"""Independent, non-authoritative UP1 R4 G2 mapping prototype.

The package checks the local shape and identity closure of a G2 mapping.  It
does not verify an external signature, trust root, revocation service, or
publisher authority.
"""

from .validator import (
    MappingError,
    ProfileError,
    canonical_bytes,
    digest,
    evaluate,
    load_path,
    load_text,
    validate,
    validate_mapping,
    validate_profile,
)

__all__ = [
    "MappingError",
    "ProfileError",
    "canonical_bytes",
    "digest",
    "evaluate",
    "load_path",
    "load_text",
    "validate",
    "validate_mapping",
    "validate_profile",
]
