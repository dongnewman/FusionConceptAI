"""AD-33 shared G1/G2 parent-baseline binding typed-absence scaffold.

This additive file is intentionally not included by FusionConceptAI.jl. The
current production path has no source-backed G1/G2 V1 declaration receipt, so
it can construct only typed absence. Present records have a private receipt
seam and cannot be created from fixtures, URI-only refs, or synthetic values.
No package, registry, T0/T1/T2 entry, provider, mesh, solver, or physical path
is called here.
"""

const VNEXT_PBB_SCHEMA_ID = "GenomeV5/Integration/VNextParentBaselineBindingV1"
const VNEXT_PBB_SCHEMA_VERSION = "v1"
const VNEXT_PBB_ABSENT_DOMAIN_G1 = "ad33:G1:parent-baseline-absent:v1"
const VNEXT_PBB_ABSENT_DOMAIN_G2 = "ad33:G2:parent-baseline-absent:v1"
const VNEXT_PBB_CHILD_ABSENT_DOMAIN_G1 = "ad33:G1:child-key-absent:v1"
const VNEXT_PBB_CHILD_ABSENT_DOMAIN_G2 = "ad33:G2:child-key-absent:v1"
const VNEXT_PBB_STATE_DOMAIN_G1 = "ad33:G1:typed-absent-state:v1"
const VNEXT_PBB_STATE_DOMAIN_G2 = "ad33:G2:typed-absent-state:v1"
const VNEXT_PBB_ALLOWED_REASONS = (:v1_declaration_instance_unavailable,
    :source_locator_unavailable, :factory_input_unavailable,
    :candidate_binding_unavailable)
const VNEXT_PBB_ERROR_CODES = (:none, :baseline_authority_absent,
    :synthetic_fixture_authority, :ref_only_authority, :foreign_candidate,
    :foreign_layer, :foreign_child, :child_contract_identity_mismatch,
    :parent_binding_absence_digest_mismatch, :status_invalid,
    :source_backed_receipt_unavailable, :absent_to_present_cas_forbidden)

abstract type AbstractRequestedCandidateV1 end
struct G1RequestedCandidateV1 <: AbstractRequestedCandidateV1
    candidate_ref::QualifiedRefV1
    function G1RequestedCandidateV1(candidate_ref::QualifiedRefV1)
        candidate_ref.version == "v5" || throw(ArgumentError("G1 candidate must be v5"))
        new(candidate_ref)
    end
end
struct G2RequestedCandidateV1 <: AbstractRequestedCandidateV1
    contract_ref::GenomeContractRef
    function G2RequestedCandidateV1(contract_ref::GenomeContractRef)
        contract_ref.version == "v5" || throw(ArgumentError("G2 candidate contract must be v5"))
        new(contract_ref)
    end
end

struct SourceLocatorV1
    module_path::String
    module_identity::String
    declaration_type::String
    factory_identity::String
    input_locator::String
    function SourceLocatorV1(module_path::String, module_identity::String,
                             declaration_type::String, factory_identity::String,
                             input_locator::String)
        all(!isempty, (module_path, module_identity, declaration_type,
                       factory_identity, input_locator)) ||
            throw(ArgumentError("source locator fields cannot be empty"))
        new(module_path, module_identity, declaration_type, factory_identity,
            input_locator)
    end
end

struct FactoryConstructionReceiptV1
    module_identity::String
    declaration_type::String
    factory_identity::String
    input_locator::String
    construction_status::Symbol
    candidate_binding_status::Symbol
    declaration_hash_recomputed::Bool
    function FactoryConstructionReceiptV1(module_identity::String,
            declaration_type::String, factory_identity::String,
            input_locator::String, construction_status::Symbol,
            candidate_binding_status::Symbol, declaration_hash_recomputed::Bool)
        construction_status in (:source_backed_present, :unavailable) ||
            throw(ArgumentError("invalid construction status"))
        candidate_binding_status in (:exact, :unavailable) ||
            throw(ArgumentError("invalid candidate binding status"))
        new(module_identity, declaration_type, factory_identity, input_locator,
            construction_status, candidate_binding_status,
            declaration_hash_recomputed)
    end
