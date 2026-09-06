# D2.2 sealed contracts for candidate-bound index-1 DAE time execution.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDAET_REVISION = "d2.2-v1"
const _TDAET_SCHEMA = "fusionconceptai:runtime-v4-typed-dae-time-execution"
const _TDAET_KIND = :typed_dae_time_execution_screen
const _TDAET_OPERATOR = "backward_euler_constant_mass_index1_dae"
const _TDAET_BACKEND = "julia-scaled-bounded-newton-backward-euler"
const _TDAET_GROUP = "julia-typed-dae-time-v1"
const _TDAET_TOKEN = Val(:typed_dae_time_execution_private)
const _TDAET_SOURCE_FILES =
    ("TypedDAETimeExecutionContracts.jl", "TypedDAETimeExecution.jl")

struct TypedDAETimeProtocolV4
    method::Symbol
    t_start::Float64
    t_stop::Float64
    step::Float64
    step_count::Int
    max_steps::Int
    time_scale::Float64
    time_unit::UnitSignature
    max_iterations::Int
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    correction_abs_tol::Float64
    finite_difference_step::Float64
    rank_relative_tol::Float64
    max_condition::Float64
    max_backtracks::Int
    protocol_hash::Digest256
    function TypedDAETimeProtocolV4(; method=:backward_euler,
            t_start=0.0, t_stop=0.4, step=0.1, max_steps=100,
            time_scale=1.0,
            time_unit=UnitSignature((0, 0, 1, 0, 0, 0, 0)),
            max_iterations=32, residual_abs_tol=1e-10,
            residual_rel_tol=1e-10, correction_abs_tol=1e-12,
            finite_difference_step=1e-7, rank_relative_tol=1e-10,
            max_condition=1e10, max_backtracks=20)
        method === :backward_euler ||
            throw(ArgumentError("D2.2 supports only backward Euler"))
        numbers = Float64[t_start, t_stop, step, time_scale,
            residual_abs_tol, residual_rel_tol, correction_abs_tol,
            finite_difference_step, rank_relative_tol, max_condition]
        all(isfinite, numbers) || throw(ArgumentError("nonfinite D2.2 protocol"))
        numbers[2] > numbers[1] && numbers[3] > 0 && numbers[4] > 0 &&
            all(>(0), numbers[5:end]) ||
            throw(ArgumentError("invalid D2.2 numerical protocol"))
        max_steps isa Integer && max_steps > 0 ||
            throw(ArgumentError("invalid D2.2 step budget"))
        max_iterations isa Integer && max_iterations > 0 ||
            throw(ArgumentError("invalid D2.2 Newton budget"))
        max_backtracks isa Integer && max_backtracks > 0 ||
            throw(ArgumentError("invalid D2.2 backtrack budget"))
        time_unit == UnitSignature((0, 0, 1, 0, 0, 0, 0)) ||
            throw(ArgumentError("D2.2 time unit must be exactly time"))
        raw_steps = (numbers[2] - numbers[1]) / numbers[3]
        steps = round(Int, raw_steps)
        isapprox(raw_steps, steps; rtol=0.0,
            atol=32eps(Float64) * max(1.0, abs(raw_steps))) ||
            throw(ArgumentError("D2.2 tspan must be an integer number of steps"))
        0 < steps <= max_steps ||
            throw(ArgumentError("D2.2 step count exceeds budget"))
        body = (revision=_TDAET_REVISION, method=method,
            t_start=numbers[1], t_stop=numbers[2], step=numbers[3],
            step_count=steps, max_steps=Int(max_steps),
            time_scale=numbers[4], time_unit=time_unit,
            max_iterations=Int(max_iterations), residual_abs_tol=numbers[5],
            residual_rel_tol=numbers[6], correction_abs_tol=numbers[7],
            finite_difference_step=numbers[8], rank_relative_tol=numbers[9],
            max_condition=numbers[10], max_backtracks=Int(max_backtracks))
        new(body.method, body.t_start, body.t_stop, body.step,
            body.step_count, body.max_steps, body.time_scale, body.time_unit,
            body.max_iterations, body.residual_abs_tol, body.residual_rel_tol,
            body.correction_abs_tol, body.finite_difference_step,
            body.rank_relative_tol, body.max_condition, body.max_backtracks,
            canonical_hash(body))
    end
end

