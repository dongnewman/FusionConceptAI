include(joinpath(@__DIR__, "..", "examples", "runtime_v4_engineering_control_fault_obligation.jl"))
using Test
@test ecod_obligation.status === :recoverable_gap
@test !isempty(ecod_obligation.gaps)
@test ECOD.validate_engineering_control_fault_obligation(ecod_obligation,cmr_context,ecod_timing)
@test !ECOD.validate_engineering_control_fault_obligation(ecod_obligation)
@test_throws ArgumentError ECOD.make_engineering_control_fault_timing(delay_ms=NaN)
@test_throws ArgumentError ECOD.make_engineering_control_fault_timing(dropout_probability=2)
@test_throws ArgumentError ECOD.EngineeringControlFaultObligationV4(nothing)
println("ENGINEERING_CONTROL_FAULT_OBLIGATION_FOCUSED_EXIT_CODE=0")
