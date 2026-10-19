"""Closed, static-only T1 package declarations for the v5-next boundary.

This file is not included by ``FusionConceptAI.jl``. It is intentionally
dependent on the source-backed local T0 transport and local authority-recheck
declarations being loaded first. It performs no source I/O, factory execution,
Julia/DESC run, provider admission, or physical claim.
"""

const VNEXT_T1_PACKAGE_SCHEMA_ID_V1 =
    "GenomeV5/Contracts/CandidateStatePackageV5Next"
const VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1 = "v1"
const VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V1 = "canonical-json-v1"
const VNEXT_T1_PACKAGE_PROFILE_VERSION_V1 = "closed-no-legacy-v1"
const VNEXT_T1_NO_LEGACY_RECEIPT_ID_V1 =
    "fusionconceptai://GenomeV5Next/T1/no-legacy"
const VNEXT_T1_G1_FACTORY_ID_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G1/source-authority-factory", "v1")
const VNEXT_T1_G2_FACTORY_ID_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G2/source-authority-factory", "v1")
const VNEXT_T1_G3_FACTORY_ID_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G3/source-authority-factory", "v1")
const VNEXT_T1_G3_FEEDBACK_FACTORY_ID_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G3/source-feedback-declaration-factory", "v1")
const VNEXT_T1_FACTORY_VERSION_V1 = "v1"
const VNEXT_T1_FROZEN_G1_CONTRACT_REF_V1 = _g1sf_expected_contract()
const VNEXT_T1_FROZEN_G2_CONTRACT_REF_V1 = _g2sf_expected_contract()
const VNEXT_T1_FROZEN_G3_CONTRACT_REF_V1 = g3_contract_ref(:realization)
const VNEXT_T1_FROZEN_G3_FEEDBACK_CONTRACT_REF_V1 =
    vnext_t0_local_g3_feedback_contract_v1()
const VNEXT_T1_FROZEN_G3_REALIZATION_CONTRACT_REF_V1 = g3_contract_ref(:realization)
const VNEXT_T1_FROZEN_G3_CONTROL_CONTRACT_REF_V1 = g3_contract_ref(:control)
const VNEXT_T1_FROZEN_G3_BINDING_CONTRACT_REF_V1 = g3_contract_ref(:binding)
const VNEXT_T1_FACTORY_IDS_V1 = (
    VNEXT_T1_G1_FACTORY_ID_V1, VNEXT_T1_G2_FACTORY_ID_V1,
    VNEXT_T1_G3_FACTORY_ID_V1, VNEXT_T1_G3_FEEDBACK_FACTORY_ID_V1)
const VNEXT_T1_FACTORY_VERSIONS_V1 = (
    VNEXT_T1_FACTORY_VERSION_V1, VNEXT_T1_FACTORY_VERSION_V1,
    VNEXT_T1_FACTORY_VERSION_V1, VNEXT_T1_FACTORY_VERSION_V1)
const VNEXT_T1_REQUIRED_LAYERS_V1 = (:G1, :G2, :G3)
const VNEXT_T1_REQUIRED_CHILDREN_V1 = (:realization, :control, :binding)
const VNEXT_T1_AXIS_IDS_V1 = (
    "fusion.t0.local/payload-schema", "fusion.t0.local/canonicalization",
    "fusion.t0.local/applicability", "fusion.t0.local/evidence-receipt")
const VNEXT_T1_AXIS_VERSION_V1 = "v1"
const VNEXT_T1_REQUIRED_COMPONENT_COUNT_V1 = 3

vnext_t1_package_schema_hash_v1() = digest256_text(
    VNEXT_T1_PACKAGE_SCHEMA_ID_V1 * ":" * VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1)
vnext_t1_package_canonicalization_hash_v1() = digest256_text(
    VNEXT_T1_PACKAGE_SCHEMA_ID_V1 * ":" * VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V1)
vnext_t1_package_profile_hash_v1() = digest256_text(
    VNEXT_T1_PACKAGE_SCHEMA_ID_V1 * ":" * VNEXT_T1_PACKAGE_PROFILE_VERSION_V1)

@noinline Base.@nospecializeinfer function _vnext_t1_sha(
        @nospecialize(bytes::Tuple{Vararg{UInt8}}))
    # Keep payload length out of SHA's inferred argument type. The immutable
    # V1 tuple and its wire representation stay unchanged; only the hashing
    # implementation receives a length-independent, byte-for-byte copy.
    copied = Vector{UInt8}(undef, length(bytes))
    for i in eachindex(copied)
        copied[i] = bytes[i]
    end
    Digest256(bytes2hex(SHA.sha256(copied)))
end
_vnext_t1_sha(bytes::AbstractVector{UInt8}) = Digest256(bytes2hex(
    invoke(SHA.sha256, Tuple{SHA.AbstractBytes}, bytes)))

"""Immutable canonical bytes with a hash recomputed from those exact bytes."""
struct VNextT1CanonicalBytesV1{N}
    bytes::NTuple{N,UInt8}
    sha256::Digest256
    @noinline Base.@nospecializeinfer function VNextT1CanonicalBytesV1(
            @nospecialize(bytes::Tuple{Vararg{UInt8}}))
        new{length(bytes)}(bytes, _vnext_t1_sha(bytes))
    end
end
@noinline Base.@nospecializeinfer function VNextT1CanonicalBytesV1(
        @nospecialize(bytes::AbstractVector{UInt8}))
    VNextT1CanonicalBytesV1(Tuple(UInt8.(bytes)))
end
_vnext_t1_owned_bytes(bytes::VNextT0LocalBytesV1) =
    VNextT1CanonicalBytesV1(bytes.bytes)
semantic_view(x::VNextT1CanonicalBytesV1) =
    (bytes=x.bytes, sha256=x.sha256)

# Preserve the exact legacy semantic projection without specializing the
# generic tuple generator/join on every payload length.
@noinline Base.@nospecializeinfer function _canonical(
        @nospecialize(x::VNextT1CanonicalBytesV1))
    tokens = String[_canonical(UInt8(i)) for i in 0:255]
    io = IOBuffer()
    write(io, "{\"bytes\":[")
    bytes = x.bytes
    for i in 1:length(bytes)
        i == 1 || write(io, ',')
        write(io, tokens[Int(bytes[i]) + 1])
    end
    write(io, "],\"sha256\":")
    write(io, _canonical(x.sha256))
    write(io, '}')
    String(take!(io))
end

"""Canonical T0 bundle snapshot bound into both the package and its hash."""
struct VNextT1PriorBundleSnapshotV1{N}
    canonical_bytes::VNextT1CanonicalBytesV1{N}
    bundle_hash::Digest256
    function VNextT1PriorBundleSnapshotV1(bytes::VNextT1CanonicalBytesV1{N},
            bundle_hash::Digest256) where {N}
        new{N}(bytes, bundle_hash)
    end
end
semantic_view(x::VNextT1PriorBundleSnapshotV1) =
    (canonical_bytes=x.canonical_bytes, bundle_hash=x.bundle_hash)

"""Explicit contract identity; profile is hashed, never left as an open label."""
struct VNextT1LayerContractIdentityV1
    layer::Symbol
    contract_ref::GenomeContractRef
    schema_hash::Digest256
    canonicalization_hash::Digest256
    compatibility_profile_hash::Digest256
    function VNextT1LayerContractIdentityV1(layer::Symbol,
            contract_ref::GenomeContractRef)
        layer in VNEXT_T1_REQUIRED_LAYERS_V1 ||
            throw(ArgumentError("unknown T1 contract layer"))
        profile_hash = digest256_text(contract_ref.compatibility_profile)
        new(layer, contract_ref, contract_ref.schema_hash,
            contract_ref.canonicalization_hash, profile_hash)
    end
