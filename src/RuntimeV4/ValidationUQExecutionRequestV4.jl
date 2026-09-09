"""Validation/UQ evidence requests downstream of trusted provider execution.

This isolated boundary consumes only an externally revalidated
`TrustedProviderExecutionReceiptV4`. Operational completion and
`physical_model_screen` remain zero-credit inputs: this file emits typed,
recoverable evidence gaps and has no pass, promotion, P5, or terminal authority.
"""

const _VUQ_REQUEST_SCHEMA =
    "fusionconceptai:runtime-v4-validation-uq-evidence-request"
const _VUQ_REQUEST_REVISION = "validation-uq-evidence-request-v2"
const _VUQ_EVIDENCE_KINDS = (
    :numerical_verification,
    :cross_code_validation,
    :physical_validation,
    :calibration_holdout,
    :measurement_uq,
    :model_form_uq,
    :parameter_uq)

struct _ValidationUQRequestToken end
const _VUQ_REQUEST_TOKEN = _ValidationUQRequestToken()

_vuq_request_text(value::AbstractString, field::AbstractString) =
    !isempty(strip(String(value))) && isvalid(String(value)) ? String(value) :
    throw(ArgumentError("$field must be non-empty valid text"))

function _vuq_names(values, field::AbstractString)
    result = Tuple(_vuq_request_text(String(value), field) for value in Tuple(values))
    isempty(result) && throw(ArgumentError("$field cannot be empty"))
    length(unique(result)) == length(result) ||
        throw(ArgumentError("$field must be unique"))
    result
end

function _vuq_required_source_class(kind::Symbol)
    kind === :numerical_verification && return :manufactured_numerical_control
    kind === :cross_code_validation && return :independent_code
    kind === :physical_validation && return :held_out_physical_experiment
    kind === :calibration_holdout && return :disjoint_data_partition
    kind === :measurement_uq && return :measurement_uncertainty_model
    kind === :model_form_uq && return :model_form_uncertainty
    kind === :parameter_uq && return :parameter_uncertainty_distribution
    throw(ArgumentError("unknown validation/UQ evidence kind"))
end

function _vuq_requirement_body(requirement_id::String, evidence_kind::Symbol,
        required_source_class::Symbol, required_artifacts::Tuple{Vararg{String}},
        protocol_hash::Digest256)
    (revision=_VUQ_REQUEST_REVISION, requirement_id=requirement_id,
     evidence_kind=evidence_kind,
     required_source_class=required_source_class,
     required_artifacts=required_artifacts, protocol_hash=protocol_hash)
end

"""A declared evidence need; it contains no evidence or outcome."""
struct ValidationUQEvidenceRequirementV4
    requirement_id::String
    evidence_kind::Symbol
    required_source_class::Symbol
    required_artifacts::Tuple{Vararg{String}}
    protocol_hash::Digest256
    requirement_hash::Digest256
    function ValidationUQEvidenceRequirementV4(token::_ValidationUQRequestToken,
            requirement_id::String, evidence_kind::Symbol,
            required_source_class::Symbol,
            required_artifacts::Tuple{Vararg{String}},
            protocol_hash::Digest256, requirement_hash::Digest256)
        token === _VUQ_REQUEST_TOKEN || throw(ArgumentError("private constructor"))
        new(requirement_id, evidence_kind, required_source_class,
            required_artifacts, protocol_hash, requirement_hash)
    end
end

function make_validation_uq_evidence_requirement(evidence_kind::Symbol,
        requirement_id::AbstractString; required_artifacts,
        protocol_hash)
    evidence_kind in _VUQ_EVIDENCE_KINDS ||
        throw(ArgumentError("unknown validation/UQ evidence kind"))
    id = _vuq_request_text(requirement_id, "requirement id")
    artifacts = _vuq_names(required_artifacts, "required artifact")
    source_class = _vuq_required_source_class(evidence_kind)
    ph = _runtime_digest(protocol_hash)
    body = _vuq_requirement_body(id, evidence_kind, source_class,
        artifacts, ph)
    ValidationUQEvidenceRequirementV4(_VUQ_REQUEST_TOKEN, id, evidence_kind,
        source_class, artifacts, ph, canonical_hash(body))
end

