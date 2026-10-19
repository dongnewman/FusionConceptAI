"""Fail-atomic execution of the five native-source T2 identity consumers.

All outputs are built in scratch state.  A ledger becomes visible only after
E0, G-I1A, E1, E2, and N10 have each been invoked exactly once and
independently validated.  Attempted calls remain visible on exceptions.
"""

const VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2 =
    "GenomeV5/Integration/VNextT2IdentityReceiptIntegrationV2"
const VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2 = "v2"
const VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2 =
    "native-source-five-consumer-fail-atomic-v2"
const VNEXT_T2_CONSUMER_ORDER_V2 = (:E0, :GI1A, :E1, :E2, :UP2_N10)

struct VNextT2InvocationCountsV2
    e0::Int
    gi1a::Int
    e1::Int
    e2::Int
    n10::Int
    compiler::Int
    provider::Int
    solver::Int
end

VNextT2InvocationCountsV2() = VNextT2InvocationCountsV2(0, 0, 0, 0, 0, 0, 0, 0)
semantic_view(x::VNextT2InvocationCountsV2) =
    (e0=x.e0, gi1a=x.gi1a, e1=x.e1, e2=x.e2, n10=x.n10,
        compiler=x.compiler, provider=x.provider, solver=x.solver)
canonical_json(x::VNextT2InvocationCountsV2) = canonical_json(semantic_view(x))

function _vnext_t2_attempt_event_body_v2(sequence, consumer_id, input_hash,
        output_hash, status, resolution, reason)
    (domain="vnext-t2-consumer-attempt-event-v2", sequence=sequence,
        consumer_id=consumer_id, input_hash=input_hash,
        output_hash=output_hash, status=status, resolution=resolution,
        reason=reason)
end

struct VNextT2AttemptEventV2
    sequence::Int
    consumer_id::Symbol
    input_hash::Digest256
    output_hash::Union{Nothing,Digest256}
    status::Symbol
    resolution::Symbol
    reason::Symbol
    event_hash::Digest256
end

function _vnext_t2_attempt_event_v2(sequence::Int, consumer_id::Symbol,
        input_hash::Digest256, output_hash::Union{Nothing,Digest256},
        status::Symbol, resolution::Symbol, reason::Symbol)
    body = _vnext_t2_attempt_event_body_v2(sequence, consumer_id,
        input_hash, output_hash, status, resolution, reason)
    VNextT2AttemptEventV2(sequence, consumer_id, input_hash, output_hash,
        status, resolution, reason, canonical_hash(body))
end

semantic_view(x::VNextT2AttemptEventV2) = merge(
    _vnext_t2_attempt_event_body_v2(x.sequence, x.consumer_id,
        x.input_hash, x.output_hash, x.status, x.resolution, x.reason),
    (event_hash=x.event_hash,))
canonical_json(x::VNextT2AttemptEventV2) = canonical_json(semantic_view(x))

function _vnext_t2_attempt_trace_body_v2(input_hash, events, counts)
    (domain="vnext-t2-consumer-attempt-trace-v2", input_hash=input_hash,
        events=events, counts=counts)
end

struct VNextT2AttemptTraceV2
    input_hash::Digest256
    events::Tuple{Vararg{VNextT2AttemptEventV2}}
    counts::VNextT2InvocationCountsV2
    trace_hash::Digest256
end

function _vnext_t2_attempt_trace_v2(input_hash::Digest256,
        events::Tuple{Vararg{VNextT2AttemptEventV2}},
        counts::VNextT2InvocationCountsV2)
    body = _vnext_t2_attempt_trace_body_v2(input_hash, events, counts)
    VNextT2AttemptTraceV2(input_hash, events, counts, canonical_hash(body))
end

semantic_view(x::VNextT2AttemptTraceV2) = merge(
    _vnext_t2_attempt_trace_body_v2(x.input_hash, x.events, x.counts),
    (trace_hash=x.trace_hash,))
canonical_json(x::VNextT2AttemptTraceV2) = canonical_json(semantic_view(x))

