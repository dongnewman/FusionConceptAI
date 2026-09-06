using FusionConceptAI
include(joinpath(@__DIR__, "..", "src", "RuntimeV4", "FusionRuntimeV4.jl"))
using .FusionRuntimeV4
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedDAEInitializationContracts.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedDAEInitialization.jl"))
include(joinpath(@__DIR__, "runtime_v4_typed_dae_initialization_fixture.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedDAETimeExecutionContracts.jl"))
Base.include(FusionRuntimeV4, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "TypedDAETimeExecution.jl"))

const compile_typed_dae_initialization_plan =
    FusionRuntimeV4.compile_typed_dae_initialization_plan
const compile_typed_dae_time_execution_plan =
    FusionRuntimeV4.compile_typed_dae_time_execution_plan
const TypedDAEInitializationStoreV4 =
    FusionRuntimeV4.TypedDAEInitializationStoreV4
const TypedDAETimeStoreV4 = FusionRuntimeV4.TypedDAETimeStoreV4
const TypedDAETimeProtocolV4 = FusionRuntimeV4.TypedDAETimeProtocolV4
const cache_typed_dae_time_execution =
    FusionRuntimeV4.cache_typed_dae_time_execution
const replay_typed_dae_time_execution =
    FusionRuntimeV4.replay_typed_dae_time_execution
const validate_typed_dae_time_report =
    FusionRuntimeV4.validate_typed_dae_time_report

const d2_init_plan = compile_typed_dae_initialization_plan(
    tdae_compiled, tdae_registry; differential_refs=tdae_drefs,
    algebraic_refs=tdae_arefs, row_bindings=tdae_rows,
    scenario=dae_scenario)
const d2_init_store = TypedDAEInitializationStoreV4()
const d2_init_report = FusionRuntimeV4.execute_once!(d2_init_store,
    d2_init_plan.input, d2_init_plan.provider, d2_init_plan)
const d2_time_protocol = TypedDAETimeProtocolV4(
    t_start=0.0, t_stop=0.4, step=0.1, max_steps=4)
const d2_time_plan = compile_typed_dae_time_execution_plan(
    d2_init_plan, d2_init_report; protocol=d2_time_protocol)
