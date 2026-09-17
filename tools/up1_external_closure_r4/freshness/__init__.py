"""Offline freshness and revocation prototype.

The package deliberately has no network client.  A result is never a
publication or a formal credit: callers must treat ``formal_credit=none`` and
``no_publish=true`` as part of the protocol, including on success.
"""

from .core import (
    CLAIM_CEILING,
    PROFILE,
    SCHEMA,
    PersistentReplayLedger,
    PersistentReplayState,
    ReceiptInputError,
    canonical_bytes,
    canonical_digest,
    parse_json_strict,
    validate,
    validate_freshness,
    validate_revocation_receipt,
)

__all__ = [
    "CLAIM_CEILING",
    "PROFILE",
    "SCHEMA",
    "PersistentReplayLedger",
    "PersistentReplayState",
    "ReceiptInputError",
    "canonical_bytes",
    "canonical_digest",
    "parse_json_strict",
    "validate",
    "validate_freshness",
    "validate_revocation_receipt",
]
