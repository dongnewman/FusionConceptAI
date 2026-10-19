"""Static and controlled failure-path checks; performs no numerical solve."""

from __future__ import annotations

import hashlib
import inspect
import importlib.util
import ctypes
import json
import os
import runpy
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch
from ctypes import wintypes

import psutil

import compare_independent_raw as comparator
import run_serial_acceptance as supervisor


_ROOT = Path(__file__).resolve().parents[3]
_BOUNDED_CHECK_PATH = _ROOT / "scripts" / "run_bounded_check.py"
_BOUNDED_CHECK_SPEC = importlib.util.spec_from_file_location(
    "workspace_run_bounded_check", _BOUNDED_CHECK_PATH)
if _BOUNDED_CHECK_SPEC is None or _BOUNDED_CHECK_SPEC.loader is None:
    raise RuntimeError("bounded checker module could not be loaded")
bounded_check = importlib.util.module_from_spec(_BOUNDED_CHECK_SPEC)
_BOUNDED_CHECK_SPEC.loader.exec_module(bounded_check)


class ResourceAuditCoverageTests(unittest.TestCase):
    def _coverage(self, temp_dir: str, rows: list[dict], created: int | None,
                  finished: int | None) -> dict:
        path = Path(temp_dir) / "audit.jsonl"
        path.write_text("".join(json.dumps(row) + "\n" for row in rows),
                        encoding="utf-8")
        return bounded_check.resource_audit_coverage(path, created, finished)

    def test_monotonic_coverage_ignores_utc_clock_step(self) -> None:
        rows = [
            {"sampled_at_utc": "2026-10-09T10:00:00+00:00",
             "sampled_at_monotonic_start_ns": 10_000_000,
             "sampled_at_monotonic_end_ns": 20_000_000},
            {"sampled_at_utc": "2026-10-09T09:59:58+00:00",
             "sampled_at_monotonic_start_ns": 300_000_000,
             "sampled_at_monotonic_end_ns": 310_000_000},
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            coverage = self._coverage(temp_dir, rows, 0, 400_000_000)
        self.assertTrue(coverage["complete"], coverage)
        self.assertAlmostEqual(coverage["max_internal_gap_seconds"], .3)
        self.assertEqual(coverage["clock"], "monotonic_ns")

    def test_slow_actual_sample_operation_fails_coverage(self) -> None:
        rows = [{"sampled_at_utc": "2026-10-09T10:00:00+00:00",
                 "sampled_at_monotonic_start_ns": 10_000_000,
                 "sampled_at_monotonic_end_ns": 600_000_000}]
        with tempfile.TemporaryDirectory() as temp_dir:
            coverage = self._coverage(temp_dir, rows, 0, 700_000_000)
        self.assertFalse(coverage["complete"], coverage)
        self.assertGreater(coverage["max_sample_operation_seconds"], .5)

    def test_observation_intervals_include_sample_operation_boundaries(self) -> None:
        cases = (
            # A .3 s head gap plus a .3 s first sample cannot credit .6 s.
            ([{"sampled_at_monotonic_start_ns": 300_000_000,
              "sampled_at_monotonic_end_ns": 600_000_000}],
             0, 700_000_000, "head_gap_seconds"),
            # .4 s sample + .4 s wait is an .8 s completed-observation span.
            ([{"sampled_at_monotonic_start_ns": 0,
              "sampled_at_monotonic_end_ns": 400_000_000},
             {"sampled_at_monotonic_start_ns": 400_000_000,
              "sampled_at_monotonic_end_ns": 800_000_000}],
             0, 900_000_000, "max_internal_gap_seconds"),
            # Final sample duration is included in the end tail interval.
            ([{"sampled_at_monotonic_start_ns": 0,
              "sampled_at_monotonic_end_ns": 300_000_000}],
             0, 600_000_000, "tail_gap_seconds"),
        )
        for rows, created, finished, field in cases:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temp_dir:
                coverage = self._coverage(temp_dir, rows, created, finished)
                self.assertFalse(coverage["complete"], coverage)
                self.assertGreater(coverage[field], .5)

    def test_sample_before_creation_boundary_fails_closed(self) -> None:
        rows = [{"sampled_at_monotonic_start_ns": 10_000_000,
                 "sampled_at_monotonic_end_ns": 100_000_000}]
        with tempfile.TemporaryDirectory() as temp_dir:
            coverage = self._coverage(temp_dir, rows, 20_000_000, 200_000_000)
        self.assertFalse(coverage["complete"], coverage)
        self.assertIn("outside process boundaries", coverage["error"])

    def test_overlapping_sample_operations_fail_closed(self) -> None:
        rows = [
            {"sampled_at_monotonic_start_ns": 10_000_000,
             "sampled_at_monotonic_end_ns": 300_000_000},
            {"sampled_at_monotonic_start_ns": 200_000_000,
             "sampled_at_monotonic_end_ns": 210_000_000},
            {"sampled_at_monotonic_start_ns": 600_000_000,
             "sampled_at_monotonic_end_ns": 610_000_000},
        ]
        with tempfile.TemporaryDirectory() as temp_dir:
            coverage = self._coverage(temp_dir, rows, 0, 700_000_000)
        self.assertFalse(coverage["complete"], coverage)
        self.assertIn("overlap", coverage["error"])

    def test_old_utc_only_samples_receive_no_coverage_credit(self) -> None:
        rows = [{"sampled_at_utc": "2026-10-09T10:00:00+00:00"}]
        with tempfile.TemporaryDirectory() as temp_dir:
            coverage = self._coverage(temp_dir, rows, 0, 10_000_000)
        self.assertFalse(coverage["complete"], coverage)
        self.assertIn("sampled_at_monotonic_start_ns", coverage["error"])


class BoundedAuditWriterTests(unittest.TestCase):
    def test_short_file_write_is_rejected(self) -> None:
        class ShortWriter:
            def write(self, line: str) -> int:
                return len(line) - 1

            def flush(self) -> None:
                raise AssertionError("short write must fail before flush")

        with self.assertRaisesRegex(OSError, "short process-tree audit write"):
            supervisor._write_audit_line(ShortWriter(), "row\n")

    def test_blocked_disk_writer_does_not_block_sampling_enqueue(self) -> None:
        entered = threading.Event()
        release = threading.Event()
        real_write = supervisor._write_audit_line

        def blocked_write(audit, line: str) -> None:
            entered.set()
            if not release.wait(3.0):
                raise TimeoutError("test writer release timed out")
            real_write(audit, line)

        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "audit.jsonl"
            with patch.object(supervisor, "_write_audit_line", blocked_write):
                writer = supervisor._BoundedAuditWriter(path, capacity=2)
                writer.enqueue('{"row":1}\n')
                self.assertTrue(entered.wait(1.0))
                started = time.perf_counter()
                writer.enqueue('{"row":2}\n')
                elapsed = time.perf_counter() - started
                release.set()
                status = writer.finish()
            self.assertLess(elapsed, 0.1)
            self.assertTrue(status["complete"], status)
            self.assertEqual(path.read_text(encoding="utf-8"),
                             '{"row":1}\n{"row":2}\n')

    def test_full_bounded_queue_fails_closed_and_still_joins(self) -> None:
        entered = threading.Event()
        release = threading.Event()
        real_write = supervisor._write_audit_line

        def blocked_write(audit, line: str) -> None:
            entered.set()
            if not release.wait(3.0):
                raise TimeoutError("test writer release timed out")
            real_write(audit, line)

        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "audit.jsonl"
            with patch.object(supervisor, "_write_audit_line", blocked_write):
                writer = supervisor._BoundedAuditWriter(path, capacity=1)
                writer.enqueue('{"row":1}\n')
                self.assertTrue(entered.wait(1.0))
                writer.enqueue('{"row":2}\n')
                with self.assertRaises(supervisor._AuditWriterError) as caught:
                    writer.enqueue('{"row":3}\n')
                self.assertEqual(caught.exception.reason,
                                 "audit_writer_queue_full")
                release.set()
                status = writer.finish()
            self.assertFalse(status["complete"], status)
            self.assertEqual(status["error"]["reason"],
                             "audit_writer_queue_full")
            self.assertFalse(writer._thread.is_alive())

    def test_write_error_is_reported_after_worker_drain_and_join(self) -> None:
        def failing_write(_audit, _line: str) -> None:
            raise OSError("controlled audit disk failure")

        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "audit.jsonl"
            with patch.object(supervisor, "_write_audit_line", failing_write):
                writer = supervisor._BoundedAuditWriter(path, capacity=2)
                writer.enqueue('{"row":1}\n')
                status = writer.finish()
            self.assertFalse(status["complete"], status)
            self.assertEqual(status["error"]["reason"],
                             "audit_writer_write_failed")
            self.assertFalse(writer._thread.is_alive())

    def test_finish_flushes_final_queued_row_before_return(self) -> None:
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "audit.jsonl"
            writer = supervisor._BoundedAuditWriter(path, capacity=2)
            writer.enqueue('{"final":true}\n')
            status = writer.finish()
            self.assertTrue(status["complete"], status)
            self.assertEqual(path.read_text(encoding="utf-8"),
                             '{"final":true}\n')

    def test_finish_timeout_is_bounded_and_never_reports_complete(self) -> None:
        entered = threading.Event()
        release = threading.Event()

        def blocked_write(_audit, _line: str) -> None:
            entered.set()
            release.wait(3.0)

        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "audit.jsonl"
            with patch.object(supervisor, "_write_audit_line", blocked_write):
                writer = supervisor._BoundedAuditWriter(path, capacity=1)
                writer.enqueue('{"row":1}\n')
                self.assertTrue(entered.wait(1.0))
                started = time.perf_counter()
                status = writer.finish(timeout_seconds=0.01)
                elapsed = time.perf_counter() - started
                release.set()
                writer._thread.join(1.0)
            self.assertLess(elapsed, 0.5)
            self.assertFalse(status["complete"], status)
            self.assertEqual(status["error"]["reason"],
                             "audit_writer_finish_timeout")
            self.assertFalse(writer._thread.is_alive())


class ProcessAccountingNegativeTests(unittest.TestCase):
    ROOT_PID = 101
    CHILD_PID = 202
    ROOT_GENERATION = 1.0
    CHILD_GENERATION = 2.0

    @staticmethod
    def _job_inventory(pids: tuple[int, ...], *, complete: bool = True,
                       assigned_count: int | None = None,
                       returned_count: int | None = None,
                       reason: str | None = None):
        assigned = len(pids) if assigned_count is None else assigned_count
        returned = len(pids) if returned_count is None else returned_count
        return supervisor.JobPidInventory(
            complete, pids, assigned, returned, reason)

    @staticmethod
    def _snapshot_reader(sequence):
        calls = 0

        def read_inventory():
            nonlocal calls
            current = sequence[min(calls, len(sequence) - 1)]
            calls += 1
            return current

        return read_inventory

    @staticmethod
    def _process_sample(pid: int, generation: float, rss: int,
                        closed: list[int] | None = None,
                        signaled: bool = False):
        return supervisor.ProcessSample(
            pid, generation, rss,
            signal_check=lambda: signaled,
            close_handle=(None if closed is None else
                          lambda: closed.append(pid)))

    @staticmethod
    def _fake_owned_process_handle(pid: int, raw_handle: int,
                                   close_results: list[bool]):
        calls: list[int] = []

        class FakeKernel:
            def __init__(self) -> None:
                self.results = iter(close_results)

            def CloseHandle(self, handle: int) -> bool:
                calls.append(handle)
                try:
                    result = next(self.results)
                except StopIteration:
                    result = False
                if not result:
                    ctypes.set_last_error(5)
                return result

        process_handle = object.__new__(
            supervisor._WindowsProcessSampleHandle)
        process_handle.pid = pid
        process_handle.owns_handle = True
        process_handle.handle = raw_handle
        process_handle._kernel32 = FakeKernel()
        process_handle.close_attempts = 0
        process_handle.pending_close_error = None
        return process_handle, calls

    def test_access_denied_child_has_no_partial_rss_credit(self) -> None:
        class Process:
            def __init__(self, pid: int, fail: bool = False) -> None:
                self.pid = pid
                self.fail = fail

            def as_dict(self, attrs=()):
                return {"pid": self.pid, "ppid": 1, "name": "test",
                        "exe": "test", "create_time": 1.0}

            def memory_info(self):
                if self.fail:
                    raise psutil.AccessDenied(pid=self.pid)
                return type("Memory", (), {"rss": 4096})()

        root = Process(101)
        inaccessible_child = Process(102, fail=True)
        with patch.object(supervisor, "_process_tree",
                          return_value=[root, inaccessible_child]):
            sample = supervisor._sample_process_tree(101, 1.0)
        self.assertFalse(sample["complete"])
        self.assertIsNone(sample["rss_total_bytes"])
        self.assertIsNone(sample["processes"][1]["rss_bytes"])

    def test_pid_generation_mismatch_has_no_rss_credit(self) -> None:
        class ReusedPid:
            def create_time(self):
                return 200.0

        with patch.object(supervisor.psutil, "Process", return_value=ReusedPid()):
            sample = supervisor._sample_process_tree(101, 100.0)
        self.assertFalse(sample["complete"])
        self.assertIsNone(sample["rss_total_bytes"])

    def test_proven_child_exit_retries_a_fresh_whole_snapshot(self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        child_generation = self.CHILD_GENERATION
        with_child = self._job_inventory((root_pid, child_pid))
        root_only = self._job_inventory((root_pid,))
        inventory_reader = self._snapshot_reader(
            (with_child, root_only, root_only, root_only, root_only))
        root_reads = 0
        child_reads = 0
        closed: list[int] = []

        def process_reader(pid: int):
            nonlocal root_reads, child_reads
            if pid == root_pid:
                root_reads += 1
                rss = 1024 if root_reads == 1 else 8192
                return self._process_sample(
                    pid, root_generation, rss, closed)
            self.assertEqual(pid, child_pid)
            child_reads += 1
            raise supervisor.ProcessGenerationExited(
                child_pid, child_generation)

        result = supervisor._sample_job_snapshot(
            inventory_reader, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=3)

        self.assertTrue(result["complete"])
        self.assertEqual(result["rss_total_bytes"], 8192)
        self.assertEqual(result["retry_count"], 1)
        self.assertEqual(root_reads, 2)
        self.assertEqual(child_reads, 1)
        self.assertEqual(len(closed), root_reads)

        # OpenProcess can lose a Job-listed child before any exact-generation
        # handle exists. Only a complete refreshed Job inventory can authorize
        # a whole-snapshot retry; it must not be represented as an exact exit.
        race_inventory = self._snapshot_reader(
            (with_child, root_only, root_only, root_only))
        race_reads: list[int] = []
        race_closed: list[int] = []
        race_root_reads = 0

        def openprocess_race_reader(pid: int):
            nonlocal race_root_reads
            race_reads.append(pid)
            if pid == root_pid:
                race_root_reads += 1
                rss = 1024 if race_root_reads == 1 else 8192
                return self._process_sample(
                    pid, root_generation, rss, race_closed)
            self.assertEqual(pid, child_pid)
            raise supervisor.JobListedPidVanishedBeforeOpen(pid)

        race_result = supervisor._sample_job_snapshot(
            race_inventory, openprocess_race_reader,
            expected_root=(root_pid, root_generation), max_attempts=3)
        self.assertTrue(race_result["complete"])
        self.assertEqual(race_result["rss_total_bytes"], 8192)
        self.assertEqual(race_result["retry_count"], 1)
        self.assertEqual(race_result["attempts"], 2)
        self.assertEqual(race_reads, [root_pid, child_pid, root_pid])
        self.assertEqual(race_closed, [root_pid, root_pid])
        race_trace = race_result["attempt_trace"][0]
        self.assertEqual(
            race_trace["reason"],
            "job_inventory_refreshed_after_openprocess_race")
        self.assertEqual(race_trace["evidence"], {
            "kind": "complete_job_inventory_refresh",
            "root_member_present": True,
            "vanished_member_absent": True,
        })
        self.assertNotIn("creation_time_utc", race_trace["evidence"])
        self.assertNotIn("process_generation", race_trace["evidence"])

        # Every retry starts over from fresh membership and discards that
        # attempt's RSS. Exhaustion remains incomplete with no partial credit.
        exhausted_inventory = self._snapshot_reader(
            (with_child, root_only, with_child, root_only))
        exhausted_reads: list[int] = []
        exhausted_closed: list[int] = []
        exhausted_root_reads = 0

        def exhausted_race_reader(pid: int):
            nonlocal exhausted_root_reads
            exhausted_reads.append(pid)
            if pid == root_pid:
                exhausted_root_reads += 1
                return self._process_sample(
                    pid, root_generation, 4096 * exhausted_root_reads,
                    exhausted_closed)
            self.assertEqual(pid, child_pid)
            raise supervisor.JobListedPidVanishedBeforeOpen(pid)

        exhausted_result = supervisor._sample_job_snapshot(
            exhausted_inventory, exhausted_race_reader,
            expected_root=(root_pid, root_generation), max_attempts=2)
        self.assertFalse(exhausted_result["complete"])
        self.assertIsNone(exhausted_result["rss_total_bytes"])
        self.assertEqual(exhausted_result["retry_count"], 2)
        self.assertEqual(exhausted_result["attempts"], 2)
        self.assertEqual(exhausted_result["reason"],
                         "process_snapshot_retry_exhausted")
        self.assertEqual(len(exhausted_result["attempt_trace"]), 2)
        self.assertEqual(exhausted_closed, [root_pid, root_pid])

    def test_reused_descendant_pid_with_new_generation_fails_closed(self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        child_generation = self.CHILD_GENERATION
        with_child = self._job_inventory((root_pid, child_pid))
        root_only = self._job_inventory((root_pid,))
        inventory_reader = self._snapshot_reader(
            (with_child, root_only, with_child, with_child))
        child_reads = 0

        def process_reader(pid: int):
            nonlocal child_reads
            if pid == root_pid:
                return self._process_sample(pid, root_generation, 4096)
            self.assertEqual(pid, child_pid)
            child_reads += 1
            if child_reads == 1:
                raise supervisor.ProcessGenerationExited(
                    child_pid, child_generation)
            raise supervisor.ProcessGenerationMismatch(
                child_pid, child_generation, child_generation + 1.0,
                "pid_reused")

        result = supervisor._sample_job_snapshot(
            inventory_reader, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=3)

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["retry_count"], 1)
        self.assertEqual(child_reads, 2)

    def test_unproven_process_disappearance_gets_no_retry_or_rss_credit(self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        with_child = self._job_inventory((root_pid, child_pid))
        root_only = self._job_inventory((root_pid,))
        child_only = self._job_inventory((child_pid,))
        empty = self._job_inventory(())

        def run_case(inventories, target_pid: int, error_factory,
                     expected_root=(root_pid, root_generation),
                     max_attempts: int = 3, root_sample=None):
            inventory_calls = 0
            process_reads: list[int] = []
            closed: list[int] = []

            def inventory_reader():
                nonlocal inventory_calls
                item = inventories[min(inventory_calls, len(inventories) - 1)]
                inventory_calls += 1
                if isinstance(item, BaseException):
                    raise item
                return item

            def process_reader(pid: int):
                process_reads.append(pid)
                if pid == target_pid:
                    raise error_factory(pid)
                if pid == root_pid and root_sample is not None:
                    return root_sample
                generation = (root_generation if pid == root_pid
                              else self.CHILD_GENERATION)
                return self._process_sample(pid, generation, 4096, closed)

            result = supervisor._sample_job_snapshot(
                inventory_reader, process_reader,
                expected_root=expected_root, max_attempts=max_attempts)
            return result, inventory_calls, process_reads, closed

        # A plain NoSuchProcess may come from after OpenProcess (for example,
        # a resource query), so it cannot enter the pre-open inventory retry.
        result, inventory_calls, process_reads, _ = run_case(
            (with_child, root_only), child_pid,
            lambda pid: psutil.NoSuchProcess(pid))

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["retry_count"], 0)
        self.assertEqual(process_reads, [root_pid, child_pid])
        self.assertEqual(inventory_calls, 1)
        self.assertEqual(result["reason"], "unproven_process_disappearance")

        failures = (
            ("pid_still_in_job_or_reused", (with_child, with_child),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             (root_pid, root_generation),
             "job_listed_pid_still_present_after_openprocess_race", 2),
            ("root_missing", (with_child, child_only),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             (root_pid, root_generation),
             "job_root_missing_during_openprocess_race_confirmation", 2),
            ("inventory_incomplete", (with_child,
             self._job_inventory((), complete=False, assigned_count=1,
                                 returned_count=0,
                                 reason="job_pid_inventory_incomplete")),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             (root_pid, root_generation), "job_pid_inventory_incomplete", 2),
            ("inventory_access_denied", (with_child,
             psutil.AccessDenied(pid=None)),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             (root_pid, root_generation), "job_inventory_access_denied", 2),
            ("error_pid_mismatch", (with_child,),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid + 1),
             (root_pid, root_generation), "process_open_race_pid_mismatch", 1),
            ("expected_root_unbound", (with_child,),
             child_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             None, "openprocess_race_root_binding_missing", 1),
            ("root_pid", (root_only, empty),
             root_pid, lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
             (root_pid, root_generation),
             "job_root_missing_during_openprocess_race_confirmation", 2),
        )
        for (label, inventories, target_pid, error_factory, expected_root,
             reason, expected_inventory_calls) in failures:
            with self.subTest(label=label):
                failed, calls, _, _ = run_case(
                    inventories, target_pid, error_factory, expected_root)
                self.assertFalse(failed["complete"])
                self.assertIsNone(failed["rss_total_bytes"])
                self.assertEqual(failed["retry_count"], 0)
                self.assertEqual(failed["attempts"], 1)
                self.assertEqual(failed["reason"], reason)
                self.assertEqual(calls, expected_inventory_calls)

        # An exact child sample already acquired before the OpenProcess race
        # must close successfully before retry; close failure keeps the exact
        # handle reference pending and blocks all credit.
        handle, close_calls = self._fake_owned_process_handle(
            root_pid, 0x5A53, [False, False])
        pending = supervisor._PENDING_PROCESS_SAMPLE_CLEANUP
        self.assertFalse(any(item is handle for item in pending))
        self.addCleanup(lambda: pending.remove(handle)
                        if any(item is handle for item in pending) else None)
        self.addCleanup(lambda: setattr(handle, "handle", None))
        root_handle_sample = supervisor.ProcessSample(
            root_pid, root_generation, 4096,
            signal_check=lambda: False, close_handle=handle.close)
        close_failure, close_inventory_calls, _, _ = run_case(
            (with_child, root_only), child_pid,
            lambda pid: supervisor.JobListedPidVanishedBeforeOpen(pid),
            root_sample=root_handle_sample)
        self.assertFalse(close_failure["complete"])
        self.assertIsNone(close_failure["rss_total_bytes"])
        self.assertEqual(close_failure["retry_count"], 0)
        self.assertEqual(close_failure["reason"],
                         "process_sample_handle_close_failed")
        self.assertEqual(close_failure["pending_sample_handle_count"], 1)
        self.assertEqual(close_inventory_calls, 2)
        self.assertEqual(close_calls, [0x5A53, 0x5A53])
        self.assertEqual(handle.handle, 0x5A53)
        self.assertTrue(any(item is handle for item in pending))
        receipt: dict = {}
        with self.assertRaisesRegex(
                RuntimeError, "exact process handles remain unclosed"):
            supervisor._require_no_pending_process_sample_handles(
                receipt, "test_openprocess_race_close")
        self.assertEqual(receipt["stop_reason"],
                         "process_sample_handle_close_unconfirmed")

    def test_persistent_access_denied_discards_partial_rss(self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        with_child = self._job_inventory((root_pid, child_pid))
        child_reads = 0
        closed: list[int] = []

        def process_reader(pid: int):
            nonlocal child_reads
            if pid == root_pid:
                return self._process_sample(pid, root_generation, 16384,
                                            closed)
            self.assertEqual(pid, child_pid)
            child_reads += 1
            raise psutil.AccessDenied(pid=child_pid)

        result = supervisor._sample_job_snapshot(
            lambda: with_child, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=3)

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["retry_count"], 0)
        self.assertEqual(child_reads, 1)
        self.assertEqual(closed, [root_pid])

    def test_incomplete_job_pid_inventory_fails_before_rss_sampling(self) -> None:
        root_pid = self.ROOT_PID
        root_generation = self.ROOT_GENERATION
        incomplete = self._job_inventory(
            (root_pid,), complete=False, assigned_count=2,
            returned_count=1, reason="short_pid_inventory")
        process_reads: list[int] = []

        def process_reader(pid: int):
            process_reads.append(pid)
            return self._process_sample(pid, root_generation, 4096)

        result = supervisor._sample_job_snapshot(
            lambda: incomplete, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=3)

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["retry_count"], 0)
        self.assertEqual(process_reads, [])

    def test_membership_change_between_complete_inventories_gets_no_credit(
            self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        child_generation = self.CHILD_GENERATION
        stable = self._job_inventory((root_pid, child_pid))
        changed = self._job_inventory((root_pid, child_pid, 303))
        inventory_reader = self._snapshot_reader(
            (stable, changed, changed))
        closed: list[int] = []

        def process_reader(pid: int):
            if pid == root_pid:
                return self._process_sample(pid, root_generation, 4096,
                                            closed)
            self.assertEqual(pid, child_pid)
            return self._process_sample(pid, child_generation, 2048, closed)

        result = supervisor._sample_job_snapshot(
            inventory_reader, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=1)

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["retry_count"], 0)
        self.assertEqual(sorted(closed), [root_pid, child_pid])

    def test_child_sample_close_retries_once_and_leaves_no_pending_handle(
            self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        child_generation = self.CHILD_GENERATION
        inventory = self._job_inventory((root_pid, child_pid))
        handle, close_calls = self._fake_owned_process_handle(
            child_pid, 0x5A51, [False, True])
        child_sample = supervisor.ProcessSample(
            child_pid, child_generation, 2048,
            close_handle=handle.close)

        def process_reader(pid: int):
            if pid == root_pid:
                return self._process_sample(pid, root_generation, 4096)
            self.assertEqual(pid, child_pid)
            return child_sample

        result = supervisor._sample_job_snapshot(
            lambda: inventory, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=1)

        self.assertTrue(result["complete"])
        self.assertEqual(result["rss_total_bytes"], 6144)
        self.assertEqual(close_calls, [0x5A51, 0x5A51])
        self.assertEqual(handle.close_attempts, 2)
        self.assertIsNone(handle.handle)
        self.assertIsNone(child_sample.close_handle)
        self.assertFalse(any(
            pending is handle
            for pending in supervisor._PENDING_PROCESS_SAMPLE_CLEANUP))

    def test_persistent_sample_close_failure_retains_handle_and_no_credit(
            self) -> None:
        root_pid = self.ROOT_PID
        child_pid = self.CHILD_PID
        root_generation = self.ROOT_GENERATION
        child_generation = self.CHILD_GENERATION
        inventory = self._job_inventory((root_pid, child_pid))
        handle, close_calls = self._fake_owned_process_handle(
            child_pid, 0x5A52, [False, False])
        close_callback = handle.close
        child_sample = supervisor.ProcessSample(
            child_pid, child_generation, 2048,
            close_handle=close_callback)

        def process_reader(pid: int):
            if pid == root_pid:
                return self._process_sample(pid, root_generation, 4096)
            self.assertEqual(pid, child_pid)
            return child_sample

        pending = supervisor._PENDING_PROCESS_SAMPLE_CLEANUP
        self.assertFalse(any(item is handle for item in pending))
        self.addCleanup(lambda: pending.remove(handle)
                        if any(item is handle for item in pending) else None)
        result = supervisor._sample_job_snapshot(
            lambda: inventory, process_reader,
            expected_root=(root_pid, root_generation), max_attempts=1)

        self.assertFalse(result["complete"])
        self.assertIsNone(result["rss_total_bytes"])
        self.assertEqual(result["reason"],
                         "process_sample_handle_close_failed")
        self.assertEqual(result["pending_sample_handle_count"], 1)
        self.assertEqual(close_calls, [0x5A52, 0x5A52])
        self.assertEqual(handle.close_attempts, 2)
        self.assertEqual(handle.handle, 0x5A52)
        self.assertIs(child_sample.close_handle, close_callback)
        self.assertTrue(any(item is handle for item in pending))
        receipt: dict = {}
        with self.assertRaisesRegex(
                RuntimeError, "exact process handles remain unclosed"):
            supervisor._require_no_pending_process_sample_handles(
                receipt, "test_persistent_close")
        self.assertEqual(receipt["stop_reason"],
                         "process_sample_handle_close_unconfirmed")
        self.assertTrue(receipt["pending_process_sample_handles"])

    def test_termination_uses_retained_exact_process_handle(self) -> None:
        class ExactHandle:
            pid = 101

            def __init__(self) -> None:
                self.killed = False
                self.waited = False

            def poll(self):
                return None if not self.killed else 94

            def kill(self):
                self.killed = True

            def wait(self, timeout: float):
                self.waited = True
                return 94

        process = ExactHandle()
        supervisor._terminate_fallback(process)
        self.assertTrue(process.killed)
        self.assertTrue(process.waited)


class BindingAndRunnerStaticTests(unittest.TestCase):
    def test_t2_sample151_raw_failure_input_is_preserved_without_credit(self) -> None:
        test_dir = Path(inspect.getsourcefile(supervisor)).resolve().parent
        repo_root = test_dir.parents[2]
        relative = (
            "runs/UP1-04A-VNEXT-T2/strict_pair_formal_r23_20260927_04/"
            "actual_formal_baseline/samples.jsonl")
        raw_path = repo_root.joinpath(*relative.split("/"))
        raw = raw_path.read_bytes()
        self.assertEqual(len(raw), 9_272_304)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),
                         "21e3a83817c6df7f3aac68214ef9f086a52d055e90cd82c01b7ffeeeee688b93")

        # Pin and parse the original bytes; do not reconstruct or normalize the
        # failed sample from its receipt or any later protocol projection.
        lines = raw.splitlines()
        self.assertGreaterEqual(len(lines), 151)
        line = lines[150]
        self.assertEqual(len(line), 338_312)
        self.assertEqual(hashlib.sha256(line).hexdigest(),
                         "f09ff591712fc54a1f6c672e88a71eb4944eeb9ec661f28da92ee1e7ce19f93d")
        sample = json.loads(line)
        self.assertEqual(sample["schema"],
                         "vnext-t2-process-tree-sample-r6-r23-membership-growth")
        self.assertEqual(sample["sample_index"], 151)
        self.assertIs(sample["sample_complete"], False)
        self.assertEqual(sample["sample_attempt_count"], 2)
        self.assertEqual(sample["native_monitor_handles_bound"], 3)
        self.assertEqual(sample["root_identity_match_count"], 0)
        self.assertEqual(sample["root_process_identity"], {
            "pid": 47796,
            "create_time_100ns": 134349467619452228,
            "create_time": 1790473161.9452229,
        })
        self.assertEqual(
            [item["type"] for item in sample["errors"]],
            ["ProcessTableError", "MonitorIncomplete"],
        )
        self.assertIn("exact handle acquisition/binding/liveness check failed",
                      sample["errors"][0]["message"])
        self.assertEqual(len(sample["membership_growth_records"]), 1)
        growth = sample["membership_growth_records"][0]
        self.assertEqual(growth["status"],
                         "strict_membership_growth_confirmed_retry_required")
        self.assertIs(growth["retry_started"], True)
        self.assertIs(growth["full_sample_completed_after_retry"], False)
        self.assertEqual(growth["rss_credit_bytes"], 0)
        self.assertIs(growth["exit_code_credit_issued"], False)
        observed_growth = growth["observed_generations"]
        self.assertEqual(len(observed_growth), 1)
        self.assertEqual(observed_growth[0], {
            "pid": 95908,
            "create_time_100ns": 134349468125090814,
            "ppid": 47796,
            "name": "git.exe",
        })
        self.assertEqual(len(sample["sample_handoff_recoveries"]), 1)
        handoff = sample["sample_handoff_recoveries"][0]
        self.assertEqual(handoff["status"],
                         "retry_exhausted_or_phase_deadline_monitor_incomplete")
        self.assertEqual(handoff["failure_stage"], "r20_exact_handle_open_or_bind")
        self.assertEqual(handoff["exact_handle_open_failure"], {
            "exception_type": "OSError",
            "message": "[WinError 87] 参数错误。",
            "pid": 100112,
            "stage": "r20_exact_handle_open_or_bind",
        })
        self.assertEqual(handoff["target_identity"], {
            "pid": 100112,
            "create_time_100ns": 134349468131055132,
        })
        self.assertEqual(handoff["whole_sample_attempt_index"], 2)
        self.assertEqual(handoff["rss_credit_bytes"], 0)
        self.assertIs(handoff["exit_code_credit_issued"], False)

    def test_shared_ad45_envelope_is_present_and_pinned(self) -> None:
        test_dir = Path(inspect.getsourcefile(supervisor)).resolve().parent
        repo_root = test_dir.parents[2]
        relative = (
            "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/"
            "fresh_candidate_binding_envelope_v1.json")
        envelope = repo_root.joinpath(*relative.split("/"))
        pins = supervisor._input_pins(test_dir, repo_root)
        self.assertTrue(envelope.is_file())
        self.assertEqual(
            pins.get(relative),
            "17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc")

    def test_report_identity_is_bound_to_plan_and_frozen_fixture(self) -> None:
        good = {
            "candidate_ref": "fusionconceptai://candidate/native-g1g2-diffusion-mms-v1",
            "candidate_version": "v5",
            "t1_package_hash": "a" * 64,
            "source_binding_hash": "b" * 64,
            "plan_hash": "c" * 64,
            "solver_input_hash": "d" * 64,
            "protocol_hash": "e" * 64,
            "solver_source_hash": comparator._EXPECTED_SOLVER_SOURCE_SHA256,
            "report_hash": "f" * 64,
        }
        self.assertEqual(comparator._check_inhouse_identity(good, good), [])
        changed_plan = dict(good, candidate_version="foreign")
        failures = comparator._check_inhouse_identity(good, changed_plan)
        self.assertIn("inhouse:report_plan_candidate_version_mismatch", failures)
        foreign_solver = dict(good, solver_source_hash="0" * 64)
        self.assertIn("inhouse:solver_source_not_frozen_sha256",
                      comparator._check_inhouse_identity(foreign_solver, foreign_solver))

    def test_runner_has_no_unmonitored_julia_discovery_child(self) -> None:
        source_path = Path(inspect.getsourcefile(supervisor))
        source = source_path.read_text(encoding="utf-8")
        self.assertNotIn("where.exe", source)
        self.assertNotIn("subprocess.run(", source)
        self.assertIn("ResumeThread(self.thread_handle)", source)
        self.assertIn("TerminateProcess(self.process_handle", source)
        self.assertIn("_verify_input_pins(test_dir, repo_root", source)

    def test_julia_and_scipy_share_one_240_second_deadline(self) -> None:
        source = Path(inspect.getsourcefile(supervisor)).read_text(
            encoding="utf-8")
        self.assertEqual(supervisor.TOTAL_WALL_TIMEOUT_SECONDS, 240)
        self.assertIn(
            "total_deadline = total_started + TOTAL_WALL_TIMEOUT_SECONDS",
            source)
        self.assertEqual(source.count("\"julia\", JULIA_TIMEOUT_SECONDS, total_deadline"), 1)
        self.assertEqual(source.count("\"python_scipy\", python_timeout, total_deadline"), 1)
        self.assertIn("remaining = deadline - time.monotonic()", source)
        self.assertIn("python_remaining_budget = max(", source)
        self.assertIn("python_timeout = min(PYTHON_TIMEOUT_SECONDS,", source)
        self.assertLess(
            source.index("_check_total_deadline(total_deadline, receipt"),
            source.index('receipt["stop_reason"] = ("complete"'))

    def test_postflight_that_crosses_total_deadline_cannot_emit_go(self) -> None:
        receipt: dict = {}
        with patch.object(supervisor.time, "monotonic", return_value=240.01):
            with self.assertRaisesRegex(TimeoutError, "postflight_before_go"):
                supervisor._check_total_deadline(
                    240.0, receipt, "postflight_before_go")
        self.assertEqual(receipt["stop_reason"], "total_wall_timeout")
        self.assertEqual(receipt["deadline_check_phase"], "postflight_before_go")

    def test_changed_pin_fails_closed(self) -> None:
        receipt: dict = {}
        with patch.object(supervisor, "_input_pins", return_value={
                "input.jl": "changed",
                "src/RuntimeV4/InHouseG1G2Q1SolverV1.jl":
                    supervisor.EXPECTED_INHOUSE_SOURCE_SHA256.lower()}):
            with self.assertRaisesRegex(RuntimeError, "pre_julia_input_pin_mismatch"):
                supervisor._verify_input_pins(
                    Path("."), Path("."), {"input.jl": "frozen"},
                    receipt, "pre_julia")
        self.assertEqual(receipt["stop_reason"], "pre_julia_input_pin_mismatch")
        self.assertFalse(receipt["pin_checks"][0]["inputs_match_initial"])

    @staticmethod
    def _source_sha256(text: str) -> str:
        return hashlib.sha256(text.encode("utf-8")).hexdigest().upper()

    def _probe_source_contract_ok(self, probe: str, runner: str,
                                 integration: str) -> bool:
        probe_hash = "8CF92684C608A095D07C7CBA499CB4947C8C3ACFD059C2173D98F746E92D5E33"
        runner_hash = "4F09460154238494238C84185482AFD857212392EA0D963DC8952FA6C51E4293"
        integration_hash = "37FC25612CCCF94044F736984F7F4A730C7F6F078898C80849981ADD27F3BC86"
        probe_terms = (
            "Meta.parseall(integration_source)",
            "length(matches) == 1 || error(\"expected one official admission function\")",
            "apv1_instrument_body(clone.args[2])",
            "apv1_strip_function_markers(clone, source_expression_count)",
            "isequal(normalized_clone, original) ||",
            "final_return_expression = phase_index == expression_count",
            "final_return_expression || push!(output,",
            "apv1_end_call(phase_index, label, source_line)",
            "begin_marker.final_return ==",
            "expected_expression_count",
            "push!(output, statement)",
            "throw(DiagnosticOnlyStop())",
            "result_discarded=true",
            "Base.include_string(Main, fixture_source, APV1_FIXTURE_PATH)",
            "Core.eval(Main.NG12_G, clone)",
            "Base.invokelatest(Main.ng12_source_chain)",
            "function _append_event(fields::NamedTuple)",
            "flush(io)",
            "function apv1_make_diagnostic_fixture(fixture_source::String)",
            "occurrences == 1 || error(\"focused fixture admission call pin mismatch\")",
        )
        runner_terms = (
            "PROBE_SOURCE_SHA256 = (",
            "8CF92684C608A095D07C7CBA499CB4947C8C3ACFD059C2173D98F746E92D5E33",
            "def validate_diagnostic_completion(events_path: Path,",
            "def record_postflight_pins(",
            "record_postflight_pins(",
            "completion = validate_diagnostic_completion(",
            "if total_deadline is not None and time.monotonic() >= total_deadline:",
            "RSS_LIMIT_BYTES\": 2 * 1024 * 1024 * 1024",
            "TOTAL_WALL_TIMEOUT_SECONDS\": 240",
            "POLL_SECONDS\": 0.25",
            "JULIA_HEAP_HINT\": \"1G\"",
            "JULIA_COMPILE_MODE\": \"min\"",
            "\"--threads=1\"",
            "supervisor.WindowsJob(supervisor.RSS_LIMIT_BYTES)",
            "supervisor._run_in_job(",
            "stop_reason\"] == \\\n            \"diagnostic_complete_zero_credit\"",
        )
        integration_terms = (
            "length(t.declarations) == 3 || return",
            "envelope_error = _vnext_t1_v2_recheck_envelope_error(input, t, r)",
            "input.parent_commitments == expected_parent || return",
            "g3check === :ok || return",
            "CandidateStatePackageV5NextV2(input.candidate_ref, t, r,",
            "VNextT1AdmissionResultV2(:prepared_not_executed",
        )
        no_downstream_calls = (
            "compile_native_g1g2_diffusion_v1(",
            "run_native_g1g2_inhouse_q1_level_v1(",
            "execute_native_g1g2_inhouse_q1_once!(",
            "scipy.sparse",
        )
        return (
            self._source_sha256(probe) == probe_hash
            and self._source_sha256(runner) == runner_hash
            and self._source_sha256(integration) == integration_hash
            and all(term in probe for term in probe_terms)
            and all(term in runner for term in runner_terms)
            and all(term in integration for term in integration_terms)
            and not any(term in probe for term in no_downstream_calls)
            and not any(term in runner for term in no_downstream_calls)
        )

    @staticmethod
    def _diagnostic_event(event_name: str, *, identity: dict | None = None,
                          **fields) -> dict:
        event = {
            "schema": "inhouse-q1-admission-probe-events-v1",
            "diagnostic_only": True,
            "acceptance_credit": False,
            "compiler_or_solver_input": False,
        }
        if identity is not None:
            event.update(identity)
        event["event"] = event_name
        event.update(fields)
        return event

    def _valid_diagnostic_events(self, namespace: dict) -> tuple[list[dict], dict]:
        identity = {
            "candidate_id": "candidate-test",
            "candidate_version": "v5",
            "transport_bundle_hash": "transport-hash",
            "recheck_bundle_hash": "recheck-hash",
            "recheck_wire_sha256": "wire-hash",
            "parent_commitments": ["parent-a", "parent-b"],
            "g3_expected_commitment": "g3-hash",
        }
        event = self._diagnostic_event
        events = [
            event("probe_started"),
            event("fresh_admission_input_bound", identity=identity,
                  input_type="FusionConceptAI.VNextT1AdmissionInputV2"),
            event("clone_call_begin", identity=identity),
            event("phase_begin", identity=identity, phase_index=1,
                  phase="early_check", source_line=20, monotonic_ns=100,
                  final_return_expression=False),
            event("phase_end", identity=identity, phase_index=1,
                  phase="early_check", source_line=20, monotonic_ns=110,
                  elapsed_ns=10),
            event("phase_begin", identity=identity, phase_index=2,
                  phase="final_result", source_line=21, monotonic_ns=120,
                  final_return_expression=True),
            event("clone_result_discarded", identity=identity,
                  monotonic_ns=130, result_discarded=True,
                  status="prepared_not_executed", resolution="terminal_deferred"),
            event("diagnostic_stop", identity=identity, monotonic_ns=140,
                  outcome=namespace["EXPECTED_OUTCOME"], clone_only=True,
                  official_admission_called=False, compiler_called=False,
                  solver_called=False, acceptance_credit=False),
        ]
        summary = {
            "schema": namespace["SUMMARY_SCHEMA"],
            "diagnostic_only": True,
            "acceptance_credit": False,
            "official_admission_called": False,
            "compiler_called": False,
            "solver_called": False,
            "scipy_called": False,
            "clone_result_discarded": True,
            "outcome": namespace["EXPECTED_OUTCOME"],
            "unmatched_phase_indices": [2],
            "intentional_final_return_phase": 2,
            "interrupted_phase_indices": [],
            "phase_count": 2,
            "error": "",
            "result_status": "prepared_not_executed",
            "result_resolution": "terminal_deferred",
        }
        return events, summary

    def _assert_admission_probe_static_contract(self, test_dir: Path,
                                                repo_root: Path) -> None:
        probe_dir = test_dir / "AdmissionProbeV1"
        probe_path = probe_dir / "probe_admission_v1.jl"
        runner_path = probe_dir / "run_probe_v1.py"
        integration_path = repo_root / "src/GenomeV5/Integration/" \
            "VNextGenomeV5IntegrationV2.jl"
        package_path = repo_root / "src/Contracts/" \
            "CandidateStatePackageV5NextV2.jl"
        probe = probe_path.read_bytes().decode("utf-8")
        runner = runner_path.read_bytes().decode("utf-8")
        integration = integration_path.read_bytes().decode("utf-8")
        fixture_bytes = (test_dir / "focused_fixture.jl").read_bytes()
        focused_tests_bytes = (test_dir / "focused_tests.jl").read_bytes()
        package_bytes = package_path.read_bytes()

        self.assertTrue(self._probe_source_contract_ok(probe, runner,
                                                       integration))
        self.assertEqual(hashlib.sha256(fixture_bytes).hexdigest().upper(),
                         "C40322D190E3BB72AFC0882E755687C67D5AD0EC4EC580BC09DFF9AA8ACBDC9A")
        self.assertEqual(hashlib.sha256(focused_tests_bytes).hexdigest().upper(),
                         "3F9A650FC8B0B218F0D8D52DE5524C03FFB1942FDCEC11E84E78C6AF6F8D43A5")
        self.assertEqual(hashlib.sha256(package_bytes).hexdigest().upper(),
                         "EFFAC2E603D2A1AF30605B70310A634E3659AC487634E164AB049851795C4F89")
        # The static gate rejects edits to a validation, branch, return,
        # instrumentation order, AST comparison, stop, or flush. It pins
        # source bytes; it does not execute Julia's Meta parser.
        mutations = (
            ("admission check removed", probe, runner,
             integration.replace("length(t.declarations) == 3", "true", 1)),
            ("branch changed", probe, runner,
             integration.replace("if r.status === :fail_closed",
                                 "if r.status !== :fail_closed", 1)),
            ("final return changed", probe, runner,
             integration.replace("VNextT1AdmissionResultV2(:prepared_not_executed",
                                 "_vnext_t1_v2_reject(:fail_closed", 1)),
            ("clone AST comparison removed",
             probe.replace("isequal(normalized_clone, original)", "true", 1),
             runner, integration),
            ("source Expr order changed",
             probe.replace("push!(output, statement)",
                           "pushfirst!(output, statement)", 1),
             runner, integration),
            ("diagnostic stop changed",
             probe.replace("throw(DiagnosticOnlyStop())",
                           "return result", 1), runner, integration),
            ("event flush removed", probe.replace("flush(io)", "", 1),
             runner, integration),
        )
        for label, mutated_probe, mutated_runner, mutated_integration in mutations:
            with self.subTest(tamper=label):
                self.assertFalse(self._probe_source_contract_ok(
                    mutated_probe, mutated_runner, mutated_integration))

        # Exercise the Python-side pre/post pins and completion gate with
        # synthetic events only. No Julia process or numerical code is loaded.
        namespace = runpy.run_path(str(runner_path))
        self.assertEqual(namespace["verify_pins"](
            supervisor, repo_root, test_dir, probe_dir, runner_path)[
                "admission_probe_v1/probe_source"],
            "8cf92684c608a095d07c7cba499cb4947c8c3acfd059c2173d98f746e92d5e33")
        pin_globals = namespace["verify_pins"].__globals__
        expected_probe_pin = pin_globals["PROBE_SOURCE_SHA256"]
        try:
            pin_globals["PROBE_SOURCE_SHA256"] = "0" * 64
            with self.assertRaisesRegex(RuntimeError, "input pin mismatch"):
                namespace["verify_pins"](
                    supervisor, repo_root, test_dir, probe_dir, runner_path)
        finally:
            pin_globals["PROBE_SOURCE_SHA256"] = expected_probe_pin
        events, summary = self._valid_diagnostic_events(namespace)
        validate = namespace["validate_diagnostic_completion"]
        postflight = namespace["record_postflight_pins"]
        with tempfile.TemporaryDirectory() as temp_name:
            temp_dir = Path(temp_name)
            events_path = temp_dir / "events.jsonl"
            summary_path = temp_dir / "summary.json"

            def write_case(case_events: list[dict], case_summary: dict) -> None:
                events_path.write_text("".join(
                    json.dumps(item, separators=(",", ":")) + "\n"
                    for item in case_events), encoding="utf-8")
                summary_path.write_text(json.dumps(case_summary),
                                        encoding="utf-8")

            write_case(events, summary)
            completed = validate(events_path, summary_path)
            self.assertEqual(completed["phase_count"], 2)
            self.assertEqual(completed["intentional_final_return_phase"], 2)
            self.assertEqual(completed["interrupted_phase_indices"], [])

            bad_cases: list[tuple[str, list[dict], dict, bool]] = []
            no_result = [item for item in events
                         if item["event"] != "clone_result_discarded"]
            bad_cases.append(("clone result missing", no_result, summary, False))
            wrong_scope = [dict(item) for item in events]
            wrong_scope[1]["acceptance_credit"] = True
            bad_cases.append(("scope changed", wrong_scope, summary, False))
            wrong_identity = [dict(item) for item in events]
            wrong_identity[4]["candidate_id"] = "foreign-candidate"
            bad_cases.append(("identity changed", wrong_identity, summary, False))
            wrong_phase_order = [events[0], events[1], events[2],
                                 events[4], events[3], *events[5:]]
            bad_cases.append(("phase order changed", wrong_phase_order,
                              summary, False))
            missing_end = [item for item in events
                           if item["event"] != "phase_end"]
            bad_cases.append(("nonfinal end missing", missing_end,
                              summary, False))
            duplicate_end = [*events[:5], events[4], *events[5:]]
            bad_cases.append(("phase end duplicated", duplicate_end,
                              summary, False))
            interrupted = [*events[:5], self._diagnostic_event(
                "phase_begin", identity=events[1] | {}, phase_index=3,
                phase="unexpected", source_line=22, monotonic_ns=115,
                final_return_expression=False), *events[5:]]
            bad_cases.append(("extra unmatched phase", interrupted,
                              summary, False))
            wrong_terminal = [dict(item) for item in events]
            wrong_terminal[-1]["outcome"] = "diagnostic_exception"
            bad_cases.append(("terminal status changed", wrong_terminal,
                              summary, False))
            wrong_summary = dict(summary, error="unexpected")
            bad_cases.append(("summary error changed", events,
                              wrong_summary, False))
            wrong_summary_status = dict(summary, outcome="diagnostic_exception")
            bad_cases.append(("summary status changed", events,
                              wrong_summary_status, False))
            bad_cases.append(("summary result status missing", events,
                              {key: value for key, value in summary.items()
                               if key != "result_status"}, False))
            bad_cases.append(("summary result resolution missing", events,
                              {key: value for key, value in summary.items()
                               if key != "result_resolution"}, False))

            for label, case_events, case_summary, _ in bad_cases:
                with self.subTest(event_tamper=label):
                    write_case(case_events, case_summary)
                    with self.assertRaises(RuntimeError):
                        validate(events_path, summary_path)

            write_case(events, summary)
            summary_path.unlink()
            with self.assertRaisesRegex(RuntimeError, "summary is missing"):
                validate(events_path, summary_path)

            events_path.write_text("{malformed\n", encoding="utf-8")
            summary_path.write_text(json.dumps(summary), encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "malformed diagnostic event"):
                validate(events_path, summary_path)

        # Controlled pre/post pin and deadline failures are pure Python.
        postflight_globals = postflight.__globals__
        original_verify_pins = postflight_globals["verify_pins"]
        try:
            postflight_globals["verify_pins"] = lambda *args, **kwargs: {"source": "same"}
            with patch.object(namespace["time"], "monotonic", return_value=9.0):
                receipt: dict = {}
                postflight(supervisor, repo_root, test_dir, probe_dir,
                           runner_path, {"source": "same"}, receipt, 10.0)
            self.assertTrue(receipt["postflight_input_hashes_match"])
            self.assertIsNone(receipt.get("stop_reason"))

            postflight_globals["verify_pins"] = lambda *args, **kwargs: {"source": "changed"}
            with patch.object(namespace["time"], "monotonic", return_value=9.0):
                receipt = {}
                postflight(supervisor, repo_root, test_dir, probe_dir,
                           runner_path, {"source": "same"}, receipt, 10.0)
            self.assertEqual(receipt["stop_reason"],
                             "input_pin_changed_during_probe")

            postflight_globals["verify_pins"] = lambda *args, **kwargs: {"source": "same"}
            with patch.object(namespace["time"], "monotonic", return_value=10.0):
                receipt = {}
                postflight(supervisor, repo_root, test_dir, probe_dir,
                           runner_path, {"source": "same"}, receipt, 10.0)
            self.assertEqual(receipt["stop_reason"],
                             "total_wall_timeout_postflight")
        finally:
            postflight_globals["verify_pins"] = original_verify_pins

        self.assertEqual(supervisor.RSS_LIMIT_BYTES, 2 * 1024 * 1024 * 1024)
        self.assertEqual(supervisor.TOTAL_WALL_TIMEOUT_SECONDS, 240)
        self.assertEqual(supervisor.JULIA_TIMEOUT_SECONDS, 240)
        self.assertEqual(supervisor.POLL_SECONDS, 0.25)
        self.assertEqual(supervisor.JULIA_COMPILE_MODE, "min")
        self.assertEqual(supervisor.JULIA_HEAP_HINT, "1G")

        julia_smoke_path = probe_dir / "ast_semantics_smoke_v1.jl"
        julia_smoke = julia_smoke_path.read_text(encoding="utf-8")
        self.assertEqual(hashlib.sha256(julia_smoke_path.read_bytes()).hexdigest().upper(),
                         "BB22C4CC4DA28A69ED5B641061194CB9542DFDABAC1A090F18B446570F6AF4F4")
        self.assertIn("const EXPECTED_PROBE_SHA256 =", julia_smoke)
        self.assertIn("const EXPECTED_INTEGRATION_SHA256 =", julia_smoke)
        self.assertIn("smoke_sha256(read(PROBE_SOURCE_PATH)) == EXPECTED_PROBE_SHA256", julia_smoke)
        self.assertIn("smoke_sha256(read(INTEGRATION_SOURCE_PATH)) == EXPECTED_INTEGRATION_SHA256", julia_smoke)
        self.assertIn("apv1_build_diagnostic_clone", julia_smoke)
        self.assertIn("apv1_instrument_body", julia_smoke)
        self.assertIn("apv1_strip_function_markers", julia_smoke)
        self.assertIn("&& return", julia_smoke)
        self.assertIn("|| return", julia_smoke)
        self.assertIn("ArgumentError", julia_smoke)
        self.assertNotIn("using FusionConceptAI", julia_smoke)
        self.assertNotIn("using JSON3", julia_smoke)
        self.assertNotIn("ng12_inhouse_compiled_fixture", julia_smoke)
        self.assertNotIn("compile_native_g1g2", julia_smoke)
        self.assertNotIn("Gridap", julia_smoke)

    def test_q1_skips_unconsumed_v1_parent_baseline_and_keeps_v2_admission(
            self) -> None:
        test_dir = Path(inspect.getsourcefile(supervisor)).resolve().parent
        repo_root = test_dir.parents[2]
        fixture = (test_dir / "focused_fixture.jl").read_text(
            encoding="utf-8")
        chain_start = fixture.index("function ng12_source_chain")
        chain_end = fixture.index(
            "\nfunction ng12_inhouse_compiled_fixture", chain_start)
        chain = fixture[chain_start:chain_end]

        self.assertNotIn("bind_local_parent_baseline_from_t0_v1(", chain)
        self.assertNotIn("fixture.chain.parent.", chain)
        self.assertNotIn("parent=parent", chain)
        self.assertIn("parents = ntuple(i -> NG12_G.vnext_t1_parent_commitment_v2(candidate,\n"
                      "        transport.declarations[i]), 2)", chain)
        self.assertIn("admission_input = NG12_G.VNextT1AdmissionInputV2(candidate, transport,\n"
                      "        recheck_v2, parents, expected.commitment_hash, authority)",
                      chain)
        self.assertIn("admission = NG12_G.vnext_t1_admit_v2(admission_input)",
                      chain)
        self.assertIn("fusionconceptai://candidate/native-g1g2-diffusion-mms-v1",
                      fixture)
        self.assertIn("NG12_R.compile_native_g1g2_diffusion_v1(\n"
                      "        chain.admission, chain.g1, chain.g2, chain.programs, chain.profile)",
                      fixture)

        legacy_tests = repo_root / "test/GenomeV5/Integration/"
        legacy_tests = legacy_tests / "vnext_parent_baseline_binding_local_v1_tests.jl"
        self.assertTrue(legacy_tests.is_file())
        self.assertIn("bind_local_parent_baseline_from_t0_v1(",
                      legacy_tests.read_text(encoding="utf-8"))
        readme = (test_dir / "README.md").read_text(encoding="utf-8")
        readme_flat = " ".join(readme.split())
        self.assertIn("does not claim coverage or acceptance for the "
                      "legacy/local V1 parent-baseline helper", readme_flat)
        self.assertIn(legacy_tests.relative_to(repo_root).as_posix(), readme)

        focused_tests = (test_dir / "focused_tests.jl").read_text(
            encoding="utf-8")
        self.assertEqual(focused_tests.count("@test ") +
                         focused_tests.count("@test_throws "), 50)
        self.assertIn(
            "protocol.cell_counts == ((2, 3, 4), (4, 6, 8), (8, 12, 16))",
            focused_tests)
        self.assertEqual(supervisor.RSS_LIMIT_BYTES, 2 * 1024 * 1024 * 1024)
        self.assertEqual(supervisor.TOTAL_WALL_TIMEOUT_SECONDS, 240)
        self._assert_admission_probe_static_contract(test_dir, repo_root)


