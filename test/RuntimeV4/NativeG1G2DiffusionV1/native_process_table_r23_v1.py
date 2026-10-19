"""Build-pinned Windows process identities for Native G1/G2 R23.

The process-table record layout is an internal Windows ABI. This module accepts
only the one observed x64 build and fails closed everywhere else. Process
generation identity is the exact raw 100 ns FILETIME creation tick; converted
floating-point seconds are display-only and never authorize membership, wait,
sampling, or a signal.
"""

from __future__ import annotations

import ctypes
import math
import os
import platform
import sys
from dataclasses import dataclass
from typing import Any, Callable, Iterable, Mapping


SCHEMA = "native-g1g2-windows-process-table-r23-v1"
WINDOWS_BUILD_PIN = (10, 0, 26200, "AMD64")
SYSTEM_INFORMATION_CLASS = 5  # SystemProcessInformation
STATUS_INFO_LENGTH_MISMATCH = 0xC0000004
INITIAL_BUFFER_BYTES = 4 * 1024 * 1024
MAX_BUFFER_BYTES = 64 * 1024 * 1024
MAX_QUERY_ATTEMPTS = 8
MAX_ROWS = 1_000_000
MAX_IMAGE_NAME_BYTES = 8192
FILETIME_TICKS_PER_SECOND = 10_000_000
WINDOWS_EPOCH_100NS = 116_444_736_000_000_000

# x64 SYSTEM_PROCESS_INFORMATION prefix and trailing thread records observed on
# Windows 10.0.26200 AMD64. The exact layout is rechecked before every query.
SPI_PREFIX_BYTES = 96
SPI_FIXED_HEADER_BYTES = 256
SYSTEM_THREAD_INFORMATION_BYTES = 80


class ProcessTableError(RuntimeError):
    """The authoritative process inventory or generation binding is incomplete."""


class _UnicodeString(ctypes.Structure):
    _fields_ = [
        ("Length", ctypes.c_ushort),
        ("MaximumLength", ctypes.c_ushort),
        ("_padding", ctypes.c_uint32),
        ("Buffer", ctypes.c_void_p),
    ]


class _SystemProcessInformationPrefix(ctypes.Structure):
    _fields_ = [
        ("NextEntryOffset", ctypes.c_uint32),
        ("NumberOfThreads", ctypes.c_uint32),
        ("WorkingSetPrivateSize", ctypes.c_int64),
        ("HardFaultCount", ctypes.c_uint32),
        ("NumberOfThreadsHighWatermark", ctypes.c_uint32),
        ("CycleTime", ctypes.c_uint64),
        ("CreateTime", ctypes.c_int64),
        ("UserTime", ctypes.c_int64),
        ("KernelTime", ctypes.c_int64),
        ("ImageName", _UnicodeString),
        ("BasePriority", ctypes.c_int32),
        ("UniqueProcessId", ctypes.c_void_p),
        ("InheritedFromUniqueProcessId", ctypes.c_void_p),
    ]


@dataclass(frozen=True, order=True)
class ProcessIdentity:
    pid: int
    create_time_100ns: int

    def __post_init__(self) -> None:
        validate_pid(self.pid, allow_zero=True)
        validate_ticks(self.create_time_100ns)


@dataclass(frozen=True)
class ProcessRow:
    identity: ProcessIdentity
    ppid: int
    name: str

    def __post_init__(self) -> None:
        validate_pid(self.ppid, allow_zero=True)
        if type(self.name) is not str:
            raise ProcessTableError("process image name must be a native string")
        if self.identity.pid == 0:
            if self.ppid != 0 or self.name != "":
                raise ProcessTableError("PID 0 idle sentinel identity is malformed")
        elif not self.name or "\x00" in self.name:
            raise ProcessTableError("non-idle process image name is empty or contains NUL")


