"""Native-source T2 bound input and real E0/G-I1A consumers.

This additive path joins a validated V3 source witness to a freshly reloaded T1
V2 package and its exact binding receipt.  It never constructs or accepts a
legacy `CandidateStatePackageV5`.
"""

const VNEXT_T2_UP2_SCHEMA_ID_V2 = "GenomeV5/UP2/VNextT2UP2AdapterV2"
const VNEXT_T2_UP2_SCHEMA_VERSION_V2 = "v2"
const VNEXT_T2_UP2_PROFILE_V2 = "native-source-formal-t1-bound-contract-only-v2"
const VNEXT_T2_UP2_CLAIM_CEILING_V2 = :contract_only

_vnext_t2_v2_zero_digest() = Digest256(repeat("0", 64))
function _vnext_t2_v2_content_equal(a, b)
    a === b && return true
    try
        canonical_json(a) == canonical_json(b)
    catch
        false
    end
end
_vnext_t2_v2_digest(x) = canonical_hash(x)

# T1 V2 deliberately hashes only a digest manifest and does not define a
# package-wide `semantic_view`.  T2 nevertheless has to compare the complete
# deserialized package at its handoff boundary.  Keep that projection local to
# T2 and include every package field, including the exact base64 projection of
# every owned byte carrier.
function _vnext_t2_t1_declaration_projection_v2(
        declaration::VNextT1DeclarationManifestV2)
    merge(semantic_view(declaration), (
        source_bytes=semantic_view(declaration.source_bytes),
        declaration_bytes=semantic_view(declaration.declaration_bytes),
        semantic_body_bytes=semantic_view(declaration.semantic_body_bytes),
        factory_receipt_bytes=semantic_view(
            declaration.factory_receipt_bytes),
        declaration_receipt_bytes=semantic_view(
            declaration.declaration_receipt_bytes)))
end

function _vnext_t2_t1_child_projection_v2(child::VNextT1ChildManifestV2)
    merge(semantic_view(child), (
        source_bytes=child.source_bytes === nothing ? nothing :
            semantic_view(child.source_bytes),
        factory_receipt_bytes=child.factory_receipt_bytes === nothing ?
            nothing : semantic_view(child.factory_receipt_bytes)))
end

function _vnext_t2_t1_package_projection_v2(
        package::CandidateStatePackageV5NextV2)
    (domain="vnext-t2-t1-package-full-content-projection-v2",
        schema_id=package.schema_id,
        schema_version=package.schema_version,
        canonicalization_version=package.canonicalization_version,
        profile_version=package.profile_version,
        candidate_ref=package.candidate_ref,
        bundle_hash=package.bundle_hash,
        declarations=Tuple(_vnext_t2_t1_declaration_projection_v2(x) for
            x in package.declarations),
        children=Tuple(_vnext_t2_t1_child_projection_v2(x) for
            x in package.children),
        feedback=Tuple(semantic_view(x) for x in package.feedback),
        axes=package.axes,
        parent_commitments=package.parent_commitments,
        g3_authority=semantic_view(package.g3_authority),
        wire=semantic_view(package.wire),
        semantic_identity=package.semantic_identity,
        package_hash=package.package_hash,
        status=package.status,
        resolution=package.resolution,
        accepted=package.accepted,
        claim_ceiling=package.claim_ceiling)
end

_vnext_t2_t1_package_content_hash_v2(
    package::CandidateStatePackageV5NextV2) =
        canonical_hash(_vnext_t2_t1_package_projection_v2(package))

function _vnext_t2_t1_package_content_equal_v2(
        left::CandidateStatePackageV5NextV2,
        right::CandidateStatePackageV5NextV2)
    _vnext_t2_v2_content_equal(
        _vnext_t2_t1_package_projection_v2(left),
        _vnext_t2_t1_package_projection_v2(right))
end

function _vnext_t2_t1_admission_projection_v2(
        admission::VNextT1AdmissionResultV2)
    (domain="vnext-t2-t1-admission-full-content-projection-v2",
        schema=VNEXT_T1_ADMISSION_SCHEMA_ID_V2,
        version=VNEXT_T1_ADMISSION_SCHEMA_VERSION_V2,
        status=admission.status,
        resolution=admission.resolution,
        accepted=admission.accepted,
        claim_ceiling=admission.claim_ceiling,
        package=admission.package === nothing ? nothing :
            _vnext_t2_t1_package_projection_v2(admission.package),
        errors=admission.errors,
        gaps=admission.gaps,
        trace=admission.trace)
end

function _vnext_t2_t1_admission_content_equal_v2(
        left::VNextT1AdmissionResultV2,
        right::VNextT1AdmissionResultV2)
    _vnext_t2_v2_content_equal(
        _vnext_t2_t1_admission_projection_v2(left),
        _vnext_t2_t1_admission_projection_v2(right))
end

function _vnext_t2_formal_gate_body_v2(candidate_ref, scenario, profile,
        witness_hash, package_hash, semantic_identity, bundle_hash, wire_hash,
        reload_adapter_receipt_hash, binding_receipt_hash, parent_commitments,
        g3_authority_commitment, evidence_kind, formal_t1_accepted,
        formal_t1_software_acceptance_receipt_hash,
        candidate_t1_admission_receipt_hash)
    (domain="vnext-t2-formal-gate-identity-v2", candidate_ref=candidate_ref,
        scenario=scenario, profile=profile, witness_hash=witness_hash,
        package_hash=package_hash, semantic_identity=semantic_identity,
        bundle_hash=bundle_hash, wire_hash=wire_hash,
        reload_adapter_receipt_hash=reload_adapter_receipt_hash,
        binding_receipt_hash=binding_receipt_hash,
        parent_commitments=parent_commitments,
        g3_authority_commitment=g3_authority_commitment,
        evidence_kind=evidence_kind,
        formal_t1_accepted=formal_t1_accepted,
        formal_t1_software_acceptance_receipt_hash=
            formal_t1_software_acceptance_receipt_hash,
        candidate_t1_admission_receipt_hash=
            candidate_t1_admission_receipt_hash)
end

