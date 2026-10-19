using Test, FusionConceptAI, LinearAlgebra, SparseArrays

println("UP2_CLOSURE_INDEPENDENT_ENV julia_version=", VERSION,
    " machine=", Sys.MACHINE, " threads=", Threads.nthreads(),
    " blas_threads=", LinearAlgebra.BLAS.get_num_threads(), " pid=", getpid())

# Keep the numerical oracle independent of the production candidate builder.
# The included module exposes the same low-level assembly functions while this
# file constructs its own quadrature fixture and expected load vectors.
module ClosureKernelUnderTest
    using FusionConceptAI, LinearAlgebra, SparseArrays
    include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
        "SpatialExecutionTypesV4.jl"))
    include(joinpath(@__DIR__, "..", "..", "..", "src", "RuntimeV4",
        "SpatialMultiRegionV4.jl"))
end
const CK = ClosureKernelUnderTest

const LEGACY_DECLARATION_HASH_FLUX1 =
    "00dc11f07af44208561877a41574cf2ec2649c6d24aa4576c05d5adabbeceb74"
const DISCRETE_LOAD_ATOL = 5.0e-10
const DISCRETE_LOAD_RTOL = 5.0e-13

function independent_fixture(M=CK; level=:coarse, nfp=1, zero_stress=false)
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
            weight = reference_weight * norm(cross(jacobian[:, tangential[1]],
                jacobian[:, tangential[2]]))
        end
        reference_B = zero_stress ? (0.0, 0.0, 0.0) : (0.0, 1.0, 0.2)
        reference_p = zero_stress ? 0.0 : 1.0e5
        (entity_id=entity, qp_id=qp, q=Tuple(q),
         xyz=(radius*cos(zeta), radius*sin(zeta), rho*sin(theta)),
         R=radius, phi=zeta, weight=weight, detE=det(jacobian),
         normal=Tuple(normal), E=jacobian, Einv=inverse_jacobian,
         B_reference_cyl=reference_B, p_reference=reference_p)
    end

    # Two-point Gauss quadrature is deliberately different from the existing
    # three-point focused-test fixture. The oracle below checks the exact same
    # frozen discrete weights and Q1 partition of unity; it does not claim an
    # exact continuum integral over the curved trigonometric mapping.
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
                roots[indices[axis]] * (bounds[axis][2] - bounds[axis][1]) / 2, 3)
            w = prod(weights[indices[axis]] *
                (bounds[axis][2] - bounds[axis][1]) / 2 for axis in 1:3)
            qp += 1
            push!(volume, sample(cell, qp, q, w, 0))
        end
    end
    for (face_id, face) in enumerate(mesh.faces)
        bounds = mesh.cell_bounds[face.right_cell == 0 ? face.left_cell : face.right_cell]
        tangential = filter(!=(face.axis), 1:3)
        qp = 0
        for j in 1:2, i in 1:2
            q = zeros(3)
            q[face.axis] = face.fixed
            w = 1.0
            for (axis, index) in zip(tangential, (i, j))
                q[axis] = sum(bounds[axis]) / 2 +
                    roots[index] * (bounds[axis][2] - bounds[axis][1]) / 2
                w *= weights[index] * (bounds[axis][2] - bounds[axis][1]) / 2
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
    declaration, (mesh=mesh, nodes=nodes, volume=volume,
        face_quadrature=faces, initial_state=state,
        raw_artifacts=(independent_manufactured_test_only=true,))
end

function replace_declaration(d::CK.SpatialMultiRegionDeclarationV4;
        revision=d.revision, regions=d.regions, states=d.states,
        interfaces=d.interfaces, source=d.source, boundary=d.boundary,
        spaces=d.spaces, flux=d.flux, cases=d.cases,
        parameters=d.parameters, quadrature=d.quadrature,
        scaling=d.scaling, solver=d.solver, applicability=d.applicability)
    CK.SpatialMultiRegionDeclarationV4(revision, regions, states, interfaces,
        source, boundary, spaces, flux, cases, parameters, quadrature, scaling,
        solver, applicability)
end

