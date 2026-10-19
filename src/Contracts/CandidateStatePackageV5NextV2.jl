"""Digest-manifest T1 package successor.

V2 keeps the source/declaration/semantic/receipt bytes in the non-parameterized
carrier and hashes only a small manifest.  The package hash therefore never
walks a large raw payload.  This file is additive; no V1 package method is
extended or called here.
"""

const VNEXT_T1_PACKAGE_SCHEMA_ID_V2 = "GenomeV5/Contracts/CandidateStatePackageV5NextV2"
const VNEXT_T1_PACKAGE_SCHEMA_VERSION_V2 = "v2"
const VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V2 = "digest-manifest-wire-bound-v2"
const VNEXT_T1_PACKAGE_PROFILE_VERSION_V2 = "closed-no-legacy-digest-manifest-wire-bound-v2"
const VNEXT_T1_PACKAGE_CLAIM_CEILING_V2 = :contract_only

struct VNextT1DeclarationManifestV2
    layer::Symbol
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    axes::NTuple{4,QualifiedRefV1}
    source_bytes::VNextT1CanonicalBytesV2
    declaration_bytes::VNextT1CanonicalBytesV2
    semantic_body_bytes::VNextT1CanonicalBytesV2
    factory_receipt_bytes::VNextT1CanonicalBytesV2
    declaration_receipt_bytes::VNextT1CanonicalBytesV2
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
end

struct VNextT1ChildManifestV2
    kind::Symbol
    candidate_ref::QualifiedRefV1
    status::Symbol
    reason::Union{Nothing,String}
    child_ref::Union{Nothing,QualifiedRefV1}
    source_ref::Union{Nothing,QualifiedRefV1}
    source_bytes::Union{Nothing,VNextT1CanonicalBytesV2}
    body_hash::Union{Nothing,Digest256}
    child_identity_hash::Union{Nothing,Digest256}
    factory_receipt_bytes::Union{Nothing,VNextT1CanonicalBytesV2}
    factory_receipt_hash::Union{Nothing,Digest256}
end

struct VNextT1G3AuthorityManifestV2
    status::Symbol
    resolution::Symbol
    authority_verified::Bool
    commitment_hash::Digest256
    binding_state_hash::Union{Nothing,Digest256}
    child_state_hashes::Tuple{Vararg{Digest256}}
end

semantic_view(x::VNextT1DeclarationManifestV2) =
    (layer=x.layer, candidate_ref=x.candidate_ref, source_ref=x.source_ref,
        declaration_ref=x.declaration_ref, axes=x.axes,
        source_bytes=x.source_bytes, declaration_bytes=x.declaration_bytes,
        semantic_body_bytes=x.semantic_body_bytes,
        factory_receipt_bytes=x.factory_receipt_bytes,
        declaration_receipt_bytes=x.declaration_receipt_bytes,
        source_identity_hash=x.source_identity_hash,
        declaration_identity_hash=x.declaration_identity_hash)
semantic_view(x::VNextT1ChildManifestV2) =
    (kind=x.kind, candidate_ref=x.candidate_ref, status=x.status, reason=x.reason,
        child_ref=x.child_ref, source_ref=x.source_ref, source_bytes=x.source_bytes,
        body_hash=x.body_hash, child_identity_hash=x.child_identity_hash,
        factory_receipt_bytes=x.factory_receipt_bytes,
        factory_receipt_hash=x.factory_receipt_hash)
semantic_view(x::VNextT1G3AuthorityManifestV2) =
    (status=x.status, resolution=x.resolution, authority_verified=x.authority_verified,
        commitment_hash=x.commitment_hash, binding_state_hash=x.binding_state_hash,
        child_state_hashes=x.child_state_hashes)

struct CandidateStatePackageV5NextV2
    schema_id::String
    schema_version::String
    canonicalization_version::String
    profile_version::String
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    declarations::NTuple{3,VNextT1DeclarationManifestV2}
    children::NTuple{3,VNextT1ChildManifestV2}
    feedback::Tuple
    axes::NTuple{3,NTuple{4,QualifiedRefV1}}
    parent_commitments::NTuple{2,Digest256}
    g3_authority::VNextT1G3AuthorityManifestV2
    wire::VNextT1CanonicalBytesV2
    semantic_identity::Digest256
    package_hash::Digest256
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
end

_vnext_t1_v2_manifest_digest(x) = canonical_hash(x)
_vnext_t1_v2_wire(x) = VNextT1CanonicalBytesV2(collect(codeunits(canonical_json(x))))

