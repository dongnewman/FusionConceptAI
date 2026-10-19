"""Declared diffusion compile/lower/compose/execute vertical slice (V1).

This is an additive adapter between the already submitted
`DeclaredG123DiffusionExecutionV1` and `DeclaredSpatialCompositionExecutionV1`
seams.  It does not modify a registry or compiler.  The adapter validates a
candidate-bound G1/G2/G3 bundle, lowers the closed one-dimensional
structured diagonal-affine scalar or explicitly coupled scalar-field subset,
builds the existing typed port plan, and dispatches finite-volume block
assembly and linear solve. Static
calls preserve their prior behavior; an explicit time interval enables one
backward-Euler scalar step with the transferred `old_state` as history. Every
result is screen-only evidence.
"""

using SHA, LinearAlgebra

const DCCE_SCHEMA_V1 = "fusionconceptai:runtime-v4:declared-diffusion-compile-execute-v1"
const DCCE_REVISION_V1 = "up2-declared-diffusion-compile-execute-v1-r2"
const DCCE_CLAIM_CEILING_V1 = :screen_only
const DCCE_STATUSES_V1 = (:ready, :fail_closed, :terminal_deferred, :numerical_fail)
const DCCE_EXPRESSION_SUBSET_V1 = :diagonal_affine_static

_dcce_hash(x) = bytes2hex(sha256(codeunits(repr(x))))
_dcce_text(x, field) = begin
    s = strip(String(x)); isempty(s) && throw(ArgumentError("$field cannot be empty")); s
end

"The hash receipt is rebuilt from bundle records; it is not a display label."
struct DCCEHashReceiptV1
    candidate_ref::Any
    g1_body_hash::Any
    g2_body_hash::Any
    g3_body_hash::Any
    source_hashes::Tuple
    declaration_hashes::Tuple
    bundle_hash::Any
    receipt_hash::String
end

struct DCCETypedLoweringV1
    status::Symbol
    code::Symbol
    candidate_ref::Any
    expression_subset::Symbol
    dimension::Int
    field_count::Int
    temporal::Symbol
    coefficient_kind::Symbol
    time_interval::Any
    time_unit::Union{Nothing,Symbol}
    transient_capacity::Any
    k_cells::Tuple
    source::Tuple
    boundary::Any
    couplings::Tuple
    declaration_hash::String
    receipt_hash::String
end

struct DCCECompositionPlanV1
    status::Symbol
    code::Symbol
    candidate_ref::Any
    plan::Any
    edges::Tuple
    semantic_hash::String
    receipt_hash::String
end

struct DeclaredDiffusionCompileExecuteInputV1
    candidate_ref::Any
    g1::Any
    g2::Any
    g3::Any
    bundle::Any
    spatial_case::DeclaredSpatialCaseV1
    hashes::DCCEHashReceiptV1
end

struct DCCEOutcomeV1
    status::Symbol
    code::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    compile::Any
    lowering::Any
    composition::Any
    numerical::Any
    aggregate::Any
    hashes::Any
    receipt_hash::String
end

_dcce_phase(status, code; kwargs...) =
    merge((status=status, code=code, accepted=false,
        claim_ceiling=DCCE_CLAIM_CEILING_V1, provider_calls=0,
        mesh_calls=0, solver_calls=0), kwargs)

"Run the DCCE FV solve with one reusable LU and at most one correction solve.
The correction uses the original residual rhs-A*x. Static calls retain their
absolute residual contract; explicitly transient SI systems may use a
normwise backward-error contract because an absolute residual below 1e-12 is
not representable at their authored mass/RHS scales."
function _dcce_solve_with_one_refinement(A::Matrix{Float64}, rhs::Vector{Float64};
        initial_state=nothing, residual_tolerance=1.0e-12,
        relative_residual_tolerance=nothing)
    n = length(rhs)
    empty_work = (solver_calls=0, factorization_count=0,
        lu_rhs_solve_count=0, refinement_solve_count=0,
        initial_residual_norm=Inf, final_residual_norm=Inf)
    n == size(A, 1) == size(A, 2) ||
        return (nothing, Inf, :invalid_system, empty_work)
    all(isfinite, A) && all(isfinite, rhs) ||
        return (nothing, Inf, :nonfinite_derived, empty_work)
    rank(A) < n &&
        return (nothing, norm(A * zeros(n) - rhs, Inf), :singular_matrix, empty_work)

    factorization = lu(A)
    residual_scale(x) = max(1.0, opnorm(A, Inf) * norm(x, Inf) + norm(rhs, Inf))
    residual_measure(r, x) = relative_residual_tolerance === nothing ? r : r / residual_scale(x)
    solve_tolerance = relative_residual_tolerance === nothing ? residual_tolerance :
        relative_residual_tolerance
    if initial_state === nothing
        solution = factorization \ rhs
        residual = norm(A * solution - rhs, Inf)
    else
        solution = Float64.(collect(initial_state))
        length(solution) == n && all(isfinite, solution) ||
            return (nothing, Inf, :invalid_initial_state, empty_work)
        residual = norm(A * solution - rhs, Inf)
        if isfinite(residual) && residual_measure(residual, solution) > solve_tolerance
            solution += factorization \ (rhs - A * solution)
            residual = norm(A * solution - rhs, Inf)
        end
    end
    initial_residual = initial_state === nothing ? residual :
        norm(A * Float64.(collect(initial_state)) - rhs, Inf)
    initial_measure = residual_measure(initial_residual,
        initial_state === nothing ? solution : Float64.(collect(initial_state)))
    lu_rhs_solve_count = initial_state === nothing || initial_measure > solve_tolerance ? 1 : 0
    refinement_solve_count = initial_state !== nothing && initial_measure > solve_tolerance ? 1 : 0
    if initial_state === nothing && isfinite(residual) &&
            residual_measure(residual, solution) > solve_tolerance
        correction = factorization \ (rhs - A * solution)
        lu_rhs_solve_count += 1
        refinement_solve_count = 1
        solution = solution + correction
        residual = norm(A * solution - rhs, Inf)
    end
    work = (solver_calls=1, factorization_count=1,
        lu_rhs_solve_count=lu_rhs_solve_count,
        refinement_solve_count=refinement_solve_count,
        residual_measure_kind=relative_residual_tolerance === nothing ? :absolute_inf_norm : :normwise_backward_error,
        initial_residual_norm=initial_residual, final_residual_norm=residual,
        initial_residual_measure=initial_measure,
        final_residual_measure=residual_measure(residual, solution))
    isfinite(residual) && all(isfinite, solution) ||
        return (nothing, residual, :nonfinite_derived, work)
    (solution, residual, :joint_linear_solved, work)
end

