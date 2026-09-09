using Test
using FusionConceptAI

include(joinpath(@__DIR__, "..", "examples",
    "runtime_v4_validation_uq_execution_request.jl"))

const R = ValidationUQExecutionRequestRuntime
const VH = digest256_text("validation-uq-trusted-receipt-adversarial")
const _VUQ_CALLER_EXECUTOR = input -> input

@testset "trusted FreeGS receipt becomes typed evidence gaps" begin
    @test R.validate_trusted_provider_registry(trusted_freegs_registry) ==
        trusted_freegs_registry.registry_hash
    @test R.validate_forward_chain_context(freegs_context) ==
        freegs_context.context_hash
    @test R.validate_trusted_provider_execution_receipt(
        trusted_freegs_receipt, trusted_freegs_request,
        trusted_freegs_registry, freegs_context)
    @test vuq_request.status === :recoverable_evidence_gap
    @test vuq_request.operational_status === :physical_model_screen
    @test vuq_request.provider_id == R._TPR_FREEGS_PROVIDER
    @test vuq_request.registry_hash == trusted_freegs_registry.registry_hash
    @test vuq_request.context_hash == freegs_context.context_hash
    @test vuq_request.subject_hash == freegs_context.subject.physical_subject_hash
    @test vuq_request.scenario_hash == freegs_context.scenario_hash
    @test vuq_request.trusted_request_hash == trusted_freegs_request.request_hash
    @test vuq_request.trusted_receipt_hash == trusted_freegs_receipt.receipt_hash
    @test vuq_request.trusted_provider_manifest_hash ==
        trusted_freegs_receipt.provider_manifest_hash
    @test vuq_request.trusted_output_hash == trusted_freegs_receipt.output_hash
    @test length(vuq_request.requirements) == length(R._VUQ_EVIDENCE_KINDS) == 7
    @test length(vuq_request.evidence_gaps) == 7
    @test Tuple(item.evidence_kind for item in vuq_request.requirements) ==
        R._VUQ_EVIDENCE_KINDS
    @test all(gap -> gap.reason ===
        :physical_model_screen_has_zero_validation_credit,
        vuq_request.evidence_gaps)
    @test all(gap -> gap.operational_status === :physical_model_screen,
        vuq_request.evidence_gaps)
    @test all(gap -> gap.recoverable && gap.evidence_credit == 0,
        vuq_request.evidence_gaps)
    @test all(gap -> gap.trusted_receipt_hash ==
        trusted_freegs_receipt.receipt_hash, vuq_request.evidence_gaps)
    @test vuq_request.evidence_credit == 0
    @test R.validate_validation_uq_execution_request(vuq_request,
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, vuq_evidence_requirements)
    @test !R.validate_validation_uq_execution_request(vuq_request)
    @test_throws ArgumentError canonical_hash(vuq_request)
end

@testset "screen-only output cannot become validation or UQ" begin
    physical_gap = only(item for item in vuq_request.evidence_gaps
        if item.evidence_kind === :physical_validation)
    @test physical_gap.required_source_class === :held_out_physical_experiment
    @test occursin("cannot satisfy validation/UQ evidence", physical_gap.detail)
    for kind in (:measurement_uq, :model_form_uq, :parameter_uq)
        gap = only(item for item in vuq_request.evidence_gaps
            if item.evidence_kind === kind)
        @test gap.required_source_class == R._vuq_required_source_class(kind)
        @test gap.reason === :physical_model_screen_has_zero_validation_credit
    end
    @test !hasproperty(vuq_request, :evidence)
    @test !hasproperty(vuq_request, :pass)
    @test !hasproperty(vuq_request, :promotion)
    @test !hasproperty(vuq_request, :p5_ready)
    @test !hasproperty(vuq_request, :terminal_disposition)

    manifest = R.validation_uq_execution_request_manifest()
    @test manifest.statuses == (:recoverable_evidence_gap,)
    @test manifest.accepted_input ===
        :externally_revalidated_trusted_provider_execution_receipt
    @test !manifest.accepts_caller_manifests
    @test !manifest.accepts_caller_executors
    @test !manifest.operational_receipt_is_evidence
    @test !manifest.physical_model_screen_is_validation
    @test manifest.evidence_credit == 0 && !manifest.emits_evidence
    @test !manifest.pass_authority && !manifest.closure_authority
    @test !manifest.promotion_authority && !manifest.p5_ready
    @test !manifest.terminal_authority
    @test manifest.credible_physical_candidate_count == 0
end

