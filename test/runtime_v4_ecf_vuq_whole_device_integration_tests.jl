using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_ecf_vuq_whole_device_integration.jl"))
const E = TrustedEngineeringControlFaultRuntime

@testset "dedicated G3 receipt has explicit non-bridge" begin
    @test E.validate_engineering_control_fault_vuq_bridge(ecf_vuq_bridge) ==
        ecf_vuq_bridge.bridge_hash
    @test ecf_vuq_bridge.context_hash == ecfgo_context.context_hash
    @test ecf_vuq_bridge.subject_hash == ecfgo_context.subject.physical_subject_hash
    @test ecf_vuq_bridge.scenario_hash == ecfgo_context.scenario_hash
    @test ecf_vuq_bridge.ecf_receipt_hash == tecfe_receipt.receipt_hash
    @test ecf_vuq_bridge.upstream_result_identity === upstream_result_identity
    @test ecf_vuq_bridge.upstream_result_identity.provider_id == "engineering-control-fault"
    @test ecf_vuq_bridge.upstream_result_identity.request_hash == tecfe_request.request_hash
    @test E.validate_engineering_control_fault_vuq_bridge(tecfe_registry, ecfgo_context,
        tecfe_request, tecfe_receipt, ecf_vuq_bridge) == ecf_vuq_bridge.bridge_hash
    @test ecf_vuq_bridge.upstream_result_identity.provider_executed
    @test ecf_vuq_bridge.upstream_result_identity.result_schema_validated
    @test ecf_vuq_bridge.upstream_result_identity.claim_ceiling === screen_only
    @test !ecf_vuq_bridge.upstream_result_identity.physical_validation
    @test !ecf_vuq_bridge.upstream_result_identity.engineering_validation
    @test !ecf_vuq_bridge.upstream_result_identity.emits_evidence
    @test !ecf_vuq_bridge.upstream_result_identity.grants_pass
    @test !ecf_vuq_bridge.upstream_result_identity.promotion_authority
    @test !ecf_vuq_bridge.upstream_result_identity.p5_ready
    @test !ecf_vuq_bridge.upstream_result_identity.terminal_authority
    @test ecf_vuq_bridge.upstream_result_identity.credible_physical_device_count == 0
    @test ecf_vuq_bridge.status === :non_bridge_recoverable_gap
    @test ecf_vuq_bridge.reason ===
        :dedicated_receipt_schema_not_generic_provider_receipt
    @test ecf_vuq_bridge.recoverable
    @test ecf_vuq_bridge.evidence_credit == 0
    @test occursin("cannot be coerced", ecf_vuq_bridge.detail)
    manifest = E.engineering_control_fault_vuq_bridge_manifest()
    @test !manifest.coerces_to_generic_provider_receipt
    @test !manifest.emits_evidence && manifest.evidence_credit == 0
    @test !hasproperty(ecf_vuq_bridge, :evidence)
    @test !hasproperty(ecf_vuq_bridge, :validation_evidence)
    foreign_provider = E.UpstreamProviderResultIdentityV4("desc-0.17.3",
        tecfe_request.request_hash, tecfe_receipt.result_hash;
        provider_executed=true, result_schema_validated=true)
    foreign_request = E.UpstreamProviderResultIdentityV4("engineering-control-fault",
        digest256_text("foreign-request"), tecfe_receipt.result_hash;
        provider_executed=true, result_schema_validated=true)
    foreign_result = E.UpstreamProviderResultIdentityV4("engineering-control-fault",
        tecfe_request.request_hash, digest256_text("foreign-result");
        provider_executed=true, result_schema_validated=true)
    unexecuted = E.UpstreamProviderResultIdentityV4("engineering-control-fault",
        tecfe_request.request_hash, tecfe_receipt.result_hash)
    for identity in (foreign_provider, foreign_request, foreign_result, unexecuted)
        @test_throws ArgumentError E.build_engineering_control_fault_vuq_bridge(
            tecfe_registry, ecfgo_context, tecfe_request, tecfe_receipt;
            upstream_result_identity=identity)
    end
end

@testset "whole-device integration remains deferred" begin
    @test E.validate_whole_device_integration_request(whole_device_integration) ==
        whole_device_integration.request_hash
    @test whole_device_integration.stage_ids ==
        (:candidate_generation, :multi_region_coupling,
         :engineering_control_fault, :validation_uq, :whole_device)
    @test whole_device_integration.status === :screen_only_deferred
    @test length(whole_device_integration.unresolved) == 5
    @test whole_device_integration.evidence_credit == 0
    @test whole_device_integration.upstream_result_identity === upstream_result_identity
    @test E.validate_whole_device_integration_request(tecfe_registry, ecfgo_context,
        tecfe_request, tecfe_receipt, ecf_vuq_bridge, whole_device_integration) ==
        whole_device_integration.request_hash
    @test_throws ArgumentError E.make_whole_device_integration_request(
        ecfgo_context, tecfe_receipt, ecf_vuq_bridge; stage_ids=(:whole_device, :whole_device))
    @test_throws ArgumentError E.make_whole_device_integration_request(
        ecfgo_context, tecfe_receipt, ecf_vuq_bridge; stage_ids=(:candidate_generation,))
end

println("ECF_VUQ_WHOLE_DEVICE_INTEGRATION_FOCUSED_EXIT_CODE=0")
