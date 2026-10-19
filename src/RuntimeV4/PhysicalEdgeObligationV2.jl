"""Assessment-time revalidation for isolated UP5 physical-edge receipts.

This module is intentionally not included by `FusionRuntimeV4.jl` or
`FusionConceptAI.jl`. V1 obligation/provider-state objects are treated as
untrusted snapshots: a readiness disposition requires the exact current
registry, context, typed request and typed receipt to pass the repository trust
validators again during every assessment. No provider is dispatched and no
queue or compiler state is changed here.
"""
module PhysicalEdgeObligationV2

import FusionConceptAI: Digest256, canonical_hash
import ..FusionRuntimeV4: ForwardChainContextV4,
    validate_forward_chain_context, TrustedProviderRegistryV4,
    validate_trusted_provider_registry, CapabilitySignatureV4,
    TrustedProviderDispatchRequestV4, TrustedProviderExecutionReceiptV4,
    validate_trusted_provider_dispatch_request,
    validate_trusted_provider_execution_receipt

const PEO1 = getfield(parentmodule(@__MODULE__), :PhysicalEdgeObligationV1)

export PhysicalEdgeLiveAttemptV2, assess_candidate_obligations_v2,
    live_attempt_manifest_v2

const _REVISION_V2 = "up5-physical-edge-live-receipt-assessment-v2"

"""A caller-carried live attempt; constructor visibility grants no trust.

The edge and obligation hashes are routing hints only. Assessment rechecks
them against the current typed edge set and calls the repository request and
receipt validators with the current registry and context.
"""
struct PhysicalEdgeLiveAttemptV2
    edge_identity_hash::Digest256
    obligation_hash::Digest256
    capability::CapabilitySignatureV4
    request::TrustedProviderDispatchRequestV4
    receipt::TrustedProviderExecutionReceiptV4
end

_deferred(reason; details=()) = (
    status=:deferred,
    activated=false,
    reasons=(reason, Tuple(details)...),
    claim_ceiling=:none,
    physical_validation=false,
    engineering_validation=false,
    candidate_discovery_credit=0,
    credible_device_count=0,
)

function _validated_gap_tuple(unresolved_nonterminals)
    gaps = Tuple(String(x) for x in unresolved_nonterminals)
    all(x -> !isempty(strip(x)) && isvalid(x), gaps) ||
        throw(ArgumentError("compiler gap labels must be nonempty valid text"))
    gaps
end

function _attempt_revalidates(context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4,
        obligations::Tuple{Vararg{PEO1.PhysicalEdgeObligationV1}},
        obligation::PEO1.PhysicalEdgeObligationV1,
        attempt::PhysicalEdgeLiveAttemptV2)
    attempt.edge_identity_hash == obligation.identity.identity_hash ||
        return (false, :live_attempt_edge_mismatch)
    attempt.obligation_hash == canonical_hash(obligation) ||
        return (false, :live_attempt_obligation_snapshot_mismatch)
    input = attempt.request.input
    input isa PEO1.PhysicalEdgeProviderInputV1 ||
        return (false, :live_attempt_missing_edge_bound_input)
    try
        canonical_hash(input)
        input.edge_identity_hash == obligation.identity.identity_hash ||
            return (false, :live_attempt_edge_input_mismatch)
        input.candidate_hash == context.candidate_hash ||
            return (false, :live_attempt_candidate_mismatch)
        input.genome_bundle_hash == context.candidate.canonical_hashes.genome_bundle_hash ||
            return (false, :live_attempt_genome_bundle_mismatch)
        input.context_hash == context.context_hash ||
            return (false, :live_attempt_context_mismatch)
        input.scenario_hash == context.scenario_hash ||
            return (false, :live_attempt_scenario_mismatch)
        input.capability_hash == canonical_hash(attempt.capability) ||
            return (false, :live_attempt_capability_mismatch)
        attempt.capability.operator == string(obligation.identity.operator_id,
            "@", obligation.identity.operator_version) ||
            return (false, :live_attempt_capability_edge_mismatch)
        attempt.request.status === :ready_for_dispatch ||
            return (false, :live_attempt_request_not_ready)
        validate_trusted_provider_dispatch_request(attempt.request, registry,
            context, attempt.capability, input) ||
            return (false, :live_request_revalidation_failed)
        validate_trusted_provider_execution_receipt(attempt.receipt,
            attempt.request, registry, context) ||
            return (false, :live_receipt_revalidation_failed)
        attempt.receipt.status === :completed && attempt.receipt.exit_code == 0 ||
            return (false, :live_provider_attempt_not_successful)

        # The V1 binder recomputes all edge, capability, request and receipt
        # bindings. It does not execute a provider. Compare its fresh state to
        # the cached V1 state rather than trusting constructor tokens or hashes.
        freshly_bound = PEO1.bind_trusted_provider_receipt_v1(obligation,
            obligations, context, registry, attempt.capability,
            attempt.request, attempt.receipt)
        freshly_bound.provider.receipt_state === :validated ||
            return (false, :live_receipt_binding_not_validated)
        freshly_bound.provider.provider_state === :completed ||
            return (false, :live_provider_attempt_not_completed)
        canonical_hash(freshly_bound.requirement) ==
            canonical_hash(obligation.requirement) ||
            return (false, :cached_capability_requirement_differs_from_live)
        canonical_hash(freshly_bound.provider) ==
            canonical_hash(obligation.provider) ||
            return (false, :cached_provider_state_differs_from_live)
        (true, :live_receipt_revalidated)
    catch
        (false, :live_receipt_revalidation_exception)
    end
