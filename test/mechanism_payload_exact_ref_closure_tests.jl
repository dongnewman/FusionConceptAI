using Test
using FusionConceptAI

function _exact_ref_identity_program(scalar, registry)
    apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=registry, input_types=(scalar,))
    TypedASTProgramV1((ASTInputV1(1, scalar), apply), (2,), (1,); registry=registry)
end

function _exact_ref_payload(; parity_ref=QualifiedRefV1("parity-generator", "v1"),
                             symmetry_generator=QualifiedRefV1("parity-generator", "v1"),
                             second_generator=nothing, action_state=true,
                             duplicate_generator=false, gauge_ref=nothing,
                             symmetry_local_ref="symmetry")
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    registry = default_operator_registry()
    program = _exact_ref_identity_program(scalar, registry)
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1("account", "v1"), Digest256(repeat("0", 64)), unit)
    account_in = PortAccountEffectV1(
        ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1)
    account_out = PortAccountEffectV1(
        ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1)
    edge_a = AtomicMIMOHyperedgeV1("site-a", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 1),), program, governing;
        account_effects=(account_in, account_out), registry=registry)
    edge_b = AtomicMIMOHyperedgeV1("site-b", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), program, governing; registry=registry)
    graph = TypedOperatorHypergraphV1(
        (node(:state, scalar; id="state-a"), node(:state, scalar; id="state-b")),
        (edge_a, edge_b); registry=registry)
    state_a = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds,
        (ParityActionV1(parity_ref, odd),),
        gauge_ref === nothing ? () : (SymmetryRefV1(gauge_ref),), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("state-b"), scalar, bounds, (), (), (), state_derived)
    matrix = ExactRationalMatrixV1(((1,),))
    action_ref = action_state ? StateGeneRefV1("state-a") : StateGeneRefV1("state-b")
    symmetry = SymmetryGeneV1(SymmetryRefV1(symmetry_local_ref), symmetry_generator,
        symmetry_continuous, matrix, (StateSymmetryActionV1(action_ref, matrix),),
        nothing, symmetry_invariant, 0)
    symmetries = duplicate_generator ?
        (symmetry, SymmetryGeneV1(SymmetryRefV1("symmetry-2"), symmetry_generator,
            symmetry_continuous, matrix, (StateSymmetryActionV1(StateGeneRefV1("state-b"), matrix),),
            nothing, symmetry_invariant, 0)) :
        second_generator === nothing ? (symmetry,) :
        (symmetry, SymmetryGeneV1(SymmetryRefV1("symmetry-2"), second_generator,
            symmetry_continuous, matrix, (StateSymmetryActionV1(StateGeneRefV1("state-a"), matrix),),
            nothing, symmetry_invariant, 0))
    invariant = InvariantV1(InvariantRefV1("invariant"), ledger,
        scope_global, nothing, (InvariantTermV1(StateGeneRefV1("state-a"), 1),),
        (), (), (), 0, entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("observable"),
        ProgramRootRefV1(OperatorSiteRefV1("site-a"), 1, scalar),
        QualifiedRefV1("intervention", "v1"), program, bounds,
        QualifiedRefV1("noise", "v1"), NonnegativeQuantityV1(1 // 10, unit),
        NonnegativeQuantityV1(1 // 10, unit), NonnegativeQuantityV1(1 // 2, unit),
        (QualifiedRefV1("prediction", "v1"),))
    MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), symmetries,
        (observable,), ())
end

