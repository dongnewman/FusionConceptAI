"""Deterministic, resumable candidate queue for the RuntimeV4 spine.

Queue metadata is deliberately separate from compiled physical identity:
proposal predictions, parent references, display identity and scheduling
priority never enter a candidate/prefix/solver hash.
"""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI

const _QUEUE_STATUSES = (:queued, :active, :failed, :deferred, :dormant, :revived)

function _queue_strings(xs, field::AbstractString)
    ys = Tuple(String(x) for x in xs)
    all(!isempty, ys) || throw(ArgumentError("$field cannot contain empty references"))
    length(unique(ys)) == length(ys) || throw(ArgumentError("$field contains duplicate references"))
    ys
end

struct CandidateQueueEntryV4
    candidate::CandidateStatePackageV4
    compiled::CompiledCandidatePrefixV4
    registry_hash::Digest256
    candidate_ref::Digest256
    parent_refs::Tuple{Vararg{String}}
    proposal_refs::Tuple{Vararg{String}}
    priority::Int
    status::Symbol
    function CandidateQueueEntryV4(candidate::CandidateStatePackageV4, compiled::CompiledCandidatePrefixV4,
                                   registry_hash, parent_refs=(), proposal_refs=(), priority::Integer=0,
                                   status::Symbol=:queued)
        status in _QUEUE_STATUSES || throw(ArgumentError("invalid candidate queue status"))
        compiled.candidate.canonical_hashes == candidate.canonical_hashes ||
            throw(ArgumentError("compiled candidate does not bind the queue candidate"))
        parents = _queue_strings(parent_refs, "parent_refs")
        proposals = _queue_strings(proposal_refs, "proposal_refs")
        ref = compiled.prefix_hash
        new(candidate, compiled, _runtime_digest(registry_hash), ref, parents, proposals, Int(priority), status)
    end
end

semantic_view(x::CandidateQueueEntryV4) = (compiled_prefix_hash=x.compiled.prefix_hash,
    registry_hash=x.registry_hash, parent_refs=x.parent_refs, proposal_refs=x.proposal_refs,
    priority=x.priority, status=x.status)

mutable struct CandidateQueueV4
    entries::Dict{Digest256,CandidateQueueEntryV4}
    proposals::Dict{String,ProposalEnvelopeV4}
    function CandidateQueueV4()
        new(Dict{Digest256,CandidateQueueEntryV4}(), Dict{String,ProposalEnvelopeV4}())
    end
end

Base.length(q::CandidateQueueV4) = length(q.entries)

function _queue_registry_hash(registry)
    registry isa GenomeContractRegistryV4 || throw(ArgumentError("registry must be GenomeContractRegistryV4"))
    canonical_hash(registry)
end

function _queue_entry_sort_key(e::CandidateQueueEntryV4)
    (-e.priority, string(e.candidate_ref))
end

function enqueue_candidate!(queue::CandidateQueueV4, candidate::CandidateStatePackageV4,
                           registry::GenomeContractRegistryV4; mission_payload=candidate.mission_contract_ref,
                           bounds_payload=nothing, parent_refs=(), proposal_refs=(), priority::Integer=0,
                           compile_kwargs...)
    compiled = compile_candidate(candidate, registry; mission_payload=mission_payload,
                                 bounds_payload=bounds_payload, compile_kwargs...)
    enqueue_candidate!(queue, candidate, compiled; registry_hash=_queue_registry_hash(registry),
                       parent_refs=parent_refs, proposal_refs=proposal_refs, priority=priority)
end

function enqueue_candidate!(queue::CandidateQueueV4, candidate::CandidateStatePackageV4,
                           compiled::CompiledCandidatePrefixV4; registry_hash=canonical_hash(compiled.minimality_scope),
                           parent_refs=(), proposal_refs=(), priority::Integer=0)
    entry = CandidateQueueEntryV4(candidate, compiled, registry_hash, parent_refs, proposal_refs,
        priority, isempty(compiled.unresolved_nonterminals) ? :queued : :deferred)
    existing = get(queue.entries, entry.candidate_ref, nothing)
    if existing !== nothing
        merged_parents = Tuple(sort(unique((existing.parent_refs..., entry.parent_refs...))))
        merged_proposals = Tuple(sort(unique((existing.proposal_refs..., entry.proposal_refs...))))
        merged = CandidateQueueEntryV4(existing.candidate, existing.compiled,
            existing.registry_hash, merged_parents, merged_proposals,
            max(existing.priority, entry.priority), existing.status)
        queue.entries[entry.candidate_ref] = merged
        return merged
    end
    queue.entries[entry.candidate_ref] = entry
    entry
end

function submit_proposal!(queue::CandidateQueueV4, proposal::ProposalEnvelopeV4)
    # Predictions remain in the proposal channel and are never copied into a
    # candidate, evidence, provider manifest or solver input.
    previous = get(queue.proposals, proposal.proposal_id, nothing)
    previous === nothing || previous == proposal || throw(ArgumentError("proposal id is already bound to a different proposal"))
    queue.proposals[proposal.proposal_id] = proposal
    proposal.proposal_id
end

function submit_proposal!(queue::CandidateQueueV4, proposal::ProposalEnvelopeV4,
                          candidate::CandidateStatePackageV4, registry::GenomeContractRegistryV4;
                          mission_payload=candidate.mission_contract_ref, bounds_payload=nothing,
                          priority::Integer=0, compile_kwargs...)
    submit_proposal!(queue, proposal)
    enqueue_candidate!(queue, candidate, registry; mission_payload=mission_payload,
                       bounds_payload=bounds_payload, parent_refs=proposal.parent_refs,
                       proposal_refs=(proposal.proposal_id,), priority=priority, compile_kwargs...)
end

function _queue_replace_status!(queue::CandidateQueueV4, ref::Digest256, status::Symbol)
    status in _QUEUE_STATUSES || throw(ArgumentError("invalid candidate queue status"))
    old = get(queue.entries, ref, nothing)
    old === nothing && throw(KeyError(ref))
    updated = CandidateQueueEntryV4(old.candidate, old.compiled, old.registry_hash,
        old.parent_refs, old.proposal_refs, old.priority, status)
    queue.entries[ref] = updated
    updated
end

mark_failed!(queue::CandidateQueueV4, ref::Digest256) = _queue_replace_status!(queue, ref, :failed)
mark_deferred!(queue::CandidateQueueV4, ref::Digest256) = _queue_replace_status!(queue, ref, :deferred)
mark_dormant!(queue::CandidateQueueV4, ref::Digest256) = _queue_replace_status!(queue, ref, :dormant)
release_candidate!(queue::CandidateQueueV4, ref::Digest256) = _queue_replace_status!(queue, ref, :revived)
revive_candidate!(queue::CandidateQueueV4, ref::Digest256) = release_candidate!(queue, ref)

function next_compilable!(queue::CandidateQueueV4)
    candidates = [e for e in values(queue.entries) if e.status in (:queued, :revived) &&
        e.compiled.compilation_status == :prefix_consistent && isempty(e.compiled.unresolved_nonterminals)]
    isempty(candidates) && return nothing
    chosen = first(sort(candidates, by=_queue_entry_sort_key))
    _queue_replace_status!(queue, chosen.candidate_ref, :active)
end