class _FakeFunction:
    def __init__(self, callback) -> None:
        self.callback = callback
        self.argtypes = None
        self.restype = None

    def __call__(self, *args):
        return self.callback(*args)


class _FakeKernel:
    PROCESS_HANDLE = 0x1001
    THREAD_HANDLE = 0x1002
    WAIT_TIMEOUT = 0x00000102
    WAIT_OBJECT_0 = 0x00000000
    WAIT_FAILED = 0xFFFFFFFF
    STILL_ACTIVE = 259
    FILETIME_EPOCH_DELTA = 11644473600
    FILETIME_TICKS_PER_SECOND = 10_000_000

    def __init__(self, failure: str) -> None:
        self.failure = failure
        self.alive = False
        self.suspended = False
        self.assigned = False
        self.active_children = 0
        self.resume_thread_calls = 0
        self.closed_handles: list[int] = []
        self.CreateProcessW = _FakeFunction(self._create_process)
        self.CreateFileW = _FakeFunction(lambda *args: 0x3001)
        self.SetHandleInformation = _FakeFunction(lambda *args: 1)
        self.GetProcessTimes = _FakeFunction(self._get_process_times)
        self.GetPriorityClass = _FakeFunction(self._get_priority_class)
        self.ResumeThread = _FakeFunction(self._resume_thread)
        self.WaitForSingleObject = _FakeFunction(self._wait)
        self.GetExitCodeProcess = _FakeFunction(self._exit_code)
        self.TerminateProcess = _FakeFunction(self._terminate_process)
        self.CloseHandle = _FakeFunction(self._close_handle)

    @staticmethod
    def _handle_value(value) -> int:
        return int(value.value if hasattr(value, "value") else value)

    def _create_process(self, *args):
        if self.failure == "create_process":
            ctypes.set_last_error(2)
            return 0
        info = ctypes.cast(
            args[-1], ctypes.POINTER(supervisor._ProcessInformation)).contents
        info.hProcess = self.PROCESS_HANDLE
        info.hThread = self.THREAD_HANDLE
        info.dwProcessId = 4242
        info.dwThreadId = 4343
        self.alive = True
        self.suspended = True
        self.active_children = 1
        return 1

    def _get_priority_class(self, handle):
        self.assert_exact_process_handle(handle)
        if self.failure == "get_priority_class":
            ctypes.set_last_error(5)
            return 0
        return 0x20

    def _get_process_times(self, *args):
        if self.failure == "get_process_times":
            ctypes.set_last_error(5)
            return 0
        now_ticks = int((time.time() +
            self.FILETIME_EPOCH_DELTA) * self.FILETIME_TICKS_PER_SECOND)
        created = ctypes.cast(
            args[1], ctypes.POINTER(supervisor._FileTime)).contents
        created.dwLowDateTime = now_ticks & 0xFFFFFFFF
        created.dwHighDateTime = (now_ticks >> 32) & 0xFFFFFFFF
        for pointer in args[2:5]:
            ctypes.cast(pointer, ctypes.POINTER(supervisor._FileTime)).contents
        return 1

    def _resume_thread(self, handle):
        self.resume_thread_calls += 1
        if self.failure == "resume":
            ctypes.set_last_error(5)
            return self.WAIT_FAILED
        self.suspended = False
        return 1

    def _wait(self, handle, timeout):
        return self.WAIT_TIMEOUT if self.alive else self.WAIT_OBJECT_0

    def _exit_code(self, handle, output):
        ctypes.cast(output, ctypes.POINTER(wintypes.DWORD)).contents.value = (
            self.STILL_ACTIVE if self.alive else 94)
        return 1

    def _terminate_process(self, handle, exit_code):
        self.assert_exact_process_handle(handle)
        self.alive = False
        self.suspended = False
        self.active_children = 0
        return 1

    def assert_exact_process_handle(self, handle) -> None:
        if self._handle_value(handle) != self.PROCESS_HANDLE:
            raise AssertionError("cleanup used a handle other than original hProcess")

    def _close_handle(self, handle):
        self.closed_handles.append(self._handle_value(handle))
        return 1


