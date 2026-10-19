"""Root-owned, read-only-verifiable external process audit for the frozen R16 run.

This launcher is the only component that may create ``outer_supervisor_audit.json``.
Its receipt records the actual child launch and process observations; it is not a
cryptographic signature and conveys no numerical or physical credit.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Iterable

try:
    import psutil  # type: ignore[import-not-found]
except ImportError:  # Static fake-process tests do not require psutil.
    psutil = None  # type: ignore[assignment]


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
ARCHIVE_ROOT = (
    ROOT
    / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
      "native_g1g2_prelaunch_r16_v1"
).resolve()
R16_RUNNER = TEST_DIR / "run_recorded_r16_v1.py"
R16_PARENT_PROTOCOL = (
    ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
         "native_g1g2_prelaunch_r16_v1/r16_static_v4/protocol.json"
)
R16_RESOURCE_REPORTER = TEST_DIR / "report_r16_resource_outcome_v1.py"
R18_REPORTER = TEST_DIR / "report_r18_resource_outcome_v1.py"
R18_TEST = TEST_DIR / "test_r18_resource_outcome_v1.py"
R18_PARENT_PROTOCOL = (
    ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
         "native_g1g2_r18_root_identity_static_20260924/protocol.json"
)
r22_PROTOCOL = (
    ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
         "native_g1g2_r22_cim_filetime_static_20260924/protocol.json"
)
R21_LINEAGE_PINS = [
    {
        "role": "r21_protocol",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r21_pid0_idle_inventory_static_20260924/protocol.json",
        "sha256": "2191689a3bee30d592b717354e0711b857d9921d986e375b900eaf5510449957",
    },
    {
        "role": "r21_manifest_v2",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r21_pid0_idle_inventory_static_20260924/manifest_v2.json",
        "sha256": "60afce43d10e877b96c030b3b761be4992193604aabed176003de9b1ea6e6e2e",
    },
    {
        "role": "r21_boundary_review",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r21_pid0_idle_inventory_static_20260924/read_only_host_boundary_review.md",
        "sha256": "1b3a31ba6e8bfd68348111080bd87606575aa289962c2cf9f082d58a52cde19f",
    },
    {
        "role": "r21_supervisor",
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r21_v1.py",
        "sha256": "dc9d6915c1f41f110685a9726b450f04eab0b4fe0083beaf11fb1dd4cb920c27",
    },
    {
        "role": "r21_python_tests",
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r21_v1.py",
        "sha256": "a3c8c748c5a651cf64f4a0f1cfaf545958f995fe00a323a1462c8704986f33ae",
    },
    {
        "role": "independent_r20_r21_r22_review_prior_r22_raw_generation_gate",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/independent_native_g1g2_r20_r21_r22_review_20260925/review.md",
        "sha256": "60af4fa89be149177582a47680da9b352df88a39be5e5c286ac078750c5a1f79",
    },
]
R20_RUNTIME_FAILURE_PINS = [
    {
        "role": "r20_static_manifest",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r20_strict_identity_static_20260924/manifest.json",
        "sha256": "e94368b479744c5a3c433932a06505d3f2294b97df5c008654d86fd7d5b09554",
    },
    {
        "role": "r20_protocol",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r20_strict_identity_static_20260924/protocol.json",
        "sha256": "3dc4800818a262d64e59cde75ed71c4bee81272e3c25ab501c1eab9d1a78db9a",
    },
    {
        "role": "r20_runtime_root_decision",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/decision.md",
        "sha256": "a594dd4fe50fac8706dd34ce9be21e8d809f67ae55a8ce6f6366b9ba00f63b5d",
    },
    {
        "role": "r20_runtime_postrun_assessment",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/postrun_assessment.md",
        "sha256": "8eede4df1a14d9f47ea2e8306a917c4d858c04cc30c0cc03834bcb1176a72afa",
    },
    {
        "role": "r20_runtime_invocation",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/invocation.json",
        "sha256": "7af5498c1fce95549e2ade57f8a40855156de10f41f25b7fc2ddf4acb57527dc",
    },
    {
        "role": "r20_runtime_invocation_exit",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/invocation.exit.txt",
        "sha256": "f1b2f662800122bed0ff255693df89c4487fbdcf453d3524a42d4ec20c3d9c04",
    },
    {
        "role": "r20_runtime_stderr",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/invocation.stderr.raw",
        "sha256": "62217d614e8240b634856a25cd4e07183871fc22b786f65a76e16d7b56ddbd29",
    },
    {
        "role": "r20_runtime_start_receipt",
        "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r20_runtime_grant_20260924/start.json",
        "sha256": "8a91b315545e1f3340c341e15cb3be1befd752d32adc1f03f63a045dd0de62da",
    },
]
R20_RUNTIME_FAILURE_CONTEXT = {
    "exit_code": 1,
    "phase": "pre_run_heavy_process_inventory",
    "cause": "Windows psutil.Process(0) is a genuine global inventory sentinel with PID 0, create_time 0.0, name System Idle Process; R20 routed it through the positive launched-process identity gate",
    "julia_started": False,
    "planned_actual_output_leaf_created": False,
    "evidence_pins": R20_RUNTIME_FAILURE_PINS,
}
R22_RUNTIME_DISPATCH_STATUS = {
    "eligible": False,
    "status": "NO_GO_exact_psutil_to_CIM_generation_binding_unavailable",
    "reason": "the prior R22 float-to-CIM fallback accepts adjacent FILETIME generations and exact raw handle reads are denied for PID 332 on this host",
    "runtime_executed": False,
    "julia_started": False,
    "requires_independent_review_and_root_grant": True,
}
R21_INDEPENDENT_REVIEW_CONTEXT = {
    "status": "NO_GO_R21_and_prior_R22_candidate",
    "report_path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/independent_native_g1g2_r20_r21_r22_review_20260925/review.md",
    "report_sha256": "60af4fa89be149177582a47680da9b352df88a39be5e5c286ac078750c5a1f79",
    "claim": "R21 inventory remains incomplete; reviewer found a one-tick psutil-to-CIM generation alias in the prior R22 source bytes",
}

R16_PARENT_PROTOCOL_SHA256 = "e37663ea794f69d862f57a3ad068bb7928ba8073e2e4e9754cc14118e993ffe6"
R16_RUNNER_SHA256 = "d39dfd70f5ce473c775a4c33c9072338e838d64db7a6fa0046a8f180bca1f4d0"
R16_RESOURCE_REPORTER_SHA256 = "b8f7a9e5c2dcd0ea31f4601f2d9e559a9d62050cef3d907a00d604c5d53cd408"
R18_REPORTER_SHA256 = "903bfccca105ca7dd4457700c6f08422c9f9ef2af2384b24eb343b4a7961abbb"
R18_TEST_SHA256 = "ba0f181f65ba31636f7bb76e72fe544c5a017b6e223e2de3fb9da74713de0d0e"
R18_PARENT_PROTOCOL_SHA256 = "551147326d1506cb7a6846c5626e3742e84a2f66235c11175f2ef3d796e8c9f6"

STAGE_ORDER = ("parse_all", "primary", "fresh_replay")
RSS_THRESHOLD_BYTES = 2_147_483_648
SAMPLE_INTERVAL_SECONDS = 0.2
STAGE_WALL_SECONDS = 480.0
HEAP_HINT = "1G"
COMPILER_MODE = "--compile=min"
WAIT_TIMEOUT_SECONDS = 10.0
FILETIME_TICKS_PER_SECOND = 10_000_000
UNIX_EPOCH_FILETIME_SECONDS = 11_644_473_600
OUTER_AUDIT_FILENAME = "outer_supervisor_audit.json"
SAMPLE_LOG_FILENAME = "outer_process_tree_samples.jsonl"
SCAN_LOG_FILENAME = "outer_stage_residual_scans.json"
REPORT_BINDING_FILENAME = "outer_r18_report_binding.json"
HEAVY_NAMES = {"julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh"}
WINDOWS_IDLE_PID = 0
WINDOWS_IDLE_NAME = "System Idle Process"
WINDOWS_IDLE_INVENTORY_RULE = {
    "scope": "global_pre_and_post_run_inventory_only",
    "platform_gate": "os.name == 'nt'",
    "provider_gate": "type(process) is psutil.Process",
    "pid_gate": "type(pid) is int and pid == 0",
    "create_time_gate": "type(value) is float and finite positive-zero only",
    "name_gate": "exact string System Idle Process",
    "recheck": "pid/create_time/name re-read after initial validation",
    "disposition": "record as excluded_processes; do not pass to launched-process identity flow",
}
WINDOWS_SYSTEM_ROW_RULE = {
    "scope": "global_inventory_classification_only_for_nonheavy_os_rows",
    "provider_gate": "type(process) is psutil.Process and os.name == 'nt'",
    "identity_snapshot": "psutil PID/create_time/name rechecked around two independent CIM and tasklist snapshots",
    "cim_generation_identity": "exact Win32_Process CreationDate roundtrip token and FILETIME ticks; both snapshots must match byte-for-byte; no psutil float comparison or tolerance",
    "tasklist_identity": "exactly one CSV row for the requested PID per snapshot; both names and PIDs must match",
    "system_pid4_gate": "PID 4; psutil exact name System and finite positive-zero create_time; CIM exact name System and parent PID 0; tasklist exact name System",
    "empty_psutil_name_gate": "only exact empty string; two CIM/tasklist snapshots must agree on nonempty name and exact before/after raw handle FILETIME must equal both CIM FILETIME ticks",
    "heavy_process_gate": "resolved heavy names still require exact raw process-handle FILETIME generation before/after resource sampling and normal control receipts",
    "permission_or_source_failure": "resource_monitor_incomplete; never omit row",
    "disposition": "PID4 System is recorded as a non-signallable OS sentinel; other rows are classified normally from corroborated name",
    "trust_boundary": "local Windows psutil/CIM/tasklist observations; not a cryptographic signature or physical/numerical authority",
}
WINDOWS_PROCESS_SOURCE_CONTRACT = {
    "cim_provider": "local PowerShell Get-CimInstance Win32_Process; exact single-PID filter; raw CreationDate roundtrip token and ToFileTimeUtc ticks",
    "tasklist_provider": "Windows System32 tasklist.exe with PID equality filter and CSV/no-header output",
    "snapshot_count": 2,
    "snapshot_order": "CIM then tasklist, followed by an independent second CIM then tasklist lookup",
    "same_generation_rule": "exact PID/name/parent/CreationDate token/FILETIME equality across CIM snapshots, PID/name equality across tasklist snapshots, and exact raw process-handle FILETIME equality to both CIM snapshots for empty-name fallback",
    "source_authentication": "system component paths plus exact process/provider type and repeated observations; no cryptographic source claim",
    "denial_behavior": "any provider, row-shape, access, parse, or consistency error fails the global inventory closed",
}
ACTUAL_DISPATCH_TOKEN = "ROOT-GRANT-R16-R22-ACTUAL"
IDENTITY_TYPE_CONTRACT = {
    "pid": "type(value) is int and value > 0; bool rejected",
    "create_time": "type(value) is float and finite and > 0; int/bool/nonfinite rejected",
    "check_order": "validate both identities before equality, wait, or signal",
    "rechecks": [
        "tree_member_after_resources",
        "tree_root_after_enumeration",
        "process_exit_before_and_after_wait",
        "process_kill_twice_before_signal",
        "root_popen_generation_before_signal_and_wait",
        "global_inventory_before_and_after_reads",
        "outer_rows_and_stage_membership_before_set_comparison",
    ],
}


class MonitorIncomplete(RuntimeError):
    """An observation or process-control operation could not be trusted."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def reporter_sha256_or_none() -> str | None:
    try:
        return sha256_file(R18_REPORTER)
    except OSError:
        return None


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, separators=(",", ":"),
                       ensure_ascii=False, allow_nan=False) + "\n").encode("utf-8")


def write_new(path: Path, value: Any) -> bytes:
    """Create one evidence file without replacing any prior bytes."""
    payload = value if isinstance(value, bytes) else json_bytes(value)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())
    return payload


def _finite_number(value: Any, *, positive: bool = False) -> bool:
    if type(value) not in (int, float):
        return False
    if not math.isfinite(float(value)):
        return False
    return float(value) > 0 if positive else float(value) >= 0


def _identity(pid: Any, created: Any) -> tuple[int, float]:
    if type(pid) is not int or pid <= 0:
        raise ValueError("process identity PID must be a positive native integer; bool is invalid")
    if type(created) is not float or not math.isfinite(created) or created <= 0:
        raise ValueError("process identity create_time must be a finite positive native float")
    return pid, created


def _identity_pair(value: Any) -> tuple[int, float]:
    if type(value) is not tuple or len(value) != 2:
        raise ValueError("process identity must be a two-item native tuple")
    return _identity(value[0], value[1])


def _same_identity(left: Any, right: Any) -> bool:
    """Compare only after both PID/create_time pairs pass strict native typing."""
    return _identity_pair(left) == _identity_pair(right)


def _validated_identity_requests(
    identities: Iterable[Any], *, phase: str
) -> tuple[list[tuple[int, float]], list[dict[str, Any]]]:
    """Validate every requested PID/time pair before deduplication or lookup."""
    valid: list[tuple[int, float]] = []
    errors: list[dict[str, Any]] = []
    try:
        iterator = iter(identities)
    except Exception as exc:
        return [], [_error(phase, exc)]
    index = 0
    while True:
        try:
            item = next(iterator)
        except StopIteration:
            break
        except Exception as exc:
            errors.append(_error(phase, exc, pid=None) | {"index": index})
            break
        try:
            identity = _identity_pair(item)
        except Exception as exc:
            errors.append(_error(phase, exc, pid=(item[0] if type(item) is tuple and item else None)) |
                          {"index": index, "observed_identity_repr": repr(item)})
        else:
            valid.append(identity)
        index += 1
    # All values reaching set/sort have passed exact native-type checks.
    return sorted(set(valid)), errors


def _identity_from_mapping(value: Any) -> tuple[int, float]:
    if not isinstance(value, dict):
        raise ValueError("process identity row must be an object")
    return _identity(value.get("pid"), value.get("create_time"))


def _identity_mapping_rows(value: Any) -> list[tuple[int, float]]:
    if not isinstance(value, list):
        raise ValueError("process identity rows must be a list")
    result = []
    for row in value:
        if not isinstance(row, dict) or set(row) != {"pid", "create_time"}:
            raise ValueError("process identity row shape is malformed")
        result.append(_identity_from_mapping(row))
    return result


def _windows_read_process_handle_identity(handle_value: Any) -> tuple[int, int]:
    """Read PID and exact raw creation FILETIME ticks from a Windows process handle."""
    if os.name != "nt":
        raise OSError("process generation binding requires Windows GetProcessTimes")
    import ctypes
    from ctypes import wintypes

    class FILETIME(ctypes.Structure):
        _fields_ = [("dwLowDateTime", wintypes.DWORD), ("dwHighDateTime", wintypes.DWORD)]

    handle = wintypes.HANDLE(int(handle_value))
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetProcessId.argtypes = [wintypes.HANDLE]
    kernel32.GetProcessId.restype = wintypes.DWORD
    kernel32.GetProcessTimes.argtypes = [
        wintypes.HANDLE, ctypes.POINTER(FILETIME), ctypes.POINTER(FILETIME),
        ctypes.POINTER(FILETIME), ctypes.POINTER(FILETIME),
    ]
    kernel32.GetProcessTimes.restype = wintypes.BOOL
    handle_pid = int(kernel32.GetProcessId(handle))
    if handle_pid <= 0:
        raise ctypes.WinError(ctypes.get_last_error())
    creation = FILETIME()
    exit_time = FILETIME()
    kernel_time = FILETIME()
    user_time = FILETIME()
    if not kernel32.GetProcessTimes(
            handle, ctypes.byref(creation), ctypes.byref(exit_time),
            ctypes.byref(kernel_time), ctypes.byref(user_time)):
        raise ctypes.WinError(ctypes.get_last_error())
    ticks = (int(creation.dwHighDateTime) << 32) | int(creation.dwLowDateTime)
    if ticks <= 0:
        raise ValueError("process handle returned a nonpositive creation FILETIME")
    return handle_pid, ticks


