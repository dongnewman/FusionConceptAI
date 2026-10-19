"""Formal local V2 T1 integration entry.

The caller supplies parent commitments and G3 authority commitments. The G3
expected commitment may be absent only when the checked G3 authority is
explicitly typed absent; a checked-present G3 authority still requires and
verifies an independent digest before constructing a package. The entry never
derives an expected commitment from the package.
"""

const VNEXT_T1_ADMISSION_SCHEMA_ID_V2 = "GenomeV5/Integration/VNextGenomeV5IntegrationV2"
const VNEXT_T1_ADMISSION_SCHEMA_VERSION_V2 = "v2"

struct VNextT1AdmissionInputV2
    candidate_ref::QualifiedRefV1
    transport::Union{Nothing,VNextT0LocalTransportV1}
    t0_recheck::Union{Nothing,VNextAuthorityRecheckLocalV2Result}
    parent_commitments::NTuple{2,Digest256}
    g3_expected_commitment::Union{Nothing,Digest256}
    g3_authority::Any
end

struct VNextT1AdmissionResultV2
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    package::Union{Nothing,CandidateStatePackageV5NextV2}
    errors::Tuple{Vararg{Symbol}}
    gaps::Tuple{Vararg{Symbol}}
    trace::Tuple
end

semantic_view(x::VNextT1AdmissionResultV2) =
    (schema=VNEXT_T1_ADMISSION_SCHEMA_ID_V2, version=VNEXT_T1_ADMISSION_SCHEMA_VERSION_V2,
        status=x.status, resolution=x.resolution, accepted=x.accepted,
        claim_ceiling=x.claim_ceiling, package=x.package, errors=x.errors,
        gaps=x.gaps, trace=x.trace)

function vnext_t1_parent_commitment_v2(candidate::QualifiedRefV1, d)
    canonical_hash((domain="vnext-t1-parent-authority-commitment-v2",
        candidate_ref=candidate, layer=d.layer, source_ref=d.source_ref,
        declaration_ref=d.declaration_ref, source_identity_hash=d.source_identity_hash,
        declaration_identity_hash=d.declaration_identity_hash, axes=d.axes))
end

function _vnext_t1_v2_reject(status, resolution, errors, gaps, trace=())
    VNextT1AdmissionResultV2(status, resolution, false, :contract_only, nothing,
        Tuple(errors), Tuple(gaps), Tuple(trace))
end

function _vnext_t1_v2_g3_check(input, recheck)
    a = input.g3_authority
    hasproperty(a, :status) || return :g3_authority_shape_invalid
    if a.status === :typed_absent
        return :g3_typed_absent
    end
    a.status === :local_checked_present && hasproperty(a, :authority_verified) &&
        a.authority_verified || return :g3_authority_not_verified

    # Shape guards must precede every nested authority dereference.  The
    # authority is caller-supplied and may be a malformed NamedTuple from a
    # reload or boundary adapter; such a value is a deterministic contract
    # rejection, never an exception from a missing field.
    hasproperty(a, :expected_commitment) || return :g3_expected_commitment_missing
    expected = a.expected_commitment
    hasproperty(expected, :commitment_hash) || return :g3_expected_commitment_hash_missing
    hasproperty(expected, :candidate_ref) || return :g3_expected_candidate_ref_missing
    hasproperty(expected, :bundle_hash) || return :g3_expected_bundle_hash_missing
    hasproperty(expected, :g3_declaration_ref) || return :g3_expected_declaration_ref_missing
    hasproperty(expected, :g3_declaration_identity_hash) ||
        return :g3_expected_declaration_hash_missing
    hasproperty(expected, :realization) || return :g3_expected_realization_missing
    hasproperty(expected, :control) || return :g3_expected_control_missing
    hasproperty(expected.realization, :state_hash) ||
        return :g3_expected_realization_state_hash_missing
    hasproperty(expected.control, :state_hash) ||
        return :g3_expected_control_state_hash_missing

    hasproperty(a, :binding_state) && a.binding_state !== nothing || return :g3_binding_state_missing
    state = a.binding_state
    hasproperty(state, :state_hash) || return :g3_state_hash_missing
    hasproperty(state, :editable_body) || return :g3_editable_body_missing
    editable = state.editable_body
    hasproperty(editable, :key) || return :g3_key_missing
    key = editable.key
    hasproperty(key, :candidate_ref) || return :g3_key_candidate_missing
    hasproperty(key, :parent_g3_declaration_ref) || return :g3_key_parent_ref_missing
    hasproperty(key, :parent_g3_declaration_hash) || return :g3_key_parent_hash_missing
    hasproperty(key, :child_kind) || return :g3_key_kind_missing
    hasproperty(state, :source_payload) || return :g3_source_payload_missing
    payload = state.source_payload
    hasproperty(payload, :realization_slot) || return :g3_realization_slot_missing
    hasproperty(payload, :control_slot) || return :g3_control_slot_missing
    realization_slot = payload.realization_slot
    control_slot = payload.control_slot
    hasproperty(realization_slot, :state_hash) || return :g3_realization_state_hash_missing
    hasproperty(control_slot, :state_hash) || return :g3_control_state_hash_missing
    realization_slot.state_hash isa Digest256 || return :g3_realization_state_hash_shape_invalid
    control_slot.state_hash isa Digest256 || return :g3_control_state_hash_shape_invalid
    key.candidate_ref == input.candidate_ref || return :g3_key_candidate_mismatch
    key.parent_g3_declaration_ref == expected.g3_declaration_ref ||
        return :g3_key_parent_ref_mismatch
    key.parent_g3_declaration_hash == expected.g3_declaration_identity_hash ||
        return :g3_key_parent_hash_mismatch
    key.child_kind === :binding || return :g3_key_kind_mismatch
    realization_slot.state_hash == expected.realization.state_hash ||
        return :g3_state_hash_mismatch
    control_slot.state_hash == expected.control.state_hash ||
        return :g3_state_hash_mismatch
    input.g3_expected_commitment isa Digest256 ||
        return :g3_expected_commitment_missing
    expected.commitment_hash == input.g3_expected_commitment ||
        return :g3_expected_commitment_stale
    expected.candidate_ref == input.candidate_ref || return :g3_expected_candidate_mismatch
    expected.bundle_hash == recheck.prior_bundle_sha256 || return :g3_expected_bundle_mismatch
    :ok
