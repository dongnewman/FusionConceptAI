"""Declaration-only engineering/control/fault obligations; no providers or authority."""
struct _ECODToken end
const _ECOD_TOKEN = _ECODToken()

struct EngineeringControlFaultTimingV4
    delay_ms::Float64
    dropout_probability::Float64
    recovery_timeout_ms::Float64
    timing_hash::Digest256
    function EngineeringControlFaultTimingV4(::_ECODToken, a...); new(a...); end
end
EngineeringControlFaultTimingV4(a...) = throw(ArgumentError("sealed fault timing"))
semantic_view(x::EngineeringControlFaultTimingV4) = (delay_ms=x.delay_ms,
    dropout_probability=x.dropout_probability, recovery_timeout_ms=x.recovery_timeout_ms)
canonical_hash(x::EngineeringControlFaultTimingV4) = x.timing_hash
function make_engineering_control_fault_timing(; delay_ms=0.0,
        dropout_probability=0.0, recovery_timeout_ms=1.0)
    all(isfinite, (delay_ms, dropout_probability, recovery_timeout_ms)) &&
        delay_ms >= 0 && 0 <= dropout_probability <= 1 && recovery_timeout_ms > 0 ||
        throw(ArgumentError("fault timing must be finite and bounded"))
    body=(delay_ms=Float64(delay_ms), dropout_probability=Float64(dropout_probability),
        recovery_timeout_ms=Float64(recovery_timeout_ms))
    EngineeringControlFaultTimingV4(_ECOD_TOKEN, body..., canonical_hash(body))
end

struct EngineeringControlFaultSiteV4
    role::Symbol
    graph_binding_hash::Digest256
    edge_identity_hashes::Tuple{Vararg{Digest256}}
    ast_root_hashes::Tuple{Vararg{Digest256}}
    input_node_hashes::Tuple{Vararg{Digest256}}
    output_node_hashes::Tuple{Vararg{Digest256}}
    site_hash::Digest256
    function EngineeringControlFaultSiteV4(::_ECODToken, a...); new(a...); end
end
EngineeringControlFaultSiteV4(a...) = throw(ArgumentError("sealed control site"))
semantic_view(x::EngineeringControlFaultSiteV4) = (role=x.role,
    graph_binding_hash=x.graph_binding_hash, edge_identity_hashes=x.edge_identity_hashes,
    ast_root_hashes=x.ast_root_hashes, input_node_hashes=x.input_node_hashes,
    output_node_hashes=x.output_node_hashes)
canonical_hash(x::EngineeringControlFaultSiteV4) = x.site_hash

struct EngineeringControlFaultObligationV4
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    site::EngineeringControlFaultSiteV4
    timing::EngineeringControlFaultTimingV4
    domain::Symbol
    status::Symbol
    gaps::Tuple{Vararg{String}}
    obligation_hash::Digest256
    function EngineeringControlFaultObligationV4(::_ECODToken, a...); new(a...); end
end
EngineeringControlFaultObligationV4(a...) = throw(ArgumentError("sealed obligation"))
semantic_view(x::EngineeringControlFaultObligationV4) = (context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    mission_hash=x.mission_hash, bounds_hash=x.bounds_hash, site=x.site,
    timing=x.timing, domain=x.domain, status=x.status, gaps=x.gaps)
canonical_hash(x::EngineeringControlFaultObligationV4) = x.obligation_hash

function _ecod_site(context, role)
    role in (:realization, :control) || throw(ArgumentError("G3 role required"))
    binding = forward_graph_binding(context, role)
    edges = binding.graph.hyperedges
    actual = Tuple((i,e) for (i,e) in enumerate(edges) if e isa AtomicMIMOHyperedgeV1)
    isempty(actual) && return nothing
    edge_hashes=Tuple(binding.hyperedge_identity_hashes[i] for (i,e) in actual)
    roots=Tuple(e.program_hash for (i,e) in actual)
    inputs=Tuple(canonical_hash(x) for (i,e) in actual for x in e.input_bindings)
    outputs=Tuple(canonical_hash(x) for (i,e) in actual for x in e.output_bindings)
    body=(role=role, graph_binding_hash=canonical_hash(binding),
        edge_identity_hashes=edge_hashes, ast_root_hashes=roots,
        input_node_hashes=inputs, output_node_hashes=outputs)
    EngineeringControlFaultSiteV4(_ECOD_TOKEN, role, canonical_hash(binding),
        edge_hashes, roots, inputs, outputs, canonical_hash(body))
end

function declare_engineering_control_fault_obligation(context::ForwardChainContextV4,
        timing::EngineeringControlFaultTimingV4; role::Symbol=:control,
        domain::Symbol=:fault)
    validate_forward_chain_context(context)
    domain in (:engineering, :control, :fault) || throw(ArgumentError("invalid domain"))
    site=_ecod_site(context, role)
    gaps=String[]
    site === nothing && push!(gaps, "no AtomicMIMO execution edge in context-owned G3 graph")
    domain === :fault && timing.recovery_timeout_ms <= 0 && push!(gaps, "recovery timeout missing")
    site === nothing && (site=EngineeringControlFaultSiteV4(_ECOD_TOKEN, role,
        digest256_text("missing"), (), (), (), (), digest256_text("missing")))
    body=(context_hash=context.context_hash,subject_hash=context.subject.physical_subject_hash,
        scenario_hash=canonical_hash(context.scenario),mission_hash=_runtime_decl_hash(context.mission_payload),
        bounds_hash=_runtime_decl_hash(context.bounds_payload),site=site,timing=timing,
        domain=domain,status=isempty(gaps) ? :declared : :recoverable_gap,gaps=Tuple(gaps))
    EngineeringControlFaultObligationV4(_ECOD_TOKEN, context.context_hash,
        context.subject.physical_subject_hash, canonical_hash(context.scenario),
        _runtime_decl_hash(context.mission_payload), _runtime_decl_hash(context.bounds_payload),
        site, timing, domain, body.status, body.gaps, canonical_hash(body))
end

function validate_engineering_control_fault_obligation(obligation::EngineeringControlFaultObligationV4,
        context::ForwardChainContextV4, timing::EngineeringControlFaultTimingV4)
    validate_forward_chain_context(context)
    expected=try declare_engineering_control_fault_obligation(context,timing; role=obligation.site.role,domain=obligation.domain) catch; return false end
    obligation.context_hash==context.context_hash && obligation.timing===timing &&
        obligation.obligation_hash==expected.obligation_hash
end
validate_engineering_control_fault_obligation(::EngineeringControlFaultObligationV4)=false
