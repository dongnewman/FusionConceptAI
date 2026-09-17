import FusionConceptAI: canonical_hash, semantic_view

"""Bounded G4 engineering/control/fault closure contracts.

This file deliberately contains contracts and validation only.  It does not
claim physical qualification: engineering and manufacturing/control evidence
are separate obligations and missing capabilities remain recoverable.
"""

const _ECF_REVISION = "g4-engineering-control-fault-v1"
const _ECF_TOKEN = Val(:engineering_control_fault_private)
const _ECF_STATUSES = (:pass, :fail, :unknown, :unsupported, :deferred)

_ecf_text(x, label) = (s = String(x); isempty(strip(s)) && throw(ArgumentError("$label must be non-empty")); s)
_ecf_status(x) = (x isa Symbol && x in _ECF_STATUSES) ? x : throw(ArgumentError("invalid closure status"))
_ecf_tuple(x) = Tuple(x)

struct EngineeringLoadV4
    name::String
    applied::Float64
    allowable::Float64
    unit::String
    evidence_ref::String
    function EngineeringLoadV4(name, applied, allowable; unit="SI", evidence_ref="")
        a, l = Float64(applied), Float64(allowable)
        isfinite(a) && isfinite(l) && a >= 0 && l >= 0 || throw(ArgumentError("finite nonnegative engineering load required"))
        u = _ecf_text(unit, "load unit"); u in ("SI", "N", "Pa", "A", "W", "J") || throw(ArgumentError("unsupported engineering load unit"))
        new(_ecf_text(name, "load name"), a, l, u, String(evidence_ref))
    end
end
semantic_view(x::EngineeringLoadV4) = (revision=_ECF_REVISION, name=x.name, applied=x.applied,
    allowable=x.allowable, unit=x.unit, evidence_ref=x.evidence_ref)
engineering_margin(x::EngineeringLoadV4) = x.allowable / max(x.applied, eps(Float64)) - 1.0

struct ObservationDependencyV4
    name::String
    channel::ObservationChannelRefV1
    required::Bool
    channel_hash::Digest256
end
ObservationDependencyV4(name, channel::ObservationChannelRefV1; required=true, channel_hash=digest256_text("unbound")) =
    ObservationDependencyV4(_ecf_text(name,"observation name"), channel, Bool(required), channel_hash)
semantic_view(x::ObservationDependencyV4) = (revision=_ECF_REVISION, name=x.name, channel=x.channel,
    required=x.required, channel_hash=x.channel_hash)

struct ActuationDependencyV4
    name::String
    actuator::OperatorSiteRefV1
    required::Bool
    actuator_hash::Digest256
end
ActuationDependencyV4(name, actuator::OperatorSiteRefV1; required=true, actuator_hash=digest256_text("unbound")) =
    ActuationDependencyV4(_ecf_text(name,"actuation name"), actuator, Bool(required), actuator_hash)
semantic_view(x::ActuationDependencyV4) = (revision=_ECF_REVISION, name=x.name, actuator=x.actuator,
    required=x.required, actuator_hash=x.actuator_hash)

struct FaultScenarioV4
    name::String
    trigger::String
    safe_state::String
    recovery::String
    observation_names::Tuple
    actuation_names::Tuple
    evidence_ref::String
end
function FaultScenarioV4(name, trigger, safe_state, recovery;
                         observation_names=(), actuation_names=(), evidence_ref="")
    FaultScenarioV4(_ecf_text(name,"fault name"), _ecf_text(trigger,"fault trigger"),
        _ecf_text(safe_state,"safe state"), _ecf_text(recovery,"recovery"),
        Tuple(String.(observation_names)), Tuple(String.(actuation_names)), String(evidence_ref))
end
semantic_view(x::FaultScenarioV4) = (revision=_ECF_REVISION, name=x.name, trigger=x.trigger,
    safe_state=x.safe_state, recovery=x.recovery, observation_names=x.observation_names,
    actuation_names=x.actuation_names, evidence_ref=x.evidence_ref)