@unittest.skipUnless(os.name == "nt", "requires Windows handle semantics")
class SuspendedChildFailureTests(unittest.TestCase):
    def _exercise_failure(self, failure: str) -> None:
        api = _FakeKernel(failure)
        real_process_type = supervisor.WindowsNativeProcess

        class FakeJob:
            def active_processes(self):
                return int(api.alive and api.assigned)

            def assign(self, process):
                if failure == "assign":
                    raise OSError("controlled AssignProcessToJobObject failure")
                api.assigned = True

            def active_pid_inventory(self):
                if failure == "resume" and api.alive and api.assigned:
                    return supervisor.JobPidInventory(True, (4242,), 1, 1)
                return supervisor.JobPidInventory(True, (), 0, 0)

            def terminate(self, exit_code: int):
                api._terminate_process(_FakeKernel.PROCESS_HANDLE, exit_code)

            def peak_job_commit_bytes(self):
                return 0

        def make_process(argv, cwd, stdout_file, stderr_file):
            return real_process_type(
                argv, cwd, stdout_file, stderr_file, kernel32=api)

        def read_controlled_process_sample(pid, _job, process):
            if pid != 4242:
                raise AssertionError(f"unexpected controlled sample PID {pid}")
            return supervisor.ProcessSample(
                pid, process.creation_time_utc, rss_bytes=0)

        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            audit_path = root / "audit.jsonl"
            receipt = {
                "peak_sampled_tree_rss_bytes": 0,
                "peak_job_commit_bytes": 0,
                "rss_accounting_incomplete": False,
                "stop_reason": None,
            }
            job = FakeJob()
            with patch.object(supervisor, "WindowsNativeProcess",
                              new=make_process), patch.object(
                                  supervisor, "_read_windows_process_sample",
                                  new=read_controlled_process_sample):
                with self.assertRaises((OSError, RuntimeError)):
                    supervisor._run_in_job(
                        ["controlled.exe"], root,
                        root / "stdout.log", root / "stderr.log",
                        audit_path, job, receipt, "julia", 10,
                        time.monotonic() + 10)
            self.assertTrue(audit_path.is_file())
            audit_text = audit_path.read_text(encoding="utf-8")
            audit_rows = [json.loads(line) for line in audit_text.splitlines()]
            if failure == "resume":
                self.assertEqual(api.resume_thread_calls, 1)
                self.assertEqual(len(audit_rows), 1)
                self.assertEqual(audit_rows[0]["job_pids"], [4242])
                self.assertTrue(receipt["julia_audit_writer_complete"])
            else:
                self.assertEqual(api.resume_thread_calls, 0)
                self.assertEqual(audit_text, "")
        self.assertEqual(api.active_children, 0)
        self.assertFalse(api.suspended)
        self.assertFalse(api.alive)
        if failure != "create_process":
            self.assertIn(_FakeKernel.PROCESS_HANDLE, api.closed_handles)
            self.assertIn(_FakeKernel.THREAD_HANDLE, api.closed_handles)
        self.assertFalse(any(
            getattr(process, "pid", None) == 4242
            for process in supervisor._PENDING_NATIVE_PROCESS_CLEANUP))

    def test_get_process_times_assign_and_resume_failures_reap_child(self) -> None:
        for failure in ("get_priority_class", "get_process_times", "assign", "resume"):
            with self.subTest(failure=failure):
                self._exercise_failure(failure)

    def test_create_process_failure_creates_no_suspended_child(self) -> None:
        self._exercise_failure("create_process")


