if !isdefined(@__MODULE__, :MultiTopologyNonlinearSolveV1)
    include(joinpath(@__DIR__, "MultiTopologyNonlinearSolveV1.jl"))
end
if !isdefined(@__MODULE__, :InHouseCoupledMHDGlobalSolveV1)
    include(joinpath(@__DIR__, "InHouseCoupledMHDGlobalSolveV1.jl"))
end

"""Versioned shared-test-row Q1 weak operator for the N1 numerical successor.

Include this file in the same definition module after SpatialMultiRegionV4.jl
and SpatialManufacturedInputV1.jl.  It deliberately does not alter the V4
289-by-40 row-stacked operator.  This is a manufactured numerical experiment;
it carries no DESC, physical, engineering, or whole-device authority.
"""


const _SMGW_OPERATOR_REVISION_V1 = "spatial-q1-global-shared-test-rows-v1"
const _SMGW_OPERATOR_REVISION_V2 = "spatial-q1-global-shared-test-rows-bound-v2"
const _SMGW_RESULT_SCHEMA_V2 = "spatial-manufactured-global-weak-result-v2"

struct _SMGWCanonicalTupleViewV1{T}
    values::Vector{T}
end

struct _SMGWCanonicalJSONFragmentV1
    bytes::String
end

@noinline function _smgw_canonical_tuple_view_json_v1(view::_SMGWCanonicalTupleViewV1)
    io = IOBuffer()
    print(io, '[')
    values = view.values
    @inbounds for index in eachindex(values)
        index == firstindex(values) || print(io, ',')
        print(io, FusionConceptAI._canonical(values[index]))
    end
    print(io, ']')
    String(take!(io))
end

FusionConceptAI._canonical(view::_SMGWCanonicalTupleViewV1) =
    _smgw_canonical_tuple_view_json_v1(view)
FusionConceptAI._canonical(fragment::_SMGWCanonicalJSONFragmentV1) = fragment.bytes

_smgw_tuple_view_v1(values::Vector{T}) where {T} = _SMGWCanonicalTupleViewV1{T}(values)

function _smgw_add_compensated_source3!(accum, correction, term)
    @inbounds for k in 1:3
        current = accum[k]
        value = term[k]
        updated = current + value
        correction[k] += abs(current) >= abs(value) ?
            (current - updated) + value : (value - updated) + current
        accum[k] = updated
    end
    nothing
end

@inline function _smgw_add_compensated_scalar(sum::Float64,
        correction::Float64, term::Real)
    value = Float64(term)
    updated = sum + value
    correction += abs(sum) >= abs(value) ?
        (sum - updated) + value : (value - updated) + sum
    (updated, correction)
end

function _smgw_partition_mode_v1(mode)
    mode isa AbstractString && (mode = Symbol(mode))
    mode in (:spatial_native, :inhouse_kkt) ||
        throw(ArgumentError("unsupported global weak residual partition mode"))
    mode
end

function _smgw_verify_solver_step_identity_v1(solver)
    mode = _smgw_partition_mode_v1(solver.residual_partition)
    expected = _smgw_step_identity_v1(mode)
    _smgw_json_equal_v1(solver.step_identity, expected) &&
        solver.step_identity_hash == string(canonical_hash(expected)) ||
        throw(ArgumentError("GlobalWeak selected step identity is stale or inconsistent"))
    function verify_partition_record(record, label)
        hasproperty(record, :residual_partition) ||
            throw(ArgumentError("$label is missing the frozen LS/KKT partition identity"))
        p = record.residual_partition
        all(key -> hasproperty(p, key), (:partition_mode, :step_identity,
                :step_identity_hash, :schema, :solver_semantic_hash,
                :partition_hash, :consumer_identity_hash, :row_identity_hash,
                :row_scale_hash, :raw_residual_hash, :equality_rows,
                :least_squares_rows)) ||
            throw(ArgumentError("$label partition identity is incomplete"))
        _smgw_partition_mode_v1(p.partition_mode) == mode &&
            _smgw_json_equal_v1(p.step_identity, expected) &&
            p.step_identity_hash == string(canonical_hash(expected)) &&
            p.equality_rows == 0 && p.least_squares_rows > 0 ||
            throw(ArgumentError("$label LS/KKT partition mode, rows, or step identity differs"))
        for key in (:schema, :solver_semantic_hash, :partition_hash,
                :consumer_identity_hash, :row_identity_hash, :row_scale_hash, :raw_residual_hash)
            hasproperty(p, key) || throw(ArgumentError("$label partition identity lacks $key"))
        end
        p.schema == "weighted-residual-kkt-partition-v1" &&
            p.solver_semantic_hash ==
                InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_step_identity_v1().solver_semantic_hash ||
            throw(ArgumentError("$label partition solver semantic identity differs from loaded InHouse API"))
        all(key -> occursin(r"^[0-9a-f]{64}$", String(getproperty(p, key))),
            (:solver_semantic_hash, :partition_hash, :consumer_identity_hash,
             :row_identity_hash, :row_scale_hash, :raw_residual_hash)) ||
            throw(ArgumentError("$label partition contains a malformed semantic or content hash"))
        true
    end
    if mode === :inhouse_kkt
        for (index, record) in enumerate(solver.iterations)
            verify_partition_record(record, "iteration[$index]")
        end
        for (index, record) in enumerate(solver.attempts)
            verify_partition_record(record, "attempt[$index]")
            inhouse_step_identity_valid = hasproperty(record.bounded_step, :backend) &&
                String(record.bounded_step.backend) == "inhouse_weighted_residual_kkt" &&
                _smgw_json_equal_v1(record.bounded_step.diagnostics.step_identity, expected.implementation) &&
                record.bounded_step.diagnostics.step_identity_hash ==
                    string(canonical_hash(expected.implementation)) &&
                record.bounded_step.diagnostics.solver_semantic_hash ==
                    InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_step_identity_v1().solver_semantic_hash
            inhouse_step_identity_valid ||
                throw(ArgumentError("attempt[$index] lacks the actual InHouse linear-step identity"))
            if hasproperty(record, :direction)
                String(record.direction) == "global_shared_q1_inhouse_active_set_weighted_residual_KKT" ||
                    throw(ArgumentError("attempt[$index] direction label differs from InHouse backend"))
            end
        end
    else
        any(record -> hasproperty(record, :residual_partition), solver.iterations) &&
            throw(ArgumentError("native Spatial path contains foreign partition records"))
        any(record -> hasproperty(record, :residual_partition), solver.attempts) &&
            throw(ArgumentError("native Spatial path contains foreign partition records"))
        for (index, record) in enumerate(solver.attempts)
            hasproperty(record, :direction) &&
                String(record.direction) != "global_shared_q1_lower_bounded_sparse_QR" &&
                throw(ArgumentError("attempt[$index] direction label differs from native Spatial backend"))
            if hasproperty(record, :selected_direction) &&
                    String(record.selected_direction) in
                        ("q1_8_bounded_lm_alternate", "q1_4_m1n1_bounded_lm_alternate")
                lm_present = hasproperty(record, :lm_alternate)
                lm = lm_present ? record.lm_alternate : nothing
                mapped_lm = String(record.selected_direction) == "q1_4_m1n1_bounded_lm_alternate"
                refinement_present = mapped_lm && lm !== nothing && hasproperty(lm, :refinement)
                if refinement_present
                    refinement = lm.refinement
                    refinement !== nothing && hasproperty(refinement, :selected) &&
                        refinement.selected isa Bool ||
                        throw(ArgumentError("attempt[$index] LM refinement is missing a Boolean selected field"))
                end
                refined_lm = refinement_present && lm.refinement.selected === true
                expected_lm_schema = refined_lm ? "q1-4-m1n1-bounded-lm-chord-refined-v2" :
                    mapped_lm ? "q1-4-m1n1-bounded-lm-chord-corrector-v1" : "q1-8-bounded-lm-chord-corrector-v1"

                ray_fields = lm_present && lm !== nothing &&
                    hasproperty(lm, :selected_lm_ray_alpha) && hasproperty(lm, :line_search_alpha0) &&
                    hasproperty(lm, :line_search_alpha_source)
                ray_policy_valid = false
                if ray_fields
                    source_value = lm.line_search_alpha_source
                    start_value = lm.line_search_alpha0
                    ray_alpha = lm.selected_lm_ray_alpha
                    source_type_valid = source_value isa Symbol || source_value isa AbstractString
                    start_type_valid = start_value isa Real && !(start_value isa Bool)
                    ray_type_valid = ray_alpha === nothing || (ray_alpha isa Real && !(ray_alpha isa Bool))
                    if source_type_valid && start_type_valid && ray_type_valid
                        ray_source = String(source_value)
                        start_alpha = Float64(start_value)
                        ray_policy_valid = isfinite(start_alpha) &&
                            ((ray_source == "quartic_selected" && ray_alpha !== nothing &&
                                isfinite(ray_alpha) && 0.0 < ray_alpha < 1.0 && start_alpha == ray_alpha) ||
                             (ray_source == "alpha_one_fallback" && ray_alpha === nothing && start_alpha == 1.0))
                    end
                end
                chord_fields = lm_present && lm !== nothing &&
                    hasproperty(lm, :raw_step) && hasproperty(lm, :correction_step) &&
                    hasproperty(lm, :corrector_kkt) && hasproperty(lm, :corrector_alpha) &&
                    hasproperty(lm, :selection_reason)
                chord_identity_valid = false
                if chord_fields && ray_policy_valid
                    raw = lm.raw_step
                    correction = lm.correction_step
                    alpha = lm.corrector_alpha
                    if alpha isa Real && !(alpha isa Bool) && isfinite(alpha) &&
                            0.0 < alpha < 1.0 && length(raw) == length(correction) == length(record.step)
                        expected_step = Float64(alpha) .* Float64.(collect(raw)) .+ Float64.(collect(correction))
                        chord_identity_valid = all(isfinite, expected_step) &&
                            _smgw_json_equal_v1(record.step, Tuple(expected_step))
                    end
                end
                if refined_lm && chord_fields && ray_policy_valid
                    hasproperty(lm, :lambda) && lm.lambda isa Real && !(lm.lambda isa Bool) &&
                        isfinite(lm.lambda) && lm.lambda > 0.0 ||
                        throw(ArgumentError("attempt[$index] refined LM lambda must be finite and positive"))
                    chord_identity_valid = _smgw_m1n1_refinement_identity_v1(lm, record)
                end
                lm_present && lm !== nothing && hasproperty(lm, :schema) &&
                    (mapped_lm || !hasproperty(lm, :refinement)) &&
                    String(lm.schema) == expected_lm_schema && ray_policy_valid &&
                    chord_identity_valid && lm.selected === true && String(lm.status) == "kkt_converged" &&
                    hasproperty(lm, :corrector_kkt) && lm.corrector_kkt.passed &&
                    isfinite(lm.lambda) && lm.lambda > 0.0 &&
                    String(lm.augmented_rank_evidence) == "not_used_for_raw_rank" &&
                    String(lm.selection_reason) == "finite_kkt_feasible_descent" &&
                    _smgw_json_equal_v1(record.step, lm.step) ||
                    throw(ArgumentError("attempt[$index] selected LM chord direction lacks its correction-KKT/composite/ray-start evidence"))
            elseif hasproperty(record, :selected_direction)
                String(record.selected_direction) == "raw_bounded_sparse_qr" &&
                    hasproperty(record, :bounded_step) &&
                    _smgw_json_equal_v1(record.step, record.bounded_step.step) ||
                    throw(ArgumentError("attempt[$index] raw direction differs from its bounded QR result"))
            end
        end
    end
    mode
end

function _smgw_step_identity_v1(mode)
    mode = _smgw_partition_mode_v1(mode)
    mode === :spatial_native ?
        (schema="spatial-global-weak-step-identity-v7", partition_mode=mode,
         backend=:spatial_lower_bounded_sparse_QR,
         nonlinear_direction_policy=:q1_8_or_q1_4_m1n1_curvature_triggered_bounded_lm_chord_corrector_v1,
         curvature_step_scope=(q1_8=:existing_maps, q1_4=:m1n1_ripple_torus_only),
         damping_rule=:actual_linear_gain_ratio_075_025_factor_tenth_ten_seed_1e_2_multiplier_1e5_100,
         chord_corrector=:quadratic_raw_ray_residual_shifted_lower_same_lambda_one_bounded_qr,
         selected_lm_ray_start=:quartic_minimizer_if_eligible_else_one,
         implementation=_smr_bounded_identity_v1()) :
        (schema="spatial-global-weak-step-identity-v1", partition_mode=mode,
         backend=:inhouse_active_set_weighted_residual_KKT,
         implementation=InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_step_identity_v1())
end

"Identity for the additive operator and its selected linear-step backend."
function spatial_global_weak_operator_identity_v1(; residual_partition=:spatial_native)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    semantic_identities = _smgw_current_semantic_identities_v1()
    bounded_identity = _smr_bounded_identity_v1()
    step_identity = _smgw_step_identity_v1(residual_partition)
    residual_partition === :inhouse_kkt &&
        step_identity.implementation.solver_semantic_hash != semantic_identities.inhouse_solver_semantic_hash &&
        throw(ArgumentError("InHouse step identity and semantic source identity differ"))
    (revision=_SMGW_OPERATOR_REVISION_V2,
        solver_semantic_hash=semantic_identities.solver_semantic_hash,
        provider_semantic_hash=semantic_identities.provider_semantic_hash,
        contract_semantic_hash=semantic_identities.contract_semantic_hash,
        residual_partition=residual_partition,
        step_identity=step_identity,
        step_identity_hash=string(canonical_hash(step_identity)),
        finite_element_space=:continuous_tensor_Q1_shared_global_nodes,
        volume_test_rows=:one_vector_and_one_divergence_row_per_global_node,
        interface_treatment=:oriented_two_sided_trace_scatter,
        exterior_treatment=:natural_load_plus_Q1_trace_projection_constraints,
        linear_step=step_identity.backend,
        bounded_step_identity=residual_partition === :spatial_native ? bounded_identity : nothing,
        dependency_semantic_hashes=semantic_identities,
        numerical_scope=:manufactured_numerical_only,
        physical_validation=:unsupported, authority=:no_publish)
end

function _smgw_validate_policy_v1(d; residual_partition=:spatial_native)
    _smm_is_declaration_v1(d) || throw(ArgumentError("global weak successor requires the frozen manufactured N1 declaration"))
    validate_spatial_n1_manufactured_declaration_v1(d)
    _smr_check_bounded_method_v1(d)
    n = d.source.input.numerics
    seconds = d.source.input.mesh.level === :q1_8 ? 600.0 : 120.0
    exact = (max_iterations=12, seconds=seconds, residual_tolerance=1.0e-6,
        gradient_tolerance=1.0e-10, rank_relative_tolerance=1.0e-10,
        kkt_absolute_tolerance=1.0e-10, line_search_steps=20, pressure_lower_Pa=0.0)
    for key in keys(exact)
        isequal(getproperty(n, key), getproperty(exact, key)) ||
            throw(ArgumentError("global weak operator refuses changed frozen numerical policy: $key"))
    end
    spatial_global_weak_operator_identity_v1(; residual_partition)
    true
end

function _smgw_validate_inputs_v1(d, data, x, flux_Wb; residual_partition=:spatial_native)
    _smgw_validate_policy_v1(d; residual_partition)
    mesh = data.mesh
    nd = 4 * size(mesh.nodes_q, 2)
    length(x) == nd && all(v -> v isa Real && isfinite(v), x) ||
        throw(ArgumentError("global weak state must be finite and match shared Q1 node DOFs"))
    mesh.nfp == d.source.input.mesh.nfp || throw(ArgumentError("global weak mesh field-period identity mismatch"))
    flux_Wb == d.source.input.flux.nominal_Wb == d.flux.nominal_Wb ||
        throw(ArgumentError("global weak flux differs from frozen manufactured input"))
    data.raw_artifacts isa NamedTuple && hasproperty(data, :volume) && hasproperty(data, :face_quadrature) ||
        throw(ArgumentError("global weak operator requires the actual manufactured quadrature bundle"))
    length(data.volume) > 0 && length(data.face_quadrature) == length(mesh.faces) * d.quadrature.order^2 ||
        throw(ArgumentError("global weak quadrature coverage mismatch"))
    (mesh=mesh, ndofs=nd, nnode=size(mesh.nodes_q, 2), flux_Wb=Float64(flux_Wb))
end

function _smgw_dofs_v1(nodes)
    Int[4 * (n - 1) + k for n in nodes for k in 1:4]
end

function _smgw_layout_v1(data)
    mesh = data.mesh
    nnode = size(mesh.nodes_q, 2)
    outer_nodes = findall(n -> mesh.nodes_q[1, n] == 1.0, 1:nnode)
    length(outer_nodes) > 0 || throw(ArgumentError("global weak mesh has no outer trace nodes"))
    outer_index = Dict(node => i for (i, node) in enumerate(outer_nodes))
    volume_end = 4 * nnode
    trace_first = volume_end + 1
    trace_end = volume_end + 4 * length(outer_nodes)
    flux_row = trace_end + 1
    total_rows = flux_row
    row_blocks = Vector{Symbol}(undef, total_rows)
    row_supports = [Int[] for _ in 1:total_rows]

    node_cells = [Int[] for _ in 1:nnode]
    for (cell, nodes) in enumerate(mesh.cell_nodes), node in nodes
        push!(node_cells[node], cell)
    end
    for node in 1:nnode
        support = sort!(unique!(reduce(vcat, (_smgw_dofs_v1(mesh.cell_nodes[c]) for c in node_cells[node]); init=Int[])))
        firstrow = 4 * (node - 1) + 1
        row_blocks[firstrow:firstrow+3] .= (:momentum_N, :momentum_N, :momentum_N, :divB_Wb)
        for row in firstrow:firstrow+3
            row_supports[row] = copy(support)
        end
    end

    trace_support = [Int[] for _ in outer_nodes]
    for face in mesh.faces
        face.role == :exterior || continue
        nodes = mesh.cell_nodes[face.left_cell]
        trace = filter(n -> mesh.nodes_q[1, n] == 1.0, nodes)
        for node in trace
            append!(trace_support[outer_index[node]], _smgw_dofs_v1(trace))
        end
    end
    for (i, node) in enumerate(outer_nodes)
        firstrow = trace_first + 4 * (i - 1)
        row_blocks[firstrow:firstrow+3] .= (:traction_N, :traction_N, :traction_N, :normal_B_Wb)
        support = sort!(unique!(trace_support[i]))
        isempty(support) && throw(ArgumentError("outer trace node has no exterior face support"))
        for row in firstrow:firstrow+3
            row_supports[row] = copy(support)
        end
    end
    cut_nodes = findall(n -> mesh.nodes_q[3, n] == 0.0, 1:nnode)
    row_blocks[flux_row] = :total_flux_Wb
    row_supports[flux_row] = Int[4 * (n - 1) + k for n in cut_nodes for k in 1:3]
    isempty(row_supports[flux_row]) && throw(ArgumentError("global weak toroidal cut has no magnetic DOFs"))

    public_row_layout = (volume_rows=(first=1, last=volume_end,
            per_node=(:momentum_x, :momentum_y, :momentum_z, :divB)),
        boundary_trace_rows=(first=trace_first, last=trace_end,
            per_node=(:traction_x, :traction_y, :traction_z, :normal_B),
            projection=:Q1_face_mass_projection),
        total_flux_row=flux_row, total_rows=total_rows, outer_nodes=Tuple(outer_nodes),
        outer_node_rows=Tuple((node=node, first=trace_first + 4 * (i - 1),
            last=trace_first + 4 * i - 1) for (i, node) in enumerate(outer_nodes)),
        cut_nodes=Tuple(cut_nodes))
    (volume_rows=public_row_layout.volume_rows,
        boundary_trace_rows=public_row_layout.boundary_trace_rows,
        total_flux_row=public_row_layout.total_flux_row, total_rows=public_row_layout.total_rows,
        outer_nodes=public_row_layout.outer_nodes, outer_node_rows=public_row_layout.outer_node_rows,
        cut_nodes=public_row_layout.cut_nodes, outer_index=outer_index,
        row_blocks=Tuple(row_blocks), row_supports=Tuple(Tuple(v) for v in row_supports),
        node_order=Tuple(Tuple(mesh.nodes_q[:, n]) for n in 1:nnode),
        element_nodes=Tuple(Tuple(nodes) for nodes in mesh.cell_nodes),
        public_row_layout=public_row_layout)
end

function _smgw_add_jacobian!(ii, jj, vv, enabled, row, col, value)
    enabled || return nothing
    isfinite(value) || throw(ArgumentError("nonfinite global weak Jacobian entry"))
    iszero(value) && return nothing
    push!(ii, row); push!(jj, col); push!(vv, value)
    nothing
end

function _smgw_row_scales_v1(d, data, layout)
    mesh = data.mesh
    volume_lump = zeros(size(mesh.nodes_q, 2))
    trace_lump = zeros(length(layout.outer_nodes))
    for sample in data.volume
        basis = spatial_basis_v4(mesh, sample.entity_id, sample.q)
        for (a, node) in enumerate(basis.ids)
            volume_lump[node] += sample.weight * basis.N[a]
        end
    end
    for sample in data.face_quadrature
        face = mesh.faces[sample.entity_id]
        face.role == :exterior || continue
        basis = spatial_basis_v4(mesh, face.left_cell, sample.q)
        for (a, node) in enumerate(basis.ids)
            mesh.nodes_q[1, node] == 1.0 || continue
            trace_lump[layout.outer_index[node]] += sample.weight * basis.N[a]
        end
    end
    stress_scale = d.scaling.B_T^2 / _SMR_MU0 + d.scaling.p_Pa
    scales = zeros(layout.total_rows)
    for node in eachindex(volume_lump)
        volume_lump[node] > 0.0 && isfinite(volume_lump[node]) ||
            throw(ArgumentError("global Q1 volume test has nonpositive lumped support"))
        area_scale = volume_lump[node]^(2 / 3)
        row = 4 * (node - 1) + 1
        scales[row:row+2] .= stress_scale * area_scale
        scales[row+3] = d.scaling.B_T * area_scale
    end
    for (i, measure) in enumerate(trace_lump)
        measure > 0.0 && isfinite(measure) || throw(ArgumentError("global Q1 exterior trace has nonpositive support"))
        row = layout.boundary_trace_rows.first + 4 * (i - 1)
        scales[row:row+2] .= stress_scale * measure
        scales[row+3] = d.scaling.B_T * measure
    end
    scales[layout.total_flux_row] = d.flux.nominal_Wb
    all(v -> isfinite(v) && v > 0.0, scales) || throw(ArgumentError("invalid global weak row scale"))
    scales
end

