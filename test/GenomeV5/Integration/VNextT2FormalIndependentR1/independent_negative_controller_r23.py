from __future__ import annotations

import argparse
import ctypes
from collections import Counter
import copy
from dataclasses import replace
import csv
from datetime import datetime
import hashlib
import io
import json
import math
import msvcrt
import os
import platform
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time
import traceback
from typing import Any, Mapping

import psutil


ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.execution.t2_source_inputs import T2SourceInputs

_T2_SOURCE_INPUTS = None
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
R23_CONTROLLER_RELATIVE_PATH = (
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
    "independent_negative_controller_r23.py")
IMPLEMENTATION_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2IdentityReceiptV2"
T2_RAW_EVIDENCE_ROOT = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()


def require_t2_execution_leaf(path: Path) -> None:
    """Keep current and replay evidence in a single owned T2 run leaf."""
    if path.resolve().parent != T2_RAW_EVIDENCE_ROOT:
        raise ValueError("T2 execution evidence must be a direct owned run leaf")
ACTUAL_DRIVER = TEST_ROOT / "actual_formal_negative_driver_r6.jl"
SUPPLEMENTARY_DRIVER = TEST_ROOT / "supplementary_contract_driver_r1.jl"
ARTIFACT_DRIVER = TEST_ROOT / "artifact_preflight_negative_driver_r1.jl"
ATTACK_FIXTURE_DRIVER = TEST_ROOT / "artifact_attack_fixture_driver_r1.jl"
AST_INVENTORY_DRIVER = TEST_ROOT / "coverage_ast_inventory_r3.jl"
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r12.py"
CANDIDATE_DRIVER = IMPLEMENTATION_ROOT / "formal_candidate_driver.jl"
PROJECTION_DRIVER = IMPLEMENTATION_ROOT / (
    "vnext_t2_package_full_content_projection_r1.jl")
PARSE_GATE = ROOT / (
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl")
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
AUTHORITY_CASE_ORDER = [
    "PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
    "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
    "ACTUAL_FORMAL_GATE_REJECTION",
    "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
    "ACTUAL_DUPLICATE_INVOCATION",
]
AUTHORITY_PHASE_TIMEOUT_SECONDS = 2400
PREFLIGHT_PHASE_TIMEOUT_SECONDS = 600
AUTHORITY_CASE_TIMEOUT_SECONDS = 2400
AUTHORITY_WORKING_SET_LIMIT_BYTES = 2_147_483_648


def actual_formal_shard_timeout(mode: str, configured_default: float) -> float:
    if configured_default != 480:
        raise ValueError("formal shard default phase timeout must remain 480s")
    if mode == "preflight":
        return PREFLIGHT_PHASE_TIMEOUT_SECONDS
    if mode not in {"fault_n10", "t1_handoff"}:
        raise ValueError(f"unsupported timeout policy for shard: {mode}")
    return configured_default

OWNED_CANDIDATE_ARTIFACTS = (
    "candidate_package.jls",
    "candidate_t1_admission_receipt.json",
    "t2_result.jls",
    "run_receipt.json",
    "replay_uncommitted_attempt.json",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _source_inputs() -> T2SourceInputs:
    global _T2_SOURCE_INPUTS
    if _T2_SOURCE_INPUTS is None:
        _T2_SOURCE_INPUTS = T2SourceInputs(ROOT)
    return _T2_SOURCE_INPUTS


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data),
            "sha256": sha256_bytes(data)}


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = json.loads(line)
        if not isinstance(value, dict):
            raise RuntimeError(f"expected JSON object at {path}:{number}")
        rows.append(value)
    return rows


def load_jsonl_complete_prefix(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Read only fully newline-terminated JSONL records for partial evidence."""
    data = path.read_bytes()
    rows: list[dict[str, Any]] = []
    offset = 0
    for index, line in enumerate(data.splitlines(keepends=True)):
        end = offset + len(line)
        if not line.endswith(b"\n"):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": False}
        try:
            value = json.loads(line.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": True,
                          "invalid_complete_row": True}
        if not isinstance(value, dict):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": True,
                          "invalid_complete_row": True}
        rows.append(value)
        offset = end
    return rows, {"complete_row_count": len(rows),
                  "truncated_row_index": None,
                  "valid_prefix_bytes": offset,
                  "file_bytes": len(data),
                  "trailing_row_terminated": True,
                  "invalid_complete_row": False}


def first_error_line(path: Path) -> str:
    lines = [line.strip() for line in path.read_text(
        encoding="utf-8", errors="replace").splitlines() if line.strip()]
    if not lines:
        raise RuntimeError(f"missing error output: {path}")
    return lines[0]


def require_output_guard_first_error(path: Path, artifact_name: str) -> str:
    observed = first_error_line(path)
    expected = (
        "ERROR: LoadError: (:formal_t2_output_artifact_already_exists, "
        f'"{artifact_name}")')
    if observed != expected:
        raise RuntimeError(
            f"output guard first error mismatch: {observed!r} != {expected!r}")
    return observed


def digest_value(value: Any, label: str) -> str:
    if isinstance(value, str):
        digest = value
    elif isinstance(value, dict) and set(value) == {"value"}:
        digest = value["value"]
    else:
        raise RuntimeError(f"{label} is not a digest: {value!r}")
    digest = digest.lower()
    if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
        raise RuntimeError(f"{label} is not a lowercase SHA-256: {digest!r}")
    return digest


def git_head(*, output: Path | None = None,
             timeout_seconds: float = 480.0,
             receipts: dict[str, Any] | None = None,
             receipt_key: str | None = None) -> str:
    if _R23_ACTIVE_PROTOCOL_SHA256 is None:
        if output is not None or receipts is not None or receipt_key is not None:
            raise RuntimeError(
                "repository-head phase receipts require a verified managed protocol")
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        return result.stdout.strip()
    if not isinstance(output, Path) or not output.is_absolute() or \
            type(receipts) is not dict or type(receipt_key) is not str or \
            not receipt_key or receipt_key in receipts:
        raise RuntimeError(
            "managed repository-head query requires an owned output leaf and receipt map")
    resolved_output = output.resolve()
    try:
        resolved_output.relative_to(ROOT)
    except ValueError as error:
        raise RuntimeError(
            "managed repository-head output is outside the repository") from error
    command = ["git", "rev-parse", "HEAD"]
    phase = run_phase(
        "repository_head", command, resolved_output,
        timeout_seconds=timeout_seconds,
        working_set_limit_bytes=AUTHORITY_WORKING_SET_LIMIT_BYTES,
        environment=os.environ.copy())
    query_receipt = {
        "schema": "vnext-t2-managed-repository-head-query-r1",
        "output_leaf": resolved_output.relative_to(ROOT).as_posix(),
        "command": command,
        "phase": file_receipt(resolved_output / "phase.json"),
        "stdout": file_receipt(resolved_output / "stdout.raw"),
        "stderr": file_receipt(resolved_output / "stderr.raw"),
        "exit_code": phase.get("exit_code"),
        "stop_reason": phase.get("stop_reason"),
        "process_tree_sample_count": phase.get("process_tree_sample_count"),
        "process_tree_samples_complete": phase.get(
            "process_tree_samples_complete"),
    }
    receipts[receipt_key] = query_receipt
    require_natural(phase, exit_zero=True)
    if phase.get("name") != "repository_head" or phase.get("exit_code") != 0 or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("process_tree_samples_complete") is not True:
        raise RuntimeError(
            "managed repository-head phase did not complete with natural process exit")
    head = (resolved_output / "stdout.raw").read_bytes().decode("ascii").strip()
    if not head or any(character.isspace() for character in head):
        raise RuntimeError("managed repository-head query returned malformed stdout")
    query_receipt["head_value_sha256"] = sha256_bytes(head.encode("ascii"))
    return head


def utc() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _monitor_error(stage: str, error: BaseException, pid: int | None = None
                   ) -> dict[str, Any]:
    return {"stage": stage, "pid": pid,
            "exception_type": type(error).__name__,
            "message": str(error)}


def _valid_pid(value: Any) -> bool:
    return type(value) is int and value > 0


def _valid_pid_inventory(value: Any, *, platform_name: str | None = None) -> bool:
    platform = os.name if platform_name is None else platform_name
    return _valid_pid(value) or (
        platform == "nt" and type(value) is int and value == 0)


def _is_windows_idle_sentinel(value: Any) -> bool:
    return os.name == "nt" and type(value) is int and value == 0


def _is_windows_idle_process_info(info: Any) -> bool:
    if os.name != "nt" or not isinstance(info, dict) or \
            type(info.get("pid")) is not int or info.get("pid") != 0 or \
            info.get("name") != "System Idle Process" or \
            type(info.get("ppid")) is not int or info.get("ppid") != 0:
        return False
    create_time = info.get("create_time")
    if type(create_time) not in (int, float):
        return False
    try:
        return math.isfinite(float(create_time)) and create_time == 0.0
    except (OverflowError, TypeError, ValueError):
        return False


def _is_windows_system_sentinel(value: Any) -> bool:
    return os.name == "nt" and type(value) is int and value == 4


def _is_windows_system_process_info(info: Any) -> bool:
    if os.name != "nt" or not isinstance(info, dict) or \
            type(info.get("pid")) is not int or info.get("pid") != 4 or \
            info.get("name") != "System" or \
            type(info.get("ppid")) is not int or info.get("ppid") != 0:
        return False
    create_time = info.get("create_time")
    return type(create_time) is float and math.isfinite(create_time) and \
        create_time == 0.0


def _valid_ppid(value: Any) -> bool:
    return type(value) is int and value >= 0


def _valid_finite_nonnegative_real(value: Any) -> bool:
    if type(value) not in (int, float):
        return False
    try:
        numeric = float(value)
    except (OverflowError, TypeError, ValueError):
        return False
    return math.isfinite(numeric) and numeric >= 0


def _valid_finite_positive_real(value: Any) -> bool:
    if type(value) not in (int, float):
        return False
    try:
        numeric = float(value)
    except (OverflowError, TypeError, ValueError):
        return False
    return math.isfinite(numeric) and numeric > 0


def _valid_create_time(value: Any) -> bool:
    return _valid_finite_positive_real(value)


def _valid_cpu_seconds(value: Any) -> bool:
    return _valid_finite_nonnegative_real(value)


def _valid_rss_bytes(value: Any) -> bool:
    return type(value) is int and value >= 0


def _bind_launch_root_identity(launch_handle: Any,
                               looked_up_root: psutil.Process
                               ) -> dict[str, Any]:
    """Bind pid lookup to the exact process generation created by Popen."""
    try:
        launch_pid = launch_handle.pid
        launch_create_time = launch_handle.create_time()
        lookup_pid = looked_up_root.pid
        lookup_create_time = looked_up_root.create_time()
    except Exception as error:
        raise RuntimeError(
            f"launch-root identity unavailable: {type(error).__name__}: {error}") from error
    if not _valid_pid(launch_pid) or not _valid_pid(lookup_pid) or \
            launch_pid != lookup_pid or \
            not _valid_create_time(launch_create_time) or \
            not _valid_create_time(lookup_create_time) or \
            launch_create_time != lookup_create_time:
        raise RuntimeError(
            "launch-root PID/create_time differs from post-launch PID lookup; "
            "PID reuse or incomplete identity binding")
    return {"schema": "vnext-t2-launch-root-identity-r1",
            "complete": True, "pid": launch_pid,
            "create_time": launch_create_time,
            "looked_up_pid": lookup_pid,
            "looked_up_create_time": lookup_create_time}


def _terminate_unbound_launch(
        launch_handle: psutil.Popen, launch_create_time: float | None,
        launch_identity_error: dict[str, Any]) -> dict[str, Any]:
    """Best-effort cleanup through the launch handle; never certify it."""
    poll_error: dict[str, Any] | None = None
    try:
        initial_poll = launch_handle.poll()
    except Exception as error:
        initial_poll = None
        poll_error = _monitor_error(
            "launch_identity_cleanup_poll", error, launch_handle.pid)
    if _valid_create_time(launch_create_time):
        try:
            receipt = kill_tree(
                launch_handle, launch_create_time, [],
                root_exit_confirmed=poll_error is None and
                initial_poll is not None)
        except Exception as error:
            cleanup_errors = [_monitor_error(
                "launch_identity_cleanup", error, launch_handle.pid)]
            if poll_error is not None:
                cleanup_errors.append(poll_error)
            receipt = {"schema": "vnext-t2-process-tree-termination-r1",
                       "complete": False, "verified": False,
                       "root_exit_confirmed": False,
                       "signal_attempts": [], "events": [],
                       "errors": cleanup_errors,
                       "still_alive": [{"pid": launch_handle.pid,
                                        "identity_unknown": True}]}
        if poll_error is not None:
            receipt.setdefault("errors", []).append(poll_error)
    else:
        events: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        if poll_error is not None:
            errors.append(poll_error)
        try:
            if poll_error is None and initial_poll is None:
                launch_handle.kill()
                events.append({"stage": "exact_launch_handle_kill",
                               "outcome": "kill_requested"})
            exit_code = launch_handle.wait(timeout=8)
            events.append({"stage": "exact_launch_handle_wait",
                           "outcome": "exited", "exit_code": exit_code})
        except Exception as error:
            errors.append(_monitor_error(
                "exact_launch_handle_cleanup", error, launch_handle.pid))
        try:
            final_poll = launch_handle.poll()
            root_exit_confirmed = final_poll is not None
        except Exception as error:
            root_exit_confirmed = False
            errors.append(_monitor_error(
                "launch_identity_cleanup_final_poll", error,
                launch_handle.pid))
        receipt = {"schema": "vnext-t2-process-tree-termination-r1",
                   "complete": False, "verified": False,
                   "root_exit_confirmed": root_exit_confirmed,
                   "signal_attempts": [], "events": events,
                   "errors": errors, "still_alive": (
                       [{"pid": launch_handle.pid}]
                       if not root_exit_confirmed else [])}
    receipt["launch_identity_binding_failed"] = True
    receipt["complete"] = False
    receipt["verified"] = False
    receipt.setdefault("errors", []).append(launch_identity_error)
    return receipt


class _NativeUnicodeString(ctypes.Structure):
    _fields_ = [('Length', ctypes.c_ushort),
                ('MaximumLength', ctypes.c_ushort),
                ('_padding', ctypes.c_uint32),
                ('Buffer', ctypes.c_void_p)]


class _NativeSystemProcessInformation(ctypes.Structure):
    _fields_ = [
        ('NextEntryOffset', ctypes.c_uint32),
        ('NumberOfThreads', ctypes.c_uint32),
        ('WorkingSetPrivateSize', ctypes.c_int64),
        ('HardFaultCount', ctypes.c_uint32),
        ('NumberOfThreadsHighWatermark', ctypes.c_uint32),
        ('CycleTime', ctypes.c_uint64),
        ('CreateTime', ctypes.c_int64),
        ('UserTime', ctypes.c_int64),
        ('KernelTime', ctypes.c_int64),
        ('ImageName', _NativeUnicodeString),
        ('BasePriority', ctypes.c_int32),
        ('UniqueProcessId', ctypes.c_void_p),
        ('InheritedFromUniqueProcessId', ctypes.c_void_p),
    ]


_WINDOWS_FILETIME_UNIX_EPOCH_100NS = 116_444_736_000_000_000
_WINDOWS_SPI_QUERY_CLASS = 5
_WINDOWS_STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
_WINDOWS_NATIVE_TABLE_MAX_BYTES = 64 * 1024 * 1024
_WINDOWS_NATIVE_TABLE_INITIAL_BYTES = 4 * 1024 * 1024
_WINDOWS_NATIVE_SUPPORTED_HOST = (10, 0, 26200, 'AMD64')


def _valid_create_time_100ns(value: Any) -> bool:
    return type(value) is int and 0 < value <= (1 << 63) - 1


def _native_create_time_seconds(value: int) -> float:
    if not _valid_create_time_100ns(value):
        raise ValueError('invalid raw Windows creation time')
    return (value - _WINDOWS_FILETIME_UNIX_EPOCH_100NS) / 10_000_000.0


def _native_process_identity(row: dict[str, Any]) -> tuple[int, int, int, str]:
    return (row['pid'], row['ppid'], row['create_time_100ns'], row['name'])


def _parse_windows_native_process_table_buffer(
        buffer: Any, used_bytes: int) -> dict[str, Any]:
    """Parse one x64 SystemProcessInformation response without lossy identities."""
    if ctypes.sizeof(ctypes.c_void_p) != 8 or \
            ctypes.sizeof(_NativeUnicodeString) != 16 or \
            ctypes.sizeof(_NativeSystemProcessInformation) != 96 or \
            _NativeSystemProcessInformation.CreateTime.offset != 32 or \
            _NativeSystemProcessInformation.ImageName.offset != 56 or \
            _NativeSystemProcessInformation.UniqueProcessId.offset != 80 or \
            _NativeSystemProcessInformation.InheritedFromUniqueProcessId.offset != 88:
        raise RuntimeError('unsupported Windows native process-table ABI')
    if type(used_bytes) is not int or used_bytes < ctypes.sizeof(
            _NativeSystemProcessInformation):
        raise RuntimeError('native process-table length is truncated or malformed')
    try:
        allocation_bytes = ctypes.sizeof(buffer)
        base = ctypes.addressof(buffer)
    except Exception as error:
        raise RuntimeError('native process-table buffer is not an owned ctypes allocation') from error
    if used_bytes > allocation_bytes or used_bytes > _WINDOWS_NATIVE_TABLE_MAX_BYTES:
        raise RuntimeError('native process-table length exceeds its bounded allocation')
    end_address = base + used_bytes
    offset = 0
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()
    while True:
        if len(rows) >= 1_000_000 or offset < 0 or \
                offset + ctypes.sizeof(_NativeSystemProcessInformation) > used_bytes or \
                (base + offset) % 8 != 0:
            raise RuntimeError('native process-table record bounds are invalid')
        record = _NativeSystemProcessInformation.from_address(base + offset)
        raw_pid = record.UniqueProcessId
        raw_ppid = record.InheritedFromUniqueProcessId
        pid = 0 if raw_pid is None else int(raw_pid)
        ppid = 0 if raw_ppid is None else int(raw_ppid)
        ticks = int(record.CreateTime)
        if type(pid) is not int or not _valid_pid_inventory(pid, platform_name='nt') or \
                not _valid_ppid(ppid) or not _valid_create_time_100ns(ticks):
            raise RuntimeError('native process-table PID/PPID/create-time is invalid')
        if pid in seen:
            raise RuntimeError(f'native process-table contains duplicate PID {pid}')
        seen.add(pid)
        image_length = int(record.ImageName.Length)
        image_maximum = int(record.ImageName.MaximumLength)
        image_pointer = 0 if record.ImageName.Buffer is None else int(record.ImageName.Buffer)
        if image_length < 0 or image_maximum < image_length or \
                image_length % 2 != 0 or image_length > 8192:
            raise RuntimeError(f'native process-table image string bounds invalid for PID {pid}')
        if image_length:
            if image_pointer < base or image_pointer + image_length > end_address:
                raise RuntimeError(f'native process-table image pointer escapes buffer for PID {pid}')
            name = ctypes.string_at(image_pointer, image_length).decode('utf-16le', errors='strict')
        else:
            if image_pointer not in (0, base + offset + _NativeSystemProcessInformation.ImageName.offset + 8):
                raise RuntimeError(f'native process-table empty image pointer is malformed for PID {pid}')
            name = ''
        if pid != 0 and not name:
            raise RuntimeError(f'native process-table image name is empty for non-idle PID {pid}')
        rows.append({
            'pid': pid, 'ppid': ppid, 'create_time_100ns': ticks,
            'create_time': _native_create_time_seconds(ticks), 'name': name,
            'name_source': 'nt_system_process_information',
            'generation_source': 'raw_create_time_100ns',
        })
        next_offset = int(record.NextEntryOffset)
        if next_offset == 0:
            break
        if next_offset < ctypes.sizeof(_NativeSystemProcessInformation) or \
                next_offset % 8 != 0 or offset + next_offset <= offset or \
                offset + next_offset + ctypes.sizeof(_NativeSystemProcessInformation) > used_bytes:
            raise RuntimeError('native process-table next-entry offset is invalid')
        offset += next_offset
    if not rows:
        raise RuntimeError('native process-table response has no records')
    return {'schema': 'vnext-t2-windows-native-process-table-r1',
            'complete': True, 'row_count': len(rows),
            'buffer_bytes': used_bytes, 'rows': rows, 'errors': []}


def _windows_native_process_table() -> dict[str, Any]:
    """Read the exact x64 Windows kernel process inventory and creation ticks."""
    try:
        version = sys.getwindowsversion()
        observed_host = (version.major, version.minor, version.build,
                         platform.machine().upper())
    except Exception as error:
        return {'schema': 'vnext-t2-windows-native-process-table-r1',
                'complete': False, 'row_count': 0, 'buffer_bytes': 0,
                'rows': [], 'errors': [_monitor_error(
                    'native_process_table_host_version', error)]}
    if os.name != 'nt' or ctypes.sizeof(ctypes.c_void_p) != 8 or \
            observed_host != _WINDOWS_NATIVE_SUPPORTED_HOST:
        return {'schema': 'vnext-t2-windows-native-process-table-r1',
                'complete': False, 'row_count': 0, 'buffer_bytes': 0,
                'rows': [], 'host_identity': observed_host, 'errors': [_monitor_error(
                    'native_process_table_platform', RuntimeError(
                        'exact process inventory requires the pinned x64 Windows build/ABI'))]}
    try:
        ntdll = ctypes.WinDLL('ntdll', use_last_error=True)
        query = ntdll.NtQuerySystemInformation
        query.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_ulong,
                          ctypes.POINTER(ctypes.c_ulong)]
        query.restype = ctypes.c_long
    except Exception as error:
        return {'schema': 'vnext-t2-windows-native-process-table-r1',
                'complete': False, 'row_count': 0, 'buffer_bytes': 0,
                'rows': [], 'errors': [_monitor_error(
                    'native_process_table_api', error)]}
    size = _WINDOWS_NATIVE_TABLE_INITIAL_BYTES
    for attempt in range(1, 9):
        if size > _WINDOWS_NATIVE_TABLE_MAX_BYTES:
            break
        try:
            buffer = ctypes.create_string_buffer(size)
            returned = ctypes.c_ulong(0)
            status = int(query(_WINDOWS_SPI_QUERY_CLASS, ctypes.byref(buffer),
                               size, ctypes.byref(returned)))
            status_u32 = ctypes.c_uint32(status).value
            if status_u32 == 0:
                used = int(returned.value)
                parsed = _parse_windows_native_process_table_buffer(buffer, used)
                parsed['query_attempts'] = attempt
                parsed['ntstatus_u32'] = status_u32
                parsed['host_identity'] = observed_host
                parsed['abi_contract'] = {
                    'system_information_class': _WINDOWS_SPI_QUERY_CLASS,
                    'windows_version': list(observed_host[:3]),
                    'machine': observed_host[3],
                    'pointer_size_bytes': ctypes.sizeof(ctypes.c_void_p),
                    'unicode_string_size_bytes': ctypes.sizeof(_NativeUnicodeString),
                    'spi_size_bytes': ctypes.sizeof(_NativeSystemProcessInformation),
                    'offsets': {'CreateTime': 32, 'ImageName': 56,
                                'UniqueProcessId': 80,
                                'InheritedFromUniqueProcessId': 88},
                    'internal_os_structure_cross_build_use': False}
                return parsed
            if status_u32 != _WINDOWS_STATUS_INFO_LENGTH_MISMATCH:
                raise OSError(f'NtQuerySystemInformation status 0x{status_u32:08x}')
            requested = int(returned.value)
            if requested <= size or requested > _WINDOWS_NATIVE_TABLE_MAX_BYTES:
                requested = size * 2
            size = max(size * 2, requested + 4096)
        except Exception as error:
            return {'schema': 'vnext-t2-windows-native-process-table-r1',
                    'complete': False, 'row_count': 0, 'buffer_bytes': size,
                    'rows': [], 'query_attempts': attempt,
                    'errors': [_monitor_error('native_process_table_query', error)]}
    return {'schema': 'vnext-t2-windows-native-process-table-r1',
            'complete': False, 'row_count': 0, 'buffer_bytes': size,
            'rows': [], 'query_attempts': 8,
            'errors': [_monitor_error(
                'native_process_table_query', RuntimeError(
                    'native process-table buffer growth exceeded its bound'))]}


def _native_table_rows(table: Any, stage: str) -> dict[int, dict[str, Any]]:
    if not isinstance(table, dict) or \
            table.get('schema') != 'vnext-t2-windows-native-process-table-r1' or \
            table.get('complete') is not True or not isinstance(table.get('rows'), list):
        raise RuntimeError(f'{stage} native process-table query is incomplete')
    rows: dict[int, dict[str, Any]] = {}
    for raw in table['rows']:
        if not isinstance(raw, dict):
            raise RuntimeError(f'{stage} native process-table row is malformed')
        pid, ppid = raw.get('pid'), raw.get('ppid')
        ticks, name = raw.get('create_time_100ns'), raw.get('name')
        if not _valid_pid_inventory(pid, platform_name='nt') or \
                not _valid_ppid(ppid) or not _valid_create_time_100ns(ticks) or \
                not isinstance(name, str) or (pid != 0 and not name):
            raise RuntimeError(f'{stage} native process-table identity is malformed')
        if pid in rows:
            raise RuntimeError(f'{stage} native process table duplicates PID {pid}')
        expected_seconds = _native_create_time_seconds(ticks)
        if type(raw.get('create_time')) not in (int, float) or \
                not math.isfinite(float(raw['create_time'])) or \
                raw['create_time'] != expected_seconds:
            raise RuntimeError(f'{stage} display create-time is not derived from raw ticks')
        rows[pid] = dict(raw)
    if not rows:
        raise RuntimeError(f'{stage} native process table is empty')
    return rows


def _validate_windows_native_sentinels(
        rows: dict[int, dict[str, Any]], stage: str) -> dict[str, Any]:
    idle = rows.get(0)
    system = rows.get(4)
    if idle is None or system is None or \
            idle.get('pid') != 0 or idle.get('ppid') != 0 or idle.get('name') != '' or \
            system.get('pid') != 4 or system.get('ppid') != 0 or \
            system.get('name') != 'System' or \
            idle.get('create_time_100ns') != system.get('create_time_100ns'):
        raise RuntimeError(f'{stage} native PID 0/PID 4 sentinel rows are not exact')
    return {'pid0': _native_process_identity(idle),
            'pid4': _native_process_identity(system)}


def _process_table_snapshot() -> dict[str, Any]:
    """Cross-check psutil PID inventories against exact native Windows snapshots.

    The kernel table is authoritative for process names and generations. psutil
    contributes only process IDs; its rounded create_time is never read here.
    Membership churn is allowed when it is bracketed by native snapshots, while
    a reused PID with changed raw creation ticks is always incomplete.
    """
    empty_counts = {stage: 0 for stage in
                    ('before_inventory', 'process_iteration',
                     'after_inventory', 'final_inventory')}
    if os.name != 'nt':
        return {'schema': 'vnext-t2-process-table-snapshot-r4',
                'complete': False, 'attempts': 0, 'rows': [],
                'errors': [_monitor_error(
                    'native_process_table_platform', RuntimeError(
                        'exact process inventory is supported only on x64 Windows'))],
                'pid0_sentinel_counts': dict(empty_counts),
                'pid4_sentinel_counts': dict(empty_counts)}

    def read_native(stage: str) -> tuple[dict[int, dict[str, Any]], dict[str, Any]]:
        table = _windows_native_process_table()
        rows = _native_table_rows(table, stage)
        sentinels = _validate_windows_native_sentinels(rows, stage)
        return rows, {'row_count': len(rows), 'buffer_bytes': table.get('buffer_bytes'),
                      'query_attempts': table.get('query_attempts'),
                      'pid0_identity': sentinels['pid0'],
                      'pid4_identity': sentinels['pid4']}

    def inventory(values: Any, stage: str) -> set[int]:
        if not isinstance(values, list) or any(
                not _valid_pid_inventory(pid, platform_name='nt') for pid in values):
            raise RuntimeError(f'{stage} psutil PID inventory contains invalid PID values')
        if len(values) != len(set(values)):
            raise RuntimeError(f'{stage} psutil PID inventory contains duplicates')
        return set(values)

    last_errors: list[dict[str, Any]] = []
    last_tables: dict[str, Any] = {}
    generation_drift: list[dict[str, Any]] = []
    for attempt in range(1, 4):
        try:
            before, before_receipt = read_native('before')
            pid_values = psutil.pids()
            pid_set = inventory(pid_values, 'pids')
            after, after_receipt = read_native('after')
            process_iter_fn = psutil.process_iter
            cache_clear = getattr(process_iter_fn, 'cache_clear', None)
            if cache_clear is None:
                cache_clear = getattr(getattr(process_iter_fn, '__func__', None),
                                      'cache_clear', None)
            cache_clear_source = None
            if callable(cache_clear):
                cache_clear()
                cache_clear_source = 'process_iter.cache_clear'
            else:
                # psutil 5.9 exposes no public cache_clear; clear its documented
                # process_iter cache before enumeration, then consume PID only.
                process_cache = getattr(psutil, '_pmap', None)
                if type(process_cache) is not dict:
                    raise RuntimeError('psutil process_iter cache cannot be cleared')
                process_cache.clear()
                cache_clear_source = 'psutil._pmap.clear'
            iter_ids: list[int] = []
            for process in process_iter_fn(attrs=['pid'], ad_value=None):
                info = getattr(process, 'info', None)
                if not isinstance(info, dict) or 'pid' not in info:
                    raise RuntimeError('psutil process_iter returned malformed PID-only row')
                pid = info.get('pid')
                if not _valid_pid_inventory(pid, platform_name='nt'):
                    raise RuntimeError('psutil process_iter returned an invalid PID')
                iter_ids.append(pid)
            iter_set = inventory(iter_ids, 'process_iter')
            final, final_receipt = read_native('final')
        except Exception as error:
            last_errors = [_monitor_error('pid_inventory_native_crosscheck', error)]
            if isinstance(error, RuntimeError) and any(
                    token in str(error) for token in
                    ('raw creation ticks', 'PID 0/PID 4 sentinel', 'duplicates',
                     'invalid PID', 'process_iter cache_clear', 'native process-table')):
                break
            if attempt < 3:
                continue
            break

        tables = [('before', before), ('after', after), ('final', final)]
        drift: list[dict[str, Any]] = []
        for index, (left_name, left) in enumerate(tables):
            for right_name, right in tables[index + 1:]:
                for pid in sorted(set(left) & set(right)):
                    left_identity = _native_process_identity(left[pid])
                    right_identity = _native_process_identity(right[pid])
                    if left_identity != right_identity:
                        drift.append({'pid': pid, 'left_snapshot': left_name,
                                      'right_snapshot': right_name,
                                      'left_identity': left_identity,
                                      'right_identity': right_identity})
        generation_drift = drift
        if drift:
            last_errors = [_monitor_error(
                'native_pid_generation_drift', RuntimeError(
                    'same PID changed exact PPID/name/raw creation ticks across native snapshots'))]
            break

        native_sets = {name: set(rows) for name, rows in tables}
        known_sets = tuple(native_sets.values())
        inventory_match = any(pid_set == values for values in known_sets)
        iterator_match = any(iter_set == values for values in known_sets)
        sentinel_counts = {
            'pid0_sentinel_counts': {
                'before_inventory': int(0 in before),
                'process_iteration': iter_ids.count(0),
                'after_inventory': int(0 in after),
                'final_inventory': int(0 in final)},
            'pid4_sentinel_counts': {
                'before_inventory': int(4 in before),
                'process_iteration': iter_ids.count(4),
                'after_inventory': int(4 in after),
                'final_inventory': int(4 in final)},
        }
        sentinels_stable = all(
            _native_process_identity(rows[pid]) ==
            _native_process_identity(before[pid])
            for _, rows in tables for pid in (0, 4) if pid in rows) and \
            all(0 in rows and 4 in rows for _, rows in tables) and \
            all(counts == {'before_inventory': 1, 'process_iteration': 1,
                           'after_inventory': 1, 'final_inventory': 1}
                for counts in sentinel_counts.values())
        if not inventory_match or not iterator_match or not sentinels_stable:
            last_errors = [_monitor_error(
                'process_membership_crosscheck', RuntimeError(
                    'psutil PID-only inventory or iterator does not match a bracketed native snapshot'))]
            if not sentinels_stable:
                last_errors.append(_monitor_error(
                    'native_windows_sentinel_crosscheck', RuntimeError(
                        'PID 0/PID 4 exact native rows or PID-only iterator counts drifted')))
            last_tables = {'before': before_receipt, 'after': after_receipt,
                           'final': final_receipt, **sentinel_counts}
            if attempt < 3 and inventory_match is False or \
                    (attempt < 3 and iterator_match is False):
                continue
            break

        final_ids = set(final)
        churn = []
        for name, rows in tables[:2]:
            churn.append({'from_snapshot': name, 'to_snapshot': 'final',
                          'added_pid_count': len(final_ids - set(rows)),
                          'removed_pid_count': len(set(rows) - final_ids),
                          'added_pids': sorted(final_ids - set(rows)),
                          'removed_pids': sorted(set(rows) - final_ids)})
        last_tables = {'before': before_receipt, 'after': after_receipt,
                       'final': final_receipt, **sentinel_counts}
        result_rows = [dict(row) for pid, row in sorted(final.items())
                       if pid not in (0, 4)]
        if any(_is_windows_idle_sentinel(row.get('pid')) or
               _is_windows_system_sentinel(row.get('pid')) for row in result_rows):
            last_errors = [_monitor_error(
                'native_windows_sentinel_filter', RuntimeError(
                    'system sentinels leaked into ordinary process rows'))]
            break
        return {'schema': 'vnext-t2-process-table-snapshot-r4',
                'complete': True, 'attempts': attempt, 'rows': result_rows,
                'errors': [], 'identity_authority':
                    'NtQuerySystemInformation_SystemProcessInformation_raw_CreateTime_100ns',
                'psutil_identity_fields_consumed': [],
                'process_iter_attributes': ['pid'],
                'process_iter_cache_cleared': True,
                'process_iter_cache_clear_source': cache_clear_source,
                'native_snapshots': {'before': before_receipt,
                                     'after': after_receipt,
                                     'final': final_receipt},
                'pid_inventory_before_count': len(before),
                'pid_inventory_after_count': len(after),
                'pid_inventory_final_recheck_count': len(final),
                'psutil_pid_inventory_count': len(pid_set),
                'psutil_iterator_pid_count': len(iter_set),
                **sentinel_counts,
                'windows_system_sentinel': {
                    'schema': 'vnext-t2-windows-native-sentinel-r1',
                    'before': before_receipt['pid4_identity'],
                    'after': after_receipt['pid4_identity'],
                    'final': final_receipt['pid4_identity'],
                    'idle_before': before_receipt['pid0_identity'],
                    'idle_after': after_receipt['pid0_identity'],
                    'idle_final': final_receipt['pid0_identity']},
                'protected_system_row_332': next(
                    (dict(row) for row in result_rows if row.get('pid') == 332), None),
                'membership_churn': churn,
                'same_pid_generation_drift': [],
                'raw_generation_values_are_exact': True}

    return {'schema': 'vnext-t2-process-table-snapshot-r4',
            'complete': False, 'attempts': attempt, 'rows': [],
            'errors': last_errors or [_monitor_error(
                'native_process_table_snapshot', RuntimeError(
                    'no stable exact native/psutil PID membership snapshot'))],
            'native_snapshots': last_tables,
            'same_pid_generation_drift': generation_drift,
            'pid0_sentinel_counts': last_tables.get(
                'pid0_sentinel_counts', dict(empty_counts)),
            'pid4_sentinel_counts': last_tables.get(
                'pid4_sentinel_counts', dict(empty_counts))}


def _descendant_rows(snapshot: dict[str, Any], root_pid: int
                     ) -> list[dict[str, Any]]:
    if not _valid_pid(root_pid):
        raise RuntimeError("invalid root PID for descendant traversal")
    by_parent: dict[int, list[dict[str, Any]]] = {}
    for row in snapshot.get("rows", []):
        if not isinstance(row, dict) or \
                not _valid_pid(row.get("pid")) or \
                not _valid_ppid(row.get("ppid")) or \
                not _valid_create_time(row.get("create_time")):
            raise RuntimeError("invalid process identity in descendant traversal")
        parent = row.get("ppid")
        by_parent.setdefault(parent, []).append(row)
    found: dict[tuple[int, float], dict[str, Any]] = {}
    stack = [root_pid]
    visited: set[int] = set()
    while stack:
        parent = stack.pop()
        if parent in visited:
            continue
        visited.add(parent)
        for row in by_parent.get(parent, []):
            key = (row["pid"], row["create_time"])
            found[key] = row
            stack.append(row["pid"])
    return sorted(found.values(), key=lambda row: (row["pid"],
                                                   row["create_time"]))


def _final_process_tree_audit(root_pid: int, root_create_time: float,
                              tracked_processes: list[dict[str, Any]], *,
                              root_exit_confirmed: bool) -> dict[str, Any]:
    snapshot = _process_table_snapshot()
    errors = list(snapshot.get("errors", []))
    root_identity_valid = _valid_pid(root_pid) and \
        _valid_create_time(root_create_time)
    if not root_identity_valid:
        errors.append(_monitor_error(
            "root_exit_identity_audit", RuntimeError(
                "invalid stage-root PID/create_time for final audit"),
            root_pid if _valid_pid(root_pid) else None))
    rows: dict[int, dict[str, Any]] = {}
    for row in snapshot.get("rows", []):
        if not isinstance(row, dict) or \
                not _valid_pid(row.get("pid")) or \
                not _valid_ppid(row.get("ppid")) or \
                not _valid_create_time(row.get("create_time")):
            errors.append(_monitor_error(
                "process_table_identity_audit", RuntimeError(
                    "invalid process-table identity in final audit")))
            continue
        pid = row["pid"]
        if pid in rows:
            errors.append(_monitor_error(
                "process_table_identity_audit", RuntimeError(
                    "duplicate PID in final process-table audit"), pid))
            continue
        rows[pid] = row
    try:
        descendants = _descendant_rows(snapshot, root_pid) \
            if root_identity_valid else []
    except Exception as error:
        descendants = []
        errors.append(_monitor_error("descendant_tree_audit", error,
                                     root_pid if _valid_pid(root_pid) else None))
    residual: dict[tuple[int, float], dict[str, Any]] = {
        (row["pid"], row["create_time"]): row for row in descendants}
    for identity in tracked_processes:
        pid = identity.get("pid") if isinstance(identity, dict) else None
        create_time = identity.get("create_time") \
            if isinstance(identity, dict) else None
        if not _valid_pid(pid) or not _valid_create_time(create_time):
            errors.append(_monitor_error(
                "tracked_process_identity_audit", RuntimeError(
                    "invalid tracked PID/create_time in final audit")))
            continue
        if root_identity_valid and pid == root_pid and \
                create_time == root_create_time:
            continue
        current = rows.get(pid)
        if current is not None and \
                _valid_create_time(current.get("create_time")) and \
                current.get("create_time") == create_time:
            residual[(pid, create_time)] = current
        elif current is not None:
            errors.append(_monitor_error(
                "tracked_process_identity_audit", RuntimeError(
                    "PID reused while auditing tracked process identity"), pid))
    root_row = rows.get(root_pid) if _valid_pid(root_pid) else None
    root_identity_absent = root_row is None
    if root_row is not None and (
            not root_identity_valid or
            not _valid_create_time(root_row.get("create_time")) or
            root_row.get("create_time") != root_create_time):
        errors.append(_monitor_error(
            "root_exit_identity_audit", RuntimeError(
                "stage-root PID was reused before final audit completed"),
            root_pid))
    if root_exit_confirmed and not root_identity_absent:
        errors.append(_monitor_error(
            "root_exit_identity_audit", RuntimeError(
                "root identity remains present after subprocess wait"), root_pid))
    if not root_exit_confirmed:
        errors.append(_monitor_error(
            "root_exit_identity_audit", RuntimeError(
                "subprocess root exit was not confirmed"), root_pid))
    return {"schema": "vnext-t2-final-process-tree-audit-r1",
            "complete": snapshot.get("complete") is True and not errors,
            "root_exit_confirmed": root_exit_confirmed,
            "root_identity_absent": root_identity_absent,
            "process_table_snapshot": {
                key: value for key, value in snapshot.items() if key != "rows"},
            "residual_process_audit": heavy_processes(snapshot),
            "tracked_identity_count": len(tracked_processes),
            "residual_descendant_processes": list(residual.values()),
            "errors": errors}


def _heavy_processes_legacy_r16(snapshot: dict[str, Any] | None = None) -> dict[str, Any]:
    snapshot = snapshot if snapshot is not None else _process_table_snapshot()
    rows = snapshot.get("rows", [])
    residual: list[dict[str, Any]] = []
    errors = list(snapshot.get("errors", []))
    for row in rows:
        if not isinstance(row, dict) or \
                not _valid_pid(row.get("pid")) or \
                not _valid_ppid(row.get("ppid")) or \
                not _valid_create_time(row.get("create_time")):
            errors.append(_monitor_error(
                "heavy_process_identity", RuntimeError(
                    "invalid PID/PPID/create_time in residual audit")))
            continue
        name_value = row.get("name", "")
        if not isinstance(name_value, str):
            errors.append(_monitor_error(
                "heavy_process_identity", RuntimeError(
                    "invalid process name in residual audit"), row["pid"]))
            continue
        name = name_value.lower()
        command = ""
        if row.get("pid") != os.getpid() and name.startswith("python"):
            try:
                process = psutil.Process(row["pid"])
                live_pid = process.pid
                live_create_time = process.create_time()
                if not _valid_pid(live_pid) or live_pid != row["pid"] or \
                        not _valid_create_time(live_create_time) or \
                        not _valid_create_time(row.get("create_time")):
                    errors.append(_monitor_error(
                        "heavy_process_identity", RuntimeError(
                            "invalid process identity during residual audit"),
                        row["pid"]))
                    continue
                if live_create_time != row["create_time"]:
                    errors.append(_monitor_error(
                        "heavy_process_identity", RuntimeError(
                            "PID reused during residual audit"), row["pid"]))
                    continue
                command = " ".join(process.cmdline())
            except Exception as error:
                errors.append(_monitor_error(
                    "heavy_process_command_line", error, row.get("pid")))
                continue
        command_lower = command.lower()
        if "julia" in name or "formal_t2_controller.py" in command_lower or \
                "independent_negative_controller_r" in command_lower:
            if row.get("pid") != os.getpid():
                residual.append({"pid": row["pid"], "name": row["name"],
                                 "command": command,
                                 "create_time": row["create_time"]})
    return {"schema": "vnext-t2-residual-process-audit-r1",
            "complete": snapshot.get("complete") is True and not errors,
            "processes": residual, "errors": errors,
            "snapshot": {key: value for key, value in snapshot.items()
                         if key != "rows"}}


def process_tree_sample(root_process: psutil.Process,
                        expected_root_create_time: float | None = None
                        ) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    root_pid = getattr(root_process, "pid", None)
    if not _valid_pid(root_pid):
        errors.append(_monitor_error(
            "root_identity_sample", RuntimeError("invalid stage-root PID")))
    if expected_root_create_time is None:
        try:
            expected_root_create_time = root_process.create_time()
        except Exception as error:
            expected_root_create_time = None
            errors.append(_monitor_error("root_identity_sample", error,
                                         root_pid if _valid_pid(root_pid) else None))
    expected_root_valid = _valid_create_time(expected_root_create_time)
    if not expected_root_valid:
        errors.append(_monitor_error(
            "root_identity_sample", RuntimeError(
                "invalid expected stage-root create_time"),
            root_pid if _valid_pid(root_pid) else None))
    try:
        observed_root_create_time = root_process.create_time()
        if not _valid_create_time(observed_root_create_time):
            errors.append(_monitor_error(
                "root_identity_sample", RuntimeError(
                    "invalid stage-root create_time during sample"),
                root_pid if _valid_pid(root_pid) else None))
        elif expected_root_valid and \
                observed_root_create_time != expected_root_create_time:
            errors.append(_monitor_error(
                "root_identity_sample", RuntimeError(
                    "stage-root identity changed or exited during sample"),
                root_pid if _valid_pid(root_pid) else None))
        if not root_process.is_running():
            errors.append(_monitor_error(
                "root_identity_sample", RuntimeError(
                    "stage-root exited during sample"),
                root_pid if _valid_pid(root_pid) else None))
    except Exception as error:
        errors.append(_monitor_error("root_identity_sample", error,
                                     root_pid if _valid_pid(root_pid) else None))
    enumerated_children: list[psutil.Process] = []
    try:
        enumerated_children = root_process.children(recursive=True)
        if not isinstance(enumerated_children, list):
            raise RuntimeError("recursive child enumeration is not a list")
    except Exception as error:
        errors.append(_monitor_error("children_enumeration", error,
                                     root_pid if _valid_pid(root_pid) else None))
        enumerated_children = []
    enumerated_identities: list[tuple[int, float]] = []
    for child in enumerated_children:
        try:
            child_pid = getattr(child, "pid", None)
            child_create_time = child.create_time()
            if not _valid_pid(child_pid) or \
                    not _valid_create_time(child_create_time):
                raise RuntimeError(
                    "invalid descendant PID/create_time during enumeration")
            enumerated_identities.append((child_pid, child_create_time))
        except Exception as error:
            errors.append(_monitor_error("child_identity_enumeration", error,
                                         getattr(child, "pid", None)))
    if len(enumerated_identities) != len(set(enumerated_identities)):
        errors.append(_monitor_error(
            "children_enumeration_identity", RuntimeError(
                "recursive child enumeration returned duplicate process identities"),
            root_pid if _valid_pid(root_pid) else None))
    processes = [root_process, *enumerated_children]
    rows: list[dict[str, Any]] = []
    total = 0
    total_user_cpu = 0.0
    total_system_cpu = 0.0
    seen: set[tuple[int, float]] = set()
    for process in processes:
        try:
            process_pid = getattr(process, "pid", None)
            create_time = process.create_time()
            if not _valid_pid(process_pid) or \
                    not _valid_create_time(create_time):
                raise RuntimeError("invalid PID/create_time in process sample")
            if _valid_pid(root_pid) and process_pid == root_pid and (
                    not expected_root_valid or
                    create_time != expected_root_create_time):
                raise RuntimeError("stage-root PID identity changed during sample")
            rss = process.memory_info().rss
            cpu = process.cpu_times()
            live_create_time = process.create_time()
            if not _valid_create_time(live_create_time):
                raise RuntimeError(
                    "invalid create_time during resource identity recheck")
            if live_create_time != create_time:
                raise RuntimeError("PID identity changed during resource sample")
            if not _valid_rss_bytes(rss) or \
                    not _valid_cpu_seconds(cpu.user) or \
                    not _valid_cpu_seconds(cpu.system):
                raise RuntimeError("invalid RSS or CPU measurement")
            identity = (process_pid, create_time)
            if identity in seen:
                errors.append(_monitor_error(
                    "duplicate_process_identity", RuntimeError(
                        "duplicate PID/create_time in process tree"),
                    process_pid))
                continue
            seen.add(identity)
            total += rss
            candidate_user_cpu = total_user_cpu + cpu.user
            candidate_system_cpu = total_system_cpu + cpu.system
            if not _valid_cpu_seconds(candidate_user_cpu) or \
                    not _valid_cpu_seconds(candidate_system_cpu):
                errors.append(_monitor_error(
                    "process_resource_sample", RuntimeError(
                        "nonfinite aggregate CPU measurement"), process_pid))
                continue
            total_user_cpu = candidate_user_cpu
            total_system_cpu = candidate_system_cpu
            rows.append({"pid": process_pid, "create_time": create_time,
                         "working_set_bytes": rss,
                         "user_cpu_seconds": cpu.user,
                         "system_cpu_seconds": cpu.system})
        except Exception as error:
            errors.append(_monitor_error("process_resource_sample", error,
                                         getattr(process, "pid", None)))
    root_matches = [row for row in rows
                    if _valid_pid(row.get("pid")) and
                    _valid_create_time(row.get("create_time")) and
                    _valid_pid(root_pid) and expected_root_valid and
                    row["pid"] == root_pid and
                    row["create_time"] == expected_root_create_time]
    if len(root_matches) != 1:
        errors.append(_monitor_error(
            "root_identity_sample", RuntimeError(
                "complete sample must contain exactly one stage-root PID/create_time"),
            root_pid if _valid_pid(root_pid) else None))
    try:
        final_root_create_time = root_process.create_time()
        root_identity_stable = expected_root_valid and \
            _valid_create_time(final_root_create_time) and \
            final_root_create_time == expected_root_create_time and \
            root_process.is_running()
        if not root_identity_stable:
            errors.append(_monitor_error(
                "root_identity_sample", RuntimeError(
                    "stage-root identity was invalid at sample completion"),
                root_pid if _valid_pid(root_pid) else None))
    except Exception as error:
        root_identity_stable = False
        errors.append(_monitor_error("root_identity_sample", error,
                                     root_pid if _valid_pid(root_pid) else None))
    complete = not errors and root_identity_stable and \
        len(rows) == len(processes) == 1 + len(enumerated_children) and \
        len(root_matches) == 1 and \
        expected_root_valid and _valid_pid(root_pid) and \
        set(seen) == {(root_pid, expected_root_create_time)} | \
        set(enumerated_identities)
    return {"schema": "vnext-t2-process-tree-sample-r1",
            "observed_utc": utc(), "sample_complete": complete,
            "root_process_identity": {
                "pid": root_pid if _valid_pid(root_pid) else None,
                "create_time": expected_root_create_time
                if expected_root_valid else None},
            "root_identity_match_count": len(root_matches),
            "subtree_enumeration_complete": not any(
                error["stage"] in {"children_enumeration",
                                   "child_identity_enumeration",
                                   "children_enumeration_identity"}
                for error in errors),
            "expected_descendant_count": len(enumerated_children),
            "enumerated_descendant_count": len(enumerated_identities),
            "expected_process_count": len(processes),
            "observed_process_count": len(rows), "errors": errors,
            "process_tree_working_set_bytes": total,
            "process_tree_user_cpu_seconds": total_user_cpu,
            "process_tree_system_cpu_seconds": total_system_cpu,
            "processes": rows}


def kill_tree(process: psutil.Process, expected_root_create_time: float,
              tracked_processes: list[dict[str, Any]], *,
              discovered_processes: list[dict[str, Any]] | None = None,
              root_exit_confirmed: bool = False) -> dict[str, Any]:
    """Kill known descendants and verify each captured identity is gone."""
    errors: list[dict[str, Any]] = []
    events: list[dict[str, Any]] = []
    targets: dict[tuple[int, float], psutil.Process] = {}
    identities: dict[tuple[int, float], dict[str, Any]] = {}
    root_pid = getattr(process, "pid", None)
    invalid_identities: list[dict[str, Any]] = []
    if not _valid_pid(root_pid) or not _valid_create_time(
            expected_root_create_time):
        invalid_identities.append({"identity": "stage_root",
                                   "pid": root_pid,
                                   "create_time": expected_root_create_time})
    for source_name, source in (("tracked", tracked_processes),
                                ("discovered", discovered_processes or [])):
        if not isinstance(source, list):
            invalid_identities.append({"identity": source_name,
                                       "reason": "not_a_list"})
            continue
        for index, identity in enumerate(source):
            pid = identity.get("pid") if isinstance(identity, dict) else None
            create_time = identity.get("create_time") \
                if isinstance(identity, dict) else None
            if not _valid_pid(pid) or not _valid_create_time(create_time):
                invalid_identities.append({
                    "identity": source_name, "index": index,
                    "pid": pid if _valid_pid(pid) else None,
                    "create_time": create_time
                    if _valid_create_time(create_time) else None})
    if invalid_identities:
        errors.append(_monitor_error(
            "termination_identity_validation", RuntimeError(
                "invalid PID/create_time rejected before target construction"),
            root_pid if _valid_pid(root_pid) else None))
        return {"schema": "vnext-t2-process-tree-termination-r1",
                "complete": False, "verified": False,
                "root_exit_confirmed": root_exit_confirmed,
                "enumeration_error_count": 0,
                "target_identity_count": 0, "signal_attempts": [],
                "events": events, "errors": errors,
                "invalid_identities": invalid_identities,
                "still_alive": []}
    snapshot = _process_table_snapshot()
    if snapshot.get("complete") is not True:
        errors.extend(snapshot.get("errors", []))
    snapshot_rows = []
    for row in snapshot.get("rows", []):
        if not isinstance(row, dict) or \
                not _valid_pid(row.get("pid")) or \
                not _valid_ppid(row.get("ppid")) or \
                not _valid_create_time(row.get("create_time")):
            errors.append(_monitor_error(
                "termination_snapshot_identity", RuntimeError(
                    "invalid process-table PID/PPID/create_time")))
            continue
        snapshot_rows.append(row)
    root_rows = [row for row in snapshot_rows
                 if _valid_pid(row.get("pid")) and row.get("pid") == root_pid]
    exact_root_rows = [row for row in root_rows
                       if _valid_create_time(row.get("create_time")) and
                       row.get("create_time") == expected_root_create_time]
    if root_exit_confirmed:
        if exact_root_rows:
            errors.append(_monitor_error(
                "termination_root_identity", RuntimeError(
                    "root identity remains after confirmed subprocess exit"),
                process.pid))
        elif root_rows:
            errors.append(_monitor_error(
                "termination_root_identity", RuntimeError(
                    "stage-root PID was reused during termination audit"),
                process.pid))
    elif len(exact_root_rows) != 1 or len(root_rows) != 1:
        errors.append(_monitor_error(
            "termination_root_identity", RuntimeError(
                "termination snapshot lacks the unique stage-root identity"),
            process.pid))
    try:
        snapshot_descendants = (
            _descendant_rows({"rows": snapshot_rows}, root_pid)
            if not root_exit_confirmed and len(exact_root_rows) == 1 else [])
    except Exception as error:
        snapshot_descendants = []
        errors.append(_monitor_error("termination_snapshot_subtree", error,
                                     root_pid))
    snapshot_child_ids = {(row["pid"], row["create_time"])
                          for row in snapshot_descendants}
    enumerated_child_ids: list[tuple[int, float]] = []
    try:
        children = process.children(recursive=True)
        for child in children:
            try:
                child_pid = getattr(child, "pid", None)
                create_time = child.create_time()
                if not _valid_pid(child_pid) or \
                        not _valid_create_time(create_time):
                    raise RuntimeError(
                        "invalid descendant PID/create_time before termination")
                key = (child_pid, create_time)
                targets[key] = child
                identities[key] = {"pid": child_pid,
                                   "create_time": create_time}
                enumerated_child_ids.append(key)
            except Exception as error:
                errors.append(_monitor_error(
                    "termination_child_identity", error,
                    getattr(child, "pid", None)))
    except psutil.NoSuchProcess as error:
        if root_exit_confirmed:
            events.append({"stage": "children_enumeration",
                           "outcome": "root_already_exited",
                           "exception_type": type(error).__name__})
        else:
            errors.append(_monitor_error("termination_children_enumeration",
                                         error, process.pid))
    except Exception as error:
        errors.append(_monitor_error("termination_children_enumeration",
                                     error, process.pid))
    else:
        if not root_exit_confirmed and \
                (len(enumerated_child_ids) != len(set(enumerated_child_ids)) or
                 set(enumerated_child_ids) != snapshot_child_ids):
            errors.append(_monitor_error(
                "termination_children_crosscheck", RuntimeError(
                    "child enumeration differs from process-table subtree"),
                process.pid))
        for row in snapshot_descendants:
            key = (row["pid"], row["create_time"])
            if key in identities:
                continue
            try:
                candidate = psutil.Process(row["pid"])
                candidate_pid = getattr(candidate, "pid", None)
                candidate_create_time = candidate.create_time()
                if not _valid_pid(candidate_pid) or \
                        candidate_pid != row["pid"] or \
                        not _valid_create_time(candidate_create_time) or \
                        not _valid_create_time(row.get("create_time")):
                    errors.append(_monitor_error(
                        "termination_pid_identity_check", RuntimeError(
                            "invalid PID/create_time before termination signal"),
                        row["pid"]))
                    continue
                if candidate_create_time != row["create_time"]:
                    errors.append(_monitor_error(
                        "termination_pid_identity_check", RuntimeError(
                            "PID reused before termination signal"), row["pid"]))
                    continue
                targets[key] = candidate
                identities[key] = {"pid": row["pid"],
                                    "create_time": row["create_time"]}
            except Exception as error:
                errors.append(_monitor_error(
                    "termination_snapshot_target", error, row["pid"]))
    for identity in [*tracked_processes, *(discovered_processes or [])]:
        pid, create_time = identity.get("pid"), identity.get("create_time")
        if not _valid_pid(pid) or not _valid_create_time(create_time):
            errors.append(_monitor_error(
                "termination_tracked_identity", RuntimeError(
                    "invalid tracked PID/create_time")))
            continue
        key = (pid, create_time)
        if key not in identities:
            try:
                candidate = psutil.Process(pid)
                candidate_pid = getattr(candidate, "pid", None)
                current_create_time = candidate.create_time()
                if not _valid_pid(candidate_pid) or candidate_pid != pid or \
                        not _valid_create_time(current_create_time):
                    errors.append(_monitor_error(
                        "termination_tracked_identity", RuntimeError(
                            "invalid live PID/create_time for tracked target"),
                        pid))
                    continue
                if current_create_time != create_time:
                    errors.append(_monitor_error(
                        "termination_tracked_identity", RuntimeError(
                            "PID reused while resolving tracked process"), pid))
                    continue
                targets[key] = candidate
                identities[key] = {"pid": pid,
                                   "create_time": create_time}
            except psutil.NoSuchProcess:
                events.append({"stage": "tracked_identity", "pid": pid,
                               "outcome": "already_exited"})
            except Exception as error:
                errors.append(_monitor_error("termination_tracked_identity",
                                             error, pid))
    root_key = (process.pid, expected_root_create_time)
    if root_key not in identities:
        try:
            live_root_pid = getattr(process, "pid", None)
            live_root_create_time = process.create_time()
            if not _valid_pid(live_root_pid) or live_root_pid != root_pid or \
                    not _valid_create_time(live_root_create_time):
                errors.append(_monitor_error(
                    "termination_root_identity", RuntimeError(
                        "invalid live root PID/create_time before kill"),
                    root_pid))
            elif live_root_create_time != expected_root_create_time:
                errors.append(_monitor_error(
                    "termination_root_identity", RuntimeError(
                        "root PID identity changed"), process.pid))
            else:
                identities[root_key] = {"pid": process.pid,
                                        "create_time": expected_root_create_time}
                targets[root_key] = process
        except psutil.NoSuchProcess:
            if root_exit_confirmed:
                events.append({"stage": "termination_root_identity",
                               "pid": process.pid,
                               "outcome": "root_already_exited"})
            else:
                errors.append(_monitor_error(
                    "termination_root_identity", RuntimeError(
                        "root disappeared before exit was confirmed"),
                    process.pid))
        except Exception as error:
            errors.append(_monitor_error("termination_root_identity", error,
                                         process.pid))
    signal_attempts: list[dict[str, Any]] = []
    ordered = sorted(targets.items(), key=lambda item: item[0] == root_key)
    for key, target in ordered:
        pid, create_time = key
        try:
            target_pid = getattr(target, "pid", None)
            target_create_time = target.create_time()
            if not _valid_pid(target_pid) or target_pid != pid or \
                    not _valid_create_time(target_create_time) or \
                    not _valid_create_time(create_time):
                errors.append(_monitor_error(
                    "termination_pid_identity_check", RuntimeError(
                        "invalid PID/create_time before kill signal"), pid))
                continue
            if target_create_time != create_time:
                errors.append(_monitor_error(
                    "termination_pid_identity_check", RuntimeError(
                        "PID identity changed before kill"), pid))
                continue
            target.kill()
            signal_attempts.append({"pid": pid, "create_time": create_time,
                                    "outcome": "kill_requested"})
        except psutil.NoSuchProcess:
            signal_attempts.append({"pid": pid, "create_time": create_time,
                                    "outcome": "already_exited_before_kill"})
        except Exception as error:
            errors.append(_monitor_error("termination_kill", error, pid))
            signal_attempts.append({"pid": pid, "create_time": create_time,
                                    "outcome": "kill_failed"})
    try:
        gone, alive = psutil.wait_procs(list(targets.values()), timeout=5)
        for target in gone:
            events.append({"stage": "termination_wait", "pid": target.pid,
                           "outcome": "exited"})
        for target in alive:
            errors.append(_monitor_error(
                "termination_wait", RuntimeError("process remained alive"),
                target.pid))
    except Exception as error:
        errors.append(_monitor_error("termination_wait", error))
    still_alive: list[dict[str, Any]] = []
    for key, identity in identities.items():
        pid, create_time = key
        try:
            current = psutil.Process(pid)
            current_pid = getattr(current, "pid", None)
            current_create_time = current.create_time()
            if not _valid_pid(current_pid) or current_pid != pid or \
                    not _valid_create_time(current_create_time) or \
                    not _valid_create_time(create_time):
                errors.append(_monitor_error(
                    "termination_final_identity", RuntimeError(
                        "invalid live identity during final termination audit"),
                    pid))
            elif current_create_time == create_time and current.is_running():
                still_alive.append(identity)
            elif current_create_time == create_time:
                events.append({"stage": "termination_final_identity",
                               "pid": pid,
                               "outcome": "confirmed_not_running"})
            elif current_create_time != create_time:
                errors.append(_monitor_error(
                    "termination_final_identity", RuntimeError(
                        "PID reused before final termination audit"), pid))
        except psutil.NoSuchProcess:
            events.append({"stage": "termination_final_identity", "pid": pid,
                           "outcome": "confirmed_absent"})
        except psutil.ZombieProcess as error:
            errors.append(_monitor_error("termination_final_identity",
                                         error, pid))
        except Exception as error:
            errors.append(_monitor_error("termination_final_identity",
                                         error, pid))
    complete = snapshot.get("complete") is True and \
        not errors and not still_alive and \
        (root_exit_confirmed or root_key not in targets or
         any(event.get("outcome") in {
                 "confirmed_absent", "confirmed_not_running"} and
             _valid_pid(event.get("pid")) and
             _valid_pid(process.pid) and
             event.get("pid") == process.pid for event in events))
    return {"schema": "vnext-t2-process-tree-termination-r1",
            "complete": complete, "verified": complete,
            "root_exit_confirmed": root_exit_confirmed,
            "enumeration_error_count": sum(
                error["stage"] == "termination_children_enumeration"
                for error in errors),
            "target_identity_count": len(identities),
            "signal_attempts": signal_attempts,
            "events": events, "errors": errors,
            "still_alive": still_alive}


def _run_phase_legacy_r16(name: str, command: list[str], output: Path, *,
              timeout_seconds: float, working_set_limit_bytes: int,
              environment: dict[str, str], precreated: bool = False) -> dict[str, Any]:
    if precreated:
        if not output.is_dir():
            raise RuntimeError(f"precreated phase directory absent: {output}")
    else:
        output.mkdir(parents=True, exist_ok=False)
    started_utc = utc()
    started = time.monotonic()
    child_started = time.monotonic()
    stop_reason = "natural_exit"
    samples: list[dict[str, Any]] = []
    tracked_processes: dict[tuple[int, float], dict[str, Any]] = {}
    termination_receipt: dict[str, Any] | None = None
    final_tree_audit: dict[str, Any] | None = None
    residual_audit: dict[str, Any] | None = None
    exit_code: int | None = None
    launch_create_time: float | None = None
    launch_identity_error: dict[str, Any] | None = None
    launch_identity_receipt: dict[str, Any]
    with (output / "stdout.raw").open("xb") as stdout, \
            (output / "stderr.raw").open("xb") as stderr:
        process = psutil.Popen(
            command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        observed_lookup: psutil.Process | None = None
        lookup_pid: int | None = None
        lookup_create_time: float | None = None
        try:
            launch_create_time = process.create_time()
            observed_lookup = psutil.Process(process.pid)
            lookup_pid = observed_lookup.pid
            lookup_create_time = observed_lookup.create_time()
            launch_identity_receipt = _bind_launch_root_identity(
                process, observed_lookup)
        except Exception as error:
            launch_identity_error = _monitor_error(
                "launch_root_identity", error, process.pid)
            launch_identity_receipt = {
                "schema": "vnext-t2-launch-root-identity-r1",
                "complete": False, "pid": process.pid,
                "create_time": launch_create_time,
                "looked_up_pid": lookup_pid,
                "looked_up_create_time": lookup_create_time,
                "error": launch_identity_error,
            }
            stop_reason = "process_tree_monitor_incomplete"
        create_time = launch_create_time
        observed = process
        samples_path = output / "samples.jsonl"
        with samples_path.open(
                "x", encoding="utf-8", newline="\n", buffering=1) as sample_file:
            while launch_identity_error is None and process.poll() is None:
                try:
                    observed_pid = getattr(observed, "pid", None)
                    observed_create_time = observed.create_time()
                    if not _valid_pid(observed_pid) or \
                            observed_pid != process.pid or \
                            not _valid_create_time(observed_create_time) or \
                            not _valid_create_time(create_time) or \
                            observed_create_time != create_time:
                        stop_reason = "pid_ownership_invalid"
                        break
                    sample = process_tree_sample(process, create_time)
                    samples.append(sample)
                    sample_file.write(json.dumps(sample, sort_keys=True) + "\n")
                    for row in sample["processes"]:
                        tracked_processes[(row["pid"], row["create_time"])] = {
                            "pid": row["pid"],
                            "create_time": row["create_time"]}
                    if sample.get("sample_complete") is not True:
                        stop_reason = "process_tree_monitor_incomplete"
                        break
                    if sample["process_tree_working_set_bytes"] >= \
                            working_set_limit_bytes:
                        stop_reason = "process_tree_working_set_hard_ceiling"
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "phase_wall_timeout"
                        break
                except Exception as error:
                    stop_reason = "process_tree_monitor_incomplete"
                    samples.append({"schema": "vnext-t2-process-tree-sample-r1",
                                    "observed_utc": utc(),
                                    "sample_complete": False,
                                    "expected_process_count": None,
                                    "observed_process_count": 0,
                                    "errors": [_monitor_error(
                                        "sample_loop", error, process.pid)],
                                    "process_tree_working_set_bytes": 0,
                                    "process_tree_user_cpu_seconds": 0.0,
                                    "process_tree_system_cpu_seconds": 0.0,
                                    "processes": []})
                    break
                time.sleep(0.2)
            if launch_identity_error is not None:
                failed_sample = {
                    "schema": "vnext-t2-process-tree-sample-r1",
                    "observed_utc": utc(), "sample_complete": False,
                    "root_process_identity": {
                        "pid": process.pid,
                        "create_time": launch_create_time},
                    "root_identity_match_count": 0,
                    "expected_process_count": None,
                    "observed_process_count": 0,
                    "errors": [launch_identity_error],
                    "process_tree_working_set_bytes": 0,
                    "process_tree_user_cpu_seconds": 0.0,
                    "process_tree_system_cpu_seconds": 0.0,
                    "processes": [],
                }
                samples.append(failed_sample)
                sample_file.write(json.dumps(failed_sample, sort_keys=True) + "\n")
                termination_receipt = _terminate_unbound_launch(
                    process, launch_create_time, launch_identity_error)
                try:
                    exit_code = process.wait(timeout=8)
                except subprocess.TimeoutExpired as error:
                    termination_receipt["errors"].append(_monitor_error(
                        "subprocess_wait", error, process.pid))
                    stop_reason = "termination_unverified"
            elif process.poll() is None and stop_reason != "natural_exit":
                termination_receipt = kill_tree(
                    process, create_time, list(tracked_processes.values()))
                try:
                    exit_code = process.wait(timeout=8)
                except subprocess.TimeoutExpired:
                    retry_receipt = kill_tree(
                        process, create_time, list(tracked_processes.values()))
                    termination_receipt["retry_receipts"] = [retry_receipt]
                    try:
                        exit_code = process.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        termination_receipt["verified"] = False
                        termination_receipt["complete"] = False
                        termination_receipt["errors"].append(_monitor_error(
                            "subprocess_wait", TimeoutError(
                                "root process remained alive after two tree kills"),
                            process.pid))
                        stop_reason = "termination_unverified"
            else:
                exit_code = process.wait()
    child_finished = time.monotonic()
    root_exit_confirmed = exit_code is not None and process.poll() is not None
    if launch_identity_error is not None:
        final_tree_audit = {
            "schema": "vnext-t2-final-process-tree-audit-r1",
            "complete": False, "root_exit_confirmed": root_exit_confirmed,
            "root_identity_absent": False,
            "residual_descendant_processes": [],
            "errors": [launch_identity_error],
            "residual_process_audit": {
                "schema": "vnext-t2-residual-process-audit-r1",
                "complete": False, "processes": [],
                "errors": [launch_identity_error],
            },
        }
    else:
        final_tree_audit = _final_process_tree_audit(
            process.pid, create_time, list(tracked_processes.values()),
            root_exit_confirmed=root_exit_confirmed)
    if final_tree_audit.get("complete") is not True:
        stop_reason = "process_tree_monitor_incomplete"
    elif final_tree_audit.get("residual_descendant_processes"):
        stop_reason = "residual_descendant_processes_present"
        termination_receipt = kill_tree(
            observed, create_time, list(tracked_processes.values()),
            discovered_processes=final_tree_audit[
                "residual_descendant_processes"],
            root_exit_confirmed=root_exit_confirmed)
        final_tree_audit = _final_process_tree_audit(
            process.pid, create_time, list(tracked_processes.values()),
            root_exit_confirmed=root_exit_confirmed)
    residual_audit = final_tree_audit.get("residual_process_audit") \
        if isinstance(final_tree_audit, dict) else None
    if not isinstance(residual_audit, dict):
        residual_audit = {
            "schema": "vnext-t2-residual-process-audit-r1",
            "complete": False, "processes": [],
            "errors": [_monitor_error(
                "residual_process_audit", RuntimeError(
                    "final process-tree snapshot was unavailable"))],
        }
    if residual_audit.get("complete") is not True:
        stop_reason = "residual_process_audit_incomplete"
    elif residual_audit.get("processes"):
        stop_reason = "residual_heavy_processes_present"
    residual_descendants = final_tree_audit.get(
        "residual_descendant_processes", [])
    if residual_descendants:
        stop_reason = "residual_descendant_processes_present"
    if termination_receipt is not None:
        termination_receipt["root_exit_confirmed"] = root_exit_confirmed
        termination_receipt["verified"] = root_exit_confirmed and \
            not termination_receipt.get("errors") and \
            not termination_receipt.get("still_alive") and \
            final_tree_audit.get("complete") is True and \
            not final_tree_audit.get("residual_descendant_processes")
        termination_receipt["complete"] = termination_receipt["verified"]
    if termination_receipt is not None and \
            termination_receipt.get("verified") is not True:
        stop_reason = "termination_unverified"
    samples_log_receipt = file_receipt(samples_path)
    samples_log_receipt["path"] = str(samples_path.resolve())
    phase = {
        "schema": "vnext-t2-independent-negative-phase-r5",
        "name": name, "command": command, "cwd": str(ROOT),
        "pid": process.pid, "process_create_time": create_time,
        "started_utc": started_utc, "ended_utc": utc(),
        "seconds": child_finished - child_started,
        "total_supervision_seconds": time.monotonic() - started,
        "exit_code": exit_code, "stop_reason": stop_reason,
        "timeout_seconds": timeout_seconds,
        "root_launch_identity": launch_identity_receipt,
        "working_set_limit_bytes": working_set_limit_bytes,
        "process_tree_sample_count": len(samples),
        "process_tree_samples_complete": bool(samples) and all(
            row.get("sample_complete") is True for row in samples),
        "tracked_process_identity_count": len(tracked_processes),
        "termination_receipt": termination_receipt,
        "final_process_tree_audit": final_tree_audit,
        "residual_process_audit": residual_audit,
        "peak_process_tree_working_set_bytes": max(
            (row["process_tree_working_set_bytes"] for row in samples),
            default=0),
        "final_sample_process_tree_user_cpu_seconds":
            samples[-1]["process_tree_user_cpu_seconds"] if samples else 0.0,
        "final_sample_process_tree_system_cpu_seconds":
            samples[-1]["process_tree_system_cpu_seconds"] if samples else 0.0,
        "stdout": file_receipt(output / "stdout.raw"),
        "stderr": file_receipt(output / "stderr.raw"),
        "residual_heavy_processes": residual_audit.get("processes", [])
            if residual_audit else [],
        "actual_model_attestation": "unavailable",
    }
    write_json_new(output / "phase.json", phase)
    return phase


def _require_natural_legacy_r16(phase: dict[str, Any], *, exit_zero: bool) -> None:
    launch_identity = phase.get("root_launch_identity")
    phase_pid = phase.get("pid")
    phase_create_time = phase.get("process_create_time")
    if not isinstance(launch_identity, dict) or \
            not _valid_pid(phase_pid) or \
            not _valid_create_time(phase_create_time) or \
            not _valid_pid(launch_identity.get("pid")) or \
            not _valid_create_time(launch_identity.get("create_time")) or \
            not _valid_pid(launch_identity.get("looked_up_pid")) or \
            not _valid_create_time(
                launch_identity.get("looked_up_create_time")) or \
            launch_identity.get("complete") is not True or \
            launch_identity.get("pid") != phase_pid or \
            launch_identity.get("create_time") != phase_create_time or \
            launch_identity.get("looked_up_pid") != phase_pid or \
            launch_identity.get("looked_up_create_time") != phase_create_time:
        raise RuntimeError(
            f"{phase['name']} process_tree_monitor_incomplete: launch identity")
    if phase.get("process_tree_samples_complete") is not True or \
            phase.get("process_tree_sample_count", 0) <= 0:
        raise RuntimeError(
            f"{phase['name']} process_tree_monitor_incomplete: samples")
    tree_audit = phase.get("final_process_tree_audit")
    if not isinstance(tree_audit, dict) or \
            tree_audit.get("complete") is not True or \
            tree_audit.get("root_exit_confirmed") is not True or \
            tree_audit.get("residual_descendant_processes"):
        raise RuntimeError(
            f"{phase['name']} process_tree_monitor_incomplete: final audit")
    termination = phase.get("termination_receipt")
    if termination is not None and termination.get("verified") is not True:
        raise RuntimeError(f"{phase['name']} termination_unverified")
    residual_audit = phase.get("residual_process_audit")
    if not isinstance(residual_audit, dict) or \
            residual_audit.get("complete") is not True or \
            residual_audit.get("processes"):
        raise RuntimeError(
            f"{phase['name']} residual_process_audit_incomplete")
    if phase["stop_reason"] != "natural_exit":
        raise RuntimeError(f"{phase['name']} stop={phase['stop_reason']}")
    if exit_zero and phase["exit_code"] != 0:
        raise RuntimeError(f"{phase['name']} exit={phase['exit_code']}")
    if not exit_zero and phase["exit_code"] == 0:
        raise RuntimeError(f"{phase['name']} unexpectedly exited zero")
    if phase["residual_heavy_processes"]:
        raise RuntimeError(
            f"{phase['name']} left residual processes: " +
            json.dumps(phase["residual_heavy_processes"], sort_keys=True))


def verify_protocol(path: Path, expected_sha256: str) -> dict[str, Any]:
    sources = _source_inputs()
    protocol_bytes = sources.read_bytes(path)
    if sha256_bytes(protocol_bytes) != expected_sha256.lower():
        raise RuntimeError("negative protocol SHA-256 mismatch")
    protocol = json.loads(protocol_bytes.decode("utf-8"))
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r10":
        raise RuntimeError("negative protocol schema mismatch")
    if protocol.get("repository_head") != EXPECTED_HEAD:
        raise RuntimeError("negative protocol HEAD mismatch")
    if protocol.get("controller_path") != R23_CONTROLLER_RELATIVE_PATH:
        raise RuntimeError("negative protocol does not bind the R23 controller path")
    controller_input = protocol.get("inputs", {}).get(
        R23_CONTROLLER_RELATIVE_PATH)
    controller_path = ROOT / R23_CONTROLLER_RELATIVE_PATH
    sources.require_local_execution(controller_path)
    sources.require_local_execution(Path(__file__))
    controller_actual = sources.receipt(controller_path)
    if not isinstance(controller_input, dict) or \
            controller_input.get("bytes") != controller_actual["bytes"] or \
            controller_input.get("sha256") != controller_actual["sha256"]:
        raise RuntimeError("negative protocol does not pin current R23 controller bytes")
    if Path(__file__).resolve() != controller_path.resolve():
        raise RuntimeError("current formal consumer is not the pinned R23 controller")
    sources.verify_protocol_layout(protocol)
    for relative, expected in protocol["inputs"].items():
        current = sources.protocol_input_receipt(protocol, ROOT / relative)
        if current["bytes"] != expected["bytes"] or \
                current["sha256"] != expected["sha256"]:
            raise RuntimeError(f"negative protocol input drift: {relative}")
    return protocol


def verify_runtime_plan(protocol: dict[str, Any]) -> dict[str, Any]:
    plan = protocol.get("runtime_execution_plan")
    if not isinstance(plan, dict):
        raise RuntimeError("negative protocol runtime plan absent")
    unique = plan.get("expected_unique_case_ids")
    counts = plan.get("expected_runtime_case_hit_counts")
    if not isinstance(unique, list) or len(unique) != len(set(unique)) or \
            not isinstance(counts, dict) or set(unique) != set(counts):
        raise RuntimeError("negative runtime case inventory invalid")
    if plan.get("expected_unique_case_count") != len(unique) or \
            plan.get("expected_runtime_case_hit_count") != sum(counts.values()):
        raise RuntimeError("negative runtime case totals invalid")
    actual = plan.get("actual_formal_summary_case_ids")
    observations = plan.get("actual_formal_observation_ids")
    if not isinstance(actual, list) or len(actual) != len(set(actual)) or \
            not isinstance(observations, list) or \
            len(observations) != len(actual) + 3:
        raise RuntimeError("actual-formal runtime inventory invalid")
    phase_cases = plan.get("actual_formal_phase_case_ids")
    phase_observations = plan.get("actual_formal_phase_observation_ids")
    expected_phases = ["actual_formal_baseline", "actual_formal_preflight",
                       "actual_formal_authority", "actual_formal_fault_n10",
                       "actual_formal_t1_handoff"]
    if not isinstance(phase_cases, dict) or \
            set(phase_cases) != set(expected_phases) or \
            [case for phase in expected_phases
             for case in phase_cases[phase]] != actual or \
            not isinstance(phase_observations, dict) or \
            set(phase_observations) != set(expected_phases) or \
            [case for phase in expected_phases
             for case in phase_observations[phase]] != observations or \
            plan.get("baseline_five_consumer_execution_count") != 1 or \
            plan.get("context_transport_validation_execution_count") != 4:
        raise RuntimeError("actual-formal shard inventory invalid")
    return plan


def verify_coverage_runtime_plan(protocol: dict[str, Any],
                                coverage: dict[str, Any]) -> dict[str, Any]:
    """Bind the executable case plan to the independently frozen coverage map."""
    mapped = coverage.get("runtime_execution_plan")
    protocol_plan = protocol.get("runtime_execution_plan")
    if not isinstance(mapped, dict) or not isinstance(protocol_plan, dict) or \
            protocol_plan != mapped:
        raise RuntimeError("negative runtime plan differs from frozen coverage map")
    verify_runtime_plan(protocol)
    return mapped


def verify_frozen_coverage_map_counts(
        coverage: dict[str, Any], runtime_plan: dict[str, Any]) -> None:
    """Enforce the frozen coverage counts on the production controller path."""
    hit_plan = coverage.get("successor_assertion_runtime_hit_plan")
    if coverage.get("schema") != \
            "vnext-t2-independent-negative-coverage-map-r16" or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622 or \
            not isinstance(hit_plan, dict) or \
            hit_plan.get("assertion_site_count") != 214 or \
            hit_plan.get("expected_runtime_hit_count") != 622 or \
            coverage.get("preserved_successor_assertion_site_count") != 191 or \
            coverage.get("preserved_successor_expected_runtime_hit_count") != 530 or \
            runtime_plan.get("expected_unique_case_count") != 60 or \
            runtime_plan.get("expected_runtime_case_hit_count") != 68 or \
            len(runtime_plan.get("actual_formal_summary_case_ids", [])) != 45:
        raise RuntimeError("negative coverage-map schema/preserved coverage mismatch")


def valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(
        character in "0123456789abcdef" for character in value)


def verify_ast_inventory(path: Path, coverage: dict[str, Any]) -> dict[str, Any]:
    value = load_json(path)
    plan = coverage.get("ast_inventory_plan")
    if not isinstance(plan, dict) or value.get("schema") != \
            "vnext-t2-independent-negative-ast-inventory-r3" or \
            value.get("status") != "pass" or \
            value.get("plan_schema") != plan.get("schema"):
        raise RuntimeError("AST inventory schema/status mismatch")
    expected_counts = {
        "old_assertion_site_count": coverage["old_assertion_site_count"],
        "successor_assertion_site_count":
            coverage["successor_assertion_site_count"],
        "projection_assertion_site_count": coverage[
            "versioned_product_repair_regression"]["assertion_site_count"],
        "total_assertion_site_count":
            coverage["ast_inventory_plan"]["total_assertion_site_count"],
    }
    for field, expected in expected_counts.items():
        if value.get(field) != expected or plan.get(field) != expected:
            raise RuntimeError(f"AST inventory count mismatch: {field}")
    if value.get("source_count") != plan.get("source_count") or \
            value.get("line_number_nodes_removed_only_from_semantic_hash") \
            is not True or value.get("context_fields") != \
            ["testset_path", "function_path", "control_context",
             "site_ast_path"]:
        raise RuntimeError("AST inventory transform/context mismatch")
    observed_sources = value.get("source_receipts")
    expected_sources = plan.get("sources")
    if not isinstance(observed_sources, list) or \
            len(observed_sources) != len(expected_sources):
        raise RuntimeError("AST inventory source receipt count mismatch")
    for observed, expected in zip(observed_sources, expected_sources):
        for field in ("role", "path", "bytes", "sha256",
                      "assertion_site_count"):
            if observed.get(field) != expected.get(field):
                raise RuntimeError(
                    f"AST inventory source mismatch: {expected.get('path')}:{field}")

    expected_rows = [*coverage["old_assertion_sites"],
                     *coverage["successor_assertion_sites"],
                     *coverage["versioned_product_repair_regression"][
                         "assertion_sites"]]
    rows = value.get("rows")
    if not isinstance(rows, list) or len(rows) != len(expected_rows):
        raise RuntimeError("AST inventory row count mismatch")
    for observed, expected in zip(rows, expected_rows):
        for field in ("site_id", "source_path", "line", "macro_name",
                      "source_text_sha256"):
            expected_value = expected["id"] if field == "site_id" else \
                expected["path"] if field == "source_path" else \
                expected[field]
            if observed.get(field) != expected_value:
                raise RuntimeError(
                    f"AST inventory row mismatch: {expected['id']}:{field}")
        if not valid_sha256(observed.get("expression_hash")) or \
                not valid_sha256(observed.get("semantic_expression_hash")):
            raise RuntimeError(f"AST inventory digest invalid: {expected['id']}")
        for field in ("testset_path", "function_path", "control_context",
                      "site_ast_path"):
            if not isinstance(observed.get(field), list):
                raise RuntimeError(
                    f"AST inventory context absent: {expected['id']}:{field}")
        for context in observed["control_context"]:
            if not isinstance(context, dict) or \
                    context.get("head") not in \
                    ("for", "while", "if", "try", "let") or \
                    not isinstance(context.get("ast_path"), list) or \
                    not all(isinstance(index, int) and index >= 1
                            for index in context.get("ast_path", [])) or \
                    not isinstance(context.get("child_index"), int) or \
                    context.get("child_index") != (
                        context["ast_path"][-1]
                        if context["ast_path"] else 0) or \
                    not valid_sha256(context.get("raw_context_hash")) or \
                    not valid_sha256(context.get("semantic_context_hash")):
                raise RuntimeError(
                    f"AST control context invalid: {expected['id']}")
        if not observed["site_ast_path"] or not all(
                isinstance(index, int) and index >= 1
                for index in observed["site_ast_path"]):
            raise RuntimeError(f"AST site path invalid: {expected['id']}")
    return value


def verify_projection_observation(path: Path, stdout_path: Path) -> dict[str, Any]:
    value = load_json(path)
    if value.get("schema") != \
            "vnext-t2-package-full-content-projection-actual-r1" or \
            value.get("suite") != \
            "vnext-t2-package-full-content-projection-r1" or \
            value.get("status") != "actual_observed" or \
            value.get("classification") != "supplemental_product_regression" or \
            value.get("recorded_before_assertions") is not True or \
            value.get("planned_test_sites") != 24 or \
            value.get("assertion_sites_completed") != 0 or \
            value.get("formal_t2_accepted") is not False:
        raise RuntimeError("projection observation schema/status mismatch")
    groups = value.get("groups")
    expected_groups = {
        "reload_content_equivalence": 8,
        "wire_byte_tamper_detection": 7,
        "source_byte_tamper_detection": 7,
        "admission_envelope_projection": 2,
    }
    if not isinstance(groups, dict) or set(groups) != set(expected_groups):
        raise RuntimeError("projection observation group inventory mismatch")
    for name, sites in expected_groups.items():
        row = groups[name]
        if row.get("planned_sites") != sites or \
                row.get("observed_values") != sites:
            raise RuntimeError(f"projection group count mismatch: {name}")
    reload = groups["reload_content_equivalence"]
    if reload.get("original_validation") != "none" or \
            reload.get("reloaded_validation") != "none" or \
            reload.get("package_content_equal") is not True or \
            reload.get("content_hash_equal") is not True or \
            reload.get("projection_domain") != \
            "vnext-t2-t1-package-full-content-projection-v2" or \
            reload.get("projection_key_count") != 20 or \
            reload.get("wire_base64_equal") is not True or \
            reload.get("wire_length_equal") is not True:
        raise RuntimeError("projection reload/content observation mismatch")
    for name in ("wire_byte_tamper_detection",
                 "source_byte_tamper_detection"):
        row = groups[name]
        if row.get("stored_package_hash_retained") is not True or \
                row.get("stored_semantic_identity_retained") is not True or \
                row.get("full_content_equal") is not False or \
                row.get("full_content_hash_changed") is not True or \
                row.get("build_status") != "fail_closed" or \
                row.get("build_reason") != \
                "t2_preflight_t1_reloaded_package_mismatch" or \
                row.get("attempted_events") != 0 or \
                row.get("zero_attempted_counts") is not True or \
                not counts_are(row.get("attempted_counts"),
                               (0, 0, 0, 0, 0, 0, 0, 0)):
            raise RuntimeError(f"projection tamper observation mismatch: {name}")
    admission = groups["admission_envelope_projection"]
    if admission.get("projection_domain") != \
            "vnext-t2-t1-admission-full-content-projection-v2" or \
            admission.get("package_projection_full_content_equal") is not True or \
            admission.get("package_projection_hash_equal_observation") is not True:
        raise RuntimeError("admission projection observation mismatch")
    for name in ("original_content_hash", "reloaded_content_hash",
                 "wire_tampered_content_hash", "source_tampered_content_hash"):
        if not valid_sha256(value.get(name)):
            raise RuntimeError(f"projection observation digest invalid: {name}")
    stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
    marker = ("VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4 "
              "classification=supplemental_product_regression "
              "formal_t2_accepted=false")
    if marker not in stdout:
        raise RuntimeError("projection post-assertion PASS marker absent")
    return value


def input_receipts(protocol: dict[str, Any]) -> dict[str, Any]:
    sources = _source_inputs()
    sources.verify_protocol_layout(protocol)
    rows = {}
    for relative in sorted(protocol["inputs"]):
        row = sources.protocol_input_receipt(protocol, ROOT / relative)
        # Existing runtime receipts use absolute paths; retain that wire
        # format while the protocol keeps its original logical input keys.
        rows[relative] = {"path": str(ROOT / relative),
                          "bytes": row["bytes"], "sha256": row["sha256"]}
    return rows


def canonical_input_pins(value: Any, label: str) -> dict[str, dict[str, Any]]:
    if not isinstance(value, dict):
        raise RuntimeError(f"{label} is not a path-keyed pin object")
    normalized: dict[str, dict[str, Any]] = {}
    for relative, row in value.items():
        if not isinstance(relative, str) or not isinstance(row, dict) or \
                row.get("path") != relative or \
                not isinstance(row.get("bytes"), int) or \
                row["bytes"] < 0 or not valid_sha256(row.get("sha256")):
            raise RuntimeError(f"{label} pin is malformed: {relative}")
        normalized[relative] = {
            "path": relative, "bytes": row["bytes"],
            "sha256": row["sha256"].lower(),
        }
    return normalized


def verify_positive_reuse_input_pins(protocol: dict[str, Any]) -> dict[str, Any]:
    dispatch = protocol.get("positive_dispatch")
    if not isinstance(dispatch, dict) or not isinstance(dispatch.get("root"), str):
        raise RuntimeError("positive dispatch root is absent")
    runtime_inputs_receipt = dispatch.get("runtime_inputs")
    if not isinstance(runtime_inputs_receipt, dict) or \
            not isinstance(runtime_inputs_receipt.get("path"), str):
        raise RuntimeError("positive runtime_inputs receipt is absent")
    runtime_inputs_path = ROOT / runtime_inputs_receipt["path"]
    actual_runtime_receipt = file_receipt(runtime_inputs_path)
    if {key: runtime_inputs_receipt.get(key) for key in ("path", "bytes", "sha256")} != {
            "path": runtime_inputs_receipt["path"],
            "bytes": actual_runtime_receipt["bytes"],
            "sha256": actual_runtime_receipt["sha256"],
    }:
        raise RuntimeError("positive runtime_inputs receipt drift")
    runtime_inputs = load_json(runtime_inputs_path)
    positive_pins = canonical_input_pins(
        runtime_inputs.get("inputs"), "positive r3 runtime inputs")
    frozen_pins = canonical_input_pins(
        protocol.get("positive_reuse_input_pins"),
        "negative protocol positive-reuse input pins")
    protocol_pins = canonical_input_pins(
        protocol.get("inputs"), "negative protocol input pins")
    if runtime_inputs.get("schema") != "vnext-t2-formal-runtime-inputs-r3" or \
            runtime_inputs.get("runtime_dependency_count") != 104 or \
            len(positive_pins) != 104 or frozen_pins != positive_pins:
        raise RuntimeError("positive r3 104-input pin set differs from protocol")
    positive_evidence = protocol.get("positive_evidence")
    if not isinstance(positive_evidence, dict) or not isinstance(
            positive_evidence.get("formal_serial_replay"), dict):
        raise RuntimeError("positive r3 replay receipt is absent")
    positive_replay = load_json(ROOT / positive_evidence[
        "formal_serial_replay"]["path"])
    for field in ("inputs_before", "inputs_after"):
        if canonical_input_pins(positive_replay.get(field),
                                f"positive replay {field}") != positive_pins:
            raise RuntimeError(f"positive r3 replay {field} differs from 104 pins")
    if positive_replay.get("pinned_input_changes") != [] or \
            positive_replay.get("status") != "pass":
        raise RuntimeError("positive r3 replay is not a clean pinned-input pass")
    if any(protocol_pins.get(relative) != row
           for relative, row in positive_pins.items()):
        raise RuntimeError("positive r3 input pin differs from protocol input closure")
    current: dict[str, dict[str, Any]] = {}
    for relative, expected in sorted(positive_pins.items()):
        path = (ROOT / relative).resolve()
        path.relative_to(ROOT)
        actual = file_receipt(path)
        row = {"path": relative, "bytes": actual["bytes"],
               "sha256": actual["sha256"]}
        if row != expected:
            raise RuntimeError(f"positive r3 current input drift: {relative}")
        current[relative] = row
    identity = sha256_bytes(json.dumps(
        positive_pins, sort_keys=True, separators=(",", ":")).encode())
    return {
        "schema": "vnext-t2-positive-r3-input-pin-join-r1",
        "status": "pass",
        "positive_runtime_input_count": len(positive_pins),
        "positive_runtime_inputs_receipt": actual_runtime_receipt,
        "pin_identity_sha256": identity,
        "verified_current_pins": current,
        "actual_model_attestation": "unavailable",
    }


def verify_assertion_site_hit_summary(summary: dict[str, Any],
                                      coverage: dict[str, Any], phase: str,
                                      *, coverage_map_sha256: str
                                      ) -> dict[str, int]:
    plan = coverage.get("successor_assertion_runtime_hit_plan")
    if not isinstance(plan, dict) or plan.get("status") != \
            "expected_source_site_hits_static_plan_actual_hits_pending":
        raise RuntimeError("source-site hit plan is absent or misclassified")
    if summary.get("assertion_site_hit_receipt_schema") != \
            "vnext-t2-source-site-hit-receipt-r1" or \
            summary.get("assertion_site_hit_phase") != phase or \
            summary.get("assertion_site_hit_coverage_map_sha256") != \
            coverage_map_sha256:
        raise RuntimeError(f"source-site hit receipt identity mismatch: {phase}")
    expected_phase = plan.get("phase_site_hit_counts", {}).get(phase)
    if not isinstance(expected_phase, dict):
        raise RuntimeError(f"source-site hit phase is not planned: {phase}")
    phase_paths = {row.get("path") for row in
                   coverage.get("successor_assertion_sites", [])
                   if phase in row.get("expected_phase_hits", {})}
    if len(phase_paths) != 1:
        raise RuntimeError(f"source-site hit phase has ambiguous source: {phase}")
    source_path = next(iter(phase_paths))
    source_rows = coverage.get("ast_inventory_plan", {}).get("sources", [])
    source_receipts = [row for row in source_rows
                       if row.get("path") == source_path]
    if len(source_receipts) != 1 or \
            summary.get("assertion_site_hit_source_sha256") != \
            source_receipts[0].get("sha256"):
        raise RuntimeError(f"source-site hit source digest mismatch: {phase}")
    source_ids = {row["id"] for row in coverage["successor_assertion_sites"]
                  if row.get("path") == source_path}
    observed_raw = summary.get("assertion_site_hit_counts")
    if summary.get("assertion_site_hit_source_path") != source_path or \
            not isinstance(observed_raw, dict) or set(observed_raw) != source_ids or \
            summary.get("unmapped_assertion_sources") not in ([], ()):
        raise RuntimeError(f"source-site hit source inventory mismatch: {phase}")
    observed: dict[str, int] = {}
    for site_id, count in observed_raw.items():
        if not isinstance(count, int) or count < 0:
            raise RuntimeError(f"source-site hit count is malformed: {phase}:{site_id}")
        observed[site_id] = count
    expected_full = {site_id: int(expected_phase.get(site_id, 0))
                     for site_id in source_ids}
    if observed != expected_full:
        raise RuntimeError(f"source-site hit count mismatch: {phase}")
    expected_total = sum(expected_full.values())
    if summary.get("assertion_site_hit_count_observed") != expected_total:
        raise RuntimeError(f"source-site hit total mismatch: {phase}")
    return observed


def aggregate_assertion_site_hit_receipts(
        summaries: list[dict[str, Any]], coverage: dict[str, Any],
        *, coverage_map_sha256: str) -> dict[str, Any]:
    hit_plan = coverage.get("successor_assertion_runtime_hit_plan")
    if not isinstance(hit_plan, dict):
        raise RuntimeError("source-site hit plan is absent")
    phases = hit_plan.get("phase_order")
    if not isinstance(phases, list) or len(phases) != 7 or \
            len(summaries) != len(phases):
        raise RuntimeError("source-site hit phase inventory is incomplete")
    merged = {row["id"]: 0 for row in coverage["successor_assertion_sites"]}
    observed_phase_totals: dict[str, int] = {}
    for phase, summary in zip(phases, summaries):
        if summary.get("assertion_site_hit_coverage_map_sha256") != \
                coverage_map_sha256:
            raise RuntimeError(f"source-site hit map pin drift: {phase}")
        source_hits = verify_assertion_site_hit_summary(
            summary, coverage, phase,
            coverage_map_sha256=coverage_map_sha256)
        for site_id, count in source_hits.items():
            merged[site_id] += count
        observed_phase_totals[phase] = sum(source_hits.values())
    expected = {site_id: int(row.get("runtime_multiplicity", 0))
                for site_id, row in ((row["id"], row)
                    for row in coverage["successor_assertion_sites"])}
    if merged != expected:
        raise RuntimeError("aggregate source-site hit count differs from static plan")
    context_ids = set(coverage.get("context_transport_assertion_ids", []))
    context_hits = sum(merged[site_id] for site_id in context_ids)
    preserved_hits = sum(count for site_id, count in merged.items()
                         if site_id not in context_ids)
    if len(merged) != 214 or sum(merged.values()) != 622 or \
            len(context_ids) != 23 or context_hits != 92 or preserved_hits != 530:
        raise RuntimeError("aggregate source-site hit total is not 214/622")
    return {
        "schema": "vnext-t2-source-site-hit-aggregate-r1",
        "status": "actual_observed_and_exactly_matched_to_static_plan",
        "phase_order": phases,
        "phase_observed_hit_counts": observed_phase_totals,
        "assertion_site_runtime_hits_observed": dict(sorted(merged.items())),
        "assertion_site_count_observed": len(merged),
        "assertion_site_hit_count_observed": sum(merged.values()),
        "context_transport_assertion_sites_completed_observed": context_hits,
        "preserved_successor_runtime_hit_count_observed": preserved_hits,
        "coverage_map_sha256": coverage_map_sha256,
        "formal_t2_accepted": False,
    }


def verify_frozen_positive_evidence(
        positive_root: Path, frozen: dict[str, Any]) -> dict[str, Any]:
    expected_root = (ROOT / frozen["root"]).resolve()
    if positive_root != expected_root:
        raise RuntimeError("positive evidence root differs from frozen protocol")
    expected_labels = {
        "formal_serial_replay", "pipeline_final",
        "producer_candidate_package", "producer_candidate_t1_receipt",
        "producer_result", "producer_run_receipt",
        "replay_candidate_package", "replay_candidate_t1_receipt",
        "replay_result", "replay_run_receipt",
    }
    if set(frozen) != expected_labels | {"root"}:
        raise RuntimeError("positive evidence receipt inventory mismatch")
    observed: dict[str, Any] = {}
    for label in sorted(expected_labels):
        expected = frozen[label]
        path = (ROOT / expected["path"]).resolve()
        path.relative_to(positive_root)
        actual = file_receipt(path)
        if actual["bytes"] != expected["bytes"] or \
                actual["sha256"] != expected["sha256"]:
            raise RuntimeError(f"positive evidence receipt drift: {label}")
        observed[label] = actual
    return observed


def write_parse_manifest(path: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    paths = protocol.get("julia_parse_paths")
    if not isinstance(paths, list) or not paths or \
            len(paths) != len(set(paths)):
        raise RuntimeError("negative protocol Julia parse inventory invalid")
    expected_gate = PARSE_GATE.relative_to(ROOT).as_posix()
    if expected_gate not in paths:
        raise RuntimeError("negative protocol omits the parse gate itself")
    rows = []
    for relative in paths:
        if relative not in protocol["inputs"] or not relative.endswith(".jl"):
            raise RuntimeError(f"unbound Julia parse path: {relative}")
        rows.append(protocol["inputs"][relative]["sha256"] + "\t" + relative)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write("\n".join(rows) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    return file_receipt(path)


def counts_are(value: Any, expected: tuple[int, ...]) -> bool:
    if not isinstance(value, dict):
        return False
    keys = ("e0", "gi1a", "e1", "e2", "n10",
            "compiler", "provider", "solver")
    return tuple(value.get(key) for key in keys) == expected


def verify_context_transport_observation(path: Path, shard: str) -> dict[str, Any]:
    value = load_json(path)
    required_true = (
        "context_authorization_join", "producer_natural_exit_zero",
        "five_consumer_counts_verified", "source_content_join",
        "package_type_valid", "package_context_join", "package_t1_join",
        "adapter_binding_present", "candidate_hash_join",
        "candidate_bytes_join", "build_input_type_valid",
        "input_content_join", "result_committed", "ledger_type_valid",
        "ledger_input_join", "ledger_package_join", "ledger_counts_join",
    )
    if value.get("schema") != \
            "vnext-t2-independent-negative-context-transport-observation-r3" or \
            value.get("shard") != shard or \
            value.get("recorded_before_assertions") is not True or \
            value.get("formal_t2_accepted") is not False or \
            any(value.get(field) is not True for field in required_true) or \
            value.get("source_status") != "source_ready" or \
            value.get("source_errors") not in ([], ()) or \
            value.get("package_validation") is not None or \
            value.get("build_status") != "prepared_not_executed" or \
            value.get("input_validation_status") != "valid" or \
            value.get("result_status") != "complete_contract_receipts":
        raise RuntimeError(f"context transport observation mismatch: {shard}")
    return value


def write_baseline_authorization(path: Path, phase_dir: Path,
                                 phase: dict[str, Any], summary: dict[str, Any],
                                 context_path: Path) -> dict[str, Any]:
    counts = summary.get("final_ledger_fingerprint", {}).get("counts")
    natural = phase.get("stop_reason") == "natural_exit" and \
        phase.get("exit_code") == 0 and not phase.get("residual_heavy_processes")
    five_counts = counts_are(counts, (1, 1, 1, 1, 1, 0, 0, 0))
    if not natural or not five_counts or summary.get("status") != "pass" or \
            summary.get("observed_case_ids") != ["ACTUAL_BASELINE_POSITIVE"]:
        raise RuntimeError("baseline cannot be authorized")
    context = file_receipt(context_path)
    value = {
        "schema": "vnext-t2-independent-negative-baseline-authorization-r3",
        "producer_natural_exit_zero": natural,
        "five_consumer_counts_verified": five_counts,
        "context_sha256": context["sha256"],
        "context": context,
        "producer_phase": file_receipt(phase_dir / "phase.json"),
        "producer_summary": file_receipt(
            phase_dir / "artifacts" / "summary.json"),
        "producer_observations": file_receipt(
            phase_dir / "artifacts" / "observations.jsonl"),
        "producer_stage_trace": file_receipt(
            phase_dir / "artifacts" / "stage_trace.tsv"),
        "input_hash": digest_value(
            summary.get("final_ledger_fingerprint", {}).get("input_hash"),
            "baseline ledger input hash"),
        "package_hash": digest_value(
            summary.get("final_ledger_fingerprint", {}).get("package_hash"),
            "baseline ledger package hash"),
        "formal_t2_accepted": False,
    }
    write_json_new(path, value)
    return value


def verify_artifact_helper(path: Path, mode: str, attacked_path: Path,
                           expected_sha256: str) -> dict[str, Any]:
    value = load_json(path)
    expected_rejection = (
        "producer_candidate_package_raw_sha256_mismatch"
        if mode == "raw_hash_mismatch" else
        "producer_candidate_package_deserialize_failed")
    if value.get("schema") != \
            "vnext-t2-independent-artifact-preflight-negative-r1" or \
            value.get("mode") != mode or \
            value.get("expected_rejection") != expected_rejection or \
            value.get("actual_rejection") != expected_rejection:
        raise RuntimeError(f"artifact helper classification mismatch: {mode}")
    if value.get("publication_committed") is not False or \
            value.get("published_artifacts") not in ([], ()) or \
            value.get("original_artifact_unchanged") is not True:
        raise RuntimeError(f"artifact helper fail-atomic mismatch: {mode}")
    zero = (0, 0, 0, 0, 0, 0, 0, 0)
    if not counts_are(value.get("consumer_attempted_counts"), zero) or \
            not counts_are(value.get("committed_counts"), zero):
        raise RuntimeError(f"artifact helper count mismatch: {mode}")
    attacked = file_receipt(attacked_path)
    if value.get("attacked_artifact_bytes") != attacked["bytes"] or \
            value.get("attacked_artifact_actual_sha256") != attacked["sha256"] or \
            value.get("attacked_artifact_expected_sha256") != \
            expected_sha256.lower():
        raise RuntimeError(f"artifact helper input receipt mismatch: {mode}")
    if mode == "raw_hash_mismatch":
        if value.get("hash_verified") is not False or \
                value.get("deserialize_attempted") is not False:
            raise RuntimeError("raw-hash helper reached deserializer")
    elif value.get("hash_verified") is not True or \
            value.get("deserialize_attempted") is not True:
        raise RuntimeError(f"corrupt helper missed deserializer: {mode}")
    return value


def assert_no_final_publication(output: Path) -> None:
    for name in ("candidate_package.jls",
                 "candidate_t1_admission_receipt.json",
                 "t2_result.jls", "run_receipt.json"):
        if (output / name).exists() or (output / name).is_symlink():
            raise RuntimeError(f"unexpected final publication: {output / name}")


def verify_uncommitted(output: Path, stage: str, *, zero_call: bool,
                       precondition_failure: str | None = None) -> dict[str, Any]:
    path = output / "replay_uncommitted_attempt.json"
    value = load_json(path)
    if value.get("schema") != "vnext-t2-formal-replay-uncommitted-attempt-r2":
        raise RuntimeError("uncommitted receipt schema mismatch")
    if value.get("stage") != stage or value.get("publication_committed") is not False:
        raise RuntimeError(f"uncommitted stage/publication mismatch: {stage}")
    if value.get("published_artifacts") not in ([], ()):
        raise RuntimeError("uncommitted receipt lists published artifacts")
    if value.get("precondition_failure") != precondition_failure:
        raise RuntimeError(f"uncommitted precondition mismatch: {stage}")
    if value.get("caller_package_sha256_before") != \
            value.get("caller_package_sha256_after"):
        raise RuntimeError("uncommitted attempt changed caller package")
    if value.get("producer_artifact_unchanged") is not True or \
            value.get("producer_artifact_sha256_before") != \
            value.get("producer_artifact_sha256_after") or \
            value.get("producer_artifact_bytes_before") != \
            value.get("producer_artifact_bytes_after"):
        raise RuntimeError("uncommitted attempt changed producer artifact")
    attempted = value.get("attempted_counts")
    committed = value.get("committed_counts")
    expected = (0, 0, 0, 0, 0, 0, 0, 0) if zero_call else \
        (1, 1, 1, 1, 1, 0, 0, 0)
    if not counts_are(attempted, expected) or not counts_are(committed, expected):
        raise RuntimeError(f"uncommitted count mismatch: {stage}")
    if value.get("authority_input_accepted") is not (not zero_call):
        raise RuntimeError(f"uncommitted authority classification mismatch: {stage}")
    expected_consumers = [] if zero_call else \
        ["E0", "GI1A", "E1", "E2", "UP2_N10"]
    if value.get("consumers_attempted") != expected_consumers:
        raise RuntimeError(f"uncommitted consumer trace mismatch: {stage}")
    if value.get("result_committed_in_process") is not (not zero_call):
        raise RuntimeError(f"uncommitted in-process result mismatch: {stage}")
    assert_no_final_publication(output)
    return value


def read_positive(positive: Path, final_sha: str,
                  pipeline_sha: str) -> dict[str, Any]:
    final_path = positive / "formal_t2_serial_replay.json"
    pipeline_path = positive / "pipeline_final.json"
    if file_receipt(final_path)["sha256"] != final_sha.lower():
        raise RuntimeError("positive formal serial replay SHA-256 mismatch")
    if file_receipt(pipeline_path)["sha256"] != pipeline_sha.lower():
        raise RuntimeError("positive pipeline-final SHA-256 mismatch")
    final = load_json(final_path)
    pipeline = load_json(pipeline_path)
    if final.get("schema") != "vnext-t2-formal-serial-candidate-replay-r1" or \
            final.get("status") != "pass":
        raise RuntimeError("positive formal serial replay did not pass")
    if pipeline.get("status") != "pass" or pipeline.get("failure") is not None:
        raise RuntimeError("positive pipeline-final did not pass")
    if final.get("formal_gate_evidence_kind") != "formal_t1_actual" or \
            final.get("formal_gate_verified") is not True:
        raise RuntimeError("positive formal gate was not actual and verified")
    if final.get("formal_t2_accepted") is not False:
        raise RuntimeError("positive evidence overclaims T2 acceptance")
    producer = positive / "producer"
    producer_receipt_path = producer / "run_receipt.json"
    producer_receipt = load_json(producer_receipt_path)
    candidate_path = producer / "candidate_t1_admission_receipt.json"
    package_path = producer / "candidate_package.jls"
    return {
        "final_path": final_path, "pipeline_path": pipeline_path,
        "final": final, "pipeline": pipeline, "producer": producer,
        "producer_receipt_path": producer_receipt_path,
        "producer_receipt": producer_receipt,
        "candidate_path": candidate_path,
        "candidate_sha256": file_receipt(candidate_path)["sha256"],
        "package_path": package_path,
        "package_sha256": file_receipt(package_path)["sha256"],
        "stable_projection_hash": digest_value(
            producer_receipt["stable_projection_hash"],
            "positive stable projection hash"),
        "result_reload_identity_hash": digest_value(
            producer_receipt["result_reload_identity_hash"],
            "positive result reload identity hash"),
        "manifest_path": Path(
            final["software_acceptance_manifest"]["path"]).resolve(),
        "manifest_sha256": final["software_acceptance_manifest"]["sha256"],
        "verification_path": Path(
            final["software_acceptance_manifest"]["verification_path"]).resolve(),
        "verification_sha256":
            final["software_acceptance_manifest"]["verification_sha256"],
    }


def candidate_command(julia_common: list[str], positive: dict[str, Any],
                      output: Path, candidate_hash: str, stable_hash: str,
                      reload_hash: str, *, package_path: Path | None = None,
                      package_sha256: str | None = None) -> list[str]:
    supplied_package = package_path or positive["package_path"]
    supplied_package_sha256 = package_sha256 or positive["package_sha256"]
    return julia_common + [str(CANDIDATE_DRIVER), "replay",
        str(positive["manifest_path"]), positive["manifest_sha256"],
        str(positive["verification_path"]), positive["verification_sha256"],
        str(output), candidate_hash, stable_hash,
        str(supplied_package), supplied_package_sha256, reload_hash]


def build_actual_formal_shard_command(
        julia_common: list[str], mode: str, authorities: list[str],
        context_path: Path | str, context_sha256: str,
        authorization_path: Path | str, authorization_sha256: str,
        output_dir: Path | str, coverage_map_path: Path | str,
        coverage_map_sha256: str) -> list[str]:
    """Build and guard the exact r3 driver's 16-argument shard invocation."""
    expected_modes = {"preflight", "authority", "fault_n10", "t1_handoff"}
    if mode not in expected_modes and not (
            mode.startswith("authority-case:") and
            mode.split(":", 1)[1] in AUTHORITY_CASE_ORDER):
        raise ValueError(f"unsupported actual-formal shard mode: {mode}")
    if len(authorities) != 8:
        raise ValueError("actual-formal shard requires four authority path/hash pairs")
    for name, digest in (("context", context_sha256),
                         ("authorization", authorization_sha256),
                         ("coverage map", coverage_map_sha256)):
        if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
            raise ValueError(f"{name} SHA-256 must be lowercase hexadecimal")
    command = list(julia_common) + [str(ACTUAL_DRIVER), mode, *authorities,
        str(context_path), context_sha256,
        str(authorization_path), authorization_sha256,
        str(output_dir), str(coverage_map_path), coverage_map_sha256]
    driver_index = command.index(str(ACTUAL_DRIVER))
    driver_args = command[driver_index + 1:]
    if len(driver_args) != 16 or driver_args[0] != mode or \
            driver_args[14] != str(coverage_map_path) or \
            driver_args[15] != coverage_map_sha256:
        raise RuntimeError("actual-formal shard argv violates the 16-argument driver contract")
    return command


def _authority_source_ids(coverage: dict[str, Any]) -> set[str]:
    source_path = "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r6.jl"
    return {row["id"] for row in coverage["successor_assertion_sites"]
            if row.get("path") == source_path}


def verify_authority_case_receipt(
        case_id: str, case_dir: Path, expected_command: list[str],
        coverage: dict[str, Any], *, coverage_map_sha256: str,
        driver_sha256: str, context_sha256: str,
        authorization_sha256: str,
        authority_path_hash_pairs: list[str]) -> tuple[dict[str, Any], dict[str, int]]:
    if case_id not in AUTHORITY_CASE_ORDER:
        raise RuntimeError(f"unknown authority case receipt: {case_id}")
    artifact_dir = case_dir / "artifacts"
    phase_path = case_dir / "phase.json"
    summary_path = artifact_dir / "summary.json"
    progress_path = artifact_dir / "case_progress.jsonl"
    observations_path = artifact_dir / "observations.jsonl"
    transport_path = artifact_dir / "context_transport_observation.json"
    phase = load_json(phase_path)
    if phase.get("name") != f"actual_formal_authority_case_{case_id}" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 0 or phase.get("residual_heavy_processes"):
        raise RuntimeError(f"authority case did not naturally pass: {case_id}")
    if phase.get("schema") != "vnext-t2-independent-negative-phase-r5" or \
            phase.get("working_set_limit_bytes") != AUTHORITY_WORKING_SET_LIMIT_BYTES or \
            not 0 < phase.get("timeout_seconds", 0) <= AUTHORITY_CASE_TIMEOUT_SECONDS:
        raise RuntimeError(f"authority case resource contract mismatch: {case_id}")
    try:
        require_natural(phase, exit_zero=True)
    except RuntimeError as error:
        raise RuntimeError(
            f"authority case monitor/termination receipt invalid: {case_id}: {error}")
    elapsed = phase.get("seconds")
    peak = phase.get("peak_process_tree_working_set_bytes")
    if not isinstance(elapsed, (int, float)) or elapsed < 0 or \
            elapsed > phase["timeout_seconds"] + 2 or \
            not isinstance(peak, int) or peak < 0 or \
            peak >= AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise RuntimeError(f"authority case measured resource receipt invalid: {case_id}")
    stdout_path = case_dir / "stdout.raw"
    stderr_path = case_dir / "stderr.raw"
    if phase.get("stdout") != file_receipt(stdout_path) or \
            phase.get("stderr") != file_receipt(stderr_path):
        raise RuntimeError(f"authority case raw phase-output pin drift: {case_id}")
    stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
    pass_marker = "VNEXT_T2_ACTUAL_FORMAL_SHARD=PASS mode=authority"
    if stdout_text.count(pass_marker) != 1:
        raise RuntimeError(f"authority case natural PASS marker missing/duplicate: {case_id}")
    command = phase.get("command")
    if not isinstance(command, list) or command != expected_command:
        # Resume may use a different immutable context/authorization path. Check
        # exact authority and source arguments, plus content hashes at old paths.
        if not isinstance(command, list):
            raise RuntimeError(f"authority case command is malformed: {case_id}")
        try:
            driver_index = command.index(str(ACTUAL_DRIVER))
            expected_driver_index = expected_command.index(str(ACTUAL_DRIVER))
        except ValueError as error:
            raise RuntimeError(f"authority case driver argv is malformed: {case_id}") from error
        old_args = command[driver_index + 1:]
        new_args = expected_command[expected_driver_index + 1:]
        if driver_index != expected_driver_index or \
                command[:driver_index + 1] != expected_command[:expected_driver_index + 1] or \
                len(old_args) != 16 or old_args[:9] != new_args[:9] or \
                old_args[0] != f"authority-case:{case_id}" or \
                old_args[10] != context_sha256 or old_args[12] != authorization_sha256 or \
                old_args[14:] != new_args[14:] or \
                old_args[13] != str(artifact_dir):
            raise RuntimeError(f"authority case command drift: {case_id}")
        old_context = Path(old_args[9])
        old_authorization = Path(old_args[11])
        if not old_context.is_file() or not old_authorization.is_file() or \
                file_receipt(old_context)["sha256"] != context_sha256 or \
                file_receipt(old_authorization)["sha256"] != authorization_sha256:
            raise RuntimeError(f"authority case reused context/authorization drift: {case_id}")
    driver_index = command.index(str(ACTUAL_DRIVER))
    old_args = command[driver_index + 1:]
    if old_args[1:9] != authority_path_hash_pairs or \
            old_args[0] != f"authority-case:{case_id}" or \
            old_args[10] != context_sha256 or old_args[12] != authorization_sha256:
        raise RuntimeError(f"authority case pinned input argv mismatch: {case_id}")
    summary = load_json(summary_path)
    if summary.get("schema") != "vnext-t2-independent-actual-negative-shard-summary-r5" or \
            summary.get("status") != "pass" or summary.get("shard") != "authority" or \
            summary.get("observed_case_ids") != [case_id] or \
            summary.get("observed_case_count") != 1 or \
            summary.get("formal_t2_accepted") is not False or \
            summary.get("physical_acceptance") is not False or \
            summary.get("scientific_acceptance") is not False or \
            summary.get("context_sha256") != context_sha256 or \
            summary.get("context_unchanged") is not True or \
            summary.get("source_revalidation_status") != "source_ready" or \
            summary.get("rebuilt_input_full_content_join") is not True or \
            summary.get("producer_package_unchanged") is not True or \
            summary.get("candidate_receipt_unchanged") is not True or \
            summary.get("package_wire_unchanged") is not True or \
            summary.get("prior_ledger_unchanged") is not True:
        raise RuntimeError(f"authority case summary contract mismatch: {case_id}")
    summary_markers = [line.partition("=")[2] for line in stdout_text.splitlines()
                       if line.startswith("VNEXT_T2_NEGATIVE_SHARD_SUMMARY=")]
    if len(summary_markers) != 1 or json.loads(summary_markers[0]) != summary:
        raise RuntimeError(f"authority case stdout/summary receipt mismatch: {case_id}")
    hit_plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    if hit_plan.get("case_order") != AUTHORITY_CASE_ORDER or \
            hit_plan.get("status") != "static_plan_actual_case_hits_pending":
        raise RuntimeError("authority case-hit plan identity mismatch")
    source_ids = _authority_source_ids(coverage)
    expected_summary = hit_plan["case_site_hit_counts"][case_id]
    observed_raw = summary.get("assertion_site_hit_counts")
    if summary.get("assertion_site_hit_receipt_schema") != \
            "vnext-t2-source-site-hit-receipt-r1" or \
            summary.get("assertion_site_hit_phase") != "actual_formal_authority" or \
            summary.get("assertion_site_hit_source_path") != hit_plan["source_path"] or \
            summary.get("assertion_site_hit_source_sha256") != driver_sha256 or \
            summary.get("assertion_site_hit_coverage_map_sha256") != coverage_map_sha256 or \
            not isinstance(observed_raw, dict) or set(observed_raw) != source_ids or \
            any(not isinstance(value, int) or value < 0 for value in observed_raw.values()) or \
            observed_raw != expected_summary or \
            summary.get("assertion_site_hit_count_observed") != sum(expected_summary.values()) or \
            summary.get("unmapped_assertion_sources") != []:
        raise RuntimeError(f"authority case source-site hits differ from plan: {case_id}")
    progress_rows = load_jsonl(progress_path)
    if len(progress_rows) < 3:
        raise RuntimeError(f"authority case progress event count mismatch: {case_id}")
    header, begin, complete = progress_rows[0], progress_rows[1], progress_rows[-1]
    record_rows = progress_rows[2:-1]
    if header.get("schema") != "vnext-t2-authority-case-progress-r3" or \
            header.get("event") != "header" or \
            header.get("phase") != "actual_formal_authority" or \
            header.get("selected_case_id") != case_id or \
            header.get("source_path") != hit_plan["source_path"] or \
            header.get("driver_version") != \
                "independent-actual-negative-r6-authority-record-progress" or \
            header.get("expected_case_ids") != [case_id] or \
            header.get("status") != "progress_only" or \
            header.get("source_sha256") != driver_sha256 or \
            header.get("coverage_map_sha256") != coverage_map_sha256 or \
            header.get("site_ids") != sorted(source_ids) or \
            header.get("actual_hit_counts_are_measured") is not True or \
            header.get("per_assertion_record_events_flushed") is not True or \
            header.get("formal_t2_accepted") is not False or \
            begin.get("event") != "case_begin" or begin.get("case_id") != case_id or \
            begin.get("phase") != "actual_formal_authority" or \
            begin.get("selected_case_id") != case_id or \
            begin.get("sequence") != 1 or \
            not isinstance(begin.get("monotonic_time_ns"), int) or \
            begin.get("monotonic_time_ns", 0) <= 0 or \
            begin.get("progress_events_are_record_level") is not True or \
            complete.get("event") != "case_complete" or \
            complete.get("case_id") != case_id or \
            complete.get("phase") != "actual_formal_authority" or \
            complete.get("selected_case_id") != case_id or \
            complete.get("sequence") != 1 or \
            not isinstance(complete.get("monotonic_time_ns"), int) or \
            complete.get("monotonic_time_ns", 0) <= 0 or \
            complete.get("status") != "completed" or \
            complete.get("case_completed") is not True or \
            complete.get("formal_t2_accepted") is not False or \
            complete.get("all_recorded_assertions_passed_observed") is not True or \
            complete.get("unmapped_assertion_source_count_observed") != 0 or \
            complete.get("status") != "completed" or \
            complete.get("per_assertion_events_match_counts") is not True:
        raise RuntimeError(f"authority case progress receipt invalid: {case_id}")
    expected_progress = dict(expected_summary)
    if case_id == AUTHORITY_CASE_ORDER[0]:
        for site_id in hit_plan["context_transport_site_ids"]:
            expected_progress[site_id] -= 1
            if expected_progress[site_id] < 0:
                raise RuntimeError("context transport hit was not allocated to first case")
    line_to_site = {}
    for row in coverage["successor_assertion_sites"]:
        if row.get("path") == hit_plan["source_path"]:
            line = row.get("line")
            if not isinstance(line, int) or line in line_to_site:
                raise RuntimeError("authority site map has a duplicate/malformed source line")
            line_to_site[line] = row["id"]
    event_hits = complete.get("assertion_site_hit_counts_observed")
    expected_result_counts = {
        "pass": sum(expected_progress.values()), "fail": 0,
        "error": 0, "broken": 0, "other": 0}
    observed_event_hits = {site_id: 0 for site_id in source_ids}
    observed_event_results = {key: 0 for key in expected_result_counts}
    last_event_time = begin["monotonic_time_ns"]
    for ordinal, event in enumerate(record_rows, 1):
        source_line = event.get("source_line")
        site_id = event.get("site_id")
        result_class = event.get("result_class")
        if event.get("schema") != "vnext-t2-authority-case-progress-r3" or \
                event.get("event") != "assertion_result" or \
                event.get("phase") != "actual_formal_authority" or \
                event.get("selected_case_id") != case_id or \
                event.get("case_id") != case_id or \
                event.get("record_ordinal") != ordinal or \
                not isinstance(source_line, int) or \
                line_to_site.get(source_line) != site_id or \
                site_id not in source_ids or \
                Path(str(event.get("source_file", ""))).name != ACTUAL_DRIVER.name or \
                result_class not in observed_event_results or \
                event.get("record_completed") is not True or \
                not isinstance(event.get("monotonic_time_ns"), int) or \
                event.get("monotonic_time_ns", 0) <= last_event_time or \
                event.get("formal_t2_accepted") is not False:
            raise RuntimeError(f"authority per-assertion event invalid: {case_id}:{ordinal}")
        observed_event_hits[site_id] += 1
        observed_event_results[result_class] += 1
        if event.get("site_hit_count_for_case_observed") != observed_event_hits[site_id]:
            raise RuntimeError(f"authority per-site running count mismatch: {case_id}:{ordinal}")
        last_event_time = event["monotonic_time_ns"]
    if not isinstance(event_hits, dict) or set(event_hits) != source_ids or \
            event_hits != expected_progress or \
            observed_event_hits != expected_progress or \
            observed_event_results != expected_result_counts or \
            len(record_rows) != sum(expected_result_counts.values()) or \
            complete.get("assertion_result_record_count_observed") != len(record_rows) or \
            complete.get("monotonic_time_ns", 0) <= last_event_time or \
            complete.get("assertion_site_hit_count_observed") != sum(expected_progress.values()) or \
            complete.get("assertion_result_count_observed") != sum(expected_progress.values()) or \
            complete.get("assertion_result_counts_observed") != expected_result_counts:
        raise RuntimeError(f"authority case actual hit event mismatch: {case_id}")
    if summary.get("authority_case_progress_path") != "case_progress.jsonl" or \
            summary.get("authority_case_progress_sha256") != file_receipt(progress_path)["sha256"] or \
            summary.get("observation_file_sha256") != file_receipt(observations_path)["sha256"]:
        raise RuntimeError(f"authority case raw receipt pin mismatch: {case_id}")
    progress_markers = [line.partition("=")[2] for line in stdout_text.splitlines()
                        if line.startswith("VNEXT_T2_NEGATIVE_CASE_PROGRESS=")]
    if len(progress_markers) != len(progress_rows) or \
            [json.loads(row) for row in progress_markers] != progress_rows:
        raise RuntimeError(f"authority case flushed progress/raw mismatch: {case_id}")
    observations = load_jsonl(observations_path)
    if [row.get("case_id") for row in observations] != [case_id]:
        raise RuntimeError(f"authority case observation inventory mismatch: {case_id}")
    transport = verify_context_transport_observation(transport_path, "authority")
    if summary.get("context_transport_observation_sha256") != \
            file_receipt(transport_path)["sha256"]:
        raise RuntimeError(f"authority case context transport observation invalid: {case_id}")
    return summary, dict(observed_raw)


def write_jsonl_new(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        for row in rows:
            stream.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def summarize_authority_case_progress_prefix(
        case_id: str, rows: list[dict[str, Any]], coverage: dict[str, Any], *,
        coverage_map_sha256: str, driver_sha256: str) -> dict[str, Any]:
    """Validate and summarize only flushed Test.record events, including partial prefixes."""
    hit_plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    source_path = hit_plan["source_path"]
    source_ids = _authority_source_ids(coverage)
    zero_hits = {site_id: 0 for site_id in sorted(source_ids)}
    result_counts = {key: 0 for key in
                     ("pass", "fail", "error", "broken", "other")}
    if not rows:
        return {"status": "no_complete_flushed_rows", "event_count": 0,
                "source_site_hit_counts_observed": zero_hits,
                "assertion_result_counts_observed": result_counts,
                "formal_t2_accepted": False}
    header = rows[0]
    if header.get("schema") != "vnext-t2-authority-case-progress-r3" or \
            header.get("event") != "header" or \
            header.get("phase") != "actual_formal_authority" or \
            header.get("selected_case_id") != case_id or \
            header.get("expected_case_ids") != [case_id] or \
            header.get("source_path") != source_path or \
            header.get("source_sha256") != driver_sha256 or \
            header.get("coverage_map_sha256") != coverage_map_sha256 or \
            header.get("site_ids") != sorted(source_ids) or \
            header.get("per_assertion_record_events_flushed") is not True or \
            header.get("actual_hit_counts_are_measured") is not True or \
            header.get("formal_t2_accepted") is not False:
        return {"status": "invalid_header", "event_count": 0,
                "source_site_hit_counts_observed": zero_hits,
                "assertion_result_counts_observed": result_counts,
                "formal_t2_accepted": False}
    line_to_site: dict[int, str] = {}
    for row in coverage["successor_assertion_sites"]:
        if row.get("path") == source_path:
            line = row.get("line")
            if not isinstance(line, int) or line in line_to_site:
                return {"status": "invalid_source_line_map", "event_count": 0,
                        "source_site_hit_counts_observed": zero_hits,
                        "assertion_result_counts_observed": result_counts,
                        "formal_t2_accepted": False}
            line_to_site[line] = row["id"]
    remaining = rows[1:]
    begin_seen = False
    complete_seen = False
    last_time = 0
    ordinal = 0
    for event in remaining:
        event_name = event.get("event")
        if event_name == "case_begin" and not begin_seen and ordinal == 0:
            if event.get("case_id") != case_id or \
                    event.get("selected_case_id") != case_id or \
                    event.get("phase") != "actual_formal_authority" or \
                    event.get("sequence") != 1 or \
                    not isinstance(event.get("monotonic_time_ns"), int):
                return {"status": "invalid_case_begin", "event_count": ordinal,
                        "source_site_hit_counts_observed": zero_hits,
                        "assertion_result_counts_observed": result_counts,
                        "formal_t2_accepted": False}
            last_time = event["monotonic_time_ns"]
            begin_seen = True
            continue
        if event_name == "assertion_result" and begin_seen and not complete_seen:
            ordinal += 1
            source_line = event.get("source_line")
            site_id = event.get("site_id")
            result_class = event.get("result_class")
            if event.get("schema") != "vnext-t2-authority-case-progress-r3" or \
                    event.get("case_id") != case_id or \
                    event.get("selected_case_id") != case_id or \
                    event.get("phase") != "actual_formal_authority" or \
                    event.get("record_ordinal") != ordinal or \
                    not isinstance(source_line, int) or \
                    line_to_site.get(source_line) != site_id or \
                    site_id not in source_ids or \
                    Path(str(event.get("source_file", ""))).name != ACTUAL_DRIVER.name or \
                    result_class not in result_counts or \
                    event.get("record_completed") is not True or \
                    not isinstance(event.get("monotonic_time_ns"), int) or \
                    event.get("monotonic_time_ns", 0) <= last_time or \
                    event.get("formal_t2_accepted") is not False:
                return {"status": "invalid_assertion_event", "event_count": ordinal - 1,
                        "source_site_hit_counts_observed": zero_hits,
                        "assertion_result_counts_observed": result_counts,
                        "formal_t2_accepted": False}
            zero_hits[site_id] += 1
            result_counts[result_class] += 1
            if event.get("site_hit_count_for_case_observed") != zero_hits[site_id]:
                return {"status": "invalid_running_site_count", "event_count": ordinal - 1,
                        "source_site_hit_counts_observed": zero_hits,
                        "assertion_result_counts_observed": result_counts,
                        "formal_t2_accepted": False}
            last_time = event["monotonic_time_ns"]
            continue
        if event_name == "case_complete" and begin_seen and not complete_seen:
            complete_seen = True
            if event.get("case_id") != case_id or \
                    event.get("selected_case_id") != case_id or \
                    event.get("phase") != "actual_formal_authority" or \
                    event.get("sequence") != 1 or \
                    event.get("status") != "completed" or \
                    event.get("assertion_site_hit_counts_observed") != zero_hits or \
                    event.get("assertion_result_counts_observed") != result_counts or \
                    event.get("assertion_result_record_count_observed") != ordinal or \
                    not isinstance(event.get("monotonic_time_ns"), int) or \
                    event.get("monotonic_time_ns", 0) <= last_time or \
                    event.get("formal_t2_accepted") is not False:
                return {"status": "invalid_case_complete", "event_count": ordinal,
                        "source_site_hit_counts_observed": zero_hits,
                        "assertion_result_counts_observed": result_counts,
                        "formal_t2_accepted": False}
            last_time = event["monotonic_time_ns"]
            continue
        return {"status": "invalid_event_order", "event_count": ordinal,
                "source_site_hit_counts_observed": zero_hits,
                "assertion_result_counts_observed": result_counts,
                "formal_t2_accepted": False}
    return {
        "status": "valid_complete_case_receipt" if complete_seen else
                  "valid_flushed_partial_prefix",
        "event_count": ordinal,
        "case_begin_seen": begin_seen,
        "case_complete_seen": complete_seen,
        "source_site_count_zero_filled": len(zero_hits),
        "source_site_nonzero_count_observed": sum(value > 0
                                                    for value in zero_hits.values()),
        "source_site_hit_count_observed": sum(zero_hits.values()),
        "source_site_hit_counts_observed": zero_hits,
        "assertion_result_counts_observed": result_counts,
        "formal_t2_accepted": False,
    }


def verify_authority_resume_ancestry(
        resume_root: Path, authority_dir: Path, current_protocol_path: Path,
        current_protocol_sha256: str, current_inputs: dict[str, Any],
        repository_head: str, expected_cases: list[str]
        ) -> tuple[dict[str, Any], dict[str, Path]]:
    resume_root = resume_root.resolve()
    require_t2_execution_leaf(resume_root)
    if not resume_root.is_dir() or resume_root == authority_dir.resolve():
        raise ValueError("authority resume source must be an existing prior T2 run leaf")
    prior_start_path = resume_root / "pipeline_start.json"
    prior_final_path = resume_root / "pipeline_final.json"
    prior_start = load_json(prior_start_path)
    prior_final = load_json(prior_final_path)
    current_protocol_receipt = file_receipt(current_protocol_path)
    if prior_start.get("repository_head") != repository_head or \
            prior_start.get("protocol_expected_sha256") != current_protocol_sha256 or \
            prior_start.get("protocol") != current_protocol_receipt or \
            prior_final.get("protocol") != current_protocol_receipt or \
            prior_start.get("inputs_before") != current_inputs or \
            prior_final.get("repository_head_before") != repository_head or \
            prior_final.get("repository_head_after") != repository_head or \
            prior_final.get("inputs_before") != current_inputs or \
            prior_final.get("inputs_after") != current_inputs or \
            prior_final.get("formal_t2_accepted") is not False:
        raise RuntimeError("authority resume source is not bound to unchanged protocol inputs")
    prior_phases = prior_final.get("phases")
    if not isinstance(prior_phases, list):
        raise RuntimeError("authority resume parent phase ancestry is absent")
    authority_phases = [phase for phase in prior_phases
        if isinstance(phase, dict) and phase.get("name") == "actual_formal_authority"]
    authority_phase_path = resume_root / "actual_formal_authority" / "phase.json"
    if len(authority_phases) != 1 or not authority_phase_path.is_file() or \
            authority_phases[0] != load_json(authority_phase_path):
        raise RuntimeError("authority resume phase is not joined to prior pipeline final")
    authority_phase = authority_phases[0]
    phase_rows = authority_phase.get("case_rows")
    completed_ids = authority_phase.get("completed_case_ids")
    if authority_phase.get("formal_t2_accepted") is not False or \
            authority_phase.get("case_count_expected") != len(expected_cases) or \
            not isinstance(phase_rows, list) or \
            not isinstance(completed_ids, list) or \
            len(completed_ids) != len(set(completed_ids)) or \
            any(case_id not in expected_cases for case_id in completed_ids):
        raise RuntimeError("authority resume case inventory is malformed")
    phase_row_ids = [row.get("case_id") for row in phase_rows
                     if isinstance(row, dict)]
    phase_positions = [expected_cases.index(case_id) for case_id in phase_row_ids
                       if case_id in expected_cases]
    if len(phase_row_ids) != len(phase_rows) or \
            len(phase_row_ids) != len(set(phase_row_ids)) or \
            len(phase_positions) != len(phase_row_ids) or \
            phase_positions != sorted(phase_positions):
        raise RuntimeError("authority resume case rows are duplicated or reordered")
    complete_statuses = {"completed_natural_exit_zero", "completed_reused"}
    row_completed_ids = [row["case_id"] for row in phase_rows
                         if row.get("status") in complete_statuses]
    if row_completed_ids != completed_ids:
        raise RuntimeError("authority resume completed-case list differs from rows")
    case_roots: dict[str, Path] = {}
    for case_id in expected_cases:
        old_case = resume_root / "actual_formal_authority" / "cases" / case_id
        if old_case.is_symlink() or not old_case.resolve().is_relative_to(resume_root):
            raise RuntimeError(f"authority resume case escapes prior run root: {case_id}")
        old_phase_path = old_case / "phase.json"
        matching_rows = [row for row in phase_rows
                         if row.get("case_id") == case_id]
        if old_phase_path.is_file():
            old_phase_receipt = file_receipt(old_phase_path)
            if len(matching_rows) == 1 and \
                    matching_rows[0].get("status") in complete_statuses and \
                    matching_rows[0].get("phase") == old_phase_receipt and \
                    case_id in completed_ids:
                case_roots[case_id] = old_case
        elif case_id in completed_ids:
            raise RuntimeError(f"completed authority case phase is missing: {case_id}")
    return authority_phase, case_roots


def run_authority_case_phase(
        *, julia_common: list[str], authorities: list[str],
        context_path: Path, context_sha256: str,
        authorization_path: Path, authorization_sha256: str,
        coverage_map_path: Path, coverage_map_sha256: str,
        coverage: dict[str, Any], driver_sha256: str,
        authority_dir: Path, environment: dict[str, str],
        working_set_limit_bytes: int, authority_phase_timeout: float,
        authority_case_timeout: float, resume_from: Path | None,
        current_protocol_path: Path, current_protocol_sha256: str,
        current_inputs: dict[str, Any],
        repository_head: str) -> dict[str, Any]:
    if authority_phase_timeout != AUTHORITY_PHASE_TIMEOUT_SECONDS or \
            authority_case_timeout != AUTHORITY_CASE_TIMEOUT_SECONDS or \
            working_set_limit_bytes != AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise RuntimeError("authority case execution limits differ from frozen contract")
    authority_dir.mkdir(parents=True, exist_ok=False)
    cases_root = authority_dir / "cases"
    cases_root.mkdir()
    artifacts = authority_dir / "artifacts"
    artifacts.mkdir()
    started_utc = utc()
    started = time.monotonic()
    case_rows: list[dict[str, Any]] = []
    case_results: dict[str, dict[str, Any]] = {}
    stop_reason = "natural_exit"
    exit_code = 0
    phase_error: str | None = None
    hit_plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    expected_cases = hit_plan["case_order"]
    if expected_cases != AUTHORITY_CASE_ORDER or len(expected_cases) != 9:
        raise RuntimeError("authority case order/coverage contract mismatch")
    resume_cases: dict[str, Path] = {}
    resume_authority_phase: dict[str, Any] | None = None
    if resume_from is not None:
        resume_authority_phase, resume_cases = verify_authority_resume_ancestry(
            resume_from, authority_dir, current_protocol_path,
            current_protocol_sha256, current_inputs, repository_head,
            expected_cases)
    all_completed = True
    child_phase_receipts: list[dict[str, Any]] = []
    for case_id in expected_cases:
        case_dir = cases_root / case_id
        command = build_actual_formal_shard_command(
            julia_common, f"authority-case:{case_id}", authorities,
            context_path, context_sha256, authorization_path,
            authorization_sha256, case_dir / "artifacts", coverage_map_path,
            coverage_map_sha256)
        source_case_dir = resume_cases.get(case_id)
        if source_case_dir is not None:
            try:
                old_artifacts = source_case_dir / "artifacts"
                old_command = build_actual_formal_shard_command(
                    julia_common, f"authority-case:{case_id}", authorities,
                    context_path, context_sha256, authorization_path,
                    authorization_sha256, old_artifacts, coverage_map_path,
                    coverage_map_sha256)
                summary, source_hits = verify_authority_case_receipt(
                    case_id, source_case_dir, old_command, coverage,
                    coverage_map_sha256=coverage_map_sha256,
                    driver_sha256=driver_sha256,
                    context_sha256=context_sha256,
                    authorization_sha256=authorization_sha256,
                    authority_path_hash_pairs=authorities)
                prior_rows = (resume_authority_phase or {}).get("case_rows", [])
                ancestry_rows = [row for row in prior_rows
                    if isinstance(row, dict) and row.get("case_id") == case_id and
                    row.get("status") in ("completed_natural_exit_zero",
                                           "completed_reused")]
                child_receipt = file_receipt(source_case_dir / "phase.json")
                if len(ancestry_rows) != 1 or \
                        ancestry_rows[0].get("phase") != child_receipt or \
                        source_case_dir.is_symlink() or \
                source_case_dir.resolve().is_relative_to(resume_from.resolve()) is False:
                    raise RuntimeError(f"authority case is not ancestry-pinned for replay: {case_id}")
                case_results[case_id] = {
                    "case_dir": source_case_dir,
                    "summary": summary,
                    "hits": source_hits,
                    "reused_from": str(source_case_dir),
                }
                phase_receipt = child_receipt
                child_phase_receipts.append({"case_id": case_id,
                    "phase": phase_receipt, "reused": True})
                case_rows.append({"case_id": case_id, "status": "completed_reused",
                    "reused_from": str(source_case_dir), "phase": phase_receipt})
                continue
            except (OSError, RuntimeError, ValueError, KeyError, TypeError):
                # A missing, interrupted, or mismatched prior case is never reused.
                pass
        remaining = authority_phase_timeout - (time.monotonic() - started)
        if remaining <= 0:
            all_completed = False
            stop_reason = "phase_wall_timeout"
            exit_code = 15
            phase_error = "authority total case budget exhausted before this case"
            case_rows.append({"case_id": case_id, "status": "not_run_total_budget_exhausted"})
            break
        case_dir.mkdir()
        case_artifacts = case_dir / "artifacts"
        case_artifacts.mkdir()
        case_timeout = min(authority_case_timeout, remaining)
        phase = run_phase(
            f"actual_formal_authority_case_{case_id}", command, case_dir,
            timeout_seconds=case_timeout,
            working_set_limit_bytes=working_set_limit_bytes,
            environment=environment, precreated=True)
        phase_receipt = file_receipt(case_dir / "phase.json")
        child_phase_receipts.append({"case_id": case_id,
            "phase": phase_receipt, "reused": False})
        if phase.get("stop_reason") != "natural_exit" or phase.get("exit_code") != 0:
            all_completed = False
            if phase.get("stop_reason") != "natural_exit":
                stop_reason = str(phase.get("stop_reason"))
                exit_code = phase.get("exit_code", 15)
            else:
                stop_reason = "authority_case_natural_exit_nonzero"
                exit_code = phase.get("exit_code", 1)
            phase_error = f"{case_id} child stop={phase.get('stop_reason')} exit={phase.get('exit_code')}"
            case_rows.append({"case_id": case_id, "status": "partial_child", "phase": phase_receipt})
            break
        try:
            summary, source_hits = verify_authority_case_receipt(
                case_id, case_dir, command, coverage,
                coverage_map_sha256=coverage_map_sha256,
                driver_sha256=driver_sha256,
                context_sha256=context_sha256,
                authorization_sha256=authorization_sha256,
                authority_path_hash_pairs=authorities)
        except (OSError, RuntimeError, ValueError, KeyError, TypeError) as error:
            all_completed = False
            stop_reason = "authority_case_receipt_invalid"
            exit_code = 1
            phase_error = f"{case_id} receipt validation failed: {error}"
            case_rows.append({"case_id": case_id, "status": "invalid_receipt",
                "phase": phase_receipt, "error": str(error)})
            break
        case_results[case_id] = {"case_dir": case_dir,
            "summary": summary, "hits": source_hits, "reused_from": None}
        case_rows.append({"case_id": case_id, "status": "completed_natural_exit_zero",
            "phase": phase_receipt})
        if time.monotonic() - started > authority_phase_timeout:
            all_completed = False
            stop_reason = "phase_wall_timeout"
            exit_code = 15
            phase_error = "authority total case budget exceeded during receipt validation"
            break
    if len(case_results) != len(expected_cases):
        all_completed = False
    if all_completed and time.monotonic() - started > authority_phase_timeout:
        all_completed = False
        stop_reason = "phase_wall_timeout"
        exit_code = 15
        phase_error = "authority total case budget exceeded before aggregate join"
    # Only measured per-case rows enter this progress projection. Raw child receipts
    # are preserved under each case directory, including partial timeout progress.
    progress_header = {
        "schema": "vnext-t2-authority-case-progress-aggregate-r2",
        "event": "header", "phase": "actual_formal_authority",
        "driver_source_sha256": driver_sha256,
        "coverage_map_sha256": coverage_map_sha256,
        "expected_case_ids": expected_cases,
        "completed_case_ids": [case_id for case_id in expected_cases
                                if case_id in case_results],
        "status": "actual_case_progress_only" if not all_completed else
                  "all_case_progress_complete_global_gate_pending",
        "actual_hits_are_measured_from_child_test_records": True,
        "per_assertion_events_are_flushed_and_reaggregated": True,
        "formal_t2_accepted": False,
    }
    progress_rows: list[dict[str, Any]] = [progress_header]
    partial_progress_sources: list[dict[str, Any]] = []
    for case_id in expected_cases:
        result = case_results.get(case_id)
        source_dir = result["case_dir"] if result else cases_root / case_id
        source_progress = source_dir / "artifacts" / "case_progress.jsonl"
        if not source_progress.is_file():
            continue
        child_rows, prefix = load_jsonl_complete_prefix(source_progress)
        observed_prefix = summarize_authority_case_progress_prefix(
            case_id, child_rows, coverage,
            coverage_map_sha256=coverage_map_sha256,
            driver_sha256=driver_sha256)
        partial_progress_sources.append({
            "case_id": case_id, "receipt": file_receipt(source_progress),
            "complete_prefix": prefix,
            "observed_flushed_prefix": observed_prefix,
            "formal_t2_accepted": False,
        })
        if not child_rows or child_rows[0].get("event") != "header" or \
                child_rows[0].get("selected_case_id") != case_id or \
                child_rows[0].get("coverage_map_sha256") != coverage_map_sha256 or \
                child_rows[0].get("source_sha256") != driver_sha256:
            continue
        progress_rows.extend(row for row in child_rows[1:])
    aggregate_progress_path = artifacts / "case_progress.jsonl"
    write_jsonl_new(aggregate_progress_path, progress_rows)
    aggregate_progress_receipt = file_receipt(aggregate_progress_path)
    if all_completed:
        merged = {site_id: 0 for site_id in _authority_source_ids(coverage)}
        for case_id in expected_cases:
            for site_id, count in case_results[case_id]["hits"].items():
                merged[site_id] += count
        expected_full = hit_plan["expected_phase_site_hits"]
        if merged != expected_full or sum(merged.values()) != 118 or \
                sum(count > 0 for count in merged.values()) != 75:
            all_completed = False
            stop_reason = "authority_case_aggregate_hit_mismatch"
            exit_code = 1
            phase_error = "measured 9-case aggregate differs from 75 sites/118 hits"
    if all_completed:
        case_summaries = [case_results[case_id]["summary"] for case_id in expected_cases]
        base = case_summaries[0]
        observations: list[dict[str, Any]] = []
        transport_values: list[dict[str, Any]] = []
        for case_id in expected_cases:
            case_artifacts = case_results[case_id]["case_dir"] / "artifacts"
            observations.extend(load_jsonl(case_artifacts / "observations.jsonl"))
            transport_values.append(load_json(
                case_artifacts / "context_transport_observation.json"))
        if [row.get("case_id") for row in observations] != expected_cases or \
                any(value != transport_values[0] for value in transport_values[1:]):
            all_completed = False
            stop_reason = "authority_case_aggregate_observation_mismatch"
            exit_code = 1
            phase_error = "case observation/context transport aggregate mismatch"
    if all_completed:
        observations_path = artifacts / "observations.jsonl"
        write_jsonl_new(observations_path, observations)
        transport_path = artifacts / "context_transport_observation.json"
        with transport_path.open("xb") as stream:
            stream.write((cases_root / expected_cases[0] / "artifacts" /
                          "context_transport_observation.json").read_bytes())
            stream.flush()
            os.fsync(stream.fileno())
        combined_summary = dict(base)
        combined_summary.update({
            "schema": "vnext-t2-independent-actual-negative-shard-summary-r5",
            "status": "pass", "shard": "authority",
            "observed_case_ids": expected_cases,
            "observed_case_count": len(expected_cases),
            "authority_case_completion_count_observed": len(expected_cases),
            "authority_case_source_phase_site_count_static_plan": 175,
            "authority_case_nonzero_site_count_static_plan": 75,
            "authority_case_expected_hit_count_static_plan": 118,
            "assertion_site_hit_count_observed": sum(merged.values()),
            "assertion_site_hit_counts": dict(sorted(merged.items())),
            "unmapped_assertion_sources": [],
            "authority_case_progress_path": "case_progress.jsonl",
            "authority_case_progress_sha256": aggregate_progress_receipt["sha256"],
            "observation_file_sha256": file_receipt(observations_path)["sha256"],
            "context_transport_observation_sha256": file_receipt(transport_path)["sha256"],
            "formal_t2_accepted": False,
        })
        write_json_new(artifacts / "summary.json", combined_summary)
        write_json_new(artifacts / "authority_case_aggregate.json", {
            "schema": "vnext-t2-authority-case-aggregate-r1",
            "status": "all_nine_natural_exit_zero_actual_hit_receipts",
            "case_order": expected_cases,
            "case_receipts": child_phase_receipts,
            "assertion_site_hit_counts_observed": dict(sorted(merged.items())),
            "assertion_site_count_observed": 175,
            "nonzero_site_count_observed": sum(count > 0 for count in merged.values()),
            "assertion_site_hit_count_observed": sum(merged.values()),
            "formal_t2_accepted": False,
        })
    else:
        write_json_new(artifacts / "authority_case_partial.json", {
            "schema": "vnext-t2-authority-case-partial-r2",
            "status": "partial_no_aggregate_acceptance",
            "expected_case_order": expected_cases,
            "completed_natural_case_ids": [case_id for case_id in expected_cases
                                            if case_id in case_results],
            "remaining_case_ids": [case_id for case_id in expected_cases
                                   if case_id not in case_results],
            "case_rows": case_rows,
            "phase_error": phase_error,
            "authority_phase_wall_budget_seconds": authority_phase_timeout,
            "authority_case_wall_budget_seconds": authority_case_timeout,
            "working_set_limit_bytes": working_set_limit_bytes,
            "partial_case_progress_receipt": aggregate_progress_receipt,
            "partial_progress_source_receipts": partial_progress_sources,
            "partial_actual_source_hit_count_observed": sum(
                row["observed_flushed_prefix"].get(
                    "source_site_hit_count_observed", 0)
                for row in partial_progress_sources),
            "partial_progress_prefix_validation_statuses": {
                row["case_id"]: row["observed_flushed_prefix"]["status"]
                for row in partial_progress_sources},
            "formal_t2_accepted": False,
        })
    elapsed = time.monotonic() - started
    phase = {
        "schema": "vnext-t2-independent-negative-authority-case-phase-r3",
        "name": "actual_formal_authority",
        "command": [row.get("phase") for row in child_phase_receipts],
        "started_utc": started_utc, "ended_utc": utc(), "seconds": elapsed,
        "exit_code": 0 if all_completed else exit_code,
        "stop_reason": "natural_exit" if all_completed else stop_reason,
        "timeout_seconds": authority_phase_timeout,
        "per_case_timeout_seconds": authority_case_timeout,
        "working_set_limit_bytes": working_set_limit_bytes,
        "peak_process_tree_working_set_bytes": max((
            load_json(Path(row["phase"]["path"]))["peak_process_tree_working_set_bytes"]
            for row in child_phase_receipts), default=0),
        "completed_case_ids": [case_id for case_id in expected_cases
                                if case_id in case_results],
        "case_count_expected": 9,
        "case_rows": case_rows,
        "aggregate_progress": aggregate_progress_receipt,
        "summary": file_receipt(artifacts / "summary.json")
                    if (artifacts / "summary.json").is_file() else None,
        "residual_heavy_process_audit": heavy_processes(),
        "residual_heavy_processes": [],
        "process_tree_sample_count": sum(
            load_json(Path(row["phase"]["path"])).get(
                "process_tree_sample_count", 0)
            for row in child_phase_receipts),
        "process_tree_samples_complete": all(
            load_json(Path(row["phase"]["path"])).get(
                "process_tree_samples_complete") is True
            for row in child_phase_receipts
            if row.get("reused") is not True),
        "final_process_tree_audit": {
            "schema": "vnext-t2-authority-final-tree-audit-r1",
            "complete": all(
                load_json(Path(row["phase"]["path"])).get(
                    "final_process_tree_audit", {}).get("complete") is True
                for row in child_phase_receipts),
            "root_exit_confirmed": all(
                load_json(Path(row["phase"]["path"])).get(
                    "final_process_tree_audit", {}).get(
                        "root_exit_confirmed") is True
                for row in child_phase_receipts),
            "residual_descendant_processes": [],
        },
        "termination_receipt": None,
        "formal_t2_accepted": False,
    }
    residual_audit = phase["residual_heavy_process_audit"]
    phase["residual_heavy_processes"] = residual_audit.get("processes", [])
    phase["residual_process_audit"] = residual_audit
    if residual_audit.get("complete") is not True or \
            residual_audit.get("processes"):
        phase["stop_reason"] = "residual_process_audit_incomplete" \
            if residual_audit.get("complete") is not True else \
            "residual_heavy_processes_present"
        phase["exit_code"] = 1
        phase["phase_error"] = "aggregate residual process audit was incomplete or nonempty"
    write_json_new(authority_dir / "phase.json", phase)
    return phase


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--julia", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--protocol-sha256", required=True)
    parser.add_argument("--positive-evidence", required=True)
    parser.add_argument("--positive-final-sha256", required=True)
    parser.add_argument("--positive-pipeline-final-sha256", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--phase-timeout", type=float, required=True)
    parser.add_argument("--authority-phase-timeout", type=float, required=True)
    parser.add_argument("--authority-case-timeout", type=float, required=True)
    parser.add_argument("--resume-authority-from")
    parser.add_argument("--working-set-limit", type=int, required=True)
    args = parser.parse_args()

    project = Path(args.project).resolve()
    if project != ROOT:
        raise ValueError("project must resolve to repository root")
    if args.phase_timeout != 480 or \
            args.authority_phase_timeout != AUTHORITY_PHASE_TIMEOUT_SECONDS or \
            args.authority_case_timeout != AUTHORITY_CASE_TIMEOUT_SECONDS or \
            args.working_set_limit != AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise ValueError("negative formal phases require 480s default, 600s preflight override, 2GiB, and authority 2400s/2400s gates")
    _source_inputs().require_local_execution(Path(args.protocol))
    protocol_path = Path(args.protocol).resolve()
    protocol_path.relative_to(ROOT)
    positive_root = Path(args.positive_evidence).resolve()
    positive_root.relative_to(ROOT)
    output = Path(args.evidence_dir).resolve()
    require_t2_execution_leaf(output)
    output.mkdir(parents=True, exist_ok=False)

    protocol = verify_protocol(protocol_path, args.protocol_sha256)
    configure_managed_lifecycle(protocol, args.protocol_sha256)
    if protocol.get("driver_path") != ACTUAL_DRIVER.relative_to(ROOT).as_posix() or \
            protocol.get("driver_path") not in protocol.get("inputs", {}):
        raise RuntimeError("negative driver path is not bound by protocol inputs")
    runtime_plan = verify_runtime_plan(protocol)
    if protocol.get("resource_gates", {}).get(
            "phase_wall_timeout_overrides") != {
                "actual_formal_preflight": PREFLIGHT_PHASE_TIMEOUT_SECONDS}:
        raise RuntimeError("preflight phase timeout override differs from controller policy")
    coverage = load_json(ROOT / protocol["coverage_map"]["path"])
    coverage_receipt = file_receipt(ROOT / protocol["coverage_map"]["path"])
    if coverage_receipt["sha256"] != protocol["coverage_map"]["sha256"] or \
            protocol["inputs"].get(protocol["coverage_map"]["path"]) != {
                "path": protocol["coverage_map"]["path"],
                "bytes": coverage_receipt["bytes"],
                "sha256": coverage_receipt["sha256"],
            }:
        raise RuntimeError("negative coverage-map input drift")
    runtime_plan = verify_coverage_runtime_plan(protocol, coverage)
    verify_frozen_coverage_map_counts(coverage, runtime_plan)
    authority_plan = coverage.get("successor_assertion_runtime_hit_plan", {}).get(
        "authority_case_hit_plan")
    authority_source_ids = _authority_source_ids(coverage)
    if not isinstance(authority_plan, dict) or \
            authority_plan.get("schema") != "vnext-t2-authority-case-hit-plan-r1" or \
            authority_plan.get("status") != "static_plan_actual_case_hits_pending" or \
            authority_plan.get("case_order") != AUTHORITY_CASE_ORDER or \
            authority_plan.get("source_site_count") != 175 or \
            authority_plan.get("nonzero_site_count") != 75 or \
            authority_plan.get("expected_hit_count") != 118 or \
            set(authority_plan.get("expected_phase_site_hits", {})) != authority_source_ids or \
            len(authority_plan.get("case_site_hit_counts", {})) != 9:
        raise RuntimeError("authority case-hit plan coverage contract mismatch")
    authority_join = {site_id: 0 for site_id in authority_source_ids}
    for case_id in AUTHORITY_CASE_ORDER:
        case_hits = authority_plan["case_site_hit_counts"].get(case_id)
        if not isinstance(case_hits, dict) or set(case_hits) != authority_source_ids:
            raise RuntimeError(f"authority case static site inventory invalid: {case_id}")
        for site_id, count in case_hits.items():
            if not isinstance(count, int) or count < 0:
                raise RuntimeError(f"authority case static hit is malformed: {case_id}:{site_id}")
            authority_join[site_id] += count
    if authority_join != authority_plan["expected_phase_site_hits"] or \
            sum(authority_join.values()) != 118:
        raise RuntimeError("authority case static plan does not reaggregate to 118")
    coverage_map_sha256 = protocol["coverage_map"]["sha256"]
    positive_input_pin_join = verify_positive_reuse_input_pins(protocol)
    frozen_positive = protocol["positive_evidence"]
    if args.positive_final_sha256.lower() != frozen_positive[
            "formal_serial_replay"]["sha256"] or \
            args.positive_pipeline_final_sha256.lower() != frozen_positive[
                "pipeline_final"]["sha256"]:
        raise RuntimeError("positive CLI hashes differ from frozen protocol")
    verify_frozen_positive_evidence(positive_root, frozen_positive)
    julia_executable = Path(args.julia).resolve()
    if str(julia_executable).lower() != str(Path(
            protocol["julia_executable"]).resolve()).lower():
        raise ValueError("Julia executable differs from frozen protocol")
    head_query_receipts: dict[str, Any] = {}
    head_before = git_head(
        output=output / "repository_head_before",
        timeout_seconds=args.phase_timeout,
        receipts=head_query_receipts, receipt_key="before")
    inputs_before = input_receipts(protocol)
    resume_authority_from = (Path(args.resume_authority_from).resolve()
        if args.resume_authority_from else None)
    if resume_authority_from is not None:
        require_t2_execution_leaf(resume_authority_from)
        if resume_authority_from == output:
            raise ValueError("authority resume source must differ from output leaf")
    baseline_heavy = heavy_processes()
    if baseline_heavy.get("complete") is not True:
        raise RuntimeError("baseline residual process audit incomplete: " +
                           json.dumps(baseline_heavy, sort_keys=True))
    if baseline_heavy.get("processes"):
        raise RuntimeError("baseline contains residual heavy processes: " +
                           json.dumps(baseline_heavy["processes"], sort_keys=True))
    phases: list[dict[str, Any]] = []
    case_receipts: dict[str, Any] = {}
    executed_case_hits: list[str] = []
    assertion_site_hit_summaries: list[dict[str, Any]] = []
    assertion_site_hit_aggregate: dict[str, Any] | None = None
    ast_inventory_assertion_sites = 0
    projection_assertion_sites_completed = 0
    context_transport_assertion_sites_completed = 0
    failure: dict[str, Any] | None = None
    pipeline_pass = False
    write_json_new(output / "pipeline_start.json", {
        "schema": "vnext-t2-independent-negative-pipeline-start-r4",
        "created_utc": utc(), "repository_head": head_before,
        "repository_head_query_receipts": dict(head_query_receipts),
        "protocol": file_receipt(protocol_path),
        "protocol_expected_sha256": args.protocol_sha256.lower(),
        "positive_evidence": str(positive_root),
        "positive_final_expected_sha256": args.positive_final_sha256.lower(),
        "positive_pipeline_final_expected_sha256":
            args.positive_pipeline_final_sha256.lower(),
        "positive_r3_runtime_input_pin_join": positive_input_pin_join,
        "inputs_before": inputs_before,
        "phase_timeout_seconds": args.phase_timeout,
        "preflight_phase_timeout_seconds": PREFLIGHT_PHASE_TIMEOUT_SECONDS,
        "authority_phase_timeout_seconds": args.authority_phase_timeout,
        "authority_case_timeout_seconds": args.authority_case_timeout,
        "authority_case_order": AUTHORITY_CASE_ORDER,
        "authority_case_resume_from": str(resume_authority_from)
            if resume_authority_from else None,
        "process_tree_working_set_limit_bytes": args.working_set_limit,
        "baseline_heavy_processes": baseline_heavy,
        "runtime_execution_plan_sha256": sha256_bytes(json.dumps(
            runtime_plan, sort_keys=True, separators=(",", ":")).encode()),
        "ast_inventory_plan_sha256": sha256_bytes(json.dumps(
            coverage["ast_inventory_plan"], sort_keys=True,
            separators=(",", ":")).encode()),
        "expected_ast_inventory_assertion_site_count":
            coverage["ast_inventory_plan"]["total_assertion_site_count"],
        "expected_versioned_product_repair_assertion_site_count": 24,
        "expected_preserved_successor_assertion_site_count": 191,
        "expected_preserved_successor_runtime_hit_count_static_plan": 530,
        "expected_context_transport_assertion_site_count_static_plan":
            coverage["context_transport_assertion_site_count"],
        "expected_context_transport_runtime_hit_count_static_plan":
            coverage["context_transport_expected_runtime_hit_count"],
        "expected_successor_assertion_site_count_static_plan":
            coverage["successor_assertion_runtime_hit_plan"][
                "assertion_site_count"],
        "expected_successor_assertion_runtime_hit_count_static_plan":
            coverage["successor_assertion_runtime_hit_plan"][
                "expected_runtime_hit_count"],
        "expected_phase_order": protocol["phase_order"],
        "expected_unique_case_count":
            runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count":
            runtime_plan["expected_runtime_case_hit_count"],
        "julia_threads": 1, "openblas_threads": 1,
        "python_dont_write_bytecode": True,
        "formal_t2_accepted": False,
        "actual_model_attestation": "unavailable",
    })

    try:
        if head_before != EXPECTED_HEAD:
            raise RuntimeError("repository HEAD mismatch")
        verify_baseline_heavy_processes_clear(baseline_heavy)
        positive = read_positive(
            positive_root, args.positive_final_sha256,
            args.positive_pipeline_final_sha256)
        positive_receipts_consumed = verify_frozen_positive_evidence(
            positive_root, frozen_positive)
        environment = os.environ.copy()
        environment["JULIA_NUM_THREADS"] = "1"
        environment["OPENBLAS_NUM_THREADS"] = "1"
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        julia_common = [str(julia_executable), "--project=" + str(project),
            "--startup-file=no", "--history-file=no", "--threads=1"]

        parse_manifest_path = output / "runtime_parse_manifest.tsv"
        parse_manifest_receipt = write_parse_manifest(
            parse_manifest_path, protocol)
        parse_dir = output / "parse_gate"
        parse_phase = run_phase("parse_gate", julia_common + [
            str(PARSE_GATE), str(parse_manifest_path)], parse_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(parse_phase)
        require_natural(parse_phase, exit_zero=True)
        case_receipts["parse_gate"] = {
            "manifest": parse_manifest_receipt,
            "parsed_count": len(protocol["julia_parse_paths"]),
            "positive_evidence_receipt_count":
                len(positive_receipts_consumed),
        }

        ast_dir = output / "coverage_ast_inventory"
        ast_receipt_path = ast_dir / "ast_inventory.json"
        ast_phase = run_phase("coverage_ast_inventory", julia_common + [
            str(AST_INVENTORY_DRIVER),
            str(ROOT / protocol["coverage_map"]["path"]),
            str(ast_receipt_path)], ast_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(ast_phase)
        require_natural(ast_phase, exit_zero=True)
        ast_receipt = verify_ast_inventory(ast_receipt_path, coverage)
        ast_inventory_assertion_sites = ast_receipt[
            "total_assertion_site_count"]
        case_receipts["coverage_ast_inventory"] = {
            "receipt": file_receipt(ast_receipt_path),
            "source_count": ast_receipt["source_count"],
            "old_assertion_site_count":
                ast_receipt["old_assertion_site_count"],
            "successor_assertion_site_count":
                ast_receipt["successor_assertion_site_count"],
            "projection_assertion_site_count":
                ast_receipt["projection_assertion_site_count"],
            "total_assertion_site_count": ast_inventory_assertion_sites,
        }

        projection_dir = output / "projection24_cross_run_validation"
        projection_reuse_receipt_path = projection_dir / "reuse_receipt.json"
        projection_phase = run_phase(
            "projection24_cross_run_validation",
            [sys.executable, "-B", str(PROJECTION_REUSE_VALIDATOR),
             str(protocol_path), str(projection_reuse_receipt_path)],
            projection_dir, timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(projection_phase)
        require_natural(projection_phase, exit_zero=True)
        projection_reuse = load_json(projection_reuse_receipt_path)
        if projection_reuse.get("status") != "pass" or \
                projection_reuse.get("natural_exit_zero") is not True or \
                projection_reuse.get("post_assertion_pass_marker") is not True or \
                projection_reuse.get("assertion_sites_completed") != 24:
            raise RuntimeError("projection24 cross-run validation failed")
        projection_assertion_sites_completed = 24
        case_receipts["projection24_cross_run_validation"] = {
            "receipt": file_receipt(projection_reuse_receipt_path),
            "source_phase_files": projection_reuse["phase_files"],
            "dependency_count": projection_reuse["dependency_count"],
            "assertion_sites_completed": 24,
            "completion_evidence":
                "exact_stage_closure_plus_natural_exit_zero_and_pass_marker",
            "formal_qualification": False,
        }

        actual_common = [str(ACTUAL_DRIVER)]
        actual_authorities = [str(positive["manifest_path"]),
            positive["manifest_sha256"], str(positive["verification_path"]),
            positive["verification_sha256"], str(positive["candidate_path"]),
            positive["candidate_sha256"], str(positive["package_path"]),
            positive["package_sha256"]]
        baseline_dir = output / "actual_formal_baseline"
        baseline_artifacts = baseline_dir / "artifacts"
        context_path = baseline_artifacts / "baseline_context.jls"
        authorization_path = output / "actual_formal_baseline_authorization.json"
        baseline_phase = run_phase("actual_formal_baseline",
            julia_common + actual_common + ["baseline", *actual_authorities,
                str(context_path), "create", str(authorization_path), "create",
                str(baseline_artifacts),
                str(ROOT / protocol["coverage_map"]["path"]),
                coverage_map_sha256], baseline_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(baseline_phase)
        require_natural(baseline_phase, exit_zero=True)
        baseline_summary_path = baseline_artifacts / "summary.json"
        baseline_summary = load_json(baseline_summary_path)
        if baseline_summary.get("status") != "pass" or \
                baseline_summary.get("observed_case_ids") != \
                runtime_plan["actual_formal_phase_case_ids"][
                    "actual_formal_baseline"] or \
                baseline_summary.get("source_revalidation_status") != \
                "source_ready" or \
                baseline_summary.get("producer_package_unchanged") is not True or \
                baseline_summary.get("candidate_receipt_unchanged") is not True or \
                baseline_summary.get("package_wire_unchanged") is not True:
            raise RuntimeError("actual formal baseline summary failed")
        assertion_site_hit_summaries.append(baseline_summary)
        baseline_site_hits = verify_assertion_site_hit_summary(
            baseline_summary, coverage, "actual_formal_baseline",
            coverage_map_sha256=coverage_map_sha256)
        context_receipt = file_receipt(context_path)
        if baseline_summary.get("context_receipt", {}).get("bytes") != \
                context_receipt["bytes"] or \
                baseline_summary.get("context_receipt", {}).get("sha256") != \
                context_receipt["sha256"]:
            raise RuntimeError("actual formal context receipt mismatch")
        authorization = write_baseline_authorization(
            authorization_path, baseline_dir, baseline_phase,
            baseline_summary, context_path)
        authorization_receipt = file_receipt(authorization_path)
        baseline_observations_path = baseline_artifacts / "observations.jsonl"
        baseline_observations = load_jsonl(baseline_observations_path)
        baseline_observation_ids = [row.get("case_id")
                                    for row in baseline_observations]
        if baseline_observation_ids != runtime_plan[
                "actual_formal_phase_observation_ids"][
                    "actual_formal_baseline"]:
            raise RuntimeError("actual baseline observation inventory mismatch")
        aggregated_actual_case_ids = list(
            baseline_summary["observed_case_ids"])
        aggregated_actual_observation_ids = list(baseline_observation_ids)
        executed_case_hits.extend(baseline_summary["observed_case_ids"])
        case_receipts["actual_formal_baseline"] = {
            "phase": file_receipt(baseline_dir / "phase.json"),
            "summary": file_receipt(baseline_summary_path),
            "observations": file_receipt(baseline_observations_path),
            "stage_trace": file_receipt(
                baseline_artifacts / "stage_trace.tsv"),
            "context": context_receipt,
            "authorization": authorization_receipt,
            "authorization_body": authorization,
            "case_ids": baseline_summary["observed_case_ids"],
            "observation_ids": baseline_observation_ids,
            "five_consumer_execution_count": 1,
            "assertion_site_hit_counts": baseline_site_hits,
            "assertion_site_hit_count_observed": sum(
                baseline_site_hits.values()),
        }

        actual_shards = (
            ("actual_formal_preflight", "preflight"),
            ("actual_formal_authority", "authority"),
            ("actual_formal_fault_n10", "fault_n10"),
            ("actual_formal_t1_handoff", "t1_handoff"),
        )
        for phase_name, mode in actual_shards:
            shard_dir = output / phase_name
            shard_artifacts = shard_dir / "artifacts"
            if mode == "authority":
                shard_phase = run_authority_case_phase(
                    julia_common=julia_common, authorities=actual_authorities,
                    context_path=context_path,
                    context_sha256=context_receipt["sha256"],
                    authorization_path=authorization_path,
                    authorization_sha256=authorization_receipt["sha256"],
                    coverage_map_path=ROOT / protocol["coverage_map"]["path"],
                    coverage_map_sha256=coverage_map_sha256,
                    coverage=coverage,
                    driver_sha256=protocol["inputs"][
                        protocol["driver_path"]]["sha256"],
                    authority_dir=shard_dir, environment=environment,
                    working_set_limit_bytes=args.working_set_limit,
                    authority_phase_timeout=args.authority_phase_timeout,
                    authority_case_timeout=args.authority_case_timeout,
                    resume_from=resume_authority_from,
                    current_protocol_path=protocol_path,
                    current_protocol_sha256=args.protocol_sha256.lower(),
                    current_inputs=inputs_before,
                    repository_head=head_before)
            else:
                shard_command = build_actual_formal_shard_command(
                    julia_common, mode, actual_authorities,
                    context_path, context_receipt["sha256"],
                    authorization_path, authorization_receipt["sha256"],
                    shard_artifacts, ROOT / protocol["coverage_map"]["path"],
                    coverage_map_sha256)
                shard_phase = run_phase(phase_name,
                    shard_command, shard_dir,
                    timeout_seconds=actual_formal_shard_timeout(
                        mode, args.phase_timeout),
                    working_set_limit_bytes=args.working_set_limit,
                    environment=environment)
            phases.append(shard_phase)
            require_natural(shard_phase, exit_zero=True)
            shard_summary_path = shard_artifacts / "summary.json"
            shard_summary = load_json(shard_summary_path)
            expected_ids = runtime_plan["actual_formal_phase_case_ids"][
                phase_name]
            if shard_summary.get("status") != "pass" or \
                    shard_summary.get("shard") != mode or \
                    shard_summary.get("observed_case_ids") != expected_ids or \
                    shard_summary.get("producer_package_unchanged") is not True or \
                    shard_summary.get("candidate_receipt_unchanged") is not True or \
                    shard_summary.get("context_unchanged") is not True or \
                    shard_summary.get("source_revalidation_status") != \
                    "source_ready" or \
                    shard_summary.get("rebuilt_input_full_content_join") is not True or \
                shard_summary.get("package_wire_unchanged") is not True or \
                shard_summary.get("prior_ledger_unchanged") is not True:
                raise RuntimeError(f"actual formal shard summary failed: {mode}")
            assertion_site_hit_summaries.append(shard_summary)
            shard_site_hits = verify_assertion_site_hit_summary(
                shard_summary, coverage, phase_name,
                coverage_map_sha256=coverage_map_sha256)
            transport_path = shard_artifacts / \
                "context_transport_observation.json"
            transport_observation = verify_context_transport_observation(
                transport_path, mode)
            observations_path = shard_artifacts / "observations.jsonl"
            observations = load_jsonl(observations_path)
            observation_ids = [row.get("case_id") for row in observations]
            expected_observations = runtime_plan[
                "actual_formal_phase_observation_ids"][phase_name]
            if observation_ids != expected_observations:
                raise RuntimeError(
                    f"actual formal shard observation inventory mismatch: {mode}")
            required_observation_fields = {
                "value_type", "status", "resolution", "first_reason", "errors",
                "package_fingerprint_before", "package_fingerprint_after",
                "package_artifact_before", "package_artifact_after",
                "prior_ledger_fingerprint_before",
                "prior_ledger_fingerprint_after", "attempted_counts",
                "committed_counts",
            }
            for row in observations:
                if row.get("schema") != \
                        "vnext-t2-independent-negative-observation-r1" or \
                        not required_observation_fields.issubset(row):
                    raise RuntimeError(
                        f"actual observation schema mismatch: {row.get('case_id')}")
            aggregated_actual_case_ids.extend(shard_summary["observed_case_ids"])
            aggregated_actual_observation_ids.extend(observation_ids)
            executed_case_hits.extend(shard_summary["observed_case_ids"])
            case_receipts[phase_name] = {
                "phase": file_receipt(shard_dir / "phase.json"),
                "summary": file_receipt(shard_summary_path),
                "authority_case_aggregate": file_receipt(
                    shard_artifacts / "authority_case_aggregate.json")
                    if mode == "authority" else None,
                "observations": file_receipt(observations_path),
                "context_transport_observation": file_receipt(transport_path),
                "context_transport_values": transport_observation,
                "stage_trace": file_receipt(
                    shard_artifacts / "stage_trace.tsv"),
                "case_ids": shard_summary["observed_case_ids"],
                "observation_ids": observation_ids,
                "baseline_consumer_execution_count": 0,
                "assertion_site_hit_counts": shard_site_hits,
                "assertion_site_hit_count_observed": sum(
                    shard_site_hits.values()),
                "protected_prior_ledger_source":
                    "actual_formal_baseline natural-zero five-consumer context",
            }

        expected_actual_case_ids = runtime_plan["actual_formal_summary_case_ids"]
        if aggregated_actual_case_ids != expected_actual_case_ids:
            raise RuntimeError("actual formal sharded case inventory mismatch")
        if aggregated_actual_observation_ids != runtime_plan[
                "actual_formal_observation_ids"]:
            raise RuntimeError("actual sharded observe-first inventory mismatch")
        case_receipts["actual_formal_shards"] = {
            "phase_names": [name for name, _ in actual_shards],
            "case_ids": aggregated_actual_case_ids,
            "observation_ids": aggregated_actual_observation_ids,
            "unique_baseline_five_consumer_execution_count": 1,
            "context_transport_validation_execution_count": 4,
        }

        for phase_name, mode, expected_case in (
                ("supplementary_edited_operation", "edited_operation",
                 "SUP_EDITED_OPERATION_DEFERRAL"),
                ("supplementary_child_coupling", "child_coupling",
                 "SUP_CHILD_COUPLING_CONTRADICTION")):
            supplementary_dir = output / phase_name
            supplementary_artifacts = supplementary_dir / "artifacts"
            supplementary = run_phase(phase_name,
                julia_common + [str(SUPPLEMENTARY_DRIVER), mode,
                                str(supplementary_artifacts),
                                str(ROOT / protocol["coverage_map"]["path"]),
                                coverage_map_sha256],
                supplementary_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(supplementary)
            require_natural(supplementary, exit_zero=True)
            supplementary_summary = load_json(
                supplementary_artifacts / "summary.json")
            expected_summary_ids = runtime_plan[
                "supplementary_summary_case_ids"][mode]
            if supplementary_summary.get("status") != "pass" or \
                    supplementary_summary.get("formal_qualification") is not False or \
                    supplementary_summary.get("mode") != mode or \
                    supplementary_summary.get("observed_case_ids") != \
                    expected_summary_ids:
                raise RuntimeError(
                    f"supplementary contract summary failed: {phase_name}")
            assertion_site_hit_summaries.append(supplementary_summary)
            supplementary_site_hits = verify_assertion_site_hit_summary(
                supplementary_summary, coverage, phase_name,
                coverage_map_sha256=coverage_map_sha256)
            supplementary_observations = load_jsonl(
                supplementary_artifacts / "observations.jsonl")
            if len(supplementary_observations) != 1 or \
                    supplementary_observations[0].get("case_id") != expected_case or \
                    supplementary_observations[0].get("formal_qualification") \
                    is not False:
                raise RuntimeError(
                    f"supplementary observation mismatch: {phase_name}")
            executed_case_hits.extend(expected_summary_ids)
            case_receipts[phase_name] = {
                "summary": file_receipt(
                    supplementary_artifacts / "summary.json"),
                "observations": file_receipt(
                    supplementary_artifacts / "observations.jsonl"),
                "case_ids": expected_summary_ids,
                "assertion_site_hit_counts": supplementary_site_hits,
                "assertion_site_hit_count_observed": sum(
                    supplementary_site_hits.values()),
            }

        attacks = output / "attack_inputs"
        attacks.mkdir()
        original_bytes = positive["package_path"].read_bytes()
        truncated = original_bytes[:max(1, len(original_bytes) // 2)]
        truncated_path = attacks / "candidate_package_truncated.jls"
        truncated_path.write_bytes(truncated)
        zero_path = attacks / "candidate_package_zero.jls"
        zero_path.write_bytes(b"")
        wrong_raw_hash = sha256_bytes(b"wrong producer package hash")
        artifact_specs = (
            ("artifact_hash_precondition", "raw_hash_mismatch",
             positive["package_path"], wrong_raw_hash),
            ("artifact_recomputed_corrupt", "recomputed_corrupt",
             truncated_path, sha256_bytes(truncated)),
            ("artifact_zero_malformed", "zero_malformed",
             zero_path, sha256_bytes(b"")),
        )
        for name, mode, attacked_path, expected_hash in artifact_specs:
            phase_dir = output / name
            receipt_path = phase_dir / "artifact_receipt.json"
            phase = run_phase(name, julia_common + [str(ARTIFACT_DRIVER),
                mode, str(positive["package_path"]), str(attacked_path),
                expected_hash, str(receipt_path)], phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=True)
            receipt = verify_artifact_helper(
                receipt_path, mode, attacked_path, expected_hash)
            case_id = runtime_plan["helper_phase_case_ids"][name]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "receipt": file_receipt(receipt_path),
                "case_id": case_id,
                "actual_rejection": receipt["actual_rejection"],
                "consumer_attempted_counts":
                    receipt["consumer_attempted_counts"],
                "committed_counts": receipt["committed_counts"],
            }

        attack_fixture_dir = output / "artifact_attack_fixture_generation"
        attack_fixture_artifacts = attack_fixture_dir / "artifacts"
        attack_fixture = run_phase("artifact_attack_fixture_generation",
            julia_common + [str(ATTACK_FIXTURE_DRIVER),
                            str(attack_fixture_artifacts)],
            attack_fixture_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(attack_fixture)
        require_natural(attack_fixture, exit_zero=True)
        attack_receipt_path = attack_fixture_artifacts / \
            "attack_fixture_receipt.json"
        attack_receipt = load_json(attack_receipt_path)
        if attack_receipt.get("schema") != \
                "vnext-t2-independent-artifact-attack-fixtures-r1" or \
                attack_receipt.get("formal_t2_accepted") is not False:
            raise RuntimeError("artifact attack fixture receipt invalid")
        wrong_type_path = attack_fixture_artifacts / \
            "candidate_package_wrong_type.jls"
        foreign_package_path = attack_fixture_artifacts / \
            "candidate_package_foreign_valid.jls"
        for label, path, row in (
                ("wrong_type", wrong_type_path,
                 attack_receipt.get("wrong_type")),
                ("foreign_package", foreign_package_path,
                 attack_receipt.get("foreign_package"))):
            actual_receipt = file_receipt(path)
            if not isinstance(row, dict) or \
                    row.get("bytes") != actual_receipt["bytes"] or \
                    row.get("sha256") != actual_receipt["sha256"]:
                raise RuntimeError(f"artifact attack fixture drift: {label}")
        case_receipts["artifact_attack_fixture_generation"] = {
            "phase": file_receipt(attack_fixture_dir / "phase.json"),
            "receipt": file_receipt(attack_receipt_path),
            "foreign_observation": file_receipt(
                attack_fixture_artifacts / "foreign_package_observation.json"),
        }

        # Exercise the implementation-owned formal driver with the same damaged
        # producer artifacts.  These are distinct from the helper/deserializer
        # receipts above and must fail before candidate authority or consumers.
        formal_artifact_specs = (
            ("formal_driver_artifact_raw_hash_precondition", truncated_path,
             positive["package_sha256"], "producer_artifact_hash_precondition",
             "raw_sha256_mismatch"),
            ("formal_driver_artifact_deserialize_precondition", truncated_path,
             sha256_bytes(truncated), "producer_artifact_deserialize_precondition",
             "deserialize_error"),
            ("formal_driver_artifact_zero_precondition", zero_path,
             sha256_bytes(b""), "producer_artifact_deserialize_precondition",
             "deserialize_error"),
            ("formal_driver_artifact_wrong_type_precondition", wrong_type_path,
             file_receipt(wrong_type_path)["sha256"],
             "producer_artifact_deserialize_precondition", "type_invalid"),
            ("formal_driver_artifact_foreign_package_precondition",
             foreign_package_path, file_receipt(foreign_package_path)["sha256"],
             "producer_artifact_deserialize_precondition",
             "expected_admission_mismatch"),
        )
        for name, attacked_path, expected_hash, expected_stage, \
                expected_failure in \
                formal_artifact_specs:
            phase_dir = output / name
            artifacts = phase_dir / "artifacts"
            command = candidate_command(julia_common, positive, artifacts,
                positive["candidate_sha256"],
                positive["stable_projection_hash"],
                positive["result_reload_identity_hash"],
                package_path=attacked_path, package_sha256=expected_hash)
            phase = run_phase(name, command, phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            receipt = verify_uncommitted(artifacts, expected_stage,
                zero_call=True, precondition_failure=expected_failure)
            if file_receipt(positive["package_path"])["sha256"] != \
                    positive["package_sha256"]:
                raise RuntimeError("original producer package changed")
            case_id = runtime_plan["formal_artifact_phase_case_ids"][name]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "phase": file_receipt(phase_dir / "phase.json"),
                "receipt": file_receipt(
                    artifacts / "replay_uncommitted_attempt.json"),
                "stage": receipt["stage"],
                "precondition_failure": receipt["precondition_failure"],
                "attempted_counts": receipt["attempted_counts"],
                "committed_counts": receipt["committed_counts"],
                "attacked_artifact": file_receipt(attacked_path),
                "original_artifact": file_receipt(positive["package_path"]),
                "runtime_consumer_count_evidence": "implementation receipt r2",
                "case_id": case_id,
            }

        # The versioned implementation driver must refuse any occupied target
        # before reading formal authorities or constructing a T1/T2 chain.
        preexisting_cases: list[tuple[str, dict[str, bytes]]] = []
        for owned in OWNED_CANDIDATE_ARTIFACTS:
            preexisting_cases.append((
                "preexisting_" + owned.replace(".", "_"),
                {owned: ("sentinel:" + owned).encode()}))
        success_bytes = {
            "candidate_package.jls": positive["package_path"].read_bytes(),
            "candidate_t1_admission_receipt.json":
                positive["candidate_path"].read_bytes(),
            "t2_result.jls":
                (positive["producer"] / "t2_result.jls").read_bytes(),
            "run_receipt.json":
                positive["producer_receipt_path"].read_bytes(),
        }
        preexisting_cases.append(("preexisting_prior_success_set", success_bytes))
        preexisting_cases.append(("preexisting_prior_uncommitted", {
            "replay_uncommitted_attempt.json": b"prior-uncommitted-sentinel\n"}))
        wrong_candidate = sha256_bytes(b"wrong candidate receipt identity")
        for name, seeded in preexisting_cases:
            phase_dir = output / name
            artifacts = phase_dir / "artifacts"
            artifacts.mkdir(parents=True)
            before = {}
            for filename, data in seeded.items():
                path = artifacts / filename
                path.write_bytes(data)
                before[filename] = file_receipt(path)
            phase = run_phase(name, candidate_command(julia_common, positive,
                artifacts, wrong_candidate, positive["stable_projection_hash"],
                positive["result_reload_identity_hash"]), phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment, precreated=True)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            expected_first_owned = next(
                owned for owned in OWNED_CANDIDATE_ARTIFACTS
                if owned in seeded)
            observed_first_error = require_output_guard_first_error(
                phase_dir / "stderr.raw", expected_first_owned)
            after = {filename: file_receipt(artifacts / filename)
                     for filename in seeded}
            if before != after:
                raise RuntimeError(f"preexisting bytes changed: {name}")
            if set(path.name for path in artifacts.iterdir()) != set(seeded):
                raise RuntimeError(f"preexisting guard mixed artifacts: {name}")
            case_id = runtime_plan[
                "preexisting_owned_target_semantic_case"]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "before": before, "after": after,
                "phase": file_receipt(phase_dir / "phase.json"),
                "case_id": case_id,
                "first_error": observed_first_error,
            }

        symlink_case: dict[str, Any]
        symlink_phase_dir = output / "preexisting_symlink_owned_target"
        symlink_artifacts = symlink_phase_dir / "artifacts"
        symlink_artifacts.mkdir(parents=True)
        external = output / "symlink_external_sentinel.bin"
        external.write_bytes(b"external-sentinel-never-overwrite\n")
        external_before = file_receipt(external)
        link = symlink_artifacts / "candidate_package.jls"
        try:
            os.symlink(external, link)
        except OSError as error:
            symlink_case = {"status": "skip_symlink_unavailable",
                            "error_type": type(error).__name__,
                            "error": str(error),
                            "external_before": external_before,
                            "external_after": file_receipt(external)}
            case_receipts["preexisting_symlink_owned_target"] = symlink_case
            raise RuntimeError(
                "preexisting symlink guard not executed: " +
                type(error).__name__ + ": " + str(error))
        else:
            phase = run_phase("preexisting_symlink_owned_target",
                candidate_command(julia_common, positive, symlink_artifacts,
                    wrong_candidate, positive["stable_projection_hash"],
                    positive["result_reload_identity_hash"]),
                symlink_phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment, precreated=True)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            symlink_first_error = require_output_guard_first_error(
                symlink_phase_dir / "stderr.raw", "candidate_package.jls")
            if file_receipt(external) != external_before:
                raise RuntimeError("symlink guard changed external sentinel")
            if not link.is_symlink() or link.resolve() != external.resolve():
                raise RuntimeError("symlink guard changed the owned link")
            if {path.name for path in symlink_artifacts.iterdir()} != \
                    {"candidate_package.jls"}:
                raise RuntimeError("symlink guard published mixed artifacts")
            symlink_case = {"status": "pass", "phase": phase,
                            "external_before": external_before,
                            "external_after": file_receipt(external),
                            "link_is_symlink": link.is_symlink(),
                            "first_error": symlink_first_error}
        symlink_case_id = runtime_plan[
            "preexisting_symlink_semantic_case"]
        executed_case_hits.append(symlink_case_id)
        symlink_case["case_id"] = symlink_case_id
        case_receipts["preexisting_symlink_owned_target"] = symlink_case

        driver_negative_specs = (
            ("candidate_receipt_precondition",
             wrong_candidate, positive["stable_projection_hash"],
             positive["result_reload_identity_hash"], True),
            ("serialized_result_postcondition",
             positive["candidate_sha256"], positive["stable_projection_hash"],
             sha256_bytes(b"wrong serialized result identity"), False),
            ("stable_projection_postcondition",
             positive["candidate_sha256"],
             sha256_bytes(b"wrong stable projection identity"),
             positive["result_reload_identity_hash"], False),
        )
        for stage, candidate_hash, stable_hash, reload_hash, zero_call in \
                driver_negative_specs:
            phase_dir = output / stage
            artifacts = phase_dir / "artifacts"
            phase = run_phase(stage, candidate_command(julia_common, positive,
                artifacts, candidate_hash, stable_hash, reload_hash), phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            receipt = verify_uncommitted(artifacts, stage,
                                         zero_call=zero_call)
            case_id = runtime_plan[
                "driver_postcondition_phase_case_ids"][stage]
            executed_case_hits.append(case_id)
            case_receipts[stage] = {
                "receipt": file_receipt(
                    artifacts / "replay_uncommitted_attempt.json"),
                "stage": receipt["stage"],
                "attempted_counts": receipt["attempted_counts"],
                "committed_counts": receipt["committed_counts"],
                "case_id": case_id,
            }

        actual_hit_counts = dict(sorted(Counter(executed_case_hits).items()))
        if actual_hit_counts != runtime_plan[
                "expected_runtime_case_hit_counts"]:
            raise RuntimeError("negative runtime case-hit inventory mismatch")
        if set(executed_case_hits) != set(runtime_plan[
                "expected_unique_case_ids"]):
            raise RuntimeError("negative unique case inventory mismatch")
        if [phase["name"] for phase in phases] != protocol["phase_order"] or \
                len(phases) != protocol["expected_phase_count"]:
            raise RuntimeError("negative phase order/count mismatch")
        if ast_inventory_assertion_sites != coverage[
                "ast_inventory_plan"]["total_assertion_site_count"] or \
                projection_assertion_sites_completed != 24 or \
                len(assertion_site_hit_summaries) != 7:
            raise RuntimeError("AST/projection assertion coverage incomplete")
        assertion_site_hit_aggregate = aggregate_assertion_site_hit_receipts(
            assertion_site_hit_summaries, coverage,
            coverage_map_sha256=coverage_map_sha256)
        context_transport_assertion_sites_completed = assertion_site_hit_aggregate[
            "context_transport_assertion_sites_completed_observed"]
        inputs_after = input_receipts(protocol)
        if inputs_after != inputs_before:
            raise RuntimeError("negative formal input drift")
        head_success_check = git_head(
            output=output / "repository_head_success_check",
            timeout_seconds=args.phase_timeout,
            receipts=head_query_receipts, receipt_key="success_check")
        if head_success_check != head_before:
            raise RuntimeError("repository HEAD drift")
        final_process_audit = heavy_processes()
        if final_process_audit.get("complete") is not True:
            raise RuntimeError("negative formal final process audit incomplete: " +
                               json.dumps(final_process_audit, sort_keys=True))
        if final_process_audit.get("processes"):
            raise RuntimeError("negative formal run left residual processes: " +
                               json.dumps(final_process_audit["processes"],
                                          sort_keys=True))
        pipeline_pass = True
    except BaseException as error:
        failure = {"type": type(error).__name__, "message": str(error),
                   "traceback": "".join(traceback.format_exception(error))}
        raise
    finally:
        try:
            inputs_after_final = input_receipts(protocol)
            input_after_error = None
        except BaseException as snapshot_error:
            inputs_after_final = {}
            input_after_error = {"type": type(snapshot_error).__name__,
                                 "message": str(snapshot_error)}
        head_after: str | None = None
        head_after_error: dict[str, Any] | None = None
        try:
            head_after = git_head(
                output=output / "repository_head_finalizer",
                timeout_seconds=args.phase_timeout,
                receipts=head_query_receipts, receipt_key="finalizer")
        except BaseException as head_error:
            head_after_error = {
                "type": type(head_error).__name__,
                "message": str(head_error),
            }
            if failure is None:
                failure = {
                    "type": type(head_error).__name__,
                    "message": str(head_error),
                    "stage": "repository_head_finalizer",
                }
        if head_after is not None and head_after != head_before and failure is None:
            failure = {
                "type": "RuntimeError",
                "message": "repository HEAD drift during finalizer query",
                "stage": "repository_head_finalizer",
            }
        residual_audit = heavy_processes()
        residual = residual_audit.get("processes", [])
        guard = pipeline_pass and failure is None and \
            input_after_error is None and inputs_after_final == inputs_before and \
            head_after_error is None and head_after == head_before and \
            residual_audit.get("complete") is True and not residual
        final = {
            "schema": "vnext-t2-independent-negative-pipeline-final-r4",
            "status": "pass" if guard else "fail",
            "repository_head_before": head_before,
            "repository_head_after": head_after,
            "repository_head_after_error": head_after_error,
            "repository_head_query_receipts": dict(head_query_receipts),
            "protocol": file_receipt(protocol_path),
            "positive_final": file_receipt(
                positive_root / "formal_t2_serial_replay.json")
                if (positive_root / "formal_t2_serial_replay.json").is_file()
                else None,
            "positive_pipeline_final": file_receipt(
                positive_root / "pipeline_final.json")
                if (positive_root / "pipeline_final.json").is_file()
                else None,
            "inputs_before": inputs_before,
            "inputs_after": inputs_after_final,
            "inputs_after_error": input_after_error,
            "phases": phases, "case_receipts": case_receipts,
            "executed_case_hits": executed_case_hits,
            "executed_case_hit_counts":
                dict(sorted(Counter(executed_case_hits).items())),
            "executed_unique_case_ids": sorted(set(executed_case_hits)),
            "executed_unique_case_count": len(set(executed_case_hits)),
            "executed_runtime_case_hit_count": len(executed_case_hits),
            "assertion_site_hit_receipt_schema":
                "vnext-t2-source-site-hit-aggregate-r1",
            "assertion_site_hit_phase_summaries":
                assertion_site_hit_summaries,
            "assertion_site_runtime_hits_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_runtime_hits_observed"],
            "assertion_site_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_count_observed"],
            "assertion_site_hit_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_hit_count_observed"],
            "assertion_site_hit_aggregate": assertion_site_hit_aggregate,
            "ast_inventory_assertion_site_count":
                ast_inventory_assertion_sites,
            "versioned_product_repair_assertion_sites_completed":
                projection_assertion_sites_completed,
            "context_transport_assertion_sites_completed":
                context_transport_assertion_sites_completed,
            "context_transport_assertion_sites_completed_observed":
                context_transport_assertion_sites_completed,
            "context_transport_source_site_count_observed":
                None if assertion_site_hit_aggregate is None else 23,
            "preserved_successor_runtime_hit_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "preserved_successor_runtime_hit_count_observed"],
            "preserved_successor_assertion_site_count":
                coverage.get("preserved_successor_assertion_site_count"),
            "preserved_successor_expected_runtime_hit_count":
                coverage.get("preserved_successor_expected_runtime_hit_count"),
            "preserved_successor_expected_runtime_hit_count_static_plan":
                coverage.get("preserved_successor_expected_runtime_hit_count"),
            "residual_heavy_processes": residual,
            "failure": None if guard else failure,
            "formal_t2_accepted": False, "physical_acceptance": False,
            "scientific_acceptance": False,
            "actual_model_attestation": "unavailable",
        }
        write_json_new(output / "pipeline_final.json", final)

    final_status = final.get("status")
    print(json.dumps({
        "status": final_status, "pipeline_final":
            file_receipt(output / "pipeline_final.json"),
        "formal_t2_accepted": False,
    }, sort_keys=True), flush=True)
    if final_status == "pass":
        print("VNEXT_T2_INDEPENDENT_NEGATIVES=PASS", flush=True)
        return 0
    print("VNEXT_T2_INDEPENDENT_NEGATIVES=FAIL", flush=True)
    return 1


_R23_TABLE_PATH = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
_R23_SUPERVISOR_PATH = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
_R23_LIFECYCLE_RELATIVE_PATH = "tools/execution/windows_process_lifecycle.py"
_R23_LIFECYCLE_PATH = ROOT / _R23_LIFECYCLE_RELATIVE_PATH
_R23_MANAGED_LIFECYCLE: Any | None = None
_R23_ACTIVE_PROTOCOL_SHA256: str | None = None
_R23_ACTIVE_PROTOCOL: dict[str, Any] | None = None
_R23_TABLE_SHA256 = "b18136c52df644579e05d52a82f98541ac95a85de9be56cdae6d52baa8af74e4"
_R23_SUPERVISOR_SHA256 = "b63c56f2a3100e280e70bb484ba68b67adcfe0cb79a56bb9d7ea4ba5105f2084"


def _exec_pinned_python_source(name: str, path: Path, expected_sha256: str) -> Any:
    """Load the exact pinned source bytes without reading or writing a pyc."""
    source = path.read_bytes()
    observed = sha256_bytes(source)
    if observed != expected_sha256:
        raise RuntimeError(f"pinned Python monitor source drift: {path}")
    existing = sys.modules.get(name)
    if existing is not None:
        if getattr(existing, "__file__", None) != str(path) or \
                getattr(existing, "__source_sha256__", None) != expected_sha256:
            raise RuntimeError(f"loaded Python monitor module identity drift: {name}")
        return existing
    import types
    module = types.ModuleType(name)
    module.__file__ = str(path)
    module.__source_sha256__ = expected_sha256
    module.__package__ = ""
    sys.modules[name] = module
    try:
        exec(compile(source, str(path), "exec"), module.__dict__)
    except Exception:
        sys.modules.pop(name, None)
        raise
    return module


def _load_managed_lifecycle(protocol: Mapping[str, Any]) -> Any:
    """Load only the lifecycle implementation bound by the active protocol."""
    inputs = protocol.get("inputs")
    pin = inputs.get(_R23_LIFECYCLE_RELATIVE_PATH) if isinstance(inputs, dict) else None
    if not isinstance(pin, dict) or set(pin) != {"path", "bytes", "sha256"} or \
            pin.get("path") != _R23_LIFECYCLE_RELATIVE_PATH or \
            type(pin.get("bytes")) is not int or pin["bytes"] <= 0 or \
            type(pin.get("sha256")) is not str or len(pin["sha256"]) != 64 or \
            any(character not in "0123456789abcdef" for character in pin["sha256"]):
        raise RuntimeError("protocol lacks the exact managed lifecycle source pin")
    current = _source_inputs().receipt(_R23_LIFECYCLE_PATH)
    if current != pin:
        raise RuntimeError("managed lifecycle source differs from the protocol pin")
    return _exec_pinned_python_source(
        "windows_process_lifecycle_managed_r23", _R23_LIFECYCLE_PATH,
        pin["sha256"])


def configure_managed_lifecycle(protocol: Mapping[str, Any],
                                protocol_sha256: str) -> None:
    """Enable managed launch only after the frozen runtime protocol is verified."""
    global _R23_MANAGED_LIFECYCLE, _R23_ACTIVE_PROTOCOL_SHA256, _R23_ACTIVE_PROTOCOL
    if os.name != "nt" or type(protocol_sha256) is not str or \
            len(protocol_sha256) != 64 or \
            any(character not in "0123456789abcdef" for character in protocol_sha256):
        raise RuntimeError("managed lifecycle requires a verified Windows protocol digest")
    if _R23_ACTIVE_PROTOCOL_SHA256 is not None:
        raise RuntimeError("managed lifecycle protocol was already configured")
    module = _load_managed_lifecycle(protocol)
    lifecycle_pins = protocol.get("managed_process_lifecycle_source_pins")
    expected_paths = {
        _R23_LIFECYCLE_RELATIVE_PATH,
        "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
        "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
    }
    if type(lifecycle_pins) is not dict or set(lifecycle_pins) != expected_paths:
        raise RuntimeError("protocol managed lifecycle source closure must contain exactly three sources")
    input_pins = protocol.get("inputs")
    if type(input_pins) is not dict:
        raise RuntimeError("protocol input pins are malformed for managed lifecycle closure")
    for path, row in lifecycle_pins.items():
        if type(path) is not str or \
                type(row) is not dict or set(row) != {"path", "bytes", "sha256"} or \
                row.get("path") != path or \
                type(row.get("bytes")) is not int or row["bytes"] <= 0 or \
                type(row.get("sha256")) is not str or len(row["sha256"]) != 64 or \
                any(character not in "0123456789abcdef" for character in row["sha256"]) or \
                input_pins.get(path) != row:
            raise RuntimeError("protocol managed lifecycle source closure row is malformed")
    _R23_MANAGED_LIFECYCLE = module
    _R23_ACTIVE_PROTOCOL_SHA256 = protocol_sha256
    _R23_ACTIVE_PROTOCOL = dict(protocol)


class _R23ManagedObserver:
    """Durable R23 history/resource observer for the core-owned debug session."""

    def __init__(self, lifecycle: Any, output: Path,
                 history: list[dict[str, Any]], witnesses: list[str],
                 monitor_identity: Any) -> None:
        self.lifecycle = lifecycle
        self.output = output
        self.history = history
        self.witnesses = witnesses
        self.monitor_identity = monitor_identity
        self.sample_index = 0
        self.attempt_index = 0
        self.birth_counts: dict[tuple[int, int], int] = {}
        self.session: Any = None
        self.last_source_snapshot: Any = None
        self._event_receipts: list[dict[str, Any]] = []
        self._paths = {
            "events": output / "lifecycle_events.jsonl",
            "birth": output / "birth_measurements.jsonl",
            "resource": output / "resource_measurements.jsonl",
        }
        self._streams = {
            key: path.open("xb", buffering=0) for key, path in self._paths.items()
        }
        self._closed = False

    def set_context(self, sample_index: int, attempt_index: int) -> None:
        if type(sample_index) is not int or sample_index < 0 or \
                type(attempt_index) is not int or attempt_index < 0:
            raise _R23_TABLE.ProcessTableError("managed birth history context is malformed")
        self.sample_index = sample_index
        self.attempt_index = attempt_index

    def _append(self, stream_name: str, value: Mapping[str, Any]) -> bool:
        if self._closed or stream_name not in self._streams or not isinstance(value, Mapping):
            raise _R23_TABLE.ProcessTableError("managed lifecycle receipt sink is unavailable")
        encoded = json.dumps(dict(value), sort_keys=True, separators=(",", ":"),
                             ensure_ascii=False, allow_nan=False).encode("utf-8") + b"\n"
        stream = self._streams[stream_name]
        written = stream.write(encoded)
        if written != len(encoded):
            raise OSError("short write in managed lifecycle receipt")
        stream.flush()
        os.fsync(stream.fileno())
        if stream_name == "events":
            self._event_receipts.append(copy.deepcopy(dict(value)))
        return True

    def event_receipts(self) -> list[dict[str, Any]]:
        """Return this observer's own receipts after each durable event write."""
        return copy.deepcopy(self._event_receipts)

    def birth_source_witness(self, pid: int, *, phase: str,
                             event_sequence: int) -> Any:
        if phase != "managed_create" or type(pid) is not int or pid <= 0 or \
                type(event_sequence) is not int or event_sequence <= 0:
            raise _R23_TABLE.ProcessTableError("managed CREATE source request is malformed")
        snapshot = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
        row = snapshot.by_pid.get(pid)
        if row is None:
            raise _R23_TABLE.ProcessTableError(
                "debug CREATE generation is absent from its source SPI snapshot")
        identity = _r23_raw_identity(row)
        if identity[0] != pid or type(row.ppid) is not int or row.ppid <= 0 or \
                type(row.name) is not str or not row.name:
            raise _R23_TABLE.ProcessTableError("managed CREATE SPI source row is malformed")
        self.last_source_snapshot = snapshot
        is_root_source = not self.history
        if is_root_source:
            sample_index, attempt_index, source_role = 0, 0, "phase_launch"
        else:
            sample_index = self.sample_index
            attempt_index = self.attempt_index
            key = (sample_index, attempt_index)
            ordinal = self.birth_counts.get(key, 0) + 1
            self.birth_counts[key] = ordinal
            source_role = f"managed_create_{ordinal}"
        sequence = _r23_append_snapshot_history(
            self.history, self.witnesses, snapshot,
            sample_index=sample_index, attempt_index=attempt_index,
            source_role=source_role)
        history_row = self.history[sequence]
        source_receipt = {
            "schema": "vnext-t2-r23-managed-birth-source-witness-r1",
            "complete": True,
            "phase": phase,
            "sequence": sequence,
            "event_sequence": event_sequence,
            "row_identity": {"pid": identity[0], "creation_time_100ns": identity[1]},
            "row_ppid": row.ppid,
            "row_name": row.name,
            "snapshot_receipt": _r23_snapshot_receipt(snapshot),
            "history_reference": {
                "sequence": sequence,
                "source_role": source_role,
                "pid_set_sha256": history_row["pid_set_sha256"],
                "prefix_sha256": history_row["prefix_sha256"],
                "captured_witness_sha256": sha256_bytes(
                    self.witnesses[sequence].encode("ascii")),
            },
        }
        self.record_lifecycle_event({
            "event": "managed_birth_source_witness_captured",
            "event_sequence": event_sequence,
            "identity": {"pid": identity[0], "creation_time_100ns": identity[1]},
            "source_receipt": source_receipt,
            "phase_history_entry": copy.deepcopy(history_row),
            "phase_history_witness_ascii": self.witnesses[sequence],
        })
        return self.lifecycle.BirthSourceWitness(row, snapshot, source_receipt)

    def measure_exact_handle(self, handle: int, identity: Any, row: Any, *,
                             phase: str, event_receipt: Mapping[str, Any]) -> Mapping[str, Any]:
        if self.session is None:
            raise _R23_TABLE.ProcessTableError("managed lifecycle session is not attached")
        values = self.session.measurement_values_for_exact_handle(handle, identity)
        event_sequence = event_receipt.get("event_sequence")
        receipt = {
            "schema": "fca-managed-resource-measurement-v1",
            "phase": phase,
            "identity": {"pid": identity.pid,
                         "creation_time_100ns": identity.creation_time_100ns},
            "handle_identity_before": {
                "pid": values["handle_identity_before"].pid,
                "creation_time_100ns": values["handle_identity_before"].creation_time_100ns},
            "handle_identity_after": {
                "pid": values["handle_identity_after"].pid,
                "creation_time_100ns": values["handle_identity_after"].creation_time_100ns},
            "event_sequence": event_sequence,
            "complete": True,
            "rss_bytes": values["rss_bytes"],
            "cpu_user_seconds": values["cpu_user_seconds"],
            "cpu_system_seconds": values["cpu_system_seconds"],
            "cmdline": list(values["cmdline"]),
            "source_tags": ["GetProcessMemoryInfo", "GetProcessTimes",
                            "NtQueryInformationProcess.ProcessCommandLineInformation"],
        }
        return _R23_SUPERVISOR._validate_managed_measurement(
            receipt, (identity.pid, identity.creation_time_100ns), phase=phase,
            expected_event_sequence=event_sequence)

    def record_birth_measurement(self, measurement: Mapping[str, Any]) -> bool:
        identity = _R23_TABLE.validate_identity((
            measurement.get("identity", {}).get("pid"),
            measurement.get("identity", {}).get("creation_time_100ns")))
        checked = _R23_SUPERVISOR._validate_managed_measurement(
            measurement, identity, phase="create")
        return self._append("birth", checked)

    def record_resource_measurement(self, measurement: Mapping[str, Any]) -> bool:
        identity = _R23_TABLE.validate_identity((
            measurement.get("identity", {}).get("pid"),
            measurement.get("identity", {}).get("creation_time_100ns")))
        phase = measurement.get("phase")
        if phase not in {"whole_sample", "exit_pre_continue"}:
            raise _R23_TABLE.ProcessTableError("managed resource phase is unsupported")
        checked = _R23_SUPERVISOR._validate_managed_measurement(
            measurement, identity, phase=phase)
        return self._append("resource", checked)

    def record_lifecycle_event(self, event: Mapping[str, Any]) -> None:
        if self._append("events", event) is not True:
            raise _R23_TABLE.ProcessTableError("managed lifecycle event was not durably recorded")

    def close(self) -> dict[str, Any]:
        if self._closed:
            raise _R23_TABLE.ProcessTableError("managed receipt streams were already closed")
        errors = []
        for stream in self._streams.values():
            try:
                stream.flush()
                os.fsync(stream.fileno())
                stream.close()
            except Exception as error:
                errors.append({"type": type(error).__name__, "message": str(error)})
        self._closed = True
        if errors:
            raise _R23_TABLE.ProcessTableError(
                f"managed receipt stream close failed: {errors!r}")
        return {name: file_receipt(path) for name, path in self._paths.items()}


class _R23ManagedBirthRegistryBoundary:
    """Adapt canonical core birth receipts to the pinned R23 registry contract."""

    def __init__(self, registry: Any, lifecycle: Any) -> None:
        self._registry = registry
        self._lifecycle = lifecycle
        self._supervisor = _R23_SUPERVISOR

    def __getattr__(self, name: str) -> Any:
        return getattr(self._registry, name)

    def register_birth(self, record: Any, *, ack_type: Any,
                       ack_publisher: Any) -> Any:
        identity = record.identity
        identity_pair = (identity.pid, identity.creation_time_100ns)
        source_receipt = dict(record.source_snapshot_receipt)
        core_row_identity = {"pid": identity.pid,
                             "creation_time_100ns": identity.creation_time_100ns}
        if source_receipt.get("row_identity") != core_row_identity:
            raise RuntimeError("core birth source receipt differs from its exact identity")
        supervisor_row_identity = {"pid": identity.pid,
                                   "create_time_100ns": identity.creation_time_100ns}
        registry_receipt = {**source_receipt,
                            "row_identity": supervisor_row_identity}
        registry_record = replace(record, source_snapshot_receipt=registry_receipt)
        before = tuple(self._registry.identities)
        try:
            return self._registry.register_birth(
                registry_record, ack_type=ack_type, ack_publisher=ack_publisher)
        except self._supervisor.MonitorIncomplete as error:
            after = tuple(self._registry.identities)
            if identity_pair not in before and identity_pair not in after:
                transferred = False
                ownership_proof = "exact_identity_absent_before_and_after_registry_call"
            elif identity_pair in after:
                retained = self._registry.handle_for(identity_pair)
                if type(retained) is not int or retained != record.retained_handle:
                    raise
                transferred = True
                ownership_proof = "exact_registry_identity_resolves_to_retained_birth_handle"
            else:
                raise
            expected_pid = identity.pid
            expected_ticks = identity.creation_time_100ns
            row = record.source_row
            checks = {
                "receipt_complete": source_receipt.get("complete") is True,
                "phase_is_managed_create": source_receipt.get("phase") == "managed_create",
                "history_sequence_is_nonnegative_int": (
                    type(source_receipt.get("sequence")) is int and
                    source_receipt["sequence"] >= 0),
                "core_row_identity_matches": (
                    source_receipt.get("row_identity") == core_row_identity),
                "supervisor_adapter_identity_matches": (
                    registry_receipt.get("row_identity") == supervisor_row_identity),
                "source_row_pid_matches": row.identity.pid == expected_pid,
                "source_row_creation_time_matches": (
                    row.identity.create_time_100ns == expected_ticks),
                "source_row_parent_matches": (
                    source_receipt.get("row_ppid") == row.ppid ==
                    record.parent_identity.pid),
                "source_row_name_matches": (
                    source_receipt.get("row_name") == row.name),
                "event_sequence_matches_creation_measurement": (
                    source_receipt.get("event_sequence") ==
                    record.creation_measurement.get("event_sequence")),
            }
            raise self._lifecycle.BirthRegistrationError(
                "pinned R23 registry rejected CREATE before a successful return",
                handle_transferred=transferred, cleanup_complete=False,
                retained_handle=record.retained_handle, identity=identity,
                evidence={
                    "registry_exception_type": type(error).__name__,
                    "registry_exception_repr": repr(error),
                    "registry_ownership_proof": ownership_proof,
                    "birth_source_receipt": source_receipt,
                    "birth_registry_receipt": registry_receipt,
                    "birth_source_validation": checks,
                }) from error


# These source-loaded modules are protocol inputs. Direct compile/exec avoids
# importlib's bytecode-cache read path; their exact source hashes are checked
# before either module is executable.
_R23_TABLE = _exec_pinned_python_source(
    "native_process_table_r23_v1", _R23_TABLE_PATH, _R23_TABLE_SHA256)
_R23_SUPERVISOR = _exec_pinned_python_source(
    "supervise_r16_root_audit_r23_v1", _R23_SUPERVISOR_PATH,
    _R23_SUPERVISOR_SHA256)


def _r23_raw_identity(row: Any) -> tuple[int, int]:
    return _R23_TABLE.validate_identity(
        (row.identity.pid, row.identity.create_time_100ns))


def _r23_snapshot_receipt(snapshot: Any) -> dict[str, Any]:
    table = _R23_TABLE.validate_snapshot(snapshot)
    digest = _R23_TABLE.native_snapshot_digest(table)
    encoded = json.dumps(digest, separators=(",", ":"), ensure_ascii=True).encode()
    return {
        "schema": "vnext-t2-r23-native-snapshot-receipt-r1",
        "complete": True,
        "row_count": len(table.rows),
        "host_identity": list(table.host_identity),
        "system_information_class": _R23_TABLE.SYSTEM_INFORMATION_CLASS,
        "buffer_bytes": table.buffer_bytes,
        "query_attempts": table.query_attempts,
        "raw_identity_digest_sha256": sha256_bytes(encoded),
        "identity_authority": "NtQuerySystemInformation_class5_raw_FILETIME_100ns",
    }


def _r23_resource_reader(pid: int) -> dict[str, Any]:
    if type(pid) is not int or pid <= 0:
        raise RuntimeError("resource reader PID must be a positive native integer")
    process = psutil.Process(pid)
    memory = process.memory_info()
    cpu = process.cpu_times()
    command = process.cmdline()
    return {
        "rss_bytes": memory.rss,
        "cpu_user_seconds": cpu.user,
        "cpu_system_seconds": cpu.system,
        "cmdline": command,
    }


def _r23_descendants_after_leader(snapshot: Any, root_identity: Any) -> list[Any]:
    table = _R23_TABLE.validate_snapshot(snapshot)
    root_pid, root_ticks = _R23_TABLE.validate_identity(root_identity)
    by_pid = table.by_pid
    root_row = by_pid.get(root_pid)
    if root_row is not None:
        current = _r23_raw_identity(root_row)
        if current != (root_pid, root_ticks):
            raise _R23_TABLE.ProcessTableError(
                "stage-root PID was reused before final native audit")
        raise _R23_TABLE.ProcessTableError(
            "stage-root generation remains after exact wait")
    descendants: dict[int, Any] = {}
    frontier = {root_pid}
    while frontier:
        next_frontier: set[int] = set()
        for row in table.rows:
            pid = row.identity.pid
            if pid in descendants or pid == root_pid or row.ppid not in frontier:
                continue
            parent_ticks = root_ticks if row.ppid == root_pid else \
                descendants[row.ppid].identity.create_time_100ns
            if row.identity.create_time_100ns < parent_ticks:
                raise _R23_TABLE.ProcessTableError(
                    "post-exit child predates its exact parent generation")
            descendants[pid] = row
            next_frontier.add(pid)
        frontier = next_frontier
    return [descendants[pid] for pid in sorted(descendants)]


def _r20_descendants_from_pid_set(snapshot: Any, seed_pids: set[int]) -> list[Any]:
    """Return every row whose PPID chain descends from an observed PID set."""
    table = _R23_TABLE.validate_snapshot(snapshot)
    seen = set(seed_pids)
    frontier = set(seed_pids)
    found: dict[int, Any] = {}
    while frontier:
        next_frontier: set[int] = set()
        for row in table.rows:
            pid = row.identity.pid
            if pid in seen or row.ppid not in frontier:
                continue
            seen.add(pid)
            found[pid] = row
            next_frontier.add(pid)
        frontier = next_frontier
    return [found[pid] for pid in sorted(found)]


def _r20_confirm_unbound_sample_race(
        source_snapshot: Any, target_identity: Any, root_identity: Any,
        previously_tracked: list[tuple[int, int]], lookup_snapshot: Any,
        confirmation_snapshots: list[Any]) -> dict[str, Any]:
    """Validate three fresh absences after an exact-handle bind failure.

    The source table is the complete before-snapshot that identified the
    target. The lookup table and two confirmation tables are all queried after
    handle acquisition/binding failed; no failed attempt receives measurement
    or exit credit. All three must show the target's entire observed subtree
    absent while the stage root and previously tracked generations stay exact.
    """
    record: dict[str, Any] = {
        "schema": "vnext-t2-r20-unbound-sample-race-r1",
        "complete": False,
        "status": "monitor_incomplete",
        "root_identity": None,
        "target_identity": None,
        "previously_tracked_identities": [],
        "source_snapshot": None,
        "lookup_snapshot": None,
        "confirmation_snapshots": [],
        "absence_checks": [],
        "confirmation_snapshot_count": 0,
        "observed_generations": [],
        "exact_handle_opened": False,
        "exact_handle_waited": False,
        "exact_handle_exit_receipt_created": False,
        "exit_code_credit_issued": False,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "errors": [],
    }
    subtree: tuple[Any, ...] = ()
    root: tuple[int, int] | None = None
    target: tuple[int, int] | None = None
    all_absence_receipts: list[dict[str, Any]] = []
    absence_checks: list[dict[str, Any]] = []
    try:
        source = _R23_TABLE.validate_snapshot(source_snapshot)
        root = _R23_TABLE.validate_identity(root_identity)
        target = _R23_TABLE.validate_identity(target_identity)
        previous = tuple(_R23_TABLE.validate_identity(value)
                         for value in previously_tracked)
        record["root_identity"] = {"pid": root[0], "create_time_100ns": root[1]}
        record["target_identity"] = {
            "pid": target[0], "create_time_100ns": target[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks} for pid, ticks in previous]
        record["source_snapshot"] = _r23_snapshot_receipt(source)
        if target == root or target in previous:
            raise _R23_TABLE.ProcessTableError(
                "root or previously tracked generation cannot use unbound-race recovery")
        source_closure = _R23_TABLE.descendant_identities(
            source, root, previously_tracked=previous)
        if target not in {(item.pid, item.create_time_100ns)
                          for item in source_closure}:
            raise _R23_TABLE.ProcessTableError(
                "missing target was not in the first sample's exact root closure")
        subtree = _R23_TABLE.descendant_identities(source, target)
        subtree_ids = tuple((item.pid, item.create_time_100ns) for item in subtree)
        subtree_pids = {pid for pid, _ in subtree_ids}
        source_rows = source.by_pid
        record["observed_generations"] = [
            {"pid": item.pid, "create_time_100ns": item.create_time_100ns,
             "ppid": source_rows[item.pid].ppid, "name": source_rows[item.pid].name}
            for item in subtree
        ]
        if type(confirmation_snapshots) is not list or len(confirmation_snapshots) != 2:
            raise _R23_TABLE.ProcessTableError(
                "sample-race recovery requires exactly two additional confirmation snapshots")

        all_absence_tables = [lookup_snapshot, *confirmation_snapshots]
        for index, snapshot in enumerate(all_absence_tables):
            table = _R23_TABLE.validate_snapshot(snapshot)
            table_receipt = _r23_snapshot_receipt(table)
            all_absence_receipts.append(table_receipt)
            current_root = table.by_pid.get(root[0])
            if current_root is None or _r23_raw_identity(current_root) != root:
                raise _R23_TABLE.ProcessTableError(
                    f"sample-race confirmation {index + 1} lost or reused the stage root")
            for identity in previous:
                current = table.by_pid.get(identity[0])
                if current is None or _r23_raw_identity(current) != identity:
                    raise _R23_TABLE.ProcessTableError(
                        f"sample-race confirmation {index + 1} lost or reused a tracked generation")
            present = []
            for pid, ticks in subtree_ids:
                current = table.by_pid.get(pid)
                if current is not None:
                    present.append({"pid": pid, "expected_create_time_100ns": ticks,
                                    "observed_create_time_100ns":
                                        current.identity.create_time_100ns})
            if present:
                raise _R23_TABLE.ProcessTableError(
                    f"sample-race confirmation {index + 1} still sees an observed subtree PID "
                    "or a reused generation")
            orphan_rows = _r20_descendants_from_pid_set(table, subtree_pids)
            if orphan_rows:
                raise _R23_TABLE.ProcessTableError(
                    f"sample-race confirmation {index + 1} sees descendants under a vanished parent")
            absence_checks.append({
                "index": index + 1,
                "snapshot": table_receipt,
                "root_exact": True,
                "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
                "previously_tracked_exact": True,
                "previously_tracked_identities": [
                    {"pid": pid, "create_time_100ns": ticks}
                    for pid, ticks in previous],
                "subtree_pids_absent": sorted(subtree_pids),
                "orphan_descendant_count": 0,
            })
        record["lookup_snapshot"] = all_absence_receipts[0]
        record["confirmation_snapshots"] = all_absence_receipts[1:]
        record["absence_checks"] = absence_checks
        record["confirmation_snapshot_count"] = 2
        record["complete"] = True
        record["status"] = "two_confirmed_absences_unbound_no_exit_receipt"
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r20_unbound_sample_race_confirmation", error,
            target[0] if target is not None else None))
        if all_absence_receipts:
            record["lookup_snapshot"] = all_absence_receipts[0]
            record["confirmation_snapshots"] = all_absence_receipts[1:]
            record["absence_checks"] = absence_checks
        elif lookup_snapshot is not None:
            try:
                record["lookup_snapshot"] = _r23_snapshot_receipt(lookup_snapshot)
            except Exception:
                pass
        record["confirmation_snapshot_count"] = sum(
            item is not None for item in record["confirmation_snapshots"])
    return record


def _r21_confirm_tracked_sample_exit(
        source_snapshot: Any, target_identity: Any, root_identity: Any,
        previously_tracked: list[tuple[int, int]],
        handle_by_identity: dict[tuple[int, int], Any], *,
        sample_index: int, attempt_index: int,
        deadline_monotonic: float,
        snapshot_provider: Any | None = None) -> dict[str, Any]:
    """Prove a previously tracked non-root subtree exited during one sample.

    This is deliberately separate from R20's unbound-PID lane. Every retired
    generation must have its own exact original handle, signaled wait, exit
    code, and three complete post-exit SPI absences. A successful proof only
    permits a new whole-sample retry; it grants no resource or exit credit.
    """
    record: dict[str, Any] = {
        "schema": "vnext-t2-r21-tracked-sample-exit-r1",
        "complete": False,
        "status": "monitor_incomplete",
        "identity_authority":
            "raw_PID_FILETIME_100ns_SPI_and_each_generation_original_handle",
        "logical_sample_index": sample_index,
        "whole_sample_attempt_index": attempt_index,
        "root_identity": None,
        "target_identity": None,
        "previously_tracked_identities": [],
        "source_snapshot": None,
        "source_root_closure": [],
        "observed_generations": [],
        "retired_tracked_identities": [],
        "exact_exit_receipts": [],
        "absence_snapshots": [],
        "absence_checks": [],
        "absence_snapshot_count": 0,
        "partial_rss_bytes_not_credited": 0,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "full_sample_completed_after_retry": False,
        "retry_started": False,
        "errors": [],
    }
    try:
        source = _R23_TABLE.validate_snapshot(source_snapshot)
        root = _R23_TABLE.validate_identity(root_identity)
        target = _R23_TABLE.validate_identity(target_identity)
        previous = tuple(_R23_TABLE.validate_identity(value)
                         for value in previously_tracked)
        previous_set = set(previous)
        record["root_identity"] = {
            "pid": root[0], "create_time_100ns": root[1]}
        record["target_identity"] = {
            "pid": target[0], "create_time_100ns": target[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in previous]
        record["source_snapshot"] = _r23_snapshot_receipt(source)

        if target == root or target not in previous_set:
            raise _R23_TABLE.ProcessTableError(
                "tracked-exit lane requires an exact previously tracked non-root target")
        source_row = source.by_pid.get(target[0])
        if source_row is None or _r23_raw_identity(source_row) != target:
            raise _R23_TABLE.ProcessTableError(
                "tracked-exit target is absent or reused in the source snapshot")

        # Preserve syntactically valid source rows even when later closure or
        # handle proof fails, so failed evidence is auditable and not malformed.
        subtree = _R23_TABLE.descendant_identities(source, target)
        source_rows = source.by_pid
        subtree_ids = tuple((item.pid, item.create_time_100ns)
                            for item in subtree)
        subtree_pids = {pid for pid, _ in subtree_ids}
        record["observed_generations"] = [
            {"pid": item.pid, "create_time_100ns": item.create_time_100ns,
             "ppid": source_rows[item.pid].ppid, "name": source_rows[item.pid].name}
            for item in subtree]
        record["retired_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in subtree_ids]

        source_closure = _R23_TABLE.descendant_identities(
            source, root, previously_tracked=previous)
        closure_ids = {(item.pid, item.create_time_100ns)
                       for item in source_closure}
        record["source_root_closure"] = [
            {"pid": item.pid, "create_time_100ns": item.create_time_100ns,
             "ppid": source.by_pid[item.pid].ppid,
             "name": source.by_pid[item.pid].name}
            for item in source_closure]
        if target not in closure_ids:
            raise _R23_TABLE.ProcessTableError(
                "tracked-exit target is outside the exact source root closure")
        if not set(subtree_ids).issubset(previous_set):
            raise _R23_TABLE.ProcessTableError(
                "tracked-exit subtree contains a generation without a prior exact handle")
        outside_subtree = previous_set.difference(subtree_ids)
        if root not in outside_subtree:
            raise _R23_TABLE.ProcessTableError(
                "tracked-exit subtree incorrectly includes the stage root")

        # Require an exact, individually retained handle for every generation
        # removed from active tracking. Failures never fall back to PID-only I/O.
        for identity in subtree_ids:
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during tracked-exit handle proof")
            handle = handle_by_identity.get(identity)
            if handle is None:
                raise _R23_TABLE.ProcessTableError(
                    f"original exact handle is unavailable for tracked generation {identity[0]}")
            before = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                before, identity, phase="R21 tracked-exit pre-wait handle")
            waited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
            if type(waited) is not bool or waited is not True:
                raise _R23_TABLE.ProcessTableError(
                    f"exact handle did not confirm natural exit for PID {identity[0]}")
            after = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                after, identity, phase="R21 tracked-exit post-wait handle")
            exit_code = _R23_TABLE.process_exit_code(handle)
            if type(exit_code) is not int or exit_code == 259:
                raise _R23_TABLE.ProcessTableError(
                    f"exact waited handle has invalid/STILL_ACTIVE exit code for PID {identity[0]}")
            record["exact_exit_receipts"].append({
                "schema": "vnext-t2-r21-tracked-generation-natural-exit-r1",
                "complete": True,
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "handle_identity_before_wait": {
                    "pid": before[0], "create_time_100ns": before[1]},
                "wait_confirmed": True,
                "handle_identity_after_wait": {
                    "pid": after[0], "create_time_100ns": after[1]},
                "exit_code": exit_code,
                "exit_code_credit_issued": False,
                "errors": [],
            })

        query = snapshot_provider or _R23_TABLE.query_native_process_table
        for index in range(1, 4):
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during tracked-exit absence confirmation")
            table = _R23_TABLE.validate_snapshot(query())
            table_receipt = _r23_snapshot_receipt(table)
            current_root = table.by_pid.get(root[0])
            if current_root is None or _r23_raw_identity(current_root) != root:
                raise _R23_TABLE.ProcessTableError(
                    f"tracked-exit confirmation {index} lost or reused the stage root")
            for identity in sorted(outside_subtree):
                current = table.by_pid.get(identity[0])
                if current is None or _r23_raw_identity(current) != identity:
                    raise _R23_TABLE.ProcessTableError(
                        f"tracked-exit confirmation {index} lost or reused another tracked generation")
            present = [{"pid": pid,
                        "expected_create_time_100ns": ticks,
                        "observed_create_time_100ns": table.by_pid[pid].identity.create_time_100ns}
                       for pid, ticks in subtree_ids if pid in table.by_pid]
            if present:
                raise _R23_TABLE.ProcessTableError(
                    f"tracked-exit confirmation {index} sees a subtree PID or reused generation")
            orphan_rows = _r20_descendants_from_pid_set(table, subtree_pids)
            if orphan_rows:
                raise _R23_TABLE.ProcessTableError(
                    f"tracked-exit confirmation {index} sees descendants under an absent subtree PID")
            record["absence_snapshots"].append(table_receipt)
            record["absence_checks"].append({
                "index": index,
                "snapshot": table_receipt,
                "root_exact": True,
                "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
                "other_previously_tracked_exact": True,
                "other_previously_tracked_identities": [
                    {"pid": pid, "create_time_100ns": ticks}
                    for pid, ticks in sorted(outside_subtree)],
                "subtree_pids_absent": sorted(subtree_pids),
                "orphan_descendant_count": 0,
            })
        record["absence_snapshot_count"] = 3
        record["complete"] = True
        record["status"] = "tracked_generations_naturally_exited_three_absences_confirmed"
    except Exception as error:
        record["absence_snapshot_count"] = len(record["absence_snapshots"])
        record["errors"].append(_monitor_error(
            "r21_tracked_sample_exit_confirmation", error,
            target[0] if "target" in locals() else None))
    return record


def _r22_snapshot_bundle(snapshot: Any) -> dict[str, Any]:
    """Keep complete raw identity rows beside their native snapshot receipt."""
    table = _R23_TABLE.validate_snapshot(snapshot)
    rows = [{
        "pid": row.identity.pid,
        "create_time_100ns": row.identity.create_time_100ns,
        "ppid": row.ppid,
        "name": row.name,
    } for row in sorted(table.rows, key=lambda item: item.identity.pid)]
    return {"schema": "vnext-t2-r22-process-table-evidence-r1",
            "snapshot": _r23_snapshot_receipt(table), "rows": rows}


def _r22_snapshot_from_bundle(value: Any) -> Any:
    if not isinstance(value, dict) or set(value) != {"schema", "snapshot", "rows"} or \
            value.get("schema") != "vnext-t2-r22-process-table-evidence-r1" or \
            not _r20_valid_snapshot_receipt(value.get("snapshot")) or \
            type(value.get("rows")) is not list:
        raise _R23_TABLE.ProcessTableError(
            "R22 pre-tree snapshot evidence bundle has an invalid shape")
    receipt = value["snapshot"]
    raw_rows = value["rows"]
    if len(raw_rows) != receipt.get("row_count"):
        raise _R23_TABLE.ProcessTableError(
            "R22 pre-tree snapshot row count differs from its receipt")
    rows = []
    seen: set[int] = set()
    for item in raw_rows:
        if not isinstance(item, dict) or set(item) != {
                "pid", "create_time_100ns", "ppid", "name"} or \
                type(item.get("name")) is not str:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree raw identity row has an invalid shape")
        pid = _R23_TABLE.validate_pid(item.get("pid"), allow_zero=True)
        ticks = _R23_TABLE.validate_ticks(item.get("create_time_100ns"))
        ppid = _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
        if pid in seen:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree raw identity rows duplicate a PID")
        seen.add(pid)
        rows.append(_R23_TABLE.ProcessRow(
            _R23_TABLE.ProcessIdentity(pid, ticks), ppid, item["name"]))
    table = _R23_TABLE.ProcessTableSnapshot(
        tuple(rows), tuple(receipt["host_identity"]),
        receipt["buffer_bytes"], receipt["query_attempts"])
    if _r23_snapshot_receipt(table) != receipt:
        raise _R23_TABLE.ProcessTableError(
            "R22 pre-tree raw rows do not reproduce their native snapshot receipt")
    return table


def _r22_tracked_closure(table: Any, root_identity: Any,
                         previously_tracked: list[tuple[int, int]]) -> dict[
                             tuple[int, int], tuple[int, str]]:
    root = _R23_TABLE.validate_identity(root_identity)
    closure = _R23_TABLE.descendant_identities(
        table, root, previously_tracked=previously_tracked)
    by_pid = table.by_pid
    projected = {
        (item.pid, item.create_time_100ns):
        (by_pid[item.pid].ppid, by_pid[item.pid].name)
        for item in closure}
    expected = {root, *previously_tracked}
    if set(projected) != expected:
        raise _R23_TABLE.ProcessTableError(
            "R22 pre-tree source closure differs from the accepted tracked generations")
    return projected


def _r23_root_closure_rows(snapshot: Any, root_identity: Any) -> dict[
        tuple[int, int], Any]:
    """Return rows reachable from one exact root through monotone PPID edges."""
    table = _R23_TABLE.validate_snapshot(snapshot)
    root = _R23_TABLE.validate_identity(root_identity)
    root_row = table.by_pid.get(root[0])
    if root_row is None or _r23_raw_identity(root_row) != root:
        raise _R23_TABLE.ProcessTableError(
            "R23 membership-growth source lacks the exact root generation")
    rows: dict[tuple[int, int], Any] = {root: root_row}
    changed = True
    while changed:
        changed = False
        by_pid = {identity[0]: row for identity, row in rows.items()}
        for row in table.rows:
            parent = by_pid.get(row.ppid)
            if parent is None:
                continue
            identity = _r23_raw_identity(row)
            if identity in rows:
                continue
            parent_identity = _r23_raw_identity(parent)
            if identity[1] < parent_identity[1]:
                raise _R23_TABLE.ProcessTableError(
                    "R23 child FILETIME predates its exact parent generation")
            rows[identity] = row
            changed = True
    return rows


def _r23_observed_root_reachable_rows(snapshot: Any, root_identity: Any) -> dict[
        tuple[int, int], Any]:
    """Retain syntactically valid root-reachable rows for fail-closed cleanup inventory."""
    table = _R23_TABLE.validate_snapshot(snapshot)
    root = _R23_TABLE.validate_identity(root_identity)
    root_row = table.by_pid.get(root[0])
    if root_row is None or _r23_raw_identity(root_row) != root:
        raise _R23_TABLE.ProcessTableError(
            "R23 observed-row inventory lacks the exact phase root")
    rows: dict[tuple[int, int], Any] = {root: root_row}
    changed = True
    while changed:
        changed = False
        parent_pids = {identity[0] for identity in rows}
        for row in table.rows:
            if row.ppid not in parent_pids:
                continue
            identity = _r23_raw_identity(row)
            if identity in rows:
                continue
            rows[identity] = row
            changed = True
    return rows


def _r23_snapshot_bundle(snapshot: Any) -> dict[str, Any]:
    table = _R23_TABLE.validate_snapshot(snapshot)
    rows = [{
        "pid": row.identity.pid,
        "create_time_100ns": row.identity.create_time_100ns,
        "ppid": row.ppid,
        "name": row.name,
    } for row in sorted(table.rows, key=lambda item: item.identity.pid)]
    return {"schema": "vnext-t2-r23-process-table-evidence-r1",
            "snapshot": _r23_snapshot_receipt(table), "rows": rows}


def _r23_snapshot_history_hash(entry: dict[str, Any]) -> str:
    payload = {key: value for key, value in entry.items()
               if key != "prefix_sha256"}
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"),
                         ensure_ascii=True).encode("ascii")
    return sha256_bytes(encoded)


def _r23_snapshot_history_pid_hash(pids: list[int]) -> str:
    encoded = json.dumps(pids, separators=(",", ":"),
                         ensure_ascii=True).encode("ascii")
    return sha256_bytes(encoded)


def _r23_snapshot_witness_bytes(entry: dict[str, Any]) -> bytes:
    if not isinstance(entry, dict):
        raise _R23_TABLE.ProcessTableError(
            "R23 captured source witness entry is malformed")
    return json.dumps(entry, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True).encode("ascii")


def _r23_snapshot_witness_ledger_receipt(
        witnesses: Any) -> dict[str, Any]:
    if type(witnesses) not in (list, tuple) or not witnesses or \
            any(type(item) is not str for item in witnesses):
        raise _R23_TABLE.ProcessTableError(
            "R23 captured source witness ledger is absent or malformed")
    payload = bytearray()
    for witness in witnesses:
        encoded = witness.encode("ascii")
        decoded = json.loads(encoded.decode("ascii"))
        if _r23_snapshot_witness_bytes(decoded) != encoded:
            raise _R23_TABLE.ProcessTableError(
                "R23 captured source witness is not canonical JSON")
        payload.extend(encoded)
        payload.extend(b"\n")
    return {
        "schema": "vnext-t2-r23-captured-source-witness-ledger-r1",
        "entry_count": len(witnesses),
        "sha256": sha256_bytes(bytes(payload)),
    }


def _r23_append_snapshot_history(
        history: list[dict[str, Any]], captured_witnesses: list[str],
        snapshot: Any, *, sample_index: int,
        attempt_index: int, source_role: str) -> int:
    """Append one complete native query as compact, prefix-chained PID evidence."""
    if type(history) is not list or type(captured_witnesses) is not list or \
            len(history) != len(captured_witnesses):
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history/witness append-only ledgers disagree")
    if type(sample_index) is not int or sample_index < 0 or \
            type(attempt_index) is not int or attempt_index < 0 or \
            type(source_role) is not str or not source_role:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history context is malformed")
    table = _R23_TABLE.validate_snapshot(snapshot)
    sequence = len(history)
    if history:
        previous = history[-1].get("prefix_sha256")
        if type(previous) is not str or len(previous) != 64:
            raise _R23_TABLE.ProcessTableError(
                "R23 phase snapshot history predecessor is malformed")
    else:
        previous = None
    pids = sorted(row.identity.pid for row in table.rows)
    if len(pids) != len(set(pids)):
        raise _R23_TABLE.ProcessTableError(
            "R23 complete native snapshot contains duplicate process IDs")
    entry = {
        "schema": "vnext-t2-r23-phase-snapshot-pid-history-entry-r1",
        "sequence": sequence,
        "sample_index": sample_index,
        "attempt_index": attempt_index,
        "source_role": source_role,
        "snapshot_receipt": _r23_snapshot_receipt(table),
        "pids": pids,
        "pid_set_sha256": _r23_snapshot_history_pid_hash(pids),
        "previous_prefix_sha256": previous,
    }
    entry["prefix_sha256"] = _r23_snapshot_history_hash(entry)
    witness = _r23_snapshot_witness_bytes(entry).decode("ascii")
    history.append(entry)
    captured_witnesses.append(witness)
    return sequence


def _r23_validate_snapshot_history(
        history: Any, captured_witnesses: Any, *,
        through_sequence: int | None = None) -> list[dict[str, Any]]:
    if type(history) is not list or not history or \
            type(captured_witnesses) not in (list, tuple) or \
            len(captured_witnesses) != len(history):
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history/captured witness ledger is absent or malformed")
    if through_sequence is None:
        through_sequence = len(history) - 1
    if type(through_sequence) is not int or not 0 <= through_sequence < len(history):
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history prefix sequence is invalid")
    previous_prefix = None
    validated: list[dict[str, Any]] = []
    outer_samples: set[int] = set()
    outer_exit_counts: dict[int, int] = {}
    outer_query_closed: set[int] = set()
    last_sample_index = 0
    last_attempt_index = 0
    role_counts: dict[tuple[int, int, str], int] = {}
    managed_birth_counts: dict[tuple[int, int], int] = {}
    seen_before: set[tuple[int, int]] = set()
    for sequence, source in enumerate(history[:through_sequence + 1]):
        if not isinstance(source, dict) or set(source) != {
                "schema", "sequence", "sample_index", "attempt_index",
                "source_role", "snapshot_receipt", "pids", "pid_set_sha256",
                "previous_prefix_sha256", "prefix_sha256"}:
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} has an invalid shape")
        witness = captured_witnesses[sequence]
        if type(witness) is not str or \
                witness.encode("ascii") != _r23_snapshot_witness_bytes(source):
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} differs from its captured source witness")
        if source.get("schema") != \
                "vnext-t2-r23-phase-snapshot-pid-history-entry-r1" or \
                source.get("sequence") != sequence or \
                type(source.get("sample_index")) is not int or \
                source["sample_index"] < 0 or \
                type(source.get("attempt_index")) is not int or \
                source["attempt_index"] < 0 or \
                type(source.get("source_role")) is not str or \
                not source["source_role"] or \
                source.get("previous_prefix_sha256") != previous_prefix:
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} has an invalid order/context")
        sample_index = source["sample_index"]
        attempt_index = source["attempt_index"]
        source_role = source["source_role"]
        if sequence == 0:
            if (sample_index, attempt_index, source_role) != (0, 0, "phase_launch"):
                raise _R23_TABLE.ProcessTableError(
                    "R23 phase snapshot history does not begin with the exact launch source")
        elif source_role == "phase_launch" or sample_index <= 0 or \
                sample_index < last_sample_index or \
                sample_index > last_sample_index + 1 or \
                (sample_index == last_sample_index and
                 attempt_index < last_attempt_index):
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} regresses its sample order")
        if source_role == "outer_reconcile":
            if attempt_index != 0 or sample_index in outer_samples or \
                    sample_index != max(outer_samples, default=0) + 1:
                raise _R23_TABLE.ProcessTableError(
                    f"R23 phase snapshot history entry {sequence} has an invalid outer sample")
            outer_samples.add(sample_index)
        elif sequence > 0:
            if sample_index not in outer_samples:
                if not (source_role.startswith("managed_create_") and
                        attempt_index == 0 and
                        sample_index == max(outer_samples, default=0) + 1):
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} precedes its outer sample")
            if source_role.startswith("managed_create_"):
                ordinal = source_role.rpartition("_")[2]
                key = (sample_index, attempt_index)
                expected_ordinal = managed_birth_counts.get(key, 0) + 1
                if attempt_index not in (0, 1, 2) or not ordinal.isdigit() or \
                        int(ordinal) != expected_ordinal or \
                        sample_index not in outer_samples and attempt_index != 0:
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid managed CREATE source")
                if attempt_index > 0 and (
                        (sample_index, attempt_index, "sample_source_after") in role_counts or
                        any(role_counts.get((sample_index, attempt_index, prefix), 0)
                            for prefix in ("tracked_exit_absence",
                                           "pre_tree_exit_absence",
                                           "unbound_confirmation"))):
                    raise _R23_TABLE.ProcessTableError(
                        "managed CREATE source arrived after its sample attempt was closed")
                managed_birth_counts[key] = expected_ordinal
            elif source_role.startswith("outer_tracked_exit_"):
                ordinal = source_role.rpartition("_")[2]
                expected_ordinal = outer_exit_counts.get(sample_index, 0) + 1
                if attempt_index != 0 or not ordinal.isdigit() or \
                        int(ordinal) != expected_ordinal or \
                        sample_index in outer_query_closed:
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid outer tracked-exit query")
                outer_exit_counts[sample_index] = expected_ordinal
            elif source_role == "sample_boundary_after":
                key = (sample_index, attempt_index, source_role)
                if attempt_index not in (1, 2) or key in role_counts or \
                        sample_index not in outer_samples:
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid lifecycle boundary reconciliation")
                outer_query_closed.add(sample_index)
                role_counts[key] = 1
            elif source_role in ("sample_source_before", "sample_source_after",
                                 "sample_source_extra"):
                if attempt_index not in (1, 2):
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid sample attempt")
                outer_query_closed.add(sample_index)
                key = (sample_index, attempt_index, source_role)
                role_counts[key] = role_counts.get(key, 0) + 1
                if source_role in ("sample_source_before", "sample_source_after") and \
                        role_counts[key] != 1:
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history duplicates {source_role}")
                if source_role == "sample_source_after" and \
                        (sample_index, attempt_index) not in seen_before:
                    raise _R23_TABLE.ProcessTableError(
                        "R23 sample after-source precedes its before-source")
                if source_role == "sample_source_before":
                    seen_before.add((sample_index, attempt_index))
            elif source_role.startswith(("tracked_exit_absence_",
                                         "pre_tree_exit_absence_",
                                         "unbound_confirmation_",
                                         "terminal_root_exit_absence_",
                                         "descendant_terminal_root_absence_")):
                if attempt_index not in (1, 2):
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid confirmation attempt")
                if source_role.startswith("terminal_root_exit_absence_") and \
                        (attempt_index != 1 or
                         (sample_index, attempt_index) not in seen_before):
                    raise _R23_TABLE.ProcessTableError(
                        "R23 terminal-root absence query lacks its first failed-sample source")
                if source_role.startswith("descendant_terminal_root_absence_") and \
                        (attempt_index != 1 or
                         (sample_index, attempt_index) not in seen_before or
                         role_counts.get((sample_index, attempt_index,
                                          "tracked_exit_absence"), 0) != 2):
                    raise _R23_TABLE.ProcessTableError(
                        "R23 descendant-terminal absence query lacks the failed source and both R21 probes")
                outer_query_closed.add(sample_index)
                prefix, _, ordinal = source_role.rpartition("_")
                if not ordinal.isdigit() or int(ordinal) <= 0:
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} has an invalid confirmation role")
                key = (sample_index, attempt_index, prefix)
                role_counts[key] = role_counts.get(key, 0) + 1
                if int(ordinal) != role_counts[key] or \
                        (source_role.startswith("descendant_terminal_root_absence_") and
                         int(ordinal) > 3):
                    raise _R23_TABLE.ProcessTableError(
                        f"R23 phase snapshot history entry {sequence} skips a confirmation sequence")
            else:
                raise _R23_TABLE.ProcessTableError(
                    f"R23 phase snapshot history entry {sequence} has an unknown query role")
        last_sample_index = sample_index
        last_attempt_index = attempt_index
        receipt = source.get("snapshot_receipt")
        pids = source.get("pids")
        if not _r20_valid_snapshot_receipt(receipt) or type(pids) is not list or \
                len(pids) != receipt.get("row_count"):
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} lacks a complete query receipt/PID set")
        checked_pids = [_R23_TABLE.validate_pid(pid, allow_zero=True) for pid in pids]
        if checked_pids != sorted(set(checked_pids)) or \
                source.get("pid_set_sha256") != \
                    _r23_snapshot_history_pid_hash(checked_pids):
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} PID-set digest is invalid")
        expected_prefix = _r23_snapshot_history_hash(source)
        if source.get("prefix_sha256") != expected_prefix:
            raise _R23_TABLE.ProcessTableError(
                f"R23 phase snapshot history entry {sequence} prefix digest is invalid")
        previous_prefix = expected_prefix
        validated.append(source)
    return validated


def _r23_snapshot_history_reference(
        history: list[dict[str, Any]], captured_witnesses: Any,
        sequence: int, snapshot: Any, *,
        sample_index: int | None = None, attempt_index: int | None = None,
        source_role: str | None = None) -> dict[str, Any]:
    if type(sequence) is not int:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history sequence is not an integer")
    entries = _r23_validate_snapshot_history(
        history, captured_witnesses, through_sequence=sequence)
    entry = entries[sequence]
    table = _R23_TABLE.validate_snapshot(snapshot)
    pids = sorted(row.identity.pid for row in table.rows)
    if entry.get("snapshot_receipt") != _r23_snapshot_receipt(table) or \
            entry.get("pids") != pids:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase history reference differs from its validated source snapshot")
    if sample_index is not None and entry.get("sample_index") != sample_index or \
            attempt_index is not None and entry.get("attempt_index") != attempt_index or \
            source_role is not None and entry.get("source_role") != source_role:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase history reference context does not match its caller")
    return {
        "sequence": sequence,
        "snapshot_receipt": copy.deepcopy(entry["snapshot_receipt"]),
        "pid_set_sha256": entry["pid_set_sha256"],
        "prefix_sha256": entry["prefix_sha256"],
    }


def _r23_snapshot_history_prefix_receipt(
        history: list[dict[str, Any]], captured_witnesses: Any,
        through_sequence: int) -> dict[str, Any]:
    entries = _r23_validate_snapshot_history(
        history, captured_witnesses, through_sequence=through_sequence)
    witness_prefix = _r23_snapshot_witness_ledger_receipt(
        captured_witnesses[:through_sequence + 1])
    return {
        "schema": "vnext-t2-r23-phase-snapshot-pid-history-prefix-r2",
        "first_sequence": 0,
        "last_sequence": through_sequence,
        "entry_count": len(entries),
        "prefix_sha256": entries[-1]["prefix_sha256"],
        "captured_source_witness_ledger": witness_prefix,
    }


def _r23_verify_snapshot_history_reference(
        history: list[dict[str, Any]], captured_witnesses: Any,
        reference: Any,
        snapshot: Any, *, sample_index: int | None = None,
        attempt_index: int | None = None, source_role: str | None = None) -> dict[str, Any]:
    if not isinstance(reference, dict) or set(reference) != {
            "sequence", "snapshot_receipt", "pid_set_sha256", "prefix_sha256"}:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history reference is malformed")
    expected = _r23_snapshot_history_reference(
        history, captured_witnesses, reference.get("sequence"), snapshot,
        sample_index=sample_index, attempt_index=attempt_index,
        source_role=source_role)
    if reference != expected:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history reference/prefix differs from its source")
    return _R23_TABLE.validate_snapshot(snapshot)


def _r23_terminal_root_closure_rows(
        snapshot: Any, root_identity: Any,
        previously_tracked: list[tuple[int, int]]) -> list[dict[str, Any]]:
    table = _R23_TABLE.validate_snapshot(snapshot)
    root = _R23_TABLE.validate_identity(root_identity)
    previous = tuple(_R23_TABLE.validate_identity(value)
                     for value in previously_tracked)
    if len(previous) != len(set(previous)) or root not in set(previous):
        raise _R23_TABLE.ProcessTableError(
            "terminal-root previous active identities are duplicated or omit the root")
    for identity in previous:
        row = table.by_pid.get(identity[0])
        if row is None or _r23_raw_identity(row) != identity:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root source omits or reuses a previously active identity")
    closure = _R23_TABLE.descendant_identities(
        table, root, previously_tracked=list(previous))
    identities = {(item.pid, item.create_time_100ns) for item in closure}
    if root not in identities or identities != set(previous):
        raise _R23_TABLE.ProcessTableError(
            "terminal-root source closure does not exactly cover the active inventory")
    rows = table.by_pid
    ordered = sorted(closure, key=lambda item: (item.pid, item.create_time_100ns))
    result: list[dict[str, Any]] = []
    for item in ordered:
        row = rows[item.pid]
        if _r23_raw_identity(row) != (item.pid, item.create_time_100ns):
            raise _R23_TABLE.ProcessTableError(
                "terminal-root closure row generation differs from its source identity")
        if item.pid != root[0]:
            parent = rows.get(row.ppid)
            if parent is None or (parent.identity.pid, parent.identity.create_time_100ns) \
                    not in identities or \
                    parent.identity.create_time_100ns > item.create_time_100ns:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root source closure has an unreachable or inverted FILETIME edge")
        result.append({"pid": item.pid,
                       "create_time_100ns": item.create_time_100ns,
                       "ppid": row.ppid, "name": row.name})
    return result


def _r23_confirm_terminal_root_sample_exit(
        previous_accepted_source_snapshot: Any,
        outer_reconcile_snapshot: Any,
        source_snapshot: Any,
        root_identity: Any,
        previously_tracked: list[tuple[int, int]],
        root_handle: Any,
        handle_by_identity: dict[tuple[int, int], Any], *,
        bound_handle_identity_receipts: list[dict[str, Any]],
        sample_index: int, attempt_index: int,
        previous_accepted_sample_index: int,
        previous_accepted_source_history_sequence: int,
        outer_reconcile_history_sequence: int,
        source_history_sequence: int,
        deadline_monotonic: float,
        resource_failure: BaseException,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: list[str],
        snapshot_provider: Any) -> dict[str, Any]:
    """Prove a final root resource-read exit without retry or resource credit."""
    record: dict[str, Any] = {
        "schema": "vnext-t2-r23-terminal-root-sample-exit-r1",
        "complete": False,
        "status": "monitor_incomplete",
        "failure_stage": "r23_terminal_root_resource_read_exit",
        "logical_sample_index": sample_index,
        "whole_sample_attempt_index": attempt_index,
        "previous_accepted_sample_index": previous_accepted_sample_index,
        "previous_accepted_source_history_sequence": (
            previous_accepted_source_history_sequence),
        "root_identity": None,
        "previously_tracked_identities": [],
        "outside_tracked_identities": [],
        "source_snapshot": None,
        "previous_accepted_source": None,
        "outer_reconcile_source": None,
        "source_table": None,
        "source_root_closure": [],
        "bound_root_handle_receipt": None,
        "resource_root_handle_proof": None,
        "exact_exit_receipts": [],
        "absence_snapshot_bundles": [],
        "absence_history_references": [],
        "absence_checks": [],
        "absence_snapshot_count": 0,
        "partial_rss_bytes_not_credited": 0,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "sample_complete": False,
        "retry_started": False,
        "full_sample_completed_after_retry": False,
        "resource_failure": None,
        "errors": [],
    }
    try:
        root = _R23_TABLE.validate_identity(root_identity)
        previous = tuple(_R23_TABLE.validate_identity(value)
                         for value in previously_tracked)
        if len(previous) != len(set(previous)) or root not in set(previous):
            raise _R23_TABLE.ProcessTableError(
                "terminal-root target is not in a unique previous-active inventory")
        if type(sample_index) is not int or sample_index <= 0 or \
                type(attempt_index) is not int or attempt_index != 1 or \
                type(previous_accepted_sample_index) is not int or \
                previous_accepted_sample_index <= 0 or \
                previous_accepted_sample_index >= sample_index:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root disposition lacks a prior complete sample or first attempt")
        if not isinstance(resource_failure, psutil.NoSuchProcess) or \
                type(getattr(resource_failure, "pid", None)) is not int or \
                getattr(resource_failure, "pid", None) != root[0]:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root disposition requires NoSuchProcess for the exact root PID")
        if type(phase_snapshot_history) is not list or \
                type(phase_snapshot_witnesses) is not list or \
                len(phase_snapshot_history) != len(phase_snapshot_witnesses):
            raise _R23_TABLE.ProcessTableError(
                "terminal-root disposition lacks aligned captured source witnesses")
        if not isinstance(handle_by_identity, dict) or root_handle is None:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root disposition lacks exact retained process handles")
        if type(bound_handle_identity_receipts) is not list:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root disposition lacks the sample's bound-handle receipt list")

        accepted = _R23_TABLE.validate_snapshot(previous_accepted_source_snapshot)
        outer = _R23_TABLE.validate_snapshot(outer_reconcile_snapshot)
        source = _R23_TABLE.validate_snapshot(source_snapshot)
        record["root_identity"] = {
            "pid": root[0], "create_time_100ns": root[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(previous)]
        record["source_snapshot"] = _r23_snapshot_receipt(source)
        record["resource_failure"] = {
            "type": type(resource_failure).__name__,
            "pid": getattr(resource_failure, "pid", None),
            "message": str(resource_failure),
        }

        accepted_rows = _r23_terminal_root_closure_rows(
            accepted, root, list(previous))
        outer_rows = _r23_terminal_root_closure_rows(
            outer, root, list(previous))
        source_rows = _r23_terminal_root_closure_rows(
            source, root, list(previous))
        if accepted_rows != outer_rows or outer_rows != source_rows:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root accepted, outer, and failed-source closure graphs differ")
        record["source_root_closure"] = copy.deepcopy(source_rows)
        closure_ids = {
            (row["pid"], row["create_time_100ns"]) for row in source_rows}
        outside = set(previous).difference(closure_ids)
        record["outside_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(outside)]
        record["previous_accepted_source"] = _r22_snapshot_bundle(accepted)
        record["outer_reconcile_source"] = _r22_snapshot_bundle(outer)
        record["source_table"] = _r22_snapshot_bundle(source)

        previous_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            previous_accepted_source_history_sequence, accepted,
            sample_index=previous_accepted_sample_index,
            source_role="sample_source_before")
        outer_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            outer_reconcile_history_sequence, outer,
            sample_index=sample_index, attempt_index=0,
            source_role="outer_reconcile")
        source_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            source_history_sequence, source,
            sample_index=sample_index, attempt_index=attempt_index,
            source_role="sample_source_before")
        if not (previous_accepted_source_history_sequence <
                outer_reconcile_history_sequence < source_history_sequence):
            raise _R23_TABLE.ProcessTableError(
                "terminal-root source history references are not strictly ordered")
        record["previous_accepted_source_history_reference"] = previous_reference
        record["outer_reconcile_history_reference"] = outer_reference
        record["source_history_reference"] = source_reference

        root_bound_receipts = [item for item in bound_handle_identity_receipts
            if isinstance(item, dict) and item.get("pid") == root[0] and
            item.get("create_time_100ns") == root[1] and
            item.get("source_snapshot") == _r23_snapshot_receipt(source)]
        if len(root_bound_receipts) != 1:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root resource failure lacks one exact source-bound Popen handle receipt")
        record["bound_root_handle_receipt"] = copy.deepcopy(root_bound_receipts[0])
        if time.monotonic() >= deadline_monotonic:
            raise TimeoutError(
                "phase deadline reached before terminal-root exact-handle proof")
        resource_before = _R23_TABLE.validate_identity(
            _R23_TABLE.read_process_handle_identity(root_handle))
        _R23_TABLE.require_same_identity(
            resource_before, root, phase="R23 terminal-root resource-failure handle")
        resource_waited = _R23_TABLE.wait_for_process_exit(root_handle, 0.001)
        if type(resource_waited) is not bool or resource_waited is not True:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root resource failure lacks a signaled original Popen handle")
        resource_after = _R23_TABLE.validate_identity(
            _R23_TABLE.read_process_handle_identity(root_handle))
        _R23_TABLE.require_same_identity(
            resource_after, root, phase="R23 terminal-root resource-failure post-wait handle")
        resource_exit_code = _R23_TABLE.process_exit_code(root_handle)
        if type(resource_exit_code) is not int or resource_exit_code == 259:
            raise _R23_TABLE.ProcessTableError(
                "terminal-root resource failure has invalid/STILL_ACTIVE Popen exit code")
        record["resource_root_handle_proof"] = {
            "identity": {"pid": root[0], "create_time_100ns": root[1]},
            "handle_owner": "original_popen_handle",
            "handle_identity_before_wait": {
                "pid": resource_before[0], "create_time_100ns": resource_before[1]},
            "wait_confirmed": True,
            "handle_identity_after_wait": {
                "pid": resource_after[0], "create_time_100ns": resource_after[1]},
            "exit_code": resource_exit_code,
            "exit_code_credit_issued": False,
            "errors": [],
        }

        source_table = source.by_pid
        exit_receipts: list[dict[str, Any]] = []
        for row in source_rows:
            identity = (row["pid"], row["create_time_100ns"])
            handle = root_handle if identity == root else handle_by_identity.get(identity)
            if handle is None:
                raise _R23_TABLE.ProcessTableError(
                    f"terminal-root source generation {identity[0]} lacks a retained exact handle")
            before = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                before, identity, phase="R23 terminal-root pre-wait handle")
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during terminal-root exact-handle proof")
            waited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
            if type(waited) is not bool or waited is not True:
                raise _R23_TABLE.ProcessTableError(
                    f"terminal-root exact handle did not confirm exit for PID {identity[0]}")
            after = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                after, identity, phase="R23 terminal-root post-wait handle")
            exit_code = _R23_TABLE.process_exit_code(handle)
            if type(exit_code) is not int or exit_code == 259:
                raise _R23_TABLE.ProcessTableError(
                    f"terminal-root exact handle has invalid/STILL_ACTIVE exit code for PID {identity[0]}")
            exit_receipts.append({
                "schema": "vnext-t2-r23-terminal-generation-exit-r1",
                "complete": True,
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "handle_owner": ("original_popen_handle" if identity == root
                                 else "retained_registry_handle"),
                "handle_identity_before_wait": {
                    "pid": before[0], "create_time_100ns": before[1]},
                "wait_confirmed": True,
                "handle_identity_after_wait": {
                    "pid": after[0], "create_time_100ns": after[1]},
                "exit_code": exit_code,
                "exit_code_credit_issued": False,
                "errors": [],
            })
        record["exact_exit_receipts"] = exit_receipts

        closure_pids = {pid for pid, _ in closure_ids}
        absence_bundles: list[dict[str, Any]] = []
        absence_references: list[dict[str, Any]] = []
        absence_checks: list[dict[str, Any]] = []
        for index in range(1, 4):
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during terminal-root absence confirmation")
            table = _R23_TABLE.validate_snapshot(snapshot_provider())
            sequence = _r23_append_snapshot_history(
                phase_snapshot_history, phase_snapshot_witnesses, table,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role=f"terminal_root_exit_absence_{index}")
            reference = _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses, sequence, table,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role=f"terminal_root_exit_absence_{index}")
            current_by_pid = table.by_pid
            present = sorted(pid for pid in closure_pids if pid in current_by_pid)
            if present:
                raise _R23_TABLE.ProcessTableError(
                    f"terminal-root absence table {index} contains a retired PID or reused generation")
            for identity in sorted(outside):
                current = current_by_pid.get(identity[0])
                if current is None or _r23_raw_identity(current) != identity:
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root absence table {index} lost or reused an outside active generation")
            orphans = _r20_descendants_from_pid_set(table, closure_pids)
            if orphans:
                raise _R23_TABLE.ProcessTableError(
                    f"terminal-root absence table {index} has an orphan under a retired generation")
            bundle = _r22_snapshot_bundle(table)
            absence_bundles.append(bundle)
            absence_references.append(reference)
            absence_checks.append({
                "index": index,
                "history_sequence": sequence,
                "snapshot": bundle["snapshot"],
                "closure_pids_absent": sorted(closure_pids),
                "outside_tracked_exact": [
                    {"pid": pid, "create_time_100ns": ticks}
                    for pid, ticks in sorted(outside)],
                "orphan_descendant_count": 0,
            })
        record["absence_snapshot_bundles"] = absence_bundles
        record["absence_history_references"] = absence_references
        record["absence_checks"] = absence_checks
        record["absence_snapshot_count"] = 3
        record["complete"] = True
        record["status"] = "terminal_root_exit_proven_partial_sample_uncredited"
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r23_terminal_root_sample_exit", error,
            record.get("root_identity", {}).get("pid")
            if isinstance(record.get("root_identity"), dict) else None))
        record["rss_credit_bytes"] = 0
        record["cpu_credit_seconds"] = {"user": 0.0, "system": 0.0}
        record["exit_code_credit_issued"] = False
        record["sample_complete"] = False
        record["retry_started"] = False
        record["full_sample_completed_after_retry"] = False
    return record


def _r23_confirm_descendant_terminal_root_sample_exit(
        previous_accepted_source_snapshot: Any,
        outer_reconcile_snapshot: Any,
        source_snapshot: Any,
        root_identity: Any,
        target_identity: Any,
        previously_tracked: list[tuple[int, int]],
        root_handle: Any,
        handle_by_identity: dict[tuple[int, int], Any], *,
        bound_handle_identity_receipts: list[dict[str, Any]],
        sample_index: int,
        attempt_index: int,
        previous_accepted_sample_index: int,
        previous_accepted_source_history_sequence: int,
        outer_reconcile_history_sequence: int,
        source_history_sequence: int,
        r21_probe_record: dict[str, Any],
        r21_probe_observations: list[dict[str, Any]],
        deadline_monotonic: float,
        resource_failure: BaseException,
        partial_rss_bytes: Any,
        working_set_limit_bytes: int,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: list[str],
        snapshot_provider: Any) -> dict[str, Any]:
    """Prove a descendant-triggered terminal root exit without retry or credit."""
    record: dict[str, Any] = {
        "schema": "vnext-t2-r23-descendant-terminal-root-sample-exit-r1",
        "complete": False, "status": "monitor_incomplete",
        "failure_stage": "r23_descendant_terminal_root_handoff",
        "logical_sample_index": sample_index,
        "whole_sample_attempt_index": attempt_index,
        "previous_accepted_sample_index": previous_accepted_sample_index,
        "previous_accepted_source_history_sequence":
            previous_accepted_source_history_sequence,
        "root_identity": None, "target_identity": None,
        "previously_tracked_identities": [], "source_snapshot": None,
        "previous_accepted_source": None, "outer_reconcile_source": None,
        "source_table": None, "source_root_closure": [],
        "source_history_references": [], "trigger_resource_failure": None,
        "r21_incomplete_handoff_observation": None,
        "r21_probe_snapshot_bundles": [], "r21_probe_history_references": [],
        "exact_exit_receipts": [], "root_exit_code": None,
        "absence_snapshot_bundles": [], "absence_history_references": [],
        "absence_checks": [], "absence_snapshot_count": 0,
        "partial_rss_bytes_not_credited": partial_rss_bytes,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False, "sample_complete": False,
        "retry_started": False, "full_sample_completed_after_retry": False,
        "errors": [],
    }
    try:
        root = _R23_TABLE.validate_identity(root_identity)
        target = _R23_TABLE.validate_identity(target_identity)
        previous = tuple(_R23_TABLE.validate_identity(value)
                         for value in previously_tracked)
        if len(previous) != len(set(previous)) or root not in set(previous) or \
                target == root or target not in set(previous):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff requires unique active root and non-root target")
        if type(sample_index) is not int or sample_index <= 1 or \
                type(attempt_index) is not int or attempt_index != 1 or \
                type(previous_accepted_sample_index) is not int or \
                previous_accepted_sample_index != sample_index - 1:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks the immediately prior complete sample")
        if not isinstance(resource_failure, psutil.NoSuchProcess) or \
                type(getattr(resource_failure, "pid", None)) is not int or \
                getattr(resource_failure, "pid", None) != target[0]:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff requires NoSuchProcess for the exact child PID")
        if type(partial_rss_bytes) is not int or partial_rss_bytes < 0 or \
                type(working_set_limit_bytes) is not int or \
                working_set_limit_bytes <= 0 or partial_rss_bytes >= working_set_limit_bytes:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal partial RSS is malformed or reaches the phase ceiling")
        if not isinstance(r21_probe_record, dict) or \
                r21_probe_record.get("schema") != "vnext-t2-r21-tracked-sample-exit-r1" or \
                r21_probe_record.get("complete") is not False or \
                r21_probe_record.get("status") != \
                    "tracked_exit_unconfirmed_monitor_incomplete" or \
                r21_probe_record.get("logical_sample_index") != sample_index or \
                r21_probe_record.get("whole_sample_attempt_index") != attempt_index or \
                r21_probe_record.get("failure_stage") != \
                    "r21_exact_tracked_resource_read_exit" or \
                r21_probe_record.get("retry_started") is not False or \
                r21_probe_record.get("full_sample_completed_after_retry") is not False or \
                r21_probe_record.get("rss_credit_bytes") != 0 or \
                r21_probe_record.get("cpu_credit_seconds") != {
                    "user": 0.0, "system": 0.0} or \
                r21_probe_record.get("exit_code_credit_issued") is not False:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks the original incomplete zero-credit R21 probe")
        probe_errors = r21_probe_record.get("errors")
        if type(probe_errors) is not list or len(probe_errors) != 1 or \
                not isinstance(probe_errors[0], dict) or \
                probe_errors[0].get("stage") != "r21_tracked_sample_exit_confirmation" or \
                probe_errors[0].get("exception_type") != "ProcessTableError" or \
                probe_errors[0].get("message") != \
                    "tracked-exit confirmation 2 lost or reused the stage root" or \
                probe_errors[0].get("pid") != target[0]:
            raise _R23_TABLE.ProcessTableError(
                "R21 probe did not fail at the exact root-loss handoff boundary")
        sample_failure = r21_probe_record.get("sample_failure")
        if not isinstance(sample_failure, dict) or \
                sample_failure.get("exception_type") != "NoSuchProcess" or \
                sample_failure.get("pid") != target[0]:
            raise _R23_TABLE.ProcessTableError(
                "R21 probe does not bind the original descendant resource failure")
        if r21_probe_record.get("absence_snapshot_count") != 1 or \
                type(r21_probe_record.get("absence_checks")) is not list or \
                len(r21_probe_record["absence_checks"]) != 1 or \
                type(r21_probe_record.get("absence_snapshots")) is not list or \
                len(r21_probe_record["absence_snapshots"]) != 1:
            raise _R23_TABLE.ProcessTableError(
                "R21 handoff observation does not preserve its single successful absence check")
        if type(r21_probe_observations) is not list or len(r21_probe_observations) != 2 or \
                any(not isinstance(item, dict) or
                    type(item.get("sequence")) is not int or
                    item.get("snapshot") is None for item in r21_probe_observations):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks both actual ordered R21 SPI observations")
        if not isinstance(handle_by_identity, dict) or root_handle is None or \
                type(bound_handle_identity_receipts) is not list:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks original handle bindings")
        if type(phase_snapshot_history) is not list or \
                type(phase_snapshot_witnesses) is not list or \
                len(phase_snapshot_history) != len(phase_snapshot_witnesses):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks aligned phase history witnesses")

        accepted = _R23_TABLE.validate_snapshot(previous_accepted_source_snapshot)
        outer = _R23_TABLE.validate_snapshot(outer_reconcile_snapshot)
        source = _R23_TABLE.validate_snapshot(source_snapshot)
        record["root_identity"] = {"pid": root[0], "create_time_100ns": root[1]}
        record["target_identity"] = {"pid": target[0], "create_time_100ns": target[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(previous)]
        record["source_snapshot"] = _r23_snapshot_receipt(source)
        record["trigger_resource_failure"] = {
            "type": type(resource_failure).__name__,
            "pid": getattr(resource_failure, "pid", None),
            "message": str(resource_failure),
        }
        accepted_rows = _r23_terminal_root_closure_rows(accepted, root, list(previous))
        outer_rows = _r23_terminal_root_closure_rows(outer, root, list(previous))
        source_rows = _r23_terminal_root_closure_rows(source, root, list(previous))
        if accepted_rows != outer_rows or outer_rows != source_rows:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal accepted, outer, and failed-source closures differ")
        record["source_root_closure"] = copy.deepcopy(source_rows)
        closure_ids = {(row["pid"], row["create_time_100ns"]) for row in source_rows}
        if closure_ids != set(previous) or target not in closure_ids:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal source closure differs from the complete active inventory")
        source_target = source.by_pid.get(target[0])
        if source_target is None or _r23_raw_identity(source_target) != target:
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal target is absent or reused in its source table")
        target_subtree = _R23_TABLE.descendant_identities(source, target)
        target_subtree_ids = {(item.pid, item.create_time_100ns) for item in target_subtree}
        if not target_subtree_ids or not target_subtree_ids.issubset(closure_ids):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal target subtree is not an exact source-closure subset")
        r21_retired = {
            _R23_TABLE.validate_identity((item.get("pid"), item.get("create_time_100ns")))
            for item in r21_probe_record.get("retired_tracked_identities", [])
            if isinstance(item, dict)}
        if r21_retired != target_subtree_ids:
            raise _R23_TABLE.ProcessTableError(
                "R21 handoff retired set differs from the exact target subtree")
        r21_previous_values = r21_probe_record.get("previously_tracked_identities")
        if type(r21_previous_values) is not list or any(
                not isinstance(item, dict) or set(item) != {
                    "pid", "create_time_100ns"} for item in r21_previous_values):
            raise _R23_TABLE.ProcessTableError(
                "R21 handoff active inventory is malformed")
        r21_previous = [_R23_TABLE.validate_identity((
            item.get("pid"), item.get("create_time_100ns")))
            for item in r21_previous_values]
        if len(r21_previous) != len(set(r21_previous)) or \
                r21_probe_record.get("source_snapshot") != _r23_snapshot_receipt(source) or \
                r21_probe_record.get("root_identity") != record["root_identity"] or \
                set(r21_previous) != set(previous):
            raise _R23_TABLE.ProcessTableError(
                "R21 handoff observation is not bound to the terminal source and active closure")
        if sorted(r21_probe_record.get("source_root_closure", []),
                  key=lambda item: (item.get("pid"), item.get("create_time_100ns"))) != source_rows:
            raise _R23_TABLE.ProcessTableError(
                "R21 handoff source closure differs from the accepted terminal closure")

        source_refs = [
            _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                previous_accepted_source_history_sequence, accepted,
                sample_index=previous_accepted_sample_index,
                source_role="sample_source_before"),
            _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                outer_reconcile_history_sequence, outer,
                sample_index=sample_index, attempt_index=0,
                source_role="outer_reconcile"),
            _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                source_history_sequence, source,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role="sample_source_before"),
        ]
        if not (previous_accepted_source_history_sequence <
                outer_reconcile_history_sequence < source_history_sequence):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal source history references are not ordered")
        record["source_history_references"] = [
            {"role": role, "reference": reference} for role, reference in zip(
                ("previous_accepted_source", "outer_reconcile", "failed_sample_source"),
                source_refs)]
        record["previous_accepted_source"] = _r22_snapshot_bundle(accepted)
        record["outer_reconcile_source"] = _r22_snapshot_bundle(outer)
        record["source_table"] = _r22_snapshot_bundle(source)

        probe_bundles: list[dict[str, Any]] = []
        probe_references: list[dict[str, Any]] = []
        for index, observation in enumerate(r21_probe_observations, start=1):
            sequence = observation["sequence"]
            table = _R23_TABLE.validate_snapshot(observation["snapshot"])
            role = f"tracked_exit_absence_{index}"
            reference = _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses, sequence, table,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role=role)
            if sequence <= source_history_sequence:
                raise _R23_TABLE.ProcessTableError(
                    "R21 root-loss observation precedes failed-source capture")
            probe_bundles.append({"sequence": sequence, "source_role": role,
                                  "snapshot_bundle": _r22_snapshot_bundle(table)})
            probe_references.append(reference)
        if not (source_history_sequence < probe_bundles[0]["sequence"] <
                probe_bundles[1]["sequence"]):
            raise _R23_TABLE.ProcessTableError(
                "R21 root-loss observations are not strictly ordered")
        first_probe = _R23_TABLE.validate_snapshot(r21_probe_observations[0]["snapshot"])
        first_root = first_probe.by_pid.get(root[0])
        if first_root is None or _r23_raw_identity(first_root) != root:
            raise _R23_TABLE.ProcessTableError(
                "R21 absence one did not retain the exact live root")
        target_pids = {pid for pid, _ in target_subtree_ids}
        if target_pids.intersection(first_probe.by_pid) or \
                _r20_descendants_from_pid_set(first_probe, target_pids):
            raise _R23_TABLE.ProcessTableError(
                "R21 absence one did not prove the exact descendant subtree absent")
        other_active = set(previous).difference(target_subtree_ids)
        for identity in other_active:
            current = first_probe.by_pid.get(identity[0])
            if current is None or _r23_raw_identity(current) != identity:
                raise _R23_TABLE.ProcessTableError(
                    "R21 absence one lost or reused another active generation")
        check_one = r21_probe_record["absence_checks"][0]
        expected_other = [{"pid": pid, "create_time_100ns": ticks}
                          for pid, ticks in sorted(other_active)]
        if check_one.get("index") != 1 or check_one.get("root_exact") is not True or \
                check_one.get("root_identity") != record["root_identity"] or \
                check_one.get("snapshot") != _r23_snapshot_receipt(first_probe) or \
                check_one.get("subtree_pids_absent") != sorted(target_pids) or \
                check_one.get("other_previously_tracked_identities") != expected_other or \
                r21_probe_record["absence_snapshots"][0] != _r23_snapshot_receipt(first_probe):
            raise _R23_TABLE.ProcessTableError(
                "R21 absence-one receipt differs from its captured raw SPI table")
        second_probe = _R23_TABLE.validate_snapshot(r21_probe_observations[1]["snapshot"])
        if second_probe.by_pid.get(root[0]) is not None:
            raise _R23_TABLE.ProcessTableError(
                "R21 confirmation two shows a live or reused root PID, not terminal absence")
        closure_pids = {pid for pid, _ in closure_ids}
        if closure_pids.intersection(second_probe.by_pid) or \
                _r20_descendants_from_pid_set(second_probe, closure_pids):
            raise _R23_TABLE.ProcessTableError(
                "R21 confirmation two has a reappeared closure PID or orphan descendant")
        record["r21_incomplete_handoff_observation"] = copy.deepcopy(r21_probe_record)
        record["r21_probe_snapshot_bundles"] = probe_bundles
        record["r21_probe_history_references"] = probe_references

        if len(bound_handle_identity_receipts) != len(source_rows):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handoff lacks one source-bound handle receipt per generation")
        receipt_ids: list[tuple[int, int]] = []
        for item in bound_handle_identity_receipts:
            if not isinstance(item, dict) or \
                    item.get("source_snapshot") != _r23_snapshot_receipt(source):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal handle receipt is not bound to the failed source")
            receipt_ids.append(_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns"))))
        expected_ids = [(row["pid"], row["create_time_100ns"]) for row in source_rows]
        if len(receipt_ids) != len(set(receipt_ids)) or set(receipt_ids) != set(expected_ids):
            raise _R23_TABLE.ProcessTableError(
                "descendant-terminal handle receipts do not exactly cover the source closure")
        exits: list[dict[str, Any]] = []
        for identity in expected_ids:
            handle = root_handle if identity == root else handle_by_identity.get(identity)
            if handle is None:
                raise _R23_TABLE.ProcessTableError(
                    f"original exact handle is unavailable for closure PID {identity[0]}")
            before = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                before, identity, phase="R23 descendant-terminal pre-wait handle")
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during descendant-terminal handle proof")
            waited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
            if type(waited) is not bool or waited is not True:
                raise _R23_TABLE.ProcessTableError(
                    f"original exact handle did not confirm exit for closure PID {identity[0]}")
            after = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                after, identity, phase="R23 descendant-terminal post-wait handle")
            exit_code = _R23_TABLE.process_exit_code(handle)
            if type(exit_code) is not int or isinstance(exit_code, bool) or exit_code == 259:
                raise _R23_TABLE.ProcessTableError(
                    f"original exact handle has invalid/STILL_ACTIVE exit code for PID {identity[0]}")
            exits.append({
                "schema": "vnext-t2-r23-descendant-terminal-generation-exit-r1",
                "complete": True,
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "handle_owner": "original_popen_handle" if identity == root
                                else "retained_registry_handle",
                "handle_identity_before_wait": {
                    "pid": before[0], "create_time_100ns": before[1]},
                "wait_confirmed": True,
                "handle_identity_after_wait": {
                    "pid": after[0], "create_time_100ns": after[1]},
                "exit_code": exit_code,
                "exit_code_credit_issued": False, "errors": [],
            })
        record["exact_exit_receipts"] = exits
        record["root_exit_code"] = next(item["exit_code"] for item in exits
            if (item["identity"]["pid"], item["identity"]["create_time_100ns"]) == root)

        absence_bundles: list[dict[str, Any]] = []
        absence_references: list[dict[str, Any]] = []
        absence_checks: list[dict[str, Any]] = []
        for index in range(1, 4):
            if time.monotonic() >= deadline_monotonic:
                raise TimeoutError(
                    "phase deadline reached during descendant-terminal absence confirmation")
            table = _R23_TABLE.validate_snapshot(snapshot_provider())
            role = f"descendant_terminal_root_absence_{index}"
            sequence = _r23_append_snapshot_history(
                phase_snapshot_history, phase_snapshot_witnesses, table,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role=role)
            reference = _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses, sequence, table,
                sample_index=sample_index, attempt_index=attempt_index,
                source_role=role)
            present = sorted(pid for pid in closure_pids if pid in table.by_pid)
            if present or _r20_descendants_from_pid_set(table, closure_pids):
                raise _R23_TABLE.ProcessTableError(
                    f"descendant-terminal absence table {index} has a closure PID or orphan")
            bundle = _r22_snapshot_bundle(table)
            absence_bundles.append({"sequence": sequence, "source_role": role,
                                    "snapshot_bundle": bundle})
            absence_references.append(reference)
            absence_checks.append({
                "index": index, "history_sequence": sequence,
                "snapshot": bundle["snapshot"],
                "closure_pids_absent": sorted(closure_pids),
                "orphan_descendant_count": 0,
            })
        record["absence_snapshot_bundles"] = absence_bundles
        record["absence_history_references"] = absence_references
        record["absence_checks"] = absence_checks
        record["absence_snapshot_count"] = 3
        record["complete"] = True
        record["status"] = \
            "descendant_exit_then_terminal_root_proven_partial_sample_uncredited"
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r23_descendant_terminal_root_handoff", error,
            record.get("root_identity", {}).get("pid")
            if isinstance(record.get("root_identity"), dict) else None))
        record["rss_credit_bytes"] = 0
        record["cpu_credit_seconds"] = {"user": 0.0, "system": 0.0}
        record["exit_code_credit_issued"] = False
        record["sample_complete"] = False
        record["retry_started"] = False
        record["full_sample_completed_after_retry"] = False
    return record


def _r23_snapshot_from_bundle(value: Any) -> Any:
    if not isinstance(value, dict) or set(value) != {"schema", "snapshot", "rows"} or \
            value.get("schema") != "vnext-t2-r23-process-table-evidence-r1" or \
            not _r20_valid_snapshot_receipt(value.get("snapshot")) or \
            type(value.get("rows")) is not list:
        raise _R23_TABLE.ProcessTableError(
            "R23 membership-growth evidence bundle has an invalid shape")
    receipt = value["snapshot"]
    raw_rows = value["rows"]
    if len(raw_rows) != receipt.get("row_count"):
        raise _R23_TABLE.ProcessTableError(
            "R23 membership-growth row count differs from its receipt")
    rows = []
    seen: set[int] = set()
    for item in raw_rows:
        if not isinstance(item, dict) or set(item) != {
                "pid", "create_time_100ns", "ppid", "name"} or \
                type(item.get("name")) is not str:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth raw row has an invalid shape")
        pid = _R23_TABLE.validate_pid(item.get("pid"), allow_zero=True)
        ticks = _R23_TABLE.validate_ticks(item.get("create_time_100ns"))
        ppid = _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
        if pid in seen:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth raw rows duplicate a PID")
        seen.add(pid)
        rows.append(_R23_TABLE.ProcessRow(
            _R23_TABLE.ProcessIdentity(pid, ticks), ppid, item["name"]))
    table = _R23_TABLE.ProcessTableSnapshot(
        tuple(rows), tuple(receipt["host_identity"]), receipt["buffer_bytes"],
        receipt["query_attempts"])
    if _r23_snapshot_receipt(table) != receipt:
        raise _R23_TABLE.ProcessTableError(
            "R23 membership-growth raw rows do not reproduce their snapshot receipt")
    return table


def _r23_monitor_digest_matches(snapshot: Any, digest: Any) -> bool:
    if type(digest) not in (list, tuple):
        return False
    try:
        observed = tuple(tuple(row) for row in digest)
        expected = _R23_TABLE.native_snapshot_digest(
            _R23_TABLE.validate_snapshot(snapshot))
    except Exception:
        return False
    return observed == expected


def _r23_row_evidence(rows: dict[tuple[int, int], Any]) -> list[dict[str, Any]]:
    return [{"pid": identity[0], "create_time_100ns": identity[1],
             "ppid": row.ppid, "name": row.name}
            for identity, row in sorted(rows.items())]


def _r23_confirm_membership_growth(
        previous_accepted_source_snapshot: Any | None,
        outer_reconcile_snapshot: Any,
        failed_attempt_before_snapshot: Any,
        failed_attempt_after_snapshot: Any,
        root_identity: Any,
        previously_tracked: list[tuple[int, int]], *,
        previous_accepted_sample_index: int | None,
        sample_index: int,
        attempt_index: int,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: Any,
        previous_accepted_source_history_sequence: int | None,
        outer_reconcile_history_sequence: int,
        failed_attempt_before_history_sequence: int,
        failed_attempt_after_history_sequence: int,
        deadline_monotonic: float | None,
        partial_rss_bytes: Any,
        exact_monitor_receipt: Any) -> dict[str, Any]:
    """Prove one strict, raw-table descendant addition and require a new sample."""
    record: dict[str, Any] = {
        "schema": "vnext-t2-r23-membership-growth-r2",
        "complete": False,
        "status": "monitor_incomplete",
        "growth_verified": False,
        "sample_index": sample_index,
        "attempt_index": attempt_index,
        "previous_accepted_sample_index": previous_accepted_sample_index,
        "root_identity": None,
        "previously_tracked_identities": [],
        "previous_accepted_source": None,
        "outer_reconcile_source": None,
        "failed_attempt_before_source": None,
        "failed_attempt_after_source": None,
        "snapshot_history_binding": None,
        "before_closure": [],
        "after_closure": [],
        "observed_generations": [],
        "discarded_attempt": None,
        "partial_rss_bytes_not_credited": 0,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "exact_handle_exit_receipt_created": False,
        "retry_started": False,
        "full_sample_completed_after_retry": False,
        "full_sample_attempt_index": None,
        "fresh_final_binding": None,
        "errors": [],
    }
    try:
        root = _R23_TABLE.validate_identity(root_identity)
        previous_values = [_R23_TABLE.validate_identity(item)
                           for item in previously_tracked]
        previous = set(previous_values)
        if len(previous) != len(previous_values) or root not in previous:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth history duplicates identities or omits root")
        if type(sample_index) is not int or sample_index <= 0 or \
                type(attempt_index) is not int or attempt_index <= 0:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth attempt indices are invalid")
        if previous_accepted_sample_index is None:
            if sample_index != 1 or previous_accepted_source_snapshot is not None:
                raise _R23_TABLE.ProcessTableError(
                    "R23 growth lacks a prior accepted source outside the first sample")
        elif type(previous_accepted_sample_index) is not int or \
                previous_accepted_sample_index <= 0 or \
                previous_accepted_sample_index >= sample_index or \
                previous_accepted_source_snapshot is None:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth prior accepted source index is invalid")
        if type(partial_rss_bytes) is not int or partial_rss_bytes < 0:
            raise _R23_TABLE.ProcessTableError(
                "R23 discarded partial RSS is not a nonnegative integer")
        if deadline_monotonic is not None and (
                type(deadline_monotonic) not in (int, float) or
                isinstance(deadline_monotonic, bool) or
                not math.isfinite(float(deadline_monotonic)) or
                time.monotonic() >= float(deadline_monotonic)):
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth confirmation reached its phase deadline")
        if not isinstance(exact_monitor_receipt, dict) or \
                exact_monitor_receipt.get("complete") is not False or \
                type(exact_monitor_receipt.get("errors")) is not list or \
                len(exact_monitor_receipt["errors"]) != 1 or \
                not isinstance(exact_monitor_receipt["errors"][0], dict) or \
                exact_monitor_receipt["errors"][0].get("message") != \
                    "process tree membership/generation changed during sample":
            raise _R23_TABLE.ProcessTableError(
                "R23 growth lane requires the exact membership-change monitor failure")
        observed_partial = exact_monitor_receipt.get("partial_rss_bytes")
        if type(observed_partial) is not int or observed_partial != partial_rss_bytes:
            raise _R23_TABLE.ProcessTableError(
                "R23 discarded RSS differs from the incomplete exact monitor receipt")

        outer = _R23_TABLE.validate_snapshot(outer_reconcile_snapshot)
        before = _R23_TABLE.validate_snapshot(failed_attempt_before_snapshot)
        after = _R23_TABLE.validate_snapshot(failed_attempt_after_snapshot)
        accepted = (_R23_TABLE.validate_snapshot(previous_accepted_source_snapshot)
                    if previous_accepted_source_snapshot is not None else None)
        record["root_identity"] = {
            "pid": root[0], "create_time_100ns": root[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(previous)]
        if accepted is not None:
            record["previous_accepted_source"] = _r23_snapshot_bundle(accepted)
        record["outer_reconcile_source"] = _r23_snapshot_bundle(outer)
        record["failed_attempt_before_source"] = _r23_snapshot_bundle(before)
        record["failed_attempt_after_source"] = _r23_snapshot_bundle(after)

        # Preserve every exact after-table row reachable under the phase root
        # that is outside the already tracked set before any proof check can
        # reject this lane. The cleanup inventory consumes this field even for
        # an incomplete growth record; it never grants sample or exit credit.
        observed_candidates: dict[tuple[int, int], Any] = {}
        try:
            observed_before_rows = _r23_observed_root_reachable_rows(before, root)
            record["before_closure"] = _r23_row_evidence(observed_before_rows)
            observed_candidates.update({identity: row
                for identity, row in observed_before_rows.items()
                if identity not in previous})
        except Exception:
            pass
        try:
            observed_after_rows = _r23_observed_root_reachable_rows(after, root)
            record["after_closure"] = _r23_row_evidence(observed_after_rows)
            observed_candidates.update({identity: row
                for identity, row in observed_after_rows.items()
                if identity not in previous})
        except Exception:
            pass
        record["observed_generations"] = _r23_row_evidence(observed_candidates)

        if type(outer_reconcile_history_sequence) is not int or \
                type(failed_attempt_before_history_sequence) is not int or \
                type(failed_attempt_after_history_sequence) is not int or \
                (accepted is None) != \
                    (previous_accepted_source_history_sequence is None):
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth snapshot history references are incomplete")
        outer_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            outer_reconcile_history_sequence, outer,
            sample_index=sample_index, attempt_index=0,
            source_role="outer_reconcile")
        before_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            failed_attempt_before_history_sequence, before,
            sample_index=sample_index, attempt_index=attempt_index,
            source_role="sample_source_before")
        after_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            failed_attempt_after_history_sequence, after,
            sample_index=sample_index, attempt_index=attempt_index,
            source_role="sample_source_after")
        accepted_reference = None
        if accepted is not None:
            accepted_reference = _r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                previous_accepted_source_history_sequence, accepted,
                sample_index=previous_accepted_sample_index,
                source_role="sample_source_before")
        sequence_refs = [outer_reconcile_history_sequence,
                         failed_attempt_before_history_sequence,
                         failed_attempt_after_history_sequence]
        if accepted is not None:
            sequence_refs.insert(0, previous_accepted_source_history_sequence)
        if sequence_refs != sorted(sequence_refs) or \
                failed_attempt_before_history_sequence <= outer_reconcile_history_sequence or \
                failed_attempt_after_history_sequence <= failed_attempt_before_history_sequence:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth snapshot history references are out of order")
        prefix = _r23_snapshot_history_prefix_receipt(
            phase_snapshot_history, phase_snapshot_witnesses,
            failed_attempt_before_history_sequence)
        record["snapshot_history_binding"] = {
            "schema": "vnext-t2-r23-membership-growth-history-binding-r2",
            "previous_accepted_source": accepted_reference,
            "outer_reconcile_source": outer_reference,
            "failed_attempt_before_source": before_reference,
            "failed_attempt_after_source": after_reference,
            "pre_growth_absence_prefix": prefix,
        }

        baseline = [table for table in (accepted, outer, before) if table is not None]
        baseline_closures = [_r23_root_closure_rows(table, root)
                             for table in baseline]
        expected_old = previous
        for closure in baseline_closures:
            if set(closure) != expected_old:
                raise _R23_TABLE.ProcessTableError(
                    "R23 prior/outer/before closure differs from active tracked identities")
        reference_rows = baseline_closures[-1]
        for closure in baseline_closures[:-1]:
            for identity in sorted(expected_old):
                left, right = closure[identity], reference_rows[identity]
                if (left.ppid, left.name) != (right.ppid, right.name):
                    raise _R23_TABLE.ProcessTableError(
                        "R23 prior accepted and pre-growth tracked parent/name rows disagree")
        before_closure = baseline_closures[-1]
        after_closure = _r23_root_closure_rows(after, root)
        before_ids, after_ids = set(before_closure), set(after_closure)
        added = after_ids.difference(before_ids)
        record["before_closure"] = _r23_row_evidence(before_closure)
        record["after_closure"] = _r23_row_evidence(after_closure)
        record["partial_rss_bytes_not_credited"] = partial_rss_bytes
        record["discarded_attempt"] = {
            "sample_index": sample_index,
            "attempt_index": attempt_index,
            "sample_complete": False,
            "observed_partial_rss_bytes_not_credited": partial_rss_bytes,
            "measured_identities_not_credited": copy.deepcopy(
                exact_monitor_receipt.get("measured_identities", [])),
            "credited_rss_bytes": 0,
            "credited_cpu_seconds": {"user": 0.0, "system": 0.0},
            "exit_code_credit_issued": False,
            "exact_handle_exit_receipt_created": False,
            "exact_monitor_receipt": copy.deepcopy(exact_monitor_receipt),
        }

        if attempt_index != 1:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership growth has no remaining whole-sample retry")
        if not added or not before_ids.issubset(after_ids) or before_ids == after_ids:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership change is not a strict descendant addition")
        if before_ids != expected_old:
            raise _R23_TABLE.ProcessTableError(
                "R23 failed-before closure is not the exact accepted tracked set")
        for identity in sorted(expected_old):
            before_row, after_row = before_closure[identity], after_closure[identity]
            if (before_row.ppid, before_row.name) != (after_row.ppid, after_row.name):
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership growth changed a previously tracked parent/name row")
        historical_pid_sets = _r23_validate_snapshot_history(
            phase_snapshot_history, phase_snapshot_witnesses,
            through_sequence=failed_attempt_before_history_sequence)
        for identity in sorted(added):
            if any(identity[0] in history_entry["pids"]
                   for history_entry in historical_pid_sets):
                raise _R23_TABLE.ProcessTableError(
                    "R23 added PID existed in a prior complete phase SPI source")
            row = after_closure[identity]
            parent = after.by_pid.get(row.ppid)
            if parent is None or row.identity.create_time_100ns < \
                    parent.identity.create_time_100ns:
                raise _R23_TABLE.ProcessTableError(
                    "R23 added identity lacks an exact monotone parent generation")
        if not _r23_monitor_digest_matches(
                before, exact_monitor_receipt.get("native_snapshot_before_digest")) or \
                not _r23_monitor_digest_matches(
                    after, exact_monitor_receipt.get("native_snapshot_after_digest")):
            raise _R23_TABLE.ProcessTableError(
                "R23 monitor's failed-sample digests differ from captured SPI tables")
        record["growth_verified"] = True
        record["complete"] = True
        record["status"] = "strict_membership_growth_confirmed_retry_required"
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r23_membership_growth_confirmation", error,
            record.get("root_identity", {}).get("pid")
            if isinstance(record.get("root_identity"), dict) else None))
    return record


def _r23_membership_growth_retry_binding(
        record: dict[str, Any], before_snapshot: Any, after_snapshot: Any,
        exact_monitor_receipt: Any,
        handle_identity_receipts: Any, *,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: Any,
        retry_before_history_sequence: int,
        retry_after_history_sequence: int) -> dict[str, Any]:
    if not isinstance(record, dict) or \
            record.get("schema") != "vnext-t2-r23-membership-growth-r2" or \
            record.get("growth_verified") is not True or \
            record.get("complete") is not True:
        raise _R23_TABLE.ProcessTableError(
            "R23 fresh-sample binding lacks a verified growth record")
    root_item = record.get("root_identity")
    if not isinstance(root_item, dict):
        raise _R23_TABLE.ProcessTableError("R23 growth record lacks its root identity")
    root = _R23_TABLE.validate_identity((
        root_item.get("pid"), root_item.get("create_time_100ns")))
    previous_rows = record.get("previously_tracked_identities")
    observed_rows = record.get("observed_generations")
    if type(previous_rows) is not list or type(observed_rows) is not list or \
            not observed_rows:
        raise _R23_TABLE.ProcessTableError(
            "R23 fresh-sample binding lacks old/observed identities")
    previous = [_R23_TABLE.validate_identity((
        item.get("pid"), item.get("create_time_100ns")))
        for item in previous_rows if isinstance(item, dict)]
    observed = [_R23_TABLE.validate_identity((
        item.get("pid"), item.get("create_time_100ns")))
        for item in observed_rows if isinstance(item, dict)]
    if len(previous) != len(previous_rows) or len(set(previous)) != len(previous) or \
            len(observed) != len(observed_rows) or len(set(observed)) != len(observed) or \
            root not in set(previous):
        raise _R23_TABLE.ProcessTableError(
            "R23 fresh-sample identity inventory is malformed")
    expected = set(previous) | set(observed)
    before = _R23_TABLE.validate_snapshot(before_snapshot)
    after = _R23_TABLE.validate_snapshot(after_snapshot)
    source_binding = record.get("snapshot_history_binding")
    if not isinstance(source_binding, dict) or \
            source_binding.get("schema") != \
                "vnext-t2-r23-membership-growth-history-binding-r2":
        raise _R23_TABLE.ProcessTableError(
            "R23 retry lacks its original phase-history prefix binding")
    source_after_reference = source_binding.get("failed_attempt_after_source")
    if not isinstance(source_after_reference, dict):
        raise _R23_TABLE.ProcessTableError(
            "R23 retry lacks its original growth-after history reference")
    if type(retry_before_history_sequence) is not int or \
            type(retry_after_history_sequence) is not int or \
            retry_before_history_sequence <= source_after_reference.get("sequence", -1) or \
            retry_after_history_sequence <= retry_before_history_sequence:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry snapshot history references are not strictly ordered")
    retry_before_reference = _r23_snapshot_history_reference(
        phase_snapshot_history, phase_snapshot_witnesses,
        retry_before_history_sequence, before,
        sample_index=record.get("sample_index"), attempt_index=2,
        source_role="sample_source_before")
    retry_after_reference = _r23_snapshot_history_reference(
        phase_snapshot_history, phase_snapshot_witnesses,
        retry_after_history_sequence, after,
        sample_index=record.get("sample_index"), attempt_index=2,
        source_role="sample_source_after")
    retry_prefix = _r23_snapshot_history_prefix_receipt(
        phase_snapshot_history, phase_snapshot_witnesses,
        retry_after_history_sequence)
    before_closure = _r23_root_closure_rows(before, root)
    after_closure = _r23_root_closure_rows(after, root)
    if set(before_closure) != expected or set(after_closure) != expected:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry source does not contain the exact observed growth closure")
    original_before = _r23_snapshot_from_bundle(
        record.get("failed_attempt_before_source"))
    original_after = _r23_snapshot_from_bundle(
        record.get("failed_attempt_after_source"))
    old_closure = _r23_root_closure_rows(original_before, root)
    growth_closure = _r23_root_closure_rows(original_after, root)
    if set(old_closure) != set(previous) or \
            set(growth_closure) != expected:
        raise _R23_TABLE.ProcessTableError(
            "R23 original source bundles do not reproduce the exact growth set")
    for identity in sorted(expected):
        before_row, after_row = before_closure[identity], after_closure[identity]
        expected_row = (old_closure.get(identity) or growth_closure.get(identity))
        if expected_row is None or \
                (before_row.ppid, before_row.name) != \
                (after_row.ppid, after_row.name) or \
                (before_row.ppid, before_row.name) != \
                (expected_row.ppid, expected_row.name):
            raise _R23_TABLE.ProcessTableError(
                "R23 retry changed an observed identity's exact parent/name row")
    if not isinstance(exact_monitor_receipt, dict) or \
            exact_monitor_receipt.get("complete") is not True or \
            exact_monitor_receipt.get("errors") != [] or \
            not _r23_monitor_digest_matches(
                before, exact_monitor_receipt.get("native_snapshot_before_digest")) or \
            not _r23_monitor_digest_matches(
                after, exact_monitor_receipt.get("native_snapshot_after_digest")):
        raise _R23_TABLE.ProcessTableError(
            "R23 retry lacks a complete exact before/after SPI sample")
    identity_sets = {}
    for field in ("discovered_identities", "measured_identities"):
        raw = exact_monitor_receipt.get(field)
        if type(raw) is not list:
            raise _R23_TABLE.ProcessTableError(
                f"R23 retry exact receipt lacks {field}")
        ids = {_R23_TABLE.validate_identity((
            item.get("pid"), item.get("create_time_100ns")))
            for item in raw if isinstance(item, dict)}
        if len(ids) != len(raw) or ids != expected:
            raise _R23_TABLE.ProcessTableError(
                f"R23 retry {field} differs from the exact observed tree")
        identity_sets[field] = ids
    resources = exact_monitor_receipt.get("processes")
    if type(resources) is not list:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry has no complete resource rows")
    resource_ids = {_R23_TABLE.validate_identity((
        item.get("pid"), item.get("create_time_100ns")))
        for item in resources if isinstance(item, dict)}
    if len(resource_ids) != len(resources) or resource_ids != expected:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry resources do not cover every old and added identity")
    for item in resources:
        for field in ("rss_bytes", "cpu_user_seconds", "cpu_system_seconds"):
            value = item.get(field)
            if type(value) not in (int, float) or isinstance(value, bool) or \
                    not math.isfinite(float(value)) or value < 0:
                raise _R23_TABLE.ProcessTableError(
                    "R23 retry resource row is malformed or non-finite")
    if type(handle_identity_receipts) is not list:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry has no exact handle identity receipts")
    handle_ids = []
    for item in handle_identity_receipts:
        if not isinstance(item, dict) or set(item) != {
                "pid", "create_time_100ns", "source_snapshot"}:
            raise _R23_TABLE.ProcessTableError(
                "R23 retry handle identity receipt is malformed")
        handle_ids.append(_R23_TABLE.validate_identity((
            item.get("pid"), item.get("create_time_100ns"))))
        if not _r20_valid_snapshot_receipt(item.get("source_snapshot")) or \
                item.get("source_snapshot") != _r23_snapshot_receipt(before):
            raise _R23_TABLE.ProcessTableError(
                "R23 retry handle was not bound to the exact fresh source table")
    if len(handle_ids) != len(set(handle_ids)) or set(handle_ids) != expected:
        raise _R23_TABLE.ProcessTableError(
            "R23 retry exact handles do not cover each exact tree generation once")
    return {
        "schema": "vnext-t2-r23-membership-growth-fresh-binding-r2",
        "complete": True,
        "attempt_index": 2,
        "snapshot_history_binding": {
        "schema": "vnext-t2-r23-membership-growth-retry-history-binding-r2",
            "source_failed_attempt_after": copy.deepcopy(source_after_reference),
            "retry_source_before": retry_before_reference,
            "retry_source_after": retry_after_reference,
            "retry_prefix": retry_prefix,
        },
        "source_before": _r23_snapshot_bundle(before),
        "source_after": _r23_snapshot_bundle(after),
        "exact_monitor_receipt": copy.deepcopy(exact_monitor_receipt),
        "expected_identity_rows": _r23_row_evidence(before_closure),
        "resource_rows": copy.deepcopy(resources),
        "handle_identity_receipts": copy.deepcopy(handle_identity_receipts),
        "exact_identity_count": len(expected),
    }


def _r23_bind_membership_growth_retry(
        record: dict[str, Any], before_snapshot: Any, after_snapshot: Any,
        exact_monitor_receipt: Any,
        handle_identity_receipts: Any, *,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: Any,
        retry_before_history_sequence: int,
        retry_after_history_sequence: int) -> bool:
    try:
        binding = _r23_membership_growth_retry_binding(
            record, before_snapshot, after_snapshot, exact_monitor_receipt,
            handle_identity_receipts,
            phase_snapshot_history=phase_snapshot_history,
            phase_snapshot_witnesses=phase_snapshot_witnesses,
            retry_before_history_sequence=retry_before_history_sequence,
            retry_after_history_sequence=retry_after_history_sequence)
        record["fresh_final_binding"] = binding
        record["complete"] = True
        record["full_sample_completed_after_retry"] = True
        record["full_sample_attempt_index"] = 2
        record["retry_started"] = True
        record["status"] = "strict_membership_growth_recovered_by_complete_retry"
        return True
    except Exception as error:
        record["complete"] = False
        record["full_sample_completed_after_retry"] = False
        record["status"] = "membership_growth_retry_unconfirmed_monitor_incomplete"
        record.setdefault("errors", []).append(_monitor_error(
            "r23_membership_growth_retry_binding", error))
        return False


def _r23_audit_membership_growth(
        snapshot: Any, records: list[dict[str, Any]],
        expected_root_identity: Any,
        historical_tracked_identities: list[tuple[int, int]],
        phase_snapshot_history: list[dict[str, Any]] | None = None,
        phase_snapshot_witnesses: Any = None) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    observed: dict[tuple[int, int], dict[str, Any]] = {}
    if type(records) is not list:
        return {"schema": "vnext-t2-r23-membership-growth-final-audit-r1",
                "complete": False, "record_count": 0,
                "observed_generations": [], "residual_observed_generations": [],
                "errors": [_monitor_error(
                    "r23_membership_growth_final_audit",
                    RuntimeError("membership-growth records are not a list"))]}
    try:
        final_table = _R23_TABLE.validate_snapshot(snapshot)
        root = _R23_TABLE.validate_identity(expected_root_identity)
        historical_values = [_R23_TABLE.validate_identity(item)
                             for item in historical_tracked_identities]
        historical = set(historical_values)
        if len(historical) != len(historical_values) or root not in historical:
            raise _R23_TABLE.ProcessTableError(
                "R23 membership-growth final audit history omits or duplicates root")
        witness_ledger = _r23_snapshot_witness_ledger_receipt(
            phase_snapshot_witnesses)
        _r23_validate_snapshot_history(
            phase_snapshot_history, phase_snapshot_witnesses)
    except Exception as error:
        return {"schema": "vnext-t2-r23-membership-growth-final-audit-r1",
                "complete": False, "record_count": 0,
                "observed_generations": [], "residual_observed_generations": [],
                "errors": [_monitor_error(
                    "r23_membership_growth_final_audit", error)]}

    for index, record in enumerate(records):
        if not isinstance(record, dict) or \
                record.get("schema") != "vnext-t2-r23-membership-growth-r2":
            errors.append(_monitor_error(
                "r23_membership_growth_final_audit",
                RuntimeError(f"membership-growth record {index} has an invalid schema")))
            continue
        rows = record.get("observed_generations")
        record_observed: list[tuple[int, int]] = []
        if type(rows) is not list or not rows:
            errors.append(_monitor_error(
                "r23_membership_growth_final_audit",
                RuntimeError(f"membership-growth record {index} has no observed rows")))
            continue
        for item in rows:
            try:
                if not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns", "ppid", "name"} or \
                        type(item.get("ppid")) is not int or \
                        type(item.get("name")) is not str:
                    raise _R23_TABLE.ProcessTableError(
                        "R23 observed generation row is malformed")
                identity = _R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns")))
                _R23_TABLE.validate_pid(item["ppid"], allow_zero=True)
                if identity[0] in observed:
                    previous_row = observed[identity[0]]
                    raise _R23_TABLE.ProcessTableError(
                        "R23 observed growth PID occurs in multiple records or generations: "
                        f"{previous_row['create_time_100ns']} and {identity[1]}")
                row = {"pid": identity[0], "create_time_100ns": identity[1],
                       "ppid": item["ppid"], "name": item["name"]}
                observed[identity[0]] = row
                record_observed.append(identity)
                if identity not in historical:
                    errors.append(_monitor_error(
                        "r23_membership_growth_final_audit",
                        RuntimeError("observed generation was not retained in historical tracked inventory"),
                        identity[0]))
                current = final_table.by_pid.get(identity[0])
                if current is not None:
                    observed_id = _r23_raw_identity(current)
                    if observed_id != identity:
                        errors.append(_monitor_error(
                            "r23_membership_growth_final_audit",
                            RuntimeError("observed growth PID was reused before final audit"),
                            identity[0]))
                    else:
                        errors.append(_monitor_error(
                            "r23_membership_growth_final_audit",
                            RuntimeError("observed growth generation remains at final audit"),
                            identity[0]))
            except Exception as error:
                errors.append(_monitor_error(
                    "r23_membership_growth_final_audit", error,
                    item.get("pid") if isinstance(item, dict) and
                    type(item.get("pid")) is int else None))

        try:
            root_item = record.get("root_identity")
            if not isinstance(root_item, dict):
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership-growth record root is malformed")
            root_in_record = _R23_TABLE.validate_identity((
                root_item.get("pid"), root_item.get("create_time_100ns")))
            previous_rows = record.get("previously_tracked_identities")
            if type(previous_rows) is not list:
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership-growth tracked history is not a list")
            previous = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in previous_rows if isinstance(item, dict)]
            if len(previous) != len(previous_rows) or len(set(previous)) != len(previous) or \
                    root_in_record != root or root_in_record not in set(previous) or \
                    not set(previous).issubset(historical):
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership-growth record root/history differs from final phase history")
            discarded = record.get("discarded_attempt")
            discarded_monitor = (discarded.get("exact_monitor_receipt")
                                 if isinstance(discarded, dict) else None)
            errors_in_monitor = (discarded_monitor.get("errors")
                                 if isinstance(discarded_monitor, dict) else None)
            expected_sample_failure = (
                isinstance(discarded_monitor, dict) and
                discarded_monitor.get("complete") is False and
                type(errors_in_monitor) is list and len(errors_in_monitor) == 1 and
                isinstance(errors_in_monitor[0], dict) and
                errors_in_monitor[0].get("message") ==
                    "process tree membership/generation changed during sample" and
                type(discarded_monitor.get("partial_rss_bytes")) is int and
                discarded_monitor.get("partial_rss_bytes") >= 0 and
                discarded_monitor.get("partial_rss_bytes") ==
                    record.get("partial_rss_bytes_not_credited") and
                discarded.get("measured_identities_not_credited") ==
                    discarded_monitor.get("measured_identities", []))
            if not isinstance(discarded, dict) or not expected_sample_failure or \
                    discarded.get("sample_complete") is not False or \
                    discarded.get("sample_index") != record.get("sample_index") or \
                    discarded.get("attempt_index") != record.get("attempt_index") or \
                    discarded.get("observed_partial_rss_bytes_not_credited") != \
                        record.get("partial_rss_bytes_not_credited") or \
                    discarded.get("credited_rss_bytes") != 0 or \
                    discarded.get("credited_cpu_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    discarded.get("exit_code_credit_issued") is not False or \
                    discarded.get("exact_handle_exit_receipt_created") is not False or \
                    record.get("rss_credit_bytes") != 0 or \
                    record.get("cpu_credit_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    record.get("exit_code_credit_issued") is not False or \
                    record.get("exact_handle_exit_receipt_created") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "R23 discarded membership-growth attempt has credit or malformed evidence")

            accepted_bundle = record.get("previous_accepted_source")
            accepted = (_r23_snapshot_from_bundle(accepted_bundle)
                        if accepted_bundle is not None else None)
            outer = _r23_snapshot_from_bundle(record.get("outer_reconcile_source"))
            before = _r23_snapshot_from_bundle(record.get("failed_attempt_before_source"))
            after = _r23_snapshot_from_bundle(record.get("failed_attempt_after_source"))
            history_binding = record.get("snapshot_history_binding")
            if not isinstance(history_binding, dict) or \
                history_binding.get("schema") != \
                        "vnext-t2-r23-membership-growth-history-binding-r2":
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership growth lacks its phase-history binding")
            accepted_reference = history_binding.get("previous_accepted_source")
            outer_reference = history_binding.get("outer_reconcile_source")
            before_reference = history_binding.get("failed_attempt_before_source")
            after_reference = history_binding.get("failed_attempt_after_source")
            if accepted is None:
                if accepted_reference is not None:
                    raise _R23_TABLE.ProcessTableError(
                        "first-sample growth unexpectedly names an accepted-source history row")
            else:
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    accepted_reference, accepted,
                    sample_index=record.get("previous_accepted_sample_index"),
                    source_role="sample_source_before")
            _r23_verify_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                outer_reference, outer,
                sample_index=record.get("sample_index"), attempt_index=0,
                source_role="outer_reconcile")
            _r23_verify_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                before_reference, before,
                sample_index=record.get("sample_index"),
                attempt_index=record.get("attempt_index"),
                source_role="sample_source_before")
            _r23_verify_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                after_reference, after,
                sample_index=record.get("sample_index"),
                attempt_index=record.get("attempt_index"),
                source_role="sample_source_after")
            before_sequence = before_reference.get("sequence")
            expected_prefix = _r23_snapshot_history_prefix_receipt(
                phase_snapshot_history, phase_snapshot_witnesses,
                before_sequence)
            if history_binding.get("pre_growth_absence_prefix") != expected_prefix:
                raise _R23_TABLE.ProcessTableError(
                    "R23 growth absence prefix does not reproduce the complete prior history")
            regenerated = _r23_confirm_membership_growth(
                accepted, outer, before, after, root, previous,
                previous_accepted_sample_index=record.get(
                    "previous_accepted_sample_index"),
                sample_index=record.get("sample_index"),
                attempt_index=record.get("attempt_index"),
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses,
                previous_accepted_source_history_sequence=(
                    accepted_reference.get("sequence")
                    if isinstance(accepted_reference, dict) else None),
                outer_reconcile_history_sequence=outer_reference.get("sequence"),
                failed_attempt_before_history_sequence=before_sequence,
                failed_attempt_after_history_sequence=after_reference.get("sequence"),
                deadline_monotonic=None,
                partial_rss_bytes=record.get("partial_rss_bytes_not_credited"),
                exact_monitor_receipt=discarded.get("exact_monitor_receipt"))
            if regenerated.get("growth_verified") is not True or \
                    regenerated.get("observed_generations") != rows or \
                    regenerated.get("before_closure") != record.get("before_closure") or \
                    regenerated.get("after_closure") != record.get("after_closure") or \
                    regenerated.get("snapshot_history_binding") != history_binding or \
                    record.get("growth_verified") is not True:
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership-growth raw source proof does not reproduce its receipt")
            if record.get("complete") is not True or \
                    record.get("retry_started") is not True or \
                    record.get("full_sample_completed_after_retry") is not True or \
                    record.get("full_sample_attempt_index") != \
                        record.get("attempt_index", 0) + 1:
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership growth lacks a completed bounded full-sample retry")
            fresh = record.get("fresh_final_binding")
            if not isinstance(fresh, dict) or \
                    fresh.get("schema") != \
                        "vnext-t2-r23-membership-growth-fresh-binding-r2" or \
                    fresh.get("complete") is not True:
                raise _R23_TABLE.ProcessTableError(
                    "R23 membership growth lacks a complete fresh final binding")
            fresh_before = _r23_snapshot_from_bundle(fresh.get("source_before"))
            fresh_after = _r23_snapshot_from_bundle(fresh.get("source_after"))
            retry_history_binding = fresh.get("snapshot_history_binding")
            if not isinstance(retry_history_binding, dict) or \
                    retry_history_binding.get("schema") != \
                        "vnext-t2-r23-membership-growth-retry-history-binding-r2":
                raise _R23_TABLE.ProcessTableError(
                    "R23 fresh retry lacks its phase-history binding")
            regenerated_binding = _r23_membership_growth_retry_binding(
                record, fresh_before, fresh_after,
                fresh.get("exact_monitor_receipt"),
                fresh.get("handle_identity_receipts"),
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses,
                retry_before_history_sequence=retry_history_binding.get(
                    "retry_source_before", {}).get("sequence"),
                retry_after_history_sequence=retry_history_binding.get(
                    "retry_source_after", {}).get("sequence"))
            if regenerated_binding != fresh or \
                    fresh.get("attempt_index") != record.get("full_sample_attempt_index"):
                raise _R23_TABLE.ProcessTableError(
                    "R23 retry binding does not reproduce the fresh source/resource/handle evidence")
        except Exception as error:
            errors.append(_monitor_error(
                "r23_membership_growth_final_audit", error,
                record.get("root_identity", {}).get("pid")
                if isinstance(record.get("root_identity"), dict) else None))

    residual = []
    observed_pids = set(observed)
    for row in _r20_descendants_from_pid_set(final_table, observed_pids):
        residual.append({"pid": row.identity.pid,
                         "create_time_100ns": row.identity.create_time_100ns,
                         "ppid": row.ppid, "name": row.name})
    if residual:
        errors.append(_monitor_error(
            "r23_membership_growth_final_audit",
            RuntimeError("descendant remains under an observed growth generation")))
    return {
        "schema": "vnext-t2-r23-membership-growth-final-audit-r1",
        "complete": not errors,
        "record_count": len(records),
        "observed_generation_count": len(observed),
        "observed_generations": [observed[pid] for pid in sorted(observed)],
        "residual_observed_generations": residual,
        "source_witness_ledger": witness_ledger,
        "errors": errors,
    }


def _r22_confirm_pre_tree_tracked_exit(
        previous_accepted_source_snapshot: Any,
        outer_reconcile_snapshot: Any,
        failed_attempt_source_snapshot: Any,
        root_identity: Any,
        previously_tracked: list[tuple[int, int]],
        handle_by_identity: dict[tuple[int, int], Any], *,
        previous_accepted_sample_index: int,
        sample_index: int,
        attempt_index: int,
        deadline_monotonic: float,
        partial_rss_bytes: Any = 0,
        snapshot_provider: Any | None = None) -> dict[str, Any]:
    """Reconcile a tracked subtree missing before the sampler reaches handle binds.

    The previous accepted sample and the outer reconciliation must independently
    retain the exact same root-closed subtree. The failed in-sample SPI table then
    proves its absence before any metrics are read; the R21 exact-handle and
    three-absence proof supplies natural-exit evidence and permits only a fresh
    whole-sample retry.
    """
    record: dict[str, Any] = {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-r1",
        "complete": False,
        "status": "monitor_incomplete",
        "failure_stage": "r22_pre_tree_missing_tracked",
        "logical_sample_index": sample_index,
        "whole_sample_attempt_index": attempt_index,
        "previous_accepted_sample_index": previous_accepted_sample_index,
        "root_identity": None,
        "previously_tracked_identities": [],
        "target_identity": None,
        "retired_tracked_identities": [],
        "previous_accepted_source": None,
        "outer_reconcile_source": None,
        "failed_attempt_source": None,
        "r21_exact_exit_proof": None,
        "exact_exit_receipts": [],
        "absence_snapshots": [],
        "absence_checks": [],
        "absence_snapshot_count": 0,
        "partial_rss_bytes_not_credited": 0,
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "full_sample_completed_after_retry": False,
        "retry_started": False,
        "errors": [],
    }
    try:
        root = _R23_TABLE.validate_identity(root_identity)
        previous = tuple(_R23_TABLE.validate_identity(item)
                         for item in previously_tracked)
        previous_set = set(previous)
        if len(previous) != len(previous_set) or root not in previous_set:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree previous identities are duplicated or omit the root")
        if type(previous_accepted_sample_index) is not int or \
                previous_accepted_sample_index <= 0 or \
                type(sample_index) is not int or sample_index <= previous_accepted_sample_index or \
                type(attempt_index) is not int or attempt_index <= 0:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree sample indices are invalid or non-monotonic")
        if type(partial_rss_bytes) is not int or partial_rss_bytes < 0:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree discarded RSS is not a nonnegative integer")
        record["root_identity"] = {
            "pid": root[0], "create_time_100ns": root[1]}
        record["previously_tracked_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in previous]
        record["partial_rss_bytes_not_credited"] = partial_rss_bytes

        accepted = _R23_TABLE.validate_snapshot(previous_accepted_source_snapshot)
        outer = _R23_TABLE.validate_snapshot(outer_reconcile_snapshot)
        failed = _R23_TABLE.validate_snapshot(failed_attempt_source_snapshot)
        record["previous_accepted_source"] = _r22_snapshot_bundle(accepted)
        record["outer_reconcile_source"] = _r22_snapshot_bundle(outer)
        record["failed_attempt_source"] = _r22_snapshot_bundle(failed)

        accepted_closure = _r22_tracked_closure(accepted, root, list(previous))
        outer_closure = _r22_tracked_closure(outer, root, list(previous))
        if accepted_closure != outer_closure:
            raise _R23_TABLE.ProcessTableError(
                "R22 prior accepted and outer reconciliation tracked rows disagree")

        missing: set[tuple[int, int]] = set()
        for identity in previous:
            current = failed.by_pid.get(identity[0])
            if current is None:
                if identity != root:
                    missing.add(identity)
            elif _r23_raw_identity(current) != identity:
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed sample source contains a reused tracked PID")
        if not missing:
            raise _R23_TABLE.ProcessTableError(
                "R22 failed sample source has no missing previously tracked generation")

        accepted_rows = accepted.by_pid
        topmost_missing = []
        for identity in sorted(missing):
            row = accepted_rows.get(identity[0])
            if row is None or _r23_raw_identity(row) != identity:
                raise _R23_TABLE.ProcessTableError(
                    "R22 missing target is absent from the prior accepted source")
            parent = accepted_rows.get(row.ppid)
            parent_identity = _r23_raw_identity(parent) if parent is not None else None
            if parent_identity not in missing:
                topmost_missing.append(identity)
        if len(topmost_missing) != 1:
            raise _R23_TABLE.ProcessTableError(
                "R22 pre-tree gap is not one exact previously tracked subtree")
        target = topmost_missing[0]
        record["target_identity"] = {
            "pid": target[0], "create_time_100ns": target[1]}
        subtree_rows = _R23_TABLE.descendant_identities(accepted, target)
        retired = {(item.pid, item.create_time_100ns) for item in subtree_rows}
        if not retired or not retired.issubset(previous_set) or root in retired or \
                retired != missing:
            raise _R23_TABLE.ProcessTableError(
                "R22 missing identities are not exactly one complete historical tracked subtree")
        retired_pids = {pid for pid, _ in retired}
        outside = previous_set.difference(retired)

        failed_root = failed.by_pid.get(root[0])
        if failed_root is None or _r23_raw_identity(failed_root) != root:
            raise _R23_TABLE.ProcessTableError(
                "R22 failed first sample lost or reused the phase root")
        for identity in sorted(outside):
            current = failed.by_pid.get(identity[0])
            if current is None or _r23_raw_identity(current) != identity:
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed first sample lost or reused another tracked generation")
        for pid in retired_pids:
            if pid in failed.by_pid:
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed first sample contains a retired subtree PID or reuse")
        if _r20_descendants_from_pid_set(failed, retired_pids):
            raise _R23_TABLE.ProcessTableError(
                "R22 failed first sample has an orphan beneath the absent subtree")
        failed_closure = _R23_TABLE.descendant_identities(
            failed, root, previously_tracked=sorted(outside))
        failed_ids = {(item.pid, item.create_time_100ns) for item in failed_closure}
        if failed_ids != outside:
            raise _R23_TABLE.ProcessTableError(
                "R22 failed first sample has an untracked or orphan descendant")

        proof = _r21_confirm_tracked_sample_exit(
            accepted, target, root, list(previous), handle_by_identity,
            sample_index=sample_index, attempt_index=attempt_index,
            deadline_monotonic=deadline_monotonic,
            snapshot_provider=snapshot_provider)
        record["r21_exact_exit_proof"] = proof
        record["complete"] = proof.get("complete") is True
        record["status"] = ("pre_tree_tracked_exit_confirmed" if record["complete"]
                             else "pre_tree_tracked_exit_unconfirmed")
        record["retired_tracked_identities"] = copy.deepcopy(
            proof.get("retired_tracked_identities", []))
        record["exact_exit_receipts"] = copy.deepcopy(
            proof.get("exact_exit_receipts", []))
        record["absence_snapshots"] = copy.deepcopy(
            proof.get("absence_snapshots", []))
        record["absence_checks"] = copy.deepcopy(
            proof.get("absence_checks", []))
        record["absence_snapshot_count"] = proof.get(
            "absence_snapshot_count", 0)
        if proof.get("complete") is not True:
            record["errors"].extend(copy.deepcopy(proof.get("errors", [])))
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r22_pre_tree_tracked_exit_confirmation", error,
            record.get("target_identity", {}).get("pid")
            if isinstance(record.get("target_identity"), dict) else None))
    return record


def _r22_audit_pre_tree_tracked_exit_races(
        snapshot: Any, records: list[dict[str, Any]],
        expected_root_identity: Any,
        historical_tracked_identities: list[tuple[int, int]]) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    retired: dict[tuple[int, int], dict[str, Any]] = {}
    if type(records) is not list:
        return {"schema": "vnext-t2-r22-pre-tree-tracked-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "retired_tracked_identities": [],
                "residual_retired_generations": [],
                "errors": [_monitor_error(
                    "r22_pre_tree_tracked_exit_final_audit",
                    RuntimeError("R22 pre-tree records are not a list"))]}
    try:
        final_table = _R23_TABLE.validate_snapshot(snapshot)
        root = _R23_TABLE.validate_identity(expected_root_identity)
        historical_values = [_R23_TABLE.validate_identity(item)
                             for item in historical_tracked_identities]
        historical = set(historical_values)
        if len(historical) != len(historical_values) or root not in historical:
            raise _R23_TABLE.ProcessTableError(
                "R22 final audit root is missing or duplicated in tracked history")
    except Exception as error:
        return {"schema": "vnext-t2-r22-pre-tree-tracked-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "retired_tracked_identities": [],
                "residual_retired_generations": [],
                "errors": [_monitor_error(
                    "r22_pre_tree_tracked_exit_final_audit", error)]}

    for index, record in enumerate(records):
        try:
            if not isinstance(record, dict) or \
                    record.get("schema") != "vnext-t2-r22-pre-tree-tracked-exit-r1" or \
                    record.get("complete") is not True or \
                    record.get("failure_stage") != "r22_pre_tree_missing_tracked" or \
                    record.get("retry_started") is not True or \
                    record.get("full_sample_completed_after_retry") is not True or \
                    type(record.get("logical_sample_index")) is not int or \
                    type(record.get("whole_sample_attempt_index")) is not int or \
                    type(record.get("full_sample_attempt_index")) is not int or \
                    record.get("full_sample_attempt_index") <= \
                        record.get("whole_sample_attempt_index") or \
                    record.get("previous_accepted_sample_index", 0) >= \
                        record.get("logical_sample_index", 0):
                raise _R23_TABLE.ProcessTableError(
                    "R22 pre-tree proof lacks a complete later whole-sample retry")
            record_root = _R23_TABLE.validate_identity((
                record.get("root_identity", {}).get("pid"),
                record.get("root_identity", {}).get("create_time_100ns")))
            target = _R23_TABLE.validate_identity((
                record.get("target_identity", {}).get("pid"),
                record.get("target_identity", {}).get("create_time_100ns")))
            previous_values = record.get("previously_tracked_identities")
            if record_root != root or type(previous_values) is not list or \
                    any(not isinstance(item, dict) for item in previous_values):
                raise _R23_TABLE.ProcessTableError(
                    "R22 pre-tree phase root or history inventory is malformed")
            previous_ordered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in previous_values]
            previous = set(previous_ordered)
            if len(previous) != len(previous_ordered) or root not in previous or \
                    not previous.issubset(historical):
                raise _R23_TABLE.ProcessTableError(
                    "R22 pre-tree history is duplicated or outside the final phase history")
            accepted = _r22_snapshot_from_bundle(
                record.get("previous_accepted_source"))
            outer = _r22_snapshot_from_bundle(
                record.get("outer_reconcile_source"))
            failed = _r22_snapshot_from_bundle(
                record.get("failed_attempt_source"))
            accepted_closure = _r22_tracked_closure(accepted, root, previous_ordered)
            outer_closure = _r22_tracked_closure(outer, root, previous_ordered)
            if accepted_closure != outer_closure:
                raise _R23_TABLE.ProcessTableError(
                    "R22 accepted and outer source rows differ at final audit")
            proof = record.get("r21_exact_exit_proof")
            if not isinstance(proof, dict) or \
                    proof.get("schema") != "vnext-t2-r21-tracked-sample-exit-r1" or \
                    proof.get("source_snapshot") != record[
                        "previous_accepted_source"]["snapshot"] or \
                    proof.get("root_identity") != record.get("root_identity") or \
                    proof.get("previously_tracked_identities") != previous_values or \
                    proof.get("target_identity") != record.get("target_identity") or \
                    proof.get("retired_tracked_identities") != \
                        record.get("retired_tracked_identities") or \
                    proof.get("exact_exit_receipts") != record.get("exact_exit_receipts") or \
                    proof.get("absence_snapshots") != record.get("absence_snapshots") or \
                    proof.get("absence_checks") != record.get("absence_checks") or \
                    proof.get("absence_snapshot_count") != 3:
                raise _R23_TABLE.ProcessTableError(
                    "R22 pre-tree wrapper differs from its exact R21 handle/absence proof")
            retired_values = record.get("retired_tracked_identities")
            if type(retired_values) is not list or any(
                    not isinstance(item, dict) for item in retired_values):
                raise _R23_TABLE.ProcessTableError(
                    "R22 retired subtree inventory is malformed")
            retired_ordered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in retired_values]
            retired_ids = set(retired_ordered)
            if len(retired_ids) != len(retired_ordered) or \
                    target not in retired_ids or root in retired_ids or \
                    not retired_ids.issubset(previous):
                raise _R23_TABLE.ProcessTableError(
                    "R22 retired identities are not an exact tracked non-root subtree")
            prior_rows = accepted.by_pid
            subtree = {(item.pid, item.create_time_100ns)
                       for item in _R23_TABLE.descendant_identities(accepted, target)}
            if subtree != retired_ids:
                raise _R23_TABLE.ProcessTableError(
                    "R22 retired inventory differs from prior accepted source subtree")
            retired_pids = {pid for pid, _ in retired_ids}
            outside = previous.difference(retired_ids)
            failed_root = failed.by_pid.get(root[0])
            if failed_root is None or _r23_raw_identity(failed_root) != root:
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed-source root is missing or reused")
            for identity in sorted(outside):
                current = failed.by_pid.get(identity[0])
                if current is None or _r23_raw_identity(current) != identity:
                    raise _R23_TABLE.ProcessTableError(
                        "R22 failed source lost or reused another tracked identity")
            if any(pid in failed.by_pid for pid in retired_pids) or \
                    _r20_descendants_from_pid_set(failed, retired_pids):
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed source contains a retired PID/reuse or orphan descendant")
            failed_closure = _R23_TABLE.descendant_identities(
                failed, root, previously_tracked=sorted(outside))
            if {(item.pid, item.create_time_100ns) for item in failed_closure} != outside:
                raise _R23_TABLE.ProcessTableError(
                    "R22 failed source contains an untracked root descendant")
            if type(record.get("partial_rss_bytes_not_credited")) is not int or \
                    record.get("partial_rss_bytes_not_credited", -1) < 0 or \
                    record.get("rss_credit_bytes") != 0 or \
                    record.get("cpu_credit_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    record.get("exit_code_credit_issued") is not False or \
                    proof.get("rss_credit_bytes") != 0 or \
                    proof.get("cpu_credit_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    proof.get("exit_code_credit_issued") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "R22 pre-tree discarded sample received resource or exit credit")
            if set(retired) & retired_ids:
                raise _R23_TABLE.ProcessTableError(
                    "R22 final audit repeats a retired tracked generation")
            inner = _r21_audit_tracked_sample_exit_races(
                final_table, [proof], root, historical_values)
            if inner.get("complete") is not True:
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 exact-handle/three-absence audit failed")
            for identity in retired_ids:
                retired[identity] = {"pid": identity[0],
                                     "create_time_100ns": identity[1]}
        except Exception as error:
            errors.append(_monitor_error(
                "r22_pre_tree_tracked_exit_final_audit", error,
                record.get("target_identity", {}).get("pid")
                if isinstance(record, dict) and
                isinstance(record.get("target_identity"), dict) else None))
    residual_orphans = _r20_descendants_from_pid_set(
        final_table, {identity[0] for identity in retired}) if retired else []
    residual = [{"pid": row.identity.pid,
                 "create_time_100ns": row.identity.create_time_100ns,
                 "ppid": row.ppid, "name": row.name}
                for row in residual_orphans]
    if residual:
        errors.append(_monitor_error(
            "r22_pre_tree_tracked_exit_final_audit",
            RuntimeError("descendant remains under a R22 retired tracked PID")))
    for identity in retired:
        current = final_table.by_pid.get(identity[0])
        if current is not None:
            errors.append(_monitor_error(
                "r22_pre_tree_tracked_exit_final_audit",
                RuntimeError("R22 retired PID remains or was reused at final audit"),
                identity[0]))
    return {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-final-audit-r1",
        "complete": not errors,
        "record_count": len(records),
        "retired_tracked_identities": [retired[key] for key in sorted(retired)],
        "residual_retired_generations": residual,
        "errors": errors,
    }


def _r20_valid_snapshot_receipt(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) != {
            "schema", "complete", "row_count", "host_identity",
            "system_information_class", "buffer_bytes", "query_attempts",
            "raw_identity_digest_sha256", "identity_authority"}:
        return False
    digest = value.get("raw_identity_digest_sha256")
    return value.get("schema") == "vnext-t2-r23-native-snapshot-receipt-r1" and \
        value.get("complete") is True and \
        type(value.get("row_count")) is int and value["row_count"] >= 2 and \
        type(value.get("host_identity")) is list and \
        value["host_identity"] == list(_R23_TABLE.WINDOWS_BUILD_PIN) and \
        type(value.get("system_information_class")) is int and \
        value["system_information_class"] == _R23_TABLE.SYSTEM_INFORMATION_CLASS and \
        type(value.get("buffer_bytes")) is int and \
        _R23_TABLE.SPI_FIXED_HEADER_BYTES <= value["buffer_bytes"] <= \
            _R23_TABLE.MAX_BUFFER_BYTES and \
        type(value.get("query_attempts")) is int and \
        1 <= value["query_attempts"] <= _R23_TABLE.MAX_QUERY_ATTEMPTS and \
        type(digest) is str and len(digest) == 64 and \
        all(character in "0123456789abcdef" for character in digest) and \
        value.get("identity_authority") == \
            "NtQuerySystemInformation_class5_raw_FILETIME_100ns"


def _r20_unbound_observed_rows(
        records: list[dict[str, Any]]) -> tuple[dict[tuple[int, int], dict[str, Any]],
                                               list[dict[str, Any]]]:
    """Collect every syntactically valid observed generation, even from failed records."""
    rows: dict[tuple[int, int], dict[str, Any]] = {}
    errors: list[dict[str, Any]] = []
    if type(records) is not list:
        return rows, [_monitor_error(
            "r20_unbound_observed_generation_inventory",
            RuntimeError("unbound observation records are not a list"))]
    for record_index, record in enumerate(records):
        if not isinstance(record, dict):
            errors.append(_monitor_error(
                "r20_unbound_observed_generation_inventory",
                RuntimeError(f"unbound observation record {record_index} is not an object")))
            continue
        generations = record.get("observed_generations")
        if type(generations) is not list or not generations:
            errors.append(_monitor_error(
                "r20_unbound_observed_generation_inventory",
                RuntimeError(f"unbound observation record {record_index} has no generation rows")))
            continue
        for row_index, item in enumerate(generations):
            try:
                if not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns", "ppid", "name"} or \
                        type(item.get("name")) is not str:
                    raise _R23_TABLE.ProcessTableError(
                        "unbound observed generation has invalid row shape")
                identity = _R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns")))
                _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
                row = {"pid": identity[0], "create_time_100ns": identity[1],
                       "ppid": item["ppid"], "name": item["name"],
                       "record_index": record_index}
                previous = rows.get(identity)
                if previous is not None and (previous["ppid"], previous["name"]) != \
                        (row["ppid"], row["name"]):
                    raise _R23_TABLE.ProcessTableError(
                        "one observed PID+FILETIME has conflicting source rows")
                if previous is None:
                    rows[identity] = row
            except Exception as error:
                errors.append(_monitor_error(
                    "r20_unbound_observed_generation_inventory", error,
                    item.get("pid") if isinstance(item, dict) and
                    type(item.get("pid")) is int else None))
    return rows, errors


def _r20_unbound_cleanup_plan(
        snapshot: Any, records: list[dict[str, Any]],
        protected_identities: list[tuple[int, int]] | set[tuple[int, int]]
        ) -> dict[str, Any]:
    """Plan exact-generation cleanup for every live unbound observation and its provable children."""
    errors: list[dict[str, Any]] = []
    unresolved: list[dict[str, Any]] = []
    targets: dict[tuple[int, int], dict[str, Any]] = {}
    already_absent: list[dict[str, int]] = []
    try:
        table = _R23_TABLE.validate_snapshot(snapshot)
    except Exception as error:
        return {"schema": "vnext-t2-r20-unbound-cleanup-plan-r1",
                "complete": False, "observed_generations": [], "targets": [],
                "already_absent": [], "unresolved": [],
                "errors": [_monitor_error(
                    "r20_unbound_cleanup_inventory", error)]}
    observed, observed_errors = _r20_unbound_observed_rows(records)
    errors.extend(observed_errors)
    protected: set[tuple[int, int]] = set()
    try:
        protected = {_R23_TABLE.validate_identity(item) for item in protected_identities}
    except Exception as error:
        errors.append(_monitor_error("r20_unbound_cleanup_protected_identity", error))
        return {
            "schema": "vnext-t2-r20-unbound-cleanup-plan-r1",
            "complete": False,
            "identity_authority": "raw_PID_FILETIME_100ns_SPI_and_original_process_handle",
            "observed_generations": [
                {"pid": identity[0], "create_time_100ns": identity[1],
                 "ppid": row["ppid"], "name": row["name"]}
                for identity, row in sorted(observed.items())],
            "targets": [], "already_absent": [],
            "unresolved": [{"pid": identity[0],
                             "expected_create_time_100ns": identity[1],
                             "reason": "protected_identity_inventory_invalid"}
                            for identity in sorted(observed)],
            "errors": errors,
        }

    observed_pids = {identity[0] for identity in observed}
    for identity, source_row in sorted(observed.items()):
        current = table.by_pid.get(identity[0])
        if identity in protected:
            unresolved.append({"pid": identity[0], "expected_create_time_100ns": identity[1],
                               "observed_create_time_100ns": (
                                   current.identity.create_time_100ns if current else None),
                               "reason": "protected_root_or_tracked_generation"})
            continue
        if current is None:
            already_absent.append({"pid": identity[0], "create_time_100ns": identity[1]})
            continue
        if _r23_raw_identity(current) != identity:
            unresolved.append({"pid": identity[0], "expected_create_time_100ns": identity[1],
                               "observed_create_time_100ns":
                                   current.identity.create_time_100ns,
                               "reason": "observed_pid_generation_reused"})
            continue
        targets[identity] = {"pid": identity[0], "create_time_100ns": identity[1],
                             "ppid": current.ppid, "name": current.name,
                             "provenance": "observed_generation"}

    # Extend only from rows whose exact observed parent generation is still in
    # this complete table. A vanished or reused PPID cannot anchor a new row.
    frontier: dict[int, int] = {
        pid: ticks for pid, ticks in targets
    }
    seen: set[tuple[int, int]] = set(targets)
    while frontier:
        next_frontier: dict[int, int] = {}
        for row in table.rows:
            parent_ticks = frontier.get(row.ppid)
            if parent_ticks is None:
                continue
            identity = _r23_raw_identity(row)
            if identity in seen:
                continue
            if identity[1] < parent_ticks:
                unresolved.append({"pid": identity[0],
                                   "observed_create_time_100ns": identity[1],
                                   "ppid": row.ppid,
                                   "expected_parent_create_time_100ns": parent_ticks,
                                   "reason": "live_descendant_predates_exact_parent"})
                continue
            if identity in protected:
                unresolved.append({"pid": identity[0],
                                   "observed_create_time_100ns": identity[1],
                                   "ppid": row.ppid,
                                   "reason": "live_descendant_is_protected"})
                continue
            targets[identity] = {"pid": identity[0],
                                 "create_time_100ns": identity[1],
                                 "ppid": row.ppid, "name": row.name,
                                 "provenance": "live_descendant_of_exact_observed_generation"}
            seen.add(identity)
            next_frontier[identity[0]] = identity[1]
        frontier = next_frontier

    # Any remaining row under an observed PID is an orphan whose exact parent
    # lineage cannot be proven from the current table; keep it NO-GO and never
    # open/signal it by PPID alone.
    for row in _r20_descendants_from_pid_set(table, observed_pids):
        identity = _r23_raw_identity(row)
        if identity in targets:
            continue
        item = {"pid": identity[0], "create_time_100ns": identity[1],
                "ppid": row.ppid, "name": row.name,
                "reason": "orphan_descendant_lacks_exact_live_parent_proof"}
        if item not in unresolved:
            unresolved.append(item)

    return {
        "schema": "vnext-t2-r20-unbound-cleanup-plan-r1",
        "complete": not errors and not unresolved,
        "identity_authority": "raw_PID_FILETIME_100ns_SPI_and_original_process_handle",
        "observed_generations": [
            {"pid": identity[0], "create_time_100ns": identity[1],
             "ppid": row["ppid"], "name": row["name"]}
            for identity, row in sorted(observed.items())],
        "targets": [targets[identity] for identity in sorted(targets)],
        "already_absent": already_absent,
        "unresolved": unresolved,
        "errors": errors,
    }


def _r20_audit_unbound_observations(
        snapshot: Any, records: list[dict[str, Any]]) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    table = _R23_TABLE.validate_snapshot(snapshot)
    if type(records) is not list:
        return {"schema": "vnext-t2-r20-unbound-observation-final-audit-r1",
                "complete": False, "observed_generation_count": 0,
                "residual_observed_generations": [], "orphan_descendants": [],
                "errors": [_monitor_error("r20_unbound_observation_final_audit",
                    RuntimeError("unbound observation records are not a list"))]}
    observed, inventory_errors = _r20_unbound_observed_rows(records)
    errors.extend(inventory_errors)
    for index, record in enumerate(records):
        confirmations = (record.get("confirmation_snapshots")
                        if isinstance(record, dict) else None)
        checks = (record.get("absence_checks")
                  if isinstance(record, dict) else None)
        cpu_credit = (record.get("cpu_credit_seconds")
                      if isinstance(record, dict) else None)
        if not isinstance(record, dict) or \
                record.get("schema") != "vnext-t2-r20-unbound-sample-race-r1" or \
                record.get("complete") is not True or \
                record.get("full_sample_completed_after_retry") is not True or \
                record.get("exact_handle_exit_receipt_created") is not False or \
                record.get("exit_code_credit_issued") is not False or \
                type(record.get("rss_credit_bytes")) is not int or \
                record.get("rss_credit_bytes") != 0 or \
                not isinstance(cpu_credit, dict) or set(cpu_credit) != {"user", "system"} or \
                any(type(cpu_credit[key]) not in (int, float) or
                    isinstance(cpu_credit[key], bool) or
                    not math.isfinite(float(cpu_credit[key])) or
                    float(cpu_credit[key]) != 0.0 for key in ("user", "system")) or \
                type(record.get("confirmation_snapshot_count")) is not int or \
                record.get("confirmation_snapshot_count") != 2 or \
                type(confirmations) is not list or len(confirmations) != 2 or \
                type(checks) is not list or len(checks) != 3 or \
                not _r20_valid_snapshot_receipt(record.get("source_snapshot")) or \
                not _r20_valid_snapshot_receipt(record.get("lookup_snapshot")) or \
                any(not _r20_valid_snapshot_receipt(item) for item in confirmations):
            errors.append(_monitor_error(
                "r20_unbound_observation_final_audit",
                RuntimeError(f"unbound observation record {index} is incomplete or malformed")))
            continue
        generations = record.get("observed_generations")
        if type(generations) is not list or not generations:
            errors.append(_monitor_error(
                "r20_unbound_observation_final_audit",
                RuntimeError(f"unbound observation record {index} has no exact generation closure")))
            continue
        record_pids: set[int] = set()
        generation_rows: dict[int, dict[str, Any]] = {}
        for item in generations:
            try:
                if not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns", "ppid", "name"} or \
                        type(item.get("name")) is not str:
                    raise _R23_TABLE.ProcessTableError(
                        "unbound observed generation has invalid row shape")
                identity = _R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns")))
                _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
                if identity[0] in record_pids:
                    raise _R23_TABLE.ProcessTableError(
                        "unbound observation record has duplicate PID")
                record_pids.add(identity[0])
                generation_rows[identity[0]] = item
            except Exception as error:
                errors.append(_monitor_error(
                    "r20_unbound_observation_final_audit", error))
        try:
            root_id = _R23_TABLE.validate_identity((
                record.get("root_identity", {}).get("pid"),
                record.get("root_identity", {}).get("create_time_100ns")))
            target = _R23_TABLE.validate_identity((
                record.get("target_identity", {}).get("pid"),
                record.get("target_identity", {}).get("create_time_100ns")))
            prior_rows = record.get("previously_tracked_identities")
            if type(prior_rows) is not list:
                raise _R23_TABLE.ProcessTableError(
                    "unbound observation has no exact prior identity list")
            prior_ids = []
            for item in prior_rows:
                prior_ids.append(_R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns"))))
            if target not in {(item["pid"], item["create_time_100ns"])
                              for item in generations}:
                raise _R23_TABLE.ProcessTableError(
                    "unbound observed closure omits its target generation")
            reachable = {target[0]}
            while True:
                new = {pid for pid, item in generation_rows.items()
                       if pid not in reachable and item["ppid"] in reachable and
                       item["create_time_100ns"] >=
                           generation_rows[item["ppid"]]["create_time_100ns"]}
                if not new:
                    break
                reachable.update(new)
            if reachable != record_pids:
                raise _R23_TABLE.ProcessTableError(
                    "unbound observed rows are not the exact target descendant closure")
            expected_pids = sorted(record_pids)
            expected_checks = [
                {"index": check_index, "snapshot": receipt,
                 "root_exact": True,
                 "root_identity": {"pid": root_id[0], "create_time_100ns": root_id[1]},
                 "previously_tracked_exact": True,
                 "previously_tracked_identities": [
                     {"pid": pid, "create_time_100ns": ticks}
                     for pid, ticks in prior_ids],
                 "subtree_pids_absent": expected_pids,
                 "orphan_descendant_count": 0}
                for check_index, receipt in enumerate(
                    [record["lookup_snapshot"], *confirmations], 1)
            ]
            if checks != expected_checks or confirmations != [
                    check["snapshot"] for check in checks[1:]]:
                raise _R23_TABLE.ProcessTableError(
                    "unbound absence checks do not match their exact snapshot receipts")
        except Exception as error:
            errors.append(_monitor_error(
                "r20_unbound_observation_final_audit", error))
    residual: list[dict[str, Any]] = []
    for (pid, ticks), source_row in sorted(observed.items()):
        row = table.by_pid.get(pid)
        if row is not None:
            residual.append({"pid": pid, "expected_create_time_100ns": ticks,
                             "observed_create_time_100ns": row.identity.create_time_100ns,
                             "ppid": row.ppid, "name": row.name,
                             "source_ppid": source_row["ppid"],
                             "source_name": source_row["name"]})
    if residual:
        errors.append(_monitor_error(
            "r20_unbound_observation_final_audit",
            RuntimeError("a previously unbound observed PID remains or was reused")))
    orphan_rows = _r20_descendants_from_pid_set(
        table, {pid for pid, _ in observed})
    orphans = [{"pid": row.identity.pid,
                "create_time_100ns": row.identity.create_time_100ns,
                "ppid": row.ppid, "name": row.name}
               for row in orphan_rows]
    if orphans:
        errors.append(_monitor_error(
            "r20_unbound_observation_final_audit",
            RuntimeError("a descendant remains under a previously unbound generation")))
    return {
        "schema": "vnext-t2-r20-unbound-observation-final-audit-r1",
        "complete": not errors,
        "observed_generation_count": len(observed),
        "observed_unbound_generations": [
            {"pid": identity[0], "create_time_100ns": identity[1]}
            for identity in sorted(observed)],
        "residual_observed_generations": residual,
        "orphan_descendants": orphans,
        "errors": errors,
    }


def _r21_audit_tracked_sample_exit_races(
        snapshot: Any, records: list[dict[str, Any]],
        expected_root_identity: Any,
        historical_tracked_identities: list[tuple[int, int]]) -> dict[str, Any]:
    """Audit R21 source ancestry against the phase root and historical set."""
    errors: list[dict[str, Any]] = []
    try:
        table = _R23_TABLE.validate_snapshot(snapshot)
    except Exception as error:
        return {"schema": "vnext-t2-r21-tracked-sample-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "retired_tracked_identities": [],
                "residual_retired_generations": [],
                "errors": [_monitor_error("r21_tracked_exit_final_audit", error)]}
    if type(records) is not list:
        records = []
        errors.append(_monitor_error(
            "r21_tracked_exit_final_audit",
            RuntimeError("tracked sample-exit records are not a list")))
    try:
        expected_root = _R23_TABLE.validate_identity(expected_root_identity)
        historical_values = [_R23_TABLE.validate_identity(item)
                             for item in historical_tracked_identities]
        historical = set(historical_values)
        if len(historical) != len(historical_values) or expected_root not in historical:
            raise _R23_TABLE.ProcessTableError(
                "phase root is missing from or duplicated in historical tracked identities")
    except Exception as error:
        return {"schema": "vnext-t2-r21-tracked-sample-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "retired_tracked_identities": [],
                "residual_retired_generations": [],
                "errors": [*errors, _monitor_error(
                    "r21_tracked_exit_final_audit", error)]}
    retired: dict[tuple[int, int], dict[str, Any]] = {}
    audited_records = 0
    for index, record in enumerate(records):
        if not isinstance(record, dict) or \
                record.get("schema") != "vnext-t2-r21-tracked-sample-exit-r1":
            errors.append(_monitor_error(
                "r21_tracked_exit_final_audit",
                RuntimeError(f"tracked sample-exit record {index} has an unknown schema")))
            continue
        audited_records += 1
        try:
            if record.get("complete") is not True or \
                    record.get("full_sample_completed_after_retry") is not True or \
                    record.get("retry_started") is not True or \
                    type(record.get("whole_sample_attempt_index")) is not int or \
                    type(record.get("full_sample_attempt_index")) is not int or \
                    record.get("full_sample_attempt_index") <= \
                        record.get("whole_sample_attempt_index"):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit proof lacks a complete fresh whole-sample retry")
            root = _R23_TABLE.validate_identity((
                record.get("root_identity", {}).get("pid"),
                record.get("root_identity", {}).get("create_time_100ns")))
            target = _R23_TABLE.validate_identity((
                record.get("target_identity", {}).get("pid"),
                record.get("target_identity", {}).get("create_time_100ns")))
            previous_values = record.get("previously_tracked_identities")
            observed_rows = record.get("observed_generations")
            retired_values = record.get("retired_tracked_identities")
            exit_receipts = record.get("exact_exit_receipts")
            absence_snapshots = record.get("absence_snapshots")
            absence_checks = record.get("absence_checks")
            if target == root or type(previous_values) is not list or \
                    type(observed_rows) is not list or not observed_rows or \
                    type(retired_values) is not list or type(exit_receipts) is not list or \
                    type(absence_snapshots) is not list or len(absence_snapshots) != 3 or \
                    type(absence_checks) is not list or len(absence_checks) != 3 or \
                    record.get("absence_snapshot_count") != 3 or \
                    not _r20_valid_snapshot_receipt(record.get("source_snapshot")):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit proof has an incomplete inventory")
            if any(not isinstance(item, dict) for item in
                   [*previous_values, *observed_rows, *retired_values]):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit identity rows are malformed")
            previous_ordered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in previous_values]
            observed_ordered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in observed_rows]
            retired_ordered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in retired_values]
            previous = set(previous_ordered)
            observed = set(observed_ordered)
            retired_ids = set(retired_ordered)
            if len(previous) != len(previous_ordered) or \
                    len(observed) != len(observed_ordered) or \
                    len(retired_ids) != len(retired_ordered):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit identity rows contain duplicates")
            for item in observed_rows:
                if set(item) != {"pid", "create_time_100ns", "ppid", "name"} or \
                        type(item.get("name")) is not str:
                    raise _R23_TABLE.ProcessTableError(
                        "tracked sample-exit observed source row has an invalid shape")
                _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
            if target not in previous or target not in observed or \
                    not retired_ids or observed != retired_ids or \
                    not retired_ids.issubset(previous) or root in retired_ids:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit source/retired identity sets disagree")
            if root != expected_root or root not in previous or \
                    not previous.issubset(historical) or \
                    not retired_ids.issubset(historical):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit root or identities differ from the phase history")

            closure_rows = record.get("source_root_closure")
            if type(closure_rows) is not list or not closure_rows or \
                    any(not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns", "ppid", "name"} or
                        type(item.get("name")) is not str for item in closure_rows):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit source root-closure rows are malformed")
            closure_by_pid: dict[int, dict[str, Any]] = {}
            closure_identity_set: set[tuple[int, int]] = set()
            for item in closure_rows:
                identity = _R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns")))
                _R23_TABLE.validate_pid(item.get("ppid"), allow_zero=True)
                if identity[0] in closure_by_pid or identity in closure_identity_set:
                    raise _R23_TABLE.ProcessTableError(
                        "tracked sample-exit source closure duplicates a PID/generation")
                closure_by_pid[identity[0]] = item
                closure_identity_set.add(identity)
            if (expected_root[0], expected_root[1]) not in closure_identity_set or \
                    not previous.issubset(closure_identity_set):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit source closure omits the phase root or a prior identity")
            root_source_row = closure_by_pid.get(expected_root[0])
            if root_source_row is None or _R23_TABLE.validate_identity((
                    root_source_row.get("pid"),
                    root_source_row.get("create_time_100ns"))) != expected_root:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit source root generation does not match the phase root")

            # Independently reconstruct the exact PPID closure and validate
            # FILETIME chronology along every source edge.
            reachable_pids = {expected_root[0]}
            frontier = {expected_root[0]}
            while frontier:
                next_frontier: set[int] = set()
                for item in closure_rows:
                    pid = item["pid"]
                    if pid in reachable_pids or item["ppid"] not in frontier:
                        continue
                    parent = closure_by_pid.get(item["ppid"])
                    if parent is None:
                        raise _R23_TABLE.ProcessTableError(
                            "tracked sample-exit descendant has no exact source parent")
                    if item["create_time_100ns"] < parent["create_time_100ns"]:
                        raise _R23_TABLE.ProcessTableError(
                            "tracked sample-exit source child predates exact parent FILETIME")
                    reachable_pids.add(pid)
                    next_frontier.add(pid)
                frontier = next_frontier
            if reachable_pids != set(closure_by_pid):
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit source rows are not all reachable from the phase root")

            subtree_pids = {target[0]}
            frontier = {target[0]}
            while frontier:
                next_frontier = {item["pid"] for item in closure_rows
                                 if item["ppid"] in frontier and
                                 item["pid"] not in subtree_pids}
                subtree_pids.update(next_frontier)
                frontier = next_frontier
            source_subtree = {
                _R23_TABLE.validate_identity((item["pid"],
                                              item["create_time_100ns"]))
                for item in closure_rows if item["pid"] in subtree_pids}
            if source_subtree != retired_ids:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit retired rows are not the complete target PPID subtree")
            observed_by_identity = {
                _R23_TABLE.validate_identity((item["pid"],
                                              item["create_time_100ns"])): item
                for item in observed_rows}
            expected_observed = {
                identity: closure_by_pid[identity[0]] for identity in source_subtree}
            if observed_by_identity != expected_observed:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit observed rows differ from its exact source closure")
            receipts_by_id: dict[tuple[int, int], dict[str, Any]] = {}
            for receipt in exit_receipts:
                if not isinstance(receipt, dict) or \
                        receipt.get("schema") != \
                            "vnext-t2-r21-tracked-generation-natural-exit-r1" or \
                        receipt.get("complete") is not True or \
                        receipt.get("errors") != [] or \
                        receipt.get("wait_confirmed") is not True or \
                        receipt.get("exit_code_credit_issued") is not False or \
                        type(receipt.get("exit_code")) is not int or \
                        receipt.get("exit_code") == 259:
                    raise _R23_TABLE.ProcessTableError(
                        "tracked sample-exit has an invalid per-generation wait receipt")
                identity = _R23_TABLE.validate_identity((
                    receipt.get("identity", {}).get("pid"),
                    receipt.get("identity", {}).get("create_time_100ns")))
                before = _R23_TABLE.validate_identity((
                    receipt.get("handle_identity_before_wait", {}).get("pid"),
                    receipt.get("handle_identity_before_wait", {}).get(
                        "create_time_100ns")))
                after = _R23_TABLE.validate_identity((
                    receipt.get("handle_identity_after_wait", {}).get("pid"),
                    receipt.get("handle_identity_after_wait", {}).get(
                        "create_time_100ns")))
                if identity != before or identity != after or identity in receipts_by_id:
                    raise _R23_TABLE.ProcessTableError(
                        "tracked sample-exit handle receipts are duplicated or mismatched")
                receipts_by_id[identity] = receipt
            if set(receipts_by_id) != retired_ids:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit lacks an exact receipt for every retired generation")
            expected_outside = [
                {"pid": pid, "create_time_100ns": ticks}
                for pid, ticks in sorted(previous.difference(retired_ids))]
            for check_index, (snapshot_receipt, check) in enumerate(
                    zip(absence_snapshots, absence_checks), start=1):
                if not isinstance(check, dict) or \
                        not _r20_valid_snapshot_receipt(snapshot_receipt) or \
                        check.get("index") != check_index or \
                        check.get("snapshot") != snapshot_receipt or \
                        check.get("root_exact") is not True or \
                        check.get("root_identity") != {
                            "pid": root[0], "create_time_100ns": root[1]} or \
                        check.get("other_previously_tracked_exact") is not True or \
                        check.get("other_previously_tracked_identities") != expected_outside or \
                        check.get("subtree_pids_absent") != sorted(
                            identity[0] for identity in retired_ids) or \
                        check.get("orphan_descendant_count") != 0:
                    raise _R23_TABLE.ProcessTableError(
                        f"tracked sample-exit absence check {check_index} is malformed")
            if record.get("rss_credit_bytes") != 0 or \
                    record.get("cpu_credit_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    record.get("exit_code_credit_issued") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "tracked sample-exit partial attempt received measurement or exit credit")
            for identity in retired_ids:
                current = table.by_pid.get(identity[0])
                if current is not None:
                    raise _R23_TABLE.ProcessTableError(
                        f"retired tracked PID {identity[0]} remains or was reused at final audit")
                retired[identity] = {"pid": identity[0],
                                     "create_time_100ns": identity[1]}
        except Exception as error:
            errors.append(_monitor_error(
                "r21_tracked_exit_final_audit", error,
                record.get("target_identity", {}).get("pid")
                if isinstance(record.get("target_identity"), dict) else None))
    orphan_rows = _r20_descendants_from_pid_set(
        table, {identity[0] for identity in retired}) if retired else []
    residual_orphans = [{"pid": row.identity.pid,
                         "create_time_100ns": row.identity.create_time_100ns,
                         "ppid": row.ppid, "name": row.name}
                        for row in orphan_rows]
    if residual_orphans:
        errors.append(_monitor_error(
            "r21_tracked_exit_final_audit",
            RuntimeError("descendant remains under a retired tracked generation")))
    return {
        "schema": "vnext-t2-r21-tracked-sample-exit-final-audit-r1",
        "complete": not errors,
        "record_count": audited_records,
        "retired_tracked_identities": [retired[key] for key in sorted(retired)],
        "residual_retired_generations": residual_orphans,
        "errors": errors,
    }


def _r23_audit_terminal_root_sample_exits(
        snapshot: Any, records: list[dict[str, Any]], root_identity: Any,
        tracked: list[tuple[int, int]], *, root_exit_confirmed: bool,
        root_exit_code: Any, working_set_limit_bytes: int,
        root_popen_handle: Any,
        retained_handles: dict[tuple[int, int], Any] | None,
        completed_samples: Any,
        terminal_partial_sample: Any,
        other_race_records: Any,
        phase_snapshot_history: list[dict[str, Any]] | None,
        phase_snapshot_witnesses: Any) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    final_table = _R23_TABLE.validate_snapshot(snapshot)
    root = _R23_TABLE.validate_identity(root_identity)
    if type(records) is not list:
        return {"schema": "vnext-t2-r23-terminal-root-sample-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "errors": [_monitor_error(
                    "r23_terminal_root_sample_exit_final_audit",
                    RuntimeError("terminal-root records are not a list"))]}
    if len(records) > 1:
        errors.append(_monitor_error(
            "r23_terminal_root_sample_exit_final_audit",
            RuntimeError("phase has more than one terminal-root sample receipt")))
    if not records:
        return {"schema": "vnext-t2-r23-terminal-root-sample-exit-final-audit-r1",
                "complete": not errors, "record_count": 0,
                "validated_root_identity": {"pid": root[0],
                                             "create_time_100ns": root[1]},
                "errors": errors}
    if type(working_set_limit_bytes) is not int or working_set_limit_bytes <= 0:
        errors.append(_monitor_error(
            "r23_terminal_root_sample_exit_final_audit",
            RuntimeError("terminal-root working-set ceiling is invalid")))
    if root_exit_confirmed is not True or type(root_exit_code) is not int or \
            isinstance(root_exit_code, bool):
        errors.append(_monitor_error(
            "r23_terminal_root_sample_exit_final_audit",
            RuntimeError("terminal-root final Popen/native exit receipt is unavailable"),
            root[0]))
    if phase_snapshot_history is None or \
            not isinstance(phase_snapshot_witnesses, (list, tuple)):
        errors.append(_monitor_error(
            "r23_terminal_root_sample_exit_final_audit",
            RuntimeError("terminal-root final audit lacks its captured history ledger")))

    checked_records: list[dict[str, Any]] = []
    for record_index, record in enumerate(records):
        try:
            if not isinstance(record, dict) or \
                    record.get("schema") != "vnext-t2-r23-terminal-root-sample-exit-r1" or \
                    record.get("complete") is not True or \
                    record.get("status") != \
                        "terminal_root_exit_proven_partial_sample_uncredited" or \
                    record.get("failure_stage") != \
                        "r23_terminal_root_resource_read_exit" or \
                    record.get("errors") != []:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root record is incomplete or has the wrong typed disposition")
            record_root = _R23_TABLE.validate_identity((
                record.get("root_identity", {}).get("pid"),
                record.get("root_identity", {}).get("create_time_100ns")))
            if record_root != root:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root record does not match the phase launch generation")
            sample_index = record.get("logical_sample_index")
            attempt_index = record.get("whole_sample_attempt_index")
            previous_sample_index = record.get("previous_accepted_sample_index")
            if type(sample_index) is not int or sample_index <= 0 or \
                    type(attempt_index) is not int or attempt_index != 1 or \
                    type(previous_sample_index) is not int or previous_sample_index <= 0 or \
                    sample_index != previous_sample_index + 1:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root record lacks a prior complete sample or first-attempt context")
            if type(other_race_records) is not list or any(
                    not isinstance(other, dict) or
                    other.get("logical_sample_index", other.get("sample_index")) ==
                        sample_index
                    for other in other_race_records):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root attempt also contains another sample-race record")
            failure = record.get("resource_failure")
            if not isinstance(failure, dict) or \
                    failure.get("type") != "NoSuchProcess" or \
                    failure.get("pid") != root[0] or \
                    type(failure.get("message")) is not str or not failure.get("message"):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root record lacks the exact root NoSuchProcess resource failure")
            if record.get("sample_complete") is not False or \
                    record.get("retry_started") is not False or \
                    record.get("full_sample_completed_after_retry") is not False or \
                    record.get("exit_code_credit_issued") is not False or \
                    record.get("rss_credit_bytes") != 0 or \
                    record.get("cpu_credit_seconds") != {"user": 0.0, "system": 0.0}:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root partial sample received completion, retry, or numerical credit")
            partial_rss = record.get("partial_rss_bytes_not_credited")
            if type(partial_rss) is not int or partial_rss < 0 or \
                    partial_rss >= working_set_limit_bytes:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root partial RSS is malformed or exceeds the phase ceiling")
            discarded = record.get("discarded_attempt")
            if not isinstance(discarded, dict) or \
                    discarded.get("sample_index") != sample_index or \
                    discarded.get("attempt_index") != 1 or \
                    discarded.get("complete") is not False or \
                    discarded.get("sample_complete") is not False or \
                    discarded.get("observed_partial_rss_bytes_not_credited") != partial_rss or \
                    discarded.get("credited_rss_bytes") != 0 or \
                    discarded.get("credited_cpu_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    discarded.get("exit_code_credit_issued") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root discarded-attempt summary is incomplete or inconsistent")
            discarded_monitor = discarded.get("exact_monitor_receipt")
            discarded_errors = (discarded_monitor.get("errors")
                if isinstance(discarded_monitor, dict) else None)
            if not isinstance(discarded_monitor, dict) or \
                    discarded_monitor.get("complete") is not False or \
                    discarded_monitor.get("sample_index") != sample_index or \
                    discarded_monitor.get("partial_rss_bytes") != partial_rss or \
                    discarded_monitor.get("errors") != record.get(
                        "sample_failure_monitor_errors") or \
                    discarded.get("errors") != discarded_errors or \
                    discarded.get("measured_identities_not_credited") != \
                        discarded_monitor.get("measured_identities") or \
                    type(discarded_errors) is not list or len(discarded_errors) != 1 or \
                    discarded_monitor.get("rss_bytes") is not None or \
                    discarded_monitor.get("numerical_credit") is not False or \
                    discarded_monitor.get("solver_success_claimed") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root discarded monitor receipt differs from its uncredited summary")
            discarded_error = discarded_errors[0]
            if not isinstance(discarded_error, dict) or \
                    discarded_error.get("message") != \
                        "exact generation exited during resource read; discard sample and " \
                        "require typed exact-generation recovery":
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root discarded monitor receipt lacks the exact resource-failure outcome")
            if not isinstance(terminal_partial_sample, dict) or \
                    terminal_partial_sample.get("sample_index") != sample_index or \
                    terminal_partial_sample.get("sample_complete") is not False or \
                    terminal_partial_sample.get("sample_attempt_count") != 1 or \
                    terminal_partial_sample.get("process_tree_working_set_bytes") != 0 or \
                    terminal_partial_sample.get("process_tree_user_cpu_seconds") != 0.0 or \
                    terminal_partial_sample.get("process_tree_system_cpu_seconds") != 0.0 or \
                    terminal_partial_sample.get("processes") != [] or \
                    terminal_partial_sample.get("errors") != discarded_errors or \
                    terminal_partial_sample.get("exact_monitor_receipt") != discarded_monitor or \
                    terminal_partial_sample.get("terminal_root_sample_exit_races") != [record]:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root partial sample top-level fields differ from the discarded receipt")
            if not root_exit_confirmed or root_exit_code is None:
                raise _R23_TABLE.ProcessTableError(
                    "phase did not complete the exact natural root wait")
            if root_popen_handle is None:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root final audit lacks the original Popen handle")
            if type(completed_samples) is not list or \
                    len(completed_samples) != previous_sample_index:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root final audit lacks the exact completed-sample ledger")
            completed_indices = [item.get("sample_index")
                for item in completed_samples if isinstance(item, dict)]
            if completed_indices != list(range(1, previous_sample_index + 1)) or \
                    any(not isinstance(item, dict) or
                        item.get("sample_complete") is not True
                        for item in completed_samples):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root prior accepted sample is not in the complete sample sequence")
            prior_sample = completed_samples[previous_sample_index - 1]
            prior_sample_monitor = prior_sample.get("exact_monitor_receipt")
            prior_sample_attempt_count = prior_sample.get("sample_attempt_count")
            prior_sample_reference = prior_sample.get(
                "completed_source_history_reference")
            if not isinstance(prior_sample_monitor, dict) or \
                    prior_sample_monitor.get("complete") is not True or \
                    type(prior_sample_attempt_count) is not int or \
                    prior_sample_attempt_count not in (1, 2) or \
                    prior_sample_reference != record.get(
                        "previous_accepted_source_history_reference") or \
                    prior_sample.get("completed_source_history_sequence") != \
                        record.get("previous_accepted_source_history_sequence"):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root accepted-source reference is not bound to its completed sample")

            previous_values = record.get("previously_tracked_identities")
            if type(previous_values) is not list or any(
                    not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns"} for item in previous_values):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root previous-active inventory is malformed")
            previous = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in previous_values]
            if len(previous) != len(set(previous)) or root not in set(previous) or \
                    not set(previous).issubset(set(tracked)):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root previous-active identities are duplicated or not phase tracked")
            if prior_sample_monitor.get("sample_index") != previous_sample_index or \
                    prior_sample_monitor.get("root_identity") != {
                        "pid": root[0], "create_time_100ns": root[1]} or \
                    prior_sample_monitor.get("errors") != [] or \
                    prior_sample.get("errors") != [] or \
                    prior_sample.get("root_process_identity", {}).get("pid") != root[0] or \
                    prior_sample.get("root_process_identity", {}).get(
                        "create_time_100ns") != root[1]:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root prior sample receipt is not the exact completed phase root sample")
            prior_discovered_values = prior_sample_monitor.get("discovered_identities")
            if type(prior_discovered_values) is not list:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root prior accepted sample lacks its exact discovered inventory")
            prior_discovered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in prior_discovered_values if isinstance(item, dict)]
            if len(prior_discovered) != len(prior_discovered_values) or \
                    len(prior_discovered) != len(set(prior_discovered)) or \
                    set(prior_discovered) != set(previous):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root active inventory differs from the completed prior sample")

            accepted = _r22_snapshot_from_bundle(
                record.get("previous_accepted_source"))
            outer = _r22_snapshot_from_bundle(record.get("outer_reconcile_source"))
            source = _r22_snapshot_from_bundle(record.get("source_table"))
            if record.get("source_snapshot") != _r23_snapshot_receipt(source):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root source bundle differs from its raw snapshot receipt")
            accepted_rows = _r23_terminal_root_closure_rows(
                accepted, root, previous)
            outer_rows = _r23_terminal_root_closure_rows(outer, root, previous)
            source_rows = _r23_terminal_root_closure_rows(source, root, previous)
            claimed_closure = record.get("source_root_closure")
            if accepted_rows != outer_rows or outer_rows != source_rows or \
                    claimed_closure != source_rows:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root accepted/outer/failed-source closure graphs do not match")
            closure_ids = {(row["pid"], row["create_time_100ns"])
                           for row in source_rows}
            outside = set(previous).difference(closure_ids)
            expected_outside = [{"pid": pid, "create_time_100ns": ticks}
                                for pid, ticks in sorted(outside)]
            if record.get("outside_tracked_identities") != expected_outside:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root outside-active inventory differs from the source closure")

            references = (
                (record.get("previous_accepted_source_history_reference"), accepted,
                 previous_sample_index, None, "sample_source_before"),
                (record.get("outer_reconcile_history_reference"), outer,
                 sample_index, 0, "outer_reconcile"),
                (record.get("source_history_reference"), source,
                 sample_index, 1, "sample_source_before"),
            )
            referenced_sequences: list[int] = []
            for reference, table, expected_sample, expected_attempt, expected_role in references:
                if phase_snapshot_history is None:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root history ledger is unavailable")
                context: dict[str, Any] = {"sample_index": expected_sample,
                                           "source_role": expected_role}
                if expected_attempt is not None:
                    context["attempt_index"] = expected_attempt
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    reference, table, **context)
                referenced_sequences.append(reference["sequence"])
            if not (referenced_sequences[0] < referenced_sequences[1] <
                    referenced_sequences[2]):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root accepted/outer/failed source history references are unordered")
            _r23_verify_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                prior_sample_reference, accepted,
                sample_index=previous_sample_index,
                attempt_index=prior_sample_attempt_count,
                source_role="sample_source_before")

            bound_root = record.get("bound_root_handle_receipt")
            if not isinstance(bound_root, dict) or \
                    bound_root.get("pid") != root[0] or \
                    bound_root.get("create_time_100ns") != root[1] or \
                    bound_root.get("source_snapshot") != _r23_snapshot_receipt(source):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root resource row lacks its original source-bound handle receipt")
            resource_root = record.get("resource_root_handle_proof")
            if not isinstance(resource_root, dict) or \
                    resource_root.get("handle_owner") != "original_popen_handle" or \
                    resource_root.get("identity") != {
                        "pid": root[0], "create_time_100ns": root[1]} or \
                    resource_root.get("handle_identity_before_wait") != {
                        "pid": root[0], "create_time_100ns": root[1]} or \
                    resource_root.get("wait_confirmed") is not True or \
                    resource_root.get("handle_identity_after_wait") != {
                        "pid": root[0], "create_time_100ns": root[1]} or \
                    type(resource_root.get("exit_code")) is not int or \
                    resource_root.get("exit_code") == 259 or \
                    resource_root.get("exit_code_credit_issued") is not False or \
                    resource_root.get("errors") != []:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root resource-time Popen wait/exit proof is incomplete")
            final_root_identity = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(root_popen_handle))
            _R23_TABLE.require_same_identity(
                final_root_identity, root,
                phase="R23 terminal-root final-audit Popen handle")
            final_root_wait = _R23_TABLE.wait_for_process_exit(
                root_popen_handle, 0.001)
            if type(final_root_wait) is not bool or final_root_wait is not True:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root final-audit Popen handle is not signaled")
            final_root_after = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(root_popen_handle))
            _R23_TABLE.require_same_identity(
                final_root_after, root,
                phase="R23 terminal-root final-audit Popen post-wait handle")
            if _R23_TABLE.process_exit_code(root_popen_handle) != root_exit_code:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root final-audit Popen exit code differs from phase exit")

            exit_receipts = record.get("exact_exit_receipts")
            if type(exit_receipts) is not list or len(exit_receipts) != len(source_rows):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root exact exit receipt count differs from source closure")
            expected_identities = [
                (row["pid"], row["create_time_100ns"]) for row in source_rows]
            observed_exit_identities: list[tuple[int, int]] = []
            for exit_receipt in exit_receipts:
                if not isinstance(exit_receipt, dict) or \
                        exit_receipt.get("schema") != \
                            "vnext-t2-r23-terminal-generation-exit-r1" or \
                        exit_receipt.get("complete") is not True or \
                        exit_receipt.get("wait_confirmed") is not True or \
                        exit_receipt.get("exit_code_credit_issued") is not False or \
                        exit_receipt.get("errors") != []:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root per-generation exit receipt is incomplete")
                identity = _R23_TABLE.validate_identity((
                    exit_receipt.get("identity", {}).get("pid"),
                    exit_receipt.get("identity", {}).get("create_time_100ns")))
                observed_exit_identities.append(identity)
                expected_owner = ("original_popen_handle" if identity == root else
                                  "retained_registry_handle")
                if exit_receipt.get("handle_owner") != expected_owner or \
                        exit_receipt.get("handle_identity_before_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]} or \
                        exit_receipt.get("handle_identity_after_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]} or \
                        type(exit_receipt.get("exit_code")) is not int or \
                        exit_receipt.get("exit_code") == 259:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root exit receipt has wrong owner, identity, wait, or exit code")
                handle = (root_popen_handle if identity == root else
                          (retained_handles.get(identity)
                           if isinstance(retained_handles, dict) else None))
                if handle is None:
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root final audit lacks the retained handle for PID {identity[0]}")
                final_before = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    final_before, identity,
                    phase="R23 terminal-root final-audit pre-wait retained handle")
                final_wait = _R23_TABLE.wait_for_process_exit(handle, 0.001)
                if type(final_wait) is not bool or final_wait is not True:
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root final-audit handle is not signaled for PID {identity[0]}")
                final_after = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    final_after, identity,
                    phase="R23 terminal-root final-audit post-wait retained handle")
                if _R23_TABLE.process_exit_code(handle) != exit_receipt.get("exit_code"):
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root final-audit handle exit code differs for PID {identity[0]}")
                if identity == root and exit_receipt.get("exit_code") != root_exit_code:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root exact exit code differs from Popen/native phase exit")
            if observed_exit_identities != expected_identities:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root exit receipts do not exactly cover the source closure")

            absence_bundles = record.get("absence_snapshot_bundles")
            absence_references = record.get("absence_history_references")
            absence_checks = record.get("absence_checks")
            if type(absence_bundles) is not list or len(absence_bundles) != 3 or \
                    type(absence_references) is not list or len(absence_references) != 3 or \
                    type(absence_checks) is not list or len(absence_checks) != 3 or \
                    record.get("absence_snapshot_count") != 3:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root proof lacks exactly three complete absence snapshots")
            absence_sequences: list[int] = []
            closure_pids = {pid for pid, _ in closure_ids}
            for index, (bundle, reference, check) in enumerate(zip(
                    absence_bundles, absence_references, absence_checks), 1):
                table = _r22_snapshot_from_bundle(bundle)
                role = f"terminal_root_exit_absence_{index}"
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    reference, table, sample_index=sample_index,
                    attempt_index=1, source_role=role)
                sequence = reference.get("sequence") if isinstance(reference, dict) else None
                if type(sequence) is not int:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root absence history sequence is malformed")
                absence_sequences.append(sequence)
                if not isinstance(check, dict) or check.get("index") != index or \
                        check.get("history_sequence") != sequence or \
                        check.get("snapshot") != _r23_snapshot_receipt(table) or \
                        check.get("closure_pids_absent") != sorted(closure_pids) or \
                        check.get("outside_tracked_exact") != expected_outside or \
                        check.get("orphan_descendant_count") != 0:
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root absence check {index} differs from its raw table")
                for pid, ticks in closure_ids:
                    if pid in table.by_pid:
                        raise _R23_TABLE.ProcessTableError(
                            f"terminal-root absence table {index} contains a closure PID or reuse")
                for identity in outside:
                    row = table.by_pid.get(identity[0])
                    if row is None or _r23_raw_identity(row) != identity:
                        raise _R23_TABLE.ProcessTableError(
                            f"terminal-root absence table {index} loses outside active identity")
                if _r20_descendants_from_pid_set(table, closure_pids):
                    raise _R23_TABLE.ProcessTableError(
                        f"terminal-root absence table {index} has an orphan under a retired generation")
            if absence_sequences != sorted(set(absence_sequences)) or \
                    absence_sequences[0] <= referenced_sequences[2]:
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root absence source witnesses are not distinct and ordered")

            for pid, ticks in closure_ids:
                if pid in final_table.by_pid:
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root closure PID remains or is reused in final phase inventory")
            if _r20_descendants_from_pid_set(final_table, closure_pids):
                raise _R23_TABLE.ProcessTableError(
                    "final phase inventory has an orphan under a terminal-root generation")
            if not root_exit_confirmed or root_exit_code != resource_root.get("exit_code"):
                raise _R23_TABLE.ProcessTableError(
                    "terminal-root resource and phase Popen exit receipts disagree")
            checked_records.append({
                "sample_index": sample_index,
                "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
                "closure_identity_count": len(source_rows),
                "absence_snapshot_count": 3,
                "partial_rss_bytes_not_credited": partial_rss,
                "retry_started": False,
                "sample_complete": False,
            })
        except Exception as error:
            errors.append(_monitor_error(
                "r23_terminal_root_sample_exit_final_audit", error,
                record.get("root_identity", {}).get("pid")
                if isinstance(record, dict) and
                isinstance(record.get("root_identity"), dict) else None))
    return {
        "schema": "vnext-t2-r23-terminal-root-sample-exit-final-audit-r1",
        "complete": not errors and len(records) <= 1,
        "record_count": len(records),
        "validated_records": checked_records,
        "errors": errors,
    }


def _r23_audit_descendant_terminal_root_sample_exits(
        snapshot: Any, records: list[dict[str, Any]], root_identity: Any,
        tracked: list[tuple[int, int]], *, root_exit_confirmed: bool,
        root_exit_code: Any, working_set_limit_bytes: int,
        root_popen_handle: Any,
        retained_handles: dict[tuple[int, int], Any] | None,
        completed_samples: Any,
        terminal_partial_sample: Any,
        other_race_records: Any,
        phase_snapshot_history: list[dict[str, Any]] | None,
        phase_snapshot_witnesses: Any) -> dict[str, Any]:
    """Recompute a child-triggered terminal-root disposition at final audit."""
    errors: list[dict[str, Any]] = []
    final_table = _R23_TABLE.validate_snapshot(snapshot)
    root = _R23_TABLE.validate_identity(root_identity)
    if type(records) is not list:
        return {"schema": "vnext-t2-r23-descendant-terminal-root-sample-exit-final-audit-r1",
                "complete": False, "record_count": 0,
                "errors": [_monitor_error(
                    "r23_descendant_terminal_final_audit",
                    RuntimeError("descendant-terminal records are not a list"))]}
    if len(records) > 1:
        errors.append(_monitor_error(
            "r23_descendant_terminal_final_audit",
            RuntimeError("phase has more than one descendant-terminal sample disposition")))
    if not records:
        return {"schema": "vnext-t2-r23-descendant-terminal-root-sample-exit-final-audit-r1",
                "complete": not errors, "record_count": 0,
                "validated_root_identity": {"pid": root[0],
                                             "create_time_100ns": root[1]},
                "errors": errors}
    if type(working_set_limit_bytes) is not int or working_set_limit_bytes <= 0:
        errors.append(_monitor_error(
            "r23_descendant_terminal_final_audit",
            RuntimeError("descendant-terminal working-set ceiling is invalid")))
    if root_exit_confirmed is not True or type(root_exit_code) is not int or \
            isinstance(root_exit_code, bool) or root_popen_handle is None:
        errors.append(_monitor_error(
            "r23_descendant_terminal_final_audit",
            RuntimeError("exact final Popen exit proof is unavailable"), root[0]))
    if phase_snapshot_history is None or \
            not isinstance(phase_snapshot_witnesses, (list, tuple)):
        errors.append(_monitor_error(
            "r23_descendant_terminal_final_audit",
            RuntimeError("final audit lacks the sealed phase history and witness ledger")))

    checked: list[dict[str, Any]] = []
    for record in records:
        try:
            if not isinstance(record, dict) or \
                    record.get("schema") != \
                        "vnext-t2-r23-descendant-terminal-root-sample-exit-r1" or \
                    record.get("complete") is not True or \
                    record.get("status") != \
                        "descendant_exit_then_terminal_root_proven_partial_sample_uncredited" or \
                    record.get("failure_stage") != \
                        "r23_descendant_terminal_root_handoff" or \
                    record.get("errors") != []:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal receipt is incomplete or has the wrong typed status")
            if _R23_TABLE.validate_identity((
                    record.get("root_identity", {}).get("pid"),
                    record.get("root_identity", {}).get("create_time_100ns"))) != root:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal receipt names another phase root")
            sample_index = record.get("logical_sample_index")
            attempt_index = record.get("whole_sample_attempt_index")
            previous_sample_index = record.get("previous_accepted_sample_index")
            if type(sample_index) is not int or type(previous_sample_index) is not int or \
                    sample_index != previous_sample_index + 1 or \
                    type(attempt_index) is not int or attempt_index != 1:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal receipt lacks its immediately prior first-attempt context")
            if type(other_race_records) is not list or any(
                    not isinstance(other, dict) or
                    other.get("logical_sample_index", other.get("sample_index")) == sample_index
                    for other in other_race_records):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal attempt has a second race disposition")
            if root_exit_confirmed is not True or root_popen_handle is None:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal phase did not retain the original Popen handle")
            final_root_before = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(root_popen_handle))
            _R23_TABLE.require_same_identity(
                final_root_before, root,
                phase="R23 descendant-terminal final-audit root handle")
            root_waited = _R23_TABLE.wait_for_process_exit(root_popen_handle, 0.001)
            if type(root_waited) is not bool or root_waited is not True:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal final-audit root handle is not signaled")
            final_root_after = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(root_popen_handle))
            _R23_TABLE.require_same_identity(
                final_root_after, root,
                phase="R23 descendant-terminal final-audit root post-wait handle")
            if _R23_TABLE.process_exit_code(root_popen_handle) != root_exit_code:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal Popen exit differs from the final native exit")

            previous_values = record.get("previously_tracked_identities")
            if type(previous_values) is not list or any(
                    not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns"} for item in previous_values):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal active inventory is malformed")
            previous = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in previous_values]
            if len(previous) != len(set(previous)) or root not in set(previous) or \
                    not set(previous).issubset(set(tracked)):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal active identities are duplicated or not phase-tracked")
            if type(completed_samples) is not list or \
                    len(completed_samples) != previous_sample_index:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal audit lacks the exact prior completed-sample ledger")
            completed_indices = [item.get("sample_index")
                for item in completed_samples if isinstance(item, dict)]
            if completed_indices != list(range(1, previous_sample_index + 1)) or \
                    any(not isinstance(item, dict) or
                        item.get("sample_complete") is not True
                        for item in completed_samples):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal predecessor is not a complete sequential sample")
            prior_sample = completed_samples[previous_sample_index - 1]
            prior_monitor = prior_sample.get("exact_monitor_receipt")
            if not isinstance(prior_monitor, dict) or \
                    prior_monitor.get("complete") is not True or \
                    prior_monitor.get("sample_index") != previous_sample_index or \
                    prior_sample.get("errors") != [] or \
                    prior_monitor.get("errors") != [] or \
                    prior_sample.get("root_process_identity", {}).get("pid") != root[0] or \
                    prior_sample.get("root_process_identity", {}).get(
                        "create_time_100ns") != root[1]:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal predecessor is not a clean accepted root sample")
            prior_discovered_values = prior_monitor.get("discovered_identities")
            if type(prior_discovered_values) is not list:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal predecessor lacks its exact active inventory")
            prior_discovered = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in prior_discovered_values if isinstance(item, dict)]
            if len(prior_discovered) != len(prior_discovered_values) or \
                    len(prior_discovered) != len(set(prior_discovered)) or \
                    set(prior_discovered) != set(previous):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal active inventory differs from its accepted predecessor")

            source_references = record.get("source_history_references")
            if type(source_references) is not list or len(source_references) != 3 or \
                    [item.get("role") if isinstance(item, dict) else None
                     for item in source_references] != [
                        "previous_accepted_source", "outer_reconcile",
                        "failed_sample_source"]:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal source history references are malformed")
            accepted = _r22_snapshot_from_bundle(record.get("previous_accepted_source"))
            outer = _r22_snapshot_from_bundle(record.get("outer_reconcile_source"))
            source = _r22_snapshot_from_bundle(record.get("source_table"))
            if record.get("source_snapshot") != _r23_snapshot_receipt(source):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal failed source bundle differs from its raw receipt")
            accepted_rows = _r23_terminal_root_closure_rows(accepted, root, list(previous))
            outer_rows = _r23_terminal_root_closure_rows(outer, root, list(previous))
            source_rows = _r23_terminal_root_closure_rows(source, root, list(previous))
            closure_ids = {(row["pid"], row["create_time_100ns"])
                           for row in source_rows}
            if accepted_rows != outer_rows or outer_rows != source_rows or \
                    record.get("source_root_closure") != source_rows or \
                    closure_ids != set(previous):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal accepted/outer/failed-source closure is not exact")

            expected_source_contexts = (
                (accepted, previous_sample_index,
                 prior_sample.get("sample_attempt_count"), "sample_source_before"),
                (outer, sample_index, 0, "outer_reconcile"),
                (source, sample_index, attempt_index, "sample_source_before"),
            )
            source_sequences: list[int] = []
            for item, (table, expected_sample, expected_attempt, expected_role) in zip(
                    source_references, expected_source_contexts):
                reference = item.get("reference")
                if not isinstance(reference, dict):
                    raise _R23_TABLE.ProcessTableError(
                        "descendant-terminal source reference is not an object")
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    reference, table,
                    sample_index=expected_sample,
                    attempt_index=expected_attempt,
                    source_role=expected_role)
                source_sequences.append(reference.get("sequence"))
            if any(type(sequence) is not int for sequence in source_sequences) or \
                    source_sequences != sorted(set(source_sequences)):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal source history sequences are not strictly ordered")
            accepted_reference = source_references[0]["reference"]
            if prior_sample.get("completed_source_history_reference") != accepted_reference or \
                    prior_sample.get("completed_source_history_sequence") != \
                        accepted_reference.get("sequence") or \
                    record.get("previous_accepted_source_history_sequence") != \
                        accepted_reference.get("sequence"):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal accepted source is not bound to its prior completed sample")

            handoff = record.get("r21_incomplete_handoff_observation")
            target = _R23_TABLE.validate_identity((
                record.get("target_identity", {}).get("pid"),
                record.get("target_identity", {}).get("create_time_100ns")))
            if not isinstance(handoff, dict) or \
                    handoff.get("schema") != "vnext-t2-r21-tracked-sample-exit-r1" or \
                    handoff.get("complete") is not False or \
                    handoff.get("status") != "tracked_exit_unconfirmed_monitor_incomplete" or \
                    handoff.get("logical_sample_index") != sample_index or \
                    handoff.get("whole_sample_attempt_index") != 1 or \
                    handoff.get("failure_stage") != "r21_exact_tracked_resource_read_exit" or \
                    handoff.get("retry_started") is not False or \
                    handoff.get("full_sample_completed_after_retry") is not False or \
                    handoff.get("rss_credit_bytes") != 0 or \
                    handoff.get("cpu_credit_seconds") != {"user": 0.0, "system": 0.0} or \
                    handoff.get("exit_code_credit_issued") is not False or \
                    handoff.get("absence_snapshot_count") != 1 or \
                    handoff.get("errors") != [_monitor_error(
                        "r21_tracked_sample_exit_confirmation",
                        _R23_TABLE.ProcessTableError(
                            "tracked-exit confirmation 2 lost or reused the stage root"),
                        target[0])]:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal nested R21 record is not the original incomplete zero-credit probe")
            failure = handoff.get("sample_failure")
            if not isinstance(failure, dict) or failure.get("exception_type") != \
                    "NoSuchProcess" or failure.get("pid") != target[0]:
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 observation does not bind the exact child resource failure")
            handoff_previous = handoff.get("previously_tracked_identities")
            if type(handoff_previous) is not list or any(
                    not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns"} for item in handoff_previous):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 active generation list is malformed")
            handoff_previous_ids = [_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in handoff_previous]
            if len(handoff_previous_ids) != len(set(handoff_previous_ids)) or \
                    set(handoff_previous_ids) != set(previous) or \
                    handoff.get("source_snapshot") != _r23_snapshot_receipt(source) or \
                    handoff.get("root_identity") != record.get("root_identity"):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 source/root/active generation binding differs")
            target_row = source.by_pid.get(target[0])
            if target_row is None or _r23_raw_identity(target_row) != target or target == root:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal trigger is not a source-bound non-root generation")
            target_subtree = _R23_TABLE.descendant_identities(source, target)
            target_subtree_ids = {(item.pid, item.create_time_100ns)
                                  for item in target_subtree}
            if not target_subtree_ids or not target_subtree_ids.issubset(closure_ids):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 target subtree is outside the exact active root closure")
            retired = handoff.get("retired_tracked_identities")
            if type(retired) is not list or any(
                    not isinstance(item, dict) or set(item) != {
                        "pid", "create_time_100ns"} for item in retired):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 retired generation list is malformed")
            retired_ids = {_R23_TABLE.validate_identity((
                item.get("pid"), item.get("create_time_100ns")))
                for item in retired}
            if retired_ids != target_subtree_ids:
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 retirement does not describe its exact source subtree")

            probe_bundles = record.get("r21_probe_snapshot_bundles")
            probe_refs = record.get("r21_probe_history_references")
            if type(probe_bundles) is not list or len(probe_bundles) != 2 or \
                    type(probe_refs) is not list or len(probe_refs) != 2:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal record lacks both raw R21 confirmation queries")
            probe_tables: list[Any] = []
            probe_sequences: list[int] = []
            for index, (bundle, reference) in enumerate(zip(probe_bundles, probe_refs), 1):
                role = f"tracked_exit_absence_{index}"
                if not isinstance(bundle, dict) or bundle.get("source_role") != role or \
                        type(bundle.get("sequence")) is not int or \
                        not isinstance(reference, dict) or \
                        reference.get("sequence") != bundle.get("sequence"):
                    raise _R23_TABLE.ProcessTableError(
                        "R21 confirmation query sequence/role reference is malformed")
                table = _r22_snapshot_from_bundle(bundle.get("snapshot_bundle"))
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    reference, table, sample_index=sample_index,
                    attempt_index=1, source_role=role)
                probe_tables.append(table)
                probe_sequences.append(bundle["sequence"])
            if not (source_sequences[-1] < probe_sequences[0] < probe_sequences[1]):
                raise _R23_TABLE.ProcessTableError(
                    "R21 confirmation queries are not after the failed source in order")
            first_probe, second_probe = probe_tables
            first_root = first_probe.by_pid.get(root[0])
            if first_root is None or _r23_raw_identity(first_root) != root or \
                    {pid for pid, _ in target_subtree_ids}.intersection(first_probe.by_pid) or \
                    _r20_descendants_from_pid_set(
                        first_probe, {pid for pid, _ in target_subtree_ids}):
                raise _R23_TABLE.ProcessTableError(
                    "R21 confirmation one does not prove child absent with exact root alive")
            for identity in set(previous).difference(target_subtree_ids):
                row = first_probe.by_pid.get(identity[0])
                if row is None or _r23_raw_identity(row) != identity:
                    raise _R23_TABLE.ProcessTableError(
                        "R21 confirmation one loses or reuses another active generation")
            if second_probe.by_pid.get(root[0]) is not None or \
                    {pid for pid, _ in closure_ids}.intersection(second_probe.by_pid) or \
                    _r20_descendants_from_pid_set(
                        second_probe, {pid for pid, _ in closure_ids}):
                raise _R23_TABLE.ProcessTableError(
                    "R21 confirmation two does not prove true root/closure absence")
            handoff_absence = handoff.get("absence_snapshots")
            handoff_checks = handoff.get("absence_checks")
            if type(handoff_absence) is not list or len(handoff_absence) != 1 or \
                    handoff_absence[0] != _r23_snapshot_receipt(first_probe) or \
                    type(handoff_checks) is not list or len(handoff_checks) != 1 or \
                    handoff_checks[0].get("snapshot") != _r23_snapshot_receipt(first_probe):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 accepted absence does not match its captured first query")
            r21_exits = handoff.get("exact_exit_receipts")
            if type(r21_exits) is not list or len(r21_exits) != len(target_subtree_ids):
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 record lacks exact target-subtree exit receipts")
            observed_r21_exit_ids: set[tuple[int, int]] = set()
            for item in r21_exits:
                identity = _R23_TABLE.validate_identity((
                    item.get("identity", {}).get("pid"),
                    item.get("identity", {}).get("create_time_100ns")))
                if item.get("schema") != \
                        "vnext-t2-r21-tracked-generation-natural-exit-r1" or \
                        item.get("complete") is not True or \
                        item.get("wait_confirmed") is not True or \
                        item.get("exit_code_credit_issued") is not False or \
                        item.get("errors") != [] or type(item.get("exit_code")) is not int or \
                        item.get("exit_code") == 259 or \
                        item.get("handle_identity_before_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]} or \
                        item.get("handle_identity_after_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]}:
                    raise _R23_TABLE.ProcessTableError(
                        "nested R21 target-subtree exit receipt is malformed")
                observed_r21_exit_ids.add(identity)
            if observed_r21_exit_ids != target_subtree_ids:
                raise _R23_TABLE.ProcessTableError(
                    "nested R21 exit receipts do not cover the exact target subtree")

            exact_exits = record.get("exact_exit_receipts")
            if type(exact_exits) is not list or len(exact_exits) != len(source_rows):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal exit receipts do not cover the active closure")
            observed_exit_ids: set[tuple[int, int]] = set()
            retained = retained_handles if isinstance(retained_handles, dict) else {}
            for item in exact_exits:
                identity = _R23_TABLE.validate_identity((
                    item.get("identity", {}).get("pid"),
                    item.get("identity", {}).get("create_time_100ns")))
                expected_owner = "original_popen_handle" if identity == root else \
                    "retained_registry_handle"
                if item.get("schema") != \
                        "vnext-t2-r23-descendant-terminal-generation-exit-r1" or \
                        item.get("complete") is not True or \
                        item.get("handle_owner") != expected_owner or \
                        item.get("wait_confirmed") is not True or \
                        item.get("exit_code_credit_issued") is not False or \
                        item.get("errors") != [] or type(item.get("exit_code")) is not int or \
                        isinstance(item.get("exit_code"), bool) or \
                        item.get("exit_code") == 259 or \
                        item.get("handle_identity_before_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]} or \
                        item.get("handle_identity_after_wait") != {
                            "pid": identity[0], "create_time_100ns": identity[1]}:
                    raise _R23_TABLE.ProcessTableError(
                        "descendant-terminal per-generation exit receipt is incomplete")
                handle = root_popen_handle if identity == root else retained.get(identity)
                if handle is None:
                    raise _R23_TABLE.ProcessTableError(
                        f"descendant-terminal audit lacks the original handle for PID {identity[0]}")
                before_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    before_identity, identity,
                    phase="R23 descendant-terminal final handle identity")
                waited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
                if type(waited) is not bool or waited is not True:
                    raise _R23_TABLE.ProcessTableError(
                        f"descendant-terminal final handle is not signaled for PID {identity[0]}")
                after_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    after_identity, identity,
                    phase="R23 descendant-terminal final handle post-wait identity")
                if _R23_TABLE.process_exit_code(handle) != item.get("exit_code"):
                    raise _R23_TABLE.ProcessTableError(
                        f"descendant-terminal final exit code differs for PID {identity[0]}")
                if identity == root and item.get("exit_code") != root_exit_code:
                    raise _R23_TABLE.ProcessTableError(
                        "descendant-terminal root receipt differs from the phase exit code")
                observed_exit_ids.add(identity)
            if observed_exit_ids != closure_ids:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal exit receipts do not exactly cover active generations")

            absence_bundles = record.get("absence_snapshot_bundles")
            absence_refs = record.get("absence_history_references")
            absence_checks = record.get("absence_checks")
            if type(absence_bundles) is not list or len(absence_bundles) != 3 or \
                    type(absence_refs) is not list or len(absence_refs) != 3 or \
                    type(absence_checks) is not list or len(absence_checks) != 3 or \
                    record.get("absence_snapshot_count") != 3:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal receipt lacks three post-wait absence tables")
            absence_sequences: list[int] = []
            closure_pids = {pid for pid, _ in closure_ids}
            for index, (bundle, reference, check) in enumerate(zip(
                    absence_bundles, absence_refs, absence_checks), 1):
                role = f"descendant_terminal_root_absence_{index}"
                if not isinstance(bundle, dict) or bundle.get("source_role") != role or \
                        not isinstance(reference, dict):
                    raise _R23_TABLE.ProcessTableError(
                        "descendant-terminal absence bundle/reference is malformed")
                table = _r22_snapshot_from_bundle(bundle.get("snapshot_bundle"))
                sequence = bundle.get("sequence")
                if type(sequence) is not int or reference.get("sequence") != sequence:
                    raise _R23_TABLE.ProcessTableError(
                        "descendant-terminal absence sequence is invalid")
                _r23_verify_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    reference, table, sample_index=sample_index,
                    attempt_index=1, source_role=role)
                absence_sequences.append(sequence)
                if not isinstance(check, dict) or check.get("index") != index or \
                        check.get("history_sequence") != sequence or \
                        check.get("snapshot") != _r23_snapshot_receipt(table) or \
                        check.get("closure_pids_absent") != sorted(closure_pids) or \
                        check.get("orphan_descendant_count") != 0 or \
                        closure_pids.intersection(table.by_pid) or \
                        _r20_descendants_from_pid_set(table, closure_pids):
                    raise _R23_TABLE.ProcessTableError(
                        f"descendant-terminal absence table {index} is not exact and clear")
                for identity in set(previous):
                    row = table.by_pid.get(identity[0])
                    if row is not None:
                        raise _R23_TABLE.ProcessTableError(
                            f"descendant-terminal absence table {index} has a tracked PID or reuse")
            if absence_sequences != sorted(set(absence_sequences)) or \
                    absence_sequences[0] <= probe_sequences[-1]:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal absence witnesses are not distinct and after R21 probes")
            if closure_pids.intersection(final_table.by_pid) or \
                    _r20_descendants_from_pid_set(final_table, closure_pids):
                raise _R23_TABLE.ProcessTableError(
                    "final inventory contains a terminal generation or orphan descendant")

            failure = record.get("trigger_resource_failure")
            if not isinstance(failure, dict) or failure.get("type") != "NoSuchProcess" or \
                    failure.get("pid") != target[0] or \
                    not isinstance(failure.get("message"), str) or not failure.get("message"):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal trigger is not the exact child NoSuchProcess")
            if record.get("sample_complete") is not False or \
                    record.get("retry_started") is not False or \
                    record.get("full_sample_completed_after_retry") is not False or \
                    record.get("rss_credit_bytes") != 0 or \
                    record.get("cpu_credit_seconds") != {"user": 0.0, "system": 0.0} or \
                    record.get("exit_code_credit_issued") is not False:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal disposition received completion, retry, or credit")
            partial_rss = record.get("partial_rss_bytes_not_credited")
            if type(partial_rss) is not int or partial_rss < 0 or \
                    partial_rss >= working_set_limit_bytes:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal partial RSS is malformed or reaches the phase ceiling")
            discarded = record.get("discarded_attempt")
            discarded_monitor = (discarded.get("exact_monitor_receipt")
                if isinstance(discarded, dict) else None)
            errors_in_monitor = (discarded_monitor.get("errors")
                if isinstance(discarded_monitor, dict) else None)
            expected_sample_failure = (
                type(errors_in_monitor) is list and len(errors_in_monitor) == 1 and
                isinstance(errors_in_monitor[0], dict) and
                errors_in_monitor[0].get("phase") == "sample_process_tree" and
                errors_in_monitor[0].get("type") == "ProcessTableError" and
                errors_in_monitor[0].get("message") ==
                    "exact generation exited during resource read; discard sample and "
                    "require typed exact-generation recovery")
            if not isinstance(discarded, dict) or \
                    discarded.get("sample_index") != sample_index or \
                    discarded.get("attempt_index") != 1 or \
                    discarded.get("complete") is not False or \
                    discarded.get("sample_complete") is not False or \
                    discarded.get("observed_partial_rss_bytes_not_credited") != partial_rss or \
                    discarded.get("credited_rss_bytes") != 0 or \
                    discarded.get("credited_cpu_seconds") != {
                        "user": 0.0, "system": 0.0} or \
                    discarded.get("exit_code_credit_issued") is not False or \
                    discarded.get("errors") != errors_in_monitor or \
                    discarded.get("measured_identities_not_credited") != (
                        discarded_monitor.get("measured_identities")
                        if isinstance(discarded_monitor, dict) else None) or \
                    not isinstance(discarded_monitor, dict) or \
                    discarded_monitor.get("complete") is not False or \
                    discarded_monitor.get("sample_index") != sample_index or \
                    discarded_monitor.get("partial_rss_bytes") != partial_rss or \
                    discarded_monitor.get("rss_bytes") is not None or \
                    discarded_monitor.get("numerical_credit") is not False or \
                    discarded_monitor.get("solver_success_claimed") is not False or \
                    discarded_monitor.get("errors") != record.get(
                        "sample_failure_monitor_errors") or \
                    not expected_sample_failure:
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal discarded-attempt summary is inconsistent")
            if not isinstance(terminal_partial_sample, dict) or \
                    terminal_partial_sample.get("sample_index") != sample_index or \
                    terminal_partial_sample.get("sample_complete") is not False or \
                    terminal_partial_sample.get("sample_attempt_count") != 1 or \
                    terminal_partial_sample.get("process_tree_working_set_bytes") != 0 or \
                    terminal_partial_sample.get("process_tree_user_cpu_seconds") != 0.0 or \
                    terminal_partial_sample.get("process_tree_system_cpu_seconds") != 0.0 or \
                    terminal_partial_sample.get("processes") != [] or \
                    terminal_partial_sample.get("errors") != errors_in_monitor or \
                    terminal_partial_sample.get("exact_monitor_receipt") != discarded_monitor or \
                    terminal_partial_sample.get(
                        "descendant_terminal_root_sample_exit_races") != [record] or \
                    terminal_partial_sample.get("tracked_sample_exit_races") not in ([], None):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal partial sample is not separate and zero-credit")
            checked.append({
                "sample_index": sample_index,
                "previous_accepted_sample_index": previous_sample_index,
                "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
                "target_identity": {"pid": target[0], "create_time_100ns": target[1]},
                "closure_identity_count": len(source_rows),
                "r21_incomplete": True,
                "r21_probe_snapshot_count": 2,
                "absence_snapshot_count": 3,
                "partial_rss_bytes_not_credited": partial_rss,
                "retry_started": False,
                "sample_complete": False,
            })
        except Exception as error:
            errors.append(_monitor_error(
                "r23_descendant_terminal_final_audit", error,
                record.get("root_identity", {}).get("pid")
                if isinstance(record, dict) and
                isinstance(record.get("root_identity"), dict) else None))
    return {
        "schema": "vnext-t2-r23-descendant-terminal-root-sample-exit-final-audit-r1",
        "complete": not errors and len(records) <= 1,
        "record_count": len(records),
        "validated_root_identity": {"pid": root[0],
                                     "create_time_100ns": root[1]},
        "checked_records": checked,
        "errors": errors,
    }


def _r23_final_audit(root_identity: Any, tracked: list[tuple[int, int]],
                     snapshot: Any, *, root_exit_confirmed: bool,
                     root_exit_code: Any = None,
                     working_set_limit_bytes: int = AUTHORITY_WORKING_SET_LIMIT_BYTES,
                     root_popen_handle: Any = None,
                     retained_handles: dict[tuple[int, int], Any] | None = None,
                     unbound_observation_records: list[dict[str, Any]] | None = None,
                     tracked_sample_exit_records: list[dict[str, Any]] | None = None,
                     pre_tree_tracked_exit_records: list[dict[str, Any]] | None = None,
                     membership_growth_records: list[dict[str, Any]] | None = None,
                     terminal_root_sample_exit_records: list[dict[str, Any]] | None = None,
                     descendant_terminal_root_sample_exit_records:
                         list[dict[str, Any]] | None = None,
                     completed_samples: Any = None,
                     terminal_partial_sample: Any = None,
                     lifecycle_session: Any | None = None,
                     phase_snapshot_history: list[dict[str, Any]] | None = None,
                     phase_snapshot_witnesses: Any = None
                     ) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    table = _R23_TABLE.validate_snapshot(snapshot)
    root_id = _R23_TABLE.validate_identity(root_identity)
    by_pid = table.by_pid
    root_row = by_pid.get(root_id[0])
    root_absent = root_row is None
    if not root_exit_confirmed:
        errors.append(_monitor_error(
            "r23_root_wait", RuntimeError("exact native-handle wait was not confirmed"),
            root_id[0]))
    if root_row is not None:
        observed = _r23_raw_identity(root_row)
        if observed == root_id:
            errors.append(_monitor_error(
                "r23_root_residual", RuntimeError(
                    "stage root exact generation remains in SPI table"), root_id[0]))
        else:
            errors.append(_monitor_error(
                "r23_root_pid_reuse", RuntimeError(
                    "stage-root PID was reused before final audit"), root_id[0]))
    try:
        descendants = _r23_descendants_after_leader(table, root_id)
    except Exception as error:
        descendants = []
        errors.append(_monitor_error("r23_post_exit_descendant_audit", error, root_id[0]))
    residual: list[dict[str, Any]] = []
    for row in descendants:
        residual.append({
            "pid": row.identity.pid,
            "create_time_100ns": row.identity.create_time_100ns,
            "ppid": row.ppid,
            "name": row.name,
        })
    reused: list[dict[str, int]] = []
    for identity in tracked:
        pid, ticks = _R23_TABLE.validate_identity(identity)
        current = by_pid.get(pid)
        if current is not None and _r23_raw_identity(current) != (pid, ticks):
            reused.append({"pid": pid, "expected_create_time_100ns": ticks,
                           "observed_create_time_100ns": current.identity.create_time_100ns})
    if reused:
        errors.append(_monitor_error(
            "r23_tracked_pid_reuse", RuntimeError(
                "a tracked PID now names a different generation")))
    unbound_observation_audit = _r20_audit_unbound_observations(
        table, unbound_observation_records or [])
    if unbound_observation_audit.get("complete") is not True:
        errors.extend(unbound_observation_audit.get("errors", []))
    tracked_sample_exit_audit = _r21_audit_tracked_sample_exit_races(
        table, tracked_sample_exit_records or [], root_id, tracked)
    if tracked_sample_exit_audit.get("complete") is not True:
        errors.extend(tracked_sample_exit_audit.get("errors", []))
    pre_tree_tracked_exit_audit = _r22_audit_pre_tree_tracked_exit_races(
        table, pre_tree_tracked_exit_records or [], root_id, tracked)
    if pre_tree_tracked_exit_audit.get("complete") is not True:
        errors.extend(pre_tree_tracked_exit_audit.get("errors", []))
    membership_growth_audit = _r23_audit_membership_growth(
        table, membership_growth_records or [], root_id, tracked,
        phase_snapshot_history, phase_snapshot_witnesses)
    if membership_growth_audit.get("complete") is not True:
        errors.extend(membership_growth_audit.get("errors", []))
    terminal_root_sample_exit_audit = _r23_audit_terminal_root_sample_exits(
        table, terminal_root_sample_exit_records or [], root_id, tracked,
        root_exit_confirmed=root_exit_confirmed,
        root_exit_code=root_exit_code,
        working_set_limit_bytes=working_set_limit_bytes,
        root_popen_handle=root_popen_handle,
        retained_handles=retained_handles,
        completed_samples=completed_samples,
        terminal_partial_sample=terminal_partial_sample,
        other_race_records=[
            *(unbound_observation_records or []),
            *(tracked_sample_exit_records or []),
            *(pre_tree_tracked_exit_records or []),
            *(membership_growth_records or []),
            *(descendant_terminal_root_sample_exit_records or [])],
        phase_snapshot_history=phase_snapshot_history,
        phase_snapshot_witnesses=phase_snapshot_witnesses)
    if terminal_root_sample_exit_audit.get("complete") is not True:
        errors.extend(terminal_root_sample_exit_audit.get("errors", []))
    descendant_terminal_root_sample_exit_audit = \
        _r23_audit_descendant_terminal_root_sample_exits(
            table, descendant_terminal_root_sample_exit_records or [], root_id, tracked,
            root_exit_confirmed=root_exit_confirmed,
            root_exit_code=root_exit_code,
            working_set_limit_bytes=working_set_limit_bytes,
            root_popen_handle=root_popen_handle,
            retained_handles=retained_handles,
            completed_samples=completed_samples,
            terminal_partial_sample=terminal_partial_sample,
            other_race_records=[
                *(unbound_observation_records or []),
                *(tracked_sample_exit_records or []),
                *(pre_tree_tracked_exit_records or []),
                *(membership_growth_records or []),
                *(terminal_root_sample_exit_records or [])],
            phase_snapshot_history=phase_snapshot_history,
            phase_snapshot_witnesses=phase_snapshot_witnesses)
    if descendant_terminal_root_sample_exit_audit.get("complete") is not True:
        errors.extend(descendant_terminal_root_sample_exit_audit.get("errors", []))
    residual_audit = _R23_SUPERVISOR.audit_residual_identities(tracked, table)
    heavy = _r23_exact_heavy_audit(table, lifecycle_session=lifecycle_session)
    if residual_audit.get("complete") is not True:
        errors.append(_monitor_error(
            "r23_tracked_residual_audit", RuntimeError("exact tracked residual audit incomplete")))
    if residual_audit.get("residual_exact_identities"):
        errors.append(_monitor_error(
            "r23_tracked_residual_audit", RuntimeError("tracked process remains after stage exit")))
    try:
        verify_baseline_heavy_processes_clear(heavy)
    except Exception as error:
        errors.append(_monitor_error(
            "r23_global_heavy_audit", error))
    return {
        "schema": "vnext-t2-r23-final-process-tree-audit-r1",
        "complete": not errors,
        "identity_authority": "raw_PID_FILETIME_100ns_SPI_and_original_process_handle",
        "root_identity": {"pid": root_id[0], "create_time_100ns": root_id[1]},
        "root_exit_confirmed": root_exit_confirmed,
        "root_identity_absent": root_absent,
        "snapshot": _r23_snapshot_receipt(table),
        "tracked_identity_count": len(tracked),
        "tracked_pid_reuse": reused,
        "residual_descendant_processes": residual,
        "residual_process_audit": residual_audit,
        "unbound_observation_final_audit": unbound_observation_audit,
        "tracked_sample_exit_final_audit": tracked_sample_exit_audit,
        "pre_tree_tracked_exit_final_audit": pre_tree_tracked_exit_audit,
        "membership_growth_final_audit": membership_growth_audit,
        "terminal_root_sample_exit_final_audit": terminal_root_sample_exit_audit,
        "descendant_terminal_root_sample_exit_final_audit":
            descendant_terminal_root_sample_exit_audit,
        "global_heavy_process_audit": heavy,
        "errors": errors,
    }


def _r23_exact_heavy_audit(snapshot: Any | None = None, *,
                           lifecycle_session: Any | None = None) -> dict[str, Any]:
    try:
        table = _R23_TABLE.validate_snapshot(
            snapshot if snapshot is not None else _R23_TABLE.query_native_process_table())
        heavy = list(_R23_SUPERVISOR.global_heavy_processes(table))
        controller_rows: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        handles: list[Any] = []
        try:
            managed_identities = set(getattr(
                getattr(lifecycle_session, "_registry", None), "identities", ()))
            managed_root = getattr(lifecycle_session, "root_identity", None)
            managed_root_identity = (
                (managed_root.pid, managed_root.creation_time_100ns)
                if managed_root is not None else None)
            for row in table.rows:
                if row.identity.pid == os.getpid() or \
                        not row.name.casefold().startswith("python"):
                    continue
                identity = _r23_raw_identity(row)
                if lifecycle_session is not None and (
                        identity == managed_root_identity or
                        identity in managed_identities or
                        identity[0] == getattr(lifecycle_session, "pid", None)):
                    if identity[0] == getattr(lifecycle_session, "pid", None) and \
                            identity != managed_root_identity and \
                            identity not in managed_identities:
                        raise _R23_TABLE.ProcessTableError(
                            "managed Python PID is present under an unregistered generation")
                    core_identity = _R23_MANAGED_LIFECYCLE.ProcessIdentity(
                        identity[0], identity[1])
                    command = " ".join(
                        lifecycle_session.command_line_for_exact(core_identity))
                    _R23_TABLE.require_same_identity(
                        lifecycle_session.identity_reader(
                            lifecycle_session.handle_for(core_identity)),
                        identity, phase="managed Python command-line post-read")
                else:
                    handle = _R23_TABLE.open_exact_process_handle(row)
                    handles.append(handle)
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(handle), identity,
                        phase="python command-line pre-read")
                    command = " ".join(psutil.Process(identity[0]).cmdline())
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(handle), identity,
                        phase="python command-line post-read")
                    fresh = _R23_TABLE.query_native_process_table()
                    current = _R23_TABLE.validate_snapshot(fresh).by_pid.get(identity[0])
                    if current is None or _r23_raw_identity(current) != identity:
                        raise _R23_TABLE.ProcessTableError(
                            "Python command-line read crossed an exact process generation")
                if "formal_t2_controller.py" in command.casefold() or \
                        "independent_negative_controller_r" in command.casefold():
                    controller_rows.append({"pid": identity[0],
                        "create_time_100ns": identity[1], "name": row.name,
                        "command": command})
        finally:
            close_errors = []
            for handle in reversed(handles):
                try:
                    _R23_TABLE.close_process_handle(handle)
                except Exception as error:
                    close_errors.append(_monitor_error("r23_python_audit_handle_close", error))
            if close_errors:
                errors.extend(close_errors)
        residual = [{"pid": pid, "create_time_100ns": ticks}
                    for pid, ticks in heavy]
        residual.extend(controller_rows)
        return {"schema": "vnext-t2-r23-global-heavy-audit-r1",
                "complete": not errors,
                "processes": residual, "native_heavy_identities": [
                    {"pid": pid, "create_time_100ns": ticks} for pid, ticks in heavy],
                "controller_processes": controller_rows,
                "snapshot": _r23_snapshot_receipt(table), "errors": errors}
    except Exception as error:
        return {"schema": "vnext-t2-r23-global-heavy-audit-r1",
                "complete": False, "processes": [],
                "errors": [_monitor_error("r23_global_heavy_audit", error)],
                **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT}


def verify_baseline_heavy_processes_clear(receipt: Any) -> None:
    """Require an unambiguous, complete, empty R23 global heavy-process audit."""
    if type(receipt) is not dict:
        raise RuntimeError("global heavy-process audit must be an object")
    if receipt.get("schema") != "vnext-t2-r23-global-heavy-audit-r1":
        raise RuntimeError("global heavy-process audit schema is missing or unknown")
    if receipt.get("complete") is not True:
        raise RuntimeError("global heavy-process audit is incomplete")
    for field in ("processes", "controller_processes",
                  "native_heavy_identities", "errors"):
        if field not in receipt or type(receipt[field]) is not list:
            raise RuntimeError(f"global heavy-process audit field {field} is malformed")
        if receipt[field]:
            raise RuntimeError(f"global heavy-process audit field {field} is nonempty")
    snapshot = receipt.get("snapshot")
    _verify_r23_native_snapshot_receipt(snapshot)


def _verify_r23_native_snapshot_receipt(snapshot: Any) -> None:
    """Validate every serialized R23 snapshot field before trusting an empty audit."""
    expected_fields = {
        "schema", "complete", "row_count", "host_identity",
        "system_information_class", "buffer_bytes", "query_attempts",
        "raw_identity_digest_sha256", "identity_authority",
    }
    if type(snapshot) is not dict or set(snapshot) != expected_fields:
        raise RuntimeError("global heavy-process audit snapshot shape is invalid")
    if snapshot["schema"] != "vnext-t2-r23-native-snapshot-receipt-r1" or \
            snapshot["complete"] is not True or \
            snapshot["identity_authority"] != \
                "NtQuerySystemInformation_class5_raw_FILETIME_100ns":
        raise RuntimeError("global heavy-process audit snapshot schema/completeness is invalid")

    host = snapshot["host_identity"]
    host_pin = list(_R23_TABLE.WINDOWS_BUILD_PIN)
    if type(host) is not list or len(host) != 4 or \
            any(type(value) is not int for value in host[:3]) or \
            type(host[3]) is not str or host != host_pin:
        raise RuntimeError("global heavy-process audit snapshot host identity is invalid")

    query_class = snapshot["system_information_class"]
    if type(query_class) is not int or \
            query_class != _R23_TABLE.SYSTEM_INFORMATION_CLASS:
        raise RuntimeError("global heavy-process audit snapshot query class is invalid")

    buffer_bytes = snapshot["buffer_bytes"]
    if type(buffer_bytes) is not int or \
            not _R23_TABLE.SPI_FIXED_HEADER_BYTES <= buffer_bytes <= \
            _R23_TABLE.MAX_BUFFER_BYTES:
        raise RuntimeError("global heavy-process audit snapshot buffer size is invalid")

    query_attempts = snapshot["query_attempts"]
    if type(query_attempts) is not int or \
            not 1 <= query_attempts <= _R23_TABLE.MAX_QUERY_ATTEMPTS:
        raise RuntimeError("global heavy-process audit snapshot query attempts are invalid")

    row_count = snapshot["row_count"]
    if type(row_count) is not int or not 1 <= row_count <= _R23_TABLE.MAX_ROWS:
        raise RuntimeError("global heavy-process audit snapshot row count is invalid")

    digest = snapshot["raw_identity_digest_sha256"]
    if type(digest) is not str or len(digest) != 64 or \
            any(character not in "0123456789abcdef" for character in digest):
        raise RuntimeError("global heavy-process audit snapshot digest is malformed")


def heavy_processes(snapshot: Any | None = None) -> dict[str, Any]:
    """R17 runtime residual gate: exact native inventory and raw process handles."""
    if isinstance(snapshot, dict):
        return _heavy_processes_legacy_r16(snapshot)
    return _r23_exact_heavy_audit(snapshot)


def _r23_handle_for_identity(registry: Any, identity: tuple[int, int],
                             process: Any) -> Any:
    if identity[0] == process.pid:
        _R23_TABLE.require_same_identity(
            _R23_TABLE.read_process_handle_identity(_r23_root_handle(process)), identity,
            phase="stage-root original process handle")
        return _r23_root_handle(process)
    handles = getattr(registry, "_handles", None)
    handle = handles.get(identity) if isinstance(handles, dict) else None
    if handle is None:
        raise _R23_TABLE.ProcessTableError("tracked exact process handle is unavailable")
    _R23_TABLE.require_same_identity(
        _R23_TABLE.read_process_handle_identity(handle), identity,
        phase="tracked original process handle")
    return handle


def _r23_root_handle(process: Any) -> Any:
    """Return the exact root handle for either legacy Popen or lifecycle session."""
    handle = getattr(process, "root_handle", None)
    if type(handle) is int and handle > 0:
        return handle
    handle = getattr(process, "_handle", None)
    if handle is None:
        raise _R23_TABLE.ProcessTableError(
            "stage-root exact original handle is unavailable")
    return handle


def _r23_lifecycle_membership_checkpoint(
        process: Any, observer: Any | None = None) -> dict[str, Any]:
    """Capture the actual Job and lifecycle registry state without sampling resources."""
    job_reader = getattr(process, "job_process_ids", None)
    summary_reader = getattr(process, "summary", None)
    if not callable(job_reader) or not callable(summary_reader):
        raise _R23_TABLE.ProcessTableError(
            "managed lifecycle cannot expose its exact Job/registration checkpoint")
    job_pids = job_reader()
    summary = summary_reader()
    if type(job_pids) is not tuple or any(type(pid) is not int or pid <= 0 for pid in job_pids) or \
            tuple(sorted(set(job_pids))) != job_pids or not isinstance(summary, Mapping):
        raise _R23_TABLE.ProcessTableError(
            "managed lifecycle Job/registration checkpoint is malformed")
    registered_rows = summary.get("registered_identities")
    event_count = summary.get("event_count")
    pending_boundary = summary.get("pending_boundary_events")
    pending_files = summary.get("pending_debug_file_handles")
    event_receipts = summary.get("event_receipts")
    module_errors = summary.get("module_lineage_errors")
    if type(registered_rows) is not list or type(event_count) is not int or event_count < 0 or \
            type(pending_boundary) is not list or type(pending_files) is not list or \
            type(event_receipts) is not list or not isinstance(module_errors, Mapping):
        raise _R23_TABLE.ProcessTableError(
            "managed lifecycle registration/event checkpoint is malformed")
    registered = tuple(sorted(_R23_TABLE.validate_identity((
        row.get("pid"), row.get("creation_time_100ns")))
        for row in registered_rows if isinstance(row, Mapping)))
    if len(registered) != len(registered_rows) or len(registered) != len(set(registered)):
        raise _R23_TABLE.ProcessTableError(
            "managed lifecycle registered identity inventory is malformed")
    observer_event_receipts: list[dict[str, Any]] = []
    if observer is not None:
        observer_reader = getattr(observer, "event_receipts", None)
        if not callable(observer_reader):
            raise _R23_TABLE.ProcessTableError(
                "managed observer cannot expose its durable lifecycle event receipts")
        observer_rows = observer_reader()
        if type(observer_rows) is not list or any(
                not isinstance(item, Mapping) for item in observer_rows):
            raise _R23_TABLE.ProcessTableError(
                "managed observer event receipt inventory is malformed")
        observer_event_receipts = copy.deepcopy(observer_rows)
    return {
        "job_pids": job_pids,
        "registered_identities": registered,
        "event_count": event_count,
        "pending_boundary_events": tuple(pending_boundary),
        "pending_debug_file_handles": copy.deepcopy(pending_files),
        "event_receipts": copy.deepcopy(event_receipts),
        "observer_event_receipts": observer_event_receipts,
        "module_lineage_errors": copy.deepcopy(dict(module_errors)),
    }


def _r23_boundary_registered_birth_growth_proof(
        process: Any, before: Mapping[str, Any], after: Mapping[str, Any], *,
        before_tree: tuple[Any, ...], after_tree: tuple[Any, ...],
        root_identity: tuple[int, int], after_snapshot: Any, after_sequence: int,
        before_sequence: int, before_snapshot: Any, before_source_role: str,
        sample_index: int, attempt_index: int,
        phase_snapshot_history: list[dict[str, Any]],
        phase_snapshot_witnesses: list[str]) -> dict[str, Any]:
    """Bind a new descendant seen after a discarded boundary to its exact CREATE birth."""
    proof: dict[str, Any] = {
        "schema": "vnext-t2-r23-boundary-registered-birth-growth-r1",
        "complete": False,
        "status": "boundary_birth_growth_unproven",
        "before_identities": [],
        "after_identities": [],
        "added_identities": [],
        "birth_event_receipts": [],
        "history_references": [],
        "pre_attempt_source_reference": None,
        "debug_event_close_receipts": [],
        "retained_handle_receipts": [],
        "errors": [],
        **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT,
    }
    try:
        def tree_map(rows: tuple[Any, ...]) -> dict[tuple[int, int], tuple[int, str]]:
            result: dict[tuple[int, int], tuple[int, str]] = {}
            for item in rows:
                identity = _R23_TABLE.validate_identity(item[0])
                if identity in result or type(item[1]) is not int or \
                        type(item[2]) is not str or not item[2]:
                    raise _R23_TABLE.ProcessTableError(
                        "boundary membership row is malformed or duplicated")
                result[identity] = (item[1], item[2])
            return result

        old_rows, new_rows = tree_map(before_tree), tree_map(after_tree)
        old_ids, new_ids = set(old_rows), set(new_rows)
        added = new_ids - old_ids
        if not added or not old_ids.issubset(new_ids) or not old_ids or \
                root_identity not in old_ids:
            raise _R23_TABLE.ProcessTableError(
                "post-release source is not one strict descendant birth")
        for identity in old_ids:
            if old_rows[identity] != new_rows[identity]:
                raise _R23_TABLE.ProcessTableError(
                    "managed birth growth changed an existing parent/name row")
        proof["before_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(old_ids)]
        proof["after_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(new_ids)]
        proof["added_identities"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(added)]

        if type(phase_snapshot_history) is not list or \
                type(phase_snapshot_witnesses) is not list or \
                len(phase_snapshot_history) != len(phase_snapshot_witnesses) or \
                type(after_sequence) is not int or not 0 <= after_sequence < len(phase_snapshot_history) or \
                type(before_sequence) is not int or not 0 <= before_sequence < after_sequence:
            raise _R23_TABLE.ProcessTableError(
                "managed birth growth lacks its exact post-boundary SPI history")
        history_entry = phase_snapshot_history[after_sequence]
        if not isinstance(history_entry, Mapping) or \
                history_entry.get("sequence") != after_sequence or \
                history_entry.get("sample_index") != sample_index or \
                history_entry.get("attempt_index") != attempt_index:
            raise _R23_TABLE.ProcessTableError(
                "post-boundary SPI history row does not bind the discarded attempt")
        if before_source_role not in {"outer_reconcile", "sample_source_before"}:
            raise _R23_TABLE.ProcessTableError(
                "pre-attempt SPI source role is not an authorized exact baseline")
        before_source_attempt = 0 if before_source_role == "outer_reconcile" else attempt_index
        before_reference = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses, before_sequence,
            before_snapshot, sample_index=sample_index,
            attempt_index=before_source_attempt, source_role=before_source_role)
        proof["pre_attempt_source_reference"] = {
            "source_role": before_source_role, **before_reference}
        for identity in added:
            if any(identity[0] in row.get("pids", [])
                   for row in phase_snapshot_history[:before_sequence + 1]
                   if isinstance(row, Mapping)):
                raise _R23_TABLE.ProcessTableError(
                    "added descendant PID existed in an earlier complete SPI source")

        before_events = before.get("event_receipts")
        after_events = after.get("event_receipts")
        before_observer_events = before.get("observer_event_receipts")
        after_observer_events = after.get("observer_event_receipts")
        if type(before_events) is not list or type(after_events) is not list or \
                len(after_events) < len(before_events) or \
                after_events[:len(before_events)] != before_events or \
                type(before_observer_events) is not list or \
                type(after_observer_events) is not list or \
                len(after_observer_events) < len(before_observer_events) or \
                after_observer_events[:len(before_observer_events)] != before_observer_events:
            raise _R23_TABLE.ProcessTableError(
                "core/observer lifecycle event histories are not append-only across the boundary")
        delta = after_events[len(before_events):]
        observer_delta = after_observer_events[len(before_observer_events):]
        allowed = {"birth_registered", "debug_event_file_close", "load_dll"}
        if not delta or any(not isinstance(item, Mapping) or
                            item.get("event") not in allowed for item in delta):
            raise _R23_TABLE.ProcessTableError(
                "boundary growth has an unclassified lifecycle event")
        births = [item for item in delta if item.get("event") == "birth_registered"]
        captured = [item for item in observer_delta
                    if item.get("event") == "managed_birth_source_witness_captured"]
        closes = [item for item in delta if item.get("event") == "debug_event_file_close"]
        loads = [item for item in delta if item.get("event") == "load_dll"]
        close_receipts: list[Mapping[str, Any]] = []
        for item in closes:
            receipt = item.get("file_handle_close")
            if not isinstance(receipt, Mapping) or \
                    receipt.get("event_code") != \
                        _R23_MANAGED_LIFECYCLE.CREATE_PROCESS_DEBUG_EVENT or \
                    receipt.get("purpose") != "created_image_file" or \
                    item.get("event_sequence") != receipt.get("event_sequence"):
                raise _R23_TABLE.ProcessTableError(
                    "boundary CREATE lacks its exact standalone file-close receipt")
            close_receipts.append(receipt)
        for item in loads:
            receipt = item.get("file_handle_close")
            if not isinstance(receipt, Mapping) or \
                    receipt.get("event_code") != \
                        _R23_MANAGED_LIFECYCLE.LOAD_DLL_DEBUG_EVENT or \
                    receipt.get("purpose") != "loaded_module_file" or \
                    item.get("event_sequence") != receipt.get("event_sequence"):
                raise _R23_TABLE.ProcessTableError(
                    "boundary LOAD_DLL lacks its exact nested file-close receipt")
            close_receipts.append(receipt)
        if len(births) != len(added) or len(captured) != len(added) or \
                len(close_receipts) != after.get("event_count", -1) - before.get("event_count", -1):
            raise _R23_TABLE.ProcessTableError(
                "lifecycle event delta does not account for each CREATE/DLL event")
        close_by_sequence: dict[int, Mapping[str, Any]] = {}
        for receipt in close_receipts:
            if not isinstance(receipt, Mapping) or receipt.get("complete") is not True or \
                    receipt.get("close_attempted") is not True or \
                    receipt.get("purpose") not in {"created_image_file", "loaded_module_file"}:
                raise _R23_TABLE.ProcessTableError(
                    "boundary debug event lacks its exact successful file-close receipt")
            sequence = receipt.get("event_sequence")
            if type(sequence) is not int or sequence <= 0 or sequence in close_by_sequence or \
                    receipt.get("event_pid") <= 0 or receipt.get("event_thread_id") <= 0:
                raise _R23_TABLE.ProcessTableError(
                    "boundary debug close receipt has invalid or duplicate identity")
            close_by_sequence[sequence] = receipt
        load_sequences: set[int] = set()
        for item in loads:
            witness = item.get("module_witness")
            identity_row = item.get("identity")
            close = item.get("file_handle_close")
            if not isinstance(witness, Mapping) or witness.get("witness_complete") is not True or \
                    witness.get("file_handle_present") is not True or \
                    not isinstance(identity_row, Mapping) or not isinstance(close, Mapping):
                raise _R23_TABLE.ProcessTableError(
                    "boundary LOAD_DLL lacks a complete module/file witness")
            identity = _R23_TABLE.validate_identity((
                identity_row.get("pid"), identity_row.get("creation_time_100ns")))
            sequence = close.get("event_sequence")
            if close.get("event_code") != _R23_MANAGED_LIFECYCLE.LOAD_DLL_DEBUG_EVENT or \
                    close.get("event_pid") != identity[0] or \
                    witness.get("identity") != identity_row or \
                    item.get("event_sequence") != sequence or \
                    witness.get("load_event_sequence") != sequence or \
                    type(sequence) is not int or sequence in load_sequences or \
                    sequence not in close_by_sequence or \
                    close_by_sequence[sequence].get("purpose") != "loaded_module_file":
                raise _R23_TABLE.ProcessTableError(
                    "boundary LOAD_DLL close/module identity does not reconcile")
            load_sequences.add(sequence)
        birth_ids: set[tuple[int, int]] = set()
        for birth in births:
            identity_row = birth.get("identity")
            parent_row = birth.get("parent_identity")
            ack = birth.get("ack")
            measurement = birth.get("creation_measurement")
            source = birth.get("source_snapshot_receipt")
            sequence = birth.get("event_sequence")
            if not isinstance(identity_row, Mapping) or not isinstance(parent_row, Mapping) or \
                    not isinstance(ack, Mapping) or not isinstance(measurement, Mapping) or \
                    not isinstance(source, Mapping):
                raise _R23_TABLE.ProcessTableError(
                    "managed CREATE birth is missing a typed source/ACK/resource receipt")
            identity = _R23_TABLE.validate_identity((
                identity_row.get("pid"), identity_row.get("creation_time_100ns")))
            parent = _R23_TABLE.validate_identity((
                parent_row.get("pid"), parent_row.get("creation_time_100ns")))
            if identity not in added or identity in birth_ids or \
                    source.get("complete") is not True or \
                    source.get("schema") != "vnext-t2-r23-managed-birth-source-witness-r1" or \
                    source.get("row_identity") != identity_row or \
                    source.get("row_ppid") != parent[0] or \
                    source.get("phase") != "managed_create" or \
                    source.get("event_sequence") != sequence or \
                    source.get("sequence") != source.get("history_reference", {}).get("sequence") or \
                    source.get("sequence", -1) <= before_sequence or \
                    source.get("row_ppid") != new_rows[identity][0] or \
                    source.get("row_name") != new_rows[identity][1] or \
                    parent not in new_ids or new_rows[identity][0] != parent[0] or \
                    identity[1] < parent[1] or \
                    ack.get("child_pid") != identity[0] or \
                    ack.get("child_creation_time_100ns") != identity[1] or \
                    ack.get("parent_pid") != parent[0] or \
                    ack.get("parent_creation_time_100ns") != parent[1] or \
                    ack.get("identity_registered") is not True or \
                    ack.get("handle_duplicated") is not True or \
                    ack.get("job_bound") is not True or \
                    ack.get("creation_sample_measured") is not True or \
                    ack.get("resume_permitted") is not True or \
                    ack.get("registration_sequence") != birth.get("registration_sequence") or \
                    measurement.get("complete") is not True or \
                    measurement.get("phase") != "create" or \
                    measurement.get("identity") != identity_row or \
                    measurement.get("handle_identity_before") != identity_row or \
                    measurement.get("handle_identity_after") != identity_row or \
                    measurement.get("event_sequence") != sequence or \
                    type(measurement.get("rss_bytes")) is not int or measurement["rss_bytes"] < 0:
                raise _R23_TABLE.ProcessTableError(
                    "managed CREATE birth does not bind the exact new descendant generation")
            history_ref = source.get("history_reference")
            source_sequence = source.get("sequence")
            witness_ascii = phase_snapshot_witnesses[source_sequence]
            witness_row = phase_snapshot_history[source_sequence]
            if not isinstance(history_ref, Mapping) or \
                    identity[0] not in witness_row.get("pids", []) or \
                    source.get("snapshot_receipt") != witness_row.get("snapshot_receipt") or \
                    history_ref.get("sequence") != source_sequence or \
                    history_ref.get("source_role") != "managed_create_1" or \
                    history_ref.get("pid_set_sha256") != witness_row.get("pid_set_sha256") or \
                    history_ref.get("prefix_sha256") != witness_row.get("prefix_sha256") or \
                    history_ref.get("captured_witness_sha256") != sha256_bytes(
                        witness_ascii.encode("ascii")):
                raise _R23_TABLE.ProcessTableError(
                    "managed CREATE source receipt differs from its frozen SPI history witness")
            matching_capture = [item for item in captured
                if item.get("identity") == identity_row and
                item.get("source_receipt") == source and
                item.get("phase_history_entry") == witness_row and
                item.get("phase_history_witness_ascii") == witness_ascii]
            if len(matching_capture) != 1:
                raise _R23_TABLE.ProcessTableError(
                    "managed CREATE lacks one matching captured source-witness event")
            create_close = close_by_sequence.get(sequence)
            if create_close is None or create_close.get("event_code") != \
                    _R23_MANAGED_LIFECYCLE.CREATE_PROCESS_DEBUG_EVENT or \
                    create_close.get("event_pid") != identity[0] or \
                    create_close.get("purpose") != "created_image_file":
                raise _R23_TABLE.ProcessTableError(
                    "managed CREATE birth lacks its exact closed CREATE_PROCESS event")
            typed = _R23_MANAGED_LIFECYCLE.ProcessIdentity(identity[0], identity[1])
            handle = process.handle_for(typed)
            _R23_TABLE.require_same_identity(
                _R23_TABLE.read_process_handle_identity(handle), identity,
                phase="boundary managed-birth retained handle")
            birth_ids.add(identity)
            proof["birth_event_receipts"].append(copy.deepcopy(dict(birth)))
            proof["history_references"].append(copy.deepcopy(dict(history_ref)))
            proof["retained_handle_receipts"].append({
                "identity": identity_row, "complete": True,
                "source": "core_registered_exact_handle"})
        if birth_ids != added:
            raise _R23_TABLE.ProcessTableError(
                "managed CREATE receipts do not exactly cover new descendant identities")
        create_sequences = {receipt.get("event_sequence")
                            for receipt in close_receipts
                            if isinstance(receipt, Mapping) and
                            receipt.get("event_code") ==
                                _R23_MANAGED_LIFECYCLE.CREATE_PROCESS_DEBUG_EVENT}
        dll_sequences = {receipt.get("event_sequence")
                         for receipt in close_receipts
                         if isinstance(receipt, Mapping) and
                         receipt.get("event_code") ==
                            _R23_MANAGED_LIFECYCLE.LOAD_DLL_DEBUG_EVENT}
        if create_sequences != {item.get("event_sequence") for item in births} or \
                dll_sequences != load_sequences or \
                len(create_sequences) + len(dll_sequences) != len(close_receipts):
            raise _R23_TABLE.ProcessTableError(
                "CREATE/DLL debug receipts do not exactly cover their successful close events")
        released_events = [copy.deepcopy(dict(receipt)) for receipt in close_receipts]
        proof["debug_event_close_receipts"] = copy.deepcopy(released_events)
        if len(released_events) != after.get("event_count", -1) - before.get("event_count", -1):
            raise _R23_TABLE.ProcessTableError(
                "managed event count is not reconciled to actual debug-event close receipts")
        proof["complete"] = True
        proof["status"] = "one_exact_managed_create_growth_bound_for_fresh_retry"
    except Exception as error:
        proof["errors"].append(_monitor_error(
            "r23_boundary_registered_birth_growth", error, root_identity[0]))
    return proof


def _r23_load_dll_boundary_retry_record(
        process: Any, final_exact: Mapping[str, Any], attempt_state: Mapping[str, Any], *,
        lifecycle_observer: Any,
        root_identity: tuple[int, int], sample_index: int, attempt_index: int,
        previously_tracked: list[tuple[int, int]],
        outer_reconcile_snapshot: Any, outer_reconcile_history_sequence: int | None,
        checkpoint_before: Any, deadline_monotonic: float,
        phase_snapshot_history: list[dict[str, Any]] | None,
        phase_snapshot_witnesses: list[str] | None) -> dict[str, Any] | None:
    """Prove a discarded LOAD_DLL-only boundary did not change process membership."""
    boundary = final_exact.get("sample_attempt_boundary")
    if not isinstance(boundary, Mapping) or boundary.get("membership_changed") is not True:
        return None
    released = boundary.get("released_boundary_events")
    record: dict[str, Any] = {
        "schema": "vnext-t2-r23-load-dll-boundary-retry-r1",
        "complete": False,
        "status": "lifecycle_boundary_membership_unproven",
        "sample_index": sample_index,
        "attempt_index": attempt_index,
        "root_identity": {"pid": root_identity[0],
                           "create_time_100ns": root_identity[1]},
        "pending_event_codes": copy.deepcopy(boundary.get("pending_event_codes")),
        "released_boundary_events": copy.deepcopy(released),
        "job_membership_before": None,
        "job_membership_after": None,
        "registered_identities_before": None,
        "registered_identities_after": None,
        "retained_handle_identity_receipts": [],
        "outer_reconcile_source": None,
        "attempt_source_references": [],
        "boundary_after_source": None,
        "exact_monitor_receipt": copy.deepcopy(dict(final_exact)),
        "rss_credit_bytes": 0,
        "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "retry_started": False,
        "full_sample_completed_after_retry": False,
        "errors": [],
    }
    try:
        pending_codes = boundary.get("pending_event_codes")
        events = released.get("events") if isinstance(released, Mapping) else None
        source_errors = final_exact.get("errors")
        exact_boundary_failure = (
            type(source_errors) is list and len(source_errors) == 1 and
            isinstance(source_errors[0], Mapping) and
            source_errors[0].get("phase") == "sample_process_tree" and
            source_errors[0].get("type") == "MonitorIncomplete" and
            source_errors[0].get("message") in {
                "debug event crossed the pre-query whole-sample boundary",
                "debug event crossed the post-query whole-sample boundary",
                "debug event crossed the whole-sample lifecycle boundary"})
        if final_exact.get("complete") is not False or exact_boundary_failure is not True or \
                final_exact.get("rss_bytes") is not None or \
                final_exact.get("credited_rss_bytes") != 0 or \
                final_exact.get("numerical_credit") is not False or \
                final_exact.get("solver_success_claimed") is not False:
            raise _R23_TABLE.ProcessTableError(
                "failed whole-sample receipt has another error or any resource/solver credit")
        if boundary.get("complete") is not False or \
                boundary.get("reason") != "debug_membership_event_during_sample" or \
                type(pending_codes) is not list or not pending_codes or \
                any(code != _R23_MANAGED_LIFECYCLE.LOAD_DLL_DEBUG_EVENT for code in pending_codes) or \
                not isinstance(released, Mapping) or released.get("complete") is not True or \
                type(released.get("count")) is not int or type(events) is not list or \
                released.get("count") != len(events) or len(events) < len(pending_codes) or any(
                    not isinstance(item, Mapping) or
                    item.get("event_code") != _R23_MANAGED_LIFECYCLE.LOAD_DLL_DEBUG_EVENT or
                    type(item.get("pid")) is not int or item.get("pid") <= 0 or
                    type(item.get("thread_id")) is not int or item.get("thread_id") <= 0 or
                    item.get("exit_code") is not None for item in events):
            raise _R23_TABLE.ProcessTableError(
                "boundary is not one complete LOAD_DLL-only discard/release batch")
        if type(checkpoint_before) is not dict or \
                checkpoint_before.get("complete") is not True:
            raise _R23_TABLE.ProcessTableError(
                "pre-attempt exact Job/registration checkpoint is unavailable")
        before = checkpoint_before["value"]
        if phase_snapshot_history is None or type(phase_snapshot_witnesses) is not list or \
                len(phase_snapshot_history) != len(phase_snapshot_witnesses) or \
                type(outer_reconcile_history_sequence) is not int or \
                outer_reconcile_snapshot is None:
            raise _R23_TABLE.ProcessTableError(
                "boundary retry lacks the exact outer SPI source-history reference")
        outer_ref = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses,
            outer_reconcile_history_sequence, outer_reconcile_snapshot,
            sample_index=sample_index, attempt_index=0,
            source_role="outer_reconcile")
        record["outer_reconcile_source"] = outer_ref

        snapshots = attempt_state.get("snapshot_sequence")
        sequences = attempt_state.get("snapshot_history_sequences")
        if type(snapshots) is not list or type(sequences) is not list or \
                len(snapshots) != len(sequences) or len(snapshots) > 2:
            raise _R23_TABLE.ProcessTableError(
                "discarded lifecycle boundary has malformed in-attempt SPI source list")
        source_snapshots = ([outer_reconcile_snapshot] if not snapshots else snapshots)
        if snapshots:
            before_attempt_sequence = sequences[0]
            before_attempt_source_role = "sample_source_before"
        else:
            before_attempt_sequence = outer_reconcile_history_sequence
            before_attempt_source_role = "outer_reconcile"
        baseline = _R23_TABLE.validate_snapshot(source_snapshots[0])
        baseline_tree = tuple(sorted((
            (item.pid, item.create_time_100ns),
            baseline.by_pid[item.pid].ppid, baseline.by_pid[item.pid].name)
            for item in _R23_TABLE.descendant_identities(
                baseline, root_identity, previously_tracked=previously_tracked)))
        baseline_identities = tuple(item[0] for item in baseline_tree)
        if root_identity not in baseline_identities:
            raise _R23_TABLE.ProcessTableError(
                "boundary retry source does not contain the exact root generation")
        for position, snapshot in enumerate(snapshots):
            table = _R23_TABLE.validate_snapshot(snapshot)
            projection = tuple(sorted((
                (item.pid, item.create_time_100ns), table.by_pid[item.pid].ppid,
                table.by_pid[item.pid].name)
                for item in _R23_TABLE.descendant_identities(
                    table, root_identity, previously_tracked=previously_tracked)))
            if projection != baseline_tree:
                raise _R23_TABLE.ProcessTableError(
                    "in-attempt SPI source differs from the exact pre-attempt membership")
            role = "sample_source_before" if position == 0 else "sample_source_after"
            record["attempt_source_references"].append(
                _r23_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses, sequences[position],
                    table, sample_index=sample_index, attempt_index=attempt_index,
                    source_role=role))

        after_snapshot = _R23_TABLE.validate_snapshot(
            _R23_TABLE.query_native_process_table())
        after_sequence = _r23_append_snapshot_history(
            phase_snapshot_history, phase_snapshot_witnesses, after_snapshot,
            sample_index=sample_index, attempt_index=attempt_index,
            source_role="sample_boundary_after")
        after_projection = tuple(sorted((
            (item.pid, item.create_time_100ns), after_snapshot.by_pid[item.pid].ppid,
            after_snapshot.by_pid[item.pid].name)
            for item in _R23_TABLE.descendant_identities(
                after_snapshot, root_identity, previously_tracked=previously_tracked)))
        checkpoint_after = _r23_lifecycle_membership_checkpoint(process, lifecycle_observer)
        registered_birth_growth = None
        if after_projection != baseline_tree:
            if type(before_attempt_sequence) is not int:
                raise _R23_TABLE.ProcessTableError(
                    "managed birth growth lacks the exact pre-attempt source sequence")
            registered_birth_growth = _r23_boundary_registered_birth_growth_proof(
                process, before, checkpoint_after,
                before_tree=baseline_tree, after_tree=after_projection,
                root_identity=root_identity, after_snapshot=after_snapshot,
                after_sequence=after_sequence, before_sequence=before_attempt_sequence,
                before_snapshot=source_snapshots[0],
                before_source_role=before_attempt_source_role,
                sample_index=sample_index,
                attempt_index=attempt_index,
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses)
            record["registered_birth_growth"] = registered_birth_growth
            if registered_birth_growth.get("complete") is not True:
                raise _R23_TABLE.ProcessTableError(
                    "post-release membership growth lacks its exact managed CREATE proof")
            record["retry_seed_identities"] = copy.deepcopy(
                registered_birth_growth["after_identities"])
        record["boundary_after_source"] = _r23_snapshot_history_reference(
            phase_snapshot_history, phase_snapshot_witnesses, after_sequence,
            after_snapshot, sample_index=sample_index, attempt_index=attempt_index,
            source_role="sample_boundary_after")

        expected_event_delta = checkpoint_after["event_count"] - before["event_count"]
        if registered_birth_growth is None:
            if expected_event_delta != len(events):
                raise _R23_TABLE.ProcessTableError(
                    "unchanged-membership LOAD_DLL batch differs from exact event count")
        else:
            close_receipts = registered_birth_growth.get("debug_event_close_receipts")
            if type(close_receipts) is not list or expected_event_delta != len(close_receipts):
                raise _R23_TABLE.ProcessTableError(
                    "managed-birth debug events do not reconcile with the lifecycle event count")
            unmatched = list(close_receipts)
            for event in events:
                match = next((index for index, receipt in enumerate(unmatched)
                    if receipt.get("event_code") == event.get("event_code") and
                    receipt.get("event_pid") == event.get("pid") and
                    receipt.get("event_thread_id") == event.get("thread_id")), None)
                if match is None:
                    raise _R23_TABLE.ProcessTableError(
                        "released boundary event lacks its exact lifecycle close receipt")
                unmatched.pop(match)
        expected_tree_identities = tuple(sorted(
            _R23_TABLE.validate_identity(item[0]) for item in after_projection))
        if (registered_birth_growth is None and
                checkpoint_after["job_pids"] != before["job_pids"]) or \
                (registered_birth_growth is None and
                 checkpoint_after["registered_identities"] != before["registered_identities"]) or \
                (registered_birth_growth is not None and
                 checkpoint_after["registered_identities"] != expected_tree_identities) or \
                checkpoint_after["pending_boundary_events"] != () or \
                checkpoint_after["pending_debug_file_handles"] != [] or \
                checkpoint_after["module_lineage_errors"] != before["module_lineage_errors"]:
            raise _R23_TABLE.ProcessTableError(
                "Job/registration/event/file-handle state changed outside the released DLL batch")
        exact_identities = tuple(sorted((
            _R23_TABLE.validate_identity(identity) for identity in baseline_identities)))
        if tuple(sorted(before["job_pids"])) != tuple(sorted(pid for pid, _ in exact_identities)) or \
                before["registered_identities"] != exact_identities or \
                tuple(sorted(checkpoint_after["job_pids"])) != tuple(sorted(
                    pid for pid, _ in expected_tree_identities)) or \
                checkpoint_after["registered_identities"] != expected_tree_identities:
            raise _R23_TABLE.ProcessTableError(
                "Job and registered identity sets do not equal their exact SPI source")
        event_pids = {item["pid"] for item in events}
        if not event_pids.issubset({pid for pid, _ in expected_tree_identities}):
            raise _R23_TABLE.ProcessTableError(
                "LOAD_DLL batch contains a PID outside the exact post-release SPI set")

        handle_receipts: list[dict[str, Any]] = []
        identity_factory = getattr(_R23_MANAGED_LIFECYCLE, "ProcessIdentity", None)
        handle_for = getattr(process, "handle_for", None)
        if not callable(identity_factory) or not callable(handle_for):
            raise _R23_TABLE.ProcessTableError(
                "managed lifecycle cannot revalidate exact retained handles")
        for identity in expected_tree_identities:
            handle = handle_for(identity_factory(identity[0], identity[1]))
            observed = _R23_TABLE.validate_identity(
                _R23_TABLE.read_process_handle_identity(handle))
            _R23_TABLE.require_same_identity(
                observed, identity, phase="LOAD_DLL boundary retry retained handle")
            handle_receipts.append({"identity": {"pid": identity[0],
                                                  "create_time_100ns": identity[1]},
                                    "handle_identity": {"pid": observed[0],
                                                        "create_time_100ns": observed[1]}})
        record["retained_handle_identity_receipts"] = handle_receipts
        if registered_birth_growth is None:
            event_start = before["event_count"] + 1
            expected_receipts = [item for item in checkpoint_after["event_receipts"]
                                 if isinstance(item, Mapping) and
                                 type(item.get("event_sequence")) is int and
                                 event_start <= item["event_sequence"] <=
                                     checkpoint_after["event_count"]]
            if len(expected_receipts) != len(events) or any(
                    receipt.get("event") != "load_dll" or
                    receipt.get("event_sequence") != event_start + position or
                    not isinstance(receipt.get("identity"), Mapping) or
                    receipt["identity"].get("pid") != event["pid"] or
                    receipt.get("thread_id") != event["thread_id"] or
                    not isinstance(receipt.get("module_witness"), Mapping) or
                    receipt["module_witness"].get("witness_complete") is not True or
                    not isinstance(receipt.get("file_handle_close"), Mapping) or
                    receipt["file_handle_close"].get("complete") is not True
                    for position, (receipt, event) in enumerate(zip(expected_receipts, events))):
                raise _R23_TABLE.ProcessTableError(
                    "released LOAD_DLL batch lacks exact module/handle-close receipts")
        else:
            close_receipts = list(registered_birth_growth["debug_event_close_receipts"])
            expected_receipts = []
            for event in events:
                match = next((index for index, receipt in enumerate(close_receipts)
                    if receipt.get("event_code") == event.get("event_code") and
                    receipt.get("event_pid") == event.get("pid") and
                    receipt.get("event_thread_id") == event.get("thread_id")), None)
                if match is None:
                    raise _R23_TABLE.ProcessTableError(
                        "released LOAD_DLL event lacks its exact successful close receipt")
                expected_receipts.append(close_receipts.pop(match))
        record["job_membership_before"] = list(before["job_pids"])
        record["job_membership_after"] = list(checkpoint_after["job_pids"])
        record["registered_identities_before"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in before["registered_identities"]]
        record["registered_identities_after"] = [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in checkpoint_after["registered_identities"]]
        record["released_event_receipts"] = copy.deepcopy(expected_receipts)
        record["complete"] = True
        record["status"] = ("load_dll_batch_released_one_managed_birth_growth"
            if registered_birth_growth is not None else
            "load_dll_batch_released_membership_unchanged")
    except Exception as error:
        record["errors"].append(_monitor_error(
            "r23_load_dll_boundary_retry_proof", error, root_identity[0]))
    record["retry_started"] = record.get("complete") is True and \
        attempt_index < R20_MAX_WHOLE_SAMPLE_ATTEMPTS and \
        time.monotonic() < deadline_monotonic
    if not record["retry_started"]:
        record["status"] = ("load_dll_boundary_retry_exhausted_monitor_incomplete"
            if record.get("complete") is True else
            "load_dll_boundary_membership_unproven_monitor_incomplete")
    return record


def _r23_wait_gone(identity: tuple[int, int], handle: Any,
                    *, timeout_seconds: float,
                    snapshot_observer: Any | None = None) -> dict[str, Any]:
    try:
        _R23_TABLE.require_same_identity(
            _R23_TABLE.read_process_handle_identity(handle), identity,
            phase="exact-generation pre-wait")
        waited = _R23_TABLE.wait_for_process_exit(handle, timeout_seconds)
        if waited is not True:
            raise _R23_TABLE.ProcessTableError("exact handle wait did not confirm exit")
        _R23_TABLE.require_same_identity(
            _R23_TABLE.read_process_handle_identity(handle), identity,
            phase="exact-generation post-wait")
        code = _R23_TABLE.process_exit_code(handle)
        after = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
        if snapshot_observer is not None:
            snapshot_observer(after)
        row = after.by_pid.get(identity[0])
        if row is not None:
            raise _R23_TABLE.ProcessTableError(
                "PID remains in post-wait process table; generation/ancestry ambiguous")
        return {"schema": "vnext-t2-r23-exact-wait-r1", "complete": True,
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "exit_code": code, "wait_confirmed": True,
                "post_table": _r23_snapshot_receipt(after), "errors": []}
    except Exception as error:
        return {"schema": "vnext-t2-r23-exact-wait-r1", "complete": False,
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "wait_confirmed": False, "exit_code": None,
                "errors": [_monitor_error("r23_exact_wait", error, identity[0])],
                **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT}


def _r23_signal_one(identity: tuple[int, int], handle: Any,
                    *, timeout_seconds: float = 8.0) -> dict[str, Any]:
    return _R23_SUPERVISOR.signal_exact_process(
        handle, identity,
        snapshot_provider=_R23_TABLE.query_native_process_table,
        handle_identity_reader=_R23_TABLE.read_process_handle_identity,
        signal_sender=lambda value: _R23_TABLE.terminate_process_handle(value, exit_code=15),
        wait_for_exit=_R23_TABLE.wait_for_process_exit,
        exit_code_reader=_R23_TABLE.process_exit_code,
        timeout_seconds=timeout_seconds)


R20_MAX_WHOLE_SAMPLE_ATTEMPTS = 2


def _r20_native_sample(process: Any, registry: Any,
                       root_identity: tuple[int, int],
                       previous: list[tuple[int, int]], *,
                       sample_index: int, elapsed: float,
                       deadline_monotonic: float,
                       previous_accepted_source_snapshot: Any | None = None,
                       outer_reconcile_snapshot: Any | None = None,
                       outer_reconcile_history_sequence: int | None = None,
                       previous_accepted_sample_index: int | None = None,
                       previous_accepted_source_history_sequence: int | None = None,
                       phase_snapshot_history: list[dict[str, Any]] | None = None,
                       phase_snapshot_witnesses: list[str] | None = None,
                       working_set_limit_bytes: int = AUTHORITY_WORKING_SET_LIMIT_BYTES,
                       completed_source_snapshot_out: list[Any] | None = None,
                       completed_source_snapshot_history_sequence_out:
                           list[int] | None = None,
                       lifecycle_observer: Any | None = None
                       ) -> dict[str, Any]:
    if completed_source_snapshot_out is not None:
        if type(completed_source_snapshot_out) is not list:
            raise _R23_TABLE.ProcessTableError(
                "completed source snapshot output must be a list")
        completed_source_snapshot_out.clear()
    if completed_source_snapshot_history_sequence_out is not None:
        if type(completed_source_snapshot_history_sequence_out) is not list:
            raise _R23_TABLE.ProcessTableError(
                "completed source history sequence output must be a list")
        completed_source_snapshot_history_sequence_out.clear()
    if phase_snapshot_history is not None and type(phase_snapshot_history) is not list:
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot history must be a list")
    if phase_snapshot_history is not None and \
            (type(phase_snapshot_witnesses) is not list or
             len(phase_snapshot_history) != len(phase_snapshot_witnesses)):
        raise _R23_TABLE.ProcessTableError(
            "R23 phase snapshot witness ledger must align with history")
    if type(working_set_limit_bytes) is not int or working_set_limit_bytes <= 0:
        raise _R23_TABLE.ProcessTableError(
            "R23 sample working-set ceiling is malformed")
    recovery_records: list[dict[str, Any]] = []
    tracked_exit_records: list[dict[str, Any]] = []
    pre_tree_exit_records: list[dict[str, Any]] = []
    membership_growth_records: list[dict[str, Any]] = []
    terminal_root_exit_records: list[dict[str, Any]] = []
    descendant_terminal_root_exit_records: list[dict[str, Any]] = []
    lifecycle_boundary_retry_records: list[dict[str, Any]] = []
    retired_after_proof: set[tuple[int, int]] = set()
    final_exact: dict[str, Any] = {}
    final_bound_handles: dict[tuple[int, int], Any] = {}
    attempts_used = 0
    retry_previous_identities: list[tuple[int, int]] | None = None
    sample_started = time.monotonic()
    sample_elapsed = elapsed

    for attempt_index in range(1, R20_MAX_WHOLE_SAMPLE_ATTEMPTS + 1):
        attempts_used = attempt_index
        if time.monotonic() >= deadline_monotonic:
            sample_elapsed = elapsed + max(0.0, time.monotonic() - sample_started)
            final_exact = {
                "schema": "native-g1g2-r23-process-tree-sample-v1",
                "sample_index": sample_index, "complete": False,
                "identity_source":
                    "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
                "processes": [], "discovered_identities": [],
                "measured_identities": [], "partial_rss_bytes": 0,
                "rss_bytes": None,
                "errors": [{"phase": "r20_full_sample_retry",
                    "type": "MonitorIncomplete",
                    "message": "phase budget expired before a fresh full sample"}],
                **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT,
            }
            break

        attempt_state: dict[str, Any] = {
            "first_snapshot": None,
            "snapshot_sequence": [],
            "snapshot_history_sequences": [],
            "handle_identity_receipts": [],
            "unbound_race": None,
            "tracked_exit_race": None,
            "pre_tree_exit_race": None,
            "membership_growth_race": None,
            "terminal_root_exit_race": None,
            "descendant_terminal_root_exit_race": None,
            "tracked_exit_probe_observations": [],
            "tracked_exit_resource_failure": None,
        }
        checkpoint_before: dict[str, Any] = {"complete": False, "error": None}
        if lifecycle_observer is not None:
            try:
                checkpoint_before = {"complete": True,
                                     "value": _r23_lifecycle_membership_checkpoint(
                                         process, lifecycle_observer)}
            except Exception as checkpoint_error:
                checkpoint_before = {"complete": False,
                    "error": _monitor_error("r23_lifecycle_membership_before", checkpoint_error,
                                            root_identity[0])}
        bound_handles: dict[tuple[int, int], Any] = {}
        active_previous = (retry_previous_identities
                           if retry_previous_identities is not None else previous)
        attempt_previous = [identity for identity in active_previous
                            if identity not in retired_after_proof]
        retired_pids = {pid for pid, _ in retired_after_proof}

        def snapshot_provider() -> Any:
            snapshot = _R23_TABLE.validate_snapshot(
                _R23_TABLE.query_native_process_table())
            if retired_pids.intersection(snapshot.by_pid):
                raise _R23_TABLE.ProcessTableError(
                    "PID from a proven-exited subtree reappeared before retry sampling completed")
            if attempt_state["first_snapshot"] is None:
                attempt_state["first_snapshot"] = snapshot
            role_index = len(attempt_state["snapshot_sequence"])
            source_role = ("sample_source_before" if role_index == 0 else
                           "sample_source_after" if role_index == 1 else
                           "sample_source_extra")
            attempt_state["snapshot_sequence"].append(snapshot)
            if phase_snapshot_history is not None:
                attempt_state["snapshot_history_sequences"].append(
                    _r23_append_snapshot_history(
                        phase_snapshot_history, phase_snapshot_witnesses, snapshot,
                        sample_index=sample_index, attempt_index=attempt_index,
                        source_role=source_role))
            return snapshot

        def confirmation_snapshot_provider(
                source_role_prefix: str,
                captured_observations: list[dict[str, Any]] | None = None) -> Any:
            def query() -> Any:
                snapshot = _R23_TABLE.validate_snapshot(
                    _R23_TABLE.query_native_process_table())
                sequence = None
                if phase_snapshot_history is not None:
                    matching = [entry for entry in phase_snapshot_history
                                if entry.get("sample_index") == sample_index and
                                entry.get("attempt_index") == attempt_index and
                                entry.get("source_role", "").startswith(
                                    source_role_prefix)]
                    role = f"{source_role_prefix}_{len(matching) + 1}"
                    sequence = _r23_append_snapshot_history(
                        phase_snapshot_history, phase_snapshot_witnesses, snapshot,
                        sample_index=sample_index, attempt_index=attempt_index,
                        source_role=role)
                if captured_observations is not None:
                    if type(sequence) is not int:
                        raise _R23_TABLE.ProcessTableError(
                            "tracked-exit confirmation query lacks a sealed phase-history sequence")
                    captured_observations.append({
                        "sequence": sequence, "snapshot": snapshot})
                return snapshot
            return query

        def record_tracked_sample_exit(
                identity: tuple[int, int], failure: BaseException, *,
                failure_phase: str, exact_handle: Any | None = None) -> dict[str, Any]:
            source = attempt_state["first_snapshot"]
            probe_observations: list[dict[str, Any]] = []
            handles: dict[tuple[int, int], Any] = {}
            for prior_identity in attempt_previous:
                if prior_identity == root_identity:
                    continue
                handle = bound_handles.get(prior_identity)
                if prior_identity == identity and exact_handle is not None:
                    handle = exact_handle
                if handle is None:
                    try:
                        handle = _r23_handle_for_identity(
                            registry, prior_identity, process)
                    except Exception:
                        continue
                handles[prior_identity] = handle
            record = _r21_confirm_tracked_sample_exit(
                source, identity, root_identity, attempt_previous, handles,
                sample_index=sample_index, attempt_index=attempt_index,
                deadline_monotonic=deadline_monotonic,
                snapshot_provider=confirmation_snapshot_provider(
                    "tracked_exit_absence", probe_observations))
            record["failure_stage"] = failure_phase
            record["sample_failure"] = _monitor_error(
                failure_phase, failure, identity[0])
            record["partial_rss_bytes_not_credited"] = final_exact.get(
                "partial_rss_bytes", 0)
            record["rss_credit_bytes"] = 0
            record["cpu_credit_seconds"] = {"user": 0.0, "system": 0.0}
            record["exit_code_credit_issued"] = False
            attempt_state["tracked_exit_race"] = record
            attempt_state["tracked_exit_probe_observations"] = probe_observations
            attempt_state["tracked_exit_resource_failure"] = failure
            return record

        def record_pre_tree_tracked_exit(failure: BaseException) -> dict[str, Any]:
            handles: dict[tuple[int, int], Any] = {}
            for prior_identity in attempt_previous:
                if prior_identity == root_identity:
                    continue
                try:
                    handles[prior_identity] = _r23_handle_for_identity(
                        registry, prior_identity, process)
                except Exception:
                    # Missing original handles are left absent so the typed
                    # proof records failure; it never opens or signals by PID.
                    continue
            record = _r22_confirm_pre_tree_tracked_exit(
                previous_accepted_source_snapshot,
                outer_reconcile_snapshot,
                attempt_state.get("first_snapshot"),
                root_identity, attempt_previous, handles,
                previous_accepted_sample_index=previous_accepted_sample_index,
                sample_index=sample_index, attempt_index=attempt_index,
                deadline_monotonic=deadline_monotonic,
                partial_rss_bytes=final_exact.get("partial_rss_bytes", 0),
                snapshot_provider=confirmation_snapshot_provider(
                    "pre_tree_exit_absence"))
            record["sample_failure"] = _monitor_error(
                "r22_pre_tree_missing_tracked", failure)
            attempt_state["pre_tree_exit_race"] = record
            return record

        def record_terminal_root_sample_exit(
                failure: BaseException) -> dict[str, Any]:
            handles: dict[tuple[int, int], Any] = {}
            for prior_identity in attempt_previous:
                if prior_identity == root_identity:
                    continue
                try:
                    # This is lookup-only: it returns a previously retained
                    # exact handle or fails, never opening by PID.
                    handles[prior_identity] = _r23_handle_for_identity(
                        registry, prior_identity, process)
                except Exception:
                    continue
            history_sequences = attempt_state.get("snapshot_history_sequences", [])
            source_sequence = (history_sequences[0]
                               if type(history_sequences) is list and history_sequences
                               else None)
            record = _r23_confirm_terminal_root_sample_exit(
                previous_accepted_source_snapshot,
                outer_reconcile_snapshot,
                attempt_state.get("first_snapshot"),
                root_identity, attempt_previous, _r23_root_handle(process), handles,
                bound_handle_identity_receipts=attempt_state.get(
                    "handle_identity_receipts", []),
                sample_index=sample_index, attempt_index=attempt_index,
                previous_accepted_sample_index=previous_accepted_sample_index,
                previous_accepted_source_history_sequence=(
                    previous_accepted_source_history_sequence),
                outer_reconcile_history_sequence=(outer_reconcile_history_sequence),
                source_history_sequence=source_sequence,
                deadline_monotonic=deadline_monotonic,
                resource_failure=failure,
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses,
                snapshot_provider=_R23_TABLE.query_native_process_table)
            record["sample_failure"] = _monitor_error(
                "r23_terminal_root_resource_read_exit", failure, root_identity[0])
            attempt_state["terminal_root_exit_race"] = record
            return record

        def record_descendant_terminal_root_sample_exit(
                r21_record: dict[str, Any], failure: BaseException,
                probe_observations: list[dict[str, Any]],
                partial_rss_bytes: Any) -> dict[str, Any]:
            handles: dict[tuple[int, int], Any] = {}
            receipts: list[dict[str, Any]] = []
            source = _R23_TABLE.validate_snapshot(attempt_state["first_snapshot"])
            source_receipt = _r23_snapshot_receipt(source)
            for identity in attempt_previous:
                if identity == root_identity:
                    handle = _r23_root_handle(process)
                else:
                    handle = bound_handles.get(identity)
                    if handle is None:
                        # Lookup only: the registry must already retain this
                        # exact generation from a prior accepted sample.
                        handle = _r23_handle_for_identity(registry, identity, process)
                exact = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    exact, identity,
                    phase="R23 descendant-terminal captured original handle")
                handles[identity] = handle
                receipts.append({
                    "pid": identity[0],
                    "create_time_100ns": identity[1],
                    "source_snapshot": source_receipt,
                })
            history_sequences = attempt_state.get("snapshot_history_sequences", [])
            source_sequence = (history_sequences[0]
                               if type(history_sequences) is list and history_sequences
                               else None)
            target_value = r21_record.get("target_identity")
            if (
                    type(target_value) is not dict or
                    set(target_value) != {"pid", "create_time_100ns"} or
                    type(target_value["pid"]) is not int or
                    target_value["pid"] <= 0 or
                    type(target_value["create_time_100ns"]) is not int or
                    target_value["create_time_100ns"] <= 0):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal target identity is not strict PID/FILETIME mapping")
            target_identity = _R23_TABLE.validate_identity(
                (target_value["pid"], target_value["create_time_100ns"]))
            record = _r23_confirm_descendant_terminal_root_sample_exit(
                previous_accepted_source_snapshot,
                outer_reconcile_snapshot,
                source,
                root_identity,
                target_identity,
                attempt_previous,
                _r23_root_handle(process),
                handles,
                bound_handle_identity_receipts=receipts,
                sample_index=sample_index,
                attempt_index=attempt_index,
                previous_accepted_sample_index=previous_accepted_sample_index,
                previous_accepted_source_history_sequence=(
                    previous_accepted_source_history_sequence),
                outer_reconcile_history_sequence=(outer_reconcile_history_sequence),
                source_history_sequence=source_sequence,
                r21_probe_record=r21_record,
                r21_probe_observations=probe_observations,
                deadline_monotonic=deadline_monotonic,
                resource_failure=failure,
                partial_rss_bytes=partial_rss_bytes,
                working_set_limit_bytes=working_set_limit_bytes,
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses,
                snapshot_provider=_R23_TABLE.query_native_process_table)
            record["sample_failure"] = _monitor_error(
                "r23_descendant_terminal_resource_read_exit", failure,
                getattr(failure, "pid", None))
            attempt_state["descendant_terminal_root_exit_race"] = record
            return record

        def record_unbound_sample_race(
                identity: tuple[int, int], failure: BaseException, *,
                failure_phase: str, exact_handle_opened: bool = False,
                exact_handle_wait_attempted: bool = False,
                exact_handle_signaled: bool = False,
                exact_handle_identity: tuple[int, int] | None = None) -> dict[str, Any]:
            source = attempt_state["first_snapshot"]
            if source is None:
                raise _R23_TABLE.ProcessTableError(
                    "cannot confirm handle race without the first source snapshot")
            source = _R23_TABLE.validate_snapshot(source)
            fresh_tables: list[Any] = []
            query_error: BaseException | None = None
            for _ in range(3):
                try:
                    if time.monotonic() >= deadline_monotonic:
                        raise TimeoutError(
                            "phase deadline reached during handle-race confirmation")
                    fresh = _R23_TABLE.validate_snapshot(
                        _R23_TABLE.query_native_process_table())
                    fresh_tables.append(fresh)
                    if phase_snapshot_history is not None:
                        _r23_append_snapshot_history(
                            phase_snapshot_history, phase_snapshot_witnesses, fresh,
                            sample_index=sample_index,
                            attempt_index=attempt_index,
                            source_role=f"unbound_confirmation_{len(fresh_tables)}")
                except Exception as error:
                    query_error = error
                    break

            confirmation_tables = fresh_tables[1:3]
            confirmation_tables.extend([None] * (2 - len(confirmation_tables)))
            recovery = _r20_confirm_unbound_sample_race(
                source, identity, root_identity, attempt_previous,
                fresh_tables[0] if fresh_tables else None,
                confirmation_tables,
            )
            recovery["logical_sample_index"] = sample_index
            recovery["whole_sample_attempt_index"] = attempt_index
            recovery["full_sample_completed_after_retry"] = False
            recovery["exact_handle_open_failure"] = _monitor_error(
                failure_phase, failure, identity[0])
            recovery["failure_stage"] = failure_phase
            recovery["exact_handle_opened"] = exact_handle_opened
            recovery["exact_handle_waited"] = exact_handle_wait_attempted
            recovery["exact_handle_already_signaled"] = exact_handle_signaled
            if exact_handle_identity is not None:
                recovery["exact_handle_binding"] = {
                    "identity": {"pid": exact_handle_identity[0],
                                 "create_time_100ns": exact_handle_identity[1]},
                    "source_snapshot": _r23_snapshot_receipt(source),
                    "resource_credit_issued": False,
                    "exit_credit_issued": False,
                }
            if query_error is not None:
                recovery.setdefault("errors", []).append(_monitor_error(
                    "r20_post_failure_snapshot", query_error, identity[0]))
                recovery["complete"] = False
                recovery["status"] = "post_failure_snapshot_incomplete"
            recovery["exact_handle_exit_receipt_created"] = False
            recovery["exit_code_credit_issued"] = False
            recovery["rss_credit_bytes"] = 0
            recovery["cpu_credit_seconds"] = {"user": 0.0, "system": 0.0}
            attempt_state["unbound_race"] = recovery
            return recovery

        def handle_provider(row: Any) -> Any:
            source = attempt_state["first_snapshot"]
            if source is None:
                raise _R23_TABLE.ProcessTableError(
                    "sample row arrived before its complete source snapshot")
            source = _R23_TABLE.validate_snapshot(source)
            identity = _r23_raw_identity(row)
            source_row = source.by_pid.get(identity[0])
            if source_row is None or _r23_raw_identity(source_row) != identity or \
                    source_row.ppid != row.ppid or source_row.name != row.name:
                raise _R23_TABLE.ProcessTableError(
                    "sample row is not bound to its first complete SPI snapshot")

            if lifecycle_observer is not None:
                try:
                    core_identity = _R23_MANAGED_LIFECYCLE.ProcessIdentity(
                        identity[0], identity[1])
                    handle = process.handle_provider(row)
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(handle), identity,
                        phase="managed registry exact birth handle")
                    if identity not in registry.identities:
                        raise _R23_TABLE.ProcessTableError(
                            "managed exact handle is absent from the consumer registry")
                    bound_handles[identity] = handle
                    attempt_state["handle_identity_receipts"].append({
                        "pid": identity[0],
                        "create_time_100ns": identity[1],
                        "source_snapshot": _r23_snapshot_receipt(source),
                        "handle_source": "acknowledged_debug_create_duplicate",
                    })
                    return handle
                except Exception as error:
                    # A missing managed birth is not evidence that a tracked
                    # generation exited. Preserve the monitor failure instead
                    # of routing it through the legacy PID-open recovery lane.
                    raise _R23_TABLE.ProcessTableError(
                        "managed SPI generation lacks its acknowledged exact birth handle") \
                        from error

            handle = None
            exact_handle_opened = False
            exact_handle_wait_attempted = False
            exact_handle_signaled = False
            exact_handle_identity = None
            try:
                # Bind against the exact row from the authoritative before
                # snapshot. The registry opens by PID but independently reads
                # raw PID+FILETIME from that handle before retaining it.
                handle = registry.for_row(row, source)
                exact_handle_opened = True
                exact_handle_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    exact_handle_identity, identity,
                    phase="R20 immediate post-open handle identity")
                attempt_state["handle_identity_receipts"].append({
                    "pid": identity[0],
                    "create_time_100ns": identity[1],
                    "source_snapshot": _r23_snapshot_receipt(source),
                })
                # OpenProcess may still open a process object after Windows has
                # signalled it, while the SPI row vanished before OpenProcess.
                # A bounded native wait distinguishes that case from a live
                # generation before any resource/exit credit is read.
                exact_handle_wait_attempted = True
                already_exited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
                if type(already_exited) is not bool:
                    raise _R23_TABLE.ProcessTableError(
                        "post-open native liveness wait returned a non-boolean result")
                exact_handle_signaled = already_exited
                if already_exited:
                    raise _R23_TABLE.ProcessTableError(
                        "exact process handle was already signaled before resource read")
            except Exception as open_error:
                failure_phase = "r21_exact_tracked_handle_open_or_bind" \
                    if identity in attempt_previous and identity != root_identity else \
                    "r20_exact_handle_open_or_bind"
                if identity in attempt_previous and identity != root_identity:
                    record_tracked_sample_exit(
                        identity, open_error, failure_phase=failure_phase,
                        exact_handle=handle)
                else:
                    record_unbound_sample_race(
                        identity, open_error,
                        failure_phase=failure_phase,
                        exact_handle_opened=exact_handle_opened,
                        exact_handle_wait_attempted=exact_handle_wait_attempted,
                        exact_handle_signaled=exact_handle_signaled,
                        exact_handle_identity=exact_handle_identity)
                raise _R23_TABLE.ProcessTableError(
                    "exact handle acquisition/binding/liveness check failed; discard "
                    "sample and require the appropriate typed native recovery proof") \
                    from open_error
            bound_handles[identity] = handle
            return handle

        def sample_resource_reader(*args: Any, **kwargs: Any) -> dict[str, Any]:
            if lifecycle_observer is not None:
                if len(args) != 3 or set(kwargs) != {
                        "phase", "event_receipt"}:
                    raise _R23_TABLE.ProcessTableError(
                        "managed resource reader call shape is invalid")
                handle, expected_identity, row = args
                if kwargs.get("phase") != "whole_sample" or \
                        not isinstance(kwargs.get("event_receipt"), Mapping):
                    raise _R23_TABLE.ProcessTableError(
                        "managed sample resource context is malformed")
                identity = (expected_identity.pid,
                            expected_identity.creation_time_100ns)
                registered_handle = bound_handles.get(identity)
                if registered_handle is None or registered_handle != handle:
                    raise _R23_TABLE.ProcessTableError(
                        "managed resource read is not bound to the registered exact handle")
                return dict(process.resource_reader(
                    handle, expected_identity, row,
                    phase=kwargs["phase"],
                    event_receipt=kwargs["event_receipt"]))
            if len(args) != 1 or kwargs:
                raise _R23_TABLE.ProcessTableError(
                    "legacy resource reader call shape is invalid")
            pid = args[0]
            try:
                return _r23_resource_reader(pid)
            except Exception as resource_error:
                identity = next((item for item in bound_handles if item[0] == pid), None)
                if identity is None:
                    raise
                handle = bound_handles[identity]
                if identity == root_identity and handle is not _r23_root_handle(process):
                    raise _R23_TABLE.ProcessTableError(
                        "terminal-root resource read is not bound to the original Popen handle") \
                        from resource_error
                exact_handle_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    exact_handle_identity, identity,
                    phase="R20 resource-failure original handle identity")
                already_exited = _R23_TABLE.wait_for_process_exit(handle, 0.001)
                if type(already_exited) is not bool:
                    raise _R23_TABLE.ProcessTableError(
                        "resource-failure liveness wait returned a non-boolean result") \
                        from resource_error
                if not already_exited:
                    raise
                if identity in attempt_previous and identity != root_identity:
                    record_tracked_sample_exit(
                        identity, resource_error,
                        failure_phase="r21_exact_tracked_resource_read_exit",
                        exact_handle=handle)
                elif identity == root_identity and root_identity in attempt_previous and \
                        attempt_index == 1 and \
                        type(previous_accepted_sample_index) is int and \
                        previous_accepted_sample_index > 0 and \
                        handle is _r23_root_handle(process) and \
                        isinstance(resource_error, psutil.NoSuchProcess) and \
                        type(getattr(resource_error, "pid", None)) is int and \
                        resource_error.pid == root_identity[0] and \
                        all(attempt_state.get(key) is None for key in (
                            "unbound_race", "tracked_exit_race",
                            "pre_tree_exit_race", "membership_growth_race",
                            "terminal_root_exit_race")):
                    record_terminal_root_sample_exit(resource_error)
                else:
                    record_unbound_sample_race(
                        identity, resource_error,
                        failure_phase="r20_exact_handle_resource_read_exit",
                        exact_handle_opened=True,
                        exact_handle_wait_attempted=True,
                        exact_handle_signaled=True,
                        exact_handle_identity=exact_handle_identity)
                raise _R23_TABLE.ProcessTableError(
                    "exact generation exited during resource read; discard sample and "
                    "require typed exact-generation recovery") from resource_error

        sample_elapsed = elapsed + max(0.0, time.monotonic() - sample_started)
        final_exact = _R23_SUPERVISOR.sample_process_tree(
            root_identity,
            snapshot_provider=snapshot_provider,
            handle_provider=handle_provider,
            resource_reader=sample_resource_reader,
            handle_identity_reader=_R23_TABLE.read_process_handle_identity,
            previously_tracked=attempt_previous,
            sample_index=sample_index,
            elapsed_seconds=sample_elapsed,
            lifecycle_session=(process if lifecycle_observer is not None else None),
            lifecycle_identity_factory=(
                (lambda identity: _R23_MANAGED_LIFECYCLE.ProcessIdentity(identity[0], identity[1]))
                if lifecycle_observer is not None else None),
            lifecycle_attempt_callback=(
                (lambda attempt_id: lifecycle_observer.set_context(
                    sample_index, attempt_id))
                if lifecycle_observer is not None else None))
        boundary_receipt = final_exact.get("sample_attempt_boundary")
        if lifecycle_observer is not None and isinstance(boundary_receipt, Mapping) and \
                boundary_receipt.get("membership_changed") is True:
            boundary_record = _r23_load_dll_boundary_retry_record(
                process, final_exact, attempt_state,
                lifecycle_observer=lifecycle_observer,
                root_identity=root_identity, sample_index=sample_index,
                attempt_index=attempt_index,
                previously_tracked=attempt_previous,
                outer_reconcile_snapshot=outer_reconcile_snapshot,
                outer_reconcile_history_sequence=outer_reconcile_history_sequence,
                checkpoint_before=checkpoint_before,
                deadline_monotonic=deadline_monotonic,
                phase_snapshot_history=phase_snapshot_history,
                phase_snapshot_witnesses=phase_snapshot_witnesses)
            if boundary_record is not None:
                lifecycle_boundary_retry_records.append(boundary_record)
                retry_seed = boundary_record.get("retry_seed_identities")
                if boundary_record.get("retry_started") is True and retry_seed is not None:
                    if type(retry_seed) is not list:
                        boundary_record["complete"] = False
                        boundary_record["retry_started"] = False
                        boundary_record["errors"].append(_monitor_error(
                            "r23_boundary_retry_seed",
                            RuntimeError("verified boundary retry seed is malformed"),
                            root_identity[0]))
                    else:
                        retry_previous_identities = [
                            _R23_TABLE.validate_identity((
                                item.get("pid"), item.get("create_time_100ns")))
                            for item in retry_seed if isinstance(item, Mapping)]
                        if len(retry_previous_identities) != len(retry_seed) or \
                                len(retry_previous_identities) != len(set(
                                    retry_previous_identities)):
                            boundary_record["complete"] = False
                            boundary_record["retry_started"] = False
                            retry_previous_identities = None
                            boundary_record["errors"].append(_monitor_error(
                                "r23_boundary_retry_seed",
                                RuntimeError(
                                    "verified boundary retry seed is duplicate or invalid"),
                                root_identity[0]))
        terminal_root_race = attempt_state.get("terminal_root_exit_race")
        if terminal_root_race is not None:
            partial_rss = final_exact.get("partial_rss_bytes", 0)
            terminal_root_race["partial_rss_bytes_not_credited"] = partial_rss
            terminal_root_race["sample_failure_monitor_errors"] = copy.deepcopy(
                final_exact.get("errors", []))
            terminal_root_race["rss_credit_bytes"] = 0
            terminal_root_race["cpu_credit_seconds"] = {
                "user": 0.0, "system": 0.0}
            terminal_root_race["exit_code_credit_issued"] = False
            terminal_root_race["sample_complete"] = False
            terminal_root_race["retry_started"] = False
            terminal_root_race["full_sample_completed_after_retry"] = False
            errors = final_exact.get("errors", [])
            exact_resource_exit_error = (
                type(errors) is list and len(errors) == 1 and
                isinstance(errors[0], dict) and
                errors[0].get("message") ==
                    "exact generation exited during resource read; discard sample and "
                    "require typed exact-generation recovery")
            if type(partial_rss) is not int or partial_rss < 0 or \
                    partial_rss >= working_set_limit_bytes:
                terminal_root_race["complete"] = False
                terminal_root_race["status"] = "monitor_incomplete"
                terminal_root_race.setdefault("errors", []).append(_monitor_error(
                    "r23_terminal_root_partial_rss",
                    RuntimeError(
                        "terminal-root partial RSS is malformed or exceeds the phase ceiling"),
                    root_identity[0]))
            if final_exact.get("complete") is True or not exact_resource_exit_error:
                terminal_root_race["complete"] = False
                terminal_root_race["status"] = "monitor_incomplete"
                terminal_root_race.setdefault("errors", []).append(_monitor_error(
                    "r23_terminal_root_sample_error_set",
                    RuntimeError(
                        "terminal-root sample has another error or is not a partial resource sample"),
                    root_identity[0]))
            terminal_root_race["discarded_attempt"] = {
                "sample_index": sample_index,
                "attempt_index": attempt_index,
                "complete": False,
                "sample_complete": False,
                "observed_partial_rss_bytes_not_credited": partial_rss,
                "measured_identities_not_credited": copy.deepcopy(
                    final_exact.get("measured_identities", [])),
                "credited_rss_bytes": 0,
                "credited_cpu_seconds": {"user": 0.0, "system": 0.0},
                "exit_code_credit_issued": False,
                "exact_monitor_receipt": copy.deepcopy(final_exact),
                "errors": copy.deepcopy(errors),
            }
            terminal_root_exit_records.append(terminal_root_race)
            # A process that has exited cannot be sampled again. Keep this
            # terminal partial outside the complete-sample sequence.
            break
        tracked_exit_candidate = attempt_state.get("tracked_exit_race")
        tracked_exit_failure = attempt_state.get("tracked_exit_resource_failure")
        tracked_probe_observations = attempt_state.get(
            "tracked_exit_probe_observations", [])
        source_errors = final_exact.get("errors", [])
        exact_descendant_resource_exit_error = (
            type(source_errors) is list and len(source_errors) == 1 and
            isinstance(source_errors[0], dict) and
            source_errors[0].get("message") ==
                "exact generation exited during resource read; discard sample and "
                "require typed exact-generation recovery")
        exact_descendant_trigger = (
            isinstance(tracked_exit_failure, psutil.NoSuchProcess) and
            isinstance(tracked_exit_candidate, dict) and
            tracked_exit_candidate.get("failure_stage") ==
                "r21_exact_tracked_resource_read_exit" and
            isinstance(tracked_exit_candidate.get("target_identity"), dict) and
            type(getattr(tracked_exit_failure, "pid", None)) is int and
            getattr(tracked_exit_failure, "pid", None) ==
                tracked_exit_candidate["target_identity"].get("pid") and
            type(tracked_probe_observations) is list and
            len(tracked_probe_observations) == 2 and
            attempt_index == 1 and
            type(previous_accepted_sample_index) is int and
            previous_accepted_sample_index == sample_index - 1 and
            all(attempt_state.get(key) is None for key in (
                "unbound_race", "pre_tree_exit_race", "membership_growth_race",
                "terminal_root_exit_race", "descendant_terminal_root_exit_race")))
        if final_exact.get("complete") is False and \
                exact_descendant_resource_exit_error and exact_descendant_trigger:
            # This is the same terminal status the unchanged R21 failure
            # path would assign after exhausting its one proof; retain it
            # unchanged as the nested handoff observation.
            tracked_exit_candidate["status"] = \
                "tracked_exit_unconfirmed_monitor_incomplete"
            terminal_descendant_race = record_descendant_terminal_root_sample_exit(
                tracked_exit_candidate, tracked_exit_failure,
                tracked_probe_observations,
                final_exact.get("partial_rss_bytes", 0))
            if terminal_descendant_race.get("complete") is True:
                # Preserve the original R21 failure verbatim inside the
                # distinct terminal handoff. It is not a recovered R21 race.
                attempt_state["tracked_exit_race"] = None
                terminal_descendant_race["partial_rss_bytes_not_credited"] = \
                    final_exact.get("partial_rss_bytes", 0)
                terminal_descendant_race["sample_failure_monitor_errors"] = \
                    copy.deepcopy(final_exact.get("errors", []))
                partial_rss = terminal_descendant_race[
                    "partial_rss_bytes_not_credited"]
                if type(partial_rss) is not int or partial_rss < 0 or \
                        partial_rss >= working_set_limit_bytes:
                    terminal_descendant_race["complete"] = False
                    terminal_descendant_race["status"] = "monitor_incomplete"
                    terminal_descendant_race.setdefault("errors", []).append(
                        _monitor_error(
                            "r23_descendant_terminal_partial_rss",
                            RuntimeError(
                                "descendant-terminal partial RSS is malformed or reaches the phase ceiling"),
                            root_identity[0]))
                terminal_descendant_race["discarded_attempt"] = {
                    "sample_index": sample_index,
                    "attempt_index": attempt_index,
                    "complete": False,
                    "sample_complete": False,
                    "observed_partial_rss_bytes_not_credited": partial_rss,
                    "measured_identities_not_credited": copy.deepcopy(
                        final_exact.get("measured_identities", [])),
                    "credited_rss_bytes": 0,
                    "credited_cpu_seconds": {"user": 0.0, "system": 0.0},
                    "exit_code_credit_issued": False,
                    "exact_monitor_receipt": copy.deepcopy(final_exact),
                    "errors": copy.deepcopy(final_exact.get("errors", [])),
                }
                descendant_terminal_root_exit_records.append(
                    terminal_descendant_race)
                final_bound_handles = bound_handles
                # This is a terminal disposition, never a successful R21
                # retry and never a completed resource sample.
                break
        if final_exact.get("complete") is not True and \
                attempt_state.get("unbound_race") is None and \
                attempt_state.get("tracked_exit_race") is None and \
                attempt_state.get("pre_tree_exit_race") is None and \
                attempt_state.get("membership_growth_race") is None and \
                attempt_state.get("terminal_root_exit_race") is None:
            source = attempt_state.get("first_snapshot")
            source_errors = final_exact.get("errors", [])
            missing_tracked_error = any(
                isinstance(error, dict) and
                error.get("message") ==
                    "previously tracked process is missing; exit receipt required"
                for error in source_errors)
            if missing_tracked_error and source is not None:
                try:
                    failed_table = _R23_TABLE.validate_snapshot(source)
                    failed_root = failed_table.by_pid.get(root_identity[0])
                    has_missing_nonroot = any(
                        identity != root_identity and
                        identity[0] not in failed_table.by_pid
                        for identity in attempt_previous)
                    if failed_root is not None and \
                            _r23_raw_identity(failed_root) == root_identity and \
                            has_missing_nonroot:
                        record_pre_tree_tracked_exit(
                            _R23_TABLE.ProcessTableError(
                                "previously tracked process disappeared before tree enumeration"))
                except Exception:
                    # The original incomplete sample remains authoritative;
                    # malformed or unavailable source evidence is never rescued.
                    pass
        if final_exact.get("complete") is not True and \
                attempt_state.get("unbound_race") is None and \
                attempt_state.get("tracked_exit_race") is None and \
                attempt_state.get("pre_tree_exit_race") is None and \
                attempt_state.get("membership_growth_race") is None and \
                attempt_state.get("terminal_root_exit_race") is None:
            for identity, handle in bound_handles.items():
                try:
                    exact_handle_identity = _R23_TABLE.validate_identity(
                        _R23_TABLE.read_process_handle_identity(handle))
                    _R23_TABLE.require_same_identity(
                        exact_handle_identity, identity,
                        phase="R20 incomplete-sample original handle identity")
                    signaled_after_sample = _R23_TABLE.wait_for_process_exit(
                        handle, 0.001)
                except Exception:
                    continue
                if type(signaled_after_sample) is bool and signaled_after_sample:
                    sample_failure = _R23_TABLE.ProcessTableError(
                        "exact process handle signaled before sample completion")
                    if identity in attempt_previous and identity != root_identity:
                        record_tracked_sample_exit(
                            identity, sample_failure,
                            failure_phase="r21_tracked_exact_handle_post_sample_exit",
                            exact_handle=handle)
                    else:
                        record_unbound_sample_race(
                            identity, sample_failure,
                            failure_phase="r20_exact_handle_post_sample_exit",
                            exact_handle_opened=True,
                            exact_handle_wait_attempted=True,
                            exact_handle_signaled=True,
                            exact_handle_identity=exact_handle_identity)
                    break
        final_bound_handles = bound_handles

        membership_error = any(
            isinstance(error, dict) and error.get("message") ==
                "process tree membership/generation changed during sample"
            for error in final_exact.get("errors", []))
        if final_exact.get("complete") is not True and membership_error and \
                attempt_state.get("unbound_race") is None and \
                attempt_state.get("tracked_exit_race") is None and \
                attempt_state.get("pre_tree_exit_race") is None and \
                attempt_state.get("terminal_root_exit_race") is None:
            snapshots = attempt_state.get("snapshot_sequence", [])
            history_sequences = attempt_state.get(
                "snapshot_history_sequences", [])
            if type(snapshots) is list and len(snapshots) == 2 and \
                    type(history_sequences) is list and \
                    len(history_sequences) == 2 and \
                    phase_snapshot_history is not None and \
                    type(outer_reconcile_history_sequence) is int:
                growth = _r23_confirm_membership_growth(
                    previous_accepted_source_snapshot,
                    outer_reconcile_snapshot,
                    snapshots[0], snapshots[1], root_identity,
                    attempt_previous,
                    previous_accepted_sample_index=previous_accepted_sample_index,
                    sample_index=sample_index, attempt_index=attempt_index,
                    phase_snapshot_history=phase_snapshot_history,
                    phase_snapshot_witnesses=phase_snapshot_witnesses,
                    previous_accepted_source_history_sequence=(
                        previous_accepted_source_history_sequence),
                    outer_reconcile_history_sequence=(
                        outer_reconcile_history_sequence),
                    failed_attempt_before_history_sequence=history_sequences[0],
                    failed_attempt_after_history_sequence=history_sequences[1],
                    deadline_monotonic=deadline_monotonic,
                    partial_rss_bytes=final_exact.get("partial_rss_bytes", 0),
                    exact_monitor_receipt=final_exact)
            else:
                growth = {
                    "schema": "vnext-t2-r23-membership-growth-r2",
                    "complete": False, "growth_verified": False,
                    "status": "membership_growth_source_incomplete",
                    "sample_index": sample_index,
                    "attempt_index": attempt_index,
                    "root_identity": {"pid": root_identity[0],
                                      "create_time_100ns": root_identity[1]},
                    "previously_tracked_identities": [
                        {"pid": pid, "create_time_100ns": ticks}
                        for pid, ticks in sorted(attempt_previous)],
                    "observed_generations": [],
                    "partial_rss_bytes_not_credited": final_exact.get(
                        "partial_rss_bytes", 0),
                    "rss_credit_bytes": 0,
                    "cpu_credit_seconds": {"user": 0.0, "system": 0.0},
                    "exit_code_credit_issued": False,
                    "exact_handle_exit_receipt_created": False,
                    "retry_started": False,
                    "full_sample_completed_after_retry": False,
                    "fresh_final_binding": None,
                    "snapshot_history_binding": None,
                    "errors": [_monitor_error(
                        "r23_membership_growth_confirmation",
                        RuntimeError("membership-change sample lacks complete ordered source/history proofs"))],
                }
            growth["sample_failure"] = _monitor_error(
                "r23_membership_growth_sample", RuntimeError(
                    "process tree membership/generation changed during sample"))
            attempt_state["membership_growth_race"] = growth

        if final_exact.get("complete") is True and attempt_index > 1:
            pending_growth = [record for record in membership_growth_records
                if record.get("growth_verified") is True and
                   record.get("full_sample_completed_after_retry") is not True]
            if pending_growth:
                snapshots = attempt_state.get("snapshot_sequence", [])
                history_sequences = attempt_state.get(
                    "snapshot_history_sequences", [])
                binding_ok = type(snapshots) is list and len(snapshots) == 2 and \
                    type(history_sequences) is list and len(history_sequences) == 2 and \
                    phase_snapshot_history is not None
                for record in pending_growth:
                    if not binding_ok or not _r23_bind_membership_growth_retry(
                            record, snapshots[0], snapshots[1], final_exact,
                            attempt_state.get("handle_identity_receipts", []),
                            phase_snapshot_history=phase_snapshot_history,
                            phase_snapshot_witnesses=phase_snapshot_witnesses,
                            retry_before_history_sequence=history_sequences[0],
                            retry_after_history_sequence=history_sequences[1]):
                        binding_ok = False
                if not binding_ok:
                    final_exact["complete"] = False
                    final_exact["rss_bytes"] = None
                    final_exact["errors"] = [*final_exact.get("errors", []),
                        _monitor_error(
                            "r23_membership_growth_retry_binding",
                            RuntimeError("fresh retry did not bind every observed generation with exact resources"))]

        tracked_race = attempt_state.get("tracked_exit_race")
        pre_tree_race = attempt_state.get("pre_tree_exit_race")
        membership_growth_race = attempt_state.get("membership_growth_race")
        race = (tracked_race or pre_tree_race or
                attempt_state.get("unbound_race") or membership_growth_race)
        if race is None:
            if final_exact.get("complete") is True:
                for record in [*recovery_records, *tracked_exit_records,
                               *pre_tree_exit_records,
                               *lifecycle_boundary_retry_records]:
                    record["full_sample_completed_after_retry"] = True
                    record["full_sample_attempt_index"] = attempt_index
                    record["status"] = "recovered_by_new_complete_whole_sample"
                    nested = record.get("r21_exact_exit_proof")
                    if isinstance(nested, dict):
                        nested["retry_started"] = True
                        nested["full_sample_completed_after_retry"] = True
                        nested["full_sample_attempt_index"] = attempt_index
                        nested["status"] = "recovered_by_new_complete_whole_sample"
            elif lifecycle_boundary_retry_records and \
                    lifecycle_boundary_retry_records[-1].get("attempt_index") == attempt_index:
                boundary_record = lifecycle_boundary_retry_records[-1]
                if boundary_record.get("retry_started") is True:
                    continue
            break

        discarded = {
            "sample_index": sample_index,
            "attempt_index": attempt_index,
            "sample_complete": False,
            "observed_partial_rss_bytes_not_credited":
                final_exact.get("partial_rss_bytes", 0),
            "measured_identities_not_credited": final_exact.get(
                "measured_identities", []),
            "credited_rss_bytes": 0,
            "credited_cpu_seconds": {"user": 0.0, "system": 0.0},
            "exit_code_credit_issued": False,
            "exact_handle_exit_receipt_created": False,
            "exact_monitor_receipt": copy.deepcopy(final_exact),
            "errors": final_exact.get("errors", []),
        }
        race["discarded_attempt"] = discarded
        if tracked_race is not None or pre_tree_race is not None:
            race["partial_rss_bytes_not_credited"] = final_exact.get(
                "partial_rss_bytes", 0)
            race["rss_credit_bytes"] = 0
            race["cpu_credit_seconds"] = {"user": 0.0, "system": 0.0}
            race["exit_code_credit_issued"] = False
        can_retry = race.get("complete") is True and \
            attempt_index < R20_MAX_WHOLE_SAMPLE_ATTEMPTS and \
            time.monotonic() < deadline_monotonic
        race["retry_started"] = can_retry
        nested = race.get("r21_exact_exit_proof")
        if isinstance(nested, dict):
            nested["retry_started"] = can_retry
        if can_retry:
            if tracked_race is not None or pre_tree_race is not None:
                retired = {_R23_TABLE.validate_identity((
                    item.get("pid"), item.get("create_time_100ns")))
                    for item in race.get("retired_tracked_identities", [])
                    if isinstance(item, dict)}
                if not retired or not retired.issubset(set(attempt_previous)):
                    race["retry_started"] = False
                    race["complete"] = False
                    race["status"] = "tracked_exit_identity_inventory_invalid"
                    race["errors"].append(_monitor_error(
                        "r22_tracked_sample_exit_retry" if pre_tree_race is not None else
                        "r21_tracked_sample_exit_retry",
                        RuntimeError("retired identities are not a subset of active tracked generations")))
                    (pre_tree_exit_records if pre_tree_race is not None else
                     tracked_exit_records).append(race)
                    break
                retired_after_proof.update(retired)
                (pre_tree_exit_records if pre_tree_race is not None else
                 tracked_exit_records).append(race)
            elif membership_growth_race is not None:
                membership_growth_race["retry_started"] = True
                membership_growth_records.append(membership_growth_race)
            else:
                recovery_records.append(race)
            continue
        race["status"] = ("tracked_exit_unconfirmed_monitor_incomplete"
                          if (tracked_race is not None or pre_tree_race is not None) and
                          race.get("complete") is not True else
                          "unbound_absence_unconfirmed_monitor_incomplete"
                          if race.get("complete") is not True else
                          "retry_exhausted_or_phase_deadline_monitor_incomplete")
        race["full_sample_completed_after_retry"] = False
        if membership_growth_race is not None:
            membership_growth_race["complete"] = False
        nested = race.get("r21_exact_exit_proof")
        if isinstance(nested, dict):
            nested["retry_started"] = race.get("retry_started")
            nested["full_sample_completed_after_retry"] = False
        if tracked_race is not None or pre_tree_race is not None:
            (pre_tree_exit_records if pre_tree_race is not None else
             tracked_exit_records).append(race)
        elif membership_growth_race is not None:
            membership_growth_race["retry_started"] = False
            membership_growth_records.append(membership_growth_race)
        else:
            recovery_records.append(race)
        break

    rows = []
    for row in final_exact.get("processes", []):
        identity = _R23_TABLE.validate_identity(
            (row.get("pid"), row.get("create_time_100ns")))
        rows.append({
            "pid": identity[0],
            "create_time": _R23_TABLE.display_seconds(identity[1]),
            "create_time_100ns": identity[1],
            "working_set_bytes": row.get("rss_bytes"),
            "user_cpu_seconds": row.get("cpu_user_seconds"),
            "system_cpu_seconds": row.get("cpu_system_seconds"),
            "name": row.get("name"),
            "ppid": row.get("ppid"),
            "cmdline": row.get("cmdline"),
        })
    all_race_records = [*recovery_records, *tracked_exit_records,
                        *pre_tree_exit_records, *membership_growth_records,
                        *lifecycle_boundary_retry_records,
                        *terminal_root_exit_records,
                        *descendant_terminal_root_exit_records]
    retryable_race_records = [*recovery_records, *tracked_exit_records,
                              *pre_tree_exit_records, *membership_growth_records,
                              *[record for record in lifecycle_boundary_retry_records
                                if record.get("complete") is not True or
                                   record.get("retry_started") is True]]
    complete = final_exact.get("complete") is True and all(
        record.get("full_sample_completed_after_retry") is True
        for record in all_race_records)
    no_credit_after_race = bool(all_race_records) and not complete
    if no_credit_after_race:
        rows = []
    sample = {
        "schema": "vnext-t2-process-tree-sample-r6-r23-membership-growth",
        "observed_utc": utc(), "sample_complete": complete,
        "identity_authority": final_exact.get("identity_source"),
        "sample_index": sample_index,
        "sample_attempt_count": attempts_used,
        "elapsed_supervision_seconds": sample_elapsed,
        "root_process_identity": {"pid": root_identity[0],
                                   "create_time_100ns": root_identity[1],
                                   "create_time": _R23_TABLE.display_seconds(root_identity[1])},
        "root_identity_match_count": sum(
            row.get("pid") == root_identity[0] and
            row.get("create_time_100ns") == root_identity[1] for row in rows),
        "expected_process_count": len(final_exact.get("discovered_identities", [])),
        "observed_process_count": len(rows),
        "errors": final_exact.get("errors", []),
        "process_tree_working_set_bytes": (0 if no_credit_after_race else
            final_exact.get("rss_bytes") if complete else
            final_exact.get("partial_rss_bytes", 0)),
        "process_tree_user_cpu_seconds": (0.0 if no_credit_after_race else sum(
            row["user_cpu_seconds"] for row in rows)),
        "process_tree_system_cpu_seconds": (0.0 if no_credit_after_race else sum(
            row["system_cpu_seconds"] for row in rows)),
        "processes": rows,
        "exact_monitor_receipt": final_exact,
        "native_monitor_handles_bound": len(final_bound_handles),
        "sample_handoff_recoveries": recovery_records,
        "tracked_sample_exit_races": tracked_exit_records,
        "pre_tree_tracked_exit_races": pre_tree_exit_records,
        "membership_growth_records": membership_growth_records,
        "lifecycle_event_boundary_retries": lifecycle_boundary_retry_records,
        "terminal_root_sample_exit_races": terminal_root_exit_records,
        "descendant_terminal_root_sample_exit_races":
            descendant_terminal_root_exit_records,
        "membership_growth_observed_generations": [
            item for record in membership_growth_records
            for item in record.get("observed_generations", [])],
        "unbound_observed_generations": [item for record in recovery_records
            for item in record.get("observed_generations", [])],
    }
    if retryable_race_records and no_credit_after_race:
        sample["errors"] = [*sample["errors"], {
            "phase": "r21_sample_race_recovery",
            "type": "MonitorIncomplete",
            "message": ("discarded lifecycle debug-event boundary was not followed by a complete new whole sample"
                if lifecycle_boundary_retry_records else
                "transient generation was not followed by a complete new sample")}]
    if complete and sample["root_identity_match_count"] != 1:
        sample["sample_complete"] = False
        sample["errors"] = [*sample["errors"], {
            "phase": "r20_root_site_count", "type": "RuntimeError",
            "message": "complete exact sample must contain exactly one root"}]
        complete = False
    if completed_source_snapshot_out is not None:
        source = attempt_state.get("first_snapshot")
        history_sequences = attempt_state.get("snapshot_history_sequences", [])
        if complete and (source is None or phase_snapshot_history is None or
                         type(history_sequences) is not list or not history_sequences or
                         completed_source_snapshot_history_sequence_out is None):
            sample["sample_complete"] = False
            sample["errors"] = [*sample["errors"], {
                "phase": "r22_completed_source_capture",
                "type": "MonitorIncomplete",
                "message": "complete sample lacks its exact first SPI source-history binding"}]
            sample["process_tree_working_set_bytes"] = 0
            sample["process_tree_user_cpu_seconds"] = 0.0
            sample["process_tree_system_cpu_seconds"] = 0.0
            sample["processes"] = []
        elif complete:
            validated_source = _R23_TABLE.validate_snapshot(source)
            source_sequence = history_sequences[0]
            sample["completed_source_history_sequence"] = source_sequence
            sample["completed_source_history_reference"] = (
                _r23_snapshot_history_reference(
                    phase_snapshot_history, phase_snapshot_witnesses,
                    source_sequence, validated_source,
                    sample_index=sample_index, attempt_index=attempts_used,
                    source_role="sample_source_before"))
            completed_source_snapshot_out.append(validated_source)
            completed_source_snapshot_history_sequence_out.append(source_sequence)
    return sample


def _r23_reconcile_missing_tracked(tracked: set[tuple[int, int]],
                                   registry: Any, process: Any,
                                   snapshot: Any, *,
                                   snapshot_observer: Any | None = None
                                   ) -> tuple[list[tuple[int, int]], list[dict[str, Any]]]:
    table = _R23_TABLE.validate_snapshot(snapshot)
    active: list[tuple[int, int]] = []
    exits: list[dict[str, Any]] = []
    for identity in sorted(tracked):
        row = table.by_pid.get(identity[0])
        if row is not None:
            current = _r23_raw_identity(row)
            if current != identity:
                raise _R23_TABLE.ProcessTableError(
                    "tracked PID generation changed during exact sample interval")
            active.append(identity)
            continue
        handle = _r23_handle_for_identity(registry, identity, process)
        receipt = _r23_wait_gone(
            identity, handle, timeout_seconds=0.01,
            snapshot_observer=snapshot_observer)
        if receipt.get("complete") is not True:
            raise _R23_TABLE.ProcessTableError(
                "missing tracked identity lacks a complete same-handle exit receipt")
        exits.append(receipt)
    return active, exits


def _r23_audit_and_cleanup(process: Any, registry: Any,
                           root_identity: tuple[int, int],
                           tracked: set[tuple[int, int]],
                           root_exit_confirmed: bool,
                           unbound_observation_records: list[dict[str, Any]] | None = None,
                           tracked_sample_exit_records: list[dict[str, Any]] | None = None,
                           pre_tree_tracked_exit_records: list[dict[str, Any]] | None = None,
                           membership_growth_records: list[dict[str, Any]] | None = None,
                           terminal_root_sample_exit_records: list[dict[str, Any]] | None = None,
                           descendant_terminal_root_sample_exit_records:
                               list[dict[str, Any]] | None = None,
                           completed_samples: Any = None,
                           terminal_partial_sample: Any = None,
                           lifecycle_session: Any | None = None,
                           working_set_limit_bytes: int = AUTHORITY_WORKING_SET_LIMIT_BYTES,
                           phase_snapshot_history: list[dict[str, Any]] | None = None,
                           phase_snapshot_witnesses: Any = None
                           ) -> tuple[dict[str, Any], dict[str, Any] | None]:
    termination: dict[str, Any] | None = None
    actions: list[dict[str, Any]] = []
    unbound_records = (unbound_observation_records
                       if unbound_observation_records is not None else [])
    growth_records = (membership_growth_records
                      if membership_growth_records is not None else [])
    cleanup_observation_records = [*unbound_records, *growth_records]
    growth_observed_rows, growth_inventory_errors = _r20_unbound_observed_rows(
        growth_records)
    managed_debug_exit_drain: dict[str, Any] | None = None
    if lifecycle_session is not None:
        managed_debug_exit_drain = {
            "schema": "vnext-t2-r23-managed-debug-exit-drain-r1",
            "attempted": False, "terminate_sent": False,
            "root_wait_returncode": None, "exit_proof_complete": False,
            "root_exit_receipt": None, "session_summary": None,
            "complete": False, "errors": [],
            **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT,
        }
        try:
            before_summary = dict(lifecycle_session.summary())
            released_startup = any(
                isinstance(item, Mapping) and
                item.get("event") == "root_startup_barrier_released"
                for item in before_summary.get("event_receipts", []))
            if released_startup and lifecycle_session.exit_proof_complete is not True:
                managed_debug_exit_drain["attempted"] = True
                lifecycle_session.terminate(exit_code=15)
                managed_debug_exit_drain["terminate_sent"] = True
                wait_deadline = time.monotonic() + 8.0
                try:
                    managed_debug_exit_drain["root_wait_returncode"] = \
                        lifecycle_session.wait(timeout=8.0)
                except Exception as wait_error:
                    managed_debug_exit_drain["errors"].append(_monitor_error(
                        "r23_managed_debug_exit_root_wait", wait_error,
                        root_identity[0]))
                while lifecycle_session.exit_proof_complete is not True and \
                        time.monotonic() < wait_deadline:
                    events = lifecycle_session.pump_debug_events(max_events=1024)
                    if not events:
                        time.sleep(min(0.01, max(0.0, wait_deadline - time.monotonic())))
            after_summary = dict(lifecycle_session.summary())
            managed_debug_exit_drain["session_summary"] = after_summary
            managed_debug_exit_drain["exit_proof_complete"] = (
                lifecycle_session.exit_proof_complete is True)
            root_exit_receipts = [item for item in after_summary.get("exit_receipts", [])
                                  if isinstance(item, Mapping) and
                                  item.get("identity") == {
                                      "pid": root_identity[0],
                                      "creation_time_100ns": root_identity[1]}]
            if len(root_exit_receipts) == 1:
                managed_debug_exit_drain["root_exit_receipt"] = \
                    copy.deepcopy(root_exit_receipts[0])
            root_exit_confirmed = (
                len(root_exit_receipts) == 1 and
                root_exit_receipts[0].get("exit_proof_complete") is True and
                root_exit_receipts[0].get("resource_measurement_complete") is True and
                type(root_exit_receipts[0].get("retained_handle_exit_code")) is int and
                root_exit_receipts[0].get("retained_handle_exit_code") != 259 and
                root_exit_receipts[0].get("duplicate_handle_wait_result") == 0 and
                root_exit_receipts[0].get("debug_event_pid") == root_identity[0] and
                root_exit_receipts[0].get("debug_event_exit_code") ==
                    root_exit_receipts[0].get("retained_handle_exit_code"))
            managed_debug_exit_drain["complete"] = (
                root_exit_confirmed and
                managed_debug_exit_drain["exit_proof_complete"] is True)
            if managed_debug_exit_drain["complete"]:
                root_exit_confirmed = True
            elif not released_startup:
                managed_debug_exit_drain["errors"].append(_monitor_error(
                    "r23_managed_debug_exit_drain",
                    RuntimeError("startup CREATE barrier remains held; abort receipt required"),
                    root_identity[0]))
            elif not managed_debug_exit_drain["errors"]:
                managed_debug_exit_drain["errors"].append(_monitor_error(
                    "r23_managed_debug_exit_drain",
                    RuntimeError("managed Job did not produce complete exact debug EXIT receipts"),
                    root_identity[0]))
        except Exception as drain_error:
            managed_debug_exit_drain["errors"].append(_monitor_error(
                "r23_managed_debug_exit_drain", drain_error, root_identity[0]))
            try:
                managed_debug_exit_drain["session_summary"] = dict(
                    lifecycle_session.summary())
                managed_debug_exit_drain["exit_proof_complete"] = (
                    lifecycle_session.exit_proof_complete is True)
            except Exception as summary_error:
                managed_debug_exit_drain["errors"].append(_monitor_error(
                    "r23_managed_debug_exit_summary", summary_error,
                    root_identity[0]))

    def signal_cleanup_target(identity: tuple[int, int], handle: Any) -> dict[str, Any]:
        if lifecycle_session is not None and managed_debug_exit_drain is not None and \
                managed_debug_exit_drain.get("complete") is not True:
            return {"schema": "native-g1g2-r23-exit-receipt-v1",
                    "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                    "signal_sent": False, "wait_confirmed": False, "exit_code": None,
                    "complete": False,
                    "failure": {"type": "LifecycleError",
                        "message": "native wait withheld because managed debug EXIT drain is incomplete"},
                    **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT}
        return _r23_signal_one(identity, handle)

    initial = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
    try:
        residual_rows = _r23_descendants_after_leader(initial, root_identity)
    except _R23_TABLE.ProcessTableError as error:
        # A still-live exact root is not a post-exit residual scan; defer to the
        # final audit, which records it as incomplete and never grants acceptance.
        residual_rows = []
        if "generation remains" not in str(error):
            actions.append({"complete": False, "error": _monitor_error(
                "r23_initial_residual_scan", error, root_identity[0])})
    targets: dict[tuple[int, int], Any] = {}
    target_sources: dict[tuple[int, int], list[str]] = {}
    for row in residual_rows:
        identity = _r23_raw_identity(row)
        handle = registry.for_row(row, initial)
        targets[identity] = handle
        target_sources.setdefault(identity, []).append("stage_root_residual")
        tracked.add(identity)
    root_row = initial.by_pid.get(root_identity[0])
    if root_row is not None and _r23_raw_identity(root_row) == root_identity:
        targets[root_identity] = _r23_root_handle(process)
        target_sources.setdefault(root_identity, []).append("stage_root")
        tracked.add(root_identity)

    # The exact root is handled through its original Popen handle. Every
    # syntactically valid observed generation remains a cleanup candidate,
    # including previously tracked identities; the registry revalidates any
    # cached handle against the same raw PID+FILETIME before signalling.
    protected_identities = {_R23_TABLE.validate_identity(root_identity)}
    unbound_plan = _r20_unbound_cleanup_plan(
        initial, cleanup_observation_records, protected_identities)
    unbound_plan["membership_growth_observed_generations"] = [
        {"pid": identity[0], "create_time_100ns": identity[1],
         "ppid": row["ppid"], "name": row["name"]}
        for identity, row in sorted(growth_observed_rows.items())]
    unbound_plan["membership_growth_inventory_errors"] = growth_inventory_errors
    unbound_plan["membership_growth_record_count"] = len(growth_records)
    membership_growth_exact_exit_receipts: list[dict[str, Any]] = []
    if growth_inventory_errors:
        unbound_plan.setdefault("errors", []).extend(growth_inventory_errors)
        unbound_plan["complete"] = False
    # An observed growth generation that disappeared before any fresh complete
    # retry was bound has no safe cleanup authority unless its exact handle was
    # already bound; cached handles must still prove a signaled natural exit.
    cached_registry_identities = set(getattr(registry, "identities", ()))
    for identity, observed_row in sorted(growth_observed_rows.items()):
        current = initial.by_pid.get(identity[0])
        if current is None and identity not in cached_registry_identities:
            unresolved = {"pid": identity[0],
                "expected_create_time_100ns": identity[1],
                "observed_create_time_100ns": None,
                "reason": "membership_growth_absent_without_exact_bound_handle"}
            if unresolved not in unbound_plan.setdefault("unresolved", []):
                unbound_plan["unresolved"].append(unresolved)
            unbound_plan["complete"] = False
        elif current is None:
            exit_receipt: dict[str, Any] = {
                "schema": "vnext-t2-r23-membership-growth-exact-exit-cleanup-r1",
                "complete": False,
                "identity": {"pid": identity[0],
                             "create_time_100ns": identity[1]},
                "handle_identity_before_wait": None,
                "handle_identity_after_wait": None,
                "exact_wait_receipt": None,
                "exit_code": None,
                "exit_code_credit_issued": False,
                "errors": [],
            }
            try:
                handle = _r23_handle_for_identity(registry, identity, process)
                before_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    before_identity, identity,
                    phase="R23 membership-growth cleanup pre-wait handle")
                exit_receipt["handle_identity_before_wait"] = {
                    "pid": before_identity[0],
                    "create_time_100ns": before_identity[1]}
                wait_receipt = _r23_wait_gone(
                    identity, handle, timeout_seconds=0.001)
                exit_receipt["exact_wait_receipt"] = wait_receipt
                after_identity = _R23_TABLE.validate_identity(
                    _R23_TABLE.read_process_handle_identity(handle))
                _R23_TABLE.require_same_identity(
                    after_identity, identity,
                    phase="R23 membership-growth cleanup post-wait handle")
                exit_receipt["handle_identity_after_wait"] = {
                    "pid": after_identity[0],
                    "create_time_100ns": after_identity[1]}
                exit_code = wait_receipt.get("exit_code")
                exit_receipt["exit_code"] = exit_code
                if wait_receipt.get("complete") is not True or \
                        wait_receipt.get("wait_confirmed") is not True or \
                        wait_receipt.get("errors") != [] or \
                        type(exit_code) is not int or exit_code == 259:
                    raise _R23_TABLE.ProcessTableError(
                        "cached exact growth handle lacks a signaled non-STILL_ACTIVE exit receipt")
                exit_receipt["complete"] = True
            except Exception as error:
                exit_receipt["errors"].append(_monitor_error(
                    "r23_membership_growth_cleanup_exact_exit", error,
                    identity[0]))
                unresolved = {"pid": identity[0],
                    "expected_create_time_100ns": identity[1],
                    "observed_create_time_100ns": None,
                    "reason": "membership_growth_cached_handle_exit_unconfirmed"}
                if unresolved not in unbound_plan.setdefault("unresolved", []):
                    unbound_plan["unresolved"].append(unresolved)
                unbound_plan["complete"] = False
            membership_growth_exact_exit_receipts.append(exit_receipt)
        elif current is not None and _r23_raw_identity(current) != identity:
            # The base cleanup plan records PID reuse as unresolved. This
            # explicit inventory marker keeps the R23 growth provenance visible.
            unbound_plan.setdefault("membership_growth_pid_reuse", []).append({
                "pid": identity[0],
                "expected_create_time_100ns": identity[1],
                "observed_create_time_100ns": current.identity.create_time_100ns})
            unbound_plan["complete"] = False
    unbound_plan["membership_growth_exact_exit_receipts"] = \
        membership_growth_exact_exit_receipts
    unbound_target_ids: set[tuple[int, int]] = set()
    unbound_open_failures: list[dict[str, Any]] = []
    for target in unbound_plan.get("targets", []):
        try:
            identity = _R23_TABLE.validate_identity((
                target.get("pid"), target.get("create_time_100ns")))
            unbound_target_ids.add(identity)
            if identity in targets:
                target_sources.setdefault(identity, []).append(target["provenance"])
                continue
            row = initial.by_pid.get(identity[0])
            if row is None or _r23_raw_identity(row) != identity:
                raise _R23_TABLE.ProcessTableError(
                    "unbound cleanup target changed generation before exact handle open")
            handle = registry.for_row(row, initial)
            targets[identity] = handle
            target_sources.setdefault(identity, []).append(target["provenance"])
        except Exception as error:
            unbound_open_failures.append({
                "identity": {"pid": target.get("pid"),
                             "create_time_100ns": target.get("create_time_100ns")},
                "source": target.get("provenance"),
                "receipt": {"schema": "vnext-t2-r20-unbound-cleanup-action-r1",
                            "complete": False, "signal_sent": False,
                            "wait_confirmed": False, "exit_code": None,
                            "errors": [_monitor_error(
                                "r20_unbound_cleanup_exact_handle_open", error,
                                target.get("pid"))],
                            **_R23_SUPERVISOR.NO_NUMERICAL_CREDIT},
            })

    unbound_signal_actions = list(unbound_open_failures)
    unbound_signal_by_identity: dict[tuple[int, int], dict[str, Any]] = {}
    if targets:
        for identity, handle in sorted(targets.items(), key=lambda item: item[0][1], reverse=True):
            receipt = signal_cleanup_target(identity, handle)
            action = {"identity": {"pid": identity[0],
                                    "create_time_100ns": identity[1]},
                      "receipt": receipt}
            actions.append(action)
            if identity in unbound_target_ids:
                unbound_action = {**action,
                    "source": target_sources.get(identity, ["observed_generation"])}
                unbound_signal_actions.append(unbound_action)
                unbound_signal_by_identity[identity] = unbound_action
        termination = {
            "schema": "vnext-t2-r23-termination-r1",
            "complete": all(row.get("receipt", {}).get("complete") is True
                             for row in actions),
            "verified": all(row.get("receipt", {}).get("complete") is True
                            for row in actions),
            "signal_attempts": actions,
            "root_exit_confirmed": root_exit_confirmed,
            "errors": [row.get("error") for row in actions if row.get("error")],
        }
    elif unbound_open_failures:
        termination = {
            "schema": "vnext-t2-r23-termination-r1",
            "complete": False, "verified": False,
            "signal_attempts": actions,
            "root_exit_confirmed": root_exit_confirmed,
            "errors": [row["receipt"] for row in unbound_open_failures],
        }
    final_snapshot = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
    root_row_final = final_snapshot.by_pid.get(root_identity[0])
    if root_row_final is not None and _r23_raw_identity(root_row_final) == root_identity:
        # A timed-out stage root is terminated through its original Popen handle.
        if not root_exit_confirmed and root_identity not in targets:
            receipt = signal_cleanup_target(root_identity, _r23_root_handle(process))
            actions.append({"identity": {"pid": root_identity[0],
                                          "create_time_100ns": root_identity[1]},
                            "receipt": receipt})
            termination = {
                "schema": "vnext-t2-r23-termination-r1",
                "complete": receipt.get("complete") is True,
                "verified": receipt.get("complete") is True,
                "signal_attempts": actions,
                "root_exit_confirmed": root_exit_confirmed,
                "errors": [] if receipt.get("complete") is True else [receipt],
            }
        # Refresh after root termination so descendants can be attributed.
        final_snapshot = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
    audit = _r23_final_audit(root_identity, sorted(tracked), final_snapshot,
                             root_exit_confirmed=root_exit_confirmed,
                             root_exit_code=getattr(process, "returncode", None),
                             working_set_limit_bytes=working_set_limit_bytes,
                             root_popen_handle=_r23_root_handle(process),
                             retained_handles=getattr(registry, "_handles", {}),
                             unbound_observation_records=unbound_observation_records,
                             tracked_sample_exit_records=tracked_sample_exit_records,
                             pre_tree_tracked_exit_records=pre_tree_tracked_exit_records,
                             membership_growth_records=membership_growth_records,
                             terminal_root_sample_exit_records=(
                                 terminal_root_sample_exit_records),
                             descendant_terminal_root_sample_exit_records=(
                                 descendant_terminal_root_sample_exit_records),
                             completed_samples=completed_samples,
                             terminal_partial_sample=terminal_partial_sample,
                             lifecycle_session=lifecycle_session,
                             phase_snapshot_history=phase_snapshot_history,
                             phase_snapshot_witnesses=phase_snapshot_witnesses)
    if audit.get("residual_descendant_processes"):
        residual_targets = []
        for row_data in audit["residual_descendant_processes"]:
            row = final_snapshot.by_pid.get(row_data["pid"])
            if row is None or _r23_raw_identity(row) != (
                    row_data["pid"], row_data["create_time_100ns"]):
                continue
            handle = registry.for_row(row, final_snapshot)
            residual_targets.append((_r23_raw_identity(row), handle))
        for identity, handle in residual_targets:
            receipt = signal_cleanup_target(identity, handle)
            action = {"identity": {"pid": identity[0],
                                    "create_time_100ns": identity[1]},
                      "receipt": receipt}
            actions.append(action)
            if identity in unbound_target_ids and identity not in unbound_signal_by_identity:
                unbound_action = {**action,
                    "source": target_sources.get(identity, ["observed_generation"])}
                unbound_signal_actions.append(unbound_action)
                unbound_signal_by_identity[identity] = unbound_action
        final_snapshot = _R23_TABLE.validate_snapshot(_R23_TABLE.query_native_process_table())
        audit = _r23_final_audit(root_identity, sorted(tracked), final_snapshot,
                                 root_exit_confirmed=root_exit_confirmed,
                                 root_exit_code=getattr(process, "returncode", None),
                                 working_set_limit_bytes=working_set_limit_bytes,
                                 root_popen_handle=_r23_root_handle(process),
                                 retained_handles=getattr(registry, "_handles", {}),
                                 unbound_observation_records=unbound_records,
                                 tracked_sample_exit_records=tracked_sample_exit_records,
                                 pre_tree_tracked_exit_records=pre_tree_tracked_exit_records,
                                 membership_growth_records=membership_growth_records,
                                 terminal_root_sample_exit_records=(
                                     terminal_root_sample_exit_records),
                                 descendant_terminal_root_sample_exit_records=(
                                     descendant_terminal_root_sample_exit_records),
                                 completed_samples=completed_samples,
                                 terminal_partial_sample=terminal_partial_sample,
                                 lifecycle_session=lifecycle_session,
                                 phase_snapshot_history=phase_snapshot_history,
                                 phase_snapshot_witnesses=phase_snapshot_witnesses)

    # This fresh full-table confirmation explicitly closes every syntactically
    # valid unbound observation and any descendant with a provable live exact
    # parent. PID reuse and orphan chains stay unresolved and cannot pass.
    post_unbound_plan = _r20_unbound_cleanup_plan(
        final_snapshot, cleanup_observation_records, protected_identities)
    post_unbound_plan["membership_growth_observed_generations"] = [
        {"pid": identity[0], "create_time_100ns": identity[1],
         "ppid": row["ppid"], "name": row["name"]}
        for identity, row in sorted(growth_observed_rows.items())]
    post_unbound_plan["membership_growth_inventory_errors"] = growth_inventory_errors
    post_unbound_plan["membership_growth_record_count"] = len(growth_records)
    post_unbound_plan["membership_growth_exact_exit_receipts"] = copy.deepcopy(
        membership_growth_exact_exit_receipts)
    if growth_inventory_errors:
        post_unbound_plan.setdefault("errors", []).extend(growth_inventory_errors)
        post_unbound_plan["complete"] = False
    target_generation_checks = []
    reused_cleanup_target_errors = []
    for identity in sorted(unbound_target_ids):
        current = final_snapshot.by_pid.get(identity[0])
        absent = current is None
        target_generation_checks.append({
            "pid": identity[0], "expected_create_time_100ns": identity[1],
            "observed_create_time_100ns": (
                current.identity.create_time_100ns if current is not None else None),
            "pid_absent": absent,
        })
        if not absent:
            reused_cleanup_target_errors.append(_monitor_error(
                "r20_unbound_cleanup_post_confirmation",
                RuntimeError("cleanup target PID remains or was reused; no further generation may be signalled"),
                identity[0]))
    post_unbound_absent = not target_generation_checks or all(
        item["pid_absent"] is True for item in target_generation_checks)
    post_unbound_absent = post_unbound_absent and \
        not post_unbound_plan.get("targets") and \
        not post_unbound_plan.get("unresolved") and \
        not post_unbound_plan.get("errors")
    unbound_cleanup = {
        "schema": "vnext-t2-r20-unbound-cleanup-r1",
        "complete": unbound_plan.get("complete") is True and
                    post_unbound_absent and
                    all(item.get("complete") is True
                        for item in membership_growth_exact_exit_receipts) and
                    all(action.get("receipt", {}).get("complete") is True
                        for action in unbound_signal_actions),
        "plan": unbound_plan,
        "membership_growth_observed_generations": [
            {"pid": identity[0], "create_time_100ns": identity[1],
             "ppid": row["ppid"], "name": row["name"]}
            for identity, row in sorted(growth_observed_rows.items())],
        "membership_growth_record_count": len(growth_records),
        "membership_growth_exact_exit_receipts":
            membership_growth_exact_exit_receipts,
        "signal_attempts": unbound_signal_actions,
        "post_cleanup_confirmation": {
            "schema": "vnext-t2-r20-unbound-cleanup-confirmation-r1",
            "complete": post_unbound_absent,
            "snapshot": _r23_snapshot_receipt(final_snapshot),
            "plan": post_unbound_plan,
            "target_generation_checks": target_generation_checks,
            "target_process_ids_absent": post_unbound_absent,
            "errors": [*post_unbound_plan.get("errors", []),
                       *reused_cleanup_target_errors],
        },
        "errors": [*unbound_plan.get("errors", []),
                   *unbound_plan.get("unresolved", []),
                   *reused_cleanup_target_errors,
                   *[action.get("receipt") for action in unbound_signal_actions
                     if action.get("receipt", {}).get("complete") is not True]],
    }
    if cleanup_observation_records or unbound_target_ids or unbound_open_failures:
        if termination is None:
            termination = {
                "schema": "vnext-t2-r23-termination-r1",
                "complete": unbound_cleanup["complete"],
                "verified": unbound_cleanup["complete"],
                "signal_attempts": actions,
                "root_exit_confirmed": root_exit_confirmed,
                "errors": [],
            }
        termination["unbound_cleanup"] = unbound_cleanup
        termination["complete"] = termination.get("complete") is True and \
            unbound_cleanup["complete"] and audit.get("complete") is True
        termination["verified"] = termination["complete"]

    if managed_debug_exit_drain is not None:
        if termination is None:
            termination = {
                "schema": "vnext-t2-r23-termination-r1",
                "complete": managed_debug_exit_drain.get("complete") is True and
                            audit.get("complete") is True,
                "verified": False,
                "signal_attempts": actions,
                "root_exit_confirmed": root_exit_confirmed,
                "errors": [],
            }
        termination["managed_debug_exit_drain"] = managed_debug_exit_drain
        termination["root_exit_confirmed"] = root_exit_confirmed
        termination["complete"] = termination.get("complete") is True and \
            managed_debug_exit_drain.get("complete") is True
        termination["errors"] = [*termination.get("errors", []),
                                  *managed_debug_exit_drain.get("errors", [])]
        termination["verified"] = termination["complete"]

    if termination is not None:
        termination["signal_attempts"] = actions
        termination["complete"] = termination["complete"] and \
            audit.get("complete") is True
        termination["verified"] = termination["complete"]
        termination["post_cleanup_audit"] = {
            "complete": audit.get("complete"),
            "residual_descendant_count": len(audit.get(
                "residual_descendant_processes", [])),
            "snapshot": audit.get("snapshot"),
        }
    return audit, termination


def run_phase(name: str, command: list[str], output: Path, *,
              timeout_seconds: float, working_set_limit_bytes: int,
              environment: dict[str, str], precreated: bool = False,
              legacy_fixture_only: bool = False) -> dict[str, Any]:
    """Run a phase with exact native PID/FILETIME supervision end-to-end."""
    if type(timeout_seconds) not in (int, float) or isinstance(timeout_seconds, bool) or \
            not math.isfinite(float(timeout_seconds)) or timeout_seconds <= 0 or \
            type(working_set_limit_bytes) is not int or working_set_limit_bytes <= 0:
        raise RuntimeError("R23 phase timeout/working-set limit is malformed")
    timeout_seconds = float(timeout_seconds)
    if type(legacy_fixture_only) is not bool:
        raise RuntimeError("legacy fixture mode must be a literal boolean")
    if _R23_ACTIVE_PROTOCOL_SHA256 is None and not legacy_fixture_only:
        raise RuntimeError("run_phase requires a verified managed protocol outside explicit fixtures")
    if _R23_ACTIVE_PROTOCOL_SHA256 is not None and legacy_fixture_only:
        raise RuntimeError("legacy fixture mode is forbidden after managed protocol configuration")
    if precreated:
        if not output.is_dir():
            raise RuntimeError(f"precreated phase directory absent: {output}")
    else:
        output.mkdir(parents=True, exist_ok=False)
    started_utc = utc()
    started = time.monotonic()
    child_started = started
    child_finished = started
    stop_reason = "natural_exit"
    samples: list[dict[str, Any]] = []
    tracked: set[tuple[int, int]] = set()
    active_tracked: set[tuple[int, int]] = set()
    exit_receipts: list[dict[str, Any]] = []
    termination_receipt: dict[str, Any] | None = None
    termination_actions: list[dict[str, Any]] = []
    final_tree_audit: dict[str, Any] | None = None
    residual_audit: dict[str, Any] | None = None
    terminal_sample_race: dict[str, Any] | None = None
    terminal_partial_sample: dict[str, Any] | None = None
    sample_handoff_recoveries: list[dict[str, Any]] = []
    tracked_sample_exit_records: list[dict[str, Any]] = []
    pre_tree_tracked_exit_records: list[dict[str, Any]] = []
    membership_growth_records: list[dict[str, Any]] = []
    terminal_root_sample_exit_records: list[dict[str, Any]] = []
    descendant_terminal_root_sample_exit_records: list[dict[str, Any]] = []
    phase_snapshot_history: list[dict[str, Any]] = []
    phase_snapshot_witnesses: list[str] = []
    previous_accepted_source_snapshot: Any | None = None
    previous_accepted_source_history_sequence: int | None = None
    previous_accepted_sample_index: int | None = None
    launch_error: dict[str, Any] | None = None
    launch_identity: tuple[int, int] | None = None
    launch_receipt: dict[str, Any] = {"schema": "vnext-t2-r23-launch-identity-r1",
        "complete": False, "identity_authority": "raw_PID_FILETIME_100ns_SPI_plus_Popen_handle"}
    registry = _R23_SUPERVISOR.ExactHandleRegistry()
    lifecycle_observer: _R23ManagedObserver | None = None
    lifecycle_directory: Path | None = None
    lifecycle_receipt_files: dict[str, Any] | None = None
    lifecycle_close_receipt: Mapping[str, Any] | None = None
    managed_mode = _R23_ACTIVE_PROTOCOL_SHA256 is not None
    managed_initial_sample_pending = managed_mode
    managed_initial_sample_gate: dict[str, Any] | None = (
        {
            "schema": "vnext-t2-r23-managed-initial-sample-before-resume-r1",
            "complete": False,
            "status": "awaiting_first_complete_sample",
            "sample_index": 1,
            "sample_complete": False,
            "root_resumed_after_sample": False,
            "sample_attempt_count": 0,
            "source_history_sequence": None,
            "sample_record_sha256": None,
            "root_identity": None,
            "samples_file": None,
            "sample_file_flushed": False,
            "sample_file_fsynced": False,
            "startup_hold_kind": None,
            "release_method": None,
            "errors": [],
        } if managed_mode else None)
    if managed_mode and _R23_MANAGED_LIFECYCLE is None:
        raise RuntimeError("verified protocol did not configure its managed lifecycle source")
    process: Any = None
    exit_code: int | None = None
    root_exit_confirmed = False
    samples_path = output / "samples.jsonl"
    with (output / "stdout.raw").open("xb") as stdout, \
            (output / "stderr.raw").open("xb") as stderr:
        with samples_path.open(
                "x", encoding="utf-8", newline="\n", buffering=1) as sample_file:
            try:
                if managed_mode:
                    lifecycle_directory = output / "managed_lifecycle"
                    lifecycle_directory.mkdir(exist_ok=False)
                    ack_directory = lifecycle_directory / "acks"
                    ack_directory.mkdir(exist_ok=False)
                    monitor_identity = _R23_MANAGED_LIFECYCLE. \
                        WindowsDebugLifecycle.current_process_identity()
                    registry = _R23ManagedBirthRegistryBoundary(
                        _R23_SUPERVISOR.ExactHandleRegistry(
                            identity_reader=_R23_TABLE.read_process_handle_identity,
                            strict_registered_births=True, phase_root=ack_directory),
                        _R23_MANAGED_LIFECYCLE)
                    lifecycle_observer = _R23ManagedObserver(
                        _R23_MANAGED_LIFECYCLE, lifecycle_directory,
                        phase_snapshot_history, phase_snapshot_witnesses,
                        monitor_identity)
                    lifecycle_observer.set_context(1, 0)
                    reserved = {
                        "FCA_MANAGED_SESSION_ID",
                        "FCA_MANAGED_ACK_DIRECTORY",
                        "FCA_MANAGED_SCOPE_SHA256",
                        "FCA_MANAGED_MONITOR_PID",
                        "FCA_MANAGED_MONITOR_CREATE_100NS",
                        "FCA_MANAGED_HANDSHAKE_SECONDS",
                        "FCA_MANAGED_DEADLINE_TICK64_MS",
                    }
                    inherited_environment = dict(environment)
                    if any(type(key) is not str or type(value) is not str
                           for key, value in inherited_environment.items()) or \
                            any(key.casefold() in {item.casefold() for item in reserved}
                                for key in inherited_environment):
                        raise _R23_TABLE.ProcessTableError(
                            "managed launch environment contains malformed or reserved values")
                    session_id = secrets.token_hex(32)
                    scope_payload = {
                        "schema": "vnext-t2-r23-managed-phase-scope-r1",
                        "protocol_sha256": _R23_ACTIVE_PROTOCOL_SHA256,
                        "phase": name,
                        "argv": command,
                        "cwd": str(ROOT),
                        "timeout_seconds": timeout_seconds,
                        "working_set_limit_bytes": working_set_limit_bytes,
                    }
                    scope_sha256 = sha256_bytes(json.dumps(
                        scope_payload, sort_keys=True, separators=(",", ":"),
                        ensure_ascii=True, allow_nan=False).encode("ascii"))
                    remaining = timeout_seconds - (time.monotonic() - started)
                    handshake_seconds = min(5.0, remaining / 4.0)
                    if remaining <= 0 or not math.isfinite(handshake_seconds) or \
                            handshake_seconds <= 0:
                        raise _R23_TABLE.ProcessTableError(
                            "managed phase has no remaining bounded CREATE handshake time")
                    inherited_environment.update({
                        "FCA_MANAGED_SESSION_ID": session_id,
                        "FCA_MANAGED_ACK_DIRECTORY": str(ack_directory.resolve()),
                        "FCA_MANAGED_SCOPE_SHA256": scope_sha256,
                        "FCA_MANAGED_MONITOR_PID": str(monitor_identity.pid),
                        "FCA_MANAGED_MONITOR_CREATE_100NS":
                            str(monitor_identity.creation_time_100ns),
                        "FCA_MANAGED_HANDSHAKE_SECONDS":
                            format(handshake_seconds, ".17g"),
                    })
                    stdout_handle = msvcrt.get_osfhandle(stdout.fileno())
                    stderr_handle = msvcrt.get_osfhandle(stderr.fileno())
                    process = _R23_MANAGED_LIFECYCLE.WindowsDebugLifecycle.spawn_suspended(
                        command, str(ROOT), inherited_environment, None, registry,
                        lifecycle_observer, started + timeout_seconds,
                        stdio_handles=(None, stdout_handle, stderr_handle))
                    lifecycle_observer.session = process
                    root_identity_obj = process.root_identity
                    launch_identity = (root_identity_obj.pid,
                                       root_identity_obj.creation_time_100ns)
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(process.root_handle),
                        launch_identity, phase="managed phase root CREATE handle")
                    launch_snapshot = lifecycle_observer.last_source_snapshot
                    if launch_snapshot is None or not phase_snapshot_history or \
                            phase_snapshot_history[0].get("source_role") != "phase_launch" or \
                            registry.identities.count(launch_identity) != 1 or \
                            process.identity_complete is not True:
                        raise _R23_TABLE.ProcessTableError(
                            "managed root CREATE lacks exact source/registry/identity proof")
                    root_row = _R23_TABLE.validate_snapshot(launch_snapshot).by_pid.get(
                        launch_identity[0])
                    if root_row is None or _r23_raw_identity(root_row) != launch_identity:
                        raise _R23_TABLE.ProcessTableError(
                            "managed root generation is absent from its CREATE source")
                    launch_authority = (
                        "raw_PID_FILETIME_100ns_SPI_plus_debug_CREATE_ack_and_original_lifecycle_handle")
                else:
                    process = psutil.Popen(
                        command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                        creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                    launch_identity = _R23_TABLE.read_process_handle_identity(_r23_root_handle(process))
                    if type(process.pid) is not int or process.pid != launch_identity[0]:
                        raise _R23_TABLE.ProcessTableError(
                            "Popen PID differs from original native process handle")
                    launch_snapshot = _R23_TABLE.validate_snapshot(
                        _R23_TABLE.query_native_process_table())
                    _r23_append_snapshot_history(
                        phase_snapshot_history, phase_snapshot_witnesses,
                        launch_snapshot,
                        sample_index=0, attempt_index=0,
                        source_role="phase_launch")
                    registry.bind_popen(process, launch_snapshot)
                    root_row = _R23_TABLE.validate_snapshot(launch_snapshot).by_pid.get(
                        launch_identity[0])
                    if root_row is None or _r23_raw_identity(root_row) != launch_identity:
                        raise _R23_TABLE.ProcessTableError(
                            "Popen generation is absent from exact native inventory")
                    launch_authority = (
                        "raw_PID_FILETIME_100ns_SPI_plus_original_Popen_handle")
                tracked.add(launch_identity)
                active_tracked.add(launch_identity)
                display = _R23_TABLE.display_seconds(launch_identity[1])
                launch_receipt = {
                    "schema": "vnext-t2-r23-launch-identity-r1", "complete": True,
                    "identity_authority": launch_authority,
                    "pid": launch_identity[0], "create_time_100ns": launch_identity[1],
                    "create_time": display, "looked_up_pid": launch_identity[0],
                    "looked_up_create_time": display,
                    "native_snapshot": _r23_snapshot_receipt(launch_snapshot),
                    "helper_sha256": _R23_TABLE_SHA256,
                    "supervisor_sha256": _R23_SUPERVISOR_SHA256,
                }
            except Exception as error:
                if process is None:
                    process = getattr(error, "session", None)
                launch_error = _monitor_error("r23_launch_generation_bind", error,
                    getattr(process, "pid", None))
                launch_receipt["error"] = launch_error
                stop_reason = "process_tree_monitor_incomplete"

            sample_index = 0
            while process is not None and launch_error is None:
                try:
                    if lifecycle_observer is None and process.poll() is not None:
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "phase_wall_timeout"
                        break
                    current = _R23_TABLE.validate_snapshot(
                        _R23_TABLE.query_native_process_table())
                    next_sample_index = sample_index + 1
                    outer_reconcile_history_sequence = \
                        _r23_append_snapshot_history(
                            phase_snapshot_history, phase_snapshot_witnesses,
                            current,
                            sample_index=next_sample_index, attempt_index=0,
                            source_role="outer_reconcile")
                    outer_exit_query_ordinal = [0]

                    def capture_outer_tracked_exit_snapshot(snapshot: Any) -> None:
                        outer_exit_query_ordinal[0] += 1
                        _r23_append_snapshot_history(
                            phase_snapshot_history, phase_snapshot_witnesses,
                            snapshot, sample_index=next_sample_index,
                            attempt_index=0,
                            source_role=(
                                f"outer_tracked_exit_{outer_exit_query_ordinal[0]}"))

                    if lifecycle_observer is not None:
                        lifecycle_observer.set_context(next_sample_index, 0)
                    if not managed_initial_sample_pending and process.poll() is not None:
                        break
                    active, exits = _r23_reconcile_missing_tracked(
                        active_tracked, registry, process, current,
                        snapshot_observer=capture_outer_tracked_exit_snapshot)
                    exit_receipts.extend(exits)
                    active_tracked = set(active) | {launch_identity}
                    if lifecycle_observer is not None:
                        lifecycle_observer.set_context(next_sample_index, 0)
                    if not managed_initial_sample_pending and process.poll() is not None:
                        break
                    sample_index += 1
                    elapsed = time.monotonic() - started
                    completed_source_snapshot: list[Any] = []
                    completed_source_history_sequence: list[int] = []
                    sample = _r20_native_sample(
                        process, registry, launch_identity, active,
                        sample_index=sample_index, elapsed=elapsed,
                        deadline_monotonic=started + timeout_seconds,
                        previous_accepted_source_snapshot=(
                            previous_accepted_source_snapshot),
                        outer_reconcile_snapshot=current,
                        outer_reconcile_history_sequence=(
                            outer_reconcile_history_sequence),
                        previous_accepted_source_history_sequence=(
                            previous_accepted_source_history_sequence),
                        previous_accepted_sample_index=previous_accepted_sample_index,
                        phase_snapshot_history=phase_snapshot_history,
                        phase_snapshot_witnesses=phase_snapshot_witnesses,
                        working_set_limit_bytes=working_set_limit_bytes,
                        lifecycle_observer=lifecycle_observer,
                        completed_source_snapshot_out=completed_source_snapshot,
                        completed_source_snapshot_history_sequence_out=(
                            completed_source_history_sequence))
                    if managed_initial_sample_pending and \
                            managed_initial_sample_gate is not None:
                        managed_initial_sample_gate.update({
                            "sample_index": sample_index,
                            "sample_complete": sample.get("sample_complete") is True,
                            "sample_attempt_count": sample.get(
                                "sample_attempt_count"),
                            "complete_sample_metrics_are_standard_phase_measurements":
                                sample.get("sample_complete") is True,
                            "reported_partial_rss_bytes_not_credited": (
                                sample.get("partial_rss_bytes_not_credited")),
                            "errors": copy.deepcopy(sample.get("errors", [])),
                        })
                    sample_handoff_recoveries.extend(
                        sample.get("sample_handoff_recoveries", []))
                    tracked_sample_exit_records.extend(
                        sample.get("tracked_sample_exit_races", []))
                    pre_tree_tracked_exit_records.extend(
                        sample.get("pre_tree_tracked_exit_races", []))
                    membership_growth_records.extend(
                        sample.get("membership_growth_records", []))
                    terminal_root_sample_exit_records.extend(
                        sample.get("terminal_root_sample_exit_races", []))
                    descendant_terminal_root_sample_exit_records.extend(
                        sample.get("descendant_terminal_root_sample_exit_races", []))
                    if sample.get("sample_complete") is not True:
                        if managed_initial_sample_pending and \
                                managed_initial_sample_gate is not None:
                            managed_initial_sample_gate["status"] = (
                                "first_full_sample_incomplete_root_not_resumed")
                        errors = sample.get("errors", [])
                        terminal_root_absence = bool(errors) and all(
                            isinstance(error, dict) and
                            error.get("message") ==
                                "root process is absent from process table"
                            for error in errors)
                        if terminal_root_absence and \
                                _R23_TABLE.wait_for_process_exit(
                                    _r23_root_handle(process), 0.05) is True:
                            _R23_TABLE.require_same_identity(
                                _R23_TABLE.read_process_handle_identity(
                                    _r23_root_handle(process)), launch_identity,
                                phase="terminal sample root-exit race")
                            terminal_sample_race = {
                                "schema": "vnext-t2-r23-terminal-sample-race-r1",
                                "status": "terminal_root_exit_during_sample",
                                "sample_index": sample_index,
                                "sample_errors": errors,
                                "exact_root_handle_wait_confirmed": True,
                                "root_identity": {
                                    "pid": launch_identity[0],
                                    "create_time_100ns": launch_identity[1]},
                                "sample_excluded_from_completed_resource_samples": True,
                                "formal_t2_accepted": False,
                            }
                            write_json_new(output / "terminal_sample_race.json",
                                           terminal_sample_race)
                            break
                        terminal_records = sample.get(
                            "terminal_root_sample_exit_races", [])
                        terminal_only = (
                            type(terminal_records) is list and
                            len(terminal_records) == 1 and
                            isinstance(terminal_records[0], dict) and
                            terminal_records[0].get("complete") is True and
                            terminal_records[0].get("schema") ==
                                "vnext-t2-r23-terminal-root-sample-exit-r1" and
                            terminal_records[0].get("sample_complete") is False and
                            terminal_records[0].get("retry_started") is False and
                            terminal_records[0].get(
                                "full_sample_completed_after_retry") is False and
                            type(terminal_records[0].get(
                                "partial_rss_bytes_not_credited")) is int and
                            terminal_records[0].get("partial_rss_bytes_not_credited", -1) <
                                working_set_limit_bytes and
                            sample.get("sample_attempt_count") == 1 and
                            sample.get("sample_complete") is False and
                            sample.get("process_tree_working_set_bytes") == 0 and
                            sample.get("process_tree_user_cpu_seconds") == 0.0 and
                            sample.get("process_tree_system_cpu_seconds") == 0.0 and
                            sample.get("processes") == [] and
                            not sample.get("sample_handoff_recoveries") and
                            not sample.get("tracked_sample_exit_races") and
                            not sample.get("pre_tree_tracked_exit_races") and
                            not sample.get("membership_growth_records") and
                            len(errors) == 1 and isinstance(errors[0], dict) and
                            errors[0].get("message") ==
                                "exact generation exited during resource read; discard sample and "
                                "require typed exact-generation recovery")
                        if terminal_only:
                            terminal_partial_sample = sample
                            terminal_sample_race = {
                                "schema": "vnext-t2-r23-terminal-sample-race-r2",
                                "status": "terminal_root_resource_read_exit_proven",
                                "sample_index": sample_index,
                                "sample_excluded_from_completed_resource_samples": True,
                                "terminal_root_sample_exit": terminal_records[0],
                                "partial_sample": sample,
                                "formal_t2_accepted": False,
                            }
                            write_json_new(output / "terminal_sample_race.json",
                                           terminal_sample_race)
                            terminal_sample_race["file"] = file_receipt(
                                output / "terminal_sample_race.json")
                            break
                        descendant_terminal_records = sample.get(
                            "descendant_terminal_root_sample_exit_races", [])
                        descendant_terminal_only = (
                            type(descendant_terminal_records) is list and
                            len(descendant_terminal_records) == 1 and
                            isinstance(descendant_terminal_records[0], dict) and
                            descendant_terminal_records[0].get("complete") is True and
                            descendant_terminal_records[0].get("schema") ==
                                "vnext-t2-r23-descendant-terminal-root-sample-exit-r1" and
                            descendant_terminal_records[0].get("sample_complete") is False and
                            descendant_terminal_records[0].get("retry_started") is False and
                            descendant_terminal_records[0].get(
                                "full_sample_completed_after_retry") is False and
                            type(descendant_terminal_records[0].get(
                                "partial_rss_bytes_not_credited")) is int and
                            0 <= descendant_terminal_records[0].get(
                                "partial_rss_bytes_not_credited") <
                                working_set_limit_bytes and
                            sample.get("sample_attempt_count") == 1 and
                            sample.get("sample_complete") is False and
                            sample.get("process_tree_working_set_bytes") == 0 and
                            sample.get("process_tree_user_cpu_seconds") == 0.0 and
                            sample.get("process_tree_system_cpu_seconds") == 0.0 and
                            sample.get("processes") == [] and
                            not sample.get("sample_handoff_recoveries") and
                            not sample.get("tracked_sample_exit_races") and
                            not sample.get("pre_tree_tracked_exit_races") and
                            not sample.get("membership_growth_records") and
                            not sample.get("terminal_root_sample_exit_races") and
                            len(errors) == 1 and isinstance(errors[0], dict) and
                            errors[0].get("message") ==
                                "exact generation exited during resource read; discard sample and "
                                "require typed exact-generation recovery")
                        if descendant_terminal_only:
                            terminal_partial_sample = sample
                            terminal_sample_race = {
                                "schema": "vnext-t2-r23-terminal-descendant-root-sample-race-r1",
                                "status": "descendant_exit_then_terminal_root_proven",
                                "sample_index": sample_index,
                                "sample_excluded_from_completed_resource_samples": True,
                                "descendant_terminal_root_sample_exit":
                                    descendant_terminal_records[0],
                                "incomplete_r21_handoff_observation":
                                    descendant_terminal_records[0].get(
                                        "r21_incomplete_handoff_observation"),
                                "partial_sample": sample,
                                "formal_t2_accepted": False,
                            }
                            write_json_new(output / "terminal_sample_race.json",
                                           terminal_sample_race)
                            terminal_sample_race["file"] = file_receipt(
                                output / "terminal_sample_race.json")
                            break
                        sample_record_json = json.dumps(sample, sort_keys=True)
                        samples.append(sample)
                        sample_file.write(sample_record_json + "\n")
                        if managed_initial_sample_pending and managed_initial_sample_gate is not None:
                            sample_file.flush()
                            managed_initial_sample_gate["sample_file_flushed"] = True
                            os.fsync(sample_file.fileno())
                            managed_initial_sample_gate["sample_file_fsynced"] = True
                            sample_log_file = file_receipt(samples_path)
                            sample_log_file["path"] = str(samples_path.resolve())
                            sample_log_file["flush"] = True
                            sample_log_file["fsync"] = True
                            managed_initial_sample_gate["samples_file"] = sample_log_file
                            managed_initial_sample_gate["sample_record_sha256"] = sha256_bytes(
                                (sample_record_json + "\n").encode("utf-8"))
                            try:
                                abort_receipt = process.abort_startup(
                                    _R23_SUPERVISOR.MonitorIncomplete(
                                        "first full sample was incomplete before root resume: " +
                                        json.dumps(errors, sort_keys=True)))
                                if not isinstance(abort_receipt, Mapping):
                                    raise _R23_TABLE.ProcessTableError(
                                        "registered startup abort returned no typed receipt")
                                managed_initial_sample_gate["startup_abort_receipt"] = dict(
                                    abort_receipt)
                            except Exception as abort_error:
                                managed_initial_sample_gate["startup_abort_error"] = _monitor_error(
                                    "r23_registered_startup_abort", abort_error,
                                    getattr(process, "pid", None))
                        stop_reason = "process_tree_monitor_incomplete"
                        break
                    if len(completed_source_snapshot) != 1:
                        raise _R23_TABLE.ProcessTableError(
                            "complete sample did not return its exact source snapshot")
                    if len(completed_source_history_sequence) != 1:
                        raise _R23_TABLE.ProcessTableError(
                            "complete sample did not return its exact source-history sequence")
                    sample_record_json = json.dumps(sample, sort_keys=True)
                    managed_initial_sample_receipt: dict[str, Any] | None = None
                    if managed_initial_sample_pending and \
                            managed_initial_sample_gate is not None:
                        source_sequence = completed_source_history_sequence[0]
                        history_reference = _r23_snapshot_history_reference(
                            phase_snapshot_history, phase_snapshot_witnesses,
                            source_sequence, completed_source_snapshot[0],
                            sample_index=sample_index,
                            source_role="sample_source_before")
                        source_attempt = phase_snapshot_history[
                            source_sequence].get("attempt_index")
                        if sample_index != 1 or type(source_attempt) is not int or \
                                source_attempt not in (1, 2):
                            raise _R23_TABLE.ProcessTableError(
                                "managed startup sample lacks its exact first-sample source")
                        managed_initial_sample_gate.update({
                            "sample_attempt_count": sample.get(
                                "sample_attempt_count"),
                            "source_history_sequence": source_sequence,
                            "source_attempt_index": source_attempt,
                            "source_history_reference": history_reference,
                            "sample_record_sha256": sha256_bytes(
                                (sample_record_json + "\n").encode("utf-8")),
                            "root_identity": {
                                "pid": launch_identity[0],
                                "creation_time_100ns": launch_identity[1]},
                            "status": "first_full_sample_accepted_before_resume",
                        })
                    previous_accepted_source_snapshot = _R23_TABLE.validate_snapshot(
                        completed_source_snapshot[0])
                    previous_accepted_source_history_sequence = \
                        completed_source_history_sequence[0]
                    previous_accepted_sample_index = sample_index
                    samples.append(sample)
                    sample_file.write(sample_record_json + "\n")
                    if managed_initial_sample_pending and \
                            managed_initial_sample_gate is not None:
                        sample_file.flush()
                        managed_initial_sample_gate["sample_file_flushed"] = True
                        os.fsync(sample_file.fileno())
                        managed_initial_sample_gate["sample_file_fsynced"] = True
                        sample_log_file = file_receipt(samples_path)
                        sample_log_file["path"] = str(samples_path.resolve())
                        sample_log_file["flush"] = True
                        sample_log_file["fsync"] = True
                        managed_initial_sample_gate["samples_file"] = sample_log_file
                        exact_receipt = sample.get("exact_monitor_receipt", {})
                        standard_metrics = (
                            sample.get("sample_complete") is True and
                            exact_receipt.get("complete") is True and
                            type(sample.get("process_tree_working_set_bytes")) is int and
                            sample["process_tree_working_set_bytes"] >= 0 and
                            type(sample.get("process_tree_user_cpu_seconds")) in
                                (int, float) and
                            math.isfinite(float(sample[
                                "process_tree_user_cpu_seconds"])) and
                            type(sample.get("process_tree_system_cpu_seconds")) in
                                (int, float) and
                            math.isfinite(float(sample[
                                "process_tree_system_cpu_seconds"])) and
                            type(sample.get("processes")) is list and
                            bool(sample["processes"]))
                        source_history_refs = [{
                            "sequence": source_sequence,
                            "complete": bool(history_reference.get("snapshot_receipt")) and
                                bool(history_reference.get("pid_set_sha256")) and
                                bool(history_reference.get("prefix_sha256")),
                            "attempt_index": source_attempt,
                            "reference": copy.deepcopy(history_reference),
                        }]
                        if sample_index != 1 or not standard_metrics or \
                                source_history_refs[0]["complete"] is not True:
                            raise _R23_TABLE.ProcessTableError(
                                "managed first sample lacks durable standard metrics/source proof")
                        managed_initial_sample_receipt = {
                            "schema": "fca-standard-first-sample-receipt-v1",
                            "sample_index": sample_index,
                            "sample_complete": True,
                            "standard_metrics": True,
                            "source_attempt_id": source_attempt,
                            "source_history_refs": source_history_refs,
                            "snapshot_complete": exact_receipt.get("complete") is True,
                            "root_identity": {
                                "pid": launch_identity[0],
                                "creation_time_100ns": launch_identity[1]},
                            "samples_file": sample_log_file,
                        }
                        managed_initial_sample_gate.update({
                            "complete_sample_metrics_are_standard_phase_measurements":
                                standard_metrics,
                            "samples_file": sample_log_file,
                        })
                    receipt = sample.get("exact_monitor_receipt", {})
                    all_tracked_exit_races = [
                        *sample.get("tracked_sample_exit_races", []),
                        *sample.get("pre_tree_tracked_exit_races", []),
                    ]
                    for race in all_tracked_exit_races:
                        if race.get("complete") is not True or \
                                race.get("full_sample_completed_after_retry") is not True or \
                                race.get("retry_started") is not True:
                            raise _R23_TABLE.ProcessTableError(
                                "tracked sample-exit did not complete its fresh whole-sample retry")
                        retired = {_R23_TABLE.validate_identity((
                            item.get("pid"), item.get("create_time_100ns")))
                            for item in race.get("retired_tracked_identities", [])
                            if isinstance(item, dict)}
                        if not retired or not retired.issubset(active_tracked) or \
                                any(identity not in tracked for identity in retired):
                            raise _R23_TABLE.ProcessTableError(
                                "tracked sample-exit retirement is outside active historical identities")
                        active_tracked.difference_update(retired)
                        exit_receipts.extend(race.get("exact_exit_receipts", []))
                    for identity_data in receipt.get("discovered_identities", []):
                        identity = _R23_TABLE.validate_identity((
                            identity_data.get("pid"),
                            identity_data.get("create_time_100ns")))
                        tracked.add(identity)
                        active_tracked.add(identity)
                    if sample.get("process_tree_working_set_bytes", 0) >= \
                            working_set_limit_bytes:
                        stop_reason = "process_tree_working_set_hard_ceiling"
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "phase_wall_timeout"
                        break
                    if managed_initial_sample_pending:
                        try:
                            if managed_initial_sample_receipt is None:
                                raise _R23_TABLE.ProcessTableError(
                                    "managed first sample receipt was not durably prepared")
                            release_receipt = process.resume_root_after_ack(
                                initial_sample_receipt=managed_initial_sample_receipt)
                        except Exception as resume_error:
                            if managed_initial_sample_gate is not None:
                                managed_initial_sample_gate["status"] = (
                                    "root_resume_failed_after_first_full_sample")
                                managed_initial_sample_gate["errors"].append(
                                    _monitor_error("r23_root_resume_after_initial_sample",
                                                   resume_error,
                                                   getattr(process, "pid", None)))
                            stop_reason = "process_tree_monitor_incomplete"
                            break
                        if not isinstance(release_receipt, Mapping) or \
                                release_receipt.get("event") != \
                                    "root_startup_barrier_released" or \
                                release_receipt.get("identity") != {
                                    "pid": launch_identity[0],
                                    "creation_time_100ns": launch_identity[1]} or \
                                release_receipt.get("startup_hold_kind") != \
                                    "debug_create_event" or \
                                release_receipt.get("release_method") != \
                                    "continue_debug_event" or \
                                release_receipt.get("initial_sample_receipt") != \
                                    managed_initial_sample_receipt:
                            if managed_initial_sample_gate is not None:
                                managed_initial_sample_gate["status"] = (
                                    "root_release_receipt_mismatch_after_continue")
                                managed_initial_sample_gate["errors"].append(
                                    _monitor_error("r23_root_release_receipt",
                                        "core release receipt did not bind the durable first sample",
                                        getattr(process, "pid", None)))
                            stop_reason = "process_tree_monitor_incomplete"
                            break
                        if managed_initial_sample_gate is not None:
                            managed_initial_sample_gate.update({
                                "complete": True,
                                "status": "first_full_sample_accepted_then_root_resumed",
                                "root_resumed_after_sample": True,
                                "startup_hold_kind": release_receipt.get(
                                    "startup_hold_kind"),
                                "release_method": release_receipt.get(
                                    "release_method"),
                            })
                        managed_initial_sample_pending = False
                    time.sleep(min(0.2, max(0.0,
                        timeout_seconds - (time.monotonic() - started))))
                except Exception as error:
                    stop_reason = "process_tree_monitor_incomplete"
                    if managed_initial_sample_pending and \
                            managed_initial_sample_gate is not None:
                        managed_initial_sample_gate["status"] = (
                            "first_full_sample_processing_failed_root_not_resumed")
                        managed_initial_sample_gate["errors"].append(
                            _monitor_error("r23_managed_initial_sample", error,
                                           getattr(process, "pid", None)))
                    failed = {
                        "schema": "vnext-t2-process-tree-sample-r2-native-exact",
                        "observed_utc": utc(), "sample_complete": False,
                        "identity_authority": "raw_PID_FILETIME_100ns_SPI_plus_original_process_handle",
                        "root_process_identity": ({"pid": launch_identity[0],
                            "create_time_100ns": launch_identity[1]}
                            if launch_identity else None),
                        "errors": [_monitor_error("r23_sample_loop", error,
                            getattr(process, "pid", None))],
                        "process_tree_working_set_bytes": 0,
                        "process_tree_user_cpu_seconds": 0.0,
                        "process_tree_system_cpu_seconds": 0.0,
                        "processes": [],
                    }
                    samples.append(failed)
                    sample_file.write(json.dumps(failed, sort_keys=True) + "\n")
                    break

            if process is not None and launch_identity is not None:
                try:
                    if process.poll() is None and stop_reason != "natural_exit":
                        # Descendants are signalled first; root uses the original Popen handle.
                        for identity in sorted(tracked - {launch_identity},
                                               key=lambda value: value[1], reverse=True):
                            current = _R23_TABLE.validate_snapshot(
                                _R23_TABLE.query_native_process_table())
                            row = current.by_pid.get(identity[0])
                            handle = _r23_handle_for_identity(registry, identity, process)
                            if row is None:
                                exit_receipt = _r23_wait_gone(
                                    identity, handle, timeout_seconds=0.01)
                                exit_receipts.append(exit_receipt)
                                if exit_receipt.get("complete") is not True:
                                    raise _R23_TABLE.ProcessTableError(
                                        "tracked descendant disappeared without exact exit proof")
                                continue
                            if _r23_raw_identity(row) != identity:
                                raise _R23_TABLE.ProcessTableError(
                                    "tracked descendant PID reused before signal")
                            receipt = _r23_signal_one(identity, handle)
                            termination_actions.append({
                                "identity": {"pid": identity[0],
                                             "create_time_100ns": identity[1]},
                                "receipt": receipt})
                            if receipt.get("complete") is not True:
                                raise _R23_TABLE.ProcessTableError(
                                    "exact descendant termination was not verified")
                        current = _R23_TABLE.validate_snapshot(
                            _R23_TABLE.query_native_process_table())
                        root_row = current.by_pid.get(launch_identity[0])
                        if root_row is not None:
                            if _r23_raw_identity(root_row) != launch_identity:
                                raise _R23_TABLE.ProcessTableError(
                                    "stage-root PID reused before termination")
                            root_signal = _r23_signal_one(
                                launch_identity, _r23_root_handle(process))
                            termination_actions.append({
                                "identity": {"pid": launch_identity[0],
                                             "create_time_100ns": launch_identity[1]},
                                "receipt": root_signal})
                            termination_receipt = {
                                "schema": "vnext-t2-r23-termination-r1",
                                "complete": all(action["receipt"].get("complete") is True
                                                 for action in termination_actions),
                                "verified": all(action["receipt"].get("complete") is True
                                                for action in termination_actions),
                                "signal_attempts": termination_actions,
                                "root_exit_confirmed": root_signal.get("wait_confirmed") is True,
                                "errors": [action["receipt"] for action in termination_actions
                                           if action["receipt"].get("complete") is not True],
                            }
                    # Native wait always uses the exact handle whose generation
                    # was bound, even when Popen.poll already observed exit.
                    if lifecycle_observer is not None:
                        remaining = max(0.0, started + timeout_seconds - time.monotonic())
                        native_code_from_session = process.wait(timeout=remaining)
                        if type(native_code_from_session) is not int:
                            raise _R23_TABLE.ProcessTableError(
                                "managed lifecycle wait returned a malformed root exit code")
                        waited = _R23_TABLE.wait_for_process_exit(
                            _r23_root_handle(process), 0)
                    else:
                        waited = _R23_TABLE.wait_for_process_exit(
                            _r23_root_handle(process),
                            min(60.0, max(0.01, timeout_seconds)))
                    if waited is not True:
                        raise _R23_TABLE.ProcessTableError(
                            "exact root handle wait did not confirm exit")
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(_r23_root_handle(process)),
                        launch_identity, phase="stage-root post-wait handle")
                    native_code = _R23_TABLE.process_exit_code(_r23_root_handle(process))
                    if lifecycle_observer is not None:
                        observed_code = native_code_from_session
                    else:
                        observed_code = process.wait(timeout=2)
                    if observed_code != native_code:
                        raise _R23_TABLE.ProcessTableError(
                            "managed/Popen and exact native-handle exit codes differ")
                    exit_code = native_code
                    root_exit_confirmed = True
                    child_finished = time.monotonic()
                except Exception as error:
                    root_exit_confirmed = False
                    child_finished = time.monotonic()
                    if stop_reason == "natural_exit":
                        stop_reason = "termination_unverified"
                    if termination_receipt is None:
                        termination_receipt = {
                            "schema": "vnext-t2-r23-termination-r1",
                            "complete": False, "verified": False,
                            "root_exit_confirmed": False,
                            "signal_attempts": termination_actions,
                            "errors": [_monitor_error("r23_exact_termination_wait",
                                error, launch_identity[0])],
                        }
                try:
                    final_tree_audit, cleanup_receipt = _r23_audit_and_cleanup(
                        process, registry, launch_identity, tracked,
                        root_exit_confirmed,
                        unbound_observation_records=sample_handoff_recoveries,
                        tracked_sample_exit_records=tracked_sample_exit_records,
                        pre_tree_tracked_exit_records=pre_tree_tracked_exit_records,
                        membership_growth_records=membership_growth_records,
                        terminal_root_sample_exit_records=(
                            terminal_root_sample_exit_records),
                        descendant_terminal_root_sample_exit_records=(
                            descendant_terminal_root_sample_exit_records),
                        completed_samples=samples,
                        terminal_partial_sample=terminal_partial_sample,
                        lifecycle_session=(process if lifecycle_observer is not None else None),
                        working_set_limit_bytes=working_set_limit_bytes,
                        phase_snapshot_history=phase_snapshot_history,
                        phase_snapshot_witnesses=tuple(phase_snapshot_witnesses))
                    if cleanup_receipt is not None:
                        termination_receipt = cleanup_receipt
                    residual_audit = final_tree_audit.get(
                        "global_heavy_process_audit")
                    if final_tree_audit.get("complete") is not True:
                        if stop_reason == "natural_exit":
                            stop_reason = "process_tree_monitor_incomplete"
                    elif final_tree_audit.get("residual_descendant_processes"):
                        stop_reason = "residual_descendant_processes_present"
                    if residual_audit is None or residual_audit.get("complete") is not True:
                        stop_reason = "residual_process_audit_incomplete"
                    elif residual_audit.get("processes"):
                        stop_reason = "residual_heavy_processes_present"
                except Exception as error:
                    final_tree_audit = {
                        "schema": "vnext-t2-r23-final-process-tree-audit-r1",
                        "complete": False, "root_exit_confirmed": root_exit_confirmed,
                        "errors": [_monitor_error("r23_final_native_audit", error,
                            launch_identity[0])],
                        "residual_descendant_processes": [],
                    }
                    residual_audit = {"schema": "vnext-t2-r23-global-heavy-audit-r1",
                        "complete": False, "processes": [],
                        "errors": [_monitor_error("r23_final_native_audit", error,
                            launch_identity[0])]}
                    stop_reason = "process_tree_monitor_incomplete"

    samples_log_receipt = file_receipt(samples_path)
    samples_log_receipt["path"] = str(samples_path.resolve())
    if lifecycle_observer is not None:
        close_errors: list[dict[str, Any]] = []
        session_summary: dict[str, Any] | None = None
        if process is not None:
            try:
                session_summary = dict(process.summary())
                if process.identity_complete is not True or \
                        process.exit_proof_complete is not True:
                    raise _R23_TABLE.ProcessTableError(
                        "managed session lacks complete identity and exact exit proof before close")
                lifecycle_close_receipt = dict(process.close())
                session_summary = dict(process.summary())
            except Exception as error:
                close_errors.append(_monitor_error(
                    "r23_managed_lifecycle_close", error,
                    getattr(process, "pid", None)))
        else:
            close_errors.append(_monitor_error(
                "r23_managed_lifecycle_close",
                RuntimeError("managed launch did not return a lifecycle session")))
        try:
            lifecycle_receipt_files = lifecycle_observer.close()
        except Exception as error:
            close_errors.append(_monitor_error(
                "r23_managed_observer_close", error,
                getattr(process, "pid", None)))
        lifecycle_complete = (
            not close_errors and lifecycle_close_receipt is not None and
            lifecycle_close_receipt.get("identity_complete") is True and
            lifecycle_close_receipt.get("exit_proof_complete") is True and
            lifecycle_close_receipt.get("cleanup_complete") is True and
            lifecycle_receipt_files is not None)
        handle_close = {
            "schema": "vnext-t2-r23-managed-lifecycle-close-r1",
            "complete": lifecycle_complete,
            "session_summary": session_summary,
            "session_close_receipt": (dict(lifecycle_close_receipt)
                                      if lifecycle_close_receipt is not None else None),
            "observer_receipts": lifecycle_receipt_files,
            "errors": close_errors,
        }
        if not lifecycle_complete:
            stop_reason = "process_tree_monitor_incomplete"
    else:
        handle_close = registry.close_owned()
        if handle_close.get("complete") is not True:
            stop_reason = "process_tree_monitor_incomplete"
        if process is not None:
            handle_close["popen_original_handle_owner"] = "psutil.Popen"
            handle_close["popen_handle_close_policy"] = \
                "retained_until_phase_return_then_closed_by_Popen_handle_owner"
    total_supervision = time.monotonic() - started
    if total_supervision >= timeout_seconds and stop_reason == "natural_exit":
        stop_reason = "phase_wall_timeout"
    if managed_initial_sample_gate is not None and \
            managed_initial_sample_pending:
        if managed_initial_sample_gate.get("status") == \
                "awaiting_first_complete_sample":
            managed_initial_sample_gate["status"] = \
                "first_full_sample_not_completed_root_not_resumed"
        if stop_reason == "natural_exit":
            stop_reason = "process_tree_monitor_incomplete"
    if process is None:
        residual_audit = residual_audit or {"schema": "vnext-t2-r23-global-heavy-audit-r1",
            "complete": False, "processes": [], "errors": [launch_error]}
        final_tree_audit = final_tree_audit or {
            "schema": "vnext-t2-r23-final-process-tree-audit-r1",
            "complete": False, "root_exit_confirmed": False,
            "residual_descendant_processes": [], "errors": [launch_error]}
    sealed_snapshot_witnesses = tuple(phase_snapshot_witnesses)
    try:
        snapshot_witness_ledger_receipt = {
            **_r23_snapshot_witness_ledger_receipt(sealed_snapshot_witnesses),
            "complete": True,
        }
    except Exception as error:
        snapshot_witness_ledger_receipt = {
            "schema": "vnext-t2-r23-captured-source-witness-ledger-r1",
            "complete": False, "entry_count": len(sealed_snapshot_witnesses),
            "sha256": None,
            "errors": [_monitor_error("r23_source_witness_ledger", error)],
        }
    phase = {
        "schema": "vnext-t2-independent-negative-phase-r6-native-r23",
        "name": name, "command": command, "cwd": str(ROOT),
        "pid": getattr(process, "pid", None),
        "process_create_time": (_R23_TABLE.display_seconds(launch_identity[1])
                                if launch_identity else None),
        "process_create_time_100ns": (launch_identity[1]
                                       if launch_identity else None),
        "started_utc": started_utc, "ended_utc": utc(),
        "seconds": total_supervision,
        "child_seconds": (child_finished - child_started)
            if process is not None else 0.0,
        "total_supervision_seconds": total_supervision,
        "exit_code": exit_code, "stop_reason": stop_reason,
        "timeout_seconds": timeout_seconds,
        "root_launch_identity": launch_receipt,
        "working_set_limit_bytes": working_set_limit_bytes,
        "process_tree_sample_count": len(samples),
        "process_tree_samples_complete": bool(samples) and all(
            row.get("sample_complete") is True for row in samples),
        "terminal_sample_race": terminal_sample_race,
        "sample_handoff_recovery_count": len(sample_handoff_recoveries),
        "sample_handoff_recoveries": sample_handoff_recoveries,
        "tracked_sample_exit_recovery_count": len(tracked_sample_exit_records),
        "tracked_sample_exit_races": tracked_sample_exit_records,
        "pre_tree_tracked_exit_recovery_count": len(pre_tree_tracked_exit_records),
        "pre_tree_tracked_exit_races": pre_tree_tracked_exit_records,
        "membership_growth_record_count": len(membership_growth_records),
        "membership_growth_records": membership_growth_records,
        "terminal_root_sample_exit_count": len(terminal_root_sample_exit_records),
        "terminal_root_sample_exit_races": terminal_root_sample_exit_records,
        "descendant_terminal_root_sample_exit_count":
            len(descendant_terminal_root_sample_exit_records),
        "descendant_terminal_root_sample_exit_races":
            descendant_terminal_root_sample_exit_records,
        "native_snapshot_pid_history_schema":
            "vnext-t2-r23-phase-snapshot-pid-history-r2",
        "native_snapshot_pid_history": phase_snapshot_history,
        "native_snapshot_source_witnesses_schema":
            "vnext-t2-r23-captured-source-witnesses-r1",
        "native_snapshot_source_witnesses": list(sealed_snapshot_witnesses),
        "native_snapshot_source_witness_ledger": snapshot_witness_ledger_receipt,
        "membership_growth_observed_generations": [
            item for record in membership_growth_records
            for item in record.get("observed_generations", [])],
        "unbound_observed_generations": [
            item for record in sample_handoff_recoveries
            for item in record.get("observed_generations", [])],
        "unbound_observation_final_audit": (final_tree_audit or {}).get(
            "unbound_observation_final_audit"),
        "tracked_sample_exit_final_audit": (final_tree_audit or {}).get(
            "tracked_sample_exit_final_audit"),
        "pre_tree_tracked_exit_final_audit": (final_tree_audit or {}).get(
            "pre_tree_tracked_exit_final_audit"),
        "membership_growth_final_audit": (final_tree_audit or {}).get(
            "membership_growth_final_audit"),
        "terminal_root_sample_exit_final_audit": (final_tree_audit or {}).get(
            "terminal_root_sample_exit_final_audit"),
        "descendant_terminal_root_sample_exit_final_audit":
            (final_tree_audit or {}).get(
                "descendant_terminal_root_sample_exit_final_audit"),
        "tracked_process_identity_count": len(tracked),
        "tracked_process_identities_raw": [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(tracked)],
        "exact_exit_receipts": exit_receipts,
        "termination_receipt": termination_receipt,
        "final_process_tree_audit": final_tree_audit,
        "residual_process_audit": residual_audit,
        "peak_process_tree_working_set_bytes": max((
            row.get("process_tree_working_set_bytes", 0) for row in samples), default=0),
        "final_sample_process_tree_user_cpu_seconds": (
            samples[-1].get("process_tree_user_cpu_seconds", 0.0) if samples else 0.0),
        "final_sample_process_tree_system_cpu_seconds": (
            samples[-1].get("process_tree_system_cpu_seconds", 0.0) if samples else 0.0),
        "monitor_source_pins": {
            "native_process_table": {"path": _R23_TABLE_PATH.relative_to(ROOT).as_posix(),
                                      "sha256": _R23_TABLE_SHA256},
            "supervisor": {"path": _R23_SUPERVISOR_PATH.relative_to(ROOT).as_posix(),
                           "sha256": _R23_SUPERVISOR_SHA256},
            "load_mode": "hash-pinned compile-exec; no pyc read/write",
        },
        "managed_lifecycle": (None if lifecycle_observer is None else {
            "schema": "vnext-t2-r23-managed-lifecycle-phase-r1",
            "complete": handle_close.get("complete") is True,
            "directory": (str(lifecycle_directory.resolve())
                          if lifecycle_directory is not None else None),
            "protocol_sha256": _R23_ACTIVE_PROTOCOL_SHA256,
            "source_pins": (_R23_ACTIVE_PROTOCOL or {}).get(
                "managed_process_lifecycle_source_pins"),
            "session_summary": handle_close.get("session_summary"),
            "session_close_receipt": handle_close.get("session_close_receipt"),
            "observer_receipts": handle_close.get("observer_receipts"),
            "errors": handle_close.get("errors", []),
        }),
        "handle_close_receipt": handle_close,
        "managed_initial_sample_gate": managed_initial_sample_gate,
        "samples_log": samples_log_receipt,
        "stdout": file_receipt(output / "stdout.raw"),
        "stderr": file_receipt(output / "stderr.raw"),
        "residual_heavy_processes": (residual_audit or {}).get("processes", []),
        "actual_model_attestation": "unavailable",
    }
    write_json_new(output / "phase.json", phase)
    return phase


def require_natural(phase: dict[str, Any], *, exit_zero: bool) -> None:
    _require_natural_legacy_r16(phase, exit_zero=exit_zero)
    launch = phase.get("root_launch_identity")
    authority = launch.get("identity_authority") if isinstance(launch, dict) else None
    allowed_authorities = {
        "raw_PID_FILETIME_100ns_SPI_plus_original_Popen_handle",
        "raw_PID_FILETIME_100ns_SPI_plus_debug_CREATE_ack_and_original_lifecycle_handle",
    }
    if not isinstance(launch, dict) or authority not in allowed_authorities or \
            type(phase.get("process_create_time_100ns")) is not int or \
            launch.get("create_time_100ns") != phase.get("process_create_time_100ns") or \
            phase.get("schema") != "vnext-t2-independent-negative-phase-r6-native-r23":
        raise RuntimeError(f"{phase.get('name')} raw process generation receipt missing")
    if authority == \
            "raw_PID_FILETIME_100ns_SPI_plus_debug_CREATE_ack_and_original_lifecycle_handle":
        startup_gate = phase.get("managed_initial_sample_gate")
        history = phase.get("native_snapshot_pid_history")
        witnesses = phase.get("native_snapshot_source_witnesses")
        sample_log_receipt = phase.get("samples_log")
        startup_sample_valid = isinstance(startup_gate, dict) and \
            startup_gate.get("schema") == \
                "vnext-t2-r23-managed-initial-sample-before-resume-r1" and \
            startup_gate.get("complete") is True and \
            startup_gate.get("status") == \
                "first_full_sample_accepted_then_root_resumed" and \
            startup_gate.get("sample_index") == 1 and \
            startup_gate.get("sample_complete") is True and \
            startup_gate.get("root_resumed_after_sample") is True and \
            startup_gate.get("startup_hold_kind") == "debug_create_event" and \
            startup_gate.get("release_method") == "continue_debug_event" and \
            startup_gate.get("sample_file_flushed") is True and \
            startup_gate.get("sample_file_fsynced") is True and \
            startup_gate.get("root_identity") == {
                "pid": phase.get("pid"),
                "creation_time_100ns": phase.get("process_create_time_100ns")} and \
            type(startup_gate.get("sample_attempt_count")) is int and \
            1 <= startup_gate["sample_attempt_count"] <= \
                R20_MAX_WHOLE_SAMPLE_ATTEMPTS and \
            startup_gate.get(
                "complete_sample_metrics_are_standard_phase_measurements") is True and \
            startup_gate.get("errors") == [] and \
            type(startup_gate.get("source_history_sequence")) is int and \
            startup_gate["source_history_sequence"] >= 0 and \
            type(startup_gate.get("source_attempt_index")) is int and \
            startup_gate["source_attempt_index"] in (1, 2) and \
            isinstance(startup_gate.get("sample_record_sha256"), str) and \
            len(startup_gate["sample_record_sha256"]) == 64 and \
            all(character in "0123456789abcdef" for character in
                startup_gate["sample_record_sha256"]) and \
            isinstance(startup_gate.get("source_history_reference"), dict) and \
            isinstance(startup_gate.get("samples_file"), dict) and \
            set(startup_gate.get("samples_file", {})) == {
                "path", "bytes", "sha256", "flush", "fsync"} and \
            startup_gate["samples_file"].get("flush") is True and \
            startup_gate["samples_file"].get("fsync") is True and \
            phase.get("process_tree_sample_count", 0) >= 1 and \
            phase.get("process_tree_samples_complete") is True and \
            type(sample_log_receipt) is dict and \
            set(sample_log_receipt) == {"path", "bytes", "sha256"} and \
            type(sample_log_receipt.get("path")) is str and \
            type(sample_log_receipt.get("bytes")) is int and \
            sample_log_receipt["bytes"] > 0 and \
            type(sample_log_receipt.get("sha256")) is str
        if startup_sample_valid:
            try:
                sample_log_path = Path(sample_log_receipt["path"])
                stdout_receipt = phase.get("stdout")
                sample_log_bytes = sample_log_path.read_bytes()
                first_sample_line = sample_log_bytes.splitlines(keepends=True)[0]
                if sample_log_path.name != "samples.jsonl" or \
                        file_receipt(sample_log_path) != sample_log_receipt or \
                        not Path(startup_gate["samples_file"].get("path", "")).is_absolute() or \
                        (startup_gate["samples_file"]["path"] !=
                         sample_log_receipt["path"]) or \
                        startup_gate["samples_file"]["bytes"] != len(first_sample_line) or \
                        sha256_bytes(first_sample_line) != \
                            startup_gate["samples_file"]["sha256"] or \
                        not first_sample_line.endswith(b"\n") or \
                        not isinstance(stdout_receipt, dict) or \
                        Path(stdout_receipt.get("path", "")).parent.resolve() != \
                            sample_log_path.parent.resolve():
                    raise RuntimeError("managed startup sample log receipt differs")
                sample_rows = load_jsonl(sample_log_path)
                source_sequence = startup_gate["source_history_sequence"]
                if len(sample_rows) != phase["process_tree_sample_count"] or \
                        not sample_rows or sample_rows[0].get("sample_index") != 1 or \
                        sample_rows[0].get("sample_complete") is not True or \
                        sample_rows[0].get("exact_monitor_receipt", {}).get(
                            "complete") is not True or \
                        sample_rows[0].get("process_tree_working_set_bytes", -1) < 0 or \
                        sample_rows[0].get("process_tree_working_set_bytes", -1) >= \
                            phase.get("working_set_limit_bytes", 0) or \
                        sample_rows[0].get("root_process_identity", {}).get("pid") != \
                            phase.get("pid") or \
                        sample_rows[0].get("root_process_identity", {}).get(
                            "create_time_100ns") != \
                            phase.get("process_create_time_100ns") or \
                        sha256_bytes((json.dumps(
                            sample_rows[0], sort_keys=True) + "\n").encode("utf-8")) != \
                            startup_gate["sample_record_sha256"]:
                    raise RuntimeError("managed startup full sample differs from its row")
                if type(history) is not list or type(witnesses) is not list:
                    raise RuntimeError("managed startup sample history is malformed")
                entries = _r23_validate_snapshot_history(
                    history, witnesses, through_sequence=source_sequence)
                source_entry = entries[source_sequence]
                source_reference = startup_gate["source_history_reference"]
                expected_reference = {
                    "sequence": source_sequence,
                    "snapshot_receipt": source_entry.get("snapshot_receipt"),
                    "pid_set_sha256": source_entry.get("pid_set_sha256"),
                    "prefix_sha256": source_entry.get("prefix_sha256"),
                }
                startup_sample_valid = (
                    set(source_reference) == set(expected_reference) and
                    source_reference == expected_reference and
                    source_entry.get("source_role") == "sample_source_before" and
                    source_entry.get("sample_index") == 1 and
                    source_entry.get("attempt_index") ==
                        startup_gate["source_attempt_index"] and
                    sample_rows[0].get("sample_attempt_count") ==
                        startup_gate["sample_attempt_count"] and
                    len([entry for entry in entries[:source_sequence + 1]
                         if entry.get("source_role") == "outer_reconcile" and
                         entry.get("sample_index") == 1 and
                         entry.get("attempt_index") == 0]) == 1)
            except Exception:
                startup_sample_valid = False
        if startup_sample_valid is not True:
            raise RuntimeError(
                f"{phase.get('name')} managed startup full sample was not proven before root resume")
        managed = phase.get("managed_lifecycle")
        session = managed.get("session_close_receipt") if isinstance(managed, dict) else None
        close = phase.get("handle_close_receipt")
        root_identity = (session.get("root_identity")
                         if isinstance(session, dict) else None)
        observer_receipts = (managed.get("observer_receipts")
                             if isinstance(managed, dict) else None)
        expected_files = {
            "events": "lifecycle_events.jsonl",
            "birth": "birth_measurements.jsonl",
            "resource": "resource_measurements.jsonl",
        }
        observer_files_valid = isinstance(observer_receipts, dict) and \
            set(observer_receipts) == set(expected_files)
        if observer_files_valid:
            directory = Path(str(managed.get("directory"))).resolve()
            observer_files_valid = directory.name == "managed_lifecycle"
            for key, filename in expected_files.items():
                receipt = observer_receipts.get(key)
                if not isinstance(receipt, dict) or \
                        set(receipt) != {"path", "bytes", "sha256"} or \
                        type(receipt.get("path")) is not str or \
                        type(receipt.get("bytes")) is not int or receipt["bytes"] <= 0 or \
                        type(receipt.get("sha256")) is not str or \
                        len(receipt["sha256"]) != 64 or \
                        any(character not in "0123456789abcdef"
                            for character in receipt["sha256"]):
                    observer_files_valid = False
                    break
                observed_path = Path(receipt["path"])
                if observed_path.name != filename or \
                        observed_path.resolve().parent != directory or \
                        file_receipt(observed_path) != receipt:
                    observer_files_valid = False
                    break
        resume_event_valid = False
        if observer_files_valid and isinstance(root_identity, dict):
            try:
                event_rows = load_jsonl(Path(observer_receipts["events"]["path"]))
                resume_events = [row for row in event_rows
                    if row.get("event") == "root_primary_thread_resumed" and
                    row.get("identity") == root_identity]
                resume_event_valid = len(resume_events) == 1
            except Exception:
                resume_event_valid = False
        if not isinstance(managed, dict) or \
                managed.get("schema") != "vnext-t2-r23-managed-lifecycle-phase-r1" or \
                managed.get("complete") is not True or \
                managed.get("protocol_sha256") != _R23_ACTIVE_PROTOCOL_SHA256 or \
                not isinstance(session, dict) or \
                session.get("identity_complete") is not True or \
                session.get("exit_proof_complete") is not True or \
                session.get("cleanup_complete") is not True or \
                not isinstance(root_identity, dict) or \
                root_identity.get("pid") != phase.get("pid") or \
                root_identity.get("creation_time_100ns") != \
                    phase.get("process_create_time_100ns") or \
                session.get("returncode") != phase.get("exit_code") or \
                not isinstance(close, dict) or close.get("complete") is not True or \
                observer_files_valid is not True or resume_event_valid is not True:
            raise RuntimeError(
                f"{phase.get('name')} managed lifecycle identity/exit/resource-log/cleanup proof is incomplete")
    if phase.get("seconds") != phase.get("total_supervision_seconds") or \
            phase.get("total_supervision_seconds", 0) < phase.get("child_seconds", 0):
        raise RuntimeError(f"{phase.get('name')} phase wall budget excludes supervision work")
    monitor_pins = phase.get("monitor_source_pins")
    if not isinstance(monitor_pins, dict) or \
            monitor_pins.get("native_process_table", {}).get("sha256") != _R23_TABLE_SHA256 or \
            monitor_pins.get("supervisor", {}).get("sha256") != _R23_SUPERVISOR_SHA256:
        raise RuntimeError(f"{phase.get('name')} R23 monitor source pins mismatch")


if __name__ == "__main__":
    raise SystemExit(main())
