"""Definition-only adapter from the checked VNext T1 package to V2 input.

This file is intentionally not included by the shared module entrypoint.  It
does not construct a package, call a legacy physical-binding path, invoke a
registry/provider, or execute a runtime.  The adapter only re-checks the closed package joins that are needed
for the narrow identity mapping

    candidate_ref / semantic_identity / package_hash
        -> VNextT1CandidateBindingInputV2

The package remains ``prepared_not_executed`` and ``terminal_deferred``.  A
typed-absent G3 child is never turned into a V2 binding input.
"""

const VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1 =
    "FusionConceptAI/GenomeV5/VNextT1PackageBindingAdapterV1"
const VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1 =
    "GenomeV5/Contracts/VNextT1PackageBindingAdapter"
const VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1 = "v1"
const VNEXT_T1_PACKAGE_BINDING_ADAPTER_CLAIM_CEILING_V1 = :contract_only
const VNEXT_T1_PACKAGE_BINDING_ADAPTER_RECEIPT_DOMAIN_V1 =
    "FusionConceptAI/GenomeV5/VNextT1PackageBindingAdapterV1/receipt/v1"

const _VNEXT_T1_PACKAGE_BINDING_ADAPTER_REASONS_V1 = (
    prepared_not_executed=(:mapped_prepared_not_executed,),
    terminal_deferred=(:g3_typed_absent,),
    fail_closed=(:package_status_conflict, :package_resolution_conflict,
        :package_acceptance_conflict, :package_claim_ceiling_conflict,
        :candidate_ref_conflict, :component_structure_conflict,
        :component_identity_mismatch, :semantic_identity_mismatch,
        :package_hash_mismatch, :g3_absence_conflict),
)

"""Closed adapter result; no result is accepted or physically authoritative."""
struct VNextT1PackageBindingAdapterResultV1
    domain::String
    schema::String
    version::String
    status::Symbol
    resolution::Symbol
    reason::Symbol
    package_status::Symbol
    package_resolution::Symbol
    candidate_ref::QualifiedRefV1
    candidate_digest::Digest256
    source_package_hash::Digest256
    wire_hash::Union{Nothing,Digest256}
    input::Union{Nothing,VNextT1CandidateBindingInputV2}
    accepted::Bool
    claim_ceiling::Symbol
    receipt_hash::Digest256

    function VNextT1PackageBindingAdapterResultV1(domain::String,
            schema::String, version::String, status::Symbol,
            resolution::Symbol, reason::Symbol, package_status::Symbol,
            package_resolution::Symbol, candidate_ref::QualifiedRefV1,
            candidate_digest::Digest256, source_package_hash::Digest256,
            wire_hash::Union{Nothing,Digest256},
            input::Union{Nothing,VNextT1CandidateBindingInputV2},
            accepted::Bool, claim_ceiling::Symbol, receipt_hash::Digest256)
        domain == VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1 ||
            throw(ArgumentError("package adapter domain mismatch"))
        schema == VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1 ||
            throw(ArgumentError("package adapter schema mismatch"))
        version == VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1 ||
            throw(ArgumentError("package adapter version mismatch"))
        status in (:prepared_not_executed, :terminal_deferred, :fail_closed) ||
            throw(ArgumentError("package adapter status mismatch"))
        resolution in (:terminal_deferred, :none) ||
            throw(ArgumentError("package adapter resolution mismatch"))
        reason in getproperty(_VNEXT_T1_PACKAGE_BINDING_ADAPTER_REASONS_V1,
            status) || throw(ArgumentError("package adapter reason mismatch"))
        accepted === false || throw(ArgumentError("adapter cannot be accepted"))
        claim_ceiling === VNEXT_T1_PACKAGE_BINDING_ADAPTER_CLAIM_CEILING_V1 ||
            throw(ArgumentError("adapter claim ceiling must remain contract_only"))
        ((status === :prepared_not_executed && input !== nothing) ||
            (status !== :prepared_not_executed && input === nothing)) ||
            throw(ArgumentError("typed absence cannot carry input"))
        expected = _vnext_t1_package_binding_adapter_receipt_hash_v1(status,
            resolution, reason, package_status, package_resolution,
            candidate_ref, candidate_digest, source_package_hash, wire_hash)
        receipt_hash == expected ||
            throw(ArgumentError("package adapter receipt hash mismatch"))
        new(domain, schema, version, status, resolution, reason,
            package_status, package_resolution, candidate_ref, candidate_digest,
            source_package_hash, wire_hash, input, accepted, claim_ceiling,
            receipt_hash)
    end