semantic_view(x::TypedDAETimeProtocolV4) = (
    revision=_TDAET_REVISION, method=x.method, t_start=x.t_start,
    t_stop=x.t_stop, step=x.step, step_count=x.step_count,
    max_steps=x.max_steps, time_scale=x.time_scale, time_unit=x.time_unit,
    max_iterations=x.max_iterations, residual_abs_tol=x.residual_abs_tol,
    residual_rel_tol=x.residual_rel_tol,
    correction_abs_tol=x.correction_abs_tol,
    finite_difference_step=x.finite_difference_step,
    rank_relative_tol=x.rank_relative_tol, max_condition=x.max_condition,
    max_backtracks=x.max_backtracks)

canonical_hash(x::TypedDAETimeProtocolV4) = begin
    hash = canonical_hash(semantic_view(x))
    hash == x.protocol_hash || throw(ArgumentError("D2.2 protocol tampered"))
    hash
end

struct TypedDAETimePointV4
    time::Float64
    time_unit::UnitSignature
    states::Tuple
    scaled_differential_residual::Tuple
    scaled_algebraic_residual::Tuple
    scaled_joint_condition::Union{Nothing,Float64}
    scaled_jzz_condition::Float64
    point_hash::Digest256
    function TypedDAETimePointV4(token::Val{:typed_dae_time_execution_private},
                                 fields...)
        token === _TDAET_TOKEN || throw(ArgumentError("private D2.2 point"))
        new(fields...)
    end
end

struct TypedDAETimePlanV4
    initialization_plan::TypedDAEInitializationPlanV4
    initialization_report::TypedDAEInitializationReportV4
    protocol::TypedDAETimeProtocolV4
    capability::CapabilitySignatureV4
    subject::ExecutablePhysicalSubjectV4
    input::SolverInputV4
    provider::ProviderManifestV4
    source_hash::Digest256
    authority_hash::Digest256
    plan_hash::Digest256
    function TypedDAETimePlanV4(token::Val{:typed_dae_time_execution_private},
                                fields...)
        token === _TDAET_TOKEN || throw(ArgumentError("private D2.2 plan"))
        new(fields...)
    end
end

struct TypedDAETimeResultV4
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    failure_reason::Union{Nothing,String}
    trajectory::Tuple
    accepted_steps::Int
    attempted_step::Int
    max_scaled_differential_residual::Union{Nothing,Float64}
    max_scaled_algebraic_residual::Union{Nothing,Float64}
    max_scaled_joint_condition::Union{Nothing,Float64}
    result_hash::Digest256
    function TypedDAETimeResultV4(token::Val{:typed_dae_time_execution_private},
                                  fields...)
        token === _TDAET_TOKEN || throw(ArgumentError("private D2.2 result"))
        new(fields...)
    end
end

struct TypedDAETimeReceiptV4
    invocation_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Union{Nothing,Digest256}
    plan_hash::Digest256
    initialization_plan_hash::Digest256
    initialization_report_hash::Digest256
    initialization_artifact_hash::Digest256
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    failure_reason::Union{Nothing,String}
    artifact_hash::Union{Nothing,Digest256}
    evidence_id::Digest256
    execution_count::Int
    receipt_hash::Digest256
    function TypedDAETimeReceiptV4(token::Val{:typed_dae_time_execution_private},
                                   fields...)
        token === _TDAET_TOKEN || throw(ArgumentError("private D2.2 receipt"))
        new(fields...)
    end
end

struct TypedDAETimeReportV4
    artifact::Union{Nothing,TypedDAETimeResultV4}
    evidence::RuntimeEvidenceV4
    receipt::TypedDAETimeReceiptV4
    numerical_status::Symbol
    unresolved_gaps::Tuple{Vararg{String}}
    executed_scope::String
    unexecuted_scopes::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function TypedDAETimeReportV4(token::Val{:typed_dae_time_execution_private},
                                  fields...)
        token === _TDAET_TOKEN || throw(ArgumentError("private D2.2 report"))
        new(fields...)
    end
end

mutable struct TypedDAETimeStoreV4
    reports::Dict{Digest256,TypedDAETimeReportV4}
    artifacts::Dict{Tuple{Digest256,Digest256},TypedDAETimeResultV4}
    execution_counts::Dict{Digest256,Int}
end

TypedDAETimeStoreV4() = TypedDAETimeStoreV4(
    Dict{Digest256,TypedDAETimeReportV4}(),
    Dict{Tuple{Digest256,Digest256},TypedDAETimeResultV4}(),
    Dict{Digest256,Int}())

