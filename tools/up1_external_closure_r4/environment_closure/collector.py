"""Observation-only UP1 environment and binary-source closure collector.

This module deliberately does not install packages, resolve dependencies,
download anything, mutate a virtual environment, or capture environment
variables.  A version string is a local observation; it is never promoted to
reproducible provenance.  Missing provenance material is represented as
``typed_absent`` and remains part of the returned receipt.
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import re
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

LOCAL_OBSERVED = "local_observed"
TYPED_ABSENT = "typed_absent"
ABSENT = TYPED_ABSENT
TYPED_UNVERIFIED = "typed_unverified"
FAIL_CLOSED = "fail_closed"

SCHEMA = "UP1.external-environment-closure-r4.v1"
_SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
_VERSION = re.compile(r"(?<!\d)(\d+(?:\.\d+){1,4})(?!\d)")
_SECRET = re.compile(
    r"(?i)(password|passwd|token|secret|api[_-]?key|authorization|credential)"
    r"(\s*[:=]\s*)[^\s,;]+"
)
_FILE_ATTRIBUTE_REPARSE_POINT = 0x400
_LOCK_NAMES = {
    "manifest.toml", "project.toml", "packages.lock.json", "poetry.lock",
    "pipfile.lock", "uv.lock", "pdm.lock", "environment.yml",
    "environment.yaml",
}


class CollectorError(ValueError):
    """A malformed request or unsafe input that must fail closed."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _lexical_path(value: str | os.PathLike[str]) -> Path:
    """Return an absolute lexical path without following any component."""
    if isinstance(value, bytes):
        raise CollectorError("path_must_be_text")
    text = os.fspath(value)
    if isinstance(text, bytes):
        raise CollectorError("path_must_be_text")
    if "\x00" in text:
        raise CollectorError("path_contains_nul")
    # Environment expansion is intentionally not performed: ``%TOKEN%`` is
    # data, not a reason to inspect or leak the process environment.
    try:
        # ``absolute`` preserves ``..``.  That is deliberate: component
        # inspection below must see a link hidden before a lexical ``..``.
        return Path(text).expanduser().absolute()
    except (OSError, RuntimeError) as exc:
        raise CollectorError(f"unsafe_path:{text}") from exc


def _reparse_info(info: os.stat_result) -> bool:
    return stat.S_ISLNK(info.st_mode) or bool(
        getattr(info, "st_file_attributes", 0) & _FILE_ATTRIBUTE_REPARSE_POINT
    )


def _lstat(path: Path, *, missing_ok: bool = False) -> os.stat_result | None:
    """lstat with typed handling; never turn inspection errors into ``False``."""
    try:
        return path.lstat()
    except FileNotFoundError:
        if missing_ok:
            return None
        raise CollectorError("path_inspection_failed:FileNotFoundError")
    except OSError as exc:
        raise CollectorError(f"path_inspection_failed:{type(exc).__name__}") from exc


def _inspect_lexical_components(path: Path) -> None:
    """Inspect existing lexical components before normalization or resolution."""
    current = Path(path.anchor) if path.anchor else Path.cwd()
    parts = path.parts[1:] if path.is_absolute() else path.parts
    for part in parts:
        if part in ("", "."):
            continue
        if part == "..":
            current = current.parent
            continue
        current = current / part
        info = _lstat(current, missing_ok=True)
        if info is not None and _reparse_info(info):
            raise CollectorError("reparse_point_not_read")


def _same_identity(left: os.stat_result, right: os.stat_result) -> bool:
    """Compare object identity, plus mutable fields relevant to a hash."""
    return (
        getattr(left, "st_dev", None),
        getattr(left, "st_ino", None),
        stat.S_IFMT(left.st_mode),
        left.st_size,
        getattr(left, "st_mtime_ns", None),
    ) == (
        getattr(right, "st_dev", None),
        getattr(right, "st_ino", None),
        stat.S_IFMT(right.st_mode),
        right.st_size,
        getattr(right, "st_mtime_ns", None),
    )


