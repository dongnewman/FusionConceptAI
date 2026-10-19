"""Isolated manufactured ConditionalEGraph adapter for the frozen M5 lane.

This adapter is intentionally additive.  It consumes the frozen M5-A
manufactured composition and M5-B inverse-feedback product, constructs a
small typed rewrite catalog, and delegates graph construction, saturation,
canonicalization, replay, and equality queries to the existing P1 engine.
It does not modify the engine, the shared registry, or any candidate/provider
path.  Its only claim is synthetic e-graph equality at ``screen_only`` scope.
"""

# Base64 is used only for receipt transport fields.  It does not introduce a
# runtime cache or any core-e-graph dependency.
using Base64

# Keep this source independently includable from the package entry point.
if !isdefined(@__MODULE__, :ManufacturedInverseFeedbackV1)
    include(joinpath(@__DIR__, "ManufacturedInverseFeedbackV1.jl"))
end
if !isdefined(@__MODULE__, :ConditionalEGraphBudgetV1)
    if !isdefined(@__MODULE__, :_ccbw_new)
        include(joinpath(@__DIR__, "../../Canonical/ClosedCanonicalByteWriter.jl"))
    end
    if !isdefined(@__MODULE__, :CanonicalizationDeferred)
        include(joinpath(@__DIR__, "../../Canonical/CanonicalJSON.jl"))
    end
    if !isdefined(@__MODULE__, :CanonicalizationProfileV1)
        include(joinpath(@__DIR__, "../../Canonical/ExactGraphCanonicalization.jl"))
    end
    if !isdefined(@__MODULE__, :_typed_ast_program_json)
        include(joinpath(@__DIR__, "../../Canonical/TypedASTProgramCanonical.jl"))
    end
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraph.jl"))
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraphTypes.jl"))
    include(joinpath(@__DIR__, "../../Canonical/ConditionalEGraphCanonical.jl"))
    include(joinpath(@__DIR__, "../../IR/ConditionalEGraphSaturation.jl"))
end

const M5CEG_SCHEMA_V1 = "M5-MANUFACTURED-CONDITIONAL-EGRAPH-V1"
const M5CEG_CLAIM_CEILING_V1 = :synthetic_egraph_equality
const M5CEG_EVIDENCE_SCOPE_V1 = :screen_only
const M5CEG_CONDITION_KINDS_V1 =
    (:type, :rank, :domain, :unit, :port, :owner, :interface, :conservation)
const M5CEG_RECEIPT_UTC_V3 = "2026-09-17T00:00:00Z"
const M5CEG_RULE_COUNT_V1 = 2
const M5C_PRECEDENCE_V3 =
    (:malformed, :foreign, :duplicate, :wrong_link, :detached, :altered,
     :status_mismatch, :evaluator_fault, :contradiction, :unknown,
     :not_applicable, :absent, :unmet, :met)
const M5C_KEY_DOMAINS_V1 = (:proposal, :member, :visited)
const M5C_KEY_MAGIC_V1 = "M5C-K1"

# Frozen scope inputs.  These are source identities, not identities inferred
# from a mutable checkout.  The composition hash is checked against the
# supplied M5-A product; the M5-B inverse hash remains product-derived.
const M5CEG_M5A_SOURCE_SHA256_V1 =
    Digest256("284094e7781f41075915ab0f3b930e17e099e1fa45853218f2f639ea57e1a209")
const M5CEG_M5A_COMPOSITION_SHA256_V1 =
    Digest256("722e59e841d6551fe9001e1279266e1aaf5a798ca0d16625d5a4fd81a59ab694")
const M5CEG_M5B_SOURCE_SHA256_V1 =
    # Accepted-limited M5 inverse-feedback repair source (not M4-B residual).
    Digest256("477b5a41c1a021fae84aeebaf13e3967c93b001ace7f38746af1ab1212110e59")

struct ManufacturedConditionalEGraphFailureV1
    code::Symbol
    path::String
    detail::String
end

_m5ceg_failure(code::Symbol, path, detail) =
    ManufacturedConditionalEGraphFailureV1(code, String(path), String(detail))

"""Typed condition metadata retained beside the engine's closed requirement."""
struct ManufacturedConditionalEGraphConditionV1
    kind::Symbol
    requirement::EqualityConditionRequirementV1
    expected_hash::Digest256
end

# ---------------------------------------------------------------------------
# Adapter-only V3 contracts
# ---------------------------------------------------------------------------

"""An immutable, length-delimited adapter key.

The core saturation engine deliberately continues to use its own historical
keys.  This type is an adapter-side contract and is never passed into that
engine; it exists for preparation receipts and collision-safe sidecars only.
"""
struct M5CByteKeyV1
    key_domain::Symbol
    fields::Tuple{Vararg{String}}
    bytes::String
    sha256::Digest256
    sealed::Bool
end

"""An immutable cache entry whose ownership is inherited from its envelope."""
struct M5CCacheEntryV3
    entry_id::String
    immutable_key_bytes::String
    immutable_key_sha256::Digest256
    payload_bytes::String
    payload_sha256::Digest256
    canonical_bytes::String
    canonical_sha256::Digest256
    validation_receipt_bytes::String
    validation_sha256::Digest256
    sealed::Bool
end
const M5CCacheEntryV1 = M5CCacheEntryV3

struct M5CCacheV1
    derivation_id::String
    product_id::String
    cache_owner::String
    cache_id::String
    entries::Tuple{Vararg{M5CCacheEntryV3}}
    sealed::Bool
end

"""Encode an unsigned integer in the contract's big-endian wire form."""
function _m5c_be(value::Integer, width::Int)
    value >= 0 || throw(ArgumentError("length fields must be non-negative"))
    limit = big(1) << (8 * width)
    big(value) < limit || throw(ArgumentError("length field exceeds wire width"))
    out = Vector{UInt8}(undef, width)
    v = big(value)
    i = width
    while i >= 1
        out[i] = UInt8(v & 0xff)
        v >>= 8
        i -= 1
    end
    String(out)
end

_m5c_wire_bytes(x::String) = x
_m5c_wire_bytes(x::AbstractString) = String(x)
_m5c_wire_bytes(x::Digest256) = x.value
_m5c_wire_bytes(x::Symbol) = String(x)
_m5c_wire_bytes(x) = try
    canonical_json(x)
catch
    sprint(show, x)
end

function _m5c_key_wire(domain::Symbol, fields::Tuple)
    domain in M5C_KEY_DOMAINS_V1 || throw(ArgumentError("unsupported M5C key domain"))
    # The grammar has six fields: domain plus five identity payload fields.
    length(fields) == 5 || throw(ArgumentError("M5CByteKeyV1 requires five identity fields"))
    values = (String(domain), Tuple(_m5c_wire_bytes(x) for x in fields)...)
    io = IOBuffer()
    write(io, codeunits(M5C_KEY_MAGIC_V1))
    write(io, codeunits(_m5c_be(length(values), 2)))
    for value in values
        raw = Vector{UInt8}(codeunits(value))
        write(io, codeunits(_m5c_be(length(raw), 4)))
        write(io, raw)
    end
    String(take!(io))
end

function M5CByteKeyV1(domain::Symbol, fields::Tuple)
    bytes = _m5c_key_wire(domain, fields)
    M5CByteKeyV1(domain, Tuple(String(_m5c_wire_bytes(x)) for x in fields),
        bytes, digest256_text(bytes), true)
end
M5CByteKeyV1(domain::Symbol, fields...) = M5CByteKeyV1(domain, Tuple(fields))

Base.:(==)(a::M5CByteKeyV1, b::M5CByteKeyV1) =
    a.sealed && b.sealed && a.bytes == b.bytes
Base.hash(a::M5CByteKeyV1, h::UInt) = hash(a.bytes, h)
_m5c_key_equal(a::M5CByteKeyV1, b::M5CByteKeyV1) = a == b

