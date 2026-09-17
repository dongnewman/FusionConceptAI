"""UP1 external closure R2: offline revocation, trusted-time and replay checks.

This package deliberately contains no network client and never creates production
authority.  Its fixture profile is explicitly TEST_ONLY and its output claim
ceiling is ``TEST_ONLY non_evidence``.
"""

from .core import PersistentReplayLedger, ReceiptInputError, canonical_bytes, canonical_digest, evaluate_windows_acl, parse_json_strict, validate, validate_acl_provider

__all__ = ["validate", "PersistentReplayLedger", "ReceiptInputError", "canonical_bytes", "canonical_digest", "parse_json_strict", "evaluate_windows_acl", "validate_acl_provider"]
