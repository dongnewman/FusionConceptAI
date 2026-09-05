using Test
using FusionConceptAI

# This fixture deliberately uses a capability-complete operator manifest.  It is
# an open-topology ledger fixture, not a device-family fixture: the ownership
# contract is exercised independently of any particular physical machine.
const LO_UNIT = UnitSignature()
const LO_TYPE = PhysicalType(:scalar_field, 0, 0, TemporalTypeV1(static_time), LO_UNIT)
const LO_BOUNDS = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), LO_UNIT)

function _lo_registry()
    manifest = OperatorManifestV1(OperatorRefV1("OPEN", "v1"), 1, 1,
        SameTypeVariadicRuleV1(1, 1), SameTypeVariadicRuleV1(1, 1);
        allowed_roles=(:governing, :additive, :interface, :boundary, :source, :sink),
        allowed_conservation_effects=(:redistribution, :interface_flux, :net_creation, :net_destruction))
    register_operator(default_operator_registry(), manifest)
end

function _lo_program(registry)
    a = ASTApplyV1(OperatorRefV1("OPEN", "v1"), (1,), (;);
        registry=registry, input_types=(LO_TYPE,))
    b = ASTApplyV1(OperatorRefV1("OPEN", "v1"), (2,), (;);
        registry=registry, input_types=(LO_TYPE,))
    TypedASTProgramV1((ASTInputV1(1, LO_TYPE), ASTInputV1(2, LO_TYPE), a, b),
        (3, 4), (1, 2); registry=registry)
end

_lo_ledger(name; version="v1", ontology=repeat("0", 64)) =
    ConservationLedgerIdentityV1(QualifiedRefV1(name, version), Digest256(ontology), LO_UNIT)
_lo_ref(name) = OperatorSiteRefV1(name)

function _lo_edge(id, role, ledger; registry, program)
    outputs = (MIMOOutputBindingV1(1, 1), MIMOOutputBindingV1(2, 2))
    if role === interface
        pair = InterfaceFluxPairV1(
            PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :minus), -1 // 1),
            PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 2, :plus), 1 // 1))
        return AtomicMIMOHyperedgeV1(id, (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), outputs, program, role;
            interface_flux_pairs=(pair,), registry=registry)
    elseif role === source
        effect = PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :plus), 1 // 1)
        return AtomicMIMOHyperedgeV1(id, (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), outputs, program, role;
            account_effects=(effect,), registry=registry)
    elseif role === sink
        effect = PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 2, :minus), -1 // 1)
        return AtomicMIMOHyperedgeV1(id, (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), outputs, program, role;
            account_effects=(effect,), registry=registry)
    end
    effects = (
        PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :inflow), 1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 2, :outflow), -1 // 1))
    AtomicMIMOHyperedgeV1(id, (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)), outputs, program, role;
        account_effects=effects, registry=registry)
end

_lo_occ(site, port, direction, kind, ledger) =
    ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1(site), :output, port, direction, kind, ledger)

