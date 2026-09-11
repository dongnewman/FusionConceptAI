include(joinpath(@__DIR__, "runtime_v4_regional_force_observation_q3_comparison.jl"))
const RFVV = DRIFO
Base.include(RFVV, joinpath(@__DIR__, "..", "src", "RuntimeV4", "RegionalForceNumericalVVAssessmentV4.jl"))
const regional_force_vv_assessment = RFVV.execute_regional_force_numerical_vv_assessment(
    imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
    drifo_execution, q3_execution)
if abspath(PROGRAM_FILE)==@__FILE__
    println("numerical_convergence_status=", regional_force_vv_assessment.numerical_convergence_status)
    println("absolute_difference_N=", regional_force_vv_assessment.absolute_difference_N)
    println("relative_difference=", regional_force_vv_assessment.relative_difference)
    println("next_layer_request=", regional_force_vv_assessment.next_layer_request)
    println("REGIONAL_FORCE_NUMERICAL_VV_ASSESSMENT_EXIT_CODE=0")
end
