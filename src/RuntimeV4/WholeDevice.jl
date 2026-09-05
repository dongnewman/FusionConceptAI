"""Whole-device admission and post-run closure audit.

Admission is a pre-run readiness decision.  The audit records stage closure,
but this module cannot promote a screen result to whole-device authority.
"""

struct WholeDeviceClosureV4
    admitted::Bool
    p5_ready::Bool
    outcome::Symbol
    stage_decisions::Tuple
    unresolved_gaps::Tuple
    claim_ceiling::ClaimCeiling
    provider_coverage_complete::Bool
    provider_registry_hash::Digest256
    goal_acceptance::Bool
    terminal_classification_executed::Bool
    closure_hash::Digest256
    function WholeDeviceClosureV4(::Val{:runtime_v4}, admitted::Bool, p5_ready::Bool,
                                  outcome::Symbol, stage_decisions::Tuple,
                                  unresolved_gaps::Tuple, claim_ceiling::ClaimCeiling,
                                  provider_coverage_complete::Bool,
                                  provider_registry_hash::Digest256, goal_acceptance::Bool,
                                  terminal_classification_executed::Bool)
        p5_ready && throw(ArgumentError("runtime v4 whole-device closure cannot be P5 ready"))
        goal_acceptance && throw(ArgumentError("runtime v4 goal acceptance is withheld"))
        terminal_classification_executed && throw(ArgumentError("runtime v4 terminal classification is withheld"))
        body = (admitted=admitted, p5_ready=p5_ready, outcome=outcome,
                stage_decisions=stage_decisions, unresolved_gaps=unresolved_gaps,
                claim_ceiling=claim_ceiling, provider_coverage_complete=provider_coverage_complete,
                provider_registry_hash=provider_registry_hash,
                goal_acceptance=goal_acceptance,
                terminal_classification_executed=terminal_classification_executed)
        new(admitted, p5_ready, outcome, stage_decisions, unresolved_gaps, claim_ceiling,
            provider_coverage_complete, provider_registry_hash, goal_acceptance,
            terminal_classification_executed, canonical_hash(body))
    end
end

semantic_view(x::WholeDeviceClosureV4) = (admitted=x.admitted, p5_ready=x.p5_ready,
    outcome=x.outcome, stage_decisions=x.stage_decisions,
    unresolved_gaps=x.unresolved_gaps, claim_ceiling=x.claim_ceiling,
    provider_coverage_complete=x.provider_coverage_complete,
    provider_registry_hash=x.provider_registry_hash, goal_acceptance=x.goal_acceptance,
    terminal_classification_executed=x.terminal_classification_executed,
    closure_hash=x.closure_hash)

function _runtime_valid_decision(decision::StageDecisionV4)
    body = (stage=decision.stage, spec_hash=decision.spec_hash,
            subject_hash=decision.subject_hash, provider_registry_hash=decision.provider_registry_hash,
            admitted=decision.admitted, outcome=decision.outcome,
            required_obligations=decision.required_obligations,
            evidence_refs=decision.evidence_refs, unresolved_gaps=decision.unresolved_gaps,
            claim_ceiling=decision.claim_ceiling, p5_ready=decision.p5_ready,
            closure_complete=decision.closure_complete)
    decision.decision_hash == canonical_hash(body)
end

function _runtime_valid_closure(closure::WholeDeviceClosureV4)
    body = (admitted=closure.admitted, p5_ready=closure.p5_ready, outcome=closure.outcome,
            stage_decisions=closure.stage_decisions, unresolved_gaps=closure.unresolved_gaps,
            claim_ceiling=closure.claim_ceiling, provider_coverage_complete=closure.provider_coverage_complete,
            provider_registry_hash=closure.provider_registry_hash,
            goal_acceptance=closure.goal_acceptance,
            terminal_classification_executed=closure.terminal_classification_executed)
    closure.closure_hash == canonical_hash(body) &&
        all(d -> d isa StageDecisionV4 && _runtime_valid_decision(d), closure.stage_decisions)
end

function _runtime_provider_tuple(providers)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    all(p -> p isa ProviderManifestV4, ps) ||
        throw(ArgumentError("provider registry must contain typed ProviderManifestV4 values"))
    ps
end

_runtime_provider_registry_hash(providers) = canonical_hash(_runtime_provider_tuple(providers))

function _runtime_stage_scenarios(spec::StageSpecV4, all_scenarios)
    isempty(spec.scenario_scope) && return ()
    xs = Tuple(x for x in all_scenarios if String(getfield(x, :name)) in spec.scenario_scope)
    _stage_scenarios(spec, xs)
end