@dataclass(frozen=True)
class ProcessTableSnapshot:
    rows: tuple[ProcessRow, ...]
    host_identity: tuple[int, int, int, str]
    buffer_bytes: int
    query_attempts: int
    ntstatus_u32: int = 0
    schema: str = SCHEMA
    complete: bool = True

    def __post_init__(self) -> None:
        validate_snapshot(self)

    @property
    def by_pid(self) -> dict[int, ProcessRow]:
        return {row.identity.pid: row for row in self.rows}


def validate_pid(value: Any, *, allow_zero: bool = False) -> int:
    if type(value) is not int or value < (0 if allow_zero else 1) or value > 0xFFFFFFFF:
        raise ProcessTableError("PID must be a native unsigned 32-bit integer")
    return value


def validate_ticks(value: Any) -> int:
    if type(value) is not int or value <= 0 or value > (1 << 63) - 1:
        raise ProcessTableError("creation FILETIME must be a positive native signed-64 integer")
    return value


def validate_identity(value: Any) -> tuple[int, int]:
    if isinstance(value, ProcessIdentity):
        value = (value.pid, value.create_time_100ns)
    if type(value) not in (tuple, list) or len(value) != 2:
        raise ProcessTableError("identity must be a two-field PID/ticks pair")
    return validate_pid(value[0]), validate_ticks(value[1])


def display_seconds(create_time_100ns: int) -> float:
    ticks = validate_ticks(create_time_100ns)
    return (ticks - WINDOWS_EPOCH_100NS) / FILETIME_TICKS_PER_SECOND


def _validate_host_identity(host_identity: Any) -> tuple[int, int, int, str]:
    if type(host_identity) not in (tuple, list) or len(host_identity) != 4:
        raise ProcessTableError("host identity is malformed")
    major, minor, build, machine = host_identity
    if type(major) is not int or type(minor) is not int or type(build) is not int or \
            type(machine) is not str:
        raise ProcessTableError("host identity fields have invalid native types")
    observed = (major, minor, build, machine.upper())
    if observed != WINDOWS_BUILD_PIN:
        raise ProcessTableError("unsupported Windows process-table build/architecture")
    return observed


def _validate_abi() -> None:
    expected = (
        ctypes.sizeof(ctypes.c_void_p) == 8 and
        ctypes.sizeof(_UnicodeString) == 16 and
        ctypes.sizeof(_SystemProcessInformationPrefix) == SPI_PREFIX_BYTES and
        _SystemProcessInformationPrefix.CreateTime.offset == 32 and
        _SystemProcessInformationPrefix.ImageName.offset == 56 and
        _SystemProcessInformationPrefix.UniqueProcessId.offset == 80 and
        _SystemProcessInformationPrefix.InheritedFromUniqueProcessId.offset == 88
    )
    if not expected:
        raise ProcessTableError("unsupported native SYSTEM_PROCESS_INFORMATION prefix ABI")


def _pointer_value(value: Any) -> int:
    return 0 if value is None else int(value)


