# D1.3 authority and evidence contracts over the frozen D1.1-D1.2b kernels.
using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TEXEC_REVISION = "typed-time-execution-v1"
const _TEXEC_SCHEMA = "fusionconceptai:runtime-v4-typed-time-execution"
const _TEXEC_KIND = :typed_constant_mass_ode_integration
const _TEXEC_BACKEND = "julia-fixed-rk4-dense-lu"
const _TEXEC_BACKEND_REVISION = "d1.3-v1"
const _TEXEC_INDEPENDENCE_GROUP = "julia-typed-time-residual-v1"
const _TEXEC_OPERATIONS = (:continuous, :three_level_refinement, :single_threshold_event)
const _TEXEC_TOKEN = Val(:typed_time_execution_private)
const _TEXEC_SOURCE_FILES = (
    "TypedTimeResidual.jl", "TypedTimeRefinement.jl", "TypedTimeEvents.jl",
    "TypedTimeExecutionContracts.jl", "TypedTimeExecution.jl")

_texec_source_hash() = canonical_hash(Tuple(begin
    path = joinpath(@__DIR__, name)
    isfile(path) || throw(ArgumentError("missing audited time source: $name"))
    (name=name, content_hash=digest256_text(read(path, String)))
end for name in _TEXEC_SOURCE_FILES))

function _texec_shape(operation, residual_plan, refinement_protocol, event_plan)
    operation in _TEXEC_OPERATIONS || throw(ArgumentError("invalid typed-time operation"))
    if operation === :continuous
        residual_plan isa TypedTimeResidualPlanV4 && refinement_protocol === nothing && event_plan === nothing ||
            throw(ArgumentError("continuous operation shape mismatch"))
    elseif operation === :three_level_refinement
        residual_plan isa TypedTimeResidualPlanV4 && refinement_protocol isa TimeRefinementProtocolV4 && event_plan === nothing ||
            throw(ArgumentError("refinement operation shape mismatch"))
    else
        residual_plan === nothing && refinement_protocol === nothing && event_plan isa TypedTimeEventPlanV4 ||
            throw(ArgumentError("event operation shape mismatch"))
    end
    true
end

function _texec_state_schema(compiled::CompiledCandidatePrefixV4)
    states = sort(collect(compiled.candidate.mechanism_genome_ref.payload.states), by=s -> s.state_ref.value)
    Tuple((physical_type=s.physical_type, bounds=s.physical_bounds) for s in states)
end

_texec_scenario_payload(scenario::TimeIntegrationScenarioV4) =
    (name=scenario.name, t_start=scenario.t_start, t_stop=scenario.t_stop,
     time_unit=scenario.time_unit,
     initial_values=Tuple((state_ref=v.state_ref, value=v.value, unit=v.unit)
                          for v in scenario.initial_values),
     scenario_hash=scenario.scenario_hash)

function _texec_binding_hashes(residual_plan, event_plan)
    if residual_plan !== nothing
        return Tuple(canonical_hash(r.binding) for r in residual_plan.form.rows), ()
    end
    rows = Tuple(canonical_hash(r.binding) for r in event_plan.residual_plan.rows)
    events = Tuple(canonical_hash(b) for b in event_plan.bindings)
    rows, events
end

function _texec_schema_hash(operation, compiled, residual_plan, refinement_protocol, event_plan)
    rows, events = _texec_binding_hashes(residual_plan, event_plan)
    canonical_hash((schema=_TEXEC_SCHEMA, revision=_TEXEC_REVISION, operation,
        state_schema=_texec_state_schema(compiled), row_binding_hashes=rows,
        event_binding_hashes=events,
        refinement_protocol_hash=refinement_protocol === nothing ? nothing : canonical_hash(refinement_protocol)))
end