end

abstract type AbstractParentRefV1 end
struct G1ParentRefV1 <: AbstractParentRefV1
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    function G1ParentRefV1(candidate_ref::QualifiedRefV1, source_ref::QualifiedRefV1)
        new(candidate_ref, source_ref)
    end
end
struct G2ParentRefV1 <: AbstractParentRefV1
    candidate_ref::GenomeContractRef
    source_ref::QualifiedRefV1
    function G2ParentRefV1(candidate_ref::GenomeContractRef, source_ref::QualifiedRefV1)
        new(candidate_ref, source_ref)
    end
end

struct ChildContractSchemaIdentityV1
    contract_ref::GenomeContractRef
    schema_hash::Digest256
    canonicalization_hash::Digest256
    compatibility_profile::String
    identity_hash::Digest256
    function ChildContractSchemaIdentityV1(contract_ref::GenomeContractRef,
            schema_hash::Digest256, canonicalization_hash::Digest256,
            compatibility_profile::String, identity_hash::Digest256)
        contract_ref.schema_hash == schema_hash ||
            throw(ArgumentError("child schema hash mismatch"))
        contract_ref.canonicalization_hash == canonicalization_hash ||
            throw(ArgumentError("child canonicalization hash mismatch"))
        contract_ref.compatibility_profile == compatibility_profile ||
            throw(ArgumentError("child compatibility profile mismatch"))
        new(contract_ref, schema_hash, canonicalization_hash,
            compatibility_profile, identity_hash)
    end
end

struct G1ParentBaselineRequestV1
    layer::Symbol
    requested_candidate::G1RequestedCandidateV1
    requested_public_contract::GenomeContractRef
    child_contract::ChildContractSchemaIdentityV1
    child_kind::Symbol
    function G1ParentBaselineRequestV1(requested_candidate::G1RequestedCandidateV1,
            requested_public_contract::GenomeContractRef,
            child_contract::ChildContractSchemaIdentityV1,
            child_kind::Symbol)
        child_kind === :mechanism || throw(ArgumentError("G1 child kind must be mechanism"))
        new(:G1, requested_candidate, requested_public_contract,
            child_contract, child_kind)
    end
end

struct G2ParentBaselineRequestV1
    layer::Symbol
    requested_candidate::G2RequestedCandidateV1
    requested_public_contract::GenomeContractRef
    child_contract::ChildContractSchemaIdentityV1
    child_kind::Symbol
    function G2ParentBaselineRequestV1(requested_candidate::G2RequestedCandidateV1,
            requested_public_contract::GenomeContractRef,
            child_contract::ChildContractSchemaIdentityV1,
            child_kind::Symbol)
        child_kind === :geometry || throw(ArgumentError("G2 child kind must be geometry"))
        new(:G2, requested_candidate, requested_public_contract,
            child_contract, child_kind)
    end
end

abstract type AbstractParentBaselineBindingV1 end

struct AbsentParentBaselineBindingV1{C<:AbstractRequestedCandidateV1} <: AbstractParentBaselineBindingV1
    layer::Symbol
    requested_candidate::C
    requested_public_contract::GenomeContractRef
    reason::Symbol
    absence_domain::String
    absence_digest::Digest256
end

struct _SourceBackedReceiptAuthorityV1 end

struct SourceBackedV1DeclarationReceiptV1{R<:AbstractParentRefV1}
    layer::Symbol
    actual_parent_ref::R
    source_locator::SourceLocatorV1
    factory_receipt::FactoryConstructionReceiptV1
    raw_source_sha256::Digest256
    semantic_body_sha256::Digest256
    parent_declaration_sha256::Digest256
    authority_status::Symbol
    function SourceBackedV1DeclarationReceiptV1(::_SourceBackedReceiptAuthorityV1,
            layer::Symbol, actual_parent_ref::R, source_locator::SourceLocatorV1,
            factory_receipt::FactoryConstructionReceiptV1,
            raw_source_sha256::Digest256, semantic_body_sha256::Digest256,
            parent_declaration_sha256::Digest256) where {R<:AbstractParentRefV1}
        layer in (:G1, :G2) || throw(ArgumentError("invalid receipt layer"))
        factory_receipt.construction_status === :source_backed_present ||
            throw(ArgumentError("source-backed construction is unavailable"))
        factory_receipt.candidate_binding_status === :exact ||
            throw(ArgumentError("source-backed candidate binding is unavailable"))
        factory_receipt.declaration_hash_recomputed ||
            throw(ArgumentError("declaration hash was not recomputed"))
        new{R}(layer, actual_parent_ref, source_locator, factory_receipt,
            raw_source_sha256, semantic_body_sha256, parent_declaration_sha256,
            :verified_source_backed)
    end
