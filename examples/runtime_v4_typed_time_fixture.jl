using FusionConceptAI
using .FusionRuntimeV4
const TimeResidualRowBindingV4 = FusionRuntimeV4.TimeResidualRowBindingV4
const compile_typed_time_residual_plan = FusionRuntimeV4.compile_typed_time_residual_plan
const TypedTimeResidualPlanV4 = FusionRuntimeV4.TypedTimeResidualPlanV4
const TypedTimeResidualFormV4 = FusionRuntimeV4.TypedTimeResidualFormV4
const TimeIntegrationScenarioV4 = FusionRuntimeV4.TimeIntegrationScenarioV4
const StateValueV4 = FusionRuntimeV4.StateValueV4
const integrate_typed_time_residual = FusionRuntimeV4.integrate_typed_time_residual
const typed_time_residual_manifest = FusionRuntimeV4.typed_time_residual_manifest
const derive_typed_time_residual_plan = FusionRuntimeV4.derive_typed_time_residual_plan
const rk4_update_defect_v4 = FusionRuntimeV4.rk4_update_defect_v4
const replay_typed_time_trajectory = FusionRuntimeV4.replay_typed_time_trajectory
const TimeIntegrationProtocolV4 = FusionRuntimeV4.TimeIntegrationProtocolV4

const ttr_unit = UnitSignature()
const ttr_time_unit = UnitSignature((0, 0, 1, 0, 0, 0, 0))
const ttr_state_type = PhysicalType(:scalar_field, 0, 0,
    TemporalTypeV1(differential_time), ttr_unit)
const ttr_refs = (StateGeneRefV1("y1"), StateGeneRefV1("y2"))
const ttr_ops = default_operator_registry()
const ttr_constant_type = PhysicalType(:scalar_field, 0, 0,
    TemporalTypeV1(static_time), ttr_unit)

function ttr_mass_program(first_state)
    y1 = ASTInputV1(1, ttr_state_type)
    y2 = ASTInputV1(2, ttr_state_type)
    d1 = ASTApplyV1(OperatorRefV1("DT", "v1"), (1,); registry=ttr_ops,
        input_types=(ttr_state_type,))
    d2 = ASTApplyV1(OperatorRefV1("DT", "v1"), (2,); registry=ttr_ops,
        input_types=(ttr_state_type,))
    two = ASTConstantV1(:two, 2.0, ttr_constant_type)
    scaled = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"),
        first_state == 1 ? (3, 5) : (4, 5); registry=ttr_ops,
        input_types=(first_state == 1 ? d1.output_type : d2.output_type,
                     ttr_constant_type))
    add = ASTApplyV1(OperatorRefV1("ADD", "v1"),
        first_state == 1 ? (6, 4) : (6, 3); registry=ttr_ops,
        input_types=(d1.output_type, d2.output_type))
    identity = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (first_state,);
        registry=ttr_ops, input_types=(ttr_state_type,))
    TypedASTProgramV1((y1, y2, d1, d2, two, scaled, add, identity),
        (8, 7), (1, 2); registry=ttr_ops)
end

function ttr_rhs_program(first_state)
    y1 = ASTInputV1(1, ttr_state_type)
    y2 = ASTInputV1(2, ttr_state_type)
    sub = ASTApplyV1(OperatorRefV1("SUB", "v1"),
        first_state == 1 ? (2, 1) : (1, 2); registry=ttr_ops,
        input_types=(ttr_state_type, ttr_state_type))
    rate_unit = UnitSignature((0, 0, -1, 0, 0, 0, 0))
    rate_type = PhysicalType(:scalar_field, 0, 0, TemporalTypeV1(static_time), rate_unit)
    rate = ASTConstantV1(:rate, 1.0, rate_type)
    mul = ASTApplyV1(OperatorRefV1("SCALAR_MUL", "v1"), (3, 4);
        registry=ttr_ops, input_types=(sub.output_type, rate_type))
    TypedASTProgramV1((y1, y2, sub, rate, mul), (5,), (1, 2);
        registry=ttr_ops)
end

const ttr_m1 = ttr_mass_program(1)
const ttr_m2 = ttr_mass_program(2)
const ttr_r1 = ttr_rhs_program(1)
const ttr_r2 = ttr_rhs_program(2)
const ttr_ledger = ConservationLedgerIdentityV1(QualifiedRefV1("ttr-ledger", "v1"),
    digest256_text("ttr-ledger-ontology"), ttr_unit)
