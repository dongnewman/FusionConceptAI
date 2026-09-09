"""Candidate-bound multi-region ownership and conservative execution contract.

This isolated module consumes a validated `ForwardChainContextV4`.  It emits
content-addressed manufactured-control receipts only; it does not emit runtime
evidence, promotion, terminal unsupported, or whole-device authority.
"""

using LinearAlgebra
using SHA
import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _CMR_REVISION = "conservative-multiregion-execution-v1"
const _CMR_SCHEMA = "fusionconceptai:runtime-v4-conservative-multiregion"
const _CMR_SOURCE_HASH = Digest256(bytes2hex(SHA.sha256(read(@__FILE__))))
const _CMR_PROJECT_HASH = Digest256(bytes2hex(SHA.sha256(read(joinpath(@__DIR__, "..", "..", "Project.toml")))))
const _CMR_DEPENDENCY_LOCK_HASH = Digest256(bytes2hex(SHA.sha256(read(joinpath(@__DIR__, "..", "..", "Manifest.toml")))))
const _CMR_CODE_HASH = canonical_hash((source_hash=_CMR_SOURCE_HASH,
    project_hash=_CMR_PROJECT_HASH, dependency_lock_hash=_CMR_DEPENDENCY_LOCK_HASH,
    julia_version=string(VERSION), algorithm="dense-linear-newton-global-residual-v1"))

struct _ConservativeMultiRegionToken end
const _CMR_TOKEN = _ConservativeMultiRegionToken()

_cmr_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    s = strip(String(x))
    !isempty(s) && isvalid(s) || throw(ArgumentError("$field cannot be empty"))
    lowercase(s) in ("*", "any", "all", "wildcard") && throw(ArgumentError("$field cannot be wildcard"))
    s
end

_cmr_finite(x, field) = begin
    y = try Float64(x) catch; throw(ArgumentError("$field must be numeric")) end
    isfinite(y) || throw(ArgumentError("$field must be finite"))
    y
end

"""Caller declaration; the resulting region reference is derived from context."""
struct ConservativeRegionSpecV4
    region_id::String
    node_ids::Tuple{Vararg{String}}
    function ConservativeRegionSpecV4(region_id, node_ids)
        id = _cmr_text(region_id, "region id")
        nodes = Tuple(_cmr_text(x, "region node id") for x in node_ids)
        isempty(nodes) && throw(ArgumentError("region cannot be empty"))
        length(unique(nodes)) == length(nodes) || throw(ArgumentError("region node IDs must be unique"))
        new(id, nodes)
    end
end
semantic_view(x::ConservativeRegionSpecV4) = (region_id=x.region_id, node_ids=x.node_ids)

"""Caller declaration selecting one exact typed interface flux pair."""
struct ConservativeInterfaceSpecV4
    interface_id::String
    edge_id::String
    minus_region::String
    plus_region::String
    ledger_identity::ConservationLedgerIdentityV1
    function ConservativeInterfaceSpecV4(interface_id, edge_id, minus_region,
            plus_region, ledger_identity::ConservationLedgerIdentityV1)
        iid = _cmr_text(interface_id, "interface id")
        eid = _cmr_text(edge_id, "interface edge id")
        minus = _cmr_text(minus_region, "minus region")
        plus = _cmr_text(plus_region, "plus region")
        minus != plus || throw(ArgumentError("interface regions must be distinct"))
        new(iid, eid, minus, plus, ledger_identity)
    end
end
semantic_view(x::ConservativeInterfaceSpecV4) = (interface_id=x.interface_id,
    edge_id=x.edge_id, minus_region=x.minus_region, plus_region=x.plus_region,
    ledger_identity=x.ledger_identity)

