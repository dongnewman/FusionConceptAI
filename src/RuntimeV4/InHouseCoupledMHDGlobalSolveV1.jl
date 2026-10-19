if !isdefined(@__MODULE__, :MultiTopologyNonlinearSolveV1)
    include(joinpath(@__DIR__, "MultiTopologyNonlinearSolveV1.jl"))
end

"""Candidate-bound multi-region ideal-MHD global solve scaffold.

This file is intentionally isolated from the shared RuntimeV4 loader. It
assembles regional equilibrium equations, exact interface/outer constraints,
and a constrained nonlinear step, but grants no physical or engineering
authority. Pressure/current topology and outer B/K/return-current evidence
must be supplied and source-bound by a future formal consumer.
"""

module InHouseCoupledMHDGlobalSolveV1

using LinearAlgebra
using SparseArrays
using SHA
using Serialization
using FusionConceptAI: canonical_hash, canonical_json
using ..MultiTopologyNonlinearSolveV1: accepted_step_v1, verify_source_v1

export CoupledMHDClosureEvidenceV1,
       CoupledMHDGlobalPolicyV1,
       CoupledMHDGlobalModelV1,
       make_closure_evidence_v1,
       make_global_policy_v1,
       make_global_model_v1,
       coupled_mhd_provider_context_hash_v1,
       coupled_mhd_capability_signature_v1,
       assemble_coupled_mhd_global_v1,
       solve_coupled_mhd_global_v1,
       replay_coupled_mhd_global_v1,
       candidate_kkt_scale_contract_v1,
       weighted_residual_kkt_partition_v1,
       weighted_residual_kkt_step_identity_v1,
       solve_weighted_residual_kkt_step_v1,
       coupled_mhd_global_manifest_v1

const _REVISION = "inhouse-coupled-mhd-global-solve-v1"
const _KKT_GMRES_RESTART_CAP = 100
const _REQUIRED_CLOSURES = (
    :pressure_topology,
    :current_topology,
    :B_out,
    :K_outer,
    :return_current_path,
)
const _SOURCE_PATH = abspath(@__FILE__)
const _CLOSURE_TOKEN = Val(:inhouse_coupled_mhd_closure_private_v1)
const _POLICY_TOKEN = Val(:inhouse_coupled_mhd_policy_private_v1)
const _MODEL_TOKEN = Val(:inhouse_coupled_mhd_model_private_v1)

_sha_bytes(bytes) = bytes2hex(SHA.sha256(bytes))
_sha_file(path) = bytes2hex(SHA.sha256(read(path)))
_semantic_sha(value) = bytes2hex(SHA.sha256(codeunits(canonical_json(value))))
_solver_semantic_hash() = _semantic_sha((revision=_REVISION,
    algorithm=:active_set_equality_KKT_weighted_least_squares,
    public_weighted_step_linear_solver=:bounded_matrix_free_restarted_gmres,
    public_weighted_step_restart_cap=_KKT_GMRES_RESTART_CAP,
    public_weighted_step_restart_rule=:min_cap_and_actual_kkt_order,
    public_weighted_step_max_iterations=1000,
    public_weighted_step_stagnation_cycles=5,
    public_weighted_step_row_column_scaling=:symmetric_l1_diagonal_equilibration,
    public_weighted_step_preconditioner=:right_hdiag_constraint_saddle_inverse,
    public_weighted_step_preconditioner_includes_active_bound_rows=true,
    public_weighted_step_preconditioner_no_jitter_or_diagonal_floor=true,
    public_weighted_step_preconditioner_schur_dimension_cap=1024,
    public_weighted_step_true_residual=:right_preconditioned_unleft_row_space_residual,
    public_weighted_step_working_set_preflight=:sparse_gmres_and_diag_schur_workspace,
    public_weighted_step_default_memory_cap_bytes=3*1024^3,
    formal_global_linear_solver=:bounded_matrix_free_restarted_gmres,
    formal_global_gmres_restart_cap=_KKT_GMRES_RESTART_CAP,
    formal_global_gmres_restart_rule=:min_cap_and_actual_kkt_order,
    formal_global_gmres_max_iterations=1000,
    formal_global_gmres_stagnation_cycles=5,
    formal_global_working_memory_cap_bytes=3*1024^3,
    formal_global_equilibration=:symmetric_diagonal_l1_row_norm,
    formal_global_preconditioner=:right_hdiag_constraint_saddle_inverse,
    formal_global_preconditioner_includes_active_bound_rows=true,
    formal_global_preconditioner_no_jitter_or_diagonal_floor=true,
    formal_global_preconditioner_schur_dimension_cap=1024,
    formal_global_original_kkt_residual_audit=true,
    formal_global_rank_certificate=:not_established_by_krylov_residual,
    formal_global_scaled_row_convergence_gate=:also_require_raw_policy_tolerance,
    public_weighted_step_rank_policy=:no_rank_certificate_require_original_KKT_residual,
    public_active_bound_equation=:column_scale_times_step_plus_state,
    public_active_bound_multiplier_stationarity=:column_scale_times_bound_multiplier,
    legacy_private_qr_helper_semantics=true,
    kkt_equilibration=:bounded_symmetric_diagonal_row_l1_ruiz,
    kkt_equilibration_max_passes=_KKT_RUIZ_MAX_PASSES,
    kkt_equilibration_target_row_norm_ratio=_KKT_RUIZ_TARGET_ROW_NORM_RATIO,
    rank_reveal_fallback=:bound_only_sparse_minimum_norm_else_bounded_constraint_nullspace_qr,
    rank_reveal_operand=:free_coordinate_design_or_constraint_nullspace_JZ,
    bound_only_rank_threshold=:eps_times_design_order_times_max_column_norm_floor_one,
    bound_only_inconsistent_rank_reveal=:untruncated_R_SVD_same_threshold_within_existing_32MiB_reserve,
    rank_reveal_fallback_max_order=_KKT_RANK_FALLBACK_MAX_ORDER,
    rank_threshold=:eps_times_order_times_maximum_r_diagonal_floor_one,
    nonfinite_rank_inputs=:explicit_numerical_failure,
    active_set_initialization=:strict_zero_pressure_coordinates,
    active_bound_coordinate_recovery=:exact_rhs_assignment))
_valid_sha(s) = s isa AbstractString && occursin(r"^[0-9a-f]{64}$", s)
_finite_vector(x) = x isa AbstractVector{<:Real} && all(isfinite, x)
_maxabs(x) = maximum(abs, x; init=0.0)

"""Freeze candidate-derived row characteristics used only for numerical scaling.

The contract covers every least-squares and exact-equality row by ordered ID,
unit, and positive characteristic. Dividing exact rows by a positive scale
preserves their zero set. Characteristics are numerical preconditioners, not
calibrated tolerances, a physical merit, or evidence that an equilibrium holds.
"""
function candidate_kkt_scale_contract_v1(;candidate_hash, source_hashes,
        equilibrium_row_ids, equilibrium_row_units, equilibrium_characteristics,
        equality_row_ids, equality_row_units, equality_characteristics,
        provenance)
    _valid_sha(candidate_hash) || throw(ArgumentError("scale contract candidate hash must be SHA-256"))
    source_hashes isa NamedTuple && !isempty(source_hashes) &&
        all(value -> _valid_sha(value), values(source_hashes)) ||
        throw(ArgumentError("scale contract source hashes must be a nonempty named tuple of SHA-256 values"))
    canonical_json(source_hashes)
    provenance isa NamedTuple || throw(ArgumentError("scale contract provenance must be a named tuple"))
    canonical_json(provenance)
    eqids=Tuple(String.(equilibrium_row_ids)); hardids=Tuple(String.(equality_row_ids))
    equnits=Tuple(String.(equilibrium_row_units)); hardunits=Tuple(String.(equality_row_units))
    eqchar_inputs=collect(equilibrium_characteristics)
    hardchar_inputs=collect(equality_characteristics)
    all(x->x isa Real && !(x isa Bool) && isfinite(x) && x>0,eqchar_inputs) &&
        all(x->x isa Real && !(x isa Bool) && isfinite(x) && x>0,hardchar_inputs) ||
        throw(ArgumentError("scale contract characteristics must be positive finite real values, excluding Bool"))
    eqchar_values=Float64.(eqchar_inputs); hardchar_values=Float64.(hardchar_inputs)
    eqchars=Tuple(eqchar_values); hardchars=Tuple(hardchar_values)
    !isempty(eqids) && length(eqids)==length(equnits)==length(eqchars) &&
        all(id->!isempty(strip(id)),eqids) && all(unit->!isempty(strip(unit)),equnits) &&
        length(unique(eqids))==length(eqids) ||
        throw(ArgumentError("equilibrium scale contract IDs, units, and characteristics must be complete and unique"))
    length(hardids)==length(hardunits)==length(hardchars) &&
        all(id->!isempty(strip(id)),hardids) && all(unit->!isempty(strip(unit)),hardunits) &&
        length(unique(hardids))==length(hardids) ||
        throw(ArgumentError("equality scale contract IDs, units, and characteristics must be complete and unique"))
    isempty(intersect(Set(eqids),Set(hardids))) ||
        throw(ArgumentError("equilibrium and equality scale-contract IDs must be disjoint"))
    all(x->isfinite(x)&&x>0.0&&isfinite(inv(x))&&inv(x)>0.0,eqchar_values) &&
        all(x->isfinite(x)&&x>0.0&&isfinite(inv(x))&&inv(x)>0.0,hardchar_values) ||
        throw(ArgumentError("scale contract characteristics and reciprocals must be finite and strictly positive"))
    body=(schema="candidate-kkt-scale-contract-v1",candidate_hash=String(candidate_hash),
        source_hashes,scale_policy=:candidate_characteristic_numerical_preconditioning,
        preserves_equilibrium_zero_set=true,preserves_exact_equality_zero_set=true,
        calibrated_physical_merit=false,physical_authority=false,
        equilibrium=(row_ids=eqids,row_units=equnits,characteristics=eqchars),
        equalities=(row_ids=hardids,row_units=hardunits,characteristics=hardchars),
        provenance)
    merge(body,(contract_hash=string(canonical_hash(body)),))
end

"""Partition weighted least-squares rows from exact KKT equalities.

This additive entry point is for real residual consumers whose boundary or
global-balance rows are part of a scaled least-squares objective. Those rows
must be supplied in `least_squares_*`; exact equalities may be multiplied by
positive `equality_row_scales`, which preserves their zero sets. The function
binds row order/scales to the candidate and consumer identity, retaining raw
residual/Jacobian values for audit.
"""
function weighted_residual_kkt_partition_v1(; candidate_hash,
        consumer_identity, least_squares_row_ids, least_squares_residual,
        least_squares_jacobian, least_squares_row_scales,
        equality_row_ids=(), equality_row_scales=nothing,equality_residual=Float64[],
        equality_jacobian=nothing)
    _valid_sha(candidate_hash) || throw(ArgumentError("partition candidate hash must be SHA-256"))
    consumer_identity isa NamedTuple && hasproperty(consumer_identity, :candidate_hash) &&
        String(consumer_identity.candidate_hash) == String(candidate_hash) ||
        throw(ArgumentError("partition consumer identity must bind the same candidate hash"))
    canonical_json(consumer_identity)
    ls_ids = Tuple(least_squares_row_ids)
    eq_ids = Tuple(equality_row_ids)
    all(id -> id isa AbstractString && !isempty(strip(id)), ls_ids) ||
        throw(ArgumentError("least-squares row identities must be nonempty strings"))
    all(id -> id isa AbstractString && !isempty(strip(id)), eq_ids) ||
        throw(ArgumentError("KKT equality row identities must be nonempty strings"))
    length(unique(ls_ids)) == length(ls_ids) && length(unique(eq_ids)) == length(eq_ids) &&
        isempty(intersect(Set(ls_ids), Set(eq_ids))) ||
        throw(ArgumentError("least-squares and KKT equality row identities must be unique and disjoint"))

    residual = Float64.(collect(least_squares_residual))
    residual isa Vector{Float64} && all(isfinite, residual) ||
        throw(ArgumentError("least-squares residual must be finite and rank one"))
    jacobian = sparse(Float64.(least_squares_jacobian))
    size(jacobian, 1) == length(residual) && size(jacobian, 2) > 0 &&
        length(ls_ids) == length(residual) ||
        throw(ArgumentError("least-squares row IDs/residual/Jacobian dimensions differ"))
    all(isfinite, nonzeros(jacobian)) || throw(ArgumentError("least-squares Jacobian is nonfinite"))

    (least_squares_row_scales isa Tuple || least_squares_row_scales isa AbstractVector) ||
        throw(ArgumentError("least-squares row scales must be an ordered tuple or vector"))
    all(scale -> scale isa Real && !(scale isa Bool), least_squares_row_scales) ||
        throw(ArgumentError("least-squares row scales must be real non-boolean values"))
    scales = Float64.(collect(least_squares_row_scales))
    length(scales) == length(residual) && all(scale -> isfinite(scale) && scale > 0.0, scales) &&
        all(scale -> isfinite(inv(scale)) && inv(scale) > 0.0, scales) ||
        throw(ArgumentError("least-squares scales must be finite, positive, representable, and row-complete"))

    hard_residual = Float64.(collect(equality_residual))
    all(isfinite, hard_residual) && length(eq_ids) == length(hard_residual) ||
        throw(ArgumentError("KKT equality row IDs/residual dimensions differ or are nonfinite"))
    hard_jacobian = equality_jacobian === nothing ?
        spzeros(Float64, length(hard_residual), size(jacobian, 2)) :
        sparse(Float64.(equality_jacobian))
    size(hard_jacobian) == (length(hard_residual), size(jacobian, 2)) &&
        all(isfinite, nonzeros(hard_jacobian)) ||
        throw(ArgumentError("KKT equality Jacobian dimensions or values are invalid"))

    hard_scales = equality_row_scales === nothing ? ones(Float64,length(hard_residual)) :
        Float64.(collect(equality_row_scales))
    length(hard_scales)==length(hard_residual) &&
        all(scale->isfinite(scale)&&scale>0.0&&isfinite(inv(scale))&&inv(scale)>0.0,hard_scales) ||
        throw(ArgumentError("KKT equality scales must be finite, positive, representable, and row-complete"))

    scaled_residual = residual ./ scales
    scaled_jacobian = spdiagm(0 => 1.0 ./ scales) * jacobian
    scaled_hard_residual=hard_residual ./ hard_scales
    scaled_hard_jacobian=spdiagm(0 => 1.0 ./ hard_scales) * hard_jacobian
    all(isfinite, scaled_residual) && all(isfinite, nonzeros(scaled_jacobian)) &&
        all(isfinite,scaled_hard_residual) && all(isfinite,nonzeros(scaled_hard_jacobian)) ||
        throw(ArgumentError("scaled least-squares rows are nonfinite"))
    scale_hash = string(canonical_hash(Tuple(scales)))
    hard_scale_hash=string(canonical_hash(Tuple(hard_scales)))
    row_identity_hash = string(canonical_hash((least_squares=ls_ids, equalities=eq_ids)))
    consumer_identity_hash = string(canonical_hash(consumer_identity))
    identity = (schema="weighted-residual-kkt-partition-v1", revision=_REVISION,
        solver_semantic_hash=_solver_semantic_hash(), candidate_hash=String(candidate_hash),
        consumer_identity_hash=consumer_identity_hash,
        least_squares_row_ids=ls_ids, equality_row_ids=eq_ids,
        least_squares_row_scale_hash=scale_hash,equality_row_scale_hash=hard_scale_hash,
        row_identity_hash=row_identity_hash)
    (identity=identity, partition_hash=string(canonical_hash(identity)),
        consumer_identity=consumer_identity, consumer_identity_hash=consumer_identity_hash,
        least_squares_row_ids=ls_ids, raw_least_squares_residual=residual,
        raw_least_squares_jacobian=jacobian, least_squares_row_scales=Tuple(scales),
        least_squares_row_scale_hash=scale_hash,
        scaled_least_squares_residual=scaled_residual,
        scaled_least_squares_jacobian=scaled_jacobian,
        equality_row_ids=eq_ids,equality_row_scales=Tuple(hard_scales),
        equality_row_scale_hash=hard_scale_hash,
        raw_equality_residual=hard_residual,raw_equality_jacobian=hard_jacobian,
        equality_residual=scaled_hard_residual,
        equality_jacobian=scaled_hard_jacobian,row_identity_hash=row_identity_hash,
        merit=0.5 * (dot(scaled_residual, scaled_residual) + dot(scaled_hard_residual, scaled_hard_residual)),
        gradient=transpose(scaled_jacobian) * scaled_residual +
            transpose(scaled_hard_jacobian) * scaled_hard_residual,
        physical_authority=false, emits_evidence=false,
        claim_ceiling=:numerical_mechanism_only)
end

const _EMPTY_CALLBACK_CAPTURE_HASH_V1 = bytes2hex(SHA.sha256(codeunits("[]")))

Base.@noinline Base.@nospecializeinfer function _callback_identity(callback)
    Base.@nospecialize callback
    trace_identity = get(ENV, "FUSION_G2_GLOBAL_ASSEMBLE_TIMING", "0") == "1"
    phase_started_ns = trace_identity ? time_ns() : UInt64(0)
    trace_identity && println("G2_CALLBACK_IDENTITY_BEGIN")
    trace_identity && flush(stdout)
    method_identities = NamedTuple[]
    methods_found = collect(methods(callback))
    isempty(methods_found) && throw(ArgumentError("callback method source is unresolved"))
    for method in methods_found
        location = try
            Base.functionloc(method)
        catch err
            throw(ArgumentError("callback method source is unresolved: $(sprint(showerror, err))"))
        end
        source_path = abspath(String(location[1]))
        push!(method_identities, (signature=string(method.sig), source_path=source_path,
            source_line=Int(location[2])))
    end
    if trace_identity
        println("G2_CALLBACK_IDENTITY_METHODS_END count=", length(method_identities),
            " elapsed_ns=", time_ns()-phase_started_ns)
        flush(stdout)
        phase_started_ns = time_ns()
    end
    capture_names = fieldnames(typeof(callback))
    capture_hash = if isempty(capture_names)
        # An empty capture tuple has canonical JSON `[]`. Reuse its digest
        # directly instead of serializing and forcing full collections for
        # callbacks that carry no captured state.
        _EMPTY_CALLBACK_CAPTURE_HASH_V1
    else
        capture_identities = Tuple((name=String(name), value=getfield(callback, name))
            for name in capture_names)
        try
        # Callback captures may serialize to very large canonical JSON. Reclaim
        # transient buffers left by the preceding callback before allocating it.
        GC.gc(true)
        capture_json = canonical_json(capture_identities)
        if trace_identity
            println("G2_CALLBACK_IDENTITY_CANONICAL_JSON_END bytes=", ncodeunits(capture_json),
                " elapsed_ns=", time_ns()-phase_started_ns)
            flush(stdout)
            phase_started_ns = time_ns()
        end
        # IOBuffer(String) reads the existing UTF-8 bytes without a full-size
        # copy. SHA still uses its Array update path through a bounded buffer.
        digest_sha_started_ns = time_ns()
        digest_raw = SHA.sha256(IOBuffer(capture_json), 1024*1024)
        trace_identity && println("G2_CALLBACK_IDENTITY_SHA_COMPUTE_END elapsed_ns=",
            time_ns()-digest_sha_started_ns, " chunk_bytes=", 1024*1024)
        trace_identity && flush(stdout)
        digest = bytes2hex(digest_raw)
        capture_json = nothing
        # Drop the just-consumed serialization before the next callback is checked.
        digest_gc_started_ns = time_ns()
        GC.gc(true)
        if trace_identity
            println("G2_CALLBACK_IDENTITY_POST_SHA_GC_END elapsed_ns=",
                time_ns()-digest_gc_started_ns)
            println("G2_CALLBACK_IDENTITY_SHA_END elapsed_ns=", time_ns()-phase_started_ns)
            flush(stdout)
        end
        digest
        catch err
            err isa OutOfMemoryError && rethrow()
            throw(ArgumentError("callback captures are not canonically source-bindable: $(sprint(showerror, err))"))
        end
    end
    (methods=Tuple(method_identities), capture_hash=capture_hash)
end

"Return the identity hash of callable methods and their captured configuration."
function coupled_mhd_provider_context_hash_v1(regional_evaluator,
        interface_evaluator, outer_evaluator, conservation_evaluator,
        jacobian_oracle; edge_equilibrium_evaluator=nothing, interface_geometry_contexts=nothing)
    callbacks = (regional_evaluator, interface_evaluator, outer_evaluator,
        conservation_evaluator, jacobian_oracle)
    identities = edge_equilibrium_evaluator === nothing ?
        Tuple(_callback_identity(f) for f in callbacks) :
        Tuple(_callback_identity(f) for f in (callbacks..., edge_equilibrium_evaluator))
    _provider_context_hash_from_identities_v1(identities;
        interface_geometry_contexts=interface_geometry_contexts)
end

function _provider_context_hash_from_identities_v1(identities; interface_geometry_contexts=nothing)
    callback_context_hash = string(canonical_hash(identities))
    interface_geometry_contexts === nothing ? callback_context_hash :
        string(canonical_hash((callback_context_hash=callback_context_hash,
            interface_geometry_contexts=interface_geometry_contexts)))
end

"A candidate-bound closure value with raw-source and semantic-payload hashes."
struct CoupledMHDClosureEvidenceV1
    kind::Symbol
    candidate_hash::String
    source_ref::String
    source_path::String
    source_sha256::String
    payload::Any
    payload_sha256::String
    evidence_hash::String
    function CoupledMHDClosureEvidenceV1(
            ::Val{:inhouse_coupled_mhd_closure_private_v1}, fields...)
        new(fields...)
    end
end

function make_closure_evidence_v1(kind::Symbol, candidate_hash::AbstractString,
        source_ref::AbstractString, source_path::AbstractString, payload)
    kind in _REQUIRED_CLOSURES || throw(ArgumentError("unknown MHD closure kind: $kind"))
    _valid_sha(candidate_hash) || throw(ArgumentError("candidate hash must be SHA-256"))
    isempty(strip(source_ref)) && throw(ArgumentError("closure source reference is required"))
    isfile(source_path) || throw(ArgumentError("closure source file is absent"))
    payload_hash = string(canonical_hash(payload))
    body = (revision=_REVISION, kind=kind, candidate_hash=String(candidate_hash),
        source_ref=String(source_ref), source_path=abspath(source_path),
        source_sha256=_sha_file(source_path), payload_sha256=payload_hash)
    CoupledMHDClosureEvidenceV1(_CLOSURE_TOKEN, kind, String(candidate_hash), String(source_ref),
        abspath(source_path), body.source_sha256, payload, payload_hash,
        string(canonical_hash(body)))
end

function _validate_closure(e::CoupledMHDClosureEvidenceV1, candidate_hash::String, kind::Symbol)
    e.kind === kind && e.candidate_hash == candidate_hash &&
        !isempty(strip(e.source_ref)) && isfile(e.source_path) &&
        _valid_sha(e.source_sha256) && _sha_file(e.source_path) == e.source_sha256 &&
        string(canonical_hash(e.payload)) == e.payload_sha256 ||
        throw(ArgumentError("closure evidence is stale, foreign, or malformed: $kind"))
    body = (revision=_REVISION, kind=e.kind, candidate_hash=e.candidate_hash,
        source_ref=e.source_ref, source_path=e.source_path,
        source_sha256=e.source_sha256, payload_sha256=e.payload_sha256)
    string(canonical_hash(body)) == e.evidence_hash ||
        throw(ArgumentError("closure evidence identity mismatch: $kind"))
    true
end

"Frozen caller-supplied acceptance gates. No default values are provided."
struct CoupledMHDGlobalPolicyV1
    acceptance_ref::String
    contract_source_path::String
    contract_semantic_hash::String
    max_updates::Int
    wall_seconds::Float64
    residual_tolerance::Float64
    constraint_tolerance::Float64
    stationarity_tolerance::Float64
    bound_dual_tolerance::Float64
    complementarity_tolerance::Float64
    step_tolerance::Float64
    minimum_step::Float64
    armijo_fraction::Float64
    max_backtracks::Int
    max_active_set_iterations::Int
    stagnation_window::Int
    policy_hash::String
    function CoupledMHDGlobalPolicyV1(
            ::Val{:inhouse_coupled_mhd_policy_private_v1}, fields...)
        new(fields...)
    end
end

function make_global_policy_v1(;acceptance_ref, contract_source_path,
        max_updates, wall_seconds, residual_tolerance, constraint_tolerance,
        stationarity_tolerance, bound_dual_tolerance,
        complementarity_tolerance, step_tolerance, minimum_step,
        armijo_fraction, max_backtracks, max_active_set_iterations,
        stagnation_window)
    isempty(strip(acceptance_ref)) && throw(ArgumentError("acceptance reference is required"))
    isempty(strip(String(contract_source_path))) &&
        throw(ArgumentError("frozen acceptance source reference is required"))
    ints = (max_updates, max_backtracks, max_active_set_iterations, stagnation_window)
    all(x -> x isa Integer && x > 0, ints) || throw(ArgumentError("iteration limits must be positive integers"))
    vals = Float64.((wall_seconds, residual_tolerance, constraint_tolerance,
        stationarity_tolerance, bound_dual_tolerance,
        complementarity_tolerance, step_tolerance, minimum_step, armijo_fraction))
    all(isfinite, vals) || throw(ArgumentError("policy values must be finite"))
    all(>(0.0), vals[1:8]) || throw(ArgumentError("budgets and tolerances must be positive"))
    0.0 < vals[9] < 1.0 || throw(ArgumentError("Armijo fraction must be in (0,1)"))
    0.0 < vals[8] <= 1.0 || throw(ArgumentError("minimum step must be in (0,1]"))
    src = abspath(contract_source_path)
    body = (revision=_REVISION, acceptance_ref=String(acceptance_ref),
        contract_source_path=src,
        contract_semantic_hash=_semantic_sha((acceptance_ref=String(acceptance_ref),
            contract_source_path=src)),
        max_updates=Int(max_updates), wall_seconds=vals[1],
        residual_tolerance=vals[2], constraint_tolerance=vals[3],
        stationarity_tolerance=vals[4], bound_dual_tolerance=vals[5],
        complementarity_tolerance=vals[6], step_tolerance=vals[7],
        minimum_step=vals[8], armijo_fraction=vals[9],
        max_backtracks=Int(max_backtracks),
        max_active_set_iterations=Int(max_active_set_iterations),
        stagnation_window=Int(stagnation_window))
    CoupledMHDGlobalPolicyV1(_POLICY_TOKEN, body.acceptance_ref, src,
        body.contract_semantic_hash, body.max_updates, body.wall_seconds,
        body.residual_tolerance, body.constraint_tolerance,
        body.stationarity_tolerance, body.bound_dual_tolerance,
        body.complementarity_tolerance, body.step_tolerance,
        body.minimum_step, body.armijo_fraction, body.max_backtracks,
        body.max_active_set_iterations, body.stagnation_window,
        string(canonical_hash(body)))
end

function _validate_policy(p::CoupledMHDGlobalPolicyV1)
    rebuilt = make_global_policy_v1(acceptance_ref=p.acceptance_ref,
        contract_source_path=p.contract_source_path, max_updates=p.max_updates,
        wall_seconds=p.wall_seconds, residual_tolerance=p.residual_tolerance,
        constraint_tolerance=p.constraint_tolerance,
        stationarity_tolerance=p.stationarity_tolerance,
        bound_dual_tolerance=p.bound_dual_tolerance,
        complementarity_tolerance=p.complementarity_tolerance,
        step_tolerance=p.step_tolerance, minimum_step=p.minimum_step,
        armijo_fraction=p.armijo_fraction, max_backtracks=p.max_backtracks,
        max_active_set_iterations=p.max_active_set_iterations,
        stagnation_window=p.stagnation_window)
    rebuilt.policy_hash == p.policy_hash || throw(ArgumentError("policy hash mismatch"))
    true
end

"Two-region provider binding remains compatible; new models carry an ordered interface graph."
struct CoupledMHDGlobalModelV1
    candidate_hash::String
    region_ids::Tuple
    region_dofs::Tuple
    local_dof_to_global::Tuple
    local_test_row_to_global::Tuple
    shared_scatter::Bool
    equilibrium_row_scales::Union{Nothing,Tuple{Vararg{Float64}}}
    scale_contract::Union{Nothing,NamedTuple}
    pressure_indices::Tuple{Vararg{Int}}
    regional_equation_ids::Tuple
    interface_constraint_ids::Tuple{Vararg{String}}
    interface_edges::Tuple
    interface_geometry_contexts::Union{Nothing,Tuple}
    outer_constraint_ids::Tuple
    global_conservation_ids::Tuple{Vararg{String}}
    closure_evidence::NamedTuple
    provider_id::String
    provider_source_path::String
    provider_semantic_hash::String
    provider_context_hash::String
    regional_evaluator::Function
    interface_evaluator::Function
    outer_evaluator::Function
    conservation_evaluator::Function
    jacobian_oracle::Function
    edge_equilibrium_evaluator::Union{Nothing,Function}
    model_hash::String
    function CoupledMHDGlobalModelV1(
            ::Val{:inhouse_coupled_mhd_model_private_v1}, fields...)
        new(fields...)
    end
end

function _model_body(m::CoupledMHDGlobalModelV1)
    body = (revision=_REVISION, candidate_hash=m.candidate_hash,
        region_ids=m.region_ids, region_dofs=m.region_dofs,
        local_dof_to_global=m.local_dof_to_global,
        local_test_row_to_global=m.local_test_row_to_global,
        shared_scatter=m.shared_scatter,
        pressure_indices=m.pressure_indices,
        regional_equation_ids=m.regional_equation_ids,
        interface_constraint_ids=m.interface_constraint_ids,
        interface_edges=m.interface_edges,
        outer_constraint_ids=m.outer_constraint_ids,
        global_conservation_ids=m.global_conservation_ids,
        closure_hashes=Tuple(e isa CoupledMHDClosureEvidenceV1 ? e.evidence_hash : nothing
            for e in values(m.closure_evidence)),
        provider_id=m.provider_id, provider_source_path=m.provider_source_path,
        provider_semantic_hash=m.provider_semantic_hash,
        provider_context_hash=m.provider_context_hash,
        evaluator_identities=m.edge_equilibrium_evaluator === nothing ?
            Tuple(_callback_identity(f) for f in
                (m.regional_evaluator, m.interface_evaluator, m.outer_evaluator,
                 m.conservation_evaluator, m.jacobian_oracle)) :
            Tuple(_callback_identity(f) for f in
                (m.regional_evaluator, m.interface_evaluator, m.outer_evaluator,
                 m.conservation_evaluator, m.jacobian_oracle,
                 m.edge_equilibrium_evaluator)),
        edge_equilibrium_evaluator_identity=m.edge_equilibrium_evaluator === nothing ?
            nothing : _callback_identity(m.edge_equilibrium_evaluator))
    body = m.interface_geometry_contexts === nothing ? body :
        merge(body, (interface_geometry_contexts=m.interface_geometry_contexts,))
    body = m.equilibrium_row_scales === nothing ? body : merge(body,
        (equilibrium_row_scales=m.equilibrium_row_scales,
         equilibrium_row_scale_hash=string(canonical_hash(m.equilibrium_row_scales))))
    m.scale_contract === nothing ? body : merge(body,
        (scale_contract_hash=m.scale_contract.contract_hash,
         scale_contract=m.scale_contract))
end

function _validated_model_body(m::CoupledMHDGlobalModelV1)
    _valid_sha(m.candidate_hash) || throw(ArgumentError("candidate hash is malformed"))
    body = _model_body(m)
    string(canonical_hash(body)) == m.model_hash ||
        throw(ArgumentError("global model identity mismatch"))
    body
end

function _validate_model(m::CoupledMHDGlobalModelV1)
    _validated_model_body(m)
    true
end

function _normalize_interface_edges(region_ids, interface_constraint_ids, interface_edges)
    if length(region_ids) == 1
        isempty(interface_constraint_ids) && interface_edges == () || throw(ArgumentError(
            "explicit single-region models require interface_edges=() and no interface constraints"))
        return ()
    end
    if interface_edges === nothing
        length(region_ids) == 2 || throw(ArgumentError(
            "multi-region models require an explicit interface edge graph"))
        all(id -> id isa AbstractString, interface_constraint_ids) ||
            throw(ArgumentError("legacy interface constraint IDs must be strings"))
        ids = Tuple(String.(interface_constraint_ids))
        !isempty(ids) && all(id -> !isempty(strip(id)), ids) &&
            length(unique(ids)) == length(ids) ||
            throw(ArgumentError("legacy interface constraints require nonempty unique IDs"))
        return ((edge_id="$(region_ids[1])->$(region_ids[2])",
            minus_region_id=String(region_ids[1]), plus_region_id=String(region_ids[2]),
            constraint_ids=ids),)
    end
    edges = Tuple(begin
        edge isa NamedTuple && Tuple(keys(edge)) ==
            (:edge_id, :minus_region_id, :plus_region_id, :constraint_ids) ||
            throw(ArgumentError("each interface edge must declare ordered identity, endpoints, and constraint IDs"))
        edge.edge_id isa AbstractString && edge.minus_region_id isa AbstractString &&
            edge.plus_region_id isa AbstractString &&
            all(id -> id isa AbstractString, edge.constraint_ids) ||
            throw(ArgumentError("interface edge IDs and constraint IDs must be strings"))
        edge_id = String(edge.edge_id)
        minus = String(edge.minus_region_id); plus = String(edge.plus_region_id)
        ids = Tuple(String.(edge.constraint_ids))
        !isempty(strip(edge_id)) && !isempty(strip(minus)) && !isempty(strip(plus)) &&
            minus != plus && !isempty(ids) && all(id -> !isempty(strip(id)), ids) ||
            throw(ArgumentError("interface edge identity, endpoints, and constraints must be nonempty and distinct"))
        (edge_id=edge_id, minus_region_id=minus, plus_region_id=plus,
            constraint_ids=ids)
    end for edge in interface_edges)
    !isempty(edges) || throw(ArgumentError("interface graph must contain at least one edge"))
    all(edge -> edge.minus_region_id in region_ids && edge.plus_region_id in region_ids, edges) ||
        throw(ArgumentError("interface edge references an unknown region"))
    adjacency = Dict(String(region) => String[] for region in region_ids)
    for edge in edges
        push!(adjacency[edge.minus_region_id], edge.plus_region_id)
        push!(adjacency[edge.plus_region_id], edge.minus_region_id)
    end
    reached = Set{String}(); pending = [String(first(region_ids))]
    while !isempty(pending)
        current = pop!(pending)
        current in reached && continue
        push!(reached, current)
        append!(pending, adjacency[current])
    end
    length(reached) == length(region_ids) ||
        throw(ArgumentError("interface graph must connect every declared region"))
    length(unique([edge.edge_id for edge in edges])) == length(edges) ||
        throw(ArgumentError("interface edge IDs must be globally unique"))
    edge_ids = Tuple(id for edge in edges for id in edge.constraint_ids)
    length(unique(collect(edge_ids))) == length(edge_ids) ||
        throw(ArgumentError("interface constraint IDs must be unique across the graph"))
    all(id -> id isa AbstractString, interface_constraint_ids) ||
        throw(ArgumentError("flattened interface constraint IDs must be strings"))
    isempty(interface_constraint_ids) || Tuple(String.(interface_constraint_ids)) == edge_ids ||
        throw(ArgumentError("flattened interface constraint IDs must match ordered edge coverage"))
    edges
end

function _normalize_interface_geometry_contexts(edges, contexts, region_ids, region_dofs)
    contexts === nothing && return nothing
    contexts isa Tuple || throw(ArgumentError("interface geometry contexts must be an immutable ordered tuple"))
    length(contexts) == length(edges) || throw(ArgumentError("interface geometry contexts must cover every ordered edge"))
    for (edge, geometry) in zip(edges, contexts)
        geometry isa NamedTuple && keys(geometry) ==
            (:edge_id, :orientation, :source_geometry, :samples) &&
            geometry.edge_id == edge.edge_id && geometry.orientation === :minus_to_plus &&
            geometry.source_geometry isa NamedTuple &&
            keys(geometry.source_geometry) == (:face_sha256, :face_schema, :face_row_count) &&
            _valid_sha(geometry.source_geometry.face_sha256) &&
            geometry.source_geometry.face_schema in
                ("spatial_geometry_v1", "spatial-manufactured-geometry-v1") &&
            geometry.source_geometry.face_row_count isa Integer &&
            geometry.source_geometry.face_row_count > 0 &&
            geometry.samples isa Tuple && !isempty(geometry.samples) ||
            throw(ArgumentError("interface geometry context must bind its edge, source face artifact, and ordered samples"))
        for sample in geometry.samples
            required = (:face_id, :quadrature_id, :chart_q, :xyz, :weight, :normal, :E, :Einv, :minus, :plus)
            sample isa NamedTuple && keys(sample) == required ||
                throw(ArgumentError("interface geometry sample has an unsupported field layout"))
            sample.face_id isa Integer && !(sample.face_id isa Bool) && sample.face_id > 0 &&
                sample.quadrature_id isa Integer && !(sample.quadrature_id isa Bool) && sample.quadrature_id > 0 ||
                throw(ArgumentError("interface geometry sample IDs must be positive integers"))
            all(v -> v isa Real && !(v isa Bool) && isfinite(v), sample.chart_q) && length(sample.chart_q) == 3 &&
                all(v -> v isa Real && !(v isa Bool) && isfinite(v), sample.xyz) && length(sample.xyz) == 3 &&
                sample.weight isa Real && !(sample.weight isa Bool) && isfinite(sample.weight) && sample.weight > 0.0 &&
                all(v -> v isa Real && !(v isa Bool) && isfinite(v), sample.normal) && length(sample.normal) == 3 ||
                throw(ArgumentError("interface geometry coordinates, normal, or quadrature weight are invalid"))
            E = Float64[sample.E[i][j] for i in 1:3, j in 1:3]
            Einv = Float64[sample.Einv[i][j] for i in 1:3, j in 1:3]
            norm(E * Einv - I, Inf) <= 1.0e-8 && all(isfinite, E) && all(isfinite, Einv) ||
                throw(ArgumentError("interface geometry metric and inverse are inconsistent"))
            abs(norm(sample.normal) - 1.0) <= 1.0e-8 ||
                throw(ArgumentError("interface geometry normal must be an outward unit conormal"))
            for (endpoint, region_id) in ((sample.minus, edge.minus_region_id), (sample.plus, edge.plus_region_id))
                endpoint isa NamedTuple && keys(endpoint) ==
                    (:region_id, :cell_id, :node_ids, :local_dofs, :basis_values, :basis_chart_gradients) &&
                    endpoint.region_id == region_id && endpoint.cell_id isa Integer && endpoint.cell_id > 0 ||
                    throw(ArgumentError("interface endpoint basis is not bound to its ordered model region"))
                count = length(endpoint.node_ids)
                count > 0 && length(endpoint.local_dofs) == count &&
                    length(endpoint.basis_values) == count && length(endpoint.basis_chart_gradients) == count ||
                    throw(ArgumentError("interface endpoint basis/node/DOF counts differ"))
                region = findfirst(==(region_id), region_ids)
                region === nothing && throw(ArgumentError("interface geometry names an unknown model region"))
                all(dofs -> dofs isa Tuple && length(dofs) == 4 &&
                    all(i -> i isa Integer && !(i isa Bool) && 1 <= i <= region_dofs[region], dofs), endpoint.local_dofs) ||
                    throw(ArgumentError("interface endpoint local DOFs are outside their model region"))
                all(v -> v isa Real && !(v isa Bool) && isfinite(v), endpoint.basis_values) &&
                    all(row -> row isa Tuple && length(row) == 3 &&
                        all(v -> v isa Real && !(v isa Bool) && isfinite(v), row), endpoint.basis_chart_gradients) ||
                    throw(ArgumentError("interface endpoint Q1 basis data are invalid"))
            end
        end
    end
    canonical_json(contexts)
    contexts
end

function _normalize_int_tuple_v1(values)
    values isa Tuple{Vararg{Int}} && return values
    source = values isa Tuple ? collect(values) : values
    Tuple(Int.(source))
end

function _normalize_string_tuple_v1(values)
    values isa Tuple{Vararg{String}} && return values
    source = values isa Tuple ? collect(values) : values
    Tuple(String.(source))
end

function _normalize_region_scatter(region_ids, region_dofs, regional_equation_ids,
        local_dof_to_global, local_test_row_to_global)
    provided = local_dof_to_global !== nothing || local_test_row_to_global !== nothing
    if !provided
        dof_maps = Tuple(begin
            first_index = 1 + sum(region_dofs[1:(k - 1)]; init=0)
            Tuple(first_index:(first_index + region_dofs[k] - 1))
        end for k in eachindex(region_ids))
        row_maps = Tuple(begin
            first_index = 1 + sum(length.(regional_equation_ids[1:(k - 1)]); init=0)
            Tuple(first_index:(first_index + length(regional_equation_ids[k]) - 1))
        end for k in eachindex(region_ids))
        return dof_maps, row_maps, false
    end
    local_dof_to_global !== nothing && local_test_row_to_global !== nothing ||
        throw(ArgumentError("shared assembly requires both local DOF and local test-row maps"))
    length(local_dof_to_global) == length(region_ids) &&
        length(local_test_row_to_global) == length(region_ids) ||
        throw(ArgumentError("shared assembly maps must cover every region"))
    all(mapping -> all(index -> index isa Integer && !(index isa Bool) && index > 0,
        mapping), local_dof_to_global) &&
        all(mapping -> all(index -> index isa Integer && !(index isa Bool) && index > 0,
        mapping), local_test_row_to_global) ||
        throw(ArgumentError("shared assembly indices must be positive integers"))
    dof_maps = Tuple(_normalize_int_tuple_v1(mapping) for mapping in local_dof_to_global)
    row_maps = Tuple(_normalize_int_tuple_v1(mapping) for mapping in local_test_row_to_global)
    all(k -> length(dof_maps[k]) == region_dofs[k] &&
        all(>(0), dof_maps[k]), eachindex(region_ids)) ||
        throw(ArgumentError("each local DOF map must contain one positive global index per local DOF"))
    all(k -> length(row_maps[k]) == length(regional_equation_ids[k]) &&
        all(>(0), row_maps[k]), eachindex(region_ids)) ||
        throw(ArgumentError("each local test-row map must cover the regional equation IDs exactly"))
    global_dofs = maximum(Iterators.flatten(dof_maps))
    global_rows = maximum(Iterators.flatten(row_maps))
    global_dof_set = Set(Iterators.flatten(dof_maps))
    global_test_row_set = Set(Iterators.flatten(row_maps))
    all(i -> i in global_dof_set, 1:global_dofs) ||
        throw(ArgumentError("shared global DOF indices must be contiguous and covered"))
    all(i -> i in global_test_row_set, 1:global_rows) ||
        throw(ArgumentError("shared global test-row indices must be contiguous and covered"))
    dof_maps, row_maps, true
end

"""Freeze a regional model, optionally with shared-DOF scatter and edge weak terms.

The default remains a connected multi-region model. A caller may explicitly
declare `single_region=true`, exactly one region, and `interface_edges=()`.
That domain has no internal interface or edge-equilibrium callback. Its real
outer and conservation rows, pressure bounds, and all five closures remain
required. This does not make a sampled interior subset a complete domain.
The existing region inventory binds this distinction in the model hash.

Shared mode requires `local_dof_to_global` and `local_test_row_to_global` maps,
plus `pressure_indices_global=true`. Regional residual rows and all four edge
equilibrium Jacobian blocks scatter-add through those maps. The optional
`edge_equilibrium_evaluator(edge, minus_state, plus_state, closures, context)`
returns candidate/provider identity, `region_id="edge_equilibrium:<edge_id>"`,
`edge_id`, concatenated endpoint `equation_ids`, endpoint `minus_residual` /
`plus_residual`, and `jacobian_minus_minus`, `jacobian_minus_plus`,
`jacobian_plus_minus`, `jacobian_plus_plus`. These are equilibrium weak-row
contributions; `interface_evaluator` remains a separate equality-constraint
provider. The independent oracle handles operation `:edge_equilibrium` and
returns the same row IDs with the vertically stacked/horizontally concatenated
four-block Jacobian.

`equilibrium_row_scales`, when supplied, is one frozen, finite, strictly
positive scale per global equilibrium test row after scatter. The solver uses
`r_scaled = r_raw ./ scales` and `J_scaled = Diagonal(1 ./ scales) * J_raw`
for the equilibrium least-squares KKT step, merit, line search, stationarity,
and residual-tolerance gate. The weighted diagnostic partition can also scale
exact equality rows by positive characteristics while preserving their zero
sets. Such characteristics are numerical preconditioners, not calibrated
physical merit or tolerances. The model hashes any supplied scale contract;
raw equilibrium residual/Jacobian and scale provenance remain auditable.
Omitting scale keywords retains the legacy raw-row behavior.
"""
function make_global_model_v1(;candidate_hash, region_ids, region_dofs,
        single_region=false,
        pressure_indices, regional_equation_ids, interface_constraint_ids=(), interface_edges=nothing,
        interface_geometry_contexts=nothing,
        local_dof_to_global=nothing, local_test_row_to_global=nothing,
        pressure_indices_global=false, edge_equilibrium_evaluator=nothing,
        equilibrium_row_scales=nothing, scale_contract=nothing,
        outer_constraint_ids, global_conservation_ids, closure_evidence,
        provider_id, provider_source_path, provider_context_hash,
        regional_evaluator, interface_evaluator, outer_evaluator,
        conservation_evaluator, jacobian_oracle)
    _valid_sha(candidate_hash) || throw(ArgumentError("candidate hash must be SHA-256"))
    single_region isa Bool || throw(ArgumentError("single_region must be an explicit Boolean"))
    (single_region ? length(region_ids) == 1 : length(region_ids) >= 2) ||
        throw(ArgumentError("default models require at least two regions; single_region=true requires exactly one"))
    all(x -> x isa AbstractString && !isempty(strip(x)), region_ids) &&
        length(unique(region_ids)) == length(region_ids) ||
        throw(ArgumentError("distinct nonempty region IDs are required"))
    length(region_dofs) == length(region_ids) && all(x -> x isa Integer && x > 0, region_dofs) ||
        throw(ArgumentError("each region must have a positive DOF count"))
    length(regional_equation_ids) == length(region_ids) && all(ids -> !isempty(ids) &&
        all(x -> x isa AbstractString && !isempty(strip(x)), ids) &&
        length(unique(ids)) == length(ids), regional_equation_ids) ||
        throw(ArgumentError("each region requires a nonempty unique equation-ID inventory"))
    phase_diagnostics = get(ENV, "FUSION_G2_PRECHECK_MODE", "") == "global_model_short"
    phase_started_ns = phase_diagnostics ? time_ns() : UInt64(0)
    dof_maps, row_maps, shared_scatter = _normalize_region_scatter(region_ids,
        region_dofs, regional_equation_ids, local_dof_to_global, local_test_row_to_global)
    if phase_diagnostics
        println("G2_GLOBAL_MODEL_PHASE phase=scatter elapsed_ns=", time_ns()-phase_started_ns)
        flush(stdout); phase_started_ns=time_ns()
    end
    scales = if equilibrium_row_scales === nothing
        nothing
    else
        (equilibrium_row_scales isa Tuple || equilibrium_row_scales isa AbstractVector) ||
            throw(ArgumentError("equilibrium row scales must be an ordered tuple or vector"))
        scale_inputs = collect(equilibrium_row_scales)
        all(x -> x isa Real && !(x isa Bool), scale_inputs) ||
            throw(ArgumentError("equilibrium row scales must be real non-boolean values"))
        scale_values = Tuple(Float64.(scale_inputs))
        !isempty(scale_values) && all(x -> isfinite(x) && x > 0.0, scale_values) ||
            throw(ArgumentError("equilibrium row scales must be nonempty, finite, and strictly positive"))
        all(x -> isfinite(inv(x)) && inv(x) > 0.0, scale_values) ||
            throw(ArgumentError("equilibrium row scale reciprocals must be representable and nonzero"))
        length(scale_values) == maximum(Iterators.flatten(row_maps)) ||
            throw(ArgumentError("equilibrium row scales must cover the global test-row inventory exactly"))
        scale_values
    end
    if phase_diagnostics
        println("G2_GLOBAL_MODEL_PHASE phase=scale_normalization elapsed_ns=", time_ns()-phase_started_ns)
        flush(stdout); phase_started_ns=time_ns()
    end
    shared_scatter && pressure_indices_global !== true && throw(ArgumentError(
        "shared assembly requires pressure_indices_global=true"))
    single_region && edge_equilibrium_evaluator !== nothing && throw(ArgumentError(
        "single-region models have no internal edge equilibrium provider"))
    shared_scatter && !single_region && edge_equilibrium_evaluator === nothing && throw(ArgumentError(
        "shared assembly requires an edge equilibrium evaluator"))
    edge_equilibrium_evaluator === nothing || edge_equilibrium_evaluator isa Function ||
        throw(ArgumentError("edge equilibrium evaluator must be callable"))
    n = shared_scatter ? maximum(Iterators.flatten(dof_maps)) : sum(region_dofs)
    !isempty(pressure_indices) && all(i -> i isa Integer && 1 <= i <= n, pressure_indices) &&
        length(unique(pressure_indices)) == length(pressure_indices) ||
        throw(ArgumentError("pressure coordinates must be unique global indices"))
    if !single_region && interface_edges === nothing
        !isempty(interface_constraint_ids) ||
            throw(ArgumentError("legacy interface constraints require an ID inventory"))
        length(unique(interface_constraint_ids)) == length(interface_constraint_ids) ||
            throw(ArgumentError("legacy interface constraint IDs must be unique"))
    end
    edges = _normalize_interface_edges(region_ids, interface_constraint_ids, interface_edges)
    geometry_contexts = _normalize_interface_geometry_contexts(edges, interface_geometry_contexts,
        Tuple(String.(region_ids)), Tuple(Int.(region_dofs)))
    length(outer_constraint_ids) == length(region_ids) && all(ids -> !isempty(ids) &&
        all(x -> x isa AbstractString && !isempty(strip(x)), ids) &&
        length(unique(ids)) == length(ids), outer_constraint_ids) ||
        throw(ArgumentError("each region requires a nonempty unique outer-constraint inventory"))
    !isempty(global_conservation_ids) &&
        all(x -> x isa AbstractString && !isempty(strip(x)), global_conservation_ids) &&
        length(unique(global_conservation_ids)) == length(global_conservation_ids) ||
        throw(ArgumentError("global conservation requires a nonempty unique ID inventory"))
    Tuple(keys(closure_evidence)) == _REQUIRED_CLOSURES ||
        throw(ArgumentError("closure evidence must list all five required keys in canonical order"))
    isempty(strip(provider_id)) && throw(ArgumentError("provider identity is required"))
    _valid_sha(provider_context_hash) ||
        throw(ArgumentError("provider context must be semantically hash-bound"))
    isempty(strip(String(provider_source_path))) &&
        throw(ArgumentError("provider source reference is required"))
    all(x -> x isa Function, (regional_evaluator, interface_evaluator,
        outer_evaluator, conservation_evaluator, jacobian_oracle)) ||
        throw(ArgumentError("all providers and the independent Jacobian oracle must be callable"))
    ids = Tuple(String.(region_ids))
    nd = Tuple(Int.(region_dofs))
    pi = _normalize_int_tuple_v1(pressure_indices)
    eqids = Tuple(_normalize_string_tuple_v1(regional_equation_ids[k]) for k in eachindex(ids))
    iids = Tuple(id for edge in edges for id in edge.constraint_ids)
    oids = Tuple(_normalize_string_tuple_v1(outer_constraint_ids[k]) for k in eachindex(ids))
    cids = _normalize_string_tuple_v1(global_conservation_ids)
    if scale_contract !== nothing
        scale_contract isa NamedTuple && hasproperty(scale_contract,:contract_hash) &&
            String(scale_contract.schema)=="candidate-kkt-scale-contract-v1" &&
            String(scale_contract.candidate_hash)==String(candidate_hash) &&
            String(scale_contract.contract_hash)==string(canonical_hash(
                Base.structdiff(scale_contract,(contract_hash=scale_contract.contract_hash,)))) ||
            throw(ArgumentError("candidate KKT scale contract identity is invalid"))
        expected_eqids = String[id for region in eqids for id in region]
        expected_hardids = String[]
        for edge in edges, id in edge.constraint_ids
            push!(expected_hardids, id)
        end
        for region in oids
            append!(expected_hardids, region)
        end
        append!(expected_hardids, cids)
        contract_eqids = collect(scale_contract.equilibrium.row_ids)
        contract_hardids = collect(scale_contract.equalities.row_ids)
        contract_eqids == expected_eqids && contract_hardids == expected_hardids ||
            throw(ArgumentError("candidate KKT scale contract row IDs do not match ordered global model rows"))
        eq_units = collect(scale_contract.equilibrium.row_units)
        hard_units = collect(scale_contract.equalities.row_units)
        length(eq_units)==length(expected_eqids) && length(hard_units)==length(expected_hardids) ||
            throw(ArgumentError("candidate KKT scale contract units do not cover all model rows"))
        eqchars = collect(scale_contract.equilibrium.characteristics)
        hardchars = collect(scale_contract.equalities.characteristics)
        valid_scale = scale -> scale isa Real && !(scale isa Bool) && isfinite(scale) &&
            scale > 0.0 && isfinite(inv(scale)) && inv(scale) > 0.0
        all(unit->!isempty(strip(unit)),eq_units) && all(unit->!isempty(strip(unit)),hard_units) &&
            all(valid_scale,eqchars) && all(valid_scale,hardchars) ||
            throw(ArgumentError("candidate KKT scale contract units or characteristics are invalid"))
        scales===nothing && throw(ArgumentError("candidate KKT scale contract requires frozen equilibrium row scales"))
        scale_values=collect(scales)
        length(scale_values)==length(eqchars) && scale_values==eqchars ||
            throw(ArgumentError("equilibrium scales differ from candidate KKT scale contract"))
        length(scale_contract.equilibrium.characteristics)==length(expected_eqids) &&
            length(scale_contract.equalities.characteristics)==length(expected_hardids) ||
            throw(ArgumentError("candidate KKT scale contract characteristics do not cover all model rows"))
    end
    if phase_diagnostics
        println("G2_GLOBAL_MODEL_PHASE phase=model_inventory_and_scale_contract elapsed_ns=", time_ns()-phase_started_ns)
        flush(stdout); phase_started_ns=time_ns()
    end
    src = abspath(provider_source_path)
    ev = NamedTuple{_REQUIRED_CLOSURES}(Tuple(closure_evidence[k] for k in _REQUIRED_CLOSURES))
    callback_set = (regional_evaluator, interface_evaluator, outer_evaluator,
        conservation_evaluator, jacobian_oracle)
    model_callback_set = edge_equilibrium_evaluator === nothing ? callback_set :
        (callback_set..., edge_equilibrium_evaluator)
    callback_identities = Tuple(_callback_identity(f) for f in model_callback_set)
    implementation_identities = edge_equilibrium_evaluator === nothing ?
        callback_identities[1:4] :
        (callback_identities[1:4]..., callback_identities[6])
    implementation_methods = Set((entry.source_path, entry.source_line, entry.signature)
        for identity in implementation_identities
        for entry in identity.methods)
    oracle_methods = Set((entry.source_path, entry.source_line, entry.signature)
        for entry in callback_identities[5].methods)
    isempty(intersect(implementation_methods, oracle_methods)) ||
        throw(ArgumentError("jacobian_oracle must use an independent method identity"))
    actual_context_hash = _provider_context_hash_from_identities_v1(callback_identities;
        interface_geometry_contexts=geometry_contexts)
    String(provider_context_hash) == actual_context_hash ||
        throw(ArgumentError("provider context hash does not match method sources and captured values"))
    provider_sha = _semantic_sha((provider_id=String(provider_id),
        provider_source_path=src, provider_context_hash=actual_context_hash))
    if phase_diagnostics
        println("G2_GLOBAL_MODEL_PHASE phase=provider_identity_context_hash elapsed_ns=", time_ns()-phase_started_ns)
        flush(stdout); phase_started_ns=time_ns()
    end
    body = (revision=_REVISION, candidate_hash=String(candidate_hash),
        region_ids=ids, region_dofs=nd, local_dof_to_global=dof_maps,
        local_test_row_to_global=row_maps, shared_scatter=shared_scatter,
        pressure_indices=pi,
        regional_equation_ids=eqids, interface_constraint_ids=iids, interface_edges=edges,
        outer_constraint_ids=oids, global_conservation_ids=cids,
        closure_hashes=Tuple(e isa CoupledMHDClosureEvidenceV1 ? e.evidence_hash : nothing for e in values(ev)),
        provider_id=String(provider_id), provider_source_path=src,
        provider_semantic_hash=provider_sha,
        provider_context_hash=String(provider_context_hash),
        evaluator_identities=callback_identities,
        edge_equilibrium_evaluator_identity=edge_equilibrium_evaluator === nothing ?
            nothing : _callback_identity(edge_equilibrium_evaluator))
    body = geometry_contexts === nothing ? body :
        merge(body, (interface_geometry_contexts=geometry_contexts,))
    body = scales === nothing ? body : merge(body,
        (equilibrium_row_scales=scales,
         equilibrium_row_scale_hash=string(canonical_hash(scales))))
    body = scale_contract === nothing ? body : merge(body,
        (scale_contract_hash=scale_contract.contract_hash,scale_contract=scale_contract))
    model_hash = string(canonical_hash(body))
    if phase_diagnostics
        println("G2_GLOBAL_MODEL_PHASE phase=model_semantic_hash elapsed_ns=", time_ns()-phase_started_ns)
        println("G2_GLOBAL_MODEL_PHASE_RESULT model_hash=", model_hash)
        flush(stdout)
    end
    CoupledMHDGlobalModelV1(_MODEL_TOKEN, String(candidate_hash), ids, nd,
        dof_maps, row_maps, shared_scatter, scales, scale_contract, pi, eqids, iids,
        edges, geometry_contexts, oids, cids, ev,
        String(provider_id), src, provider_sha, String(provider_context_hash), regional_evaluator,
        interface_evaluator, outer_evaluator, conservation_evaluator,
        jacobian_oracle, edge_equilibrium_evaluator,
        model_hash)
end

function _missing_closures(m::CoupledMHDGlobalModelV1)
    missing = Symbol[]
    for key in _REQUIRED_CLOSURES
        e = getproperty(m.closure_evidence, key)
        if e === nothing
            push!(missing, key)
            continue
        end
        e isa CoupledMHDClosureEvidenceV1 ||
            throw(ArgumentError("malformed closure evidence is fail-closed: $key"))
        _validate_closure(e, m.candidate_hash, key)
    end
    Tuple(missing)
end

function _capability_signature_body_v1(m::CoupledMHDGlobalModelV1, missing)
    body = (revision=_REVISION, candidate_hash=m.candidate_hash,
        provider_id=m.provider_id, provider_semantic_hash=m.provider_semantic_hash,
        provider_context_hash=m.provider_context_hash,
        region_ids=m.region_ids, regional_dofs=m.region_dofs,
        local_dof_to_global=m.local_dof_to_global,
        local_test_row_to_global=m.local_test_row_to_global,
        shared_scatter=m.shared_scatter,
        regional_equation_ids=m.regional_equation_ids,
        interface_constraint_ids=m.interface_constraint_ids, interface_edges=m.interface_edges,
        outer_constraint_ids=m.outer_constraint_ids,
        required_closures=_REQUIRED_CLOSURES, missing_closures=missing,
        complete=isempty(missing),
        capabilities=(two_region_global_assembly=length(m.region_ids) == 2,
            multi_region_global_assembly=length(m.region_ids)>1, region_count=length(m.region_ids),
            shared_dof_scatter=m.shared_scatter,
            edge_equilibrium_terms=m.edge_equilibrium_evaluator !== nothing,
            interface_equalities=!isempty(m.interface_edges), outer_equalities=true,
            pressure_nonnegative_active_set=true,
            independent_jacobian_oracle=true,
            global_conservation=:required,
            pressure_topology=:pressure_topology in missing ? :typed_absent : :present,
            current_topology=:current_topology in missing ? :typed_absent : :present,
            B_out=:B_out in missing ? :typed_absent : :present,
            K_outer=:K_outer in missing ? :typed_absent : :present,
            return_current_path=:return_current_path in missing ? :typed_absent : :present),
        physical_authority=false, engineering_authority=false,
        claim_ceiling=:numerical_mechanism_only)
    if m.equilibrium_row_scales !== nothing
        body = merge(body, (equilibrium_residual_scaling=(mode=:explicit_positive_row_scales,
            row_scales=m.equilibrium_row_scales,
            row_scale_hash=string(canonical_hash(m.equilibrium_row_scales))),))
    end
    merge(body, (signature_hash=string(canonical_hash(body)),))
end


function coupled_mhd_capability_signature_v1(m::CoupledMHDGlobalModelV1)
    _validate_model(m)
    missing = _missing_closures(m)
    _capability_signature_body_v1(m, missing)
end

function _matrix_snapshot(A::AbstractMatrix)
    S = sparse(Float64.(A))
    ii, jj, vv = findnz(S)
    perm = sortperm(eachindex(vv); by=k -> (ii[k], jj[k]))
    (format=:coordinate, index_base=1, rows=size(S, 1), columns=size(S, 2),
        row_indices=Tuple(ii[perm]), column_indices=Tuple(jj[perm]),
        values=Tuple(vv[perm]))
end

# Sparse QR's R diagonal is ordering-dependent and is not rank revealing. A
# suspicious KKT pivot may use a bounded square-root solve of the same weighted
# least-squares objective after exact equality/active-bound elimination. Julia
# exposes host free memory here, not the outer job/cgroup's remaining hard-limit
# budget. The order and workspace caps bound the added allocation; the external
# job monitor remains authoritative.
const _KKT_RANK_FALLBACK_MAX_ORDER = 128
const _KKT_RANK_FALLBACK_MIN_REMAINING_NS = 250_000_000
const _KKT_RANK_FALLBACK_MEMORY_RESERVE_BYTES = 32 * 1024 * 1024
const _KKT_RUIZ_MAX_PASSES = 8
const _KKT_RUIZ_TARGET_ROW_NORM_RATIO = 4.0

function _kkt_rank_threshold(diagonal, dimensions)
    eps(Float64) * maximum(dimensions) * max(maximum(diagonal; init=0.0), 1.0)
end

function _kkt_rank_fallback_budget(K, policy)
    order = size(K, 1)
    order == size(K, 2) || return (allowed=false, reason=:nonsquare_kkt,
        order=order, estimated_peak_bytes=0, available_memory_bytes=0,
        remaining_ns=0)
    order <= _KKT_RANK_FALLBACK_MAX_ORDER ||
        return (allowed=false, reason=:kkt_order_over_fallback_limit, order=order,
            estimated_peak_bytes=0, available_memory_bytes=0, remaining_ns=0)
    remaining_ns = if hasproperty(policy, :deadline_ns)
        # `time_ns()` is UInt64 on Julia 1.10. Convert both operands to a
        # signed wide type before subtracting, then clamp to the diagnostic
        # Int64 range so an expired deadline cannot wrap into a large budget.
        remaining_wide = Int128(policy.deadline_ns) - Int128(time_ns())
        Int64(clamp(remaining_wide, Int128(0), Int128(typemax(Int64))))
    else
        typemax(Int64)
    end
    remaining_ns >= _KKT_RANK_FALLBACK_MIN_REMAINING_NS ||
        return (allowed=false, reason=:insufficient_wall_budget, order=order,
            estimated_peak_bytes=0, available_memory_bytes=0,
            remaining_ns=remaining_ns)
    dense_bytes = sizeof(Float64) * order * order
    # Covers dense constraint factors, the reduced design, QR factors, and
    # LAPACK workspace. The order cap bounds this at a few MiB; reserve 32 MiB.
    estimated_peak_bytes = max(_KKT_RANK_FALLBACK_MEMORY_RESERVE_BYTES,
        32 * dense_bytes)
    available_bytes = try
        Sys.free_memory()
    catch
        0
    end
    available_bytes >= estimated_peak_bytes ||
        return (allowed=false, reason=:insufficient_memory_budget, order=order,
            estimated_peak_bytes=estimated_peak_bytes,
            available_memory_bytes=available_bytes, remaining_ns=remaining_ns)
    (allowed=true, reason=:budget_available, order=order,
        estimated_peak_bytes=estimated_peak_bytes,
        available_memory_bytes=available_bytes, remaining_ns=remaining_ns)
end

function _kkt_square_root_qr_solution(J, f, Ca, ca, K, policy)
    n = size(J, 2); k = size(Ca, 1)
    k <= n || return (status=:numerical_fail,
        reason=:rank_deficient_kkt_system, detail=(constraint_rows=k, variables=n))
    hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
        return (status=:resource_interruption, reason=:wall_time_budget)

    p0 = zeros(Float64, n)
    Z = Matrix{Float64}(I, n, n)
    constraint_rank = 0
    constraint_threshold = 0.0
    constraint_row_scales = ones(Float64, k)
    constraint_qr = nothing
    if k > 0
        D = Matrix(Ca)
        row_norms = [norm(view(D, row, :)) for row in 1:k]
        all(isfinite, row_norms) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_constraint_norm)
        constraint_row_scales = Float64[norm > 0.0 ? inv(norm) : 1.0
            for norm in row_norms]
        all(value -> isfinite(value) && value > 0.0, constraint_row_scales) ||
            return (status=:numerical_fail, reason=:nonfinite_kkt_constraint_equilibration)
        D_rank = constraint_row_scales .* D
        d_rank = -constraint_row_scales .* ca
        all(isfinite, D_rank) && all(isfinite, d_rank) ||
            return (status=:numerical_fail, reason=:nonfinite_kkt_constraint_equilibration)
        constraint_qr = qr(Matrix(transpose(D_rank)), ColumnNorm())
        constraint_diagonal = abs.(diag(constraint_qr.R))
        all(isfinite, constraint_diagonal) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_constraint_qr_diagonal)
        constraint_threshold = _kkt_rank_threshold(constraint_diagonal,
            size(D_rank'))
        isfinite(constraint_threshold) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_constraint_rank_threshold)
        constraint_qr_rank = count(>(constraint_threshold), constraint_diagonal)
        constraint_qr_rank == k || return (status=:numerical_fail,
            reason=:rank_deficient_kkt_system,
            detail=(constraint_rank=constraint_qr_rank, constraint_rows=k,
                constraint_threshold=constraint_threshold,
                constraint_rank_method=:pivoted_qr_of_scaled_constraint_transpose))
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)

        constraint_svd = svd(D_rank; full=true)
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)
        all(isfinite, constraint_svd.S) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_constraint_spectrum)
        constraint_rank = count(>(constraint_threshold), constraint_svd.S)
        constraint_rank == k || return (status=:numerical_fail,
            reason=:rank_deficient_kkt_system,
            detail=(constraint_rank=constraint_rank, constraint_rows=k,
                constraint_threshold=constraint_threshold,
                constraint_rank_method=:svd_scaled_constraints))
        p0 = constraint_svd.V[:, 1:k] *
            ((transpose(constraint_svd.U) * d_rank) ./ constraint_svd.S)
        Z = constraint_svd.V[:, (k + 1):n]
        all(isfinite, p0) && all(isfinite, Z) ||
            return (status=:numerical_fail, reason=:nonfinite_kkt_constraint_basis)
    end

    hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
        return (status=:resource_interruption, reason=:wall_time_budget)
    reduced_design = Matrix(J * Z)
    all(isfinite, reduced_design) || return (status=:numerical_fail,
        reason=:nonfinite_kkt_reduced_design)
    reduced_columns = size(reduced_design, 2)
    reduced_diagonal = Float64[]
    reduced_threshold = 0.0
    reduced_rank = 0
    y = Float64[]
    if reduced_columns > 0
        reduced_qr = qr(reduced_design, ColumnNorm())
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)
        reduced_diagonal = abs.(diag(reduced_qr.R))
        all(isfinite, reduced_diagonal) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_reduced_qr_diagonal)
        reduced_threshold = _kkt_rank_threshold(reduced_diagonal,
            size(reduced_design))
        isfinite(reduced_threshold) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_reduced_rank_threshold)
        reduced_rank = count(>(reduced_threshold), reduced_diagonal)
        reduced_rank == reduced_columns || return (status=:numerical_fail,
            reason=:rank_deficient_kkt_system,
            detail=(rank_estimate=reduced_rank, columns=reduced_columns,
                relative_threshold=reduced_threshold,
                method=:pivoted_qr_reduced_least_squares_design_JZ))
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)
        y = reduced_qr \ (-(J * p0 + f))
    end
    p = p0 + Z * y
    lambda = J * p + f
    mu = if k == 0
        Float64[]
    else
        multiplier_scaled = constraint_qr \ (-(transpose(J) * lambda))
        constraint_row_scales .* multiplier_scaled
    end
    hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
        return (status=:resource_interruption, reason=:wall_time_budget)
    z = vcat(p, lambda, mu)
    all(isfinite, z) || return (status=:numerical_fail,
        reason=:nonfinite_kkt_solution)
    rank_snapshot = (rank_estimate=reduced_rank, columns=reduced_columns,
        relative_threshold=reduced_threshold,
        method=:pivoted_qr_reduced_least_squares_design_JZ,
        rank_operator=:constraint_nullspace_reduced_design_JZ,
        constraint_rank=constraint_rank, constraint_rows=k,
        constraint_relative_threshold=constraint_threshold,
        constraint_rank_method=k == 0 ? :no_exact_or_active_constraints :
            :pivoted_qr_and_svd_scaled_constraints,
        solution_method=:orthogonal_constraint_nullspace_and_pivoted_qr,
        original_kkt_order=size(K, 1))
    (status=:ok, z=z, rank_snapshot=rank_snapshot)
end

# Coordinate bounds need no dense nullspace basis. Each active coordinate is
# fixed exactly, including bounds first activated from a nonzero state.
# SPQR's F\b is a basic solution, so a second sparse QR supplies the minimum
# norm free-coordinate solution. Inconsistent QR ranks require a separately
# bounded singular-value rank of untruncated R; Q and dense nullspaces are never formed.
# Bound-only rectangular rank repair, not the square-KKT/nullspace fallback.
# Its new dense workspace must FIT WITHIN the existing 32 MiB reserve; the
# independent exact-equality KKT order-128 gate is neither raised nor bypassed.
function _kkt_bound_only_r_svd(A, b, threshold, policy)
    order=size(A,2);rows=size(A,1)
    # Include a conservative sparse-factor upper allowance (eight dense A
    # equivalents) and projected-RHS vectors as well as the small dense SVD.
    workspace=Int128(sizeof(Float64))*(32Int128(order)^2+
        8Int128(rows)*Int128(order)+3Int128(rows))
    limit=_KKT_RANK_FALLBACK_MEMORY_RESERVE_BYTES
    workspace<=limit || return (status=:numerical_fail,
        reason=:bound_only_rank_reveal_workspace_limit,
        detail=(free_columns=order,estimated_workspace_bytes=workspace,workspace_limit_bytes=limit))
    remaining=hasproperty(policy,:deadline_ns) ?
        max(Int128(0),Int128(policy.deadline_ns)-Int128(time_ns())) : Int128(typemax(Int64))
    remaining>=_KKT_RANK_FALLBACK_MIN_REMAINING_NS ||
        return (status=:resource_interruption,reason=:insufficient_wall_budget)
    available=try Sys.free_memory() catch; 0 end
    available>=limit || return (status=:resource_interruption,reason=:insufficient_memory_budget,
        detail=(available_memory_bytes=available,required_free_memory_bytes=limit))
    hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
        return (status=:resource_interruption,reason=:wall_time_budget)
    # tol=0 is only a factorization choice: NO numerical rank is accepted here.
    # Recompute from A because the first SPQR may already have discarded rows.
    F=qr(A;tol=0.0)
    hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
        return (status=:resource_interruption,reason=:wall_time_budget)
    hasproperty(policy,:deadline_ns) &&
        Int128(policy.deadline_ns)-Int128(time_ns())<_KKT_RANK_FALLBACK_MIN_REMAINING_NS &&
        return (status=:resource_interruption,reason=:insufficient_wall_budget)
    R=Matrix(F.R)
    all(isfinite,R) || return (status=:numerical_fail,reason=:nonfinite_kkt_reduced_qr)
    hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
        return (status=:resource_interruption,reason=:wall_time_budget)
    hasproperty(policy,:deadline_ns) &&
        Int128(policy.deadline_ns)-Int128(time_ns())<_KKT_RANK_FALLBACK_MIN_REMAINING_NS &&
        return (status=:resource_interruption,reason=:insufficient_wall_budget)
    S=svd(R;full=false)
    hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
        return (status=:resource_interruption,reason=:wall_time_budget)
    all(isfinite,S.S) && all(isfinite,S.U) && all(isfinite,S.Vt) ||
        return (status=:numerical_fail,reason=:nonfinite_kkt_reduced_svd)
    r=count(>(threshold),S.S)
    y=zeros(Float64,order)
    if r>0
        qtb=F.Q'*b[F.prow]
        coefficients=(transpose(S.U[:,1:r])*qtb[1:size(R,1)])./S.S[1:r]
        permuted=transpose(S.Vt[1:r,:])*coefficients
        fc=isempty(F.pcol) ? collect(1:order) : F.pcol
        y[fc]=permuted
    end
    all(isfinite,y) || return (status=:numerical_fail,reason=:nonfinite_kkt_solution)
    hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
        return (status=:resource_interruption,reason=:wall_time_budget)
    (status=:ok,y=y,rank_estimate=r,estimated_workspace_bytes=Int(workspace),
        workspace_limit_bytes=limit,rank_threshold=threshold,
        method=:untruncated_sparse_QR_bounded_R_SVD)
end

function _kkt_bound_only_minimum_norm(J, f, x, active, policy)
    hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
        return (status=:resource_interruption, reason=:wall_time_budget)
    n = size(J, 2); m = size(J, 1)
    free = setdiff(collect(1:n), active)
    p = zeros(Float64, n)
    p[active] = -x[active]
    A = sparse(J[:, free])
    b = -(f + J * p)
    all(isfinite, nonzeros(A)) && all(isfinite, b) ||
        return (status=:numerical_fail, reason=:nonfinite_kkt_reduced_design)
    # Column norms bound the R diagonal scale. Use the existing eps*order
    # convention with that pre-factorization scale; no rank-tolerance sweep.
    column_norms = [norm(view(nonzeros(A), nzrange(A, j))) for j in axes(A, 2)]
    threshold = _kkt_rank_threshold(column_norms, size(A))
    isfinite(threshold) || return (status=:numerical_fail,
        reason=:nonfinite_kkt_reduced_rank_threshold)
    free_rank = 0
    solution_method=:two_sparse_qr_minimum_norm_free_step
    rank_repair=nothing
    if !isempty(free)
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)
        F = qr(A; tol=threshold)
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget)
        all(isfinite, nonzeros(F.R)) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_reduced_qr)
        # SPQR's rank records live rows after its numerical rank detection;
        # counting diagonal entries is not equivalent under sparse ordering.
        free_rank = rank(F)
        if free_rank > 0
            qtb = F.Q' * b[F.prow]
            B = sparse(transpose(F.R[1:free_rank, :]))
            hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                return (status=:resource_interruption, reason=:wall_time_budget)
            G = qr(B; tol=threshold)
            hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                return (status=:resource_interruption, reason=:wall_time_budget)
            all(isfinite, nonzeros(G.R)) || return (status=:numerical_fail,
                reason=:nonfinite_kkt_minimum_norm_qr)
            if rank(G) != free_rank
                # A different rank under transposition is not a usable COD.
                # Resolve it with one singular-value rank of untruncated R.
                repair=_kkt_bound_only_r_svd(A,b,threshold,policy)
                repair.status===:ok || return repair
                rank_repair=(first_sparse_rank=free_rank,transpose_sparse_rank=rank(G),
                    estimated_workspace_bytes=repair.estimated_workspace_bytes,
                    workspace_limit_bytes=repair.workspace_limit_bytes)
                free_rank=repair.rank_estimate
                p[free]=repair.y
                solution_method=repair.method
            else
            # A[F.prow,F.pcol]=F.Q*F.R, B[G.prow,G.pcol]=G.Q*G.R.
            # Solve Rr*y=qtb[1:r] via Rg'*h=qtb[G.pcol], then
            # y[G.prow]=Qg*[h;0]. Undo BOTH column and row permutations.
            gc = isempty(G.pcol) ? collect(1:free_rank) : G.pcol
            h = LowerTriangular(sparse(transpose(G.R[1:free_rank, 1:free_rank]))) \
                qtb[1:free_rank][gc]
            y = zeros(Float64, length(free))
            y[G.prow] = G.Q * vcat(h, zeros(Float64, length(free) - free_rank))
            fc = isempty(F.pcol) ? collect(1:length(free)) : F.pcol
            p[free[fc]] = y
            end
        end
    end
    lambda = J * p + f
    # J'p + ... is not the stationarity equation: lambda is the LS residual.
    # For E*p=-x_active, J'lambda+E'mu=0, hence mu=-gradient_active.
    mu = -(transpose(J) * lambda)[active]
    z = vcat(p, lambda, mu)
    hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
        return (status=:resource_interruption, reason=:wall_time_budget)
    all(isfinite, z) || return (status=:numerical_fail, reason=:nonfinite_kkt_solution)
    (status=:ok, z=z,
        rank_snapshot=(rank_estimate=m + 2 * length(active) + free_rank,
            columns=n + m + length(active), relative_threshold=threshold,
            method=:bound_only_sparse_minimum_norm_qr,
            rank_operator=:free_coordinate_least_squares_design,
            free_rank=free_rank, free_columns=length(free),
            constraint_rank=length(active), constraint_rows=length(active),
            solution_method=solution_method,rank_repair=rank_repair))
end


# Return true only for structurally valid CSC storage with sorted, unique rows.
# Validate every pointer bound before indexing any stored row/value.
function _sparse_csc_rows_sorted_unique(A::SparseMatrixCSC)
    length(A.colptr)==size(A,2)+1 && !isempty(A.colptr) &&
        first(A.colptr)==1 && last(A.colptr)==length(A.rowval)+1 &&
        length(A.rowval)==length(A.nzval) || return false
    previous_pointer=1
    storage_limit=length(A.rowval)+1
    for pointer in A.colptr
        previous_pointer<=pointer<=storage_limit || return false
        previous_pointer=pointer
    end
    for col in 1:size(A,2)
        previous_row=0
        for pointer in A.colptr[col]:(A.colptr[col+1]-1)
            row=A.rowval[pointer]
            1<=row<=size(A,1) && row>previous_row || return false
            previous_row=row
        end
    end
    true
end

# A valid but unsorted/duplicate CSC is normalized via explicit COO triplets;
# sparse(I,J,V,...) sorts rows and combines duplicate coordinates.
function _sparse_normalized_csc(A::SparseMatrixCSC)
    _sparse_csc_rows_sorted_unique(A) && error("internal error: expected noncanonical CSC")
    # Revalidate pointer and row bounds before findnz traverses raw storage.
    length(A.colptr)==size(A,2)+1 && !isempty(A.colptr) &&
        first(A.colptr)==1 && last(A.colptr)==length(A.rowval)+1 &&
        length(A.rowval)==length(A.nzval) ||
        throw(ArgumentError("invalid sparse CSC storage"))
    previous_pointer=1
    storage_limit=length(A.rowval)+1
    for pointer in A.colptr
        previous_pointer<=pointer<=storage_limit ||
            throw(ArgumentError("invalid sparse CSC column pointers"))
        previous_pointer=pointer
    end
    for row in A.rowval
        1<=row<=size(A,1) || throw(ArgumentError("invalid sparse CSC row index"))
    end
    rows,cols,values=findnz(A)
    sparse(Int.(rows),Int.(cols),Float64.(values),size(A,1),size(A,2))
end

function _sparse_float64_csc(A::SparseMatrixCSC{Float64,Int})
    _sparse_csc_rows_sorted_unique(A) &&
        return SparseMatrixCSC{Float64,Int}(size(A,1),size(A,2),copy(A.colptr),
            copy(A.rowval),copy(A.nzval))
    _sparse_normalized_csc(A)
end
function _sparse_float64_csc(A::SparseMatrixCSC)
    _sparse_csc_rows_sorted_unique(A) &&
        return SparseMatrixCSC{Float64,Int}(A)
    _sparse_normalized_csc(A)
end
_sparse_float64_csc(A) = sparse(Float64.(A))

# Read-only oracle comparison borrows canonical storage; noncanonical storage
# is explicitly normalized before the streaming merge.
function _sparse_float64_csc_borrowed(A::SparseMatrixCSC{Float64,Int})
    _sparse_csc_rows_sorted_unique(A) ? A : _sparse_normalized_csc(A)
end
_sparse_float64_csc_borrowed(A) = _sparse_float64_csc(A)

# Compare canonical row-sorted, unique-row CSCs without materializing a
# difference matrix. Explicit stored zeros and unequal patterns are handled.
function _sparse_max_abs_difference(A::SparseMatrixCSC{Float64,Int},
        B::SparseMatrixCSC{Float64,Int})
    size(A) == size(B) || throw(ArgumentError("sparse difference dimensions differ"))
    _sparse_csc_rows_sorted_unique(A) && _sparse_csc_rows_sorted_unique(B) ||
        throw(ArgumentError("sparse difference requires canonical row-sorted unique CSC inputs"))
    defect=0.0
    for col in 1:size(A,2)
        pa=A.colptr[col]; enda=A.colptr[col+1]-1
        pb=B.colptr[col]; endb=B.colptr[col+1]-1
        while pa<=enda || pb<=endb
            if pb>endb || (pa<=enda && A.rowval[pa]<B.rowval[pb])
                defect=max(defect,abs(A.nzval[pa]));pa+=1
            elseif pa>enda || B.rowval[pb]<A.rowval[pa]
                defect=max(defect,abs(B.nzval[pb]));pb+=1
            else
                defect=max(defect,abs(A.nzval[pa]-B.nzval[pb]));pa+=1;pb+=1
            end
        end
    end
    defect
end

function _oracle_phase_marker(operation,phase,started_ns;jacobian=nothing)
    get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1" && operation===:outer || return nothing
    print("G2_GLOBAL_ORACLE_PHASE operation=",operation," phase=",phase,
        " elapsed_ns=",time_ns()-started_ns," gc_live_bytes=",Base.gc_live_bytes())
    if jacobian isa AbstractMatrix
        print(" matrix_type=",nameof(typeof(jacobian))," rows=",size(jacobian,1),
            " cols=",size(jacobian,2)," nnz=",
            jacobian isa SparseArrays.SparseMatrixCSC ? SparseArrays.nnz(jacobian) : nothing)
    end
    println();flush(stdout);nothing
end

function _checked_block(block, rows, columns, label; borrow_canonical_csc::Bool=false)
    block isa NamedTuple && hasproperty(block, :residual) && hasproperty(block, :jacobian) ||
        throw(ArgumentError("$label evaluator must return residual and jacobian"))
    block.residual isa AbstractVector && eltype(block.residual) <: Real ||
        throw(ArgumentError("$label residual must be a rank-one real vector"))
    r = Float64.(block.residual)
    J = if borrow_canonical_csc
        block.jacobian isa SparseMatrixCSC{Float64,Int} && _sparse_csc_rows_sorted_unique(block.jacobian) ||
            throw(ArgumentError("$label identity fast path requires canonical Float64 CSC storage"))
        _sparse_float64_csc_borrowed(block.jacobian)
    else
        _sparse_float64_csc(block.jacobian)
    end
    length(r) > 0 && size(J) == (length(r), columns) &&
        (rows === nothing || length(r) == rows) ||
        throw(ArgumentError("$label residual/Jacobian dimensions do not agree"))
    all(isfinite, r) && all(isfinite, nonzeros(J)) ||
        throw(ArgumentError("$label residual/Jacobian contains nonfinite values"))
    (residual=r, jacobian=J)
end

Base.@noinline Base.@nospecializeinfer function _check_provider_record(block, m, expected_ids, expected_region, label, id_field)
    Base.@nospecialize block m expected_ids id_field
    block isa NamedTuple && hasproperty(block, :candidate_hash) &&
        hasproperty(block, :provider_semantic_hash) &&
        hasproperty(block, :provider_context_hash) &&
        hasproperty(block, :region_id) && hasproperty(block, id_field) ||
        throw(ArgumentError("$label result lacks candidate/provider/coverage identity"))
    block.candidate_hash == m.candidate_hash &&
        block.provider_semantic_hash == m.provider_semantic_hash &&
        block.provider_context_hash == m.provider_context_hash &&
        block.region_id == expected_region ||
        throw(ArgumentError("$label result is bound to another candidate/provider"))
    _normalize_string_tuple_v1(getproperty(block, id_field)) == expected_ids ||
        throw(ArgumentError("$label result does not cover the frozen IDs exactly"))
    true
end

function _check_jacobian_oracle(m, operation, region_id, state, expected_ids,
        id_field, assembled_jacobian, label; provider_context=_provider_context(m),
        raw_record_observer=nothing)
    context = provider_context
    oracle_started_ns=time_ns()
    _oracle_phase_marker(operation,:oracle_call_begin,oracle_started_ns)
    record = m.jacobian_oracle(operation, region_id, state,
        m.closure_evidence, context)
    raw_record_observer === nothing || raw_record_observer(record)
    _oracle_phase_marker(operation,:oracle_return,oracle_started_ns;
        jacobian=hasproperty(record,:jacobian) ? record.jacobian : nothing)
    _check_provider_record(record, m, expected_ids, region_id,
        "$(label) jacobian_oracle", id_field)
    hasproperty(record, :jacobian) && hasproperty(record, :jacobian_oracle_hash) ||
        throw(ArgumentError("$(label) jacobian_oracle record is incomplete"))
    # This context is fresh for the current assembly; entry/final model validation
    # still independently rehashes mutable callback captures.
    expected_oracle_hash = context.jacobian_oracle_hash
    record.jacobian_oracle_hash == expected_oracle_hash ||
        throw(ArgumentError("$(label) jacobian_oracle source/capture identity mismatch"))
    record.jacobian isa AbstractMatrix{<:Real} ||
        throw(ArgumentError("$(label) jacobian_oracle must return a real matrix"))
    oracle_jacobian = _sparse_float64_csc_borrowed(record.jacobian)
    _oracle_phase_marker(operation,:oracle_normalized,oracle_started_ns;jacobian=oracle_jacobian)
    assembled_csc = _sparse_float64_csc_borrowed(assembled_jacobian)
    size(oracle_jacobian) == size(assembled_csc) &&
        all(isfinite, nonzeros(oracle_jacobian)) ||
        throw(ArgumentError("$(label) jacobian_oracle dimensions or values are invalid"))
    defect = _sparse_max_abs_difference(assembled_csc,oracle_jacobian)
    _oracle_phase_marker(operation,:defect_complete,oracle_started_ns;jacobian=oracle_jacobian)
    tolerance = 64eps(Float64) * max(1.0, _maxabs(nonzeros(assembled_jacobian)),
        _maxabs(nonzeros(oracle_jacobian)))
    defect <= tolerance ||
        throw(ArgumentError("$(label) jacobian_oracle consistency failure"))
    (operation=operation, region_id=region_id, equation_ids=expected_ids,
        oracle_hash=expected_oracle_hash, max_abs_defect=defect,
        roundoff_tolerance=tolerance, passed=true)
end

function _provider_context(m::CoupledMHDGlobalModelV1; interface_edge=nothing,
        interface_geometry_context=nothing, validated_model_body=nothing)
    oracle_identity = validated_model_body === nothing ?
        _callback_identity(m.jacobian_oracle) : validated_model_body.evaluator_identities[5]
    base = (candidate_hash=m.candidate_hash, provider_id=m.provider_id,
        provider_semantic_hash=m.provider_semantic_hash,
        provider_context_hash=m.provider_context_hash,
        jacobian_oracle_hash=string(canonical_hash(oracle_identity)))
    if interface_edge === nothing
        return base
    end
    interface_geometry_context === nothing ? merge(base, (interface_edge=interface_edge,)) :
        merge(base, (interface_edge=interface_edge,
            interface_geometry_context=interface_geometry_context))
end

function _region_ranges(m::CoupledMHDGlobalModelV1)
    ranges = UnitRange{Int}[]
    offset = 0
    for dofs in m.region_dofs
        push!(ranges, (offset + 1):(offset + dofs))
        offset += dofs
    end
    Tuple(ranges)
end

_global_dof_count(m::CoupledMHDGlobalModelV1) = maximum(Iterators.flatten(m.local_dof_to_global))
_global_test_row_count(m::CoupledMHDGlobalModelV1) = maximum(Iterators.flatten(m.local_test_row_to_global))

function _scatter_regional_blocks(blocks, row_maps, dof_maps, row_count, dof_count;
        identity_alias_safe::Bool=false)
    if identity_alias_safe && length(blocks)==1 && length(row_maps)==1 && length(dof_maps)==1
        block=only(blocks)
        if size(block.jacobian)==(row_count,dof_count) && length(block.residual)==row_count &&
                length(row_maps[1])==row_count && length(dof_maps[1])==dof_count &&
                all(i->row_maps[1][i]==i,eachindex(row_maps[1])) &&
                all(i->dof_maps[1][i]==i,eachindex(dof_maps[1]))
            # Alias only for exact identity maps; the call site opts in only
            # when the residual has no later edge-equilibrium mutation.
            return block.residual,block.jacobian
        end
    end
    residual = zeros(Float64, row_count)
    rows = Int[]; columns = Int[]; values = Float64[]
    for k in eachindex(blocks)
        block = blocks[k]
        for local_row in eachindex(block.residual)
            residual[row_maps[k][local_row]] += block.residual[local_row]
        end
        local_rows, local_columns, local_values = findnz(block.jacobian)
        append!(rows, [row_maps[k][i] for i in local_rows])
        append!(columns, [dof_maps[k][j] for j in local_columns])
        append!(values, local_values)
    end
    residual, sparse(rows, columns, values, row_count, dof_count)
end

function _scatter_matrix(local_jacobian, row_map, column_map, row_count, column_count)
    local_rows, local_columns, values = findnz(local_jacobian)
    sparse([row_map[i] for i in local_rows],
        [column_map[j] for j in local_columns], values, row_count, column_count)
end

function _stack_scattered_constraints(blocks, dof_maps, dof_count)
    total_rows = sum(length(block.residual) for block in blocks)
    residual = vcat((block.residual for block in blocks)...)
    rows = Int[]; columns = Int[]; values = Float64[]
    row_offset = 0
    for k in eachindex(blocks)
        local_rows, local_columns, local_values = findnz(blocks[k].jacobian)
        append!(rows, local_rows .+ row_offset)
        append!(columns, [dof_maps[k][j] for j in local_columns])
        append!(values, local_values)
        row_offset += size(blocks[k].jacobian, 1)
    end
    residual, sparse(rows, columns, values, total_rows, dof_count)
end

function _block_diagonal_sparse(blocks)
    total_rows = sum(size(block, 1) for block in blocks)
    total_columns = sum(size(block, 2) for block in blocks)
    rows = Int[]; columns = Int[]; values = Float64[]
    row_offset = 0; column_offset = 0
    for block in blocks
        local_rows, local_columns, local_values = findnz(block)
        append!(rows, local_rows .+ row_offset)
        append!(columns, local_columns .+ column_offset)
        append!(values, local_values)
        row_offset += size(block, 1)
        column_offset += size(block, 2)
    end
    sparse(rows, columns, values, total_rows, total_columns)
end

function _embed_interface_jacobian(local_jacobian, minus_map, plus_map, total_dofs)
    rows, local_columns, values = findnz(local_jacobian)
    columns_by_region = (minus_map..., plus_map...)
    sparse(rows, [columns_by_region[column] for column in local_columns], values,
        size(local_jacobian, 1), total_dofs)
end

function _checked_edge_equilibrium(block, m, edge, minus_index, plus_index, context, local_states)
    region_id = "edge_equilibrium:$(edge.edge_id)"
    expected_ids = (m.regional_equation_ids[minus_index]...,
        m.regional_equation_ids[plus_index]...)
    block isa NamedTuple && all(k -> hasproperty(block, k),
        (:candidate_hash, :provider_semantic_hash, :provider_context_hash,
         :region_id, :edge_id, :equation_ids, :minus_residual, :plus_residual,
         :jacobian_minus_minus, :jacobian_minus_plus,
         :jacobian_plus_minus, :jacobian_plus_plus)) ||
        throw(ArgumentError("edge equilibrium evaluator result is incomplete"))
    block.candidate_hash == m.candidate_hash &&
        block.provider_semantic_hash == m.provider_semantic_hash &&
        block.provider_context_hash == m.provider_context_hash &&
        block.region_id == region_id && block.edge_id == edge.edge_id &&
        Tuple(String.(block.equation_ids)) == expected_ids ||
        throw(ArgumentError("edge equilibrium result is bound to another edge, candidate, or provider"))
    block.minus_residual isa AbstractVector{<:Real} &&
        block.plus_residual isa AbstractVector{<:Real} ||
        throw(ArgumentError("edge equilibrium endpoint residuals must be real vectors"))
    minus_residual = Float64.(block.minus_residual)
    plus_residual = Float64.(block.plus_residual)
    length(minus_residual) == length(m.regional_equation_ids[minus_index]) &&
        length(plus_residual) == length(m.regional_equation_ids[plus_index]) ||
        throw(ArgumentError("edge equilibrium residual contributions must cover endpoint test rows"))
    nd_minus = m.region_dofs[minus_index]; nd_plus = m.region_dofs[plus_index]
    Jmm = sparse(Float64.(block.jacobian_minus_minus))
    Jmp = sparse(Float64.(block.jacobian_minus_plus))
    Jpm = sparse(Float64.(block.jacobian_plus_minus))
    Jpp = sparse(Float64.(block.jacobian_plus_plus))
    size(Jmm) == (length(minus_residual), nd_minus) &&
        size(Jmp) == (length(minus_residual), nd_plus) &&
        size(Jpm) == (length(plus_residual), nd_minus) &&
        size(Jpp) == (length(plus_residual), nd_plus) ||
        throw(ArgumentError("edge equilibrium Jacobian blocks do not match endpoint row/DOF maps"))
    all(isfinite, minus_residual) && all(isfinite, plus_residual) &&
        all(isfinite, nonzeros(Jmm)) && all(isfinite, nonzeros(Jmp)) &&
        all(isfinite, nonzeros(Jpm)) && all(isfinite, nonzeros(Jpp)) ||
        throw(ArgumentError("edge equilibrium contribution contains nonfinite values"))
    local_jacobian = [Jmm Jmp; Jpm Jpp]
    oracle_check = _check_jacobian_oracle(m, :edge_equilibrium, region_id,
        (minus=Tuple(local_states[1]), plus=Tuple(local_states[2])),
        expected_ids, :equation_ids, local_jacobian,
        "edge equilibrium $(edge.edge_id)"; provider_context=context)
    (edge=edge, minus_residual=minus_residual, plus_residual=plus_residual,
        jacobian_minus_minus=Jmm, jacobian_minus_plus=Jmp,
        jacobian_plus_minus=Jpm, jacobian_plus_plus=Jpp,
        oracle_check=oracle_check)
end

"Assemble global equilibrium rows and exact interface/outer equality rows."
function assemble_coupled_mhd_global_v1(m::CoupledMHDGlobalModelV1, x::AbstractVector;
        allow_incomplete::Bool=false)
    trace_assembly = get(ENV, "FUSION_G2_GLOBAL_ASSEMBLE_TIMING", "0") == "1"
    if trace_assembly
        assembly_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=assembly")
        flush(stdout)
    end
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=entry_validate")
        flush(stdout)
    end
    entry_model_body = _validated_model_body(m)
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=entry_validate elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    missing = _missing_closures(m)
    if !isempty(missing) && !allow_incomplete
        return (status=:typed_absent, missing_closures=missing,
        candidate_hash=m.candidate_hash, model_hash=m.model_hash,
        capability_signature=coupled_mhd_capability_signature_v1(m),
        physical_authority=false)
    end
    n = _global_dof_count(m)
    borrow_flag=get(ENV,"FUSION_G2_BORROW_CANONICAL_IDENTITY_REGION_BLOCK","0")
    borrow_flag in ("0","1") || throw(ArgumentError("canonical CSC borrow flag must be 0 or 1"))
    borrow_canonical_region=borrow_flag=="1"
    if borrow_canonical_region
        length(m.region_ids)==1 && length(m.local_dof_to_global)==1 &&
            length(m.local_test_row_to_global)==1 && m.shared_scatter &&
            m.edge_equilibrium_evaluator===nothing &&
            length(m.local_dof_to_global[1])==n &&
            all(i->m.local_dof_to_global[1][i]==i,eachindex(m.local_dof_to_global[1])) &&
            length(m.local_test_row_to_global[1])==_global_test_row_count(m) &&
            all(i->m.local_test_row_to_global[1][i]==i,eachindex(m.local_test_row_to_global[1])) ||
            throw(ArgumentError("canonical CSC borrow is limited to one exact identity-map region without edge mutation"))
    end
    length(x) == n && all(isfinite, x) || throw(ArgumentError("global state has invalid dimensions or values"))
    all(i -> x[i] >= 0.0, m.pressure_indices) ||
        throw(ArgumentError("initial pressure state violates the frozen nonnegative-pressure bound"))
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=provider_context")
        flush(stdout)
    end
    context = _provider_context(m; validated_model_body=entry_model_body)
    entry_model_body = nothing
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=provider_context elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    ranges = _region_ranges(m)
    local_states = Tuple(m.shared_scatter ?
        Float64[x[index] for index in m.local_dof_to_global[k]] :
        view(x, ranges[k]) for k in eachindex(m.region_ids))
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=region_blocks")
        flush(stdout)
    end
    region_blocks = Tuple(begin
        result = m.regional_evaluator(
            m.region_ids[k], local_states[k], m.closure_evidence, context)
        _check_provider_record(result, m, m.regional_equation_ids[k],
            m.region_ids[k], "regional $(m.region_ids[k])", :equation_ids)
        _checked_block(result, length(m.regional_equation_ids[k]),
            m.region_dofs[k], "regional $(m.region_ids[k])";
            borrow_canonical_csc=borrow_canonical_region)
    end for k in eachindex(m.region_ids))
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=region_blocks elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    sum(size(block.jacobian, 1) for block in region_blocks) > 0 ||
        throw(ArgumentError("regional equilibrium system is empty"))
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=regional_oracle")
        flush(stdout)
    end
    regional_jacobian_checks = Tuple(_check_jacobian_oracle(m,
        :regional, m.region_ids[k], local_states[k],
        m.regional_equation_ids[k], :equation_ids,
        region_blocks[k].jacobian, "regional $(m.region_ids[k])";
        provider_context=context) for k in eachindex(m.region_ids))
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=regional_oracle elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    # The local oracle consumes region blocks directly, so run it before making
    # the additional scattered CSC. The validation and inputs are unchanged.
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=scatter")
        flush(stdout)
    end
    f, J = if m.shared_scatter
        _scatter_regional_blocks(region_blocks, m.local_test_row_to_global,
            m.local_dof_to_global, _global_test_row_count(m), n;
            identity_alias_safe=m.edge_equilibrium_evaluator===nothing)
    else
        (vcat((block.residual for block in region_blocks)...),
            _block_diagonal_sparse(Tuple(block.jacobian for block in region_blocks)))
    end
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=scatter elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end

    interface_blocks = Tuple(begin
        minus_index = findfirst(==(edge.minus_region_id), m.region_ids)
        plus_index = findfirst(==(edge.plus_region_id), m.region_ids)
        endpoint_states = (local_states[minus_index], local_states[plus_index])
        edge_geometry = m.interface_geometry_contexts === nothing ? nothing :
            m.interface_geometry_contexts[edge_index]
        edge_context = _provider_context(m; interface_edge=edge,
            interface_geometry_context=edge_geometry)
        interface = m.interface_evaluator(endpoint_states[1], endpoint_states[2],
            m.closure_evidence, edge_context)
        interface_region = "interface:$(edge.edge_id)"
        _check_provider_record(interface, m, edge.constraint_ids, interface_region,
            "interface $(edge.edge_id)", :constraint_ids)
        interface isa NamedTuple && all(k -> hasproperty(interface, k),
            (:residual, :jacobian_minus, :jacobian_plus)) ||
            throw(ArgumentError("interface evaluator must return residual and both endpoint Jacobians"))
        interface.residual isa AbstractVector && eltype(interface.residual) <: Real ||
            throw(ArgumentError("interface residual must be a rank-one real vector"))
        residual = Float64.(interface.residual)
        jacobian_minus = sparse(Float64.(interface.jacobian_minus))
        jacobian_plus = sparse(Float64.(interface.jacobian_plus))
        !isempty(residual) && size(jacobian_minus) ==
            (length(residual), m.region_dofs[minus_index]) &&
            size(jacobian_plus) == (length(residual), m.region_dofs[plus_index]) ||
            throw(ArgumentError("interface edge Jacobian dimensions do not match its endpoint regions"))
        all(isfinite, residual) && all(isfinite, nonzeros(jacobian_minus)) &&
            all(isfinite, nonzeros(jacobian_plus)) ||
            throw(ArgumentError("interface edge contains nonfinite values"))
        local_jacobian = [jacobian_minus jacobian_plus]
        oracle_check = _check_jacobian_oracle(m, :interface, interface_region,
            endpoint_states, edge.constraint_ids, :constraint_ids, local_jacobian,
            "interface $(edge.edge_id)"; provider_context=edge_context)
        (edge=edge, residual=residual, jacobian_minus=jacobian_minus,
            jacobian_plus=jacobian_plus,
            global_jacobian=_embed_interface_jacobian(local_jacobian,
                m.local_dof_to_global[minus_index],
                m.local_dof_to_global[plus_index], n), oracle_check=oracle_check)
    end for (edge_index, edge) in enumerate(m.interface_edges))
    ci = isempty(interface_blocks) ? Float64[] : vcat((block.residual for block in interface_blocks)...)
    Ci = isempty(interface_blocks) ? spzeros(Float64,0,n) :
        reduce(vcat, (block.global_jacobian for block in interface_blocks))
    interface_jacobian_checks = Tuple(block.oracle_check for block in interface_blocks)

    edge_equilibrium_blocks = m.edge_equilibrium_evaluator === nothing ? () :
        Tuple(begin
            minus_index = findfirst(==(edge.minus_region_id), m.region_ids)
            plus_index = findfirst(==(edge.plus_region_id), m.region_ids)
            edge_geometry = m.interface_geometry_contexts === nothing ? nothing :
                m.interface_geometry_contexts[edge_index]
            edge_context = _provider_context(m; interface_edge=edge,
                interface_geometry_context=edge_geometry)
            result = m.edge_equilibrium_evaluator(edge, local_states[minus_index],
                local_states[plus_index], m.closure_evidence, edge_context)
            checked = _checked_edge_equilibrium(result, m, edge, minus_index,
                plus_index, edge_context,
                (local_states[minus_index], local_states[plus_index]))
            minus_rows = m.local_test_row_to_global[minus_index]
            plus_rows = m.local_test_row_to_global[plus_index]
            for i in eachindex(checked.minus_residual)
                f[minus_rows[i]] += checked.minus_residual[i]
            end
            for i in eachindex(checked.plus_residual)
                f[plus_rows[i]] += checked.plus_residual[i]
            end
            global_minus_jacobian = _scatter_matrix(checked.jacobian_minus_minus, minus_rows,
                m.local_dof_to_global[minus_index], _global_test_row_count(m), n)
            global_minus_jacobian += _scatter_matrix(checked.jacobian_minus_plus, minus_rows,
                m.local_dof_to_global[plus_index], _global_test_row_count(m), n)
            global_plus_jacobian = _scatter_matrix(checked.jacobian_plus_minus, plus_rows,
                m.local_dof_to_global[minus_index], _global_test_row_count(m), n)
            global_plus_jacobian += _scatter_matrix(checked.jacobian_plus_plus, plus_rows,
                m.local_dof_to_global[plus_index], _global_test_row_count(m), n)
            global_jacobian = global_minus_jacobian + global_plus_jacobian
            J += global_jacobian
            merge(checked, (global_jacobian=global_jacobian,))
        end for (edge_index, edge) in enumerate(m.interface_edges))

    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=outer_and_oracle")
        flush(stdout)
    end
    outer_parts = Tuple(begin
        result = m.outer_evaluator(m.region_ids[k], local_states[k],
            m.closure_evidence, context)
        _check_provider_record(result, m, m.outer_constraint_ids[k],
            m.region_ids[k], "outer $(m.region_ids[k])", :constraint_ids)
        _checked_block(result, length(m.outer_constraint_ids[k]),
            m.region_dofs[k], "outer $(m.region_ids[k])")
    end for k in eachindex(m.region_ids))
    if trace_assembly
        println("G2_GLOBAL_ORACLE_PHASE operation=outer phase=outer_forward elapsed_ns=",
            time_ns()-stage_started," gc_live_bytes=",Base.gc_live_bytes(),
            " rows=",sum(size(part.jacobian,1) for part in outer_parts)," cols=",n,
            " nnz=",sum(SparseArrays.nnz(part.jacobian) for part in outer_parts))
        flush(stdout)
    end
    outer_jacobian_checks = Tuple(_check_jacobian_oracle(m, :outer,
        m.region_ids[k], local_states[k], m.outer_constraint_ids[k],
        :constraint_ids, outer_parts[k].jacobian, "outer $(m.region_ids[k])";
        provider_context=context)
        for k in eachindex(m.region_ids))
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=outer_and_oracle elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    if trace_assembly
        gc_checkpoint_started = time_ns()
        gc_live_before_checkpoint = Base.gc_live_bytes()
        println("G2_GLOBAL_PRE_CONSERVATION_GC phase=before_full_gc",
            " gc_live_bytes=",gc_live_before_checkpoint)
        flush(stdout)
        # Outer-oracle temporaries are no longer rooted after its check returns.
        # Model callbacks and outer_parts remain rooted for later assembly.
        GC.gc(true)
        post_full_gc_baseline_live_bytes = Base.gc_live_bytes()
        println("G2_GLOBAL_PRE_CONSERVATION_GC phase=post_full_gc_baseline",
            " elapsed_ns=",time_ns()-gc_checkpoint_started,
            " gc_live_bytes=",post_full_gc_baseline_live_bytes,
            " before_minus_after_live_bytes=",
            Int128(gc_live_before_checkpoint)-Int128(post_full_gc_baseline_live_bytes))
        flush(stdout)
    end
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=conservation")
        flush(stdout)
    end
    conservation_eval_started = trace_assembly ? time_ns() : UInt64(0)
    if trace_assembly
        println("G2_GLOBAL_CONSERVATION_PHASE phase=evaluator_begin gc_live_bytes=",
            Base.gc_live_bytes())
        flush(stdout)
    end
    conservation = m.conservation_evaluator(x, m.closure_evidence, context)
    if trace_assembly
        # Do not inspect callback fields here: malformed generic callbacks must
        # still fail at the existing provider/block validation boundary.
        println("G2_GLOBAL_CONSERVATION_PHASE phase=evaluator_return elapsed_ns=",
            time_ns()-conservation_eval_started," gc_live_bytes=",Base.gc_live_bytes(),
            " result_type=",nameof(typeof(conservation)))
        flush(stdout)
    end
    _check_provider_record(conservation, m, m.global_conservation_ids,
        "global", "conservation", :conservation_ids)
    conservation_block_started = trace_assembly ? time_ns() : UInt64(0)
    conservation_block = _checked_block(conservation,
        length(m.global_conservation_ids), n, "global conservation")
    if trace_assembly
        println("G2_GLOBAL_CONSERVATION_PHASE phase=checked_block_end elapsed_ns=",
            time_ns()-conservation_block_started," gc_live_bytes=",Base.gc_live_bytes(),
            " rows=",length(conservation_block.residual),
            " cols=",size(conservation_block.jacobian,2),
            " nnz=",conservation_block.jacobian isa SparseArrays.SparseMatrixCSC ?
                SparseArrays.nnz(conservation_block.jacobian) : nothing)
        flush(stdout)
    end
    conservation_oracle_started = trace_assembly ? time_ns() : UInt64(0)
    if trace_assembly
        println("G2_GLOBAL_CONSERVATION_PHASE phase=oracle_begin gc_live_bytes=",
            Base.gc_live_bytes())
        flush(stdout)
    end
    conservation_jacobian_check = _check_jacobian_oracle(m,
        :global_conservation, "global", x, m.global_conservation_ids,
        :conservation_ids, conservation_block.jacobian, "global conservation";
        provider_context=context)
    if trace_assembly
        println("G2_GLOBAL_CONSERVATION_PHASE phase=oracle_end elapsed_ns=",
            time_ns()-conservation_oracle_started," gc_live_bytes=",Base.gc_live_bytes(),
            " passed=",conservation_jacobian_check.passed)
        flush(stdout)
    end
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=conservation elapsed_ns=", time_ns()-stage_started)
        flush(stdout)
    end
    if trace_assembly
        stage_started = time_ns()
        println("G2_GLOBAL_ASSEMBLE_BEGIN stage=final_validate")
        flush(stdout)
    end
    _validate_model(m)
    final_missing = _missing_closures(m)
    if trace_assembly
        println("G2_GLOBAL_ASSEMBLE_END stage=final_validate elapsed_ns=", time_ns()-stage_started)
        println("G2_GLOBAL_ASSEMBLE_FINAL_VALIDATE_COMPLETE elapsed_ns=", time_ns()-assembly_started)
        flush(stdout)
    end
    co, Co = if m.shared_scatter
        _stack_scattered_constraints(outer_parts, m.local_dof_to_global, n)
    else
        (vcat((part.residual for part in outer_parts)...),
            _block_diagonal_sparse(Tuple(part.jacobian for part in outer_parts)))
    end
    c = vcat(ci, co, conservation_block.residual)
    C = [Ci; Co; conservation_block.jacobian]
    size(C, 2) == n && size(C, 1) == length(c) ||
        throw(ArgumentError("global equality assembly dimension mismatch"))
    assembled = (status=:assembled, candidate_hash=m.candidate_hash,
        model_hash=m.model_hash, residual=f, jacobian=J,
        scale_contract=m.scale_contract,
        scale_contract_hash=m.scale_contract===nothing ? nothing : m.scale_contract.contract_hash,
        equality_residual=c, equality_jacobian=C,
        conservation_residual=conservation_block.residual,
        conservation_defect=_maxabs(conservation_block.residual),
        jacobian_checks=(regional=regional_jacobian_checks,
            interface=isempty(interface_jacobian_checks) ? nothing : first(interface_jacobian_checks),
            interfaces=interface_jacobian_checks, outer=outer_jacobian_checks,
            global_conservation=conservation_jacobian_check),
        row_ownership=(regional=m.region_ids,
            interface_rows=length(ci), outer_rows=length(co),
            conservation_rows=length(conservation_block.residual)),
        raw_blocks=(regions=region_blocks,
            edge_equilibrium=edge_equilibrium_blocks,
            interface=isempty(interface_blocks) ? nothing : (residual=interface_blocks[1].residual,
                jacobian_minus=interface_blocks[1].jacobian_minus,
                jacobian_plus=interface_blocks[1].jacobian_plus),
            interfaces=Tuple((edge_id=block.edge.edge_id,
                constraint_ids=block.edge.constraint_ids, residual=block.residual,
                jacobian_minus=block.jacobian_minus, jacobian_plus=block.jacobian_plus)
                for block in interface_blocks), outer=outer_parts,
            conservation=(residual=conservation_block.residual,
                jacobian=conservation_block.jacobian)),
        physical_authority=false, engineering_authority=false,
        claim_ceiling=:numerical_mechanism_only)
    if !isempty(missing)
        diagnostic_assembly = (status=:incomplete_assembly, residual=f, jacobian=J,
            equality_residual=c, equality_jacobian=C,
            scale_contract=m.scale_contract,
            scale_contract_hash=m.scale_contract===nothing ? nothing : m.scale_contract.contract_hash,
            conservation_residual=conservation_block.residual,
            conservation_defect=_maxabs(conservation_block.residual),
            jacobian_checks=assembled.jacobian_checks,
            row_ownership=assembled.row_ownership, raw_blocks=assembled.raw_blocks,
        equation_ids=(regional=m.regional_equation_ids,
            interface=Tuple(edge.constraint_ids for edge in m.interface_edges),
            outer=m.outer_constraint_ids, conservation=m.global_conservation_ids),
        equilibrium_row_scales=m.equilibrium_row_scales,
        residual_scaling=m.equilibrium_row_scales===nothing ? :raw_unscaled : :frozen_row_scales,
            physical_authority=false, claim_ceiling=:diagnostic_only)
        if m.equilibrium_row_scales !== nothing
            scaled_residual=f ./ m.equilibrium_row_scales
            scaled_jacobian=spdiagm(0 => 1.0 ./ collect(m.equilibrium_row_scales)) * J
            all(isfinite,scaled_residual) && all(isfinite,nonzeros(scaled_jacobian)) ||
                throw(ArgumentError("scaled diagnostic equilibrium residual/Jacobian is nonfinite"))
            diagnostic_assembly=merge(diagnostic_assembly,
                (equilibrium_row_scale_hash=string(canonical_hash(m.equilibrium_row_scales)),
                 scaled_residual=scaled_residual,scaled_jacobian=scaled_jacobian,
                 residual_scaling=:frozen_row_scales))
        end
        return (status=:typed_absent, missing_closures=missing,
            candidate_hash=m.candidate_hash, model_hash=m.model_hash,
            capability_signature=_capability_signature_body_v1(m, final_missing),
            physical_authority=false, claim_ceiling=:diagnostic_only,
            diagnostic_assembly=diagnostic_assembly)
    end
    if m.equilibrium_row_scales === nothing
        return assembled
    end
    length(m.equilibrium_row_scales) == length(f) ||
        throw(ArgumentError("equilibrium row scale coverage differs from assembled global test rows"))
    row_scales = m.equilibrium_row_scales
    scaled_residual = f ./ row_scales
    scaled_jacobian = spdiagm(0 => 1.0 ./ collect(row_scales)) * J
    all(isfinite, scaled_residual) && all(isfinite, nonzeros(scaled_jacobian)) ||
        throw(ArgumentError("scaled equilibrium residual/Jacobian is nonfinite"))
    merge(assembled, (equilibrium_row_scales=row_scales,
        equilibrium_row_scale_hash=string(canonical_hash(row_scales)),
        scaled_residual=scaled_residual, scaled_jacobian=scaled_jacobian))
end

function _active_kkt_step(J, f, C, c, x, pressure_indices, policy)
    n = size(J, 2); m = size(J, 1)
    active = sort!(Int[i for i in pressure_indices if iszero(x[i])])
    steps = NamedTuple[]
    for iteration in 1:policy.max_active_set_iterations
        hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
            return (status=:resource_interruption, reason=:wall_time_budget,
                active=Tuple(active), steps=Tuple(steps))
        E = isempty(active) ? spzeros(0, n) : sparse(1:length(active), active,
            ones(length(active)), length(active), n)
        Ca = [C; E]
        ca = vcat(c, x[active])
        k = size(Ca, 1)
        K = [spzeros(n, n) transpose(J) transpose(Ca);
             J -spdiagm(0 => ones(m)) spzeros(m, k);
              Ca spzeros(k, m) spzeros(k, k)]
        rhs = vcat(zeros(n), -f, -ca)
        try
            # Bounded symmetric row-L1 Ruiz passes change coordinates only:
            # solve (D*K*D)w = D*rhs and recover z = D*w. Stop when all
            # nonzero row norms are within a factor four, or at the fixed cap.
            # Every accepted solution is still checked against the original K.
            row_scales = ones(Float64, size(K, 1))
            equilibrated_K = sparse(K)
            equilibrated_rhs = copy(rhs)
            ruiz_pass_count = 0
            ruiz_final_norm_ratio = nothing
            for ruiz_pass in 1:_KKT_RUIZ_MAX_PASSES
                hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                    return (status=:resource_interruption, reason=:wall_time_budget,
                        active=Tuple(active), steps=Tuple(steps))
                row_norms = vec(sum(abs, equilibrated_K; dims=2))
                all(isfinite, row_norms) || return (status=:numerical_fail,
                    reason=:nonfinite_kkt_row_norm, active=Tuple(active), steps=Tuple(steps))
                pass_scales = Float64[norm > 0.0 ? inv(sqrt(norm)) : 1.0
                    for norm in row_norms]
                all(isfinite, pass_scales) || return (status=:numerical_fail,
                    reason=:nonfinite_kkt_equilibration, active=Tuple(active), steps=Tuple(steps))
                D = spdiagm(0 => pass_scales)
                equilibrated_K = sparse(D * equilibrated_K * D)
                equilibrated_rhs = pass_scales .* equilibrated_rhs
                row_scales .*= pass_scales
                ruiz_pass_count = ruiz_pass
                all(isfinite, row_scales) && all(isfinite, nonzeros(equilibrated_K)) &&
                    all(isfinite, equilibrated_rhs) ||
                    return (status=:numerical_fail, reason=:nonfinite_kkt_equilibration,
                        active=Tuple(active), steps=Tuple(steps))
                balanced_row_norms = vec(sum(abs, equilibrated_K; dims=2))
                all(isfinite, balanced_row_norms) || return (status=:numerical_fail,
                    reason=:nonfinite_kkt_row_norm, active=Tuple(active), steps=Tuple(steps))
                nonzero_row_norms = filter(>(0.0), balanced_row_norms)
                isempty(nonzero_row_norms) && break
                norm_ratio = maximum(nonzero_row_norms) / minimum(nonzero_row_norms)
                isfinite(norm_ratio) || return (status=:numerical_fail,
                    reason=:nonfinite_kkt_row_norm_ratio, active=Tuple(active),
                    steps=Tuple(steps),
                    detail=(maximum_nonzero_row_norm=maximum(nonzero_row_norms),
                        minimum_nonzero_row_norm=minimum(nonzero_row_norms)))
                ruiz_final_norm_ratio = norm_ratio
                norm_ratio <= _KKT_RUIZ_TARGET_ROW_NORM_RATIO && break
            end
            hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                return (status=:resource_interruption, reason=:wall_time_budget,
                    active=Tuple(active), steps=Tuple(steps))
            F = qr(equilibrated_K)
            hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                return (status=:resource_interruption, reason=:wall_time_budget,
                    active=Tuple(active), steps=Tuple(steps))
            diagonal = abs.(diag(F.R))
            all(isfinite, diagonal) || return (status=:numerical_fail,
                reason=:nonfinite_kkt_qr_diagonal, active=Tuple(active),
                steps=Tuple(steps),
                detail=(diagonal_count=length(diagonal),
                    nonfinite_count=count(value -> !isfinite(value), diagonal)))
            rank_threshold = _kkt_rank_threshold(diagonal, size(K))
            isfinite(rank_threshold) || return (status=:numerical_fail,
                reason=:nonfinite_kkt_rank_threshold, active=Tuple(active),
                steps=Tuple(steps))
            rank_estimate = count(>(rank_threshold), diagonal)
            rank_snapshot = (rank_estimate=rank_estimate,
                columns=size(K, 2), relative_threshold=rank_threshold,
                method=:sparse_qr_R_diagonal,
                kkt_equilibration_passes=ruiz_pass_count,
                kkt_equilibrated_row_norm_ratio=ruiz_final_norm_ratio)
            z = nothing
            if rank_estimate < size(K, 2) && size(C, 1) == 0
                # Bound-only primal LS can be consistent with a nonunique
                # minimizer. No dense rank audit or larger audit cap is needed.
                minimum_norm = _kkt_bound_only_minimum_norm(J, f, x, active, policy)
                if minimum_norm.status !== :ok
                    rank_snapshot = merge(rank_snapshot,
                        (fallback_status=minimum_norm.status,
                         fallback_reason=minimum_norm.reason,
                         fallback_order=size(K, 1),
                         fallback_method=:bound_only_sparse_minimum_norm_qr))
                    push!(steps, (active_bounds=Tuple(active), kkt_rank=rank_snapshot))
                    return (status=minimum_norm.status, reason=minimum_norm.reason,
                        active=Tuple(active), steps=Tuple(steps),
                        detail=get(minimum_norm, :detail, nothing))
                end
                rank_snapshot = merge(minimum_norm.rank_snapshot,
                    (sparse_qr_rank_estimate=rank_estimate,
                     sparse_qr_relative_threshold=rank_threshold,
                     kkt_equilibration_passes=ruiz_pass_count,
                     kkt_equilibrated_row_norm_ratio=ruiz_final_norm_ratio,
                     fallback_status=:used))
                z = minimum_norm.z
            elseif rank_estimate < size(K, 2)
                fallback_budget = _kkt_rank_fallback_budget(K, policy)
                if !fallback_budget.allowed
                    rank_snapshot = merge(rank_snapshot,
                        (fallback_status=:not_attempted,
                         fallback_reason=fallback_budget.reason,
                         fallback_order=fallback_budget.order,
                         fallback_peak_memory_bytes=fallback_budget.estimated_peak_bytes,
                         fallback_available_memory_bytes=fallback_budget.available_memory_bytes,
                         fallback_remaining_ns=fallback_budget.remaining_ns))
                    failure_step = hasproperty(policy, :compact_trace) && policy.compact_trace ?
                        (active_bounds=Tuple(active), kkt_rank=rank_snapshot) :
                        (active_bounds=Tuple(active), matrix=_matrix_snapshot(K),
                         rhs=Tuple(rhs), kkt_rank=rank_snapshot)
                    push!(steps, failure_step)
                    if fallback_budget.reason in (:insufficient_wall_budget,
                            :insufficient_memory_budget)
                        return (status=:resource_interruption,
                            reason=fallback_budget.reason, active=Tuple(active),
                            steps=Tuple(steps),
                            detail=(fallback_order=fallback_budget.order,
                                estimated_peak_bytes=fallback_budget.estimated_peak_bytes,
                                available_memory_bytes=fallback_budget.available_memory_bytes,
                                remaining_ns=fallback_budget.remaining_ns))
                    end
                    return (status=:numerical_fail,
                        reason=:rank_verification_capability_gap,
                        active=Tuple(active), steps=Tuple(steps),
                        kkt_rank=rank_snapshot)
                end
                fallback_result = try
                    _kkt_square_root_qr_solution(J, f, Ca, ca, K, policy)
                catch err
                    if err isa OutOfMemoryError
                        (status=:resource_interruption,
                         reason=:kkt_square_root_qr_out_of_memory,
                         error=sprint(showerror, err))
                    else
                        rethrow()
                    end
                end
                if fallback_result.status !== :ok
                    rank_snapshot = merge(rank_snapshot,
                        (fallback_status=fallback_result.status,
                         fallback_reason=fallback_result.reason,
                         fallback_order=fallback_budget.order,
                         fallback_peak_memory_bytes=fallback_budget.estimated_peak_bytes,
                         fallback_available_memory_bytes=fallback_budget.available_memory_bytes,
                         fallback_remaining_ns=fallback_budget.remaining_ns,
                         fallback_detail=get(fallback_result, :detail, nothing),
                         fallback_method=:constraint_nullspace_pivoted_qr))
                    failure_step = hasproperty(policy, :compact_trace) && policy.compact_trace ?
                        (active_bounds=Tuple(active), kkt_rank=rank_snapshot) :
                        (active_bounds=Tuple(active), matrix=_matrix_snapshot(K),
                         rhs=Tuple(rhs), kkt_rank=rank_snapshot)
                    push!(steps, failure_step)
                    return (status=fallback_result.status, reason=fallback_result.reason,
                        active=Tuple(active), steps=Tuple(steps),
                        detail=(fallback_order=fallback_budget.order,
                            estimated_peak_bytes=fallback_budget.estimated_peak_bytes,
                            available_memory_bytes=fallback_budget.available_memory_bytes,
                            remaining_ns=fallback_budget.remaining_ns,
                            fallback_detail=get(fallback_result, :detail, nothing)))
                end
                rank_snapshot = merge(fallback_result.rank_snapshot,
                    (sparse_qr_rank_estimate=rank_estimate,
                     sparse_qr_relative_threshold=rank_threshold,
                     kkt_equilibration_passes=ruiz_pass_count,
                     kkt_equilibrated_row_norm_ratio=ruiz_final_norm_ratio,
                     fallback_status=:used,
                     fallback_order=fallback_budget.order,
                     fallback_peak_memory_bytes=fallback_budget.estimated_peak_bytes,
                     fallback_available_memory_bytes=fallback_budget.available_memory_bytes,
                     fallback_remaining_ns=fallback_budget.remaining_ns))
                z = fallback_result.z
            end
            if z === nothing
                equilibrated_z = F \ equilibrated_rhs
                z = row_scales .* equilibrated_z
            end
            hasproperty(policy, :deadline_ns) && time_ns() >= policy.deadline_ns &&
                return (status=:resource_interruption, reason=:wall_time_budget,
                    active=Tuple(active), steps=Tuple(steps))
            all(isfinite, z) || return (status=:numerical_fail, reason=:nonfinite_kkt_solution,
                active=Tuple(active), steps=Tuple(steps))
            p = copy(z[1:n])
            lambda = z[(n + 1):(n + m)]
            mu = z[(n + m + 1):end]
            # Active pressure rows are exact KKT equalities: recover their RHS
            # directly after Ruiz-coordinate recovery, then audit that corrected
            # primal/multiplier vector against the original unscaled KKT system.
            p[active] .= -x[active]
            z[1:n] .= p
            kkt_defect = _maxabs(K * z - rhs)
            kkt_scale = max(1.0, _maxabs(rhs), opnorm(K, Inf) * _maxabs(z))
            rel_defect = kkt_defect / kkt_scale
            snap = hasproperty(policy, :compact_trace) && policy.compact_trace ?
                (active_bounds=Tuple(active), kkt_rank=rank_snapshot,
                 kkt_relative_defect=rel_defect) :
                (active_bounds=Tuple(active), matrix=_matrix_snapshot(K),
                 rhs=Tuple(rhs), solution=Tuple(z), kkt_rank=rank_snapshot,
                 kkt_relative_defect=rel_defect)
            push!(steps, snap)
            rel_defect <= policy.stationarity_tolerance ||
                return (status=:numerical_fail, reason=:kkt_linear_residual,
                    active=Tuple(active), steps=Tuple(steps))
            violating = collect(filter(i -> !(i in active) && x[i] + p[i] < 0.0,
                pressure_indices))
            if !isempty(violating)
                # Activate the most infeasible pressure coordinate; ties use global index.
                idx = first(sort(violating; by=i -> (x[i] + p[i], i)))
                push!(active, idx); sort!(active)
                continue
            end
            active_mu = isempty(active) ? Float64[] : mu[(size(C, 1) + 1):end]
            bad_dual = findall(v -> v > policy.bound_dual_tolerance, active_mu)
            if !isempty(bad_dual)
                release_pos = bad_dual[argmax(active_mu[bad_dual])]
                deleteat!(active, release_pos)
                continue
            end
            stationarity = _maxabs(transpose(J) * lambda + transpose(Ca) * mu)
            dual_violation = maximum((max(0.0, v) for v in active_mu); init=0.0)
            complementarity = maximum((abs((x[i] + p[i]) * (-active_mu[j]))
                for (j, i) in enumerate(active)); init=0.0)
            return (status=:ok, step=collect(p), equation_multipliers=collect(lambda),
                constraint_multipliers=collect(mu), active_bounds=Tuple(active),
                stationarity=stationarity, dual_violation=dual_violation,
                complementarity=complementarity, kkt_relative_defect=rel_defect,
                steps=Tuple(steps))
        catch err
            if err isa OutOfMemoryError
                return (status=:resource_interruption,
                    reason=:kkt_factorization_or_solve_out_of_memory,
                    error=sprint(showerror, err), active=Tuple(active), steps=Tuple(steps))
            end
            return (status=:numerical_fail, reason=:kkt_factorization_or_solve,
                error=sprint(showerror, err), active=Tuple(active), steps=Tuple(steps))
        end
    end
    (status=:numerical_fail, reason=:active_set_iteration_limit,
        active=Tuple(active), steps=Tuple(steps))
end

weighted_residual_kkt_step_identity_v1() = (
    schema="inhouse-weighted-residual-kkt-step-identity-v1",
    solver_semantic_hash=_solver_semantic_hash(),
    algorithm=:active_set_equality_KKT_weighted_least_squares,
    linear_solver=:bounded_matrix_free_restarted_gmres,
    gmres_restart_cap=_KKT_GMRES_RESTART_CAP,
    gmres_restart_rule=:min_cap_and_actual_kkt_order,
    gmres_iteration_limit=1000,
    gmres_stagnation_cycles=5,
    max_working_memory_bytes=3*1024^3,
    kkt_equilibration=:symmetric_diagonal_l1_row_norm,
    kkt_preconditioner=:right_hdiag_constraint_saddle_inverse,
    kkt_preconditioner_includes_active_bound_rows=true,
    kkt_preconditioner_no_jitter_or_diagonal_floor=true,
    kkt_preconditioner_schur_dimension_cap=1024,
    kkt_operator=:block_matrix_free_Jt_lambda_plus_Ct_mu_Jp_minus_lambda_Cp,
    original_kkt_residual_audit=true,
    rank_certificate=:not_established_by_krylov_residual,
    nonfinite_gmres_inputs_and_products=:explicit_numerical_failure,
    stagnation=:five_consecutive_restart_cycles_below_one_percent_progress,
    active_set_initialization=:strict_zero_pressure_coordinates,
    active_bound_coordinate_recovery=:exact_rhs_assignment,
    active_bound_equation=:column_scale_times_step_plus_state_equals_zero,
    active_bound_multiplier_stationarity=:column_scale_times_bound_multiplier,
    coordinates=:row_and_column_scaled,
    exact_equalities=:preserved_by_invertible_diagonal_row_scaling,
    pressure_bounds=:active_set_nonnegative_state_coordinates,
    rank_deficiency=:nonconvergence_stagnation_or_original_residual_failure,
    solver_working_set=:preflight_capped_before_matrix_free_krylov,
    line_search=:caller_owned)

function _matrix_free_kkt_product!(out, v, J, C, active, column_scales)
    n=size(J,2);m=size(J,1);k=size(C,1);q=length(active)
    length(v)==n+m+k+q && length(out)==length(v) ||
        throw(ArgumentError("matrix-free KKT vector dimensions differ"))
    fill!(out,0.0)
    p=@view v[1:n]
    lambda=@view v[(n+1):(n+m)]
    mu=@view v[(n+m+1):(n+m+k)]
    nu=@view v[(n+m+k+1):end]
    yp=@view out[1:n]
    yl=@view out[(n+1):(n+m)]
    yc=@view out[(n+m+1):(n+m+k)]
    mul!(yp,transpose(J),lambda)
    k>0 && mul!(yp,transpose(C),mu,1.0,1.0)
    for a in eachindex(active)
        yp[active[a]]+=column_scales[active[a]]*nu[a]
    end
    mul!(yl,J,p)
    yl .-= lambda
    k>0 && mul!(yc,C,p)
    for a in eachindex(active)
        out[n+m+k+a]=column_scales[active[a]]*p[active[a]]
    end
    all(isfinite,out) || throw(ArgumentError("matrix-free KKT product became nonfinite"))
    out
end

function _matrix_free_kkt_block_defect(J,f,C,c,p,lambda,mu,active,x,column_scales)
    n=size(J,2);k=size(C,1)
    jt_lambda=transpose(J)*lambda
    ct_mu=k==0 ? zeros(Float64,n) : transpose(C)*mu[1:k]
    nu=isempty(active) ? zeros(Float64,n) : zeros(Float64,n)
    for (a,i) in enumerate(active)
        nu[i]=column_scales[i]*mu[k+a]
    end
    stationarity=jt_lambda.+ct_mu.+nu
    jp=J*p
    equilibrium=jp.-lambda.+f
    cp=k==0 ? Float64[] : C*p
    equality=cp.+c
    physical_step=column_scales.*p
    bound=isempty(active) ? Float64[] : physical_step[active].+x[active]
    stationarity_relative=_maxabs(stationarity)/max(1.0,
        _maxabs(jt_lambda),_maxabs(ct_mu),_maxabs(nu))
    equilibrium_relative=_maxabs(equilibrium)/max(1.0,
        _maxabs(jp),_maxabs(lambda),_maxabs(f))
    equality_relative=_maxabs(equality)/max(1.0,_maxabs(cp),_maxabs(c))
    bound_relative=_maxabs(bound)/max(1.0,_maxabs(physical_step[active]),_maxabs(x[active]))
    blocks=(stationarity=stationarity_relative,equilibrium=equilibrium_relative,
        equality=equality_relative,active_bounds=bound_relative)
    all(isfinite,values(blocks)) || return (status=:numerical_fail,
        reason=:nonfinite_kkt_block_residual,blocks=blocks)
    (status=:ok,relative_defect=maximum(values(blocks)),blocks=blocks,
        stationarity=stationarity)
end

const _KKT_DIAG_SCHUR_MAX_DIM=1024

function _kkt_diag_schur_pair_update_estimate(C,active)
    n=size(C,2);length(unique(active))==length(active) ||
        throw(ArgumentError("active KKT rows must be unique"))
    updates=Int128(0);a=1
    for j in 1:n
        d=Int128(C.colptr[j+1]-C.colptr[j])
        has_active=a<=length(active) && active[a]==j
        updates+=d*d
        if has_active
            updates+=2d+1
            a+=1
        end
    end
    a==length(active)+1 || throw(ArgumentError("active KKT rows must be sorted and in range"))
    updates
end

function _build_matrix_free_kkt_preconditioner(J,C,active,column_scales;deadline_ns=typemax(Int64))
    n=size(J,2);m=size(J,1);k=size(C,1);q=length(active);l=k+q
    started=time_ns()
    l<=_KKT_DIAG_SCHUR_MAX_DIM || return (status=:resource_interruption,
        reason=:kkt_preconditioner_schur_dimension_cap,schur_dimension=l,
        max_schur_dimension=_KKT_DIAG_SCHUR_MAX_DIM,setup_seconds=0.0)
    length(column_scales)==n && size(C,2)==n || throw(ArgumentError("KKT preconditioner dimensions differ"))
    issorted(active) && length(unique(active))==q && all(i->1<=i<=n,active) ||
        throw(ArgumentError("active KKT rows must be sorted, unique, and in range"))
    pair_updates=_kkt_diag_schur_pair_update_estimate(C,active)
    hdiag=zeros(Float64,n);jnz=nonzeros(J)
    for j in 1:n
        time_ns()>=deadline_ns && return (status=:resource_interruption,
            reason=:wall_time_budget,schur_dimension=l,schur_pair_updates=pair_updates,
            setup_seconds=Float64(time_ns()-started)/1.0e9)
        acc=0.0
        for p in nzrange(J,j)
            v=jnz[p];acc=muladd(v,v,acc)
        end
        isfinite(acc)&&acc>0.0 || return (status=:numerical_fail,
            reason=:kkt_preconditioner_nonpositive_hdiag,column=j,hdiag_value=acc,
            schur_dimension=l,schur_pair_updates=pair_updates,
            setup_seconds=Float64(time_ns()-started)/1.0e9)
        hdiag[j]=acc
    end
    S=zeros(Float64,l,l);cnz=nonzeros(C);crows=rowvals(C);active_pos=1
    for j in 1:n
        time_ns()>=deadline_ns && return (status=:resource_interruption,
            reason=:wall_time_budget,schur_dimension=l,schur_pair_updates=pair_updates,
            setup_seconds=Float64(time_ns()-started)/1.0e9)
        invh=inv(hdiag[j]);lo=first(nzrange(C,j));hi=last(nzrange(C,j))
        has_active=active_pos<=q && active[active_pos]==j
        b_row=has_active ? k+active_pos : 0
        b_value=has_active ? column_scales[j] : 0.0
        if lo<=hi
            for p in lo:hi
                ri=crows[p];vi=cnz[p]
                for r in lo:hi
                    rj=crows[r]
                    S[ri,rj]=muladd(vi,cnz[r]*invh,S[ri,rj])
                end
                if has_active
                    cross=vi*b_value*invh
                    S[ri,b_row]+=cross;S[b_row,ri]+=cross
                end
            end
        end
        if has_active
            S[b_row,b_row]=muladd(b_value,b_value*invh,S[b_row,b_row])
            active_pos+=1
        end
    end
    active_pos==q+1 || throw(ArgumentError("active KKT row map was not fully consumed"))
    all(isfinite,S) || return (status=:numerical_fail,
        reason=:kkt_preconditioner_nonfinite_schur,schur_dimension=l,
        schur_pair_updates=pair_updates,setup_seconds=Float64(time_ns()-started)/1.0e9)
    time_ns()>=deadline_ns && return (status=:resource_interruption,
        reason=:wall_time_budget,schur_dimension=l,schur_pair_updates=pair_updates,
        setup_seconds=Float64(time_ns()-started)/1.0e9)
    spectrum=if l==0
        (rank_estimate=0,rank_threshold=0.0,minimum_eigenvalue=Inf,
            maximum_eigenvalue=0.0,negative_outlier_count=0)
    else
        eigenvalues=try
            eigvals(Symmetric(S))
        catch err
            return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
                reason=err isa OutOfMemoryError ? :kkt_preconditioner_schur_spectrum_out_of_memory :
                    :kkt_preconditioner_schur_spectrum_failed,
                detail=sprint(showerror,err),schur_dimension=l,schur_pair_updates=pair_updates,
                setup_seconds=Float64(time_ns()-started)/1.0e9)
        end
        all(isfinite,eigenvalues) || return (status=:numerical_fail,
            reason=:kkt_preconditioner_schur_nonfinite_spectrum,schur_dimension=l,
            schur_pair_updates=pair_updates,setup_seconds=Float64(time_ns()-started)/1.0e9)
        singular_values=abs.(eigenvalues)
        # Match the existing KKT rank policy: eps * max_dimension * max(sigma_max, 1).
        rank_threshold=_kkt_rank_threshold(singular_values,size(S))
        positive_rank=count(v->v>rank_threshold,eigenvalues)
        negative_outliers=count(v->v < -rank_threshold,eigenvalues)
        if positive_rank<l || negative_outliers>0
            return (status=:numerical_fail,
                reason=negative_outliers>0 ? :kkt_preconditioner_schur_indefinite :
                    :kkt_preconditioner_schur_rank_deficient,
                schur_dimension=l,schur_rank_estimate=positive_rank,
                schur_rank_threshold=rank_threshold,
                schur_minimum_eigenvalue=minimum(eigenvalues),
                schur_maximum_eigenvalue=maximum(eigenvalues),
                negative_outlier_count=negative_outliers,schur_pair_updates=pair_updates,
                setup_seconds=Float64(time_ns()-started)/1.0e9)
        end
        (rank_estimate=positive_rank,rank_threshold=rank_threshold,
            minimum_eigenvalue=minimum(eigenvalues),maximum_eigenvalue=maximum(eigenvalues),
            negative_outlier_count=negative_outliers)
    end
    time_ns()>=deadline_ns && return (status=:resource_interruption,
        reason=:wall_time_budget,schur_dimension=l,schur_pair_updates=pair_updates,
        setup_seconds=Float64(time_ns()-started)/1.0e9)
    factor=if l==0
        nothing
    else
        try
            cholesky(Symmetric(S);check=true)
        catch err
            return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
                reason=err isa OutOfMemoryError ? :kkt_preconditioner_schur_out_of_memory :
                    :kkt_preconditioner_schur_factorization_failed,
                detail=sprint(showerror,err),schur_dimension=l,schur_pair_updates=pair_updates,
                schur_rank_estimate=spectrum.rank_estimate,
                schur_rank_threshold=spectrum.rank_threshold,
                setup_seconds=Float64(time_ns()-started)/1.0e9)
        end
    end
    time_ns()>=deadline_ns && return (status=:resource_interruption,
        reason=:wall_time_budget,schur_dimension=l,schur_pair_updates=pair_updates,
        setup_seconds=Float64(time_ns()-started)/1.0e9)
    (status=:ok,hdiag=hdiag,schur=S,schur_factor=factor,schur_dimension=l,
        schur_pair_updates=pair_updates,schur_dense_bytes=Int128(8)*Int128(l)*Int128(l),
        schur_rank_estimate=spectrum.rank_estimate,schur_rank_threshold=spectrum.rank_threshold,
        schur_minimum_eigenvalue=spectrum.minimum_eigenvalue,
        schur_maximum_eigenvalue=spectrum.maximum_eigenvalue,
        hdiag_minimum=minimum(hdiag),hdiag_maximum=maximum(hdiag),
        setup_seconds=Float64(time_ns()-started)/1.0e9)
end

function _solve_kkt_schur_cholesky!(rhs,factor)
    L=factor.L;n=length(rhs)
    size(L)==(n,n) || throw(ArgumentError("KKT Schur factor dimensions differ"))
    for i in 1:n
        value=rhs[i]
        for j in 1:(i-1)
            value-=L[i,j]*rhs[j]
        end
        rhs[i]=value/L[i,i]
    end
    for i in n:-1:1
        value=rhs[i]
        for j in (i+1):n
            value-=L[j,i]*rhs[j]
        end
        rhs[i]=value/L[i,i]
    end
    all(isfinite,rhs) || throw(ArgumentError("KKT Schur solve became nonfinite"))
    rhs
end

function _apply_matrix_free_kkt_constraint_saddle_inverse!(out,v,preconditioner,diagonal,
        J,C,active,column_scales,schur_work,primal_work)
    n=size(J,2);m=size(J,1);k=size(C,1);q=length(active);l=k+q;order=n+m+l
    length(out)==length(v)==order || throw(ArgumentError("right-preconditioner vector dimensions differ"))
    length(schur_work)==l || throw(ArgumentError("right-preconditioner Schur workspace differs"))
    length(primal_work)==n || throw(ArgumentError("right-preconditioner primal workspace differs"))
    hdiag=preconditioner.hdiag
    # First map the equilibrated input through D^-1. Keep the equation block
    # b in out until lambda=J*p-b has been formed.
    for j in 1:n
        d=diagonal[j]
        isfinite(d)&&d>0.0 || throw(ArgumentError("invalid right-preconditioner primal scaling"))
        out[j]=v[j]/d
    end
    for i in 1:m
        d=diagonal[n+i]
        isfinite(d)&&d>0.0 || throw(ArgumentError("invalid right-preconditioner equation scaling"))
        out[n+i]=v[n+i]/d
    end
    for i in 1:l
        d=diagonal[n+m+i]
        isfinite(d)&&d>0.0 || throw(ArgumentError("invalid right-preconditioner constraint scaling"))
        schur_work[i]=-v[n+m+i]/d
    end
    # Eliminate lambda from J*p-lambda=b, so r=a+J'*b.
    mul!(view(out,1:n),transpose(J),view(out,(n+1):(n+m)),1.0,1.0)
    for j in 1:n
        h=hdiag[j]
        isfinite(h)&&h>0.0 || throw(ArgumentError("invalid right-preconditioner hdiag"))
        out[j]/=h
    end
    primal_work .= view(out,1:n) # t=Hdiag^-1*r, retained for the correction
    k>0 && mul!(view(schur_work,1:k),C,primal_work,1.0,1.0)
    for a in 1:q
        schur_work[k+a]+=column_scales[active[a]]*primal_work[active[a]]
    end
    l>0 && _solve_kkt_schur_cholesky!(schur_work,preconditioner.schur_factor)
    # Replace the primal output with E'*mu, then apply p=t-Hdiag^-1*E'*mu.
    fill!(view(out,1:n),0.0)
    k>0 && mul!(view(out,1:n),transpose(C),view(schur_work,1:k))
    for a in 1:q
        i=active[a]
        out[i]+=column_scales[i]*schur_work[k+a]
    end
    for j in 1:n
        out[j]=primal_work[j]-out[j]/hdiag[j]
    end
    # Recover lambda and then apply the outer D^-1 to the whole inverse action.
    mul!(view(out,(n+1):(n+m)),J,view(out,1:n),1.0,-1.0)
    for i in 1:l
        out[n+m+i]=schur_work[i]
    end
    for i in 1:order
        d=diagonal[i]
        isfinite(d)&&d>0.0 || throw(ArgumentError("invalid right-preconditioner output scaling"))
        out[i]/=d
    end
    all(isfinite,out) || throw(ArgumentError("KKT right preconditioner produced nonfinite coordinates"))
    out
end

function _matrix_free_working_set_bytes(J,C,order;restart=min(_KKT_GMRES_RESTART_CAP,order),
        schur_dimension=size(C,1))
    # Include sparse operator copies, Arnoldi/operator vectors, Hdiag, and both
    # the dense small Schur matrix and its Cholesky factor. No normal J'J is formed.
    sparse_bytes=Int128(16)*(Int128(nnz(J))+Int128(nnz(C)))+
        Int128(8)*(Int128(size(J,2))+Int128(size(C,2))+2)
    vector_bytes=Int128(8)*Int128(order)*(Int128(restart)+40)
    schur=Int128(schur_dimension)
    # The second primal vector is the retained Hdiag^-1*r used during the
    # constraint-saddle correction; reserve it explicitly alongside hdiag.
    preconditioner_bytes=Int128(16)*Int128(size(J,2))+Int128(24)*schur*schur+
        Int128(8)*Int128(order)+Int128(8)*schur
    Int128(2)*sparse_bytes+vector_bytes+preconditioner_bytes
end

function _bounded_restarted_gmres(apply!, b; restart=min(_KKT_GMRES_RESTART_CAP,length(b)), max_iterations=1000,
        relative_tolerance=1.0e-8, stagnation_cycles=5, deadline_ns=typemax(Int64))
    n=length(b)
    restart isa Integer && restart>0 || throw(ArgumentError("GMRES restart must be positive"))
    max_iterations isa Integer && max_iterations>0 || throw(ArgumentError("GMRES iteration limit must be positive"))
    stagnation_cycles isa Integer && stagnation_cycles>0 || throw(ArgumentError("GMRES stagnation limit must be positive"))
    isfinite(relative_tolerance) && relative_tolerance>0.0 ||
        throw(ArgumentError("GMRES tolerance must be finite and positive"))
    all(isfinite,b) || return (status=:numerical_fail,reason=:nonfinite_gmres_rhs,
        iterations=0,restarts=0,residual_norm=Inf)
    history=NamedTuple[];history_stride=max(1,cld(max_iterations,32))
    record!(iteration,restart_index,phase,residual)=begin
        push!(history,(iteration=iteration,restart=restart_index,phase=phase,residual_norm=residual))
        length(history)>64 && deleteat!(history,9)
        nothing
    end
    with_history(result)=merge(result,(residual_history=Tuple(history),residual_history_capacity=64))
    x=zeros(Float64,n);b_norm=norm(b);target=relative_tolerance*max(b_norm,1.0)
    isfinite(target) || return (status=:numerical_fail,reason=:nonfinite_gmres_target,
        iterations=0,restarts=0,residual_norm=Inf,residual_history=(),residual_history_capacity=64)
    work=zeros(Float64,n);r=zeros(Float64,n);w=zeros(Float64,n)
    iterations=0;restarts=0;stagnant=0;previous=b_norm
    while iterations<max_iterations
        time_ns()>=deadline_ns && return with_history((status=:resource_interruption,
            reason=:wall_time_budget,iterations=iterations,restarts=restarts,
            residual_norm=previous,solution=x))
        apply!(work,x)
        r .= b .- work
        beta=norm(r)
        record!(iterations,restarts,:restart_true,beta)
        isfinite(beta) || return (status=:numerical_fail,reason=:nonfinite_gmres_residual,
            iterations=iterations,restarts=restarts,residual_norm=beta,solution=x,
            residual_history=Tuple(history),residual_history_capacity=64)
        beta<=target && return (status=:ok,solution=x,iterations=iterations,
            restarts=restarts,residual_norm=beta,relative_residual=beta/max(b_norm,1.0),
            residual_history=Tuple(history),residual_history_capacity=64)
        width=min(Int(restart),max_iterations-iterations)
        V=zeros(Float64,n,width+1);H=zeros(Float64,width+1,width)
        V[:,1].=r./beta
        g=zeros(Float64,width+1);g[1]=beta
        used=0;y=Float64[];estimate=beta
        for j in 1:width
            time_ns()>=deadline_ns && return (status=:resource_interruption,
                reason=:wall_time_budget,iterations=iterations,restarts=restarts,
                residual_norm=estimate,solution=x,residual_history=Tuple(history),
                residual_history_capacity=64)
            apply!(w,@view(V[:,j]))
            before=norm(w)
            isfinite(before) || return (status=:numerical_fail,
                reason=:nonfinite_gmres_operator,iterations=iterations,
                restarts=restarts,residual_norm=before,solution=x,residual_history=Tuple(history),
                residual_history_capacity=64)
            for i in 1:j
                H[i,j]=dot(@view(V[:,i]),w)
                w .-= H[i,j].*@view(V[:,i])
            end
            # One reorthogonalization pass limits loss of orthogonality in the
            # indefinite KKT Krylov space without increasing storage.
            for i in 1:j
                correction=dot(@view(V[:,i]),w)
                H[i,j]+=correction
                w .-= correction.*@view(V[:,i])
            end
            H[j+1,j]=norm(w)
            isfinite(H[j+1,j]) || return (status=:numerical_fail,
                reason=:nonfinite_gmres_hessenberg,iterations=iterations,
                restarts=restarts,residual_norm=H[j+1,j],solution=x,residual_history=Tuple(history),
                residual_history_capacity=64)
            if H[j+1,j]>eps(Float64)*max(before,1.0)
                V[:,j+1].=w./H[j+1,j]
            end
            Hj=@view H[1:(j+1),1:j]
            y=try
                Hj\(@view g[1:(j+1)])
            catch err
                return (status=:numerical_fail,reason=:gmres_projected_solve,
                    detail=sprint(showerror,err),iterations=iterations+j,
                    restarts=restarts,residual_norm=estimate,solution=x,residual_history=Tuple(history),
                    residual_history_capacity=64)
            end
            estimate=norm(@view(g[1:(j+1)])-Hj*y)
            (mod(iterations+1,history_stride)==0 || estimate<=target || H[j+1,j]<=eps(Float64)*max(before,1.0)) &&
                record!(iterations+1,restarts,:projected,estimate)
            isfinite(estimate) || return (status=:numerical_fail,
                reason=:nonfinite_gmres_projected_residual,iterations=iterations+j,
                restarts=restarts,residual_norm=estimate,solution=x,residual_history=Tuple(history),
                residual_history_capacity=64)
            used=j;iterations+=1
            (estimate<=target || H[j+1,j]<=eps(Float64)*max(before,1.0)) && break
        end
        used>0 || return (status=:numerical_fail,reason=:gmres_no_progress,
            iterations=iterations,restarts=restarts,residual_norm=estimate,solution=x,
            residual_history=Tuple(history),residual_history_capacity=64)
        x .+= @view(V[:,1:used])*y
        restarts+=1
        apply!(work,x);r .= b .- work
        true_norm=norm(r)
        record!(iterations,restarts,:restart_true,true_norm)
        isfinite(true_norm) || return (status=:numerical_fail,
            reason=:nonfinite_gmres_residual,iterations=iterations,
            restarts=restarts,residual_norm=true_norm,solution=x,
            residual_history=Tuple(history),residual_history_capacity=64)
        true_norm<=target && return (status=:ok,solution=x,iterations=iterations,
            restarts=restarts,residual_norm=true_norm,
            relative_residual=true_norm/max(b_norm,1.0),residual_history=Tuple(history),
            residual_history_capacity=64)
        if true_norm>=0.99*previous
            stagnant+=1
        else
            stagnant=0
        end
        stagnant>=stagnation_cycles && return (status=:numerical_fail,
            reason=:gmres_stagnation,iterations=iterations,restarts=restarts,
            residual_norm=true_norm,stagnant_cycles=stagnant,solution=x,
            residual_history=Tuple(history),residual_history_capacity=64)
        previous=true_norm
    end
    with_history((status=:numerical_fail,reason=:gmres_iteration_limit,iterations=iterations,
        restarts=restarts,residual_norm=previous,solution=x))
end

function _active_kkt_step_matrix_free(J,f,C,c,x,column_scales,pressure_indices,policy)
    n=size(J,2);m=size(J,1);k=size(C,1)
    active=sort!(Int[i for i in pressure_indices if iszero(x[i])])
    steps=NamedTuple[]
    for iteration in 1:policy.max_active_set_iterations
        hasproperty(policy,:deadline_ns) && time_ns()>=policy.deadline_ns &&
            return (status=:resource_interruption,reason=:wall_time_budget,
                active=Tuple(active),steps=Tuple(steps))
        q=length(active);order=n+m+k+q
        restart=min(policy.gmres_restart,order)
        schur_dimension=k+q
        if schur_dimension>_KKT_DIAG_SCHUR_MAX_DIM
            audit=(schur_dimension=schur_dimension,
                max_schur_dimension=_KKT_DIAG_SCHUR_MAX_DIM,scope=:kkt_preconditioner)
            push!(steps,(active_bounds=Tuple(active),linear_solve=merge(audit,
                (status=:resource_interruption,reason=:kkt_preconditioner_schur_dimension_cap))))
            return (status=:resource_interruption,reason=:kkt_preconditioner_schur_dimension_cap,
                active=Tuple(active),steps=Tuple(steps),detail=audit)
        end
        working_set_estimate=_matrix_free_working_set_bytes(J,C,order;restart=restart,
            schur_dimension=schur_dimension)
        if working_set_estimate>policy.max_working_memory_bytes
            audit=(estimated_working_set_bytes=working_set_estimate,
                max_working_memory_bytes=policy.max_working_memory_bytes,
                scope=:kkt_workspace)
            push!(steps,(active_bounds=Tuple(active),linear_solve=merge(audit,
                (status=:resource_interruption,reason=:matrix_free_working_set_cap))))
            return (status=:resource_interruption,reason=:matrix_free_working_set_cap,
                active=Tuple(active),steps=Tuple(steps),detail=audit,
                estimated_working_set_bytes=working_set_estimate,
                max_working_memory_bytes=policy.max_working_memory_bytes)
        end
        # K is symmetric. A symmetric diagonal L1 scaling is formed from its
        # sparse block row sums; products below apply D*K*D without building K.
        jrows=vec(sum(abs,J;dims=2));jcols=vec(sum(abs,J;dims=1))
        crows=k==0 ? Float64[] : vec(sum(abs,C;dims=2))
        ccols=k==0 ? zeros(Float64,n) : vec(sum(abs,C;dims=1))
        primal_norm=jcols.+ccols
        for i in active
            primal_norm[i]+=abs(column_scales[i])
        end
        row_norm=vcat(primal_norm,jrows.+1.0,crows,abs.(column_scales[active]))
        length(row_norm)==order && all(isfinite,row_norm) ||
            return (status=:numerical_fail,reason=:nonfinite_kkt_row_norm,
                active=Tuple(active),steps=Tuple(steps))
        diagonal=Float64[v>0.0 ? inv(sqrt(v)) : 1.0 for v in row_norm]
        all(v->isfinite(v)&&v>0.0,diagonal) || return (status=:numerical_fail,
            reason=:nonfinite_kkt_equilibration,active=Tuple(active),steps=Tuple(steps))
        rhs=vcat(zeros(Float64,n),-f,-c,-x[active])
        scaled_rhs=diagonal.*rhs
        block_range(lo,count)=count==0 ? (lo:(lo-1)) : (lo:(lo+count-1))
        rhs_ranges=(primal=block_range(1,n),least_squares=block_range(n+1,m),
            equality=block_range(n+m+1,k),active_bounds=block_range(n+m+k+1,q))
        block_stats(v,r)=begin
            values=view(v,r)
            (length=length(values),norm=norm(values),max_abs=maximum(abs,values;init=0.0))
        end
        equilibration_observation=(row_norm_min=minimum(row_norm;init=Inf),
            row_norm_max=maximum(row_norm;init=0.0),zero_row_count=count(iszero,row_norm),
            D_min=minimum(diagonal;init=Inf),D_max=maximum(diagonal;init=0.0),
            D_blocks=(primal=block_stats(diagonal,rhs_ranges.primal),least_squares=block_stats(diagonal,rhs_ranges.least_squares),
                equality=block_stats(diagonal,rhs_ranges.equality),active_bounds=block_stats(diagonal,rhs_ranges.active_bounds)),
            rhs_unscaled=(primal=block_stats(rhs,rhs_ranges.primal),least_squares=block_stats(rhs,rhs_ranges.least_squares),
                equality=block_stats(rhs,rhs_ranges.equality),active_bounds=block_stats(rhs,rhs_ranges.active_bounds)),
            rhs_scaled=(primal=block_stats(scaled_rhs,rhs_ranges.primal),least_squares=block_stats(scaled_rhs,rhs_ranges.least_squares),
                equality=block_stats(scaled_rhs,rhs_ranges.equality),active_bounds=block_stats(scaled_rhs,rhs_ranges.active_bounds)))
        preconditioner=try
            _build_matrix_free_kkt_preconditioner(J,C,active,column_scales;
                deadline_ns=hasproperty(policy,:deadline_ns) ? Int128(policy.deadline_ns) : typemax(Int64))
        catch err
            (status=err isa OutOfMemoryError ? :resource_interruption : :program_exception,
                reason=err isa OutOfMemoryError ? :kkt_preconditioner_out_of_memory :
                    :kkt_preconditioner_setup_exception,detail=sprint(showerror,err))
        end
        preconditioner.status===:ok || begin
            push!(steps,(active_bounds=Tuple(active),linear_solve=preconditioner))
            return (status=preconditioner.status,reason=preconditioner.reason,
                detail=get(preconditioner,:detail,nothing),active=Tuple(active),steps=Tuple(steps))
        end
        right_workspace=try
            (right_coordinate=zeros(Float64,order),schur_work=zeros(Float64,k+q),
                primal_work=zeros(Float64,n))
        catch err
            allocation=(status=err isa OutOfMemoryError ? :resource_interruption : :program_exception,
                reason=err isa OutOfMemoryError ? :kkt_preconditioner_workspace_out_of_memory :
                    :kkt_preconditioner_workspace_exception,detail=sprint(showerror,err),
                estimated_working_set_bytes=working_set_estimate)
            push!(steps,(active_bounds=Tuple(active),linear_solve=allocation))
            return (status=allocation.status,reason=allocation.reason,detail=allocation.detail,
                active=Tuple(active),steps=Tuple(steps))
        end
        right_coordinate=right_workspace.right_coordinate;schur_work=right_workspace.schur_work
        primal_work=right_workspace.primal_work
        unscaled_product=zeros(Float64,order);scaled_input=zeros(Float64,order)
        function scaled_product!(out,v)
            scaled_input .= diagonal.*v
            _matrix_free_kkt_product!(unscaled_product,scaled_input,J,C,active,column_scales)
            out .= diagonal.*unscaled_product
            all(isfinite,out) || throw(ArgumentError("scaled matrix-free KKT product is nonfinite"))
            out
        end
        function right_preconditioned_product!(out,v)
            _apply_matrix_free_kkt_constraint_saddle_inverse!(right_coordinate,v,preconditioner,
                diagonal,J,C,active,column_scales,schur_work,primal_work)
            scaled_product!(out,right_coordinate)
        end
        linear_tolerance=max(64eps(Float64),min(1.0e-8,policy.stationarity_tolerance*0.1))
        gmres=try
            _bounded_restarted_gmres(right_preconditioned_product!,scaled_rhs;restart=restart,
                max_iterations=policy.gmres_iteration_limit,relative_tolerance=linear_tolerance,
                stagnation_cycles=policy.gmres_stagnation_cycles,deadline_ns=hasproperty(policy,:deadline_ns) ?
                    Int128(policy.deadline_ns) : typemax(Int128))
        catch err
            (status=err isa OutOfMemoryError ? :resource_interruption :
                err isa ArgumentError ? :numerical_fail : :program_exception,
                reason=err isa OutOfMemoryError ? :matrix_free_kkt_out_of_memory : :matrix_free_kkt_operator,
                detail=sprint(showerror,err),iterations=0,restarts=0,residual_norm=Inf)
        end
        gmres.status===:ok || begin
            failure_blocks=if hasproperty(gmres,:solution) && length(gmres.solution)==order && all(isfinite,gmres.solution)
                _apply_matrix_free_kkt_constraint_saddle_inverse!(right_coordinate,gmres.solution,
                    preconditioner,diagonal,J,C,active,column_scales,schur_work,primal_work)
                z=diagonal.*right_coordinate
                checked=_matrix_free_kkt_block_defect(J,f,C,c,z[1:n],z[(n+1):(n+m)],
                    z[(n+m+1):(n+m+k+q)],active,x,column_scales)
                checked.status===:ok ? (status=:evaluated_approximate_iterate,
                    relative_defect=checked.relative_defect,blocks=checked.blocks) :
                    (status=:typed_absent,reason=checked.reason)
            else
                (status=:typed_absent,reason=:approximate_iterate_unavailable_or_nonfinite)
            end
            linear_observation=(status=gmres.status,reason=gmres.reason,detail=get(gmres,:detail,nothing),
                iterations=gmres.iterations,restarts=gmres.restarts,residual_norm=gmres.residual_norm,
                relative_residual=get(gmres,:relative_residual,nothing),
                residual_history=get(gmres,:residual_history,()),
                residual_history_capacity=get(gmres,:residual_history_capacity,64),
                residual_kind=:right_preconditioned_operator_true_row_residual,
                gmres_relative_tolerance=linear_tolerance,
                preconditioner=(kind=:hdiag_constraint_saddle_inverse,
                    schur_dimension=preconditioner.schur_dimension,
                    schur_pair_updates=preconditioner.schur_pair_updates,
                    schur_dense_bytes=preconditioner.schur_dense_bytes,
                    schur_rank_estimate=preconditioner.schur_rank_estimate,
                    schur_rank_threshold=preconditioner.schur_rank_threshold,
                    schur_minimum_eigenvalue=preconditioner.schur_minimum_eigenvalue,
                    hdiag_minimum=preconditioner.hdiag_minimum,hdiag_maximum=preconditioner.hdiag_maximum),
                equilibration=equilibration_observation,failure_block_defect=failure_blocks)
            push!(steps,(active_bounds=Tuple(active),linear_solve=linear_observation))
            return (status=gmres.status,reason=gmres.reason,detail=get(gmres,:detail,nothing),
                active=Tuple(active),steps=Tuple(steps))
        end
        _apply_matrix_free_kkt_constraint_saddle_inverse!(right_coordinate,gmres.solution,
            preconditioner,diagonal,J,C,active,column_scales,schur_work,primal_work)
        z=diagonal.*right_coordinate
        block_check=_matrix_free_kkt_block_defect(J,f,C,c,z[1:n],
            z[(n+1):(n+m)],z[(n+m+1):end],active,x,column_scales)
        block_check.status===:ok || return (status=:numerical_fail,
            reason=block_check.reason,active=Tuple(active),steps=Tuple(steps))
        relative_defect=block_check.relative_defect
        if get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1"
            println("G2_KKT_PRECONDITIONER_SETUP seconds=",preconditioner.setup_seconds)
            flush(stdout)
        end
        linear_summary=(status=gmres.status,iterations=gmres.iterations,
            restarts=gmres.restarts,residual_norm=gmres.residual_norm,
            relative_residual=gmres.relative_residual,
            estimated_working_set_bytes=working_set_estimate,
            max_working_memory_bytes=policy.max_working_memory_bytes,
            residual_history=gmres.residual_history,
            residual_history_capacity=gmres.residual_history_capacity,
            residual_kind=:right_preconditioned_operator_true_row_residual,
            gmres_relative_tolerance=linear_tolerance,
            preconditioner=(kind=:hdiag_constraint_saddle_inverse,
                schur_dimension=preconditioner.schur_dimension,
                schur_pair_updates=preconditioner.schur_pair_updates,
                schur_dense_bytes=preconditioner.schur_dense_bytes,
                schur_rank_estimate=preconditioner.schur_rank_estimate,
                schur_rank_threshold=preconditioner.schur_rank_threshold,
                schur_minimum_eigenvalue=preconditioner.schur_minimum_eigenvalue,
                hdiag_minimum=preconditioner.hdiag_minimum,hdiag_maximum=preconditioner.hdiag_maximum),
            equilibration=equilibration_observation)
        snap=(active_bounds=Tuple(active),linear_solve=linear_summary,
            kkt_relative_defect=relative_defect,linear_solver=:bounded_matrix_free_restarted_gmres)
        push!(steps,snap)
        relative_defect<=policy.stationarity_tolerance || return (status=:numerical_fail,
            reason=:kkt_linear_residual,active=Tuple(active),steps=Tuple(steps))
        p=copy(z[1:n]);lambda=z[(n+1):(n+m)];mu=z[(n+m+1):(n+m+k+q)]
        p[active].=-x[active]./column_scales[active]
        # Restore active coordinates exactly and audit the original KKT system.
        z[1:n].=p
        block_check=_matrix_free_kkt_block_defect(J,f,C,c,p,lambda,mu,active,x,column_scales)
        block_check.status===:ok || return (status=:numerical_fail,
            reason=block_check.reason,active=Tuple(active),steps=Tuple(steps))
        relative_defect=block_check.relative_defect
        relative_defect<=policy.stationarity_tolerance || return (status=:numerical_fail,
            reason=:kkt_linear_residual_after_bound_recovery,active=Tuple(active),steps=Tuple(steps))
        physical_step=column_scales.*p
        violating=collect(filter(i->!(i in active)&&x[i]+physical_step[i]<0.0,pressure_indices))
        if !isempty(violating)
            idx=first(sort(violating;by=i->(x[i]+physical_step[i],i)))
            push!(active,idx);sort!(active);continue
        end
        active_mu=isempty(active) ? Float64[] : mu[(k+1):end]
        bad_dual=findall(v->v>policy.bound_dual_tolerance,active_mu)
        if !isempty(bad_dual)
            release_pos=bad_dual[argmax(active_mu[bad_dual])]
            deleteat!(active,release_pos);continue
        end
        gradient=transpose(J)*lambda+transpose(C)*mu[1:k]
        for (a,i) in enumerate(active)
            gradient[i]+=column_scales[i]*mu[k+a]
        end
        stationarity=_maxabs(gradient)
        dual_violation=maximum((max(0.0,v) for v in active_mu);init=0.0)
        complementarity=maximum((abs((x[i]+physical_step[i])*(-active_mu[j]))
            for (j,i) in enumerate(active));init=0.0)
        isfinite(stationarity)&&isfinite(dual_violation)&&isfinite(complementarity) ||
            return (status=:numerical_fail,reason=:nonfinite_kkt_metrics,
                active=Tuple(active),steps=Tuple(steps))
        return (status=:ok,step=physical_step,equation_multipliers=lambda,
            constraint_multipliers=mu,active_bounds=Tuple(active),
            stationarity=stationarity,dual_violation=dual_violation,
            complementarity=complementarity,kkt_relative_defect=relative_defect,
            steps=Tuple(steps),rank_certificate=:not_established_matrix_free_krylov)
    end
    (status=:numerical_fail,reason=:active_set_iteration_limit,
        active=Tuple(active),steps=Tuple(steps))
end



# Owned implementation to be inserted in InHouseCoupledMHDGlobalSolveV1.
# Sparse LU is applied only to a native-grid band surrogate; every Krylov
# product and acceptance residual uses the complete captured G or G'.
struct GSNumericInverseFailureV1 <: Exception
    result::NamedTuple
end
Base.showerror(io::IO,e::GSNumericInverseFailureV1)=print(io,
    "GS inverse action failed closed: ",get(e.result,:reason,get(e.result,:status,:unknown)))

function _gs_native_band_factor_v1(G,gs_node_rz;radius_r::Int=1,radius_z::Int=2,
        max_factor_bytes::Int=512*1024^2)
    n=size(G,1)
    size(G,2)==n || return (status=:numerical_fail,reason=:gs_inverse_not_square)
    length(gs_node_rz)==n || return (status=:numerical_fail,reason=:gs_native_axis_map_missing,
        expected_nodes=n,provided_nodes=length(gs_node_rz))
    rz=NTuple{2,Int}[(Int(p[1]),Int(p[2])) for p in gs_node_rz]
    all(p->p[1]>0&&p[2]>0,rz)&&length(unique(rz))==n ||
        return (status=:numerical_fail,reason=:gs_native_axis_map_invalid)
    all(isfinite,nonzeros(G)) || return (status=:numerical_fail,reason=:gs_inverse_nonfinite_operator)
    kept=0;max_bandwidth=0
    full_row_sum=zeros(Float64,n);band_row_sum=zeros(Float64,n)
    full_column_sum=zeros(Float64,n);band_column_sum=zeros(Float64,n)
    for col in 1:n,ptr in nzrange(G,col)
        row=G.rowval[ptr]
        value=G.nzval[ptr]
        full_row_sum[row]+=value;full_column_sum[col]+=value
        if abs(rz[row][1]-rz[col][1])<=radius_r&&abs(rz[row][2]-rz[col][2])<=radius_z
            kept+=1;max_bandwidth=max(max_bandwidth,abs(row-col))
            band_row_sum[row]+=value;band_column_sum[col]+=value
        end
    end
    all(isfinite,full_row_sum)&&all(isfinite,band_row_sum)&&
        all(isfinite,full_column_sum)&&all(isfinite,band_column_sum) ||
        return (status=:numerical_fail,reason=:gs_band_row_column_sum_nonfinite)
    # Conservative band-envelope allocation bound for sparse LU fill, checked
    # before constructing the surrogate/factor. The selected order is retained.
    factor_bound=Int128(64)*n*(2*max_bandwidth+1)+Int128(64)*n
    factor_bound<=max_factor_bytes || return (status=:resource_interruption,
        reason=:gs_band_lu_memory_preflight,estimated_factor_bytes=factor_bound,
        max_factor_bytes=Int128(max_factor_bytes),pattern_nnz=kept,bandwidth=max_bandwidth)
    I=Int[];J=Int[];V=Float64[]
    sizehint!(I,kept);sizehint!(J,kept);sizehint!(V,kept)
    for col in 1:n,ptr in nzrange(G,col)
        row=G.rowval[ptr]
        if abs(rz[row][1]-rz[col][1])<=radius_r&&abs(rz[row][2]-rz[col][2])<=radius_z
            push!(I,row);push!(J,col);push!(V,G.nzval[ptr])
        end
    end
    S=sparse(I,J,V,n,n)
    all(isfinite,nonzeros(S)) || return (status=:numerical_fail,reason=:gs_band_surrogate_nonfinite)
    row_defect_before=full_row_sum-band_row_sum
    column_defect_before=full_column_sum-band_column_sum
    # Add the dropped full-G row sum to each surrogate diagonal. This preserves
    # the actual G action on the constant vector, including physical boundary
    # rows and reaction terms; it does not change the full-G Krylov operator.
    S+=spdiagm(0=>row_defect_before)
    all(isfinite,nonzeros(S)) || return (status=:numerical_fail,reason=:gs_row_sum_repaired_surrogate_nonfinite)
    repaired_row_sum=zeros(Float64,n);repaired_column_sum=zeros(Float64,n)
    for col in 1:n,ptr in nzrange(S,col)
        row=S.rowval[ptr];value=S.nzval[ptr]
        repaired_row_sum[row]+=value;repaired_column_sum[col]+=value
    end
    all(isfinite,repaired_row_sum)&&all(isfinite,repaired_column_sum) ||
        return (status=:numerical_fail,reason=:gs_row_sum_repaired_surrogate_sum_nonfinite)
    row_sum_defect=(before=(l2=norm(row_defect_before),max_abs=maximum(abs,row_defect_before;init=0.0)),
        after=(l2=norm(full_row_sum-repaired_row_sum),
            max_abs=maximum(abs,full_row_sum-repaired_row_sum;init=0.0)),
        diagonal_compensation=(l2=norm(row_defect_before),max_abs=maximum(abs,row_defect_before;init=0.0),
            corrected_rows=count(x->!iszero(x),row_defect_before)))
    column_sum_defect=(before=(l2=norm(column_defect_before),
            max_abs=maximum(abs,column_defect_before;init=0.0)),
        after=(l2=norm(full_column_sum-repaired_column_sum),
            max_abs=maximum(abs,full_column_sum-repaired_column_sum;init=0.0)))
    F=try
        lu(S;check=false)
    catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
            reason=err isa OutOfMemoryError ? :gs_band_lu_out_of_memory : :gs_band_lu_factorization,
            detail=sprint(showerror,err),pattern_nnz=nnz(S),bandwidth=max_bandwidth)
    end
    piv=abs.(diag(F.U));pmax=maximum(piv;init=0.0)
    all(isfinite,piv)&&minimum(piv;init=Inf)>eps(Float64)*max(size(S)...)*pmax ||
        return (status=:numerical_fail,reason=:gs_band_lu_pivot_gate,
            pattern_nnz=nnz(S),bandwidth=max_bandwidth,pivot_min=minimum(piv;init=Inf),pivot_max=pmax)
    (status=:ok,factor=F,pattern_nnz=nnz(S),band_entries=kept,bandwidth=max_bandwidth,
        estimated_factor_bytes=factor_bound,max_factor_bytes=Int128(max_factor_bytes),
        row_sum_defect=row_sum_defect,column_sum_defect=column_sum_defect,
        rank_certificate=:surrogate_only_not_G_rank,native_radius=(radius_r,radius_z))
end

"""Apply G^-1/G'^-1 using bounded restarted GMRES and the full G operator.

`gs_node_rz` is in exact pivot-column order from the existing producer
`psi_global_dof_ids` map. Sparse LU factors only a coordinate-band surrogate;
true full-operator residuals gate every RHS. This does not certify rank(G).
"""
function gs_native_band_inverse_v1(G,gs_node_rz,rhs;transpose_system::Bool=false,
        restart::Int=32,max_iterations::Int=512,max_refinements::Int=2,
        relative_tolerance::Float64=1e-10,radius_r::Int=1,radius_z::Int=2,
        max_auxiliary_bytes::Int=512*1024^2,deadline_ns::Int64=typemax(Int64),factorization=nothing)
    n=size(G,1);size(G,2)==n || return (status=:numerical_fail,reason=:gs_inverse_not_square)
    B=rhs isa AbstractVector ? reshape(Float64.(rhs),n,1) :
        rhs isa AbstractMatrix ? Matrix{Float64}(rhs) :
        return (status=:numerical_fail,reason=:gs_inverse_rhs_type)
    size(B,1)==n&&all(isfinite,B) || return (status=:numerical_fail,reason=:gs_inverse_rhs_invalid)
    restart>0&&max_iterations>0&&max_refinements>=0&&relative_tolerance>0&&isfinite(relative_tolerance) ||
        return (status=:program_exception,reason=:gs_inverse_policy_invalid)
    built=factorization===nothing ? _gs_native_band_factor_v1(G,gs_node_rz;
        radius_r=radius_r,radius_z=radius_z,max_factor_bytes=max_auxiliary_bytes) :
        merge((status=:ok,),factorization)
    built.status===:ok || return built
    F=built.factor;restart=min(restart,n)
    krylov_bytes=Int128(8)*n*(restart+16)+Int128(8)*(restart+1)*restart
    rhs_bytes=Int128(16)*n*size(B,2)
    aux=Int128(built.estimated_factor_bytes)+krylov_bytes+rhs_bytes
    aux<=max_auxiliary_bytes || return (status=:resource_interruption,
        reason=:gs_inverse_workspace_memory_cap,estimated_auxiliary_bytes=aux,
        max_auxiliary_bytes=Int128(max_auxiliary_bytes),pattern_nnz=built.pattern_nnz)
    X=zeros(Float64,n,size(B,2));reports=NamedTuple[]
    prec!(v)=transpose_system ? (F'\v) : (F\v)
    for col in axes(B,2)
        time_ns()>=deadline_ns && return (status=:resource_interruption,reason=:gs_inverse_wall_time,
            rhs_completed=col-1,solve_reports=Tuple(reports))
        b=@view B[:,col];x=zeros(Float64,n);base=norm(b);totalit=0;last=nothing
        isfinite(base) || return (status=:numerical_fail,reason=:gs_inverse_rhs_norm_nonfinite,rhs_column=col)
        for pass in 0:max_refinements
            r=pass==0 ? Vector(b) : Vector(b)-(transpose_system ? transpose(G)*x : G*x)
            pb=prec!(r)
            rhs_scale=norm(pb)
            isfinite(rhs_scale) || return (status=:numerical_fail,
                reason=:gs_inverse_preconditioned_rhs_nonfinite,rhs_column=col,refinement=pass)
            # The shared GMRES has an absolute floor for small right-hand sides.
            # Solve a unit RHS here, then restore its scale before testing G*x.
            # This preserves a relative correction even for tiny adjoint loads.
            normalized_rhs=iszero(rhs_scale) ? pb : pb./rhs_scale
            apply!(out,v)=(mul!(out,transpose_system ? transpose(G) : G,v);out)
            left!(out,v)=(apply!(out,v);out.=prec!(out);out)
            sol=_bounded_restarted_gmres(left!,normalized_rhs;restart=restart,max_iterations=max_iterations,
                relative_tolerance=relative_tolerance,deadline_ns=deadline_ns)
            last=sol;totalit+=get(sol,:iterations,0)
            if sol.status!==:ok
                delta=get(sol,:solution,nothing)
                trial=delta isa AbstractVector&&length(delta)==n&&all(isfinite,delta) ? x.+rhs_scale.*delta : nothing
                true_residual=trial===nothing ? nothing :
                    Vector(b)-(transpose_system ? transpose(G)*trial : G*trial)
                true_norm=true_residual===nothing ? Inf : norm(true_residual)
                true_relative=iszero(base) ? true_norm : true_norm/base
                return (status=sol.status,reason=get(sol,:reason,:gs_inverse_gmres_failed),
                    rhs_column=col,refinement=pass,gmres=sol,
                    preconditioned_rhs_norm=rhs_scale,
                    true_residual_available=true_residual!==nothing,
                    true_relative_residual=true_relative,true_residual_norm=true_norm,
                    pattern_nnz=built.pattern_nnz,row_sum_defect=built.row_sum_defect,
                    column_sum_defect=built.column_sum_defect,
                    rank_certificate=:not_established_for_G)
            end
            x .+= rhs_scale.*sol.solution
            tr=Vector(b)-(transpose_system ? transpose(G)*x : G*x)
            tr_norm=norm(tr)
            rel=iszero(base) ? tr_norm : tr_norm/base
            if isfinite(rel)&&rel<=relative_tolerance
                X[:,col].=x
                push!(reports,(rhs_column=col,iterations=totalit,refinements=pass,
                    true_relative_residual=rel,true_residual_norm=tr_norm,
                    rank_certificate=:not_established_for_G))
                break
            end
        end
        any(q->q.rhs_column==col,reports) || begin
            tr=Vector(b)-(transpose_system ? transpose(G)*x : G*x);tr_norm=norm(tr)
            rel=iszero(base) ? tr_norm : tr_norm/base
            return (status=:numerical_fail,reason=:gs_inverse_true_residual_gate,
                rhs_column=col,iterations=totalit,true_relative_residual=rel,
                true_residual_norm=tr_norm,last_gmres=last,pattern_nnz=built.pattern_nnz,
                rank_certificate=:not_established_for_G)
        end
    end
    solution=rhs isa AbstractVector ? vec(X) : X
    (status=:ok,solution=solution,transpose_system=transpose_system,rhs_count=size(B,2),
        solve_reports=Tuple(reports),pattern_nnz=built.pattern_nnz,bandwidth=built.bandwidth,
        estimated_auxiliary_bytes=aux,max_auxiliary_bytes=Int128(max_auxiliary_bytes),
        row_sum_defect=built.row_sum_defect,column_sum_defect=built.column_sum_defect,
        preconditioner_kind=get(built,:preconditioner_kind,:native_band_surrogate),
        rank_certificate=:not_established_for_full_G,full_global_kkt=false)
end

"""Compact state inputs for the native-grid FD3 surrogate; contains no captured matrices."""
struct ExactRowPivotGSFD3PayloadV1
    Raxis::Vector{Float64}
    Zaxis::Vector{Float64}
    native_ids::Vector{Int}
    mask::BitVector
    mu0::Float64
    Rscale::Float64
    span_columns::NTuple{2,Int}
    coefficient_columns::NTuple{2,Int}
    function ExactRowPivotGSFD3PayloadV1(Raxis,Zaxis,native_ids,mask,mu0,Rscale,
            span_columns,coefficient_columns)
        R=Float64.(collect(Raxis)); Z=Float64.(collect(Zaxis))
        ids=Int.(collect(native_ids)); active=BitVector(mask)
        length(R)>=2 && length(Z)>=2 && all(isfinite,R) && all(isfinite,Z) &&
            all(>(0.0),R) && all(diff(R).>0.0) && all(diff(Z).>0.0) ||
            throw(ArgumentError("FD3 axes must be finite, positive-R, and strictly increasing"))
        hR=R[2]-R[1]; hZ=Z[2]-Z[1]
        all(i->isapprox(R[i],R[1]+(i-1)*hR;rtol=0,atol=32eps(Float64)*max(1.0,abs(R[end]))),eachindex(R)) &&
            all(j->isapprox(Z[j],Z[1]+(j-1)*hZ;rtol=0,atol=32eps(Float64)*max(1.0,abs(Z[end]))),eachindex(Z)) ||
            throw(ArgumentError("FD3 surrogate requires uniform native axes"))
        nr=length(R); nz=length(Z); n=nr*nz
        length(active)==n && !isempty(ids) && length(unique(ids))==length(ids) &&
            all(k->1<=k<=n,ids) || throw(ArgumentError("FD3 mask/native IDs do not match grid"))
        isfinite(mu0) && mu0>0 && isfinite(Rscale) && Rscale>0 ||
            throw(ArgumentError("FD3 physical scales must be finite and positive"))
        span=Tuple(Int.(collect(span_columns))); coeff=Tuple(Int.(collect(coefficient_columns)))
        length(span)==2 && length(coeff)==2 || throw(ArgumentError("FD3 span/coefficient maps must be pairs"))
        new(R,Z,ids,active,Float64(mu0),Float64(Rscale),(span[1],span[2]),(coeff[1],coeff[2]))
    end
end

"""Numeric row/column map for the diagnostic exact row-pivot KKT backend.

All vectors are indices into the already ordered weighted partition or state.
The map carries no factors, closures, residuals, or solver identity.
"""
struct ExactRowPivotKKTMapV1
    schema::String
    row_groups::NTuple{5,Vector{Int}}
    column_groups::NTuple{5,Vector{Int}}
    free_columns::Vector{Int}
    pressure_indices::Vector{Int}
    ordered_LS_ids::Vector{String}
    ordered_EQ_ids::Vector{String}
    gs_native_rz::Union{Nothing,Vector{NTuple{2,Int}}}
    gs_fd3_payload::Union{Nothing,ExactRowPivotGSFD3PayloadV1}
    function ExactRowPivotKKTMapV1(row_groups,column_groups,free_columns,
            pressure_indices,ordered_LS_ids,ordered_EQ_ids;gs_native_rz=nothing,gs_fd3_payload=nothing)
        length(row_groups)==5 && length(column_groups)==5 ||
            throw(ArgumentError("exact row-pivot map requires five ordered row/column groups"))
        rows=ntuple(i->Int.(collect(row_groups[i])),5)
        cols=ntuple(i->Int.(collect(column_groups[i])),5)
        free=Int.(collect(free_columns)); pressure=Int.(collect(pressure_indices))
        lsids=String.(collect(ordered_LS_ids)); eqids=String.(collect(ordered_EQ_ids))
        rz=gs_native_rz===nothing ? nothing : NTuple{2,Int}[(Int(p[1]),Int(p[2])) for p in gs_native_rz]
        rz===nothing || (length(rz)==length(cols[2]) && all(p->p[1]>0&&p[2]>0,rz) && length(unique(rz))==length(rz)) ||
            throw(ArgumentError("GS native R/Z map must uniquely cover pivot-column order"))
        gs_fd3_payload===nothing || gs_fd3_payload isa ExactRowPivotGSFD3PayloadV1 ||
            throw(ArgumentError("GS FD3 payload has an unsupported type"))
        gs_fd3_payload===nothing || rz!==nothing ||
            throw(ArgumentError("GS FD3 payload requires native R/Z coordinates"))
        all(x->!isempty(x),lsids) && all(x->!isempty(x),eqids) ||
            throw(ArgumentError("exact row-pivot map row IDs must be nonempty"))
        new("exact-row-pivot-kkt-map-v1",rows,cols,free,pressure,lsids,eqids,rz,gs_fd3_payload)
    end
end

function _gs_native_fd3_factor_v1(G,rz,payload,state,row_scales,column_scales,max_factor_bytes)
    nr=length(payload.Raxis); nz=length(payload.Zaxis); n=size(G,1)
    size(G)==(n,n) && length(rz)==n && length(payload.native_ids)==n ||
        return (status=:numerical_fail,reason=:fd3_grid_G_shape_mismatch)
    ids=payload.native_ids
    expected_rz=NTuple{2,Int}[(div(k-1,nz)+1,mod1(k,nz)) for k in ids]
    rz==expected_rz && all(p->1<=p[1]<=nr && 1<=p[2]<=nz,rz) ||
        return (status=:numerical_fail,reason=:fd3_native_axis_order_mismatch)
    length(row_scales)==n && length(column_scales)==n && all(isfinite,row_scales) &&
        all(isfinite,column_scales) && all(>(0.0),row_scales) && all(>(0.0),column_scales) ||
        return (status=:numerical_fail,reason=:fd3_scaled_G_scale_shape_or_value_mismatch)
    all(k->1<=k<=length(state),4 .* ids) && all(k->1<=k<=length(state),payload.span_columns) &&
        all(k->1<=k<=length(state),payload.coefficient_columns) ||
        return (status=:numerical_fail,reason=:fd3_state_coordinate_out_of_range)
    delta=Float64(state[payload.span_columns[1]]-state[payload.span_columns[2]])
    isfinite(delta) && !iszero(delta) || return (status=:numerical_fail,reason=:fd3_profile_span_invalid)
    u=Float64(state[payload.coefficient_columns[1]]); v=Float64(state[payload.coefficient_columns[2]])
    all(isfinite,(u,v)) || return (status=:numerical_fail,reason=:fd3_profile_coefficient_nonfinite)
    hR=payload.Raxis[2]-payload.Raxis[1]; hZ=payload.Zaxis[2]-payload.Zaxis[1]
    node_to_col=Dict(k=>i for (i,k) in enumerate(ids))
    bandwidth=0
    for (row,k) in enumerate(ids)
        ir=div(k-1,nz)+1; iz=mod1(k,nz)
        for neighbor in ((ir<nr ? ir*nz+iz : 0),(ir>1 ? (ir-2)*nz+iz : 0),
                (iz<nz ? (ir-1)*nz+iz+1 : 0),(iz>1 ? (ir-1)*nz+iz-1 : 0))
            col=get(node_to_col,neighbor,0); col==0 || (bandwidth=max(bandwidth,abs(row-col)))
        end
    end
    factor_bound=Int128(64)*n*(2bandwidth+1)+Int128(64)*n
    factor_bound<=max_factor_bytes || return (status=:resource_interruption,reason=:fd3_lu_memory_preflight,
        estimated_factor_bytes=factor_bound,max_factor_bytes=Int128(max_factor_bytes),bandwidth=bandwidth)
    I=Int[]; J=Int[]; V=Float64[]
    sizehint!(I,5n); sizehint!(J,5n); sizehint!(V,5n)
    for (row,k) in enumerate(ids)
        ir=div(k-1,nz)+1; iz=mod1(k,nz); radius=payload.Raxis[ir]
        coeff=u*radius/payload.Rscale+v*payload.Rscale/radius
        qdiag=payload.mask[k] ? payload.mu0*radius*2coeff*(state[4k]-state[payload.span_columns[2]])/(delta^2) : 0.0
        all(isfinite,(radius,coeff,qdiag)) && radius>0 || return (status=:numerical_fail,reason=:fd3_reaction_nonfinite)
        push!(I,row); push!(J,row); push!(V,-2/hR^2-2/hZ^2+qdiag)
        for (neighbor,value) in (((ir<nr ? ir*nz+iz : 0),1/hR^2-1/(2radius*hR)),
                ((ir>1 ? (ir-2)*nz+iz : 0),1/hR^2+1/(2radius*hR)),
                ((iz<nz ? (ir-1)*nz+iz+1 : 0),1/hZ^2),
                ((iz>1 ? (ir-1)*nz+iz-1 : 0),1/hZ^2))
            col=get(node_to_col,neighbor,0); col==0 || (push!(I,row);push!(J,col);push!(V,value))
        end
    end
    Mraw=sparse(I,J,V,n,n)
    M=spdiagm(0=>1.0 ./ row_scales)*Mraw*spdiagm(0=>column_scales)
    all(isfinite,nonzeros(M)) || return (status=:numerical_fail,reason=:fd3_scaled_surrogate_nonfinite)
    fac=try lu(M;check=false) catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
            reason=err isa OutOfMemoryError ? :fd3_lu_out_of_memory : :fd3_lu_factorization,
            detail=sprint(showerror,err),pattern_nnz=nnz(M),bandwidth=bandwidth)
    end
    piv=abs.(diag(fac.U)); pmax=maximum(piv;init=0.0)
    all(isfinite,piv)&&minimum(piv;init=Inf)>eps(Float64)*max(size(M)...)*pmax ||
        return (status=:numerical_fail,reason=:fd3_lu_pivot_gate,pattern_nnz=nnz(M),bandwidth=bandwidth)
    gr=vec(sum(G,dims=2)); mr=vec(sum(M,dims=2)); gc=vec(sum(G,dims=1)); mc=vec(sum(M,dims=1))
    rd=(before=(l2=norm(gr-mr),max_abs=maximum(abs,gr-mr;init=0.0)),
        after=(l2=norm(gr-mr),max_abs=maximum(abs,gr-mr;init=0.0)),diagonal_compensation=:none)
    cd=(before=(l2=norm(gc-mc),max_abs=maximum(abs,gc-mc;init=0.0)),
        after=(l2=norm(gc-mc),max_abs=maximum(abs,gc-mc;init=0.0)))
    (status=:ok,factor=fac,pattern_nnz=nnz(M),bandwidth=bandwidth,estimated_factor_bytes=factor_bound,
        row_sum_defect=rd,column_sum_defect=cd,preconditioner_kind=:scaled_fd3_plus_exact_diagonal_reaction,
        rank_certificate=:preconditioner_only_not_G_rank)
end

"""Build the exact native-spline mixed realization of the captured scaled GS block.

The mixed unknown is `(psi, P_R, P_Z)`, with full-grid spline slopes.  Its two
auxiliary blocks are the primary not-a-knot systems `L_R P_R = C_R psi` and
`L_Z P_Z = C_Z psi`; the first block uses the native Hermite-knot Hessian
formula and the captured local diagonal reaction recovered from scaled `G`.
Only the compact mixed matrix is factored.  The saved `G` object remains the
reference for every inverse-action residual check.
"""
struct ExactSplineMixedFactorV1
    factorization::Any
    G_reference::SparseMatrixCSC{Float64,Int}
    shape::Tuple{Int,Int}
    mixed_dimension::Int
    nnz::Int
    rhs_capacity::Int
    native_ids::Vector{Int}
    report::NamedTuple
end

function _gs_mixed_nak_axis_v1(axis)
    x=Float64.(collect(axis));n=length(x);h=diff(x)
    4<=n<=257 && all(isfinite,x) && all(>(0.0),h) ||
        return (status=:numerical_fail,reason=:mixed_axis_invalid)
    L=zeros(Float64,n,n);C=zeros(Float64,n,n)
    for i in 2:n-1
        a,b=h[i-1],h[i]
        L[i,i-1]=b;L[i,i]=2(a+b);L[i,i+1]=a
        C[i,i-1]=-3b/a;C[i,i]=3(b/a-a/b);C[i,i+1]=3a/b
    end
    for (r,s) in ((1,1),(n,n-2))
        a,b=h[s],h[s+1]
        L[r,s]=1/a^2;L[r,s+1]=1/a^2-1/b^2;L[r,s+2]=-1/b^2
        C[r,s]=-2/a^3;C[r,s+1]=2/a^3+2/b^3;C[r,s+2]=-2/b^3
    end
    D=try L\C catch
        return (status=:numerical_fail,reason=:mixed_axis_nak_solve_failed)
    end
    all(isfinite,D) ? (status=:ok,L=L,C=C,D=D) :
        (status=:numerical_fail,reason=:mixed_axis_nak_nonfinite)
end

"""Stream the exact eliminated spline coefficients against the captured G.

This is a coefficient-consistency diagnostic only. It does not materialize the
Schur matrix or certify rank/conditioning of G.
"""
function _gs_native_exact_spline_mixed_consistency_v1(G,rz,payload,row_scales,column_scales,sr,sz)
    nr=length(payload.Raxis);nz=length(payload.Zaxis);n=size(G,1)
    R=Float64.(collect(payload.Raxis));Z=Float64.(collect(payload.Zaxis))
    rs=Float64.(collect(row_scales));cs=Float64.(collect(column_scales))
    hR=R[2]-R[1];hZ=Z[2]-Z[1]
    ids=Int.(collect(payload.native_ids));cmap=Dict(k=>q for (q,k) in enumerate(ids))
    # `D` is already the solved map L\C used by the eliminated equation
    # P=D*psi; multiplying by C again would be a different operator.
    HR=sr.D;HZ=sz.D
    # These small axis factors are diagnostic metadata, not rank certificates.
    axis_stats(L)=try
        F=lu(L;check=false);d=abs.(diag(F.U))
        (finite=all(isfinite,d),min_abs=minimum(d;init=Inf),max_abs=maximum(d;init=0.0))
    catch
        (finite=false,min_abs=NaN,max_abs=NaN)
    end
    axis_r=axis_stats(sr.L);axis_z=axis_stats(sz.L)
    all(isfinite,HR)&&all(isfinite,HZ)||return (status=:numerical_fail,reason=:mixed_eliminated_axis_coefficients_nonfinite)
    delta_max=0.0;delta_inf=0.0;off_support_max=0.0;support_mismatch_count=0
    row_error=Dict{Int,Float64}()
    # Each eliminated row couples only along the two native grid axes. Stream
    # those coefficients, reading G by sparse scalar lookup; absent G entries
    # are treated as zero. No n-by-n Schur or dense G is formed.
    expected_axis_support=(nr-2)+(nz-2)-1
    for (q,k) in enumerate(ids)
        i=div(k-1,nz)+1;j=mod1(k,nz);row_sum=0.0
        cols=Set{Int}()
        for m in 2:nr-1;push!(cols,cmap[(m-1)*nz+j]);end
        for ell in 2:nz-1;push!(cols,cmap[(i-1)*nz+ell]);end
        length(cols)==expected_axis_support||return (status=:numerical_fail,
            reason=:mixed_axis_support_intersection_mismatch,row=q,
            expected=expected_axis_support,actual=length(cols))
        for c in sort!(collect(cols))
            kc=ids[c];ii=div(kc-1,nz)+1;jj=mod1(kc,nz)
            raw=0.0
            if ii==i&&jj==j
                raw+=-6/hR^2-6/hZ^2
            elseif jj==j&&ii==i+1
                raw+=6/hR^2
            elseif ii==i&&jj==j+1
                raw+=6/hZ^2
            end
            raw+=( -4/hR-1/R[i])*HR[i,ii]+(-2/hR)*HR[i+1,ii]
            raw+=(-4/hZ)*HZ[j,jj]+(-2/hZ)*HZ[j+1,jj]
            modeled=raw*cs[c]/rs[q]
            actual=G[q,c]
            e=abs(actual-modeled);delta_max=max(delta_max,e);row_sum+=e
            iszero(e)||(support_mismatch_count+=1)
        end
        row_error[q]=row_sum
    end
    # Any actual nonzero outside the two native axis lines has modeled value 0.
    for c in 1:n,ptr in nzrange(G,c)
        q=G.rowval[ptr];k=ids[q];kc=ids[c]
        i=div(k-1,nz)+1;j=mod1(k,nz);ii=div(kc-1,nz)+1;jj=mod1(kc,nz)
        if ii!=i&&jj!=j
            e=abs(G.nzval[ptr]);delta_max=max(delta_max,e);off_support_max=max(off_support_max,e)
            row_error[q]=get(row_error,q,0.0)+e;support_mismatch_count+=1
        end
    end
    delta_inf=maximum(values(row_error);init=0.0)
    (status=:measured,schema=:actual_G_exact_spline_schur_coefficient_consistency_v1,
     scope=:coefficient_consistency_only,delta_inf=delta_inf,
     delta_inf_kind=:computed_float64_row_sum_not_a_rigorous_bound,
     max_abs_coefficient_difference=delta_max,
     max_abs_off_support_G=off_support_max,nonzero_difference_count=support_mismatch_count,
     support=(expected_axis_columns_per_row=expected_axis_support,
         duplicate_intersection_subtracted=1),
     axis_LU=(R=axis_r,Z=axis_z),axis_order=(R=nr,Z=nz),
     mapped_scales=(row=copy(rs),column=copy(cs),mapping=:native_G_row_and_column_scales_exact),
     rank_certificate=:not_established_for_G,conditioning_certificate=:not_established_for_G,
     dense_G_materialized=false,dense_schur_materialized=false)
end

function _gs_native_exact_spline_mixed_factor_v1(G,rz,payload,row_scales,column_scales,
        available_bytes;max_factor_bytes=available_bytes,verify_coefficient_consistency=false)
    G isa SparseMatrixCSC{Float64,Int} ||
        return (status=:unsupported,reason=:mixed_scaled_G_sparse_abi_unsupported)
    hasproperty(payload,:Raxis)&&hasproperty(payload,:Zaxis)&&hasproperty(payload,:native_ids) ||
        return (status=:unsupported,reason=:mixed_payload_missing_axes_or_native_ids)
    R=Float64.(collect(payload.Raxis));Z=Float64.(collect(payload.Zaxis));ids=Int.(collect(payload.native_ids))
    nr=length(R);nz=length(Z);N=nr*nz;n=length(ids);dim=n+2N
    size(G)==(n,n)&&length(rz)==n&&n==(nr-2)*(nz-2) ||
        return (status=:numerical_fail,reason=:mixed_grid_G_shape_mismatch)
    length(row_scales)==length(column_scales)==n ||
        return (status=:numerical_fail,reason=:mixed_scale_shape_mismatch)
    rs=Float64.(collect(row_scales));cs=Float64.(collect(column_scales))
    all(isfinite,rs)&&all(isfinite,cs)&&all(>(0.0),rs)&&all(>(0.0),cs)&&
        all(isfinite,nonzeros(G)) || return (status=:numerical_fail,reason=:mixed_G_or_scale_nonfinite)
    expected=NTuple{2,Int}[(div(k-1,nz)+1,mod1(k,nz)) for k in ids]
    expected==[(Int(p[1]),Int(p[2])) for p in rz]&&
        ids==Int[(i-1)*nz+j for i in 2:nr-1 for j in 2:nz-1] ||
        return (status=:numerical_fail,reason=:mixed_native_axis_order_mismatch)
    all(isfinite,R)&&all(isfinite,Z)&&all(>(0.0),R)&&all(diff(R).>0.0)&&all(diff(Z).>0.0) ||
        return (status=:numerical_fail,reason=:mixed_axes_invalid)
    sr=_gs_mixed_nak_axis_v1(R);sr.status===:ok||return sr
    sz=_gs_mixed_nak_axis_v1(Z);sz.status===:ok||return sz
    hR=R[2]-R[1];hZ=Z[2]-Z[1]
    all(i->isapprox(R[i],R[1]+(i-1)*hR;rtol=0,atol=32eps(Float64)*max(1.0,abs(R[end]))),eachindex(R))&&
        all(j->isapprox(Z[j],Z[1]+(j-1)*hZ;rtol=0,atol=32eps(Float64)*max(1.0,abs(Z[end]))),eachindex(Z)) ||
        return (status=:numerical_fail,reason=:mixed_uniform_axis_required)
    cmap=Dict(k=>q for (q,k) in enumerate(ids));qdiag=Vector{Float64}(undef,n);gd=diag(G)
    for (q,k) in enumerate(ids)
        i=div(k-1,nz)+1;j=mod1(k,nz)
        # Convert the scaled diagonal back to the source row equation before
        # removing the exact source Hessian diagonal.  This recovers Qdiag
        # without rebuilding or factoring standalone G.
        source_ks=-6/hR^2-4/hR*sr.D[i,i]-2/hR*sr.D[i+1,i]-sr.D[i,i]/R[i]-
            6/hZ^2-4/hZ*sz.D[j,j]-2/hZ*sz.D[j+1,j]
        qdiag[q]=gd[q]*rs[q]/cs[q]-source_ks
    end
    all(isfinite,qdiag)||return (status=:numerical_fail,reason=:mixed_reaction_diagonal_nonfinite)
    consistency=verify_coefficient_consistency ?
        _gs_native_exact_spline_mixed_consistency_v1(G,rz,payload,rs,cs,sr,sz) :
        (status=:not_requested,scope=:coefficient_consistency_only)
    consistency.status in (:measured,:not_requested)||return consistency

    # Preflight sparse staging against both caller headroom and the hard 4 GiB
    # process budget.  These bounds include the triplet staging arrays and the
    # CSC copy made by UmfpackLU, rather than applying the former fixed 512 MiB
    # factor cap.
    triplet_bound=Int128(7n+12N)
    assembly_bytes=triplet_bound*Int128(3*sizeof(Int))+Int128(sizeof(Int))*Int128(dim+1)+
        triplet_bound*Int128(sizeof(Int)+sizeof(Float64))
    avail=Int128(available_bytes);factor_cap=Int128(max_factor_bytes)
    avail>=0&&factor_cap>=0||return (status=:resource_interruption,reason=:mixed_memory_budget_invalid,
        available_bytes=avail,max_factor_bytes=factor_cap)
    assembly_bytes<=avail&&assembly_bytes<=factor_cap || return (status=:resource_interruption,
        reason=:mixed_assembly_memory_preflight,estimated_assembly_bytes=assembly_bytes,
        available_bytes=avail,max_factor_bytes=factor_cap)

    I=Int[];J=Int[];V=Float64[]
    sizehint!(I,Int(triplet_bound));sizehint!(J,Int(triplet_bound));sizehint!(V,Int(triplet_bound))
    add!(r,c,v)=(iszero(v)||(push!(I,r);push!(J,c);push!(V,Float64(v)));nothing)
    poR=n;poZ=n+N
    for (q,k) in enumerate(ids)
        i=div(k-1,nz)+1;j=mod1(k,nz);rf=1/rs[q];kr=k+nz;kz=k+1
        add!(q,cmap[k],rf*cs[q]*(qdiag[q]-6/hR^2-6/hZ^2))
        haskey(cmap,kr)&&add!(q,cmap[kr],rf*cs[cmap[kr]]*6/hR^2)
        haskey(cmap,kz)&&add!(q,cmap[kz],rf*cs[cmap[kz]]*6/hZ^2)
        add!(q,poR+k,rf*(-4/hR-1/R[i]));add!(q,poR+kr,rf*(-2/hR))
        add!(q,poZ+k,rf*(-4/hZ));add!(q,poZ+kz,rf*(-2/hZ))
    end
    # Primary not-a-knot slope equations.  Psi coordinates outside the selected
    # interior block are fixed at zero, while slope coordinates span the grid.
    for j in 1:nz,i in 1:nr
        node=(i-1)*nz+j;row=n+node;span=i==1 ? (1:3) : i==nr ? (nr-2:nr) : (i-1:i+1)
        for ell in span
            add!(row,poR+(ell-1)*nz+j,sr.L[i,ell])
            q=get(cmap,(ell-1)*nz+j,0);q==0||add!(row,q,-sr.C[i,ell]*cs[q])
        end
    end
    for i in 1:nr,j in 1:nz
        node=(i-1)*nz+j;row=n+N+node;span=j==1 ? (1:3) : j==nz ? (nz-2:nz) : (j-1:j+1)
        for ell in span
            add!(row,poZ+(i-1)*nz+ell,sz.L[j,ell])
            q=get(cmap,(i-1)*nz+ell,0);q==0||add!(row,q,-sz.C[j,ell]*cs[q])
        end
    end
    A=sparse(I,J,V,dim,dim);dropzeros!(A);I=nothing;J=nothing;V=nothing
    all(isfinite,nonzeros(A))||return (status=:numerical_fail,reason=:mixed_matrix_nonfinite)
    UM=SparseArrays.UMFPACK;US=SparseArrays.LibSuiteSparse
    U=try
        control=UM.get_umfpack_control(Float64,Int)
        control[UM.UMFPACK_ORDERING+1]=US.UMFPACK_ORDERING_METIS
        UM.UmfpackLU(A;control=control)
    catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :unsupported,
            reason=err isa OutOfMemoryError ? :mixed_umfpack_symbolic_allocation : :mixed_umfpack_unavailable,
            detail=sprint(showerror,err),shape=size(A),nnz=nnz(A))
    end
    try
        UM.umfpack_symbolic!(U,nothing)
    catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
            reason=err isa OutOfMemoryError ? :mixed_metis_symbolic_out_of_memory : :mixed_metis_symbolic_failed,
            detail=sprint(showerror,err),shape=size(A),nnz=nnz(A))
    end
    unit=U.info[US.UMFPACK_SIZE_OF_UNIT+1];peak_units=U.info[US.UMFPACK_PEAK_MEMORY_ESTIMATE+1]
    numeric_units=U.info[US.UMFPACK_NUMERIC_SIZE_ESTIMATE+1]
    all(isfinite,(unit,peak_units,numeric_units))&&unit>0&&peak_units>=0 ||
        return (status=:numerical_fail,reason=:mixed_umfpack_memory_estimate_invalid)
    ordering_used=Int(U.info[US.UMFPACK_ORDERING_USED+1])
    ordering_used==US.UMFPACK_ORDERING_METIS||return (status=:unsupported,
        reason=:mixed_umfpack_metis_ordering_not_used,ordering_used=ordering_used)
    peak_bytes=ceil(Int128,unit*peak_units);numeric_bytes=ceil(Int128,unit*numeric_units)
    live=Int128(Base.gc_live_bytes());reserve=Int128(768)*1024^2
    csc_bytes=Int128(sizeof(Int))*length(A.colptr)+
        Int128(sizeof(Int)+sizeof(Float64))*nnz(A)
    incremental=csc_bytes+peak_bytes+reserve
    rhs_capacity=16
    rhs_workspace=Int128(3*sizeof(Float64))*Int128(size(A,1))*rhs_capacity
    incremental+=rhs_workspace
    projected=live+peak_bytes+reserve
    projected+=rhs_workspace
    cap4g=Int128(4)*1024^3
    incremental<=min(avail,factor_cap)&&projected<=cap4g||return (status=:resource_interruption,
        reason=:mixed_numeric_factor_memory_preflight,estimated_factor_bytes=peak_bytes,
        csc_copy_bytes=csc_bytes,reserve_bytes=reserve,incremental_bytes=incremental,
        available_bytes=avail,max_factor_bytes=factor_cap,projected_peak_bytes=projected,cap_bytes=cap4g)
    try
        UM.umfpack_numeric!(U)
    catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
            reason=err isa OutOfMemoryError ? :mixed_numeric_factor_out_of_memory : :mixed_numeric_factor_failed,
            detail=sprint(showerror,err),shape=size(A),nnz=nnz(A),projected_peak_bytes=projected)
    end
    LinearAlgebra.issuccess(U)||return (status=:numerical_fail,reason=:mixed_numeric_factor_singular,
        shape=size(A),nnz=nnz(A),umfpack_status=U.status)
    built=ExactSplineMixedFactorV1(U,G,size(G),size(A,1),nnz(A),rhs_capacity,ids,
        (schema=:exact_spline_mixed_factor_v1,ordering=:metis,ordering_used=ordering_used,
         status=:numeric_factor_complete,shape=size(A),nnz=nnz(A),
         umfpack=(size_of_unit_bytes=unit,peak_memory_estimate_bytes=peak_bytes,
             numeric_size_estimate_bytes=numeric_bytes),
         coefficient_consistency=consistency,
         memory=(assembly_estimate_bytes=assembly_bytes,csc_copy_bytes=csc_bytes,
             estimated_factor_bytes=peak_bytes,reserve_bytes=reserve,incremental_bytes=incremental,
             rhs_workspace_bytes=rhs_workspace,rhs_capacity=rhs_capacity,
             available_bytes=avail,max_factor_bytes=factor_cap,projected_peak_bytes=projected,
             cap_bytes=cap4g),rank_certificate=:not_established_for_G,
         full_G_lu=false,full_global_kkt=false,science_credit=false))
    (status=:ok,factorization=built,factor=U,report=built.report)
end

"""Apply a previously built exact mixed factor and gate every RHS against true scaled G."""
function _gs_native_exact_spline_mixed_inverse_v1(G,built::ExactSplineMixedFactorV1,rhs;
        transpose_system=false,relative_tolerance=1e-10,deadline_ns=typemax(Int64))
    G===built.G_reference||return (status=:numerical_fail,reason=:mixed_G_identity_changed,
        rank_certificate=:not_established_for_G)
    size(G)==built.shape&&size(built.factorization,1)==built.mixed_dimension ||
        return (status=:numerical_fail,reason=:mixed_factor_shape_mismatch)
    isfinite(relative_tolerance)&&relative_tolerance>0||
        return (status=:numerical_fail,reason=:mixed_residual_tolerance_invalid)
    B=rhs isa AbstractVector ? reshape(Float64.(rhs),:,1) : Matrix{Float64}(rhs)
    size(B,1)==size(G,1)&&all(isfinite,B)||
        return (status=:numerical_fail,reason=:mixed_rhs_shape_or_value_invalid)
    size(B,2)<=built.rhs_capacity||return (status=:resource_interruption,
        reason=:mixed_rhs_batch_exceeds_reserved_workspace,rhs_count=size(B,2),
        rhs_capacity=built.rhs_capacity)
    n=size(G,1);N=(built.mixed_dimension-n)÷2;dim=built.mixed_dimension
    full_rhs=zeros(Float64,dim,size(B,2));full_rhs[1:n,:].=B
    time_ns()<deadline_ns||return (status=:resource_interruption,reason=:mixed_inverse_deadline_before_solve,
        transpose=transpose_system,rhs_count=size(B,2))
    Y=try
        transpose_system ? transpose(built.factorization)\full_rhs : built.factorization\full_rhs
    catch err
        return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
            reason=err isa OutOfMemoryError ? :mixed_inverse_action_out_of_memory : :mixed_inverse_action_failed,
            detail=sprint(showerror,err),transpose=transpose_system,rhs_count=size(B,2))
    end
    X=Matrix{Float64}(Y[1:n,:]);reports=NamedTuple[]
    for j in axes(B,2)
        rhsj=view(B,:,j);rhsnorm=norm(rhsj);refinements=0
        defect=transpose_system ? transpose(G)*view(X,:,j)-rhsj : G*view(X,:,j)-rhsj
        rel=norm(defect)/max(rhsnorm,floatmin(Float64))
        while isfinite(rel)&&rel>relative_tolerance&&refinements<2
            time_ns()<deadline_ns||return (status=:resource_interruption,reason=:mixed_inverse_deadline_before_refinement,
                transpose=transpose_system,rhs_index=j,refinements=refinements)
            correction_rhs=zeros(Float64,dim);correction_rhs[1:n].=-defect
            correction=try
                transpose_system ? transpose(built.factorization)\correction_rhs : built.factorization\correction_rhs
            catch err
                return (status=err isa OutOfMemoryError ? :resource_interruption : :numerical_fail,
                    reason=err isa OutOfMemoryError ? :mixed_refinement_out_of_memory : :mixed_refinement_solve_failed,
                    detail=sprint(showerror,err),transpose=transpose_system,rhs_index=j,
                    refinements=refinements)
            end
            view(X,:,j).+=view(correction,1:n);refinements+=1
            defect=transpose_system ? transpose(G)*view(X,:,j)-rhsj : G*view(X,:,j)-rhsj
            rel=norm(defect)/max(rhsnorm,floatmin(Float64))
        end
        defectnorm=norm(defect)
        push!(reports,(rhs_index=j,true_G_relative_residual=rel,true_G_residual_norm=defectnorm,
            rhs_norm=rhsnorm,refinements=refinements,passed=isfinite(rel)&&rel<=relative_tolerance))
    end
    pass=all(r->r.passed,reports)
    (status=pass ? :ok : :numerical_fail,reason=pass ? :none : :mixed_true_G_residual_exceeded,
        solution=rhs isa AbstractVector ? vec(X) : X,transpose=Bool(transpose_system),
        solve_reports=Tuple(reports),rhs_count=size(B,2),relative_tolerance=relative_tolerance,
        factor_report=built.report,rank_certificate=:not_established_for_G,
        full_G_lu=false,full_global_kkt=false,science_credit=false)
end

# Result fidelity binding for cached numerical transforms. Hash the actual
# CSC arrays in place; this is numeric operator data, never a source-file hash.
function _exact_numeric_operator_sha256_v1(J::SparseMatrixCSC,C::SparseMatrixCSC)
    context=SHA.SHA2_256_CTX()
    for A in (J,C)
        SHA.update!(context,reinterpret(UInt8,Int64[size(A,1),size(A,2)]))
        SHA.update!(context,reinterpret(UInt8,A.colptr))
        SHA.update!(context,reinterpret(UInt8,A.rowval))
        SHA.update!(context,reinterpret(UInt8,A.nzval))
    end
    bytes2hex(SHA.digest!(context))
end

# Multiply the equality nullspace by its original and active-bound blocks
# without materializing vcat(Cu,bound_Cu), a second full constraint transform.
function _exact_constraint_nullspace_product_v1(Cu::Matrix{Float64},
        bound_Cu::Matrix{Float64},Q2::AbstractMatrix{Float64})
    size(Cu,2)==size(bound_Cu,2) && size(Q2,1)==size(Cu,1)+size(bound_Cu,1) ||
        throw(ArgumentError("constraint/nullspace block dimensions differ"))
    D=Matrix{Float64}(undef,size(Q2,2),size(Cu,2))
    mul!(D,transpose(view(Q2,1:size(Cu,1),:)),Cu)
    if size(bound_Cu,1)>0
        mul!(D,transpose(view(Q2,size(Cu,1)+1:size(Q2,1),:)),bound_Cu,1.0,1.0)
    end
    D
end

# Evaluate the small Schur residual using exact conversions of the Float64
# factors and iterate at elevated precision. This distinguishes cancellation
# in the ordinary Float64 matrix products from an actual Schur solve defect.
function _exact_lq_schur_residual_big_v1(L::Matrix{Float64},rhs::Vector{Float64},
        eta::Vector{Float64};precision_bits::Int=256)
    setprecision(BigFloat,precision_bits) do
        Lb=BigFloat.(L); rb=BigFloat.(rhs); eb=BigFloat.(eta)
        residual=rb-Lb*(transpose(Lb)*eb)
        relative=norm(residual)/max(one(BigFloat),norm(rb))
        (relative=Float64(relative),residual=Float64.(residual))
    end
end

const EXACT_TRANSFORM_APPEND_ROW_SUPPORTED = true

Base.@noinline Base.@nospecializeinfer function _exact_save_hp_replay_v1(path, payload)
    Base.@nospecialize payload
    ispath(path) && throw(ArgumentError("refusing to overwrite exact fixed-primal replay checkpoint"))
    mkpath(dirname(abspath(path)))
    open(path,"w") do io
        serialize(io,payload);flush(io)
    end
    (path=abspath(path),bytes=filesize(path),sha256=bytes2hex(open(SHA.sha256,path)))
end

# Keep failure reporting bounded when a MethodError carries a very large Tuple
# specialization. Calling showerror here can allocate another giant type string
# and hide the original inference failure under ReadOnlyMemoryError.
Base.@noinline Base.@nospecializeinfer function _bounded_exact_kkt_exception_v1(err, bt)
    Base.@nospecialize err bt
    type_family(x)=try
        nameof(Base.unwrap_unionall(typeof(x)))
    catch
        :unknown_type
    end
    callable_name(f)=try
        nameof(f)
    catch
        type_family(f)
    end
    arg_shape(x)=if x isa Tuple || x isa NamedTuple
        (type=type_family(x),length=length(x))
    elseif x isa AbstractArray
        (type=type_family(x),length=length(x))
    else
        (type=type_family(x),length=nothing)
    end
    if err isa MethodError
        args=getfield(err,:args)
        count=min(length(args),8)
        families=Symbol[type_family(args[i]) for i in 1:count]
        shapes=[arg_shape(args[i]) for i in 1:count]
        summary=(exception_type=:MethodError,function_name=callable_name(getfield(err,:f)),
            argument_count=length(args),argument_families=families,argument_shapes=shapes,
            arguments_truncated=length(args)>count,message=:method_error_details_suppressed)
    elseif err isa ErrorException
        message=getfield(err,:msg)
        clipped=length(message)>512 ? String(first(message,512)) : message
        summary=(exception_type=type_family(err),function_name=:unknown,argument_count=0,
            argument_families=Symbol[],argument_shapes=NamedTuple[],arguments_truncated=false,
            message=clipped)
    else
        summary=(exception_type=type_family(err),function_name=:unknown,argument_count=0,
            argument_families=Symbol[],argument_shapes=NamedTuple[],arguments_truncated=false,
            message=:exception_details_suppressed)
    end
    frames=NamedTuple[]
    try
        trace=stacktrace(bt)
        for frame in Iterators.take(trace,8)
            push!(frames,(file=frame.file,line=frame.line,func=frame.func))
        end
    catch
        empty!(frames)
    end
    (summary=summary,frames=frames)
end

# A fixed-primal check, not a second global solve. Float64 matrices and the
# physical/scaled step are unchanged. Only the small dual solve and residual
# arithmetic use 256 bits; no BigFloat copy of either sparse operator is made.
function _exact_fixed_primal_high_precision_kkt_v1(J,C,f,c,d,state,physical_step,
        column_scales,active,L,schur_rhs,Q2)
    setprecision(BigFloat,256) do
        function matvec(A,x,adjoint_action=false)
            out=zeros(BigFloat,adjoint_action ? size(A,2) : size(A,1))
            if SparseArrays.issparse(A)
                rows=SparseArrays.rowvals(A);values=SparseArrays.nonzeros(A)
                for j in axes(A,2),k in SparseArrays.nzrange(A,j)
                    if adjoint_action
                        out[j]+=BigFloat(values[k])*BigFloat(x[rows[k]])
                    else
                        out[rows[k]]+=BigFloat(values[k])*BigFloat(x[j])
                    end
                end
            else
                for j in axes(A,2),i in axes(A,1)
                    iszero(A[i,j]) && continue
                    if adjoint_action
                        out[j]+=BigFloat(A[i,j])*BigFloat(x[i])
                    else
                        out[i]+=BigFloat(A[i,j])*BigFloat(x[j])
                    end
                end
            end
            out
        end
        maxabs(x)=maximum(abs,x;init=BigFloat(0))
        Lb=BigFloat.(L);rb=BigFloat.(schur_rhs)
        yb=LowerTriangular(Lb)\rb;etab=UpperTriangular(transpose(Lb))\yb
        schur_res=rb-Lb*(transpose(Lb)*etab)
        schur_rel=norm(schur_res)/max(BigFloat(1),norm(rb))
        mu=matvec(Q2,etab);mu_eq=mu[1:size(C,1)];mu_bound=mu[size(C,1)+1:end]
        jy=matvec(J,d);fb=BigFloat.(f);lambda=fb+jy
        jt=matvec(J,lambda,true);ct=matvec(C,mu_eq,true);bound=zeros(BigFloat,length(d))
        for (a,i) in enumerate(active);bound[i]=BigFloat(column_scales[i])*mu_bound[a];end
        stationarity=jt+ct+bound;ls=jy-lambda+fb
        cd=matvec(C,d);cb=BigFloat.(c);eq=cd+cb
        active_res=BigFloat[BigFloat(state[i])+BigFloat(physical_step[i]) for i in active]
        stat_abs=maxabs(stationarity)
        stat_rel=stat_abs/max(BigFloat(1),maxabs(jt),maxabs(ct),maxabs(bound))
        ls_rel=maxabs(ls)/max(BigFloat(1),maxabs(jy),maxabs(lambda),maxabs(fb))
        eq_rel=maxabs(eq)/max(BigFloat(1),maxabs(cd),maxabs(cb))
        active_rel=maxabs(active_res)/max(BigFloat(1),maxabs(physical_step[active]),maxabs(state[active]))
        rhs_norm=sqrt(sum(abs2,fb)+sum(abs2,cb)+sum(i->abs2(BigFloat(state[i])),active;init=BigFloat(0)))
        true_res=sqrt(sum(abs2,stationarity)+sum(abs2,ls)+sum(abs2,eq)+sum(abs2,active_res))
        true_rel=iszero(rhs_norm) ? true_res : true_res/rhs_norm
        (schema=:fixed_primal_high_precision_kkt_v1,precision_bits=256,
            primal_step_changed=false,new_G_solves=0,new_assemblies=0,
            Q2=Matrix{Float64}(Q2),schur_factor=copy(L),schur_rhs=copy(schur_rhs),schur_y=yb,schur_eta=etab,
            lambda=lambda,mu_eq=mu_eq,mu_bound=mu_bound,bound_stationarity=bound,
            stationarity_vector=stationarity,least_squares_residual=ls,equality_residual=eq,
            active_coordinate_residual=active_res,stationarity=stat_abs,stationarity_relative=stat_rel,
            least_squares_relative=ls_rel,equality_relative=eq_rel,active_bound_relative=active_rel,
            block_defect=maximum((stat_rel,ls_rel,eq_rel,active_rel)),
            true_kkt_relative_defect=true_rel,true_kkt_absolute_residual=true_res,true_kkt_rhs_norm=rhs_norm,
            schur_relative_residual=schur_rel,full_global_kkt=false)
    end
end

function _exact_transform_append_base_v1(J,C,state,column_scales,pressure_indices,map,row_order,pivot_cols,free_cols)
    path=get(ENV,"FUSION_G2_EXACT_TRANSFORM_APPEND_BASE_PATH","")
    pin=get(ENV,"FUSION_G2_EXACT_TRANSFORM_APPEND_BASE_SHA256","")
    base_partition=get(ENV,"FUSION_G2_EXACT_TRANSFORM_APPEND_BASE_PARTITION_HASH","")
    size(C,1)==772 && !isempty(path) && !isempty(base_partition) &&
        occursin(r"^[0-9a-f]{64}$",pin) && bytes2hex(open(SHA.sha256,path))==pin ||
        throw(ArgumentError("append-one base numerical checkpoint pin or row count differs"))
    saved=open(deserialize,path)
    base_count=size(C,1)-1;m=size(J,1)
    saved.schema===:exact_row_pivot_constraint_transform_v1 &&
        saved.numeric_operator_sha256==_exact_numeric_operator_sha256_v1(J,sparse(C[1:base_count,:])) &&
        saved.partition_hash==base_partition &&
        saved.state==state && saved.column_scales==column_scales &&
        saved.row_order==row_order && saved.pivot_columns==pivot_cols &&
        saved.free_columns==free_cols && saved.pressure_indices==Int.(collect(pressure_indices)) &&
        saved.ordered_equality_ids==map.ordered_EQ_ids[1:base_count] &&
        size(saved.Cu)==(base_count,m) && size(saved.Cv)==(base_count,length(free_cols)) &&
        all(isfinite,saved.Cu) && all(isfinite,saved.Cv) ||
        throw(ArgumentError("append-one base transform differs from the unchanged 771-row numeric problem"))
    saved
end

# The formal append route calls the same numerical validator.  This entry
# only loads/scales/checks saved arrays; it cannot factor or solve a system.
function _exact_transform_append_preflight_v1(partition,state,column_scales,pressure_indices,map)
    map.ordered_LS_ids==String.(collect(partition.least_squares_row_ids)) &&
        map.ordered_EQ_ids==String.(collect(partition.equality_row_ids)) &&
        map.pressure_indices==Int.(collect(pressure_indices)) && map.gs_native_rz!==nothing ||
        throw(ArgumentError("append-one preflight row/map ABI differs"))
    J=sparse(partition.scaled_least_squares_jacobian*spdiagm(0=>column_scales))
    C=sparse(partition.equality_jacobian*spdiagm(0=>column_scales))
    row_order=vcat(map.row_groups...);pivot_cols=vcat(map.column_groups...);free_cols=map.free_columns
    saved=_exact_transform_append_base_v1(J,C,state,column_scales,pressure_indices,map,row_order,pivot_cols,free_cols)
    (status=:exact_transform_append_base_ABI_passed,base_rows=size(saved.Cu,1),current_rows=size(C,1),
        Cu_shape=size(saved.Cu),Cv_shape=size(saved.Cv),state_dofs=length(state),
        base_operator_sha256=saved.numeric_operator_sha256,base_partition_hash=saved.partition_hash,
        new_transpose_RHS_columns=1,new_factorizations=0,new_solver_calls=0,new_assemblies=0,
        full_global_kkt=false,formal_acceptance=false)
end

function _exact_row_pivot_kkt_step_v1(partition,state,column_scales,pressure_indices,map;
        stationarity_tolerance, bound_dual_tolerance, max_active_set_iterations, seconds,
        max_working_memory_bytes, diagnostic_transpose_rhs=nothing,
        precomputed_scaled_jacobian=nothing)
    method_started=time_ns()
    m=length(partition.scaled_least_squares_residual)
    n=length(state)
    if diagnostic_transpose_rhs!==nothing
        diagnostic_transpose_rhs isa AbstractMatrix{Float64} &&
            size(diagnostic_transpose_rhs)==(m,1) && all(isfinite,diagnostic_transpose_rhs) ||
            throw(ArgumentError("diagnostic transpose RHS must be one finite Float64 pivot-ordered column"))
    end
    max_seconds=Float64(seconds)
    deadline_check() = (time_ns()-method_started)/1e9 < max_seconds
    map.schema=="exact-row-pivot-kkt-map-v1" || throw(ArgumentError("exact row-pivot map schema is invalid"))
    map.ordered_LS_ids==String.(collect(partition.least_squares_row_ids)) ||
        throw(ArgumentError("exact row-pivot map least-squares IDs differ from partition order"))
    map.ordered_EQ_ids==String.(collect(partition.equality_row_ids)) ||
        throw(ArgumentError("exact row-pivot map equality IDs differ from partition order"))
    map.pressure_indices==Int.(collect(pressure_indices)) ||
        throw(ArgumentError("exact row-pivot map pressure coordinates differ from solver request"))
    all(g->all(i->1<=i<=m,g),map.row_groups) || throw(ArgumentError("exact row-pivot row index is out of range"))
    all(g->all(i->1<=i<=n,g),map.column_groups) && all(i->1<=i<=n,map.free_columns) ||
        throw(ArgumentError("exact row-pivot state index is out of range"))
    row_order=vcat(map.row_groups...); pivot_cols=vcat(map.column_groups...); free_cols=map.free_columns
    length(row_order)==m && sort(row_order)==collect(1:m) ||
        throw(ArgumentError("exact row-pivot row groups must cover least-squares rows exactly once"))
    length(unique(pivot_cols))==length(pivot_cols) && length(unique(free_cols))==length(free_cols) &&
        isempty(intersect(Set(pivot_cols),Set(free_cols))) &&
        sort(vcat(pivot_cols,free_cols))==collect(1:n) ||
        throw(ArgumentError("exact row-pivot and free columns must partition state coordinates"))
    all(i->i in pivot_cols,pressure_indices) ||
        throw(ArgumentError("all nonnegative pressure coordinates must be pivot coordinates"))
    all(i->length(map.row_groups[i])==length(map.column_groups[i]),1:5) ||
        throw(ArgumentError("exact row-pivot diagonal blocks must be square"))
    length(map.row_groups[1])==1 || throw(ArgumentError("normalization pivot block must be scalar"))
    J=precomputed_scaled_jacobian === nothing ?
        _column_scaled_sparse_copy_v1(partition.scaled_least_squares_jacobian,column_scales) :
        precomputed_scaled_jacobian
    C=_column_scaled_sparse_copy_v1(partition.equality_jacobian,column_scales)
    f=Float64.(partition.scaled_least_squares_residual); c=Float64.(partition.equality_residual)
    size(J)==(m,n) && size(C)==(length(c),n) || throw(ArgumentError("exact row-pivot input dimensions differ"))
    all(isfinite,f) && all(isfinite,c) && all(isfinite,nonzeros(J)) && all(isfinite,nonzeros(C)) ||
        throw(ArgumentError("exact row-pivot input contains nonfinite values"))
    for i in 1:5, j in (i+1):5
        nnz(J[map.row_groups[i],map.column_groups[j]])==0 ||
            throw(ArgumentError("exact row-pivot expected block-lower-triangular upper block to be zero"))
    end
    for i in (1,3,4,5)
        B=J[map.row_groups[i],map.column_groups[i]]
        length(map.row_groups[i])==length(map.column_groups[i]) && nnz(B)==length(map.row_groups[i]) ||
            throw(ArgumentError("exact row-pivot scalar diagonal block is not diagonal and complete"))
        all(x->isfinite(x)&&!iszero(x),diag(B)) ||
            throw(ArgumentError("exact row-pivot diagonal block has a zero or nonfinite pivot"))
    end
    row_offsets=cumsum(vcat(0,collect(length.(map.row_groups))))
    row_ranges=ntuple(i->(row_offsets[i]+1):row_offsets[i+1],5)
    lower=Dict{Tuple{Int,Int},SparseMatrixCSC{Float64,Int}}()
    for i in 2:5,j in 1:(i-1)
        B=sparse(J[map.row_groups[i],map.column_groups[j]])
        nnz(B)>0 && (lower[(i,j)]=B)
    end
    Jf=sparse(J[row_order,free_cols]); Cp=sparse(C[:,pivot_cols]); Cf=sparse(C[:,free_cols])
    G=sparse(J[map.row_groups[2],map.column_groups[2]])
    size(G,1)==size(G,2) && size(G,1)>0 || throw(ArgumentError("GS pivot block is not square"))
    if map.gs_fd3_payload!==nothing
        payload=map.gs_fd3_payload
        payload.span_columns[1] in free_cols && payload.span_columns[2] in free_cols &&
            payload.coefficient_columns[2] in free_cols && payload.coefficient_columns[1]==map.column_groups[1][1] ||
            throw(ArgumentError("FD3 state-dependent profile columns disagree with the original exact pivot map"))
        gs_rows=map.row_groups[2]
        row_ids=String.(map.ordered_LS_ids[gs_rows])
        all(id->occursin(":GS4:node_",id),row_ids) ||
            throw(ArgumentError("FD3 GS equation rows are not tagged native GS4 nodes"))
        parsed_ids=Int[parse(Int,split(id,":node_")[end]) for id in row_ids]
        parsed_ids==payload.native_ids && map.column_groups[2]==4 .* payload.native_ids ||
            throw(ArgumentError("FD3 native IDs do not match exact G row and column order"))
        length(payload.mask)==length(payload.Raxis)*length(payload.Zaxis) ||
            throw(ArgumentError("FD3 native mask dimensions differ from native axes"))
    end
    gs_inverse_reports=NamedTuple[]
    band_build=nothing
    mixed_build=nothing
    if map.gs_native_rz===nothing
        # Preserve the existing exact full-G LU/rank-gate behavior for callers
        # that have not opted into the producer-native coordinate route.
        g_payload=Int128(sizeof(Float64))*(Int128(size(G,2))+1)+Int128(16)*Int128(nnz(G))
        reserve_bytes=Base.summarysize((partition,J,C,G,lower,Jf,Cp,Cf))+
            Int128(sizeof(Float64))*Int128(size(C,1))*Int128(m)+
            Int128(sizeof(Float64))*Int128(size(C,1))*Int128(length(free_cols))+
            Int128(sizeof(Float64))*Int128(m)*16*6+Int128(8)*g_payload
        reserve_bytes<=Int128(max_working_memory_bytes) || return (status=:resource_interruption,
            reason=:exact_row_pivot_pre_factor_working_memory_cap,
            linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
            estimated_working_set_bytes=reserve_bytes,max_working_memory_bytes=Int128(max_working_memory_bytes),
            full_global_kkt=false)
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_before_factor,
            full_global_kkt=false)
        factor=lu(G;check=false)
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_after_factor,
            full_global_kkt=false)
        piv=abs.(diag(factor.U)); pmax=maximum(piv;init=0.0)
        prank=count(>(eps(Float64)*max(size(G)...)*pmax),piv)
        prank==size(G,1) && all(isfinite,piv) ||
            return (status=:numerical_fail,reason=:exact_row_pivot_GS_rank_gate,
                linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
                pivot_rank=prank,pivot_order=size(G,1),full_global_kkt=false)
    else
        length(map.gs_native_rz)==size(G,2) || throw(ArgumentError("GS native R/Z map order differs from G pivot columns"))
        rhs_batch_bytes=Int128(16)*size(G,1)*16
        gmres_workspace_bytes=Int128(8)*size(G,1)*48+Int128(8)*33*32
        nonfactor_bytes=Base.summarysize((partition,J,C,G,lower,Jf,Cp,Cf))+
            Int128(sizeof(Float64))*Int128(size(C,1))*Int128(m)+
            Int128(sizeof(Float64))*Int128(size(C,1))*Int128(length(free_cols))+
            Int128(sizeof(Float64))*Int128(m)*16*6
        available_bytes=max(Int128(0),Int128(max_working_memory_bytes)-nonfactor_bytes)
        inverse_workspace_bytes=rhs_batch_bytes+gmres_workspace_bytes
        fd3_construction_bytes=map.gs_fd3_payload===nothing ? Int128(0) : Int128(512)*size(G,1)
        factor_cap=Int(max(Int128(0),min(Int128(512*1024^2),
            available_bytes-inverse_workspace_bytes-fd3_construction_bytes)))
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_before_band_factor,full_global_kkt=false)
        if map.gs_fd3_payload===nothing
            band_build=_gs_native_band_factor_v1(G,map.gs_native_rz;radius_r=1,radius_z=2,
                max_factor_bytes=factor_cap)
        else
            payload=map.gs_fd3_payload
            gs_row_scales=Float64[partition.least_squares_row_scales[i] for i in map.row_groups[2]]
            gs_column_scales=Float64[column_scales[i] for i in map.column_groups[2]]
            mixed_available=max(Int128(0),available_bytes-inverse_workspace_bytes)
            mixed_build=_gs_native_exact_spline_mixed_factor_v1(G,map.gs_native_rz,payload,
                gs_row_scales,gs_column_scales,mixed_available)
            mixed_build.status===:ok || return merge(mixed_build,
                (linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,
                 backend=:exact_row_pivot_active_set,full_global_kkt=false))
        end
        if mixed_build===nothing
            band_build.status===:ok || return merge(band_build,(linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,
                backend=:exact_row_pivot_active_set,full_global_kkt=false))
            factor=band_build.factor
            reserve_bytes=nonfactor_bytes+inverse_workspace_bytes+fd3_construction_bytes+
                band_build.estimated_factor_bytes
        else
            factor=mixed_build.factor
            reserve_bytes=nonfactor_bytes+inverse_workspace_bytes+
                mixed_build.report.memory.incremental_bytes
        end
        reserve_bytes<=Int128(max_working_memory_bytes) || return (status=:resource_interruption,
            reason=:exact_row_pivot_band_factor_working_memory_cap,
            linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
            estimated_working_set_bytes=reserve_bytes,max_working_memory_bytes=Int128(max_working_memory_bytes),
            full_global_kkt=false)
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_after_band_factor,
            full_global_kkt=false)
    end
    diagonal_values=ntuple(i->i==2 ? Float64[] : Float64.(diag(J[map.row_groups[i],map.column_groups[i]])),5)
    function diag_solve(i,rhs,transpose_system=false)
        if i==2
            if mixed_build!==nothing
                deadline_check() || throw(GSNumericInverseFailureV1(
                    (status=:resource_interruption,reason=:mixed_inverse_deadline)))
                solved=_gs_native_exact_spline_mixed_inverse_v1(G,mixed_build.factorization,rhs;
                    transpose_system=transpose_system,relative_tolerance=1e-10,
                    deadline_ns=isfinite(max_seconds) ? Int64(method_started)+round(Int,max_seconds*1.0e9) : typemax(Int64))
                solved.status===:ok || throw(GSNumericInverseFailureV1(solved))
                append!(gs_inverse_reports,(merge(report,
                    (transpose_system=transpose_system,backend=:exact_spline_mixed_metis))
                    for report in solved.solve_reports))
                return solved.solution
            end
            if band_build===nothing
                return transpose_system ? transpose(factor)\rhs : factor\rhs
            end
            solved=gs_native_band_inverse_v1(G,map.gs_native_rz,rhs;transpose_system=transpose_system,
                restart=32,max_iterations=512,max_refinements=2,relative_tolerance=1e-10,
                max_auxiliary_bytes=Int(min(available_bytes,Int128(512*1024^2))),
                deadline_ns=isfinite(max_seconds) ? Int64(method_started)+round(Int,max_seconds*1.0e9) : typemax(Int64),
                factorization=band_build)
            solved.status===:ok || throw(GSNumericInverseFailureV1(solved))
            append!(gs_inverse_reports,(merge(report,(transpose_system=transpose_system,)) for report in solved.solve_reports))
            return solved.solution
        end
        rhs ./ reshape(diagonal_values[i],:,1)
    end
    function solve_A(rhs)
        size(rhs,1)==m || throw(ArgumentError("exact row-pivot A solve dimension mismatch"))
        parts=Vector{Matrix{Float64}}(undef,5)
        for i in 1:5
            t=Matrix(@view rhs[row_ranges[i],:])
            for j in 1:(i-1)
                B=get(lower,(i,j),nothing); B===nothing || (t .-= B*parts[j])
            end
            parts[i]=diag_solve(i,t,false)
        end
        vcat(parts...)
    end
    function solve_At(rhs)
        size(rhs,1)==m || throw(ArgumentError("exact row-pivot A transpose solve dimension mismatch"))
        parts=Vector{Matrix{Float64}}(undef,5)
        for i in 5:-1:1
            t=Matrix(@view rhs[row_ranges[i],:])
            for j in (i+1):5
                B=get(lower,(j,i),nothing); B===nothing || (t .-= transpose(B)*parts[j])
            end
            parts[i]=diag_solve(i,t,true)
        end
        vcat(parts...)
    end
    if diagnostic_transpose_rhs!==nothing
        deadline_check() || return (status=:resource_interruption,
            reason=:exact_transpose_diagnostic_deadline,full_global_kkt=false)
        solution=solve_At(Matrix{Float64}(diagnostic_transpose_rhs))
        return (status=:diagnostic_transpose_action,
            transpose_solution=solution,transpose_solution_row_order=copy(row_order),
            transpose_rhs_pivot_columns=copy(pivot_cols),
            gs_inverse_solve_reports=Tuple(gs_inverse_reports),
            new_transpose_RHS_columns=1,new_transforms=0,new_assemblies=0,
            full_global_kkt=false,science_credit=false)
    end
    transform_reuse=get(ENV,"FUSION_G2_EXACT_TRANSFORM_REUSE_PATH","")
    transform_output=get(ENV,"FUSION_G2_EXACT_TRANSFORM_CHECKPOINT_PATH","")
    transform_append=get(ENV,"FUSION_G2_EXACT_TRANSFORM_APPEND_BASE_PATH","")
    rank_diagnostic_path=get(ENV,"FUSION_G2_EXACT_RANK_DIAGNOSTIC_PATH","")
    (!isempty(rank_diagnostic_path) && isempty(transform_reuse)) &&
        throw(ArgumentError("exact Schur-rank diagnostics require the saved Cu/Cv transform reuse path"))
    (isempty(transform_reuse)||isempty(transform_output)) ||
        throw(ArgumentError("choose either reuse or output for the exact-transform checkpoint"))
    isempty(transform_append) || (isempty(transform_reuse) && !isempty(transform_output) &&
        size(C,1)==772 && map.gs_native_rz!==nothing) ||
        throw(ArgumentError("append-one transform requires 772 rows, the GS inverse, and a fresh output; ordinary reuse is separate"))
    transform_operator_sha=isempty(transform_reuse)&&isempty(transform_output) ? nothing :
        _exact_numeric_operator_sha256_v1(J,C)
    if !isempty(transform_append)
        saved=_exact_transform_append_base_v1(J,C,state,column_scales,pressure_indices,map,row_order,pivot_cols,free_cols)
        base_count=size(C,1)-1
        append_bytes=Base.summarysize((partition,J,C,G,lower,Jf,Cp,Cf,factor,saved))+
            Int128(8)*size(C,1)*(m+length(free_cols))+Int128(16)*m*6
        append_bytes<=Int128(max_working_memory_bytes) || return (
            status=:resource_interruption,reason=:exact_transform_append_working_memory_cap,
            estimated_working_set_bytes=append_bytes,max_working_memory_bytes=Int128(max_working_memory_bytes),
            full_global_kkt=false)
        deadline_check() || return (status=:resource_interruption,
            reason=:exact_transform_append_deadline_before_single_row,full_global_kkt=false)
        println("G2_EXACT_TRANSFORM_APPEND_BEGIN base_rows=",base_count," new_rhs_columns=1");flush(stdout)
        qCu=transpose(solve_At(Matrix(transpose(Cp[end:end,:]))))
        qCv=Matrix(Cf[end:end,:])-qCu*Jf
        Cu=Matrix{Float64}(undef,size(C,1),m)
        Cv=Matrix{Float64}(undef,size(C,1),length(free_cols))
        @views Cu[1:base_count,:].=saved.Cu
        @views Cv[1:base_count,:].=saved.Cv
        @views Cu[end:end,:].=qCu
        @views Cv[end:end,:].=qCv
        append!(gs_inverse_reports,saved.gs_inverse_solve_reports)
        saved=nothing;qCu=nothing;qCv=nothing
        GC.gc(true)
        println("G2_EXACT_TRANSFORM_APPENDED base_rows=",base_count," current_rows=",size(C,1));flush(stdout)
    elseif isempty(transform_reuse)
    Cu=Matrix{Float64}(undef,size(C,1),m)
    for first_row in 1:16:size(C,1)
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_Cu_build,
            full_global_kkt=false)
        eq_batch=first_row:min(size(C,1),first_row+15)
        solved=solve_At(Matrix(transpose(Cp[eq_batch,:])))
        @views Cu[eq_batch,:].=transpose(solved)
        if get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1"
            println("G2_EXACT_EQUALITY_TRANSFORM rhs_completed=",Base.last(eq_batch),
                "/",size(C,1)," elapsed_seconds=",(time_ns()-method_started)/1e9)
            flush(stdout)
        end
    end
    get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1" &&
        (println("G2_EXACT_TRANSFORM_CV_BEGIN live_bytes=",Base.gc_live_bytes());flush(stdout))
    GC.gc(true)
    Cv=Matrix(Cf)
    for col in 1:size(Jf,2)
        deadline_check() || return (status=:resource_interruption,reason=:exact_row_pivot_deadline_Cv_build,
            full_global_kkt=false)
        dest=@view Cv[:,col]
        for ptr in nzrange(Jf,col)
            prow=Jf.rowval[ptr]; axpy!(-Jf.nzval[ptr],@view(Cu[:,prow]),dest)
        end
    end
    else
        saved=open(deserialize,transform_reuse)
        saved.schema===:exact_row_pivot_constraint_transform_v1 &&
            saved.numeric_operator_sha256==transform_operator_sha &&
            saved.partition_hash==partition.partition_hash &&
            saved.state==state && saved.column_scales==column_scales &&
            saved.row_order==row_order && saved.pivot_columns==pivot_cols &&
            saved.free_columns==free_cols && saved.pressure_indices==Int.(collect(pressure_indices)) &&
            saved.ordered_equality_ids==map.ordered_EQ_ids &&
            size(saved.Cu)==(size(C,1),m) && size(saved.Cv)==(size(C,1),length(free_cols)) ||
            throw(ArgumentError("saved exact constraint transform does not match the current numeric problem"))
        Cu=saved.Cu;Cv=saved.Cv
        append!(gs_inverse_reports,saved.gs_inverse_solve_reports)
        saved=nothing
        println("G2_EXACT_TRANSFORM_REUSED path=",transform_reuse);flush(stdout)
    end
    rank_diagnostic_operator_sha=transform_operator_sha===nothing && !isempty(rank_diagnostic_path) ?
        _exact_numeric_operator_sha256_v1(J,C) : transform_operator_sha
    all(isfinite,Cu) && all(isfinite,Cv) || return (status=:numerical_fail,
        reason=:exact_row_pivot_constraint_transform_nonfinite,
        linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
        full_global_kkt=false)
    GC.gc(true)
    if !isempty(transform_output)
        ispath(transform_output) && throw(ArgumentError("refusing to overwrite an exact-transform checkpoint"))
        mkpath(dirname(abspath(transform_output)))
        numeric_transform=(schema=:exact_row_pivot_constraint_transform_v1,
            numeric_operator_sha256=transform_operator_sha,
            partition_hash=partition.partition_hash,state=state,column_scales=column_scales,
            row_order=row_order,pivot_columns=pivot_cols,free_columns=free_cols,
            pressure_indices=Int.(collect(pressure_indices)),ordered_equality_ids=map.ordered_EQ_ids,
            Cu=Cu,Cv=Cv,gs_inverse_solve_reports=gs_inverse_reports,
            reference_object=:same_saved_numeric_partition,
            full_global_kkt=false,physical_validation=false)
        open(transform_output,"w") do io;serialize(io,numeric_transform);flush(io);end
        println("G2_EXACT_TRANSFORM_SAVED path=",transform_output,
            " Cu_bytes=",sizeof(Cu)," Cv_bytes=",sizeof(Cv)," live_bytes=",Base.gc_live_bytes());flush(stdout)
    end
    get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1" &&
        (println("G2_EXACT_FREE_RANK_BEGIN rows=",size(Cv,1)," columns=",size(Cv,2),
            " live_bytes=",Base.gc_live_bytes());flush(stdout))
    if band_build!==nothing && map.gs_fd3_payload===nothing
        r=f[row_order]
        forward_probe=solve_A(reshape(r,:,1))
        all(isfinite,forward_probe) || return (status=:numerical_fail,
            reason=:exact_row_pivot_forward_transform_nonfinite,full_global_kkt=false)
        # The surrogate LU and converged full-G inverse actions do not certify
        # rank(G). Preserve the rank gate fail-closed before KKT/active-set output.
        return (status=:deferred,reason=:exact_row_pivot_GS_rank_certificate_unestablished,
            linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
            gs_inverse_actions=:production_Cu_Cv_forward_adjoint_completed,
            gs_inverse_solve_reports=Tuple(gs_inverse_reports),
            forward_probe=:captured_weighted_least_squares_residual,
            gs_max_iterations_per_rhs=512,gs_restart=32,gs_max_refinements=2,
            gs_true_relative_residual_tolerance=1e-10,
            gs_auxiliary_bytes_cap=Int(min(available_bytes,Int128(512*1024^2))),
            estimated_working_set_bytes=reserve_bytes,
            max_working_memory_bytes=Int128(max_working_memory_bytes),
            gs_surrogate_pattern_nnz=band_build.pattern_nnz,gs_surrogate_bandwidth=band_build.bandwidth,
            gs_surrogate_factor_bytes=band_build.estimated_factor_bytes,
            rank_certificate=:not_established_for_full_G,full_global_kkt=false,science_credit=false)
    end
    sv=svdvals(Cv); sigma=maximum(sv;init=0.0)
    rank_threshold=sqrt(eps(Float64))*max(size(Cv)...)*sigma
    count(>(rank_threshold),sv)==length(free_cols) ||
        return (status=:numerical_fail,reason=:exact_row_pivot_free_constraint_rank_gate,
            linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
            free_constraint_rank=count(>(rank_threshold),sv),free_column_count=length(free_cols),full_global_kkt=false)
    base_bytes=max(reserve_bytes,Base.summarysize((partition,J,C,G,lower,Jf,Cp,Cf,Cu,Cv,factor)))
    r=f[row_order]; active=sort!(Int[i for i in pressure_indices if iszero(state[i])])
    seen=Set{Tuple}(); trace=NamedTuple[]; last=nothing
    pivot_pos=Dict(col=>i for (i,col) in enumerate(pivot_cols))
    for iteration in 1:Int(max_active_set_iterations)
        deadline_check() ||
            return (status=:resource_interruption,reason=:exact_active_set_wall_time,
                active_set_trace=Tuple(trace),active_bounds=Tuple(active),full_global_kkt=false)
        key=Tuple(active); key in seen && return (status=:numerical_fail,
            reason=:exact_active_set_cycle,active_set_trace=Tuple(trace),active_bounds=key,full_global_kkt=false)
        push!(seen,key); q=length(active); augmented_rows=size(C,1)+q; nullity=augmented_rows-length(free_cols)
        (nullity>0 && nullity<=1024) || return (status=:resource_interruption,
            reason=:exact_active_schur_dimension_cap,active_set_trace=Tuple(trace),active_bounds=key,
            schur_dimension=nullity,max_schur_dimension=1024,full_global_kkt=false)
        batch=min(8,max(q,1)); extra=Int128(sizeof(Float64))*(Int128(q)*length(pivot_cols)+
            Int128(augmented_rows)*length(free_cols)*4+
            Int128(nullity)*length(pivot_cols)+Int128(nullity)^2+Int128(12)*n+
            Int128(5)*length(pivot_cols)*batch+Int128(4)*augmented_rows)
        estimate=Int128(base_bytes)+extra
        estimate<=Int128(max_working_memory_bytes) || return (status=:resource_interruption,
            reason=:exact_active_set_working_memory_cap,active_set_trace=Tuple(trace),active_bounds=key,
            estimated_working_set_bytes=estimate,max_working_memory_bytes=Int128(max_working_memory_bytes),
            full_global_kkt=false)
        bound_Cu=zeros(Float64,q,length(pivot_cols))
        for first_bound in 1:8:q
            rr=first_bound:min(q,first_bound+7)
            # Each pressure-bound row has one nonzero. Materialize only the
            # current transpose RHS batch, rather than a second q-by-m array.
            bound_rhs=zeros(Float64,length(pivot_cols),length(rr))
            for (a,k) in enumerate(rr)
                i=active[k];bound_rhs[pivot_pos[i],a]=column_scales[i]
            end
            bound_Cu[rr,:].=transpose(solve_At(bound_rhs))
        end
        bound_Cv=-(bound_Cu*Jf)
        # q=0 is the common case: alias the unchanged small free-column block.
        # The large Cu block is never concatenated or copied.
        Cv_aug=q==0 ? Cv : vcat(Cv,bound_Cv)
        c_aug=q==0 ? c : vcat(c,state[active])
        sv_aug=svdvals(Cv_aug); sig_aug=maximum(sv_aug;init=0.0)
        aug_thr=sqrt(eps(Float64))*max(size(Cv_aug)...)*sig_aug
        aug_rank=count(>(aug_thr),sv_aug)
        aug_rank==length(free_cols) || return (status=:numerical_fail,reason=:exact_row_pivot_augmented_free_rank_gate,
            active_set_trace=Tuple(trace),active_bounds=key,augmented_rank=aug_rank,
            augmented_rank_threshold=aug_thr,full_global_kkt=false)
        qr_factor=qr(Cv_aug); Q=Matrix{Float64}(I,augmented_rows,augmented_rows); lmul!(qr_factor.Q,Q)
        R=Matrix(qr_factor.R); Q1=@view Q[:,1:length(free_cols)]; Q2=@view Q[:,length(free_cols)+1:augmented_rows]
        # The QR object is no longer needed after Q and the copied R exist.
        # Keep Cv_aug and sv_aug through the Schur-rank diagnostic below.
        qr_factor=nothing
        GC.gc(true)
        get(ENV,"FUSION_G2_GLOBAL_ASSEMBLE_TIMING","0")=="1" &&
            (println("G2_EXACT_ACTIVE_NULLSPACE rows=",augmented_rows," nullity=",nullity,
                " active=",q," live_bytes=",Base.gc_live_bytes());flush(stdout))
        D=_exact_constraint_nullspace_product_v1(Cu,bound_Cu,Q2)
        # Keep the old Gram spectrum as an explicitly labeled diagnostic. It
        # is not the rank gate: forming D*D' squares conditioning and its
        # eigenvalue floor is in different units from direct singular values.
        legacy_gram=Symmetric(D*transpose(D))
        legacy_gram_eigenvalues=eigvals(legacy_gram)
        legacy_gram_maximum=maximum(legacy_gram_eigenvalues;init=0.0)
        legacy_gram_threshold=eps(Float64)*max(size(D)...)*legacy_gram_maximum
        legacy_gram_rank=count(>(legacy_gram_threshold),legacy_gram_eigenvalues)
        # Form b before lq! overwrites D. LQ stores Householder reflectors in
        # the existing wide D allocation; Q remains implicit and no D' copy is
        # made. For D=LQ, D*D'=L*L'.
        schur_rhs=transpose(Q2)*c_aug-D*r
        lq_factor=lq!(D)
        L=Matrix(lq_factor.L)
        schur_singular_values=svdvals(L)
        schur_sigma_maximum=maximum(schur_singular_values;init=0.0)
        schur_rank_threshold=eps(Float64)*max(size(D)...)*schur_sigma_maximum
        schur_rank=count(>(schur_rank_threshold),schur_singular_values)
        schur_rank_margin=minimum(schur_singular_values;init=Inf)-schur_rank_threshold
        schur_rank_gate_passed=size(D,1)<=size(D,2) && schur_rank==nullity &&
            schur_sigma_maximum>0.0 && all(isfinite,schur_singular_values)
        if !schur_rank_gate_passed
            diagnostic_pin=nothing
            diagnostic_path=get(ENV,"FUSION_G2_EXACT_RANK_DIAGNOSTIC_PATH","")
            if !isempty(diagnostic_path)
                ispath(diagnostic_path) && throw(ArgumentError(
                    "refusing to overwrite exact Schur-rank diagnostic checkpoint"))
                mkpath(dirname(abspath(diagnostic_path)))
                # The LQ workspace no longer contains the original D. Rebuild
                # it only on an opted-in rank failure so the saved diagnostic
                # retains the operator without holding two wide copies.
                lq_factor=nothing;L=nothing;D=nothing;GC.gc(true)
                D_saved=_exact_constraint_nullspace_product_v1(Cu,bound_Cu,Q2)
                state_sha256=bytes2hex(SHA.sha256(reinterpret(UInt8,Float64.(collect(state)))))
                scale_sha256=string(canonical_hash(Tuple(Float64.(collect(column_scales)))))
                rank_failure_schur_rhs=copy(schur_rhs)
                row_norms=(Cv_aug=Tuple(vec(sqrt.(sum(abs2,Cv_aug;dims=2)))),
                    bound_Cu=Tuple(vec(sqrt.(sum(abs2,bound_Cu;dims=2)))),
                    bound_Cv=Tuple(vec(sqrt.(sum(abs2,bound_Cv;dims=2)))),
                    D=Tuple(vec(sqrt.(sum(abs2,D_saved;dims=2)))))
                diagnostic=(schema=:exact_row_pivot_schur_rank_diagnostic_v1,
                    status=:saved_failed_schur_rank_gate,
                    reason=:exact_row_pivot_schur_rank_gate,
                    rank_method=:direct_lq_svd,
                    schur_rank_threshold_units=:singular_value_of_D,
                    legacy_gram_threshold_units=:eigenvalue_of_DDt,
                    iteration=iteration,active_bounds=key,active_bound_count=q,
                    schur_dimension=nullity,schur_rank=schur_rank,
                    schur_rank_threshold=schur_rank_threshold,
                    schur_rank_margin=schur_rank_margin,
                    schur_singular_values=Tuple(schur_singular_values),
                    legacy_gram_rank=legacy_gram_rank,
                    legacy_gram_threshold=legacy_gram_threshold,
                    legacy_gram_eigenvalues=Tuple(legacy_gram_eigenvalues),
                    augmented_rank=aug_rank,augmented_rank_threshold=aug_thr,
                    augmented_singular_values=Tuple(sv_aug),
                    schur_eigenvalues=Tuple(legacy_gram_eigenvalues),
                    schur_threshold=legacy_gram_threshold,
                    schur_threshold_relative=iszero(legacy_gram_maximum) ? Inf :
                        legacy_gram_threshold/legacy_gram_maximum,
                    schur_maximum_eigenvalue=legacy_gram_maximum,
                    schur_minimum_eigenvalue=minimum(legacy_gram_eigenvalues;init=Inf),
                    schur_rank_margin_relative=iszero(schur_sigma_maximum) ? Inf :
                        schur_rank_margin/schur_sigma_maximum,
                    active_set_trace=Tuple(trace),
                    q0_kkt_trace=Tuple(filter(x->hasproperty(x,:active_bounds)&&isempty(x.active_bounds),trace)),
                    previous_active_set_kkt_candidate=last,
                    numeric_operator_binding=(sha256=rank_diagnostic_operator_sha,
                        transform_reuse_path=isempty(transform_reuse) ? nothing : abspath(transform_reuse),
                        partition_hash=partition.partition_hash,state_sha256=state_sha256,
                        column_scales_sha256=scale_sha256,
                        ordered_LS_ids=map.ordered_LS_ids,ordered_EQ_ids=map.ordered_EQ_ids,
                        pressure_indices=map.pressure_indices),
                    row_column_maps=(row_order=row_order,pivot_columns=pivot_cols,
                        free_columns=free_cols,row_groups=map.row_groups,column_groups=map.column_groups,
                        active_bound_indices=key),
                    dimensions=(Cv_aug=size(Cv_aug),bound_Cu=size(bound_Cu),
                        bound_Cv=size(bound_Cv),Q2=size(Q2),D=size(D_saved)),
                    row_norms=row_norms,
                    bound_Cu=bound_Cu,bound_Cv=bound_Cv,Cv_aug=Cv_aug,
                    Q2=Matrix{Float64}(Q2),D=D_saved,r=Float64.(r),
                    c_aug=Float64.(c_aug),schur_rhs=Float64.(rank_failure_schur_rhs),
                    full_global_kkt=false,formal_acceptance=false,physical_validation=false)
                open(diagnostic_path,"w") do io
                    serialize(io,diagnostic);flush(io)
                end
                diagnostic_pin=(path=abspath(diagnostic_path),
                    sha256=bytes2hex(open(SHA.sha256,diagnostic_path)),
                    bytes=filesize(diagnostic_path))
            end
            return (status=:numerical_fail,reason=:exact_row_pivot_schur_rank_gate,
                active_set_trace=Tuple(trace),active_bounds=key,
                schur_dimension=nullity,schur_rank=schur_rank,
                schur_rank_method=:direct_lq_svd,
                schur_rank_threshold=schur_rank_threshold,
                schur_rank_threshold_units=:singular_value_of_D,
                schur_singular_values=Tuple(schur_singular_values),
                schur_rank_margin=schur_rank_margin,
                legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                legacy_gram_threshold_units=:eigenvalue_of_DDt,
                legacy_gram_eigenvalues=Tuple(legacy_gram_eigenvalues),
                augmented_rank=aug_rank,augmented_rank_threshold=aug_thr,
                rank_diagnostic_pin=diagnostic_pin,
                last_candidate=last,full_global_kkt=false)
        end
        # The augmented design and its singular values are needed only by the
        # rank-failure diagnostic above. Release them before refinement and
        # fixed-primal checks; Q2 and the copied R retain the solve data.
        Cv_aug=nothing; sv_aug=nothing; GC.gc(true)
        y=LowerTriangular(L)\schur_rhs
        eta=UpperTriangular(transpose(L))\y
        y_before_refinement=copy(y);eta_before_refinement=copy(eta)
        schur_float64_before_refinement=norm(L*(transpose(L)*eta)-schur_rhs)/
            max(1.0,norm(schur_rhs))
        accurate_schur=_exact_lq_schur_residual_big_v1(L,schur_rhs,eta)
        schur_bigfloat_before_refinement=accurate_schur.relative
        schur_refinement_iterations=0
        for _ in 1:3
            accurate_schur.relative<=1e-8 && break
            delta_y=LowerTriangular(L)\accurate_schur.residual
            delta_eta=UpperTriangular(transpose(L))\delta_y
            y .+= delta_y
            eta .+= delta_eta
            schur_refinement_iterations+=1
            accurate_schur=_exact_lq_schur_residual_big_v1(L,schur_rhs,eta)
        end
        q_action=zeros(Float64,size(D,2));q_action[1:length(y)]=y
        lmul!(adjoint(lq_factor.Q),q_action)
        u=-r-q_action; augmented_mu=Q2*eta
        schur_float64_after_refinement=norm(L*(transpose(L)*eta)-schur_rhs)/
            max(1.0,norm(schur_rhs))
        schur_rel=accurate_schur.relative
        refinement_u_delta_norm=0.0
        refinement_mu_delta_norm=0.0
        if schur_refinement_iterations>0
            q_action_before=zeros(Float64,size(q_action))
            q_action_before[1:length(y_before_refinement)]=y_before_refinement
            lmul!(adjoint(lq_factor.Q),q_action_before)
            refinement_u_delta_norm=norm(q_action-q_action_before)
            refinement_mu_delta_norm=norm(Q2*(eta-eta_before_refinement))
        end
        refinement_metrics=(method=:bigfloat_schur_residual_with_same_lq_refinement,
            precision_bits=256,iterations=schur_refinement_iterations,maximum_iterations=3,
            threshold=1e-8,ordinary_float64_relative_before=schur_float64_before_refinement,
            accurate_relative_before=schur_bigfloat_before_refinement,
            ordinary_float64_relative_after=schur_float64_after_refinement,
            accurate_relative_after=schur_rel,
            free_coordinate_u_delta_norm=refinement_u_delta_norm,
            equality_and_active_mu_delta_norm=refinement_mu_delta_norm,
            least_squares_lambda_delta=:not_replayed_no_additional_inverse)
        # Keep the copied triangular factor L and Schur vectors through the KKT
        # gate; a failed step's serialized raw result carries them for audit.
        lq_factor=nothing;D=nothing;q_action=nothing;GC.gc(true)
        Cu_action=q==0 ? Cu*u : vcat(Cu*u,bound_Cu*u)
        z=R\(transpose(Q1)*(-c_aug-Cu_action)); xp=solve_A(reshape(u-Jf*z,:,1))[:,1]
        scaled_direction=zeros(Float64,n); scaled_direction[pivot_cols]=xp; scaled_direction[free_cols]=z
        physical_step=column_scales.*scaled_direction
        # Active pressure equalities are exact algebraic coordinates. Encode
        # their physical updates directly, then recompute every original KKT
        # action and gate below using the synchronized scaled direction.
        for i in active
            physical_step[i]=-state[i]
            scaled_direction[i]=physical_step[i]/column_scales[i]
        end
        updated=state.+physical_step
        all(i->iszero(updated[i]),active) || return (status=:numerical_fail,
            reason=:exact_active_pressure_coordinate_gate,active_set_trace=Tuple(trace),
            active_bounds=key,full_global_kkt=false)
        pressure_after=updated[pressure_indices]
        violation=maximum((max(0.0,-p) for p in pressure_after);init=0.0)
        violating=sort!(Int[i for i in pressure_indices if !(i in active)&&updated[i]<0.0];
            by=i->(updated[i],i))
        Jy=J*scaled_direction; lambda=f.+Jy; mu_eq=augmented_mu[1:size(C,1)]
        mu_bound=q==0 ? Float64[] : augmented_mu[(size(C,1)+1):end]
        jt=transpose(J)*lambda; ct=transpose(C)*mu_eq; bstat=zeros(Float64,n)
        for (a,i) in enumerate(active); bstat[i]=column_scales[i]*mu_bound[a]; end
        stationarity=jt+ct+bstat; ls_eq=Jy.-lambda.+f; eq_eq=C*scaled_direction.+c
        active_eq=state[active].+physical_step[active]
        maxabs(x)=maximum(abs.(x);init=0.0)
        stat_abs=maxabs(stationarity)
        stat_rel=stat_abs/max(1.0,maxabs(jt),maxabs(ct),maxabs(bstat))
        ls_rel=maxabs(ls_eq)/max(1.0,maxabs(Jy),maxabs(lambda),maxabs(f))
        eq_rel=maxabs(eq_eq)/max(1.0,maxabs(C*scaled_direction),maxabs(c))
        active_rel=maxabs(active_eq)/max(1.0,maxabs(physical_step[active]),maxabs(state[active]))
        defect=maximum((stat_rel,ls_rel,eq_rel,active_rel))
        rhs_norm=sqrt(sum(abs2,f)+sum(abs2,c)+sum(abs2,state[active]))
        true_res=sqrt(sum(abs2,stationarity)+sum(abs2,ls_eq)+sum(abs2,eq_eq)+sum(abs2,active_eq))
        true_rel=iszero(rhs_norm) ? true_res : true_res/rhs_norm
        float64_shadow=(stationarity=stat_abs,stationarity_relative=stat_rel,
            equality_multipliers=copy(mu_eq),active_bound_multipliers=copy(mu_bound),
            block_defect=defect,least_squares_relative=ls_rel,equality_relative=eq_rel,
            active_bound_relative=active_rel,true_kkt_relative_defect=true_rel,
            true_kkt_absolute_residual=true_res,true_kkt_rhs_norm=rhs_norm,
            schur_relative_residual=schur_rel,
            original_kkt_gate=stat_abs<=stationarity_tolerance && defect<=stationarity_tolerance,
            true_kkt_gate=true_rel<=1e-8,schur_gate=schur_rel<=1e-8)
        accurate_kkt=nothing
        if all(isfinite,(stat_abs,defect,true_rel,schur_rel)) &&
                isempty(violating) &&
                !(float64_shadow.original_kkt_gate && float64_shadow.true_kkt_gate && float64_shadow.schur_gate)
            # Include retained BF vectors, sparse actions, small dense solve
            # temporaries and serialization headroom in the original inner
            # working-set gate. The outer process remains limited to 4 GiB.
            high_precision_reserve=Int128(128)*(Int128(12)*n+Int128(8)*size(J,1)+
                Int128(6)*size(C,1)+Int128(5)*nullity^2+Int128(4)*augmented_rows*nullity)+Int128(32)*1024^2
            if estimate+high_precision_reserve>Int128(max_working_memory_bytes)
                checkpoint_path=get(ENV,"FUSION_C771_MASK_ACTIVE_HP_CHECKPOINT_PATH","")
                checkpoint_pin=nothing
                if !isempty(checkpoint_path)
                    # Preserve the unchanged numerical problem before releasing
                    # its large QR/GS workspaces. A fresh process can perform the
                    # same fixed-primal check without another factorization.
                    payload=(schema=:saved_C771_exact_high_precision_replay_v1,
                        status=:unverified_fixed_primal_candidate,
                        J=J,C=C,f=f,c=c,scaled_direction=scaled_direction,state=state,
                        physical_step=physical_step,column_scales=column_scales,
                        active=copy(active),L=L,schur_rhs=schur_rhs,Q2=Matrix(Q2),
                        candidate_hash=partition.identity.candidate_hash,
                        partition_hash=partition.partition_hash,
                        consumer_identity=partition.consumer_identity,
                        pressure_indices=copy(pressure_indices),
                        row_groups=map.row_groups,column_groups=map.column_groups,
                        free_columns=map.free_columns,
                        ordered_LS_ids=map.ordered_LS_ids,ordered_EQ_ids=map.ordered_EQ_ids,
                        iteration=iteration,active_set_trace=Tuple(trace),
                        schur_rank=schur_rank,schur_dimension=nullity,
                        schur_rank_threshold=schur_rank_threshold,
                        schur_rank_margin=schur_rank_margin,
                        schur_rank_gate_passed=schur_rank_gate_passed,
                        augmented_free_rank=aug_rank,free_column_count=length(free_cols),
                        float64_kkt_shadow=float64_shadow,
                        stationarity_tolerance=Float64(stationarity_tolerance),
                        bound_dual_tolerance=Float64(bound_dual_tolerance),
                        true_kkt_tolerance=1e-8,schur_tolerance=1e-8,
                        max_working_memory_bytes=Int128(max_working_memory_bytes),
                        new_assemblies=0,new_G_solves=0,
                        formal_acceptance=false,physical_validation=false)
                    checkpoint_pin=_exact_save_hp_replay_v1(checkpoint_path,payload)
                end
                return (status=:resource_interruption,reason=:exact_high_precision_working_memory_cap,
                    active_set_trace=Tuple(trace),active_bounds=key,float64_kkt_shadow=float64_shadow,
                    estimated_working_set_bytes=estimate+high_precision_reserve,
                    high_precision_reserved_bytes=high_precision_reserve,
                    primal_candidate_checkpoint=checkpoint_pin,
                    max_working_memory_bytes=Int128(max_working_memory_bytes),full_global_kkt=false)
            end
            accurate_kkt=_exact_fixed_primal_high_precision_kkt_v1(J,C,f,c,scaled_direction,state,
                physical_step,column_scales,active,L,schur_rhs,Q2)
            stat_abs=accurate_kkt.stationarity;stat_rel=accurate_kkt.stationarity_relative
            ls_rel=accurate_kkt.least_squares_relative;eq_rel=accurate_kkt.equality_relative
            active_rel=accurate_kkt.active_bound_relative;defect=accurate_kkt.block_defect
            true_res=accurate_kkt.true_kkt_absolute_residual;true_rel=accurate_kkt.true_kkt_relative_defect
            rhs_norm=accurate_kkt.true_kkt_rhs_norm;schur_rel=accurate_kkt.schur_relative_residual
            stationarity=accurate_kkt.stationarity_vector;bstat=accurate_kkt.bound_stationarity
            lambda=accurate_kkt.lambda;mu_eq=accurate_kkt.mu_eq;mu_bound=accurate_kkt.mu_bound
        end
        dual_bad=findall(v->v>bound_dual_tolerance,mu_bound)
        dual_violation=maximum((max(0.0,v) for v in mu_bound);init=0.0)
        complementarity=maximum((abs(updated[i]*(-mu_bound[a])) for (a,i) in enumerate(active));init=0.0)
        finite=all(isfinite,(defect,true_rel,schur_rel,violation,dual_violation,complementarity))
        active_capacity=max(0,1024-size(C,1))
        active_room=active_capacity-length(active)
        # A pressure-infeasible intermediate candidate selects the next bound
        # subproblem. Keep its failed true-KKT metric visible, and enforce the
        # strict true-KKT gate on every feasible candidate returned to callers.
        # Nonfinite or inaccurate stationarity/equality/Schur actions must not
        # choose active coordinates.
        (finite && stat_abs<=stationarity_tolerance && defect<=stationarity_tolerance &&
            schur_rel<=1e-8 && (true_rel<=1e-8 || !isempty(violating))) ||
            return (status=:numerical_fail,reason=:exact_row_pivot_original_KKT_gate,
                float64_kkt_shadow=float64_shadow,accurate_fixed_primal_kkt=accurate_kkt,
                true_kkt_residual_arithmetic=accurate_kkt===nothing ? :Float64 : :fixed_input_BigFloat256,
                active_set_trace=Tuple(trace),active_bounds=key,stationarity=stat_abs,
                stationarity_vector=stationarity,stationarity_relative=stat_rel,kkt_relative_defect=true_rel,
                block_defect=defect,least_squares_relative=ls_rel,equality_relative=eq_rel,
                active_bound_relative=active_rel,
                original_kkt_tolerance=stationarity_tolerance,original_kkt_gate=stat_abs<=stationarity_tolerance,
                true_kkt_relative_defect=true_rel,true_kkt_tolerance=1e-8,true_kkt_gate=true_rel<=1e-8,
                true_kkt_absolute_residual=true_res,true_kkt_rhs_norm=rhs_norm,
                schur_relative_residual=schur_rel,schur_relative_residual_float64=schur_float64_after_refinement,
                schur_gate=schur_rel<=1e-8,schur_dimension=nullity,schur_rank=schur_rank,
                schur_rank_method=:direct_lq_svd,schur_rank_threshold=schur_rank_threshold,
                schur_rank_threshold_units=:singular_value_of_D,
                legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                legacy_gram_threshold_units=:eigenvalue_of_DDt,
                rank_certificate=map.gs_native_rz===nothing ? :original_full_G_LU_pivot_gate : :not_established_for_full_G,
                pressure_lower_bound_violation=violation,
                pressure_bound_gate=violation<=bound_dual_tolerance,dual_violation=dual_violation,
                dual_gate=dual_violation<=bound_dual_tolerance,complementarity=complementarity,
                complementarity_gate=complementarity<=bound_dual_tolerance,
                schur_solve_diagnostic=(schema=:exact_lq_schur_solve_failure_v1,
                    active_bounds=key,iteration=iteration,factor=copy(L),rhs=copy(schur_rhs),
                    y=copy(y),eta=copy(eta),y_before_refinement=y_before_refinement,
                    eta_before_refinement=eta_before_refinement,refinement=refinement_metrics),
                last_candidate=(iteration=iteration,solved_active_bounds=key,next_active_bounds=key,
                    physical_step=copy(physical_step),scaled_direction=copy(scaled_direction),
                    updated_state=copy(updated),pressure_before=Tuple(state[pressure_indices]),
                    pressure_after=Tuple(pressure_after),pressure_violations=Tuple(violating),
                    stationarity=stat_abs,stationarity_relative=stat_rel,
                    stationarity_vector=copy(stationarity),least_squares_relative=ls_rel,
                    equality_relative=eq_rel,active_bound_relative=active_rel,block_defect=defect,
                    true_kkt_relative_defect=true_rel,true_kkt_absolute_residual=true_res,
                    true_kkt_rhs_norm=rhs_norm,schur_relative_residual=schur_rel,
                    schur_relative_residual_float64=schur_float64_after_refinement,
                    schur_rank=schur_rank,schur_dimension=nullity,
                    schur_rank_method=:direct_lq_svd,schur_rank_threshold=schur_rank_threshold,
                    legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                    pressure_violation=violation,dual_violation=dual_violation,
                    complementarity=complementarity,active_bound_multipliers=copy(mu_bound),
                    original_kkt_gate=stat_abs<=stationarity_tolerance,
                    true_kkt_gate=true_rel<=1e-8,schur_gate=schur_rel<=1e-8,
                    pressure_gate=violation<=bound_dual_tolerance,
                    dual_gate=dual_violation<=bound_dual_tolerance,
                    complementarity_gate=complementarity<=bound_dual_tolerance,
                    rank_certificate=map.gs_native_rz===nothing ? :original_full_G_LU_pivot_gate :
                        :not_established_for_full_G,
                    rank_boundary=map.gs_native_rz===nothing ? :original_full_G_LU_pivot_gate :
                        :not_established_for_full_G,
                    primal_pressure_gate=violation<=bound_dual_tolerance,
                    linearized_equalities_passed=eq_rel<=stationarity_tolerance,
                    bound_kkt_pass=violation<=bound_dual_tolerance &&
                        dual_violation<=bound_dual_tolerance && complementarity<=bound_dual_tolerance,
                    refinement=refinement_metrics,full_global_kkt=false),full_global_kkt=false)
        if !isempty(violating)
            if active_room<=0 && !isempty(dual_bad)
                released=Tuple(active[dual_bad]);deleteat!(active,dual_bad)
                push!(trace,(active_bounds=key,decision=:release_wrong_sign_duals_for_active_capacity,
                    active_released=released,active_bound_count=length(active),schur_dimension=nullity,
                    true_kkt_relative_defect=true_rel,pressure_violation=violation))
                continue
            end
            active_room>0 || return (status=:resource_interruption,
                reason=:exact_active_bound_capacity,active_set_trace=Tuple(trace),active_bounds=key,
                active_capacity=active_capacity,unadded_pressure_violations=Tuple(violating),
                full_global_kkt=false)
            active_added=length(violating)<=active_room ? violating :
                sort!(copy(violating);by=i->(updated[i],i))[1:active_room]
            append!(active,active_added);sort!(active)
            push!(trace,(active_bounds=key,decision=:add_primal_violations_within_schur_row_cap,
                active_added=Tuple(active_added),active_bound_count=length(active),
                unadded_pressure_violations=length(violating)-length(active_added),
                schur_dimension=nullity,kkt_relative_defect=true_rel,true_kkt_relative_defect=true_rel,
                kkt_rank=(rank=schur_rank,order=nullity,method=:direct_lq_svd,
                    threshold=schur_rank_threshold,threshold_units=:singular_value_of_D,
                    legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                    legacy_gram_threshold_units=:eigenvalue_of_DDt,scope=:transformed_schur_only),
                linear_solve=(status=true_rel<=1e-8 ? :ok : :pressure_infeasible_intermediate,
                    reason=true_rel<=1e-8 ? nothing : :activate_pressure_bounds_before_final_true_KKT_gate,
                    iterations=1,restarts=0,residual_norm=true_res,
                    residual_history=(),equilibration=:exact_row_pivot,estimated_working_set_bytes=estimate),
                pressure_violation=violation))
            last=(iteration=iteration,solved_active_bounds=key,
                next_active_bounds=Tuple(active),active_added=Tuple(active_added),
                physical_step=copy(physical_step),scaled_direction=copy(scaled_direction),
                updated_state=copy(updated),pressure_before=Tuple(state[pressure_indices]),
                pressure_after=Tuple(pressure_after),pressure_violations=Tuple(violating),
                stationarity=stat_abs,stationarity_relative=stat_rel,
                stationarity_vector=copy(stationarity),least_squares_relative=ls_rel,
                equality_relative=eq_rel,active_bound_relative=active_rel,block_defect=defect,
                true_kkt_relative_defect=true_rel,true_kkt_absolute_residual=true_res,
                true_kkt_rhs_norm=rhs_norm,schur_relative_residual=schur_rel,
                pressure_violation=violation,dual_violation=dual_violation,
                complementarity=complementarity,active_bound_multipliers=copy(mu_bound),
                primal_pressure_gate=false,linearized_equalities_passed=true,
                bound_kkt_pass=false,full_global_kkt=false)
            continue
        end
        if !isempty(dual_bad)
            released=Tuple(active[dual_bad]); deleteat!(active,dual_bad)
            push!(trace,(active_bounds=key,decision=:release_wrong_sign_duals,active_released=released,
                active_bound_count=length(active),schur_dimension=nullity,kkt_relative_defect=true_rel,
                true_kkt_relative_defect=true_rel,kkt_rank=(rank=schur_rank,order=nullity,method=:direct_lq_svd,
                    threshold=schur_rank_threshold,threshold_units=:singular_value_of_D,
                    legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                    legacy_gram_threshold_units=:eigenvalue_of_DDt,scope=:transformed_schur_only),
                linear_solve=(status=:ok,reason=nothing,iterations=1,restarts=0,residual_norm=true_res,
                    residual_history=(),equilibration=:exact_row_pivot,estimated_working_set_bytes=estimate)))
            last=(iteration=iteration,solved_active_bounds=key,
                next_active_bounds=Tuple(active),active_released=released,
                physical_step=copy(physical_step),scaled_direction=copy(scaled_direction),
                updated_state=copy(updated),pressure_before=Tuple(state[pressure_indices]),
                pressure_after=Tuple(pressure_after),pressure_violations=Tuple(violating),
                stationarity=stat_abs,stationarity_relative=stat_rel,
                stationarity_vector=copy(stationarity),least_squares_relative=ls_rel,
                equality_relative=eq_rel,active_bound_relative=active_rel,block_defect=defect,
                true_kkt_relative_defect=true_rel,true_kkt_absolute_residual=true_res,
                true_kkt_rhs_norm=rhs_norm,schur_relative_residual=schur_rel,
                pressure_violation=violation,dual_violation=dual_violation,
                complementarity=complementarity,active_bound_multipliers=copy(mu_bound),
                primal_pressure_gate=violation<=bound_dual_tolerance,
                linearized_equalities_passed=true,bound_kkt_pass=false,full_global_kkt=false)
            continue
        end
        if violation>bound_dual_tolerance || dual_violation>bound_dual_tolerance
            return (status=:numerical_fail,reason=:exact_row_pivot_bound_gate,
                active_set_trace=Tuple(trace),active_bounds=key,pressure_lower_bound_violation=violation,
                dual_violation=dual_violation,full_global_kkt=false)
        end
        push!(trace,(active_bounds=key,decision=:active_set_kkt_gates_passed,
            active_bound_count=length(active),schur_dimension=nullity,kkt_relative_defect=true_rel,
            true_kkt_relative_defect=true_rel,kkt_rank=(rank=schur_rank,order=nullity,method=:direct_lq_svd,
                threshold=schur_rank_threshold,threshold_units=:singular_value_of_D,
                legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
                legacy_gram_threshold_units=:eigenvalue_of_DDt,scope=:transformed_schur_only),
            linear_solve=(status=:ok,reason=nothing,iterations=1,restarts=0,residual_norm=true_res,
                residual_history=(),equilibration=:exact_row_pivot,estimated_working_set_bytes=estimate),
            pressure_violation=violation,dual_violation=dual_violation))
        return (status=:ok,reason=:diagnostic_exact_bound_step_ok,step=copy(physical_step),steps=Tuple(trace),
            float64_kkt_shadow=float64_shadow,accurate_fixed_primal_kkt=accurate_kkt,
            true_kkt_residual_arithmetic=accurate_kkt===nothing ? :Float64 : :fixed_input_BigFloat256,
            active_bounds=key,active_set_trace=Tuple(trace),
            linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
            bound_constrained_kkt=true,full_global_kkt=false,full_kkt_acceptance=false,
            stationarity=stat_abs,stationarity_vector=stationarity,bound_stationarity=bstat,
            stationarity_relative=stat_rel,equilibrium_relative=ls_rel,equality_relative=eq_rel,
            active_bound_relative=active_rel,equality_multipliers=mu_eq,
            active_bound_multipliers=mu_bound,least_squares_multipliers=lambda,
            state_before=copy(state),state_after=copy(updated),physical_step=copy(physical_step),
            scaled_direction=copy(scaled_direction),pressure_before=Tuple(state[pressure_indices]),
            pressure_after=Tuple(pressure_after),column_scales=copy(column_scales),
            elapsed_seconds=(time_ns()-method_started)/1e9,dual_violation=dual_violation,
            complementarity=complementarity,kkt_relative_defect=true_rel,true_kkt_relative_defect=true_rel,
            true_kkt_rhs_norm=rhs_norm,true_kkt_absolute_residual=true_res,
            true_kkt_residual_policy=:original_augmented_system_2norm_over_rhs_2norm,
            true_kkt_tolerance=1e-8,true_kkt_gate=true_rel<=1e-8,original_kkt_tolerance=stationarity_tolerance,
            original_kkt_gate=stat_abs<=stationarity_tolerance,
            pressure_lower_bound_violation=violation,pressure_bound_gate=violation<=bound_dual_tolerance,
            dual_gate=dual_violation<=bound_dual_tolerance,pressure_indices=Tuple(pressure_indices),
            minimum_pressure_before=minimum(state[pressure_indices];init=Inf),
            minimum_pressure_after=minimum(pressure_after;init=Inf),
            pressure_violations=Tuple(i for i in pressure_indices if updated[i]<0.0),
            pressure_violations_over_tolerance=Tuple(i for i in pressure_indices if updated[i]<-bound_dual_tolerance),
            negative_pressure_count=count(<(0.0),pressure_after),active_set_iteration=iteration,
            active_set_iteration_limit=max_active_set_iterations,block_defect=defect,
            schur_dimension=nullity,schur_rank=schur_rank,schur_rank_method=:direct_lq_svd,
            schur_rank_threshold=schur_rank_threshold,
            schur_rank_threshold_units=:singular_value_of_D,
            schur_minimum_singular_value=minimum(schur_singular_values;init=Inf),
            schur_maximum_singular_value=schur_sigma_maximum,
            schur_rank_margin=schur_rank_margin,
            schur_rank_margin_relative=iszero(schur_sigma_maximum) ? Inf :
                schur_rank_margin/schur_sigma_maximum,
            schur_singular_values=Tuple(schur_singular_values),
            schur_relative_residual=schur_rel,
            schur_relative_residual_float64=schur_float64_after_refinement,
            schur_refinement=refinement_metrics,
            legacy_gram_rank=legacy_gram_rank,legacy_gram_threshold=legacy_gram_threshold,
            legacy_gram_threshold_units=:eigenvalue_of_DDt,
            legacy_gram_minimum_eigenvalue=minimum(legacy_gram_eigenvalues;init=Inf),
            legacy_gram_maximum_eigenvalue=legacy_gram_maximum,
            legacy_gram_eigenvalues=Tuple(legacy_gram_eigenvalues),
            estimated_working_set_bytes=estimate,
            max_working_memory_bytes=Int128(max_working_memory_bytes),scope=:initial_linearized_incomplete_global_assembly,
            gs_preconditioner=map.gs_native_rz===nothing ? :full_G_LU :
                (map.gs_fd3_payload===nothing ? :native_band : :exact_native_spline_mixed_metis),
            gs_mixed_factor_report=mixed_build===nothing ? nothing : mixed_build.report,
            gs_inverse_solve_reports=Tuple(gs_inverse_reports),
            rank_certificate=map.gs_native_rz===nothing ? :original_full_G_LU_pivot_gate : :not_established_for_full_G,
            transform_bijectivity=map.gs_native_rz===nothing ? :original_LU_elimination : :not_established,
            inverse_action_semantics=:full_G_true_residual_checked,
            nonlinear_descent=:not_executed,physical_validation=false)
    end
    (status=:numerical_fail,reason=:active_set_iteration_limit,active_set_trace=Tuple(trace),
        active_bounds=Tuple(active),last_candidate=last,full_global_kkt=false)
end

"""Solve one weighted-residual Gauss-Newton step with exact KKT rows and bounds.

This is the numerical step entry point for assembled residual consumers. The
least-squares rows are minimized in their supplied scaled coordinates;
positive equality-row scaling preserves exact zero sets, and `pressure_indices`
select state coordinates constrained to remain nonnegative. It applies a
matrix-free symmetric KKT operator with bounded restarted GMRES, blockwise
original-system residual checks, and a conservative working-set preflight. It
does not form or factor the saddle-point matrix. Krylov convergence is not a
rank certificate; nonconvergence and memory/time caps return explicit failure
or resource-interruption outcomes. Supplying `exact_row_pivot_map` opts into the
specialized exact QR/nullspace active-set backend for an incomplete-global
numeric partition. That route validates the numeric index map and matrix block
structure, reports its backend plainly, and carries no solver-semantic hash or
physical-validation authority.
"""
function _column_scaled_sparse_copy_v1(matrix::SparseMatrixCSC{Float64,Ti}, scales) where {Ti<:Integer}
    length(scales) == size(matrix, 2) ||
        throw(ArgumentError("sparse column scale count differs from matrix width"))
    result = copy(matrix)
    values = nonzeros(result)
    for column in 1:size(result, 2)
        scale = scales[column]
        for index in result.colptr[column]:(result.colptr[column + 1] - 1)
            @inbounds values[index] *= scale
        end
    end
    return result
end

function _validate_reusable_scaled_jacobian_v1(partition, candidate, scales)
    candidate isa SparseMatrixCSC{Float64,Int} ||
        throw(ArgumentError("reusable scaled Jacobian must be Float64 CSC with Int indices"))
    source = partition.scaled_least_squares_jacobian
    size(candidate) == size(source) ||
        throw(ArgumentError("reusable scaled Jacobian dimensions differ from the partition"))
    candidate.colptr == source.colptr && candidate.rowval == source.rowval ||
        throw(ArgumentError("reusable scaled Jacobian CSC structure differs from the partition"))
    length(scales) == size(source, 2) ||
        throw(ArgumentError("reusable scaled Jacobian column scales are incomplete"))
    candidate_values = nonzeros(candidate)
    source_values = nonzeros(source)
    length(candidate_values) == length(source_values) ||
        throw(ArgumentError("reusable scaled Jacobian nonzero count differs from the partition"))
    for column in 1:size(source, 2)
        scale = scales[column]
        for index in source.colptr[column]:(source.colptr[column + 1] - 1)
            candidate_values[index] == source_values[index] * scale ||
                throw(ArgumentError("reusable scaled Jacobian values differ from the partition"))
        end
    end
    return candidate
end

function solve_weighted_residual_kkt_step_v1(partition; scaled_state,
        column_scales=ones(length(scaled_state)), pressure_indices=(),
        stationarity_tolerance, bound_dual_tolerance,
        max_active_set_iterations, seconds=Inf,
        max_working_memory_bytes=3*1024^3, exact_row_pivot_map=nothing,
        diagnostic_transpose_rhs=nothing, precomputed_scaled_jacobian=nothing)
    hasproperty(partition, :identity) && hasproperty(partition, :partition_hash) &&
        partition.identity.schema == "weighted-residual-kkt-partition-v1" &&
        partition.partition_hash == string(canonical_hash(partition.identity)) ||
        throw(ArgumentError("weighted-residual KKT step requires an intact partition identity"))
    exact_row_pivot_map===nothing && partition.identity.solver_semantic_hash !=
        weighted_residual_kkt_step_identity_v1().solver_semantic_hash &&
        throw(ArgumentError("weighted-residual KKT partition solver identity is malformed"))
    state = Float64.(collect(scaled_state))
    scales = Float64.(collect(column_scales))
    length(scales) == length(state) && all(s -> isfinite(s) && s > 0.0, scales) ||
        throw(ArgumentError("step column scales must be finite, positive, and state-complete"))
    f = partition.scaled_least_squares_residual
    c = partition.equality_residual
    n = size(partition.scaled_least_squares_jacobian, 2)
    length(unique(pressure_indices)) == length(pressure_indices) &&
        all(i -> i isa Integer && 1 <= i <= n, pressure_indices) ||
        throw(ArgumentError("pressure bound indices are invalid or duplicated"))
    length(state) == n && all(isfinite, state) &&
        all(i -> state[i] >= 0.0, pressure_indices) ||
        throw(ArgumentError("scaled state dimensions or nonnegative pressure bounds are invalid"))
    stationarity_tolerance isa Real && !(stationarity_tolerance isa Bool) &&
        isfinite(stationarity_tolerance) && stationarity_tolerance > 0.0 ||
        throw(ArgumentError("stationarity tolerance must be finite and positive"))
    bound_dual_tolerance isa Real && !(bound_dual_tolerance isa Bool) &&
        isfinite(bound_dual_tolerance) && bound_dual_tolerance > 0.0 ||
        throw(ArgumentError("bound dual tolerance must be finite and positive"))
    max_active_set_iterations isa Integer && !(max_active_set_iterations isa Bool) &&
        max_active_set_iterations > 0 ||
        throw(ArgumentError("active-set iteration limit must be a positive integer"))
    max_working_memory_bytes isa Integer && !(max_working_memory_bytes isa Bool) &&
        max_working_memory_bytes > 0 ||
        throw(ArgumentError("matrix-free working-memory cap must be a positive integer byte count"))
    seconds isa Real && !(seconds isa Bool) && !isnan(seconds) && seconds >= 0.0 ||
        throw(ArgumentError("step wall-time allowance must be nonnegative"))
    size(partition.scaled_least_squares_jacobian,1)==length(f) &&
        size(partition.equality_jacobian)==(length(c),n) ||
        throw(ArgumentError("partition step residual/Jacobian dimensions differ"))
    diagnostic_transpose_rhs===nothing || exact_row_pivot_map!==nothing ||
        throw(ArgumentError("diagnostic transpose action requires the exact row-pivot map"))
    reusable_jacobian = precomputed_scaled_jacobian === nothing ? nothing :
        _validate_reusable_scaled_jacobian_v1(partition, precomputed_scaled_jacobian, scales)
    if exact_row_pivot_map!==nothing
        exact_row_pivot_map isa ExactRowPivotKKTMapV1 ||
            throw(ArgumentError("exact row-pivot backend requires ExactRowPivotKKTMapV1"))
        exact=try
            _exact_row_pivot_kkt_step_v1(partition,state,scales,Int.(collect(pressure_indices)),
                exact_row_pivot_map;stationarity_tolerance=Float64(stationarity_tolerance),
                bound_dual_tolerance=Float64(bound_dual_tolerance),
                max_active_set_iterations=Int(max_active_set_iterations),seconds=Float64(seconds),
                max_working_memory_bytes=max_working_memory_bytes,
                diagnostic_transpose_rhs=diagnostic_transpose_rhs,
                precomputed_scaled_jacobian=reusable_jacobian)
        catch err
            err isa GSNumericInverseFailureV1 ? merge(err.result,
                (linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,backend=:exact_row_pivot_active_set,
                 full_global_kkt=false,science_credit=false)) :
            let bounded=_bounded_exact_kkt_exception_v1(err,catch_backtrace())
                (status=err isa OutOfMemoryError ? :resource_interruption : :program_exception,
                    reason=err isa OutOfMemoryError ? :exact_row_pivot_out_of_memory : :exact_row_pivot_exception,
                    exception_summary=bounded.summary,detail=bounded.summary.message,
                    failure_stack=bounded.frames,
                    linear_solver=:exact_qr_nullspace_active_pressure_row_pivot,
                    backend=:exact_row_pivot_active_set,full_global_kkt=false)
            end
        end
        return merge((schema="inhouse-weighted-residual-kkt-step-v1",
            partition_hash=partition.partition_hash,column_scales=copy(scales),
            column_scale_hash=string(canonical_hash(Tuple(scales))),
            exact_backend_schema=exact_row_pivot_map.schema,
            exact_row_groups=Tuple(copy(g) for g in exact_row_pivot_map.row_groups),
            exact_column_groups=Tuple(copy(g) for g in exact_row_pivot_map.column_groups),
            exact_free_columns=copy(exact_row_pivot_map.free_columns),
            steps=get(exact,:steps,get(exact,:active_set_trace,())),active_set_trace=()),exact)
    end
    q=count(i->iszero(state[i]),pressure_indices)
    order=n+length(f)+length(c)+q
    J_preflight=partition.scaled_least_squares_jacobian
    C_preflight=partition.equality_jacobian
    schur_dimension=size(C_preflight,1)+q
    working_set_estimate=_matrix_free_working_set_bytes(J_preflight,C_preflight,order;
        restart=min(_KKT_GMRES_RESTART_CAP,order),schur_dimension=schur_dimension)
    if schur_dimension>_KKT_DIAG_SCHUR_MAX_DIM || working_set_estimate>Int128(max_working_memory_bytes)
        identity=weighted_residual_kkt_step_identity_v1()
        return (schema="inhouse-weighted-residual-kkt-step-v1",
            solver_semantic_hash=identity.solver_semantic_hash,step_identity=identity,
            step_identity_hash=string(canonical_hash(identity)),partition_hash=partition.partition_hash,
            column_scales=Tuple(scales),column_scale_hash=string(canonical_hash(Tuple(scales))),
            status=:resource_interruption,
            reason=schur_dimension>_KKT_DIAG_SCHUR_MAX_DIM ?
                :kkt_preconditioner_schur_dimension_cap : :matrix_free_working_set_cap,
            detail=(estimated_working_set_bytes=working_set_estimate,
                max_working_memory_bytes=Int128(max_working_memory_bytes),
                schur_dimension=schur_dimension,max_schur_dimension=_KKT_DIAG_SCHUR_MAX_DIM,
                scope=:kkt_workspace_and_preconditioner),
            active_bounds=(),active_set_trace=(),linear_solver=:bounded_matrix_free_restarted_gmres,
            max_working_memory_bytes=Int128(max_working_memory_bytes),
            estimated_working_set_bytes=working_set_estimate,
            rank_certificate=:not_established_matrix_free_krylov)
    end
    step_policy = (stationarity_tolerance=Float64(stationarity_tolerance),
        bound_dual_tolerance=Float64(bound_dual_tolerance),
        max_active_set_iterations=Int(max_active_set_iterations),
        gmres_restart=_KKT_GMRES_RESTART_CAP,gmres_iteration_limit=1000,gmres_stagnation_cycles=5,
        max_working_memory_bytes=Int128(max_working_memory_bytes),
        compact_trace=true,
        deadline_ns=isfinite(seconds) ? time_ns() + round(Int, Float64(seconds) * 1.0e9) : typemax(Int64))
    solved = try
        J = reusable_jacobian === nothing ?
            _column_scaled_sparse_copy_v1(partition.scaled_least_squares_jacobian,scales) : reusable_jacobian
        C = _column_scaled_sparse_copy_v1(partition.equality_jacobian,scales)
        _active_kkt_step_matrix_free(J, f, C, c, state, scales, pressure_indices, step_policy)
    catch err
        (status=err isa OutOfMemoryError ? :resource_interruption : :program_exception,
            reason=err isa OutOfMemoryError ? :matrix_free_kkt_out_of_memory : :matrix_free_kkt_exception,
            detail=sprint(showerror,err),steps=())
    end
    active_trace = Tuple((active_bounds=s.active_bounds,
        kkt_rank=hasproperty(s, :kkt_rank) ? s.kkt_rank : nothing,
        linear_solve=hasproperty(s, :linear_solve) ? s.linear_solve : nothing,
        kkt_relative_defect=hasproperty(s, :kkt_relative_defect) ? s.kkt_relative_defect : nothing)
        for s in solved.steps)
    base = (schema="inhouse-weighted-residual-kkt-step-v1",
        solver_semantic_hash=weighted_residual_kkt_step_identity_v1().solver_semantic_hash,
        step_identity=weighted_residual_kkt_step_identity_v1(),
        step_identity_hash=string(canonical_hash(weighted_residual_kkt_step_identity_v1())),
        partition_hash=partition.partition_hash,
        column_scales=Tuple(scales),
        column_scale_hash=string(canonical_hash(Tuple(scales))),
        status=solved.status, reason=get(solved, :reason, nothing),
        detail=get(solved, :detail, get(solved, :error, nothing)),
        active_bounds=get(solved, :active_bounds, ()), active_set_trace=active_trace,
        linear_solver=:bounded_matrix_free_restarted_gmres,
        max_working_memory_bytes=Int128(max_working_memory_bytes),
        estimated_working_set_bytes=get(solved,:estimated_working_set_bytes,nothing),
        rank_certificate=get(solved,:rank_certificate,:not_established_matrix_free_krylov))
    solved.status === :ok ? merge(base, (step=Tuple(solved.step),
        stationarity=solved.stationarity, dual_violation=solved.dual_violation,
        complementarity=solved.complementarity,
        kkt_relative_defect=solved.kkt_relative_defect)) : base
end

_merit(f, c) = 0.5 * (dot(f, f) + dot(c, c))

function _equilibrium_system_v1(m, a)
    if m.equilibrium_row_scales === nothing
        return (residual=a.residual, jacobian=a.jacobian,
            row_scales=nothing, row_scale_hash=nothing)
    end
    length(m.equilibrium_row_scales) == length(a.residual) ||
        throw(ArgumentError("equilibrium row scales do not cover the assembled residual"))
    if hasproperty(a, :scaled_residual) && hasproperty(a, :scaled_jacobian) &&
            hasproperty(a, :equilibrium_row_scale_hash)
        a.equilibrium_row_scales == m.equilibrium_row_scales &&
            a.equilibrium_row_scale_hash == string(canonical_hash(m.equilibrium_row_scales)) ||
            throw(ArgumentError("assembled equilibrium scale identity differs from frozen model"))
        return (residual=a.scaled_residual, jacobian=a.scaled_jacobian,
            row_scales=m.equilibrium_row_scales,
            row_scale_hash=a.equilibrium_row_scale_hash)
    end
    residual = a.residual ./ m.equilibrium_row_scales
    jacobian = spdiagm(0 => 1.0 ./ collect(m.equilibrium_row_scales)) * a.jacobian
    all(isfinite, residual) && all(isfinite, nonzeros(jacobian)) ||
        throw(ArgumentError("scaled equilibrium residual/Jacobian is nonfinite"))
    (residual=residual, jacobian=jacobian,
     row_scales=m.equilibrium_row_scales,
     row_scale_hash=string(canonical_hash(m.equilibrium_row_scales)))
end

function _equilibrium_trace_fields_v1(m, a)
    m.equilibrium_row_scales === nothing && return (;)
    system = _equilibrium_system_v1(m, a)
    (raw_equilibrium_residual=Tuple(a.residual),
     raw_equilibrium_jacobian=_matrix_snapshot(a.jacobian),
     equilibrium_row_scales=system.row_scales,
     equilibrium_row_scale_hash=system.row_scale_hash,
     scaled_equilibrium_residual=Tuple(system.residual),
     scaled_equilibrium_jacobian=_matrix_snapshot(system.jacobian))
end

function _trace_eval(a, m=nothing)
    body = (candidate_hash=a.candidate_hash, model_hash=a.model_hash,
        residual=Tuple(a.residual), jacobian=_matrix_snapshot(a.jacobian),
        equality_residual=Tuple(a.equality_residual),
        equality_jacobian=_matrix_snapshot(a.equality_jacobian),
        conservation_residual=Tuple(a.conservation_residual),
        conservation_defect=a.conservation_defect,
        jacobian_checks=a.jacobian_checks,
        row_ownership=a.row_ownership,
        raw_blocks=(regions=Tuple((residual=Tuple(b.residual),
            jacobian=_matrix_snapshot(b.jacobian)) for b in a.raw_blocks.regions),
            edge_equilibrium=Tuple((edge_id=b.edge.edge_id,
                minus_residual=Tuple(b.minus_residual),
                plus_residual=Tuple(b.plus_residual),
                jacobian_minus_minus=_matrix_snapshot(b.jacobian_minus_minus),
                jacobian_minus_plus=_matrix_snapshot(b.jacobian_minus_plus),
                jacobian_plus_minus=_matrix_snapshot(b.jacobian_plus_minus),
                jacobian_plus_plus=_matrix_snapshot(b.jacobian_plus_plus),
                global_jacobian=_matrix_snapshot(b.global_jacobian),
                oracle_check=b.oracle_check) for b in a.raw_blocks.edge_equilibrium),
            interface=a.raw_blocks.interface === nothing ? nothing : (residual=Tuple(a.raw_blocks.interface.residual),
                jacobian_minus=_matrix_snapshot(a.raw_blocks.interface.jacobian_minus),
                jacobian_plus=_matrix_snapshot(a.raw_blocks.interface.jacobian_plus)),
            interfaces=Tuple((edge_id=edge.edge_id, constraint_ids=edge.constraint_ids,
                residual=Tuple(edge.residual),
                jacobian_minus=_matrix_snapshot(edge.jacobian_minus),
                jacobian_plus=_matrix_snapshot(edge.jacobian_plus))
                for edge in a.raw_blocks.interfaces),
            outer=Tuple((residual=Tuple(b.residual),
                jacobian=_matrix_snapshot(b.jacobian)) for b in a.raw_blocks.outer),
            conservation=(residual=Tuple(a.raw_blocks.conservation.residual),
                jacobian=_matrix_snapshot(a.raw_blocks.conservation.jacobian))))
    if m !== nothing && m.scale_contract !== nothing
        body=merge(body,(scale_contract=m.scale_contract,
            scale_contract_hash=m.scale_contract.contract_hash))
    end
    if m !== nothing && m.equilibrium_row_scales !== nothing
        return merge(body, _equilibrium_trace_fields_v1(m, a))
    end
    body
end

function _base_result(status, m, p, signature; missing=(), trace=(), updates=0,
        initial_state=(), final_state=(), final_metrics=nothing, failure=nothing)
    body = (revision=_REVISION, status=status, candidate_hash=m.candidate_hash,
        model_hash=m.model_hash, policy_hash=p.policy_hash,
        capability_signature=signature, missing_closures=missing,
        updates=updates, initial_state=Tuple(initial_state),
        final_state=Tuple(final_state),
        final_metrics=final_metrics, raw_trace=Tuple(trace), failure=failure,
        solver_convergence_criteria_met=status === :converged,
        solver_convergence_validated=false,
        independent_replay_validated=false, formal_consumer_connected=false,
        multiregion_closure=false, physical_validation=false,
        engineering_validation=false, emits_evidence=false, grants_pass=false,
        promotion_authority=false, terminal_authority=false,
        credible_physical_device_count=0,
        claim_ceiling=:numerical_mechanism_only)
    merge(body, (result_hash=string(canonical_hash(body)),))
end

"Run constrained global Gauss-Newton with pressure active set and backtracking."
function solve_coupled_mhd_global_v1(m::CoupledMHDGlobalModelV1,
        initial_state::AbstractVector, policy::CoupledMHDGlobalPolicyV1)
    _validate_policy(policy)
    _validate_model(m)
    signature = coupled_mhd_capability_signature_v1(m)
    x = Float64.(collect(initial_state))
    length(x) == _global_dof_count(m) && all(isfinite, x) ||
        throw(ArgumentError("initial state dimensions or values are invalid"))
    all(i -> x[i] >= 0.0, m.pressure_indices) ||
        throw(ArgumentError("initial pressure state violates nonnegative-pressure bound"))
    missing = signature.missing_closures
    isempty(missing) || return _base_result(:typed_absent, m, policy, signature;
        missing=missing, initial_state=x, final_state=x,
        failure=(kind=:missing_required_closure, detail=missing))
    x0 = Tuple(x)
    start = time_ns(); traces = NamedTuple[]; no_progress = 0
    last_metrics = nothing
    for update in 0:policy.max_updates
        (time_ns() - start) / 1e9 <= policy.wall_seconds ||
            return _base_result(:resource_interruption, m, policy, signature;
                trace=traces, updates=max(0, update - 1), initial_state=x0, final_state=x,
                final_metrics=last_metrics, failure=(kind=:wall_budget_exceeded,))
        assembled = try
            assemble_coupled_mhd_global_v1(m, x)
        catch err
            return _base_result(:program_exception, m, policy, signature;
                trace=traces, updates=max(0, update - 1), initial_state=x0, final_state=x,
                final_metrics=last_metrics,
                failure=(kind=:provider_or_assembly_exception,
                    error=sprint(showerror, err)))
        end
        assembled.status === :assembled || return _base_result(assembled.status, m,
            policy, signature; missing=assembled.missing_closures,
            trace=traces, updates=max(0, update - 1), initial_state=x0, final_state=x,
            final_metrics=last_metrics)
        equilibrium = _equilibrium_system_v1(m, assembled)
        f = equilibrium.residual; J = equilibrium.jacobian
        c = assembled.equality_residual; C = assembled.equality_jacobian
        raw = _trace_eval(assembled, m)
        max_f = _maxabs(f); max_c = _maxabs(c); merit = _merit(f, c)
        conservation_defect = assembled.conservation_defect
        step_policy = (stationarity_tolerance=policy.stationarity_tolerance,
            bound_dual_tolerance=policy.bound_dual_tolerance,
            max_active_set_iterations=policy.max_active_set_iterations,
            gmres_restart=_KKT_GMRES_RESTART_CAP,gmres_iteration_limit=1000,
            gmres_stagnation_cycles=5,max_working_memory_bytes=3*1024^3,
            compact_trace=true,
            deadline_ns=start + round(Int, policy.wall_seconds * 1.0e9))
        step_result = try
            _active_kkt_step_matrix_free(J, f, C, c, x,
                ones(length(x)),m.pressure_indices,step_policy)
        catch err
            (status=err isa OutOfMemoryError ? :resource_interruption : :program_exception,
                reason=err isa OutOfMemoryError ? :matrix_free_kkt_out_of_memory : :matrix_free_kkt_exception,
                detail=sprint(showerror,err),steps=())
        end
        push!(traces, (update=update, state=Tuple(x), evaluation=raw,
            kkt_active_set=step_result.steps, active_bounds=get(step_result, :active_bounds, ()),
            proposed_step=hasproperty(step_result, :step) ? Tuple(step_result.step) : (),
            solver_status=step_result.status,
            solver_reason=get(step_result, :reason, nothing)))
        if step_result.status !== :ok
            failure_status = step_result.status in (:resource_interruption,:program_exception) ?
                step_result.status : :numerical_fail
            return _base_result(failure_status, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=(max_residual=max_f, max_constraint=max_c,
                    conservation_defect=conservation_defect, merit=merit),
                failure=(kind=step_result.reason,
                    detail=get(step_result, :detail,
                        get(step_result, :error, nothing))))
        end
        if (time_ns() - start) / 1e9 > policy.wall_seconds
            return _base_result(:resource_interruption, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=(max_residual=max_f, max_constraint=max_c,
                    conservation_defect=conservation_defect, merit=merit),
                failure=(kind=:wall_budget_exceeded_during_linear_solve,))
        end
        last_metrics = (max_residual=max_f, max_constraint=max_c,
            conservation_defect=conservation_defect, merit=merit,
            stationarity=step_result.stationarity,
            bound_dual_violation=step_result.dual_violation,
            complementarity=step_result.complementarity,
            step_norm=_maxabs(step_result.step))
        if m.equilibrium_row_scales !== nothing
            last_metrics = merge(last_metrics,
                (max_raw_equilibrium_residual=_maxabs(assembled.residual),
                 max_scaled_equilibrium_residual=max_f,
                 residual_tolerance_basis=:scaled_equilibrium_rows,
                 equilibrium_row_scales=equilibrium.row_scales,
                 equilibrium_row_scale_hash=equilibrium.row_scale_hash))
        end
        raw_residual_gate=m.equilibrium_row_scales===nothing ||
            _maxabs(assembled.residual)<=policy.residual_tolerance
        converged = max_f <= policy.residual_tolerance && raw_residual_gate &&
            max_c <= policy.constraint_tolerance &&
            conservation_defect <= policy.constraint_tolerance &&
            step_result.stationarity <= policy.stationarity_tolerance &&
            step_result.dual_violation <= policy.bound_dual_tolerance &&
            step_result.complementarity <= policy.complementarity_tolerance &&
            _maxabs(step_result.step) <= policy.step_tolerance
        if converged
            return _base_result(:converged, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics)
        end
        if update == policy.max_updates
            break
        end
        accepted = false; trial_record = nothing
        directional = dot(f, J * step_result.step) + dot(c, C * step_result.step)
        isfinite(directional) && directional < 0.0 ||
            return _base_result(:numerical_fail, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics,
                failure=(kind=:non_descent_constrained_direction,
                    directional_derivative=directional))
        verify_source_v1(joinpath(@__DIR__, "MultiTopologyNonlinearSolveV1.jl"))
        binding_guard = () -> begin
            _validate_model(m)
            _validate_policy(policy)
            string(canonical_hash((candidate_hash=m.candidate_hash,
                model_hash=m.model_hash, provider_context_hash=m.provider_context_hash,
                policy_hash=policy.policy_hash,
                solver_identity=weighted_residual_kkt_step_identity_v1(),
                capability_signature=coupled_mhd_capability_signature_v1(m))))
        end
        step_search = try
            accepted_step_v1(x, step_result.step, ones(length(x));
                objective_before=merit, directional_derivative=directional,
                max_backtracks=policy.max_backtracks, alpha0=1.0,
                reduction=0.5, minimum_alpha=policy.minimum_step,
                armijo_fraction=policy.armijo_fraction,
                require_strict_decrease=false,
                assemble_trial=trial -> assemble_coupled_mhd_global_v1(m, trial),
                assembly_ready=a -> hasproperty(a, :status) && a.status === :assembled,
                unavailable_reason=a -> (kind=hasproperty(a, :status) ? a.status : :unknown,
                    missing=hasproperty(a, :missing_closures) ? a.missing_closures : ()),
                residual_for_merit=a -> vcat(_equilibrium_system_v1(m, a).residual,
                    a.equality_residual),
                merit=(a, _) -> _merit(_equilibrium_system_v1(m, a).residual,
                    a.equality_residual),
                project_state=identity,
                feasible=trial -> all(i -> trial[i] >= 0.0, m.pressure_indices),
                changed=(_, _) -> true,
                evaluation_record=a -> _trace_eval(a, m), binding_guard=binding_guard,
                continue_trial=()->(time_ns() - start) / 1e9 <= policy.wall_seconds)
        catch err
            return _base_result(:program_exception, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics,
                failure=(kind=:trial_evaluation_exception,
                    error=sprint(showerror, err)))
        end
        if step_search.status === :operator_unavailable
            if step_search.failure.kind === :typed_absent
                return _base_result(:typed_absent, m, policy, signature;
                    missing=step_search.failure.missing, trace=traces,
                    updates=update, initial_state=x0, final_state=x,
                    final_metrics=last_metrics,
                    failure=(kind=:missing_required_closure,
                        detail=step_search.failure.missing))
            end
            return _base_result(:numerical_fail, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics,
                failure=(kind=:trial_operator_unavailable,
                    detail=step_search.failure))
        end
        last_trial_index = nothing
        for trial_index in eachindex(step_search.trials)
            step_search.trials[trial_index].evaluated && (last_trial_index = trial_index)
        end
        if last_trial_index !== nothing
            t = step_search.trials[last_trial_index]
            trial_record = (backtrack=t.trial_index, alpha=t.alpha,
                state=t.state, evaluation=t.evaluation,
                merit=t.objective_after, armijo_bound=t.armijo_bound)
        end
        accepted = step_search.status === :accepted
        if accepted
            x = step_search.state
            trial_eval = step_search.accepted_assembly
            trial_equilibrium = _equilibrium_system_v1(m, trial_eval)
            last_metrics = (max_residual=_maxabs(trial_equilibrium.residual),
                max_constraint=_maxabs(trial_eval.equality_residual),
                conservation_defect=trial_eval.conservation_defect,
                merit=step_search.accepted_objective,
                accepted_state_hash=string(canonical_hash(Tuple(x))))
            if m.equilibrium_row_scales !== nothing
                last_metrics = merge(last_metrics,
                    (max_raw_equilibrium_residual=_maxabs(trial_eval.residual),
                     max_scaled_equilibrium_residual=_maxabs(trial_equilibrium.residual),
                     residual_tolerance_basis=:scaled_equilibrium_rows,
                     equilibrium_row_scales=trial_equilibrium.row_scales,
                     equilibrium_row_scale_hash=trial_equilibrium.row_scale_hash))
            end
        end
        push!(traces, (update=update, line_search=trial_record,
            accepted=accepted, accepted_alpha=accepted ? step_search.accepted_alpha : nothing))
        if (time_ns() - start) / 1e9 > policy.wall_seconds
            return _base_result(:resource_interruption, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics, failure=(kind=:wall_budget_exceeded,))
        end
        if !accepted
            return _base_result(:numerical_fail, m, policy, signature;
                trace=traces, updates=update, initial_state=x0, final_state=x,
                final_metrics=last_metrics,
                failure=(kind=:globalization_stagnation,))
        end
        new_merit = trial_record.merit
        no_progress = new_merit >= merit * (1.0 - 16eps(Float64)) ? no_progress + 1 : 0
        if no_progress >= policy.stagnation_window
            return _base_result(:numerical_fail, m, policy, signature;
                trace=traces, updates=update + 1, initial_state=x0, final_state=x,
                final_metrics=last_metrics, failure=(kind=:stagnation,))
        end
    end
    _base_result(:numerical_fail, m, policy, signature; trace=traces,
        updates=policy.max_updates, initial_state=x0, final_state=x, final_metrics=last_metrics,
        failure=(kind=:update_limit_without_all_frozen_gates,))
end

"Replay an in-memory raw trace in a fresh caller and compare exact trace bytes."
function replay_coupled_mhd_global_v1(m::CoupledMHDGlobalModelV1,
        initial_state::AbstractVector, policy::CoupledMHDGlobalPolicyV1,
        recorded_result)
    _validate_policy(policy)
    _validate_model(m)
    required = (:result_hash, :raw_trace, :candidate_hash, :model_hash,
        :policy_hash, :initial_state, :capability_signature, :final_state,
        :status)
    all(k -> hasproperty(recorded_result, k), required) ||
        throw(ArgumentError("recorded result does not contain a raw replay trace"))
    body = NamedTuple{Tuple(k for k in keys(recorded_result) if k !== :result_hash)}(
        Tuple(getproperty(recorded_result, k) for k in keys(recorded_result) if k !== :result_hash))
    string(canonical_hash(body)) == recorded_result.result_hash ||
        throw(ArgumentError("recorded result hash mismatch"))
    expected_initial_state = Tuple(Float64.(collect(initial_state)))
    signature = coupled_mhd_capability_signature_v1(m)
    identity_matches = (
        recorded_result.candidate_hash == m.candidate_hash,
        recorded_result.model_hash == m.model_hash,
        recorded_result.policy_hash == policy.policy_hash,
        recorded_result.initial_state == expected_initial_state,
        canonical_json(recorded_result.capability_signature) == canonical_json(signature),
    )
    all(identity_matches) || return (status=:replay_mismatch,
        reason=:recorded_candidate_model_policy_or_input_mismatch,
        identity_matches=identity_matches, candidate_hash=m.candidate_hash,
        recorded_result_hash=recorded_result.result_hash,
        replayed_result_hash=nothing, raw_trace_match=false,
        disposition_match=false, replayed_result=nothing,
        physical_authority=false, claim_ceiling=:numerical_mechanism_only)
    replayed = solve_coupled_mhd_global_v1(m, initial_state, policy)
    raw_trace_match = canonical_json(replayed.raw_trace) == canonical_json(recorded_result.raw_trace)
    disposition_match = canonical_json(replayed) == canonical_json(recorded_result)
    same = raw_trace_match && replayed.status === recorded_result.status &&
        replayed.final_state == recorded_result.final_state && disposition_match
    (status=same ? :replayed_exact : :replay_mismatch,
        candidate_hash=m.candidate_hash, recorded_result_hash=recorded_result.result_hash,
        replayed_result_hash=replayed.result_hash, raw_trace_match=raw_trace_match,
        disposition_match=disposition_match,
        replayed_result=replayed, physical_authority=false,
        claim_ceiling=:numerical_mechanism_only)
end

coupled_mhd_global_manifest_v1() = (
    revision=_REVISION,
    source_path=_SOURCE_PATH,
    solver_semantic_hash=weighted_residual_kkt_step_identity_v1().solver_semantic_hash,
    regions=:candidate_declared,
    interface_graph=:explicit_ordered_edges,
    global_regional_residual_and_jacobian=true,
    interface_equalities=true,
    shared_dof_scatter=:optional,
    edge_equilibrium_weak_residuals=:optional,
    outer_equalities=true,
    pressure_lower_bound_active_set=true,
    kkt_linearization=true,
    armijo_backtracking=true,
    raw_trace_replay=true,
    missing_required_closures=:typed_absent,
    pressure_current_topology_required=true,
    B_out_K_outer_return_current_path_required=true,
    solver_convergence_authority=:numerical_mechanism_only,
    multiregion_closure=false,
    physical_validation=false,
    engineering_validation=false,
    promotion_authority=false,
    credible_physical_device_count=0,
)

end # module