def _windows_popen_handle_identity(popen: Any) -> tuple[int, int]:
    """Read exact PID/generation from the original handle owned by Popen."""
    return _windows_read_process_handle_identity(getattr(popen, "_handle"))


def _windows_pid_handle_identity(pid: int) -> tuple[int, int]:
    """Open the PID afresh and read its exact generation, closing the new handle."""
    if type(pid) is not int or pid <= 0:
        raise ValueError("OpenProcess PID must be a positive native integer")
    if os.name != "nt":
        raise OSError("PID handle generation binding requires Windows OpenProcess")
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    access = 0x1000  # PROCESS_QUERY_LIMITED_INFORMATION
    handle = kernel32.OpenProcess(access, False, pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return _windows_read_process_handle_identity(handle)
    finally:
        if not kernel32.CloseHandle(handle):
            raise ctypes.WinError(ctypes.get_last_error())


def _filetime_unix_seconds(ticks: int) -> float:
    if type(ticks) is not int or ticks <= 0:
        raise ValueError("creation FILETIME ticks must be a positive native integer")
    return ticks / FILETIME_TICKS_PER_SECOND - UNIX_EPOCH_FILETIME_SECONDS


def _unix_seconds_filetime_roundtrip(seconds: float) -> int:
    if not _finite_number(seconds, positive=True):
        raise ValueError("process creation time must be finite and positive")
    return int(round((float(seconds) + UNIX_EPOCH_FILETIME_SECONDS) * FILETIME_TICKS_PER_SECOND))


def bind_popen_process_identity(
    popen: Any,
    *,
    process_factory: Callable[[int], Any] | None = None,
    handle_identity_reader: Callable[[Any], tuple[int, int]] | None = None,
    pid_handle_identity_reader: Callable[[int], tuple[int, int]] | None = None,
) -> tuple[Any | None, tuple[int, float] | None, dict[str, Any]]:
    """Bind original Popen handle, fresh PID handles, and psutil to one generation."""
    binding: dict[str, Any] = {
        "schema": "native-g1g2-r22-popen-process-identity-binding-v1",
        "method": "exact raw FILETIME ticks: Popen handle vs fresh PID handles before/after psutil lookup",
        "filetime_ticks_per_second": FILETIME_TICKS_PER_SECOND,
        "complete": False,
        "identity_match": False,
        "errors": [],
    }
    process = None
    identity: tuple[int, float] | None = None
    popen_pid = getattr(popen, "pid", None)
    binding["popen_pid"] = popen_pid
    if type(popen_pid) is not int or popen_pid <= 0:
        binding["errors"].append({"phase": "popen_pid", "reason": "invalid_popen_pid"})
        return process, identity, binding

    reader = handle_identity_reader or _windows_popen_handle_identity
    pid_reader = pid_handle_identity_reader or _windows_pid_handle_identity
    try:
        handle_pid, handle_ticks = reader(popen)
        if type(handle_pid) is not int or handle_pid <= 0 or type(handle_ticks) is not int or handle_ticks <= 0:
            raise ValueError("Popen handle returned malformed PID/FILETIME ticks")
        binding["popen_handle_pid"] = handle_pid
        binding["popen_handle_creation_filetime_ticks"] = handle_ticks
    except Exception as exc:
        binding["errors"].append(_error("popen_handle_identity", exc, pid=popen_pid))
        handle_identity = None
    else:
        handle_identity = (handle_pid, handle_ticks)

    before_identity = None
    try:
        before_pid, before_ticks = pid_reader(popen_pid)
        if type(before_pid) is not int or before_pid <= 0 or type(before_ticks) is not int or before_ticks <= 0:
            raise ValueError("fresh PID handle returned malformed PID/FILETIME ticks")
        before_identity = (before_pid, before_ticks)
        binding["fresh_pid_handle_before_pid"] = before_pid
        binding["fresh_pid_handle_before_creation_filetime_ticks"] = before_ticks
    except Exception as exc:
        binding["errors"].append(_error("fresh_pid_handle_before_psutil", exc, pid=popen_pid))

    factory = process_factory
    if factory is None:
        if psutil is None:
            binding["errors"].append({"phase": "psutil_process_lookup", "reason": "psutil_unavailable"})
            return process, identity, binding
        factory = psutil.Process  # type: ignore[union-attr]
    try:
        process = factory(popen_pid)
        process_identity = _identity(process.pid, process.create_time())
        binding["psutil_process_pid"] = process_identity[0]
        binding["psutil_process_create_time"] = process_identity[1]
    except Exception as exc:
        binding["errors"].append(_error("psutil_process_identity", exc, pid=popen_pid))
        process_identity = None

    after_identity = None
    try:
        after_pid, after_ticks = pid_reader(popen_pid)
        if type(after_pid) is not int or after_pid <= 0 or type(after_ticks) is not int or after_ticks <= 0:
            raise ValueError("fresh PID handle returned malformed PID/FILETIME ticks")
        after_identity = (after_pid, after_ticks)
        binding["fresh_pid_handle_after_pid"] = after_pid
        binding["fresh_pid_handle_after_creation_filetime_ticks"] = after_ticks
    except Exception as exc:
        binding["errors"].append(_error("fresh_pid_handle_after_psutil", exc, pid=popen_pid))

    if popen_pid != (handle_identity[0] if handle_identity else None):
        binding["errors"].append({
            "phase": "popen_handle_pid_comparison", "reason": "popen_pid_differs_from_process_handle_pid",
        })
    if popen_pid != (before_identity[0] if before_identity else None) or \
            popen_pid != (after_identity[0] if after_identity else None):
        binding["errors"].append({
            "phase": "fresh_pid_handle_pid_comparison", "reason": "fresh_pid_handle_pid_differs_from_popen_pid",
        })
    if popen_pid != (process_identity[0] if process_identity else None):
        binding["errors"].append({
            "phase": "psutil_pid_comparison", "reason": "popen_pid_differs_from_psutil_pid",
        })
    if handle_identity is not None and before_identity is not None and after_identity is not None:
        tick_identities = [handle_identity, before_identity, after_identity]
        if len(set(tick_identities)) != 1:
            binding["errors"].append({
                "phase": "exact_filetime_comparison",
                "reason": "popen_and_fresh_pid_handle_generation_mismatch",
                "observed_filetime_identities": [
                    {"pid": pid, "creation_filetime_ticks": ticks}
                    for pid, ticks in tick_identities
                ],
            })
        elif process_identity is not None:
            expected_seconds = _filetime_unix_seconds(handle_identity[1])
            binding["psutil_create_time_expected_from_filetime"] = expected_seconds
            roundtrip_ticks = _unix_seconds_filetime_roundtrip(process_identity[1])
            binding["psutil_create_time_filetime_roundtrip_ticks"] = roundtrip_ticks
            binding["psutil_float_filetime_roundtrip_delta_ticks"] = roundtrip_ticks - handle_identity[1]
            binding["psutil_float_crosscheck_semantics"] = \
                "diagnostic_only; generation decided by exact raw handle FILETIME ticks"
            binding["identity_match"] = True
            binding["generation_identity"] = {
                "pid": handle_identity[0], "creation_filetime_ticks": handle_identity[1],
            }
            identity = process_identity
    binding["complete"] = binding["identity_match"] is True and not binding["errors"]
    if not binding["complete"]:
        identity = None
    return process, identity, binding


def validate_popen_generation_binding(
    binding: Any, root_identity: tuple[int, float] | None
) -> list[str]:
    """Recheck exact raw FILETIME generation comparisons before outer pass."""
    failures: list[str] = []
    if not isinstance(binding, dict) or root_identity is None:
        return ["popen_process_generation_binding_missing"]
    if binding.get("complete") is not True or binding.get("identity_match") is not True:
        failures.append("popen_process_generation_binding_incomplete")
    if binding.get("method") != \
            "exact raw FILETIME ticks: Popen handle vs fresh PID handles before/after psutil lookup":
        failures.append("popen_process_generation_binding_method_mismatch")
    if binding.get("errors") != []:
        failures.append("popen_process_generation_binding_contains_errors")
    if binding.get("filetime_ticks_per_second") != FILETIME_TICKS_PER_SECOND:
        failures.append("popen_process_generation_binding_filetime_scale_mismatch")
    try:
        expected_pid, expected_created = _identity_pair(root_identity)
    except Exception:
        return sorted(set(failures + ["popen_process_generation_binding_outer_identity_malformed"]))
    for field in ("popen_pid", "popen_handle_pid", "fresh_pid_handle_before_pid",
                  "fresh_pid_handle_after_pid", "psutil_process_pid"):
        value = binding.get(field)
        if type(value) is not int:
            failures.append(f"popen_process_generation_binding_{field}_malformed")
        elif value != expected_pid:
            failures.append(f"popen_process_generation_binding_{field}_mismatch")
    tick_fields = (
        "popen_handle_creation_filetime_ticks",
        "fresh_pid_handle_before_creation_filetime_ticks",
        "fresh_pid_handle_after_creation_filetime_ticks",
    )
    ticks = [binding.get(field) for field in tick_fields]
    if any(type(value) is not int or value <= 0 for value in ticks):
        failures.append("popen_process_generation_binding_filetime_ticks_malformed")
    elif len(set(ticks)) != 1:
        failures.append("popen_process_generation_binding_filetime_ticks_not_identical")
    process_created = binding.get("psutil_process_create_time")
    if type(process_created) is not float or not math.isfinite(process_created) or process_created <= 0:
        failures.append("popen_process_generation_binding_psutil_create_time_malformed")
    elif float(process_created) != expected_created:
        failures.append("popen_process_generation_binding_psutil_time_differs_from_outer_root")
    if type(ticks[0]) is int and ticks[0] > 0 and _finite_number(process_created, positive=True):
        exact_seconds = _filetime_unix_seconds(ticks[0])
        roundtrip_ticks = _unix_seconds_filetime_roundtrip(float(process_created))
        if type(binding.get("psutil_create_time_expected_from_filetime")) is not float or \
                binding.get("psutil_create_time_expected_from_filetime") != exact_seconds:
            failures.append("popen_process_generation_binding_expected_filetime_time_mismatch")
        if type(binding.get("psutil_create_time_filetime_roundtrip_ticks")) is not int or \
                binding.get("psutil_create_time_filetime_roundtrip_ticks") != roundtrip_ticks:
            failures.append("popen_process_generation_binding_psutil_roundtrip_ticks_mismatch")
        if type(binding.get("psutil_float_filetime_roundtrip_delta_ticks")) is not int or \
                binding.get("psutil_float_filetime_roundtrip_delta_ticks") != roundtrip_ticks - ticks[0]:
            failures.append("popen_process_generation_binding_psutil_float_delta_mismatch")
        if binding.get("psutil_float_crosscheck_semantics") != \
                "diagnostic_only; generation decided by exact raw handle FILETIME ticks":
            failures.append("popen_process_generation_binding_float_semantics_mismatch")
    generation_identity = binding.get("generation_identity")
    if not isinstance(generation_identity, dict):
        failures.append("popen_process_generation_binding_generation_identity_mismatch")
    else:
        generation_pid = generation_identity.get("pid")
        generation_ticks = generation_identity.get("creation_filetime_ticks")
        if type(generation_pid) is not int or type(generation_ticks) is not int:
            failures.append("popen_process_generation_binding_generation_identity_malformed")
        elif generation_pid != expected_pid or generation_ticks != ticks[0]:
            failures.append("popen_process_generation_binding_generation_identity_mismatch")
    return sorted(set(failures))


def _error(phase: str, exc: BaseException, *, pid: Any = None) -> dict[str, Any]:
    return {
        "phase": phase,
        "pid": pid,
        "exception_type": type(exc).__name__,
        "exception_message": str(exc),
        "exception_repr": repr(exc),
    }


def _rss(value: Any) -> int:
    if type(value) is not int or value < 0:
        raise ValueError("RSS must be a native nonnegative integer")
    return value


def _cpu_seconds(value: Any, field: str) -> float:
    if not _finite_number(value):
        raise ValueError(f"{field} must be a finite nonnegative number")
    return float(value)


def sample_process_tree(
    root_process: Any,
    *,
    sample_index: int,
    sampled_utc: str | None = None,
    elapsed_seconds: float | None = None,
    expected_root_creation_filetime_ticks: int | None = None,
    pid_handle_identity_reader: Callable[[int], tuple[int, int]] | None = None,
) -> dict[str, Any]:
    """Sample root and all recursive descendants; any partial read is incomplete."""
    errors: list[dict[str, Any]] = []
    members: list[Any] = [root_process]
    root_identity: tuple[int, float] | None = None
    guard_required = expected_root_creation_filetime_ticks is not None
    guard_reader = pid_handle_identity_reader or _windows_pid_handle_identity
    guard_before: tuple[int, int] | None = None
    guard_after: tuple[int, int] | None = None
    root_pid = getattr(root_process, "pid", None)
    root_pid_valid = type(root_pid) is int and root_pid > 0
    if not root_pid_valid:
        errors.append({"phase": "root_pid_validation", "reason": "root_pid_must_be_positive_native_integer",
                       "observed_type": type(root_pid).__name__, "observed_repr": repr(root_pid)})
    guard_expected_valid = type(expected_root_creation_filetime_ticks) is int and \
        expected_root_creation_filetime_ticks > 0
    if guard_required and not guard_expected_valid:
        errors.append({"phase": "root_generation_guard_expected", "reason": "expected_filetime_ticks_malformed",
                       "observed_type": type(expected_root_creation_filetime_ticks).__name__,
                       "observed_repr": repr(expected_root_creation_filetime_ticks)})
    if guard_required and root_pid_valid and guard_expected_valid:
        try:
            guard_before = guard_reader(root_pid)
            if not isinstance(guard_before, tuple) or len(guard_before) != 2 or \
                    type(guard_before[0]) is not int or guard_before[0] <= 0 or \
                    type(guard_before[1]) is not int or guard_before[1] <= 0:
                raise ValueError("fresh PID handle identity must contain native integer PID/ticks")
            if guard_before != (root_pid, expected_root_creation_filetime_ticks):
                errors.append({
                    "phase": "root_generation_guard_before",
                    "reason": "root_generation_differs_from_popen_bound_raw_filetime",
                    "observed": list(guard_before),
                    "expected": [root_pid, expected_root_creation_filetime_ticks],
                })
                guard_before = None
        except Exception as exc:
            errors.append(_error("root_generation_guard_before", exc,
                                 pid=root_pid))
            guard_before = None
    try:
        root_identity = _identity(root_pid, root_process.create_time())
    except Exception as exc:
        errors.append(_error("root_identity_before_enumeration", exc,
                             pid=root_pid))
    try:
        descendants = root_process.children(recursive=True)
        if not isinstance(descendants, (list, tuple)):
            raise TypeError("recursive child enumeration did not return a list")
        members.extend(descendants)
    except Exception as exc:
        errors.append(_error("recursive_process_enumeration", exc,
                             pid=root_pid))

    rows: list[dict[str, Any]] = []
    discovered: list[dict[str, Any]] = []
    seen_pids: dict[int, float] = {}
    seen_identities: set[tuple[int, float]] = set()
    partial_rss = 0
    for member in members:
        pid = getattr(member, "pid", None)
        try:
            created_before = member.create_time()
            identity = _identity(pid, created_before)
            discovered.append({"pid": identity[0], "create_time": identity[1]})
            if identity[0] in seen_pids:
                reason = ("duplicate_process_identity" if seen_pids[identity[0]] == identity[1]
                          else "pid_reused_within_one_sample")
                raise ValueError(reason)
            seen_pids[identity[0]] = identity[1]
            if identity in seen_identities:
                raise ValueError("duplicate pid/create_time identity")
            seen_identities.add(identity)

            memory = member.memory_info()
            rss_bytes = _rss(getattr(memory, "rss", None))
            cpu = member.cpu_times()
            user_seconds = _cpu_seconds(getattr(cpu, "user", None), "cpu user seconds")
            system_seconds = _cpu_seconds(getattr(cpu, "system", None), "cpu system seconds")
            ppid = member.ppid()
            if type(ppid) is not int or ppid < 0:
                raise ValueError("parent pid must be a native nonnegative integer")
            name = member.name()
            if not isinstance(name, str) or not name:
                raise ValueError("process name is unavailable")
            command = member.cmdline()
            if not isinstance(command, (list, tuple)) or any(not isinstance(x, str) for x in command):
                raise ValueError("process command line is unavailable or malformed")
            identity_after = _identity(member.pid, member.create_time())
            if not _same_identity(identity_after, identity):
                raise ValueError("process identity changed during sample")
            partial_rss += rss_bytes
            rows.append({
                "pid": identity[0], "create_time": identity[1], "ppid": ppid,
                "name": name, "cmdline": list(command), "rss_bytes": rss_bytes,
                "cpu_user_seconds": user_seconds,
                "cpu_system_seconds": system_seconds,
            })
        except Exception as exc:
            errors.append(_error("member_resource_or_identity_read", exc, pid=pid))

    root_row_count = 0
    if root_identity is not None:
        root_row_count = sum(
            1 for row in rows
            if _same_identity(_identity_from_mapping(row), root_identity)
        )
        if root_row_count != 1:
            errors.append({
                "phase": "root_identity_membership",
                "pid": root_identity[0],
                "reason": "root_identity_missing_or_nonunique",
                "root_row_count": root_row_count,
            })
    root_pid_stable = False
    try:
        root_after_pid = getattr(root_process, "pid", None)
        root_after = _identity(root_after_pid, root_process.create_time())
        if not _same_identity(root_identity, root_after):
            raise ValueError("root identity changed during sample")
        root_pid_stable = True
    except Exception as exc:
        errors.append(_error("root_identity_after_enumeration", exc,
                             pid=getattr(root_process, "pid", None)))
    if guard_required and root_pid_valid and root_pid_stable and guard_expected_valid:
        try:
            guard_after = guard_reader(root_pid)
            if not isinstance(guard_after, tuple) or len(guard_after) != 2 or \
                    type(guard_after[0]) is not int or guard_after[0] <= 0 or \
                    type(guard_after[1]) is not int or guard_after[1] <= 0:
                raise ValueError("fresh PID handle identity must contain native integer PID/ticks")
            if guard_after != (root_pid, expected_root_creation_filetime_ticks):
                errors.append({
                    "phase": "root_generation_guard_after",
                    "reason": "root_generation_changed_during_process_tree_sample",
                    "observed": list(guard_after),
                    "expected": [root_pid, expected_root_creation_filetime_ticks],
                })
                guard_after = None
        except Exception as exc:
            errors.append(_error("root_generation_guard_after", exc,
                                 pid=root_pid))
            guard_after = None
    return {
        "schema": "native-g1g2-r22-process-tree-sample-v1",
        "sample_index": sample_index,
        "utc": sampled_utc or utc_now(),
        "elapsed_seconds": elapsed_seconds,
        "root_pid": root_identity[0] if root_identity else None,
        "root_create_time": root_identity[1] if root_identity else None,
        "root_generation_guard_required": guard_required,
        "root_creation_filetime_ticks": expected_root_creation_filetime_ticks,
        "root_generation_guard_before": (
            {"pid": guard_before[0], "creation_filetime_ticks": guard_before[1]}
            if guard_before is not None else None
        ),
        "root_generation_guard_after": (
            {"pid": guard_after[0], "creation_filetime_ticks": guard_after[1]}
            if guard_after is not None else None
        ),
        "root_generation_guard_complete": (
            not guard_required or (
                guard_before == (root_pid, expected_root_creation_filetime_ticks) and
                guard_after == (root_pid, expected_root_creation_filetime_ticks)
            )
        ),
        "root_row_count": root_row_count,
        "complete": not errors,
        "discovered_process_identities": discovered,
        "measured_process_identities": [
            {"pid": row["pid"], "create_time": row["create_time"]} for row in rows
        ],
        "processes": rows,
        "partial_rss_bytes": partial_rss,
        "rss_bytes": partial_rss if not errors else None,
        "errors": errors,
    }


def _stage_descendants_in_sample(
    rows: list[dict[str, Any]], root_identity: tuple[int, float]
) -> set[tuple[int, float]]:
    root_identity = _identity_pair(root_identity)
    by_pid: dict[int, dict[str, Any]] = {}
    for row in rows:
        identity = _identity_from_mapping(row)
        pid = identity[0]
        ppid = row.get("ppid")
        if type(ppid) is not int or ppid < 0:
            raise ValueError("process sample contains malformed parent PID")
        if pid in by_pid:
            raise ValueError("process sample contains malformed or duplicate PIDs")
        by_pid[pid] = {"pid": pid, "create_time": identity[1], "ppid": ppid}
    root = by_pid.get(root_identity[0])
    if root is None or not _same_identity(_identity_from_mapping(root), root_identity):
        return set()
    result: set[tuple[int, float]] = {root_identity}
    for row in rows:
        cursor = row
        visited: set[int] = set()
        while type(cursor.get("ppid")) is int and cursor["ppid"] in by_pid:
            parent_pid = cursor["ppid"]
            if parent_pid in visited:
                raise ValueError("process parent graph contains a cycle")
            visited.add(parent_pid)
            parent = by_pid[parent_pid]
            parent_identity = _identity_from_mapping(parent)
            if _same_identity(parent_identity, root_identity):
                row_identity = _identity_from_mapping(row)
                result.add(row_identity)
                break
            cursor = parent
    return result


def process_exit_receipts(
    handles: dict[tuple[int, float], Any],
    identities: Iterable[tuple[int, float]],
    *,
    timeout_seconds: float = WAIT_TIMEOUT_SECONDS,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Wait each exact PID/create_time identity; missing handles and errors fail closed."""
    receipts: list[dict[str, Any]] = []
    ordered, errors = _validated_identity_requests(identities, phase="descendant_exit_identity_request")
    if errors:
        return receipts, errors
    for identity in ordered:
        handle = handles.get(identity)
        if handle is None:
            errors.append({"phase": "descendant_exit_wait", "pid": identity[0],
                           "create_time": identity[1], "reason": "process_handle_not_tracked"})
            continue
        try:
            actual = _identity(handle.pid, handle.create_time())
            if not _same_identity(actual, identity):
                raise ValueError("PID/create_time changed before wait")
            immediate = _identity(handle.pid, handle.create_time())
            if not _same_identity(immediate, identity):
                raise ValueError("PID/create_time changed at wait boundary")
            code = handle.wait(timeout=timeout_seconds)
            if type(code) is not int:
                raise ValueError("wait returned no native integer exit code")
            actual_after = _identity(handle.pid, handle.create_time())
            if not _same_identity(actual_after, identity):
                raise ValueError("PID/create_time changed across exit wait")
            receipts.append({"pid": identity[0], "create_time": identity[1],
                             "exit_code": code, "exit_confirmed": True})
        except Exception as exc:
            errors.append(_error("descendant_exit_wait", exc, pid=identity[0]) |
                          {"create_time": identity[1]})
    return receipts, errors


def terminate_and_wait(
    handles: dict[tuple[int, float], Any],
    identities: Iterable[tuple[int, float]],
    *,
    timeout_seconds: float = WAIT_TIMEOUT_SECONDS,
) -> dict[str, Any]:
    """Attempt every kill and wait; any kill/wait/identity error is incomplete."""
    requested: list[dict[str, Any]] = []
    ordered, errors = _validated_identity_requests(identities, phase="kill_identity_request")
    if errors:
        return {
            "attempted": False, "kill_requests": [], "exit_receipts": [],
            "errors": errors, "complete": False,
        }
    ordered = sorted(ordered, key=lambda pair: pair[0], reverse=True)
    for identity in ordered:
        handle = handles.get(identity)
        if handle is None:
            errors.append({"phase": "kill_request", "pid": identity[0],
                           "create_time": identity[1], "reason": "process_handle_not_tracked"})
            continue
        try:
            actual = _identity(handle.pid, handle.create_time())
            if not _same_identity(actual, identity):
                raise ValueError("PID/create_time changed before kill")
            immediate = _identity(handle.pid, handle.create_time())
            if not _same_identity(immediate, identity):
                raise ValueError("PID/create_time changed at kill boundary")
            handle.kill()
            requested.append({"pid": identity[0], "create_time": identity[1],
                              "request": "sent"})
        except Exception as exc:
            errors.append(_error("kill_request", exc, pid=identity[0]) |
                          {"create_time": identity[1]})
    receipts, wait_errors = process_exit_receipts(
        handles, ordered, timeout_seconds=timeout_seconds
    )
    errors.extend(wait_errors)
    return {
        "attempted": True,
        "kill_requests": requested,
        "exit_receipts": receipts,
        "errors": errors,
        "complete": not errors and len(receipts) == len(ordered),
    }


def _windows_idle_sentinel_record(process: Any) -> dict[str, Any]:
    """Validate only the OS-provided Windows idle sentinel used in global inventory."""
    if os.name != "nt":
        raise ValueError("PID 0 exception is Windows-only")
    process_type = getattr(psutil, "Process", None) if psutil is not None else None
    if not isinstance(process_type, type) or type(process) is not process_type:
        raise ValueError("PID 0 row is not a psutil Process object")

    pid = getattr(process, "pid", None)
    created = process.create_time()
    name = process.name()
    if type(pid) is not int or pid != WINDOWS_IDLE_PID:
        raise ValueError("Windows idle sentinel PID must be the native integer zero")
    if type(created) is not float or not math.isfinite(created) or created != 0.0 or \
            math.copysign(1.0, created) < 0:
        raise ValueError("Windows idle sentinel create_time must be positive finite zero")
    if type(name) is not str or name != WINDOWS_IDLE_NAME:
        raise ValueError("Windows idle sentinel name must match the OS process name exactly")

    pid_after = getattr(process, "pid", None)
    created_after = process.create_time()
    name_after = process.name()
    if type(pid_after) is not int or pid_after != WINDOWS_IDLE_PID:
        raise ValueError("Windows idle sentinel PID changed or became malformed")
    if type(created_after) is not float or not math.isfinite(created_after) or \
            created_after != 0.0 or math.copysign(1.0, created_after) < 0:
        raise ValueError("Windows idle sentinel create_time changed or became malformed")
    if type(name_after) is not str or name_after != WINDOWS_IDLE_NAME:
        raise ValueError("Windows idle sentinel name changed or became malformed")
    return {
        "pid": WINDOWS_IDLE_PID,
        "create_time": 0.0,
        "name": WINDOWS_IDLE_NAME,
        "validation": "windows_psutil_process_pid0_positive_zero_exact_name_stable",
    }


def _windows_system_directory() -> Path:
    """Return the native Windows system directory through GetSystemDirectoryW."""
    if os.name != "nt":
        raise OSError("Windows system component lookup is Windows-only")
    import ctypes
    from ctypes import wintypes

    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetSystemDirectoryW.argtypes = [wintypes.LPWSTR, wintypes.UINT]
    kernel32.GetSystemDirectoryW.restype = wintypes.UINT
    buffer = ctypes.create_unicode_buffer(32768)
    length = int(kernel32.GetSystemDirectoryW(buffer, len(buffer)))
    if length <= 0 or length >= len(buffer):
        raise ctypes.WinError(ctypes.get_last_error())
    result = Path(buffer.value)
    if not result.is_absolute() or not result.is_dir():
        raise ValueError("GetSystemDirectoryW returned an invalid system directory")
    return result


def _windows_powershell_path() -> Path:
    path = _windows_system_directory() / "WindowsPowerShell" / "v1.0" / "powershell.exe"
    if not path.is_file():
        raise FileNotFoundError(f"Windows PowerShell system component is unavailable: {path}")
    return path


def _windows_tasklist_path() -> Path:
    path = _windows_system_directory() / "tasklist.exe"
    if not path.is_file():
        raise FileNotFoundError(f"Windows tasklist system component is unavailable: {path}")
    return path


def _decode_windows_console(data: bytes) -> str:
    try:
        return data.decode("mbcs", errors="strict")
    except Exception as exc:
        raise ValueError(f"Windows provider output encoding is unreadable: {type(exc).__name__}") from exc


def _validate_cim_process_snapshot(value: Any, requested_pid: int) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {
            "pid", "name", "parent_pid", "creation_date_token", "creation_filetime_ticks"}:
        raise ValueError("CIM Win32_Process row shape is malformed")
    pid = value["pid"]
    name = value["name"]
    parent_pid = value["parent_pid"]
    token = value["creation_date_token"]
    ticks = value["creation_filetime_ticks"]
    if type(pid) is not int or pid <= 0 or pid != requested_pid:
        raise ValueError("CIM Win32_Process PID differs from requested native PID")
    if type(name) is not str or not name or name != name.strip():
        raise ValueError("CIM Win32_Process name is missing or malformed")
    if type(parent_pid) is not int or parent_pid < 0:
        raise ValueError("CIM Win32_Process parent PID is malformed")
    if type(token) is not str or not token:
        raise ValueError("CIM Win32_Process CreationDate token is missing")
    if type(ticks) is not int or ticks <= 0:
        raise ValueError("CIM Win32_Process CreationDate FILETIME ticks are malformed")
    return {
        "pid": pid,
        "name": name,
        "parent_pid": parent_pid,
        "creation_date_token": token,
        "creation_filetime_ticks": ticks,
    }


def _windows_cim_process_snapshot(pid: int) -> dict[str, Any]:
    """Read one exact local Win32_Process row; errors are never treated as absence."""
    if type(pid) is not int or pid <= 0:
        raise ValueError("CIM process lookup PID must be a positive native integer")
    powershell = _windows_powershell_path()
    script = f"""
$ErrorActionPreference = 'Stop'
$rows = @(Get-CimInstance -ClassName Win32_Process -Filter 'ProcessId = {pid}' -ErrorAction Stop | ForEach-Object {{
  $created = [datetime]$_.CreationDate
  [pscustomobject][ordered]@{{
    pid = [int]$_.ProcessId
    name = [string]$_.Name
    parent_pid = [int]$_.ParentProcessId
    creation_date_token = $created.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
    creation_filetime_ticks = [long]$created.ToFileTimeUtc()
  }}
}})
$json = ConvertTo-Json -InputObject $rows -Compress -Depth 4
[Console]::Out.WriteLine([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($json)))
"""
    completed = subprocess.run(
        [str(powershell), "-NoProfile", "-NonInteractive", "-Command", script],
        check=False, capture_output=True, timeout=15.0,
    )
    stdout = _decode_windows_console(completed.stdout).strip()
    stderr = _decode_windows_console(completed.stderr).strip()
    if completed.returncode != 0 or stderr:
        raise RuntimeError(
            f"PowerShell CIM provider failed (exit={completed.returncode}; stderr={stderr[:400]})"
        )
    try:
        payload = __import__("base64").b64decode(stdout, validate=True).decode("utf-8", errors="strict")
        rows = json.loads(payload)
    except Exception as exc:
        raise ValueError(f"CIM provider JSON/base64 output is malformed: {type(exc).__name__}") from exc
    if type(rows) is not list or len(rows) != 1:
        raise ValueError("CIM provider did not return exactly one requested process row")
    return _validate_cim_process_snapshot(rows[0], pid)


def _windows_tasklist_process_snapshot(pid: int) -> dict[str, Any]:
    """Read one PID-filtered CSV tasklist row from the Windows system directory."""
    if type(pid) is not int or pid <= 0:
        raise ValueError("tasklist process lookup PID must be a positive native integer")
    tasklist = _windows_tasklist_path()
    completed = subprocess.run(
        [str(tasklist), "/FI", f"PID eq {pid}", "/FO", "CSV", "/NH"],
        check=False, capture_output=True, timeout=15.0,
    )
    stdout = _decode_windows_console(completed.stdout)
    stderr = _decode_windows_console(completed.stderr).strip()
    if completed.returncode != 0 or stderr:
        raise RuntimeError(
            f"tasklist provider failed (exit={completed.returncode}; stderr={stderr[:400]})"
        )
    try:
        rows = [row for row in csv.reader(io.StringIO(stdout)) if row]
    except Exception as exc:
        raise ValueError(f"tasklist CSV is malformed: {type(exc).__name__}") from exc
    if len(rows) != 1 or len(rows[0]) < 2:
        raise ValueError("tasklist did not return exactly one requested process row")
    name, pid_text = rows[0][0], rows[0][1]
    if not pid_text.isascii() or not pid_text.isdecimal():
        raise ValueError("tasklist CSV PID is malformed")
    result = {"pid": int(pid_text), "name": name}
    if result["pid"] != pid or type(name) is not str or not name or name != name.strip():
        raise ValueError("tasklist CSV PID/name differs from requested process")
    return result


def _validate_tasklist_process_snapshot(value: Any, requested_pid: int) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {"pid", "name"}:
        raise ValueError("tasklist row shape is malformed")
    pid, name = value["pid"], value["name"]
    if type(pid) is not int or pid != requested_pid:
        raise ValueError("tasklist PID differs from requested native PID")
    if type(name) is not str or not name or name != name.strip():
        raise ValueError("tasklist image name is missing or malformed")
    return {"pid": pid, "name": name}


def _stable_windows_process_metadata(
    process: Any,
    pid: int,
    *,
    cim_reader: Callable[[int], Any] | None = None,
    tasklist_reader: Callable[[int], Any] | None = None,
    filetime_reader: Callable[[int], tuple[int, int]] | None = None,
    system_pid4: bool = False,
) -> tuple[str, dict[str, Any]]:
    """Bind a non-heavy system row to two exact CIM/tasklist snapshots and psutil rechecks."""
    if os.name != "nt":
        raise OSError("Windows CIM/tasklist system-row resolution is Windows-only")
    process_type = getattr(psutil, "Process", None) if psutil is not None else None
    if not isinstance(process_type, type) or type(process) is not process_type:
        raise ValueError("system-row source is not the exact psutil.Process provider type")
    if type(pid) is not int or pid <= 0:
        raise ValueError("system-row requested PID is malformed or changed")

    def read_process_pid() -> int:
        observed = getattr(process, "pid", None)
        if type(observed) is not int or observed <= 0 or observed != pid:
            raise ValueError("psutil process PID is malformed or changed")
        return observed

    cim_reader = cim_reader or _windows_cim_process_snapshot
    tasklist_reader = tasklist_reader or _windows_tasklist_process_snapshot

    read_process_pid()
    created_before = process.create_time()
    name_before = process.name()
    if type(name_before) is not str:
        raise ValueError("psutil process name is not a native string")
    if system_pid4:
        if pid != 4 or type(created_before) is not float or not math.isfinite(created_before) or \
                created_before != 0.0 or math.copysign(1.0, created_before) < 0 or \
                name_before != "System":
            raise ValueError("PID 4 is not the exact psutil System positive-zero sentinel")
    else:
        _identity(pid, created_before)
        if name_before != "":
            raise ValueError("CIM fallback is allowed only for an exact empty psutil name")
        raw_reader = filetime_reader or _windows_pid_handle_identity
        raw_before = _validated_raw_process_filetime(pid, raw_reader)

    cim_first = _validate_cim_process_snapshot(cim_reader(pid), pid)
    task_first = _validate_tasklist_process_snapshot(tasklist_reader(pid), pid)
    read_process_pid()
    created_middle = process.create_time()
    name_middle = process.name()
    if type(name_middle) is not str:
        raise ValueError("psutil process PID/name changed during metadata lookup")
    cim_second = _validate_cim_process_snapshot(cim_reader(pid), pid)
    task_second = _validate_tasklist_process_snapshot(tasklist_reader(pid), pid)
    read_process_pid()
    created_after = process.create_time()
    name_after = process.name()
    read_process_pid()
    created_confirm = process.create_time()
    name_confirm = process.name()
    if type(name_after) is not str or type(name_confirm) is not str:
        raise ValueError("psutil process PID/name changed after metadata lookup")

    cim_identity = lambda row: (row["pid"], row["name"], row["parent_pid"],
                                row["creation_date_token"], row["creation_filetime_ticks"])
    task_identity = lambda row: (row["pid"], row["name"])
    if cim_identity(cim_first) != cim_identity(cim_second):
        raise ValueError("Win32_Process PID/name/parent/CreationDate generation changed between snapshots")
    if task_identity(task_first) != task_identity(task_second):
        raise ValueError("tasklist PID/name changed between snapshots")
    if task_first["name"] != cim_first["name"]:
        raise ValueError("CIM and tasklist process names disagree")
    if system_pid4:
        created_values = (created_before, created_middle, created_after, created_confirm)
        if any(type(value) is not float or not math.isfinite(value) or value != 0.0 or
               math.copysign(1.0, value) < 0 for value in created_values):
            raise ValueError("PID 4 psutil create_time is not stable positive zero")
        if any(value != "System" for value in (name_before, name_middle, name_after,
                                                name_confirm, cim_first["name"], task_first["name"])):
            raise ValueError("PID 4 name is not System across both Windows sources")
        if cim_first["parent_pid"] != 0:
            raise ValueError("PID 4 Win32_Process parent PID is not zero")
        disposition = "excluded_non_signallable_windows_system_pid4_global_inventory_only"
    else:
        raw_after = _validated_raw_process_filetime(pid, raw_reader)
        if not _same_raw_process_filetime(raw_before, raw_after):
            raise ValueError("raw process-handle FILETIME generation changed during system-row classification")
        if not _same_raw_process_filetime(raw_before, (pid, cim_first["creation_filetime_ticks"])):
            raise ValueError("raw process-handle FILETIME does not exactly match the first CIM generation")
        if not _same_raw_process_filetime(raw_after, (pid, cim_second["creation_filetime_ticks"])):
            raise ValueError("raw process-handle FILETIME does not exactly match the second CIM generation")
        identities = [_identity(pid, value) for value in
                      (created_before, created_middle, created_after, created_confirm)]
        if not (_same_identity(identities[0], identities[1]) and
                _same_identity(identities[1], identities[2])):
            raise ValueError("psutil PID/create_time changed during dual-source metadata lookup")
        if any(value != "" for value in (name_before, name_middle, name_after, name_confirm)):
            raise ValueError("psutil empty-name state changed during CIM fallback")
        disposition = "classified_by_exact_raw_handle_and_dual_source_windows_generation"

    record = {
        "pid": pid,
        "psutil_create_time": created_before,
        "psutil_name_before": name_before,
        "psutil_name_middle": name_middle,
        "psutil_name_after": name_after,
        "psutil_create_time_confirm": created_confirm,
        "psutil_name_confirm": name_confirm,
        "cim_snapshots": [cim_first, cim_second],
        "tasklist_snapshots": [task_first, task_second],
        "generation_identity": {
            "pid": pid,
            "creation_date_token": cim_first["creation_date_token"],
            "creation_filetime_ticks": cim_first["creation_filetime_ticks"],
            "binding": "exact repeated local Win32_Process CreationDate token and FILETIME ticks; no psutil float tolerance",
        },
        "sources_agree": True,
        "raw_process_handle_generation": (
            {"pid": raw_before[0], "creation_filetime_ticks": raw_before[1],
             "before_after_and_both_cim_exact": True}
            if not system_pid4 else None
        ),
        "disposition": disposition,
        "signal_allowed": False if system_pid4 else None,
        "trust_boundary": "local OS metadata; repeated provider agreement is not a cryptographic signature",
    }
    return cim_first["name"], record


def _validated_raw_process_filetime(pid: int, reader: Callable[[int], tuple[int, int]]) -> tuple[int, int]:
    value = reader(pid)
    if type(value) is not tuple or len(value) != 2:
        raise ValueError("raw process-handle identity must be a native two-item tuple")
    observed_pid, ticks = value
    if type(observed_pid) is not int or observed_pid <= 0 or observed_pid != pid:
        raise ValueError("raw process-handle PID differs from requested process")
    if type(ticks) is not int or ticks <= 0:
        raise ValueError("raw process-handle creation FILETIME ticks must be a positive native integer")
    return observed_pid, ticks


def _same_raw_process_filetime(left: Any, right: Any) -> bool:
    """Validate both raw process identities before exact integer equality."""
    if type(left) is not tuple or len(left) != 2 or type(right) is not tuple or len(right) != 2:
        raise ValueError("raw process-handle identity pair is malformed")
    for pid, ticks in (left, right):
        if type(pid) is not int or pid <= 0 or type(ticks) is not int or ticks <= 0:
            raise ValueError("raw process-handle identity contains malformed native integers")
    return left == right


def scan_heavy_processes(
    process_iter: Callable[[], Iterable[Any]] | None = None,
    *,
    cim_reader: Callable[[int], Any] | None = None,
    tasklist_reader: Callable[[int], Any] | None = None,
    filetime_reader: Callable[[int], tuple[int, int]] | None = None,
) -> dict[str, Any]:
    """Enumerate global heavy-process names with strict system-row classification."""
    errors: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    excluded_processes: list[dict[str, Any]] = []
    resolved_processes: list[dict[str, Any]] = []
    if process_iter is None:
        if psutil is None:
            return {"complete": False, "processes": [], "excluded_processes": [],
                    "resolved_processes": [],
                    "errors": [{"phase": "global_process_enumeration",
                                "reason": "psutil_unavailable"}]}
        process_iter = lambda: psutil.process_iter()  # type: ignore[union-attr]
    try:
        processes = list(process_iter())
    except Exception as exc:
        return {"complete": False, "processes": [], "excluded_processes": [],
                "resolved_processes": [],
                "errors": [_error("global_process_enumeration", exc)]}
    seen_pids: set[int] = set()
    idle_sentinel_seen = False
    for process in processes:
        try:
            pid = getattr(process, "pid", None)
        except Exception as exc:
            errors.append(_error("global_process_pid_read", exc))
            continue
        if type(pid) is int and pid == WINDOWS_IDLE_PID:
            try:
                if idle_sentinel_seen:
                    raise ValueError("duplicate Windows idle sentinel in global inventory")
                excluded_processes.append(_windows_idle_sentinel_record(process))
                idle_sentinel_seen = True
            except Exception as exc:
                errors.append(_error("windows_idle_sentinel_validation", exc, pid=pid))
            continue
        if type(pid) is int and pid == 4:
            try:
                if pid in seen_pids:
                    raise ValueError("duplicate PID 4 in global process inventory")
                seen_pids.add(pid)
                _name, metadata = _stable_windows_process_metadata(
                    process, pid, cim_reader=cim_reader,
                    tasklist_reader=tasklist_reader, system_pid4=True,
                )
                excluded_processes.append(metadata)
            except Exception as exc:
                errors.append(_error("windows_system_pid4_validation", exc, pid=pid))
            continue
        operation = "psutil_create_time_before_name"
        try:
            before = _identity(pid, process.create_time())
            if before[0] in seen_pids:
                raise ValueError("duplicate PID in global process inventory")
            seen_pids.add(before[0])
            operation = "psutil_name_read"
            name = process.name()
            if type(name) is not str:
                raise ValueError("global process name is unavailable or malformed")
            operation = "psutil_create_time_after_name"
            after_name = _identity(getattr(process, "pid", None), process.create_time())
            if not _same_identity(after_name, before):
                raise ValueError("global process identity changed while reading name")
            if name == "":
                operation = "dual_source_empty_name_resolution"
                name, metadata = _stable_windows_process_metadata(
                    process, before[0], cim_reader=cim_reader,
                    tasklist_reader=tasklist_reader, filetime_reader=filetime_reader,
                    system_pid4=False,
                )
                resolved_processes.append(metadata)
                operation = "psutil_post_corroboration_name_read"
                confirmed_name = process.name()
                operation = "psutil_post_corroboration_identity_read"
                after_name = _identity(getattr(process, "pid", None), process.create_time())
                if not _same_identity(after_name, before) or confirmed_name != "":
                    raise ValueError("psutil identity or empty-name state changed after corroboration")
            if name == WINDOWS_IDLE_NAME or (name == "System" and before[0] != 4):
                raise ValueError("Windows system sentinel name appears on an unexpected PID")
            normalized_name = name.lower()
            if normalized_name not in HEAVY_NAMES:
                continue
            operation = "heavy_raw_filetime_before_resources"
            raw_reader = filetime_reader or _windows_pid_handle_identity
            raw_before = _validated_raw_process_filetime(before[0], raw_reader)
            operation = "heavy_rss_read"
            rss_bytes = _rss(process.memory_info().rss)
            operation = "heavy_cpu_read"
            cpu = process.cpu_times()
            user_seconds = _cpu_seconds(cpu.user, "cpu user seconds")
            system_seconds = _cpu_seconds(cpu.system, "cpu system seconds")
            operation = "heavy_command_line_read"
            command = process.cmdline()
            if not isinstance(command, (list, tuple)) or any(not isinstance(x, str) for x in command):
                raise ValueError("heavy process command line is unavailable")
            operation = "heavy_psutil_identity_after_resources"
            after_resources = _identity(getattr(process, "pid", None), process.create_time())
            if not _same_identity(after_resources, before):
                raise ValueError("global process identity changed while reading resources")
            operation = "heavy_raw_filetime_after_resources"
            raw_after = _validated_raw_process_filetime(before[0], raw_reader)
            if not _same_raw_process_filetime(raw_before, raw_after):
                raise ValueError("heavy process raw handle FILETIME generation changed during resource reads")
            rows.append({
                "pid": before[0], "create_time": before[1], "name": name,
                "cmdline": list(command), "rss_bytes": rss_bytes,
                "cpu_user_seconds": user_seconds,
                "cpu_system_seconds": system_seconds,
                "raw_handle_generation_filetime_ticks": raw_before[1],
            })
        except Exception as exc:
            # An unreadable process could be a heavy residual; never silently drop it.
            errors.append(_error("global_process_classification_or_measurement", exc, pid=pid) |
                          {"operation": operation})
    rows.sort(key=lambda item: (item["pid"], item["create_time"]))
    return {"complete": not errors, "sampled_utc": utc_now(),
            "processes": rows, "excluded_processes": excluded_processes,
            "resolved_processes": resolved_processes,
            "errors": errors}


def verify_frozen_inputs(protocol: dict[str, Any]) -> list[str]:
    """Verify immutable R16/R18/R20 ancestors and unchanged runtime thresholds."""
    errors: list[str] = []
    if protocol.get("r20_runtime_failure_context") != R20_RUNTIME_FAILURE_CONTEXT:
        errors.append("r20_runtime_failure_context_changed_or_malformed")
    if protocol.get("runtime_dispatch_status") != R22_RUNTIME_DISPATCH_STATUS:
        errors.append("r22_runtime_dispatch_status_changed_or_malformed")
    if protocol.get("r21_independent_review_context") != R21_INDEPENDENT_REVIEW_CONTEXT:
        errors.append("r21_independent_review_context_changed_or_malformed")
    if protocol.get("r21_lineage_pins") != R21_LINEAGE_PINS:
        errors.append("r21_lineage_pin_inventory_mismatch")
    for item in R21_LINEAGE_PINS:
        path = ROOT / item["path"]
        try:
            observed = sha256_file(path)
        except Exception as exc:
            errors.append(f"{item['role']}_unreadable:{type(exc).__name__}:{exc}")
            continue
        if observed != item["sha256"]:
            errors.append(f"{item['role']}_sha256_mismatch:{observed}")
    for item in R20_RUNTIME_FAILURE_PINS:
        path = ROOT / item["path"]
        try:
            if sha256_file(path) != item["sha256"]:
                errors.append(f"{item['role']}_sha256_mismatch")
        except Exception as exc:
            errors.append(f"{item['role']}_unreadable:{type(exc).__name__}:{exc}")
    expected = {
        "r16_parent_protocol": (R16_PARENT_PROTOCOL, R16_PARENT_PROTOCOL_SHA256),
        "r16_runner": (R16_RUNNER, R16_RUNNER_SHA256),
        "r16_reporter": (R16_RESOURCE_REPORTER, R16_RESOURCE_REPORTER_SHA256),
        "r18_parent_protocol": (R18_PARENT_PROTOCOL, R18_PARENT_PROTOCOL_SHA256),
        "r18_reporter": (R18_REPORTER, R18_REPORTER_SHA256),
        "r18_test": (R18_TEST, R18_TEST_SHA256),
    }
    for label, (path, digest) in expected.items():
        try:
            observed = sha256_file(path)
        except Exception as exc:
            errors.append(f"{label}_unreadable:{type(exc).__name__}:{exc}")
            continue
        if observed != digest:
            errors.append(f"{label}_sha256_mismatch:{observed}")
    expected_parent_pins = [
        {"role": label, "path": path.relative_to(ROOT).as_posix(), "sha256": digest}
        for label, (path, digest) in expected.items()
    ]
    if protocol.get("frozen_parent_pins") != expected_parent_pins:
        errors.append("frozen_parent_pin_inventory_mismatch")
    expected_owned = {
        "supervisor": TEST_DIR / "supervise_r16_root_audit_r22_v1.py",
        "python_tests": TEST_DIR / "test_r16_root_audit_r22_v1.py",
    }
    frozen_files = protocol.get("frozen_files")
    if not isinstance(frozen_files, list):
        errors.append("r22_frozen_file_pins_missing")
        frozen_files = []
    observed_roles = {item.get("role"): item for item in frozen_files if isinstance(item, dict)}
    if set(observed_roles) != set(expected_owned):
        errors.append("r22_frozen_file_roles_mismatch")
    for role, path in expected_owned.items():
        record = observed_roles.get(role)
        if not isinstance(record, dict) or record.get("path") != path.relative_to(ROOT).as_posix():
            errors.append(f"r22_{role}_path_pin_mismatch")
            continue
        try:
            digest = sha256_file(path)
            byte_count = path.stat().st_size
        except Exception as exc:
            errors.append(f"r22_{role}_unreadable:{type(exc).__name__}:{exc}")
            continue
        if record.get("sha256") != digest or record.get("bytes") != byte_count:
            errors.append(f"r22_{role}_sha256_or_size_mismatch:{digest}:{byte_count}")
    if protocol.get("schema") != "native-g1g2-r22-root-supervisor-protocol-v1":
        errors.append("r22_protocol_schema_mismatch")
    if protocol.get("identity_type_contract") != IDENTITY_TYPE_CONTRACT:
        errors.append("identity_type_contract_changed_or_malformed")
    if protocol.get("windows_idle_inventory_rule") != WINDOWS_IDLE_INVENTORY_RULE:
        errors.append("windows_idle_inventory_rule_changed_or_malformed")
    if protocol.get("windows_system_row_rule") != WINDOWS_SYSTEM_ROW_RULE:
        errors.append("windows_system_row_rule_changed_or_malformed")
    if protocol.get("windows_process_source_contract") != WINDOWS_PROCESS_SOURCE_CONTRACT:
        errors.append("windows_process_source_contract_changed_or_malformed")
    limits = protocol.get("r16_limits")
    if limits != {
        "stage_order": list(STAGE_ORDER),
        "wall_seconds_per_stage": STAGE_WALL_SECONDS,
        "sampled_rss_stop_threshold_bytes": RSS_THRESHOLD_BYTES,
        "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
        "julia_threads": 1,
        "blas_threads": 1,
        "julia_heap_size_hint": HEAP_HINT,
        "compiler_mode": COMPILER_MODE,
    }:
        errors.append("r16_limits_changed_or_malformed")
    if protocol.get("claim_ceiling") != {
        "numerical_status": "not_established",
        "physical_status": "unknown",
        "solver_success_claimed": False,
        "numerical_credit_before_outer_audit": False,
        "numerical_credit_on_monitor_incomplete": False,
    }:
        errors.append("claim_ceiling_changed_or_malformed")
    if protocol.get("receipt_policy") != {
        "schema": "root_owned_write_once_run_receipt_v1",
        "write_once": True,
        "cryptographic_signature": False,
        "authenticate_by": "root-owned child launch and measured provenance",
        "binds_actual_outer_supervisor_argv": True,
        "binds_r16_runner_protocol_summary_stage_raw_and_artifact_hashes": True,
        "binds_r18_reporter_path_sha256": True,
        "binds_report_output_to_outer_receipt_via_write_once_followup": True,
    }:
        errors.append("receipt_policy_changed_or_malformed")
    dispatch = protocol.get("dispatch")
    if not isinstance(dispatch, dict):
        errors.append("dispatch_pin_missing_or_malformed")
    else:
        try:
            parent = _read_json(R16_PARENT_PROTOCOL)
            parent_plan = parent["execution_plan"]
            julia_record = parent_plan["julia_executable"]
            output_leaf = dispatch.get("output_leaf")
            if not isinstance(output_leaf, str) or not output_leaf or Path(output_leaf).name != output_leaf:
                raise ValueError("output leaf pin is malformed")
            if dispatch.get("julia_executable") != julia_record.get("path") or \
                    dispatch.get("julia_executable_sha256") != julia_record.get("sha256") or \
                    dispatch.get("julia_executable_bytes") != julia_record.get("bytes"):
                errors.append("dispatch_julia_pin_differs_from_r16_parent")
            if dispatch.get("python_executable") != str(Path(sys.executable).resolve()):
                errors.append("dispatch_python_path_differs_from_current_interpreter")
            python_path = Path(sys.executable).resolve()
            if dispatch.get("python_executable_sha256") != sha256_file(python_path) or \
                    dispatch.get("python_executable_bytes") != python_path.stat().st_size:
                errors.append("dispatch_python_binary_pin_mismatch")
            script_path = str(Path(__file__).resolve())
            frozen_static = [
                str(Path(sys.executable).resolve()), "-B", script_path,
                "--static-only", "--output", output_leaf,
            ]
            frozen_actual = [
                str(Path(sys.executable).resolve()), "-B", script_path,
                "--output", output_leaf, "--dispatch-actual", ACTUAL_DISPATCH_TOKEN,
            ]
            child_argv = _expected_runner_argv(output_leaf, dispatch.get("julia_executable"))
            parent_child = list(parent_plan["expected_runtime_supervisor_argv"])
            output_pos = parent_child.index("--output") + 1
            parent_child[output_pos] = output_leaf
            if child_argv != parent_child:
                errors.append("dispatch_child_argv_differs_from_r16_parent_except_output")
            if dispatch.get("static_argv") != frozen_static:
                errors.append("dispatch_static_argv_pin_mismatch")
            if dispatch.get("runtime_argv") != frozen_actual:
                errors.append("dispatch_runtime_argv_pin_mismatch")
        except Exception as exc:
            errors.append(f"dispatch_parent_argv_pin_invalid:{type(exc).__name__}:{exc}")
    if protocol.get("monitoring_contract") != {
        "rss_semantics": "sampled_stop_trigger_not_instantaneous_hard_cap",
        "rss_threshold_bytes": RSS_THRESHOLD_BYTES,
        "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
        "threshold_hit_or_overshoot_disposition": "resource_failure",
        "popen_generation_binding": "exact_raw_filetime_ticks_from_original_and_fresh_pid_handles_before_after_psutil",
        "filetime_ticks_per_second": FILETIME_TICKS_PER_SECOND,
        "psutil_float_create_time_semantics": "diagnostic_only; exact raw handle FILETIME ticks decide generation",
        "stage_wall_seconds": STAGE_WALL_SECONDS,
        "stage_order": list(STAGE_ORDER),
        "compiler_mode": COMPILER_MODE,
        "heap_hint": HEAP_HINT,
        "incomplete_observation_disposition": "resource_monitor_incomplete_no_numerical_credit",
        "windows_idle_inventory_rule": WINDOWS_IDLE_INVENTORY_RULE,
        "windows_system_row_rule": WINDOWS_SYSTEM_ROW_RULE,
        "windows_process_source_contract": WINDOWS_PROCESS_SOURCE_CONTRACT,
    }:
        errors.append("monitoring_contract_changed_or_malformed")
    return errors


def _read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object at {path}")
    return value


def _output_leaf(name: str) -> Path:
    if not name or Path(name).name != name or name in {".", ".."} or "/" in name or "\\" in name:
        raise ValueError("output must be one new leaf name")
    leaf = (ARCHIVE_ROOT / name).resolve()
    leaf.relative_to(ARCHIVE_ROOT)
    if leaf.exists():
        raise FileExistsError(f"refusing to overwrite existing R16 output leaf: {leaf}")
    return leaf


def _expected_runner_argv(output_name: str, julia_path: str) -> list[str]:
    parent = _read_json(R16_PARENT_PROTOCOL)
    plan = parent.get("execution_plan", {})
    expected = plan.get("expected_runtime_supervisor_argv")
    if not isinstance(expected, list) or any(not isinstance(token, str) for token in expected):
        raise ValueError("R16 frozen runtime argv is missing or malformed")
    parent_julia = plan.get("julia_executable", {}).get("path")
    if not isinstance(parent_julia, str) or str(Path(julia_path).resolve()) != parent_julia:
        raise ValueError("requested Julia executable differs from exact R16 parent path")
    command = list(expected)
    positions = [index for index, token in enumerate(command) if token == "--output"]
    julia_positions = [index for index, token in enumerate(command) if token == "--julia"]
    if len(positions) != 1 or positions[0] + 1 >= len(command):
        raise ValueError("R16 frozen argv must contain exactly one --output value")
    if len(julia_positions) != 1 or julia_positions[0] + 1 >= len(command):
        raise ValueError("R16 frozen argv must contain exactly one --julia value")
    command[positions[0] + 1] = output_name
    return command


def _current_invocation_argv() -> list[str]:
    original = getattr(sys, "orig_argv", None)
    if isinstance(original, list) and original and all(isinstance(x, str) for x in original):
        return list(original)
    return [sys.executable, *sys.argv]


def _normalize_invocation_argv(argv: list[str]) -> list[str]:
    result = list(argv)
    for index in (0, 2):
        if index < len(result):
            result[index] = str(Path(result[index]).resolve()).casefold()
    return result


def _validate_invocation(protocol: dict[str, Any], mode: str, observed: list[str]) -> list[str]:
    expected = protocol.get("dispatch", {}).get(f"{mode}_argv")
    if not isinstance(expected, list) or any(not isinstance(token, str) for token in expected):
        return [f"{mode}_argv_pin_missing_or_malformed"]
    if _normalize_invocation_argv(expected) != _normalize_invocation_argv(observed):
        return [f"{mode}_argv_differs_from_frozen_invocation"]
    return []


def _runtime_dispatch_block_reason(protocol: dict[str, Any]) -> str | None:
    """Keep this host-specific R22 candidate static-only after observed inventory gaps."""
    if protocol.get("runtime_dispatch_status") != R22_RUNTIME_DISPATCH_STATUS:
        return "r22_runtime_dispatch_status_changed_or_malformed"
    if R22_RUNTIME_DISPATCH_STATUS["eligible"] is not True:
        return R22_RUNTIME_DISPATCH_STATUS["reason"]
    return None


def _validate_r16_run_protocol(
    run_protocol: dict[str, Any], child_argv: list[str], leaf: Path
) -> tuple[dict[str, list[str]], list[str]]:
    failures: list[str] = []
    plan = run_protocol.get("execution_plan")
    if run_protocol.get("schema") != "native-g1g2-gridap-recorded-protocol-r16-v1":
        failures.append("r16_actual_protocol_schema_mismatch")
        plan = {}
    if run_protocol.get("run_mode") != "actual" or not isinstance(plan, dict) or \
            plan.get("runtime_executed") is not True:
        failures.append("r16_protocol_not_actual_runtime")
    if isinstance(plan, dict):
        if plan.get("runner_invocation_argv") != child_argv:
            failures.append("r16_runner_argv_differs_from_root_child_launch")
        if plan.get("expected_runtime_supervisor_argv") != child_argv:
            failures.append("r16_expected_runtime_argv_mismatch")
        if plan.get("planned_actual_output") != str(leaf):
            failures.append("r16_actual_output_path_mismatch")
    stage_commands = plan.get("stage_commands") if isinstance(plan, dict) else None
    expected_stages: dict[str, list[str]] = {}
    if not isinstance(stage_commands, list) or len(stage_commands) != len(STAGE_ORDER):
        failures.append("r16_stage_command_count_mismatch")
    else:
        for index, item in enumerate(stage_commands):
            if not isinstance(item, dict) or item.get("stage") != STAGE_ORDER[index] or \
                    not isinstance(item.get("argv"), list) or \
                    any(not isinstance(arg, str) for arg in item.get("argv", [])):
                failures.append(f"r16_stage_command_{index + 1}_malformed")
                continue
            expected_stages[STAGE_ORDER[index]] = item["argv"]
    return expected_stages, failures


def _stage_paths(leaf: Path, index: int, name: str) -> tuple[Path, Path, Path]:
    stage = leaf / f"{index:02d}_{name}"
    return stage, stage / "start.json", stage / "final.json"


def _parse_time(value: Any) -> float:
    if not isinstance(value, str):
        raise ValueError("stage timestamp missing")
    text = value[:-1] + "+00:00" if value.endswith("Z") else value
    result = datetime.fromisoformat(text).timestamp()
    if not math.isfinite(result):
        raise ValueError("stage timestamp is non-finite")
    return result


def _wall_elapsed(started_utc: str, now_utc: str) -> float:
    return _parse_time(now_utc) - _parse_time(started_utc)


def _active_known_stage_identities(leaf: Path) -> set[tuple[int, float]]:
    active: set[tuple[int, float]] = set()
    for index, name in enumerate(STAGE_ORDER, start=1):
        _, start_path, final_path = _stage_paths(leaf, index, name)
        if not start_path.is_file() or final_path.is_file():
            continue
        start = _read_json(start_path)
        active.add(_identity(start.get("pid"), start.get("process_create_time")))
    return active


def _residual_heavy_rows(
    scan: dict[str, Any], leaf: Path, *, stage_identity: tuple[int, float] | None = None
) -> list[dict[str, Any]]:
    try:
        active = _active_known_stage_identities(leaf)
    except Exception as exc:
        return [{"identity_malformed": True, "reason": f"active_stage_identity_invalid:{type(exc).__name__}:{exc}"}]
    if stage_identity is not None:
        active.discard(_identity_pair(stage_identity))
    rows = scan.get("processes")
    if not isinstance(rows, list):
        return [{"identity_malformed": True, "reason": "heavy_process_rows_missing_or_malformed"}]
    residual: list[dict[str, Any]] = []
    for row in rows:
        try:
            identity = _identity_from_mapping(row)
        except Exception as exc:
            residual.append({"identity_malformed": True,
                             "reason": f"heavy_process_identity_invalid:{type(exc).__name__}:{exc}",
                             "observed_repr": repr(row)})
            continue
        if identity not in active:
            residual.append(row)
    return residual


def _stage_window_audit(
    leaf: Path,
    samples: list[dict[str, Any]],
    handles: dict[tuple[int, float], Any],
    expected_commands: dict[str, list[str]],
    pre_scans: dict[str, dict[str, Any]],
    post_scans: dict[str, dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[str], list[dict[str, Any]]]:
    audits: list[dict[str, Any]] = []
    root_receipts: list[dict[str, Any]] = []
    aggregate_descendants: list[dict[str, Any]] = []
    failures: list[str] = []
    scan_rows: list[dict[str, Any]] = []
    for index, name in enumerate(STAGE_ORDER, start=1):
        stage, start_path, final_path = _stage_paths(leaf, index, name)
        pre = pre_scans.get(name)
        post = post_scans.get(name)
        start: dict[str, Any] | None = None
        final: dict[str, Any] | None = None
        try:
            if not start_path.is_file() or not final_path.is_file():
                raise FileNotFoundError("stage start/final receipt missing")
            start = _read_json(start_path)
            final = _read_json(final_path)
            identity = _identity(start.get("pid"), start.get("process_create_time"))
            final_identity = _identity(final.get("root_pid"), final.get("root_process_create_time"))
            if not _same_identity(identity, final_identity):
                raise ValueError("stage start/final root identity mismatch")
            if start.get("command") != expected_commands.get(name) or \
                    final.get("command") != expected_commands.get(name):
                raise ValueError("stage command differs from R16 frozen plan")
            start_time = _parse_time(start.get("started_utc"))
            end_time = _parse_time(final.get("ended_utc"))
            if end_time < start_time:
                raise ValueError("stage ended before it started")
        except Exception as exc:
            failures.append(f"stage_{index}_boundary_invalid:{type(exc).__name__}:{exc}")
            identity = None
            start_time = end_time = 0.0

        pre_complete = isinstance(pre, dict) and pre.get("complete") is True
        post_complete = isinstance(post, dict) and post.get("complete") is True
        if not pre_complete:
            failures.append(f"stage_{index}_pre_inventory_incomplete")
        if not post_complete:
            failures.append(f"stage_{index}_post_inventory_incomplete")
        if identity is not None and start_time > 0:
            try:
                if _parse_time((pre or {}).get("sampled_utc")) > start_time:
                    failures.append(f"stage_{index}_pre_scan_not_before_stage_start")
            except Exception:
                failures.append(f"stage_{index}_pre_scan_timestamp_invalid")
            try:
                if _parse_time((post or {}).get("sampled_utc")) < end_time:
                    failures.append(f"stage_{index}_post_scan_not_after_stage_end")
            except Exception:
                failures.append(f"stage_{index}_post_scan_timestamp_invalid")
        pre_residual = _residual_heavy_rows(pre or {"processes": []}, leaf) if pre_complete else []
        post_residual = _residual_heavy_rows(
            post or {"processes": []}, leaf, stage_identity=identity
        ) if post_complete else []
        if pre_residual:
            failures.append(f"stage_{index}_pre_residual_heavy_processes_present")
        if post_residual:
            failures.append(f"stage_{index}_post_residual_heavy_processes_present")

        external_seen: set[tuple[int, float]] = set()
        stage_samples: list[dict[str, Any]] = []
        external_peak = 0
        peak_sample: dict[str, Any] | None = None
        if identity is not None:
            for sample in samples:
                try:
                    sample_time = _parse_time(sample.get("utc"))
                except Exception:
                    failures.append(f"stage_{index}_outer_sample_timestamp_invalid")
                    continue
                if start_time <= sample_time <= end_time:
                    if sample.get("complete") is not True:
                        failures.append(f"stage_{index}_in_window_sample_incomplete")
                        continue
                    try:
                        members = _stage_descendants_in_sample(
                            sample.get("processes", []), identity
                        )
                    except Exception as exc:
                        failures.append(
                            f"stage_{index}_outer_process_tree_graph_invalid:{type(exc).__name__}"
                        )
                        continue
                    if identity in members:
                        external_seen.update(members)
                        stage_samples.append(sample)
                        rss_total = sum(
                            _rss(row.get("rss_bytes")) for row in sample["processes"]
                            if (row.get("pid"), row.get("create_time")) in members
                        )
                        if rss_total > external_peak:
                            external_peak = rss_total
                            peak_sample = sample
            if identity not in external_seen:
                failures.append(f"stage_{index}_root_not_observed_by_external_sampler")

        inner_seen: set[tuple[int, float]] = set()
        inner_sample_path = stage / "samples.jsonl"
        if not inner_sample_path.is_file():
            failures.append(f"stage_{index}_inner_sample_file_missing")
        else:
            try:
                for line_number, raw_line in enumerate(
                        inner_sample_path.read_text(encoding="utf-8").splitlines(), start=1):
                    if not raw_line.strip():
                        continue
                    inner_sample = json.loads(raw_line)
                    member_rows = inner_sample.get("process_tree_processes")
                    if not isinstance(member_rows, list):
                        failures.append(f"stage_{index}_inner_sample_{line_number}_rows_missing")
                        continue
                    for item in member_rows:
                        try:
                            inner_seen.add(_identity(item.get("pid"), item.get("create_time")))
                        except Exception:
                            failures.append(f"stage_{index}_inner_sample_{line_number}_identity_malformed")
            except Exception as exc:
                failures.append(f"stage_{index}_inner_samples_unreadable:{type(exc).__name__}:{exc}")
        if isinstance(final, dict) and identity is not None:
            final_identity = _identity(final.get("root_pid"), final.get("root_process_create_time"))
            if not _same_identity(final_identity, identity):
                failures.append(f"stage_{index}_inner_final_root_identity_mismatch")
        if not inner_seen.issubset(external_seen):
            failures.append(f"stage_{index}_inner_observation_not_externally_confirmed")
        if identity is not None and identity not in inner_seen:
            failures.append(f"stage_{index}_inner_root_identity_missing")

        stage_exit_receipts: list[dict[str, Any]] = []
        if identity is not None:
            stage_exit_receipts, wait_errors = process_exit_receipts(
                handles, [item for item in external_seen if not _same_identity(item, identity)]
            )
            if wait_errors:
                failures.append(f"stage_{index}_descendant_wait_incomplete")
            stage_root_exit, root_wait_errors = process_exit_receipts(handles, [identity])
            if root_wait_errors or len(stage_root_exit) != 1:
                failures.append(f"stage_{index}_root_wait_incomplete")
                root_code = None
            else:
                root_code = stage_root_exit[0]["exit_code"]
                root_receipts.append({
                    "index": index, "stage": name, "pid": identity[0],
                    "create_time": identity[1], "exit_code": root_code,
                    "exit_confirmed": True,
                })
            for row in stage_exit_receipts:
                aggregate_descendants.append({"index": index, "stage": name, **row})
        else:
            root_code = None

        if isinstance(final, dict) and root_code is not None and \
                final.get("exit_code") != root_code:
            failures.append(f"stage_{index}_outer_exit_code_differs_from_runner")
        expected_descendants = inner_seen - ({identity} if identity is not None else set())
        receipts_by_identity = {
            (item["pid"], item["create_time"]) for item in stage_exit_receipts
        }
        if not expected_descendants.issubset(receipts_by_identity):
            failures.append(f"stage_{index}_inner_descendant_exit_receipt_gap")

        audits.append({
            "index": index, "stage": name,
            "root_pid": identity[0] if identity else None,
            "root_process_create_time": identity[1] if identity else None,
            "root_exit_confirmed": root_code is not None,
            "root_exit_code": root_code,
            "pre_stage_inventory_complete": pre_complete,
            "post_stage_inventory_complete": post_complete,
            "pre_stage_residual_heavy_processes": pre_residual,
            "post_stage_residual_heavy_processes": post_residual,
            "pre_stage_heavy_inventory": (pre or {}).get("processes", []),
            "post_stage_heavy_inventory": (post or {}).get("processes", []),
            "outer_window_sample_count": len(stage_samples),
            "outer_window_peak_rss_bytes": external_peak,
            "outer_window_peak_sample_utc": peak_sample.get("utc") if peak_sample else None,
            "inner_identities": [
                {"pid": pid, "create_time": created}
                for pid, created in sorted(inner_seen)
            ],
            "tracked_descendant_exit_receipts": stage_exit_receipts,
        })
        scan_rows.append({
            "index": index, "stage": name,
            "pre_stage_inventory_complete": pre_complete,
            "post_stage_inventory_complete": post_complete,
            "pre_stage_scan": pre,
            "post_stage_scan": post,
        })
    return audits, root_receipts, aggregate_descendants, failures, scan_rows


def _runtime_file_receipts(leaf: Path) -> list[dict[str, Any]]:
    paths = [leaf / "protocol.json", leaf / "static_preflight.json",
             leaf / "parse_manifest.tsv", leaf / "prelaunch.exit.txt", leaf / "summary.json",
             leaf / "root_supervised_runner.stdout.raw",
             leaf / "root_supervised_runner.stderr.raw"]
    for index, name in enumerate(STAGE_ORDER, start=1):
        stage, start_path, final_path = _stage_paths(leaf, index, name)
        paths.extend([start_path, final_path, stage / "samples.jsonl",
                      stage / "stdout.raw", stage / "stderr.raw"])
    for path in sorted(leaf.rglob("*")):
        if path.is_file() and path.name.startswith("primary"):
            paths.append(path)
    unique = list(dict.fromkeys(paths))
    records = []
    for path in unique:
        if not path.is_file():
            continue
        records.append({
            "path": path.relative_to(leaf).as_posix(),
            "bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        })
    return records


def validate_outer_samples(
    samples: list[dict[str, Any]], root_identity: tuple[int, float] | None,
    expected_root_creation_filetime_ticks: int | None = None,
) -> list[str]:
    """Check each externally collected complete tree sample against its root."""
    failures: list[str] = []
    if root_identity is None or not samples:
        return ["outer_samples_missing_or_root_identity_missing"]
    try:
        root_identity = _identity_pair(root_identity)
    except Exception:
        return ["outer_samples_root_identity_malformed"]
    if expected_root_creation_filetime_ticks is not None and \
            (type(expected_root_creation_filetime_ticks) is not int or
             expected_root_creation_filetime_ticks <= 0):
        failures.append("outer_samples_expected_root_filetime_malformed")
        expected_root_creation_filetime_ticks = None
    for index, sample in enumerate(samples, start=1):
        if not isinstance(sample, dict):
            failures.append(f"outer_sample_{index}_record_malformed")
            continue
        if sample.get("complete") is not True:
            failures.append(f"outer_sample_{index}_incomplete")
        try:
            sample_root_identity = _identity(sample.get("root_pid"), sample.get("root_create_time"))
        except Exception:
            sample_root_identity = None
        root_row_count = sample.get("root_row_count")
        if (sample_root_identity is None or
                not _same_identity(sample_root_identity, root_identity) or
                type(root_row_count) is not int or root_row_count != 1):
            failures.append(f"outer_sample_{index}_root_identity_mismatch")
        if expected_root_creation_filetime_ticks is not None:
            expected_generation = {
                "pid": root_identity[0],
                "creation_filetime_ticks": expected_root_creation_filetime_ticks,
            }
            before = sample.get("root_generation_guard_before")
            after = sample.get("root_generation_guard_after")
            raw_guards_valid = all(
                isinstance(value, dict) and
                type(value.get("pid")) is int and value.get("pid") > 0 and
                type(value.get("creation_filetime_ticks")) is int and
                value.get("creation_filetime_ticks") > 0
                for value in (before, after)
            )
            if sample.get("root_generation_guard_required") is not True or \
                    sample.get("root_generation_guard_complete") is not True or \
                    type(sample.get("root_creation_filetime_ticks")) is not int or \
                    sample.get("root_creation_filetime_ticks") != expected_root_creation_filetime_ticks or \
                    not raw_guards_valid or before != expected_generation or after != expected_generation:
                failures.append(f"outer_sample_{index}_exact_root_generation_guard_incomplete")
        rows = sample.get("processes")
        if not isinstance(rows, list) or not rows:
            failures.append(f"outer_sample_{index}_process_rows_missing")
            continue
        row_ids: list[tuple[int, float]] = []
        rss_sum = 0
        row_error = False
        for row in rows:
            try:
                ident = _identity(row.get("pid"), row.get("create_time"))
                rss_sum += _rss(row.get("rss_bytes"))
                _cpu_seconds(row.get("cpu_user_seconds"), "cpu user seconds")
                _cpu_seconds(row.get("cpu_system_seconds"), "cpu system seconds")
                if type(row.get("ppid")) is not int or row["ppid"] < 0:
                    raise ValueError("parent pid is malformed")
                if not isinstance(row.get("name"), str) or not row["name"]:
                    raise ValueError("process name is unavailable")
                if not isinstance(row.get("cmdline"), list) or any(
                        not isinstance(part, str) for part in row["cmdline"]):
                    raise ValueError("process command line is unavailable")
                row_ids.append(ident)
            except Exception:
                row_error = True
        if row_error:
            failures.append(f"outer_sample_{index}_malformed_process_row")
        if len(row_ids) != len(rows) or len({pid for pid, _ in row_ids}) != len(row_ids):
            failures.append(f"outer_sample_{index}_duplicate_or_missing_identity")
        if row_ids.count(root_identity) != 1:
            failures.append(f"outer_sample_{index}_root_process_row_not_unique")
        if type(sample.get("rss_bytes")) is not int or sample.get("rss_bytes") != rss_sum or \
                type(sample.get("partial_rss_bytes")) is not int or \
                sample.get("partial_rss_bytes") != rss_sum:
            failures.append(f"outer_sample_{index}_rss_total_mismatch")
        try:
            measured = _identity_mapping_rows(sample.get("measured_process_identities"))
        except Exception:
            measured = None
        if measured != row_ids:
            failures.append(f"outer_sample_{index}_measured_identity_rows_mismatch")
        try:
            discovered = _identity_mapping_rows(sample.get("discovered_process_identities"))
        except Exception:
            discovered = None
        if discovered != row_ids:
            failures.append(f"outer_sample_{index}_discovered_identity_rows_mismatch")
    return failures


def validate_popen_generation_for_control(
    popen: Any,
    expected_identity: Any,
    launch_identity_binding: Any,
    *,
    require_fresh_pid_handle: bool = True,
    handle_identity_reader: Callable[[Any], tuple[int, int]] | None = None,
    pid_handle_identity_reader: Callable[[int], tuple[int, int]] | None = None,
) -> list[str]:
    """Revalidate the owned Popen generation before control or wait operations."""
    failures: list[str] = []
    try:
        expected = _identity_pair(expected_identity)
    except Exception:
        return ["popen_control_expected_identity_malformed"]
    if not isinstance(launch_identity_binding, dict) or \
            launch_identity_binding.get("complete") is not True:
        failures.append("popen_control_launch_binding_incomplete")
        return failures
    expected_ticks = launch_identity_binding.get("popen_handle_creation_filetime_ticks")
    if type(expected_ticks) is not int or expected_ticks <= 0:
        failures.append("popen_control_expected_filetime_ticks_malformed")
        return failures
    pid = getattr(popen, "pid", None)
    if type(pid) is not int or pid <= 0:
        failures.append("popen_control_pid_malformed")
        return failures
    if pid != expected[0]:
        failures.append("popen_control_pid_differs_from_bound_root")
    original_reader = handle_identity_reader or _windows_popen_handle_identity
    try:
        original = original_reader(popen)
        if type(original) is not tuple or len(original) != 2 or \
                type(original[0]) is not int or original[0] <= 0 or \
                type(original[1]) is not int or original[1] <= 0:
            raise ValueError("original Popen handle returned malformed PID/FILETIME ticks")
        if original[0] != expected[0] or original[1] != expected_ticks:
            failures.append("popen_control_original_handle_generation_mismatch")
    except Exception as exc:
        failures.append(f"popen_control_original_handle_unreadable:{type(exc).__name__}:{exc}")
    if require_fresh_pid_handle:
        pid_reader = pid_handle_identity_reader or _windows_pid_handle_identity
        try:
            fresh = pid_reader(pid)
            if type(fresh) is not tuple or len(fresh) != 2 or \
                    type(fresh[0]) is not int or fresh[0] <= 0 or \
                    type(fresh[1]) is not int or fresh[1] <= 0:
                raise ValueError("fresh PID handle returned malformed PID/FILETIME ticks")
            if fresh[0] != expected[0] or fresh[1] != expected_ticks:
                failures.append("popen_control_fresh_handle_generation_mismatch")
        except Exception as exc:
            failures.append(f"popen_control_fresh_handle_unreadable:{type(exc).__name__}:{exc}")
    return failures


def kill_popen_if_bound(
    popen: Any,
    expected_identity: Any,
    launch_identity_binding: Any,
    *,
    handle_identity_reader: Callable[[Any], tuple[int, int]] | None = None,
    pid_handle_identity_reader: Callable[[int], tuple[int, int]] | None = None,
) -> dict[str, Any]:
    """Signal the root Popen only after exact current-generation revalidation."""
    failures = validate_popen_generation_for_control(
        popen, expected_identity, launch_identity_binding,
        require_fresh_pid_handle=True,
        handle_identity_reader=handle_identity_reader,
        pid_handle_identity_reader=pid_handle_identity_reader,
    )
    if failures:
        return {"signal_sent": False, "errors": failures}
    try:
        popen.kill()
    except Exception as exc:
        return {"signal_sent": False,
                "errors": [f"popen_control_kill_failed:{type(exc).__name__}:{exc}"]}
    return {"signal_sent": True, "errors": []}


def wait_popen_if_bound(
    popen: Any,
    expected_identity: Any,
    launch_identity_binding: Any,
    *,
    timeout_seconds: float,
    handle_identity_reader: Callable[[Any], tuple[int, int]] | None = None,
) -> tuple[int | None, list[str]]:
    """Wait only on the exact owned Popen generation and recheck its handle after."""
    errors = validate_popen_generation_for_control(
        popen, expected_identity, launch_identity_binding,
        require_fresh_pid_handle=False,
        handle_identity_reader=handle_identity_reader,
    )
    if errors:
        return None, errors
    try:
        code = popen.wait(timeout=timeout_seconds)
    except Exception as exc:
        return None, [f"popen_control_wait_failed:{type(exc).__name__}:{exc}"]
    if type(code) is not int:
        return None, ["popen_control_wait_returned_non_native_exit_code"]
    errors = validate_popen_generation_for_control(
        popen, expected_identity, launch_identity_binding,
        require_fresh_pid_handle=False,
        handle_identity_reader=handle_identity_reader,
    )
    return (code if not errors else None), errors


def build_outer_audit(
    *,
    leaf: Path,
    protocol: dict[str, Any],
    child_argv: list[str],
    root_identity: tuple[int, float] | None,
    runner_exit_code: int | None,
    runner_wait_confirmed: bool,
    pre_inventory: dict[str, Any],
    post_inventory: dict[str, Any],
    samples: list[dict[str, Any]],
    handles: dict[tuple[int, float], Any],
    pre_scans: dict[str, dict[str, Any]],
    post_scans: dict[str, dict[str, Any]],
    forced_failures: list[str],
    external_events: list[dict[str, Any]],
    termination_receipt: dict[str, Any] | None = None,
    tracked_process_exit_receipts: list[dict[str, Any]] | None = None,
    supervisor_invocation_argv: list[str] | None = None,
    launch_identity_binding: dict[str, Any] | None = None,
) -> tuple[dict[str, Any], list[str]]:
    expected_stages: dict[str, list[str]] = {}
    failures = list(forced_failures)
    try:
        run_protocol = _read_json(leaf / "protocol.json")
        expected_stages, protocol_failures = _validate_r16_run_protocol(
            run_protocol, child_argv, leaf
        )
        failures.extend(protocol_failures)
    except Exception as exc:
        run_protocol = {}
        failures.append(f"r16_actual_protocol_unreadable:{type(exc).__name__}:{exc}")
    required_run_files = [
        leaf / "protocol.json", leaf / "static_preflight.json",
        leaf / "parse_manifest.tsv", leaf / "prelaunch.exit.txt",
        leaf / "summary.json",
    ]
    for required_path in required_run_files:
        if not required_path.is_file():
            failures.append(f"r16_required_payload_missing:{required_path.name}")
    try:
        prelaunch_exit = (leaf / "prelaunch.exit.txt").read_text(encoding="ascii")
        if prelaunch_exit.strip() != "0":
            failures.append("r16_python_prelaunch_not_exit_zero")
        summary = _read_json(leaf / "summary.json")
        summary_stages = summary.get("stages")
        if summary.get("runtime_executed") is not True or not isinstance(summary_stages, list) or \
                [item.get("stage") for item in summary_stages if isinstance(item, dict)] != list(STAGE_ORDER):
            failures.append("r16_actual_summary_stage_or_runtime_mismatch")
        if summary.get("formal_t2_consumer_receipts_assigned") != 0 or \
                summary.get("physical_status") != "unknown":
            failures.append("r16_summary_claim_ceiling_mismatch")
    except Exception as exc:
        failures.append(f"r16_summary_or_prelaunch_unreadable:{type(exc).__name__}:{exc}")
    stage_audits, stage_roots, descendants, stage_failures, scan_rows = _stage_window_audit(
        leaf, samples, handles, expected_stages, pre_scans, post_scans
    )
    failures.extend(stage_failures)
    if root_identity is None:
        failures.append("supervised_runner_identity_unconfirmed")
    failures.extend(validate_popen_generation_binding(launch_identity_binding, root_identity))
    if runner_wait_confirmed is not True or type(runner_exit_code) is not int:
        failures.append("supervised_runner_wait_unconfirmed")
    failures.extend(verify_frozen_inputs(protocol))
    if pre_inventory.get("complete") is not True:
        failures.append("pre_run_residual_inventory_incomplete")
    if post_inventory.get("complete") is not True:
        failures.append("post_run_residual_inventory_incomplete")
    if pre_inventory.get("processes") != []:
        failures.append("pre_run_heavy_process_present")
    if post_inventory.get("processes") != []:
        failures.append("post_run_heavy_process_present")
    if reporter_sha256_or_none() != R18_REPORTER_SHA256:
        failures.append("r18_reporter_changed_during_root_supervision")
    if len(samples) == 0 or any(sample.get("complete") is not True for sample in samples):
        failures.append("outer_process_tree_sample_incomplete_or_missing")
    expected_root_ticks = (
        launch_identity_binding.get("popen_handle_creation_filetime_ticks")
        if isinstance(launch_identity_binding, dict) else None
    )
    failures.extend(validate_outer_samples(samples, root_identity, expected_root_ticks))
    if external_events:
        failures.append("outer_sampled_resource_or_wall_stop_triggered")

    sample_log = b"".join(json_bytes(sample) for sample in samples)
    scan_document = {
        "schema": "native-g1g2-r22-stage-residual-scans-v1",
        "pre_run_inventory": pre_inventory,
        "stages": scan_rows,
        "post_run_inventory": post_inventory,
    }
    sample_log_path = leaf / SAMPLE_LOG_FILENAME
    scan_log_path = leaf / SCAN_LOG_FILENAME
    try:
        sample_log_written = write_new(sample_log_path, sample_log)
        scan_doc_written = write_new(scan_log_path, scan_document)
    except Exception as exc:
        failures.append(f"outer_receipt_sidecar_write_failed:{type(exc).__name__}:{exc}")
        sample_log_written = b""
        scan_doc_written = b""

    identity_obj = (
        {"pid": root_identity[0], "create_time": root_identity[1]}
        if root_identity else None
    )
    reporter_sha = sha256_file(R18_REPORTER) if R18_REPORTER.is_file() else None
    wrapper_sha = sha256_file(Path(__file__).resolve())
    r22_protocol_sha = sha256_file(r22_PROTOCOL) if r22_PROTOCOL.is_file() else None
    run_receipts = _runtime_file_receipts(leaf)
    stage_count_ok = len(stage_audits) == len(STAGE_ORDER)
    complete = not failures and stage_count_ok
    audit = {
        "schema": "native-g1g2-root-outer-supervisor-residual-audit-v1",
        "audit_owner": "root_dispatch_controller",
        "audit_status": "pass" if complete else "incomplete",
        "run_mode": "actual",
        "runtime_executed": True,
        "run_root_pid_create_time": identity_obj,
        "pre_run_inventory_complete": pre_inventory.get("complete") is True,
        "post_run_inventory_complete": post_inventory.get("complete") is True,
        "post_run_heavy_process_inventory": post_inventory.get("processes", []),
        "supervised_runner": {
            **(identity_obj or {}),
            "exit_confirmed": runner_wait_confirmed is True,
            "exit_code": runner_exit_code,
        },
        "residual_scan_before_and_after_each_stage": len(scan_rows) == len(STAGE_ORDER),
        "residual_scan_completeness": {
            "pre_run_inventory_complete": pre_inventory.get("complete") is True,
            "post_run_inventory_complete": post_inventory.get("complete") is True,
            "stages": scan_rows,
        },
        "stage_root_exit_receipts": stage_roots,
        "tracked_descendant_exit_receipts": descendants,
        "stages": stage_audits,
        "root_owned_provenance": {
            "schema": "native-g1g2-r22-root-owned-run-provenance-v1",
            "wrapper_path": str(Path(__file__).resolve()),
            "wrapper_sha256": wrapper_sha,
            "protocol_path": str(r22_PROTOCOL.resolve()),
            "protocol_sha256": r22_protocol_sha,
            "parent_r16_protocol_path": str(R16_PARENT_PROTOCOL.resolve()),
            "parent_r16_protocol_sha256": R16_PARENT_PROTOCOL_SHA256,
            "r16_runner_path": str(R16_RUNNER.resolve()),
            "r16_runner_sha256": R16_RUNNER_SHA256,
            "r18_reporter_path": str(R18_REPORTER.resolve()),
            "r18_reporter_sha256": reporter_sha,
            "r18_reporter_output": "resource_report_r18.json",
            "r18_reporter_is_bound_before_receipt": reporter_sha == R18_REPORTER_SHA256,
            "supervisor_invocation_argv": supervisor_invocation_argv,
            "supervisor_invocation_argv_sha256": (
                sha256_bytes(json_bytes(supervisor_invocation_argv))
                if supervisor_invocation_argv is not None else None
            ),
            "popen_process_generation_binding": launch_identity_binding,
            "child_argv": child_argv,
            "child_argv_sha256": sha256_bytes(json_bytes(child_argv)),
            "runner_exit_code": runner_exit_code,
            "write_once": True,
            "authentication_semantics": "root-owned launch and measured receipt provenance; no cryptographic signature",
            "run_file_receipts": run_receipts,
            "tracked_process_exit_receipts": tracked_process_exit_receipts or [],
            "outer_sample_log": {
                "path": SAMPLE_LOG_FILENAME,
                "bytes": len(sample_log_written),
                "sha256": sha256_bytes(sample_log_written) if sample_log_written else None,
            },
            "stage_scan_log": {
                "path": SCAN_LOG_FILENAME,
                "bytes": len(scan_doc_written),
                "sha256": sha256_bytes(scan_doc_written) if scan_doc_written else None,
            },
            "external_stop_events": external_events,
            "termination_receipt": termination_receipt or {
                "attempted": False, "complete": True, "errors": []
            },
            "failure_reasons": sorted(set(failures)),
        },
        "claim_ceiling": {
            "solver_success_claimed": False,
            "numerical_credit_before_outer_audit": False,
            "numerical_credit_on_monitor_incomplete": False,
            "numerical_status": "not_established",
            "physical_status": "unknown",
        },
    }
    return audit, sorted(set(failures))


def _runner_protocol_path(leaf: Path) -> Path:
    return leaf / "protocol.json"


def _collect_markers(
    leaf: Path,
    pre_scans: dict[str, dict[str, Any]],
    post_scans: dict[str, dict[str, Any]],
    *,
    scan_global: Callable[[], dict[str, Any]],
) -> None:
    for index, name in enumerate(STAGE_ORDER, start=1):
        stage, start_path, final_path = _stage_paths(leaf, index, name)
        checkpoint = stage / "checkpoint_before_assert.json"
        if checkpoint.is_file() and name not in pre_scans:
            pre_scans[name] = scan_global()
            pre_scans[name].setdefault("sampled_utc", utc_now())
        if final_path.is_file() and name not in post_scans:
            post_scans[name] = scan_global()
            post_scans[name].setdefault("sampled_utc", utc_now())


def _current_stage_files(leaf: Path) -> list[tuple[int, str, dict[str, Any], dict[str, Any]]]:
    result = []
    for index, name in enumerate(STAGE_ORDER, start=1):
        _, start_path, final_path = _stage_paths(leaf, index, name)
        if not start_path.is_file() or final_path.is_file():
            continue
        try:
            start = _read_json(start_path)
            result.append((index, name, start, {}))
        except Exception:
            continue
    return result


def _stage_rss_at_sample(
    sample: dict[str, Any], stage_identity: tuple[int, float]
) -> int | None:
    try:
        members = _stage_descendants_in_sample(sample.get("processes", []), stage_identity)
        if stage_identity not in members:
            return None
        return sum(
            _rss(row.get("rss_bytes")) for row in sample["processes"]
            if (row.get("pid"), row.get("create_time")) in members
        )
    except Exception:
        return None


def _validate_static_command(julia_path: str, output_name: str) -> list[str]:
    errors: list[str] = []
    try:
        protocol = _read_json(r22_PROTOCOL)
    except Exception as exc:
        return [f"r22_protocol_unreadable:{type(exc).__name__}:{exc}"]
    errors.extend(verify_frozen_inputs(protocol))
    expected_python = protocol.get("dispatch", {}).get("python_executable")
    if expected_python and str(Path(sys.executable).resolve()).casefold() != \
            str(Path(expected_python).resolve()).casefold():
        errors.append("python_executable_differs_from_frozen_dispatch")
    expected_julia = protocol.get("dispatch", {}).get("julia_executable")
    if expected_julia and str(Path(julia_path).resolve()) != str(Path(expected_julia).resolve()):
        errors.append("julia_executable_differs_from_frozen_dispatch")
    try:
        julia_record = _read_json(R16_PARENT_PROTOCOL)["execution_plan"]["julia_executable"]
        julia_file = Path(julia_path).resolve()
        if not julia_file.is_file():
            errors.append("julia_executable_missing")
        else:
            if julia_file.stat().st_size != julia_record.get("bytes"):
                errors.append("julia_executable_size_differs_from_r16_parent")
            if sha256_file(julia_file) != julia_record.get("sha256"):
                errors.append("julia_executable_hash_differs_from_r16_parent")
    except Exception as exc:
        errors.append(f"julia_executable_pin_unreadable:{type(exc).__name__}:{exc}")
    expected_output = protocol.get("dispatch", {}).get("output_leaf")
    if output_name != expected_output:
        errors.append("output_leaf_differs_from_frozen_dispatch")
    return errors


def run_supervised_actual(
    output_name: str, julia_path: str, supervisor_invocation_argv: list[str]
) -> tuple[int, dict[str, Any] | None]:
    """Launch the exact R16 child and fail closed if any outer evidence is incomplete."""
    if psutil is None:
        raise RuntimeError("psutil is required for actual root supervision")
    static_errors = _validate_static_command(julia_path, output_name)
    if static_errors:
        raise RuntimeError("root supervisor prelaunch failed: " + ";".join(static_errors))
    protocol = _read_json(r22_PROTOCOL)
    leaf = _output_leaf(output_name)
    julia = str(Path(julia_path).resolve())
    child_argv = _expected_runner_argv(output_name, julia)
    try:
        baseline = scan_heavy_processes()
    except Exception as exc:
        baseline = {"complete": False, "processes": [],
                    "errors": [_error("pre_run_inventory", exc)]}
    if baseline.get("complete") is not True or baseline.get("processes") != []:
        raise RuntimeError("pre-run heavy process inventory not empty and complete")

    samples: list[dict[str, Any]] = []
    handles: dict[tuple[int, float], Any] = {}
    pre_scans: dict[str, dict[str, Any]] = {}
    post_scans: dict[str, dict[str, Any]] = {}
    forced_failures: list[str] = []
    external_events: list[dict[str, Any]] = []
    root_identity: tuple[int, float] | None = None
    runner_process: Any | None = None
    launch_identity_binding: dict[str, Any] | None = None
    runner_exit_code: int | None = None
    runner_wait_confirmed = False
    started_mono = time.monotonic()
    sample_index = 0
    termination_attempt: dict[str, Any] | None = None

    with tempfile.TemporaryFile(mode="w+b") as runner_stdout, \
            tempfile.TemporaryFile(mode="w+b") as runner_stderr:
        runner = subprocess.Popen(
            child_argv, cwd=str(ROOT), env=os.environ.copy(),
            stdout=runner_stdout, stderr=runner_stderr, shell=False,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        runner_process, root_identity, launch_identity_binding = bind_popen_process_identity(runner)
        if launch_identity_binding.get("complete") is True and root_identity is not None:
            handles[root_identity] = runner_process
        else:
            forced_failures.append("supervised_runner_popen_process_generation_binding_failed")
            if launch_identity_binding.get("errors"):
                forced_failures.extend(
                    f"launch_identity:{item.get('phase')}:{item.get('exception_type') or item.get('reason')}"
                    for item in launch_identity_binding["errors"]
                )
            if runner_process is not None:
                try:
                    descendants = runner_process.children(recursive=True)
                    if not isinstance(descendants, (list, tuple)):
                        raise TypeError("recursive child enumeration did not return a list")
                    for process in descendants:
                        identity = _identity(process.pid, process.create_time())
                        if identity in handles:
                            raise ValueError("duplicate descendant identity during recovery enumeration")
                        handles[identity] = process
                except Exception as tree_exc:
                    forced_failures.append(
                        f"unidentified_runner_tree_enumeration_failed:{type(tree_exc).__name__}:{tree_exc}"
                    )
            if handles:
                termination_attempt = terminate_and_wait(
                    handles, list(handles), timeout_seconds=WAIT_TIMEOUT_SECONDS
                )
                if termination_attempt.get("complete") is not True:
                    forced_failures.append("unidentified_runner_descendant_termination_incomplete")
            root_kill = kill_popen_if_bound(
                runner, root_identity, launch_identity_binding
            )
            if root_kill.get("signal_sent") is not True:
                forced_failures.extend(
                    f"root_kill_identity_or_signal_failed:{item}"
                    for item in root_kill.get("errors", [])
                )

        if root_identity is not None:
            next_sample_mono = 0.0
            while runner.poll() is None:
                now_mono = time.monotonic()
                if now_mono >= next_sample_mono:
                    sample_index += 1
                    try:
                        sample = sample_process_tree(
                            runner_process,
                            sample_index=sample_index,
                            sampled_utc=utc_now(),
                            elapsed_seconds=now_mono - started_mono,
                            expected_root_creation_filetime_ticks=(
                                launch_identity_binding.get("popen_handle_creation_filetime_ticks")
                                if isinstance(launch_identity_binding, dict) else None
                            ),
                            pid_handle_identity_reader=_windows_pid_handle_identity,
                        )
                    except Exception as exc:
                        sample = {
                            "schema": "native-g1g2-r22-process-tree-sample-v1",
                            "sample_index": sample_index, "utc": utc_now(),
                            "elapsed_seconds": now_mono - started_mono,
                            "root_pid": root_identity[0],
                            "root_create_time": root_identity[1],
                            "complete": False, "processes": [],
                            "partial_rss_bytes": 0, "rss_bytes": None,
                            "errors": [_error("outer_process_tree_sample", exc)],
                        }
                    samples.append(sample)
                    for row in sample.get("processes", []):
                        try:
                            identity = _identity(row.get("pid"), row.get("create_time"))
                        except Exception as exc:
                            forced_failures.append(
                                f"sampled_process_identity_invalid:{type(exc).__name__}:{exc}"
                            )
                            continue
                        try:
                            handle = psutil.Process(identity[0])
                            handle_identity = _identity(handle.pid, handle.create_time())
                            immediate_handle_identity = _identity(handle.pid, handle.create_time())
                            if (not _same_identity(handle_identity, identity) or
                                    not _same_identity(immediate_handle_identity, identity)):
                                raise ValueError("PID was reused between sample and handle bind")
                            handles.setdefault(identity, handle)
                        except Exception as exc:
                            forced_failures.append(
                                f"observed_process_handle_failed:{identity[0]}:{type(exc).__name__}:{exc}"
                            )
                    if sample.get("complete") is not True:
                        forced_failures.append("outer_process_tree_sample_incomplete")
                        event = {"kind": "resource_monitor_incomplete",
                                 "sample_index": sample_index,
                                 "partial_rss_bytes": sample.get("partial_rss_bytes"),
                                 "errors": sample.get("errors", [])}
                        external_events.append(event)
                        termination_attempt = terminate_and_wait(
                            handles, list(handles), timeout_seconds=WAIT_TIMEOUT_SECONDS
                        )
                        forced_failures.extend(
                            f"termination_incomplete:{item.get('phase')}:{item.get('exception_type') or item.get('reason')}"
                            for item in termination_attempt.get("errors", [])
                        )
                        break
                    try:
                        _collect_markers(leaf, pre_scans, post_scans,
                                         scan_global=scan_heavy_processes)
                    except Exception as exc:
                        forced_failures.append(f"stage_boundary_scan_failed:{type(exc).__name__}:{exc}")
                        external_events.append({"kind": "resource_monitor_incomplete",
                                                "sample_index": sample_index,
                                                "error": repr(exc)})
                        termination_attempt = terminate_and_wait(
                            handles, list(handles), timeout_seconds=WAIT_TIMEOUT_SECONDS
                        )
                        break

                    active = _current_stage_files(leaf)
                    for stage_index, stage_name, start, _ in active:
                        try:
                            stage_identity = _identity(start.get("pid"), start.get("process_create_time"))
                            elapsed = _wall_elapsed(start.get("started_utc"), utc_now())
                        except Exception as exc:
                            forced_failures.append(f"stage_{stage_index}_watchdog_identity_invalid:{type(exc).__name__}:{exc}")
                            continue
                        if elapsed < 0:
                            forced_failures.append(f"stage_{stage_index}_wall_clock_moved_before_start")
                            external_events.append({
                                "kind": "resource_monitor_incomplete",
                                "index": stage_index, "stage": stage_name,
                                "root_pid": stage_identity[0],
                                "root_create_time": stage_identity[1],
                                "elapsed_seconds": elapsed,
                            })
                            termination_attempt = terminate_and_wait(
                                handles, list(handles), timeout_seconds=WAIT_TIMEOUT_SECONDS
                            )
                            break
                        stage_rss = _stage_rss_at_sample(sample, stage_identity)
                        stop_kind = None
                        if stage_rss is not None and stage_rss >= RSS_THRESHOLD_BYTES:
                            stop_kind = "sampled_rss_threshold_hit_or_overshoot"
                        elif elapsed >= STAGE_WALL_SECONDS:
                            stop_kind = "stage_wall_deadline"
                        if stop_kind is not None:
                            event = {
                                "kind": stop_kind, "index": stage_index,
                                "stage": stage_name, "root_pid": stage_identity[0],
                                "root_create_time": stage_identity[1],
                                "elapsed_seconds": elapsed,
                                "rss_bytes": stage_rss,
                                "sample_index": sample_index,
                                "sampled_utc": sample.get("utc"),
                                "disposition": "resource_failure",
                            }
                            external_events.append(event)
                            stage_members: set[tuple[int, float]] = set()
                            try:
                                stage_members = _stage_descendants_in_sample(
                                    sample.get("processes", []), stage_identity
                                )
                                if stage_identity not in stage_members:
                                    forced_failures.append(
                                        f"stage_{stage_index}_root_missing_from_stop_sample"
                                    )
                            except Exception as exc:
                                forced_failures.append(f"stage_{stage_index}_kill_enumeration_failed:{type(exc).__name__}:{exc}")
                            termination_attempt = terminate_and_wait(
                                handles, list(handles), timeout_seconds=WAIT_TIMEOUT_SECONDS
                            )
                            if termination_attempt.get("complete") is not True:
                                forced_failures.append(f"stage_{stage_index}_kill_or_wait_incomplete")
                            break
                    next_sample_mono = now_mono + SAMPLE_INTERVAL_SECONDS

                if termination_attempt is not None and termination_attempt.get("complete") is not True:
                    break
                time.sleep(min(0.02, max(0.001, next_sample_mono - time.monotonic())))

            if termination_attempt is None:
                try:
                    runner_exit_code = runner.wait(timeout=WAIT_TIMEOUT_SECONDS)
                    runner_wait_confirmed = type(runner_exit_code) is int
                    if not runner_wait_confirmed:
                        forced_failures.append("supervised_runner_wait_returned_invalid_exit_code")
                except Exception as exc:
                    forced_failures.append(f"supervised_runner_wait_failed:{type(exc).__name__}:{exc}")
            elif runner.poll() is not None:
                try:
                    runner_exit_code = runner.wait(timeout=WAIT_TIMEOUT_SECONDS)
                    runner_wait_confirmed = type(runner_exit_code) is int
                except Exception as exc:
                    forced_failures.append(f"supervised_runner_post_termination_wait_failed:{type(exc).__name__}:{exc}")
            elif runner.poll() is None:
                forced_failures.append("supervised_runner_alive_after_incomplete_termination")
                root_kill = kill_popen_if_bound(
                    runner, root_identity, launch_identity_binding
                )
                if root_kill.get("signal_sent") is not True:
                    forced_failures.extend(
                        f"supervised_runner_final_kill_identity_or_signal_failed:{item}"
                        for item in root_kill.get("errors", [])
                    )
                try:
                    runner_exit_code = runner.wait(timeout=WAIT_TIMEOUT_SECONDS)
                    runner_wait_confirmed = type(runner_exit_code) is int
                except Exception as exc:
                    forced_failures.append(f"supervised_runner_final_wait_failed:{type(exc).__name__}:{exc}")

        if root_identity is None and not runner_wait_confirmed:
            try:
                runner_exit_code = runner.wait(timeout=WAIT_TIMEOUT_SECONDS)
                runner_wait_confirmed = type(runner_exit_code) is int
            except Exception as exc:
                forced_failures.append(f"unidentified_runner_wait_failed:{type(exc).__name__}:{exc}")

        # Reconcile every externally observed child after the root runner exits,
        # including identities outside the three Julia stage windows.
        tracked_descendant_receipts: list[dict[str, Any]] = []
        descendant_ids = [identity for identity in handles
                          if not _same_identity(identity, root_identity)]
        tracked_descendant_receipts, wait_errors = process_exit_receipts(
            handles, descendant_ids, timeout_seconds=WAIT_TIMEOUT_SECONDS
        )
        if wait_errors:
            forced_failures.append("tracked_descendant_wait_incomplete")
            forced_failures.extend(
                f"descendant_wait:{item.get('pid')}:{item.get('exception_type') or item.get('reason')}"
                for item in wait_errors
            )
            retry_ids = [
                (item.get("pid"), item.get("create_time"))
                for item in wait_errors
                if type(item.get("pid")) is int and
                _finite_number(item.get("create_time"), positive=True)
            ]
            retry_kill = terminate_and_wait(
                handles, retry_ids, timeout_seconds=WAIT_TIMEOUT_SECONDS
            )
            if termination_attempt is None:
                termination_attempt = retry_kill
            else:
                termination_attempt = {
                    "attempted": True,
                    "complete": termination_attempt.get("complete") is True and
                                retry_kill.get("complete") is True,
                    "prior": termination_attempt,
                    "retry": retry_kill,
                }
            if retry_kill.get("complete") is not True:
                forced_failures.append("descendant_kill_or_wait_incomplete")
        if termination_attempt is not None and termination_attempt.get("complete") is not True:
            forced_failures.append("termination_request_or_wait_incomplete")

        runner_stdout.seek(0)
        stdout_bytes = runner_stdout.read()
        runner_stderr.seek(0)
        stderr_bytes = runner_stderr.read()

    if not leaf.is_dir():
        leaf.mkdir(parents=True, exist_ok=False)
        forced_failures.append("r16_child_did_not_create_actual_output_leaf")
    # Preserve the wrapper's actual child streams as additive run evidence.
    try:
        write_new(leaf / "root_supervised_runner.stdout.raw", stdout_bytes)
        write_new(leaf / "root_supervised_runner.stderr.raw", stderr_bytes)
    except Exception as exc:
        forced_failures.append(f"runner_stream_write_failed:{type(exc).__name__}:{exc}")

    try:
        _collect_markers(leaf, pre_scans, post_scans, scan_global=scan_heavy_processes)
    except Exception as exc:
        forced_failures.append(f"final_stage_scan_failed:{type(exc).__name__}:{exc}")
    post_inventory = scan_heavy_processes()
    audit, failures = build_outer_audit(
        leaf=leaf, protocol=protocol, child_argv=child_argv,
        root_identity=root_identity, runner_exit_code=runner_exit_code,
        runner_wait_confirmed=runner_wait_confirmed,
        pre_inventory=baseline, post_inventory=post_inventory,
        samples=samples, handles=handles, pre_scans=pre_scans,
        post_scans=post_scans, forced_failures=forced_failures,
        external_events=external_events, termination_receipt=termination_attempt,
        tracked_process_exit_receipts=tracked_descendant_receipts,
        supervisor_invocation_argv=supervisor_invocation_argv,
        launch_identity_binding=launch_identity_binding,
    )
    audit_path = leaf / OUTER_AUDIT_FILENAME
    audit_bytes = write_new(audit_path, audit)
    audit_sha = sha256_bytes(audit_bytes)

    reporter_command = [
        str(Path(sys.executable).resolve()), "-B", str(R18_REPORTER.resolve()),
        "--actual-leaf", str(leaf),
    ]
    reporter_exit: int | None = None
    reporter_stdout = b""
    reporter_stderr = b""
    reporter_error: str | None = None
    if sha256_file(R18_REPORTER) == R18_REPORTER_SHA256:
        try:
            report_run = subprocess.run(
                reporter_command, cwd=str(ROOT), capture_output=True, check=False, shell=False
            )
            reporter_exit = report_run.returncode
            reporter_stdout = report_run.stdout
            reporter_stderr = report_run.stderr
        except Exception as exc:
            reporter_error = f"{type(exc).__name__}:{exc}"
            reporter_stderr = (reporter_error + "\n").encode("utf-8", errors="replace")
    else:
        reporter_error = "R18 reporter hash mismatch; reporter not launched"
        reporter_stderr = (reporter_error + "\n").encode("utf-8")
    report_path = leaf / "resource_report_r18.json"
    reporter_stdout_path = leaf / "r18_reporter.stdout.raw"
    reporter_stderr_path = leaf / "r18_reporter.stderr.raw"
    stdout_written: bytes | None = None
    stderr_written: bytes | None = None
    try:
        stdout_written = write_new(reporter_stdout_path, reporter_stdout)
        stderr_written = write_new(reporter_stderr_path, reporter_stderr)
    except Exception as exc:
        reporter_error = reporter_error or f"reporter_raw_write:{type(exc).__name__}:{exc}"
    binding = {
        "schema": "native-g1g2-r22-root-to-r18-report-binding-v1",
        "outer_audit_path": OUTER_AUDIT_FILENAME,
        "outer_audit_sha256": audit_sha,
        "r18_reporter_path": str(R18_REPORTER.resolve()),
        "r18_reporter_sha256": sha256_file(R18_REPORTER) if R18_REPORTER.is_file() else None,
        "r18_reporter_argv": reporter_command,
        "r18_reporter_exit_code": reporter_exit,
        "r18_reporter_error": reporter_error,
        "r18_report_path": report_path.name,
        "r18_report_sha256": sha256_file(report_path) if report_path.is_file() else None,
        "r18_reporter_stdout_path": reporter_stdout_path.name,
        "r18_reporter_stdout_sha256": sha256_bytes(stdout_written) if stdout_written is not None else None,
        "r18_reporter_stderr_path": reporter_stderr_path.name,
        "r18_reporter_stderr_sha256": sha256_bytes(stderr_written) if stderr_written is not None else None,
        "reporter_stdout_sha256": sha256_bytes(reporter_stdout),
        "reporter_stderr_sha256": sha256_bytes(reporter_stderr),
        "reporter_exit_means": "report_written_only",
    }
    binding_path = leaf / REPORT_BINDING_FILENAME
    write_new(binding_path, binding)
    if reporter_exit != 0 or not report_path.is_file():
        return 1, audit
    return (0 if not failures else 1), audit


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="r16_root_supervised_actual_r22_v1")
    parser.add_argument("--julia", default=None)
    parser.add_argument("--static-only", action="store_true")
    parser.add_argument("--dispatch-actual", default=None)
    args = parser.parse_args(argv)
    protocol = _read_json(r22_PROTOCOL)
    invocation_argv = _current_invocation_argv()
    invocation_mode = "static" if args.static_only else "runtime"
    invocation_errors = _validate_invocation(protocol, invocation_mode, invocation_argv)
    if invocation_errors:
        print(json.dumps({"status": "frozen_invocation_mismatch",
                          "errors": invocation_errors,
                          "runtime_executed": False}, sort_keys=True))
        return 2
    dispatch = protocol.get("dispatch", {})
    julia = args.julia or dispatch.get("julia_executable")
    if not isinstance(julia, str):
        raise ValueError("frozen Julia executable path is missing")
    static_errors = _validate_static_command(julia, args.output)
    if static_errors:
        print(json.dumps({"status": "static_preflight_failed", "errors": static_errors}, sort_keys=True))
        return 2
    if args.static_only:
        print(json.dumps({
            "status": "static_preflight_pass",
            "runtime_executed": False,
            "julia_started": False,
            "r16_limits": protocol["r16_limits"],
        }, sort_keys=True))
        return 0
    runtime_block = _runtime_dispatch_block_reason(protocol)
    if runtime_block is not None:
        print(json.dumps({
            "status": "r22_runtime_no_go",
            "reason": runtime_block,
            "runtime_executed": False,
            "julia_started": False,
        }, sort_keys=True))
        return 3
    if args.dispatch_actual != ACTUAL_DISPATCH_TOKEN:
        print(json.dumps({"status": "fail_closed", "reason": "root_dispatch_token_required",
                          "runtime_executed": False}, sort_keys=True))
        return 3
    exit_code, audit = run_supervised_actual(args.output, julia, invocation_argv)
    print(json.dumps({
        "status": "root_supervisor_pass" if audit and audit.get("audit_status") == "pass" else "root_supervisor_incomplete",
        "audit_path": str((ARCHIVE_ROOT / args.output / OUTER_AUDIT_FILENAME).resolve()),
        "report_path": str((ARCHIVE_ROOT / args.output / "resource_report_r18.json").resolve()),
        "runtime_executed": True,
        "numerical_status": "not_established",
        "physical_status": "unknown",
    }, sort_keys=True))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
