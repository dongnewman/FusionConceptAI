"""G3 source and material inputs for a bounded thermal-field projection.

This version only produces a candidate-bound, `screen_only` material/source
projection. It does not parse upstream measurements, construct a PDE, map a
mesh, compile, call a provider, or solve a thermal problem. A source producer
must establish the value-to-evidence relationship before constructing the
typed witness. Local hashes bind the supplied record and bytes; they are not
signatures or claims of physical authority.

The SI exponent order used here is explicitly `(kg, m, s, A, K, mol, cd)`.
"""

const G3_MFP_V1_SCHEMA_ID = "GenomeV5/G3/G3MaterialFieldProjectionV1"
const G3_MFP_V1_VERSION = "v1"
const G3_MFP_V1_CLAIM_CEILING = :screen_only
const G3_MFP_V1_SOURCE_RECORD_PREFIX = "fusionconceptai://GenomeV5/G3/source-record/"
const G3_MFP_V1_SI_BASIS = (:kg, :m, :s, :A, :K, :mol, :cd)
const G3_MFP_V1_W_UNIT = UnitSignature((1, 2, -3, 0, 0, 0, 0))
const G3_MFP_V1_W_PER_M_K_UNIT = UnitSignature((1, 1, -3, 0, -1, 0, 0))
const G3_MFP_V1_M3_UNIT = UnitSignature((0, 3, 0, 0, 0, 0, 0))
const G3_MFP_V1_M_INV3_UNIT = UnitSignature((0, -3, 0, 0, 0, 0, 0))
const G3_MFP_V1_W_PER_M3_UNIT = UnitSignature((1, -1, -3, 0, 0, 0, 0))

_g3mfp_text(x, field) = begin
    x isa AbstractString || throw(ArgumentError("$field must be a string"))
    value = String(x)
    !isempty(value) && isvalid(value) || throw(ArgumentError("$field must be non-empty UTF-8"))
    value
end
_g3mfp_ref(x, field) = x isa QualifiedRefV1 ? x : throw(ArgumentError("$field must be QualifiedRefV1"))
_g3mfp_hash(x, field) = x isa Digest256 ? x : throw(ArgumentError("$field must be Digest256"))
_g3mfp_unit_matches(a, b) = a isa UnitSignature && b isa UnitSignature && a.exponents == b.exponents
_g3mfp_rat(x, field) = begin
    x isa Bool && throw(ArgumentError("$field must be an exact rational"))
    (x isa Rational || x isa Integer) || throw(ArgumentError("$field must be an exact rational"))
    Rational{Int64}(x)
end
_g3mfp_positive_int(x, field) = begin
    x isa Bool && throw(ArgumentError("$field must be a positive integer"))
    x isa Integer && 0 < x <= typemax(Int) || throw(ArgumentError("$field must be a positive integer"))
    Int(x)
end
_g3mfp_bytes(x, field) = begin
    x isa AbstractVector{UInt8} || throw(ArgumentError("$field must be Vector{UInt8}"))
    !isempty(x) || throw(ArgumentError("$field must not be empty"))
    Tuple(x)
end
_g3mfp_bytes_sha(bytes::Tuple{Vararg{UInt8}}) = Digest256(bytes2hex(SHA.sha256(collect(bytes))))
_g3mfp_ref_view(ref::QualifiedRefV1) = (id=ref.id, version=ref.version)
_g3mfp_unit_view(unit::UnitSignature) = (basis=G3_MFP_V1_SI_BASIS, exponents=unit.exponents)

function _g3mfp_power_witness_content(x)
    (candidate_ref=x.candidate_ref,
     source_ref=x.source_ref,
     source_id=x.source_id,
     declaration_hash=x.declaration_hash,
     endpoint_id=x.endpoint_id,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     power_w=x.power_w,
     unit_id=x.unit_id,
     unit_basis=G3_MFP_V1_SI_BASIS,
     unit=x.unit,
     unit_scale_to_si=x.unit_scale_to_si,
     source_evidence_ref=x.source_evidence_ref,
     source_evidence_bytes=length(x.source_evidence_bytes),
     source_evidence_sha256=x.source_evidence_sha256,
     authority_ref=x.authority_ref,
     authority_scope=x.authority_scope)
end

_g3mfp_power_witness_body(x) = merge(
    (schema_id=G3_MFP_V1_SCHEMA_ID * "/OperatingPowerWitness", version=G3_MFP_V1_VERSION),
    _g3mfp_power_witness_content(x),
    (authority_binding_hash=x.authority_binding_hash,))

