"""Candidate-local algebraic screening over the RuntimeV4 deferred archive.

This layer deliberately keeps the algebraic result local to one candidate,
prefix, plan, stage, and scenario.  Resolving this screen never revives a
candidate in the global queue and never closes a physical or whole-device
obligation.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _ALG_SCOPED_STAGE = :g1_zero_dimensional_algebraic_constraint
const _ALG_SCOPED_SCOPE = "g1_zero_dimensional_algebraic_constraint"

struct _AlgebraicScopedWorkToken end
struct _AlgebraicScopedResolutionToken end
const _ALG_SCOPED_WORK_TOKEN = _AlgebraicScopedWorkToken()
const _ALG_SCOPED_RESOLUTION_TOKEN = _AlgebraicScopedResolutionToken()

function _alg_scoped_stage(stage)
    stage === _ALG_SCOPED_STAGE || throw(ArgumentError("algebraic scoped work requires the declared G1 stage"))
    stage
end

function _alg_scoped_digest_tuple(xs, field)
    ys = Tuple(x isa Digest256 ? x : throw(ArgumentError("$field must contain Digest256 values")) for x in xs)
    length(unique(ys)) == length(ys) || throw(ArgumentError("$field contains duplicate hashes"))
    ys
end

struct AlgebraicScopedWorkV4
    entry::CandidateQueueEntryV4
    registry_hash::Digest256
    candidate_ref::Digest256
    prefix_hash::Digest256
    plan::AlgebraicResidualPlanV4
    scenario::AlgebraicScenarioV4
    stage::Symbol
    capability::CapabilitySignatureV4
    scenario_hash::Digest256
    work_hash::Digest256
    function AlgebraicScopedWorkV4(::_AlgebraicScopedWorkToken,
                                   entry::CandidateQueueEntryV4,
                                   registry::GenomeContractRegistryV4,
                                   plan::AlgebraicResidualPlanV4,
                                   scenario::AlgebraicScenarioV4,
                                   stage::Symbol)
        _alg_scoped_stage(stage)
        registry_hash = canonical_hash(registry)
        entry.registry_hash == registry_hash || throw(ArgumentError("queue entry registry does not match scoped registry"))
        entry.candidate_ref == entry.compiled.prefix_hash || throw(ArgumentError("queue candidate reference does not match prefix"))
        plan.compiled_prefix_hash == entry.compiled.prefix_hash || throw(ArgumentError("algebraic plan prefix does not match queue entry"))
        plan.capability.evidence_level == screen_only || throw(ArgumentError("algebraic scoped capability must be screen_only"))
        plan.capability.kind == :algebraic_constraint_screen || throw(ArgumentError("plan is not the algebraic constraint capability"))
        Tuple(v.state_ref.value for v in scenario.state_values) == Tuple(r.value for r in plan.state_refs) ||
            throw(ArgumentError("scenario states do not exactly match the algebraic plan"))
        scenario_hash = scenario.scenario_hash
        body = (candidate_ref=entry.candidate_ref, prefix_hash=entry.compiled.prefix_hash,
            plan_hash=plan.plan_hash, stage=stage, scenario_hash=scenario_hash,
            capability_hash=canonical_hash(plan.capability), registry_hash=registry_hash)
        new(entry, registry_hash, entry.candidate_ref, entry.compiled.prefix_hash, plan, scenario,
            stage, plan.capability, scenario_hash, canonical_hash(body))
    end
end

semantic_view(x::AlgebraicScopedWorkV4) =
    (candidate_ref=x.candidate_ref, prefix_hash=x.prefix_hash, plan_hash=x.plan.plan_hash,
     stage=x.stage, scenario_hash=x.scenario_hash, capability_hash=canonical_hash(x.capability),
     registry_hash=x.registry_hash, work_hash=x.work_hash)

"""Build a candidate-local algebraic work item from an existing queue entry."""
function make_algebraic_scoped_work(entry::CandidateQueueEntryV4,
                                    registry::GenomeContractRegistryV4,
                                    scenario::AlgebraicScenarioV4;
                                    stage::Symbol=_ALG_SCOPED_STAGE)
    plan_result = compile_algebraic_residual_plan(entry.compiled, registry)
    plan_result.status == :ready || throw(ArgumentError("algebraic scoped plan is deferred: $(plan_result.unresolved_gaps)"))
    plan_result.plan === nothing && throw(ArgumentError("ready algebraic scoped plan is missing"))
    AlgebraicScopedWorkV4(_ALG_SCOPED_WORK_TOKEN, entry, registry, plan_result.plan, scenario, stage)
end

algebraic_scoped_work(args...; kwargs...) = make_algebraic_scoped_work(args...; kwargs...)

function defer_algebraic_scoped!(archive::CapabilityArchiveV4, work::AlgebraicScopedWorkV4;
                                 providers=(), reason=nothing)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("scoped providers must be typed"))
    match = match_provider(work.capability, ps)
    local_provider = algebraic_residual_manifest(work.plan)
    local_exact = match.status == unique_match && match.provider !== nothing &&
        match.provider.manifest_hash == local_provider.manifest_hash &&
        match.provider.code_hash == local_provider.code_hash &&
        match.provider.backend_revision == local_provider.backend_revision &&
        match.provider.executor === local_provider.executor
    local_exact && throw(ArgumentError("an exact local algebraic provider cannot be deferred"))
    retry_hash = _archive_provider_hash(ps)
    status = match.status == unique_match ? out_of_domain : match.status
    default_reason = match.status == unique_match ?
        "provider matched capability but is not the local algebraic implementation" :
        "algebraic scoped provider unavailable: $(match.reason)"
    message = reason === nothing ? default_reason : String(reason)
    defer!(archive, work.candidate_ref, work.stage, work.capability, status, message, retry_hash)
end

function requeue_scoped_resolved!(archive::CapabilityArchiveV4,
                                  work::AlgebraicScopedWorkV4,
                                  providers)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    isempty(ps) && return nothing
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("scoped providers must be typed"))
    key = (string(work.candidate_ref), work.stage, canonical_hash(work.capability))
    record = get(archive.deferred, key, nothing)
    record === nothing && return nothing
    match = match_provider(work.capability, ps)
    provider_hash = _archive_provider_hash(ps)
    local_provider = algebraic_residual_manifest(work.plan)
    local_exact = match.status == unique_match && match.provider !== nothing &&
        match.provider.manifest_hash == local_provider.manifest_hash &&
        match.provider.code_hash == local_provider.code_hash &&
        match.provider.backend_revision == local_provider.backend_revision &&
        match.provider.executor === local_provider.executor
    if local_exact
        delete!(archive.deferred, key)
        return work
    end
    status = match.status == unique_match ? out_of_domain : match.status
    reason = match.status == unique_match ?
        "provider matched capability but is not the local algebraic implementation" : match.reason
    archive.deferred[key] = DeferredObligationV4(record.candidate_ref, record.stage,
        record.signature, status, reason, provider_hash)
    nothing
end

"""Select the first priority-ordered deferred/queued/revived algebraic work item.

