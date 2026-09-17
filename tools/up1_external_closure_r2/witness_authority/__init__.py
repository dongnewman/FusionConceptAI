"""UP1 external witness and authority receipt boundary.

This package is deliberately local and side-effect free.  It validates the
shape and bindings of a supplied record; it never contacts an endpoint,
loads credentials, or treats a test fixture as evidence.
"""

from .validator import AuthorityLedger, validate, validate_batch

__all__ = ["AuthorityLedger", "validate", "validate_batch"]
