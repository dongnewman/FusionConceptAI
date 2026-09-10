using Test
using FusionConceptAI
include(joinpath(@__DIR__, "..", "examples", "runtime_v4_desc_request_provider_execution.jl"))

@testset "candidate-bound DESC provider execution" begin
    @test dgrpe_probe.desc_importable
    @test dgrpe_probe.desc_version == "0.17.3"
    @test canonical_hash(dgrpe_probe) == dgrpe_probe.probe_hash
    @test dgrpe_request isa DGRPE.DESCExecutionRequestV4
    @test dgrpe_request.runner_payload isa DGRPE.DESCExecutionPayloadV4
    @test dgrpe_request.runner_payload.psi == tdpi_profiles_flux.toroidal_flux_wb
    @test canonical_hash(dgrpe_request.runner_payload) == dgrpe_request.runner_payload.payload_hash
    @test canonical_hash(dgrpe_request) == dgrpe_request.request_hash
    @test dgrpe_request.context_hash == dgpi_context.context_hash
    @test dgrpe_request.candidate_hash == dgpi_context.candidate_hash
    @test dgrpe_request.compatibility_certificate_hash == canonical_hash(dgrpe_certificate)
    @test dgrpe_result.request_emitted
    @test dgrpe_result.provider_selected
    @test dgrpe_result.provider_executed
    @test dgrpe_result.solver_execution_attempted
    @test dgrpe_result.solver_executed
    @test dgrpe_result.result_schema_validated
    @test dgrpe_result.status === :provider_executed
    @test dgrpe_receipt.exit_code == 0
    @test dgrpe_receipt.inspection_exit_code == 0
    @test dgrpe_receipt.output_schema_validated
    @test isfile(dgrpe_receipt.input_path)
    @test isfile(dgrpe_receipt.output_path)
    @test isfile(dgrpe_receipt.adapter_path)
    @test isfile(dgrpe_receipt.inspector_path)
    @test dgrpe_receipt.output_sha256 !== nothing
    @test canonical_hash(dgrpe_receipt) == dgrpe_receipt.receipt_hash
    @test DGRPE.validate_desc_provider_receipt(dgrpe_receipt)
    @test canonical_hash(dgrpe_result) == dgrpe_result.result_hash
    @test occursin("DESC_PROVIDER_EXECUTED=1", dgrpe_receipt.stdout)
    @test occursin("DESC_OUTPUT_INSPECTION_OK=1", dgrpe_receipt.inspection_stdout)
    @test occursin("EQUILIBRIUM_TYPE=Equilibrium", dgrpe_receipt.inspection_stdout)
    @test !occursin("precise_QA", dgrpe_receipt.command)
    @test dgrpe_result.claim_ceiling == screen_only
    @test !dgrpe_result.physical_validation
    @test !dgrpe_result.engineering_validation
    @test !dgrpe_result.emits_evidence
    @test !dgrpe_result.grants_pass
    @test !dgrpe_result.promotion_authority
    @test !dgrpe_result.p5_ready
    @test !dgrpe_result.terminal_authority
    @test dgrpe_result.credible_physical_device_count == 0
end

@testset "request schema and candidate reconstruction reject bypasses" begin
    payload = dgrpe_request.runner_payload
    controls = DGRPE.DESCExecutionControlsV4(payload.L, payload.M, payload.N,
        payload.L_grid, payload.M_grid, payload.N_grid, payload.maxiter,
        payload.ftol, payload.xtol, payload.gtol)
    expected = DGRPE._dgrpe_candidate_payload(dgpi_context,
        dgpi_bridge_resolution, controls)
    @test semantic_view(expected) == semantic_view(payload)
    fake_token = DGRPE._DGRPEPrivateToken()
    @test_throws ArgumentError DGRPE.DESCExecutionPayloadV4(fake_token,
        semantic_view(payload)..., payload.payload_hash)
    malicious_body = merge(semantic_view(payload), (psi=2.0,))
    malicious_payload = DGRPE.DESCExecutionPayloadV4(DGRPE._DGRPE_TOKEN,
        malicious_body..., canonical_hash(malicious_body))
    malicious_request = DGRPE.DESCExecutionRequestV4(DGRPE._DGRPE_TOKEN,
        dgrpe_request.context_hash, dgrpe_request.candidate_hash,
        dgrpe_request.compatibility_certificate_hash, malicious_payload)
    @test_throws ArgumentError DGRPE.execute_desc_request_provider(dgpi_context,
        malicious_request, dgpi_bridge_resolution, dgpi_evaluation,
        dgcp_resolution, dgrpe_probe; run_dir=mktempdir())
    nan_body = merge(semantic_view(payload), (psi=NaN,))
    @test_throws ArgumentError begin
        nan_payload = DGRPE.DESCExecutionPayloadV4(DGRPE._DGRPE_TOKEN,
            nan_body..., canonical_hash(nan_body))
        canonical_hash(nan_payload)
    end
end

@testset "receipt replay detects artifact tampering" begin
    for path in (dgrpe_receipt.input_path, dgrpe_receipt.output_path,
            dgrpe_receipt.adapter_path, dgrpe_receipt.inspector_path)
        original = read(path)
        try
            open(path, "a") do io
                write(io, UInt8[0x0a])
            end
            @test_throws ArgumentError DGRPE.validate_desc_provider_receipt(dgrpe_receipt)
        finally
            open(path, "w") do io
                write(io, original)
            end
        end
        @test DGRPE.validate_desc_provider_receipt(dgrpe_receipt)
    end
end

@testset "failed provider preserves actual process exit code" begin
    dir = mktempdir()
    input = joinpath(dir, "candidate_bound.desc")
    output = joinpath(dir, "candidate_bound.h5")
    adapter = joinpath(dir, "adapter.py")
    inspector = joinpath(dir, "inspector.py")
    write(input, "{}")
    write(adapter, "import sys\nsys.exit(7)\n")
    write(inspector, "raise AssertionError('must not run')\n")
    receipt = DGRPE._dgrpe_run(dgrpe_probe, input, output, adapter, inspector)
    @test receipt.exit_code == 7
    @test receipt.inspection_exit_code === nothing
    @test !receipt.output_schema_validated
    @test_throws ArgumentError DGRPE.validate_desc_provider_receipt(receipt)
end

@testset "manifest states the narrow authority" begin
    manifest = DGRPE.desc_request_provider_execution_manifest()
    @test manifest.provider_selected
    @test manifest.provider_executed
    @test manifest.solver_executed
    @test manifest.result_schema_validated
    @test !manifest.physical_validation
    @test !manifest.engineering_validation
    @test !manifest.emits_evidence
    @test !manifest.grants_pass
    @test !manifest.promotion_authority
    @test !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_device_count == 0
end

println("DESC_REQUEST_PROVIDER_EXECUTION_FOCUSED_EXIT_CODE=0")
