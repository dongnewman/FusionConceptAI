"""Read explicitly pinned historical source snapshots from a ZIP archive.

This module deliberately has no workspace-path fallback and never extracts
archive members. Current sources remain the caller's responsibility; this
reader only serves an exact ``(logical_path, snapshot_id)`` pair from a
hash-pinned index and archive.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import stat
import unicodedata
import zipfile
import zlib
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path, PurePosixPath, PureWindowsPath
from typing import Any, BinaryIO


INDEX_SCHEMA = "fusion-workspace-historical-source-index-v1"
_INDEX_KEYS = {"schema", "archive", "entries"}
_ARCHIVE_KEYS = {"path", "bytes", "sha256"}
_ENTRY_KEYS = {
    "logical_path",
    "snapshot_id",
    "archive_member",
    "bytes",
    "sha256",
    "zip_crc32",
    "origin_receipt",
}
_ORIGIN_KEYS = {"path", "bytes", "sha256"}
_HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_SNAPSHOT_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_CHUNK_BYTES = 1024 * 1024
_FILE_ATTRIBUTE_REPARSE_POINT = 0x0400


class HistoricalSourceError(ValueError):
    """The pinned index, archive, or requested historical snapshot is invalid."""


def _fail(message: str) -> None:
    raise HistoricalSourceError(message)


def _reject_json_constant(value: str) -> None:
    _fail(f"non-finite JSON value is forbidden: {value}")


def _object_without_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            _fail(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _load_json_bytes(data: bytes, label: str) -> Any:
    try:
        return json.loads(
            data.decode("utf-8", errors="strict"),
            object_pairs_hook=_object_without_duplicate_keys,
            parse_constant=_reject_json_constant,
        )
    except HistoricalSourceError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError, RecursionError) as exc:
        raise HistoricalSourceError(f"invalid UTF-8 JSON in {label}") from exc


def _require_object(value: Any, keys: set[str], label: str) -> dict[str, Any]:
    if type(value) is not dict or set(value) != keys:
        _fail(f"{label} must contain exactly the declared fields")
    return value


def _require_nonnegative_int(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        _fail(f"{label} must be a nonnegative integer")
    return value


def _require_sha256(value: Any, label: str) -> str:
    if not isinstance(value, str) or _HEX_SHA256.fullmatch(value) is None:
        _fail(f"{label} must be a lowercase SHA-256 hex digest")
    return value


def _canonical_posix_path(value: Any, label: str, *, directory: bool = False) -> str:
    if not isinstance(value, str) or not value or "\x00" in value:
        _fail(f"{label} must be a nonempty POSIX path")
    if "\\" in value or ":" in value or value.startswith("/"):
        _fail(f"{label} must be relative and use POSIX separators")
    if unicodedata.normalize("NFC", value) != value or \
            unicodedata.normalize("NFKC", value) != value:
        _fail(f"{label} is not Unicode-normalized")
    if any(unicodedata.category(char) == "Cs" for char in value):
        _fail(f"{label} contains an invalid Unicode surrogate")
    raw = value[:-1] if directory and value.endswith("/") else value
    if not raw or (value.endswith("/") and not directory):
        _fail(f"{label} has a noncanonical trailing separator")
    parts = raw.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        _fail(f"{label} contains an empty, dot, or parent component")
    if any(part.rstrip(" .") != part for part in parts):
        _fail(f"{label} contains a Windows-equivalent trailing dot or space")
    if any(any(char in '<>|?*' for char in part) for part in parts):
        _fail(f"{label} contains a nonportable path character")
    for part in parts:
        device_stem = part.split(".", 1)[0].upper()
        if device_stem in {"CON", "PRN", "AUX", "NUL"} or \
                re.fullmatch(r"(?:COM|LPT)[1-9]", device_stem):
            _fail(f"{label} contains a reserved Windows device component")
    pure = PurePosixPath(raw)
    if pure.is_absolute() or pure.as_posix() != raw:
        _fail(f"{label} is not canonical POSIX form")
    return value


def _path_alias_key(value: str) -> str:
    return unicodedata.normalize("NFKC", value.casefold())


def _canonical_archive_field(value: Any) -> str:
    if not isinstance(value, str) or not value or "\x00" in value:
        _fail("archive.path must be an absolute normalized path")
    if "\\" in value or unicodedata.normalize("NFC", value) != value or \
            unicodedata.normalize("NFKC", value) != value:
        _fail("archive.path must use canonical forward-slash form")
    if re.match(r"^[A-Za-z]:/", value):
        if value.startswith("//") or any(part in {".", ".."}
                                           for part in value[3:].split("/")):
            _fail("archive.path contains a noncanonical drive path")
        pure = PureWindowsPath(value)
        if not pure.is_absolute() or pure.as_posix() != value:
            _fail("archive.path must be an absolute normalized path")
    elif value.startswith("/") and not value.startswith("//"):
        pure_posix = PurePosixPath(value)
        if pure_posix.as_posix() != value or any(
                part in {".", ".."} for part in value.split("/")[1:]):
            _fail("archive.path contains a noncanonical POSIX path")
    else:
        _fail("archive.path must be absolute")
    if value.endswith("/"):
        _fail("archive.path must name a file")
    return value


def _path_has_reparse_component(path: Path) -> bool:
    for component in reversed((path, *path.parents)):
        try:
            info = component.lstat()
        except OSError as exc:
            raise HistoricalSourceError(f"cannot inspect path component: {component}") from exc
        if stat.S_ISLNK(info.st_mode) or \
                (getattr(info, "st_file_attributes", 0) &
                 _FILE_ATTRIBUTE_REPARSE_POINT):
            return True
    return False


def _stat_fingerprint(info: os.stat_result) -> tuple[int, ...]:
    return (
        int(info.st_dev),
        int(info.st_ino),
        int(info.st_size),
        int(getattr(info, "st_mtime_ns", int(info.st_mtime * 1_000_000_000))),
        int(getattr(info, "st_ctime_ns", int(info.st_ctime * 1_000_000_000))),
        int(getattr(info, "st_file_attributes", 0)),
    )


def _cross_lane_file_identity(info: os.stat_result) -> tuple[int, ...]:
    common = (
        int(info.st_dev),
        int(info.st_ino),
        int(info.st_size),
        int(getattr(info, "st_mtime_ns", int(info.st_mtime * 1_000_000_000))),
        int(getattr(info, "st_file_attributes", 0)),
    )
    if os.name == "nt":
        birthtime_ns = getattr(info, "st_birthtime_ns", None)
        if type(birthtime_ns) is not int:
            _fail("Windows source archive birthtime_ns is unavailable")
        return common + (birthtime_ns,)
    return _stat_fingerprint(info)


def _hash_stream(stream: BinaryIO) -> tuple[int, str]:
    digest = hashlib.sha256()
    byte_count = 0
    stream.seek(0)
    while True:
        block = stream.read(_CHUNK_BYTES)
        if not block:
            break
        byte_count += len(block)
        digest.update(block)
    return byte_count, digest.hexdigest()


@dataclass(frozen=True)
class _FrozenArchiveBinding:
    snapshot: Any
    snapshot_id: str
    manifest_sha256: str
    index_key: str
    index_bytes: int
    index_sha256: str
    archive_key: str
    archive_bytes: int
    archive_sha256: str
    original_archive_path: str
    index_path: Path
    archive_path: Path

    def verify_locations(self, *, full: bool = False) -> None:
        """Check the authorized frozen paths, never the original ZIP location."""
        snap = self.snapshot
        if snap.snapshot_id != self.snapshot_id or \
                snap.inventory_root_sha256 != self.snapshot_id or \
                snap.manifest_sha256 != self.manifest_sha256:
            _fail("frozen archive binding belongs to a different source generation")
        if full:
            snap.verify_all()
        manifest = Path(snap.root) / "manifest.toml"
        if _path_has_reparse_component(manifest) or \
                hashlib.sha256(manifest.read_bytes()).hexdigest() != self.manifest_sha256:
            _fail("frozen archive manifest no longer matches the authorized digest")
        index = snap.entries.get(self.index_key)
        archive = snap.external_archives.get(self.archive_key)
        if not isinstance(index, Mapping) or not isinstance(archive, Mapping) or \
                (index.get("bytes"), index.get("sha256")) != \
                (self.index_bytes, self.index_sha256) or \
                (archive.get("bytes"), archive.get("sha256")) != \
                (self.archive_bytes, self.archive_sha256):
            _fail("frozen archive membership changed after authorization")
        root = Path(snap.root)
        if root / index.get("frozen_path", "") != self.index_path or \
                root / archive.get("frozen_path", "") != self.archive_path:
            _fail("frozen archive paths changed after authorization")
        origin = Path(archive.get("origin_path", "")).as_posix()
        if origin != self.original_archive_path:
            _fail("frozen archive origin differs from the unchanged historical index")
        for path in (self.index_path, self.archive_path):
            if _path_has_reparse_component(path):
                _fail("frozen archive binding traverses a reparse point")
            path.relative_to(root)
            if not stat.S_ISREG(path.stat().st_mode) or path.stat().st_nlink != 1:
                _fail("frozen archive binding is not an exclusive regular file")


class HistoricalSourceReader:
    """Access a hash-pinned historical source by its exact snapshot identity.

    ``archive_path`` must be supplied explicitly and resolve to the absolute
    location bound into the index.  Snapshot ids are mandatory for every read;
    this class never looks at a same-named workspace file.
    """

    def __init__(self, index_path: str | os.PathLike[str],
                 index_sha256: str,
                 archive_path: str | os.PathLike[str], *,
                 strict_subset: bool = False) -> None:
        self._initialize(index_path, index_sha256, archive_path,
                         strict_subset=strict_subset, frozen_binding=None)

    @classmethod
    def from_frozen_snapshot(
            cls, snapshot: Any, index_logical_path: str,
            expected_index_sha256: str, archive_logical_path: str, *,
            expected_snapshot_id: str, expected_manifest_sha256: str,
            strict_subset: bool = False) -> HistoricalSourceReader:
        """Bind an unchanged historical index to its copied ZIP in one snapshot.

        The two source-generation digests must come from the authorized outer
        protocol. Historical per-member snapshot ids remain independent.
        ``archive.path`` is retained as provenance; no original path is opened.
        """
        snapshot_id = _require_sha256(expected_snapshot_id, "expected_snapshot_id")
        manifest_sha = _require_sha256(expected_manifest_sha256,
                                       "expected_manifest_sha256")
        index_sha = _require_sha256(expected_index_sha256, "expected_index_sha256")
        index_key = _canonical_posix_path(index_logical_path, "index_logical_path")
        archive_key = _canonical_posix_path(archive_logical_path, "archive_logical_path")
        if snapshot.manifest_sha256 != manifest_sha or \
                snapshot.snapshot_id != snapshot_id or \
                snapshot.inventory_root_sha256 != snapshot_id:
            _fail("frozen archive source generation is not authorized")
        snapshot.verify_all()
        index_row = snapshot.entries.get(index_key)
        archive_row = snapshot.external_archives.get(archive_key)
        if not isinstance(index_row, Mapping) or index_row.get("sha256") != index_sha:
            _fail("historical index is not a declared frozen input")
        if not isinstance(archive_row, Mapping) or \
                archive_row.get("kind") != "external_archive":
            _fail("historical ZIP is not a declared external archive")
        frozen_key = _canonical_posix_path(archive_row.get("frozen_path"),
                                           "frozen archive path")
        if not frozen_key.startswith("_archives/") or len(frozen_key.split("/")) != 2:
            _fail("historical ZIP must be inside the frozen archive directory")
        index_bytes = _require_nonnegative_int(index_row.get("bytes"), "frozen index bytes")
        archive_bytes = _require_nonnegative_int(archive_row.get("bytes"), "frozen ZIP bytes")
        archive_sha = _require_sha256(archive_row.get("sha256"), "frozen ZIP SHA-256")
        index_path = snapshot.resolve(index_key, index_bytes, index_sha)
        archive_path = snapshot.resolve(archive_key, archive_bytes, archive_sha)
        document = _load_json_bytes(snapshot.read_bytes(index_key, index_bytes, index_sha),
                                    "frozen historical-source index")
        document = _require_object(document, _INDEX_KEYS, "index")
        archive = _require_object(document.get("archive"), _ARCHIVE_KEYS, "archive")
        original_path = _canonical_archive_field(archive["path"])
        if (archive["bytes"], archive["sha256"]) != (archive_bytes, archive_sha) or \
                Path(archive_row.get("origin_path", "")).as_posix() != original_path:
            _fail("frozen ZIP does not preserve the original whole-archive receipt")
        binding = _FrozenArchiveBinding(
            snapshot, snapshot_id, manifest_sha, index_key, index_bytes, index_sha,
            archive_key, archive_bytes, archive_sha, original_path,
            Path(index_path), Path(archive_path))
        binding.verify_locations()
        reader = cls.__new__(cls)
        reader._initialize(index_path, index_sha, archive_path,
                           strict_subset=strict_subset, frozen_binding=binding)
        return reader

    def _initialize(self, index_path: str | os.PathLike[str], index_sha256: str,
                    archive_path: str | os.PathLike[str], *, strict_subset: bool,
                    frozen_binding: _FrozenArchiveBinding | None) -> None:
        if type(strict_subset) is not bool:
            _fail("strict_subset must be a boolean")
        self._frozen_binding = frozen_binding
        self._strict_subset = strict_subset
        self._index_path = self._resolve_local_regular_file(
            index_path, "index", require_absolute=False)
        self._index_sha256 = _require_sha256(index_sha256, "index_sha256")
        self._index_fingerprint: tuple[int, ...] | None = None
        self._archive_path = self._resolve_local_regular_file(
            archive_path, "archive", require_absolute=True)
        self._archive_path_posix = self._archive_path.as_posix()
        self._index, self._entries = self._read_and_validate_index()
        archive = self._index["archive"]
        if frozen_binding is None:
            if archive["path"] != self._archive_path_posix:
                _fail("explicit archive_path does not match the pinned archive path")
        else:
            frozen_binding.verify_locations()
            if self._index_path != frozen_binding.index_path or \
                    self._archive_path != frozen_binding.archive_path or \
                    self._index_sha256 != frozen_binding.index_sha256 or \
                    (archive["path"], archive["bytes"], archive["sha256"]) != \
                    (frozen_binding.original_archive_path,
                     frozen_binding.archive_bytes, frozen_binding.archive_sha256):
                _fail("historical reader does not match its frozen archive binding")
        self._archive_bytes = archive["bytes"]
        self._archive_sha256 = archive["sha256"]
        self._archive_file: BinaryIO | None = None
        self._zip: zipfile.ZipFile | None = None
        self._archive_fd_fingerprint: tuple[int, ...] | None = None
        self._archive_path_fingerprint: tuple[int, ...] | None = None
        self._members: dict[str, zipfile.ZipInfo] = {}
        self._entered = False
        self._closed = False

    @staticmethod
    def _resolve_local_regular_file(path_value: str | os.PathLike[str],
                                   label: str, *,
                                   require_absolute: bool) -> Path:
        try:
            raw = os.fspath(path_value)
            if not isinstance(raw, str) or not raw or "\x00" in raw:
                _fail(f"{label} path must be a nonempty filesystem path")
            if any(part in {".", ".."} for part in re.split(r"[\\/]", raw)):
                _fail(f"{label} path contains a dot or parent component")
            path = Path(raw)
            if require_absolute and not path.is_absolute():
                _fail(f"{label} path must be absolute")
            absolute_input = path if path.is_absolute() else Path.cwd() / path
            absolute_input = Path(os.path.abspath(absolute_input))
            if _path_has_reparse_component(absolute_input):
                _fail(f"{label} path traverses a symlink or reparse point")
            resolved = absolute_input.resolve(strict=True)
            info = resolved.stat()
            if not stat.S_ISREG(info.st_mode):
                _fail(f"{label} path must name a regular file")
            return resolved
        except HistoricalSourceError:
            raise
        except (OSError, TypeError, ValueError) as exc:
            raise HistoricalSourceError(f"cannot resolve {label} path") from exc

    def _read_and_validate_index(self) -> tuple[dict[str, Any],
                                                   dict[tuple[str, str], dict[str, Any]]]:
        try:
            before = self._index_path.stat()
            data = self._index_path.read_bytes()
            after = self._index_path.stat()
        except OSError as exc:
            raise HistoricalSourceError("cannot read historical-source index") from exc
        if _stat_fingerprint(before) != _stat_fingerprint(after):
            _fail("historical-source index changed while being read")
        if hashlib.sha256(data).hexdigest() != self._index_sha256:
            _fail("historical-source index SHA-256 mismatch")
        self._index_fingerprint = _stat_fingerprint(after)
        index = _load_json_bytes(data, "historical-source index")
        index_obj = _require_object(index, _INDEX_KEYS, "index")
        if index_obj["schema"] != INDEX_SCHEMA:
            _fail("historical-source index schema mismatch")

        archive_obj = _require_object(index_obj["archive"], _ARCHIVE_KEYS,
                                      "archive")
        archive_path = _canonical_archive_field(archive_obj["path"])
        archive_bytes = _require_nonnegative_int(archive_obj["bytes"],
                                                 "archive.bytes")
        archive_sha = _require_sha256(archive_obj["sha256"],
                                      "archive.sha256")
        index_obj["archive"] = {
            "path": archive_path,
            "bytes": archive_bytes,
            "sha256": archive_sha,
        }
        if type(index_obj["entries"]) is not list:
            _fail("index.entries must be an array")

        entries: dict[tuple[str, str], dict[str, Any]] = {}
        logical_aliases: dict[str, str] = {}
        member_aliases: dict[str, str] = {}
        snapshot_members: set[str] = set()
        for ordinal, raw_entry in enumerate(index_obj["entries"]):
            entry = _require_object(raw_entry, _ENTRY_KEYS,
                                    f"entries[{ordinal}]")
            logical = _canonical_posix_path(entry["logical_path"],
                                            f"entries[{ordinal}].logical_path")
            snapshot_id = entry["snapshot_id"]
            if not isinstance(snapshot_id, str) or \
                    _SNAPSHOT_ID.fullmatch(snapshot_id) is None:
                _fail(f"entries[{ordinal}].snapshot_id is not canonical")
            member = _canonical_posix_path(entry["archive_member"],
                                           f"entries[{ordinal}].archive_member")
            byte_count = _require_nonnegative_int(entry["bytes"],
                                                  f"entries[{ordinal}].bytes")
            sha = _require_sha256(entry["sha256"],
                                  f"entries[{ordinal}].sha256")
            crc = entry["zip_crc32"]
            if type(crc) is not int or crc < 0 or crc > 0xFFFFFFFF:
                _fail(f"entries[{ordinal}].zip_crc32 must be an unsigned 32-bit integer")
            origin = _require_object(entry["origin_receipt"], _ORIGIN_KEYS,
                                     f"entries[{ordinal}].origin_receipt")
            origin_path = _canonical_posix_path(
                origin["path"], f"entries[{ordinal}].origin_receipt.path")
            origin_bytes = _require_nonnegative_int(
                origin["bytes"], f"entries[{ordinal}].origin_receipt.bytes")
            origin_sha = _require_sha256(
                origin["sha256"], f"entries[{ordinal}].origin_receipt.sha256")
            if (origin_path, origin_bytes, origin_sha) != (logical, byte_count, sha):
                _fail(f"entries[{ordinal}] does not preserve its origin receipt")

            identity = (logical, snapshot_id)
            if identity in entries:
                _fail("duplicate (logical_path, snapshot_id) identity")
            if member in snapshot_members:
                _fail("archive_member is assigned to more than one snapshot")
            logical_alias = _path_alias_key(logical)
            prior_logical = logical_aliases.get(logical_alias)
            if prior_logical is not None and prior_logical != logical:
                _fail("logical paths have a case or Unicode alias")
            logical_aliases[logical_alias] = logical
            member_alias = _path_alias_key(member)
            prior_member = member_aliases.get(member_alias)
            if prior_member is not None and prior_member != member:
                _fail("archive members have a case or Unicode alias")
            member_aliases[member_alias] = member
            snapshot_members.add(member)
            entries[identity] = {
                "logical_path": logical,
                "snapshot_id": snapshot_id,
                "archive_member": member,
                "bytes": byte_count,
                "sha256": sha,
                "zip_crc32": crc,
                "origin_receipt": {
                    "path": origin_path,
                    "bytes": origin_bytes,
                    "sha256": origin_sha,
                },
            }
        return index_obj, entries

    def _verify_index_unchanged(self) -> None:
        if self._frozen_binding is not None:
            self._frozen_binding.verify_locations()
        try:
            before = self._index_path.stat()
            data = self._index_path.read_bytes()
            after = self._index_path.stat()
        except OSError as exc:
            raise HistoricalSourceError("historical-source index became unavailable") from exc
        if _stat_fingerprint(before) != _stat_fingerprint(after) or \
                _stat_fingerprint(after) != self._index_fingerprint or \
                hashlib.sha256(data).hexdigest() != self._index_sha256:
            _fail("historical-source index changed during the reader lifetime")

    def _verify_archive_path_identity(self) -> None:
        if self._archive_file is None or self._archive_fd_fingerprint is None or \
                self._archive_path_fingerprint is None:
            _fail("historical-source reader is not open")
        if _path_has_reparse_component(self._archive_path):
            _fail("pinned source archive path became a symlink or reparse point")
        try:
            opened = os.fstat(self._archive_file.fileno())
            current_path = self._archive_path.stat()
        except OSError as exc:
            raise HistoricalSourceError("pinned source archive became unavailable") from exc
        opened_fingerprint = _stat_fingerprint(opened)
        path_fingerprint = _stat_fingerprint(current_path)
        opened_identity = _cross_lane_file_identity(opened)
        path_identity = _cross_lane_file_identity(current_path)
        if opened_fingerprint != self._archive_fd_fingerprint or \
                path_fingerprint != self._archive_path_fingerprint or \
                opened_identity != path_identity:
            expected_fd = self._archive_fd_fingerprint
            expected_path = self._archive_path_fingerprint

            def raw_stat_fields(info: os.stat_result) -> dict[str, Any]:
                return {
                    "fingerprint": _stat_fingerprint(info),
                    "cross_lane_identity": _cross_lane_file_identity(info),
                    "tuple": tuple(info),
                    "st_mode": int(info.st_mode),
                    "st_dev": int(info.st_dev),
                    "st_ino": int(info.st_ino),
                    "st_size": int(info.st_size),
                    "st_mtime_ns": int(getattr(
                        info, "st_mtime_ns", int(info.st_mtime * 1_000_000_000))),
                    "st_ctime_ns": int(getattr(
                        info, "st_ctime_ns", int(info.st_ctime * 1_000_000_000))),
                    "st_birthtime_ns": getattr(info, "st_birthtime_ns", None),
                    "st_file_attributes": int(getattr(info, "st_file_attributes", 0)),
                    "st_reparse_tag": int(getattr(info, "st_reparse_tag", 0)),
                }

            _fail(
                "pinned source archive identity or metadata changed; "
                f"expected_fd_fingerprint={expected_fd!r}; "
                f"expected_path_fingerprint={expected_path!r}; "
                f"opened={raw_stat_fields(opened)!r}; "
                f"path={raw_stat_fields(current_path)!r}"
            )

    def _verify_archive_digest(self) -> None:
        self._verify_archive_path_identity()
        assert self._archive_file is not None
        try:
            before = os.fstat(self._archive_file.fileno())
            byte_count, digest = _hash_stream(self._archive_file)
            after = os.fstat(self._archive_file.fileno())
        except OSError as exc:
            raise HistoricalSourceError("cannot recheck pinned source archive") from exc
        if _stat_fingerprint(before) != _stat_fingerprint(after) or \
                _stat_fingerprint(after) != self._archive_fd_fingerprint or \
                byte_count != self._archive_bytes or digest != self._archive_sha256:
            _fail("pinned source archive changed or no longer matches its receipt")
        self._verify_archive_path_identity()

    def _inventory_zip_members(self) -> dict[str, zipfile.ZipInfo]:
        assert self._zip is not None
        by_name: dict[str, zipfile.ZipInfo] = {}
        aliases: dict[str, str] = {}
        try:
            infos = self._zip.infolist()
        except (OSError, zipfile.BadZipFile) as exc:
            raise HistoricalSourceError("cannot read pinned source archive directory") from exc
        for info in infos:
            original_name = getattr(info, "orig_filename", info.filename)
            if original_name != info.filename:
                _fail("ZIP member name contains a noncanonical NUL suffix")
            if info.is_dir():
                _fail("ZIP archive contains an unindexed directory entry")
            canonical_name = _canonical_posix_path(info.filename,
                                                   "ZIP member name")
            if info.filename in by_name:
                _fail("duplicate ZIP member name")
            alias = _path_alias_key(canonical_name)
            old = aliases.get(alias)
            if old is not None and old != canonical_name:
                _fail("ZIP members have a case or Unicode alias")
            aliases[alias] = canonical_name
            by_name[canonical_name] = info
        indexed_members = {entry["archive_member"]
                           for entry in self._entries.values()}
        if self._strict_subset:
            if not indexed_members or not indexed_members.issubset(by_name):
                _fail("indexed ZIP members are not a nonempty subset of the archive")
        elif set(by_name) != indexed_members:
            _fail("ZIP archive members do not exactly match the index allowlist")
        for entry in self._entries.values():
            info = by_name.get(entry["archive_member"])
            if info is None:
                _fail(f"pinned ZIP member is missing: {entry['archive_member']}")
            if info.file_size != entry["bytes"] or info.CRC != entry["zip_crc32"]:
                _fail(f"pinned ZIP member metadata mismatch: {entry['archive_member']}")
        return by_name

    @property
    def indexed_identities(self) -> frozenset[tuple[str, str]]:
        """Return the finite exact logical-path/snapshot pairs in the index."""
        return frozenset(self._entries)

    def __enter__(self) -> HistoricalSourceReader:
        if self._entered or self._closed:
            _fail("historical-source reader cannot be re-entered")
        if self._frozen_binding is not None:
            self._frozen_binding.verify_locations(full=True)
        self._verify_index_unchanged()
        try:
            path_before = self._archive_path.stat()
            if not stat.S_ISREG(path_before.st_mode):
                _fail("source archive path must name a regular file")
            archive_file = self._archive_path.open("rb")
            before = os.fstat(archive_file.fileno())
            if not stat.S_ISREG(before.st_mode):
                _fail("source archive must be a regular file")
            self._archive_file = archive_file
            byte_count, digest = _hash_stream(archive_file)
            after = os.fstat(archive_file.fileno())
            path_after = self._archive_path.stat()
            if _stat_fingerprint(before) != _stat_fingerprint(after):
                _fail("source archive changed while it was being opened")
            if _stat_fingerprint(path_before) != _stat_fingerprint(path_after):
                _fail("source archive path changed while it was being opened")
            expected_identity = _cross_lane_file_identity(after)
            if _cross_lane_file_identity(path_before) != expected_identity or \
                    _cross_lane_file_identity(path_after) != expected_identity:
                _fail("source archive path and opened file do not identify the same file")
            if byte_count != self._archive_bytes or digest != self._archive_sha256:
                _fail("source archive size or SHA-256 mismatch")
            self._archive_fd_fingerprint = _stat_fingerprint(after)
            self._archive_path_fingerprint = _stat_fingerprint(path_after)
            archive_file.seek(0)
            self._zip = zipfile.ZipFile(archive_file, mode="r")
            self._verify_archive_path_identity()
            self._members = self._inventory_zip_members()
            self._entered = True
            return self
        except HistoricalSourceError:
            self._close_after_failed_enter()
            raise
        except (OSError, zipfile.BadZipFile, ValueError) as exc:
            self._close_after_failed_enter()
            raise HistoricalSourceError("cannot open pinned source archive") from exc

    def _close_after_failed_enter(self) -> None:
        try:
            if self._zip is not None:
                self._zip.close()
        finally:
            self._zip = None
            if self._archive_file is not None:
                self._archive_file.close()
            self._archive_file = None
            self._closed = True

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> bool:
        integrity_error: BaseException | None = None
        try:
            if self._zip is not None:
                self._zip.close()
            if self._archive_file is not None:
                self._verify_archive_digest()
            self._verify_index_unchanged()
            if self._frozen_binding is not None:
                self._frozen_binding.verify_locations(full=True)
        except BaseException as check_error:
            integrity_error = check_error
        finally:
            self._zip = None
            if self._archive_file is not None:
                self._archive_file.close()
            self._archive_file = None
            self._closed = True
        if integrity_error is not None:
            raise integrity_error
        return False

    def _require_open(self) -> None:
        if not self._entered or self._closed or self._zip is None or \
                self._archive_file is None:
            _fail("historical-source reads require an active context manager")

    def _lookup(self, logical_path: str, snapshot_id: str) -> dict[str, Any]:
        self._require_open()
        logical = _canonical_posix_path(logical_path, "logical_path")
        if not isinstance(snapshot_id, str) or \
                _SNAPSHOT_ID.fullmatch(snapshot_id) is None:
            _fail("snapshot_id is required and must be canonical")
        entry = self._entries.get((logical, snapshot_id))
        if entry is None:
            _fail("no exact historical snapshot is allowlisted")
        return entry

    def read_bytes(self, logical_path: str, snapshot_id: str) -> bytes:
        """Return the exact bytes bound to one allowlisted snapshot id."""
        entry = self._lookup(logical_path, snapshot_id)
        assert self._zip is not None
        info = self._members.get(entry["archive_member"])
        if info is None:
            _fail("pinned ZIP member is unavailable")
        self._verify_archive_path_identity()
        digest = hashlib.sha256()
        crc = 0
        byte_count = 0
        content = bytearray()
        try:
            with self._zip.open(info, mode="r") as source:
                while True:
                    block = source.read(_CHUNK_BYTES)
                    if not block:
                        break
                    byte_count += len(block)
                    if byte_count > entry["bytes"]:
                        _fail("historical source exceeds its pinned size")
                    digest.update(block)
                    crc = zlib.crc32(block, crc) & 0xFFFFFFFF
                    content.extend(block)
        except HistoricalSourceError:
            raise
        except (OSError, EOFError, RuntimeError, ValueError,
                zipfile.BadZipFile, zlib.error) as exc:
            raise HistoricalSourceError("cannot read pinned ZIP member") from exc
        self._verify_archive_path_identity()
        if byte_count != entry["bytes"] or \
                digest.hexdigest() != entry["sha256"] or \
                crc != entry["zip_crc32"]:
            _fail("historical source member does not match its pinned receipt")
        return bytes(content)

    def read_text(self, logical_path: str, snapshot_id: str,
                  encoding: str = "utf-8") -> str:
        """Decode one exact snapshot; decoding errors are never replaced."""
        if not isinstance(encoding, str) or not encoding:
            _fail("encoding must be an explicit nonempty string")
        try:
            return self.read_bytes(logical_path, snapshot_id).decode(
                encoding, errors="strict")
        except HistoricalSourceError:
            raise
        except (LookupError, UnicodeDecodeError) as exc:
            raise HistoricalSourceError("historical source text decoding failed") from exc

    def read_json(self, logical_path: str, snapshot_id: str) -> Any:
        """Parse strict UTF-8 JSON and reject duplicate keys at every depth."""
        payload = self.read_bytes(logical_path, snapshot_id)
        return _load_json_bytes(payload, logical_path)