end

struct PresentParentBaselineBindingV1{C<:AbstractRequestedCandidateV1,R<:AbstractParentRefV1} <: AbstractParentBaselineBindingV1
    layer::Symbol
    actual_parent_ref::R
    parent_declaration_hash::Digest256
    baseline_raw_source_sha256::Digest256
    baseline_semantic_body_sha256::Digest256
    source_locator::SourceLocatorV1
    factory_receipt::FactoryConstructionReceiptV1
    requested_candidate::C
    requested_public_contract::GenomeContractRef
    parent_binding_hash::Digest256
    function PresentParentBaselineBindingV1(::_SourceBackedReceiptAuthorityV1,
            layer::Symbol, actual_parent_ref::R, parent_declaration_hash::Digest256,
            baseline_raw_source_sha256::Digest256,
            baseline_semantic_body_sha256::Digest256,
            source_locator::SourceLocatorV1,
            factory_receipt::FactoryConstructionReceiptV1,
            requested_candidate::C,
            requested_public_contract::GenomeContractRef) where {
                C<:AbstractRequestedCandidateV1,R<:AbstractParentRefV1}
        layer in (:G1, :G2) || throw(ArgumentError("invalid present layer"))
        factory_receipt.construction_status === :source_backed_present ||
            throw(ArgumentError("present binding requires source-backed receipt"))
        factory_receipt.candidate_binding_status === :exact ||
            throw(ArgumentError("present binding requires exact candidate binding"))
        factory_receipt.declaration_hash_recomputed ||
            throw(ArgumentError("present binding requires declaration hash recomputation"))
        binding = _present_parent_hash(layer, actual_parent_ref,
            parent_declaration_hash, baseline_raw_source_sha256,
            baseline_semantic_body_sha256, source_locator, factory_receipt,
            requested_candidate, requested_public_contract)
        new{C,R}(layer, actual_parent_ref, parent_declaration_hash,
            baseline_raw_source_sha256, baseline_semantic_body_sha256,
            source_locator, factory_receipt, requested_candidate,
            requested_public_contract, binding)
    end
end

abstract type AbstractChildKeyV1 end

struct AbsentChildKeyV1{C<:AbstractRequestedCandidateV1} <: AbstractChildKeyV1
    layer::Symbol
    requested_candidate::C
    requested_public_contract::GenomeContractRef
    child_kind::Symbol
    child_id::String
    child_contract_schema_identity::ChildContractSchemaIdentityV1
    parent_binding_absence_digest::Digest256
    child_key_digest::Digest256
end

struct PresentChildKeyV1{C<:AbstractRequestedCandidateV1,R<:AbstractParentRefV1} <: AbstractChildKeyV1
    layer::Symbol
    requested_candidate::C
    requested_public_contract::GenomeContractRef
    child_kind::Symbol
    child_id::String
    child_contract_schema_identity::ChildContractSchemaIdentityV1
    parent_binding::PresentParentBaselineBindingV1{C,R}
    actual_parent_ref::R
    parent_declaration_hash::Digest256
    child_key_digest::Digest256
end

struct TypedAbsentSourcePayloadV1
    layer::Symbol
    reason::Symbol
    absence_digest::Digest256
end

struct CanonicalBytesV1
    bytes::Vector{UInt8}
    sha256::Digest256
    function CanonicalBytesV1(bytes::Vector{UInt8})
        owned = copy(bytes)
        new(owned, Digest256(bytes2hex(SHA.sha256(copy(owned)))))
    end
