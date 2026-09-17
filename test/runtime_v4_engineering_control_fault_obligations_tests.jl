include(joinpath(@__DIR__, "..", "examples", "runtime_v4_engineering_control_fault_obligations.jl"))
using Test
@test validate_engineering_control_fault_request(eco_request, forward_context, eco_scenario, eco_obligations)
@test eco_request.status in (:ready, :recoverable_gap)
@test_throws ArgumentError build_engineering_control_fault_request(forward_context, ControlFaultCaseV4("foreign", "foreign", (x=(0.0,1.0),)), eco_obligations)
@test_throws ArgumentError ControlFaultCaseV4("", "startup", (); delay_ms=-1)
@test_throws ArgumentError ControlFaultCaseV4("bad", "startup", (); dropout_probability=NaN)
@test_throws ArgumentError EngineeringControlFaultObligationV4("x", :physical, :control,
    nothing, eco_capability, :engineering)
@test !validate_engineering_control_fault_request(eco_request)
@test_throws ArgumentError EngineeringControlFaultRequestV4(nothing)
println("ENGINEERING_CONTROL_FAULT_FOCUSED_EXIT_CODE=0")