"""Validate a cross-mesh transfer as a DCCE initial state.

The binding carries the typed receipt and the inputs needed to replay the
candidate-bound transfer.  This prevents an unbound vector or a stale receipt
from being used as a numerical warm start.
"""
function _dcce_cross_mesh_initial_state(input::DeclaredDiffusionCompileExecuteInputV1,
        binding)
    binding === nothing && return (nothing, :ready)
    required = (:receipt, :identity, :source_mesh, :target_mesh, :source_state, :accounts)
    all(k -> hasproperty(binding, k), required) ||
        return (nothing, :cross_mesh_binding_malformed)
    isdefined(@__MODULE__, :DeclaredCrossMeshTransferReceiptV1) &&
        isdefined(@__MODULE__, :DeclaredCrossMeshAccountsV1) &&
        isdefined(@__MODULE__, :DeclaredCrossMeshUnitV1) &&
        isdefined(@__MODULE__, :declared_cross_mesh_transfer_v1) ||
        return (nothing, :cross_mesh_transfer_api_unavailable)
    receipt = binding.receipt
    receipt isa DeclaredCrossMeshTransferReceiptV1 ||
        return (nothing, :cross_mesh_receipt_type_mismatch)
    accounts = binding.accounts
    accounts isa DeclaredCrossMeshAccountsV1 ||
        return (nothing, :cross_mesh_account_type_mismatch)
    all(account -> account !== nothing, (accounts.source, accounts.target,
            accounts.external, accounts.return_account)) ||
        return (nothing, :cross_mesh_account_missing)
    # UnitSignature records SI exponents but has no unit scale.  The transfer
    # arithmetic does not convert values, so every account must match u and
    # already be expressed at canonical SI scale.
    expected_units = Tuple(input.g1.u.physical_type.units.exponents)
    native_units = (accounts.source.unit, accounts.target.unit,
        accounts.external.unit, accounts.return_account.unit)
    all(unit -> unit isa DeclaredCrossMeshUnitV1 &&
        Tuple(unit.exponents) == expected_units && unit.scale_to_si == 1.0,
        native_units) || return (nothing, :cross_mesh_g1_unit_mismatch)
    receipt.status === :ready && receipt.code === :conservative_cross_mesh_transfer ||
        return (nothing, :cross_mesh_receipt_not_ready)
    try
        dgd = dgd_input_v1(input.candidate_ref, input.g1, input.g2, input.g3, input.bundle)
        replay = declared_cross_mesh_transfer_v1(dgd, binding.identity,
            binding.source_mesh, binding.target_mesh, binding.source_state;
            accounts=binding.accounts)
        replay.status === :ready && receipt.receipt_hash == replay.receipt_hash &&
            receipt.candidate_ref == replay.candidate_ref &&
            receipt.source_hash == replay.source_hash &&
            receipt.body_hash == replay.body_hash &&
            receipt.bundle_hash == replay.bundle_hash &&
            receipt.source_mesh_hash == replay.source_mesh_hash &&
            receipt.target_mesh_hash == replay.target_mesh_hash &&
            receipt.source_integrated_total == replay.source_integrated_total &&
            receipt.target_integrated_total == replay.target_integrated_total &&
            receipt.local_defects == replay.local_defects &&
            receipt.interface_defects == replay.interface_defects &&
            receipt.global_defect == replay.global_defect &&
            receipt.source_overlap_coverage == replay.source_overlap_coverage &&
            receipt.target_overlap_coverage == replay.target_overlap_coverage &&
            receipt.overlap_lengths == replay.overlap_lengths &&
            receipt.overlap_proportions == replay.overlap_proportions &&
            receipt.interface_faces == replay.interface_faces &&
            receipt.interface_orientations == replay.interface_orientations &&
            receipt.transferred_state == replay.transferred_state ||
            return (nothing, :cross_mesh_receipt_replay_mismatch)
        receipt.candidate_ref == input.candidate_ref ||
            return (nothing, :cross_mesh_candidate_mismatch)
        source_edges = Tuple((c.lower for c in binding.source_mesh.cells))
        source_edges = (source_edges..., last(binding.source_mesh.cells).upper)
        target_edges = Tuple((c.lower for c in binding.target_mesh.cells))
        target_edges = (target_edges..., last(binding.target_mesh.cells).upper)
        source_edges == Tuple(input.spatial_case.old_geometry.edges) ||
            return (nothing, :cross_mesh_source_geometry_mismatch)
        target_edges == Tuple(input.spatial_case.new_geometry.edges) ||
            return (nothing, :cross_mesh_target_geometry_mismatch)
        Tuple(Float64.(collect(binding.source_state))) == Tuple(input.spatial_case.old_state) ||
            return (nothing, :cross_mesh_source_state_mismatch)
        length(receipt.transferred_state) == length(input.spatial_case.new_geometry.edges) - 1 ||
            return (nothing, :cross_mesh_target_dof_mismatch)
        Tuple(receipt.transferred_state) == Tuple(measure_overlap_transfer(
            input.spatial_case.old_geometry, input.spatial_case.new_geometry,
            input.spatial_case.old_state).transfer.new_state) ||
            return (nothing, :cross_mesh_consumer_transfer_mismatch)
        (Float64.(collect(receipt.transferred_state)), :ready)
    catch
        (nothing, :cross_mesh_binding_invalid)
    end
end

function _dcce_hash_receipt(candidate, ghashes, bundle)
    records = Tuple(sort([r for r in bundle.declarations if
        r isa VNextT0LocalPresentDeclarationV1], by=r -> String(r.layer)))
    length(records) == 3 || throw(ArgumentError("bundle must contain exactly G1/G2/G3 records"))
    source_hashes = Tuple(r.source_bytes.sha256 for r in records)
    declaration_hashes = Tuple(r.declaration_bytes.sha256 for r in records)
    body = (candidate_ref=candidate, g1_body_hash=ghashes.g1_body_hash,
        g2_body_hash=ghashes.g2_body_hash, g3_body_hash=ghashes.g3_body_hash,
        source_hashes=source_hashes, declaration_hashes=declaration_hashes,
        bundle_hash=ghashes.bundle_hash)
    DCCEHashReceiptV1(candidate, ghashes.g1_body_hash, ghashes.g2_body_hash,
        ghashes.g3_body_hash, source_hashes, declaration_hashes, ghashes.bundle_hash,
        _dcce_hash(body))
end

"Strict constructor: the existing DGD input validator performs byte-level
 candidate/source/declaration/body/bundle validation before this adapter runs."
function dcce_input_v1(candidate, g1, g2, g3, bundle, spatial_case)
    spatial_case isa DeclaredSpatialCaseV1 || throw(ArgumentError("spatial_case must be typed"))
    dgd = dgd_input_v1(candidate, g1, g2, g3, bundle)
    hashes = _dcce_hash_receipt(candidate, dgd.hashes, bundle)
    DeclaredDiffusionCompileExecuteInputV1(candidate, g1, g2, g3, bundle, spatial_case, hashes)
