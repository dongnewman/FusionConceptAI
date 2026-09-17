"""Typed engineering/control/fault provider-admission request. No evidence or execution."""

struct _EngineeringControlFaultExecutionToken end
const _ECFE_TOKEN = _EngineeringControlFaultExecutionToken()

struct EngineeringControlFaultSiteV4
    role::Symbol
    graph_binding_hash::Digest256
    node_identity_hashes::Tuple{Vararg{Digest256}}
    edge_identity_hashes::Tuple{Vararg{Digest256}}
    ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    output_identity_hashes::Tuple{Vararg{Digest256}}
    site_hash::Digest256
    function EngineeringControlFaultSiteV4(::_EngineeringControlFaultExecutionToken, a...)
        new(a...)
    end
end
EngineeringControlFaultSiteV4(a...) = throw(ArgumentError("sealed graph site"))
semantic_view(x::EngineeringControlFaultSiteV4) = (role=x.role,
    graph_binding_hash=x.graph_binding_hash, node_identity_hashes=x.node_identity_hashes,
    edge_identity_hashes=x.edge_identity_hashes,
    ast_root_identity_hashes=x.ast_root_identity_hashes,
    output_identity_hashes=x.output_identity_hashes)
canonical_hash(x::EngineeringControlFaultSiteV4) = x.site_hash

function _ecfe_site(context::ForwardChainContextV4, role::Symbol)
    role in (:realization, :control) || throw(ArgumentError("site must be realization or control"))
    binding = forward_graph_binding(context, role)
    graph = binding.graph
    outputs = Digest256[]
    roots = Digest256[]
    for edge in graph.hyperedges
        if edge isa AtomicMIMOHyperedgeV1
            push!(roots, edge.program_hash)
            append!(outputs, Digest256[canonical_hash(x) for x in edge.output_bindings])
        else
            push!(roots, canonical_hash(edge.ast))
            append!(outputs, Digest256[canonical_hash(x) for x in edge.outputs])
        end
    end
    body = (role=role, graph_binding_hash=canonical_hash(binding),
        node_identity_hashes=binding.node_identity_hashes,
        edge_identity_hashes=binding.hyperedge_identity_hashes,
        ast_root_identity_hashes=Tuple(roots), output_identity_hashes=Tuple(outputs))
    EngineeringControlFaultSiteV4(_ECFE_TOKEN, role, canonical_hash(binding),
        binding.node_identity_hashes, binding.hyperedge_identity_hashes, Tuple(roots),
        Tuple(outputs), canonical_hash(body))
end

struct EngineeringControlFaultCaseV4
    context_hash::Digest256
    scenario_hash::Digest256
    name::String
    limits::Any
    delay_ms::Float64
    dropout_probability::Float64
    recovery_timeout_ms::Float64
    fault_mode::Symbol
    case_hash::Digest256
    function EngineeringControlFaultCaseV4(::_EngineeringControlFaultExecutionToken, a...)
        new(a...)
    end
end
EngineeringControlFaultCaseV4(a...) = throw(ArgumentError("sealed fault case"))
semantic_view(x::EngineeringControlFaultCaseV4) = (context_hash=x.context_hash,
    scenario_hash=x.scenario_hash, name=x.name, limits=x.limits, delay_ms=x.delay_ms,
    dropout_probability=x.dropout_probability,
    recovery_timeout_ms=x.recovery_timeout_ms, fault_mode=x.fault_mode)
canonical_hash(x::EngineeringControlFaultCaseV4) = x.case_hash

function make_engineering_control_fault_case(context::ForwardChainContextV4, name,
        limits; delay_ms=0.0, dropout_probability=0.0, recovery_timeout_ms=1.0,
        fault_mode=:none)
    validate_forward_chain_context(context)
    n = strip(String(name)); isempty(n) && throw(ArgumentError("case name required"))
    is_canonical_value(limits) || throw(ArgumentError("limits must be canonical"))
    all(isfinite, (delay_ms, dropout_probability, recovery_timeout_ms)) &&
        delay_ms >= 0 && 0 <= dropout_probability <= 1 && recovery_timeout_ms > 0 ||
        throw(ArgumentError("invalid finite fault timing"))
    fault_mode isa Symbol || throw(ArgumentError("typed fault mode required"))
    body=(context_hash=context.context_hash, scenario_hash=canonical_hash(context.scenario),
        name=n, limits=limits, delay_ms=Float64(delay_ms),
        dropout_probability=Float64(dropout_probability),
        recovery_timeout_ms=Float64(recovery_timeout_ms), fault_mode=fault_mode)
    EngineeringControlFaultCaseV4(_ECFE_TOKEN, context.context_hash,
        canonical_hash(context.scenario), n, limits, Float64(delay_ms),
        Float64(dropout_probability), Float64(recovery_timeout_ms), fault_mode,
        canonical_hash(body))
end

