"""Closed, static-only T1 admission boundary for the v5-next package.

This additive file is not included by ``FusionConceptAI.jl``. It consumes only
typed T0 objects already supplied by a caller. It performs no source I/O,
factory execution, Julia/DESC run, provider admission, or physical claim.
"""

const VNEXT_T1_ADMISSION_SCHEMA_ID_V1 =
    "GenomeV5/Integration/VNextGenomeV5Integration"
const VNEXT_T1_ADMISSION_SCHEMA_VERSION_V1 = "v1"

struct VNextT1AdmissionInputV1
    candidate_ref::QualifiedRefV1
    t0_recheck::Union{Nothing,VNextT1AdmissionRecheckInputV1}
    transport::Union{Nothing,VNextT0LocalTransportV1}
    no_legacy_receipt::Union{Nothing,VNextT1NoLegacyReceiptV1}
end
VNextT1AdmissionInputV1(candidate_ref::QualifiedRefV1,
        t0_recheck::Union{Nothing,VNextT1AdmissionRecheckInputV1},
        transport::Union{Nothing,VNextT0LocalTransportV1}) =
    VNextT1AdmissionInputV1(candidate_ref, t0_recheck, transport, nothing)

struct VNextT1AdmissionResultV1{P,C,E,G}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    package::P
    component_count_receipt::C
    no_legacy_receipt::Union{Nothing,VNextT1NoLegacyReceiptV1}
    errors::NTuple{E,Symbol}
    gaps::NTuple{G,Symbol}
end
semantic_view(x::VNextT1AdmissionResultV1) = (
    schema=VNEXT_T1_ADMISSION_SCHEMA_ID_V1,
    schema_version=VNEXT_T1_ADMISSION_SCHEMA_VERSION_V1,
    status=x.status, resolution=x.resolution, accepted=x.accepted,
    claim_ceiling=x.claim_ceiling, package=x.package,
    component_count_receipt=x.component_count_receipt,
    no_legacy_receipt=x.no_legacy_receipt, errors=x.errors, gaps=x.gaps)

function _vnext_t1_reject(status::Symbol, resolution::Symbol,
        errors::NTuple{E,Symbol}, gaps::NTuple{G,Symbol}) where {E,G}
    VNextT1AdmissionResultV1{Nothing,Nothing,E,G}(status, resolution, false,
        :contract_only, nothing, nothing, nothing, errors, gaps)
end
_vnext_t1_deferred(code::Symbol) =
    _vnext_t1_reject(:terminal_deferred, :terminal_deferred, (), (code,))
_vnext_t1_fail(code::Symbol) =
    _vnext_t1_reject(:fail_closed, :none, (code,), ())

