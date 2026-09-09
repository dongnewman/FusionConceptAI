"""Typed, candidate-bound oriented 3-D interface and discrete-space input.

This file is intentionally isolated from `FusionRuntimeV4.jl`. It compiles
only declarations already owned by typed G2 fields and an exact
`ForwardChainContextV4`.  Interface coefficients and endpoints are derived
from an actual `AtomicMIMOHyperedgeV1`; callers cannot supply or guess them.
No provider is selected, no solver is run, and no evidence is emitted.
"""

using FusionConceptAI
import FusionConceptAI: canonical_hash, semantic_view

const _TDOI_REVISION = "runtime-v4-three-d-oriented-interface-input-v1"
const _TDOI_SCHEMA = "fusionconceptai:runtime-v4-three-d-oriented-interface-input"
const _TDOI_TOKEN = Val(:three_d_oriented_interface_input_private)
const _TDOI_REQUIRED_GAPS = (
    "required_typed_three_d_oriented_interface_discrete_spaces",
    "required_three_d_oriented_interface_subject_binding")

function _tdoi_text(value, field::String)
    typeof(value) === String || throw(ArgumentError("$field must be an immutable String"))
    text = strip(value)
    !isempty(text) && isvalid(text) || throw(ArgumentError("$field cannot be empty"))
    lowered = lowercase(text)
    (lowered in ("*", "any", "all", "wildcard") || occursin('*', text)) &&
        throw(ArgumentError("$field cannot contain a wildcard"))
    String(text)
end

function _tdoi_positive_int(value, field::String, maximum::Int)
    value isa Bool && throw(ArgumentError("$field must be an integer, not Bool"))
    typeof(value) <: Integer || throw(ArgumentError("$field must be an integer"))
    typemin(Int) <= value <= typemax(Int) || throw(ArgumentError("$field is out of range"))
    result = Int(value)
    1 <= result <= maximum || throw(ArgumentError("$field is outside its admitted range"))
    result
end

function _tdoi_qualified_ref(value::QualifiedRefV1, field::String)
    _tdoi_text(value.id, "$field id")
    _tdoi_text(value.version, "$field version")
    value
end

@enum ThreeDDiscreteSpaceRoleV4 volume_space trace_space multiplier_space

struct ThreeDDiscreteSpaceV4
    space_id::String
    role::ThreeDDiscreteSpaceRoleV4
    owner_id::String
    support_ref::SpatialSupportRefV1
    basis_family::QualifiedRefV1
    physical_type::PhysicalType
    polynomial_order::Int
    quadrature_order::Int
    function ThreeDDiscreteSpaceV4(space_id, role::ThreeDDiscreteSpaceRoleV4,
            owner_id, support_ref::SpatialSupportRefV1,
            basis_family::QualifiedRefV1, physical_type::PhysicalType,
            polynomial_order, quadrature_order)
        physical_type.spatial_dimension == 3 ||
            throw(ArgumentError("discrete-space physical type must be three-dimensional"))
        physical_type.temporal_type == TemporalTypeV1(static_time) ||
            throw(ArgumentError("discrete-space physical type must use static time"))
        new(_tdoi_text(space_id, "space_id"), role,
            _tdoi_text(owner_id, "space owner_id"), support_ref,
            _tdoi_qualified_ref(basis_family, "basis family"), physical_type,
            _tdoi_positive_int(polynomial_order, "polynomial_order", 8),
            _tdoi_positive_int(quadrature_order, "quadrature_order", 32))
    end
end
semantic_view(x::ThreeDDiscreteSpaceV4) = (
    space_id=x.space_id, role=x.role, owner_id=x.owner_id,
    support_ref=x.support_ref, basis_family=x.basis_family,
    physical_type=x.physical_type, polynomial_order=x.polynomial_order,
    quadrature_order=x.quadrature_order)

struct ThreeDRegionSpaceDeclarationV4
    region_id::String
    state_node_id::String
    support_ref::SpatialSupportRefV1
    volume_space::ThreeDDiscreteSpaceV4
    function ThreeDRegionSpaceDeclarationV4(region_id, state_node_id,
            support_ref::SpatialSupportRefV1,
            volume::ThreeDDiscreteSpaceV4)
        id = _tdoi_text(region_id, "region_id")
        volume.role == volume_space && volume.owner_id == id ||
            throw(ArgumentError("volume space must be owned by its exact region"))
        volume.support_ref == support_ref ||
            throw(ArgumentError("volume space support must match its region"))
        new(id, _tdoi_text(state_node_id, "state_node_id"), support_ref, volume)
    end
end
semantic_view(x::ThreeDRegionSpaceDeclarationV4) = (
    region_id=x.region_id, state_node_id=x.state_node_id,
    support_ref=x.support_ref, volume_space=x.volume_space)

