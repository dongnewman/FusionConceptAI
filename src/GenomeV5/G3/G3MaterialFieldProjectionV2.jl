"""Candidate-bound G3 heat/material projection V2.

This additive slice is an evidence-bound, screen-only producer. It requires
separate source-power, evaluated heat-endpoint, and heat-to-region receipts.
It does not build a mesh/PDE, call a provider, solve, or establish physical
truth. Synthetic/local evidence remains screen-only.
"""

const G3_MFP_V2_SCHEMA_ID = "GenomeV5/G3/G3MaterialFieldProjectionV2"
const G3_MFP_V2_VERSION = "v2"
const G3_MFP_V2_CLAIM_CEILING = :screen_only
const G3_MFP_V2_SOURCE_RECORD_PREFIX = "fusionconceptai://GenomeV5/G3/source-record/"
const G3_MFP_V2_SI_BASIS = (:kg, :m, :s, :A, :K, :mol, :cd)
const G3_MFP_V2_W_UNIT = UnitSignature((1, 2, -3, 0, 0, 0, 0))
const G3_MFP_V2_W_PER_M_K_UNIT = UnitSignature((1, 1, -3, 0, -1, 0, 0))
const G3_MFP_V2_M3_UNIT = UnitSignature((0, 3, 0, 0, 0, 0, 0))
const G3_MFP_V2_M_INV3_UNIT = UnitSignature((0, -3, 0, 0, 0, 0, 0))
const G3_MFP_V2_W_PER_M3_UNIT = UnitSignature((1, -1, -3, 0, 0, 0, 0))

_g3mfp2_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    value = String(x)
    !isempty(value) && isvalid(value) || throw(ArgumentError("$field must be non-empty UTF-8"))
    value
