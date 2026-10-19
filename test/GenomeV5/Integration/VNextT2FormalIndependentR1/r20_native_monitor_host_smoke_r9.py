from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import sys
import textwrap
import time
import types
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = Path(__file__).resolve().parent
CONTROLLER = TEST_ROOT / "independent_negative_controller_r20.py"
NATIVE_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
TEST_SUITE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r23_v1.py"
RUNNER = Path(__file__).resolve()
MAX_CANDIDATE_ATTEMPTS = 12


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.resolve().relative_to(ROOT).as_posix(),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def load_controller() -> types.ModuleType:
    source = CONTROLLER.read_bytes()
    module = types.ModuleType("r20_native_monitor_host_smoke_controller")
    module.__file__ = str(CONTROLLER)
    sys.dont_write_bytecode = True
    exec(compile(source, str(CONTROLLER), "exec"), module.__dict__)
    return module


def write_json(path: Path, value: Any) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8", newline="\n")


def source_pins() -> dict[str, dict[str, Any]]:
    return {"runner": file_receipt(RUNNER),
            "controller": file_receipt(CONTROLLER),
            "native_process_table": file_receipt(NATIVE_TABLE),
            "supervisor": file_receipt(SUPERVISOR),
            "test_suite_source": file_receipt(TEST_SUITE)}


def exact_launcher_argv() -> list[str]:
    return [sys.executable, "-B", str(RUNNER), *sys.argv[1:]]


def assert_true(value: bool, message: str) -> None:
    if not value:
        raise RuntimeError(message)


def run_openprocess_race_preprobe(module: types.ModuleType) -> dict[str, Any]:
    native = module._R23_TABLE
    flags = getattr(module.subprocess, "CREATE_NO_WINDOW", 0)
    child = module.psutil.Popen(
        [sys.executable, "-B", "-c", "import time; time.sleep(60)"],
        cwd=ROOT, stdin=module.subprocess.DEVNULL,
        stdout=module.subprocess.DEVNULL, stderr=module.subprocess.DEVNULL,
        creationflags=flags)
    identity = native.read_process_handle_identity(child._handle)
    before = native.validate_snapshot(native.query_native_process_table())
    row = before.by_pid.get(identity[0])
    assert_true(row is not None and
                (row.identity.pid, row.identity.create_time_100ns) == identity,
                "preprobe child was not present in its exact before-SPI snapshot")
    terminate_sent = child.poll() is None
    if terminate_sent:
        child.terminate()
    child_exit = child.wait(timeout=5.0)
    child._handle.Close()
    child._handle = None
    absence_snapshots = []
    deadline = time.monotonic() + 2.0
    while time.monotonic() < deadline:
        current = native.validate_snapshot(native.query_native_process_table())
        absence_snapshots.append(module._r23_snapshot_receipt(current))
        if identity[0] not in current.by_pid:
            break
        time.sleep(0.02)
    post = native.validate_snapshot(native.query_native_process_table())
    assert_true(identity[0] not in post.by_pid,
                "preprobe target PID remained in raw SPI after all test-side handles closed")

    open_result: dict[str, Any]
    try:
        handle = native.open_exact_process_handle(row)
    except Exception as error:
        open_result = {"outcome": "openprocess_failed_after_spi_absence",
                       "exception_type": type(error).__name__,
                       "message": str(error)}
    else:
        try:
            handle_identity = native.read_process_handle_identity(handle)
            signaled = native.wait_for_process_exit(handle, 0.001)
            assert_true(handle_identity == identity and signaled is True,
                        "preprobe OpenProcess did not yield the exact already-signaled generation")
            open_result = {"outcome": "opened_exact_already_signaled_generation",
                           "handle_identity": list(handle_identity),
                           "native_wait_signaled": True}
        finally:
            native.close_process_handle(handle)
    final_snapshot = native.validate_snapshot(native.query_native_process_table())
    assert_true(identity[0] not in final_snapshot.by_pid,
                "preprobe target reappeared or its PID was reused before the final check")
    return {
        "schema": "vnext-t2-r20-openprocess-exit-race-preprobe-r1",
        "complete": True,
        "identity_authority": "raw_PID_FILETIME_100ns_SPI_and_original_process_handle",
        "source_identity": {"pid": identity[0], "create_time_100ns": identity[1]},
        "before_snapshot": module._r23_snapshot_receipt(before),
        "terminate_sent": terminate_sent,
        "child_wait_exit_code": child_exit,
        "parent_popen_handle_closed": True,
        "post_exit_absence_snapshots": absence_snapshots,
        "post_exit_pid_absent_from_spi": True,
        "openprocess_result": open_result,
        "final_pid_absent_from_spi": True,
        "formal_t2_accepted": False,
    }


