using Test
using FusionConceptAI

helper_source = read(joinpath(@__DIR__, "mechanism_hash_layers_tests.jl"), String)
include_string(Main, first(split(helper_source, "@testset")), "mechanism_hash_layers_tests.jl")

_scope_hash_tuple(h) = ntuple(i -> getfield(h, i), fieldcount(typeof(h)))
struct ScopeRogueV1 <: ConservationInvariantScopeV1 end

function _scope_owned(payload, ledger, state_id::Union{Nothing,String}=nothing, site_id::Union{Nothing,String}=nothing)
    nodes = Dict(i => n.node_id for (i, n) in enumerate(payload.operator_graph.nodes))
    items = FusionConceptAI._g1_payload_graph_occurrences(payload.operator_graph)
    Tuple(item.ref for item in items if
        FusionConceptAI._ledger_identity_full_key(item.ref.ledger_identity) == FusionConceptAI._ledger_identity_full_key(ledger) &&
        (state_id === nothing || get(nodes, item.graph_node_index, nothing) == state_id) &&
        (site_id === nothing || item.ref.operator_site_ref.value == site_id))
end

@testset "typed conservation scope constructors and canonical identity" begin
    state_a = StateGeneRefV1("state-a")
    state_b = StateGeneRefV1("state-b")
    global_scope = GlobalConservationScopeV1()
    domain_scope = DomainConservationScopeV1((state_b, state_a))
    @test global_scope isa ConservationInvariantScopeV1
    @test domain_scope.state_refs == (state_a, state_b)
    @test DomainConservationScopeV1((state_a, state_b)) == domain_scope
    @test InterfaceConservationScopeV1(OperatorSiteRefV1("interface-a")) isa ConservationInvariantScopeV1
    @test_throws ArgumentError DomainConservationScopeV1(())
    @test_throws ArgumentError DomainConservationScopeV1((state_a, state_a))
    @test_throws ArgumentError DomainConservationScopeV1(("state-a",))
    @test_throws ArgumentError InterfaceConservationScopeV1("interface-a")
    @test_throws ArgumentError GlobalConservationScopeV1(:unexpected)
    @test_throws MethodError InvariantV1(InvariantRefV1("old"),
        ConservationLedgerIdentityV1(QualifiedRefV1("ledger", "v1"), Digest256(repeat("0", 64)), UnitSignature()),
        global_scope, nothing, (), (), (), (), 0, entropy_conserved)
    @test_throws ArgumentError InvariantV1(InvariantRefV1("rogue"), ConservationLedgerIdentityV1(QualifiedRefV1("ledger", "v1"), Digest256(repeat("0", 64)), UnitSignature()), ScopeRogueV1(), (InvariantTermV1(state_a, 1),), tuple(()..., ()..., ()...), 0, entropy_conserved)
    @test !isdefined(FusionConceptAI, :InvariantScopeV1)
    @test !isdefined(FusionConceptAI, :scope_global)
end

