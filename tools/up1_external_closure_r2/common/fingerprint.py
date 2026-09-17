"""Domain-separated candidate/source fingerprints."""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any, Iterable

from .canonical import CANONICALIZATION_VERSION, canonical_json_bytes
from .identity import Fingerprint, sha256_hex
from .taxonomy import ErrorCode, EvidenceError, TypedError

_IDENTITY_NAMES = frozenset({
    "fingerprint", "candidate_fingerprint", "source_fingerprint", "content_identity",
    "receipt_hash", "receipt_sha256", "canonical_input_fingerprint",
})


def _without(value: Any, excludes: set[str], path: str = "$", active: set[int] | None = None) -> Any:
    if active is None:
        active = set()
    if isinstance(value, (Mapping, list, tuple)):
        marker = id(value)
        if marker in active:
            raise EvidenceError(TypedError(ErrorCode.CYCLIC_VALUE.value, "cyclic fingerprint payload", path))
        active.add(marker)
    if isinstance(value, Mapping):
        try:
            result: dict[str, Any] = {}
            for key, item in value.items():
                if not isinstance(key, str):
                    raise EvidenceError(TypedError(ErrorCode.INVALID_FIELD.value, "fingerprint object keys must be strings", path))
                if key in _IDENTITY_NAMES and key not in excludes:
                    raise EvidenceError(TypedError(ErrorCode.SELF_REFERENCE.value, "nested identity field in fingerprint payload", f"{path}.{key}"))
                if key in excludes:
                    continue
                result[key] = _without(item, excludes, f"{path}.{key}", active)
            return result
        finally:
            active.remove(id(value))
    if isinstance(value, (list, tuple)):
        try:
            return [_without(item, excludes, f"{path}[]", active) for item in value]
        finally:
            active.remove(id(value))
    return value


def typed_fingerprint(
    payload: Any,
    *,
    domain: str,
    version: str = "v1",
    exclude_fields: Iterable[str] = (),
) -> Fingerprint:
    """Hash a domain/version tagged preimage exactly once.

    Identity fields are rejected unless explicitly listed in ``exclude_fields``;
    this makes the omission policy visible and prevents accidental self-hash.
    """
    if type(domain) is not str or not domain or type(version) is not str or not version:
        raise ValueError("domain and version must be non-empty strings")
    excludes = set(exclude_fields)
    if not excludes.issubset(_IDENTITY_NAMES):
        raise ValueError("exclude_fields may only contain known identity fields")
    clean = _without(payload, excludes)
    preimage_value = {
        "canonicalization": CANONICALIZATION_VERSION,
        "domain": domain,
        "version": version,
        "payload": clean,
    }
    preimage = canonical_json_bytes(preimage_value)
    return Fingerprint(domain, version, sha256_hex(preimage), preimage)


def candidate_fingerprint(payload: Any, *, version: str = "v1", exclude_fields: Iterable[str] = ()) -> Fingerprint:
    return typed_fingerprint(payload, domain="up1:candidate", version=version, exclude_fields=exclude_fields)


def source_fingerprint(payload: Any, *, version: str = "v1", exclude_fields: Iterable[str] = ()) -> Fingerprint:
    return typed_fingerprint(payload, domain="up1:source", version=version, exclude_fields=exclude_fields)