struct ThreeDOrientedInterfaceDeclarationV4
    interface_id::String
    edge_id::String
    minus_region_id::String
    plus_region_id::String
    ledger_identity::ConservationLedgerIdentityV1
    minus_trace_space::ThreeDDiscreteSpaceV4
    plus_trace_space::ThreeDDiscreteSpaceV4
    multiplier_space::ThreeDDiscreteSpaceV4
    function ThreeDOrientedInterfaceDeclarationV4(interface_id, edge_id,
            minus_region_id, plus_region_id,
            ledger_identity::ConservationLedgerIdentityV1,
            minus_trace::ThreeDDiscreteSpaceV4,
            plus_trace::ThreeDDiscreteSpaceV4,
            multiplier::ThreeDDiscreteSpaceV4)
        id = _tdoi_text(interface_id, "interface_id")
        minus = _tdoi_text(minus_region_id, "minus_region_id")
        plus = _tdoi_text(plus_region_id, "plus_region_id")
        minus != plus || throw(ArgumentError("interface endpoint regions must differ"))
        minus_trace.role == trace_space && minus_trace.owner_id == minus ||
            throw(ArgumentError("minus trace space must be owned by minus region"))
        plus_trace.role == trace_space && plus_trace.owner_id == plus ||
            throw(ArgumentError("plus trace space must be owned by plus region"))
        multiplier.role == multiplier_space && multiplier.owner_id == id ||
            throw(ArgumentError("multiplier space must be owned by its interface"))
        spaces = (minus_trace.space_id, plus_trace.space_id, multiplier.space_id)
        length(unique(spaces)) == 3 || throw(ArgumentError("interface space IDs must be unique"))
        new(id, _tdoi_text(edge_id, "interface edge_id"), minus, plus,
            ledger_identity, minus_trace, plus_trace, multiplier)
    end
end
semantic_view(x::ThreeDOrientedInterfaceDeclarationV4) = (
    interface_id=x.interface_id, edge_id=x.edge_id,
    minus_region_id=x.minus_region_id, plus_region_id=x.plus_region_id,
    ledger_identity=x.ledger_identity,
    minus_trace_space=x.minus_trace_space,
    plus_trace_space=x.plus_trace_space,
    multiplier_space=x.multiplier_space)

function _tdoi_declaration_body(declaration_id, regions, interfaces)
    (revision=_TDOI_REVISION, declaration_id=declaration_id,
     regions=regions, interfaces=interfaces,
     model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
     provider_selected=false, solver_executed=false, emits_evidence=false,
     p5_ready=false, credible_physical_device_count=0)
end

struct ThreeDOrientedInterfaceDeclarationSetV4
    declaration_id::String
    regions::Tuple{Vararg{ThreeDRegionSpaceDeclarationV4}}
    interfaces::Tuple{Vararg{ThreeDOrientedInterfaceDeclarationV4}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    credible_physical_device_count::Int
    declaration_hash::Digest256
    function ThreeDOrientedInterfaceDeclarationSetV4(declaration_id,
            region_declarations, interface_declarations)
        region_declarations isa Tuple && !(region_declarations isa NamedTuple) &&
            all(x -> typeof(x) === ThreeDRegionSpaceDeclarationV4,
                region_declarations) ||
            throw(ArgumentError("regions must be an immutable typed tuple"))
        interface_declarations isa Tuple &&
            !(interface_declarations isa NamedTuple) &&
            all(x -> typeof(x) === ThreeDOrientedInterfaceDeclarationV4,
                interface_declarations) ||
            throw(ArgumentError("interfaces must be an immutable typed tuple"))
        length(region_declarations) >= 2 ||
            throw(ArgumentError("at least two regions are required"))
        !isempty(interface_declarations) ||
            throw(ArgumentError("at least one oriented interface is required"))
        regions = Tuple(sort(collect(region_declarations), by=x -> x.region_id))
        interfaces = Tuple(sort(collect(interface_declarations), by=x -> x.interface_id))
        length(unique(x.region_id for x in regions)) == length(regions) ||
            throw(ArgumentError("region IDs must be unique"))
        length(unique(x.state_node_id for x in regions)) == length(regions) ||
            throw(ArgumentError("region state nodes must be uniquely owned"))
        length(unique(x.interface_id for x in interfaces)) == length(interfaces) ||
            throw(ArgumentError("interface IDs must be unique"))
        length(unique(x.edge_id for x in interfaces)) == length(interfaces) ||
            throw(ArgumentError("interface edges must be uniquely declared"))
        region_ids = Set(x.region_id for x in regions)
        all(x -> x.minus_region_id in region_ids && x.plus_region_id in region_ids,
            interfaces) || throw(ArgumentError("interface references an undeclared region"))
        adjacency = Dict(id => Set{String}() for id in region_ids)
        for interface in interfaces
            push!(adjacency[interface.minus_region_id], interface.plus_region_id)
            push!(adjacency[interface.plus_region_id], interface.minus_region_id)
        end
        reached = Set([first(regions).region_id])
        frontier = [first(regions).region_id]
        while !isempty(frontier)
            current = pop!(frontier)
            for neighbor in adjacency[current]
                if !(neighbor in reached)
                    push!(reached, neighbor)
                    push!(frontier, neighbor)
                end
            end
        end
        length(reached) == length(regions) ||
            throw(ArgumentError("region/interface declarations must form one connected graph"))
        id = _tdoi_text(declaration_id, "declaration_id")
        body = _tdoi_declaration_body(id, regions, interfaces)
        new(id, regions, interfaces, :manufactured_input_fixture, screen_only,
            false, false, false, false, 0, canonical_hash(body))
    end
    function ThreeDOrientedInterfaceDeclarationSetV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private interface declaration constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDOrientedInterfaceDeclarationSetV4) = merge(
    _tdoi_declaration_body(x.declaration_id, x.regions, x.interfaces),
    (declaration_hash=x.declaration_hash,))
