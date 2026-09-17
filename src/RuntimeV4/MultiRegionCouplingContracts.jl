"""Candidate-bound, screen-only contracts for coupled multi-region operators.

This file declares obligations and validates ownership.  It deliberately does
not assemble or solve a physical system, and therefore cannot mint physical
evidence from a manufactured fixture.
"""

import FusionConceptAI: AtomicMIMOHyperedgeV1, TypedOperatorHypergraphV1,
    canonical_hash, semantic_view, is_canonical_value,
    Digest256, governing, interface

const _MR_STATUSES = (:ready, :unknown, :deferred, :unsupported, :invalid)
const _MR_CHANNELS = (:particle, :energy, :current, :magnetic_flux, :force_balance)

struct MultiRegionRefV4
    region_id::String
    node_refs::Tuple{Vararg{Int}}
    function MultiRegionRefV4(region_id::AbstractString, node_refs)
        id = String(region_id); !isempty(id) || throw(ArgumentError("region id cannot be empty"))
        ns = Tuple(Int(x) for x in node_refs)
        all(x -> x > 0, ns) || throw(ArgumentError("region node refs must be positive"))
        length(unique(ns)) == length(ns) || throw(ArgumentError("region node refs must be unique"))
        new(id, ns)
    end
end

struct MultiRegionInterfaceV4
    interface_id::String
    minus_region::String
    plus_region::String
    channels::Tuple{Vararg{Symbol}}
    flux_bindings::Tuple
    function MultiRegionInterfaceV4(interface_id::AbstractString, minus_region::AbstractString,
                                    plus_region::AbstractString, channels, flux_bindings)
        id, minus, plus = String(interface_id), String(minus_region), String(plus_region)
        !isempty(id) && !isempty(minus) && !isempty(plus) && minus != plus ||
            throw(ArgumentError("interface endpoints must be distinct non-empty regions"))
        cs = Tuple(Symbol(x) for x in channels)
        isempty(cs) || all(x -> x in _MR_CHANNELS, cs) || throw(ArgumentError("unknown interface conservation channel"))
        length(unique(cs)) == length(cs) || throw(ArgumentError("interface channels must be unique"))
        fs = Tuple(flux_bindings)
        isempty(fs) || all(x -> _mr_flux_binding_valid(x), fs) || throw(ArgumentError("interface flux bindings must be typed"))
        new(id, minus, plus, cs, fs)
    end
end

struct MultiRegionFluxBindingV4
    channel::Symbol
    edge_id::String
    minus_node_ref::Int
    plus_node_ref::Int
    minus_output_port::Int
    plus_output_port::Int
    ledger_hash::Digest256
    unit_hash::Digest256
    function MultiRegionFluxBindingV4(channel::Symbol, edge_id::AbstractString, minus_node_ref::Integer, plus_node_ref::Integer,
                                      minus_output_port::Integer, plus_output_port::Integer, ledger_identity, unit)
        channel in _MR_CHANNELS || throw(ArgumentError("unknown flux conservation channel"))
        !isempty(String(edge_id)) && minus_node_ref > 0 && plus_node_ref > 0 && minus_output_port > 0 && plus_output_port > 0 ||
            throw(ArgumentError("flux binding endpoint is invalid"))
        new(channel, String(edge_id), Int(minus_node_ref), Int(plus_node_ref), Int(minus_output_port), Int(plus_output_port),
            canonical_hash(ledger_identity), canonical_hash(unit))
    end
end
semantic_view(x::MultiRegionFluxBindingV4) = (channel=x.channel, edge_id=x.edge_id, minus_node_ref=x.minus_node_ref,
    plus_node_ref=x.plus_node_ref, minus_output_port=x.minus_output_port, plus_output_port=x.plus_output_port,
    ledger_hash=x.ledger_hash, unit_hash=x.unit_hash)
_mr_flux_binding_valid(x) = x isa MultiRegionFluxBindingV4

