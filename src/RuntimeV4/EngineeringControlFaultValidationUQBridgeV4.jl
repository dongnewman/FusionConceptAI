"""Explicit boundary between the dedicated G3 ECF receipt and Validation/UQ.

The dedicated engineering/control/fault executor is not a
`TrustedProviderExecutionReceiptV4`: its registry, executor and receipt schema
are intentionally different.  This adapter therefore records a typed,
candidate-bound integration gap; it never coerces the receipt or grants
validation/UQ credit.
"""

const _ECF_VUQ_BRIDGE_REVISION = "ecf-vuq-nonbridge-v1"

"""Identity-only upstream result view; authority fields must stay zero."""
struct UpstreamProviderResultIdentityV4
    provider_id::String
    request_hash::Digest256
    result_hash::Digest256
    claim_ceiling::ClaimCeiling
    provider_executed::Bool
    result_schema_validated::Bool
    physical_validation::Bool
    engineering_validation::Bool
    emits_evidence::Bool
    grants_pass::Bool
    promotion_authority::Bool
    p5_ready::Bool
    terminal_authority::Bool
    credible_physical_device_count::Int
    identity_hash::Digest256
end

function UpstreamProviderResultIdentityV4(provider_id, request_hash,
        result_hash; claim_ceiling=screen_only, provider_executed=false,
        result_schema_validated=false, physical_validation=false,
        engineering_validation=false, emits_evidence=false, grants_pass=false,
        promotion_authority=false, p5_ready=false, terminal_authority=false,
        credible_physical_device_count=0)
    id = strip(String(provider_id)); isempty(id) && throw(ArgumentError("upstream provider id required"))
    claim_ceiling === screen_only || throw(ArgumentError("upstream identity exceeds screen-only ceiling"))
    !physical_validation && !engineering_validation && !emits_evidence && !grants_pass &&
        !promotion_authority && !p5_ready && !terminal_authority &&
        credible_physical_device_count == 0 || throw(ArgumentError("upstream authority fields must remain zero"))
    body = (revision=_ECF_VUQ_BRIDGE_REVISION, provider_id=id, request_hash=request_hash,
        result_hash=result_hash, claim_ceiling=claim_ceiling,
        provider_executed=Bool(provider_executed), result_schema_validated=Bool(result_schema_validated),
        physical_validation=Bool(physical_validation), engineering_validation=Bool(engineering_validation),
        emits_evidence=Bool(emits_evidence), grants_pass=Bool(grants_pass),
        promotion_authority=Bool(promotion_authority), p5_ready=Bool(p5_ready),
        terminal_authority=Bool(terminal_authority), credible_physical_device_count=Int(credible_physical_device_count))
    UpstreamProviderResultIdentityV4(body.provider_id, body.request_hash, body.result_hash,
        body.claim_ceiling, body.provider_executed, body.result_schema_validated,
        body.physical_validation, body.engineering_validation, body.emits_evidence,
        body.grants_pass, body.promotion_authority, body.p5_ready, body.terminal_authority,
        body.credible_physical_device_count, canonical_hash(body))
end

semantic_view(x::UpstreamProviderResultIdentityV4) = (
    revision=_ECF_VUQ_BRIDGE_REVISION, provider_id=x.provider_id, request_hash=x.request_hash,
    result_hash=x.result_hash, claim_ceiling=x.claim_ceiling, provider_executed=x.provider_executed,
    result_schema_validated=x.result_schema_validated, physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation, emits_evidence=x.emits_evidence,
    grants_pass=x.grants_pass, promotion_authority=x.promotion_authority, p5_ready=x.p5_ready,
    terminal_authority=x.terminal_authority, credible_physical_device_count=x.credible_physical_device_count)
canonical_hash(x::UpstreamProviderResultIdentityV4) = x.identity_hash == canonical_hash(semantic_view(x)) ? x.identity_hash : throw(ArgumentError("upstream provider result identity hash mismatch"))

struct EngineeringControlFaultValidationUQBridgeV4
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    ecf_request_hash::Digest256
    ecf_receipt_hash::Digest256
    upstream_result_identity::UpstreamProviderResultIdentityV4
    status::Symbol
    reason::Symbol
    recoverable::Bool
    evidence_credit::Int
    detail::String
    bridge_hash::Digest256
end

semantic_view(x::EngineeringControlFaultValidationUQBridgeV4) = (
    revision=_ECF_VUQ_BRIDGE_REVISION, context_hash=x.context_hash,
    subject_hash=x.subject_hash, scenario_hash=x.scenario_hash,
    ecf_request_hash=x.ecf_request_hash,
    ecf_receipt_hash=x.ecf_receipt_hash, upstream_result_identity=x.upstream_result_identity, status=x.status,
    reason=x.reason, recoverable=x.recoverable,
    evidence_credit=x.evidence_credit, detail=x.detail)

