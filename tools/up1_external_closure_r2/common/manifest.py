"""Exact-set and hash validation for small local artifact trees."""

from __future__ import annotations

import hashlib
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping

from .files import MAX_FILE_BYTES, SafeFileError, read_bytes_limited, safe_relative_path
from .taxonomy import ErrorCode, EvidenceError, TypedError


class ManifestError(EvidenceError):
    pass


@dataclass(frozen=True)
class ManifestCheck:
    ok: bool
    declared: tuple[str, ...]
    actual: tuple[str, ...]
    missing: tuple[str, ...]
    unexpected: tuple[str, ...]
    mismatched: tuple[str, ...]
    errors: tuple[TypedError, ...] = ()

    def as_dict(self) -> dict[str, Any]:
        return {
            "ok": self.ok,
            "declared": list(self.declared),
            "actual": list(self.actual),
            "missing": list(self.missing),
            "unexpected": list(self.unexpected),
            "mismatched": list(self.mismatched),
            "errors": [error.as_dict() for error in self.errors],
        }


def _actual_files(root: Path) -> dict[str, Path]:
    if root.is_symlink() or not root.is_dir():
        raise ManifestError(TypedError(ErrorCode.PATH_NOT_FILE.value, "manifest root must be a real directory", str(root)))
    result: dict[str, Path] = {}
    for current, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(dirs)
        for directory in dirs:
            if (Path(current) / directory).is_symlink():
                raise ManifestError(TypedError(ErrorCode.SYMLINK_REJECTED.value, "symlink directory is not allowed", str(Path(current) / directory)))
        for name in sorted(files):
            full = Path(current) / name
            if full.is_symlink():
                raise ManifestError(TypedError(ErrorCode.SYMLINK_REJECTED.value, "symlink file is not allowed", str(full)))
            rel = safe_relative_path(full.relative_to(root).as_posix())
            result[rel] = full
    return result


def _declared_items(expected: Mapping[str, Any] | Iterable[str]) -> tuple[dict[str, str | None], list[TypedError]]:
    result: dict[str, str | None] = {}
    errors: list[TypedError] = []
    if isinstance(expected, (str, bytes, bytearray)):
        return {}, [TypedError(ErrorCode.MANIFEST_MALFORMED.value, "bare string is not an exact-set manifest")]
    if isinstance(expected, Mapping):
        items = expected.items()
    else:
        def expanded():
            for value in expected:
                if isinstance(value, Mapping):
                    yield value.get("path"), value.get("sha256", value.get("hash"))
                else:
                    yield None, None
        items = expanded()
    for raw_path, raw_hash in items:
        try:
            path = safe_relative_path(raw_path)
        except (TypeError, SafeFileError) as exc:
            errors.append(exc.error if isinstance(exc, EvidenceError) else TypedError(ErrorCode.PATH_ESCAPE.value, str(exc)))
            continue
        if path in result:
            errors.append(TypedError(ErrorCode.MANIFEST_DUPLICATE_PATH.value, "duplicate manifest path", path))
            continue
        digest: str | None
        if raw_hash is None:
            digest = None
        elif isinstance(raw_hash, str):
            digest = raw_hash.lower()
        elif isinstance(raw_hash, Mapping) and isinstance(raw_hash.get("sha256"), str):
            digest = raw_hash["sha256"].lower()
        else:
            digest = None
            errors.append(TypedError(ErrorCode.MANIFEST_MALFORMED.value, "manifest hash must be sha256 text", path))
        if digest is not None and (len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest)):
            errors.append(TypedError(ErrorCode.MANIFEST_MALFORMED.value, "manifest hash is not lowercase/hex SHA-256", path))
        result[path] = digest
    return result, errors


def verify_exact_set(
    root: str | os.PathLike[str],
    expected: Mapping[str, Any] | Iterable[str],
    *,
    exclude: Iterable[str] = (),
    max_bytes: int = MAX_FILE_BYTES,
) -> ManifestCheck:
    """Check that root contains exactly declared paths and matching hashes.

    ``expected`` may map relative POSIX paths to SHA-256 strings (or objects
    containing ``sha256``), or be an iterable of path records. Bare strings
    are rejected to prevent accidental character-wise under-declaration.
    Exclusions are explicit and normalized.
    """
    root_path = Path(root)
    actual_map = _actual_files(root_path)
    excluded = {safe_relative_path(item) for item in exclude}
    actual_map = {path: full for path, full in actual_map.items() if path not in excluded}
    declared_map, errors = _declared_items(expected)
    declared_map = {path: digest for path, digest in declared_map.items() if path not in excluded}
    declared = tuple(sorted(declared_map))
    actual = tuple(sorted(actual_map))
    missing = tuple(sorted(set(declared) - set(actual)))
    unexpected = tuple(sorted(set(actual) - set(declared)))
    mismatched: list[str] = []
    for path in sorted(set(declared) & set(actual)):
        digest = declared_map[path]
        if digest is None:
            continue
        try:
            observed = hashlib.sha256(read_bytes_limited(actual_map[path], max_bytes=max_bytes)).hexdigest()
        except SafeFileError as exc:
            errors.append(exc.error)
            continue
        if observed != digest:
            mismatched.append(path)
            errors.append(TypedError(ErrorCode.MANIFEST_HASH_MISMATCH.value, "SHA-256 mismatch", path, {"expected": digest, "actual": observed}))
    if missing:
        errors.append(TypedError(ErrorCode.MANIFEST_MISSING.value, "declared paths are absent", details={"paths": list(missing)}))
    if unexpected:
        errors.append(TypedError(ErrorCode.MANIFEST_UNEXPECTED.value, "undeclared files are present", details={"paths": list(unexpected)}))
    return ManifestCheck(not errors and not missing and not unexpected and not mismatched, declared, actual, missing, unexpected, tuple(mismatched), tuple(errors))


def verify_manifest(
    root: str | os.PathLike[str],
    manifest: Mapping[str, Any],
    *,
    manifest_path: str = "manifest.json",
    max_bytes: int = MAX_FILE_BYTES,
) -> ManifestCheck:
    """Verify the common ``files``/``exact_set`` manifest shapes."""
    if not isinstance(manifest, Mapping):
        raise ManifestError(TypedError(ErrorCode.MANIFEST_MALFORMED.value, "manifest must be an object"))
    declared = manifest.get("files", manifest.get("exact_set"))
    if declared is None:
        raise ManifestError(TypedError(ErrorCode.MANIFEST_MALFORMED.value, "manifest requires files or exact_set"))
    excluded = manifest.get("exclude", [manifest_path])
    if not isinstance(excluded, (list, tuple)):
        raise ManifestError(TypedError(ErrorCode.MANIFEST_MALFORMED.value, "manifest exclude must be an array"))
    return verify_exact_set(root, declared, exclude=excluded, max_bytes=max_bytes)


check_exact_set = verify_exact_set
