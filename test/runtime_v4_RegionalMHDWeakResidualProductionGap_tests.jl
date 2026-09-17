using Test

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_regional_mhd_weak_residual_production_gap.jl"))

@testset "RegionalMHDWeakResidualV4 real production gap" begin
    @test validate_regional_mhd_production_gap_request(rmwr_production_gap) ==
        rmwr_production_gap.request_hash
    @test rmwr_production_gap.status == :deferred
    @test rmwr_production_gap.claim_ceiling == screen_only
    @test rmwr_production_gap.q3_comparison_identity ==
        canonical_hash(q3_comparison)
    @test rmwr_production_gap.jump_result_identity == canonical_hash(smjl_result)
    @test rmwr_production_gap.global_observation_identity ==
        canonical_hash(rmgco_observation)
    @test rmwr_production_gap.partition_identity ==
        canonical_hash(imit_upstream[12])
    @test rmwr_production_gap.region_ids ==
        Tuple(region.region_id for region in imit_upstream[12].regions)
    @test_throws ArgumentError bind_regional_mhd_desc_production_gap(
        q3_comparison.candidate_hash, q3_comparison.context_hash,
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, rmwr_static_full_chain[1:end-1],
        smjl_request, smjl_result, rmgco_observation)
end

println("REGIONAL_MHD_WEAK_RESIDUAL_PRODUCTION_GAP_FOCUSED_EXIT_CODE=0")