end
canonical_bytes(x::CanonicalBytesV1) = copy(x.bytes)
canonical_sha256(x::CanonicalBytesV1) = x.sha256

struct OperationHistoryV1{N}
    digests::NTuple{N,Digest256}
    function OperationHistoryV1(digests::NTuple{N,Digest256}) where {N}
        0 <= N <= 64 || throw(ArgumentError("operation history bound exceeded"))
        new{N}(digests)
    end
end

struct EditStateV1{B<:AbstractParentBaselineBindingV1,K<:AbstractChildKeyV1}
    layer::Symbol
    baseline_binding::B
    child_key::K
    source_payload::TypedAbsentSourcePayloadV1
    contract_admission::Symbol
    state_hash::Digest256
    canonical_state::CanonicalBytesV1
    source_content_hash::Digest256
    history::OperationHistoryV1{0}
end

struct ReplaceSourcePayloadInputV1{K<:AbstractChildKeyV1}
    operation_id::String
    key::K
    expected_prior_state_hash::Digest256
    expected_prior_source_content_hash::Digest256
    replacement_payload_hash::Digest256
end

struct EditFailureReceiptV1
    operation_id::String
    error_code::Symbol
    status::Symbol
    prior_canonical_bytes::CanonicalBytesV1
    prior_state_hash::Digest256
    prior_source_content_hash::Digest256
    history::OperationHistoryV1{0}
    published::Bool
    history_advanced::Bool
end

_pbb_layer_text(layer::Symbol) = layer === :G1 ? "G1" : layer === :G2 ? "G2" :
    throw(ArgumentError("invalid layer"))
_pbb_candidate_text(x::G1RequestedCandidateV1) =
    string("qualified:", x.candidate_ref.id, ":", x.candidate_ref.version)
_pbb_candidate_text(x::G2RequestedCandidateV1) =
    string("contract:", x.contract_ref.uri, ":", x.contract_ref.version, ":",
           x.contract_ref.schema_hash.value, ":", x.contract_ref.canonicalization_hash.value,
           ":", x.contract_ref.compatibility_profile)
_pbb_contract_text(x::GenomeContractRef) =
    string(x.uri, ":", x.version, ":", x.schema_hash.value, ":",
           x.canonicalization_hash.value, ":", x.compatibility_profile)
_pbb_contract_text(x::ChildContractSchemaIdentityV1) =
    string(_pbb_contract_text(x.contract_ref), ":", x.schema_hash.value, ":",
           x.canonicalization_hash.value, ":", x.compatibility_profile, ":",
           x.identity_hash.value)
_pbb_locator_text(x::SourceLocatorV1) =
    string(x.module_path, ":", x.module_identity, ":", x.declaration_type, ":",
           x.factory_identity, ":", x.input_locator)
_pbb_receipt_text(x::FactoryConstructionReceiptV1) =
    string(x.module_identity, ":", x.declaration_type, ":", x.factory_identity, ":",
           x.input_locator, ":", x.construction_status, ":",
           x.candidate_binding_status, ":", x.declaration_hash_recomputed)
_pbb_parent_ref_text(x::G1ParentRefV1) =
    string("G1:", _pbb_candidate_text(G1RequestedCandidateV1(x.candidate_ref)), ":",
           x.source_ref.id, ":", x.source_ref.version)
_pbb_parent_ref_text(x::G2ParentRefV1) =
    string("G2:", _pbb_contract_text(x.candidate_ref), ":",
           x.source_ref.id, ":", x.source_ref.version)

function _pbb_hash(domain::String, payload::String)
    digest256_text(string(domain, "\0", payload))
end

function _child_contract_identity_expected(x::ChildContractSchemaIdentityV1)
    _pbb_hash("ad33:child-contract-identity:v1", string(
        _pbb_contract_text(x.contract_ref), ":", x.schema_hash.value, ":",
        x.canonicalization_hash.value, ":", x.compatibility_profile))
end
child_contract_identity_matches(x::ChildContractSchemaIdentityV1) =
    x.identity_hash == _child_contract_identity_expected(x)