struct MultiRegionCouplingContractV4
    candidate_prefix_hash::Digest256
    candidate_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    mechanism_graph_hash::Digest256
    contract_hash::Digest256
    regions::Tuple{Vararg{MultiRegionRefV4}}
    interfaces::Tuple{Vararg{MultiRegionInterfaceV4}}
    required_channels::Tuple{Vararg{Symbol}}
    claim_ceiling::Symbol
    function MultiRegionCouplingContractV4(compiled::CompiledCandidatePrefixV4, regions, interfaces;
                                           required_channels=_MR_CHANNELS, claim_ceiling::Symbol=:screen_only)
        rs, is = Tuple(regions), Tuple(interfaces)
        all(x -> x isa MultiRegionRefV4, rs) || throw(ArgumentError("regions must be typed"))
        all(x -> x isa MultiRegionInterfaceV4, is) || throw(ArgumentError("interfaces must be typed"))
        length(unique(x.region_id for x in rs)) == length(rs) || throw(ArgumentError("duplicate region id"))
        cs = Tuple(Symbol(x) for x in required_channels)
        all(x -> x in _MR_CHANNELS, cs) && length(unique(cs)) == length(cs) ||
            throw(ArgumentError("required channels are not closed"))
        claim_ceiling === :screen_only || throw(ArgumentError("multi-region contract is screen-only"))
        body = (candidate_prefix_hash=compiled.prefix_hash, candidate_hash=compiled.candidate.canonical_hashes.genome_bundle_hash,
            mission_hash=canonical_hash(compiled.mission_payload), bounds_hash=canonical_hash(compiled.bounds_payload),
            mechanism_graph_hash=canonical_hash(compiled.mechanism_graph),
            regions=rs, interfaces=is, required_channels=cs, claim_ceiling=claim_ceiling)
        is_canonical_value(body) || throw(ArgumentError("multi-region contract is not canonicalizable"))
        new(compiled.prefix_hash, body.candidate_hash, body.mission_hash, body.bounds_hash,
            body.mechanism_graph_hash, canonical_hash(body), rs, is, cs, claim_ceiling)
    end
end
semantic_view(x::MultiRegionRefV4) = (region_id=x.region_id, node_refs=x.node_refs)
semantic_view(x::MultiRegionInterfaceV4) = (interface_id=x.interface_id, minus_region=x.minus_region,
    plus_region=x.plus_region, channels=x.channels, flux_bindings=x.flux_bindings)
semantic_view(x::MultiRegionCouplingContractV4) = (candidate_prefix_hash=x.candidate_prefix_hash,
    candidate_hash=x.candidate_hash, mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
    mechanism_graph_hash=x.mechanism_graph_hash, contract_hash=x.contract_hash, regions=x.regions, interfaces=x.interfaces,
    required_channels=x.required_channels, claim_ceiling=x.claim_ceiling)

struct MultiRegionCouplingValidationV4
    status::Symbol
    contract_hash::Digest256
    gaps::Tuple{Vararg{String}}
    conservation_channels::Tuple{Vararg{Symbol}}
    function MultiRegionCouplingValidationV4(status::Symbol, contract_hash::Digest256, gaps, channels)
        status in _MR_STATUSES || throw(ArgumentError("invalid multi-region validation status"))
        new(status, contract_hash, Tuple(String(x) for x in gaps), Tuple(Symbol(x) for x in channels))
    end
end
semantic_view(x::MultiRegionCouplingValidationV4) = (status=x.status, contract_hash=x.contract_hash,
    gaps=x.gaps, conservation_channels=x.conservation_channels)