def _safe_path(
    value: str | os.PathLike[str],
    *,
    allow_missing: bool = True,
    root: Path | None = None,
) -> Path:
    """Validate lexical components, containment, then resolve safely."""
    lexical = _lexical_path(value)
    _inspect_lexical_components(lexical)
    normalized = Path(os.path.normpath(os.fspath(lexical)))

    root_normalized: Path | None = None
    if root is not None:
        root_lexical = _lexical_path(root)
        _inspect_lexical_components(root_lexical)
        root_normalized = Path(os.path.normpath(os.fspath(root_lexical)))
        try:
            normalized.relative_to(root_normalized)
        except ValueError as exc:
            raise CollectorError("path_escapes_root") from exc

    info = _lstat(normalized, missing_ok=True)
    if info is None and not allow_missing:
        raise CollectorError(f"path_not_found:{normalized}")
    try:
        resolved = normalized.resolve(strict=False)
    except (OSError, RuntimeError) as exc:
        raise CollectorError(f"unsafe_path:{normalized}") from exc
    if root_normalized is not None:
        try:
            resolved_root = root_normalized.resolve(strict=False)
            resolved.relative_to(resolved_root)
        except (OSError, RuntimeError) as exc:
            raise CollectorError(f"unsafe_root:{root_normalized}") from exc
        except ValueError as exc:
            raise CollectorError("path_escapes_root") from exc
    return resolved


def _is_reparse(path: Path) -> bool:
    """Detect links/reparse points; inspection failure is fail-closed."""
    info = _lstat(path)
    assert info is not None
    return _reparse_info(info)


def _hash_regular_verified(path: Path, expected: os.stat_result) -> tuple[str, int]:
    """Hash a verified regular file and reject identity/content races."""
    if _reparse_info(expected) or not stat.S_ISREG(expected.st_mode):
        raise CollectorError("not_a_regular_file")
    flags = os.O_RDONLY | getattr(os, "O_BINARY", 0)
    # On POSIX this closes the remaining open-vs-swap gap.  Windows has no
    # portable O_NOFOLLOW flag; lstat/fstat before and after still fail closed.
    flags |= getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(os.fspath(path), flags)
    except OSError as exc:
        raise CollectorError(f"read_failed:{type(exc).__name__}") from exc
    digest = hashlib.sha256()
    try:
        with os.fdopen(fd, "rb", closefd=True) as handle:
            opened = os.fstat(handle.fileno())
            if _reparse_info(opened) or not _same_identity(expected, opened):
                raise CollectorError("path_identity_changed")
            for block in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(block)
            finished = os.fstat(handle.fileno())
            if _reparse_info(finished) or not _same_identity(opened, finished):
                raise CollectorError("path_identity_changed")
            size = finished.st_size
    except CollectorError:
        raise
    except OSError as exc:
        raise CollectorError(f"read_failed:{type(exc).__name__}") from exc
    after = _lstat(path)
    assert after is not None
    if _reparse_info(after) or not _same_identity(expected, after):
        raise CollectorError("path_identity_changed")
    return digest.hexdigest(), size


def file_sha256(path: str | os.PathLike[str], *, root: Path | None = None) -> str:
    """Hash one regular, non-reparse file in bounded chunks."""
    target = _safe_path(path, allow_missing=False, root=root)
    info = _lstat(target)
    assert info is not None
    if _reparse_info(info):
        raise CollectorError("reparse_point_not_read")
    if not stat.S_ISREG(info.st_mode):
        raise CollectorError("not_a_regular_file")
    digest, _ = _hash_regular_verified(target, info)
    return digest


