# D2.1 sealed contracts for candidate-bound mixed-state initialization.
using LinearAlgebra
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDAE_REVISION = "d2.1-v1"
const _TDAE_SCHEMA = "fusionconceptai:runtime-v4-typed-dae-initialization"
const _TDAE_KIND = :typed_dae_consistent_initialization_screen
const _TDAE_OPERATOR = "mixed_constant_mass_dae_consistent_initialization"
const _TDAE_BACKEND = "julia-bounded-newton-dense-lu"
const _TDAE_INDEPENDENCE_GROUP = "julia-typed-dae-initialization-v1"
const _TDAE_TOKEN = Val(:typed_dae_initialization_private)
const _TDAE_ALLOWED_ALGEBRAIC_OPS = ("IDENTITY", "ADD", "SUB", "NEG", "SCALAR_MUL", "SCALAR_DIV")
const _TDAE_SOURCE_FILES = ("TypedDAEInitializationContracts.jl", "TypedDAEInitialization.jl")

struct DAEAlgebraicRowBindingV4
    state_ref::StateGeneRefV1
    governing_edge_hash::Digest256
    residual_edge_hash::Digest256
    residual_root_position::Int
    operator_manifest_bindings::Tuple
    function DAEAlgebraicRowBindingV4(state_ref, governing_edge_hash,
                                      residual_edge_hash, residual_root_position,
                                      operator_manifest_bindings=())
        state_ref isa StateGeneRefV1 || throw(ArgumentError("typed state ref required"))
        residual_root_position isa Integer && residual_root_position > 0 ||
            throw(ArgumentError("positive residual root position required"))
        new(state_ref, governing_edge_hash, residual_edge_hash,
            Int(residual_root_position), Tuple(operator_manifest_bindings))
    end
end
semantic_view(x::DAEAlgebraicRowBindingV4) = (
    state_ref=x.state_ref, governing_edge_hash=x.governing_edge_hash,
    residual_edge_hash=x.residual_edge_hash,
    residual_root_position=x.residual_root_position,
    operator_manifest_bindings=x.operator_manifest_bindings)

struct ConsistentInitializationScenarioV4
    name::String
    initial_values::Tuple
    scenario_hash::Digest256
    function ConsistentInitializationScenarioV4(name, initial_values)
        values = Tuple(initial_values)
        all(v -> v isa StateValueV4, values) ||
            throw(ArgumentError("typed initial values required"))
        refs = Tuple(v.state_ref.value for v in values)
        length(unique(refs)) == length(refs) ||
            throw(ArgumentError("duplicate scenario state"))
        ordered = Tuple(sort(collect(values), by=v -> v.state_ref.value))
        body = (revision=_TDAE_REVISION, name=String(name), initial_values=ordered)
        new(String(name), ordered, canonical_hash(body))
    end
end
semantic_view(x::ConsistentInitializationScenarioV4) = (
    revision=_TDAE_REVISION, name=x.name, initial_values=x.initial_values)

struct ConsistentInitializationProtocolV4
    max_iterations::Int
    residual_abs_tol::Float64
    residual_rel_tol::Float64
    mass_residual_tol::Float64
    correction_abs_tol::Float64
    finite_difference_step::Float64
    time_scale::Float64
    time_unit::UnitSignature
    rank_relative_tol::Float64
    max_condition::Float64
    max_backtracks::Int
    protocol_hash::Digest256
    function ConsistentInitializationProtocolV4(; max_iterations=32,
            residual_abs_tol=1e-10, residual_rel_tol=1e-10,
            mass_residual_tol=1e-10, correction_abs_tol=1e-12,
            finite_difference_step=1e-7, time_scale=1.0,
            time_unit=UnitSignature((0, 0, 1, 0, 0, 0, 0)),
            rank_relative_tol=1e-10,
            max_condition=1e10,
            max_backtracks=20)
        max_iterations isa Integer && max_iterations > 0 ||
            throw(ArgumentError("invalid iteration budget"))
        max_backtracks isa Integer && max_backtracks > 0 ||
            throw(ArgumentError("invalid backtrack budget"))
        numbers = Float64[residual_abs_tol, residual_rel_tol,
            mass_residual_tol, correction_abs_tol, finite_difference_step,
            time_scale, rank_relative_tol, max_condition]
        all(isfinite, numbers) && all(>(0), numbers) ||
            throw(ArgumentError("invalid initialization protocol"))
        time_unit == UnitSignature((0, 0, 1, 0, 0, 0, 0)) ||
            throw(ArgumentError("D2.1 time unit must be exactly the time dimension"))
        body = (revision=_TDAE_REVISION, max_iterations=Int(max_iterations),
            residual_abs_tol=numbers[1], residual_rel_tol=numbers[2],
            mass_residual_tol=numbers[3], correction_abs_tol=numbers[4],
            finite_difference_step=numbers[5], time_scale=numbers[6],
            time_unit=time_unit, rank_relative_tol=numbers[7],
            max_condition=numbers[8],
            max_backtracks=Int(max_backtracks))
        new(body.max_iterations, body.residual_abs_tol, body.residual_rel_tol,
            body.mass_residual_tol, body.correction_abs_tol,
            body.finite_difference_step, body.time_scale, body.time_unit,
            body.rank_relative_tol,
            body.max_condition,
            body.max_backtracks, canonical_hash(body))
    end
