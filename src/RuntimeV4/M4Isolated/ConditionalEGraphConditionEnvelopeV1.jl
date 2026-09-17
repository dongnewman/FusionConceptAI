"""Isolated, contract-only condition and replay envelope for UP5-01.

This file is intentionally not included by the shared RuntimeV4 entry point.
It validates the semantic boundary around the existing bounded conditional
e-graph without transferring solver, evidence, provider, or physical credit.
"""

module ConditionalEGraphConditionEnvelopeV1

using SHA

export Digest256V1, digest_text, canonical_bytes, canonical_hash,
       ConditionSignatureV1, RequiredConditionV1, AvailableConditionV1,
       RequiredConditionCatalogV1, AvailableConditionCatalogV1,
       ConditionEvaluationV1, evaluate_conditions,
       ReceiptTokenV1, RewriteTraceStepV1, MergeReplayReceiptV1,
       MergeReplayResultV1, replay_merge, validate_replay_receipt,
       validate_replay_result,
       SaturationReceiptV1, make_saturation_receipt,
       CanonicalCacheEntryV1, CanonicalCacheV1, cache_put!, cache_get,
       cache_hash, cold_canonical_bytes, cold_canonical_hash,
       hot_canonical_bytes, hot_canonical_hash, validate_token

struct Digest256V1
    value::String
    function Digest256V1(value::AbstractString)
        v = lowercase(String(value))
        occursin(r"^[0-9a-f]{64}$", v) ||
            throw(ArgumentError("Digest256V1 must be 64 lowercase hex characters"))
        new(v)
    end
end
Base.string(x::Digest256V1) = x.value
Base.:(==)(a::Digest256V1, b::Digest256V1) = a.value == b.value
Base.hash(a::Digest256V1, h::UInt) = hash(a.value, h)

digest_text(x::AbstractString) = Digest256V1(bytes2hex(SHA.sha256(codeunits(String(x)))))

_nonempty(x, field) = begin
    v = String(x)
    isempty(strip(v)) && throw(ArgumentError("$field cannot be empty"))
    v
end

struct ConditionSignatureV1
    unit::String
    rank::Int
    domain::String
    boundary::String
    time::String
    effect::String
    conservation::String
    function ConditionSignatureV1(unit, rank::Integer, domain, boundary, time, effect, conservation)
        rank >= 0 || throw(ArgumentError("condition rank must be non-negative"))
        new(_nonempty(unit, "unit"), Int(rank), _nonempty(domain, "domain"),
            _nonempty(boundary, "boundary"), _nonempty(time, "time"),
            _nonempty(effect, "effect"), _nonempty(conservation, "conservation"))
    end
end
Base.:(==)(a::ConditionSignatureV1, b::ConditionSignatureV1) =
    a.unit == b.unit && a.rank == b.rank && a.domain == b.domain &&
    a.boundary == b.boundary && a.time == b.time && a.effect == b.effect &&
    a.conservation == b.conservation
Base.hash(a::ConditionSignatureV1, h::UInt) =
    hash((a.unit, a.rank, a.domain, a.boundary, a.time, a.effect, a.conservation), h)

_signature_tuple(x::ConditionSignatureV1) =
    (unit=x.unit, rank=x.rank, domain=x.domain, boundary=x.boundary,
     time=x.time, effect=x.effect, conservation=x.conservation)

struct RequiredConditionV1
    condition_ref::String
    condition_contract_hash::Digest256V1
    signature::ConditionSignatureV1
    function RequiredConditionV1(condition_ref, signature::ConditionSignatureV1)
        ref = _nonempty(condition_ref, "condition_ref")
        new(ref, digest_text(_encode(_signature_tuple(signature))), signature)
    end
end

struct AvailableConditionV1
    condition_ref::String
    condition_contract_hash::Digest256V1
    signature::ConditionSignatureV1
    observation_hash::Digest256V1
    function AvailableConditionV1(condition_ref, signature::ConditionSignatureV1,
                                  observation_hash::Digest256V1)
        new(_nonempty(condition_ref, "condition_ref"),
            digest_text(_encode(_signature_tuple(signature))), signature,
            observation_hash)
    end
end

