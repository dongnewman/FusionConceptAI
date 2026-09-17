"""Offline authoritative-channel intake boundary (R4).

This package is deliberately a local isolation prototype.  It never opens a
socket, sends an acknowledgement, verifies an external trust root, or turns a
file-system write into authority.  See :mod:`intake` for the public API.
"""

from .intake import (
    AuthorityIntake,
    AuthoritativeIntake,
    ChannelIdentity,
    ChannelPolicy,
    IntakeError,
    SCHEMA_VERSION,
    RECEIPT_SCHEMA_VERSION,
    atomic_quarantine,
)

__all__ = [
    "AuthorityIntake",
    "AuthoritativeIntake",
    "ChannelIdentity",
    "ChannelPolicy",
    "IntakeError",
    "SCHEMA_VERSION",
    "RECEIPT_SCHEMA_VERSION",
    "atomic_quarantine",
]
