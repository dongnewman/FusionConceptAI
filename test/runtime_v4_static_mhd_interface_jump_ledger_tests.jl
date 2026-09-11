using Test

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_static_mhd_interface_jump_ledger.jl"))

@testset "full-chain static jump ledger" begin
    @test canonical_hash(smjl_request) == smjl_request.request_hash
    @test canonical_hash(smjl_result) == smjl_result.result_hash
    @test validate_static_mhd_interface_jump_ledger(
        imit_upstream..., imit_request, imit_result, imit_rj_request,
        imit_rj_result, smjl_request, smjl_result) == smjl_result.result_hash
    @test length(smjl_result.entries) == length(imit_result.samples)
    for (index, entry) in enumerate(smjl_result.entries)
        spec = imit_request.specs[index]
        traction = imit_result.samples[index]
        residual = imit_rj_result.residuals[index]
        @test entry.interface_id == spec.interface_id
        @test entry.interface_hash == spec.interface_hash
        @test entry.minus_region_support_hash == spec.minus_region_support_hash
        @test entry.plus_region_support_hash == spec.plus_region_support_hash
        @test entry.traction_sample_hash == canonical_hash(traction)
        @test entry.residual_hash == canonical_hash(residual)
        @test entry.static_conditions[1].proxy_values == residual[1:3]
        @test entry.static_conditions[2].proxy_values == (residual[4],)
        @test all(c -> c.proxy_evaluated && c.boundary_limit_required &&
            !c.boundary_limit_validated && !c.condition_validated,
            entry.static_conditions)
        @test all(c -> !c.required_for_static_contract &&
            !c.input_available && !c.proxy_evaluated && !c.condition_validated,
            entry.dynamic_conditions)
    end
end

@testset "ledger authority stays closed" begin
    @test smjl_result.static_required_proxies_evaluated
    @test smjl_result.dynamic_conditions_out_of_scope
    @test !smjl_result.boundary_limits_validated
    @test !smjl_result.jump_conditions_validated
    @test !smjl_result.regional_residual_assembled
    @test !smjl_result.global_residual_assembled
    @test !smjl_result.solver_convergence_validated
    @test !smjl_result.multiregion_closure
    @test !smjl_result.emits_evidence
    @test !smjl_result.grants_pass
    @test !smjl_result.promotion_authority
    @test !smjl_result.p5_ready
    @test !smjl_result.terminal_authority
    @test smjl_result.credible_physical_device_count == 0
    @test smjl_result.claim_ceiling == screen_only

    request_body = semantic_view(smjl_request)
    foreign_body = merge(request_body, (interface_ids=("foreign_interface",),))
    foreign_request = StaticMHDInterfaceJumpLedgerRequestV4(
        values(foreign_body)..., canonical_hash(foreign_body))
    @test_throws ArgumentError validate_static_mhd_interface_jump_ledger(
        imit_upstream..., imit_request, imit_result, imit_rj_request,
        imit_rj_result, foreign_request, smjl_result)

    result_body = semantic_view(smjl_result)
    forged_body = merge(result_body, (boundary_limits_validated=true,))
    forged_result = StaticMHDInterfaceJumpLedgerResultV4(
        values(forged_body)..., canonical_hash(forged_body))
    @test_throws ArgumentError canonical_hash(forged_result)
    @test_throws MethodError make_static_mhd_interface_jump_ledger_request(
        imit_upstream..., imit_result, imit_request, imit_rj_request,
        imit_rj_result)
end

println("STATIC_MHD_INTERFACE_JUMP_LEDGER_FOCUSED_EXIT_CODE=0")