function _vnext_t2_invocation_receipt_body_v2(consumer_id,
        t1_package_hash, candidate_ref, scenario, profile, input_hash,
        output_hash, invocation_count, status, resolution)
    (domain="vnext-t2-consumer-invocation-receipt-v2",
        consumer_id=consumer_id, t1_package_hash=t1_package_hash,
        candidate_ref=candidate_ref, scenario=scenario, profile=profile,
        input_hash=input_hash, output_hash=output_hash,
        invocation_count=invocation_count, status=status,
        resolution=resolution)
end

struct VNextT2InvocationReceiptV2
    consumer_id::Symbol
    t1_package_hash::Digest256
    candidate_ref::QualifiedRefV1
    scenario::String
    profile::String
    input_hash::Digest256
    output_hash::Digest256
    identity_hash::Digest256
    invocation_count::Int
    status::Symbol
    resolution::Symbol
end

function _vnext_t2_invocation_receipt_v2(consumer_id::Symbol,
        input::VNextT2UP2BoundInputV2, stage_input_hash::Digest256,
        output_hash::Digest256, status::Symbol, resolution::Symbol)
    body = _vnext_t2_invocation_receipt_body_v2(consumer_id,
        input.package.package_hash, input.package.candidate_ref,
        input.scenario, input.profile, stage_input_hash, output_hash, 1,
        status, resolution)
    VNextT2InvocationReceiptV2(consumer_id, input.package.package_hash,
        input.package.candidate_ref, input.scenario, input.profile,
        stage_input_hash, output_hash, canonical_hash(body), 1, status,
        resolution)
end

semantic_view(x::VNextT2InvocationReceiptV2) = merge(
    _vnext_t2_invocation_receipt_body_v2(x.consumer_id,
        x.t1_package_hash, x.candidate_ref, x.scenario, x.profile,
        x.input_hash, x.output_hash, x.invocation_count, x.status,
        x.resolution),
    (identity_hash=x.identity_hash,))
canonical_json(x::VNextT2InvocationReceiptV2) = canonical_json(semantic_view(x))

function _vnext_t2_receipt_ledger_body_v2(schema_id, schema_version,
        profile, candidate_ref, scenario, input_hash, package_hash, receipts,
        counts, status, resolution, accepted, claim_ceiling, gaps)
    (domain="vnext-t2-five-consumer-receipt-ledger-v2",
        schema_id=schema_id, schema_version=schema_version, profile=profile,
        candidate_ref=candidate_ref, scenario=scenario,
        input_hash=input_hash, package_hash=package_hash, receipts=receipts,
        counts=counts, status=status, resolution=resolution,
        accepted=accepted, claim_ceiling=claim_ceiling, gaps=gaps)
end

struct VNextT2ReceiptLedgerV2
    schema_id::String
    schema_version::String
    profile::String
    candidate_ref::QualifiedRefV1
    scenario::String
    input_hash::Digest256
    package_hash::Digest256
    receipts::NTuple{5,VNextT2InvocationReceiptV2}
    counts::VNextT2InvocationCountsV2
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    gaps::Tuple{Vararg{Symbol}}
    ledger_hash::Digest256
end

function _vnext_t2_receipt_ledger_v2(input::VNextT2UP2BoundInputV2,
        receipts::NTuple{5,VNextT2InvocationReceiptV2},
        counts::VNextT2InvocationCountsV2, gaps::Tuple{Vararg{Symbol}})
    Tuple(x.consumer_id for x in receipts) == VNEXT_T2_CONSUMER_ORDER_V2 ||
        throw(ArgumentError("T2 consumer receipt order mismatch"))
    all(x -> x.invocation_count == 1, receipts) ||
        throw(ArgumentError("T2 consumer receipt count mismatch"))
    counts == VNextT2InvocationCountsV2(1, 1, 1, 1, 1, 0, 0, 0) ||
        throw(ArgumentError("T2 ledger counts mismatch"))
    body = _vnext_t2_receipt_ledger_body_v2(
        VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2,
        VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2,
        VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2,
        input.package.candidate_ref, input.scenario, input.input_hash,
        input.package.package_hash, receipts, counts,
        :complete_contract_receipts, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2, gaps)
    VNextT2ReceiptLedgerV2(VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2,
        VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2,
        VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2,
        input.package.candidate_ref, input.scenario, input.input_hash,
        input.package.package_hash, receipts, counts,
        :complete_contract_receipts, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2, gaps, canonical_hash(body))
