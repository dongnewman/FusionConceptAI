"""Offline, non-authoritative UP1 R4 trust-chain prototype.

This package deliberately has no bundled roots, no system-store lookup and no
network access.  A caller supplies every root and certificate byte.  A
cryptographically consistent chain is reported as ``unverified``: it is local
software behavior, not external authority evidence.
"""

from .verifier import (
    ALLOWED_ALGORITHMS,
    CRYPTOGRAPHY_AVAILABLE,
    SCHEMA,
    VerificationError,
    canonical_json_bytes,
    certificate_raw_sha256,
    hash_raw_bytes,
    hash_certificate_raw_bytes,
    result_exit_code,
    verify_certificate_chain,
    verify_chain,
    verify_request,
    verify_signature,
    verify_signature_result,
)

__all__ = [
    "SCHEMA",
    "ALLOWED_ALGORITHMS",
    "CRYPTOGRAPHY_AVAILABLE",
    "VerificationError",
    "canonical_json_bytes",
    "certificate_raw_sha256",
    "hash_raw_bytes",
    "hash_certificate_raw_bytes",
    "result_exit_code",
    "verify_certificate_chain",
    "verify_chain",
    "verify_request",
    "verify_signature",
    "verify_signature_result",
]