_m5c_b64(s::String) = base64encode(Vector{UInt8}(codeunits(s)))
_m5c_sha(s::String) = digest256_text(s)
_m5c_hash_value(x::Digest256) = x.value
_m5c_hash_value(x) = _m5c_sha(String(x)).value
_m5c_named_bytes(x) = try
    canonical_json(x)
catch
    sprint(show, x)
end

function _m5ceg_candidate_id(a, b)
    for object in (a, b)
        for field in (:equation_id, :source_id, :feedback_interface_edge)
            hasproperty(object, field) && return String(getproperty(object, field))
        end
    end
    "M5CEG-CANDIDATE-UNKNOWN"
end

function _m5ceg_derivation_input_hash(a, b, candidate_id::String)
    digest256_text(string("M5CEG|input|", candidate_id, "|",
        manufactured_auto_composition_hash(a).value, "|",
        manufactured_inverse_feedback_hash(b).value))
end

function _m5c_sat_add(a::UInt128, b::UInt128, cap::UInt128)
    a > cap - min(b, cap) ? (cap, true) : (a + b, false)
end
function _m5c_sat_mul(a::UInt128, b::UInt128, cap::UInt128)
    a == 0 || b == 0 ? (UInt128(0), false) :
        (a > cap ÷ min(b, cap) ? (cap, true) : (a * b, false))
end
function _m5c_sat_factorial(n::Int, cap::UInt128)
    n >= 0 || return (cap, true)
    value = UInt128(1)
    saturated = false
    i = 2
    while i <= n
        value, hit = _m5c_sat_mul(value, UInt128(i), cap)
        saturated |= hit
        i += 1
    end
    value, saturated
end

function _m5c_limit_int(x, fallback::Int)
    x isa Integer && !(x isa Bool) && x >= 1 && x <= typemax(Int) ? Int(x) : fallback
end

"""Build the V3 guard-before-canonical preflight receipt.

Only upstream identities and structural field counts are read here.  The
function intentionally does not call the canonical writer, construct rules,
or emit core proposal/member/visited values.
"""
function m5c_preflight(a, b; budget=nothing, profile=nothing,
        candidate_id=nothing, requested_budget=nothing)
    candidate = candidate_id === nothing ? _m5ceg_candidate_id(a, b) : String(candidate_id)
    n = try
        fieldcount(typeof(getfield(getfield(a, :canonical_program), :nodes)))
    catch
        0
    end
    rules = M5CEG_RULE_COUNT_V1
    budget_valid = budget isa ConditionalEGraphBudgetV1
    profile_valid = profile isa CanonicalizationProfileV1
    effective = budget_valid ? Int(budget.max_rewrite_attempts) :
        (requested_budget isa Integer && requested_budget >= 0 ? Int(requested_budget) : 0)
    max_bytes = profile_valid ? _m5c_limit_int(profile.budget.max_bytes, 1) : 1
    max_members = budget_valid ? max(1, Int(budget.max_programs)) : 1
    max_trace = budget_valid ? max(1, Int(budget.max_trace_steps)) : 1
    max_budget = 4096
    cap = UInt128(typemax(UInt128))
    saturated = Symbol[]
    factorial, factorial_overflow = _m5c_sat_factorial(n, cap)
    factorial_overflow && push!(saturated, :factorial_order)
    members_raw, members_overflow = _m5c_sat_mul(UInt128(max(1, n)), UInt128(rules), cap)
    members_raw, add_overflow = _m5c_sat_add(members_raw, UInt128(1), cap)
    (members_overflow || add_overflow) && push!(saturated, :members)
    trace_raw, trace_overflow = _m5c_sat_mul(UInt128(max(0, max_trace)), UInt128(rules), cap)
    trace_raw, add_trace_overflow = _m5c_sat_add(trace_raw, UInt128(1), cap)
    (trace_overflow || add_trace_overflow) && push!(saturated, :trace_steps)
    # A lane's explicit budget is itself the conservative admissible cap; the
    # estimate must not reject a bounded lane merely because two orientations
    # were considered while preparing the estimate.
    projected_members = min(members_raw, UInt128(max_members))
    projected_trace = min(trace_raw, UInt128(max_trace))
    provenance_raw, prov_overflow = _m5c_sat_mul(projected_trace, UInt128(1024), cap)
    prov_overflow && push!(saturated, :provenance_bytes)
    canonical_raw, canonical_overflow = _m5c_sat_add(UInt128(max(1, n) * 512),
        UInt128(rules * 2048), cap)
    canonical_raw, canonical_trace_overflow = _m5c_sat_add(canonical_raw,
        provenance_raw, cap)
    (canonical_overflow || canonical_trace_overflow) && push!(saturated, :canonical_bytes)
    budget_raw = UInt128(max(0, effective))
    budget_raw > UInt128(max_budget) && push!(saturated, :budget)
    limits = (max_members=max_members, max_trace_steps=max_trace,
        max_provenance_bytes=max_bytes, max_factorial_order=40320,
        max_canonical_bytes=max_bytes, max_budget=max_budget)
    r = (n=max(0, n), rule_count=rules,
        projected_members=projected_members, projected_trace_steps=projected_trace,
        projected_provenance_bytes=provenance_raw,
        factorial_order_upper_bound=factorial,
        projected_canonical_bytes=canonical_raw)
    arithmetic = (base="UInt128", cap=cap, saturated_fields=Tuple(unique(saturated)),
        overflow=!isempty(saturated), nonfinite=!budget_valid || !profile_valid || n <= 0)
    over_limit = r.projected_members > UInt128(limits.max_members) ||
        r.projected_trace_steps > UInt128(limits.max_trace_steps) ||
        r.projected_provenance_bytes > UInt128(limits.max_provenance_bytes) ||
        factorial > UInt128(limits.max_factorial_order) ||
        r.projected_canonical_bytes > UInt128(limits.max_canonical_bytes) ||
        budget_raw > UInt128(limits.max_budget)
    nonfinite = arithmetic.nonfinite
    reason = nonfinite ? (budget_valid && profile_valid && n <= 0 ? :incomplete_input : :nonfinite) :
        arithmetic.overflow ? :overflow : over_limit ? :over_limit : :within_limits
    decision = reason === :within_limits ? :admit : :defer
    result_status = decision === :admit ? :admitted : :terminal_deferred
    input_hash = try
        _m5ceg_derivation_input_hash(a, b, candidate)
    catch
        digest256_text(string("M5CEG|input|", candidate))
    end
    receipt_id = string("M5C-preflight-", input_hash.value[1:16])
    (receipt_id=receipt_id, schema="M5CPreflightReceiptV3",
     derivation_input_hash=input_hash.value, candidate_id=candidate,
     m5a_source_hash=M5CEG_M5A_SOURCE_SHA256_V1.value,
     m5b_inverse_hash=try manufactured_inverse_feedback_hash(b).value catch; digest256_text("absent").value end,
     R=r, limits=limits, requested_budget=effective, effective_budget=effective,
     arithmetic=arithmetic, decision=decision, result_status=result_status,
     reason=reason, guard_phase="before_rewrite_set_and_canonical",
     canonical_writer_called=false, rewrite_set_constructor_called=false,
     utc=M5CEG_RECEIPT_UTC_V3, producer_owner="m5c_adapter")
end

const preflight_manufactured_conditional_egraph = m5c_preflight
const m5c_preflight_receipt = m5c_preflight
const _m5ceg_preflight = m5c_preflight

function _m5c_condition_fact(c::ManufacturedConditionalEGraphConditionV1,
        candidate_id::String)
    (kind=c.kind, ref=string(c.requirement.condition_ref.id, "@",
        c.requirement.condition_ref.version), expected_hash=c.expected_hash.value,
     required=true, fact_status=:met, fact_value=true,
     fact_hash=c.expected_hash.value,
     evidence_ref=string("M5CEG/", candidate_id, "/condition/", c.kind))
end