end

semantic_view(x::VNextT2ReceiptLedgerV2) = merge(
    _vnext_t2_receipt_ledger_body_v2(x.schema_id, x.schema_version,
        x.profile, x.candidate_ref, x.scenario, x.input_hash,
        x.package_hash, x.receipts, x.counts, x.status, x.resolution,
        x.accepted, x.claim_ceiling, x.gaps),
    (ledger_hash=x.ledger_hash,))
canonical_json(x::VNextT2ReceiptLedgerV2) = canonical_json(semantic_view(x))

function _vnext_t2_integration_result_body_v2(status, resolution, reason,
        committed, ledger, attempted_trace, committed_counts, errors, gaps)
    (domain="vnext-t2-identity-receipt-integration-result-v2",
        status=status, resolution=resolution, reason=reason,
        committed=committed, ledger=ledger, attempted_trace=attempted_trace,
        committed_counts=committed_counts, errors=errors, gaps=gaps)
end

struct VNextT2IdentityReceiptIntegrationResultV2
    status::Symbol
    resolution::Symbol
    reason::Symbol
    committed::Bool
    ledger::Union{Nothing,VNextT2ReceiptLedgerV2}
    attempted_trace::VNextT2AttemptTraceV2
    committed_counts::VNextT2InvocationCountsV2
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    result_hash::Digest256
end

function _vnext_t2_integration_result_v2(status::Symbol,
        resolution::Symbol, reason::Symbol, committed::Bool,
        ledger::Union{Nothing,VNextT2ReceiptLedgerV2},
        attempted_trace::VNextT2AttemptTraceV2,
        committed_counts::VNextT2InvocationCountsV2;
        errors::Tuple{Vararg{Symbol}}=(), gaps::Tuple{Vararg{Symbol}}=())
    body = _vnext_t2_integration_result_body_v2(status, resolution, reason,
        committed, ledger, attempted_trace, committed_counts, errors, gaps)
    VNextT2IdentityReceiptIntegrationResultV2(status, resolution, reason,
        committed, ledger, attempted_trace, committed_counts, errors, gaps,
        canonical_hash(body))
end

semantic_view(x::VNextT2IdentityReceiptIntegrationResultV2) = merge(
    _vnext_t2_integration_result_body_v2(x.status, x.resolution, x.reason,
        x.committed, x.ledger, x.attempted_trace, x.committed_counts,
        x.errors, x.gaps),
    (result_hash=x.result_hash,))
canonical_json(x::VNextT2IdentityReceiptIntegrationResultV2) =
    canonical_json(semantic_view(x))

function _vnext_t2_counts_v2(e0, gi1a, e1, e2, n10)
    VNextT2InvocationCountsV2(e0, gi1a, e1, e2, n10, 0, 0, 0)
end

function _vnext_t2_trace_from_work_v2(input_hash, events, counts)
    _vnext_t2_attempt_trace_v2(input_hash, Tuple(events), counts)
end

function _vnext_t2_prior_counts_v2(
        prior_ledger::Union{Nothing,VNextT2ReceiptLedgerV2})
    prior_ledger === nothing ? VNextT2InvocationCountsV2() : prior_ledger.counts
end