"""Validate only declarations bound to the compiled candidate's typed graph."""
function validate_multiregion_coupling(contract::MultiRegionCouplingContractV4,
                                       compiled::CompiledCandidatePrefixV4)
    gaps = String[]; graph = compiled.mechanism_graph
    body = (candidate_prefix_hash=contract.candidate_prefix_hash, candidate_hash=contract.candidate_hash,
        mission_hash=contract.mission_hash, bounds_hash=contract.bounds_hash,
        mechanism_graph_hash=contract.mechanism_graph_hash, regions=contract.regions, interfaces=contract.interfaces,
        required_channels=contract.required_channels, claim_ceiling=contract.claim_ceiling)
    canonical_hash(body) == contract.contract_hash || push!(gaps, "contract_hash_mismatch")
    contract.candidate_prefix_hash == compiled.prefix_hash || push!(gaps, "candidate_prefix_mismatch")
    contract.candidate_hash == compiled.candidate.canonical_hashes.genome_bundle_hash || push!(gaps, "candidate_hash_mismatch")
    contract.mission_hash == canonical_hash(compiled.mission_payload) || push!(gaps, "mission_hash_mismatch")
    contract.bounds_hash == canonical_hash(compiled.bounds_payload) || push!(gaps, "bounds_hash_mismatch")
    contract.mechanism_graph_hash == canonical_hash(graph) || push!(gaps, "mechanism_graph_mismatch")
    ids = Set(String(e.edge_id) for e in graph.hyperedges if e isa AtomicMIMOHyperedgeV1)
    node_count = length(graph.nodes)
    region_ids = Set(x.region_id for x in contract.regions)
    region_nodes = Dict(r.region_id => Set(r.node_refs) for r in contract.regions)
    for r in contract.regions
        all(n -> n <= node_count, r.node_refs) || push!(gaps, "region_node_out_of_graph:" * r.region_id)
    end
    length(contract.regions) >= 2 || push!(gaps, "at_least_two_regions_required")
    seen = Set{String}()
    for i in contract.interfaces
        i.interface_id in seen && push!(gaps, "duplicate_interface:" * i.interface_id); push!(seen, i.interface_id)
        i.minus_region in region_ids || push!(gaps, "missing_minus_region:" * i.interface_id)
        i.plus_region in region_ids || push!(gaps, "missing_plus_region:" * i.interface_id)
        isempty(i.channels) && push!(gaps, "interface_has_no_conservation_channel:" * i.interface_id)
        for binding in i.flux_bindings
            e = binding.edge_id
            binding.channel in i.channels || push!(gaps, "flux_channel_not_declared:" * e)
            e in ids || push!(gaps, "missing_typed_edge:" * e)
            binding.minus_node_ref in get(region_nodes, i.minus_region, Set{Int}()) || push!(gaps, "minus_endpoint_not_owned_by_region:" * e)
            binding.plus_node_ref in get(region_nodes, i.plus_region, Set{Int}()) || push!(gaps, "plus_endpoint_not_owned_by_region:" * e)
            if e in ids
                edge = only(x for x in graph.hyperedges if x isa AtomicMIMOHyperedgeV1 && x.edge_id == e)
                edge.role === interface || push!(gaps, "interface_edge_not_interface_role:" * e)
                minus_nodes = [b.graph_node_index for b in edge.output_bindings if b.program_position == binding.minus_output_port]
                plus_nodes = [b.graph_node_index for b in edge.output_bindings if b.program_position == binding.plus_output_port]
                length(minus_nodes) == 1 && minus_nodes[1] == binding.minus_node_ref || push!(gaps, "minus_region_node_or_port_mismatch:" * e)
                length(plus_nodes) == 1 && plus_nodes[1] == binding.plus_node_ref || push!(gaps, "plus_region_node_or_port_mismatch:" * e)
                matches = [p for p in edge.interface_flux_pairs if p.minus.account_ref.port_index == binding.minus_output_port &&
                    p.plus.account_ref.port_index == binding.plus_output_port]
                length(matches) == 1 || push!(gaps, "wrong_or_ambiguous_flux_ports:" * e)
                if length(matches) == 1
                    pair = matches[1]
                    canonical_hash(pair.minus.account_ref.ledger_identity) == binding.ledger_hash || push!(gaps, "ledger_identity_mismatch:" * e)
                    pair.minus.account_ref.direction === :minus && pair.plus.account_ref.direction === :plus || push!(gaps, "flux_orientation_mismatch:" * e)
                    canonical_hash(pair.minus.account_ref.ledger_identity.unit) == binding.unit_hash || push!(gaps, "unit_mismatch:" * e)
                    pair.minus.coefficient == -pair.plus.coefficient || push!(gaps, "flux_coefficient_not_closed:" * e)
                    pair.minus.account_ref.port_index == binding.minus_output_port || push!(gaps, "minus_port_mismatch:" * e)
                end
            end
        end
    end
    declared = Set(Symbol(c) for i in contract.interfaces for c in i.channels)
    for c in contract.required_channels
        c in declared || push!(gaps, "missing_required_conservation_channel:" * String(c))
    end
    status = isempty(gaps) ? :ready : :deferred
    MultiRegionCouplingValidationV4(status, canonical_hash(contract), gaps, Tuple(sort!(collect(declared))))
end

multiregion_coupling_contract(compiled, regions, interfaces; kwargs...) =
    MultiRegionCouplingContractV4(compiled, regions, interfaces; kwargs...)