end
semantic_view(x::ConsistentInitializationProtocolV4) = (
    revision=_TDAE_REVISION, max_iterations=x.max_iterations,
    residual_abs_tol=x.residual_abs_tol, residual_rel_tol=x.residual_rel_tol,
    mass_residual_tol=x.mass_residual_tol,
    correction_abs_tol=x.correction_abs_tol,
    finite_difference_step=x.finite_difference_step,
    time_scale=x.time_scale, time_unit=x.time_unit,
    rank_relative_tol=x.rank_relative_tol,
    max_condition=x.max_condition, max_backtracks=x.max_backtracks)
canonical_hash(x::ConsistentInitializationProtocolV4) = begin
    h = canonical_hash(semantic_view(x))
    h == x.protocol_hash || throw(ArgumentError("D2.1 protocol tampered"))
    h
end

struct TypedDAEInitializationPlanV4
    compiled::CompiledCandidatePrefixV4
    registry::GenomeContractRegistryV4
    differential_refs::Tuple
    algebraic_refs::Tuple
    row_bindings::Tuple
    scenario::ConsistentInitializationScenarioV4
    protocol::ConsistentInitializationProtocolV4
    capability::CapabilitySignatureV4
    subject::ExecutablePhysicalSubjectV4
    input::SolverInputV4
    provider::ProviderManifestV4
    source_hash::Digest256
    authority_hash::Digest256
    plan_hash::Digest256
    function TypedDAEInitializationPlanV4(
            token::Val{:typed_dae_initialization_private}, fields...)
        token === _TDAE_TOKEN || throw(ArgumentError("private D2.1 plan constructor"))
        new(fields...)
    end
end

struct TypedDAEInitializationResultV4
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    failure_reason::Union{Nothing,String}
    differential_refs::Tuple
    algebraic_refs::Tuple
    initial_values::Tuple
    final_values::Union{Nothing,Tuple}
    initial_algebraic_residual::Union{Nothing,Tuple}
    final_algebraic_residual::Union{Nothing,Tuple}
    initial_derivative::Union{Nothing,Tuple}
    differential_mass_residual::Union{Nothing,Tuple}
    correction_norm::Union{Nothing,Float64}
    differential_unchanged::Union{Nothing,Bool}
    mass_matrix::Union{Nothing,Tuple}
    jacobian_zz::Union{Nothing,Tuple}
    mass_condition::Union{Nothing,Float64}
    jacobian_condition::Union{Nothing,Float64}
    result_hash::Digest256
    function TypedDAEInitializationResultV4(
            token::Val{:typed_dae_initialization_private}, fields...)
        token === _TDAE_TOKEN || throw(ArgumentError("private D2.1 result constructor"))
        new(fields...)
    end
end

struct TypedDAEInitializationReceiptV4
    invocation_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Union{Nothing,Digest256}
    plan_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    failure_reason::Union{Nothing,String}
    artifact_hash::Union{Nothing,Digest256}
    evidence_id::Digest256
    execution_count::Int
    receipt_hash::Digest256
    function TypedDAEInitializationReceiptV4(
            token::Val{:typed_dae_initialization_private}, fields...)
        token === _TDAE_TOKEN || throw(ArgumentError("private D2.1 receipt constructor"))
        new(fields...)
    end
end

