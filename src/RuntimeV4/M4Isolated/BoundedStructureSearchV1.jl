"""Additive, isolated UP5 structure-search contract.

This module is deliberately not included by RuntimeV4.  It is a prepared
screen-only seam for a deterministic, grammar-guided prefix DAG.  It does not
invoke a registry, provider, solver, mesh, physical model, or engineering
backend.  The content receipt excludes operational fields (PID, time, paths,
and run identifiers), so a fresh-process replay can compare content exactly.
"""
module BoundedStructureSearchV1

using SHA

struct _BoundedStructureSearchSealV1 end
const _BSS_SEAL_V1 = _BoundedStructureSearchSealV1()
struct _BudgetAuthoritySealV1 end
const _BUDGET_AUTHORITY_SEAL_V1 = _BudgetAuthoritySealV1()

export Digest256V1, digest_text, canonical_bytes, canonical_hash,
       SearchInputClosureV1, StructurePrefixV1, StructureActionV1,
       StructureSearchBudgetV1, BudgetEventV1, BudgetLedgerV1,
       StructureLedgerSnapshotV1,
       StructureReplayReceiptV1, StructureActionResultV1,
       StructureProposalV1, StructureDescriptorV1,
       StructureContentReceiptV1, StructureOperationalEnvelopeV1,
       StructureFailureV1, StructureSearchResultV1,
       validate_closure, make_root_prefix, apply_action,
       build_prefix_dag, descriptor, make_content_receipt,
       make_operational_envelope, prepare_search, validate_result,
       budget_event, record_event!, replay_content_hash,
       FROZEN_SEEDS, DEFAULT_BUDGET

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

_nonempty(x, field) = begin
    v = String(x)
    isempty(strip(v)) && throw(ArgumentError("$field cannot be empty"))
    v
end

"""Small deterministic encoder; it is not an evidence or JSON authority."""
_canon(x::Nothing) = "null"
_canon(x::Bool) = x ? "true" : "false"
_canon(x::Symbol) = ":" * String(x)
_canon(x::AbstractString) = repr(String(x))
_canon(x::Integer) = string(x)
_canon(x::AbstractFloat) = isfinite(x) ? repr(x) : throw(ArgumentError("non-finite canonical value"))
_canon(x::Digest256V1) = "digest(" * x.value * ")"
_canon(x::Tuple) = "(" * join((_canon(v) for v in x), ",") * ")"
function _canon(x::AbstractVector)
    x isa Array && ndims(x) == 1 ||
        throw(ArgumentError("unsupported canonical vector type $(typeof(x))"))
    "[" * join((_canon(v) for v in x), ",") * "]"
end
function _canon(x::NamedTuple)
    keys_sorted = sort(collect(keys(x)), by=String)
    "{" * join((String(k) * "=" * _canon(getfield(x, k)) for k in keys_sorted), ";") * "}"
end
_canon(x) = throw(ArgumentError("unsupported canonical type $(typeof(x))"))

"""Validate the closed node-payload value grammar before canonical encoding.

This is intentionally separate from `_canon`: constructor admission must turn
every unsupported nested value into the contract-level `ArgumentError`, even
when a future method-table change would otherwise surface a dispatch error.
The accepted set exactly mirrors the explicit `_canon` methods above.
"""
_validate_node_payload_canonical(::Nothing) = nothing
_validate_node_payload_canonical(::Bool) = nothing
_validate_node_payload_canonical(::Symbol) = nothing
_validate_node_payload_canonical(::AbstractString) = nothing
_validate_node_payload_canonical(::Integer) = nothing
_validate_node_payload_canonical(x::AbstractFloat) = begin
    isfinite(x) || throw(ArgumentError("non-finite canonical value"))
    nothing
end
_validate_node_payload_canonical(::Digest256V1) = nothing
_validate_node_payload_canonical(x::Tuple) = begin
    foreach(_validate_node_payload_canonical, x)
    nothing
end
_validate_node_payload_canonical(x::NamedTuple) = begin
    foreach(k -> _validate_node_payload_canonical(getfield(x, k)), keys(x))
    nothing
end
_validate_node_payload_canonical(x::AbstractVector) = begin
    x isa Array && ndims(x) == 1 ||
        throw(ArgumentError("unsupported canonical vector type $(typeof(x))"))
    foreach(_validate_node_payload_canonical, x)
    nothing
end
_validate_node_payload_canonical(x::AbstractDict) =
    throw(ArgumentError("unsupported canonical type $(typeof(x))"))
_validate_node_payload_canonical(x::AbstractSet) =
    throw(ArgumentError("unsupported canonical type $(typeof(x))"))
_validate_node_payload_canonical(x) =
    throw(ArgumentError("unsupported canonical type $(typeof(x))"))

canonical_bytes(x) = Vector{UInt8}(codeunits(_canon(x)))
canonical_hash(x) = Digest256V1(bytes2hex(SHA.sha256(canonical_bytes(x))))
digest_text(x::AbstractString) = Digest256V1(bytes2hex(SHA.sha256(codeunits(String(x)))))

const FROZEN_SEEDS = (11, 23, 37, 41, 53, 67, 79, 97)

struct SearchInputClosureV1
    candidate_ref::String
    candidate_hash::Digest256V1
    g1_hash::Digest256V1
    g2_hash::Digest256V1
    g3_hash::Digest256V1
    component_hash::Digest256V1
    registry_hash::Digest256V1
    source_bundle_hash::Digest256V1
    grammar_hash::Digest256V1
    mission_hash::Digest256V1
    bounds_hash::Digest256V1
    scenario_hash::Digest256V1
    condition_registry_hash::Digest256V1
    m5c_gate_hash::Union{Nothing,Digest256V1}
    m5c_gate_status::Symbol
    candidate_generation::UInt64
    source_generation::UInt64
    freshness_hash::Digest256V1
    closure_hash::Digest256V1
    function SearchInputClosureV1(candidate_ref, candidate_hash, g1_hash, g2_hash,
                                  g3_hash, component_hash, registry_hash,
                                  source_bundle_hash, grammar_hash, mission_hash,
                                  bounds_hash, scenario_hash, condition_registry_hash;
                                  m5c_gate_hash=nothing, m5c_gate_status=:typed_absent,
                                  candidate_generation=1, source_generation=1,
                                  freshness_hash=nothing)
        ref = _nonempty(candidate_ref, "candidate_ref")
        m5c_gate_status in (:accepted, :typed_absent, :stale, :rejected) ||
            throw(ArgumentError("invalid M5-C gate status"))
        candidate_generation isa Integer && candidate_generation > 0 ||
            throw(ArgumentError("candidate_generation must be positive"))
        source_generation isa Integer && source_generation > 0 ||
            throw(ArgumentError("source_generation must be positive"))
        gate = m5c_gate_hash === nothing ? nothing : (m5c_gate_hash isa Digest256V1 ?
            m5c_gate_hash : throw(ArgumentError("M5-C gate hash must be Digest256V1")))
        gate_status = gate === nothing ? :typed_absent : m5c_gate_status
        candidate_gen = UInt64(candidate_generation)
        source_gen = UInt64(source_generation)
        expected_freshness = canonical_hash((candidate_ref=ref,
            candidate_hash=candidate_hash, source_bundle_hash=source_bundle_hash,
            candidate_generation=candidate_gen, source_generation=source_gen))
        freshness = freshness_hash === nothing ? expected_freshness :
            (freshness_hash isa Digest256V1 ? freshness_hash :
             throw(ArgumentError("freshness_hash must be Digest256V1")))
        body = (candidate_ref=ref, candidate_hash=candidate_hash, g1_hash=g1_hash,
            g2_hash=g2_hash, g3_hash=g3_hash, component_hash=component_hash,
            registry_hash=registry_hash, source_bundle_hash=source_bundle_hash,
            grammar_hash=grammar_hash, mission_hash=mission_hash,
            bounds_hash=bounds_hash, scenario_hash=scenario_hash,
            condition_registry_hash=condition_registry_hash, m5c_gate_hash=gate,
            m5c_gate_status=gate_status, candidate_generation=candidate_gen,
            source_generation=source_gen, freshness_hash=freshness)
        new(ref, candidate_hash, g1_hash, g2_hash, g3_hash, component_hash,
            registry_hash, source_bundle_hash, grammar_hash, mission_hash,
            bounds_hash, scenario_hash, condition_registry_hash, gate, gate_status,
            candidate_gen, source_gen, freshness, canonical_hash(body))
    end