end
semantic_view(x::VNextT1LayerContractIdentityV1) = (
    layer=x.layer, contract_ref=x.contract_ref, schema_hash=x.schema_hash,
    canonicalization_hash=x.canonicalization_hash,
    compatibility_profile_hash=x.compatibility_profile_hash)

"""Closed receipt projection; the open T0 result is retained only by the caller."""
struct VNextT1ReceiptProjectionV1
    kind::Symbol
    bytes::VNextT1CanonicalBytesV1
    candidate_ref::QualifiedRefV1
    layer::Symbol
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    axes::NTuple{4,QualifiedRefV1}
    factory_axes::NTuple{4,QualifiedRefV1}
    status::Symbol
    factory_api::Symbol
    factory_result_hash::Digest256
end
semantic_view(x::VNextT1ReceiptProjectionV1) = (
    kind=x.kind, bytes=x.bytes, candidate_ref=x.candidate_ref,
    layer=x.layer, source_ref=x.source_ref, declaration_ref=x.declaration_ref,
    axes=x.axes, factory_axes=x.factory_axes, status=x.status,
    factory_api=x.factory_api, factory_result_hash=x.factory_result_hash)

"""Closed VNext receipt proving that no legacy mapping was supplied."""
struct VNextT1NoLegacyReceiptV1
    receipt_id::QualifiedRefV1
    candidate_ref::QualifiedRefV1
    legacy_refs::NTuple{0,QualifiedRefV1}
    status::Symbol
    candidate_identity_hash::Digest256
    receipt_hash::Digest256
    function VNextT1NoLegacyReceiptV1(receipt_id::QualifiedRefV1,
            candidate_ref::QualifiedRefV1,
            legacy_refs::NTuple{0,QualifiedRefV1}, status::Symbol,
            candidate_identity_hash::Digest256)
        candidate_ref.version == "v5" ||
            throw(ArgumentError("VNext candidate must carry v5 version"))
        status === :no_legacy_mapping ||
            throw(ArgumentError("VNext receipt status must be no_legacy_mapping"))
        candidate_identity_hash == canonical_hash((kind=:candidate_identity,
            candidate_ref=candidate_ref)) ||
            throw(ArgumentError("VNext candidate identity hash mismatch"))
        payload = (receipt_id=receipt_id, candidate_ref=candidate_ref,
            legacy_refs=legacy_refs, status=status,
            candidate_identity_hash=candidate_identity_hash)
        new(receipt_id, candidate_ref, legacy_refs, status,
            candidate_identity_hash, canonical_hash(payload))
    end
end
semantic_view(x::VNextT1NoLegacyReceiptV1) = (
    receipt_id=x.receipt_id, candidate_ref=x.candidate_ref,
    legacy_refs=x.legacy_refs, status=x.status,
    candidate_identity_hash=x.candidate_identity_hash, receipt_hash=x.receipt_hash)
_vnext_t1_no_legacy_payload(x::VNextT1NoLegacyReceiptV1) = (
    receipt_id=x.receipt_id, candidate_ref=x.candidate_ref,
    legacy_refs=x.legacy_refs, status=x.status,
    candidate_identity_hash=x.candidate_identity_hash)
function vnext_t1_no_legacy_receipt_v1(candidate_ref::QualifiedRefV1)
    identity_hash = canonical_hash((kind=:candidate_identity,
        candidate_ref=candidate_ref))
    VNextT1NoLegacyReceiptV1(
        QualifiedRefV1(VNEXT_T1_NO_LEGACY_RECEIPT_ID_V1, "v1"),
        candidate_ref, (), :no_legacy_mapping, identity_hash)
end
function _vnext_t1_validate_no_legacy_receipt(
        receipt::VNextT1NoLegacyReceiptV1, candidate_ref::QualifiedRefV1)
    receipt == vnext_t1_no_legacy_receipt_v1(candidate_ref) ||
        throw(ArgumentError("VNext no-legacy receipt/candidate join mismatch"))
    receipt.receipt_hash == canonical_hash(_vnext_t1_no_legacy_payload(receipt)) ||
        throw(ArgumentError("VNext no-legacy receipt hash mismatch"))
    receipt
end

"""A present declaration projection with no untyped/open package field."""
struct VNextT1DeclarationRecordV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
    axes::NTuple{4,QualifiedRefV1}
    source_bytes::VNextT1CanonicalBytesV1
    declaration_bytes::VNextT1CanonicalBytesV1
    semantic_body_bytes::VNextT1CanonicalBytesV1
    source_locator::VNextT0LocalSourceLocatorV1
    factory_receipt::VNextT1ReceiptProjectionV1
    declaration_receipt::VNextT1ReceiptProjectionV1
    contract_identity::VNextT1LayerContractIdentityV1
end
semantic_view(x::VNextT1DeclarationRecordV1) = (
    layer=x.layer, candidate_ref=x.candidate_ref, source_ref=x.source_ref,
    declaration_ref=x.declaration_ref, source_identity_hash=x.source_identity_hash,
    declaration_identity_hash=x.declaration_identity_hash, axes=x.axes,
    source_bytes=x.source_bytes, declaration_bytes=x.declaration_bytes,
    semantic_body_bytes=x.semantic_body_bytes, source_locator=x.source_locator,
    factory_receipt=x.factory_receipt, declaration_receipt=x.declaration_receipt,
    contract_identity=x.contract_identity)

abstract type VNextT1ChildRecordV1 end
struct VNextT1PresentChildRecordV1 <: VNextT1ChildRecordV1
    kind::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    child_id::String
    child_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_bytes::VNextT1CanonicalBytesV1
    source_locator::VNextT0LocalSourceLocatorV1
    body_hash::Digest256
    child_identity_hash::Digest256
end
struct VNextT1AbsentChildRecordV1 <: VNextT1ChildRecordV1
    kind::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    child_id::String
    status::Symbol
    reason::String
    candidate_identity_created::Bool
    factory_api::Symbol
    factory_receipt_bytes::VNextT1CanonicalBytesV1
    factory_receipt_hash::Digest256
    source_path::String
end
const VNEXT_T1_CHILD_RECORD_TYPE_V1 =
    Union{VNextT1PresentChildRecordV1,VNextT1AbsentChildRecordV1}
semantic_view(x::VNextT1PresentChildRecordV1) = (
    kind=x.kind, candidate_ref=x.candidate_ref, layer=x.layer,
    child_id=x.child_id, child_ref=x.child_ref, source_ref=x.source_ref,
    source_bytes=x.source_bytes, source_locator=x.source_locator,
    body_hash=x.body_hash, child_identity_hash=x.child_identity_hash)
semantic_view(x::VNextT1AbsentChildRecordV1) = (
    kind=x.kind, candidate_ref=x.candidate_ref, layer=x.layer,
    child_id=x.child_id, status=x.status, reason=x.reason,
    candidate_identity_created=x.candidate_identity_created,
    factory_api=x.factory_api, factory_receipt_bytes=x.factory_receipt_bytes,
    factory_receipt_hash=x.factory_receipt_hash, source_path=x.source_path)

"""Feedback projection bound to a concrete target declaration and body hash."""
struct VNextT1FeedbackRecordV1
    target_id::String
    target_layer::Symbol
    candidate_ref::QualifiedRefV1
    target_ref::QualifiedRefV1
    target_declaration_ref::QualifiedRefV1
    target_declaration_identity_hash::Digest256
    target_body_hash::Digest256
    body_hash::Digest256
end
semantic_view(x::VNextT1FeedbackRecordV1) = (
    target_id=x.target_id, target_layer=x.target_layer,
    candidate_ref=x.candidate_ref, target_ref=x.target_ref,
    target_declaration_ref=x.target_declaration_ref,
    target_declaration_identity_hash=x.target_declaration_identity_hash,
    target_body_hash=x.target_body_hash, body_hash=x.body_hash)

