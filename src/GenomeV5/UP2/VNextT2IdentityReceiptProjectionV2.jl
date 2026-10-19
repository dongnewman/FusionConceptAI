"""Native-source N10 identity projection for the versioned T2 path.

The five rows read the reconstructed declarations, current G3 binding child,
reloaded T1 V2 package, and fresh adapter/binding receipt.  Legacy migration
provenance remains an explicit gap and is never synthesized.
"""

const VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_ID_V2 =
    "GenomeV5/UP2/VNextT2IdentityReceiptProjectionV2"
const VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_VERSION_V2 = "v2"
const VNEXT_T2_IDENTITY_PROJECTION_PROFILE_V2 =
    "native-source-five-row-identity-projection-v2"
const VNEXT_T2_IDENTITY_ROW_IDS_V2 =
    ("N10-V2-01", "N10-V2-02", "N10-V2-03", "N10-V2-04", "N10-V2-05")
const VNEXT_T2_IDENTITY_ROW_PATHS_V2 = (
    "/source_witness/g1/record/factory_receipt/factory_result/contract_ref/schema_hash",
    "/source_witness/g2/declaration/canonicalization_hash",
    "/source_witness/children/binding_state/source_payload/child_contract_ref",
    "/t1/package/package_hash",
    "/t1/reload_adapter/binding/semantic_package_wire_identity")

abstract type VNextT2IdentityTypedValueV2 end

struct VNextT2DigestIdentityValueV2 <: VNextT2IdentityTypedValueV2
    value::Digest256
end

"""Typed current binding-child identity and its independent authority joins."""
struct VNextT2G3BindingIdentityValueV2 <: VNextT2IdentityTypedValueV2
    candidate_ref::QualifiedRefV1
    parent_g3_declaration_ref::QualifiedRefV1
    parent_g3_declaration_hash::Digest256
    child_kind::Symbol
    child_contract_ref::GenomeContractRef
    binding_child_identity_hash::Digest256
    state_hash::Digest256
end

"""Fresh reload/adapter/binding identity; no legacy migration field is present."""
struct VNextT2ReloadBindingIdentityValueV2 <: VNextT2IdentityTypedValueV2
    candidate_ref::QualifiedRefV1
    semantic_identity::Digest256
    package_hash::Digest256
    wire_hash::Digest256
    reload_adapter_receipt_hash::Digest256
    binding_receipt_hash::Digest256
end

semantic_view(x::VNextT2DigestIdentityValueV2) =
    (kind=:digest256, value=x.value)
semantic_view(x::VNextT2G3BindingIdentityValueV2) =
    (kind=:g3_binding_child_identity, candidate_ref=x.candidate_ref,
        parent_g3_declaration_ref=x.parent_g3_declaration_ref,
        parent_g3_declaration_hash=x.parent_g3_declaration_hash,
        child_kind=x.child_kind, child_contract_ref=x.child_contract_ref,
        binding_child_identity_hash=x.binding_child_identity_hash,
        state_hash=x.state_hash)
semantic_view(x::VNextT2ReloadBindingIdentityValueV2) =
    (kind=:fresh_reload_binding_identity, candidate_ref=x.candidate_ref,
        semantic_identity=x.semantic_identity, package_hash=x.package_hash,
        wire_hash=x.wire_hash,
        reload_adapter_receipt_hash=x.reload_adapter_receipt_hash,
        binding_receipt_hash=x.binding_receipt_hash)

for T in (VNextT2DigestIdentityValueV2,
        VNextT2G3BindingIdentityValueV2,
        VNextT2ReloadBindingIdentityValueV2)
    @eval canonical_json(x::$T) = canonical_json(semantic_view(x))
end

function _vnext_t2_identity_field_body_v2(row_id, field_path,
        source_locator, value_kind, component_hash, original_value,
        authoritative_value)
    (domain="vnext-t2-identity-field-v2", row_id=row_id,
        field_path=field_path, source_locator=source_locator,
        value_kind=value_kind, component_hash=component_hash,
        original_value=original_value,
        authoritative_value=authoritative_value)
end

struct VNextT2IdentityFieldV2
    row_id::String
    field_path::String
    source_locator::String
    value_kind::Symbol
    component_hash::Digest256
    original_value::VNextT2IdentityTypedValueV2
    authoritative_value::VNextT2IdentityTypedValueV2
    field_hash::Digest256
