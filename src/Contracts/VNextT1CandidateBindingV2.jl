"""Additive, definition-only V2 candidate-binding contract.

This file is intentionally not included, exported, or registered.  It accepts
only explicit immutable identities; candidate labels and URI parsing never
participate in binding.  A later adapter may read these values from a verified
T1 package, but this slice does not construct the V1 giant-tuple package.
"""

const VNEXT_T1_CANDIDATE_BINDING_V2_DOMAIN =
    "FusionConceptAI/GenomeV5/VNextT1CandidateBindingV2"
const VNEXT_T1_CANDIDATE_BINDING_V2_SCHEMA =
    "GenomeV5/Contracts/VNextT1CandidateBinding"
const VNEXT_T1_CANDIDATE_BINDING_V2_VERSION = "v2"
const VNEXT_T1_CANDIDATE_BINDING_V2_CLAIM_CEILING = :contract_only
const VNEXT_T1_CANDIDATE_BINDING_V2_RECEIPT_DOMAIN =
    "FusionConceptAI/GenomeV5/VNextT1CandidateBindingV2/receipt/v1"

const _VNEXT_T1_BINDING_REASONS_V2 = (
    bound=(:exact_explicit_binding,),
    terminal_deferred=(:missing_observation, :missing_expected_wire,
        :missing_observed_wire),
    fail_closed=(:duplicate_conflict, :foreign_candidate_ref,
        :candidate_digest_mismatch, :source_package_hash_mismatch,
        :wire_hash_mismatch),
)
const _VNEXT_T1_BINDING_WIRE_HASH_REQUIRED_REASONS_V2 = (
    :exact_explicit_binding, :missing_observed_wire, :wire_hash_mismatch)

"""One explicit candidate binding; `wire` may be absent at this boundary."""
struct VNextT1CandidateBindingInputV2
    candidate_ref::QualifiedRefV1
    candidate_digest::Digest256
    source_package_hash::Digest256
    wire::Union{Nothing,VNextT1CanonicalBytesV2}
end

semantic_view(x::VNextT1CandidateBindingInputV2) = (
    candidate_ref=x.candidate_ref,
    candidate_digest=x.candidate_digest,
    source_package_hash=x.source_package_hash,
    wire=x.wire,
)

"""Binding decision.  All results remain unaccepted and contract-only."""
struct VNextT1CandidateBindingReceiptV2
    domain::String
    schema::String
    version::String
    status::Symbol
    reason::Symbol
    candidate_ref::QualifiedRefV1
    candidate_digest::Digest256
    source_package_hash::Digest256
    wire_hash::Union{Nothing,Digest256}
    duplicate_count::Int
    accepted::Bool
    claim_ceiling::Symbol
    receipt_hash::Digest256

    function VNextT1CandidateBindingReceiptV2(domain::String, schema::String,
            version::String, status::Symbol, reason::Symbol,
            candidate_ref::QualifiedRefV1, candidate_digest::Digest256,
            source_package_hash::Digest256, wire_hash::Union{Nothing,Digest256},
            duplicate_count::Int, accepted::Bool, claim_ceiling::Symbol,
            receipt_hash::Digest256)
        status in (:bound, :terminal_deferred, :fail_closed) ||
            throw(ArgumentError("unsupported V2 candidate-binding status"))
        domain == VNEXT_T1_CANDIDATE_BINDING_V2_DOMAIN ||
            throw(ArgumentError("candidate-binding domain mismatch"))
        schema == VNEXT_T1_CANDIDATE_BINDING_V2_SCHEMA ||
            throw(ArgumentError("candidate-binding schema mismatch"))
        version == VNEXT_T1_CANDIDATE_BINDING_V2_VERSION ||
            throw(ArgumentError("candidate-binding version mismatch"))
        reason in getproperty(_VNEXT_T1_BINDING_REASONS_V2, status) ||
            throw(ArgumentError("candidate-binding status/reason mismatch"))
        duplicate_count >= 0 || throw(ArgumentError("duplicate_count must be nonnegative"))
        (reason === :missing_observation) == (duplicate_count == 0) ||
            throw(ArgumentError("missing-observation duplicate_count mismatch"))
        (reason === :duplicate_conflict) == (duplicate_count > 1) ||
            throw(ArgumentError("duplicate conflict count mismatch"))
        reason === :missing_expected_wire && wire_hash !== nothing &&
            throw(ArgumentError("missing expected wire cannot carry wire_hash"))
        reason in _VNEXT_T1_BINDING_WIRE_HASH_REQUIRED_REASONS_V2 &&
            wire_hash === nothing &&
            throw(ArgumentError("wire-dependent binding result requires wire_hash"))
        accepted === false || throw(ArgumentError("candidate-binding receipt cannot be accepted"))
        claim_ceiling === VNEXT_T1_CANDIDATE_BINDING_V2_CLAIM_CEILING ||
            throw(ArgumentError("candidate-binding claim ceiling must remain contract_only"))
        receipt_hash == _vnext_t1_binding_receipt_hash(status, reason,
            candidate_ref, candidate_digest, source_package_hash, wire_hash,
            duplicate_count) || throw(ArgumentError("candidate-binding receipt_hash mismatch"))
        new(domain, schema, version, status, reason, candidate_ref,
            candidate_digest, source_package_hash, wire_hash, duplicate_count,
            accepted, claim_ceiling, receipt_hash)
    end
end

