using Test
using FusionConceptAI
using LinearAlgebra
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_desc_field_provider.jl"))

@testset "candidate-bound real DESC field provider" begin
    @test dfp_request isa DFP.DESCFieldProviderRequestV4
    @test canonical_hash(dfp_request) == dfp_request.request_hash
    @test dfp_request.context_hash == dgpi_context.context_hash
    @test dfp_request.candidate_hash == dgpi_context.candidate_hash
    @test dfp_request.execution_request_hash == canonical_hash(dgrpe_request)
    @test dfp_request.execution_result_hash == canonical_hash(dgrpe_result)
    @test dfp_request.execution_receipt_hash == canonical_hash(dgrpe_receipt)
    @test dfp_request.equilibrium_output_sha256 == dgrpe_receipt.output_sha256
    @test dfp_result.status === :field_sampled
    @test dfp_result.provider_selected
    @test dfp_result.provider_executed
    @test dfp_result.result_schema_validated
    @test dfp_result.desc_version == "0.17.3"
    @test dfp_result.nfp == dgrpe_request.runner_payload.nfp
    @test dfp_result.psi == dgrpe_request.runner_payload.psi
    @test length(dfp_result.samples) == length(dfp_points)
    @test Tuple(sample.point for sample in dfp_result.samples) == dfp_points
    @test all(sample -> all(isfinite, (sample.B_desc_native_T...,
        sample.B_norm_T, sample.pressure_Pa, sample.iota, sample.sqrt_g_m3,
        sample.force_balance_error_desc_native_N_m3...)), dfp_result.samples)
    @test all(sample -> isapprox(norm(collect(sample.B_desc_native_T)),
        sample.B_norm_T; rtol=1e-10, atol=1e-12), dfp_result.samples)
    @test dfp_receipt.exit_code == 0
    @test dfp_receipt.output_schema_validated
    @test occursin("DESC_FIELD_PROVIDER_EXECUTED=1", dfp_receipt.stdout)
    @test dfp_receipt.command == string(`$(dfp_receipt.python_executable) $(dfp_receipt.adapter_path) $(dfp_receipt.upstream_hdf5_path) $(dfp_receipt.input_path) $(dfp_receipt.output_path) $(dfp_receipt.desc_module_path)`)
    @test DFP.validate_desc_field_provider_receipt(dfp_receipt)
    @test canonical_hash(dfp_receipt) == dfp_receipt.receipt_hash
    @test canonical_hash(dfp_result) == dfp_result.result_hash
    @test DFP.validate_desc_field_provider_result(dgpi_context,
        dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_request,
        dfp_result) == dfp_result.result_hash
end

@testset "field request and output schema fail closed" begin
    @test_throws ArgumentError DFP.DESCFieldSamplePointV4(NaN, 0.0, 0.0)
    @test_throws ArgumentError DFP.DESCFieldSamplePointV4(1.1, 0.0, 0.0)
    @test_throws ArgumentError DFP.make_desc_field_provider_request(dgpi_context,
        dgrpe_request, dgrpe_result, dgrpe_receipt, (dfp_points[1], dfp_points[1]))
    outside_period = DFP.DESCFieldSamplePointV4(0.5, 0.2, 2.0)
    @test_throws ArgumentError DFP.make_desc_field_provider_request(dgpi_context,
        dgrpe_request, dgrpe_result, dgrpe_receipt, (outside_period,))
    fake_token = DFP._DFPPrivateToken()
    @test_throws ArgumentError DFP.DESCFieldProviderRequestV4(fake_token,
        dfp_request.context_hash, dfp_request.candidate_hash,
        dfp_request.execution_request_hash, dfp_request.execution_result_hash,
        dfp_request.execution_receipt_hash,
        dfp_request.equilibrium_output_sha256, dfp_request.points,
        dfp_request.quantities, dfp_request.units, dfp_request.request_hash)
    foreign_body = merge(semantic_view(dfp_request),
        (candidate_hash=digest256_text("foreign-candidate"),))
    foreign_request = DFP.DESCFieldProviderRequestV4(DFP._DFP_TOKEN,
        foreign_body..., canonical_hash(foreign_body))
    @test_throws ArgumentError DFP.execute_desc_field_provider(dgpi_context,
        dgrpe_request, dgrpe_result, dgrpe_receipt, foreign_request;
        run_dir=mktempdir())

    malformed = joinpath(mktempdir(), "malformed.tsv")
    write(malformed, replace(read(dfp_receipt.output_path, String),
        "NFP\t5" => "NFP\t6"))
    @test_throws ArgumentError DFP._dfp_parse_output(malformed, dfp_request,
        dgrpe_request, dfp_result.desc_version)
end

@testset "field receipt replay detects artifact tampering" begin
    for path in (dfp_receipt.input_path, dfp_receipt.output_path,
            dfp_receipt.adapter_path)
        original = read(path)
        try
            open(path, "a") do io
                write(io, UInt8[0x0a])
            end
            @test_throws ArgumentError DFP.validate_desc_field_provider_receipt(
                dfp_receipt)
        finally
            open(path, "w") do io
                write(io, original)
            end
        end
        @test DFP.validate_desc_field_provider_receipt(dfp_receipt)
    end
end

@testset "field receipt rejects a re-sealed forged process hash" begin
    forged_body = merge(semantic_view(dfp_receipt),
        (process_hash=digest256_text("forged-process"),))
    forged_receipt = DFP.DESCFieldProviderReceiptV4(forged_body...,
        canonical_hash(forged_body))
    @test canonical_hash(forged_receipt) == forged_receipt.receipt_hash
    @test_throws ArgumentError DFP.validate_desc_field_provider_receipt(
        forged_receipt)
end

@testset "failed field provider preserves actual process exit code" begin
    process = DFP._dfp_process(dgrpe_receipt, dfp_request, mktempdir();
        adapter_source="import sys\nsys.exit(9)\n")
    @test process.exit_code == 9
    @test process.output_sha256 === nothing
    receipt = DFP._dfp_receipt(process, false)
    @test receipt.exit_code == 9
    @test !receipt.output_schema_validated
    @test_throws ArgumentError DFP.validate_desc_field_provider_receipt(receipt)
end

@testset "field authority remains screen-only" begin
    @test !dfp_result.solver_convergence_validated
    @test !dfp_result.multiregion_closure
    @test !dfp_result.physical_validation
    @test !dfp_result.engineering_validation
    @test !dfp_result.emits_evidence
    @test !dfp_result.grants_pass
    @test !dfp_result.promotion_authority
    @test !dfp_result.p5_ready
    @test !dfp_result.terminal_authority
    @test dfp_result.credible_physical_device_count == 0
    @test dfp_result.claim_ceiling == screen_only
    manifest = DFP.desc_field_provider_manifest()
    @test manifest.quantities == DFP._DFP_QUANTITIES
    @test manifest.units == DFP._DFP_UNITS
    @test !manifest.solver_convergence_validated
    @test !manifest.multiregion_closure
    @test !manifest.physical_validation
    @test !manifest.emits_evidence
    @test manifest.credible_physical_device_count == 0
end

println("DESC_FIELD_PROVIDER_FOCUSED_EXIT_CODE=0")
