"""Isolated V2 dispatch guard around the V1 typed Search-to-FreeGS request.

This module is deliberately not included by `FusionRuntimeV4.jl`. It serializes
calls made through this V2 API and fails closed if the active queue snapshot
changes before or during trusted dispatch. `CandidateQueueV4` mutation methods
do not share this lock, so callers must keep the queue single-owned for the
whole prepare/dispatch interval. A post-dispatch drift is recorded as deferred;
it cannot undo an executor that has already started. All outputs remain
`screen_only` at most, with zero discovery or engineering credit.
"""
module SearchPhysicalConsumerV2

using FusionConceptAI: Digest256, ClaimCeiling, screen_only, none
import FusionConceptAI: canonical_hash, semantic_view
using ..FusionRuntimeV4: CandidateQueueV4, ForwardChainContextV4,
    TrustedProviderRegistryV4, TrustedProviderExecutionReceiptV4,
    validate_trusted_provider_execution_receipt, execute_trusted_provider
using ..FusionRuntimeV4: SearchPhysicalConsumerV1

const _SPC2_STATES = (:ready_for_dispatch, :deferred, :not_executed,
    :screen_only, :program_exception)
const _SPC2_OWNER_GUARD = ReentrantLock()
struct _SPC2DispatchLease
    owner_task::Task
    token::UInt64
    entry_ref::Digest256
    queue_fingerprint::Digest256
end
const _SPC2_QUEUE_OWNERS = WeakKeyDict{CandidateQueueV4,_SPC2DispatchLease}()
const _SPC2_DISPATCHED = WeakKeyDict{CandidateQueueV4,Set{Digest256}}()
const _SPC2_NEXT_TOKEN = Ref{UInt64}(0)

# V1 defined this projection in a local generic. Register it on the package
# generic so nested V1 records serialize through FusionConceptAI.canonical_json.
semantic_view(x::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1) =
    SearchPhysicalConsumerV1.semantic_view(x)

struct SearchPhysicalConsumerReceiptV2
    state::Symbol
    inner::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1
    queue_fingerprint_before::Union{Nothing,Digest256}
    queue_fingerprint_after::Union{Nothing,Digest256}
    queue_owner_token::Union{Nothing,UInt64}
    queue_stable::Bool
    request_hash::Union{Nothing,Digest256}
    provider_status::Union{Nothing,Symbol}
    trusted_receipt_hash::Union{Nothing,Digest256}
    output_hash::Union{Nothing,Digest256}
    failure_code::Union{Nothing,Symbol}
    claim_ceiling::ClaimCeiling
    physical_validation::Bool
    engineering_validation::Bool
    candidate_discovery_credit::Int
    credible_device_count::Int
    record_hash::Digest256
end

function _spc2_body(state, inner, queue_fingerprint_before,
        queue_fingerprint_after, queue_owner_token, queue_stable,
        request_hash, provider_status, trusted_receipt_hash, output_hash,
        failure_code, claim_ceiling, physical_validation,
        engineering_validation, candidate_discovery_credit,
        credible_device_count)
    (schema="fusionconceptai:runtime-v4-search-physical-consumer-receipt",
     revision="search-physical-consumer-v2", state=state,
     inner=inner, queue_fingerprint_before=queue_fingerprint_before,
     queue_fingerprint_after=queue_fingerprint_after,
     queue_owner_token=queue_owner_token, queue_stable=queue_stable,
     request_hash=request_hash, provider_status=provider_status,
     trusted_receipt_hash=trusted_receipt_hash, output_hash=output_hash,
     failure_code=failure_code, claim_ceiling=claim_ceiling,
     physical_validation=physical_validation,
     engineering_validation=engineering_validation,
     candidate_discovery_credit=candidate_discovery_credit,
     credible_device_count=credible_device_count)
end

function _spc2_make_record(inner::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1;
        state::Symbol=inner.state,
        queue_fingerprint_before=nothing, queue_fingerprint_after=nothing,
        queue_owner_token=nothing, queue_stable=false,
        failure_code=inner.failure_code)
    state in _SPC2_STATES || throw(ArgumentError("invalid V2 consumer state"))
    ceiling = state === :screen_only ? screen_only : none
    body = _spc2_body(state, inner, queue_fingerprint_before,
        queue_fingerprint_after, queue_owner_token, queue_stable,
        inner.request_hash, inner.provider_status, inner.trusted_receipt_hash,
        inner.output_hash, failure_code, ceiling, false, false, 0, 0)
    record = SearchPhysicalConsumerReceiptV2(state, inner,
        queue_fingerprint_before, queue_fingerprint_after, queue_owner_token,
        queue_stable, inner.request_hash, inner.provider_status,
        inner.trusted_receipt_hash, inner.output_hash, failure_code, ceiling,
        false, false, 0, 0, canonical_hash(body))
    canonical_hash(record)
    record