"""Caller-supplied software-gate identity for synthetic or actual T1 evidence.

The identity binds the supplied evidence; it does not independently prove that
formal T1 acceptance occurred.  A formal runner must validate the original
acceptance artifact before constructing `:formal_t1_actual` evidence.
"""
struct VNextT2FormalGateIdentityV2
    candidate_ref::QualifiedRefV1
    scenario::String
    profile::String
    witness_hash::Digest256
    package_hash::Digest256
    semantic_identity::Digest256
    bundle_hash::Digest256
    wire_hash::Digest256
    reload_adapter_receipt_hash::Digest256
    binding_receipt_hash::Digest256
    parent_commitments::NTuple{2,Digest256}
    g3_authority_commitment::Digest256
    evidence_kind::Symbol
    formal_t1_accepted::Bool
    formal_t1_software_acceptance_receipt_hash::Digest256
    candidate_t1_admission_receipt_hash::Digest256
    identity_hash::Digest256
    function VNextT2FormalGateIdentityV2(candidate_ref::QualifiedRefV1,
            scenario::String, profile::String, witness_hash::Digest256,
            package_hash::Digest256, semantic_identity::Digest256,
            bundle_hash::Digest256, wire_hash::Digest256,
            reload_adapter_receipt_hash::Digest256,
            binding_receipt_hash::Digest256,
            parent_commitments::NTuple{2,Digest256},
            g3_authority_commitment::Digest256,
            evidence_kind::Symbol,
            formal_t1_accepted::Bool,
            formal_t1_software_acceptance_receipt_hash::Digest256,
            candidate_t1_admission_receipt_hash::Digest256,
            identity_hash::Digest256)
        candidate_ref.version == "v5" ||
            throw(ArgumentError("T2 formal-gate candidate must use v5"))
        !isempty(scenario) || throw(ArgumentError("T2 scenario must be non-empty"))
        profile == VNEXT_T2_UP2_PROFILE_V2 ||
            throw(ArgumentError("T2 formal-gate profile mismatch"))
        evidence_kind in (:synthetic_local, :formal_t1_actual) ||
            throw(ArgumentError("T2 formal-gate evidence kind invalid"))
        !formal_t1_accepted ||
            (formal_t1_software_acceptance_receipt_hash !=
                _vnext_t2_v2_zero_digest() &&
             candidate_t1_admission_receipt_hash !=
                _vnext_t2_v2_zero_digest()) ||
            throw(ArgumentError("accepted T2 T1 receipt hashes cannot be zero"))
        body = _vnext_t2_formal_gate_body_v2(candidate_ref, scenario, profile,
            witness_hash, package_hash, semantic_identity, bundle_hash,
            wire_hash, reload_adapter_receipt_hash, binding_receipt_hash,
            parent_commitments, g3_authority_commitment, evidence_kind,
            formal_t1_accepted,
            formal_t1_software_acceptance_receipt_hash,
            candidate_t1_admission_receipt_hash)
        identity_hash == canonical_hash(body) ||
            throw(ArgumentError("T2 formal-gate identity hash mismatch"))
        new(candidate_ref, scenario, profile, witness_hash, package_hash,
            semantic_identity, bundle_hash, wire_hash,
            reload_adapter_receipt_hash, binding_receipt_hash,
            parent_commitments, g3_authority_commitment,
            evidence_kind, formal_t1_accepted,
            formal_t1_software_acceptance_receipt_hash,
            candidate_t1_admission_receipt_hash,
            identity_hash)
    end
end

function vnext_t2_formal_gate_identity_v2(candidate_ref::QualifiedRefV1,
        scenario::String, witness_hash::Digest256, package_hash::Digest256,
        semantic_identity::Digest256, bundle_hash::Digest256,
        wire_hash::Digest256, reload_adapter_receipt_hash::Digest256,
        binding_receipt_hash::Digest256,
        parent_commitments::NTuple{2,Digest256},
        g3_authority_commitment::Digest256,
        formal_t1_software_acceptance_receipt_hash::Digest256,
        candidate_t1_admission_receipt_hash::Digest256;
        evidence_kind::Symbol=:synthetic_local,
        formal_t1_accepted::Bool=false,
        profile::String=VNEXT_T2_UP2_PROFILE_V2)
    body = _vnext_t2_formal_gate_body_v2(candidate_ref, scenario, profile,
        witness_hash, package_hash, semantic_identity, bundle_hash, wire_hash,
        reload_adapter_receipt_hash, binding_receipt_hash, parent_commitments,
        g3_authority_commitment, evidence_kind, formal_t1_accepted,
        formal_t1_software_acceptance_receipt_hash,
        candidate_t1_admission_receipt_hash)
    VNextT2FormalGateIdentityV2(candidate_ref, scenario, profile, witness_hash,
        package_hash, semantic_identity, bundle_hash, wire_hash,
        reload_adapter_receipt_hash, binding_receipt_hash,
        parent_commitments, g3_authority_commitment, evidence_kind,
        formal_t1_accepted, formal_t1_software_acceptance_receipt_hash,
        candidate_t1_admission_receipt_hash,
        canonical_hash(body))
end

semantic_view(x::VNextT2FormalGateIdentityV2) = merge(
    _vnext_t2_formal_gate_body_v2(x.candidate_ref, x.scenario, x.profile,
        x.witness_hash, x.package_hash, x.semantic_identity, x.bundle_hash,
        x.wire_hash, x.reload_adapter_receipt_hash,
        x.binding_receipt_hash, x.parent_commitments,
        x.g3_authority_commitment, x.evidence_kind,
        x.formal_t1_accepted,
        x.formal_t1_software_acceptance_receipt_hash,
        x.candidate_t1_admission_receipt_hash),
    (identity_hash=x.identity_hash,))

function _vnext_t2_bound_input_body_v2(witness, package, adapter,
        formal_gate, scenario, profile)
    (domain="vnext-t2-up2-bound-input-v2",
        schema_id=VNEXT_T2_UP2_SCHEMA_ID_V2,
        schema_version=VNEXT_T2_UP2_SCHEMA_VERSION_V2,
        profile=VNEXT_T2_UP2_PROFILE_V2,
        candidate_ref=package.candidate_ref,
        witness_hash=witness.witness_hash,
        package_hash=package.package_hash,
        semantic_identity=package.semantic_identity,
        wire_hash=package.wire.sha256,
        adapter_hash=canonical_hash(semantic_view(adapter)),
        formal_gate_hash=formal_gate.identity_hash,
        scenario=scenario, execution_profile=profile)
end

"""Material, independently expected input to every native T2 consumer."""
struct VNextT2UP2BoundInputV2
    witness::VNextT2ConcreteSourceWitnessV3
    package::CandidateStatePackageV5NextV2
    adapter::VNextT1PackageBindingAdapterResultV2
    formal_gate::VNextT2FormalGateIdentityV2
    scenario::String
    profile::String
    input_hash::Digest256
end

semantic_view(x::VNextT2UP2BoundInputV2) = merge(
    _vnext_t2_bound_input_body_v2(x.witness, x.package, x.adapter,
        x.formal_gate, x.scenario, x.profile),
    (input_hash=x.input_hash,))

struct VNextT2UP2InputValidationV2
    status::Symbol
    resolution::Symbol
    reason::Symbol
    input_hash::Digest256
end

semantic_view(x::VNextT2UP2InputValidationV2) =
    (status=x.status, resolution=x.resolution, reason=x.reason,
        input_hash=x.input_hash)

struct VNextT2UP2InputBuildResultV2
    status::Symbol
    resolution::Symbol
    reason::Symbol
    input::Union{Nothing,VNextT2UP2BoundInputV2}
    input_hash::Digest256
end

semantic_view(x::VNextT2UP2InputBuildResultV2) =
    (status=x.status, resolution=x.resolution, reason=x.reason,
        input=x.input, input_hash=x.input_hash)

