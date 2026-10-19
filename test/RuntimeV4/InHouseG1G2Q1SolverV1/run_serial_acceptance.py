"""Bounded one-Julia-process gate followed by independent SciPy replay.

The Julia process runs alone. Python oracle work starts only after Julia has
exited successfully and its process tree is confirmed empty. On Windows a Job
Object enforces an aggregate 2 GiB commit ceiling and kills descendants when
the supervisor closes or terminates the job; psutil samples and records the
root/descendant working-set total against the same 2 GiB gate.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import math
import os
import platform
import queue
import shutil
import subprocess
import sys
import threading
import time
from ctypes import wintypes
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable

import psutil


RSS_LIMIT_BYTES = 2 * 1024 * 1024 * 1024
TOTAL_WALL_TIMEOUT_SECONDS = 240
JULIA_TIMEOUT_SECONDS = 240
PYTHON_TIMEOUT_SECONDS = 120
POLL_SECONDS = 0.25
MAX_RESOURCE_OBSERVATION_SPAN_NS = 500_000_000
JULIA_HEAP_HINT = "1G"
JULIA_COMPILE_MODE = "min"
PROCESS_SNAPSHOT_MAX_ATTEMPTS = 3
PROCESS_SAMPLE_CLOSE_MAX_ATTEMPTS = 2
MAX_JOB_PROCESS_IDS = 4096
AUDIT_WRITE_QUEUE_CAPACITY = 64
EXPECTED_INHOUSE_SOURCE_SHA256 = (
    "BD8E60FF527C42723B2B38C28494761D33C30D9E2FB200C464FADA926A4351BF"
)
_PENDING_NATIVE_PROCESS_CLEANUP = []
_PENDING_PROCESS_SAMPLE_CLEANUP = []


class _FileTime(ctypes.Structure):
    _fields_ = [("dwLowDateTime", wintypes.DWORD),
                ("dwHighDateTime", wintypes.DWORD)]


class _SecurityAttributes(ctypes.Structure):
    _fields_ = [("nLength", wintypes.DWORD),
                ("lpSecurityDescriptor", wintypes.LPVOID),
                ("bInheritHandle", wintypes.BOOL)]


class _StartupInfo(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("lpReserved", wintypes.LPWSTR),
        ("lpDesktop", wintypes.LPWSTR),
        ("lpTitle", wintypes.LPWSTR),
        ("dwX", wintypes.DWORD), ("dwY", wintypes.DWORD),
        ("dwXSize", wintypes.DWORD), ("dwYSize", wintypes.DWORD),
        ("dwXCountChars", wintypes.DWORD), ("dwYCountChars", wintypes.DWORD),
        ("dwFillAttribute", wintypes.DWORD), ("dwFlags", wintypes.DWORD),
        ("wShowWindow", wintypes.WORD), ("cbReserved2", wintypes.WORD),
        ("lpReserved2", ctypes.POINTER(wintypes.BYTE)),
        ("hStdInput", wintypes.HANDLE),
        ("hStdOutput", wintypes.HANDLE),
        ("hStdError", wintypes.HANDLE),
    ]


class _ProcessInformation(ctypes.Structure):
    _fields_ = [("hProcess", wintypes.HANDLE),
                ("hThread", wintypes.HANDLE),
                ("dwProcessId", wintypes.DWORD),
                ("dwThreadId", wintypes.DWORD)]


class _IoCounters(ctypes.Structure):
    _fields_ = [
        ("ReadOperationCount", ctypes.c_ulonglong),
        ("WriteOperationCount", ctypes.c_ulonglong),
        ("OtherOperationCount", ctypes.c_ulonglong),
        ("ReadTransferCount", ctypes.c_ulonglong),
        ("WriteTransferCount", ctypes.c_ulonglong),
        ("OtherTransferCount", ctypes.c_ulonglong),
    ]


class _BasicLimitInformation(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_longlong),
        ("PerJobUserTimeLimit", ctypes.c_longlong),
        ("LimitFlags", wintypes.DWORD),
        ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t),
        ("ActiveProcessLimit", wintypes.DWORD),
        ("Affinity", ctypes.c_size_t),
        ("PriorityClass", wintypes.DWORD),
        ("SchedulingClass", wintypes.DWORD),
    ]


class _ExtendedLimitInformation(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", _BasicLimitInformation),
        ("IoInfo", _IoCounters),
        ("ProcessMemoryLimit", ctypes.c_size_t),
        ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t),
        ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


class _BasicAccountingInformation(ctypes.Structure):
    _fields_ = [
        ("TotalUserTime", ctypes.c_longlong),
        ("TotalKernelTime", ctypes.c_longlong),
        ("ThisPeriodTotalUserTime", ctypes.c_longlong),
        ("ThisPeriodTotalKernelTime", ctypes.c_longlong),
        ("TotalPageFaultCount", wintypes.DWORD),
        ("TotalProcesses", wintypes.DWORD),
        ("ActiveProcesses", wintypes.DWORD),
        ("TotalTerminatedProcesses", wintypes.DWORD),
    ]


class _BasicProcessIdListHeader(ctypes.Structure):
    _fields_ = [
        ("NumberOfAssignedProcesses", wintypes.DWORD),
        ("NumberOfProcessIdsInList", wintypes.DWORD),
    ]


class _ProcessMemoryCounters(ctypes.Structure):
    _fields_ = [
        ("cb", wintypes.DWORD),
        ("PageFaultCount", wintypes.DWORD),
        ("PeakWorkingSetSize", ctypes.c_size_t),
        ("WorkingSetSize", ctypes.c_size_t),
        ("QuotaPeakPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPagedPoolUsage", ctypes.c_size_t),
        ("QuotaPeakNonPagedPoolUsage", ctypes.c_size_t),
        ("QuotaNonPagedPoolUsage", ctypes.c_size_t),
        ("PagefileUsage", ctypes.c_size_t),
        ("PeakPagefileUsage", ctypes.c_size_t),
    ]


@dataclass(frozen=True)
class JobPidInventory:
    complete: bool
    pids: tuple[int, ...]
    assigned_count: int
    returned_count: int
    reason: str | None = None


@dataclass
class ProcessSample:
    pid: int
    creation_time_utc: float
    rss_bytes: int
    signaled: bool = False
    signal_check: Callable[[], bool] | None = None
    close_handle: Callable[[], None] | None = None

    def is_signaled(self) -> bool:
        return bool(self.signal_check()) if self.signal_check is not None else self.signaled

    def close(self) -> None:
        callback = self.close_handle
        if callback is not None:
            callback()
            self.close_handle = None


class ProcessGenerationExited(psutil.NoSuchProcess):
    """A retained process handle proved this exact PID generation exited."""

    def __init__(self, pid: int, creation_time_utc: float) -> None:
        super().__init__(pid, msg="retained process-generation handle is signaled")
        self.creation_time_utc = float(creation_time_utc)
        self.signaled = True


class JobListedPidVanishedBeforeOpen(psutil.NoSuchProcess):
    """A Job-listed PID vanished before OpenProcess retained its generation."""


class ProcessGenerationMismatch(RuntimeError):
    def __init__(self, pid: int, expected_creation_time_utc,
                 observed_creation_time_utc, reason: str) -> None:
        self.pid = int(pid)
        self.expected_creation_time_utc = expected_creation_time_utc
        self.observed_creation_time_utc = observed_creation_time_utc
        self.reason = str(reason)
        super().__init__(
            f"process generation mismatch for PID {pid}: {self.reason}; "
            f"expected={expected_creation_time_utc}, "
            f"observed={observed_creation_time_utc}")


class WindowsNativeProcess:
    """CREATE_SUSPENDED child retaining its original process/thread handles."""

    CREATE_SUSPENDED = 0x00000004
    CREATE_NEW_PROCESS_GROUP = 0x00000200
    CREATE_NO_WINDOW = 0x08000000
    STARTF_USESTDHANDLES = 0x00000100
    HANDLE_FLAG_INHERIT = 0x00000001
    WAIT_OBJECT_0 = 0x00000000
    WAIT_TIMEOUT = 0x00000102
    WAIT_FAILED = 0xFFFFFFFF
    WAIT_INFINITE = 0xFFFFFFFF
    STILL_ACTIVE = 259
    FILETIME_EPOCH_DELTA = 11644473600
    FILETIME_TICKS_PER_SECOND = 10_000_000

    def __init__(self, argv: list[str], cwd: Path, stdout_file,
                 stderr_file, *, kernel32=None) -> None:
        if os.name != "nt":
            raise RuntimeError("native suspended process launch requires Windows")
        import msvcrt

        self._kernel32 = (kernel32 if kernel32 is not None else
                          ctypes.WinDLL("kernel32", use_last_error=True))
        self._configure_api()
        self.process_handle = None
        self.thread_handle = None
        self.pid = 0
        self.creation_time_utc = 0.0
        self.creation_time_monotonic_ns: int | None = None
        stdout_handle = wintypes.HANDLE(msvcrt.get_osfhandle(stdout_file.fileno()))
        stderr_handle = wintypes.HANDLE(msvcrt.get_osfhandle(stderr_file.fileno()))
        stdin_handle = None
        stdout_inheritable = False
        stderr_inheritable = False
        try:
            stdin_handle = self._open_inheritable_null()
            self._set_inheritable(stdout_handle, True)
            stdout_inheritable = True
            self._set_inheritable(stderr_handle, True)
            stderr_inheritable = True
            startup = _StartupInfo()
            startup.cb = ctypes.sizeof(startup)
            startup.dwFlags = self.STARTF_USESTDHANDLES
            startup.hStdInput = stdin_handle
            startup.hStdOutput = stdout_handle
            startup.hStdError = stderr_handle
            info = _ProcessInformation()
            command_line = ctypes.create_unicode_buffer(
                subprocess.list2cmdline(argv))
            flags = (self.CREATE_SUSPENDED | self.CREATE_NEW_PROCESS_GROUP
                     | self.CREATE_NO_WINDOW)
            # Use a conservative lower bound immediately before CreateProcessW;
            # process identity itself remains the exact UTC FILETIME value.
            self.creation_time_monotonic_ns = time.monotonic_ns()
            created = self._kernel32.CreateProcessW(
                argv[0], command_line, None, None, True, flags, None, str(cwd),
                ctypes.byref(startup), ctypes.byref(info))
            if not created:
                self._raise_last_error("CreateProcessW")
            self.process_handle = info.hProcess
            self.thread_handle = info.hThread
            self.pid = int(info.dwProcessId)
            self.priority_class = int(self._kernel32.GetPriorityClass(self.process_handle))
            if self.priority_class == 0:
                self._raise_last_error("GetPriorityClass(suspended child)")
            self.creation_time_utc = self._get_creation_time()
        except BaseException:
            try:
                self._terminate_and_close_handles()
            except BaseException:
                self._retain_for_cleanup()
                raise
            raise
        finally:
            cleanup_error = None
            if stdout_inheritable:
                try:
                    self._set_inheritable(stdout_handle, False)
                except OSError as error:
                    cleanup_error = error
            if stderr_inheritable:
                try:
                    self._set_inheritable(stderr_handle, False)
                except OSError as error:
                    cleanup_error = cleanup_error or error
            if stdin_handle:
                self._kernel32.CloseHandle(stdin_handle)
            if cleanup_error is not None:
                self._terminate_and_close_handles()
                raise cleanup_error

    def _configure_api(self) -> None:
        kernel = self._kernel32
        kernel.CreateProcessW.argtypes = (
            wintypes.LPCWSTR, wintypes.LPWSTR, wintypes.LPVOID,
            wintypes.LPVOID, wintypes.BOOL, wintypes.DWORD,
            wintypes.LPVOID, wintypes.LPCWSTR,
            ctypes.POINTER(_StartupInfo), ctypes.POINTER(_ProcessInformation),
        )
        kernel.CreateProcessW.restype = wintypes.BOOL
        kernel.CreateFileW.argtypes = (
            wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
            ctypes.POINTER(_SecurityAttributes), wintypes.DWORD,
            wintypes.DWORD, wintypes.HANDLE,
        )
        kernel.CreateFileW.restype = wintypes.HANDLE
        kernel.SetHandleInformation.argtypes = (
            wintypes.HANDLE, wintypes.DWORD, wintypes.DWORD,
        )
        kernel.SetHandleInformation.restype = wintypes.BOOL
        kernel.GetProcessTimes.argtypes = (
            wintypes.HANDLE, ctypes.POINTER(_FileTime), ctypes.POINTER(_FileTime),
            ctypes.POINTER(_FileTime), ctypes.POINTER(_FileTime),
        )
        kernel.GetProcessTimes.restype = wintypes.BOOL
        kernel.GetPriorityClass.argtypes = (wintypes.HANDLE,)
        kernel.GetPriorityClass.restype = wintypes.DWORD
        kernel.ResumeThread.argtypes = (wintypes.HANDLE,)
        kernel.ResumeThread.restype = wintypes.DWORD
        kernel.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.GetExitCodeProcess.argtypes = (
            wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD),
        )
        kernel.GetExitCodeProcess.restype = wintypes.BOOL
        kernel.TerminateProcess.argtypes = (wintypes.HANDLE, wintypes.UINT)
        kernel.TerminateProcess.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        kernel.CloseHandle.restype = wintypes.BOOL

    def _open_inheritable_null(self):
        security = _SecurityAttributes()
        security.nLength = ctypes.sizeof(security)
        security.bInheritHandle = True
        handle = self._kernel32.CreateFileW(
            "NUL", 0x80000000, 0x00000001 | 0x00000002,
            ctypes.byref(security), 3, 0x00000080, None)
        if not handle or handle == wintypes.HANDLE(-1).value:
            self._raise_last_error("CreateFileW(NUL)")
        return handle

    def _set_inheritable(self, handle, inheritable: bool) -> None:
        flags = self.HANDLE_FLAG_INHERIT if inheritable else 0
        if not self._kernel32.SetHandleInformation(
            handle, self.HANDLE_FLAG_INHERIT, flags
        ):
            self._raise_last_error("SetHandleInformation")

    def _get_creation_time(self) -> float:
        created = _FileTime()
        exited = _FileTime()
        kernel = _FileTime()
        user = _FileTime()
        if not self._kernel32.GetProcessTimes(
            self.process_handle, ctypes.byref(created), ctypes.byref(exited),
            ctypes.byref(kernel), ctypes.byref(user),
        ):
            self._raise_last_error("GetProcessTimes")
        ticks = (int(created.dwHighDateTime) << 32) | int(created.dwLowDateTime)
        return ticks / self.FILETIME_TICKS_PER_SECOND - self.FILETIME_EPOCH_DELTA

    def resume_primary_thread(self) -> None:
        if not self.thread_handle:
            raise RuntimeError("original suspended thread handle is unavailable")
        previous_suspend_count = int(self._kernel32.ResumeThread(self.thread_handle))
        if previous_suspend_count == self.WAIT_FAILED:
            self._raise_last_error("ResumeThread(original hThread)")
        if previous_suspend_count != 1:
            raise RuntimeError(
                f"unexpected primary thread suspend count {previous_suspend_count}")
        if not self._kernel32.CloseHandle(self.thread_handle):
            self._retain_for_cleanup()
            self._raise_last_error("CloseHandle(original hThread)")
        self.thread_handle = None

    def poll(self) -> int | None:
        if not self.process_handle:
            return None
        status = int(self._kernel32.WaitForSingleObject(self.process_handle, 0))
        if status == self.WAIT_TIMEOUT:
            return None
        if status != self.WAIT_OBJECT_0:
            self._raise_last_error("WaitForSingleObject(process)")
        code = wintypes.DWORD()
        if not self._kernel32.GetExitCodeProcess(
            self.process_handle, ctypes.byref(code)
        ):
            self._raise_last_error("GetExitCodeProcess")
        return int(code.value)

    def wait(self, timeout: float) -> int:
        milliseconds = min(max(int(timeout * 1000), 0), 0xFFFFFFFE)
        status = int(self._kernel32.WaitForSingleObject(
            self.process_handle, milliseconds))
        if status == self.WAIT_TIMEOUT:
            raise TimeoutError("timed out waiting for supervised process")
        if status != self.WAIT_OBJECT_0:
            self._raise_last_error("WaitForSingleObject(process)")
        result = self.poll()
        if result is None:
            raise RuntimeError("signaled process still reports active")
        return result

    def kill(self) -> None:
        if self.poll() is not None:
            return
        if not self._kernel32.TerminateProcess(self.process_handle, 94):
            if self.poll() is None:
                self._raise_last_error("TerminateProcess(original hProcess)")

    def close(self) -> None:
        self._terminate_and_close_handles()

    def _retain_for_cleanup(self) -> None:
        if self not in _PENDING_NATIVE_PROCESS_CLEANUP:
            _PENDING_NATIVE_PROCESS_CLEANUP.append(self)

    def _forget_cleanup(self) -> None:
        try:
            _PENDING_NATIVE_PROCESS_CLEANUP.remove(self)
        except ValueError:
            pass

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        self.close()

    def _terminate_and_close_handles(self) -> None:
        if self.process_handle:
            if self.poll() is None:
                terminated = self._kernel32.TerminateProcess(
                    self.process_handle, 94)
                if not terminated and self.poll() is None:
                    self._retain_for_cleanup()
                    self._raise_last_error(
                        "TerminateProcess(original hProcess)")
                waited = int(self._kernel32.WaitForSingleObject(
                    self.process_handle, self.WAIT_INFINITE))
                if waited != self.WAIT_OBJECT_0:
                    self._retain_for_cleanup()
                    raise RuntimeError(
                        "original process handle did not confirm termination")
            if not self._kernel32.CloseHandle(self.process_handle):
                self._retain_for_cleanup()
                self._raise_last_error("CloseHandle(original hProcess)")
            self.process_handle = None
        if self.thread_handle:
            if not self._kernel32.CloseHandle(self.thread_handle):
                self._retain_for_cleanup()
                self._raise_last_error("CloseHandle(original hThread)")
            self.thread_handle = None
        self._forget_cleanup()

    @staticmethod
    def _raise_last_error(name: str) -> None:
        error = ctypes.get_last_error()
        raise OSError(error, f"{name} failed")


class WindowsJob:
    """Aggregate commit guard and descendant lifetime for the Julia run."""

    JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9
    JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION = 1
    JOB_OBJECT_BASIC_PROCESS_ID_LIST = 3
    JOB_OBJECT_LIMIT_JOB_MEMORY = 0x00000200
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
    ERROR_ACCESS_DENIED = 5
    ERROR_INSUFFICIENT_BUFFER = 122
    ERROR_MORE_DATA = 234

    def __init__(self, memory_limit: int) -> None:
        if os.name != "nt":
            raise RuntimeError("the acceptance supervisor requires Windows")
        self._kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self._configure_api()
        self.handle = self._kernel32.CreateJobObjectW(None, None)
        self._check_handle(self.handle, "CreateJobObjectW")
        limits = _ExtendedLimitInformation()
        limits.BasicLimitInformation.LimitFlags = (
            self.JOB_OBJECT_LIMIT_JOB_MEMORY
            | self.JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        )
        limits.JobMemoryLimit = memory_limit
        if not self._kernel32.SetInformationJobObject(
            self.handle,
            self.JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
            ctypes.byref(limits),
            ctypes.sizeof(limits),
        ):
            self.close()
            self._raise_last_error("SetInformationJobObject")

    def _configure_api(self) -> None:
        kernel = self._kernel32
        kernel.CreateJobObjectW.argtypes = (wintypes.LPVOID, wintypes.LPCWSTR)
        kernel.CreateJobObjectW.restype = wintypes.HANDLE
        kernel.SetInformationJobObject.argtypes = (
            wintypes.HANDLE, wintypes.INT, wintypes.LPVOID, wintypes.DWORD,
        )
        kernel.SetInformationJobObject.restype = wintypes.BOOL
        kernel.AssignProcessToJobObject.argtypes = (wintypes.HANDLE, wintypes.HANDLE)
        kernel.AssignProcessToJobObject.restype = wintypes.BOOL
        kernel.TerminateJobObject.argtypes = (wintypes.HANDLE, wintypes.UINT)
        kernel.TerminateJobObject.restype = wintypes.BOOL
        kernel.QueryInformationJobObject.argtypes = (
            wintypes.HANDLE, wintypes.INT, wintypes.LPVOID,
            wintypes.DWORD, ctypes.POINTER(wintypes.DWORD),
        )
        kernel.QueryInformationJobObject.restype = wintypes.BOOL
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        kernel.CloseHandle.restype = wintypes.BOOL

    def assign(self, process: WindowsNativeProcess) -> None:
        if not self._kernel32.AssignProcessToJobObject(
            self.handle, process.process_handle
        ):
            self._raise_last_error("AssignProcessToJobObject")

    def active_processes(self) -> int:
        info = _BasicAccountingInformation()
        if not self._kernel32.QueryInformationJobObject(
            self.handle,
            self.JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION,
            ctypes.byref(info), ctypes.sizeof(info), None,
        ):
            self._raise_last_error("QueryInformationJobObject(accounting)")
        return int(info.ActiveProcesses)

    def active_pid_inventory(self) -> JobPidInventory:
        """Return a complete Job PID list or an explicit incomplete result."""
        try:
            initial_count = self.active_processes()
        except OSError:
            raise
        if initial_count > MAX_JOB_PROCESS_IDS:
            return JobPidInventory(False, (), initial_count, 0,
                                   "job_process_limit_exceeded")
        capacity = max(1, initial_count)
        header_size = ctypes.sizeof(_BasicProcessIdListHeader)
        pid_size = ctypes.sizeof(ctypes.c_size_t)
        for _ in range(16):
            if capacity > MAX_JOB_PROCESS_IDS:
                return JobPidInventory(False, (), capacity, 0,
                                       "job_process_limit_exceeded")
            raw = ctypes.create_string_buffer(header_size + capacity * pid_size)
            returned_length = wintypes.DWORD(0)
            succeeded = self._kernel32.QueryInformationJobObject(
                self.handle,
                self.JOB_OBJECT_BASIC_PROCESS_ID_LIST,
                raw,
                ctypes.sizeof(raw),
                ctypes.byref(returned_length),
            )
            header = ctypes.cast(
                raw, ctypes.POINTER(_BasicProcessIdListHeader)).contents
            assigned = int(header.NumberOfAssignedProcesses)
            returned = int(header.NumberOfProcessIdsInList)
            if assigned > MAX_JOB_PROCESS_IDS:
                return JobPidInventory(False, (), assigned, returned,
                                       "job_process_limit_exceeded")
            if not succeeded:
                error = ctypes.get_last_error()
                if error == self.ERROR_ACCESS_DENIED:
                    raise psutil.AccessDenied(pid=None)
                if error not in (self.ERROR_MORE_DATA,
                                 self.ERROR_INSUFFICIENT_BUFFER):
                    raise OSError(error, "QueryInformationJobObject(PID list) failed")
            if returned < assigned or not succeeded:
                next_capacity = max(assigned, capacity * 2)
                if next_capacity <= capacity:
                    next_capacity = capacity + 1
                capacity = next_capacity
                continue
            if returned > capacity:
                return JobPidInventory(False, (), assigned, returned,
                                       "job_pid_list_count_exceeds_buffer")
            pid_array = ctypes.cast(
                ctypes.addressof(raw) + header_size,
                ctypes.POINTER(ctypes.c_size_t),
            )
            pids = tuple(int(pid_array[index]) for index in range(returned))
            if (len(pids) != assigned or len(set(pids)) != len(pids)
                    or any(pid <= 0 for pid in pids)):
                return JobPidInventory(False, pids, assigned, returned,
                                       "job_pid_list_malformed")
            final_count = self.active_processes()
            if final_count != assigned:
                return JobPidInventory(False, pids, assigned, returned,
                                       "job_active_count_unstable")
            return JobPidInventory(True, tuple(sorted(pids)), assigned,
                                   returned, None)
        return JobPidInventory(False, (), capacity, 0,
                               "job_pid_inventory_buffer_retry_exhausted")

    def peak_job_commit_bytes(self) -> int:
        info = _ExtendedLimitInformation()
        if not self._kernel32.QueryInformationJobObject(
            self.handle,
            self.JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
            ctypes.byref(info), ctypes.sizeof(info), None,
        ):
            self._raise_last_error("QueryInformationJobObject(extended)")
        return int(info.PeakJobMemoryUsed)

    def terminate(self, exit_code: int) -> None:
        if self.handle and not self._kernel32.TerminateJobObject(
            self.handle, exit_code
        ):
            error = ctypes.get_last_error()
            raise OSError(error, "TerminateJobObject failed")

    def close(self) -> None:
        handle = getattr(self, "handle", None)
        if handle:
            self._kernel32.CloseHandle(handle)
            self.handle = None

    @staticmethod
    def _check_handle(handle, name: str) -> None:
        if not handle:
            WindowsJob._raise_last_error(name)

    @staticmethod
    def _raise_last_error(name: str) -> None:
        error = ctypes.get_last_error()
        raise OSError(error, f"{name} failed")


class _WindowsProcessSampleHandle:
    """Retain one exact process generation while reading its working set."""

    PROCESS_QUERY_INFORMATION = 0x00000400
    PROCESS_VM_READ = 0x00000010
    PROCESS_SYNCHRONIZE = 0x00100000
    WAIT_OBJECT_0 = 0x00000000
    WAIT_TIMEOUT = 0x00000102
    ERROR_ACCESS_DENIED = 5
    ERROR_INVALID_PARAMETER = 87
    FILETIME_EPOCH_DELTA = 11644473600
    FILETIME_TICKS_PER_SECOND = 10_000_000

    def __init__(self, pid: int, job: WindowsJob,
                 root_process: WindowsNativeProcess) -> None:
        if os.name != "nt":
            raise RuntimeError("process snapshot handles require Windows")
        self.pid = int(pid)
        self.owns_handle = pid != root_process.pid
        self.handle = None
        self.close_attempts = 0
        self.pending_close_error = None
        self._kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        self._configure_kernel_api()
        self._psapi = ctypes.WinDLL("psapi", use_last_error=True)
        self._psapi.GetProcessMemoryInfo.argtypes = (
            wintypes.HANDLE, ctypes.POINTER(_ProcessMemoryCounters),
            wintypes.DWORD,
        )
        self._psapi.GetProcessMemoryInfo.restype = wintypes.BOOL
        if self.owns_handle:
            self.handle = self._kernel32.OpenProcess(
                self.PROCESS_QUERY_INFORMATION | self.PROCESS_VM_READ
                | self.PROCESS_SYNCHRONIZE,
                False, self.pid,
            )
            if not self.handle:
                error = ctypes.get_last_error()
                if error == self.ERROR_INVALID_PARAMETER:
                    raise JobListedPidVanishedBeforeOpen(self.pid)
                self._raise_process_error(error, "OpenProcess")
        else:
            self.handle = root_process.process_handle
        try:
            self._creation_time_utc = self._get_creation_time()
            in_job = wintypes.BOOL()
            if not self._kernel32.IsProcessInJob(
                self.handle, job.handle, ctypes.byref(in_job)
            ):
                self._raise_process_error(ctypes.get_last_error(),
                                         "IsProcessInJob")
            if not in_job.value:
                raise ProcessGenerationMismatch(
                    self.pid, None, self._creation_time_utc,
                    "PID inventory entry resolved to a process outside the Job")
        except BaseException:
            self.close()
            raise

    def _configure_kernel_api(self) -> None:
        kernel = self._kernel32
        kernel.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL,
                                       wintypes.DWORD)
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.GetProcessTimes.argtypes = (
            wintypes.HANDLE, ctypes.POINTER(_FileTime),
            ctypes.POINTER(_FileTime), ctypes.POINTER(_FileTime),
            ctypes.POINTER(_FileTime),
        )
        kernel.GetProcessTimes.restype = wintypes.BOOL
        kernel.IsProcessInJob.argtypes = (
            wintypes.HANDLE, wintypes.HANDLE, ctypes.POINTER(wintypes.BOOL),
        )
        kernel.IsProcessInJob.restype = wintypes.BOOL
        kernel.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD)
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.CloseHandle.argtypes = (wintypes.HANDLE,)
        kernel.CloseHandle.restype = wintypes.BOOL

    def _raise_process_error(self, error: int, operation: str) -> None:
        if error == self.ERROR_ACCESS_DENIED:
            raise psutil.AccessDenied(pid=self.pid)
        if error == self.ERROR_INVALID_PARAMETER:
            raise psutil.NoSuchProcess(self.pid, msg=f"{operation}: PID vanished")
        raise OSError(error, f"{operation} failed for PID {self.pid}")

    def _get_creation_time(self) -> float:
        created = _FileTime()
        exited = _FileTime()
        kernel = _FileTime()
        user = _FileTime()
        if not self._kernel32.GetProcessTimes(
            self.handle, ctypes.byref(created), ctypes.byref(exited),
            ctypes.byref(kernel), ctypes.byref(user),
        ):
            self._raise_process_error(ctypes.get_last_error(), "GetProcessTimes")
        ticks = (int(created.dwHighDateTime) << 32) | int(created.dwLowDateTime)
        return ticks / self.FILETIME_TICKS_PER_SECOND - self.FILETIME_EPOCH_DELTA

    def is_signaled(self) -> bool:
        status = int(self._kernel32.WaitForSingleObject(self.handle, 0))
        if status == self.WAIT_OBJECT_0:
            return True
        if status == self.WAIT_TIMEOUT:
            return False
        error = ctypes.get_last_error()
        if error == self.ERROR_ACCESS_DENIED:
            raise psutil.AccessDenied(pid=self.pid)
        raise OSError(error, f"WaitForSingleObject failed for PID {self.pid}")

    def sample(self) -> ProcessSample:
        if self.is_signaled():
            raise ProcessGenerationExited(self.pid, self._creation_time_utc)
        counters = _ProcessMemoryCounters()
        counters.cb = ctypes.sizeof(counters)
        if not self._psapi.GetProcessMemoryInfo(
            self.handle, ctypes.byref(counters), ctypes.sizeof(counters)
        ):
            error = ctypes.get_last_error()
            if self.is_signaled():
                raise ProcessGenerationExited(self.pid, self._creation_time_utc)
            self._raise_process_error(error, "GetProcessMemoryInfo")
        return ProcessSample(
            pid=self.pid,
            creation_time_utc=self._creation_time_utc,
            rss_bytes=int(counters.WorkingSetSize),
            signal_check=self.is_signaled,
            close_handle=self.close,
        )

    def close(self) -> None:
        if not self.owns_handle or self.handle is None:
            return
        while self.close_attempts < PROCESS_SAMPLE_CLOSE_MAX_ATTEMPTS:
            self.close_attempts += 1
            if self._kernel32.CloseHandle(self.handle):
                self.handle = None
                self.pending_close_error = None
                try:
                    _PENDING_PROCESS_SAMPLE_CLEANUP.remove(self)
                except ValueError:
                    pass
                return
            self.pending_close_error = ctypes.get_last_error()
        if self not in _PENDING_PROCESS_SAMPLE_CLEANUP:
            _PENDING_PROCESS_SAMPLE_CLEANUP.append(self)
        error = self.pending_close_error
        raise OSError(error,
                      f"CloseHandle remained unconfirmed for PID {self.pid} "
                      f"after {self.close_attempts} attempts")


def _read_windows_process_sample(pid: int, job: WindowsJob,
                                 root_process: WindowsNativeProcess) -> ProcessSample:
    handle = _WindowsProcessSampleHandle(pid, job, root_process)
    try:
        return handle.sample()
    except BaseException:
        handle.close()
        raise


def _pending_process_sample_handle_receipt() -> list[dict]:
    return [{
        "pid": int(handle.pid),
        "close_attempts": int(handle.close_attempts),
        "handle_retained": handle.handle is not None,
        "last_close_error": handle.pending_close_error,
    } for handle in _PENDING_PROCESS_SAMPLE_CLEANUP]


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def _sha256(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _input_pins(test_dir: Path, repo_root: Path) -> dict[str, str | None]:
    paths = {
        "focused_tests.jl": test_dir / "focused_tests.jl",
        "focused_fixture.jl": test_dir / "focused_fixture.jl",
        "run_serial_acceptance.py": Path(__file__).resolve(),
        "independent_q1_oracle.py": test_dir / "independent_q1_oracle.py",
        "test_independent_q1_oracle.py": test_dir / "test_independent_q1_oracle.py",
        "test_serial_supervisor_static.py": (
            test_dir / "test_serial_supervisor_static.py"),
        "compare_independent_raw.py": test_dir / "compare_independent_raw.py",
        "Project.toml": repo_root / "Project.toml",
        "Manifest.toml": repo_root / "Manifest.toml",
        "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json": (
            repo_root / "docs" / "implementation" / "AD-45"
            / "FRESH-CANDIDATE-BINDING-ENVELOPE"
            / "fresh_candidate_binding_envelope_v1.json"),
        "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl": (
            repo_root / "test" / "GenomeV5" / "Integration"
            / "VNextT2ConcreteSourceWitnessV3" / "fixture_helpers.jl"),
    }
    for path in sorted((repo_root / "src").rglob("*.jl")):
        paths[path.relative_to(repo_root).as_posix()] = path
    return {name: _sha256(path) for name, path in sorted(paths.items())}


def _verify_input_pins(test_dir: Path, repo_root: Path, expected: dict,
                       receipt: dict, phase: str) -> None:
    current = _input_pins(test_dir, repo_root)
    changed = sorted(name for name, digest in expected.items()
                     if current.get(name) != digest)
    missing = sorted(name for name, digest in current.items() if digest is None)
    solver_hash = current.get("src/RuntimeV4/InHouseG1G2Q1SolverV1.jl")
    solver_match = solver_hash == EXPECTED_INHOUSE_SOURCE_SHA256.lower()
    receipt.setdefault("pin_checks", []).append({
        "phase": phase,
        "inputs_match_initial": not changed and not missing,
        "solver_matches_frozen_sha256": solver_match,
        "changed_inputs": changed,
        "missing_inputs": missing,
        "solver_source_sha256": solver_hash,
    })
    if changed or missing or not solver_match:
        reason = f"{phase}_input_pin_mismatch"
        receipt["stop_reason"] = reason
        raise RuntimeError(
            f"{reason}: changed={changed}, missing={missing}, "
            f"solver_source_sha256={solver_hash}")


def _check_total_deadline(deadline_monotonic: float, receipt: dict,
                          phase: str) -> None:
    checked_at = time.monotonic()
    if checked_at >= deadline_monotonic:
        receipt["stop_reason"] = "total_wall_timeout"
        receipt["deadline_check_phase"] = phase
        receipt["deadline_check_monotonic"] = checked_at
        raise TimeoutError(
            f"shared Julia plus SciPy deadline expired during {phase}")
    receipt["deadline_check_phase"] = phase
    receipt["deadline_check_monotonic"] = checked_at
    receipt["deadline_remaining_seconds"] = deadline_monotonic - checked_at


def _require_no_pending_process_sample_handles(receipt: dict,
                                              phase: str) -> None:
    pending = _pending_process_sample_handle_receipt()
    receipt["pending_process_sample_handles"] = pending
    if pending:
        receipt["pending_process_sample_cleanup_phase"] = phase
        receipt["stop_reason"] = "process_sample_handle_close_unconfirmed"
        raise RuntimeError(
            "one or more exact process handles remain unclosed after bounded retries")


def _process_tree(root_pid: int,
                  expected_creation_time_utc: float) -> list[psutil.Process]:
    root = psutil.Process(root_pid)
    if not math.isclose(root.create_time(), expected_creation_time_utc,
                        rel_tol=0.0, abs_tol=0.01):
        raise psutil.NoSuchProcess(root_pid, msg="root process generation changed")
    return [root, *root.children(recursive=True)]


def _sample_process_tree(root_pid: int,
                         expected_creation_time_utc: float) -> dict:
    rows = []
    rss_total = 0
    complete = True
    try:
        processes = _process_tree(root_pid, expected_creation_time_utc)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        return {"sampled_at_utc": _utc_now(), "complete": False,
                "rss_total_bytes": None,
                "root_generation_utc": expected_creation_time_utc,
                "processes": [{"pid": root_pid, "rss_bytes": None,
                               "sample_error": "root missing or access denied"}]}
    for process in processes:
        try:
            info = process.as_dict(attrs=("pid", "ppid", "name", "exe",
                                          "create_time"))
            rss = process.memory_info().rss
            rss_total += rss
            rows.append({**info, "rss_bytes": rss})
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            complete = False
            rows.append({"pid": process.pid, "rss_bytes": None,
                         "sample_error": "process exited or access denied"})
    return {"sampled_at_utc": _utc_now(),
            "root_generation_utc": expected_creation_time_utc,
            "complete": complete,
            "rss_total_bytes": rss_total if complete else None,
            "processes": rows}


def _sample_job_snapshot(inventory_reader: Callable[[], JobPidInventory],
                         process_reader: Callable[[int], ProcessSample],
                         expected_root: tuple[int, float] | None = None,
                         max_attempts: int = PROCESS_SNAPSHOT_MAX_ATTEMPTS,
                         generation_bindings: dict[int, float] | None = None
                         ) -> dict:
    """Sample one stable, complete Job membership snapshot or fail closed.

    Each attempt is all-or-nothing: partial RSS is never returned. A process
    disappearance is retryable only when its retained exact-generation handle
    is signaled and a new complete Job inventory proves the PID is absent.
    """
    if max_attempts < 1:
        return {
            "sampled_at_utc": _utc_now(), "complete": False,
            "rss_total_bytes": None, "processes": [], "job_pids": None,
            "retry_count": 0, "attempts": 0,
            "reason": "invalid_retry_limit", "error_class": "ValueError",
            "pending_sample_handle_count": len(
                _PENDING_PROCESS_SAMPLE_CLEANUP),
        }
    expected = generation_bindings if generation_bindings is not None else {}
    trace = []

    def incomplete(attempt: int, retries: int, reason: str,
                   error_class: str | None = None, *,
                   start_pids=None, end_pids=None) -> dict:
        return {
            "sampled_at_utc": _utc_now(), "complete": False,
            "rss_total_bytes": None, "processes": [], "job_pids": None,
            "retry_count": retries, "attempts": attempt,
            "reason": reason, "error_class": error_class,
            "attempt_trace": trace,
            "start_job_pids": start_pids, "end_job_pids": end_pids,
            "pending_sample_handle_count": len(
                _PENDING_PROCESS_SAMPLE_CLEANUP),
        }

    def read_inventory(label: str):
        try:
            item = inventory_reader()
        except psutil.AccessDenied as error:
            return None, "job_inventory_access_denied", type(error).__name__
        except psutil.NoSuchProcess as error:
            return None, "job_inventory_process_disappeared", type(error).__name__
        except BaseException as error:
            return None, f"job_inventory_{label}_failed", type(error).__name__
        if not isinstance(item, JobPidInventory):
            return None, "job_inventory_invalid_result", type(item).__name__
        pids = item.pids
        if not item.complete:
            return None, item.reason or "job_pid_inventory_incomplete", "JobPidInventory"
        if (not isinstance(pids, tuple)
                or type(item.assigned_count) is not int
                or type(item.returned_count) is not int
                or item.assigned_count < 0 or item.returned_count < 0
                or item.assigned_count != item.returned_count
                or item.returned_count != len(pids)
                or any(type(pid) is not int or pid <= 0 for pid in pids)
                or len(set(pids)) != len(pids)
                ):
            return None, "job_pid_inventory_malformed", "JobPidInventory"
        return tuple(sorted(pids)), None, None

    def validate_generation(pid: int, generation: float):
        if type(generation) not in (int, float):
            return "process_generation_nonfinite"
        try:
            generation = float(generation)
        except (OverflowError, TypeError, ValueError):
            return "process_generation_nonfinite"
        if not math.isfinite(generation):
            return "process_generation_nonfinite"
        if expected_root is not None and pid == expected_root[0]:
            if not math.isclose(generation, expected_root[1],
                                rel_tol=0.0, abs_tol=0.01):
                return "root_process_generation_mismatch"
        prior = expected.get(pid)
        if prior is not None and not math.isclose(
                generation, prior, rel_tol=0.0, abs_tol=0.01):
            return "process_generation_reused"
        return None

    retries = 0
    for attempt in range(1, max_attempts + 1):
        samples: list[ProcessSample] = []

        def close_samples() -> str | None:
            close_error = None
            for sample in samples:
                try:
                    sample.close()
                except BaseException as error:
                    close_error = close_error or type(error).__name__
            return close_error

        start_pids, reason, error_class = read_inventory("start")
        if reason is not None:
            return incomplete(attempt, retries, reason, error_class)
        rows: list[dict] = []
        retry_reason = None
        retry_class = None
        retry_evidence = None
        failure_reason = None
        failure_class = None

        for pid in start_pids:
            try:
                sample = process_reader(pid)
            except ProcessGenerationExited as error:
                if (error.pid != pid or error.signaled is not True
                        or not math.isfinite(error.creation_time_utc)):
                    failure_reason = "unproven_process_generation_exit"
                    failure_class = type(error).__name__
                    break
                generation_problem = validate_generation(
                    pid, error.creation_time_utc)
                if generation_problem is not None:
                    failure_reason = generation_problem
                    failure_class = type(error).__name__
                    break
                fresh_pids, fresh_reason, fresh_class = read_inventory(
                    "exit_confirmation")
                if fresh_reason is not None:
                    failure_reason = fresh_reason
                    failure_class = fresh_class
                    break
                if pid in fresh_pids:
                    failure_reason = "signaled_pid_still_in_job_or_reused"
                    failure_class = type(error).__name__
                    break
                retry_reason = "proven_process_generation_exit"
                retry_class = type(error).__name__
                break
            except JobListedPidVanishedBeforeOpen as error:
                if error.pid != pid:
                    failure_reason = "process_open_race_pid_mismatch"
                    failure_class = type(error).__name__
                    break
                if expected_root is None:
                    failure_reason = (
                        "openprocess_race_root_binding_missing")
                    failure_class = "ExpectedRootBinding"
                    break
                confirmed_pids, confirm_reason, confirm_class = read_inventory(
                    "openprocess_race_confirmation")
                if confirm_reason is not None:
                    failure_reason = confirm_reason
                    failure_class = confirm_class
                    break
                root_pid_present = expected_root[0] in confirmed_pids
                if not root_pid_present:
                    failure_reason = (
                        "job_root_missing_during_openprocess_race_confirmation")
                    failure_class = "JobPidInventory"
                    break
                if pid in confirmed_pids:
                    failure_reason = (
                        "job_listed_pid_still_present_after_openprocess_race")
                    failure_class = type(error).__name__
                    break
                retry_reason = "job_inventory_refreshed_after_openprocess_race"
                retry_class = type(error).__name__
                retry_evidence = {
                    "kind": "complete_job_inventory_refresh",
                    "root_member_present": root_pid_present,
                    "vanished_member_absent": True,
                }
                break
            except psutil.AccessDenied as error:
                failure_reason = "process_sample_access_denied"
                failure_class = type(error).__name__
                break
            except psutil.NoSuchProcess as error:
                failure_reason = "unproven_process_disappearance"
                failure_class = type(error).__name__
                break
            except ProcessGenerationMismatch as error:
                failure_reason = "process_generation_mismatch"
                failure_class = type(error).__name__
                break
            except BaseException as error:
                failure_reason = "process_sample_failed"
                failure_class = type(error).__name__
                break

            if not isinstance(sample, ProcessSample):
                failure_reason = "invalid_process_sample"
                failure_class = type(sample).__name__
                break
            samples.append(sample)
            if sample.pid != pid:
                failure_reason = "process_sample_pid_mismatch"
                failure_class = "ProcessSample"
                break
            generation_problem = validate_generation(
                pid, sample.creation_time_utc)
            if generation_problem is not None:
                failure_reason = generation_problem
                failure_class = "ProcessSample"
                break
            if (type(sample.rss_bytes) is not int
                    or sample.rss_bytes < 0):
                failure_reason = "invalid_process_rss"
                failure_class = "ProcessSample"
                break
            rows.append({"pid": pid,
                         "creation_time_utc": sample.creation_time_utc,
                         "rss_bytes": sample.rss_bytes})

        if failure_reason is not None:
            close_error = close_samples()
            if close_error is not None:
                failure_reason = "process_sample_handle_close_failed"
                failure_class = close_error
            trace.append({"attempt": attempt, "outcome": "failed",
                          "reason": failure_reason})
            return incomplete(attempt, retries, failure_reason, failure_class,
                              start_pids=start_pids)

        if retry_reason is not None:
            close_error = close_samples()
            if close_error is not None:
                trace.append({"attempt": attempt, "outcome": "failed",
                              "reason": "process_sample_handle_close_failed"})
                return incomplete(attempt, retries,
                                  "process_sample_handle_close_failed",
                                  close_error, start_pids=start_pids)
            retry_trace = {"attempt": attempt, "outcome": "retry",
                           "reason": retry_reason}
            if retry_evidence is not None:
                retry_trace["evidence"] = retry_evidence
            trace.append(retry_trace)
            retries += 1
            if attempt == max_attempts:
                return incomplete(attempt, retries,
                                  "process_snapshot_retry_exhausted",
                                  retry_class, start_pids=start_pids)
            continue

        end_pids, reason, error_class = read_inventory("end")
        if reason is not None:
            close_error = close_samples()
            if close_error is not None:
                reason = "process_sample_handle_close_failed"
                error_class = close_error
            trace.append({"attempt": attempt, "outcome": "failed",
                          "reason": reason})
            return incomplete(attempt, retries, reason, error_class,
                              start_pids=start_pids)

        signaled_samples = []
        for sample in samples:
            try:
                if sample.is_signaled():
                    signaled_samples.append(sample)
            except psutil.AccessDenied as error:
                failure_reason = "process_signal_check_access_denied"
                failure_class = type(error).__name__
                break
            except psutil.NoSuchProcess as error:
                failure_reason = "unproven_process_disappearance"
                failure_class = type(error).__name__
                break
            except BaseException as error:
                failure_reason = "process_signal_check_failed"
                failure_class = type(error).__name__
                break

        if failure_reason is not None:
            close_error = close_samples()
            if close_error is not None:
                failure_reason = "process_sample_handle_close_failed"
                failure_class = close_error
            trace.append({"attempt": attempt, "outcome": "failed",
                          "reason": failure_reason})
            return incomplete(attempt, retries, failure_reason, failure_class,
                              start_pids=start_pids, end_pids=end_pids)

        if signaled_samples:
            fresh_pids, fresh_reason, fresh_class = read_inventory(
                "signal_confirmation")
            if fresh_reason is not None:
                close_error = close_samples()
                if close_error is not None:
                    fresh_reason = "process_sample_handle_close_failed"
                    fresh_class = close_error
                trace.append({"attempt": attempt, "outcome": "failed",
                              "reason": fresh_reason})
                return incomplete(attempt, retries, fresh_reason, fresh_class,
                                  start_pids=start_pids, end_pids=end_pids)
            still_present = sorted(
                sample.pid for sample in signaled_samples
                if sample.pid in fresh_pids)
            if still_present:
                close_error = close_samples()
                reason = ("process_sample_handle_close_failed" if close_error
                          else "signaled_pid_still_in_job_or_reused")
                trace.append({"attempt": attempt, "outcome": "failed",
                              "reason": reason})
                return incomplete(attempt, retries, reason,
                                  close_error or "ProcessSample",
                                  start_pids=start_pids, end_pids=end_pids)
            close_error = close_samples()
            if close_error is not None:
                trace.append({"attempt": attempt, "outcome": "failed",
                              "reason": "process_sample_handle_close_failed"})
                return incomplete(attempt, retries,
                                  "process_sample_handle_close_failed",
                                  close_error, start_pids=start_pids,
                                  end_pids=end_pids)
            trace.append({"attempt": attempt, "outcome": "retry",
                          "reason": "proven_process_generation_exit"})
            retries += 1
            if attempt == max_attempts:
                return incomplete(attempt, retries,
                                  "process_snapshot_retry_exhausted",
                                  "ProcessGenerationExited",
                                  start_pids=start_pids, end_pids=end_pids)
            continue

        if start_pids != end_pids:
            removed_pids = set(start_pids) - set(end_pids)
            reason = ("inventory_disappearance_without_signaled_generation"
                      if removed_pids else "job_membership_unstable")
            close_error = close_samples()
            if close_error is not None:
                reason = "process_sample_handle_close_failed"
                error_class = close_error
            trace.append({"attempt": attempt,
                          "outcome": "failed" if removed_pids else "retry",
                          "reason": reason})
            if removed_pids or attempt == max_attempts:
                return incomplete(attempt, retries, reason,
                                  error_class or "JobPidInventory",
                                  start_pids=start_pids, end_pids=end_pids)
            retries += 1
            continue

        close_error = close_samples()
        if close_error is not None:
            trace.append({"attempt": attempt, "outcome": "failed",
                          "reason": "process_sample_handle_close_failed"})
            return incomplete(attempt, retries,
                              "process_sample_handle_close_failed", close_error,
                              start_pids=start_pids, end_pids=end_pids)
        expected.update({row["pid"]: row["creation_time_utc"] for row in rows})
        trace.append({"attempt": attempt, "outcome": "stable",
                      "job_pids": list(start_pids)})
        return {
            "sampled_at_utc": _utc_now(), "complete": True,
            "rss_total_bytes": sum(row["rss_bytes"] for row in rows),
            "processes": rows, "job_pids": list(start_pids),
            "retry_count": retries, "attempts": attempt,
            "reason": None, "error_class": None,
            "attempt_trace": trace,
            "start_job_pids": list(start_pids),
            "end_job_pids": list(end_pids),
            "pending_sample_handle_count": len(
                _PENDING_PROCESS_SAMPLE_CLEANUP),
        }
    return incomplete(max_attempts, retries,
                      "process_snapshot_retry_exhausted", None)


def _write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


class _AuditWriterError(RuntimeError):
    def __init__(self, reason: str, detail: str):
        super().__init__(detail)
        self.reason = reason


def _write_audit_line(audit, line: str) -> None:
    written = audit.write(line)
    if written != len(line):
        raise OSError(f"short process-tree audit write: {written}/{len(line)}")
    audit.flush()


class _BoundedAuditWriter:
    """Append immutable JSONL rows off the resource-sampling thread."""

    def __init__(self, path: Path, capacity: int = AUDIT_WRITE_QUEUE_CAPACITY):
        self._file = path.open("a", encoding="utf-8")
        self._queue: queue.Queue[str] = queue.Queue(maxsize=capacity)
        self._lock = threading.Lock()
        self._error: tuple[str, str] | None = None
        self._submitted = 0
        self._written = 0
        self._finished = False
        self._close_requested = threading.Event()
        self._thread = threading.Thread(
            target=self._run, name="process-tree-audit-writer", daemon=True)
        try:
            self._thread.start()
        except BaseException:
            self._file.close()
            raise

    def _set_error(self, reason: str, error: BaseException) -> None:
        with self._lock:
            if self._error is None:
                self._error = (reason, f"{type(error).__name__}: {error}")

    @property
    def error(self) -> tuple[str, str] | None:
        with self._lock:
            return self._error

    def enqueue(self, line: str) -> None:
        if not isinstance(line, str):
            raise TypeError("audit writer accepts serialized strings only")
        with self._lock:
            if self._error is not None:
                reason, detail = self._error
                raise _AuditWriterError(reason, detail)
            try:
                self._queue.put_nowait(line)
            except queue.Full as error:
                self._error = (
                    "audit_writer_queue_full",
                    "bounded process-tree audit queue is full")
                raise _AuditWriterError(
                    "audit_writer_queue_full",
                    "bounded process-tree audit queue is full") from error
            self._submitted += 1

    def _run(self) -> None:
        try:
            while True:
                try:
                    item = self._queue.get(timeout=0.05)
                except queue.Empty:
                    if self._close_requested.is_set():
                        try:
                            self._file.flush()
                        except BaseException as error:
                            self._set_error("audit_writer_flush_failed", error)
                        try:
                            self._file.close()
                        except BaseException as error:
                            self._set_error("audit_writer_close_failed", error)
                        return
                    continue
                try:
                    with self._lock:
                        can_write = self._error is None
                    if can_write:
                        try:
                            _write_audit_line(self._file, item)
                            self._written += 1
                        except BaseException as error:
                            self._set_error("audit_writer_write_failed", error)
                finally:
                    self._queue.task_done()
        except BaseException as error:
            self._set_error("audit_writer_thread_failed", error)
            # Keep draining until finish() requests close, even after an
            # unexpected worker failure, so accepted queue tasks are accounted.
            while True:
                try:
                    item = self._queue.get(timeout=0.05)
                except queue.Empty:
                    if self._close_requested.is_set():
                        try:
                            self._file.close()
                        except BaseException as close_error:
                            self._set_error("audit_writer_close_failed", close_error)
                        return
                    continue
                try:
                    pass
                finally:
                    self._queue.task_done()

    def finish(self, timeout_seconds: float = 10.0) -> dict:
        if self._finished:
            return self.status()
        self._finished = True
        self._close_requested.set()
        self._thread.join(max(0.0, timeout_seconds))
        if self._thread.is_alive():
            self._set_error(
                "audit_writer_finish_timeout",
                TimeoutError("audit writer did not drain and flush before timeout"))
        return self.status()

    def status(self) -> dict:
        error = self.error
        return {
            "complete": (error is None and self._written == self._submitted
                         and not self._thread.is_alive()),
            "submitted_rows": self._submitted,
            "written_rows": self._written,
            "error": None if error is None else {
                "reason": error[0], "detail": error[1]},
        }


def _terminate_fallback(process: WindowsNativeProcess) -> None:
    """Terminate the exact process handle while it is still suspended."""
    if process.poll() is None:
        process.kill()
        try:
            process.wait(timeout=5.0)
        except TimeoutError:
            pass


def _run_in_job(argv: list[str], cwd: Path, stdout_path: Path,
                stderr_path: Path, audit_path: Path, job: WindowsJob,
                receipt: dict, stage: str, timeout_seconds: int,
                total_deadline_monotonic: float) -> int:
    phase_started = time.monotonic()
    if phase_started >= total_deadline_monotonic:
        receipt["stop_reason"] = "total_wall_timeout"
        raise TimeoutError("shared Julia plus SciPy wall deadline expired")
    stage_deadline = phase_started + timeout_seconds
    deadline = min(total_deadline_monotonic, stage_deadline)
    timeout_reason = ("total_wall_timeout"
                      if total_deadline_monotonic <= stage_deadline
                      else f"{stage}_timeout")
    if job.active_processes() != 0:
        receipt["stop_reason"] = f"{stage}_prior_process_tree_not_empty"
        job.terminate(97)
        raise RuntimeError("previous stage left an active Job process")
    if stage == "python_scipy":
        receipt["python_started_after_julia_tree_empty"] = True
    with stdout_path.open("wb") as out, stderr_path.open("wb") as err:
        # Open the JSONL file before creating/resuming the child. Only the
        # dedicated writer thread performs audit-file I/O during sampling.
        audit_writer = _BoundedAuditWriter(audit_path)
        try:
            process = WindowsNativeProcess(argv, cwd, out, err)
        except BaseException:
            writer_finish_timeout = max(
                0.0, min(10.0,
                         deadline - time.monotonic()))
            writer_status = audit_writer.finish(writer_finish_timeout)
            receipt[f"{stage}_audit_writer"] = writer_status
            receipt[f"{stage}_audit_writer_complete"] = writer_status["complete"]
            raise
        receipt[f"{stage}_process_id"] = process.pid
        receipt[f"{stage}_child_priority_class"] = process.priority_class
        receipt[f"{stage}_child_priority_class_name"] = (
            "NORMAL" if process.priority_class == 0x20 else f"OTHER_{process.priority_class}")
        receipt[f"{stage}_child_priority_class_observed_before_resume"] = True
        receipt[f"{stage}_process_creation_time_utc"] = (
            process.creation_time_utc)
        receipt[f"{stage}_process_creation_monotonic_ns"] = (
            process.creation_time_monotonic_ns)
        receipt[f"{stage}_process_exit_monotonic_ns"] = None
        try:
            try:
                if time.monotonic() >= deadline:
                    receipt["stop_reason"] = timeout_reason
                    raise TimeoutError(
                        "shared or stage wall deadline expired during process creation")
                job.assign(process)
            except BaseException:
                if process.poll() is None:
                    if job.active_processes() > 0:
                        job.terminate(95)
                    else:
                        _terminate_fallback(process)
                raise

            generation_bindings: dict[int, float] = {}
            previous_sample_started_monotonic_ns: int | None = None
            primary_thread_resumed = False
            pending_cycle_timing: dict[str, int] | None = None
            while True:
                writer_error = audit_writer.error
                if writer_error is not None:
                    receipt["stop_reason"] = writer_error[0]
                    receipt["audit_writer_error"] = {
                        "stage": stage, "reason": writer_error[0],
                        "detail": writer_error[1],
                    }
                    receipt["rss_accounting_incomplete"] = True
                    job.terminate(96)
                    break
                if time.monotonic() >= deadline:
                    receipt["stop_reason"] = timeout_reason
                    job.terminate(92)
                    break
                sample_started_monotonic_ns = time.monotonic_ns()
                sample = _sample_job_snapshot(
                    job.active_pid_inventory,
                    lambda pid: _read_windows_process_sample(pid, job, process),
                    expected_root=(process.pid, process.creation_time_utc),
                    generation_bindings=generation_bindings,
                )
                sample_finished_monotonic_ns = time.monotonic_ns()
                sample["sampled_at_monotonic_start_ns"] = (
                    sample_started_monotonic_ns)
                sample["sampled_at_monotonic_end_ns"] = (
                    sample_finished_monotonic_ns)
                sample["stage"] = stage
                if pending_cycle_timing is not None:
                    pending_cycle_timing["next_query_start_monotonic_ns"] = (
                        sample_started_monotonic_ns)
                    sample["previous_cycle_timing"] = pending_cycle_timing
                    pending_cycle_timing = None
                resource_coverage_gap = None
                if sample["complete"]:
                    coverage_start_ns = (
                        process.creation_time_monotonic_ns
                        if previous_sample_started_monotonic_ns is None
                        else previous_sample_started_monotonic_ns)
                    observation_span_ns = (
                        sample_finished_monotonic_ns - coverage_start_ns)
                    if observation_span_ns > MAX_RESOURCE_OBSERVATION_SPAN_NS:
                        resource_coverage_gap = {
                            "kind": (
                                "head"
                                if previous_sample_started_monotonic_ns is None
                                else "internal"
                            ),
                            "span_ns": observation_span_ns,
                            "span_seconds": observation_span_ns / 1_000_000_000,
                            "limit_ns": MAX_RESOURCE_OBSERVATION_SPAN_NS,
                            "from_monotonic_ns": coverage_start_ns,
                            "to_monotonic_ns": sample_finished_monotonic_ns,
                        }
                        sample["resource_coverage_gap"] = resource_coverage_gap
                        sample["rss_accounting_incomplete"] = True
                        receipt["resource_coverage_gap"] = {
                            "stage": stage, **resource_coverage_gap}
                        receipt["rss_accounting_incomplete"] = True
                receipt[f"{stage}_job_snapshot_attempts"] = (
                    receipt.get(f"{stage}_job_snapshot_attempts", 0)
                    + sample["attempts"])
                receipt[f"{stage}_job_snapshot_retries"] = (
                    receipt.get(f"{stage}_job_snapshot_retries", 0)
                    + sample["retry_count"])
                if not sample["complete"]:
                    sample["rss_accounting_incomplete"] = True
                    receipt["rss_accounting_incomplete"] = True
                    receipt["rss_snapshot_failure"] = {
                        "reason": sample["reason"],
                        "error_class": sample["error_class"],
                        "attempts": sample["attempts"],
                        "retry_count": sample["retry_count"],
                    }
                elif sample["rss_total_bytes"] is not None:
                    receipt["peak_sampled_tree_rss_bytes"] = max(
                        receipt["peak_sampled_tree_rss_bytes"],
                        sample["rss_total_bytes"])
                # The OS enforces JobMemoryLimit continuously and retains the
                # lifetime commit high-water mark after the Job becomes empty.
                # Query that retained peak below, outside the RSS sampling loop:
                # QueryInformationJobObject/file metadata can block long enough
                # to invalidate the unchanged 500 ms RSS observation contract.
                audit_append_start_monotonic_ns = time.monotonic_ns()
                # Serialize before enqueue so the writer owns an immutable row;
                # put_nowait keeps disk latency off this sampling thread.
                audit_line = json.dumps(sample, sort_keys=True) + "\n"
                try:
                    audit_writer.enqueue(audit_line)
                except _AuditWriterError as error:
                    audit_append_end_monotonic_ns = time.monotonic_ns()
                    pending_cycle_timing = {
                        "sample_query_start_monotonic_ns": sample_started_monotonic_ns,
                        "sample_query_end_monotonic_ns": sample_finished_monotonic_ns,
                        "audit_append_start_monotonic_ns": audit_append_start_monotonic_ns,
                        "audit_append_end_monotonic_ns": audit_append_end_monotonic_ns,
                        "audit_append_mode": "serialized_nonblocking_enqueue",
                    }
                    receipt["stop_reason"] = error.reason
                    receipt["audit_writer_error"] = {
                        "stage": stage, "reason": error.reason,
                        "detail": str(error),
                    }
                    receipt["rss_accounting_incomplete"] = True
                    job.terminate(96)
                    break
                audit_append_end_monotonic_ns = time.monotonic_ns()
                pending_cycle_timing = {
                    "sample_query_start_monotonic_ns": sample_started_monotonic_ns,
                    "sample_query_end_monotonic_ns": sample_finished_monotonic_ns,
                    "audit_append_start_monotonic_ns": audit_append_start_monotonic_ns,
                    "audit_append_end_monotonic_ns": audit_append_end_monotonic_ns,
                    "audit_append_mode": "serialized_nonblocking_enqueue",
                }
                if sample["complete"]:
                    previous_sample_started_monotonic_ns = (
                        sample_started_monotonic_ns)
                if resource_coverage_gap is not None:
                    receipt["stop_reason"] = "resource_coverage_gap"
                    job.terminate(94)
                    break
                if not sample["complete"]:
                    receipt["stop_reason"] = (
                        "process_sample_handle_close_unconfirmed"
                        if sample["reason"] ==
                        "process_sample_handle_close_failed"
                        else "process_tree_sample_incomplete")
                    job.terminate(96)
                    break
                if sample["rss_total_bytes"] >= RSS_LIMIT_BYTES:
                    receipt["stop_reason"] = "process_tree_rss_limit"
                    job.terminate(91)
                    break
                if not primary_thread_resumed:
                    if time.monotonic() >= deadline:
                        receipt["stop_reason"] = timeout_reason
                        job.terminate(92)
                        break
                    # Account for the assigned root before it starts executing.
                    try:
                        process.resume_primary_thread()
                        primary_thread_resumed = True
                    except BaseException:
                        if process.poll() is None:
                            if job.active_processes() > 0:
                                job.terminate(95)
                            else:
                                _terminate_fallback(process)
                        raise
                process_poll_start_monotonic_ns = time.monotonic_ns()
                root_exit_code = process.poll()
                process_poll_end_monotonic_ns = time.monotonic_ns()
                pending_cycle_timing["process_poll_start_monotonic_ns"] = (
                    process_poll_start_monotonic_ns)
                pending_cycle_timing["process_poll_end_monotonic_ns"] = (
                    process_poll_end_monotonic_ns)
                if root_exit_code is None:
                    if process.pid not in sample["job_pids"]:
                        receipt["stop_reason"] = (
                            "root_process_missing_from_job_inventory")
                        job.terminate(96)
                        break
                elif not sample["job_pids"]:
                    final_inventory = job.active_pid_inventory()
                    if (not final_inventory.complete
                            or final_inventory.pids
                            or final_inventory.assigned_count != 0
                            or final_inventory.returned_count != 0):
                        receipt["stop_reason"] = (
                            "job_final_empty_inventory_unconfirmed")
                        job.terminate(96)
                        break
                    break
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    receipt["stop_reason"] = timeout_reason
                    job.terminate(92)
                    break
                sleep_start_monotonic_ns = time.monotonic_ns()
                time.sleep(min(POLL_SECONDS, remaining))
                sleep_return_monotonic_ns = time.monotonic_ns()
                pending_cycle_timing["sleep_start_monotonic_ns"] = (
                    sleep_start_monotonic_ns)
                pending_cycle_timing["sleep_return_monotonic_ns"] = (
                    sleep_return_monotonic_ns)
            exit_code = process.wait(timeout=15.0)

            if (receipt["stop_reason"] is None
                    and time.monotonic() > deadline):
                receipt["stop_reason"] = timeout_reason

            cleanup_deadline = min(time.monotonic() + 10.0,
                                   total_deadline_monotonic)
            while (job.active_processes() > 0
                   and time.monotonic() < cleanup_deadline):
                time.sleep(min(0.1, cleanup_deadline - time.monotonic()))
            if job.active_processes() != 0:
                receipt["stop_reason"] = f"{stage}_descendant_survived"
                job.terminate(93)
                raise RuntimeError(
                    f"{stage} process tree remained active after root exit")
            # This is the confirmed empty-Job boundary, so descendants are
            # covered through their actual end as well as the root process.
            if receipt[f"{stage}_process_exit_monotonic_ns"] is None:
                receipt[f"{stage}_process_exit_monotonic_ns"] = (
                    time.monotonic_ns())
            peak_query_started_ns = time.monotonic_ns()
            commit_peak = job.peak_job_commit_bytes()
            receipt["peak_job_commit_bytes"] = max(
                receipt["peak_job_commit_bytes"], commit_peak)
            receipt[f"{stage}_commit_peak_observation"] = {
                "source": "OS_Job_lifetime_PeakJobMemoryUsed",
                "job_empty_confirmed": True,
                "start_monotonic_ns": peak_query_started_ns,
                "end_monotonic_ns": time.monotonic_ns(),
                "bytes": commit_peak,
            }
            if (receipt["stop_reason"] is None
                    and commit_peak >= RSS_LIMIT_BYTES):
                receipt["stop_reason"] = f"{stage}_job_commit_limit_or_exit"
            if (receipt["stop_reason"] is None
                    and time.monotonic() > deadline):
                receipt["stop_reason"] = timeout_reason
            return int(exit_code)
        finally:
            try:
                process.close()
            finally:
                writer_finish_timeout = max(
                    0.0, min(10.0,
                             deadline - time.monotonic()))
                writer_status = audit_writer.finish(writer_finish_timeout)
                receipt[f"{stage}_audit_writer"] = writer_status
                receipt[f"{stage}_audit_writer_complete"] = (
                    writer_status["complete"])
                if not writer_status["complete"]:
                    receipt["rss_accounting_incomplete"] = True
                    writer_error = writer_status["error"]
                    if writer_error is not None:
                        receipt["audit_writer_error"] = {
                            "stage": stage, **writer_error}
                    if receipt["stop_reason"] is None:
                        receipt["stop_reason"] = (
                            "audit_writer_incomplete")
                    if job.active_processes() > 0:
                        job.terminate(96)
                    if sys.exc_info()[0] is None:
                        raise RuntimeError(
                            f"{stage} audit writer did not flush all rows")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        raise SystemExit("NO_GO: Windows Job Object enforcement is unavailable")

    test_dir = Path(__file__).resolve().parent
    repo_root = test_dir.parents[2]
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=False)
    report_path = output_dir / "inhouse-report.json"
    audit_path = output_dir / "process-tree-audit.jsonl"
    julia_stdout = output_dir / "julia.stdout.log"
    julia_stderr = output_dir / "julia.stderr.log"
    python_stdout = output_dir / "python.stdout.log"
    python_stderr = output_dir / "python.stderr.log"
    configured_julia = os.environ.get("JULIA_EXE")
    julia_path = (Path(configured_julia).expanduser() if configured_julia
                  else Path(shutil.which("julia") or ""))
    julia_exe = julia_path.resolve() if julia_path.is_file() else None
    julia_argv = [] if julia_exe is None else [
        str(julia_exe), "--startup-file=no", "--threads=1",
        f"--compile={JULIA_COMPILE_MODE}",
        f"--heap-size-hint={JULIA_HEAP_HINT}", f"--project={repo_root}",
        str(test_dir / "focused_tests.jl"), "--json-out", str(report_path),
    ]
    initial_pins = _input_pins(test_dir, repo_root)
    receipt = {
        "schema": "inhouse-q1-serial-acceptance-run-v1",
        "started_at_utc": _utc_now(), "completed_at_utc": None,
        "working_directory": str(repo_root),
        "output_directory": str(output_dir),
        "julia_argv": julia_argv,
        "julia_compile_mode": JULIA_COMPILE_MODE,
        "julia_timeout_seconds": JULIA_TIMEOUT_SECONDS,
        "python_timeout_seconds": PYTHON_TIMEOUT_SECONDS,
        "total_wall_timeout_seconds": TOTAL_WALL_TIMEOUT_SECONDS,
        "total_wall_elapsed_seconds": None,
        "python_remaining_budget_seconds_at_start": None,
        "python_effective_timeout_seconds": None,
        "julia_heap_size_hint": JULIA_HEAP_HINT,
        "aggregate_job_commit_limit_bytes": RSS_LIMIT_BYTES,
        "process_tree_rss_limit_bytes": RSS_LIMIT_BYTES,
        "process_tree_sample_seconds": POLL_SECONDS,
        "julia_exit_code": None, "python_exit_code": None,
        "serial_order": ["julia_inhouse_three_grid", "python_scipy_raw_replay"],
        "python_started_after_julia_tree_empty": False,
        "peak_sampled_tree_rss_bytes": 0,
        "peak_job_commit_bytes": 0,
        "rss_accounting_incomplete": False,
        "stop_reason": None,
        "report_sha256": None,
        "input_sha256": initial_pins,
        "solver_source_sha256_expected": EXPECTED_INHOUSE_SOURCE_SHA256.lower(),
        "pin_checks": [],
        "julia_report_sha256_before_python": None,
        "julia_process_id": None,
        "julia_process_creation_time_utc": None,
        "python_scipy_process_id": None,
        "python_scipy_process_creation_time_utc": None,
    }
    job: WindowsJob | None = None
    total_started = None
    total_deadline = None
    try:
        if julia_exe is None:
            receipt["stop_reason"] = "julia_executable_not_found"
            raise RuntimeError(
                "julia executable is unavailable; set JULIA_EXE or install Julia")
        _verify_input_pins(test_dir, repo_root, initial_pins, receipt,
                           "pre_julia")
        total_started = time.monotonic()
        total_deadline = total_started + TOTAL_WALL_TIMEOUT_SECONDS
        job = WindowsJob(RSS_LIMIT_BYTES)
        receipt["julia_exit_code"] = _run_in_job(julia_argv, repo_root,
            julia_stdout, julia_stderr, audit_path, job, receipt,
            "julia", JULIA_TIMEOUT_SECONDS, total_deadline)
        _require_no_pending_process_sample_handles(receipt, "post_julia")
        if receipt["stop_reason"] is not None:
            raise RuntimeError(receipt["stop_reason"])
        if receipt["julia_exit_code"] != 0:
            receipt["stop_reason"] = "julia_nonzero_exit"
            raise RuntimeError("Julia focused acceptance did not exit successfully")
        _verify_input_pins(test_dir, repo_root, initial_pins, receipt,
                           "post_julia")
        if not report_path.is_file():
            receipt["stop_reason"] = "julia_report_missing"
            raise RuntimeError("Julia did not write its raw report")
        receipt["report_sha256"] = _sha256(report_path)
        receipt["julia_report_sha256_before_python"] = receipt["report_sha256"]
        python_remaining_budget = max(
            0.0, total_deadline - time.monotonic())
        receipt["python_remaining_budget_seconds_at_start"] = (
            python_remaining_budget)
        python_timeout = min(PYTHON_TIMEOUT_SECONDS,
                             python_remaining_budget)
        receipt["python_effective_timeout_seconds"] = python_timeout
        if python_timeout <= 0.0:
            receipt["stop_reason"] = "total_wall_timeout"
            raise TimeoutError(
                "shared Julia plus SciPy wall deadline expired before Python")
        python_argv = [sys.executable, "-B",
            str(test_dir / "compare_independent_raw.py"), str(report_path),
            "--backends", "inhouse"]
        receipt["python_argv"] = python_argv
        receipt["python_exit_code"] = _run_in_job(python_argv, test_dir,
            python_stdout, python_stderr, audit_path, job, receipt,
            "python_scipy", python_timeout, total_deadline)
        _require_no_pending_process_sample_handles(receipt, "post_python")
        if receipt["stop_reason"] is not None:
            raise RuntimeError(receipt["stop_reason"])
        _verify_input_pins(test_dir, repo_root, initial_pins, receipt,
                           "post_python")
        if _sha256(report_path) != receipt["julia_report_sha256_before_python"]:
            receipt["stop_reason"] = "julia_report_changed_during_python_replay"
            raise RuntimeError(receipt["stop_reason"])
        _require_no_pending_process_sample_handles(receipt, "postflight_before_go")
        _check_total_deadline(total_deadline, receipt,
                              "postflight_before_go")
        receipt["stop_reason"] = ("complete" if receipt["python_exit_code"] == 0
                                  else "scipy_oracle_no_go")
        print("SERIAL_ACCEPTANCE=" +
              ("GO" if receipt["python_exit_code"] == 0 else "NO_GO"))
        return int(receipt["python_exit_code"])
    except BaseException as error:
        if receipt["stop_reason"] is None:
            receipt["stop_reason"] = f"supervisor_exception:{type(error).__name__}"
        receipt["supervisor_error"] = str(error)
        print("SERIAL_ACCEPTANCE=NO_GO reason=" + receipt["stop_reason"],
              file=sys.stderr)
        return 2
    finally:
        if job is not None:
            try:
                if job.handle and job.active_processes() > 0:
                    job.terminate(94)
                if job.handle:
                    receipt["peak_job_commit_bytes"] = max(
                        receipt["peak_job_commit_bytes"],
                        job.peak_job_commit_bytes())
            except OSError:
                pass
            job.close()
        if total_started is not None:
            receipt["total_wall_elapsed_seconds"] = max(
                0.0, time.monotonic() - total_started)
        receipt["completed_at_utc"] = _utc_now()
        receipt["report_sha256"] = _sha256(report_path)
        receipt["pending_process_sample_handles"] = (
            _pending_process_sample_handle_receipt())
        _write_json(output_dir / "run-receipt.json", receipt)


if __name__ == "__main__":
    raise SystemExit(main())