"""Assemble physical weak residual/Jacobian into shared global Q1 test rows.

Interior and rho=1/2 interface face fluxes are scattered with opposite
orientations into the same shared-node test rows. Exterior analytic traction
and normal field enter the natural weak boundary load, and remain independently
checked by Q1 trace-projection rows. The toroidal cut flux is retained as an
explicit scalar residual.
"""
function assemble_spatial_global_weak_system_v1(d, data, x;
        flux_Wb=d.flux.nominal_Wb, jacobian=true, residual_partition=:spatial_native)
    checked = _smgw_validate_inputs_v1(d, data, x, flux_Wb; residual_partition)
    mesh = checked.mesh
    layout = _smgw_layout_v1(data)
    scales = _smgw_row_scales_v1(d, data, layout)
    residual = zeros(layout.total_rows)
    ii = Int[]; jj = Int[]; vv = Float64[]
    add(row, col, value) = _smgw_add_jacobian!(ii, jj, vv, jacobian, row, col, value)
    source_integral = zeros(3)
    source_correction = zeros(3)
    boundary_traction_integral = zeros(3)
    boundary_traction_correction = zeros(3)
    boundary_normal_integral = 0.0
    boundary_normal_correction = 0.0
    outer_traction_peak = 0.0
    outer_normal_peak = 0.0
    interface_B_peak = 0.0
    interface_traction_peak = 0.0
    interface_normal_B_peak = 0.0
    interface_action_reaction = zeros(3)
    interface_action_correction = zeros(3)
    interface_normal_balance = 0.0
    interface_normal_correction = 0.0

    # d(stress*g)/d(B,p), contracted against the physical test gradient.
    function stress_directional_derivative(field, trial_basis, component, test_gradient)
        component == 4 && return -trial_basis .* test_gradient
        direction = trial_basis .* view(field.rotation, :, component)
        B = field.B_xyz
        (direction .* dot(B, test_gradient) + B .* dot(direction, test_gradient) -
            test_gradient .* dot(B, direction)) ./ _SMR_MU0
    end

    # Scalar form for the high-volume quadrature loop; return an isbits tuple.
    @inline function stress_directional_derivative_components(field, trial_basis, component, test_gradient, bg)
        g1, g2, g3 = test_gradient
        if component == 4
            return (-trial_basis * g1, -trial_basis * g2, -trial_basis * g3)
        end
        r1 = field.rotation[1, component]
        r2 = field.rotation[2, component]
        r3 = field.rotation[3, component]
        u1 = trial_basis * r1
        u2 = trial_basis * r2
        u3 = trial_basis * r3
        B = field.B_xyz
        ug = u1 * g1 + u2 * g2 + u3 * g3
        bu = B[1] * u1 + B[2] * u2 + B[3] * u3
        ((u1 * bg + B[1] * ug - g1 * bu) / _SMR_MU0,
         (u2 * bg + B[2] * ug - g2 * bu) / _SMR_MU0,
         (u3 * bg + B[3] * ug - g3 * bu) / _SMR_MU0)
    end

    # Volume weak form, scattered by global trial/test node ids.
    for sample in data.volume
        cell = sample.entity_id
        field = spatial_field_v4(data, cell, sample, x)
        source = collect(_smm_source_v1(d.source.input, sample.xyz))
        _smgw_add_compensated_source3!(source_integral, source_correction,
            sample.weight .* source)
        for a in eachindex(field.ids)
            node_a = field.ids[a]
            row = 4 * (node_a - 1) + 1
            gradient = view(field.gradN_xyz, :, a)
            residual[row:row+2] .-= sample.weight .* (field.T_xyz * gradient + field.N[a] .* source)
            residual[row+3] -= sample.weight * dot(gradient, field.B_xyz)
            if jacobian
                rotation_gradient = ntuple(component ->
                    dot(gradient, view(field.rotation, :, component)), 3)
                bg = dot(field.B_xyz, gradient)
                for (b, node_b) in enumerate(field.ids), component in 1:4
                    col = 4 * (node_b - 1) + component
                    derivative1, derivative2, derivative3 = stress_directional_derivative_components(
                        field, field.N[b], component, gradient, bg)
                    add(row, col, -sample.weight * derivative1)
                    add(row + 1, col, -sample.weight * derivative2)
                    add(row + 2, col, -sample.weight * derivative3)
                    div_derivative = component == 4 ? 0.0 :
                        -sample.weight * field.N[b] * rotation_gradient[component]
                    add(row + 3, col, div_derivative)
                end
            end
        end
    end

    source_integral .+= source_correction

    # Oriented interior/interface fluxes; both sides use their own element
    # basis-to-global map before scattering into the shared test space.
    for sample in data.face_quadrature
        face = mesh.faces[sample.entity_id]
        face.role == :exterior && continue
        normal = collect(sample.normal)
        left = spatial_field_v4(data, face.left_cell, sample, x)
        right = spatial_field_v4(data, face.right_cell, sample, x)
        if face.role == :interface
            jump_B = right.B_xyz - left.B_xyz
            jump_traction = (right.T_xyz - left.T_xyz) * normal
            interface_B_peak = max(interface_B_peak, norm(jump_B))
            interface_traction_peak = max(interface_traction_peak, norm(jump_traction))
            interface_normal_B_peak = max(interface_normal_B_peak, abs(dot(jump_B, normal)))
            _smgw_add_compensated_source3!(interface_action_reaction,
                interface_action_correction,
                sample.weight .* ((left.T_xyz - right.T_xyz) * normal))
            interface_normal_balance, interface_normal_correction =
                _smgw_add_compensated_scalar(interface_normal_balance,
                    interface_normal_correction,
                    sample.weight * (dot(left.B_xyz, normal) - dot(right.B_xyz, normal)))
        end
        for (field, sign) in ((left, 1.0), (right, -1.0))
            for a in eachindex(field.ids)
                node_a = field.ids[a]
                row = 4 * (node_a - 1) + 1
                weight = sign * sample.weight * field.N[a]
                residual[row:row+2] .+= weight .* (field.T_xyz * normal)
                residual[row+3] += weight * dot(field.B_xyz, normal)
                if jacobian
                    for (b, node_b) in enumerate(field.ids), component in 1:4
                        col = 4 * (node_b - 1) + component
                        derivative = weight .* stress_directional_derivative(field, field.N[b], component, normal)
                        for k in 1:3
                            add(row + k - 1, col, derivative[k])
                        end
                        div_derivative = component == 4 ? 0.0 :
                            weight * field.N[b] * dot(normal, view(field.rotation, :, component))
                        add(row + 3, col, div_derivative)
                    end
                end
            end
        end
    end
    interface_action_reaction .+= interface_action_correction
    interface_normal_balance += interface_normal_correction

    # Analytic natural boundary loads plus separate Q1 trace-projection
    # equations, preserving the prior traction and B-normal checks.
    for sample in data.face_quadrature
        face = mesh.faces[sample.entity_id]
        face.role == :exterior || continue
        field = spatial_field_v4(data, face.left_cell, sample, x)
        normal = collect(sample.normal)
        traction_reference = collect(_smm_traction_v1(d.source.input, sample.xyz, sample.normal))
        normal_reference = _smm_normal_v1(d.source.input, sample.xyz, sample.normal)
        _smgw_add_compensated_source3!(boundary_traction_integral,
            boundary_traction_correction, sample.weight .* traction_reference)
        boundary_normal_integral, boundary_normal_correction =
            _smgw_add_compensated_scalar(boundary_normal_integral,
                boundary_normal_correction, sample.weight * normal_reference)
        outer_traction_peak = max(outer_traction_peak, norm(field.T_xyz * normal - traction_reference))
        outer_normal_peak = max(outer_normal_peak, abs(dot(field.B_xyz, normal) - normal_reference))
        for a in eachindex(field.ids)
            node = field.ids[a]
            test_weight = sample.weight * field.N[a]
            if test_weight != 0.0
                row = 4 * (node - 1) + 1
                residual[row:row+2] .+= test_weight .* traction_reference
                residual[row+3] += test_weight * normal_reference
            end
        end
        trace_positions = findall(a -> mesh.nodes_q[1, field.ids[a]] == 1.0, eachindex(field.ids))
        for a in trace_positions
            node_a = field.ids[a]
            trace_index = layout.outer_index[node_a]
            row = layout.boundary_trace_rows.first + 4 * (trace_index - 1)
            test_weight = sample.weight * field.N[a]
            residual[row:row+2] .+= test_weight .* (field.T_xyz * normal - traction_reference)
            residual[row+3] += test_weight * (dot(field.B_xyz, normal) - normal_reference)
            if jacobian
                for (b, node_b) in enumerate(field.ids), component in 1:4
                    col = 4 * (node_b - 1) + component
                    derivative = test_weight .* stress_directional_derivative(field, field.N[b], component, normal)
                    for k in 1:3
                        add(row + k - 1, col, derivative[k])
                    end
                    div_derivative = component == 4 ? 0.0 :
                        test_weight * field.N[b] * dot(normal, view(field.rotation, :, component))
                    add(row + 3, col, div_derivative)
                end
            end
        end
    end
    boundary_traction_integral .+= boundary_traction_correction
    boundary_normal_integral += boundary_normal_correction

    # Explicit positive-e_phi toroidal cut flux row.
    flux = 0.0
    for sample in data.face_quadrature
        face = mesh.faces[sample.entity_id]
        face.axis == 3 && face.fixed == 0.0 || continue
        field = spatial_field_v4(data, face.left_cell, sample, x)
        normal = collect(sample.normal)
        flux += sample.weight * dot(field.B_xyz, normal)
        if jacobian
            for (b, node) in enumerate(field.ids), component in 1:3
                col = 4 * (node - 1) + component
                add(layout.total_flux_row, col,
                    sample.weight * field.N[b] * dot(normal, view(field.rotation, :, component)))
            end
        end
    end
    residual[layout.total_flux_row] = flux - checked.flux_Wb
    matrix = jacobian ? sparse(ii, jj, vv, layout.total_rows, checked.ndofs) :
        spzeros(Float64, layout.total_rows, checked.ndofs)
    all(isfinite, residual) || throw(ArgumentError("nonfinite global weak residual"))
    momentum_rows = Int[4 * (node - 1) + component for node in 1:checked.nnode for component in 1:3]
    divergence_rows = Int[4 * (node - 1) + 4 for node in 1:checked.nnode]
    boundary_momentum_rows = Int[layout.boundary_trace_rows.first + 4 * (j - 1) + k
        for j in eachindex(layout.outer_nodes) for k in 0:2]
    boundary_normal_rows = Int[layout.boundary_trace_rows.first + 4 * (j - 1) + 3
        for j in eachindex(layout.outer_nodes)]
    interface_checks = (B_jump_peak_T=interface_B_peak,
        traction_jump_peak_Pa=interface_traction_peak,
        normal_B_jump_peak_T=interface_normal_B_peak,
        action_reaction_integral_N=Tuple(interface_action_reaction))
    boundary_checks = (traction_projection_residual_N=Tuple(residual[boundary_momentum_rows]),
        normal_B_projection_residual_Wb=Tuple(residual[boundary_normal_rows]),
        pointwise_traction_mismatch_peak_Pa=outer_traction_peak,
        pointwise_normal_B_mismatch_peak_T=outer_normal_peak,
        prescribed_traction_integral_N=Tuple(boundary_traction_integral),
        prescribed_normal_B_integral_Wb=boundary_normal_integral)
    weak_momentum_balance = zeros(3)
    weak_momentum_correction = zeros(3)
    divergence_balance = 0.0
    divergence_correction = 0.0
    for node in 1:checked.nnode
        row = 4 * (node - 1)
        _smgw_add_compensated_source3!(weak_momentum_balance,
            weak_momentum_correction, (residual[row+1], residual[row+2], residual[row+3]))
        divergence_balance, divergence_correction = _smgw_add_compensated_scalar(
            divergence_balance, divergence_correction, residual[row+4])
    end
    weak_momentum_balance .+= weak_momentum_correction
    divergence_balance += divergence_correction
    source_balance = boundary_traction_integral - source_integral + interface_action_reaction
    conservation_checks = (source_integral_N=Tuple(source_integral),
        prescribed_boundary_traction_integral_N=Tuple(boundary_traction_integral),
        assembled_constant_momentum_test_N=Tuple(weak_momentum_balance),
        global_momentum_balance_defect_N=Tuple(weak_momentum_balance - source_balance),
        assembled_constant_divergence_test_Wb=divergence_balance,
        prescribed_boundary_normal_integral_Wb=boundary_normal_integral,
        interface_normal_balance_Wb=interface_normal_balance,
        global_divergence_balance_defect_Wb=divergence_balance -
            boundary_normal_integral - interface_normal_balance,
        cut_flux_Wb=flux, prescribed_flux_Wb=checked.flux_Wb,
        cut_flux_defect_Wb=flux - checked.flux_Wb,
        flux_constraint_residual_Wb=residual[layout.total_flux_row])
    (schema="spatial-global-shared-q1-weak-assembly-v1", revision=_SMGW_OPERATOR_REVISION_V1,
        residual=residual, row_scales=scales, row_blocks=layout.row_blocks,
        row_supports=layout.row_supports, jacobian=matrix,
        node_order=layout.node_order, element_nodes=layout.element_nodes,
        row_layout=layout.public_row_layout, interface_checks=interface_checks, boundary_checks=boundary_checks,
        conservation_checks=conservation_checks,
        cut_flux_Wb=flux, prescribed_flux_Wb=checked.flux_Wb,
        jacobian_assembled=Bool(jacobian))
end

function spatial_global_weak_physical_checks_v1(d, data, x;
        flux_Wb=d.flux.nominal_Wb, residual_partition=:spatial_native)
    checked = _smgw_validate_inputs_v1(d, data, x, flux_Wb; residual_partition)
    source_sq = 0.0; div_sq = 0.0; volume = 0.0
    source_integral = zeros(3); source_correction = zeros(3)
    strong_momentum_integral = zeros(3)
    strong_momentum_peak = 0.0; div_peak = 0.0
    for sample in data.volume
        field = spatial_field_v4(data, sample.entity_id, sample, x)
        source = collect(_smm_source_v1(d.source.input, sample.xyz))
        divT = cross(field.J_xyz, field.B_xyz) - field.gradp_xyz +
            field.B_xyz .* (field.divB / _SMR_MU0)
        defect = divT - source
        _smgw_add_compensated_source3!(source_integral, source_correction,
            sample.weight .* source)
        strong_momentum_integral .+= sample.weight .* divT
        source_sq += sample.weight * dot(defect, defect)
        div_sq += sample.weight * field.divB^2
        volume += sample.weight
        strong_momentum_peak = max(strong_momentum_peak, norm(defect))
        div_peak = max(div_peak, abs(field.divB))
    end
    source_integral .+= source_correction
    volume > 0.0 || throw(ArgumentError("empty physical-check volume"))
    interface_B_peak = 0.0; interface_traction_peak = 0.0; interface_normal_B_peak = 0.0
    interface_action_reaction = zeros(3)
    outer_traction_peak = 0.0; outer_normal_B_peak = 0.0
    outer_traction_integral = zeros(3); outer_normal_integral = 0.0
    cut_flux = 0.0
    for sample in data.face_quadrature
        face = checked.mesh.faces[sample.entity_id]
        normal = collect(sample.normal)
        if face.role == :interface
            left = spatial_field_v4(data, face.left_cell, sample, x)
            right = spatial_field_v4(data, face.right_cell, sample, x)
            jumpB = right.B_xyz - left.B_xyz
            jumpT = (right.T_xyz - left.T_xyz) * normal
            jumpBn = dot(jumpB, normal)
            interface_B_peak = max(interface_B_peak, norm(jumpB))
            interface_traction_peak = max(interface_traction_peak, norm(jumpT))
            interface_normal_B_peak = max(interface_normal_B_peak, abs(jumpBn))
            interface_action_reaction .+= sample.weight .* ((left.T_xyz - right.T_xyz) * normal)
        elseif face.role == :exterior
            field = spatial_field_v4(data, face.left_cell, sample, x)
            tdefect = field.T_xyz * normal - collect(_smm_traction_v1(d.source.input, sample.xyz, sample.normal))
            ndefect = dot(field.B_xyz, normal) - _smm_normal_v1(d.source.input, sample.xyz, sample.normal)
            outer_traction_peak = max(outer_traction_peak, norm(tdefect))
            outer_normal_B_peak = max(outer_normal_B_peak, abs(ndefect))
            outer_traction_integral .+= sample.weight .* tdefect
            outer_normal_integral += sample.weight * ndefect
        end
        if face.axis == 3 && face.fixed == 0.0
            field = spatial_field_v4(data, face.left_cell, sample, x)
            cut_flux += sample.weight * dot(field.B_xyz, normal)
        end
    end
    (volume_m3=volume, source_integral_N=Tuple(source_integral),
        strong_momentum_integral_N=Tuple(strong_momentum_integral),
        integrated_momentum_balance_N=Tuple(strong_momentum_integral - source_integral),
        strong_momentum_defect_L2=sqrt(source_sq), strong_momentum_defect_peak_N_m3=strong_momentum_peak,
        divB_RMS_T=sqrt(div_sq / volume), divB_peak_T=div_peak,
        interface_B_jump_peak_T=interface_B_peak,
        interface_traction_jump_peak_Pa=interface_traction_peak,
        interface_normal_B_jump_peak_T=interface_normal_B_peak,
        interface_action_reaction_integral_N=Tuple(interface_action_reaction),
        outer_traction_mismatch_peak_Pa=outer_traction_peak,
        outer_normal_B_mismatch_peak_T=outer_normal_B_peak,
        outer_traction_mismatch_integral_N=Tuple(outer_traction_integral),
        outer_normal_B_mismatch_integral_Wb=outer_normal_integral,
        toroidal_cut_flux_Wb=cut_flux, prescribed_flux_Wb=checked.flux_Wb,
        toroidal_flux_defect_Wb=cut_flux - checked.flux_Wb,
        authority=:no_publish, physical_validation=:unsupported)
end

function _smgw_scaled_lower_bounds_v1(x, column_scales)
    lower = fill(-Inf, length(x))
    for index in 4:4:length(x)
        pressure = x[index]
        _smr_pressure_feasible(pressure, column_scales[index]) ||
            throw(ArgumentError("global weak solver received an infeasible pressure"))
        lower[index] = -pressure / column_scales[index]
    end
    lower
end

"""Route all actual global-weak rows through the explicit LS/KKT partition API."""
function _smgw_inhouse_partition_v1(assembly, admission, seal)
    n = size(assembly.jacobian, 2)
    semantic_identities = _smgw_current_semantic_identities_v1()
    row_ids = Tuple("global-weak-row-$(row):$(assembly.row_blocks[row])"
        for row in eachindex(assembly.residual))
    consumer_identity = (candidate_hash=string(admission.candidate_hash),
        context_hash=string(admission.context_hash),
        declaration_hash=string(admission.declaration_hash),
        input_hash=string(admission.input_hash),
        geometry_receipt_hash=string(seal.receipt_hash),
        operator_data_fingerprint=string(seal.data_fingerprint),
        solver_semantic_hash=semantic_identities.solver_semantic_hash,
        provider_semantic_hash=semantic_identities.provider_semantic_hash,
        contract_semantic_hash=semantic_identities.contract_semantic_hash,
        row_layout_hash=string(canonical_hash(assembly.row_layout)))
    InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_partition_v1(
        candidate_hash=consumer_identity.candidate_hash,
        consumer_identity=consumer_identity,
        least_squares_row_ids=row_ids,
        least_squares_residual=assembly.residual,
        least_squares_jacobian=assembly.jacobian,
        least_squares_row_scales=assembly.row_scales,
        equality_row_ids=(), equality_residual=Float64[],
        equality_jacobian=spzeros(Float64, 0, n))
end

_smgw_partition_record_v1(partition) = (
    partition_mode=:inhouse_kkt,
    step_identity=_smgw_step_identity_v1(:inhouse_kkt),
    step_identity_hash=string(canonical_hash(_smgw_step_identity_v1(:inhouse_kkt))),
    schema=partition.identity.schema,
    solver_semantic_hash=partition.identity.solver_semantic_hash,
    partition_hash=partition.partition_hash,
    consumer_identity_hash=partition.consumer_identity_hash,
    least_squares_rows=length(partition.least_squares_row_ids),
    equality_rows=length(partition.equality_row_ids),
    row_identity_hash=partition.row_identity_hash,
    row_scale_hash=partition.least_squares_row_scale_hash,
    raw_residual_hash=string(canonical_hash(Tuple(partition.raw_least_squares_residual)))
)

function _smgw_inhouse_step_input_v1(partition, scaled_state, pressure_indices, column_scales)
    J = partition.scaled_least_squares_jacobian * spdiagm(0 => column_scales)
    ri, ci, values = findnz(J)
    (schema="inhouse-weighted-residual-kkt-input-v1",
        partition_hash=partition.partition_hash,
        rows=size(J, 1), columns=size(J, 2), index_base=1,
        jacobian=(format=:coordinate, row_indices=Tuple(ri),
            column_indices=Tuple(ci), values=Tuple(values)),
        scaled_residual=Tuple(partition.scaled_least_squares_residual),
        column_scales=Tuple(column_scales),
        column_scale_hash=string(canonical_hash(Tuple(column_scales))),
        equality_residual=Tuple(partition.equality_residual),
        equality_jacobian=(rows=size(partition.equality_jacobian, 1),
            columns=size(partition.equality_jacobian, 2), nnz=nnz(partition.equality_jacobian)),
        pressure_step_lower_bounds=Tuple((index=i, lower=-scaled_state[i])
            for i in pressure_indices),
        coordinates=:dimensionless_column_scaled_step,
        objective=:half_squared_norm_scaled_residual_plus_exact_equalities)
end

"""Run the N1 successor solve with unchanged 12-update/120-second gates.

`residual_partition=:inhouse_kkt` is an opt-in real-consumer seam. It passes
the complete global weak residual (including outer trace and total flux) as
scaled least-squares rows to InHouse's explicit partition API, then uses its
active-set KKT routine for the bounded Gauss-Newton linear step. The KKT equality
inventory stays empty; the existing spatial Armijo search remains the nonlinear
acceptance layer. The default `:spatial_native` path is unchanged.
"""
function solve_spatial_global_weak_state_v1(d, data, initial; flux_Wb=d.flux.nominal_Wb,
        admission, geometry_receipt, residual_partition=:spatial_native, stage_trace=nothing)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    admission isa _SMGWOperatorAdmissionV1 && admission.declaration === d ||
        throw(ArgumentError("global weak solver requires its admitted candidate declaration"))
    seal = _smgw_trace_stage_v1(stage_trace, "binding_capture", () ->
        _smgw_capture_operator_binding_v1(admission, data, geometry_receipt, initial;
            residual_partition, stage_trace))
    _smgw_stage_diagnostic_v1(stage_trace, "binding_guard_construct_begin")
    binding_guard = _SMGWOperatorBindingGuardCallV1(stage_trace, seal, admission,
        d, data, geometry_receipt, initial, residual_partition)
    _smgw_stage_diagnostic_v1(stage_trace, "binding_guard_construct_end")
    _smgw_stage_diagnostic_v1(stage_trace, "input_validate_trace_begin")
    _smgw_trace_event_v1(stage_trace, "input_validate", :begin)
    checked = try
        _smgw_validate_inputs_v1(d, data, initial, flux_Wb; residual_partition)
    catch err
        _smgw_stage_diagnostic_v1(stage_trace, "input_validate_error";
            error=err, backtrace=catch_backtrace())
        rethrow()
    finally
        _smgw_trace_event_v1(stage_trace, "input_validate", :end)
        _smgw_stage_diagnostic_v1(stage_trace, "input_validate_trace_end")
    end
    return _smgw_solve_spatial_global_weak_after_input_validation_v1(
        d, data, initial, flux_Wb, admission, residual_partition, stage_trace,
        seal, binding_guard, checked)