def parse_spi_buffer(buffer: Any, used_bytes: int, *, host_identity: Any) -> ProcessTableSnapshot:
    """Parse a single bounded class-5 response, rejecting malformed records."""
    _validate_abi()
    host = _validate_host_identity(host_identity)
    if type(used_bytes) is not int or used_bytes < SPI_FIXED_HEADER_BYTES or used_bytes > MAX_BUFFER_BYTES:
        raise ProcessTableError("returned process-table byte count is truncated or out of bounds")
    try:
        allocation_bytes = ctypes.sizeof(buffer)
        base = ctypes.addressof(buffer)
    except Exception as exc:
        raise ProcessTableError("process-table buffer is not an owned ctypes allocation") from exc
    if used_bytes > allocation_bytes:
        raise ProcessTableError("returned process-table byte count exceeds owned allocation")

    rows: list[ProcessRow] = []
    seen: set[int] = set()
    offset = 0
    while True:
        if len(rows) >= MAX_ROWS or offset % 8 or \
                offset + SPI_PREFIX_BYTES > used_bytes:
            raise ProcessTableError("process-table prefix bounds/alignment are invalid")
        record_address = base + offset
        record = _SystemProcessInformationPrefix.from_address(record_address)
        next_offset = int(record.NextEntryOffset)
        thread_count = int(record.NumberOfThreads)
        if thread_count < 0 or thread_count > 100_000:
            raise ProcessTableError("process-table thread count is outside the frozen bound")
        record_end = offset + next_offset if next_offset else used_bytes
        span = record_end - offset
        minimum_span = SPI_FIXED_HEADER_BYTES + thread_count * SYSTEM_THREAD_INFORMATION_BYTES
        if record_end > used_bytes or span < minimum_span or \
                (next_offset and (next_offset % 8 or next_offset <= 0)):
            raise ProcessTableError("process-table full record/thread array is truncated or malformed")

        pid = _pointer_value(record.UniqueProcessId)
        ppid = _pointer_value(record.InheritedFromUniqueProcessId)
        ticks = int(record.CreateTime)
        validate_pid(pid, allow_zero=True)
        validate_pid(ppid, allow_zero=True)
        validate_ticks(ticks)
        if pid in seen:
            raise ProcessTableError(f"duplicate PID in one process-table snapshot: {pid}")
        seen.add(pid)

        image_length = int(record.ImageName.Length)
        image_maximum = int(record.ImageName.MaximumLength)
        image_pointer = _pointer_value(record.ImageName.Buffer)
        if image_length < 0 or image_maximum < image_length or \
                image_length % 2 or image_length > MAX_IMAGE_NAME_BYTES:
            raise ProcessTableError(f"UNICODE_STRING length is malformed for PID {pid}")
        if image_length:
            lower = base + offset + minimum_span
            upper = base + record_end
            if image_pointer < lower or image_pointer + image_length > upper:
                raise ProcessTableError(f"image buffer escapes its bounded process record for PID {pid}")
            try:
                name = ctypes.string_at(image_pointer, image_length).decode("utf-16le", errors="strict")
            except Exception as exc:
                raise ProcessTableError(f"image name is not valid UTF-16LE for PID {pid}") from exc
        else:
            if pid != 0 or image_pointer not in (0, record_address + 64):
                raise ProcessTableError(f"empty image name is only valid for exact idle sentinel PID 0")
            name = ""
        row = ProcessRow(ProcessIdentity(pid, ticks), ppid, name)
        rows.append(row)

        if next_offset == 0:
            break
        if offset + next_offset <= offset or offset + next_offset + SPI_PREFIX_BYTES > used_bytes:
            raise ProcessTableError("NextEntryOffset does not advance to a bounded process record")
        offset += next_offset

    if not rows:
        raise ProcessTableError("native process table has no records")
    return ProcessTableSnapshot(
        rows=tuple(rows), host_identity=host, buffer_bytes=used_bytes,
        query_attempts=1, ntstatus_u32=0,
    )


def validate_snapshot(snapshot: Any) -> ProcessTableSnapshot:
    if not isinstance(snapshot, ProcessTableSnapshot):
        raise ProcessTableError("process table is not a typed snapshot")
    if snapshot.schema != SCHEMA or snapshot.complete is not True:
        raise ProcessTableError("process table schema/completeness is invalid")
    _validate_host_identity(snapshot.host_identity)
    if type(snapshot.buffer_bytes) is not int or not SPI_FIXED_HEADER_BYTES <= snapshot.buffer_bytes <= MAX_BUFFER_BYTES:
        raise ProcessTableError("process-table buffer size is invalid")
    if type(snapshot.query_attempts) is not int or not 1 <= snapshot.query_attempts <= MAX_QUERY_ATTEMPTS:
        raise ProcessTableError("process-table attempt count is invalid")
    if type(snapshot.ntstatus_u32) is not int or snapshot.ntstatus_u32 != 0:
        raise ProcessTableError("native process-table query did not return NTSTATUS success")
    if type(snapshot.rows) is not tuple or not snapshot.rows:
        raise ProcessTableError("process-table rows must be a nonempty immutable tuple")
    seen: set[int] = set()
    for row in snapshot.rows:
        if not isinstance(row, ProcessRow):
            raise ProcessTableError("process-table contains an untyped row")
        identity = (validate_pid(row.identity.pid, allow_zero=True),
                    validate_ticks(row.identity.create_time_100ns))
        validate_pid(row.ppid, allow_zero=True)
        if identity[0] in seen:
            raise ProcessTableError("process-table contains a duplicate PID")
        seen.add(identity[0])
    by_pid = {row.identity.pid: row for row in snapshot.rows}
    idle, system = by_pid.get(0), by_pid.get(4)
    if idle is None or system is None or \
            idle.ppid != 0 or idle.name != "" or \
            system.ppid != 0 or system.name != "System" or \
            idle.identity.create_time_100ns != system.identity.create_time_100ns:
        raise ProcessTableError("PID 0/PID 4 exact OS sentinel rows are absent or inconsistent")
    return snapshot