class _LifecycleApiFake:
    """Injectable native boundary for the managed lifecycle's focused controls."""

    def __init__(self, core, timeline, *, root_file_handle=None):
        self.core = core
        self.timeline = timeline
        self.monitor = core.ProcessIdentity(31000, 134349400000000000)
        self.root = core.ProcessIdentity(41000, 134349400000000100)
        self.root_handle = 100
        self.root_thread = 101
        self.job = 900
        self.queue = []
        self.next_handle = 200
        self.handle_identity = {}
        self.handle_object = {}
        self.parents = {}
        self.latest_by_pid = {}
        self.signaled = {}
        self.exit_codes = {}
        self.exit_events = {}
        self.emit_exit_after_terminated_create_continue = False
        self.pending_job_exit_codes = {}
        self.closed_handles = []
        self.closed_debug_files = []
        self.fail_duplicate_call = None
        self.duplicate_call_count = 0
        self.fail_close_once = set()
        self.close_attempts = {}
        self.pid_resource_reads = []
        self.resource_handle_reads = []
        self.open_birth_handle_calls = 0
        self._bind(self.root_handle, self.root, "root-process")
        self._bind(self.root_thread, None, "root-thread")
        self._bind(110, self.root, "root-process")
        self._bind(111, None, "root-thread")
        self._set_parent(self.root, self.monitor.pid)
        self.latest_by_pid[self.root.pid] = self.root
        self.signaled[self.root] = False
        self.exit_codes[self.root] = self.core.STILL_ACTIVE
        self.root_create_event = None
        self.root_file_handle = root_file_handle

    def _bind(self, handle, identity, object_name):
        self.handle_identity[handle] = identity
        self.handle_object[handle] = object_name

    def _set_parent(self, identity, parent_pid):
        self.parents[identity] = parent_pid

    def current_process_identity(self):
        return self.monitor

    def tick_count64(self):
        return 150000

    def create_process(self, argv, cwd, env, stdio_handles):
        self.timeline.append(("create_process", tuple(argv)))
        self.root_create_event = self.core.DebugEvent(
            self.core.CREATE_PROCESS_DEBUG_EVENT, self.root.pid, 411,
            process_handle=110, thread_handle=111,
            file_handle=self.root_file_handle)
        self.queue.append(self.root_create_event)
        return self.core.CreateProcessResult(
            self.root_handle, self.root_thread, self.root.pid, 411, tuple(stdio_handles))

    def add_child_event(self, pid, creation_ticks, parent_pid, *, thread_handle=None,
                        enqueue=True):
        identity = self.core.ProcessIdentity(pid, creation_ticks)
        self.latest_by_pid[pid] = identity
        self._set_parent(identity, parent_pid)
        self.signaled[identity] = False
        self.exit_codes[identity] = self.core.STILL_ACTIVE
        event_handle = self.next_handle
        self.next_handle += 1
        token = f"process:{pid}:{creation_ticks}"
        self._bind(event_handle, identity, token)
        if thread_handle is None:
            thread_handle = self.next_handle
            self.next_handle += 1
        self._bind(thread_handle, None, f"debug-thread:{pid}:{creation_ticks}")
        event = self.core.DebugEvent(self.core.CREATE_PROCESS_DEBUG_EVENT, pid,
                                     pid + 1, process_handle=event_handle,
                                     thread_handle=thread_handle)
        if enqueue:
            self.queue.append(event)
        return identity, event

    def add_exit_event(self, identity, exit_code=0):
        return self.core.DebugEvent(self.core.EXIT_PROCESS_DEBUG_EVENT,
                                    identity.pid, identity.pid + 1,
                                    exit_code=exit_code)

    def wait_debug_event(self, timeout_ms):
        if self.queue:
            return self.queue.pop(0)
        return None

    def continue_debug_event(self, event, status):
        identity = self.latest_by_pid.get(event.process_id)
        self.timeline.append(("continue", event.code, event.process_id,
                              None if identity is None else identity.creation_time_100ns,
                              status, id(event)))
        if (event.code == self.core.CREATE_PROCESS_DEBUG_EVENT and
                identity is not None and
                self.emit_exit_after_terminated_create_continue and
                identity in self.pending_job_exit_codes):
            exit_code = self.pending_job_exit_codes.pop(identity)
            exit_event = self.add_exit_event(identity, exit_code)
            self.exit_events[identity] = exit_event
            self.queue.append(exit_event)
            self.timeline.append(("enqueue_terminated_exit", identity, exit_code,
                                 id(event), id(exit_event)))
        if event.code == self.core.EXIT_PROCESS_DEBUG_EVENT and identity is not None:
            self.signaled[identity] = True
            self.exit_codes[identity] = event.exit_code

    def open_birth_handle(self, event_process_handle, pid):
        self.open_birth_handle_calls += 1
        identity = self.handle_identity[event_process_handle]
        if identity is None or identity.pid != pid:
            raise AssertionError("birth handle must be opened from the exact debug-event process handle")
        opened = self.next_handle
        self.next_handle += 1
        self._bind(opened, identity, self.handle_object[event_process_handle])
        self.timeline.append(("open_birth_handle", identity, opened))
        return opened, True

    def compare_objects(self, first, second):
        return self.handle_object.get(first) == self.handle_object.get(second)

    def duplicate_handle(self, handle):
        self.duplicate_call_count += 1
        identity = self.handle_identity.get(handle)
        self.timeline.append(("duplicate", identity, handle))
        if self.fail_duplicate_call == self.duplicate_call_count:
            raise OSError("injected DuplicateHandle failure")
        duplicated = self.next_handle
        self.next_handle += 1
        self._bind(duplicated, identity, self.handle_object[handle])
        self.timeline[-1] = ("duplicate", identity, handle, duplicated)
        return duplicated

    def read_identity(self, handle):
        identity = self.handle_identity.get(handle)
        if identity is None:
            raise OSError("handle has no process identity")
        return identity

    def read_parent_pid(self, handle):
        return self.parents[self.read_identity(handle)]

    def wait_handle(self, handle, timeout_ms):
        identity = self.read_identity(handle)
        result = (self.core.WAIT_OBJECT_0 if self.signaled.get(identity, False)
                  else self.core.WAIT_TIMEOUT)
        self.timeline.append(("wait_handle", identity, handle, timeout_ms, result))
        return result

    def exit_code(self, handle):
        identity = self.read_identity(handle)
        self.timeline.append(("exit_code", identity, handle))
        return self.exit_codes[identity]

    def is_signaled(self, handle):
        return self.signaled.get(self.read_identity(handle), False)

    def ensure_job(self, process_handle, supplied_job):
        self.timeline.append(("ensure_job", self.read_identity(process_handle), supplied_job))
        return (self.job if supplied_job is None else supplied_job), supplied_job is None

    def create_containment_job(self):
        return self.job

    def terminate_job(self, job_handle, exit_code):
        self.timeline.append(("terminate_job", job_handle, exit_code))
        for identity in tuple(self.signaled):
            self.signaled[identity] = True
            self.exit_codes[identity] = exit_code
        if self.emit_exit_after_terminated_create_continue:
            self.pending_job_exit_codes[self.root] = exit_code

    def job_process_ids(self, job_handle):
        if job_handle != self.job:
            raise AssertionError("Job census must use the exact retained Job handle")
        pids = tuple(sorted(identity.pid for identity, signaled in self.signaled.items()
                            if not signaled))
        self.timeline.append(("job_process_ids", job_handle, pids))
        return pids

    def terminate_process(self, process_handle, exit_code):
        identity = self.read_identity(process_handle)
        self.timeline.append(("terminate_process", identity, process_handle, exit_code))
        self.exit_codes[identity] = exit_code
        event = self.add_exit_event(identity, exit_code)
        self.exit_events[identity] = event
        self.queue.append(event)

    def resume_thread(self, thread_handle):
        self.timeline.append(("resume_thread", thread_handle))
        return 1

    def close_handle(self, handle):
        self.close_attempts[handle] = self.close_attempts.get(handle, 0) + 1
        self.timeline.append(("close_handle", handle))
        if handle in self.fail_close_once and self.close_attempts[handle] == 1:
            raise OSError("injected CloseHandle failure")
        self.closed_handles.append(handle)

    def close_debug_file(self, handle):
        self.timeline.append(("close_debug_file", handle))
        self.closed_debug_files.append(handle)

    def command_line(self, process_handle):
        return ["git.exe", "-C", ".", "status"]

    def resource_values(self, process_handle):
        identity = self.read_identity(process_handle)
        self.timeline.append(("resource_values", identity, process_handle))
        self.resource_handle_reads.append((identity, process_handle))
        return {
            "rss_bytes": 0,
            "cpu_user_seconds": 0.0,
            "cpu_system_seconds": 0.0,
            "cmdline": ["git.exe", "-C", ".", "status"],
        }