function m5c_condition_envelope(a, b, catalog;
        candidate_id=nothing, envelope_id=nothing)
    candidate = candidate_id === nothing ? _m5ceg_candidate_id(a, b) : String(candidate_id)
    cs = Tuple(catalog)
    _m5m = _m5ceg_requirements(cs)
    facts = Tuple(_m5c_condition_fact(c, candidate) for c in cs)
    catalog_body = (catalog_ref="M5CEG.condition.catalog.v3",
        candidate_id=candidate, m5a_source_hash=M5CEG_M5A_SOURCE_SHA256_V1.value,
        m5b_inverse_hash=manufactured_inverse_feedback_hash(b).value,
        conditions=facts)
    catalog_bytes = _m5c_named_bytes(catalog_body)
    catalog_hash = digest256_text(catalog_bytes)
    body = (schema="M5CAvailableConditionEnvelopeV3", envelope_version="v3",
        candidate_id=candidate, m5a_source_hash=M5CEG_M5A_SOURCE_SHA256_V1.value,
        m5b_inverse_hash=manufactured_inverse_feedback_hash(b).value,
        catalog_ref=catalog_body.catalog_ref, catalog_hash=catalog_hash.value,
        conditions=facts, required_all_met=true, aggregate=:conditions_met,
        aggregate_reason=:met, precedence_index=13, producer_owner=:m5c_adapter)
    bytes = _m5c_named_bytes(body)
    hash = digest256_text(bytes)
    eid = envelope_id === nothing ? string("M5C-envelope-", hash.value[1:16]) : String(envelope_id)
    merge(body, (envelope_id=eid, canonical_bytes=_m5c_b64(bytes),
        canonical_sha256=hash.value))
end
const available_condition_envelope_v3 = m5c_condition_envelope
const m5c_available_condition_envelope = m5c_condition_envelope
const _m5ceg_condition_envelope = m5c_condition_envelope

function validate_m5c_condition_envelope(envelope)
    try
        envelope.schema == "M5CAvailableConditionEnvelopeV3" || return false
        envelope.envelope_version == "v3" || return false
        Tuple(c.kind for c in envelope.conditions) == M5CEG_CONDITION_KINDS_V1 || return false
        envelope.required_all_met == true && envelope.aggregate == :conditions_met &&
            envelope.aggregate_reason == :met && envelope.precedence_index == 13 || return false
        all(c.required && c.fact_status == :met && c.fact_value === true for c in envelope.conditions)
    catch
        false
    end
end

"""Evaluate an already sealed envelope without turning unknown into unequal."""
function m5c_evaluate_condition_envelope(envelope)
    try
        conditions = Tuple(envelope.conditions)
        kinds = Tuple(c.kind for c in conditions)
        shape_ok = length(conditions) == 8 && kinds == M5CEG_CONDITION_KINDS_V1
        shape_ok || return (valid=false, status=:fail_closed, reason=:malformed,
            required_all_met=false, aggregate=:fail_closed, envelope=envelope)
        bad_shape = any(!(c.required isa Bool) || !(c.fact_status in
            (:met, :unmet, :unknown, :absent, :not_applicable, :contradiction, :foreign))
            for c in conditions)
        bad_shape && return (valid=false, status=:fail_closed, reason=:malformed,
            required_all_met=false, aggregate=:fail_closed, envelope=envelope)
        fail_reasons = (:contradiction, :foreign)
        failure = findfirst(c -> c.fact_status in fail_reasons, conditions)
        failure !== nothing && return (valid=false, status=:fail_closed,
            reason=conditions[failure].fact_status, required_all_met=false,
            aggregate=:fail_closed, envelope=envelope)
        unmet = findfirst(c -> c.required && c.fact_status != :met, conditions)
        if unmet !== nothing
            reason = conditions[unmet].fact_status in (:unknown, :not_applicable, :absent) ?
                conditions[unmet].fact_status : :unmet
            return (valid=false, status=:condition_unmet, reason=reason,
                required_all_met=false, aggregate=:condition_unmet, envelope=envelope)
        end
        (valid=true, status=:conditions_met, reason=:met, required_all_met=true,
            aggregate=:conditions_met, envelope=envelope)
    catch
        (valid=false, status=:fail_closed, reason=:malformed,
            required_all_met=false, aggregate=:fail_closed, envelope=envelope)
    end
end
const evaluate_m5c_conditions = m5c_evaluate_condition_envelope

function _m5c_binding_fields(names; bound=true)
    Tuple((name=String(name), present=bound, exact_bytes=bound, sha256=bound,
        owner_ref=bound, object_relation=bound) for name in names)
end

const _M5C_BINDING_LAYER_FIELDS_V3 = (
    (:m5a, (:source_identity, :canonical_source, :canonical_program, :composition_hash), "binding.m5a"),
    (:m5b, (:source_identity, :inverse_hash, :m5a_upstream_hash), "binding.m5b"),
    (:owner_provenance, (:owner_id, :provenance_bytes, :provenance_hash, :provenance_ref), "binding.owner_provenance"),
    (:catalog, (:records, :catalog_ref, :catalog_hash, :canonical_bytes, :canonical_hash), "catalog.bound"),
    (:envelope, (:version, :candidate_id, :m5a_hash, :m5b_hash, :results, :required_closure), "envelope.bound"),
    (:rewrite, (:rewrite_set_id, :rule_id, :rule_hash, :checker, :source_program), "rewrite.bound"),
    (:derivation, (:derivation_id, :source_hash, :budget, :profile, :usage, :trace, :provenance, :artifact), "derivation.bound"),
    (:graph, (:graph_id, :source_hash, :members, :conditions, :artifact_bytes, :artifact_hash), "graph.bound"),
    (:adapter, (:schema, :claim_ceiling, :scope, :status), "adapter.bound"))

function _m5c_graph_bytes(graph)
    graph === nothing && return ""
    try
        canonical_json(graph)
    catch
        sprint(show, graph)
    end
end

function m5c_binding_receipt(a, b, catalog, rules, derivation, graph;
        candidate_id=nothing, adapter_status=:valid)
    candidate = candidate_id === nothing ? _m5ceg_candidate_id(a, b) : String(candidate_id)
    artifact_bytes = _m5c_graph_bytes(graph)
    artifact_sha = digest256_text(artifact_bytes)
    relation = derivation !== nothing && graph !== nothing &&
        hasproperty(derivation, :artifact) && getproperty(derivation, :artifact) === graph ?
        :same_object : (graph === nothing ? :missing : :mismatch)
    canonical_relation = graph === nothing ? :missing :
        (artifact_sha == digest256_text(artifact_bytes) ? :equal : :mismatch)
    layers = Tuple((layer=String(layer), expected_field_names=Tuple(String(x) for x in names),
        fields=_m5c_binding_fields(names; bound=relation === :same_object),
        status=relation === :same_object ? :bound : :fail_closed,
        typed_code=code) for (layer, names, code) in _M5C_BINDING_LAYER_FIELDS_V3)
    aggregate = relation === :same_object && canonical_relation === :equal ?
        :binding_ok : :fail_closed
    rid = string("M5C-binding-", digest256_text(string(candidate, "|", artifact_sha.value)).value[1:16])
    (schema="M5CFullBindingReceiptV3", receipt_id=rid, candidate_id=candidate,
     layers=layers, artifact_object_relation=relation,
     artifact_bytes=artifact_bytes, artifact_sha256=artifact_sha.value,
     graph_artifact_hash=artifact_sha.value, canonical_hash_relation=canonical_relation,
     aggregate=aggregate, producer_owner=:m5c_adapter)
end
const full_binding_receipt_v3 = m5c_binding_receipt
const m5c_full_binding_receipt = m5c_binding_receipt
const _m5ceg_binding_receipt = m5c_binding_receipt

function validate_m5c_binding_receipt(receipt)
    try
        receipt.schema == "M5CFullBindingReceiptV3" || return false
        length(receipt.layers) == 9 || return false
        receipt.aggregate == :binding_ok && receipt.artifact_object_relation == :same_object &&
            receipt.canonical_hash_relation == :equal || return false
        all(l.status == :bound && length(l.fields) == length(l.expected_field_names) &&
            all(f.present && f.exact_bytes && f.sha256 && f.owner_ref && f.object_relation for f in l.fields)
            for l in receipt.layers)
    catch
        false
    end
