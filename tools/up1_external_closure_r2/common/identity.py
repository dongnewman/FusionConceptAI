"""Content-addressed identities with no implicit time or environment input."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from typing import Any, Mapping

from .canonical import CANONICALIZATION_VERSION, canonical_json_bytes


def sha256_hex(data: bytes | bytearray | memoryview) -> str:
    return hashlib.sha256(bytes(data)).hexdigest()


def digest_bytes(data: bytes | bytearray | memoryview) -> str:
    """Alias emphasizing that the digest is over exact supplied bytes."""
    return sha256_hex(data)


def digest_json(value: Any) -> str:
    return sha256_hex(canonical_json_bytes(value))


canonical_digest = digest_json
sha256_json = digest_json


@dataclass(frozen=True)
class ContentIdentity:
    algorithm: str
    digest: str
    byte_length: int
    canonicalization: str | None = None

    def as_dict(self) -> dict[str, Any]:
        result = {
            "algorithm": self.algorithm,
            "sha256": self.digest,
            "byte_length": self.byte_length,
        }
        if self.canonicalization is not None:
            result["canonicalization"] = self.canonicalization
        return result


def content_identity(value: Any, *, canonical: bool = True) -> ContentIdentity:
    """Return a SHA-256 identity over bytes or a canonical JSON value."""
    if isinstance(value, (bytes, bytearray, memoryview)):
        data = bytes(value)
        profile = None
    else:
        data = canonical_json_bytes(value)
        profile = CANONICALIZATION_VERSION if canonical else None
    return ContentIdentity("sha256", sha256_hex(data), len(data), profile)


@dataclass(frozen=True)
class Fingerprint:
    domain: str
    version: str
    digest: str
    preimage: bytes
    canonicalization: str = CANONICALIZATION_VERSION

    def __post_init__(self) -> None:
        if type(self.domain) is not str or self.domain not in {"up1:candidate", "up1:source"}:
            raise ValueError("fingerprint domain is not a permitted UP1 domain")
        if type(self.version) is not str or not self.version:
            raise ValueError("fingerprint version must be non-empty text")
        if self.canonicalization != CANONICALIZATION_VERSION:
            raise ValueError("fingerprint canonicalization profile mismatch")
        if type(self.preimage) is not bytes:
            raise TypeError("fingerprint preimage must be bytes")
        if type(self.digest) is not str or not re.fullmatch(r"[0-9a-f]{64}", self.digest):
            raise ValueError("fingerprint digest must be lowercase SHA-256")
        if sha256_hex(self.preimage) != self.digest:
            raise ValueError("fingerprint digest does not match preimage")

    def as_dict(self) -> dict[str, Any]:
        return {
            "type": "candidate_fingerprint" if self.domain == "up1:candidate" else "source_fingerprint",
            "domain": self.domain,
            "version": self.version,
            "algorithm": "sha256",
            "digest": self.digest,
            "canonicalization": self.canonicalization,
            "preimage": self.preimage.decode("ascii"),
        }