const ttr_in_effect = PortAccountEffectV1(
    ConservationAccountRefV1(ttr_ledger, :input, 1, :inflow), 1 // 1)
const ttr_out_effect = PortAccountEffectV1(
    ConservationAccountRefV1(ttr_ledger, :output, 1, :outflow), -1 // 1)

function ttr_edge(id, output_node, program, role; effects=())
    AtomicMIMOHyperedgeV1(id,
        (MIMOInputBindingV1(1, 1), MIMOInputBindingV1(2, 2)),
        role === governing ?
            (MIMOOutputBindingV1(1, output_node), MIMOOutputBindingV1(2, output_node + 2)) :
            (MIMOOutputBindingV1(1, output_node),),
        program, role; account_effects=effects, registry=ttr_ops)
end

const ttr_g1 = ttr_edge("g1", 1, ttr_m1, governing;
    effects=(ttr_in_effect, ttr_out_effect))
const ttr_g2 = ttr_edge("g2", 2, ttr_m2, governing)
const ttr_a1 = ttr_edge("a1", 5, ttr_r1, additive)
const ttr_a2 = ttr_edge("a2", 6, ttr_r2, additive)
const ttr_graph = TypedOperatorHypergraphV1(
    (node(:state, ttr_state_type; id="y1"),
     node(:state, ttr_state_type; id="y2"),
     node(:non_state, ttr_m1.nodes[ttr_m1.roots[2]].output_type; id="m1"),
     node(:non_state, ttr_m2.nodes[ttr_m2.roots[2]].output_type; id="m2"),
     node(:non_state, ttr_r1.nodes[ttr_r1.roots[1]].output_type; id="r1"),
     node(:non_state, ttr_r2.nodes[ttr_r2.roots[1]].output_type; id="r2"),
     node(:region, ttr_state_type; id="region"),
     node(:boundary, ttr_state_type; id="boundary")),
    (ttr_g1, ttr_g2, ttr_a1, ttr_a2); registry=ttr_ops)

const ttr_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), ttr_unit)
const ttr_s1 = StateGeneV1(ttr_refs[1], ttr_state_type, ttr_bounds, (), (), (), state_derived)
const ttr_s2 = StateGeneV1(ttr_refs[2], ttr_state_type, ttr_bounds, (), (), (), state_derived)
const ttr_observable_program = let
    input = ASTInputV1(1, ttr_state_type)
    identity = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (1,);
        registry=ttr_ops, input_types=(ttr_state_type,))
    TypedASTProgramV1((input, identity), (2,), (1,); registry=ttr_ops)
end
const ttr_invariant = InvariantV1(InvariantRefV1("ttr-invariant"), ttr_ledger,
    GlobalConservationScopeV1(),
    (InvariantTermV1(ttr_refs[1], 1),),
    (ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("g1"), :input, 1,
        :inflow, occurrence_internal_effect, ttr_ledger),
     ConservationLedgerOccurrenceRefV1(OperatorSiteRefV1("g1"), :output, 1,
        :outflow, occurrence_internal_effect, ttr_ledger)), 0, entropy_conserved)
const ttr_observable = ObservableGeneV1(ObservableRefV1("ttr-observable"),
    ProgramRootRefV1(OperatorSiteRefV1("g1"), 1, ttr_state_type),
    QualifiedRefV1("ttr-intervention", "v1"), ttr_observable_program, ttr_bounds,
    QualifiedRefV1("ttr-noise", "v1"), NonnegativeQuantityV1(1 // 10, ttr_unit),
    NonnegativeQuantityV1(1 // 10, ttr_unit), NonnegativeQuantityV1(1 // 2, ttr_unit),
    (QualifiedRefV1("ttr-prediction", "v1"),))
const ttr_payload = MechanismGenomePayloadV1((ttr_s1, ttr_s2),
    (ttr_invariant,), ttr_graph, (), (), (ttr_observable,), ())
const ttr_mechanism_ref = g1_occurrence_ownership_contract_ref("urn:fusion:ttr:mechanism")
const ttr_field_ref = GenomeContractRef("urn:fusion:ttr:field", "v1",
    digest256_text("ttr-field-schema"), digest256_text("ttr-field-canon"), "ttr")
const ttr_realization_ref = GenomeContractRef("urn:fusion:ttr:realization", "v1",
    digest256_text("ttr-realization-schema"), digest256_text("ttr-realization-canon"), "ttr")
const ttr_registry = GenomeContractRegistryV4(ttr_mechanism_ref, ttr_field_ref, ttr_realization_ref)
const ttr_mechanism = MechanismGenomeV4(1, ttr_mechanism_ref, ttr_payload)
const ttr_aux_graph = TypedOperatorHypergraphV1(
    (node(:region, ttr_state_type; id="aux-region"),
     node(:boundary, ttr_state_type; id="aux-boundary")), (), registry=ttr_ops)
const ttr_field = FieldGeometryGenomeV4(2, ttr_field_ref, ttr_aux_graph)
const ttr_realization = RealizationControlGenomeV4(3, 4, ttr_realization_ref,
    ttr_aux_graph, ttr_aux_graph)
const ttr_mission = MissionContractRef("urn:fusion:ttr:mission", "v1",
    digest256_text("ttr-mission-schema"), digest256_text("ttr-mission-canon"))
const ttr_candidate = CandidateStatePackageV4("typed-time-fixture", ttr_mission,
    ttr_mechanism, ttr_field, ttr_realization, ttr_registry)
const ttr_compiled = compile_candidate(ttr_candidate, ttr_registry;
    mission_payload=ttr_mission, bounds_payload=nothing,
    comparison_scope=("typed-time",), scenario_scope=("two-state",))
const ttr_bindings = (
    TimeResidualRowBindingV4(ttr_refs[1], canonical_hash(ttr_g1), 2,
        canonical_hash(ttr_a1), 1),
    TimeResidualRowBindingV4(ttr_refs[2], canonical_hash(ttr_g2), 2,
        canonical_hash(ttr_a2), 1))
const ttr_plan = compile_typed_time_residual_plan(ttr_compiled, ttr_registry;
    row_bindings=ttr_bindings)
const ttr_scenario = TimeIntegrationScenarioV4("two-state", 0.0, 1.0,
    ttr_time_unit,
    (StateValueV4(ttr_refs[1], 1.0, ttr_unit),
     StateValueV4(ttr_refs[2], 0.0, ttr_unit)))