"""Domain-separated receipt hash; never hashes or aliases raw wire bytes."""
function _vnext_t1_binding_receipt_hash(status::Symbol, reason::Symbol,
        candidate_ref::QualifiedRefV1, candidate_digest::Digest256,
        source_package_hash::Digest256, wire_hash::Union{Nothing,Digest256},
        duplicate_count::Int)
    canonical_hash((
        receipt_domain=VNEXT_T1_CANDIDATE_BINDING_V2_RECEIPT_DOMAIN,
        body=_vnext_t1_binding_receipt_body(status, reason, candidate_ref,
            candidate_digest, source_package_hash, wire_hash, duplicate_count),
    ))
end

function _vnext_t1_binding_receipt_body(status::Symbol, reason::Symbol,
        candidate_ref::QualifiedRefV1, candidate_digest::Digest256,
        source_package_hash::Digest256, wire_hash::Union{Nothing,Digest256},
        duplicate_count::Int)
    (
        domain=VNEXT_T1_CANDIDATE_BINDING_V2_DOMAIN,
        schema=VNEXT_T1_CANDIDATE_BINDING_V2_SCHEMA,
        version=VNEXT_T1_CANDIDATE_BINDING_V2_VERSION,
        status=status,
        reason=reason,
        candidate_ref=candidate_ref,
        candidate_digest=candidate_digest,
        source_package_hash=source_package_hash,
        wire_hash=wire_hash,
        duplicate_count=duplicate_count,
        accepted=false,
        claim_ceiling=VNEXT_T1_CANDIDATE_BINDING_V2_CLAIM_CEILING,
    )
end

function _vnext_t1_binding_receipt(status::Symbol, reason::Symbol,
        candidate_ref::QualifiedRefV1, candidate_digest::Digest256,
        source_package_hash::Digest256, wire_hash::Union{Nothing,Digest256},
        duplicate_count::Int)
    body = _vnext_t1_binding_receipt_body(status, reason, candidate_ref,
        candidate_digest, source_package_hash, wire_hash, duplicate_count)
    VNextT1CandidateBindingReceiptV2(
        body.domain, body.schema, body.version, body.status, body.reason,
        body.candidate_ref, body.candidate_digest, body.source_package_hash,
        body.wire_hash, body.duplicate_count, body.accepted,
        body.claim_ceiling, _vnext_t1_binding_receipt_hash(status, reason,
            candidate_ref, candidate_digest, source_package_hash, wire_hash,
            duplicate_count))
end

semantic_view(x::VNextT1CandidateBindingReceiptV2) = merge(
    _vnext_t1_binding_receipt_body(x.status, x.reason, x.candidate_ref,
        x.candidate_digest, x.source_package_hash, x.wire_hash,
        x.duplicate_count),
    (receipt_hash=x.receipt_hash,))

"""Resolve one observed binding against one explicit expected binding.

`nothing` means typed absence and therefore `terminal_deferred`.  More than
one observation is never selected by order: identical duplicates and
conflicting duplicates both fail closed.  The wire digest is checked
independently and is never substituted for the receipt digest.
"""
function vnext_t1_candidate_binding_v2(
        expected::VNextT1CandidateBindingInputV2,
        observations::Tuple{Vararg{VNextT1CandidateBindingInputV2}})
    expected_wire_hash = expected.wire === nothing ? nothing : expected.wire.sha256
    count = length(observations)
    # Precedence is structural: multiplicity, explicit identities, then wire
    # presence/integrity.  Thus a foreign identity never degrades to absence.
    count == 0 && return _vnext_t1_binding_receipt(:terminal_deferred,
        :missing_observation, expected.candidate_ref, expected.candidate_digest,
        expected.source_package_hash, expected_wire_hash, count)
    count == 1 || return _vnext_t1_binding_receipt(:fail_closed,
        :duplicate_conflict, expected.candidate_ref, expected.candidate_digest,
        expected.source_package_hash, expected_wire_hash, count)

    observed = only(observations)
    observed.candidate_ref == expected.candidate_ref ||
        return _vnext_t1_binding_receipt(:fail_closed, :foreign_candidate_ref,
            expected.candidate_ref, expected.candidate_digest,
            expected.source_package_hash, expected_wire_hash, count)
    observed.candidate_digest == expected.candidate_digest ||
        return _vnext_t1_binding_receipt(:fail_closed, :candidate_digest_mismatch,
            expected.candidate_ref, expected.candidate_digest,
            expected.source_package_hash, expected_wire_hash, count)
    observed.source_package_hash == expected.source_package_hash ||
        return _vnext_t1_binding_receipt(:fail_closed, :source_package_hash_mismatch,
            expected.candidate_ref, expected.candidate_digest,
            expected.source_package_hash, expected_wire_hash, count)
    expected.wire === nothing && return _vnext_t1_binding_receipt(
        :terminal_deferred, :missing_expected_wire, expected.candidate_ref,
        expected.candidate_digest, expected.source_package_hash, nothing, count)
    observed.wire === nothing && return _vnext_t1_binding_receipt(
        :terminal_deferred, :missing_observed_wire, expected.candidate_ref,
        expected.candidate_digest, expected.source_package_hash,
        expected_wire_hash, count)
    observed.wire.sha256 == expected_wire_hash ||
        return _vnext_t1_binding_receipt(:fail_closed, :wire_hash_mismatch,
            expected.candidate_ref, expected.candidate_digest,
            expected.source_package_hash, expected_wire_hash, count)

    _vnext_t1_binding_receipt(:bound, :exact_explicit_binding,
        expected.candidate_ref, expected.candidate_digest,
        expected.source_package_hash, expected_wire_hash, count)
end
