# Independent analytic-torus assembly fixture for candidate-shard tests.
#
# This file deliberately owns no candidate construction.  A shard must first
# obtain and validate a declaration through the production candidate entry.
# The fixture then checks only that declaration's algebraic consumption by the
# production assembler.  It is not the candidate's Fourier geometry provider.

using LinearAlgebra, SparseArrays

const BOUNDED_CANDIDATE_LOAD_ATOL = 5.0e-10
const BOUNDED_CANDIDATE_LOAD_RTOL = 5.0e-13

function bounded_candidate_fixture_v1(M; level=:coarse, nfp=1)
    declaration = M.spatial_multiregion_declaration_v4(flux_Wb=1.0)
    mesh = M.build_spatial_mesh_v4(declaration, level, nfp)

    function sample(entity, qp, q, reference_weight, face_axis)
        rho, theta, zeta = q
        radius = 3.0 + rho * cos(theta)
        rotation = M._smr_rot(zeta)
        jacobian = [cos(theta) -rho*sin(theta) 0.0;
                    0.0        0.0            radius;
                    sin(theta) rho*cos(theta)  0.0]
        inverse_jacobian = rho == 0.0 ? zeros(3, 3) : inv(jacobian)
        normal = zeros(3)
        weight = reference_weight * abs(det(jacobian))
        if face_axis != 0
            dual = inverse_jacobian[face_axis, :]
            normal = rotation * dual / norm(dual)
            tangential = filter(!=(face_axis), 1:3)
            weight = reference_weight * norm(cross(
                jacobian[:, tangential[1]], jacobian[:, tangential[2]]))
        end
        (entity_id=entity, qp_id=qp, q=Tuple(q),
         xyz=(radius*cos(zeta), radius*sin(zeta), rho*sin(theta)),
         R=radius, phi=zeta, weight=weight, detE=det(jacobian),
         normal=Tuple(normal), E=jacobian, Einv=inverse_jacobian,
         B_reference_cyl=(0.0, 0.0, 0.0), p_reference=0.0)
    end

    # The oracle is exact for these saved discrete weights and the Q1
    # partition of unity.  It makes no exact continuum-integral claim for the
    # curved trigonometric map.
    roots = (-inv(sqrt(3.0)), inv(sqrt(3.0)))
    weights = (1.0, 1.0)
    nodes = [sample(i, 1, mesh.nodes_q[:, i], 0.0, 0)
             for i in axes(mesh.nodes_q, 2)]
    volume = NamedTuple[]
    faces = NamedTuple[]
    for (cell, bounds) in enumerate(mesh.cell_bounds)
        qp = 0
        for iz in 1:2, it in 1:2, ir in 1:2
            indices = (ir, it, iz)
            q = ntuple(axis -> sum(bounds[axis]) / 2 +
                roots[indices[axis]] *
                (bounds[axis][2] - bounds[axis][1]) / 2, 3)
            w = prod(weights[indices[axis]] *
                (bounds[axis][2] - bounds[axis][1]) / 2 for axis in 1:3)
            qp += 1
            push!(volume, sample(cell, qp, q, w, 0))
        end
    end
    for (face_id, face) in enumerate(mesh.faces)
        bounds = mesh.cell_bounds[
            face.right_cell == 0 ? face.left_cell : face.right_cell]
        tangential = filter(!=(face.axis), 1:3)
        qp = 0
        for j in 1:2, i in 1:2
            q = zeros(3)
            q[face.axis] = face.fixed
            w = 1.0
            for (axis, index) in zip(tangential, (i, j))
                q[axis] = sum(bounds[axis]) / 2 + roots[index] *
                    (bounds[axis][2] - bounds[axis][1]) / 2
                w *= weights[index] *
                    (bounds[axis][2] - bounds[axis][1]) / 2
            end
            qp += 1
            push!(faces, sample(face_id, qp, q, w, face.axis))
        end
    end
    state = Float64[]
    for node in nodes
        append!(state, node.B_reference_cyl)
        push!(state, node.p_reference)
    end
    (mesh=mesh, nodes=nodes, volume=volume, face_quadrature=faces,
     initial_state=state,
     raw_artifacts=(independent_analytic_torus_test_only=true,))
end

function bounded_candidate_expected_source_delta_v1(data, source, M)
    delta = zeros(length(data.mesh.row_blocks))
    for sample in data.volume
        basis = M.spatial_basis_v4(data.mesh, sample.entity_id, sample.q)
        for local_node in eachindex(basis.N)
            row = data.mesh.cell_row_start[sample.entity_id] +
                4*(local_node-1)
            delta[row:row+2] .-= sample.weight .* basis.N[local_node] .* source
        end
    end
    delta
end

function bounded_candidate_vector_close_v1(actual, expected)
    length(actual) == length(expected) || return false
    all(isapprox(actual[i], expected[i]; atol=BOUNDED_CANDIDATE_LOAD_ATOL,
        rtol=BOUNDED_CANDIDATE_LOAD_RTOL) for i in eachindex(actual))
end

function bounded_candidate_assembly_hashes_v1(assembly, canonical_hash)
    rows, columns, values = findnz(assembly.jacobian)
    residual_hash = canonical_hash((kind=:independent_assembly_residual,
        values=Tuple(assembly.residual)))
    jacobian_hash = canonical_hash((kind=:independent_assembly_jacobian,
        rows=size(assembly.jacobian, 1), columns=size(assembly.jacobian, 2),
        row_indices=Tuple(rows), column_indices=Tuple(columns),
        values=Tuple(values)))
    (residual_hash=string(residual_hash), jacobian_hash=string(jacobian_hash),
     residual_l2=norm(assembly.residual), jacobian_nnz=length(values))
end