function _vnext_t1_snapshot(input::VNextT1AdmissionInputV1)
    recheck = input.t0_recheck
    transport = input.transport
    recheck === nothing && throw(ArgumentError("T0 recheck required"))
    transport === nothing && throw(ArgumentError("T0 transport required"))
    recheck.status === :local_checked_present ||
        throw(ArgumentError("T0 status is not local_checked_present"))
    recheck.resolution === :resolved || throw(ArgumentError("T0 is not resolved"))
    recheck.accepted == false || throw(ArgumentError("T0 accepted=true"))
    recheck.claim_ceiling === :contract_only || throw(ArgumentError("T0 claim ceiling invalid"))
    isempty(recheck.errors) || throw(ArgumentError("T0 recheck errors present"))
    isempty(recheck.reasons) || throw(ArgumentError("T0 recheck reasons present"))
    transport.candidate_ref == input.candidate_ref ||
        throw(ArgumentError("transport candidate mismatch"))
    transport.status === :valid || throw(ArgumentError("transport is not valid"))
    isempty(transport.errors) || throw(ArgumentError("transport errors present"))
    transport.gaps in ((), (:g3_child_terminal_deferred,)) ||
        throw(ArgumentError("unknown or multiple T0 gaps"))
    Tuple(child.kind for child in transport.children) == VNEXT_T1_REQUIRED_CHILDREN_V1 ||
        throw(ArgumentError("T0 child kind/order mismatch"))
    has_absent_child = any(child -> child isa VNextT0LocalChildAbsentV1,
        transport.children)
    has_absent_child == (transport.gaps == (:g3_child_terminal_deferred,)) ||
        throw(ArgumentError("T0 child/gap semantic mismatch"))
    if transport.gaps == (:g3_child_terminal_deferred,)
        all(child -> child isa VNextT0LocalChildAbsentV1, transport.children) ||
            throw(ArgumentError("T0 child gap must be all typed absent"))
        all(child -> child.status in (:terminal_deferred, :typed_absent),
            transport.children) || throw(ArgumentError("T0 absent child status invalid"))
    else
        all(child -> child isa VNextT0LocalChildPresentV1, transport.children) ||
            throw(ArgumentError("T0 no-gap state must be all present"))
    end
    _vnext_t1_validate_feedback_order(transport.feedback)
    recomputed_bundle_hash = vnext_t0_local_bundle_hash_recompute_v1(transport)
    recomputed_bundle_hash == transport.bundle_hash ||
        throw(ArgumentError("transport bundle hash recomputation mismatch"))
    transport.bundle_hash == recheck.prior_bundle_sha256 ||
        throw(ArgumentError("recheck/transport bundle hash mismatch"))
    canonical_bytes = Tuple(Vector{UInt8}(codeunits(canonical_json(transport))))
    canonical_bytes == recheck.prior_bundle_bytes ||
        throw(ArgumentError("canonical prior bundle bytes mismatch"))
    prior = VNextT1PriorBundleSnapshotV1(
        VNextT1CanonicalBytesV1(canonical_bytes), transport.bundle_hash)
    prior
end

function _vnext_t1_declaration_tuple(
        transport::VNextT0LocalTransportV1, candidate::QualifiedRefV1)
    all(d -> d isa VNextT0LocalPresentDeclarationV1, transport.declarations) ||
        throw(ArgumentError("T1 requires all three present declarations"))
    records = ntuple(i -> _vnext_t1_declaration_record(
        transport.declarations[i]::VNextT0LocalPresentDeclarationV1, candidate), 3)
    Tuple(r.layer for r in records) == VNEXT_T1_REQUIRED_LAYERS_V1 ||
        throw(ArgumentError("declaration order mismatch"))
    records
end

function _vnext_t1_child_tuple(transport::VNextT0LocalTransportV1,
        candidate::QualifiedRefV1)
    length(transport.children) == 3 || throw(ArgumentError("child arity mismatch"))
    all(child -> child isa VNextT0LocalChildV1, transport.children) ||
        throw(ArgumentError("child type mismatch"))
    ntuple(i -> _vnext_t1_child_record(transport.children[i], candidate,
        VNEXT_T1_REQUIRED_CHILDREN_V1[i]), 3)
end

function _vnext_t1_feedback_tuple(items::NTuple{N,VNextT0LocalFeedbackV1},
        declarations::NTuple{3,VNextT0LocalPresentDeclarationV1},
        candidate::QualifiedRefV1) where {N}
    ntuple(i -> _vnext_t1_feedback_record(items[i], declarations, candidate), N)
end

