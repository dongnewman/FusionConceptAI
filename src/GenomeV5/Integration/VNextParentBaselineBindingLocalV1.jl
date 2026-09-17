"""Versioned local-input adapter for the G1/G2 parent-baseline prerequisite.

This additive adapter is intentionally not included by FusionConceptAI.jl.  It
accepts runtime-owned local records rather than importing or hard-coding the
current G1/G2 repair hashes.  Every present branch retains the source bytes,
semantic bytes, source locator, factory receipt bytes, four axes, source and
declaration refs, layer, child and exact normalized candidate identity.

Missing material is a real typed-absent result.  Contradictory, duplicate,
foreign, stale or tampered material is fail-closed.  CAS replacement validates
both expected hashes and a complete state re-derivation before publishing.
The failure_atomic contract is enforced by immutable state snapshots in every
rejected CAS receipt. This file does not call a provider, compiler, solver,
mesh, T0/T1/T2 entry or physical path.
"""

const VNEXT_LOCAL_PBB_SCHEMA_ID_V1 =
    "GenomeV5/Integration/VNextParentBaselineBindingLocalV1"
const VNEXT_LOCAL_PBB_SCHEMA_VERSION_V1 = "v1"
const VNEXT_LOCAL_PBB_FACTORY_VERSION_V1 =
    "GenomeV5/Integration/VNextParentBaselineBindingLocalV1/factory-v1"
const VNEXT_LOCAL_PBB_REVIEW_VERSION_V1 =
    "GenomeV5/Integration/VNextParentBaselineBindingLocalV1/review-v1"
const VNEXT_LOCAL_PBB_AXES_COUNT_V1 = 4
const VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 = (:G1, :G2)
const VNEXT_LOCAL_PBB_ALLOWED_ORIGINS_V1 = (:runtime_local,)
const VNEXT_LOCAL_PBB_ALLOWED_RECEIPT_STATUS_V1 = (:source_backed_present, :unavailable)
const VNEXT_LOCAL_PBB_ALLOWED_REVIEW_STATUS_V1 = (:fresh_reviewed, :unavailable)
const VNEXT_LOCAL_PBB_ABSENT_REASONS_V1 = (
    :missing_declaration_record, :missing_child_record,
    :source_backed_receipt_unavailable, :fresh_identity_review_missing)
const VNEXT_LOCAL_PBB_ERROR_CODES_V1 = (
    :none, :foreign_candidate, :foreign_layer, :foreign_child,
    :duplicate_layer, :duplicate_child, :missing_layer, :missing_child,
    :unknown_layer, :unknown_child, :source_bytes_hash_mismatch,
    :source_locator_hash_mismatch, :source_locator_size_mismatch,
    :declaration_bytes_hash_mismatch, :semantic_body_hash_mismatch,
    :declaration_hash_mismatch, :factory_receipt_bytes_hash_mismatch,
    :factory_receipt_binding_mismatch, :factory_receipt_layer_mismatch,
    :factory_receipt_candidate_mismatch, :factory_receipt_ref_mismatch,
    :factory_receipt_axes_mismatch, :factory_receipt_status_invalid,
    :factory_receipt_unavailable, :authority_origin_rejected,
    :candidate_identity_missing, :four_axes_invalid, :source_ref_missing,
    :declaration_ref_missing, :source_ref_hash_mismatch, :declaration_ref_hash_mismatch,
    :duplicate_axis, :child_contract_hash_mismatch, :parent_binding_hash_mismatch,
    :review_bytes_hash_mismatch, :review_candidate_mismatch, :review_layer_mismatch,
    :review_ref_mismatch, :review_axes_mismatch, :review_status_invalid,
    :reviewer_ref_missing, :review_version_missing,
    :review_version_mismatch, :factory_version_mismatch,
    :child_request_binding_mismatch, :child_request_ref_mismatch,
    :child_request_hash_mismatch,
    :bundle_hash_mismatch, :state_canonical_hash_mismatch,
    :state_hash_mismatch, :source_content_hash_mismatch,
    :stale_state_hash, :stale_source_hash, :stale_history, :replacement_payload_missing,
    :replacement_payload_hash_mismatch, :baseline_authority_absent,
    :operation_invalid, :history_bound_exceeded, :program_exception)

_vnl_sha256(bytes::AbstractVector{UInt8}) =
    Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
_vnl_digest_text(x::Digest256) = x.value
_vnl_hash(domain::AbstractString, payload::AbstractString) =
    digest256_text(string(domain, "\0", payload))

"""A byte vector and a caller-claimed SHA-256, retained for independent checks."""
struct LocalDigestBytesV1
    bytes::Vector{UInt8}
    claimed_sha256::Digest256
    function LocalDigestBytesV1(bytes::AbstractVector{UInt8}, claimed_sha256::Digest256)
        new(copy(Vector{UInt8}(bytes)), claimed_sha256)
    end
end

"""Normalized candidate identity; no old candidate/hash is embedded here."""
struct LocalCandidateIdentityV1
    candidate_id::String
    candidate_version::String
    identity_hash::Digest256
    function LocalCandidateIdentityV1(candidate_id::AbstractString,
            candidate_version::AbstractString, identity_hash::Digest256)
        isempty(String(candidate_id)) && throw(ArgumentError("candidate_id is required"))
        isempty(String(candidate_version)) && throw(ArgumentError("candidate_version is required"))
        new(String(candidate_id), String(candidate_version), identity_hash)
    end