struct EvidenceObligationV4
    name::String
    domain::Symbol
    required::Bool
    status::Symbol
    evidence_target::Union{Nothing,Tuple{Digest256,Digest256}}
end
function EvidenceObligationV4(name, domain; required=true, status=:unknown, evidence_target=nothing)
    domain in (:physical, :engineering, :control, :manufacturing, :fault) || throw(ArgumentError("invalid evidence domain"))
    evidence_target === nothing || (evidence_target isa Tuple && length(evidence_target) == 2 && all(x -> x isa Digest256, evidence_target)) || throw(ArgumentError("evidence target must be (Digest256,Digest256)"))
    EvidenceObligationV4(_ecf_text(name,"obligation name"), domain, Bool(required), _ecf_status(status), evidence_target)
end
semantic_view(x::EvidenceObligationV4) = (revision=_ECF_REVISION, name=x.name, domain=x.domain,
    required=x.required, status=x.status, evidence_target=x.evidence_target)

struct EngineeringControlFaultInputV4
    candidate::CandidateStatePackageV4
    compiled::Union{Nothing,CompiledCandidatePrefixV4}
    subject::Union{Nothing,ExecutablePhysicalSubjectV4}
    scenario::Any
    mechanism::MechanismGenomeV4
    field_geometry::FieldGeometryGenomeV4
    realization_control::RealizationControlGenomeV4
    registry::GenomeContractRegistryV4
    loads::Tuple
    observations::Tuple
    actuations::Tuple
    faults::Tuple
    obligations::Tuple
    input_hash::Digest256
end
function EngineeringControlFaultInputV4(candidate::CandidateStatePackageV4, registry::GenomeContractRegistryV4;
        compiled=nothing, subject=nothing, scenario=nothing,
        loads=(), observations=(), actuations=(), faults=(), obligations=())
    ls, os, as, fs, es = Tuple(loads), Tuple(observations), Tuple(actuations), Tuple(faults), Tuple(obligations)
    all(x -> x isa EngineeringLoadV4, ls) || throw(ArgumentError("typed engineering loads required"))
    all(x -> x isa ObservationDependencyV4, os) || throw(ArgumentError("typed observations required"))
    all(x -> x isa ActuationDependencyV4, as) || throw(ArgumentError("typed actuations required"))
    all(x -> x isa FaultScenarioV4, fs) || throw(ArgumentError("typed fault scenarios required"))
    all(x -> x isa EvidenceObligationV4, es) || throw(ArgumentError("typed evidence obligations required"))
    compiled === nothing || compiled isa CompiledCandidatePrefixV4 || throw(ArgumentError("typed compiled prefix required"))
    subject === nothing || subject isa ExecutablePhysicalSubjectV4 || throw(ArgumentError("typed physical subject required"))
    body = (revision=_ECF_REVISION, candidate=canonical_hash(candidate), compiled=compiled,
        subject=subject, scenario=scenario, registry=registry, loads=ls, observations=os,
        actuations=as, faults=fs, obligations=es)
    EngineeringControlFaultInputV4(candidate, compiled, subject, scenario,
        candidate.mechanism_genome_ref, candidate.field_geometry_genome_ref,
        candidate.realization_control_genome_ref, registry, ls, os, as, fs, es, canonical_hash(body))
end
semantic_view(x::EngineeringControlFaultInputV4) = (revision=_ECF_REVISION,
    candidate=canonical_hash(x.candidate), compiled=x.compiled, subject=x.subject, scenario=x.scenario,
    registry=x.registry,
    loads=x.loads, observations=x.observations, actuations=x.actuations, faults=x.faults, obligations=x.obligations)
canonical_hash(x::EngineeringControlFaultInputV4) = begin
    h = canonical_hash(semantic_view(x)); h == x.input_hash || throw(ArgumentError("G4 input tampered")); h
end