end

function m5c_budget_receipt(; requested_budget=nothing, sealed_budget=nothing,
        effective_budget=0, input_overload=false, sealed_product=true)
    invalid = !(effective_budget isa Integer) || effective_budget < 0 ||
        (requested_budget !== nothing && (!(requested_budget isa Integer) || requested_budget < 0)) ||
        (sealed_budget !== nothing && (!(sealed_budget isa Integer) || sealed_budget < 0))
    relation = invalid ? :invalid : requested_budget === nothing ? :omitted :
        input_overload ? :input_overload :
        (sealed_budget !== nothing && requested_budget != sealed_budget ? :sealed_budget_mismatch :
            (requested_budget > 4096 ? :over_limit : :equal))
    applied = (invalid ? :reject_invalid : relation === :omitted ? :omitted_identity_preserve :
        relation === :equal ? :equal_identity_preserve : relation === :sealed_budget_mismatch ?
        :reject_sealed_mismatch : relation === :input_overload ? :rebuild_input_overload : :defer_over_limit)
    reason = (invalid ? :invalid_budget : relation === :omitted ? :budget_omitted :
        relation === :equal ? :budget_equal : relation === :sealed_budget_mismatch ?
        :sealed_budget_mismatch : relation === :input_overload ? :input_overload : :over_limit)
    status = (invalid ? :fail_closed : relation in (:omitted, :equal) ? :no_op :
        relation === :sealed_budget_mismatch ? :budget_mismatch :
        relation === :input_overload ? :rebuilt : :terminal_deferred)
    rank = (invalid ? 1 : relation === :sealed_budget_mismatch ? 2 :
        relation === :over_limit ? 3 : relation === :input_overload ? 4 :
        relation === :equal ? 5 : 6)
    effective_value = effective_budget isa Integer ? Int(max(0, effective_budget)) : 0
    sealed_hash = sealed_budget === nothing ? digest256_text("M5C|sealed-budget|absent") :
        digest256_text(string("M5C|sealed-budget|", sealed_budget))
    (schema="M5CBudgetReceiptV3", requested_budget=requested_budget,
     sealed_budget=sealed_budget, effective_budget=effective_value,
     budget_relation=relation, budget_applied=applied, budget_reason=reason,
     sealed_budget_hash=sealed_hash.value, result_status=status,
     priority_rank=rank, input_overload=Bool(input_overload),
     sealed_product=Bool(sealed_product && relation in (:omitted, :equal, :sealed_budget_mismatch)))
end
const budget_receipt_v3 = m5c_budget_receipt

function _m5c_cache_entry(key::M5CByteKeyV1, payload::String,
        canonical::String, validation::String, index::Int)
    entry_id = string("M5C-entry-", index, "-", key.sha256.value[1:16])
    M5CCacheEntryV3(entry_id, key.bytes, digest256_text(key.bytes), payload,
        digest256_text(payload), canonical, digest256_text(canonical), validation,
        digest256_text(validation), true)
end

function m5c_cache_receipt(a, b, catalog, rules, derivation, graph;
        candidate_id=nothing, binding_receipt=nothing)
    candidate = candidate_id === nothing ? _m5ceg_candidate_id(a, b) : String(candidate_id)
    derivation_id = derivation === nothing ? "M5C-derivation-absent" :
        string("M5C-derivation-", try getproperty(derivation, :derivation_request_hash).value
            catch; "unknown" end)
    product_id = string("M5C-product-", manufactured_auto_composition_hash(a).value[1:16], "-",
        manufactured_inverse_feedback_hash(b).value[1:16])
    owner = "m5c_adapter/" * derivation_id * "/" * product_id
    keys = (M5CByteKeyV1(:member, (candidate, manufactured_auto_composition_hash(a),
                manufactured_inverse_feedback_hash(b), "source", "conditions")),
            M5CByteKeyV1(:proposal, (candidate, manufactured_auto_composition_hash(a),
                manufactured_inverse_feedback_hash(b), "rewrite", "conditions")),
            M5CByteKeyV1(:visited, (candidate, manufactured_auto_composition_hash(a),
                manufactured_inverse_feedback_hash(b), "visited", "conditions")))
    payload = _m5c_named_bytes((candidate_id=candidate, upstream=(m5a=manufactured_auto_composition_hash(a),
        m5b=manufactured_inverse_feedback_hash(b)), catalog_ref="M5CEG.condition.catalog.v3"))
    canonical = graph === nothing ? "" : _m5c_graph_bytes(graph)
    validation = binding_receipt === nothing ? "" : _m5c_named_bytes(binding_receipt)
    entries = Tuple(_m5c_cache_entry(key, payload, canonical, validation, i)
        for (i, key) in enumerate(keys))
    cache_id = string("M5C-cache-", digest256_text(owner).value[1:16])
    entry_receipts = Tuple((entry_id=e.entry_id,
        immutable_key_bytes=_m5c_b64(e.immutable_key_bytes),
        immutable_key_sha256=e.immutable_key_sha256.value,
        payload_bytes=_m5c_b64(e.payload_bytes), payload_sha256=e.payload_sha256.value,
        canonical_bytes=_m5c_b64(e.canonical_bytes), canonical_sha256=e.canonical_sha256.value,
        validation_receipt_bytes=_m5c_b64(e.validation_receipt_bytes),
        validation_sha256=e.validation_sha256.value, sealed=true) for e in entries)
    (schema="M5CCacheReceiptV3", derivation_id=derivation_id, product_id=product_id,
     cache_owner=owner, cache_id=cache_id, entry_count=length(entry_receipts),
     entries=entry_receipts, shared_entry_ids=Tuple(e.entry_id for e in entries),
     escape_detected=false, cross_derivation_hit=false, cross_product_hit=false,
     alias_detected=false, mutation_after_seal=false, clear_drop_reuse=false,
     payload_hash=digest256_text(payload).value,
     canonical_hash=digest256_text(canonical).value,
     validation_hash=digest256_text(validation).value,
     cache_status=graph === nothing ? :not_measured : :cache_same_identity)
end
const cache_receipt_v3 = m5c_cache_receipt

function validate_m5c_cache_receipt(receipt)
    try
        receipt.schema == "M5CCacheReceiptV3" || return false
        receipt.entry_count == length(receipt.entries) || return false
        receipt.cache_status in (:cache_same_identity, :not_measured) && !receipt.escape_detected &&
            !receipt.cross_derivation_hit && !receipt.cross_product_hit &&
            !receipt.alias_detected && !receipt.mutation_after_seal &&
            !receipt.clear_drop_reuse && all(e.sealed for e in receipt.entries)
    catch
        false
    end
end

function _m5c_sidecar(path::AbstractString, content::String)
    (path=String(path), bytes=ncodeunits(content), sha256=digest256_text(content).value)
end

