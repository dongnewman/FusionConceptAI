"""UP1 R2 source-identity and four-axis binding validator.

This package is deliberately additive and has no dependency on the Fusion runtime.
It validates a candidate-bound, immutable source snapshot and the four explicit
provenance axes used by the external-closure handoff.
"""

from .source_axis_binding import (
    AXES,
    SCHEMA_VERSION,
    BindingValidationError,
    canonical_bytes,
    canonical_digest,
    capture_source_identity,
    material_digest,
    source_identity_digest,
    validate_bundle,
)

__all__ = [
    "AXES",
    "SCHEMA_VERSION",
    "BindingValidationError",
    "canonical_bytes",
    "canonical_digest",
    "capture_source_identity",
    "material_digest",
    "source_identity_digest",
    "validate_bundle",
]