"""The label-erased identity payload used by the package hash."""
struct VNextT1DeclarationIdentityV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
    axes::NTuple{4,QualifiedRefV1}
    semantic_body_bytes::VNextT1CanonicalBytesV1
end
semantic_view(x::VNextT1DeclarationIdentityV1) = (
    layer=x.layer, candidate_ref=x.candidate_ref, source_ref=x.source_ref,
    declaration_ref=x.declaration_ref, source_identity_hash=x.source_identity_hash,
    declaration_identity_hash=x.declaration_identity_hash, axes=x.axes,
    semantic_body_bytes=x.semantic_body_bytes)
# Label-erased semantic identity is canonicalized with labels=() and body bytes.
struct VNextT1ChildIdentityV1
    kind::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    child_id::String
    status::Symbol
    reason::String
    candidate_identity_created::Bool
    factory_api::Symbol
    factory_receipt_hash::Union{Nothing,Digest256}
    source_path::String
    body_hash::Union{Nothing,Digest256}
    child_identity_hash::Union{Nothing,Digest256}
    source_ref::Union{Nothing,QualifiedRefV1}
    source_sha256::Union{Nothing,Digest256}
end
struct VNextT1LabelErasedIdentityV1{N}
    candidate_ref::QualifiedRefV1
    declarations::NTuple{3,VNextT1DeclarationIdentityV1}
    children::NTuple{3,VNextT1ChildIdentityV1}
    axes::NTuple{3,NTuple{4,QualifiedRefV1}}
    feedback::NTuple{N,VNextT1FeedbackRecordV1}
    source_hashes::NTuple{3,Digest256}
    declaration_hashes::NTuple{3,Digest256}
end
semantic_view(x::VNextT1ChildIdentityV1) = (
    kind=x.kind, candidate_ref=x.candidate_ref, layer=x.layer,
    child_id=x.child_id, status=x.status, reason=x.reason,
    candidate_identity_created=x.candidate_identity_created,
    factory_api=x.factory_api, factory_receipt_hash=x.factory_receipt_hash,
    source_path=x.source_path, body_hash=x.body_hash,
    child_identity_hash=x.child_identity_hash, source_ref=x.source_ref,
    source_sha256=x.source_sha256)
semantic_view(x::VNextT1LabelErasedIdentityV1) = (
    candidate_ref=x.candidate_ref, declarations=x.declarations,
    children=x.children, axes=x.axes, feedback=x.feedback,
    source_hashes=x.source_hashes, declaration_hashes=x.declaration_hashes)

"""Exact declaration/child/feedback tuples; counts cannot be detached."""
struct VNextT1ComponentCountReceiptV1{N}
    declaration_layers::NTuple{3,Symbol}
    child_kinds::NTuple{3,Symbol}
    feedback_ids::NTuple{N,String}
    declaration_count::Int
    child_count::Int
    feedback_count::Int
    component_count::Int
    count_hash::Digest256
    function VNextT1ComponentCountReceiptV1(
            declaration_layers::NTuple{3,Symbol},
            child_kinds::NTuple{3,Symbol}, feedback_ids::NTuple{N,String}) where {N}
        declaration_layers == VNEXT_T1_REQUIRED_LAYERS_V1 ||
            throw(ArgumentError("declaration layer tuple mismatch"))
        child_kinds == VNEXT_T1_REQUIRED_CHILDREN_V1 ||
            throw(ArgumentError("child kind tuple mismatch"))
        length(unique(feedback_ids)) == N ||
            throw(ArgumentError("feedback IDs must be unique"))
        count_hash = canonical_hash((declaration_layers=declaration_layers,
            child_kinds=child_kinds, feedback_ids=feedback_ids,
            declaration_count=3, child_count=3, feedback_count=N,
            component_count=3))
        new{N}(declaration_layers, child_kinds, feedback_ids, 3, 3, N, 3,
            count_hash)
    end
end
semantic_view(x::VNextT1ComponentCountReceiptV1) = (
    declaration_layers=x.declaration_layers, child_kinds=x.child_kinds,
    feedback_ids=x.feedback_ids, declaration_count=x.declaration_count,
    child_count=x.child_count, feedback_count=x.feedback_count,
    component_count=x.component_count, count_hash=x.count_hash)

struct VNextT1ComponentIdentityV1{N}
    semantic_identity::Digest256
    layer_contracts::NTuple{3,VNextT1LayerContractIdentityV1}
    source_hashes::NTuple{3,Digest256}
    declaration_hashes::NTuple{3,Digest256}
    axis_hashes::NTuple{3,NTuple{4,Digest256}}
    child_identity_hashes::NTuple{3,Digest256}
    feedback_hashes::NTuple{N,Digest256}
    count_receipt::VNextT1ComponentCountReceiptV1{N}
end
semantic_view(x::VNextT1ComponentIdentityV1) = (
    semantic_identity=x.semantic_identity, layer_contracts=x.layer_contracts,
    source_hashes=x.source_hashes, declaration_hashes=x.declaration_hashes,
    axis_hashes=x.axis_hashes, child_identity_hashes=x.child_identity_hashes,
    feedback_hashes=x.feedback_hashes, count_receipt=x.count_receipt)

"""The exact checked-present T0 result accepted by T1."""
const VNextT1ExpectedRecheckV1 =
    VNextAuthorityRecheckLocalResultV1{VNextAuthorityRecheckLocalCheckedPresentV1}

"""Closed public-input boundary for all executable V1 recheck outcomes.

`VNextT1ExpectedRecheckV1` remains the checked-present package input.  The two
additional variants may cross the public admission boundary only so that the
existing fail-closed policy can reject an honest typed absence or a concrete
recheck failure without a constructor `MethodError`.
"""
const VNextT1AdmissionRecheckInputV1 = Union{
    VNextT1ExpectedRecheckV1,
    VNextAuthorityRecheckLocalResultV1{VNextAuthorityRecheckLocalTypedAbsentV1},
    VNextAuthorityRecheckLocalResultV1{Nothing}}

struct VNextT1T0OutputIdentityV1{N}
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    declaration_identity_hashes::NTuple{3,Digest256}
    child_identity_hashes::NTuple{3,Digest256}
    feedback_hashes::NTuple{N,Digest256}
    output_hash::Digest256
end
semantic_view(x::VNextT1T0OutputIdentityV1) = (
    candidate_ref=x.candidate_ref, bundle_hash=x.bundle_hash,
    declaration_identity_hashes=x.declaration_identity_hashes,
    child_identity_hashes=x.child_identity_hashes,
    feedback_hashes=x.feedback_hashes, output_hash=x.output_hash)

"""Closed canonical projection of the checked T0 output envelope."""
struct VNextT1T0OutputProjectionV1{N}
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    declarations::NTuple{3,VNextT1DeclarationRecordV1}
    children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1}
    feedback::NTuple{N,VNextT1FeedbackRecordV1}
end
semantic_view(x::VNextT1T0OutputProjectionV1) = (
    candidate_ref=x.candidate_ref, bundle_hash=x.bundle_hash,
    declarations=x.declarations, children=x.children, feedback=x.feedback)