end

function _vnext_t2_identity_field_v2(row_id::String, field_path::String,
        source_locator::String, value_kind::Symbol,
        component_hash::Digest256,
        original_value::VNextT2IdentityTypedValueV2,
        authoritative_value::VNextT2IdentityTypedValueV2)
    isempty(row_id) && throw(ArgumentError("T2 identity row id cannot be empty"))
    isempty(field_path) && throw(ArgumentError("T2 identity field path cannot be empty"))
    isempty(source_locator) && throw(ArgumentError("T2 identity source locator cannot be empty"))
    body = _vnext_t2_identity_field_body_v2(row_id, field_path,
        source_locator, value_kind, component_hash, original_value,
        authoritative_value)
    VNextT2IdentityFieldV2(row_id, field_path, source_locator, value_kind,
        component_hash, original_value, authoritative_value,
        canonical_hash(body))
end

semantic_view(x::VNextT2IdentityFieldV2) = merge(
    _vnext_t2_identity_field_body_v2(x.row_id, x.field_path,
        x.source_locator, x.value_kind, x.component_hash,
        x.original_value, x.authoritative_value),
    (field_hash=x.field_hash,))
canonical_json(x::VNextT2IdentityFieldV2) = canonical_json(semantic_view(x))

function _vnext_t2_identity_projection_body_v2(schema_id, schema_version,
        profile, candidate_ref, package_hash, input_hash, witness_hash, fields,
        gaps, status, resolution, accepted, claim_ceiling)
    (domain="vnext-t2-native-source-identity-projection-v2",
        schema_id=schema_id, schema_version=schema_version, profile=profile,
        candidate_ref=candidate_ref, package_hash=package_hash,
        input_hash=input_hash, witness_hash=witness_hash, fields=fields,
        gaps=gaps, status=status, resolution=resolution, accepted=accepted,
        claim_ceiling=claim_ceiling)
end

struct VNextT2IdentityProjectionV2
    schema_id::String
    schema_version::String
    profile::String
    candidate_ref::QualifiedRefV1
    package_hash::Digest256
    input_hash::Digest256
    witness_hash::Digest256
    fields::NTuple{5,VNextT2IdentityFieldV2}
    gaps::Tuple{Vararg{Symbol}}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    projection_hash::Digest256
end

semantic_view(x::VNextT2IdentityProjectionV2) = merge(
    _vnext_t2_identity_projection_body_v2(x.schema_id, x.schema_version,
        x.profile, x.candidate_ref, x.package_hash, x.input_hash,
        x.witness_hash, x.fields, x.gaps, x.status, x.resolution,
        x.accepted, x.claim_ceiling),
    (projection_hash=x.projection_hash,))
canonical_json(x::VNextT2IdentityProjectionV2) = canonical_json(semantic_view(x))

struct VNextT2IdentityValidationV2
    status::Symbol
    resolution::Symbol
    reason::Symbol
    row_id::Union{Nothing,String}
    field_path::Union{Nothing,String}
    projection_hash::Digest256
end

semantic_view(x::VNextT2IdentityValidationV2) =
    (status=x.status, resolution=x.resolution, reason=x.reason,
        row_id=x.row_id, field_path=x.field_path,
        projection_hash=x.projection_hash)

function _vnext_t2_identity_projection_v2(candidate_ref::QualifiedRefV1,
        package_hash::Digest256, input_hash::Digest256,
        witness_hash::Digest256,
        fields::NTuple{5,VNextT2IdentityFieldV2};
        gaps::Tuple{Vararg{Symbol}}=(:legacy_migration_provenance_absent,),
        status::Symbol=:prepared_not_executed,
        resolution::Symbol=:terminal_deferred,
        accepted::Bool=false,
        claim_ceiling::Symbol=VNEXT_T2_UP2_CLAIM_CEILING_V2)
    body = _vnext_t2_identity_projection_body_v2(
        VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_ID_V2,
        VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_VERSION_V2,
        VNEXT_T2_IDENTITY_PROJECTION_PROFILE_V2, candidate_ref, package_hash,
        input_hash, witness_hash, fields, gaps, status, resolution, accepted,
        claim_ceiling)
    VNextT2IdentityProjectionV2(
        VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_ID_V2,
        VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_VERSION_V2,
        VNEXT_T2_IDENTITY_PROJECTION_PROFILE_V2, candidate_ref, package_hash,
        input_hash, witness_hash, fields, gaps, status, resolution, accepted,
        claim_ceiling, canonical_hash(body))