end

function validate_closure(c::SearchInputClosureV1; require_m5c=true,
                          expected_candidate_generation=nothing,
                          expected_source_generation=nothing,
                          expected_freshness_hash=nothing)
    c.m5c_gate_status === :accepted || !require_m5c ||
        return (:not_executed, :terminal_deferred, :missing_m5c_authority)
    c.candidate_ref == strip(c.candidate_ref) ||
        return (:fail_closed, :fail_closed, :malformed_candidate_ref)
    c.candidate_generation > 0 && c.source_generation > 0 ||
        return (:fail_closed, :fail_closed, :invalid_generation)
    expected_candidate_generation !== nothing &&
        UInt64(expected_candidate_generation) != c.candidate_generation &&
        return (:fail_closed, :fail_closed, :candidate_generation_mismatch)
    expected_source_generation !== nothing &&
        UInt64(expected_source_generation) != c.source_generation &&
        return (:fail_closed, :fail_closed, :source_generation_mismatch)
    expected_freshness = canonical_hash((candidate_ref=c.candidate_ref,
        candidate_hash=c.candidate_hash, source_bundle_hash=c.source_bundle_hash,
        candidate_generation=c.candidate_generation,
        source_generation=c.source_generation))
    c.freshness_hash == expected_freshness ||
        return (:fail_closed, :fail_closed, :freshness_hash_mismatch)
    expected_freshness_hash !== nothing &&
        c.freshness_hash != expected_freshness_hash &&
        return (:fail_closed, :fail_closed, :freshness_binding_mismatch)
    c.closure_hash == canonical_hash((candidate_ref=c.candidate_ref,
        candidate_hash=c.candidate_hash, g1_hash=c.g1_hash, g2_hash=c.g2_hash,
        g3_hash=c.g3_hash, component_hash=c.component_hash,
        registry_hash=c.registry_hash, source_bundle_hash=c.source_bundle_hash,
        grammar_hash=c.grammar_hash, mission_hash=c.mission_hash,
        bounds_hash=c.bounds_hash, scenario_hash=c.scenario_hash,
        condition_registry_hash=c.condition_registry_hash,
        m5c_gate_hash=c.m5c_gate_hash, m5c_gate_status=c.m5c_gate_status,
        candidate_generation=c.candidate_generation,
        source_generation=c.source_generation, freshness_hash=c.freshness_hash)) ||
        return (:fail_closed, :fail_closed, :closure_hash_mismatch)
    (:ready, :screen_only, :none)
end

struct StructurePrefixV1
    candidate_ref::String
    closure_hash::Digest256V1
    parent_prefix_hash::Union{Nothing,Digest256V1}
    action_refs::Tuple{Vararg{String}}
    node_payload::Tuple
    prefix_hash::Digest256V1
    function StructurePrefixV1(candidate_ref, closure_hash,
                               parent_prefix_hash, action_refs, node_payload)
        refs = Tuple(_nonempty(x, "action_ref") for x in action_refs)
        payload = Tuple(node_payload)
        body = (candidate_ref=String(candidate_ref), closure_hash=closure_hash,
            parent_prefix_hash=parent_prefix_hash, action_refs=refs,
            node_payload=payload)
        new(String(candidate_ref), closure_hash, parent_prefix_hash, refs, payload,
            canonical_hash(body))
    end
end

make_root_prefix(c::SearchInputClosureV1) = StructurePrefixV1(
    c.candidate_ref, c.closure_hash, nothing, (), ())

struct StructureActionV1
    action_ref::String
    parent_prefix_hash::Digest256V1
    node_payload::NamedTuple
    condition_status::Symbol
    condition_hash::Digest256V1
    token_generation::UInt64
    source_generation::UInt64
    function StructureActionV1(action_ref, parent_prefix_hash, node_payload,
                               condition_status, condition_hash;
                               token_generation, source_generation)
        condition_status in (:conditions_met, :condition_unmet, :equality_unknown,
            :terminal_deferred, :contradiction, :fail_closed) ||
            throw(ArgumentError("invalid condition status"))
        node_payload isa NamedTuple || throw(ArgumentError("node payload must be NamedTuple"))
        # Force validation of the complete payload closure at the boundary;
        # repr-based fallback is intentionally unavailable for node payloads.
        _validate_node_payload_canonical(node_payload)
        canonical_bytes(node_payload)
        token_generation >= 1 || throw(ArgumentError("token generation is required and must be positive"))
        source_generation >= 1 || throw(ArgumentError("source generation is required and must be positive"))
        new(_nonempty(action_ref, "action_ref"), parent_prefix_hash, node_payload,
            condition_status, condition_hash, UInt64(token_generation),
            UInt64(source_generation))
    end
end

struct StructureSearchBudgetV1
    max_seeds::Int
    max_rewrites_per_seed::Int
    max_prefixes::Int
    max_proposal_receipts::Int
    max_provider_steps::Int
    max_solver_steps::Int
    max_mesh_steps::Int
    max_physical_steps::Int
    budget_hash::Digest256V1
    function StructureSearchBudgetV1(; max_seeds=8, max_rewrites_per_seed=32,
        max_prefixes=64, max_proposal_receipts=48,
        max_provider_steps=0, max_solver_steps=0, max_mesh_steps=0,
        max_physical_steps=0)
        vals = (max_seeds, max_rewrites_per_seed, max_prefixes,
            max_proposal_receipts, max_provider_steps, max_solver_steps,
            max_mesh_steps, max_physical_steps)
        all(x -> x >= 0, vals) || throw(ArgumentError("budget caps must be non-negative"))
        (max_provider_steps, max_solver_steps, max_mesh_steps, max_physical_steps) ==
            (0, 0, 0, 0) ||
            throw(ArgumentError("provider/solver/mesh/physical caps are fixed at zero"))
        body = (max_seeds=max_seeds, max_rewrites_per_seed=max_rewrites_per_seed,
            max_prefixes=max_prefixes, max_proposal_receipts=max_proposal_receipts,
            max_provider_steps=max_provider_steps,
            max_solver_steps=max_solver_steps, max_mesh_steps=max_mesh_steps,
            max_physical_steps=max_physical_steps)
        new(Int(vals[1]), Int(vals[2]), Int(vals[3]), Int(vals[4]),
            Int(vals[5]), Int(vals[6]), Int(vals[7]), Int(vals[8]),
            canonical_hash(body))
    end
    function StructureSearchBudgetV1(::_BudgetAuthoritySealV1,
        max_seeds::Int, max_rewrites_per_seed::Int, max_prefixes::Int,
        max_proposal_receipts::Int, max_provider_steps::Int, max_solver_steps::Int,
        max_mesh_steps::Int, max_physical_steps::Int, budget_hash::Digest256V1)
        new(max_seeds, max_rewrites_per_seed, max_prefixes,
            max_proposal_receipts, max_provider_steps, max_solver_steps,
            max_mesh_steps, max_physical_steps, budget_hash)
    end
