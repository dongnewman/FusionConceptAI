"""Additive, isolated UP5 adapter from one active search entry to UP4-02B.

Include this file only in a RuntimeV4 composition that already defines
`CandidateQueueV4`/`Search.jl`, `ForwardChainContextV4`, and the real
`EngineeringFeedbackExecutionV1` executor. This file is intentionally not
included by the production runtime entry point. Its only positive outcome is a
bounded `screen_only` record; it never awards candidate-discovery or
engineering credit.
"""

import FusionConceptAI: Digest256, canonical_hash, digest256_text, semantic_view

const UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V1 =
    "UP5-SEARCH-ENGINEERING-FEEDBACK-BRIDGE-V1-R1"
const _UP5_SEFB_TOKEN_V1 = Ref{Nothing}(nothing)
const _UP5_SEFB_ROUTE_STATUSES_V1 = (:screen_only, :deferred, :failed)
const _UP5_SEFB_QUEUE_TRANSITIONS_V1 = (:deferred, :failed, :unchanged)

struct SearchEngineeringFeedbackRecordV1
    revision::String
    route_status::Symbol
    queue_transition::Symbol
    queue_status_after::Symbol
    queue_entry_ref::Digest256
    context_hash::Union{Nothing,Digest256}
    candidate_hash::Union{Nothing,Digest256}
    scenario_hash::Union{Nothing,Digest256}
    g3_hash::Union{Nothing,Digest256}
    request_digest::Digest256
    request_digest_kind::Symbol
    output_digest::Union{Nothing,Digest256}
    output_digest_kind::Union{Nothing,Symbol}
    evaluator_status::Union{Nothing,Symbol}
    failure_codes::Tuple{Vararg{Symbol}}
    exception_type::String
    exception_detail::String
    exception_digest::Union{Nothing,Digest256}
    accepted::Bool
    claim_ceiling::Symbol
    engineering_credit::Symbol
    physical_credit::Symbol
    r01_r10_credit::Symbol
    discovery_credit::Symbol
    score::Float64
    record_hash::Digest256

    function SearchEngineeringFeedbackRecordV1(token::Base.RefValue{Nothing},
            revision::String, route_status::Symbol, queue_transition::Symbol,
            queue_status_after::Symbol, queue_entry_ref::Digest256,
            context_hash::Union{Nothing,Digest256}, candidate_hash::Union{Nothing,Digest256},
            scenario_hash::Union{Nothing,Digest256}, g3_hash::Union{Nothing,Digest256},
            request_digest::Digest256, request_digest_kind::Symbol,
            output_digest::Union{Nothing,Digest256}, output_digest_kind::Union{Nothing,Symbol},
            evaluator_status::Union{Nothing,Symbol}, failure_codes::Tuple{Vararg{Symbol}},
            exception_type::String, exception_detail::String,
            exception_digest::Union{Nothing,Digest256}, accepted::Bool,
            claim_ceiling::Symbol, engineering_credit::Symbol, physical_credit::Symbol,
            r01_r10_credit::Symbol, discovery_credit::Symbol, score::Float64,
            record_hash::Digest256)
        token === _UP5_SEFB_TOKEN_V1 || throw(ArgumentError("private UP5 feedback record constructor"))
        revision == UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V1 ||
            throw(ArgumentError("UP5 feedback revision mismatch"))
        route_status in _UP5_SEFB_ROUTE_STATUSES_V1 || throw(ArgumentError("invalid UP5 route status"))
        queue_transition in _UP5_SEFB_QUEUE_TRANSITIONS_V1 || throw(ArgumentError("invalid UP5 queue transition"))
        request_digest_kind in (:canonical, :repr_fallback) || throw(ArgumentError("invalid request digest kind"))
        output_digest_kind in (nothing, :canonical, :repr_fallback) ||
            throw(ArgumentError("invalid output digest kind"))
        (output_digest === nothing) == (output_digest_kind === nothing) ||
            throw(ArgumentError("output digest and kind must be present together"))
        (exception_digest === nothing) == (isempty(exception_type) && isempty(exception_detail)) ||
            throw(ArgumentError("exception details and digest must be present together"))
        accepted === false && claim_ceiling === :screen_only ||
            throw(ArgumentError("UP5 bridge cannot issue acceptance"))
        engineering_credit === :none && physical_credit === :none &&
            r01_r10_credit === :none && discovery_credit === :none && score === 0.0 ||
            throw(ArgumentError("UP5 bridge credit must remain none/zero"))
        body = _up5_sefb_record_body_v1(revision, route_status, queue_transition,
            queue_status_after, queue_entry_ref, context_hash, candidate_hash,
            scenario_hash, g3_hash, request_digest, request_digest_kind,
            output_digest, output_digest_kind, evaluator_status, failure_codes,
            exception_type, exception_detail, exception_digest, accepted,
            claim_ceiling, engineering_credit, physical_credit, r01_r10_credit,
            discovery_credit, score)
        canonical_hash(body) == record_hash || throw(ArgumentError("UP5 feedback record hash mismatch"))
        new(revision, route_status, queue_transition, queue_status_after,
            queue_entry_ref, context_hash, candidate_hash, scenario_hash, g3_hash,
            request_digest, request_digest_kind, output_digest, output_digest_kind,
            evaluator_status, failure_codes, exception_type, exception_detail,
            exception_digest, accepted, claim_ceiling, engineering_credit,
            physical_credit, r01_r10_credit, discovery_credit, score, record_hash)
    end