function canonical_hash(x::ThreeDOrientedInterfaceDeclarationSetV4)
    expected = canonical_hash(_tdoi_declaration_body(x.declaration_id,
        x.regions, x.interfaces))
    expected == x.declaration_hash || throw(ArgumentError("interface declaration hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.p5_ready &&
        x.credible_physical_device_count == 0 ||
        throw(ArgumentError("interface declaration authority ceiling was exceeded"))
    expected
end

struct ThreeDRegionSpaceRefV4
    region_id::String
    support_identity_hash::Digest256
    state_node_identity_hash::Digest256
    state_type::PhysicalType
    volume_space::ThreeDDiscreteSpaceV4
    ref_hash::Digest256
    function ThreeDRegionSpaceRefV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private region ref constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDRegionSpaceRefV4) = (
    region_id=x.region_id, support_identity_hash=x.support_identity_hash,
    state_node_identity_hash=x.state_node_identity_hash,
    state_type=x.state_type, volume_space=x.volume_space,
    ref_hash=x.ref_hash)

struct ThreeDOrientedInterfaceRefV4
    interface_id::String
    edge_identity_hash::Digest256
    operator_program_hash::Digest256
    ast_root_identity_hashes::Tuple{Vararg{Digest256}}
    pair_position::Int
    pair_hash::Digest256
    interface_support_identity_hash::Digest256
    minus_region_ref_hash::Digest256
    plus_region_ref_hash::Digest256
    minus_state_node_identity_hash::Digest256
    plus_state_node_identity_hash::Digest256
    ledger_identity::ConservationLedgerIdentityV1
    minus_coefficient::Rational{Int64}
    plus_coefficient::Rational{Int64}
    minus_trace_space::ThreeDDiscreteSpaceV4
    plus_trace_space::ThreeDDiscreteSpaceV4
    multiplier_space::ThreeDDiscreteSpaceV4
    ref_hash::Digest256
    function ThreeDOrientedInterfaceRefV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private interface ref constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDOrientedInterfaceRefV4) = (
    interface_id=x.interface_id, edge_identity_hash=x.edge_identity_hash,
    operator_program_hash=x.operator_program_hash,
    ast_root_identity_hashes=x.ast_root_identity_hashes,
    pair_position=x.pair_position, pair_hash=x.pair_hash,
    interface_support_identity_hash=x.interface_support_identity_hash,
    minus_region_ref_hash=x.minus_region_ref_hash,
    plus_region_ref_hash=x.plus_region_ref_hash,
    minus_state_node_identity_hash=x.minus_state_node_identity_hash,
    plus_state_node_identity_hash=x.plus_state_node_identity_hash,
    ledger_identity=x.ledger_identity,
    minus_coefficient=x.minus_coefficient,
    plus_coefficient=x.plus_coefficient,
    minus_trace_space=x.minus_trace_space,
    plus_trace_space=x.plus_trace_space,
    multiplier_space=x.multiplier_space, ref_hash=x.ref_hash)

function _tdoi_output_node(edge::AtomicMIMOHyperedgeV1, position::Int)
    hits = Tuple(x.graph_node_index for x in edge.output_bindings
        if x.program_position == position)
    length(hits) == 1 || throw(ArgumentError("interface output binding is missing or ambiguous"))
    only(hits)
end

function _tdoi_edge_root_hashes(binding::ForwardGraphBindingV4, edge_position::Int)
    first_root = 1
    for i in 1:(edge_position - 1)
        _, roots, _ = _forward_edge_program(binding.graph.hyperedges[i])
        first_root += length(roots)
    end
    _, roots, _ = _forward_edge_program(binding.graph.hyperedges[edge_position])
    Tuple(binding.ast_root_identity_hashes[first_root + i - 1] for i in eachindex(roots))
end