def query_native_process_table() -> ProcessTableSnapshot:
    """Read a complete SPI class-5 table on the one pinned Windows build."""
    if os.name != "nt":
        raise ProcessTableError("native process-table provider is Windows-only")
    try:
        version = sys.getwindowsversion()
        host = _validate_host_identity((version.major, version.minor, version.build,
                                        platform.machine().upper()))
        _validate_abi()
        ntdll = ctypes.WinDLL("ntdll", use_last_error=True)
        query = ntdll.NtQuerySystemInformation
        query.argtypes = [ctypes.c_int, ctypes.c_void_p, ctypes.c_ulong,
                          ctypes.POINTER(ctypes.c_ulong)]
        query.restype = ctypes.c_long
    except Exception as exc:
        raise ProcessTableError("native process-table host/API preflight failed") from exc

    size = INITIAL_BUFFER_BYTES
    for attempt in range(1, MAX_QUERY_ATTEMPTS + 1):
        if size > MAX_BUFFER_BYTES:
            break
        buffer = ctypes.create_string_buffer(size)
        returned = ctypes.c_ulong(0)
        status = int(query(SYSTEM_INFORMATION_CLASS, ctypes.byref(buffer), size,
                           ctypes.byref(returned)))
        status_u32 = ctypes.c_uint32(status).value
        if status_u32 == 0:
            used = int(returned.value)
            snapshot = parse_spi_buffer(buffer, used, host_identity=host)
            return ProcessTableSnapshot(
                rows=snapshot.rows, host_identity=host,
                buffer_bytes=snapshot.buffer_bytes, query_attempts=attempt,
                ntstatus_u32=status_u32,
            )
        if status_u32 != STATUS_INFO_LENGTH_MISMATCH:
            raise ProcessTableError(f"NtQuerySystemInformation failed: NTSTATUS 0x{status_u32:08x}")
        requested = int(returned.value)
        if requested <= size or requested > MAX_BUFFER_BYTES:
            requested = size * 2
        size = max(size * 2, requested + 4096)
    raise ProcessTableError("native process-table query exceeded bounded size/retry contract")


def require_same_identity(actual: Any, expected: Any, *, phase: str) -> tuple[int, int]:
    """Type-check both operands before exact equality; bool/int aliases fail."""
    actual_id = validate_identity(actual)
    expected_id = validate_identity(expected)
    if actual_id != expected_id:
        raise ProcessTableError(f"{phase}: raw process generation mismatch")
    return actual_id


def require_handle_matches_table(
    handle: Any,
    expected_identity: Any,
    snapshot: ProcessTableSnapshot,
    *,
    handle_identity_reader: Callable[[Any], tuple[int, int]],
) -> tuple[int, int]:
    """Require exact PID+FILETIME equality in table and native handle evidence."""
    expected = validate_identity(expected_identity)
    table = validate_snapshot(snapshot)
    row = table.by_pid.get(expected[0])
    if row is None:
        raise ProcessTableError("expected process PID is absent from authoritative snapshot")
    require_same_identity((row.identity.pid, row.identity.create_time_100ns), expected,
                         phase="process-table")
    try:
        observed = handle_identity_reader(handle)
    except Exception as exc:
        raise ProcessTableError("raw process-handle generation read failed") from exc
    return require_same_identity(observed, expected, phase="process-handle")


