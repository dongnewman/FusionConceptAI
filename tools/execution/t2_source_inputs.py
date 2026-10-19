"""Explicit current-file and historical-data binding for the T2 consumer.

Historical entries are source *data*, identified by their original logical
paths. This module never imports, executes, extracts, or restores those bytes.
An absent current executable is always an error, even if an archive exists.
"""

from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tomllib
import unicodedata
from typing import Any, Iterable, Mapping
from types import MappingProxyType

from tools.workspace_sources import HistoricalSourceReader


INDEX_RELATIVE = "test/fixtures/historical_sources/index.json"
INDEX_SHA256 = "0c0c4f57a4fcfe42421bf524a58ff9b2ae423798247f9d7c3cffbfbfabea5185"
READER_RELATIVE = "tools/workspace_sources.py"
READER_SHA256 = "7c99b3ba9b8bf36923cca729ecaaeb5748a2b9369922dd9ae6bbcb51f64a8920"
SNAPSHOT_ID = "workspace-63792ca-20260927-paused"
ARCHIVE_PATH = Path("D:/006-Programing/LMC/FusionConceptAI_cleanup_20260927/code_history.zip")
ARCHIVE_SHA256 = "a696078a4cd8bb88b0aa30920b91c2aefdb9a8d61f8fe9bd9cfb2caeec528f4b"
ARCHIVE_BYTES = 1819620
BINDING_RELATIVE = "tools/execution/t2_source_inputs.py"
_LOADED_BINDING_SHA256 = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
FROZEN_ARCHIVE_LOGICAL_PATH = "historical_archives/code_history.zip"


_FROZEN_SNAPSHOT_SCHEMA = "fusion-t2-frozen-input-snapshot-v1"
_FROZEN_MANIFEST_NAME = "manifest.toml"
_FROZEN_HEX64 = re.compile(r"^[0-9a-f]{64}$")
_FROZEN_REPARSE_POINT = 0x0400
_FROZEN_CHUNK_BYTES = 1024 * 1024


def _frozen_path(value: Any, label: str) -> str:
    """Validate one portable, canonical relative path used by the snapshot."""
    if not isinstance(value, str) or not value or "\x00" in value or \
            "\\" in value or ":" in value or value.startswith("/"):
        raise RuntimeError(f"{label} must be a canonical relative POSIX path")
    if unicodedata.normalize("NFC", value) != value or \
            unicodedata.normalize("NFKC", value) != value or \
            any(unicodedata.category(char) == "Cs" for char in value):
        raise RuntimeError(f"{label} is not Unicode-normalized")
    parts = value.split("/")
    if any(part in {"", ".", ".."} for part in parts) or \
            any(part.rstrip(" .") != part for part in parts) or \
            any(any(char in '<>|?*' for char in part) for part in parts):
        raise RuntimeError(f"{label} is not a portable canonical relative path")
    for part in parts:
        stem = part.split(".", 1)[0].upper()
        if stem in {"CON", "PRN", "AUX", "NUL"} or \
                re.fullmatch(r"(?:COM|LPT)[1-9]", stem):
            raise RuntimeError(f"{label} contains a reserved Windows path component")
    return value


def _frozen_alias_key(value: str) -> str:
    return unicodedata.normalize("NFKC", value.casefold())


def _frozen_sha(value: Any, label: str) -> str:
    if type(value) is not str or _FROZEN_HEX64.fullmatch(value) is None:
        raise RuntimeError(f"{label} must be lowercase SHA-256 hex")
    return value


def _frozen_pin_bytes(value: Any, label: str) -> int:
    if type(value) is not int or value < 0:
        raise RuntimeError(f"{label} must be a nonnegative integer")
    return value