end

@inline function _smgw_lm_next_damping_multiplier_v1(multiplier, gain_ratio)
    isfinite(multiplier) && 1.0e-5 <= multiplier <= 1.0e2 ||
        throw(ArgumentError("Q1_8 LM damping multiplier is outside its bounded policy"))
    isfinite(gain_ratio) || return Float64(multiplier)
    gain_ratio > 0.75 ? max(1.0e-5, 0.1 * multiplier) :
        (gain_ratio < 0.25 ? min(1.0e2, 10.0 * multiplier) : Float64(multiplier))
end

@noinline function _smgw_lm_curvature_scale_v1(A, r0, b, r1, alpha;
        damping_multiplier=1.0)
    isfinite(damping_multiplier) && 1.0e-5 <= damping_multiplier <= 1.0e2 || return nothing
    length(r0) == length(b) == length(r1) == size(A, 1) || return nothing
    isfinite(alpha) && 0.0 < alpha < 0.5 || return nothing
    all(isfinite, r0) && all(isfinite, b) && all(isfinite, r1) || return nothing
    n = size(A, 2)
    n > 0 || return nothing
    curvature = Vector{Float64}(undef, length(r0))
    @inbounds for i in eachindex(curvature)
        curvature[i] = Float64(r1[i]) - Float64(r0[i]) - Float64(b[i])
    end
    all(isfinite, curvature) || return nothing
    bnorm = norm(b)
    cnorm = norm(curvature)
    isfinite(bnorm) && isfinite(cnorm) || return nothing
    ratio = alpha * cnorm / max(bnorm, eps(Float64))
    isfinite(ratio) && ratio > 0.5 || return nothing
    # Damping rule in scaled step coordinates. The previous accepted LM
    # actual-to-linear-predicted gain ratio adjusts this multiplier; its
    # initial value is 1e-2. The mean diagonal avoids forming normal equations.
    # lambda = 1e-2 * multiplier * min(1, ratio)^2 * trace(J'J)/n.
    mean_column_norm2 = sum(abs2, A.nzval) / n
    isfinite(mean_column_norm2) && mean_column_norm2 > 0.0 || return nothing
    factor = Float64(damping_multiplier) * 1.0e-2 * min(1.0, ratio)^2
    lambda = factor * mean_column_norm2
    isfinite(lambda) && lambda > 0.0 || return nothing
    (lambda=Float64(lambda), curvature_ratio=Float64(ratio),
        curvature_norm=Float64(cnorm), linearized_norm=Float64(bnorm),
        mean_column_norm2=Float64(mean_column_norm2), damping_factor=Float64(factor))
end

@noinline function _smgw_quartic_ray_alpha_v1(r0, b, r1)
    length(r0) == length(b) == length(r1) || return nothing
    all(isfinite, r0) && all(isfinite, b) && all(isfinite, r1) || return nothing

    c = Vector{Float64}(undef, length(r0))
    @inbounds for i in eachindex(c)
        c[i] = Float64(r1[i]) - Float64(r0[i]) - Float64(b[i])
    end
    all(isfinite, c) || return nothing
    scale = max(norm(r0), norm(b), norm(r1))
    scale > 0.0 || return nothing
    norm(c) > 256eps(Float64) * scale || return nothing

    rb = dot(r0, b)
    rc = dot(r0, c)
    bb = dot(b, b)
    bc = dot(b, c)
    cc = dot(c, c)
    q = Float64[rb, 2rc + bb, 3bc, 2cc]
    all(isfinite, q) || return nothing
    qscale = maximum(abs, q)
    qscale > 0.0 || return nothing
    q ./= qscale
    abs(q[4]) > 256eps(Float64) || return nothing

    companion = [0.0 0.0 -q[1] / q[4];
                 1.0 0.0 -q[2] / q[4];
                 0.0 1.0 -q[3] / q[4]]
    roots = eigvals(companion)
    alphas = Float64[0.0, 1.0]
    for root in roots
        isfinite(real(root)) && isfinite(imag(root)) || return nothing
        abs(imag(root)) <= 256eps(Float64) * max(1.0, abs(real(root))) || continue
        alpha = real(root)
        tol = 256eps(Float64) * max(1.0, abs(alpha))
        -tol <= alpha <= 1.0 + tol || continue
        push!(alphas, clamp(Float64(alpha), 0.0, 1.0))
    end

    rnorm2 = dot(r0, r0)
    isfinite(rnorm2) || return nothing
    best_alpha = 0.0
    best_value = rnorm2
    for alpha in alphas
        value = rnorm2 + 2rb * alpha + (bb + 2rc) * alpha^2 +
            2bc * alpha^3 + cc * alpha^4
        isfinite(value) || return nothing
        if value < best_value
            best_alpha = alpha
            best_value = value
        end
    end
    0.0 < best_alpha < 1.0 ? best_alpha : nothing
end

function _smgw_lm_chord_corrector_inputs_v1(r0, b, q, alpha, raw_step, lower)
    length(r0) == length(b) == length(q) || return nothing
    length(raw_step) == length(lower) || return nothing
    isfinite(alpha) && 0.0 < alpha < 1.0 || return nothing
    all(isfinite, r0) && all(isfinite, b) && all(isfinite, q) && all(isfinite, raw_step) || return nothing
    all(v -> !isnan(v) && v != Inf, lower) || return nothing
    n = length(raw_step)
    n > 0 || return nothing
    length(r0) > 0 || return nothing
    residual = Float64.(r0) .+ Float64(alpha) .* Float64.(b) .+ Float64(alpha)^2 .* Float64.(q)
    shifted_lower = Float64.(lower) .- Float64(alpha) .* Float64.(raw_step)
    all(isfinite, residual) && all(v -> !isnan(v) && v != Inf && v <= 0.0, shifted_lower) || return nothing
    (residual=residual, lower=shifted_lower, alpha=Float64(alpha),
        curvature=Float64.(q), shifted_finite_bounds=count(isfinite, shifted_lower))
end

function _smgw_lm_chord_corrector_v1(A, r0, b, q, alpha, raw_step, lower, lambda;
        seconds=6.0, stage_trace=nothing, stage_name="native_bounded_lm_chord_corrector",
        row_weight_policy=:l2_only)
    n = size(A, 2)
    size(A, 1) == length(r0) || return nothing
    length(raw_step) == n && length(lower) == n || return nothing
    isfinite(lambda) && lambda > 0.0 || return nothing
    inputs = _smgw_lm_chord_corrector_inputs_v1(r0, b, q, alpha, raw_step, lower)
    inputs === nothing && return nothing
    system_A = A
    system_residual = inputs.residual
    system_lambda = Float64(lambda)
    mean_column_norm2 = nothing
    row_weight_min = 1.0
    row_weight_max = 1.0
    if row_weight_policy === :l2_plus_p8_tail_u6_v1
        residual_max = maximum(abs, inputs.residual; init=0.0)
        isfinite(residual_max) && residual_max > 0.0 || return nothing
        weights = sqrt.(1.0 .+ (abs.(inputs.residual) ./ residual_max).^6)
        all(w -> isfinite(w) && 1.0 <= w <= sqrt(2.0), weights) || return nothing
        system_A = spdiagm(0 => weights) * A
        system_residual = weights .* inputs.residual
        original_mean_column_norm2 = sum(abs2, A.nzval) / n
        weighted_mean_column_norm2 = sum(abs2, system_A.nzval) / n
        isfinite(original_mean_column_norm2) && original_mean_column_norm2 > 0.0 &&
            isfinite(weighted_mean_column_norm2) && weighted_mean_column_norm2 > 0.0 || return nothing
        system_lambda = Float64(lambda) * (weighted_mean_column_norm2 / original_mean_column_norm2)
        isfinite(system_lambda) && system_lambda > 0.0 || return nothing
        all(isfinite, system_residual) || return nothing
        mean_column_norm2 = weighted_mean_column_norm2
        row_weight_min = minimum(weights)
        row_weight_max = maximum(weights)
    elseif row_weight_policy !== :l2_only
        throw(ArgumentError("unsupported Q1_8 chord-corrector row-weight policy"))
    end
    system = _smgw_trace_stage_v1(stage_trace, "$(stage_name)_augment", () -> (
        matrix=vcat(system_A, spdiagm(0 => fill(sqrt(system_lambda), n))),
        residual=vcat(system_residual, zeros(n)), lower=inputs.lower))
    solved = _smgw_trace_stage_v1(stage_trace, stage_name, () ->
        SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
            system.matrix, system.residual, system.lower; seconds, stage_trace))
    correction_raw = solved.step
    correction_valid = length(correction_raw) == n &&
        all(v -> v isa Real && isfinite(v), correction_raw)
    correction = correction_valid ? Float64.(collect(correction_raw)) : zeros(n)
    composite = Float64(alpha) .* Float64.(raw_step) .+ correction
    composite_valid = correction_valid && all(isfinite, composite)
    (inputs=inputs, solved=solved, correction=correction,
        composite=composite_valid ? composite : nothing, valid=composite_valid,
        row_weight_policy=row_weight_policy, row_weight_min=row_weight_min,
        row_weight_max=row_weight_max, mean_column_norm2=mean_column_norm2,
        lambda=system_lambda)
end

# Candidate insertion beside the existing chord helper; not a standalone runner.
function _smgw_m1n1_refine_chord_v1(A,r,x,columns,raw_step,alpha0,chord,lambda,
        row_scales,row_blocks,assemble_trial,binding_guard,deadline;initial_endpoint=nothing)
    n=length(x);objective=dot(r,r);gradient=A'*r
    started=time();events=NamedTuple[]
    budget_ok()=time()<deadline
    event!(stage,reason;details...) = push!(events,
        (;stage,reason,elapsed_seconds=time()-started,time_eligible=budget_ok(),details...))
    pressure_violations(y)=Tuple(i for i in 4:4:n if !_smr_pressure_feasible(y[i],columns[i]))
    project(y)=begin
        for i in 4:4:n
            _smr_pressure_feasible(y[i],columns[i]) && y[i]<0 && (y[i]=0.0)
        end
        y
    end
    feasible(y)=all(isfinite,y) && all(i->_smr_pressure_feasible(y[i],columns[i]),4:4:n)
    endpoint_cache=initial_endpoint
    if initial_endpoint!==nothing
        initial_endpoint.state==x.+columns.*chord.composite &&
            initial_endpoint.assembly.row_scales==row_scales &&
            initial_endpoint.assembly.row_blocks==row_blocks &&
            length(initial_endpoint.assembly.residual)==length(row_scales) &&
            all(isfinite,initial_endpoint.state) && all(isfinite,initial_endpoint.assembly.residual) &&
            initial_endpoint.binding==binding_guard() ||
            throw(ArgumentError("m1n1 initial endpoint differs from current chord state, rows, scales, or binding"))
    end
    function assemble(y)
        if !budget_ok()
            event!(:assembly,:deadline_reached)
            return nothing
        end
        before=binding_guard()
        value=try
            assemble_trial(y)
        catch err
            numeric_failure=err isa DomainError || (err isa ArgumentError &&
                occursin("nonfinite global weak residual",sprint(showerror,err)))
            (err isa InterruptException || !numeric_failure) && rethrow()
            event!(:assembly,:numeric_failure;error_type=string(typeof(err)),error=sprint(showerror,err))
            nothing
        end
        binding_guard()==before || throw(ArgumentError("m1n1 refinement operator binding changed"))
        value===nothing && return nothing
        value.row_scales==row_scales && value.row_blocks==row_blocks ||
            throw(ArgumentError("m1n1 refinement changed row space"))
        if !budget_ok() || !all(isfinite,value.residual)
            event!(:assembly,budget_ok() ? :nonfinite_residual : :late_result)
            return nothing
        end
        value
    end
    function full_endpoint(y,stage,inner)
        budget_ok() || return nothing
        if endpoint_cache!==nothing && y==endpoint_cache.state
            endpoint_cache.binding==binding_guard() ||
                throw(ArgumentError("m1n1 endpoint cache operator binding changed"))
            event!(:endpoint_cache,:reused;consumer_stage=stage,inner)
            return endpoint_cache.assembly
        end
        value=assemble(y)
        if value!==nothing
            endpoint_cache=(state=copy(y),assembly=value,binding=binding_guard())
        end
        value
    end
    function ray(step,stage,inner)
        if !budget_ok() || !all(isfinite,step) || !(dot(gradient,step)<0)
            reason=!budget_ok() ? :deadline_reached : !all(isfinite,step) ? :nonfinite_step : :non_descent
            event!(stage,reason;inner)
            return nothing
        end
        endpoint=project(x.+columns.*step)
        if !feasible(endpoint)
            event!(stage,:pressure_or_nonfinite_endpoint;inner,
                pressure_violating_columns=pressure_violations(endpoint),nonfinite_columns=Tuple(findall(!isfinite,endpoint)))
            return nothing
        end
        ending=full_endpoint(endpoint,stage,inner)
        if ending===nothing
            event!(stage,:endpoint_assembly_unavailable;inner)
            return nothing
        end
        ray_alpha=_smgw_quartic_ray_alpha_v1(r,A*step,ending.residual./row_scales)
        if ray_alpha!==nothing
            raw_candidate=x.+ray_alpha.*columns.*step
            projected_candidate=project(copy(raw_candidate))
            raw_candidate==projected_candidate && feasible(projected_candidate) || (ray_alpha=nothing)
        end
        start=ray_alpha===nothing ? 1.0 : ray_alpha
        result=MultiTopologyNonlinearSolveV1.accepted_step_v1(x,step,columns;
            objective_before=objective,directional_derivative=2dot(gradient,step),
            max_backtracks=20,alpha0=start,reduction=0.5,minimum_alpha=0.0,
            armijo_fraction=2e-4,require_strict_decrease=true,
            assemble_trial=y->y==endpoint && budget_ok() ? ending : assemble(y),
            assembly_ready=a->a!==nothing,unavailable_reason=_->(kind=:refinement_time_ineligible,),
            residual_for_merit=a->a.residual./row_scales,merit=(_,rr)->dot(rr,rr),
            project_state=project,feasible=feasible,
            changed=(before,after)->after!=before && _smr_scaled_state_change(before,after,columns),
            evaluation_record=_->nothing,binding_guard=binding_guard,continue_trial=budget_ok)
        if !budget_ok() || result.status!==:accepted
            event!(stage,budget_ok() ? :line_search_rejected : :late_line_search;
                inner,line_search_status=result.status,line_search_failure=result.failure,
                trials=Tuple((alpha=t.alpha,feasible=t.feasible,evaluated=t.evaluated,
                    objective_after=t.objective_after,armijo=t.armijo,strict_decrease=t.strict_decrease,
                    pressure_violating_columns=pressure_violations(t.state)) for t in result.trials))
            return nothing
        end
        event!(stage,:accepted;inner,objective=result.accepted_objective)
        (objective=result.accepted_objective,alpha0=start,ray_alpha=ray_alpha,
            state=result.state,assembly=result.accepted_assembly)
    end
    chain=NamedTuple[];selected_chain=();selected=nothing
    initial_step=copy(chord.composite);baseline=ray(initial_step,:baseline_ray,0)
    if baseline!==nothing && budget_ok()
        best_objective=baseline.objective
        augmented=vcat(A,spdiagm(0=>fill(sqrt(lambda),n)))
        working=collect(chord.solved.active_indices);free=collect(chord.solved.free_indices)
        factor_started=time();factor=qr(augmented[:,free])
        event!(:initial_factorization,budget_ok() ? :ready : :late_result;
            factor_seconds=time()-factor_started)
        cumulative=copy(chord.correction);step=copy(initial_step)
        for inner in 1:2
            if !budget_ok()
                event!(:inner_corrector,:deadline_reached;inner)
                break
            end
            y=project(x.+columns.*step)
            if !feasible(y)
                event!(:inner_corrector,:pressure_or_nonfinite_endpoint;inner,
                    pressure_violating_columns=pressure_violations(y),nonfinite_columns=Tuple(findall(!isfinite,y)))
                break
            end
            value=full_endpoint(y,:inner_corrector,inner)
            if value===nothing
                event!(:inner_corrector,:assembly_unavailable;inner)
                break
            end
            residual=value.residual./row_scales;lower=_smgw_scaled_lower_bounds_v1(y,columns)
            rhs_residual=vcat(residual,zeros(n))
            cached_started=time();correction=zeros(n);correction[working].=lower[working]
            correction[free].=factor\(-rhs_residual-augmented[:,working]*correction[working])
            kkt=SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
                augmented,rhs_residual,lower,correction,working)
            cache_pass=kkt.passed;refactor=false
            event!(:cached_corrector,cache_pass ? :kkt_passed : :kkt_failed;inner,kkt,
                solve_seconds=time()-cached_started,
                pressure_violating_columns=Tuple(t.index for t in kkt.primal_coordinate_tolerances if
                    correction[t.index]<lower[t.index]-t.tolerance))
            if !cache_pass
                remaining=max(0.0,deadline-time())
                if !(remaining>0)
                    event!(:bounded_fallback,:deadline_reached;inner,kkt)
                    break
                end
                fallback_started=time()
                bounded=SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
                    augmented,rhs_residual,lower;seconds=remaining)
                fallback_eligible=budget_ok() && bounded.converged && bounded.kkt.passed
                event!(:bounded_fallback,!budget_ok() ? :late_result :
                    !bounded.converged ? :not_converged : !bounded.kkt.passed ? :kkt_failed : :kkt_passed;
                    inner,kkt=bounded.kkt,converged=bounded.converged,
                    bounded_status=bounded.status,bounded_failure=bounded.failure,
                    solve_seconds=time()-fallback_started,seconds_allowance=remaining,
                    pressure_violating_columns=Tuple(t.index for t in bounded.kkt.primal_coordinate_tolerances if
                        bounded.step[t.index]<lower[t.index]-t.tolerance))
                fallback_eligible || break
                correction=Float64.(collect(bounded.step));new_free=collect(bounded.free_indices)
                working=collect(bounded.active_indices);kkt=bounded.kkt
                if new_free!=free
                    free=new_free;factor_started=time();factor=qr(augmented[:,free]);refactor=true
                    event!(:cache_refactor,budget_ok() ? :ready : :late_result;
                        inner,factor_seconds=time()-factor_started)
                end
            end
            if !budget_ok() || !kkt.passed
                event!(:inner_corrector,!budget_ok() ? :late_result : :kkt_failed;inner,kkt)
                break
            end
            cumulative .+=correction
            proposed=alpha0.*raw_step.+cumulative
            proposed_state=project(x.+columns.*proposed)
            if !feasible(proposed_state)
                event!(:proposed_composite,:pressure_or_nonfinite_endpoint;inner,kkt,
                    pressure_violating_columns=pressure_violations(proposed_state),
                    nonfinite_columns=Tuple(findall(!isfinite,proposed_state)))
                break
            end
            candidate=ray(proposed,:candidate_ray,inner)
            if !budget_ok()
                event!(:inner_corrector,:late_ray_result;inner,kkt)
                break
            end
            entry=(inner=inner,eligible=true,kkt=kkt,
                kkt_scope=:local_augmented_shifted_lower_bound_subproblem,
                correction=Tuple(correction),residual=Tuple(residual),
                lower=Tuple(isfinite(v) ? v : nothing for v in lower),
                before_composite=Tuple(step),resulting_composite=Tuple(proposed),
                cache_pass=cache_pass,refactor=refactor,active_indices=Tuple(working))
            push!(chain,entry)
            improved=candidate!==nothing && candidate.objective<best_objective
            event!(:inner_corrector,:completed;inner=inner,eligible=true,cache_pass=cache_pass,refactor=refactor,
                candidate_accepted=candidate!==nothing,
                objective=candidate===nothing ? nothing : candidate.objective,improved=improved)
            if improved
                best_objective=candidate.objective
                selected=(step=copy(proposed),ray=candidate)
                selected_chain=Tuple(chain)
                event!(:inner_corrector,:first_improvement_selected;inner)
                break
            end
            step=proposed
        end
    end
    # A late result must not replace the original direction, even if numerically good.
    eligible=budget_ok() && selected!==nothing
    (selected=eligible,step=eligible ? selected.step : initial_step,
        ray=eligible ? selected.ray : nothing,
        record=(schema="m1n1-bounded-chord-refinement-v1",selected=eligible,
            status=budget_ok() ? :bounded_refinement_finished : :time_ineligible,
            extra_corrector_limit=2,shared_seconds_limit=6.0,
            initial_composite=Tuple(initial_step),
            baseline_objective=baseline===nothing ? nothing : baseline.objective,
            selected_objective=eligible ? selected.ray.objective : nothing,
            selected_chain=eligible ? selected_chain : (),events=Tuple(events)))
end

function _smgw_m1n1_refinement_identity_v1(lm,record)
    hasproperty(lm,:corrector_kkt_scope) &&
        lm.corrector_kkt_scope in (:initial_chord_augmented_shifted_lower_bound_subproblem,
            "initial_chord_augmented_shifted_lower_bound_subproblem") || return false
    refinement=lm.refinement
    refinement.schema=="m1n1-bounded-chord-refinement-v1" && refinement.selected===true &&
        refinement.shared_seconds_limit==6.0 && refinement.extra_corrector_limit==2 &&
        refinement.elapsed_seconds<=6.0 && refinement.elapsed_seconds>=0.0 &&
        isfinite(refinement.baseline_objective) && isfinite(refinement.selected_objective) &&
        0.0<=refinement.selected_objective<refinement.baseline_objective || return false
    chain=refinement.selected_chain;1<=length(chain)<=2 || return false
    li=record.linear_input;matrix=li.matrix;n=li.columns
    A=sparse(Int.(collect(matrix.row_indices)),Int.(collect(matrix.column_indices)),
        Float64.(collect(matrix.values)),li.rows,n)
    augmented=vcat(A,spdiagm(0=>fill(sqrt(Float64(lm.lambda)),n)))
    correction=Float64.(collect(lm.correction_step));raw=Float64.(collect(lm.raw_step))
    before=Float64(lm.corrector_alpha).*raw.+correction
    _smgw_json_equal_v1(refinement.initial_composite,Tuple(before)) || return false
    for (index,entry) in enumerate(chain)
        entry.inner==index && entry.eligible===true && entry.kkt.passed &&
            String(entry.kkt_scope)=="local_augmented_shifted_lower_bound_subproblem" &&
            _smgw_json_equal_v1(entry.before_composite,Tuple(before)) || return false
        audit=SpatialBoundedLinearStepV1.bounded_step_kkt_v1(augmented,
            vcat(Float64.(collect(entry.residual)),zeros(n)),
            [v===nothing ? -Inf : Float64(v) for v in entry.lower],
            Float64.(collect(entry.correction)),Int.(collect(entry.active_indices)))
        audit.passed || return false
        correction .+=Float64.(collect(entry.correction))
        before=Float64(lm.corrector_alpha).*raw.+correction
        _smgw_json_equal_v1(entry.resulting_composite,Tuple(before)) || return false
    end
    _smgw_json_equal_v1(record.step,Tuple(before)) && _smgw_json_equal_v1(lm.step,Tuple(before))