function _vnext_t2_layer_tuple_v2(witness)
    (witness.g1, witness.g2, witness.g3)
end

function _vnext_t2_package_source_carriers_match_v2(input)
    for (manifest, layer) in zip(input.package.declarations,
            _vnext_t2_layer_tuple_v2(input.witness))
        record = layer.record
        manifest.source_ref == record.source_ref || return false
        copy_bytes(manifest.source_bytes) == record.source_bytes.bytes || return false
        manifest.source_bytes.sha256 == record.source_bytes.sha256 || return false
        manifest.source_identity_hash == record.source_identity_hash || return false
        layer.identity.source_identity_hash == record.source_identity_hash || return false
        layer.identity.source_file_sha256 == record.source_bytes.sha256 || return false
        layer.identity.source_carrier_hash == canonical_hash(record) || return false
    end
    true
end

function _vnext_t2_package_declaration_carriers_match_v2(input)
    for (manifest, layer) in zip(input.package.declarations,
            _vnext_t2_layer_tuple_v2(input.witness))
        record = layer.record
        manifest.declaration_ref == record.declaration_ref || return false
        copy_bytes(manifest.declaration_bytes) == record.declaration_bytes.bytes || return false
        manifest.declaration_bytes.sha256 == record.declaration_bytes.sha256 || return false
        manifest.declaration_identity_hash == record.declaration_identity_hash || return false
        copy_bytes(manifest.factory_receipt_bytes) == record.factory_receipt.bytes.bytes || return false
        copy_bytes(manifest.declaration_receipt_bytes) == record.declaration_receipt.bytes.bytes || return false
        layer.identity.declaration_identity_hash == record.declaration_identity_hash || return false
        layer.identity.declaration_sha256 == record.declaration_bytes.sha256 || return false
        layer.identity.declaration_component_hash == canonical_hash(layer.declaration) || return false
        layer.identity.factory_content_identity ==
            record.factory_receipt.factory_result.content_identity || return false
    end
    true
end

function _vnext_t2_package_semantic_carriers_match_v2(input)
    for (manifest, layer) in zip(input.package.declarations,
            _vnext_t2_layer_tuple_v2(input.witness))
        record = layer.record
        copy_bytes(manifest.semantic_body_bytes) ==
            record.semantic_body.bytes.bytes || return false
        manifest.semantic_body_bytes.sha256 ==
            record.semantic_body.bytes.sha256 || return false
        layer.identity.semantic_body_sha256 ==
            record.semantic_body.bytes.sha256 || return false
        layer.identity.semantic_body_hash == canonical_hash(record.semantic_body.body) ||
            return false
        layer.identity.native_declaration_hash ==
            getproperty(layer.declaration, :declaration_hash) || return false
    end
    true
end

function _vnext_t2_axes_match_v2(input)
    for (manifest, layer) in zip(input.package.declarations,
            _vnext_t2_layer_tuple_v2(input.witness))
        record = layer.record
        manifest.axes == record.axes == layer.identity.source_axes || return false
        record.factory_receipt.factory_axes == layer.identity.factory_axes || return false
    end
    true
end

function _vnext_t2_t0_recheck_match_v2(input)
    witness = input.witness
    package = input.package
    t = witness.t0_transport
    r = witness.t0_recheck
    t.candidate_ref == package.candidate_ref || return false
    t.bundle_hash == package.bundle_hash == witness.manifest.t0_bundle_hash || return false
    r.candidate_ref == package.candidate_ref || return false
    r.bundle_hash == package.bundle_hash || return false
    recheck_declarations = if r isa VNextAuthorityRecheckLocalV2Checked
        r.declarations
    elseif r isa VNextAuthorityRecheckLocalCheckedPresentV1
        (r.g1, r.g2, r.g3)
    else
        return false
    end
    _vnext_t2_v2_content_equal(recheck_declarations, t.declarations) || return false
    _vnext_t2_v2_content_equal(r.children, t.children) || return false
    _vnext_t2_v2_content_equal(r.feedback, t.feedback) || return false
    expected_wire = Vector{UInt8}(codeunits(canonical_json(t)))
    copy_bytes(package.wire) == expected_wire || return false
    true
end

function _vnext_t2_children_match_v2(input)
    witness = input.witness
    package = input.package
    _vnext_t2_v2_content_equal(witness.children.t0_children,
        witness.t0_transport.children) || return false
    for i in 1:3
        expected = _vnext_t1_v2_child(witness.children.t0_children[i])
        _vnext_t2_v2_content_equal(package.children[i], expected) || return false
    end
    expected = witness.children.expected_commitment
    expected.candidate_ref == package.candidate_ref || return false
    expected.bundle_hash == package.bundle_hash || return false
    expected.realization.state_hash == witness.children.realization_state.state_hash ||
        return false
    expected.control.state_hash == witness.children.control_state.current_state_hash || return false
    package.g3_authority.child_state_hashes ==
        (expected.realization.state_hash, expected.control.state_hash) || return false
    package.g3_authority.binding_state_hash == witness.children.binding_state.state_hash ||
        return false
    true
end

function _vnext_t2_feedback_match_v2(input)
    witness = input.witness
    _vnext_t2_v2_content_equal(input.package.feedback,
        witness.feedback.t0_feedback) || return false
    _vnext_t2_v2_content_equal(witness.feedback.t0_feedback,
        witness.t0_transport.feedback) || return false
    witness.feedback.g3_targets == witness.g3.declaration.feedback_targets || return false
    true
end

function _vnext_t2_parent_match_v2(input)
    source_parent = input.witness.parent_bundle
    package = input.package
    witness = input.witness
    source_parent.candidate_ref == package.candidate_ref || return false
    source_parent.bundle_hash == witness.manifest.parent_bundle_hash || return false
    source_expected = (
        t0_parent_authority_commitment_v1(witness.g1.record),
        t0_parent_authority_commitment_v1(witness.g2.record))
    verify_present_t0_local_parent_bundle_v1(source_parent,
        source_expected[1], source_expected[2]) || return false
    t1_expected = (
        vnext_t1_parent_commitment_v2(package.candidate_ref,
            witness.g1.record),
        vnext_t1_parent_commitment_v2(package.candidate_ref,
            witness.g2.record))
    package.parent_commitments == t1_expected || return false
    input.formal_gate.parent_commitments == t1_expected || return false
    true
end

function _vnext_t2_g3_authority_match_v2(input)
    expected = input.witness.children.expected_commitment
    package = input.package
    expected.candidate_ref == package.candidate_ref || return false
    expected.bundle_hash == input.witness.t0_transport.bundle_hash || return false
    expected.g3_declaration_ref == input.witness.g3.record.declaration_ref || return false
    expected.g3_declaration_identity_hash ==
        input.witness.g3.record.declaration_identity_hash || return false
    expected.commitment_hash ==
        vnext_g3_binding_expected_commitment_hash_v1(expected) || return false
    expected.commitment_hash == input.witness.manifest.g3_expected_commitment_hash ||
        return false
    package.g3_authority.commitment_hash == expected.commitment_hash || return false
    package.g3_authority.commitment_hash ==
        input.formal_gate.g3_authority_commitment || return false
    package.g3_authority.authority_verified || return false
    true