end

function _vnext_t1_v2_recheck_envelope_error(input, transport, recheck)
    recheck.accepted === false || return :t0_recheck_accepted_invalid
    recheck.claim_ceiling === :contract_only || return :t0_recheck_claim_ceiling_invalid
    if recheck.status === :local_checked_present
        recheck.resolution === :resolved || return :t0_recheck_resolution_invalid
        isempty(recheck.errors) || return :t0_recheck_errors_invalid
        isempty(recheck.reasons) || return :t0_recheck_reasons_invalid
        recheck.output isa VNextAuthorityRecheckLocalV2Checked ||
            return :t0_recheck_output_invalid
        all(d -> d isa VNextT0LocalPresentDeclarationV1, transport.declarations) ||
            return :t0_recheck_presence_mismatch
        output = recheck.output
        output.candidate_ref == input.candidate_ref || return :t0_recheck_output_candidate_mismatch
        output.bundle_hash == transport.bundle_hash || return :t0_recheck_output_bundle_mismatch
        _vnext_ar_v2_content_equal(output.declarations, transport.declarations) ||
            return :t0_recheck_output_declarations_mismatch
        _vnext_ar_v2_content_equal(output.children, transport.children) ||
            return :t0_recheck_output_children_mismatch
        _vnext_ar_v2_content_equal(output.feedback, transport.feedback) ||
            return :t0_recheck_output_feedback_mismatch
        output.g3_children_deferred == any(c -> c isa VNextT0LocalChildAbsentV1,
            transport.children) || return :t0_recheck_output_child_deferral_mismatch
        return nothing
    elseif recheck.status === :typed_absent
        recheck.resolution === :terminal_deferred || return :t0_recheck_resolution_invalid
        isempty(recheck.errors) || return :t0_recheck_errors_invalid
        isempty(recheck.reasons) && return :t0_recheck_reasons_invalid
        recheck.output isa VNextAuthorityRecheckLocalV2TypedAbsent ||
            return :t0_recheck_output_invalid
        any(d -> d isa VNextT0LocalAbsentDeclarationV1, transport.declarations) ||
            return :t0_recheck_absence_mismatch
        for (index, declaration) in enumerate(transport.declarations)
            declaration isa VNextT0LocalAbsentDeclarationV1 || continue
            errors = _vnext_ar_v2_validate_declaration(declaration,
                input.candidate_ref, index)
            isempty(errors) || return first(errors)
        end
        output = recheck.output
        output.candidate_ref == input.candidate_ref || return :t0_recheck_output_candidate_mismatch
        output.bundle_hash == transport.bundle_hash || return :t0_recheck_output_bundle_mismatch
        expected_reasons = _vnext_ar_v2_absence_reasons(transport.declarations)
        recheck.reasons == expected_reasons || return :t0_recheck_reasons_invalid
        output.reasons == expected_reasons || return :t0_recheck_output_reasons_mismatch
        output.g3_children_deferred == all(c -> c isa VNextT0LocalChildAbsentV1,
            transport.children) || return :t0_recheck_output_child_deferral_mismatch
        return nothing
    elseif recheck.status === :fail_closed
        recheck.resolution === :none || return :t0_recheck_resolution_invalid
        recheck.output === nothing || return :t0_recheck_output_invalid
        isempty(recheck.errors) && return :t0_recheck_errors_invalid
        recheck.reasons == recheck.errors || return :t0_recheck_reasons_invalid
        return nothing
    end
    :t0_recheck_status_invalid