struct RequiredConditionCatalogV1
    records::Tuple{Vararg{RequiredConditionV1}}
    catalog_hash::Digest256V1
    function RequiredConditionCatalogV1(records)
        xs = Tuple(records)
        all(x -> x isa RequiredConditionV1, xs) ||
            throw(ArgumentError("required catalog contains an untyped record"))
        refs = Tuple(x.condition_ref for x in xs)
        length(unique(refs)) == length(refs) ||
            throw(ArgumentError("required catalog contains duplicate references"))
        ordered = Tuple(sort(collect(xs), by=x -> x.condition_ref))
        new(ordered, digest_text(_encode(Tuple((x.condition_ref,
            string(x.condition_contract_hash)) for x in ordered))))
    end
end

struct AvailableConditionCatalogV1
    records::Tuple{Vararg{AvailableConditionV1}}
    catalog_hash::Digest256V1
    function AvailableConditionCatalogV1(records)
        xs = Tuple(records)
        all(x -> x isa AvailableConditionV1, xs) ||
            throw(ArgumentError("available catalog contains an untyped record"))
        ordered = Tuple(sort(collect(xs), by=x -> (x.condition_ref, string(x.observation_hash))))
        new(ordered, digest_text(_encode(Tuple((x.condition_ref,
            string(x.condition_contract_hash), string(x.observation_hash)) for x in ordered))))
    end
end

const _EVAL_STATUSES = (:conditions_met, :condition_unmet, :equality_unknown,
                        :contradiction, :fail_closed)

struct ConditionEvaluationV1
    status::Symbol
    missing_refs::Tuple{Vararg{String}}
    unmet_refs::Tuple{Vararg{String}}
    contradiction_refs::Tuple{Vararg{String}}
    evaluation_hash::Digest256V1
    function ConditionEvaluationV1(status::Symbol, missing_refs, unmet_refs, contradiction_refs)
        status in _EVAL_STATUSES || throw(ArgumentError("invalid condition evaluation status"))
        missing = Tuple(sort!(String[String(x) for x in missing_refs]))
        unmet = Tuple(sort!(String[String(x) for x in unmet_refs]))
        contradictions = Tuple(sort!(String[String(x) for x in contradiction_refs]))
        length(unique((missing..., unmet..., contradictions...))) ==
            length(missing) + length(unmet) + length(contradictions) ||
            throw(ArgumentError("condition evaluation references overlap"))
        status === :conditions_met && isempty(missing) && isempty(unmet) && isempty(contradictions) ||
            status === :condition_unmet && !isempty(unmet) && isempty(contradictions) ||
            status === :equality_unknown && !isempty(missing) && isempty(unmet) && isempty(contradictions) ||
            status === :contradiction && !isempty(contradictions) ||
            status === :fail_closed && !isempty(contradictions) ||
            throw(ArgumentError("condition evaluation status does not match references"))
        body = (status=status, missing=missing, unmet=unmet, contradictions=contradictions)
        new(status, missing, unmet, contradictions, digest_text(_encode(body)))
    end
end

function evaluate_conditions(required::RequiredConditionCatalogV1,
                            available::AvailableConditionCatalogV1)
    by_ref = Dict{String,Vector{AvailableConditionV1}}()
    for item in available.records
        push!(get!(by_ref, item.condition_ref, AvailableConditionV1[]), item)
    end
    missing = String[]; unmet = String[]; contradictions = String[]
    for item in required.records
        rows = get(by_ref, item.condition_ref, AvailableConditionV1[])
        if isempty(rows)
            push!(missing, item.condition_ref)
            continue
        end
        if length(rows) != 1
            push!(contradictions, item.condition_ref)
            continue
        end
        observed = only(rows)
        observed.condition_contract_hash == item.condition_contract_hash &&
            observed.signature == item.signature || push!(unmet, item.condition_ref)
    end
    if !isempty(contradictions)
        return ConditionEvaluationV1(:fail_closed, missing, unmet, contradictions)
    elseif !isempty(unmet)
        return ConditionEvaluationV1(:condition_unmet, missing, unmet, contradictions)
    elseif !isempty(missing)
        return ConditionEvaluationV1(:equality_unknown, missing, unmet, contradictions)
    end
    ConditionEvaluationV1(:conditions_met, missing, unmet, contradictions)
end

struct ReceiptTokenV1
    owner::String
    generation::UInt64
    scope::Symbol
    content_hash::Digest256V1
    function ReceiptTokenV1(owner, generation::Integer, scope::Symbol, content_hash::Digest256V1)
        generation >= 0 || throw(ArgumentError("token generation must be non-negative"))
        new(_nonempty(owner, "token owner"), UInt64(generation), scope, content_hash)
    end
