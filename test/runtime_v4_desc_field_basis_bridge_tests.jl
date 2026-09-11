using Test
using FusionConceptAI
using LinearAlgebra
include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_desc_field_basis_bridge.jl"))

@testset "candidate-bound DESC field basis bridge" begin
    @test dfb_request isa DFB.DESCFieldBasisBridgeRequestV4
    @test canonical_hash(dfb_request) == dfb_request.request_hash
    @test dfb_request.context_hash == dgpi_context.context_hash
    @test dfb_request.candidate_hash == dgpi_context.candidate_hash
    @test dfb_request.execution_request_hash == canonical_hash(dgrpe_request)
    @test dfb_request.execution_result_hash == canonical_hash(dgrpe_result)
    @test dfb_request.execution_receipt_hash == canonical_hash(dgrpe_receipt)
    @test dfb_request.compatibility_resolution_hash ==
        canonical_hash(dgcp_resolution)
    @test dfb_request.compatibility_certificate_hash ==
        canonical_hash(dgcp_certificate)
    @test dfb_request.compiled_prefix_hash ==
        dgcp_certificate.payload.compiled_prefix_hash
    @test dfb_request.physical_subject_hash ==
        dgcp_certificate.payload.physical_subject_hash
    @test dfb_request.physical_declaration_hash ==
        dgcp_certificate.payload.declaration_hash
    @test dfb_request.physical_support_hash ==
        dgcp_certificate.payload.support_hash
    @test dfb_request.coordinate_chart_hash ==
        dgcp_certificate.payload.chart_hash
    @test dfb_request.coordinate_program_hash ==
        dgcp_certificate.payload.coordinate_program_hash
    @test dfb_request.metric_program_hash ==
        dgcp_certificate.payload.metric_program_hash
    @test dfb_request.field_request_hash == canonical_hash(dfp_request)
    @test dfb_request.field_result_hash == canonical_hash(dfp_result)
    @test dfb_request.field_receipt_hash == canonical_hash(dfp_receipt)
    @test dfb_request.equilibrium_output_sha256 == dgrpe_receipt.output_sha256
    @test dfb_request.point_hashes == canonical_hash.(dfp_points)
    @test dfb_result.status === :basis_mapped
    @test dfb_result.provider_selected
    @test dfb_result.provider_executed
    @test dfb_result.result_schema_validated
    @test dfb_result.field_values_cross_checked
    @test dfb_result.position_basis_mapped
    @test dfb_result.vector_basis_mapped
    @test length(dfb_result.samples) == length(dfp_result.samples)
    @test dfb_result.source_basis === DFB._DFB_SOURCE_BASIS
    @test dfb_result.target_basis === DFB._DFB_TARGET_BASIS
    @test dfb_result.phi_frame === DFB._DFB_PHI_FRAME
    for (sample, upstream) in zip(dfb_result.samples, dfp_result.samples)
        R, phi, Z = sample.cylindrical_position_R_phi_Z
        @test sample.point_hash == canonical_hash(upstream.point)
        @test isapprox(hypot(sample.cartesian_position_xyz_m[1],
            sample.cartesian_position_xyz_m[2]), R;
            rtol=1e-12, atol=1e-12)
        @test sample.cartesian_position_xyz_m[3] == Z
        @test sample.B_cylindrical_R_phi_Z_T == upstream.B_desc_native_T
        @test sample.F_cylindrical_R_phi_Z_N_m3 ==
            upstream.force_balance_error_desc_native_N_m3
        @test sample.sqrt_g_m3 == upstream.sqrt_g_m3
        @test isapprox(norm(collect(sample.B_cartesian_xyz_T)),
            upstream.B_norm_T; rtol=1e-10, atol=1e-12)
        @test isapprox(sample.cartesian_position_xyz_m[1], R * cos(phi);
            rtol=1e-12, atol=1e-12)
        @test isapprox(sample.cartesian_position_xyz_m[2], R * sin(phi);
            rtol=1e-12, atol=1e-12)
    end
    @test dfb_receipt.exit_code == 0
    @test dfb_receipt.output_schema_validated
    @test occursin("DESC_FIELD_BASIS_BRIDGE_EXECUTED=1",
        dfb_receipt.stdout)
    @test DFB.validate_desc_field_basis_bridge_receipt(dfb_receipt)
    @test canonical_hash(dfb_receipt) == dfb_receipt.receipt_hash
    @test canonical_hash(dfb_result) == dfb_result.result_hash
    @test DFB.validate_desc_field_basis_bridge_result(dgpi_context,
        dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution,
        dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_request, dfp_result,
        dfb_request, dfb_result) == dfb_result.result_hash
end