function _vnext_t1_v2_declaration(d::VNextT0LocalPresentDeclarationV1)
    VNextT1DeclarationManifestV2(d.layer, d.candidate_ref, d.source_ref,
        d.declaration_ref, d.axes, VNextT1CanonicalBytesV2(d.source_bytes.bytes),
        VNextT1CanonicalBytesV2(d.declaration_bytes.bytes),
        VNextT1CanonicalBytesV2(d.semantic_body.bytes.bytes),
        VNextT1CanonicalBytesV2(d.factory_receipt.bytes.bytes),
        VNextT1CanonicalBytesV2(d.declaration_receipt.bytes.bytes),
        d.source_identity_hash, d.declaration_identity_hash)
end
function _vnext_t1_v2_declaration(d::VNextT0LocalAbsentDeclarationV1)
    z = VNextT1CanonicalBytesV2(UInt8[])
    VNextT1DeclarationManifestV2(d.layer, d.candidate_ref,
        QualifiedRefV1("local://absent/" * String(d.layer), "v1"),
        QualifiedRefV1("local://absent/" * String(d.layer), "v1"),
        (QualifiedRefV1("local://absent-axis", "v1"), QualifiedRefV1("local://absent-axis", "v1"),
         QualifiedRefV1("local://absent-axis", "v1"), QualifiedRefV1("local://absent-axis", "v1")),
        z, z, z, z, z,
        digest256_text("typed-absent-source"), digest256_text("typed-absent-declaration"))
end

function _vnext_t1_v2_child(c::VNextT0LocalChildPresentV1)
    VNextT1ChildManifestV2(c.kind, c.candidate_ref, :present, nothing, c.child_ref,
        c.source_ref, VNextT1CanonicalBytesV2(c.source_bytes.bytes), c.body_hash,
        c.child_identity_hash, nothing, nothing)
end
function _vnext_t1_v2_child(c::VNextT0LocalChildAbsentV1)
    VNextT1ChildManifestV2(c.kind, c.candidate_ref, c.status, c.reason, nothing, nothing,
        nothing, nothing, nothing, VNextT1CanonicalBytesV2(c.factory_receipt_bytes.bytes),
        c.factory_receipt_hash)
end

function _vnext_t1_v2_g3_authority(result)
    status = hasproperty(result, :status) ? result.status : :fail_closed
    resolution = hasproperty(result, :resolution) ? result.resolution : :none
    verified = hasproperty(result, :authority_verified) ? result.authority_verified : false
    state = hasproperty(result, :binding_state) ? result.binding_state : nothing
    commit = hasproperty(result, :commitment_hash) ? result.commitment_hash :
        (state === nothing ? digest256_text("g3-authority-absent") : canonical_hash(semantic_view(state)))
    state_hash = state === nothing ? nothing : getproperty(state, :state_hash)
    child_hashes = state === nothing ? () : Tuple(filter(x -> x isa Digest256,
        (getproperty(state.source_payload.realization_slot, :state_hash),
         getproperty(state.source_payload.control_slot, :state_hash))))
    VNextT1G3AuthorityManifestV2(status, resolution, verified, commit, state_hash, child_hashes)
end

function _vnext_t1_v2_identity_manifest(candidate, bundle_hash, declarations, children,
        feedback, axes, parents, g3, wire)
    (domain="candidate-state-package-v5-next-v2/semantic",
        schema=VNEXT_T1_PACKAGE_SCHEMA_ID_V2, version=VNEXT_T1_PACKAGE_SCHEMA_VERSION_V2,
        candidate_ref=candidate, bundle_hash=bundle_hash,
        declaration_identities=Tuple((d.layer, d.candidate_ref, d.source_ref,
            d.declaration_ref, d.source_bytes.sha256, d.declaration_bytes.sha256,
            d.semantic_body_bytes.sha256, d.factory_receipt_bytes.sha256,
            d.declaration_receipt_bytes.sha256, d.source_identity_hash,
            d.declaration_identity_hash) for d in declarations),
        child_identities=Tuple((c.kind, c.candidate_ref, c.status, c.child_ref,
            c.source_ref, c.source_bytes === nothing ? nothing : c.source_bytes.sha256,
            c.body_hash, c.child_identity_hash, c.factory_receipt_hash) for c in children),
        feedback_digest=canonical_hash(feedback), axes=axes,
        parent_commitments=parents, g3_authority=g3,
        wire_sha256=wire.sha256, wire_byte_length=length(copy_bytes(wire)))
