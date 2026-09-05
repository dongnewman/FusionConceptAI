"""Published-contract 0D algebraic constraint fixture.

The fixture is intentionally dimensionless and parameter-free.  It provides
two algebraic state constraints, x+y-3=0 and x-y-1=0, plus an ignored
governing identity edge so the residual compiler must select by the sealed
constraint role.
"""

using FusionConceptAI

const _alg_unit = UnitSignature()
const _alg_type = PhysicalType(:scalar_field, 0, 0, TemporalTypeV1(algebraic_time), _alg_unit)
const _alg_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), _alg_unit)
const _alg_ops = default_operator_registry()

function _alg_linear_program(kind::Symbol)
    # Ports are intentionally non-contiguous: routing must use the typed AST
    # port declarations, never program position as an implicit ABI.
    x = ASTInputV1(7, _alg_type)
    y = ASTInputV1(11, _alg_type)
    constant = kind === :sum ? ASTConstantV1(:three, 3, _alg_type) : ASTConstantV1(:one, 1, _alg_type)
    first_op = kind === :sum ?
        ASTApplyV1(OperatorRefV1("ADD", "v1"), (1, 2), (;); registry=_alg_ops, input_types=(_alg_type, _alg_type)) :
        ASTApplyV1(OperatorRefV1("SUB", "v1"), (1, 2), (;); registry=_alg_ops, input_types=(_alg_type, _alg_type))
    final_op = ASTApplyV1(OperatorRefV1("SUB", "v1"), (4, 3), (;);
        registry=_alg_ops, input_types=(_alg_type, _alg_type))
    TypedASTProgramV1((x, y, constant, first_op, final_op), (5,), (1, 2); registry=_alg_ops)
end

const _alg_identity_apply = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,), (;);
    registry=_alg_ops, input_types=(_alg_type,))
const _alg_identity_program = TypedASTProgramV1(
    (ASTInputV1(1, _alg_type), _alg_identity_apply), (2,), (1,); registry=_alg_ops)
const _alg_sum_program = _alg_linear_program(:sum)
const _alg_difference_program = _alg_linear_program(:difference)

function _alg_payload()
    ledger = ConservationLedgerIdentityV1(QualifiedRefV1("algebraic-ledger", "v1"),
        digest256_text("algebraic-ledger-ontology"), _alg_unit)
    input_effect = PortAccountEffectV1(
        ConservationAccountRefV1(ledger, :input, 1, :inflow), 1 // 1)
    output_effect = PortAccountEffectV1(
        ConservationAccountRefV1(ledger, :output, 1, :outflow), -1 // 1)
    governing_edge = AtomicMIMOHyperedgeV1("ignored-governing-identity",
        (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 3),), _alg_identity_program, governing;
        account_effects=(input_effect, output_effect), registry=_alg_ops)
    governing_x = AtomicMIMOHyperedgeV1("governing-x",
        (MIMOInputBindingV1(1, 1),), (MIMOOutputBindingV1(1, 1),), _alg_identity_program, governing;
        registry=_alg_ops)
    governing_y = AtomicMIMOHyperedgeV1("governing-y",
        (MIMOInputBindingV1(1, 2),), (MIMOOutputBindingV1(1, 2),), _alg_identity_program, governing;
        registry=_alg_ops)
    sum_edge = AtomicMIMOHyperedgeV1("constraint-sum",
        (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
        (MIMOOutputBindingV1(1, 1),), _alg_sum_program, constraint; registry=_alg_ops)
    difference_edge = AtomicMIMOHyperedgeV1("constraint-difference",
        (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
        (MIMOOutputBindingV1(1, 2),), _alg_difference_program, constraint; registry=_alg_ops)
    graph = TypedOperatorHypergraphV1(
        (node(:state, _alg_type; id="x"), node(:state, _alg_type; id="y"),
         node(:region, _alg_type; id="ignored-region")),
        (governing_edge, governing_x, governing_y, sum_edge, difference_edge); registry=_alg_ops)
    state_x = StateGeneV1(StateGeneRefV1("x"), _alg_type, _alg_bounds, (), (),
        (ConstraintRefV1("constraint-sum"),), state_derived)
    state_y = StateGeneV1(StateGeneRefV1("y"), _alg_type, _alg_bounds, (), (),
        (ConstraintRefV1("constraint-difference"),), state_derived)
    invariant = InvariantV1(InvariantRefV1("algebraic-invariant"), ledger,
        GlobalConservationScopeV1(), (InvariantTermV1(StateGeneRefV1("x"), 1),),
        (), (), (), 0, entropy_conserved)
    observable = ObservableGeneV1(ObservableRefV1("algebraic-observable"),
        ProgramRootRefV1(OperatorSiteRefV1("ignored-governing-identity"), 1, _alg_type),
        QualifiedRefV1("algebraic-intervention", "v1"), _alg_identity_program, _alg_bounds,
        QualifiedRefV1("algebraic-noise", "v1"), NonnegativeQuantityV1(1 // 10, _alg_unit),
        NonnegativeQuantityV1(1 // 10, _alg_unit), NonnegativeQuantityV1(1 // 2, _alg_unit),
        (QualifiedRefV1("algebraic-prediction", "v1"),))
    MechanismGenomePayloadV1((state_x, state_y), (invariant,), graph, (), (), (observable,), ())
end

const _alg_refs = (
    GenomeContractRef("urn:fusion:algebraic:mechanism", "v1", digest256_text("alg-mechanism-schema"), digest256_text("alg-mechanism-canon"), "algebraic"),
    GenomeContractRef("urn:fusion:algebraic:field", "v1", digest256_text("alg-field-schema"), digest256_text("alg-field-canon"), "algebraic"),
    GenomeContractRef("urn:fusion:algebraic:realization", "v1", digest256_text("alg-realization-schema"), digest256_text("alg-realization-canon"), "algebraic"))
const registry = GenomeContractRegistryV4(_alg_refs...)
const _alg_graph = TypedOperatorHypergraphV1(
    (node(:region, _alg_type; id="algebraic-region"), node(:boundary, _alg_type; id="algebraic-boundary")), (),
    registry=_alg_ops)
const _alg_mechanism = MechanismGenomeV4(1, _alg_refs[1], _alg_payload())
const _alg_field = FieldGeometryGenomeV4(2, _alg_refs[2], _alg_graph)
const _alg_realization = RealizationControlGenomeV4(3, 4, _alg_refs[3], _alg_graph, _alg_graph)
const _alg_mission = MissionContractRef("urn:fusion:algebraic:mission", "v1",
    digest256_text("alg-mission-schema"), digest256_text("alg-mission-canon"))
const candidate = CandidateStatePackageV4("algebraic-constraint-fixture", _alg_mission,
    _alg_mechanism, _alg_field, _alg_realization, registry)
