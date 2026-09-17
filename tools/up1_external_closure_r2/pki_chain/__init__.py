"""UP1 external closure R2 PKI chain verification.

The package deliberately has no network or trust-store side effects.  A caller
must provide a pinned root and an explicit versioned profile.  TEST_ONLY
profiles are useful for exercising the verifier, but their result is always
non-evidence.
"""

from .verifier import verify_chain, verify_request, canonical_json_bytes, result_exit_code

__all__ = ["verify_chain", "verify_request", "canonical_json_bytes", "result_exit_code"]