end

function canonical_hash(x::SearchPhysicalConsumerReceiptV2)
    x.state in _SPC2_STATES || throw(ArgumentError("invalid V2 consumer state"))
    canonical_hash(x.inner)
    x.request_hash == x.inner.request_hash ||
        throw(ArgumentError("V2 request hash detached from inner receipt"))
    x.provider_status == x.inner.provider_status ||
        throw(ArgumentError("V2 provider status detached from inner receipt"))
    x.trusted_receipt_hash == x.inner.trusted_receipt_hash &&
        x.output_hash == x.inner.output_hash ||
        throw(ArgumentError("V2 raw provider hashes detached from inner receipt"))
    x.claim_ceiling == (x.state === :screen_only ? screen_only : none) ||
        throw(ArgumentError("V2 claim ceiling exceeds state"))
    !x.physical_validation && !x.engineering_validation &&
        x.candidate_discovery_credit == 0 && x.credible_device_count == 0 ||
        throw(ArgumentError("V2 consumer receipt exceeds screen-only authority"))
    if x.state === :screen_only
        x.inner.state === :screen_only && x.inner.trusted_receipt !== nothing &&
            x.queue_stable && x.queue_fingerprint_before !== nothing &&
            x.queue_fingerprint_before == x.queue_fingerprint_after &&
            x.queue_owner_token !== nothing && x.failure_code === nothing ||
            throw(ArgumentError("V2 screen-only result lacks a stable serialized dispatch"))
    end
    if x.inner.trusted_receipt !== nothing
        x.inner.trusted_receipt_hash == x.inner.trusted_receipt.receipt_hash &&
            x.inner.output_hash == x.inner.trusted_receipt.output_hash ||
            throw(ArgumentError("V2 provider hashes do not bind raw receipt"))
    end
    body = _spc2_body(x.state, x.inner, x.queue_fingerprint_before,
        x.queue_fingerprint_after, x.queue_owner_token, x.queue_stable,
        x.request_hash, x.provider_status, x.trusted_receipt_hash,
        x.output_hash, x.failure_code, x.claim_ceiling,
        x.physical_validation, x.engineering_validation,
        x.candidate_discovery_credit, x.credible_device_count)
    expected = canonical_hash(body)
    expected == x.record_hash || throw(ArgumentError("V2 record hash mismatch"))
    expected
end

semantic_view(x::SearchPhysicalConsumerReceiptV2) = (
    state=x.state, inner=x.inner,
    queue_fingerprint_before=x.queue_fingerprint_before,
    queue_fingerprint_after=x.queue_fingerprint_after,
    queue_owner_token=x.queue_owner_token, queue_stable=x.queue_stable,
    request_hash=x.request_hash, provider_status=x.provider_status,
    trusted_receipt_hash=x.trusted_receipt_hash, output_hash=x.output_hash,
    failure_code=x.failure_code, claim_ceiling=x.claim_ceiling,
    physical_validation=x.physical_validation,
    engineering_validation=x.engineering_validation,
    candidate_discovery_credit=x.candidate_discovery_credit,
    credible_device_count=x.credible_device_count, record_hash=x.record_hash)

function _spc2_queue_fingerprint(queue::CandidateQueueV4, entry_ref::Digest256)
    entry = get(queue.entries, entry_ref, nothing)
    entry === nothing && return nothing
    canonical_hash((candidate_ref=entry.candidate_ref, status=entry.status,
        registry_hash=entry.registry_hash,
        prefix_hash=entry.compiled.prefix_hash,
        compilation_status=entry.compiled.compilation_status,
        unresolved_nonterminals=Tuple(String(x) for x in
            entry.compiled.unresolved_nonterminals),
        candidate_hashes=entry.candidate.canonical_hashes,
        compiled_candidate_hashes=entry.compiled.candidate.canonical_hashes,
        parent_refs=entry.parent_refs, proposal_refs=entry.proposal_refs,
        priority=entry.priority))
end

function _spc2_claim_dispatch!(queue::CandidateQueueV4,
        entry_ref::Digest256, expected::Union{Nothing,Digest256})
    lock(_SPC2_OWNER_GUARD) do
        haskey(_SPC2_QUEUE_OWNERS, queue) &&
            return (lease=nothing, failure_code=:queue_owner_busy)
        entry = get(queue.entries, entry_ref, nothing)
        entry === nothing && return (lease=nothing,
            failure_code=:search_entry_missing)
        entry.status === :active || return (lease=nothing,
            failure_code=:search_entry_not_active)
        current = _spc2_queue_fingerprint(queue, entry_ref)
        current == expected || return (lease=nothing,
            failure_code=:queue_changed_before_dispatch)
        dispatched = get!(_SPC2_DISPATCHED, queue, Set{Digest256}())
        entry_ref in dispatched && return (lease=nothing,
            failure_code=:already_dispatched)
        _SPC2_NEXT_TOKEN[] += UInt64(1)
        lease = _SPC2DispatchLease(current_task(), _SPC2_NEXT_TOKEN[],
            entry_ref, current)
        _SPC2_QUEUE_OWNERS[queue] = lease
        (lease=lease, failure_code=nothing)
    end