struct G3MFPOperatingPowerWitnessV1
    candidate_ref::QualifiedRefV1
    source_ref::QualifiedRefV1
    source_id::String
    declaration_hash::Digest256
    endpoint_id::String
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    power_w::Rational{Int64}
    unit_id::String
    unit::UnitSignature
    unit_scale_to_si::Rational{Int64}
    source_evidence_ref::QualifiedRefV1
    source_evidence_bytes::Tuple{Vararg{UInt8}}
    source_evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    witness_hash::Digest256
    function G3MFPOperatingPowerWitnessV1(candidate_ref::Any, source_ref::Any,
            source_id::Any, declaration_hash::Any, endpoint_id::Any,
            operating_condition_ref::Any, operating_condition_hash::Any,
            power_w::Any, unit_id::Any, unit::Any, unit_scale_to_si::Any,
            source_evidence_ref::Any, source_evidence_bytes::Any,
            authority_ref::Any, authority_scope::Any)
        c = _g3mfp_ref(candidate_ref, "candidate_ref")
        c.version == "v5" || throw(ArgumentError("candidate_ref must use v5"))
        src = _g3mfp_ref(source_ref, "source_ref")
        sid = _g3mfp_text(source_id, "source_id")
        dh = _g3mfp_hash(declaration_hash, "declaration_hash")
        endpoint = _g3mfp_text(endpoint_id, "endpoint_id")
        condition = _g3mfp_ref(operating_condition_ref, "operating_condition_ref")
        condition_hash = _g3mfp_hash(operating_condition_hash, "operating_condition_hash")
        p = _g3mfp_rat(power_w, "power_w")
        p >= 0 || throw(ArgumentError("power_w must be non-negative"))
        uid = _g3mfp_text(unit_id, "power unit_id")
        unit isa UnitSignature || throw(ArgumentError("power unit must be UnitSignature"))
        _g3mfp_unit_matches(unit, G3_MFP_V1_W_UNIT) ||
            throw(ArgumentError("operating power must have SI watt exponents in the declared basis"))
        uid == "W" || throw(ArgumentError("operating power unit_id must be W"))
        scale = _g3mfp_rat(unit_scale_to_si, "power unit_scale_to_si")
        scale == 1 // 1 || throw(ArgumentError("v1 operating power must already be in SI watts (scale 1)"))
        evidence_ref = _g3mfp_ref(source_evidence_ref, "source_evidence_ref")
        evidence = _g3mfp_bytes(source_evidence_bytes, "source_evidence_bytes")
        evidence_sha = _g3mfp_bytes_sha(evidence)
        authority = _g3mfp_ref(authority_ref, "authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_source_record, :synthetic_local) ||
            throw(ArgumentError("authority_scope must identify a local source record or a synthetic fixture"))
        draft = (candidate_ref=c, source_ref=src, source_id=sid, declaration_hash=dh,
            endpoint_id=endpoint, operating_condition_ref=condition,
            operating_condition_hash=condition_hash, power_w=p, unit_id=uid,
            unit_basis=G3_MFP_V1_SI_BASIS, unit=unit, unit_scale_to_si=scale,
            source_evidence_ref=evidence_ref,
            source_evidence_bytes=length(evidence), source_evidence_sha256=evidence_sha,
            authority_ref=authority, authority_scope=scope)
        auth_hash = canonical_hash((domain="G3-MFP-local-authority-binding-v1",
            authority_ref=authority, authority_scope=scope, body=draft))
        body = merge(draft, (authority_binding_hash=auth_hash,))
        witness_hash = canonical_hash((domain="G3-MFP-operating-power-witness-v1", body=body))
        new(c, src, sid, dh, endpoint, condition, condition_hash, p, uid, unit, scale,
            evidence_ref, evidence, evidence_sha, authority, scope, auth_hash, witness_hash)
    end
end

semantic_view(x::G3MFPOperatingPowerWitnessV1) =
    merge(_g3mfp_power_witness_body(x), (witness_hash=x.witness_hash,))

function _g3mfp_power_witness_valid(x::G3MFPOperatingPowerWitnessV1)
    x.source_evidence_sha256 == _g3mfp_bytes_sha(x.source_evidence_bytes) || return false
    _g3mfp_unit_matches(x.unit, G3_MFP_V1_W_UNIT) && x.unit_id == "W" &&
        x.unit_scale_to_si == 1 // 1 && x.power_w >= 0 || return false
    content = _g3mfp_power_witness_content(x)
    expected_auth = canonical_hash((domain="G3-MFP-local-authority-binding-v1",
        authority_ref=x.authority_ref, authority_scope=x.authority_scope, body=content))
    expected_auth == x.authority_binding_hash || return false
    canonical_hash((domain="G3-MFP-operating-power-witness-v1",
        body=merge(content, (authority_binding_hash=x.authority_binding_hash,)))) == x.witness_hash
end

struct G3MFPConductivitySelectionV1
    candidate_ref::QualifiedRefV1
    region_id::String
    component::G3RealizationComponentV2
    material_domain::G3MaterialDomainV2
    selected_value::Rational{Int64}
    unit_id::String
    unit_scale_to_si::Rational{Int64}
    operating_condition_ref::QualifiedRefV1
    operating_condition_hash::Digest256
    source_ref::QualifiedRefV1
    source_bytes::Tuple{Vararg{UInt8}}
    source_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    selection_hash::Digest256
    function G3MFPConductivitySelectionV1(candidate_ref::Any, region_id::Any,
            component::Any, material_domain::Any, selected_value::Any,
            unit_id::Any, unit_scale_to_si::Any, operating_condition_ref::Any,
            operating_condition_hash::Any, source_ref::Any, source_bytes::Any,
            authority_ref::Any, authority_scope::Any)
        c = _g3mfp_ref(candidate_ref, "selection candidate_ref")
        c.version == "v5" || throw(ArgumentError("selection candidate_ref must use v5"))
        region = _g3mfp_text(region_id, "region_id")
        component isa G3RealizationComponentV2 ||
            throw(ArgumentError("component must be G3RealizationComponentV2"))
        domain = material_domain isa G3MaterialDomainV2 ? material_domain :
            throw(ArgumentError("material_domain must be G3MaterialDomainV2"))
        domain.property === :conductivity || throw(ArgumentError("material domain must declare conductivity"))
        domain.material_id == component.material_id ||
            throw(ArgumentError("component material_id must match selected material domain"))
        _g3mfp_unit_matches(domain.unit, G3_MFP_V1_W_PER_M_K_UNIT) ||
            throw(ArgumentError("conductivity domain must use W/(m*K) SI exponents in the declared basis"))
        selected = _g3mfp_rat(selected_value, "selected_value")
        domain.lower <= selected <= domain.upper ||
            throw(ArgumentError("selected conductivity must lie in its declared material domain"))
        uid = _g3mfp_text(unit_id, "conductivity unit_id")
        uid == "W/(m*K)" || throw(ArgumentError("conductivity unit_id must be W/(m*K)"))
        scale = _g3mfp_rat(unit_scale_to_si, "conductivity unit_scale_to_si")
        scale == 1 // 1 || throw(ArgumentError("v1 conductivity must already be in SI W/(m*K) (scale 1)"))
        condition = _g3mfp_ref(operating_condition_ref, "selection operating_condition_ref")
        condition_hash = _g3mfp_hash(operating_condition_hash, "selection operating_condition_hash")
        src = _g3mfp_ref(source_ref, "selection source_ref")
        bytes = _g3mfp_bytes(source_bytes, "selection source_bytes")
        sha = _g3mfp_bytes_sha(bytes)
        authority = _g3mfp_ref(authority_ref, "selection authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_material_record, :synthetic_local) ||
            throw(ArgumentError("material authority_scope must identify a local source record or synthetic fixture"))
        draft = (candidate_ref=c, region_id=region, component=component,
            material_domain=domain, selected_value=selected, unit_id=uid,
            unit_scale_to_si=scale, operating_condition_ref=condition,
            operating_condition_hash=condition_hash, source_ref=src,
            source_bytes=bytes, source_sha256=sha, authority_ref=authority,
            authority_scope=scope)
        auth_hash = canonical_hash((domain="G3-MFP-material-authority-binding-v1", body=draft))
        body = merge(draft, (authority_binding_hash=auth_hash,))
        selection_hash = canonical_hash((domain="G3-MFP-conductivity-selection-v1", body=body))
        new(c, region, component, domain, selected, uid, scale, condition,
            condition_hash, src, bytes, sha, authority, scope, auth_hash, selection_hash)
    end
end

semantic_view(x::G3MFPConductivitySelectionV1) =
    (candidate_ref=x.candidate_ref, region_id=x.region_id, component=x.component,
     material_domain=x.material_domain, selected_value=x.selected_value,
     unit_id=x.unit_id, unit_scale_to_si=x.unit_scale_to_si,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash, source_ref=x.source_ref,
     source_bytes=length(x.source_bytes), source_sha256=x.source_sha256,
     authority_ref=x.authority_ref, authority_scope=x.authority_scope,
     authority_binding_hash=x.authority_binding_hash,
     selection_hash=x.selection_hash)

function _g3mfp_selection_valid(x::G3MFPConductivitySelectionV1)
    x.source_sha256 == _g3mfp_bytes_sha(x.source_bytes) || return false
    x.material_domain.property === :conductivity || return false
    _g3mfp_unit_matches(x.material_domain.unit, G3_MFP_V1_W_PER_M_K_UNIT) || return false
    x.unit_id == "W/(m*K)" && x.unit_scale_to_si == 1 // 1 || return false
    x.authority_scope in (:agent_local_material_record, :synthetic_local) || return false
    x.material_domain.lower <= x.selected_value <= x.material_domain.upper || return false
    body = (candidate_ref=x.candidate_ref, region_id=x.region_id,
        component=x.component, material_domain=x.material_domain,
        selected_value=x.selected_value, unit_id=x.unit_id,
        unit_scale_to_si=x.unit_scale_to_si,
        operating_condition_ref=x.operating_condition_ref,
        operating_condition_hash=x.operating_condition_hash, source_ref=x.source_ref,
        source_bytes=x.source_bytes, source_sha256=x.source_sha256,
        authority_ref=x.authority_ref, authority_scope=x.authority_scope)
    expected_auth = canonical_hash((domain="G3-MFP-material-authority-binding-v1", body=body))
    expected_auth == x.authority_binding_hash || return false
    canonical_hash((domain="G3-MFP-conductivity-selection-v1",
        body=merge(body, (authority_binding_hash=x.authority_binding_hash,)))) == x.selection_hash
end

struct G3MFPRegionSupportV1
    region_id::String
    shape_weight::Rational{Int64}
    physical_volume_m3::Rational{Int64}
    function G3MFPRegionSupportV1(region_id::Any, shape_weight::Any, physical_volume_m3::Any)
        region = _g3mfp_text(region_id, "support region_id")
        weight = _g3mfp_rat(shape_weight, "dimensionless shape_weight")
        weight >= 0 || throw(ArgumentError("shape_weight must be non-negative"))
        volume = _g3mfp_rat(physical_volume_m3, "physical_volume_m3")
        volume > 0 || throw(ArgumentError("physical_volume_m3 must be positive"))
        new(region, weight, volume)
    end
end

semantic_view(x::G3MFPRegionSupportV1) =
    (region_id=x.region_id, shape_weight=x.shape_weight,
     physical_volume_m3=x.physical_volume_m3,
     volume_unit_id="m^3", volume_unit=_g3mfp_unit_view(G3_MFP_V1_M3_UNIT))

struct G3MFPPhysicalMeasureReceiptV1
    candidate_ref::QualifiedRefV1
    g2_map_ref::QualifiedRefV1
    g2_map_hash::Digest256
    provenance::Symbol
    jacobian_included::Bool
    region_support::Tuple{Vararg{G3MFPRegionSupportV1}}
    evidence_ref::QualifiedRefV1
    evidence_bytes::Tuple{Vararg{UInt8}}
    evidence_sha256::Digest256
    authority_ref::QualifiedRefV1
    authority_scope::Symbol
    authority_binding_hash::Digest256
    receipt_hash::Digest256
    function G3MFPPhysicalMeasureReceiptV1(candidate_ref::Any, g2_map_ref::Any,
            g2_map_hash::Any, provenance::Any, jacobian_included::Any,
            region_support::Any, evidence_ref::Any, evidence_bytes::Any,
            authority_ref::Any, authority_scope::Any)
        c = _g3mfp_ref(candidate_ref, "measure candidate_ref")
        c.version == "v5" || throw(ArgumentError("measure candidate_ref must use v5"))
        map_ref = _g3mfp_ref(g2_map_ref, "g2_map_ref")
        map_hash = _g3mfp_hash(g2_map_hash, "g2_map_hash")
        prov = provenance isa Symbol ? provenance : Symbol(provenance)
        prov in (:synthetic_local, :candidate_mapped_unverified) ||
            throw(ArgumentError("measure provenance must be explicit and unverified"))
        prov === :candidate_mapped_unverified &&
            !startswith(map_ref.id, "fusionconceptai://GenomeV5/G2/") &&
            throw(ArgumentError("candidate-mapped measure must name a G2 map reference"))
        jacobian_included isa Bool || throw(ArgumentError("jacobian_included must be Bool"))
        supports = region_support isa Tuple ? region_support :
            throw(ArgumentError("region_support must be an immutable tuple"))
        all(x -> x isa G3MFPRegionSupportV1, supports) ||
            throw(ArgumentError("region_support must contain typed region supports"))
        !isempty(supports) || throw(ArgumentError("region_support must not be empty"))
        ids = Tuple(x.region_id for x in supports)
        length(unique(ids)) == length(ids) || throw(ArgumentError("duplicate measure region_id"))
        source_ref = _g3mfp_ref(evidence_ref, "measure evidence_ref")
        bytes = _g3mfp_bytes(evidence_bytes, "measure evidence_bytes")
        sha = _g3mfp_bytes_sha(bytes)
        authority = _g3mfp_ref(authority_ref, "measure authority_ref")
        scope = authority_scope isa Symbol ? authority_scope : Symbol(authority_scope)
        scope in (:agent_local_measure_record, :synthetic_local) ||
            throw(ArgumentError("measure authority_scope must identify a local source record or synthetic fixture"))
        draft = (schema_id=G3_MFP_V1_SCHEMA_ID * "/PhysicalMeasureReceipt",
            version=G3_MFP_V1_VERSION, candidate_ref=c, g2_map_ref=map_ref,
            g2_map_hash=map_hash, provenance=prov,
            measure_unit_id="m^3", measure_unit=_g3mfp_unit_view(G3_MFP_V1_M3_UNIT),
            jacobian_included=jacobian_included, region_support=Tuple(supports),
            evidence_ref=source_ref, evidence_bytes=bytes, evidence_sha256=sha,
            authority_ref=authority, authority_scope=scope)
        auth_hash = canonical_hash((domain="G3-MFP-measure-authority-binding-v1", body=draft))
        receipt_hash = canonical_hash(merge(draft, (authority_binding_hash=auth_hash,)))
        new(c, map_ref, map_hash, prov, jacobian_included, Tuple(supports),
            source_ref, bytes, sha, authority, scope, auth_hash, receipt_hash)
    end
end

function _g3mfp_measure_content(x::G3MFPPhysicalMeasureReceiptV1)
    (schema_id=G3_MFP_V1_SCHEMA_ID * "/PhysicalMeasureReceipt",
     version=G3_MFP_V1_VERSION, candidate_ref=x.candidate_ref,
     g2_map_ref=x.g2_map_ref, g2_map_hash=x.g2_map_hash,
     provenance=x.provenance, measure_unit_id="m^3",
     measure_unit=_g3mfp_unit_view(G3_MFP_V1_M3_UNIT),
     jacobian_included=x.jacobian_included, region_support=x.region_support,
     evidence_ref=x.evidence_ref, evidence_bytes=x.evidence_bytes,
     evidence_sha256=x.evidence_sha256, authority_ref=x.authority_ref,
     authority_scope=x.authority_scope)
end
_g3mfp_measure_body(x::G3MFPPhysicalMeasureReceiptV1) =
    merge(_g3mfp_measure_content(x), (authority_binding_hash=x.authority_binding_hash,))
semantic_view(x::G3MFPPhysicalMeasureReceiptV1) =
    merge(_g3mfp_measure_body(x), (receipt_hash=x.receipt_hash,))

function _g3mfp_measure_valid(x::G3MFPPhysicalMeasureReceiptV1)
    x.evidence_sha256 == _g3mfp_bytes_sha(x.evidence_bytes) || return false
    x.provenance in (:synthetic_local, :candidate_mapped_unverified) || return false
    x.authority_scope in (:agent_local_measure_record, :synthetic_local) || return false
    content = _g3mfp_measure_content(x)
    canonical_hash((domain="G3-MFP-measure-authority-binding-v1", body=content)) ==
        x.authority_binding_hash || return false
    x.receipt_hash == canonical_hash(_g3mfp_measure_body(x)) || return false
    length(Set(s.region_id for s in x.region_support)) == length(x.region_support) || return false
    all(s -> s.physical_volume_m3 > 0 && s.shape_weight >= 0, x.region_support)
end

struct G3MFPProjectedRegionV1
    region_id::String
    component_id::String
    material_id::String
    conductivity_w_m_k::Rational{Int64}
    normalized_source_weight_m_inv3::Rational{Int64}
    volumetric_source_w_m3::Rational{Int64}
    physical_volume_m3::Rational{Int64}
end

semantic_view(x::G3MFPProjectedRegionV1) =
    (region_id=x.region_id, component_id=x.component_id, material_id=x.material_id,
     conductivity_w_m_k=x.conductivity_w_m_k,
     conductivity_unit_id="W/(m*K)",
     conductivity_unit=_g3mfp_unit_view(G3_MFP_V1_W_PER_M_K_UNIT),
     normalized_source_weight_m_inv3=x.normalized_source_weight_m_inv3,
     source_weight_unit_id="m^-3",
     source_weight_unit=_g3mfp_unit_view(G3_MFP_V1_M_INV3_UNIT),
     volumetric_source_w_m3=x.volumetric_source_w_m3,
     volumetric_source_unit_id="W/m^3",
     volumetric_source_unit=_g3mfp_unit_view(G3_MFP_V1_W_PER_M3_UNIT),
     physical_volume_m3=x.physical_volume_m3,
     volume_unit_id="m^3", volume_unit=_g3mfp_unit_view(G3_MFP_V1_M3_UNIT))

struct G3MFPProjectionReceiptV1
    candidate_ref::Union{Nothing,QualifiedRefV1}
    declaration_hash::Union{Nothing,Digest256}
    operating_power_witness_hash::Union{Nothing,Digest256}
    physical_measure_hash::Union{Nothing,Digest256}
    conductivity_selection_hashes::Tuple{Vararg{Digest256}}
    operating_condition_ref::Union{Nothing,QualifiedRefV1}
    operating_condition_hash::Union{Nothing,Digest256}
    input_provenance::Symbol
    regions::Tuple{Vararg{G3MFPProjectedRegionV1}}
    source_power_w::Union{Nothing,Rational{Int64}}
    normalized_support_integral::Union{Nothing,Rational{Int64}}
    integrated_source_power_w::Union{Nothing,Rational{Int64}}
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

function _g3mfp_projection_content(x::G3MFPProjectionReceiptV1)
    (schema_id=G3_MFP_V1_SCHEMA_ID, version=G3_MFP_V1_VERSION,
     candidate_ref=x.candidate_ref, declaration_hash=x.declaration_hash,
     operating_power_witness_hash=x.operating_power_witness_hash,
     physical_measure_hash=x.physical_measure_hash,
     conductivity_selection_hashes=x.conductivity_selection_hashes,
     operating_condition_ref=x.operating_condition_ref,
     operating_condition_hash=x.operating_condition_hash,
     input_provenance=x.input_provenance, regions=x.regions,
     source_power_w=x.source_power_w,
     normalized_support_integral=x.normalized_support_integral,
     integrated_source_power_w=x.integrated_source_power_w,
     status=x.status, resolution=x.resolution, accepted=x.accepted,
     claim_ceiling=x.claim_ceiling, physical_status=x.physical_status,
     formal_up2_credit=x.formal_up2_credit, formal_r_credit=x.formal_r_credit,
     discovery_credit=x.discovery_credit, engineering_credit=x.engineering_credit,
     compiler_calls=x.compiler_calls, provider_calls=x.provider_calls,
     mesh_calls=x.mesh_calls, solver_calls=x.solver_calls,
     errors=x.errors, gaps=x.gaps)
end

_g3mfp_projection_receipt_valid(x::G3MFPProjectionReceiptV1) =
    x.accepted === false && x.claim_ceiling === :screen_only &&
    x.physical_status === :unknown && !x.formal_up2_credit && !x.formal_r_credit &&
    !x.discovery_credit && !x.engineering_credit && x.compiler_calls == 0 &&
    x.provider_calls == 0 && x.mesh_calls == 0 && x.solver_calls == 0 &&
    x.receipt_hash == canonical_hash(_g3mfp_projection_content(x))

function _g3mfp_receipt(candidate_ref, declaration_hash; power_hash=nothing,
        measure_hash=nothing, selection_hashes=(), operating_condition_ref=nothing,
        operating_condition_hash=nothing, input_provenance=:unknown, regions=(),
        source_power_w=nothing, normalized_support_integral=nothing,
        integrated_source_power_w=nothing, status=:terminal_deferred,
        resolution=:terminal_deferred, errors=(), gaps=())
    body = (schema_id=G3_MFP_V1_SCHEMA_ID, version=G3_MFP_V1_VERSION,
        candidate_ref=candidate_ref, declaration_hash=declaration_hash,
        operating_power_witness_hash=power_hash, physical_measure_hash=measure_hash,
        conductivity_selection_hashes=Tuple(selection_hashes),
        operating_condition_ref=operating_condition_ref,
        operating_condition_hash=operating_condition_hash,
        input_provenance=input_provenance, regions=Tuple(regions),
        source_power_w=source_power_w, normalized_support_integral=normalized_support_integral,
        integrated_source_power_w=integrated_source_power_w, status=status,
        resolution=resolution, accepted=false, claim_ceiling=G3_MFP_V1_CLAIM_CEILING,
        physical_status=:unknown, formal_up2_credit=false, formal_r_credit=false,
        discovery_credit=false, engineering_credit=false, compiler_calls=0,
        provider_calls=0, mesh_calls=0, solver_calls=0,
        errors=Tuple(String.(errors)), gaps=Tuple(String.(gaps)))
    hash = canonical_hash(body)
    G3MFPProjectionReceiptV1(candidate_ref, declaration_hash, power_hash, measure_hash,
        Tuple(selection_hashes), operating_condition_ref, operating_condition_hash,
        input_provenance, Tuple(regions), source_power_w, normalized_support_integral,
        integrated_source_power_w, status, resolution, false, G3_MFP_V1_CLAIM_CEILING,
        :unknown, false, false, false, false, 0, 0, 0, 0,
        Tuple(String.(errors)), Tuple(String.(gaps)), hash)
end

semantic_view(x::G3MFPProjectionReceiptV1) =
    merge(_g3mfp_projection_content(x), (receipt_hash=x.receipt_hash,))

function g3_mfp_project_v1(declaration::Any, power_witness::Any=nothing;
        physical_measure::Any=nothing, conductivity_selections::Any=())
    if !(declaration isa G3SFDeclarationV1)
        declaration === nothing && return _g3mfp_receipt(nothing, nothing;
            status=:terminal_deferred, resolution=:terminal_deferred,
            gaps=("g3_source_declaration_missing",))
        return _g3mfp_receipt(nothing, nothing; status=:fail_closed,
            resolution=:fail_closed, errors=("g3_source_declaration_type_invalid",))
    end
    candidate = declaration.candidate_ref
    declaration_hash = declaration.declaration_hash
    declared_status, declared_errors = g3_sf_validate_v1(declaration)
    declared_status === :valid || return _g3mfp_receipt(candidate, declaration_hash;
        status=:fail_closed, resolution=:fail_closed,
        errors=Tuple("g3_declaration:" * String(e) for e in declared_errors))

    missing = String[]
    conductivity_selections isa Tuple || return _g3mfp_receipt(candidate, declaration_hash;
        status=:fail_closed, resolution=:fail_closed,
        errors=("conductivity_selections_must_be_tuple",))
    power_witness === nothing && push!(missing, "candidate_source_bound_operating_power_witness_missing")
    physical_measure === nothing && push!(missing, "g2_physical_measure_receipt_missing")
    if isempty(conductivity_selections)
        push!(missing, "region_conductivity_selections_missing")
    end
    !isempty(missing) && return _g3mfp_receipt(candidate, declaration_hash;
        status=:terminal_deferred, resolution=:terminal_deferred, gaps=Tuple(missing))

    errors = String[]
    power_witness isa G3MFPOperatingPowerWitnessV1 ||
        push!(errors, "operating_power_witness_type_invalid")
    physical_measure isa G3MFPPhysicalMeasureReceiptV1 ||
        push!(errors, "physical_measure_receipt_type_invalid")
    conductivity_selections isa Tuple || push!(errors, "conductivity_selections_must_be_tuple")
    if !isempty(errors)
        return _g3mfp_receipt(candidate, declaration_hash; status=:fail_closed,
            resolution=:fail_closed, errors=Tuple(errors))
    end

    witness = power_witness::G3MFPOperatingPowerWitnessV1
    measure = physical_measure::G3MFPPhysicalMeasureReceiptV1
    if !_g3mfp_power_witness_valid(witness)
        push!(errors, "operating_power_witness_hash_or_source_bytes_mismatch")
    end
    source_endpoint = only(filter(e -> e.role === :source, declaration.endpoints))
    _g3mfp_unit_matches(source_endpoint.unit, G3_MFP_V1_W_UNIT) ||
        push!(errors, "g3_source_endpoint_not_si_watts")
    witness.candidate_ref == candidate || push!(errors, "operating_power_candidate_mismatch")
    witness.source_id == declaration.source_id || push!(errors, "operating_power_source_id_mismatch")
    witness.source_ref == QualifiedRefV1(G3_MFP_V1_SOURCE_RECORD_PREFIX * declaration.source_id,
        "v1") || push!(errors, "operating_power_source_ref_mismatch")
    witness.declaration_hash == declaration_hash || push!(errors, "operating_power_declaration_hash_mismatch")
    witness.endpoint_id == declaration.law.source_endpoint_id ||
        push!(errors, "operating_power_endpoint_mismatch")
    _g3mfp_measure_valid(measure) || push!(errors, "physical_measure_receipt_hash_or_bytes_mismatch")
    measure.candidate_ref == candidate || push!(errors, "physical_measure_candidate_mismatch")
    measure.jacobian_included || push!(errors, "physical_measure_jacobian_missing")
    selection_tuple = conductivity_selections::Tuple
    all(x -> x isa G3MFPConductivitySelectionV1, selection_tuple) ||
        push!(errors, "conductivity_selection_type_invalid")
    if !isempty(errors)
        return _g3mfp_receipt(candidate, declaration_hash;
            power_hash=witness.witness_hash, measure_hash=measure.receipt_hash,
            status=:fail_closed, resolution=:fail_closed, errors=Tuple(errors))
    end

    region_ids = Tuple(s.region_id for s in measure.region_support)
    selection_ids = Tuple(s.region_id for s in selection_tuple)
    length(Set(selection_ids)) == length(selection_ids) || push!(errors, "duplicate_region_conductivity_selection")
    all(id -> id in region_ids, selection_ids) || push!(errors, "conductivity_selection_for_unknown_region")
    for selection in selection_tuple
        _g3mfp_selection_valid(selection) || push!(errors, "conductivity_selection_hash_or_source_mismatch:" * selection.region_id)
        selection.candidate_ref == candidate || push!(errors, "conductivity_candidate_mismatch:" * selection.region_id)
        selection.operating_condition_ref == witness.operating_condition_ref ||
            push!(errors, "conductivity_operating_condition_ref_mismatch:" * selection.region_id)
        selection.operating_condition_hash == witness.operating_condition_hash ||
            push!(errors, "conductivity_operating_condition_hash_mismatch:" * selection.region_id)
        selection.component.material_id == selection.material_domain.material_id ||
            push!(errors, "conductivity_material_id_mismatch:" * selection.region_id)
    end
    if !isempty(errors)
        return _g3mfp_receipt(candidate, declaration_hash;
            power_hash=witness.witness_hash, measure_hash=measure.receipt_hash,
            selection_hashes=Tuple(s.selection_hash for s in selection_tuple),
            status=:fail_closed, resolution=:fail_closed, errors=Tuple(errors))
    end

    input_provenance = (witness.authority_scope === :synthetic_local ||
        measure.provenance === :synthetic_local ||
        measure.authority_scope === :synthetic_local ||
        any(s -> s.authority_scope === :synthetic_local, selection_tuple)) ?
        :synthetic_local : :candidate_mapped_unverified

    missing_regions = Tuple(id for id in region_ids if !(id in selection_ids))
    if !isempty(missing_regions)
        return _g3mfp_receipt(candidate, declaration_hash;
            power_hash=witness.witness_hash, measure_hash=measure.receipt_hash,
            selection_hashes=Tuple(s.selection_hash for s in selection_tuple),
            operating_condition_ref=witness.operating_condition_ref,
            operating_condition_hash=witness.operating_condition_hash,
            input_provenance=input_provenance, status=:terminal_deferred,
            resolution=:terminal_deferred,
            gaps=Tuple("region_conductivity_selection_missing:" * id for id in missing_regions))
    end

    shape_integral = sum(s.shape_weight * s.physical_volume_m3 for s in measure.region_support; init=0 // 1)
    shape_integral > 0 || return _g3mfp_receipt(candidate, declaration_hash;
        power_hash=witness.witness_hash, measure_hash=measure.receipt_hash,
        selection_hashes=Tuple(s.selection_hash for s in selection_tuple),
        operating_condition_ref=witness.operating_condition_ref,
        operating_condition_hash=witness.operating_condition_hash,
        input_provenance=input_provenance, status=:fail_closed,
        resolution=:fail_closed, errors=("source_shape_has_zero_physical_support_integral",))

    selections = Dict(s.region_id => s for s in selection_tuple)
    normalized = Tuple(begin
        selection = selections[support.region_id]
        weight = support.shape_weight / shape_integral
        G3MFPProjectedRegionV1(support.region_id, selection.component.component_id,
            selection.material_domain.material_id, selection.selected_value,
            weight, witness.power_w * weight, support.physical_volume_m3)
    end for support in measure.region_support)
    normalized_integral = sum(r.normalized_source_weight_m_inv3 * r.physical_volume_m3
        for r in normalized; init=0 // 1)
    integrated_power = sum(r.volumetric_source_w_m3 * r.physical_volume_m3
        for r in normalized; init=0 // 1)
    normalized_integral == 1 // 1 || push!(errors, "normalized_source_support_integral_not_one")
    integrated_power == witness.power_w || push!(errors, "integrated_source_power_not_conservative")
    !isempty(errors) && return _g3mfp_receipt(candidate, declaration_hash;
        power_hash=witness.witness_hash, measure_hash=measure.receipt_hash,
        selection_hashes=Tuple(s.selection_hash for s in selection_tuple),
        operating_condition_ref=witness.operating_condition_ref,
        operating_condition_hash=witness.operating_condition_hash,
        input_provenance=input_provenance, regions=normalized,
        source_power_w=witness.power_w, normalized_support_integral=normalized_integral,
        integrated_source_power_w=integrated_power,
        status=:fail_closed, resolution=:fail_closed, errors=Tuple(errors))

    _g3mfp_receipt(candidate, declaration_hash; power_hash=witness.witness_hash,
        measure_hash=measure.receipt_hash,
        selection_hashes=Tuple(selections[id].selection_hash for id in region_ids),
        operating_condition_ref=witness.operating_condition_ref,
        operating_condition_hash=witness.operating_condition_hash,
        input_provenance=input_provenance, regions=normalized,
        source_power_w=witness.power_w,
        normalized_support_integral=normalized_integral,
        integrated_source_power_w=integrated_power,
        status=:evaluated_screen_only, resolution=:screen_only)
end
