"""Candidate Windows debug-event lifecycle core.

This module is isolated under ``runs/e`` and is not imported by a runner.  It
provides a fakeable native boundary for review; no execution or acceptance
credit is implied.  The code intentionally fails closed when a consumer has
not supplied the ledgered snapshot, handle-first resource, registry, Job, or
exclusive ACK interfaces described below.
"""

from __future__ import annotations

import ctypes
import hashlib
import json
import math
import os
import secrets
import subprocess
import threading
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Mapping, Protocol, Sequence
from ctypes import wintypes as _wintypes


ACK_SCHEMA = "fca-managed-process-ack-v1"
ACK_PUBLICATION_SCHEMA = "fca-managed-ack-publication-v1"
RESOURCE_MEASUREMENT_SCHEMA = "fca-managed-resource-measurement-v1"
LIFECYCLE_SCHEMA = "fca-windows-debug-lifecycle-v1"

CREATE_PROCESS_DEBUG_EVENT = 3
CREATE_THREAD_DEBUG_EVENT = 2
EXIT_THREAD_DEBUG_EVENT = 4
EXIT_PROCESS_DEBUG_EVENT = 5
LOAD_DLL_DEBUG_EVENT = 6
UNLOAD_DLL_DEBUG_EVENT = 7
OUTPUT_DEBUG_STRING_EVENT = 8
RIP_EVENT = 9
EXCEPTION_DEBUG_EVENT = 1
DBG_CONTINUE = 0x00010002
DBG_EXCEPTION_NOT_HANDLED = 0x80010001
EXCEPTION_BREAKPOINT = 0x80000003
EXCEPTION_SINGLE_STEP = 0x80000004
INFINITE = 0xFFFFFFFF
WAIT_OBJECT_0 = 0
WAIT_TIMEOUT = 258
STILL_ACTIVE = 259
DEBUG_PROCESS = 0x00000001
CREATE_UNICODE_ENVIRONMENT = 0x00000400
EXTENDED_STARTUPINFO_PRESENT = 0x00080000
CREATE_NO_WINDOW = 0x08000000
PROC_THREAD_ATTRIBUTE_HANDLE_LIST = 0x00020002
DUPLICATE_SAME_ACCESS = 0x00000002
PROCESS_TERMINATE = 0x0001
PROCESS_VM_READ = 0x0010
PROCESS_QUERY_INFORMATION = 0x0400
PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
SYNCHRONIZE = 0x00100000
JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9
JOB_OBJECT_BASIC_LIMIT_INFORMATION_CLASS = 9
JOB_OBJECT_BASIC_PROCESS_ID_LIST_CLASS = 3
MOVEFILE_WRITE_THROUGH = 0x00000008
FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
STARTF_USESTDHANDLES = 0x00000100
STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
STD_ERROR_HANDLE = -12
FCA_DEADLINE_TICK_ENV = "FCA_MANAGED_DEADLINE_TICK64_MS"
FILE_READ_ATTRIBUTES = 0x0080
FILE_SHARE_READ = 0x00000001
FILE_SHARE_WRITE = 0x00000002
FILE_SHARE_DELETE = 0x00000004
OPEN_EXISTING = 3
FILE_ID_INFO_CLASS = 18


# Keep Win32 event/startup structures at module scope. Nested class bodies do
# not close over sibling names in an enclosing class namespace.
class _FILETIME(ctypes.Structure):
    _fields_ = [("low", ctypes.c_uint32), ("high", ctypes.c_uint32)]


class _FILE_ID_INFO(ctypes.Structure):
    _fields_ = [("VolumeSerialNumber", ctypes.c_uint64),
                ("FileId", ctypes.c_ubyte * 16)]


class _MODULEINFO(ctypes.Structure):
    _fields_ = [("lpBaseOfDll", ctypes.c_void_p),
                ("SizeOfImage", ctypes.c_uint32),
                ("EntryPoint", ctypes.c_void_p)]


class _EXCEPTION_RECORD(ctypes.Structure):
    _fields_ = [("ExceptionCode", ctypes.c_uint32), ("ExceptionFlags", ctypes.c_uint32),
                ("ExceptionRecord", ctypes.c_void_p), ("ExceptionAddress", ctypes.c_void_p),
                ("NumberParameters", ctypes.c_size_t), ("ExceptionInformation", ctypes.c_size_t * 15)]


class _EXCEPTION_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("ExceptionRecord", _EXCEPTION_RECORD), ("dwFirstChance", ctypes.c_uint32)]


class _CREATE_PROCESS_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("hFile", ctypes.c_void_p), ("hProcess", ctypes.c_void_p), ("hThread", ctypes.c_void_p),
                ("lpBaseOfImage", ctypes.c_void_p), ("dwDebugInfoFileOffset", ctypes.c_uint32),
                ("nDebugInfoSize", ctypes.c_uint32), ("lpThreadLocalBase", ctypes.c_void_p),
                ("lpStartAddress", ctypes.c_void_p), ("lpImageName", ctypes.c_void_p),
                ("fUnicode", ctypes.c_uint16)]


class _CREATE_THREAD_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("hThread", ctypes.c_void_p), ("lpThreadLocalBase", ctypes.c_void_p),
                ("lpStartAddress", ctypes.c_void_p)]


class _EXIT_PROCESS_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("dwExitCode", ctypes.c_uint32)]


class _LOAD_DLL_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("hFile", ctypes.c_void_p), ("lpBaseOfDll", ctypes.c_void_p),
                ("dwDebugInfoFileOffset", ctypes.c_uint32), ("nDebugInfoSize", ctypes.c_uint32),
                ("lpImageName", ctypes.c_void_p), ("fUnicode", ctypes.c_uint16)]


class _UNLOAD_DLL_DEBUG_INFO(ctypes.Structure):
    _fields_ = [("lpBaseOfDll", ctypes.c_void_p)]


class _OUTPUT_DEBUG_STRING_INFO(ctypes.Structure):
    _fields_ = [("lpDebugStringData", ctypes.c_void_p), ("fUnicode", ctypes.c_uint16),
                ("nDebugStringLength", ctypes.c_uint16)]


class _RIP_INFO(ctypes.Structure):
    _fields_ = [("dwError", ctypes.c_uint32), ("dwType", ctypes.c_uint32)]


class _DEBUG_UNION(ctypes.Union):
    _fields_ = [("Exception", _EXCEPTION_DEBUG_INFO), ("CreateProcessInfo", _CREATE_PROCESS_DEBUG_INFO),
                ("CreateThread", _CREATE_THREAD_DEBUG_INFO), ("ExitProcess", _EXIT_PROCESS_DEBUG_INFO),
                ("ExitThread", _EXIT_PROCESS_DEBUG_INFO), ("LoadDll", _LOAD_DLL_DEBUG_INFO),
                ("UnloadDll", _UNLOAD_DLL_DEBUG_INFO), ("DebugString", _OUTPUT_DEBUG_STRING_INFO),
                ("RipInfo", _RIP_INFO), ("raw", ctypes.c_byte * 192)]


class _DEBUG_EVENT(ctypes.Structure):
    _fields_ = [("dwDebugEventCode", ctypes.c_uint32), ("dwProcessId", ctypes.c_uint32),
                ("dwThreadId", ctypes.c_uint32), ("u", _DEBUG_UNION)]


class _STARTUPINFO(ctypes.Structure):
    _fields_ = [("cb", _wintypes.DWORD), ("lpReserved", _wintypes.LPWSTR),
                ("lpDesktop", _wintypes.LPWSTR), ("lpTitle", _wintypes.LPWSTR),
                ("dwX", _wintypes.DWORD), ("dwY", _wintypes.DWORD), ("dwXSize", _wintypes.DWORD),
                ("dwYSize", _wintypes.DWORD), ("dwXCountChars", _wintypes.DWORD),
                ("dwYCountChars", _wintypes.DWORD), ("dwFillAttribute", _wintypes.DWORD),
                ("dwFlags", _wintypes.DWORD), ("wShowWindow", _wintypes.WORD),
                ("cbReserved2", _wintypes.WORD), ("lpReserved2", ctypes.POINTER(ctypes.c_ubyte)),
                ("hStdInput", _wintypes.HANDLE), ("hStdOutput", _wintypes.HANDLE),
                ("hStdError", _wintypes.HANDLE)]


class _STARTUPINFOEX(ctypes.Structure):
    _fields_ = [("StartupInfo", _STARTUPINFO), ("lpAttributeList", ctypes.c_void_p)]


class _PROCESS_INFORMATION(ctypes.Structure):
    _fields_ = [("hProcess", _wintypes.HANDLE), ("hThread", _wintypes.HANDLE),
                ("dwProcessId", _wintypes.DWORD), ("dwThreadId", _wintypes.DWORD)]

_RESERVED_ENV = (
    "FCA_MANAGED_SESSION_ID",
    "FCA_MANAGED_ACK_DIRECTORY",
    "FCA_MANAGED_SCOPE_SHA256",
    "FCA_MANAGED_MONITOR_PID",
    "FCA_MANAGED_MONITOR_CREATE_100NS",
    "FCA_MANAGED_HANDSHAKE_SECONDS",
)


class LifecycleError(RuntimeError):
    """Fail-closed lifecycle error with stage and native error evidence."""

    def __init__(self, stage: str, message: str, *, winerror: int | None = None,
                 identity: "ProcessIdentity | None" = None,
                 evidence: Mapping[str, Any] | None = None) -> None:
        super().__init__(f"{stage}: {message}")
        self.stage = stage
        self.message = message
        self.winerror = winerror
        self.identity = identity
        self.evidence = dict(evidence or {})


class BirthPending(LifecycleError):
    """A managed SPI identity has no acknowledged debug CREATE registration."""

    def __init__(self, identity: "ProcessIdentity") -> None:
        super().__init__("birth_pending", "managed identity is not registered; no PID fallback",
                         identity=identity)


class SampleBoundaryChanged(LifecycleError):
    """A CREATE/EXIT event arrived during a whole sample attempt."""


class CleanupIncomplete(LifecycleError):
    """An owned handle could not be closed; it remains retained for retry/audit."""


class BirthRegistrationError(LifecycleError):
    """Registry failure carries explicit retained-handle ownership state."""

    def __init__(self, message: str, *, handle_transferred: bool, cleanup_complete: bool,
                 retained_handle: int, identity: "ProcessIdentity | None" = None,
                 evidence: Mapping[str, Any] | None = None) -> None:
        super().__init__("registry_birth", message, identity=identity,
                         evidence={**dict(evidence or {}), "handle_transferred": handle_transferred,
                                   "cleanup_complete": cleanup_complete,
                                   "retained_handle": retained_handle})
        self.handle_transferred = handle_transferred
        self.cleanup_complete = cleanup_complete
        self.retained_handle = retained_handle


@dataclass(frozen=True, order=True)
class ProcessIdentity:
    pid: int
    creation_time_100ns: int

    def __post_init__(self) -> None:
        if type(self.pid) is not int or not (0 < self.pid <= 0xFFFFFFFF):
            raise ValueError("PID must be a positive native uint32")
        if type(self.creation_time_100ns) is not int or not (0 < self.creation_time_100ns <= (1 << 63) - 1):
            raise ValueError("creation time must be positive signed-64 FILETIME ticks")


@dataclass(frozen=True)
class DebugEvent:
    code: int
    process_id: int
    thread_id: int
    process_handle: int | None = None
    thread_handle: int | None = None
    file_handle: int | None = None
    exit_code: int | None = None
    exception_code: int | None = None
    first_chance: bool | None = None
    raw: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class CreateProcessResult:
    process_handle: int
    thread_handle: int
    pid: int
    thread_id: int
    inherited_stdio: tuple[int | None, int | None, int | None]
    unclosed_temp_handles: tuple[int, ...] = ()
    launch_cleanup_errors: tuple[Mapping[str, Any], ...] = ()


@dataclass(frozen=True)
class BirthSourceWitness:
    """Exact row and the source provider's existing phase-history witness."""

    row: Any
    snapshot: Any
    source_receipt: Mapping[str, Any]


@dataclass(frozen=True)
class AckPublication:
    schema: str
    path: str
    filename: str
    bytes: int
    sha256: str
    exclusive: bool
    flushed: bool


@dataclass(frozen=True)
class RegistrationAck:
    # Exact 16-key wire schema from the root contract.
    schema: str
    session_id: str
    scope_sha256: str
    child_pid: int
    child_creation_time_100ns: int
    parent_pid: int
    parent_creation_time_100ns: int
    monitor_pid: int
    monitor_creation_time_100ns: int
    registration_sequence: int
    handle_duplicated: bool
    identity_registered: bool
    job_bound: bool
    creation_sample_measured: bool
    resume_permitted: bool
    full_run_resource_complete: bool

    @classmethod
    def from_mapping(cls, payload: Mapping[str, Any]) -> "RegistrationAck":
        return _validate_ack_payload(payload)

    def wire(self) -> dict[str, Any]:
        return {
            "schema": self.schema,
            "session_id": self.session_id,
            "scope_sha256": self.scope_sha256,
            "child_pid": self.child_pid,
            "child_creation_time_100ns": self.child_creation_time_100ns,
            "parent_pid": self.parent_pid,
            "parent_creation_time_100ns": self.parent_creation_time_100ns,
            "monitor_pid": self.monitor_pid,
            "monitor_creation_time_100ns": self.monitor_creation_time_100ns,
            "registration_sequence": self.registration_sequence,
            "handle_duplicated": self.handle_duplicated,
            "identity_registered": self.identity_registered,
            "job_bound": self.job_bound,
            "creation_sample_measured": self.creation_sample_measured,
            "resume_permitted": self.resume_permitted,
            "full_run_resource_complete": self.full_run_resource_complete,
        }


@dataclass(frozen=True)
class BirthRecord:
    identity: ProcessIdentity
    parent_identity: ProcessIdentity
    event_pid: int
    source_row: Any
    source_snapshot: Any
    source_snapshot_receipt: Mapping[str, Any]
    session_id: str
    scope_sha256: str
    monitor_identity: ProcessIdentity
    registration_sequence: int
    retained_handle: int
    job_bound: bool
    creation_measurement: Mapping[str, Any]


@dataclass(frozen=True)
class ProcessExitReceipt:
    schema: str
    identity: ProcessIdentity
    debug_event_pid: int
    debug_event_exit_code: int
    pre_continue_measurement: Mapping[str, Any]
    duplicate_handle_wait_result: int
    retained_handle_exit_code: int
    exit_proof_complete: bool
    resource_measurement_complete: bool
    event_sequence: int = 0
    birth_source_sequence: int = 0
    sample_attempt_id: int | None = None


@dataclass(frozen=True)
class SampleAttemptBoundary:
    attempt_id: int
    complete: bool
    membership_changed: bool
    pending_event_codes: tuple[int, ...]
    reason: str | None


@dataclass(frozen=True)
class SampleBoundaryCheckpoint:
    attempt_id: int
    observed: bool
    pending_event_codes: tuple[int, ...]


class LifecycleObserver(Protocol):
    """Consumer-owned, history-aware callbacks; none may reopen a PID."""

    def birth_source_witness(self, pid: int, *, phase: str,
                             event_sequence: int) -> BirthSourceWitness: ...

    def measure_exact_handle(self, handle: int, identity: ProcessIdentity, row: Any, *,
                             phase: str, event_receipt: Mapping[str, Any]) -> Mapping[str, Any]: ...

    def record_birth_measurement(self, measurement: Mapping[str, Any]) -> bool: ...

    def record_resource_measurement(self, measurement: Mapping[str, Any]) -> bool: ...

    def record_lifecycle_event(self, event: Mapping[str, Any]) -> None: ...

    def validate_initial_loader_breakpoint(self, identity: ProcessIdentity, thread_id: int,
                                           exception_address: int | None, exception_code: int,
                                           create_event_thread_id: int) -> bool: ...


class ExactBirthRegistry(Protocol):
    """Adapter implemented by the existing consumer ExactHandleRegistry."""

    @property
    def phase_root(self) -> Path: ...

    @property
    def identities(self) -> Sequence[tuple[int, int]]: ...

    def bind_managed_context(self, managed: "ManagedEnvironment") -> None: ...

    def register_birth(self, record: BirthRecord, *, ack_type: type[RegistrationAck],
                       ack_publisher: Callable[[Mapping[str, Any]], AckPublication]) -> RegistrationAck: ...

    def handle_for(self, identity: ProcessIdentity) -> int: ...

    def unregister_and_close_birth(self, identity: ProcessIdentity, *, sequence: int) -> Mapping[str, Any]: ...


@dataclass(frozen=True)
class ManagedEnvironment:
    session_id: str
    ack_directory: Path
    scope_sha256: str
    monitor_identity: ProcessIdentity
    handshake_seconds: float
    absolute_deadline_tick64_ms: int


def _child_environment(env: Mapping[str, str] | None, managed: ManagedEnvironment) -> dict[str, str]:
    """Preserve caller entries while binding only the auxiliary absolute deadline."""
    source = os.environ if env is None else env
    if not isinstance(source, Mapping):
        raise LifecycleError("CreateProcessW.environment", "environment is not a mapping")
    copied: dict[str, str] = {}
    for key, value in source.items():
        if type(key) is not str or type(value) is not str:
            raise LifecycleError("CreateProcessW.environment", "environment keys/values must be native strings")
        if key.casefold() == FCA_DEADLINE_TICK_ENV.casefold():
            continue
        copied[key] = value
    copied[FCA_DEADLINE_TICK_ENV] = str(managed.absolute_deadline_tick64_ms)
    return copied


def _is_sha256(value: Any) -> bool:
    return type(value) is str and len(value) == 64 and all(ch in "0123456789abcdef" for ch in value)


def _raw_handle(handle: Any, *, stage: str) -> int:
    if type(handle) is int and handle > 0:
        return handle
    if type(handle) is ctypes.c_void_p and type(handle.value) is int and handle.value > 0:
        return int(handle.value)
    if os.name == "nt":
        handle_type = getattr(subprocess, "Handle", None)
        if handle_type is not None and type(handle) is handle_type:
            raw = int(handle)
            if raw > 0:
                return raw
    raise LifecycleError(stage, "handle must be an exact positive raw integer/c_void_p/subprocess.Handle")


def _positive_native_int(value: Any, field_name: str) -> int:
    if type(value) is not int or value <= 0:
        raise LifecycleError("contract", f"{field_name} must be a positive native integer")
    return value


def _no_reparse_path(path: Path) -> None:
    if not path.is_absolute():
        raise LifecycleError("ack_directory", "ACK directory must be absolute")
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current = current / part
        try:
            st = current.lstat()
        except OSError as exc:
            raise LifecycleError("ack_directory", f"cannot stat ACK path component {current}",
                                 winerror=getattr(exc, "winerror", None)) from exc
        attrs = getattr(st, "st_file_attributes", 0)
        if current.is_symlink() or (attrs & FILE_ATTRIBUTE_REPARSE_POINT):
            raise LifecycleError("ack_directory", f"ACK path contains reparse point: {current}")


def _managed_environment(env: Mapping[str, str] | None, backend: "Win32Backend",
                         deadline: float, now: Callable[[], float]) -> ManagedEnvironment:
    source = os.environ if env is None else env
    values: dict[str, str] = {}
    for key in _RESERVED_ENV:
        value = source.get(key)
        if type(value) is not str or not value:
            raise LifecycleError("managed_environment", f"missing reserved environment value {key}")
        values[key] = value
    session = values["FCA_MANAGED_SESSION_ID"]
    scope = values["FCA_MANAGED_SCOPE_SHA256"]
    if not _is_sha256(session) or not _is_sha256(scope):
        raise LifecycleError("managed_environment", "session and scope must be lowercase SHA256 hex")
    try:
        ack_dir = Path(values["FCA_MANAGED_ACK_DIRECTORY"])
        if not ack_dir.is_absolute():
            raise ValueError("not absolute")
        monitor_pid = int(values["FCA_MANAGED_MONITOR_PID"], 10)
        monitor_ticks = int(values["FCA_MANAGED_MONITOR_CREATE_100NS"], 10)
        handshake = float(values["FCA_MANAGED_HANDSHAKE_SECONDS"])
    except Exception as exc:
        raise LifecycleError("managed_environment", "reserved environment values are malformed") from exc
    if type(values["FCA_MANAGED_MONITOR_PID"]) is not str or str(monitor_pid) != values["FCA_MANAGED_MONITOR_PID"]:
        raise LifecycleError("managed_environment", "monitor PID must use canonical decimal text")
    if str(monitor_ticks) != values["FCA_MANAGED_MONITOR_CREATE_100NS"] or monitor_ticks <= 0:
        raise LifecycleError("managed_environment", "monitor FILETIME must use positive canonical decimal text")
    if not math.isfinite(handshake) or handshake <= 0:
        raise LifecycleError("managed_environment", "handshake allowance must be finite and positive")
    remaining = deadline - now()
    if remaining <= 0 or handshake > remaining:
        raise LifecycleError("managed_environment", "handshake exceeds remaining original deadline")
    remaining_ms = math.floor(remaining * 1000.0)
    if remaining_ms <= 0:
        raise LifecycleError("managed_environment", "less than one whole millisecond remains on original deadline")
    _no_reparse_path(ack_dir)
    if not ack_dir.is_dir():
        raise LifecycleError("ack_directory", "ACK directory must already exist")
    try:
        if any(ack_dir.iterdir()):
            raise LifecycleError("ack_directory", "ACK directory is not empty/exclusive")
    except OSError as exc:
        raise LifecycleError("ack_directory", "cannot inventory ACK directory") from exc
    monitor = ProcessIdentity(monitor_pid, monitor_ticks)
    actual_monitor = backend.current_process_identity()
    if monitor != actual_monitor:
        raise LifecycleError("managed_environment", "monitor identity differs from current process handle",
                             identity=actual_monitor)
    absolute_tick = backend.tick_count64() + remaining_ms
    if absolute_tick <= 0 or absolute_tick > 0xFFFFFFFFFFFFFFFF:
        raise LifecycleError("managed_environment", "absolute tick deadline is outside uint64 range")
    return ManagedEnvironment(session, ack_dir, scope, monitor, handshake, absolute_tick)


