from __future__ import annotations

import argparse
import ctypes
from collections import Counter
import csv
from datetime import datetime
import hashlib
import io
import json
import math
import os
import platform
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback
from typing import Any

import psutil


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
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
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r10.py"
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


def git_head() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    return result.stdout.strip()


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
        with (output / "samples.jsonl").open(
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
    actual = file_receipt(path)
    if actual["sha256"] != expected_sha256.lower():
        raise RuntimeError("negative protocol SHA-256 mismatch")
    protocol = load_json(path)
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r8":
        raise RuntimeError("negative protocol schema mismatch")
    if protocol.get("repository_head") != EXPECTED_HEAD:
        raise RuntimeError("negative protocol HEAD mismatch")
    for relative, expected in protocol["inputs"].items():
        current = file_receipt(ROOT / relative)
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
    return {relative: file_receipt(ROOT / relative)
            for relative in sorted(protocol["inputs"])}


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
    protocol_path = Path(args.protocol).resolve()
    protocol_path.relative_to(ROOT)
    positive_root = Path(args.positive_evidence).resolve()
    positive_root.relative_to(ROOT)
    output = Path(args.evidence_dir).resolve()
    require_t2_execution_leaf(output)
    output.mkdir(parents=True, exist_ok=False)

    protocol = verify_protocol(protocol_path, args.protocol_sha256)
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
    head_before = git_head()
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
        if git_head() != head_before:
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
        head_after = git_head()
        residual_audit = heavy_processes()
        residual = residual_audit.get("processes", [])
        guard = pipeline_pass and failure is None and \
            input_after_error is None and inputs_after_final == inputs_before and \
            head_after == head_before and \
            residual_audit.get("complete") is True and not residual
        final = {
            "schema": "vnext-t2-independent-negative-pipeline-final-r4",
            "status": "pass" if guard else "fail",
            "repository_head_before": head_before,
            "repository_head_after": head_after,
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

    print(json.dumps({
        "status": "pass", "pipeline_final":
            file_receipt(output / "pipeline_final.json"),
        "formal_t2_accepted": False,
    }, sort_keys=True), flush=True)
    print("VNEXT_T2_INDEPENDENT_NEGATIVES=PASS", flush=True)
    return 0


_R23_TABLE_PATH = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
_R23_SUPERVISOR_PATH = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
_R23_TABLE_SHA256 = "b18136c52df644579e05d52a82f98541ac95a85de9be56cdae6d52baa8af74e4"
_R23_SUPERVISOR_SHA256 = "ed38b5e1d9d7c506bd8db4c311948601fbb12be47ac68e2d3e4ac2e710342192"


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


def _r23_final_audit(root_identity: Any, tracked: list[tuple[int, int]],
                     snapshot: Any, *, root_exit_confirmed: bool,
                     unbound_observation_records: list[dict[str, Any]] | None = None) -> dict[str, Any]:
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
    residual_audit = _R23_SUPERVISOR.audit_residual_identities(tracked, table)
    heavy = _r23_exact_heavy_audit(table)
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
        "global_heavy_process_audit": heavy,
        "errors": errors,
    }


def _r23_exact_heavy_audit(snapshot: Any | None = None) -> dict[str, Any]:
    try:
        table = _R23_TABLE.validate_snapshot(
            snapshot if snapshot is not None else _R23_TABLE.query_native_process_table())
        heavy = list(_R23_SUPERVISOR.global_heavy_processes(table))
        controller_rows: list[dict[str, Any]] = []
        errors: list[dict[str, Any]] = []
        handles: list[Any] = []
        try:
            for row in table.rows:
                if row.identity.pid == os.getpid() or \
                        not row.name.casefold().startswith("python"):
                    continue
                identity = _r23_raw_identity(row)
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
                **NO_NUMERICAL_CREDIT}


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
            _R23_TABLE.read_process_handle_identity(process._handle), identity,
            phase="stage-root original Popen handle")
        return process._handle
    handles = getattr(registry, "_handles", None)
    handle = handles.get(identity) if isinstance(handles, dict) else None
    if handle is None:
        raise _R23_TABLE.ProcessTableError("tracked exact process handle is unavailable")
    _R23_TABLE.require_same_identity(
        _R23_TABLE.read_process_handle_identity(handle), identity,
        phase="tracked original process handle")
    return handle


