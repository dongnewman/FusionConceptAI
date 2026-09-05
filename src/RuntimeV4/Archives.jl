"""Deferred capability archive, exact gap aggregation, and safe checkpoints."""

import FusionConceptAI: semantic_view, canonical_hash
using FusionConceptAI
using SHA
using Serialization

function _archive_stage(stage::Symbol)
    isempty(String(stage)) && throw(ArgumentError("deferred stage cannot be empty"))
    lowercase(String(stage)) in ("*", "any", "wildcard", "all") && throw(ArgumentError("deferred stage cannot be wildcard"))
    stage
end

function _archive_ref(x)
    x isa Digest256 && return string(x)
    x isa AbstractString && return string(Digest256(String(x)))
    throw(ArgumentError("candidate_ref must be a Digest256 or a 64-character digest string"))
end

struct DeferredObligationV4
    candidate_ref::String
    stage::Symbol
    signature::CapabilitySignatureV4
    match_status::MatchStatus
    reason::String
    retry_registry_hash::Digest256
    function DeferredObligationV4(candidate_ref, stage::Symbol, signature::CapabilitySignatureV4,
                                  match_status::MatchStatus, reason::AbstractString, retry_registry_hash)
        _archive_stage(stage)
        match_status == unique_match && throw(ArgumentError("unique match cannot be deferred"))
        r = _runtime_nonempty_text(reason, "deferred reason")
        new(_archive_ref(candidate_ref), stage, signature, match_status, r, _runtime_digest(retry_registry_hash))
    end
end
semantic_view(x::DeferredObligationV4) = (candidate_ref=x.candidate_ref, stage=x.stage,
    signature=x.signature, match_status=x.match_status, reason=x.reason, retry_registry_hash=x.retry_registry_hash)

struct CapabilityGapRecordV4
    signature_hash::Digest256
    signature::CapabilitySignatureV4
    blocked_stage::Symbol
    candidate_refs::Tuple{Vararg{String}}
    count::Int
    required_evidence_level::ClaimCeiling
    function CapabilityGapRecordV4(signature::CapabilitySignatureV4, blocked_stage::Symbol,
                                   candidate_refs, required_evidence_level::ClaimCeiling=signature.evidence_level)
        _archive_stage(blocked_stage)
        refs = Tuple(sort(unique(_archive_ref(x) for x in candidate_refs)))
        isempty(refs) && throw(ArgumentError("capability gap needs at least one candidate"))
        required_evidence_level == signature.evidence_level || throw(ArgumentError("gap evidence level must match signature"))
        new(canonical_hash(signature), signature, blocked_stage, refs, length(refs), required_evidence_level)
    end
end
semantic_view(x::CapabilityGapRecordV4) = (signature_hash=x.signature_hash, signature=x.signature,
    blocked_stage=x.blocked_stage, candidate_refs=x.candidate_refs, count=x.count,
    required_evidence_level=x.required_evidence_level)

mutable struct CapabilityArchiveV4
    deferred::Dict{Tuple{String,Symbol,Digest256},DeferredObligationV4}
    function CapabilityArchiveV4()
        new(Dict{Tuple{String,Symbol,Digest256},DeferredObligationV4}())
    end
end

function defer!(archive::CapabilityArchiveV4, candidate_ref, stage::Symbol,
                signature::CapabilitySignatureV4, match_status::MatchStatus,
                reason::AbstractString, retry_registry_hash)
    record = DeferredObligationV4(candidate_ref, stage, signature, match_status, reason, retry_registry_hash)
    archive.deferred[(record.candidate_ref, record.stage, canonical_hash(signature))] = record
    record
end

function _archive_provider_hash(manifests)
    ps = manifests isa ProviderManifestV4 ? (manifests,) : Tuple(manifests)
    all(p -> p isa ProviderManifestV4, ps) || throw(ArgumentError("provider manifests must be typed"))
    canonical_hash(Tuple(sort([p.manifest_hash for p in ps], by=string)))
end