def _raw_handle_value(handle_value: Any, *, phase: str) -> int:
    """Normalize only documented, exact handle representations.

    CPython's Windows ``Popen._handle`` is a ``subprocess.Handle`` wrapper,
    which is int-convertible but is not itself an ``int`` or ``c_void_p``.
    Accept that exact runtime type on Windows; never invoke arbitrary
    ``__int__``/``value`` attributes supplied by caller objects.
    """
    if type(handle_value) is int:
        raw = handle_value
    elif type(handle_value) is ctypes.c_void_p:
        raw = handle_value.value
    elif os.name == "nt":
        import subprocess
        handle_type = getattr(subprocess, "Handle", None)
        if handle_type is None or type(handle_value) is not handle_type:
            raise ProcessTableError(f"{phase} handle has an unsupported exact type")
        try:
            raw = int(handle_value)
        except Exception as exc:
            raise ProcessTableError(f"{phase} subprocess.Handle conversion failed") from exc
    else:
        raise ProcessTableError(f"{phase} handle has an unsupported exact type")
    if type(raw) is not int or raw <= 0:
        raise ProcessTableError(f"{phase} handle is null or malformed")
    return raw


def read_process_handle_identity(handle_value: Any) -> tuple[int, int]:
    """Return exact (PID, raw creation FILETIME ticks) from a Windows handle."""
    if os.name != "nt":
        raise ProcessTableError("process-handle generation API is Windows-only")
    from ctypes import wintypes

    class _FILETIME(ctypes.Structure):
        _fields_ = [("dwLowDateTime", wintypes.DWORD), ("dwHighDateTime", wintypes.DWORD)]

    raw_handle = _raw_handle_value(handle_value, phase="identity")
    handle = wintypes.HANDLE(raw_handle)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetProcessId.argtypes = [wintypes.HANDLE]
    kernel32.GetProcessId.restype = wintypes.DWORD
    kernel32.GetProcessTimes.argtypes = [
        wintypes.HANDLE, ctypes.POINTER(_FILETIME), ctypes.POINTER(_FILETIME),
        ctypes.POINTER(_FILETIME), ctypes.POINTER(_FILETIME),
    ]
    kernel32.GetProcessTimes.restype = wintypes.BOOL
    pid = int(kernel32.GetProcessId(handle))
    if pid <= 0:
        raise ctypes.WinError(ctypes.get_last_error())
    creation = _FILETIME()
    exit_time = _FILETIME()
    kernel_time = _FILETIME()
    user_time = _FILETIME()
    if not kernel32.GetProcessTimes(
            handle, ctypes.byref(creation), ctypes.byref(exit_time),
            ctypes.byref(kernel_time), ctypes.byref(user_time)):
        raise ctypes.WinError(ctypes.get_last_error())
    ticks = (int(creation.dwHighDateTime) << 32) | int(creation.dwLowDateTime)
    return validate_identity((pid, ticks))