end

semantic_view(x::VNextT1PackageBindingAdapterResultV1) = (
    domain=x.domain, schema=x.schema, version=x.version, status=x.status,
    resolution=x.resolution, reason=x.reason,
    package_status=x.package_status, package_resolution=x.package_resolution,
    candidate_ref=x.candidate_ref, candidate_digest=x.candidate_digest,
    source_package_hash=x.source_package_hash, wire_hash=x.wire_hash,
    input=x.input, accepted=x.accepted, claim_ceiling=x.claim_ceiling,
    receipt_hash=x.receipt_hash)

function _vnext_t1_package_binding_adapter_receipt_hash_v1(status::Symbol,
        resolution::Symbol, reason::Symbol, package_status::Symbol,
        package_resolution::Symbol, candidate_ref::QualifiedRefV1,
        candidate_digest::Digest256, source_package_hash::Digest256,
        wire_hash::Union{Nothing,Digest256})
    canonical_hash((receipt_domain=
        VNEXT_T1_PACKAGE_BINDING_ADAPTER_RECEIPT_DOMAIN_V1,
        body=(domain=VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1,
            schema=VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1,
            version=VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1,
            status=status, resolution=resolution, reason=reason,
            package_status=package_status,
            package_resolution=package_resolution,
            candidate_ref=candidate_ref, candidate_digest=candidate_digest,
            source_package_hash=source_package_hash, wire_hash=wire_hash,
            accepted=false,
            claim_ceiling=VNEXT_T1_PACKAGE_BINDING_ADAPTER_CLAIM_CEILING_V1)))
end

function _vnext_t1_package_binding_adapter_result_v1(status::Symbol,
        resolution::Symbol, reason::Symbol, package::CandidateStatePackageV5Next,
        wire::Union{Nothing,VNextT1CanonicalBytesV2},
        input::Union{Nothing,VNextT1CandidateBindingInputV2})
    digest = package.semantic_identity
    package_hash = package.package_hash
    receipt_hash = _vnext_t1_package_binding_adapter_receipt_hash_v1(status,
        resolution, reason, package.status, package.resolution,
        package.candidate_ref, digest, package_hash,
        wire === nothing ? nothing : wire.sha256)
    VNextT1PackageBindingAdapterResultV1(
        VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1,
        VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1,
        VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1,
        status, resolution, reason, package.status, package.resolution,
        package.candidate_ref, digest, package_hash,
        wire === nothing ? nothing : wire.sha256, input, false,
        VNEXT_T1_PACKAGE_BINDING_ADAPTER_CLAIM_CEILING_V1, receipt_hash)
end