function _vnext_t2_zero_call_result_v2(input_hash::Digest256,
        status::Symbol, resolution::Symbol, reason::Symbol,
        prior_ledger::Union{Nothing,VNextT2ReceiptLedgerV2};
        errors::Tuple{Vararg{Symbol}}=(), gaps::Tuple{Vararg{Symbol}}=())
    counts = VNextT2InvocationCountsV2()
    trace = _vnext_t2_attempt_trace_v2(input_hash, (), counts)
    _vnext_t2_integration_result_v2(status, resolution, reason, false,
        prior_ledger, trace, _vnext_t2_prior_counts_v2(prior_ledger),
        errors=errors, gaps=gaps)
end

function _vnext_t2_stage_input_hash_v2(input_hash::Digest256,
        consumer_id::Symbol, upstream_hash::Digest256)
    canonical_hash((domain="vnext-t2-consumer-stage-input-v2",
        input_hash=input_hash, consumer_id=consumer_id,
        upstream_hash=upstream_hash))
end

function _vnext_t2_slot_valid_v2(slot::VNextT2AuthoritySlotV2,
        expected_slot::Symbol)
    slot.slot === expected_slot || return false
    slot.output_hash == canonical_hash(_vnext_t2_slot_body_v2(slot.slot,
        slot.status, slot.resolution, slot.reason,
        slot.observed_content_hash, slot.unsupported_capabilities,
        slot.errors, slot.gaps)) || return false
    slot.status in (:present, :typed_absent, :fail_closed) || return false
    slot.status === :present && slot.resolution !== :resolved && return false
    slot.status === :typed_absent &&
        slot.resolution !== :terminal_deferred && return false
    slot.status === :fail_closed && slot.resolution !== :none && return false
    slot.status === :fail_closed && isempty(slot.errors) && return false
    true
end

function _vnext_t2_context_valid_v2(input, e0, context)
    _vnext_t2_validate_gi1_context_v2(input, context) || return false
    context.e0_output_hash == e0.output_hash || return false
    true
end

function _vnext_t2_injected_fault_v2(fault_after_stage, stage)
    fault_after_stage === stage &&
        throw(ErrorException("injected T2 integration exception after $(stage)"))
    nothing
end

function _vnext_t2_stage_reason_v2(stage::Symbol, reason::Symbol)
    prefix = String(stage) * "_"
    startswith(String(reason), prefix) ? reason :
        Symbol(prefix * String(reason))
end

