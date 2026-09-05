"""Frozen stage contracts and conservative frontier admission."""

const _RUNTIME_V4_TOKEN = Val(:runtime_v4)

abstract type AbstractStageRequirementV4 end

struct ExactCapabilityRequirementV4 <: AbstractStageRequirementV4
    signature::CapabilitySignatureV4
    requirement_hash::Digest256
    function ExactCapabilityRequirementV4(signature::CapabilitySignatureV4)
        new(signature, canonical_hash(signature))
    end
end

struct UnresolvedStageDeclarationV4 <: AbstractStageRequirementV4
    code::Symbol
    missing_axes::Tuple{Vararg{Symbol}}
    source_hash::Digest256
    required_ceiling::ClaimCeiling
    requirement_hash::Digest256
    function UnresolvedStageDeclarationV4(code::Symbol, missing_axes, source_hash,
                                          required_ceiling::ClaimCeiling)
        _runtime_nonwild_text(String(code), "unresolved declaration code")
        axes = Tuple(Symbol(axis) for axis in missing_axes)
        isempty(axes) && throw(ArgumentError("unresolved declaration requires missing axes"))
        length(unique(axes)) == length(axes) || throw(ArgumentError("unresolved declaration axes must be unique"))
        any(lowercase(String(axis)) in ("*", "any", "wildcard", "all") for axis in axes) &&
            throw(ArgumentError("unresolved declaration axes cannot be wildcard"))
        body = (code=code, missing_axes=axes, source_hash=_runtime_digest(source_hash),
                required_ceiling=required_ceiling)
        new(code, axes, body.source_hash, required_ceiling, canonical_hash(body))
    end
end

_stage_requirement(x::CapabilitySignatureV4) = ExactCapabilityRequirementV4(x)
_stage_requirement(x::AbstractStageRequirementV4) = x
_stage_requirement(x) = throw(ArgumentError("stage requirements must be typed"))
_stage_signature(x::ExactCapabilityRequirementV4) = x.signature
_stage_signature(x::CapabilitySignatureV4) = x
_stage_signature(::UnresolvedStageDeclarationV4) = nothing
_stage_requirement_hash(x::AbstractStageRequirementV4) = x.requirement_hash

semantic_view(x::ExactCapabilityRequirementV4) =
    (signature=x.signature, requirement_hash=x.requirement_hash)
semantic_view(x::UnresolvedStageDeclarationV4) =
    (code=x.code, missing_axes=x.missing_axes, source_hash=x.source_hash,
     required_ceiling=x.required_ceiling, requirement_hash=x.requirement_hash)

struct StageSpecV4
    stage::Symbol
    required_signatures::Tuple{Vararg{AbstractStageRequirementV4}}
    prerequisites::Tuple{Vararg{Symbol}}
    scenario_scope::Tuple{Vararg{String}}
    required_ceiling::ClaimCeiling
    gate_policy_hash::Digest256
    spec_hash::Digest256
    function StageSpecV4(stage::Symbol, signatures, prerequisites, scenario_scope,
                         required_ceiling::ClaimCeiling; gate_policy_hash=nothing)
        _runtime_nonwild_text(String(stage), "stage")
        isempty(strip(String(stage))) && throw(ArgumentError("stage cannot be empty"))
        lowercase(String(stage)) in ("*", "any", "wildcard", "all") && throw(ArgumentError("stage cannot be wildcard"))
        sigs = Tuple(_stage_requirement(s) for s in signatures)
        isempty(sigs) && throw(ArgumentError("stage requires at least one requirement"))
        pre = Tuple(Symbol(p) for p in prerequisites)
        length(unique(pre)) == length(pre) || throw(ArgumentError("stage prerequisites must be unique"))
        stage in pre && throw(ArgumentError("stage cannot prerequisite itself"))
        unresolved_scope = any(r -> r isa UnresolvedStageDeclarationV4 &&
            :scenario_scope in r.missing_axes, sigs)
        scope = _runtime_axis_tuple(scenario_scope, "stage scenario_scope";
            allow_empty=unresolved_scope)
        policy = gate_policy_hash === nothing ? canonical_hash((stage=stage, prerequisites=pre,
            scenario_scope=scope, required_ceiling=required_ceiling, signatures=sigs)) : _runtime_digest(gate_policy_hash)
        body = (stage=stage, required_signatures=sigs, prerequisites=pre,
                scenario_scope=scope, required_ceiling=required_ceiling, gate_policy_hash=policy)
        new(stage, sigs, pre, scope, required_ceiling, policy, canonical_hash(body))
    end