"""Sealed typed node reference into the context-owned mechanism graph."""
struct ConservativeTypedNodeRefV4
    graph_binding_hash::Digest256
    node_position::Int
    node_id::String
    node_kind::Symbol
    physical_type::PhysicalType
    node_identity_hash::Digest256
    ref_hash::Digest256
    function ConservativeTypedNodeRefV4(token::_ConservativeMultiRegionToken,
            graph_binding_hash::Digest256, node_position::Int, node_id::String,
            node_kind::Symbol, physical_type::PhysicalType,
            node_identity_hash::Digest256, ref_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(graph_binding_hash, node_position, node_id, node_kind, physical_type,
            node_identity_hash, ref_hash)
    end
end
semantic_view(x::ConservativeTypedNodeRefV4) = (graph_binding_hash=x.graph_binding_hash,
    node_position=x.node_position, node_id=x.node_id, node_kind=x.node_kind,
    physical_type=x.physical_type, node_identity_hash=x.node_identity_hash,
    ref_hash=x.ref_hash)

function _cmr_node_ref(graph_binding::ForwardGraphBindingV4, position::Int)
    1 <= position <= length(graph_binding.graph.nodes) || throw(ArgumentError("node position outside graph"))
    node = graph_binding.graph.nodes[position]
    identity = graph_binding.node_identity_hashes[position]
    body = (revision=_CMR_REVISION, graph_binding_hash=canonical_hash(graph_binding),
        node_position=position, node_id=node.node_id, node_kind=node.node_kind,
        physical_type=node.physical_type, node_identity_hash=identity)
    ConservativeTypedNodeRefV4(_CMR_TOKEN, canonical_hash(graph_binding), position,
        node.node_id, node.node_kind, node.physical_type, identity, canonical_hash(body))
end

function _cmr_node_body(x::ConservativeTypedNodeRefV4)
    (revision=_CMR_REVISION, graph_binding_hash=x.graph_binding_hash,
     node_position=x.node_position, node_id=x.node_id, node_kind=x.node_kind,
     physical_type=x.physical_type, node_identity_hash=x.node_identity_hash)
end

canonical_hash(x::ConservativeTypedNodeRefV4) = begin
    h = canonical_hash(_cmr_node_body(x))
    h == x.ref_hash || throw(ArgumentError("typed node ref hash mismatch"))
    h
end

"""Sealed region containing nonempty, disjoint typed mechanism-graph nodes."""
struct ConservativeRegionRefV4
    region_id::String
    nodes::Tuple{Vararg{ConservativeTypedNodeRefV4}}
    unit::UnitSignature
    ref_hash::Digest256
    function ConservativeRegionRefV4(token::_ConservativeMultiRegionToken,
            region_id::String, nodes::Tuple{Vararg{ConservativeTypedNodeRefV4}},
            unit::UnitSignature, ref_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(region_id, nodes, unit, ref_hash)
    end
end
semantic_view(x::ConservativeRegionRefV4) = (region_id=x.region_id, nodes=x.nodes,
    unit=x.unit, ref_hash=x.ref_hash)

function _cmr_region_body(x::ConservativeRegionRefV4)
    (revision=_CMR_REVISION, region_id=x.region_id,
     node_ref_hashes=Tuple(canonical_hash(n) for n in x.nodes), unit=x.unit)
end
canonical_hash(x::ConservativeRegionRefV4) = begin
    !isempty(x.nodes) || throw(ArgumentError("region ref cannot be empty"))
    h = canonical_hash(_cmr_region_body(x))
    h == x.ref_hash || throw(ArgumentError("region ref hash mismatch"))
    h
end

"""Sealed reference to a typed AtomicMIMOHyperedgeV1."""
struct ConservativeTypedEdgeRefV4
    graph_binding_hash::Digest256
    edge_position::Int
    edge_id::String
    edge_role::HyperedgeRoleV1
    edge_identity_hash::Digest256
    ref_hash::Digest256
    function ConservativeTypedEdgeRefV4(token::_ConservativeMultiRegionToken,
            graph_binding_hash::Digest256, edge_position::Int, edge_id::String,
            edge_role::HyperedgeRoleV1, edge_identity_hash::Digest256,
            ref_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(graph_binding_hash, edge_position, edge_id, edge_role,
            edge_identity_hash, ref_hash)
    end
end
semantic_view(x::ConservativeTypedEdgeRefV4) = (graph_binding_hash=x.graph_binding_hash,
    edge_position=x.edge_position, edge_id=x.edge_id, edge_role=x.edge_role,
    edge_identity_hash=x.edge_identity_hash, ref_hash=x.ref_hash)

function _cmr_edge_ref(graph_binding::ForwardGraphBindingV4, position::Int)
    1 <= position <= length(graph_binding.graph.hyperedges) || throw(ArgumentError("edge position outside graph"))
    edge = graph_binding.graph.hyperedges[position]
    edge isa AtomicMIMOHyperedgeV1 || throw(ArgumentError("multi-region execution requires AtomicMIMOHyperedgeV1"))
    identity = graph_binding.hyperedge_identity_hashes[position]
    body = (revision=_CMR_REVISION, graph_binding_hash=canonical_hash(graph_binding),
        edge_position=position, edge_id=edge.edge_id, edge_role=edge.role,
        edge_identity_hash=identity)
    ConservativeTypedEdgeRefV4(_CMR_TOKEN, canonical_hash(graph_binding), position,
        edge.edge_id, edge.role, identity, canonical_hash(body))
end

function _cmr_edge_body(x::ConservativeTypedEdgeRefV4)
    (revision=_CMR_REVISION, graph_binding_hash=x.graph_binding_hash,
     edge_position=x.edge_position, edge_id=x.edge_id, edge_role=x.edge_role,
     edge_identity_hash=x.edge_identity_hash)
end
canonical_hash(x::ConservativeTypedEdgeRefV4) = begin
    h = canonical_hash(_cmr_edge_body(x))
    h == x.ref_hash || throw(ArgumentError("typed edge ref hash mismatch"))
    h
end

"""Unique ownership of one source/sink/boundary ledger occurrence."""
struct ConservativeExternalOwnerV4
    region_ref_hash::Digest256
    edge_ref::ConservativeTypedEdgeRefV4
    port_side::Symbol
    port_position::Int
    node_ref::ConservativeTypedNodeRefV4
    ledger_identity::ConservationLedgerIdentityV1
    coefficient::Rational{Int64}
    owner_hash::Digest256
    function ConservativeExternalOwnerV4(token::_ConservativeMultiRegionToken,
            region_ref_hash::Digest256, edge_ref::ConservativeTypedEdgeRefV4,
            port_side::Symbol, port_position::Int,
            node_ref::ConservativeTypedNodeRefV4,
            ledger_identity::ConservationLedgerIdentityV1,
            coefficient::Rational{Int64}, owner_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(region_ref_hash, edge_ref, port_side, port_position, node_ref,
            ledger_identity, coefficient, owner_hash)
    end
end
semantic_view(x::ConservativeExternalOwnerV4) = (region_ref_hash=x.region_ref_hash,
    edge_ref=x.edge_ref, port_side=x.port_side, port_position=x.port_position,
    node_ref=x.node_ref, ledger_identity=x.ledger_identity,
    coefficient=x.coefficient, owner_hash=x.owner_hash)

function _cmr_owner_body(x::ConservativeExternalOwnerV4)
    (revision=_CMR_REVISION, region_ref_hash=x.region_ref_hash,
     edge_ref_hash=canonical_hash(x.edge_ref), port_side=x.port_side,
     port_position=x.port_position, node_ref_hash=canonical_hash(x.node_ref),
     ledger_identity=x.ledger_identity, coefficient=x.coefficient)
end
canonical_hash(x::ConservativeExternalOwnerV4) = begin
    x.edge_ref.edge_role in (source, sink, boundary) || throw(ArgumentError("external owner edge role mismatch"))
    h = canonical_hash(_cmr_owner_body(x))
    h == x.owner_hash || throw(ArgumentError("external owner hash mismatch"))
    h
end

"""Exact oriented interface pair and its two owning regions."""
struct ConservativeInterfaceRefV4
    interface_id::String
    edge_ref::ConservativeTypedEdgeRefV4
    pair_position::Int
    pair_hash::Digest256
    minus_region_ref_hash::Digest256
    plus_region_ref_hash::Digest256
    minus_node_ref::ConservativeTypedNodeRefV4
    plus_node_ref::ConservativeTypedNodeRefV4
    ledger_identity::ConservationLedgerIdentityV1
    minus_coefficient::Rational{Int64}
    plus_coefficient::Rational{Int64}
    ref_hash::Digest256
    function ConservativeInterfaceRefV4(token::_ConservativeMultiRegionToken,
            interface_id::String, edge_ref::ConservativeTypedEdgeRefV4,
            pair_position::Int, pair_hash::Digest256,
            minus_region_ref_hash::Digest256, plus_region_ref_hash::Digest256,
            minus_node_ref::ConservativeTypedNodeRefV4,
            plus_node_ref::ConservativeTypedNodeRefV4,
            ledger_identity::ConservationLedgerIdentityV1,
            minus_coefficient::Rational{Int64}, plus_coefficient::Rational{Int64},
            ref_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(interface_id, edge_ref, pair_position, pair_hash,
            minus_region_ref_hash, plus_region_ref_hash, minus_node_ref,
            plus_node_ref, ledger_identity, minus_coefficient,
            plus_coefficient, ref_hash)
    end
end
semantic_view(x::ConservativeInterfaceRefV4) = (interface_id=x.interface_id,
    edge_ref=x.edge_ref, pair_position=x.pair_position, pair_hash=x.pair_hash,
    minus_region_ref_hash=x.minus_region_ref_hash,
    plus_region_ref_hash=x.plus_region_ref_hash,
    minus_node_ref=x.minus_node_ref, plus_node_ref=x.plus_node_ref,
    ledger_identity=x.ledger_identity, minus_coefficient=x.minus_coefficient,
    plus_coefficient=x.plus_coefficient, ref_hash=x.ref_hash)

function _cmr_interface_body(x::ConservativeInterfaceRefV4)
    (revision=_CMR_REVISION, interface_id=x.interface_id,
     edge_ref_hash=canonical_hash(x.edge_ref), pair_position=x.pair_position,
     pair_hash=x.pair_hash, minus_region_ref_hash=x.minus_region_ref_hash,
     plus_region_ref_hash=x.plus_region_ref_hash,
     minus_node_ref_hash=canonical_hash(x.minus_node_ref),
     plus_node_ref_hash=canonical_hash(x.plus_node_ref),
     ledger_identity=x.ledger_identity, minus_coefficient=x.minus_coefficient,
     plus_coefficient=x.plus_coefficient)
end
canonical_hash(x::ConservativeInterfaceRefV4) = begin
    x.edge_ref.edge_role === interface || throw(ArgumentError("interface ref edge role mismatch"))
    x.minus_coefficient < 0 && x.plus_coefficient > 0 &&
        x.minus_coefficient == -x.plus_coefficient ||
        throw(ArgumentError("interface coefficients are not exact opposites"))
    x.minus_region_ref_hash != x.plus_region_ref_hash || throw(ArgumentError("interface regions must differ"))
    x.minus_node_ref.physical_type.units == x.ledger_identity.unit &&
        x.plus_node_ref.physical_type.units == x.ledger_identity.unit ||
        throw(ArgumentError("interface endpoint unit mismatch"))
    h = canonical_hash(_cmr_interface_body(x))
    h == x.ref_hash || throw(ArgumentError("interface ref hash mismatch"))
    h
end

struct ConservativeMultiRegionContractV4
    context_hash::Digest256
    region_specs::Tuple{Vararg{ConservativeRegionSpecV4}}
    interface_specs::Tuple{Vararg{ConservativeInterfaceSpecV4}}
    regions::Tuple{Vararg{ConservativeRegionRefV4}}
    interfaces::Tuple{Vararg{ConservativeInterfaceRefV4}}
    external_owners::Tuple{Vararg{ConservativeExternalOwnerV4}}
    capability::CapabilitySignatureV4
    contract_hash::Digest256
    function ConservativeMultiRegionContractV4(token::_ConservativeMultiRegionToken,
            context_hash::Digest256,
            region_specs::Tuple{Vararg{ConservativeRegionSpecV4}},
            interface_specs::Tuple{Vararg{ConservativeInterfaceSpecV4}},
            regions::Tuple{Vararg{ConservativeRegionRefV4}},
            interfaces::Tuple{Vararg{ConservativeInterfaceRefV4}},
            external_owners::Tuple{Vararg{ConservativeExternalOwnerV4}},
            capability::CapabilitySignatureV4, contract_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, region_specs, interface_specs, regions, interfaces,
            external_owners, capability, contract_hash)
    end
end

semantic_view(x::ConservativeMultiRegionContractV4) = (context_hash=x.context_hash,
    region_specs=x.region_specs, interface_specs=x.interface_specs,
    regions=x.regions, interfaces=x.interfaces,
    external_owners=x.external_owners, capability=x.capability,
    contract_hash=x.contract_hash)

function _cmr_contract_body(context_hash, region_specs, interface_specs, regions,
        interfaces, external_owners, capability)
    (revision=_CMR_REVISION, context_hash=context_hash,
     region_specs=region_specs, interface_specs=interface_specs,
     region_ref_hashes=Tuple(canonical_hash(r) for r in regions),
     interface_ref_hashes=Tuple(canonical_hash(i) for i in interfaces),
     external_owner_hashes=Tuple(canonical_hash(o) for o in external_owners),
     capability=capability)
end

canonical_hash(x::ConservativeMultiRegionContractV4) = begin
    h = canonical_hash(_cmr_contract_body(x.context_hash, x.region_specs,
        x.interface_specs, x.regions, x.interfaces, x.external_owners,
        x.capability))
    h == x.contract_hash || throw(ArgumentError("multi-region contract hash mismatch"))
    h
end

struct ConservativeMultiRegionContractResolutionV4
    context_hash::Digest256
    status::Symbol
    contract::Union{Nothing,ConservativeMultiRegionContractV4}
    recoverable_gaps::Tuple{Vararg{String}}
    resolution_hash::Digest256
    function ConservativeMultiRegionContractResolutionV4(token::_ConservativeMultiRegionToken,
            context_hash::Digest256, status::Symbol,
            contract::Union{Nothing,ConservativeMultiRegionContractV4},
            gaps::Tuple{Vararg{String}}, resolution_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, status, contract, gaps, resolution_hash)
    end
end
semantic_view(x::ConservativeMultiRegionContractResolutionV4) = (
    context_hash=x.context_hash, status=x.status,
    contract_hash=x.contract === nothing ? nothing : canonical_hash(x.contract),
    recoverable_gaps=x.recoverable_gaps, resolution_hash=x.resolution_hash)

function _cmr_contract_resolution(context_hash, contract, gaps)
    gs = Tuple(String(g) for g in gaps)
    status = contract === nothing ? :recoverable_gap : :ready
    status === :ready && !isempty(gs) && throw(ArgumentError("ready resolution cannot contain gaps"))
    status === :recoverable_gap && isempty(gs) && throw(ArgumentError("gap resolution requires a reason"))
    body = (revision=_CMR_REVISION, kind=:contract_resolution,
        context_hash=context_hash, status=status,
        contract_hash=contract === nothing ? nothing : canonical_hash(contract),
        recoverable_gaps=gs)
    ConservativeMultiRegionContractResolutionV4(_CMR_TOKEN, context_hash, status,
        contract, gs, canonical_hash(body))
end

function canonical_hash(x::ConservativeMultiRegionContractResolutionV4)
    x.status in (:ready, :recoverable_gap) || throw(ArgumentError("invalid contract resolution status"))
    (x.status === :ready) == (x.contract !== nothing) || throw(ArgumentError("contract resolution payload mismatch"))
    body = (revision=_CMR_REVISION, kind=:contract_resolution,
        context_hash=x.context_hash, status=x.status,
        contract_hash=x.contract === nothing ? nothing : canonical_hash(x.contract),
        recoverable_gaps=x.recoverable_gaps)
    h = canonical_hash(body)
    h == x.resolution_hash || throw(ArgumentError("contract resolution hash mismatch"))
    h
end

function _cmr_graph_node(edge::AtomicMIMOHyperedgeV1, port_side::Symbol, port::Int)
    bindings = port_side === :input ? edge.input_bindings :
        port_side === :output ? edge.output_bindings :
        throw(ArgumentError("invalid edge port side"))
    hits = Tuple(b.graph_node_index for b in bindings if b.program_position == port)
    length(hits) == 1 || throw(ArgumentError("edge port binding missing or ambiguous"))
    only(hits)
end

function _cmr_find_region(regions, node_hash)
    Tuple(r for r in regions if any(n -> canonical_hash(n) == node_hash, r.nodes))
end

function _cmr_build_contract(context::ForwardChainContextV4, region_specs, interface_specs)
    validate_forward_chain_context(context)
    rspecs = Tuple(region_specs)
    ispecs = Tuple(interface_specs)
    all(x -> x isa ConservativeRegionSpecV4, rspecs) || throw(ArgumentError("regions must be ConservativeRegionSpecV4"))
    all(x -> x isa ConservativeInterfaceSpecV4, ispecs) || throw(ArgumentError("interfaces must be ConservativeInterfaceSpecV4"))
    length(rspecs) >= 2 || throw(ArgumentError("at least two nonempty regions are required"))
    !isempty(ispecs) || throw(ArgumentError("at least one interface channel is required"))
    length(unique(r.region_id for r in rspecs)) == length(rspecs) || throw(ArgumentError("duplicate region id"))
    length(unique(i.interface_id for i in ispecs)) == length(ispecs) || throw(ArgumentError("duplicate interface id"))
    graph_binding = forward_graph_binding(context, :mechanism)
    graph = graph_binding.graph
    node_index = Dict(n.node_id => i for (i, n) in enumerate(graph.nodes))
    regions = ConservativeRegionRefV4[]
    owned_node_hashes = Set{Digest256}()
    for spec in rspecs
        all(haskey(node_index, id) for id in spec.node_ids) || throw(ArgumentError("region references a missing mechanism node"))
        refs = Tuple(_cmr_node_ref(graph_binding, node_index[id]) for id in spec.node_ids)
        hashes = Tuple(canonical_hash(n) for n in refs)
        identity_hashes = Set(n.node_identity_hash for n in refs)
        isempty(intersect(owned_node_hashes, identity_hashes)) || throw(ArgumentError("mechanism node has multiple region owners"))
        union!(owned_node_hashes, identity_hashes)
        units = unique(n.physical_type.units for n in refs)
        length(units) == 1 || throw(ArgumentError("region nodes must share one balance unit"))
        body = (revision=_CMR_REVISION, region_id=spec.region_id,
            node_ref_hashes=hashes, unit=first(units))
        push!(regions, ConservativeRegionRefV4(_CMR_TOKEN, spec.region_id, refs,
            first(units), canonical_hash(body)))
    end
    Set(n.node_identity_hash for r in regions for n in r.nodes) ==
        Set(graph_binding.node_identity_hashes) ||
        throw(ArgumentError("regions do not exactly cover mechanism graph nodes"))
    region_by_id = Dict(r.region_id => r for r in regions)

    edge_index = Dict{String,Int}()
    for (i, edge) in enumerate(graph.hyperedges)
        edge isa AtomicMIMOHyperedgeV1 || throw(ArgumentError("mechanism graph contains a non-AtomicMIMO edge"))
        haskey(edge_index, edge.edge_id) && throw(ArgumentError("mechanism edge id is ambiguous"))
        edge_index[edge.edge_id] = i
    end

    interfaces = ConservativeInterfaceRefV4[]
    selected_pairs = Set{Tuple{String,Int}}()
    selected_region_pairs = Set{Tuple{String,String}}()
    for spec in ispecs
        haskey(edge_index, spec.edge_id) || throw(ArgumentError("missing interface capability edge: $(spec.edge_id)"))
        haskey(region_by_id, spec.minus_region) && haskey(region_by_id, spec.plus_region) ||
            throw(ArgumentError("interface references a missing region"))
        edge_position = edge_index[spec.edge_id]
        edge = graph.hyperedges[edge_position]::AtomicMIMOHyperedgeV1
        edge.role === interface || throw(ArgumentError("selected interface edge does not have interface role"))
        ledger_hash = canonical_hash(spec.ledger_identity)
        matches = Tuple((i, p) for (i, p) in enumerate(edge.interface_flux_pairs)
            if canonical_hash(p.minus.account_ref.ledger_identity) == ledger_hash &&
               canonical_hash(p.plus.account_ref.ledger_identity) == ledger_hash)
        length(matches) == 1 || throw(ArgumentError("interface capability pair is missing or ambiguous"))
        pair_position, pair = only(matches)
        pair_key = (edge.edge_id, pair_position)
        pair_key in selected_pairs && throw(ArgumentError("interface flux pair has multiple declarations"))
        push!(selected_pairs, pair_key)
        unordered_regions = Tuple(sort([spec.minus_region, spec.plus_region]))
        unordered_regions in selected_region_pairs && throw(ArgumentError("narrow execution permits one channel per region pair"))
        push!(selected_region_pairs, unordered_regions)
        minus_position = _cmr_graph_node(edge, :output, pair.minus.account_ref.port_index)
        plus_position = _cmr_graph_node(edge, :output, pair.plus.account_ref.port_index)
        minus_node = _cmr_node_ref(graph_binding, minus_position)
        plus_node = _cmr_node_ref(graph_binding, plus_position)
        minus_region = region_by_id[spec.minus_region]
        plus_region = region_by_id[spec.plus_region]
        any(n -> canonical_hash(n) == canonical_hash(minus_node), minus_region.nodes) ||
            throw(ArgumentError("interface minus endpoint is not owned by minus region"))
        any(n -> canonical_hash(n) == canonical_hash(plus_node), plus_region.nodes) ||
            throw(ArgumentError("interface plus endpoint is not owned by plus region"))
        pair.minus.account_ref.direction === :minus && pair.plus.account_ref.direction === :plus ||
            throw(ArgumentError("interface flux orientation mismatch"))
        pair.minus.coefficient == -pair.plus.coefficient || throw(ArgumentError("interface flux pair is not conservative"))
        minus_node.physical_type.units == spec.ledger_identity.unit &&
            plus_node.physical_type.units == spec.ledger_identity.unit ||
            throw(ArgumentError("interface ledger and endpoint units differ"))
        edge_ref = _cmr_edge_ref(graph_binding, edge_position)
        pair_hash = canonical_hash(pair)
        body = (revision=_CMR_REVISION, interface_id=spec.interface_id,
            edge_ref_hash=canonical_hash(edge_ref), pair_position=pair_position,
            pair_hash=pair_hash, minus_region_ref_hash=canonical_hash(minus_region),
            plus_region_ref_hash=canonical_hash(plus_region),
            minus_node_ref_hash=canonical_hash(minus_node),
            plus_node_ref_hash=canonical_hash(plus_node),
            ledger_identity=spec.ledger_identity,
            minus_coefficient=pair.minus.coefficient,
            plus_coefficient=pair.plus.coefficient)
        push!(interfaces, ConservativeInterfaceRefV4(_CMR_TOKEN,
            spec.interface_id, edge_ref, pair_position, pair_hash,
            canonical_hash(minus_region), canonical_hash(plus_region),
            minus_node, plus_node, spec.ledger_identity,
            pair.minus.coefficient, pair.plus.coefficient, canonical_hash(body)))
    end
    expected_pairs = Set{Tuple{String,Int}}()
    for edge in graph.hyperedges
        edge isa AtomicMIMOHyperedgeV1 || continue
        if edge.role === interface
            isempty(edge.interface_flux_pairs) && throw(ArgumentError("interface edge has no channel"))
            for i in eachindex(edge.interface_flux_pairs)
                push!(expected_pairs, (edge.edge_id, i))
            end
        end
    end
    selected_pairs == expected_pairs || throw(ArgumentError("interface declarations do not exactly cover typed flux pairs"))

    # Every region must participate in one connected interface component.
    adjacency = Dict(r.region_id => Set{String}() for r in regions)
    for spec in ispecs
        push!(adjacency[spec.minus_region], spec.plus_region)
        push!(adjacency[spec.plus_region], spec.minus_region)
    end
    reached = Set{String}([first(regions).region_id])
    frontier = [first(regions).region_id]
    while !isempty(frontier)
        current = pop!(frontier)
        for neighbor in adjacency[current]
            if !(neighbor in reached)
                push!(reached, neighbor); push!(frontier, neighbor)
            end
        end
    end
    length(reached) == length(regions) || throw(ArgumentError("regions are not connected by interface channels"))

    external = ConservativeExternalOwnerV4[]
    occurrence_keys = Set{Tuple{String,Symbol,Int,Digest256}}()
    for (edge_position, edge_any) in enumerate(graph.hyperedges)
        edge = edge_any::AtomicMIMOHyperedgeV1
        edge.role in (source, sink, boundary) || continue
        isempty(edge.account_effects) && throw(ArgumentError("source/sink/boundary edge has no owned occurrence"))
        edge_ref = _cmr_edge_ref(graph_binding, edge_position)
        for effect in edge.account_effects
            account = effect.account_ref
            key = (edge.edge_id, account.port_side, account.port_index,
                canonical_hash(account.ledger_identity))
            key in occurrence_keys && throw(ArgumentError("external occurrence is duplicated"))
            push!(occurrence_keys, key)
            node_position = _cmr_graph_node(edge, account.port_side, account.port_index)
            node_ref = _cmr_node_ref(graph_binding, node_position)
            owners = _cmr_find_region(regions, canonical_hash(node_ref))
            length(owners) == 1 || throw(ArgumentError("external occurrence does not have exactly one region owner"))
            owner = only(owners)
            owner.unit == account.ledger_identity.unit || throw(ArgumentError("external occurrence unit differs from region balance unit"))
            body = (revision=_CMR_REVISION,
                region_ref_hash=canonical_hash(owner), edge_ref_hash=canonical_hash(edge_ref),
                port_side=account.port_side, port_position=account.port_index,
                node_ref_hash=canonical_hash(node_ref), ledger_identity=account.ledger_identity,
                coefficient=effect.coefficient)
            push!(external, ConservativeExternalOwnerV4(_CMR_TOKEN,
                canonical_hash(owner), edge_ref, account.port_side,
                account.port_index, node_ref, account.ledger_identity,
                effect.coefficient, canonical_hash(body)))
        end
    end

    input_schema_hash = canonical_hash((schema=_CMR_SCHEMA, revision=_CMR_REVISION,
        context_hash=context.context_hash,
        region_ref_hashes=Tuple(canonical_hash(r) for r in regions),
        interface_ref_hashes=Tuple(canonical_hash(i) for i in interfaces),
        external_owner_hashes=Tuple(canonical_hash(o) for o in external),
        execution="one_global_non_diagonal_residual"))
    capability = CapabilitySignatureV4(_CMR_SCHEMA, _CMR_REVISION,
        :conservative_multiregion_residual_screen,
        "typed_interface_balance_newton", Tuple(r.region_id for r in regions),
        "typed_region_balance", "typed_global_residual", 0, (),
        "unique_source_sink_boundary_occurrence_ownership",
        "exact_opposite_typed_flux_pairs", "static_iteration",
        ("global_residual", "iteration_trace", "interface_conservation_defect"),
        screen_only, context.subject.bounds_hash;
        input_schema_hash=input_schema_hash, coordinate_system="lumped_regions")
    body = _cmr_contract_body(context.context_hash, rspecs, ispecs,
        Tuple(regions), Tuple(interfaces), Tuple(external), capability)
    ConservativeMultiRegionContractV4(_CMR_TOKEN, context.context_hash,
        rspecs, ispecs, Tuple(regions), Tuple(interfaces), Tuple(external),
        capability, canonical_hash(body))
end

"""Resolve missing structural capability as a recoverable gap, never terminal unsupported."""
function resolve_conservative_multiregion_contract(context::ForwardChainContextV4,
        region_specs, interface_specs)
    validate_forward_chain_context(context)
    try
        contract = _cmr_build_contract(context, region_specs, interface_specs)
        _cmr_contract_resolution(context.context_hash, contract, ())
    catch error
        error isa ArgumentError || rethrow()
        _cmr_contract_resolution(context.context_hash, nothing,
            ("structural_capability_gap:" * sprint(showerror, error),))
    end
end

function validate_conservative_multiregion_contract(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4)
    validate_forward_chain_context(context)
    context.context_hash == contract.context_hash || throw(ArgumentError("contract context mismatch"))
    expected = _cmr_build_contract(context, contract.region_specs, contract.interface_specs)
    canonical_hash(expected) == canonical_hash(contract) || throw(ArgumentError("contract reconstruction mismatch"))
    contract
end

struct ConservativeExternalValueV4
    owner_hash::Digest256
    value::Float64
    unit::UnitSignature
    value_hash::Digest256
    function ConservativeExternalValueV4(token::_ConservativeMultiRegionToken,
            owner_hash::Digest256, value::Float64, unit::UnitSignature,
            value_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(owner_hash, value, unit, value_hash)
    end
end
semantic_view(x::ConservativeExternalValueV4) = (owner_hash=x.owner_hash,
    value=x.value, unit=x.unit, value_hash=x.value_hash)
canonical_hash(x::ConservativeExternalValueV4) = begin
    isfinite(x.value) || throw(ArgumentError("external occurrence value must be finite"))
    h = canonical_hash((revision=_CMR_REVISION, owner_hash=x.owner_hash,
        value=x.value, unit=x.unit))
    h == x.value_hash || throw(ArgumentError("external occurrence value hash mismatch"))
    h
end

function make_conservative_external_value(contract::ConservativeMultiRegionContractV4,
        edge_id, port_side::Symbol, port_position::Integer; value)
    canonical_hash(contract)
    eid = _cmr_text(edge_id, "external edge id")
    port_position isa Bool && throw(ArgumentError("external port position must not be Bool"))
    position = Int(port_position)
    hits = Tuple(o for o in contract.external_owners if o.edge_ref.edge_id == eid &&
        o.port_side === port_side && o.port_position == position)
    length(hits) == 1 || throw(ArgumentError("external occurrence is missing or ambiguous"))
    owner = only(hits)
    v = _cmr_finite(value, "external occurrence value")
    body = (revision=_CMR_REVISION, owner_hash=canonical_hash(owner), value=v,
        unit=owner.ledger_identity.unit)
    ConservativeExternalValueV4(_CMR_TOKEN, canonical_hash(owner), v,
        owner.ledger_identity.unit, canonical_hash(body))
end

struct ConservativeRegionBalanceV4
    region_ref_hash::Digest256
    diagonal::Float64
    right_hand_side::Float64
    initial_value::Float64
    unit::UnitSignature
    external_values::Tuple{Vararg{ConservativeExternalValueV4}}
    balance_hash::Digest256
    function ConservativeRegionBalanceV4(token::_ConservativeMultiRegionToken,
            region_ref_hash::Digest256, diagonal::Float64,
            right_hand_side::Float64, initial_value::Float64,
            unit::UnitSignature,
            external_values::Tuple{Vararg{ConservativeExternalValueV4}},
            balance_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(region_ref_hash, diagonal, right_hand_side, initial_value, unit,
            external_values, balance_hash)
    end
end
semantic_view(x::ConservativeRegionBalanceV4) = (region_ref_hash=x.region_ref_hash,
    diagonal=x.diagonal, right_hand_side=x.right_hand_side,
    initial_value=x.initial_value, unit=x.unit,
    external_values=x.external_values, balance_hash=x.balance_hash)

function _cmr_balance_body(x::ConservativeRegionBalanceV4)
    (revision=_CMR_REVISION, region_ref_hash=x.region_ref_hash,
     diagonal=x.diagonal, right_hand_side=x.right_hand_side,
     initial_value=x.initial_value, unit=x.unit,
     external_value_hashes=Tuple(canonical_hash(v) for v in x.external_values))
end

function _cmr_validate_balance(contract::ConservativeMultiRegionContractV4,
        balance::ConservativeRegionBalanceV4)
    canonical_hash(balance)
    regions = Tuple(r for r in contract.regions if
        canonical_hash(r) == balance.region_ref_hash)
    length(regions) == 1 || throw(ArgumentError("balance region is missing or ambiguous"))
    region = only(regions)
    expected_owners = Tuple(o for o in contract.external_owners if
        o.region_ref_hash == balance.region_ref_hash)
    Tuple(v.owner_hash for v in balance.external_values) ==
        Tuple(canonical_hash(o) for o in expected_owners) ||
        throw(ArgumentError("balance external values do not exactly cover owned occurrences"))
    all(canonical_hash(v) isa Digest256 for v in balance.external_values)
    all(v -> v.unit == region.unit, balance.external_values) ||
        throw(ArgumentError("balance external value unit mismatch"))
    derived_rhs = sum((Float64(o.coefficient) * v.value for (o, v) in
        zip(expected_owners, balance.external_values)); init=0.0)
    balance.right_hand_side == derived_rhs ||
        throw(ArgumentError("balance right-hand side was not derived from owned occurrences"))
    balance.unit == region.unit || throw(ArgumentError("balance region unit mismatch"))
    balance
end
canonical_hash(x::ConservativeRegionBalanceV4) = begin
    isfinite(x.diagonal) && x.diagonal > 0 || throw(ArgumentError("region diagonal must be positive finite"))
    isfinite(x.right_hand_side) && isfinite(x.initial_value) || throw(ArgumentError("region values must be finite"))
    h = canonical_hash(_cmr_balance_body(x))
    h == x.balance_hash || throw(ArgumentError("region balance hash mismatch"))
    h
end

function make_conservative_region_balance(contract::ConservativeMultiRegionContractV4,
        region_id; diagonal, external_values, initial_value=0.0)
    canonical_hash(contract)
    id = _cmr_text(region_id, "region id")
    hits = Tuple(r for r in contract.regions if r.region_id == id)
    length(hits) == 1 || throw(ArgumentError("region balance target is missing or ambiguous"))
    region = only(hits)
    d = _cmr_finite(diagonal, "region diagonal")
    d > 0 || throw(ArgumentError("region diagonal must be positive"))
    values = Tuple(external_values)
    all(v -> v isa ConservativeExternalValueV4, values) ||
        throw(ArgumentError("external values must be typed"))
    expected_owners = Tuple(o for o in contract.external_owners if
        o.region_ref_hash == canonical_hash(region))
    Tuple(v.owner_hash for v in values) == Tuple(canonical_hash(o) for o in expected_owners) ||
        throw(ArgumentError("external values must exactly cover region-owned occurrences in contract order"))
    all(canonical_hash(v) isa Digest256 for v in values)
    all(v -> v.unit == region.unit, values) || throw(ArgumentError("external value unit differs from region balance unit"))
    rhs = sum((Float64(o.coefficient) * v.value for (o, v) in
        zip(expected_owners, values)); init=0.0)
    isfinite(rhs) || throw(ArgumentError("derived region right hand side is nonfinite"))
    initial = _cmr_finite(initial_value, "region initial value")
    body = (revision=_CMR_REVISION, region_ref_hash=canonical_hash(region),
        diagonal=d, right_hand_side=rhs, initial_value=initial, unit=region.unit)
    ConservativeRegionBalanceV4(_CMR_TOKEN, canonical_hash(region), d, rhs,
        initial, region.unit, values, canonical_hash((body...,
            external_value_hashes=Tuple(canonical_hash(v) for v in values))))
end

struct ConservativeInterfaceCoefficientV4
    interface_ref_hash::Digest256
    coefficient::Float64
    coefficient_hash::Digest256
    function ConservativeInterfaceCoefficientV4(token::_ConservativeMultiRegionToken,
            interface_ref_hash::Digest256, coefficient::Float64,
            coefficient_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(interface_ref_hash, coefficient, coefficient_hash)
    end
end
semantic_view(x::ConservativeInterfaceCoefficientV4) = (
    interface_ref_hash=x.interface_ref_hash, coefficient=x.coefficient,
    coefficient_hash=x.coefficient_hash)
canonical_hash(x::ConservativeInterfaceCoefficientV4) = begin
    isfinite(x.coefficient) && x.coefficient > 0 || throw(ArgumentError("interface coefficient must be positive finite"))
    h = canonical_hash((revision=_CMR_REVISION,
        interface_ref_hash=x.interface_ref_hash, coefficient=x.coefficient))
    h == x.coefficient_hash || throw(ArgumentError("interface coefficient hash mismatch"))
    h
end

function make_conservative_interface_coefficient(contract::ConservativeMultiRegionContractV4,
        interface_id; coefficient)
    canonical_hash(contract)
    id = _cmr_text(interface_id, "interface id")
    hits = Tuple(i for i in contract.interfaces if i.interface_id == id)
    length(hits) == 1 || throw(ArgumentError("interface coefficient target is missing or ambiguous"))
    ref = only(hits)
    value = _cmr_finite(coefficient, "interface coefficient")
    value > 0 || throw(ArgumentError("interface coefficient must be positive"))
    body = (revision=_CMR_REVISION, interface_ref_hash=canonical_hash(ref),
        coefficient=value)
    ConservativeInterfaceCoefficientV4(_CMR_TOKEN, canonical_hash(ref), value,
        canonical_hash(body))
end

struct ConservativeMultiRegionProtocolV4
    residual_tolerance::Float64
    max_iterations::Int
    protocol_hash::Digest256
    function ConservativeMultiRegionProtocolV4(residual_tolerance=1e-12,
            max_iterations::Integer=4)
        tol = _cmr_finite(residual_tolerance, "residual tolerance")
        tol > 0 || throw(ArgumentError("residual tolerance must be positive"))
        max_iterations isa Bool && throw(ArgumentError("max iterations must not be Bool"))
        iterations = Int(max_iterations)
        iterations >= 1 || throw(ArgumentError("max iterations must be positive"))
        body = (revision=_CMR_REVISION, residual_tolerance=tol,
            max_iterations=iterations, method=:dense_linear_newton,
            residual_assembly=:one_global_non_diagonal_vector)
        new(tol, iterations, canonical_hash(body))
    end
end
semantic_view(x::ConservativeMultiRegionProtocolV4) = (
    residual_tolerance=x.residual_tolerance, max_iterations=x.max_iterations,
    protocol_hash=x.protocol_hash)
canonical_hash(x::ConservativeMultiRegionProtocolV4) = begin
    body = (revision=_CMR_REVISION, residual_tolerance=x.residual_tolerance,
        max_iterations=x.max_iterations, method=:dense_linear_newton,
        residual_assembly=:one_global_non_diagonal_vector)
    h = canonical_hash(body)
    h == x.protocol_hash || throw(ArgumentError("multi-region protocol hash mismatch"))
    h
end

function conservative_multiregion_manifest(contract::ConservativeMultiRegionContractV4)
    canonical_hash(contract)
    ProviderManifestV4(_CMR_SCHEMA, _CMR_REVISION, contract.capability.kind,
        contract.capability,
        (bounds_hash=contract.capability.applicability_bounds,
         context_hash=contract.context_hash, contract_hash=contract.contract_hash,
         model_class="manufactured_control",
         dependency_lock_hash=_CMR_DEPENDENCY_LOCK_HASH),
        "julia-dense-linear-newton", "v1", _CMR_CODE_HASH,
        "manufactured-multiregion-control", screen_only;
        input_schema_hash=contract.capability.input_schema_hash)
end

struct ConservativeMultiRegionPlanV4
    context_hash::Digest256
    contract_hash::Digest256
    balances::Tuple{Vararg{ConservativeRegionBalanceV4}}
    interface_coefficients::Tuple{Vararg{ConservativeInterfaceCoefficientV4}}
    protocol::ConservativeMultiRegionProtocolV4
    provider::ProviderManifestV4
    assembled_matrix::Tuple
    right_hand_side::Tuple{Vararg{Float64}}
    execution_input_hash::Digest256
    plan_hash::Digest256
    function ConservativeMultiRegionPlanV4(token::_ConservativeMultiRegionToken,
            context_hash::Digest256, contract_hash::Digest256,
            balances::Tuple{Vararg{ConservativeRegionBalanceV4}},
            coefficients::Tuple{Vararg{ConservativeInterfaceCoefficientV4}},
            protocol::ConservativeMultiRegionProtocolV4,
            provider::ProviderManifestV4, assembled_matrix::Tuple,
            right_hand_side::Tuple{Vararg{Float64}},
            execution_input_hash::Digest256, plan_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, contract_hash, balances, coefficients, protocol,
            provider, assembled_matrix, right_hand_side, execution_input_hash,
            plan_hash)
    end
end
semantic_view(x::ConservativeMultiRegionPlanV4) = (context_hash=x.context_hash,
    contract_hash=x.contract_hash, balance_hashes=Tuple(canonical_hash(b) for b in x.balances),
    coefficient_hashes=Tuple(canonical_hash(c) for c in x.interface_coefficients),
    protocol_hash=canonical_hash(x.protocol), provider_manifest_hash=x.provider.manifest_hash,
    assembled_matrix=x.assembled_matrix, right_hand_side=x.right_hand_side,
    execution_input_hash=x.execution_input_hash, plan_hash=x.plan_hash)

struct ConservativeMultiRegionPlanResolutionV4
    context_hash::Digest256
    contract_hash::Digest256
    status::Symbol
    plan::Union{Nothing,ConservativeMultiRegionPlanV4}
    recoverable_gaps::Tuple{Vararg{String}}
    resolution_hash::Digest256
    function ConservativeMultiRegionPlanResolutionV4(token::_ConservativeMultiRegionToken,
            context_hash::Digest256, contract_hash::Digest256, status::Symbol,
            plan::Union{Nothing,ConservativeMultiRegionPlanV4},
            gaps::Tuple{Vararg{String}}, resolution_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, contract_hash, status, plan, gaps, resolution_hash)
    end
end
semantic_view(x::ConservativeMultiRegionPlanResolutionV4) = (
    context_hash=x.context_hash, contract_hash=x.contract_hash, status=x.status,
    plan_hash=x.plan === nothing ? nothing : x.plan.plan_hash,
    recoverable_gaps=x.recoverable_gaps, resolution_hash=x.resolution_hash)

function _cmr_plan_resolution(context_hash, contract_hash, plan, gaps)
    gs = Tuple(String(g) for g in gaps)
    status = plan === nothing ? :recoverable_gap : :ready
    status === :ready && !isempty(gs) && throw(ArgumentError("ready plan resolution cannot contain gaps"))
    status === :recoverable_gap && isempty(gs) && throw(ArgumentError("plan gap requires reason"))
    body = (revision=_CMR_REVISION, kind=:plan_resolution,
        context_hash=context_hash, contract_hash=contract_hash, status=status,
        plan_hash=plan === nothing ? nothing : plan.plan_hash, recoverable_gaps=gs)
    ConservativeMultiRegionPlanResolutionV4(_CMR_TOKEN, context_hash,
        contract_hash, status, plan, gs, canonical_hash(body))
end

function canonical_hash(x::ConservativeMultiRegionPlanResolutionV4)
    x.status in (:ready, :recoverable_gap) || throw(ArgumentError("invalid plan resolution status"))
    (x.status === :ready) == (x.plan !== nothing) || throw(ArgumentError("plan resolution payload mismatch"))
    body = (revision=_CMR_REVISION, kind=:plan_resolution,
        context_hash=x.context_hash, contract_hash=x.contract_hash,
        status=x.status, plan_hash=x.plan === nothing ? nothing : x.plan.plan_hash,
        recoverable_gaps=x.recoverable_gaps)
    h = canonical_hash(body)
    h == x.resolution_hash || throw(ArgumentError("plan resolution hash mismatch"))
    h
end

function _cmr_assemble(contract, balances, coefficients)
    n = length(contract.regions)
    region_index = Dict(canonical_hash(r) => i for (i, r) in enumerate(contract.regions))
    A = zeros(Float64, n, n)
    rhs = zeros(Float64, n)
    initial = zeros(Float64, n)
    for (i, balance) in enumerate(balances)
        A[i, i] = balance.diagonal
        rhs[i] = balance.right_hand_side
        initial[i] = balance.initial_value
    end
    term_hashes = Digest256[]
    for (interface_ref, coefficient) in zip(contract.interfaces, coefficients)
        i = region_index[interface_ref.minus_region_ref_hash]
        j = region_index[interface_ref.plus_region_ref_hash]
        k = coefficient.coefficient
        A[i, i] += k; A[i, j] -= k
        A[j, j] += k; A[j, i] -= k
        push!(term_hashes, canonical_hash((interface_ref_hash=canonical_hash(interface_ref),
            coefficient_hash=canonical_hash(coefficient), rows=(i, j),
            contributions=((i, i, k), (i, j, -k), (j, i, -k), (j, j, k)))))
    end
    matrix = Tuple(Tuple(A[i, j] for j in axes(A, 2)) for i in axes(A, 1))
    matrix, Tuple(rhs), Tuple(initial), Tuple(term_hashes)
end

function _cmr_plan_body(context_hash, contract_hash, balances, coefficients,
        protocol, provider, matrix, rhs, input_hash)
    (revision=_CMR_REVISION, context_hash=context_hash, contract_hash=contract_hash,
     balance_hashes=Tuple(canonical_hash(b) for b in balances),
     coefficient_hashes=Tuple(canonical_hash(c) for c in coefficients),
     protocol_hash=canonical_hash(protocol), provider_manifest_hash=provider.manifest_hash,
     provider_code_hash=provider.code_hash, assembled_matrix=matrix,
     right_hand_side=rhs, execution_input_hash=input_hash)
end

function validate_conservative_multiregion_plan(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4)
    validate_conservative_multiregion_contract(context, contract)
    plan.context_hash == context.context_hash || throw(ArgumentError("plan context mismatch"))
    plan.contract_hash == contract.contract_hash || throw(ArgumentError("plan contract mismatch"))
    length(plan.balances) == length(contract.regions) || throw(ArgumentError("plan balance count mismatch"))
    length(plan.interface_coefficients) == length(contract.interfaces) || throw(ArgumentError("plan interface coefficient count mismatch"))
    Tuple(b.region_ref_hash for b in plan.balances) == Tuple(canonical_hash(r) for r in contract.regions) ||
        throw(ArgumentError("plan balances are missing, duplicated, or reordered"))
    Tuple(c.interface_ref_hash for c in plan.interface_coefficients) == Tuple(canonical_hash(i) for i in contract.interfaces) ||
        throw(ArgumentError("plan interface coefficients are missing, duplicated, or reordered"))
    all(_cmr_validate_balance(contract, b) isa ConservativeRegionBalanceV4 for
        b in plan.balances)
    all(canonical_hash(c) isa Digest256 for c in plan.interface_coefficients)
    canonical_hash(plan.protocol)
    local_provider = conservative_multiregion_manifest(contract)
    plan.provider.manifest_hash == local_provider.manifest_hash &&
        plan.provider.code_hash == local_provider.code_hash ||
        throw(ArgumentError("plan provider is not the exact local manufactured-control provider"))
    matrix, rhs, initial, term_hashes = _cmr_assemble(contract, plan.balances,
        plan.interface_coefficients)
    matrix == plan.assembled_matrix || throw(ArgumentError("plan matrix reconstruction mismatch"))
    rhs == plan.right_hand_side || throw(ArgumentError("plan right-hand side mismatch"))
    n = length(matrix)
    off_diagonal = count(!iszero(matrix[i][j]) for i in 1:n for j in 1:n if i != j)
    off_diagonal >= 2 * length(contract.interfaces) ||
        throw(ArgumentError("plan did not assemble actual non-diagonal interface coupling"))
    input_body = (revision=_CMR_REVISION, kind=:execution_input,
        context_hash=context.context_hash, contract_hash=contract.contract_hash,
        balance_hashes=Tuple(canonical_hash(b) for b in plan.balances),
        coefficient_hashes=Tuple(canonical_hash(c) for c in plan.interface_coefficients),
        protocol_hash=canonical_hash(plan.protocol), provider_manifest_hash=plan.provider.manifest_hash,
        initial_state=initial, interface_term_hashes=term_hashes)
    expected_input = canonical_hash(input_body)
    expected_input == plan.execution_input_hash || throw(ArgumentError("plan execution input hash mismatch"))
    h = canonical_hash(_cmr_plan_body(context.context_hash, contract.contract_hash,
        plan.balances, plan.interface_coefficients, plan.protocol, plan.provider,
        matrix, rhs, expected_input))
    h == plan.plan_hash || throw(ArgumentError("multi-region plan hash mismatch"))
    h
end

canonical_hash(x::ConservativeMultiRegionPlanV4) = begin
    h = canonical_hash(_cmr_plan_body(x.context_hash, x.contract_hash, x.balances,
        x.interface_coefficients, x.protocol, x.provider, x.assembled_matrix,
        x.right_hand_side, x.execution_input_hash))
    h == x.plan_hash || throw(ArgumentError("multi-region plan local hash mismatch"))
    h
end

function admit_conservative_multiregion_plan(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4, balances, coefficients,
        protocol::ConservativeMultiRegionProtocolV4, providers)
    validate_conservative_multiregion_contract(context, contract)
    bs = Tuple(balances); cs = Tuple(coefficients)
    all(x -> x isa ConservativeRegionBalanceV4, bs) || throw(ArgumentError("balances must be typed"))
    all(x -> x isa ConservativeInterfaceCoefficientV4, cs) || throw(ArgumentError("interface coefficients must be typed"))
    length(bs) == length(contract.regions) || throw(ArgumentError("one balance per region is required"))
    length(cs) == length(contract.interfaces) || throw(ArgumentError("one coefficient per interface is required"))
    Tuple(b.region_ref_hash for b in bs) == Tuple(canonical_hash(r) for r in contract.regions) ||
        throw(ArgumentError("balances must follow exact contract region order"))
    Tuple(c.interface_ref_hash for c in cs) == Tuple(canonical_hash(i) for i in contract.interfaces) ||
        throw(ArgumentError("coefficients must follow exact contract interface order"))
    all(_cmr_validate_balance(contract, b) isa ConservativeRegionBalanceV4 for b in bs)
    ps = providers isa ProviderManifestV4 ? (providers,) : Tuple(providers)
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("providers must be typed ProviderManifestV4"))
    match = match_provider(contract.capability, ps)
    match.status == unique_match || return _cmr_plan_resolution(context.context_hash,
        contract.contract_hash, nothing, ("provider_gap:" * match.reason,))
    provider = match.provider
    local_provider = conservative_multiregion_manifest(contract)
    provider.manifest_hash == local_provider.manifest_hash && provider.code_hash == local_provider.code_hash ||
        return _cmr_plan_resolution(context.context_hash, contract.contract_hash,
            nothing, ("provider_gap:exact local provider implementation is absent",))
    matrix, rhs, initial, term_hashes = _cmr_assemble(contract, bs, cs)
    n = length(matrix)
    off_diagonal = count(!iszero(matrix[i][j]) for i in 1:n for j in 1:n if i != j)
    off_diagonal >= 2 * length(contract.interfaces) || throw(ArgumentError("assembled system lacks non-diagonal interface coupling"))
    input_body = (revision=_CMR_REVISION, kind=:execution_input,
        context_hash=context.context_hash, contract_hash=contract.contract_hash,
        balance_hashes=Tuple(canonical_hash(b) for b in bs),
        coefficient_hashes=Tuple(canonical_hash(c) for c in cs),
        protocol_hash=canonical_hash(protocol), provider_manifest_hash=provider.manifest_hash,
        initial_state=initial, interface_term_hashes=term_hashes)
    input_hash = canonical_hash(input_body)
    plan_body = _cmr_plan_body(context.context_hash, contract.contract_hash,
        bs, cs, protocol, provider, matrix, rhs, input_hash)
    plan = ConservativeMultiRegionPlanV4(_CMR_TOKEN, context.context_hash,
        contract.contract_hash, bs, cs, protocol, provider, matrix, rhs,
        input_hash, canonical_hash(plan_body))
    validate_conservative_multiregion_plan(context, contract, plan)
    _cmr_plan_resolution(context.context_hash, contract.contract_hash, plan, ())
end

struct ConservativeMultiRegionIterationV4
    iteration::Int
    state::Tuple{Vararg{Float64}}
    global_residual::Tuple{Vararg{Float64}}
    residual_inf::Float64
    iteration_hash::Digest256
    function ConservativeMultiRegionIterationV4(token::_ConservativeMultiRegionToken,
            iteration::Int, state::Tuple{Vararg{Float64}},
            residual::Tuple{Vararg{Float64}}, residual_inf::Float64,
            iteration_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(iteration, state, residual, residual_inf, iteration_hash)
    end
end
semantic_view(x::ConservativeMultiRegionIterationV4) = (iteration=x.iteration,
    state=x.state, global_residual=x.global_residual,
    residual_inf=x.residual_inf, iteration_hash=x.iteration_hash)
canonical_hash(x::ConservativeMultiRegionIterationV4) = begin
    x.iteration >= 0 || throw(ArgumentError("iteration index must be nonnegative"))
    all(isfinite, x.state) && all(isfinite, x.global_residual) && isfinite(x.residual_inf) ||
        throw(ArgumentError("iteration contains nonfinite data"))
    expected_norm = isempty(x.global_residual) ? 0.0 : maximum(abs, x.global_residual)
    x.residual_inf == expected_norm || throw(ArgumentError("iteration residual norm mismatch"))
    h = canonical_hash((revision=_CMR_REVISION, iteration=x.iteration,
        state=x.state, global_residual=x.global_residual,
        residual_inf=x.residual_inf))
    h == x.iteration_hash || throw(ArgumentError("iteration hash mismatch"))
    h
end

struct ConservativeMultiRegionResultV4
    status::Symbol
    assembled_matrix::Tuple
    right_hand_side::Tuple{Vararg{Float64}}
    iteration_trace::Tuple{Vararg{ConservativeMultiRegionIterationV4}}
    final_state::Tuple{Vararg{Float64}}
    final_global_residual::Tuple{Vararg{Float64}}
    off_diagonal_nonzeros::Int
    interface_conservation_defect::Float64
    reason::String
    result_hash::Digest256
    function ConservativeMultiRegionResultV4(token::_ConservativeMultiRegionToken,
            status::Symbol, matrix::Tuple, rhs::Tuple{Vararg{Float64}},
            trace::Tuple{Vararg{ConservativeMultiRegionIterationV4}},
            final_state::Tuple{Vararg{Float64}},
            final_residual::Tuple{Vararg{Float64}}, off_diagonal_nonzeros::Int,
            conservation_defect::Float64, reason::String,
            result_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(status, matrix, rhs, trace, final_state, final_residual,
            off_diagonal_nonzeros, conservation_defect, reason, result_hash)
    end
end
semantic_view(x::ConservativeMultiRegionResultV4) = (status=x.status,
    assembled_matrix=x.assembled_matrix, right_hand_side=x.right_hand_side,
    iteration_trace=x.iteration_trace, final_state=x.final_state,
    final_global_residual=x.final_global_residual,
    off_diagonal_nonzeros=x.off_diagonal_nonzeros,
    interface_conservation_defect=x.interface_conservation_defect,
    reason=x.reason, result_hash=x.result_hash)

function _cmr_result_body(status, matrix, rhs, trace, final_state, final_residual,
        offdiag, defect, reason)
    (revision=_CMR_REVISION, status=status, assembled_matrix=matrix,
     right_hand_side=rhs, iteration_hashes=Tuple(canonical_hash(t) for t in trace),
     final_state=final_state, final_global_residual=final_residual,
     off_diagonal_nonzeros=offdiag,
     interface_conservation_defect=defect, reason=reason)
end

struct ConservativeMultiRegionReceiptV4
    context_hash::Digest256
    contract_hash::Digest256
    plan_hash::Digest256
    execution_input_hash::Digest256
    provider_manifest_hash::Digest256
    result::ConservativeMultiRegionResultV4
    claim_ceiling::ClaimCeiling
    model_class::Symbol
    receipt_hash::Digest256
    function ConservativeMultiRegionReceiptV4(token::_ConservativeMultiRegionToken,
            context_hash::Digest256, contract_hash::Digest256,
            plan_hash::Digest256, input_hash::Digest256,
            provider_hash::Digest256, result::ConservativeMultiRegionResultV4,
            claim_ceiling::ClaimCeiling, model_class::Symbol,
            receipt_hash::Digest256)
        token === _CMR_TOKEN || throw(ArgumentError("private constructor"))
        new(context_hash, contract_hash, plan_hash, input_hash, provider_hash,
            result, claim_ceiling, model_class, receipt_hash)
    end
end
semantic_view(x::ConservativeMultiRegionReceiptV4) = (context_hash=x.context_hash,
    contract_hash=x.contract_hash, plan_hash=x.plan_hash,
    execution_input_hash=x.execution_input_hash,
    provider_manifest_hash=x.provider_manifest_hash,
    result_hash=x.result.result_hash, claim_ceiling=x.claim_ceiling,
    model_class=x.model_class, receipt_hash=x.receipt_hash)

_cmr_matrix(plan) = reduce(vcat, [collect(row)' for row in plan.assembled_matrix])

function _cmr_iteration(iteration, state, residual)
    s = Tuple(Float64(x) for x in state)
    r = Tuple(Float64(x) for x in residual)
    norm_value = isempty(r) ? 0.0 : maximum(abs, r)
    body = (revision=_CMR_REVISION, iteration=iteration, state=s,
        global_residual=r, residual_inf=norm_value)
    ConservativeMultiRegionIterationV4(_CMR_TOKEN, iteration, s, r,
        norm_value, canonical_hash(body))
end

function _cmr_conservation_defect(contract, coefficients, state)
    index = Dict(canonical_hash(r) => i for (i, r) in enumerate(contract.regions))
    isempty(state) && return 0.0
    maximum((abs(begin
        i = index[ref.minus_region_ref_hash]; j = index[ref.plus_region_ref_hash]
        minus_term = coefficient.coefficient * (state[i] - state[j])
        plus_term = coefficient.coefficient * (state[j] - state[i])
        minus_term + plus_term
    end) for (ref, coefficient) in zip(contract.interfaces, coefficients)); init=0.0)
end

function _cmr_make_result(status, plan, trace, final_state, final_residual,
        offdiag, defect, reason)
    body = _cmr_result_body(status, plan.assembled_matrix,
        plan.right_hand_side, trace, final_state, final_residual, offdiag,
        defect, reason)
    ConservativeMultiRegionResultV4(_CMR_TOKEN, status, plan.assembled_matrix,
        plan.right_hand_side, trace, final_state, final_residual, offdiag,
        defect, reason, canonical_hash(body))
end

function _cmr_run(contract, plan)
    A = _cmr_matrix(plan)
    rhs = collect(plan.right_hand_side)
    state = [b.initial_value for b in plan.balances]
    trace = ConservativeMultiRegionIterationV4[]
    offdiag = count(!iszero(A[i, j]) for i in axes(A, 1) for j in axes(A, 2) if i != j)
    try
        for iteration in 0:plan.protocol.max_iterations
            residual = A * state - rhs
            all(isfinite, residual) || return _cmr_make_result(:unknown, plan,
                (), (), (), offdiag, 0.0,
                "nonfinite_global_residual")
            push!(trace, _cmr_iteration(iteration, state, residual))
            maximum(abs, residual) <= plan.protocol.residual_tolerance &&
                return _cmr_make_result(:pass, plan, Tuple(trace), Tuple(state),
                    Tuple(residual), offdiag,
                    _cmr_conservation_defect(contract, plan.interface_coefficients, state),
                    "manufactured_control_converged")
            iteration == plan.protocol.max_iterations && break
            correction = A \ residual
            all(isfinite, correction) || return _cmr_make_result(:unknown, plan,
                (), (), (), offdiag, 0.0,
                "nonfinite_linear_correction")
            state .-= correction
        end
        residual = A * state - rhs
        _cmr_make_result(:numerical_fail, plan, Tuple(trace), Tuple(state),
            Tuple(residual), offdiag,
            _cmr_conservation_defect(contract, plan.interface_coefficients, state),
            "residual_tolerance_not_met")
    catch error
        _cmr_make_result(:unknown, plan, (), (), (), offdiag, 0.0,
            "execution_error:" * sprint(showerror, error))
    end
end

function validate_conservative_multiregion_result(contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4, result::ConservativeMultiRegionResultV4)
    result.status in (:pass, :numerical_fail, :unknown) || throw(ArgumentError("invalid multi-region result status"))
    result.assembled_matrix == plan.assembled_matrix || throw(ArgumentError("result matrix mismatch"))
    result.right_hand_side == plan.right_hand_side || throw(ArgumentError("result right-hand side mismatch"))
    !isempty(result.iteration_trace) || result.status === :unknown || throw(ArgumentError("executed result has no trace"))
    A = _cmr_matrix(plan); rhs = collect(plan.right_hand_side)
    for (i, item) in enumerate(result.iteration_trace)
        canonical_hash(item)
        item.iteration == i - 1 || throw(ArgumentError("iteration trace is not contiguous"))
        expected = Tuple(A * collect(item.state) - rhs)
        item.global_residual == expected || throw(ArgumentError("iteration does not contain the global residual"))
        if i < length(result.iteration_trace)
            next_state = Tuple(collect(item.state) - A \ collect(item.global_residual))
            result.iteration_trace[i + 1].state == next_state || throw(ArgumentError("iteration did not apply the coupled global correction"))
        end
    end
    last_item = isempty(result.iteration_trace) ? nothing : last(result.iteration_trace)
    if last_item !== nothing
        result.final_state == last_item.state || throw(ArgumentError("final state does not match trace"))
        result.final_global_residual == last_item.global_residual || throw(ArgumentError("final residual does not match trace"))
    end
    n = length(plan.assembled_matrix)
    expected_offdiag = count(!iszero(plan.assembled_matrix[i][j]) for i in 1:n for j in 1:n if i != j)
    result.off_diagonal_nonzeros == expected_offdiag &&
        expected_offdiag >= 2 * length(contract.interfaces) ||
        throw(ArgumentError("result lacks verified non-diagonal coupling"))
    expected_defect = _cmr_conservation_defect(contract,
        plan.interface_coefficients, result.final_state)
    result.interface_conservation_defect == expected_defect || throw(ArgumentError("interface conservation defect mismatch"))
    if result.status === :pass
        last_item !== nothing && last_item.residual_inf <= plan.protocol.residual_tolerance ||
            throw(ArgumentError("pass result did not meet residual tolerance"))
        expected_defect == 0.0 || throw(ArgumentError("pass result does not conserve interface flux"))
    end
    h = canonical_hash(_cmr_result_body(result.status, result.assembled_matrix,
        result.right_hand_side, result.iteration_trace, result.final_state,
        result.final_global_residual, result.off_diagonal_nonzeros,
        result.interface_conservation_defect, result.reason))
    h == result.result_hash || throw(ArgumentError("multi-region result hash mismatch"))
    h
end

function _cmr_receipt_body(context, contract, plan, result)
    (revision=_CMR_REVISION, context_hash=context.context_hash,
     contract_hash=contract.contract_hash, plan_hash=plan.plan_hash,
     execution_input_hash=plan.execution_input_hash,
     provider_manifest_hash=plan.provider.manifest_hash,
     result_hash=result.result_hash, claim_ceiling=screen_only,
     model_class=:manufactured_control)
end

function validate_conservative_multiregion_receipt(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4,
        receipt::ConservativeMultiRegionReceiptV4)
    validate_conservative_multiregion_plan(context, contract, plan)
    receipt.context_hash == context.context_hash || throw(ArgumentError("receipt context mismatch"))
    receipt.contract_hash == contract.contract_hash || throw(ArgumentError("receipt contract mismatch"))
    receipt.plan_hash == plan.plan_hash || throw(ArgumentError("receipt plan mismatch"))
    receipt.execution_input_hash == plan.execution_input_hash || throw(ArgumentError("receipt input mismatch"))
    receipt.provider_manifest_hash == plan.provider.manifest_hash || throw(ArgumentError("receipt provider mismatch"))
    receipt.claim_ceiling == screen_only || throw(ArgumentError("receipt exceeds screen_only"))
    receipt.model_class === :manufactured_control || throw(ArgumentError("receipt model class mismatch"))
    validate_conservative_multiregion_result(contract, plan, receipt.result)
    h = canonical_hash(_cmr_receipt_body(context, contract, plan, receipt.result))
    h == receipt.receipt_hash || throw(ArgumentError("multi-region receipt hash mismatch"))
    h
end

function execute_conservative_multiregion!(store::AbstractDict,
        context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4)
    validate_conservative_multiregion_plan(context, contract, plan)
    if haskey(store, plan.execution_input_hash)
        receipt = store[plan.execution_input_hash]
        receipt isa ConservativeMultiRegionReceiptV4 || throw(ArgumentError("cache entry has wrong type"))
        validate_conservative_multiregion_receipt(context, contract, plan, receipt)
        return receipt
    end
    result = _cmr_run(contract, plan)
    body = _cmr_receipt_body(context, contract, plan, result)
    receipt = ConservativeMultiRegionReceiptV4(_CMR_TOKEN,
        context.context_hash, contract.contract_hash, plan.plan_hash,
        plan.execution_input_hash, plan.provider.manifest_hash, result,
        screen_only, :manufactured_control, canonical_hash(body))
    validate_conservative_multiregion_receipt(context, contract, plan, receipt)
    store[plan.execution_input_hash] = receipt
    receipt
end

"""Verify an existing cache entry without invoking the execution routine."""
function verify_conservative_multiregion_cache(store::AbstractDict,
        context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4)
    haskey(store, plan.execution_input_hash) || throw(ArgumentError("cache entry is missing"))
    receipt = store[plan.execution_input_hash]
    receipt isa ConservativeMultiRegionReceiptV4 || throw(ArgumentError("cache entry has wrong type"))
    validate_conservative_multiregion_receipt(context, contract, plan, receipt)
    receipt
end

"""Execute in a fresh store and require deterministic declared identities."""
function rerun_conservative_multiregion(context::ForwardChainContextV4,
        contract::ConservativeMultiRegionContractV4,
        plan::ConservativeMultiRegionPlanV4,
        prior::ConservativeMultiRegionReceiptV4)
    validate_conservative_multiregion_receipt(context, contract, plan, prior)
    fresh = Dict{Digest256,ConservativeMultiRegionReceiptV4}()
    replay = execute_conservative_multiregion!(fresh, context, contract, plan)
    replay.result.result_hash == prior.result.result_hash || throw(ArgumentError("fresh rerun result hash mismatch"))
    replay.receipt_hash == prior.receipt_hash || throw(ArgumentError("fresh rerun receipt hash mismatch"))
    replay
end

conservative_multiregion_manifest() = (
    schema=_CMR_SCHEMA, revision=_CMR_REVISION,
    purpose=:typed_ownership_and_global_conservative_residual,
    model_class=:manufactured_control, claim_ceiling=screen_only,
    emits_runtime_evidence=false, terminal_authority=false,
    credible_device_count=0)