"""Run the five logical consumers once and publish their receipts atomically."""
function vnext_t2_rebind_identity_receipts_v2(
        input::VNextT2UP2BoundInputV2;
        prior_ledger::Union{Nothing,VNextT2ReceiptLedgerV2}=nothing,
        fault_after_stage::Union{Nothing,Symbol}=nothing)
    validation = vnext_t2_up2_validate_input_v2(input)
    validation.status === :valid || return _vnext_t2_zero_call_result_v2(
        input.input_hash, :fail_closed, :none, validation.reason,
        prior_ledger, errors=(validation.reason,))
    if prior_ledger !== nothing && prior_ledger.input_hash == input.input_hash
        return _vnext_t2_zero_call_result_v2(input.input_hash, :fail_closed,
            :none, :t2_preflight_duplicate_invocation, prior_ledger,
            errors=(:t2_preflight_duplicate_invocation,))
    end

    events = VNextT2AttemptEventV2[]
    e0_count = 0
    gi1a_count = 0
    e1_count = 0
    e2_count = 0
    n10_count = 0
    current_stage = :e0
    current_input_hash = input.input_hash
    current_recorded = false

    try
        e0_count += 1
        e0 = up2_candidate_physical_binding_from_a(input)
        push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
            :E0, current_input_hash, e0.output_hash, e0.status,
            e0.resolution, :none))
        current_recorded = true
        _vnext_t2_injected_fault_v2(fault_after_stage, :e0)

        current_stage = :gi1a
        current_recorded = false
        current_input_hash = _vnext_t2_stage_input_hash_v2(input.input_hash,
            :GI1A, e0.output_hash)
        gi1a_count += 1
        context = gi1_authority_context_from_a(input, e0)
        push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
            :GI1A, current_input_hash, context.context_hash,
            context.status, context.resolution, :none))
        current_recorded = true
        _vnext_t2_injected_fault_v2(fault_after_stage, :gi1a)
        _vnext_t2_context_valid_v2(input, e0, context) ||
            throw(VNextT2ConsumerFailureV2(:gi1a,
                :context_hash_mismatch))

        current_stage = :e1
        current_recorded = false
        current_input_hash = _vnext_t2_stage_input_hash_v2(input.input_hash,
            :E1, context.context_hash)
        e1_count += 1
        e1 = e1_authority_slot_from_a(input, context)
        push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
            :E1, current_input_hash, e1.output_hash, e1.status,
            e1.resolution, e1.reason))
        current_recorded = true
        _vnext_t2_injected_fault_v2(fault_after_stage, :e1)

        current_stage = :e2
        current_recorded = false
        current_input_hash = _vnext_t2_stage_input_hash_v2(input.input_hash,
            :E2, context.context_hash)
        e2_count += 1
        e2 = e2_authority_slot_from_a(input, context)
        push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
            :E2, current_input_hash, e2.output_hash, e2.status,
            e2.resolution, e2.reason))
        current_recorded = true
        _vnext_t2_injected_fault_v2(fault_after_stage, :e2)

        counts = _vnext_t2_counts_v2(e0_count, gi1a_count, e1_count,
            e2_count, n10_count)
        if !_vnext_t2_slot_valid_v2(e1, :E1)
            trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
                counts)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                :e1_slot_validation_failed, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger),
                errors=(:e1_slot_validation_failed,))
        elseif !_vnext_t2_slot_valid_v2(e2, :E2)
            trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
                counts)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                :e2_slot_validation_failed, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger),
                errors=(:e2_slot_validation_failed,))
        elseif e1.status === :fail_closed
            trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
                counts)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                e1.reason, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger),
                errors=isempty(e1.errors) ? (e1.reason,) : e1.errors)
        elseif e2.status === :fail_closed
            trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
                counts)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                e2.reason, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger),
                errors=isempty(e2.errors) ? (e2.reason,) : e2.errors)
        end

        current_stage = :up2
        current_recorded = false
        current_input_hash = _vnext_t2_stage_input_hash_v2(input.input_hash,
            :UP2_N10, input.formal_gate.identity_hash)
        n10_count += 1
        projection = n10_identity_projection_from_a(input)
        push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
            :UP2_N10, current_input_hash, projection.projection_hash,
            projection.status, projection.resolution, :none))
        current_recorded = true
        _vnext_t2_injected_fault_v2(fault_after_stage, :up2)
        projection_validation =
            vnext_t2_validate_identity_receipt_v2(projection)
        if projection_validation.status !== :valid
            counts = _vnext_t2_counts_v2(e0_count, gi1a_count, e1_count,
                e2_count, n10_count)
            trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
                counts)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                projection_validation.reason, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger),
                errors=(projection_validation.reason,))
        end

        counts = _vnext_t2_counts_v2(e0_count, gi1a_count, e1_count,
            e2_count, n10_count)
        receipts = (
            _vnext_t2_invocation_receipt_v2(:E0, input,
                input.input_hash, e0.output_hash, e0.status,
                e0.resolution),
            _vnext_t2_invocation_receipt_v2(:GI1A, input,
                _vnext_t2_stage_input_hash_v2(input.input_hash, :GI1A,
                    e0.output_hash), context.context_hash, context.status,
                context.resolution),
            _vnext_t2_invocation_receipt_v2(:E1, input,
                _vnext_t2_stage_input_hash_v2(input.input_hash, :E1,
                    context.context_hash), e1.output_hash, e1.status,
                e1.resolution),
            _vnext_t2_invocation_receipt_v2(:E2, input,
                _vnext_t2_stage_input_hash_v2(input.input_hash, :E2,
                    context.context_hash), e2.output_hash, e2.status,
                e2.resolution),
            _vnext_t2_invocation_receipt_v2(:UP2_N10, input,
                _vnext_t2_stage_input_hash_v2(input.input_hash, :UP2_N10,
                    input.formal_gate.identity_hash),
                projection.projection_hash, projection.status,
                projection.resolution))
        gaps = Tuple(unique((:compiler_not_executed,
            :provider_not_executed, :solver_not_executed,
            input.witness.gaps..., e0.gaps..., e1.gaps..., e2.gaps...,
            projection.gaps...)))
        ledger = _vnext_t2_receipt_ledger_v2(input, receipts, counts, gaps)
        trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
            counts)
        _vnext_t2_integration_result_v2(:complete_contract_receipts,
            :terminal_deferred, :none, true, ledger, trace, counts,
            gaps=gaps)
    catch error
        counts = _vnext_t2_counts_v2(e0_count, gi1a_count, e1_count,
            e2_count, n10_count)
        if !current_recorded
            consumer_id = current_stage === :e0 ? :E0 :
                current_stage === :gi1a ? :GI1A :
                current_stage === :e1 ? :E1 :
                current_stage === :e2 ? :E2 : :UP2_N10
            status = error isa VNextT2ConsumerFailureV2 ?
                :fail_closed : :program_exception
            push!(events, _vnext_t2_attempt_event_v2(length(events) + 1,
                consumer_id, current_input_hash, nothing, status, :none,
                status === :fail_closed ? error.reason :
                    _vnext_t2_stage_reason_v2(current_stage,
                        :program_exception)))
        end
        trace = _vnext_t2_trace_from_work_v2(input.input_hash, events,
            counts)
        if error isa VNextT2ConsumerFailureV2
            reason = _vnext_t2_stage_reason_v2(error.stage, error.reason)
            return _vnext_t2_integration_result_v2(:fail_closed, :none,
                reason, false, prior_ledger, trace,
                _vnext_t2_prior_counts_v2(prior_ledger), errors=(reason,))
        end
        reason = _vnext_t2_stage_reason_v2(current_stage,
            :program_exception)
        _vnext_t2_integration_result_v2(:program_exception, :none, reason,
            false, prior_ledger, trace,
            _vnext_t2_prior_counts_v2(prior_ledger), errors=(reason,))
    end