end

semantic_view(x::StageSpecV4) = (stage=x.stage, required_signatures=x.required_signatures,
    prerequisites=x.prerequisites, scenario_scope=x.scenario_scope,
    required_ceiling=x.required_ceiling, gate_policy_hash=x.gate_policy_hash,
    spec_hash=x.spec_hash)

struct StageDecisionV4
    stage::Symbol
    spec_hash::Digest256
    subject_hash::Union{Nothing,Digest256}
    provider_registry_hash::Digest256
    admitted::Bool
    outcome::Symbol
    required_obligations::Tuple
    evidence_refs::Tuple
    unresolved_gaps::Tuple
    claim_ceiling::ClaimCeiling
    p5_ready::Bool
    closure_complete::Bool
    decision_hash::Digest256
    function StageDecisionV4(::Val{:runtime_v4}, stage::Symbol, spec_hash::Digest256,
                             subject_hash::Union{Nothing,Digest256}, provider_registry_hash::Digest256,
                             admitted::Bool, outcome::Symbol, required_obligations::Tuple,
                             evidence_refs::Tuple, unresolved_gaps::Tuple,
                             claim_ceiling::ClaimCeiling, p5_ready::Bool, closure_complete::Bool)
        outcome in (:admitted, :evidence_closed, :withheld) || throw(ArgumentError("invalid stage decision outcome"))
        p5_ready && throw(ArgumentError("runtime v4 stage decisions cannot be P5 ready"))
        outcome == :admitted && (admitted && !closure_complete && isempty(evidence_refs) ||
            throw(ArgumentError("admitted decision has invalid closure state")))
        outcome == :withheld && closure_complete && throw(ArgumentError("withheld decision cannot be closure complete"))
        if outcome == :evidence_closed
            admitted && closure_complete && isempty(unresolved_gaps) ||
                throw(ArgumentError("evidence-closed decision has unresolved gaps"))
            all(ref -> ref isa StageEvidenceBindingV4 && ref.stage == stage &&
                ref.spec_hash == spec_hash && ref.subject.physical_subject_hash == subject_hash,
                evidence_refs) || throw(ArgumentError("evidence-closed decision has invalid evidence refs"))
        end
        body = (stage=stage, spec_hash=spec_hash, subject_hash=subject_hash,
                provider_registry_hash=provider_registry_hash, admitted=admitted,
                outcome=outcome, required_obligations=required_obligations,
                evidence_refs=evidence_refs, unresolved_gaps=unresolved_gaps,
                claim_ceiling=claim_ceiling, p5_ready=p5_ready,
                closure_complete=closure_complete)
        new(stage, spec_hash, subject_hash, provider_registry_hash, admitted, outcome,
            required_obligations, evidence_refs, unresolved_gaps, claim_ceiling,
            p5_ready, closure_complete, canonical_hash(body))
    end
end

semantic_view(x::StageDecisionV4) = (stage=x.stage, spec_hash=x.spec_hash,
    subject_hash=x.subject_hash, provider_registry_hash=x.provider_registry_hash,
    admitted=x.admitted, outcome=x.outcome, required_obligations=x.required_obligations,
    evidence_refs=x.evidence_refs, unresolved_gaps=x.unresolved_gaps,
    claim_ceiling=x.claim_ceiling, p5_ready=x.p5_ready,
    closure_complete=x.closure_complete, decision_hash=x.decision_hash)

function _runtime_subject_hash(subject)
    subject === nothing && return nothing
    subject isa ExecutablePhysicalSubjectV4 && return subject.physical_subject_hash
    canonical_hash(subject)
end

function _stage_scenario_names(scenarios)
    xs = scenarios isa NamedTuple ? (scenarios,) : Tuple(scenarios)
    isempty(xs) && throw(ArgumentError("stage requires at least one scenario"))
    all(is_canonical_value, xs) || throw(ArgumentError("stage scenario is not canonicalizable"))
    names = Tuple(begin
        x isa NamedTuple && :name in keys(x) || throw(ArgumentError("scenario must carry an explicit name"))
        n = getfield(x, :name)
        n isa AbstractString && !isempty(strip(String(n))) || throw(ArgumentError("scenario name must be non-empty"))
        lowercase(String(n)) in ("*", "any", "wildcard", "all") && throw(ArgumentError("scenario name cannot be wildcard"))
        String(n)
    end for x in xs)
    length(unique(names)) == length(names) || throw(ArgumentError("scenario names must be unique"))
    xs, names