end
Base.:(==)(a::LocalCandidateIdentityV1, b::LocalCandidateIdentityV1) =
    a.candidate_id == b.candidate_id && a.candidate_version == b.candidate_version &&
    a.identity_hash == b.identity_hash
_vnl_candidate_text(x::LocalCandidateIdentityV1) =
    string(x.candidate_id, "@", x.candidate_version, ":", x.identity_hash.value)

"""Qualified source/declaration/axis reference retained in the local record."""
struct LocalQualifiedRefV1
    id::String
    version::String
    content_hash::Digest256
    function LocalQualifiedRefV1(id::AbstractString, version::AbstractString,
            content_hash::Digest256)
        isempty(String(id)) && throw(ArgumentError("qualified ref id is required"))
        isempty(String(version)) && throw(ArgumentError("qualified ref version is required"))
        new(String(id), String(version), content_hash)
    end
end
Base.:(==)(a::LocalQualifiedRefV1, b::LocalQualifiedRefV1) =
    a.id == b.id && a.version == b.version && a.content_hash == b.content_hash
_vnl_ref_text(x::LocalQualifiedRefV1) = string(x.id, "@", x.version, ":", x.content_hash.value)

"""Closed candidate-review receipt bound to the candidate and declaration refs."""
struct LocalCandidateIdentityReviewReceiptV1
    review_bytes::LocalDigestBytesV1
    review_sha256::Digest256
    review_status::Symbol
    review_version::String
    reviewer_ref::LocalQualifiedRefV1
    candidate::LocalCandidateIdentityV1
    layer::Symbol
    source_ref::LocalQualifiedRefV1
    declaration_ref::LocalQualifiedRefV1
    axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1}
    function LocalCandidateIdentityReviewReceiptV1(
            review_bytes::LocalDigestBytesV1, review_sha256::Digest256,
            review_status::Symbol, review_version::AbstractString,
            reviewer_ref::LocalQualifiedRefV1, candidate::LocalCandidateIdentityV1,
            layer::Symbol, source_ref::LocalQualifiedRefV1,
            declaration_ref::LocalQualifiedRefV1,
            axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1})
        isempty(String(review_version)) && throw(ArgumentError("review version required"))
        isempty(reviewer_ref.id) && throw(ArgumentError("reviewer ref required"))
        layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 ||
            throw(ArgumentError("unknown review layer"))
        new(review_bytes, review_sha256, review_status, String(review_version),
            reviewer_ref, candidate, layer, source_ref, declaration_ref, axes)
    end
end

"""Portable source locator with runtime-observed source byte count/hash."""
struct LocalSourceLocatorV1
    repository_root::String
    source_path::String
    module_identity::String
    declaration_type::String
    factory_identity::String
    input_locator::String
    source_bytes::Int
    source_sha256::Digest256
    function LocalSourceLocatorV1(repository_root::AbstractString,
            source_path::AbstractString, module_identity::AbstractString,
            declaration_type::AbstractString, factory_identity::AbstractString,
            input_locator::AbstractString, source_bytes::Integer,
            source_sha256::Digest256)
        fields = (repository_root, source_path, module_identity, declaration_type,
            factory_identity, input_locator)
        all(!isempty(String(x)) for x in fields) ||
            throw(ArgumentError("source locator fields are required"))
        !startswith(String(source_path), "/") && !startswith(String(source_path), "\\") &&
            !occursin("..", replace(String(source_path), '\\' => '/')) ||
            throw(ArgumentError("source path must be relative and non-escaping"))
        source_bytes >= 0 || throw(ArgumentError("source_bytes must be non-negative"))
        new(String(repository_root), replace(String(source_path), '\\' => '/'),
            String(module_identity), String(declaration_type), String(factory_identity),
            String(input_locator), Int(source_bytes), source_sha256)
    end
end

"""Factory receipt envelope; its bytes and all binding metadata are checked."""
struct LocalFactoryReceiptV1
    factory_identity::String
    factory_version::String
    receipt_status::Symbol
    receipt_bytes::LocalDigestBytesV1
    receipt_sha256::Digest256
    candidate::LocalCandidateIdentityV1
    layer::Symbol
    source_ref::LocalQualifiedRefV1
    declaration_ref::LocalQualifiedRefV1
    axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1}
    candidate_identity_review::LocalCandidateIdentityReviewReceiptV1
    function LocalFactoryReceiptV1(factory_identity::AbstractString,
            factory_version::AbstractString, receipt_status::Symbol,
            receipt_bytes::LocalDigestBytesV1, receipt_sha256::Digest256,
            candidate::LocalCandidateIdentityV1, layer::Symbol,
            source_ref::LocalQualifiedRefV1, declaration_ref::LocalQualifiedRefV1,
            axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1},
            candidate_identity_review::LocalCandidateIdentityReviewReceiptV1)
        !isempty(String(factory_identity)) || throw(ArgumentError("factory identity required"))
        !isempty(String(factory_version)) || throw(ArgumentError("factory version required"))
        layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 || throw(ArgumentError("unknown receipt layer"))
        new(String(factory_identity), String(factory_version), receipt_status,
            receipt_bytes, receipt_sha256, candidate, layer, source_ref,
            declaration_ref, axes, candidate_identity_review)
    end
end