end

function _dcce_failure(candidate, code; status=:fail_closed, hashes=nothing,
                       compile=nothing, lowering=nothing, composition=nothing,
                       numerical=nothing, detail=String(code), solver_calls=0)
    aggregate = _dcce_phase(status, code; resolution=status, detail=detail,
        accepted=false, formal_up_credit=false, formal_r_credit=false,
        screen_only=true, hashes=hashes, solver_calls=solver_calls)
    body = (candidate=candidate, status=status, code=code,
        compile=compile, lowering=lowering, composition=composition,
        numerical=numerical, hashes=hashes)
    DCCEOutcomeV1(status, code, false, DCCE_CLAIM_CEILING_V1, compile, lowering,
        composition, numerical, aggregate, hashes, _dcce_hash(body))
end

function _dcce_public_candidate(candidate)
    try
        (id=getproperty(candidate, :id), version=getproperty(candidate, :version))
    catch
        (id=String(candidate), version="unknown")
    end
end

"Lower the closed declaration subset into the existing spatial FV field.
The spatial field values remain explicit numerical inputs, while G1's
candidate-owned K/source types and hashes are retained in the lowering receipt."
function _dcce_g1_authored_roots_x_only_v1(capability)
    capability.schema == "fusionconceptai:genome-v5:g1-authored-typed-source-field-program-v1" ||
        return false
    capability.program isa NamedTuple && keys(capability.program) == (:u, :f) ||
        return false
    for role in (:u, :f)
        ast = getproperty(capability.program, role).ast
        ast isa TypedASTProgramV1 || return false
        states = Vector{Any}(undef, length(ast.nodes))
        for (position, node) in enumerate(ast.nodes)
            if typeof(node) === ASTInputV1
                states[position] = (shape=:chart_vector, x_only=false, value=nothing)
            elseif typeof(node) === ASTConstantV1
                if node.value isa Tuple && length(node.value) == 3
                    states[position] = (shape=:constant_vector, x_only=true,
                        value=Tuple(Float64.(node.value)))
                elseif node.value isa Real
                    states[position] = (shape=:scalar, x_only=true,
                        value=Float64(node.value))
                else
                    return false
                end
            elseif typeof(node) === ASTApplyV1
                all(i -> 1 <= i < position, node.inputs) || return false
                args = Tuple(states[i] for i in node.inputs)
                id = node.operator_ref.qualified.id
                if id == "DOT" && length(args) == 2
                    left, right = args
                    if left.shape === :chart_vector &&
                            right.shape === :constant_vector &&
                            right.value == (1.0, 0.0, 0.0)
                        states[position] = (shape=:scalar, x_only=true, value=nothing)
                    elseif right.shape === :chart_vector &&
                            left.shape === :constant_vector &&
                            left.value == (1.0, 0.0, 0.0)
                        states[position] = (shape=:scalar, x_only=true, value=nothing)
                    elseif left.shape === :constant_vector &&
                            right.shape === :constant_vector
                        states[position] = (shape=:scalar, x_only=true, value=sum(
                            left.value[i] * right.value[i] for i in 1:3))
                    else
                        return false
                    end
                elseif id == "IDENTITY" && length(args) == 1 &&
                        args[1].shape === :scalar
                    states[position] = args[1]
                elseif id in ("ADD", "SUB", "NEG", "SCALAR_MUL", "SCALAR_DIV") &&
                        all(arg -> arg.shape === :scalar && arg.x_only, args)
                    arity_ok = id == "NEG" ? length(args) == 1 :
                        id in ("ADD", "SUB", "SCALAR_MUL", "SCALAR_DIV") ?
                            length(args) == 2 : false
                    arity_ok || return false
                    states[position] = (shape=:scalar, x_only=true, value=nothing)
                else
                    return false
                end
            else
                return false
            end
        end
        root = only(ast.roots)
        states[root].shape === :scalar && states[root].x_only || return false
    end
    true
end