def smoke_child_command(*, phase_dir: Path, launch_orphan: bool,
                        root_seconds: float,
                        require_candidate_pid_after_baseline: bool = True,
                        wait_for_root_release: bool = False,
                        target_seconds: float = 60.0) -> list[str]:
    target_pid = phase_dir / "target_pid.txt"
    orphan_pid = phase_dir / "orphan_pid.txt"
    begin_baseline_file = phase_dir / "begin_baseline.txt"
    baseline_ready_file = phase_dir / "baseline_ready.txt"
    begin_target_file = phase_dir / "begin_target.txt"
    target_release_file = phase_dir / "target_release.txt"
    target_selection_file = phase_dir / "target_selection.json"
    candidate_attempt_prefix = phase_dir / "candidate_attempt_"
    candidate_ready_prefix = phase_dir / "candidate_ready_"
    candidate_decision_prefix = phase_dir / "candidate_decision_"
    candidate_closed_prefix = phase_dir / "candidate_closed_"
    candidate_absent_prefix = phase_dir / "candidate_absent_"
    candidate_detach_prefix = phase_dir / "candidate_detach_request_"
    baseline_detach_request_file = phase_dir / "baseline_detach_request.json"
    baseline_detached_file = phase_dir / "baseline_handle_detached.json"
    root_release_file = phase_dir / "root_release.txt"
    worker_code = textwrap.dedent(f"""
        import os, pathlib, subprocess, sys, time
        release = pathlib.Path(sys.argv[1])
        pathlib.Path(sys.argv[2]).write_text(str(os.getpid()), encoding='ascii')
        deadline = time.monotonic() + 10.0
        while not release.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        if not release.exists():
            raise SystemExit(95)
        orphan_pid = {str(orphan_pid)!r}
        if {launch_orphan!r}:
            flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
            child = subprocess.Popen(
                [sys.executable, '-B', '-c', 'import time; time.sleep(60)'],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, creationflags=flags)
            pathlib.Path(orphan_pid).write_text(str(child.pid), encoding='ascii')
        pathlib.Path({str(target_pid)!r}).write_text(
            str(os.getpid()), encoding='ascii')
        print('R20_TARGET_READY', os.getpid(), flush=True)
        time.sleep({float(target_seconds)!r})
    """).strip()
    baseline_code = textwrap.dedent(f"""
        import os, pathlib, time
        pathlib.Path({str(baseline_ready_file)!r}).write_text(
            str(os.getpid()), encoding='ascii')
        print('R20_BASELINE_READY', os.getpid(), flush=True)
        time.sleep(60)
    """).strip()
    root_code = textwrap.dedent(f"""
        import json, os, pathlib, subprocess, sys, time
        flags = getattr(subprocess, 'CREATE_NO_WINDOW', 0)
        max_attempts = {MAX_CANDIDATE_ATTEMPTS}
        require_pid_sort = {require_candidate_pid_after_baseline!r}
        def write_json_atomic(path, value):
            path = pathlib.Path(path)
            temporary = path.with_name(path.name + '.tmp')
            temporary.write_text(json.dumps(value, sort_keys=True), encoding='utf-8')
            os.replace(temporary, path)
        def detach_live_popen(process, identity, source_row, source_snapshot):
            if (not isinstance(identity, dict) or
                    identity.get('pid') != process.pid or
                    type(identity.get('create_time_100ns')) is not int or
                    not isinstance(source_row, dict) or
                    source_row.get('pid') != identity.get('pid') or
                    source_row.get('create_time_100ns') !=
                        identity.get('create_time_100ns') or
                    not isinstance(source_snapshot, dict) or
                    source_snapshot.get('complete') is not True or
                    getattr(process, '_child_created', None) is not True):
                raise SystemExit(104)
            poll_result = process.poll()
            if poll_result is not None or getattr(process, '_handle', None) is None:
                raise SystemExit(105)
            process._handle.Close()
            process._handle = None
            process._child_created = False
            return {{'identity': identity, 'source_row': source_row,
                    'source_snapshot': source_snapshot,
                    'process_poll_returncode': poll_result,
                    'original_popen_handle_closed': True,
                    'popen_wrapper_ownership_transferred': True,
                    'popen_child_created_before_transfer': True,
                    'popen_child_created_after_transfer': False,
                    'popen_wrapper_detached_after_exact_live_spi_binding': True,
                    'returncode_was_not_synthesized': True}}
        print('R20_ROOT_READY', os.getpid(), flush=True)
        begin_baseline = pathlib.Path({str(begin_baseline_file)!r})
        deadline = time.monotonic() + 12.0
        while not begin_baseline.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        if not begin_baseline.exists():
            raise SystemExit(91)
        baseline_code = {baseline_code!r}
        baseline = subprocess.Popen(
            [sys.executable, '-B', '-c', baseline_code],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL, creationflags=flags)
        deadline = time.monotonic() + 5.0
        while not pathlib.Path({str(baseline_ready_file)!r}).exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        if not pathlib.Path({str(baseline_ready_file)!r}).exists():
            raise SystemExit(92)
        deadline = time.monotonic() + 5.0
        while not pathlib.Path({str(baseline_detach_request_file)!r}).exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        if not pathlib.Path({str(baseline_detach_request_file)!r}).exists():
            raise SystemExit(106)
        baseline_detach_request = json.loads(pathlib.Path(
            {str(baseline_detach_request_file)!r}).read_text(encoding='utf-8'))
        baseline_detach = detach_live_popen(
            baseline, baseline_detach_request.get('identity', {{}}),
            baseline_detach_request.get('source_row', {{}}),
            baseline_detach_request.get('source_snapshot', {{}}))
        baseline_detach['schema'] = 'vnext-t2-r20-live-popen-detach-r1'
        baseline_detach['phase'] = 'completed_sample_two_baseline'
        write_json_atomic(pathlib.Path({str(baseline_detached_file)!r}), baseline_detach)
        begin_target = pathlib.Path({str(begin_target_file)!r})
        deadline = time.monotonic() + 5.0
        while not begin_target.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        if not begin_target.exists():
            raise SystemExit(93)
        baseline_pid = int(pathlib.Path({str(baseline_ready_file)!r}).read_text(
            encoding='ascii').strip())
        baseline_identity = None
        attempts = []
        accepted = False
        for attempt in range(1, max_attempts + 1):
            suffix = f'{{attempt:02d}}.json'
            attempt_path = pathlib.Path({str(candidate_attempt_prefix)!r} + suffix)
            ready_path = pathlib.Path({str(candidate_ready_prefix)!r} + suffix)
            decision_path = pathlib.Path({str(candidate_decision_prefix)!r} + suffix)
            closed_path = pathlib.Path({str(candidate_closed_prefix)!r} + suffix)
            detach_path = pathlib.Path({str(candidate_detach_prefix)!r} + suffix)
            absent_path = pathlib.Path({str(candidate_absent_prefix)!r} + suffix)
            worker = subprocess.Popen(
                [sys.executable, '-B', '-c', {worker_code!r},
                 {str(target_release_file)!r}, str(ready_path)],
                stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL, creationflags=flags)
            write_json_atomic(attempt_path, {{'attempt': attempt, 'pid': worker.pid}})
            try:
                deadline = time.monotonic() + 1.0
                while not ready_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                if not ready_path.exists() or int(ready_path.read_text(
                        encoding='ascii').strip()) != worker.pid:
                    raise SystemExit(94)
                deadline = time.monotonic() + 1.0
                while not decision_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                if not decision_path.exists():
                    raise SystemExit(95)
                decision = json.loads(decision_path.read_text(encoding='utf-8'))
                identity = decision.get('identity', {{}})
                observed_baseline = decision.get('baseline_identity', {{}})
                if decision.get('pid_ordering_required') is not require_pid_sort:
                    raise SystemExit(107)
                if (decision.get('attempt') != attempt or
                        identity.get('pid') != worker.pid or
                        type(identity.get('create_time_100ns')) is not int or
                        observed_baseline.get('pid') != baseline_pid or
                        type(observed_baseline.get('create_time_100ns')) is not int):
                    raise SystemExit(96)
                if baseline_identity is None:
                    baseline_identity = observed_baseline
                elif observed_baseline != baseline_identity:
                    raise SystemExit(103)
                if decision.get('action') == 'reject':
                    if not require_pid_sort or worker.pid > baseline_pid:
                        raise SystemExit(97)
                    worker.terminate()
                    child_exit = worker.wait(timeout=2.0)
                    worker._handle.Close()
                    worker._handle = None
                    closed = {{'attempt': attempt, 'identity': identity,
                              'terminate_called': True,
                              'wait_exit_code': child_exit,
                              'original_popen_handle_closed': True}}
                    write_json_atomic(closed_path, closed)
                    deadline = time.monotonic() + 1.0
                    while not absent_path.exists() and time.monotonic() < deadline:
                        time.sleep(0.01)
                    if not absent_path.exists():
                        raise SystemExit(98)
                    absent = json.loads(absent_path.read_text(encoding='utf-8'))
                    if (absent.get('attempt') != attempt or
                            absent.get('identity') != identity or
                            absent.get('complete') is not True or
                            absent.get('pid_absent') is not True or
                            absent.get('pid_reuse_observed') is not False):
                        raise SystemExit(99)
                    attempts.append({{'decision': decision, 'termination': closed,
                                     'absence': absent}})
                    continue
                if (decision.get('action') != 'accept' or
                        (require_pid_sort and worker.pid <= baseline_pid)):
                    raise SystemExit(100)
                pathlib.Path({str(target_release_file)!r}).write_text(
                    'release', encoding='ascii')
                deadline = time.monotonic() + 1.0
                while not pathlib.Path({str(target_pid)!r}).exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                if (not pathlib.Path({str(target_pid)!r}).exists() or
                        int(pathlib.Path({str(target_pid)!r}).read_text(
                            encoding='ascii').strip()) != worker.pid):
                    raise SystemExit(101)
                deadline = time.monotonic() + 2.0
                while not detach_path.exists() and time.monotonic() < deadline:
                    time.sleep(0.01)
                if not detach_path.exists():
                    raise SystemExit(108)
                detach_request = json.loads(detach_path.read_text(encoding='utf-8'))
                if (detach_request.get('identity') != identity or
                        detach_request.get('source_snapshot') !=
                            decision.get('source_snapshot') or
                        detach_request.get('source_row', {{}}).get('pid') != worker.pid):
                    raise SystemExit(109)
                detached = detach_live_popen(
                    worker, identity, detach_request.get('source_row', {{}}),
                    detach_request.get('source_snapshot', {{}}))
                detached['schema'] = 'vnext-t2-r20-live-popen-detach-r1'
                detached['phase'] = 'candidate_bound_to_complete_source_spi'
                accepted_record = {{'attempt': attempt, 'identity': identity,
                                   'released': True,
                                   'pid_ordering_required': require_pid_sort,
                                   **detached}}
                attempts.append({{'decision': decision,
                                 'accepted_target': accepted_record}})
                write_json_atomic(closed_path, accepted_record)
                write_json_atomic(pathlib.Path({str(target_selection_file)!r}), {{
                    'schema': 'vnext-t2-r20-target-pid-selection-r2',
                    'baseline_pid': baseline_pid,
                    'baseline_identity': baseline_identity,
                    'pid_ordering_required': require_pid_sort,
                    'max_attempts': max_attempts,
                    'attempts': attempts,
                    'accepted_identity': identity,
                }})
                accepted = True
                break
            finally:
                if getattr(worker, '_handle', None) is not None:
                    worker._handle.Close()
                    worker._handle = None
        if not accepted:
            raise SystemExit(102)
        print('R20_TARGET_STARTED', worker.pid, flush=True)
        if {wait_for_root_release!r}:
            root_release = pathlib.Path({str(root_release_file)!r})
            deadline = time.monotonic() + {float(root_seconds)!r}
            while not root_release.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            if not root_release.exists():
                raise SystemExit(110)
        else:
            time.sleep({float(root_seconds)!r})
    """).strip()
    return [sys.executable, "-B", "-c", root_code]