end

function _up5_sefb_record_body_v1(revision, route_status, queue_transition,
        queue_status_after, queue_entry_ref, context_hash, candidate_hash,
        scenario_hash, g3_hash, request_digest, request_digest_kind,
        output_digest, output_digest_kind, evaluator_status, failure_codes,
        exception_type, exception_detail, exception_digest, accepted,
        claim_ceiling, engineering_credit, physical_credit, r01_r10_credit,
        discovery_credit, score)
    (schema="fusionconceptai:up5-search-engineering-feedback-bridge-v1",
        revision=revision, route_status=route_status,
        queue_transition=queue_transition, queue_status_after=queue_status_after,
        queue_entry_ref=queue_entry_ref, context_hash=context_hash,
        candidate_hash=candidate_hash, scenario_hash=scenario_hash, g3_hash=g3_hash,
        request_digest=request_digest, request_digest_kind=request_digest_kind,
        output_digest=output_digest, output_digest_kind=output_digest_kind,
        evaluator_status=evaluator_status, failure_codes=failure_codes,
        exception_type=exception_type, exception_detail=exception_detail,
        exception_digest=exception_digest, accepted=accepted,
        claim_ceiling=claim_ceiling, engineering_credit=engineering_credit,
        physical_credit=physical_credit, r01_r10_credit=r01_r10_credit,
        discovery_credit=discovery_credit, score=score)
end

semantic_view(x::SearchEngineeringFeedbackRecordV1) = merge(
    _up5_sefb_record_body_v1(x.revision, x.route_status, x.queue_transition,
        x.queue_status_after, x.queue_entry_ref, x.context_hash, x.candidate_hash,
        x.scenario_hash, x.g3_hash, x.request_digest, x.request_digest_kind,
        x.output_digest, x.output_digest_kind, x.evaluator_status, x.failure_codes,
        x.exception_type, x.exception_detail, x.exception_digest, x.accepted,
        x.claim_ceiling, x.engineering_credit, x.physical_credit,
        x.r01_r10_credit, x.discovery_credit, x.score),
    (record_hash=x.record_hash,))

canonical_hash(x::SearchEngineeringFeedbackRecordV1) = begin
    body = _up5_sefb_record_body_v1(x.revision, x.route_status,
        x.queue_transition, x.queue_status_after, x.queue_entry_ref,
        x.context_hash, x.candidate_hash, x.scenario_hash, x.g3_hash,
        x.request_digest, x.request_digest_kind, x.output_digest,
        x.output_digest_kind, x.evaluator_status, x.failure_codes,
        x.exception_type, x.exception_detail, x.exception_digest, x.accepted,
        x.claim_ceiling, x.engineering_credit, x.physical_credit,
        x.r01_r10_credit, x.discovery_credit, x.score)
    expected = canonical_hash(body)
    expected == x.record_hash || throw(ArgumentError("UP5 feedback record hash mismatch"))
    expected
end

function _up5_sefb_digest_v1(value, label::String)
    try
        return (digest=canonical_hash(value), kind=:canonical, error=nothing)
    catch err
        rendered = try
            sprint(show, value)
        catch
            "<unrenderable>"
        end
        fallback = digest256_text("UP5-SEFB-V1-RAW-REPR|" * label * "|" *
            string(typeof(value)) * "|" * rendered)
        return (digest=fallback, kind=:repr_fallback, error=err)
    end
end

function _up5_sefb_exception_v1(err)
    kind = string(typeof(err))
    detail = sprint(showerror, err)
    (kind=kind, detail=detail,
        digest=digest256_text("UP5-SEFB-V1-EXCEPTION|" * kind * "|" * detail))