def _validate_ack_payload(payload: Mapping[str, Any]) -> RegistrationAck:
    expected_keys = {
        "schema", "session_id", "scope_sha256", "child_pid", "child_creation_time_100ns",
        "parent_pid", "parent_creation_time_100ns", "monitor_pid", "monitor_creation_time_100ns",
        "registration_sequence", "handle_duplicated", "identity_registered", "job_bound",
        "creation_sample_measured", "resume_permitted", "full_run_resource_complete",
    }
    if not isinstance(payload, Mapping) or set(payload) != expected_keys:
        raise LifecycleError("ack_schema", "ACK keys differ from the frozen 16-key contract")
    if payload["schema"] != ACK_SCHEMA or type(payload["schema"]) is not str:
        raise LifecycleError("ack_schema", "ACK schema is not the frozen literal")
    for key in ("session_id", "scope_sha256"):
        if not _is_sha256(payload[key]):
            raise LifecycleError("ack_schema", f"{key} must be lowercase SHA256 hex")
    for key in ("child_pid", "child_creation_time_100ns", "parent_pid", "parent_creation_time_100ns",
                "monitor_pid", "monitor_creation_time_100ns", "registration_sequence"):
        _positive_native_int(payload[key], key)
    for key in ("handle_duplicated", "identity_registered", "job_bound", "creation_sample_measured",
                "resume_permitted"):
        if payload[key] is not True:
            raise LifecycleError("ack_schema", f"{key} must be literal true")
    if payload["full_run_resource_complete"] is not False:
        raise LifecycleError("ack_schema", "startup ACK must not claim full-run resource completion")
    return RegistrationAck(**dict(payload))


def publish_ack_exclusive(directory: Path, payload: Mapping[str, Any]) -> AckPublication:
    """Durably publish one complete ACK by same-directory no-replace rename."""
    ack = _validate_ack_payload(payload)
    _no_reparse_path(directory)
    if not directory.is_dir():
        raise LifecycleError("ack_publish", "ACK directory disappeared")
    filename = f"{ack.child_pid}_{ack.child_creation_time_100ns}.ack.json"
    final_path = directory / filename
    temp_path = directory / f".{filename}.{secrets.token_hex(12)}.tmp"
    wire = json.dumps(ack.wire(), ensure_ascii=False, separators=(",", ":"), allow_nan=False).encode("utf-8") + b"\n"
    fd = None
    moved = False
    result: AckPublication | None = None
    failure: Exception | None = None
    try:
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
        fd = os.open(temp_path, flags, 0o600)
        with os.fdopen(fd, "wb", closefd=True) as stream:
            fd = None
            stream.write(wire)
            stream.flush()
            os.fsync(stream.fileno())
        if final_path.exists():
            raise LifecycleError("ack_publish", "final ACK already exists; replacement forbidden")
        if os.name != "nt":
            # Candidate must not be silently used on a non-Windows host.
            raise LifecycleError("ack_publish", "exclusive ACK publication is Windows-only")
        from ctypes import wintypes
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.MoveFileExW.argtypes = [wintypes.LPCWSTR, wintypes.LPCWSTR, wintypes.DWORD]
        kernel32.MoveFileExW.restype = wintypes.BOOL
        if not kernel32.MoveFileExW(str(temp_path), str(final_path), MOVEFILE_WRITE_THROUGH):
            raise ctypes.WinError(ctypes.get_last_error())
        moved = True
        observed = final_path.read_bytes()
        if observed != wire:
            raise LifecycleError("ack_publish", "published ACK bytes differ from flushed temporary bytes")
        parsed = json.loads(observed.decode("utf-8"), object_pairs_hook=_unique_json_object)
        _validate_ack_payload(parsed)
        result = AckPublication(ACK_PUBLICATION_SCHEMA, str(final_path), filename, len(wire),
                                hashlib.sha256(wire).hexdigest(), True, True)
    except Exception as exc:
        failure = exc
    cleanup_errors: list[dict[str, Any]] = []
    if fd is not None:
        try:
            os.close(fd)
        except OSError as exc:
            cleanup_errors.append({"resource": "temporary_ack_fd", "fd": fd,
                                   "type": type(exc).__name__, "repr": repr(exc),
                                   "winerror": getattr(exc, "winerror", None)})
    if not moved:
        try:
            temp_path.unlink(missing_ok=True)
        except OSError as exc:
            cleanup_errors.append({"resource": "temporary_ack_file", "path": str(temp_path),
                                   "type": type(exc).__name__, "repr": repr(exc),
                                   "winerror": getattr(exc, "winerror", None)})
    if failure is not None or cleanup_errors or result is None:
        evidence = {"temp_path": str(temp_path), "final_path": str(final_path),
                    "published": moved, "cleanup_errors": cleanup_errors,
                    "primary_error": ({"type": type(failure).__name__, "repr": repr(failure),
                                       "winerror": getattr(failure, "winerror", None)}
                                      if failure is not None else None)}
        if isinstance(failure, LifecycleError):
            failure.evidence = {**failure.evidence, **evidence}
            raise failure
        cleanup_winerror = cleanup_errors[0].get("winerror") if cleanup_errors else None
        raise LifecycleError("ack_publish", "exclusive ACK publication or cleanup failed",
                             winerror=getattr(failure, "winerror", None) if failure is not None else cleanup_winerror,
                             evidence=evidence) from failure
    return result