end

@inline function _smgw_curvature_step_enabled_v1(input, residual_partition)
    residual_partition === :spatial_native &&
        (input.mesh.level === :q1_8 ||
         (input.mesh.level === :q1_4 && input.geometry.model === :m1n1_ripple_torus))
end

@noinline function _smgw_solve_spatial_global_weak_after_input_validation_v1(
        d, data, initial, flux_Wb, admission, residual_partition, stage_trace,
        seal, binding_guard, checked)
    policy = d.source.input.numerics
    curvature_step_enabled = _smgw_curvature_step_enabled_v1(d.source.input, residual_partition)
    mapped_q1_4_step = curvature_step_enabled && d.source.input.mesh.level === :q1_4
    lm_direction_label = mapped_q1_4_step ? :q1_4_m1n1_bounded_lm_alternate : :q1_8_bounded_lm_alternate
    lm_record_schema = mapped_q1_4_step ?
        "q1-4-m1n1-bounded-lm-chord-corrector-v1" : "q1-8-bounded-lm-chord-corrector-v1"
    x = Float64.(initial)
    n = checked.ndofs
    columns = repeat([d.scaling.B_T, d.scaling.B_T, d.scaling.B_T, d.scaling.p_Pa], div(n, 4))
    history = NamedTuple[]; attempts = NamedTuple[]; states = Vector{Float64}[]
    accepted_updates = 0; last_step_norm = 0.0; last_linear_residual = nothing
    lm_extra_elapsed = 0.0
    lm_damping_multiplier = 1.0e-2
    started = time(); code = 4; reason = :iteration_limit
    rank_diagnostics = (method=:not_executed, rank_estimate=-1, columns=n,
        nullity_estimate=-1, null_modes=(), continuum_uniqueness=:unsupported)
    final = nothing
    for iteration in 0:policy.max_iterations
        for index in 4:4:n
            _smr_pressure_feasible(x[index], columns[index]) && x[index] < 0.0 && (x[index] = 0.0)
        end
        binding_guard()
        assembly = _smgw_trace_stage_v1(stage_trace, "assembly_iteration_$(iteration)", () ->
            assemble_spatial_global_weak_system_v1(d, data, x;
                flux_Wb, jacobian=true, residual_partition))
        binding_guard()
        partition = residual_partition === :inhouse_kkt ?
            _smgw_trace_stage_v1(stage_trace, "partition_iteration_$(iteration)", () ->
                _smgw_inhouse_partition_v1(assembly, admission, seal)) : nothing
        scaled_residual = partition === nothing ? assembly.residual ./ assembly.row_scales :
            partition.scaled_least_squares_residual
        unscaled_jacobian = partition === nothing ?
            spdiagm(0 => 1.0 ./ assembly.row_scales) * assembly.jacobian :
            partition.scaled_least_squares_jacobian
        scaled_jacobian = unscaled_jacobian * spdiagm(0 => columns)
        equality_residual = partition === nothing ? Float64[] : partition.equality_residual
        isempty(equality_residual) || throw(ArgumentError(
            "current Spatial global-weak consumer has no exact KKT equality rows"))
        gradient = transpose(scaled_jacobian) * scaled_residual
        z = x ./ columns
        bound_tolerance = _smr_scaled_bound_tolerance(z)
        active_pressure = [i for i in 4:4:n if z[i] <= bound_tolerance[i] && gradient[i] > 0.0]
        projected_gradient = copy(gradient); projected_gradient[active_pressure] .= 0.0
        residual_max = maximum(abs, scaled_residual)
        iteration_record = (iteration=iteration, scaled_norm=norm(scaled_residual), scaled_max=residual_max,
            blocks=_smgw_block_norms_v1(assembly), projected_gradient_norm=norm(projected_gradient),
            step_norm=last_step_norm, linear_relative_residual=last_linear_residual,
            active_pressure_indices=Tuple(active_pressure), elapsed_seconds=time() - started)
        partition === nothing || (iteration_record = merge(iteration_record,
            (residual_partition=_smgw_partition_record_v1(partition),)))
        push!(history, iteration_record)
        push!(states, copy(x))
        final = assembly
        if !all(isfinite, scaled_residual) || any(i -> !_smr_pressure_feasible(x[i], columns[i]), 4:4:n)
            code = 6; reason = :nonfinite_or_infeasible_state; break
        elseif residual_max <= policy.residual_tolerance
            code = 0; reason = :all_scaled_residuals_converged; break
        elseif norm(projected_gradient) <= policy.gradient_tolerance
            code = 2; reason = :stationary_nonzero_residual; break
        elseif iteration == policy.max_iterations
            code = 4; reason = :iteration_limit; break
        elseif time() - started >= policy.seconds
            code = 4; reason = :wall_time_budget; break
        end

        scaled_state = x ./ columns
        remaining = max(0.0, policy.seconds - (time() - started))
        if partition === nothing
            lower = _smgw_scaled_lower_bounds_v1(x, columns)
            native_step_trace = stage_trace === nothing ? nothing :
                ((name, edge, stamp) -> stage_trace(
                    "native_bounded_step_iteration_$(iteration)_$(name)", edge, stamp))
            bounded = _smgw_trace_stage_v1(stage_trace,
                "native_bounded_step_iteration_$(iteration)", () -> try
                    SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1(
                        scaled_jacobian, scaled_residual, lower; seconds=remaining,
                        stage_trace=native_step_trace)
                catch err
                    _smgw_stage_diagnostic_v1(stage_trace,
                        "native_bounded_step_iteration_$(iteration)_error";
                        error=err, backtrace=catch_backtrace())
                    rethrow()
                end)
            subproblem = SpatialBoundedLinearStepV1.bounded_linear_step_snapshot_v1(
                scaled_jacobian, scaled_residual, lower)
        else
            pressure_indices = Tuple(4:4:n)
            linear_policy = SpatialBoundedLinearStepV1.bounded_linear_step_policy_v1()
            policy.kkt_absolute_tolerance == linear_policy.kkt_absolute_tolerance ||
                throw(ArgumentError("InHouse opt-in requires the frozen spatial KKT tolerance"))
            inhouse_step = _smgw_trace_stage_v1(stage_trace,
                "kkt_step_iteration_$(iteration)", () ->
                    InHouseCoupledMHDGlobalSolveV1.solve_weighted_residual_kkt_step_v1(
                        partition; scaled_state, column_scales=columns, pressure_indices,
                        precomputed_scaled_jacobian=scaled_jacobian,
                        stationarity_tolerance=policy.kkt_absolute_tolerance,
                        bound_dual_tolerance=policy.kkt_absolute_tolerance,
                        max_active_set_iterations=8n + 16, seconds=remaining))
            inhouse_step.status in (:ok, :numerical_fail, :resource_interruption) ||
                throw(ArgumentError("unexpected InHouse weighted-residual KKT status"))
            lower = _smgw_scaled_lower_bounds_v1(x, columns)
            inhouse_audit = inhouse_step.status === :ok ?
                SpatialBoundedLinearStepV1.bounded_step_kkt_v1(
                    scaled_jacobian, scaled_residual, lower, inhouse_step.step,
                    inhouse_step.active_bounds; policy=linear_policy) : nothing
            inhouse_converged = inhouse_step.status === :ok && inhouse_audit.passed
            bounded = (converged=inhouse_converged,
                status=inhouse_converged ? :inhouse_kkt_converged :
                    (inhouse_step.status === :ok ? :inhouse_kkt_audit_failed : inhouse_step.reason),
                step=inhouse_step.status === :ok ? collect(inhouse_step.step) : zeros(n),
                backend=:inhouse_weighted_residual_kkt,
                diagnostics=(schema=inhouse_step.schema,
                    solver_semantic_hash=inhouse_step.solver_semantic_hash,
                    partition_hash=inhouse_step.partition_hash,
                    step_identity=inhouse_step.step_identity,
                    step_identity_hash=inhouse_step.step_identity_hash,
                    status=inhouse_step.status, reason=inhouse_step.reason,
                    active_bounds=inhouse_step.active_bounds,
                    active_set_trace=inhouse_step.active_set_trace,
                    stationarity=get(inhouse_step, :stationarity, nothing),
                    dual_violation=get(inhouse_step, :dual_violation, nothing),
                    complementarity=get(inhouse_step, :complementarity, nothing),
                    kkt_relative_defect=get(inhouse_step, :kkt_relative_defect, nothing),
                    spatial_bound_kkt_audit=inhouse_audit))
            subproblem = _smgw_inhouse_step_input_v1(
                partition, scaled_state, pressure_indices, columns)
        end
        if !bounded.converged
            code = bounded.status == :wall_time_budget ? 4 : 7
            reason = bounded.status == :wall_time_budget ? :bounded_step_wall_time_budget : :bounded_step_numerical_failure
            attempt_record = (attempt_index=length(attempts)+1, iteration=iteration,
                accepted=false, state_before_hash=canonical_hash(Tuple(x)), linear_input=subproblem,
                bounded_step=bounded, elapsed_seconds=time() - started)
            partition === nothing || (attempt_record = merge(attempt_record,
                (residual_partition=_smgw_partition_record_v1(partition),)))
            push!(attempts, attempt_record)
            break
        end
        step = Float64.(collect(bounded.step))
        all(isfinite, step) || begin
            code = 7; reason = :nonfinite_bounded_step
            attempt_record = (attempt_index=length(attempts)+1, iteration=iteration,
                accepted=false, state_before_hash=canonical_hash(Tuple(x)), linear_input=subproblem,
                bounded_step=bounded, elapsed_seconds=time() - started)
            partition === nothing || (attempt_record = merge(attempt_record,
                (residual_partition=_smgw_partition_record_v1(partition),)))
            push!(attempts, attempt_record)
            break
        end
        linearized_delta = scaled_jacobian * step
        last_linear_residual = norm(linearized_delta + scaled_residual) /
            max(norm(scaled_residual), eps(Float64))
        objective_before = dot(scaled_residual, scaled_residual)
        directional = dot(gradient, step)
        line_search_alpha0 = 1.0
        # Reuse only a fully finite, same-row-scale LM endpoint assembled in this iteration.
        lm_ray_reuse_state = nothing
        lm_ray_reuse_assembly = nothing
        lm_ray_reuse_hit = false
        selected_direction = partition === nothing ? :raw_bounded_sparse_qr :
            :inhouse_weighted_residual_kkt
        lm_direction_record = nothing
        raw_bounded_step = copy(step)
        if curvature_step_enabled && time() - started < policy.seconds
            raw_endpoint = Float64.(x .+ columns .* step)
            if all(isfinite, raw_endpoint) &&
                    all(i -> _smr_pressure_feasible(raw_endpoint[i], columns[i]), 4:4:n)
                probe_binding = binding_guard()
                probe_assembly = try
                    _smgw_trace_stage_v1(stage_trace,
                        "assembly_quartic_ray_probe_iteration_$(iteration)", () ->
                            assemble_spatial_global_weak_system_v1(
                                d, data, raw_endpoint; flux_Wb, jacobian=false, residual_partition))
                catch err
                    probe_numeric_failure = err isa DomainError ||
                        (err isa ArgumentError &&
                            occursin("nonfinite global weak residual", sprint(showerror, err)))
                    (err isa InterruptException || !probe_numeric_failure) && rethrow()
                    nothing
                end
                binding_guard() == probe_binding ||
                    throw(ArgumentError("operator binding changed during quartic-ray residual probe"))
                if probe_assembly !== nothing && probe_assembly.row_scales == assembly.row_scales
                    probe_residual = probe_assembly.residual ./ probe_assembly.row_scales
                    proposed_alpha = _smgw_quartic_ray_alpha_v1(
                        scaled_residual, linearized_delta, probe_residual)
                    if proposed_alpha !== nothing
                        raw_candidate = Float64.(x .+ proposed_alpha .* columns .* step)
                        projected_candidate = copy(raw_candidate)
                        for index in 4:4:n
                            _smr_pressure_feasible(projected_candidate[index], columns[index]) &&
                                projected_candidate[index] < 0.0 && (projected_candidate[index] = 0.0)
                        end
                        if raw_candidate == projected_candidate &&
                                all(i -> _smr_pressure_feasible(projected_candidate[i], columns[i]), 4:4:n)
                            line_search_alpha0 = proposed_alpha
                            damping = _smgw_lm_curvature_scale_v1(
                                scaled_jacobian, scaled_residual, linearized_delta,
                                probe_residual, proposed_alpha;
                                damping_multiplier=lm_damping_multiplier)
                            if damping !== nothing
                                # One alternate bounded QR per update; this now corrects the
                                # exact raw-ray quadratic residual at its quartic alpha.
                                lm_allowance = min(max(0.0, 72.0 - lm_extra_elapsed), 6.0,
                                    max(0.0, policy.seconds - (time() - started) - 8.0))
                                chord_inputs = _smgw_lm_chord_corrector_inputs_v1(
                                    scaled_residual, linearized_delta,
                                    probe_residual .- scaled_residual .- linearized_delta,
                                    proposed_alpha, raw_bounded_step,
                                    _smgw_scaled_lower_bounds_v1(x, columns))
                                if lm_allowance >= 6.0 && chord_inputs !== nothing
                                    lm_trace = stage_trace === nothing ? nothing :
                                        ((name, edge, stamp) -> stage_trace(
                                            "native_bounded_lm_iteration_$(iteration)_$(name)", edge, stamp))
                                    lm_refinement_started = mapped_q1_4_step ? time() : nothing
                                    lm_charge_before = lm_extra_elapsed
                                    chord_result = _smgw_lm_chord_corrector_v1(
                                        scaled_jacobian, scaled_residual, linearized_delta,
                                        probe_residual .- scaled_residual .- linearized_delta,
                                        proposed_alpha, raw_bounded_step,
                                        _smgw_scaled_lower_bounds_v1(x, columns), damping.lambda;
                                        seconds=lm_allowance, stage_trace=lm_trace,
                                        stage_name="native_bounded_lm_chord_corrector_iteration_$(iteration)")
                                    lm_step_result = chord_result.solved
                                        lm_extra_elapsed += Float64(lm_step_result.elapsed_seconds)
                                        binding_guard() == probe_binding ||
                                            throw(ArgumentError("operator binding changed during bounded LM chord corrector"))
                                        lm_candidate = chord_result.composite
                                        lm_candidate_valid = chord_result.valid && lm_candidate !== nothing &&
                                            length(lm_candidate) == n && all(isfinite, lm_candidate)
                                        lm_directional = lm_candidate_valid ?
                                            dot(gradient, lm_candidate) : Inf
                                        lm_full_endpoint = lm_candidate_valid ? x .+ columns .* lm_candidate : Float64[]
                                        lm_candidate_feasible = lm_candidate_valid &&
                                            all(isfinite, lm_full_endpoint) &&
                                            all(i -> _smr_pressure_feasible(lm_full_endpoint[i], columns[i]), 4:4:n)
                                        lm_selected = lm_step_result.converged &&
                                            lm_step_result.kkt.passed && lm_candidate_feasible &&
                                            isfinite(lm_directional) && lm_directional < 0.0 &&
                                            norm(lm_candidate) > 0.0
                                        correction_step = chord_result.correction
                                        lm_direction_record = (schema=lm_record_schema,
                                            selected=lm_selected,
                                            status=lm_step_result.converged ? :kkt_converged : lm_step_result.status,
                                            lambda=damping.lambda,
                                            curvature_ratio=damping.curvature_ratio,
                                            damping_factor=damping.damping_factor,
                                            mean_column_norm2=damping.mean_column_norm2,
                                            raw_ray_alpha=proposed_alpha,
                                            corrector_alpha=proposed_alpha,
                                            corrector_residual_norm=norm(chord_result.inputs.residual),
                                            corrector_shifted_finite_bounds=chord_result.inputs.shifted_finite_bounds,
                                            directional_derivative=isfinite(lm_directional) ?
                                                Float64(2.0 * lm_directional) : nothing,
                                            corrector_kkt=lm_step_result.kkt,
                                            active_indices=lm_step_result.active_indices,
                                            free_indices=lm_step_result.free_indices,
                                            raw_step=Tuple(raw_bounded_step),
                                            correction_step=Tuple(correction_step),
                                            step=lm_candidate_valid ? Tuple(lm_candidate) : nothing,
                                            selection_reason=lm_selected ? :finite_kkt_feasible_descent : :corrector_not_kkt_finite_or_descent,
                                            elapsed_seconds=lm_step_result.elapsed_seconds,
                                            total_extra_elapsed_seconds=lm_extra_elapsed,
                                            augmented_rank_evidence=:not_used_for_raw_rank,
                                            selected_lm_ray_alpha=nothing, line_search_alpha0=1.0,
                                            line_search_alpha_source=:alpha_one_fallback)
                                        if lm_selected
                                            step = lm_candidate
                                            selected_direction = lm_direction_label
                                        linearized_delta = scaled_jacobian * step
                                        last_linear_residual = norm(linearized_delta + scaled_residual) /
                                            max(norm(scaled_residual), eps(Float64))
                                        directional = lm_directional
                                        # The raw-ray quartic value only triggers this LM solve. Probe
                                        # the selected LM ray separately; keep alpha one on any ineligible probe.
                                        line_search_alpha0 = 1.0
                                        lm_ray_alpha = nothing
                                        lm_ray_source = :alpha_one_fallback
                                        lm_endpoint = Float64.(x .+ columns .* lm_candidate)
                                        if all(isfinite, lm_endpoint) &&
                                                all(i -> _smr_pressure_feasible(lm_endpoint[i], columns[i]), 4:4:n)
                                            lm_ray_binding = binding_guard()
                                            lm_ray_probe = try
                                                _smgw_trace_stage_v1(stage_trace,
                                                    "assembly_selected_lm_quartic_ray_probe_iteration_$(iteration)", () ->
                                                        assemble_spatial_global_weak_system_v1(
                                                            d, data, lm_endpoint; flux_Wb, jacobian=false, residual_partition))
                                            catch err
                                                probe_numeric_failure = err isa DomainError ||
                                                    (err isa ArgumentError &&
                                                        occursin("nonfinite global weak residual", sprint(showerror, err)))
                                                (err isa InterruptException || !probe_numeric_failure) && rethrow()
                                                nothing
                                            end
                                            binding_guard() == lm_ray_binding ||
                                                throw(ArgumentError("operator binding changed during selected-LM quartic-ray probe"))
                                            if lm_ray_probe !== nothing &&
                                                    lm_ray_probe.row_blocks == assembly.row_blocks &&
                                                    lm_ray_probe.row_scales == assembly.row_scales &&
                                                    length(lm_ray_probe.residual) == length(assembly.residual) &&
                                                    length(lm_ray_probe.row_scales) == length(assembly.row_scales) &&
                                                    all(isfinite, lm_ray_probe.residual) &&
                                                    all(isfinite, lm_ray_probe.row_scales) &&
                                                    all(>(0.0), lm_ray_probe.row_scales)
                                                lm_ray_reuse_state = copy(lm_endpoint)
                                                lm_ray_reuse_assembly = lm_ray_probe
                                            end
                                            if lm_ray_probe !== nothing &&
                                                    lm_ray_probe.row_scales == assembly.row_scales
                                                lm_ray_residual = lm_ray_probe.residual ./ lm_ray_probe.row_scales
                                                lm_linearized_delta = scaled_jacobian * lm_candidate
                                                proposed_lm_alpha = _smgw_quartic_ray_alpha_v1(
                                                    scaled_residual, lm_linearized_delta, lm_ray_residual)
                                                if proposed_lm_alpha !== nothing
                                                    lm_raw_candidate = Float64.(x .+ proposed_lm_alpha .* columns .* lm_candidate)
                                                    lm_projected_candidate = copy(lm_raw_candidate)
                                                    for index in 4:4:n
                                                        _smr_pressure_feasible(lm_projected_candidate[index], columns[index]) &&
                                                            lm_projected_candidate[index] < 0.0 &&
                                                            (lm_projected_candidate[index] = 0.0)
                                                    end
                                                    if all(isfinite, lm_raw_candidate) &&
                                                            lm_raw_candidate == lm_projected_candidate &&
                                                            all(i -> _smr_pressure_feasible(lm_projected_candidate[i], columns[i]), 4:4:n)
                                                        lm_ray_alpha = Float64(proposed_lm_alpha)
                                                        lm_ray_source = :quartic_selected
                                                        line_search_alpha0 = lm_ray_alpha
                                                    end
                                                end
                                            end
                                        end
                                        lm_direction_record = merge(lm_direction_record,
                                            (selected_lm_ray_alpha=lm_ray_alpha,
                                             line_search_alpha0=line_search_alpha0,
                                             line_search_alpha_source=lm_ray_source))
                                        # Only the mapped Q1_4 branch receives extra inner corrections.
                                        # The original first corrector, probes and refinements share six seconds.
                                        if mapped_q1_4_step
                                            refinement_deadline = lm_refinement_started + lm_allowance
                                            refinement_assemble = y -> assemble_spatial_global_weak_system_v1(
                                                d, data, y; flux_Wb, jacobian=false, residual_partition)
                                            refined = _smgw_m1n1_refine_chord_v1(
                                                scaled_jacobian, scaled_residual, x, columns,
                                                raw_bounded_step, proposed_alpha, chord_result, damping.lambda,
                                                assembly.row_scales, assembly.row_blocks, refinement_assemble,
                                                binding_guard, refinement_deadline;
                                                initial_endpoint=lm_ray_reuse_assembly===nothing ? nothing :
                                                    (state=copy(lm_ray_reuse_state),assembly=lm_ray_reuse_assembly,
                                                     binding=lm_ray_binding))
                                            refinement_elapsed = time() - lm_refinement_started
                                            refinement_eligible = refined.selected && refinement_elapsed <= lm_allowance
                                            lm_extra_elapsed = lm_charge_before + refinement_elapsed
                                            refinement_record = merge(refined.record,
                                                (selected=refinement_eligible, elapsed_seconds=refinement_elapsed,
                                                 status=refinement_elapsed <= lm_allowance ? refined.record.status : :time_ineligible))
                                            lm_direction_record = merge(lm_direction_record,
                                                (refinement=refinement_record, total_extra_elapsed_seconds=lm_extra_elapsed))
                                            if refinement_eligible
                                                step = refined.step
                                                linearized_delta = scaled_jacobian * step
                                                last_linear_residual = norm(linearized_delta + scaled_residual) /
                                                    max(norm(scaled_residual), eps(Float64))
                                                directional = dot(gradient, step)
                                                line_search_alpha0 = refined.ray.alpha0
                                                lm_ray_reuse_state = copy(refined.ray.state)
                                                lm_ray_reuse_assembly = refined.ray.assembly
                                                lm_direction_record = merge(lm_direction_record,
                                                    (schema="q1-4-m1n1-bounded-lm-chord-refined-v2",
                                                     corrector_kkt_scope=:initial_chord_augmented_shifted_lower_bound_subproblem,
                                                     step=Tuple(step), directional_derivative=2.0 * directional,
                                                     selected_lm_ray_alpha=refined.ray.ray_alpha,
                                                     line_search_alpha0=line_search_alpha0,
                                                     line_search_alpha_source=refined.ray.ray_alpha===nothing ?
                                                        :alpha_one_fallback : :quartic_selected))
                                            end
                                        end
                                    end
                                else
                                    lm_direction_record = (schema=lm_record_schema,
                                        selected=false,
                                        status=lm_allowance >= 6.0 ? :chord_input_ineligible : :skipped_budget_guard,
                                        selection_reason=lm_allowance >= 6.0 ? :chord_input_ineligible : :skipped_budget_guard,
                                        lambda=damping.lambda,
                                        curvature_ratio=damping.curvature_ratio,
                                        damping_factor=damping.damping_factor,
                                        mean_column_norm2=damping.mean_column_norm2,
                                        raw_ray_alpha=proposed_alpha,
                                        elapsed_seconds=0.0,
                                        total_extra_elapsed_seconds=lm_extra_elapsed,
                                        augmented_rank_evidence=:not_used_for_raw_rank,
                                        selected_lm_ray_alpha=nothing, line_search_alpha0=1.0,
                                        line_search_alpha_source=:alpha_one_fallback)
                                end
                            end
                        end
                    end
                end
            end
        end
        MultiTopologyNonlinearSolveV1.verify_source_v1(
            joinpath(@__DIR__, "MultiTopologyNonlinearSolveV1.jl"))
        # Merit is r'r; its directional derivative is 2*(J'r)'step.
        directional *= 2.0
        step_search = MultiTopologyNonlinearSolveV1.accepted_step_v1(
            x, step, columns; objective_before=objective_before,
            directional_derivative=directional,
            max_backtracks=policy.line_search_steps, alpha0=line_search_alpha0,
            reduction=0.5, minimum_alpha=0.0, armijo_fraction=2.0e-4,
            require_strict_decrease=true,
            assemble_trial=trial -> _smgw_trace_stage_v1(stage_trace,
                "assembly_line_search_iteration_$(iteration)", () -> begin
                    if lm_ray_reuse_assembly !== nothing && trial == lm_ray_reuse_state
                        lm_ray_reuse_hit = true
                        lm_ray_reuse_assembly
                    else
                        assemble_spatial_global_weak_system_v1(
                            d, data, trial; flux_Wb, jacobian=false, residual_partition)
                    end
                end),
            assembly_ready=_ -> true,
            unavailable_reason=_ -> (kind=:unexpected_unavailable_global_weak_assembly,),
            residual_for_merit=trial_assembly -> begin
                trial_partition = residual_partition === :inhouse_kkt ?
                    _smgw_inhouse_partition_v1(trial_assembly, admission, seal) : nothing
                trial_partition === nothing ?
                    trial_assembly.residual ./ trial_assembly.row_scales :
                    vcat(trial_partition.scaled_least_squares_residual,
                        trial_partition.equality_residual)
            end,
            merit=(_, residual) -> dot(residual, residual),
            project_state=trial -> begin
                for index in 4:4:n
                    _smr_pressure_feasible(trial[index], columns[index]) &&
                        trial[index] < 0.0 && (trial[index] = 0.0)
                end
                trial
            end,
            feasible=trial -> all(i -> _smr_pressure_feasible(trial[i], columns[i]), 4:4:n),
            changed=(before, after) -> after != before &&
                _smr_scaled_state_change(before, after, columns),
            evaluation_record=_ -> nothing, binding_guard=binding_guard,
            continue_trial=()->!(residual_partition === :inhouse_kkt ||
                curvature_step_enabled) ||
                time() - started < policy.seconds)
        step_search.status === :operator_unavailable &&
            throw(ArgumentError("global weak trial assembler became unavailable: $(step_search.failure)"))
        trials = Tuple((trial_index=t.trial_index, alpha=t.alpha, evaluated=t.evaluated,
            feasible=t.feasible, scaled_state_change=t.scaled_state_change,
            objective_after=t.objective_after, armijo=t.armijo,
            strict_decrease=t.strict_decrease, accepted=t.accepted)
            for t in step_search.trials)
        accepted = step_search.status === :accepted
        accepted_alpha = step_search.accepted_alpha
        accepted_state = step_search.state
        accepted_objective = step_search.accepted_objective
        lm_actual_linear_gain_ratio = nothing
        if accepted && selected_direction === lm_direction_label
            # Evaluate the same scaled-residual-squared merit on the accepted,
            # pressure-projected displacement. This changes only the next
            # alternate-step damping; raw QR rank/KKT and Armijo are unchanged.
            accepted_scaled_step = (accepted_state - x) ./ columns
            predicted_residual = scaled_residual + scaled_jacobian * accepted_scaled_step
            predicted_objective = dot(predicted_residual, predicted_residual)
            predicted_reduction = objective_before - predicted_objective
            actual_reduction = objective_before - accepted_objective
            reduction_floor = 128eps(Float64) * max(objective_before, accepted_objective, eps(Float64))
            if isfinite(predicted_reduction) && predicted_reduction > reduction_floor &&
                    isfinite(actual_reduction) && actual_reduction > 0.0
                ratio = actual_reduction / predicted_reduction
                if isfinite(ratio)
                    lm_actual_linear_gain_ratio = Float64(ratio)
                    lm_damping_multiplier = _smgw_lm_next_damping_multiplier_v1(
                        lm_damping_multiplier, ratio)
                end
            end
            lm_direction_record = merge(lm_direction_record,
                (actual_linear_gain_ratio=lm_actual_linear_gain_ratio,
                 next_damping_multiplier=lm_damping_multiplier))
        end
        if curvature_step_enabled && lm_direction_record !== nothing
            lm_direction_record = merge(lm_direction_record,
                (same_call_lm_endpoint_reused=lm_ray_reuse_hit,))
        end
        attempt_record = (attempt_index=length(attempts)+1, iteration=iteration,
            accepted=accepted, accepted_alpha=accepted_alpha,
            state_before_hash=canonical_hash(Tuple(x)),
            state_after_hash=canonical_hash(Tuple(accepted_state)),
            objective_before=objective_before, objective_after=accepted_objective,
            objective_decrease=objective_before - accepted_objective,
            direction=(hasproperty(bounded, :backend) &&
                bounded.backend === :inhouse_weighted_residual_kkt) ?
                :global_shared_q1_inhouse_active_set_weighted_residual_KKT :
                :global_shared_q1_lower_bounded_sparse_QR,
            selected_direction=selected_direction, lm_alternate=lm_direction_record,
            step=Tuple(step), step_norm=norm(step), linear_relative_residual=last_linear_residual,
            linear_input=subproblem, bounded_step=bounded, trials=trials,
            elapsed_seconds=time() - started)
        partition === nothing || (attempt_record = merge(attempt_record,
            (residual_partition=_smgw_partition_record_v1(partition),)))
        push!(attempts, attempt_record)
        if !accepted
            if step_search.status === :budget_boundary
                code = 4; reason = :wall_time_budget_during_line_search
            else
                code = 3; reason = :feasible_line_search_failed
            end
            break
        end
        last_step_norm = norm((accepted_state - x) ./ columns)
        x = accepted_state
        accepted_updates += 1
    end
    binding_guard()
    if final !== nothing && !isempty(states) && states[end] == x
        final = _smgw_trace_stage_v1(stage_trace, "assembly_final", () -> final)
    else
        final = _smgw_trace_stage_v1(stage_trace, "assembly_final", () ->
            assemble_spatial_global_weak_system_v1(d, data, x;
                flux_Wb, jacobian=true, residual_partition))
    end
    binding_guard()
    final_partition = residual_partition === :inhouse_kkt ?
        _smgw_trace_stage_v1(stage_trace, "partition_final", () ->
            _smgw_inhouse_partition_v1(final, admission, seal)) : nothing
    final_scaled = final_partition === nothing ? final.residual ./ final.row_scales :
        final_partition.scaled_least_squares_residual
    final_unscaled_matrix = final_partition === nothing ?
        spdiagm(0 => 1.0 ./ final.row_scales) * final.jacobian :
        final_partition.scaled_least_squares_jacobian
    final_matrix = final_unscaled_matrix * spdiagm(0 => columns)
    rank_diagnostics = try
        _smr_rank_audit(final_matrix, qr(final_matrix; tol=policy.rank_relative_tolerance),
            policy.rank_relative_tolerance)
    catch err
        (method=:final_sparse_QR_failed, error=sprint(showerror, err), rank_estimate=-1,
            columns=n, nullity_estimate=-1, null_modes=(), continuum_uniqueness=:unsupported)
    end
    code == 0 && maximum(abs, final_scaled) > policy.residual_tolerance &&
        throw(ArgumentError("global weak solver convergence code contradicts final residual"))
    (schema="spatial-global-weak-solver-state-v2", initial_state=Tuple(initial),
        final_state=Tuple(x), iterations=Tuple(history), state_history=Tuple(Tuple(v) for v in states),
        solver_exit_code=code, stopping_reason=reason, status=code == 0 ? :converged : :fail,
        numerical_status=code == 0 ? :full_discrete_residual_converged : :numerical_fail,
        accepted_update_count=accepted_updates, attempt_count=length(attempts),
        attempts=Tuple(attempts), final_assembly=final,
        final_scaled_residual_max=maximum(abs, final_scaled),
        final_scaled_residual_norm=norm(final_scaled), rank_diagnostics=rank_diagnostics,
        physical_checks=spatial_global_weak_physical_checks_v1(d, data, x;
            flux_Wb, residual_partition),
        elapsed_seconds=time() - started,
        operator_binding=_smgw_operator_binding_wire_v1(seal),
        residual_partition=residual_partition, step_identity=_smgw_step_identity_v1(residual_partition),
        step_identity_hash=string(canonical_hash(_smgw_step_identity_v1(residual_partition))),
        numerical_policy=(max_iterations=policy.max_iterations, seconds=policy.seconds,
            residual_tolerance=policy.residual_tolerance, gradient_tolerance=policy.gradient_tolerance,
            rank_relative_tolerance=policy.rank_relative_tolerance,
            kkt_absolute_tolerance=policy.kkt_absolute_tolerance,
            line_search_steps=policy.line_search_steps, pressure_lower_Pa=policy.pressure_lower_Pa),
        formal_policy=(status=:typed_absent, value=nothing),
        spatial_closures=(J_source=(status=:typed_absent, value=nothing),
            return_current_path=(status=:typed_absent, value=nothing),
            B_out=(status=:typed_absent, value=nothing),
            K_outer=(status=:typed_absent, value=nothing),
            pressure_current_topology=(status=:typed_absent, value=nothing)),
        physical_validation=:unsupported, authority=:no_publish,
        claim_ceiling=screen_only)