end

"""Consume the complete T0 -> authority -> parent/G3 -> package chain."""
function vnext_t1_admit_v2(input::VNextT1AdmissionInputV2)
    input.candidate_ref.version == "v5" || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:candidate_version_invalid,), (), (:entry,))
    t = input.transport
    r = input.t0_recheck
    t === nothing && return _vnext_t1_v2_reject(:terminal_deferred, :terminal_deferred,
        (), (:t0_transport_required,), (:entry,))
    r === nothing && return _vnext_t1_v2_reject(:terminal_deferred, :terminal_deferred,
        (), (:t0_recheck_required,), (:entry,))
    r.prior_bundle_sha256 == t.bundle_hash || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:t0_bundle_recheck_mismatch,), (), (:entry, :recheck))
    expected_wire = _vnext_ar_v2_carrier(t)
    r.prior_bundle_bytes.sha256 == expected_wire.sha256 ||
        return _vnext_t1_v2_reject(:fail_closed, :none,
            (:t0_recheck_wire_hash_mismatch,), (), (:entry, :recheck))
    length(copy_bytes(r.prior_bundle_bytes)) == length(copy_bytes(expected_wire)) ||
        return _vnext_t1_v2_reject(:fail_closed, :none,
            (:t0_recheck_wire_length_mismatch,), (), (:entry, :recheck))
    copy_bytes(r.prior_bundle_bytes) == copy_bytes(expected_wire) ||
        return _vnext_t1_v2_reject(:fail_closed, :none,
            (:t0_recheck_wire_bytes_mismatch,), (), (:entry, :recheck))
    t.candidate_ref == input.candidate_ref || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:foreign_candidate,), (), (:entry, :recheck))
    t.status === :valid || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:t0_transport_status_invalid,), (), (:entry, :recheck))
    isempty(t.errors) || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:t0_transport_errors_present,), (), (:entry, :recheck))
    canonical_hash(_vnext_ar_v2_bundle_body(t)) == t.bundle_hash ||
        return _vnext_t1_v2_reject(:fail_closed, :none,
            (:t0_transport_bundle_invalid,), (), (:entry, :recheck))
    length(t.declarations) == 3 || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:declaration_arity,), (), (:entry,))
    envelope_error = _vnext_t1_v2_recheck_envelope_error(input, t, r)
    envelope_error === nothing || return _vnext_t1_v2_reject(:fail_closed, :none,
        (envelope_error,), (), (:entry, :recheck))
    if r.status === :fail_closed
        return _vnext_t1_v2_reject(:fail_closed, :none, r.errors, (),
            (:entry, :recheck, :upstream_fail_closed))
    elseif r.status === :typed_absent
        return _vnext_t1_v2_reject(:terminal_deferred, :terminal_deferred,
            (), (:t0_recheck_typed_absent,), (:entry, :recheck, :typed_absence))
    end
    # Commitments are supplied by the caller/producer and checked before the package exists.
    expected_parent = ntuple(i -> vnext_t1_parent_commitment_v2(input.candidate_ref,
        t.declarations[i]), 2)
    input.parent_commitments == expected_parent || return _vnext_t1_v2_reject(:fail_closed, :none,
        (:parent_commitment_mismatch,), (), (:entry, :parent_authority))
    g3check = _vnext_t1_v2_g3_check(input, r)
    if g3check === :g3_typed_absent
        return _vnext_t1_v2_reject(:terminal_deferred, :terminal_deferred,
            (), (:g3_typed_absent,), (:entry, :g3_authority))
    end
    g3check === :ok || return _vnext_t1_v2_reject(:fail_closed, :none, (g3check,), (),
        (:entry, :g3_authority))
    # `_vnext_t1_v2_g3_check` only returns :ok for a checked-present authority
    # with a supplied digest. Keep the package contract strictly non-optional.
    g3_expected_commitment = input.g3_expected_commitment::Digest256
    package = CandidateStatePackageV5NextV2(input.candidate_ref, t, r,
        input.parent_commitments, input.g3_authority, g3_expected_commitment)
    VNextT1AdmissionResultV2(:prepared_not_executed, :terminal_deferred, false,
        :contract_only, package, (), (:t1_runtime_unresolved,),
        (:t0_transport, :v2_recheck, :parent_authority, :g3_authority, :package))
end

export VNextT1AdmissionInputV2,VNextT1AdmissionResultV2,vnext_t1_parent_commitment_v2,
    vnext_t1_admit_v2