The scan never changes candidate queue status; resolving this local work is a
separate operation from reviving the candidate globally.
"""
function next_algebraic_scoped_work(queue::CandidateQueueV4,
                                    registry::GenomeContractRegistryV4,
                                    scenario::AlgebraicScenarioV4;
                                    stage::Symbol=_ALG_SCOPED_STAGE)
    eligible = [entry for entry in values(queue.entries) if entry.status in (:deferred, :queued, :revived)]
    for entry in sort!(eligible, by=_queue_entry_sort_key)
        entry.registry_hash == canonical_hash(registry) ||
            throw(ArgumentError("queue entry registry does not match scoped registry"))
        plan_result = compile_algebraic_residual_plan(entry.compiled, registry)
        if plan_result.status != :ready
            any(startswith(String(g), "compiled_prefix_validation:") for g in plan_result.unresolved_gaps) &&
                throw(ArgumentError("compiled prefix validation failed for scoped queue entry"))
            continue
        end
        plan_result.plan === nothing && throw(ArgumentError("ready algebraic scoped plan is missing"))
        return AlgebraicScopedWorkV4(_ALG_SCOPED_WORK_TOKEN, entry, registry,
            plan_result.plan, scenario, stage)
    end
    nothing
end

function _alg_scoped_payload_field(payload, field)
    payload isa NamedTuple && field in keys(payload) || throw(ArgumentError("algebraic solver payload is missing $field"))
    getfield(payload, field)
end

function _alg_scoped_report_validation(work::AlgebraicScopedWorkV4,
                                       plan::AlgebraicResidualPlanV4,
                                       scenario::AlgebraicScenarioV4,
                                       report::AlgebraicSliceReportV4)
    plan.plan_hash == work.plan.plan_hash && plan.compiled_prefix_hash == work.prefix_hash ||
        throw(ArgumentError("algebraic resolution plan does not match scoped work"))
    scenario.scenario_hash == work.scenario_hash || throw(ArgumentError("algebraic resolution scenario does not match scoped work"))
    report.subject isa ExecutableAlgebraicSubjectV4 || throw(ArgumentError("algebraic resolution subject is not typed"))
    report.subject.plan_hash == plan.plan_hash && report.subject.scenario_hash == scenario.scenario_hash ||
        throw(ArgumentError("algebraic subject identity mismatch"))
    report.input === nothing && throw(ArgumentError("algebraic resolution requires provider-bound solver input"))
    report.result === nothing && throw(ArgumentError("algebraic resolution requires a typed result"))
    input = report.input
    payload = input.payload
    _alg_scoped_payload_field(payload, :plan_hash) == plan.plan_hash || throw(ArgumentError("algebraic input plan mismatch"))
    _alg_scoped_payload_field(payload, :scenario_hash) == scenario.scenario_hash || throw(ArgumentError("algebraic input scenario mismatch"))
    _alg_scoped_payload_field(payload, :subject_hash) == report.subject.subject_hash || throw(ArgumentError("algebraic input subject mismatch"))
    _alg_scoped_payload_field(payload, :constraint_subgraph_scope) === true ||
        throw(ArgumentError("algebraic input is not constraint-subgraph scoped"))
    requested = _alg_scoped_payload_field(payload, :requested_obligation)
    requested isa CapabilitySignatureV4 && canonical_hash(requested) == canonical_hash(work.capability) ||
        throw(ArgumentError("algebraic input requested obligation mismatch"))
    input.physical_subject_hash == report.subject.subject_hash && input.scenario_hash == scenario.scenario_hash ||
        throw(ArgumentError("algebraic solver input identity mismatch"))
    input.input_schema_hash == work.capability.input_schema_hash || throw(ArgumentError("algebraic input schema mismatch"))
    local_provider = algebraic_residual_manifest(plan)
    report.evidence.provider_manifest_hash == local_provider.manifest_hash ||
        throw(ArgumentError("algebraic evidence provider is not the local exact provider"))
    input.provider_manifest_hash == local_provider.manifest_hash || throw(ArgumentError("algebraic input provider mismatch"))
    result = report.result
    result.plan_hash == plan.plan_hash && result.scenario_hash == scenario.scenario_hash ||
        throw(ArgumentError("algebraic result identity mismatch"))
    evidence = report.evidence
    evidence.physical_subject_hash == report.subject.subject_hash && evidence.scenario_hash == scenario.scenario_hash &&
        evidence.solver_input_hash == input.solver_input_hash || throw(ArgumentError("algebraic evidence binding mismatch"))
    evidence.binding_provenance isa NamedTuple && :constraint_subgraph_scope in keys(evidence.binding_provenance) &&
        getfield(evidence.binding_provenance, :constraint_subgraph_scope) === true ||
        throw(ArgumentError("algebraic evidence is not constraint-subgraph scoped"))
    evidence.backend_revision == local_provider.backend_revision ||
        throw(ArgumentError("algebraic evidence backend revision is not local"))
    evidence.independence_group == local_provider.independence_group ||
        throw(ArgumentError("algebraic evidence independence group is not local"))
    expected_configuration_hash = canonical_hash((plan=plan.numerical_protocol,
        scenario=(scenario.abs_tol, scenario.rel_tol, scenario.max_iterations,
                  scenario.fd_step, scenario.min_line_search)))
    evidence.numerical_configuration_hash == expected_configuration_hash ||
        throw(ArgumentError("algebraic evidence numerical configuration is not frozen"))
    evidence.claim_ceiling == screen_only || throw(ArgumentError("algebraic resolution requires screen_only evidence"))
    evidence.artifact_refs == (result.result_hash,) || throw(ArgumentError("algebraic evidence artifact does not bind result"))
    status = evidence.status_vector
    status.applicability == required && status.match_status == unique_match &&
        status.resolution == resolved && status.lifecycle == low_fidelity_evaluated ||
        throw(ArgumentError("algebraic evidence status is not the required low-fidelity resolved combination"))
    provenance = evidence.binding_provenance
    provenance isa NamedTuple && all(field -> field in keys(provenance),
        (:subject_hash, :plan_hash, :scenario_hash, :provider_manifest_hash,
         :backend_revision, :constraint_subgraph_scope)) ||
        throw(ArgumentError("algebraic evidence provenance is incomplete"))
    getfield(provenance, :subject_hash) == report.subject.subject_hash &&
        getfield(provenance, :plan_hash) == plan.plan_hash &&
        getfield(provenance, :scenario_hash) == scenario.scenario_hash &&
        getfield(provenance, :provider_manifest_hash) == local_provider.manifest_hash &&
        getfield(provenance, :backend_revision) == local_provider.backend_revision &&
        getfield(provenance, :constraint_subgraph_scope) === true ||
        throw(ArgumentError("algebraic evidence provenance does not bind the scoped work"))
    result.status == :converged && evidence.status_vector.stage_outcome == pass ||
        result.status == :numerical_fail && evidence.status_vector.stage_outcome == numerical_fail ||
        throw(ArgumentError("algebraic result/evidence outcome mismatch"))
    if result.status == :converged
        threshold = plan.numerical_protocol.abs_tol + plan.numerical_protocol.rel_tol * result.reference_norm
        result.residual_norm !== nothing && result.residual_norm <= threshold ||
            throw(ArgumentError("algebraic result does not meet frozen threshold"))
    end
    (input=input, result=result, evidence=evidence, provider=local_provider,
     remaining_unresolved_nonterminals=work.entry.compiled.unresolved_nonterminals,
     remaining_capability_obligations=work.entry.compiled.capability_obligations)
end

struct AlgebraicScopedResolutionV4
    work_hash::Digest256
    candidate_ref::Digest256
    prefix_hash::Digest256
    plan_hash::Digest256
    stage::Symbol
    scenario_hash::Digest256
    capability_hash::Digest256
    subject_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Digest256
    result_hash::Digest256
    evidence_hash::Digest256
    classification::Symbol
    scope::String
    selected_constraint_hashes::Tuple{Vararg{Digest256}}
    remaining_unresolved_nonterminals::Tuple{Vararg{String}}
    remaining_capability_obligations::Tuple{Vararg{CapabilitySignatureV4}}
    report::AlgebraicSliceReportV4
    resolution_hash::Digest256
    function AlgebraicScopedResolutionV4(::_AlgebraicScopedResolutionToken,
                                         work::AlgebraicScopedWorkV4,
                                         plan::AlgebraicResidualPlanV4,
                                         scenario::AlgebraicScenarioV4,
                                         report::AlgebraicSliceReportV4)
        validated = _alg_scoped_report_validation(work, plan, scenario, report)
        validated.result.status == :converged && validated.evidence.status_vector.stage_outcome == pass ||
            throw(ArgumentError("numerical or failed algebraic execution must be recorded as AlgebraicScopedAttemptV4"))
        classification = :evaluated_screen
        selected = _alg_scoped_digest_tuple(plan.selected_constraint_hashes, "selected constraint hashes")
        remaining_unresolved = Tuple(String(x) for x in validated.remaining_unresolved_nonterminals)
        remaining_obligations = Tuple(validated.remaining_capability_obligations)
        body = (work_hash=work.work_hash, candidate_ref=work.candidate_ref,
            prefix_hash=work.prefix_hash, plan_hash=plan.plan_hash, stage=work.stage,
            scenario_hash=scenario.scenario_hash, capability_hash=canonical_hash(work.capability),
            subject_hash=report.subject.subject_hash, solver_input_hash=validated.input.solver_input_hash,
            provider_manifest_hash=validated.provider.manifest_hash, result_hash=validated.result.result_hash,
            evidence_hash=validated.evidence.evidence_id, classification=classification,
            scope=_ALG_SCOPED_SCOPE, selected_constraint_hashes=selected,
            remaining_unresolved_nonterminals=remaining_unresolved,
            remaining_capability_obligations=remaining_obligations)
        new(work.work_hash, work.candidate_ref, work.prefix_hash, plan.plan_hash, work.stage,
            scenario.scenario_hash, canonical_hash(work.capability), report.subject.subject_hash,
            validated.input.solver_input_hash, validated.provider.manifest_hash, validated.result.result_hash,
            validated.evidence.evidence_id, classification, _ALG_SCOPED_SCOPE, selected,
            remaining_unresolved, remaining_obligations, report, canonical_hash(body))
    end
end

semantic_view(x::AlgebraicScopedResolutionV4) =
    (work_hash=x.work_hash, candidate_ref=x.candidate_ref, prefix_hash=x.prefix_hash,
     plan_hash=x.plan_hash, stage=x.stage, scenario_hash=x.scenario_hash,
     capability_hash=x.capability_hash, subject_hash=x.subject_hash,
     solver_input_hash=x.solver_input_hash, provider_manifest_hash=x.provider_manifest_hash,
     result_hash=x.result_hash, evidence_hash=x.evidence_hash, classification=x.classification,
     scope=x.scope, selected_constraint_hashes=x.selected_constraint_hashes,
     remaining_unresolved_nonterminals=x.remaining_unresolved_nonterminals,
     remaining_capability_obligations=x.remaining_capability_obligations,
     resolution_hash=x.resolution_hash)

struct AlgebraicScopedAttemptV4
    work_hash::Digest256
    candidate_ref::Digest256
    prefix_hash::Digest256
    plan_hash::Digest256
    stage::Symbol
    scenario_hash::Digest256
    capability_hash::Digest256
    subject_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Digest256
    result_hash::Digest256
    evidence_hash::Digest256
    classification::Symbol
    scope::String
    selected_constraint_hashes::Tuple{Vararg{Digest256}}
    remaining_unresolved_nonterminals::Tuple{Vararg{String}}
    remaining_capability_obligations::Tuple{Vararg{CapabilitySignatureV4}}
    report::AlgebraicSliceReportV4
    attempt_hash::Digest256
    function AlgebraicScopedAttemptV4(::_AlgebraicScopedResolutionToken,
                                      work::AlgebraicScopedWorkV4,
                                      plan::AlgebraicResidualPlanV4,
                                      scenario::AlgebraicScenarioV4,
                                      report::AlgebraicSliceReportV4)
        validated = _alg_scoped_report_validation(work, plan, scenario, report)
        validated.result.status == :numerical_fail && validated.evidence.status_vector.stage_outcome == numerical_fail ||
            throw(ArgumentError("AlgebraicScopedAttemptV4 requires a typed numerical failure"))
        selected = _alg_scoped_digest_tuple(plan.selected_constraint_hashes, "selected constraint hashes")
        remaining_unresolved = Tuple(String(x) for x in validated.remaining_unresolved_nonterminals)
        remaining_obligations = Tuple(validated.remaining_capability_obligations)
        body = (work_hash=work.work_hash, candidate_ref=work.candidate_ref,
            prefix_hash=work.prefix_hash, plan_hash=plan.plan_hash, stage=work.stage,
            scenario_hash=scenario.scenario_hash, capability_hash=canonical_hash(work.capability),
            subject_hash=report.subject.subject_hash, solver_input_hash=validated.input.solver_input_hash,
            provider_manifest_hash=validated.provider.manifest_hash, result_hash=validated.result.result_hash,
            evidence_hash=validated.evidence.evidence_id, classification=:attempt_failed,
            scope=_ALG_SCOPED_SCOPE, selected_constraint_hashes=selected,
            remaining_unresolved_nonterminals=remaining_unresolved,
            remaining_capability_obligations=remaining_obligations)
        new(work.work_hash, work.candidate_ref, work.prefix_hash, plan.plan_hash, work.stage,
            scenario.scenario_hash, canonical_hash(work.capability), report.subject.subject_hash,
            validated.input.solver_input_hash, validated.provider.manifest_hash, validated.result.result_hash,
            validated.evidence.evidence_id, :attempt_failed, _ALG_SCOPED_SCOPE, selected,
            remaining_unresolved, remaining_obligations, report, canonical_hash(body))
    end
end

semantic_view(x::AlgebraicScopedAttemptV4) =
    (work_hash=x.work_hash, candidate_ref=x.candidate_ref, prefix_hash=x.prefix_hash,
     plan_hash=x.plan_hash, stage=x.stage, scenario_hash=x.scenario_hash,
     capability_hash=x.capability_hash, subject_hash=x.subject_hash,
     solver_input_hash=x.solver_input_hash, provider_manifest_hash=x.provider_manifest_hash,
     result_hash=x.result_hash, evidence_hash=x.evidence_hash, classification=x.classification,
     scope=x.scope, selected_constraint_hashes=x.selected_constraint_hashes,
     remaining_unresolved_nonterminals=x.remaining_unresolved_nonterminals,
     remaining_capability_obligations=x.remaining_capability_obligations,
     attempt_hash=x.attempt_hash)

function make_algebraic_scoped_resolution(work::AlgebraicScopedWorkV4,
                                          plan::AlgebraicResidualPlanV4,
                                          scenario::AlgebraicScenarioV4,
                                          report::AlgebraicSliceReportV4)
    AlgebraicScopedResolutionV4(_ALG_SCOPED_RESOLUTION_TOKEN, work, plan, scenario, report)
end

algebraic_scoped_resolution(args...) = make_algebraic_scoped_resolution(args...)

function make_algebraic_scoped_attempt(work::AlgebraicScopedWorkV4,
                                       plan::AlgebraicResidualPlanV4,
                                       scenario::AlgebraicScenarioV4,
                                       report::AlgebraicSliceReportV4)
    AlgebraicScopedAttemptV4(_ALG_SCOPED_RESOLUTION_TOKEN, work, plan, scenario, report)
end

algebraic_scoped_attempt(args...) = make_algebraic_scoped_attempt(args...)