def install_r20_race_hooks(module: types.ModuleType, phase_dir: Path,
                           *, launch_orphan: bool,
                           inject_open_denial: bool = False,
                           require_candidate_pid_after_baseline: bool = True,
                           wait_for_root_release: bool = False) -> tuple[dict[str, Any], list[Any]]:
    state: dict[str, Any] = {
        "target_exit_confirmed": False,
        "race_triggered": False,
        "injected_open_denial": inject_open_denial,
        "source_snapshot": None,
        "source_identity": None,
        "open_failure": None,
        "registry_open_succeeded": False,
        "registry_handle_identity": None,
        "native_liveness_waits": [],
        "keeper_open_identity": None,
        "keeper_wait_signaled": False,
        "keeper_close_succeeded": False,
        "keeper_close_monotonic": None,
        "post_failure_snapshot_monotonic": [],
        "failure_window_started": False,
        "post_failure_snapshots": [],
        "target_pid": None,
        "orphan_pid": None,
        "sample_one_completed": False,
        "baseline_ready_before_sample_two": False,
        "sample_two_completed": False,
        "target_ready_before_sample_three": False,
        "baseline_pid": None,
        "baseline_identity": None,
        "baseline_source_snapshot": None,
        "baseline_popen_handle_detach": None,
        "candidate_pid_ordering_required": require_candidate_pid_after_baseline,
        "candidate_max_attempts": MAX_CANDIDATE_ATTEMPTS,
        "candidate_attempts": [],
        "candidate_selection_receipt": None,
        "accepted_target_identity": None,
        "wait_for_root_release": wait_for_root_release,
        "root_release_written": False,
        "root_release_receipt": None,
        "for_row_calls": [],
    }
    snapshots: list[Any] = []
    native = module._R23_TABLE
    registry_class = module._R23_SUPERVISOR.ExactHandleRegistry
    original_for_row = registry_class.for_row
    original_query = native.query_native_process_table
    original_wait = native.wait_for_process_exit
    original_sample = module._r20_native_sample
    target_pid_file = phase_dir / "target_pid.txt"
    orphan_pid_file = phase_dir / "orphan_pid.txt"
    begin_baseline_file = phase_dir / "begin_baseline.txt"
    baseline_ready_file = phase_dir / "baseline_ready.txt"
    begin_target_file = phase_dir / "begin_target.txt"
    target_selection_file = phase_dir / "target_selection.json"
    candidate_attempt_prefix = phase_dir / "candidate_attempt_"
    candidate_ready_prefix = phase_dir / "candidate_ready_"
    candidate_decision_prefix = phase_dir / "candidate_decision_"
    candidate_closed_prefix = phase_dir / "candidate_closed_"
    candidate_absent_prefix = phase_dir / "candidate_absent_"
    candidate_detach_prefix = phase_dir / "candidate_detach_request_"
    baseline_detach_request_file = phase_dir / "baseline_detach_request.json"
    baseline_detached_file = phase_dir / "baseline_handle_detached.json"
    root_release_file = phase_dir / "root_release.txt"

    def wait_for_ready_marker(path: Path, label: str,
                              deadline_monotonic: float) -> int:
        bounded_deadline = min(deadline_monotonic, time.monotonic() + 5.0)
        while time.monotonic() < bounded_deadline:
            try:
                value = int(path.read_text(encoding="ascii").strip())
                if value > 0:
                    return value
            except (OSError, ValueError):
                pass
            time.sleep(0.01)
        raise RuntimeError(f"R20 {label} barrier was not ready before the next sample")

    def write_json_atomic(path: Path, value: Any) -> None:
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_text(json.dumps(value, sort_keys=True), encoding="utf-8")
        temporary.replace(path)

    def wait_json(path: Path, deadline_monotonic: float, label: str) -> dict[str, Any]:
        while time.monotonic() < deadline_monotonic:
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(value, dict):
                    return value
            except (OSError, ValueError):
                pass
            time.sleep(0.01)
        raise RuntimeError(f"R20 {label} handshake did not complete before the sample deadline")

    def process_closure_rows(snapshot: Any, root_pid: int) -> list[dict[str, Any]]:
        pids = {root_pid}
        changed = True
        while changed:
            changed = False
            for row in snapshot.rows:
                if row.ppid in pids and row.identity.pid not in pids:
                    pids.add(row.identity.pid)
                    changed = True
        return [{"pid": row.identity.pid,
                 "create_time_100ns": row.identity.create_time_100ns,
                 "ppid": row.ppid, "name": row.name}
                for row in sorted(snapshot.rows, key=lambda item: item.identity.pid)
                if row.identity.pid in pids]

    def select_target_after_baseline(deadline_monotonic: float) -> int:
        baseline_pid = state.get("baseline_pid")
        baseline_identity = state.get("baseline_identity")
        if (type(baseline_pid) is not int or baseline_pid <= 0 or
                not isinstance(baseline_identity, dict) or
                baseline_identity.get("pid") != baseline_pid or
                type(baseline_identity.get("create_time_100ns")) is not int):
            raise RuntimeError("R20 baseline helper PID was not pinned before candidate selection")
        for attempt in range(1, MAX_CANDIDATE_ATTEMPTS + 1):
            suffix = f"{attempt:02d}.json"
            attempt_path = Path(str(candidate_attempt_prefix) + suffix)
            ready_path = Path(str(candidate_ready_prefix) + suffix)
            decision_path = Path(str(candidate_decision_prefix) + suffix)
            closed_path = Path(str(candidate_closed_prefix) + suffix)
            absent_path = Path(str(candidate_absent_prefix) + suffix)
            detach_path = Path(str(candidate_detach_prefix) + suffix)
            attempt_marker = wait_json(
                attempt_path, min(deadline_monotonic, time.monotonic() + 1.0),
                f"candidate {attempt} start")
            require_candidate_pid = attempt_marker.get("pid")
            if (attempt_marker.get("attempt") != attempt or
                    type(require_candidate_pid) is not int or
                    require_candidate_pid <= 0):
                raise RuntimeError("R20 candidate launch marker has an invalid attempt/PID")
            ready_pid = wait_for_ready_marker(
                ready_path, f"candidate {attempt}", deadline_monotonic)
            if ready_pid != require_candidate_pid:
                raise RuntimeError("R20 candidate ready marker differs from its original Popen PID")

            source_snapshot = native.validate_snapshot(original_query())
            if source_snapshot.complete is not True:
                raise RuntimeError("R20 candidate source SPI snapshot was incomplete")
            row = source_snapshot.by_pid.get(require_candidate_pid)
            if row is None or row.identity.pid != require_candidate_pid:
                raise RuntimeError("R20 candidate PID was absent from its complete live source SPI table")
            baseline_row = source_snapshot.by_pid.get(baseline_pid)
            if (baseline_row is None or
                    baseline_row.identity.pid != baseline_pid or
                    baseline_row.identity.create_time_100ns !=
                        baseline_identity["create_time_100ns"]):
                raise RuntimeError("R20 exact baseline helper generation was absent or changed in candidate source SPI")
            identity = {"pid": row.identity.pid,
                        "create_time_100ns": row.identity.create_time_100ns}
            baseline_row_receipt = {
                "pid": baseline_row.identity.pid,
                "create_time_100ns": baseline_row.identity.create_time_100ns,
                "ppid": baseline_row.ppid, "name": baseline_row.name,
            }
            closure_rows = process_closure_rows(source_snapshot, row.identity.pid)
            closure_identities = [{"pid": item["pid"],
                                   "create_time_100ns": item["create_time_100ns"]}
                                  for item in closure_rows]
            action = (
                "accept" if not require_candidate_pid_after_baseline or
                row.identity.pid > baseline_pid else "reject")
            source_receipt = module._r23_snapshot_receipt(source_snapshot)
            decision = {
                "attempt": attempt, "action": action, "identity": identity,
                "baseline_pid": baseline_pid,
                "baseline_identity": baseline_identity,
                "baseline_row_in_source_snapshot": baseline_row_receipt,
                "baseline_source_snapshot": state.get("baseline_source_snapshot"),
                "pid_ordering_required": require_candidate_pid_after_baseline,
                "source_snapshot": source_receipt,
                "observed_generation_closure": closure_rows,
            }
            write_json_atomic(decision_path, decision)
            attempt_receipt: dict[str, Any] = {
                "attempt": attempt, "action": action, "identity": identity,
                "baseline_pid": baseline_pid,
                "baseline_identity": baseline_identity,
                "baseline_row_in_source_snapshot": baseline_row_receipt,
                "baseline_source_snapshot": state.get("baseline_source_snapshot"),
                "pid_ordering_required": require_candidate_pid_after_baseline,
                "source_snapshot": source_receipt,
                "observed_generation_closure": closure_rows,
            }
            if action == "accept":
                target_pid = wait_for_ready_marker(
                    target_pid_file, "accepted target", deadline_monotonic)
                if target_pid != row.identity.pid:
                    raise RuntimeError("R20 accepted target ready marker changed its exact PID")
                source_row_receipt = {
                    "pid": row.identity.pid,
                    "create_time_100ns": row.identity.create_time_100ns,
                    "ppid": row.ppid, "name": row.name,
                }
                write_json_atomic(detach_path, {
                    "schema": "vnext-t2-r20-live-popen-detach-request-r1",
                    "identity": identity,
                    "source_row": source_row_receipt,
                    "source_snapshot": source_receipt,
                    "reason": "complete_live_source_spi_generation_bound_before_sample_three",
                })
                closed = wait_json(
                    closed_path,
                    min(deadline_monotonic, time.monotonic() + 1.0),
                    f"accepted candidate {attempt} Popen-handle close")
                if (closed.get("identity") != identity or
                        closed.get("original_popen_handle_closed") is not True or
                        closed.get("released") is not True or
                        closed.get("popen_wrapper_ownership_transferred") is not True or
                        closed.get("popen_child_created_before_transfer") is not True or
                        closed.get("popen_child_created_after_transfer") is not False or
                        closed.get("popen_wrapper_detached_after_exact_live_spi_binding")
                            is not True or
                        closed.get("returncode_was_not_synthesized") is not True or
                        closed.get("process_poll_returncode") is not None or
                        closed.get("source_row") != source_row_receipt or
                        closed.get("source_snapshot") != source_receipt):
                    raise RuntimeError("R20 accepted candidate ownership-transfer receipt was not exact")
                selection = wait_json(
                    target_selection_file,
                    min(deadline_monotonic, time.monotonic() + 1.0),
                    "target PID selection receipt")
                if (selection.get("schema") !=
                        "vnext-t2-r20-target-pid-selection-r2" or
                        selection.get("baseline_pid") != baseline_pid or
                        selection.get("pid_ordering_required") !=
                            require_candidate_pid_after_baseline or
                        selection.get("max_attempts") != MAX_CANDIDATE_ATTEMPTS or
                        selection.get("accepted_identity") != identity):
                    raise RuntimeError("R20 target selection receipt lost its exact baseline/target binding")
                attempt_receipt["accepted_target_popen_handle_close"] = closed
                state["candidate_attempts"].append(attempt_receipt)
                state["candidate_selection_receipt"] = selection
                state["accepted_target_identity"] = identity
                state["target_pid"] = target_pid
                state["target_pid_from_ready_marker"] = target_pid
                state["target_ready_before_sample_three"] = True
                return target_pid

            closed = wait_json(
                closed_path,
                min(deadline_monotonic, time.monotonic() + 1.0),
                f"rejected candidate {attempt} exact Popen termination/close")
            if (closed.get("identity") != identity or
                    closed.get("terminate_called") is not True or
                    type(closed.get("wait_exit_code")) is not int or
                    closed.get("original_popen_handle_closed") is not True):
                raise RuntimeError("R20 rejected candidate was not terminated, waited, and closed through its original Popen handle")

            absence_deadline = min(deadline_monotonic, time.monotonic() + 1.5)
            absence_receipt = None
            while time.monotonic() < absence_deadline:
                current = native.validate_snapshot(original_query())
                if current.complete is not True:
                    raise RuntimeError("R20 rejected-candidate post-close SPI table was incomplete")
                current_by_pid = current.by_pid
                reused = [old for old in closure_identities
                          if old["pid"] in current_by_pid and
                          current_by_pid[old["pid"]].identity.create_time_100ns !=
                          old["create_time_100ns"]]
                if reused:
                    raise RuntimeError("R20 rejected-candidate PID was reused before complete SPI absence")
                remaining = [old for old in closure_identities
                             if old["pid"] in current_by_pid]
                if not remaining:
                    absence_receipt = {
                        "attempt": attempt, "identity": identity,
                        "complete": True, "pid_absent": True,
                        "pid_reuse_observed": False,
                        "absent_generation_pids": [item["pid"]
                                                    for item in closure_identities],
                        "snapshot": module._r23_snapshot_receipt(current),
                    }
                    break
                time.sleep(0.01)
            if absence_receipt is None:
                raise RuntimeError("R20 rejected candidate or its observed closure remained in complete SPI")
            attempt_receipt["popen_termination_wait_close"] = closed
            attempt_receipt["post_close_absence"] = absence_receipt
            state["candidate_attempts"].append(attempt_receipt)
            write_json_atomic(absent_path, absence_receipt)
        raise RuntimeError(
            f"R20 did not obtain a target PID above stable helper PID {baseline_pid} "
            f"within {MAX_CANDIDATE_ATTEMPTS} bounded attempts")

    def sample_hook(process: Any, registry: Any, root_identity: Any,
                    previous: Any, *, sample_index: int, elapsed: float,
                    deadline_monotonic: float) -> dict[str, Any]:
        if sample_index == 2:
            state["baseline_pid"] = wait_for_ready_marker(
                baseline_ready_file, "baseline helper", deadline_monotonic)
            baseline_snapshot = native.validate_snapshot(original_query())
            baseline_row = baseline_snapshot.by_pid.get(state["baseline_pid"])
            if baseline_snapshot.complete is not True or baseline_row is None:
                raise RuntimeError("R20 baseline helper was not present in a complete sample-2 source SPI table")
            state["baseline_identity"] = {
                "pid": baseline_row.identity.pid,
                "create_time_100ns": baseline_row.identity.create_time_100ns,
            }
            state["baseline_source_snapshot"] = module._r23_snapshot_receipt(
                baseline_snapshot)
            state["baseline_ready_before_sample_two"] = True
        if sample_index == 3:
            select_target_after_baseline(deadline_monotonic)
        value = original_sample(
            process, registry, root_identity, previous,
            sample_index=sample_index, elapsed=elapsed,
            deadline_monotonic=deadline_monotonic)
        if sample_index == 1 and value.get("sample_complete") is True and \
                not state["sample_one_completed"]:
            state["sample_one_completed"] = True
            begin_baseline_file.write_text("start\n", encoding="ascii")
        if sample_index == 2 and value.get("sample_complete") is True and \
                not state["sample_two_completed"]:
            state["sample_two_completed"] = True
            baseline_pid = state.get("baseline_pid")
            baseline_identity = state.get("baseline_identity")
            baseline_snapshot = native.validate_snapshot(original_query())
            if baseline_snapshot.complete is not True:
                raise RuntimeError("R20 baseline-detach source SPI snapshot was incomplete")
            baseline_row = baseline_snapshot.by_pid.get(baseline_pid)
            if (baseline_row is None or
                    baseline_identity != {
                        "pid": baseline_row.identity.pid,
                        "create_time_100ns": baseline_row.identity.create_time_100ns}):
                raise RuntimeError("R20 baseline helper generation changed before ownership transfer")
            source_receipt = module._r23_snapshot_receipt(baseline_snapshot)
            baseline_row_receipt = {
                "pid": baseline_row.identity.pid,
                "create_time_100ns": baseline_row.identity.create_time_100ns,
                "ppid": baseline_row.ppid, "name": baseline_row.name,
            }
            write_json_atomic(baseline_detach_request_file, {
                "schema": "vnext-t2-r20-live-popen-detach-request-r1",
                "identity": baseline_identity,
                "source_row": baseline_row_receipt,
                "source_snapshot": source_receipt,
                "reason": "completed_sample_two_exact_live_baseline_generation",
            })
            baseline_detach = wait_json(
                baseline_detached_file,
                min(deadline_monotonic, time.monotonic() + 2.0),
                "baseline helper Popen-handle transfer")
            if (baseline_detach.get("schema") !=
                    "vnext-t2-r20-live-popen-detach-r1" or
                    baseline_detach.get("phase") !=
                    "completed_sample_two_baseline" or
                    baseline_detach.get("identity") != baseline_identity or
                    baseline_detach.get("source_row") != baseline_row_receipt or
                    baseline_detach.get("source_snapshot") != source_receipt or
                    baseline_detach.get("process_poll_returncode") is not None or
                    baseline_detach.get("original_popen_handle_closed") is not True or
                    baseline_detach.get("popen_wrapper_ownership_transferred") is not True or
                    baseline_detach.get("popen_child_created_before_transfer") is not True or
                    baseline_detach.get("popen_child_created_after_transfer") is not False or
                    baseline_detach.get("popen_wrapper_detached_after_exact_live_spi_binding")
                        is not True or
                    baseline_detach.get("returncode_was_not_synthesized") is not True):
                raise RuntimeError("R20 baseline Popen ownership-transfer receipt was incomplete or changed generation")
            state["baseline_popen_handle_detach"] = baseline_detach
            state["baseline_detach_source_row"] = baseline_row_receipt
            begin_target_file.write_text("start\n", encoding="ascii")
        if state.get("wait_for_root_release") is True and sample_index == 3:
            recoveries = value.get("sample_handoff_recoveries", [])
            recovery = recoveries[0] if len(recoveries) == 1 else {}
            discarded = recovery.get("discarded_attempt", {})
            first_three = state.get("post_failure_snapshots", [])[:3]
            first_three_receipts = [
                module._r23_snapshot_receipt(item) for item in first_three]
            target_pid = state.get("target_pid")
            release_ready = (
                value.get("sample_complete") is True and
                len(recoveries) == 1 and
                recovery.get("status") ==
                    "recovered_by_new_complete_whole_sample" and
                recovery.get("complete") is True and
                recovery.get("full_sample_completed_after_retry") is True and
                recovery.get("whole_sample_attempt_index") == 1 and
                recovery.get("full_sample_attempt_index") == 2 and
                recovery.get("target_identity") ==
                    state.get("accepted_target_identity") and
                len(first_three) == 3 and
                all(item.complete is True and target_pid not in item.by_pid
                    for item in first_three) and
                recovery.get("lookup_snapshot") == first_three_receipts[0] and
                recovery.get("confirmation_snapshots") ==
                    first_three_receipts[1:] and
                discarded.get("observed_partial_rss_bytes_not_credited", 0) > 0 and
                discarded.get("credited_rss_bytes") == 0 and
                discarded.get("credited_cpu_seconds") ==
                    {"user": 0.0, "system": 0.0} and
                discarded.get("exit_code_credit_issued") is False and
                recovery.get("exit_code_credit_issued") is False and
                recovery.get("rss_credit_bytes") == 0 and
                recovery.get("cpu_credit_seconds") ==
                    {"user": 0.0, "system": 0.0})
            if not release_ready:
                raise RuntimeError(
                    "R9 root release requires complete sample 3 after the exact whole-sample race recovery")
            release_receipt = {
                "schema": "vnext-t2-r20-root-release-after-recovered-sample-r1",
                "sample_index": sample_index,
                "sample_complete": True,
                "recovery_status": recovery.get("status"),
                "recovery_count": len(recoveries),
                "target_identity": recovery.get("target_identity"),
                "absence_snapshot_count": len(first_three_receipts),
                "absence_snapshots": first_three_receipts,
                "discarded_partial_rss_bytes": discarded.get(
                    "observed_partial_rss_bytes_not_credited"),
                "discarded_rss_credit_bytes": discarded.get(
                    "credited_rss_bytes"),
                "discarded_cpu_credit_seconds": discarded.get(
                    "credited_cpu_seconds"),
                "exit_code_credit_issued": recovery.get(
                    "exit_code_credit_issued"),
            }
            root_release_file.write_text("release\n", encoding="ascii")
            state["root_release_written"] = True
            state["root_release_receipt"] = release_receipt
        return value

    def for_row(registry: Any, row: Any, snapshot: Any) -> Any:
        state["for_row_calls"].append({
            "pid": row.identity.pid,
            "create_time_100ns": row.identity.create_time_100ns,
            "target_pid_file_exists": target_pid_file.is_file(),
            "registry_class": type(registry).__name__,
        })
        if target_pid_file.is_file():
            try:
                target_pid = int(target_pid_file.read_text(encoding="ascii").strip())
            except (OSError, ValueError):
                target_pid = None
            if target_pid is not None:
                state["target_pid"] = target_pid
                if orphan_pid_file.is_file():
                    try:
                        state["orphan_pid"] = int(
                            orphan_pid_file.read_text(encoding="ascii").strip())
                    except (OSError, ValueError):
                        pass
                identity = (row.identity.pid, row.identity.create_time_100ns)
                if identity[0] == target_pid and state["race_triggered"] is False:
                    state["race_triggered"] = True
                    state["source_snapshot"] = module._r23_snapshot_receipt(snapshot)
                    state["source_identity"] = {
                        "pid": identity[0], "create_time_100ns": identity[1],
                        "ppid": row.ppid, "name": row.name}
                    if not inject_open_denial:
                        keeper = None
                        try:
                            keeper = native.open_exact_process_handle(row)
                            keeper_identity = native.read_process_handle_identity(keeper)
                            assert_true(keeper_identity == identity,
                                        "keeper handle did not bind to the exact source PID/FILETIME")
                            state["keeper_open_identity"] = list(keeper_identity)
                            native.terminate_process_handle(keeper, exit_code=15)
                            state["keeper_wait_signaled"] = \
                                native.wait_for_process_exit(keeper, 5.0)
                            assert_true(state["keeper_wait_signaled"] is True,
                                        "keeper handle did not confirm target exit")
                            state["target_exit_confirmed"] = True
                            handle = original_for_row(registry, row, snapshot)
                            state["registry_open_succeeded"] = True
                            state["registry_handle_identity"] = list(
                                native.read_process_handle_identity(handle))
                            state["failure_window_started"] = True
                            native.close_process_handle(keeper)
                            keeper = None
                            state["keeper_close_succeeded"] = True
                            state["keeper_close_monotonic"] = time.monotonic()
                            return handle
                        except Exception as error:
                            state["open_failure"] = {
                                "exception_type": type(error).__name__,
                                "message": str(error)}
                            state["failure_window_started"] = True
                            raise
                        finally:
                            if keeper is not None:
                                native.close_process_handle(keeper)
                    else:
                        state["failure_window_started"] = True
                        state["open_failure"] = {
                            "exception_type": "ControlledOpenDenied",
                            "message": "test-only denial while exact observed generation remains live"}
                        raise OSError(
                            "test-only OpenProcess denial for failed-open orphan cleanup control")
                    raise AssertionError("injected open-denial branch should have raised")
        return original_for_row(registry, row, snapshot)

    def wait_for_exit(handle: Any, timeout_seconds: float) -> bool:
        identity = None
        try:
            identity = native.read_process_handle_identity(handle)
        except Exception:
            pass
        result = original_wait(handle, timeout_seconds)
        source_identity = state.get("source_identity")
        if (state.get("registry_open_succeeded") is True and
                isinstance(source_identity, dict) and identity == (
                source_identity.get("pid"),
                source_identity.get("create_time_100ns"))):
            state["native_liveness_waits"].append({
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "timeout_seconds": timeout_seconds,
                "wait_for_process_exit_return": result,
                "win32_wait_result": "WAIT_OBJECT_0" if result is True else
                                     "WAIT_TIMEOUT" if result is False else "invalid",
            })
        return result

    def query() -> Any:
        snapshot = original_query()
        if state["failure_window_started"] is True and \
                len(state["post_failure_snapshots"]) < 4:
            state["post_failure_snapshots"].append(snapshot)
            state["post_failure_snapshot_monotonic"].append(time.monotonic())
        return snapshot

    registry_class.for_row = for_row
    native.query_native_process_table = query
    native.wait_for_process_exit = wait_for_exit
    module._r20_native_sample = sample_hook
    state["restore"] = lambda: (
        setattr(registry_class, "for_row", original_for_row),
        setattr(native, "query_native_process_table", original_query),
        setattr(native, "wait_for_process_exit", original_wait),
        setattr(module, "_r20_native_sample", original_sample))
    return state, snapshots