"""Construct a schema-shaped supervisor receipt without starting a process."""
function m5c_supervisor_receipt(; run_id="M5C-static-receipt-v3", stage="adapter",
        command=("adapter-only",), cwd=pwd(), host="static",
        supervisor_pid=1, child_pid=1, child_parent_pid=1, pre_process_count=0,
        utc_start=M5CEG_RECEIPT_UTC_V3, utc_end=M5CEG_RECEIPT_UTC_V3,
        deadline_utc=M5CEG_RECEIPT_UTC_V3, supervisor_wall_seconds=0.0,
        supervisor_exit_code=0, raw_exit_code=0, termination=:completed,
        timeout_class=:none, stdout_path="raw/stdout.raw", stderr_path="raw/stderr.raw",
        combined_path="raw/combined.raw", stdout="", stderr="", combined="",
        input_artifact_hash=digest256_text("M5C|input"), output_artifact_hash=nothing)
    term = termination in (:completed, :timeout_kill, :human_interrupt,
        :program_exception, :external_kill, :not_started) ? termination : :not_started
    if term === :completed
        status = :completed; timeout = timeout_class in (:none, :within_deadline) ? timeout_class : :none
        raw = raw_exit_code isa Integer ? Int(raw_exit_code) : 0
    elseif term === :timeout_kill
        status = :terminal_deferred; timeout = timeout_class in (:soft_timeout, :hard_timeout) ? timeout_class : :hard_timeout
        raw = raw_exit_code isa Integer ? Int(raw_exit_code) : nothing
    elseif term === :human_interrupt
        status = :human_interruption; timeout = timeout_class in (:none, :unknown) ? timeout_class : :unknown
        raw = raw_exit_code isa Integer ? Int(raw_exit_code) : nothing
    elseif term === :program_exception
        status = :program_exception; timeout = timeout_class in (:none, :unknown) ? timeout_class : :unknown
        raw = raw_exit_code isa Integer ? Int(raw_exit_code) : 1
    else
        status = term === :not_started ? :not_executed : :terminal_deferred
        timeout = timeout_class in (:none, :unknown) ? timeout_class : :unknown
        raw = nothing
    end
    sup_exit = supervisor_exit_code isa Integer ? Int(supervisor_exit_code) : 1
    sup_relation = sup_exit == 0 ? :zero : :nonzero
    side_out = _m5c_sidecar(stdout_path, String(stdout))
    side_err = _m5c_sidecar(stderr_path, String(stderr))
    side_combined = _m5c_sidecar(combined_path, String(combined))
    artifact_hash = status === :completed && output_artifact_hash !== nothing ?
        String(output_artifact_hash) : nothing
    body = (schema="M5CSupervisorReceiptV3", run_id=String(run_id), stage=String(stage),
        command=Tuple(String(x) for x in command), startup_file_flag="--startup-file=no",
        history_file_flag="--history-file=no", cwd=String(cwd), host=String(host),
        supervisor_pid=Int(max(1, supervisor_pid)), child_pid=child_pid,
        child_parent_pid=child_parent_pid, pre_process_count=Int(max(0, pre_process_count)),
        post_process_count=0, utc_start=String(utc_start), utc_end=String(utc_end),
        deadline_utc=String(deadline_utc), supervisor_wall_seconds=Float64(max(0.0, supervisor_wall_seconds)),
        supervisor_exit_code=sup_exit, supervisor_exit_relation=sup_relation,
        raw_exit_code=raw, termination=term, timeout_class=timeout,
        stdout_path=side_out.path, stderr_path=side_err.path, combined_path=side_combined.path,
        stdout_bytes=side_out.bytes, stdout_sha256=side_out.sha256,
        stderr_bytes=side_err.bytes, stderr_sha256=side_err.sha256,
        combined_bytes=side_combined.bytes, combined_sha256=side_combined.sha256,
        input_artifact_hash=input_artifact_hash isa Digest256 ? input_artifact_hash.value : String(input_artifact_hash),
        output_artifact_hash=artifact_hash, status=status)
    receipt_hash = digest256_text(_m5c_named_bytes(body))
    merge(body, (receipt_sha256=receipt_hash.value,))
end
const supervisor_receipt_v3 = m5c_supervisor_receipt

function validate_m5c_supervisor_receipt(receipt)
    try
        receipt.schema == "M5CSupervisorReceiptV3" || return false
        receipt.post_process_count == 0 || return false
        receipt.supervisor_exit_relation == (receipt.supervisor_exit_code == 0 ? :zero : :nonzero) || return false
        receipt.termination === :completed ? receipt.status === :completed && receipt.raw_exit_code !== nothing :
            receipt.status !== :completed
    catch
        false
    end
end

function _m5c_hostile_receipt()
    out, err, combined = "collision.stdout.raw", "collision.stderr.raw", "collision.combined.raw"
    stdout, stderr, allbytes = "key_collision\n", "fail_closed\n", "key_collision\nfail_closed\n"
    (pid=1, utc=M5CEG_RECEIPT_UTC_V3, exit_code=1, stdout_path=out,
     stderr_path=err, combined_path=combined, stdout_bytes=ncodeunits(stdout),
     stderr_bytes=ncodeunits(stderr), combined_bytes=ncodeunits(allbytes),
     stdout_sha256=digest256_text(stdout).value, stderr_sha256=digest256_text(stderr).value,
     combined_sha256=digest256_text(allbytes).value, status=:fail_closed)
end

"""Return the deterministic hostile digest-collision receipt required by R4."""
function m5c_collision_receipt(; forced_digest=repeat("0", 64))
    forced = String(forced_digest)
    length(forced) == 64 || throw(ArgumentError("forced digest must be 64 characters"))
    key_a = M5CByteKeyV1(:proposal, ("candidate-A", "upstream", "program-A", "conditions", "prov-A"))
    key_b = M5CByteKeyV1(:proposal, ("candidate-B", "upstream", "program-A", "conditions", "prov-A"))
    payload_a = (bytes=_m5c_b64(key_a.bytes), sha256=key_a.sha256.value, key_domain=:proposal)
    payload_b = (bytes=_m5c_b64(key_b.bytes), sha256=key_b.sha256.value, key_domain=:proposal)
    full_equal = key_a.bytes == key_b.bytes
    domains = Tuple((domain=d, emitted_id=string(d, ":", forced[1:16]),
        result=full_equal ? :dedup_allowed : :key_collision) for d in M5C_KEY_DOMAINS_V1)
    emitted = (proposal=(domains[1].emitted_id,), member=(domains[2].emitted_id,),
        visited=(domains[3].emitted_id,))
    (schema="M5CCollisionReceiptV3", protocol="M5CTestDigestV1",
     injection=(protocol="M5CTestDigestV1", forced_digest=forced,
        deterministic=true, seed="fixed"), payload_a=payload_a, payload_b=payload_b,
     forced_digest=forced, digest_equal=true, bucket_id=string("bucket:", forced[1:16]),
     full_key_a=_m5c_b64(key_a.bytes), full_key_b=_m5c_b64(key_b.bytes),
     full_key_sha256_a=key_a.sha256.value, full_key_sha256_b=key_b.sha256.value,
     full_key_equal=full_equal, outcome=full_equal ? :dedup_allowed : :key_collision,
     aggregate=full_equal ? :dedup_allowed : :fail_closed, domain_outcomes=domains,
     emitted_ids=emitted, hostile_supervisor_receipt=_m5c_hostile_receipt())
end
const collision_receipt_v3 = m5c_collision_receipt
const m5c_byte_key = M5CByteKeyV1
const m5c_key_equal = _m5c_key_equal

function validate_m5c_collision_receipt(receipt)
    try
        receipt.schema == "M5CCollisionReceiptV3" && receipt.protocol == "M5CTestDigestV1" || return false
        receipt.digest_equal === true && length(receipt.domain_outcomes) == 3 || return false
        receipt.full_key_equal ? receipt.aggregate == :dedup_allowed : receipt.aggregate == :fail_closed
    catch
        false
    end
end




function _m5ceg_condition(kind::Symbol, a, b)
    kind in M5CEG_CONDITION_KINDS_V1 ||
        throw(ArgumentError("unsupported manufactured e-graph condition kind"))
    # Include both upstream identities in every condition contract.  This
    # prevents a condition copied between manufactured products from passing.
    value = digest256_text(string("M5CEG|", kind, "|",
        manufactured_auto_composition_hash(a).value, "|",
        manufactured_inverse_feedback_hash(b).value))
    ref = QualifiedRefV1(string("M5CEG.condition.", kind), "v1")
    req = EqualityConditionRequirementV1(ref, value)
    ManufacturedConditionalEGraphConditionV1(kind, req, value)
end