end

function _spc2_dispatch_gate(queue::CandidateQueueV4,
        entry_ref::Digest256, lease::_SPC2DispatchLease)
    lock(_SPC2_OWNER_GUARD) do
        get(_SPC2_QUEUE_OWNERS, queue, nothing) === lease ||
            return (allowed=false, failure_code=:queue_owner_lost)
        current_task() === lease.owner_task ||
            return (allowed=false, failure_code=:queue_owner_task_mismatch)
        entry = get(queue.entries, entry_ref, nothing)
        entry !== nothing && entry.status === :active ||
            return (allowed=false, failure_code=:search_entry_not_active)
        _spc2_queue_fingerprint(queue, entry_ref) == lease.queue_fingerprint ||
            return (allowed=false, failure_code=:queue_changed_before_dispatch)
        (allowed=true, failure_code=nothing)
    end
end

function _spc2_mark_dispatched!(queue::CandidateQueueV4,
        entry_ref::Digest256, lease::_SPC2DispatchLease)
    lock(_SPC2_OWNER_GUARD) do
        get(_SPC2_QUEUE_OWNERS, queue, nothing) === lease || return false
        current_task() === lease.owner_task || return false
        entry = get(queue.entries, entry_ref, nothing)
        entry !== nothing && entry.status === :active || return false
        _spc2_queue_fingerprint(queue, entry_ref) == lease.queue_fingerprint ||
            return false
        push!(get!(_SPC2_DISPATCHED, queue, Set{Digest256}()), entry_ref)
        true
    end
end

function _spc2_release_dispatch!(queue::CandidateQueueV4,
        lease::_SPC2DispatchLease)
    lock(_SPC2_OWNER_GUARD) do
        get(_SPC2_QUEUE_OWNERS, queue, nothing) === lease || return false
        delete!(_SPC2_QUEUE_OWNERS, queue)
        true
    end
end