def check_race_phase(module: types.ModuleType, phase: dict[str, Any],
                     state: dict[str, Any]) -> dict[str, Any]:
    recoveries = phase.get("sample_handoff_recoveries", [])
    assert_true(state.get("sample_one_completed") is True and
                state.get("baseline_ready_before_sample_two") is True and
                state.get("sample_two_completed") is True and
                state.get("target_ready_before_sample_three") is True and
                state.get("wait_for_root_release") is True and
                state.get("root_release_written") is True and
                state.get("root_release_receipt", {}).get(
                    "sample_index") == 3 and
                state.get("root_release_receipt", {}).get(
                    "sample_complete") is True and
                state.get("root_release_receipt", {}).get(
                    "recovery_status") ==
                    "recovered_by_new_complete_whole_sample" and
                state.get("root_release_receipt", {}).get(
                    "absence_snapshot_count") == 3 and
                state.get("root_release_receipt", {}).get(
                    "discarded_partial_rss_bytes", 0) > 0 and
                state.get("root_release_receipt", {}).get(
                    "discarded_rss_credit_bytes") == 0 and
                state.get("root_release_receipt", {}).get(
                    "exit_code_credit_issued") is False and
                type(state.get("baseline_pid")) is int and
                state.get("baseline_identity", {}).get("pid") ==
                    state.get("baseline_pid") and
                type(state.get("baseline_identity", {}).get(
                    "create_time_100ns")) is int and
                state.get("baseline_source_snapshot", {}).get("complete") is True and
                state.get("baseline_popen_handle_detach", {}).get(
                    "popen_wrapper_ownership_transferred") is True and
                state.get("baseline_popen_handle_detach", {}).get(
                    "identity") == state.get("baseline_identity") and
                state.get("baseline_popen_handle_detach", {}).get(
                    "process_poll_returncode") is None and
                state.get("baseline_popen_handle_detach", {}).get(
                    "returncode_was_not_synthesized") is True and
                state.get("target_pid_from_ready_marker") == state.get("target_pid"),
                "R20 staged fixture did not stabilize a baseline helper and target between complete samples")
    candidate_attempts = state.get("candidate_attempts", [])
    candidate_selection = state.get("candidate_selection_receipt", {})
    assert_true(1 <= len(candidate_attempts) <= MAX_CANDIDATE_ATTEMPTS and
                len(candidate_selection.get("attempts", [])) == len(candidate_attempts) and
                candidate_selection.get("max_attempts") == MAX_CANDIDATE_ATTEMPTS and
                candidate_selection.get("baseline_pid") == state.get("baseline_pid") and
                candidate_selection.get("baseline_identity") ==
                    state.get("baseline_identity") and
                candidate_attempts[-1].get("action") == "accept" and
                candidate_attempts[-1].get("identity") ==
                    state.get("accepted_target_identity") and
                candidate_selection.get("pid_ordering_required") is True and
                candidate_attempts[-1].get(
                    "accepted_target_popen_handle_close", {}).get(
                        "popen_wrapper_ownership_transferred") is True and
                candidate_attempts[-1].get(
                    "accepted_target_popen_handle_close", {}).get(
                        "popen_child_created_before_transfer") is True and
                candidate_attempts[-1].get(
                    "accepted_target_popen_handle_close", {}).get(
                        "popen_child_created_after_transfer") is False and
                candidate_attempts[-1].get(
                    "accepted_target_popen_handle_close", {}).get(
                        "returncode_was_not_synthesized") is True and
                state.get("target_pid") > state.get("baseline_pid"),
                "R20 target selection did not bind a bounded live PID above the stable helper")
    assert_true(all(item.get("baseline_identity") ==
                        state.get("baseline_identity") and
                    item.get("baseline_source_snapshot", {}).get(
                        "complete") is True and
                    item.get("baseline_row_in_source_snapshot") == {
                        "pid": state["baseline_identity"]["pid"],
                        "create_time_100ns": state["baseline_identity"][
                            "create_time_100ns"],
                        "ppid": item.get("baseline_row_in_source_snapshot", {}).get("ppid"),
                        "name": item.get("baseline_row_in_source_snapshot", {}).get("name"),
                    } and
                    item.get("source_snapshot", {}).get("complete") is True
                    for item in candidate_attempts),
                "R20 candidate selection did not preserve the exact baseline PID/FILETIME in each complete decision snapshot")
    rejected_attempts = candidate_attempts[:-1]
    assert_true(all(item.get("action") == "reject" and
                    item.get("identity", {}).get("pid", 0) <=
                        state.get("baseline_pid", 0) and
                    item.get("source_snapshot", {}).get("complete") is True and
                    any(row.get("pid") == item.get("identity", {}).get("pid") and
                        row.get("create_time_100ns") ==
                            item.get("identity", {}).get("create_time_100ns")
                        for row in item.get("observed_generation_closure", [])) and
                    item.get("popen_termination_wait_close", {}).get(
                        "terminate_called") is True and
                    type(item.get("popen_termination_wait_close", {}).get(
                        "wait_exit_code")) is int and
                    item.get("popen_termination_wait_close", {}).get(
                        "original_popen_handle_closed") is True and
                    item.get("post_close_absence", {}).get("complete") is True and
                    item.get("post_close_absence", {}).get("pid_absent") is True and
                    item.get("post_close_absence", {}).get("snapshot", {}).get(
                        "complete") is True and
                    item.get("post_close_absence", {}).get(
                        "pid_reuse_observed") is False and
                    [row.get("pid") for row in
                     item.get("observed_generation_closure", [])] ==
                        item.get("post_close_absence", {}).get(
                            "absent_generation_pids", [])
                    for item in rejected_attempts) and
                all(item.get("decision", {}).get("action") == "reject" and
                    item.get("termination", {}).get(
                        "original_popen_handle_closed") is True and
                    item.get("absence", {}).get("pid_absent") is True
                    for item in candidate_selection.get("attempts", [])[:-1]) and
                candidate_selection.get("attempts", [])[-1].get(
                    "decision", {}).get("action") == "accept",
                "R20 rejected candidate lacked exact live SPI identity, original-handle termination/close, or fresh absence proof")
    assert_true(state.get("target_exit_confirmed") is True and
                state.get("failure_window_started") is True,
                "controlled descendant did not exit before real OpenProcess/liveness binding")
    assert_true(len(recoveries) == 1,
                "R20 race phase did not retain exactly one source-row recovery receipt")
    recovery = recoveries[0]
    source_identity = state.get("source_identity")
    assert_true(isinstance(source_identity, dict) and
                source_identity.get("pid") == state.get("target_pid") and
                state.get("registry_open_succeeded") is True and
                state.get("registry_handle_identity") == [
                    source_identity.get("pid"), source_identity.get("create_time_100ns")] and
                recovery.get("source_snapshot") == state.get("source_snapshot") and
                recovery.get("target_identity") == {
                    "pid": source_identity.get("pid"),
                    "create_time_100ns": source_identity.get("create_time_100ns")},
                "R20 recovery lost the exact PID/raw FILETIME from the before-SPI row")
    fresh = state.get("post_failure_snapshots", [])
    assert_true(len(fresh) >= 3,
                "R20 did not issue three new native SPI queries after exact handle failure")
    first_three = fresh[:3]
    first_three_receipts = [module._r23_snapshot_receipt(item) for item in first_three]
    assert_true(len({id(item) for item in first_three}) == 3 and
                all(item.complete is True for item in first_three) and
                all(state["target_pid"] not in item.by_pid for item in first_three) and
                recovery.get("lookup_snapshot") == first_three_receipts[0] and
                recovery.get("confirmation_snapshots") == first_three_receipts[1:],
                "R20 did not retain three fresh complete absence snapshots for the vanished child")
    discarded = recovery.get("discarded_attempt", {})
    assert_true(recovery.get("complete") is True and
                recovery.get("full_sample_completed_after_retry") is True and
                recovery.get("whole_sample_attempt_index") == 1 and
                recovery.get("full_sample_attempt_index") == 2 and
                recovery.get("exact_handle_exit_receipt_created") is False and
                recovery.get("exit_code_credit_issued") is False and
                recovery.get("rss_credit_bytes") == 0 and
                recovery.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                discarded.get("credited_rss_bytes") == 0 and
                discarded.get("credited_cpu_seconds") == {"user": 0.0, "system": 0.0} and
                discarded.get("exit_code_credit_issued") is False and
                discarded.get("exact_handle_exit_receipt_created") is False and
                discarded.get("observed_partial_rss_bytes_not_credited", 0) > 0,
                "R20 did not discard all partial first-attempt metrics before a fresh full retry")
    if state.get("registry_open_succeeded") is True:
        assert_true(recovery.get("exact_handle_opened") is True and
                    recovery.get("exact_handle_waited") is True and
                    recovery.get("exact_handle_already_signaled") is True and
                    recovery.get("exact_handle_binding", {}).get("identity") == {
                        "pid": source_identity["pid"],
                        "create_time_100ns": source_identity["create_time_100ns"]},
                    "R20 did not route a real opened-but-signaled process handle into race recovery")
    waits = state.get("native_liveness_waits", [])
    assert_true(any(item.get("identity") == {
                        "pid": source_identity["pid"],
                        "create_time_100ns": source_identity["create_time_100ns"]} and
                    item.get("wait_for_process_exit_return") is True and
                    item.get("win32_wait_result") == "WAIT_OBJECT_0"
                    for item in waits),
                "R20 did not observe WAIT_OBJECT_0 on the exact opened stale process handle")
    post_failure_times = state.get("post_failure_snapshot_monotonic", [])
    assert_true(state.get("keeper_open_identity") == [
                    source_identity["pid"], source_identity["create_time_100ns"]] and
                state.get("keeper_wait_signaled") is True and
                state.get("keeper_close_succeeded") is True and
                type(state.get("keeper_close_monotonic")) in (int, float) and
                len(post_failure_times) >= 3 and
                state["keeper_close_monotonic"] <= post_failure_times[0],
                "exact keeper handle was not closed before fresh absence snapshots")
    close = phase.get("handle_close_receipt", {})
    assert_true(close.get("complete") is True and close.get("errors") == [] and
                any(item.get("pid") == source_identity["pid"] and
                    item.get("create_time_100ns") == source_identity[
                        "create_time_100ns"]
                    for item in close.get("closed_owned_handles", [])),
                "R20 stale-generation registry handle was not closed by exact PID/FILETIME")
    final_audit = phase.get("final_process_tree_audit", {})
    cleanup = (phase.get("termination_receipt") or {}).get("unbound_cleanup", {})
    assert_true(phase.get("stop_reason") == "natural_exit" and
                phase.get("stderr", {}).get("bytes") == 0 and
                final_audit.get("complete") is True and
                final_audit.get("residual_descendant_processes") == [] and
                cleanup.get("complete") is True and
                cleanup.get("post_cleanup_confirmation", {}).get("complete") is True,
                "R20 recovered race did not finish natural exit with complete cleanup and no residual")
    return {
        "staged_membership_barriers": {
            "sample_one_completed_before_baseline_launch": state.get(
                "sample_one_completed"),
            "baseline_pid_ready_before_sample_two": state.get("baseline_pid"),
            "sample_two_completed_before_target_launch": state.get(
                "sample_two_completed"),
            "target_pid_ready_before_sample_three": state.get(
                "target_pid_from_ready_marker"),
        },
        "target_pid_selection": {
            "baseline_pid": state.get("baseline_pid"),
            "baseline_identity": state.get("baseline_identity"),
            "baseline_source_snapshot": state.get("baseline_source_snapshot"),
            "max_attempts": MAX_CANDIDATE_ATTEMPTS,
            "attempt_count": len(candidate_attempts),
            "rejected_generations": rejected_attempts,
            "accepted_identity": state.get("accepted_target_identity"),
        },
        "source_row": source_identity,
        "source_snapshot": state.get("source_snapshot"),
        "target_exit_confirmed_before_open": True,
        "open_failure": state.get("open_failure"),
        "registry_open_succeeded": state.get("registry_open_succeeded"),
        "registry_handle_identity": state.get("registry_handle_identity"),
        "native_liveness_waits": waits,
        "exact_keeper_handle_closed_before_absence_queries": True,
        "keeper_handle_identity": state.get("keeper_open_identity"),
        "opened_handle_closed_by_identity": {
            "pid": source_identity["pid"],
            "create_time_100ns": source_identity["create_time_100ns"],
        },
        "post_open_handle_wait_signaled": recovery.get(
            "exact_handle_already_signaled"),
        "post_open_failure_snapshot_count": 3,
        "post_open_failure_absence_snapshots": first_three_receipts,
        "retry_sample_index": recovery.get("full_sample_attempt_index"),
        "attempt_count": 2,
        "discarded_partial_rss_bytes": discarded.get(
            "observed_partial_rss_bytes_not_credited"),
        "discarded_rss_credit_bytes": discarded.get("credited_rss_bytes"),
        "discarded_cpu_credit_seconds": discarded.get("credited_cpu_seconds"),
        "failed_attempt_exit_receipt": discarded.get(
            "exact_handle_exit_receipt_created"),
        "final_no_residual_audit": phase.get(
            "final_process_tree_audit", {}).get("complete") is True and
            phase.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [],
    }