function _tdoi_support_identity_hash(candidate::CandidateStatePackageV4,
        support_ref::SpatialSupportRefV1, field::String)
    supports = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === SpatialSupportGeneV1 && x.support_ref == support_ref)
    length(supports) == 1 ||
        throw(ArgumentError("$field support is absent from or ambiguous in current G2 fields"))
    canonical_hash(only(supports))
end

function _tdoi_compile_declaration(candidate::CandidateStatePackageV4,
        graph_binding::ForwardGraphBindingV4,
        declaration::ThreeDOrientedInterfaceDeclarationSetV4)
    canonical_hash(declaration)
    owned = Tuple(x for x in candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4 &&
           canonical_hash(x) == declaration.declaration_hash)
    length(owned) == 1 ||
        throw(ArgumentError("interface declaration is absent from or ambiguous in current G2 fields"))
    canonical_hash(graph_binding)
    graph = graph_binding.graph
    node_by_id = Dict{String,Int}()
    for (i, node) in enumerate(graph.nodes)
        haskey(node_by_id, node.node_id) && throw(ArgumentError("G2 node ID is ambiguous"))
        node_by_id[node.node_id] = i
    end
    region_refs = ThreeDRegionSpaceRefV4[]
    for region in declaration.regions
        haskey(node_by_id, region.state_node_id) ||
            throw(ArgumentError("region state node is absent from current G2 graph"))
        node_position = node_by_id[region.state_node_id]
        node = graph.nodes[node_position]
        node.node_kind === :state || throw(ArgumentError("region must own a typed G2 state node"))
        node.physical_type == region.volume_space.physical_type ||
            throw(ArgumentError("region volume-space physical type differs from state"))
        body = (revision=_TDOI_REVISION, region_id=region.region_id,
            support_identity_hash=_tdoi_support_identity_hash(candidate,
                region.support_ref, "region"),
            state_node_identity_hash=graph_binding.node_identity_hashes[node_position],
            state_type=node.physical_type, volume_space=region.volume_space)
        push!(region_refs, ThreeDRegionSpaceRefV4(_TDOI_TOKEN,
            body.region_id, body.support_identity_hash,
            body.state_node_identity_hash, body.state_type,
            body.volume_space, canonical_hash(body)))
    end
    graph_state_hashes = Set(graph_binding.node_identity_hashes[i]
        for (i, node) in enumerate(graph.nodes) if node.node_kind === :state)
    Set(x.state_node_identity_hash for x in region_refs) == graph_state_hashes ||
        throw(ArgumentError("region declarations must exactly cover current G2 state nodes"))
    region_by_id = Dict(x.region_id => x for x in region_refs)

    edge_by_id = Dict{String,Int}()
    for (i, edge) in enumerate(graph.hyperedges)
        haskey(edge_by_id, edge.edge_id) && throw(ArgumentError("G2 edge ID is ambiguous"))
        edge_by_id[edge.edge_id] = i
    end
    interface_refs = ThreeDOrientedInterfaceRefV4[]
    selected_pairs = Set{Tuple{String,Int}}()
    for declared in declaration.interfaces
        haskey(edge_by_id, declared.edge_id) ||
            throw(ArgumentError("declared interface edge is absent from current G2 graph"))
        edge_position = edge_by_id[declared.edge_id]
        edge = graph.hyperedges[edge_position]
        typeof(edge) === AtomicMIMOHyperedgeV1 ||
            throw(ArgumentError("3-D interface must bind an AtomicMIMOHyperedgeV1"))
        edge.role === interface || throw(ArgumentError("selected G2 edge is not an interface"))
        ledger_hash = canonical_hash(declared.ledger_identity)
        pairs = Tuple((i, pair) for (i, pair) in enumerate(edge.interface_flux_pairs)
            if canonical_hash(pair.minus.account_ref.ledger_identity) == ledger_hash &&
               canonical_hash(pair.plus.account_ref.ledger_identity) == ledger_hash)
        length(pairs) == 1 ||
            throw(ArgumentError("declared interface ledger is absent from or ambiguous in edge pairs"))
        pair_position, pair = only(pairs)
        key = (edge.edge_id, pair_position)
        key in selected_pairs && throw(ArgumentError("interface pair has multiple declarations"))
        push!(selected_pairs, key)
        minus_region = region_by_id[declared.minus_region_id]
        plus_region = region_by_id[declared.plus_region_id]
        minus_node_position = _tdoi_output_node(edge,
            pair.minus.account_ref.port_index)
        plus_node_position = _tdoi_output_node(edge,
            pair.plus.account_ref.port_index)
        minus_node_hash = graph_binding.node_identity_hashes[minus_node_position]
        plus_node_hash = graph_binding.node_identity_hashes[plus_node_position]
        minus_node_hash == minus_region.state_node_identity_hash &&
            plus_node_hash == plus_region.state_node_identity_hash ||
            throw(ArgumentError("declared interface orientation differs from G2 pair endpoints"))
        pair.minus.account_ref.direction === :minus &&
            pair.plus.account_ref.direction === :plus &&
            pair.minus.coefficient < 0 && pair.plus.coefficient > 0 &&
            pair.minus.coefficient == -pair.plus.coefficient ||
            throw(ArgumentError("G2 interface pair is not exact oriented conservation"))
        minus_region.state_type == plus_region.state_type ||
            throw(ArgumentError("interface endpoint state types differ"))
        declared.ledger_identity.unit == minus_region.state_type.units ||
            throw(ArgumentError("interface ledger unit differs from endpoint state units"))
        declared.minus_trace_space.physical_type == minus_region.state_type &&
            declared.plus_trace_space.physical_type == plus_region.state_type &&
            declared.multiplier_space.physical_type == minus_region.state_type ||
            throw(ArgumentError("interface discrete-space physical type mismatch"))
        declared.minus_trace_space.support_ref ==
            minus_region.volume_space.support_ref ||
            throw(ArgumentError("minus trace support differs from minus region support"))
        declared.plus_trace_space.support_ref ==
            plus_region.volume_space.support_ref ||
            throw(ArgumentError("plus trace support differs from plus region support"))
        minus_trace_support_hash = _tdoi_support_identity_hash(candidate,
            declared.minus_trace_space.support_ref, "minus trace")
        plus_trace_support_hash = _tdoi_support_identity_hash(candidate,
            declared.plus_trace_space.support_ref, "plus trace")
        interface_support_hash = _tdoi_support_identity_hash(candidate,
            declared.multiplier_space.support_ref, "interface multiplier")
        minus_trace_support_hash == minus_region.support_identity_hash ||
            throw(ArgumentError("minus trace support identity differs from minus region"))
        plus_trace_support_hash == plus_region.support_identity_hash ||
            throw(ArgumentError("plus trace support identity differs from plus region"))
        ast_roots = _tdoi_edge_root_hashes(graph_binding, edge_position)
        body = (revision=_TDOI_REVISION, interface_id=declared.interface_id,
            edge_identity_hash=graph_binding.hyperedge_identity_hashes[edge_position],
            operator_program_hash=edge.program_hash,
            ast_root_identity_hashes=ast_roots, pair_position=pair_position,
            pair_hash=canonical_hash(pair),
            interface_support_identity_hash=interface_support_hash,
            minus_region_ref_hash=minus_region.ref_hash,
            plus_region_ref_hash=plus_region.ref_hash,
            minus_state_node_identity_hash=minus_node_hash,
            plus_state_node_identity_hash=plus_node_hash,
            ledger_identity=declared.ledger_identity,
            minus_coefficient=pair.minus.coefficient,
            plus_coefficient=pair.plus.coefficient,
            minus_trace_space=declared.minus_trace_space,
            plus_trace_space=declared.plus_trace_space,
            multiplier_space=declared.multiplier_space)
        push!(interface_refs, ThreeDOrientedInterfaceRefV4(_TDOI_TOKEN,
            body.interface_id, body.edge_identity_hash,
            body.operator_program_hash, body.ast_root_identity_hashes,
            body.pair_position, body.pair_hash,
            body.interface_support_identity_hash, body.minus_region_ref_hash,
            body.plus_region_ref_hash, body.minus_state_node_identity_hash,
            body.plus_state_node_identity_hash, body.ledger_identity,
            body.minus_coefficient, body.plus_coefficient,
            body.minus_trace_space, body.plus_trace_space,
            body.multiplier_space, canonical_hash(body)))
    end
    expected_pairs = Set{Tuple{String,Int}}()
    for edge in graph.hyperedges
        if typeof(edge) === AtomicMIMOHyperedgeV1 && edge.role === interface
            for i in eachindex(edge.interface_flux_pairs)
                push!(expected_pairs, (edge.edge_id, i))
            end
        end
    end
    selected_pairs == expected_pairs ||
        throw(ArgumentError("declarations must exactly cover current G2 interface pairs"))
    Tuple(region_refs), Tuple(interface_refs)