function expected_source_delta(data, source, M=CK)
    delta = zeros(length(data.mesh.row_blocks))
    for sample in data.volume
        basis = M.spatial_basis_v4(data.mesh, sample.entity_id, sample.q)
        for local_node in eachindex(basis.N)
            row = data.mesh.cell_row_start[sample.entity_id] + 4*(local_node-1)
            delta[row:row+2] .-= sample.weight .* basis.N[local_node] .* source
        end
    end
    delta
end

function expected_normal_field_delta(data, normal_B_T, M=CK)
    delta = zeros(length(data.mesh.row_blocks))
    for sample in data.face_quadrature
        face = data.mesh.faces[sample.entity_id]
        face.role == :exterior || continue
        basis = M.spatial_basis_v4(data.mesh, face.left_cell, sample.q)
        for local_node in eachindex(basis.N)
            row = data.mesh.cell_row_start[face.left_cell] + 4*(local_node-1) + 3
            delta[row] += sample.weight * basis.N[local_node] * normal_B_T
        end
        trace = findall(local_node ->
            data.mesh.nodes_q[1, basis.ids[local_node]] == 1.0,
            eachindex(basis.ids))
        start = data.mesh.exterior_row_start[sample.entity_id]
        for (trace_position, local_node) in enumerate(trace)
            row = start + 4*(trace_position-1) + 3
            delta[row] -= sample.weight * basis.N[local_node] * normal_B_T
        end
    end
    delta
end

@testset "legacy declaration and narrow declared-load authority" begin
    base = CK.spatial_multiregion_declaration_v4(flux_Wb=1.0)
    @test string(canonical_hash(base)) == LEGACY_DECLARATION_HASH_FLUX1
    @test CK.validate_spatial_multiregion_declaration_v4(base)

    declared = CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(3.25, -2.5, 0.75), normal_B_T=0.0,
        source_provenance="independent manufactured force-density fixture",
        boundary_provenance="independent closed-torus zero-normal-field fixture")
    @test declared.revision == "spatial-q1-static-mhd-declared-loads-v1"
    @test canonical_hash(declared) != canonical_hash(base)
    @test CK.validate_spatial_multiregion_declaration_v4(declared)
    @test declared.source.unit == "N m^-3"
    @test declared.boundary.normal_B_unit == "T"

    @test_throws ArgumentError CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(1.0, 2.0), normal_B_T=0.0,
        source_provenance="source", boundary_provenance="boundary")
    @test_throws ArgumentError CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(1.0, Inf, 3.0), normal_B_T=0.0,
        source_provenance="source", boundary_provenance="boundary")
    @test_throws ArgumentError CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(1.0, 2.0, 3.0), normal_B_T=0.0,
        source_provenance="", boundary_provenance="boundary")
    @test_throws ArgumentError CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(1.0, 2.0, 3.0), normal_B_T=0.0,
        source_provenance="source", boundary_provenance="boundary",
        source_unit="Pa", normal_field_unit="T")
    @test_throws ArgumentError CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(1.0, 2.0, 3.0), normal_B_T=1.0e-6,
        source_provenance="source", boundary_provenance="boundary")

    tampered_solver = replace_declaration(declared;
        solver=merge(declared.solver,
            (residual_tolerance=2*declared.solver.residual_tolerance,)))
    tampered_space = replace_declaration(declared;
        spaces=(merge(declared.spaces[1],
            (theta_count=declared.spaces[1].theta_count + 1,)),
            declared.spaces[2]))
    tampered_traction = replace_declaration(declared;
        boundary=merge(declared.boundary, (traction=:invented_anchor,)))
    @test_throws ArgumentError CK.validate_spatial_multiregion_declaration_v4(tampered_solver)
    @test_throws ArgumentError CK.validate_spatial_multiregion_declaration_v4(tampered_space)
    @test_throws ArgumentError CK.validate_spatial_multiregion_declaration_v4(tampered_traction)
end