"""Recompute the exact V5Next package hash without rebuilding the package."""
function _vnext_t1_package_binding_adapter_package_hash_v1(
        package::CandidateStatePackageV5Next, identity::VNextT1ComponentIdentityV1)
    canonical_hash((schema=VNEXT_T1_PACKAGE_SCHEMA_ID_V1,
        schema_version=package.package_schema_version,
        package_schema_hash=package.package_schema_hash,
        package_canonicalization_version=package.package_canonicalization_version,
        package_canonicalization_hash=package.package_canonicalization_hash,
        package_profile_version=package.package_profile_version,
        package_profile_hash=package.package_profile_hash,
        candidate_ref=package.candidate_ref, declarations=package.declarations,
        children=package.children, axes=package.axes, feedback=package.feedback,
        source_hashes=package.source_hashes,
        declaration_hashes=package.declaration_hashes,
        layer_contracts=identity.layer_contracts,
        schema_hashes=ntuple(i -> identity.layer_contracts[i].schema_hash, 3),
        canonicalization_hashes=ntuple(i ->
            identity.layer_contracts[i].canonicalization_hash, 3),
        profile_hashes=ntuple(i ->
            identity.layer_contracts[i].compatibility_profile_hash, 3),
        component_identity=identity,
        component_count_receipt=package.component_count_receipt,
        semantic_identity=identity.semantic_identity,
        no_legacy_receipt=package.no_legacy_receipt,
        t0_gate=package.t0_gate, prior_bundle=package.t0_gate.prior_bundle,
        output_hash=package.t0_gate.output_hash,
        status=package.status, resolution=package.resolution,
        accepted=package.accepted, claim_ceiling=package.claim_ceiling))
end