function validate_validation_uq_evidence_requirement(
        requirement::ValidationUQEvidenceRequirementV4)
    expected = make_validation_uq_evidence_requirement(
        requirement.evidence_kind, requirement.requirement_id;
        required_artifacts=requirement.required_artifacts,
        protocol_hash=requirement.protocol_hash)
    requirement.required_source_class == expected.required_source_class ||
        throw(ArgumentError("validation/UQ required source class mismatch"))
    requirement.requirement_hash == expected.requirement_hash ||
        throw(ArgumentError("validation/UQ requirement hash mismatch"))
    expected.requirement_hash
end

canonical_hash(x::ValidationUQEvidenceRequirementV4) =
    validate_validation_uq_evidence_requirement(x)
semantic_view(x::ValidationUQEvidenceRequirementV4) =
    _vuq_requirement_body(x.requirement_id, x.evidence_kind,
        x.required_source_class, x.required_artifacts, x.protocol_hash)

function _vuq_gap_reason(status::Symbol)
    status === :physical_model_screen &&
        return :physical_model_screen_has_zero_validation_credit
    status === :recoverable_gap_unknown && return :provider_execution_incomplete
    status === :executor_error && return :provider_execution_failed
    :operational_receipt_has_zero_validation_credit
end

function _vuq_gap_body(requirement_hash::Digest256,
        evidence_kind::Symbol, required_source_class::Symbol,
        trusted_receipt_hash::Digest256, operational_status::Symbol,
        reason::Symbol, detail::String, recoverable::Bool,
        evidence_credit::Int)
    (revision=_VUQ_REQUEST_REVISION, requirement_hash=requirement_hash,
     evidence_kind=evidence_kind,
     required_source_class=required_source_class,
     trusted_receipt_hash=trusted_receipt_hash,
     operational_status=operational_status, reason=reason, detail=detail,
     recoverable=recoverable, evidence_credit=evidence_credit)
end

"""Typed explanation of evidence still required after operational execution."""
struct ValidationUQEvidenceGapV4
    requirement_hash::Digest256
    evidence_kind::Symbol
    required_source_class::Symbol
    trusted_receipt_hash::Digest256
    operational_status::Symbol
    reason::Symbol
    detail::String
    recoverable::Bool
    evidence_credit::Int
    gap_hash::Digest256
    function ValidationUQEvidenceGapV4(token::_ValidationUQRequestToken,
            requirement_hash::Digest256, evidence_kind::Symbol,
            required_source_class::Symbol, trusted_receipt_hash::Digest256,
            operational_status::Symbol, reason::Symbol, detail::String,
            recoverable::Bool, evidence_credit::Int, gap_hash::Digest256)
        token === _VUQ_REQUEST_TOKEN || throw(ArgumentError("private constructor"))
        new(requirement_hash, evidence_kind, required_source_class,
            trusted_receipt_hash, operational_status, reason, detail,
            recoverable, evidence_credit, gap_hash)
    end
end

function _vuq_make_gap(requirement::ValidationUQEvidenceRequirementV4,
        receipt::TrustedProviderExecutionReceiptV4)
    reason = _vuq_gap_reason(receipt.status)
    detail = receipt.status === :physical_model_screen ?
        "trusted FreeGS physical-model screen is operational only and cannot satisfy validation/UQ evidence" :
        "trusted provider receipt is operational only and cannot satisfy validation/UQ evidence"
    body = _vuq_gap_body(requirement.requirement_hash,
        requirement.evidence_kind, requirement.required_source_class,
        receipt.receipt_hash, receipt.status, reason, detail, true, 0)
    ValidationUQEvidenceGapV4(_VUQ_REQUEST_TOKEN,
        requirement.requirement_hash, requirement.evidence_kind,
        requirement.required_source_class, receipt.receipt_hash,
        receipt.status, reason, detail, true, 0, canonical_hash(body))
end

semantic_view(x::ValidationUQEvidenceGapV4) = merge(
    _vuq_gap_body(x.requirement_hash, x.evidence_kind,
        x.required_source_class, x.trusted_receipt_hash,
        x.operational_status, x.reason, x.detail, x.recoverable,
        x.evidence_credit),
    (gap_hash=x.gap_hash,))

function validate_validation_uq_evidence_gap(
        gap::ValidationUQEvidenceGapV4,
        requirement::ValidationUQEvidenceRequirementV4,
        receipt::TrustedProviderExecutionReceiptV4)
    validate_validation_uq_evidence_requirement(requirement)
    expected = _vuq_make_gap(requirement, receipt)
    semantic_view(gap) == semantic_view(expected) ||
        throw(ArgumentError("validation/UQ evidence gap mismatch"))
    expected.gap_hash