function _lo_fixture(; prefix="", ledger_prefix=prefix, external_prefix=prefix, reverse=false, interface_target="interface-a",
                     duplicate_same_scope=false, interface_pair_reverse=false)
    registry = _lo_registry()
    program = _lo_program(registry)
    energy = _lo_ledger(ledger_prefix * "energy")
    birth = _lo_ledger(ledger_prefix * "birth")
    loss = _lo_ledger(ledger_prefix * "loss")
    flux = _lo_ledger(ledger_prefix * "flux")
    edges = (
        _lo_edge(prefix * "internal", additive, energy; registry, program),
        _lo_edge(prefix * "boundary", boundary, energy; registry, program),
        _lo_edge(prefix * "source", source, birth; registry, program),
        _lo_edge(prefix * "sink", sink, loss; registry, program),
        _lo_edge(prefix * "interface-a", interface, flux; registry, program),
        _lo_edge(prefix * "interface-b", interface, flux; registry, program))
    nodes = (node(:state, LO_TYPE; id=prefix * "state-a"),
        node(:state, LO_TYPE; id=prefix * "state-b"))
    graph = TypedOperatorHypergraphV1(nodes, reverse ? Base.reverse(edges) : edges; registry=registry)
    state_a = StateGeneV1(StateGeneRefV1(prefix * "state-a"), LO_TYPE, LO_BOUNDS, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1(prefix * "state-b"), LO_TYPE, LO_BOUNDS, (), (), (), state_derived)
    term_a = (InvariantTermV1(StateGeneRefV1(prefix * "state-a"), 1),)
    term_b = (InvariantTermV1(StateGeneRefV1(prefix * "state-b"), 1),)
    energy_global_refs = (_lo_occ(prefix * "internal", 1, :inflow, occurrence_internal_effect, energy),
        _lo_occ(prefix * "internal", 2, :outflow, occurrence_internal_effect, energy),
        _lo_occ(prefix * "boundary", 1, :inflow, occurrence_boundary_effect, energy),
        _lo_occ(prefix * "boundary", 2, :outflow, occurrence_boundary_effect, energy))
    energy_domain_refs = (_lo_occ(prefix * "internal", 1, :inflow, occurrence_internal_effect, energy),
        _lo_occ(prefix * "boundary", 1, :inflow, occurrence_boundary_effect, energy))
    birth_refs = (_lo_occ(prefix * "source", 1, :plus, occurrence_source_effect, birth),)
    loss_refs = (_lo_occ(prefix * "sink", 2, :minus, occurrence_sink_effect, loss),)
    flux_a_refs = (_lo_occ(prefix * "interface-a", 1, :minus, occurrence_interface_minus, flux),
        _lo_occ(prefix * "interface-a", 2, :plus, occurrence_interface_plus, flux))
    flux_b_refs = (_lo_occ(prefix * "interface-b", 1, :minus, occurrence_interface_minus, flux),
        _lo_occ(prefix * "interface-b", 2, :plus, occurrence_interface_plus, flux))
    energy_global = InvariantV1(InvariantRefV1(prefix * "energy-global"), energy, GlobalConservationScopeV1(), term_a, energy_global_refs, 0, entropy_conserved)
    energy_domain = InvariantV1(InvariantRefV1(prefix * "energy-domain-a"), energy, DomainConservationScopeV1((StateGeneRefV1(prefix * "state-a"),)), term_a, energy_domain_refs, 0, entropy_conserved)
    birth_domain = InvariantV1(InvariantRefV1(prefix * "birth-domain-a"), birth, DomainConservationScopeV1((StateGeneRefV1(prefix * "state-a"),)), term_a, birth_refs, 0, entropy_conserved)
    loss_domain = InvariantV1(InvariantRefV1(prefix * "loss-domain-b"), loss, DomainConservationScopeV1((StateGeneRefV1(prefix * "state-b"),)), term_b, loss_refs, 0, entropy_conserved)
    flux_interface = InvariantV1(InvariantRefV1(prefix * "flux-interface"), flux, InterfaceConservationScopeV1(_lo_ref(prefix * interface_target)), term_a, interface_target == "interface-a" ? flux_a_refs : flux_b_refs, 0, entropy_conserved)
    flux_interface_other = InvariantV1(InvariantRefV1(prefix * "flux-interface-other"), flux, InterfaceConservationScopeV1(_lo_ref(prefix * (interface_target == "interface-a" ? "interface-b" : "interface-a"))), term_a, interface_target == "interface-a" ? flux_b_refs : flux_a_refs, 0, entropy_conserved)
    invariants = duplicate_same_scope ?
        (energy_global, energy_domain,
         InvariantV1(InvariantRefV1(prefix * "energy-global-duplicate"), energy, GlobalConservationScopeV1(), term_a, energy_global_refs, 0, entropy_conserved),
         birth_domain, loss_domain, flux_interface, flux_interface_other) :
        (energy_global, energy_domain, birth_domain, loss_domain, flux_interface, flux_interface_other)
    if reverse
        invariants = Base.reverse(invariants)
    end
    observable = ObservableGeneV1(ObservableRefV1(external_prefix * "observable"),
        ProgramRootRefV1(OperatorSiteRefV1(prefix * "internal"), 1, LO_TYPE),
        QualifiedRefV1(external_prefix * "intervention", "v1"),
        TypedASTProgramV1((ASTInputV1(1, LO_TYPE),
            ASTApplyV1(OperatorRefV1("OPEN", "v1"), (1,), (;);
                registry=registry, input_types=(LO_TYPE,))), (2,), (1,); registry=registry), LO_BOUNDS,
        QualifiedRefV1(external_prefix * "noise", "v1"), NonnegativeQuantityV1(1 // 10, LO_UNIT),
        NonnegativeQuantityV1(1 // 10, LO_UNIT), NonnegativeQuantityV1(1 // 2, LO_UNIT),
        (QualifiedRefV1(external_prefix * "prediction", "v1"),))
    payload = MechanismGenomePayloadV1((state_a, state_b), invariants, graph, (), (), (observable,), ())
    payload
end

function _lo_replace(payload; invariants=payload.invariants, edges=payload.operator_graph.hyperedges)
    graph = TypedOperatorHypergraphV1(payload.operator_graph.nodes, edges;
        registry=first(edges).registry)
    MechanismGenomePayloadV1(payload.states, invariants, graph, payload.parameters,
        payload.symmetries, payload.observables, payload.operator_holes)
end

function _lo_bad_pair()
    InterfaceFluxPairV1(
        PortAccountEffectV1(ConservationAccountRefV1(_lo_ledger("flux"), :output, 1, :minus), -1 // 1),
        PortAccountEffectV1(ConservationAccountRefV1(_lo_ledger("other"), :output, 2, :plus), 1 // 1))
end

@testset "ledger occurrence ownership: open topology" begin
    payload = _lo_fixture()
    @test payload isa MechanismGenomePayloadV1
    @test length(payload.invariants) == 6
    @test length(payload.operator_graph.hyperedges) == 6

    # One complete ledger may have repeated occurrences and may be declared by
    # invariants in different typed scopes.  This is intentionally not a
    # one-ledger-one-invariant rule.
    @test _lo_fixture(duplicate_same_scope=false) isa MechanismGenomePayloadV1
    @test mechanism_hash_layers(payload,
        MechanismCanonicalizationContextV1(
            g1_occurrence_ownership_contract_ref("urn:fusion:ledger-owner"),
            CanonicalizationProfileV1("ledger-owner", "1",
                CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000)))) isa MechanismHashLayersV1

    @test_throws ArgumentError _lo_fixture(duplicate_same_scope=true)

    # The full identity, not only the account label, is part of ownership.
    bad_identity = _lo_ledger("energy", version="v2")
    @test_throws ArgumentError InvariantV1(payload.invariants[1].invariant_ref, bad_identity,
        payload.invariants[1].scope, payload.invariants[1].terms,
        payload.invariants[1].owned_ledger_occurrence_refs, 0, entropy_conserved)

    # A source/sink/boundary/interface reference must bind the declared role
    # and ledger occurrence; omission and cross-role substitution are failures.
    inv = payload.invariants
    @test_throws ArgumentError _lo_replace(payload; invariants=(inv[1], inv[2],
        InvariantV1(inv[3].invariant_ref, inv[3].ledger_identity, inv[3].scope, inv[3].terms, (), 0, entropy_conserved), inv[4], inv[5], inv[6]))
    @test_throws ArgumentError _lo_replace(payload; invariants=(inv[1], inv[2], inv[3],
        InvariantV1(inv[4].invariant_ref, inv[4].ledger_identity, inv[4].scope, inv[4].terms, (), 0, entropy_conserved), inv[5], inv[6]))
    @test_throws ArgumentError _lo_replace(payload; invariants=(inv[1], inv[2], inv[3], inv[4],
        InvariantV1(inv[5].invariant_ref, inv[5].ledger_identity, inv[5].scope, inv[5].terms, (), 0, entropy_conserved), inv[6]))
    @test_throws ArgumentError _lo_replace(payload; invariants=(inv[1], inv[2], inv[3],
        InvariantV1(inv[4].invariant_ref, inv[4].ledger_identity, inv[4].scope, inv[4].terms, (inv[2].owned_ledger_occurrence_refs[1],), 0, entropy_conserved), inv[5], inv[6]))

    # Interface scope target is structural; changing the target or using a
    # non-interface edge is rejected even when the ledger identity is equal.
    @test_throws ArgumentError _lo_fixture(interface_target="boundary")
    @test_throws ArgumentError _lo_fixture(interface_target="missing")
end

@testset "ledger occurrence ownership: alpha, scope, and permutation boundaries" begin
    base = _lo_fixture()
    renamed = _lo_fixture(prefix="renamed-")
    contract = g1_occurrence_ownership_contract_ref("urn:fusion:ledger-alpha")
    profile = CanonicalizationProfileV1("ledger-alpha", "1",
        CanonicalizationBudgetV1(500_000, 50_000, 512, 8_000_000))
    context = MechanismCanonicalizationContextV1(contract, profile)
    first = mechanism_hash_layers(base, context)
    second = mechanism_hash_layers(renamed, context)
    @test first.topology_hash == second.topology_hash
    @test first.operator_program_hash == second.operator_program_hash
    # Alpha renaming preserves open operator topology/program identity.  The
    # r2 owner key is contract-owned decoration, so changing owner labels is
    # intentionally visible from structure onward.
    @test first.mechanism_structure_hash != second.mechanism_structure_hash
    @test first.decorated_mechanism_hash != second.decorated_mechanism_hash
    @test first.candidate_subject_hash != second.candidate_subject_hash
    local_renamed = _lo_fixture(prefix="local-", ledger_prefix="", external_prefix="")
    local_hash = mechanism_hash_layers(local_renamed, context)
    @test ntuple(i -> getfield(first, i), 8) == ntuple(i -> getfield(local_hash, i), 8)
    permuted = _lo_fixture(reverse=true)
    permuted_hash = mechanism_hash_layers(permuted, context)
    @test ntuple(i -> getfield(first, i), 8) == ntuple(i -> getfield(permuted_hash, i), 8)

    changed_scope = begin
        x = base.invariants[1]
        refs_b = (_lo_occ("internal", 2, :outflow, occurrence_internal_effect, x.ledger_identity),
            _lo_occ("boundary", 2, :outflow, occurrence_boundary_effect, x.ledger_identity))
        replacement = InvariantV1(x.invariant_ref, x.ledger_identity, DomainConservationScopeV1((StateGeneRefV1("state-b"),)), (InvariantTermV1(StateGeneRefV1("state-b"), 1),), refs_b, x.tolerance_log10, x.entropy_direction)
        _lo_replace(base; invariants=(replacement, base.invariants[2:end]...))
    end
    changed_scope_hash = mechanism_hash_layers(changed_scope, context)
    @test first.topology_hash == changed_scope_hash.topology_hash
    @test first.operator_program_hash == changed_scope_hash.operator_program_hash
    @test first.mechanism_structure_hash != changed_scope_hash.mechanism_structure_hash
    @test first.decorated_mechanism_hash != changed_scope_hash.decorated_mechanism_hash

    @test true
end