@testset "scope alpha renames are synchronized graph closures" begin
    base_payload, base_context = _hash_fixture()
    base_invariant = base_payload.invariants[1]
    base_domain_invariant = InvariantV1(base_invariant.invariant_ref, base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"),)), base_invariant.terms, _scope_owned(base_payload, base_invariant.ledger_identity, "state-a"), 0, entropy_conserved)
    base_domain_b = InvariantV1(InvariantRefV1("domain-b"), base_invariant.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-b"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), _scope_owned(base_payload, base_invariant.ledger_identity, "state-b"), 0, entropy_conserved)
    base_domain = MechanismGenomePayloadV1(base_payload.states, (base_domain_invariant, base_domain_b, base_payload.invariants[2:end]...),
        base_payload.operator_graph, base_payload.parameters, base_payload.symmetries,
        base_payload.observables, base_payload.operator_holes)
    renamed_payload, renamed_context = _hash_fixture(prefix="renamed-")
    renamed_base = renamed_payload.invariants[1]
    renamed_domain_invariant = InvariantV1(renamed_base.invariant_ref, renamed_base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("renamed-state-a"),)), renamed_base.terms, _scope_owned(renamed_payload, renamed_base.ledger_identity, "renamed-state-a"), 0, entropy_conserved)
    renamed_domain_b = InvariantV1(InvariantRefV1("renamed-domain-b"), renamed_base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("renamed-state-b"),)), (InvariantTermV1(StateGeneRefV1("renamed-state-b"), 1),), _scope_owned(renamed_payload, renamed_base.ledger_identity, "renamed-state-b"), 0, entropy_conserved)
    renamed_domain = MechanismGenomePayloadV1(renamed_payload.states, (renamed_domain_invariant, renamed_domain_b, renamed_payload.invariants[2:end]...),
        renamed_payload.operator_graph, renamed_payload.parameters, renamed_payload.symmetries,
        renamed_payload.observables, renamed_payload.operator_holes)
    @test _scope_hash_tuple(mechanism_hash_layers(base_domain, base_context)) ==
        _scope_hash_tuple(mechanism_hash_layers(renamed_domain, renamed_context))

    base_edge = base_payload.operator_graph.hyperedges[1]
    base_flux = base_edge.interface_flux_pairs[1].minus.account_ref.ledger_identity
    base_interface_invariant = InvariantV1(InvariantRefV1("interface-alpha"), base_flux, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-a")), base_invariant.terms, _scope_owned(base_payload, base_flux, nothing, "interface-a"), 0, entropy_conserved)
    base_interface_b = InvariantV1(InvariantRefV1("interface-beta"), base_flux, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-b")), base_invariant.terms, _scope_owned(base_payload, base_flux, nothing, "interface-b"), 0, entropy_conserved)
    base_interface = MechanismGenomePayloadV1(base_payload.states, (base_payload.invariants[1], base_interface_invariant, base_interface_b),
        base_payload.operator_graph, base_payload.parameters, base_payload.symmetries,
        base_payload.observables, base_payload.operator_holes)
    renamed_edge = renamed_payload.operator_graph.hyperedges[1]
    renamed_flux = renamed_edge.interface_flux_pairs[1].minus.account_ref.ledger_identity
    renamed_interface_invariant = InvariantV1(InvariantRefV1("renamed-interface-alpha"), renamed_flux, InterfaceConservationScopeV1(OperatorSiteRefV1("renamed-interface-a")), renamed_base.terms, _scope_owned(renamed_payload, renamed_flux, nothing, "renamed-interface-a"), 0, entropy_conserved)
    renamed_interface_b = InvariantV1(InvariantRefV1("renamed-interface-beta"), renamed_flux, InterfaceConservationScopeV1(OperatorSiteRefV1("renamed-interface-b")), renamed_base.terms, _scope_owned(renamed_payload, renamed_flux, nothing, "renamed-interface-b"), 0, entropy_conserved)
    renamed_interface = MechanismGenomePayloadV1(renamed_payload.states, (renamed_payload.invariants[1], renamed_interface_invariant, renamed_interface_b),
        renamed_payload.operator_graph, renamed_payload.parameters, renamed_payload.symmetries,
        renamed_payload.observables, renamed_payload.operator_holes)
    @test _scope_hash_tuple(mechanism_hash_layers(base_interface, base_context)) ==
        _scope_hash_tuple(mechanism_hash_layers(renamed_interface, renamed_context))
end

@testset "scope payload closure and layer boundaries" begin
    payload, context = _hash_fixture()
    base = payload.invariants[1]
    domain = InvariantV1(base.invariant_ref, base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"),)), base.terms, _scope_owned(payload, base.ledger_identity, "state-a"), base.tolerance_log10, base.entropy_direction)
    domain_b = InvariantV1(InvariantRefV1("domain-b"), base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-b"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), _scope_owned(payload, base.ledger_identity, "state-b"), 0, entropy_conserved)
    domain_payload = MechanismGenomePayloadV1(payload.states, (domain, domain_b, payload.invariants[2:end]...), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    @test domain_payload.invariants[1].scope isa DomainConservationScopeV1
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(base.invariant_ref, base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), tuple(base.owned_ledger_occurrence_refs..., ()..., ()...), base.tolerance_log10, base.entropy_direction),), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    interface_edge = payload.operator_graph.hyperedges[1]
    flux_identity = interface_edge.interface_flux_pairs[1].minus.account_ref.ledger_identity
    interface = InvariantV1(InvariantRefV1("interface-invariant"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1(interface_edge.edge_id)), base.terms, _scope_owned(payload, flux_identity, nothing, interface_edge.edge_id), 0, entropy_conserved)
    interface_b = InvariantV1(InvariantRefV1("interface-invariant-b"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-b")), base.terms, _scope_owned(payload, flux_identity, nothing, "interface-b"), 0, entropy_conserved)
    interface_payload = MechanismGenomePayloadV1(payload.states, (interface, interface_b, base), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    @test interface_payload.invariants[1].scope isa InterfaceConservationScopeV1
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(InvariantRefV1("wrong-interface"), base.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("additive")), base.terms, tuple(()..., ()..., ()...), 0, entropy_conserved),), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(InvariantRefV1("dangling-domain"), base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("missing-state"),)), base.terms, tuple(()..., ()..., ()...), 0, entropy_conserved),), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    nonstate_graph = TypedOperatorHypergraphV1((payload.operator_graph.nodes...,
        node(:parameter, payload.states[1].physical_type; id="nonstate")),
        payload.operator_graph.hyperedges; registry=default_operator_registry())
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(InvariantRefV1("nonstate-domain"), base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("nonstate"),)), base.terms, tuple(()..., ()..., ()...), 0, entropy_conserved),), nonstate_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(InvariantRefV1("dangling-interface"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("missing-edge")), base.terms, tuple(()..., ()..., ()...), 0, entropy_conserved),), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    @test_throws ArgumentError MechanismGenomePayloadV1(payload.states,
        (InvariantV1(InvariantRefV1("wrong-ledger-interface"), base.ledger_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-a")), base.terms, tuple(()..., ()..., ()...), 0, entropy_conserved),), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)

    # A domain member is a structural relation, while a local alpha rename is not.
    domain_all = InvariantV1(base.invariant_ref, base.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-a"), StateGeneRefV1("state-b"))), base.terms, tuple(base.owned_ledger_occurrence_refs..., ()..., ()...), base.tolerance_log10, base.entropy_direction)
    all_payload = MechanismGenomePayloadV1(payload.states, (domain_all, payload.invariants[2:end]...), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    all_hashes = mechanism_hash_layers(all_payload, context)
    one_hashes = mechanism_hash_layers(domain_payload, context)
    @test all_hashes.topology_hash == one_hashes.topology_hash
    @test all_hashes.operator_program_hash == one_hashes.operator_program_hash
    @test all_hashes.mechanism_structure_hash != one_hashes.mechanism_structure_hash
    @test all_hashes.decorated_mechanism_hash != one_hashes.decorated_mechanism_hash
    @test all_hashes.candidate_subject_hash != one_hashes.candidate_subject_hash

    renamed_state = StateGeneV1(StateGeneRefV1("state-a"), payload.states[1].physical_type,
        payload.states[1].physical_bounds, payload.states[1].parity_actions,
        (SymmetryRefV1("sym-renamed"),), payload.states[1].constraint_refs,
        payload.states[1].epistemic_state)
    renamed_symmetry = SymmetryGeneV1(SymmetryRefV1("sym-renamed"),
        payload.symmetries[1].generator_ref, payload.symmetries[1].group_kind,
        payload.symmetries[1].coordinate_generator_matrix, payload.symmetries[1].state_actions,
        payload.symmetries[1].group_order, payload.symmetries[1].behavior,
        payload.symmetries[1].tolerance)
    renamed_payload = MechanismGenomePayloadV1((renamed_state, payload.states[2]), (domain, domain_b, payload.invariants[2:end]...),
        payload.operator_graph, payload.parameters, (renamed_symmetry,), payload.observables,
        payload.operator_holes)
    renamed_hashes = mechanism_hash_layers(renamed_payload, context)
    @test _scope_hash_tuple(renamed_hashes) == _scope_hash_tuple(mechanism_hash_layers(domain_payload, context))

    interface_a = InvariantV1(InvariantRefV1("interface-invariant"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-a")), base.terms, _scope_owned(payload, flux_identity, nothing, "interface-a"), 0, entropy_conserved)
    interface_b = InvariantV1(InvariantRefV1("interface-invariant-b"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-b")), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), _scope_owned(payload, flux_identity, nothing, "interface-b"), 0, entropy_conserved)
    interface_a_payload = MechanismGenomePayloadV1(payload.states, (base, interface_a, interface_b), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    interface_b_alt = InvariantV1(InvariantRefV1("interface-invariant-b-alt"), flux_identity, InterfaceConservationScopeV1(OperatorSiteRefV1("interface-b")), base.terms, _scope_owned(payload, flux_identity, nothing, "interface-b"), 0, entropy_conserved)
    interface_b_payload = MechanismGenomePayloadV1(payload.states, (base, interface_a, interface_b_alt), payload.operator_graph,
        payload.parameters, payload.symmetries, payload.observables, payload.operator_holes)
    interface_a_hashes = mechanism_hash_layers(interface_a_payload, context)
    interface_b_hashes = mechanism_hash_layers(interface_b_payload, context)
    @test interface_a_hashes.topology_hash == interface_b_hashes.topology_hash
    @test interface_a_hashes.operator_program_hash == interface_b_hashes.operator_program_hash
    @test interface_a_hashes.mechanism_structure_hash != interface_b_hashes.mechanism_structure_hash
    @test interface_a_hashes.decorated_mechanism_hash != interface_b_hashes.decorated_mechanism_hash
    @test interface_a_hashes.candidate_subject_hash != interface_b_hashes.candidate_subject_hash

    rebound, rebound_context = _hash_fixture(ledger_account="rebound-ledger")
    rebound_hashes = mechanism_hash_layers(rebound, rebound_context)
    base_hashes = mechanism_hash_layers(payload, context)
    @test rebound_hashes.topology_hash == base_hashes.topology_hash
    @test rebound_hashes.operator_program_hash == base_hashes.operator_program_hash
    @test rebound_hashes.mechanism_structure_hash != base_hashes.mechanism_structure_hash
    @test rebound_hashes.decorated_mechanism_hash != base_hashes.decorated_mechanism_hash
    @test rebound_hashes.candidate_subject_hash != base_hashes.candidate_subject_hash
    global_hashes = mechanism_hash_layers(payload, context)
    domain_hashes = mechanism_hash_layers(domain_payload, context)
    @test domain_hashes.topology_hash == global_hashes.topology_hash
    @test domain_hashes.operator_program_hash == global_hashes.operator_program_hash
    @test domain_hashes.mechanism_structure_hash != global_hashes.mechanism_structure_hash
    @test domain_hashes.decorated_mechanism_hash != global_hashes.decorated_mechanism_hash
    @test domain_hashes.candidate_subject_hash != global_hashes.candidate_subject_hash
end