end

function _smgw_serializable_assembly_v1(assembly)
    rows, columns = size(assembly.jacobian)
    ri, ci, values = findnz(assembly.jacobian)
    (schema=assembly.schema, revision=assembly.revision, rows=rows, columns=columns,
        row_count=length(assembly.residual), residual=Tuple(assembly.residual),
        row_scales=Tuple(assembly.row_scales), row_blocks=assembly.row_blocks,
        row_supports=assembly.row_supports,
        jacobian=(format=:coordinate, index_base=1, row_indices=Tuple(ri),
            column_indices=Tuple(ci), values=Tuple(values)),
        node_order=assembly.node_order, element_nodes=assembly.element_nodes,
        row_layout=assembly.row_layout, cut_flux_Wb=assembly.cut_flux_Wb,
        prescribed_flux_Wb=assembly.prescribed_flux_Wb,
        interface_checks=assembly.interface_checks, boundary_checks=assembly.boundary_checks,
        conservation_checks=assembly.conservation_checks)
end

Base.@noinline Base.@nospecializeinfer function _smgw_write_solver_files_v1(root, solved)
    Base.@nospecialize solved
    assembly = solved.final_assembly
    paths = (state="solver_state.csv", residual="residual_rows.csv",
        jacobian="global_weak_jacobian.csv", row_supports="global_weak_row_supports.csv",
        iterations="iterations.json", attempts="attempts.json")
    io = open(joinpath(root, paths.state), "w")
    try
        println(io, "node_id,BR_T,Bphi_T,BZ_T,p_Pa")
        for node in 1:div(length(solved.final_state), 4)
            println(io, join((node, solved.final_state[4node-3:4node]...), ','))
        end
    finally
        close(io)
    end
    io = open(joinpath(root, paths.residual), "w")
    try
        println(io, "row,block,residual,declared_scale")
        for row in eachindex(assembly.residual)
            println(io, join((row, assembly.row_blocks[row], assembly.residual[row], assembly.row_scales[row]), ','))
        end
    finally
        close(io)
    end
    io = open(joinpath(root, paths.jacobian), "w")
    try
        println(io, "row,column,value")
        ri, ci, values = findnz(assembly.jacobian)
        for i in eachindex(values)
            println(io, join((ri[i], ci[i], values[i]), ','))
        end
    finally
        close(io)
    end
    io = open(joinpath(root, paths.row_supports), "w")
    try
        println(io, "row,block,columns_semicolon")
        for row in eachindex(assembly.row_blocks)
            println(io, "$(row),$(assembly.row_blocks[row]),$(join(assembly.row_supports[row], ';'))")
        end
    finally
        close(io)
    end
    write(joinpath(root, paths.iterations), canonical_json(solved.iterations) * "\n")
    write(joinpath(root, paths.attempts), canonical_json(solved.attempts) * "\n")
    counts = (state=div(length(solved.final_state), 4), residual=length(assembly.residual),
        jacobian=nnz(assembly.jacobian), row_supports=length(assembly.row_blocks),
        iterations=length(solved.iterations), attempts=length(solved.attempts))
    Tuple((name=name, path=joinpath(root, getproperty(paths, name)),
        sha256=bytes2hex(SHA.sha256(read(joinpath(root, getproperty(paths, name))))),
        row_count=getproperty(counts, name)) for name in keys(paths))
end

function validate_spatial_manufactured_global_weak_result_v1(context, result; run_dir=result.run_dir,
        _producer_admission=nothing)
    _smgw_validator_marker_v1(:validator_begin)
    if _producer_admission === nothing
        declared = _smgw_validator_timed_v1(:declaration_lookup, () -> _smr_declaration(context))
        _smgw_validator_timed_v1(:declaration_validation, () ->
            validate_spatial_n1_manufactured_declaration_v1(declared))
    else
        _producer_admission isa _SMGWOperatorAdmissionV1 ||
            throw(ArgumentError("producer validator reuse requires its admitted operator binding"))
        declared = _producer_admission.declaration
        _smgw_validator_marker_v1(:producer_admission_reuse)
        _smgw_validator_timed_v1(:producer_admission_identity, () -> begin
            _producer_admission.context === context ||
                throw(ArgumentError("producer admission belongs to a different context object"))
            _smgw_assert_admission_identity_v1(_producer_admission, declared)
        end)
    end
    _smgw_validator_timed_v1(:report_identity_checks, () -> begin
        result.report.schema == _SMGW_RESULT_SCHEMA_V2 ||
            throw(ArgumentError("unsupported GlobalWeak result schema"))
        result.report.binding.candidate_hash == context.candidate_hash == result.report.binding.context_candidate_hash ||
            throw(ArgumentError("global weak report candidate binding mismatch"))
        result.report.binding.context_hash == context.context_hash ||
            throw(ArgumentError("global weak report context binding mismatch"))
        result.report.declaration_hash == canonical_hash(declared) &&
            result.report.input_hash == canonical_hash(declared.source.input) ||
            throw(ArgumentError("global weak report declaration/input mismatch"))
    end)
    solver_mode = _smgw_validator_timed_v1(:solver_mode_identity, () ->
        _smgw_verify_solver_step_identity_v1(result.report.solver))
    _smgw_validator_timed_v1(:operator_identity_check, () -> begin
        result.report.operator_identity ==
            spatial_global_weak_operator_identity_v1(; residual_partition=solver_mode) ||
            throw(ArgumentError("global weak operator identity mismatch"))
    end)
    _smgw_validator_timed_v1(:scope_checks, () -> begin
        result.report.physical_validation == :unsupported && result.report.authority == :no_publish &&
            result.report.formal_policy == (status=:typed_absent, value=nothing) ||
            throw(ArgumentError("global weak result scope was promoted"))
        all(c -> c.status == :typed_absent && c.value === nothing, values(result.report.spatial_closures)) ||
            throw(ArgumentError("missing spatial closure must remain typed_absent"))
    end)
    _smgw_validator_timed_v1(:result_hash_check, () -> begin
        result.result_hash == canonical_hash(result.report) ||
            throw(ArgumentError("global weak result hash mismatch"))
    end)
    report_path = joinpath(run_dir, "global_weak_primary.json")
    report_wire = _smgw_validator_timed_v1(:primary_wire_encoding, () ->
        canonical_json(merge(result.report, (result_hash=result.result_hash,))) * "\n")
    _smgw_validator_timed_v1(:primary_wire_readback, () -> begin
        read(report_path, String) == report_wire ||
            throw(ArgumentError("global weak report primary wire mismatch"))
    end)
    _smgw_validator_timed_v1(:solver_artifact_validation, () -> begin
        for artifact in result.report.artifacts
            path = artifact.path
            isfile(path) && string(_smr_sha(path)) == artifact.sha256 ||
                throw(ArgumentError("global weak raw artifact changed: $(artifact.name)"))
        end
    end)
    receipt = result.report.geometry_receipt
    if _producer_admission === nothing
        _smgw_validator_timed_v1(:geometry_receipt, () ->
            validate_spatial_manufactured_geometry_v1(context, declared.source.input, receipt))
    else
        binding = (candidate_hash=_producer_admission.candidate_hash,
            context_hash=_producer_admission.context_hash)
        _smgw_validator_timed_v1(:geometry_receipt, () ->
            _smm_validate_geometry_receipt_v1(declared.source.input, declared, binding, receipt))
    end
    mesh_data = _smgw_validator_timed_v1(:fresh_parser_load, () ->
        load_spatial_data_v4(declared, (level=declared.source.input.mesh.level,
            nfp=declared.source.input.mesh.nfp, flux_Wb=declared.source.input.flux.nominal_Wb,
            raw_artifacts=receipt.raw_artifacts)))
    hasproperty(result.report.solver, :operator_binding) &&
        result.report.solver.schema == "spatial-global-weak-solver-state-v2" ||
        throw(ArgumentError("serialized GlobalWeak solver binding is missing or stale"))
    admission = _producer_admission === nothing ?
        _smgw_admission_record_v1(context, declared) : _producer_admission
    replay_seal = _smgw_validator_timed_v1(:fresh_data_binding_seal, () ->
        _smgw_capture_validator_fresh_data_binding_v1(admission, mesh_data, receipt,
            result.report.solver.initial_state; residual_partition=solver_mode))
    _smgw_json_equal_v1(result.report.solver.operator_binding,
        _smgw_operator_binding_wire_v1(replay_seal)) ||
        throw(ArgumentError("GlobalWeak operator binding differs from fresh geometry/source replay"))
    replay = _smgw_validator_timed_v1(:final_assembly_replay, () ->
        assemble_spatial_global_weak_system_v1(declared, mesh_data,
            result.report.solver.final_state; flux_Wb=declared.source.input.flux.nominal_Wb,
            jacobian=true, residual_partition=solver_mode))
    _smgw_serializable_assembly_v1(replay) == result.report.final_assembly ||
        throw(ArgumentError("global weak final residual/Jacobian replay mismatch"))
    replay_checks = _smgw_validator_timed_v1(:physical_check_replay, () ->
        spatial_global_weak_physical_checks_v1(declared, mesh_data,
            result.report.solver.final_state; flux_Wb=declared.source.input.flux.nominal_Wb,
            residual_partition=solver_mode))
    replay_checks == result.report.solver.physical_checks ||
        throw(ArgumentError("global weak independent physical-check replay mismatch"))
    result.report.solver.solver_exit_code == 0 &&
        result.report.solver.final_scaled_residual_max > declared.source.input.numerics.residual_tolerance &&
        throw(ArgumentError("global weak solver false convergence"))
    _smgw_validator_marker_v1(:validator_complete)
    result.result_hash
end

function _smgw_validator_timing_enabled_v1()
    get(ENV, "SMGW_VALIDATOR_TIMING", "") == "1"
end

function _smgw_validator_marker_v1(stage::Symbol)
    _smgw_validator_timing_enabled_v1() || return nothing
    println("SMGW_VALIDATOR_PHASE=$(stage)")
    flush(stdout)
    nothing
end

function _smgw_validator_timed_v1(stage::Symbol, operation::Function)
    _smgw_validator_timing_enabled_v1() || return operation()
    println("SMGW_VALIDATOR_PHASE_BEGIN=$(stage)")
    flush(stdout)
    started_ns = time_ns()
    try
        operation()
    finally
        elapsed_ns = time_ns() - started_ns
        println("SMGW_VALIDATOR_PHASE_END=$(stage);elapsed_ns=$(elapsed_ns)")
        flush(stdout)
    end
end

_smgw_json_equal_v1(left, right) = canonical_json(left) == canonical_json(right)

function _smgw_require_json_keys_v1(value, expected, label)
    value isa NamedTuple || throw(ArgumentError("$label must be a canonical JSON object"))
    Set(keys(value)) == Set(expected) || throw(ArgumentError("$label fields differ from the frozen schema"))
    value
end

function _smgw_digest_from_wire_v1(value, label)
    _smgw_require_json_keys_v1(value, (:value,), label)
    hex = value.value
    hex isa AbstractString && occursin(r"\A[0-9a-f]{64}\z", hex) ||
        throw(ArgumentError("$label is not a lowercase SHA-256 digest"))
    Digest256(String(hex))
end

function _smgw_artifact_from_wire_v1(value, label)
    _smgw_require_json_keys_v1(value, (:path, :sha256, :schema, :row_count), label)
    value.path isa AbstractString && value.schema isa AbstractString &&
        value.row_count isa Integer && !(value.row_count isa Bool) && value.row_count >= 0 ||
        throw(ArgumentError("$label has invalid artifact metadata"))
    SpatialArtifactV4(String(value.path), _smgw_digest_from_wire_v1(value.sha256, "$label.sha256"),
        String(value.schema), Int(value.row_count))
end