end

function _vnext_t1_v2_package_manifest(package::CandidateStatePackageV5NextV2)
    (domain="candidate-state-package-v5-next-v2/package", schema=package.schema_id,
        version=package.schema_version, canonicalization=package.canonicalization_version,
        profile=package.profile_version, candidate_ref=package.candidate_ref,
        bundle_hash=package.bundle_hash, semantic_identity=package.semantic_identity,
        declaration_digests=Tuple((d.layer, d.source_bytes.sha256,
            d.declaration_bytes.sha256, d.semantic_body_bytes.sha256,
            d.factory_receipt_bytes.sha256, d.declaration_receipt_bytes.sha256) for d in package.declarations),
        child_digests=Tuple((c.kind, c.status, c.child_identity_hash,
            c.factory_receipt_hash) for c in package.children),
        feedback_digest=canonical_hash(package.feedback), axes=package.axes,
        parent_commitments=package.parent_commitments, g3_authority=package.g3_authority,
        wire_sha256=package.wire.sha256, wire_byte_length=length(copy_bytes(package.wire)),
        status=package.status, resolution=package.resolution, accepted=package.accepted,
        claim_ceiling=package.claim_ceiling)
end

function CandidateStatePackageV5NextV2(candidate::QualifiedRefV1,
        transport::VNextT0LocalTransportV1, recheck::VNextAuthorityRecheckLocalV2Result,
        parent_commitments::NTuple{2,Digest256}, g3_authority,
        g3_expected_commitment::Digest256)
    candidate.version == "v5" || throw(ArgumentError("candidate version invalid"))
    transport.candidate_ref == candidate || throw(ArgumentError("transport candidate mismatch"))
    transport.status === :valid || throw(ArgumentError("transport status invalid"))
    isempty(transport.errors) || throw(ArgumentError("transport errors present"))
    canonical_hash(_vnext_ar_v2_bundle_body(transport)) == transport.bundle_hash ||
        throw(ArgumentError("transport bundle hash mismatch"))
    recheck.status === :local_checked_present ||
        throw(ArgumentError("recheck status is not local_checked_present"))
    recheck.resolution === :resolved || throw(ArgumentError("recheck is not resolved"))
    recheck.accepted === false || throw(ArgumentError("recheck accepted=true"))
    recheck.claim_ceiling === :contract_only || throw(ArgumentError("recheck claim ceiling invalid"))
    isempty(recheck.errors) || throw(ArgumentError("recheck errors present"))
    isempty(recheck.reasons) || throw(ArgumentError("recheck reasons present"))
    recheck.output isa VNextAuthorityRecheckLocalV2Checked ||
        throw(ArgumentError("recheck checked output missing"))
    all(d -> d isa VNextT0LocalPresentDeclarationV1, transport.declarations) ||
        throw(ArgumentError("checked recheck requires present declarations"))
    checked = recheck.output
    checked.candidate_ref == candidate || throw(ArgumentError("recheck output candidate mismatch"))
    checked.bundle_hash == transport.bundle_hash || throw(ArgumentError("recheck output bundle mismatch"))
    _vnext_ar_v2_content_equal(checked.declarations, transport.declarations) ||
        throw(ArgumentError("recheck output declarations mismatch"))
    _vnext_ar_v2_content_equal(checked.children, transport.children) ||
        throw(ArgumentError("recheck output children mismatch"))
    _vnext_ar_v2_content_equal(checked.feedback, transport.feedback) ||
        throw(ArgumentError("recheck output feedback mismatch"))
    checked.g3_children_deferred == any(c -> c isa VNextT0LocalChildAbsentV1,
        transport.children) || throw(ArgumentError("recheck child deferral mismatch"))
    recheck.prior_bundle_sha256 == transport.bundle_hash || throw(ArgumentError("recheck bundle mismatch"))
    wire = recheck.prior_bundle_bytes
    isempty(copy_bytes(wire)) && throw(ArgumentError("wire empty"))
    wire.sha256 == _vnext_ar_v2_sha(copy_bytes(wire)) || throw(ArgumentError("wire hash mismatch"))
    wire.sha256 == Digest256(repeat("0", 64)) && throw(ArgumentError("wire hash all zero"))
    expected_wire = _vnext_ar_v2_carrier(transport)
    wire.sha256 == expected_wire.sha256 || throw(ArgumentError("recheck wire hash stale"))
    length(copy_bytes(wire)) == length(copy_bytes(expected_wire)) ||
        throw(ArgumentError("recheck wire length stale"))
    copy_bytes(wire) == copy_bytes(expected_wire) || throw(ArgumentError("recheck wire bytes stale"))
    declarations = ntuple(i -> _vnext_t1_v2_declaration(transport.declarations[i]), 3)
    children = ntuple(i -> _vnext_t1_v2_child(transport.children[i]), 3)
    axes = ntuple(i -> declarations[i].axes, 3)
    g3 = _vnext_t1_v2_g3_authority(g3_authority)
    g3.commitment_hash == g3_expected_commitment || throw(ArgumentError("g3 commitment mismatch"))
    semantic_manifest = _vnext_t1_v2_identity_manifest(candidate, transport.bundle_hash,
        declarations, children, transport.feedback, axes, parent_commitments, g3, wire)
    semantic_identity = _vnext_t1_v2_manifest_digest(semantic_manifest)
    status = :prepared_not_executed
    resolution = :terminal_deferred
    p = CandidateStatePackageV5NextV2(VNEXT_T1_PACKAGE_SCHEMA_ID_V2,
        VNEXT_T1_PACKAGE_SCHEMA_VERSION_V2, VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V2,
        VNEXT_T1_PACKAGE_PROFILE_VERSION_V2, candidate, transport.bundle_hash,
        declarations, children, transport.feedback, axes, parent_commitments, g3,
        wire, semantic_identity, digest256_text("pending"),
        status, resolution, false, VNEXT_T1_PACKAGE_CLAIM_CEILING_V2)
    package_hash = _vnext_t1_v2_manifest_digest(_vnext_t1_v2_package_manifest(p))
    CandidateStatePackageV5NextV2(p.schema_id, p.schema_version, p.canonicalization_version,
        p.profile_version, p.candidate_ref, p.bundle_hash, p.declarations, p.children,
        p.feedback, p.axes, p.parent_commitments, p.g3_authority, p.wire,
        p.semantic_identity, package_hash, p.status, p.resolution, p.accepted, p.claim_ceiling)