def _version_resource(path: Path) -> str | None:
    """Read a Windows PE fixed-file version without starting the binary."""
    if os.name != "nt":
        return None
    try:
        import ctypes
        from ctypes import wintypes

        version = ctypes.WinDLL("Version", use_last_error=True)
        version.GetFileVersionInfoSizeW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(wintypes.DWORD)]
        version.GetFileVersionInfoSizeW.restype = wintypes.DWORD
        version.GetFileVersionInfoW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, wintypes.LPVOID]
        version.GetFileVersionInfoW.restype = wintypes.BOOL
        version.VerQueryValueW.argtypes = [wintypes.LPVOID, wintypes.LPCWSTR, ctypes.POINTER(wintypes.LPVOID), ctypes.POINTER(wintypes.UINT)]
        version.VerQueryValueW.restype = wintypes.BOOL
        handle = wintypes.DWORD()
        size = version.GetFileVersionInfoSizeW(str(path), ctypes.byref(handle))
        if not size:
            return None
        buffer = ctypes.create_string_buffer(size)
        if not version.GetFileVersionInfoW(str(path), 0, size, buffer):
            return None
        pointer = wintypes.LPVOID()
        length = wintypes.UINT()
        if not version.VerQueryValueW(buffer, "\\", ctypes.byref(pointer), ctypes.byref(length)) or length.value < 8:
            return None
        # VS_FIXEDFILEINFO: signature, struct version, file version MS/LS.
        words = (ctypes.c_uint32 * 13).from_address(pointer.value)
        if words[0] != 0xFEEF04BD:
            return None
        major = words[2] >> 16
        minor = words[2] & 0xFFFF
        patch = words[3] >> 16
        build = words[3] & 0xFFFF
        return f"{major}.{minor}.{patch}.{build}"
    except (AttributeError, OSError, TypeError, ValueError):
        return None


def collect_file_observation(
    path: str | os.PathLike[str] | None,
    *,
    name: str | None = None,
    role: str | None = None,
    root: Path | None = None,
) -> dict[str, Any]:
    """Return a safe local observation for a file, without following reparse points."""
    if path is None:
        return {
            "name": name,
            "role": role,
            "path": None,
            "exists": False,
            "status": TYPED_ABSENT,
            "reason": "path_not_declared",
        }
    try:
        target = _safe_path(path, root=root)
    except CollectorError as exc:
        reason = str(exc)
        status = TYPED_UNVERIFIED if reason == "reparse_point_not_read" else FAIL_CLOSED
        return {"name": name, "role": role, "path": str(path), "exists": False, "status": status, "reason": reason}
    try:
        before = _lstat(target, missing_ok=True)
    except CollectorError as exc:
        return {"name": name, "role": role, "path": str(target), "exists": False, "status": FAIL_CLOSED, "reason": str(exc)}
    item: dict[str, Any] = {"name": name, "role": role, "path": str(target), "exists": before is not None}
    if before is None:
        item.update({"status": TYPED_ABSENT, "reason": "path_not_found"})
        return item
    if _reparse_info(before):
        item.update({"status": TYPED_UNVERIFIED, "reason": "reparse_point_not_read"})
        return item
    if not stat.S_ISREG(before.st_mode):
        item.update({"status": FAIL_CLOSED, "reason": "not_a_regular_file"})
        return item
    try:
        digest, size = _hash_regular_verified(target, before)
        # Version-resource inspection is also path-based.  Keep it within the
        # same identity envelope so a replacement cannot be reported as the
        # version of the hashed file.
        version_before = _lstat(target)
        assert version_before is not None
        if _reparse_info(version_before) or not _same_identity(before, version_before):
            raise CollectorError("path_identity_changed")
        file_version = _version_resource(target)
        version_after = _lstat(target)
        assert version_after is not None
        if _reparse_info(version_after) or not _same_identity(version_before, version_after):
            raise CollectorError("path_identity_changed")
        item.update({
            "bytes": size,
            "sha256": digest,
            "status": LOCAL_OBSERVED,
        })
    except (OSError, CollectorError) as exc:
        item.update({"status": FAIL_CLOSED, "reason": f"read_failed:{type(exc).__name__}"})
        return item
    item["file_version"] = file_version
    return item


def _redact(text: str) -> str:
    text = _SECRET.sub(r"\1=REDACTED", text)
    # Do not emit arbitrary command output.  Keep a tiny diagnostic that is
    # safe for ordinary --version output and a digest for exact comparison.
    return text[:512].replace("\r", "").replace("\x00", "")


