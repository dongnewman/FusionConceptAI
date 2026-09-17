"""AD-30 local, source-backed T0 transport.

This is an additive local-input boundary.  It deliberately does not include or
modify the old T0 transport, the package/registry, a provider, a mesh or a
solver.  Unlike the historical T0 scaffold, a present record carries the
actual source/declaration/semantic bytes and independently checkable SHA-256
values, locators and two receipt envelopes.  The fixture is never an
authority: every acceptance decision below is recomputed from the input.
"""

const VNEXT_T0_LOCAL_SCHEMA_ID_V1 = "GenomeV5/Integration/VNextDeclarationTransportLocalV1"
const VNEXT_T0_LOCAL_SCHEMA_VERSION_V1 = "v1"
const VNEXT_T0_LOCAL_LAYERS_V1 = (:G1, :G2, :G3)
const VNEXT_T0_LOCAL_AXES_V1 = (:payload_schema_version, :canonicalization_profile_version,
    :applicability_profile_version, :evidence_receipt_version)
const VNEXT_T0_LOCAL_AXIS_IDS_V1 = (
    "fusion.t0.local/payload-schema", "fusion.t0.local/canonicalization",
    "fusion.t0.local/applicability", "fusion.t0.local/evidence-receipt")
const VNEXT_T0_LOCAL_AXIS_VERSION_V1 = "v1"
const VNEXT_T0_LOCAL_CHILD_KINDS_V1 = (:realization, :control, :binding)
const VNEXT_T0_LOCAL_DEFERRED_V1 = (:terminal_deferred, :typed_absent)
const VNEXT_T0_G3_FEEDBACK_FACTORY_REF_V1 = QualifiedRefV1(
    "fusionconceptai://GenomeV5/G3/source-feedback-declaration-factory", "v1")
const VNEXT_T0_G3_FEEDBACK_FACTORY_VERSION_V1 = "v1"
const VNEXT_T0_G3_FEEDBACK_AXES_V1 = (
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/payload-schema", "v1"),
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/canonicalization-profile", "v1"),
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/applicability-profile", "v1"),
    QualifiedRefV1("fusionconceptai://GenomeV5/G3/source-feedback/evidence-receipt", "v1"))

_vnl_t0_sha(bytes::AbstractVector{UInt8}) = Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))
_vnl_t0_text(x, field) = begin
    s = String(x)
    !isempty(s) && isvalid(s) || throw(ArgumentError("$field must be non-empty UTF-8"))
    s
end
_vnl_t0_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_vnl_t0_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_vnl_t0_ref_hash(x::QualifiedRefV1) = canonical_hash(x)

"""A byte payload with a caller claim retained for an independent recheck."""
struct VNextT0LocalBytesV1
    bytes::Vector{UInt8}
    sha256::Digest256
    function VNextT0LocalBytesV1(bytes::AbstractVector{UInt8}, sha256::Digest256)
        new(copy(Vector{UInt8}(bytes)), sha256)
    end
end
semantic_view(x::VNextT0LocalBytesV1) = (bytes=x.bytes, sha256=x.sha256)
canonical_json(x::VNextT0LocalBytesV1) = canonical_json(semantic_view(x))

"""Source locator; paths are relative and cannot escape the repository root."""
struct VNextT0LocalSourceLocatorV1
    repository_root::String
    source_path::String
    source_uri::String
    source_ref::QualifiedRefV1
    source_size::Int
    source_sha256::Digest256
    observed_head::String
    head_path_status::Symbol
    working_tree_path_status::Symbol
    working_tree_status::Symbol
    head_blob_sha256::Union{Nothing,Digest256}
    provenance::Symbol
    function VNextT0LocalSourceLocatorV1(root::Any, path::Any, uri::Any,
            source_ref::QualifiedRefV1, size::Integer, sha256::Digest256,
            observed_head::Any, head_path_status::Any,
            working_tree_path_status::Any, working_tree_status::Any,
            head_blob_sha256::Any, provenance::Any)
        r0 = _vnl_t0_text(root, "repository_root")
        isdir(r0) || throw(ArgumentError("repository_root must exist"))
        r = realpath(r0)
        p = replace(_vnl_t0_text(path, "source_path"), '\\' => '/')
        u = _vnl_t0_text(uri, "source_uri")
        comps = split(p, '/'; keepempty=false)
        isabspath(p) && throw(ArgumentError("source_path must be relative"))
        any(c -> c == "..", comps) && throw(ArgumentError("source_path escapes repository"))
        size >= 0 || throw(ArgumentError("source_size must be non-negative"))
        h = _vnl_t0_text(observed_head, "observed_head")
        all(x -> x isa Symbol, (head_path_status, working_tree_path_status, working_tree_status)) ||
            throw(ArgumentError("locator path statuses must be Symbols"))
        head_blob_sha256 === nothing || head_blob_sha256 isa Digest256 ||
            throw(ArgumentError("head_blob_sha256 must be Digest256 or nothing"))
        provenance in (:repository_head, :isolated_test_fixture) ||
            throw(ArgumentError("locator provenance invalid"))
        new(r, p, u, source_ref, Int(size), sha256, h, head_path_status,
            working_tree_path_status, working_tree_status, head_blob_sha256, provenance)
    end
end
semantic_view(x::VNextT0LocalSourceLocatorV1) =
    (repository_root=x.repository_root, source_path=x.source_path, source_uri=x.source_uri,
     source_ref=x.source_ref, source_size=x.source_size, source_sha256=x.source_sha256,
     observed_head=x.observed_head, head_path_status=x.head_path_status,
     working_tree_path_status=x.working_tree_path_status,
     working_tree_status=x.working_tree_status, head_blob_sha256=x.head_blob_sha256,
     provenance=x.provenance)
canonical_json(x::VNextT0LocalSourceLocatorV1) = canonical_json(semantic_view(x))

"""Semantic body separates presentation labels from hashed meaning."""
struct VNextT0LocalSemanticBodyV1
    body::Any
    bytes::VNextT0LocalBytesV1
    labels::Tuple
    function VNextT0LocalSemanticBodyV1(body::Any, bytes::VNextT0LocalBytesV1, labels::Any=())
        labels isa Tuple || throw(ArgumentError("labels must be an immutable tuple"))
        new(body, bytes, labels)
    end
end
semantic_view(x::VNextT0LocalSemanticBodyV1) = (body=x.body, bytes=x.bytes, labels=())
canonical_json(x::VNextT0LocalSemanticBodyV1) = canonical_json(semantic_view(x))

"""Explicit fresh-candidate envelope for the legacy G2 source payload shape."""
struct VNextT0LocalG2CandidateEnvelopeV1
    candidate_ref::QualifiedRefV1
    contract_ref::GenomeContractRef
    source_ref::QualifiedRefV1
    source_hash::Digest256
    function VNextT0LocalG2CandidateEnvelopeV1(candidate_ref::QualifiedRefV1,
            contract_ref::GenomeContractRef, source_ref::QualifiedRefV1,
            source_hash::Digest256)
        candidate_ref.version == "v5" || throw(ArgumentError("G2 envelope candidate version invalid"))
        new(candidate_ref, contract_ref, source_ref, source_hash)
    end
end
semantic_view(x::VNextT0LocalG2CandidateEnvelopeV1) =
    (candidate_ref=x.candidate_ref, contract_ref=x.contract_ref,
     source_ref=x.source_ref, source_hash=x.source_hash)
canonical_json(x::VNextT0LocalG2CandidateEnvelopeV1) = canonical_json(semantic_view(x))

"""Closed normalized evidence emitted only by a strict G1/G2/G3 adapter."""
struct VNextT0LocalFactoryResultV1
    factory_id::QualifiedRefV1
    factory_version::String
    factory_api::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    source_ref::QualifiedRefV1
    source_bytes::VNextT0LocalBytesV1
    source_size::Int
    locator::VNextT0LocalSourceLocatorV1
    locator_provenance::Symbol
    declaration_ref::QualifiedRefV1
    declaration_bytes::VNextT0LocalBytesV1
    declaration_hash::Digest256
    status::Symbol
    contract_ref::GenomeContractRef
    content_identity::Digest256
    axes::NTuple{4,QualifiedRefV1}
    upstream_receipt_bytes::VNextT0LocalBytesV1
    upstream_receipt_hash::Digest256
    function VNextT0LocalFactoryResultV1(factory_id, factory_version, factory_api,
            candidate_ref, layer, source_ref, source_bytes, source_size,
            locator, locator_provenance,
            declaration_ref, declaration_bytes, declaration_hash, status,
            contract_ref, content_identity, axes, upstream_receipt_bytes,
            upstream_receipt_hash)
        factory_id isa QualifiedRefV1 || throw(ArgumentError("factory_id must be QualifiedRefV1"))
        factory_version isa String && !isempty(factory_version) ||
            throw(ArgumentError("factory_version must be non-empty"))
        factory_api in (:G1, :G2, :G3, :G3_FEEDBACK) || throw(ArgumentError("factory_api invalid"))
        candidate_ref isa QualifiedRefV1 || throw(ArgumentError("candidate_ref invalid"))
        layer in VNEXT_T0_LOCAL_LAYERS_V1 || throw(ArgumentError("layer invalid"))
        source_ref isa QualifiedRefV1 || throw(ArgumentError("source_ref invalid"))
        declaration_ref isa QualifiedRefV1 || throw(ArgumentError("declaration_ref invalid"))
        status === :present || throw(ArgumentError("normalized factory status must be present"))
        contract_ref isa GenomeContractRef || throw(ArgumentError("contract_ref invalid"))
        source_size == length(source_bytes.bytes) || throw(ArgumentError("source_size mismatch"))
        locator.source_ref == source_ref || throw(ArgumentError("factory locator source ref mismatch"))
        locator.source_size == source_size || throw(ArgumentError("factory locator source size mismatch"))
        locator.source_sha256 == source_bytes.sha256 || throw(ArgumentError("factory locator source hash mismatch"))
        locator.provenance == locator_provenance || throw(ArgumentError("factory locator provenance mismatch"))
        locator_provenance in (:repository_head, :isolated_test_fixture) ||
            throw(ArgumentError("locator_provenance invalid"))
        source_bytes.sha256 == _vnl_t0_sha(source_bytes.bytes) || throw(ArgumentError("source hash mismatch"))
        declaration_bytes.sha256 == _vnl_t0_sha(declaration_bytes.bytes) || throw(ArgumentError("declaration hash mismatch"))
        declaration_hash == declaration_bytes.sha256 ||
            throw(ArgumentError("declaration hash does not cover declaration bytes"))
        upstream_receipt_hash == _vnl_t0_sha(upstream_receipt_bytes.bytes) ||
            throw(ArgumentError("upstream receipt hash mismatch"))
        expected_content_identity = canonical_hash((factory_id=factory_id,
            factory_version=factory_version, factory_api=factory_api,
            candidate_ref=candidate_ref, layer=layer, source_ref=source_ref,
            source_bytes=source_bytes, source_size=Int(source_size),
            locator=locator,
            locator_provenance=locator_provenance,
            declaration_ref=declaration_ref, declaration_bytes=declaration_bytes,
            declaration_hash=declaration_hash, status=status,
            contract_ref=contract_ref, axes=axes,
            upstream_receipt_bytes=upstream_receipt_bytes,
            upstream_receipt_hash=upstream_receipt_hash))
        content_identity == expected_content_identity ||
            throw(ArgumentError("factory_result_content_identity_mismatch"))
        new(factory_id, factory_version, factory_api, candidate_ref, layer,
            source_ref, source_bytes, Int(source_size), locator, locator_provenance, declaration_ref,
            declaration_bytes, declaration_hash, status, contract_ref,
            content_identity, axes, upstream_receipt_bytes, upstream_receipt_hash)
    end
end

function vnext_t0_local_g3_feedback_contract_v1()
    GenomeContractRef("fusionconceptai://GenomeV5/G3/source-feedback", "v1",
        g3_sf_schema_hash_v1(), g3_sf_canonicalization_hash_v1(),
        "g3-source-feedback-v1-profile:" * g3_sf_profile_hash_v1().value)
end
semantic_view(x::VNextT0LocalFactoryResultV1) =
    (factory_id=x.factory_id, factory_version=x.factory_version,
     factory_api=x.factory_api, candidate_ref=x.candidate_ref, layer=x.layer,
     source_ref=x.source_ref, source_bytes=x.source_bytes, source_size=x.source_size,
     locator=x.locator,
     locator_provenance=x.locator_provenance,
     declaration_ref=x.declaration_ref, declaration_bytes=x.declaration_bytes,
     declaration_hash=x.declaration_hash, status=x.status, contract_ref=x.contract_ref,
     content_identity=x.content_identity, axes=x.axes,
     upstream_receipt_bytes=x.upstream_receipt_bytes,
     upstream_receipt_hash=x.upstream_receipt_hash)