end

function _vuq_request_body(registry_hash::Digest256,
        context_hash::Digest256, subject_hash::Digest256,
        scenario_hash::Digest256, trusted_request_hash::Digest256,
        trusted_receipt_hash::Digest256,
        trusted_provider_manifest_hash::Digest256,
        trusted_output_hash::Digest256, provider_id::String,
        operational_status::Symbol,
        requirements::Tuple{Vararg{ValidationUQEvidenceRequirementV4}},
        gaps::Tuple{Vararg{ValidationUQEvidenceGapV4}}, status::Symbol)
    (revision=_VUQ_REQUEST_REVISION, registry_hash=registry_hash,
     context_hash=context_hash, subject_hash=subject_hash,
     scenario_hash=scenario_hash,
     trusted_request_hash=trusted_request_hash,
     trusted_receipt_hash=trusted_receipt_hash,
     trusted_provider_manifest_hash=trusted_provider_manifest_hash,
     trusted_output_hash=trusted_output_hash, provider_id=provider_id,
     operational_status=operational_status,
     requirement_hashes=Tuple(item.requirement_hash for item in requirements),
     gap_hashes=Tuple(item.gap_hash for item in gaps), status=status,
     evidence_credit=0)
end

struct ValidationUQExecutionRequestV4
    registry_hash::Digest256
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    trusted_request_hash::Digest256
    trusted_receipt_hash::Digest256
    trusted_provider_manifest_hash::Digest256
    trusted_output_hash::Digest256
    provider_id::String
    operational_status::Symbol
    requirements::Tuple{Vararg{ValidationUQEvidenceRequirementV4}}
    evidence_gaps::Tuple{Vararg{ValidationUQEvidenceGapV4}}
    status::Symbol
    evidence_credit::Int
    request_hash::Digest256
    function ValidationUQExecutionRequestV4(token::_ValidationUQRequestToken,
            registry_hash::Digest256, context_hash::Digest256,
            subject_hash::Digest256, scenario_hash::Digest256,
            trusted_request_hash::Digest256,
            trusted_receipt_hash::Digest256,
            trusted_provider_manifest_hash::Digest256,
            trusted_output_hash::Digest256, provider_id::String,
            operational_status::Symbol,
            requirements::Tuple{Vararg{ValidationUQEvidenceRequirementV4}},
            evidence_gaps::Tuple{Vararg{ValidationUQEvidenceGapV4}},
            status::Symbol, evidence_credit::Int,
            request_hash::Digest256)
        token === _VUQ_REQUEST_TOKEN || throw(ArgumentError("private constructor"))
        new(registry_hash, context_hash, subject_hash, scenario_hash,
            trusted_request_hash, trusted_receipt_hash,
            trusted_provider_manifest_hash, trusted_output_hash, provider_id,
            operational_status, requirements, evidence_gaps, status,
            evidence_credit, request_hash)
    end
end

function _vuq_request_components(registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4,
        trusted_request::TrustedProviderDispatchRequestV4,
        trusted_receipt::TrustedProviderExecutionReceiptV4,
        requirements::Tuple{Vararg{ValidationUQEvidenceRequirementV4}})
    validate_trusted_provider_registry(registry)
    validate_forward_chain_context(context)
    validate_trusted_provider_dispatch_request(trusted_request, registry,
        context, trusted_request.capability, trusted_request.input) ||
        throw(ArgumentError("trusted provider dispatch request failed external validation"))
    trusted_request.status === :ready_for_dispatch ||
        throw(ArgumentError("trusted provider dispatch request is not ready"))
    validate_trusted_provider_execution_receipt(trusted_receipt,
        trusted_request, registry, context) ||
        throw(ArgumentError("trusted provider execution receipt failed external validation"))
    isempty(requirements) &&
        throw(ArgumentError("validation/UQ evidence requirements cannot be empty"))
    all(validate_validation_uq_evidence_requirement(item) == item.requirement_hash
        for item in requirements) ||
        throw(ArgumentError("validation/UQ evidence requirement validation failed"))
    ids = Tuple(item.requirement_id for item in requirements)
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("validation/UQ requirement IDs must be unique"))
    registration = trusted_request.registration::TrustedProviderRegistrationV4
    provider_id = registration.manifest.backend
    gaps = Tuple(_vuq_make_gap(item, trusted_receipt) for item in requirements)
    status = :recoverable_evidence_gap
    body = _vuq_request_body(registry.registry_hash, context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        trusted_request.request_hash, trusted_receipt.receipt_hash,
        trusted_receipt.provider_manifest_hash, trusted_receipt.output_hash,
        provider_id, trusted_receipt.status, requirements, gaps, status)
    (provider_id=provider_id, gaps=gaps, status=status,
     request_hash=canonical_hash(body))