function _texec_capability(operation, compiled, residual_plan, refinement_protocol, event_plan)
    required = operation === :continuous ? ("trajectory", "residuals") :
        operation === :three_level_refinement ? ("refinement_receipt", "order", "residuals") :
        ("trajectory", "event_log", "residuals")
    CapabilitySignatureV4(_TEXEC_SCHEMA, _TEXEC_REVISION, _TEXEC_KIND,
        String(operation), ("differential_state_vector",),
        "typed_lumped_state", "typed_time_artifact", 0, (),
        "outside_g1_lumped_time_scope", "outside_g1_lumped_time_scope",
        "deterministic_time", required, screen_only, compiled.minimality_scope.bounds_hash;
        input_schema_hash=_texec_schema_hash(operation, compiled, residual_plan,
            refinement_protocol, event_plan), coordinate_system="lumped_0d")
end

function _texec_subject(compiled, scenario, capability, operation,
                        residual_plan, refinement_protocol, event_plan)
    rows, events = _texec_binding_hashes(residual_plan, event_plan)
    numerical_hash = residual_plan === nothing ? canonical_hash(event_plan) : canonical_hash(residual_plan)
    payload = (operation=operation,
        mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled_prefix_hash=compiled.prefix_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash,
        state_schema=_texec_state_schema(compiled), row_binding_hashes=rows,
        event_binding_hashes=events, numerical_plan_hash=numerical_hash,
        refinement_protocol_hash=refinement_protocol === nothing ? nothing : canonical_hash(refinement_protocol),
        executed_scope="g1_lumped_time",
        unexecuted_scopes=("g2_field_geometry", "g3_realization_control"))
    bindings = (("typed_time_operation", operation),
                ("numerical_plan_hash", numerical_hash))
    ExecutablePhysicalSubjectV4(compiled.prefix_hash,
        compiled.candidate.canonical_hashes.genome_bundle_hash,
        compiled.minimality_scope.mission_hash, compiled.minimality_scope.bounds_hash,
        bindings, (_texec_scenario_payload(scenario),), payload, (capability,))
end

function _texec_provider(capability, operation, source_hash)
    ProviderManifestV4(_TEXEC_SCHEMA, _TEXEC_REVISION, _TEXEC_KIND, capability,
        (bounds_hash=capability.applicability_bounds, operation=operation,
         executed_scope="g1_lumped_time"), _TEXEC_BACKEND,
        _TEXEC_BACKEND_REVISION, source_hash, _TEXEC_INDEPENDENCE_GROUP,
        screen_only; input_schema_hash=capability.input_schema_hash, executor=nothing)
end

function _texec_authority_hash(operation, compiled, subject, scenario,
                               residual_plan, refinement_protocol, event_plan,
                               capability, provider, source_hash)
    numerical_hash = residual_plan === nothing ? canonical_hash(event_plan) : canonical_hash(residual_plan)
    canonical_hash((revision=_TEXEC_REVISION, operation, compiled_prefix=compiled.prefix_hash,
        mechanism_hash=mechanism_hash(compiled.candidate.mechanism_genome_ref),
        field_geometry_hash=field_geometry_hash(compiled.candidate.field_geometry_genome_ref),
        realization_control_hash=realization_control_hash(compiled.candidate.realization_control_genome_ref),
        genome_bundle_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
        mission_hash=compiled.minimality_scope.mission_hash,
        bounds_hash=compiled.minimality_scope.bounds_hash,
        subject=subject.physical_subject_hash, scenario=scenario.scenario_hash,
        numerical_plan=numerical_hash,
        refinement_protocol=refinement_protocol === nothing ? nothing : canonical_hash(refinement_protocol),
        capability=canonical_hash(capability), provider=provider.manifest_hash,
        source_hash=source_hash))
end

function _texec_solver_input(subject, scenario, provider, operation, authority_hash,
                             residual_plan, refinement_protocol, event_plan)
    numerical_hash = residual_plan === nothing ? canonical_hash(event_plan) : canonical_hash(residual_plan)
    payload = (revision=_TEXEC_REVISION, operation, execution_authority_hash=authority_hash,
        physical_subject_hash=subject.physical_subject_hash,
        scenario=_texec_scenario_payload(scenario), scenario_hash=scenario.scenario_hash,
        numerical_plan_hash=numerical_hash,
        refinement_protocol_hash=refinement_protocol === nothing ? nothing : canonical_hash(refinement_protocol),
        provider_manifest_hash=provider.manifest_hash,
        source_hash=provider.code_hash, executed_scope="g1_lumped_time",
        unexecuted_scopes=("g2_field_geometry", "g3_realization_control"))
    SolverInputV4(subject.physical_subject_hash, scenario.scenario_hash,
        provider.manifest_hash, provider.input_schema_hash, payload)