struct ManufacturedConditionalEGraphV1
    schema::String
    source_program::TypedASTProgramV1
    source_program_hash::Digest256
    m5a_source_sha256::Digest256
    m5a_composition_hash::Digest256
    m5b_source_sha256::Digest256
    m5b_inverse_hash::Digest256
    owner_bindings::NamedTuple
    provenance_bindings::NamedTuple
    condition_catalog::Tuple{Vararg{ManufacturedConditionalEGraphConditionV1}}
    rewrite_set::ConditionalRewriteSetV1
    registry::OperatorRegistryV1
    budget::ConditionalEGraphBudgetV1
    profile::CanonicalizationProfileV1
    preflight_receipt::NamedTuple
    condition_envelope::NamedTuple
    binding_receipt::NamedTuple
    budget_receipt::NamedTuple
    cache_receipt::NamedTuple
    derivation::Union{Nothing,ConditionalEGraphDerivationResultV1}
    graph::Union{Nothing,DerivedConditionalEGraphV1}
    status::Symbol
    claim_ceiling::Symbol
    evidence_scope::Symbol
end

struct ManufacturedConditionalEGraphResultV1
    valid::Bool
    status::Symbol
    egraph::Union{Nothing,ManufacturedConditionalEGraphV1}
    failures::Tuple{Vararg{ManufacturedConditionalEGraphFailureV1}}
    claim_ceiling::Symbol
    evidence_scope::Symbol
    preflight_receipt::Union{Nothing,NamedTuple}
end

const ManufacturedConditionalEGraphValidationV1 = ManufacturedConditionalEGraphResultV1

_m5ceg_failure_tuple(fs) = Tuple(ManufacturedConditionalEGraphFailureV1[f for f in fs])
ManufacturedConditionalEGraphResultV1(valid::Bool, status::Symbol, egraph,
        failures::Tuple, claim_ceiling::Symbol, evidence_scope::Symbol) =
    ManufacturedConditionalEGraphResultV1(valid, status, egraph, failures,
        claim_ceiling, evidence_scope, nothing)
_m5ceg_invalid(fs; status=:typed_failure, preflight_receipt=nothing) = ManufacturedConditionalEGraphResultV1(
    false, status, nothing, _m5ceg_failure_tuple(fs),
    M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1, preflight_receipt)

function _m5ceg_unwrap_a(x)
    x isa ManufacturedAutoCompositionV1 && return x
    x isa ManufacturedAutoCompositionResultV1 && x.valid && x.composition !== nothing &&
        return x.composition
    nothing
end
function _m5ceg_unwrap_b(x)
    x isa ManufacturedInverseFeedbackV1 && return x
    x isa ManufacturedInverseFeedbackResultV1 && x.valid && x.inverse !== nothing &&
        return x.inverse
    nothing
end

function _m5ceg_hash(x)
    x isa Digest256 && return x
    digest256_text(String(x))
end

function _m5ceg_upstream_checks!(fs, a, b)
    a === nothing && push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A",
        "expected a valid ManufacturedAutoCompositionV1"))
    b === nothing && push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B",
        "expected a valid ManufacturedInverseFeedbackV1"))
    a === nothing || begin
        try
            validate_manufactured_auto_composition(a).valid ||
                push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A.validation",
                    "M5-A validation failed"))
            a.source_hashes == M5A_SOURCE_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-A.source_hashes",
                    "M5-A source identities are not frozen"))
            manufactured_auto_composition_hash(a) == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-A.composition_hash",
                    "M5-A composition hash does not match the frozen scope"))
        catch err
            push!(fs, _m5ceg_failure(:invalid_m5a, "M5-A",
                sprint(showerror, err)))
        end
    end
    b === nothing || begin
        try
            validate_inverse(b).valid ||
                push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B.validation",
                    "M5-B validation failed"))
            b.m5a_source_sha256 == M5CEG_M5A_SOURCE_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-B.m5a_source_sha256",
                    "M5-B is not bound to frozen M5-A"))
            b.m5a_composition_hash == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
                push!(fs, _m5ceg_failure(:foreign_hash, "M5-B.m5a_composition_hash",
                    "M5-B inverse receipt has a foreign M5-A composition hash"))
            b.claim_ceiling == M5I_CLAIM_CEILING_V1 &&
                b.evidence_scope == M5I_EVIDENCE_SCOPE_V1 ||
                push!(fs, _m5ceg_failure(:foreign_provenance, "M5-B.scope",
                    "M5-B must remain manufactured/screen_only"))
        catch err
            push!(fs, _m5ceg_failure(:invalid_m5b, "M5-B",
                sprint(showerror, err)))
        end
    end
    a === nothing || b === nothing || begin
        b.m5a_upstream === a || push!(fs, _m5ceg_failure(:foreign_hash,
            "M5-A/M5-B.join", "M5-B does not retain the supplied M5-A object"))
        b.owner_bindings == _m5ceg_owner_projection(a, b) ||
            push!(fs, _m5ceg_failure(:foreign_owner, "M5-B.owner_bindings",
                "owner binding ledger is not the retained M5-B projection"))
        b.provenance_bindings == _m5ceg_provenance_projection(a, b) ||
            push!(fs, _m5ceg_failure(:foreign_provenance, "M5-B.provenance_bindings",
                "provenance ledger is not the retained M5-B projection"))
    end
    nothing
end

_m5ceg_owner_projection(a, b) = b.owner_bindings
_m5ceg_provenance_projection(a, b) = b.provenance_bindings

function _m5ceg_condition_catalog(a, b)
    Tuple(_m5ceg_condition(k, a, b) for k in M5CEG_CONDITION_KINDS_V1)
end
const m5c_condition_catalog = _m5ceg_condition_catalog

function _m5ceg_requirements(catalog)
    cs = Tuple(catalog)
    length(cs) == length(M5CEG_CONDITION_KINDS_V1) ||
        throw(ArgumentError("manufactured e-graph requires eight typed conditions"))
    seen = Symbol[]
    req = EqualityConditionRequirementV1[]
    for c in cs
        c isa ManufacturedConditionalEGraphConditionV1 ||
            throw(ArgumentError("condition catalog contains an untyped value"))
        c.kind in M5CEG_CONDITION_KINDS_V1 ||
            throw(ArgumentError("condition catalog contains an unsupported kind"))
        c.kind in seen && throw(ArgumentError("condition catalog contains duplicate kinds"))
        push!(seen, c.kind)
        c.requirement.condition_contract_hash == c.expected_hash ||
            throw(ArgumentError("condition contract hash does not match expected hash"))
        push!(req, c.requirement)
    end
    all(k -> k in seen, M5CEG_CONDITION_KINDS_V1) ||
        throw(ArgumentError("condition catalog is missing a typed condition"))
    Tuple(req)
end

function _m5ceg_catalog_matches(catalog, a, b)
    expected = _m5ceg_condition_catalog(a, b)
    actual = Tuple(catalog)
    length(actual) == length(expected) || return false
    for i in eachindex(expected)
        left, right = expected[i], actual[i]
        left.kind == right.kind || return false
        _ceg_ref_equal(left.requirement.condition_ref, right.requirement.condition_ref) || return false
        left.expected_hash == right.expected_hash || return false
        left.requirement.condition_contract_hash == right.requirement.condition_contract_hash || return false
    end
    true
end

function _m5ceg_rhs(source::TypedASTProgramV1; registry::OperatorRegistryV1)
    nodes = getfield(source, :nodes)
    ports = getfield(source, :input_ports)
    fieldcount(typeof(ports)) == 3 && fieldcount(typeof(nodes)) == 8 ||
        throw(ArgumentError("frozen M5-A canonical program shape is required"))
    all(typeof(getfield(nodes, i)) === ASTInputV1 for i in 1:3) ||
        throw(ArgumentError("M5-A canonical inputs are not typed AST inputs"))
    t1, t2, t3 = (getfield(getfield(nodes, i), :output_type) for i in 1:3)
    add = OperatorRefV1("ADD", "v1")
    neg = OperatorRefV1("NEG", "v1")
    n4 = ASTApplyV1(add, (1, 3), (;); registry=registry, input_types=(t1, t3))
    n5 = ASTApplyV1(add, (4, 2), (;); registry=registry,
        input_types=(getfield(n4, :output_type), t2))
    n6 = ASTApplyV1(neg, (5,), (;); registry=registry,
        input_types=(getfield(n5, :output_type),))
    n7 = ASTApplyV1(neg, (6,), (;); registry=registry,
        input_types=(getfield(n6, :output_type),))
    n8 = ASTApplyV1(OperatorRefV1("IDENTITY", "v1"), (7,), (;);
        registry=registry, input_types=(getfield(n7, :output_type),))
    TypedASTProgramV1((getfield(nodes, 1), getfield(nodes, 2), getfield(nodes, 3),
        n4, n5, n6, n7, n8), getfield(source, :roots), getfield(source, :input_ports), registry)