@testset "G1 exact qualified symmetry generator closure" begin
    payload = _exact_ref_payload()
    @test payload.symmetries[1].generator_ref == QualifiedRefV1("parity-generator", "v1")
    @test occursin("\"generator_ref\":{\"id\":\"parity-generator\",\"version\":\"v1\"}",
        canonical_json(payload.symmetries[1]))
    @test FusionConceptAI._g1_payload_parity_generator_closure(
        payload.states, payload.symmetries)

    @test_throws ArgumentError _exact_ref_payload(
        parity_ref=QualifiedRefV1("parity-generator", "v2"),
        symmetry_generator=QualifiedRefV1("parity-generator", "v1"))
    @test_throws ArgumentError _exact_ref_payload(action_state=false)
    @test_throws ArgumentError _exact_ref_payload(duplicate_generator=true)

    extended = FusionConceptAI._g1_transport_extended_incidence(payload)
    @test any(arc -> arc[3] == "state_gene_to_symmetry_parity|sign=odd", extended.arcs)
    @test !occursin("parity-generator", FusionConceptAI._g1_transport_state_color(payload.states[1]))
    @test occursin("parity-generator", FusionConceptAI._g1_transport_symmetry_color(payload.symmetries[1]))
    decorated = FusionConceptAI._g1_layer_extended_incidence(payload, :decorated)
    structure = FusionConceptAI._g1_layer_extended_incidence(payload, :structure)
    @test any(arc -> arc[3] == "state_gene_to_symmetry_parity|sign=odd", decorated.arcs)
    @test any(arc -> arc[3] == "state_gene_to_symmetry_parity|cardinality", structure.arcs)
    @test !any(arc -> occursin("|sign=", arc[3]), structure.arcs)

    contract = GenomeContractRef("urn:fusion:exact-ref-hash-test", "v1",
        repeat("a", 64), repeat("b", 64), "g1")
    context = MechanismCanonicalizationContextV1(contract)
    symmetry = payload.symmetries[1]
    renamed_symmetry = SymmetryGeneV1(SymmetryRefV1("renamed-local-symmetry"),
        symmetry.generator_ref, symmetry.group_kind, symmetry.coordinate_generator_matrix,
        symmetry.state_actions, symmetry.group_order, symmetry.behavior, symmetry.tolerance)
    renamed = MechanismGenomePayloadV1(payload.states, payload.invariants, payload.operator_graph,
        payload.parameters, (renamed_symmetry,), payload.observables, payload.operator_holes)
    @test canonicalize_mechanism_transport(payload, context).canonical_bytes ==
        canonicalize_mechanism_transport(renamed, context).canonical_bytes
    generator_a = QualifiedRefV1("generator-a", "v1")
    generator_b = QualifiedRefV1("generator-b", "v1")
    bound_a = _exact_ref_payload(parity_ref=generator_a, symmetry_generator=generator_a,
        second_generator=generator_b)
    bound_b = _exact_ref_payload(parity_ref=generator_b, symmetry_generator=generator_a,
        second_generator=generator_b)
    base_layers = mechanism_hash_layers(payload, context)
    rebound_layers = mechanism_hash_layers(bound_b, context)
    @test mechanism_hash_layers(bound_a, context).decorated_mechanism_hash != rebound_layers.decorated_mechanism_hash
    @test mechanism_hash_layers(bound_a, context).candidate_subject_hash != rebound_layers.candidate_subject_hash

    gauged = _exact_ref_payload(gauge_ref="symmetry")
    gauged_symmetry = gauged.symmetries[1]
    gauged_state = gauged.states[1]
    renamed_symmetry = SymmetryGeneV1(SymmetryRefV1("renamed-local-symmetry"),
        gauged_symmetry.generator_ref, gauged_symmetry.group_kind,
        gauged_symmetry.coordinate_generator_matrix, gauged_symmetry.state_actions,
        gauged_symmetry.group_order, gauged_symmetry.behavior, gauged_symmetry.tolerance)
    renamed_state = StateGeneV1(gauged_state.state_ref, gauged_state.physical_type,
        gauged_state.physical_bounds, gauged_state.parity_actions,
        (SymmetryRefV1("renamed-local-symmetry"),), gauged_state.constraint_refs,
        gauged_state.epistemic_state)
    renamed_gauged = MechanismGenomePayloadV1((renamed_state, gauged.states[2]),
        gauged.invariants, gauged.operator_graph, gauged.parameters,
        (renamed_symmetry,), gauged.observables, gauged.operator_holes)
    renamed_transport = canonicalize_mechanism_transport(renamed_gauged, context)
    @test canonicalize_mechanism_transport(gauged, context).canonical_bytes == renamed_transport.canonical_bytes
    gauged_layers = mechanism_hash_layers(gauged, context)
    renamed_layers = mechanism_hash_layers(renamed_gauged, context)
    @test gauged_layers.decorated_mechanism_hash == renamed_layers.decorated_mechanism_hash
    @test gauged_layers.candidate_subject_hash == renamed_layers.candidate_subject_hash
end

@testset "G1 migration defers unrepresentable parity generator closure" begin
    unit = UnitSignature()
    scalar = PhysicalType(:scalar_field, 0, 3, :differential, unit)
    registry = default_operator_registry()
    graph = TypedOperatorHypergraphV1(
        (node(:state, scalar; id="state-a"), node(:state, scalar; id="state-b")),
        (); registry=registry)
    contract = GenomeContractRef("urn:fusion:exact-ref-test", "v1", repeat("a", 64), repeat("b", 64), "g1")
    source = LegacyMechanismGenomeV4(1, contract, graph)
    bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), unit)
    matrix = ExactRationalMatrixV1(((1,),))
    context = MechanismCanonicalizationContextV1(contract)
    function deferred_result(parity_ref, symmetry_generator)
        state = StateGeneV1(StateGeneRefV1("state-a"), scalar, bounds,
            (ParityActionV1(parity_ref, odd),), (), (), state_derived)
        symmetry = SymmetryGeneV1(SymmetryRefV1("symmetry"), symmetry_generator,
            symmetry_continuous, matrix,
            (StateSymmetryActionV1(StateGeneRefV1("state-a"), matrix),), nothing,
            symmetry_invariant, 0)
        declaration = G1LegacyMigrationDeclarationV1(QualifiedRefV1("mapping", "v1"),
            FusionConceptAI._g1_migration_source_hash(source, context.profile), contract,
            (state,), (), (), (symmetry,), (), (), ())
        migrate_legacy_g1(source, declaration, context, registry)
    end
    missing = deferred_result(QualifiedRefV1("missing-generator", "v1"),
        QualifiedRefV1("other-generator", "v1"))
    wrong_version = deferred_result(QualifiedRefV1("same-generator", "v2"),
        QualifiedRefV1("same-generator", "v1"))
    for result in (missing, wrong_version)
        @test result.resolution === terminal_deferred
        @test result.reason === legacy_gene_semantics_unrepresentable
        @test result.genome === nothing
        @test result.mapping_hash === nothing
    end
end