function requeue_resolved!(archive::CapabilityArchiveV4, queue::CandidateQueueV4, manifests)
    registry_hash = _archive_provider_hash(manifests)
    resolved = Set{String}()
    keys_sorted = sort!(collect(keys(archive.deferred)), by=x -> (x[1], String(x[2]), string(x[3])))
    for key in keys_sorted
        record = archive.deferred[key]
        registry_hash == record.retry_registry_hash && continue
        result = match_provider(record.signature, manifests)
        if result.status == unique_match
            ref = Digest256(record.candidate_ref)
            haskey(queue.entries, ref) || continue
            delete!(archive.deferred, key)
            if !any(record2.candidate_ref == record.candidate_ref for record2 in values(archive.deferred))
                release_candidate!(queue, ref)
                push!(resolved, record.candidate_ref)
            end
        else
            # Keep no-match and ambiguous gaps alive, while recording that
            # this provider registry has already been checked.
        archive.deferred[key] = DeferredObligationV4(record.candidate_ref, record.stage,
                record.signature, result.status, result.reason, registry_hash)
        end
    end
    Tuple(sort!(collect(resolved)))
end

"""Resolve archive records without mutating a queue; callers may enqueue the returned refs."""
function requeue_resolved!(archive::CapabilityArchiveV4, manifests)
    registry_hash = _archive_provider_hash(manifests)
    resolved = Set{String}()
    for key in sort!(collect(keys(archive.deferred)), by=x -> (x[1], String(x[2]), string(x[3])))
        record = archive.deferred[key]
        registry_hash == record.retry_registry_hash && continue
        result = match_provider(record.signature, manifests)
        if result.status == unique_match
            delete!(archive.deferred, key)
            push!(resolved, record.candidate_ref)
        else
            archive.deferred[key] = DeferredObligationV4(record.candidate_ref, record.stage,
                record.signature, result.status, result.reason, registry_hash)
        end
    end
    Tuple(sort!(collect(x for x in resolved if !any(r -> r.candidate_ref == x, values(archive.deferred)))))
end

function gap_report(archive::CapabilityArchiveV4)
    groups = Dict{Tuple{Symbol,Digest256},Vector{DeferredObligationV4}}()
    for record in values(archive.deferred)
        push!(get!(groups, (record.stage, canonical_hash(record.signature)), DeferredObligationV4[]), record)
    end
    out = CapabilityGapRecordV4[]
    for key in sort!(collect(keys(groups)), by=x -> (String(x[1]), string(x[2])))
        records = groups[key]
        ordered = sort(records, by=r -> (String(r.stage), r.candidate_ref, string(r.match_status)))
        refs = unique(r.candidate_ref for r in ordered)
        stage = first(ordered).stage
        push!(out, CapabilityGapRecordV4(first(ordered).signature, stage, refs))
    end
    Tuple(out)
end

struct _RuntimeCheckpointEnvelopeV4
    schema::String
    version::Int
    campaign_hash::Digest256
    provider_registry_hash::Digest256
    checksum::Digest256
    payload_bytes::Vector{UInt8}
end

function _runtime_serialize(x)
    io = IOBuffer(); serialize(io, x); take!(io)
end

function _runtime_checkpoint_payload(queue::CandidateQueueV4, archive::CapabilityArchiveV4)
    entries = Tuple(queue.entries[k] for k in sort!(collect(keys(queue.entries)), by=string))
    proposals = Tuple(queue.proposals[k] for k in sort!(collect(keys(queue.proposals))))
    deferred = Tuple(archive.deferred[k] for k in sort!(collect(keys(archive.deferred)), by=x -> (x[1], String(x[2]), string(x[3]))))
    isempty(entries) && isempty(proposals) && isempty(deferred) && throw(ArgumentError("cannot checkpoint an empty runtime archive"))
    (entries=entries, proposals=proposals, deferred=deferred)
end

"""Write a local internal checkpoint; serialized bytes are not a public input format."""
function checkpoint_runtime(path::AbstractString, queue::CandidateQueueV4, archive::CapabilityArchiveV4;
                            campaign_hash, provider_registry_hash)
    campaign = _runtime_digest(campaign_hash); providers = _runtime_digest(provider_registry_hash)
    payload_bytes = _runtime_serialize(_runtime_checkpoint_payload(queue, archive))
    checksum = Digest256(bytes2hex(SHA.sha256(payload_bytes)))
    envelope = _RuntimeCheckpointEnvelopeV4("fusionconceptai:runtime-v4-checkpoint", 1,
        campaign, providers, checksum, payload_bytes)
    bytes = _runtime_serialize(envelope)
    open(path, "w") do io
        write(io, bytes)
    end
    checksum
