"""Safe offline intake for a local authority-channel dropbox.

The source file is opened read-only and is never moved, deleted, or modified.
Accepted canonical bytes are copied into a content-addressed store and every
attempt receives a local bookkeeping receipt.  The receipt is *not* an
external signature and cannot satisfy the UP1 external-authority gate.
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import stat
import tempfile
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = "UP1.authority-intake-envelope.v1"
RECEIPT_SCHEMA_VERSION = "UP1.local-intake-receipt.v1"
MAX_BYTES_DEFAULT = 1_048_576
_SAFE_ID = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")
_FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
_WINDOWS_HANDLE_IO_SUPPORTED = os.name == "nt"

if _WINDOWS_HANDLE_IO_SUPPORTED:
    import ctypes
    import ctypes.wintypes as _wintypes
    import msvcrt

    _kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    _CreateFileW = _kernel32.CreateFileW
    _CreateFileW.argtypes = [_wintypes.LPCWSTR, _wintypes.DWORD, _wintypes.DWORD,
                             ctypes.c_void_p, _wintypes.DWORD, _wintypes.DWORD, _wintypes.HANDLE]
    _CreateFileW.restype = _wintypes.HANDLE
    _CloseHandle = _kernel32.CloseHandle
    _CloseHandle.argtypes = [_wintypes.HANDLE]
    _CloseHandle.restype = _wintypes.BOOL
    _GetFinalPathNameByHandleW = _kernel32.GetFinalPathNameByHandleW
    _GetFinalPathNameByHandleW.argtypes = [_wintypes.HANDLE, _wintypes.LPWSTR, _wintypes.DWORD, _wintypes.DWORD]
    _GetFinalPathNameByHandleW.restype = _wintypes.DWORD
    _GetFileInformationByHandle = _kernel32.GetFileInformationByHandle
    _GetFileInformationByHandle.argtypes = [_wintypes.HANDLE, ctypes.c_void_p]
    _GetFileInformationByHandle.restype = _wintypes.BOOL
    _GENERIC_READ = 0x80000000
    _GENERIC_WRITE = 0x40000000
    _FILE_SHARE_READ = 0x00000001
    _FILE_SHARE_WRITE = 0x00000002
    _FILE_SHARE_DELETE = 0x00000004
    _OPEN_EXISTING = 3
    _CREATE_NEW = 1
    _FILE_ATTRIBUTE_NORMAL = 0x80
    _FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000
    _ERROR_FILE_NOT_FOUND = 2
    _ERROR_PATH_NOT_FOUND = 3
    _ERROR_FILE_EXISTS = 80
    _ERROR_ALREADY_EXISTS = 183

    class _BY_HANDLE_FILE_INFORMATION(ctypes.Structure):
        _fields_ = [
            ("dwFileAttributes", _wintypes.DWORD), ("ftCreationTime", _wintypes.FILETIME),
            ("ftLastAccessTime", _wintypes.FILETIME), ("ftLastWriteTime", _wintypes.FILETIME),
            ("dwVolumeSerialNumber", _wintypes.DWORD), ("nFileSizeHigh", _wintypes.DWORD),
            ("nFileSizeLow", _wintypes.DWORD), ("nNumberOfLinks", _wintypes.DWORD),
            ("nFileIndexHigh", _wintypes.DWORD), ("nFileIndexLow", _wintypes.DWORD),
        ]


def _strip_extended_path(value: str) -> str:
    if value.startswith("\\\\?\\UNC\\"):
        return "\\\\" + value[8:]
    if value.startswith("\\\\?\\"):
        return value[4:]
    return value


def _norm_path(value: str | os.PathLike[str]) -> str:
    return os.path.normcase(os.path.abspath(_strip_extended_path(os.fspath(value))))


def _same_path(left: str | os.PathLike[str], right: str | os.PathLike[str]) -> bool:
    try:
        return _norm_path(left) == _norm_path(right)
    except (TypeError, ValueError):
        return False


def _windows_handle_facts(handle: Any, expected: Path, boundary: Path, code: str) -> tuple[str, tuple[int, int]]:
    """Validate final path, identity, and reparse state on the opened handle."""
    if not _WINDOWS_HANDLE_IO_SUPPORTED:
        raise IntakeError("handle_pinned_io_unsupported", "mutable spool requires Windows handle-pinned I/O")
    info = _BY_HANDLE_FILE_INFORMATION()
    if not _GetFileInformationByHandle(handle, ctypes.byref(info)):
        raise IntakeError(code, "GetFileInformationByHandle failed")
    if info.dwFileAttributes & _FILE_ATTRIBUTE_REPARSE_POINT:
        raise IntakeError(code, "opened object is a reparse point")
    buffer_len = 512
    while buffer_len <= 32768:
        buffer = ctypes.create_unicode_buffer(buffer_len)
        length = _GetFinalPathNameByHandleW(handle, buffer, buffer_len, 0)
        if length == 0:
            raise IntakeError(code, "GetFinalPathNameByHandleW failed")
        if length < buffer_len - 1:
            final_path = _strip_extended_path(buffer.value)
            break
        buffer_len *= 2
    else:
        raise IntakeError(code, "final path is too long")
    try:
        _norm_path(final_path).replace(_norm_path(boundary), "", 1)
        if os.path.commonpath([_norm_path(final_path), _norm_path(boundary)]) != _norm_path(boundary):
            raise IntakeError(code, "opened object escaped spool root")
    except ValueError as exc:
        raise IntakeError(code, "opened object path has incompatible root") from exc
    if not _same_path(final_path, expected):
        raise IntakeError(code, "opened final path differs from requested path")
    file_id = (int(info.dwVolumeSerialNumber), (int(info.nFileIndexHigh) << 32) | int(info.nFileIndexLow))
    return final_path, file_id


def _windows_open(path: Path, *, write: bool, create_new: bool = False) -> Any:
    if not _WINDOWS_HANDLE_IO_SUPPORTED:
        raise IntakeError("handle_pinned_io_unsupported", "mutable spool requires Windows handle-pinned I/O")
    access = _GENERIC_READ | (_GENERIC_WRITE if write else 0)
    disposition = _CREATE_NEW if create_new else _OPEN_EXISTING
    handle = _CreateFileW(str(path), access,
                          _FILE_SHARE_READ | _FILE_SHARE_WRITE | _FILE_SHARE_DELETE,
                          None, disposition,
                          _FILE_ATTRIBUTE_NORMAL | _FILE_FLAG_OPEN_REPARSE_POINT, None)
    invalid = ctypes.c_void_p(-1).value
    if handle in (None, invalid):
        error = ctypes.get_last_error()
        if create_new and error in (_ERROR_FILE_EXISTS, _ERROR_ALREADY_EXISTS):
            raise IntakeError("output_exists", "destination already exists")
        raise IntakeError("open_failed", f"CreateFileW failed: {error}")
    return handle


def _windows_read_owned(path: Path, boundary: Path, max_bytes: int | None = None) -> tuple[bytes, tuple[int, int]]:
    handle = _windows_open(path, write=False)
    fd = None
    try:
        _, file_id = _windows_handle_facts(handle, path, boundary, "reparse_input")
        fd = msvcrt.open_osfhandle(int(handle), os.O_RDONLY | getattr(os, "O_BINARY", 0))
        handle = None  # ownership transferred to fd
        info = os.fstat(fd)
        if max_bytes is not None and info.st_size > max_bytes:
            raise IntakeError("oversize", "input exceeds configured size limit",
                              max_bytes=max_bytes, source_size=info.st_size,
                              bytes_available=False, quarantine_copy="not_attempted_because_size_limit")
        chunks: list[bytes] = []
        while True:
            chunk = os.read(fd, 131072)
            if not chunk:
                break
            chunks.append(chunk)
            if max_bytes is not None and sum(map(len, chunks)) > max_bytes:
                raise IntakeError("toctou", "opened input exceeded size limit while being read")
        data = b"".join(chunks)
        return data, file_id
    finally:
        if fd is not None:
            os.close(fd)
        elif handle is not None:
            _CloseHandle(handle)


def _windows_write_owned(path: Path, data: bytes, boundary: Path, *, create_new: bool = False) -> bool:
    """Write only through a handle whose final path and file identity were checked."""
    # Validate every existing parent before mkdir/open.  In particular, do not
    # let a junction substituted between callers' path checks and this write
    # redirect an adapter-owned artifact outside the spool.
    _assert_no_symlink_components(path.parent, boundary, "reparse_output")
    path.parent.mkdir(parents=True, exist_ok=True)
    _assert_no_symlink_components(path.parent, boundary, "reparse_output")
    try:
        handle = _windows_open(path, write=True, create_new=create_new)
        created = create_new
    except IntakeError as error:
        if not create_new or error.code != "output_exists":
            raise
        return False
    fd = None
    try:
        _windows_handle_facts(handle, path, boundary, "reparse_output")
        fd = msvcrt.open_osfhandle(int(handle), os.O_RDWR | getattr(os, "O_BINARY", 0))
        handle = None
        os.ftruncate(fd, 0)
        view = memoryview(data)
        while view:
            written = os.write(fd, view)
            if written <= 0:
                raise IntakeError("write_failed", "short write to handle-pinned output")
            view = view[written:]
        os.fsync(fd)
        return created
    finally:
        if fd is not None:
            os.close(fd)
        elif handle is not None:
            _CloseHandle(handle)


class IntakeError(ValueError):
    """A stable, fail-closed intake error."""

    def __init__(self, code: str, message: str, **details: Any) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def _canonical_bytes(value: Any) -> bytes:
    """Return deterministic UTF-8 JSON and reject duplicate/non-finite JSON."""

    try:
        return json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        ).encode("utf-8")
    except (TypeError, ValueError, UnicodeEncodeError) as exc:
        raise IntakeError("noncanonical_json", "payload is not canonical JSON") from exc


def _loads_unique(raw: bytes) -> Any:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IntakeError("invalid_utf8", "input is not UTF-8") from exc

    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        out: dict[str, Any] = {}
        for key, value in items:
            if key in out:
                raise IntakeError("duplicate_json_key", f"duplicate key: {key}")
            out[key] = value
        return out

    try:
        value = json.loads(text, object_pairs_hook=pairs, parse_constant=lambda x: (_ for _ in ()).throw(ValueError(x)))
    except IntakeError:
        raise
    except (json.JSONDecodeError, ValueError, TypeError) as exc:
        raise IntakeError("invalid_json", "input is not valid JSON") from exc
    if not isinstance(value, dict):
        raise IntakeError("schema_type", "envelope must be a JSON object")
    return value


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _stable_digest_matches(path: Path, expected: str, boundary: Path | None = None) -> bool:
    """Read an owned CAS object and reject replacement during verification."""
    if _WINDOWS_HANDLE_IO_SUPPORTED:
        try:
            data, _ = _windows_read_owned(path, boundary or Path(path.anchor), None)
            return _sha256(data) == expected
        except IntakeError:
            return False
    try:
        before = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(before.st_mode):
            return False
        flags = os.O_RDONLY | (os.O_BINARY if hasattr(os, "O_BINARY") else 0)
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        fd = os.open(path, flags)
        try:
            opened = os.fstat(fd)
            if (opened.st_size, getattr(opened, "st_ino", 0)) != (before.st_size, getattr(before, "st_ino", 0)):
                return False
            data = bytearray()
            while True:
                chunk = os.read(fd, 131072)
                if not chunk:
                    break
                data.extend(chunk)
            after = os.stat(path, follow_symlinks=False)
            if (after.st_size, after.st_mtime_ns, getattr(after, "st_ino", 0)) != (before.st_size, before.st_mtime_ns, getattr(before, "st_ino", 0)):
                return False
            return _sha256(bytes(data)) == expected
        finally:
            os.close(fd)
    except OSError:
        return False


def _is_reparse_point(path: Path) -> bool:
    """Detect symlinks, junctions, and Windows FILE_ATTRIBUTE_REPARSE_POINT."""
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attributes = getattr(os.lstat(path), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    return bool(attributes & _FILE_ATTRIBUTE_REPARSE_POINT)


def _assert_no_symlink_components(path: Path, boundary: Path, code: str) -> None:
    """Reject links/reparse points in a path without resolving them first."""
    current = path
    boundary = boundary.absolute()
    while True:
        if _is_reparse_point(current):
            raise IntakeError(code, "adapter-owned path contains a symlink, junction, or reparse point")
        if current == boundary:
            return
        if current.parent == current:
            raise IntakeError(code, "adapter-owned path escaped spool root")
        current = current.parent


def _safe_identifier(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 256 or any(c not in _SAFE_ID for c in value):
        raise IntakeError("invalid_identifier", f"{name} must be a bounded identifier")
    return value


def _atomic_write(path: Path, data: bytes, boundary: Path | None = None, *, create_only: bool = False) -> None:
    if _WINDOWS_HANDLE_IO_SUPPORTED and boundary is not None:
        _assert_no_symlink_components(path.parent, boundary, "reparse_output")
        if create_only and path.exists():
            try:
                existing, _ = _windows_read_owned(path, boundary, None)
            except IntakeError as verify_error:
                raise IntakeError("output_collision", "immutable output could not be verified") from verify_error
            if existing != data:
                raise IntakeError("output_collision", "immutable output exists with different bytes")
            return
        try:
            if create_only:
                created = _windows_write_owned(path, data, boundary, create_new=True)
                if not created:
                    existing, _ = _windows_read_owned(path, boundary, None)
                    if existing != data:
                        raise IntakeError("output_collision", "immutable output exists with different bytes")
                return
            _windows_write_owned(path, data, boundary, create_new=False)
        except IntakeError as error:
            if create_only:
                raise
            if error.code != "open_failed":
                raise
            created = _windows_write_owned(path, data, boundary, create_new=True)
            if not created:
                # A creator may have won the missing-path race.  Never treat
                # that as success unless the handle-pinned bytes are exactly
                # the bytes this transaction intended to install.
                try:
                    existing, _ = _windows_read_owned(path, boundary, None)
                except IntakeError as verify_error:
                    raise IntakeError("output_collision", "output appeared but could not be verified") from verify_error
                if existing != data:
                    raise IntakeError("output_collision", "output exists with different bytes")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    if create_only and path.exists():
        if path.is_file() and path.read_bytes() == data:
            return
        raise IntakeError("output_collision", "immutable output exists with different bytes")
    if create_only:
        temporary = path.with_name(f".{path.name}.{secrets.token_hex(8)}.tmp")
        try:
            with temporary.open("xb") as handle:
                handle.write(data)
                handle.flush()
                os.fsync(handle.fileno())
            try:
                os.link(temporary, path)
            except FileExistsError:
                if not path.is_file() or path.read_bytes() != data:
                    raise IntakeError("output_collision", "immutable output exists with different bytes")
            return
        finally:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass
    fd, temporary = tempfile.mkstemp(prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def _atomic_cas(path: Path, data: bytes, boundary: Path | None = None) -> bool:
    """Install data atomically; return False when the same object already exists."""
    if boundary is not None:
        _assert_no_symlink_components(path, boundary, "cas_symlink")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink():
        raise IntakeError("cas_symlink", "CAS destination may not be a symlink")
    if path.exists():
        if not path.is_file() or not _stable_digest_matches(path, path.stem, boundary):
            raise IntakeError("cas_collision", "CAS path exists with a different digest")
        return False
    if _WINDOWS_HANDLE_IO_SUPPORTED and boundary is not None:
        created = _windows_write_owned(path, data, boundary, create_new=True)
        if not created:
            # CREATE_NEW losing a race is only a duplicate when the existing
            # object still verifies against the requested content-addressed
            # digest through its own pinned handle.
            if not path.is_file() or not _stable_digest_matches(path, path.stem, boundary):
                raise IntakeError("cas_collision", "CAS path appeared with a different or unverifiable digest")
        return created
    temporary = path.with_name(f".{path.name}.{secrets.token_hex(8)}.tmp")
    try:
        with temporary.open("xb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        # The destination is a digest-derived name.  A pre-existing identical
        # object is harmless; verify it rather than overwriting it.
        try:
            os.link(temporary, path)
        except FileExistsError:
            if not path.is_file() or not _stable_digest_matches(path, path.stem, boundary):
                raise IntakeError("cas_collision", "CAS path exists with a different digest")
            return False
        return True
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


class AuthorityIntakeAdapter:
    """Read-only local spool adapter.

    Layout is ``incoming/``, ``accepted/`` (informational), ``quarantine/``,
    ``cas/sha256/``, ``receipts/`` and ``state/ledger.json``.  The adapter only
    reads from ``incoming`` and writes its own derived artifacts elsewhere.
    """

    def __init__(self, spool_root: str | os.PathLike[str], max_bytes: int = MAX_BYTES_DEFAULT) -> None:
        if not isinstance(max_bytes, int) or max_bytes <= 0:
            raise ValueError("max_bytes must be positive")
        self.root = Path(spool_root).absolute()
        _assert_no_symlink_components(self.root, self.root.anchor and Path(self.root.anchor), "spool_reparse")
        if self.root.exists() and not self.root.is_dir():
            raise IntakeError("spool_not_directory", "spool root must be a directory")
        self.root.mkdir(parents=True, exist_ok=True)
        if _is_reparse_point(self.root):
            raise IntakeError("spool_reparse", "spool root may not be a symlink, junction, or reparse point")
        resolved_root = self.root.resolve(strict=True)
        if resolved_root != self.root:
            raise IntakeError("spool_reparse", "spool root resolved through a reparse point")
        self.max_bytes = max_bytes
        self.incoming = self.root / "incoming"
        self.quarantine = self.root / "quarantine"
        self.cas = self.root / "cas" / "sha256"
        self.receipts = self.root / "receipts"
        self.state = self.root / "state"
        self.ledger_path = self.state / "ledger.json"
        self._before_input_open = None
        self._before_output_open = None
        for directory in (self.incoming, self.quarantine, self.cas, self.receipts, self.state):
            # Check existing components before mkdir: mkdir(exist_ok=True)
            # would otherwise follow a pre-existing junction in a parent.
            _assert_no_symlink_components(directory, self.root, "spool_reparse")
            directory.mkdir(parents=True, exist_ok=True)
            _assert_no_symlink_components(directory, self.root, "spool_reparse")
            if not directory.is_dir():
                raise IntakeError("spool_not_directory", "adapter-owned path must be a directory")

    def _validate_source_path(self, source: str | os.PathLike[str]) -> Path:
        raw = Path(source)
        if raw.is_absolute():
            raise IntakeError("absolute_path", "input paths must be relative to incoming")
        candidate = self.incoming / raw
        candidate_absolute = candidate.absolute()
        try:
            candidate_absolute.relative_to(self.incoming.absolute())
        except ValueError as exc:
            raise IntakeError("path_traversal", "input is outside incoming directory") from exc
        _assert_no_symlink_components(candidate_absolute, self.root, "reparse_input")
        try:
            resolved = candidate_absolute.resolve(strict=True)
        except (FileNotFoundError, OSError) as exc:
            raise IntakeError("input_missing", "input does not exist") from exc
        try:
            resolved.relative_to(self.incoming.resolve())
            resolved.relative_to(self.root.resolve())
        except ValueError as exc:
            raise IntakeError("path_traversal", "input is outside incoming directory") from exc
        # Reject symlinks in every component, including a link that resolves
        # back inside the spool.  This closes the obvious replacement race.
        current = self.incoming.resolve()
        relative = resolved.relative_to(current)
        for part in relative.parts:
            current = current / part
            if current.is_symlink():
                raise IntakeError("symlink_input", "symlink input is not accepted")
        info = os.stat(resolved, follow_symlinks=False)
        if not stat.S_ISREG(info.st_mode):
            raise IntakeError("not_regular_file", "input must be a regular file")
        return resolved

    def _read_stable(self, source: Path) -> bytes:
        if _WINDOWS_HANDLE_IO_SUPPORTED:
            data, _ = _windows_read_owned(source, self.root, self.max_bytes)
            return data
        before = os.stat(source, follow_symlinks=False)
        if before.st_size > self.max_bytes:
            raise IntakeError("oversize", "input exceeds configured size limit",
                              max_bytes=self.max_bytes, source_size=before.st_size,
                              bytes_available=False,
                              quarantine_copy="not_attempted_because_size_limit")
        flags = os.O_RDONLY
        if hasattr(os, "O_BINARY"):
            flags |= os.O_BINARY
        if hasattr(os, "O_NOFOLLOW"):
            flags |= os.O_NOFOLLOW
        try:
            fd = os.open(source, flags)
        except OSError as exc:
            raise IntakeError("read_failed", "could not open input read-only") from exc
        try:
            opened = os.fstat(fd)
            if not stat.S_ISREG(opened.st_mode) or opened.st_size != before.st_size:
                raise IntakeError("toctou", "input changed during open")
            chunks: list[bytes] = []
            remaining = self.max_bytes + 1
            while remaining:
                chunk = os.read(fd, min(131072, remaining))
                if not chunk:
                    break
                chunks.append(chunk)
                remaining -= len(chunk)
            data = b"".join(chunks)
            after = os.stat(source, follow_symlinks=False)
            if len(data) > self.max_bytes or after.st_size != before.st_size:
                raise IntakeError("toctou", "input size changed while being read")
            identity = (before.st_size, before.st_mtime_ns, getattr(before, "st_ino", 0))
            identity_after = (after.st_size, after.st_mtime_ns, getattr(after, "st_ino", 0))
            if identity != identity_after:
                raise IntakeError("toctou", "input metadata changed while being read")
            return data
        finally:
            os.close(fd)

    def _quarantine_copy(self, raw: bytes, source_hash: str, error: IntakeError) -> str:
        path = self.quarantine / f"{source_hash}.bin"
        _assert_no_symlink_components(path, self.root, "quarantine_symlink")
        if path.is_symlink():
            raise IntakeError("quarantine_symlink", "quarantine destination may not be a symlink")
        if not path.exists():
            _atomic_write(path, raw, self.root)
        elif not path.is_file() or not _stable_digest_matches(path, source_hash, self.root):
            raise IntakeError("quarantine_collision", "quarantine path exists with a different digest")
        metadata = {
            "schema_version": RECEIPT_SCHEMA_VERSION,
            "source_sha256": source_hash,
            "error_code": error.code,
            "error_message": error.message,
            "local_only": True,
            "external_authority_claim": False,
        }
        _atomic_write(self.quarantine / f"{source_hash}.json", _canonical_bytes(metadata), self.root)
        return str(path.relative_to(self.root).as_posix())

    def _load_ledger(self) -> dict[str, Any]:
        if self.ledger_path.is_symlink():
            raise IntakeError("ledger_symlink", "intake ledger may not be a symlink")
        if not self.ledger_path.exists():
            return {"schema_version": "UP1.authority-intake-ledger.v1", "entries": {}, "last_sequence": {}}
        try:
            if _WINDOWS_HANDLE_IO_SUPPORTED:
                ledger_raw, _ = _windows_read_owned(self.ledger_path, self.root, None)
            else:
                ledger_raw = self.ledger_path.read_bytes()
            ledger = _loads_unique(ledger_raw)
        except IntakeError as exc:
            raise IntakeError("ledger_invalid", "intake ledger is invalid") from exc
        if not isinstance(ledger.get("entries"), dict) or not isinstance(ledger.get("last_sequence"), dict):
            raise IntakeError("ledger_invalid", "intake ledger shape is invalid")
        return ledger

    @contextmanager
    def _ledger_lock(self):
        """Cross-process exclusive lock for the ledger read/modify/write."""
        lock_path = self.state / ".ledger.lock"
        _assert_no_symlink_components(lock_path, self.root, "ledger_symlink")
        deadline = time.monotonic() + 15.0
        while True:
            try:
                if _WINDOWS_HANDLE_IO_SUPPORTED:
                    created = _windows_write_owned(lock_path, str(os.getpid()).encode("ascii"), self.root, create_new=True)
                    if not created:
                        raise IntakeError("output_exists", "destination already exists")
                else:
                    fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                    os.write(fd, str(os.getpid()).encode("ascii"))
                    os.close(fd)
                break
            except (FileExistsError, IntakeError) as error:
                if isinstance(error, IntakeError) and error.code not in {"output_exists"}:
                    raise
                if time.monotonic() >= deadline:
                    raise IntakeError("ledger_busy", "timed out acquiring intake ledger lock")
                time.sleep(0.01)
        try:
            yield
        finally:
            try:
                lock_path.unlink()
            except FileNotFoundError:
                pass

    def _write_ledger(self, ledger: dict[str, Any]) -> None:
        _assert_no_symlink_components(self.ledger_path, self.root, "ledger_symlink")
        _atomic_write(self.ledger_path, _canonical_bytes(ledger), self.root)

    def _receipt(self, *, outcome: str, source_hash: str, canonical_hash: str | None, source: Path,
                 error: IntakeError | None = None, cas_path: str | None = None, entry: dict[str, Any] | None = None) -> dict[str, Any]:
        receipt: dict[str, Any] = {
            "schema_version": RECEIPT_SCHEMA_VERSION,
            "receipt_id": f"local-{secrets.token_hex(16)}",
            "issued_utc": _utc_now(),
            "pid": os.getpid(),
            "outcome": outcome,
            "source_name": source.name,
            "source_sha256": source_hash,
            "canonical_payload_sha256": canonical_hash,
            "cas_path": cas_path,
            "entry": entry,
            "sender_id": entry.get("sender_id") if entry else None,
            "authority_channel_id": entry.get("authority_channel_id") if entry else None,
            "external_endpoint_state": "typed_absence",
            "typed_absence": True,
            "typed_absence_reason": "real external endpoint/channel is not configured in this offline adapter",
            "external_channel_ack": None,
            "external_signature_state": "not_verified",
            "signature": None,
            "local_bookkeeping_only": True,
            "claim_ceiling": "software_bookkeeping_only",
            "no_network_or_message_sent": True,
            "external_authority_claim": False,
        }
        if error is not None:
            receipt["error"] = {"code": error.code, "message": error.message, "details": error.details}
        digest_input = _canonical_bytes(receipt)
        receipt["receipt_sha256"] = _sha256(digest_input)
        return receipt

    def _persist_receipt(self, receipt: dict[str, Any]) -> str:
        digest = receipt["receipt_sha256"]
        path = self.receipts / f"{digest}.json"
        _assert_no_symlink_components(path, self.root, "receipt_symlink")
        _atomic_write(path, _canonical_bytes(receipt), self.root, create_only=True)
        return str(path.relative_to(self.root).as_posix())

    def _quarantined_result(self, raw: bytes, source_hash: str, canonical_hash: str | None,
                            source_path: Path, error: IntakeError, entry: dict[str, Any] | None = None) -> dict[str, Any]:
        quarantine_path = self._quarantine_copy(raw, source_hash, error)
        receipt = self._receipt(outcome="quarantined", source_hash=source_hash,
                                canonical_hash=canonical_hash, source=source_path,
                                error=error, entry=entry)
        receipt["quarantine_path"] = quarantine_path
        receipt["receipt_sha256"] = _sha256(_canonical_bytes({k: v for k, v in receipt.items() if k != "receipt_sha256"}))
        return {"ok": False, "outcome": "quarantined",
                "error": {"code": error.code, "message": error.message},
                "quarantine_path": quarantine_path, "receipt": self._persist_receipt(receipt)}

    def _commit_valid(self, *, raw: bytes, source_hash: str, canonical: bytes,
                      canonical_hash: str, source_path: Path, sender: str,
                      channel: str, nonce: str, sequence: int, idem: str) -> dict[str, Any]:
        """Validate and commit one envelope while holding the process lock."""
        with self._ledger_lock():
            ledger = self._load_ledger()
            key = f"{sender}/{channel}"
            entry = ledger["entries"].get(idem)
            if entry is not None:
                if (entry.get("canonical_payload_sha256") == canonical_hash
                        and entry.get("sender_id") == sender
                        and entry.get("authority_channel_id") == channel):
                    cas_ref = entry.get("cas_path")
                    cas_path = self.root / str(cas_ref) if isinstance(cas_ref, str) else self.root / "__invalid__"
                    try:
                        cas_path.absolute().relative_to(self.root.absolute())
                        _assert_no_symlink_components(cas_path, self.root, "cas_symlink")
                        cas_ok = cas_path.is_file() and _stable_digest_matches(cas_path, canonical_hash, self.root)
                    except (OSError, ValueError, IntakeError):
                        cas_ok = False
                    if not cas_ok:
                        return self._quarantined_result(
                            raw, source_hash, canonical_hash, source_path,
                            IntakeError("cas_missing", "ledger entry references a missing or invalid CAS object"), entry)
                    receipt = self._receipt(outcome="duplicate", source_hash=source_hash,
                                            canonical_hash=canonical_hash, source=source_path, entry=entry)
                    return {"ok": True, "outcome": "duplicate", "receipt": self._persist_receipt(receipt), "entry": entry}
                return self._quarantined_result(
                    raw, source_hash, canonical_hash, source_path,
                    IntakeError("idempotency_conflict", "idempotency key is already bound to different content"), entry)
            last = ledger["last_sequence"].get(key, 0)
            if sequence <= last:
                return self._quarantined_result(
                    raw, source_hash, canonical_hash, source_path,
                    IntakeError("sequence_replay", "sequence is not greater than the last accepted sequence", last_sequence=last))
            nonce_key = f"{sender}/{channel}/{nonce}"
            for old in ledger["entries"].values():
                if old.get("nonce_key") == nonce_key:
                    return self._quarantined_result(
                        raw, source_hash, canonical_hash, source_path,
                        IntakeError("nonce_replay", "nonce has already been consumed"), old)
            cas_path = self.cas / canonical_hash[:2] / f"{canonical_hash}.json"
            try:
                if callable(self._before_output_open):
                    self._before_output_open(cas_path)
                _assert_no_symlink_components(cas_path, self.root, "cas_symlink")
                _atomic_cas(cas_path, canonical, self.root)
            except IntakeError as error:
                return self._quarantined_result(raw, source_hash, canonical_hash, source_path, error)
            new_entry = {
                "sender_id": sender,
                "authority_channel_id": channel,
                "nonce_key": nonce_key,
                "sequence": sequence,
                "idempotency_key": idem,
                "canonical_payload_sha256": canonical_hash,
                "source_sha256": source_hash,
                "cas_path": str(cas_path.relative_to(self.root).as_posix()),
            }
            ledger["entries"][idem] = new_entry
            ledger["last_sequence"][key] = sequence
            self._write_ledger(ledger)
            receipt = self._receipt(outcome="accepted_local", source_hash=source_hash,
                                    canonical_hash=canonical_hash, source=source_path,
                                    cas_path=new_entry["cas_path"], entry=new_entry)
            return {"ok": True, "outcome": "accepted_local", "receipt": self._persist_receipt(receipt), "entry": new_entry}

    def intake(self, source: str | os.PathLike[str]) -> dict[str, Any]:
        """Attempt one input and return a JSON-serializable result."""
        if not _WINDOWS_HANDLE_IO_SUPPORTED:
            error = IntakeError("handle_pinned_io_unsupported", "mutable spool requires Windows handle-pinned I/O")
            return {"ok": False, "outcome": "unsupported",
                    "error": {"code": error.code, "message": error.message}}
        try:
            source_path = self._validate_source_path(source)
        except IntakeError as error:
            # No bytes are available for a quarantine copy in this case.
            return {"ok": False, "outcome": "rejected", "error": {"code": error.code, "message": error.message}}
        try:
            if callable(self._before_input_open):
                self._before_input_open(source_path)
            raw = self._read_stable(source_path)
        except IntakeError as error:
            # A stable pre-read hash is unavailable on a TOCTOU failure; a
            # receipt still identifies the attempted path without claiming data.
            receipt = self._receipt(outcome="rejected", source_hash="", canonical_hash=None, source=source_path, error=error)
            receipt["raw_unavailable"] = True
            receipt["quarantine_copy"] = "not_attempted"
            receipt["receipt_sha256"] = _sha256(_canonical_bytes({k: v for k, v in receipt.items() if k != "receipt_sha256"}))
            return {"ok": False, "outcome": "rejected", "error": {"code": error.code, "message": error.message}, "receipt": self._persist_receipt(receipt)}
        source_hash = _sha256(raw)
        try:
            envelope = _loads_unique(raw)
            allowed = {"schema_version", "sender_id", "authority_channel_id", "nonce", "sequence", "idempotency_key", "payload", "external_signature"}
            unknown = set(envelope) - allowed
            if unknown:
                raise IntakeError("unknown_field", "unknown envelope field", fields=sorted(unknown))
            if envelope.get("schema_version") != SCHEMA_VERSION:
                raise IntakeError("schema_version_unsupported", "unsupported envelope schema version")
            sender = _safe_identifier(envelope.get("sender_id"), "sender_id")
            channel = _safe_identifier(envelope.get("authority_channel_id"), "authority_channel_id")
            nonce = _safe_identifier(envelope.get("nonce"), "nonce")
            idem = _safe_identifier(envelope.get("idempotency_key"), "idempotency_key")
            sequence = envelope.get("sequence")
            if isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 1 or sequence > 2**63 - 1:
                raise IntakeError("sequence_invalid", "sequence must be a positive integer")
            if "payload" not in envelope:
                raise IntakeError("payload_missing", "payload is required")
            # The external signature is retained only as input data.  It is
            # never parsed, trusted, or copied into a signature claim.
            canonical = _canonical_bytes(envelope)
            canonical_hash = _sha256(canonical)
        except IntakeError as error:
            quarantine_path = self._quarantine_copy(raw, source_hash, error)
            receipt = self._receipt(outcome="quarantined", source_hash=source_hash, canonical_hash=None, source=source_path, error=error)
            receipt["quarantine_path"] = quarantine_path
            receipt["receipt_sha256"] = _sha256(_canonical_bytes({k: v for k, v in receipt.items() if k != "receipt_sha256"}))
            return {"ok": False, "outcome": "quarantined", "error": {"code": error.code, "message": error.message}, "quarantine_path": quarantine_path, "receipt": self._persist_receipt(receipt)}

        return self._commit_valid(raw=raw, source_hash=source_hash, canonical=canonical,
                                  canonical_hash=canonical_hash, source_path=source_path,
                                  sender=sender, channel=channel, nonce=nonce,
                                  sequence=sequence, idem=idem)

    def scan(self) -> list[dict[str, Any]]:
        """Intake regular JSON files in incoming without changing them."""
        results: list[dict[str, Any]] = []
        for path in sorted(self.incoming.iterdir(), key=lambda item: item.name):
            if path.is_file() and path.suffix.lower() == ".json":
                results.append(self.intake(path.relative_to(self.incoming)))
        return results