end

function StructureSearchBudgetV1(vals::Vararg{Int,8})
    b = StructureSearchBudgetV1(max_seeds=vals[1], max_rewrites_per_seed=vals[2],
        max_prefixes=vals[3], max_proposal_receipts=vals[4],
        max_provider_steps=vals[5], max_solver_steps=vals[6],
        max_mesh_steps=vals[7], max_physical_steps=vals[8])
    b
end

const DEFAULT_BUDGET = StructureSearchBudgetV1()

struct BudgetEventV1
    stage::Symbol
    seed::Int
    sequence::Int
    before::Int
    after::Int
    limit::Int
    remaining::Int
    status::Symbol
    event_hash::Digest256V1
    function BudgetEventV1(stage, seed, sequence, before, after, limit, status)
        before >= 0 && after >= before && limit >= 0 ||
            throw(ArgumentError("invalid budget event counters"))
        after <= limit || throw(ArgumentError("budget exceeded; fail closed"))
        status in (:progress, :complete, :saturation_incomplete) ||
            throw(ArgumentError("invalid budget event status"))
        body = (stage=stage, seed=seed, sequence=sequence, before=before,
            after=after, limit=limit, remaining=limit-after, status=status)
        new(stage, Int(seed), Int(sequence), Int(before), Int(after), Int(limit),
            Int(limit-after), status, canonical_hash(body))
    end
end
budget_event(stage, seed, sequence, before, after, limit; status=:progress) =
    BudgetEventV1(stage, seed, sequence, before, after, limit, status)

mutable struct BudgetLedgerV1
    events::Vector{BudgetEventV1}
    counters::Dict{Symbol,Int}
    function BudgetLedgerV1()
        new(BudgetEventV1[], Dict{Symbol,Int}(
            :eclasses=>0, :enodes=>0, :rewrites=>0, :trace_rows=>0,
            :prefixes=>0, :screen_evaluations=>0, :proposal_receipts=>0,
            :global_trace_rows=>0,
            :qd_proposals=>0, :mcts_proposals=>0, :provider_steps=>0,
            :solver_steps=>0, :mesh_steps=>0, :physical_steps=>0))
    end
end

const _LEDGER_COUNTER_KEYS = (:eclasses, :enodes, :rewrites, :trace_rows,
    :global_trace_rows, :prefixes, :screen_evaluations, :proposal_receipts,
    :qd_proposals, :mcts_proposals, :provider_steps, :solver_steps,
    :mesh_steps, :physical_steps)

_budget_body(b::StructureSearchBudgetV1) =
    (max_seeds=b.max_seeds, max_rewrites_per_seed=b.max_rewrites_per_seed,
     max_prefixes=b.max_prefixes, max_proposal_receipts=b.max_proposal_receipts,
     max_provider_steps=b.max_provider_steps, max_solver_steps=b.max_solver_steps,
     max_mesh_steps=b.max_mesh_steps, max_physical_steps=b.max_physical_steps)

function _validate_budget_authority(b::StructureSearchBudgetV1)
    b.budget_hash == canonical_hash(_budget_body(b)) ||
        throw(ArgumentError("budget authority hash mismatch"))
    all(x -> x >= 0, values(_budget_body(b))) ||
        throw(ArgumentError("budget authority contains negative cap"))
    (b.max_provider_steps, b.max_solver_steps, b.max_mesh_steps,
        b.max_physical_steps) == (0, 0, 0, 0) ||
        throw(ArgumentError("budget authority enables unsupported execution"))
    true
end

function _budget_equal(a::StructureSearchBudgetV1, b::StructureSearchBudgetV1)
    _validate_budget_authority(a)
    _validate_budget_authority(b)
    a.budget_hash == b.budget_hash && _budget_body(a) == _budget_body(b)
end

function _counter_namedtuple(pairs)
    d = Dict{Symbol,Int}(Symbol(k) => Int(v) for (k, v) in pairs)
    all(haskey(d, key) for key in _LEDGER_COUNTER_KEYS) ||
        throw(ArgumentError("ledger counter axis is missing"))
    NamedTuple{_LEDGER_COUNTER_KEYS}(Tuple(d[key] for key in _LEDGER_COUNTER_KEYS))
end

"""Immutable typed snapshot used as the receipt's ledger authority.

The mutable builder ledger is never used as replay input after this snapshot
is made.  Replay therefore rebuilds semantic bytes from typed events/counters
owned by the receipt rather than trusting byte fields supplied by a caller.
"""
struct StructureLedgerSnapshotV1
    events::Tuple{Vararg{BudgetEventV1}}
    counter_pairs::Tuple{Vararg{Tuple{Symbol,Int}}}
    snapshot_hash::Digest256V1
    function StructureLedgerSnapshotV1(events, counter_pairs)
        evs = Tuple(events)
        pairs = Tuple((Symbol(k), Int(v)) for (k, v) in counter_pairs)
        length(unique(first(x) for x in pairs)) == length(pairs) ||
            throw(ArgumentError("ledger snapshot counter keys must be unique"))
        pairs == Tuple(sort(collect(pairs), by=x -> String(first(x)))) ||
            throw(ArgumentError("ledger snapshot counter keys are not canonical"))
        _counter_namedtuple(pairs)
        all(event.event_hash == canonical_hash(_budget_event_semantic_body(event))
            for event in evs) ||
            throw(ArgumentError("ledger snapshot event semantic hash mismatch"))
        body = (events=Tuple(_budget_event_semantic_body(event) for event in evs),
            counters=pairs)
        new(evs, pairs, canonical_hash(body))
    end
end

function _ledger_snapshot(ledger::BudgetLedgerV1)
    _ledger_semantic_body(ledger)
    StructureLedgerSnapshotV1(ledger.events,
        ((key, ledger.counters[key]) for key in sort(collect(keys(ledger.counters)), by=String)))
end

_ledger_semantic_body(snapshot::StructureLedgerSnapshotV1) =
    (events=Tuple(_budget_event_semantic_body(event) for event in snapshot.events),
     counters=snapshot.counter_pairs)
function record_event!(ledger::BudgetLedgerV1, event::BudgetEventV1)
    push!(ledger.events, event)
    ledger.counters[event.stage] = event.after
    ledger
end

struct StructureReplayReceiptV1
    source_hash::Digest256V1
    target_hash::Digest256V1
    action_hash::Digest256V1
    condition_hash::Digest256V1
    sequence::Int
    receipt_hash::Digest256V1
    function StructureReplayReceiptV1(source_hash, target_hash, action_hash,
                                      condition_hash, sequence)
        body = (source_hash=source_hash, target_hash=target_hash,
            action_hash=action_hash, condition_hash=condition_hash, sequence=sequence)
        new(source_hash, target_hash, action_hash, condition_hash, Int(sequence),
            canonical_hash(body))
    end
end

struct StructureActionResultV1
    merged::Bool
    status::Symbol
    child::Union{Nothing,StructurePrefixV1}
    receipt::Union{Nothing,StructureReplayReceiptV1}
    result_hash::Digest256V1
end

function _action_result(merged, status, child, receipt)
    status === :replayed && (merged && child !== nothing && receipt !== nothing) ||
        status !== :replayed && (!merged && receipt === nothing) ||
        throw(ArgumentError("action result merge/receipt invariant violated"))
    StructureActionResultV1(merged, status, child, receipt,
        canonical_hash((merged=merged, status=status,
            child_hash=child === nothing ? nothing : child.prefix_hash,
            receipt_hash=receipt === nothing ? nothing : receipt.receipt_hash)))
end

