"""Additive V2 authority recheck for the local T0 transport.

The recheck owns no source I/O and does not materialize the legacy tuple
representation.  It checks every byte-bearing field in the producer record,
then retains one immutable V2 carrier for the transport projection.  Typed
absence is a first-class result and is never replaced by a G3 projection.
"""

const VNEXT_AR_LOCAL_SCHEMA_ID_V2 = "GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2"
const VNEXT_AR_LOCAL_SCHEMA_VERSION_V2 = "v2"
const VNEXT_AR_LOCAL_LAYERS_V2 = (:G1, :G2, :G3)
const VNEXT_AR_LOCAL_CHILD_KINDS_V2 = (:realization, :control, :binding)

_vnext_ar_v2_sha(bytes::AbstractVector{UInt8}) =
    Digest256(bytes2hex(SHA.sha256(copy(Vector{UInt8}(bytes)))))

struct VNextAuthorityRecheckLocalV2Input
    candidate_ref::QualifiedRefV1
    transport::Union{Nothing,VNextT0LocalTransportV1}
end

struct VNextAuthorityRecheckLocalV2Checked
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    declarations::NTuple{3,VNextT0LocalDeclarationV1}
    children::NTuple{3,VNextT0LocalChildV1}
    feedback::Tuple
    g3_children_deferred::Bool
end

struct VNextAuthorityRecheckLocalV2TypedAbsent
    candidate_ref::QualifiedRefV1
    bundle_hash::Digest256
    reasons::Tuple{Vararg{Symbol}}
    g3_children_deferred::Bool
end

struct VNextAuthorityRecheckLocalV2Result
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    output::Union{Nothing,VNextAuthorityRecheckLocalV2Checked,VNextAuthorityRecheckLocalV2TypedAbsent}
    errors::Tuple{Vararg{Symbol}}
    reasons::Tuple{Vararg{Symbol}}
    prior_bundle_bytes::VNextT1CanonicalBytesV2
    prior_bundle_sha256::Digest256
end

function _vnext_ar_v2_bundle_body(t::VNextT0LocalTransportV1)
    _vnl_t0_bundle_body_v1(t.candidate_ref, t.declarations, t.children,
        t.feedback, t.frozen_source_authority)
end

function _vnext_ar_v2_carrier(x)
    VNextT1CanonicalBytesV2(collect(codeunits(canonical_json(x))))
end

# Composite transport records own byte vectors and therefore do not have a
# useful generic `==` identity across serialization.  Join their canonical
# content without changing equality semantics for any public type.
function _vnext_ar_v2_content_equal(a, b)
    a === b || canonical_json(a) == canonical_json(b)
end

function _vnext_ar_v2_valid_bytes(x, field::Symbol)
    x isa VNextT0LocalBytesV1 || return false, field
    x.sha256 == _vnext_ar_v2_sha(x.bytes) || return false, Symbol(string(field), "_hash_mismatch")
    isempty(x.bytes) && return false, Symbol(string(field), "_zero_bytes")
    true, nothing
end