end

function validate_token(token::ReceiptTokenV1, owner, scope::Symbol,
                       content_hash::Digest256V1, generation::Integer)
    token.owner == String(owner) || throw(ArgumentError("foreign receipt token"))
    token.scope === scope || throw(ArgumentError("stale receipt token scope"))
    token.generation == UInt64(generation) || throw(ArgumentError("stale receipt token generation"))
    token.content_hash == content_hash || throw(ArgumentError("stale receipt token content"))
    true
end

struct RewriteTraceStepV1
    step_index::Int
    source_hash::Digest256V1
    target_hash::Digest256V1
    rule_hash::Digest256V1
    registry_hash::Digest256V1
    budget_hash::Digest256V1
    evaluation_hash::Digest256V1
    condition_status::Symbol
    token::ReceiptTokenV1
    function RewriteTraceStepV1(step_index::Integer, source_hash::Digest256V1,
                                target_hash::Digest256V1, rule_hash::Digest256V1,
                                registry_hash::Digest256V1, budget_hash::Digest256V1,
                                evaluation::ConditionEvaluationV1, token::ReceiptTokenV1)
        step_index > 0 || throw(ArgumentError("trace step index must be positive"))
        evaluation.status === :conditions_met ||
            throw(ArgumentError("a merge trace requires conditions_met"))
        new(Int(step_index), source_hash, target_hash, rule_hash, registry_hash,
            budget_hash, evaluation.evaluation_hash, evaluation.status, token)
    end
    function RewriteTraceStepV1(step::RewriteTraceStepV1,
                                evaluation::ConditionEvaluationV1)
        new(step.step_index, step.source_hash, step.target_hash, step.rule_hash,
            step.registry_hash, step.budget_hash, evaluation.evaluation_hash,
            evaluation.status, step.token)
    end
end

struct MergeReplayReceiptV1
    step::RewriteTraceStepV1
    replay_hash::Digest256V1
    receipt_hash::Digest256V1
    function MergeReplayReceiptV1(step::RewriteTraceStepV1, replay_hash::Digest256V1)
        expected = _replay_identity_hash(step)
        replay_hash == expected || throw(ArgumentError("replay identity hash mismatch"))
        receipt_hash = digest_text(_encode((step=step, replay_hash=replay_hash)))
        new(step, replay_hash, receipt_hash)
    end
end

struct MergeReplayResultV1
    merged::Bool
    status::Symbol
    receipt::Union{Nothing,MergeReplayReceiptV1}
    result_hash::Digest256V1
    function MergeReplayResultV1(merged::Bool, status::Symbol,
                                 receipt::Union{Nothing,MergeReplayReceiptV1})
        if status === :replayed
            merged && receipt !== nothing ||
                throw(ArgumentError("replayed result requires merged receipt"))
        else
            !merged && receipt === nothing ||
                throw(ArgumentError("non-replayed result must be zero-merge"))
        end
        body = (merged=merged, status=status,
                receipt_hash=receipt === nothing ? nothing : receipt.receipt_hash)
        new(merged, status, receipt, digest_text(_encode(body)))
    end
end

_replay_identity_hash(step::RewriteTraceStepV1) = digest_text(_encode(
    (step=step.step_index, source=step.source_hash, target=step.target_hash,
     rule=step.rule_hash, registry=step.registry_hash, budget=step.budget_hash,
     evaluation=step.evaluation_hash)))

function _validate_replay_identity(step::RewriteTraceStepV1,
                                   evaluation::ConditionEvaluationV1;
                                   owner, source_hash::Digest256V1,
                                   target_hash::Digest256V1,
                                   rule_hash::Digest256V1,
                                   registry_hash::Digest256V1,
                                   budget_hash::Digest256V1,
                                   expected_generation::Integer)
    step.evaluation_hash == evaluation.evaluation_hash ||
        throw(ArgumentError("trace evaluation hash mismatch"))
    step.condition_status === evaluation.status ||
        throw(ArgumentError("trace condition status mismatch"))
    validate_token(step.token, owner, :rewrite_trace,
                   digest_text(_encode((source_hash=source_hash, target_hash=target_hash,
                                       rule_hash=rule_hash, registry_hash=registry_hash,
                                       budget_hash=budget_hash))), expected_generation)
    step.source_hash == source_hash && step.target_hash == target_hash ||
        throw(ArgumentError("trace source/target mismatch"))
    step.rule_hash == rule_hash && step.registry_hash == registry_hash &&
        step.budget_hash == budget_hash || throw(ArgumentError("trace identity mismatch"))
    true