function apply_action(parent::StructurePrefixV1, action::StructureActionV1,
                      closure::SearchInputClosureV1; sequence=1,
                      expected_candidate_generation,
                      expected_source_generation,
                      expected_token_generation,
                      expected_freshness_hash)
    closure_state, closure_status, _ = validate_closure(closure;
        expected_candidate_generation=expected_candidate_generation,
        expected_source_generation=expected_source_generation,
        expected_freshness_hash=expected_freshness_hash)
    closure_state === :ready ||
        return _action_result(false,
            closure_status === :terminal_deferred ? :terminal_deferred : :fail_closed,
            nothing, nothing)
    action.parent_prefix_hash == parent.prefix_hash &&
        parent.candidate_ref == closure.candidate_ref &&
        parent.closure_hash == closure.closure_hash ||
        return _action_result(false, :fail_closed, nothing, nothing)
    expected_token_generation isa Integer && expected_token_generation >= 1 ||
        throw(ArgumentError("expected_token_generation is required and positive"))
    action.token_generation != UInt64(expected_token_generation) &&
        return _action_result(false, :fail_closed, nothing, nothing)
    action.source_generation == closure.source_generation ||
        return _action_result(false, :fail_closed, nothing, nothing)
    if action.condition_status === :conditions_met
        child = StructurePrefixV1(parent.candidate_ref, parent.closure_hash,
            parent.prefix_hash, (parent.action_refs..., action.action_ref),
            (parent.node_payload..., action.node_payload))
        receipt = StructureReplayReceiptV1(parent.prefix_hash, child.prefix_hash,
            digest_text(action.action_ref), action.condition_hash, sequence)
        return _action_result(true, :replayed, child, receipt)
    elseif action.condition_status === :condition_unmet
        return _action_result(false, :not_applicable, nothing, nothing)
    elseif action.condition_status in (:equality_unknown, :terminal_deferred)
        return _action_result(false, :terminal_deferred, nothing, nothing)
    end
    _action_result(false, :fail_closed, nothing, nothing)
end

struct StructureProposalV1
    emitter::Symbol
    seed::Int
    sequence::Int
    candidate_ref::String
    parent_prefix_hash::Digest256V1
    prefix_hash::Digest256V1
    action_hash::Digest256V1
    closure_hash::Digest256V1
    proposal_hash::Digest256V1
    function StructureProposalV1(emitter, seed, sequence, candidate_ref,
                                 parent_prefix_hash, prefix_hash, action_hash,
                                 closure_hash)
        emitter in (:grammar, :qd, :mcts) || throw(ArgumentError("invalid emitter"))
        body = (emitter=emitter, seed=seed, sequence=sequence,
            candidate_ref=String(candidate_ref), parent_prefix_hash=parent_prefix_hash,
            prefix_hash=prefix_hash, action_hash=action_hash, closure_hash=closure_hash)
        new(emitter, Int(seed), Int(sequence), String(candidate_ref), parent_prefix_hash,
            prefix_hash, action_hash, closure_hash, canonical_hash(body))
    end
end

struct StructureDescriptorV1
    prefix_byte_mod_16::Int
    typed_node_count_mod_16::Int
    ledger_prefix_count::Int
    descriptor_hash::Digest256V1
    function StructureDescriptorV1(prefix_byte_mod_16, typed_node_count_mod_16,
                                   ledger_prefix_count)
        vals = (prefix_byte_mod_16, typed_node_count_mod_16, ledger_prefix_count)
        all(x -> x >= 0, vals) || throw(ArgumentError("negative descriptor axis"))
        body = (prefix_byte_mod_16=prefix_byte_mod_16,
            typed_node_count_mod_16=typed_node_count_mod_16,
            ledger_prefix_count=ledger_prefix_count)
        new(Int.(vals)..., canonical_hash(body))
    end
end
function descriptor(prefix::StructurePrefixV1, ledger::BudgetLedgerV1)
    bytes = canonical_bytes(_prefix_semantic_body(prefix))
    StructureDescriptorV1(mod(sum(Int, bytes), 16), mod(length(prefix.node_payload), 16),
        get(ledger.counters, :prefixes, 0))
end

_prefix_semantic_body(x::StructurePrefixV1) =
    (candidate_ref=x.candidate_ref, closure_hash=x.closure_hash,
     parent_prefix_hash=x.parent_prefix_hash, action_refs=x.action_refs,
     node_payload=x.node_payload)
_proposal_semantic_body(x::StructureProposalV1) =
    (emitter=x.emitter, seed=x.seed, sequence=x.sequence,
     candidate_ref=x.candidate_ref, parent_prefix_hash=x.parent_prefix_hash,
     prefix_hash=x.prefix_hash, action_hash=x.action_hash,
     closure_hash=x.closure_hash)
_descriptor_semantic_body(x::StructureDescriptorV1) =
    (prefix_byte_mod_16=x.prefix_byte_mod_16,
     typed_node_count_mod_16=x.typed_node_count_mod_16,
     ledger_prefix_count=x.ledger_prefix_count)
_semantic_bytes(x) = canonical_bytes(x)
_semantic_digest(bytes::Vector{UInt8}) =
    Digest256V1(bytes2hex(SHA.sha256(bytes)))
const _RECEIPT_STATUSES = (:screen_only, :terminal_deferred, :fail_closed, :not_executed)
_valid_receipt_status(status::Symbol) = status in _RECEIPT_STATUSES
_budget_event_semantic_body(x::BudgetEventV1) =
    (stage=x.stage, seed=x.seed, sequence=x.sequence, before=x.before,
     after=x.after, limit=x.limit, remaining=x.remaining, status=x.status)
function _ledger_semantic_body(ledger::BudgetLedgerV1)
    all(event.event_hash == canonical_hash(_budget_event_semantic_body(event))
        for event in ledger.events) ||
        throw(ArgumentError("budget event semantic hash mismatch"))
    counter_pairs = Tuple((key, ledger.counters[key]) for key in
        sort(collect(keys(ledger.counters)), by=String))
    events = Tuple(_budget_event_semantic_body(event) for event in ledger.events)
    (events=events, counters=counter_pairs)
end
_ledger_semantic_bytes(ledger::BudgetLedgerV1) =
    _semantic_bytes(_ledger_semantic_body(ledger))

struct StructureContentReceiptV1
    closure_hash::Digest256V1
    root_hash::Digest256V1
    prefix_hashes::Tuple{Vararg{Digest256V1}}
    proposal_hashes::Tuple{Vararg{Digest256V1}}
    descriptor_hashes::Tuple{Vararg{Digest256V1}}
    prefix_semantic_bytes::Tuple{Vararg{Vector{UInt8}}}
    proposal_semantic_bytes::Tuple{Vararg{Vector{UInt8}}}
    descriptor_semantic_bytes::Tuple{Vararg{Vector{UInt8}}}
    ledger_semantic_bytes::Vector{UInt8}
    counters::NamedTuple
    status::Symbol
    content_hash::Digest256V1
    closure::SearchInputClosureV1
    prefix_lineage::Tuple{Vararg{StructurePrefixV1}}
    proposal_lineage::Tuple{Vararg{StructureProposalV1}}
    descriptor_lineage::Tuple{Vararg{StructureDescriptorV1}}
    ledger_snapshot::StructureLedgerSnapshotV1
    budget::StructureSearchBudgetV1
end