end

function _m5ceg_rewrite_set(source, catalog; registry::OperatorRegistryV1)
    req = _m5ceg_requirements(catalog)
    rhs = _m5ceg_rhs(source; registry=registry)
    checker = QualifiedRefV1("M5CEG.synthetic.condition.checker", "v1")
    checker_hash = digest256_text("M5CEG|typed-condition-checker|v1")
    rules = WholeProgramConditionalRewriteV1[]
    push!(rules, WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.reassociate_add", "v1"), source, rhs,
        req, checker, checker_hash; registry=registry))
    # A second orientation-changing root order is deliberately tiny and
    # remains within the same typed interface.  It is still synthetic.
    reordered = TypedASTProgramV1(getfield(source, :nodes),
        reverse(getfield(source, :roots)), getfield(source, :input_ports), registry)
    push!(rules, WholeProgramConditionalRewriteV1(
        QualifiedRefV1("M5CEG.root_order", "v1"), source, reordered,
        req, checker, checker_hash; registry=registry))
    ConditionalRewriteSetV1(Tuple(rules))
end

function _m5ceg_build(a, b; registry=nothing,
        budget::ConditionalEGraphBudgetV1=ConditionalEGraphBudgetV1(),
        profile::CanonicalizationProfileV1=default_canonicalization_profile(),
        condition_catalog=nothing, preflight_receipt=nothing)
    registry_obj = registry === nothing ? default_operator_registry() : registry
    registry_obj isa OperatorRegistryV1 || throw(ArgumentError("registry must be OperatorRegistryV1"))
    catalog = condition_catalog === nothing ? _m5ceg_condition_catalog(a, b) : Tuple(condition_catalog)
    preflight = preflight_receipt === nothing ? m5c_preflight(a, b;
        budget=budget, profile=profile) : preflight_receipt
    preflight.decision == :admit || throw(ArgumentError("M5C preflight deferred before construction"))
    candidate = _m5ceg_candidate_id(a, b)
    envelope = m5c_condition_envelope(a, b, catalog; candidate_id=candidate)
    validate_m5c_condition_envelope(envelope) ||
        throw(ArgumentError("M5C condition envelope failed closed validation"))
    source = a.canonical_program
    source_hash = invoke(_ceg_program_hash, Tuple{TypedASTProgramV1}, source)
    rules = _m5ceg_rewrite_set(source, catalog; registry=registry_obj)
    derivation = derive_conditional_program_egraph(source, rules, registry_obj;
        saturation_budget=budget, canonicalization_profile=profile)
    graph = derivation.artifact
    status = graph === nothing ? :terminal_deferred :
        (graph.complete ? :valid : :terminal_deferred)
    inverse_hash = manufactured_inverse_feedback_hash(b)
    budget_receipt = m5c_budget_receipt(requested_budget=budget.max_rewrite_attempts,
        sealed_budget=budget.max_rewrite_attempts,
        effective_budget=budget.max_rewrite_attempts)
    binding_receipt = m5c_binding_receipt(a, b, catalog, rules, derivation, graph;
        candidate_id=candidate, adapter_status=status)
    cache_receipt = m5c_cache_receipt(a, b, catalog, rules, derivation, graph;
        candidate_id=candidate, binding_receipt=binding_receipt)
    ManufacturedConditionalEGraphV1(M5CEG_SCHEMA_V1, source, source_hash,
        M5CEG_M5A_SOURCE_SHA256_V1, M5CEG_M5A_COMPOSITION_SHA256_V1,
        M5CEG_M5B_SOURCE_SHA256_V1, inverse_hash, b.owner_bindings,
        b.provenance_bindings, catalog, rules, registry_obj, budget, profile,
        preflight, envelope, binding_receipt, budget_receipt, cache_receipt,
        derivation, graph, status, M5CEG_CLAIM_CEILING_V1,
        M5CEG_EVIDENCE_SCOPE_V1)
end

function build_manufactured_conditional_egraph(a_input, b_input;
        registry=nothing, budget=ConditionalEGraphBudgetV1(),
        profile=default_canonicalization_profile(), condition_catalog=nothing)
    a, b = _m5ceg_unwrap_a(a_input), _m5ceg_unwrap_b(b_input)
    fs = ManufacturedConditionalEGraphFailureV1[]
    _m5ceg_upstream_checks!(fs, a, b)
    isempty(fs) || return _m5ceg_invalid(fs; status=:fail_closed)
    budget isa ConditionalEGraphBudgetV1 ||
        push!(fs, _m5ceg_failure(:invalid_budget, "budget", "budget is not typed"))
    profile isa CanonicalizationProfileV1 ||
        push!(fs, _m5ceg_failure(:invalid_profile, "profile", "profile is not typed"))
    if condition_catalog !== nothing
        try
            _m5ceg_requirements(condition_catalog)
            _m5ceg_catalog_matches(condition_catalog, a, b) ||
                push!(fs, _m5ceg_failure(:condition_rejected, "conditions",
                    "condition catalog is not bound to the supplied M5-A/M5-B identities"))
        catch err
            push!(fs, _m5ceg_failure(:condition_rejected, "conditions",
                sprint(showerror, err)))
        end
    end
    isempty(fs) || return _m5ceg_invalid(fs; status=:fail_closed)
    preflight = m5c_preflight(a, b; budget=budget, profile=profile)
    preflight.decision == :admit || return _m5ceg_invalid([_m5ceg_failure(
        :preflight_deferred, "preflight", string("M5C preflight: ", preflight.reason))];
        status=:terminal_deferred, preflight_receipt=preflight)
    try
        product = _m5ceg_build(a, b; registry=registry, budget=budget,
            profile=profile, condition_catalog=condition_catalog,
            preflight_receipt=preflight)
        checked = validate_manufactured_conditional_egraph(product)
        checked.valid ? checked : ManufacturedConditionalEGraphResultV1(
            false, checked.status, product, checked.failures,
            M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1)
    catch err
        _m5ceg_invalid([_m5ceg_failure(:fail_closed, "construction",
            sprint(showerror, err))]; status=:fail_closed)
    end
end

function saturate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1;
        budget=x.budget)
    budget isa ConditionalEGraphBudgetV1 || throw(ArgumentError("budget must be typed"))
    same_budget = budget.max_programs == x.budget.max_programs &&
        budget.max_rewrite_attempts == x.budget.max_rewrite_attempts &&
        budget.max_rounds == x.budget.max_rounds &&
        budget.max_trace_steps == x.budget.max_trace_steps
    same_budget || return _m5ceg_invalid([_m5ceg_failure(
        :budget_mismatch, "budget", "sealed product budget differs from requested budget")];
        status=:budget_mismatch)
    # Build already performs one bounded saturation.  This operation is a
    # receipt-preserving idempotent view; no second engine is introduced here.
    x
end
saturate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1; kwargs...) =
    x.egraph === nothing ? x : saturate_manufactured_conditional_egraph(x.egraph; kwargs...)
saturate_manufactured_conditional_egraph(a_input, b_input; kwargs...) =
    build_manufactured_conditional_egraph(a_input, b_input; kwargs...)

function replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1, provenance::ConditionalEqualityProvenanceV1)
    replay_conditional_rewrite_trace(x.source_program, target, x.rewrite_set,
        x.registry, provenance)
end
replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1, provenance::ConditionalEqualityProvenanceV1) =
    x.egraph === nothing ? false : replay_manufactured_conditional_egraph(x.egraph, target, provenance)
function replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1)
    result = query_manufactured_conditional_equality(x, target)
    result === nothing || result.provenance === nothing ? false :
        replay_manufactured_conditional_egraph(x, target, result.provenance)
