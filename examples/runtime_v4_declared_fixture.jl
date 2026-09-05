"""Small declared three-Genome software fixture for the v4 CLI.

This is a typed structural fixture only.  It carries no measured or
high-fidelity evidence and is intentionally expected to stop at a capability
gap unless a matching structural-screen provider is supplied by the caller.
The file defines `candidate` and `registry` for scripts/run_v4_vertical_slice.jl.
"""

using FusionConceptAI

const _fixture_unit = UnitSignature()
const _fixture_type = PhysicalType(:scalar_field, 0, 0, :differential, _fixture_unit)
const _fixture_ops = default_operator_registry()
const _fixture_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-1, 1, false), _fixture_unit)

function _fixture_program()
    apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
        registry=_fixture_ops, input_types=(_fixture_type,))
    TypedASTProgramV1((ASTInputV1(1, _fixture_type), apply), (2,), (1,);
        registry=_fixture_ops)
end

function _fixture_mechanism_payload()
    program = _fixture_program()
    contract_account = ConservationLedgerIdentityV1(
        QualifiedRefV1("runtime-fixture-account", "v1"),
        digest256_text("runtime-fixture-ontology"), _fixture_unit)
    input_effect = PortAccountEffectV1(
        ConservationAccountRefV1(contract_account, :input, 1, :inflow), 1 // 1)
    output_effect = PortAccountEffectV1(
        ConservationAccountRefV1(contract_account, :output, 1, :outflow), -1 // 1)
    # The c0e0d85 contract binds this ledger through edge port effects.  The
    # fixture is intentionally pinned to that committed G1 API; a dirty
    # checkout with a different ownership schema must be tested separately.
    edge_a = AtomicMIMOHyperedgeV1("runtime-site-a", (MIMOInputBindingV1(1, 1),),
        (MIMOOutputBindingV1(1, 1),), program, governing;
        account_effects=(input_effect, output_effect), registry=_fixture_ops)
    edge_b = AtomicMIMOHyperedgeV1("runtime-site-b", (MIMOInputBindingV1(1, 2),),
        (MIMOOutputBindingV1(1, 2),), program, governing; registry=_fixture_ops)
    graph = TypedOperatorHypergraphV1(
        (node(:state, _fixture_type; id="runtime-state-a"),
         node(:state, _fixture_type; id="runtime-state-b")),
        (edge_a, edge_b); registry=_fixture_ops)
    state_a = StateGeneV1(StateGeneRefV1("runtime-state-a"), _fixture_type,
        _fixture_bounds, (), (), (), state_derived)
    state_b = StateGeneV1(StateGeneRefV1("runtime-state-b"), _fixture_type,
        _fixture_bounds, (), (), (), state_derived)
    owned = (ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("runtime-site-a"), :input, 1, :inflow,
            occurrence_internal_effect, contract_account),
        ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("runtime-site-a"), :output, 1, :outflow,
            occurrence_internal_effect, contract_account))
    invariant = InvariantV1(InvariantRefV1("runtime-invariant"), contract_account, GlobalConservationScopeV1(), (InvariantTermV1(StateGeneRefV1("runtime-state-a"), 1),), owned, 0, entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("runtime-observable"),
        ProgramRootRefV1(OperatorSiteRefV1("runtime-site-a"), 1, _fixture_type),
        QualifiedRefV1("runtime-intervention", "v1"), program, _fixture_bounds,
        QualifiedRefV1("runtime-noise", "v1"), NonnegativeQuantityV1(1 // 10, _fixture_unit),
        NonnegativeQuantityV1(1 // 10, _fixture_unit), NonnegativeQuantityV1(1 // 2, _fixture_unit),
        (QualifiedRefV1("runtime-prediction", "v1"),))
    MechanismGenomePayloadV1((state_a, state_b), (invariant,), graph, (), (), (observable,), ())
end

function _fixture_graph()
    # Region and boundary declarations make the compiler's unresolved state
    # explicit while the graph remains a valid immutable typed hypergraph.
    TypedOperatorHypergraphV1(
        (node(:region, _fixture_type; id="runtime-region"),
         node(:boundary, _fixture_type; id="runtime-boundary")), (),
        registry=_fixture_ops)
end

const _fixture_refs = (
    g1_occurrence_ownership_contract_ref("urn:fusion:runtime:mechanism"),
    GenomeContractRef("urn:fusion:runtime:field", "v4", digest256_text("runtime-g2-schema"), digest256_text("runtime-g2-canon"), "runtime"),
    GenomeContractRef("urn:fusion:runtime:control", "v4", digest256_text("runtime-g3-schema"), digest256_text("runtime-g3-canon"), "runtime"))
const registry = GenomeContractRegistryV4(_fixture_refs...)
const _fixture_mechanism = MechanismGenomeV4(1, _fixture_refs[1], _fixture_mechanism_payload())
const _fixture_field = FieldGeometryGenomeV4(2, _fixture_refs[2], _fixture_graph())
const _fixture_realization = RealizationControlGenomeV4(3, 4, _fixture_refs[3], _fixture_graph(), _fixture_graph())
const _fixture_mission = MissionContractRef("urn:fusion:runtime:mission", "v4",
    digest256_text("runtime-mission-schema"), digest256_text("runtime-mission-canon"))
const candidate = CandidateStatePackageV4("runtime-declared-fixture", _fixture_mission,
    _fixture_mechanism, _fixture_field, _fixture_realization, registry)