"""Return the first closed conflict, or the typed G3 absence marker."""
function _vnext_t1_package_binding_adapter_check_v1(
        package::CandidateStatePackageV5Next)
    package.status === :prepared_not_executed || return :package_status_conflict
    package.resolution === :terminal_deferred ||
        return :package_resolution_conflict
    package.accepted === false || return :package_acceptance_conflict
    package.claim_ceiling === :contract_only ||
        return :package_claim_ceiling_conflict
    package.candidate_ref.version == "v5" || return :candidate_ref_conflict
    all(d -> d.candidate_ref == package.candidate_ref, package.declarations) ||
        return :candidate_ref_conflict
    all(c -> c.candidate_ref == package.candidate_ref, package.children) ||
        return :candidate_ref_conflict
    Tuple(d.layer for d in package.declarations) == (:G1, :G2, :G3) ||
        return :component_structure_conflict
    Tuple(c.kind for c in package.children) ==
        (:realization, :control, :binding) ||
        return :component_structure_conflict
    all(c -> c.layer === :G3, package.children) ||
        return :component_structure_conflict
    package.no_legacy_receipt.candidate_ref == package.candidate_ref ||
        return :candidate_ref_conflict
    package.t0_gate.candidate_ref == package.candidate_ref ||
        return :candidate_ref_conflict
    package.t0_gate.output_identity.candidate_ref == package.candidate_ref ||
        return :candidate_ref_conflict
    for declaration in package.declarations
        declaration.source_bytes.sha256 ==
            _vnext_t1_sha(declaration.source_bytes.bytes) ||
            return :component_structure_conflict
        declaration.declaration_bytes.sha256 ==
            _vnext_t1_sha(declaration.declaration_bytes.bytes) ||
            return :component_structure_conflict
        declaration.semantic_body_bytes.sha256 ==
            _vnext_t1_sha(declaration.semantic_body_bytes.bytes) ||
            return :component_structure_conflict
        declaration.source_identity_hash == canonical_hash((kind=:source,
            ref=declaration.source_ref,
            bytes_sha256=declaration.source_bytes.sha256)) ||
            return :component_structure_conflict
        declaration.declaration_identity_hash == canonical_hash((
            kind=:declaration, ref=declaration.declaration_ref,
            bytes_sha256=declaration.declaration_bytes.sha256)) ||
            return :component_structure_conflict
        declaration.factory_receipt.bytes.sha256 ==
            _vnext_t1_sha(declaration.factory_receipt.bytes.bytes) ||
            return :component_structure_conflict
        declaration.declaration_receipt.bytes.sha256 ==
            _vnext_t1_sha(declaration.declaration_receipt.bytes.bytes) ||
            return :component_structure_conflict
    end
    for child in package.children
        if child isa VNextT1PresentChildRecordV1
            child.source_bytes.sha256 == _vnext_t1_sha(child.source_bytes.bytes) ||
                return :component_structure_conflict
            expected_child_identity = canonical_hash((
                candidate_ref=child.candidate_ref, layer=child.layer,
                child_id=child.child_id, kind=child.kind,
                child_ref=child.child_ref, body_hash=child.body_hash,
                source_ref=child.source_ref,
                source_sha256=child.source_bytes.sha256))
            child.child_identity_hash == expected_child_identity ||
                return :component_structure_conflict
        else
            child.factory_receipt_bytes.sha256 ==
                _vnext_t1_sha(child.factory_receipt_bytes.bytes) ||
                return :component_structure_conflict
            child.factory_receipt_hash == child.factory_receipt_bytes.sha256 ||
                return :component_structure_conflict
            child.status in (:terminal_deferred, :typed_absent) ||
                return :component_structure_conflict
            child.candidate_identity_created === false ||
                return :component_structure_conflict
        end
    end
    package.t0_gate.output_bytes.sha256 ==
        _vnext_t1_sha(package.t0_gate.output_bytes.bytes) ||
        return :component_structure_conflict
    package.t0_gate.output_hash == canonical_hash(
        package.t0_gate.output_projection) || return :component_structure_conflict
    try
        _vnext_t1_validate_no_legacy_receipt(package.no_legacy_receipt,
            package.candidate_ref)
    catch
        return :component_structure_conflict
    end
    package.axes == ntuple(i -> package.declarations[i].axes, 3) ||
        return :component_structure_conflict
    package.source_hashes == ntuple(i ->
        package.declarations[i].source_bytes.sha256, 3) ||
        return :component_structure_conflict
    package.declaration_hashes == ntuple(i ->
        package.declarations[i].declaration_bytes.sha256, 3) ||
        return :component_structure_conflict
    package.component_count_receipt.declaration_layers ==
        (:G1, :G2, :G3) || return :component_structure_conflict
    package.component_count_receipt.child_kinds ==
        (:realization, :control, :binding) || return :component_structure_conflict
    package.component_count_receipt.component_count == 3 ||
        return :component_structure_conflict
    package.no_legacy_receipt.legacy_refs == () ||
        return :component_structure_conflict

    package.package_schema_version === VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1 ||
        return :component_structure_conflict
    package.package_schema_hash == vnext_t1_package_schema_hash_v1() ||
        return :component_structure_conflict
    package.package_canonicalization_version ===
        VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V1 ||
        return :component_structure_conflict
    package.package_canonicalization_hash ==
        vnext_t1_package_canonicalization_hash_v1() ||
        return :component_structure_conflict
    package.package_profile_version === VNEXT_T1_PACKAGE_PROFILE_VERSION_V1 ||
        return :component_structure_conflict
    package.package_profile_hash == vnext_t1_package_profile_hash_v1() ||
        return :component_structure_conflict

    package.t0_gate.status === :local_checked_present ||
        return :component_structure_conflict
    package.t0_gate.resolution === :resolved ||
        return :component_structure_conflict
    package.t0_gate.accepted === false ||
        return :component_structure_conflict
    package.t0_gate.claim_ceiling === :contract_only ||
        return :component_structure_conflict
    package.t0_gate.prior_bundle.canonical_bytes.sha256 ==
        _vnext_t1_sha(package.t0_gate.prior_bundle.canonical_bytes.bytes) ||
        return :component_structure_conflict
    package.t0_gate.output_identity.bundle_hash ==
        package.t0_gate.prior_bundle.bundle_hash ||
        return :component_structure_conflict
    package.t0_gate.output_identity.output_hash == package.t0_gate.output_hash ||
        return :component_structure_conflict
    package.t0_gate.output_identity.declaration_identity_hashes ==
        ntuple(i -> package.declarations[i].declaration_identity_hash, 3) ||
        return :component_structure_conflict
    package.t0_gate.output_identity.child_identity_hashes == ntuple(i ->
        package.children[i] isa VNextT1PresentChildRecordV1 ?
            package.children[i].child_identity_hash :
            package.children[i].factory_receipt_hash, 3) ||
        return :component_structure_conflict
    package.t0_gate.output_identity.feedback_hashes == ntuple(i ->
        canonical_hash(package.feedback[i]), length(package.feedback)) ||
        return :component_structure_conflict
    package.t0_gate.output_projection.candidate_ref == package.candidate_ref ||
        return :component_structure_conflict
    package.t0_gate.output_projection.bundle_hash ==
        package.t0_gate.prior_bundle.bundle_hash ||
        return :component_structure_conflict
    package.t0_gate.output_projection.declarations == package.declarations ||
        return :component_structure_conflict
    package.t0_gate.output_projection.children == package.children ||
        return :component_structure_conflict
    package.t0_gate.output_projection.feedback == package.feedback ||
        return :component_structure_conflict
    package.t0_gate.output_hash == canonical_hash(
        package.t0_gate.output_projection) || return :component_structure_conflict
    package.t0_gate.output_bytes.bytes == Tuple(Vector{UInt8}(codeunits(
        canonical_json(package.t0_gate.output_projection)))) ||
        return :component_structure_conflict

    identity = try
        _vnext_t1_component_identity(package.candidate_ref,
            package.declarations, package.children, package.axes,
            package.feedback, package.source_hashes,
            package.declaration_hashes, package.component_count_receipt)
    catch
        return :component_structure_conflict
    end
    package.component_identity == identity ||
        return :component_identity_mismatch
    package.layer_contracts == identity.layer_contracts ||
        return :component_identity_mismatch
    package.schema_hashes == ntuple(i ->
        identity.layer_contracts[i].schema_hash, 3) ||
        return :component_identity_mismatch
    package.canonicalization_hashes == ntuple(i ->
        identity.layer_contracts[i].canonicalization_hash, 3) ||
        return :component_identity_mismatch
    package.profile_hashes == ntuple(i ->
        identity.layer_contracts[i].compatibility_profile_hash, 3) ||
        return :component_identity_mismatch
    expected_count = try
        VNextT1ComponentCountReceiptV1(
            Tuple(d.layer for d in package.declarations),
            Tuple(c.kind for c in package.children),
            Tuple(f.target_id for f in package.feedback))
    catch
        return :component_structure_conflict
    end
    package.component_count_receipt == expected_count ||
        return :component_structure_conflict
    package.semantic_identity == identity.semantic_identity ||
        return :semantic_identity_mismatch
    expected_package_hash = try
        _vnext_t1_package_binding_adapter_package_hash_v1(package, identity)
    catch
        return :component_structure_conflict
    end
    package.package_hash == expected_package_hash || return :package_hash_mismatch

    any(child -> child isa VNextT1AbsentChildRecordV1 &&
        child.status === :typed_absent, package.children) &&
        return :g3_typed_absent
    nothing
