using Test
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_regional_force_observation_q4_comparison.jl"))

@testset "real q2/q3/q4 regional-force convergence ladder" begin
    comparison = q4_comparison
    request = comparison.q4_request
    result = comparison.q4_result
    receipt = comparison.q4_receipt
    region_count = length(request.partition_region_ids)

    @test canonical_hash(comparison) == comparison.comparison_hash
    @test RFQ4.validate_regional_force_q4_execution(imit_upstream,
        imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, q4_execution) == comparison.comparison_hash
    @test length(request.nodes) == 64 * region_count
    @test all(count(node -> node.region_id == region_id, request.nodes) == 64
        for region_id in request.partition_region_ids)
    @test all(length(unique(Tuple(node.local_index for node in request.nodes
        if node.region_id == region_id))) == 64
        for region_id in request.partition_region_ids)
    @test isapprox(sum(node.weight for node in request.nodes),
        sum((region.rho_upper - region.rho_lower) * 4pi^2
            for region in imit_upstream[12].regions); rtol=0, atol=1e-12)
    @test result.region_force == comparison.q4_region_force
    @test result.total_force == comparison.q4_total_force
    @test RFQ4._rfq4_sum(comparison.q4_region_force) == comparison.q4_total_force
    @test comparison.q2_total_force == q3_comparison.q2_total_force
    @test comparison.q3_total_force == q3_comparison.q3_total_force
    @test comparison.q2_q3_absolute_difference_N ==
        q3_comparison.absolute_difference_N
    @test comparison.q2_q3_relative_difference ==
        q3_comparison.relative_difference
    @test all(isfinite, comparison.q4_total_force)
    @test isfinite(comparison.q3_q4_absolute_difference_N)
    @test isfinite(comparison.q3_q4_relative_difference)
    expected_status = ((comparison.q3_q4_absolute_difference_N <=
        comparison.absolute_tolerance_N || comparison.q3_q4_relative_difference <=
        comparison.relative_tolerance) &&
        comparison.q3_q4_absolute_difference_N <
            comparison.q2_q3_absolute_difference_N) ? :pass : :fail
    @test comparison.convergence_status === expected_status
    @test comparison.numerical_convergence_assessed &&
        comparison.fresh_q4_executed && comparison.independent_replay_required
    @test !comparison.independent_code_validation &&
        !comparison.physical_validation && !comparison.validation_uq
    @test !comparison.promotion_authority && !comparison.terminal_authority &&
        comparison.credible_device_count == 0
    @test comparison.evidence_credit == 0 &&
        comparison.claim_ceiling == screen_only
    @test isfile(receipt.output_path)
    @test RFQ4.validate_regional_force_q4_comparison(imit_upstream,
        imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution, q4_execution;
        run_dir=joinpath(RFQ3_RUN_ROOT, "q4_independent_validation")) ==
            comparison.comparison_hash

    missing_node_body = merge(semantic_view(request),
        (nodes=request.nodes[1:end-1],))
    missing_node_request = RFQ4.RegionalForceQ4RequestV4(RFQ4._RFQ4_TOKEN,
        values(missing_node_body)..., canonical_hash(missing_node_body))
    @test_throws ArgumentError canonical_hash(missing_node_request)

    duplicate_nodes = (request.nodes[1:end-1]..., request.nodes[end-1])
    duplicate_body = merge(semantic_view(request), (nodes=duplicate_nodes,))
    duplicate_request = RFQ4.RegionalForceQ4RequestV4(RFQ4._RFQ4_TOKEN,
        values(duplicate_body)..., canonical_hash(duplicate_body))
    @test_throws ArgumentError canonical_hash(duplicate_request)

    wrong_first = merge(request.nodes[1],
        (region_id=request.partition_region_ids[end],))
    wrong_nodes = (wrong_first, request.nodes[2:end]...)
    wrong_nodes_body = merge(semantic_view(request), (nodes=wrong_nodes,))
    wrong_nodes_request = RFQ4.RegionalForceQ4RequestV4(RFQ4._RFQ4_TOKEN,
        values(wrong_nodes_body)..., canonical_hash(wrong_nodes_body))
    @test_throws ArgumentError canonical_hash(wrong_nodes_request)

    forged_total_body = merge(semantic_view(result),
        (total_force=ntuple(k -> result.total_force[k] + (k == 1 ? 1.0 : 0.0), 3),))
    forged_total = RFQ4.RegionalForceQ4ResultV4(RFQ4._RFQ4_TOKEN,
        values(forged_total_body)..., canonical_hash(forged_total_body))
    @test_throws ArgumentError canonical_hash(forged_total)

    forged_status_body = merge(semantic_view(comparison),
        (convergence_status=comparison.convergence_status === :pass ? :fail : :pass,))
    forged_status = RFQ4.RegionalForceQ4ComparisonV4(RFQ4._RFQ4_TOKEN,
        values(forged_status_body)..., canonical_hash(forged_status_body))
    @test_throws ArgumentError canonical_hash(forged_status)

    forged_authority_body = merge(semantic_view(comparison),
        (promotion_authority=true,))
    forged_authority = RFQ4.RegionalForceQ4ComparisonV4(RFQ4._RFQ4_TOKEN,
        values(forged_authority_body)..., canonical_hash(forged_authority_body))
    @test_throws ArgumentError canonical_hash(forged_authority)

    forged_receipt_body = merge(semantic_view(receipt),
        (output_path=joinpath(dirname(receipt.output_path), "missing.tsv"),))
    forged_receipt = RFQ4.RegionalForceQ4ReceiptV4(RFQ4._RFQ4_TOKEN,
        values(forged_receipt_body)..., canonical_hash(forged_receipt_body))
    @test_throws ArgumentError RFQ4.validate_regional_force_q4_receipt(
        forged_receipt, request, q4_execution.fq, q4_execution.fr,
        q4_execution.bq, q4_execution.br,
        comparison.q4_region_force, comparison.q4_total_force)

    foreign_provider_body = merge(semantic_view(receipt),
        (field_receipt_hash=canonical_hash(q4_execution.br.receipt),))
    foreign_provider_receipt = RFQ4.RegionalForceQ4ReceiptV4(
        RFQ4._RFQ4_TOKEN, values(foreign_provider_body)...,
        canonical_hash(foreign_provider_body))
    @test_throws ArgumentError RFQ4.validate_regional_force_q4_receipt(
        foreign_provider_receipt, request, q4_execution.fq, q4_execution.fr,
        q4_execution.bq, q4_execution.br,
        comparison.q4_region_force, comparison.q4_total_force)

    @test_throws ArgumentError RFQ4.execute_regional_force_q4(imit_upstream,
        imit_request, imit_result, drifo_request, drifo_result,
        drifo_execution, q3_execution; run_dir=joinpath(RFQ3_RUN_ROOT, "bad"),
        relative_tolerance=NaN)
    @test_throws MethodError RFQ4.RegionalForceQ4ComparisonV4(
        values(semantic_view(comparison))..., comparison.comparison_hash)
end

println("REGIONAL_FORCE_Q4_COMPARISON_FOCUSED_EXIT_CODE=0")
