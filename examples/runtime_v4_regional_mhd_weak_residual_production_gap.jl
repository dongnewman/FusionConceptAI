const RMWR_PRODUCTION_RUN_ROOT = get(ENV, "RMWR_PRODUCTION_RUN_ROOT",
    mktempdir(prefix="regional_mhd_weak_production_"))
ENV["RMGCO_RUN_ROOT"] = RMWR_PRODUCTION_RUN_ROOT
include(joinpath(@__DIR__,
    "runtime_v4_regional_mhd_global_conservation_observation.jl"))
include(joinpath(@__DIR__, "..", "src", "RuntimeV4",
    "RegionalMHDWeakResidualV4.jl"))

const rmwr_static_full_chain = (
    imit_upstream...,
    imit_request,
    imit_result,
    imit_rj_request,
    imit_rj_result,
)
const rmwr_production_gap = bind_regional_mhd_desc_production_gap(
    q3_comparison.candidate_hash,
    q3_comparison.context_hash,
    imit_upstream,
    imit_request,
    imit_result,
    drifo_request,
    drifo_result,
    drifo_execution,
    q3_execution,
    rmwr_static_full_chain,
    smjl_request,
    smjl_result,
    rmgco_observation,
)

if abspath(PROGRAM_FILE) == @__FILE__
    println("status=", rmwr_production_gap.status)
    println("missing_capabilities=", rmwr_production_gap.missing_capabilities)
    println("region_count=", length(rmwr_production_gap.region_ids))
    println("REGIONAL_MHD_WEAK_RESIDUAL_PRODUCTION_GAP_EXIT_CODE=0")
end