struct VNextT1T0GateV1{B,O,F}
    prior_bundle::VNextT1PriorBundleSnapshotV1{B}
    candidate_ref::QualifiedRefV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    output_projection::VNextT1T0OutputProjectionV1{F}
    output_bytes::VNextT1CanonicalBytesV1{O}
    output_identity::VNextT1T0OutputIdentityV1{F}
    output_hash::Digest256
    @noinline Base.@nospecializeinfer function VNextT1T0GateV1(@nospecialize(prior_bundle::VNextT1PriorBundleSnapshotV1),
            candidate_ref::QualifiedRefV1, status::Symbol, resolution::Symbol,
            accepted::Bool, claim_ceiling::Symbol,
            output_projection::VNextT1T0OutputProjectionV1{F},
            @nospecialize(output_bytes::VNextT1CanonicalBytesV1),
            output_identity::VNextT1T0OutputIdentityV1{F},
            output_hash::Digest256) where {F}
        candidate_ref.version == "v5" ||
            throw(ArgumentError("T1 gate candidate must carry v5 version"))
        status === :local_checked_present ||
            throw(ArgumentError("T1 requires local_checked_present"))
        resolution === :resolved ||
            throw(ArgumentError("T1 requires resolved T0 recheck"))
        accepted == false ||
            throw(ArgumentError("T0 accepted=true is not a T1 input"))
        claim_ceiling === :contract_only ||
            throw(ArgumentError("T0 claim ceiling must be contract_only"))
        output_identity.output_hash == output_hash ||
            throw(ArgumentError("T0 output identity/hash mismatch"))
        projection_bytes = Tuple(Vector{UInt8}(codeunits(canonical_json(output_projection))))
        output_bytes.bytes == projection_bytes ||
            throw(ArgumentError("T0 output projection bytes mismatch"))
        output_bytes.sha256 == _vnext_t1_sha(projection_bytes) ||
            throw(ArgumentError("T0 output bytes/hash mismatch"))
        output_hash == canonical_hash(output_projection) ||
            throw(ArgumentError("T0 output projection hash mismatch"))
        new{length(prior_bundle.canonical_bytes.bytes),length(output_bytes.bytes),F}(prior_bundle, candidate_ref, status, resolution, accepted,
            claim_ceiling, output_projection, output_bytes, output_identity,
            output_hash)
    end
end
semantic_view(x::VNextT1T0GateV1) = (
    prior_bundle=x.prior_bundle, candidate_ref=x.candidate_ref,
    status=x.status, resolution=x.resolution, accepted=x.accepted,
    claim_ceiling=x.claim_ceiling, output_projection=x.output_projection,
    output_bytes=x.output_bytes,
    output_identity=x.output_identity, output_hash=x.output_hash)

"""Candidate-bound, non-executed T1 package. All fields are closed types."""
struct CandidateStatePackageV5Next{N,M,K}
    candidate_ref::QualifiedRefV1
    declarations::NTuple{3,VNextT1DeclarationRecordV1}
    children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1}
    axes::NTuple{3,NTuple{4,QualifiedRefV1}}
    feedback::NTuple{N,VNextT1FeedbackRecordV1}
    source_hashes::NTuple{3,Digest256}
    declaration_hashes::NTuple{3,Digest256}
    layer_contracts::NTuple{3,VNextT1LayerContractIdentityV1}
    schema_hashes::NTuple{3,Digest256}
    canonicalization_hashes::NTuple{3,Digest256}
    profile_hashes::NTuple{3,Digest256}
    component_identity::VNextT1ComponentIdentityV1{N}
    component_count_receipt::VNextT1ComponentCountReceiptV1{N}
    semantic_identity::Digest256
    no_legacy_receipt::VNextT1NoLegacyReceiptV1
    t0_gate::VNextT1T0GateV1{M,K,N}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    package_schema_version::String
    package_schema_hash::Digest256
    package_canonicalization_version::String
    package_canonicalization_hash::Digest256
    package_profile_version::String
    package_profile_hash::Digest256
    package_hash::Digest256
end

# This closed V1 family contains only recursively immutable value fields.
# Sharing preserves deepcopy value semantics; no mutable payload can alias.
# See the generic closure/native-copy/canonical parity evidence in R22/R22b.
@noinline Base.@nospecializeinfer function Base.deepcopy_internal(
        @nospecialize(x::CandidateStatePackageV5Next), stackdict::IdDict)
    x
end

semantic_view(x::CandidateStatePackageV5Next) = (
    schema=VNEXT_T1_PACKAGE_SCHEMA_ID_V1,
    schema_version=VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1,
    candidate_ref=x.candidate_ref, declarations=x.declarations,
    children=x.children, axes=x.axes, feedback=x.feedback,
    source_hashes=x.source_hashes, declaration_hashes=x.declaration_hashes,
    layer_contracts=x.layer_contracts, component_identity=x.component_identity,
    schema_hashes=x.schema_hashes,
    canonicalization_hashes=x.canonicalization_hashes,
    profile_hashes=x.profile_hashes,
    component_count_receipt=x.component_count_receipt,
    semantic_identity=x.semantic_identity, no_legacy_receipt=x.no_legacy_receipt,
    t0_gate=x.t0_gate, status=x.status, resolution=x.resolution,
    accepted=x.accepted, claim_ceiling=x.claim_ceiling,
    package_schema_version=x.package_schema_version,
    package_schema_hash=x.package_schema_hash,
    package_canonicalization_version=x.package_canonicalization_version,
    package_canonicalization_hash=x.package_canonicalization_hash,
    package_profile_version=x.package_profile_version,
    package_profile_hash=x.package_profile_hash,
    package_hash=x.package_hash)

function _vnext_t1_validate_axes(axes::NTuple{4,QualifiedRefV1})
    Tuple(axis.id for axis in axes) == VNEXT_T1_AXIS_IDS_V1 ||
        throw(ArgumentError("T1 axis IDs/order mismatch"))
    all(axis.version == VNEXT_T1_AXIS_VERSION_V1 for axis in axes) ||
        throw(ArgumentError("T1 axis version mismatch"))
    length(unique(canonical_hash(axis).value for axis in axes)) == 4 ||
        throw(ArgumentError("T1 axes are not independent"))
    axes
end

function _vnext_t1_validate_bytes(bytes::VNextT0LocalBytesV1)
    bytes.sha256 == _vnext_t1_sha(bytes.bytes) ||
        throw(ArgumentError("T0 byte/hash join mismatch"))
    bytes
end
function _vnext_t1_validate_bytes(bytes::VNextT1CanonicalBytesV1)
    bytes.sha256 == _vnext_t1_sha(bytes.bytes) ||
        throw(ArgumentError("owned byte/hash join mismatch"))
    bytes
end

function _vnext_t1_expected_factory_identity(api::Symbol)
    api === :G1 && return (VNEXT_T1_G1_FACTORY_ID_V1, VNEXT_T1_FACTORY_VERSION_V1)
    api === :G2 && return (VNEXT_T1_G2_FACTORY_ID_V1, VNEXT_T1_FACTORY_VERSION_V1)
    api === :G3 && return (VNEXT_T1_G3_FACTORY_ID_V1, VNEXT_T1_FACTORY_VERSION_V1)
    api === :G3_FEEDBACK &&
        return (VNEXT_T1_G3_FEEDBACK_FACTORY_ID_V1, VNEXT_T1_FACTORY_VERSION_V1)
    throw(ArgumentError("unknown factory API"))
end

function _vnext_t1_g2_source(declaration::VNextT0LocalPresentDeclarationV1)
    declaration.layer === :G2 || return nothing
    body = declaration.semantic_body.body
    body isa NamedTuple && hasproperty(body, :source) &&
        hasproperty(body, :contract_ref) ||
        throw(ArgumentError("G2 semantic body lacks typed source contract"))
    source = body.source
    source isa G2MBSourceV1 ||
        throw(ArgumentError("G2 semantic body source is not G2MBSourceV1"))
    source.candidate_ref == body.contract_ref ||
        throw(ArgumentError("G2 source candidate contract mismatch"))
    rebuilt = g2mb_declaration_v1(body.contract_ref, source)
    rebuilt.schema_hash == body.schema_hash &&
        rebuilt.canonicalization_hash == body.canonicalization_hash &&
        rebuilt.profile_hash == body.profile_hash &&
        rebuilt.declaration_hash == body.declaration_hash ||
        throw(ArgumentError("G2 typed source declaration metadata mismatch"))
    source
end