end

function _stage_scenarios(spec::StageSpecV4, scenarios)
    xs, names = _stage_scenario_names(scenarios)
    all(name -> name in spec.scenario_scope, names) || throw(ArgumentError("scenario is outside stage scenario_scope"))
    Set(names) == Set(spec.scenario_scope) || throw(ArgumentError("stage scenarios must exactly equal stage scenario_scope"))
    xs
end

function _stage_execution_scenarios(spec::StageSpecV4, scenarios)
    isempty(spec.scenario_scope) && return ()
    _stage_scenarios(spec, scenarios)
end

_stage_named_scenarios(scenarios) = first(_stage_scenario_names(scenarios))

function derive_provider_gaps(spec::StageSpecV4, scenarios, providers)
    _stage_execution_scenarios(spec, scenarios)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    Tuple(begin
        sig = _stage_signature(req)
        (stage=spec.stage, requirement_hash=_stage_requirement_hash(req),
         signature_hash=sig === nothing ? nothing : canonical_hash(sig),
         reason=sig === nothing ? "stage_declaration_unresolved" : "missing_exact_provider")
    end for req in spec.required_signatures
    if _stage_signature(req) === nothing ||
       (r = match_provider(_stage_signature(req), ps); r.status != unique_match ||
        r.obligation_hash != canonical_hash(_stage_signature(req))))
end

struct StageEvidenceBindingV4
    stage::Symbol
    spec_hash::Digest256
    signature_hash::Digest256
    scenario_hash::Digest256
    physical_subject_hash::Digest256
    solver_input_hash::Digest256
    provider_manifest_hash::Digest256
    evidence_id::Digest256
    subject::ExecutablePhysicalSubjectV4
    input::SolverInputV4
    evidence::RuntimeEvidenceV4
    match::ProviderMatchResultV4
    binding_hash::Digest256
    function StageEvidenceBindingV4(::Val{:runtime_v4}, stage::Symbol, spec_hash::Digest256,
                                    signature_hash::Digest256, scenario_hash::Digest256,
                                    physical_subject_hash::Digest256, solver_input_hash::Digest256,
                                    provider_manifest_hash::Digest256, evidence_id::Digest256,
                                    subject::ExecutablePhysicalSubjectV4, input::SolverInputV4,
                                    evidence::RuntimeEvidenceV4, match::ProviderMatchResultV4,
                                    binding_hash::Digest256)
        new(stage, spec_hash, signature_hash, scenario_hash, physical_subject_hash,
            solver_input_hash, provider_manifest_hash, evidence_id, subject, input,
            evidence, match, binding_hash)
    end
end

semantic_view(x::StageEvidenceBindingV4) = (stage=x.stage, spec_hash=x.spec_hash,
    signature_hash=x.signature_hash, scenario_hash=x.scenario_hash,
    subject=x.subject, input=x.input, evidence=x.evidence, match=x.match,
    binding_hash=x.binding_hash)