@testset "independent source residual and conservation oracle" begin
    # A zero-field, zero-pressure, zero-reference-traction fixture isolates the
    # declared load. This avoids subtracting two large stress residuals, which
    # caused the preserved runtime_r1 test-harness cancellation failure.
    base, data = independent_fixture(; zero_stress=true)
    source = [3.25, -2.5, 0.75]
    declared = CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=Tuple(source), normal_B_T=0.0,
        source_provenance="independent manufactured force-density fixture",
        boundary_provenance="independent closed-torus zero-normal-field fixture")
    baseline = CK.assemble_spatial_system_v4(base, data, data.initial_state)
    loaded = CK.assemble_spatial_system_v4(declared, data, data.initial_state)
    delta = loaded.residual - baseline.residual
    oracle = expected_source_delta(data, source)
    @test delta ≈ oracle atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test loaded.jacobian == baseline.jacobian

    callback = CK.assemble_spatial_system_v4(base, data, data.initial_state;
        source_function=_ -> source)
    @test callback.residual ≈ loaded.residual atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test callback.jacobian == loaded.jacobian

    integrated_volume = sum(sample.weight for sample in data.volume)
    summed_momentum_delta = zeros(3)
    for (cell, ids) in enumerate(data.mesh.cell_nodes), local_node in eachindex(ids)
        row = data.mesh.cell_row_start[cell] + 4*(local_node-1)
        summed_momentum_delta .+= delta[row:row+2]
    end
    @test summed_momentum_delta ≈ -integrated_volume .* source atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL

    @test_throws ArgumentError CK.assemble_spatial_system_v4(base, data,
        data.initial_state; source_function=_ -> (1.0, NaN, 2.0))
end

@testset "normal-field signs are testable but production-incompatible" begin
    base, data = independent_fixture(; zero_stress=true)
    normal_B_T = 0.25
    incompatible = replace_declaration(base;
        boundary=merge(base.boundary, (normal_B_T=normal_B_T,)))
    @test_throws ArgumentError CK.validate_spatial_multiregion_declaration_v4(incompatible)

    baseline = CK.assemble_spatial_system_v4(base, data, data.initial_state)
    altered = CK.assemble_spatial_system_v4(incompatible, data, data.initial_state)
    delta = altered.residual - baseline.residual
    oracle = expected_normal_field_delta(data, normal_B_T)
    @test delta ≈ oracle atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test altered.jacobian == baseline.jacobian

    callback = CK.assemble_spatial_system_v4(base, data, data.initial_state;
        normal_field_function=(_, _) -> normal_B_T)
    @test callback.residual ≈ altered.residual atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
end

@testset "declared-load diagnostics preserve missing external closure" begin
    # Use the same zero-stress control as the assembly oracle. The diagnostic
    # quantities then have direct discrete values without cancellation against
    # unrelated magnetic or pressure stresses.
    base, data = independent_fixture(; zero_stress=true)
    source = [3.25, -2.5, 0.75]
    declared = CK.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=Tuple(source), normal_B_T=0.0,
        source_provenance="independent manufactured force-density fixture",
        boundary_provenance="independent closed-torus zero-normal-field fixture")
    diagnostics = CK._smr_current_texts(data, data.initial_state;
        declaration=declared).diagnostics.declared_loads
    @test diagnostics.source_xyz_N_m3 == Tuple(source)
    @test diagnostics.source_unit == "N m^-3"
    @test diagnostics.normal_B_unit == "T"
    source_norm = norm(source)
    @test collect(diagnostics.divT_minus_source_rms_N_m3) ≈
        fill(source_norm, 2) atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test collect(diagnostics.divT_minus_source_peak_N_m3) ≈
        fill(source_norm, 2) atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    integrated_volume = sum(sample.weight for sample in data.volume)
    force_balance_oracle = -integrated_volume .* source
    @test collect(diagnostics.imposed_traction_minus_source_integral_N) ≈
        force_balance_oracle atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test collect(diagnostics.state_traction_minus_source_integral_N) ≈
        force_balance_oracle atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test diagnostics.prescribed_outer_normal_flux_Wb == 0.0
    @test diagnostics.outer_normal_field_mismatch_peak_T == 0.0
    @test diagnostics.compatibility_certified === false
    @test diagnostics.external_closure_status === :terminal_deferred
    current = CK._smr_current_texts(data, data.initial_state;
        declaration=declared).current_closure
    @test current.outer_Bout === :unknown
    @test current.outer_K === :unknown
    @test current.external_current_closure === :unsupported
