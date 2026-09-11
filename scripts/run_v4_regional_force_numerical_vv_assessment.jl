include(joinpath(@__DIR__, "..", "examples", "runtime_v4_regional_force_numerical_vv_assessment.jl"))
println("numerical_convergence_status=", regional_force_vv_assessment.numerical_convergence_status)
println("relative_difference=", regional_force_vv_assessment.relative_difference)
println("REGIONAL_FORCE_NUMERICAL_VV_ASSESSMENT_EXIT_CODE=0")