function StageEvidenceBindingV4(stage::Symbol, spec::StageSpecV4,
                               signature::CapabilitySignatureV4, scenario,
                               subject::ExecutablePhysicalSubjectV4,
                               input::SolverInputV4, evidence::RuntimeEvidenceV4,
                               match::ProviderMatchResultV4)
    stage == spec.stage || throw(ArgumentError("binding stage does not match spec"))
    sig_hash = canonical_hash(signature)
    any((_stage_signature(required) !== nothing && canonical_hash(_stage_signature(required)) == sig_hash)
        for required in spec.required_signatures) ||
        throw(ArgumentError("binding signature is not required by spec"))
    scenario isa NamedTuple && :name in keys(scenario) || throw(ArgumentError("binding scenario must carry an explicit name"))
    name = getfield(scenario, :name)
    name isa AbstractString && String(name) in spec.scenario_scope ||
        throw(ArgumentError("binding scenario is outside spec scope"))
    match.status == unique_match && match.provider !== nothing || throw(ArgumentError("binding requires unique provider match"))
    match.obligation_hash == sig_hash || throw(ArgumentError("provider match obligation hash mismatch"))
    match_provider(signature, (match.provider,)).status == unique_match ||
        throw(ArgumentError("provider is not an exact match for binding signature"))
    scenario_hash = canonical_hash(scenario)
    input.scenario_hash == scenario_hash || throw(ArgumentError("input scenario hash mismatch"))
    evidence.scenario_hash == scenario_hash || throw(ArgumentError("evidence scenario hash mismatch"))
    input.physical_subject_hash == subject.physical_subject_hash ||
        throw(ArgumentError("input subject hash mismatch"))
    evidence.physical_subject_hash == input.physical_subject_hash || throw(ArgumentError("evidence subject hash mismatch"))
    input.provider_manifest_hash == match.provider.manifest_hash || throw(ArgumentError("input provider hash mismatch"))
    input.input_schema_hash == match.provider.input_schema_hash || throw(ArgumentError("input schema hash mismatch"))
    evidence.solver_input_hash == input.solver_input_hash || throw(ArgumentError("evidence solver hash mismatch"))
    evidence.provider_manifest_hash == match.provider.manifest_hash || throw(ArgumentError("evidence provider hash mismatch"))
    hasproperty(input.payload, :requested_obligation) &&
        canonical_hash(getproperty(input.payload, :requested_obligation)) == sig_hash ||
        throw(ArgumentError("input requested obligation mismatch"))
    sv = evidence.status_vector
    sv.applicability == required && sv.match_status == unique_match &&
        sv.resolution == resolved && sv.stage_outcome == pass ||
        throw(ArgumentError("evidence status is not a required resolved pass"))
    _runtime_ceiling_rank(evidence.claim_ceiling) >= _runtime_ceiling_rank(spec.required_ceiling) ||
        throw(ArgumentError("evidence claim ceiling is below stage requirement"))
    _runtime_ceiling_rank(evidence.claim_ceiling) <= _runtime_ceiling_rank(match.provider.claim_ceiling) ||
        throw(ArgumentError("evidence claim ceiling exceeds provider ceiling"))
    any(canonical_hash(obligation) == sig_hash for obligation in subject.operator_obligations) ||
        throw(ArgumentError("binding signature is not part of subject obligations"))
    body = (stage=stage, spec_hash=spec.spec_hash, signature_hash=sig_hash,
            scenario_hash=scenario_hash, physical_subject_hash=subject.physical_subject_hash,
            solver_input_hash=input.solver_input_hash,
            provider_manifest_hash=match.provider.manifest_hash,
            evidence_id=evidence.evidence_id,
            input=input, evidence=evidence, match=match)
    StageEvidenceBindingV4(_RUNTIME_V4_TOKEN, stage, spec.spec_hash, sig_hash, scenario_hash,
        subject.physical_subject_hash, input.solver_input_hash, match.provider.manifest_hash,
        evidence.evidence_id, subject, input, evidence, match, canonical_hash(body))
end

function _runtime_valid_binding(binding::StageEvidenceBindingV4)
    body = (stage=binding.stage, spec_hash=binding.spec_hash,
            signature_hash=binding.signature_hash, scenario_hash=binding.scenario_hash,
            physical_subject_hash=binding.physical_subject_hash,
            solver_input_hash=binding.solver_input_hash,
            provider_manifest_hash=binding.provider_manifest_hash,
            evidence_id=binding.evidence_id, input=binding.input,
            evidence=binding.evidence, match=binding.match)
    binding.binding_hash == canonical_hash(body)
end