def check_orphan_cleanup_phase(module: types.ModuleType, phase: dict[str, Any],
                               state: dict[str, Any]) -> dict[str, Any]:
    recoveries = phase.get("sample_handoff_recoveries", [])
    assert_true(state.get("injected_open_denial") is True and
                state.get("target_exit_confirmed") is False and
                isinstance(state.get("open_failure"), dict) and
                len(recoveries) >= 1 and
                recoveries[0].get("complete") is False and
                recoveries[0].get("full_sample_completed_after_retry") is False,
                "orphan control did not remain an incomplete non-retry failed-open sample")
    recovery = recoveries[0]
    candidate_attempts = state.get("candidate_attempts", [])
    candidate_selection = state.get("candidate_selection_receipt", {})
    accepted_candidate = candidate_attempts[-1] if candidate_attempts else {}
    accepted_close = accepted_candidate.get(
        "accepted_target_popen_handle_close", {})
    candidate_identity = state.get("accepted_target_identity")
    source_identity = recovery.get("target_identity")
    source_snapshot = accepted_candidate.get("source_snapshot", {})
    source_row = next((item for item in accepted_candidate.get(
        "observed_generation_closure", [])
        if isinstance(item, dict) and
        item.get("pid") == (candidate_identity or {}).get("pid") and
        item.get("create_time_100ns") ==
            (candidate_identity or {}).get("create_time_100ns")), None)
    baseline_row = accepted_candidate.get("baseline_row_in_source_snapshot", {})
    baseline_detach = state.get("baseline_popen_handle_detach", {})
    assert_true(state.get("sample_one_completed") is True and
                state.get("sample_two_completed") is True and
                candidate_selection.get("schema") ==
                    "vnext-t2-r20-target-pid-selection-r2" and
                candidate_selection.get("pid_ordering_required") is False and
                state.get("candidate_pid_ordering_required") is False and
                len(candidate_attempts) == 1 and
                len(candidate_selection.get("attempts", [])) == 1 and
                accepted_candidate.get("action") == "accept" and
                isinstance(candidate_identity, dict) and
                source_identity == candidate_identity and
                source_snapshot.get("complete") is True and
                isinstance(source_row, dict) and
                source_row.get("pid") == candidate_identity.get("pid") and
                source_row.get("create_time_100ns") ==
                    candidate_identity.get("create_time_100ns") and
                baseline_row.get("pid") == state.get("baseline_pid") and
                baseline_row.get("create_time_100ns") ==
                    state.get("baseline_identity", {}).get(
                        "create_time_100ns") and
                baseline_detach.get("identity") == state.get("baseline_identity") and
                baseline_detach.get("popen_wrapper_ownership_transferred") is True and
                baseline_detach.get("returncode_was_not_synthesized") is True and
                accepted_close.get("identity") == candidate_identity and
                accepted_close.get("popen_wrapper_ownership_transferred") is True and
                accepted_close.get("returncode_was_not_synthesized") is True and
                accepted_close.get("process_poll_returncode") is None,
                "R8 failed-open lane did not accept one exact source-bound candidate without numeric PID sorting or transfer both live Popen wrappers cleanly")
    discarded = recovery.get("discarded_attempt", {})
    first_three = state.get("post_failure_snapshots", [])[:3]
    assert_true(len(first_three) == 3 and
                all(item.complete is True for item in first_three) and
                all(state.get("target_pid") in item.by_pid for item in first_three) and
                recovery.get("retry_started") is False and
                recovery.get("exact_handle_exit_receipt_created") is False and
                recovery.get("exit_code_credit_issued") is False and
                recovery.get("rss_credit_bytes") == 0 and
                recovery.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                discarded.get("credited_rss_bytes") == 0 and
                discarded.get("credited_cpu_seconds") == {"user": 0.0, "system": 0.0} and
                discarded.get("exit_code_credit_issued") is False,
                "open-denied orphan control did not fail closed with three present-generation tables and zero credit")
    orphan_pid = state.get("orphan_pid")
    assert_true(type(orphan_pid) is int,
                "orphan control did not capture its controlled grandchild PID")
    observed = recoveries[0].get("observed_generations", [])
    orphan_row = next((item for item in observed if item.get("pid") == orphan_pid), None)
    assert_true(isinstance(orphan_row, dict),
                "failed-open recovery omitted the exact orphan generation from the source closure")
    cleanup = (phase.get("termination_receipt") or {}).get("unbound_cleanup")
    assert_true(isinstance(cleanup, dict),
                "phase cleanup omitted the unbound orphan receipt")
    plan = cleanup.get("plan", {})
    targets = plan.get("targets", [])
    assert_true(any(item.get("pid") == orphan_row["pid"] and
                    item.get("create_time_100ns") == orphan_row["create_time_100ns"]
                    for item in targets) and
                any(item.get("identity") == {
                        "pid": orphan_row["pid"],
                        "create_time_100ns": orphan_row["create_time_100ns"]} and
                    item.get("receipt", {}).get("complete") is True
                    for item in cleanup.get("signal_attempts", [])) and
                cleanup.get("complete") is True and
                cleanup.get("post_cleanup_confirmation", {}).get("complete") is True,
                "phase cleanup did not signal/wait/confirm the exact old orphan generation")
    termination = phase.get("termination_receipt", {})
    handle_close = phase.get("handle_close_receipt", {})
    final_audit = phase.get("final_process_tree_audit", {})
    global_heavy_audit = final_audit.get("global_heavy_process_audit", {})
    unbound_audit = phase.get("unbound_observation_final_audit", {})
    confirmation = cleanup.get("post_cleanup_confirmation", {})
    expected_error = {
        "exception_type": "RuntimeError",
        "stage": "r20_unbound_observation_final_audit",
        "message": "unbound observation record 0 is incomplete or malformed",
    }

    def has_expected_error(errors: Any) -> bool:
        return (isinstance(errors, list) and len(errors) == 1 and
                isinstance(errors[0], dict) and
                set(errors[0]) == set(expected_error) | {"pid"} and
                all(errors[0].get(key) == value
                    for key, value in expected_error.items()) and
                errors[0].get("pid") is None)

    observed_rows_are_four_unique_generations = (
        isinstance(observed, list) and len(observed) == 4 and
        all(isinstance(item, dict) and
            type(item.get("pid")) is int and item.get("pid") > 0 and
            type(item.get("create_time_100ns")) is int and
            item.get("create_time_100ns") > 0 and
            type(item.get("ppid")) is int and item.get("ppid") >= 0 and
            isinstance(item.get("name"), str) and bool(item.get("name"))
            for item in observed))
    expected_generations = {
        (item.get("pid"), item.get("create_time_100ns"))
        for item in observed
        if isinstance(item, dict)
    }
    target_identity = recovery.get("target_identity", {})
    root_identity = recovery.get("root_identity", {})
    root_launch_identity = phase.get("root_launch_identity", {})
    target_row = next((item for item in observed
                       if isinstance(item, dict) and
                       item.get("pid") == target_identity.get("pid") and
                       item.get("create_time_100ns") ==
                           target_identity.get("create_time_100ns")), None)
    observed_by_pid = {item.get("pid"): item for item in observed
                       if isinstance(item, dict)}
    reachable_descendants = {target_identity.get("pid")}
    while True:
        expanded = reachable_descendants | {
            item.get("pid") for item in observed
            if isinstance(item, dict) and item.get("pid") !=
                target_identity.get("pid") and
            item.get("ppid") in reachable_descendants
        }
        if expanded == reachable_descendants:
            break
        reachable_descendants = expanded
    lineage_edges = []
    if isinstance(target_row, dict):
        lineage_edges.append((root_identity, target_row))
        lineage_edges.extend(
            (observed_by_pid.get(item.get("ppid")), item)
            for item in observed
            if isinstance(item, dict) and
            item.get("pid") != target_identity.get("pid"))
    filetime_ordering_valid = (
        len(lineage_edges) == 4 and
        all(isinstance(parent, dict) and isinstance(child, dict) and
            type(parent.get("create_time_100ns")) is int and
            type(child.get("create_time_100ns")) is int and
            child.get("create_time_100ns") >=
                parent.get("create_time_100ns")
            for parent, child in lineage_edges))
    exact_target_closure = (
        observed_rows_are_four_unique_generations and
        isinstance(target_identity, dict) and
        type(target_identity.get("pid")) is int and
        type(target_identity.get("create_time_100ns")) is int and
        isinstance(root_identity, dict) and
        type(root_identity.get("pid")) is int and
        type(root_identity.get("create_time_100ns")) is int and
        root_identity.get("pid") == root_launch_identity.get("pid") and
        root_identity.get("create_time_100ns") ==
            root_launch_identity.get("create_time_100ns") and
        isinstance(target_row, dict) and
        target_row.get("ppid") == root_identity.get("pid") and
        orphan_row.get("ppid") == target_identity.get("pid") and
        len(observed_by_pid) == 4 and
        filetime_ordering_valid and
        reachable_descendants == set(observed_by_pid))
    generation_checks = confirmation.get("target_generation_checks", [])
    checked_generations = {
        (item.get("pid"), item.get("expected_create_time_100ns"))
        for item in generation_checks if isinstance(item, dict)
    }
    already_absent_rows = confirmation.get("plan", {}).get("already_absent", [])
    already_absent_generations = {
        (item.get("pid"), item.get("create_time_100ns"))
        for item in already_absent_rows if isinstance(item, dict)
    }
    planned_observed = plan.get("observed_generations", [])
    planned_observed_generations = {
        (item.get("pid"), item.get("create_time_100ns"))
        for item in planned_observed if isinstance(item, dict)
    }
    planned_targets = plan.get("targets", [])
    planned_target_generations = {
        (item.get("pid"), item.get("create_time_100ns"))
        for item in planned_targets if isinstance(item, dict)
    }
    signal_attempts = cleanup.get("signal_attempts", [])
    signal_generations = {
        (item.get("identity", {}).get("pid"),
         item.get("identity", {}).get("create_time_100ns"))
        for item in signal_attempts if isinstance(item, dict)
    }
    all_absent = (
        observed_rows_are_four_unique_generations and
        len(expected_generations) == 4 and
        isinstance(generation_checks, list) and len(generation_checks) == 4 and
        all(isinstance(item, dict) and
            type(item.get("pid")) is int and
            type(item.get("expected_create_time_100ns")) is int
            for item in generation_checks) and
        len(checked_generations) == 4 and
        isinstance(already_absent_rows, list) and len(already_absent_rows) == 4 and
        len(already_absent_generations) == 4 and
        checked_generations == expected_generations and
        already_absent_generations == expected_generations and
        all(item.get("pid_absent") is True and
            item.get("observed_create_time_100ns") is None
            for item in generation_checks) and
        isinstance(planned_observed, list) and len(planned_observed) == 4 and
        planned_observed_generations == expected_generations and
        isinstance(planned_targets, list) and len(planned_targets) == 4 and
        planned_target_generations == expected_generations and
        isinstance(signal_attempts, list) and len(signal_attempts) == 4 and
        signal_generations == expected_generations and
        all(isinstance(item, dict) and
            isinstance(item.get("identity"), dict) and
            item.get("receipt", {}).get("identity") == item.get("identity") and
            item.get("receipt", {}).get("complete") is True and
            item.get("receipt", {}).get("signal_sent") is True and
            item.get("receipt", {}).get("wait_confirmed") is True and
            item.get("receipt", {}).get(
                "post_table_same_generation_present") is False and
            item.get("receipt", {}).get("post_table_reused_pid_ticks") is None
            for item in signal_attempts))
    closed_generations = {
        (item.get("pid"), item.get("create_time_100ns"))
        for item in handle_close.get("closed_owned_handles", [])
        if isinstance(item, dict)
    }
    assert_true(phase.get("stop_reason") == "process_tree_monitor_incomplete" and
                phase.get("stderr", {}).get("bytes") == 0 and
                phase.get("exit_code") == 15 and
                phase.get("formal_t2_accepted") is not True and
                termination.get("complete") is False and
                termination.get("verified") is False and
                handle_close.get("complete") is True and
                final_audit.get("complete") is False and
                has_expected_error(final_audit.get("errors")) and
                unbound_audit.get("complete") is False and
                has_expected_error(unbound_audit.get("errors")) and
                cleanup.get("complete") is True and
                cleanup.get("plan", {}).get("complete") is True and
                cleanup.get("plan", {}).get("errors") == [] and
                confirmation.get("complete") is True and
                confirmation.get("errors") == [] and
                confirmation.get("snapshot", {}).get("complete") is True and
                confirmation.get("target_process_ids_absent") is True and
                all_absent and expected_generations <= closed_generations and
                cleanup.get("plan", {}).get("unresolved") == [] and
                final_audit.get("residual_descendant_processes") == [] and
                final_audit.get("root_exit_confirmed") is True and
                final_audit.get("snapshot", {}).get("complete") is True and
                global_heavy_audit.get("complete") is True and
                global_heavy_audit.get("errors") == [] and
                global_heavy_audit.get("native_heavy_identities") == [] and
                global_heavy_audit.get("controller_processes") == [] and
                global_heavy_audit.get("processes") == [] and
                unbound_audit.get("residual_observed_generations") == [] and
                unbound_audit.get("orphan_descendants") == [] and
                termination.get("post_cleanup_audit", {}).get(
                    "residual_descendant_count") == 0 and
                any(item.get("pid") == orphan_row["pid"] and
                    item.get("create_time_100ns") == orphan_row["create_time_100ns"]
                    for item in handle_close.get("closed_owned_handles", [])),
                "failed-open orphan control did not remain explicit NO-GO with exact cleanup and no residual identities")
    assert_true(exact_target_closure,
                "failed-open observed generations are not the exact four-row descendant closure rooted at the target")
    return {
        "schema": "vnext-t2-r20-unbound-open-denial-cleanup-r9",
        "orphan_identity": {"pid": orphan_row["pid"],
                            "create_time_100ns": orphan_row["create_time_100ns"]},
        "sample_retry": False,
        "three_post_failure_complete_snapshots_with_target_present": True,
        "discarded_metric_credit_bytes": discarded.get("credited_rss_bytes"),
        "discarded_exit_credit": discarded.get("exit_code_credit_issued"),
        "cleanup_plan_complete": plan.get("complete"),
        "exact_signal_wait_confirmed": True,
        "orphan_handle_closed_by_identity": {
            "pid": orphan_row["pid"],
            "create_time_100ns": orphan_row["create_time_100ns"],
        },
        "post_cleanup_confirmation": cleanup.get("post_cleanup_confirmation"),
        "phase_stop_reason": phase.get("stop_reason"),
        "phase_exit_code": phase.get("exit_code"),
        "termination_complete": termination.get("complete"),
        "final_audit_complete": final_audit.get("complete"),
        "expected_fail_closed_error": expected_error,
        "all_observed_generations_absent": bool(all_absent),
        "observed_generation_count": len(expected_generations),
        "absence_check_count": len(generation_checks),
        "exact_target_descendant_closure": exact_target_closure,
        "filetime_ordering_valid_for_each_closure_edge":
            filetime_ordering_valid,
        "per_generation_signal_identity_and_post_table_receipts": True,
        "all_observed_generation_handles_closed":
            expected_generations <= closed_generations,
        "final_snapshot_complete": True,
        "global_heavy_audit_complete_empty": True,
        "final_residual_descendants":
            final_audit.get("residual_descendant_processes"),
        "formal_t2_accepted": False,
        "handle_close_complete": True,
    }