struct TypedDAEInitializationReportV4
    artifact::Union{Nothing,TypedDAEInitializationResultV4}
    evidence::RuntimeEvidenceV4
    receipt::TypedDAEInitializationReceiptV4
    numerical_status::Symbol
    unresolved_gaps::Tuple{Vararg{String}}
    executed_scope::String
    unexecuted_scopes::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    trajectory::Nothing
    report_hash::Digest256
    function TypedDAEInitializationReportV4(
            token::Val{:typed_dae_initialization_private}, fields...)
        token === _TDAE_TOKEN || throw(ArgumentError("private D2.1 report constructor"))
        new(fields...)
    end
end

mutable struct TypedDAEInitializationStoreV4
    reports::Dict{Digest256,TypedDAEInitializationReportV4}
    artifacts::Dict{Tuple{Digest256,Digest256},TypedDAEInitializationResultV4}
    execution_counts::Dict{Digest256,Int}
end
TypedDAEInitializationStoreV4() = TypedDAEInitializationStoreV4(
    Dict{Digest256,TypedDAEInitializationReportV4}(),
    Dict{Tuple{Digest256,Digest256},TypedDAEInitializationResultV4}(),
    Dict{Digest256,Int}())

_tdae_result_identity(x::TypedDAEInitializationResultV4) = (
    revision=_TDAE_REVISION, status=x.status, failure_code=x.failure_code,
    failure_reason=x.failure_reason, differential_refs=x.differential_refs,
    algebraic_refs=x.algebraic_refs, initial_values=x.initial_values,
    final_values=x.final_values,
    initial_algebraic_residual=x.initial_algebraic_residual,
    final_algebraic_residual=x.final_algebraic_residual,
    initial_derivative=x.initial_derivative,
    differential_mass_residual=x.differential_mass_residual,
    correction_norm=x.correction_norm,
    differential_unchanged=x.differential_unchanged,
    mass_matrix=x.mass_matrix, jacobian_zz=x.jacobian_zz,
    mass_condition=x.mass_condition,
    jacobian_condition=x.jacobian_condition)

_tdae_receipt_identity(x::TypedDAEInitializationReceiptV4) = (
    revision=_TDAE_REVISION, invocation=x.invocation_hash,
    solver_input=x.solver_input_hash, provider=x.provider_manifest_hash,
    plan=x.plan_hash, physical_subject=x.physical_subject_hash,
    scenario=x.scenario_hash, status=x.status,
    failure_code=x.failure_code, failure_reason=x.failure_reason,
    artifact=x.artifact_hash, evidence=x.evidence_id,
    execution_count=x.execution_count)

_tdae_report_identity(x::TypedDAEInitializationReportV4) = (
    revision=_TDAE_REVISION,
    artifact=x.artifact === nothing ? nothing : canonical_hash(x.artifact),
    evidence=x.evidence.evidence_id, receipt=x.receipt.receipt_hash,
    numerical_status=x.numerical_status, unresolved_gaps=x.unresolved_gaps,
    executed_scope=x.executed_scope, unexecuted_scopes=x.unexecuted_scopes,
    claim_ceiling=x.claim_ceiling,
    credible_physical_candidate_count=x.credible_physical_candidate_count,
    p5_ready=x.p5_ready, unsupported_emitted=x.unsupported_emitted,
    trajectory=nothing)

canonical_hash(x::TypedDAEInitializationResultV4) = begin
    h = canonical_hash(_tdae_result_identity(x))
    h == x.result_hash || throw(ArgumentError("D2.1 result tampered"))
    h
end
canonical_hash(x::TypedDAEInitializationReceiptV4) = begin
    h = canonical_hash(_tdae_receipt_identity(x))
    h == x.receipt_hash || throw(ArgumentError("D2.1 receipt tampered"))
    h
end
canonical_hash(x::TypedDAEInitializationReportV4) = begin
    x.claim_ceiling == screen_only &&
        x.credible_physical_candidate_count == 0 && !x.p5_ready &&
        !x.unsupported_emitted && x.trajectory === nothing ||
        throw(ArgumentError("D2.1 claim firewall violated"))
    canonical_hash(x.receipt)
    canonical_hash(x.evidence)
    h = canonical_hash(_tdae_report_identity(x))
    h == x.report_hash || throw(ArgumentError("D2.1 report tampered"))
    h
end