end

function _up5_sefb_finish_v1(queue, entry_ref, route_status, request_digest,
        request_digest_kind; context_hash=nothing, candidate_hash=nothing,
        scenario_hash=nothing, g3_hash=nothing, output_digest=nothing,
        output_digest_kind=nothing, evaluator_status=nothing, failure_codes=(),
        exception=nothing)
    current = get(queue.entries, entry_ref, nothing)
    if current !== nothing && current.status === :active
        queue_transition = route_status === :failed ? :failed : :deferred
        updated = queue_transition === :failed ? mark_failed!(queue, entry_ref) :
            mark_deferred!(queue, entry_ref)
        queue_status_after = updated.status
    else
        queue_transition = :unchanged
        queue_status_after = current === nothing ? :absent : current.status
    end
    failures = Tuple(sort(unique(Symbol(x) for x in failure_codes), by=String))
    ex = exception === nothing ?
        (kind="", detail="", digest=nothing) : exception
    body = _up5_sefb_record_body_v1(
        UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V1, route_status,
        queue_transition, queue_status_after, entry_ref, context_hash,
        candidate_hash, scenario_hash, g3_hash, request_digest,
        request_digest_kind, output_digest, output_digest_kind,
        evaluator_status, failures, ex.kind, ex.detail, ex.digest, false,
        :screen_only, :none, :none, :none, :none, 0.0)
    SearchEngineeringFeedbackRecordV1(_UP5_SEFB_TOKEN_V1,
        UP5_SEARCH_ENGINEERING_FEEDBACK_BRIDGE_REVISION_V1, route_status,
        queue_transition, queue_status_after, entry_ref, context_hash,
        candidate_hash, scenario_hash, g3_hash, request_digest,
        request_digest_kind, output_digest, output_digest_kind,
        evaluator_status, failures, ex.kind, ex.detail, ex.digest, false,
        :screen_only, :none, :none, :none, :none, 0.0, canonical_hash(body))
end

function _up5_sefb_g3_present_v1(candidate)
    hasproperty(candidate, :realization_control_genome_ref) || return false
    g3 = candidate.realization_control_genome_ref
    hasproperty(g3, :realization) && hasproperty(g3, :control) || return false
    !isempty(g3.realization) && !isempty(g3.control)
end