end
replay_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1) =
    x.egraph === nothing ? false : replay_manufactured_conditional_egraph(x.egraph, target)

function query_manufactured_conditional_equality(x::ManufacturedConditionalEGraphV1,
        target::TypedASTProgramV1)
    x.graph === nothing ? nothing : query_conditional_equality(x.graph, target)
end
query_manufactured_conditional_equality(x::ManufacturedConditionalEGraphResultV1,
        target::TypedASTProgramV1) =
    x.egraph === nothing ? nothing : query_manufactured_conditional_equality(x.egraph, target)

function validate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1)
    fs = ManufacturedConditionalEGraphFailureV1[]
    x.schema == M5CEG_SCHEMA_V1 || push!(fs, _m5ceg_failure(:foreign_identity, "schema", "schema is foreign"))
    x.claim_ceiling == M5CEG_CLAIM_CEILING_V1 && x.evidence_scope == M5CEG_EVIDENCE_SCOPE_V1 ||
        push!(fs, _m5ceg_failure(:foreign_provenance, "scope", "claim ceiling is not synthetic/screen_only"))
    try
        x.preflight_receipt.schema == "M5CPreflightReceiptV3" &&
            x.preflight_receipt.decision == :admit || push!(fs, _m5ceg_failure(
                :preflight_invalid, "preflight_receipt", "admitted product lacks an admitted V3 preflight"))
        validate_m5c_condition_envelope(x.condition_envelope) ||
            push!(fs, _m5ceg_failure(:condition_rejected, "condition_envelope",
                "available condition envelope is not closed"))
        (validate_m5c_binding_receipt(x.binding_receipt) ||
            (x.graph === nothing && x.status == :terminal_deferred)) ||
            push!(fs, _m5ceg_failure(:binding_detached, "binding_receipt",
                "full binding receipt is not closed"))
        x.budget_receipt.schema == "M5CBudgetReceiptV3" &&
            x.budget_receipt.budget_relation == :equal || push!(fs, _m5ceg_failure(
                :budget_invalid, "budget_receipt", "sealed product budget receipt is not equal"))
        validate_m5c_cache_receipt(x.cache_receipt) ||
            push!(fs, _m5ceg_failure(:cache_entry_incomplete, "cache_receipt",
                "adapter cache receipt is not a sealed same-identity cache"))
        _ceg_digest_equal(x.source_program_hash, _ceg_program_hash(x.source_program)) ||
            push!(fs, _m5ceg_failure(:foreign_hash, "source_program_hash", "source hash does not replay"))
        x.m5a_source_sha256 == M5CEG_M5A_SOURCE_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5a_source_sha256", "M5-A source hash is foreign"))
        x.m5a_composition_hash == M5CEG_M5A_COMPOSITION_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5a_composition_hash", "M5-A composition hash is foreign"))
        x.m5b_source_sha256 == M5CEG_M5B_SOURCE_SHA256_V1 ||
            push!(fs, _m5ceg_failure(:foreign_hash, "m5b_source_sha256", "M5-B source hash is foreign"))
        _m5ceg_requirements(x.condition_catalog)
        x.graph === nothing && x.derivation === nothing &&
            push!(fs, _m5ceg_failure(:missing_derivation, "derivation", "no derivation receipt retained"))
        if x.graph === nothing
            x.status == :terminal_deferred || push!(fs, _m5ceg_failure(
                :status_mismatch, "status", "an absent graph must be terminal_deferred"))
        else
            x.graph.source_hash == x.source_program_hash ||
                push!(fs, _m5ceg_failure(:foreign_hash, "graph.source_hash", "graph source hash is foreign"))
            status_ok = x.graph.complete ? (x.status == :valid) :
                (x.status == :terminal_deferred)
            status_ok || push!(fs, _m5ceg_failure(:status_mismatch, "status", "graph completeness and status are inconsistent"))
        end
    catch err
        push!(fs, _m5ceg_failure(:fail_closed, "validation", sprint(showerror, err)))
    end
    ManufacturedConditionalEGraphResultV1(isempty(fs), isempty(fs) ? x.status : :typed_failure,
        x, _m5ceg_failure_tuple(fs), M5CEG_CLAIM_CEILING_V1, M5CEG_EVIDENCE_SCOPE_V1)
end
validate_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1) =
    x.egraph === nothing ? x : validate_manufactured_conditional_egraph(x.egraph)
validate_manufactured_conditional_egraph(x) = _m5ceg_invalid([_m5ceg_failure(
    :invalid_input, "input", "expected ManufacturedConditionalEGraphV1")]; status=:fail_closed)

function manufactured_conditional_egraph_payload(x::ManufacturedConditionalEGraphV1)
    (schema=x.schema, source_program=invoke(_typed_ast_program_json,
        Tuple{TypedASTProgramV1}, x.source_program), source_program_hash=x.source_program_hash,
     m5a_source_sha256=x.m5a_source_sha256, m5a_composition_hash=x.m5a_composition_hash,
     m5b_source_sha256=x.m5b_source_sha256, m5b_inverse_hash=x.m5b_inverse_hash,
     owners=x.owner_bindings, provenance=x.provenance_bindings,
     conditions=Tuple((kind=c.kind, requirement=c.requirement,
        expected_hash=c.expected_hash) for c in x.condition_catalog),
     rewrite_set=canonical_json(x.rewrite_set), budget=x.budget, profile=x.profile,
     preflight_receipt=x.preflight_receipt, condition_envelope=x.condition_envelope,
     binding_receipt=x.binding_receipt, budget_receipt=x.budget_receipt,
     cache_receipt=x.cache_receipt,
     derivation=x.derivation === nothing ? nothing : canonical_json(x.derivation),
     graph=x.graph === nothing ? nothing : canonical_json(x.graph), status=x.status,
     claim_ceiling=x.claim_ceiling, evidence_scope=x.evidence_scope)
end
manufactured_conditional_egraph_payload(x) =
    (schema=M5CEG_SCHEMA_V1, status=:typed_failure, input_type=typeof(x))

function manufactured_conditional_egraph_hash(x::ManufacturedConditionalEGraphV1)
    p = manufactured_conditional_egraph_payload(x)
    bytes = try
        canonical_json(p)
    catch
        try
            invoke(_tac_value_string, Tuple{Any}, p)
        catch
            repr(p)
        end
    end
    digest256_text(bytes)
end
manufactured_conditional_egraph_hash(x) = digest256_text(
    string(manufactured_conditional_egraph_payload(x)))

is_valid_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphV1) =
    validate_manufactured_conditional_egraph(x).valid
is_valid_manufactured_conditional_egraph(x::ManufacturedConditionalEGraphResultV1) = x.valid
is_valid_manufactured_conditional_egraph(x) = false

const build_manufactured_conditional_egraph_v1 = build_manufactured_conditional_egraph
const manufactured_conditional_egraph = build_manufactured_conditional_egraph
const validate_manufactured_conditional_egraph_v1 = validate_manufactured_conditional_egraph
const manufactured_conditional_egraph_payload_v1 = manufactured_conditional_egraph_payload
const manufactured_conditional_egraph_hash_v1 = manufactured_conditional_egraph_hash
const is_valid_manufactured_conditional_egraph_v1 = is_valid_manufactured_conditional_egraph
if !isdefined(@__MODULE__, :build_conditional_egraph)
    const build_conditional_egraph = build_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :saturate_conditional_egraph)
    const saturate_conditional_egraph = saturate_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :replay_conditional_egraph)
    const replay_conditional_egraph = replay_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :query_conditional_egraph)
    const query_conditional_egraph = query_manufactured_conditional_equality
end
if !isdefined(@__MODULE__, :validate)
    const validate = validate_manufactured_conditional_egraph
end
if !isdefined(@__MODULE__, :payload)
    const payload = manufactured_conditional_egraph_payload
end
if !isdefined(@__MODULE__, :is_valid)
    const is_valid = is_valid_manufactured_conditional_egraph
end