end

function _tdoi_binding_body(declaration_hash, genome_hash, graph_hash,
        graph_binding_hash, region_ref_hashes, interface_ref_hashes,
        mission_hash, bounds_hash, scenario_hash)
    (revision=_TDOI_REVISION,
     binding_kind=:three_d_oriented_interface_subject_binding,
     declaration_hash=declaration_hash,
     field_geometry_genome_hash=genome_hash,
     field_geometry_graph_hash=graph_hash,
     field_geometry_graph_binding_hash=graph_binding_hash,
     region_ref_hashes=region_ref_hashes,
     interface_ref_hashes=interface_ref_hashes,
     mission_hash=mission_hash, bounds_hash=bounds_hash,
     scenario_hash=scenario_hash)
end

struct ThreeDOrientedInterfaceBindingV4
    declaration_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    region_ref_hashes::Tuple{Vararg{Digest256}}
    interface_ref_hashes::Tuple{Vararg{Digest256}}
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    binding_hash::Digest256
    function ThreeDOrientedInterfaceBindingV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private interface binding constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDOrientedInterfaceBindingV4) = merge(
    _tdoi_binding_body(x.declaration_hash, x.field_geometry_genome_hash,
        x.field_geometry_graph_hash, x.field_geometry_graph_binding_hash,
        x.region_ref_hashes, x.interface_ref_hashes, x.mission_hash,
        x.bounds_hash, x.scenario_hash), (binding_hash=x.binding_hash,))