end
_g3mfp2_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_g3mfp2_hash(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_g3mfp2_unit_matches(a, b) = a isa UnitSignature && b isa UnitSignature && a.exponents == b.exponents
_g3mfp2_rat(x, field) = begin
    x isa Bool && throw(ArgumentError("$field must be an exact rational"))
    (x isa Rational || x isa Integer) || throw(ArgumentError("$field must be an exact rational"))
    Rational{Int64}(x)
end
_g3mfp2_bytes(x, field) = begin
    x isa AbstractVector{UInt8} || throw(ArgumentError("$field must be Vector{UInt8}"))
    !isempty(x) || throw(ArgumentError("$field must not be empty"))
    Tuple(x)
end
_g3mfp2_bytes_sha(bytes::Tuple{Vararg{UInt8}}) = Digest256(bytes2hex(SHA.sha256(collect(bytes))))
_g3mfp2_unit_view(unit::UnitSignature) = (basis=G3_MFP_V2_SI_BASIS, exponents=unit.exponents)

function _g3mfp2_ref_body(x::QualifiedRefV1)
    (id=x.id, version=x.version)
end

function _g3mfp2_source_content(x)
    (candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_id=x.source_id,
     declaration_hash=x.declaration_hash, endpoint_id=x.endpoint_id,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     source_power_w=x.source_power_w, unit_id=x.unit_id,
     unit_basis=G3_MFP_V2_SI_BASIS, unit=x.unit,
     unit_scale_to_si=x.unit_scale_to_si, evidence_ref=x.evidence_ref,
     evidence_bytes=length(x.evidence_bytes), evidence_sha256=x.evidence_sha256,
     authority_ref=x.authority_ref, authority_scope=x.authority_scope)
end

struct G3MFPSourceOperatingPointV2
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_id::String
    declaration_hash::Digest256
    endpoint_id::String
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    source_power_w::Rational{Int64}
    unit_id::String
    unit::UnitSignature
    unit_scale_to_si::Rational{Int64}
    evidence_ref::QualifiedRefV1
    evidence_bytes::Tuple{Vararg{UInt8}}
    evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    record_hash::Digest256
    function G3MFPSourceOperatingPointV2(candidate_ref::Any, source_ref::Any,
            source_id::Any, declaration_hash::Any, endpoint_id::Any,
            operating_condition_ref::Any, operating_condition_hash::Any,
            source_power_w::Any, unit_id::Any, unit::Any, unit_scale_to_si::Any,
            evidence_ref::Any, evidence_bytes::Any, authority_ref::Any, authority_scope::Any)
        candidate = _g3mfp2_ref(candidate_ref, "candidate_ref")
        source = _g3mfp2_ref(source_ref, "source_ref")
        sid = _g3mfp2_text(source_id, "source_id")
        declaration = _g3mfp2_hash(declaration_hash, "declaration_hash")
        endpoint = _g3mfp2_text(endpoint_id, "endpoint_id")
        condition = _g3mfp2_ref(operating_condition_ref, "operating_condition_ref")
        condition_hash = _g3mfp2_hash(operating_condition_hash, "operating_condition_hash")
        power = _g3mfp2_rat(source_power_w, "source_power_w")
        power >= 0 || throw(ArgumentError("source_power_w must be non-negative"))
        uid = _g3mfp2_text(unit_id, "source power unit_id")
        unit isa UnitSignature || throw(ArgumentError("source power unit must be UnitSignature"))
        _g3mfp2_unit_matches(unit, G3_MFP_V2_W_UNIT) && uid == "W" ||
            throw(ArgumentError("source power must use SI W"))
        scale = _g3mfp2_rat(unit_scale_to_si, "unit_scale_to_si")
        scale == 1 // 1 || throw(ArgumentError("source power must already be SI W"))
        eref = _g3mfp2_ref(evidence_ref, "evidence_ref")
        bytes = _g3mfp2_bytes(evidence_bytes, "evidence_bytes")
        evidence_hash = _g3mfp2_bytes_sha(bytes)
        aref = _g3mfp2_ref(authority_ref, "authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_source_record, :synthetic_local) ||
            throw(ArgumentError("unsupported authority_scope"))
        draft = (candidate_ref=candidate, source_ref=source, source_id=sid,
            declaration_hash=declaration, endpoint_id=endpoint,
            operating_condition_ref=condition, operating_condition_hash=condition_hash,
            source_power_w=power, unit_id=uid, unit=unit,
            unit_scale_to_si=scale, evidence_ref=eref,
            evidence_bytes=length(bytes), evidence_sha256=evidence_hash,
            authority_ref=aref, authority_scope=scope)
        authority_hash = canonical_hash((domain="G3-MFP-V2-source-authority-binding", body=draft))
        body = merge(draft, (authority_binding_hash=authority_hash,))
        record_hash = canonical_hash((domain="G3-MFP-V2-source-operating-point", body=body))
        new(candidate, source, sid, declaration, endpoint, condition, condition_hash,
            power, uid, unit, scale, eref, bytes, evidence_hash, aref, scope,
            authority_hash, record_hash)
    end
end

function _g3mfp2_source_valid(x::G3MFPSourceOperatingPointV2)
    _g3mfp2_bytes_sha(x.evidence_bytes) == x.evidence_sha256 || return false
    _g3mfp2_unit_matches(x.unit, G3_MFP_V2_W_UNIT) && x.unit_id == "W" &&
        x.unit_scale_to_si == 1 // 1 && x.source_power_w >= 0 || return false
    content = _g3mfp2_source_content(x)
    authority = canonical_hash((domain="G3-MFP-V2-source-authority-binding", body=content))
    authority == x.authority_binding_hash || return false
    body = merge(content, (authority_binding_hash=authority,))
    canonical_hash((domain="G3-MFP-V2-source-operating-point", body=body)) == x.record_hash
end
semantic_view(x::G3MFPSourceOperatingPointV2) = merge(
    (schema_id=G3_MFP_V2_SCHEMA_ID * "/SourceOperatingPoint", version=G3_MFP_V2_VERSION),
    _g3mfp2_source_content(x), (authority_binding_hash=x.authority_binding_hash, record_hash=x.record_hash))

function _g3mfp2_heat_content(x)
    (candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_id=x.source_id,
     declaration_hash=x.declaration_hash, endpoint_id=x.endpoint_id,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     heat_power_w=x.heat_power_w, unit_id=x.unit_id, unit_basis=G3_MFP_V2_SI_BASIS,
     unit=x.unit, evidence_ref=x.evidence_ref, evidence_bytes=length(x.evidence_bytes),
     evidence_sha256=x.evidence_sha256, authority_ref=x.authority_ref,
     authority_scope=x.authority_scope)
end

struct G3MFPHeatEndpointWitnessV2
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_id::String
    declaration_hash::Digest256
    endpoint_id::String
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    heat_power_w::Rational{Int64}
    unit_id::String
    unit::UnitSignature
    evidence_ref::QualifiedRefV1
    evidence_bytes::Tuple{Vararg{UInt8}}
    evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    record_hash::Digest256
    function G3MFPHeatEndpointWitnessV2(candidate_ref::Any, source_ref::Any,
            source_id::Any, declaration_hash::Any, endpoint_id::Any,
            operating_condition_ref::Any, operating_condition_hash::Any,
            heat_power_w::Any, unit_id::Any, unit::Any, evidence_ref::Any,
            evidence_bytes::Any, authority_ref::Any, authority_scope::Any)
        candidate = _g3mfp2_ref(candidate_ref, "candidate_ref")
        source = _g3mfp2_ref(source_ref, "source_ref")
        sid = _g3mfp2_text(source_id, "source_id")
        declaration = _g3mfp2_hash(declaration_hash, "declaration_hash")
        endpoint = _g3mfp2_text(endpoint_id, "endpoint_id")
        condition = _g3mfp2_ref(operating_condition_ref, "operating_condition_ref")
        condition_hash = _g3mfp2_hash(operating_condition_hash, "operating_condition_hash")
        heat = _g3mfp2_rat(heat_power_w, "heat_power_w")
        heat >= 0 || throw(ArgumentError("heat_power_w must be non-negative"))
        uid = _g3mfp2_text(unit_id, "heat unit_id")
        unit isa UnitSignature || throw(ArgumentError("heat unit must be UnitSignature"))
        _g3mfp2_unit_matches(unit, G3_MFP_V2_W_UNIT) && uid == "W" ||
            throw(ArgumentError("heat endpoint must use SI W"))
        eref = _g3mfp2_ref(evidence_ref, "heat evidence_ref")
        bytes = _g3mfp2_bytes(evidence_bytes, "heat evidence_bytes")
        evidence_hash = _g3mfp2_bytes_sha(bytes)
        aref = _g3mfp2_ref(authority_ref, "heat authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_source_record, :synthetic_local) ||
            throw(ArgumentError("unsupported heat authority_scope"))
        draft = (candidate_ref=candidate, source_ref=source, source_id=sid,
            declaration_hash=declaration, endpoint_id=endpoint,
            operating_condition_ref=condition, operating_condition_hash=condition_hash,
            heat_power_w=heat, unit_id=uid, unit=unit,
            evidence_ref=eref, evidence_bytes=length(bytes), evidence_sha256=evidence_hash,
            authority_ref=aref, authority_scope=scope)
        authority_hash = canonical_hash((domain="G3-MFP-V2-heat-authority-binding", body=draft))
        body = merge(draft, (authority_binding_hash=authority_hash,))
        record_hash = canonical_hash((domain="G3-MFP-V2-heat-endpoint-witness", body=body))
        new(candidate, source, sid, declaration, endpoint, condition, condition_hash,
            heat, uid, unit, eref, bytes, evidence_hash, aref, scope,
            authority_hash, record_hash)
    end
end

function _g3mfp2_heat_valid(x::G3MFPHeatEndpointWitnessV2)
    _g3mfp2_bytes_sha(x.evidence_bytes) == x.evidence_sha256 || return false
    _g3mfp2_unit_matches(x.unit, G3_MFP_V2_W_UNIT) && x.unit_id == "W" && x.heat_power_w >= 0 || return false
    content = _g3mfp2_heat_content(x)
    authority = canonical_hash((domain="G3-MFP-V2-heat-authority-binding", body=content))
    authority == x.authority_binding_hash || return false
    body = merge(content, (authority_binding_hash=authority,))
    canonical_hash((domain="G3-MFP-V2-heat-endpoint-witness", body=body)) == x.record_hash
end
semantic_view(x::G3MFPHeatEndpointWitnessV2) = merge(
    (schema_id=G3_MFP_V2_SCHEMA_ID * "/HeatEndpointWitness", version=G3_MFP_V2_VERSION),
    _g3mfp2_heat_content(x), (authority_binding_hash=x.authority_binding_hash, record_hash=x.record_hash))

struct G3MFPRegionHeatAllocationV2
    region_id::String
    allocation_fraction::Rational{Int64}
    physical_volume_m3::Rational{Int64}
    profile_kind::Symbol
    function G3MFPRegionHeatAllocationV2(region_id::Any, allocation_fraction::Any,
            physical_volume_m3::Any, profile_kind::Any)
        region = _g3mfp2_text(region_id, "region_id")
        fraction = _g3mfp2_rat(allocation_fraction, "allocation_fraction")
        0 <= fraction <= 1 || throw(ArgumentError("allocation_fraction must be in [0,1]"))
        volume = _g3mfp2_rat(physical_volume_m3, "physical_volume_m3")
        volume > 0 || throw(ArgumentError("physical_volume_m3 must be positive"))
        profile = profile_kind isa Symbol ? profile_kind : Symbol(profile_kind)
        profile in (:uniform_within_region, :nonuniform, :unspecified) ||
            throw(ArgumentError("unsupported spatial profile kind"))
        new(region, fraction, volume, profile)
    end
end

function _g3mfp2_allocation_row_view(x::G3MFPRegionHeatAllocationV2)
    (region_id=x.region_id, allocation_fraction=x.allocation_fraction,
     physical_volume_m3=x.physical_volume_m3, volume_unit_id="m^3",
     volume_unit=_g3mfp2_unit_view(G3_MFP_V2_M3_UNIT), profile_kind=x.profile_kind)
end
semantic_view(x::G3MFPRegionHeatAllocationV2) = _g3mfp2_allocation_row_view(x)

function _g3mfp2_allocation_content(x)
    (candidate_ref=x.candidate_ref, source_ref=x.source_ref, source_id=x.source_id,
     declaration_hash=x.declaration_hash, source_operating_point_hash=x.source_operating_point_hash,
     heat_witness_hash=x.heat_witness_hash, heat_endpoint_id=x.heat_endpoint_id,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     g2_region_map_ref=x.g2_region_map_ref, g2_region_map_hash=x.g2_region_map_hash,
     physical_frame_ref=x.physical_frame_ref, physical_frame_hash=x.physical_frame_hash,
     jacobian_included=x.jacobian_included, region_support=x.region_support,
     evidence_ref=x.evidence_ref, evidence_bytes=length(x.evidence_bytes),
     evidence_sha256=x.evidence_sha256, authority_ref=x.authority_ref,
     authority_scope=x.authority_scope)
end

struct G3MFPHeatAllocationReceiptV2
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_id::String
    declaration_hash::Digest256
    source_operating_point_hash::Digest256
    heat_witness_hash::Digest256
    heat_endpoint_id::String
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    g2_region_map_ref::QualifiedRefV1
    g2_region_map_hash::Digest256
    physical_frame_ref::QualifiedRefV1
    physical_frame_hash::Digest256
    jacobian_included::Bool
    region_support::Tuple{Vararg{G3MFPRegionHeatAllocationV2}}
    evidence_ref::QualifiedRefV1
    evidence_bytes::Tuple{Vararg{UInt8}}
    evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    receipt_hash::Digest256
    function G3MFPHeatAllocationReceiptV2(candidate_ref::Any, source_ref::Any,
            source_id::Any, declaration_hash::Any, source_operating_point_hash::Any,
            heat_witness_hash::Any, heat_endpoint_id::Any, operating_condition_ref::Any,
            operating_condition_hash::Any, g2_region_map_ref::Any, g2_region_map_hash::Any,
            physical_frame_ref::Any, physical_frame_hash::Any,
            jacobian_included::Any, region_support::Any, evidence_ref::Any,
            evidence_bytes::Any, authority_ref::Any, authority_scope::Any)
        candidate = _g3mfp2_ref(candidate_ref, "candidate_ref")
        source = _g3mfp2_ref(source_ref, "source_ref")
        sid = _g3mfp2_text(source_id, "source_id")
        declaration = _g3mfp2_hash(declaration_hash, "declaration_hash")
        source_hash = _g3mfp2_hash(source_operating_point_hash, "source_operating_point_hash")
        heat_hash = _g3mfp2_hash(heat_witness_hash, "heat_witness_hash")
        endpoint = _g3mfp2_text(heat_endpoint_id, "heat_endpoint_id")
        condition = _g3mfp2_ref(operating_condition_ref, "operating_condition_ref")
        condition_hash = _g3mfp2_hash(operating_condition_hash, "operating_condition_hash")
        map_ref = _g3mfp2_ref(g2_region_map_ref, "g2_region_map_ref")
        map_hash = _g3mfp2_hash(g2_region_map_hash, "g2_region_map_hash")
        frame_ref = _g3mfp2_ref(physical_frame_ref, "physical_frame_ref")
        frame_hash = _g3mfp2_hash(physical_frame_hash, "physical_frame_hash")
        jacobian_included isa Bool || throw(ArgumentError("jacobian_included must be Bool"))
        rows = region_support isa Tuple ? region_support :
            throw(ArgumentError("region_support must be an immutable tuple"))
        all(x -> x isa G3MFPRegionHeatAllocationV2, rows) ||
            throw(ArgumentError("region_support must contain typed heat allocations"))
        !isempty(rows) || throw(ArgumentError("region_support must not be empty"))
        eref = _g3mfp2_ref(evidence_ref, "allocation evidence_ref")
        bytes = _g3mfp2_bytes(evidence_bytes, "allocation evidence_bytes")
        evidence_hash = _g3mfp2_bytes_sha(bytes)
        aref = _g3mfp2_ref(authority_ref, "allocation authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_source_record, :synthetic_local) ||
            throw(ArgumentError("unsupported allocation authority_scope"))
        draft = (candidate_ref=candidate, source_ref=source, source_id=sid,
            declaration_hash=declaration, source_operating_point_hash=source_hash,
            heat_witness_hash=heat_hash, heat_endpoint_id=endpoint,
            operating_condition_ref=condition, operating_condition_hash=condition_hash,
            g2_region_map_ref=map_ref, g2_region_map_hash=map_hash,
            physical_frame_ref=frame_ref, physical_frame_hash=frame_hash,
            jacobian_included=jacobian_included, region_support=Tuple(rows),
            evidence_ref=eref, evidence_bytes=length(bytes), evidence_sha256=evidence_hash,
            authority_ref=aref, authority_scope=scope)
        authority_hash = canonical_hash((domain="G3-MFP-V2-heat-allocation-authority", body=draft))
        body = merge(draft, (authority_binding_hash=authority_hash,))
        receipt_hash = canonical_hash((domain="G3-MFP-V2-heat-allocation", body=body))
        new(candidate, source, sid, declaration, source_hash, heat_hash, endpoint,
            condition, condition_hash, map_ref, map_hash, frame_ref, frame_hash, jacobian_included,
            Tuple(rows), eref, bytes, evidence_hash, aref, scope, authority_hash, receipt_hash)
    end
end

function _g3mfp2_allocation_valid(x::G3MFPHeatAllocationReceiptV2)
    _g3mfp2_bytes_sha(x.evidence_bytes) == x.evidence_sha256 || return false
    length(Set(r.region_id for r in x.region_support)) == length(x.region_support) || return false
    all(r -> 0 <= r.allocation_fraction <= 1 && r.physical_volume_m3 > 0, x.region_support) || return false
    content = _g3mfp2_allocation_content(x)
    authority = canonical_hash((domain="G3-MFP-V2-heat-allocation-authority", body=content))
    authority == x.authority_binding_hash || return false
    body = merge(content, (authority_binding_hash=authority,))
    canonical_hash((domain="G3-MFP-V2-heat-allocation", body=body)) == x.receipt_hash
end
semantic_view(x::G3MFPHeatAllocationReceiptV2) = merge(
    (schema_id=G3_MFP_V2_SCHEMA_ID * "/HeatAllocation", version=G3_MFP_V2_VERSION),
    _g3mfp2_allocation_content(x),
    (authority_binding_hash=x.authority_binding_hash, receipt_hash=x.receipt_hash))

function _g3mfp2_tensor(value::Any, material_law::Symbol)
    if material_law === :isotropic_scalar
        scalar = _g3mfp2_rat(value, "isotropic conductivity")
        scalar > 0 || throw(ArgumentError("isotropic conductivity must be positive"))
        return (scalar, 0 // 1, 0 // 1, 0 // 1, scalar, 0 // 1, 0 // 1, 0 // 1, scalar)
    elseif material_law === :symmetric_positive_definite_tensor
        value isa Tuple && length(value) == 9 ||
            throw(ArgumentError("conductivity tensor must be a row-major 9-tuple"))
        return Tuple(_g3mfp2_rat(v, "conductivity tensor entry") for v in value)
    end
    throw(ArgumentError("material_law must explicitly declare isotropic_scalar or symmetric_positive_definite_tensor"))
end

function _g3mfp2_tensor_spd(t::NTuple{9,Rational{Int64}})
    a, b, c, d, e, f, g, h, i = t
    b == d && c == g && f == h || return false
    minor1 = a
    minor2 = a * e - b * b
    determinant = a * (e * i - f * f) - b * (b * i - f * c) + c * (b * f - e * c)
    minor1 > 0 && minor2 > 0 && determinant > 0
end

function _g3mfp2_conductivity_content(x)
    (candidate_ref=x.candidate_ref, region_id=x.region_id, component_id=x.component_id,
     material_id=x.material_id, material_law=x.material_law,
     conductivity_tensor_w_m_k=x.conductivity_tensor_w_m_k,
     conductivity_domain_lower=x.conductivity_domain_lower,
     conductivity_domain_upper=x.conductivity_domain_upper,
     g2_region_map_ref=x.g2_region_map_ref, g2_region_map_hash=x.g2_region_map_hash,
     physical_frame_ref=x.physical_frame_ref, physical_frame_hash=x.physical_frame_hash,
     unit_id=x.unit_id, unit_basis=G3_MFP_V2_SI_BASIS, unit=x.unit,
     unit_scale_to_si=x.unit_scale_to_si,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     source_ref=x.source_ref, evidence_ref=x.evidence_ref,
     evidence_bytes=length(x.evidence_bytes), evidence_sha256=x.evidence_sha256,
     authority_ref=x.authority_ref, authority_scope=x.authority_scope)
end

struct G3MFPConductivityTensorSelectionV2
    candidate_ref::QualifiedRefV1
    region_id::String
    component_id::String
    material_id::String
    material_law::Symbol
    conductivity_tensor_w_m_k::NTuple{9,Rational{Int64}}
    conductivity_domain_lower::Union{Rational{Int64},NTuple{9,Rational{Int64}}}
    conductivity_domain_upper::Union{Rational{Int64},NTuple{9,Rational{Int64}}}
    g2_region_map_ref::QualifiedRefV1
    g2_region_map_hash::Digest256
    physical_frame_ref::QualifiedRefV1
    physical_frame_hash::Digest256
    unit_id::String
    unit::UnitSignature
    unit_scale_to_si::Rational{Int64}
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    source_ref::QualifiedRefV1
    evidence_ref::QualifiedRefV1
    evidence_bytes::Tuple{Vararg{UInt8}}
    evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    selection_hash::Digest256
    function G3MFPConductivityTensorSelectionV2(candidate_ref::Any, region_id::Any,
            component_id::Any, material_id::Any, conductivity_value::Any,
            material_law::Any, domain_lower::Any, domain_upper::Any,
            g2_region_map_ref::Any, g2_region_map_hash::Any,
            physical_frame_ref::Any, physical_frame_hash::Any,
            unit_id::Any, unit::Any, unit_scale_to_si::Any,
            operating_condition_ref::Any, operating_condition_hash::Any,
            source_ref::Any, evidence_ref::Any, evidence_bytes::Any,
            authority_ref::Any, authority_scope::Any)
        candidate = _g3mfp2_ref(candidate_ref, "candidate_ref")
        region = _g3mfp2_text(region_id, "region_id")
        component = _g3mfp2_text(component_id, "component_id")
        material = _g3mfp2_text(material_id, "material_id")
        law = material_law isa Symbol ? material_law : Symbol(material_law)
        tensor = _g3mfp2_tensor(conductivity_value, law)
        _g3mfp2_tensor_spd(tensor) || throw(ArgumentError("conductivity tensor must be symmetric positive definite"))
        if law === :isotropic_scalar
            tensor[1] == tensor[5] == tensor[9] &&
                all(tensor[i] == 0 // 1 for i in (2, 3, 4, 6, 7, 8)) ||
                throw(ArgumentError("isotropic_scalar tensor must equal k*I"))
        end
        if law === :isotropic_scalar
            lower = _g3mfp2_rat(domain_lower, "isotropic conductivity domain lower")
            upper = _g3mfp2_rat(domain_upper, "isotropic conductivity domain upper")
            0 < lower <= tensor[1] <= upper ||
                throw(ArgumentError("selected isotropic conductivity must lie in its positive declared domain"))
        elseif law === :symmetric_positive_definite_tensor
            domain_lower isa Tuple && length(domain_lower) == 9 ||
                throw(ArgumentError("tensor domain lower bound must be a row-major 9-tuple"))
            domain_upper isa Tuple && length(domain_upper) == 9 ||
                throw(ArgumentError("tensor domain upper bound must be a row-major 9-tuple"))
            lower = Tuple(_g3mfp2_rat(v, "conductivity tensor domain lower") for v in domain_lower)
            upper = Tuple(_g3mfp2_rat(v, "conductivity tensor domain upper") for v in domain_upper)
            all(lower[i] <= tensor[i] <= upper[i] for i in 1:9) ||
                throw(ArgumentError("selected conductivity tensor must lie in its declared domain"))
            lower[2] == lower[4] && lower[3] == lower[7] && lower[6] == lower[8] &&
                upper[2] == upper[4] && upper[3] == upper[7] && upper[6] == upper[8] ||
                throw(ArgumentError("tensor domain bounds must preserve matrix symmetry"))
        end
        map_ref = _g3mfp2_ref(g2_region_map_ref, "g2_region_map_ref")
        map_hash = _g3mfp2_hash(g2_region_map_hash, "g2_region_map_hash")
        frame_ref = _g3mfp2_ref(physical_frame_ref, "physical_frame_ref")
        frame_hash = _g3mfp2_hash(physical_frame_hash, "physical_frame_hash")
        uid = _g3mfp2_text(unit_id, "conductivity unit_id")
        unit isa UnitSignature || throw(ArgumentError("conductivity unit must be UnitSignature"))
        _g3mfp2_unit_matches(unit, G3_MFP_V2_W_PER_M_K_UNIT) && uid == "W/(m*K)" ||
            throw(ArgumentError("conductivity tensor must use SI W/(m*K)"))
        scale = _g3mfp2_rat(unit_scale_to_si, "conductivity unit_scale_to_si")
        scale == 1 // 1 || throw(ArgumentError("conductivity tensor must already be SI"))
        condition = _g3mfp2_ref(operating_condition_ref, "operating_condition_ref")
        condition_hash = _g3mfp2_hash(operating_condition_hash, "operating_condition_hash")
        source = _g3mfp2_ref(source_ref, "material source_ref")
        eref = _g3mfp2_ref(evidence_ref, "material evidence_ref")
        bytes = _g3mfp2_bytes(evidence_bytes, "material evidence_bytes")
        evidence_hash = _g3mfp2_bytes_sha(bytes)
        aref = _g3mfp2_ref(authority_ref, "material authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_source_record, :synthetic_local) ||
            throw(ArgumentError("unsupported material authority_scope"))
        draft = (candidate_ref=candidate, region_id=region, component_id=component,
            material_id=material, material_law=law, conductivity_tensor_w_m_k=tensor,
            conductivity_domain_lower=lower, conductivity_domain_upper=upper,
            g2_region_map_ref=map_ref, g2_region_map_hash=map_hash,
            physical_frame_ref=frame_ref, physical_frame_hash=frame_hash,
            unit_id=uid, unit=unit, unit_scale_to_si=scale,
            operating_condition_ref=condition, operating_condition_hash=condition_hash,
            source_ref=source, evidence_ref=eref, evidence_bytes=length(bytes),
            evidence_sha256=evidence_hash, authority_ref=aref, authority_scope=scope)
        authority_hash = canonical_hash((domain="G3-MFP-V2-material-authority-binding", body=draft))
        body = merge(draft, (authority_binding_hash=authority_hash,))
        selection_hash = canonical_hash((domain="G3-MFP-V2-conductivity-tensor-selection", body=body))
        new(candidate, region, component, material, law, tensor, lower, upper, map_ref, map_hash,
            frame_ref, frame_hash, uid, unit, scale,
            condition, condition_hash, source, eref, bytes, evidence_hash, aref,
            scope, authority_hash, selection_hash)
    end
end

function _g3mfp2_conductivity_valid(x::G3MFPConductivityTensorSelectionV2)
    _g3mfp2_bytes_sha(x.evidence_bytes) == x.evidence_sha256 || return false
    _g3mfp2_unit_matches(x.unit, G3_MFP_V2_W_PER_M_K_UNIT) &&
        x.unit_id == "W/(m*K)" && x.unit_scale_to_si == 1 // 1 || return false
    _g3mfp2_tensor_spd(x.conductivity_tensor_w_m_k) || return false
    if x.material_law === :isotropic_scalar
        t = x.conductivity_tensor_w_m_k
        t[1] == t[5] == t[9] && all(t[i] == 0 // 1 for i in (2, 3, 4, 6, 7, 8)) || return false
        x.conductivity_domain_lower isa Rational{Int64} &&
            x.conductivity_domain_upper isa Rational{Int64} &&
            0 < x.conductivity_domain_lower <= t[1] <= x.conductivity_domain_upper || return false
    elseif x.material_law !== :symmetric_positive_definite_tensor
        return false
    else
        lower = x.conductivity_domain_lower
        upper = x.conductivity_domain_upper
        lower isa NTuple{9,Rational{Int64}} && upper isa NTuple{9,Rational{Int64}} || return false
        all(lower[i] <= x.conductivity_tensor_w_m_k[i] <= upper[i] for i in 1:9) || return false
        lower[2] == lower[4] && lower[3] == lower[7] && lower[6] == lower[8] &&
            upper[2] == upper[4] && upper[3] == upper[7] && upper[6] == upper[8] || return false
    end
    content = _g3mfp2_conductivity_content(x)
    authority = canonical_hash((domain="G3-MFP-V2-material-authority-binding", body=content))
    authority == x.authority_binding_hash || return false
    body = merge(content, (authority_binding_hash=authority,))
    canonical_hash((domain="G3-MFP-V2-conductivity-tensor-selection", body=body)) == x.selection_hash
end
semantic_view(x::G3MFPConductivityTensorSelectionV2) = merge(
    (schema_id=G3_MFP_V2_SCHEMA_ID * "/ConductivityTensorSelection", version=G3_MFP_V2_VERSION),
    _g3mfp2_conductivity_content(x),
    (authority_binding_hash=x.authority_binding_hash, selection_hash=x.selection_hash))

struct G3MFPProjectedRegionV2
    region_id::String
    component_id::String
    material_id::String
    material_law::Symbol
    conductivity_tensor_w_m_k::NTuple{9,Rational{Int64}}
    physical_frame_ref::QualifiedRefV1
    physical_frame_hash::Digest256
    allocation_fraction::Rational{Int64}
    normalized_source_weight_m_inv3::Rational{Int64}
    volumetric_source_w_m3::Rational{Int64}
    physical_volume_m3::Rational{Int64}
end

function _g3mfp2_projected_region_view(x::G3MFPProjectedRegionV2)
    (region_id=x.region_id, component_id=x.component_id, material_id=x.material_id,
     material_law=x.material_law, conductivity_tensor_w_m_k=x.conductivity_tensor_w_m_k,
     physical_frame_ref=x.physical_frame_ref, physical_frame_hash=x.physical_frame_hash,
     conductivity_unit_id="W/(m*K)", conductivity_unit=_g3mfp2_unit_view(G3_MFP_V2_W_PER_M_K_UNIT),
     allocation_fraction=x.allocation_fraction,
     normalized_source_weight_m_inv3=x.normalized_source_weight_m_inv3,
     source_weight_unit_id="m^-3", source_weight_unit=_g3mfp2_unit_view(G3_MFP_V2_M_INV3_UNIT),
     volumetric_source_w_m3=x.volumetric_source_w_m3,
     volumetric_source_unit_id="W/m^3", volumetric_source_unit=_g3mfp2_unit_view(G3_MFP_V2_W_PER_M3_UNIT),
     physical_volume_m3=x.physical_volume_m3,
     volume_unit_id="m^3", volume_unit=_g3mfp2_unit_view(G3_MFP_V2_M3_UNIT))
end

struct G3MFPProjectionReceiptV2
    candidate_ref::Union{Nothing,QualifiedRefV1}
    declaration_hash::Union{Nothing,Digest256}
    source_operating_point_hash::Union{Nothing,Digest256}
    heat_endpoint_witness_hash::Union{Nothing,Digest256}
    heat_allocation_hash::Union{Nothing,Digest256}
    conductivity_selection_hashes::Tuple{Vararg{Digest256}}
    operating_condition_ref::Union{Nothing,QualifiedRefV1}
    operating_condition_hash::Union{Nothing,Digest256}
    input_provenance::Symbol
    source_power_w::Union{Nothing,Rational{Int64}}
    field_power_w::Union{Nothing,Rational{Int64}}
    return_power_w::Union{Nothing,Rational{Int64}}
    heat_power_w::Union{Nothing,Rational{Int64}}
    energy_residual_w::Union{Nothing,Rational{Int64}}
    ledger_residual_w::Union{Nothing,Rational{Int64}}
    regions::Tuple{Vararg{G3MFPProjectedRegionV2}}
    normalized_support_integral::Union{Nothing,Rational{Int64}}
    integrated_heat_power_w::Union{Nothing,Rational{Int64}}
    status::Symbol
    resolution::Symbol
    accepted::Bool
    claim_ceiling::Symbol
    physical_status::Symbol
    formal_up2_credit::Bool
    formal_r_credit::Bool
    discovery_credit::Bool
    engineering_credit::Bool
    compiler_calls::Int
    provider_calls::Int
    mesh_calls::Int
    solver_calls::Int
    errors::Tuple{Vararg{String}}
    gaps::Tuple{Vararg{String}}
    receipt_hash::Digest256
end

function _g3mfp2_receipt_content(x::G3MFPProjectionReceiptV2)
    (schema_id=G3_MFP_V2_SCHEMA_ID, version=G3_MFP_V2_VERSION,
     candidate_ref=x.candidate_ref, declaration_hash=x.declaration_hash,
     source_operating_point_hash=x.source_operating_point_hash,
     heat_endpoint_witness_hash=x.heat_endpoint_witness_hash,
     heat_allocation_hash=x.heat_allocation_hash,
     conductivity_selection_hashes=x.conductivity_selection_hashes,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     input_provenance=x.input_provenance, source_power_w=x.source_power_w,
     field_power_w=x.field_power_w, return_power_w=x.return_power_w,
     heat_power_w=x.heat_power_w, energy_residual_w=x.energy_residual_w,
     ledger_residual_w=x.ledger_residual_w,
     regions=Tuple(_g3mfp2_projected_region_view(r) for r in x.regions),
     normalized_support_integral=x.normalized_support_integral,
     integrated_heat_power_w=x.integrated_heat_power_w,
     status=x.status, resolution=x.resolution, accepted=x.accepted,
     claim_ceiling=x.claim_ceiling, physical_status=x.physical_status,
     formal_up2_credit=x.formal_up2_credit, formal_r_credit=x.formal_r_credit,
     discovery_credit=x.discovery_credit, engineering_credit=x.engineering_credit,
     compiler_calls=x.compiler_calls, provider_calls=x.provider_calls,
     mesh_calls=x.mesh_calls, solver_calls=x.solver_calls,
     errors=x.errors, gaps=x.gaps)
end

function _g3mfp2_receipt(candidate_ref, declaration_hash; source_hash=nothing,
        heat_hash=nothing, allocation_hash=nothing, selection_hashes=(),
        condition_ref=nothing, condition_hash=nothing, input_provenance=:unknown,
        source_power=nothing, field_power=nothing, return_power=nothing,
        heat_power=nothing, energy_residual=nothing, ledger_residual=nothing,
        regions=(), normalized_support_integral=nothing, integrated_heat=nothing,
        status=:terminal_deferred, resolution=:terminal_deferred, errors=(), gaps=())
    body = (schema_id=G3_MFP_V2_SCHEMA_ID, version=G3_MFP_V2_VERSION,
        candidate_ref=candidate_ref, declaration_hash=declaration_hash,
        source_operating_point_hash=source_hash, heat_endpoint_witness_hash=heat_hash,
        heat_allocation_hash=allocation_hash, conductivity_selection_hashes=Tuple(selection_hashes),
        operating_condition_ref=condition_ref, operating_condition_hash=condition_hash,
        input_provenance=input_provenance, source_power_w=source_power,
        field_power_w=field_power, return_power_w=return_power,
        heat_power_w=heat_power, energy_residual_w=energy_residual,
        ledger_residual_w=ledger_residual,
        regions=Tuple(_g3mfp2_projected_region_view(r) for r in regions),
        normalized_support_integral=normalized_support_integral,
        integrated_heat_power_w=integrated_heat, status=status,
        resolution=resolution, accepted=false, claim_ceiling=G3_MFP_V2_CLAIM_CEILING,
        physical_status=:unknown, formal_up2_credit=false, formal_r_credit=false,
        discovery_credit=false, engineering_credit=false, compiler_calls=0,
        provider_calls=0, mesh_calls=0, solver_calls=0,
        errors=Tuple(String.(errors)), gaps=Tuple(String.(gaps)))
    hash = canonical_hash(body)
    G3MFPProjectionReceiptV2(candidate_ref, declaration_hash, source_hash, heat_hash,
        allocation_hash, Tuple(selection_hashes), condition_ref, condition_hash,
        input_provenance, source_power, field_power, return_power, heat_power,
        energy_residual, ledger_residual, Tuple(regions), normalized_support_integral,
        integrated_heat, status, resolution, false, G3_MFP_V2_CLAIM_CEILING,
        :unknown, false, false, false, false, 0, 0, 0, 0,
        Tuple(String.(errors)), Tuple(String.(gaps)), hash)
end

semantic_view(x::G3MFPProjectionReceiptV2) =
    merge(_g3mfp2_receipt_content(x), (receipt_hash=x.receipt_hash,))

"""Evaluate G3SF and project only its witnessed heat endpoint into G2 regions.

Missing authority, operating point, independent heat witness, heat allocation,
Jacobian evidence, spatial profile law, or a unique per-region material record
returns `terminal_deferred`. Contradictory typed evidence fails closed.
"""
function g3_mfp_project_v2(declaration::Any, source_point::Any=nothing;
        heat_endpoint_witness::Any=nothing, heat_allocation::Any=nothing,
        conductivity_selections::Any=())
    if !(declaration isa G3SFDeclarationV1)
        declaration === nothing && return _g3mfp2_receipt(nothing, nothing;
            gaps=("g3_source_declaration_missing",))
        return _g3mfp2_receipt(nothing, nothing; status=:fail_closed,
            resolution=:fail_closed, errors=("g3_source_declaration_type_invalid",))
    end
    candidate = declaration.candidate_ref
    declaration_hash = declaration.declaration_hash
    validity, declaration_errors = g3_sf_validate_v1(declaration)
    validity === :valid || return _g3mfp2_receipt(candidate, declaration_hash;
        status=:fail_closed, resolution=:fail_closed,
        errors=Tuple("g3_declaration:" * String(e) for e in declaration_errors))

    source_point === nothing && return _g3mfp2_receipt(candidate, declaration_hash;
        gaps=("candidate_source_bound_operating_point_missing",))
    source_point isa G3MFPSourceOperatingPointV2 || return _g3mfp2_receipt(candidate, declaration_hash;
        status=:fail_closed, resolution=:fail_closed, errors=("source_operating_point_type_invalid",))
    source = source_point::G3MFPSourceOperatingPointV2
    _g3mfp2_source_valid(source) || return _g3mfp2_receipt(candidate, declaration_hash;
        source_hash=source.record_hash, status=:fail_closed, resolution=:fail_closed,
        errors=("source_operating_point_hash_or_evidence_mismatch",))

    source_ref_expected = QualifiedRefV1(G3_MFP_V2_SOURCE_RECORD_PREFIX * declaration.source_id, "v1")
    source.candidate_ref == candidate || return _g3mfp2_receipt(candidate, declaration_hash;
        source_hash=source.record_hash, status=:fail_closed, resolution=:fail_closed,
        errors=("source_operating_point_candidate_mismatch",))
    source.source_ref == source_ref_expected && source.source_id == declaration.source_id ||
        return _g3mfp2_receipt(candidate, declaration_hash; source_hash=source.record_hash,
            status=:fail_closed, resolution=:fail_closed, errors=("source_operating_point_source_mismatch",))
    source.declaration_hash == declaration_hash && source.endpoint_id == declaration.law.source_endpoint_id ||
        return _g3mfp2_receipt(candidate, declaration_hash; source_hash=source.record_hash,
            status=:fail_closed, resolution=:fail_closed, errors=("source_operating_point_declaration_endpoint_mismatch",))
    source_endpoint = only(filter(e -> e.endpoint_id == declaration.law.source_endpoint_id, declaration.endpoints))
    _g3mfp2_unit_matches(source_endpoint.unit, G3_MFP_V2_W_UNIT) && source_endpoint.sign == 1 &&
        source_endpoint.direction in (:out, :bidirectional) ||
        return _g3mfp2_receipt(candidate, declaration_hash; source_hash=source.record_hash,
            status=:fail_closed, resolution=:fail_closed, errors=("source_endpoint_not_SI_outgoing_W",))

    evaluation = try
        g3_sf_evaluate_v1(declaration, source.source_power_w)
    catch
        return _g3mfp2_receipt(candidate, declaration_hash; source_hash=source.record_hash,
            condition_ref=source.operating_condition_ref, condition_hash=source.operating_condition_hash,
            input_provenance=source.authority_scope, status=:fail_closed,
            resolution=:fail_closed, errors=("g3_sf_evaluator_rejected_bound_operating_point",))
    end
    eval_kwargs = (; source_hash=source.record_hash,
        condition_ref=source.operating_condition_ref,
        condition_hash=source.operating_condition_hash,
        source_power=evaluation.source_power, field_power=evaluation.field_power,
        return_power=evaluation.return_power, heat_power=evaluation.heat_power,
        energy_residual=evaluation.energy_residual, ledger_residual=evaluation.ledger_residual)

    heat_endpoint_witness === nothing && return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., gaps=("independent_candidate_bound_heat_endpoint_witness_missing",))
    heat_endpoint_witness isa G3MFPHeatEndpointWitnessV2 || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., status=:fail_closed, resolution=:fail_closed,
        errors=("heat_endpoint_witness_type_invalid",))
    heat_witness = heat_endpoint_witness::G3MFPHeatEndpointWitnessV2
    _g3mfp2_heat_valid(heat_witness) || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("heat_endpoint_witness_hash_or_evidence_mismatch",))
    heat_endpoint = only(filter(e -> e.endpoint_id == declaration.law.heat_endpoint_id, declaration.endpoints))
    heat_binding_ok = heat_witness.candidate_ref == candidate &&
        heat_witness.source_ref == source.source_ref && heat_witness.source_id == declaration.source_id &&
        heat_witness.declaration_hash == declaration_hash &&
        heat_witness.endpoint_id == declaration.law.heat_endpoint_id &&
        heat_witness.operating_condition_ref == source.operating_condition_ref &&
        heat_witness.operating_condition_hash == source.operating_condition_hash &&
        _g3mfp2_unit_matches(heat_endpoint.unit, G3_MFP_V2_W_UNIT) &&
        heat_endpoint.role === :heat && heat_endpoint.direction === :out && heat_endpoint.sign == -1
    heat_binding_ok || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("heat_endpoint_identity_or_semantics_mismatch",))
    heat_witness.heat_power_w == evaluation.heat_power || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("heat_endpoint_witness_disagrees_with_evaluated_ledger",))
    evaluation.energy_residual == 0 && evaluation.ledger_residual == 0 ||
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, status=:fail_closed,
            resolution=:fail_closed, errors=("g3_sf_energy_or_ledger_residual_nonzero",))

    heat_allocation === nothing && return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        gaps=("candidate_bound_heat_to_region_allocation_missing",))
    heat_allocation isa G3MFPHeatAllocationReceiptV2 || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        status=:fail_closed, resolution=:fail_closed,
        errors=("heat_allocation_receipt_type_invalid",))
    allocation = heat_allocation::G3MFPHeatAllocationReceiptV2
    _g3mfp2_allocation_valid(allocation) || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("heat_allocation_hash_or_evidence_mismatch",))
    allocation_binding_ok = allocation.candidate_ref == candidate &&
        allocation.source_ref == source.source_ref && allocation.source_id == declaration.source_id &&
        allocation.declaration_hash == declaration_hash &&
        allocation.source_operating_point_hash == source.record_hash &&
        allocation.heat_witness_hash == heat_witness.record_hash &&
        allocation.heat_endpoint_id == declaration.law.heat_endpoint_id &&
        allocation.operating_condition_ref == source.operating_condition_ref &&
        allocation.operating_condition_hash == source.operating_condition_hash
    allocation_binding_ok || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("heat_allocation_candidate_source_condition_mismatch",))
    !allocation.jacobian_included && return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash,
        gaps=("physical_measure_jacobian_missing",))
    any(r -> r.profile_kind !== :uniform_within_region, allocation.region_support) &&
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
            gaps=("uniform_within_region_spatial_law_missing_or_unsupported",))
    sum(r.allocation_fraction for r in allocation.region_support; init=0 // 1) == 1 ||
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
            status=:fail_closed, resolution=:fail_closed,
            errors=("heat_region_allocation_fractions_not_conservative",))

    conductivity_selections isa Tuple || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("conductivity_selections_must_be_tuple",))
    isempty(conductivity_selections) && return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash,
        gaps=("region_conductivity_selections_missing",))
    all(x -> x isa G3MFPConductivityTensorSelectionV2, conductivity_selections) ||
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
            status=:fail_closed, resolution=:fail_closed,
            errors=("conductivity_tensor_selection_type_invalid",))
    selections = conductivity_selections::Tuple{Vararg{G3MFPConductivityTensorSelectionV2}}
    all(_g3mfp2_conductivity_valid, selections) || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash, status=:fail_closed,
        resolution=:fail_closed, errors=("conductivity_tensor_hash_unit_or_SPD_invalid",))
    allocation_region_ids = Tuple(x.region_id for x in allocation.region_support)
    selection_region_ids = Tuple(x.region_id for x in selections)
    length(Set(selection_region_ids)) == length(selection_region_ids) ||
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
            status=:fail_closed, resolution=:fail_closed,
            errors=("duplicate_region_conductivity_selection",))
    all(id -> id in allocation_region_ids, selection_region_ids) ||
        return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
            heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
            status=:fail_closed, resolution=:fail_closed,
            errors=("conductivity_selection_for_unmapped_region",))
    for selection in selections
        selection.candidate_ref == candidate || return _g3mfp2_receipt(candidate, declaration_hash;
            eval_kwargs..., heat_hash=heat_witness.record_hash,
            allocation_hash=allocation.receipt_hash, status=:fail_closed,
            resolution=:fail_closed, errors=("conductivity_candidate_mismatch:" * selection.region_id,))
        selection.g2_region_map_ref == allocation.g2_region_map_ref &&
            selection.g2_region_map_hash == allocation.g2_region_map_hash ||
            return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
                heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
                status=:fail_closed, resolution=:fail_closed,
                errors=("conductivity_region_map_mismatch:" * selection.region_id,))
        selection.physical_frame_ref == allocation.physical_frame_ref &&
            selection.physical_frame_hash == allocation.physical_frame_hash ||
            return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
                heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
                status=:fail_closed, resolution=:fail_closed,
                errors=("conductivity_physical_frame_mismatch:" * selection.region_id,))
        selection.operating_condition_ref == source.operating_condition_ref &&
            selection.operating_condition_hash == source.operating_condition_hash ||
            return _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
                heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
                status=:fail_closed, resolution=:fail_closed,
                errors=("conductivity_operating_condition_mismatch:" * selection.region_id,))
    end
    missing_regions = Tuple(id for id in allocation_region_ids if !(id in selection_region_ids))
    isempty(missing_regions) || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash,
        allocation_hash=allocation.receipt_hash,
        selection_hashes=Tuple(x.selection_hash for x in selections),
        gaps=Tuple("region_conductivity_selection_missing:" * id for id in missing_regions))

    selection_map = Dict(x.region_id => x for x in selections)
    projected = Tuple(begin
        selection = selection_map[row.region_id]
        weight = row.allocation_fraction / row.physical_volume_m3
        G3MFPProjectedRegionV2(row.region_id, selection.component_id, selection.material_id,
            selection.material_law, selection.conductivity_tensor_w_m_k,
            selection.physical_frame_ref, selection.physical_frame_hash, row.allocation_fraction,
            weight, evaluation.heat_power * weight, row.physical_volume_m3)
    end for row in allocation.region_support)
    normalized_integral = sum(r.normalized_source_weight_m_inv3 * r.physical_volume_m3
        for r in projected; init=0 // 1)
    integrated_heat = sum(r.volumetric_source_w_m3 * r.physical_volume_m3
        for r in projected; init=0 // 1)
    normalized_integral == 1 // 1 || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
        selection_hashes=Tuple(x.selection_hash for x in selections), regions=projected,
        normalized_support_integral=normalized_integral, integrated_heat=integrated_heat,
        status=:fail_closed, resolution=:fail_closed,
        errors=("normalized_heat_support_integral_not_one",))
    integrated_heat == heat_witness.heat_power_w || return _g3mfp2_receipt(candidate, declaration_hash;
        eval_kwargs..., heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
        selection_hashes=Tuple(x.selection_hash for x in selections), regions=projected,
        normalized_support_integral=normalized_integral, integrated_heat=integrated_heat,
        status=:fail_closed, resolution=:fail_closed,
        errors=("integrated_source_disagrees_with_evaluated_heat_endpoint",))
    has_synthetic_provenance = source.authority_scope === :synthetic_local ||
        heat_witness.authority_scope === :synthetic_local ||
        allocation.authority_scope === :synthetic_local ||
        any(x -> x.authority_scope === :synthetic_local, selections)
    provenance = has_synthetic_provenance ? :synthetic_local : :agent_local_source_record
    _g3mfp2_receipt(candidate, declaration_hash; eval_kwargs...,
        heat_hash=heat_witness.record_hash, allocation_hash=allocation.receipt_hash,
        selection_hashes=Tuple(x.selection_hash for x in selections),
        input_provenance=provenance, regions=projected,
        normalized_support_integral=normalized_integral, integrated_heat=integrated_heat,
        status=:evaluated_screen_only, resolution=:screen_only)
end