def run_probe_to_receipt(receipt_dir: Path) -> int:
    if os.name != "nt":
        print(json.dumps({"complete": False, "reason": "Windows host required"}),
              flush=True)
        return 1
    if receipt_dir.exists():
        raise RuntimeError(f"R20 preprobe evidence already exists: {receipt_dir}")
    receipt_dir.mkdir(parents=True, exist_ok=False)
    before = source_pins()
    try:
        result = run_openprocess_race_preprobe(load_controller())
        code = 0
    except Exception as error:
        result = {"schema": "vnext-t2-r20-openprocess-exit-race-preprobe-r1",
                  "complete": False, "formal_t2_accepted": False,
                  "exception_type": type(error).__name__, "message": str(error)}
        code = 1
    after = source_pins()
    result["source_pins_before"] = before
    result["source_pins_after"] = after
    result["source_pins_stable"] = before == after
    if before != after:
        result["complete"] = False
        code = 1
    write_json(receipt_dir / "command_argv.json", {
        "kind": "python_only_openprocess_exit_race_preprobe",
        "argv": exact_launcher_argv(), "cwd": str(Path.cwd()),
        "source_pins_before": before, "source_pins_after": after,
        "julia_started": False, "formal_t2_accepted": False,
    })
    write_json(receipt_dir / "stdout.raw", result)
    (receipt_dir / "stderr.raw").write_bytes(b"")
    write_json(receipt_dir / "exit_code.json", {
        "exit_code": code, "julia_started": False,
        "formal_t2_accepted": False,
        "source_pins_after": after,
        "status": "pass_python_only" if code == 0 else "fail",
    })
    print(json.dumps(result, sort_keys=True), flush=True)
    return code