end

function _vnext_t2_g3_binding_identity_actual_v2(input)
    state = input.witness.children.binding_state
    payload = state.source_payload
    key = payload.key
    VNextT2G3BindingIdentityValueV2(key.candidate_ref,
        key.parent_g3_declaration_ref, key.parent_g3_declaration_hash,
        key.child_kind, payload.child_contract_ref,
        state.binding_child_identity_hash, state.state_hash)
end

function _vnext_t2_g3_binding_identity_authoritative_v2(input)
    state = input.witness.children.binding_state
    payload = state.source_payload
    expected = input.witness.children.expected_commitment
    expected_identity = canonical_hash((domain="g3-binding-child-identity-v2",
        key=payload.key, child_contract_ref=_g3be2_contract(),
        source_record_hash=payload.source_record.source_record_hash,
        source_content_hash=payload.source_content_hash))
    VNextT2G3BindingIdentityValueV2(input.package.candidate_ref,
        expected.g3_declaration_ref,
        expected.g3_declaration_identity_hash, :binding, _g3be2_contract(),
        expected_identity, input.package.g3_authority.binding_state_hash)
end

function _vnext_t2_reload_binding_actual_v2(input)
    adapter = input.adapter
    binding = adapter.binding
    observed = adapter.input
    VNextT2ReloadBindingIdentityValueV2(input.package.candidate_ref,
        adapter.semantic_identity, adapter.package_hash, observed.wire.sha256,
        canonical_hash(semantic_view(adapter)), binding.receipt_hash)
end

function _vnext_t2_reload_binding_authoritative_v2(input)
    gate = input.formal_gate
    VNextT2ReloadBindingIdentityValueV2(gate.candidate_ref,
        gate.semantic_identity, gate.package_hash, gate.wire_hash,
        gate.reload_adapter_receipt_hash, gate.binding_receipt_hash)
end

"""Project five real identity rows from the validated native bound input."""
function n10_identity_projection_from_a(input::VNextT2UP2BoundInputV2)
    _vnext_t2_require_valid_input_v2(input)
    witness = input.witness
    g1_ref = witness.g1.record.factory_receipt.factory_result.contract_ref
    g2_ref = witness.g2.declaration.contract_ref
    binding_contract = witness.children.binding_state.source_payload.child_contract_ref
    fields = (
        _vnext_t2_identity_field_v2(VNEXT_T2_IDENTITY_ROW_IDS_V2[1],
            VNEXT_T2_IDENTITY_ROW_PATHS_V2[1],
            "VNextT2ConcreteG1DeclarationV3.record.factory_receipt.factory_result.contract_ref.schema_hash",
            :Digest256, witness.g1.identity.identity_hash,
            VNextT2DigestIdentityValueV2(g1_ref.schema_hash),
            VNextT2DigestIdentityValueV2(g1_diffusion_schema_hash_v1())),
        _vnext_t2_identity_field_v2(VNEXT_T2_IDENTITY_ROW_IDS_V2[2],
            VNEXT_T2_IDENTITY_ROW_PATHS_V2[2],
            "VNextT2ConcreteG2DeclarationV3.declaration.canonicalization_hash",
            :Digest256, witness.g2.identity.identity_hash,
            VNextT2DigestIdentityValueV2(
                witness.g2.declaration.canonicalization_hash),
            VNextT2DigestIdentityValueV2(
                g2_ref.canonicalization_hash)),
        _vnext_t2_identity_field_v2(VNEXT_T2_IDENTITY_ROW_IDS_V2[3],
            VNEXT_T2_IDENTITY_ROW_PATHS_V2[3],
            "VNextT2ConcreteG3ChildrenV3.binding_state.source_payload.child_contract_ref+key",
            :G3BindingChildIdentity,
            witness.manifest.children_identity_hash,
            _vnext_t2_g3_binding_identity_actual_v2(input),
            _vnext_t2_g3_binding_identity_authoritative_v2(input)),
        _vnext_t2_identity_field_v2(VNEXT_T2_IDENTITY_ROW_IDS_V2[4],
            VNEXT_T2_IDENTITY_ROW_PATHS_V2[4],
            "CandidateStatePackageV5NextV2.package_hash",
            :Digest256, input.package.package_hash,
            VNextT2DigestIdentityValueV2(input.package.package_hash),
            VNextT2DigestIdentityValueV2(
                vnext_t1_package_v2_manifest_hash(input.package))),
        _vnext_t2_identity_field_v2(VNEXT_T2_IDENTITY_ROW_IDS_V2[5],
            VNEXT_T2_IDENTITY_ROW_PATHS_V2[5],
            "VNextT1PackageBindingAdapterResultV2.binding+formal_gate",
            :FreshReloadBindingIdentity, input.adapter.binding.receipt_hash,
            _vnext_t2_reload_binding_actual_v2(input),
            _vnext_t2_reload_binding_authoritative_v2(input)))
    _vnext_t2_identity_projection_v2(input.package.candidate_ref,
        input.package.package_hash, input.input_hash, witness.witness_hash,
        fields)
