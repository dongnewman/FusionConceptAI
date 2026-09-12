include(joinpath(@__DIR__,"runtime_v4_regional_force_observation_q4_comparison.jl"))
# Use the upstream provider owner: these candidate-specific DESC types are
# intentionally not exported by FusionConceptAI.
const RFIC=RFQ4
Base.include(RFIC,joinpath(@__DIR__,"..","src","RuntimeV4","RegionalForceIndependentCubatureV4.jl"))
const independent_execution=RFIC.execute_regional_force_independent_cubature(imit_upstream,imit_request,imit_result,drifo_request,drifo_result,drifo_execution,q3_execution,q4_execution;run_dir=joinpath(RFQ3_RUN_ROOT,"independent_cubature"))
if abspath(PROGRAM_FILE)==@__FILE__
 println("independent_total_force_N=",independent_execution.result.total_force)
 println("q4_total_force_N=",independent_execution.q4_total_force)
 println("q4_independent_absolute_difference_N=",independent_execution.absolute_difference_N)
 println("q4_independent_relative_difference=",independent_execution.relative_difference)
 println("independent_comparison_status=",independent_execution.comparison_status)
 println("independent_node_count_per_region=",length(independent_execution.request.nodes)÷length(independent_execution.request.partition_region_ids))
 println("REGIONAL_FORCE_INDEPENDENT_CUBATURE_EXIT_CODE=0")
end