def _run_version_command(path: Path, args: Sequence[str], timeout: float) -> dict[str, Any]:
    started = utc_now()
    command = [str(path), *args]
    receipt: dict[str, Any] = {
        "command": command,
        "started_utc": started,
        "pid": None,
        "exit_code": None,
        "status": TYPED_ABSENT,
    }
    identity_before: os.stat_result | None = None
    try:
        identity_before = _lstat(path)
        assert identity_before is not None
        if _reparse_info(identity_before) or not stat.S_ISREG(identity_before.st_mode):
            raise CollectorError("runtime_not_regular")
        # shell=False is intentional.  stdin is closed and no environment
        # values are copied into the receipt.
        process = subprocess.Popen(
            command,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=False,
            cwd=str(path.parent),
        )
        receipt["pid"] = process.pid
        try:
            stdout, stderr = process.communicate(timeout=max(0.1, float(timeout)))
        except subprocess.TimeoutExpired:
            process.kill()
            stdout, stderr = process.communicate()
            receipt["status"] = FAIL_CLOSED
            receipt["reason"] = "version_probe_timeout"
        else:
            receipt["exit_code"] = process.returncode
            receipt["status"] = LOCAL_OBSERVED if process.returncode == 0 else TYPED_UNVERIFIED
        out = (stdout or b"") + b"\n" + (stderr or b"")
        text = out.decode("utf-8", errors="replace")
        receipt["output_sha256"] = hashlib.sha256(out).hexdigest()
        receipt["output_excerpt"] = _redact(text)
        match = _VERSION.search(text)
        receipt["version"] = match.group(1) if match else None
    except (OSError, ValueError, CollectorError) as exc:
        receipt.update({"status": FAIL_CLOSED, "reason": f"probe_unavailable:{type(exc).__name__}"})
    if identity_before is not None:
        try:
            identity_after = _lstat(path)
            if identity_after is None or not _same_identity(identity_before, identity_after):
                receipt.update({"status": FAIL_CLOSED, "reason": "path_identity_changed"})
        except CollectorError as exc:
            receipt.update({"status": FAIL_CLOSED, "reason": str(exc)})
    receipt["ended_utc"] = utc_now()
    return receipt


def _specs(value: Any, *, default_name: str | None = None) -> list[dict[str, Any]]:
    if value is None:
        return []
    if isinstance(value, Mapping):
        if "path" in value or "name" in value:
            return [dict(value)]
        return [{"name": str(key), "path": val} for key, val in value.items()]
    if isinstance(value, (str, os.PathLike)):
        return [{"name": default_name, "path": value}]
    result: list[dict[str, Any]] = []
    for item in value:
        if isinstance(item, Mapping):
            result.append(dict(item))
        elif isinstance(item, (tuple, list)) and len(item) == 2:
            result.append({"name": item[0], "path": item[1]})
        else:
            result.append({"name": default_name, "path": item})
    return result


def _which(name: str) -> str | None:
    try:
        return shutil.which(name)
    except (OSError, ValueError):
        return None


def _runtime(name: str, path: Any, *, probe: bool, timeout: float) -> dict[str, Any]:
    chosen = path or _which({"python": "python", "julia": "julia", "desc": "desc"}.get(name.lower(), name))
    observation = collect_file_observation(chosen, name=name, role="runtime")
    item: dict[str, Any] = {
        "name": name,
        "path": observation.get("path"),
        "file": observation,
        "version": observation.get("file_version"),
        "version_source": "windows_file_version_resource" if observation.get("file_version") else None,
        "status": observation.get("status", TYPED_ABSENT),
    }
    if probe and observation.get("status") == LOCAL_OBSERVED:
        args = ("--version",)
        command = _run_version_command(Path(observation["path"]), args, timeout)
        item["version_command"] = command
        if command.get("status") == FAIL_CLOSED:
            item["status"] = FAIL_CLOSED
        if command.get("version"):
            item["version"] = command["version"]
            item["version_source"] = "version_command_observation"
    else:
        item["version_command"] = {
            "command": [observation.get("path"), "--version"] if observation.get("path") else None,
            "status": TYPED_ABSENT,
            "reason": "version_probe_not_requested" if not probe else "runtime_not_readable",
            "pid": None,
            "exit_code": None,
            "started_utc": None,
            "ended_utc": None,
        }
    return item


