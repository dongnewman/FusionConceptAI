"""Run one repository check through the existing Windows Job executor.

This is a stable entrypoint, not another process supervisor implementation.
Each invocation writes a fresh, owned evidence leaf and retains actual exits,
raw output, resource observations, caller-supplied input identities, and cleanup disposition.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

import psutil


ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR = ROOT / "test/RuntimeV4/InHouseG1G2Q1SolverV1/run_serial_acceptance.py"
MEMORY_LIMIT = 2147483648
MAX_AUTHORIZED_MEMORY_LIMIT = 4294967296


def data_pin(path: Path) -> dict:
    raw = path.read_bytes()
    return {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def write_new(path: Path, value: dict) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")


def raise_observer_priority(receipt: dict) -> tuple[object, int, int, int, int, dict]:
    """Raise only this observer process/thread and retain exact prior values."""
    if os.name != "nt":
        raise RuntimeError("Windows observer priority is unavailable")
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.GetCurrentProcess.argtypes = []
    kernel32.GetCurrentProcess.restype = ctypes.c_void_p
    kernel32.GetCurrentThread.argtypes = []
    kernel32.GetCurrentThread.restype = ctypes.c_void_p
    kernel32.GetPriorityClass.argtypes = [ctypes.c_void_p]
    kernel32.GetPriorityClass.restype = ctypes.c_uint32
    kernel32.SetPriorityClass.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
    kernel32.SetPriorityClass.restype = ctypes.c_int
    kernel32.GetThreadPriority.argtypes = [ctypes.c_void_p]
    kernel32.GetThreadPriority.restype = ctypes.c_int
    kernel32.SetThreadPriority.argtypes = [ctypes.c_void_p, ctypes.c_int]
    kernel32.SetThreadPriority.restype = ctypes.c_int
    current_process = kernel32.GetCurrentProcess()
    current_thread = kernel32.GetCurrentThread()
    state = {
        "process_api": "SetPriorityClass", "process_requested": "HIGH",
        "process_requested_value": 0x80, "process_applied": False,
        "process_restored": None, "thread_api": "SetThreadPriority",
        "thread_requested": "HIGHEST", "thread_requested_value": 2,
        "thread_applied": False, "thread_restored": None,
        "restoration_errors": [],
    }
    receipt["observer_priority"] = state

    def read_process_class(scope: str) -> int:
        ctypes.set_last_error(0)
        value = int(kernel32.GetPriorityClass(current_process))
        if value == 0:
            error_code = ctypes.get_last_error()
            state[f"{scope}_get_error_winerror"] = error_code
            raise OSError(error_code, f"GetPriorityClass({scope}) failed")
        return value

    def read_thread_priority(scope: str) -> int:
        ctypes.set_last_error(0)
        value = int(kernel32.GetThreadPriority(current_thread))
        if value == 0x7FFFFFFF:
            error_code = ctypes.get_last_error()
            state[f"{scope}_get_error_winerror"] = error_code
            raise OSError(error_code, f"GetThreadPriority({scope}) failed")
        return value

    previous_class = read_process_class("observer_before")
    previous_thread = read_thread_priority("observer_before")
    state["previous_process_priority_class"] = previous_class
    state["previous_thread_priority"] = previous_thread
    token = (kernel32, current_process, previous_class, current_thread,
             previous_thread, state)
    try:
        ctypes.set_last_error(0)
        if not kernel32.SetPriorityClass(current_process, 0x80):
            error_code = ctypes.get_last_error()
            state["process_set_error_winerror"] = error_code
            raise OSError(error_code, "SetPriorityClass(HIGH) failed")
        state["process_applied"] = True
        actual_class = read_process_class("process_apply_readback")
        state["process_readback_priority_class"] = actual_class
        if actual_class != 0x80:
            raise RuntimeError(f"observer priority class readback {actual_class}, expected HIGH(128)")
        ctypes.set_last_error(0)
        if not kernel32.SetThreadPriority(current_thread, 2):
            error_code = ctypes.get_last_error()
            state["thread_set_error_winerror"] = error_code
            raise OSError(error_code, "SetThreadPriority(HIGHEST) failed")
        state["thread_applied"] = True
        actual_thread = read_thread_priority("thread_apply_readback")
        state["thread_readback_priority"] = actual_thread
        if actual_thread != 2:
            raise RuntimeError(f"observer thread priority readback {actual_thread}, expected HIGHEST(2)")
    except BaseException as apply_error:
        state["apply_error"] = repr(apply_error)
        try:
            restore_observer_priority(token, receipt)
        except BaseException as rollback_error:
            state["apply_rollback_error"] = repr(rollback_error)
        raise
    return token


def restore_observer_priority(
        token: tuple[object, int, int, int, int, dict], receipt: dict) -> None:
    kernel32, current_process, previous_class, current_thread, previous_thread, state = token
    errors = []
    ctypes.set_last_error(0)
    thread_set_ok = bool(kernel32.SetThreadPriority(current_thread, previous_thread))
    thread_set_error = 0 if thread_set_ok else ctypes.get_last_error()
    if not thread_set_ok:
        errors.append({"scope": "thread", "stage": "restore_set", "winerror": thread_set_error})
    ctypes.set_last_error(0)
    thread_readback = int(kernel32.GetThreadPriority(current_thread))
    if thread_readback == 0x7FFFFFFF:
        error_code = ctypes.get_last_error()
        state["thread_restore_get_error_winerror"] = error_code
        errors.append({"scope": "thread", "stage": "restore_get", "winerror": error_code})
        state["thread_restored"] = False
    else:
        state["thread_restore_readback"] = thread_readback
        state["thread_restored"] = thread_set_ok and thread_readback == previous_thread
        if thread_readback != previous_thread:
            errors.append({"scope": "thread", "stage": "restore_readback", "expected": previous_thread, "actual": thread_readback})

    ctypes.set_last_error(0)
    process_set_ok = bool(kernel32.SetPriorityClass(current_process, previous_class))
    process_set_error = 0 if process_set_ok else ctypes.get_last_error()
    if not process_set_ok:
        errors.append({"scope": "process", "stage": "restore_set", "winerror": process_set_error})
    ctypes.set_last_error(0)
    process_readback = int(kernel32.GetPriorityClass(current_process))
    if process_readback == 0:
        error_code = ctypes.get_last_error()
        state["process_restore_get_error_winerror"] = error_code
        errors.append({"scope": "process", "stage": "restore_get", "winerror": error_code})
        state["process_restored"] = False
    else:
        state["process_restore_readback"] = process_readback
        state["process_restored"] = process_set_ok and process_readback == previous_class
        if process_readback != previous_class:
            errors.append({"scope": "process", "stage": "restore_readback", "expected": previous_class, "actual": process_readback})
    state["restoration_errors"] = errors
    if errors:
        receipt["stop_reason"] = "observer_priority_restore_failed"
        raise OSError(f"observer process/thread priority restoration failed: {errors!r}")


def resource_audit_coverage(path: Path, created_monotonic_ns: int | None,
                            finished_monotonic_ns: int | None) -> dict:
    """Require monotonic coverage from process creation through empty Job."""
    try:
        rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]
        if (created_monotonic_ns is None or finished_monotonic_ns is None
                or not rows):
            raise ValueError("missing monotonic process boundary or resource samples")
        if (type(created_monotonic_ns) is not int
                or type(finished_monotonic_ns) is not int
                or created_monotonic_ns < 0
                or finished_monotonic_ns < created_monotonic_ns):
            raise ValueError("invalid monotonic process boundaries")
        starts: list[int] = []
        ends: list[int] = []
        for row in rows:
            start_ns = row["sampled_at_monotonic_start_ns"]
            end_ns = row["sampled_at_monotonic_end_ns"]
            if (type(start_ns) is not int or type(end_ns) is not int
                    or start_ns < 0 or end_ns < start_ns):
                raise ValueError("invalid monotonic sample operation interval")
            starts.append(start_ns)
            ends.append(end_ns)
        if (starts != sorted(starts)
                or starts[0] < created_monotonic_ns
                or ends[-1] > finished_monotonic_ns):
            raise ValueError("nonmonotonic samples or sample outside process boundaries")
        uncovered_gaps = [starts[index] - ends[index - 1]
                          for index in range(1, len(rows))]
        if any(gap < 0 for gap in uncovered_gaps):
            raise ValueError("sample operation intervals overlap or are out of order")
        # Bound complete-observation spacing, including the actual operation
        # durations at each endpoint. Resource reads are not treated as a
        # continuous observation throughout the operation.
        head = (ends[0] - created_monotonic_ns) / 1_000_000_000
        internal_spans = [
            (ends[index] - starts[index - 1]) / 1_000_000_000
            for index in range(1, len(rows))]
        internal = max(internal_spans, default=0.0)
        tail = (finished_monotonic_ns - starts[-1]) / 1_000_000_000
        max_sample_operation = max(
            (end - start) / 1_000_000_000
            for start, end in zip(starts, ends))
        # The supervisor samples every 0.25 s. Keep the existing 0.5 s
        # ceiling for head/internal/tail observation intervals.
        complete = (min(head, internal, tail) >= 0
                    and max(head, internal, tail, max_sample_operation) <= 0.5)
        return {"complete": complete, "samples": len(rows),
                "head_gap_seconds": head,
                "max_internal_gap_seconds": internal,
                "tail_gap_seconds": tail,
                "max_sample_operation_seconds": max_sample_operation,
                "clock": "monotonic_ns"}
    except (OSError, ValueError, KeyError, TypeError, OverflowError, json.JSONDecodeError) as error:
        return {"complete": False, "samples": 0, "error": repr(error),
                "clock": "monotonic_ns"}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--seconds", type=int, default=240)
    parser.add_argument("--memory-gib", type=int, choices=(2, 4), default=2)
    parser.add_argument("--pin", action="append", default=[], type=Path)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    memory_limit = args.memory_gib * 1024 * 1024 * 1024
    if memory_limit > MAX_AUTHORIZED_MEMORY_LIMIT:
        parser.error("memory limit exceeds the authorized 4 GiB ceiling")
    argv = args.command[1:] if args.command[:1] == ["--"] else args.command
    if os.name != "nt" or not argv or not 0 < args.seconds <= 5400:
        parser.error("requires Windows, an explicit command, and a wall limit in 1..5400 seconds")
    out = args.output_dir.resolve()
    out.relative_to(ROOT / "runs")
    if out.exists():
        raise FileExistsError(f"retain existing evidence: {out}")
    active = [process.pid for process in psutil.process_iter(["name"])
              if (process.info["name"] or "").lower() in
              ("julia.exe", "julia-debug.exe", "desc.exe", "freegs.exe", "gmsh.exe", "mesh.exe")]
    if active:
        raise RuntimeError(f"root's serial execution slot is occupied: {active}")
    # Hash only run inputs explicitly named by the caller. Runtime source is
    # maintained in place and is not an admission gate.
    input_paths = set()
    for supplied in args.pin:
        path = supplied.resolve(strict=True)
        path.relative_to(ROOT)
        input_paths.add(path)
    executable = Path(argv[0]).resolve(strict=True)
    executable_pin = data_pin(executable)
    before = {path.relative_to(ROOT).as_posix(): data_pin(path)
              for path in sorted(input_paths)}
    spec = importlib.util.spec_from_file_location("workspace_current_windows_job", SUPERVISOR)
    supervisor = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = supervisor
    spec.loader.exec_module(supervisor)
    if supervisor.RSS_LIMIT_BYTES != MEMORY_LIMIT or supervisor.POLL_SECONDS != .25:
        raise RuntimeError("current Windows Job executor resource policy changed")
    # The existing supervisor uses one limit for Job commit and sampled tree RSS.
    # Apply the per-run authorized cap while retaining the existing 0.25 s poll.
    supervisor.RSS_LIMIT_BYTES = memory_limit
    out.mkdir(parents=True, exist_ok=False)
    write_new(out / "input_pins_before.json", before)
    for name in ("JULIA_NUM_THREADS", "OPENBLAS_NUM_THREADS", "OMP_NUM_THREADS", "MKL_NUM_THREADS"):
        os.environ[name] = "1"
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    receipt = {
        "schema": "bounded-workspace-check-v1", "owner": "/root", "argv": argv,
        "outer_argv": psutil.Process().cmdline(), "cwd": str(ROOT),
        "executable": {"path": str(executable), **executable_pin},
        "wall_limit_seconds": args.seconds, "job_memory_limit_bytes": memory_limit,
        "process_tree_rss_limit_bytes": memory_limit, "sample_seconds": .25,
        "stop_reason": None, "rss_accounting_incomplete": False,
        "peak_sampled_tree_rss_bytes": 0, "peak_job_commit_bytes": 0,
        "observer_priority": None,
        "actual_child_os_exit_code": None, "formal_acceptance": False,
        "physical_validation": "not_assessed", "authority": "no_publish",
    }
    started = time.monotonic()
    job = supervisor.WindowsJob(memory_limit)
    try:
        priority_token = raise_observer_priority(receipt)
        try:
            receipt["actual_child_os_exit_code"] = supervisor._run_in_job(
                argv, ROOT, out / "stdout.raw", out / "stderr.raw",
                out / "process_tree_audit.jsonl", job, receipt, "check",
                args.seconds, started + args.seconds)
        finally:
            restore_observer_priority(priority_token, receipt)
        receipt["job_active_processes_after_run"] = job.active_processes()
        supervisor._require_no_pending_process_sample_handles(receipt, "workspace_post_check")
    except BaseException as error:
        receipt["exception"] = repr(error)
        if job.active_processes():
            job.terminate(94)
        receipt["job_active_processes_after_failure"] = job.active_processes()
    finally:
        job.close()
    coverage = resource_audit_coverage(
        out / "process_tree_audit.jsonl",
        receipt.get("check_process_creation_monotonic_ns"),
        receipt.get("check_process_exit_monotonic_ns"))
    receipt["resource_audit_coverage"] = coverage
    if not coverage["complete"]:
        receipt["rss_accounting_incomplete"] = True
    receipt["resource_gate_passed"] = bool(
        coverage["complete"] and not receipt["rss_accounting_incomplete"]
        and receipt["peak_sampled_tree_rss_bytes"] < memory_limit
        and receipt["peak_job_commit_bytes"] < memory_limit)
    receipt["child_exit_success"] = (
        receipt["actual_child_os_exit_code"] == 0)
    receipt["cleanup_complete"] = bool(
        receipt.get("job_active_processes_after_run") == 0
        and receipt.get("job_active_processes_after_failure", 0) == 0
        and not receipt.get("pending_process_sample_handles", []))
    after = {path.relative_to(ROOT).as_posix(): data_pin(path)
             for path in sorted(input_paths)}
    receipt["seconds"] = time.monotonic() - started
    receipt["input_pins_unchanged"] = after == before
    receipt["executable_pin_unchanged"] = data_pin(executable) == executable_pin
    receipt["passed_software_check"] = bool(
        receipt["child_exit_success"] and "exception" not in receipt
        and receipt["stop_reason"] is None and receipt["resource_gate_passed"]
        and receipt["cleanup_complete"] and receipt["input_pins_unchanged"]
        and receipt["executable_pin_unchanged"])
    write_new(out / "input_pins_after.json", after)
    receipt["raw_files"] = {path.name: data_pin(path) for path in out.iterdir() if path.is_file()}
    write_new(out / "receipt.json", receipt)
    print(json.dumps({key: receipt.get(key) for key in (
        "actual_child_os_exit_code", "stop_reason", "seconds", "peak_sampled_tree_rss_bytes",
        "peak_job_commit_bytes", "resource_gate_passed", "child_exit_success",
        "cleanup_complete", "input_pins_unchanged", "passed_software_check")}), flush=True)
    return 0 if receipt["passed_software_check"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
