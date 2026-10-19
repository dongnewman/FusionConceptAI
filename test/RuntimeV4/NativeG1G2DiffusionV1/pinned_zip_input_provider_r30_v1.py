"""Strict, read-only input provider for the private R30 replay lane.

The provider presents exact pinned files from either the live checkout or a
frozen ZIP member. ZIP-backed files remain physically absent from the checkout:
only read operations are virtualized. It never extracts, restores, or writes
input files.
"""

from __future__ import annotations

import hashlib
import io
import json
import os
import stat
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Mapping


SCHEMA = "native-g1g2-r30-pinned-zip-input-provider-v1"
ARCHIVE_CONTRACT_KEY = "archive_input_provider"


class PinnedInputError(RuntimeError):
    """A workspace or archive input no longer matches its frozen identity."""


@dataclass(frozen=True)
class InputPin:
    path: str
    byte_count: int
    sha256: str


@dataclass(frozen=True)
class InputRow:
    path: str
    byte_count: int
    sha256: str
    source: str

    def as_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "bytes": self.byte_count,
            "sha256": self.sha256,
            "source": self.source,
        }


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _hash_file(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    total = 0
    with path.open("rb") as stream:
        while True:
            block = stream.read(1024 * 1024)
            if not block:
                break
            total += len(block)
            digest.update(block)
    return total, digest.hexdigest()


def _safe_logical_path(value: Any) -> str:
    if type(value) is not str or not value or "\\" in value or "\x00" in value:
        raise PinnedInputError("input path must be a nonempty POSIX logical path")
    logical = PurePosixPath(value)
    if logical.is_absolute() or any(part in ("", ".", "..") for part in logical.parts):
        raise PinnedInputError(f"unsafe logical input path: {value!r}")
    if logical.as_posix() != value:
        raise PinnedInputError(f"input path is not canonical POSIX form: {value!r}")
    return value


def _checked_sha(value: Any, label: str) -> str:
    if type(value) is not str or len(value) != 64 or any(
            ch not in "0123456789abcdef" for ch in value):
        raise PinnedInputError(f"{label} must be a lowercase SHA-256 hex digest")
    return value


class PinnedZipInputProvider:
    """Read pinned inputs without materializing archive-backed workspace paths.

    Protocol shape consumed here::

        {
          "input_pins": [{"path": ..., "bytes": ..., "sha256": ...}, ...],
          "archive_input_provider": {
            "schema": "native-g1g2-r30-archive-input-provider-v1",
            "path": "...zip",
            "bytes": ...,
            "sha256": "...",
            "zip_member_paths": ["docs/...", ...]
          }
        }

    The ordered `zip_member_paths` field is the explicit source-class map. The
    provider never reclassifies a missing local file as ZIP-backed after
    construction.
    """

    def __init__(self, protocol: Mapping[str, Any], repo_root: Path,
                 archive_path: Path | None = None) -> None:
        if not isinstance(protocol, Mapping):
            raise PinnedInputError("protocol must be a mapping")
        raw_pins = protocol.get("input_pins")
        if type(raw_pins) is not list or not raw_pins:
            raise PinnedInputError("protocol input_pins must be a nonempty list")
        archive_contract = protocol.get(ARCHIVE_CONTRACT_KEY)
        if not isinstance(archive_contract, Mapping) or \
                archive_contract.get("schema") != "native-g1g2-r30-archive-input-provider-v1":
            raise PinnedInputError("R30 archive input-provider contract is missing")

        repo_candidate = Path(repo_root)
        if repo_candidate.is_symlink():
            raise PinnedInputError("repository root must not be a symlink")
        try:
            self.repo_root = repo_candidate.resolve(strict=True)
        except OSError as exc:
            raise PinnedInputError(f"repository root is unavailable: {exc}") from exc
        if not self.repo_root.is_dir():
            raise PinnedInputError("repository root is not a directory")

        protocol_archive_path = archive_contract.get("path")
        if type(protocol_archive_path) is not str or not protocol_archive_path or \
                not Path(protocol_archive_path).is_absolute():
            raise PinnedInputError("archive path must be absolute in the frozen provider contract")
        archive_candidate = Path(protocol_archive_path)
        if archive_candidate.is_symlink():
            raise PinnedInputError("pinned archive path must not be a symlink")
        if not archive_candidate.is_file():
            raise PinnedInputError("pinned archive is missing or is not a regular file")
        if archive_path is not None:
            supplied_archive_path = Path(archive_path)
            if supplied_archive_path.is_symlink():
                raise PinnedInputError("supplied archive path must not be a symlink")
            try:
                supplied_resolved = supplied_archive_path.resolve(strict=True)
                protocol_resolved = archive_candidate.resolve(strict=True)
            except OSError as exc:
                raise PinnedInputError(f"pinned archive path could not be resolved: {exc}") from exc
            if supplied_resolved != protocol_resolved:
                raise PinnedInputError("supplied archive path differs from frozen protocol path")
        try:
            self.archive_path = archive_candidate.resolve(strict=True)
        except OSError as exc:
            raise PinnedInputError(f"pinned archive path could not be resolved: {exc}") from exc
        if not self.archive_path.is_file():
            raise PinnedInputError("pinned archive must be a regular non-symlink file")
        self.archive_bytes = archive_contract.get("bytes")
        if type(self.archive_bytes) is not int or self.archive_bytes <= 0:
            raise PinnedInputError("archive byte count is malformed")
        self.archive_sha256 = _checked_sha(archive_contract.get("sha256"), "archive SHA")

        raw_zip_paths = archive_contract.get("zip_member_paths")
        if type(raw_zip_paths) is not list or not raw_zip_paths:
            raise PinnedInputError("zip_member_paths must be a nonempty ordered list")
        zip_paths = tuple(_safe_logical_path(item) for item in raw_zip_paths)
        if len(set(zip_paths)) != len(zip_paths):
            raise PinnedInputError("zip_member_paths contains duplicate logical paths")
        if tuple(sorted(zip_paths)) != zip_paths:
            raise PinnedInputError("zip_member_paths must be sorted by canonical logical path")
        self.zip_member_paths = zip_paths
        self._zip_path_set = frozenset(zip_paths)

        pins: dict[str, InputPin] = {}
        for row in raw_pins:
            if not isinstance(row, Mapping):
                raise PinnedInputError("input pin row must be a mapping")
            logical = _safe_logical_path(row.get("path"))
            byte_count = row.get("bytes")
            if type(byte_count) is not int or byte_count < 0:
                raise PinnedInputError(f"pinned byte count is malformed: {logical}")
            if logical in pins:
                raise PinnedInputError(f"duplicate input pin: {logical}")
            pins[logical] = InputPin(logical, byte_count, _checked_sha(row.get("sha256"), logical))
        if set(zip_paths) - set(pins):
            raise PinnedInputError("archive source map refers to an unpinned logical path")
        self._pins = pins

        self._rows: dict[str, InputRow] = {}
        for logical, pin in pins.items():
            physical = self._physical_path(logical)
            if logical in self._zip_path_set:
                self._require_absent_physical(physical, logical)
                self._rows[logical] = InputRow(logical, pin.byte_count, pin.sha256, "zip_member")
            else:
                self._require_workspace_file(physical, logical)
                current_size, current_sha = _hash_file(physical)
                self._require_pin_match(pin, current_size, current_sha, "workspace")
                self._rows[logical] = InputRow(logical, pin.byte_count, pin.sha256, "workspace")

        self._verify_archive_identity()
        self._verify_zip_index()
        # Validate every selected ZIP entry once at construction. Reading to EOF
        # lets zipfile check the member CRC; the content SHA/length are checked
        # independently against the frozen pin.
        for logical in self.zip_member_paths:
            self._read_zip_member(logical)
        self._verify_archive_identity()

    @classmethod
    def from_protocol(cls, protocol: Mapping[str, Any], repo_root: Path,
                      archive_path: Path | None = None) -> "PinnedZipInputProvider":
        return cls(protocol, repo_root, archive_path)

    def _physical_path(self, logical: str) -> Path:
        parts = PurePosixPath(logical).parts
        candidate = self.repo_root.joinpath(*parts)
        # Resolve without requiring the leaf to exist, and reject both explicit
        # symlink components and a canonical path that escapes the checkout.
        current = self.repo_root
        for part in parts:
            current = current / part
            if current.is_symlink():
                raise PinnedInputError(f"symlink in pinned input path: {logical}")
        resolved = candidate.resolve(strict=False)
        try:
            resolved.relative_to(self.repo_root)
        except ValueError as exc:
            raise PinnedInputError(f"pinned input path escapes repository: {logical}") from exc
        return candidate

    @staticmethod
    def _require_absent_physical(path: Path, logical: str) -> None:
        if path.is_symlink() or path.exists():
            raise PinnedInputError(
                f"ZIP-backed logical input must remain physically absent: {logical}")

    @staticmethod
    def _require_workspace_file(path: Path, logical: str) -> None:
        if path.is_symlink() or not path.is_file():
            raise PinnedInputError(
                f"workspace-backed logical input is absent or not a regular file: {logical}")

    @staticmethod
    def _require_pin_match(pin: InputPin, byte_count: int, sha256: str,
                           source: str) -> None:
        if byte_count != pin.byte_count or sha256 != pin.sha256:
            raise PinnedInputError(
                f"{source} input differs from frozen pin: {pin.path}; "
                f"expected {pin.byte_count}/{pin.sha256}, observed {byte_count}/{sha256}")

    def _verify_archive_identity(self) -> dict[str, Any]:
        if self.archive_path.is_symlink() or not self.archive_path.is_file():
            raise PinnedInputError("pinned archive stopped being a regular non-symlink file")
        actual_bytes, actual_sha = _hash_file(self.archive_path)
        if actual_bytes != self.archive_bytes or actual_sha != self.archive_sha256:
            raise PinnedInputError(
                "frozen input archive identity changed: "
                f"expected {self.archive_bytes}/{self.archive_sha256}, "
                f"observed {actual_bytes}/{actual_sha}")
        return {"path": str(self.archive_path), "bytes": actual_bytes, "sha256": actual_sha}

    @staticmethod
    def _is_regular_zip_file(info: zipfile.ZipInfo) -> bool:
        if info.is_dir():
            return False
        mode = (info.external_attr >> 16) & 0xFFFF
        file_type = stat.S_IFMT(mode)
        return file_type in (0, stat.S_IFREG)

    def _verify_zip_index(self) -> None:
        try:
            with zipfile.ZipFile(self.archive_path, "r") as bundle:
                names: dict[str, list[zipfile.ZipInfo]] = {}
                aliases: dict[str, list[str]] = {}
                for info in bundle.infolist():
                    names.setdefault(info.filename, []).append(info)
                    alias = self._zip_alias_key(info.filename)
                    if alias in self._zip_path_set:
                        aliases.setdefault(alias, []).append(info.filename)
                for logical in self.zip_member_paths:
                    matches = names.get(logical, [])
                    if len(matches) != 1:
                        raise PinnedInputError(
                            f"ZIP member must occur exactly once in central directory: {logical}")
                    if _safe_logical_path(matches[0].filename) != logical:
                        raise PinnedInputError(f"ZIP member path is not canonical: {logical}")
                    if not self._is_regular_zip_file(matches[0]):
                        raise PinnedInputError(f"ZIP member is not a regular file: {logical}")
                    if aliases.get(logical, []) != [logical]:
                        raise PinnedInputError(
                            f"ZIP member has a duplicate or aliased central-directory name: {logical}")
                    pin = self._pins[logical]
                    if matches[0].file_size != pin.byte_count:
                        raise PinnedInputError(f"ZIP member length differs from pin: {logical}")
        except zipfile.BadZipFile as exc:
            raise PinnedInputError(f"pinned input archive is not a valid ZIP: {exc}") from exc

    @staticmethod
    def _zip_alias_key(name: str) -> str | None:
        """Return a safe slash-normalized alias key for ZIP collision checks."""
        if not name or name.startswith("/") or "\x00" in name:
            return None
        parts: list[str] = []
        for component in name.replace("\\", "/").split("/"):
            if component in ("", "."):
                continue
            if component == "..":
                if not parts:
                    return None
                parts.pop()
            else:
                parts.append(component)
        return "/".join(parts) if parts else None

    def _read_zip_member(self, logical: str) -> bytes:
        if logical not in self._zip_path_set:
            raise PinnedInputError(f"logical input is not ZIP-backed: {logical}")
        path = self._physical_path(logical)
        self._require_absent_physical(path, logical)
        pin = self._pins[logical]
        try:
            with zipfile.ZipFile(self.archive_path, "r") as bundle:
                matches = [info for info in bundle.infolist() if info.filename == logical]
                if len(matches) != 1:
                    raise PinnedInputError(
                        f"ZIP member must occur exactly once in central directory: {logical}")
                info = matches[0]
                if not self._is_regular_zip_file(info) or info.file_size != pin.byte_count:
                    raise PinnedInputError(f"ZIP member metadata differs from pin: {logical}")
                digest = hashlib.sha256()
                chunks: list[bytes] = []
                total = 0
                with bundle.open(info, "r") as stream:
                    while True:
                        # At most one byte beyond the pin is read so a bad size
                        # declaration cannot expand into unbounded memory.
                        remaining = pin.byte_count - total
                        block = stream.read(min(64 * 1024, max(1, remaining + 1)))
                        if not block:
                            break
                        total += len(block)
                        if total > pin.byte_count:
                            raise PinnedInputError(f"ZIP member exceeds pinned length: {logical}")
                        digest.update(block)
                        chunks.append(block)
                actual_sha = digest.hexdigest()
                self._require_pin_match(pin, total, actual_sha, "ZIP")
                data = b"".join(chunks)
        except (zipfile.BadZipFile, zipfile.LargeZipFile, OSError, EOFError) as exc:
            if isinstance(exc, PinnedInputError):
                raise
            raise PinnedInputError(f"ZIP member read/CRC failure for {logical}: {exc}") from exc
        # Recheck absence after the read to prevent a concurrent restoration
        # from silently changing the physical/virtual source classification.
        self._require_absent_physical(path, logical)
        return data

    def _read_workspace_file(self, logical: str) -> bytes:
        path = self._physical_path(logical)
        self._require_workspace_file(path, logical)
        data = path.read_bytes()
        pin = self._pins[logical]
        self._require_pin_match(pin, len(data), _sha256(data), "workspace")
        return data

    def read_bytes(self, logical_path: str) -> bytes:
        logical = _safe_logical_path(logical_path)
        if logical not in self._pins:
            raise PinnedInputError(f"read requested for an unpinned logical input: {logical}")
        if logical in self._zip_path_set:
            return self._read_zip_member(logical)
        return self._read_workspace_file(logical)

    def read_text(self, logical_path: str, encoding: str = "utf-8",
                  errors: str = "strict") -> str:
        raw = self.read_bytes(logical_path)
        with io.TextIOWrapper(io.BytesIO(raw), encoding=encoding, errors=errors,
                              newline=None) as stream:
            return stream.read()

    def read_json(self, logical_path: str) -> Any:
        return json.loads(self.read_text(logical_path, encoding="utf-8"))

    def receipt(self, logical_path: str) -> dict[str, Any]:
        logical = _safe_logical_path(logical_path)
        data = self.read_bytes(logical)
        row = self._rows[logical]
        return {"path": logical, "bytes": len(data), "sha256": _sha256(data),
                "source": row.source}

    def verify_all(self, phase: str) -> dict[str, Any]:
        if type(phase) is not str or not phase.strip():
            raise PinnedInputError("verify_all phase must be a nonempty label")
        archive_before = self._verify_archive_identity()
        rows: list[dict[str, Any]] = []
        for logical in sorted(self._pins):
            rows.append(self.receipt(logical))
        archive_after = self._verify_archive_identity()
        if archive_before != archive_after:
            raise PinnedInputError("pinned input archive changed during full verification")
        expected = [self._rows[path].as_dict() for path in sorted(self._rows)]
        if rows != expected:
            raise PinnedInputError("full input verification differs from initial source-class map")
        return {
            "schema": SCHEMA,
            "phase": phase,
            "complete": True,
            "archive": archive_after,
            "archive_before": archive_before,
            "archive_after": archive_after,
            "input_count": len(rows),
            "workspace_count": sum(row["source"] == "workspace" for row in rows),
            "zip_member_count": sum(row["source"] == "zip_member" for row in rows),
            "rows": rows,
        }

    def physical_path(self, logical_path: str) -> Path:
        """Return the physical path while preserving normal filesystem facts."""
        logical = _safe_logical_path(logical_path)
        if logical not in self._pins:
            raise PinnedInputError(f"path requested for an unpinned input: {logical}")
        return self._physical_path(logical)

    def repo_path_adapter(self, original_repo_path: Any) -> Any:
        """Build a module-local repo_path adapter for direct Python readers.

        Only ZIP-backed logical paths receive a read-through wrapper. `exists`,
        `is_file`, `stat`, `resolve`, and `__fspath__` continue to describe the
        physical checkout; in particular, absent archive files stay absent.
        """
        def adapted(relative: str) -> Any:
            physical = original_repo_path(relative)
            try:
                logical = _safe_logical_path(relative)
            except PinnedInputError:
                return physical
            if logical in self._zip_path_set:
                return _ReadThroughPinnedPath(physical, self, logical)
            return physical
        return adapted


class _ReadThroughPinnedPath:
    """Path-shaped read adapter that never virtualizes existence or writes."""

    __slots__ = ("_path", "_provider", "_logical")

    def __init__(self, path: Path, provider: PinnedZipInputProvider,
                 logical: str) -> None:
        self._path = path
        self._provider = provider
        self._logical = logical

    def __fspath__(self) -> str:
        return os.fspath(self._path)

    def __str__(self) -> str:
        return str(self._path)

    def __repr__(self) -> str:
        return repr(self._path)

    def __getattr__(self, name: str) -> Any:
        if name in {
            "write_bytes", "write_text", "touch", "unlink", "mkdir", "rmdir",
            "rename", "replace", "symlink_to", "hardlink_to", "chmod", "lchmod",
        }:
            def reject_write(*args: Any, **kwargs: Any) -> Any:
                raise PinnedInputError("archive-backed path is read-only")
            return reject_write
        return getattr(self._path, name)

    def exists(self) -> bool:
        return self._path.exists()

    def is_file(self) -> bool:
        return self._path.is_file()

    def is_symlink(self) -> bool:
        return self._path.is_symlink()

    def resolve(self, strict: bool = False) -> Path:
        return self._path.resolve(strict=strict)

    def stat(self, *, follow_symlinks: bool = True) -> os.stat_result:
        return self._path.stat(follow_symlinks=follow_symlinks)

    def read_bytes(self) -> bytes:
        return self._provider.read_bytes(self._logical)

    def read_text(self, encoding: str | None = None,
                  errors: str | None = None) -> str:
        raw = self.read_bytes()
        with io.TextIOWrapper(io.BytesIO(raw), encoding=encoding or "utf-8",
                              errors=errors or "strict", newline=None) as stream:
            return stream.read()

    def open(self, mode: str = "r", buffering: int = -1,
             encoding: str | None = None, errors: str | None = None,
             newline: str | None = None) -> Any:
        if mode not in ("r", "rt", "rb") or buffering not in (-1, 0, 1):
            raise PinnedInputError("archive-backed path permits read-only open modes")
        raw = self.read_bytes()
        if mode == "rb":
            return io.BytesIO(raw)
        return io.TextIOWrapper(io.BytesIO(raw), encoding=encoding or "utf-8",
                                errors=errors or "strict", newline=newline)