def _unique_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise LifecycleError("ack_schema", f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _validate_measurement(value: Any, identity: ProcessIdentity, *, phase: str,
                          event_sequence: int) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise LifecycleError("resource_measurement", "observer returned a non-mapping measurement",
                             identity=identity)
    required = {
        "schema", "phase", "identity", "handle_identity_before", "handle_identity_after",
        "event_sequence", "complete", "rss_bytes", "cpu_user_seconds", "cpu_system_seconds",
        "cmdline", "source_tags",
    }
    if set(value) != required:
        raise LifecycleError("resource_measurement", "measurement keys differ from frozen v1 schema",
                             identity=identity)
    expected = {"pid": identity.pid, "creation_time_100ns": identity.creation_time_100ns}
    if value["schema"] != RESOURCE_MEASUREMENT_SCHEMA or value["phase"] != phase:
        raise LifecycleError("resource_measurement", "measurement schema or phase mismatch", identity=identity)
    if value["identity"] != expected or value["handle_identity_before"] != expected or \
            value["handle_identity_after"] != expected:
        raise LifecycleError("resource_measurement", "measurement does not bind the exact handle generation",
                             identity=identity)
    if value["event_sequence"] != event_sequence or type(value["event_sequence"]) is not int:
        raise LifecycleError("resource_measurement", "measurement event sequence mismatch", identity=identity)
    if value["complete"] is not True:
        raise LifecycleError("resource_measurement", "measurement is incomplete", identity=identity)
    if type(value["rss_bytes"]) is not int or value["rss_bytes"] < 0:
        raise LifecycleError("resource_measurement", "RSS must be exact nonnegative native integer", identity=identity)
    for field_name in ("cpu_user_seconds", "cpu_system_seconds"):
        number = value[field_name]
        if type(number) not in (int, float) or isinstance(number, bool) or not math.isfinite(float(number)) or number < 0:
            raise LifecycleError("resource_measurement", f"{field_name} is not finite/nonnegative", identity=identity)
    command = value["cmdline"]
    if type(command) is not list or any(type(part) is not str for part in command):
        raise LifecycleError("resource_measurement", "command line must be a list of native strings", identity=identity)
    tags = value["source_tags"]
    if tags != ["GetProcessMemoryInfo", "GetProcessTimes", "NtQueryInformationProcess.ProcessCommandLineInformation"]:
        raise LifecycleError("resource_measurement", "measurement source tags differ from exact-handle APIs",
                             identity=identity)
    return dict(value)


@dataclass
class _OwnedHandle:
    raw: int
    identity: ProcessIdentity | None
    purpose: str
    owned: bool = True
    closed: bool = False
    registry_owned: bool = False
    close_error: Mapping[str, Any] | None = None


@dataclass
class _HeldEvent:
    event: DebugEvent
    event_sequence: int
    sample_attempt_id: int | None = None


class Win32Api(Protocol):
    """Injectable native boundary. Fakes implement this protocol in QA."""

    def current_process_identity(self) -> ProcessIdentity: ...
    def tick_count64(self) -> int: ...
    def create_process(self, argv: Sequence[str], cwd: str | None, env: Mapping[str, str] | None,
                       stdio_handles: tuple[int | None, int | None, int | None]) -> CreateProcessResult: ...
    def wait_debug_event(self, timeout_ms: int) -> DebugEvent | None: ...
    def continue_debug_event(self, event: DebugEvent, status: int) -> None: ...
    def open_birth_handle(self, event_process_handle: int, pid: int) -> tuple[int, bool]: ...
    def compare_objects(self, first: int, second: int) -> bool: ...
    def duplicate_handle(self, handle: int) -> int: ...
    def read_identity(self, handle: int) -> ProcessIdentity: ...
    def read_parent_pid(self, handle: int) -> int: ...
    def wait_handle(self, handle: int, timeout_ms: int) -> int: ...
    def exit_code(self, handle: int) -> int: ...
    def is_signaled(self, handle: int) -> bool: ...
    def ensure_job(self, process_handle: int, supplied_job: int | None) -> tuple[int, bool]: ...
    def job_process_ids(self, job_handle: int) -> tuple[int, ...]: ...
    def create_containment_job(self) -> int: ...
    def terminate_job(self, job_handle: int, exit_code: int) -> None: ...
    def terminate_process(self, process_handle: int, exit_code: int) -> None: ...
    def close_handle(self, handle: int) -> None: ...
    def close_debug_file(self, handle: int) -> None: ...
    def command_line(self, process_handle: int) -> list[str]: ...

    def resource_values(self, process_handle: int) -> Mapping[str, Any]: ...

    def initial_loader_breakpoint(self, process_handle: int, identity: ProcessIdentity, *,
                                  thread_id: int, create_event_thread_id: int,
                                  exception_address: int | None, exception_code: int,
                                  first_chance: bool, module_process_identity: ProcessIdentity,
                                  module_base: int, module_file_identity: tuple[int, str],
                                  module_load_sequence: int, exception_sequence: int) -> bool: ...

    def loader_validation_receipt(self) -> Mapping[str, Any]: ...


class _Win32Api:
    """Small ctypes implementation; every operation keeps the raw Win32 error."""

    def __init__(self) -> None:
        if os.name != "nt":
            raise LifecycleError("platform", "Windows debug lifecycle is Windows-only")
        from ctypes import wintypes
        self.wt = wintypes
        self.k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self.kbase = ctypes.WinDLL("kernelbase", use_last_error=True)
        self.psapi = ctypes.WinDLL("psapi", use_last_error=True)
        self.ntdll = ctypes.WinDLL("ntdll", use_last_error=True)
        self.shell32 = ctypes.WinDLL("shell32", use_last_error=True)
        # Bind pointer-width APIs before any calls, including sizing probes.
        self.k32.GetCurrentProcess.argtypes = []
        self.k32.GetCurrentProcess.restype = self.wt.HANDLE
        self.k32.GetCurrentProcessId.argtypes = []
        self.k32.GetCurrentProcessId.restype = self.wt.DWORD
        self.k32.GetStdHandle.argtypes = [self.wt.DWORD]
        self.k32.GetStdHandle.restype = self.wt.HANDLE
        self._pending_metadata_file_handles: list[dict[str, Any]] = []
        self._metadata_cleanup_errors: list[dict[str, Any]] = []
        self._last_loader_validation: dict[str, Any] = {
            "schema": "fca-initial-loader-breakpoint-validation-v1",
            "complete": False,
            "reason": "not_attempted",
        }

    def _check(self, ok: Any, stage: str) -> None:
        if not ok:
            error = ctypes.get_last_error()
            raise LifecycleError(stage, "Win32 call failed", winerror=error)

    def _h(self, value: int) -> Any:
        return self.wt.HANDLE(value)

    def current_process_identity(self) -> ProcessIdentity:
        handle = self.k32.GetCurrentProcess()
        pid = int(self.k32.GetCurrentProcessId())
        ticks = self._creation_ticks(handle)
        return ProcessIdentity(pid, ticks)

    def _creation_ticks(self, handle: Any) -> int:
        creation = _FILETIME()
        exit_time = _FILETIME()
        kernel = _FILETIME()
        user = _FILETIME()
        self.k32.GetProcessTimes.argtypes = [self.wt.HANDLE, ctypes.POINTER(_FILETIME),
                                             ctypes.POINTER(_FILETIME), ctypes.POINTER(_FILETIME),
                                             ctypes.POINTER(_FILETIME)]
        self.k32.GetProcessTimes.restype = self.wt.BOOL
        self._check(self.k32.GetProcessTimes(handle, ctypes.byref(creation), ctypes.byref(exit_time),
                                             ctypes.byref(kernel), ctypes.byref(user)), "GetProcessTimes")
        return (int(creation.high) << 32) | int(creation.low)

    def tick_count64(self) -> int:
        self.k32.GetTickCount64.argtypes = []
        self.k32.GetTickCount64.restype = ctypes.c_uint64
        return int(self.k32.GetTickCount64())

    def read_identity(self, handle: int) -> ProcessIdentity:
        raw = _raw_handle(handle, stage="GetProcessId")
        self.k32.GetProcessId.argtypes = [self.wt.HANDLE]
        self.k32.GetProcessId.restype = self.wt.DWORD
        pid = int(self.k32.GetProcessId(self._h(raw)))
        if pid <= 0:
            error = ctypes.get_last_error()
            raise LifecycleError("GetProcessId", "returned a zero PID", winerror=error)
        return ProcessIdentity(pid, self._creation_ticks(self._h(raw)))

    def compare_objects(self, first: int, second: int) -> bool:
        api = getattr(self.kbase, "CompareObjectHandles", None)
        if api is None:
            raise LifecycleError("CompareObjectHandles", "required API unavailable; PID fallback forbidden")
        api.argtypes = [self.wt.HANDLE, self.wt.HANDLE]
        api.restype = self.wt.BOOL
        ctypes.set_last_error(0)
        result = api(self._h(first), self._h(second))
        if not result:
            error = ctypes.get_last_error()
            if error:
                raise LifecycleError("CompareObjectHandles", "native object comparison failed", winerror=error)
        return bool(result)

    def open_birth_handle(self, event_process_handle: int, pid: int) -> tuple[int, bool]:
        # This is the sole allowed PID open: it is called only while the exact
        # CREATE_PROCESS_DEBUG_EVENT remains pending and before user-mode resume.
        access = (PROCESS_QUERY_INFORMATION | PROCESS_QUERY_LIMITED_INFORMATION |
                  PROCESS_VM_READ | PROCESS_TERMINATE | SYNCHRONIZE)
        self.k32.OpenProcess.argtypes = [self.wt.DWORD, self.wt.BOOL, self.wt.DWORD]
        self.k32.OpenProcess.restype = self.wt.HANDLE
        opened = self.k32.OpenProcess(access, False, pid)
        if not opened:
            error = ctypes.get_last_error()
            raise LifecycleError("OpenProcess_at_create_barrier", "one CREATE-barrier open failed",
                                 winerror=error)
        raw = _raw_handle(opened, stage="OpenProcess_at_create_barrier")
        # Caller performs the immediate event-object comparison while this
        # exact pending CREATE event is still owned and uncontinued.
        return raw, True

    def duplicate_handle(self, handle: int) -> int:
        current = self.k32.GetCurrentProcess()
        duplicate = self.wt.HANDLE()
        self.k32.DuplicateHandle.argtypes = [self.wt.HANDLE, self.wt.HANDLE, self.wt.HANDLE,
                                             ctypes.POINTER(self.wt.HANDLE), self.wt.DWORD,
                                             self.wt.BOOL, self.wt.DWORD]
        self.k32.DuplicateHandle.restype = self.wt.BOOL
        self._check(self.k32.DuplicateHandle(current, self._h(handle), current, ctypes.byref(duplicate),
                                             0, False, DUPLICATE_SAME_ACCESS), "DuplicateHandle")
        return _raw_handle(duplicate, stage="DuplicateHandle")

    class _PBI(ctypes.Structure):
        _fields_ = [("Reserved1", ctypes.c_void_p), ("PebBaseAddress", ctypes.c_void_p),
                    ("Reserved2_0", ctypes.c_void_p), ("Reserved2_1", ctypes.c_void_p),
                    ("UniqueProcessId", ctypes.c_size_t), ("InheritedFromUniqueProcessId", ctypes.c_size_t)]

    def read_parent_pid(self, handle: int) -> int:
        pbi = self._PBI()
        returned = self.wt.ULONG()
        self.ntdll.NtQueryInformationProcess.argtypes = [self.wt.HANDLE, self.wt.ULONG,
                                                         ctypes.c_void_p, self.wt.ULONG,
                                                         ctypes.POINTER(self.wt.ULONG)]
        self.ntdll.NtQueryInformationProcess.restype = self.wt.LONG
        status = self.ntdll.NtQueryInformationProcess(self._h(handle), 0, ctypes.byref(pbi),
                                                       ctypes.sizeof(pbi), ctypes.byref(returned))
        if status < 0:
            raise LifecycleError("NtQueryInformationProcess.BasicInformation",
                                 "parent PID query failed", evidence={"ntstatus": int(status) & 0xFFFFFFFF})
        parent = int(pbi.InheritedFromUniqueProcessId)
        if parent <= 0 or parent > 0xFFFFFFFF:
            raise LifecycleError("NtQueryInformationProcess.BasicInformation", "parent PID malformed")
        return parent

    def wait_handle(self, handle: int, timeout_ms: int) -> int:
        self.k32.WaitForSingleObject.argtypes = [self.wt.HANDLE, self.wt.DWORD]
        self.k32.WaitForSingleObject.restype = self.wt.DWORD
        value = int(self.k32.WaitForSingleObject(self._h(handle), timeout_ms))
        if value == 0xFFFFFFFF:
            raise LifecycleError("WaitForSingleObject", "wait failed", winerror=ctypes.get_last_error())
        return value

    def exit_code(self, handle: int) -> int:
        code = self.wt.DWORD()
        self.k32.GetExitCodeProcess.argtypes = [self.wt.HANDLE, ctypes.POINTER(self.wt.DWORD)]
        self.k32.GetExitCodeProcess.restype = self.wt.BOOL
        self._check(self.k32.GetExitCodeProcess(self._h(handle), ctypes.byref(code)), "GetExitCodeProcess")
        return int(code.value)

    def is_signaled(self, handle: int) -> bool:
        return self.wait_handle(handle, 0) == WAIT_OBJECT_0

    def create_containment_job(self) -> int:
        self.k32.CreateJobObjectW.argtypes = [ctypes.c_void_p, self.wt.LPCWSTR]
        self.k32.CreateJobObjectW.restype = self.wt.HANDLE
        handle = self.k32.CreateJobObjectW(None, None)
        if not handle:
            raise LifecycleError("CreateJobObjectW", "failed", winerror=ctypes.get_last_error())
        raw = _raw_handle(handle, stage="CreateJobObjectW")
        class _BASIC(ctypes.Structure):
            _fields_ = [("PerProcessUserTimeLimit", ctypes.c_int64), ("PerJobUserTimeLimit", ctypes.c_int64),
                        ("LimitFlags", self.wt.DWORD), ("MinimumWorkingSetSize", ctypes.c_size_t),
                        ("MaximumWorkingSetSize", ctypes.c_size_t), ("ActiveProcessLimit", self.wt.DWORD),
                        ("Affinity", ctypes.c_size_t), ("PriorityClass", self.wt.DWORD),
                        ("SchedulingClass", self.wt.DWORD)]
        class _IO_COUNTERS(ctypes.Structure):
            _fields_ = [(name, ctypes.c_uint64) for name in ("ReadOperationCount", "WriteOperationCount",
                        "OtherOperationCount", "ReadTransferCount", "WriteTransferCount", "OtherTransferCount")]
        class _EXTENDED(ctypes.Structure):
            _fields_ = [("BasicLimitInformation", _BASIC), ("IoInfo", _IO_COUNTERS),
                        ("ProcessMemoryLimit", ctypes.c_size_t), ("JobMemoryLimit", ctypes.c_size_t),
                        ("PeakProcessMemoryUsed", ctypes.c_size_t), ("PeakJobMemoryUsed", ctypes.c_size_t)]
        info = _EXTENDED()
        info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        self.k32.SetInformationJobObject.argtypes = [self.wt.HANDLE, self.wt.INT, ctypes.c_void_p, self.wt.DWORD]
        self.k32.SetInformationJobObject.restype = self.wt.BOOL
        self._check(self.k32.SetInformationJobObject(self._h(raw), JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
                                                     ctypes.byref(info), ctypes.sizeof(info)),
                    "SetInformationJobObject.KILL_ON_JOB_CLOSE")
        return raw

    def ensure_job(self, process_handle: int, supplied_job: int | None) -> tuple[int, bool]:
        job = supplied_job
        owned = False
        if job is None:
            job = self.create_containment_job()
            owned = True
        in_job = self.wt.BOOL()
        self.k32.IsProcessInJob.argtypes = [self.wt.HANDLE, self.wt.HANDLE, ctypes.POINTER(self.wt.BOOL)]
        self.k32.IsProcessInJob.restype = self.wt.BOOL
        self._check(self.k32.IsProcessInJob(self._h(process_handle), self._h(job), ctypes.byref(in_job)),
                    "IsProcessInJob")
        if not in_job.value:
            self.k32.AssignProcessToJobObject.argtypes = [self.wt.HANDLE, self.wt.HANDLE]
            self.k32.AssignProcessToJobObject.restype = self.wt.BOOL
            self._check(self.k32.AssignProcessToJobObject(self._h(job), self._h(process_handle)),
                        "AssignProcessToJobObject")
            if not self.k32.IsProcessInJob(self._h(process_handle), self._h(job), ctypes.byref(in_job)):
                raise LifecycleError("IsProcessInJob_after_assign", "membership verification failed",
                                     winerror=ctypes.get_last_error())
        if not in_job.value:
            raise LifecycleError("job_membership", "process is not in the exact configured Job")
        return int(job), owned

    def job_process_ids(self, job_handle: int) -> tuple[int, ...]:
        """Read the current PID inventory of the retained exact Job."""
        raw_job = _raw_handle(job_handle, stage="QueryInformationJobObject")
        query = self.k32.QueryInformationJobObject
        query.argtypes = [self.wt.HANDLE, self.wt.INT, ctypes.c_void_p,
                          self.wt.DWORD, ctypes.POINTER(self.wt.DWORD)]
        query.restype = self.wt.BOOL
        capacity = 16
        for _ in range(16):
            header_size = 2 * ctypes.sizeof(self.wt.DWORD)
            pid_size = ctypes.sizeof(ctypes.c_size_t)
            buffer_size = header_size + capacity * pid_size
            buffer = ctypes.create_string_buffer(buffer_size)
            returned = self.wt.DWORD()
            if not query(self._h(raw_job), JOB_OBJECT_BASIC_PROCESS_ID_LIST_CLASS,
                         ctypes.byref(buffer), buffer_size, ctypes.byref(returned)):
                error = ctypes.get_last_error()
                if error == 234:  # ERROR_MORE_DATA: repeat with a larger PID array.
                    capacity *= 2
                    continue
                raise LifecycleError("QueryInformationJobObject.BasicProcessIdList",
                                     "Win32 query failed", winerror=error)
            assigned = int.from_bytes(buffer.raw[0:4], "little")
            copied = int.from_bytes(buffer.raw[4:8], "little")
            if copied > capacity or assigned < copied:
                raise LifecycleError("QueryInformationJobObject.BasicProcessIdList",
                                     "Job PID inventory counts are malformed",
                                     evidence={"assigned": assigned, "copied": copied,
                                               "capacity": capacity,
                                               "returned_bytes": int(returned.value)})
            if copied < assigned:
                capacity = max(assigned, capacity * 2)
                continue
            pids = tuple(int.from_bytes(
                buffer.raw[header_size + index * pid_size:
                           header_size + (index + 1) * pid_size], "little")
                for index in range(copied))
            if any(pid <= 0 or pid > 0xFFFFFFFF for pid in pids) or \
                    len(pids) != len(set(pids)):
                raise LifecycleError("QueryInformationJobObject.BasicProcessIdList",
                                     "Job PID inventory contains invalid or duplicate PID")
            return tuple(sorted(pids))
        raise LifecycleError("QueryInformationJobObject.BasicProcessIdList",
                             "Job PID inventory changed during every bounded query",
                             evidence={"query_attempts": 16})

    def terminate_job(self, job_handle: int, exit_code: int) -> None:
        self.k32.TerminateJobObject.argtypes = [self.wt.HANDLE, self.wt.UINT]
        self.k32.TerminateJobObject.restype = self.wt.BOOL
        self._check(self.k32.TerminateJobObject(self._h(job_handle), exit_code), "TerminateJobObject")

    def terminate_process(self, process_handle: int, exit_code: int) -> None:
        self.k32.TerminateProcess.argtypes = [self.wt.HANDLE, self.wt.UINT]
        self.k32.TerminateProcess.restype = self.wt.BOOL
        self._check(self.k32.TerminateProcess(self._h(process_handle), exit_code), "TerminateProcess")

    def close_handle(self, handle: int) -> None:
        self.k32.CloseHandle.argtypes = [self.wt.HANDLE]
        self.k32.CloseHandle.restype = self.wt.BOOL
        self._check(self.k32.CloseHandle(self._h(handle)), "CloseHandle")

    def close_debug_file(self, handle: int) -> None:
        self.close_handle(handle)

    @property
    def metadata_cleanup_complete(self) -> bool:
        return not self._pending_metadata_file_handles

    def metadata_cleanup_receipt(self) -> Mapping[str, Any]:
        return {
            "complete": self.metadata_cleanup_complete,
            "pending_handles": [dict(item) for item in self._pending_metadata_file_handles],
            "errors": [dict(item) for item in self._metadata_cleanup_errors],
        }

    def loader_validation_receipt(self) -> Mapping[str, Any]:
        return dict(self._last_loader_validation)

    def _file_identity(self, file_handle: int) -> tuple[int, str]:
        raw = _raw_handle(file_handle, stage="GetFileInformationByHandleEx.file_id")
        info = _FILE_ID_INFO()
        api = self.k32.GetFileInformationByHandleEx
        api.argtypes = [self.wt.HANDLE, self.wt.DWORD, ctypes.c_void_p, self.wt.DWORD]
        api.restype = self.wt.BOOL
        self._check(api(self._h(raw), FILE_ID_INFO_CLASS, ctypes.byref(info), ctypes.sizeof(info)),
                    "GetFileInformationByHandleEx.FileIdInfo")
        file_id = bytes(info.FileId).hex()
        if len(file_id) != 32 or not any(info.FileId):
            raise LifecycleError("GetFileInformationByHandleEx.FileIdInfo", "file identity is malformed")
        return int(info.VolumeSerialNumber), file_id

    def _current_ntdll_dbg_breakpoint(self) -> tuple[int, int, bytes, tuple[int, str]]:
        """Return local ntdll DbgBreakPoint address, entry bytes, and exact file ID."""
        self.k32.GetModuleHandleW.argtypes = [self.wt.LPCWSTR]
        self.k32.GetModuleHandleW.restype = self.wt.HMODULE
        module = self.k32.GetModuleHandleW("ntdll.dll")
        base = int(module or 0)
        if base <= 0:
            raise LifecycleError("GetModuleHandleW.ntdll", "local ntdll module unavailable",
                                 winerror=ctypes.get_last_error())

        self.k32.GetProcAddress.argtypes = [self.wt.HMODULE, ctypes.c_char_p]
        self.k32.GetProcAddress.restype = ctypes.c_void_p
        symbol = int(self.k32.GetProcAddress(module, b"DbgBreakPoint") or 0)
        info = _MODULEINFO()
        self.psapi.GetModuleInformation.argtypes = [self.wt.HANDLE, self.wt.HMODULE,
                                                     ctypes.POINTER(_MODULEINFO), self.wt.DWORD]
        self.psapi.GetModuleInformation.restype = self.wt.BOOL
        self._check(self.psapi.GetModuleInformation(self.k32.GetCurrentProcess(), module,
                    ctypes.byref(info), ctypes.sizeof(info)), "GetModuleInformation.ntdll")
        image_base, image_size = int(info.lpBaseOfDll or 0), int(info.SizeOfImage)
        if (symbol <= base or image_base != base or image_size <= 0 or
                not (image_base <= symbol < image_base + image_size)):
            raise LifecycleError("GetProcAddress.ntdll.DbgBreakPoint", "export is outside the ntdll image")

        self.k32.GetModuleFileNameW.argtypes = [self.wt.HMODULE, self.wt.LPWSTR, self.wt.DWORD]
        self.k32.GetModuleFileNameW.restype = self.wt.DWORD
        image_path = None
        for capacity in (512, 1024, 2048, 4096, 8192, 16384, 32768):
            buffer = ctypes.create_unicode_buffer(capacity)
            count = int(self.k32.GetModuleFileNameW(module, buffer, capacity))
            if count == 0:
                raise LifecycleError("GetModuleFileNameW.ntdll", "local ntdll path unavailable",
                                     winerror=ctypes.get_last_error())
            if count < capacity - 1:
                image_path = buffer.value
                break
        if not image_path:
            raise LifecycleError("GetModuleFileNameW.ntdll", "local ntdll path exceeded bounded buffer")

        self.k32.CreateFileW.argtypes = [self.wt.LPCWSTR, self.wt.DWORD, self.wt.DWORD,
            ctypes.c_void_p, self.wt.DWORD, self.wt.DWORD, self.wt.HANDLE]
        self.k32.CreateFileW.restype = self.wt.HANDLE
        file_handle = self.k32.CreateFileW(image_path, FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, None, OPEN_EXISTING, 0, None)
        invalid = ctypes.c_void_p(-1).value
        if not file_handle or int(file_handle) == invalid:
            raise LifecycleError("CreateFileW.local_ntdll", "local ntdll file open failed",
                                 winerror=ctypes.get_last_error())
        raw_file = _raw_handle(file_handle, stage="CreateFileW.local_ntdll")
        local_file_id: tuple[int, str] | None = None
        identity_error: Exception | None = None
        close_error: Exception | None = None
        try:
            local_file_id = self._file_identity(raw_file)
        except Exception as exc:
            identity_error = exc
        try:
            self.close_handle(raw_file)
        except Exception as exc:
            close_error = exc
            pending = {"purpose": "local_ntdll_file_identity", "handle": raw_file,
                       "path": image_path, "file_identity": local_file_id,
                       "close_error": {"type": type(exc).__name__, "repr": repr(exc),
                                       "winerror": getattr(exc, "winerror", None)}}
            self._pending_metadata_file_handles.append(pending)
            self._metadata_cleanup_errors.append(dict(pending))
        if close_error is not None:
            raise LifecycleError("CloseHandle.local_ntdll", "metadata file handle close failed and remains owned",
                                 winerror=getattr(close_error, "winerror", None),
                                 evidence={"handle": raw_file, "path": image_path,
                                           "file_identity": local_file_id,
                                           "type": type(close_error).__name__,
                                           "repr": repr(close_error)}) from close_error
        if identity_error is not None:
            raise LifecycleError("GetFileInformationByHandleEx.local_ntdll",
                                 "local ntdll file identity query failed",
                                 winerror=getattr(identity_error, "winerror", None),
                                 evidence={"type": type(identity_error).__name__,
                                           "repr": repr(identity_error)}) from identity_error
        if local_file_id is None:
            raise LifecycleError("GetFileInformationByHandleEx.local_ntdll",
                                 "local ntdll file identity was not produced")

        entry = ctypes.string_at(symbol, 1)
        # Accept only the native int3 entry form; other layouts remain unsupported.
        if not entry or entry[0] != 0xCC:
            raise LifecycleError("DbgBreakPoint.native_opcode", "export entry is not an int3 instruction")
        return image_base, symbol, entry, local_file_id

    def initial_loader_breakpoint(self, process_handle: int, identity: ProcessIdentity, *,
                                  thread_id: int, create_event_thread_id: int,
                                  exception_address: int | None, exception_code: int,
                                  first_chance: bool,
                                  module_process_identity: ProcessIdentity,
                                  module_base: int,
                                  module_file_identity: tuple[int, str],
                                  module_load_sequence: int,
                                  exception_sequence: int) -> bool:
        """Validate an initial loader trap against an exact loaded ntdll image."""
        detail: dict[str, Any] = {
            "schema": "fca-initial-loader-breakpoint-validation-v1",
            "complete": False,
            "identity": _identity_value(identity) if type(identity) is ProcessIdentity else None,
            "module_process_identity": (_identity_value(module_process_identity)
                                        if type(module_process_identity) is ProcessIdentity else None),
            "module_base": module_base,
            "module_file_identity": (list(module_file_identity)
                                     if type(module_file_identity) is tuple else None),
            "module_load_sequence": module_load_sequence,
            "exception_sequence": exception_sequence,
            "thread_id": thread_id,
            "create_event_thread_id": create_event_thread_id,
            "exception_address": exception_address,
            "exception_code": exception_code,
            "first_chance": first_chance,
        }
        self._last_loader_validation = detail
        try:
            if (type(process_handle) is not int or process_handle <= 0 or
                    type(identity) is not ProcessIdentity or
                    type(module_process_identity) is not ProcessIdentity or
                    module_process_identity != identity or
                    type(thread_id) is not int or thread_id <= 0 or
                    type(create_event_thread_id) is not int or thread_id != create_event_thread_id or
                    type(exception_address) is not int or exception_address <= 0 or
                    type(exception_code) is not int or exception_code != EXCEPTION_BREAKPOINT or
                    first_chance is not True or type(module_base) is not int or module_base <= 0 or
                    type(module_load_sequence) is not int or module_load_sequence <= 0 or
                    type(exception_sequence) is not int or exception_sequence <= module_load_sequence or
                    not (type(module_file_identity) is tuple and len(module_file_identity) == 2 and
                         type(module_file_identity[0]) is int and
                         0 <= module_file_identity[0] < (1 << 64) and
                         type(module_file_identity[1]) is str and len(module_file_identity[1]) == 32 and
                         all(ch in "0123456789abcdef" for ch in module_file_identity[1]))):
                detail["reason"] = "malformed_or_mismatched_native_witness_fields"
                return False
            if self.read_identity(process_handle) != identity:
                detail["reason"] = "retained_process_handle_identity_mismatch"
                return False
            local_base, local_symbol, local_entry, local_file_id = self._current_ntdll_dbg_breakpoint()
            detail["local_ntdll_base"] = local_base
            detail["local_dbg_breakpoint_address"] = local_symbol
            detail["local_dbg_breakpoint_bytes_hex"] = local_entry.hex()
            detail["local_ntdll_file_identity"] = list(local_file_id)
            if local_file_id != module_file_identity:
                detail["reason"] = "loaded_module_file_identity_mismatch"
                return False
            remote_address = module_base + (local_symbol - local_base)
            detail["remote_dbg_breakpoint_address"] = remote_address
            if remote_address != exception_address or remote_address > (1 << (ctypes.sizeof(ctypes.c_void_p) * 8)) - 1:
                detail["reason"] = "exception_address_does_not_match_ntdll_export_rva"
                return False
            remote = ctypes.create_string_buffer(len(local_entry))
            bytes_read = ctypes.c_size_t(0)
            self.k32.ReadProcessMemory.argtypes = [self.wt.HANDLE, ctypes.c_void_p, ctypes.c_void_p,
                                                   ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
            self.k32.ReadProcessMemory.restype = self.wt.BOOL
            if not self.k32.ReadProcessMemory(self._h(process_handle), ctypes.c_void_p(remote_address),
                                              remote, len(local_entry), ctypes.byref(bytes_read)):
                detail["reason"] = "ReadProcessMemory_failed"
                detail["winerror"] = ctypes.get_last_error()
                return False
            detail["remote_dbg_breakpoint_bytes_hex"] = remote.raw.hex()
            if int(bytes_read.value) != len(local_entry) or remote.raw != local_entry:
                detail["reason"] = "remote_ntdll_opcode_mismatch"
                detail["bytes_read"] = int(bytes_read.value)
                return False
            detail["remote_opcode_matches"] = True
            if self.read_identity(process_handle) != identity:
                detail["reason"] = "retained_process_handle_identity_changed_during_validation"
                return False
            detail["complete"] = True
            detail["reason"] = "exact_loaded_ntdll_dbg_breakpoint"
            return True
        except Exception as exc:
            detail["reason"] = "native_validation_exception"
            detail["error"] = {"type": type(exc).__name__, "repr": repr(exc),
                               "stage": getattr(exc, "stage", None),
                               "winerror": getattr(exc, "winerror", None)}
            detail["metadata_cleanup"] = dict(self.metadata_cleanup_receipt())
            return False
        finally:
            self._last_loader_validation = dict(detail)

    def _duplicate_inheritable(self, raw: int) -> int:
        current = self.k32.GetCurrentProcess()
        dup = self.wt.HANDLE()
        self.k32.DuplicateHandle.argtypes = [self.wt.HANDLE, self.wt.HANDLE, self.wt.HANDLE,
                                             ctypes.POINTER(self.wt.HANDLE), self.wt.DWORD,
                                             self.wt.BOOL, self.wt.DWORD]
        self.k32.DuplicateHandle.restype = self.wt.BOOL
        self._check(self.k32.DuplicateHandle(current, self._h(raw), current, ctypes.byref(dup), 0, True,
                                             DUPLICATE_SAME_ACCESS), "DuplicateHandle.stdio")
        return _raw_handle(dup, stage="DuplicateHandle.stdio")

    def _create_process_native(self, argv: Sequence[str], cwd: str | None, env: Mapping[str, str] | None,
                               stdio_handles: tuple[int | None, int | None, int | None]) -> CreateProcessResult:
        if not argv or any(type(part) is not str or "\x00" in part for part in argv):
            raise LifecycleError("CreateProcessW", "argv must be a nonempty sequence of NUL-free strings")
        if cwd is not None and (type(cwd) is not str or "\x00" in cwd):
            raise LifecycleError("CreateProcessW", "cwd must be a NUL-free string or None")
        command_line = ctypes.create_unicode_buffer(subprocess.list2cmdline(list(argv)))
        startup = _STARTUPINFOEX()
        startup.StartupInfo.cb = ctypes.sizeof(_STARTUPINFOEX)
        startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES
        temp_handles: list[int] = []
        child_stdio: list[int] = []
        original: list[int | None] = []
        attr_buffer = None
        result: CreateProcessResult | None = None
        failure: Exception | None = None
        cleanup_errors: list[dict[str, Any]] = []
        try:
            for handle in stdio_handles:
                raw = None if handle is None else _raw_handle(handle, stage="stdio")
                original.append(raw)
                if raw is None:
                    std_handle = self.k32.GetStdHandle(
                        STD_INPUT_HANDLE if len(original) == 1 else
                        STD_OUTPUT_HANDLE if len(original) == 2 else STD_ERROR_HANDLE)
                    raw = _raw_handle(std_handle, stage="GetStdHandle")
                dup = self._duplicate_inheritable(raw)
                temp_handles.append(dup)
                child_stdio.append(dup)
            startup.StartupInfo.hStdInput = self._h(child_stdio[0])
            startup.StartupInfo.hStdOutput = self._h(child_stdio[1])
            startup.StartupInfo.hStdError = self._h(child_stdio[2])
            self.k32.InitializeProcThreadAttributeList.argtypes = [ctypes.c_void_p, self.wt.DWORD,
                                                                    self.wt.DWORD, ctypes.POINTER(ctypes.c_size_t)]
            self.k32.InitializeProcThreadAttributeList.restype = self.wt.BOOL
            self.k32.DeleteProcThreadAttributeList.argtypes = [ctypes.c_void_p]
            self.k32.DeleteProcThreadAttributeList.restype = None
            size = ctypes.c_size_t(0)
            self.k32.InitializeProcThreadAttributeList(None, 1, 0, ctypes.byref(size))
            if size.value == 0:
                raise LifecycleError("InitializeProcThreadAttributeList", "required handle-list size unavailable",
                                     winerror=ctypes.get_last_error())
            attr_buffer = ctypes.create_string_buffer(size.value)
            startup.lpAttributeList = ctypes.cast(attr_buffer, ctypes.c_void_p)
            self._check(self.k32.InitializeProcThreadAttributeList(startup.lpAttributeList, 1, 0,
                                                                    ctypes.byref(size)),
                        "InitializeProcThreadAttributeList")
            handle_array = (self.wt.HANDLE * len(child_stdio))(*(self._h(item) for item in child_stdio))
            self.k32.UpdateProcThreadAttribute.argtypes = [ctypes.c_void_p, self.wt.DWORD, ctypes.c_size_t,
                                                            ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p,
                                                            ctypes.c_void_p]
            self.k32.UpdateProcThreadAttribute.restype = self.wt.BOOL
            self._check(self.k32.UpdateProcThreadAttribute(startup.lpAttributeList, 0,
                        PROC_THREAD_ATTRIBUTE_HANDLE_LIST, ctypes.cast(handle_array, ctypes.c_void_p),
                         ctypes.sizeof(handle_array), None, None), "UpdateProcThreadAttribute.handle_list")
            env_block = None
            flags = DEBUG_PROCESS | EXTENDED_STARTUPINFO_PRESENT | CREATE_NO_WINDOW
            if env is not None:
                if not isinstance(env, Mapping) or any(type(k) is not str or type(v) is not str or
                        not k or "=" in k or "\x00" in k or "\x00" in v for k, v in env.items()):
                    raise LifecycleError("CreateProcessW", "environment mapping is malformed")
                entries = sorted((f"{k}={v}" for k, v in env.items()), key=str.casefold)
                env_block = ctypes.create_unicode_buffer("\x00".join(entries) + "\x00\x00")
                flags |= CREATE_UNICODE_ENVIRONMENT
            pi = _PROCESS_INFORMATION()
            self.k32.CreateProcessW.argtypes = [self.wt.LPCWSTR, self.wt.LPWSTR, ctypes.c_void_p,
                ctypes.c_void_p, self.wt.BOOL, self.wt.DWORD, ctypes.c_void_p, self.wt.LPCWSTR,
                ctypes.c_void_p, ctypes.POINTER(_PROCESS_INFORMATION)]
            self.k32.CreateProcessW.restype = self.wt.BOOL
            self._check(self.k32.CreateProcessW(None, command_line, None, None, True, flags,
                ctypes.cast(env_block, ctypes.c_void_p) if env_block is not None else None,
                cwd, ctypes.byref(startup), ctypes.byref(pi)), "CreateProcessW")
            result = CreateProcessResult(_raw_handle(pi.hProcess, stage="CreateProcessW.process"),
                                         _raw_handle(pi.hThread, stage="CreateProcessW.thread"),
                                         int(pi.dwProcessId), int(pi.dwThreadId), tuple(original))
        except Exception as exc:
            failure = exc
        finally:
            if startup.lpAttributeList and attr_buffer is not None:
                try:
                    self.k32.DeleteProcThreadAttributeList(startup.lpAttributeList)
                except Exception as exc:
                    cleanup_errors.append({"purpose": "DeleteProcThreadAttributeList",
                                           "type": type(exc).__name__, "repr": repr(exc),
                                           "winerror": getattr(exc, "winerror", None)})
            for handle in temp_handles:
                try:
                    self.close_handle(handle)
                except Exception as exc:
                    cleanup_errors.append({"purpose": "stdio_inheritable_duplicate_close",
                                           "handle": handle, "type": type(exc).__name__,
                                           "repr": repr(exc),
                                           "winerror": getattr(exc, "winerror", None)})
        if failure is not None:
            evidence = {"launch_cleanup_errors": cleanup_errors,
                        "process_created": result is not None}
            if isinstance(failure, LifecycleError):
                failure.evidence = {**failure.evidence, **evidence}
                raise failure
            raise LifecycleError("CreateProcessW", "native launch or startup-handle cleanup failed",
                                 winerror=getattr(failure, "winerror", None),
                                 evidence={**evidence, "type": type(failure).__name__,
                                           "repr": repr(failure)}) from failure
        if result is None:
            raise LifecycleError("CreateProcessW", "native launch returned no process information",
                                 evidence={"launch_cleanup_errors": cleanup_errors})
        unclosed = tuple(item["handle"] for item in cleanup_errors
                         if item.get("purpose") == "stdio_inheritable_duplicate_close")
        return CreateProcessResult(result.process_handle, result.thread_handle, result.pid, result.thread_id,
                                   result.inherited_stdio, unclosed, tuple(cleanup_errors))

    def create_process(self, argv: Sequence[str], cwd: str | None, env: Mapping[str, str] | None,
                       stdio_handles: tuple[int | None, int | None, int | None]) -> CreateProcessResult:
        return self._create_process_native(argv, cwd, env, stdio_handles)

    def wait_debug_event(self, timeout_ms: int) -> DebugEvent | None:
        event = _DEBUG_EVENT()
        self.k32.WaitForDebugEvent.argtypes = [ctypes.POINTER(_DEBUG_EVENT), self.wt.DWORD]
        self.k32.WaitForDebugEvent.restype = self.wt.BOOL
        if not self.k32.WaitForDebugEvent(ctypes.byref(event), timeout_ms):
            error = ctypes.get_last_error()
            if error == 121:  # ERROR_SEM_TIMEOUT
                return None
            raise LifecycleError("WaitForDebugEvent", "debug wait failed", winerror=error)
        code = int(event.dwDebugEventCode)
        raw: dict[str, Any] = {}
        process_handle = thread_handle = file_handle = exit_code = exception_code = first_chance = None
        if code == CREATE_PROCESS_DEBUG_EVENT:
            info = event.u.CreateProcessInfo
            process_handle = int(info.hProcess or 0) or None
            thread_handle = int(info.hThread or 0) or None
            file_handle = int(info.hFile or 0) or None
        elif code == CREATE_THREAD_DEBUG_EVENT:
            thread_handle = int(event.u.CreateThread.hThread or 0) or None
        elif code == EXIT_PROCESS_DEBUG_EVENT:
            exit_code = int(event.u.ExitProcess.dwExitCode)
        elif code == EXCEPTION_DEBUG_EVENT:
            exception = event.u.Exception
            exception_code = int(exception.ExceptionRecord.ExceptionCode)
            first_chance = bool(exception.dwFirstChance)
            raw["exception_flags"] = int(exception.ExceptionRecord.ExceptionFlags)
            raw["exception_address"] = int(exception.ExceptionRecord.ExceptionAddress or 0)
        elif code == LOAD_DLL_DEBUG_EVENT:
            info = event.u.LoadDll
            file_handle = int(info.hFile or 0) or None
            raw["module_base"] = int(info.lpBaseOfDll or 0)
            if file_handle:
                try:
                    raw["module_file_identity"] = self._file_identity(file_handle)
                except Exception as exc:
                    raw["module_file_identity_error"] = {
                        "type": type(exc).__name__,
                        "repr": repr(exc),
                        "winerror": getattr(exc, "winerror", None),
                    }
        elif code == UNLOAD_DLL_DEBUG_EVENT:
            raw["module_base"] = int(event.u.UnloadDll.lpBaseOfDll or 0)
        return DebugEvent(code, int(event.dwProcessId), int(event.dwThreadId), process_handle,
                          thread_handle, file_handle, exit_code, exception_code, first_chance, raw)

    def continue_debug_event(self, event: DebugEvent, status: int) -> None:
        self.k32.ContinueDebugEvent.argtypes = [self.wt.DWORD, self.wt.DWORD, self.wt.DWORD]
        self.k32.ContinueDebugEvent.restype = self.wt.BOOL
        self._check(self.k32.ContinueDebugEvent(event.process_id, event.thread_id, status), "ContinueDebugEvent")

    def wait_debug_event_timeout(self, timeout_ms: int) -> DebugEvent | None:
        return self.wait_debug_event(timeout_ms)

    def command_line(self, process_handle: int) -> list[str]:
        # ProcessCommandLineInformation=60 returns a UNICODE_STRING whose
        # buffer is contained in the supplied query buffer.
        class _UNICODE_STRING(ctypes.Structure):
            _fields_ = [("Length", self.wt.USHORT), ("MaximumLength", self.wt.USHORT),
                        ("Buffer", ctypes.c_void_p)]
        self.ntdll.NtQueryInformationProcess.argtypes = [self.wt.HANDLE, self.wt.ULONG,
                                                         ctypes.c_void_p, self.wt.ULONG,
                                                         ctypes.POINTER(self.wt.ULONG)]
        self.ntdll.NtQueryInformationProcess.restype = self.wt.LONG
        size = 4096
        while size <= 1 << 20:
            buffer = ctypes.create_string_buffer(size)
            returned = self.wt.ULONG()
            status = self.ntdll.NtQueryInformationProcess(self._h(process_handle), 60, buffer,
                                                           size, ctypes.byref(returned))
            if status >= 0:
                header = ctypes.cast(buffer, ctypes.POINTER(_UNICODE_STRING)).contents
                base = ctypes.addressof(buffer)
                offset = int(header.Buffer or 0) - base
                length = int(header.Length)
                if length % 2 or offset < ctypes.sizeof(_UNICODE_STRING) or offset + length > size:
                    raise LifecycleError("ProcessCommandLineInformation", "returned UnicodeString bounds invalid")
                command = ctypes.wstring_at(base + offset, length // 2)
                argc = ctypes.c_int()
                self.shell32.CommandLineToArgvW.argtypes = [self.wt.LPCWSTR, ctypes.POINTER(ctypes.c_int)]
                self.shell32.CommandLineToArgvW.restype = ctypes.POINTER(self.wt.LPWSTR)
                argv_ptr = self.shell32.CommandLineToArgvW(command, ctypes.byref(argc))
                if not argv_ptr:
                    raise LifecycleError("CommandLineToArgvW", "failed", winerror=ctypes.get_last_error())
                try:
                    return [argv_ptr[i] for i in range(argc.value)]
                finally:
                    self.k32.LocalFree.argtypes = [self.wt.HLOCAL]
                    self.k32.LocalFree.restype = self.wt.HLOCAL
                    self.k32.LocalFree(argv_ptr)
            # STATUS_INFO_LENGTH_MISMATCH and STATUS_BUFFER_TOO_SMALL are the
            # only reasons to grow this bounded buffer.
            if (int(status) & 0xFFFFFFFF) not in (0xC0000004, 0xC0000023):
                raise LifecycleError("ProcessCommandLineInformation", "native query failed",
                                     evidence={"ntstatus": int(status) & 0xFFFFFFFF})
            size *= 2
        raise LifecycleError("ProcessCommandLineInformation", "command line exceeds bounded query buffer")

    def resource_values(self, process_handle: int) -> Mapping[str, Any]:
        class _PROCESS_MEMORY_COUNTERS_EX(ctypes.Structure):
            _fields_ = [("cb", self.wt.DWORD), ("PageFaultCount", self.wt.DWORD),
                        ("PeakWorkingSetSize", ctypes.c_size_t), ("WorkingSetSize", ctypes.c_size_t),
                        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t), ("QuotaPagedPoolUsage", ctypes.c_size_t),
                        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t), ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
                        ("PagefileUsage", ctypes.c_size_t), ("PeakPagefileUsage", ctypes.c_size_t),
                        ("PrivateUsage", ctypes.c_size_t)]
        counters = _PROCESS_MEMORY_COUNTERS_EX()
        counters.cb = ctypes.sizeof(counters)
        self.psapi.GetProcessMemoryInfo.argtypes = [self.wt.HANDLE,
            ctypes.POINTER(_PROCESS_MEMORY_COUNTERS_EX), self.wt.DWORD]
        self.psapi.GetProcessMemoryInfo.restype = self.wt.BOOL
        self._check(self.psapi.GetProcessMemoryInfo(self._h(process_handle), ctypes.byref(counters),
                                                    counters.cb), "GetProcessMemoryInfo")
        kernel = _FILETIME()
        user = _FILETIME()
        creation = _FILETIME()
        exit_time = _FILETIME()
        self.k32.GetProcessTimes.argtypes = [self.wt.HANDLE, ctypes.POINTER(_FILETIME),
            ctypes.POINTER(_FILETIME), ctypes.POINTER(_FILETIME), ctypes.POINTER(_FILETIME)]
        self.k32.GetProcessTimes.restype = self.wt.BOOL
        self._check(self.k32.GetProcessTimes(self._h(process_handle), ctypes.byref(creation),
            ctypes.byref(exit_time), ctypes.byref(kernel), ctypes.byref(user)), "GetProcessTimes.resources")
        kernel_ticks = (int(kernel.high) << 32) | int(kernel.low)
        user_ticks = (int(user.high) << 32) | int(user.low)
        return {"rss_bytes": int(counters.WorkingSetSize),
                "cpu_user_seconds": user_ticks / 10_000_000.0,
                "cpu_system_seconds": kernel_ticks / 10_000_000.0,
                "cmdline": self.command_line(process_handle)}


def _raw_handle_value(handle: Any, *, stage: str) -> int:
    return _raw_handle(handle, stage=stage)


def _identity_value(identity: ProcessIdentity) -> dict[str, int]:
    return {"pid": identity.pid, "creation_time_100ns": identity.creation_time_100ns}


class WindowsDebugLifecycle:
    """Factory for a suspended root and single-thread-owned debug session."""

    @staticmethod
    def current_process_identity(native_api: Win32Api | None = None) -> ProcessIdentity:
        backend: Win32Api = _Win32Api() if native_api is None else native_api
        return backend.current_process_identity()

    @staticmethod
    def spawn_suspended(argv: Sequence[str], cwd: str | None, env: Mapping[str, str] | None,
                        job: int | None, registry: ExactBirthRegistry, observer: LifecycleObserver,
                        deadline: float, *,
                        stdio_handles: tuple[int | None, int | None, int | None] = (None, None, None),
                        native_api: Win32Api | None = None,
                        ack_publisher: Callable[[Path, Mapping[str, Any]], AckPublication] | None = None,
                        clock: Callable[[], float] = time.monotonic) -> "LifecycleSession":
        if type(deadline) not in (int, float) or isinstance(deadline, bool) or not math.isfinite(float(deadline)):
            raise LifecycleError("deadline", "deadline must be finite monotonic timestamp")
        backend: Win32Api = _Win32Api() if native_api is None else native_api
        if len(stdio_handles) != 3:
            raise LifecycleError("stdio", "stdio_handles must be exactly (stdin, stdout, stderr)")
        managed = _managed_environment(env, backend, float(deadline), clock)
        publisher = ack_publisher or (lambda directory, payload: publish_ack_exclusive(directory, payload))
        session = LifecycleSession(backend, registry, observer, managed, deadline=float(deadline),
                                   ack_publisher=lambda payload: publisher(managed.ack_directory, payload),
                                   clock=clock, stdio_handles=stdio_handles)
        try:
            session._start(argv, cwd, _child_environment(env, managed), job)
        except Exception as exc:
            abort = session.abort_startup(exc)
            if isinstance(exc, LifecycleError):
                exc.evidence = {**exc.evidence, "startup_abort": abort}
                exc.session = session
                raise
            raise LifecycleError("startup", "managed startup failed and was aborted fail-closed",
                                 evidence={"type": type(exc).__name__, "repr": repr(exc),
                                           "startup_abort": abort}) from exc
        return session


class LifecycleSession:
    """Popen-like exact-handle session; debug operations stay on creator thread."""

    def __init__(self, backend: Win32Api, registry: ExactBirthRegistry,
                 observer: LifecycleObserver, managed: ManagedEnvironment, *, deadline: float,
                 ack_publisher: Callable[[Mapping[str, Any]], AckPublication], clock: Callable[[], float],
                 stdio_handles: tuple[int | None, int | None, int | None]) -> None:
        self._api = backend
        self._registry = registry
        self._observer = observer
        self._managed = managed
        self._deadline = deadline
        self._clock = clock
        self._ack_publisher = ack_publisher
        self._stdio = stdio_handles
        self._owner_thread = threading.get_ident()
        self._create: CreateProcessResult | None = None
        self._root_identity: ProcessIdentity | None = None
        self._root_handle: int | None = None
        self._root_thread_handle: int | None = None
        self._root_job: int | None = None
        self._job_owned = False
        self._root_process_owned: _OwnedHandle | None = None
        self._root_thread_owned: _OwnedHandle | None = None
        self._job_owned_handle: _OwnedHandle | None = None
        self._temporary_handles: list[_OwnedHandle] = []
        self._uncertain_registry_handles: list[dict[str, Any]] = []
        self._handles: dict[ProcessIdentity, _OwnedHandle] = {}
        self._birth_witnesses: dict[ProcessIdentity, BirthSourceWitness] = {}
        self._loaded_module_witnesses: dict[ProcessIdentity, dict[int, dict[str, Any]]] = {}
        self._module_lineage_errors: dict[ProcessIdentity, list[dict[str, Any]]] = {}
        self._pending_debug_file_handles: list[dict[str, Any]] = []
        self._debug_file_close_receipts: dict[int, dict[str, Any]] = {}
        self._active_identities: set[ProcessIdentity] = set()
        self._pid_generations: dict[int, int] = {}
        self._create_seen: set[ProcessIdentity] = set()
        self._first_breakpoint_pending: set[ProcessIdentity] = set()
        self._initial_thread_ids: dict[ProcessIdentity, int] = {}
        self._event_sequence = 0
        self._continued_event_sequences: set[int] = set()
        self._registration_sequence = 0
        self._held_events: list[_HeldEvent] = []
        self._pending_boundary_events: list[_HeldEvent] = []
        self._pending_start_event: _HeldEvent | None = None
        self._startup_hold_kind: str | None = None
        self._startup_release_method: str | None = None
        self._startup_sample_receipt: Mapping[str, Any] | None = None
        self._attempt_counter = 0
        self._active_attempt: int | None = None
        self._active_attempt_changed = False
        self._active_attempt_codes: list[int] = []
        self._returncode: int | None = None
        self._exit_receipts: list[ProcessExitReceipt] = []
        self._event_receipts: list[dict[str, Any]] = []
        self._cleanup_errors: list[dict[str, Any]] = []
        self._fatal: LifecycleError | None = None
        self._startup_barrier_released = False
        self._closed = False
        self._debug_owner = True
        self._registry_close_complete = False
        self._cleanup_receipt_recorded = False
        self._registry.bind_managed_context(self._managed)
        try:
            phase_root = Path(self._registry.phase_root)
            if not phase_root.is_absolute() or os.path.normcase(os.path.abspath(phase_root)) != \
                    os.path.normcase(os.path.abspath(self._managed.ack_directory)):
                raise LifecycleError("registry_context", "registry phase root differs from exclusive ACK directory",
                                     evidence={"phase_root": str(phase_root),
                                               "ack_directory": str(self._managed.ack_directory)})
        except LifecycleError:
            raise
        except Exception as exc:
            raise LifecycleError("registry_context", "registry did not expose a valid phase root",
                                 evidence={"type": type(exc).__name__, "repr": repr(exc)}) from exc

    @property
    def pid(self) -> int:
        if self._create is None:
            raise LifecycleError("session", "process has not been created")
        return self._create.pid

    @property
    def root_identity(self) -> ProcessIdentity:
        if self._root_identity is None:
            raise LifecycleError("session", "root CREATE event has not been registered")
        return self._root_identity

    @property
    def returncode(self) -> int | None:
        return self._returncode

    @property
    def stdin(self) -> int | None:
        return self._stdio[0]

    @property
    def stdout(self) -> int | None:
        return self._stdio[1]

    @property
    def stderr(self) -> int | None:
        return self._stdio[2]

    @property
    def root_handle(self) -> int:
        if self._root_handle is None:
            raise LifecycleError("session", "root process handle is not available")
        return self._root_handle

    @property
    def exit_receipts(self) -> tuple[ProcessExitReceipt, ...]:
        return tuple(self._exit_receipts)

    @property
    def identity_complete(self) -> bool:
        return self._root_identity is not None and self._root_identity in self._handles and self._fatal is None

    @property
    def exit_proof_complete(self) -> bool:
        return (self._returncode is not None and not self._active_identities and
                len(self._exit_receipts) == len(self._handles) and
                all(x.exit_proof_complete and x.resource_measurement_complete for x in self._exit_receipts))

    @property
    def resource_sampling_complete(self) -> bool:
        # Startup/exit measurements are separate from the consumer's accepted
        # whole-tree sample sequence. The lifecycle core never upgrades it.
        return False

    @property
    def cleanup_complete(self) -> bool:
        roots_closed = all(handle is None or handle.closed for handle in
                           (self._root_process_owned, self._root_thread_owned, self._job_owned_handle))
        transient_closed = all(item.closed for item in self._temporary_handles)
        births_closed = all(handle.closed for handle in self._handles.values())
        metadata_complete = getattr(self._api, "metadata_cleanup_complete", True) is True
        return (self._closed and self._registry_close_complete and roots_closed and transient_closed and
                births_closed and metadata_complete and self._cleanup_receipt_recorded and
                not self._uncertain_registry_handles and not self._pending_debug_file_handles)

    def _check_owner(self) -> None:
        if threading.get_ident() != self._owner_thread:
            raise LifecycleError("thread_owner", "debug APIs must stay on the process-creation thread")

    def _remaining_ms(self, cap_seconds: float | None = None) -> int:
        remaining = self._deadline - self._clock()
        if remaining <= 0:
            raise LifecycleError("deadline", "original stage deadline expired")
        if cap_seconds is not None:
            remaining = min(remaining, cap_seconds)
        return max(1, int(math.ceil(remaining * 1000.0)))

    def _start(self, argv: Sequence[str], cwd: str | None, env: Mapping[str, str] | None,
               job: int | None) -> None:
        self._check_owner()
        if self._clock() >= self._deadline:
            raise LifecycleError("CreateProcessW", "deadline expired before process creation")
        created = self._api.create_process(argv, cwd, env, self._stdio)
        self._create = created
        self._root_handle = created.process_handle
        self._root_thread_handle = created.thread_handle
        self._root_process_owned = _OwnedHandle(created.process_handle, None, "root_process")
        self._root_thread_owned = _OwnedHandle(created.thread_handle, None, "root_primary_thread")
        for raw in created.unclosed_temp_handles:
            self._temporary_handles.append(_OwnedHandle(raw, None, "stdio_inheritable_duplicate"))
        for error in created.launch_cleanup_errors:
            self._cleanup_errors.append(dict(error))
        if created.launch_cleanup_errors:
            raise LifecycleError("CreateProcessW.cleanup", "temporary startup cleanup was incomplete",
                                 evidence={"cleanup_errors": [dict(item) for item in created.launch_cleanup_errors]})
        self._root_job, self._job_owned = self._api.ensure_job(created.process_handle, job)
        if self._job_owned:
            self._job_owned_handle = _OwnedHandle(self._root_job, None, "containment_job")
        # Register the actual root CREATE event but retain the native debug
        # barrier until the consumer commits its first complete standard sample.
        held = self._wait_until_root_create(created.pid)
        self._pending_start_event = held
        self._startup_hold_kind = "debug_create_event"
        try:
            # Route the root CREATE through the same containment/drain path as
            # descendant CREATE failures.  The event handler owns its hFile
            # close, so this call must not close it a second time.
            self._handle_debug_event(held.event, held.event_sequence)
        except Exception:
            if held.event_sequence in self._continued_event_sequences:
                self._pending_start_event = None
            raise

    def _wait_until_root_create(self, pid: int) -> _HeldEvent:
        expires = min(self._deadline, self._clock() + self._managed.handshake_seconds)
        while self._clock() < expires:
            self._check_owner()
            event = self._api.wait_debug_event(max(1, int((expires - self._clock()) * 1000)))
            if event is None:
                continue
            self._event_sequence += 1
            held = _HeldEvent(event, self._event_sequence)
            if event.code == CREATE_PROCESS_DEBUG_EVENT and event.process_id == pid:
                return held
            # No other event can precede the root create barrier in a valid
            # session. Preserve evidence and fail rather than continuing it.
            self._held_events.append(held)
            raise LifecycleError("root_create_order", "unexpected debug event before root CREATE",
                                 identity=self._api.read_identity(self._root_handle),
                                 evidence={"event_code": event.code, "event_pid": event.process_id,
                                           "event_sequence": held.event_sequence})
        raise LifecycleError("root_create_timeout", "no root CREATE event before bounded handshake/deadline")

    def _source_witness(self, pid: int, sequence: int, *, phase: str) -> BirthSourceWitness:
        witness = self._observer.birth_source_witness(pid, phase=phase, event_sequence=sequence)
        if not isinstance(witness, BirthSourceWitness):
            raise LifecycleError("source_witness", "observer must return BirthSourceWitness")
        receipt = witness.source_receipt
        if not isinstance(receipt, Mapping) or receipt.get("complete") is not True:
            raise LifecycleError("source_witness", "snapshot provider receipt is incomplete")
        if type(receipt.get("sequence")) is not int or receipt["sequence"] < 0:
            raise LifecycleError("source_witness", "snapshot receipt lacks a nonnegative 0-based history sequence")
        if receipt.get("phase") != phase:
            raise LifecycleError("source_witness", "snapshot receipt phase differs from requested boundary")
        row = witness.row
        try:
            row_id = ProcessIdentity(row.identity.pid, row.identity.create_time_100ns)
            ppid = row.ppid
            name = row.name
        except Exception as exc:
            raise LifecycleError("source_witness", "snapshot witness row has unsupported schema") from exc
        if row_id.pid != pid or type(ppid) is not int or ppid <= 0 or type(name) is not str or not name:
            raise LifecycleError("source_witness", "snapshot witness row is malformed")
        receipt_identity = receipt.get("row_identity")
        if receipt_identity != _identity_value(row_id) or receipt.get("row_ppid") != ppid or receipt.get("row_name") != name:
            raise LifecycleError("source_witness", "phase receipt does not bind the exact SPI row")
        return witness

    def _parent_identity(self, parent_pid: int) -> ProcessIdentity:
        if parent_pid == self._managed.monitor_identity.pid:
            return self._managed.monitor_identity
        candidates = [identity for identity in self._handles if identity.pid == parent_pid]
        if len(candidates) != 1:
            raise LifecycleError("parent_generation", "parent PID has no unique registered generation",
                                 evidence={"parent_pid": parent_pid,
                                           "registered_generations": [x.creation_time_100ns for x in candidates]})
        identity = candidates[0]
        adopted = self._handles[identity]
        raw = self._registry.handle_for(identity)
        if _raw_handle(raw, stage="parent_registry_handle") != adopted.raw:
            raise LifecycleError("parent_generation", "registry handle differs from adopted parent generation",
                                 identity=identity)
        if identity not in self._active_identities or self._api.read_identity(raw) != identity or \
                self._api.is_signaled(raw):
            raise LifecycleError("parent_generation", "exact registered parent is no longer live", identity=identity)
        return identity

    def _retain_pending_event(self, event: DebugEvent, sequence: int,
                              sample_attempt_id: int | None = None) -> None:
        if not any(item.event_sequence == sequence for item in self._held_events):
            self._held_events.append(_HeldEvent(event, sequence, sample_attempt_id))

    def _contain_failed_create_event(self, event: DebugEvent, sequence: int,
                                     cause: Exception,
                                     sample_attempt_id: int | None = None) -> bool:
        """Abort a rejected CREATE, continue its held event, then drain its exit."""
        raw = event.process_handle
        evidence: dict[str, Any] = {
            "event_sequence": sequence,
            "sample_attempt_id": sample_attempt_id,
            "event_pid": event.process_id,
            "cause_type": type(cause).__name__,
            "cause_repr": repr(cause),
            "failure_evidence": dict(getattr(cause, "evidence", {}) or {}),
            "registration_state": "unknown_until_exact_identity_read",
            "rejection_credit_disposition": {"registration": "zero",
                                               "birth_resource": "zero",
                                               "whole_sample": "zero",
                                               "full_lifecycle": "zero"},
            "termination_attempted": False,
            "terminate_succeeded": False,
            "duplicate_handle": None,
            "create_continued": False,
            "exit_thread_events": [],
            "exit_process_event": None,
            "wait_result": None,
            "exit_code": None,
            "exit_code_matches_event": False,
            "errors": [],
        }
        if raw is None:
            evidence["errors"].append({"stage": "CREATE_HANDLE", "error": "missing exact event process handle"})
            self._cleanup_errors.append({"purpose": "rejected_create_containment", **evidence})
            return False
        exact_identity: ProcessIdentity | None = None
        duplicate: _OwnedHandle | None = None
        try:
            if event.file_handle:
                close_receipt = self._close_debug_event_file_once(event, sequence,
                                                                    "rejected_create_image_file")
                evidence["image_file_close"] = dict(close_receipt)
                if close_receipt.get("complete") is not True:
                    raise LifecycleError("create_abort_file_close", "rejected CREATE image handle did not close")
            exact_identity = self._api.read_identity(raw)
            if exact_identity.pid != event.process_id:
                raise LifecycleError("create_abort_identity", "event handle PID differs from CREATE event",
                                     identity=exact_identity)
            evidence["identity"] = _identity_value(exact_identity)
            evidence["registration_state"] = ("registered_but_startup_failed"
                if exact_identity in self._create_seen or exact_identity in self._handles
                else "rejected_before_registration")
            duplicate_raw = self._api.duplicate_handle(raw)
            duplicate = _OwnedHandle(duplicate_raw, exact_identity, "rejected_create_abort_duplicate")
            self._temporary_handles.append(duplicate)
            evidence["duplicate_handle"] = duplicate.raw
            if self._api.read_identity(duplicate.raw) != exact_identity:
                raise LifecycleError("create_abort_duplicate", "retained duplicate differs from exact CREATE generation",
                                     identity=exact_identity)
            evidence["termination_attempted"] = True
            try:
                self._api.terminate_process(raw, 0xE0000002)
                evidence["terminate_succeeded"] = True
            except Exception as exc:
                evidence["errors"].append({"stage": "TerminateProcess.exact_create_handle",
                    "type": type(exc).__name__, "repr": repr(exc),
                    "winerror": getattr(exc, "winerror", None)})
            # Persist the abort decision while the real CREATE event is still
            # held. A successful process wait is meaningless until that event
            # has been continued and its real EXIT events drained.
            self._record({"event": "rejected_create_abort_started", **evidence})
            if not evidence["terminate_succeeded"]:
                evidence["errors"].append({"stage": "ContinueDebugEvent.CREATE",
                                            "error": "exact termination did not succeed; CREATE remains held"})
                self._cleanup_errors.append({"purpose": "rejected_create_containment", **evidence})
                return False
            self._continue_event(event, DBG_CONTINUE, sequence)
            evidence["create_continued"] = True
            exit_event_seen = False
            while not exit_event_seen:
                remaining_ms = max(0, int((self._deadline - self._clock()) * 1000.0))
                if remaining_ms <= 0:
                    raise LifecycleError("create_abort_exit_events", "deadline expired before real EXIT_PROCESS event",
                                         identity=exact_identity)
                next_event = self._api.wait_debug_event(remaining_ms)
                if next_event is None:
                    raise LifecycleError("create_abort_exit_events", "real EXIT_PROCESS event was not observed",
                                         identity=exact_identity)
                self._event_sequence += 1
                next_sequence = self._event_sequence
                if next_event.process_id != exact_identity.pid:
                    held = _HeldEvent(next_event, next_sequence, sample_attempt_id)
                    self._held_events.append(held)
                    raise LifecycleError("create_abort_exit_events", "unrelated debug event blocked rejected CREATE drain",
                                         identity=exact_identity,
                                         evidence={"event_pid": next_event.process_id,
                                                   "event_code": next_event.code,
                                                   "event_sequence": next_sequence})
                if next_event.code == EXIT_THREAD_DEBUG_EVENT:
                    evidence["exit_thread_events"].append({"thread_id": next_event.thread_id,
                                                              "event_sequence": next_sequence})
                elif next_event.code == EXIT_PROCESS_DEBUG_EVENT:
                    evidence["exit_process_event"] = {"thread_id": next_event.thread_id,
                        "event_sequence": next_sequence, "exit_code": next_event.exit_code}
                    exit_event_seen = True
                else:
                    evidence.setdefault("intermediate_events", []).append({"event_code": next_event.code,
                        "thread_id": next_event.thread_id, "event_sequence": next_sequence})
                if next_event.file_handle:
                    close_receipt = self._close_debug_event_file_once(next_event, next_sequence,
                                                                        "rejected_create_abort_event_file")
                    if close_receipt.get("complete") is not True:
                        raise LifecycleError("create_abort_file_close", "debug event file handle did not close",
                                             identity=exact_identity,
                                             evidence={"event_sequence": next_sequence,
                                                       "close": dict(close_receipt)})
                self._continue_event(next_event, DBG_CONTINUE, next_sequence)
            if self._api.read_identity(duplicate.raw) != exact_identity:
                raise LifecycleError("create_abort_identity", "retained duplicate changed generation before exit wait",
                                     identity=exact_identity)
            remaining_ms = max(0, int((self._deadline - self._clock()) * 1000.0))
            wait_result = self._api.wait_handle(duplicate.raw, remaining_ms)
            evidence["wait_result"] = wait_result
            if wait_result != WAIT_OBJECT_0:
                raise LifecycleError("create_abort_wait", "exact CREATE generation did not signal after EXIT_PROCESS",
                                     identity=exact_identity,
                                     evidence={"wait_result": wait_result})
            exit_code = self._api.exit_code(duplicate.raw)
            evidence["exit_code"] = exit_code
            event_exit = evidence["exit_process_event"]["exit_code"]
            if self._api.read_identity(duplicate.raw) != exact_identity:
                raise LifecycleError("create_abort_identity", "retained duplicate changed generation after exit wait",
                                     identity=exact_identity)
            evidence["exit_code_matches_event"] = (exit_code != STILL_ACTIVE and exit_code == event_exit)
            if evidence["exit_code_matches_event"] is not True:
                raise LifecycleError("create_abort_exit_code", "exact process exit code differs from EXIT_PROCESS event",
                                     identity=exact_identity,
                                     evidence={"handle_exit_code": exit_code, "event_exit_code": event_exit})
            self._cleanup_handle(duplicate)
            if not duplicate.closed:
                raise LifecycleError("create_abort_duplicate_close", "exact abort duplicate did not close",
                                     identity=exact_identity, evidence={"close_error": duplicate.close_error})
            try:
                self._record({"event": "rejected_create_abort_drained", **evidence})
            except Exception as exc:
                evidence["errors"].append({"stage": "record_rejected_create", "type": type(exc).__name__,
                    "repr": repr(exc), "winerror": getattr(exc, "winerror", None)})
                self._cleanup_errors.append({"purpose": "rejected_create_receipt", **evidence})
                self._fatal = LifecycleError("create_abort_receipt", "rejected CREATE receipt was not durable",
                                             identity=exact_identity, evidence=evidence)
            return True
        except Exception as exc:
            evidence["errors"].append({"stage": getattr(exc, "stage", "create_abort"),
                "type": type(exc).__name__, "repr": repr(exc), "winerror": getattr(exc, "winerror", None)})
            self._cleanup_errors.append({"purpose": "rejected_create_containment", **evidence})
            if duplicate is not None and not duplicate.closed and not evidence["create_continued"]:
                self._cleanup_handle(duplicate)
                if not duplicate.closed:
                    evidence["errors"].append({"stage": "duplicate_close",
                        "error": "abort duplicate remains open", "close_error": duplicate.close_error})
            try:
                self._record({"event": "rejected_create_abort_incomplete", **evidence})
            except Exception as record_exc:
                self._fatal = LifecycleError("create_abort_receipt", "incomplete CREATE abort receipt was not durable",
                    identity=exact_identity, evidence={**evidence,
                        "record_error": {"type": type(record_exc).__name__, "repr": repr(record_exc)}})
            return False

    def abort_startup(self, cause: Exception) -> Mapping[str, Any]:
        """Best-effort bounded termination while retaining every unresolved handle."""
        self._check_owner()
        receipt: dict[str, Any] = {"schema": "fca-managed-startup-abort-v1", "attempted": False,
                                   "termination": None, "root_wait_result": None,
                                   "root_exit_code": None, "cleanup_complete": False,
                                   "pending_create": self._pending_start_event is not None,
                                   "held_event_sequences": [item.event_sequence for item in self._held_events],
                                   "cause_type": type(cause).__name__, "cause_repr": repr(cause)}
        if self._create is None or self._root_handle is None:
            receipt["cleanup_complete"] = True
            return receipt
        receipt["attempted"] = True
        try:
            if self._root_job is not None:
                self._api.terminate_job(self._root_job, 0xE0000001)
                receipt["termination"] = {"kind": "job", "succeeded": True}
            else:
                self._api.terminate_process(self._root_handle, 0xE0000001)
                receipt["termination"] = {"kind": "root_handle", "succeeded": True}
        except Exception as exc:
            receipt["termination"] = {"kind": "failed", "type": type(exc).__name__, "repr": repr(exc),
                                       "winerror": getattr(exc, "winerror", None)}
            self._cleanup_errors.append({"purpose": "startup_terminate", **receipt["termination"]})
        pending = self._pending_start_event
        if pending is not None:
            registered_root = (self._root_identity is not None and
                               self._root_identity in self._handles and
                               pending.event.process_id == self._root_identity.pid)
            if not registered_root:
                receipt["root_wait_error"] = "unregistered CREATE event remains held; no wait/exit credit"
                receipt["debug_create_abort"] = {"continued": False,
                    "reason": "rejected/unregistered CREATE is not eligible for startup release"}
            elif receipt.get("termination", {}).get("succeeded") is True:
                try:
                    self._record({"event": "registered_root_abort_started",
                                  "identity": _identity_value(self._root_identity),
                                  "event_sequence": pending.event_sequence,
                                  "termination": receipt["termination"]})
                    self._continue_event(pending.event, DBG_CONTINUE, pending.event_sequence)
                    receipt["debug_create_abort"] = {"continued": True,
                        "event_sequence": pending.event_sequence,
                        "release_method": "abort_only_continue_debug_event"}
                    self._pending_start_event = None
                    while self._returncode is None:
                        remaining_ms = max(0, int((self._deadline - self._clock()) * 1000.0))
                        if remaining_ms <= 0:
                            raise LifecycleError("startup_abort_exit", "deadline expired before registered root EXIT_PROCESS",
                                                 identity=self._root_identity)
                        event = self._api.wait_debug_event(remaining_ms)
                        if event is None:
                            raise LifecycleError("startup_abort_exit", "registered root EXIT_PROCESS event was not observed",
                                                 identity=self._root_identity)
                        self._event_sequence += 1
                        self._handle_debug_event(event, self._event_sequence)
                except Exception as exc:
                    receipt["debug_create_abort_error"] = {"type": type(exc).__name__, "repr": repr(exc),
                        "stage": getattr(exc, "stage", None), "winerror": getattr(exc, "winerror", None)}
                    self._cleanup_errors.append({"purpose": "startup_debug_create_abort",
                                                 **receipt["debug_create_abort_error"]})
        try:
            # A pending CREATE event owns the process's native debug stop.
            # Never wait for its process handle until the event was continued.
            wait_result = (self._api.wait_handle(self._root_handle, 0)
                           if self._pending_start_event is None else WAIT_TIMEOUT)
            receipt["root_wait_result"] = wait_result
            if wait_result == WAIT_OBJECT_0:
                try:
                    receipt["root_exit_code"] = self._api.exit_code(self._root_handle)
                except Exception as exc:
                    receipt["root_exit_code_error"] = {"type": type(exc).__name__, "repr": repr(exc),
                                                        "winerror": getattr(exc, "winerror", None)}
            elif wait_result != WAIT_TIMEOUT:
                receipt["root_wait_error"] = "unexpected wait status"
        except Exception as exc:
            receipt["root_wait_error"] = {"type": type(exc).__name__, "repr": repr(exc),
                                          "winerror": getattr(exc, "winerror", None)}
        # Debug CREATE/EXIT barriers are never continued for an unregistered
        # identity. A signaled process is not enough to claim debug cleanup if
        # a CREATE event remains pending.
        debug_checkpoint: dict[str, Any] = {
            "schema": "fca-startup-debug-queue-checkpoint-v1",
            "attempted": False, "queue_empty": False, "held_event": None, "error": None,
        }
        if (receipt["root_wait_result"] == WAIT_OBJECT_0 and
                self._pending_start_event is None and not self._held_events and
                not self._pending_boundary_events):
            debug_checkpoint["attempted"] = True
            try:
                event = self._api.wait_debug_event(0)
                if event is None:
                    debug_checkpoint["queue_empty"] = True
                else:
                    self._event_sequence += 1
                    held = _HeldEvent(event, self._event_sequence)
                    self._held_events.append(held)
                    debug_checkpoint["held_event"] = {
                        "event_sequence": held.event_sequence,
                        "event_code": event.code,
                        "process_id": event.process_id,
                        "thread_id": event.thread_id,
                        "raw": dict(event.raw),
                    }
            except Exception as exc:
                debug_checkpoint["error"] = {
                    "type": type(exc).__name__, "repr": repr(exc),
                    "stage": getattr(exc, "stage", None),
                    "winerror": getattr(exc, "winerror", None),
                }
        receipt["debug_queue_checkpoint"] = debug_checkpoint
        receipt["held_event_sequences"] = [item.event_sequence for item in self._held_events]
        receipt["root_create_registered"] = (self._root_identity is not None and
                                               self._root_identity in self._create_seen)
        receipt["active_identity_count"] = len(self._active_identities)
        receipt["startup_cleanup_errors"] = [dict(item) for item in self._cleanup_errors]
        receipt["pending_debug_file_handle_count"] = len(self._pending_debug_file_handles)
        receipt["uncertain_registry_handle_count"] = len(self._uncertain_registry_handles)
        receipt["cleanup_complete"] = (
            receipt["termination"] is not None and receipt["termination"].get("succeeded") is True and
            receipt["root_wait_result"] == WAIT_OBJECT_0 and
            receipt.get("root_exit_code") is not None and receipt["root_exit_code"] != STILL_ACTIVE and
            receipt["root_create_registered"] is True and receipt["active_identity_count"] == 0 and
            debug_checkpoint["attempted"] is True and debug_checkpoint["queue_empty"] is True and
            self._pending_start_event is None and not self._held_events and
            not self._pending_boundary_events and receipt["pending_debug_file_handle_count"] == 0 and
            receipt["uncertain_registry_handle_count"] == 0 and not self._cleanup_errors
        )
        self._record({"event": "startup_abort", **receipt})
        return receipt

    def _make_ack(self, identity: ProcessIdentity, parent: ProcessIdentity, sequence: int) -> RegistrationAck:
        return RegistrationAck(
            schema=ACK_SCHEMA, session_id=self._managed.session_id, scope_sha256=self._managed.scope_sha256,
            child_pid=identity.pid, child_creation_time_100ns=identity.creation_time_100ns,
            parent_pid=parent.pid, parent_creation_time_100ns=parent.creation_time_100ns,
            monitor_pid=self._managed.monitor_identity.pid,
            monitor_creation_time_100ns=self._managed.monitor_identity.creation_time_100ns,
            registration_sequence=sequence, handle_duplicated=True, identity_registered=True,
            job_bound=True, creation_sample_measured=True, resume_permitted=True,
            full_run_resource_complete=False)

    def _handle_create_event(self, event: DebugEvent, *, is_root: bool = False,
                             event_sequence: int | None = None) -> RegistrationAck:
        self._check_owner()
        if event.code != CREATE_PROCESS_DEBUG_EVENT or event.process_handle is None or event.thread_handle is None:
            raise LifecycleError("create_event", "CREATE_PROCESS event lacks its event process/thread handle")
        if event_sequence is None:
            self._event_sequence += 1
            sequence = self._event_sequence
        else:
            if type(event_sequence) is not int or event_sequence <= 0:
                raise LifecycleError("create_event", "event sequence must be a positive integer")
            sequence = event_sequence
        if self._create is None or self._root_handle is None:
            raise LifecycleError("create_event", "root process creation state is absent")
        if is_root:
            if (event.process_id != self._create.pid or event.thread_id != self._create.thread_id or
                    not self._api.compare_objects(event.process_handle, self._root_handle) or
                    self._root_thread_handle is None or
                    not self._api.compare_objects(event.thread_handle, self._root_thread_handle)):
                raise LifecycleError("root_create_identity", "root CREATE event handle differs from CreateProcess handle")
            full_handle = self._root_handle
            temporary_open = False
        else:
            full_handle, temporary_open = self._api.open_birth_handle(event.process_handle, event.process_id)
            if not temporary_open or not self._api.compare_objects(event.process_handle, full_handle):
                if temporary_open:
                    query = _OwnedHandle(full_handle, None, "birth_query_handle")
                    self._temporary_handles.append(query)
                    self._cleanup_handle(query)
                raise LifecycleError("create_barrier_handle", "CREATE event could not be compared to one rights handle")
        query_handle = None
        if temporary_open:
            query_handle = _OwnedHandle(full_handle, None, "birth_query_handle")
            self._temporary_handles.append(query_handle)
        retained_handle: int | None = None
        adopted = False
        identity: ProcessIdentity | None = None
        measurement: Mapping[str, Any] | None = None
        try:
            identity = self._api.read_identity(full_handle)
            if identity.pid != event.process_id:
                raise LifecycleError("create_barrier_identity", "event PID differs from full-rights handle identity",
                                     identity=identity)
            prior_generation = self._pid_generations.get(identity.pid)
            if prior_generation is not None:
                raise LifecycleError("pid_generation_reuse", "PID already appeared in this debug session",
                                     identity=identity,
                                     evidence={"prior_creation_time_100ns": prior_generation,
                                               "new_creation_time_100ns": identity.creation_time_100ns})
            if identity in self._handles or identity in self._create_seen:
                raise LifecycleError("duplicate_birth", "same PID generation was already registered", identity=identity)
            parent_pid = self._api.read_parent_pid(full_handle)
            parent_identity = self._parent_identity(parent_pid)
            witness = self._source_witness(event.process_id, sequence, phase="managed_create")
            row = witness.row
            row_identity = ProcessIdentity(row.identity.pid, row.identity.create_time_100ns)
            if row_identity != identity or row.ppid != parent_identity.pid:
                raise LifecycleError("source_row_binding", "SPI row identity/parent differs from CREATE event",
                                     identity=identity)
            if is_root and parent_identity != self._managed.monitor_identity:
                raise LifecycleError("root_parent", "root parent differs from exact monitor identity", identity=identity)
            if not is_root and parent_identity == self._managed.monitor_identity and parent_pid != self._managed.monitor_identity.pid:
                raise LifecycleError("parent_generation", "monitor parent PID mismatch", identity=identity)
            job_handle = self._root_job
            if job_handle is None:
                raise LifecycleError("job_membership", "no exact configured Job was retained")
            verified_job, newly_owned = self._api.ensure_job(full_handle, job_handle)
            if verified_job != job_handle:
                if newly_owned:
                    self._api.close_handle(verified_job)
                raise LifecycleError("job_membership", "birth is not bound to the exact root Job", identity=identity)
            retained_handle = self._api.duplicate_handle(full_handle)
            if self._api.read_identity(retained_handle) != identity:
                raise LifecycleError("retained_handle", "duplicate handle identity differs", identity=identity)
            event_receipt = {"event_code": event.code, "event_pid": event.process_id,
                             "event_thread_id": event.thread_id, "event_sequence": sequence,
                             "create_handle_compared": True, "job_handle": job_handle}
            measured = self._measure_exact_handle(retained_handle, identity, row, phase="create",
                                                  event_sequence=sequence, event_receipt=event_receipt)
            measurement = measured["measurement_receipt"]
            if self._api.read_identity(retained_handle) != identity:
                raise LifecycleError("creation_sample", "handle generation changed during measured read", identity=identity)
            if self._observer.record_birth_measurement(measurement) is not True:
                raise LifecycleError("creation_sample", "observer did not durably record complete measurement",
                                     identity=identity)
            ack_payload = self._make_ack(identity, parent_identity, self._registration_sequence + 1).wire()
            birth = BirthRecord(identity, parent_identity, event.process_id, row, witness.snapshot,
                                witness.source_receipt, self._managed.session_id,
                                self._managed.scope_sha256, self._managed.monitor_identity,
                                self._registration_sequence + 1, retained_handle, True, measurement)
            publications: list[AckPublication] = []

            def publish(payload: Mapping[str, Any]) -> AckPublication:
                publication = self._ack_publisher(payload)
                if type(publication) is not AckPublication:
                    raise LifecycleError("ack_publish", "publisher did not return typed AckPublication",
                                         identity=identity)
                publications.append(publication)
                return publication

            try:
                ack = self._registry.register_birth(birth, ack_type=RegistrationAck, ack_publisher=publish)
            except BirthRegistrationError as exc:
                if exc.handle_transferred:
                    adopted = True
                    self._handles[identity] = _OwnedHandle(retained_handle, identity,
                        "registry-owned-duplicate", owned=False, registry_owned=True)
                    self._active_identities.add(identity)
                    self._pid_generations[identity.pid] = identity.creation_time_100ns
                    self._birth_witnesses[identity] = witness
                raise
            except Exception as exc:
                # A non-typed registry error leaves ownership ambiguous. Keep
                # the duplicate open and explicitly record that uncertainty;
                # closing it here could double-close a transferred handle.
                self._uncertain_registry_handles.append({"identity": _identity_value(identity),
                    "handle": retained_handle, "type": type(exc).__name__, "repr": repr(exc)})
                retained_handle = None
                raise LifecycleError("registry_birth_ownership", "registry failure did not state transfer ownership",
                                     identity=identity,
                                     evidence={"type": type(exc).__name__, "repr": repr(exc)}) from exc
            adopted = True
            self._handles[identity] = _OwnedHandle(retained_handle, identity, "registry-owned-duplicate",
                                                   owned=False, registry_owned=True)
            self._active_identities.add(identity)
            self._pid_generations[identity.pid] = identity.creation_time_100ns
            self._birth_witnesses[identity] = witness
            if type(ack) is not RegistrationAck or ack.wire() != ack_payload:
                raise LifecycleError("registry_ack", "registry returned a different or untyped ACK", identity=identity)
            if len(publications) != 1:
                raise LifecycleError("registry_ack", "registry did not publish exactly one ACK", identity=identity,
                                     evidence={"publication_count": len(publications)})
            publication = publications[0]
            expected_name = f"{identity.pid}_{identity.creation_time_100ns}.ack.json"
            expected_path = os.path.normcase(os.path.abspath(self._managed.ack_directory / expected_name))
            actual_path = os.path.normcase(os.path.abspath(publication.path))
            if (publication.schema != ACK_PUBLICATION_SCHEMA or publication.filename != expected_name or
                    actual_path != expected_path or type(publication.bytes) is not int or publication.bytes <= 0 or
                    not _is_sha256(publication.sha256) or publication.exclusive is not True or
                    publication.flushed is not True):
                raise LifecycleError("registry_ack", "published ACK receipt differs from exclusive session binding",
                                     identity=identity, evidence={"publication": publication.__dict__})
            self._registration_sequence += 1
            self._create_seen.add(identity)
            self._first_breakpoint_pending.add(identity)
            self._initial_thread_ids[identity] = event.thread_id
            self._record({"event": "birth_registered", "identity": _identity_value(identity),
                          "parent_identity": _identity_value(parent_identity), "event_sequence": sequence,
                          "registration_sequence": self._registration_sequence,
                          "ack": ack.wire(), "ack_publication": publication.__dict__,
                          "creation_measurement": measurement,
                          "source_snapshot_receipt": dict(witness.source_receipt)})
            if query_handle is not None:
                self._cleanup_handle(query_handle)
                if not query_handle.closed:
                    raise LifecycleError("birth_query_handle", "temporary query handle failed to close before Continue",
                                         identity=identity,
                                         evidence={"handle": query_handle.raw,
                                                   "close_error": query_handle.close_error})
            # Publication and exact registry ownership have succeeded; only
            # now may a descendant CREATE be released. The root event remains
            # held until resume_root_after_ack verifies the committed sample.
            if is_root:
                self._root_identity = identity
            else:
                self._continue_event(event, DBG_CONTINUE, sequence)
            return ack
        except Exception as exc:
            if measurement is not None:
                failure_evidence = dict(getattr(exc, "evidence", {}) or {})
                failure_evidence["raw_birth_measurement_receipt"] = dict(measurement)
                failure_evidence["raw_birth_measurement_disposition"] = "diagnostic_only_zero_credit_if_create_rejected"
                if isinstance(exc, LifecycleError):
                    exc.evidence = failure_evidence
            if retained_handle is not None and not adopted:
                unadopted = _OwnedHandle(retained_handle, identity, "unadopted_birth_duplicate")
                self._temporary_handles.append(unadopted)
                self._cleanup_handle(unadopted)
            if query_handle is not None and not query_handle.closed:
                self._cleanup_handle(query_handle)
            if isinstance(exc, LifecycleError):
                if query_handle is not None and not query_handle.closed:
                    exc.evidence = {**exc.evidence, "query_handle_close_error": query_handle.close_error}
                raise
            raise LifecycleError("create_barrier", "birth registration failed before ContinueDebugEvent",
                                 identity=identity, evidence={"type": type(exc).__name__,
                                                              "repr": repr(exc), "event_sequence": sequence}) from exc

    def _record(self, event: Mapping[str, Any]) -> None:
        receipt = dict(event)
        self._event_receipts.append(receipt)
        self._observer.record_lifecycle_event(receipt)

    def _continue_event(self, event: DebugEvent, status: int, sequence: int) -> None:
        self._api.continue_debug_event(event, status)
        self._continued_event_sequences.add(sequence)

    def _close_debug_event_file_once(self, event: DebugEvent, event_sequence: int,
                                     purpose: str) -> Mapping[str, Any]:
        if not event.file_handle:
            return {"attempted": False, "complete": True, "purpose": purpose}
        previous = self._debug_file_close_receipts.get(event_sequence)
        if previous is not None:
            if previous.get("handle") != event.file_handle or \
                    previous.get("event_code") != event.code or \
                    previous.get("event_pid") != event.process_id or \
                    previous.get("event_thread_id") != event.thread_id:
                mismatch = {"purpose": purpose, "handle": event.file_handle,
                    "event_code": event.code, "event_pid": event.process_id,
                    "event_thread_id": event.thread_id,
                    "event_sequence": event_sequence, "close_attempted": False,
                    "complete": False, "error": {
                        "type": "LifecycleError",
                        "repr": "debug event sequence was reused with different CREATE metadata"}}
                self._cleanup_errors.append({**mismatch,
                                             "purpose": "debug_event_file_close_sequence_mismatch"})
                return mismatch
            return {"purpose": purpose, "handle": event.file_handle,
                    "event_code": event.code, "event_pid": event.process_id,
                    "event_thread_id": event.thread_id,
                    "event_sequence": event_sequence, "close_attempted": False,
                    "already_closed": True, "closed_by_purpose": previous["purpose"],
                    "complete": True}
        row: dict[str, Any] = {"purpose": purpose, "handle": event.file_handle,
                               "event_code": event.code, "event_pid": event.process_id,
                               "event_thread_id": event.thread_id,
                               "event_sequence": event_sequence, "close_attempted": True}
        try:
            self._api.close_debug_file(event.file_handle)
        except Exception as exc:
            row.update({"complete": False, "error": {"type": type(exc).__name__,
                "repr": repr(exc), "winerror": getattr(exc, "winerror", None)}})
            self._pending_debug_file_handles.append(dict(row))
            self._cleanup_errors.append({"purpose": "debug_event_file_close", **row})
        else:
            row["complete"] = True
            self._debug_file_close_receipts[event_sequence] = dict(row)
        return row

    @staticmethod
    def _valid_module_file_identity(value: Any) -> bool:
        return (type(value) is tuple and len(value) == 2 and type(value[0]) is int and
                0 <= value[0] < (1 << 64) and type(value[1]) is str and len(value[1]) == 32 and
                any(ch != "0" for ch in value[1]) and
                all(ch in "0123456789abcdef" for ch in value[1]))

    def _remember_module_lineage_error(self, identity: ProcessIdentity, event_name: str,
                                       event: DebugEvent, event_sequence: int,
                                       reason: str) -> None:
        self._module_lineage_errors.setdefault(identity, []).append({
            "event": event_name, "reason": reason, "event_code": event.code,
            "event_pid": event.process_id, "thread_id": event.thread_id,
            "event_sequence": event_sequence, "raw": dict(event.raw),
        })

    def _process_load_dll_event(self, event: DebugEvent, event_sequence: int) -> None:
        raw = dict(event.raw)
        identity: ProcessIdentity | None = None
        witness: dict[str, Any] | None = None
        try:
            identity = self._identity_for_pid(event.process_id)
            base = raw.get("module_base")
            file_identity = raw.get("module_file_identity")
            valid_base = type(base) is int and 0 < base < (1 << (ctypes.sizeof(ctypes.c_void_p) * 8))
            valid_file_identity = self._valid_module_file_identity(file_identity)
            modules = self._loaded_module_witnesses.setdefault(identity, {})
            duplicate_base = valid_base and base in modules
            witness = {
                "identity": _identity_value(identity),
                "module_base": base if valid_base else None,
                "module_file_identity": list(file_identity) if valid_file_identity else None,
                "load_event_sequence": event_sequence,
                "file_handle_present": bool(event.file_handle),
                "witness_complete": bool(valid_base and valid_file_identity and not duplicate_base),
                "raw": raw,
            }
            if duplicate_base:
                witness["lineage_error"] = "duplicate_live_module_base"
            elif not valid_base:
                witness["lineage_error"] = "invalid_or_missing_module_base"
            elif not valid_file_identity:
                witness["lineage_error"] = "module_file_identity_unavailable_or_malformed"
            if valid_base:
                # A duplicate base invalidates the old witness too; keeping either
                # mapping would make a later exception appear to have exact lineage.
                modules[base] = witness
            if not witness["witness_complete"]:
                self._remember_module_lineage_error(identity, "load_dll", event, event_sequence,
                                                    witness["lineage_error"])
        except Exception as exc:
            close_receipt = self._close_debug_event_file_once(event, event_sequence, "loaded_module_file")
            failed_receipt = {"event": "load_dll_rejected", "identity":
                _identity_value(identity) if identity is not None else None,
                "thread_id": event.thread_id, "event_sequence": event_sequence,
                "module_witness": witness, "file_handle_close": dict(close_receipt),
                "raw": raw, "error": {"type": type(exc).__name__, "repr": repr(exc)}}
            self._record(failed_receipt)
            raise LifecycleError("load_dll_lineage", "LOAD_DLL event could not be bound to one live generation",
                                 identity=identity, evidence=failed_receipt) from exc

        close_receipt = self._close_debug_event_file_once(event, event_sequence, "loaded_module_file")
        receipt = {"event": "load_dll", "identity": _identity_value(identity),
                   "thread_id": event.thread_id, "event_sequence": event_sequence,
                   "module_witness": witness, "file_handle_close": dict(close_receipt), "raw": raw}
        self._record(receipt)
        if close_receipt.get("complete") is not True:
            raise LifecycleError("load_dll_file_close", "debug-owned DLL file handle close failed",
                                 identity=identity, evidence=receipt)
        self._continue_event(event, DBG_CONTINUE, event_sequence)

    def _process_unload_dll_event(self, event: DebugEvent, event_sequence: int) -> None:
        raw = dict(event.raw)
        try:
            identity = self._identity_for_pid(event.process_id)
        except Exception as exc:
            receipt = {"event": "unload_dll_rejected", "identity": None,
                "thread_id": event.thread_id, "event_sequence": event_sequence,
                "module_base": raw.get("module_base"), "lineage_match": False,
                "raw": raw, "error": {"type": type(exc).__name__, "repr": repr(exc)}}
            self._record(receipt)
            raise LifecycleError("unload_dll_identity", "UNLOAD_DLL event has no exact active generation",
                                 evidence=receipt) from exc
        base = raw.get("module_base")
        modules = self._loaded_module_witnesses.setdefault(identity, {})
        valid_base = type(base) is int and 0 < base < (1 << (ctypes.sizeof(ctypes.c_void_p) * 8))
        prior = modules.pop(base, None) if valid_base else None
        matched = (isinstance(prior, Mapping) and prior.get("witness_complete") is True and
                   type(prior.get("load_event_sequence")) is int and
                   prior["load_event_sequence"] < event_sequence)
        if not matched:
            self._remember_module_lineage_error(identity, "unload_dll", event, event_sequence,
                "invalid_base_or_no_exact_live_load_witness")
        receipt = {"event": "unload_dll", "identity": _identity_value(identity),
                   "thread_id": event.thread_id, "event_sequence": event_sequence,
                   "module_base": base if valid_base else None,
                   "matched_load_witness": dict(prior) if isinstance(prior, Mapping) else None,
                   "lineage_match": matched, "raw": raw}
        self._record(receipt)
        self._continue_event(event, DBG_CONTINUE, event_sequence)

    def _validate_initial_loader_event(self, event: DebugEvent, identity: ProcessIdentity,
                                       event_sequence: int) -> tuple[bool, Mapping[str, Any]]:
        expected_thread = self._initial_thread_ids.get(identity)
        modules = self._loaded_module_witnesses.get(identity, {})
        lineage_errors = self._module_lineage_errors.get(identity, [])
        attempts: list[dict[str, Any]] = []
        if lineage_errors:
            return False, {"complete": False, "reason": "module_lineage_has_errors",
                           "lineage_errors": [dict(item) for item in lineage_errors],
                           "raw": dict(event.raw), "attempts": attempts}
        if expected_thread is None or event.thread_id != expected_thread:
            return False, {"complete": False, "reason": "exception_thread_is_not_initial_create_thread",
                           "expected_thread_id": expected_thread, "event_thread_id": event.thread_id,
                           "raw": dict(event.raw), "attempts": attempts}
        native_validator = getattr(self._api, "initial_loader_breakpoint", None)
        native_receipt_reader = getattr(self._api, "loader_validation_receipt", None)
        if not callable(native_validator) or not callable(native_receipt_reader):
            return False, {"complete": False, "reason": "native_loader_validator_unavailable",
                           "raw": dict(event.raw), "attempts": attempts}
        process_handle = self.handle_for(identity)
        for base, module in sorted(modules.items(), key=lambda pair: pair[0]):
            if module.get("witness_complete") is not True:
                continue
            identity_pair = module.get("module_file_identity")
            if type(identity_pair) is not list or len(identity_pair) != 2:
                continue
            file_identity = (identity_pair[0], identity_pair[1])
            try:
                accepted = native_validator(process_handle, identity, thread_id=event.thread_id,
                    create_event_thread_id=expected_thread,
                    exception_address=event.raw.get("exception_address"),
                    exception_code=event.exception_code if event.exception_code is not None else -1,
                    first_chance=event.first_chance is True,
                    module_process_identity=identity, module_base=base,
                    module_file_identity=file_identity,
                    module_load_sequence=module["load_event_sequence"],
                    exception_sequence=event_sequence)
                native_receipt = native_receipt_reader()
                receipt_matches = (isinstance(native_receipt, Mapping) and
                    native_receipt.get("schema") == "fca-initial-loader-breakpoint-validation-v1" and
                    native_receipt.get("complete") is True and
                    native_receipt.get("reason") == "exact_loaded_ntdll_dbg_breakpoint" and
                    native_receipt.get("identity") == _identity_value(identity) and
                    native_receipt.get("module_process_identity") == _identity_value(identity) and
                    native_receipt.get("module_base") == base and
                    native_receipt.get("module_file_identity") == identity_pair and
                    native_receipt.get("module_load_sequence") == module["load_event_sequence"] and
                    native_receipt.get("exception_sequence") == event_sequence and
                    native_receipt.get("thread_id") == event.thread_id and
                    native_receipt.get("create_event_thread_id") == expected_thread and
                    native_receipt.get("exception_address") == event.raw.get("exception_address") and
                    native_receipt.get("exception_code") == EXCEPTION_BREAKPOINT and
                    native_receipt.get("first_chance") is True and
                    native_receipt.get("remote_opcode_matches") is True)
                attempts.append({"module_witness": dict(module),
                    "native_validation": dict(native_receipt) if isinstance(native_receipt, Mapping) else repr(native_receipt),
                    "accepted": accepted is True and receipt_matches})
            except Exception as exc:
                attempts.append({"module_witness": dict(module), "accepted": False,
                    "error": {"type": type(exc).__name__, "repr": repr(exc),
                              "stage": getattr(exc, "stage", None),
                              "winerror": getattr(exc, "winerror", None)}})
        accepted = [item for item in attempts if item.get("accepted") is True]
        return (len(accepted) == 1,
                {"complete": len(accepted) == 1,
                 "reason": "exactly_one_native_ntdll_witness" if len(accepted) == 1 else
                           "native_loader_witness_missing_or_ambiguous",
                 "expected_thread_id": expected_thread, "event_thread_id": event.thread_id,
                 "raw": dict(event.raw), "attempts": attempts})

    def _process_exit_event(self, event: DebugEvent, event_sequence: int,
                            sample_attempt_id: int | None = None) -> None:
        identities = [identity for identity in self._active_identities if identity.pid == event.process_id]
        if len(identities) != 1:
            raise LifecycleError("exit_identity", "EXIT event has no unique registered generation",
                                 evidence={"event_pid": event.process_id,
                                           "generations": [x.creation_time_100ns for x in identities]})
        identity = identities[0]
        witness = self._birth_witnesses.get(identity)
        measurement: Mapping[str, Any] = {"complete": False, "error": "not_attempted"}
        measurement_error: Mapping[str, Any] | None = None
        resource_complete = False
        duplicate: _OwnedHandle | None = None
        wait_result: int | None = None
        code: int | None = None
        close_error: Mapping[str, Any] | None = None
        retained: int | None = None
        try:
            if witness is None:
                raise LifecycleError("exit_source_witness", "registered CREATE source witness is absent",
                                     identity=identity)
            retained = self._registry.handle_for(identity)
            if _raw_handle(retained, stage="registry.handle_for") != self._handles[identity].raw:
                raise LifecycleError("exit_identity", "registry returned a different retained handle", identity=identity)
            if self._api.read_identity(retained) != identity:
                raise LifecycleError("exit_identity", "retained handle identity changed before EXIT read",
                                     identity=identity)
            row_identity = ProcessIdentity(witness.row.identity.pid, witness.row.identity.create_time_100ns)
            if row_identity != identity:
                raise LifecycleError("exit_source_witness", "bound CREATE source row generation differs",
                                     identity=identity)
            source_sequence = witness.source_receipt.get("sequence")
            if type(source_sequence) is not int or source_sequence < 0:
                raise LifecycleError("exit_source_witness", "bound CREATE source history reference is invalid",
                                     identity=identity)
            measured = self._measure_exact_handle(retained, identity, witness.row, phase="exit_pre_continue",
                event_sequence=event_sequence, event_receipt={"event_code": event.code,
                    "event_pid": event.process_id, "event_exit_code": event.exit_code,
                    "event_sequence": event_sequence, "sample_attempt_id": sample_attempt_id,
                    "birth_source_sequence": source_sequence})
            measurement = measured["measurement_receipt"]
            resource_complete = self._observer.record_resource_measurement(measurement) is True
            if not resource_complete:
                raise LifecycleError("exit_measurement", "observer did not durably record EXIT measurement",
                                     identity=identity)
        except Exception as exc:
            measurement_error = {"type": type(exc).__name__, "repr": repr(exc),
                                 "stage": getattr(exc, "stage", None),
                                 "winerror": getattr(exc, "winerror", None)}
            resource_complete = False
        if retained is not None:
            try:
                duplicate_raw = self._api.duplicate_handle(retained)
                duplicate = _OwnedHandle(duplicate_raw, identity, "exit_proof_duplicate")
                self._temporary_handles.append(duplicate)
                if self._api.read_identity(duplicate_raw) != identity:
                    self._cleanup_handle(duplicate)
                    close_error = dict(duplicate.close_error or {"error": "wrong-identity duplicate close incomplete"})
                    duplicate = None
                    raise LifecycleError("exit_duplicate", "EXIT proof duplicate has wrong identity", identity=identity)
            except Exception as exc:
                measurement_error = {**dict(measurement_error or {}),
                    "exit_duplicate_error": {"type": type(exc).__name__, "repr": repr(exc),
                                             "winerror": getattr(exc, "winerror", None)}}
                if duplicate is not None and not duplicate.closed:
                    self._cleanup_handle(duplicate)
                    if not duplicate.closed:
                        close_error = dict(duplicate.close_error or {"error": "duplicate close incomplete"})
                duplicate = None
        # EXIT is already terminating the process; continuing this event does
        # not release a live CREATE. Do so even if measurement failed, while
        # retaining zero resource/exit credit for the failed proof.
        continue_error = None
        try:
            self._continue_event(event, DBG_CONTINUE, event_sequence)
        except Exception as exc:
            continue_error = {"type": type(exc).__name__, "repr": repr(exc),
                              "winerror": getattr(exc, "winerror", None)}
        if duplicate is not None and continue_error is None:
            try:
                remaining_ms = max(0, int((self._deadline - self._clock()) * 1000.0))
                wait_result = self._api.wait_handle(duplicate.raw, remaining_ms)
                if wait_result == WAIT_OBJECT_0:
                    code = self._api.exit_code(duplicate.raw)
            except Exception as exc:
                measurement_error = {**dict(measurement_error or {}),
                    "exit_wait_error": {"type": type(exc).__name__, "repr": repr(exc),
                                        "winerror": getattr(exc, "winerror", None)}}
            self._cleanup_handle(duplicate)
            if not duplicate.closed:
                close_error = dict(duplicate.close_error or {"error": "duplicate close incomplete"})
        proof = (continue_error is None and wait_result == WAIT_OBJECT_0 and code is not None and
                 code != STILL_ACTIVE and code == event.exit_code and close_error is None)
        if proof:
            self._active_identities.discard(identity)
        receipt = ProcessExitReceipt("fca-managed-process-exit-v1", identity, event.process_id,
            int(event.exit_code if event.exit_code is not None else -1), dict(measurement),
            -1 if wait_result is None else wait_result,
            -1 if code is None else code, proof, resource_complete, event_sequence,
            (witness.source_receipt["sequence"] if witness is not None and
             type(witness.source_receipt.get("sequence")) is int else 0), sample_attempt_id)
        self._exit_receipts.append(receipt)
        self._record({"event": "exit_reconciled", "identity": _identity_value(identity),
                      "event_sequence": event_sequence, "sample_attempt_id": sample_attempt_id,
                      "birth_source_sequence": receipt.birth_source_sequence,
                      "birth_source_receipt": (dict(witness.source_receipt) if witness is not None else None),
                      "debug_event_exit_code": event.exit_code, "handle_exit_code": code,
                      "wait_result": wait_result, "exit_proof_complete": proof,
                      "resource_measurement_complete": resource_complete,
                      "measurement_error": measurement_error, "continue_error": continue_error,
                      "close_error": close_error})
        if identity == self._root_identity:
            if proof:
                self._returncode = code
        if not proof or not resource_complete:
            self._fatal = LifecycleError("exit_proof", "exit/resource evidence incomplete", identity=identity,
                evidence={"proof": proof, "resource_complete": resource_complete,
                          "measurement_error": measurement_error, "continue_error": continue_error})

    def _handle_debug_event(self, event: DebugEvent, sequence: int,
                            sample_attempt_id: int | None = None) -> None:
        if event.code == CREATE_PROCESS_DEBUG_EVENT:
            try:
                self._handle_create_event(event, is_root=(event.process_id == self.pid and
                                         self._root_identity is None and self._create_seen == set()),
                                           event_sequence=sequence)
            except Exception as exc:
                contained = self._contain_failed_create_event(event, sequence, exc, sample_attempt_id)
                if not contained:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                raise
            finally:
                if event.file_handle:
                    close_receipt = self._close_debug_event_file_once(event, sequence, "created_image_file")
                    self._record({"event": "debug_event_file_close", "identity":
                        _identity_value(self._root_identity) if self._root_identity is not None else None,
                        "thread_id": event.thread_id, "event_sequence": sequence,
                        "file_handle_close": dict(close_receipt), "raw": dict(event.raw)})
                    if close_receipt.get("complete") is not True:
                        raise LifecycleError("create_debug_file_close", "debug-owned image file handle close failed",
                            identity=self._root_identity,
                            evidence={"event_sequence": sequence, "close": dict(close_receipt),
                                      "raw": dict(event.raw)})
            # CREATE event process/thread handles are owned by the debug API;
            # ContinueDebugEvent controls their lifetime. Only hFile closes here.
            return
        if event.code == EXIT_PROCESS_DEBUG_EVENT:
            try:
                self._process_exit_event(event, sequence, sample_attempt_id)
            except Exception:
                if sequence not in self._continued_event_sequences:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                raise
            return
        if event.code == LOAD_DLL_DEBUG_EVENT:
            try:
                self._process_load_dll_event(event, sequence)
            except Exception as exc:
                if sequence not in self._continued_event_sequences:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                self._fatal = exc if isinstance(exc, LifecycleError) else LifecycleError(
                    "load_dll_event", "LOAD_DLL handling failed", evidence={
                        "type": type(exc).__name__, "repr": repr(exc), "raw": dict(event.raw),
                        "event_sequence": sequence})
                raise self._fatal
            return
        if event.code == UNLOAD_DLL_DEBUG_EVENT:
            try:
                self._process_unload_dll_event(event, sequence)
            except Exception as exc:
                if sequence not in self._continued_event_sequences:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                self._fatal = exc if isinstance(exc, LifecycleError) else LifecycleError(
                    "unload_dll_event", "UNLOAD_DLL handling failed", evidence={
                        "type": type(exc).__name__, "repr": repr(exc), "raw": dict(event.raw),
                        "event_sequence": sequence})
                raise self._fatal
            return
        if event.code == EXCEPTION_DEBUG_EVENT:
            try:
                identity = self._identity_for_pid(event.process_id)
            except Exception as exc:
                receipt = {"event": "exception_identity_rejected", "event_pid": event.process_id,
                    "thread_id": event.thread_id, "event_sequence": sequence,
                    "exception_code": event.exception_code, "first_chance": event.first_chance,
                    "raw": dict(event.raw), "error": {"type": type(exc).__name__, "repr": repr(exc)}}
                self._record(receipt)
                self._retain_pending_event(event, sequence, sample_attempt_id)
                self._fatal = LifecycleError("debug_exception_identity",
                    "exception event has no exact active process generation", evidence=receipt)
                raise self._fatal from exc
            if event.exception_code == EXCEPTION_BREAKPOINT and event.first_chance is True and \
                    identity in self._first_breakpoint_pending:
                validated, native_witness = self._validate_initial_loader_event(event, identity, sequence)
                receipt = {"event": "initial_loader_breakpoint" if validated else
                           "initial_loader_breakpoint_rejected",
                           "identity": _identity_value(identity), "thread_id": event.thread_id,
                           "exception_address": event.raw.get("exception_address"),
                           "exception_code": event.exception_code, "first_chance": event.first_chance,
                           "event_sequence": sequence, "native_witness": dict(native_witness),
                           "raw": dict(event.raw)}
                try:
                    self._record(receipt)
                except Exception as exc:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                    self._fatal = LifecycleError("initial_loader_receipt",
                        "initial breakpoint receipt could not be recorded", identity=identity,
                        evidence={**receipt, "record_error": {"type": type(exc).__name__, "repr": repr(exc)}})
                    raise self._fatal from exc
                if validated:
                    try:
                        self._continue_event(event, DBG_CONTINUE, sequence)
                    except Exception as exc:
                        self._retain_pending_event(event, sequence, sample_attempt_id)
                        self._fatal = LifecycleError("initial_loader_continue",
                            "proved initial breakpoint could not be continued", identity=identity,
                            evidence={**receipt, "continue_error": {"type": type(exc).__name__,
                                "repr": repr(exc), "winerror": getattr(exc, "winerror", None)}})
                        raise self._fatal from exc
                    self._first_breakpoint_pending.remove(identity)
                    return
                self._fatal = LifecycleError("initial_loader_breakpoint",
                    "first initial breakpoint lacked an exact native loaded-ntdll witness",
                    identity=identity, evidence=receipt)
                try:
                    self._continue_event(event, DBG_EXCEPTION_NOT_HANDLED, sequence)
                except Exception as exc:
                    self._retain_pending_event(event, sequence, sample_attempt_id)
                    self._fatal.evidence = {**self._fatal.evidence, "continue_error": {
                        "type": type(exc).__name__, "repr": repr(exc),
                        "winerror": getattr(exc, "winerror", None)}}
                    raise self._fatal from exc
                try:
                    self.terminate()
                except Exception as exc:
                    self._fatal.evidence = {**self._fatal.evidence, "terminate_error": {
                        "type": type(exc).__name__, "repr": repr(exc),
                        "winerror": getattr(exc, "winerror", None)}}
                raise self._fatal
            if event.first_chance is True:
                self._continue_event(event, DBG_EXCEPTION_NOT_HANDLED, sequence)
                self._record({"event": "first_chance_exception_passed", "identity": _identity_value(identity),
                              "pid": event.process_id, "thread_id": event.thread_id,
                              "exception_code": event.exception_code, "first_chance": event.first_chance,
                              "event_sequence": sequence, "raw": dict(event.raw)})
                return
            self._fatal = LifecycleError("debug_exception", "second-chance/unclassified exception",
                identity=identity, evidence={"exception_code": event.exception_code,
                                             "first_chance": event.first_chance, "sequence": sequence,
                                             "thread_id": event.thread_id, "raw": dict(event.raw)})
            self._continue_event(event, DBG_EXCEPTION_NOT_HANDLED, sequence)
            self.terminate()
            raise self._fatal
        if event.code in (CREATE_THREAD_DEBUG_EVENT, EXIT_THREAD_DEBUG_EVENT,
                          OUTPUT_DEBUG_STRING_EVENT, RIP_EVENT):
            self._continue_event(event, DBG_CONTINUE, sequence)
            self._record({"event": "non_membership_debug_event", "event_code": event.code,
                          "pid": event.process_id, "thread_id": event.thread_id, "sequence": sequence})
            return
        self._fatal = LifecycleError("debug_event", "unclassified debug event", evidence={
            "event_code": event.code, "pid": event.process_id, "thread_id": event.thread_id,
            "sequence": sequence})
        raise self._fatal

    def _identity_for_pid(self, pid: int) -> ProcessIdentity:
        rows = [identity for identity in self._active_identities if identity.pid == pid]
        if len(rows) != 1:
            raise LifecycleError("identity_lookup", "debug event PID has no unique registered generation",
                                 evidence={"pid": pid, "generations": [x.creation_time_100ns for x in rows]})
        return rows[0]

    def pump_debug_events(self, *, max_events: int = 1024) -> tuple[DebugEvent, ...]:
        self._check_owner()
        if self._pending_start_event is not None:
            raise LifecycleError("startup_barrier", "debug pump is held until first standard sample is accepted",
                                 identity=self._root_identity)
        if self._active_attempt is not None:
            raise LifecycleError("sample_boundary", "debug events cannot be pumped inside a whole sample attempt")
        if type(max_events) is not int or max_events < 1:
            raise LifecycleError("debug_pump", "max_events must be positive")
        processed: list[DebugEvent] = []
        for index in range(max_events):
            event = self._api.wait_debug_event(0 if index else min(1, self._remaining_ms()))
            if event is None:
                break
            self._event_sequence += 1
            sequence = self._event_sequence
            try:
                self._handle_debug_event(event, sequence)
            except Exception as exc:
                self._fatal = exc if isinstance(exc, LifecycleError) else LifecycleError(
                    "debug_event", "event handling failed", evidence={"type": type(exc).__name__, "repr": repr(exc)})
                raise self._fatal
            processed.append(event)
        return tuple(processed)

    def begin_sample_attempt(self) -> int:
        self._check_owner()
        if self._active_attempt is not None:
            raise LifecycleError("sample_boundary", "nested whole-sample attempts are forbidden")
        if self._held_events:
            raise LifecycleError("sample_boundary", "prior debug event remains held")
        if self._pending_start_event is not None and self._startup_hold_kind != "debug_create_event":
            raise LifecycleError("sample_boundary", "unknown startup event hold prevents sampling")
        self._attempt_counter += 1
        self._active_attempt = self._attempt_counter
        self._active_attempt_changed = False
        self._active_attempt_codes = []
        self.sample_boundary_checkpoint(self._active_attempt)
        return self._active_attempt

    def sample_boundary_checkpoint(self, attempt_id: int) -> SampleBoundaryCheckpoint:
        """Observe and hold queued debug events at a sample read boundary.

        This stays on the debug owner thread, uses only a zero-timeout wait,
        never continues events, and marks the current whole-tree attempt
        incomplete as soon as any event is observed.
        """
        self._check_owner()
        if self._active_attempt is None or attempt_id != self._active_attempt:
            raise LifecycleError("sample_boundary", "checkpoint attempt identity mismatch")
        if self._pending_boundary_events:
            return SampleBoundaryCheckpoint(self._active_attempt, True,
                                            tuple(self._active_attempt_codes))
        event = self._api.wait_debug_event(0)
        if event is not None:
            self._event_sequence += 1
            held = _HeldEvent(event, self._event_sequence, self._active_attempt)
            self._pending_boundary_events.append(held)
            self._active_attempt_changed = True
            self._active_attempt_codes.append(event.code)
        return SampleBoundaryCheckpoint(self._active_attempt,
            event is not None,
            tuple(self._active_attempt_codes))

    def observe_sample_event_arrival(self, event: DebugEvent) -> None:
        """Consumer hook for a debug event discovered between its SPI reads."""
        self._check_owner()
        if self._active_attempt is None:
            raise LifecycleError("sample_boundary", "sample event hook used without active attempt")
        self._event_sequence += 1
        held = _HeldEvent(event, self._event_sequence, self._active_attempt)
        self._pending_boundary_events.append(held)
        self._active_attempt_changed = True
        self._active_attempt_codes.append(event.code)

    def end_sample_attempt(self, attempt_id: int) -> SampleAttemptBoundary:
        self._check_owner()
        if self._active_attempt is None or attempt_id != self._active_attempt:
            raise LifecycleError("sample_boundary", "attempt identity mismatch")
        self.sample_boundary_checkpoint(attempt_id)
        codes = tuple(self._active_attempt_codes)
        changed = self._active_attempt_changed
        result = SampleAttemptBoundary(attempt_id, not changed, changed, codes,
            "debug_membership_event_during_sample" if changed else None)
        self._active_attempt = None
        self._active_attempt_changed = False
        self._active_attempt_codes = []
        return result

    def release_boundary_events(self) -> tuple[DebugEvent, ...]:
        """Process held membership events after the caller discards the attempt."""
        self._check_owner()
        if self._pending_start_event is not None:
            raise LifecycleError("startup_barrier", "boundary event release is held until first standard sample is accepted",
                                 identity=self._root_identity)
        if self._active_attempt is not None:
            raise LifecycleError("sample_boundary", "cannot release events before ending/discarding attempt")
        processed: list[DebugEvent] = []
        while self._pending_boundary_events:
            item = self._pending_boundary_events[0]
            try:
                self._handle_debug_event(item.event, item.event_sequence, item.sample_attempt_id)
            except Exception:
                # A post-Continue failure may have a receipt in the session;
                # preserve the exact event for audit but do not replay a
                # continued event. Pre-Continue failures remain blocked.
                if item.event_sequence in self._continued_event_sequences:
                    self._pending_boundary_events.pop(0)
                raise
            else:
                self._pending_boundary_events.pop(0)
            processed.append(item.event)
        processed.extend(self.pump_debug_events())
        return tuple(processed)

    def check_membership(self, job_pids: Sequence[int], spi_identities: Sequence[ProcessIdentity]) -> bool:
        """Return exact registered-membership equality; never sample/retry here."""
        self._check_owner()
        expected = {(item.pid, item.creation_time_100ns) for item in spi_identities}
        registered = {(item.pid, item.creation_time_100ns) for item in self._active_identities}
        pids = {item.pid for item in spi_identities}
        if any(type(pid) is not int or pid <= 0 for pid in job_pids):
            raise LifecycleError("membership", "Job inventory contains malformed PID")
        if pids != set(job_pids) or expected != registered:
            return False
        return True

    def job_process_ids(self) -> tuple[int, ...]:
        """Return the exact retained Job's live PID inventory on the owner thread."""
        self._check_owner()
        if self._root_job is None:
            raise LifecycleError("membership", "no exact configured Job was retained")
        reader = getattr(self._api, "job_process_ids", None)
        if not callable(reader):
            raise LifecycleError("membership", "native API cannot enumerate the exact Job")
        pids = reader(self._root_job)
        if type(pids) is not tuple or any(type(pid) is not int or pid <= 0 for pid in pids) or \
                tuple(sorted(set(pids))) != pids:
            raise LifecycleError("membership", "native Job PID inventory is malformed")
        return pids

    def handle_for(self, identity: ProcessIdentity) -> int:
        self._check_owner()
        if identity not in self._handles:
            raise BirthPending(identity)
        raw = self._registry.handle_for(identity)
        if _raw_handle(raw, stage="registry.handle_for") != self._handles[identity].raw:
            raise LifecycleError("registry_handle", "registry handle differs from adopted generation", identity=identity)
        if self._api.read_identity(raw) != identity:
            raise LifecycleError("registry_handle", "adopted handle identity changed", identity=identity)
        return raw

    def handle_provider(self, row: Any) -> int:
        try:
            identity = ProcessIdentity(row.identity.pid, row.identity.create_time_100ns)
        except Exception as exc:
            raise LifecycleError("handle_provider", "row lacks exact process identity") from exc
        return self.handle_for(identity)

    def identity_reader(self, handle: int) -> tuple[int, int]:
        identity = self._api.read_identity(_raw_handle(handle, stage="identity_reader"))
        return identity.pid, identity.creation_time_100ns

    def measurement_values_for_exact_handle(self, handle: int,
                                            expected_identity: ProcessIdentity) -> Mapping[str, Any]:
        """Read resource values through the supplied retained handle only.

        This public seam lets the existing observer build/record its receipt
        without reopening a PID or recursively calling resource_reader.
        """
        raw = _raw_handle(handle, stage="measurement_values")
        before = self._api.read_identity(raw)
        if before != expected_identity:
            raise LifecycleError("measurement_values", "exact handle identity mismatch before native read",
                                 identity=expected_identity)
        values = self._api.resource_values(raw)
        after = self._api.read_identity(raw)
        if before != after or after != expected_identity:
            raise LifecycleError("measurement_values", "exact handle identity changed during native read",
                                 identity=expected_identity)
        if not isinstance(values, Mapping) or set(values) != {
                "rss_bytes", "cpu_user_seconds", "cpu_system_seconds", "cmdline"}:
            raise LifecycleError("measurement_values", "native resource reader returned malformed fields",
                                 identity=expected_identity)
        if type(values["rss_bytes"]) is not int or values["rss_bytes"] < 0:
            raise LifecycleError("measurement_values", "native RSS is not a nonnegative integer",
                                 identity=expected_identity)
        for key in ("cpu_user_seconds", "cpu_system_seconds"):
            value = values[key]
            if type(value) is not float or not math.isfinite(value) or value < 0:
                raise LifecycleError("measurement_values", f"native {key} is not finite nonnegative float",
                                     identity=expected_identity)
        if type(values["cmdline"]) is not list or any(type(part) is not str for part in values["cmdline"]):
            raise LifecycleError("measurement_values", "native command line is malformed", identity=expected_identity)
        return {"rss_bytes": values["rss_bytes"], "cpu_user_seconds": values["cpu_user_seconds"],
                "cpu_system_seconds": values["cpu_system_seconds"], "cmdline": list(values["cmdline"]),
                "handle_identity_before": before, "handle_identity_after": after}

    def _measure_exact_handle(self, handle: int, identity: ProcessIdentity, row: Any, *, phase: str,
                              event_sequence: int,
                              event_receipt: Mapping[str, Any]) -> Mapping[str, Any]:
        values = self.measurement_values_for_exact_handle(handle, identity)
        receipt = {"schema": RESOURCE_MEASUREMENT_SCHEMA, "phase": phase,
            "identity": _identity_value(identity),
            "handle_identity_before": _identity_value(values["handle_identity_before"]),
            "handle_identity_after": _identity_value(values["handle_identity_after"]),
            "event_sequence": event_sequence, "complete": True,
            "rss_bytes": values["rss_bytes"], "cpu_user_seconds": values["cpu_user_seconds"],
            "cpu_system_seconds": values["cpu_system_seconds"], "cmdline": values["cmdline"],
            "source_tags": ["GetProcessMemoryInfo", "GetProcessTimes",
                            "NtQueryInformationProcess.ProcessCommandLineInformation"]}
        validated = _validate_measurement(receipt, identity, phase=phase, event_sequence=event_sequence)
        return {"rss_bytes": validated["rss_bytes"], "cpu_user_seconds": validated["cpu_user_seconds"],
                "cpu_system_seconds": validated["cpu_system_seconds"], "cmdline": validated["cmdline"],
                "measurement_receipt": validated}

    def resource_reader(self, handle: int, expected_identity: ProcessIdentity, row: Any,
                        *, phase: str, event_receipt: Mapping[str, Any] | None = None) -> Mapping[str, Any]:
        event = dict(event_receipt or {})
        sequence = event.get("event_sequence")
        if type(sequence) is not int or sequence <= 0:
            raise LifecycleError("resource_reader", "sample event receipt lacks a positive attempt sequence",
                                 identity=expected_identity)
        measured = self._measure_exact_handle(handle, expected_identity, row, phase=phase,
                                              event_sequence=sequence, event_receipt=event)
        if self._observer.record_resource_measurement(measured["measurement_receipt"]) is not True:
            raise LifecycleError("resource_reader", "observer did not durably record measurement receipt",
                                 identity=expected_identity)
        return measured

    def command_line_for_exact(self, identity: ProcessIdentity) -> list[str]:
        handle = self.handle_for(identity)
        before = self._api.read_identity(handle)
        if before != identity:
            raise LifecycleError("command_line", "handle identity changed before native query", identity=identity)
        command = self._api.command_line(handle)
        after = self._api.read_identity(handle)
        if before != after or after != identity:
            raise LifecycleError("command_line", "handle identity changed during native query", identity=identity)
        if type(command) is not list or any(type(item) is not str for item in command):
            raise LifecycleError("command_line", "native command line parser returned malformed argv", identity=identity)
        return command

    def _validate_initial_sample_receipt(self, receipt: Mapping[str, Any] | None) -> dict[str, Any]:
        if not isinstance(receipt, Mapping):
            raise LifecycleError("resume_root.sample", "durable first standard sample receipt is required",
                                 identity=self._root_identity)
        value = dict(receipt)
        if (value.get("schema") != "fca-standard-first-sample-receipt-v1" or
                value.get("sample_index") != 1 or value.get("sample_complete") is not True or
                value.get("standard_metrics") is not True or
                type(value.get("source_attempt_id")) is not int or
                value["source_attempt_id"] not in (1, 2) or
                value["source_attempt_id"] != self._attempt_counter or
                value.get("snapshot_complete") is not True):
            raise LifecycleError("resume_root.sample", "first sample disposition is incomplete or out of sequence",
                                 identity=self._root_identity, evidence={"receipt": value})
        identity = value.get("root_identity")
        expected_identity = _identity_value(self._root_identity) if self._root_identity is not None else None
        if identity != expected_identity:
            raise LifecycleError("resume_root.sample", "sample root identity differs from registered CREATE identity",
                                 identity=self._root_identity, evidence={"root_identity": identity})
        refs = value.get("source_history_refs")
        if (type(refs) is not list or not refs or any(not isinstance(item, Mapping) or
                item.get("complete") is not True or type(item.get("sequence")) is not int or
                item["sequence"] < 0 or not isinstance(item.get("reference"), Mapping)
                for item in refs)):
            raise LifecycleError("resume_root.sample", "complete source-history references are required",
                                 identity=self._root_identity)
        file_receipt = value.get("samples_file")
        if not isinstance(file_receipt, Mapping):
            raise LifecycleError("resume_root.sample", "durable samples.jsonl file receipt is required",
                                 identity=self._root_identity)
        path = file_receipt.get("path")
        size = file_receipt.get("bytes")
        digest = file_receipt.get("sha256")
        if (type(path) is not str or not os.path.isabs(path) or
                os.path.basename(path).casefold() != "samples.jsonl" or type(size) is not int or size <= 0 or
                not _is_sha256(digest) or file_receipt.get("flush") is not True or
                file_receipt.get("fsync") is not True):
            raise LifecycleError("resume_root.sample", "samples.jsonl path/hash/flush/fsync receipt is malformed",
                                 identity=self._root_identity)
        try:
            contents = Path(path).read_bytes()
        except Exception as exc:
            raise LifecycleError("resume_root.sample", "samples.jsonl could not be reopened for exact binding",
                                 identity=self._root_identity,
                                 evidence={"path": path, "type": type(exc).__name__, "repr": repr(exc)}) from exc
        if len(contents) != size or hashlib.sha256(contents).hexdigest() != digest:
            raise LifecycleError("resume_root.sample", "samples.jsonl bytes or SHA-256 changed after durable write",
                                 identity=self._root_identity,
                                 evidence={"path": path, "actual_bytes": len(contents),
                                           "claimed_bytes": size,
                                           "actual_sha256": hashlib.sha256(contents).hexdigest(),
                                           "claimed_sha256": digest})
        matches: list[Mapping[str, Any]] = []
        try:
            for raw_line in contents.splitlines():
                if not raw_line.strip():
                    continue
                row = json.loads(raw_line)
                if isinstance(row, Mapping) and row.get("sample_index") == 1:
                    matches.append(row)
        except Exception as exc:
            raise LifecycleError("resume_root.sample", "samples.jsonl contains malformed JSONL",
                                 identity=self._root_identity,
                                 evidence={"path": path, "type": type(exc).__name__, "repr": repr(exc)}) from exc
        root = matches[0].get("root_process_identity") if len(matches) == 1 else None
        root_id = None
        if isinstance(root, Mapping):
            try:
                root_id = ProcessIdentity(root.get("pid"), root.get("create_time_100ns"))
            except Exception:
                root_id = None
        if (len(matches) != 1 or matches[0].get("sample_complete") is not True or
                matches[0].get("errors") != [] or self._root_identity is None or
                root_id != self._root_identity or matches[0].get("root_identity_match_count") != 1 or
                matches[0].get("expected_process_count") != matches[0].get("observed_process_count") or
                type(matches[0].get("processes")) is not list or not matches[0]["processes"]):
            raise LifecycleError("resume_root.sample", "actual first sample row is incomplete or unbound",
                                 identity=self._root_identity,
                                 evidence={"row_count": len(matches), "row": dict(matches[0]) if matches else None})
        root_rows = [row for row in matches[0]["processes"] if isinstance(row, Mapping) and
                     row.get("pid") == self._root_identity.pid and
                     row.get("create_time_100ns") == self._root_identity.creation_time_100ns]
        if len(root_rows) != 1:
            raise LifecycleError("resume_root.sample", "sample process list lacks exactly one registered root row",
                                 identity=self._root_identity)
        if matches[0].get("sample_attempt_count") != value["source_attempt_id"]:
            raise LifecycleError("resume_root.sample", "sample attempt count differs from receipt",
                                 identity=self._root_identity)
        sample_rows = matches[0]["processes"]
        if any(not isinstance(row, Mapping) or type(row.get("pid")) is not int or
               type(row.get("create_time_100ns")) is not int or
               type(row.get("working_set_bytes")) is not int or row["working_set_bytes"] < 0 or
               type(row.get("user_cpu_seconds")) not in (int, float) or
               isinstance(row.get("user_cpu_seconds"), bool) or
               not math.isfinite(float(row["user_cpu_seconds"])) or row["user_cpu_seconds"] < 0 or
               type(row.get("system_cpu_seconds")) not in (int, float) or
               isinstance(row.get("system_cpu_seconds"), bool) or
               not math.isfinite(float(row["system_cpu_seconds"])) or row["system_cpu_seconds"] < 0
               for row in sample_rows):
            raise LifecycleError("resume_root.sample", "sample process rows lack complete standard resource metrics",
                                 identity=self._root_identity)
        metrics = ("process_tree_working_set_bytes", "process_tree_user_cpu_seconds",
                   "process_tree_system_cpu_seconds")
        for key in metrics:
            metric = matches[0].get(key)
            if (type(metric) not in (int, float) or isinstance(metric, bool) or
                    not math.isfinite(float(metric)) or metric < 0):
                raise LifecycleError("resume_root.sample", "sample lacks a finite nonnegative standard aggregate metric",
                                     identity=self._root_identity, evidence={"metric": key})
        rss_sum = sum(row["working_set_bytes"] for row in sample_rows)
        user_sum = sum(float(row["user_cpu_seconds"]) for row in sample_rows)
        system_sum = sum(float(row["system_cpu_seconds"]) for row in sample_rows)
        if (type(matches[0]["process_tree_working_set_bytes"]) is not int or
                matches[0]["process_tree_working_set_bytes"] != rss_sum or
                not math.isclose(float(matches[0]["process_tree_user_cpu_seconds"]), user_sum,
                                 rel_tol=0.0, abs_tol=1e-9) or
                not math.isclose(float(matches[0]["process_tree_system_cpu_seconds"]), system_sum,
                                 rel_tol=0.0, abs_tol=1e-9)):
            raise LifecycleError("resume_root.sample", "standard aggregate metrics do not match process rows",
                                 identity=self._root_identity)
        return {"schema": value["schema"], "sample_index": 1,
                "sample_complete": True, "standard_metrics": True,
                "source_attempt_id": value["source_attempt_id"],
                "snapshot_complete": True,
                "root_identity": expected_identity, "source_history_refs": [dict(x) for x in refs],
                "samples_file": {"path": os.path.abspath(path), "bytes": size, "sha256": digest,
                                 "flush": True, "fsync": True}}

    def resume_root_after_ack(self, *, initial_sample_receipt: Mapping[str, Any] | None = None) -> Mapping[str, Any]:
        self._check_owner()
        if self._startup_barrier_released:
            raise LifecycleError("resume_root", "root CREATE event was already continued")
        if self._root_identity is None or self._root_identity not in self._handles:
            raise LifecycleError("resume_root", "root has no registered identity/ACK")
        if self._fatal is not None:
            raise LifecycleError("resume_root", "session has a prior fatal error", identity=self._root_identity)
        held = self._pending_start_event
        if held is None or held.event.code != CREATE_PROCESS_DEBUG_EVENT or held.event.process_id != self._root_identity.pid:
            raise LifecycleError("resume_root", "exact registered root CREATE event is not pending",
                                 identity=self._root_identity)
        if self._active_attempt is not None or self._pending_boundary_events or self._held_events:
            raise LifecycleError("resume_root", "active sample or unresolved debug events prevent startup release",
                                 identity=self._root_identity,
                                 evidence={"active_attempt": self._active_attempt,
                                           "pending_boundary_event_count": len(self._pending_boundary_events),
                                           "held_event_count": len(self._held_events)})
        receipt = self._validate_initial_sample_receipt(initial_sample_receipt)
        self._remaining_ms()
        self._continue_event(held.event, DBG_CONTINUE, held.event_sequence)
        self._pending_start_event = None
        self._startup_sample_receipt = receipt
        self._startup_release_method = "continue_debug_event"
        self._startup_barrier_released = True
        release = {"event": "root_startup_barrier_released", "identity": _identity_value(self._root_identity),
                   "event_sequence": held.event_sequence, "startup_hold_kind": self._startup_hold_kind,
                   "release_method": self._startup_release_method,
                   "initial_sample_receipt": receipt}
        self._record(release)
        return release

    def poll(self) -> int | None:
        self._check_owner()
        if self._pending_start_event is not None:
            raise LifecycleError("startup_barrier", "poll is held until first standard sample is accepted",
                                 identity=self._root_identity)
        if self._active_attempt is not None:
            raise LifecycleError("poll", "poll cannot pump debug events during an active sample")
        if self._fatal is not None:
            raise self._fatal
        self.pump_debug_events()
        return self._returncode

    def wait(self, timeout: float | None = None) -> int:
        self._check_owner()
        if self._pending_start_event is not None:
            raise LifecycleError("startup_barrier", "wait is held until first standard sample is accepted",
                                 identity=self._root_identity)
        if timeout is not None and (type(timeout) not in (int, float) or isinstance(timeout, bool) or
                                    not math.isfinite(float(timeout)) or timeout < 0):
            raise ValueError("timeout must be finite and nonnegative")
        until = self._deadline if timeout is None else min(self._deadline, self._clock() + float(timeout))
        while self._returncode is None:
            if self._fatal is not None:
                raise self._fatal
            if self._active_attempt is not None:
                raise LifecycleError("wait", "cannot wait/pump while sample attempt active")
            remaining = until - self._clock()
            if remaining <= 0:
                raise TimeoutError("managed process did not exit before bounded wait")
            event = self._api.wait_debug_event(max(1, min(50, int(remaining * 1000))))
            if event is None:
                continue
            self._event_sequence += 1
            self._handle_debug_event(event, self._event_sequence)
        return self._returncode

    def send_signal(self, sig: int) -> None:
        self.terminate(exit_code=int(sig) & 0xFFFFFFFF)

    def terminate(self, exit_code: int = 15) -> None:
        self._check_owner()
        if self._root_job is not None:
            self._api.terminate_job(self._root_job, exit_code)
            return
        for identity in tuple(self._handles):
            handle = self.handle_for(identity)
            self._api.terminate_process(handle, exit_code)

    kill = terminate

    def _cleanup_handle(self, owned: _OwnedHandle) -> None:
        if owned.closed or not owned.owned:
            return
        try:
            self._api.close_handle(owned.raw)
            owned.owned = False
            owned.closed = True
            owned.close_error = None
        except Exception as exc:
            detail = {"purpose": owned.purpose, "identity": _identity_value(owned.identity)
                      if owned.identity else None, "handle": owned.raw,
                      "type": type(exc).__name__, "repr": repr(exc)}
            owned.close_error = detail
            self._cleanup_errors.append(detail)

    def close(self) -> Mapping[str, Any]:
        self._check_owner()
        if self._active_attempt is not None:
            raise LifecycleError("cleanup", "cannot close while a whole sample attempt is active")
        if self.cleanup_complete:
            return self.summary()
        if not self.exit_proof_complete:
            raise LifecycleError("cleanup", "cannot close lifecycle handles without complete root/tree exit proof",
                                 evidence={"returncode": self._returncode,
                                           "active_identities": [_identity_value(x) for x in sorted(self._active_identities)],
                                           "exit_receipt_count": len(self._exit_receipts),
                                           "registered_count": len(self._handles)})
        close_rows: list[dict[str, Any]] = []
        # Registry owns its adopted duplicates and performs close-on-success;
        # lifecycle reads its strict receipt. Failed entries stay in registry.
        try:
            registry_receipt = self._registry.close_owned()
        except Exception as exc:
            registry_receipt = {"complete": False, "error": repr(exc)}
        if not isinstance(registry_receipt, Mapping) or registry_receipt.get("complete") is not True:
            self._cleanup_errors.append({"purpose": "registry_close_owned", "receipt": dict(registry_receipt)
                                         if isinstance(registry_receipt, Mapping) else repr(registry_receipt)})
        else:
            self._registry_close_complete = True
            for value in self._handles.values():
                if value.registry_owned:
                    value.closed = True
        for wrapper in (self._root_thread_owned, self._root_process_owned, self._job_owned_handle,
                        *self._temporary_handles):
            if wrapper is None:
                continue
            was_closed = wrapper.closed
            self._cleanup_handle(wrapper)
            close_rows.append({"purpose": wrapper.purpose, "handle": wrapper.raw,
                               "closed": wrapper.closed, "previously_closed": was_closed,
                               "error": wrapper.close_error})
        metadata_reader = getattr(self._api, "metadata_cleanup_receipt", None)
        metadata_receipt = (metadata_reader() if callable(metadata_reader) else
                            {"complete": getattr(self._api, "metadata_cleanup_complete", True) is True})
        if not isinstance(metadata_receipt, Mapping) or metadata_receipt.get("complete") is not True:
            self._cleanup_errors.append({"purpose": "native_metadata_handle_cleanup",
                "receipt": dict(metadata_receipt) if isinstance(metadata_receipt, Mapping) else repr(metadata_receipt)})
        else:
            close_rows.append({"purpose": "native_metadata_file_handles", "complete": True,
                               "receipt": dict(metadata_receipt)})
        metadata_complete = getattr(self._api, "metadata_cleanup_complete", True) is True
        self._closed = (self._registry_close_complete and metadata_complete and
                        all(item is None or item.closed for item in
                            (self._root_thread_owned, self._root_process_owned, self._job_owned_handle)) and
                        all(item.closed for item in self._temporary_handles) and
                        all(item.closed for item in self._handles.values()) and
                        not self._pending_debug_file_handles)
        try:
            self._record({"event": "cleanup", "registry_complete": self._registry_close_complete,
                          "close_rows": close_rows, "cleanup_errors": list(self._cleanup_errors),
                          "cleanup_complete": self._closed})
            self._cleanup_receipt_recorded = True
        except Exception as exc:
            self._cleanup_errors.append({"purpose": "cleanup_receipt", "type": type(exc).__name__,
                                         "repr": repr(exc)})
        return self.summary()

    def summary(self) -> Mapping[str, Any]:
        return {
            "schema": LIFECYCLE_SCHEMA,
            "root_pid": self._create.pid if self._create else None,
            "root_identity": _identity_value(self._root_identity) if self._root_identity else None,
            "session_id": self._managed.session_id,
            "scope_sha256": self._managed.scope_sha256,
            "event_count": self._event_sequence,
            "registration_count": self._registration_sequence,
            "registered_identities": [_identity_value(x) for x in sorted(self._handles)],
            "identity_complete": self.identity_complete,
            "exit_proof_complete": self.exit_proof_complete,
            "resource_sampling_complete": False,
            "cleanup_complete": self.cleanup_complete,
            "native_metadata_cleanup": (dict(self._api.metadata_cleanup_receipt())
                if callable(getattr(self._api, "metadata_cleanup_receipt", None)) else
                {"complete": getattr(self._api, "metadata_cleanup_complete", True) is True}),
            "returncode": self._returncode,
            "exit_receipts": [
                {"identity": _identity_value(item.identity), "debug_event_pid": item.debug_event_pid,
                 "debug_event_exit_code": item.debug_event_exit_code,
                 "duplicate_handle_wait_result": item.duplicate_handle_wait_result,
                 "retained_handle_exit_code": item.retained_handle_exit_code,
                 "exit_proof_complete": item.exit_proof_complete,
                 "resource_measurement_complete": item.resource_measurement_complete}
                for item in self._exit_receipts],
            "pending_boundary_events": [item.event.code for item in self._pending_boundary_events],
            "pending_debug_file_handles": [dict(item) for item in self._pending_debug_file_handles],
            "loaded_module_witnesses": {
                f"{identity.pid}_{identity.creation_time_100ns}":
                    [dict(witness) for _, witness in sorted(modules.items())]
                for identity, modules in self._loaded_module_witnesses.items()},
            "module_lineage_errors": {
                f"{identity.pid}_{identity.creation_time_100ns}": [dict(item) for item in items]
                for identity, items in self._module_lineage_errors.items()},
            "cleanup_errors": list(self._cleanup_errors),
            "event_receipts": list(self._event_receipts),
            "scientific_credit": False,
        }


__all__ = [
    "ACK_SCHEMA", "ACK_PUBLICATION_SCHEMA", "RESOURCE_MEASUREMENT_SCHEMA", "LifecycleError",
    "BirthPending", "SampleBoundaryChanged", "CleanupIncomplete", "ProcessIdentity", "DebugEvent",
    "CreateProcessResult", "BirthSourceWitness", "AckPublication", "RegistrationAck", "BirthRecord",
    "ProcessExitReceipt", "SampleAttemptBoundary", "ManagedEnvironment", "LifecycleObserver",
    "ExactBirthRegistry", "Win32Api", "WindowsDebugLifecycle", "LifecycleSession", "publish_ack_exclusive",
]