function _runtime_prerequisite_decisions(spec::StageSpecV4, specs, prior_stage_decisions,
                                         subject_hash, provider_registry_hash)
    prior = Tuple(d for d in prior_stage_decisions if d isa StageDecisionV4)
    out = StageDecisionV4[]
    for prerequisite in spec.prerequisites
        candidates = Tuple(d for d in prior if d.stage == prerequisite)
        length(candidates) == 1 || return nothing
        expected = only(s for s in specs if s.stage == prerequisite)
        decision = only(candidates)
        _runtime_valid_decision(decision) || return nothing
        decision.spec_hash == expected.spec_hash || return nothing
        decision.subject_hash == subject_hash || return nothing
        decision.provider_registry_hash == provider_registry_hash || return nothing
        decision.admitted && decision.closure_complete || return nothing
        push!(out, decision)
    end
    Tuple(out)
end

function admit_whole_device(specs, subject; providers=(), scenarios=(), hard_gates=(),
                            protocol_ready=false, resources_ready=false,
                            prior_stage_decisions=())
    subject === nothing || subject isa ExecutablePhysicalSubjectV4 ||
        throw(ArgumentError("whole-device admission requires an ExecutablePhysicalSubjectV4 or nothing"))
    ss = Tuple(specs)
    isempty(ss) && throw(ArgumentError("whole-device admission requires at least one stage"))
    all(s -> s isa StageSpecV4, ss) || throw(ArgumentError("whole-device stages must be typed StageSpecV4"))
    length(unique(s.stage for s in ss)) == length(ss) || throw(ArgumentError("whole-device stages must be unique"))
    all_scenarios = _stage_named_scenarios(scenarios)
    ps = _runtime_provider_tuple(providers)
    registry_hash = canonical_hash(ps)
    subject_hash = _runtime_subject_hash(subject)
    decisions = Tuple(begin
        stage_scenarios = _runtime_stage_scenarios(spec, all_scenarios)
        prerequisites = _runtime_prerequisite_decisions(spec, ss, prior_stage_decisions,
            subject_hash, registry_hash)
        _admit_frontier(_RUNTIME_V4_TOKEN, spec; subject=subject, providers=ps, scenarios=stage_scenarios,
            hard_gates=hard_gates, protocol_ready=protocol_ready,
            resources_ready=resources_ready,
            prerequisite_decisions=prerequisites === nothing ? () : prerequisites)
    end for spec in ss)
    gaps = Tuple(g for d in decisions for g in d.unresolved_gaps)
    admitted = all(d.admitted for d in decisions)
    coverage = all(isempty(derive_provider_gaps(spec, _runtime_stage_scenarios(spec, all_scenarios), ps))
                   for spec in ss)
    WholeDeviceClosureV4(_RUNTIME_V4_TOKEN, admitted, false, :withheld, decisions, gaps,
        none, coverage, registry_hash, false, false)
end

function audit_whole_device(admission::WholeDeviceClosureV4, specs, scenarios;
                            evidence_refs=(), providers=nothing)
    _runtime_valid_closure(admission) || throw(ArgumentError("admission closure hash is invalid"))
    providers === nothing && throw(ArgumentError("audit requires the frozen provider registry"))
    ss = Tuple(specs)
    length(admission.stage_decisions) == length(ss) ||
        throw(ArgumentError("admission stage decision count does not match specs"))
    all(d.stage == spec.stage && d.spec_hash == spec.spec_hash
        for (d, spec) in zip(admission.stage_decisions, ss)) ||
        throw(ArgumentError("admission decisions do not match stage specs"))
    all_scenarios = _stage_named_scenarios(scenarios)
    registry_hash = if providers === nothing
        admission.provider_registry_hash
    else
        supplied = _runtime_provider_registry_hash(providers)
        supplied == admission.provider_registry_hash ||
            throw(ArgumentError("audit provider registry differs from admission registry"))
        supplied
    end
    ps = _runtime_provider_tuple(providers)
    coverage = all(isempty(derive_provider_gaps(spec, _runtime_stage_scenarios(spec, all_scenarios), ps))
                   for spec in ss)
    decisions = Tuple(close_frontier(spec, d, _runtime_stage_scenarios(spec, all_scenarios);
        evidence_refs=evidence_refs, providers=ps)
        for (spec, d) in zip(ss, admission.stage_decisions))
    gaps = Tuple(g for d in decisions for g in d.unresolved_gaps)
    # A screen closure is still only a stage closure.  No typed whole-device
    # validation/VVUQ package exists in runtime v4, so P5 remains withheld.
    WholeDeviceClosureV4(_RUNTIME_V4_TOKEN, admission.admitted, false, :withheld, decisions, gaps,
        none, coverage, registry_hash, false, false)
end
