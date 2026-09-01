"""Versioned references to the three independently owned Genome contracts."""

struct GenomeContractRef
    uri::String
    version::String
    schema_hash::String
    canonicalization_hash::String
    compatibility_profile::String
    function GenomeContractRef(uri::AbstractString, version::AbstractString, schema_hash::AbstractString,
                               canonicalization_hash::AbstractString, compatibility_profile::AbstractString)
        all(!isempty, (uri, version, schema_hash, canonicalization_hash, compatibility_profile)) ||
            throw(ArgumentError("GenomeContractRef requires all fields and a non-empty compatibility_profile"))
        new(String(uri), String(version), String(schema_hash), String(canonicalization_hash), String(compatibility_profile))
    end
end

struct GenomeContractRegistryV4
    mechanism::GenomeContractRef
    field_geometry::GenomeContractRef
    realization_control::GenomeContractRef
    function GenomeContractRegistryV4(m::GenomeContractRef, f::GenomeContractRef, r::GenomeContractRef)
        new(m, f, r)
    end
end