function _smgw_geometry_receipt_from_wire_v1(value, input)
    fields = (:schema, :candidate_hash, :context_hash, :declaration_hash, :input_hash,
        :provider, :provider_source, :raw_artifacts, :initializer_hash, :reference_state_hash,
        :enclosure, :desc_execution, :physical_validation, :authority)
    _smgw_require_json_keys_v1(value, fields, "geometry_receipt")
    provider = spatial_manufactured_provider_identity_v1()
    _smgw_json_equal_v1(value.provider, provider) ||
        throw(ArgumentError("manufactured geometry provider identity mismatch"))
    enclosure = _smm_enclosure_v1(input)
    _smgw_json_equal_v1(value.enclosure, enclosure) ||
        throw(ArgumentError("manufactured geometry enclosure mismatch"))
    raw = _smgw_require_json_keys_v1(value.raw_artifacts, (:nodes, :volume, :faces),
        "geometry_receipt.raw_artifacts")
    schema = value.schema
    schema == "spatial-manufactured-geometry-receipt-v1" ||
        throw(ArgumentError("unsupported manufactured geometry receipt schema"))
    value.desc_execution == "not_executed" && value.physical_validation == "unsupported" &&
        value.authority == "no_publish" ||
        throw(ArgumentError("manufactured geometry receipt scope was promoted"))
    SpatialManufacturedGeometryReceiptV1(String(schema),
        _smgw_digest_from_wire_v1(value.candidate_hash, "geometry_receipt.candidate_hash"),
        _smgw_digest_from_wire_v1(value.context_hash, "geometry_receipt.context_hash"),
        _smgw_digest_from_wire_v1(value.declaration_hash, "geometry_receipt.declaration_hash"),
        _smgw_digest_from_wire_v1(value.input_hash, "geometry_receipt.input_hash"), provider,
        _smgw_artifact_from_wire_v1(value.provider_source, "geometry_receipt.provider_source"),
        (nodes=_smgw_artifact_from_wire_v1(raw.nodes, "geometry_receipt.raw_artifacts.nodes"),
            volume=_smgw_artifact_from_wire_v1(raw.volume, "geometry_receipt.raw_artifacts.volume"),
            faces=_smgw_artifact_from_wire_v1(raw.faces, "geometry_receipt.raw_artifacts.faces")),
        _smgw_digest_from_wire_v1(value.initializer_hash, "geometry_receipt.initializer_hash"),
        _smgw_digest_from_wire_v1(value.reference_state_hash, "geometry_receipt.reference_state_hash"),
        enclosure, Symbol(value.desc_execution), Symbol(value.physical_validation), Symbol(value.authority))
end

function _smgw_existing_root_v1(directory)
    directory isa AbstractString && !isempty(directory) ||
        throw(ArgumentError("artifact directory must be a nonempty path"))
    requested = abspath(String(directory))
    isdir(requested) && !islink(requested) ||
        throw(ArgumentError("artifact directory must be an existing nonsymlink directory"))
    realpath(requested)
end

function _smgw_confined_file_v1(root, path, label)
    path isa AbstractString && isabspath(String(path)) ||
        throw(ArgumentError("$label path must be absolute"))
    normalized = normpath(String(path))
    isfile(normalized) && !islink(normalized) ||
        throw(ArgumentError("$label must be an existing regular nonsymlink file"))
    resolved = realpath(normalized)
    relative = relpath(resolved, root)
    components = splitpath(relative)
    !isempty(components) && first(components) != ".." && relative != "." ||
        throw(ArgumentError("$label escapes the supplied artifact directory"))
    resolved
end

function _smgw_current_semantic_identities_v1()
    method_source(method) = begin
        location = try
            Base.functionloc(method)
        catch err
            throw(ArgumentError("semantic method source is unresolved: $(sprint(showerror, err))"))
        end
        source_path = abspath(String(location[1]))
        isfile(source_path) || throw(ArgumentError("semantic method source file is absent: $source_path"))
        (signature=string(method.sig), source_path=source_path, source_line=Int(location[2]))
    end
    method_sources(functions...) = Tuple(begin
        found = collect(methods(f))
        isempty(found) && throw(ArgumentError("semantic method source is unresolved: $(nameof(f))"))
        entries = map(method_source, found)
        Tuple(sort!(collect(entries); by=entry -> (entry.source_path, entry.source_line, entry.signature)))
    end for f in functions)
    semantic_hash(value) = bytes2hex(SHA.sha256(IOBuffer(canonical_json(value))))

    solver_methods = method_sources(assemble_spatial_global_weak_system_v1,
        solve_spatial_global_weak_state_v1,
        _smgw_solve_spatial_global_weak_after_input_validation_v1,
        _smgw_curvature_step_enabled_v1,
        _smgw_m1n1_refine_chord_v1, _smgw_m1n1_refinement_identity_v1,
        _smgw_quartic_ray_alpha_v1, _smgw_lm_curvature_scale_v1,
        spatial_global_weak_physical_checks_v1)
    provider_methods = method_sources(spatial_field_v4, _smm_source_v1,
        load_spatial_data_v4, SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1)
    contract = (revision=_SMGW_OPERATOR_REVISION_V2,
        result_schema=_SMGW_RESULT_SCHEMA_V2,
        numerical_policy=(max_iterations=12,
            seconds_by_level=(coarse=120.0, q1_4=120.0, q1_8=600.0),
            residual_tolerance=1.0e-6, gradient_tolerance=1.0e-10, rank_relative_tolerance=1.0e-10,
            kkt_absolute_tolerance=1.0e-10, line_search_steps=20, pressure_lower_Pa=0.0))
    inhouse_step = InHouseCoupledMHDGlobalSolveV1.weighted_residual_kkt_step_identity_v1()
    tuple_view_canonical_method = method_source(which(FusionConceptAI._canonical,
        Tuple{_SMGWCanonicalTupleViewV1}))
    json_fragment_canonical_method = method_source(which(FusionConceptAI._canonical,
        Tuple{_SMGWCanonicalJSONFragmentV1}))
    (solver_semantic_hash=semantic_hash((revision=_SMGW_OPERATOR_REVISION_V2,
            algorithm=:shared_global_q1_weak_residual, methods=solver_methods)),
        provider_semantic_hash=semantic_hash((provider=:spatial_q1_manufactured_provider,
            methods=provider_methods)),
        contract_semantic_hash=semantic_hash(contract),
        inhouse_solver_semantic_hash=inhouse_step.solver_semantic_hash,
        accepted_step_core_semantic_hash=semantic_hash(method_sources(
            MultiTopologyNonlinearSolveV1.accepted_step_v1,
            MultiTopologyNonlinearSolveV1.verify_source_v1)),
        spatial_v4_semantic_hash=semantic_hash(method_sources(
            spatial_field_v4, load_spatial_data_v4, _smr_bounded_identity_v1)),
        manufactured_input_semantic_hash=semantic_hash(method_sources(
            _smm_source_v1, _smm_field_v1)),
        bounded_step_semantic_hash=semantic_hash(method_sources(
            SpatialBoundedLinearStepV1.solve_lower_bounded_step_v1,
            SpatialBoundedLinearStepV1.bounded_linear_step_identity_v1)),
        execution_types_semantic_hash=semantic_hash((methods=method_sources(
            _smgw_operator_data_fingerprint_v1, _smgw_mesh_view_v1,
            _smgw_array_view_v1, _smgw_sample_view_v1, _smgw_tuple_view_v1,
            _smgw_canonical_tuple_view_json_v1),
            tuple_view_canonical_method=tuple_view_canonical_method,
            json_fragment_canonical_method=json_fragment_canonical_method)))
end

function _smgw_check_semantic_identities_v1(expected)
    expected isa NamedTuple || throw(ArgumentError("expected_semantic_identities must be a named tuple"))
    expected_keys = (:solver_semantic_hash, :provider_semantic_hash,
        :contract_semantic_hash, :inhouse_solver_semantic_hash,
        :accepted_step_core_semantic_hash, :spatial_v4_semantic_hash,
        :manufactured_input_semantic_hash, :bounded_step_semantic_hash,
        :execution_types_semantic_hash)
    keys(expected) == expected_keys || throw(ArgumentError("expected semantic identity fields/order mismatch"))
    actual = _smgw_current_semantic_identities_v1()
    for key in expected_keys
        expected_value = getproperty(expected, key)
        expected_value isa AbstractString && expected_value == getproperty(actual, key) ||
            throw(ArgumentError("implementation semantic identity mismatch: $key"))
    end
    actual
end

struct _SMGWOperatorAdmissionV1
    context::Any
    declaration::SpatialMultiRegionDeclarationV4
    candidate_hash::Digest256
    context_hash::Digest256
    declaration_hash::Digest256
    input_hash::Digest256
end

struct _SMGWOperatorBindingSealV1
    admission::_SMGWOperatorAdmissionV1
    receipt_hash::Digest256
    data_fingerprint::Digest256
    initial_state_hash::Digest256
    semantic_identities::NamedTuple
    residual_partition::Symbol
    step_identity::NamedTuple
end

"""Run the real candidate/context/declaration guard once and retain its identities."""
function _smgw_admit_context_v1(context)
    declared = _smr_declaration(context)
    _smm_is_declaration_v1(declared) ||
        throw(ArgumentError("global weak admission requires the frozen manufactured declaration"))
    validate_spatial_n1_manufactured_declaration_v1(declared)
    _smgw_admission_record_v1(context, declared)
end

function _smgw_admission_record_v1(context, declared)
    _smm_is_declaration_v1(declared) ||
        throw(ArgumentError("global weak admission requires the frozen manufactured declaration"))
    input = declared.source.input
    _SMGWOperatorAdmissionV1(context, declared, context.candidate_hash, context.context_hash,
        canonical_hash(declared), canonical_hash(input))
end

function _smgw_context_declaration_v1(context)
    only(filter(value -> value isa SpatialMultiRegionDeclarationV4,
        context.candidate.field_geometry_genome_ref.fields))
end

function _smgw_assert_admission_identity_v1(admission::_SMGWOperatorAdmissionV1, declared)
    context = admission.context
    context.candidate_hash == admission.candidate_hash && context.context_hash == admission.context_hash ||
        throw(ArgumentError("global weak candidate/context identity changed"))
    embedded = _smgw_context_declaration_v1(context)
    canonical_hash(embedded) == admission.declaration_hash &&
        canonical_hash(embedded.source.input) == admission.input_hash &&
        canonical_hash(declared) == admission.declaration_hash &&
        canonical_hash(declared.source.input) == admission.input_hash ||
        throw(ArgumentError("global weak declaration/input identity changed"))
    true
end

function _smgw_array_view_v1(value, label; stage_trace=nothing, trace_name="",
        variable_length_tuple_view=false)
    value isa Matrix{Float64} ||
        throw(ArgumentError("$label must retain the production Matrix{Float64} loader type"))
    all(isfinite, value) || throw(ArgumentError("$label contains a nonfinite loader value"))
    if variable_length_tuple_view
        values = _smgw_trace_stage_v1(stage_trace, trace_name * "_values_vector", () ->
            _smgw_tuple_view_v1(collect(vec(value))))
        return (shape=Tuple(size(value)), values=values)
    end
    # Canonical AbstractArray encoding emits exactly the former explicit
    # {shape,values} projection. Capture those bytes for this fingerprint so
    # sample E/Einv need no intermediate 9-value tuple; each invocation still
    # validates and encodes the current matrix contents.
    _SMGWCanonicalJSONFragmentV1(FusionConceptAI._canonical(value))
end

function _smgw_float_tuple3_v1(value, label)
    typeof(value) === NTuple{3,Float64} ||
        throw(ArgumentError("$label must retain the production NTuple{3,Float64} loader type"))
    all(isfinite, value) || throw(ArgumentError("$label contains a nonfinite loader value"))
    value
end

function _smgw_state_tuple_v1(value, label)
    (typeof(value) === Vector{Float64} || value isa Tuple{Vararg{Float64}}) ||
        throw(ArgumentError("$label must be a Float64 vector or Float64 tuple from the production loader"))
    all(item -> typeof(item) === Float64 && isfinite(item), value) ||
        throw(ArgumentError("$label contains a nonfinite or non-Float64 loader value"))
    Tuple(value)
end

function _smgw_enclosure_view_v1(value)
    value isa NamedTuple && keys(value) ==
        (:supported, :R_upper_m, :method, :applicability, :desc_spectral_enclosure) ||
        throw(ArgumentError("continuous enclosure differs from the manufactured loader schema"))
    typeof(value.supported) === Bool && typeof(value.R_upper_m) === Float64 &&
        isfinite(value.R_upper_m) && typeof(value.method) === Symbol &&
        typeof(value.applicability) === Symbol && typeof(value.desc_spectral_enclosure) === Symbol ||
        throw(ArgumentError("continuous enclosure fields differ from the manufactured loader types"))
    value
end

function _smgw_mesh_view_v1(mesh::SpatialMeshV4; stage_trace=nothing, trace_prefix="")
    size(mesh.nodes_q, 1) == 3 && all(isfinite, mesh.nodes_q) ||
        throw(ArgumentError("mesh node coordinates differ from the finite 3D loader layout"))
    expected_face_keys = (:axis, :left_cell, :right_cell, :role, :fixed)
    all(face -> face isa NamedTuple && keys(face) == expected_face_keys &&
        typeof(face.axis) === Int && typeof(face.left_cell) === Int &&
        typeof(face.right_cell) === Int && typeof(face.role) === Symbol &&
        typeof(face.fixed) === Float64 && isfinite(face.fixed), mesh.faces) ||
        throw(ArgumentError("mesh face rows differ from the production loader schema/types"))
    exterior = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_exterior_row_start_vector", () ->
        _smgw_tuple_view_v1([(cell=key, row=mesh.exterior_row_start[key]) for key in
            sort!(collect(keys(mesh.exterior_row_start)))]))
    nodes_q = _smgw_array_view_v1(mesh.nodes_q, "mesh.nodes_q";
        stage_trace, trace_name=trace_prefix * "_mesh_nodes_q",
        variable_length_tuple_view=true)
    cell_nodes = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_cell_nodes_vector", () ->
        _smgw_tuple_view_v1(map(nodes -> Tuple(nodes), mesh.cell_nodes)))
    corner_to_local = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_corner_to_local_vector", () ->
        _smgw_tuple_view_v1(map(mapping -> Tuple(mapping), mesh.corner_to_local)))
    cell_bounds = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_cell_bounds_vector", () ->
        _smgw_tuple_view_v1(collect(mesh.cell_bounds)))
    cell_regions = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_cell_regions_vector", () ->
        _smgw_tuple_view_v1(collect(mesh.cell_regions)))
    faces = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_faces_vector", () ->
        _smgw_tuple_view_v1(map(face -> (axis=face.axis, left_cell=face.left_cell,
            right_cell=face.right_cell, role=face.role, fixed=face.fixed), mesh.faces)))
    cell_row_start = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_cell_row_start_vector", () ->
        _smgw_tuple_view_v1(collect(mesh.cell_row_start)))
    row_blocks = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_row_blocks_vector", () ->
        _smgw_tuple_view_v1(collect(mesh.row_blocks)))
    row_supports = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_row_supports_vector", () ->
        _smgw_tuple_view_v1(map(support -> Tuple(support), mesh.row_supports)))
    (level=mesh.level, nfp=mesh.nfp, nodes_q=nodes_q,
        cell_nodes=cell_nodes, corner_to_local=corner_to_local,
        cell_bounds=cell_bounds, cell_regions=cell_regions, faces=faces,
        cell_row_start=cell_row_start, exterior_row_start=exterior,
        row_blocks=row_blocks, row_supports=row_supports)
end

function _smgw_sample_view_v1(sample)
    sample isa NamedTuple && keys(sample) ==
        (:entity_id, :qp_id, :q, :xyz, :R, :phi, :weight, :detE, :normal,
            :E, :Einv, :B_reference_cyl, :p_reference) ||
        throw(ArgumentError("quadrature sample differs from the production loader schema"))
    typeof(sample.entity_id) === Int && typeof(sample.qp_id) === Int ||
        throw(ArgumentError("quadrature sample IDs must retain the production Int loader type"))
    q = _smgw_float_tuple3_v1(sample.q, "sample.q")
    xyz = _smgw_float_tuple3_v1(sample.xyz, "sample.xyz")
    normal = _smgw_float_tuple3_v1(sample.normal, "sample.normal")
    reference = _smgw_float_tuple3_v1(sample.B_reference_cyl, "sample.B_reference_cyl")
    for name in (:R, :phi, :weight, :detE, :p_reference)
        value = getproperty(sample, name)
        typeof(value) === Float64 && isfinite(value) ||
            throw(ArgumentError("quadrature sample $name must retain a finite Float64 loader value"))
    end
    sample.E isa Matrix{Float64} && size(sample.E) == (3, 3) ||
        throw(ArgumentError("sample.E must retain the production 3x3 Matrix{Float64} loader type"))
    sample.Einv isa Matrix{Float64} && size(sample.Einv) == (3, 3) ||
        throw(ArgumentError("sample.Einv must retain the production 3x3 Matrix{Float64} loader type"))
    (entity_id=sample.entity_id, qp_id=sample.qp_id, q=q, xyz=xyz,
        R=sample.R, phi=sample.phi, weight=sample.weight, detE=sample.detE, normal=normal,
        E=_smgw_array_view_v1(sample.E, "sample.E"),
        Einv=_smgw_array_view_v1(sample.Einv, "sample.Einv"),
        B_reference_cyl=reference, p_reference=sample.p_reference)
end

function _smgw_raw_artifact_view_v1(artifacts)
    keys(artifacts) == (:nodes, :volume, :faces) ||
        throw(ArgumentError("global weak raw artifact bundle fields/order mismatch"))
    NamedTuple{keys(artifacts)}(Tuple(begin
        artifact = getproperty(artifacts, key)
        artifact isa SpatialArtifactV4 || throw(ArgumentError("global weak raw artifact type mismatch: $key"))
        path = artifact.path
        isfile(path) && !islink(path) || throw(ArgumentError("global weak raw artifact is missing or linked: $key"))
        bytes = read(path)
        actual_sha = bytes2hex(SHA.sha256(bytes))
        actual_sha == string(artifact.sha256) ||
            throw(ArgumentError("global weak raw artifact bytes changed: $key"))
        (path=abspath(path), sha256=actual_sha, schema=artifact.schema,
            row_count=artifact.row_count, byte_count=length(bytes))
    end for key in keys(artifacts)))
end

function _smgw_operator_data_fingerprint_v1(data; stage_trace=nothing, trace_prefix="operator_fingerprint")
    data isa NamedTuple && keys(data) ==
        (:mesh, :nodes, :volume, :face_quadrature, :initial_state, :raw_artifacts, :continuous_enclosure) ||
        throw(ArgumentError("global weak loaded data differs from the production parser schema"))
    mesh = data.mesh
    mesh isa SpatialMeshV4 || throw(ArgumentError("global weak mesh type changed"))
    samples = (nodes=data.nodes, volume=data.volume, faces=data.face_quadrature)
    all(rows -> typeof(rows) === Vector{NamedTuple}, values(samples)) ||
        throw(ArgumentError("global weak quadrature arrays differ from the production Vector{NamedTuple} loader type"))
    (typeof(data.initial_state) === Vector{Float64} ||
        data.initial_state isa Tuple{Vararg{Float64}}) ||
        throw(ArgumentError("loaded initial state must be a Float64 vector or Float64 tuple from the production loader"))
    all(item -> typeof(item) === Float64 && isfinite(item), data.initial_state) ||
        throw(ArgumentError("loaded initial state contains a nonfinite or non-Float64 loader value"))
    initial_state = _smgw_tuple_view_v1(collect(data.initial_state))
    mesh_view = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_mesh_view", () ->
        _smgw_mesh_view_v1(mesh; stage_trace, trace_prefix))
    node_views = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_nodes_sample_views_vector", () ->
        _smgw_tuple_view_v1(map(_smgw_sample_view_v1, samples.nodes)))
    volume_views = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_volume_sample_views_vector", () ->
        _smgw_tuple_view_v1(map(_smgw_sample_view_v1, samples.volume)))
    face_views = _smgw_trace_stage_v1(stage_trace, trace_prefix * "_face_sample_views_vector", () ->
        _smgw_tuple_view_v1(map(_smgw_sample_view_v1, samples.faces)))
    projection = (mesh=mesh_view,
        nodes=node_views,
        volume=volume_views,
        face_quadrature=face_views,
        initial_state=initial_state,
        continuous_enclosure=_smgw_enclosure_view_v1(data.continuous_enclosure),
        raw_artifacts=_smgw_raw_artifact_view_v1(data.raw_artifacts))
    canonical_hash(projection)
end

function _smgw_build_operator_binding_seal_v1(admission::_SMGWOperatorAdmissionV1,
        receipt::SpatialManufacturedGeometryReceiptV1, initial, residual_partition, fingerprint)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    semantic_identities = _smgw_current_semantic_identities_v1()
    step_identity = _smgw_step_identity_v1(residual_partition)
    residual_partition === :inhouse_kkt &&
        step_identity.implementation.solver_semantic_hash != semantic_identities.inhouse_solver_semantic_hash &&
        throw(ArgumentError("InHouse step identity differs from the sealed solver semantics"))
    _SMGWOperatorBindingSealV1(admission, canonical_hash(receipt), fingerprint,
        canonical_hash(_smgw_state_tuple_v1(initial, "admitted initial state")), semantic_identities,
        residual_partition, step_identity)
end

"""Seal the exact operator data after validating the real receipt and production parser output."""
function _smgw_capture_operator_binding_v1(admission::_SMGWOperatorAdmissionV1, data,
        receipt::SpatialManufacturedGeometryReceiptV1, initial;
        residual_partition=:spatial_native, stage_trace=nothing)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    declared = admission.declaration
    _smgw_assert_admission_identity_v1(admission, declared)
    input = declared.source.input
    binding = (candidate_hash=admission.candidate_hash, context_hash=admission.context_hash)
    _smgw_validate_inputs_v1(declared, data, initial, input.flux.nominal_Wb;
        residual_partition)
    _smm_validate_geometry_receipt_v1(input, declared, binding, receipt)
    isequal(data.raw_artifacts, receipt.raw_artifacts) ||
        throw(ArgumentError("loaded GlobalWeak data refers to a different geometry receipt"))
    replayed_data = _smgw_trace_stage_v1(stage_trace, "production_loader_replay", () ->
        load_spatial_data_v4(declared, (level=input.mesh.level, nfp=input.mesh.nfp,
            flux_Wb=input.flux.nominal_Wb, raw_artifacts=receipt.raw_artifacts)))
    fingerprint = _smgw_operator_data_fingerprint_v1(data; stage_trace,
        trace_prefix="binding_capture_loaded_fingerprint")
    fingerprint == _smgw_operator_data_fingerprint_v1(replayed_data; stage_trace,
        trace_prefix="binding_capture_replay_fingerprint") ||
        throw(ArgumentError("loaded GlobalWeak operator data differs from the production parser replay"))
    _smgw_build_operator_binding_seal_v1(admission, receipt, initial,
        residual_partition, fingerprint)
end

"""Seal data just loaded from the production parser by the result validator.

Precondition: the validator has freshly validated `receipt` against the candidate and
then loaded `data` from exactly `receipt.raw_artifacts`. Keep the regular solver
capture on `_smgw_capture_operator_binding_v1`, which independently repeats both
receipt validation and parser replay.
"""
function _smgw_capture_validator_fresh_data_binding_v1(admission::_SMGWOperatorAdmissionV1,
        data, receipt::SpatialManufacturedGeometryReceiptV1, initial;
        residual_partition=:spatial_native)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    declared = admission.declaration
    _smgw_assert_admission_identity_v1(admission, declared)
    input = declared.source.input
    _smgw_validate_inputs_v1(declared, data, initial, input.flux.nominal_Wb;
        residual_partition)
    isequal(data.raw_artifacts, receipt.raw_artifacts) ||
        throw(ArgumentError("loaded GlobalWeak data refers to a different geometry receipt"))
    fingerprint = _smgw_operator_data_fingerprint_v1(data)
    _smgw_build_operator_binding_seal_v1(admission, receipt, initial,
        residual_partition, fingerprint)