end

function _vnext_t2_adapter_match_v2(input)
    adapter = input.adapter
    package = input.package
    adapter.status === :prepared_not_executed || return false
    adapter.resolution === :terminal_deferred || return false
    adapter.reason === :mapped_prepared_not_executed || return false
    adapter.package_hash == package.package_hash || return false
    adapter.semantic_identity == package.semantic_identity || return false
    adapter.input isa VNextT1CandidateBindingInputV2 || return false
    adapter.binding isa VNextT1CandidateBindingReceiptV2 || return false
    observed = adapter.input
    receipt = adapter.binding
    observed.candidate_ref == package.candidate_ref || return false
    observed.candidate_digest == package.semantic_identity || return false
    observed.source_package_hash == package.package_hash || return false
    observed.wire isa VNextT1CanonicalBytesV2 || return false
    copy_bytes(observed.wire) == copy_bytes(package.wire) || return false
    receipt.status === :bound || return false
    receipt.reason === :exact_explicit_binding || return false
    receipt.duplicate_count == 1 || return false
    receipt.candidate_ref == package.candidate_ref || return false
    receipt.candidate_digest == package.semantic_identity || return false
    receipt.source_package_hash == package.package_hash || return false
    receipt.wire_hash == package.wire.sha256 || return false
    receipt.receipt_hash == input.formal_gate.binding_receipt_hash || return false
    canonical_hash(semantic_view(adapter)) ==
        input.formal_gate.reload_adapter_receipt_hash || return false
    true
end

function _vnext_t2_first_input_error_v2(input::VNextT2UP2BoundInputV2)
    package = input.package
    witness = input.witness
    gate = input.formal_gate
    package.schema_id == VNEXT_T1_PACKAGE_SCHEMA_ID_V2 ||
        return :t2_preflight_schema_id_mismatch
    package.schema_version == VNEXT_T1_PACKAGE_SCHEMA_VERSION_V2 ||
        return :t2_preflight_schema_version_mismatch
    package.profile_version == VNEXT_T1_PACKAGE_PROFILE_VERSION_V2 ||
        return :t2_preflight_profile_mismatch
    package.wire isa VNextT1CanonicalBytesV2 ||
        return :t2_preflight_wire_shape_invalid
    isempty(copy_bytes(package.wire)) && return :t2_preflight_wire_shape_invalid
    package.wire.sha256 == _vnext_ar_v2_sha(copy_bytes(package.wire)) ||
        return :t2_preflight_wire_hash_mismatch
    package.wire.sha256 != _vnext_t2_v2_zero_digest() ||
        return :t2_preflight_wire_hash_mismatch
    package.candidate_ref == witness.candidate_ref == gate.candidate_ref ||
        return :t2_preflight_candidate_ref_mismatch
    witness.schema_id == VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_ID_V3 ||
        return :t2_preflight_source_witness_shape_invalid
    witness.schema_version == VNEXT_T2_CONCRETE_SOURCE_WITNESS_SCHEMA_VERSION_V3 ||
        return :t2_preflight_source_witness_shape_invalid
    witness.profile == VNEXT_T2_CONCRETE_SOURCE_WITNESS_PROFILE_V3 ||
        return :t2_preflight_source_witness_shape_invalid
    witness.source_status === :source_ready ||
        return :t2_preflight_source_witness_shape_invalid
    witness.resolution === :terminal_deferred ||
        return :t2_preflight_source_witness_shape_invalid
    witness.formal_node_accepted === false ||
        return :t2_preflight_source_witness_shape_invalid
    witness.formal_t1.status === :typed_absent ||
        return :t2_preflight_source_witness_shape_invalid
    witness.formal_t1.formal_t1_accepted === false ||
        return :t2_preflight_source_witness_shape_invalid
    witness.formal_t1.formal_consumer_counts ==
        (e0=0, gi1a=0, e1=0, e2=0, n10=0) ||
        return :t2_preflight_source_witness_shape_invalid
    witness.witness_hash == vnext_t2_concrete_source_witness_hash_v3(witness) ||
        return :t2_preflight_source_edit_without_rebuild
    witness.witness_hash == gate.witness_hash ||
        return :t2_preflight_source_edit_without_rebuild
    _vnext_t2_package_source_carriers_match_v2(input) ||
        return :t2_preflight_source_carrier_mismatch
    _vnext_t2_package_declaration_carriers_match_v2(input) ||
        return :t2_preflight_declaration_carrier_mismatch
    _vnext_t2_package_semantic_carriers_match_v2(input) ||
        return :t2_preflight_semantic_carrier_mismatch
    _vnext_t2_axes_match_v2(input) || return :t2_preflight_axis_mismatch
    input.scenario == gate.scenario || return :t2_preflight_scenario_mismatch
    input.profile == gate.profile == VNEXT_T2_UP2_PROFILE_V2 ||
        return :t2_preflight_profile_mismatch
    package.bundle_hash == witness.manifest.t0_bundle_hash ||
        return :t2_preflight_t0_bundle_mismatch
    _vnext_t2_t0_recheck_match_v2(input) ||
        return :t2_preflight_t0_recheck_mismatch
    _vnext_t2_children_match_v2(input) || return :t2_preflight_child_mismatch
    _vnext_t2_feedback_match_v2(input) || return :t2_preflight_feedback_mismatch
    _vnext_t2_parent_match_v2(input) ||
        return :t2_preflight_parent_commitment_mismatch
    _vnext_t2_g3_authority_match_v2(input) ||
        return :t2_preflight_g3_authority_mismatch
    package.semantic_identity == gate.semantic_identity ||
        return :t2_preflight_semantic_identity_mismatch
    package.package_hash == gate.package_hash ||
        return :t2_preflight_package_hash_mismatch
    package.bundle_hash == gate.bundle_hash ||
        return :t2_preflight_t0_bundle_mismatch
    package.wire.sha256 == gate.wire_hash ||
        return :t2_preflight_wire_hash_mismatch
    vnext_t1_package_v2_validate(package) === nothing ||
        return :t2_preflight_package_hash_mismatch
    _vnext_t2_adapter_match_v2(input) ||
        return :t2_preflight_reload_binding_mismatch
    gate.evidence_kind in (:synthetic_local, :formal_t1_actual) ||
        return :t2_preflight_formal_gate_evidence_kind_invalid
    gate.identity_hash == canonical_hash(_vnext_t2_formal_gate_body_v2(
        gate.candidate_ref, gate.scenario, gate.profile, gate.witness_hash,
        gate.package_hash, gate.semantic_identity, gate.bundle_hash,
        gate.wire_hash, gate.reload_adapter_receipt_hash,
        gate.binding_receipt_hash, gate.parent_commitments,
        gate.g3_authority_commitment, gate.evidence_kind,
        gate.formal_t1_accepted,
        gate.formal_t1_software_acceptance_receipt_hash,
        gate.candidate_t1_admission_receipt_hash)) ||
        return :t2_preflight_formal_gate_identity_mismatch
    gate.formal_t1_accepted || return :t2_preflight_formal_t1_not_accepted
    gate.formal_t1_software_acceptance_receipt_hash !=
        _vnext_t2_v2_zero_digest() ||
        return :t2_preflight_formal_t1_software_receipt_invalid
    gate.candidate_t1_admission_receipt_hash !=
        _vnext_t2_v2_zero_digest() ||
        return :t2_preflight_candidate_t1_admission_receipt_invalid
    input.input_hash == canonical_hash(_vnext_t2_bound_input_body_v2(
        witness, package, input.adapter, gate, input.scenario,
        input.profile)) || return :t2_preflight_input_hash_mismatch
    :none