"""Actual local declaration input. Constructor is permissive; binder is not."""
struct LocalDeclarationRecordV1
    layer::Symbol
    child_kind::Symbol
    child_id::String
    child_contract_ref::LocalQualifiedRefV1
    child_contract_hash::Digest256
    candidate::LocalCandidateIdentityV1
    axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1}
    source_ref::LocalQualifiedRefV1
    declaration_ref::LocalQualifiedRefV1
    source_bytes::LocalDigestBytesV1
    declaration_bytes::LocalDigestBytesV1
    semantic_body_bytes::LocalDigestBytesV1
    declaration_hash::Digest256
    semantic_body_hash::Digest256
    source_locator::LocalSourceLocatorV1
    factory_receipt::LocalFactoryReceiptV1
    authority_origin::Symbol
end

"""Candidate-owned child request; duplicate child identities are rejected."""
struct LocalChildRequestV1
    layer::Symbol
    child_kind::Symbol
    child_id::String
    child_contract_ref::LocalQualifiedRefV1
    child_contract_hash::Digest256
    function LocalChildRequestV1(layer::Symbol, child_kind::Symbol,
            child_id::AbstractString, child_contract_ref::LocalQualifiedRefV1,
            child_contract_hash::Digest256)
        new(layer, child_kind, String(child_id), child_contract_ref, child_contract_hash)
    end
end

struct LocalParentBaselineBatchInputV1
    candidate::LocalCandidateIdentityV1
    records::Tuple{Vararg{LocalDeclarationRecordV1}}
    children::Tuple{Vararg{LocalChildRequestV1}}
    function LocalParentBaselineBatchInputV1(candidate::LocalCandidateIdentityV1,
            records::Tuple{Vararg{LocalDeclarationRecordV1}},
            children::Tuple{Vararg{LocalChildRequestV1}})
        new(candidate, records, children)
    end
end

struct PresentLocalParentBaselineBindingV1
    layer::Symbol
    child_kind::Symbol
    child_id::String
    child_contract_ref::LocalQualifiedRefV1
    child_contract_hash::Digest256
    candidate::LocalCandidateIdentityV1
    axes::NTuple{VNEXT_LOCAL_PBB_AXES_COUNT_V1,LocalQualifiedRefV1}
    source_ref::LocalQualifiedRefV1
    declaration_ref::LocalQualifiedRefV1
    source_bytes::LocalDigestBytesV1
    declaration_bytes::LocalDigestBytesV1
    semantic_body_bytes::LocalDigestBytesV1
    declaration_hash::Digest256
    semantic_body_hash::Digest256
    source_locator::LocalSourceLocatorV1
    factory_receipt::LocalFactoryReceiptV1
    parent_binding_hash::Digest256
end

struct AbsentLocalParentBaselineBindingV1
    layer::Symbol
    child_kind::Symbol
    child_id::String
    candidate::LocalCandidateIdentityV1
    reason::Symbol
    resolution::Symbol
    absence_digest::Digest256
end

const LocalParentBaselineBindingUnionV1 =
    Union{PresentLocalParentBaselineBindingV1,AbsentLocalParentBaselineBindingV1}

struct PresentLocalParentBaselineBundleV1
    candidate::LocalCandidateIdentityV1
    g1::PresentLocalParentBaselineBindingV1
    g2::PresentLocalParentBaselineBindingV1
    bundle_hash::Digest256
end

struct AbsentLocalParentBaselineBundleV1
    candidate::LocalCandidateIdentityV1
    g1::AbsentLocalParentBaselineBindingV1
    g2::AbsentLocalParentBaselineBindingV1
    bundle_hash::Digest256
end

const LocalParentBaselineBundleUnionV1 =
    Union{PresentLocalParentBaselineBundleV1,AbsentLocalParentBaselineBundleV1}

struct LocalParentBaselineBindResultV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    errors::Tuple{Vararg{Symbol}}
    output::Union{LocalParentBaselineBundleUnionV1,Nothing}
    output_hash::Digest256
end