def _r23_wait_gone(identity: tuple[int, int], handle: Any,
                    *, timeout_seconds: float) -> dict[str, Any]:
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
                **NO_NUMERICAL_CREDIT}


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
                       deadline_monotonic: float) -> dict[str, Any]:
    recovery_records: list[dict[str, Any]] = []
    final_exact: dict[str, Any] = {}
    final_bound_handles: dict[tuple[int, int], Any] = {}
    attempts_used = 0
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
                **NO_NUMERICAL_CREDIT,
            }
            break

        attempt_state: dict[str, Any] = {
            "first_snapshot": None,
            "unbound_race": None,
        }
        bound_handles: dict[tuple[int, int], Any] = {}

        def snapshot_provider() -> Any:
            snapshot = _R23_TABLE.validate_snapshot(
                _R23_TABLE.query_native_process_table())
            if attempt_state["first_snapshot"] is None:
                attempt_state["first_snapshot"] = snapshot
            return snapshot

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
                    fresh_tables.append(_R23_TABLE.validate_snapshot(
                        _R23_TABLE.query_native_process_table()))
                except Exception as error:
                    query_error = error
                    break

            confirmation_tables = fresh_tables[1:3]
            confirmation_tables.extend([None] * (2 - len(confirmation_tables)))
            recovery = _r20_confirm_unbound_sample_race(
                source, identity, root_identity, previous,
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
                record_unbound_sample_race(
                    identity, open_error,
                    failure_phase="r20_exact_handle_open_or_bind",
                    exact_handle_opened=exact_handle_opened,
                    exact_handle_wait_attempted=exact_handle_wait_attempted,
                    exact_handle_signaled=exact_handle_signaled,
                    exact_handle_identity=exact_handle_identity)
                raise _R23_TABLE.ProcessTableError(
                    "R20 exact handle acquisition/binding/liveness check failed; discard "
                    "sample and require three complete post-failure SPI absence snapshots") \
                    from open_error
            bound_handles[identity] = handle
            return handle

        def sample_resource_reader(pid: int) -> dict[str, Any]:
            try:
                return _r23_resource_reader(pid)
            except Exception as resource_error:
                identity = next((item for item in bound_handles if item[0] == pid), None)
                if identity is None:
                    raise
                handle = bound_handles[identity]
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
                record_unbound_sample_race(
                    identity, resource_error,
                    failure_phase="r20_exact_handle_resource_read_exit",
                    exact_handle_opened=True,
                    exact_handle_wait_attempted=True,
                    exact_handle_signaled=True,
                    exact_handle_identity=exact_handle_identity)
                raise _R23_TABLE.ProcessTableError(
                    "exact generation exited during resource read; discard sample and "
                    "confirm three fresh SPI absence snapshots") from resource_error

        sample_elapsed = elapsed + max(0.0, time.monotonic() - sample_started)
        final_exact = _R23_SUPERVISOR.sample_process_tree(
            root_identity,
            snapshot_provider=snapshot_provider,
            handle_provider=handle_provider,
            resource_reader=sample_resource_reader,
            handle_identity_reader=_R23_TABLE.read_process_handle_identity,
            previously_tracked=previous,
            sample_index=sample_index,
            elapsed_seconds=sample_elapsed)
        if final_exact.get("complete") is not True and \
                attempt_state.get("unbound_race") is None:
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
                    record_unbound_sample_race(
                        identity,
                        _R23_TABLE.ProcessTableError(
                            "exact process handle signaled before sample completion"),
                        failure_phase="r20_exact_handle_post_sample_exit",
                        exact_handle_opened=True,
                        exact_handle_wait_attempted=True,
                        exact_handle_signaled=True,
                        exact_handle_identity=exact_handle_identity)
                    break
        final_bound_handles = bound_handles

        race = attempt_state.get("unbound_race")
        if race is None:
            if final_exact.get("complete") is True:
                for record in recovery_records:
                    record["full_sample_completed_after_retry"] = True
                    record["full_sample_attempt_index"] = attempt_index
                    record["status"] = "recovered_by_new_complete_whole_sample"
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
            "errors": final_exact.get("errors", []),
        }
        race["discarded_attempt"] = discarded
        can_retry = race.get("complete") is True and \
            attempt_index < R20_MAX_WHOLE_SAMPLE_ATTEMPTS and \
            time.monotonic() < deadline_monotonic
        race["retry_started"] = can_retry
        if can_retry:
            recovery_records.append(race)
            continue
        race["status"] = ("unbound_absence_unconfirmed_monitor_incomplete"
                          if race.get("complete") is not True else
                          "retry_exhausted_or_phase_deadline_monitor_incomplete")
        race["full_sample_completed_after_retry"] = False
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
    complete = final_exact.get("complete") is True and not (
        recovery_records and not recovery_records[-1].get(
            "full_sample_completed_after_retry", False))
    no_credit_after_race = bool(recovery_records) and not complete
    if no_credit_after_race:
        rows = []
    sample = {
        "schema": "vnext-t2-process-tree-sample-r3-r20-unbound-race",
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
        "unbound_observed_generations": [item for record in recovery_records
            for item in record.get("observed_generations", [])],
    }
    if recovery_records and no_credit_after_race:
        sample["errors"] = [*sample["errors"], {
            "phase": "r20_unbound_sample_race",
            "type": "MonitorIncomplete",
            "message": "transient generation was not followed by a complete new sample"}]
    if complete and sample["root_identity_match_count"] != 1:
        sample["sample_complete"] = False
        sample["errors"] = [*sample["errors"], {
            "phase": "r20_root_site_count", "type": "RuntimeError",
            "message": "complete exact sample must contain exactly one root"}]
    return sample


