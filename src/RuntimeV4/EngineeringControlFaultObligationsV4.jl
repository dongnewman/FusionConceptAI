# Typed engineering/control/fault execution obligations; never evidence or authority.
using FusionConceptAI

struct _EngineeringControlFaultToken end
const _ECO_TOKEN = _EngineeringControlFaultToken()
const _ECO_DOMAINS = (:engineering, :control, :fault)
const _ECO_EVIDENCE = (:engineering, :manufactured_control, :fault_recovery)

struct ControlFaultCaseV4
    name::String
    scenario_name::String
    limits::NamedTuple
    delay_ms::Float64
    dropout_probability::Float64
    fault_mode::Symbol
    recovery::String
    case_hash::Digest256
    function ControlFaultCaseV4(::_EngineeringControlFaultToken, name, scenario_name,
            limits, delay_ms, dropout_probability, fault_mode, recovery)
        new(String(name), String(scenario_name), limits, Float64(delay_ms),
            Float64(dropout_probability), fault_mode, String(recovery),
            canonical_hash((name=String(name), scenario_name=String(scenario_name),
                limits=limits, delay_ms=Float64(delay_ms),
                dropout_probability=Float64(dropout_probability), fault_mode=fault_mode,
                recovery=String(recovery))))
    end
end
function ControlFaultCaseV4(name, scenario_name, limits; delay_ms=0.0,
        dropout_probability=0.0, fault_mode=:none, recovery="")
    isempty(strip(String(name))) && throw(ArgumentError("case name required"))
    isempty(strip(String(scenario_name))) && throw(ArgumentError("scenario name required"))
    isfinite(delay_ms) && delay_ms >= 0 || throw(ArgumentError("invalid delay"))
    isfinite(dropout_probability) && 0 <= dropout_probability <= 1 ||
        throw(ArgumentError("invalid dropout probability"))
    fault_mode isa Symbol || throw(ArgumentError("typed fault mode required"))
    ControlFaultCaseV4(_ECO_TOKEN, name, scenario_name, limits, delay_ms,
        dropout_probability, fault_mode, recovery)
end
semantic_view(x::ControlFaultCaseV4) = (name=x.name, scenario_name=x.scenario_name,
    limits=x.limits, delay_ms=x.delay_ms, dropout_probability=x.dropout_probability,
    fault_mode=x.fault_mode, recovery=x.recovery)
canonical_hash(x::ControlFaultCaseV4) = x.case_hash

struct RecoveryRequirementV4
    name::String
    trigger::Symbol
    safe_state::String
    timeout_ms::Float64
    capability::Any
    evidence_class::Symbol
    requirement_hash::Digest256
    function RecoveryRequirementV4(::_EngineeringControlFaultToken, name, trigger,
            safe_state, timeout_ms, capability, evidence_class)
        new(String(name), trigger, String(safe_state), Float64(timeout_ms), capability,
            evidence_class, canonical_hash((name=String(name), trigger=trigger,
                safe_state=String(safe_state), timeout_ms=Float64(timeout_ms),
                capability=capability, evidence_class=evidence_class)))
    end
end
function RecoveryRequirementV4(name, trigger, safe_state, timeout_ms,
        capability, evidence_class)
    isempty(strip(String(name))) && throw(ArgumentError("recovery name required"))
    isempty(strip(String(safe_state))) && throw(ArgumentError("safe state required"))
    isfinite(timeout_ms) && timeout_ms > 0 || throw(ArgumentError("invalid recovery timeout"))
    trigger isa Symbol && evidence_class in _ECO_EVIDENCE ||
        throw(ArgumentError("invalid recovery typing"))
    RecoveryRequirementV4(_ECO_TOKEN, name, trigger, safe_state, timeout_ms,
        capability, evidence_class)
end
semantic_view(x::RecoveryRequirementV4) = (name=x.name, trigger=x.trigger,
    safe_state=x.safe_state, timeout_ms=x.timeout_ms, capability=x.capability,
    evidence_class=x.evidence_class)
canonical_hash(x::RecoveryRequirementV4) = x.requirement_hash