function _vnl_record_structural_errors(record::LocalDeclarationRecordV1,
        candidate::LocalCandidateIdentityV1)
    errors = Symbol[]
    record.layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 || push!(errors, :unknown_layer)
    expected_child = record.layer === :G1 ? :mechanism : record.layer === :G2 ? :geometry : nothing
    expected_child === nothing || record.child_kind === expected_child || push!(errors, :foreign_child)
    isempty(record.child_id) && push!(errors, :foreign_child)
    isempty(record.child_contract_ref.id) && push!(errors, :foreign_child)
    record.child_contract_hash == record.child_contract_ref.content_hash ||
        push!(errors, :child_contract_hash_mismatch)
    record.candidate == candidate || push!(errors, :foreign_candidate)
    record.authority_origin in VNEXT_LOCAL_PBB_ALLOWED_ORIGINS_V1 ||
        push!(errors, :authority_origin_rejected)
    length(record.axes) == VNEXT_LOCAL_PBB_AXES_COUNT_V1 || push!(errors, :four_axes_invalid)
    isempty(record.axes) && push!(errors, :four_axes_invalid)
    length(unique(_vnl_ref_text(x) for x in record.axes)) == VNEXT_LOCAL_PBB_AXES_COUNT_V1 ||
        push!(errors, :duplicate_axis)
    isempty(record.source_ref.id) && push!(errors, :source_ref_missing)
    isempty(record.declaration_ref.id) && push!(errors, :declaration_ref_missing)
    record.source_locator.source_bytes == length(record.source_bytes.bytes) ||
        push!(errors, :source_locator_size_mismatch)
    record.source_locator.source_sha256 == _vnl_sha256(record.source_bytes.bytes) ||
        push!(errors, :source_locator_hash_mismatch)
    record.source_bytes.claimed_sha256 == _vnl_sha256(record.source_bytes.bytes) ||
        push!(errors, :source_bytes_hash_mismatch)
    record.declaration_bytes.claimed_sha256 == _vnl_sha256(record.declaration_bytes.bytes) ||
        push!(errors, :declaration_bytes_hash_mismatch)
    record.semantic_body_bytes.claimed_sha256 == _vnl_sha256(record.semantic_body_bytes.bytes) ||
        push!(errors, :semantic_body_hash_mismatch)
    record.declaration_hash == _vnl_sha256(record.declaration_bytes.bytes) ||
        push!(errors, :declaration_hash_mismatch)
    record.semantic_body_hash == _vnl_sha256(record.semantic_body_bytes.bytes) ||
        push!(errors, :semantic_body_hash_mismatch)
    receipt = record.factory_receipt
    receipt.receipt_sha256 == _vnl_sha256(receipt.receipt_bytes.bytes) ||
        push!(errors, :factory_receipt_bytes_hash_mismatch)
    receipt.layer === record.layer || push!(errors, :factory_receipt_layer_mismatch)
    receipt.candidate == record.candidate || push!(errors, :factory_receipt_candidate_mismatch)
    receipt.candidate == candidate || push!(errors, :factory_receipt_candidate_mismatch)
    receipt.source_ref == record.source_ref && receipt.declaration_ref == record.declaration_ref ||
        push!(errors, :factory_receipt_ref_mismatch)
    record.source_ref.content_hash == _vnl_sha256(record.source_bytes.bytes) ||
        push!(errors, :source_ref_hash_mismatch)
    record.declaration_ref.content_hash == _vnl_sha256(record.declaration_bytes.bytes) ||
        push!(errors, :declaration_ref_hash_mismatch)
    receipt.axes == record.axes || push!(errors, :factory_receipt_axes_mismatch)
    receipt.factory_identity == record.source_locator.factory_identity ||
        push!(errors, :factory_receipt_binding_mismatch)
    receipt.factory_version == VNEXT_LOCAL_PBB_FACTORY_VERSION_V1 ||
        push!(errors, :factory_version_mismatch)
    receipt.receipt_status in VNEXT_LOCAL_PBB_ALLOWED_RECEIPT_STATUS_V1 ||
        push!(errors, :factory_receipt_status_invalid)
    receipt.receipt_bytes.claimed_sha256 == _vnl_sha256(receipt.receipt_bytes.bytes) ||
        push!(errors, :factory_receipt_bytes_hash_mismatch)
    review = receipt.candidate_identity_review
    review.review_sha256 == _vnl_sha256(review.review_bytes.bytes) ||
        push!(errors, :review_bytes_hash_mismatch)
    review.review_bytes.claimed_sha256 == _vnl_sha256(review.review_bytes.bytes) ||
        push!(errors, :review_bytes_hash_mismatch)
    review.candidate == record.candidate || push!(errors, :review_candidate_mismatch)
    review.candidate == candidate || push!(errors, :review_candidate_mismatch)
    review.layer === record.layer || push!(errors, :review_layer_mismatch)
    review.source_ref == record.source_ref && review.declaration_ref == record.declaration_ref ||
        push!(errors, :review_ref_mismatch)
    review.axes == record.axes || push!(errors, :review_axes_mismatch)
    review.review_status in VNEXT_LOCAL_PBB_ALLOWED_REVIEW_STATUS_V1 ||
        push!(errors, :review_status_invalid)
    isempty(review.reviewer_ref.id) && push!(errors, :reviewer_ref_missing)
    isempty(review.review_version) && push!(errors, :review_version_missing)
    review.review_version == VNEXT_LOCAL_PBB_REVIEW_VERSION_V1 ||
        push!(errors, :review_version_mismatch)
    unique!(errors)
    errors
end

function _vnl_record_absence_reason(record::LocalDeclarationRecordV1)
    record.factory_receipt.receipt_status === :unavailable &&
        return :source_backed_receipt_unavailable
    record.factory_receipt.candidate_identity_review.review_status === :unavailable &&
        return :fresh_identity_review_missing
    nothing
end

function _vnl_child_errors(children::Tuple{Vararg{LocalChildRequestV1}})
    errors = Symbol[]
    seen_layers = Symbol[]
    seen_children = String[]
    for child in children
        child.layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 || push!(errors, :unknown_layer)
        expected = child.layer === :G1 ? :mechanism : child.layer === :G2 ? :geometry : nothing
        expected === nothing || child.child_kind === expected || push!(errors, :foreign_child)
        isempty(child.child_id) && push!(errors, :missing_child)
        child.layer in seen_layers && push!(errors, :duplicate_layer)
        push!(seen_layers, child.layer)
        child.child_contract_hash == child.child_contract_ref.content_hash ||
            push!(errors, :child_contract_hash_mismatch)
        key = string(child.layer, ":", child.child_kind, ":", child.child_id)
        key in seen_children && push!(errors, :duplicate_child)
        push!(seen_children, key)
    end
    count(x -> x === :G1, seen_layers) == 1 || push!(errors, :missing_layer)
    count(x -> x === :G2, seen_layers) == 1 || push!(errors, :missing_layer)
    unique!(errors)
    errors
