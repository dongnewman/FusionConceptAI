const RMGCO_RUN_ROOT = get(ENV, "RMGCO_RUN_ROOT", mktempdir(prefix="regional_mhd_global_"))
mkpath(RMGCO_RUN_ROOT)
for (k,v) in (("DGRPE_RUN_DIR","geometry_proof"),("DFP_RUN_DIR","field"),("DFB_RUN_DIR","basis"),
              ("DRSTP_RUN_DIR","surface"),("IMIT_PRESSURE_RUN_DIR","pressure"),("DRIFO_RUN_DIR","q2"))
    ENV[k] = joinpath(RMGCO_RUN_ROOT, v)
end
include(joinpath(@__DIR__, "runtime_v4_static_mhd_interface_jump_ledger.jl"))
const RFQ3 = IMIT
Base.include(RFQ3, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "DESCRegionalIntegratedForceObservationV4.jl"))
const drifo_request = RFQ3.make_desc_regional_integrated_force_observation_request(
    imit_upstream..., imit_request, imit_result)
const drifo_execution = RFQ3.execute_desc_regional_integrated_force_observation(
    imit_upstream..., imit_request, imit_result, drifo_request;
    run_dir=joinpath(RMGCO_RUN_ROOT, "q2"))
const drifo_result = drifo_execution.observation
Base.include(RFQ3, joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "RegionalForceObservationQ3ComparisonV4.jl"))
const q3_execution = RFQ3.execute_regional_force_q3(imit_upstream, imit_request,
    imit_result, drifo_request, drifo_result, drifo_execution;
    run_dir=joinpath(RMGCO_RUN_ROOT, "q3_comparison"))
const q3_comparison = q3_execution.comparison
Base.include(Main, joinpath(@__DIR__, "..", "src", "RuntimeV4", "RegionalMHDGlobalConservationObservationV4.jl"))
const rmgco_execution = execute_regional_mhd_global_conservation_observation(
    imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
    drifo_execution, q3_execution, imit_upstream[12], imit_upstream[13], smjl_request, smjl_result)
const rmgco_observation = rmgco_execution
if abspath(PROGRAM_FILE) == @__FILE__
    println("region_volume_force_total_N=", rmgco_observation.region_volume_force_total)
    println("internal_interface_pair_sum_N=", rmgco_observation.internal_interface_pair_sum)
    println("external_boundary_terms=", rmgco_observation.external_boundary_terms)
    println("global_residual_N=", rmgco_observation.global_residual)
    println("global_residual_norm_N=", rmgco_observation.global_residual_norm)
    println("status=", rmgco_observation.status)
    println("RMGCO_RUN_ROOT=", RMGCO_RUN_ROOT)
    println("REGIONAL_MHD_GLOBAL_CONSERVATION_OBSERVATION_EXIT_CODE=0")
end