struct EngineeringControlFaultObligationV4
    name::String
    domain::Symbol
    graph_role::Symbol
    site::Any
    capability::CapabilitySignatureV4
    evidence_class::Symbol
    recovery::Union{Nothing,RecoveryRequirementV4}
    obligation_hash::Digest256
    function EngineeringControlFaultObligationV4(::_EngineeringControlFaultToken,
            name, domain, graph_role, site, capability, evidence_class, recovery)
        new(String(name), domain, graph_role, site, capability, evidence_class, recovery,
            canonical_hash((name=String(name), domain=domain, graph_role=graph_role,
                site=site, capability=capability, evidence_class=evidence_class,
                recovery=recovery)))
    end
end
function EngineeringControlFaultObligationV4(name, domain, graph_role, site,
        capability, evidence_class; recovery=nothing)
    isempty(strip(String(name))) && throw(ArgumentError("obligation name required"))
    domain in _ECO_DOMAINS || throw(ArgumentError("invalid obligation domain"))
    graph_role in (:control, :mechanism, :field_geometry) ||
        throw(ArgumentError("invalid graph role"))
    site === nothing && throw(ArgumentError("typed graph site required"))
    evidence_class in _ECO_EVIDENCE || throw(ArgumentError("invalid evidence class"))
    recovery isa Nothing || recovery isa RecoveryRequirementV4 ||
        throw(ArgumentError("typed recovery requirement required"))
    EngineeringControlFaultObligationV4(_ECO_TOKEN, name, domain, graph_role, site,
        capability, evidence_class, recovery)
end
semantic_view(x::EngineeringControlFaultObligationV4) = (name=x.name, domain=x.domain,
    graph_role=x.graph_role, site=x.site, capability=x.capability,
    evidence_class=x.evidence_class, recovery=x.recovery)
canonical_hash(x::EngineeringControlFaultObligationV4) = x.obligation_hash

struct EngineeringControlFaultRequestV4
    context::Any
    fault_case::ControlFaultCaseV4
    obligations::Tuple
    status::Symbol
    gaps::Tuple
    request_hash::Digest256
    function EngineeringControlFaultRequestV4(::_EngineeringControlFaultToken, args...)
        new(args...)
    end
end
EngineeringControlFaultRequestV4(args...) = throw(ArgumentError("sealed request"))
semantic_view(x::EngineeringControlFaultRequestV4) = (context_hash=x.context.context_hash,
    case_hash=x.fault_case.case_hash,
    obligation_hashes=Tuple(canonical_hash(o) for o in x.obligations), status=x.status,
    gaps=x.gaps)
canonical_hash(x::EngineeringControlFaultRequestV4) = x.request_hash

function build_engineering_control_fault_request(context,
        fault_case::ControlFaultCaseV4, obligations)
    validate_forward_chain_context(context)
    fault_case.scenario_name in context.scenario_scope ||
        throw(ArgumentError("fault case is outside context scenario scope"))
    os = Tuple(obligations)
    all(o isa EngineeringControlFaultObligationV4 for o in os) ||
        throw(ArgumentError("typed obligations required"))
    length(unique(o.name for o in os)) == length(os) ||
        throw(ArgumentError("obligation names must be unique"))
    gaps = String[]
    for o in os
        graph = try
            forward_graph_binding(context, o.graph_role)
        catch
            nothing
        end
        graph === nothing && (push!(gaps, "missing owned graph $(o.graph_role)"); continue)
        o.capability in context.obligations || push!(gaps, "capability gap: $(o.name)")
        o.domain === :fault && o.recovery === nothing &&
            push!(gaps, "recovery requirement missing: $(o.name)")
    end
    status = isempty(gaps) ? :ready : :recoverable_gap
    body = (context_hash=context.context_hash, case_hash=fault_case.case_hash,
        obligation_hashes=Tuple(canonical_hash(o) for o in os), status=status,
        gaps=Tuple(gaps))
    EngineeringControlFaultRequestV4(_ECO_TOKEN, context, fault_case, os, status,
        body.gaps, canonical_hash(body))
end

function validate_engineering_control_fault_request(request::EngineeringControlFaultRequestV4,
        context, fault_case::ControlFaultCaseV4, obligations)
    validate_forward_chain_context(context)
    request.context === context || return false
    request.fault_case === fault_case || return false
    expected = build_engineering_control_fault_request(context, fault_case, obligations)
    request.status === expected.status && request.gaps == expected.gaps &&
        request.request_hash == expected.request_hash
end
validate_engineering_control_fault_request(::EngineeringControlFaultRequestV4) = false