def run(output: Path) -> int:
    if os.name != "nt":
        raise RuntimeError("R20 host smoke requires the pinned Windows process APIs")
    output.relative_to(ROOT)
    probe_dir = output / "openprocess_race_preprobe"
    if not probe_dir.is_dir() or {path.name for path in output.iterdir()} != {
            "openprocess_race_preprobe"}:
        raise RuntimeError(
            "R20 full smoke requires a separate successful preprobe and an otherwise empty evidence leaf")
    probe_payload = json.loads((probe_dir / "stdout.raw").read_text(encoding="utf-8"))
    probe_command = json.loads((probe_dir / "command_argv.json").read_text(encoding="utf-8"))
    probe_exit = json.loads((probe_dir / "exit_code.json").read_text(encoding="utf-8"))
    pins_before = source_pins()
    assert_true(probe_payload.get("complete") is True and
                probe_payload.get("post_exit_pid_absent_from_spi") is True and
                probe_payload.get("final_pid_absent_from_spi") is True and
                probe_exit.get("exit_code") == 0 and
                probe_payload.get("source_pins_before") == pins_before and
                probe_payload.get("source_pins_after") == pins_before and
                probe_command.get("source_pins_before") == pins_before and
                probe_command.get("source_pins_after") == pins_before,
                "R20 preprobe is missing, failed, or pinned to different source bytes")
    module = load_controller()
    common = {
        "timeout_seconds": 10.0,
        "working_set_limit_bytes": 2_147_483_648,
        "environment": os.environ.copy(),
    }
    terminal_fixture: dict[str, Any] = {
        "schema": "vnext-t2-r20-terminal-race-scheduling-fixture-r1",
        "sampler_hook": "_r20_native_sample",
        "second_sample_hook_entered": False,
        "child_wait_natural_exit_code": None,
        "original_native_sampler_called_after_wait": False,
        "sampler_replaced_only_for_natural_phase": True,
    }
    payload: dict[str, Any] = {
        "schema": "vnext-t2-r20-native-monitor-host-smoke-r9",
        "formal_t2_accepted": False, "julia_started": False,
        "host_identity": list(module._R23_TABLE.WINDOWS_BUILD_PIN),
        "openprocess_race_preprobe": probe_payload,
        "source_pins_before": pins_before,
    }
    exit_code = 1
    try:
        natural_output = output / "natural_python_child"
        original_sample = module._r20_native_sample

        def scheduled_natural_sample(process: Any, registry: Any,
                                     root_identity: Any, previous: Any, *,
                                     sample_index: int, elapsed: float,
                                     deadline_monotonic: float) -> dict[str, Any]:
            if sample_index == 2:
                terminal_fixture["second_sample_hook_entered"] = True
                terminal_fixture["child_wait_natural_exit_code"] = process.wait(timeout=4.0)
                terminal_fixture["original_native_sampler_called_after_wait"] = True
            return original_sample(process, registry, root_identity, previous,
                                   sample_index=sample_index, elapsed=elapsed,
                                   deadline_monotonic=deadline_monotonic)

        module._r20_native_sample = scheduled_natural_sample
        natural = module.run_phase(
            "r20_exact_python_natural_probe",
            [sys.executable, "-B", "-c", "import time; time.sleep(0.8)"],
            natural_output, **common)
        module._r20_native_sample = original_sample
        terminal_fixture["sampler_restored_after_natural_phase"] = \
            module._r20_native_sample is original_sample

        timeout = module.run_phase(
            "r20_exact_python_timeout_probe",
            [sys.executable, "-B", "-c", "import time; time.sleep(15)"],
            output / "timed_python_child", timeout_seconds=1.0,
            working_set_limit_bytes=common["working_set_limit_bytes"],
            environment=common["environment"])

        race_dir = output / "source_snapshot_handle_race"
        race_dir.mkdir(parents=False, exist_ok=False)
        race_state, _ = install_r20_race_hooks(
            module, race_dir, launch_orphan=False,
            require_candidate_pid_after_baseline=True,
            wait_for_root_release=True)
        race_command = smoke_child_command(
            phase_dir=race_dir, launch_orphan=False, root_seconds=10.0,
            require_candidate_pid_after_baseline=True,
            wait_for_root_release=True)
        race_phase = module.run_phase(
            "r20_disappearing_descendant_before_handle_open", race_command,
            race_dir / "phase", timeout_seconds=20.0,
            working_set_limit_bytes=common["working_set_limit_bytes"],
            environment=common["environment"])
        race_state["restore"]()
        payload["race_debug"] = {
            key: value for key, value in race_state.items()
            if key not in {"restore", "post_failure_snapshots"}}
        payload["race_debug"]["post_failure_snapshot_count"] = len(
            race_state.get("post_failure_snapshots", []))
        payload["race_phase"] = race_phase
        source_race = check_race_phase(module, race_phase, race_state)
        source_race["phase"] = race_phase

        orphan_dir = output / "unbound_orphan_cleanup"
        orphan_dir.mkdir(parents=False, exist_ok=False)
        orphan_state, _ = install_r20_race_hooks(
            module, orphan_dir, launch_orphan=True, inject_open_denial=True,
            require_candidate_pid_after_baseline=False)
        orphan_command = smoke_child_command(
            phase_dir=orphan_dir, launch_orphan=True, root_seconds=30.0,
            target_seconds=5.0,
            require_candidate_pid_after_baseline=False)
        orphan_phase = module.run_phase(
            "r20_failed_open_orphan_cleanup", orphan_command,
            orphan_dir / "phase", timeout_seconds=20.0,
            working_set_limit_bytes=common["working_set_limit_bytes"],
            environment=common["environment"])
        orphan_state["restore"]()
        orphan_cleanup = check_orphan_cleanup_phase(module, orphan_phase, orphan_state)
        orphan_cleanup["phase"] = orphan_phase

        assert_true(terminal_fixture.get("second_sample_hook_entered") is True and
                    terminal_fixture.get("child_wait_natural_exit_code") == 0 and
                    terminal_fixture.get("original_native_sampler_called_after_wait") is True and
                    terminal_fixture.get("sampler_hook") == "_r20_native_sample",
                    "R20 natural terminal-race scheduling receipt is incomplete")
        assert_true(natural.get("stop_reason") == "natural_exit" and
                    natural.get("exit_code") == 0 and
                    natural.get("stderr", {}).get("bytes") == 0 and
                    natural.get("handle_close_receipt", {}).get("complete") is True and
                    natural.get("final_process_tree_audit", {}).get("complete") is True and
                    natural.get("final_process_tree_audit", {}).get(
                        "residual_descendant_processes") == [],
                    "R20 natural child phase did not finish with a clean exact audit")
        assert_true(timeout.get("stop_reason") == "phase_wall_timeout" and
                    timeout.get("exit_code") == 15 and
                    timeout.get("stderr", {}).get("bytes") == 0 and
                    timeout.get("termination_receipt", {}).get("verified") is True and
                    timeout.get("handle_close_receipt", {}).get("complete") is True and
                    timeout.get("final_process_tree_audit", {}).get("root_exit_confirmed") is True and
                    timeout.get("final_process_tree_audit", {}).get(
                        "residual_descendant_processes") == [],
                    "R20 timed child was not exactly terminated and audited")
        payload.update({
            "runner": file_receipt(RUNNER),
            "controller": module.file_receipt(CONTROLLER),
            "native_process_table": module.file_receipt(NATIVE_TABLE),
            "supervisor": module.file_receipt(SUPERVISOR),
            "test_suite_source": module.file_receipt(TEST_SUITE),
            "terminal_race_fixture": terminal_fixture,
            "natural_phase": natural,
            "timeout_phase": timeout,
            "source_snapshot_handle_race": source_race,
            "unbound_orphan_cleanup": orphan_cleanup,
        })
        exit_code = 0
    except Exception as error:
        payload["smoke_assertion"] = {
            "type": type(error).__name__, "message": str(error)}
        exit_code = 1

    payload["formal_t2_accepted"] = False
    payload["julia_started"] = False
    pins_after = source_pins()
    payload["source_pins_after"] = pins_after
    payload["source_pins_stable"] = pins_before == pins_after
    if pins_before != pins_after:
        payload["smoke_assertion"] = {
            "type": "RuntimeError",
            "message": "runner/controller/helper source hashes changed during smoke"}
        exit_code = 1
    write_json(output / "command_argv.json", {
        "kind": "python_only_host_supervisor_smoke",
        "argv": exact_launcher_argv(), "cwd": str(Path.cwd()),
        "source_pins_before": pins_before, "source_pins_after": pins_after,
        "controller_sha256": file_receipt(CONTROLLER)["sha256"],
        "julia_started": False, "formal_t2_accepted": False,
    })
    write_json(output / "stdout.raw", payload)
    (output / "stderr.raw").write_bytes(b"")
    write_json(output / "exit_code.json", {
        "exit_code": exit_code, "julia_started": False,
        "formal_t2_accepted": False,
        "source_pins_after": pins_after,
        "status": "pass_python_only" if exit_code == 0 else "fail",
    })
    print(json.dumps(payload, sort_keys=True), flush=True)
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--probe-only", action="store_true")
    args = parser.parse_args()
    if args.probe_only:
        if args.output is None:
            parser.error("receipt output is required with --probe-only")
        return run_probe_to_receipt(args.output.resolve())
    if args.output is None:
        parser.error("output is required unless --probe-only is selected")
    return run(args.output.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