function _content_receipt_body(receipt::StructureContentReceiptV1)
    (closure_hash=receipt.closure_hash, root_hash=receipt.root_hash,
        prefix_hashes=receipt.prefix_hashes,
        proposal_hashes=receipt.proposal_hashes,
        descriptor_hashes=receipt.descriptor_hashes,
        prefix_semantic_bytes=receipt.prefix_semantic_bytes,
        proposal_semantic_bytes=receipt.proposal_semantic_bytes,
        descriptor_semantic_bytes=receipt.descriptor_semantic_bytes,
        ledger_semantic_bytes=receipt.ledger_semantic_bytes,
        budget_hash=receipt.budget.budget_hash,
        budget_caps=_budget_body(receipt.budget),
        counters=receipt.counters, status=receipt.status)
end

function _recomputed_content_hash(receipt::StructureContentReceiptV1)
    canonical_hash(_content_receipt_body(receipt))
end

function _recomputed_content_hash(receipt::StructureContentReceiptV1,
                                  prefix_hashes, proposal_hashes,
                                  descriptor_hashes, prefix_bytes,
                                  proposal_bytes, descriptor_bytes,
                                  ledger_bytes; budget=receipt.budget,
                                  counters=receipt.counters, status=receipt.status)
    canonical_hash((closure_hash=receipt.closure_hash, root_hash=receipt.root_hash,
        prefix_hashes=prefix_hashes, proposal_hashes=proposal_hashes,
        descriptor_hashes=descriptor_hashes,
        prefix_semantic_bytes=prefix_bytes,
        proposal_semantic_bytes=proposal_bytes,
        descriptor_semantic_bytes=descriptor_bytes,
        ledger_semantic_bytes=ledger_bytes, budget_hash=budget.budget_hash,
        budget_caps=_budget_body(budget), counters=counters, status=status))
end

"""Check the typed lineage and ledger join before any receipt bytes are made."""
function _budget_cap(budget::StructureSearchBudgetV1, stage::Symbol)
    stage === :rewrites && return budget.max_rewrites_per_seed
    stage === :prefixes && return budget.max_prefixes
    stage === :proposal_receipts && return budget.max_proposal_receipts
    stage === :provider_steps && return budget.max_provider_steps
    stage === :solver_steps && return budget.max_solver_steps
    stage === :mesh_steps && return budget.max_mesh_steps
    stage === :physical_steps && return budget.max_physical_steps
    nothing
end

function _validate_budget_ledger(ledger::BudgetLedgerV1,
                                 budget::StructureSearchBudgetV1,
                                 proposal_count::Int, prefix_count::Int,
                                 proposal_values::Tuple,
                                 result_counters::NamedTuple)
    _validate_budget_authority(budget)
    counters = _counter_namedtuple(((key, ledger.counters[key])
        for key in _LEDGER_COUNTER_KEYS))
    expected_zero = (:eclasses, :enodes, :trace_rows, :global_trace_rows,
        :screen_evaluations, :qd_proposals, :mcts_proposals, :provider_steps,
        :solver_steps, :mesh_steps, :physical_steps)
    all(getproperty(counters, key) == 0 for key in expected_zero) ||
        throw(ArgumentError("unsupported ledger counter is nonzero"))
    counters.prefixes == prefix_count ||
        throw(ArgumentError("ledger prefixes counter does not join lineage"))
    counters.rewrites == proposal_count ||
        throw(ArgumentError("ledger rewrites counter does not join proposals"))
    counters.proposal_receipts == proposal_count ||
        throw(ArgumentError("ledger proposal counter does not join lineage"))
    counters == result_counters ||
        throw(ArgumentError("ledger counters do not exactly join result counters"))
    length(proposal_values) == proposal_count ||
        throw(ArgumentError("proposal values do not join proposal lineage"))
    proposal_seeds = Tuple(proposal.seed for proposal in proposal_values)
    length(unique(proposal_seeds)) <= budget.max_seeds ||
        throw(ArgumentError("distinct proposal seeds exceed budget max_seeds"))
    events = ledger.events
    length(events) == 3 * proposal_count ||
        throw(ArgumentError("ledger event count does not join proposal lineage"))
    all(event.event_hash == canonical_hash(_budget_event_semantic_body(event))
        for event in events) ||
        throw(ArgumentError("budget event hash mismatch during replay"))
    for i in 1:proposal_count
        rewrite_event = events[3 * i - 2]
        prefix_event = events[3 * i - 1]
        proposal_event = events[3 * i]
        rewrite_event.stage === :rewrites && rewrite_event.sequence == i &&
            rewrite_event.before == i - 1 && rewrite_event.after == i &&
            rewrite_event.status === :progress ||
            throw(ArgumentError("rewrite budget event progression mismatch"))
        prefix_event.stage === :prefixes && prefix_event.sequence == i &&
            prefix_event.before == i && prefix_event.after == i + 1 ||
            throw(ArgumentError("prefix budget event progression mismatch"))
        proposal_event.stage === :proposal_receipts &&
            proposal_event.sequence == i && proposal_event.before == i - 1 &&
            proposal_event.after == i ||
            throw(ArgumentError("proposal budget event progression mismatch"))
        rewrite_event.seed == proposal_event.seed &&
            prefix_event.seed == proposal_event.seed &&
            prefix_event.seed in FROZEN_SEEDS ||
            throw(ArgumentError("budget event seed is not frozen"))
        rewrite_event.limit == budget.max_rewrites_per_seed ||
            throw(ArgumentError("rewrite event limit does not match budget authority"))
        prefix_event.limit == budget.max_prefixes ||
            throw(ArgumentError("prefix event limit does not match budget authority"))
        proposal_event.limit == budget.max_proposal_receipts ||
            throw(ArgumentError("proposal event limit does not match budget authority"))
    end
    true
end