@testset "caller manifests and executors cannot enter the boundary" begin
    @test_throws MethodError R.build_validation_uq_execution_request(
        freegs_context, vuq_evidence_requirements,
        (trusted_freegs_manifest,))
    @test_throws MethodError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_manifest, vuq_evidence_requirements)
    @test_throws MethodError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, vuq_evidence_requirements;
        manifest=trusted_freegs_manifest)
    @test_throws MethodError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, vuq_evidence_requirements;
        executor=_VUQ_CALLER_EXECUTOR)
end

@testset "external validation rejects substitutions and forged hashes" begin
    receipt = trusted_freegs_receipt
    forged_receipt = R.TrustedProviderExecutionReceiptV4(R._TPR_TOKEN,
        receipt.registry_hash, receipt.request_hash, receipt.registration_hash,
        receipt.provider_manifest_hash, receipt.input_hash, receipt.output,
        VH, receipt.exit_code, receipt.status, receipt.message,
        receipt.receipt_hash)
    @test !R.validate_trusted_provider_execution_receipt(forged_receipt,
        trusted_freegs_request, trusted_freegs_registry, freegs_context)
    @test_throws ArgumentError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        forged_receipt, vuq_evidence_requirements)

    @test_throws ArgumentError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, ())
    @test_throws ArgumentError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, (first(vuq_evidence_requirements), "untyped"))
    @test_throws ArgumentError R.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt,
        (first(vuq_evidence_requirements), first(vuq_evidence_requirements)))

    requirement = first(vuq_evidence_requirements)
    forged_requirement = R.ValidationUQEvidenceRequirementV4(
        R._VUQ_REQUEST_TOKEN, requirement.requirement_id,
        requirement.evidence_kind, :caller_claimed_physical_evidence,
        requirement.required_artifacts, requirement.protocol_hash,
        requirement.requirement_hash)
    @test_throws ArgumentError canonical_hash(forged_requirement)

    request = vuq_request
    forged_embedded_requirements = Base.setindex(request.requirements,
        forged_requirement, 1)
    forged_embedded_requirement_request = R.ValidationUQExecutionRequestV4(
        R._VUQ_REQUEST_TOKEN, request.registry_hash, request.context_hash,
        request.subject_hash, request.scenario_hash,
        request.trusted_request_hash, request.trusted_receipt_hash,
        request.trusted_provider_manifest_hash, request.trusted_output_hash,
        request.provider_id, request.operational_status,
        forged_embedded_requirements, request.evidence_gaps, request.status,
        request.evidence_credit, request.request_hash)
    @test !R.validate_validation_uq_execution_request(
        forged_embedded_requirement_request, trusted_freegs_registry,
        freegs_context, trusted_freegs_request, trusted_freegs_receipt,
        vuq_evidence_requirements)

    gap = first(request.evidence_gaps)
    forged_gap = R.ValidationUQEvidenceGapV4(R._VUQ_REQUEST_TOKEN,
        gap.requirement_hash, gap.evidence_kind, gap.required_source_class,
        gap.trusted_receipt_hash, gap.operational_status, gap.reason,
        gap.detail, false, 1, gap.gap_hash)
    @test_throws ArgumentError R.validate_validation_uq_evidence_gap(
        forged_gap, first(request.requirements), trusted_freegs_receipt)
    forged_embedded_gaps = Base.setindex(request.evidence_gaps, forged_gap, 1)
    forged_embedded_gap_request = R.ValidationUQExecutionRequestV4(
        R._VUQ_REQUEST_TOKEN, request.registry_hash, request.context_hash,
        request.subject_hash, request.scenario_hash,
        request.trusted_request_hash, request.trusted_receipt_hash,
        request.trusted_provider_manifest_hash, request.trusted_output_hash,
        request.provider_id, request.operational_status, request.requirements,
        forged_embedded_gaps, request.status, request.evidence_credit,
        request.request_hash)
    @test !R.validate_validation_uq_execution_request(
        forged_embedded_gap_request, trusted_freegs_registry,
        freegs_context, trusted_freegs_request, trusted_freegs_receipt,
        vuq_evidence_requirements)

    forged_request = R.ValidationUQExecutionRequestV4(R._VUQ_REQUEST_TOKEN,
        request.registry_hash, request.context_hash, request.subject_hash,
        request.scenario_hash, request.trusted_request_hash,
        request.trusted_receipt_hash, request.trusted_provider_manifest_hash,
        request.trusted_output_hash, request.provider_id,
        request.operational_status, request.requirements,
        request.evidence_gaps, :pass, 1, request.request_hash)
    @test !R.validate_validation_uq_execution_request(forged_request,
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, vuq_evidence_requirements)
end

println("VALIDATION_UQ_EXECUTION_REQUEST_FOCUSED_EXIT_CODE=0")