end

function replay_merge(step::RewriteTraceStepV1, evaluation::ConditionEvaluationV1;
                      owner, source_hash::Digest256V1, target_hash::Digest256V1,
                      rule_hash::Digest256V1, registry_hash::Digest256V1,
                      budget_hash::Digest256V1, expected_generation::Integer)
    try
        _validate_replay_identity(step, evaluation; owner=owner,
            source_hash=source_hash, target_hash=target_hash, rule_hash=rule_hash,
            registry_hash=registry_hash, budget_hash=budget_hash,
            expected_generation=expected_generation)
    catch err
        err isa ArgumentError && return MergeReplayResultV1(false, :fail_closed, nothing)
        rethrow()
    end
    if evaluation.status !== :conditions_met
        result = MergeReplayResultV1(false, evaluation.status, nothing)
        validate_replay_result(result)
        return result
    end
    receipt = MergeReplayReceiptV1(step, _replay_identity_hash(step))
    validate_replay_receipt(receipt, evaluation; owner=owner,
        source_hash=source_hash, target_hash=target_hash, rule_hash=rule_hash,
        registry_hash=registry_hash, budget_hash=budget_hash,
        expected_generation=expected_generation)
    result = MergeReplayResultV1(true, :replayed, receipt)
    validate_replay_result(result)
    result
end

function validate_replay_receipt(receipt::MergeReplayReceiptV1,
                                 evaluation::ConditionEvaluationV1;
                                 owner, source_hash::Digest256V1,
                                 target_hash::Digest256V1, rule_hash::Digest256V1,
                                 registry_hash::Digest256V1,
                                 budget_hash::Digest256V1,
                                 expected_generation::Integer)
    evaluation.status === :conditions_met || throw(ArgumentError("receipt conditions are not met"))
    step = receipt.step
    step.evaluation_hash == evaluation.evaluation_hash ||
        throw(ArgumentError("receipt evaluation hash mismatch"))
    step.source_hash == source_hash && step.target_hash == target_hash ||
        throw(ArgumentError("receipt source/target mismatch"))
    step.rule_hash == rule_hash && step.registry_hash == registry_hash &&
        step.budget_hash == budget_hash || throw(ArgumentError("receipt identity mismatch"))
    token_hash = digest_text(_encode((source_hash=source_hash, target_hash=target_hash,
        rule_hash=rule_hash, registry_hash=registry_hash, budget_hash=budget_hash)))
    validate_token(step.token, owner, :rewrite_trace, token_hash, expected_generation)
    receipt.replay_hash == _replay_identity_hash(step) ||
        throw(ArgumentError("receipt replay hash mismatch"))
    expected_receipt_hash = digest_text(_encode((step=step, replay_hash=receipt.replay_hash)))
    receipt.receipt_hash == expected_receipt_hash ||
        throw(ArgumentError("receipt canonical hash mismatch"))
    true
end

function validate_replay_result(result::MergeReplayResultV1)
    expected = digest_text(_encode((merged=result.merged, status=result.status,
        receipt_hash=result.receipt === nothing ? nothing : result.receipt.receipt_hash)))
    result.result_hash == expected || throw(ArgumentError("replay result canonical hash mismatch"))
    if result.status === :replayed
        result.merged && result.receipt !== nothing ||
            throw(ArgumentError("replayed result invariant failed"))
    else
        !result.merged && result.receipt === nothing ||
            throw(ArgumentError("non-replayed result invariant failed"))
    end
    true
end

struct SaturationReceiptV1
    source_hash::Digest256V1
    ruleset_hash::Digest256V1
    registry_hash::Digest256V1
    budget_hash::Digest256V1
    trace_hash::Digest256V1
    complete::Bool
    status::Symbol
    equivalence::Symbol
    function SaturationReceiptV1(source_hash::Digest256V1, ruleset_hash::Digest256V1,
                                 registry_hash::Digest256V1, budget_hash::Digest256V1,
                                 trace_hash::Digest256V1, complete::Bool,
                                 status::Symbol, equivalence::Symbol)
        status in (:complete, :incomplete) || throw(ArgumentError("invalid saturation status"))
        complete == (status === :complete) || throw(ArgumentError("saturation status mismatch"))
        (!complete && equivalence === :unknown) ||
            (complete && equivalence in (:equivalent, :not_equivalent)) ||
            throw(ArgumentError("incomplete saturation cannot imply inequality"))
        new(source_hash, ruleset_hash, registry_hash, budget_hash, trace_hash,
            complete, status, equivalence)
    end
