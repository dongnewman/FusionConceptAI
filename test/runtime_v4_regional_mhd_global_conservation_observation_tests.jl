using Test

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_regional_mhd_global_conservation_observation.jl"))

@testset "regional MHD global conservation observation" begin
    observation = rmgco_observation
    partition_request = imit_upstream[12]
    partition_result = imit_upstream[13]
    @test canonical_hash(observation) == observation.observation_hash
    @test observation.region_volume_force_total == q3_comparison.q3_total_force
    @test observation.partition_request_hash == canonical_hash(partition_request)
    @test observation.partition_result_hash == canonical_hash(partition_result)
    @test Tuple(v.region_id for v in observation.region_volume_force) ==
        Tuple(r.region_id for r in partition_request.regions)
    @test observation.internal_interface_pair_sum === nothing
    @test all(e -> e.pair_sum === nothing &&
        e.contribution_status === :not_surface_contribution,
        observation.internal_interface_ledger)
    @test observation.external_boundary_terms === nothing
    @test observation.global_residual === nothing
    @test observation.global_residual_norm === nothing
    @test observation.status === :nonclosure_deferred
    @test !observation.multiregion_closure
    @test observation.claim_ceiling == screen_only
    @test observation.evidence_credit == 0

    forged_status_body = merge(semantic_view(observation), (status=:closed,))
    forged_status = RegionalMHDGlobalConservationObservationV4(
        Val(:rmgco_private), values(forged_status_body)...,
        canonical_hash(forged_status_body))
    @test_throws ArgumentError canonical_hash(forged_status)
end

@testset "global conservation rejects foreign upstream identities" begin
    partition_request = imit_upstream[12]
    partition_result = imit_upstream[13]
    foreign_partition_body = merge(semantic_view(partition_request),
        (compatibility_resolution_hash=canonical_hash(:foreign_partition),))
    foreign_partition = RFQ3.DESCRhoPartitionRequestV4(RFQ3._DRP_TOKEN,
        values(foreign_partition_body)...,
        canonical_hash(foreign_partition_body))
    @test Tuple(r.region_id for r in foreign_partition.regions) ==
        Tuple(r.region_id for r in partition_request.regions)
    @test canonical_hash(foreign_partition) != canonical_hash(partition_request)
    @test_throws ArgumentError execute_regional_mhd_global_conservation_observation(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, foreign_partition, partition_result,
        smjl_request, smjl_result)

    foreign_ledger_body = merge(semantic_view(smjl_result),
        (request_hash=canonical_hash(:foreign_ledger_request),))
    foreign_ledger = StaticMHDInterfaceJumpLedgerResultV4(
        values(foreign_ledger_body)..., canonical_hash(foreign_ledger_body))
    @test canonical_hash(foreign_ledger) == foreign_ledger.result_hash
    @test_throws ArgumentError execute_regional_mhd_global_conservation_observation(
        imit_upstream, imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, partition_request, partition_result,
        smjl_request, foreign_ledger)
end

println("REGIONAL_MHD_GLOBAL_CONSERVATION_OBSERVATION_FOCUSED_EXIT_CODE=0")