end

function vnext_t1_package_v2_manifest_hash(package::CandidateStatePackageV5NextV2)
    _vnext_t1_v2_manifest_digest(_vnext_t1_v2_package_manifest(package))
end

function vnext_t1_package_v2_validate(package::CandidateStatePackageV5NextV2)
    package.schema_id == VNEXT_T1_PACKAGE_SCHEMA_ID_V2 || return :schema_mismatch
    package.schema_version == VNEXT_T1_PACKAGE_SCHEMA_VERSION_V2 || return :schema_mismatch
    package.canonicalization_version == VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V2 ||
        return :canonicalization_version_mismatch
    package.profile_version == VNEXT_T1_PACKAGE_PROFILE_VERSION_V2 || return :profile_version_mismatch
    package.candidate_ref.version == "v5" || return :candidate_ref_conflict
    package.wire.encoding == VNEXT_T1_CANONICAL_BYTES_V2_ENCODING || return :wire_encoding_conflict
    isempty(copy_bytes(package.wire)) && return :wire_empty
    package.wire.sha256 == Digest256(repeat("0", 64)) && return :wire_hash_zero
    package.wire.sha256 == _vnext_ar_v2_sha(copy_bytes(package.wire)) || return :wire_hash_mismatch
    package.status === :prepared_not_executed || return :status_conflict
    package.resolution === :terminal_deferred || return :resolution_conflict
    package.accepted === false || return :accepted_conflict
    package.claim_ceiling == VNEXT_T1_PACKAGE_CLAIM_CEILING_V2 || return :claim_ceiling_conflict
    package.semantic_identity == _vnext_t1_v2_manifest_digest(_vnext_t1_v2_identity_manifest(
        package.candidate_ref, package.bundle_hash, package.declarations, package.children,
        package.feedback, package.axes, package.parent_commitments, package.g3_authority,
        package.wire)) ||
        return :semantic_identity_mismatch
    package.package_hash == vnext_t1_package_v2_manifest_hash(package) || return :package_hash_mismatch
    nothing
end

export CandidateStatePackageV5NextV2,VNextT1DeclarationManifestV2,VNextT1ChildManifestV2,
    VNextT1G3AuthorityManifestV2,vnext_t1_package_v2_manifest_hash,vnext_t1_package_v2_validate