"""Prepare a typed request without acquiring a dispatch lease or running a provider."""
function prepare_search_physical_consumer_v2(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    before = try
        _spc2_queue_fingerprint(queue, entry_ref)
    catch
        nothing
    end
    inner = SearchPhysicalConsumerV1.prepare_search_physical_consumer(
        queue, entry_ref, context, registry)
    after = try
        _spc2_queue_fingerprint(queue, entry_ref)
    catch
        nothing
    end
    stable = before !== nothing && before == after
    state = stable ? inner.state :
        (inner.state === :ready_for_dispatch ? :not_executed : inner.state)
    failure = stable ? inner.failure_code : :queue_changed_during_prepare
    _spc2_make_record(inner; state=state,
        queue_fingerprint_before=before, queue_fingerprint_after=after,
        queue_stable=stable, failure_code=failure)
end

function _spc2_failure_record(queue, entry_ref, context, registry, inner;
        before, state, failure_code, token=nothing)
    after = try
        _spc2_queue_fingerprint(queue, entry_ref)
    catch
        nothing
    end
    _spc2_make_record(inner; state=state,
        queue_fingerprint_before=before, queue_fingerprint_after=after,
        queue_owner_token=token,
        queue_stable=before !== nothing && before == after,
        failure_code=failure_code)
end

function _spc2_finalize_execution(queue, entry_ref, context, registry,
        prepared::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1,
        lease::_SPC2DispatchLease,
        receipt::TrustedProviderExecutionReceiptV4)
    valid = _spc2_execution_receipt_valid(receipt, prepared, registry, context)
    if valid
        state, failure = SearchPhysicalConsumerV1._spc_post_execution_state(receipt)
        inner = SearchPhysicalConsumerV1._spc_make_record(queue, entry_ref,
            context, registry; state=state, failure_code=failure,
            capability=prepared.capability, input=prepared.input,
            request=prepared.request, trusted_receipt=receipt)
    else
        inner = SearchPhysicalConsumerV1._spc_make_record(queue, entry_ref,
            context, registry; state=:program_exception,
            failure_code=:trusted_receipt_invalid,
            gaps=("trusted_execution_receipt_failed_revalidation",),
            capability=prepared.capability, input=prepared.input,
            request=prepared.request, trusted_receipt=receipt)
    end
    after = try
        _spc2_queue_fingerprint(queue, entry_ref)
    catch
        nothing
    end
    stable = after !== nothing && after == lease.queue_fingerprint
    outer_state = stable ? inner.state : :deferred
    failure = stable ? inner.failure_code : :queue_changed_during_dispatch
    _spc2_make_record(inner; state=outer_state,
        queue_fingerprint_before=lease.queue_fingerprint,
        queue_fingerprint_after=after, queue_owner_token=lease.token,
        queue_stable=stable, failure_code=failure)
end

_spc2_execution_receipt_valid(receipt::TrustedProviderExecutionReceiptV4,
    prepared::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1,
    registry::TrustedProviderRegistryV4, context::ForwardChainContextV4) =
        validate_trusted_provider_execution_receipt(receipt,
            prepared.request, registry, context)

function _spc2_execution_exception(queue, entry_ref, context, registry,
        prepared, lease::_SPC2DispatchLease, error)
    inner = SearchPhysicalConsumerV1._spc_make_record(queue, entry_ref,
        context, registry; state=:program_exception,
        failure_code=:trusted_dispatch_exception,
        failure_type=string(typeof(error)),
        failure_message=sprint(showerror, error),
        capability=prepared.capability, input=prepared.input,
        request=prepared.request)
    _spc2_failure_record(queue, entry_ref, context, registry, inner;
        before=lease.queue_fingerprint, state=:program_exception,
        failure_code=:trusted_dispatch_exception, token=lease.token)
end

"""Execute the repository-owned provider under a V2 single-owner dispatch lease.

No executor callback is accepted. Direct mutation through shared Search queue
APIs is outside this module's lock; the caller must not mutate the queue during
this call. Pre-dispatch drift suppresses provider invocation. Post-dispatch
drift preserves the trusted raw receipt but demotes the result to `deferred`.
"""
function execute_search_physical_consumer_v2!(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    before = try
        _spc2_queue_fingerprint(queue, entry_ref)
    catch error
        inner = SearchPhysicalConsumerV1.prepare_search_physical_consumer(
            queue, entry_ref, context, registry)
        return _spc2_failure_record(queue, entry_ref, context, registry,
            inner; before=nothing, state=:program_exception,
            failure_code=:queue_snapshot_exception)
    end
    prepared = SearchPhysicalConsumerV1.prepare_search_physical_consumer(
        queue, entry_ref, context, registry)
    if prepared.state !== :ready_for_dispatch
        return _spc2_failure_record(queue, entry_ref, context, registry,
            prepared; before=before, state=prepared.state,
            failure_code=prepared.failure_code)
    end

    claim = try
        _spc2_claim_dispatch!(queue, entry_ref, before)
    catch error
        return _spc2_failure_record(queue, entry_ref, context, registry,
            prepared; before=before, state=:program_exception,
            failure_code=:dispatch_claim_exception)
    end
    claim.lease === nothing && return _spc2_failure_record(queue,
        entry_ref, context, registry, prepared; before=before,
        state=(claim.failure_code in
            (:queue_changed_before_dispatch, :search_entry_missing)) ?
            :not_executed : :deferred,
        failure_code=claim.failure_code)
    lease = claim.lease::_SPC2DispatchLease
    try
        gate = _spc2_dispatch_gate(queue, entry_ref, lease)
        gate.allowed || return _spc2_failure_record(queue, entry_ref,
            context, registry, prepared; before=before,
            state=:not_executed, failure_code=gate.failure_code,
            token=lease.token)
        _spc2_mark_dispatched!(queue, entry_ref, lease) ||
            return _spc2_failure_record(queue, entry_ref, context,
                registry, prepared; before=before, state=:not_executed,
                failure_code=:dispatch_claim_revalidation_failed,
                token=lease.token)
        request = prepared.request
        receipt = execute_trusted_provider(registry, context, request)
        _spc2_finalize_execution(queue, entry_ref, context, registry,
            prepared, lease, receipt)
    catch error
        _spc2_execution_exception(queue, entry_ref, context, registry,
            prepared, lease, error)
    finally
        _spc2_release_dispatch!(queue, lease)
    end
end

"""Revalidate V2 canonical integrity and its inner request against live inputs."""
function validate_search_physical_consumer_receipt_v2(record::SearchPhysicalConsumerReceiptV2,
        queue::CandidateQueueV4, context::ForwardChainContextV4,
        registry::TrustedProviderRegistryV4)
    try
        canonical_hash(record)
        SearchPhysicalConsumerV1.validate_search_physical_consumer_receipt(
            record.inner, queue, context, registry) || return false
        current = _spc2_queue_fingerprint(queue, record.inner.queue_entry_ref)
        current !== nothing && current == record.queue_fingerprint_after || return false
        record.state === :screen_only &&
            (!record.queue_stable || record.queue_fingerprint_before != current) &&
            return false
        true
    catch
        false
    end
end

end # module SearchPhysicalConsumerV2