def _frozen_windows_handle_identity(handle: Any) -> tuple[int, int, int, int, int, int, int]:
    import ctypes
    from ctypes import wintypes

    class _FileTime(ctypes.Structure):
        _fields_ = [("low", wintypes.DWORD), ("high", wintypes.DWORD)]

    class _ByHandleFileInformation(ctypes.Structure):
        _fields_ = [
            ("attributes", wintypes.DWORD),
            ("creation_time", _FileTime),
            ("last_access_time", _FileTime),
            ("last_write_time", _FileTime),
            ("volume_serial", wintypes.DWORD),
            ("size_high", wintypes.DWORD),
            ("size_low", wintypes.DWORD),
            ("link_count", wintypes.DWORD),
            ("file_index_high", wintypes.DWORD),
            ("file_index_low", wintypes.DWORD),
        ]

    class _FileBasicInfo(ctypes.Structure):
        _fields_ = [
            ("creation_time", ctypes.c_longlong),
            ("last_access_time", ctypes.c_longlong),
            ("last_write_time", ctypes.c_longlong),
            ("change_time", ctypes.c_longlong),
            ("attributes", wintypes.DWORD),
        ]

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetFileInformationByHandle.argtypes = [
        wintypes.HANDLE, ctypes.POINTER(_ByHandleFileInformation)]
    kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
    kernel32.GetFileInformationByHandleEx.argtypes = [
        wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel32.GetFileInformationByHandleEx.restype = wintypes.BOOL
    info = _ByHandleFileInformation()
    if not kernel32.GetFileInformationByHandle(handle, ctypes.byref(info)):
        raise OSError(ctypes.get_last_error(), "GetFileInformationByHandle failed")
    basic = _FileBasicInfo()
    if not kernel32.GetFileInformationByHandleEx(
            handle, 0, ctypes.byref(basic), ctypes.sizeof(basic)):
        raise OSError(ctypes.get_last_error(), "GetFileInformationByHandleEx failed")
    if basic.attributes & _FROZEN_REPARSE_POINT:
        raise RuntimeError("frozen input handle is a reparse point")
    index = (int(info.file_index_high) << 32) | int(info.file_index_low)
    size = (int(info.size_high) << 32) | int(info.size_low)
    return (int(info.volume_serial), index, size,
            int(basic.creation_time), int(basic.last_write_time),
            int(basic.change_time), int(info.link_count))


def _frozen_fd_identity(fd: int) -> tuple[int, ...]:
    info = os.fstat(fd)
    if os.name != "nt":
        return (info.st_dev, info.st_ino, info.st_size,
                info.st_mtime_ns, info.st_ctime_ns, info.st_nlink)
    import msvcrt
    return _frozen_windows_handle_identity(msvcrt.get_osfhandle(fd))


def _frozen_path_identity(path: Path) -> tuple[int, ...]:
    _frozen_reparse_check(path)
    if os.name != "nt":
        info = Path(path).stat()
        return (info.st_dev, info.st_ino, info.st_size,
                info.st_mtime_ns, info.st_ctime_ns, info.st_nlink)
    import ctypes
    from ctypes import wintypes
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateFileW.argtypes = [
        wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
        wintypes.LPVOID, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE]
    kernel32.CreateFileW.restype = wintypes.HANDLE
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    handle = kernel32.CreateFileW(
        str(Path(path)), 0x80, 0x1 | 0x2 | 0x4, None, 3, 0x00200000, None)
    invalid_handle = ctypes.c_void_p(-1).value
    if handle == invalid_handle or handle is None:
        raise OSError(ctypes.get_last_error(), "CreateFileW metadata open failed")
    try:
        return _frozen_windows_handle_identity(handle)
    finally:
        if not kernel32.CloseHandle(handle):
            raise OSError(ctypes.get_last_error(), "CloseHandle metadata failed")


def _frozen_file_id(identity: tuple[int, ...]) -> tuple[int, int]:
    return identity[0], identity[1]


def _frozen_reparse_check(path: Path, *, allow_missing: bool = False) -> None:
    """Reject symlinks and Windows reparse points in every existing component."""
    absolute = Path(os.path.abspath(os.fspath(path)))
    for component in reversed((absolute, *absolute.parents)):
        try:
            info = component.lstat()
        except FileNotFoundError:
            if allow_missing:
                continue
            raise
        if stat.S_ISLNK(info.st_mode) or \
                getattr(info, "st_file_attributes", 0) & _FROZEN_REPARSE_POINT:
            raise RuntimeError(f"frozen input path contains a reparse component: {component}")


def _frozen_parent_identity_chain(path: Path) -> tuple[tuple[str, int, int], ...]:
    _frozen_reparse_check(path)
    absolute = Path(os.path.abspath(os.fspath(path)))
    chain = []
    for component in reversed((absolute, *absolute.parents)):
        info = component.lstat()
        if not stat.S_ISDIR(info.st_mode):
            raise RuntimeError(f"snapshot output parent is not a directory: {component}")
        chain.append((str(component), info.st_dev, info.st_ino))
    return tuple(chain)


def _frozen_file_receipt(path: Path) -> tuple[int, str]:
    _frozen_reparse_check(path)
    with Path(path).open("rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise RuntimeError(f"frozen snapshot member is not a regular file: {path}")
        before_identity = _frozen_fd_identity(stream.fileno())
        digest = hashlib.sha256()
        length = 0
        while True:
            chunk = stream.read(_FROZEN_CHUNK_BYTES)
            if not chunk:
                break
            length += len(chunk)
            digest.update(chunk)
        after = os.fstat(stream.fileno())
        after_identity = _frozen_fd_identity(stream.fileno())
    final_identity = _frozen_path_identity(path)
    if before_identity != after_identity or after_identity != final_identity:
        raise RuntimeError(f"frozen snapshot member changed while hashing: {path}")
    return length, digest.hexdigest()


def _frozen_read_file(path: Path) -> bytes:
    """Read and verify bytes and path identity through the same file handle."""
    _frozen_reparse_check(path)
    with Path(path).open("rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise RuntimeError(f"frozen input is not a regular file: {path}")
        before_identity = _frozen_fd_identity(stream.fileno())
        data = stream.read()
        after = os.fstat(stream.fileno())
        after_identity = _frozen_fd_identity(stream.fileno())
    _frozen_reparse_check(path)
    final_identity = _frozen_path_identity(path)
    if before_identity != after_identity or \
            after_identity != final_identity or \
            len(data) != after.st_size:
        raise RuntimeError(f"frozen input changed while being read: {path}")
    return data


def _frozen_write_new(path: Path, data: bytes) -> None:
    """Create one new manifest with exclusive open and path/handle checks."""
    parent_before = _frozen_parent_identity_chain(path.parent)
    _frozen_reparse_check(path, allow_missing=True)
    with Path(path).open("xb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
            raise RuntimeError(f"snapshot output is not a new regular file: {path}")
        before_identity = _frozen_fd_identity(stream.fileno())
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
        after = os.fstat(stream.fileno())
        after_identity = _frozen_fd_identity(stream.fileno())
    _frozen_reparse_check(path)
    final_identity = _frozen_path_identity(path)
    parent_after = _frozen_parent_identity_chain(path.parent)
    if _frozen_file_id(before_identity) != _frozen_file_id(after_identity) or \
            after_identity != final_identity or \
            after.st_size != len(data) or parent_before != parent_after:
        raise RuntimeError(f"snapshot output identity changed while writing: {path}")


def _toml_string(value: str) -> str:
    # JSON basic-string escaping is a strict subset of TOML basic strings.
    return json.dumps(value, ensure_ascii=True)


class FrozenInputSnapshot:
    """Owned, exact-byte source tree with a strict TOML closure manifest.

    ``origin_path`` is provenance metadata only. Reads and resolutions always
    use the copied file below ``root``. Missing declared files fail during
    freeze and are never represented as bytes or silently sourced elsewhere.
    """

    def __init__(self, snapshot_root: Path, manifest_sha256: str,
                 entries: dict[str, dict[str, Any]],
                 external_archives: dict[str, dict[str, Any]],
                 inventory_root_sha256: str):
        self.root = Path(snapshot_root).resolve(strict=True)
        self.manifest_path = self.root / _FROZEN_MANIFEST_NAME
        self.manifest_sha256 = _frozen_sha(manifest_sha256, "manifest SHA-256")
        self.entries = MappingProxyType({
            key: MappingProxyType(dict(row)) for key, row in entries.items()})
        self.external_archives = MappingProxyType({
            key: MappingProxyType(dict(row)) for key, row in external_archives.items()})
        self.inventory_root_sha256 = _frozen_sha(
            inventory_root_sha256, "inventory root SHA-256")
        self.snapshot_id = self.inventory_root_sha256

    @staticmethod
    def _normalize_rows(rows: Any, *, external: bool) -> list[dict[str, Any]]:
        if isinstance(rows, Mapping):
            source_rows = []
            for key, value in rows.items():
                if not isinstance(value, Mapping):
                    raise RuntimeError("snapshot closure values must be mappings")
                row = dict(value)
                receipt_path = row.pop("path", key)
                if receipt_path != key:
                    raise RuntimeError("snapshot receipt path differs from its closure key")
                row.setdefault("logical_path", key)
                source_rows.append(row)
        elif isinstance(rows, Iterable) and not isinstance(rows, (str, bytes)):
            source_rows = list(rows)
        else:
            raise RuntimeError("snapshot closure must be a mapping or iterable of rows")
        normalized = []
        expected_keys = {"logical_path", "role", "bytes", "sha256"}
        if external:
            expected_keys.add("origin_path")
        for source_row in source_rows:
            if not isinstance(source_row, Mapping):
                raise RuntimeError("snapshot closure row must be a mapping")
            row = dict(source_row)
            if "path" in row and "logical_path" not in row:
                row["logical_path"] = row.pop("path")
            allowed_keys = (expected_keys, expected_keys | {"source_path"}) \
                if external else (expected_keys,)
            if set(row) not in allowed_keys:
                raise RuntimeError("snapshot closure row has missing or unknown fields")
            logical = _frozen_path(row["logical_path"], "logical_path")
            role = row["role"]
            if type(role) is not str or not role or any(ord(char) < 0x20 for char in role):
                raise RuntimeError("snapshot role must be nonempty printable text")
            record = {
                "logical_path": logical,
                "role": role,
                "bytes": _frozen_pin_bytes(row["bytes"], "input bytes"),
                "sha256": _frozen_sha(row["sha256"], "input SHA-256"),
            }
            if external:
                origin = row["origin_path"]
                if type(origin) is not str or not Path(origin).is_absolute():
                    raise RuntimeError("external archive origin_path must be absolute")
                record["origin_path"] = origin
                if "source_path" in row:
                    source_path = row["source_path"]
                    if type(source_path) is not str or \
                            not Path(source_path).is_absolute():
                        raise RuntimeError(
                            "external archive source_path must be absolute")
                    record["_copy_source_path"] = source_path
                leaf = Path(origin).name
                _frozen_path("_archives/" + leaf, "external archive frozen path")
                record["frozen_path"] = "_archives/" + leaf
            else:
                record["frozen_path"] = logical
            normalized.append(record)
        return normalized

    @staticmethod
    def _inventory_root(entries: list[dict[str, Any]],
                        external_archives: list[dict[str, Any]]) -> str:
        rows = []
        for kind, source_rows in (("entry", entries), ("external_archive", external_archives)):
            for row in source_rows:
                rows.append([kind, row["logical_path"], row["role"],
                             row["frozen_path"], row["bytes"], row["sha256"]])
        rows.sort(key=lambda row: (_frozen_alias_key(row[1]), row[0], row[2], row[3]))
        encoded = json.dumps(rows, ensure_ascii=True, separators=(",", ":")).encode("utf-8")
        return hashlib.sha256(encoded).hexdigest()

    @classmethod
    def freeze(cls, repository_root: Path, fresh_snapshot_dir: Path,
               explicit_entries: Any, *,
               explicit_external_archives: Any = ()) -> "FrozenInputSnapshot":
        repository_input = Path(os.path.abspath(os.fspath(repository_root)))
        _frozen_reparse_check(repository_input)
        repository = repository_input.resolve(strict=True)
        destination = Path(os.path.abspath(os.fspath(fresh_snapshot_dir)))
        if destination.exists():
            raise FileExistsError(f"snapshot destination must be fresh: {destination}")
        _frozen_reparse_check(destination.parent, allow_missing=False)
        if destination == repository or destination in repository.parents:
            raise RuntimeError("snapshot destination cannot replace or contain the repository root")

        entries = cls._normalize_rows(explicit_entries, external=False)
        archives = cls._normalize_rows(explicit_external_archives, external=True)
        if not entries and not archives:
            raise RuntimeError("frozen input snapshot cannot have an empty declared closure")
        logical_keys: dict[str, str] = {}
        frozen_keys: dict[str, str] = {}
        for kind, rows in (("entry", entries), ("external_archive", archives)):
            for row in rows:
                logical = row["logical_path"]
                frozen = row["frozen_path"]
                if frozen == _FROZEN_MANIFEST_NAME or \
                        frozen.startswith(_FROZEN_MANIFEST_NAME + "/"):
                    raise RuntimeError("declared frozen path collides with manifest.toml")
                for key, value, label in (
                        (logical_keys, logical, "logical"),
                        (frozen_keys, frozen, "frozen")):
                    alias = _frozen_alias_key(value)
                    prior = key.get(alias)
                    if prior is not None:
                        raise RuntimeError(f"snapshot {label} path aliases or duplicates: {prior}, {value}")
                    key[alias] = value
                row["kind"] = kind

        source_paths: dict[str, Path] = {}
        for row in entries:
            source = repository.joinpath(*row["logical_path"].split("/"))
            source_paths[row["logical_path"]] = source
        for row in archives:
            source_paths[row["logical_path"]] = Path(
                row.get("_copy_source_path", row["origin_path"]))
        source_file_ids: dict[tuple[int, int], str] = {}
        source_preflight_identity: dict[str, tuple[int, int, int, int, int]] = {}
        for logical, source in source_paths.items():
            _frozen_reparse_check(source)
            resolved = source.resolve(strict=True)
            if not resolved.is_file():
                raise RuntimeError(f"declared snapshot input is not a regular file: {source}")
            info = resolved.stat()
            identity = _frozen_path_identity(resolved)
            file_id = _frozen_file_id(identity)
            previous = source_file_ids.get(file_id)
            if previous is not None:
                raise RuntimeError(
                    f"declared snapshot paths alias the same file: {previous}, {logical}")
            source_file_ids[file_id] = logical
            source_preflight_identity[logical] = identity
        destination.mkdir(parents=True, exist_ok=False)
        try:
            for row in sorted([*entries, *archives], key=lambda item: item["frozen_path"]):
                source = source_paths[row["logical_path"]]
                target = destination.joinpath(*row["frozen_path"].split("/"))
                target.parent.mkdir(parents=True, exist_ok=True)
                parent_before = _frozen_parent_identity_chain(target.parent)
                _frozen_reparse_check(target, allow_missing=True)
                _frozen_reparse_check(source)
                with source.open("rb") as source_stream:
                    before = os.fstat(source_stream.fileno())
                    before_identity = _frozen_fd_identity(source_stream.fileno())
                    if not stat.S_ISREG(before.st_mode) or before.st_nlink != 1:
                        raise RuntimeError(f"declared snapshot input is not a regular file: {source}")
                    if before_identity != source_preflight_identity[row["logical_path"]]:
                        raise RuntimeError(
                            f"declared input identity changed after preflight: {row['logical_path']}")
                    digest = hashlib.sha256()
                    length = 0
                    with target.open("xb") as target_stream:
                        target_before = os.fstat(target_stream.fileno())
                        target_before_identity = _frozen_fd_identity(
                            target_stream.fileno())
                        if not stat.S_ISREG(target_before.st_mode) or \
                                target_before.st_nlink != 1:
                            raise RuntimeError(
                                f"snapshot output is not a new regular file: {target}")
                        while True:
                            chunk = source_stream.read(_FROZEN_CHUNK_BYTES)
                            if not chunk:
                                break
                            target_stream.write(chunk)
                            digest.update(chunk)
                            length += len(chunk)
                        target_stream.flush()
                        os.fsync(target_stream.fileno())
                        target_after = os.fstat(target_stream.fileno())
                        target_after_identity = _frozen_fd_identity(
                            target_stream.fileno())
                    after = os.fstat(source_stream.fileno())
                    after_identity = _frozen_fd_identity(source_stream.fileno())
                final_identity = _frozen_path_identity(source)
                _frozen_reparse_check(source)
                if before_identity != after_identity or \
                        after_identity != final_identity:
                    raise RuntimeError(f"declared input changed while being copied: {row['logical_path']}")
                _frozen_reparse_check(target)
                target_final_identity = _frozen_path_identity(target)
                parent_after = _frozen_parent_identity_chain(target.parent)
                if _frozen_file_id(target_before_identity) != \
                        _frozen_file_id(target_after_identity) or \
                        target_after_identity != target_final_identity or \
                        target_after.st_size != length or parent_before != parent_after:
                    raise RuntimeError(
                        f"snapshot output identity changed while copying: {row['logical_path']}")
                if length != row["bytes"] or digest.hexdigest() != row["sha256"]:
                    raise RuntimeError(f"declared input pin mismatch: {row['logical_path']}")
                copied_length, copied_sha = _frozen_file_receipt(target)
                if (copied_length, copied_sha) != (row["bytes"], row["sha256"]):
                    raise RuntimeError(f"copied input differs from source bytes: {row['logical_path']}")
                if row["kind"] == "entry":
                    row["origin_path"] = str(source.absolute())
                row.pop("_copy_source_path", None)

            inventory_root = cls._inventory_root(entries, archives)
            manifest_text = cls._manifest_text(entries, archives, inventory_root)
            manifest_bytes = manifest_text.encode("utf-8")
            manifest_path = destination / _FROZEN_MANIFEST_NAME
            _frozen_write_new(manifest_path, manifest_bytes)
            manifest_sha = hashlib.sha256(manifest_bytes).hexdigest()
            snapshot = cls.open(destination, manifest_sha)
            return snapshot
        except BaseException:
            # Keep a failed partial tree for diagnosis; it is never loadable
            # because it has no verified manifest identity.
            raise

    @staticmethod
    def _manifest_text(entries: list[dict[str, Any]],
                       external_archives: list[dict[str, Any]],
                       inventory_root_sha256: str) -> str:
        lines = [
            "[snapshot]",
            f"schema = {_toml_string(_FROZEN_SNAPSHOT_SCHEMA)}",
            f"entry_count = {len(entries)}",
            f"external_archive_count = {len(external_archives)}",
            f"inventory_root_sha256 = {_toml_string(inventory_root_sha256)}",
        ]
        for heading, rows in (("entries", entries),
                              ("external_archives", external_archives)):
            for row in sorted(rows, key=lambda item: item["logical_path"]):
                lines.extend(("", f"[[{heading}]]"))
                for key in (("logical_path", "role", "bytes", "sha256", "frozen_path", "origin_path")
                            if heading == "entries" else
                            ("logical_path", "role", "bytes", "sha256", "frozen_path", "origin_path")):
                    value = row[key]
                    rendered = str(value) if key == "bytes" else _toml_string(value)
                    lines.append(f"{key} = {rendered}")
        return "\n".join(lines) + "\n"

    @classmethod
    def open(cls, snapshot_root: Path,
             expected_manifest_sha256: str) -> "FrozenInputSnapshot":
        root_input = Path(os.path.abspath(os.fspath(snapshot_root)))
        _frozen_reparse_check(root_input)
        root = root_input.resolve(strict=True)
        manifest_path = root / _FROZEN_MANIFEST_NAME
        manifest_sha = _frozen_sha(expected_manifest_sha256, "expected manifest SHA-256")
        _frozen_reparse_check(manifest_path)
        manifest_bytes = _frozen_read_file(manifest_path)
        if hashlib.sha256(manifest_bytes).hexdigest() != manifest_sha:
            raise RuntimeError("frozen input manifest SHA-256 mismatch")
        try:
            value = tomllib.loads(manifest_bytes.decode("utf-8", errors="strict"))
        except (UnicodeDecodeError, tomllib.TOMLDecodeError) as exc:
            raise RuntimeError("frozen input manifest is invalid UTF-8 TOML") from exc
        if type(value) is not dict or not {"snapshot"}.issubset(value) or \
                not set(value).issubset({"snapshot", "entries", "external_archives"}):
            raise RuntimeError("frozen input manifest has unexpected top-level fields")
        header = value["snapshot"]
        if type(header) is not dict or set(header) != {
                "schema", "entry_count", "external_archive_count", "inventory_root_sha256"} or \
                header.get("schema") != _FROZEN_SNAPSHOT_SCHEMA:
            raise RuntimeError("frozen input manifest header differs from the declared schema")
        raw_entries = value.get("entries", [])
        raw_archives = value.get("external_archives", [])
        if type(raw_entries) is not list or type(raw_archives) is not list or \
                (not raw_entries and not raw_archives) or \
                type(header.get("entry_count")) is not int or \
                header["entry_count"] != len(raw_entries) or \
                type(header.get("external_archive_count")) is not int or \
                header["external_archive_count"] != len(raw_archives):
            raise RuntimeError("frozen input manifest counts do not match its rows")
        expected_fields = {"logical_path", "role", "bytes", "sha256", "frozen_path", "origin_path"}
        normalized_entries = []
        normalized_archives = []
        logical_keys: dict[str, str] = {}
        frozen_keys: dict[str, str] = {}
        for kind, raw_rows, target_rows in (
                ("entry", raw_entries, normalized_entries),
                ("external_archive", raw_archives, normalized_archives)):
            for raw in raw_rows:
                if type(raw) is not dict or set(raw) != expected_fields:
                    raise RuntimeError("frozen input manifest row has unexpected fields")
                logical = _frozen_path(raw["logical_path"], "manifest logical_path")
                frozen = _frozen_path(raw["frozen_path"], "manifest frozen_path")
                if kind == "entry" and frozen != logical:
                    raise RuntimeError("ordinary frozen entry path must equal its logical path")
                if frozen == _FROZEN_MANIFEST_NAME or \
                        frozen.startswith(_FROZEN_MANIFEST_NAME + "/"):
                    raise RuntimeError("manifest path collides with a declared frozen input")
                if kind == "external_archive" and not frozen.startswith("_archives/"):
                    raise RuntimeError("external archive must be stored below _archives/")
                if kind == "external_archive" and len(frozen.split("/")) != 2:
                    raise RuntimeError("external archive frozen path must be _archives/<safe-name>")
                role = raw["role"]
                if type(role) is not str or not role or any(ord(char) < 0x20 for char in role):
                    raise RuntimeError("manifest role must be nonempty printable text")
                origin = raw["origin_path"]
                if type(origin) is not str or not Path(origin).is_absolute():
                    raise RuntimeError("manifest origin_path must be absolute provenance text")
                row = {"logical_path": logical, "role": role,
                       "bytes": _frozen_pin_bytes(raw["bytes"], "manifest bytes"),
                       "sha256": _frozen_sha(raw["sha256"], "manifest SHA-256"),
                       "frozen_path": frozen, "origin_path": origin, "kind": kind}
                for index, label, text in (
                        (logical_keys, "logical", logical),
                        (frozen_keys, "frozen", frozen)):
                    alias = _frozen_alias_key(text)
                    if alias in index:
                        raise RuntimeError(f"manifest {label} paths alias or duplicate")
                    index[alias] = text
                target_rows.append(row)
        inventory_root = cls._inventory_root(normalized_entries, normalized_archives)
        if header.get("inventory_root_sha256") != inventory_root:
            raise RuntimeError("frozen input inventory root digest mismatch")
        snapshot = cls(root, manifest_sha,
                       {row["logical_path"]: row for row in normalized_entries},
                       {row["logical_path"]: row for row in normalized_archives},
                       inventory_root)
        snapshot.verify_all()
        return snapshot

    def _closed_tree_inventory(self) -> tuple[set[str], set[str]]:
        expected_files = {_FROZEN_MANIFEST_NAME}
        expected_dirs: set[str] = set()
        rows = [*self.entries.values(), *self.external_archives.values()]
        for row in rows:
            relative = row["frozen_path"]
            expected_files.add(relative)
            parts = relative.split("/")
            for index in range(1, len(parts)):
                expected_dirs.add("/".join(parts[:index]))
        actual_files: set[str] = set()
        actual_dirs: set[str] = set()
        _frozen_reparse_check(self.root)
        for path in self.root.rglob("*"):
            _frozen_reparse_check(path)
            relative = path.relative_to(self.root).as_posix()
            if path.is_dir():
                actual_dirs.add(relative)
            elif path.is_file():
                actual_files.add(relative)
            else:
                raise RuntimeError(f"snapshot contains a non-file member: {relative}")
        if actual_files != expected_files or actual_dirs != expected_dirs:
            raise RuntimeError("frozen input tree has missing or undeclared members")
        return actual_files, actual_dirs

    def verify_frozen_identity(self) -> None:
        """Verify the protocol-pinned manifest and its exact in-memory row maps."""
        manifest_bytes = _frozen_read_file(self.manifest_path)
        if hashlib.sha256(manifest_bytes).hexdigest() != self.manifest_sha256:
            raise RuntimeError("frozen input manifest changed after admission")
        entries = list(self.entries.values())
        archives = list(self.external_archives.values())
        expected_row_fields = {
            "logical_path", "role", "bytes", "sha256", "frozen_path",
            "origin_path", "kind"}
        for expected_kind, source in (
                ("entry", self.entries),
            ("external_archive", self.external_archives)):
            for key, row in source.items():
                if not isinstance(row, Mapping) or set(row) != expected_row_fields or \
                        row.get("logical_path") != key or row.get("kind") != expected_kind:
                    raise RuntimeError("frozen input membership maps changed after admission")
        inventory_root = self._inventory_root(entries, archives)
        if inventory_root != self.inventory_root_sha256 or \
                self.snapshot_id != inventory_root:
            raise RuntimeError("frozen input inventory identity changed after admission")
        canonical_manifest = self._manifest_text(
            entries, archives, inventory_root).encode("utf-8")
        if canonical_manifest != manifest_bytes:
            raise RuntimeError("frozen input manifest rows differ from bound membership maps")

    def verify_all(self) -> None:
        """Re-read every declared byte and prove the entire tree is closed."""
        self.verify_frozen_identity()
        self._closed_tree_inventory()
        for row in [*self.entries.values(), *self.external_archives.values()]:
            path = self.root.joinpath(*row["frozen_path"].split("/"))
            actual = _frozen_file_receipt(path)
            if actual != (row["bytes"], row["sha256"]):
                raise RuntimeError(f"frozen input bytes changed: {row['logical_path']}")

    def resolve(self, logical_path: str, expected_bytes: int,
                expected_sha256: str) -> Path:
        """Resolve a pinned path; callers must still verify the full tree after use."""
        self.verify_frozen_identity()
        logical = _frozen_path(logical_path, "requested frozen logical_path")
        expected = {"bytes": _frozen_pin_bytes(expected_bytes, "requested bytes"),
                    "sha256": _frozen_sha(expected_sha256, "requested SHA-256")}
        row = self.entries.get(logical) or self.external_archives.get(logical)
        if row is None or {"bytes": row["bytes"], "sha256": row["sha256"]} != expected:
            raise RuntimeError(f"requested frozen input identity is not declared: {logical}")
        path = self.root.joinpath(*row["frozen_path"].split("/"))
        if _frozen_file_receipt(path) != (row["bytes"], row["sha256"]):
            raise RuntimeError(f"requested frozen input bytes changed: {logical}")
        return path

    def read_bytes(self, logical_path: str, expected_bytes: int,
                   expected_sha256: str) -> bytes:
        logical = _frozen_path(logical_path, "requested frozen logical_path")
        row = self.entries.get(logical) or self.external_archives.get(logical)
        expected_length = _frozen_pin_bytes(expected_bytes, "requested bytes")
        if row is None or row["bytes"] != expected_length or \
                row["sha256"] != _frozen_sha(expected_sha256, "requested SHA-256"):
            raise RuntimeError(f"requested frozen input identity is not declared: {logical}")
        self.verify_frozen_identity()
        path = self.root.joinpath(*row["frozen_path"].split("/"))
        data = _frozen_read_file(path)
        if len(data) != expected_length or \
                hashlib.sha256(data).hexdigest() != expected_sha256:
            raise RuntimeError(f"requested frozen input changed while reading: {logical_path}")
        return data


def _verify_formal_frozen_protocol(snapshot: Any, protocol_path_value: str,
                                  expected_protocol_sha256: str,
                                  expected_snapshot_id: str,
                                  expected_manifest_sha256: str) -> None:
    protocol_input = Path(protocol_path_value)
    if not protocol_input.is_absolute():
        raise RuntimeError("formal T2 protocol path must be absolute")
    protocol_path = protocol_input.resolve(strict=True)
    root = Path(snapshot.root).resolve(strict=True)
    try:
        protocol_path.relative_to(root)
    except ValueError:
        pass
    else:
        raise RuntimeError("formal T2 protocol must be outside the frozen source tree")
    raw = protocol_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected_protocol_sha256.lower():
        raise RuntimeError("formal T2 protocol raw SHA-256 mismatch")
    try:
        protocol = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError("formal T2 protocol is not valid JSON") from error
    if type(protocol) is not dict:
        raise RuntimeError("formal T2 protocol root must be an object")
    if "protocol_path" in protocol and protocol.get("protocol_path") != str(protocol_path):
        raise RuntimeError("formal T2 protocol path identity mismatch")
    record = protocol.get("source_snapshot")
    consumer = protocol.get("consumer")
    consumer_protocol = consumer.get("protocol") if type(consumer) is dict else None
    wrapped_record = consumer_protocol.get("source_snapshot") \
        if type(consumer_protocol) is dict else None
    if record is None:
        record = wrapped_record
    elif wrapped_record is not None and wrapped_record != record:
        raise RuntimeError("formal T2 protocol source authorization wrappers differ")
    if type(record) is not dict or \
            record.get("schema") != "fusion-t2-frozen-input-snapshot-v1":
        raise RuntimeError("formal T2 protocol lacks frozen source authorization")
    snapshot.verify_frozen_identity()
    manifest = snapshot.manifest_path.read_bytes()

    def expected_rows(rows: Any) -> dict[str, dict[str, Any]]:
        return {key: {"role": row["role"], "bytes": row["bytes"],
                      "sha256": row["sha256"]}
                for key, row in sorted(rows.items())}

    if record.get("source_root") != str(root) or \
            record.get("manifest_path") != "manifest.toml" or \
            record.get("manifest_bytes") != len(manifest) or \
            record.get("manifest_sha256") != expected_manifest_sha256.lower() or \
            hashlib.sha256(manifest).hexdigest() != expected_manifest_sha256.lower() or \
            snapshot.manifest_sha256 != expected_manifest_sha256.lower() or \
            record.get("inventory_root_sha256") != expected_snapshot_id.lower() or \
            record.get("snapshot_id") != expected_snapshot_id.lower() or \
            snapshot.inventory_root_sha256 != expected_snapshot_id.lower() or \
            snapshot.snapshot_id != expected_snapshot_id.lower() or \
            record.get("expected_entries") != expected_rows(snapshot.entries) or \
            record.get("expected_external_archives") != expected_rows(
                snapshot.external_archives):
        raise RuntimeError(
            "formal T2 protocol source authorization differs from frozen snapshot")


class T2SourceInputs:
    """One frozen, explicit history allowlist shared by the three consumers."""

    def __init__(self, repository_root: Path, *,
                 frozen_snapshot: FrozenInputSnapshot | None = None,
                 expected_snapshot_id: str | None = None,
                 expected_manifest_sha256: str | None = None):
        formal_env_names = (
            "FUSION_T2_FROZEN_SNAPSHOT_ID",
            "FUSION_T2_FROZEN_MANIFEST_SHA256",
            "FUSION_T2_FROZEN_PROTOCOL_SHA256",
            "FUSION_T2_FROZEN_PROTOCOL_PATH",
        )
        formal_env_present = [name in os.environ for name in formal_env_names]
        if any(formal_env_present):
            if not all(formal_env_present):
                raise RuntimeError("formal T2 frozen environment pins are incomplete")
            formal_env = [os.environ[name] for name in formal_env_names]
            if any(type(value) is not str or not value for value in formal_env) or \
                    any(not _FROZEN_HEX64.fullmatch(value.lower())
                        for value in formal_env[:3]):
                raise RuntimeError("formal T2 frozen environment pins are malformed")
            if frozen_snapshot is None or \
                    type(expected_snapshot_id) is not str or \
                    type(expected_manifest_sha256) is not str:
                raise RuntimeError(
                    "formal T2 source binding requires complete frozen snapshot inputs")
            if expected_snapshot_id.lower() != formal_env[0].lower() or \
                    expected_manifest_sha256.lower() != formal_env[1].lower():
                raise RuntimeError("formal T2 frozen environment identity mismatch")
            _verify_formal_frozen_protocol(
                frozen_snapshot, formal_env[3], formal_env[2],
                expected_snapshot_id.lower(), expected_manifest_sha256.lower())
        repository = Path(repository_root).resolve(strict=True)
        if frozen_snapshot is None:
            if expected_snapshot_id is not None or expected_manifest_sha256 is not None:
                raise RuntimeError("frozen snapshot identities require a frozen snapshot")
            self.frozen_snapshot = None
            self.expected_snapshot_id = None
            self.expected_manifest_sha256 = None
            self.root = repository
        else:
            if not isinstance(frozen_snapshot, FrozenInputSnapshot):
                raise TypeError("frozen_snapshot must be a FrozenInputSnapshot")
            expected_id = _frozen_sha(expected_snapshot_id, "expected frozen snapshot ID")
            expected_manifest = _frozen_sha(
                expected_manifest_sha256, "expected frozen manifest SHA-256")
            if repository != frozen_snapshot.root or \
                    expected_id != frozen_snapshot.inventory_root_sha256 or \
                    expected_manifest != frozen_snapshot.manifest_sha256:
                raise RuntimeError("authorized frozen snapshot identities do not match")
            self.frozen_snapshot = frozen_snapshot
            self.expected_snapshot_id = expected_id
            self.expected_manifest_sha256 = expected_manifest
            self.root = frozen_snapshot.root
            frozen_snapshot.verify_all()
        self.index = self.root / INDEX_RELATIVE
        self._check_current_helpers()
        # The reader validates duplicate keys, canonical paths, original
        # receipts, pins, and the index's local identity before exposing data.
        with self._reader():
            index_bytes = self.read_bytes(self.index)
            if hashlib.sha256(index_bytes).hexdigest() != INDEX_SHA256:
                raise RuntimeError("T2 historical index changed during binding")
            value = json.loads(index_bytes)
        if value["archive"] != {
                "path": ARCHIVE_PATH.as_posix(), "bytes": ARCHIVE_BYTES,
                "sha256": ARCHIVE_SHA256}:
            raise RuntimeError("T2 source archive binding differs from the frozen archive")
        self.history = {}
        for entry in value["entries"]:
            if entry["snapshot_id"] != SNAPSHOT_ID:
                raise RuntimeError("T2 source history has an unapproved snapshot")
            logical = entry["logical_path"]
            if logical in self.history:
                raise RuntimeError("T2 source history repeats a logical path")
            self.history[logical] = dict(entry["origin_receipt"])
        if len(self.history) != 82:
            raise RuntimeError("T2 historical source allowlist differs from the frozen 82 entries")

    def _reader(self) -> HistoricalSourceReader:
        if self.frozen_snapshot is not None:
            return HistoricalSourceReader.from_frozen_snapshot(
                self.frozen_snapshot, INDEX_RELATIVE, INDEX_SHA256,
                FROZEN_ARCHIVE_LOGICAL_PATH,
                expected_snapshot_id=self.expected_snapshot_id,
                expected_manifest_sha256=self.expected_manifest_sha256,
                strict_subset=False)
        return HistoricalSourceReader(self.index, INDEX_SHA256, ARCHIVE_PATH)

    def _check_current_helpers(self) -> None:
        if self.frozen_snapshot is not None:
            if Path(__file__).resolve(strict=True) != \
                    (self.root / BINDING_RELATIVE).resolve(strict=True):
                raise RuntimeError("T2 source binding helper was loaded outside the frozen snapshot")
            reader_module = sys.modules.get(HistoricalSourceReader.__module__)
            reader_file = getattr(reader_module, "__file__", None)
            if not isinstance(reader_file, str) or \
                    Path(reader_file).resolve(strict=True) != \
                    (self.root / READER_RELATIVE).resolve(strict=True):
                raise RuntimeError("historical reader was loaded outside the frozen snapshot")
            for relative in (READER_RELATIVE, BINDING_RELATIVE):
                row = self._snapshot_entry(relative)
                data = self.frozen_snapshot.read_bytes(
                    relative, row["bytes"], row["sha256"])
                actual = hashlib.sha256(data).hexdigest()
                if actual != row["sha256"]:
                    raise RuntimeError(f"T2 frozen helper byte drift: {relative}")
            binding_row = self._snapshot_entry(BINDING_RELATIVE)
            if binding_row["sha256"] != _LOADED_BINDING_SHA256:
                raise RuntimeError("T2 frozen binding module differs from its loaded bytes")
            return
        for relative, expected in (
                (READER_RELATIVE, READER_SHA256),
                (BINDING_RELATIVE, _LOADED_BINDING_SHA256)):
            path = self._local_file(self.root / relative)
            if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise RuntimeError(f"T2 current source binding helper drift: {relative}")
        if Path(__file__).resolve(strict=True) != (self.root / BINDING_RELATIVE).resolve(strict=True):
            raise RuntimeError("T2 source binding helper was loaded from another checkout")

    def _snapshot_entry(self, relative: str) -> Mapping[str, Any]:
        if self.frozen_snapshot is None:
            raise RuntimeError("snapshot membership requested in legacy source mode")
        row = self.frozen_snapshot.entries.get(relative)
        if not isinstance(row, Mapping) or row.get("logical_path") != relative:
            raise RuntimeError(f"T2 frozen snapshot omits declared input: {relative}")
        return row

    def logical_path(self, path: Path) -> str:
        absolute = Path(path).absolute()
        relative = absolute.relative_to(self.root).as_posix()
        if any(part in ("", ".", "..") for part in relative.split("/")):
            raise RuntimeError("T2 input path is not canonical")
        return relative

    def _local_file(self, path: Path) -> Path:
        if self.frozen_snapshot is not None:
            relative = self.logical_path(path)
            row = self._snapshot_entry(relative)
            return self.frozen_snapshot.resolve(
                relative, row["bytes"], row["sha256"])
        absolute = Path(path).absolute()
        self.logical_path(absolute)
        for component in reversed((absolute, *absolute.parents)):
            info = component.lstat()
            if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
                raise RuntimeError(f"T2 local input has a symlink or reparse component: {component}")
        resolved = absolute.resolve(strict=True)
        resolved.relative_to(self.root)
        if not resolved.is_file():
            raise RuntimeError(f"T2 local input is not a regular file: {path}")
        return resolved

    def read_bytes(self, path: Path) -> bytes:
        """Read a current local file, with no historical lookup or fallback."""
        self._check_current_helpers()
        if self.frozen_snapshot is not None:
            relative = self.logical_path(path)
            row = self._snapshot_entry(relative)
            return self.frozen_snapshot.read_bytes(
                relative, row["bytes"], row["sha256"])
        resolved = self._local_file(path)
        with resolved.open("rb") as stream:
            before = os.fstat(stream.fileno())
            data = stream.read()
            after = os.fstat(stream.fileno())
        final = self._local_file(path).stat()
        fingerprint = lambda item: (item.st_dev, item.st_ino, item.st_size, item.st_mtime_ns)
        if fingerprint(before) != fingerprint(after) or fingerprint(after) != fingerprint(final):
            raise RuntimeError(f"T2 local input changed during its read: {path}")
        return data

    def read_historical_bytes(self, path: Path, snapshot_id: str,
                              expected_receipt: dict[str, Any]) -> bytes:
        """Explicit historical data read; all three identities are required."""
        self._check_current_helpers()
        relative = self.logical_path(path)
        if snapshot_id != SNAPSHOT_ID or self.history.get(relative) != expected_receipt:
            raise RuntimeError(f"T2 historical read has an unapproved identity: {relative}")
        with self._reader() as reader:
            data = reader.read_bytes(relative, snapshot_id)
        if len(data) != expected_receipt["bytes"] or hashlib.sha256(data).hexdigest() != expected_receipt["sha256"]:
            raise RuntimeError(f"T2 historical source pin drift: {relative}")
        return data

    def read_text(self, path: Path, encoding: str = "utf-8", errors: str = "strict") -> str:
        return self.read_bytes(path).decode(encoding, errors)

    def receipt(self, path: Path) -> dict[str, Any]:
        relative = self.logical_path(path)
        data = self.read_bytes(path)
        result = {"path": relative, "bytes": len(data),
                  "sha256": hashlib.sha256(data).hexdigest()}
        return result

    def historical_receipt(self, path: Path, snapshot_id: str,
                           expected_receipt: dict[str, Any]) -> dict[str, Any]:
        data = self.read_historical_bytes(path, snapshot_id, expected_receipt)
        return {"path": self.logical_path(path), "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest()}

    def read_historical_text(self, path: Path, snapshot_id: str,
                             expected_receipt: dict[str, Any],
                             encoding: str = "utf-8", errors: str = "strict") -> str:
        return self.read_historical_bytes(path, snapshot_id, expected_receipt).decode(encoding, errors)

    def read_protocol_input_bytes(self, protocol: dict[str, Any], path: Path) -> bytes:
        """Read one explicitly pinned protocol input, never a protocol/output fallback."""
        relative = self.logical_path(path)
        self.verify_protocol_layout(protocol)
        expected = protocol["inputs"].get(relative)
        if (type(expected) is not dict or
                set(expected) != {"path", "bytes", "sha256"} or
                expected.get("path") != relative or
                type(expected.get("bytes")) is not int or expected["bytes"] < 0 or
                type(expected.get("sha256")) is not str or
                len(expected["sha256"]) != 64 or
                any(character not in "0123456789abcdef"
                    for character in expected["sha256"])):
            raise RuntimeError(f"T2 protocol input has no exact path/bytes/SHA pin: {relative}")
        layout = protocol["source_layout"]
        historical = layout["historical_source_data"].get(relative)
        if historical is not None:
            data = self.read_historical_bytes(path, layout["snapshot_id"], historical)
        else:
            data = self.read_bytes(path)
        actual = {"path": relative, "bytes": len(data),
                  "sha256": hashlib.sha256(data).hexdigest()}
        if actual != expected:
            raise RuntimeError(f"T2 protocol input differs from its exact pin: {relative}")
        return data

    def protocol_input_receipt(self, protocol: dict[str, Any], path: Path) -> dict[str, Any]:
        """Map the same checked input bytes to the original receipt shape."""
        data = self.read_protocol_input_bytes(protocol, path)
        return {"path": self.logical_path(path), "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest()}

    def history_paths_under(self, directory: Path) -> list[Path]:
        prefix = self.logical_path(directory).rstrip("/") + "/"
        return [self.root / relative for relative in sorted(self.history)
                if relative.startswith(prefix)]

    def require_local_execution(self, path: Path) -> None:
        relative = self.logical_path(path)
        if relative in self.history:
            raise RuntimeError(f"T2 historical source is data and cannot be executed: {relative}")
        self._local_file(path)

    def describe(self) -> dict[str, Any]:
        self._check_current_helpers()
        if self.frozen_snapshot is not None:
            self.frozen_snapshot.verify_frozen_identity()
        # Also check the archive identity even if no historical read is needed
        # by a particular stage. Enter/exit includes full streaming SHA checks.
        with self._reader():
            pass
        helpers = {}
        for relative, expected in (
                (INDEX_RELATIVE, INDEX_SHA256),
                (READER_RELATIVE, READER_SHA256),
                (BINDING_RELATIVE, _LOADED_BINDING_SHA256)):
            if self.frozen_snapshot is not None and relative == READER_RELATIVE:
                expected = self._snapshot_entry(relative)["sha256"]
            data = self.read_bytes(self.root / relative)
            actual = hashlib.sha256(data).hexdigest()
            if actual != expected:
                raise RuntimeError(f"T2 source layout helper drift: {relative}")
            helpers[relative] = {"path": relative, "bytes": len(data),
                                 "sha256": actual}
        return {
            "schema": "vnext-t2-explicit-source-layout-v1",
            "snapshot_id": SNAPSHOT_ID,
            "archive": {"path": ARCHIVE_PATH.as_posix(), "bytes": ARCHIVE_BYTES,
                        "sha256": ARCHIVE_SHA256},
            "binding_inputs": helpers,
            "historical_source_data": dict(sorted(self.history.items())),
            "historical_execution_allowed": False,
            "implicit_local_fallback_allowed": False,
        }

    def verify_protocol_layout(self, protocol: dict[str, Any]) -> None:
        actual = self.describe()
        if protocol.get("source_layout") != actual:
            raise RuntimeError("T2 protocol source layout differs from the frozen binding")
        pins = protocol.get("inputs")
        if not isinstance(pins, dict):
            raise RuntimeError("T2 protocol source inputs are absent")
        for relative, expected in {
                **actual["historical_source_data"], **actual["binding_inputs"]}.items():
            if pins.get(relative) != expected:
                raise RuntimeError(f"T2 protocol omitted or changed a source binding: {relative}")
