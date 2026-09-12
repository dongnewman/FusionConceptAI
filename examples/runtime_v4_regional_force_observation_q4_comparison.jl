include(joinpath(@__DIR__,"runtime_v4_regional_force_observation_q3_comparison.jl"))
const RFQ4=DRIFO
Base.include(RFQ4,joinpath(@__DIR__,"..","src","RuntimeV4","RegionalForceObservationQ4ComparisonV4.jl"))
const q4_execution = RFQ4.execute_regional_force_q4(
    imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
    drifo_execution, q3_execution; run_dir=joinpath(RFQ3_RUN_ROOT, "q4"))
const q4_comparison = q4_execution.comparison
if abspath(PROGRAM_FILE) == @__FILE__
    println("q4_total_force_N=", q4_comparison.q4_total_force)
    println("q3_q4_absolute_difference_N=",
        q4_comparison.q3_q4_absolute_difference_N)
    println("q3_q4_relative_difference=",
        q4_comparison.q3_q4_relative_difference)
    println("q4_convergence_status=", q4_comparison.convergence_status)
    println("q4_node_count_per_region=",
        length(q4_comparison.q4_request.nodes) ÷
            length(q4_comparison.q4_request.partition_region_ids))
    println("REGIONAL_FORCE_Q4_COMPARISON_EXIT_CODE=0")
end