end

struct TypedTimeExecutionPlanV4
    operation::Symbol
    compiled::CompiledCandidatePrefixV4
    registry::GenomeContractRegistryV4
    subject::ExecutablePhysicalSubjectV4
    input::SolverInputV4
    provider::ProviderManifestV4
    scenario::TimeIntegrationScenarioV4
    residual_plan::Union{Nothing,TypedTimeResidualPlanV4}
    refinement_protocol::Union{Nothing,TimeRefinementProtocolV4}
    event_plan::Union{Nothing,TypedTimeEventPlanV4}
    source_hash::Digest256
    authority_hash::Digest256
    plan_hash::Digest256
    function TypedTimeExecutionPlanV4(token::Val{:typed_time_execution_private}, fields...)
        token === _TEXEC_TOKEN || throw(ArgumentError("private execution-plan constructor"))
        new(fields...)
    end
end

struct TypedTimeTrajectoryV4
    physical_subject_hash::Digest256
    solver_input_hash::Digest256
    execution_plan_hash::Digest256
    scenario_hash::Digest256
    result_hash::Digest256
    status::Symbol
    times::Tuple
    states::Tuple
    event_hashes::Tuple{Vararg{Digest256}}
    mass_residual_norm::Union{Nothing,Float64}
    trajectory_defect_norm::Union{Nothing,Float64}
    residual_norm::Union{Nothing,Float64}
    trajectory_hash::Digest256
    function TypedTimeTrajectoryV4(token::Val{:typed_time_execution_private}, fields...)
        token === _TEXEC_TOKEN || throw(ArgumentError("private trajectory constructor"))
        new(fields...)
    end
end

struct TypedTimeExecutionReceiptV4
    invocation_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Union{Nothing,Digest256}
    execution_plan_hash::Digest256
    physical_subject_hash::Digest256
    scenario_hash::Digest256
    operation::Symbol
    status::Symbol
    failure_code::Union{Nothing,Symbol}
    failure_reason::Union{Nothing,String}
    artifact_hash::Union{Nothing,Digest256}
    trajectory_hash::Union{Nothing,Digest256}
    evidence_id::Digest256
    execution_count::Int
    receipt_hash::Digest256
    function TypedTimeExecutionReceiptV4(token::Val{:typed_time_execution_private}, fields...)
        token === _TEXEC_TOKEN || throw(ArgumentError("private receipt constructor"))
        new(fields...)
    end
end

const _TEXEC_ARTIFACT = Union{Nothing,TypedTimeResidualResultV4,TimeRefinementReceiptV4,TypedTimeEventResultV4}

struct TypedTimeResidualReportV4
    artifact::_TEXEC_ARTIFACT
    trajectory::Union{Nothing,TypedTimeTrajectoryV4}
    evidence::RuntimeEvidenceV4
    receipt::TypedTimeExecutionReceiptV4
    numerical_status::Symbol
    unresolved_gaps::Tuple{Vararg{String}}
    executed_scope::String
    unexecuted_scopes::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    credible_physical_candidate_count::Int
    p5_ready::Bool
    unsupported_emitted::Bool
    report_hash::Digest256
    function TypedTimeResidualReportV4(token::Val{:typed_time_execution_private}, fields...)
        token === _TEXEC_TOKEN || throw(ArgumentError("private report constructor"))
        new(fields...)
    end
end

mutable struct TypedTimeExecutionStoreV4
    reports::Dict{Digest256,TypedTimeResidualReportV4}
    artifacts::Dict{Tuple{Digest256,Digest256},_TEXEC_ARTIFACT}
    execution_counts::Dict{Digest256,Int}