child_contract_identity_matches(x::ChildContractSchemaIdentityV1, expected::Digest256) =
    expected == _child_contract_identity_expected(x)

function _present_parent_hash(layer::Symbol, parent_ref::R,
        declaration_hash::Digest256, raw_hash::Digest256, semantic_hash::Digest256,
        locator::SourceLocatorV1, receipt::FactoryConstructionReceiptV1,
        candidate::C, public_contract::GenomeContractRef) where {
            R<:AbstractParentRefV1,C<:AbstractRequestedCandidateV1}
    _pbb_hash(string("ad33:", _pbb_layer_text(layer),
        ":parent-baseline-present:v1"), string(
        _pbb_layer_text(layer), ":", _pbb_parent_ref_text(parent_ref), ":",
        declaration_hash.value, ":", raw_hash.value, ":", semantic_hash.value,
        ":", _pbb_locator_text(locator), ":", _pbb_receipt_text(receipt),
        ":", _pbb_candidate_text(candidate), ":",
        _pbb_contract_text(public_contract)))
end

function _absent_parent_hash(layer::Symbol, candidate::C,
        public_contract::GenomeContractRef, reason::Symbol) where {
            C<:AbstractRequestedCandidateV1}
    _pbb_hash(layer === :G1 ? VNEXT_PBB_ABSENT_DOMAIN_G1 :
        VNEXT_PBB_ABSENT_DOMAIN_G2, string(_pbb_layer_text(layer), ":",
        _pbb_candidate_text(candidate), ":", _pbb_contract_text(public_contract),
        ":", reason))
end

function _validate_request(layer::Symbol, candidate::C,
        public_contract::GenomeContractRef, child_kind::Symbol) where {
            C<:AbstractRequestedCandidateV1}
    _pbb_layer_text(layer)
    _pbb_candidate_text(candidate)
    public_contract.version == "v5" || throw(ArgumentError("foreign_candidate"))
    if layer === :G1
        candidate isa G1RequestedCandidateV1 || throw(ArgumentError("foreign_layer"))
        child_kind === :mechanism || throw(ArgumentError("foreign_child"))
    else
        candidate isa G2RequestedCandidateV1 || throw(ArgumentError("foreign_layer"))
        child_kind === :geometry || throw(ArgumentError("foreign_child"))
        candidate.contract_ref == public_contract || throw(ArgumentError("foreign_candidate"))
    end
    child_kind
end

function _make_absent_parent(layer::Symbol, candidate::C,
        public_contract::GenomeContractRef, reason::Symbol) where {
            C<:AbstractRequestedCandidateV1}
    reason in VNEXT_PBB_ALLOWED_REASONS || throw(ArgumentError("status_invalid"))
    _validate_request(layer, candidate, public_contract,
        layer === :G1 ? :mechanism : :geometry)
    domain = layer === :G1 ? VNEXT_PBB_ABSENT_DOMAIN_G1 : VNEXT_PBB_ABSENT_DOMAIN_G2
    AbsentParentBaselineBindingV1{C}(layer, candidate, public_contract, reason,
        domain, _absent_parent_hash(layer, candidate, public_contract, reason))
end

function _absent_child_hash(layer::Symbol, candidate::C,
        public_contract::GenomeContractRef, child_kind::Symbol, child_id::String,
        child_contract::ChildContractSchemaIdentityV1,
        parent_absence_digest::Digest256) where {C<:AbstractRequestedCandidateV1}
    domain = layer === :G1 ? VNEXT_PBB_CHILD_ABSENT_DOMAIN_G1 :
        VNEXT_PBB_CHILD_ABSENT_DOMAIN_G2
    _pbb_hash(domain, string(_pbb_layer_text(layer), ":",
        _pbb_candidate_text(candidate), ":", _pbb_contract_text(public_contract),
        ":", child_kind, ":", child_id, ":",
        _pbb_contract_text(child_contract), ":", parent_absence_digest.value))
end

