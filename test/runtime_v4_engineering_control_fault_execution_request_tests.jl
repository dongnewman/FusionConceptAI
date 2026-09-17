include(joinpath(@__DIR__, "..", "examples", "runtime_v4_engineering_control_fault_execution_request.jl"))
using Test
@test ecf_request.status in (:ready_for_execution, :recoverable_gap)
@test ECF.validate_engineering_control_fault_execution_request(ecf_request, cmr_context, ecf_case, (ecf_obligation,), (ecf_provider,))
@test !ECF.validate_engineering_control_fault_execution_request(ecf_request)
@test_throws ArgumentError ECF.make_engineering_control_fault_case(cmr_context, "", (); delay_ms=NaN)
@test_throws ArgumentError ECF.make_engineering_control_fault_case(cmr_context, "x", (); dropout_probability=2.0)
@test_throws ArgumentError ECF.make_engineering_control_fault_obligation(cmr_context, "", :control, :manufactured_control, :control)
@test_throws ArgumentError ECF.EngineeringControlFaultExecutionRequestV4(nothing)
@test ECF.make_engineering_control_fault_execution_request(cmr_context, ecf_case, (ecf_obligation,), ()).status === :recoverable_gap
@test ECF.make_engineering_control_fault_execution_request(cmr_context, ecf_case, (ecf_obligation,), (ecf_provider, ecf_provider)).status === :recoverable_gap
println("ENGINEERING_CONTROL_FAULT_EXECUTION_REQUEST_FOCUSED_EXIT_CODE=0")