def open_exact_process_handle(
    row: ProcessRow,
    *,
    access: int = 0x00100000 | 0x0001 | 0x1000,  # SYNCHRONIZE | TERMINATE | QUERY_LIMITED_INFORMATION
    identity_reader: Callable[[Any], tuple[int, int]] = read_process_handle_identity,
) -> int:
    """Open a handle with query/terminate/wait rights and bind it to exact row."""
    if os.name != "nt":
        raise ProcessTableError("OpenProcess is Windows-only")
    if not isinstance(row, ProcessRow) or row.identity.pid <= 0:
        raise ProcessTableError("only a positive non-sentinel process row can be opened")
    if type(access) is not int or access <= 0:
        raise ProcessTableError("process handle access mask is malformed")
    from ctypes import wintypes
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
    kernel32.OpenProcess.restype = wintypes.HANDLE
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    handle = kernel32.OpenProcess(access, False, row.identity.pid)
    if not handle:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        raw_handle = _raw_handle_value(handle, phase="OpenProcess")
    except ProcessTableError:
        kernel32.CloseHandle(handle)
        raise
    try:
        require_same_identity(identity_reader(raw_handle),
                             (row.identity.pid, row.identity.create_time_100ns),
                             phase="OpenProcess")
        return raw_handle
    except Exception:
        if not kernel32.CloseHandle(handle):
            raise ctypes.WinError(ctypes.get_last_error())
        raise


def close_process_handle(handle_value: int) -> None:
    if os.name != "nt":
        raise ProcessTableError("CloseHandle is Windows-only")
    if type(handle_value) is not int or handle_value <= 0:
        raise ProcessTableError("process handle is malformed")
    from ctypes import wintypes
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
    kernel32.CloseHandle.restype = wintypes.BOOL
    if not kernel32.CloseHandle(wintypes.HANDLE(handle_value)):
        raise ctypes.WinError(ctypes.get_last_error())


def terminate_process_handle(handle_value: Any, *, exit_code: int = 15) -> None:
    """Terminate the already generation-bound handle, never a PID lookup."""
    if os.name != "nt":
        raise ProcessTableError("TerminateProcess is Windows-only")
    if type(exit_code) is not int or exit_code < 0 or exit_code > 0xFFFFFFFF:
        raise ProcessTableError("termination exit code must be a native unsigned 32-bit integer")
    from ctypes import wintypes
    raw = _raw_handle_value(handle_value, phase="termination")
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
    kernel32.TerminateProcess.restype = wintypes.BOOL
    if not kernel32.TerminateProcess(wintypes.HANDLE(raw), exit_code):
        raise ctypes.WinError(ctypes.get_last_error())


def wait_for_process_exit(handle_value: Any, timeout_seconds: float) -> bool:
    """Wait on the same bound handle; never wait by PID/create_time projection."""
    if os.name != "nt":
        raise ProcessTableError("WaitForSingleObject is Windows-only")
    if type(timeout_seconds) not in (int, float) or isinstance(timeout_seconds, bool) or \
            not math.isfinite(float(timeout_seconds)) or timeout_seconds <= 0 or timeout_seconds > 60:
        raise ProcessTableError("native wait timeout must be finite, positive, and at most 60s")
    from ctypes import wintypes
    raw = _raw_handle_value(handle_value, phase="wait")
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
    kernel32.WaitForSingleObject.restype = wintypes.DWORD
    timeout_ms = int(math.ceil(float(timeout_seconds) * 1000.0))
    result = int(kernel32.WaitForSingleObject(wintypes.HANDLE(raw), timeout_ms))
    if result == 0:  # WAIT_OBJECT_0
        return True
    if result == 258:  # WAIT_TIMEOUT
        return False
    raise ctypes.WinError(ctypes.get_last_error())


def process_exit_code(handle_value: Any) -> int:
    """Read exit code from an exact waited handle; reject STILL_ACTIVE."""
    if os.name != "nt":
        raise ProcessTableError("GetExitCodeProcess is Windows-only")
    from ctypes import wintypes
    raw = _raw_handle_value(handle_value, phase="exit-code")
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
    kernel32.GetExitCodeProcess.restype = wintypes.BOOL
    code = wintypes.DWORD(0)
    if not kernel32.GetExitCodeProcess(wintypes.HANDLE(raw), ctypes.byref(code)):
        raise ctypes.WinError(ctypes.get_last_error())
    if int(code.value) == 259:  # STILL_ACTIVE
        raise ProcessTableError("process handle remains active after wait")
    return int(code.value)