end

function vnext_t2_rebind_identity_receipts_v2(
        build::VNextT2UP2InputBuildResultV2;
        prior_ledger::Union{Nothing,VNextT2ReceiptLedgerV2}=nothing,
        fault_after_stage::Union{Nothing,Symbol}=nothing)
    build.status === :typed_absent && return _vnext_t2_zero_call_result_v2(
        build.input_hash, :typed_absent, :terminal_deferred, build.reason,
        prior_ledger, gaps=(build.reason,))
    build.status === :fail_closed && return _vnext_t2_zero_call_result_v2(
        build.input_hash, :fail_closed, :none, build.reason, prior_ledger,
        errors=(build.reason,))
    build.status === :prepared_not_executed &&
        build.input isa VNextT2UP2BoundInputV2 ||
        return _vnext_t2_zero_call_result_v2(build.input_hash,
            :fail_closed, :none, :t2_preflight_source_witness_shape_invalid,
            prior_ledger,
            errors=(:t2_preflight_source_witness_shape_invalid,))
    vnext_t2_rebind_identity_receipts_v2(build.input,
        prior_ledger=prior_ledger, fault_after_stage=fault_after_stage)
end

export VNEXT_T2_RECEIPT_LEDGER_SCHEMA_ID_V2,
    VNEXT_T2_RECEIPT_LEDGER_SCHEMA_VERSION_V2,
    VNEXT_T2_RECEIPT_LEDGER_PROFILE_V2,VNextT2InvocationCountsV2,
    VNextT2AttemptEventV2,VNextT2AttemptTraceV2,
    VNextT2InvocationReceiptV2,VNextT2ReceiptLedgerV2,
    VNextT2IdentityReceiptIntegrationResultV2,
    vnext_t2_rebind_identity_receipts_v2