end

function vnext_t2_up2_validate_input_v2(input::VNextT2UP2BoundInputV2)
    reason = try
        _vnext_t2_first_input_error_v2(input)
    catch
        :t2_preflight_serialization_corrupt
    end
    reason === :none ?
        VNextT2UP2InputValidationV2(:valid, :terminal_deferred, :none,
            input.input_hash) :
        VNextT2UP2InputValidationV2(:fail_closed, :none, reason,
            input.input_hash)
end

function vnext_t2_up2_input_from_t1_v2(
        witness::Union{Nothing,VNextT2ConcreteSourceWitnessV3},
        package::CandidateStatePackageV5NextV2,
        adapter::VNextT1PackageBindingAdapterResultV2,
        formal_gate::VNextT2FormalGateIdentityV2;
        scenario::String=formal_gate.scenario,
        profile::String=formal_gate.profile)
    if witness === nothing
        return VNextT2UP2InputBuildResultV2(:typed_absent,
            :terminal_deferred, :t2_preflight_source_witness_absent,
            nothing, canonical_hash((domain="vnext-t2-absent-input-v2",
                package_hash=package.package_hash, scenario=scenario,
                profile=profile)))
    end
    body = _vnext_t2_bound_input_body_v2(witness, package, adapter,
        formal_gate, scenario, profile)
    input = VNextT2UP2BoundInputV2(witness, package, adapter, formal_gate,
        scenario, profile, canonical_hash(body))
    validation = vnext_t2_up2_validate_input_v2(input)
    validation.status === :valid ?
        VNextT2UP2InputBuildResultV2(:prepared_not_executed,
            :terminal_deferred, :t2_preflight_ready, input,
            input.input_hash) :
        VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            validation.reason, nothing, input.input_hash)
end

function _vnext_t2_t1_admission_input_match_v2(witness, admission_input)
    admission_input.candidate_ref == witness.candidate_ref || return false
    admission_input.transport isa VNextT0LocalTransportV1 || return false
    _vnext_t2_v2_content_equal(admission_input.transport,
        witness.t0_transport) || return false
    admission_input.t0_recheck isa VNextAuthorityRecheckLocalV2Result ||
        return false
    recheck = admission_input.t0_recheck
    recheck.status === :local_checked_present || return false
    recheck.resolution === :resolved || return false
    recheck.accepted === false || return false
    recheck.claim_ceiling === :contract_only || return false
    isempty(recheck.errors) || return false
    isempty(recheck.reasons) || return false
    recheck.output isa VNextAuthorityRecheckLocalV2Checked || return false
    recheck.prior_bundle_sha256 == witness.t0_transport.bundle_hash || return false
    _vnext_t2_v2_content_equal(recheck.output.declarations,
        witness.t0_transport.declarations) || return false
    _vnext_t2_v2_content_equal(recheck.output.children,
        witness.t0_transport.children) || return false
    _vnext_t2_v2_content_equal(recheck.output.feedback,
        witness.t0_transport.feedback) || return false
    expected_parents = (
        vnext_t1_parent_commitment_v2(witness.candidate_ref,
            witness.g1.record),
        vnext_t1_parent_commitment_v2(witness.candidate_ref,
            witness.g2.record))
    admission_input.parent_commitments == expected_parents || return false
    expected = witness.children.expected_commitment
    admission_input.g3_expected_commitment == expected.commitment_hash || return false
    authority = admission_input.g3_authority
    hasproperty(authority, :status) &&
        authority.status === :local_checked_present || return false
    hasproperty(authority, :resolution) &&
        authority.resolution === :resolved || return false
    hasproperty(authority, :authority_verified) &&
        authority.authority_verified === true || return false
    hasproperty(authority, :expected_commitment) || return false
    _vnext_t2_v2_content_equal(authority.expected_commitment, expected) || return false
    hasproperty(authority, :binding_state) || return false
    _vnext_t2_v2_content_equal(authority.binding_state,
        witness.children.binding_state) || return false
    hasproperty(authority, :commitment_hash) &&
        authority.commitment_hash == expected.commitment_hash || return false
    true
end

function _vnext_t2_t1_recheck_output_projection_v2(output)
    output === nothing && return (
        domain="vnext-t2-t1-recheck-output-v2/nothing",)
    if output isa VNextAuthorityRecheckLocalV2Checked
        return (domain="vnext-t2-t1-recheck-output-v2/checked",
            candidate_ref=output.candidate_ref,
            bundle_hash=output.bundle_hash,
            declarations=output.declarations,
            children=output.children,
            feedback=output.feedback,
            g3_children_deferred=output.g3_children_deferred)
    end
    output isa VNextAuthorityRecheckLocalV2TypedAbsent ||
        throw(ArgumentError("T1 recheck output type invalid"))
    (domain="vnext-t2-t1-recheck-output-v2/typed-absent",
        candidate_ref=output.candidate_ref,
        bundle_hash=output.bundle_hash,
        reasons=output.reasons,
        g3_children_deferred=output.g3_children_deferred)
end

function _vnext_t2_t1_recheck_projection_v2(recheck)
    recheck === nothing && return (
        domain="vnext-t2-t1-recheck-v2/nothing",)
    recheck isa VNextAuthorityRecheckLocalV2Result ||
        throw(ArgumentError("T1 recheck result type invalid"))
    (domain="vnext-t2-t1-recheck-v2/result",
        status=recheck.status,
        resolution=recheck.resolution,
        accepted=recheck.accepted,
        claim_ceiling=recheck.claim_ceiling,
        output=_vnext_t2_t1_recheck_output_projection_v2(recheck.output),
        errors=recheck.errors,
        reasons=recheck.reasons,
        prior_bundle_bytes=recheck.prior_bundle_bytes,
        prior_bundle_sha256=recheck.prior_bundle_sha256)
end