def _r23_reconcile_missing_tracked(tracked: set[tuple[int, int]],
                                   registry: Any, process: Any,
                                   snapshot: Any) -> tuple[list[tuple[int, int]], list[dict[str, Any]]]:
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
        receipt = _r23_wait_gone(identity, handle, timeout_seconds=0.01)
        if receipt.get("complete") is not True:
            raise _R23_TABLE.ProcessTableError(
                "missing tracked identity lacks a complete same-handle exit receipt")
        exits.append(receipt)
    return active, exits


def _r23_audit_and_cleanup(process: Any, registry: Any,
                           root_identity: tuple[int, int],
                           tracked: set[tuple[int, int]],
                           root_exit_confirmed: bool,
                           unbound_observation_records: list[dict[str, Any]] | None = None
                           ) -> tuple[dict[str, Any], dict[str, Any] | None]:
    termination: dict[str, Any] | None = None
    actions: list[dict[str, Any]] = []
    unbound_records = (unbound_observation_records
                       if unbound_observation_records is not None else [])
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
        targets[root_identity] = process._handle
        target_sources.setdefault(root_identity, []).append("stage_root")
        tracked.add(root_identity)

    # The exact root is handled through its original Popen handle. Every
    # syntactically valid observed generation remains a cleanup candidate,
    # including previously tracked identities; the registry revalidates any
    # cached handle against the same raw PID+FILETIME before signalling.
    protected_identities = {_R23_TABLE.validate_identity(root_identity)}
    unbound_plan = _r20_unbound_cleanup_plan(
        initial, unbound_records, protected_identities)
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
                            **NO_NUMERICAL_CREDIT},
            })

    unbound_signal_actions = list(unbound_open_failures)
    unbound_signal_by_identity: dict[tuple[int, int], dict[str, Any]] = {}
    if targets:
        for identity, handle in sorted(targets.items(), key=lambda item: item[0][1], reverse=True):
            receipt = _r23_signal_one(identity, handle)
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
            receipt = _r23_signal_one(root_identity, process._handle)
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
                             unbound_observation_records=unbound_observation_records)
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
            receipt = _r23_signal_one(identity, handle)
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
                                 unbound_observation_records=unbound_records)

    # This fresh full-table confirmation explicitly closes every syntactically
    # valid unbound observation and any descendant with a provable live exact
    # parent. PID reuse and orphan chains stay unresolved and cannot pass.
    post_unbound_plan = _r20_unbound_cleanup_plan(
        final_snapshot, unbound_records, protected_identities)
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
                    all(action.get("receipt", {}).get("complete") is True
                        for action in unbound_signal_actions),
        "plan": unbound_plan,
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
    if unbound_records or unbound_target_ids or unbound_open_failures:
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
              environment: dict[str, str], precreated: bool = False) -> dict[str, Any]:
    """Run a phase with exact native PID/FILETIME supervision end-to-end."""
    if type(timeout_seconds) not in (int, float) or isinstance(timeout_seconds, bool) or \
            not math.isfinite(float(timeout_seconds)) or timeout_seconds <= 0 or \
            type(working_set_limit_bytes) is not int or working_set_limit_bytes <= 0:
        raise RuntimeError("R23 phase timeout/working-set limit is malformed")
    timeout_seconds = float(timeout_seconds)
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
    sample_handoff_recoveries: list[dict[str, Any]] = []
    launch_error: dict[str, Any] | None = None
    launch_identity: tuple[int, int] | None = None
    launch_receipt: dict[str, Any] = {"schema": "vnext-t2-r23-launch-identity-r1",
        "complete": False, "identity_authority": "raw_PID_FILETIME_100ns_SPI_plus_Popen_handle"}
    registry = _R23_SUPERVISOR.ExactHandleRegistry()
    process: Any = None
    exit_code: int | None = None
    root_exit_confirmed = False
    with (output / "stdout.raw").open("xb") as stdout, \
            (output / "stderr.raw").open("xb") as stderr:
        with (output / "samples.jsonl").open(
                "x", encoding="utf-8", newline="\n", buffering=1) as sample_file:
            try:
                process = psutil.Popen(
                    command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                    creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
                launch_identity = _R23_TABLE.read_process_handle_identity(process._handle)
                if type(process.pid) is not int or process.pid != launch_identity[0]:
                    raise _R23_TABLE.ProcessTableError(
                        "Popen PID differs from original native process handle")
                launch_snapshot = _R23_TABLE.query_native_process_table()
                registry.bind_popen(process, launch_snapshot)
                root_row = _R23_TABLE.validate_snapshot(launch_snapshot).by_pid.get(
                    launch_identity[0])
                if root_row is None or _r23_raw_identity(root_row) != launch_identity:
                    raise _R23_TABLE.ProcessTableError(
                        "Popen generation is absent from exact native inventory")
                tracked.add(launch_identity)
                active_tracked.add(launch_identity)
                display = _R23_TABLE.display_seconds(launch_identity[1])
                launch_receipt = {
                    "schema": "vnext-t2-r23-launch-identity-r1", "complete": True,
                    "identity_authority": "raw_PID_FILETIME_100ns_SPI_plus_original_Popen_handle",
                    "pid": launch_identity[0], "create_time_100ns": launch_identity[1],
                    "create_time": display, "looked_up_pid": launch_identity[0],
                    "looked_up_create_time": display,
                    "native_snapshot": _r23_snapshot_receipt(launch_snapshot),
                    "helper_sha256": _R23_TABLE_SHA256,
                    "supervisor_sha256": _R23_SUPERVISOR_SHA256,
                }
            except Exception as error:
                launch_error = _monitor_error("r23_launch_generation_bind", error,
                    getattr(process, "pid", None))
                launch_receipt["error"] = launch_error
                stop_reason = "process_tree_monitor_incomplete"

            sample_index = 0
            while process is not None and launch_error is None:
                try:
                    if process.poll() is not None:
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "phase_wall_timeout"
                        break
                    current = _R23_TABLE.query_native_process_table()
                    active, exits = _r23_reconcile_missing_tracked(
                        active_tracked, registry, process, current)
                    exit_receipts.extend(exits)
                    active_tracked = set(active) | {launch_identity}
                    if process.poll() is not None:
                        break
                    sample_index += 1
                    elapsed = time.monotonic() - started
                    sample = _r20_native_sample(
                        process, registry, launch_identity, active,
                        sample_index=sample_index, elapsed=elapsed,
                        deadline_monotonic=started + timeout_seconds)
                    sample_handoff_recoveries.extend(
                        sample.get("sample_handoff_recoveries", []))
                    if sample.get("sample_complete") is not True:
                        errors = sample.get("errors", [])
                        terminal_root_absence = bool(errors) and all(
                            isinstance(error, dict) and
                            error.get("message") ==
                                "root process is absent from process table"
                            for error in errors)
                        if terminal_root_absence and \
                                _R23_TABLE.wait_for_process_exit(
                                    process._handle, 0.05) is True:
                            _R23_TABLE.require_same_identity(
                                _R23_TABLE.read_process_handle_identity(
                                    process._handle), launch_identity,
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
                        samples.append(sample)
                        sample_file.write(json.dumps(sample, sort_keys=True) + "\n")
                        stop_reason = "process_tree_monitor_incomplete"
                        break
                    samples.append(sample)
                    sample_file.write(json.dumps(sample, sort_keys=True) + "\n")
                    receipt = sample.get("exact_monitor_receipt", {})
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
                    time.sleep(min(0.2, max(0.0,
                        timeout_seconds - (time.monotonic() - started))))
                except Exception as error:
                    stop_reason = "process_tree_monitor_incomplete"
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
                                launch_identity, process._handle)
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
                    waited = _R23_TABLE.wait_for_process_exit(
                        process._handle, min(60.0, max(0.01, timeout_seconds)))
                    if waited is not True:
                        raise _R23_TABLE.ProcessTableError(
                            "exact Popen handle wait did not confirm exit")
                    _R23_TABLE.require_same_identity(
                        _R23_TABLE.read_process_handle_identity(process._handle),
                        launch_identity, phase="stage-root post-wait handle")
                    native_code = _R23_TABLE.process_exit_code(process._handle)
                    popen_code = process.wait(timeout=2)
                    if popen_code != native_code:
                        raise _R23_TABLE.ProcessTableError(
                            "Popen and exact native-handle exit codes differ")
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
                        unbound_observation_records=sample_handoff_recoveries)
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
    if process is None:
        residual_audit = residual_audit or {"schema": "vnext-t2-r23-global-heavy-audit-r1",
            "complete": False, "processes": [], "errors": [launch_error]}
        final_tree_audit = final_tree_audit or {
            "schema": "vnext-t2-r23-final-process-tree-audit-r1",
            "complete": False, "root_exit_confirmed": False,
            "residual_descendant_processes": [], "errors": [launch_error]}
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
        "unbound_observed_generations": [
            item for record in sample_handoff_recoveries
            for item in record.get("observed_generations", [])],
        "unbound_observation_final_audit": (final_tree_audit or {}).get(
            "unbound_observation_final_audit"),
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
        "handle_close_receipt": handle_close,
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
    if not isinstance(launch, dict) or \
            launch.get("identity_authority") != \
            "raw_PID_FILETIME_100ns_SPI_plus_original_Popen_handle" or \
            type(phase.get("process_create_time_100ns")) is not int or \
            launch.get("create_time_100ns") != phase.get("process_create_time_100ns") or \
            phase.get("schema") != "vnext-t2-independent-negative-phase-r6-native-r23":
        raise RuntimeError(f"{phase.get('name')} raw process generation receipt missing")
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