function _vnext_ar_v2_validate_declaration(d, candidate, index)
    if d isa VNextT0LocalAbsentDeclarationV1
        d.candidate_ref == candidate || return (:candidate_mismatch,)
        d.layer == VNEXT_AR_LOCAL_LAYERS_V2[index] || return (:layer_order_mismatch,)
        d.status in VNEXT_T0_LOCAL_DEFERRED_V1 || return (:absence_status_invalid,)
        d.reason in (:missing_material, :source_unavailable, :declaration_unavailable) ||
            return (:absence_reason_invalid,)
        return ()
    end
    d isa VNextT0LocalPresentDeclarationV1 || return (:declaration_type_invalid,)
    d.candidate_ref == candidate || return (:candidate_mismatch,)
    d.layer == VNEXT_AR_LOCAL_LAYERS_V2[index] || return (:layer_order_mismatch,)
    d.source_locator.source_ref == d.source_ref || return (:source_locator_ref_mismatch,)
    d.source_locator.source_sha256 == d.source_bytes.sha256 || return (:source_locator_hash_mismatch,)
    d.source_locator.source_size == length(d.source_bytes.bytes) || return (:source_size_mismatch,)
    d.source_identity_hash == canonical_hash((kind=:source, ref=d.source_ref,
        bytes_sha256=d.source_bytes.sha256)) || return (:source_identity_hash_mismatch,)
    d.declaration_identity_hash == canonical_hash((kind=:declaration,
        ref=d.declaration_ref, bytes_sha256=d.declaration_bytes.sha256)) ||
        return (:declaration_identity_hash_mismatch,)
    d.semantic_body.body isa Any || return (:semantic_body_missing,)
    d.semantic_body.bytes.bytes == Vector{UInt8}(codeunits(canonical_json(d.semantic_body.body))) ||
        return (:semantic_body_bytes_identity_mismatch,)
    d.semantic_body.bytes.sha256 == _vnext_ar_v2_sha(d.semantic_body.bytes.bytes) ||
        return (:semantic_body_hash_mismatch,)
    d.factory_receipt.candidate_ref == candidate || return (:receipt_candidate_mismatch,)
    d.declaration_receipt.candidate_ref == candidate || return (:receipt_candidate_mismatch,)
    d.factory_receipt.declaration_ref == d.declaration_ref || return (:receipt_declaration_mismatch,)
    d.declaration_receipt.declaration_ref == d.declaration_ref || return (:receipt_declaration_mismatch,)
    d.axes == d.factory_receipt.axes || return (:axis_factory_mismatch,)
    d.axes == d.declaration_receipt.axes || return (:axis_declaration_mismatch,)
    d.factory_receipt.bytes.bytes == Vector{UInt8}(codeunits(canonical_json(d.factory_receipt.factory_result))) ||
        return (:factory_receipt_bytes_identity_mismatch,)
    d.declaration_receipt.bytes.bytes == Vector{UInt8}(codeunits(canonical_json(d.declaration_receipt.factory_result))) ||
        return (:declaration_receipt_bytes_identity_mismatch,)
    all(d.axes[i].id == VNEXT_T0_LOCAL_AXIS_IDS_V1[i] for i in 1:4) ||
        return (:axis_identity_or_order_invalid,)
    ok, reason = _vnext_ar_v2_valid_bytes(d.source_bytes, :source_bytes); ok || return (reason,)
    ok, reason = _vnext_ar_v2_valid_bytes(d.declaration_bytes, :declaration_bytes); ok || return (reason,)
    ok, reason = _vnext_ar_v2_valid_bytes(d.semantic_body.bytes, :semantic_body_bytes); ok || return (reason,)
    ok, reason = _vnext_ar_v2_valid_bytes(d.factory_receipt.bytes, :factory_receipt_bytes); ok || return (reason,)
    ok, reason = _vnext_ar_v2_valid_bytes(d.declaration_receipt.bytes, :declaration_receipt_bytes); ok || return (reason,)
    ()
end

function _vnext_ar_v2_absence_reasons(declarations)
    reasons = Symbol[]
    for d in declarations
        d isa VNextT0LocalAbsentDeclarationV1 || continue
        push!(reasons, d.reason)
        push!(reasons, d.layer === :G3 ? :g3_feedback_material_absent :
            Symbol(lowercase(String(d.layer)), "_material_absent"))
    end
    Tuple(unique(reasons))
end

function _vnext_ar_v2_validate_child(c, candidate, index)
    c.kind == VNEXT_AR_LOCAL_CHILD_KINDS_V2[index] || return (:child_order_mismatch,)
    c.candidate_ref == candidate || return (:child_candidate_mismatch,)
    if c isa VNextT0LocalChildPresentV1
        c.source_bytes.sha256 == _vnext_ar_v2_sha(c.source_bytes.bytes) || return (:child_source_hash_mismatch,)
        c.body_hash == canonical_hash(c.body) || return (:child_body_hash_mismatch,)
        return ()
    end
    c isa VNextT0LocalChildAbsentV1 || return (:child_type_invalid,)
    c.status in (:typed_absent, :terminal_deferred) || return (:child_status_invalid,)
    c.candidate_identity_created == false || return (:absent_child_identity_created,)
    c.factory_receipt_hash == _vnext_ar_v2_sha(c.factory_receipt_bytes.bytes) ||
        return (:child_receipt_hash_mismatch,)
    ()