function _validate_typed_lineage(closure::SearchInputClosureV1,
                                 root::StructurePrefixV1,
                                 prefix_values::Tuple,
                                 proposal_values::Tuple,
                                 descriptor_values::Tuple,
                                 ledger::BudgetLedgerV1,
                                 budget::StructureSearchBudgetV1,
                                 result_counters::NamedTuple)
    !isempty(prefix_values) && first(prefix_values).prefix_hash == root.prefix_hash ||
        throw(ArgumentError("root is not the first lineage prefix"))
    length(prefix_values) == length(proposal_values) + 1 ||
        throw(ArgumentError("prefix/proposal lineage length mismatch"))
    length(descriptor_values) == length(proposal_values) ||
        throw(ArgumentError("descriptor/proposal lineage count mismatch"))
    all(x.candidate_ref == closure.candidate_ref &&
        x.closure_hash == closure.closure_hash for x in prefix_values) ||
        throw(ArgumentError("prefix is not bound to the closure"))
    all(i == 1 || (prefix_values[i].parent_prefix_hash !== nothing &&
        prefix_values[i].parent_prefix_hash in
            Tuple(x.prefix_hash for x in prefix_values[1:i-1]))
        for i in eachindex(prefix_values)) ||
        throw(ArgumentError("prefix parent is not bound to an earlier lineage node"))
    length(unique(x.prefix_hash for x in prefix_values)) == length(prefix_values) ||
        throw(ArgumentError("prefix hashes are not unique"))
    prefix_index = Dict{Digest256V1,Int}(x.prefix_hash => i
        for (i, x) in enumerate(prefix_values))
    first(prefix_values).parent_prefix_hash === nothing ||
        throw(ArgumentError("lineage root has a parent"))
    events = ledger.events
    length(events) == 3 * length(proposal_values) ||
        throw(ArgumentError("ledger event/proposal count mismatch"))
    for (i, proposal) in enumerate(proposal_values)
        proposal.emitter === :grammar ||
            throw(ArgumentError("unsupported proposal emitter for this slice"))
        proposal.seed in FROZEN_SEEDS ||
            throw(ArgumentError("proposal seed is not frozen for this slice"))
        proposal.sequence == i ||
            throw(ArgumentError("proposal sequence is not canonical"))
        haskey(prefix_index, proposal.parent_prefix_hash) &&
            haskey(prefix_index, proposal.prefix_hash) ||
            throw(ArgumentError("proposal edge is not present in lineage"))
        parent_index = prefix_index[proposal.parent_prefix_hash]
        child_index = prefix_index[proposal.prefix_hash]
        child_index == i + 1 && parent_index < child_index ||
            throw(ArgumentError("proposal edge/sequence join mismatch"))
        child = prefix_values[child_index]
        parent = prefix_values[parent_index]
        child.parent_prefix_hash == proposal.parent_prefix_hash &&
            child.candidate_ref == proposal.candidate_ref &&
            child.closure_hash == proposal.closure_hash ||
            throw(ArgumentError("proposal parent-child binding mismatch"))
        !isempty(child.action_refs) &&
            digest_text(last(child.action_refs)) == proposal.action_hash ||
            throw(ArgumentError("proposal action edge mismatch"))
        parent_refs = length(child.action_refs) == 1 ? () :
            child.action_refs[1:end-1]
        parent_refs == parent.action_refs ||
            throw(ArgumentError("prefix action lineage mismatch"))
        parent_payload_length = length(parent.node_payload)
        parent_payload = parent_payload_length == 0 ? () :
            child.node_payload[1:parent_payload_length]
        parent_payload == parent.node_payload ||
            throw(ArgumentError("prefix node lineage mismatch"))
        descriptor_values[i].ledger_prefix_count == i + 1 ||
            throw(ArgumentError("descriptor ledger sequence mismatch"))
        expected_descriptor = StructureDescriptorV1(
            mod(sum(Int, canonical_bytes(_prefix_semantic_body(child))), 16),
            mod(length(child.node_payload), 16), i + 1)
        descriptor_values[i].descriptor_hash == expected_descriptor.descriptor_hash ||
            throw(ArgumentError("descriptor does not match proposal child"))
        event = events[3 * i - 1]
        event.seed in FROZEN_SEEDS &&
            event.stage === :prefixes && event.sequence == i && event.seed == proposal.seed &&
            event.before == i && event.after == i + 1 ||
            throw(ArgumentError("ledger event seed/edge does not match frozen authority"))
    end
    get(ledger.counters, :prefixes, -1) == length(prefix_values) ||
        throw(ArgumentError("ledger prefix counter does not match lineage"))
    _validate_budget_ledger(ledger, budget, length(proposal_values),
        length(prefix_values), proposal_values, result_counters)
    true
end

function _validate_typed_lineage(closure::SearchInputClosureV1,
                                 root::StructurePrefixV1,
                                 prefix_values::Tuple,
                                 proposal_values::Tuple,
                                 descriptor_values::Tuple,
                                 snapshot::StructureLedgerSnapshotV1,
                                 budget::StructureSearchBudgetV1,
                                 result_counters::NamedTuple)
    ledger = BudgetLedgerV1()
    ledger.events = BudgetEventV1[snapshot.events...]
    ledger.counters = Dict{Symbol,Int}(snapshot.counter_pairs)
    _validate_typed_lineage(closure, root, prefix_values, proposal_values,
        descriptor_values, ledger, budget, result_counters)
end

function make_content_receipt(closure, root, prefixes, proposals, descriptors,
                              counters, status; ledger=nothing, budget=nothing)
    status isa Symbol && _valid_receipt_status(status) ||
        throw(ArgumentError("invalid content receipt status"))
    prefix_values = Tuple(prefixes)
    proposal_values = Tuple(proposals)
    descriptor_values = Tuple(descriptors)
    prefix_bytes = Tuple(_semantic_bytes(_prefix_semantic_body(x)) for x in prefix_values)
    proposal_bytes = Tuple(_semantic_bytes(_proposal_semantic_body(x)) for x in proposal_values)
    descriptor_bytes = Tuple(_semantic_bytes(_descriptor_semantic_body(x)) for x in descriptor_values)
    ph = Tuple(_semantic_digest(bytes) for bytes in prefix_bytes)
    qh = Tuple(_semantic_digest(bytes) for bytes in proposal_bytes)
    dh = Tuple(_semantic_digest(bytes) for bytes in descriptor_bytes)
    all(x.prefix_hash == digest for (x, digest) in zip(prefix_values, ph)) ||
        throw(ArgumentError("prefix semantic hash mismatch"))
    all(x.proposal_hash == digest for (x, digest) in zip(proposal_values, qh)) ||
        throw(ArgumentError("proposal semantic hash mismatch"))
    all(x.descriptor_hash == digest for (x, digest) in zip(descriptor_values, dh)) ||
        throw(ArgumentError("descriptor semantic hash mismatch"))
    ledger isa BudgetLedgerV1 ||
        throw(ArgumentError("content receipt requires a real typed budget ledger"))
    budget isa StructureSearchBudgetV1 ||
        throw(ArgumentError("content receipt requires a typed budget authority"))
    _validate_typed_lineage(closure, root, prefix_values, proposal_values,
        descriptor_values, ledger, budget, counters)
    hasproperty(counters, :prefixes) && counters.prefixes == length(prefix_values) ||
        throw(ArgumentError("receipt prefix counter does not match lineage"))
    hasproperty(counters, :proposal_receipts) &&
        counters.proposal_receipts == length(proposal_values) ||
        throw(ArgumentError("receipt proposal counter does not match lineage"))
    ledger_snapshot = _ledger_snapshot(ledger)
    ledger_bytes = _semantic_bytes(_ledger_semantic_body(ledger_snapshot))
    body = (closure_hash=closure.closure_hash, root_hash=root.prefix_hash,
        prefix_hashes=ph, proposal_hashes=qh, descriptor_hashes=dh,
        prefix_semantic_bytes=prefix_bytes, proposal_semantic_bytes=proposal_bytes,
        descriptor_semantic_bytes=descriptor_bytes, ledger_semantic_bytes=ledger_bytes,
        budget_hash=budget.budget_hash, budget_caps=_budget_body(budget),
        counters=counters, status=status)
    StructureContentReceiptV1(closure.closure_hash, root.prefix_hash, ph, qh, dh,
        prefix_bytes, proposal_bytes, descriptor_bytes, ledger_bytes,
        counters, status, canonical_hash(body), closure, prefix_values,
        proposal_values, descriptor_values, ledger_snapshot, budget)
end

struct StructureOperationalEnvelopeV1
    pid::Int
    started_utc::String
    ended_utc::String
    command::String
    raw_refs::Tuple{Vararg{String}}
    operational_hash::Digest256V1
end
function make_operational_envelope(pid, started_utc, ended_utc, command, raw_refs=())
    body = (pid=Int(pid), started_utc=String(started_utc), ended_utc=String(ended_utc),
        command=String(command), raw_refs=Tuple(String(x) for x in raw_refs))
    StructureOperationalEnvelopeV1(body.pid, body.started_utc, body.ended_utc,
        body.command, body.raw_refs, canonical_hash(body))
end

struct StructureFailureV1
    kind::Symbol
    detail::String
    failure_hash::Digest256V1
end
StructureFailureV1(kind, detail) = StructureFailureV1(kind, String(detail),
    canonical_hash((kind=kind, detail=String(detail))))

function _validate_failure_hashes(failures::Tuple{Vararg{StructureFailureV1}})
    all(x.failure_hash == canonical_hash((kind=x.kind, detail=x.detail))
        for x in failures) ||
        throw(ArgumentError("failure hash mismatch"))
    true
end