end

"""Build a zero-credit downstream request from one exact trusted execution."""
function build_validation_uq_execution_request(
        registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4,
        trusted_request::TrustedProviderDispatchRequestV4,
        trusted_receipt::TrustedProviderExecutionReceiptV4,
        requirements)
    raw = Tuple(requirements)
    all(item -> item isa ValidationUQEvidenceRequirementV4, raw) ||
        throw(ArgumentError("typed ValidationUQEvidenceRequirementV4 values required"))
    typed = Tuple(item::ValidationUQEvidenceRequirementV4 for item in raw)
    c = _vuq_request_components(registry, context, trusted_request,
        trusted_receipt, typed)
    ValidationUQExecutionRequestV4(_VUQ_REQUEST_TOKEN,
        registry.registry_hash, context.context_hash,
        context.subject.physical_subject_hash, context.scenario_hash,
        trusted_request.request_hash, trusted_receipt.receipt_hash,
        trusted_receipt.provider_manifest_hash, trusted_receipt.output_hash,
        c.provider_id, trusted_receipt.status, typed, c.gaps, c.status, 0,
        c.request_hash)
end

validate_validation_uq_execution_request(::ValidationUQExecutionRequestV4) = false

function validate_validation_uq_execution_request(
        request::ValidationUQExecutionRequestV4,
        registry::TrustedProviderRegistryV4,
        context::ForwardChainContextV4,
        trusted_request::TrustedProviderDispatchRequestV4,
        trusted_receipt::TrustedProviderExecutionReceiptV4,
        requirements)
    try
        expected = build_validation_uq_execution_request(registry, context,
            trusted_request, trusted_receipt, requirements)
        length(request.requirements) == length(expected.requirements) ||
            return false
        length(request.evidence_gaps) == length(expected.evidence_gaps) ||
            return false
        for (actual, wanted) in zip(request.requirements,
                expected.requirements)
            validate_validation_uq_evidence_requirement(actual) ==
                wanted.requirement_hash || return false
            semantic_view(actual) == semantic_view(wanted) || return false
        end
        for (actual, requirement, wanted) in zip(request.evidence_gaps,
                expected.requirements, expected.evidence_gaps)
            validate_validation_uq_evidence_gap(actual, requirement,
                trusted_receipt) == wanted.gap_hash || return false
            semantic_view(actual) == semantic_view(wanted) || return false
        end
        semantic_view(request) == semantic_view(expected)
    catch
        false
    end
end

canonical_hash(::ValidationUQExecutionRequestV4) =
    throw(ArgumentError("validation/UQ request hash requires external trusted-registry revalidation"))

semantic_view(x::ValidationUQExecutionRequestV4) = (
    registry_hash=x.registry_hash, context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    trusted_request_hash=x.trusted_request_hash,
    trusted_receipt_hash=x.trusted_receipt_hash,
    trusted_provider_manifest_hash=x.trusted_provider_manifest_hash,
    trusted_output_hash=x.trusted_output_hash, provider_id=x.provider_id,
    operational_status=x.operational_status,
    requirement_hashes=Tuple(item.requirement_hash for item in x.requirements),
    gap_hashes=Tuple(item.gap_hash for item in x.evidence_gaps),
    status=x.status, evidence_credit=x.evidence_credit,
    request_hash=x.request_hash)

validation_uq_execution_request_manifest() = (
    schema=_VUQ_REQUEST_SCHEMA, revision=_VUQ_REQUEST_REVISION,
    purpose=:trusted_execution_to_recoverable_evidence_gaps,
    accepted_input=:externally_revalidated_trusted_provider_execution_receipt,
    statuses=(:recoverable_evidence_gap,),
    accepts_caller_manifests=false, accepts_caller_executors=false,
    operational_receipt_is_evidence=false,
    physical_model_screen_is_validation=false,
    evidence_credit=0, emits_evidence=false, pass_authority=false,
    closure_authority=false, promotion_authority=false,
    p5_ready=false, terminal_authority=false,
    credible_physical_candidate_count=0)
