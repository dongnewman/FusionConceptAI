"""Offline, fail-closed authority-channel intake for UP1 R2.

This package deliberately implements a local spool protocol only.  It never
contacts an endpoint, verifies an external signature, or creates authority.
"""

from .adapter import AuthorityIntakeAdapter, IntakeError, SCHEMA_VERSION

__all__ = ["AuthorityIntakeAdapter", "IntakeError", "SCHEMA_VERSION"]
