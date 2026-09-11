using Test
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_desc_static_mhd_balance_provider.jl"))
@testset "real DESC static MHD balance" begin
    @test dsmb_result.regional_force_balance_sampled
    @test dsmb_result.cross_checked
    @test !dsmb_result.regional_residual_assembled
    @test !dsmb_result.jacobian_executed
    @test dsmb_result.claim_ceiling == screen_only
    @test all(isfinite, (s.force_balance_error_norm_N_m3 for s in dsmb_result.samples))
    @test all(canonical_hash(s) == s.sample_hash for s in dsmb_result.samples)
    @test all(s.F_crosschecked && s.F_discrepancy_norm_N_m3 <=
        sqrt(3) * (s.F_crosscheck_abs_tol_N_m3 + s.F_crosscheck_rel_tol *
        max(maximum(abs, s.F_desc_xyz_N_m3), maximum(abs, s.JxB_minus_gradp_xyz_N_m3)))
        for s in dsmb_result.samples)

    dsmb_request = DSMB._dsmb_request(imit_upstream[1], imit_upstream[15],
        imit_request, imit_result, imit_upstream[17])
    @test DSMB.validate_desc_static_mhd_balance_result(imit_upstream[1],
        imit_upstream[15], imit_request, imit_result, imit_upstream[17], dsmb_request,
        dsmb_result) == dsmb_result.result_hash

    foreign_result_body = merge(semantic_view(dsmb_result),
        (request_hash=canonical_hash((foreign_balance_request=true,)),))
    foreign_result = DSMB.DESCStaticMHDBalanceResultV4(
        values(foreign_result_body)..., canonical_hash(foreign_result_body))
    @test canonical_hash(foreign_result) == foreign_result.result_hash
    @test_throws ArgumentError DSMB.validate_desc_static_mhd_balance_result(
        imit_upstream[1], imit_upstream[15], imit_request, imit_result, imit_upstream[17],
        dsmb_request, foreign_result)

    original_sample = dsmb_result.samples[1]
    forged_sample_body = merge(semantic_view(original_sample),
        (F_desc_xyz_N_m3=(original_sample.F_desc_xyz_N_m3[1] + 1.0,
            original_sample.F_desc_xyz_N_m3[2:3]...),))
    forged_sample = DSMB.DESCStaticMHDBalanceSampleV4(values(forged_sample_body)...,
        canonical_hash(forged_sample_body))
    forged_samples = (forged_sample, dsmb_result.samples[2:end]...)
    forged_body = merge(semantic_view(dsmb_result), (samples=forged_samples,))
    forged_result = DSMB.DESCStaticMHDBalanceResultV4(values(forged_body)...,
        canonical_hash(forged_body))
    @test canonical_hash(forged_result) == forged_result.result_hash
    @test_throws ArgumentError DSMB.validate_desc_static_mhd_balance_result(
        imit_upstream[1], imit_upstream[15], imit_request, imit_result, imit_upstream[17],
        dsmb_request, forged_result)

    forged_positions = ((dsmb_request.positions_xyz_m[1][1] + 0.1,
        dsmb_request.positions_xyz_m[1][2:3]...), dsmb_request.positions_xyz_m[2:end]...)
    forged_request_body = merge(semantic_view(dsmb_request),
        (positions_xyz_m=forged_positions,))
    forged_request = DSMB.DESCStaticMHDBalanceRequestV4(values(forged_request_body)...,
        canonical_hash(forged_request_body))
    @test canonical_hash(forged_request) == forged_request.request_hash
    @test_throws ArgumentError DSMB.validate_desc_static_mhd_balance_result(
        imit_upstream[1], imit_upstream[15], imit_request, imit_result,
        imit_upstream[17], forged_request, dsmb_result)

    authority_body = merge(semantic_view(dsmb_result),
        (regional_residual_assembled=true,))
    authority_result = DSMB.DESCStaticMHDBalanceResultV4(values(authority_body)...,
        canonical_hash(authority_body))
    @test_throws ArgumentError canonical_hash(authority_result)

    tampered_output = replace(read(dsmb_result.receipt.output_path, String),
        "POINT\t1\t$(repr(dsmb_request.points[1].rho))" => "POINT\t1\t0.123456789";
        count=1)
    tampered_path = joinpath(dirname(dsmb_result.receipt.output_path),
        "tampered_balance_result.tsv")
    write(tampered_path, tampered_output)
    @test_throws ArgumentError DSMB._dsmb_parse(tampered_path, dsmb_request)
end
println("DESC_STATIC_MHD_BALANCE_PROVIDER_FOCUSED_EXIT_CODE=0")
