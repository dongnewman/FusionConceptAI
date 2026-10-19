"""Fail-closed sampled process-tree supervisor for the FreeGS v24 candidate.

This is a versioned evidence harness, not solver code.  It preserves the v22
child command and resource limits while refusing to treat an incomplete
process-tree/RSS observation or unverified cleanup as a natural child result.
The receipt describes sampled process-tree evidence; it is not an OS job-object
or kernel-level guarantee about processes that exist only between samples.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
from datetime import datetime, timezone
from typing import Any, Iterable

import psutil


RESOURCE_WALL_EXIT = 97
RESOURCE_RSS_EXIT = 98
PREFLIGHT_EXIT = 96
TREE_EVIDENCE_EXIT = 99
WAIT_SECONDS = 5.0
POLL_SECONDS = 0.05
PIN_MANIFEST_SCHEMA = "fusionconceptai:process-tree-required-files-manifest-v1"


class ProcessTreeEvidenceError(RuntimeError):
    """Raised whenever a process-tree sample cannot be called complete."""

    def __init__(
        self,
        operation: str,
        pid: int | None,
        error: BaseException,
        *,
        details: dict[str, Any] | None = None,
    ):
        self.operation = operation
        self.pid = pid
        self.error_type = type(error).__name__
        self.details = details
        super().__init__(f"{operation} failed for pid={pid}: {self.error_type}: {error}")

    def as_dict(self) -> dict[str, Any]:
        result = {
            "operation": self.operation,
            "pid": self.pid,
            "error_type": self.error_type,
            "message": str(self),
        }
        if self.details is not None:
            result["details"] = self.details
        return result


@dataclass(frozen=True)
class ProcessIdentity:
    pid: int
    create_time_epoch_s: float

    def key(self) -> tuple[int, float]:
        return self.pid, self.create_time_epoch_s


@dataclass(frozen=True)
class TreeSample:
    rss_bytes: int
    processes: tuple[dict[str, Any], ...]
    identities: tuple[ProcessIdentity, ...]
    handles: tuple[tuple[ProcessIdentity, Any], ...]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_receipt(path: Path, receipt: dict[str, Any]) -> None:
    canonical = json.dumps(
        receipt,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    receipt["receipt_sha256"] = hashlib.sha256(canonical).hexdigest()
    path.write_text(
        json.dumps(receipt, indent=2, sort_keys=True, ensure_ascii=False, allow_nan=False) + "\n",
        encoding="utf-8",
    )


def _identity(process: Any, api: Any, operation: str) -> ProcessIdentity:
    try:
        pid = int(process.pid)
        created = float(process.create_time())
    except Exception as exc:
        raise ProcessTreeEvidenceError(operation, getattr(process, "pid", None), exc) from exc
    if pid <= 0 or not math.isfinite(created) or created < 0:
        raise ProcessTreeEvidenceError(
            operation,
            pid,
            ValueError("invalid process identity fields"),
        )
    return ProcessIdentity(pid, created)


def _identity_record(identity: ProcessIdentity) -> dict[str, Any]:
    return {
        "pid": identity.pid,
        "create_time_epoch_s": identity.create_time_epoch_s,
    }


def _verify_natural_root_identity(
    child: Any,
    root: Any,
    expected: ProcessIdentity,
    api: Any,
) -> dict[str, Any]:
    """Prove that wait() refers to the same exact root identity bound pre-sample."""
    popen_identity = _identity(child, api, "natural_exit_popen_identity")
    lookup_identity = _identity(root, api, "natural_exit_lookup_identity")
    details = {
        "expected_identity": _identity_record(expected),
        "popen_identity": _identity_record(popen_identity),
        "process_lookup_identity": _identity_record(lookup_identity),
    }
    if popen_identity != expected or lookup_identity != expected:
        raise ProcessTreeEvidenceError(
            "natural_exit_root_identity_mismatch",
            expected.pid,
            ValueError("Popen and Process lookup identities must both equal the initially bound root"),
            details=details,
        )
    root_state = _process_alive(root, api, "natural_exit_root_state")
    details["process_lookup_is_running"] = root_state
    if root_state is not False:
        raise ProcessTreeEvidenceError(
            "natural_exit_root_not_proven_gone",
            expected.pid,
            ValueError("natural wait return requires the exact Process lookup to report the root gone"),
            details=details,
        )
    return {"status": "verified_exact_root_exit", **details}


def observe_process_tree(
    root: Any,
    api: Any = psutil,
    expected_root_identity: ProcessIdentity | None = None,
) -> TreeSample:
    """Return one complete recursive process/RSS sample or fail closed.

    NoSuchProcess is not silently dropped: a process disappearing between
    enumeration and RSS collection invalidates the entire sample because the
    remaining RSS sum would be partial.
    """
    root_identity = _identity(root, api, "root_identity")
    if expected_root_identity is not None and root_identity != expected_root_identity:
        raise ProcessTreeEvidenceError(
            "sample_root_identity_mismatch",
            root_identity.pid,
            ValueError("sample root identity differs from the Popen-bound root identity"),
            details={
                "expected_identity": _identity_record(expected_root_identity),
                "observed_identity": _identity_record(root_identity),
            },
        )
    if _process_alive(root, api, "sample_root_state") is not True:
        raise ProcessTreeEvidenceError(
            "sample_root_not_live",
            root_identity.pid,
            ValueError("root must be positively live before a complete process-tree sample"),
            details={"root_identity": _identity_record(root_identity)},
        )
    try:
        descendants = list(root.children(recursive=True))
    except Exception as exc:
        raise ProcessTreeEvidenceError("recursive_enumeration", root_identity.pid, exc) from exc

    handles: dict[tuple[int, float], tuple[ProcessIdentity, Any]] = {
        root_identity.key(): (root_identity, root),
    }
    for process in descendants:
        identity = _identity(process, api, "descendant_identity")
        handles.setdefault(identity.key(), (identity, process))

    root_identities_for_pid = [identity for identity, _ in handles.values() if identity.pid == root_identity.pid]
    if len(root_identities_for_pid) != 1 or root_identities_for_pid[0].key() != root_identity.key():
        raise ProcessTreeEvidenceError(
            "root_identity_membership",
            root_identity.pid,
            ValueError("complete sample must contain the exact root pid/create-time identity exactly once"),
        )

    rss_total = 0
    records: list[dict[str, Any]] = []
    for identity, process in sorted(handles.values(), key=lambda item: item[0].key()):
        try:
            rss = int(process.memory_info().rss)
        except Exception as exc:
            raise ProcessTreeEvidenceError("rss_read", identity.pid, exc) from exc
        if rss < 0:
            raise ProcessTreeEvidenceError(
                "rss_validation",
                identity.pid,
                ValueError("negative RSS"),
            )
        rss_total += rss
        records.append({
            "pid": identity.pid,
            "create_time_epoch_s": identity.create_time_epoch_s,
            "rss_bytes": rss,
        })
    return TreeSample(
        rss_bytes=rss_total,
        processes=tuple(records),
        identities=tuple(item[0] for item in sorted(handles.values(), key=lambda item: item[0].key())),
        handles=tuple(sorted(handles.values(), key=lambda item: item[0].key())),
    )


def _process_alive(process: Any, api: Any, operation: str) -> bool | None:
    try:
        return bool(process.is_running())
    except api.NoSuchProcess:
        return False
    except (api.AccessDenied, OSError):
        return None
    except Exception:
        return None


def audit_tracked_processes(
    tracked: dict[tuple[int, float], tuple[ProcessIdentity, Any]],
    root_identity: ProcessIdentity,
    api: Any = psutil,
) -> dict[str, Any]:
    """Audit known identities without confusing unreadable with exited."""
    alive: list[dict[str, Any]] = []
    unknown: list[dict[str, Any]] = []
    exited: list[dict[str, Any]] = []
    for identity, process in sorted(tracked.values(), key=lambda item: item[0].key()):
        state = _process_alive(process, api, "tracked_process_state")
        record = {"pid": identity.pid, "create_time_epoch_s": identity.create_time_epoch_s}
        if state is True:
            if identity.key() != root_identity.key():
                alive.append(record)
        elif state is False:
            exited.append(record)
        else:
            unknown.append(record)
    return {
        "alive_descendants": alive,
        "unknown_processes": unknown,
        "verified_exited_processes": exited,
        "all_tracked_descendants_gone": not alive and not unknown,
    }


def _append_operation(
    operations: list[dict[str, Any]],
    action: str,
    identity: ProcessIdentity,
    process: Any,
    api: Any,
) -> None:
    try:
        getattr(process, action)()
        operations.append({"action": action, "pid": identity.pid, "status": "requested"})
    except api.NoSuchProcess:
        operations.append({"action": action, "pid": identity.pid, "status": "already_gone"})
    except Exception as exc:
        operations.append({
            "action": action,
            "pid": identity.pid,
            "status": "failed",
            "error_type": type(exc).__name__,
            "message": str(exc),
        })


def stop_and_verify(
    root: Any,
    root_identity: ProcessIdentity,
    tracked: dict[tuple[int, float], tuple[ProcessIdentity, Any]],
    api: Any = psutil,
    timeout_seconds: float = WAIT_SECONDS,
) -> dict[str, Any]:
    """Terminate known/current processes and report whether exit was proved.

    Enumeration, terminate/kill, wait and final state errors are recorded.
    An AccessDenied or unknown final state can never be reported as proof.
    """
    enumeration_errors: list[dict[str, Any]] = []
    try:
        current = list(root.children(recursive=True))
        current.append(root)
        for process in current:
            identity = _identity(process, api, "termination_enumeration_identity")
            tracked.setdefault(identity.key(), (identity, process))
        enumeration_complete = True
    except Exception as exc:
        enumeration_complete = False
        enumeration_errors.append({
            "operation": "termination_recursive_enumeration",
            "pid": getattr(root, "pid", None),
            "error_type": type(exc).__name__,
            "message": str(exc),
        })

    operations: list[dict[str, Any]] = []
    candidates = sorted(tracked.values(), key=lambda item: item[0].key(), reverse=True)
    for identity, process in candidates:
        _append_operation(operations, "terminate", identity, process, api)

    waits: list[dict[str, Any]] = []
    try:
        gone, alive = api.wait_procs([p for _, p in candidates], timeout=timeout_seconds)
        waits.append({
            "phase": "terminate_wait",
            "gone_pids": sorted(int(p.pid) for p in gone),
            "alive_pids": sorted(int(p.pid) for p in alive),
            "status": "completed",
        })
    except Exception as exc:
        alive = [process for _, process in candidates]
        waits.append({
            "phase": "terminate_wait",
            "status": "failed",
            "error_type": type(exc).__name__,
            "message": str(exc),
        })

    identity_by_object = {id(process): identity for identity, process in candidates}
    alive_keys = {
        identity_by_object[id(process)].key()
        for process in alive
        if id(process) in identity_by_object
    }
    for identity, process in candidates:
        if identity.key() in alive_keys:
            _append_operation(operations, "kill", identity, process, api)

    try:
        gone_after_kill, alive_after_kill = api.wait_procs(alive, timeout=timeout_seconds)
        waits.append({
            "phase": "kill_wait",
            "gone_pids": sorted(int(p.pid) for p in gone_after_kill),
            "alive_pids": sorted(int(p.pid) for p in alive_after_kill),
            "status": "completed",
        })
    except Exception as exc:
        alive_after_kill = list(alive)
        waits.append({
            "phase": "kill_wait",
            "status": "failed",
            "error_type": type(exc).__name__,
            "message": str(exc),
        })

    residual = audit_tracked_processes(tracked, root_identity, api)
    failed_ops = [item for item in operations if item["status"] == "failed"]
    wait_failed = any(item["status"] == "failed" for item in waits)
    exit_proven = (
        enumeration_complete
        and not enumeration_errors
        and not failed_ops
        and not wait_failed
        and residual["all_tracked_descendants_gone"]
        and not alive_after_kill
    )
    return {
        "enumeration_complete": enumeration_complete,
        "enumeration_errors": enumeration_errors,
        "operations": operations,
        "waits": waits,
        "residual_audit": residual,
        "tree_exit_proven": exit_proven,
    }


def stop_child_without_process_identity(child: Any, api: Any = psutil) -> dict[str, Any]:
    """Best-effort stop when PID/create-time binding failed after launch.

    It can never prove tree exit because no trustworthy process identity or
    recursive snapshot was acquired; the caller must return harness exit 99.
    """
    operations: list[dict[str, Any]] = []
    waits: list[dict[str, Any]] = []
    try:
        child.terminate()
        operations.append({"action": "terminate", "pid": int(child.pid), "status": "requested"})
    except Exception as exc:
        operations.append({"action": "terminate", "pid": getattr(child, "pid", None), "status": "failed", "error_type": type(exc).__name__, "message": str(exc)})
    try:
        result = child.wait(timeout=WAIT_SECONDS)
        waits.append({"phase": "terminate_wait", "status": "completed", "return_code": result})
    except api.TimeoutExpired:
        try:
            child.kill()
            operations.append({"action": "kill", "pid": int(child.pid), "status": "requested"})
        except Exception as exc:
            operations.append({"action": "kill", "pid": getattr(child, "pid", None), "status": "failed", "error_type": type(exc).__name__, "message": str(exc)})
        try:
            result = child.wait(timeout=WAIT_SECONDS)
            waits.append({"phase": "kill_wait", "status": "completed", "return_code": result})
        except Exception as exc:
            waits.append({"phase": "kill_wait", "status": "failed", "error_type": type(exc).__name__, "message": str(exc)})
    except Exception as exc:
        waits.append({"phase": "terminate_wait", "status": "failed", "error_type": type(exc).__name__, "message": str(exc)})
    return {
        "enumeration_complete": False,
        "enumeration_errors": [{"operation": "root_identity_unavailable", "pid": getattr(child, "pid", None)}],
        "operations": operations,
        "waits": waits,
        "residual_audit": {"all_tracked_descendants_gone": False, "unknown_processes": []},
        "tree_exit_proven": False,
    }


def rehash_required_files(required_files: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    after: list[dict[str, Any]] = []
    changes: list[dict[str, Any]] = []
    for before in required_files:
        path = Path(str(before["path"]))
        expected = str(before["expected_sha256"])
        actual = sha256_file(path) if path.is_file() else None
        status = "match" if actual == expected else ("missing_or_not_file" if actual is None else "hash_mismatch")
        after.append({"path": str(path), "expected_sha256": expected, "actual_sha256": actual, "status": status})
        if actual != before["actual_sha256"]:
            changes.append({"path": str(path), "before_sha256": before["actual_sha256"], "after_sha256": actual})
    return after, changes


def _parse_required_files(declarations: Iterable[str]) -> tuple[list[dict[str, Any]], list[str]]:
    records: list[dict[str, Any]] = []
    errors: list[str] = []
    for declaration in declarations:
        if "=" not in declaration:
            raise ValueError(f"invalid --require-file-sha256 declaration {declaration!r}")
        path_text, expected = declaration.rsplit("=", 1)
        if not path_text or len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
            raise ValueError(f"invalid --require-file-sha256 declaration {declaration!r}")
        path = Path(path_text)
        if not path.is_absolute():
            raise ValueError("required-file paths must be absolute")
        resolved = path.resolve(strict=False)
        actual = sha256_file(resolved) if resolved.is_file() else None
        status = "match" if actual == expected else ("missing_or_not_file" if actual is None else "hash_mismatch")
        records.append({"path": str(resolved), "expected_sha256": expected, "actual_sha256": actual, "status": status})
        if status != "match":
            errors.append(f"required file {resolved}: {status}")
    return records, errors


def _expand_required_files(
    declarations: Iterable[str],
    manifest_paths: Iterable[Path],
) -> tuple[list[dict[str, Any]], list[str]]:
    direct, errors = _parse_required_files(declarations)
    direct_by_path = {str(Path(item["path"]).resolve(strict=False)): item for item in direct}
    if len(direct_by_path) != len(direct):
        errors.append("duplicate direct required-file SHA pin")
    expanded = list(direct)
    seen = set(direct_by_path)
    manifest_paths = list(manifest_paths)
    normalized_manifests = {str(path.resolve(strict=False)) for path in manifest_paths}
    if len(manifest_paths) != 1:
        errors.append("exactly one directly SHA-pinned required-file manifest is mandatory")
    if normalized_manifests and set(direct_by_path) != normalized_manifests:
        errors.append("direct required-file pins must consist exactly of the declared pin manifest files")
    for manifest_input in manifest_paths:
        if not manifest_input.is_absolute():
            raise ValueError("required-file manifest paths must be absolute")
        manifest = manifest_input.resolve(strict=False)
        manifest_record = direct_by_path.get(str(manifest))
        if manifest_record is None or manifest_record["status"] != "match":
            errors.append(f"required-file manifest must itself have a matching direct SHA pin: {manifest}")
            continue
        try:
            payload = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception as exc:
            errors.append(f"cannot read required-file manifest {manifest}: {type(exc).__name__}: {exc}")
            continue
        if not isinstance(payload, dict) or payload.get("schema") != PIN_MANIFEST_SCHEMA:
            errors.append(f"required-file manifest schema mismatch: {manifest}")
            continue
        pins = payload.get("pins")
        if not isinstance(pins, list):
            errors.append(f"required-file manifest pins must be a list: {manifest}")
            continue
        for pin in pins:
            if not isinstance(pin, dict):
                errors.append(f"malformed required-file manifest pin in {manifest}")
                continue
            path_text = str(pin.get("path", ""))
            expected = str(pin.get("sha256", ""))
            required_path = Path(path_text)
            if not path_text or not required_path.is_absolute() or len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected):
                errors.append(f"malformed required-file pin in {manifest}: {path_text}")
                continue
            resolved = required_path.resolve(strict=False)
            key = str(resolved)
            if key in seen:
                errors.append(f"duplicate required-file pin across command/manifest: {resolved}")
                continue
            seen.add(key)
            actual = sha256_file(resolved) if resolved.is_file() else None
            status = "match" if actual == expected else ("missing_or_not_file" if actual is None else "hash_mismatch")
            expanded.append({"path": key, "expected_sha256": expected, "actual_sha256": actual, "status": status})
            if status != "match":
                errors.append(f"required file {resolved}: {status}")
        if sha256_file(manifest) != manifest_record["expected_sha256"]:
            errors.append(f"required-file manifest changed while being read: {manifest}")
    return expanded, errors


def _parse_absent_paths(declarations: Iterable[str]) -> tuple[list[dict[str, Any]], list[str]]:
    records: list[dict[str, Any]] = []
    errors: list[str] = []
    for path_text in declarations:
        path = Path(path_text)
        if not path.is_absolute():
            raise ValueError("required-absent paths must be absolute")
        resolved = path.resolve(strict=False)
        exists = resolved.exists()
        records.append({"path": str(resolved), "exists_at_preflight": exists, "status": "already_exists" if exists else "absent"})
        if exists:
            errors.append(f"required fresh path already exists: {resolved}")
    return records, errors


def _validate_env(declarations: Iterable[str]) -> dict[str, str]:
    explicit: dict[str, str] = {}
    for declaration in declarations:
        if "=" not in declaration:
            raise ValueError(f"invalid --env declaration {declaration!r}")
        key, value = declaration.split("=", 1)
        if not key or not key.replace("_", "").isalnum() or key.upper() != key:
            raise ValueError(f"invalid --env key {key!r}")
        explicit[key] = value
    return explicit


def run_supervised(
    args: argparse.Namespace,
    api: Any = psutil,
) -> int:
    command = list(args.command)
    if command[:1] == ["--"]:
        command = command[1:]
    if not command or args.wall_seconds <= 0 or args.rss_bytes <= 0:
        raise ValueError("a command and positive limits are required")

    cwd = args.cwd.resolve(strict=True)
    thread_environment = {
        "JULIA_NUM_THREADS": "1",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
        "NUMEXPR_NUM_THREADS": "1",
    }
    explicit_environment = _validate_env(args.env)
    environment = dict(os.environ)
    environment.update(thread_environment)
    environment.update(explicit_environment)
    required_files, preflight_errors = _expand_required_files(
        args.require_file_sha256,
        getattr(args, "require_file_sha256_manifest", []),
    )
    required_absent_paths, absent_errors = _parse_absent_paths(args.require_absent_path)
    preflight_errors.extend(absent_errors)

    for output in (args.stdout, args.stderr, args.receipt):
        output.parent.mkdir(parents=True, exist_ok=True)
    args.stdout.touch(exist_ok=True)
    args.stderr.touch(exist_ok=True)
    host_interpreter = Path(sys.executable).resolve(strict=True)
    host_interpreter_sha256 = sha256_file(host_interpreter)
    started_utc = utc_now()
    started = time.monotonic()
    common = {
        "schema": "fusionconceptai:recorded-process-execution-v2",
        "supervisor_version": "freegs-process-supervisor-v24",
        "tree_observation_contract": "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound",
        "name": args.name,
        "started_utc": started_utc,
        "cwd": str(cwd),
        "command_argv": command,
        "host_interpreter_path": str(host_interpreter),
        "host_interpreter_sha256": host_interpreter_sha256,
        "thread_environment": thread_environment,
        "explicit_environment": explicit_environment,
        "wall_limit_seconds": args.wall_seconds,
        "process_tree_rss_limit_bytes": args.rss_bytes,
        "required_files": required_files,
        "required_absent_paths": required_absent_paths,
    }
    if preflight_errors:
        args.stdout.write_bytes(b"")
        args.stderr.write_text("\n".join(preflight_errors) + "\n", encoding="utf-8")
        receipt = {
            **common,
            "finished_utc": utc_now(),
            "child_root_pid": None,
            "root_identity": None,
            "root_identity_binding": None,
            "natural_root_exit_identity_check": None,
            "observed_processes": [],
            "elapsed_seconds": time.monotonic() - started,
            "peak_complete_process_tree_rss_bytes": 0,
            "sample_count": 0,
            "complete_sample_count": 0,
            "all_samples_complete": False,
            "stop_reason": "preflight_failed",
            "preflight_errors": preflight_errors,
            "child_exit_code": None,
            "harness_exit_code": PREFLIGHT_EXIT,
            "tree_exit_proven": False,
            "termination": None,
            "stdout_path": str(args.stdout.resolve()),
            "stdout_sha256": sha256_file(args.stdout),
            "stderr_path": str(args.stderr.resolve()),
            "stderr_sha256": sha256_file(args.stderr),
            "required_files_after": required_files,
            "required_file_changes": [],
            "pins_stable_during_run": None,
            "evidence_status": "preflight_failed_no_child",
            "samples": [],
        }
        write_receipt(args.receipt, receipt)
        return PREFLIGHT_EXIT

    samples: list[dict[str, Any]] = []
    tracked: dict[tuple[int, float], tuple[ProcessIdentity, Any]] = {}
    all_sample_errors: list[dict[str, Any]] = []
    peak_rss = 0
    stop_reason = "supervisor_not_started"
    child_exit_code: int | None = None
    harness_exit_code = TREE_EVIDENCE_EXIT
    tree_exit_proven = False
    termination: dict[str, Any] | None = None
    root: Any = None
    root_identity: ProcessIdentity | None = None
    child: Any = None
    root_identity_binding: dict[str, Any] | None = None
    natural_root_exit_identity_check: dict[str, Any] | None = None
    try:
        with args.stdout.open("wb") as stdout_stream, args.stderr.open("wb") as stderr_stream:
            child = api.Popen(
                command,
                cwd=str(cwd),
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=stdout_stream,
                stderr=stderr_stream,
            )
            root_identity_binding = {"status": "unverified"}
            popen_identity = _identity(child, api, "popen_root_identity")
            root_identity_binding.update({
                "status": "popen_identity_observed",
                "popen_identity": _identity_record(popen_identity),
            })
            try:
                candidate_root = api.Process(child.pid)
            except Exception as exc:
                raise ProcessTreeEvidenceError("root_process_lookup", child.pid, exc) from exc
            lookup_identity = _identity(candidate_root, api, "lookup_root_identity")
            root_identity_binding.update({
                "status": "lookup_identity_observed",
                "process_lookup_identity": _identity_record(lookup_identity),
            })
            if popen_identity != lookup_identity:
                root_identity_binding["status"] = "mismatch"
                root_identity_binding["expected_identity"] = _identity_record(popen_identity)
                raise ProcessTreeEvidenceError(
                    "root_identity_binding_mismatch",
                    popen_identity.pid,
                    ValueError("Popen and Process lookup must identify the same (pid, create_time) before sampling"),
                    details={
                        "popen_identity": _identity_record(popen_identity),
                        "process_lookup_identity": _identity_record(lookup_identity),
                    },
                )
            root_identity_binding["status"] = "verified"
            root_identity_binding["bound_identity"] = _identity_record(popen_identity)
            root = candidate_root
            root_identity = popen_identity
            tracked[root_identity.key()] = (root_identity, root)
            stop_reason = "monitoring"

            while True:
                elapsed = time.monotonic() - started
                try:
                    snapshot = observe_process_tree(root, api, expected_root_identity=root_identity)
                except ProcessTreeEvidenceError as exc:
                    all_sample_errors.append(exc.as_dict())
                    samples.append({
                        "elapsed_seconds": elapsed,
                        "complete": False,
                        "process_tree_rss_bytes": None,
                        "processes": [],
                        "error": exc.as_dict(),
                    })
                    stop_reason = "incomplete_process_tree_observation"
                    if exc.operation in {"sample_root_identity_mismatch", "sample_root_not_live"}:
                        # The PID may now name a different process. Only the
                        # Popen-owned child handle may be used for cleanup.
                        termination = stop_child_without_process_identity(child, api)
                        tree_exit_proven = False
                    else:
                        termination = stop_and_verify(root, root_identity, tracked, api)
                        tree_exit_proven = bool(termination["tree_exit_proven"])
                    harness_exit_code = TREE_EVIDENCE_EXIT
                    break

                # Retain the exact handles collected by the successful snapshot.
                for identity, process in snapshot.handles:
                    tracked.setdefault(identity.key(), (identity, process))

                peak_rss = max(peak_rss, snapshot.rss_bytes)
                samples.append({
                    "elapsed_seconds": elapsed,
                    "complete": True,
                    "process_tree_rss_bytes": snapshot.rss_bytes,
                    "processes": list(snapshot.processes),
                    "error": None,
                })
                if snapshot.rss_bytes >= args.rss_bytes:
                    stop_reason = "process_tree_rss_limit"
                    termination = stop_and_verify(root, root_identity, tracked, api)
                    tree_exit_proven = bool(termination["tree_exit_proven"])
                    child_exit_code = RESOURCE_RSS_EXIT
                    harness_exit_code = RESOURCE_RSS_EXIT if tree_exit_proven else TREE_EVIDENCE_EXIT
                    if not tree_exit_proven:
                        stop_reason = "process_tree_rss_limit_exit_unproven"
                    break
                if elapsed >= args.wall_seconds:
                    stop_reason = "wall_timeout"
                    termination = stop_and_verify(root, root_identity, tracked, api)
                    tree_exit_proven = bool(termination["tree_exit_proven"])
                    child_exit_code = RESOURCE_WALL_EXIT
                    harness_exit_code = RESOURCE_WALL_EXIT if tree_exit_proven else TREE_EVIDENCE_EXIT
                    if not tree_exit_proven:
                        stop_reason = "wall_timeout_exit_unproven"
                    break
                try:
                    child_exit_code = child.wait(timeout=POLL_SECONDS)
                    stop_reason = "root_natural_exit"
                    try:
                        natural_root_exit_identity_check = _verify_natural_root_identity(
                            child, root, root_identity, api
                        )
                    except ProcessTreeEvidenceError as exc:
                        natural_root_exit_identity_check = {
                            "status": "failed",
                            "error": exc.as_dict(),
                        }
                        raise
                    descendant_audit = audit_tracked_processes(tracked, root_identity, api)
                    if descendant_audit["unknown_processes"]:
                        stop_reason = "natural_root_exit_descendant_state_unknown"
                        termination = stop_and_verify(root, root_identity, tracked, api)
                        harness_exit_code = TREE_EVIDENCE_EXIT
                        tree_exit_proven = bool(termination["tree_exit_proven"])
                        break
                    if descendant_audit["alive_descendants"]:
                        stop_reason = "natural_root_exit_with_live_descendants"
                        termination = stop_and_verify(root, root_identity, tracked, api)
                        harness_exit_code = TREE_EVIDENCE_EXIT
                        tree_exit_proven = bool(termination["tree_exit_proven"])
                        break
                    tree_exit_proven = True
                    harness_exit_code = int(child_exit_code)
                    break
                except api.TimeoutExpired:
                    continue
                except Exception as exc:
                    if isinstance(exc, ProcessTreeEvidenceError):
                        error = exc.as_dict()
                        stop_reason = "natural_root_identity_check_failed"
                        termination = stop_child_without_process_identity(child, api)
                        tree_exit_proven = False
                    else:
                        error = {
                            "operation": "root_wait",
                            "pid": root_identity.pid,
                            "error_type": type(exc).__name__,
                            "message": str(exc),
                        }
                        stop_reason = "root_wait_observation_failure"
                        termination = stop_and_verify(root, root_identity, tracked, api)
                        tree_exit_proven = bool(termination["tree_exit_proven"])
                    all_sample_errors.append(error)
                    harness_exit_code = TREE_EVIDENCE_EXIT
                    break
    except BaseException as exc:
        if isinstance(exc, ProcessTreeEvidenceError):
            error = exc.as_dict()
            if exc.operation == "root_identity_binding_mismatch":
                stop_reason = "root_identity_binding_failed"
            else:
                stop_reason = "supervisor_exception"
        else:
            error = {
                "operation": "supervisor_exception",
                "error_type": type(exc).__name__,
                "message": str(exc),
            }
            stop_reason = "supervisor_exception"
        all_sample_errors.append(error)
        if root is not None and root_identity is not None:
            try:
                termination = stop_and_verify(root, root_identity, tracked, api)
                tree_exit_proven = bool(termination["tree_exit_proven"])
            except Exception as stop_exc:
                termination = {
                    "tree_exit_proven": False,
                    "cleanup_exception": {"error_type": type(stop_exc).__name__, "message": str(stop_exc)},
                }
        elif child is not None:
            termination = stop_child_without_process_identity(child, api)
            tree_exit_proven = False
        harness_exit_code = TREE_EVIDENCE_EXIT

    elapsed = time.monotonic() - started
    stdout_sha = sha256_file(args.stdout)
    stderr_sha = sha256_file(args.stderr)
    required_after, required_changes = rehash_required_files(required_files)
    pins_stable = not required_changes and all(item["status"] == "match" for item in required_after)
    all_samples_complete = bool(samples) and all(bool(item["complete"]) for item in samples)
    evidence_status = "recorded_complete_samples" if all_samples_complete and tree_exit_proven else "invalid_process_tree_evidence"
    if not pins_stable:
        evidence_status = "invalid_pin_drift"
    receipt = {
        **common,
        "finished_utc": utc_now(),
        "child_root_pid": getattr(child, "pid", None),
        "root_identity": None if root_identity is None else {
            "pid": root_identity.pid,
            "create_time_epoch_s": root_identity.create_time_epoch_s,
        },
        "root_identity_binding": root_identity_binding,
        "natural_root_exit_identity_check": natural_root_exit_identity_check,
        "observed_processes": [
            {"pid": identity.pid, "create_time_epoch_s": identity.create_time_epoch_s}
            for identity, _ in sorted(tracked.values(), key=lambda item: item[0].key())
        ],
        "elapsed_seconds": elapsed,
        "peak_complete_process_tree_rss_bytes": peak_rss,
        "sample_count": len(samples),
        "complete_sample_count": sum(1 for item in samples if item["complete"]),
        "all_samples_complete": all_samples_complete,
        "stop_reason": stop_reason,
        "observation_errors": all_sample_errors,
        "child_exit_code": child_exit_code,
        "harness_exit_code": harness_exit_code,
        "tree_exit_proven": tree_exit_proven,
        "tree_exit_proof_scope": "root natural exit plus all identities discovered by complete recursive samples audited gone; sampled evidence only, not OS job containment",
        "termination": termination,
        "stdout_path": str(args.stdout.resolve()),
        "stdout_sha256": stdout_sha,
        "stderr_path": str(args.stderr.resolve()),
        "stderr_sha256": stderr_sha,
        "preflight_errors": [],
        "required_files_after": required_after,
        "required_file_changes": required_changes,
        "pins_stable_during_run": pins_stable,
        "evidence_status": evidence_status,
        "samples": samples,
    }
    write_receipt(args.receipt, receipt)
    return int(harness_exit_code)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--cwd", type=Path, required=True)
    parser.add_argument("--wall-seconds", type=float, required=True)
    parser.add_argument("--rss-bytes", type=int, required=True)
    parser.add_argument("--stdout", type=Path, required=True)
    parser.add_argument("--stderr", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("--require-file-sha256", action="append", default=[])
    parser.add_argument("--require-file-sha256-manifest", type=Path, action="append", default=[])
    parser.add_argument("--require-absent-path", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args(argv)
    try:
        return run_supervised(args)
    except (ValueError, OSError) as exc:
        parser.error(str(exc))
        return PREFLIGHT_EXIT


if __name__ == "__main__":
    raise SystemExit(main())