end

function _vnl_record_child_binding_errors(
        records::Tuple{Vararg{LocalDeclarationRecordV1}},
        children::Tuple{Vararg{LocalChildRequestV1}})
    errors = Symbol[]
    for record in records
        index = findfirst(child -> child.layer === record.layer, children)
        index === nothing && continue
        child = children[index]
        record.child_kind === child.child_kind && record.child_id == child.child_id ||
            push!(errors, :child_request_binding_mismatch)
        record.child_contract_ref == child.child_contract_ref ||
            push!(errors, :child_request_ref_mismatch)
        record.child_contract_hash == child.child_contract_hash ||
            push!(errors, :child_request_hash_mismatch)
    end
    unique!(errors)
    errors
end

function _vnl_record_layer_errors(records::Tuple{Vararg{LocalDeclarationRecordV1}})
    errors = Symbol[]
    seen = Symbol[]
    for record in records
        record.layer in seen && push!(errors, :duplicate_layer)
        push!(seen, record.layer)
    end
    count(x -> x === :G1, seen) == 1 || push!(errors, :missing_layer)
    count(x -> x === :G2, seen) == 1 || push!(errors, :missing_layer)
    unique!(errors)
    errors
end

function _vnl_absence_digest(candidate::LocalCandidateIdentityV1, layer::Symbol,
        child_kind::Symbol, child_id::String, reason::Symbol)
    _vnl_hash("vnext-local-pbb:absence:v1", string(_vnl_candidate_text(candidate),
        "\0", layer, "\0", child_kind, "\0", child_id, "\0", reason))
end

function _vnl_absent(candidate::LocalCandidateIdentityV1, layer::Symbol,
        child_kind::Symbol, child_id::String, reason::Symbol)
    AbsentLocalParentBaselineBindingV1(layer, child_kind, child_id, candidate,
        reason, :terminal_deferred,
        _vnl_absence_digest(candidate, layer, child_kind, child_id, reason))
end

function _vnl_parent_binding_hash(record::LocalDeclarationRecordV1)
    payload = string(record.layer, "\0", record.child_kind, "\0", record.child_id,
        "\0", _vnl_ref_text(record.child_contract_ref), "\0",
        record.child_contract_hash.value,
        "\0", _vnl_candidate_text(record.candidate), "\0",
        join(_vnl_ref_text.(record.axes), "\0"), "\0",
        _vnl_ref_text(record.source_ref), "\0", _vnl_ref_text(record.declaration_ref),
        "\0", record.source_locator.repository_root, "\0", record.source_locator.source_path,
        "\0", record.source_locator.module_identity, "\0", record.source_locator.declaration_type,
        "\0", record.source_locator.factory_identity, "\0", record.source_locator.input_locator,
        "\0", record.source_bytes.claimed_sha256.value, "\0",
        record.declaration_bytes.claimed_sha256.value, "\0", record.semantic_body_hash.value,
        "\0", record.factory_receipt.receipt_sha256.value, "\0",
        record.factory_receipt.candidate_identity_review.review_sha256.value, "\0",
        record.factory_receipt.candidate_identity_review.review_version, "\0",
        _vnl_ref_text(record.factory_receipt.candidate_identity_review.reviewer_ref))
    _vnl_hash("vnext-local-pbb:parent-binding:v1", payload)
end

function _vnl_present(record::LocalDeclarationRecordV1)
    PresentLocalParentBaselineBindingV1(record.layer, record.child_kind, record.child_id,
        record.child_contract_ref, record.child_contract_hash, record.candidate,
        record.axes, record.source_ref, record.declaration_ref,
        record.source_bytes, record.declaration_bytes, record.semantic_body_bytes,
        record.declaration_hash, record.semantic_body_hash, record.source_locator,
        record.factory_receipt, _vnl_parent_binding_hash(record))
end

function _vnl_bundle_hash(candidate::LocalCandidateIdentityV1,
        g1::PresentLocalParentBaselineBindingV1,
        g2::PresentLocalParentBaselineBindingV1)
    _vnl_hash("vnext-local-pbb:bundle-present:v1", string(_vnl_candidate_text(candidate),
        "\0", g1.parent_binding_hash.value, "\0", g2.parent_binding_hash.value))
end
function _vnl_bundle_hash(candidate::LocalCandidateIdentityV1,
        g1::AbsentLocalParentBaselineBindingV1,
        g2::AbsentLocalParentBaselineBindingV1)
    _vnl_hash("vnext-local-pbb:bundle-absent:v1", string(_vnl_candidate_text(candidate),
        "\0", g1.absence_digest.value, "\0", g2.absence_digest.value))
end

