"""Bounded, traversal-safe local file reads for evidence inspection."""

from __future__ import annotations

import os
import stat as stat_module
from pathlib import Path
from typing import Any

from .canonical import (
    CyclicValueError,
    DuplicateKeyError,
    InvalidUTF8Error,
    NonCanonicalJSONError,
    NonCanonicalNumberError,
    NonFiniteNumberError,
    SyntaxJSONError,
    UnsupportedValueError,
    parse_json,
)
from .taxonomy import ErrorCode, EvidenceError, TypedError

MAX_FILE_BYTES = 16 * 1024 * 1024


class SafeFileError(EvidenceError):
    pass


def safe_relative_path(path: str | os.PathLike[str]) -> str:
    """Normalize a manifest path and reject absolute/traversal forms."""
    text = os.fspath(path).replace("\\", "/")
    if not text or text.startswith("/") or text.startswith("//"):
        raise SafeFileError(TypedError(ErrorCode.PATH_ESCAPE.value, "absolute or empty path is not allowed", text))
    drive, _ = os.path.splitdrive(text)
    if drive or (len(text) >= 2 and text[1] == ":"):
        raise SafeFileError(TypedError(ErrorCode.PATH_ESCAPE.value, "drive-qualified path is not allowed", text))
    parts = text.split("/")
    if any(part in ("", ".") for part in parts):
        parts = [part for part in parts if part not in ("", ".")]
    if any(part == ".." for part in parts):
        raise SafeFileError(TypedError(ErrorCode.PATH_ESCAPE.value, "path traversal is not allowed", text))
    if not parts:
        raise SafeFileError(TypedError(ErrorCode.PATH_ESCAPE.value, "empty path is not allowed", text))
    return "/".join(parts)


def _same_file(left: os.stat_result, right: os.stat_result) -> bool:
    # st_ino is available on Windows (and is the useful replacement detector);
    # size/mtime catches in-place writes while the descriptor is being read.
    return (left.st_mode & 0o170000) == stat_module.S_IFREG and \
        (right.st_mode & 0o170000) == stat_module.S_IFREG and \
        left.st_dev == right.st_dev and left.st_ino == right.st_ino and \
        left.st_size == right.st_size and left.st_mtime_ns == right.st_mtime_ns


def _open_checked(path: str | os.PathLike[str]):
    candidate = Path(path)
    try:
        before = os.lstat(candidate)
    except OSError as exc:
        raise SafeFileError(TypedError(ErrorCode.PATH_NOT_FILE.value, f"cannot stat file: {exc}", str(path))) from exc
    if (before.st_mode & 0o170000) != stat_module.S_IFREG:
        code = ErrorCode.SYMLINK_REJECTED.value if stat_module.S_ISLNK(before.st_mode) else ErrorCode.PATH_NOT_FILE.value
        raise SafeFileError(TypedError(code, "path is not a regular non-symlink file", str(path)))
    flags = os.O_RDONLY
    if hasattr(os, "O_BINARY"):
        flags |= os.O_BINARY
    try:
        fd = os.open(candidate, flags)
        opened = os.fstat(fd)
    except OSError as exc:
        if "fd" in locals():
            try:
                os.close(fd)
            except OSError:
                pass
        raise SafeFileError(TypedError(ErrorCode.PATH_NOT_FILE.value, f"cannot open file: {exc}", str(path))) from exc
    if not _same_file(before, opened):
        os.close(fd)
        raise SafeFileError(TypedError(ErrorCode.IDENTITY_MISMATCH.value, "file changed between lstat and open", str(path)))
    return fd, opened


def read_bytes_limited(path: str | os.PathLike[str], *, max_bytes: int = MAX_FILE_BYTES) -> bytes:
    if not isinstance(max_bytes, int) or isinstance(max_bytes, bool) or max_bytes < 0:
        raise ValueError("max_bytes must be a non-negative integer")
    fd, opened = _open_checked(path)
    try:
        if opened.st_size > max_bytes:
            raise SafeFileError(TypedError(ErrorCode.FILE_TOO_LARGE.value, f"file exceeds {max_bytes} bytes", str(path)))
        data = b""
        while len(data) <= max_bytes:
            chunk = os.read(fd, min(1024 * 1024, max_bytes + 1 - len(data)))
            if not chunk:
                break
            data += chunk
        after = os.fstat(fd)
    except SafeFileError:
        os.close(fd)
        raise
    except OSError as exc:
        os.close(fd)
        raise SafeFileError(TypedError(ErrorCode.PATH_NOT_FILE.value, f"cannot read file: {exc}", str(path))) from exc
    finally:
        try:
            os.close(fd)
        except OSError:
            pass
    if len(data) > max_bytes or not _same_file(opened, after):
        code = ErrorCode.FILE_TOO_LARGE.value if len(data) > max_bytes else ErrorCode.IDENTITY_MISMATCH.value
        detail = f"file exceeds {max_bytes} bytes" if code == ErrorCode.FILE_TOO_LARGE.value else "file changed while being read"
        raise SafeFileError(TypedError(code, detail, str(path)))
    return data


def read_json_file(path: str | os.PathLike[str], *, max_bytes: int = MAX_FILE_BYTES) -> Any:
    data = read_bytes_limited(path, max_bytes=max_bytes)
    try:
        return parse_json(data)
    except DuplicateKeyError as exc:
        raise SafeFileError(TypedError(ErrorCode.DUPLICATE_JSON_KEY.value, str(exc), str(path))) from exc
    except NonCanonicalJSONError as exc:
        code = getattr(exc, "code", ErrorCode.INVALID_FIELD.value)
        raise SafeFileError(TypedError(code, str(exc), str(path))) from exc
    except (TypeError, ValueError) as exc:
        if isinstance(exc, EvidenceError):
            raise
        raise SafeFileError(TypedError(ErrorCode.INVALID_FIELD.value, f"invalid JSON: {exc}", str(path))) from exc
