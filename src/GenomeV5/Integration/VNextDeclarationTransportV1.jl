"""AD-30 T0 additive transport for the three V1 declarations.

This file is intentionally standalone.  It is not included by the legacy
FusionConceptAI module entry and it does not construct CandidateStatePackageV5,
alter a registry, invoke a compiler/provider/mesh/solver, or provide physical
evidence.  A caller may include it after the three V1 declaration files.

The transport preserves complete declaration bodies and stored source/declaration
identity.  Missing candidate mappings, axis provenance, G3 source content, and
G3 realization/control/binding children are typed gaps.  Contradictions are
returned as fail_closed admission results.
"""

const VNEXT_T0_SCHEMA_ID = "GenomeV5/Integration/VNextDeclarationTransportV1"
const VNEXT_T0_SCHEMA_VERSION = "v1"
const VNEXT_T0_REQUIRED_AXES =
    (:payload_schema_version, :canonicalization_profile_version,
     :applicability_profile_version, :evidence_receipt_version)
const VNEXT_T0_G3_CHILD_KINDS = (:realization, :control, :binding)
const VNEXT_T0_AXIS_IDENTITY_SCHEMA_ID = "GenomeV5/Integration/VNextAxisIdentityV1"
const VNEXT_T0_AXIS_IDENTITY_SCHEMA_VERSION = "v1"
const VNEXT_T0_G2_MAPPING_FIELD_PATH = "source.candidate_ref"

_vnext_t0_text(x, field) = begin
    value = String(x)
    !isempty(value) && isvalid(value) || throw(ArgumentError("$field must be non-empty UTF-8"))
    value