function _make_absent_child(parent::AbsentParentBaselineBindingV1{C},
        child_contract::ChildContractSchemaIdentityV1,
        child_kind::Symbol, child_id::String) where {C<:AbstractRequestedCandidateV1}
    isempty(child_id) && throw(ArgumentError("foreign_child"))
    expected_kind = parent.layer === :G1 ? :mechanism : :geometry
    child_kind === expected_kind || throw(ArgumentError("foreign_child"))
    child_contract_identity_matches(child_contract) ||
        throw(ArgumentError("child_contract_identity_mismatch"))
    digest = _absent_child_hash(parent.layer, parent.requested_candidate,
        parent.requested_public_contract, child_kind, child_id, child_contract,
        parent.absence_digest)
    AbsentChildKeyV1{C}(parent.layer, parent.requested_candidate,
        parent.requested_public_contract, child_kind, child_id, child_contract,
        parent.absence_digest, digest)
end

function _absent_payload(layer::Symbol, parent_absence_digest::Digest256)
    TypedAbsentSourcePayloadV1(layer, :v1_declaration_instance_unavailable,
        _pbb_hash(string("ad33:", _pbb_layer_text(layer), ":source-payload-absent:v1"),
            parent_absence_digest.value))
end

function _state_bytes(layer::Symbol, parent_absence_digest::Digest256,
        child_digest::Digest256, payload_digest::Digest256)
    Vector{UInt8}(codeunits(string("schema=", VNEXT_PBB_SCHEMA_ID,
        ";version=", VNEXT_PBB_SCHEMA_VERSION, ";layer=", _pbb_layer_text(layer),
        ";parent_absence_digest=", parent_absence_digest.value,
        ";child_key_digest=", child_digest.value,
        ";source_payload_absence_digest=", payload_digest.value,
        ";contract_admission=terminal_deferred")))
end

function _make_absent_state(parent::AbsentParentBaselineBindingV1{C},
        child::AbsentChildKeyV1{C}) where {C<:AbstractRequestedCandidateV1}
    child.layer == parent.layer || throw(ArgumentError("foreign_layer"))
    child.parent_binding_absence_digest == parent.absence_digest ||
        throw(ArgumentError("parent_binding_absence_digest_mismatch"))
    payload = _absent_payload(parent.layer, parent.absence_digest)
    bytes = CanonicalBytesV1(_state_bytes(parent.layer, parent.absence_digest,
        child.child_key_digest, payload.absence_digest))
    domain = parent.layer === :G1 ? VNEXT_PBB_STATE_DOMAIN_G1 : VNEXT_PBB_STATE_DOMAIN_G2
    state_hash = _pbb_hash(domain, String(copy(bytes.bytes)))
    EditStateV1{typeof(parent),typeof(child)}(parent.layer, parent, child,
        payload, :terminal_deferred, state_hash, bytes,
        _pbb_hash(string("ad33:", _pbb_layer_text(parent.layer),
            ":source-content-absent:v1"), parent.absence_digest.value),
        OperationHistoryV1(()))
end

function g1_typed_absent_state(request::G1ParentBaselineRequestV1;
        reason::Symbol=:v1_declaration_instance_unavailable)
    parent = _make_absent_parent(:G1, request.requested_candidate,
        request.requested_public_contract, reason)
    child = _make_absent_child(parent, request.child_contract,
        request.child_kind, "g1-mechanism-edit-prec")
    _make_absent_state(parent, child)
end

function g2_typed_absent_state(request::G2ParentBaselineRequestV1;
        reason::Symbol=:v1_declaration_instance_unavailable)
    parent = _make_absent_parent(:G2, request.requested_candidate,
        request.requested_public_contract, reason)
    child = _make_absent_child(parent, request.child_contract,
        request.child_kind, "g2-geometry-edit-prec")
    _make_absent_state(parent, child)
end

function admit_present_parent(request::G1ParentBaselineRequestV1, mode::Symbol)
    mode === :fixture && throw(ArgumentError("synthetic_fixture_authority"))
    mode === :ref_only && throw(ArgumentError("ref_only_authority"))
    mode === :synthetic && throw(ArgumentError("synthetic_fixture_authority"))
    mode === :foreign && throw(ArgumentError("foreign_candidate"))
    throw(ArgumentError("source_backed_receipt_unavailable"))