def _material(path: Any, *, kind: str) -> dict[str, Any]:
    result = collect_file_observation(path, name=kind, role=kind)
    if result.get("status") == LOCAL_OBSERVED:
        # Presence alone cannot verify authorship, signature, origin, or
        # reproducibility.  Keep that ceiling explicit.
        result["status"] = TYPED_UNVERIFIED
        result["verification"] = TYPED_ABSENT
        result["reason"] = "local_material_not_independently_verified"
    else:
        result["verification"] = TYPED_ABSENT
    return result


def _root_files(root: Path, explicit: Iterable[Any] | None) -> list[Any]:
    if explicit is not None:
        return list(explicit)
    names = ["Project.toml", "Manifest.toml", "requirements.txt", "requirements.lock", "poetry.lock", "Pipfile.lock", "uv.lock", "environment.yml", "environment.yaml"]
    found: list[Path] = []
    for name in names:
        candidate = root / name
        try:
            present = candidate.lstat()
        except FileNotFoundError:
            present = None
        except OSError:
            # Preserve the candidate so collect_file_observation emits a
            # typed fail-closed inspection result instead of skipping it.
            present = object()
        if present is not None:
            found.append(candidate)
    gridap = root / "tools" / "qualification" / "gridap"
    for name in ("Project.toml", "Manifest.toml"):
        candidate = gridap / name
        try:
            present = candidate.lstat()
        except FileNotFoundError:
            present = None
        except OSError:
            present = object()
        if present is not None:
            found.append(candidate)
    return found