end
_vnext_t0_digest(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_vnext_t0_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_vnext_t0_axis_value(x, field) =
    x isa String || x isa Digest256 ? x : throw(ArgumentError("$field must be String or Digest256"))

"""Canonical identity recipe for a source-bound four-axis receipt."""
function vnext_axis_identity_hash_v1(candidate_ref::Any, layer::Any, axis::Any,
                                     value::Any, source_uri::Any, source_path::Any,
                                     source_record_hash::Any, attestation::Any)
    c = _vnext_t0_ref(candidate_ref, "axis identity candidate_ref")
    l = layer isa Symbol ? layer : Symbol(layer)
    l in (:G1, :G2, :G3) || throw(ArgumentError("axis identity layer must be G1, G2, or G3"))
    a = axis isa Symbol ? axis : Symbol(axis)
    a in VNEXT_T0_REQUIRED_AXES || throw(ArgumentError("axis identity axis is not in the frozen set"))
    v = _vnext_t0_axis_value(value, "axis identity value")
    uri = _vnext_t0_text(source_uri, "axis identity source_uri")
    path = _vnext_t0_text(source_path, "axis identity source_path")
    record_hash = _vnext_t0_digest(source_record_hash, "axis identity source_record_hash")
    astatus = attestation isa Symbol ? attestation : Symbol(attestation)
    astatus in (:unattested, :trusted_receipt) || throw(ArgumentError("invalid axis identity attestation"))
    canonical_hash((schema_id=VNEXT_T0_AXIS_IDENTITY_SCHEMA_ID,
        schema_version=VNEXT_T0_AXIS_IDENTITY_SCHEMA_VERSION, candidate_ref=c,
        layer=l, axis=a, value=v, source_uri=uri, source_path=path,
        source_record_hash=record_hash, attestation=astatus))
end

struct VNextTypedAbsenceV1
    kind::Symbol
    status::Symbol
    reason::String
    function VNextTypedAbsenceV1(kind::Any, reason::Any)
        k = kind isa Symbol ? kind : Symbol(kind)
        r = _vnext_t0_text(reason, "typed absence reason")
        new(k, :terminal_deferred, r)
    end
end
semantic_view(x::VNextTypedAbsenceV1) = (kind=x.kind, status=x.status, reason=x.reason)
canonical_json(x::VNextTypedAbsenceV1) = canonical_json(semantic_view(x))

struct VNextAxisProvenanceV1
    axis::Symbol
    candidate_ref::Union{Nothing,QualifiedRefV1}
    status::Symbol
    value::Union{Nothing,String,Digest256}
    source_uri::Union{Nothing,String}
    source_path::Union{Nothing,String}
    provenance::Symbol
    source_record_hash::Union{Nothing,Digest256}
    identity_hash::Union{Nothing,Digest256}
    attestation::Symbol
    verification_status::Symbol
    reason::Union{Nothing,String}
    function VNextAxisProvenanceV1(axis::Any, value::Any, source_uri::Any,
                                   source_path::Any;
                                   status=:present, provenance=:source_bound,
                                   candidate_ref=nothing,
                                   source_record_hash=nothing, identity_hash=nothing,
                                   attestation=:unattested,
                                   verification_status=nothing,
                                   reason=nothing)
        a = axis isa Symbol ? axis : Symbol(axis)
        a in VNEXT_T0_REQUIRED_AXES || throw(ArgumentError("unknown T0 axis"))
        s = status isa Symbol ? status : Symbol(status)
        s in (:present, :typed_absent) || throw(ArgumentError("invalid T0 axis status"))
        p = provenance isa Symbol ? provenance : Symbol(provenance)
        p in (:source_bound, :synthetic_oracle) || throw(ArgumentError("invalid T0 axis provenance"))
        astatus = attestation isa Symbol ? attestation : Symbol(attestation)
        astatus in (:unattested, :trusted_receipt) || throw(ArgumentError("invalid T0 axis attestation"))
        verification = verification_status === nothing ?
            (s === :typed_absent ? :not_applicable : :external_verification_pending) :
            (verification_status isa Symbol ? verification_status : Symbol(verification_status))
        verification in (:not_applicable, :external_verification_pending) ||
            throw(ArgumentError("invalid T0 axis verification status"))
        if s === :present
            v = _vnext_t0_axis_value(value, "axis value")
            uri = _vnext_t0_text(source_uri, "axis source_uri")
            path = _vnext_t0_text(source_path, "axis source_path")
            cref = candidate_ref === nothing ? nothing : _vnext_t0_ref(candidate_ref, "axis candidate_ref")
            record_hash = source_record_hash === nothing ? nothing : _vnext_t0_digest(source_record_hash, "axis source_record_hash")
            identity = identity_hash === nothing ? nothing : _vnext_t0_digest(identity_hash, "axis identity_hash")
            p === :source_bound && (cref === nothing || record_hash === nothing || identity === nothing) &&
                throw(ArgumentError("source_bound axis requires candidate_ref, source_record_hash, and identity_hash"))
            p === :source_bound && verification !== :external_verification_pending &&
                throw(ArgumentError("source_bound axis requires external_verification_pending"))
            why = reason === nothing ? nothing : _vnext_t0_text(reason, "axis reason")
            new(a, cref, s, v, uri, path, p, record_hash, identity, astatus, verification, why)
        else
            value === nothing || throw(ArgumentError("typed absent axis must have no value"))
            source_uri === nothing || throw(ArgumentError("typed absent axis must have no source_uri"))
            source_path === nothing || throw(ArgumentError("typed absent axis must have no source_path"))
            why = reason === nothing ? nothing : _vnext_t0_text(reason, "axis reason")
            why === nothing && throw(ArgumentError("typed absent axis requires a reason"))
            verification === :not_applicable ||
                throw(ArgumentError("typed absent axis must be not_applicable"))
            new(a, nothing, s, nothing, nothing, nothing, p, nothing, nothing, astatus, verification, why)
        end
    end
end
semantic_view(x::VNextAxisProvenanceV1) =
    (axis=x.axis, candidate_ref=x.candidate_ref, status=x.status, value=x.value, source_uri=x.source_uri,
     source_path=x.source_path, provenance=x.provenance, source_record_hash=x.source_record_hash,
     identity_hash=x.identity_hash, attestation=x.attestation,
     verification_status=x.verification_status, reason=x.reason)
canonical_json(x::VNextAxisProvenanceV1) = canonical_json(semantic_view(x))

struct VNextG2CandidateMappingReceiptV1
    source_ref::QualifiedRefV1
    source_version::String
    source_candidate_ref::GenomeContractRef
    candidate_ref::QualifiedRefV1
    source_record_hash::Digest256
    source_hash::Digest256
    evidence_ref::Digest256
    field_path::String
    attestation::Symbol
    verification_status::Symbol
    function VNextG2CandidateMappingReceiptV1(source::G2MBSourceV1, candidate_ref::Any,
                                              evidence_ref::Any, field_path::Any;
                                              source_record_hash=canonical_hash(_vnext_t0_g2_source_body(source)),
                                              source_hash=source.source_hash,
                                              attestation=:unattested,
                                              verification_status=:external_verification_pending)
        c = _vnext_t0_ref(candidate_ref, "G2 mapping candidate_ref")
        evidence = _vnext_t0_digest(evidence_ref, "G2 mapping evidence_ref")
        path = _vnext_t0_text(field_path, "G2 mapping field_path")
        body_hash = _vnext_t0_digest(source_record_hash, "G2 mapping source_record_hash")
        sh = _vnext_t0_digest(source_hash, "G2 mapping source_hash")
        a = attestation isa Symbol ? attestation : Symbol(attestation)
        a in (:unattested, :trusted_receipt) || throw(ArgumentError("invalid G2 mapping attestation"))
        verification_status === :external_verification_pending ||
            throw(ArgumentError("G2 mapping requires external_verification_pending"))
        new(source.source_ref, source.source_version, source.candidate_ref, c,
            body_hash, sh, evidence, path, a, :external_verification_pending)
    end
end
semantic_view(x::VNextG2CandidateMappingReceiptV1) =
    (source_ref=x.source_ref, source_version=x.source_version,
     source_candidate_ref=x.source_candidate_ref, candidate_ref=x.candidate_ref,
     source_record_hash=x.source_record_hash, source_hash=x.source_hash,
     evidence_ref=x.evidence_ref, field_path=x.field_path, attestation=x.attestation,
     verification_status=x.verification_status)
canonical_json(x::VNextG2CandidateMappingReceiptV1) = canonical_json(semantic_view(x))

struct VNextG2CandidateEnvelopeV1
    candidate_ref::QualifiedRefV1
    source_candidate_ref::GenomeContractRef
    mapping_status::Symbol
    mapping_receipt::Union{Nothing,VNextG2CandidateMappingReceiptV1}
    reason::Union{Nothing,String}
    function VNextG2CandidateEnvelopeV1(candidate_ref::Any, source_candidate_ref::Any;
                                         mapping_status=:typed_absent,
                                         mapping_receipt=nothing,
                                         reason=nothing)
        c = _vnext_t0_ref(candidate_ref, "G2 envelope candidate_ref")
        source_candidate_ref isa GenomeContractRef ||
            throw(ArgumentError("G2 envelope source_candidate_ref must be GenomeContractRef"))
        s = mapping_status isa Symbol ? mapping_status : Symbol(mapping_status)
        s in (:mapped, :typed_absent) || throw(ArgumentError("invalid G2 mapping status"))
        if s === :mapped
            mapping_receipt isa VNextG2CandidateMappingReceiptV1 ||
                throw(ArgumentError("mapped G2 envelope requires typed mapping receipt"))
            why = reason === nothing ? nothing : _vnext_t0_text(reason, "G2 mapping reason")
            new(c, source_candidate_ref, s, mapping_receipt, why)
        else
            mapping_receipt === nothing || throw(ArgumentError("typed absent G2 mapping has no receipt"))
            why = reason === nothing ? nothing : _vnext_t0_text(reason, "G2 mapping reason")
            why === nothing && throw(ArgumentError("typed absent G2 mapping requires a reason"))
            new(c, source_candidate_ref, s, nothing, why)
        end
    end
end
semantic_view(x::VNextG2CandidateEnvelopeV1) =
    (candidate_ref=x.candidate_ref, source_candidate_ref=x.source_candidate_ref,
     mapping_status=x.mapping_status, mapping_receipt=x.mapping_receipt,
     reason=x.reason)
canonical_json(x::VNextG2CandidateEnvelopeV1) = canonical_json(semantic_view(x))

struct VNextG3ChildStateV1
    kind::Symbol
    status::Symbol
    gap::VNextTypedAbsenceV1
    function VNextG3ChildStateV1(kind::Any, gap::Any)
        k = kind isa Symbol ? kind : Symbol(kind)
        k in VNEXT_T0_G3_CHILD_KINDS || throw(ArgumentError("unknown G3 child kind"))
        gap isa VNextTypedAbsenceV1 || throw(ArgumentError("G3 child gap must be typed"))
        gap.kind == k || throw(ArgumentError("G3 child gap kind mismatch"))
        new(k, :typed_absent, gap)
    end
end
semantic_view(x::VNextG3ChildStateV1) = (kind=x.kind, status=x.status, gap=x.gap)
canonical_json(x::VNextG3ChildStateV1) = canonical_json(semantic_view(x))

"""Exact semantic body used by the current G1 declaration implementation."""
function _vnext_t0_g1_body(x::G1DiffusionDeclarationV1)
    (schema_id=G1_DIFFUSION_SCHEMA_ID_V1, schema_version=G1_DIFFUSION_SCHEMA_VERSION_V1,
     candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_version=x.source_version,
     source_payload=x.source_payload, source_hash=x.source_hash, u=x.u, K=x.K, f=x.f,
     operators=x.operators, closure_ref=x.closure_ref, applicability_ref=x.applicability_ref,
     applicability_domain=x.applicability_domain, ownership=x.ownership,
     negative_controls=x.negative_controls)
end

"""Exact source body used by the current G2 declaration implementation."""
function _vnext_t0_g2_source_body(x::G2MBSourceV1)
    body = (source_ref=x.source_ref, source_version=x.source_version, candidate_ref=x.candidate_ref,
     chart_map=x.chart_map, mesh=x.mesh, faces=x.faces, profile=x.profile,
     units=x.units, authority=x.authority)
    if x.region_interface !== nothing
        body = merge(body, (field_space=x.field_space,
            q1_interpretation=x.q1_interpretation,
            boundary_coverage=x.boundary_coverage,
            region_interface=x.region_interface,
            region_exterior_owners=x.region_exterior_owners))
    end
    body
end

function _vnext_t0_g2_body(x::G2MBDeclarationV1)
    (contract_ref=x.contract_ref, source=x.source, schema_hash=x.schema_hash,
     canonicalization_hash=x.canonicalization_hash, profile_hash=x.profile_hash)
end

"""Exact semantic body used by the current G3 declaration implementation."""
function _vnext_t0_g3_body(x::G3SFDeclarationV1)
    (schema_id=G3_SF_V1_SCHEMA_ID, version=G3_SF_V1_VERSION,
     candidate_ref=x.candidate_ref, source_id=x.source_id, owner_scope=x.owner_scope,
     endpoints=x.endpoints, law=x.law, ledger_entries=x.ledger_entries,
     ledger_closure=x.ledger_closure, feedback_targets=x.feedback_targets,
     upstream_authority=x.upstream_authority)
end

function _vnext_t0_axes(axes::Any, layer::Symbol)
    axes isa Tuple || throw(ArgumentError("$layer axes must be an immutable tuple"))
    length(axes) == length(VNEXT_T0_REQUIRED_AXES) ||
        throw(ArgumentError("$layer must provide exactly four axes"))
    all(x -> x isa VNextAxisProvenanceV1, axes) ||
        throw(ArgumentError("$layer axes must be typed"))
    names = Tuple(x.axis for x in axes)
    names == VNEXT_T0_REQUIRED_AXES ||
        throw(ArgumentError("$layer axes must use the frozen order and names"))
    axes
end

function _vnext_t0_children(children::Any)
    children isa Tuple && length(children) == 3 || throw(ArgumentError("G3 children must have three typed entries"))
    all(x -> x isa VNextG3ChildStateV1, children) || throw(ArgumentError("G3 children must be typed"))
    Tuple(x.kind for x in children) == VNEXT_T0_G3_CHILD_KINDS ||
        throw(ArgumentError("G3 children must be realization/control/binding in order"))
    children
end

function _vnext_t0_axis_checks(axis_sets, body_hashes, candidate_ref)
    errors = String[]
    gaps = String[]
    for (layer, axes) in zip((:G1, :G2, :G3), axis_sets)
        for axis in axes
            if axis.status === :typed_absent
                push!(gaps, "axis_gap:$(layer):$(axis.axis):terminal_deferred")
            elseif axis.provenance === :synthetic_oracle
                push!(gaps, "axis_synthetic_oracle:$(layer):$(axis.axis)")
            else
                axis.candidate_ref == candidate_ref ||
                    push!(errors, "axis_candidate_ref_mismatch:$(layer):$(axis.axis)")
                expected_hash = layer === :G1 ? body_hashes[1] : layer === :G2 ? body_hashes[2] : body_hashes[3]
                axis.source_record_hash == expected_hash ||
                    push!(errors, "axis_source_record_hash_mismatch:$(layer):$(axis.axis)")
                expected_identity = vnext_axis_identity_hash_v1(candidate_ref, layer, axis.axis,
                    axis.value, axis.source_uri, axis.source_path, axis.source_record_hash,
                    axis.attestation)
                axis.identity_hash == expected_identity ||
                    push!(errors, "axis_identity_hash_mismatch:$(layer):$(axis.axis)")
                axis.attestation === :trusted_receipt ||
                    push!(errors, "axis_unattested:$(layer):$(axis.axis)")
                axis.verification_status === :external_verification_pending ||
                    push!(errors, "axis_verification_status_invalid:$(layer):$(axis.axis)")
                push!(gaps, "axis_external_receipt_verification_pending:$(layer):$(axis.axis)")
            end
        end
    end
    for i in eachindex(VNEXT_T0_REQUIRED_AXES)
        values = [axes[i].value for axes in axis_sets if axes[i].status === :present]
        isempty(values) && continue
        all(value == values[1] for value in values) ||
            push!(errors, "axis_conflict:" * String(VNEXT_T0_REQUIRED_AXES[i]))
    end
    unique!(errors); unique!(gaps)
    errors, gaps
end

struct VNextDeclarationTransportV1
    candidate_ref::QualifiedRefV1
    g1::G1DiffusionDeclarationV1
    g2::G2MBDeclarationV1
    g3::G3SFDeclarationV1
    g2_candidate_envelope::VNextG2CandidateEnvelopeV1
    g1_axes::NTuple{4,VNextAxisProvenanceV1}
    g2_axes::NTuple{4,VNextAxisProvenanceV1}
    g3_axes::NTuple{4,VNextAxisProvenanceV1}
    g3_children::NTuple{3,VNextG3ChildStateV1}
    g1_body_hash::Digest256
    g2_body_hash::Digest256
    g3_body_hash::Digest256
    g1_source_hash::Digest256
    g2_source_hash::Digest256
    g3_source_content_hash::Union{Nothing,Digest256}
    bundle_hash::Digest256
    status::Symbol
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
end

semantic_view(x::VNextDeclarationTransportV1) =
    (schema_id=VNEXT_T0_SCHEMA_ID, schema_version=VNEXT_T0_SCHEMA_VERSION,
     candidate_ref=x.candidate_ref, g1=x.g1, g2=x.g2, g3=x.g3,
     g2_candidate_envelope=x.g2_candidate_envelope, g1_axes=x.g1_axes,
     g2_axes=x.g2_axes, g3_axes=x.g3_axes, g3_children=x.g3_children,
     g1_body_hash=x.g1_body_hash, g2_body_hash=x.g2_body_hash,
     g3_body_hash=x.g3_body_hash, g1_source_hash=x.g1_source_hash,
     g2_source_hash=x.g2_source_hash, g3_source_content_hash=x.g3_source_content_hash,
     bundle_hash=x.bundle_hash, status=x.status, errors=x.errors, gaps=x.gaps)
canonical_json(x::VNextDeclarationTransportV1) = canonical_json(semantic_view(x))

struct VNextTransportAdmissionV1
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    transport::Union{Nothing,VNextDeclarationTransportV1}
    bundle_hash::Union{Nothing,Digest256}
end
semantic_view(x::VNextTransportAdmissionV1) =
    (status=x.status, resolution=x.resolution, accepted=x.accepted,
     claim_ceiling=x.claim_ceiling, errors=x.errors, gaps=x.gaps,
     transport=x.transport, bundle_hash=x.bundle_hash)
canonical_json(x::VNextTransportAdmissionV1) = canonical_json(semantic_view(x))

function _vnext_t0_build_bundle(candidate_ref, g1, g2, g3, g2_envelope,
                                g1_axes, g2_axes, g3_axes, children,
                                g1_body_hash, g2_body_hash, g3_body_hash,
                                g1_source_hash, g2_source_hash, g3_source_content_hash,
                                status, errors, gaps)
    body = (schema_id=VNEXT_T0_SCHEMA_ID, schema_version=VNEXT_T0_SCHEMA_VERSION,
        candidate_ref=candidate_ref, g1=g1, g2=g2, g3=g3,
        g2_candidate_envelope=g2_envelope, g1_axes=g1_axes, g2_axes=g2_axes,
        g3_axes=g3_axes, g3_children=children, g1_body_hash=g1_body_hash,
        g2_body_hash=g2_body_hash, g3_body_hash=g3_body_hash,
        g1_source_hash=g1_source_hash, g2_source_hash=g2_source_hash,
        g3_source_content_hash=g3_source_content_hash,
        status=status, errors=errors, gaps=gaps)
    canonical_hash(body)
end

"""Build T0 and classify exact joins without entering the old V5 package."""
function vnext_declaration_transport_v1(g1::G1DiffusionDeclarationV1,
                                        g2::G2MBDeclarationV1,
                                        g3::G3SFDeclarationV1,
                                        candidate_ref::QualifiedRefV1,
                                        g2_envelope::VNextG2CandidateEnvelopeV1,
                                        g1_axes::Any, g2_axes::Any, g3_axes::Any,
                                        g3_children::Any)
    axes = (_vnext_t0_axes(g1_axes, :G1), _vnext_t0_axes(g2_axes, :G2),
            _vnext_t0_axes(g3_axes, :G3))
    children = _vnext_t0_children(g3_children)
    errors = String[]
    gaps = String[]
    candidate_ref.version == "v5" || push!(errors, "candidate_ref_version_mismatch")
    g1.candidate_ref == candidate_ref || push!(errors, "G1_candidate_binding_mismatch")
    g3.candidate_ref == candidate_ref || push!(errors, "G3_candidate_binding_mismatch")
    g2_envelope.candidate_ref == candidate_ref || push!(errors, "G2_envelope_candidate_binding_mismatch")
    g2_envelope.source_candidate_ref == g2.source.candidate_ref ||
        push!(errors, "G2_source_candidate_ref_envelope_mismatch")
    g2_envelope.mapping_status === :typed_absent &&
        push!(gaps, "G2_candidate_mapping:terminal_deferred")
    if g2_envelope.mapping_status === :mapped
        receipt = g2_envelope.mapping_receipt
        receipt.source_ref == g2.source.source_ref || push!(errors, "G2_mapping_source_ref_mismatch")
        receipt.source_version == g2.source.source_version || push!(errors, "G2_mapping_source_version_mismatch")
        receipt.source_candidate_ref == g2.source.candidate_ref || push!(errors, "G2_mapping_source_candidate_ref_mismatch")
        receipt.candidate_ref == candidate_ref || push!(errors, "G2_mapping_candidate_ref_mismatch")
        receipt.source_record_hash == canonical_hash(_vnext_t0_g2_source_body(g2.source)) ||
            push!(errors, "G2_mapping_source_record_hash_mismatch")
        receipt.source_hash == g2.source.source_hash || push!(errors, "G2_mapping_source_hash_mismatch")
        receipt.field_path == VNEXT_T0_G2_MAPPING_FIELD_PATH ||
            push!(errors, "G2_mapping_field_path_mismatch")
        receipt.attestation === :trusted_receipt || push!(errors, "G2_mapping_unattested")
        receipt.verification_status === :external_verification_pending ||
            push!(errors, "G2_mapping_verification_status_invalid")
        push!(gaps, "G2_mapping_external_receipt_verification_pending:terminal_deferred")
    end

    g1_body = _vnext_t0_g1_body(g1)
    g2_body = _vnext_t0_g2_body(g2)
    g3_body = _vnext_t0_g3_body(g3)
    g1_body_hash = canonical_hash(g1_body)
    g2_body_hash = canonical_hash(g2_body)
    g3_body_hash = canonical_hash(g3_body)
    g1_source_hash = g1_diffusion_source_hash_v1(g1.source_payload)
    g2_source_hash = g2.source.source_hash
    g1.declaration_hash == g1_body_hash || push!(errors, "G1_declaration_hash_mismatch")
    g2.declaration_hash == g2_body_hash || push!(errors, "G2_declaration_hash_mismatch")
    g3.declaration_hash == g3_body_hash || push!(errors, "G3_declaration_hash_mismatch")
    g1.source_hash == g1_source_hash || push!(errors, "G1_source_hash_mismatch")
    canonical_hash(_vnext_t0_g2_source_body(g2.source)) == g2_source_hash ||
        push!(errors, "G2_source_hash_mismatch")
    g3_source_content_hash = nothing
    push!(gaps, "G3_source_content_hash:typed_absent:terminal_deferred")
    axis_errors, axis_gaps = _vnext_t0_axis_checks(axes, (g1_body_hash, g2_body_hash, g3_body_hash), candidate_ref)
    append!(errors, axis_errors)
    append!(gaps, axis_gaps)
    append!(gaps, String("G3_child_" * String(child.kind) * ":typed_absent:terminal_deferred") for child in children)
    all(a.candidate_ref == candidate_ref for a in g3.upstream_authority) ||
        push!(errors, "G3_upstream_authority_candidate_mismatch")
    for authority in g3.upstream_authority
        if authority.status === :actual && authority.attestation !== :trusted_receipt
            push!(errors, "G3_upstream_unattested_authority:" * String(authority.layer))
        elseif authority.status === :contradictory
            push!(errors, "G3_upstream_contradictory_authority:" * String(authority.layer))
        elseif authority.status === :stale
            push!(errors, "G3_upstream_stale_authority:" * String(authority.layer))
        elseif authority.status === :actual
            push!(gaps, "G3_upstream_actual_authority_external_verification_pending:" * String(authority.layer))
        elseif authority.status === :missing
            push!(gaps, "G3_upstream_authority_missing:" * String(authority.layer) * ":terminal_deferred")
        end
    end
    for target in g3.feedback_targets
        target.authority.candidate_ref == candidate_ref ||
            push!(errors, "G3_feedback_authority_candidate_mismatch:" * target.target_id)
        target.authority.status === :actual && target.authority.attestation !== :trusted_receipt &&
            push!(errors, "G3_feedback_unattested_authority:" * target.target_id)
        target.authority.status === :contradictory &&
            push!(errors, "G3_feedback_contradictory_authority:" * target.target_id)
        target.authority.status === :stale &&
            push!(errors, "G3_feedback_stale_authority:" * target.target_id)
        target.authority.status === :missing &&
            push!(gaps, "G3_feedback_authority_missing:" * target.target_id * ":terminal_deferred")
    end
    unique!(errors); unique!(gaps)
    status = isempty(errors) ? :valid : :fail_closed
    resolution = isempty(errors) && isempty(gaps) ? :resolved : :terminal_deferred
    bundle_hash = _vnext_t0_build_bundle(candidate_ref, g1, g2, g3, g2_envelope,
        axes[1], axes[2], axes[3], children, g1_body_hash, g2_body_hash, g3_body_hash,
        g1_source_hash, g2_source_hash, g3_source_content_hash, status,
        Tuple(errors), Tuple(gaps))
    transport = VNextDeclarationTransportV1(candidate_ref, g1, g2, g3, g2_envelope,
        axes[1], axes[2], axes[3], children, g1_body_hash, g2_body_hash, g3_body_hash,
        g1_source_hash, g2_source_hash, g3_source_content_hash, bundle_hash,
        status, Tuple(errors), Tuple(gaps))
    VNextTransportAdmissionV1(status, resolution, false, :contract_only,
        Tuple(errors), Tuple(gaps), transport, bundle_hash)
end

vnext_transport_bundle_hash_v1(x::VNextDeclarationTransportV1) = x.bundle_hash
vnext_transport_body_hashes_v1(x::VNextDeclarationTransportV1) =
    (G1=x.g1_body_hash, G2=x.g2_body_hash, G3=x.g3_body_hash)
vnext_transport_source_hashes_v1(x::VNextDeclarationTransportV1) =
    (G1=x.g1_source_hash, G2=x.g2_source_hash, G3=x.g3_source_content_hash)