end

make_saturation_receipt(source_hash, ruleset_hash, registry_hash, budget_hash,
                        trace_hash; complete, equivalence=:unknown) =
    SaturationReceiptV1(source_hash, ruleset_hash, registry_hash, budget_hash,
                        trace_hash, complete, complete ? :complete : :incomplete,
                        equivalence)

struct CanonicalCacheEntryV1
    key::String
    bytes::String
    hash::Digest256V1
    token::ReceiptTokenV1
end

mutable struct CanonicalCacheV1
    owner::String
    generation::UInt64
    entries::Dict{String,CanonicalCacheEntryV1}
    function CanonicalCacheV1(owner; generation::Integer=1)
        new(_nonempty(owner, "cache owner"), UInt64(generation),
            Dict{String,CanonicalCacheEntryV1}())
    end
end

function cache_put!(cache::CanonicalCacheV1, key, value)
    k = _nonempty(key, "cache key")
    bytes = canonical_bytes(value)
    h = digest_text(bytes)
    token = ReceiptTokenV1(cache.owner, cache.generation, :canonical_cache, h)
    cache.entries[k] = CanonicalCacheEntryV1(k, bytes, h, token)
    cache.entries[k]
end

function cache_get(cache::CanonicalCacheV1, key, expected_hash::Digest256V1)
    entry = get(cache.entries, String(key), nothing)
    entry === nothing && throw(ArgumentError("missing canonical cache entry"))
    validate_token(entry.token, cache.owner, :canonical_cache, expected_hash, cache.generation)
    entry.hash == expected_hash || throw(ArgumentError("cache hash mismatch"))
    entry
end

cache_hash(cache::CanonicalCacheV1, key, expected_hash::Digest256V1) =
    cache_get(cache, key, expected_hash).hash

function _encode(x)
    x === nothing && return "N"
    x isa Digest256V1 && return "D" * x.value
    x isa Symbol && return "S" * String(x)
    x isa AbstractString && return "T" * string(ncodeunits(String(x))) * ":" * String(x)
    x isa Bool && return x ? "B1" : "B0"
    x isa Integer && return "I" * string(x)
    x isa NamedTuple && return _encode(Tuple((k, getfield(x, k)) for k in keys(x)))
    x isa ConditionSignatureV1 && return _encode(_signature_tuple(x))
    x isa RequiredConditionV1 && return _encode((x.condition_ref, x.condition_contract_hash, x.signature))
    x isa AvailableConditionV1 && return _encode((x.condition_ref, x.condition_contract_hash, x.signature, x.observation_hash))
    x isa ConditionEvaluationV1 && return _encode((x.status, x.missing_refs, x.unmet_refs, x.contradiction_refs, x.evaluation_hash))
    x isa ReceiptTokenV1 && return _encode((x.owner, x.generation, x.scope, x.content_hash))
    x isa RewriteTraceStepV1 && return _encode((x.step_index, x.source_hash, x.target_hash, x.rule_hash, x.registry_hash, x.budget_hash, x.evaluation_hash, x.condition_status))
    x isa MergeReplayReceiptV1 && return _encode((x.step, x.replay_hash, x.receipt_hash))
    x isa MergeReplayResultV1 && return _encode((x.merged, x.status, x.receipt, x.result_hash))
    x isa SaturationReceiptV1 && return _encode((x.source_hash, x.ruleset_hash, x.registry_hash, x.budget_hash, x.trace_hash, x.complete, x.status, x.equivalence))
    x isa Tuple && return "(" * join((_encode(y) for y in x), ";") * ")"
    string(typeof(x), ":", repr(x))
end

canonical_bytes(x) = _encode(x)
canonical_hash(x) = digest_text(canonical_bytes(x))
cold_canonical_bytes(x) = canonical_bytes(x)
cold_canonical_hash(x) = digest_text(cold_canonical_bytes(x))
hot_canonical_bytes(cache::CanonicalCacheV1, key, expected_hash::Digest256V1) =
    cache_get(cache, key, expected_hash).bytes
hot_canonical_hash(cache::CanonicalCacheV1, key, expected_hash::Digest256V1) =
    cache_hash(cache, key, expected_hash)

end