function verify_present_local_binding_v1(x::PresentLocalParentBaselineBindingV1)
    x.layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 || return false
    expected_child = x.layer === :G1 ? :mechanism : x.layer === :G2 ? :geometry : nothing
    expected_child === x.child_kind || return false
    !isempty(x.child_id) || return false
    !isempty(x.child_contract_ref.id) || return false
    x.child_contract_hash == x.child_contract_ref.content_hash || return false
    length(x.axes) == VNEXT_LOCAL_PBB_AXES_COUNT_V1 || return false
    length(unique(_vnl_ref_text(ref) for ref in x.axes)) == VNEXT_LOCAL_PBB_AXES_COUNT_V1 || return false
    x.factory_receipt.receipt_status === :source_backed_present || return false
    x.factory_receipt.factory_version == VNEXT_LOCAL_PBB_FACTORY_VERSION_V1 || return false
    review = x.factory_receipt.candidate_identity_review
    review.review_status === :fresh_reviewed || return false
    review.review_version == VNEXT_LOCAL_PBB_REVIEW_VERSION_V1 || return false
    review.review_sha256 == _vnl_sha256(review.review_bytes.bytes) || return false
    review.review_bytes.claimed_sha256 == _vnl_sha256(review.review_bytes.bytes) || return false
    review.candidate == x.candidate || return false
    review.layer === x.layer || return false
    review.source_ref == x.source_ref || return false
    review.declaration_ref == x.declaration_ref || return false
    review.axes == x.axes || return false
    !isempty(review.review_version) || return false
    !isempty(review.reviewer_ref.id) || return false
    x.candidate == x.factory_receipt.candidate || return false
    x.layer === x.factory_receipt.layer || return false
    x.factory_receipt.factory_identity == x.source_locator.factory_identity || return false
    x.source_ref == x.factory_receipt.source_ref || return false
    x.declaration_ref == x.factory_receipt.declaration_ref || return false
    x.axes == x.factory_receipt.axes || return false
    x.source_locator.source_sha256 == _vnl_sha256(x.source_bytes.bytes) || return false
    x.source_locator.source_bytes == length(x.source_bytes.bytes) || return false
    x.source_bytes.claimed_sha256 == _vnl_sha256(x.source_bytes.bytes) || return false
    x.source_ref.content_hash == _vnl_sha256(x.source_bytes.bytes) || return false
    x.declaration_bytes.claimed_sha256 == _vnl_sha256(x.declaration_bytes.bytes) || return false
    x.declaration_ref.content_hash == _vnl_sha256(x.declaration_bytes.bytes) || return false
    x.semantic_body_bytes.claimed_sha256 == _vnl_sha256(x.semantic_body_bytes.bytes) || return false
    x.declaration_hash == _vnl_sha256(x.declaration_bytes.bytes) || return false
    x.semantic_body_hash == _vnl_sha256(x.semantic_body_bytes.bytes) || return false
    x.factory_receipt.receipt_sha256 == _vnl_sha256(x.factory_receipt.receipt_bytes.bytes) || return false
    x.factory_receipt.receipt_bytes.claimed_sha256 == _vnl_sha256(x.factory_receipt.receipt_bytes.bytes) || return false
    x.parent_binding_hash == _vnl_parent_binding_hash(LocalDeclarationRecordV1(
        x.layer, x.child_kind, x.child_id, x.child_contract_ref,
        x.child_contract_hash, x.candidate, x.axes, x.source_ref,
        x.declaration_ref, x.source_bytes, x.declaration_bytes,
        x.semantic_body_bytes, x.declaration_hash, x.semantic_body_hash,
        x.source_locator, x.factory_receipt, :runtime_local)) || return false
    true
end

function verify_absent_local_binding_v1(x::AbsentLocalParentBaselineBindingV1)
    x.layer in VNEXT_LOCAL_PBB_ALLOWED_LAYERS_V1 || return false
    expected_child = x.layer === :G1 ? :mechanism : x.layer === :G2 ? :geometry : nothing
    expected_child === x.child_kind || return false
    !isempty(x.child_id) || return false
    x.resolution === :terminal_deferred || return false
    x.reason in VNEXT_LOCAL_PBB_ABSENT_REASONS_V1 || return false
    x.absence_digest == _vnl_absence_digest(x.candidate, x.layer,
        x.child_kind, x.child_id, x.reason)
end

function _vnl_result(status::Symbol, resolution::Symbol, errors::Vector{Symbol},
        output::Union{LocalParentBaselineBundleUnionV1,Nothing})
    unique!(errors)
    output_hash = output === nothing ?
        _vnl_hash("vnext-local-pbb:result:none:v1", string(status, "\0", join(String.(errors), ","))) :
        _vnl_hash("vnext-local-pbb:result:v1", string(status, "\0", repr(output)))
    LocalParentBaselineBindResultV1(status, resolution, status === :present,
        Tuple(errors), output, output_hash)
end

function _vnl_absent_bundle(input::LocalParentBaselineBatchInputV1, reason::Symbol)
    g1child = findfirst(x -> x.layer === :G1, input.children)
    g2child = findfirst(x -> x.layer === :G2, input.children)
    c1 = g1child === nothing ? LocalChildRequestV1(:G1, :mechanism,
        "missing-g1-child", LocalQualifiedRefV1("missing", "v1",
            _vnl_hash("vnext-local-pbb:missing-ref:v1", "G1")),
            _vnl_hash("vnext-local-pbb:missing-child:v1", "G1")) : input.children[g1child]
    c2 = g2child === nothing ? LocalChildRequestV1(:G2, :geometry,
        "missing-g2-child", LocalQualifiedRefV1("missing", "v1",
            _vnl_hash("vnext-local-pbb:missing-ref:v1", "G2")),
            _vnl_hash("vnext-local-pbb:missing-child:v1", "G2")) : input.children[g2child]
    g1 = _vnl_absent(input.candidate, :G1, c1.child_kind, c1.child_id, reason)
    g2 = _vnl_absent(input.candidate, :G2, c2.child_kind, c2.child_id, reason)
    AbsentLocalParentBaselineBundleV1(input.candidate, g1, g2,
        _vnl_bundle_hash(input.candidate, g1, g2))