end

module CandidateEntryFixture
    using FusionConceptAI

    function timed(f, label)
        started = time_ns()
        println("UP2_CLOSURE_DGPI_STAGE_BEGIN=", label); flush(stdout)
        value = f()
        println("UP2_CLOSURE_DGPI_STAGE_END=", label,
            " elapsed_seconds=", (time_ns()-started)/1e9); flush(stdout)
        value
    end

    # This is a structurally valid production parent constructed by the real
    # DGPI example. It intentionally differs from the historical revised
    # parent used by W24; this fixture does not replay that upstream
    # revised-candidate, DESC-proof, or whole-chain lineage.
    timed("dgpi_parent") do
        include(joinpath(@__DIR__, "..", "..", "..", "examples",
            "runtime_v4_desc_geometry_program_interpreter.jl"))
    end
    const SCV = DGPI
    timed("production_helper_sources") do
        for source in ("DESCRequestProviderExecutionV4.jl",
                       "CompleteMultiRegionV4.jl",
                       "MagneticEngineeringV4.jl",
                       "ExecutedVerificationUQV4.jl",
                       "RevisedCandidateV4.jl")
            Base.include(SCV, joinpath(@__DIR__, "..", "..", "..", "src",
                "RuntimeV4", source))
        end
        Base.include(SCV, joinpath(@__DIR__, "..", "..", "..", "src",
            "RuntimeV4", "SpatialRuntimeV4.jl"))
        Base.invokelatest(SCV.load_spatial_runtime_v4!)
    end

    const historical_revised_parent_hash =
        "7b44ba518eb7e7fdede814c1fccb94bd540f41c8b5e4fd3130e6971465c35548"
    const parent_context = dgpi_context
    const physical_input = dgpi_declaration
    const parent_candidate_hash = string(parent_context.candidate_hash)
    const parent_subject_hash = string(parent_context.subject.physical_subject_hash)
    const parent_declaration_hash = string(canonical_hash(physical_input))
    const flux = physical_input.profiles_flux.toroidal_flux_wb
    const base = SCV.spatial_multiregion_declaration_v4(flux_Wb=flux)
    const implicit_legacy = timed("implicit_legacy_candidate") do
        SCV.build_spatial_candidate_v4(parent_context, physical_input)
    end
    const explicit_legacy = timed("explicit_legacy_candidate") do
        SCV.build_spatial_candidate_v4(parent_context, physical_input;
            physical_declaration=base)
    end
    const declared = SCV.spatial_multiregion_declared_loads_v1(base;
        source_xyz_N_m3=(3.25, -2.5, 0.75), normal_B_T=0.0,
        source_provenance="independent manufactured force-density fixture",
        boundary_provenance="independent closed-torus zero-normal-field fixture")
    const loaded = timed("declared_load_candidate") do
        SCV.build_spatial_candidate_v4(parent_context, physical_input;
            physical_declaration=declared)
    end
end
const CE = CandidateEntryFixture