_tdaet_point_identity(x::TypedDAETimePointV4) = (
    revision=_TDAET_REVISION, time=x.time, time_unit=x.time_unit,
    states=x.states,
    scaled_differential_residual=x.scaled_differential_residual,
    scaled_algebraic_residual=x.scaled_algebraic_residual,
    scaled_joint_condition=x.scaled_joint_condition,
    scaled_jzz_condition=x.scaled_jzz_condition)

_tdaet_result_identity(x::TypedDAETimeResultV4) = (
    revision=_TDAET_REVISION, status=x.status, failure_code=x.failure_code,
    failure_reason=x.failure_reason,
    trajectory=Tuple(canonical_hash(point) for point in x.trajectory),
    accepted_steps=x.accepted_steps, attempted_step=x.attempted_step,
    max_scaled_differential_residual=x.max_scaled_differential_residual,
    max_scaled_algebraic_residual=x.max_scaled_algebraic_residual,
    max_scaled_joint_condition=x.max_scaled_joint_condition)

_tdaet_receipt_identity(x::TypedDAETimeReceiptV4) = (
    revision=_TDAET_REVISION, invocation=x.invocation_hash,
    solver_input=x.solver_input_hash, provider=x.provider_manifest_hash,
    plan=x.plan_hash, initialization_plan=x.initialization_plan_hash,
    initialization_report=x.initialization_report_hash,
    initialization_artifact=x.initialization_artifact_hash,
    status=x.status, failure_code=x.failure_code,
    failure_reason=x.failure_reason, artifact=x.artifact_hash,
    evidence=x.evidence_id, execution_count=x.execution_count)

_tdaet_report_identity(x::TypedDAETimeReportV4) = (
    revision=_TDAET_REVISION,
    artifact=x.artifact === nothing ? nothing : canonical_hash(x.artifact),
    evidence=x.evidence.evidence_id, receipt=x.receipt.receipt_hash,
    numerical_status=x.numerical_status, unresolved_gaps=x.unresolved_gaps,
    executed_scope=x.executed_scope, unexecuted_scopes=x.unexecuted_scopes,
    claim_ceiling=x.claim_ceiling,
    credible_physical_candidate_count=x.credible_physical_candidate_count,
    p5_ready=x.p5_ready, unsupported_emitted=x.unsupported_emitted)

canonical_hash(x::TypedDAETimePointV4) = begin
    isfinite(x.time) && all(value -> value isa StateValueV4, x.states) &&
        all(value -> isfinite(value.value), x.states) &&
        all(isfinite, x.scaled_differential_residual) &&
        all(isfinite, x.scaled_algebraic_residual) &&
        (x.scaled_joint_condition === nothing ||
            isfinite(x.scaled_joint_condition)) &&
        isfinite(x.scaled_jzz_condition) ||
        throw(ArgumentError("invalid D2.2 point payload"))
    hash = canonical_hash(_tdaet_point_identity(x))
    hash == x.point_hash || throw(ArgumentError("D2.2 point tampered"))
    hash
end

canonical_hash(x::TypedDAETimeResultV4) = begin
    all(point -> point isa TypedDAETimePointV4, x.trajectory) ||
        throw(ArgumentError("D2.2 trajectory must contain typed points"))
    x.status in (:pass, :numerical_fail, :unknown) ||
        throw(ArgumentError("invalid D2.2 result status"))
    x.accepted_steps == max(0, length(x.trajectory) - 1) &&
        x.attempted_step >= x.accepted_steps ||
        throw(ArgumentError("invalid D2.2 step accounting"))
    (x.status === :pass) ==
        (x.failure_code === nothing && x.failure_reason === nothing) ||
        throw(ArgumentError("invalid D2.2 failure semantics"))
    hash = canonical_hash(_tdaet_result_identity(x))
    hash == x.result_hash || throw(ArgumentError("D2.2 result tampered"))
    hash
end

canonical_hash(x::TypedDAETimeReceiptV4) = begin
    hash = canonical_hash(_tdaet_receipt_identity(x))
    hash == x.receipt_hash || throw(ArgumentError("D2.2 receipt tampered"))
    hash
end

canonical_hash(x::TypedDAETimeReportV4) = begin
    x.claim_ceiling === screen_only &&
        x.credible_physical_candidate_count == 0 && !x.p5_ready &&
        !x.unsupported_emitted || throw(ArgumentError("D2.2 claim firewall"))
    canonical_hash(x.evidence)
    canonical_hash(x.receipt)
    hash = canonical_hash(_tdaet_report_identity(x))
    hash == x.report_hash || throw(ArgumentError("D2.2 report tampered"))
    hash
end
