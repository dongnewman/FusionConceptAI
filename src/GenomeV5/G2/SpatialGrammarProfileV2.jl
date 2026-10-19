"""Closed G2 V5 grammar/profile declarations.

This file owns only structural applicability metadata.  It does not register
operators in the shared registry and it does not claim a geometry provider.
"""

function _g2v5_text(value::Any, field::AbstractString)
    value isa String || throw(ArgumentError("$field must be an immutable String"))
    isvalid(value) || throw(ArgumentError("$field must contain valid Unicode scalar values"))
    isempty(value) && throw(ArgumentError("$field cannot be empty"))
    value
end

function _g2v5_qref(value::Any, field::AbstractString)
    value isa QualifiedRefV1 || throw(ArgumentError("$field must be QualifiedRefV1"))
    value.version != "v1" || throw(ArgumentError("$field cannot reinterpret a V1 reference"))
    value
end

function _g2v5_versioned_qref(value::Any, field::AbstractString, version::String)
    ref = _g2v5_qref(value, field)
    ref.version == version || throw(ArgumentError("$field must use version $version"))
    ref
end

_g2v5_v2_qref(value::Any, field::AbstractString) =
    _g2v5_versioned_qref(value, field, "v2")
_g2v5_v5_qref(value::Any, field::AbstractString) =
    _g2v5_versioned_qref(value, field, "v5")

const G2_PROFILE_REF_ID = "fusion.g2.grammar-profile"
const G2_CANONICALIZATION_PROFILE_REF_ID = "fusion.g2.canonicalization-profile"
const G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID =
    "fusion.g2.canonicalization-profile.source-backed"
const G2_SOURCE_ORDER_CANONICALIZATION_AXIS_REF_ID =
    "fusion.g2.canonicalization.source-backed"
const G2_APPLICABILITY_PROFILE_REF_ID = "fusion.g2.applicability-profile"

function _g2v5_tuple(value::Any, field::AbstractString)
    value isa Tuple && !(value isa NamedTuple) ||
        throw(ArgumentError("$field must be an immutable tuple"))
    value
end

function _g2v5_symbol_tuple(value::Any, field::AbstractString)
    tuple = _g2v5_tuple(value, field)
    all(x -> x isa Symbol && !isempty(String(x)), tuple) ||
        throw(ArgumentError("$field must contain non-empty Symbols"))
    tuple
end

struct SpatialGrammarProfileV2
    profile_ref::QualifiedRefV1
    canonicalization_profile_ref::QualifiedRefV1
    applicability_profile_ref::QualifiedRefV1
    ambient_dimension::Int
    supported_topologies::Tuple{Vararg{Symbol}}
    mesh_families::Tuple{Vararg{Symbol}}
    provider_match::Symbol
    function SpatialGrammarProfileV2(profile_ref::Any,
                                     canonicalization_profile_ref::Any,
                                     applicability_profile_ref::Any,
                                     ambient_dimension::Any,
                                     supported_topologies::Any,
                                     mesh_families::Any;
                                     provider_match::Symbol=:no_match)
        p = _g2v5_v2_qref(profile_ref, "profile_ref")
        c = _g2v5_v2_qref(canonicalization_profile_ref, "canonicalization_profile_ref")
        a = _g2v5_v2_qref(applicability_profile_ref, "applicability_profile_ref")
        p.id == G2_PROFILE_REF_ID ||
            throw(ArgumentError("profile_ref must use the fusion.g2.grammar-profile domain"))
        c.id in (G2_CANONICALIZATION_PROFILE_REF_ID,
                 G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID) ||
            throw(ArgumentError("canonicalization_profile_ref must use a controlled G2 canonicalization profile"))
        a.id == G2_APPLICABILITY_PROFILE_REF_ID ||
            throw(ArgumentError("applicability_profile_ref must use the fusion.g2.applicability-profile domain"))
        ambient_dimension isa Integer && !(ambient_dimension isa Bool) ||
            throw(ArgumentError("ambient_dimension must be an integer"))
        Int(ambient_dimension) == 3 ||
            throw(ArgumentError("G2 V5 profile requires ambient_dimension=3"))
        topologies = _g2v5_symbol_tuple(supported_topologies, "supported_topologies")
        meshes = _g2v5_symbol_tuple(mesh_families, "mesh_families")
        isempty(topologies) && throw(ArgumentError("supported_topologies cannot be empty"))
        isempty(meshes) && throw(ArgumentError("mesh_families cannot be empty"))
        provider_match in (:unique_match, :no_match, :invalid_signature) ||
            throw(ArgumentError("provider_match must be :unique_match, :no_match or :invalid_signature"))
        length(unique(topologies)) == length(topologies) ||
            throw(ArgumentError("supported_topologies must be unique"))
        length(unique(meshes)) == length(meshes) ||
            throw(ArgumentError("mesh_families must be unique"))
        new(p, c, a, 3, topologies, meshes, provider_match)
    end