function _vnext_t1_expected_contract_ref(layer::Symbol, api::Symbol,
        g2_source::Union{Nothing,G2MBSourceV1}=nothing,
        g1_declaration::Union{Nothing,VNextT0LocalPresentDeclarationV1}=nothing)
    if layer === :G1 && api === :G1
        if g1_declaration !== nothing &&
                g1_declaration.layer === :G1 &&
                hasproperty(g1_declaration.semantic_body.body, :source_payload)
            body = g1_declaration.semantic_body.body
            payload = body.source_payload
            if payload isa G1DiffusionSourcePayloadV1 &&
                    payload.interface_flux_pair !== nothing
                hasproperty(body, :source_hash) &&
                    payload.candidate_ref == g1_declaration.candidate_ref &&
                    payload.source_ref == g1_declaration.source_ref &&
                    payload.source_version == body.source_version ||
                    throw(ArgumentError("G1 source payload identity differs from its declaration"))
                g1_diffusion_source_hash_v1(payload) == body.source_hash ||
                    throw(ArgumentError("G1 semantic body source payload hash mismatch"))
                return _g1sf_expected_contract(payload)
            end
        end
        return VNEXT_T1_FROZEN_G1_CONTRACT_REF_V1
    end
    if layer === :G2 && api === :G2
        g2_source === nothing && return VNEXT_T1_FROZEN_G2_CONTRACT_REF_V1
        expected = _g2sf_expected_contract(g2_source)
        g2_source.candidate_ref == expected ||
            throw(ArgumentError("G2 source contract is not source-shape bound"))
        return expected
    end
    layer === :G3 && api === :G3 && return VNEXT_T1_FROZEN_G3_CONTRACT_REF_V1
    layer === :G3 && api === :G3_FEEDBACK &&
        return VNEXT_T1_FROZEN_G3_FEEDBACK_CONTRACT_REF_V1
    throw(ArgumentError("factory API/layer contract pair is not frozen"))
end
function _vnext_t1_expected_child_contract_ref(kind::Symbol)
    kind === :realization && return VNEXT_T1_FROZEN_G3_REALIZATION_CONTRACT_REF_V1
    kind === :control && return VNEXT_T1_FROZEN_G3_CONTROL_CONTRACT_REF_V1
    kind === :binding && return VNEXT_T1_FROZEN_G3_BINDING_CONTRACT_REF_V1
    throw(ArgumentError("unknown G3 child contract kind"))
end

function _vnext_t1_validate_locator(locator::VNextT0LocalSourceLocatorV1,
        candidate_source::QualifiedRefV1, bytes::VNextT0LocalBytesV1)
    locator.source_ref == candidate_source ||
        throw(ArgumentError("source locator/ref mismatch"))
    locator.source_uri == candidate_source.id ||
        throw(ArgumentError("source locator URI mismatch"))
    locator.source_size == length(bytes.bytes) ||
        throw(ArgumentError("source locator size mismatch"))
    locator.source_sha256 == bytes.sha256 ||
        throw(ArgumentError("source locator/hash mismatch"))
    locator
end

function _vnext_t1_validate_feedback_order(items::Tuple)
    all(item -> item isa VNextT0LocalFeedbackV1, items) ||
        throw(ArgumentError("feedback type mismatch"))
    ids = Tuple(item.target_id for item in items)
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("feedback target IDs must be unique"))
    canonical = Tuple(sort!(collect(items), by=item -> item.target_id))
    items == canonical || throw(ArgumentError("feedback canonical order mismatch"))
    items
end

function _vnext_t1_validate_factory_result(result::VNextT0LocalFactoryResultV1,
        declaration::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1, axes::NTuple{4,QualifiedRefV1})
    expected_factory_id, expected_factory_version =
        _vnext_t1_expected_factory_identity(result.factory_api)
    result.factory_id == expected_factory_id ||
        throw(ArgumentError("factory result factory ID mismatch"))
    result.factory_version == expected_factory_version ||
        throw(ArgumentError("factory result factory version mismatch"))
    result.candidate_ref == candidate || throw(ArgumentError("factory result candidate mismatch"))
    result.layer == declaration.layer || throw(ArgumentError("factory result layer mismatch"))
    result.source_ref == declaration.source_ref || throw(ArgumentError("factory result source ref mismatch"))
    result.declaration_ref == declaration.declaration_ref ||
        throw(ArgumentError("factory result declaration ref mismatch"))
    result.status === :present || throw(ArgumentError("factory result status mismatch"))
    result.source_bytes == declaration.source_bytes ||
        throw(ArgumentError("factory result source bytes mismatch"))
    result.source_size == length(declaration.source_bytes.bytes) ||
        throw(ArgumentError("factory result source size mismatch"))
    result.locator == declaration.source_locator ||
        throw(ArgumentError("factory result locator mismatch"))
    result.locator_provenance == declaration.source_locator.provenance ||
        throw(ArgumentError("factory result locator provenance mismatch"))
    (result.declaration_bytes.bytes == declaration.declaration_bytes.bytes &&
        result.declaration_bytes.sha256 == declaration.declaration_bytes.sha256) ||
        throw(ArgumentError("factory result declaration bytes mismatch"))
    result.declaration_hash == declaration.declaration_bytes.sha256 ||
        throw(ArgumentError("factory result declaration hash mismatch"))
    g2_source = _vnext_t1_g2_source(declaration)
    result.contract_ref == _vnext_t1_expected_contract_ref(
        declaration.layer, result.factory_api, g2_source, declaration) ||
        throw(ArgumentError("factory result contract is not frozen"))
    result.contract_ref == declaration.factory_receipt.factory_result.contract_ref ||
        throw(ArgumentError("factory result contract mismatch"))
    result.axes == _vnext_t1_expected_factory_axes(result) ||
        throw(ArgumentError("factory result layer axes mismatch"))
    result.upstream_receipt_hash == _vnext_t1_sha(result.upstream_receipt_bytes.bytes) ||
        throw(ArgumentError("factory upstream receipt hash mismatch"))
    result.content_identity == canonical_hash((factory_id=result.factory_id,
        factory_version=result.factory_version, factory_api=result.factory_api,
        candidate_ref=result.candidate_ref, layer=result.layer,
        source_ref=result.source_ref, source_bytes=result.source_bytes,
        source_size=result.source_size, locator=result.locator,
        locator_provenance=result.locator_provenance,
        declaration_ref=result.declaration_ref,
        declaration_bytes=result.declaration_bytes,
        declaration_hash=result.declaration_hash, status=result.status,
        contract_ref=result.contract_ref, axes=result.axes,
        upstream_receipt_bytes=result.upstream_receipt_bytes,
        upstream_receipt_hash=result.upstream_receipt_hash)) ||
        throw(ArgumentError("factory result content identity mismatch"))
    result
end

function _vnext_t1_expected_factory_axes(result::VNextT0LocalFactoryResultV1)
    result.factory_api === :G1 && return (
        QualifiedRefV1("fusion.g1.payload-schema", "v2"),
        QualifiedRefV1("fusion.g1.canonicalization", "v2"),
        QualifiedRefV1("fusion.g1.applicability", "v2"),
        QualifiedRefV1("fusion.g1.receipt", "v2"))
    result.factory_api === :G2 && return (
        QualifiedRefV1("fusion.g2.payload-schema", "v5"),
        QualifiedRefV1("fusion.g2.canonicalization", "v5"),
        QualifiedRefV1("fusion.g2.applicability", "v5"),
        QualifiedRefV1("fusion.g2.receipt", "v5"))
    result.factory_api === :G3_FEEDBACK && return VNEXT_T0_G3_FEEDBACK_AXES_V1
    result.factory_api === :G3 || throw(ArgumentError("unknown factory API"))
    isdefined(@__MODULE__, :g3_version_axes) ||
        throw(ArgumentError("G3 version axes provider unavailable"))
    g3_axes = g3_version_axes(:realization)
    (g3_axes.payload_schema_version, g3_axes.canonicalization_profile_version,
        g3_axes.applicability_profile_version, g3_axes.evidence_receipt_version)