struct StructureSearchResultV1
    status::Symbol
    claim_ceiling::Symbol
    accepted::Bool
    no_publish::Bool
    closure_hash::Digest256V1
    content_receipt::Union{Nothing,StructureContentReceiptV1}
    operational_envelope::Union{Nothing,StructureOperationalEnvelopeV1}
    failures::Tuple{Vararg{StructureFailureV1}}
    counters::NamedTuple
    result_hash::Digest256V1
    function StructureSearchResultV1(::_BoundedStructureSearchSealV1,
                                    status::Symbol, claim_ceiling::Symbol,
                                    accepted::Bool, no_publish::Bool,
                                    closure_hash::Digest256V1,
                                    content_receipt::Union{Nothing,StructureContentReceiptV1},
                                    operational_envelope::Union{Nothing,StructureOperationalEnvelopeV1},
                                    failures::Tuple{Vararg{StructureFailureV1}},
                                    counters::NamedTuple, result_hash::Digest256V1)
        status in (:screen_only, :terminal_deferred, :fail_closed, :not_executed) ||
            throw(ArgumentError("invalid structure search result status"))
        claim_ceiling === :screen_only && !accepted && no_publish ||
            throw(ArgumentError("result must remain screen_only, unaccepted, and no_publish"))
        _zero_execution_counters(counters) ||
            throw(ArgumentError("provider/solver/mesh/physical/QD/MCTS counters must be zero"))
        new(status, claim_ceiling, accepted, no_publish, closure_hash,
            content_receipt, operational_envelope, failures, counters, result_hash)
    end
end

StructureSearchResultV1(args...) =
    throw(ArgumentError("StructureSearchResultV1 is sealed; use internal result factory"))

function _zero_execution_counters(counters::NamedTuple)
    required = (:qd_proposals, :mcts_proposals, :provider_steps, :solver_steps,
                :mesh_steps, :physical_steps)
    all(hasproperty(counters, field) && getproperty(counters, field) == 0
        for field in required)
end

function _new_result(status::Symbol, claim_ceiling::Symbol, accepted::Bool,
                     no_publish::Bool, closure_hash::Digest256V1,
                     content_receipt::Union{Nothing,StructureContentReceiptV1},
                     operational_envelope::Union{Nothing,StructureOperationalEnvelopeV1},
                     failures::Tuple{Vararg{StructureFailureV1}}, counters::NamedTuple,
                     result_hash::Digest256V1)
    invoke(StructureSearchResultV1,
        Tuple{_BoundedStructureSearchSealV1,Symbol,Symbol,Bool,Bool,Digest256V1,
              Union{Nothing,StructureContentReceiptV1},
              Union{Nothing,StructureOperationalEnvelopeV1},
              Tuple{Vararg{StructureFailureV1}},NamedTuple,Digest256V1},
        _BSS_SEAL_V1, status, claim_ceiling, accepted, no_publish, closure_hash,
        content_receipt, operational_envelope, failures, counters, result_hash)
end

function _result(status, closure_hash; receipt=nothing, operational=nothing,
                 failures=(), counters=(eclasses=0, enodes=0, rewrites=0,
                 trace_rows=0, global_trace_rows=0, prefixes=0,
                 screen_evaluations=0, proposal_receipts=0, qd_proposals=0,
                 mcts_proposals=0, provider_steps=0, solver_steps=0,
                 mesh_steps=0, physical_steps=0))
    body = (status=status, claim_ceiling=:screen_only, accepted=false, no_publish=true,
        closure_hash=closure_hash, content_hash=receipt === nothing ? nothing : receipt.content_hash,
        failures=Tuple(x.failure_hash for x in failures), counters=counters)
    _new_result(status, :screen_only, false, true, closure_hash, receipt,
        operational, Tuple(failures), counters, canonical_hash(body))
end

function prepare_search(closure::SearchInputClosureV1; budget=DEFAULT_BUDGET)
    state, status, detail = validate_closure(closure)
    state === :ready || return _result(status, closure.closure_hash;
        failures=(StructureFailureV1(status, detail),))
    _result(:screen_only, closure.closure_hash)
end

function _action_sort_key(action::StructureActionV1)
    _canon((parent_prefix_hash=action.parent_prefix_hash,
        action_ref=action.action_ref, node_payload=action.node_payload,
        condition_status=action.condition_status,
        condition_hash=action.condition_hash,
        token_generation=action.token_generation,
        source_generation=action.source_generation))
end

function _budget_precheck(closure::SearchInputClosureV1,
                          actions::Vector{StructureActionV1},
                          budget::StructureSearchBudgetV1, seed::Int)
    seed in FROZEN_SEEDS ||
        return (:fail_closed, :invalid_seed)
    budget.max_prefixes >= 1 ||
        return (:terminal_deferred, :prefix_budget_exhausted)
    # A root-only receipt consumes no proposal seed.  Preserve that valid
    # zero-proposal case even when the seed cap is explicitly zero; any
    # non-empty action list still requires at least one allowed seed.
    isempty(actions) && budget.max_seeds == 0 && return (:ready, :none)
    budget.max_seeds >= 1 ||
        return (:terminal_deferred, :seed_budget_exhausted)
    length(actions) <= budget.max_rewrites_per_seed ||
        return (:terminal_deferred, :rewrite_budget_exhausted)
    (:ready, :none)
end

function build_prefix_dag(closure::SearchInputClosureV1, actions;
                          budget=DEFAULT_BUDGET, seed=FROZEN_SEEDS[1],
                          expected_candidate_generation,
                          expected_source_generation,
                          expected_token_generation,
                          expected_freshness_hash)
    state, status, detail = validate_closure(closure;
        expected_candidate_generation=expected_candidate_generation,
        expected_source_generation=expected_source_generation,
        expected_freshness_hash=expected_freshness_hash)
    state === :ready || return _result(status, closure.closure_hash;
        failures=(StructureFailureV1(status, detail),))
    expected_token_generation isa Integer && expected_token_generation >= 1 ||
        throw(ArgumentError("expected_token_generation is required and positive"))
    UInt64(expected_token_generation) == closure.source_generation ||
        return _result(:fail_closed, closure.closure_hash;
            failures=(StructureFailureV1(:fail_closed, "token/source generation mismatch"),))
    raw_actions = collect(actions)
    all(action -> action isa StructureActionV1, raw_actions) ||
        return _result(:fail_closed, closure.closure_hash;
            failures=(StructureFailureV1(:fail_closed, "invalid action type"),))
    ordered_actions = sort(StructureActionV1[raw_actions...], by=_action_sort_key)
    budget_state, budget_detail = _budget_precheck(closure, ordered_actions, budget, Int(seed))
    budget_state === :ready || return _result(budget_state, closure.closure_hash;
        failures=(StructureFailureV1(:saturation_incomplete, budget_detail),))
    root = make_root_prefix(closure)
    ledger = BudgetLedgerV1()
    ledger.counters[:prefixes] = 1
    prefixes = StructurePrefixV1[root]
    prefix_by_hash = Dict{Digest256V1,StructurePrefixV1}(root.prefix_hash => root)
    proposals = StructureProposalV1[]
    descriptors = StructureDescriptorV1[]
    failures = StructureFailureV1[]
    exhausted = false
    pending = ordered_actions
    attempt_sequence = 0
    proposal_sequence = 0
    while !isempty(pending)
        ready_indices = findall(action -> haskey(prefix_by_hash, action.parent_prefix_hash), pending)
        if isempty(ready_indices)
            append!(failures, (StructureFailureV1(:fail_closed,
                "unresolved parent prefix") for _ in pending))
            break
        end
        ready_set = Set(ready_indices)
        next_pending = StructureActionV1[]
        for (index, action) in enumerate(pending)
            if !(index in ready_set)
                push!(next_pending, action)
                continue
            end
            attempt_sequence += 1
            parent = prefix_by_hash[action.parent_prefix_hash]
            result = apply_action(parent, action, closure; sequence=attempt_sequence,
                expected_candidate_generation=expected_candidate_generation,
                expected_source_generation=expected_source_generation,
                expected_token_generation=expected_token_generation,
                expected_freshness_hash=expected_freshness_hash)
        if result.status === :replayed
            proposal_sequence += 1
            before = length(prefixes)
            if before + 1 > budget.max_prefixes
                exhausted = true
                break
            end
            if length(proposals) + 1 > budget.max_proposal_receipts
                exhausted = true
                break
            end
            rewrite_before = ledger.counters[:rewrites]
            record_event!(ledger, budget_event(:rewrites, seed, proposal_sequence,
                rewrite_before, rewrite_before + 1,
                budget.max_rewrites_per_seed))
            push!(prefixes, result.child)
            prefix_by_hash[result.child.prefix_hash] = result.child
            record_event!(ledger, budget_event(:prefixes, seed, proposal_sequence, before,
                before + 1, budget.max_prefixes))
            proposal_before = length(proposals)
            push!(proposals, StructureProposalV1(:grammar, seed, proposal_sequence,
                closure.candidate_ref, parent.prefix_hash, result.child.prefix_hash,
                digest_text(action.action_ref), closure.closure_hash))
            record_event!(ledger, budget_event(:proposal_receipts, seed,
                proposal_sequence, proposal_before, proposal_before + 1,
                budget.max_proposal_receipts))
            push!(descriptors, descriptor(result.child, ledger))
        elseif result.status === :terminal_deferred
            push!(failures, StructureFailureV1(:terminal_deferred, "condition unknown"))
        elseif result.status === :fail_closed
            push!(failures, StructureFailureV1(:fail_closed, "binding or condition mismatch"))
        end
        end
        pending = next_pending
        exhausted && break
    end
    exhausted && push!(failures, StructureFailureV1(:saturation_incomplete,
        "prefix or proposal receipt budget exhausted"))
    counters = _counter_namedtuple(((key, ledger.counters[key])
        for key in _LEDGER_COUNTER_KEYS))
    status = isempty(failures) ? :screen_only :
        (any(x.kind === :fail_closed for x in failures) ? :fail_closed : :terminal_deferred)
    receipt = make_content_receipt(closure, root, prefixes, proposals, descriptors,
        counters, status; ledger=ledger, budget=budget)
    _result(status, closure.closure_hash; receipt=receipt, failures=failures,
        counters=counters)
