"""UP1 R2 reproducible-environment and binary-provenance closure.

This package performs offline Ed25519 verification with the already available
``cryptography`` runtime. It observes files when asked, but never installs,
downloads, or treats a local observation as an authority attestation.
"""

from .validator import (
    FAIL_CLOSED,
    NON_EVIDENCE,
    PRESENT,
    TYPED_ABSENT,
    ValidationResult,
    canonical_sha256,
    validate_document,
)

__all__ = [
    "FAIL_CLOSED",
    "NON_EVIDENCE",
    "PRESENT",
    "TYPED_ABSENT",
    "ValidationResult",
    "canonical_sha256",
    "validate_document",
]