function _vnext_t2_t1_admission_handoff_body_v2(witness, admission_input,
        admission, reloaded_package, adapter, formal_gate, scenario, profile)
    (domain="vnext-t2-t1-admission-handoff-v2",
        witness_hash=witness === nothing ? nothing : witness.witness_hash,
        admission_input=(candidate_ref=admission_input.candidate_ref,
            transport=admission_input.transport,
            t0_recheck=_vnext_t2_t1_recheck_projection_v2(
                admission_input.t0_recheck),
            parent_commitments=admission_input.parent_commitments,
            g3_expected_commitment=admission_input.g3_expected_commitment,
            g3_authority=admission_input.g3_authority),
        admission=_vnext_t2_t1_admission_projection_v2(admission),
        reloaded_package_hash=reloaded_package === nothing ? nothing :
            reloaded_package.package_hash,
        reloaded_package_content_hash=reloaded_package === nothing ? nothing :
            _vnext_t2_t1_package_content_hash_v2(reloaded_package),
        reload_adapter_receipt_hash=adapter === nothing ? nothing :
            canonical_hash(semantic_view(adapter)),
        formal_gate_hash=formal_gate === nothing ? nothing :
            formal_gate.identity_hash,
        scenario=scenario, profile=profile)
end

function _vnext_t2_t1_admission_absence_valid_v2(witness, admission_input,
        admission)
    admission_input.candidate_ref == witness.candidate_ref || return false
    admission.status === :terminal_deferred || return false
    admission.resolution === :terminal_deferred || return false
    admission.accepted === false || return false
    admission.claim_ceiling === :contract_only || return false
    admission.package === nothing || return false
    isempty(admission.errors) || return false
    if admission_input.transport === nothing
        return admission.gaps == (:t0_transport_required,) &&
            admission.trace == (:entry,)
    elseif admission_input.t0_recheck === nothing
        _vnext_t2_v2_content_equal(admission_input.transport,
            witness.t0_transport) || return false
        return admission.gaps == (:t0_recheck_required,) &&
            admission.trace == (:entry,)
    end
    false
end

"""Bind the actual T1 admission result and its deserialized package to T2.

This entry preserves typed absence and upstream failure as zero-consumer build
results.  A prepared handoff must carry the exact admission input, output
envelope, deserialized package, reload adapter, and formal-gate identity.  It
re-runs T1 admission once and exact-compares the complete supplied result.
"""
function vnext_t2_up2_input_from_t1_admission_v2(
        witness::Union{Nothing,VNextT2ConcreteSourceWitnessV3},
        admission_input::VNextT1AdmissionInputV2,
        admission::VNextT1AdmissionResultV2,
        reloaded_package::Union{Nothing,CandidateStatePackageV5NextV2},
        adapter::Union{Nothing,VNextT1PackageBindingAdapterResultV2},
        formal_gate::Union{Nothing,VNextT2FormalGateIdentityV2};
        scenario::String,
        profile::String=VNEXT_T2_UP2_PROFILE_V2)
    handoff_hash = canonical_hash(_vnext_t2_t1_admission_handoff_body_v2(
        witness, admission_input, admission, reloaded_package, adapter,
        formal_gate, scenario, profile))
    witness === nothing && return VNextT2UP2InputBuildResultV2(:typed_absent,
        :terminal_deferred, :t2_preflight_source_witness_absent, nothing,
        handoff_hash)
    rebuilt_admission = vnext_t1_admit_v2(admission_input)
    _vnext_t2_t1_admission_content_equal_v2(rebuilt_admission, admission) ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_result_mismatch, nothing,
            handoff_hash)
    admission.accepted === false ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_accepted_invalid, nothing, handoff_hash)
    admission.claim_ceiling === :contract_only ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_claim_ceiling_invalid, nothing,
            handoff_hash)
    if _vnext_t2_t1_admission_absence_valid_v2(witness, admission_input,
            admission)
        return VNextT2UP2InputBuildResultV2(:typed_absent,
            :terminal_deferred, :t2_preflight_t1_admission_absent, nothing,
            handoff_hash)
    end
    _vnext_t2_t1_admission_input_match_v2(witness, admission_input) ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_input_mismatch, nothing, handoff_hash)
    admission.status === :prepared_not_executed ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_not_prepared, nothing, handoff_hash)
    admission.resolution === :terminal_deferred ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_resolution_invalid, nothing,
            handoff_hash)
    isempty(admission.errors) ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_errors_present, nothing, handoff_hash)
    admission.package isa CandidateStatePackageV5NextV2 ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_admission_package_absent, nothing, handoff_hash)
    reloaded_package isa CandidateStatePackageV5NextV2 ||
        return VNextT2UP2InputBuildResultV2(:typed_absent,
            :terminal_deferred, :t2_preflight_t1_reloaded_package_absent,
            nothing, handoff_hash)
    _vnext_t2_t1_package_content_equal_v2(admission.package,
        reloaded_package) ||
        return VNextT2UP2InputBuildResultV2(:fail_closed, :none,
            :t2_preflight_t1_reloaded_package_mismatch, nothing, handoff_hash)
    adapter isa VNextT1PackageBindingAdapterResultV2 ||
        return VNextT2UP2InputBuildResultV2(:typed_absent,
            :terminal_deferred, :t2_preflight_reload_adapter_absent, nothing,
            handoff_hash)
    formal_gate isa VNextT2FormalGateIdentityV2 ||
        return VNextT2UP2InputBuildResultV2(:typed_absent,
            :terminal_deferred, :t2_preflight_formal_gate_absent, nothing,
            handoff_hash)
    vnext_t2_up2_input_from_t1_v2(witness, reloaded_package, adapter,
        formal_gate; scenario=scenario, profile=profile)
end

struct VNextT2ConsumerFailureV2 <: Exception
    stage::Symbol
    reason::Symbol
end
Base.showerror(io::IO, x::VNextT2ConsumerFailureV2) =
    print(io, String(x.stage), "_", String(x.reason))

function _vnext_t2_require_valid_input_v2(input)
    validation = vnext_t2_up2_validate_input_v2(input)
    validation.status === :valid ||
        throw(VNextT2ConsumerFailureV2(:t2_preflight, validation.reason))
    nothing
end

struct VNextT2E0PhysicalBindingV2
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    witness_hash::Digest256
    contract_refs::NTuple{3,GenomeContractRef}
    declaration_hashes::NTuple{3,Digest256}
    component_identity_hashes::NTuple{3,Digest256}
    axes::NTuple{3,NTuple{4,QualifiedRefV1}}
    children_identity_hash::Digest256
    feedback_identity_hash::Digest256
    source_bundle_hash::Digest256
    input_hash::Digest256
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    gaps::Tuple{Vararg{Symbol}}
    output_hash::Digest256
end

function _vnext_t2_e0_body_v2(candidate_ref, package_hash, witness_hash,
        contract_refs, declaration_hashes, component_identity_hashes, axes,
        children_identity_hash, feedback_identity_hash, source_bundle_hash,
        input_hash, status, resolution, accepted, claim_ceiling, gaps)
    (domain="vnext-t2-e0-native-source-binding-v2",
        candidate_ref=candidate_ref, package_hash=package_hash,
        witness_hash=witness_hash, contract_refs=contract_refs,
        declaration_hashes=declaration_hashes,
        component_identity_hashes=component_identity_hashes, axes=axes,
        children_identity_hash=children_identity_hash,
        feedback_identity_hash=feedback_identity_hash,
        source_bundle_hash=source_bundle_hash, input_hash=input_hash,
        status=status, resolution=resolution, accepted=accepted,
        claim_ceiling=claim_ceiling, gaps=gaps)