end

function _vnext_t1_validate_receipt_envelope(receipt_bytes::VNextT0LocalBytesV1,
        result::VNextT0LocalFactoryResultV1)
    envelope_bytes = Vector{UInt8}(codeunits(canonical_json(result)))
    receipt_bytes.bytes == envelope_bytes ||
        throw(ArgumentError("receipt bytes do not equal canonical result envelope"))
    receipt_bytes.sha256 == _vnext_t1_sha(envelope_bytes) ||
        throw(ArgumentError("receipt envelope hash mismatch"))
    nothing
end

function _vnext_t1_validate_receipt(receipt::VNextT0LocalFactoryReceiptV1,
        declaration::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1, axes::NTuple{4,QualifiedRefV1})
    _vnext_t1_validate_bytes(receipt.bytes)
    receipt.candidate_ref == candidate || throw(ArgumentError("factory receipt candidate mismatch"))
    receipt.layer == declaration.layer || throw(ArgumentError("factory receipt layer mismatch"))
    receipt.source_ref == declaration.source_ref || throw(ArgumentError("factory receipt source mismatch"))
    receipt.declaration_ref == declaration.declaration_ref ||
        throw(ArgumentError("factory receipt declaration mismatch"))
    receipt.axes == axes || throw(ArgumentError("factory receipt axes mismatch"))
    receipt.status === :present || throw(ArgumentError("factory receipt status mismatch"))
    receipt.factory_axes == receipt.factory_result.axes ||
        throw(ArgumentError("factory receipt result axes mismatch"))
    receipt.factory_result_hash == canonical_hash(receipt.factory_result) ||
        throw(ArgumentError("factory receipt result hash mismatch"))
    _vnext_t1_validate_receipt_envelope(receipt.bytes, receipt.factory_result)
    _vnext_t1_validate_factory_result(receipt.factory_result, declaration,
        candidate, axes)
    receipt
end

function _vnext_t1_validate_receipt(receipt::VNextT0LocalDeclarationReceiptV1,
        declaration::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1, axes::NTuple{4,QualifiedRefV1})
    _vnext_t1_validate_bytes(receipt.bytes)
    receipt.candidate_ref == candidate || throw(ArgumentError("declaration receipt candidate mismatch"))
    receipt.layer == declaration.layer || throw(ArgumentError("declaration receipt layer mismatch"))
    receipt.source_ref == declaration.source_ref || throw(ArgumentError("declaration receipt source mismatch"))
    receipt.declaration_ref == declaration.declaration_ref ||
        throw(ArgumentError("declaration receipt declaration mismatch"))
    receipt.axes == axes || throw(ArgumentError("declaration receipt axes mismatch"))
    receipt.status === :present || throw(ArgumentError("declaration receipt status mismatch"))
    receipt.factory_axes == receipt.factory_result.axes ||
        throw(ArgumentError("declaration receipt result axes mismatch"))
    receipt.factory_result_hash == canonical_hash(receipt.factory_result) ||
        throw(ArgumentError("declaration receipt result hash mismatch"))
    _vnext_t1_validate_receipt_envelope(receipt.bytes, receipt.factory_result)
    _vnext_t1_validate_factory_result(receipt.factory_result, declaration,
        candidate, axes)
    receipt
end

function _vnext_t1_receipt_projection(receipt::VNextT0LocalFactoryReceiptV1,
        kind::Symbol)
    VNextT1ReceiptProjectionV1(kind, _vnext_t1_owned_bytes(receipt.bytes), receipt.candidate_ref,
        receipt.layer, receipt.source_ref, receipt.declaration_ref, receipt.axes,
        receipt.factory_axes, receipt.status, receipt.factory_api,
        receipt.factory_result_hash)
end
function _vnext_t1_receipt_projection(receipt::VNextT0LocalDeclarationReceiptV1,
        kind::Symbol)
    VNextT1ReceiptProjectionV1(kind, _vnext_t1_owned_bytes(receipt.bytes), receipt.candidate_ref,
        receipt.layer, receipt.source_ref, receipt.declaration_ref, receipt.axes,
        receipt.factory_axes, receipt.status, receipt.factory_api,
        receipt.factory_result_hash)
end

function _vnext_t1_declaration_record(d::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1)
    d.candidate_ref == candidate || throw(ArgumentError("declaration candidate mismatch"))
    d.layer in VNEXT_T1_REQUIRED_LAYERS_V1 || throw(ArgumentError("declaration layer invalid"))
    _vnext_t1_validate_axes(d.axes)
    _vnext_t1_validate_bytes(d.source_bytes)
    _vnext_t1_validate_bytes(d.declaration_bytes)
    _vnext_t1_validate_bytes(d.semantic_body.bytes)
    semantic_body_bytes = Vector{UInt8}(codeunits(canonical_json(d.semantic_body.body)))
    semantic_body_bytes == d.semantic_body.bytes.bytes ||
        throw(ArgumentError("semantic body bytes mismatch"))
    _vnext_t1_validate_locator(d.source_locator, d.source_ref, d.source_bytes)
    d.source_identity_hash == canonical_hash((kind=:source, ref=d.source_ref,
        bytes_sha256=d.source_bytes.sha256)) ||
        throw(ArgumentError("source identity hash mismatch"))
    d.declaration_identity_hash == canonical_hash((kind=:declaration,
        ref=d.declaration_ref, bytes_sha256=d.declaration_bytes.sha256)) ||
        throw(ArgumentError("declaration identity hash mismatch"))
    expected_factory_api = d.layer === :G1 ? (:G1,) :
        d.layer === :G2 ? (:G2,) : (:G3, :G3_FEEDBACK)
    d.factory_receipt.factory_result.factory_api in expected_factory_api ||
        throw(ArgumentError("declaration factory API/layer mismatch"))
    _vnext_t1_validate_receipt(d.factory_receipt, d, candidate, d.axes)
    _vnext_t1_validate_receipt(d.declaration_receipt, d, candidate, d.axes)
    contract_ref = d.factory_receipt.factory_result.contract_ref
    g2_source = _vnext_t1_g2_source(d)
    contract_ref == _vnext_t1_expected_contract_ref(
        d.layer, d.factory_receipt.factory_result.factory_api, g2_source, d) ||
        throw(ArgumentError("declaration contract is not frozen"))
    d.declaration_receipt.factory_result.contract_ref == contract_ref ||
        throw(ArgumentError("declaration/factory contract ref mismatch"))
    VNextT1DeclarationRecordV1(d.layer, candidate, d.source_ref,
        d.declaration_ref, d.source_identity_hash, d.declaration_identity_hash,
        d.axes, _vnext_t1_owned_bytes(d.source_bytes),
        _vnext_t1_owned_bytes(d.declaration_bytes),
        _vnext_t1_owned_bytes(d.semantic_body.bytes),
        d.source_locator, _vnext_t1_receipt_projection(d.factory_receipt, :factory),
        _vnext_t1_receipt_projection(d.declaration_receipt, :declaration),
        VNextT1LayerContractIdentityV1(d.layer, contract_ref))
end