function canonical_hash(x::ThreeDOrientedInterfaceBindingV4)
    expected = canonical_hash(_tdoi_binding_body(x.declaration_hash,
        x.field_geometry_genome_hash, x.field_geometry_graph_hash,
        x.field_geometry_graph_binding_hash, x.region_ref_hashes,
        x.interface_ref_hashes, x.mission_hash, x.bounds_hash,
        x.scenario_hash))
    expected == x.binding_hash || throw(ArgumentError("interface subject binding hash mismatch"))
    expected
end

function make_three_d_oriented_interface_binding(
        compiled::CompiledCandidatePrefixV4,
        registry::GenomeContractRegistryV4, mission_payload, bounds_payload,
        comparison_scope, scenario_scope, scenario,
        declaration::ThreeDOrientedInterfaceDeclarationSetV4)
    comparison = _runtime_axis_tuple(comparison_scope, "comparison_scope")
    scenarios = _runtime_axis_tuple(scenario_scope, "scenario_scope")
    _runtime_validate_compiled_prefix(compiled, compiled.candidate, registry,
        mission_payload, bounds_payload, comparison, scenarios)
    is_canonical_value(scenario) || throw(ArgumentError("binding scenario is not canonicalizable"))
    _forward_scenario_name(scenario) in scenarios ||
        throw(ArgumentError("binding scenario is outside frozen scope"))
    graph = _make_forward_graph_binding(:field_geometry, compiled.field_geometry_graph)
    regions, interfaces = _tdoi_compile_declaration(compiled.candidate, graph, declaration)
    genome_hash = field_geometry_hash(compiled.candidate.field_geometry_genome_ref)
    graph_hash = canonical_hash(compiled.field_geometry_graph)
    graph_binding_hash = canonical_hash(graph)
    region_hashes = Tuple(x.ref_hash for x in regions)
    interface_hashes = Tuple(x.ref_hash for x in interfaces)
    mission_hash = _runtime_decl_hash(mission_payload)
    bounds_hash = _runtime_decl_hash(bounds_payload)
    scenario_hash = canonical_hash(scenario)
    body = _tdoi_binding_body(canonical_hash(declaration), genome_hash,
        graph_hash, graph_binding_hash, region_hashes, interface_hashes,
        mission_hash, bounds_hash, scenario_hash)
    ThreeDOrientedInterfaceBindingV4(_TDOI_TOKEN,
        canonical_hash(declaration), genome_hash, graph_hash,
        graph_binding_hash, region_hashes, interface_hashes, mission_hash,
        bounds_hash, scenario_hash, canonical_hash(body))
end