@testset "basis schema and reconstruction fail closed" begin
    forged_body = merge(semantic_view(dfb_request),
        (target_basis=:flux_coordinate_components,))
    forged = DFB.DESCFieldBasisBridgeRequestV4(DFB._DFB_TOKEN,
        forged_body..., canonical_hash(forged_body))
    @test_throws ArgumentError canonical_hash(forged)
    fake_token = DFB._DFBPrivateToken()
    @test_throws ArgumentError DFB.DESCFieldBasisBridgeRequestV4(fake_token,
        dfb_request.context_hash, dfb_request.candidate_hash,
        dfb_request.execution_request_hash, dfb_request.execution_result_hash,
        dfb_request.execution_receipt_hash,
        dfb_request.compatibility_resolution_hash,
        dfb_request.compatibility_certificate_hash,
        dfb_request.compiled_prefix_hash, dfb_request.physical_subject_hash,
        dfb_request.physical_declaration_hash,
        dfb_request.physical_support_hash, dfb_request.coordinate_chart_hash,
        dfb_request.geometry_graph_binding_hash,
        dfb_request.coordinate_program_hash, dfb_request.metric_program_hash,
        dfb_request.geometry_payload_hash, dfb_request.field_request_hash,
        dfb_request.field_result_hash, dfb_request.field_receipt_hash,
        dfb_request.equilibrium_output_sha256, dfb_request.point_hashes,
        dfb_request.provider_quantities, dfb_request.units,
        dfb_request.source_basis, dfb_request.target_basis,
        dfb_request.phi_frame, dfb_request.request_hash)
    malformed = joinpath(mktempdir(), "malformed-basis.tsv")
    write(malformed, replace(read(dfb_receipt.output_path, String),
        "SOURCE_BASIS\tdesc_embedded_orthonormal_cylindrical_R_phi_Z" =>
        "SOURCE_BASIS\tflux_coordinate_components"))
    @test_throws ArgumentError DFB._dfb_parse_output(malformed, dfb_request,
        dfp_request, dfp_result, dgrpe_request, dfb_result.desc_version)
    truncated = (samples=(first(dfp_result.samples),),)
    @test_throws ArgumentError DFB._dfb_parse_output(dfb_receipt.output_path,
        dfb_request, dfp_request, truncated, dgrpe_request,
        dfb_result.desc_version)
    foreign_body = merge(semantic_view(dfb_request),
        (physical_support_hash=digest256_text("foreign-support"),))
    foreign = DFB.DESCFieldBasisBridgeRequestV4(DFB._DFB_TOKEN,
        foreign_body..., canonical_hash(foreign_body))
    @test_throws ArgumentError DFB._dfb_rebuild_request(dgpi_context,
        dgpi_bridge_resolution, dgpi_evaluation, dgcp_resolution,
        dgrpe_request, dgrpe_result, dgrpe_receipt, dfp_request, dfp_result,
        foreign)
end

@testset "basis receipt replay detects artifact tampering" begin
    for path in (dfb_receipt.input_path, dfb_receipt.output_path,
            dfb_receipt.adapter_path)
        original = read(path)
        try
            open(path, "a") do io
                write(io, UInt8[0x0a])
            end
            @test_throws ArgumentError begin
                DFB.validate_desc_field_basis_bridge_receipt(dfb_receipt)
            end
        finally
            open(path, "w") do io
                write(io, original)
            end
        end
        @test DFB.validate_desc_field_basis_bridge_receipt(dfb_receipt)
    end
    forged_process_hash = digest256_text("forged-process-hash")
    forged_body = merge(DFB._dfb_receipt_process_body(dfb_receipt),
        (process_hash=forged_process_hash,))
    forged_receipt = DFB.DESCFieldBasisBridgeReceiptV4(forged_body...,
        canonical_hash(forged_body))
    @test_throws ArgumentError canonical_hash(forged_receipt)

    arbitrary = joinpath(mktempdir(), "arbitrary-output.tsv")
    write(arbitrary, "not-a-DESC-basis-output\n")
    arbitrary_process = merge(DFB._dfb_receipt_process_body(dfb_receipt),
        (output_path=arbitrary, output_sha256=DFB._dfb_sha256(arbitrary),))
    arbitrary_body = merge(arbitrary_process,
        (process_hash=canonical_hash(arbitrary_process),))
    arbitrary_receipt = DFB.DESCFieldBasisBridgeReceiptV4(arbitrary_body...,
        canonical_hash(arbitrary_body))
    @test_throws ArgumentError begin
        DFB.validate_desc_field_basis_bridge_receipt(arbitrary_receipt)
    end
end

@testset "failed basis process preserves actual exit code" begin
    process = DFB._dfb_process(dgrpe_receipt, dfb_request, dfp_request,
        mktempdir(); adapter_source="import sys\nsys.exit(11)\n")
    @test process.exit_code == 11
    @test process.output_sha256 === nothing
    receipt = DFB._dfb_receipt(process, false)
    @test receipt.exit_code == 11
    @test !receipt.output_schema_validated
    @test_throws ArgumentError begin
        DFB.validate_desc_field_basis_bridge_receipt(receipt)
    end
end

@testset "basis bridge authority remains screen-only" begin
    @test !dfb_result.solver_convergence_validated
    @test !dfb_result.region_partition_validated
    @test !dfb_result.interface_trace_validated
    @test !dfb_result.multiregion_closure
    @test !dfb_result.physical_validation
    @test !dfb_result.engineering_validation
    @test !dfb_result.emits_evidence
    @test !dfb_result.grants_pass
    @test !dfb_result.promotion_authority
    @test !dfb_result.p5_ready
    @test !dfb_result.terminal_authority
    @test dfb_result.credible_physical_device_count == 0
    @test dfb_result.claim_ceiling == screen_only
    manifest = DFB.desc_field_basis_bridge_manifest()
    @test manifest.source_basis === DFB._DFB_SOURCE_BASIS
    @test manifest.target_basis === DFB._DFB_TARGET_BASIS
    @test manifest.field_values_cross_checked
    @test !manifest.region_partition_validated
    @test !manifest.multiregion_closure
    @test !manifest.physical_validation
    @test manifest.credible_physical_device_count == 0
end

println("DESC_FIELD_BASIS_BRIDGE_FOCUSED_EXIT_CODE=0")
