using Test
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_regional_force_observation_q3_comparison.jl"))
@testset "q3 numerical comparison" begin
    @test canonical_hash(q3_comparison)==q3_comparison.comparison_hash
    @test q3_comparison.fresh_q3_executed
    @test isfinite(q3_comparison.absolute_difference_N)
    @test isfinite(q3_comparison.relative_difference)
    @test !q3_comparison.convergence_validated
    @test q3_comparison.evidence_credit==0
    @test length(q3_comparison.q3_request.nodes)==27*length(q3_comparison.q3_region_force)
    @test q3_comparison.q3_result.request_hash == q3_comparison.q3_request.request_hash
    @test q3_comparison.q3_result.receipt_hash == q3_comparison.q3_receipt.receipt_hash
    @test isfile(q3_comparison.q3_receipt.output_path)
    @test q3_comparison.q3_receipt.output_path != joinpath(dirname(@__DIR__),
        "runs", "regional_force_q3_comparison", "regional_force_q3_result.tsv")
    duplicate_nodes = (q3_comparison.q3_request.nodes[1:end-1]...,
        q3_comparison.q3_request.nodes[end-1], q3_comparison.q3_request.nodes[end-1])
    duplicate_body = merge(semantic_view(q3_comparison.q3_request), (nodes=duplicate_nodes,))
    duplicate_request = RFQ3.RegionalForceQ3RequestV4(values(duplicate_body)...,
        canonical_hash(duplicate_body))
    @test_throws ArgumentError canonical_hash(duplicate_request)
    partition_request = imit_upstream[12]
    @test all(count(p -> p.region_id == region.region_id,
        q3_comparison.q3_request.nodes) == 27 for region in partition_request.regions)
    parsed_domain_volume = sum((region.rho_upper - region.rho_lower) * 4pi^2
        for region in partition_request.regions)
    @test isapprox(sum(p.weight for p in q3_comparison.q3_request.nodes),
        parsed_domain_volume; rtol=0, atol=1e-12)
    @test RFQ3.validate_regional_force_q3_comparison(imit_upstream,
        imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, q3_comparison;
        run_dir=joinpath(RFQ3_RUN_ROOT, "independent_validation")) ==
        q3_comparison.comparison_hash

    q3_result_body = merge(semantic_view(q3_comparison.q3_result),
        (total_force=ntuple(k -> q3_comparison.q3_result.total_force[k] +
            (k == 1 ? 1.0 : 0.0), 3),))
    forged_q3_result = RFQ3.RegionalForceQ3ResultV4(
        values(q3_result_body)..., canonical_hash(q3_result_body))
    @test_throws ArgumentError canonical_hash(forged_q3_result)

    comparison_body = merge(semantic_view(q3_comparison),
        (absolute_difference_N=q3_comparison.absolute_difference_N + 1.0,))
    forged_comparison = RFQ3.RegionalForceQ3ComparisonV4(
        values(comparison_body)..., canonical_hash(comparison_body))
    @test_throws ArgumentError canonical_hash(forged_comparison)

    total_body = merge(semantic_view(q3_comparison),
        (q3_total_force=ntuple(k -> q3_comparison.q3_total_force[k] +
            (k == 1 ? 1.0 : 0.0), 3),))
    forged_total = RFQ3.RegionalForceQ3ComparisonV4(
        values(total_body)..., canonical_hash(total_body))
    @test_throws ArgumentError canonical_hash(forged_total)
end
println("REGIONAL_FORCE_Q3_COMPARISON_FOCUSED_EXIT_CODE=0")
