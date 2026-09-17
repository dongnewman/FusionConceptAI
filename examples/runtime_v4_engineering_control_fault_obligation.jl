include(joinpath(@__DIR__, "runtime_v4_conservative_multiregion_execution.jl"))
Base.include(ConservativeMultiRegionRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultObligationV4.jl"))
const ECOD=ConservativeMultiRegionRuntime
const ecod_timing=ECOD.make_engineering_control_fault_timing(delay_ms=2.0,dropout_probability=0.01,recovery_timeout_ms=100.0)
const ecod_obligation=ECOD.declare_engineering_control_fault_obligation(cmr_context,ecod_timing)