function dcce_typed_lower_v1(input::DeclaredDiffusionCompileExecuteInputV1)
    try
        g1_status, g1_errors = g1_diffusion_validate(input.g1)
        g1_status === :valid || return _dcce_phase(:fail_closed, :g1_declaration_invalid;
            detail=g1_errors)
        k = input.g1.K.expression
        k isa G1DiffusionDiagonalAffineKFieldV1 ||
            return _dcce_phase(:terminal_deferred, :unsupported_anisotropic;
                detail="only diagonal affine K is executable")
        uexpr = input.g1.u.source_expression
        fexpr = input.g1.f.source_expression
        authored_program_spec = _dgd_current_source_g1_typed_spec_v1(input.g1)
        typed_program_input = nothing
        if authored_program_spec !== nothing ||
            uexpr == DGD_G1_TYPED_SOURCE_MARKER_V1
            typed_program_input = DeclaredG123InputV1(input.candidate_ref,
                input.g1, input.g2, input.g3, input.bundle,
                DeclaredG123HashSetV1(input.candidate_ref,
                    input.hashes.g1_body_hash, input.hashes.g2_body_hash,
                    input.hashes.g3_body_hash, input.hashes.bundle_hash))
            _dgd_g1_typed_source_capability_v1(typed_program_input) === nothing &&
                return _dcce_phase(:terminal_deferred,
                    authored_program_spec === nothing ?
                        :g1_typed_source_program_missing :
                        :candidate_authored_g1_program_not_reconstructed;
                    detail="G1 typed source has no reconstructed T0 typed program")
        else
            uexpr in DGD_ALLOWED_U_EXPRESSIONS_V1 ||
                return _dcce_phase(:terminal_deferred,
                    occursin("sin", fexpr) || occursin("exp", fexpr) ?
                        :unsupported_nonlinear : :unsupported_expression;
                    detail="u expression is outside the static scalar subset")
            fexpr in DGD_ALLOWED_F_EXPRESSIONS_V1 ||
                return _dcce_phase(:terminal_deferred,
                    occursin("t", fexpr) ? :unsupported_time : :unsupported_nonlinear;
                    detail="f expression is outside the static affine subset")
        end
        field = input.spatial_case.field
        component_fields = input.spatial_case.component_fields
        component_boundaries = input.spatial_case.component_boundaries
        component_count = length(component_fields)
        n = length(field.k_cells)
        n >= 2 && length(field.source) == n ||
            return _dcce_phase(:fail_closed, :multifield_or_size_mismatch;
                detail="structured scalar lowering requires one K/source value per cell")
        vf = validate_declared_field_hashes(field)
        vf.valid || return _dcce_phase(vf.status, vf.code; detail=vf.detail)
        boundary = input.spatial_case.boundary
        vb = validate_declared_boundary(boundary)
        vb.valid || return _dcce_phase(vb.status, vb.code; detail=vb.detail)
        component_count >= 1 && length(component_boundaries) == component_count &&
            all(x -> length(x.k_cells) == n && length(x.source) == n &&
                validate_declared_field_hashes(x).valid, component_fields) ||
            return _dcce_phase(:fail_closed, :multifield_or_size_mismatch;
                detail="each declared component requires cell-aligned, hash-valid K/source values")
        if component_count > 1
            all(x -> validate_declared_boundary(x).valid, component_boundaries) ||
                return _dcce_phase(:fail_closed, :multifield_boundary_invalid;
                    detail="every component requires its own complete boundary declaration")
            isempty(input.spatial_case.couplings) && return _dcce_phase(:terminal_deferred,
                :multifield_coupling_absent;
                detail="multifield execution requires an explicit component coupling declaration")
            expected_coupling_units = UnitSignature((-2, 0, 0, 0, 0, 0, 0))
            all(c -> 1 <= c.left_component < c.right_component <= component_count &&
                isfinite(c.coefficient) && c.coefficient > 0 && c.closed &&
                c.units isa UnitSignature && c.units == expected_coupling_units &&
                c.source_ref == input.g1.source_ref, input.spatial_case.couplings) ||
                return _dcce_phase(:fail_closed, :multifield_coupling_invalid;
                    detail="couplings must be closed positive L^-2 declarations bound to this G1 source")
            length(input.spatial_case.component_old_states) == component_count ||
                return _dcce_phase(:fail_closed, :multifield_history_missing;
                    detail="one old-state history is required for each declared component")
        end
        # G1 physical types are the unit/dimension gate.  Constructors upstream
        # guarantee the full tensor algebra; repeat the scalar/rank checks here
        # so this execution boundary cannot silently widen to multifield. A
        # A source-authored discrete-time G1 law selects a backward-Euler step.
        # Steady G1 declarations remain a separate static-only route.
        up = input.g1.u.physical_type; fp = input.g1.f.physical_type
        kp = input.g1.K.physical_type
        up.tensor_rank == 0 && fp.tensor_rank == 0 && kp.tensor_rank == 2 ||
            return _dcce_phase(:fail_closed, :units_dimension_mismatch;
                detail="u/f must be scalar and K rank-2")
        up.spatial_dimension == 3 && fp.spatial_dimension == 3 && kp.spatial_dimension == 3 ||
            return _dcce_phase(:fail_closed, :units_dimension_mismatch;
                detail="declaration spatial dimension is not three")
        interval = input.spatial_case.time_interval
        transient_capacity = input.g1.source_payload.transient_capacity
        static_g1 = up.temporal_type == TemporalTypeV1(static_time) &&
            kp.temporal_type == TemporalTypeV1(static_time) &&
            fp.temporal_type == TemporalTypeV1(static_time)
        # Discrete/event time types require a clock reference.  Do not build
        # an invalid clockless TemporalType merely to compare kinds; validate
        # the admitted clock-bearing type and require u/K/f to share it.
        discrete_g1 = up.temporal_type.kind === discrete_time &&
            up.temporal_type.derivative_order == 0 &&
            up.temporal_type.clock_ref !== nothing &&
            kp.temporal_type == up.temporal_type &&
            fp.temporal_type == up.temporal_type
        (interval === nothing ? static_g1 : discrete_g1) ||
            return _dcce_phase(:terminal_deferred, :unsupported_time;
                detail="steady G1 requires static fields; backward Euler requires source-authored discrete-time u/K/f")
        if interval !== nothing
            all(isfinite, interval) && interval[2] > interval[1] ||
                return _dcce_phase(:fail_closed, :invalid_time_interval;
                    detail="backward-Euler interval endpoints must be finite and increasing")
            mass = input.spatial_case.time_mass
            mass === nothing && return _dcce_phase(:terminal_deferred,
                :time_capacity_typed_absent;
                detail="transient execution requires an explicit closed capacity tied to this G1 source")
            capacity = input.g1.source_payload.transient_capacity
            capacity isa G1DiffusionTransientCapacityV1 ||
                return _dcce_phase(:terminal_deferred, :time_capacity_source_absent;
                    detail="this G1 source authors no transient volumetric capacity")
            input.spatial_case.time_unit === :second ||
                return _dcce_phase(:terminal_deferred, :time_unit_absent;
                    detail="the SI thermal diffusion lane requires the second time unit")
            capacity.source_ref == input.g1.source_ref ||
                return _dcce_phase(:fail_closed, :time_capacity_source_mismatch;
                    detail="G1 transient capacity source identity differs from the G1 declaration")
            mass.source_ref == input.g1.source_ref && mass.closed && capacity.closed ||
                return _dcce_phase(:fail_closed, :time_capacity_source_mismatch;
                    detail="case capacity must be closed and bound to the authored G1 source")
            mass.coefficient == capacity.coefficient && mass.units == capacity.units ||
                return _dcce_phase(:fail_closed, :time_capacity_source_mismatch;
                    detail="case capacity coefficient and units must exactly match the authored G1 capacity")
            isdefined(@__MODULE__, :UnitSignature) && mass.units isa UnitSignature &&
                mass.units == capacity.units &&
                isfinite(mass.coefficient) && mass.coefficient > 0.0 &&
                capacity.units == UnitSignature((-1, 1, -2, 0, -1, 0, 0)) &&
                up.units == UnitSignature((0, 0, 0, 0, 1, 0, 0)) &&
                kp.units == UnitSignature((1, 1, -3, 0, -1, 0, 0)) &&
                fp.units == UnitSignature((-1, 1, -3, 0, 0, 0, 0)) ||
                return _dcce_phase(:terminal_deferred, :unsupported_time_mass_units;
                    detail="only a G1-authored SI volumetric capacity that closes rhoCp*du/dt with div(K*grad(u))=f is admitted")
        end
        temporal = interval === nothing ? :static : :transient
        ktuple = Tuple(Float64.(field.k_cells)); ftuple = Tuple(Float64.(field.source))
        all(isfinite, ktuple) && all(>(0.0), ktuple) && all(isfinite, ftuple) ||
            return _dcce_phase(:numerical_fail, :nonfinite_derived;
                detail="lowered K/source is nonfinite or nonpositive")
        source_program_hash = nothing
        if typed_program_input !== nothing
            capability = _dgd_g1_typed_source_capability_v1(typed_program_input)
            if authored_program_spec !== nothing &&
                !_dcce_g1_authored_roots_x_only_v1(capability)
                return _dcce_phase(:terminal_deferred,
                    :typed_unsupported_transverse_source_program;
                    detail="the existing one-dimensional FV consumer admits candidate-authored roots only when their typed AST depends on the G2 x chart coordinate")
            end
            chart = input.g2.source.chart_map
            diagonal_chart = chart.map_kind === :affine &&
                all(iszero(chart.jacobian_rows[i][j]) for i in 1:3 for j in 1:3 if i != j) &&
                all(chart.jacobian_rows[i][i] > 0 for i in 1:3)
            diagonal_chart || return _dcce_phase(:terminal_deferred,
                :unsupported_g1_source_chart;
                detail="the admitted G1 source capability requires a positive diagonal affine chart")
            edges = input.spatial_case.new_geometry.edges
            length(edges) == n + 1 ||
                return _dcce_phase(:fail_closed, :g1_spatial_domain_mismatch;
                    detail="FV edge count differs from the admitted source field cell count")
            x_min_faces = Tuple(face for face in input.g2.source.faces if face.face === :x_min)
            x_max_faces = Tuple(face for face in input.g2.source.faces if face.face === :x_max)
            length(x_min_faces) == 1 && length(x_max_faces) == 1 ||
                return _dcce_phase(:fail_closed, :g1_boundary_face_mismatch;
                    detail="the admitted G2 source must contain unique x_min and x_max faces")
            if authored_program_spec !== nothing
                expected_flux_units = _g1d_sub(
                    _g1d_add(input.g1.K.physical_type.units,
                        input.g1.u.physical_type.units), _g1d_length_unit())
                input.g1.u.physical_type.units == input.g2.source.units.field_value &&
                    input.g2.source.units.flux_value == expected_flux_units ||
                    return _dcce_phase(:fail_closed, :g1_g2_unit_mismatch;
                        detail="candidate-authored G1 u units must match G2 field_value units and G2 flux_value units must match the G1 K*u/length conormal units")
                source_faces = Tuple(input.g2.source.faces)
                expected_faces = (:x_min, :x_max, :y_min, :y_max, :z_min, :z_max)
                length(source_faces) == 6 &&
                    Set(face.face for face in source_faces) == Set(expected_faces) &&
                    length(unique(face.face_id for face in source_faces)) == 6 ||
                    return _dcce_phase(:terminal_deferred,
                        :unsupported_g1_transverse_boundary_profile;
                        detail="the one-dimensional authored-source lane requires six uniquely identified G2 faces")
                all(face.face in (:x_min, :x_max) ?
                    (face.value.kind === :dirichlet &&
                     face.value.unit == input.g2.source.units.field_value) :
                    (face.value.kind === :neumann && iszero(face.value.value) &&
                     face.value.unit == input.g2.source.units.flux_value)
                    for face in source_faces) ||
                    return _dcce_phase(:terminal_deferred,
                        :unsupported_g1_transverse_boundary_profile;
                        detail="the one-dimensional authored-source lane requires field-unit x Dirichlet faces and zero Neumann transverse faces in the actual G2 flux units")
            end
            x_min_face, x_max_face = only(x_min_faces), only(x_max_faces)
            physical_x_min = Float64(chart.offset[1] +
                chart.jacobian_rows[1][1] * chart.domain_lower[1])
            physical_x_max = Float64(chart.offset[1] +
                chart.jacobian_rows[1][1] * chart.domain_upper[1])
            (first(edges) == physical_x_min && last(edges) == physical_x_max) ||
                return _dcce_phase(:fail_closed, :g1_spatial_domain_mismatch;
                    detail="FV geometry endpoints differ from the admitted G2 x domain")
            fv_boundary = input.spatial_case.boundary
            (fv_boundary.left_kind === :dirichlet &&
             fv_boundary.left_value == Float64(x_min_face.value.value) &&
             fv_boundary.right_kind === :dirichlet &&
             fv_boundary.right_value == Float64(x_max_face.value.value)) ||
                return _dcce_phase(:fail_closed, :g1_boundary_mismatch;
                    detail="FV x Dirichlet conditions differ from the admitted G2 x faces")
            if authored_program_spec !== nothing
                y_ref = (Float64(chart.domain_lower[2]) +
                    Float64(chart.domain_upper[2])) / 2.0
                z_ref = (Float64(chart.domain_lower[3]) +
                    Float64(chart.domain_upper[3])) / 2.0
                endpoint_points = ((Float64(chart.domain_lower[1]), y_ref, z_ref),
                    (Float64(chart.domain_upper[1]), y_ref, z_ref))
                evaluated_u = _dgd_evaluate_g1_typed_source_v1(
                    typed_program_input, :u, endpoint_points)
                expected_u = (Float64(x_min_face.value.value),
                    Float64(x_max_face.value.value))
                evaluated_u !== nothing && evaluated_u == expected_u ||
                    return _dcce_phase(:fail_closed, :g1_u_boundary_source_mismatch;
                        detail="candidate-authored u root endpoints differ from actual G2 Dirichlet faces")
            end
            x_centers = Tuple((Float64(edges[i]) + Float64(edges[i + 1])) / 2.0
                for i in 1:(length(edges) - 1))
            y_ref = (Float64(chart.domain_lower[2]) + Float64(chart.domain_upper[2])) / 2.0
            z_ref = (Float64(chart.domain_lower[3]) + Float64(chart.domain_upper[3])) / 2.0
            ref_points = Tuple(begin
                ref_x = (x - Float64(chart.offset[1])) /
                    Float64(chart.jacobian_rows[1][1])
                (ref_x, y_ref, z_ref)
            end for x in x_centers)
            all(point -> all(chart.domain_lower[i] <= point[i] <= chart.domain_upper[i]
                    for i in 1:3), ref_points) ||
                return _dcce_phase(:terminal_deferred, :spatial_points_outside_g1_source_domain;
                    detail="FV cell centers are outside the admitted G1 source chart")
            chart_points = Tuple(ntuple(i -> Float64(point[i]), 3) for point in ref_points)
            evaluated_source = _dgd_evaluate_g1_typed_source_v1(typed_program_input,
                :f, chart_points)
            evaluated_source !== nothing && evaluated_source == ftuple ||
                return _dcce_phase(:fail_closed, :g1_source_field_mismatch;
                    detail="FV source values differ from the admitted G1 typed source program")
            physical_points = Tuple(ntuple(row -> Float64(chart.offset[row]) +
                sum(Float64(chart.jacobian_rows[row][col]) * point[col]
                    for col in 1:3), 3) for point in ref_points)
            evaluated_k = Tuple(Float64(g1_diffusion_k_eval(k, point)[1][1])
                for point in physical_points)
            evaluated_k == ktuple ||
                return _dcce_phase(:fail_closed, :g1_coefficient_field_mismatch;
                    detail="FV K values differ from the admitted G1 coefficient declaration")
            source_program_hash = capability.capability_hash
        end
        expression_subset = component_count == 1 ?
            (interval === nothing ? DCCE_EXPRESSION_SUBSET_V1 :
                :diagonal_affine_backward_euler) :
            (interval === nothing ? :diagonal_affine_multifield :
                :diagonal_affine_multifield_backward_euler)
        coefficient_kind = component_count == 1 ? :diagonal : :diagonal_with_declared_exchange
        lowered_k = component_count == 1 ? ktuple : Tuple(Tuple(f.k_cells) for f in component_fields)
        lowered_source = component_count == 1 ? ftuple : Tuple(Tuple(f.source) for f in component_fields)
        lowered_boundary = component_count == 1 ? semantic_view(boundary) :
            Tuple(semantic_view(b) for b in component_boundaries)
        # Preserve the historical steady scalar receipt exactly. New temporal
        # and component metadata is included only for cases that use it.
        body = (candidate=input.candidate_ref, expression_subset=expression_subset,
            dimension=1, field_count=component_count, temporal=temporal,
            coefficient_kind=coefficient_kind, k_cells=lowered_k,
            source=lowered_source, boundary=lowered_boundary,
            g1_body_hash=input.hashes.g1_body_hash,
            g2_body_hash=input.hashes.g2_body_hash,
            g3_body_hash=input.hashes.g3_body_hash,
            bundle_hash=input.hashes.bundle_hash)
        couplings = Tuple((c.left_component,c.right_component,c.coefficient,c.units,
            c.source_ref,c.closed) for c in input.spatial_case.couplings)
        if interval !== nothing || transient_capacity !== nothing || component_count > 1
            body = merge(body, (time_interval=interval,
                time_unit=interval === nothing ? nothing : input.spatial_case.time_unit,
                transient_capacity=transient_capacity, couplings=couplings))
        end
        lowering_body = source_program_hash === nothing ? body :
            merge(body, (source_program_hash=source_program_hash,))
        DCCETypedLoweringV1(:ready, :typed_lowering_ready, input.candidate_ref,
            expression_subset, 1, component_count, temporal, coefficient_kind,
            interval, interval === nothing ? nothing : input.spatial_case.time_unit,
            transient_capacity, lowered_k, lowered_source, lowered_boundary, couplings,
            _dcce_hash((g1=input.hashes.g1_body_hash,
                g2=input.hashes.g2_body_hash, g3=input.hashes.g3_body_hash)),
            _dcce_hash(lowering_body))
    catch err
        _dcce_phase(:fail_closed, :program_exception; detail=sprint(showerror, err))
    end