end

_vnext_t2_identity_value_equal_v2(a, b) =
    typeof(a) === typeof(b) && _vnext_t2_v2_content_equal(a, b)

function _vnext_t2_identity_validation_v2(projection, reason;
        row_id=nothing, field_path=nothing)
    reason === :none ? VNextT2IdentityValidationV2(:valid,
        :terminal_deferred, :none, nothing, nothing,
        projection.projection_hash) :
        VNextT2IdentityValidationV2(:fail_closed, :none, reason,
            row_id, field_path, projection.projection_hash)
end

function _vnext_t2_identity_row_reason_v2(index::Int)
    index == 1 && return :up2_n10_01_g1_schema_descriptor_mismatch
    index == 2 && return :up2_n10_02_g2_canonicalization_descriptor_mismatch
    index == 3 && return :up2_n10_03_g3_binding_child_identity_mismatch
    index == 4 && return :up2_n10_04_t1_package_hash_mismatch
    index == 5 && return :up2_n10_05_reload_binding_identity_mismatch
    :up2_n10_row_unknown
end

"""Recompute and validate every field and the projection envelope."""
function vnext_t2_validate_identity_receipt_v2(
        projection::VNextT2IdentityProjectionV2)
    projection.schema_id == VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_ID_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_schema_id_mismatch)
    projection.schema_version == VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_VERSION_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_schema_version_mismatch)
    projection.profile == VNEXT_T2_IDENTITY_PROJECTION_PROFILE_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_profile_mismatch)
    projection.candidate_ref.version == "v5" ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_candidate_ref_mismatch)
    projection.status === :prepared_not_executed ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_status_mismatch)
    projection.resolution === :terminal_deferred ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_resolution_mismatch)
    projection.accepted === false ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_accepted_mismatch)
    projection.claim_ceiling === VNEXT_T2_UP2_CLAIM_CEILING_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_claim_ceiling_mismatch)
    projection.gaps == (:legacy_migration_provenance_absent,) ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_legacy_provenance_gap_mismatch)
    Tuple(x.row_id for x in projection.fields) ==
        VNEXT_T2_IDENTITY_ROW_IDS_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_row_order_mismatch)
    Tuple(x.field_path for x in projection.fields) ==
        VNEXT_T2_IDENTITY_ROW_PATHS_V2 ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_row_path_mismatch)
    for (index, field) in enumerate(projection.fields)
        expected_hash = canonical_hash(_vnext_t2_identity_field_body_v2(
            field.row_id, field.field_path, field.source_locator,
            field.value_kind, field.component_hash, field.original_value,
            field.authoritative_value))
        field.field_hash == expected_hash ||
            return _vnext_t2_identity_validation_v2(projection,
                :up2_n10_field_hash_mismatch, row_id=field.row_id,
                field_path=field.field_path)
        _vnext_t2_identity_value_equal_v2(field.original_value,
            field.authoritative_value) ||
            return _vnext_t2_identity_validation_v2(projection,
                _vnext_t2_identity_row_reason_v2(index),
                row_id=field.row_id, field_path=field.field_path)
    end
    expected_projection_hash = canonical_hash(
        _vnext_t2_identity_projection_body_v2(projection.schema_id,
            projection.schema_version, projection.profile,
            projection.candidate_ref, projection.package_hash,
            projection.input_hash, projection.witness_hash,
            projection.fields, projection.gaps, projection.status,
            projection.resolution, projection.accepted,
            projection.claim_ceiling))
    projection.projection_hash == expected_projection_hash ||
        return _vnext_t2_identity_validation_v2(projection,
            :up2_n10_projection_hash_mismatch)
    _vnext_t2_identity_validation_v2(projection, :none)