end
function admit_present_parent(request::G2ParentBaselineRequestV1, mode::Symbol)
    mode === :fixture && throw(ArgumentError("synthetic_fixture_authority"))
    mode === :ref_only && throw(ArgumentError("ref_only_authority"))
    mode === :synthetic && throw(ArgumentError("synthetic_fixture_authority"))
    mode === :foreign && throw(ArgumentError("foreign_candidate"))
    throw(ArgumentError("source_backed_receipt_unavailable"))
end

function admit_present_parent(request::G1ParentBaselineRequestV1,
        receipt::SourceBackedV1DeclarationReceiptV1)
    receipt.layer === :G1 || throw(ArgumentError("foreign_layer"))
    throw(ArgumentError("source_backed_receipt_unavailable"))
end
function admit_present_parent(request::G2ParentBaselineRequestV1,
        receipt::SourceBackedV1DeclarationReceiptV1)
    receipt.layer === :G2 || throw(ArgumentError("foreign_layer"))
    throw(ArgumentError("source_backed_receipt_unavailable"))
end

function _failure(state::EditStateV1, operation_id::String, code::Symbol)
    code in VNEXT_PBB_ERROR_CODES || throw(ArgumentError("status_invalid"))
    EditFailureReceiptV1(operation_id, code, :rejected,
        CanonicalBytesV1(copy(state.canonical_state.bytes)), state.state_hash,
        state.source_content_hash, state.history, false, false)
end

function replace_source_payload(state::EditStateV1,
        input::ReplaceSourcePayloadInputV1)
    input.key == state.child_key || return _failure(state, input.operation_id, :foreign_child)
    state.contract_admission === :terminal_deferred ||
        return _failure(state, input.operation_id, :status_invalid)
    _failure(state, input.operation_id, :baseline_authority_absent)
end

function promote_absent_to_present(::EditStateV1, ::SourceBackedV1DeclarationReceiptV1)
    throw(ArgumentError("absent_to_present_cas_forbidden"))
end
function promote_absent_to_present(::EditStateV1, ::Symbol)
    throw(ArgumentError("absent_to_present_cas_forbidden"))
end

function verify_absent_parent(binding::AbsentParentBaselineBindingV1)
    expected = _absent_parent_hash(binding.layer, binding.requested_candidate,
        binding.requested_public_contract, binding.reason)
    binding.absence_domain == (binding.layer === :G1 ? VNEXT_PBB_ABSENT_DOMAIN_G1 :
        VNEXT_PBB_ABSENT_DOMAIN_G2) && binding.absence_digest == expected
end
function verify_absent_child(key::AbsentChildKeyV1)
    child_contract_identity_matches(key.child_contract_schema_identity) || return false
    expected = _absent_child_hash(key.layer, key.requested_candidate,
        key.requested_public_contract, key.child_kind, key.child_id,
        key.child_contract_schema_identity, key.parent_binding_absence_digest)
    key.child_key_digest == expected
end
function verify_absent_state(state::EditStateV1)
    state.contract_admission === :terminal_deferred || return false
    state.baseline_binding isa AbsentParentBaselineBindingV1 || return false
    state.child_key isa AbsentChildKeyV1 || return false
    verify_absent_parent(state.baseline_binding) || return false
    verify_absent_child(state.child_key) || return false
    state.child_key.parent_binding_absence_digest == state.baseline_binding.absence_digest || return false
    state.source_payload.layer == state.layer || return false
    CanonicalBytesV1(copy(state.canonical_state.bytes)).sha256 ==
        state.canonical_state.sha256 || return false
    expected_bytes = _state_bytes(state.layer, state.baseline_binding.absence_digest,
        state.child_key.child_key_digest, state.source_payload.absence_digest)
    state.canonical_state.bytes == expected_bytes || return false
    domain = state.layer === :G1 ? VNEXT_PBB_STATE_DOMAIN_G1 : VNEXT_PBB_STATE_DOMAIN_G2
    state.state_hash == _pbb_hash(domain, String(copy(expected_bytes))) || return false
    true
end