end

function _vnl_missing_material_reason(input::LocalParentBaselineBatchInputV1)
    record_layers = Set(record.layer for record in input.records)
    child_layers = Set(child.layer for child in input.children)
    (:G1 in record_layers && :G2 in record_layers) ||
        return :missing_declaration_record
    (:G1 in child_layers && :G2 in child_layers) ||
        return :missing_child_record
    nothing
end

_vnl_only_missing_errors(errors::Vector{Symbol}) =
    all(error -> error in (:missing_layer, :missing_child), errors)

"""Bind exactly one checked local G1 and G2 record to one child per layer."""
function bind_local_parent_baseline_v1(input::LocalParentBaselineBatchInputV1)
    try
        missing_reason = _vnl_missing_material_reason(input)
        errors = _vnl_record_layer_errors(input.records)
        append!(errors, _vnl_child_errors(input.children))
        append!(errors, _vnl_record_child_binding_errors(input.records, input.children))
        for record in input.records
            append!(errors, _vnl_record_structural_errors(record, input.candidate))
        end
        if missing_reason !== nothing && _vnl_only_missing_errors(errors)
            return _vnl_result(:typed_absent, :terminal_deferred,
                Symbol[], _vnl_absent_bundle(input, missing_reason))
        end
        isempty(errors) || return _vnl_result(:fail_closed, :none, errors, nothing)
        by_layer = Dict(record.layer => record for record in input.records)
        g1 = by_layer[:G1]
        g2 = by_layer[:G2]
        reasons = Symbol[]
        for record in (g1, g2)
            reason = _vnl_record_absence_reason(record)
            reason === nothing || push!(reasons, reason)
        end
        if !isempty(reasons)
            reason = first(reasons)
            return _vnl_result(:typed_absent, :terminal_deferred,
                Symbol[], _vnl_absent_bundle(input, reason))
        end
        p1 = _vnl_present(g1); p2 = _vnl_present(g2)
        verify_present_local_binding_v1(p1) && verify_present_local_binding_v1(p2) ||
            return _vnl_result(:fail_closed, :none, [:parent_binding_hash_mismatch], nothing)
        p1.candidate == p2.candidate ||
            return _vnl_result(:fail_closed, :none, [:foreign_candidate], nothing)
        bundle = PresentLocalParentBaselineBundleV1(input.candidate, p1, p2,
            _vnl_bundle_hash(input.candidate, p1, p2))
        _vnl_result(:present, :resolved, Symbol[], bundle)
    catch
        _vnl_result(:fail_closed, :none, [:program_exception], nothing)
    end
end

struct LocalCanonicalStateV1
    bundle::LocalParentBaselineBundleUnionV1
    source_content_hash::Digest256
    canonical_bytes::Vector{UInt8}
    canonical_sha256::Digest256
    state_hash::Digest256
    history::Tuple{Vararg{Digest256}}
    function LocalCanonicalStateV1(bundle::LocalParentBaselineBundleUnionV1,
            source_content_hash::Digest256, canonical_bytes::AbstractVector{UInt8},
            canonical_sha256::Digest256, state_hash::Digest256,
            history::Tuple{Vararg{Digest256}})
        new(bundle, source_content_hash, copy(Vector{UInt8}(canonical_bytes)),
            canonical_sha256, state_hash, history)
    end
end

function _vnl_bundle_hash(x::PresentLocalParentBaselineBundleV1)
    x.bundle_hash
end
function _vnl_bundle_hash(x::AbsentLocalParentBaselineBundleV1)
    x.bundle_hash
end
function recompute_local_bundle_hash_v1(x::PresentLocalParentBaselineBundleV1)
    _vnl_bundle_hash(x.candidate, x.g1, x.g2)
end
function recompute_local_bundle_hash_v1(x::AbsentLocalParentBaselineBundleV1)
    _vnl_bundle_hash(x.candidate, x.g1, x.g2)
end
function _vnl_history_hash(history::Tuple{Vararg{Digest256}})
    _vnl_hash("vnext-local-pbb:history:v1", join((item.value for item in history), "\0"))
end
function _vnl_state_bytes(bundle::LocalParentBaselineBundleUnionV1,
        source_content_hash::Digest256, history::Tuple{Vararg{Digest256}})
    Vector{UInt8}(codeunits(string("schema=", VNEXT_LOCAL_PBB_SCHEMA_ID_V1,
        ";version=", VNEXT_LOCAL_PBB_SCHEMA_VERSION_V1, ";status=",
        bundle isa PresentLocalParentBaselineBundleV1 ? "present" : "typed_absent",
        ";bundle_hash=", _vnl_bundle_hash(bundle).value,
        ";source_content_hash=", source_content_hash.value,
        ";history_length=", length(history),
        ";history_hash=", _vnl_history_hash(history).value)))
end
function _vnl_state_hash(bundle::LocalParentBaselineBundleUnionV1,
        source_content_hash::Digest256, bytes::AbstractVector{UInt8},
        history::Tuple{Vararg{Digest256}})
    _vnl_hash("vnext-local-pbb:state:v1", string(_vnl_bundle_hash(bundle).value,
        "\0", source_content_hash.value, "\0", _vnl_history_hash(history).value,
        "\0", String(copy(bytes))))
end