end

"Build the existing typed port plan.  Component/port labels are diagnostic;
the upstream matcher hashes only semantic direction/account/quantity/unit and
sorts its edge payloads."
function dcce_composition_plan_v1(input::DeclaredDiffusionCompileExecuteInputV1)
    try
        # The existing matcher is deliberately authoritative for all of these
        # negative gates: duplicate_producer/ambiguous producers, unit mismatch,
        # missing_boundary, missing_return, and ledger_contradiction.
        matched = auto_typed_port_edges(input.spatial_case.composition)
        matched.valid || return _dcce_phase(matched.status, matched.code; detail=matched.detail)
        edges = Tuple(matched.edges)
        semantic_edges = Tuple(sort([(_dsc_port_key(e.producer), _dsc_port_key(e.consumer))
            for e in edges], by=repr))
        plan_hash = _dcce_hash(semantic_edges)
        plan = DCCECompositionPlanV1(:ready, :typed_composition_plan_ready,
            input.candidate_ref, input.spatial_case.composition, edges, plan_hash,
            _dcce_hash((candidate=input.candidate_ref, plan_hash=plan_hash)))
        (status=:ready, code=:typed_composition_plan_ready, valid=true,
            plan=plan, edges=edges, semantic_hash=plan_hash,
            ledger_residual=matched.residual, receipt_hash=plan.receipt_hash,
            provider_calls=0, mesh_calls=0, solver_calls=0)
    catch err
        _dcce_phase(:fail_closed, :composition_plan_exception; detail=sprint(showerror, err))
    end