def descendant_identities(
    snapshot: ProcessTableSnapshot,
    root_identity: Any,
    *,
    previously_tracked: Iterable[Any] = (),
) -> tuple[ProcessIdentity, ...]:
    """Build a bounded PPID tree, checking chronology and PID reuse explicitly."""
    table = validate_snapshot(snapshot)
    root = validate_identity(root_identity)
    by_pid = table.by_pid
    root_row = by_pid.get(root[0])
    if root_row is None:
        raise ProcessTableError("root process is absent from process table")
    require_same_identity((root_row.identity.pid, root_row.identity.create_time_100ns),
                         root, phase="tree-root")

    tracked: dict[int, ProcessIdentity] = {root[0]: root_row.identity}
    for value in previously_tracked:
        pid, ticks = validate_identity(value)
        prior = ProcessIdentity(pid, ticks)
        current = by_pid.get(pid)
        if current is None:
            raise ProcessTableError("previously tracked process is missing; exit receipt required")
        require_same_identity((current.identity.pid, current.identity.create_time_100ns),
                             (pid, ticks), phase="tracked-descendant")
        tracked[pid] = prior

    changed = True
    while changed:
        changed = False
        for row in table.rows:
            if row.identity.pid in tracked or row.ppid not in tracked:
                continue
            parent = tracked[row.ppid]
            if row.identity.create_time_100ns < parent.create_time_100ns:
                raise ProcessTableError("parent PID points to a newer generation; ancestry is ambiguous")
            tracked[row.identity.pid] = row.identity
            changed = True
    # Any child pointing at the monitored PID but older than its bound generation
    # is a possible PID-reuse alias, not safe evidence that it is unrelated.
    for row in table.rows:
        parent = tracked.get(row.ppid)
        if parent is not None and row.identity.pid not in tracked and \
                row.identity.create_time_100ns < parent.create_time_100ns:
            raise ProcessTableError("child predates the bound parent generation")
    return tuple(sorted(tracked.values()))


def native_snapshot_digest(snapshot: ProcessTableSnapshot) -> tuple[tuple[int, int, int, str], ...]:
    """Stable exact-identity projection useful for read-only audit receipts."""
    table = validate_snapshot(snapshot)
    return tuple(sorted(
        (row.identity.pid, row.ppid, row.identity.create_time_100ns, row.name)
        for row in table.rows
    ))


def smoke_summary(snapshot: ProcessTableSnapshot) -> dict[str, Any]:
    table = validate_snapshot(snapshot)
    by_pid = table.by_pid
    return {
        "schema": SCHEMA,
        "complete": True,
        "host_identity": list(table.host_identity),
        "system_information_class": SYSTEM_INFORMATION_CLASS,
        "buffer_bytes": table.buffer_bytes,
        "query_attempts": table.query_attempts,
        "row_count": len(table.rows),
        "abi": {
            "pointer_size_bytes": ctypes.sizeof(ctypes.c_void_p),
            "unicode_string_size_bytes": ctypes.sizeof(_UnicodeString),
            "spi_prefix_size_bytes": ctypes.sizeof(_SystemProcessInformationPrefix),
            "spi_fixed_header_bytes": SPI_FIXED_HEADER_BYTES,
            "thread_information_bytes": SYSTEM_THREAD_INFORMATION_BYTES,
            "offsets": {
                "CreateTime": _SystemProcessInformationPrefix.CreateTime.offset,
                "ImageName": _SystemProcessInformationPrefix.ImageName.offset,
                "UniqueProcessId": _SystemProcessInformationPrefix.UniqueProcessId.offset,
                "InheritedFromUniqueProcessId": _SystemProcessInformationPrefix.InheritedFromUniqueProcessId.offset,
            },
        },
        "sentinels": {
            str(pid): {
                "ppid": by_pid[pid].ppid,
                "name": by_pid[pid].name,
                "create_time_100ns": by_pid[pid].identity.create_time_100ns,
            }
            for pid in (0, 4) if pid in by_pid
        },
    }