function _vnext_t1_child_record(child::VNextT0LocalChildPresentV1,
        candidate::QualifiedRefV1, expected_kind::Symbol)
    child.kind === expected_kind || throw(ArgumentError("present child kind mismatch"))
    child.candidate_ref == candidate || throw(ArgumentError("present child candidate mismatch"))
    child.layer === :G3 || throw(ArgumentError("present child layer mismatch"))
    child.child_id == String(expected_kind) || throw(ArgumentError("present child id mismatch"))
    isempty(child.child_ref.id) && throw(ArgumentError("present child ref missing"))
    _vnext_t1_validate_bytes(child.source_bytes)
    _vnext_t1_validate_locator(child.source_locator, child.source_ref, child.source_bytes)
    _vnext_t1_validate_present_child_body(child.body, child, candidate)
    child.body_hash == canonical_hash(child.body) ||
        throw(ArgumentError("present child body hash mismatch"))
    expected_identity = canonical_hash((candidate_ref=child.candidate_ref,
        layer=child.layer, child_id=child.child_id, kind=child.kind,
        child_ref=child.child_ref, body_hash=child.body_hash,
        source_ref=child.source_ref, source_sha256=child.source_bytes.sha256))
    child.child_identity_hash == expected_identity ||
        throw(ArgumentError("present child identity hash mismatch"))
    VNextT1PresentChildRecordV1(child.kind, candidate, child.layer,
        child.child_id, child.child_ref, child.source_ref,
        _vnext_t1_owned_bytes(child.source_bytes),
        child.source_locator, child.body_hash, child.child_identity_hash)
end

"""Validate closed joins exposed by a present child envelope when present."""
function _vnext_t1_validate_present_child_body(body, child::VNextT0LocalChildPresentV1,
        candidate::QualifiedRefV1)
    hasproperty(body, :kind) || throw(ArgumentError("child envelope kind missing"))
    body.kind == child.kind || throw(ArgumentError("child envelope kind mismatch"))
    hasproperty(body, :source_ref) || throw(ArgumentError("child envelope source missing"))
    body.source_ref == child.source_ref || throw(ArgumentError("child envelope source mismatch"))
    hasproperty(body, :source_sha256) ||
        throw(ArgumentError("child envelope source hash missing"))
    body.source_sha256 == child.source_bytes.sha256 ||
        throw(ArgumentError("child envelope source hash mismatch"))
    if hasproperty(body, :contract_ref)
        body.contract_ref == _vnext_t1_expected_child_contract_ref(child.kind) ||
            throw(ArgumentError("child envelope frozen contract mismatch"))
    end
    for (field, expected) in ((:candidate_ref, candidate), (:child_ref, child.child_ref),
            (:declaration_ref, nothing))
        if hasproperty(body, field)
            actual = getproperty(body, field)
            expected === nothing || actual == expected ||
                throw(ArgumentError("child envelope $field mismatch"))
            actual isa QualifiedRefV1 ||
                throw(ArgumentError("child envelope $field is not typed"))
        end
    end
    nothing
end

function _vnext_t1_child_record(child::VNextT0LocalChildAbsentV1,
        candidate::QualifiedRefV1, expected_kind::Symbol)
    child.kind === expected_kind || throw(ArgumentError("absent child kind mismatch"))
    child.candidate_ref == candidate || throw(ArgumentError("absent child candidate mismatch"))
    child.layer === :G3 || throw(ArgumentError("absent child layer mismatch"))
    child.child_id == String(expected_kind) || throw(ArgumentError("absent child id mismatch"))
    child.status in (:terminal_deferred, :typed_absent) ||
        throw(ArgumentError("absent child status invalid"))
    isempty(child.reason) && throw(ArgumentError("absent child reason missing"))
    child.candidate_identity_created == false ||
        throw(ArgumentError("absent child created candidate identity"))
    child.factory_api === :G3 || throw(ArgumentError("absent child factory API mismatch"))
    _vnext_t1_validate_bytes(child.factory_receipt_bytes)
    child.factory_receipt_hash == child.factory_receipt_bytes.sha256 ||
        throw(ArgumentError("absent child receipt hash mismatch"))
    isempty(child.source_path) && throw(ArgumentError("absent child source path missing"))
    isempty(child.factory_receipt_bytes.bytes) &&
        throw(ArgumentError("absent child receipt envelope missing"))
    _vnext_t1_validate_absent_child_envelope(child, candidate, expected_kind)
    VNextT1AbsentChildRecordV1(child.kind, candidate, child.layer, child.child_id,
        child.status, child.reason, child.candidate_identity_created,
        child.factory_api, _vnext_t1_owned_bytes(child.factory_receipt_bytes),
        child.factory_receipt_hash, child.source_path)
end

"""The absent path has no child identity; retain only typed envelope joins."""
function _vnext_t1_validate_absent_child_envelope(child::VNextT0LocalChildAbsentV1,
        candidate::QualifiedRefV1, expected_kind::Symbol)
    child.candidate_ref == candidate || throw(ArgumentError("absent envelope candidate mismatch"))
    child.kind === expected_kind || throw(ArgumentError("absent envelope kind mismatch"))
    child.factory_api === :G3 || throw(ArgumentError("absent envelope factory mismatch"))
    child.factory_receipt_hash == _vnext_t1_sha(child.factory_receipt_bytes.bytes) ||
        throw(ArgumentError("absent envelope hash mismatch"))
    child.source_path isa String && isvalid(child.source_path) ||
        throw(ArgumentError("absent envelope source path invalid"))
    nothing
end

function _vnext_t1_feedback_record(item::VNextT0LocalFeedbackV1,
        declarations::NTuple{3,VNextT0LocalPresentDeclarationV1},
        candidate::QualifiedRefV1)
    item.candidate_ref == candidate || throw(ArgumentError("feedback candidate mismatch"))
    item.target_layer in (:G1, :G2) || throw(ArgumentError("feedback target layer invalid"))
    target_index = findfirst(d -> d.layer === item.target_layer, declarations)
    target_index === nothing && throw(ArgumentError("feedback target declaration missing"))
    target = declarations[target_index]
    item.target_ref == target.source_ref || item.target_ref == target.declaration_ref ||
        throw(ArgumentError("feedback target ref mismatch"))
    _vnext_t1_feedback_body_join(item.body, item, target, candidate)
    item.body_hash == canonical_hash(item.body) ||
        throw(ArgumentError("feedback body hash mismatch"))
    VNextT1FeedbackRecordV1(item.target_id, item.target_layer, candidate,
        item.target_ref, target.declaration_ref, target.declaration_identity_hash,
        canonical_hash(target.semantic_body.body), item.body_hash)
end

function _vnext_t1_feedback_body_join(body::T, item::VNextT0LocalFeedbackV1,
        target::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1) where {T}
    hasproperty(body, :candidate_ref) ||
        throw(ArgumentError("feedback body candidate ref missing"))
    hasproperty(body, :source_ref) ||
        throw(ArgumentError("feedback body source ref missing"))
    body.candidate_ref == candidate || throw(ArgumentError("feedback body candidate mismatch"))
    body.source_ref == target.source_ref || throw(ArgumentError("feedback body source mismatch"))
    if hasproperty(body, :declaration_ref)
        body.declaration_ref == target.declaration_ref ||
            throw(ArgumentError("feedback body declaration mismatch"))
    end
    if hasproperty(body, :target_ref)
        body.target_ref == item.target_ref ||
            throw(ArgumentError("feedback body target ref mismatch"))
    end
    hasproperty(body, :feedback_targets) ||
        throw(ArgumentError("feedback body feedback targets missing"))
    target_matches = filter(x -> hasproperty(x, :target_id) &&
        x.target_id == item.target_id, body.feedback_targets)
    length(target_matches) == 1 ||
        throw(ArgumentError("feedback body target ID is not unique"))
    body_target = first(target_matches)
    hasproperty(body_target, :target_layer) &&
        body_target.target_layer == item.target_layer ||
        throw(ArgumentError("feedback body target layer mismatch"))
    hasproperty(body_target, :authority) ||
        throw(ArgumentError("feedback body target authority missing"))
    authority = body_target.authority
    authority.candidate_ref == candidate ||
        throw(ArgumentError("feedback body authority candidate mismatch"))
    if hasproperty(authority, :source_ref) && authority.source_ref !== nothing
        authority.source_ref == target.source_ref ||
            throw(ArgumentError("feedback body authority source mismatch"))
    end
    nothing
end

