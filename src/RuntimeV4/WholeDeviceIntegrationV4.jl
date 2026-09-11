"""Minimal typed whole-device assembly boundary.

This is an integration request, not a closure authority.  It binds the same
subject/scenario to the dedicated G3 receipt and its explicit VVUQ gap while
keeping the whole-device result deferred and zero-credit.
"""

const _WHOLE_DEVICE_INTEGRATION_REVISION = "whole-device-integration-v1"
const _WHOLE_DEVICE_STAGE_IDS = (:candidate_generation, :multi_region_coupling,
    :engineering_control_fault, :validation_uq, :whole_device)

struct WholeDeviceIntegrationRequestV4
    context_hash::Digest256
    subject_hash::Digest256
    scenario_hash::Digest256
    ecf_receipt_hash::Digest256
    bridge_hash::Digest256
    upstream_result_identity::UpstreamProviderResultIdentityV4
    stage_ids::Tuple{Vararg{Symbol}}
    status::Symbol
    unresolved::Tuple{Vararg{String}}
    evidence_credit::Int
    request_hash::Digest256
end

semantic_view(x::WholeDeviceIntegrationRequestV4) = (
    revision=_WHOLE_DEVICE_INTEGRATION_REVISION,
    context_hash=x.context_hash, subject_hash=x.subject_hash,
    scenario_hash=x.scenario_hash, ecf_receipt_hash=x.ecf_receipt_hash,
    bridge_hash=x.bridge_hash, upstream_result_identity=x.upstream_result_identity,
    stage_ids=x.stage_ids, status=x.status,
    unresolved=x.unresolved, evidence_credit=x.evidence_credit)

function canonical_hash(x::WholeDeviceIntegrationRequestV4)
    x.status === :screen_only_deferred && x.evidence_credit == 0 &&
        x.stage_ids == _WHOLE_DEVICE_STAGE_IDS &&
        x.unresolved == ("real multi-region provider is missing",
            "dedicated G3 receipt has no generic Validation/UQ provider bridge",
            "held-out physical validation is missing",
            "Validation/UQ artifacts are missing",
            "high-fidelity whole-device closure and terminal authority are missing") ||
        throw(ArgumentError("whole-device integration exceeds deferred authority"))
    canonical_hash(x.upstream_result_identity)
    h = canonical_hash(semantic_view(x))
    h == x.request_hash || throw(ArgumentError("whole-device integration hash mismatch"))
    h
end

function validate_whole_device_integration_request(
        registry::TrustedEngineeringControlFaultRegistryV4,
        context::ForwardChainContextV4,
        ecf_request::TrustedEngineeringControlFaultDispatchRequestV4,
        receipt::TrustedEngineeringControlFaultOperationalReceiptV4,
        bridge::EngineeringControlFaultValidationUQBridgeV4,
        request::WholeDeviceIntegrationRequestV4)
    validate_engineering_control_fault_vuq_bridge(registry, context,
        ecf_request, receipt, bridge)
    bridge.context_hash == context.context_hash &&
        bridge.subject_hash == context.subject.physical_subject_hash &&
        bridge.scenario_hash == context.scenario_hash &&
        bridge.ecf_receipt_hash == receipt.receipt_hash &&
        request.context_hash == context.context_hash &&
        request.subject_hash == context.subject.physical_subject_hash &&
        request.scenario_hash == context.scenario_hash &&
        request.ecf_receipt_hash == receipt.receipt_hash &&
        request.bridge_hash == bridge.bridge_hash &&
        semantic_view(request.upstream_result_identity) ==
            semantic_view(bridge.upstream_result_identity) &&
        request.stage_ids == _WHOLE_DEVICE_STAGE_IDS ||
        throw(ArgumentError("whole-device integration identity mismatch"))
    canonical_hash(request)
end

function make_whole_device_integration_request(
        context::ForwardChainContextV4,
        receipt::TrustedEngineeringControlFaultOperationalReceiptV4,
        bridge::EngineeringControlFaultValidationUQBridgeV4; stage_ids=())
    validate_engineering_control_fault_vuq_bridge(bridge)
    bridge.context_hash == context.context_hash ||
        throw(ArgumentError("whole-device bridge context mismatch"))
    bridge.ecf_receipt_hash == receipt.receipt_hash ||
        throw(ArgumentError("whole-device receipt/bridge mismatch"))
    identity = bridge.upstream_result_identity
    canonical_hash(identity)
    ids = Tuple(Symbol(x) for x in stage_ids)
    ids == _WHOLE_DEVICE_STAGE_IDS || throw(ArgumentError("whole-device stage contract mismatch"))
    gaps = ("real multi-region provider is missing",
        "dedicated G3 receipt has no generic Validation/UQ provider bridge",
        "held-out physical validation is missing",
        "Validation/UQ artifacts are missing",
        "high-fidelity whole-device closure and terminal authority are missing")
    body = (revision=_WHOLE_DEVICE_INTEGRATION_REVISION,
        context_hash=context.context_hash,
        subject_hash=context.subject.physical_subject_hash,
        scenario_hash=context.scenario_hash,
        ecf_receipt_hash=receipt.receipt_hash, bridge_hash=bridge.bridge_hash,
        upstream_result_identity=identity,
        stage_ids=ids, status=:screen_only_deferred, unresolved=gaps,
        evidence_credit=0)
    x = WholeDeviceIntegrationRequestV4(body.context_hash, body.subject_hash,
        body.scenario_hash, body.ecf_receipt_hash, body.bridge_hash,
        body.upstream_result_identity, body.stage_ids,
        body.status, body.unresolved, 0, canonical_hash(body))
    canonical_hash(x)
    x
end

validate_whole_device_integration_request(
    x::WholeDeviceIntegrationRequestV4) = canonical_hash(x)