function _vnext_t1_output_gate(input::VNextT1AdmissionInputV1,
        prior::VNextT1PriorBundleSnapshotV1{B},
        declarations::NTuple{3,VNextT1DeclarationRecordV1},
        children::NTuple{3,VNEXT_T1_CHILD_RECORD_TYPE_V1},
        feedback::NTuple{N,VNextT1FeedbackRecordV1}) where {B,N}
    recheck = input.t0_recheck
    transport = input.transport
    output = recheck.output
    output.candidate_ref == input.candidate_ref ||
        throw(ArgumentError("T0 output candidate mismatch"))
    output.bundle_hash == transport.bundle_hash ||
        throw(ArgumentError("T0 output bundle mismatch"))
    output.g1 == transport.declarations[1] || throw(ArgumentError("T0 output G1 mismatch"))
    output.g2 == transport.declarations[2] || throw(ArgumentError("T0 output G2 mismatch"))
    output.g3 == transport.declarations[3] || throw(ArgumentError("T0 output G3 mismatch"))
    output.children == transport.children || throw(ArgumentError("T0 output children mismatch"))
    output.feedback == transport.feedback || throw(ArgumentError("T0 output feedback mismatch"))
    output_projection = VNextT1T0OutputProjectionV1{N}(input.candidate_ref,
        transport.bundle_hash, declarations, children, feedback)
    output_bytes = VNextT1CanonicalBytesV1(
        Tuple(Vector{UInt8}(codeunits(canonical_json(output_projection)))))
    output_hash = canonical_hash(output_projection)
    child_hashes = ntuple(i -> children[i] isa VNextT1PresentChildRecordV1 ?
        children[i].child_identity_hash : children[i].factory_receipt_hash, 3)
    output_identity = VNextT1T0OutputIdentityV1{N}(input.candidate_ref,
        transport.bundle_hash, ntuple(i -> declarations[i].declaration_identity_hash, 3),
        child_hashes, ntuple(i -> canonical_hash(feedback[i]), N), output_hash)
    VNextT1T0GateV1(prior, input.candidate_ref, recheck.status,
        recheck.resolution, recheck.accepted, recheck.claim_ceiling,
        output_projection, output_bytes, output_identity, output_hash)
end

"""Admit an explicit T0 recheck into a prepared, terminal-deferred T1 package."""
function vnext_t1_admit_skeleton_v1(input::VNextT1AdmissionInputV1)
    input.candidate_ref.version == "v5" || return _vnext_t1_fail(:candidate_version_invalid)
    input.t0_recheck === nothing && return _vnext_t1_deferred(:t0_recheck_required)
    input.transport === nothing && return _vnext_t1_deferred(:t0_transport_required)
    input.t0_recheck.status === :local_checked_present ||
        return _vnext_t1_fail(:t0_recheck_gate_invalid)
    input.t0_recheck.resolution === :resolved ||
        return _vnext_t1_fail(:t0_recheck_gate_invalid)
    input.t0_recheck.accepted == false ||
        return _vnext_t1_fail(:t0_recheck_gate_invalid)
    input.t0_recheck.claim_ceiling === :contract_only ||
        return _vnext_t1_fail(:t0_recheck_gate_invalid)
    try
        prior = _vnext_t1_snapshot(input)
        declarations = _vnext_t1_declaration_tuple(input.transport,
            input.candidate_ref)
        children = _vnext_t1_child_tuple(input.transport, input.candidate_ref)
        raw_declarations = ntuple(i ->
            input.transport.declarations[i]::VNextT0LocalPresentDeclarationV1, 3)
        raw_feedback = input.transport.feedback
        _vnext_t1_validate_feedback_order(raw_feedback)
        typed_feedback = ntuple(i -> raw_feedback[i]::VNextT0LocalFeedbackV1,
            length(raw_feedback))
        feedback = _vnext_t1_feedback_tuple(typed_feedback, raw_declarations,
            input.candidate_ref)
        axes = ntuple(i -> declarations[i].axes, 3)
        source_hashes = ntuple(i -> declarations[i].source_bytes.sha256, 3)
        declaration_hashes = ntuple(i -> declarations[i].declaration_bytes.sha256, 3)
        no_legacy = input.no_legacy_receipt === nothing ?
            vnext_t1_no_legacy_receipt_v1(input.candidate_ref) :
            input.no_legacy_receipt
        _vnext_t1_validate_no_legacy_receipt(no_legacy, input.candidate_ref)
        gate = _vnext_t1_output_gate(input, prior, declarations, children, feedback)
        package = _vnext_t1_package(input.candidate_ref, declarations, children,
            axes, feedback, source_hashes, declaration_hashes, gate, no_legacy)
        VNextT1AdmissionResultV1{typeof(package),typeof(package.component_count_receipt),0,1}(
            :prepared_not_executed, :terminal_deferred, false, :contract_only,
            package, package.component_count_receipt, no_legacy, (),
            (:t1_runtime_unresolved,))
    catch
        _vnext_t1_fail(:t1_projection_invalid)
    end
end