end

"""Revalidate one current typed receipt per physical edge/root obligation.

Cached V1 `provider` state, its hash, and module-qualified constructors are not
trusted as evidence. The only successful status means the live receipt contract
was revalidated but the shared compiler/queue seam is still unwired. It never
activates a candidate or awards physical, engineering, or discovery credit.
"""
function assess_candidate_obligations_v2(
        context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4,
        obligations::Tuple{Vararg{PEO1.PhysicalEdgeObligationV1}},
        live_attempts::Tuple{Vararg{PhysicalEdgeLiveAttemptV2}};
        unresolved_nonterminals=())
    try
        validate_forward_chain_context(context)
        validate_trusted_provider_registry(registry)
        PEO1.validate_obligation_set_v1(context, obligations)
    catch
        return _deferred(:typed_obligation_set_invalid)
    end

    gaps = try
        _validated_gap_tuple(unresolved_nonterminals)
    catch
        return _deferred(:invalid_compiler_gap_input)
    end
    isempty(gaps) || return _deferred(:compiler_gap_has_no_edge_bound_resolution)
    isempty(obligations) && return _deferred(:candidate_has_no_typed_physical_edge_obligations)
    length(live_attempts) == length(obligations) ||
        return _deferred(:live_receipt_revalidation_required)

    identity_hashes = Tuple(x.identity.identity_hash for x in obligations)
    attempt_hashes = Tuple(x.edge_identity_hash for x in live_attempts)
    length(unique(attempt_hashes)) == length(attempt_hashes) ||
        return _deferred(:duplicate_live_edge_attempt)
    Set(attempt_hashes) == Set(identity_hashes) ||
        return _deferred(:live_attempt_set_has_missing_or_foreign_edge)

    request_hashes = Digest256[]
    receipt_hashes = Digest256[]
    for obligation in obligations
        matches = Tuple(a for a in live_attempts if
            a.edge_identity_hash == obligation.identity.identity_hash)
        length(matches) == 1 || return _deferred(:live_attempt_edge_ambiguous)
        attempt = only(matches)
        valid, reason = _attempt_revalidates(context, registry,
            obligations, obligation, attempt)
        valid || return _deferred(reason)
        push!(request_hashes, attempt.request.request_hash)
        push!(receipt_hashes, attempt.receipt.receipt_hash)
    end
    length(unique(request_hashes)) == length(request_hashes) ||
        return _deferred(:live_request_reused_across_edges)
    length(unique(receipt_hashes)) == length(receipt_hashes) ||
        return _deferred(:live_receipt_reused_across_edges)

    (status=:live_receipts_revalidated_unwired,
     activated=false,
     reasons=(:shared_compiler_queue_entry_not_wired,),
     claim_ceiling=:none,
     physical_validation=false,
     engineering_validation=false,
     candidate_discovery_credit=0,
     credible_device_count=0)
end

live_attempt_manifest_v2() = (
    schema="fusionconceptai:up5-physical-edge-live-attempt-v2",
    revision=_REVISION_V2,
    revalidates_at_assessment=true,
    consumes_current_registry_and_context=true,
    trusts_cached_provider_state=false,
    dispatches_provider=false,
    mutates_queue=false,
    shared_compiler_entry_wired=false,
    activation_authority=false,
    physical_validation_credit=0,
    engineering_validation_credit=0,
    candidate_discovery_credit=0,
    credible_device_count=0,
)

end # module PhysicalEdgeObligationV2
