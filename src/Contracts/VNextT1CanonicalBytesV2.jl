"""Additive, non-parameterized immutable byte carrier for the VNext T1 slice.

This file is intentionally not included by ``FusionConceptAI.jl`` yet.  V1
continues to own the current T1 admission path; V2 is a narrow contract slice
for testing stable byte ownership and cross-process replay before integration.
The ``raw`` field is a Julia ``String`` used as an immutable byte container;
no character iteration or UTF-8 normalization is performed.
"""

using Base64

const VNEXT_T1_CANONICAL_BYTES_V2_SCHEMA =
    "GenomeV5/Contracts/VNextT1CanonicalBytes"
const VNEXT_T1_CANONICAL_BYTES_V2_VERSION = "v2"
const VNEXT_T1_CANONICAL_BYTES_V2_ENCODING = :base64

"""Immutable byte payload with an explicit base64 semantic projection.

The constructor first copies the caller's byte vector and only then creates
the ``String``.  This prevents mutation of a caller-owned vector from changing
the value after construction.  The type is deliberately non-parameterized so
large payloads do not become gigantic tuple specializations.
"""
struct VNextT1CanonicalBytesV2
    raw::String
    sha256::Digest256
    encoding::Symbol

    function VNextT1CanonicalBytesV2(bytes::AbstractVector{UInt8})
        owned = copy(bytes)
        raw = String(owned)
        digest = Digest256(bytes2hex(
            invoke(SHA.sha256, Tuple{SHA.AbstractBytes}, codeunits(raw))))
        new(raw, digest, VNEXT_T1_CANONICAL_BYTES_V2_ENCODING)
    end
end

"""Return the number of exact payload bytes, including invalid UTF-8 bytes."""
byte_length(x::VNextT1CanonicalBytesV2) = ncodeunits(x.raw)

"""Return an independent ``Vector{UInt8}`` copy of the exact payload bytes."""
copy_bytes(x::VNextT1CanonicalBytesV2) = Vector{UInt8}(codeunits(x.raw))

"""Return one exact payload byte using one-based indexing."""
function byte_at(x::VNextT1CanonicalBytesV2, index::Integer)
    checkbounds(codeunits(x.raw), index)
    codeunits(x.raw)[index]
end

"""Stable, explicit cross-process semantic projection.

The base64 member is produced by Julia's Base64 stdlib from the exact raw
code units.  It is the transport form; ``sha256`` remains the digest of those
same raw code units, not of the base64 text.
"""
semantic_view(x::VNextT1CanonicalBytesV2) = (
    schema=VNEXT_T1_CANONICAL_BYTES_V2_SCHEMA,
    version=VNEXT_T1_CANONICAL_BYTES_V2_VERSION,
    encoding=x.encoding,
    base64=Base64.base64encode(copy_bytes(x)),
    length=byte_length(x),
    sha256=x.sha256,
)

"""Canonical JSON is always the explicit base64 projection, never raw bytes."""
canonical_json(x::VNextT1CanonicalBytesV2) = canonical_json(semantic_view(x))