function derive_stage_gaps(spec::StageSpecV4, scenarios; evidence=(), allowed_provider_hashes=nothing)
    xs = _stage_execution_scenarios(spec, scenarios)
    counts = Dict{Tuple{Digest256,Digest256},Int}()
    for binding in evidence
        binding isa StageEvidenceBindingV4 && _runtime_valid_binding(binding) || continue
        binding.stage == spec.stage && binding.spec_hash == spec.spec_hash || continue
        allowed_provider_hashes === nothing ||
            binding.match.provider.manifest_hash in allowed_provider_hashes || continue
        key = (binding.signature_hash, binding.scenario_hash)
        counts[key] = get(counts, key, 0) + 1
    end
    gaps = NamedTuple[]
    for req in spec.required_signatures
        _stage_signature(req) === nothing || continue
        push!(gaps, (stage=spec.stage, requirement_hash=_stage_requirement_hash(req),
                     signature_hash=nothing, scenario_hash=nothing,
                     reason="stage_declaration_unresolved"))
    end
    for req in spec.required_signatures, scenario in xs
        sig = _stage_signature(req)
        sig === nothing && continue
        key = (sig === nothing ? _stage_requirement_hash(req) : canonical_hash(sig), canonical_hash(scenario))
        count = get(counts, key, 0)
        if sig === nothing
            push!(gaps, (stage=spec.stage, requirement_hash=key[1], signature_hash=nothing,
                         scenario_hash=key[2], reason="stage_declaration_unresolved"))
        elseif count != 1
            reason = count == 0 ? "missing_exact_match_or_evidence" : "ambiguous_duplicate_evidence"
            push!(gaps, (stage=spec.stage, requirement_hash=key[1], signature_hash=key[1],
                         scenario_hash=key[2], reason=reason))
        end
    end
    Tuple(gaps)
end

function _admit_frontier(::Val{:runtime_v4}, spec::StageSpecV4; subject=nothing, providers=(), scenarios=(),
                        hard_gates=(), protocol_ready=false, resources_ready=false,
                        prerequisite_decisions=())
    subject === nothing || subject isa ExecutablePhysicalSubjectV4 ||
        throw(ArgumentError("frontier admission requires an ExecutablePhysicalSubjectV4 or nothing"))
    xs = _stage_execution_scenarios(spec, scenarios)
    provider_gaps = derive_provider_gaps(spec, xs, providers)
    prereq_stages = Tuple(d.stage for d in prerequisite_decisions if d isa StageDecisionV4)
    prereq_ok = length(prerequisite_decisions) == length(spec.prerequisites) &&
        length(unique(prereq_stages)) == length(spec.prerequisites) &&
        Set(prereq_stages) == Set(spec.prerequisites) &&
        all(d -> d isa StageDecisionV4 && d.admitted && d.closure_complete &&
            d.outcome == :evidence_closed, prerequisite_decisions)
    pre_gaps = Tuple((stage=spec.stage, reason=reason) for reason in (
        subject === nothing ? "missing_physical_subject" : nothing,
        isempty(hard_gates) ? "hard_gate_not_declared" : (all(identity, hard_gates) ? nothing : "hard_gate_not_ready"),
        protocol_ready ? nothing : "protocol_not_ready",
        resources_ready ? nothing : "resources_not_ready",
        prereq_ok ? nothing : "prerequisite_not_ready") if reason !== nothing)
    pre_gaps = (pre_gaps..., provider_gaps...)
    admitted = isempty(pre_gaps)
    sh = _runtime_subject_hash(subject)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    StageDecisionV4(_RUNTIME_V4_TOKEN, spec.stage, spec.spec_hash, sh, canonical_hash(ps),
        admitted, admitted ? :admitted : :withheld,
        spec.required_signatures, (), pre_gaps, admitted ? spec.required_ceiling : none, false, false)
end

function admit_frontier(spec::StageSpecV4; kwargs...)
    isempty(spec.prerequisites) ||
        throw(ArgumentError("stages with prerequisites must be admitted through admit_whole_device"))
    _admit_frontier(_RUNTIME_V4_TOKEN, spec; kwargs...)
end

function close_frontier(spec::StageSpecV4, admission::StageDecisionV4, scenarios;
                        evidence_refs=(), providers)
    admission.stage == spec.stage && admission.spec_hash == spec.spec_hash ||
        throw(ArgumentError("stage decision does not match stage spec"))
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    canonical_hash(ps) == admission.provider_registry_hash ||
        throw(ArgumentError("closure provider registry does not match admission"))
    allowed_provider_hashes = Set(p.manifest_hash for p in ps)
    gaps = derive_stage_gaps(spec, scenarios; evidence=evidence_refs,
        allowed_provider_hashes=allowed_provider_hashes)
    all_gaps = (admission.unresolved_gaps..., gaps...)
    ready = admission.admitted && isempty(all_gaps)
    StageDecisionV4(_RUNTIME_V4_TOKEN, spec.stage, spec.spec_hash, admission.subject_hash, admission.provider_registry_hash,
        admission.admitted, ready ? :evidence_closed : :withheld,
        spec.required_signatures, Tuple(evidence_refs), all_gaps,
        ready ? spec.required_ceiling : none, false, ready)
end