function _tdoi_input_body(context, binding, regions, interfaces)
    (revision=_TDOI_REVISION, schema=_TDOI_SCHEMA,
     context_hash=context.context_hash, candidate_hash=context.candidate_hash,
     compiled_prefix_hash=context.compiled.prefix_hash,
     physical_subject_hash=context.subject.physical_subject_hash,
     mission_hash=_runtime_decl_hash(context.mission_payload),
     bounds_hash=_runtime_decl_hash(context.bounds_payload),
     scenario_hash=context.scenario_hash,
     field_geometry_genome_hash=binding.field_geometry_genome_hash,
     field_geometry_graph_hash=binding.field_geometry_graph_hash,
     field_geometry_graph_binding_hash=binding.field_geometry_graph_binding_hash,
     declaration_hash=binding.declaration_hash,
     binding_hash=binding.binding_hash, regions=regions,
     interfaces=interfaces, model_class=:manufactured_input_fixture,
     claim_ceiling=screen_only, provider_selected=false,
     solver_executed=false, emits_evidence=false,
     p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDOrientedInterfaceInputV4
    context_hash::Digest256
    candidate_hash::Digest256
    compiled_prefix_hash::Digest256
    physical_subject_hash::Digest256
    mission_hash::Digest256
    bounds_hash::Digest256
    scenario_hash::Digest256
    field_geometry_genome_hash::Digest256
    field_geometry_graph_hash::Digest256
    field_geometry_graph_binding_hash::Digest256
    declaration_hash::Digest256
    binding_hash::Digest256
    regions::Tuple{Vararg{ThreeDRegionSpaceRefV4}}
    interfaces::Tuple{Vararg{ThreeDOrientedInterfaceRefV4}}
    model_class::Symbol
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    input_hash::Digest256
    function ThreeDOrientedInterfaceInputV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private interface input constructor"))
        new(fields...)
    end
end

function _tdoi_make_input(context, binding, regions, interfaces)
    body = _tdoi_input_body(context, binding, regions, interfaces)
    ThreeDOrientedInterfaceInputV4(_TDOI_TOKEN,
        body.context_hash, body.candidate_hash, body.compiled_prefix_hash,
        body.physical_subject_hash, body.mission_hash, body.bounds_hash,
        body.scenario_hash, body.field_geometry_genome_hash,
        body.field_geometry_graph_hash, body.field_geometry_graph_binding_hash,
        body.declaration_hash, body.binding_hash, body.regions,
        body.interfaces, body.model_class, body.claim_ceiling,
        body.provider_selected, body.solver_executed, body.emits_evidence,
        body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

function semantic_view(x::ThreeDOrientedInterfaceInputV4)
    body = (revision=_TDOI_REVISION, schema=_TDOI_SCHEMA,
        context_hash=x.context_hash, candidate_hash=x.candidate_hash,
        compiled_prefix_hash=x.compiled_prefix_hash,
        physical_subject_hash=x.physical_subject_hash,
        mission_hash=x.mission_hash, bounds_hash=x.bounds_hash,
        scenario_hash=x.scenario_hash,
        field_geometry_genome_hash=x.field_geometry_genome_hash,
        field_geometry_graph_hash=x.field_geometry_graph_hash,
        field_geometry_graph_binding_hash=x.field_geometry_graph_binding_hash,
        declaration_hash=x.declaration_hash, binding_hash=x.binding_hash,
        regions=x.regions, interfaces=x.interfaces,
        model_class=x.model_class, claim_ceiling=x.claim_ceiling,
        provider_selected=x.provider_selected, solver_executed=x.solver_executed,
        emits_evidence=x.emits_evidence, p5_ready=x.p5_ready,
        terminal_authority=x.terminal_authority,
        credible_physical_device_count=x.credible_physical_device_count)
    merge(body, (input_hash=x.input_hash,))
end
function canonical_hash(x::ThreeDOrientedInterfaceInputV4)
    view = semantic_view(x)
    body = NamedTuple{keys(view)[1:end-1]}(values(view)[1:end-1])
    expected = canonical_hash(body)
    expected == x.input_hash || throw(ArgumentError("oriented interface input hash mismatch"))
    x.model_class === :manufactured_input_fixture &&
        x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("oriented interface input authority ceiling was exceeded"))
    expected
end

function _tdoi_context_input(context::ForwardChainContextV4,
        declaration::ThreeDOrientedInterfaceDeclarationSetV4,
        binding::ThreeDOrientedInterfaceBindingV4)
    canonical_hash(binding)
    graph = forward_graph_binding(context, :field_geometry)
    regions, interfaces = _tdoi_compile_declaration(context.candidate, graph, declaration)
    binding.declaration_hash == canonical_hash(declaration) ||
        throw(ArgumentError("interface binding declaration hash is foreign"))
    binding.field_geometry_genome_hash ==
        field_geometry_hash(context.candidate.field_geometry_genome_ref) ||
        throw(ArgumentError("interface binding G2 Genome hash is foreign"))
    binding.field_geometry_graph_hash == canonical_hash(context.compiled.field_geometry_graph) ||
        throw(ArgumentError("interface binding G2 graph hash is foreign"))
    binding.field_geometry_graph_binding_hash == canonical_hash(graph) ||
        throw(ArgumentError("interface binding G2 graph identity is foreign"))
    binding.region_ref_hashes == Tuple(x.ref_hash for x in regions) ||
        throw(ArgumentError("interface binding region identities are foreign"))
    binding.interface_ref_hashes == Tuple(x.ref_hash for x in interfaces) ||
        throw(ArgumentError("interface binding operator identities are foreign"))
    binding.mission_hash == _runtime_decl_hash(context.mission_payload) ||
        throw(ArgumentError("interface binding mission hash is foreign"))
    binding.bounds_hash == _runtime_decl_hash(context.bounds_payload) ||
        throw(ArgumentError("interface binding bounds hash is foreign"))
    binding.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("interface binding scenario hash is foreign"))
    _tdoi_make_input(context, binding, regions, interfaces)
end

function validate_three_d_oriented_interface_input(context::ForwardChainContextV4,
        input::ThreeDOrientedInterfaceInputV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDOrientedInterfaceBindingV4)
    length(declarations) == 1 && length(bindings) == 1 ||
        throw(ArgumentError("current context lacks one exact interface declaration/binding"))
    expected = _tdoi_context_input(context, only(declarations), only(bindings))
    canonical_hash(input) == canonical_hash(expected) &&
        semantic_view(input) == semantic_view(expected) ||
        throw(ArgumentError("oriented interface input differs from current context"))
    input.input_hash