end

semantic_view(x::VNextT2E0PhysicalBindingV2) = merge(
    _vnext_t2_e0_body_v2(x.candidate_ref, x.package_hash, x.witness_hash,
        x.contract_refs, x.declaration_hashes,
        x.component_identity_hashes, x.axes,
        x.children_identity_hash, x.feedback_identity_hash,
        x.source_bundle_hash, x.input_hash, x.status, x.resolution,
        x.accepted, x.claim_ceiling, x.gaps),
    (output_hash=x.output_hash,))

"""Read and validate all three native declarations before producing E0."""
function up2_candidate_physical_binding_from_a(
        input::VNextT2UP2BoundInputV2)
    _vnext_t2_require_valid_input_v2(input)
    witness = input.witness
    g1_status, _ = g1_diffusion_validate(witness.g1.declaration)
    g1_status === :valid ||
        throw(VNextT2ConsumerFailureV2(:e0, :g1_declaration_invalid))
    g2_admission = g2mb_admit(witness.g2.declaration.source)
    g2_admission.status in (:valid, :terminal_deferred) ||
        throw(VNextT2ConsumerFailureV2(:e0, :g2_declaration_invalid))
    g3_status, _ = g3_sf_validate_v1(witness.g3.declaration)
    g3_status === :valid ||
        throw(VNextT2ConsumerFailureV2(:e0, :g3_declaration_invalid))

    layers = _vnext_t2_layer_tuple_v2(witness)
    refs = ntuple(i -> layers[i].record.factory_receipt.factory_result.contract_ref, 3)
    declaration_hashes = (witness.g1.declaration.declaration_hash,
        witness.g2.declaration.declaration_hash,
        witness.g3.declaration.declaration_hash)
    component_hashes = (witness.g1.identity.identity_hash,
        witness.g2.identity.identity_hash, witness.g3.identity.identity_hash)
    axes = ntuple(i -> layers[i].identity.source_axes, 3)
    evidence_gaps = input.formal_gate.evidence_kind === :synthetic_local ?
        (:formal_gate_verified_false_synthetic_local,) : ()
    gaps = Tuple(unique((:e1_two_region_interface_authority_unsupported,
        :compiler_not_executed, :provider_not_executed,
        :solver_not_executed, witness.gaps..., evidence_gaps...)))
    body = _vnext_t2_e0_body_v2(input.package.candidate_ref,
        input.package.package_hash, witness.witness_hash, refs,
        declaration_hashes, component_hashes, axes,
        witness.manifest.children_identity_hash,
        witness.manifest.feedback_identity_hash,
        witness.manifest.source_bundle_hash, input.input_hash,
        :prepared_not_executed, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2, gaps)
    VNextT2E0PhysicalBindingV2(input.package.candidate_ref,
        input.package.package_hash, witness.witness_hash, refs,
        declaration_hashes, component_hashes, axes,
        witness.manifest.children_identity_hash,
        witness.manifest.feedback_identity_hash,
        witness.manifest.source_bundle_hash, input.input_hash,
        :prepared_not_executed, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2, gaps, canonical_hash(body))
end

struct VNextT2AuthoritySlotV2
    slot::Symbol
    status::Symbol
    resolution::Symbol
    reason::Symbol
    observed_content_hash::Digest256
    unsupported_capabilities::Tuple{Vararg{Symbol}}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    output_hash::Digest256
end

function _vnext_t2_slot_body_v2(slot, status, resolution, reason,
        observed_content_hash, unsupported_capabilities, errors, gaps)
    (domain="vnext-t2-authority-slot-v2", slot=slot, status=status,
        resolution=resolution, reason=reason,
        observed_content_hash=observed_content_hash,
        unsupported_capabilities=unsupported_capabilities,
        errors=errors, gaps=gaps)
end

function _vnext_t2_slot_v2(slot, status, resolution, reason,
        observed_content_hash, unsupported_capabilities=(), errors=(), gaps=())
    body = _vnext_t2_slot_body_v2(slot, status, resolution, reason,
        observed_content_hash, Tuple(unsupported_capabilities), Tuple(errors),
        Tuple(gaps))
    VNextT2AuthoritySlotV2(slot, status, resolution, reason,
        observed_content_hash, Tuple(unsupported_capabilities), Tuple(errors),
        Tuple(gaps), canonical_hash(body))
end

semantic_view(x::VNextT2AuthoritySlotV2) = merge(
    _vnext_t2_slot_body_v2(x.slot, x.status, x.resolution, x.reason,
        x.observed_content_hash, x.unsupported_capabilities, x.errors,
        x.gaps), (output_hash=x.output_hash,))

struct VNextT2GI1AuthorityContextV2
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    input_hash::Digest256
    e0_output_hash::Digest256
    native_authority_hash::Digest256
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    context_hash::Digest256
end

function _vnext_t2_gi1_body_v2(candidate_ref, package_hash, input_hash,
        e0_output_hash, native_authority_hash, status, resolution, accepted,
        claim_ceiling)
    (domain="vnext-t2-gi1-native-authority-context-v2",
        candidate_ref=candidate_ref, package_hash=package_hash,
        input_hash=input_hash, e0_output_hash=e0_output_hash,
        native_authority_hash=native_authority_hash,
        status=status, resolution=resolution,
        accepted=accepted, claim_ceiling=claim_ceiling)
end

semantic_view(x::VNextT2GI1AuthorityContextV2) = merge(
    _vnext_t2_gi1_body_v2(x.candidate_ref, x.package_hash,
        x.input_hash, x.e0_output_hash, x.native_authority_hash, x.status,
        x.resolution, x.accepted, x.claim_ceiling),
    (context_hash=x.context_hash,))

function _vnext_t2_validate_e0_v2(input, e0)
    e0.candidate_ref == input.package.candidate_ref || return false
    e0.package_hash == input.package.package_hash || return false
    e0.witness_hash == input.witness.witness_hash || return false
    e0.input_hash == input.input_hash || return false
    e0.output_hash == canonical_hash(_vnext_t2_e0_body_v2(e0.candidate_ref,
        e0.package_hash, e0.witness_hash, e0.contract_refs,
        e0.declaration_hashes, e0.component_identity_hashes, e0.axes,
        e0.children_identity_hash, e0.feedback_identity_hash,
        e0.source_bundle_hash, e0.input_hash, e0.status, e0.resolution,
        e0.accepted, e0.claim_ceiling, e0.gaps))
end