function local_state_from_binding_v1(result::LocalParentBaselineBindResultV1)
    result.output === nothing && return nothing
    source_hash = _vnl_hash("vnext-local-pbb:source-content:v1",
        _vnl_bundle_hash(result.output).value)
    history = ()
    bytes = _vnl_state_bytes(result.output, source_hash, history)
    LocalCanonicalStateV1(result.output, source_hash, bytes,
        _vnl_sha256(bytes), _vnl_state_hash(result.output, source_hash, bytes, history), history)
end

function verify_local_state_v1(state::LocalCanonicalStateV1)
    length(state.history) <= 64 || return false
    bundle = state.bundle
    recompute_local_bundle_hash_v1(bundle) == bundle.bundle_hash || return false
    if bundle isa PresentLocalParentBaselineBundleV1
        bundle.candidate == bundle.g1.candidate || return false
        bundle.candidate == bundle.g2.candidate || return false
    else
        bundle.candidate == bundle.g1.candidate || return false
        bundle.candidate == bundle.g2.candidate || return false
    end
    state.canonical_sha256 == _vnl_sha256(state.canonical_bytes) || return false
    state.canonical_bytes == _vnl_state_bytes(state.bundle, state.source_content_hash,
        state.history) || return false
    state.state_hash == _vnl_state_hash(state.bundle, state.source_content_hash,
        state.canonical_bytes, state.history) || return false
    state.bundle isa PresentLocalParentBaselineBundleV1 &&
        (verify_present_local_binding_v1(state.bundle.g1) &&
         verify_present_local_binding_v1(state.bundle.g2)) ||
        state.bundle isa AbsentLocalParentBaselineBundleV1 &&
        (verify_absent_local_binding_v1(state.bundle.g1) &&
         verify_absent_local_binding_v1(state.bundle.g2))
end

struct LocalReplaceSourcePayloadInputV1
    operation_id::String
    expected_prior_state_hash::Digest256
    expected_prior_source_content_hash::Digest256
    expected_prior_history::Tuple{Vararg{Digest256}}
    replacement_payload::LocalDigestBytesV1
    function LocalReplaceSourcePayloadInputV1(operation_id::AbstractString,
            expected_prior_state_hash::Digest256,
            expected_prior_source_content_hash::Digest256,
            expected_prior_history::Tuple{Vararg{Digest256}},
            replacement_payload::LocalDigestBytesV1)
        isempty(String(operation_id)) && throw(ArgumentError("operation_id required"))
        new(String(operation_id), expected_prior_state_hash,
            expected_prior_source_content_hash, expected_prior_history,
            replacement_payload)
    end
end

struct LocalReplaceSourcePayloadReceiptV1
    status::Symbol
    error_code::Symbol
    state_after::Union{LocalCanonicalStateV1,Nothing}
    prior_canonical_bytes::Vector{UInt8}
    prior_canonical_sha256::Digest256
    prior_state_hash::Digest256
    prior_source_content_hash::Digest256
    prior_history::Tuple{Vararg{Digest256}}
    published::Bool
    history_advanced::Bool
end

function _vnl_failure(state::LocalCanonicalStateV1, code::Symbol)
    LocalReplaceSourcePayloadReceiptV1(:rejected, code, nothing,
        copy(state.canonical_bytes), state.canonical_sha256, state.state_hash,
        state.source_content_hash, state.history, false, false)
end

function replace_local_source_payload_v1(state::LocalCanonicalStateV1,
        input::LocalReplaceSourcePayloadInputV1)
    input.expected_prior_source_content_hash == state.source_content_hash ||
        return _vnl_failure(state, :stale_source_hash)
    input.expected_prior_state_hash == state.state_hash ||
        return _vnl_failure(state, :stale_state_hash)
    input.expected_prior_history == state.history ||
        return _vnl_failure(state, :stale_history)
    verify_local_state_v1(state) || return _vnl_failure(state, :state_hash_mismatch)
    state.bundle isa PresentLocalParentBaselineBundleV1 ||
        return _vnl_failure(state, :baseline_authority_absent)
    isempty(input.replacement_payload.bytes) &&
        return _vnl_failure(state, :replacement_payload_missing)
    input.replacement_payload.claimed_sha256 == _vnl_sha256(input.replacement_payload.bytes) ||
        return _vnl_failure(state, :replacement_payload_hash_mismatch)
    length(state.history) < 64 || return _vnl_failure(state, :history_bound_exceeded)
    new_source_hash = input.replacement_payload.claimed_sha256
    operation_hash = _vnl_hash("vnext-local-pbb:operation:v1", string(
        input.operation_id, "\0", state.state_hash.value, "\0", new_source_hash.value,
        "\0", _vnl_history_hash(state.history).value))
    history = (state.history..., operation_hash)
    bytes = _vnl_state_bytes(state.bundle, new_source_hash, history)
    next_state = LocalCanonicalStateV1(state.bundle, new_source_hash, bytes,
        _vnl_sha256(bytes), _vnl_state_hash(state.bundle, new_source_hash, bytes, history), history)
    LocalReplaceSourcePayloadReceiptV1(:published, :none, next_state,
        copy(state.canonical_bytes), state.canonical_sha256, state.state_hash,
        state.source_content_hash, state.history, true, true)
end

function promote_absent_local_to_present_v1(state::LocalCanonicalStateV1)
    state.bundle isa AbsentLocalParentBaselineBundleV1 ||
        throw(ArgumentError("promotion requires absent state"))
    throw(ArgumentError("absent_to_present_cas_forbidden"))
end