end

"""Recheck source, candidate, receipt, initial state, mesh, and every consumed quadrature value."""
function _smgw_assert_operator_binding_v1(seal::_SMGWOperatorBindingSealV1, context,
        declared, data, receipt, initial; residual_partition=seal.residual_partition,
        stage_trace=nothing)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    residual_partition == seal.residual_partition &&
        _smgw_json_equal_v1(_smgw_step_identity_v1(residual_partition), seal.step_identity) ||
        throw(ArgumentError("global weak solver backend or step identity changed after binding"))
    admission = seal.admission
    context === admission.context ||
        throw(ArgumentError("global weak operator binding changed candidate context object"))
    _smgw_assert_admission_identity_v1(admission, declared)
    context.candidate_hash == admission.candidate_hash && context.context_hash == admission.context_hash ||
        throw(ArgumentError("global weak operator binding candidate/context mismatch"))
    receipt isa SpatialManufacturedGeometryReceiptV1 &&
        receipt.candidate_hash == admission.candidate_hash && receipt.context_hash == admission.context_hash &&
        receipt.declaration_hash == admission.declaration_hash && receipt.input_hash == admission.input_hash &&
        canonical_hash(receipt) == seal.receipt_hash ||
        throw(ArgumentError("global weak geometry receipt binding changed"))
    isequal(data.raw_artifacts, receipt.raw_artifacts) ||
        throw(ArgumentError("global weak raw artifact references differ from the admitted receipt"))
    current_identities = _smgw_check_semantic_identities_v1(seal.semantic_identities)
    current_identities == seal.semantic_identities ||
        throw(ArgumentError("global weak semantic identities changed"))
    _smgw_operator_data_fingerprint_v1(data; stage_trace,
        trace_prefix="binding_check_fingerprint") == seal.data_fingerprint ||
        throw(ArgumentError("global weak mesh, quadrature, raw artifact, or layout data changed"))
    canonical_hash(_smgw_state_tuple_v1(initial, "admitted initial state")) == seal.initial_state_hash ||
        throw(ArgumentError("global weak admitted initial state changed"))
    string(canonical_hash((candidate_hash=admission.candidate_hash, context_hash=admission.context_hash,
        declaration_hash=admission.declaration_hash, input_hash=admission.input_hash,
        receipt_hash=seal.receipt_hash, data_fingerprint=seal.data_fingerprint,
        initial_state_hash=seal.initial_state_hash, semantic_identities=current_identities,
        residual_partition=seal.residual_partition, step_identity=seal.step_identity)))
end

struct _SMGWOperatorBindingGuardCallV1 <: Function
    stage_trace::Any
    seal::Any
    admission::Any
    declared::Any
    data::Any
    receipt::Any
    initial::Any
    residual_partition::Any
end

function (guard::_SMGWOperatorBindingGuardCallV1)()
    _smgw_trace_event_v1(guard.stage_trace, "binding_check", :begin)
    try
        _smgw_assert_operator_binding_v1(guard.seal, guard.admission.context,
            guard.declared, guard.data, guard.receipt, guard.initial;
            residual_partition=guard.residual_partition, stage_trace=guard.stage_trace)
    catch err
        _smgw_stage_diagnostic_v1(guard.stage_trace, "binding_check_error";
            error=err, backtrace=catch_backtrace())
        rethrow()
    finally
        _smgw_trace_event_v1(guard.stage_trace, "binding_check", :end)
    end
end

function _smgw_operator_binding_wire_v1(seal::_SMGWOperatorBindingSealV1)
    admission = seal.admission
    (schema="spatial-global-weak-operator-binding-v1",
        candidate_hash=string(admission.candidate_hash), context_hash=string(admission.context_hash),
        declaration_hash=string(admission.declaration_hash), input_hash=string(admission.input_hash),
        geometry_receipt_hash=string(seal.receipt_hash),
        operator_data_fingerprint=string(seal.data_fingerprint),
        initial_state_hash=string(seal.initial_state_hash), semantic_identities=seal.semantic_identities,
        residual_partition=seal.residual_partition, step_identity=seal.step_identity,
        step_identity_hash=string(canonical_hash(seal.step_identity)))
end

function _smgw_csv_rows_v1(path, header, label)
    lines = readlines(path)
    !isempty(lines) && first(lines) == header || throw(ArgumentError("$label CSV header mismatch"))
    rows = split.(lines[2:end], ',')
    all(row -> !isempty(row) && all(field -> !isempty(field), row), rows) ||
        throw(ArgumentError("$label CSV contains empty rows or fields"))
    rows
end

function _smgw_csv_rows_v1(bytes::Vector{UInt8}, header, label)
    lines = readlines(IOBuffer(bytes))
    !isempty(lines) && first(lines) == header || throw(ArgumentError("$label CSV header mismatch"))
    rows = split.(lines[2:end], ',')
    all(row -> !isempty(row) && all(field -> !isempty(field), row), rows) ||
        throw(ArgumentError("$label CSV contains empty rows or fields"))
    rows
end

function _smgw_csv_integer_v1(value, label)
    parsed = tryparse(Int, value)
    parsed !== nothing && string(parsed) == value || throw(ArgumentError("$label is not a canonical integer"))
    parsed
end

function _smgw_csv_float_v1(value, label)
    parsed = tryparse(Float64, value)
    parsed !== nothing && isfinite(parsed) || throw(ArgumentError("$label is not a finite Float64"))
    parsed
end

function _smgw_sha256_file_v1(path)
    open(path, "r") do io
        bytes2hex(SHA.sha256(io))
    end
end

function _smgw_check_row_artifacts_v1(root, report, data, state, replay, replay_checks)
    refs = report.artifacts
    refs isa Tuple || throw(ArgumentError("global weak artifact refs must be an ordered array"))
    names = (:state, :residual, :jacobian, :row_supports, :iterations, :attempts)
    length(refs) == length(names) || throw(ArgumentError("global weak artifact coverage mismatch"))
    by_name = Dict{Symbol,Any}()
    sha_by_name = Dict{Symbol,String}()
    expected_files = ("solver_state.csv", "residual_rows.csv", "global_weak_jacobian.csv",
        "global_weak_row_supports.csv", "iterations.json", "attempts.json")
    expected_counts = (size(data.mesh.nodes_q, 2), length(replay.residual), nnz(replay.jacobian),
        length(replay.row_blocks), length(report.solver.iterations), length(report.solver.attempts))
    for index in eachindex(refs)
        ref = refs[index]
        _smgw_require_json_keys_v1(ref, (:name, :path, :sha256, :row_count), "artifact_ref[$index]")
        ref.name == String(names[index]) || throw(ArgumentError("global weak artifact ref order/name mismatch"))
        path = _smgw_confined_file_v1(root, ref.path, "artifact_ref[$index]")
        path == joinpath(root, expected_files[index]) ||
            throw(ArgumentError("global weak artifact path mismatch"))
        ref.sha256 isa AbstractString && occursin(r"\A[0-9a-f]{64}\z", ref.sha256) ||
            throw(ArgumentError("artifact ref SHA-256 must be lowercase hex"))
        _smgw_sha256_file_v1(path) == ref.sha256 ||
            throw(ArgumentError("global weak artifact bytes changed: $(ref.name)"))
        ref.row_count isa Integer && !(ref.row_count isa Bool) && ref.row_count == expected_counts[index] ||
            throw(ArgumentError("global weak artifact row count mismatch: $(ref.name)"))
        by_name[names[index]] = path
        sha_by_name[names[index]] = String(ref.sha256)
    end
    state_rows = _smgw_csv_rows_v1(read(by_name[:state]), "node_id,BR_T,Bphi_T,BZ_T,p_Pa", "solver_state")
    length(state_rows) == size(data.mesh.nodes_q, 2) || throw(ArgumentError("solver state row count mismatch"))
    read_state = Float64[]
    node_ids = Int[]
    for (index, row) in enumerate(state_rows)
        length(row) == 5 || throw(ArgumentError("solver state row width mismatch"))
        node = _smgw_csv_integer_v1(row[1], "solver_state.node_id")
        push!(node_ids, node)
        node == index || throw(ArgumentError("solver state node IDs are missing, duplicated, or reordered"))
        append!(read_state, (_smgw_csv_float_v1(row[column], "solver_state.value") for column in 2:5))
    end
    Tuple(node_ids) == Tuple(1:size(data.mesh.nodes_q, 2)) ||
        throw(ArgumentError("solver state node identity mismatch"))
    Tuple(read_state) == Tuple(state) || throw(ArgumentError("solver state CSV changed during replay"))

    residual_rows = _smgw_csv_rows_v1(read(by_name[:residual]), "row,block,residual,declared_scale", "residual_rows")
    length(residual_rows) == length(replay.residual) || throw(ArgumentError("residual row coverage mismatch"))
    for (index, row) in enumerate(residual_rows)
        length(row) == 4 && _smgw_csv_integer_v1(row[1], "residual.row") == index &&
            row[2] == string(replay.row_blocks[index]) &&
            _smgw_csv_float_v1(row[3], "residual.value") == replay.residual[index] &&
            _smgw_csv_float_v1(row[4], "residual.scale") == replay.row_scales[index] ||
            throw(ArgumentError("serialized residual/scale replay mismatch at row $index"))
    end

    jacobian_rows = _smgw_csv_rows_v1(read(by_name[:jacobian]), "row,column,value", "global_weak_jacobian")
    row_indices, column_indices, values = findnz(replay.jacobian)
    length(jacobian_rows) == length(values) || throw(ArgumentError("Jacobian nonzero coverage mismatch"))
    for index in eachindex(values)
        row = jacobian_rows[index]
        length(row) == 3 && _smgw_csv_integer_v1(row[1], "jacobian.row") == row_indices[index] &&
            _smgw_csv_integer_v1(row[2], "jacobian.column") == column_indices[index] &&
            _smgw_csv_float_v1(row[3], "jacobian.value") == values[index] ||
            throw(ArgumentError("serialized Jacobian replay mismatch at entry $index"))
    end

    support_rows = _smgw_csv_rows_v1(read(by_name[:row_supports]), "row,block,columns_semicolon", "row_supports")
    length(support_rows) == length(replay.row_supports) || throw(ArgumentError("row support coverage mismatch"))
    for (index, row) in enumerate(support_rows)
        expected_columns = join(replay.row_supports[index], ';')
        length(row) == 3 && _smgw_csv_integer_v1(row[1], "row_supports.row") == index &&
            row[2] == string(replay.row_blocks[index]) && row[3] == expected_columns ||
            throw(ArgumentError("serialized row support replay mismatch at row $index"))
    end

    iterations = _smr_read_canonical_json_v1(read(by_name[:iterations], String))
    iterations_match = _smgw_json_equal_v1(iterations, report.solver.iterations)
    attempt_wire = read(by_name[:attempts], String)
    canonical_attempt_wire = canonical_json(report.solver.attempts)
    expected_attempt_bytes = codeunits(canonical_attempt_wire)
    actual_attempt_bytes = codeunits(attempt_wire)
    attempts_match = length(actual_attempt_bytes) == length(expected_attempt_bytes) + 1 &&
        actual_attempt_bytes[end] == 0x0a
    if attempts_match
        for index in eachindex(expected_attempt_bytes)
            if expected_attempt_bytes[index] != actual_attempt_bytes[index]
                attempts_match = false
                break
            end
        end
    end
    canonical_attempt_wire = nothing
    iterations_match && attempts_match ||
        throw(ArgumentError("serialized solver history differs from primary report"))
    attempt_wire = nothing
    for name in names
        _smgw_sha256_file_v1(by_name[name]) == sha_by_name[name] ||
            throw(ArgumentError("global weak artifact changed during replay: $name"))
    end
    by_name
end

"""Validate a fresh process's GlobalWeak artifacts without trusting its memory state.

The final state is reconstructed only from `solver_state.csv`; the primary JSON
is a claim and binding record.  A copied tree is acceptable when every embedded
artifact path is rebound into that copy and all bytes, hashes, and row counts
are updated consistently.  Reassembly from the CSV-derived state remains the
acceptance check.  This validator confers no physical or publication authority.
"""
function _smgw_q1_continuation_obligation_shapes_v1(obligations, expected_bounds_hash::Digest256)
    screen_input_hash = canonical_hash((schema="fusionconceptai:screen-input", revision="v1"))
    shapes = Tuple(begin
        obligation isa CapabilitySignatureV4 ||
            throw(ArgumentError("Q1 continuation obligations must remain typed capability signatures"))
        is_structural_screen = obligation.schema == "fusionconceptai:runtime-v4-screen" &&
            obligation.revision == "v1" && obligation.kind === :structural_screen &&
            obligation.operator == "typed_structure_audit" &&
            obligation.input_schema_hash == screen_input_hash
        if is_structural_screen
            obligation.applicability_bounds == expected_bounds_hash ||
                throw(ArgumentError("structural obligation is not bound to this admitted context bounds"))
            canonical_hash(merge(semantic_view(obligation),
                (applicability_bounds=:candidate_scoped_bounds,)))
        else
            canonical_hash(obligation)
        end
    end for obligation in obligations)
    # Compilation orders the source tuple by full hashes; those hashes change
    # with bounds, so sort projected digests to compare level-independent membership.
    Tuple(sort!(collect(shapes); by=string))
end

function _smgw_q1_continuation_context_family_v1(admission::_SMGWOperatorAdmissionV1)
    context = admission.context
    context_bounds_hash = _runtime_decl_hash(context.bounds_payload)
    context.compiled.minimality_scope.bounds_hash == context_bounds_hash ||
        throw(ArgumentError("continuation context compiled bounds differ from its admitted bounds"))
    obligation_shapes = _smgw_q1_continuation_obligation_shapes_v1(
        context.compiled.capability_obligations, context_bounds_hash)
    candidate = context.candidate
    parent_provenance = only(filter(value -> value isa NamedTuple && hasproperty(value, :parent_candidate_hash),
        candidate.field_geometry_genome_ref.fields))
    proposals = Tuple((proposal_id=proposal.proposal_id,
        candidate_or_prefix_ref=proposal.candidate_or_prefix_ref, parent_refs=proposal.parent_refs,
        search_channel=proposal.search_channel, target_behavior_cell=proposal.target_behavior_cell,
        predicted_outcomes=proposal.predicted_outcomes, uncertainty=proposal.uncertainty,
        estimated_cost=proposal.estimated_cost, requested_next_stage=proposal.requested_next_stage,
        common_edit_trace=Tuple((g1=edit.g1, g2=edit.g2, g3=edit.g3,
            engineering_hash=edit.engineering_hash, verification_hash=edit.verification_hash)
            for edit in proposal.typed_edit_trace)) for proposal in candidate.proposal_lineage)
    (identity_ref=candidate.identity_ref,
        parent_binding=(candidate_hash=parent_provenance.parent_candidate_hash,
            package_hash=parent_provenance.parent_package_hash, context_hash=parent_provenance.parent_context_hash),
        mission_contract_ref=candidate.mission_contract_ref,
        mechanism=(seed=candidate.mechanism_genome_ref.seed,
            contract_ref=candidate.mechanism_genome_ref.contract_ref),
        field_geometry=(seed=candidate.field_geometry_genome_ref.seed,
            contract_ref=candidate.field_geometry_genome_ref.contract_ref),
        realization_control=(seed=candidate.realization_control_genome_ref.seed,
            control_seed=candidate.realization_control_genome_ref.control_seed,
            contract_ref=candidate.realization_control_genome_ref.contract_ref,
            realization=candidate.realization_control_genome_ref.realization,
            verification=first(candidate.realization_control_genome_ref.control)),
        resolution=candidate.resolution, lifecycle=candidate.lifecycle,
        applicability_records=candidate.applicability_records, compilation_records=candidate.compilation_records,
        stage_evidence_refs=candidate.stage_evidence_refs, archive_memberships=candidate.archive_memberships,
        claim_ceiling=candidate.claim_ceiling, registry_hash=context.registry_hash,
        mission_payload=context.mission_payload,
        common_bounds=(engineering_hash=context.bounds_payload.engineering_hash,
            verification_hash=context.bounds_payload.verification_hash, scope=context.bounds_payload.scope),
        subject_materialization=(revision=context.subject.materialized_payload.revision,
            changes=(g1=context.subject.materialized_payload.changes.g1,
                g2=context.subject.materialized_payload.changes.g2,
                g3=context.subject.materialized_payload.changes.g3,
                engineering_hash=context.subject.materialized_payload.changes.engineering_hash,
                verification_hash=context.subject.materialized_payload.changes.verification_hash),
            authority=context.subject.materialized_payload.provenance.authority),
        comparison_scope=context.comparison_scope, scenario_scope=context.scenario_scope,
        scenario=context.scenario, scenario_hash=context.scenario_hash,
        # Context admission checks each exact bounds hash and complete obligation set.
        # Cross-level family identity normalizes only the structural screen's candidate bounds.
        obligation_shapes=obligation_shapes, proposals=proposals)
end

function _smgw_current_q1_4_artifact_state_v1(context, artifact_directory, target_context)
    admission = _smgw_admit_context_v1(context)
    target_admission = _smgw_admit_context_v1(target_context)
    source_input = admission.declaration.source.input
    target_input = target_admission.declaration.source.input
    source_input.mesh.level === :q1_4 && target_input.mesh.level === :q1_8 ||
        throw(ArgumentError("Q1 continuation requires an admitted Q1_4-to-Q1_8 candidate pair"))
    source_policy = Tuple((key, getproperty(source_input.numerics, key))
        for key in keys(source_input.numerics) if key !== :seconds)
    target_policy = Tuple((key, getproperty(target_input.numerics, key))
        for key in keys(target_input.numerics) if key !== :seconds)
    source_input.geometry == target_input.geometry && source_input.fields == target_input.fields &&
        source_input.initialization == target_input.initialization &&
        source_input.quadrature == target_input.quadrature && source_input.boundary == target_input.boundary &&
        source_input.flux == target_input.flux && source_input.provenance == target_input.provenance &&
        source_policy == target_policy ||
        throw(ArgumentError("Q1 continuation candidate contexts do not share the same physical input/policy"))
    source_context_family = _smgw_q1_continuation_context_family_v1(admission)
    target_context_family = _smgw_q1_continuation_context_family_v1(target_admission)
    source_context_family.identity_ref == _SMM_CANDIDATE_ID_V1 &&
        target_context_family.identity_ref == _SMM_CANDIDATE_ID_V1 &&
        canonical_hash(source_context_family) == canonical_hash(target_context_family) ||
        throw(ArgumentError("Q1 continuation source candidate/context family differs from target"))
    input = admission.declaration.source.input
    input.mesh.level === :q1_4 || throw(ArgumentError("continuation source context must be current Q1_4"))
    validation = validate_spatial_manufactured_global_weak_artifacts_v1(context, artifact_directory;
        expected_candidate_hash=string(context.candidate_hash),
        expected_context_hash=string(context.context_hash),
        expected_input_hash=string(admission.input_hash),
        expected_semantic_identities=_smgw_current_semantic_identities_v1(),
        _consumer_admission=admission)
    validation.solver_exit_code == 0 && validation.status === :converged &&
        validation.numerical_status === :full_discrete_residual_converged &&
        validation.stopping_reason === :all_scaled_residuals_converged &&
        validation.accepted_update_count <= input.numerics.max_iterations &&
        validation.final_scaled_residual_max <= input.numerics.residual_tolerance &&
        validation.elapsed_seconds <= input.numerics.seconds ||
        throw(ArgumentError("current Q1_4 continuation artifact did not pass its frozen numerical gate"))
    (input=input, mesh=validation.mesh, state=validation.final_state)
end