struct EngineeringControlFaultObligationV4
    name::String
    domain::Symbol
    evidence_class::Symbol
    site::EngineeringControlFaultSiteV4
    capability::CapabilitySignatureV4
    recovery_required::Bool
    obligation_hash::Digest256
    function EngineeringControlFaultObligationV4(::_EngineeringControlFaultExecutionToken, a...)
        new(a...)
    end
end
EngineeringControlFaultObligationV4(a...) = throw(ArgumentError("sealed obligation"))
semantic_view(x::EngineeringControlFaultObligationV4) = (name=x.name, domain=x.domain,
    evidence_class=x.evidence_class, site=x.site, capability=x.capability,
    recovery_required=x.recovery_required)
canonical_hash(x::EngineeringControlFaultObligationV4) = x.obligation_hash

function make_engineering_control_fault_obligation(context::ForwardChainContextV4,
        name, domain::Symbol, evidence_class::Symbol, role::Symbol; recovery_required=false)
    validate_forward_chain_context(context)
    domain in (:engineering, :control, :fault) || throw(ArgumentError("invalid domain"))
    evidence_class in (:engineering, :manufactured_control, :fault_recovery) ||
        throw(ArgumentError("invalid evidence class"))
    domain === :fault && !recovery_required && throw(ArgumentError("fault recovery is required"))
    site = _ecfe_site(context, role)
    candidates = Tuple(o for o in context.obligations if o isa CapabilitySignatureV4)
    isempty(candidates) && throw(ArgumentError("context has no typed capability"))
    capability = first(candidates)
    n=strip(String(name)); isempty(n) && throw(ArgumentError("obligation name required"))
    body=(name=n,domain=domain,evidence_class=evidence_class,site=site,
        capability=capability,recovery_required=Bool(recovery_required))
    EngineeringControlFaultObligationV4(_ECFE_TOKEN,n,domain,evidence_class,site,
        capability,Bool(recovery_required),canonical_hash(body))
end

struct EngineeringControlFaultExecutionRequestV4
    context::ForwardChainContextV4
    fault_case::EngineeringControlFaultCaseV4
    obligations::Tuple
    providers::Tuple{Vararg{ProviderManifestV4}}
    status::Symbol
    gaps::Tuple{Vararg{String}}
    request_hash::Digest256
    function EngineeringControlFaultExecutionRequestV4(::_EngineeringControlFaultExecutionToken, a...)
        new(a...)
    end
end
EngineeringControlFaultExecutionRequestV4(a...) = throw(ArgumentError("sealed execution request"))
semantic_view(x::EngineeringControlFaultExecutionRequestV4) = (context_hash=x.context.context_hash,
    fault_case_hash=x.fault_case.case_hash,
    obligation_hashes=Tuple(canonical_hash(o) for o in x.obligations),
    provider_hashes=Tuple(canonical_hash(p) for p in x.providers), status=x.status, gaps=x.gaps)
canonical_hash(x::EngineeringControlFaultExecutionRequestV4) = x.request_hash

function make_engineering_control_fault_execution_request(context::ForwardChainContextV4,
        fault_case::EngineeringControlFaultCaseV4, obligations, providers)
    validate_forward_chain_context(context)
    fault_case.context_hash == context.context_hash &&
        fault_case.scenario_hash == canonical_hash(context.scenario) ||
        throw(ArgumentError("fault case context/scenario mismatch"))
    os=Tuple(obligations); ps=Tuple(providers)
    all(o -> o isa EngineeringControlFaultObligationV4, os) || throw(ArgumentError("typed obligations required"))
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("typed providers required"))
    length(unique(o.name for o in os)) == length(os) || throw(ArgumentError("obligation names must be unique"))
    gaps=String[]
    for o in os
        hits=Tuple(p for p in ps if p.capability == o.capability &&
            p.independence_group != "manufactured-control")
        length(hits)==1 || push!(gaps, length(hits)==0 ? "missing provider: $(o.name)" : "ambiguous provider: $(o.name)")
    end
    status=isempty(gaps) ? :ready_for_execution : :recoverable_gap
    body=(context_hash=context.context_hash,fault_case_hash=fault_case.case_hash,
        obligation_hashes=Tuple(canonical_hash(o) for o in os),provider_hashes=Tuple(canonical_hash(p) for p in ps),status=status,gaps=Tuple(gaps))
    EngineeringControlFaultExecutionRequestV4(_ECFE_TOKEN,context,fault_case,os,ps,status,Tuple(gaps),canonical_hash(body))
end

function validate_engineering_control_fault_execution_request(request,
        context::ForwardChainContextV4, fault_case::EngineeringControlFaultCaseV4,
        obligations, providers)
    validate_forward_chain_context(context)
    expected=try make_engineering_control_fault_execution_request(context,fault_case,obligations,providers) catch; return false end
    request isa EngineeringControlFaultExecutionRequestV4 && request.context === context &&
        request.fault_case === fault_case && request.request_hash === expected.request_hash
end
validate_engineering_control_fault_execution_request(::EngineeringControlFaultExecutionRequestV4)=false