@testset "actual candidate entry consumes the declaration without solving" begin
    @test CE.parent_candidate_hash != CE.historical_revised_parent_hash
    @test CE.parent_candidate_hash == string(CE.parent_context.candidate_hash)
    @test CE.parent_subject_hash == string(CE.parent_context.subject.physical_subject_hash)
    @test CE.parent_declaration_hash == string(canonical_hash(CE.physical_input))
    @test CE.SCV.validate_spatial_candidate_v4(CE.implicit_legacy.context)
    @test CE.SCV.validate_spatial_candidate_v4(CE.explicit_legacy.context)
    @test CE.SCV.validate_spatial_candidate_v4(CE.loaded.context)
    @test CE.implicit_legacy.context.candidate_hash == CE.explicit_legacy.context.candidate_hash
    @test CE.implicit_legacy.context.context_hash == CE.explicit_legacy.context.context_hash
    @test CE.implicit_legacy.context.subject.physical_subject_hash ==
        CE.explicit_legacy.context.subject.physical_subject_hash
    @test canonical_hash(CE.implicit_legacy.context.candidate) ==
        canonical_hash(CE.explicit_legacy.context.candidate)
    @test CE.loaded.context.candidate_hash != CE.implicit_legacy.context.candidate_hash
    @test CE.loaded.context.context_hash != CE.implicit_legacy.context.context_hash
    @test CE.loaded.context.subject.physical_subject_hash !=
        CE.implicit_legacy.context.subject.physical_subject_hash
    @test CE.loaded.context.candidate.canonical_hashes.mechanism_hash !=
        CE.implicit_legacy.context.candidate.canonical_hashes.mechanism_hash
    @test CE.loaded.context.candidate.canonical_hashes.field_geometry_hash !=
        CE.implicit_legacy.context.candidate.canonical_hashes.field_geometry_hash
    @test CE.loaded.context.candidate.canonical_hashes.realization_control_hash !=
        CE.implicit_legacy.context.candidate.canonical_hashes.realization_control_hash
    @test CE.implicit_legacy.parent_hash == canonical_hash(CE.parent_context.candidate)
    @test CE.explicit_legacy.parent_hash == canonical_hash(CE.parent_context.candidate)
    @test CE.loaded.parent_hash == canonical_hash(CE.parent_context.candidate)
    @test CE.loaded.provenance.parent_candidate_hash == CE.parent_context.candidate_hash
    @test CE.loaded.provenance.parent_context_hash == CE.parent_context.context_hash
    @test CE.loaded.provenance.parent_package_hash ==
        canonical_hash(CE.parent_context.candidate)
    inherited_input = only(filter(x -> x isa CE.SCV.ThreeDPhysicalProviderInputV4,
        CE.loaded.context.candidate.field_geometry_genome_ref.fields))
    @test canonical_hash(inherited_input) == canonical_hash(CE.physical_input)
    @test CE.loaded.changes.physical_hash == canonical_hash(CE.declared)
    @test CE.loaded.provenance.revision ==
        "spatial-coupled-candidate-declared-loads-v1"
    @test CE.loaded.provenance.declared_loads.exterior_current_closure ===
        :terminal_deferred
    @test CE.SCV._smr_declaration(CE.implicit_legacy.context) == CE.base
    @test CE.SCV._smr_declaration(CE.explicit_legacy.context) == CE.base
    production_declaration = CE.SCV._smr_declaration(CE.loaded.context)
    @test production_declaration == CE.declared

    # Exercise the declaration obtained from the real candidate entry through
    # the real assembly seam. This remains an assembly test; it makes no solver
    # convergence or physical-closure claim.
    _, production_data = independent_fixture(CE.SCV; zero_stress=true)
    legacy_assembly = CE.SCV.assemble_spatial_system_v4(CE.base,
        production_data, production_data.initial_state)
    loaded_assembly = CE.SCV.assemble_spatial_system_v4(production_declaration,
        production_data, production_data.initial_state)
    production_delta = loaded_assembly.residual - legacy_assembly.residual
    production_oracle = expected_source_delta(production_data,
        [3.25, -2.5, 0.75], CE.SCV)
    @test production_delta ≈ production_oracle atol=DISCRETE_LOAD_ATOL rtol=DISCRETE_LOAD_RTOL
    @test loaded_assembly.jacobian == legacy_assembly.jacobian
end

println("UP2_CLOSURE_DGPI_PARENT_CANDIDATE_HASH=", CE.parent_candidate_hash)
println("UP2_CLOSURE_DGPI_PARENT_SUBJECT_HASH=", CE.parent_subject_hash)
println("UP2_CLOSURE_DGPI_PARENT_DECLARATION_HASH=", CE.parent_declaration_hash)
println("UP2_CLOSURE_DGPI_SCOPE=targeted_real_parent_not_historical_W24_replay")

println("UP2_CLOSURE_REPAIR_V1_INDEPENDENT_TESTS_EXIT_CODE=0")