function canonical_hash(x::EngineeringControlFaultValidationUQBridgeV4)
    x.status === :non_bridge_recoverable_gap &&
        x.reason === :dedicated_receipt_schema_not_generic_provider_receipt &&
        x.recoverable && x.evidence_credit == 0 ||
        throw(ArgumentError("ECF/VVUQ bridge exceeds non-bridge authority"))
    canonical_hash(x.upstream_result_identity)
    x.upstream_result_identity.provider_id == "engineering-control-fault" &&
        x.upstream_result_identity.provider_executed &&
        x.upstream_result_identity.result_schema_validated ||
        throw(ArgumentError("ECF/VVUQ bridge does not contain an executed ECF identity"))
    h = canonical_hash(semantic_view(x))
    h == x.bridge_hash || throw(ArgumentError("ECF/VVUQ bridge hash mismatch"))
    h
end

function validate_engineering_control_fault_vuq_bridge(
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4,
        request::TrustedEngineeringControlFaultDispatchRequestV4,
        receipt::TrustedEngineeringControlFaultOperationalReceiptV4,
        bridge::EngineeringControlFaultValidationUQBridgeV4)
    expected = build_engineering_control_fault_vuq_bridge(registry, context,
        request, receipt; upstream_result_identity=bridge.upstream_result_identity)
    semantic_view(expected) == semantic_view(bridge) ||
        throw(ArgumentError("ECF/VVUQ bridge differs from independent reconstruction"))
    bridge.bridge_hash
end

function build_engineering_control_fault_vuq_bridge(
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4,
        request::TrustedEngineeringControlFaultDispatchRequestV4,
        receipt::TrustedEngineeringControlFaultOperationalReceiptV4;
        upstream_result_identity=nothing)
    validate_trusted_engineering_control_fault_operational_receipt(
        receipt, request, registry, context)
    receipt.context_hash == context.context_hash ||
        throw(ArgumentError("ECF receipt context mismatch"))
    receipt.physical_subject_hash == context.subject.physical_subject_hash ||
        throw(ArgumentError("ECF receipt subject mismatch"))
    receipt.scenario_hash == context.scenario_hash ||
        throw(ArgumentError("ECF receipt scenario mismatch"))
    identity = upstream_result_identity === nothing ? UpstreamProviderResultIdentityV4(
        "engineering-control-fault", request.request_hash, receipt.result_hash;
        provider_executed=true, result_schema_validated=true) : upstream_result_identity
    identity isa UpstreamProviderResultIdentityV4 || throw(ArgumentError("typed upstream result identity required"))
    canonical_hash(identity)
    identity.provider_id == "engineering-control-fault" &&
        identity.request_hash == request.request_hash && identity.result_hash == receipt.result_hash &&
        identity.provider_executed && identity.result_schema_validated ||
        throw(ArgumentError("upstream identity is not the ECF execution identity"))
    body = (revision=_ECF_VUQ_BRIDGE_REVISION,
        context_hash=context.context_hash,
        subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        ecf_request_hash=request.request_hash,
        ecf_receipt_hash=receipt.receipt_hash,
        upstream_result_identity=identity,
        status=:non_bridge_recoverable_gap,
        reason=:dedicated_receipt_schema_not_generic_provider_receipt,
        recoverable=true, evidence_credit=0,
        detail="dedicated G3 operational receipt cannot be coerced into Validation/UQ evidence")
    x = EngineeringControlFaultValidationUQBridgeV4(
        body.context_hash, body.subject_hash, body.scenario_hash,
        body.ecf_request_hash, body.ecf_receipt_hash, body.upstream_result_identity, body.status,
        body.reason, body.recoverable, body.evidence_credit, body.detail,
        canonical_hash(body))
    canonical_hash(x)
    x
end

validate_engineering_control_fault_vuq_bridge(
    x::EngineeringControlFaultValidationUQBridgeV4) = canonical_hash(x)

engineering_control_fault_vuq_bridge_manifest() = (
    revision=_ECF_VUQ_BRIDGE_REVISION,
    input=:TrustedEngineeringControlFaultOperationalReceiptV4,
    output=:typed_non_bridge_integration_gap,
    coerces_to_generic_provider_receipt=false,
    emits_evidence=false, evidence_credit=0,
    physical_validation_credit=0, recoverable=true)