struct EngineeringControlFaultDecisionV4
    status::Symbol
    engineering_status::Symbol
    control_status::Symbol
    fault_status::Symbol
    unresolved::Tuple{Vararg{String}}
    unsupported::Tuple{Vararg{String}}
    physical_evidence_satisfied::Bool
    decision_hash::Digest256
    function EngineeringControlFaultDecisionV4(token::Val{:engineering_control_fault_private}, fields...)
        token === _ECF_TOKEN || throw(ArgumentError("private G4 decision constructor")); new(fields...)
    end
end
semantic_view(x::EngineeringControlFaultDecisionV4) = (revision=_ECF_REVISION, status=x.status,
    engineering_status=x.engineering_status, control_status=x.control_status, fault_status=x.fault_status,
    unresolved=x.unresolved, unsupported=x.unsupported, physical_evidence_satisfied=x.physical_evidence_satisfied)
canonical_hash(x::EngineeringControlFaultDecisionV4) = begin
    h=canonical_hash(semantic_view(x)); h == x.decision_hash || throw(ArgumentError("G4 decision tampered")); h
end

function validate_engineering_control_fault(input::EngineeringControlFaultInputV4)
    canonical_hash(input)
    unresolved, unsupported = String[], String[]
    refs = (input.candidate.mechanism_genome_ref, input.candidate.field_geometry_genome_ref, input.candidate.realization_control_genome_ref)
    refs == (input.registry.mechanism, input.registry.field_geometry, input.registry.realization_control) ||
        push!(unresolved, "candidate Genome contract binding mismatch")
    for x in input.loads
        engineering_margin(x) < 0 && push!(unresolved, "load $(x.name) exceeds allowable")
        isempty(x.evidence_ref) && push!(unresolved, "engineering evidence missing: $(x.name)")
    end
    for x in input.observations
        x.required && x.channel_hash == digest256_text("unbound") && push!(unsupported, "observation capability unsupported: $(x.channel.value)")
    end
    for x in input.actuations
        x.required && x.actuator_hash == digest256_text("unbound") && push!(unsupported, "actuation capability unsupported: $(x.actuator.value)")
    end
    for x in input.faults
        isempty(x.recovery) && push!(unresolved, "fault recovery missing: $(x.name)")
        isempty(x.evidence_ref) && push!(unresolved, "fault evidence missing: $(x.name)")
    end
    physical = all(x -> !x.required || x.domain != :physical || x.status === :pass, input.obligations)
    for x in input.obligations
        x.required && x.status !== :pass && push!(unresolved, "$(x.domain) evidence obligation unresolved: $(x.name)")
        x.required && x.status === :pass && x.evidence_target === nothing && push!(unresolved, "$(x.domain) pass lacks evidence target: $(x.name)")
    end
    eng_fail = any(occursin("exceeds", x) for x in unresolved) ||
        any(x.required && x.domain in (:engineering, :manufacturing) && x.status === :fail for x in input.obligations)
    eng = eng_fail ? :fail : (isempty(unresolved) ? :pass : :deferred)
    ctl = any(occursin("capability unsupported", x) for x in unsupported) ? :unsupported :
        (any(x.required && x.domain === :control && x.status === :fail for x in input.obligations) ? :fail : :pass)
    flt = isempty(input.faults) ? :deferred : (any(occursin("fault recovery missing", x) for x in unresolved) ? :deferred :
        (any(x.required && x.domain === :fault && x.status === :fail for x in input.obligations) ? :fail : :pass))
    overall = !physical ? :deferred : ctl === :unsupported ? :deferred :
        (eng === :fail || flt === :fail || ctl === :fail) ? :fail :
        (eng === :deferred || flt === :deferred ? :deferred : :pass)
    draft = EngineeringControlFaultDecisionV4(_ECF_TOKEN, overall, eng, ctl, flt, Tuple(unresolved), Tuple(unsupported), physical, digest256_text("draft"))
    EngineeringControlFaultDecisionV4(_ECF_TOKEN, overall, eng, ctl, flt, Tuple(unresolved), Tuple(unsupported), physical, canonical_hash(semantic_view(draft)))
end