function _vnext_t2_e1_slot_v2(input)
    g1 = input.witness.g1.declaration
    g2 = input.witness.g2.declaration.source
    observed = canonical_hash((g1_operator_chain=g1.operators,
        g1_u_type=g1.u.physical_type, g1_k_type=g1.K.physical_type,
        g1_f_type=g1.f.physical_type, g2_chart_map=g2.chart_map,
        g2_faces=g2.faces, g2_units=g2.units,
        g2_authority=g2.authority))
    _vnext_t2_slot_v2(:E1, :typed_absent, :terminal_deferred,
        :e1_two_region_interface_authority_unsupported, observed,
        (:two_region_interface_law, :interface_flux_authority), (),
        (:single_affine_chart_external_faces_only,))
end

function _vnext_t2_e2_slot_v2(input)
    witness = input.witness
    observed = canonical_hash((g3_endpoints=witness.g3.declaration.endpoints,
        g3_law=witness.g3.declaration.law,
        g3_ledger_entries=witness.g3.declaration.ledger_entries,
        g3_ledger_closure=witness.g3.declaration.ledger_closure,
        g3_feedback_targets=witness.g3.declaration.feedback_targets,
        realization_state=witness.children.realization_state,
        control_payload=witness.children.control_payload,
        control_state=witness.children.control_state,
        binding_state=witness.children.binding_state,
        initial_binding_links=witness.feedback.binding_links,
        current_binding_links=witness.children.binding_state.editable_body.links,
        binding_operation_history=
            witness.children.binding_state.operation_history))
    coupling = witness.coupling
    carried_gaps = Tuple(unique((coupling.gaps..., witness.gaps...)))
    replay_gaps = Tuple(gap for gap in witness.gaps if gap in (
        :realization_full_operation_replay_evidence_not_carried,
        :control_full_operation_replay_evidence_not_carried))
    if coupling.status === :fail_closed || !isempty(coupling.errors)
        return _vnext_t2_slot_v2(:E2, :fail_closed, :none,
            :e2_declared_source_child_contradiction, observed, (),
            Tuple(coupling.errors), carried_gaps)
    elseif !isempty(replay_gaps)
        return _vnext_t2_slot_v2(:E2, :typed_absent, :terminal_deferred,
            :e2_operation_replay_evidence_missing, observed,
            (:full_child_operation_replay_evidence,), (), carried_gaps)
    elseif coupling.resolution === :resolved &&
            coupling.status in (:valid, :resolved, :declared_consistent)
        return _vnext_t2_slot_v2(:E2, :present, :resolved,
            :e2_declared_local_source_child_consistent, observed, (), (),
            carried_gaps)
    end
    _vnext_t2_slot_v2(:E2, :typed_absent, :terminal_deferred,
        :e2_source_child_mapping_missing, observed,
        (:source_field_conversion_map, :target_measure_map), (),
        carried_gaps)
end

function _vnext_t2_gi1_native_authority_hash_v2(input)
    witness = input.witness
    canonical_hash((domain="vnext-t2-gi1-native-authority-v2",
        g1_identity_hash=witness.g1.identity.identity_hash,
        g2_identity_hash=witness.g2.identity.identity_hash,
        g3_identity_hash=witness.g3.identity.identity_hash,
        parent_bundle_hash=witness.manifest.parent_bundle_hash,
        expected_commitment_hash=
            witness.children.expected_commitment.commitment_hash,
        binding_state_hash=witness.children.binding_state.state_hash,
        feedback_identity_hash=witness.feedback.identity_hash,
        source_bundle_hash=witness.manifest.source_bundle_hash))
end

function _vnext_t2_validate_gi1_context_v2(input, context)
    context.candidate_ref == input.package.candidate_ref || return false
    context.package_hash == input.package.package_hash || return false
    context.input_hash == input.input_hash || return false
    context.native_authority_hash ==
        _vnext_t2_gi1_native_authority_hash_v2(input) || return false
    context.status === :prepared_not_executed || return false
    context.resolution === :terminal_deferred || return false
    context.accepted === false || return false
    context.claim_ceiling === VNEXT_T2_UP2_CLAIM_CEILING_V2 || return false
    context.context_hash == canonical_hash(_vnext_t2_gi1_body_v2(
        context.candidate_ref, context.package_hash, context.input_hash,
        context.e0_output_hash, context.native_authority_hash,
        context.status, context.resolution, context.accepted,
        context.claim_ceiling))
end

"""Consume E0 and bind the native authority context without running E1/E2."""
function gi1_authority_context_from_a(input::VNextT2UP2BoundInputV2,
        e0::VNextT2E0PhysicalBindingV2)
    _vnext_t2_require_valid_input_v2(input)
    _vnext_t2_validate_e0_v2(input, e0) ||
        throw(VNextT2ConsumerFailureV2(:gi1a, :e0_binding_mismatch))
    native_authority_hash = _vnext_t2_gi1_native_authority_hash_v2(input)
    body = _vnext_t2_gi1_body_v2(input.package.candidate_ref,
        input.package.package_hash, input.input_hash, e0.output_hash,
        native_authority_hash, :prepared_not_executed, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2)
    VNextT2GI1AuthorityContextV2(input.package.candidate_ref,
        input.package.package_hash, input.input_hash, e0.output_hash,
        native_authority_hash, :prepared_not_executed, :terminal_deferred, false,
        VNEXT_T2_UP2_CLAIM_CEILING_V2, canonical_hash(body))
end

"""Run E1 exactly once after G-I1A has bound the native authority context."""
function e1_authority_slot_from_a(input::VNextT2UP2BoundInputV2,
        context::VNextT2GI1AuthorityContextV2)
    _vnext_t2_require_valid_input_v2(input)
    _vnext_t2_validate_gi1_context_v2(input, context) ||
        throw(VNextT2ConsumerFailureV2(:e1, :gi1_context_mismatch))
    _vnext_t2_e1_slot_v2(input)
end

"""Run E2 exactly once after G-I1A has bound the native authority context."""
function e2_authority_slot_from_a(input::VNextT2UP2BoundInputV2,
        context::VNextT2GI1AuthorityContextV2)
    _vnext_t2_require_valid_input_v2(input)
    _vnext_t2_validate_gi1_context_v2(input, context) ||
        throw(VNextT2ConsumerFailureV2(:e2, :gi1_context_mismatch))
    _vnext_t2_e2_slot_v2(input)
end

export VNEXT_T2_UP2_SCHEMA_ID_V2,VNEXT_T2_UP2_SCHEMA_VERSION_V2,
    VNEXT_T2_UP2_PROFILE_V2,VNextT2FormalGateIdentityV2,
    VNextT2UP2BoundInputV2,VNextT2UP2InputValidationV2,
    VNextT2UP2InputBuildResultV2,VNextT2ConsumerFailureV2,
    VNextT2E0PhysicalBindingV2,VNextT2AuthoritySlotV2,
    VNextT2GI1AuthorityContextV2,vnext_t2_formal_gate_identity_v2,
    vnext_t2_up2_input_from_t1_v2,
    vnext_t2_up2_input_from_t1_admission_v2,
    vnext_t2_up2_validate_input_v2,
    up2_candidate_physical_binding_from_a,gi1_authority_context_from_a,
    e1_authority_slot_from_a,e2_authority_slot_from_a