canonical_json(x::VNextT0LocalFactoryResultV1) = canonical_json(semantic_view(x))
_vnl_t0_factory_result_bytes(x::VNextT0LocalFactoryResultV1) = begin
    b = Vector{UInt8}(codeunits(canonical_json(x)))
    VNextT0LocalBytesV1(b, _vnl_t0_sha(b))
end

"""Strictly normalize one concrete present G1/G2/G3 factory result.

The raw result is never stored. Every field in the closed local evidence is
copied from a typed result or from bytes that are read and checked against the
typed result's locator. Any mismatch aborts before a receipt can be built.
"""
function vnext_t0_local_normalize_factory_result_v1(raw_result::Any,
        factory_api::Symbol, layer::Symbol, candidate::QualifiedRefV1,
        source_ref::QualifiedRefV1, source_bytes::VNextT0LocalBytesV1,
        source_locator::VNextT0LocalSourceLocatorV1,
        declaration_ref::QualifiedRefV1,
        declaration_bytes::VNextT0LocalBytesV1,
        contract_ref::GenomeContractRef)
    result_type_ok = (factory_api === :G1 && raw_result isa G1SourceFactoryConstructionResultV1) ||
        (factory_api === :G2 && raw_result isa G2SourceFactoryConstructionResultV1) ||
        (factory_api === :G3 && raw_result isa G3FactoryConstructionResultV1)
    result_type_ok || throw(ArgumentError("factory_result_type_invalid"))
    receipt = raw_result.receipt
    receipt.status === :present || throw(ArgumentError("factory_result_status_mismatch"))
    raw_result.source_declaration !== nothing ||
        throw(ArgumentError("factory_result_content_missing"))
    source_decl = raw_result.source_declaration
    if factory_api === :G1
        source_ref_actual = source_decl.declaration.source_ref
        candidate_actual = source_decl.declaration.candidate_ref
        declaration_hash_actual = source_decl.local_declaration_hash
        declaration_bytes_actual = source_decl.declaration
        contract_actual = source_decl.public_contract_ref
        locator = source_decl.locator
        locator_provenance = locator.provenance
        factory_id = raw_result.identity.factory_ref
        factory_version = raw_result.identity.factory_version
        axes_actual = (raw_result.identity.version_axes.payload_schema_version,
            raw_result.identity.version_axes.canonicalization_profile_version,
            raw_result.identity.version_axes.applicability_profile_version,
            raw_result.identity.version_axes.evidence_receipt_version)
        candidate_actual == candidate || throw(ArgumentError("factory_result_candidate_mismatch"))
        source_ref_actual == source_ref || throw(ArgumentError("factory_result_source_ref_mismatch"))
    elseif factory_api === :G2
        source_ref_actual = source_decl.declaration.source.source_ref
        declaration_hash_actual = source_decl.local_declaration_hash
        declaration_bytes_actual = source_decl.declaration
        contract_actual = source_decl.public_contract_ref
        locator = source_decl.locator
        locator_provenance = locator.provenance
        factory_id = raw_result.identity.factory_ref
        factory_version = raw_result.identity.factory_version
        axes_actual = (raw_result.identity.version_axes.payload_schema_version,
            raw_result.identity.version_axes.canonicalization_profile_version,
            raw_result.identity.version_axes.applicability_profile_version,
            raw_result.identity.version_axes.evidence_receipt_version)
        source_decl.declaration.source.candidate_ref == contract_actual ||
            throw(ArgumentError("factory_result_candidate_contract_mismatch"))
        source_ref_actual == source_ref || throw(ArgumentError("factory_result_source_ref_mismatch"))
    else
        source_ref_actual = source_decl.content.source_schema_ref
        declaration_hash_actual = source_decl.source_declaration_hash
        declaration_bytes_actual = source_decl
        contract_actual = source_decl.content.contract_ref
        locator = source_decl.content.locator
        locator_provenance = :repository_head
        factory_id = raw_result.identity.factory_ref
        factory_version = raw_result.identity.factory_version
        axes_actual = (raw_result.identity.version_axes.payload_schema_version,
            raw_result.identity.version_axes.canonicalization_profile_version,
            raw_result.identity.version_axes.applicability_profile_version,
            raw_result.identity.version_axes.evidence_receipt_version)
        source_ref_actual == source_ref || throw(ArgumentError("factory_result_source_ref_mismatch"))
        declaration_ref == source_decl.declaration_ref ||
            throw(ArgumentError("factory_result_declaration_ref_mismatch"))
    end
    contract_actual == contract_ref || throw(ArgumentError("factory_result_contract_mismatch"))
    upstream_provenance = factory_api === :G3 ? :repository_head : locator.provenance
    _vnl_t0_factory_locator_matches(source_locator, locator, source_ref, upstream_provenance) ||
        throw(ArgumentError("factory_result_locator_mismatch"))
    expected_factory_id, expected_factory_version = if factory_api === :G1
        isdefined(@__MODULE__, :G1_SOURCE_AUTHORITY_FACTORY_REF_V1) ||
            throw(ArgumentError("factory_dependency_missing"))
        (G1_SOURCE_AUTHORITY_FACTORY_REF_V1, G1_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
    elseif factory_api === :G2
        isdefined(@__MODULE__, :G2_SOURCE_AUTHORITY_FACTORY_REF_V1) ||
            throw(ArgumentError("factory_dependency_missing"))
        (G2_SOURCE_AUTHORITY_FACTORY_REF_V1, G2_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
    else
        isdefined(@__MODULE__, :G3_SOURCE_AUTHORITY_FACTORY_REF_V1) ||
            throw(ArgumentError("factory_dependency_missing"))
        (G3_SOURCE_AUTHORITY_FACTORY_REF_V1, G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
    end
    factory_id == expected_factory_id || throw(ArgumentError("factory_result_id_mismatch"))
    factory_version == expected_factory_version || throw(ArgumentError("factory_result_version_mismatch"))
    g3_axes = factory_api === :G3 ? g3_version_axes(raw_result.identity.scope) : nothing
    expected_axes = factory_api === :G1 ?
        (QualifiedRefV1("fusion.g1.payload-schema", "v2"),
         QualifiedRefV1("fusion.g1.canonicalization", "v2"),
         QualifiedRefV1("fusion.g1.applicability", "v2"),
         QualifiedRefV1("fusion.g1.receipt", "v2")) : factory_api === :G2 ?
        (QualifiedRefV1("fusion.g2.payload-schema", "v5"),
         QualifiedRefV1("fusion.g2.canonicalization", "v5"),
         QualifiedRefV1("fusion.g2.applicability", "v5"),
         QualifiedRefV1("fusion.g2.receipt", "v5")) :
        (g3_axes.payload_schema_version, g3_axes.canonicalization_profile_version,
         g3_axes.applicability_profile_version, g3_axes.evidence_receipt_version)
    axes_actual == expected_axes || throw(ArgumentError("factory_result_axes_mismatch"))
    locator.source_sha256 == source_bytes.sha256 ||
        throw(ArgumentError("factory_result_source_content_mismatch"))
    locator.source_bytes == length(source_bytes.bytes) ||
        throw(ArgumentError("factory_result_source_size_mismatch"))
    _vnl_t0_locator_bytes(source_locator) == source_bytes.bytes ||
        throw(ArgumentError("source_locator_bytes_mismatch"))
    actual_declaration_bytes = Vector{UInt8}(codeunits(canonical_json(declaration_bytes_actual)))
    declaration_bytes.bytes == actual_declaration_bytes ||
        throw(ArgumentError("factory_result_declaration_content_mismatch"))
    declaration_hash_actual = _vnl_t0_sha(actual_declaration_bytes)
    upstream = Vector{UInt8}(codeunits(canonical_json(receipt)))
    upstream_bytes = VNextT0LocalBytesV1(upstream, _vnl_t0_sha(upstream))
    content_identity = canonical_hash((factory_id=factory_id,
        factory_version=factory_version, factory_api=factory_api,
        candidate_ref=candidate, layer=layer, source_ref=source_ref,
        source_bytes=source_bytes, source_size=length(source_bytes.bytes),
        locator=source_locator,
        locator_provenance=locator_provenance,
        declaration_ref=declaration_ref, declaration_bytes=declaration_bytes,
        declaration_hash=declaration_hash_actual, status=:present,
        contract_ref=contract_ref, axes=axes_actual,
        upstream_receipt_bytes=upstream_bytes,
        upstream_receipt_hash=upstream_bytes.sha256))
    VNextT0LocalFactoryResultV1(factory_id, factory_version, factory_api,
        candidate, layer, source_ref, source_bytes, length(source_bytes.bytes),
        source_locator, locator_provenance, declaration_ref, declaration_bytes,
        declaration_hash_actual, :present,
        contract_ref, content_identity, axes_actual, upstream_bytes,
        upstream_bytes.sha256)
end

function _vnl_t0_factory_locator_matches(local_locator::VNextT0LocalSourceLocatorV1,
        upstream_locator, expected_source_ref::QualifiedRefV1,
        upstream_provenance::Symbol)
    try
        realpath(local_locator.repository_root) == realpath(upstream_locator.repository_root) &&
        local_locator.observed_head == upstream_locator.observed_head &&
        local_locator.source_path == upstream_locator.source_path &&
        local_locator.source_ref == expected_source_ref &&
        local_locator.source_uri == expected_source_ref.id &&
        local_locator.source_size == upstream_locator.source_bytes &&
        local_locator.source_sha256 == upstream_locator.source_sha256 &&
        local_locator.head_path_status == upstream_locator.head_path_status &&
        local_locator.working_tree_path_status == upstream_locator.working_tree_path_status &&
        local_locator.working_tree_status == upstream_locator.working_tree_status &&
        local_locator.head_blob_sha256 == upstream_locator.head_blob_sha256 &&
        local_locator.provenance == upstream_provenance
    catch
        false
    end
end

"""Normalize the real candidate-consuming G3SourceFeedbackLawV1 declaration.

The feedback declaration is not a realization/control/binding source factory
result. It is built by `g3_sf_declaration_v1` and receives its own closed
factory receipt so the local transport cannot substitute the :realization
authority factory for a different G3 source.
"""
function vnext_t0_local_normalize_g3_feedback_declaration_v1(raw::G3SFDeclarationV1,
        candidate::QualifiedRefV1, source_ref::QualifiedRefV1,
        source_bytes::VNextT0LocalBytesV1,
        source_locator::VNextT0LocalSourceLocatorV1,
        declaration_ref::QualifiedRefV1,
        semantic_body::VNextT0LocalSemanticBodyV1)
    raw.candidate_ref == candidate || throw(ArgumentError("g3_feedback_candidate_mismatch"))
    body_candidate = getproperty(semantic_body.body, :candidate_ref)
    body_source = getproperty(semantic_body.body, :source_ref)
    body_candidate == candidate || throw(ArgumentError("g3_feedback_body_candidate_mismatch"))
    body_source == source_ref || throw(ArgumentError("g3_feedback_body_source_ref_mismatch"))
    validation_status, validation_errors = g3_sf_validate_v1(raw)
    validation_status === :valid ||
        throw(ArgumentError("g3_feedback_declaration_invalid:" * join(validation_errors, ",")))
    # R20c: the semantic projection must be an exact view of the original
    # declaration before any candidate/source edit is admitted.  Checking only
    # the two outer refs permits a stale or fabricated authority/target tuple
    # to be carried into a fresh candidate.
    _vnl_t0_validate_g3_feedback_projection_v1(raw, semantic_body.body, candidate)
    _vnl_t0_locator_bytes(source_locator) == source_bytes.bytes ||
        throw(ArgumentError("g3_feedback_source_locator_bytes_mismatch"))
    source_bytes.sha256 == _vnl_t0_sha(source_bytes.bytes) ||
        throw(ArgumentError("g3_feedback_source_hash_mismatch"))
    declaration_raw = Vector{UInt8}(codeunits(canonical_json(raw)))
    declaration_bytes = VNextT0LocalBytesV1(declaration_raw, _vnl_t0_sha(declaration_raw))
    contract_ref = vnext_t0_local_g3_feedback_contract_v1()
    receipt_body = (status=:present, factory_ref=VNEXT_T0_G3_FEEDBACK_FACTORY_REF_V1,
        factory_version=VNEXT_T0_G3_FEEDBACK_FACTORY_VERSION_V1,
        candidate_ref=candidate, source_ref=source_ref,
        source_bytes=source_bytes, declaration_ref=declaration_ref,
        declaration_hash=declaration_bytes.sha256, contract_ref=contract_ref,
        axes=VNEXT_T0_G3_FEEDBACK_AXES_V1)
    receipt_raw = Vector{UInt8}(codeunits(canonical_json(receipt_body)))
    upstream_bytes = VNextT0LocalBytesV1(receipt_raw, _vnl_t0_sha(receipt_raw))
    content_identity = canonical_hash((factory_id=VNEXT_T0_G3_FEEDBACK_FACTORY_REF_V1,
        factory_version=VNEXT_T0_G3_FEEDBACK_FACTORY_VERSION_V1,
        factory_api=:G3_FEEDBACK, candidate_ref=candidate, layer=:G3,
        source_ref=source_ref, source_bytes=source_bytes,
        source_size=length(source_bytes.bytes), locator=source_locator,
        locator_provenance=source_locator.provenance, declaration_ref=declaration_ref,
        declaration_bytes=declaration_bytes, declaration_hash=declaration_bytes.sha256,
        status=:present, contract_ref=contract_ref, axes=VNEXT_T0_G3_FEEDBACK_AXES_V1,
        upstream_receipt_bytes=upstream_bytes, upstream_receipt_hash=upstream_bytes.sha256))
    VNextT0LocalFactoryResultV1(VNEXT_T0_G3_FEEDBACK_FACTORY_REF_V1,
        VNEXT_T0_G3_FEEDBACK_FACTORY_VERSION_V1, :G3_FEEDBACK, candidate, :G3,
        source_ref, source_bytes, length(source_bytes.bytes), source_locator,
        source_locator.provenance, declaration_ref, declaration_bytes,
        declaration_bytes.sha256, :present, contract_ref, content_identity,
        VNEXT_T0_G3_FEEDBACK_AXES_V1, upstream_bytes, upstream_bytes.sha256)
end

function _vnl_t0_canonical_equal(a, b)
    canonical_json(a) == canonical_json(b)
end

"""Strictly validate every candidate projection in a G3 feedback body."""
function _vnl_t0_validate_g3_feedback_projection_v1(raw::G3SFDeclarationV1,
        body::Any, candidate::QualifiedRefV1)
    required = (:candidate_ref, :source_id, :owner_scope, :endpoints, :law,
        :ledger_entries, :ledger_closure, :feedback_targets, :upstream_authority)
    all(hasproperty(body, field) for field in required) ||
        throw(ArgumentError("g3_feedback_body_shape_incomplete"))
    body.candidate_ref == raw.candidate_ref == candidate ||
        throw(ArgumentError("g3_feedback_body_candidate_projection_mismatch"))
    body.source_id == raw.source_id || throw(ArgumentError("g3_feedback_body_source_id_mismatch"))
    body.owner_scope == raw.owner_scope || throw(ArgumentError("g3_feedback_body_owner_scope_mismatch"))
    for field in (:endpoints, :law, :ledger_entries, :ledger_closure)
        _vnl_t0_canonical_equal(getproperty(body, field), getproperty(raw, field)) ||
            throw(ArgumentError("g3_feedback_body_$(field)_mismatch"))
    end
    authorities = body.upstream_authority
    authorities isa Tuple && all(x -> x isa G3SFAuthorityV1, authorities) ||
        throw(ArgumentError("g3_feedback_body_upstream_authority_invalid"))
    length(authorities) == length(raw.upstream_authority) ||
        throw(ArgumentError("g3_feedback_body_upstream_authority_arity_mismatch"))
    for (actual, projected) in zip(raw.upstream_authority, authorities)
        actual.candidate_ref == candidate || throw(ArgumentError("g3_feedback_upstream_candidate_mismatch"))
        projected.candidate_ref == candidate || throw(ArgumentError("g3_feedback_upstream_candidate_projection_mismatch"))
        _vnl_t0_canonical_equal(actual, projected) ||
            throw(ArgumentError("g3_feedback_upstream_projection_mismatch"))
    end
    targets = body.feedback_targets
    targets isa Tuple && all(x -> x isa G3SFFeedbackTargetV1, targets) ||
        throw(ArgumentError("g3_feedback_body_feedback_targets_invalid"))
    length(targets) == length(raw.feedback_targets) ||
        throw(ArgumentError("g3_feedback_body_feedback_targets_arity_mismatch"))
    for (actual, projected) in zip(raw.feedback_targets, targets)
        actual.authority.candidate_ref == candidate ||
            throw(ArgumentError("g3_feedback_target_candidate_mismatch"))
        projected.authority.candidate_ref == candidate ||
            throw(ArgumentError("g3_feedback_target_candidate_projection_mismatch"))
        _vnl_t0_canonical_equal(actual, projected) ||
            throw(ArgumentError("g3_feedback_target_projection_mismatch"))
    end
    nothing
end

function _vnl_t0_g3_rebind_authority_v1(authority::G3SFAuthorityV1,
        old_candidate::QualifiedRefV1, fresh_candidate::QualifiedRefV1)
    authority.candidate_ref == old_candidate ||
        throw(ArgumentError("g3_feedback_authority_candidate_mismatch"))
    authority.status in (:missing, :historical_absent) ||
        throw(ArgumentError("g3_feedback_authority_status_not_rebindable"))
    authority.contract_ref === nothing && authority.contract_hash === nothing &&
        authority.source_ref === nothing && authority.source_bytes === nothing &&
        authority.source_sha256 === nothing ||
        throw(ArgumentError("g3_feedback_authority_materialized_without_fresh_receipt"))
    G3SFAuthorityV1(authority.layer, fresh_candidate, nothing, nothing,
        authority.status; attestation=authority.attestation)
end

"""Rebind a validated G3 semantic body; actual/stale/contradictory material is never copied."""
function _vnl_t0_g3_feedback_semantic_rebind_v1(body::Any,
        fresh_candidate::QualifiedRefV1, fresh_source_ref::QualifiedRefV1)
    required = (:candidate_ref, :source_id, :owner_scope, :endpoints, :law,
        :ledger_entries, :ledger_closure, :feedback_targets, :upstream_authority,
        :source_ref)
    all(hasproperty(body, field) for field in required) ||
        throw(ArgumentError("G3 feedback semantic body shape is incomplete"))
    old_candidate = body.candidate_ref
    old_candidate isa QualifiedRefV1 || throw(ArgumentError("g3_feedback_old_candidate_untyped"))
    old_source_ref = body.source_ref
    old_source_ref isa QualifiedRefV1 || throw(ArgumentError("g3_feedback_old_source_ref_untyped"))
    raw = try
        g3_sf_declaration_v1(old_candidate, body.source_id, body.owner_scope,
            body.endpoints, body.law, body.ledger_entries, body.ledger_closure,
            body.feedback_targets, body.upstream_authority)
    catch err
        throw(ArgumentError("g3_feedback_original_reconstruction_failed:" * sprint(showerror, err)))
    end
    validation_status, validation_errors = g3_sf_validate_v1(raw)
    validation_status === :valid ||
        throw(ArgumentError("g3_feedback_original_invalid:" * join(validation_errors, ",")))
    _vnl_t0_validate_g3_feedback_projection_v1(raw, body, old_candidate)
    fresh_authorities = Tuple(_vnl_t0_g3_rebind_authority_v1(a, old_candidate, fresh_candidate)
        for a in raw.upstream_authority)
    authority_by_layer = Dict(a.layer => a for a in fresh_authorities)
    fresh_targets = Tuple(begin
        t.authority.layer in keys(authority_by_layer) ||
            throw(ArgumentError("g3_feedback_target_authority_layer_missing"))
        a = authority_by_layer[t.authority.layer]
        G3SFFeedbackTargetV1(t.target_id, t.target_layer, t.target_path, t.quantity,
            t.unit, t.direction, t.sign, t.source_id, t.owner_scope, a)
    end for t in raw.feedback_targets)
    rebound = merge(body, (candidate_ref=fresh_candidate, source_ref=fresh_source_ref,
        feedback_targets=fresh_targets, upstream_authority=fresh_authorities))
    fresh_raw = g3_sf_declaration_v1(fresh_candidate, rebound.source_id, rebound.owner_scope,
        rebound.endpoints, rebound.law, rebound.ledger_entries, rebound.ledger_closure,
        rebound.feedback_targets, rebound.upstream_authority)
    fresh_status, fresh_errors = g3_sf_validate_v1(fresh_raw)
    fresh_status === :valid ||
        throw(ArgumentError("g3_feedback_rebound_invalid:" * join(fresh_errors, ",")))
    bytes = Vector{UInt8}(codeunits(canonical_json(rebound)))
    VNextT0LocalSemanticBodyV1(rebound,
        VNextT0LocalBytesV1(bytes, _vnl_t0_sha(bytes)), ())
end

struct VNextT0LocalFactoryReceiptV1
    bytes::VNextT0LocalBytesV1
    candidate_ref::QualifiedRefV1
    layer::Symbol
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    axes::NTuple{4,QualifiedRefV1}
    factory_axes::NTuple{4,QualifiedRefV1}
    status::Symbol
    factory_api::Symbol
    factory_result::VNextT0LocalFactoryResultV1
    factory_result_hash::Digest256
    function VNextT0LocalFactoryReceiptV1(candidate_ref, layer, source_ref,
            declaration_ref, axes, status, factory_result::VNextT0LocalFactoryResultV1)
        factory_result.candidate_ref == candidate_ref || throw(ArgumentError("receipt candidate mismatch"))
        factory_result.layer == layer || throw(ArgumentError("receipt layer mismatch"))
        factory_result.source_ref == source_ref || throw(ArgumentError("receipt source mismatch"))
        factory_result.declaration_ref == declaration_ref || throw(ArgumentError("receipt declaration mismatch"))
        factory_result.status == status || throw(ArgumentError("receipt status mismatch"))
        bytes = _vnl_t0_factory_result_bytes(factory_result)
        new(bytes, candidate_ref, layer, source_ref, declaration_ref, axes,
            factory_result.axes,
            status, factory_result.factory_api, factory_result, canonical_hash(factory_result))
    end
end
struct VNextT0LocalDeclarationReceiptV1
    bytes::VNextT0LocalBytesV1
    candidate_ref::QualifiedRefV1
    layer::Symbol
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    axes::NTuple{4,QualifiedRefV1}
    factory_axes::NTuple{4,QualifiedRefV1}
    status::Symbol
    factory_api::Symbol
    factory_result::VNextT0LocalFactoryResultV1
    factory_result_hash::Digest256
    function VNextT0LocalDeclarationReceiptV1(candidate_ref, layer, source_ref,
            declaration_ref, axes, status, factory_result::VNextT0LocalFactoryResultV1)
        factory_result.candidate_ref == candidate_ref || throw(ArgumentError("receipt candidate mismatch"))
        factory_result.layer == layer || throw(ArgumentError("receipt layer mismatch"))
        factory_result.source_ref == source_ref || throw(ArgumentError("receipt source mismatch"))
        factory_result.declaration_ref == declaration_ref || throw(ArgumentError("receipt declaration mismatch"))
        factory_result.status == status || throw(ArgumentError("receipt status mismatch"))
        bytes = _vnl_t0_factory_result_bytes(factory_result)
        new(bytes, candidate_ref, layer, source_ref, declaration_ref, axes,
            factory_result.axes,
            status, factory_result.factory_api, factory_result, canonical_hash(factory_result))
    end
end
for T in (:VNextT0LocalFactoryReceiptV1, :VNextT0LocalDeclarationReceiptV1)
    @eval begin
        semantic_view(x::$T) = (bytes=x.bytes, candidate_ref=x.candidate_ref, layer=x.layer,
            source_ref=x.source_ref, declaration_ref=x.declaration_ref, axes=x.axes,
            factory_axes=x.factory_axes, status=x.status,
            factory_api=x.factory_api, factory_result=x.factory_result, factory_result_hash=x.factory_result_hash)
        canonical_json(x::$T) = canonical_json(semantic_view(x))
    end
end

"""Actual child or closed typed absence. No open-ended `Any` child is allowed."""
struct VNextT0LocalChildPresentV1
    kind::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    child_id::String
    child_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_bytes::VNextT0LocalBytesV1
    source_locator::VNextT0LocalSourceLocatorV1
    body::Any
    body_hash::Digest256
    child_identity_hash::Digest256
end
struct VNextT0LocalChildAbsentV1
    kind::Symbol
    candidate_ref::QualifiedRefV1
    layer::Symbol
    child_id::String
    status::Symbol
    reason::String
    candidate_identity_created::Bool
    factory_api::Symbol
    factory_receipt_bytes::VNextT0LocalBytesV1
    factory_receipt_hash::Digest256
    source_path::String
    function VNextT0LocalChildAbsentV1(kind::Symbol, candidate_ref::QualifiedRefV1,
            layer::Symbol, child_id::String, status::Symbol, reason::String,
            candidate_identity_created::Bool, factory_api::Symbol,
            factory_receipt_bytes::VNextT0LocalBytesV1,
            factory_receipt_hash::Digest256, source_path::String)
        kind in VNEXT_T0_LOCAL_CHILD_KINDS_V1 || throw(ArgumentError("child kind invalid"))
        layer === :G3 || throw(ArgumentError("child layer invalid"))
        child_id == String(kind) || throw(ArgumentError("child id must equal kind"))
        status in VNEXT_T0_LOCAL_DEFERRED_V1 || throw(ArgumentError("absent child status invalid"))
        candidate_identity_created == false ||
            throw(ArgumentError("absent child cannot claim candidate identity"))
        factory_api === :G3 || throw(ArgumentError("absent child factory api invalid"))
        factory_receipt_hash == _vnl_t0_sha(factory_receipt_bytes.bytes) ||
            throw(ArgumentError("absent child factory receipt hash mismatch"))
        !isempty(source_path) || throw(ArgumentError("absent child source path missing"))
        new(kind, candidate_ref, layer, child_id, status, reason,
            candidate_identity_created, factory_api,
            factory_receipt_bytes, factory_receipt_hash, source_path)
    end
end
const VNextT0LocalChildV1 = Union{VNextT0LocalChildPresentV1,VNextT0LocalChildAbsentV1}
semantic_view(x::VNextT0LocalChildPresentV1) =
    (kind=x.kind, candidate_ref=x.candidate_ref, layer=x.layer, child_id=x.child_id,
     child_ref=x.child_ref, source_ref=x.source_ref,
     source_bytes=x.source_bytes, source_locator=x.source_locator, body=x.body,
     body_hash=x.body_hash, child_identity_hash=x.child_identity_hash)
semantic_view(x::VNextT0LocalChildAbsentV1) =
    (kind=x.kind, candidate_ref=x.candidate_ref, layer=x.layer, child_id=x.child_id,
     status=x.status, reason=x.reason, candidate_identity_created=x.candidate_identity_created,
     factory_api=x.factory_api,
     factory_receipt_bytes=x.factory_receipt_bytes,
     factory_receipt_hash=x.factory_receipt_hash, source_path=x.source_path)
canonical_json(x::VNextT0LocalChildPresentV1) = canonical_json(semantic_view(x))
canonical_json(x::VNextT0LocalChildAbsentV1) = canonical_json(semantic_view(x))

struct VNextT0LocalFeedbackV1
    target_id::String
    target_layer::Symbol
    candidate_ref::QualifiedRefV1
    target_ref::QualifiedRefV1
    body::Any
    body_hash::Digest256
end
semantic_view(x::VNextT0LocalFeedbackV1) =
    (target_id=x.target_id, target_layer=x.target_layer, candidate_ref=x.candidate_ref,
     target_ref=x.target_ref, body=x.body, body_hash=x.body_hash)
canonical_json(x::VNextT0LocalFeedbackV1) = canonical_json(semantic_view(x))

struct VNextT0LocalPresentDeclarationV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    declaration_ref::QualifiedRefV1
    source_identity_hash::Digest256
    declaration_identity_hash::Digest256
    axes::NTuple{4,QualifiedRefV1}
    source_bytes::VNextT0LocalBytesV1
    declaration_bytes::VNextT0LocalBytesV1
    semantic_body::VNextT0LocalSemanticBodyV1
    source_locator::VNextT0LocalSourceLocatorV1
    factory_receipt::VNextT0LocalFactoryReceiptV1
    declaration_receipt::VNextT0LocalDeclarationReceiptV1
end
struct VNextT0LocalAbsentDeclarationV1
    layer::Symbol
    candidate_ref::QualifiedRefV1
    reason::Symbol
    status::Symbol
end
const VNextT0LocalDeclarationV1 = Union{VNextT0LocalPresentDeclarationV1,VNextT0LocalAbsentDeclarationV1}
semantic_view(x::VNextT0LocalPresentDeclarationV1) =
    (layer=x.layer, candidate_ref=x.candidate_ref, source_ref=x.source_ref,
     declaration_ref=x.declaration_ref, axes=x.axes, source_bytes=x.source_bytes,
     source_identity_hash=x.source_identity_hash, declaration_identity_hash=x.declaration_identity_hash,
     declaration_bytes=x.declaration_bytes, semantic_body=x.semantic_body,
     source_locator=x.source_locator, factory_receipt=x.factory_receipt,
     declaration_receipt=x.declaration_receipt)
semantic_view(x::VNextT0LocalAbsentDeclarationV1) =
    (layer=x.layer, candidate_ref=x.candidate_ref, reason=x.reason, status=x.status)
canonical_json(x::VNextT0LocalPresentDeclarationV1) = canonical_json(semantic_view(x))
canonical_json(x::VNextT0LocalAbsentDeclarationV1) = canonical_json(semantic_view(x))

struct VNextT0LocalTransportV1
    candidate_ref::QualifiedRefV1
    declarations::NTuple{3,VNextT0LocalDeclarationV1}
    children::NTuple{3,VNextT0LocalChildV1}
    feedback::Tuple
    bundle_hash::Digest256
    status::Symbol
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
end
semantic_view(x::VNextT0LocalTransportV1) =
    (schema_id=VNEXT_T0_LOCAL_SCHEMA_ID_V1, schema_version=VNEXT_T0_LOCAL_SCHEMA_VERSION_V1,
     candidate_ref=x.candidate_ref, declarations=x.declarations, children=x.children,
     feedback=x.feedback, bundle_hash=x.bundle_hash, status=x.status, errors=x.errors, gaps=x.gaps)
canonical_json(x::VNextT0LocalTransportV1) = canonical_json(semantic_view(x))

struct VNextT0LocalAdmissionV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    transport::Union{Nothing,VNextT0LocalTransportV1}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
end
semantic_view(x::VNextT0LocalAdmissionV1) =
    (status=x.status, resolution=x.resolution, accepted=x.accepted,
     claim_ceiling=x.claim_ceiling, transport=x.transport, errors=x.errors, gaps=x.gaps)
canonical_json(x::VNextT0LocalAdmissionV1) = canonical_json(semantic_view(x))

struct VNextT0LocalSourceEditResultV1
    old_candidate_ref::QualifiedRefV1
    new_candidate_ref::QualifiedRefV1
    old_source_ref::QualifiedRefV1
    new_source_ref::QualifiedRefV1
    old_declaration_ref::QualifiedRefV1
    new_declaration_ref::QualifiedRefV1
    old_source_identity_hash::Digest256
    new_source_identity_hash::Digest256
    old_declaration_identity_hash::Digest256
    new_declaration_identity_hash::Digest256
    edited_declaration::VNextT0LocalPresentDeclarationV1
end
semantic_view(x::VNextT0LocalSourceEditResultV1) =
    (old_candidate_ref=x.old_candidate_ref, new_candidate_ref=x.new_candidate_ref,
     old_source_ref=x.old_source_ref, new_source_ref=x.new_source_ref,
     old_declaration_ref=x.old_declaration_ref, new_declaration_ref=x.new_declaration_ref,
     old_source_identity_hash=x.old_source_identity_hash,
     new_source_identity_hash=x.new_source_identity_hash,
     old_declaration_identity_hash=x.old_declaration_identity_hash,
     new_declaration_identity_hash=x.new_declaration_identity_hash,
     edited_declaration=x.edited_declaration)
canonical_json(x::VNextT0LocalSourceEditResultV1) = canonical_json(semantic_view(x))

function _vnl_t0_finite(x)
    x isa AbstractFloat && return isfinite(x)
    x isa NamedTuple && return all(_vnl_t0_finite(v) for v in values(x))
    x isa Tuple && return all(_vnl_t0_finite(v) for v in x)
    x isa AbstractArray && return all(_vnl_t0_finite(v) for v in x)
    x isa AbstractDict && return all(_vnl_t0_finite(v) for v in values(x))
    true
end
function _vnl_t0_body_hash(body::VNextT0LocalSemanticBodyV1)
    _vnl_t0_finite(body.body) || throw(ArgumentError("semantic body contains NaN or Inf"))
    canonical_hash(body.body)
end
function _vnl_t0_locator_bytes(locator::VNextT0LocalSourceLocatorV1)
    root = realpath(locator.repository_root)
    path = normpath(joinpath(root, locator.source_path))
    real = realpath(path)
    prefix = endswith(root, Base.Filesystem.path_separator) ? root : root * Base.Filesystem.path_separator
    (real == root || startswith(real, prefix)) || throw(ArgumentError("source locator escapes repository"))
    isfile(real) || throw(ArgumentError("source locator is not a file"))
    bytes = read(real)
    locator.source_uri == locator.source_ref.id || throw(ArgumentError("source URI/ref mismatch"))
    locator.source_size == length(bytes) || throw(ArgumentError("source locator size mismatch"))
    locator.source_sha256 == _vnl_t0_sha(bytes) || throw(ArgumentError("source locator hash mismatch"))
    bytes
end
_vnl_t0_semantic_bytes(body::VNextT0LocalSemanticBodyV1) =
    Vector{UInt8}(codeunits(canonical_json(body.body)))
function _vnl_t0_axes_ok(axes)
    axes isa NTuple{4,QualifiedRefV1} || return false
    Tuple(x.id for x in axes) == VNEXT_T0_LOCAL_AXIS_IDS_V1 &&
        all(x -> x.version == VNEXT_T0_LOCAL_AXIS_VERSION_V1, axes)
end

function _vnl_t0_errors(x::VNextT0LocalPresentDeclarationV1, candidate::QualifiedRefV1)
    e = Symbol[]
    x.layer in VNEXT_T0_LOCAL_LAYERS_V1 || push!(e, :foreign_layer)
    x.candidate_ref == candidate || push!(e, :foreign_candidate)
    _vnl_t0_axes_ok(x.axes) || push!(e, :axes_identity_or_order_invalid)
    length(unique(canonical_hash(a).value for a in x.axes)) == 4 || push!(e, :duplicate_axis)
    for (i, axis) in enumerate(x.axes)
        axis.version == VNEXT_T0_LOCAL_AXIS_VERSION_V1 || push!(e, :axis_version_invalid)
    end
    isempty(x.source_bytes.bytes) && push!(e, :source_bytes_missing)
    isempty(x.declaration_bytes.bytes) && push!(e, :declaration_bytes_missing)
    x.source_bytes.sha256 == _vnl_t0_sha(x.source_bytes.bytes) || push!(e, :source_bytes_hash_mismatch)
    x.declaration_bytes.sha256 == _vnl_t0_sha(x.declaration_bytes.bytes) || push!(e, :declaration_bytes_hash_mismatch)
    x.semantic_body.bytes.sha256 == _vnl_t0_sha(x.semantic_body.bytes.bytes) || push!(e, :semantic_body_bytes_hash_mismatch)
    isempty(x.semantic_body.bytes.bytes) && push!(e, :semantic_body_bytes_missing)
    try
        _vnl_t0_locator_bytes(x.source_locator) == x.source_bytes.bytes || push!(e, :source_locator_bytes_mismatch)
    catch
        push!(e, :source_locator_unreadable_or_escape)
    end
    try
        x.semantic_body.bytes.bytes == _vnl_t0_semantic_bytes(x.semantic_body) ||
            push!(e, :semantic_body_bytes_mismatch)
    catch
        push!(e, :semantic_body_invalid)
    end
    x.source_locator.source_ref == x.source_ref || push!(e, :source_locator_ref_mismatch)
    x.source_locator.source_uri == x.source_ref.id || push!(e, :source_uri_ref_mismatch)
    x.source_identity_hash == canonical_hash((kind=:source, ref=x.source_ref, bytes_sha256=x.source_bytes.sha256)) ||
        push!(e, :source_identity_hash_mismatch)
    x.declaration_identity_hash == canonical_hash((kind=:declaration, ref=x.declaration_ref, bytes_sha256=x.declaration_bytes.sha256)) ||
        push!(e, :declaration_identity_hash_mismatch)
    x.source_locator.source_size == length(x.source_bytes.bytes) || push!(e, :source_locator_size_mismatch)
    x.source_locator.source_sha256 == x.source_bytes.sha256 || push!(e, :source_locator_hash_mismatch)
    x.source_ref.id != "" || push!(e, :source_ref_missing)
    x.declaration_ref.id != "" || push!(e, :declaration_ref_missing)
    x.factory_receipt.bytes.sha256 == _vnl_t0_sha(x.factory_receipt.bytes.bytes) || push!(e, :factory_receipt_hash_mismatch)
    x.declaration_receipt.bytes.sha256 == _vnl_t0_sha(x.declaration_receipt.bytes.bytes) || push!(e, :declaration_receipt_hash_mismatch)
    for r in (x.factory_receipt, x.declaration_receipt)
        r.candidate_ref == candidate || push!(e, :receipt_candidate_mismatch)
        r.layer === x.layer || push!(e, :receipt_layer_mismatch)
        r.source_ref == x.source_ref || push!(e, :receipt_source_ref_mismatch)
        r.declaration_ref == x.declaration_ref || push!(e, :receipt_declaration_ref_mismatch)
        r.axes == x.axes || push!(e, :receipt_axes_mismatch)
        r.factory_axes == r.factory_result.axes || push!(e, :factory_result_outer_axes_mismatch)
        r.status === :present || push!(e, :receipt_status_invalid)
    end
    for fr in (x.factory_receipt, x.declaration_receipt)
        fr.factory_api in (:G1, :G2, :G3, :G3_FEEDBACK) || push!(e, :factory_api_invalid)
        fr.factory_result_hash == canonical_hash(fr.factory_result) ||
            push!(e, :factory_result_hash_mismatch)
        fr.bytes.bytes == _vnl_t0_factory_result_bytes(fr.factory_result).bytes ||
            push!(e, :factory_receipt_bytes_mismatch)
        append!(e, _vnl_t0_factory_result_binding_errors(fr, x, candidate))
    end
    x.semantic_body.body === nothing && push!(e, :semantic_body_missing)
    try
        _vnl_t0_body_hash(x.semantic_body)
    catch
        push!(e, :semantic_body_invalid)
    end
    unique!(e); e
end

function _vnl_t0_factory_result_binding_errors(fr, x, candidate)
    r = fr.factory_result
    e = Symbol[]
    r.factory_api == fr.factory_api || push!(e, :factory_result_api_mismatch)
    r.candidate_ref == candidate || push!(e, :factory_result_candidate_mismatch)
    r.layer == x.layer || push!(e, :factory_result_layer_mismatch)
    r.source_ref == x.source_ref || push!(e, :factory_result_source_ref_mismatch)
    r.source_size == length(x.source_bytes.bytes) || push!(e, :factory_result_source_size_mismatch)
    r.source_bytes.bytes == x.source_bytes.bytes || push!(e, :factory_result_source_content_mismatch)
    r.source_bytes.sha256 == x.source_bytes.sha256 || push!(e, :factory_result_source_content_mismatch)
    r.locator_provenance in (:repository_head, :isolated_test_fixture) ||
        push!(e, :factory_result_locator_provenance_mismatch)
    try
        r.locator.repository_root == x.source_locator.repository_root ||
            push!(e, :factory_result_locator_root_mismatch)
        r.locator.observed_head == x.source_locator.observed_head ||
            push!(e, :factory_result_locator_head_mismatch)
        r.locator.source_path == x.source_locator.source_path ||
            push!(e, :factory_result_locator_path_mismatch)
        r.locator.source_ref == x.source_locator.source_ref ||
            push!(e, :factory_result_locator_ref_mismatch)
        r.locator.source_size == x.source_locator.source_size ||
            push!(e, :factory_result_locator_size_mismatch)
        r.locator.source_sha256 == x.source_locator.source_sha256 ||
            push!(e, :factory_result_locator_hash_mismatch)
        r.locator.head_path_status == x.source_locator.head_path_status ||
            push!(e, :factory_result_locator_status_mismatch)
        r.locator.working_tree_path_status == x.source_locator.working_tree_path_status ||
            push!(e, :factory_result_locator_status_mismatch)
        r.locator.working_tree_status == x.source_locator.working_tree_status ||
            push!(e, :factory_result_locator_status_mismatch)
        r.locator.head_blob_sha256 == x.source_locator.head_blob_sha256 ||
            push!(e, :factory_result_locator_head_blob_mismatch)
        r.locator.provenance == x.source_locator.provenance ||
            push!(e, :factory_result_locator_provenance_mismatch)
    catch
        push!(e, :factory_result_locator_mismatch)
    end
    r.declaration_ref == x.declaration_ref || push!(e, :factory_result_declaration_ref_mismatch)
    r.declaration_bytes.bytes == x.declaration_bytes.bytes ||
        push!(e, :factory_result_declaration_content_mismatch)
    r.declaration_bytes.sha256 == x.declaration_bytes.sha256 ||
        push!(e, :factory_result_declaration_content_mismatch)
    r.declaration_hash isa Digest256 || push!(e, :factory_result_declaration_hash_mismatch)
    r.declaration_hash == r.declaration_bytes.sha256 ||
        push!(e, :factory_result_declaration_hash_mismatch)
    expected_factory = try
        if r.factory_api === :G1
            isdefined(@__MODULE__, :G1_SOURCE_AUTHORITY_FACTORY_REF_V1) || nothing
            (G1_SOURCE_AUTHORITY_FACTORY_REF_V1, G1_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
        elseif r.factory_api === :G2
            isdefined(@__MODULE__, :G2_SOURCE_AUTHORITY_FACTORY_REF_V1) || nothing
            (G2_SOURCE_AUTHORITY_FACTORY_REF_V1, G2_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
        elseif r.factory_api === :G3
            isdefined(@__MODULE__, :G3_SOURCE_AUTHORITY_FACTORY_REF_V1) || nothing
            (G3_SOURCE_AUTHORITY_FACTORY_REF_V1, G3_SOURCE_AUTHORITY_FACTORY_VERSION_V1)
        elseif r.factory_api === :G3_FEEDBACK
            (VNEXT_T0_G3_FEEDBACK_FACTORY_REF_V1, VNEXT_T0_G3_FEEDBACK_FACTORY_VERSION_V1)
        else
            nothing
        end
    catch
        nothing
    end
    expected_factory === nothing && push!(e, :factory_dependency_missing)
    expected_factory === nothing || begin
        r.factory_id == expected_factory[1] || push!(e, :factory_result_id_mismatch)
        r.factory_version == expected_factory[2] || push!(e, :factory_result_version_mismatch)
    end
    if r.factory_api === :G2
        getproperty(x.semantic_body.body, :contract_ref) == r.contract_ref ||
            push!(e, :factory_result_contract_mismatch)
        try
            envelope = getproperty(x.semantic_body.body, :candidate_envelope)
            typed_source = getproperty(x.semantic_body.body, :source)
            typed_source isa G2MBSourceV1 ||
                push!(e, :factory_result_typed_source_invalid)
            envelope isa VNextT0LocalG2CandidateEnvelopeV1 ||
                push!(e, :factory_result_candidate_envelope_invalid)
            envelope.candidate_ref == candidate || push!(e, :factory_result_candidate_mismatch)
            envelope.contract_ref == r.contract_ref || push!(e, :factory_result_contract_mismatch)
            envelope.source_ref == r.source_ref || push!(e, :factory_result_source_ref_mismatch)
            if typed_source isa G2MBSourceV1
                typed_source.source_ref == r.source_ref ||
                    push!(e, :factory_result_source_ref_mismatch)
                typed_source.candidate_ref == r.contract_ref ||
                    push!(e, :factory_result_contract_mismatch)
                envelope.source_hash == typed_source.source_hash ||
                    push!(e, :factory_result_source_content_mismatch)
                typed_declaration = g2mb_declaration_v1(r.contract_ref, typed_source)
                typed_declaration.schema_hash ==
                    getproperty(x.semantic_body.body, :schema_hash) ||
                    push!(e, :factory_result_typed_declaration_mismatch)
                typed_declaration.canonicalization_hash ==
                    getproperty(x.semantic_body.body, :canonicalization_hash) ||
                    push!(e, :factory_result_typed_declaration_mismatch)
                typed_declaration.profile_hash ==
                    getproperty(x.semantic_body.body, :profile_hash) ||
                    push!(e, :factory_result_typed_declaration_mismatch)
                typed_declaration_bytes = Vector{UInt8}(
                    codeunits(canonical_json(typed_declaration)))
                typed_declaration_bytes == r.declaration_bytes.bytes ||
                    push!(e, :factory_result_typed_declaration_mismatch)
            end
        catch
            push!(e, :factory_result_typed_source_binding_invalid)
        end
    elseif r.factory_api === :G3
        try
            authorities = getproperty(x.semantic_body.body, :upstream_authority)
            all(a -> a.candidate_ref == candidate, authorities) ||
                push!(e, :factory_result_candidate_mismatch)
        catch
            push!(e, :factory_result_candidate_mismatch)
        end
    elseif r.factory_api === :G3_FEEDBACK
        r.contract_ref == vnext_t0_local_g3_feedback_contract_v1() ||
            push!(e, :factory_result_contract_mismatch)
        try
            getproperty(x.semantic_body.body, :candidate_ref) == candidate ||
                push!(e, :factory_result_candidate_mismatch)
            getproperty(x.semantic_body.body, :source_ref) == x.source_ref ||
                push!(e, :factory_result_source_ref_mismatch)
        catch
            push!(e, :factory_result_feedback_body_mismatch)
        end
    end
    r.axes isa NTuple{4,QualifiedRefV1} ||
        push!(e, :factory_result_axes_invalid)
    length(unique(canonical_hash(a).value for a in r.axes)) == 4 ||
        push!(e, :factory_result_axes_duplicate)
    g3_axes = try
        r.factory_api === :G3 ? g3_version_axes(:realization) : nothing
    catch
        nothing
    end
    expected_axes = r.factory_api === :G1 ?
        (QualifiedRefV1("fusion.g1.payload-schema", "v2"),
         QualifiedRefV1("fusion.g1.canonicalization", "v2"),
         QualifiedRefV1("fusion.g1.applicability", "v2"),
         QualifiedRefV1("fusion.g1.receipt", "v2")) : r.factory_api === :G2 ?
        (QualifiedRefV1("fusion.g2.payload-schema", "v5"),
         QualifiedRefV1("fusion.g2.canonicalization", "v5"),
         QualifiedRefV1("fusion.g2.applicability", "v5"),
         QualifiedRefV1("fusion.g2.receipt", "v5")) :
        r.factory_api === :G3 && g3_axes !== nothing ?
        (g3_axes.payload_schema_version, g3_axes.canonicalization_profile_version,
         g3_axes.applicability_profile_version, g3_axes.evidence_receipt_version) :
        r.factory_api === :G3_FEEDBACK ? VNEXT_T0_G3_FEEDBACK_AXES_V1 : ()
    r.axes == expected_axes || push!(e, :factory_result_axes_mismatch)
    try
        expected_contract = r.factory_api === :G1 ? _g1sf_expected_contract() :
            r.factory_api === :G2 ? _g2sf_expected_contract() :
            r.factory_api === :G3_FEEDBACK ? vnext_t0_local_g3_feedback_contract_v1() :
            g3_contract_ref(:realization)
        r.contract_ref == expected_contract || push!(e, :factory_result_contract_mismatch)
    catch
        push!(e, :factory_result_contract_mismatch)
    end
    r.status === :present || push!(e, :factory_result_status_mismatch)
    r.upstream_receipt_hash == _vnl_t0_sha(r.upstream_receipt_bytes.bytes) ||
        push!(e, :factory_result_upstream_receipt_hash_mismatch)
    r.content_identity == canonical_hash((factory_id=r.factory_id,
        factory_version=r.factory_version, factory_api=r.factory_api,
        candidate_ref=r.candidate_ref, layer=r.layer, source_ref=r.source_ref,
        source_bytes=r.source_bytes, source_size=r.source_size,
        locator=r.locator,
        locator_provenance=r.locator_provenance,
        declaration_ref=r.declaration_ref, declaration_bytes=r.declaration_bytes,
        declaration_hash=r.declaration_hash, status=r.status,
        contract_ref=r.contract_ref, axes=r.axes,
        upstream_receipt_bytes=r.upstream_receipt_bytes,
        upstream_receipt_hash=r.upstream_receipt_hash)) ||
        push!(e, :factory_result_content_identity_mismatch)
    unique!(e)
    e
end
function _vnl_t0_absent_errors(x::VNextT0LocalAbsentDeclarationV1, candidate)
    e = Symbol[]
    x.layer in VNEXT_T0_LOCAL_LAYERS_V1 || push!(e, :foreign_layer)
    x.candidate_ref == candidate || push!(e, :foreign_candidate)
    x.status in VNEXT_T0_LOCAL_DEFERRED_V1 || push!(e, :absence_status_invalid)
    x.reason in (:missing_material, :source_unavailable, :declaration_unavailable) || push!(e, :absence_reason_invalid)
    e
end
function _vnl_t0_child_errors(child, candidate, kind)
    e = Symbol[]
    child.kind === kind || push!(e, :child_kind_mismatch)
    if child isa VNextT0LocalChildPresentV1
        child.candidate_ref == candidate || push!(e, :child_candidate_mismatch)
        child.layer === :G3 || push!(e, :child_layer_invalid)
        child.child_id == String(kind) || push!(e, :child_id_mismatch)
        isempty(child.child_id) && push!(e, :child_id_missing)
        isempty(child.child_ref.id) && push!(e, :child_ref_missing)
        child.source_ref.id == child.source_locator.source_uri || push!(e, :child_source_uri_mismatch)
        child.source_bytes.sha256 == _vnl_t0_sha(child.source_bytes.bytes) || push!(e, :child_source_hash_mismatch)
        try
            _vnl_t0_locator_bytes(child.source_locator) == child.source_bytes.bytes || push!(e, :child_locator_bytes_mismatch)
        catch
            push!(e, :child_locator_unreadable_or_escape)
        end
        try
            child.body_hash == canonical_hash(child.body) || push!(e, :child_body_hash_mismatch)
            child.child_identity_hash == canonical_hash((candidate_ref=child.candidate_ref,
                layer=child.layer, child_id=child.child_id, kind=child.kind,
                child_ref=child.child_ref, body_hash=child.body_hash,
                source_ref=child.source_ref, source_sha256=child.source_bytes.sha256)) ||
                push!(e, :child_identity_hash_mismatch)
        catch
            push!(e, :child_body_invalid)
        end
    elseif child isa VNextT0LocalChildAbsentV1
        child.candidate_ref == candidate || push!(e, :child_candidate_mismatch)
        child.layer === :G3 || push!(e, :child_layer_invalid)
        isempty(child.child_id) && push!(e, :child_id_missing)
        child.child_id == String(kind) || push!(e, :child_id_mismatch)
         child.status in VNEXT_T0_LOCAL_DEFERRED_V1 || push!(e, :child_absence_status_invalid)
        isempty(child.reason) && push!(e, :child_absence_reason_missing)
        child.candidate_identity_created == false || push!(e, :child_candidate_identity_created)
        child.factory_api === :G3 || push!(e, :child_factory_api_invalid)
        child.factory_receipt_hash == _vnl_t0_sha(child.factory_receipt_bytes.bytes) ||
            push!(e, :child_factory_receipt_hash_mismatch)
        isempty(child.source_path) && push!(e, :child_source_path_missing)
    else
        push!(e, :child_type_invalid)
    end
    e
end
function _vnl_t0_feedback_errors(feedback, candidate, declarations)
    e = Symbol[]
    feedback isa Tuple || return [:feedback_not_tuple]
    ids = String[]
    for item in feedback
        item isa VNextT0LocalFeedbackV1 || (push!(e, :feedback_type_invalid); continue)
        item.candidate_ref == candidate || push!(e, :feedback_candidate_mismatch)
        item.target_layer in (:G1, :G2) || push!(e, :feedback_layer_invalid)
        target = findfirst(x -> x.layer === item.target_layer, declarations)
        if target === nothing || !(declarations[target] isa VNextT0LocalPresentDeclarationV1)
            push!(e, :feedback_target_material_missing)
        else
            target_record = declarations[target]
            item.target_ref == target_record.source_ref || item.target_ref == target_record.declaration_ref ||
                push!(e, :feedback_target_ref_mismatch)
        end
        try
            item.body_hash == canonical_hash(item.body) || push!(e, :feedback_body_hash_mismatch)
        catch
            push!(e, :feedback_body_invalid)
        end
        item.target_id in ids && push!(e, :duplicate_feedback)
        push!(ids, item.target_id)
    end
    e
end

function _vnl_t0_edit_ref(ref::QualifiedRefV1, digest::Digest256, kind::Symbol)
    QualifiedRefV1(string(ref.id, "#", String(kind), "-", digest.value[1:16]), ref.version)
end
function _vnl_t0_edit_candidate(ref::QualifiedRefV1, digest::Digest256)
    QualifiedRefV1(string(ref.id, "#source-edit-", digest.value[1:16]), ref.version)
end
function _vnl_t0_receipt_bytes(kind, layer, candidate, source_ref, declaration_ref, axes,
        source_sha, declaration_sha)
    payload = (kind=kind, layer=layer, candidate_ref=candidate, source_ref=source_ref,
        declaration_ref=declaration_ref, axes=axes, source_sha256=source_sha,
        declaration_sha256=declaration_sha)
    b = Vector{UInt8}(codeunits(canonical_json(payload)))
    VNextT0LocalBytesV1(b, _vnl_t0_sha(b))
end
function _vnl_t0_rebind_record(x::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1; source_bytes=x.source_bytes, semantic_body=x.semantic_body,
        source_locator=nothing, factory_api=x.factory_receipt.factory_api,
        factory_result::VNextT0LocalFactoryResultV1=x.factory_receipt.factory_result,
        declaration_factory_api=x.declaration_receipt.factory_api,
        declaration_factory_result::VNextT0LocalFactoryResultV1=x.declaration_receipt.factory_result)
    factory_api in (:G1, :G2, :G3, :G3_FEEDBACK) || throw(ArgumentError("rebind requires a real factory_api"))
    declaration_factory_api in (:G1, :G2, :G3, :G3_FEEDBACK) || throw(ArgumentError("rebind requires a real declaration factory_api"))
    factory_result.factory_api == factory_api || throw(ArgumentError("factory_result api mismatch"))
    declaration_factory_result.factory_api == declaration_factory_api ||
        throw(ArgumentError("declaration factory_result api mismatch"))
    factory_result.candidate_ref == candidate || throw(ArgumentError("rebind factory candidate mismatch"))
    declaration_factory_result.candidate_ref == candidate ||
        throw(ArgumentError("rebind declaration factory candidate mismatch"))
    factory_result.layer == x.layer || throw(ArgumentError("rebind factory layer mismatch"))
    declaration_factory_result.layer == x.layer ||
        throw(ArgumentError("rebind declaration factory layer mismatch"))
    source_sha = _vnl_t0_sha(source_bytes.bytes)
    factory_result.source_ref == declaration_factory_result.source_ref ||
        throw(ArgumentError("rebind factory source ref mismatch"))
    factory_result.declaration_ref == declaration_factory_result.declaration_ref ||
        throw(ArgumentError("rebind factory declaration ref mismatch"))
    factory_result.declaration_bytes.bytes == declaration_factory_result.declaration_bytes.bytes ||
        throw(ArgumentError("rebind factory declaration bytes mismatch"))
    declaration_bytes = factory_result.declaration_bytes
    declaration_sha = declaration_bytes.sha256
    source_ref = factory_result.source_ref
    declaration_ref = factory_result.declaration_ref
    locator = source_locator === nothing ? VNextT0LocalSourceLocatorV1(x.source_locator.repository_root,
        x.source_locator.source_path, source_ref.id, source_ref, length(source_bytes.bytes), source_sha,
        x.source_locator.observed_head, x.source_locator.head_path_status,
        x.source_locator.working_tree_path_status, x.source_locator.working_tree_status,
        x.source_locator.head_blob_sha256, x.source_locator.provenance) : source_locator
    locator.source_ref == factory_result.source_ref ||
        throw(ArgumentError("rebind locator source ref mismatch"))
    factory = VNextT0LocalFactoryReceiptV1(
        candidate, x.layer, source_ref, declaration_ref, x.axes, :present,
        factory_result)
    declaration = VNextT0LocalDeclarationReceiptV1(
        candidate, x.layer, source_ref, declaration_ref, x.axes, :present,
        declaration_factory_result)
    VNextT0LocalPresentDeclarationV1(x.layer, candidate, source_ref, declaration_ref,
        canonical_hash((kind=:source, ref=source_ref, bytes_sha256=source_sha)),
        canonical_hash((kind=:declaration, ref=declaration_ref, bytes_sha256=declaration_sha)),
        x.axes, source_bytes, declaration_bytes, semantic_body, locator, factory, declaration)
end

function _vnl_t0_edit_refs(x::VNextT0LocalPresentDeclarationV1,
        candidate::QualifiedRefV1, source_sha::Digest256, declaration_sha::Digest256)
    (_vnl_t0_edit_ref(x.source_ref, source_sha, :source),
     _vnl_t0_edit_ref(x.declaration_ref, declaration_sha, :declaration))
end

function _vnl_t0_semantic_rebind_candidate(body::VNextT0LocalSemanticBodyV1,
        candidate::QualifiedRefV1, source_ref::Union{Nothing,QualifiedRefV1}=nothing)
    hasproperty(body.body, :candidate_ref) ||
        throw(ArgumentError("semantic body has no candidate binding field"))
    original_candidate = body.body.candidate_ref
    original_source_ref = hasproperty(body.body, :source_ref) ? body.body.source_ref : nothing

    # R20c: G3 feedback owns two candidate-projection collections.  Rebuild
    # them from a strictly validated original declaration; a generic merge
    # would silently carry stale/actual/contradictory authorities forward.
    if hasproperty(body.body, :upstream_authority) &&
            hasproperty(body.body, :feedback_targets)
        source_ref !== nothing ||
            throw(ArgumentError("G3 feedback semantic rebind requires a fresh source_ref"))
        rebound = _vnl_t0_g3_feedback_semantic_rebind_v1(body.body, candidate, source_ref)
        return VNextT0LocalSemanticBodyV1(rebound.body,
            rebound.bytes, body.labels)
    end

    # R20b: G2 carries two candidate identity domains in one semantic body.
    # Validate the old typed join before changing anything, then rebuild every
    # G2 identity/hash from a fresh typed source.  In particular, do not let a
    # generic merge preserve stale declaration/profile fields or confuse the
    # package candidate ref with the v5 G2 contract ref.
    if hasproperty(body.body, :candidate_envelope)
        g2_fields = (:candidate_ref, :candidate_envelope, :contract_ref, :source,
            :schema_hash, :canonicalization_hash, :profile_hash, :declaration_hash)
        all(hasproperty(body.body, field) for field in g2_fields) ||
            throw(ArgumentError("G2 semantic body shape is incomplete"))
        source_ref !== nothing ||
            throw(ArgumentError("G2 semantic rebind requires a fresh source_ref"))
        original_candidate isa QualifiedRefV1 ||
            throw(ArgumentError("G2 semantic body candidate_ref must be typed"))
        source_ref isa QualifiedRefV1 ||
            throw(ArgumentError("G2 semantic rebind source_ref must be typed"))
        envelope = body.body.candidate_envelope
        source = body.body.source
        contract_ref = body.body.contract_ref
        envelope isa VNextT0LocalG2CandidateEnvelopeV1 ||
            throw(ArgumentError("G2 semantic body candidate_envelope must be typed"))
        source isa G2MBSourceV1 ||
            throw(ArgumentError("G2 semantic body source must be typed"))
        contract_ref isa GenomeContractRef ||
            throw(ArgumentError("G2 semantic body contract_ref must be typed"))
        contract_ref == _g2sf_expected_contract() ||
            throw(ArgumentError("G2 semantic body contract_ref is not the expected G2 contract"))
        envelope.candidate_ref == original_candidate ||
            throw(ArgumentError("G2 semantic body envelope candidate binding is stale"))
        envelope.contract_ref == contract_ref ||
            throw(ArgumentError("G2 semantic body envelope contract binding is stale"))
        source.candidate_ref == contract_ref ||
            throw(ArgumentError("G2 semantic body source candidate/contract domains are confused"))
        source.source_ref == envelope.source_ref ||
            throw(ArgumentError("G2 semantic body envelope/source ref mismatch"))
        source.source_hash == envelope.source_hash ||
            throw(ArgumentError("G2 semantic body envelope/source hash mismatch"))
        source.source_hash == canonical_hash(_g2mb_source_body(source.source_ref,
            source.source_version, source.candidate_ref, source.chart_map, source.mesh,
            source.faces, source.profile, source.units, source.authority)) ||
            throw(ArgumentError("G2 semantic body typed source hash is stale"))
        old_declaration = try
            g2mb_declaration_v1(contract_ref, source)
        catch err
            throw(ArgumentError("G2 semantic body declaration is not rebindable: " *
                sprint(showerror, err)))
        end
        body.body.schema_hash == old_declaration.schema_hash ||
            throw(ArgumentError("G2 semantic body schema hash is stale"))
        body.body.canonicalization_hash == old_declaration.canonicalization_hash ||
            throw(ArgumentError("G2 semantic body canonicalization hash is stale"))
        body.body.profile_hash == old_declaration.profile_hash ||
            throw(ArgumentError("G2 semantic body profile hash is stale"))
        body.body.declaration_hash == old_declaration.declaration_hash ||
            throw(ArgumentError("G2 semantic body declaration hash is stale"))
        fresh_source = g2mb_source_v1(source_ref, source.source_version, contract_ref,
            source.chart_map, source.mesh, source.faces, source.profile, source.units,
            source.authority)
        fresh_declaration = g2mb_declaration_v1(contract_ref, fresh_source)
        fresh_envelope = VNextT0LocalG2CandidateEnvelopeV1(candidate, contract_ref,
            fresh_source.source_ref, fresh_source.source_hash)
        rebound = merge(body.body, (candidate_ref=candidate,
            candidate_envelope=fresh_envelope, contract_ref=contract_ref,
            source=fresh_source, schema_hash=fresh_declaration.schema_hash,
            canonicalization_hash=fresh_declaration.canonicalization_hash,
            profile_hash=fresh_declaration.profile_hash,
            declaration_hash=fresh_declaration.declaration_hash))
        bytes = Vector{UInt8}(codeunits(canonical_json(rebound)))
        return VNextT0LocalSemanticBodyV1(rebound,
            VNextT0LocalBytesV1(bytes, _vnl_t0_sha(bytes)), body.labels)
    end
    rebound = merge(body.body, (candidate_ref=candidate,))
    if source_ref !== nothing && hasproperty(rebound, :source_ref)
        rebound = merge(rebound, (source_ref=source_ref,))
    end
    if hasproperty(rebound, :source_payload)
        source_ref !== nothing ||
            throw(ArgumentError("G1 semantic rebind requires a fresh source_ref"))
        g1_fields = (:source_version, :source_payload, :source_hash, :u, :K, :f,
            :operators, :closure_ref, :applicability_ref, :applicability_domain,
            :ownership, :negative_controls, :candidate_ref, :source_ref)
        all(hasproperty(rebound, field) for field in g1_fields) ||
            throw(ArgumentError("G1 semantic body shape is incomplete"))
        old_candidate = original_candidate
        old_source_ref = original_source_ref
        old_candidate isa QualifiedRefV1 ||
            throw(ArgumentError("G1 semantic body candidate_ref must be typed"))
        old_source_ref isa QualifiedRefV1 ||
            throw(ArgumentError("G1 semantic body source_ref must be typed"))
        payload = rebound.source_payload
        payload isa G1DiffusionSourcePayloadV1 ||
            throw(ArgumentError("G1 semantic body source_payload must be typed"))
        rebound.u isa G1DiffusionScalarFieldV1 ||
            throw(ArgumentError("G1 semantic body u must be typed"))
        rebound.K isa G1DiffusionCoefficientFieldV1 ||
            throw(ArgumentError("G1 semantic body K must be typed"))
        rebound.f isa G1DiffusionScalarFieldV1 ||
            throw(ArgumentError("G1 semantic body f must be typed"))
        rebound.source_version isa String ||
            throw(ArgumentError("G1 semantic body source_version must be typed"))
        payload.source_version == String(rebound.source_version) ||
            throw(ArgumentError("G1 semantic body source version mismatch"))
        payload.candidate_ref == old_candidate ||
            throw(ArgumentError("G1 semantic body source payload candidate binding is stale"))
        payload.source_ref == old_source_ref ||
            throw(ArgumentError("G1 semantic body source payload source binding is stale"))
        rebound.u.source_ref == old_source_ref ||
            throw(ArgumentError("G1 semantic body u source binding is stale"))
        rebound.K.source_ref == old_source_ref ||
            throw(ArgumentError("G1 semantic body K source binding is stale"))
        rebound.f.source_ref == old_source_ref ||
            throw(ArgumentError("G1 semantic body f source binding is stale"))
        canonical_hash(payload.u) == canonical_hash(rebound.u) ||
            throw(ArgumentError("G1 semantic body u disagrees with source payload"))
        canonical_hash(payload.K) == canonical_hash(rebound.K) ||
            throw(ArgumentError("G1 semantic body K disagrees with source payload"))
        canonical_hash(payload.f) == canonical_hash(rebound.f) ||
            throw(ArgumentError("G1 semantic body f disagrees with source payload"))
        rebound.source_hash isa Digest256 ||
            throw(ArgumentError("G1 semantic body source_hash must be typed"))
        rebound.source_hash == g1_diffusion_source_hash_v1(payload) ||
            throw(ArgumentError("G1 semantic body source hash is stale"))
        old_declaration = try
            g1_diffusion_declaration_v1(old_candidate, old_source_ref,
                rebound.source_version, rebound.source_hash, rebound.u, rebound.K,
                rebound.f, rebound.operators, rebound.closure_ref,
                rebound.applicability_ref, rebound.applicability_domain,
                rebound.negative_controls; ownership=rebound.ownership,
                source_payload=payload)
        catch err
            throw(ArgumentError("G1 semantic body declaration is not rebindable: " *
                sprint(showerror, err)))
        end
        old_validation_status, old_validation_errors = g1_diffusion_validate(old_declaration)
        old_validation_status === :valid ||
            throw(ArgumentError("G1 semantic body validator failed: " *
                join(old_validation_errors, ",")))
        fresh_u = G1DiffusionScalarFieldV1(rebound.u.field_id, rebound.u.physical_type,
            source_ref; source_expression=rebound.u.source_expression)
        fresh_K = G1DiffusionCoefficientFieldV1(rebound.K.field_id,
            rebound.K.physical_type, source_ref;
            spatial_dependency=rebound.K.spatial_dependency,
            symmetry=rebound.K.symmetry, positive_definite=rebound.K.positive_definite,
            lower_bound=rebound.K.lower_bound, upper_bound=rebound.K.upper_bound,
            expression=rebound.K.expression)
        fresh_f = G1DiffusionScalarFieldV1(rebound.f.field_id, rebound.f.physical_type,
            source_ref; source_expression=rebound.f.source_expression)
        fresh_payload = G1DiffusionSourcePayloadV1(candidate, source_ref,
            rebound.source_version, fresh_u, fresh_K, fresh_f)
        fresh_source_hash = g1_diffusion_source_hash_v1(fresh_payload)
        fresh_declaration = g1_diffusion_declaration_v1(candidate, source_ref,
            rebound.source_version, fresh_source_hash, fresh_u, fresh_K, fresh_f,
            rebound.operators, rebound.closure_ref, rebound.applicability_ref,
            rebound.applicability_domain, rebound.negative_controls;
            ownership=rebound.ownership, source_payload=fresh_payload)
        validation_status, validation_errors = g1_diffusion_validate(fresh_declaration)
        validation_status === :valid ||
            throw(ArgumentError("G1 semantic rebind validator failed:" *
                join(validation_errors, ",")))
        rebound = merge(rebound, (source_payload=fresh_payload,
            source_hash=fresh_source_hash, u=fresh_u, K=fresh_K, f=fresh_f))
    end
    if source_ref !== nothing && hasproperty(rebound, :candidate_envelope)
        envelope = rebound.candidate_envelope
        rebound = merge(rebound, (candidate_envelope=
            VNextT0LocalG2CandidateEnvelopeV1(candidate, envelope.contract_ref,
                source_ref, envelope.source_hash),))
    end
    bytes = Vector{UInt8}(codeunits(canonical_json(rebound)))
    VNextT0LocalSemanticBodyV1(rebound, VNextT0LocalBytesV1(bytes, _vnl_t0_sha(bytes)), body.labels)
end

function _vnl_t0_factory_pair(factory_builder, candidate, record, source_ref,
        declaration_ref, source_bytes, semantic_body, source_locator)
    factory_builder isa Function ||
        throw(ArgumentError("fresh source edit requires an explicit factory_builder"))
    pair = factory_builder(candidate, record.layer, source_ref, declaration_ref,
        source_bytes, semantic_body, source_locator)
    pair isa Tuple && length(pair) == 2 ||
        throw(ArgumentError("factory_builder must return (factory_result, declaration_factory_result)"))
    pair[1] === nothing && throw(ArgumentError("factory_builder returned missing factory_result"))
    pair[2] === nothing && throw(ArgumentError("factory_builder returned missing declaration_factory_result"))
    pair[1] isa VNextT0LocalFactoryResultV1 ||
        throw(ArgumentError("factory_builder returned unnormalized factory_result"))
    pair[2] isa VNextT0LocalFactoryResultV1 ||
        throw(ArgumentError("factory_builder returned unnormalized declaration_factory_result"))
    pair[1].candidate_ref == candidate ||
        throw(ArgumentError("factory_builder candidate binding mismatch"))
    pair[2].candidate_ref == candidate ||
        throw(ArgumentError("factory_builder declaration candidate binding mismatch"))
    pair[1].layer == record.layer || throw(ArgumentError("factory_builder layer binding mismatch"))
    pair[2].layer == record.layer ||
        throw(ArgumentError("factory_builder declaration layer binding mismatch"))
    pair[1].source_ref == source_ref ||
        throw(ArgumentError("factory_builder source binding mismatch"))
    pair[2].source_ref == source_ref ||
        throw(ArgumentError("factory_builder declaration source binding mismatch"))
    pair[1].source_bytes.bytes == source_bytes.bytes ||
        throw(ArgumentError("factory_builder source bytes binding mismatch"))
    pair[2].source_bytes.bytes == source_bytes.bytes ||
        throw(ArgumentError("factory_builder declaration source bytes binding mismatch"))
    pair[1].locator == source_locator ||
        throw(ArgumentError("factory_builder locator binding mismatch"))
    pair[2].locator == source_locator ||
        throw(ArgumentError("factory_builder declaration locator binding mismatch"))
    pair[1].declaration_ref == pair[2].declaration_ref ||
        throw(ArgumentError("factory_builder declaration binding mismatch"))
    pair
end

"""Rebind a source edit into fresh candidate/source/declaration identities.

The returned record is deliberately not published.  A caller must pass the
fresh candidate and all three records through the same T0 builder again.
"""
function vnext_t0_local_source_edit_v1(record::VNextT0LocalPresentDeclarationV1,
        new_source_bytes::VNextT0LocalBytesV1, new_semantic_body::VNextT0LocalSemanticBodyV1;
        new_source_locator=nothing, factory_builder=nothing)
    old_source = record.source_bytes.sha256
    old_decl = record.declaration_bytes.sha256
    new_source = _vnl_t0_sha(new_source_bytes.bytes)
    new_decl = _vnl_t0_sha(_vnl_t0_semantic_bytes(new_semantic_body))
    seed = canonical_hash((old_candidate=record.candidate_ref, old_source=old_source,
        old_declaration=old_decl, new_source=new_source, new_declaration=new_decl))
    candidate = _vnl_t0_edit_candidate(record.candidate_ref, seed)
    source_ref, declaration_ref = _vnl_t0_edit_refs(record, candidate, new_source, new_decl)
    fresh_locator = new_source_locator === nothing ? VNextT0LocalSourceLocatorV1(
        record.source_locator.repository_root, record.source_locator.source_path,
        source_ref.id, source_ref, length(new_source_bytes.bytes), new_source,
        record.source_locator.observed_head, record.source_locator.head_path_status,
        record.source_locator.working_tree_path_status, record.source_locator.working_tree_status,
        record.source_locator.head_blob_sha256, record.source_locator.provenance) : new_source_locator
    fresh_locator.source_ref == source_ref || throw(ArgumentError("source edit locator ref mismatch"))
    fresh_semantic_body = _vnl_t0_semantic_rebind_candidate(new_semantic_body, candidate, source_ref)
    factory_result, declaration_factory_result = _vnl_t0_factory_pair(factory_builder,
        candidate, record, source_ref, declaration_ref, new_source_bytes,
        fresh_semantic_body, fresh_locator)
    source_ref == factory_result.source_ref || throw(ArgumentError("fresh factory source ref mismatch"))
    factory_result.declaration_ref == declaration_factory_result.declaration_ref ||
        throw(ArgumentError("fresh factory declaration ref mismatch"))
    edited = _vnl_t0_rebind_record(record, candidate;
        source_bytes=VNextT0LocalBytesV1(new_source_bytes.bytes, new_source),
        semantic_body=fresh_semantic_body, source_locator=fresh_locator,
        factory_api=record.factory_receipt.factory_api, factory_result=factory_result,
        declaration_factory_api=record.declaration_receipt.factory_api,
        declaration_factory_result=declaration_factory_result)
    VNextT0LocalSourceEditResultV1(record.candidate_ref, candidate, record.source_ref,
        edited.source_ref, record.declaration_ref, edited.declaration_ref,
        record.source_identity_hash, edited.source_identity_hash,
        record.declaration_identity_hash, edited.declaration_identity_hash, edited)
end

function _vnl_t0_bundle_body_v1(candidate, declarations, children, feedback)
    (schema_id=VNEXT_T0_LOCAL_SCHEMA_ID_V1, schema_version=VNEXT_T0_LOCAL_SCHEMA_VERSION_V1,
        candidate_ref=candidate, declarations=Tuple(declarations), children=Tuple(children),
        feedback=Tuple(sort!(collect(feedback), by=x -> x.target_id)))
end

function _vnl_t0_rebind_absent_child_v1(child::VNextT0LocalChildAbsentV1,
        old_candidate::QualifiedRefV1, fresh_candidate::QualifiedRefV1)
    child.candidate_ref == old_candidate || throw(ArgumentError("child_candidate_mismatch"))
    child.kind in VNEXT_T0_LOCAL_CHILD_KINDS_V1 || throw(ArgumentError("child_kind_invalid"))
    child.layer === :G3 || throw(ArgumentError("child_layer_invalid"))
    child.child_id == String(child.kind) || throw(ArgumentError("child_id_mismatch"))
    child.status in VNEXT_T0_LOCAL_DEFERRED_V1 || throw(ArgumentError("child_status_not_rebindable"))
    child.candidate_identity_created == false ||
        throw(ArgumentError("typed_absent_child_candidate_identity_created"))
    child.factory_api === :G3 || throw(ArgumentError("typed_absent_child_factory_api_invalid"))
    isempty(child.factory_receipt_bytes.bytes) &&
        throw(ArgumentError("typed_absent_child_receipt_missing"))
    child.factory_receipt_hash == _vnl_t0_sha(child.factory_receipt_bytes.bytes) ||
        throw(ArgumentError("typed_absent_child_receipt_hash_mismatch"))
    isempty(child.source_path) && throw(ArgumentError("typed_absent_child_source_path_missing"))
    VNextT0LocalChildAbsentV1(child.kind, fresh_candidate, child.layer, child.child_id,
        child.status, child.reason, false, child.factory_api, child.factory_receipt_bytes,
        child.factory_receipt_hash, child.source_path)
end

function _vnl_t0_rebind_feedback_item_v1(item::VNextT0LocalFeedbackV1,
        old_candidate::QualifiedRefV1, fresh_candidate::QualifiedRefV1,
        declarations::Tuple, fresh_declarations::Tuple)
    item.candidate_ref == old_candidate || throw(ArgumentError("feedback_candidate_mismatch"))
    item.body_hash == canonical_hash(item.body) ||
        throw(ArgumentError("feedback_body_hash_mismatch"))
    old_index = findfirst(x -> x.layer === item.target_layer, declarations)
    fresh_index = findfirst(x -> x.layer === item.target_layer, fresh_declarations)
    (old_index === nothing || fresh_index === nothing) &&
        throw(ArgumentError("feedback_target_material_missing"))
    old_record = declarations[old_index]
    fresh_record = fresh_declarations[fresh_index]
    old_record isa VNextT0LocalPresentDeclarationV1 ||
        throw(ArgumentError("feedback_target_material_missing"))
    fresh_record isa VNextT0LocalPresentDeclarationV1 ||
        throw(ArgumentError("feedback_target_material_missing"))
    source_match = item.target_ref == old_record.source_ref
    declaration_match = item.target_ref == old_record.declaration_ref
    (source_match ⊻ declaration_match) ||
        throw(ArgumentError(source_match || declaration_match ?
            "feedback_target_ref_ambiguous" : "feedback_target_ref_unknown"))
    fresh_ref = source_match ? fresh_record.source_ref : fresh_record.declaration_ref
    body = item.body
    if hasproperty(body, :candidate_ref)
        body.candidate_ref == old_candidate ||
            throw(ArgumentError("feedback_body_candidate_mismatch"))
        body = merge(body, (candidate_ref=fresh_candidate,))
    end
    if hasproperty(body, :source_ref)
        body.source_ref == old_record.source_ref ||
            throw(ArgumentError("feedback_body_source_ref_mismatch"))
        body = merge(body, (source_ref=fresh_record.source_ref,))
    end
    if hasproperty(body, :declaration_ref)
        body.declaration_ref == old_record.declaration_ref ||
            throw(ArgumentError("feedback_body_declaration_ref_mismatch"))
        body = merge(body, (declaration_ref=fresh_record.declaration_ref,))
    end
    VNextT0LocalFeedbackV1(item.target_id, item.target_layer, fresh_candidate,
        fresh_ref, body, canonical_hash(body))
end
function vnext_t0_local_bundle_hash_recompute_v1(x::VNextT0LocalTransportV1)
    canonical_hash(_vnl_t0_bundle_body_v1(x.candidate_ref, x.declarations, x.children, x.feedback))
end

"""Rebuild all three declarations, children and feedback after one source edit."""
function _vnl_t0_rebuild_after_source_edit_impl_v1(candidate::QualifiedRefV1,
        declarations::Tuple, children::Tuple, feedback::Tuple, layer::Symbol,
        new_source_bytes::VNextT0LocalBytesV1, new_semantic_body::VNextT0LocalSemanticBodyV1;
        new_source_locator=nothing, factory_builder=nothing)
    factory_builder isa Function ||
        throw(ArgumentError("source edit rebuild requires fresh factory_builder"))
    target = findfirst(x -> x.layer === layer, declarations)
    target === nothing && throw(ArgumentError("source edit layer is absent"))
    declarations[target] isa VNextT0LocalPresentDeclarationV1 ||
        throw(ArgumentError("source edit requires a present declaration"))
    edit = vnext_t0_local_source_edit_v1(declarations[target], new_source_bytes,
        new_semantic_body; new_source_locator=new_source_locator,
        factory_builder=factory_builder)
    fresh_candidate = edit.new_candidate_ref
    fresh_declarations = ntuple(i -> begin
        x = declarations[i]
        if i == target
            edit.edited_declaration
        elseif x isa VNextT0LocalPresentDeclarationV1
            source_sha = x.source_bytes.sha256
            declaration_sha = x.declaration_bytes.sha256
            source_ref, declaration_ref = _vnl_t0_edit_refs(x, fresh_candidate,
                source_sha, declaration_sha)
            fresh_locator = VNextT0LocalSourceLocatorV1(
                x.source_locator.repository_root, x.source_locator.source_path,
                source_ref.id, source_ref, length(x.source_bytes.bytes), source_sha,
                x.source_locator.observed_head, x.source_locator.head_path_status,
                x.source_locator.working_tree_path_status, x.source_locator.working_tree_status,
                x.source_locator.head_blob_sha256, x.source_locator.provenance)
            fresh_semantic_body = _vnl_t0_semantic_rebind_candidate(x.semantic_body, fresh_candidate, source_ref)
            pair = _vnl_t0_factory_pair(factory_builder, fresh_candidate, x,
                source_ref, declaration_ref, x.source_bytes, fresh_semantic_body,
                fresh_locator)
            _vnl_t0_rebind_record(x, fresh_candidate;
                semantic_body=fresh_semantic_body, source_locator=fresh_locator, factory_result=pair[1],
                declaration_factory_result=pair[2])
        else
            x
        end
    end, 3)
    fresh_children = ntuple(i -> begin
        child = children[i]
        child isa VNextT0LocalChildPresentV1 &&
            throw(ArgumentError("present_g3_child_requires_fresh_receipt"))
        _vnl_t0_rebind_absent_child_v1(child, candidate, fresh_candidate)
    end, 3)
    fresh_feedback = Tuple(_vnl_t0_rebind_feedback_item_v1(item, candidate,
        fresh_candidate, declarations, fresh_declarations) for item in feedback)
    admission = vnext_declaration_transport_local_v1(fresh_candidate,
        fresh_declarations, fresh_children, fresh_feedback)
    (edit=edit, admission=admission)
end

"""Public source-edit boundary: builder failures are fail-closed data."""
function vnext_t0_local_rebuild_after_source_edit_v1(candidate::QualifiedRefV1,
        declarations::Tuple, children::Tuple, feedback::Tuple, layer::Symbol,
        new_source_bytes::VNextT0LocalBytesV1,
        new_semantic_body::VNextT0LocalSemanticBodyV1; kwargs...)
    try
        _vnl_t0_rebuild_after_source_edit_impl_v1(candidate, declarations, children,
            feedback, layer, new_source_bytes, new_semantic_body; kwargs...)
    catch err
        message = sprint(showerror, err)
        has_code(token) = findfirst(token, message) !== nothing
        code = has_code("present_g3_child_requires_fresh_receipt") ?
            :present_g3_child_requires_fresh_receipt :
            has_code("feedback_target_ref_ambiguous") ?
            :feedback_target_ref_ambiguous :
            has_code("feedback_target_ref_unknown") ?
            :feedback_target_ref_unknown : :factory_builder_fail_closed
        (edit=nothing, admission=VNextT0LocalAdmissionV1(
            :fail_closed, :fail_closed, false, :contract_only, nothing,
            (code,), ()))
    end
end

"""Build a local T0 bundle; all errors are returned without partial output."""
function vnext_declaration_transport_local_v1(candidate::QualifiedRefV1,
        declarations::Tuple, children::Tuple, feedback::Tuple=())
    errors = Symbol[]; gaps = Symbol[]
    length(declarations) == 3 || push!(errors, :declaration_arity_invalid)
    length(children) == 3 || push!(errors, :child_arity_invalid)
    length(declarations) == 3 || return VNextT0LocalAdmissionV1(:fail_closed, :fail_closed, false, :contract_only, nothing, (:declaration_arity_invalid,), ())
    length(children) == 3 || return VNextT0LocalAdmissionV1(:fail_closed, :fail_closed, false, :contract_only, nothing, (:child_arity_invalid,), ())
    declarations_typed = all(x -> x isa VNextT0LocalDeclarationV1, declarations)
    children_typed = all(x -> x isa VNextT0LocalChildV1, children)
    declarations_typed || push!(errors, :declaration_type_invalid)
    children_typed || push!(errors, :child_type_invalid)
    if declarations_typed
        layers = sort!([x.layer for x in declarations], by=String)
        layers == sort!(collect(VNEXT_T0_LOCAL_LAYERS_V1), by=String) || push!(errors, :layer_set_invalid)
    end
    if children_typed
        childkinds = sort!([x.kind for x in children], by=String)
        childkinds == sort!(collect(VNEXT_T0_LOCAL_CHILD_KINDS_V1), by=String) || push!(errors, :child_set_invalid)
    end
    (!declarations_typed || !children_typed) &&
        return VNextT0LocalAdmissionV1(:fail_closed, :fail_closed, false, :contract_only, nothing,
            Tuple(unique(errors)), ())
    for x in declarations
        append!(errors, x isa VNextT0LocalPresentDeclarationV1 ? _vnl_t0_errors(x, candidate) : _vnl_t0_absent_errors(x, candidate))
    end
    for kind in VNEXT_T0_LOCAL_CHILD_KINDS_V1
        if children_typed
            index = findfirst(x -> x.kind === kind, children)
            index === nothing || append!(errors, _vnl_t0_child_errors(children[index], candidate, kind))
        end
    end
    append!(errors, _vnl_t0_feedback_errors(feedback, candidate, declarations))
    unique!(errors)
    any(x -> x isa VNextT0LocalAbsentDeclarationV1, declarations) && push!(gaps, :declaration_material_terminal_deferred)
    any(x -> x isa VNextT0LocalChildAbsentV1, children) && push!(gaps, :g3_child_terminal_deferred)
    declarations = sort!(collect(declarations), by=x -> findfirst(==(x.layer), VNEXT_T0_LOCAL_LAYERS_V1))
    children = sort!(collect(children), by=x -> findfirst(==(x.kind), VNEXT_T0_LOCAL_CHILD_KINDS_V1))
    if !isempty(errors)
        return VNextT0LocalAdmissionV1(:fail_closed, :fail_closed, false, :contract_only, nothing, Tuple(errors), Tuple(gaps))
    end
    body = _vnl_t0_bundle_body_v1(candidate, declarations, children, feedback)
    bundle_hash = canonical_hash(body)
    transport = VNextT0LocalTransportV1(candidate, Tuple(declarations), Tuple(children), Tuple(sort!(collect(feedback), by=x -> x.target_id)), bundle_hash,
        :valid, (), Tuple(gaps))
    resolution = isempty(gaps) ? :local_contract_ready : :terminal_deferred
    VNextT0LocalAdmissionV1(:valid, resolution, false, :contract_only, transport, (), Tuple(gaps))
end