end

"""Rebuild a single row with all enclosing hashes recomputed for attack tests."""
function vnext_t2_identity_projection_with_value_v2(
        projection::VNextT2IdentityProjectionV2, row_id::String,
        value::VNextT2IdentityTypedValueV2)
    row_id in VNEXT_T2_IDENTITY_ROW_IDS_V2 ||
        throw(ArgumentError("unknown T2 identity row"))
    fields = ntuple(5) do index
        field = projection.fields[index]
        field.row_id == row_id ? _vnext_t2_identity_field_v2(field.row_id,
            field.field_path, field.source_locator, field.value_kind,
            field.component_hash, value, field.authoritative_value) : field
    end
    _vnext_t2_identity_projection_v2(projection.candidate_ref,
        projection.package_hash, projection.input_hash,
        projection.witness_hash, fields, gaps=projection.gaps,
        status=projection.status, resolution=projection.resolution,
        accepted=projection.accepted, claim_ceiling=projection.claim_ceiling)
end

function _vnext_t2_changed_digest_v2(value::Digest256, row_id::String)
    changed = canonical_hash((domain="vnext-t2-identity-mutation-v2",
        row_id=row_id, prior=value))
    changed == value && throw(ArgumentError("T2 identity mutation unchanged"))
    changed
end

"""Produce one typed, fully rehashed mutation for each versioned N10 row."""
function vnext_t2_identity_projection_attack_v2(
        projection::VNextT2IdentityProjectionV2, row_id::String)
    field = only(x for x in projection.fields if x.row_id == row_id)
    if row_id in (VNEXT_T2_IDENTITY_ROW_IDS_V2[1],
            VNEXT_T2_IDENTITY_ROW_IDS_V2[2],
            VNEXT_T2_IDENTITY_ROW_IDS_V2[4])
        value = field.original_value::VNextT2DigestIdentityValueV2
        return vnext_t2_identity_projection_with_value_v2(projection,
            row_id, VNextT2DigestIdentityValueV2(
                _vnext_t2_changed_digest_v2(value.value, row_id)))
    elseif row_id == VNEXT_T2_IDENTITY_ROW_IDS_V2[3]
        value = field.original_value::VNextT2G3BindingIdentityValueV2
        changed = VNextT2G3BindingIdentityValueV2(value.candidate_ref,
            value.parent_g3_declaration_ref,
            value.parent_g3_declaration_hash, :control,
            value.child_contract_ref, value.binding_child_identity_hash,
            value.state_hash)
        return vnext_t2_identity_projection_with_value_v2(projection,
            row_id, changed)
    elseif row_id == VNEXT_T2_IDENTITY_ROW_IDS_V2[5]
        value = field.original_value::VNextT2ReloadBindingIdentityValueV2
        changed = VNextT2ReloadBindingIdentityValueV2(value.candidate_ref,
            value.semantic_identity, value.package_hash,
            _vnext_t2_changed_digest_v2(value.wire_hash, row_id),
            value.reload_adapter_receipt_hash, value.binding_receipt_hash)
        return vnext_t2_identity_projection_with_value_v2(projection,
            row_id, changed)
    end
    throw(ArgumentError("unknown T2 identity row"))
end

export VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_ID_V2,
    VNEXT_T2_IDENTITY_PROJECTION_SCHEMA_VERSION_V2,
    VNEXT_T2_IDENTITY_PROJECTION_PROFILE_V2,
    VNEXT_T2_IDENTITY_ROW_IDS_V2,VNextT2IdentityTypedValueV2,
    VNextT2DigestIdentityValueV2,VNextT2G3BindingIdentityValueV2,
    VNextT2ReloadBindingIdentityValueV2,VNextT2IdentityFieldV2,
    VNextT2IdentityProjectionV2,VNextT2IdentityValidationV2,
    vnext_t2_validate_identity_receipt_v2,
    vnext_t2_identity_projection_with_value_v2,
    vnext_t2_identity_projection_attack_v2