end

"""Map one closed package to an explicit V2 input, retaining all gaps."""
function vnext_t1_package_binding_adapter_v1(
        package::CandidateStatePackageV5Next;
        wire::Union{Nothing,VNextT1CanonicalBytesV2}=nothing)
    reason = try
        _vnext_t1_package_binding_adapter_check_v1(package)
    catch
        :component_structure_conflict
    end
    if reason === nothing
        input = VNextT1CandidateBindingInputV2(package.candidate_ref,
            package.semantic_identity, package.package_hash, wire)
        return _vnext_t1_package_binding_adapter_result_v1(
            :prepared_not_executed, :terminal_deferred,
            :mapped_prepared_not_executed, package, wire, input)
    elseif reason === :g3_typed_absent
        return _vnext_t1_package_binding_adapter_result_v1(
            :terminal_deferred, :terminal_deferred, reason, package, wire, nothing)
    end
    _vnext_t1_package_binding_adapter_result_v1(
        :fail_closed, :none, reason, package, wire, nothing)
end

vnext_t1_package_binding_adapter_v1(package::CandidateStatePackageV5Next,
        wire::VNextT1CanonicalBytesV2) =
    vnext_t1_package_binding_adapter_v1(package; wire=wire)
vnext_t1_package_binding_adapter_v1(package::CandidateStatePackageV5Next,
        ::Nothing) = vnext_t1_package_binding_adapter_v1(package; wire=nothing)