function validate_spatial_manufactured_global_weak_artifacts_v1(context, artifact_directory;
        expected_candidate_hash, expected_context_hash, expected_input_hash, expected_semantic_identities,
        _consumer_admission=nothing, continuation_source_context=nothing, continuation_source_dir=nothing,
        _consumer_projection=false, _expected_result_hash=nothing)
    before_identities = _smgw_check_semantic_identities_v1(expected_semantic_identities)
    root = _smgw_existing_root_v1(artifact_directory)
    if _consumer_admission === nothing
        declared = _smr_declaration(context)
        validate_spatial_n1_manufactured_declaration_v1(declared)
    else
        _consumer_admission isa _SMGWOperatorAdmissionV1 ||
            throw(ArgumentError("consumer replay reuse requires its admitted operator binding"))
        _consumer_admission.context === context ||
            throw(ArgumentError("consumer admission belongs to a different context object"))
        declared = _consumer_admission.declaration
        _smgw_assert_admission_identity_v1(_consumer_admission, declared)
    end
    input = declared.source.input
    if _consumer_admission === nothing
        validate_spatial_manufactured_candidate_input_v1(context, input)
    else
        _consumer_admission.input_hash == canonical_hash(input) ||
            throw(ArgumentError("consumer admission input identity changed"))
    end
    String(expected_candidate_hash) == string(context.candidate_hash) ||
        throw(ArgumentError("expected candidate hash differs from current context"))
    String(expected_context_hash) == string(context.context_hash) ||
        throw(ArgumentError("expected context hash differs from current context"))
    String(expected_input_hash) == string(canonical_hash(input)) ||
        throw(ArgumentError("expected manufactured input hash differs from current declaration"))
    report_path = _smgw_confined_file_v1(root, joinpath(root, "global_weak_primary.json"), "global_weak_primary")
    report_wire = read(report_path, String)
    report_primary_sha256 = bytes2hex(SHA.sha256(IOBuffer(report_wire)))
    report = _smr_read_canonical_json_v1(report_wire)
    report_wire = nothing
    report_fields = (:schema, :binding, :declaration_hash, :input_hash, :operator_identity,
        :geometry_receipt, :solver, :final_assembly, :solver_exit_code, :stopping_reason,
        :status, :numerical_status, :accepted_update_count, :final_scaled_residual_max,
        :artifacts, :physical_validation, :authority, :formal_policy, :spatial_closures,
        :claim_ceiling, :desc_execution, :engineering_execution, :whole_device_validation,
        :run_dir, :result_hash)
    _smgw_require_json_keys_v1(report, report_fields, "global_weak_primary")
    report.schema == _SMGW_RESULT_SCHEMA_V2 || throw(ArgumentError("unsupported GlobalWeak primary schema"))
    binding = _smgw_require_json_keys_v1(report.binding,
        (:candidate_hash, :context_hash, :context_candidate_hash), "primary.binding")
    _smgw_digest_from_wire_v1(binding.candidate_hash, "primary.binding.candidate_hash") == context.candidate_hash &&
        _smgw_digest_from_wire_v1(binding.context_candidate_hash, "primary.binding.context_candidate_hash") == context.candidate_hash &&
        _smgw_digest_from_wire_v1(binding.context_hash, "primary.binding.context_hash") == context.context_hash ||
        throw(ArgumentError("GlobalWeak primary candidate/context binding mismatch"))
    _smgw_digest_from_wire_v1(report.declaration_hash, "primary.declaration_hash") == canonical_hash(declared) &&
        _smgw_digest_from_wire_v1(report.input_hash, "primary.input_hash") == canonical_hash(input) ||
        throw(ArgumentError("GlobalWeak primary declaration/input binding mismatch"))
    hasproperty(report.solver, :residual_partition) ||
        throw(ArgumentError("GlobalWeak primary solver lacks its residual partition mode"))
    solver_mode = _smgw_partition_mode_v1(report.solver.residual_partition)
    _smgw_json_equal_v1(report.operator_identity,
        spatial_global_weak_operator_identity_v1(; residual_partition=solver_mode)) ||
        throw(ArgumentError("GlobalWeak operator identity mismatch"))
    report.physical_validation == "unsupported" && report.authority == "no_publish" &&
        report.claim_ceiling == "screen_only" && report.desc_execution == "not_executed" &&
        report.engineering_execution == "not_executed" && report.whole_device_validation == "unsupported" ||
        throw(ArgumentError("GlobalWeak primary scope was promoted"))
    _smgw_json_equal_v1(report.formal_policy, (status=:typed_absent, value=nothing)) ||
        throw(ArgumentError("missing formal policy must remain typed_absent"))
    closures = _smgw_require_json_keys_v1(report.spatial_closures,
        (:J_source, :return_current_path, :B_out, :K_outer, :pressure_current_topology),
        "primary.spatial_closures")
    all(key -> begin
        closure = getproperty(closures, key)
        closure isa NamedTuple && keys(closure) == (:status, :value) &&
            closure.status == "typed_absent" && closure.value === nothing
    end, keys(closures)) || throw(ArgumentError("missing spatial closures must remain typed_absent"))
    body_keys = Tuple(key for key in keys(report) if key != :result_hash)
    report_body = NamedTuple{body_keys}(Tuple(getproperty(report, key) for key in body_keys))
    report_hash = canonical_hash(report_body)
    _smgw_digest_from_wire_v1(report.result_hash, "primary.result_hash") == report_hash ||
        throw(ArgumentError("GlobalWeak primary canonical result hash mismatch"))
    _expected_result_hash === nothing || _expected_result_hash isa AbstractString &&
        occursin(r"\A[0-9a-f]{64}\z", _expected_result_hash) ||
        throw(ArgumentError("expected producer result hash must be lowercase SHA-256"))
    _expected_result_hash === nothing || String(_expected_result_hash) == string(report_hash) ||
        error("producer result hash differs from bound primary artifact")
    report.run_dir isa AbstractString && realpath(String(report.run_dir)) == root ||
        throw(ArgumentError("GlobalWeak primary run_dir differs from supplied artifact root"))

    receipt = _smgw_geometry_receipt_from_wire_v1(report.geometry_receipt, input)
    receipt.candidate_hash == context.candidate_hash && receipt.context_hash == context.context_hash &&
        receipt.declaration_hash == canonical_hash(declared) && receipt.input_hash == canonical_hash(input) ||
        throw(ArgumentError("serialized geometry receipt binding mismatch"))
    for key in (:nodes, :volume, :faces)
        artifact = getproperty(receipt.raw_artifacts, key)
        path = _smgw_confined_file_v1(root, artifact.path, "geometry_receipt.raw_artifacts.$key")
        path == joinpath(root, "geometry", "manufactured_$(key).csv") &&
            artifact.schema == "spatial-manufactured-geometry-v1" ||
            throw(ArgumentError("manufactured geometry artifact path/schema mismatch: $key"))
    end
    provider_record_path = _smgw_confined_file_v1(root,
        joinpath(root, "geometry", "manufactured_provider.json"), "manufactured_provider.json")
    provider_wire = read(provider_record_path, String)
    provider_record = _smr_read_canonical_json_v1(provider_wire)
    _smgw_json_equal_v1(provider_record, receipt) ||
        throw(ArgumentError("manufactured provider record differs from primary receipt"))
    if _consumer_admission === nothing
        validate_spatial_manufactured_geometry_v1(context, input, receipt)
    else
        _smm_validate_geometry_receipt_v1(input, declared,
            (candidate_hash=context.candidate_hash, context_hash=context.context_hash), receipt)
    end
    data = load_spatial_data_v4(declared, (level=input.mesh.level, nfp=input.mesh.nfp,
        flux_Wb=input.flux.nominal_Wb, raw_artifacts=receipt.raw_artifacts))

    solver_fields = (:schema, :initial_state, :final_state, :iterations, :state_history,
        :solver_exit_code, :stopping_reason, :status, :numerical_status, :accepted_update_count,
        :attempt_count, :attempts, :final_assembly, :final_scaled_residual_max,
        :final_scaled_residual_norm, :rank_diagnostics, :physical_checks, :elapsed_seconds,
        :operator_binding, :residual_partition, :step_identity, :step_identity_hash,
        :numerical_policy, :formal_policy, :spatial_closures,
        :physical_validation, :authority, :claim_ceiling)
    solver = _smgw_require_json_keys_v1(report.solver, solver_fields, "primary.solver")
    _smgw_verify_solver_step_identity_v1(solver) == solver_mode ||
        throw(ArgumentError("serialized solver partition mode changed during validation"))
    solver.schema == "spatial-global-weak-solver-state-v2" && solver.final_assembly === nothing ||
        throw(ArgumentError("unsupported serialized solver state schema"))
    _smgw_json_equal_v1(solver.formal_policy, report.formal_policy) &&
        _smgw_json_equal_v1(solver.spatial_closures, report.spatial_closures) &&
        solver.physical_validation == "unsupported" && solver.authority == "no_publish" &&
        solver.claim_ceiling == "screen_only" ||
        throw(ArgumentError("serialized solver scope/bindings differ from primary"))
    solver.numerical_policy isa NamedTuple || throw(ArgumentError("serialized numerical policy is missing"))
    policy = input.numerics
    expected_policy = (max_iterations=policy.max_iterations, seconds=policy.seconds,
        residual_tolerance=policy.residual_tolerance, gradient_tolerance=policy.gradient_tolerance,
        rank_relative_tolerance=policy.rank_relative_tolerance,
        kkt_absolute_tolerance=policy.kkt_absolute_tolerance,
        line_search_steps=policy.line_search_steps, pressure_lower_Pa=policy.pressure_lower_Pa)
    _smgw_json_equal_v1(solver.numerical_policy, expected_policy) ||
        throw(ArgumentError("serialized numerical policy differs from frozen declaration"))
    state_path = _smgw_confined_file_v1(root, joinpath(root, "solver_state.csv"), "solver_state.csv")
    state_rows = _smgw_csv_rows_v1(read(state_path), "node_id,BR_T,Bphi_T,BZ_T,p_Pa", "solver_state")
    length(state_rows) == size(data.mesh.nodes_q, 2) || throw(ArgumentError("solver state row count mismatch"))
    state = Float64[]
    for (index, row) in enumerate(state_rows)
        length(row) == 5 || throw(ArgumentError("solver state row width mismatch"))
        _smgw_csv_integer_v1(row[1], "solver_state.node_id") == index ||
            throw(ArgumentError("solver state IDs must be unique, ordered, and complete"))
        append!(state, (_smgw_csv_float_v1(row[column], "solver_state.value") for column in 2:5))
    end
    continuation_source_context === nothing && continuation_source_dir === nothing ||
        continuation_source_context !== nothing && continuation_source_dir !== nothing ||
        throw(ArgumentError("Q1 continuation requires both the current source context and artifact directory"))
    if continuation_source_context === nothing
        initial_state = Tuple(data.initial_state)
        _smgw_json_equal_v1(solver.initial_state, initial_state) &&
            _smgw_json_equal_v1(solver.final_state, Tuple(state)) ||
            throw(ArgumentError("serialized solver state differs from fresh artifact state"))
    else
        source = _smgw_current_q1_4_artifact_state_v1(continuation_source_context,
            continuation_source_dir, context)
        initial_state = Tuple(spatial_q1_4_to_q1_8_initial_state_v1(source.input, source.mesh,
            source.state, input, data.mesh; pressure_scale_Pa=declared.scaling.p_Pa))
        _smgw_json_equal_v1(solver.initial_state, initial_state) &&
            _smgw_json_equal_v1(solver.final_state, Tuple(state)) ||
            throw(ArgumentError("serialized solver state differs from current Q1_4 continuation seed/final artifact state"))
    end
    admission = _consumer_admission === nothing ?
        _smgw_admission_record_v1(context, declared) : _consumer_admission
    replay_seal = _smgw_capture_operator_binding_v1(admission, data, receipt, initial_state;
        residual_partition=solver_mode)
    _smgw_json_equal_v1(solver.operator_binding, _smgw_operator_binding_wire_v1(replay_seal)) ||
        throw(ArgumentError("serialized operator binding differs from fresh source/data replay"))
    solver.state_history isa Tuple && !isempty(solver.state_history) ||
        throw(ArgumentError("serialized state history is empty"))
    length(solver.iterations) == length(solver.state_history) &&
        all(state_row -> state_row isa Tuple && length(state_row) == length(state) &&
            all(value -> value isa Real && !(value isa Bool) && isfinite(value), state_row), solver.state_history) ||
        throw(ArgumentError("serialized solver history has invalid state coverage"))
    _smgw_json_equal_v1(first(solver.state_history), initial_state) &&
        _smgw_json_equal_v1(last(solver.state_history), Tuple(state)) ||
        throw(ArgumentError("serialized state history endpoints differ from input/CSV"))

    replay = assemble_spatial_global_weak_system_v1(declared, data, state;
        flux_Wb=input.flux.nominal_Wb, jacobian=true, residual_partition=solver_mode)
    replay_checks = spatial_global_weak_physical_checks_v1(declared, data, state;
        flux_Wb=input.flux.nominal_Wb, residual_partition=solver_mode)
    serialized_assembly = _smgw_serializable_assembly_v1(replay)
    _smgw_json_equal_v1(report.final_assembly, serialized_assembly) ||
        throw(ArgumentError("serialized global residual/Jacobian/scale/support replay mismatch"))
    _smgw_json_equal_v1(report.solver.final_scaled_residual_max, maximum(abs, replay.residual ./ replay.row_scales)) &&
        _smgw_json_equal_v1(report.solver.final_scaled_residual_norm, norm(replay.residual ./ replay.row_scales)) ||
        throw(ArgumentError("serialized final residual metrics differ from fresh reassembly"))
    report.solver_exit_code == solver.solver_exit_code && report.stopping_reason == solver.stopping_reason &&
        report.status == solver.status && report.numerical_status == solver.numerical_status &&
        report.accepted_update_count == solver.accepted_update_count &&
        report.final_scaled_residual_max == solver.final_scaled_residual_max ||
        throw(ArgumentError("duplicated primary solver summary fields disagree"))
    solver.solver_exit_code isa Integer && !(solver.solver_exit_code isa Bool) &&
        solver.accepted_update_count isa Integer && !(solver.accepted_update_count isa Bool) &&
        solver.accepted_update_count >= 0 || throw(ArgumentError("serialized solver counters are invalid"))
    terminal_attempt_accepted = isempty(solver.attempts) ||
        (hasproperty(last(solver.attempts), :accepted) && last(solver.attempts).accepted === true)
    solver.attempt_count isa Integer && !(solver.attempt_count isa Bool) &&
        solver.attempt_count == length(solver.attempts) &&
        all(attempt -> hasproperty(attempt, :accepted) && attempt.accepted isa Bool, solver.attempts) &&
        solver.accepted_update_count == count(attempt -> attempt.accepted === true, solver.attempts) &&
        solver.accepted_update_count == length(solver.state_history) - 1 &&
        length(solver.iterations) == length(solver.attempts) + (terminal_attempt_accepted ? 1 : 0) ||
        throw(ArgumentError("serialized solver iteration/attempt accounting mismatch"))
    residual_max = maximum(abs, replay.residual ./ replay.row_scales)
    solver.final_scaled_residual_max == residual_max ||
        throw(ArgumentError("serialized solver residual metric differs from replay"))
    solver.solver_exit_code == 0 && residual_max > policy.residual_tolerance &&
        throw(ArgumentError("GlobalWeak solver claims false convergence"))
    solver.solver_exit_code == 0 && solver.status != "converged" &&
        throw(ArgumentError("GlobalWeak exit/status mismatch"))
    solver.solver_exit_code != 0 && solver.status != "fail" &&
        throw(ArgumentError("GlobalWeak failed exit/status mismatch"))
    solver.numerical_status == (solver.solver_exit_code == 0 ? "full_discrete_residual_converged" : "numerical_fail") ||
        throw(ArgumentError("GlobalWeak numerical status/exit mismatch"))
    for index in 4:4:length(state)
        _smr_pressure_feasible(state[index], declared.scaling.p_Pa) ||
            throw(ArgumentError("serialized state violates pressure bound"))
    end
    row_artifacts = _smgw_check_row_artifacts_v1(root, report, data, state, replay, replay_checks)
    _smgw_json_equal_v1(solver.physical_checks, replay_checks) ||
        throw(ArgumentError("serialized physical/conservation checks differ from fresh replay"))
    post_identities = _smgw_check_semantic_identities_v1(expected_semantic_identities)
    before_identities == post_identities || throw(ArgumentError("semantic identity drift during artifact replay"))
    result = (schema="spatial-global-weak-artifact-replay-validation-v1",
        validation=:artifact_replay_completed,
        candidate_hash=string(context.candidate_hash), context_hash=string(context.context_hash),
        input_hash=string(canonical_hash(input)), result_hash=string(report_hash),
        state_hash=string(canonical_hash(Tuple(state))),
        final_scaled_residual_max=residual_max, jacobian_nnz=nnz(replay.jacobian),
        interface_checks=replay.interface_checks, boundary_checks=replay.boundary_checks,
        conservation_checks=replay.conservation_checks, numerical_status=Symbol(solver.numerical_status),
        solver_exit_code=Int(solver.solver_exit_code), status=Symbol(solver.status),
        stopping_reason=Symbol(solver.stopping_reason),
        accepted_update_count=Int(solver.accepted_update_count), elapsed_seconds=Float64(solver.elapsed_seconds),
        initial_state=Tuple(initial_state), final_state=Tuple(state), mesh=data.mesh,
        physical_validation=:unsupported, authority=:no_publish,
        semantic_identities=post_identities, replayed_artifacts=(:state, :residual, :jacobian, :row_supports, :iterations, :attempts))
    _consumer_projection isa Bool || throw(ArgumentError("consumer projection selector must be Bool"))
    _consumer_projection || return result
    consumer_artifact_paths = Dict("state"=>"solver_state.csv", "residual"=>"residual_rows.csv",
        "jacobian"=>"global_weak_jacobian.csv", "row_supports"=>"global_weak_row_supports.csv",
        "iterations"=>"iterations.json", "attempts"=>"attempts.json")
    artifact_projection = Tuple(sort!(collect((
        begin
            name = String(ref.name)
            relpath = get(consumer_artifact_paths, name, nothing)
            relpath === nothing && throw(ArgumentError("unknown GlobalWeak artifact name: $name"))
            path = normpath(joinpath(artifact_directory, relpath))
            sha = String(ref.sha256)
            (name=name, path=path, declared_sha256=sha, actual_sha256=sha)
        end for ref in report.artifacts)); by=x -> x.name))
    raw_paths = (nodes=joinpath(artifact_directory, "geometry", "manufactured_nodes.csv"),
        volume=joinpath(artifact_directory, "geometry", "manufactured_volume.csv"),
        faces=joinpath(artifact_directory, "geometry", "manufactured_faces.csv"))
    raw_wire = report.geometry_receipt.raw_artifacts
    geometry_projection = Tuple(sort!(collect((
        begin
            name = String(key)
            artifact = getproperty(raw_wire, key)
            path = normpath(String(getproperty(raw_paths, key)))
            sha = string(_smgw_digest_from_wire_v1(artifact.sha256, "geometry_receipt.raw_artifacts.$key.sha256"))
            _smgw_sha256_file_v1(path) == sha || throw(ArgumentError("geometry artifact changed during replay: $name"))
            (name=name, path=path, declared_sha256=sha, actual_sha256=sha)
        end for key in keys(raw_wire))); by=x -> x.name))
    solver_projection = report.solver
    operator_projection = solver_projection.operator_binding
    primary_projection = (
        binding=(candidate_hash=report.binding.candidate_hash, context_hash=report.binding.context_hash),
        input_hash=report.input_hash, geometry_receipt=report.geometry_receipt,
        solver=(final_state=solver_projection.final_state,
            operator_binding=(candidate_hash=operator_projection.candidate_hash,
                context_hash=operator_projection.context_hash)),
        solver_exit_code=report.solver_exit_code, status=report.status,
        numerical_status=report.numerical_status,
        final_scaled_residual_max=report.final_scaled_residual_max)
    consumer_binding = (primary_sha256=report_primary_sha256, result_hash=string(report_hash),
        artifact_set_hash=string(canonical_hash(artifact_projection)),
        geometry_artifact_set_hash=string(canonical_hash(geometry_projection)),
        primary_projection=primary_projection)
    merge(result, (consumer_artifact_binding=consumer_binding,))
end

"""Successor numerical consumer: same candidate/provider path, versioned weak solve.

This function is the additive successor to
`execute_spatial_manufactured_numerical_v1` → `_smr_write_case` →
`ManufacturedCandidateV1Tests.result_tests`; it does not route the V1 solver
result into the V1 validator. Its own replay validator reassembles raw global
residual/Jacobian and physical diagnostics. DESC and all formal closures remain
typed absent/unsupported.
"""
function execute_spatial_manufactured_global_weak_numerical_v1(context, run_dir;
        residual_partition=:spatial_native, stage_trace=nothing,
        continuation_source_context=nothing, continuation_source_dir=nothing)
    residual_partition = _smgw_partition_mode_v1(residual_partition)
    root = abspath(run_dir)
    ispath(root) && (!isdir(root) || !isempty(readdir(root))) &&
        throw(ArgumentError("preserve existing global weak numerical evidence directory"))
    mkpath(root)
    admission = _smgw_trace_stage_v1(stage_trace, "admission", () ->
        _smgw_admit_context_v1(context))
    declared = admission.declaration
    input = declared.source.input
    binding = (candidate_hash=context.candidate_hash, context_hash=context.context_hash)
    geometry_dir = joinpath(root, "geometry")
    receipt = _smgw_trace_stage_v1(stage_trace, "geometry_materialize", () ->
        _smm_materialize_geometry_v1(input, declared, binding, geometry_dir))
    data = _smgw_trace_stage_v1(stage_trace, "production_loader", () ->
        load_spatial_data_v4(declared, (level=input.mesh.level, nfp=input.mesh.nfp,
            flux_Wb=input.flux.nominal_Wb, raw_artifacts=receipt.raw_artifacts)))
    continuation_source_context === nothing && continuation_source_dir === nothing ||
        continuation_source_context !== nothing && continuation_source_dir !== nothing ||
        throw(ArgumentError("Q1 continuation requires both the current source context and artifact directory"))
    initial_state = if continuation_source_context === nothing
        data.initial_state
    else
        source = _smgw_current_q1_4_artifact_state_v1(continuation_source_context,
            continuation_source_dir, context)
        spatial_q1_4_to_q1_8_initial_state_v1(source.input, source.mesh, source.state,
            input, data.mesh; pressure_scale_Pa=declared.scaling.p_Pa)
    end
    solved = solve_spatial_global_weak_state_v1(declared, data, initial_state;
        flux_Wb=input.flux.nominal_Wb, admission=admission, geometry_receipt=receipt,
        residual_partition, stage_trace)
    artifact_rows = _smgw_write_solver_files_v1(root, solved)
    artifact_refs = Tuple((name=a.name, path=a.path, sha256=a.sha256, row_count=a.row_count)
        for a in artifact_rows)
    report = (schema=_SMGW_RESULT_SCHEMA_V2, binding=(candidate_hash=context.candidate_hash,
            context_hash=context.context_hash, context_candidate_hash=context.candidate_hash),
        declaration_hash=canonical_hash(declared), input_hash=canonical_hash(input),
        operator_identity=spatial_global_weak_operator_identity_v1(; residual_partition),
        geometry_receipt=receipt, solver=merge(solved, (final_assembly=nothing,)),
        final_assembly=_smgw_serializable_assembly_v1(solved.final_assembly),
        solver_exit_code=solved.solver_exit_code, stopping_reason=solved.stopping_reason,
        status=solved.status, numerical_status=solved.numerical_status,
        accepted_update_count=solved.accepted_update_count,
        final_scaled_residual_max=solved.final_scaled_residual_max,
        artifacts=artifact_refs, physical_validation=:unsupported, authority=:no_publish,
        formal_policy=solved.formal_policy, spatial_closures=solved.spatial_closures,
        claim_ceiling=screen_only, desc_execution=:not_executed,
        engineering_execution=:not_executed, whole_device_validation=:unsupported,
        run_dir=root)
    result_hash = canonical_hash(report)
    report_path = joinpath(root, "global_weak_primary.json")
    write(report_path, canonical_json(merge(report, (result_hash=result_hash,))) * "\n")
    result = (report=report, result_hash=result_hash, run_dir=root, report_path=report_path)
    validate_spatial_manufactured_global_weak_result_v1(context, result; run_dir=root,
        _producer_admission=admission)
    result
end

function _smgw_trace_event_v1(trace, name, edge)
    trace === nothing && return nothing
    try
        trace(name, edge, time_ns())
    catch err
        detail = try
            sprint(showerror, err)
        catch
            string(typeof(err))
        end
        try
            println(stderr, "SMGW_TRACE_INCOMPLETE name=", name, " edge=", edge,
                " reason=", detail)
            flush(stderr)
        catch
            # A broken trace sink must not alter the measured operation or its error.
        end
    end
    nothing
end

function _smgw_stage_diagnostic_v1(trace, marker; error=nothing, backtrace=nothing)
    trace === nothing && return nothing
    try
        println(stderr, "SMGW_STAGE_DIAGNOSTIC marker=", marker,
            " monotonic_ns=", time_ns())
        if error !== nothing
            println(stderr, "SMGW_STAGE_DIAGNOSTIC_ERROR marker=", marker,
                " detail=", sprint(showerror, error))
            backtrace === nothing || Base.show_backtrace(stderr, backtrace)
        end
        flush(stderr)
    catch
        # Diagnostic output must not change the solver stage or its exception.
    end
    nothing
end

function _smgw_trace_stage_v1(trace, name, operation::Function)
    trace === nothing && return operation()
    _smgw_trace_event_v1(trace, name, :begin)
    try
        operation()
    finally
        _smgw_trace_event_v1(trace, name, :end)
    end
end

function _smgw_block_norms_v1(assembly)
    names = (:momentum_N, :divB_Wb, :traction_N, :normal_B_Wb, :total_flux_Wb)
    NamedTuple{names}(Tuple(norm(assembly.residual[findall(==(block), assembly.row_blocks)]) for block in names))
end
