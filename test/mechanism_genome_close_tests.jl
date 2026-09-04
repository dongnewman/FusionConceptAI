"""Focused admission tests for the sealed G1 mechanism wrapper."""

const WRAPPER_UNIT = UnitSignature()
const WRAPPER_TYPE = PhysicalType(:scalar_field, 0, 3, :differential, WRAPPER_UNIT)
const WRAPPER_BOUNDS = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), WRAPPER_UNIT)
const WRAPPER_CONTRACT = GenomeContractRef("urn:fusion:wrapper", "v1",
    repeat("a", 64), repeat("b", 64), "g1")
const WRAPPER_PROFILE = CanonicalizationProfileV1("wrapper-tests", "1",
    CanonicalizationBudgetV1(100_000, 10_000, 512, 8_000_000))

function _wrapper_payload(; account::String="wrapper-account")
    registry = default_operator_registry()
    identity() = begin
        apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
            registry=registry, input_types=(WRAPPER_TYPE,))
        TypedASTProgramV1((ASTInputV1(1, WRAPPER_TYPE), apply), (2,), (1,);
            registry=registry)
    end
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1(account, "v1"), Digest256(repeat("0", 64)), WRAPPER_UNIT)
    inflow = PortAccountEffectV1(ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1)
    outflow = PortAccountEffectV1(ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1)
    edge = AtomicMIMOHyperedgeV1("wrapper-site-a", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 1),), identity(), governing;
        account_effects=(inflow, outflow), registry=registry)
    edge_b = AtomicMIMOHyperedgeV1("wrapper-site-b", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), identity(), governing; registry=registry)
    graph = TypedOperatorHypergraphV1((node(:state, WRAPPER_TYPE; id="wrapper-state-a"),
        node(:state, WRAPPER_TYPE; id="wrapper-state-b")), (edge, edge_b); registry=registry)
    state_a = StateGeneV1(StateGeneRefV1("wrapper-state-a"), WRAPPER_TYPE,
        WRAPPER_BOUNDS, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("wrapper-state-b"), WRAPPER_TYPE,
        WRAPPER_BOUNDS, (), (), (), state_derived)
    invariant = InvariantV1(InvariantRefV1("wrapper-invariant"),
        ledger, GlobalConservationScopeV1(),
        (InvariantTermV1(StateGeneRefV1("wrapper-state-a"), 1),), (), (), (), 0,
        entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("wrapper-observable"),
        ProgramRootRefV1(OperatorSiteRefV1("wrapper-site-a"), 1, WRAPPER_TYPE),
        QualifiedRefV1("wrapper-intervention", "v1"), identity(), WRAPPER_BOUNDS,
        QualifiedRefV1("wrapper-noise", "v1"), NonnegativeQuantityV1(1 // 10, WRAPPER_UNIT),
        NonnegativeQuantityV1(1 // 10, WRAPPER_UNIT), NonnegativeQuantityV1(1 // 2, WRAPPER_UNIT),
        (QualifiedRefV1("wrapper-prediction", "v1"),))
    MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (),
        (observable,), ())
end

@testset "sealed MechanismGenomeV4 wrapper" begin
    payload = _wrapper_payload()
    m1 = MechanismGenomeV4(UInt64(11), WRAPPER_CONTRACT, payload; profile=WRAPPER_PROFILE)
    m2 = MechanismGenomeV4(UInt64(99), WRAPPER_CONTRACT, payload; profile=WRAPPER_PROFILE)
    @test fieldnames(MechanismGenomeV4) == (:seed, :contract_ref, :payload, :canonical)
    @test m1.seed == UInt64(11)
    @test mechanism_hash(m1) == m1.canonical.hashes.decorated_mechanism_hash
    @test mechanism_subject_hash(m1) == m1.canonical.hashes.candidate_subject_hash
    @test mechanism_hash(m1) == mechanism_hash(m2)
    @test mechanism_subject_hash(m1) == mechanism_subject_hash(m2)
    @test mechanism_hash_layers(m1) == m1.canonical.hashes
    @test haskey(semantic_view(m1), :canonicalization_profile_hash)
    @test haskey(semantic_view(m1), :operator_registry_hash)
    @test !haskey(semantic_view(m1), :seed)
    @test_throws MethodError MechanismGenomeV4(1, WRAPPER_CONTRACT, payload.operator_graph)
    @test_throws MethodError mechanism_hash(LegacyMechanismGenomeV4(1, WRAPPER_CONTRACT,
        payload.operator_graph))
    @test_throws MethodError CandidateStatePackageV4("legacy", MissionContractRef(
        "urn:mission", "v1", digest256_text("schema"), digest256_text("canon")),
        LegacyMechanismGenomeV4(1, WRAPPER_CONTRACT, payload.operator_graph),
        FieldGeometryGenomeV4(2, WRAPPER_CONTRACT, payload.operator_graph),
        RealizationControlGenomeV4(3, 4, WRAPPER_CONTRACT, payload.operator_graph,
            payload.operator_graph), GenomeContractRegistryV4(WRAPPER_CONTRACT))
end
