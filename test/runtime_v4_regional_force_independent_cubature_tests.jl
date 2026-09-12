using Test
include(joinpath(@__DIR__,"..","examples","runtime_v4_regional_force_independent_cubature.jl"))
include(joinpath(@__DIR__,"runtime_v4_regional_force_independent_cubature_checks.jl"))
test_candidate_independent_cubature(independent_execution,imit_upstream,
    imit_request,imit_result,drifo_request,drifo_result,drifo_execution,
    q3_execution,q4_execution)
println("REGIONAL_FORCE_INDEPENDENT_CUBATURE_FOCUSED_EXIT_CODE=0")