end

function _dcce_execute_input(input::DeclaredDiffusionCompileExecuteInputV1;
        cross_mesh_transfer_binding=nothing)
    compile = dgd_compile_v1(DeclaredG123InputV1(input.candidate_ref, input.g1,
        input.g2, input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash)))
    compile.status === :ready || return _dcce_failure(input.candidate_ref,
        compile.code; status=compile.status, hashes=input.hashes, compile=compile)
    lowering = dcce_typed_lower_v1(input)
    lowering.status === :ready || return _dcce_failure(input.candidate_ref,
        lowering.code; status=lowering.status, hashes=input.hashes,
        compile=compile, lowering=lowering)
    plan = dcce_composition_plan_v1(input)
    plan.status === :ready || return _dcce_failure(input.candidate_ref,
        plan.code; status=plan.status, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=plan)
    authority = dgd_composition_admit_v1(DeclaredG123InputV1(input.candidate_ref,
        input.g1, input.g2, input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash)))
    authority.status === :fail_closed && return _dcce_failure(input.candidate_ref,
        authority.code; status=:fail_closed, hashes=input.hashes, compile=compile,
        lowering=lowering, composition=merge(plan, (authority=authority,)))
    warm_start, warm_start_code = _dcce_cross_mesh_initial_state(input,
        cross_mesh_transfer_binding)
    warm_start_code === :ready || return _dcce_failure(input.candidate_ref,
        warm_start_code; status=:fail_closed, hashes=input.hashes, compile=compile,
        lowering=lowering, composition=merge(plan, (authority=authority,
            cross_mesh_transfer_binding=cross_mesh_transfer_binding)))
    component_count = length(input.spatial_case.component_fields)
    component_count > 1 && cross_mesh_transfer_binding !== nothing &&
        return _dcce_failure(input.candidate_ref, :multifield_cross_mesh_transfer_untyped;
            status=:terminal_deferred, hashes=input.hashes, compile=compile,
            lowering=lowering, composition=merge(plan, (authority=authority,
                cross_mesh_transfer_binding=cross_mesh_transfer_binding)))
    # Keep the submitted G123 2-DOF numerical lane separate from the spatial
    # composition lane.  Their matrices have different discretization
    # identities and must never be placed in one receipt or compared as if
    # they were the same numerical system.
    dgd_input = DeclaredG123InputV1(input.candidate_ref, input.g1, input.g2,
        input.g3, input.bundle,
        DeclaredG123HashSetV1(input.candidate_ref, input.hashes.g1_body_hash,
            input.hashes.g2_body_hash, input.hashes.g3_body_hash,
            input.hashes.bundle_hash))
    dgd_mesh = dgd_local_mesh_v1(dgd_input)
    typed_dgd_mesh_deferred =
        (input.g1.u.source_expression == DGD_G1_TYPED_SOURCE_MARKER_V1 ||
         _dgd_current_source_g1_typed_spec_v1(input.g1) !== nothing) &&
        length(dgd_mesh.reference_nodes) != 2
    if typed_dgd_mesh_deferred
        dgd_transfer = (status=:not_executed, resolution=:terminal_deferred,
            code=:unsupported_typed_source_mesh, source_mesh_hash=dgd_mesh.mesh_hash,
            target_mesh_hash=dgd_mesh.mesh_hash, old_state=nothing, new_state=nothing,
            overlap=nothing, weights=nothing, conservation_residual=nothing,
            solver_calls=0,
            receipt_hash=_dcce_hash((status=:not_executed,
                code=:unsupported_typed_source_mesh, mesh_hash=dgd_mesh.mesh_hash,
                reference_node_count=length(dgd_mesh.reference_nodes))))
        dgd_numerical = (status=:terminal_deferred,
            code=:unsupported_typed_source_mesh, solver_calls=0,
            receipt_hash=_dcce_hash((status=:terminal_deferred,
                code=:unsupported_typed_source_mesh, mesh_hash=dgd_mesh.mesh_hash,
                transfer=dgd_transfer.receipt_hash)))
    else
        dgd_transfer = dgd_transfer_v1(dgd_mesh, dgd_mesh, input.spatial_case.old_state)
        dgd_transfer.status === :ready || return _dcce_failure(input.candidate_ref,
            dgd_transfer.code; status=dgd_transfer.status, hashes=input.hashes,
            compile=compile, lowering=lowering, composition=merge(plan,
                (authority=authority, dgd_transfer=dgd_transfer)))
        dgd_numerical = dgd_numerical_solve_v1(dgd_input, dgd_mesh, dgd_transfer)
        dgd_numerical.status === :ready || return _dcce_failure(input.candidate_ref,
            dgd_numerical.code; status=:numerical_fail, hashes=input.hashes,
            compile=compile, lowering=lowering, composition=merge(plan,
                (authority=authority, dgd_transfer=dgd_transfer)),
            numerical=_dcce_phase(:numerical_fail, dgd_numerical.code;
                dgd=dgd_numerical))
    end
    component_transfers = component_count == 1 ? nothing :
        Tuple(measure_overlap_transfer(input.spatial_case.old_geometry,
            input.spatial_case.new_geometry, state)
            for state in input.spatial_case.component_old_states)
    transfer = if component_count == 1
        measure_overlap_transfer(input.spatial_case.old_geometry,
            input.spatial_case.new_geometry, input.spatial_case.old_state)
    else
        first_transfer = first(component_transfers)
        bad_index = findfirst(t -> !t.valid, component_transfers)
        selected = bad_index === nothing ? first_transfer : component_transfers[bad_index]
        (valid=bad_index === nothing, status=selected.status, code=selected.code,
            detail="component histories are independently transferred",
            residual=sum(t.residual for t in component_transfers),
            transfer=first_transfer.transfer,
            component_transfers=Tuple(t.transfer for t in component_transfers))
    end
    transfer.valid || return _dcce_failure(input.candidate_ref, transfer.code;
        status=transfer.status, hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer)))
    assembled = component_count == 1 ?
        assemble_declared_spatial_fv(input.spatial_case.new_geometry,
            input.spatial_case.field, input.spatial_case.boundary; edges=plan.edges) :
        assemble_declared_spatial_multifield_fv(input.spatial_case.new_geometry,
            input.spatial_case.component_fields, input.spatial_case.component_boundaries,
            input.spatial_case.couplings; edges=plan.edges)
    assembled.valid || return _dcce_failure(input.candidate_ref, assembled.code;
        status=assembled.status, hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer,
            assembly=assembled)))
    time_step = nothing
    fv_matrix = assembled.assembly.matrix
    fv_rhs = assembled.assembly.rhs
    if input.spatial_case.time_interval !== nothing
        field_edge = only(filter(e -> e.account == "field", plan.edges))
        time_system = component_count == 1 ?
            declared_spatial_backward_euler_system(input.spatial_case,
                transfer.transfer, assembled.assembly;
                coupling_gain=field_edge.producer.magnitude,
                expected_source_ref=input.g1.source_ref,
                expected_capacity=input.g1.source_payload.transient_capacity) :
            declared_spatial_multifield_backward_euler_system(input.spatial_case,
                component_transfers, assembled.assembly;
                coupling_gain=field_edge.producer.magnitude,
                expected_source_ref=input.g1.source_ref,
                expected_capacity=input.g1.source_payload.transient_capacity)
        time_system.valid || return _dcce_failure(input.candidate_ref,
            time_system.code; status=time_system.status, hashes=input.hashes,
            compile=compile, lowering=lowering, composition=merge(plan,
                (authority=authority, transfer=transfer, assembly=assembled,
                 time_system=time_system)))
        time_step = time_system.system
        fv_matrix = time_step.matrix
        fv_rhs = time_step.rhs
    end
    all_neumann = all(b -> b.left_kind === :neumann && b.right_kind === :neumann,
        input.spatial_case.component_boundaries)
    all_neumann &&
        return _dcce_failure(input.candidate_ref, :pure_neumann_singular;
            status=:numerical_fail, hashes=input.hashes, compile=compile,
            lowering=lowering, composition=merge(plan, (authority=authority,
                transfer=transfer, assembly=assembled)))
    solution, residual, solve_code, solve_work =
        _dcce_solve_with_one_refinement(fv_matrix, fv_rhs; initial_state=warm_start,
            relative_residual_tolerance=time_step === nothing ? nothing : 1.0e-12)
    solve_code === :singular_matrix && return _dcce_failure(input.candidate_ref,
        :singular_matrix; status=:numerical_fail, hashes=input.hashes,
        compile=compile, lowering=lowering, composition=merge(plan, (authority=authority,
            transfer=transfer, assembly=assembled)),
        numerical=_dcce_phase(:numerical_fail, :singular_matrix;
            residual_norm=residual, solver_calls=solve_work.solver_calls,
            linear_work=solve_work), solver_calls=dgd_numerical.solver_calls + solve_work.solver_calls)
    solve_code === :joint_linear_solved || return _dcce_failure(input.candidate_ref,
        solve_code; status=:numerical_fail, hashes=input.hashes, compile=compile,
        lowering=lowering, composition=merge(plan, (authority=authority,
            transfer=transfer, assembly=assembled)),
        numerical=_dcce_phase(:numerical_fail, solve_code; residual_norm=residual,
            solver_calls=solve_work.solver_calls, linear_work=solve_work),
        solver_calls=dgd_numerical.solver_calls + solve_work.solver_calls)
    isfinite(solve_work.final_residual_measure) &&
        solve_work.final_residual_measure <= 1.0e-12 || return _dcce_failure(
        input.candidate_ref, :residual_failure; status=:numerical_fail,
        hashes=input.hashes, compile=compile, lowering=lowering,
        composition=merge(plan, (authority=authority, transfer=transfer,
            assembly=assembled)), numerical=_dcce_phase(:numerical_fail,
            :residual_failure; residual_norm=residual,
            residual_measure=solve_work.final_residual_measure,
            residual_measure_kind=solve_work.residual_measure_kind,
            solver_calls=solve_work.solver_calls,
            fv=(status=:numerical_fail, code=:residual_failure,
                residual_norm=residual, residual_measure=solve_work.final_residual_measure,
                residual_measure_kind=solve_work.residual_measure_kind,
                solver_calls=solve_work.solver_calls,
                assembly_hash=assembled.assembly.assembly_hash,
                linear_work=solve_work), linear_work=solve_work),
        solver_calls=dgd_numerical.solver_calls + solve_work.solver_calls)
    warm_start_payload = cross_mesh_transfer_binding === nothing ? (;) :
        (initial_state=Tuple(warm_start),
         cross_mesh_transfer_receipt_hash=cross_mesh_transfer_binding.receipt.receipt_hash,
         cross_mesh_account_binding_hash=_dcce_hash((
            source=cross_mesh_transfer_binding.accounts.source,
            target=cross_mesh_transfer_binding.accounts.target,
            external=cross_mesh_transfer_binding.accounts.external,
            return_account=cross_mesh_transfer_binding.accounts.return_account)),
         warm_start_initial_residual_norm=solve_work.initial_residual_norm)
    fv_receipt_payload = merge((matrix=Tuple(Tuple(row) for row in eachrow(fv_matrix)),
        rhs=Tuple(fv_rhs), solution=Tuple(solution),
        residual_norm=residual, residual_measure=solve_work.final_residual_measure,
        residual_measure_kind=solve_work.residual_measure_kind,
        assembly_hash=assembled.assembly.assembly_hash,
        time_step=time_step === nothing ? nothing :
            (interval=time_step.interval, dt=time_step.dt, mass=time_step.mass,
             history=time_step.history, time_assembly_hash=time_step.assembly_hash)),
        warm_start_payload)
    fv_numerical = merge(fv_receipt_payload,
        (status=:ready, code=:finite_volume_solved,
         solver_calls=solve_work.solver_calls,
         factorization_count=solve_work.factorization_count,
         lu_rhs_solve_count=solve_work.lu_rhs_solve_count,
         refinement_solve_count=solve_work.refinement_solve_count,
         initial_residual_norm=solve_work.initial_residual_norm))
    numerical = if typed_dgd_mesh_deferred
        _dcce_phase(:terminal_deferred, :dgd_2dof_mesh_not_executed;
            accepted=false, dgd=dgd_numerical, dgd_transfer=dgd_transfer,
            fv=fv_numerical, solver_calls=solve_work.solver_calls,
            linear_work=solve_work,
            receipt_hash=_dcce_hash((dgd=dgd_numerical.receipt_hash,
                dgd_transfer=dgd_transfer.receipt_hash, fv=fv_receipt_payload)))
    else
        _dcce_phase(:ready, :finite_volume_solved; accepted=false,
            # `dgd` is the submitted 2x2 lane; `fv` is the independent spatial
            # composition holdout. Both receipts remain separate.
            dgd=dgd_numerical, dgd_transfer=dgd_transfer,
            matrix=dgd_numerical.matrix, rhs=dgd_numerical.rhs,
            solution=dgd_numerical.solution,
            residual_norm=dgd_numerical.residual_norm,
            fv=fv_numerical, solver_calls=solve_work.solver_calls,
            linear_work=solve_work,
            receipt_hash=_dcce_hash((dgd=dgd_numerical.receipt_hash,
                fv_assembly=assembled.assembly.assembly_hash,
                fv_solution=Tuple(solution), fv_residual_norm=residual)))
    end
    composition_status = authority.status === :ready && authority.resolution === :resolved ?
        :ready : :terminal_deferred
    composition = merge(plan, (status=composition_status, authority=authority,
        transfer=transfer, assembly=assembled, accepted=false,
        claim_ceiling=DCCE_CLAIM_CEILING_V1,
        receipt_hash=_dcce_hash((plan=plan.receipt_hash,
            authority=canonical_json(authority), assembly=assembled.assembly.assembly_hash))))
    aggregate_status = composition_status === :ready && !typed_dgd_mesh_deferred ?
        :ready : :terminal_deferred
    aggregate_code = aggregate_status === :ready ? :screen_ready_authority_deferred :
        (composition_status === :ready && typed_dgd_mesh_deferred ?
            :dgd_2dof_mesh_not_executed : authority.code)
    aggregate = _dcce_phase(aggregate_status, aggregate_code; resolution=aggregate_status,
        accepted=false, formal_up_credit=false, formal_r_credit=false,
        screen_only=true, provider_calls=0, mesh_calls=0,
        solver_calls=dgd_numerical.solver_calls + solve_work.solver_calls,
        dgd_solver_calls=dgd_numerical.solver_calls,
        fv_solver_calls=solve_work.solver_calls,
        candidate_ref=input.candidate_ref, hashes=input.hashes,
        residual_norm=residual, solution=Tuple(solution))
    body = (candidate=input.candidate_ref, hashes=input.hashes.receipt_hash,
        compile=compile.receipt_hash, lowering=lowering.receipt_hash,
        composition=composition.receipt_hash, numerical=numerical.receipt_hash,
        aggregate=aggregate)
    DCCEOutcomeV1(aggregate_status, aggregate.code, false, DCCE_CLAIM_CEILING_V1,
        compile, lowering, composition, numerical, aggregate, input.hashes,
        _dcce_hash(body))
end

"Public boundary: strict identity errors become a typed fail-closed outcome."
function dcce_compile_execute_v1(candidate, g1, g2, g3, bundle, spatial_case;
        cross_mesh_transfer_binding=nothing)
    try
        input = dcce_input_v1(candidate, g1, g2, g3, bundle, spatial_case)
        _dcce_execute_input(input; cross_mesh_transfer_binding=cross_mesh_transfer_binding)
    catch err
        msg = lowercase(sprint(showerror, err))
        code = occursin("candidate", msg) ? :candidate_mismatch :
            occursin("bundle_hash", msg) ? :bundle_hash_mismatch :
            occursin("body", msg) || occursin("semantic", msg) ?
                :body_hash_mismatch : occursin("source", msg) ?
                :source_hash_mismatch : occursin("declaration", msg) ?
                :declaration_hash_mismatch : :hash_or_declaration_mismatch
        _dcce_failure(_dcce_public_candidate(candidate), code;
            status=:fail_closed, detail=sprint(showerror, err))
    end
end

const declared_diffusion_compile_execute_v1 = dcce_compile_execute_v1
const execute_declared_diffusion_compile_execute_v1 = dcce_compile_execute_v1
