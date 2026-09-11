const RFQ3_RUN_ROOT = get(ENV, "RFQ3_RUN_ROOT", mktempdir(prefix="regional_force_q3_"))
mkpath(RFQ3_RUN_ROOT)
ENV["DRSTP_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "surface")
ENV["IMIT_PRESSURE_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "pressure")
ENV["DRIFO_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "q2")
ENV["DGRPE_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "geometry_proof")
ENV["DFP_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "field")
ENV["DFB_RUN_DIR"] = joinpath(RFQ3_RUN_ROOT, "basis")
include(joinpath(@__DIR__, "runtime_v4_desc_regional_integrated_force_observation.jl"))
const RFQ3 = DRIFO
Base.include(RFQ3, joinpath(@__DIR__, "..", "src", "RuntimeV4", "RegionalForceObservationQ3ComparisonV4.jl"))
const q3_execution = RFQ3.execute_regional_force_q3(imit_upstream, imit_request,
    imit_result, drifo_request, drifo_result, drifo_execution;
    run_dir=joinpath(RFQ3_RUN_ROOT, "comparison"))
const q3_comparison = q3_execution.comparison
if abspath(PROGRAM_FILE)==@__FILE__
    println("q3_absolute_difference_N=", q3_comparison.absolute_difference_N)
    println("q3_relative_difference=", q3_comparison.relative_difference)
    println("q3_convergence_validated=", q3_comparison.convergence_validated)
    println("REGIONAL_FORCE_Q3_COMPARISON_EXIT_CODE=0")
end