class _LifecycleObserverFake:
    def __init__(self, core, api, timeline):
        self.core = core
        self.api = api
        self.timeline = timeline
        self.birth_measurements = []
        self.measurements = []
        self.events = []

    @staticmethod
    def _row(identity, parent_pid):
        from types import SimpleNamespace
        return SimpleNamespace(
            identity=SimpleNamespace(pid=identity.pid,
                                      create_time_100ns=identity.creation_time_100ns),
            ppid=parent_pid,
            name="git.exe")

    def birth_source_witness(self, pid, *, phase, event_sequence):
        identity = self.api.latest_by_pid[pid]
        parent_pid = self.api.parents[identity]
        row = self._row(identity, parent_pid)
        receipt = {
            "complete": True,
            "sequence": max(1, event_sequence),
            "phase": phase,
            "row_identity": {"pid": identity.pid,
                             "creation_time_100ns": identity.creation_time_100ns},
            "row_ppid": parent_pid,
            "row_name": "git.exe",
        }
        return self.core.BirthSourceWitness(row, object(), receipt)

    def measure_exact_handle(self, handle, identity, row, *, phase, event_receipt):
        before = self.api.read_identity(handle)
        after = self.api.read_identity(handle)
        sequence = event_receipt.get("event_sequence", 0)
        self.timeline.append(("measure", phase, identity, handle, sequence))
        measurement = {
            "schema": self.core.RESOURCE_MEASUREMENT_SCHEMA,
            "phase": phase,
            "identity": {"pid": identity.pid,
                         "creation_time_100ns": identity.creation_time_100ns},
            "handle_identity_before": {"pid": before.pid,
                                        "creation_time_100ns": before.creation_time_100ns},
            "handle_identity_after": {"pid": after.pid,
                                       "creation_time_100ns": after.creation_time_100ns},
            "event_sequence": sequence,
            "complete": True,
            "rss_bytes": 0,
            "cpu_user_seconds": 0.0,
            "cpu_system_seconds": 0.0,
            "cmdline": ["git.exe", "-C", ".", "status"],
            "source_tags": ["GetProcessMemoryInfo", "GetProcessTimes",
                            "NtQueryInformationProcess.ProcessCommandLineInformation"],
        }
        self.measurements.append((handle, identity, phase, dict(event_receipt)))
        return measurement

    def record_birth_measurement(self, measurement):
        self.birth_measurements.append(dict(measurement))
        self.timeline.append(("birth_measurement_recorded", measurement["identity"]["pid"],
                              measurement["identity"]["creation_time_100ns"]))
        return True

    def record_resource_measurement(self, measurement):
        identity = measurement["identity"]
        self.timeline.append(("resource_measurement_recorded", measurement["phase"],
                              identity["pid"], identity["creation_time_100ns"],
                              measurement["event_sequence"], dict(measurement)))
        return True

    def record_lifecycle_event(self, event):
        self.events.append(dict(event))

    def validate_initial_loader_breakpoint(self, identity, thread_id, exception_address,
                                           exception_code, create_event_thread_id):
        return (identity.pid > 0 and thread_id == create_event_thread_id and
                exception_code == self.core.EXCEPTION_BREAKPOINT and
                exception_address is not None)