def collect_closure(
    root: str | os.PathLike[str] | None = None,
    *,
    runtimes: Any = None,
    runtime_paths: Any = None,
    python_path: str | os.PathLike[str] | None = None,
    julia_path: str | os.PathLike[str] | None = None,
    desc_path: str | os.PathLike[str] | None = None,
    binaries: Any = None,
    binary_paths: Any = None,
    manifests: Iterable[Any] | None = None,
    source_receipt: Any = None,
    signature: Any = None,
    download_receipt: Any = None,
    sbom: Any = None,
    build_recipe: Any = None,
    probe_versions: bool = False,
    command_timeout: float = 10.0,
) -> dict[str, Any]:
    """Collect a JSON-serializable, observation-only closure receipt."""
    started = utc_now()
    collector_pid = os.getpid()
    try:
        base = _safe_path(root or Path.cwd())
        base_info = _lstat(base)
        assert base_info is not None
        if _reparse_info(base_info) or not stat.S_ISDIR(base_info.st_mode):
            raise CollectorError("root_must_be_regular_directory")
        if runtimes is None and runtime_paths is not None:
            runtimes = runtime_paths
        runtime_specs = _specs(runtimes)
        by_name = {str(x.get("name", "")).lower(): x.get("path") for x in runtime_specs if x.get("name")}
        by_name.update({k: v for k, v in {"python": python_path, "julia": julia_path, "desc": desc_path}.items() if v is not None})
        runtime_items = [_runtime("Python", by_name.get("python"), probe=probe_versions, timeout=command_timeout), _runtime("Julia", by_name.get("julia"), probe=probe_versions, timeout=command_timeout), _runtime("DESC", by_name.get("desc"), probe=probe_versions, timeout=command_timeout)]

        binary_specs = _specs(binary_paths if binary_paths is not None else binaries)
        binary_items: list[dict[str, Any]] = []
        for spec in binary_specs:
            name = str(spec.get("name") or Path(os.fspath(spec.get("path"))).name)
            obs = collect_file_observation(spec.get("path"), name=name, role="binary")
            item = {"name": name, "file": obs, "path": obs.get("path"), "version": obs.get("file_version"), "status": obs.get("status", TYPED_ABSENT)}
            item["source_closure"] = {
                "source_receipt": _material(spec.get("source_receipt", source_receipt), kind="source_receipt"),
                "signature": _material(spec.get("signature", signature), kind="signature"),
                "download_receipt": _material(spec.get("download_receipt", download_receipt), kind="download_receipt"),
                "sbom": _material(spec.get("sbom", sbom), kind="sbom"),
                "build_recipe": _material(spec.get("build_recipe", build_recipe), kind="build_recipe"),
            }
            binary_items.append(item)

        declaration_items: list[dict[str, Any]] = []
        for declaration in _root_files(base, manifests):
            if isinstance(declaration, Mapping):
                path = declaration.get("path")
                kind = declaration.get("kind") or Path(os.fspath(path)).name.lower()
            else:
                path = declaration
                kind = Path(os.fspath(path)).name.lower()
            declaration_items.append(collect_file_observation(path, name=str(kind), role="lock_or_manifest", root=base))
        has_python_lock = any(Path(str(x.get("path") or "")).name.lower() in {"requirements.lock", "poetry.lock", "pipfile.lock", "uv.lock", "pdm.lock", "environment.yml", "environment.yaml"} for x in declaration_items)
        if not has_python_lock:
            declaration_items.append({"name": "python_lock_or_channel_freeze", "path": None, "exists": False, "status": TYPED_ABSENT, "reason": "no_exact_python_lock_or_channel_freeze_declared"})

        provenance = {
            "source_receipt": _material(source_receipt, kind="source_receipt"),
            "signature": _material(signature, kind="signature"),
            "download_receipt": _material(download_receipt, kind="download_receipt"),
            "sbom": _material(sbom, kind="sbom"),
            "build_recipe": _material(build_recipe, kind="build_recipe"),
        }
        missing: list[str] = []
        for key, value in provenance.items():
            if value.get("status") == TYPED_ABSENT:
                missing.append(key)
        if not binary_items:
            missing.append("binary_inventory")
        if not any(x.get("status") == LOCAL_OBSERVED for x in runtime_items):
            missing.append("runtime_inventory")
        if not has_python_lock:
            missing.append("python_lock_or_channel_freeze")
        status = TYPED_ABSENT if missing else TYPED_UNVERIFIED
        receipt = {
            "record_kind": "up1_external_environment_closure_r4",
            "schema": SCHEMA,
            "observed_utc": started,
            "collector": {"pid": collector_pid, "started_utc": started, "ended_utc": None, "platform": platform.platform(), "python": None},
            "root": str(base),
            "runtimes": runtime_items,
            "binaries": binary_items,
            "lock_and_manifest_files": declaration_items,
            "provenance": provenance,
            "status": status,
            "claim_ceiling": "local_observation_only; version strings and SHA256 values do not establish reproducible closure",
            "missing_or_unverified": sorted(set(missing)) if missing else ["independent_provenance_verification"],
            "command_policy": {"read_only": True, "network_used": False, "download_performed": False, "installation_performed": False, "environment_modified": False, "environment_variables_captured": False, "version_probes_enabled": bool(probe_versions)},
        }
        receipt["collector"]["ended_utc"] = utc_now()
        return receipt
    except Exception as exc:
        return {
            "record_kind": "up1_external_environment_closure_r4",
            "schema": SCHEMA,
            "observed_utc": started,
            "collector": {"pid": collector_pid, "started_utc": started, "ended_utc": utc_now(), "platform": platform.platform(), "python": None},
            "status": FAIL_CLOSED,
            "claim_ceiling": "no closure claim",
            "errors": [str(exc)],
            "command_policy": {"read_only": True, "network_used": False, "download_performed": False, "installation_performed": False, "environment_modified": False, "environment_variables_captured": False},
        }


def dump_receipt(receipt: Mapping[str, Any], output: str | os.PathLike[str] | None = None) -> None:
    """Write a receipt only when requested; never overwrite an existing file."""
    if output is None:
        return
    target = _safe_path(output)
    if target.exists():
        raise CollectorError("refuse_to_overwrite_receipt")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(receipt, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
