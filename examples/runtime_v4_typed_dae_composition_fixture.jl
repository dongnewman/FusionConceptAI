using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_typed_field_time_bridge_fixture.jl"))

const composition_unit = UnitSignature()
const composition_static3d = PhysicalType(:scalar_field, 0, 3,
    TemporalTypeV1(static_time), composition_unit)
const composition_bounds = QuantityIntervalV1(ExactFiniteIntervalV1(-10, 10, false), composition_unit)
const composition_u = StateGeneV1(StateGeneRefV1("u"), composition_static3d, composition_bounds, (), (), (), state_derived)
const composition_f = StateGeneV1(StateGeneRefV1("f"), composition_static3d, composition_bounds, (), (), (), state_derived)
const composition_r = StateGeneV1(StateGeneRefV1("r"), composition_static3d, composition_bounds, (), (), (), state_derived)
const composition_graph = TypedOperatorHypergraphV1(
    (tdae_graph.nodes..., node(:state, composition_static3d; id="u"),
     node(:state, composition_static3d; id="f"), node(:state, composition_static3d; id="r")),
    tdae_graph.hyperedges; registry=tdae_ops)
const composition_payload = MechanismGenomePayloadV1(
    (tdae_x, tdae_z1, tdae_z2, composition_u, composition_f, composition_r),
    tdae_payload.invariants, composition_graph, tdae_payload.parameters,
    tdae_payload.symmetries, tdae_payload.observables, tdae_payload.operator_holes)
const composition_mechanism = MechanismGenomeV4(1, tdae_mech_ref, composition_payload)
const composition_candidate = CandidateStatePackageV4("typed-dae-composition-fixture", tdae_mission,
    composition_mechanism, d3_field, tdae_real, tdae_registry)
const composition_compiled = compile_candidate(composition_candidate, tdae_registry;
    mission_payload=tdae_mission, bounds_payload=tdae_bounds,
    comparison_scope=("typed-dae", "typed-field-time-bridge", "composition"),
    scenario_scope=("mixed-state", "g2-field-scenario", "static-composition"))
const composition_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(composition_compiled, tdae_registry;
    differential_refs=tdae_drefs, algebraic_refs=tdae_arefs, row_bindings=tdae_rows, scenario=dae_scenario)
const composition_init_report = FusionRuntimeV4.execute_once!(FusionRuntimeV4.TypedDAEInitializationStoreV4(), composition_plan.input, composition_plan.provider, composition_plan)
const composition_time_plan = FusionRuntimeV4.compile_typed_dae_time_execution_plan(composition_plan, composition_init_report; protocol=d3_time_protocol)
const composition_time_report = FusionRuntimeV4.execute_once!(FusionRuntimeV4.TypedDAETimeStoreV4(), composition_time_plan.input, composition_time_plan.provider, composition_time_plan)
const composition_g2_plan = FusionRuntimeV4.compile_field_evaluation_plan(composition_candidate, composition_compiled, tdae_registry, d3_operator_registry; scenario=d3_g2_scenario, grid=d3_g2_grid, program_site_ref=d3_g2_site, root_position=1)
const composition_g2_provider = FusionRuntimeV4.field_evaluation_provider(composition_g2_plan)
const composition_g2_report = FusionRuntimeV4.execute_field_evaluation(Dict{Digest256,Any}(), composition_candidate, composition_compiled, tdae_registry, d3_operator_registry, composition_g2_plan, d3_g2_scenario; provider=composition_g2_provider)
const composition_d3_report = build_typed_field_time_bridge(composition_candidate, composition_compiled, tdae_registry, d3_operator_registry, composition_time_plan, composition_time_report, composition_g2_plan, composition_g2_report, dae_scenario, d3_g2_scenario; g2_provider=composition_g2_provider)
const composition_static_refs = (StateGeneRefV1("u"), StateGeneRefV1("f"), StateGeneRefV1("r"))