"""Run real UP4-02B feedback for one identity-matched active queue entry.

The caller must supply a freshly validated `ForwardChainContextV4` assembled
from the same compiled prefix as the active Search entry. Identity or G3
absence is typed as deferred without invoking the evaluator. Evaluator `:pass`
maps only to the bridge label `:screen_only`, and to Search's existing
`deferred` state, because UP4-02B is a reduced SI screen with no admission or
engineering credit.
"""
function route_search_engineering_feedback!(queue::CandidateQueueV4,
        entry_ref::Digest256, context::ForwardChainContextV4,
        request::EngineeringFeedbackExecutionRequestV1;
        executor::Function=execute_engineering_feedback)
    request_pin = _up5_sefb_digest_v1(request, "request")
    request_digest = request_pin.digest
    request_digest_kind = request_pin.kind

    current = get(queue.entries, entry_ref, nothing)
    current === nothing && return _up5_sefb_finish_v1(queue, entry_ref,
        :deferred, request_digest, request_digest_kind;
        failure_codes=(:search_entry_absent,))
    current.status === :active || return _up5_sefb_finish_v1(queue, entry_ref,
        :deferred, request_digest, request_digest_kind;
        failure_codes=(:search_entry_not_active,))
    current.candidate_ref == entry_ref && current.compiled.prefix_hash == entry_ref ||
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind;
            failure_codes=(:search_prefix_identity_mismatch,))

    request_pin.error === nothing || begin
        ex = _up5_sefb_exception_v1(request_pin.error)
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind;
            failure_codes=(:request_hash_validation_failed,), exception=ex)
    end

    context_hash = nothing
    candidate_hash = nothing
    scenario_hash = nothing
    g3_hash = nothing
    try
        context_hash = validate_forward_chain_context(context)
        candidate_hash = _forward_candidate_identity(context.candidate)
        scenario_hash = canonical_hash(context.scenario)
        g3_hash = canonical_hash(context.candidate.realization_control_genome_ref)
    catch err
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind; context_hash,
            failure_codes=(:forward_context_invalid,),
            exception=_up5_sefb_exception_v1(err))
    end

    queue_candidate_hash = try
        _forward_candidate_identity(current.candidate)
    catch err
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, failure_codes=(:search_candidate_invalid,),
            exception=_up5_sefb_exception_v1(err))
    end
    failures = Symbol[]
    context.compiled.prefix_hash == entry_ref || push!(failures, :context_prefix_mismatch)
    current.compiled.prefix_hash == context.compiled.prefix_hash ||
        push!(failures, :queue_context_prefix_mismatch)
    queue_candidate_hash == candidate_hash || push!(failures, :candidate_identity_mismatch)
    current.candidate.canonical_hashes == context.candidate.canonical_hashes ||
        push!(failures, :candidate_genome_bundle_mismatch)
    request.candidate_hash == candidate_hash || push!(failures, :request_candidate_mismatch)
    request.scenario_hash == scenario_hash || push!(failures, :request_scenario_mismatch)
    request.g3_hash == g3_hash || push!(failures, :request_g3_mismatch)
    if !isempty(failures)
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, failure_codes=failures)
    end

    if !_up5_sefb_g3_present_v1(context.candidate)
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash,
            failure_codes=(:missing_g3_realization_control_payload,))
    end

    result = try
        executor(request)
    catch err
        return _up5_sefb_finish_v1(queue, entry_ref, :failed,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, evaluator_status=:program_exception,
            failure_codes=(:evaluator_exception,),
            exception=_up5_sefb_exception_v1(err))
    end

    result isa EngineeringFeedbackExecutionV1 || begin
        output_pin = _up5_sefb_digest_v1(result, "evaluator-output")
        ex = (kind="EvaluatorOutputTypeMismatch",
            detail="UP4-02B executor returned $(typeof(result)); expected EngineeringFeedbackExecutionV1",
            digest=digest256_text("UP5-SEFB-V1-EXCEPTION|EvaluatorOutputTypeMismatch|" * string(typeof(result))))
        return _up5_sefb_finish_v1(queue, entry_ref, :failed,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=:program_exception,
            failure_codes=(:evaluator_output_type_mismatch,), exception=ex)
    end

    output_pin = _up5_sefb_digest_v1(result, "evaluator-output")
    output_pin.error === nothing || begin
        return _up5_sefb_finish_v1(queue, entry_ref, :failed,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=:program_exception,
            failure_codes=(:evaluator_output_hash_invalid,),
            exception=_up5_sefb_exception_v1(output_pin.error))
    end

    output_failures = Symbol[]
    result.candidate_hash == candidate_hash || push!(output_failures, :output_candidate_mismatch)
    result.scenario_hash == scenario_hash || push!(output_failures, :output_scenario_mismatch)
    result.g3_hash == g3_hash || push!(output_failures, :output_g3_mismatch)
    result.shir_hash == request.shir_hash || push!(output_failures, :output_shir_mismatch)
    result.bridge_hash == request.bridge_hash || push!(output_failures, :output_bridge_mismatch)
    result.upstream_execution_hash == request.upstream_execution_hash ||
        push!(output_failures, :output_upstream_mismatch)
    result.load_sample_hash == request.load_sample_hash ||
        push!(output_failures, :output_load_sample_mismatch)
    (result.accepted === false && result.claim_ceiling === :screen_only &&
        result.engineering_credit === :none && result.physical_credit === :none &&
        result.r01_r10_credit === :none && result.component_load === false &&
        result.component_load_admitted === false) || push!(output_failures, :output_claim_ceiling_violation)
    if !isempty(output_failures)
        return _up5_sefb_finish_v1(queue, entry_ref, :failed,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=result.status,
            failure_codes=output_failures)
    end

    if result.status === :pass
        return _up5_sefb_finish_v1(queue, entry_ref, :screen_only,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=result.status)
    elseif result.status in (:fail_closed, :terminal_deferred)
        return _up5_sefb_finish_v1(queue, entry_ref, :deferred,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=result.status,
            failure_codes=result.failures)
    elseif result.status in (:numerical_fail, :physical_fail, :program_exception)
        return _up5_sefb_finish_v1(queue, entry_ref, :failed,
            request_digest, request_digest_kind; context_hash, candidate_hash,
            scenario_hash, g3_hash, output_digest=output_pin.digest,
            output_digest_kind=output_pin.kind, evaluator_status=result.status,
            failure_codes=result.failures)
    end

    _up5_sefb_finish_v1(queue, entry_ref, :failed,
        request_digest, request_digest_kind; context_hash, candidate_hash,
        scenario_hash, g3_hash, output_digest=output_pin.digest,
        output_digest_kind=output_pin.kind, evaluator_status=result.status,
        failure_codes=(:unknown_evaluator_status,))
end