function _vnext_t1_child_identity(child::VNextT1PresentChildRecordV1)
    VNextT1ChildIdentityV1(child.kind, child.candidate_ref, child.layer,
        child.child_id, :present, "", false, :none, nothing,
        child.source_locator.source_path, child.body_hash,
        child.child_identity_hash, child.source_ref, child.source_bytes.sha256)
end
function _vnext_t1_child_identity(child::VNextT1AbsentChildRecordV1)
    VNextT1ChildIdentityV1(child.kind, child.candidate_ref, child.layer,
        child.child_id, child.status, child.reason,
        child.candidate_identity_created, child.factory_api,
        child.factory_receipt_hash, child.source_path, nothing, nothing,
        nothing, nothing)
end

function _vnext_t1_label_erased_identity(candidate::QualifiedRefV1,
        declarations::NTuple{3,VNextT1DeclarationRecordV1},
        children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1},
        axes::NTuple{3,NTuple{4,QualifiedRefV1}},
        feedback::NTuple{N,VNextT1FeedbackRecordV1},
        source_hashes::NTuple{3,Digest256},
        declaration_hashes::NTuple{3,Digest256}) where {N}
    declaration_identity = ntuple(i -> begin
        d = declarations[i]
        VNextT1DeclarationIdentityV1(d.layer, d.candidate_ref, d.source_ref,
            d.declaration_ref, d.source_identity_hash,
            d.declaration_identity_hash, d.axes, d.semantic_body_bytes)
    end, 3)
    child_identity = ntuple(i -> _vnext_t1_child_identity(children[i]), 3)
    VNextT1LabelErasedIdentityV1{N}(candidate, declaration_identity,
        child_identity, axes, feedback, source_hashes, declaration_hashes)
end

function _vnext_t1_component_identity(candidate::QualifiedRefV1,
        declarations::NTuple{3,VNextT1DeclarationRecordV1},
        children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1},
        axes::NTuple{3,NTuple{4,QualifiedRefV1}},
        feedback::NTuple{N,VNextT1FeedbackRecordV1},
        source_hashes::NTuple{3,Digest256},
        declaration_hashes::NTuple{3,Digest256},
        count::VNextT1ComponentCountReceiptV1{N}) where {N}
    identity = _vnext_t1_label_erased_identity(candidate, declarations, children,
        axes, feedback, source_hashes, declaration_hashes)
    axis_hashes = ntuple(i -> ntuple(j -> canonical_hash(axes[i][j]), 4), 3)
    child_hashes = ntuple(i -> children[i] isa VNextT1PresentChildRecordV1 ?
        children[i].child_identity_hash : children[i].factory_receipt_hash, 3)
    feedback_hashes = ntuple(i -> canonical_hash(feedback[i]), N)
    VNextT1ComponentIdentityV1{N}(canonical_hash(identity),
        ntuple(i -> declarations[i].contract_identity, 3), source_hashes,
        declaration_hashes, axis_hashes, child_hashes, feedback_hashes, count)
end

function _vnext_t1_package(candidate::QualifiedRefV1,
        declarations::NTuple{3,VNextT1DeclarationRecordV1},
        children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1},
        axes::NTuple{3,NTuple{4,QualifiedRefV1}},
    feedback::NTuple{N,VNextT1FeedbackRecordV1},
        source_hashes::NTuple{3,Digest256},
        declaration_hashes::NTuple{3,Digest256}, gate::VNextT1T0GateV1{M,K,N},
        no_legacy::VNextT1NoLegacyReceiptV1) where {N,M,K}
    axes == ntuple(i -> declarations[i].axes, 3) ||
        throw(ArgumentError("package/declaration axis join mismatch"))
    source_hashes == ntuple(i -> declarations[i].source_bytes.sha256, 3) ||
        throw(ArgumentError("package/source byte hash join mismatch"))
    declaration_hashes == ntuple(i -> declarations[i].declaration_bytes.sha256, 3) ||
        throw(ArgumentError("package/declaration byte hash join mismatch"))
    count = VNextT1ComponentCountReceiptV1(
        Tuple(d.layer for d in declarations),
        Tuple(c.kind for c in children), Tuple(f.target_id for f in feedback))
    identity = _vnext_t1_component_identity(candidate, declarations, children,
        axes, feedback, source_hashes, declaration_hashes, count)
    gate.output_identity.candidate_ref == candidate ||
        throw(ArgumentError("T0 output identity candidate mismatch"))
    gate.output_identity.bundle_hash == gate.prior_bundle.bundle_hash ||
        throw(ArgumentError("T0 output identity bundle mismatch"))
    gate.output_identity.declaration_identity_hashes ==
        ntuple(i -> declarations[i].declaration_identity_hash, 3) ||
        throw(ArgumentError("T0 output declaration identity mismatch"))
    gate.output_identity.child_identity_hashes == ntuple(i ->
        children[i] isa VNextT1PresentChildRecordV1 ?
            children[i].child_identity_hash : children[i].factory_receipt_hash, 3) ||
        throw(ArgumentError("T0 output child identity mismatch"))
    gate.output_identity.feedback_hashes == ntuple(i -> canonical_hash(feedback[i]), N) ||
        throw(ArgumentError("T0 output feedback identity mismatch"))
    identity.semantic_identity == canonical_hash(
        _vnext_t1_label_erased_identity(candidate, declarations, children,
            axes, feedback, source_hashes, declaration_hashes)) ||
        throw(ArgumentError("label-erased component identity mismatch"))
    _vnext_t1_validate_no_legacy_receipt(no_legacy, candidate)
    package_schema_version = VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1
    package_schema_hash = vnext_t1_package_schema_hash_v1()
    package_canonicalization_version = VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V1
    package_canonicalization_hash = vnext_t1_package_canonicalization_hash_v1()
    package_profile_version = VNEXT_T1_PACKAGE_PROFILE_VERSION_V1
    package_profile_hash = vnext_t1_package_profile_hash_v1()
    package_hash = canonical_hash((schema=VNEXT_T1_PACKAGE_SCHEMA_ID_V1,
        schema_version=package_schema_version, package_schema_hash=package_schema_hash,
        package_canonicalization_version=package_canonicalization_version,
        package_canonicalization_hash=package_canonicalization_hash,
        package_profile_version=package_profile_version,
        package_profile_hash=package_profile_hash,
        candidate_ref=candidate, declarations=declarations, children=children,
        axes=axes, feedback=feedback, source_hashes=source_hashes,
        declaration_hashes=declaration_hashes, layer_contracts=identity.layer_contracts,
        schema_hashes=ntuple(i -> identity.layer_contracts[i].schema_hash, 3),
        canonicalization_hashes=ntuple(i -> identity.layer_contracts[i].canonicalization_hash, 3),
        profile_hashes=ntuple(i -> identity.layer_contracts[i].compatibility_profile_hash, 3),
        component_identity=identity, component_count_receipt=count,
        semantic_identity=identity.semantic_identity,
        no_legacy_receipt=no_legacy, t0_gate=gate,
        prior_bundle=gate.prior_bundle, output_hash=gate.output_hash,
        status=:prepared_not_executed, resolution=:terminal_deferred,
        accepted=false, claim_ceiling=:contract_only))
    CandidateStatePackageV5Next{N,M,K}(candidate, declarations, children, axes,
        feedback, source_hashes, declaration_hashes, identity.layer_contracts,
        ntuple(i -> identity.layer_contracts[i].schema_hash, 3),
        ntuple(i -> identity.layer_contracts[i].canonicalization_hash, 3),
        ntuple(i -> identity.layer_contracts[i].compatibility_profile_hash, 3),
        identity, count, identity.semantic_identity, no_legacy, gate,
        :prepared_not_executed, :terminal_deferred, false, :contract_only,
        package_schema_version, package_schema_hash,
        package_canonicalization_version, package_canonicalization_hash,
        package_profile_version, package_profile_hash,
        package_hash)
end