class _LifecycleRegistryFake:
    def __init__(self, core, api, ack_directory, timeline):
        self.core = core
        self.api = api
        self.phase_root = ack_directory
        self.timeline = timeline
        self.managed = None
        self.owned_handles = {}
        self.next_mode = None

    @property
    def identities(self):
        return tuple((identity.pid, identity.creation_time_100ns)
                     for identity in sorted(self.owned_handles))

    def bind_managed_context(self, managed):
        self.managed = managed

    def register_birth(self, record, *, ack_type, ack_publisher):
        self.timeline.append(("registry_register", record.identity,
                              record.parent_identity, record.retained_handle))
        mode, self.next_mode = self.next_mode, None
        if mode == "raise":
            raise self.core.BirthRegistrationError(
                "injected exact registry rejection", handle_transferred=False,
                cleanup_complete=True, retained_handle=record.retained_handle,
                identity=record.identity)
        payload = {
            "schema": self.core.ACK_SCHEMA,
            "session_id": record.session_id,
            "scope_sha256": record.scope_sha256,
            "child_pid": record.identity.pid,
            "child_creation_time_100ns": record.identity.creation_time_100ns,
            "parent_pid": record.parent_identity.pid,
            "parent_creation_time_100ns": record.parent_identity.creation_time_100ns,
            "monitor_pid": record.monitor_identity.pid,
            "monitor_creation_time_100ns": record.monitor_identity.creation_time_100ns,
            "registration_sequence": record.registration_sequence,
            "handle_duplicated": True,
            "identity_registered": True,
            "job_bound": record.job_bound,
            "creation_sample_measured": True,
            "resume_permitted": True,
            "full_run_resource_complete": False,
        }
        if mode == "forged_return":
            forged = dict(payload)
            forged["parent_creation_time_100ns"] += 1
            return ack_type(**forged)
        ack = ack_type.from_mapping(payload)
        self.owned_handles[record.identity] = record.retained_handle
        publication = ack_publisher(ack.wire())
        if not isinstance(publication, self.core.AckPublication) or publication.exclusive is not True \
                or publication.flushed is not True:
            raise self.core.LifecycleError("ack_publication", "fake publisher did not return exclusive durable receipt")
        self.timeline.append(("ack_published", record.identity, ack.wire()))
        return ack

    def handle_for(self, identity):
        return self.owned_handles[identity]

    def unregister_and_close_birth(self, identity, *, sequence):
        handle = self.owned_handles.pop(identity)
        self.api.close_handle(handle)
        return {"complete": True, "identity": identity, "sequence": sequence}

    def close_owned(self):
        failures = []
        for identity, handle in tuple(self.owned_handles.items()):
            try:
                self.api.close_handle(handle)
            except Exception as exc:
                failures.append({"identity": identity, "handle": handle,
                                 "error": repr(exc)})
            else:
                self.owned_handles.pop(identity, None)
        return {"complete": not failures and not self.owned_handles,
                "failures": failures,
                "remaining": len(self.owned_handles)}


class _LifecycleHarness:
    def __init__(self, core, *, registry_mode=None, root_file_handle=None,
                 capture_startup_error=False):
        self.core = core
        self.temp = tempfile.TemporaryDirectory()
        self.ack_directory = Path(self.temp.name)
        self.timeline = []
        self.api = _LifecycleApiFake(core, self.timeline,
                                     root_file_handle=root_file_handle)
        self.registry = _LifecycleRegistryFake(core, self.api, self.ack_directory,
                                               self.timeline)
        self.observer = _LifecycleObserverFake(core, self.api, self.timeline)
        self.registry.next_mode = registry_mode
        self.ack_publications = []
        env = {
            "FCA_MANAGED_SESSION_ID": "a" * 64,
            "FCA_MANAGED_ACK_DIRECTORY": str(self.ack_directory),
            "FCA_MANAGED_SCOPE_SHA256": "b" * 64,
            "FCA_MANAGED_MONITOR_PID": str(self.api.monitor.pid),
            "FCA_MANAGED_MONITOR_CREATE_100NS": str(self.api.monitor.creation_time_100ns),
            "FCA_MANAGED_HANDSHAKE_SECONDS": "5",
        }

        def publish(directory, payload):
            encoded = json.dumps(dict(payload), sort_keys=True, separators=(",", ":")).encode()
            filename = f"{payload['child_pid']}_{payload['child_creation_time_100ns']}.ack.json"
            receipt = core.AckPublication(
                core.ACK_PUBLICATION_SCHEMA, str(Path(directory) / filename), filename,
                len(encoded), hashlib.sha256(encoded).hexdigest(), True, True)
            self.ack_publications.append((dict(payload), receipt))
            self.timeline.append(("ack_publication_callback", payload["child_pid"],
                                  payload["child_creation_time_100ns"]))
            return receipt

        try:
            self.session = core.WindowsDebugLifecycle.spawn_suspended(
                ["git.exe", "-C", ".", "status"], None, env, self.api.job,
                self.registry, self.observer, time.monotonic() + 30,
                stdio_handles=(None, None, None), native_api=self.api,
                ack_publisher=publish)
        except core.LifecycleError as exc:
            if not capture_startup_error:
                raise
            self.startup_error = exc
            self.session = getattr(exc, "session", None)
        else:
            self.startup_error = None

    def record_first_standard_sample(self):
        """Build a durable fake R23 sample from the retained root handle."""
        root = self.session.root_identity
        attempt = self.session.begin_sample_attempt()
        witness = self.observer.birth_source_witness(
            root.pid, phase="managed_create", event_sequence=1)
        retained = self.session.handle_for(root)
        measurement = self.session.resource_reader(
            retained, root, witness.row, phase="sample",
            event_receipt={"event_sequence": attempt,
                           "sample_attempt_id": attempt})
        boundary = self.session.end_sample_attempt(attempt)
        if not boundary.complete or boundary.attempt_id != attempt:
            raise AssertionError("fake first standard sample did not finish as a complete whole attempt")
        identity_wire = {"pid": root.pid,
                         "creation_time_100ns": root.creation_time_100ns}
        resource_receipt = measurement.get("measurement_receipt")
        if not isinstance(resource_receipt, dict) or \
                resource_receipt.get("complete") is not True or \
                resource_receipt.get("phase") != "sample" or \
                resource_receipt.get("identity") != identity_wire or \
                resource_receipt.get("handle_identity_before") != identity_wire or \
                resource_receipt.get("handle_identity_after") != identity_wire or \
                resource_receipt.get("event_sequence") != attempt:
            raise AssertionError("fake first standard sample lacks retained-handle resource evidence")
        if type(measurement.get("rss_bytes")) is not int or measurement["rss_bytes"] < 0 or \
                type(measurement.get("cpu_user_seconds")) is not float or \
                type(measurement.get("cpu_system_seconds")) is not float or \
                type(measurement.get("cmdline")) is not list or \
                any(type(part) is not str for part in measurement["cmdline"]):
            raise AssertionError("fake first standard sample lacks complete standard metric values")
        row = {
            "pid": root.pid,
            "create_time_100ns": root.creation_time_100ns,
            "working_set_bytes": measurement["rss_bytes"],
            "user_cpu_seconds": measurement["cpu_user_seconds"],
            "system_cpu_seconds": measurement["cpu_system_seconds"],
            "name": witness.row.name,
            "ppid": witness.row.ppid,
            "cmdline": list(measurement["cmdline"]),
        }
        sample = {
            "sample_index": 1,
            "sample_complete": True,
            "errors": [],
            "sample_attempt_count": attempt,
            "root_process_identity": {
                "pid": root.pid,
                "create_time_100ns": root.creation_time_100ns,
            },
            "root_identity_match_count": 1,
            "expected_process_count": 1,
            "observed_process_count": 1,
            "processes": [row],
            "process_tree_working_set_bytes": row["working_set_bytes"],
            "process_tree_user_cpu_seconds": row["user_cpu_seconds"],
            "process_tree_system_cpu_seconds": row["system_cpu_seconds"],
        }
        sample_path = self.ack_directory / "samples.jsonl"
        encoded = (json.dumps(sample, sort_keys=True, separators=(",", ":")) + "\n").encode()
        with sample_path.open("wb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        source_reference = {
            "kind": "managed_root_create_source",
            "identity": {"pid": root.pid,
                         "creation_time_100ns": root.creation_time_100ns},
            "receipt": dict(witness.source_receipt),
            "measurement_receipt": dict(measurement["measurement_receipt"]),
        }
        receipt = {
            "schema": "fca-standard-first-sample-receipt-v1",
            "sample_index": 1,
            "sample_complete": True,
            "standard_metrics": True,
            "source_attempt_id": attempt,
            "snapshot_complete": True,
            "root_identity": {"pid": root.pid,
                              "creation_time_100ns": root.creation_time_100ns},
            "source_history_refs": [{
                "complete": True,
                "sequence": witness.source_receipt["sequence"],
                "reference": source_reference,
            }],
            "samples_file": {
                "path": str(sample_path.resolve()),
                "bytes": len(encoded),
                "sha256": hashlib.sha256(encoded).hexdigest(),
                "flush": True,
                "fsync": True,
            },
        }
        return receipt, sample, measurement

    def accept_root_startup(self):
        receipt, sample, measurement = self.record_first_standard_sample()
        self.session.resume_root_after_ack(initial_sample_receipt=receipt)
        return receipt, sample, measurement

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        self.temp.cleanup()


