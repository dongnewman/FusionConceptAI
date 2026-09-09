"""Downstream Validation/UQ request from a real trusted FreeGS receipt."""

using FusionConceptAI

include(joinpath(@__DIR__, "runtime_v4_trusted_freegs_axisymmetric_provider.jl"))

const ValidationUQExecutionRequestRuntime = TrustedFreeGSRuntime
Base.include(ValidationUQExecutionRequestRuntime,
    joinpath(@__DIR__, "..", "src", "RuntimeV4",
        "ValidationUQExecutionRequestV4.jl"))

const vuq_evidence_requirements = (
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :numerical_verification, "freegs-numerical-verification";
        required_artifacts=("mesh-refinement-study", "solver-residual-audit"),
        protocol_hash=canonical_hash((protocol="freegs-numerical-vv", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :cross_code_validation, "freegs-cross-code-validation";
        required_artifacts=("independent-code-results", "comparison-metrics"),
        protocol_hash=canonical_hash((protocol="freegs-cross-code", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :physical_validation, "freegs-held-out-physical-validation";
        required_artifacts=("held-out-experiment", "prediction-error-metrics"),
        protocol_hash=canonical_hash((protocol="held-out-physical-validation", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :calibration_holdout, "freegs-calibration-holdout";
        required_artifacts=("frozen-calibration-partition", "disjoint-holdout-partition"),
        protocol_hash=canonical_hash((protocol="calibration-holdout", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :measurement_uq, "freegs-measurement-uq";
        required_artifacts=("measurement-error-model", "uncertainty-budget"),
        protocol_hash=canonical_hash((protocol="measurement-uq", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :model_form_uq, "freegs-model-form-uq";
        required_artifacts=("model-discrepancy-model", "structural-uncertainty-summary"),
        protocol_hash=canonical_hash((protocol="model-form-uq", revision="v1"))),
    ValidationUQExecutionRequestRuntime.make_validation_uq_evidence_requirement(
        :parameter_uq, "freegs-parameter-uq";
        required_artifacts=("parameter-distribution", "propagated-output-intervals"),
        protocol_hash=canonical_hash((protocol="parameter-uq", revision="v1"))))

const vuq_request =
    ValidationUQExecutionRequestRuntime.build_validation_uq_execution_request(
        trusted_freegs_registry, freegs_context, trusted_freegs_request,
        trusted_freegs_receipt, vuq_evidence_requirements)

if abspath(PROGRAM_FILE) == @__FILE__
    println("trusted_operational_status=", vuq_request.operational_status)
    println("status=", vuq_request.status)
    println("requirements=", length(vuq_request.requirements))
    println("evidence_gaps=", length(vuq_request.evidence_gaps))
    println("evidence_credit=", vuq_request.evidence_credit)
    println("trusted_receipt_hash=", vuq_request.trusted_receipt_hash)
    println("request_hash=", vuq_request.request_hash)
    for gap in vuq_request.evidence_gaps
        println("gap=", gap.evidence_kind, ":", gap.reason, ":",
            gap.required_source_class)
    end
    manifest = ValidationUQExecutionRequestRuntime.
        validation_uq_execution_request_manifest()
    println("accepts_caller_manifests=", manifest.accepts_caller_manifests)
    println("accepts_caller_executors=", manifest.accepts_caller_executors)
    println("physical_model_screen_is_validation=",
        manifest.physical_model_screen_is_validation)
    println("p5_ready=", manifest.p5_ready)
end