end
TypedTimeExecutionStoreV4() = TypedTimeExecutionStoreV4(
    Dict{Digest256,TypedTimeResidualReportV4}(),
    Dict{Tuple{Digest256,Digest256},_TEXEC_ARTIFACT}(), Dict{Digest256,Int}())

semantic_view(x::TypedTimeExecutionPlanV4) = (revision=_TEXEC_REVISION,
    operation=x.operation, compiled_prefix_hash=x.compiled.prefix_hash,
    subject_hash=x.subject.physical_subject_hash, input_hash=x.input.solver_input_hash,
    provider_hash=x.provider.manifest_hash, scenario_hash=x.scenario.scenario_hash,
    residual_plan_hash=x.residual_plan === nothing ? nothing : x.residual_plan.plan_hash,
    refinement_protocol_hash=x.refinement_protocol === nothing ? nothing : x.refinement_protocol.protocol_hash,
    event_plan_hash=x.event_plan === nothing ? nothing : x.event_plan.plan_hash,
    source_hash=x.source_hash, authority_hash=x.authority_hash, plan_hash=x.plan_hash)

_texec_trajectory_identity(x::TypedTimeTrajectoryV4) =
    (revision=_TEXEC_REVISION, physical_subject=x.physical_subject_hash,
     solver_input=x.solver_input_hash, execution_plan=x.execution_plan_hash,
     scenario=x.scenario_hash, result=x.result_hash, status=x.status,
     times=x.times, states=x.states, event_hashes=x.event_hashes,
     mass_residual_norm=x.mass_residual_norm,
     trajectory_defect_norm=x.trajectory_defect_norm, residual_norm=x.residual_norm)

_texec_receipt_identity(x::TypedTimeExecutionReceiptV4) =
    (revision=_TEXEC_REVISION, invocation=x.invocation_hash,
     solver_input=x.solver_input_hash, provider=x.provider_manifest_hash,
     execution_plan=x.execution_plan_hash, physical_subject=x.physical_subject_hash,
     scenario=x.scenario_hash, operation=x.operation, status=x.status,
     failure_code=x.failure_code, failure_reason=x.failure_reason,
     artifact=x.artifact_hash, trajectory=x.trajectory_hash,
     evidence=x.evidence_id, execution_count=x.execution_count)

_texec_report_identity(x::TypedTimeResidualReportV4) =
    (revision=_TEXEC_REVISION,
     artifact=x.artifact === nothing ? nothing : _texec_artifact_hash(x.artifact),
     trajectory=x.trajectory === nothing ? nothing : canonical_hash(x.trajectory),
     evidence=x.evidence.evidence_id, receipt=x.receipt.receipt_hash,
     numerical_status=x.numerical_status, unresolved_gaps=x.unresolved_gaps,
     executed_scope=x.executed_scope, unexecuted_scopes=x.unexecuted_scopes,
     claim_ceiling=x.claim_ceiling,
     credible_physical_candidate_count=x.credible_physical_candidate_count,
     p5_ready=x.p5_ready, unsupported_emitted=x.unsupported_emitted)

canonical_hash(x::TypedTimeTrajectoryV4) = begin
    h = canonical_hash(_texec_trajectory_identity(x))
    h == x.trajectory_hash || throw(ArgumentError("typed-time trajectory tampered"))
    h
end
canonical_hash(x::TypedTimeExecutionReceiptV4) = begin
    h = canonical_hash(_texec_receipt_identity(x))
    h == x.receipt_hash || throw(ArgumentError("typed-time receipt tampered"))
    h
end
canonical_hash(x::TypedTimeResidualReportV4) = begin
    x.claim_ceiling == screen_only && x.credible_physical_candidate_count == 0 &&
        !x.p5_ready && !x.unsupported_emitted || throw(ArgumentError("D1.3 claim firewall violated"))
    canonical_hash(x.receipt)
    canonical_hash(x.evidence)
    h = canonical_hash(_texec_report_identity(x))
    h == x.report_hash || throw(ArgumentError("typed-time report tampered"))
    h
end