end

function replay_content_hash(result::StructureSearchResultV1;
                             expected_budget=DEFAULT_BUDGET)
    _validate_failure_hashes(result.failures)
    result.content_receipt === nothing && return nothing
    receipt = result.content_receipt
    _valid_receipt_status(receipt.status) ||
        throw(ArgumentError("invalid content receipt status during replay"))
    closure_state, closure_status, closure_detail = validate_closure(receipt.closure;
        expected_candidate_generation=receipt.closure.candidate_generation,
        expected_source_generation=receipt.closure.source_generation,
        expected_freshness_hash=receipt.closure.freshness_hash)
    closure_state === :ready ||
        throw(ArgumentError("typed receipt closure validation failed: $(closure_status)/$(closure_detail)"))
    receipt.closure.closure_hash == receipt.closure_hash ||
        throw(ArgumentError("typed closure does not match receipt during replay"))
    prefix_values = receipt.prefix_lineage
    proposal_values = receipt.proposal_lineage
    descriptor_values = receipt.descriptor_lineage
    isempty(prefix_values) &&
        throw(ArgumentError("typed prefix lineage is empty during replay"))
    expected_budget isa StructureSearchBudgetV1 ||
        throw(ArgumentError("expected budget authority is required"))
    _budget_equal(receipt.budget, expected_budget) ||
        throw(ArgumentError("receipt budget does not match expected authority"))
    _validate_typed_lineage(receipt.closure, first(prefix_values), prefix_values,
        proposal_values, descriptor_values, receipt.ledger_snapshot,
        expected_budget, receipt.counters)
    prefix_bytes = Tuple(_semantic_bytes(_prefix_semantic_body(x)) for x in prefix_values)
    proposal_bytes = Tuple(_semantic_bytes(_proposal_semantic_body(x)) for x in proposal_values)
    descriptor_bytes = Tuple(_semantic_bytes(_descriptor_semantic_body(x)) for x in descriptor_values)
    ledger_bytes = _semantic_bytes(_ledger_semantic_body(receipt.ledger_snapshot))
    prefix_hashes = Tuple(_semantic_digest(bytes) for bytes in prefix_bytes)
    proposal_hashes = Tuple(_semantic_digest(bytes) for bytes in proposal_bytes)
    descriptor_hashes = Tuple(_semantic_digest(bytes) for bytes in descriptor_bytes)
    receipt.prefix_hashes == prefix_hashes ||
        throw(ArgumentError("prefix hashes disagree with typed lineage during replay"))
    receipt.proposal_hashes == proposal_hashes ||
        throw(ArgumentError("proposal hashes disagree with typed lineage during replay"))
    receipt.descriptor_hashes == descriptor_hashes ||
        throw(ArgumentError("descriptor hashes disagree with typed lineage during replay"))
    receipt.prefix_semantic_bytes == prefix_bytes ||
        throw(ArgumentError("prefix semantic bytes disagree with typed lineage during replay"))
    receipt.proposal_semantic_bytes == proposal_bytes ||
        throw(ArgumentError("proposal semantic bytes disagree with typed lineage during replay"))
    receipt.descriptor_semantic_bytes == descriptor_bytes ||
        throw(ArgumentError("descriptor semantic bytes disagree with typed lineage during replay"))
    receipt.ledger_semantic_bytes == ledger_bytes ||
        throw(ArgumentError("ledger semantic bytes disagree with typed ledger during replay"))
    receipt.root_hash == first(prefix_hashes) ||
        throw(ArgumentError("root hash disagrees with typed lineage during replay"))
    recomputed = _recomputed_content_hash(receipt, prefix_hashes, proposal_hashes,
        descriptor_hashes, prefix_bytes, proposal_bytes, descriptor_bytes,
        ledger_bytes)
    recomputed == receipt.content_hash ||
        throw(ArgumentError("content receipt hash mismatch during replay"))
    recomputed
end

function validate_result(result::StructureSearchResultV1;
                         expected_budget=DEFAULT_BUDGET)
    _validate_failure_hashes(result.failures)
    result.claim_ceiling === :screen_only && !result.accepted && result.no_publish ||
        throw(ArgumentError("result claim ceiling invariant violated"))
    _zero_execution_counters(result.counters) ||
        throw(ArgumentError("result contains nonzero prohibited execution counters"))
    if result.content_receipt !== nothing
        result.content_receipt.closure_hash == result.closure_hash ||
            throw(ArgumentError("content receipt closure hash mismatch"))
        result.content_receipt.status == result.status ||
            throw(ArgumentError("content receipt status mismatch"))
        result.content_receipt.counters == result.counters ||
            throw(ArgumentError("content receipt counters mismatch"))
        replay_content_hash(result; expected_budget=expected_budget) !== nothing ||
            throw(ArgumentError("content receipt replay unavailable"))
    end
    result.result_hash == canonical_hash((status=result.status, claim_ceiling=:screen_only,
        accepted=false, no_publish=true, closure_hash=result.closure_hash,
        content_hash=result.content_receipt === nothing ? nothing : result.content_receipt.content_hash,
        failures=Tuple(x.failure_hash for x in result.failures), counters=result.counters)) ||
        throw(ArgumentError("result hash mismatch"))
    true
end

end # module BoundedStructureSearchV1