end

semantic_view(x::SpatialGrammarProfileV2) =
    (profile_ref=x.profile_ref,
     canonicalization_profile_ref=x.canonicalization_profile_ref,
     applicability_profile_ref=x.applicability_profile_ref,
     ambient_dimension=x.ambient_dimension,
     supported_topologies=x.supported_topologies,
     mesh_families=x.mesh_families,
     provider_match=x.provider_match)

canonical_json(x::SpatialGrammarProfileV2) = canonical_json(semantic_view(x))
g2_profile_hash(x::SpatialGrammarProfileV2)::Digest256 = canonical_hash(x)

const G2_SCHEMA_DESCRIPTOR_V2 =
    (name="FieldGeometryGenomeV5",
     fields=("external_contract_ref", "region_interface", "chart", "embedding",
             "field_space", "mesh", "exterior", "version_axes"),
     constraints=("ambient_dimension=3", "region_bounds_strict", "interface_face_match",
                  "interface_tangential_coverage", "closed_exterior_boundary",
                  "candidate_bound_hash"))

const G2_CANONICALIZATION_DESCRIPTOR_V2 =
    (domain="fusionconceptai:g2:v5",
     encoding="canonical_json_named_tuple_sorted_keys",
     exact_coordinate_type="Rational{Int64}",
     version_axes=("payload_schema_version", "canonicalization_profile_version",
                   "applicability_profile_version", "evidence_receipt_version"))

# The historical profile remains byte/order preserving.  Only current
# source-backed projections opt into this separately bound representation rule.
const G2_SOURCE_ORDER_CANONICALIZATION_DESCRIPTOR_V2 =
    (base=G2_CANONICALIZATION_DESCRIPTOR_V2,
     profile_ref=(id=G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID, version="v2"),
     canonicalization_axis=(id=G2_SOURCE_ORDER_CANONICALIZATION_AXIS_REF_ID,
         version="v5"),
     unordered_fields=(
         "region_interface.regions sorted by region_id",
         "plan.mesh.region_ids sorted by region_id",
         "plan.exterior.boundary_region_ids sorted by region_id",
         "plan.exterior.boundary_faces sorted lexically",
         "plan.exterior.boundary_patches sorted by face, region_id, lower, upper"),
     ordered_fields=("plan.mesh.cells_per_region retained in source x/y/z axis order",
         "plan.mesh.basis", "plan.mesh.quadrature"))

g2_schema_hash()::Digest256 = canonical_hash(G2_SCHEMA_DESCRIPTOR_V2)
g2_canonicalization_hash()::Digest256 = canonical_hash(G2_CANONICALIZATION_DESCRIPTOR_V2)
function g2_canonicalization_hash(profile::SpatialGrammarProfileV2)::Digest256
    descriptor = profile.canonicalization_profile_ref.id ==
        G2_SOURCE_ORDER_CANONICALIZATION_PROFILE_REF_ID ?
        G2_SOURCE_ORDER_CANONICALIZATION_DESCRIPTOR_V2 :
        G2_CANONICALIZATION_DESCRIPTOR_V2
    canonical_hash(descriptor)
end
g2_compatibility_profile_token(profile::SpatialGrammarProfileV2)::String =
    "g2-v5-profile:" * g2_profile_hash(profile).value