class ManagedProcessLifecycleControls(unittest.TestCase):
    """Eight fake-boundary controls for the frozen lifecycle contract."""

    CORE_SHA256 = "ADAB05284991EABF611B5F5DF2F04245C02245BC3462C5D4FCA47C1C2B15E928"
    CONTRACT_SHA256 = "D78112C83FFE90D40F652E230B41F15524F836EFA68FAE1ADEAD0FC9F10DCBE0"
    CLARIFICATION_SHA256 = "A3F524C8731E41AAB9A41E3D8A82FAE15A14D72AD7BDD1A962E6881A46757711"

    @classmethod
    def setUpClass(cls):
        import importlib.util
        import sys

        cls.repo_root = Path(__file__).resolve().parents[3]
        live_core_path = cls.repo_root / "tools" / "execution" / "windows_process_lifecycle.py"
        candidate_core_path = (cls.repo_root / "runs" / "e" / "t2_post_query_boundary_repair_20260928_r1" /
                               "postimage" / "tools" / "execution" /
                               "windows_process_lifecycle.py")
        selected_core = os.environ.get("FCA_QA_LIFECYCLE_CORE_SOURCE")
        if selected_core is None:
            core_path = live_core_path
        else:
            selected_path = Path(selected_core)
            if not selected_path.is_absolute():
                raise AssertionError("FCA_QA_LIFECYCLE_CORE_SOURCE must be an absolute path")
            core_path = selected_path.resolve(strict=True)
            allowed_sources = {live_core_path.resolve(strict=False),
                               candidate_core_path.resolve(strict=False)}
            if core_path not in allowed_sources:
                raise AssertionError("lifecycle source override is outside the two owned exact source paths")
        contract_path = cls.repo_root / "runs" / "e" / "lifecycle_systemic_repair_20260927_r1" / "contract.json"
        clarification_path = (cls.repo_root / "runs" / "e" / "lifecycle_systemic_repair_20260927_r1" /
                             "interface_clarifications.json")
        core_source_bytes_before = core_path.read_bytes()
        core_source_sha_before = hashlib.sha256(core_source_bytes_before).hexdigest()
        for path, expected in ((contract_path, cls.CONTRACT_SHA256),
                               (clarification_path, cls.CLARIFICATION_SHA256)):
            raw = path.read_bytes()
            actual = hashlib.sha256(raw).hexdigest()
            if actual != expected.lower():
                raise AssertionError(f"{path} SHA-256 {actual} != frozen pin {expected}")
        if core_source_sha_before != cls.CORE_SHA256.lower():
            raise AssertionError(
                f"{core_path} SHA-256 {core_source_sha_before} != frozen pin {cls.CORE_SHA256}")
        spec = importlib.util.spec_from_file_location("managed_process_lifecycle_under_test", core_path)
        if spec is None or spec.loader is None:
            raise AssertionError("could not construct pinned lifecycle module loader")
        module = importlib.util.module_from_spec(spec)
        module.__source_sha256__ = core_source_sha_before
        sys.modules[spec.name] = module
        source_code = compile(core_source_bytes_before, str(core_path), "exec",
                              dont_inherit=True)
        exec(source_code, module.__dict__)
        core_source_bytes_after = core_path.read_bytes()
        core_source_sha_after = hashlib.sha256(core_source_bytes_after).hexdigest()
        if (core_source_sha_after != core_source_sha_before or
                core_source_bytes_after != core_source_bytes_before):
            raise AssertionError(
                f"{core_path} source bytes changed while the pinned module was executing")
        cls.lifecycle = module

    @staticmethod
    def _assert_failed_create_cleanup(test, harness, identity, event):
        timeline = harness.timeline
        terminations = [(index, item) for index, item in enumerate(timeline)
                        if item[0] == "terminate_process" and item[1] == identity]
        duplicates = [(index, item) for index, item in enumerate(timeline)
                      if item[0] == "duplicate" and item[1] == identity and
                      item[2] == event.process_handle and len(item) > 3]
        continue_indices = [index for index, item in enumerate(timeline)
                            if item[0] == "continue" and item[1] == harness.core.CREATE_PROCESS_DEBUG_EVENT
                            and item[2] == identity.pid and item[3] == identity.creation_time_100ns]
        test.assertEqual(harness.api.handle_identity.get(event.process_handle), identity)
        test.assertTrue(terminations, "failed CREATE must terminate the exact observed generation handle")
        test.assertEqual(len(duplicates), 1,
                         "failed CREATE must retain one exact-generation duplicate for exit proof")
        test.assertTrue(continue_indices, "failed CREATE must release/drain its event after termination")
        test.assertEqual(timeline[min(continue_indices)][5], id(event),
                         "rejected CREATE must continue the exact observed event object")
        test.assertEqual(harness.api.handle_identity.get(terminations[0][1][2]), identity)
        test.assertLess(terminations[0][0], min(continue_indices),
                        "CREATE event cannot continue before failed generation is contained")
        duplicate_handle = duplicates[0][1][3]
        exit_event = harness.api.exit_events[identity]
        exit_continues = [(index, item) for index, item in enumerate(timeline)
                          if item[0] == "continue" and
                          item[1] == harness.core.EXIT_PROCESS_DEBUG_EVENT and
                          item[2] == identity.pid and
                          item[3] == identity.creation_time_100ns]
        test.assertEqual(len(exit_continues), 1,
                         "contained CREATE must drain its actual EXIT_PROCESS event")
        test.assertEqual(exit_continues[0][1][5], id(exit_event),
                         "abort must continue the actual EXIT_PROCESS event for this generation")
        wait_indices = [(index, item) for index, item in enumerate(timeline)
                        if item[0] == "wait_handle" and item[1] == identity]
        code_indices = [(index, item) for index, item in enumerate(timeline)
                        if item[0] == "exit_code" and item[1] == identity]
        duplicate_closes = [index for index, item in enumerate(timeline)
                            if item[0] == "close_handle" and item[1] == duplicate_handle]
        test.assertEqual(len(wait_indices), 1)
        test.assertEqual(wait_indices[0][1][2], duplicate_handle,
                         "abort wait must use its retained exact-generation duplicate")
        test.assertEqual(len(code_indices), 1)
        test.assertEqual(code_indices[0][1][2], duplicate_handle,
                         "abort exit-code read must use the same retained duplicate")
        test.assertEqual(len(duplicate_closes), 1)
        test.assertLess(min(continue_indices), exit_continues[0][0])
        test.assertLess(exit_continues[0][0], wait_indices[0][0])
        test.assertLess(wait_indices[0][0], code_indices[0][0])
        test.assertLess(code_indices[0][0], duplicate_closes[0])
        drained = [item for item in harness.observer.events
                   if item.get("event") == "rejected_create_abort_drained" and
                   item.get("event_pid") == identity.pid]
        test.assertEqual(len(drained), 1)
        test.assertTrue(drained[0]["exit_code_matches_event"])
        test.assertFalse(any(item[0] == "ack_published" and item[1] == identity for item in timeline),
                         "rejected birth must not publish an ACK")

    def test_immediate_exit_keeps_startup_and_exit_resource_proofs_separate(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            ack = h.ack_publications[0][0]
            self.assertEqual(set(ack), {
                "schema", "session_id", "scope_sha256", "child_pid", "child_creation_time_100ns",
                "parent_pid", "parent_creation_time_100ns", "monitor_pid", "monitor_creation_time_100ns",
                "registration_sequence", "handle_duplicated", "identity_registered", "job_bound",
                "creation_sample_measured", "resume_permitted", "full_run_resource_complete"})
            self.assertIs(ack["full_run_resource_complete"], False)
            self.assertIs(h.session.resource_sampling_complete, False)
            self.assertFalse(any(item[0] == "continue" and
                                 item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                 item[2] == root.pid for item in h.timeline),
                             "root CREATE must remain pending after its startup ACK")
            ack_publish = next(i for i, item in enumerate(h.timeline)
                               if item[0] == "ack_publication_callback")
            receipt, sample, measurement = h.record_first_standard_sample()
            self.assertEqual(receipt["source_attempt_id"], 1)
            self.assertEqual(sample["root_process_identity"], {
                "pid": root.pid, "create_time_100ns": root.creation_time_100ns})
            self.assertIs(measurement["measurement_receipt"]["complete"], True)
            sample_receipt = measurement["measurement_receipt"]
            sample_measure = next(i for i, item in enumerate(h.timeline)
                                  if item[0] == "resource_measurement_recorded" and
                                  item[1] == "sample" and
                                  item[2] == root.pid and
                                  item[3] == root.creation_time_100ns and
                                  item[4] == receipt["source_attempt_id"] and
                                  item[5] == sample_receipt)
            self.assertLess(ack_publish, sample_measure)
            self.assertFalse(any(item[0] == "continue" and
                                 item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                 item[2] == root.pid for item in h.timeline),
                             "first sample collection must not release root CREATE")
            invalid_receipts = [None]
            malformed = dict(receipt)
            malformed["schema"] = "wrong-schema"
            invalid_receipts.append(malformed)
            incomplete = dict(receipt)
            incomplete["sample_complete"] = False
            invalid_receipts.append(incomplete)
            wrong_generation = json.loads(json.dumps(receipt))
            wrong_generation["root_identity"]["creation_time_100ns"] += 1
            invalid_receipts.append(wrong_generation)
            for invalid in invalid_receipts:
                with self.subTest(receipt=invalid):
                    with self.assertRaises(core.LifecycleError):
                        h.session.resume_root_after_ack(initial_sample_receipt=invalid)
                    self.assertFalse(any(item[0] == "continue" and
                                         item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                         item[2] == root.pid for item in h.timeline))
                    self.assertFalse(any(item[0] == "resume_thread" for item in h.timeline))
            original_deadline = h.session._deadline
            h.session._deadline = time.monotonic() - 1.0
            with self.assertRaises(core.LifecycleError):
                h.session.resume_root_after_ack(initial_sample_receipt=receipt)
            self.assertFalse(any(item[0] == "continue" and
                                 item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                 item[2] == root.pid for item in h.timeline),
                             "expired startup deadline must leave the root CREATE held")
            h.session._deadline = original_deadline
            release = h.session.resume_root_after_ack(initial_sample_receipt=receipt)
            self.assertEqual(release["initial_sample_receipt"], receipt,
                             "the release receipt must preserve the complete validated sample receipt")
            create_continues = [item for item in h.timeline
                                if item[0] == "continue" and
                                item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                item[2] == root.pid]
            self.assertEqual(len(create_continues), 1,
                             "a valid first-sample receipt permits one exact root CREATE Continue")
            self.assertEqual(create_continues[0][5], id(h.api.root_create_event),
                             "ContinueDebugEvent must release the originally held root CREATE event")
            self.assertFalse(any(item[0] == "resume_thread" for item in h.timeline),
                             "debug-event release must not call ResumeThread")
            create_continue = next(i for i, item in enumerate(h.timeline)
                                   if item[0] == "continue" and
                                   item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                   item[2] == root.pid)
            self.assertLess(sample_measure, create_continue)
            h.api.queue.append(h.api.add_exit_event(root, 0))
            self.assertEqual(h.session.wait(timeout=1), 0)
            receipt = h.session.exit_receipts[0]
            self.assertTrue(receipt.exit_proof_complete)
            self.assertTrue(receipt.resource_measurement_complete)
            self.assertIs(h.session.resource_sampling_complete, False)
            retained = h.registry.handle_for(root)
            self.assertEqual(h.api.resource_handle_reads[0], (root, retained))
            resource_measurements = [i for i, item in enumerate(h.timeline)
                                     if item[0] == "resource_values" and item[1] == root]
            self.assertEqual(len(resource_measurements), 3,
                             "create, accepted startup sample, and exit each require a full exact-handle read")
            exit_measurement = next(i for i, item in enumerate(h.timeline)
                                    if item[0] == "resource_measurement_recorded" and
                                    item[1] == "exit_pre_continue" and
                                    item[2] == root.pid and
                                    item[3] == root.creation_time_100ns)
            exit_continue = next(i for i, item in enumerate(h.timeline)
                                 if item[0] == "continue" and item[1] == core.EXIT_PROCESS_DEBUG_EVENT)
            self.assertLess(exit_measurement, exit_continue,
                            "exit resource receipt must be recorded before continuing EXIT_PROCESS")
            wait_index = next(i for i, item in enumerate(h.timeline)
                              if item[0] == "wait_handle" and item[1] == root)
            code_index = next(i for i, item in enumerate(h.timeline)
                              if item[0] == "exit_code" and item[1] == root)
            close_index = next(i for i, item in enumerate(h.timeline)
                               if item[0] == "close_handle" and i > exit_continue)
            self.assertLess(exit_continue, wait_index)
            self.assertLess(wait_index, code_index)
            self.assertLess(code_index, close_index)
            self.assertTrue(h.session.close()["cleanup_complete"])

        for guard_case in ("active_attempt", "pending_boundary"):
            with self.subTest(guard_case=guard_case), _LifecycleHarness(core) as h:
                root = h.session.root_identity
                valid_receipt, _, _ = h.record_first_standard_sample()
                attempt = h.session.begin_sample_attempt()
                if guard_case == "pending_boundary":
                    event = h.api.add_exit_event(root, 0)
                    h.session.observe_sample_event_arrival(event)
                    boundary = h.session.end_sample_attempt(attempt)
                    self.assertFalse(boundary.complete)
                with self.assertRaises(core.LifecycleError) as rejected:
                    h.session.resume_root_after_ack(initial_sample_receipt=valid_receipt)
                self.assertEqual(rejected.exception.stage, "resume_root",
                                 "state guards must reject before checking the now-stale attempt count")
                self.assertFalse(any(item[0] == "continue" and
                                     item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                     item[2] == root.pid for item in h.timeline),
                                 "active sample state or pending boundary must keep root CREATE held")
                self.assertFalse(any(item[0] == "resume_thread" for item in h.timeline))

    def test_exit_during_sample_is_held_until_whole_attempt_is_discarded(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            h.accept_root_startup()
            attempt = h.session.begin_sample_attempt()
            event = h.api.add_exit_event(root, 0)
            h.session.observe_sample_event_arrival(event)
            boundary = h.session.end_sample_attempt(attempt)
            self.assertEqual(boundary.attempt_id, attempt)
            self.assertIs(boundary.complete, False)
            self.assertIs(boundary.membership_changed, True)
            self.assertEqual(boundary.pending_event_codes, (core.EXIT_PROCESS_DEBUG_EVENT,))
            self.assertEqual(boundary.reason, "debug_membership_event_during_sample")
            self.assertEqual(len(h.session._pending_boundary_events), 1)
            self.assertIs(h.session._pending_boundary_events[0].event, event)
            self.assertFalse(any(item[0] == "continue" and item[1] == core.EXIT_PROCESS_DEBUG_EVENT
                                 for item in h.timeline))
            discarded_attempts = [boundary.attempt_id]
            self.assertEqual(discarded_attempts, [attempt])
            h.session.release_boundary_events()
            self.assertEqual(h.session.returncode, 0)
            self.assertTrue(h.session.exit_receipts[0].exit_proof_complete)
            self.assertIs(h.session.resource_sampling_complete, False)
            self.assertTrue(h.session.close()["cleanup_complete"])

    def test_two_growth_boundaries_discard_both_attempts_without_partial_credit(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            h.accept_root_startup()
            # The accepted startup sample used lifecycle attempt id 1. These
            # are the two whole-sample attempts in the subsequent bounded run;
            # their local retry indices remain 1 and 2.
            observed_attempts = []
            discarded_attempts = []
            for index, (pid, ticks) in enumerate(((42001, 134349400000000201),
                                                   (42002, 134349400000000202)), start=1):
                attempt = h.session.begin_sample_attempt()
                observed_attempts.append(attempt)
                _, event = h.api.add_child_event(pid, ticks, root.pid, enqueue=False)
                h.session.observe_sample_event_arrival(event)
                boundary = h.session.end_sample_attempt(attempt)
                self.assertEqual(boundary.attempt_id, attempt)
                self.assertIs(boundary.complete, False)
                self.assertIs(boundary.membership_changed, True)
                self.assertEqual(boundary.pending_event_codes, (core.CREATE_PROCESS_DEBUG_EVENT,))
                self.assertEqual(boundary.reason, "debug_membership_event_during_sample")
                self.assertEqual(len(h.session._pending_boundary_events), 1)
                self.assertIs(h.session._pending_boundary_events[0].event, event)
                self.assertFalse(any(item[0] == "continue" and item[1] == core.CREATE_PROCESS_DEBUG_EVENT
                                     and item[2] == pid for item in h.timeline))
                discarded_attempts.append(boundary.attempt_id)
                self.assertEqual(discarded_attempts, [2, 3][:index])
                h.session.release_boundary_events()
                ack_index = next(i for i, item in enumerate(h.timeline)
                                 if item[0] == "ack_published" and item[1].pid == pid)
                create_continue_index = next(i for i, item in enumerate(h.timeline)
                                              if item[0] == "continue" and
                                              item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                              item[2] == pid)
                self.assertEqual(h.timeline[create_continue_index][5], id(event),
                                 "accepted descendant must continue its exact held CREATE event")
                self.assertLess(ack_index, create_continue_index,
                                "descendant ACK publication must precede CREATE Continue")
            self.assertEqual(observed_attempts, [2, 3])
            identities = tuple(sorted((root, *h.registry.owned_handles.keys())))
            self.assertTrue(h.session.check_membership(
                [root.pid, 42001, 42002], identities))
            self.assertIs(h.session.resource_sampling_complete, False)
            identity = next(item for item in identities if item.pid == 42001)
            handle = h.session.handle_for(identity)
            row = h.observer.birth_source_witness(identity.pid, phase="managed_create",
                                                  event_sequence=99).row
            birth_open_calls_before_measurement = h.api.open_birth_handle_calls
            self.assertEqual(birth_open_calls_before_measurement, 2)
            measurement = h.session.resource_reader(
                handle, identity, row, phase="sample",
                event_receipt={"event_sequence": 99})
            self.assertEqual(h.api.open_birth_handle_calls,
                             birth_open_calls_before_measurement)
            self.assertEqual(measurement["measurement_receipt"]["identity"], {
                "pid": identity.pid, "creation_time_100ns": identity.creation_time_100ns})
            self.assertEqual(h.api.resource_handle_reads[-1], (identity, handle))
            self.assertEqual(h.api.pid_resource_reads, [])
            with self.assertRaises(core.BirthPending):
                h.session.handle_for(core.ProcessIdentity(42999, 134349400000000299))

    def test_pid_reuse_with_new_filetime_fails_before_second_birth_ack(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            h.accept_root_startup()
            first, first_event = h.api.add_child_event(42011, 134349400000000301, root.pid)
            self.assertEqual(len(h.session.pump_debug_events()), 1)
            first_ack = next(i for i, item in enumerate(h.timeline)
                             if item[0] == "ack_published" and item[1] == first)
            first_continue = next(i for i, item in enumerate(h.timeline)
                                  if item[0] == "continue" and
                                  item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                  item[2] == first.pid)
            self.assertEqual(h.timeline[first_continue][5], id(first_event),
                             "accepted generation must continue the exact observed CREATE event")
            self.assertLess(first_ack, first_continue,
                            "descendant ACK publication must precede CREATE Continue")
            second, event = h.api.add_child_event(42011, 134349400000000302, root.pid)
            with self.assertRaises(core.LifecycleError):
                h.session.pump_debug_events()
            self._assert_failed_create_cleanup(self, h, second, event)
            self.assertIn(first, h.registry.owned_handles)
            self.assertNotIn(second, h.registry.owned_handles)
            self.assertFalse(any(item[0] == "ack_published" and item[1] == second
                                 for item in h.timeline))

    def test_duplicate_handle_failure_contains_exact_create_before_continue(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            h.accept_root_startup()
            child, event = h.api.add_child_event(42021, 134349400000000401, root.pid)
            h.api.fail_duplicate_call = h.api.duplicate_call_count + 1
            with self.assertRaises(core.LifecycleError):
                h.session.pump_debug_events()
            self._assert_failed_create_cleanup(self, h, child, event)
            opened = [item[2] for item in h.timeline if item[0] == "open_birth_handle"
                      and item[1] == child]
            self.assertEqual(len(opened), 1)
            self.assertIn(opened[0], h.api.closed_handles)
            self.assertEqual(sum(item[0] == "ack_published" for item in h.timeline), 1)
            self.assertIs(h.session.resource_sampling_complete, False)

    def test_registry_rejection_and_forged_ack_never_release_uncontained_birth(self) -> None:
        core = self.lifecycle
        for mode, pid, ticks in (("raise", 42031, 134349400000000501),
                                 ("forged_return", 42032, 134349400000000502)):
            with self.subTest(mode=mode), _LifecycleHarness(core) as h:
                root = h.session.root_identity
                h.accept_root_startup()
                h.registry.next_mode = mode
                child, event = h.api.add_child_event(pid, ticks, root.pid)
                with self.assertRaises(core.LifecycleError):
                    h.session.pump_debug_events()
                self._assert_failed_create_cleanup(self, h, child, event)
                self.assertNotIn(child, h.registry.owned_handles)
                self.assertEqual(sum(item[0] == "ack_published" for item in h.timeline), 1)
                self.assertIs(h.session.resource_sampling_complete, False)

    def test_orphan_birth_without_registered_parent_is_terminated_not_adopted(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            h.accept_root_startup()
            orphan, event = h.api.add_child_event(42041, 134349400000000601, 49999)
            with self.assertRaises(core.LifecycleError):
                h.session.pump_debug_events()
            self._assert_failed_create_cleanup(self, h, orphan, event)
            self.assertNotIn(orphan, h.registry.owned_handles)
            self.assertEqual(sum(item[0] == "ack_published" for item in h.timeline), 1)
            self.assertIs(h.session.resource_sampling_complete, False)

    def test_cleanup_failure_remains_incomplete_and_preserves_handle_evidence(self) -> None:
        core = self.lifecycle
        with _LifecycleHarness(core) as h:
            root = h.session.root_identity
            h.accept_root_startup()
            h.api.queue.append(h.api.add_exit_event(root, 0))
            self.assertEqual(h.session.wait(timeout=1), 0)
            retained = h.registry.handle_for(root)
            h.api.fail_close_once.add(retained)
            summary = h.session.close()
            self.assertIs(summary["cleanup_complete"], False)
            self.assertTrue(summary["cleanup_errors"])
            self.assertIn(retained, h.registry.owned_handles.values())
            self.assertIs(h.session.resource_sampling_complete, False)

    def test_rejected_root_create_persists_zero_credit_and_closes_each_event_file_once(self) -> None:
        core = self.lifecycle
        image_handle = 624
        with _LifecycleHarness(core, registry_mode="raise",
                               root_file_handle=image_handle,
                               capture_startup_error=True) as h:
            self.assertIsInstance(h.startup_error, core.LifecycleError)
            self.assertIsNotNone(h.session)
            root = h.api.root
            event = h.api.root_create_event
            timeline = h.timeline
            terminations = [(i, item) for i, item in enumerate(timeline)
                            if item[0] == "terminate_process" and item[1] == root]
            abort_duplicate = next(item[3] for item in timeline
                                   if item[0] == "duplicate" and item[1] == root and
                                   item[2] == event.process_handle and len(item) > 3)
            create_continues = [(i, item) for i, item in enumerate(timeline)
                                if item[0] == "continue" and
                                item[1] == core.CREATE_PROCESS_DEBUG_EVENT and
                                item[2] == root.pid and
                                item[3] == root.creation_time_100ns]
            exit_event = h.api.exit_events[root]
            exit_continues = [(i, item) for i, item in enumerate(timeline)
                              if item[0] == "continue" and
                              item[1] == core.EXIT_PROCESS_DEBUG_EVENT and
                              item[2] == root.pid]
            wait_indices = [(i, item) for i, item in enumerate(timeline)
                            if item[0] == "wait_handle" and item[1] == root]
            duplicate_wait = next((i, item) for i, item in wait_indices
                                  if item[2] == abort_duplicate)
            startup_root_wait = next((i, item) for i, item in wait_indices
                                     if item[2] == h.api.root_handle)
            code_index = next(i for i, item in enumerate(timeline)
                              if item[0] == "exit_code" and item[1] == root and
                              item[2] == abort_duplicate)
            duplicate_close_index = next(i for i, item in enumerate(timeline)
                                         if item[0] == "close_handle" and
                                         item[1] == abort_duplicate)
            self.assertTrue(terminations)
            self.assertEqual(len(create_continues), 1)
            self.assertEqual(create_continues[0][1][5], id(event))
            self.assertEqual(len(exit_continues), 1)
            self.assertEqual(exit_continues[0][1][5], id(exit_event))
            self.assertEqual(len(wait_indices), 2,
                             "root CREATE containment and outer startup abort each require their own exact-handle wait")
            self.assertEqual(duplicate_wait[1][2], abort_duplicate)
            self.assertEqual(duplicate_wait[1][4], core.WAIT_OBJECT_0)
            self.assertGreater(duplicate_wait[1][3], 0,
                               "exact CREATE drain must wait within the remaining session deadline")
            self.assertEqual(startup_root_wait[1][2], h.api.root_handle)
            self.assertEqual(startup_root_wait[1][3], 0,
                             "outer startup abort must perform its distinct nonblocking root-handle check")
            self.assertEqual(startup_root_wait[1][4], core.WAIT_OBJECT_0)
            self.assertLess(terminations[0][0], create_continues[0][0])
            self.assertLess(create_continues[0][0], exit_continues[0][0])
            self.assertLess(exit_continues[0][0], duplicate_wait[0])
            self.assertLess(duplicate_wait[0], code_index)
            self.assertLess(code_index, duplicate_close_index)
            self.assertLess(duplicate_close_index, startup_root_wait[0])
            self.assertEqual(len(h.observer.birth_measurements), 1,
                             "rejected root CREATE must retain its complete raw birth measurement")
            self.assertIs(h.observer.birth_measurements[0]["complete"], True)
            self.assertEqual(h.api.closed_debug_files, [image_handle],
                             "CREATE hFile must reach the native close boundary exactly once")
            self.assertEqual([item for item in h.timeline if item[0] == "close_debug_file"],
                             [("close_debug_file", image_handle)])
            started = next(item for item in h.observer.events
                           if item.get("event") == "rejected_create_abort_started")
            self.assertEqual(started["registration_state"], "rejected_before_registration")
            self.assertEqual(started["image_file_close"]["event_sequence"], 1)
            self.assertIs(started["image_file_close"]["complete"], True)
            self.assertEqual(started["rejection_credit_disposition"], {
                "registration": "zero", "birth_resource": "zero",
                "whole_sample": "zero", "full_lifecycle": "zero"})
            self.assertIs(started["failure_evidence"]["handle_transferred"], False)
            drained = next(item for item in h.observer.events
                           if item.get("event") == "rejected_create_abort_drained")
            self.assertEqual(drained["event_pid"], root.pid)
            self.assertIs(drained["exit_code_matches_event"], True)
            self.assertNotIn(root, h.registry.owned_handles)
            self.assertEqual(h.ack_publications, [])
            self.assertIs(h.session.resource_sampling_complete, False)
            startup_abort = next(item for item in h.observer.events
                                 if item.get("event") == "startup_abort")
            self.assertIs(startup_abort["root_create_registered"], False)
            self.assertEqual(startup_abort["root_wait_result"], core.WAIT_OBJECT_0)
            self.assertIs(startup_abort["cleanup_complete"], False,
                          "outer handle signal cannot substitute for an unregistered held CREATE receipt")

            duplicate_close = h.session._close_debug_event_file_once(
                event, 1, "same_exact_event_recheck")
            self.assertIs(duplicate_close["complete"], True)
            self.assertIs(duplicate_close["already_closed"], True)
            self.assertIs(duplicate_close["close_attempted"], False)
            self.assertEqual(len(h.api.closed_debug_files), 1)
            changed_thread = __import__("dataclasses").replace(
                event, thread_id=event.thread_id + 1)
            mismatched = h.session._close_debug_event_file_once(
                changed_thread, 1, "reused_sequence_changed_thread")
            self.assertIs(mismatched["complete"], False)
            self.assertEqual(mismatched["error"]["repr"],
                             "debug event sequence was reused with different CREATE metadata")
            self.assertEqual(mismatched["event_thread_id"], event.thread_id + 1)
            self.assertIs(mismatched["close_attempted"], False)
            self.assertEqual(len(h.api.closed_debug_files), 1,
                             "a same-sequence event with a changed thread must never close hFile again")
            self.assertTrue(any(item.get("purpose") ==
                                "debug_event_file_close_sequence_mismatch" and
                                item.get("event_sequence") == 1 and
                                item.get("event_thread_id") == event.thread_id + 1
                                for item in h.session._cleanup_errors),
                            "the altered-thread replay must remain explicit failed cleanup evidence")


    def test_delete_attribute_list_uses_pointer_sized_prototype(self) -> None:
        core = self.lifecycle
        wt = wintypes

        class FakeDllFunction:
            def __init__(self, name, callback, argtypes, restype):
                self.name = name
                self.callback = callback
                self.expected_argtypes = argtypes
                self.expected_restype = restype
                self.argtypes = None
                self.restype = ctypes.c_int
                self.calls = []

            def __call__(self, *args):
                if self.argtypes != self.expected_argtypes:
                    raise AssertionError(
                        f"{self.name} argtypes were not bound before call: "
                        f"{self.argtypes!r}")
                if self.restype is not self.expected_restype:
                    raise AssertionError(
                        f"{self.name} restype was not bound before call: "
                        f"{self.restype!r}")
                self.calls.append({"argtypes": self.argtypes,
                                   "restype": self.restype, "args": args})
                return self.callback(*args)

        def pointer_value(value):
            if value is None:
                return None
            return int(value.value if hasattr(value, "value") else value)

        duplicate_handles = iter((0x5101, 0x5102, 0x5103))
        attribute_pointers = {"initialize": [], "update": [],
                              "create": [], "delete": []}
        create_process_flags = []
        closed_handles = []

        def duplicate_handle(*args):
            target = ctypes.cast(
                args[3], ctypes.POINTER(wt.HANDLE)).contents
            target.value = next(duplicate_handles)
            return 1

        def initialize_attributes(*args):
            attribute_list = pointer_value(args[0])
            attribute_pointers["initialize"].append(attribute_list)
            required_size = ctypes.cast(
                args[3], ctypes.POINTER(ctypes.c_size_t)).contents
            if attribute_list is None:
                required_size.value = 64
                return 0
            return 1

        def update_attribute(*args):
            attribute_pointers["update"].append(pointer_value(args[0]))
            return 1

        def create_process(*args):
            create_process_flags.append(int(args[5]))
            startup = ctypes.cast(
                args[8], ctypes.POINTER(core._STARTUPINFOEX)).contents
            attribute_pointers["create"].append(
                pointer_value(startup.lpAttributeList))
            process_info = ctypes.cast(
                args[9], ctypes.POINTER(core._PROCESS_INFORMATION)).contents
            process_info.hProcess = 0x6201
            process_info.hThread = 0x6202
            process_info.dwProcessId = 6501
            process_info.dwThreadId = 6502
            return 1

        def delete_attribute_list(*args):
            attribute_pointers["delete"].append(pointer_value(args[0]))

        def close_handle(handle):
            closed_handles.append(pointer_value(handle))
            return 1

        duplicate_argtypes = [wt.HANDLE, wt.HANDLE, wt.HANDLE,
                              ctypes.POINTER(wt.HANDLE), wt.DWORD,
                              wt.BOOL, wt.DWORD]
        initialize_argtypes = [ctypes.c_void_p, wt.DWORD, wt.DWORD,
                               ctypes.POINTER(ctypes.c_size_t)]
        update_argtypes = [ctypes.c_void_p, wt.DWORD, ctypes.c_size_t,
                           ctypes.c_void_p, ctypes.c_size_t,
                           ctypes.c_void_p, ctypes.c_void_p]
        create_argtypes = [wt.LPCWSTR, wt.LPWSTR, ctypes.c_void_p,
                           ctypes.c_void_p, wt.BOOL, wt.DWORD,
                           ctypes.c_void_p, wt.LPCWSTR, ctypes.c_void_p,
                           ctypes.POINTER(core._PROCESS_INFORMATION)]

        class FakeKernel32:
            pass

        kernel32 = FakeKernel32()
        kernel32.GetCurrentProcess = lambda: ctypes.c_void_p(-1).value
        kernel32.DuplicateHandle = FakeDllFunction(
            "DuplicateHandle", duplicate_handle, duplicate_argtypes, wt.BOOL)
        kernel32.InitializeProcThreadAttributeList = FakeDllFunction(
            "InitializeProcThreadAttributeList", initialize_attributes,
            initialize_argtypes, wt.BOOL)
        kernel32.UpdateProcThreadAttribute = FakeDllFunction(
            "UpdateProcThreadAttribute", update_attribute,
            update_argtypes, wt.BOOL)
        kernel32.CreateProcessW = FakeDllFunction(
            "CreateProcessW", create_process, create_argtypes, wt.BOOL)
        kernel32.DeleteProcThreadAttributeList = FakeDllFunction(
            "DeleteProcThreadAttributeList", delete_attribute_list,
            [ctypes.c_void_p], None)
        kernel32.CloseHandle = FakeDllFunction(
            "CloseHandle", close_handle, [wt.HANDLE], wt.BOOL)

        api = object.__new__(core._Win32Api)
        api.wt = wt
        api.k32 = kernel32
        result = api._create_process_native(
            ["git.exe", "rev-parse", "HEAD"], None, None,
            (0x1101, 0x1102, 0x1103))

        self.assertEqual(result.launch_cleanup_errors, ())
        self.assertEqual(result.unclosed_temp_handles, ())
        self.assertEqual(len(kernel32.InitializeProcThreadAttributeList.calls), 2)
        initialize_calls = kernel32.InitializeProcThreadAttributeList.calls
        self.assertIsNone(initialize_calls[0]["args"][0])
        self.assertEqual(initialize_calls[0]["argtypes"], initialize_argtypes)
        self.assertEqual(initialize_calls[1]["argtypes"], initialize_argtypes)
        self.assertEqual(attribute_pointers["initialize"][0], None)
        actual_attribute_pointer = attribute_pointers["initialize"][1]
        self.assertIsNotNone(actual_attribute_pointer)
        self.assertGreater(actual_attribute_pointer, 0xFFFFFFFF)
        self.assertEqual(attribute_pointers["update"], [actual_attribute_pointer])
        self.assertEqual(attribute_pointers["create"], [actual_attribute_pointer])
        self.assertEqual(attribute_pointers["delete"], [actual_attribute_pointer])
        delete_call = kernel32.DeleteProcThreadAttributeList.calls[0]
        self.assertEqual(delete_call["argtypes"], [ctypes.c_void_p])
        self.assertIsNone(delete_call["restype"])
        self.assertEqual(pointer_value(delete_call["args"][0]),
                         actual_attribute_pointer)
        self.assertEqual(len(closed_handles), 3)
        self.assertEqual(len(create_process_flags), 1)
        self.assertTrue(create_process_flags[0] & core.DEBUG_PROCESS)
        self.assertFalse(create_process_flags[0] & 0x00000004)  # Win32 CREATE_SUSPENDED


if __name__ == "__main__":
    unittest.main(verbosity=2)
