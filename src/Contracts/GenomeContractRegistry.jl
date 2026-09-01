"""Versioned references to the three independently owned Genome contracts."""

struct GenomeContractRef
    uri::String
    version::String
    schema_hash::Digest256
    canonicalization_hash::Digest256
    compatibility_profile::String
    function GenomeContractRef(uri::AbstractString, version::AbstractString, schema_hash::Digest256,
                               canonicalization_hash::Digest256, compatibility_profile::AbstractString)
        all(!isempty, (uri, version, compatibility_profile)) ||
            throw(ArgumentError("GenomeContractRef requires all fields and a non-empty compatibility_profile"))
        new(String(uri), String(version), schema_hash, canonicalization_hash, String(compatibility_profile))
    end
end
GenomeContractRef(uri::AbstractString, version::AbstractString, schema_hash::AbstractString,
                  canonicalization_hash::AbstractString, profile::AbstractString) =
    GenomeContractRef(uri, version, Digest256(schema_hash), Digest256(canonicalization_hash), profile)
Base.:(==)(a::GenomeContractRef, b::GenomeContractRef) = semantic_view(a) == semantic_view(b)
semantic_view(x::GenomeContractRef) = (uri=x.uri, version=x.version, schema_hash=x.schema_hash,
                                        canonicalization_hash=x.canonicalization_hash, compatibility_profile=x.compatibility_profile)

struct GenomeContractRegistryV4
    mechanism::GenomeContractRef
    field_geometry::GenomeContractRef
    realization_control::GenomeContractRef
    function GenomeContractRegistryV4(m::GenomeContractRef, f::GenomeContractRef, r::GenomeContractRef)
        new(m, f, r)
    end
end
semantic_view(x::GenomeContractRegistryV4) = (mechanism=x.mechanism, field_geometry=x.field_geometry, realization_control=x.realization_control)

function resolve_contract(registry::GenomeContractRegistryV4, ref::GenomeContractRef, role::Symbol)
    expected = role === :mechanism ? registry.mechanism : role === :field_geometry ? registry.field_geometry :
               role === :realization_control ? registry.realization_control : throw(ArgumentError("unknown contract role"))
    ref == expected
end