end

function _vnext_ar_v2_fail(carrier, hash, code)
    VNextAuthorityRecheckLocalV2Result(:fail_closed, :none, false, :contract_only,
        nothing, (code,), (code,), carrier, hash)
end

"""Recheck source, declaration, semantic, receipt, axis, candidate and bundle fields."""
function vnext_declaration_authority_recheck_local_v2(input::VNextAuthorityRecheckLocalV2Input)
    t = input.transport
    if t === nothing
        empty = VNextT1CanonicalBytesV2(UInt8[])
        return VNextAuthorityRecheckLocalV2Result(:terminal_deferred, :terminal_deferred,
            false, :contract_only, nothing, (), (:t0_transport_required,), empty, empty.sha256)
    end
    carrier = _vnext_ar_v2_carrier(t)
    hash = t.bundle_hash
    t.candidate_ref == input.candidate_ref || return _vnext_ar_v2_fail(carrier, hash, :candidate_mismatch)
    t.status == :valid || return _vnext_ar_v2_fail(carrier, hash, :transport_status_invalid)
    isempty(t.errors) || return _vnext_ar_v2_fail(carrier, hash, :transport_errors_present)
    Tuple(d.layer for d in t.declarations) == VNEXT_AR_LOCAL_LAYERS_V2 ||
        return _vnext_ar_v2_fail(carrier, hash, :declaration_layer_order_invalid)
    Tuple(c.kind for c in t.children) == VNEXT_AR_LOCAL_CHILD_KINDS_V2 ||
        return _vnext_ar_v2_fail(carrier, hash, :child_kind_order_invalid)
    expected_bundle = canonical_hash(_vnext_ar_v2_bundle_body(t))
    expected_bundle == t.bundle_hash || return _vnext_ar_v2_fail(carrier, hash, :bundle_hash_mismatch)
    for (i, d) in enumerate(t.declarations)
        errors = _vnext_ar_v2_validate_declaration(d, input.candidate_ref, i)
        isempty(errors) || return _vnext_ar_v2_fail(carrier, hash, first(errors))
    end
    for (i, c) in enumerate(t.children)
        errors = _vnext_ar_v2_validate_child(c, input.candidate_ref, i)
        isempty(errors) || return _vnext_ar_v2_fail(carrier, hash, first(errors))
    end
    seen = Set{String}()
    for f in t.feedback
        f isa VNextT0LocalFeedbackV1 || return _vnext_ar_v2_fail(carrier, hash, :feedback_type_invalid)
        f.candidate_ref == input.candidate_ref || return _vnext_ar_v2_fail(carrier, hash, :feedback_candidate_mismatch)
        f.body_hash == canonical_hash(f.body) || return _vnext_ar_v2_fail(carrier, hash, :feedback_hash_mismatch)
        f.target_id in seen && return _vnext_ar_v2_fail(carrier, hash, :duplicate_feedback)
        push!(seen, f.target_id)
    end
    absent = any(d -> d isa VNextT0LocalAbsentDeclarationV1, t.declarations)
    absence_reasons = _vnext_ar_v2_absence_reasons(t.declarations)
    g3_children_deferred = all(c -> c isa VNextT0LocalChildAbsentV1, t.children)
    absent && return VNextAuthorityRecheckLocalV2Result(:typed_absent, :terminal_deferred,
        false, :contract_only,
        VNextAuthorityRecheckLocalV2TypedAbsent(input.candidate_ref, hash,
            absence_reasons, g3_children_deferred), (), absence_reasons, carrier, hash)
    g3_absent = any(c -> c isa VNextT0LocalChildAbsentV1, t.children)
    output = VNextAuthorityRecheckLocalV2Checked(input.candidate_ref, hash,
        t.declarations, t.children, t.feedback, g3_absent)
    VNextAuthorityRecheckLocalV2Result(:local_checked_present, :resolved, false,
        :contract_only, output, (), (), carrier, hash)
end

export VNextAuthorityRecheckLocalV2Input,VNextAuthorityRecheckLocalV2Checked,
    VNextAuthorityRecheckLocalV2TypedAbsent,VNextAuthorityRecheckLocalV2Result,
    vnext_declaration_authority_recheck_local_v2
