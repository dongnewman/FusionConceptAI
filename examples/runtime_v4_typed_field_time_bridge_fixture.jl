"""D3 fixture: one candidate/prefix, independent D2 and static G2 execution."""

include(joinpath(@__DIR__, "runtime_v4_typed_dae_time_execution_fixture.jl"))

Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedFieldTimeBridgeContracts.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedFieldTimeBridge.jl"))

module D3DeclaredG2Dependency
using FusionConceptAI
include(joinpath(@__DIR__, "runtime_v4_g2_field_fixture.jl"))
end

const FieldTimeMaterializationV4 = FusionRuntimeV4.FieldTimeMaterializationV4
const FieldTimeBridgeReportV4 = FusionRuntimeV4.FieldTimeBridgeReportV4
const build_typed_field_time_bridge =
    FusionRuntimeV4.build_typed_field_time_bridge
const validate_typed_field_time_bridge =
    FusionRuntimeV4.validate_typed_field_time_bridge

# Keep D2 G1, G3, mission, bounds and contract references. Replace only the
# empty D2 G2 payload with the already-declared static G2 program.
const d3_field = FieldGeometryGenomeV4(2, tdae_field_ref, tdae_aux;
    fields=(D3DeclaredG2Dependency._g2_support,
            D3DeclaredG2Dependency._g2_phase_set))
const d3_candidate = CandidateStatePackageV4("typed-field-time-bridge-fixture",
    tdae_mission, tdae_mechanism, d3_field, tdae_real, tdae_registry)
const d3_compiled = compile_candidate(d3_candidate, tdae_registry;
    mission_payload=tdae_mission, bounds_payload=tdae_bounds,
    comparison_scope=("typed-dae", "typed-field-time-bridge"),
    scenario_scope=("mixed-state", "g2-field-scenario"))

const d3_d2_scenario = dae_scenario
const d3_init_plan = FusionRuntimeV4.compile_typed_dae_initialization_plan(
    d3_compiled, tdae_registry; differential_refs=tdae_drefs,
    algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
    scenario=d3_d2_scenario)
const d3_init_report = FusionRuntimeV4.execute_once!(
    FusionRuntimeV4.TypedDAEInitializationStoreV4(), d3_init_plan.input,
    d3_init_plan.provider, d3_init_plan)
const d3_time_protocol = FusionRuntimeV4.TypedDAETimeProtocolV4(
    t_start=0.0, t_stop=0.4, step=0.1, max_steps=4)
const d3_time_plan = FusionRuntimeV4.compile_typed_dae_time_execution_plan(
    d3_init_plan, d3_init_report; protocol=d3_time_protocol)
const d3_time_report = FusionRuntimeV4.execute_once!(
    FusionRuntimeV4.TypedDAETimeStoreV4(), d3_time_plan.input,
    d3_time_plan.provider, d3_time_plan)

const d3_g2_scenario = (name="g2-field-scenario",)
const d3_g2_grid = D3DeclaredG2Dependency.grid
const d3_g2_site = D3DeclaredG2Dependency._g2_site
const d3_operator_registry = default_operator_registry()
const d3_g2_plan = FusionRuntimeV4.compile_field_evaluation_plan(
    d3_candidate, d3_compiled, tdae_registry, d3_operator_registry;
    scenario=d3_g2_scenario, grid=d3_g2_grid,
    program_site_ref=d3_g2_site, root_position=1)
const d3_g2_provider = FusionRuntimeV4.field_evaluation_provider(d3_g2_plan)
const d3_g2_report = FusionRuntimeV4.execute_field_evaluation(
    Dict{Digest256,Any}(), d3_candidate, d3_compiled, tdae_registry,
    d3_operator_registry, d3_g2_plan, d3_g2_scenario;
    provider=d3_g2_provider)

const d3_report = build_typed_field_time_bridge(d3_candidate, d3_compiled,
    tdae_registry, d3_operator_registry, d3_time_plan, d3_time_report,
    d3_g2_plan, d3_g2_report, d3_d2_scenario, d3_g2_scenario;
    g2_provider=d3_g2_provider)