end

function _tdoi_resolution_body(context_hash, status, input, gaps)
    (revision=_TDOI_REVISION, kind=:three_d_oriented_interface_input_resolution,
     context_hash=context_hash, status=status,
     input_hash=input === nothing ? nothing : canonical_hash(input),
     recoverable_gaps=gaps, claim_ceiling=screen_only,
     provider_selected=false, solver_executed=false,
     emits_evidence=false, p5_ready=false, terminal_authority=false,
     credible_physical_device_count=0)
end

struct ThreeDOrientedInterfaceResolutionV4
    context_hash::Digest256
    status::Symbol
    input::Union{Nothing,ThreeDOrientedInterfaceInputV4}
    recoverable_gaps::Tuple{Vararg{String}}
    claim_ceiling::ClaimCeiling
    provider_selected::Bool
    solver_executed::Bool
    emits_evidence::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    resolution_hash::Digest256
    function ThreeDOrientedInterfaceResolutionV4(
            token::Val{:three_d_oriented_interface_input_private}, fields...)
        token === _TDOI_TOKEN || throw(ArgumentError("private interface resolution constructor"))
        new(fields...)
    end
end
semantic_view(x::ThreeDOrientedInterfaceResolutionV4) = merge(
    _tdoi_resolution_body(x.context_hash, x.status, x.input,
        x.recoverable_gaps), (resolution_hash=x.resolution_hash,))
function canonical_hash(x::ThreeDOrientedInterfaceResolutionV4)
    x.status in (:input_complete, :recoverable_gap) ||
        throw(ArgumentError("invalid oriented interface resolution status"))
    (x.status === :input_complete) == (x.input !== nothing) ||
        throw(ArgumentError("oriented interface resolution payload mismatch"))
    x.status === :input_complete ? isempty(x.recoverable_gaps) :
        !isempty(x.recoverable_gaps) || throw(ArgumentError("gap resolution requires exact gaps"))
    expected = canonical_hash(_tdoi_resolution_body(x.context_hash,
        x.status, x.input, x.recoverable_gaps))
    expected == x.resolution_hash || throw(ArgumentError("interface resolution hash mismatch"))
    x.claim_ceiling == screen_only && !x.provider_selected &&
        !x.solver_executed && !x.emits_evidence && !x.p5_ready &&
        !x.terminal_authority && x.credible_physical_device_count == 0 ||
        throw(ArgumentError("interface resolution authority ceiling was exceeded"))
    expected
end

function _tdoi_resolution(context_hash, input, gaps)
    gs = Tuple(String(x) for x in gaps)
    status = input === nothing ? :recoverable_gap : :input_complete
    status === :input_complete && !isempty(gs) && throw(ArgumentError("complete input cannot contain gaps"))
    status === :recoverable_gap && isempty(gs) && throw(ArgumentError("gap resolution requires a reason"))
    body = _tdoi_resolution_body(context_hash, status, input, gs)
    ThreeDOrientedInterfaceResolutionV4(_TDOI_TOKEN, context_hash, status,
        input, gs, screen_only, false, false, false, false, false, 0,
        canonical_hash(body))
end

function resolve_three_d_oriented_interface_input(context::ForwardChainContextV4)
    validate_forward_chain_context(context)
    declarations = Tuple(x for x in context.candidate.field_geometry_genome_ref.fields
        if typeof(x) === ThreeDOrientedInterfaceDeclarationSetV4)
    bindings = Tuple(x for x in context.subject.bindings
        if typeof(x) === ThreeDOrientedInterfaceBindingV4)
    gaps = String[]
    isempty(declarations) ? push!(gaps, _TDOI_REQUIRED_GAPS[1]) :
        length(declarations) == 1 || push!(gaps, "ambiguous_typed_three_d_oriented_interface_discrete_spaces")
    isempty(bindings) ? push!(gaps, _TDOI_REQUIRED_GAPS[2]) :
        length(bindings) == 1 || push!(gaps, "ambiguous_three_d_oriented_interface_subject_binding")
    isempty(gaps) || return _tdoi_resolution(context.context_hash, nothing, Tuple(gaps))
    input = _tdoi_context_input(context, only(declarations), only(bindings))
    validate_three_d_oriented_interface_input(context, input)
    _tdoi_resolution(context.context_hash, input, ())
end

three_d_oriented_interface_input_manifest() = (
    schema=_TDOI_SCHEMA, revision=_TDOI_REVISION,
    purpose=:typed_oriented_three_d_interface_and_discrete_space_input,
    statuses=(:input_complete, :recoverable_gap),
    model_class=:manufactured_input_fixture, claim_ceiling=screen_only,
    provider_selected=false, solver_executed=false,
    emits_evidence=false, physical_validation=false,
    engineering_validation=false, terminal_authority=false,
    p5_ready=false, credible_physical_device_count=0)
