include(joinpath(@__DIR__, "runtime_v4_ecf_vuq_whole_device_integration.jl"))
Base.include(ECFVUQ, joinpath(@__DIR__, "..", "src", "RuntimeV4", "EngineeringControlFaultNumericalRepeatabilityV4.jl"))
const ecf_repeatability = ECFVUQ.execute_ecf_numerical_repeatability(
    tecfe_registry, ecfgo_context, tecfe_request, tecfe_receipt, ecf_vuq_bridge)
if abspath(PROGRAM_FILE) == @__FILE__
    println("status=", ecf_repeatability.result.status)
    println("trace_observables_validated=", ecf_repeatability.result.trace_observables_validated)
    println("repeatability_passed=", ecf_repeatability.result.repeatability_passed)
    println("claim_ceiling=", ecf_repeatability.result.claim_ceiling)
    println("physical_validation=", ecf_repeatability.result.physical_validation)
    println("validation_uq=", ecf_repeatability.result.validation_uq)
    println("whole_device_closure=", ecf_repeatability.result.whole_device_closure)
    println("ECF_NUMERICAL_REPEATABILITY_EXIT_CODE=0")
end