end

"""Resume a local checkpoint after outer campaign/provider/checksum validation."""
function resume_runtime(path::AbstractString; campaign_hash, provider_registry_hash)
    bytes = read(path)
    isempty(bytes) && throw(ArgumentError("checkpoint is empty"))
    envelope = try
        deserialize(IOBuffer(bytes))
    catch
        throw(ArgumentError("checkpoint is corrupt or not a RuntimeV4 checkpoint"))
    end
    envelope isa _RuntimeCheckpointEnvelopeV4 || throw(ArgumentError("unknown checkpoint schema"))
    envelope.schema == "fusionconceptai:runtime-v4-checkpoint" && envelope.version == 1 ||
        throw(ArgumentError("unknown checkpoint schema or version"))
    envelope.campaign_hash == _runtime_digest(campaign_hash) || throw(ArgumentError("campaign hash mismatch"))
    envelope.provider_registry_hash == _runtime_digest(provider_registry_hash) || throw(ArgumentError("provider registry hash mismatch"))
    isempty(envelope.payload_bytes) && throw(ArgumentError("checkpoint payload is empty"))
    Digest256(bytes2hex(SHA.sha256(envelope.payload_bytes))) == envelope.checksum ||
        throw(ArgumentError("checkpoint checksum mismatch"))
    payload = try deserialize(IOBuffer(envelope.payload_bytes)) catch; throw(ArgumentError("checkpoint payload is corrupt")) end
    payload isa NamedTuple && all(k in keys(payload) for k in (:entries, :proposals, :deferred)) ||
        throw(ArgumentError("checkpoint payload schema mismatch"))
    entries = Tuple(payload.entries); proposals = Tuple(payload.proposals); deferred = Tuple(payload.deferred)
    all(e -> e isa CandidateQueueEntryV4, entries) || throw(ArgumentError("checkpoint contains an invalid queue record"))
    all(p -> p isa ProposalEnvelopeV4, proposals) || throw(ArgumentError("checkpoint contains an invalid proposal record"))
    all(d -> d isa DeferredObligationV4, deferred) || throw(ArgumentError("checkpoint contains an invalid deferred record"))
    length(unique(e.candidate_ref for e in entries)) == length(entries) || throw(ArgumentError("duplicate queue records"))
    length(unique(p.proposal_id for p in proposals)) == length(proposals) || throw(ArgumentError("duplicate proposal records"))
    length(unique((d.candidate_ref, d.stage, canonical_hash(d.signature)) for d in deferred)) == length(deferred) ||
        throw(ArgumentError("duplicate deferred records"))
    queue = CandidateQueueV4()
    for entry in entries
        entry.candidate_ref == entry.compiled.prefix_hash || throw(ArgumentError("queue candidate reference/hash mismatch"))
        rebuilt = CandidateQueueEntryV4(entry.candidate, entry.compiled, entry.registry_hash,
            entry.parent_refs, entry.proposal_refs, entry.priority, entry.status)
        rebuilt.candidate_ref == entry.candidate_ref || throw(ArgumentError("queue candidate reference mismatch"))
        queue.entries[rebuilt.candidate_ref] = rebuilt
    end
    for proposal in proposals
        queue.proposals[proposal.proposal_id] = proposal
    end
    archive = CapabilityArchiveV4()
    for record in deferred
        rebuilt = DeferredObligationV4(record.candidate_ref, record.stage, record.signature,
            record.match_status, record.reason, record.retry_registry_hash)
        archive.deferred[(rebuilt.candidate_ref, rebuilt.stage, canonical_hash(rebuilt.signature))] = rebuilt
    end
    (queue=queue, archive=archive)
end

checkpoint!(path::AbstractString, queue::CandidateQueueV4, archive::CapabilityArchiveV4; kwargs...) =
    checkpoint_runtime(path, queue, archive; kwargs...)
resume_checkpoint(path::AbstractString; kwargs...) = resume_runtime(path; kwargs...)
