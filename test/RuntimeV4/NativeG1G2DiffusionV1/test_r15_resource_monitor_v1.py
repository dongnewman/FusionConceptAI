"""Python-only fake-process and reporter tests for r15 RSS fail-closed logic."""

from __future__ import annotations

from contextlib import nullcontext
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace

import psutil


HERE = Path(__file__).resolve().parent
RUNNER_PATH = HERE / "run_recorded_r15_v1.py"
REPORTER_PATH = HERE / "report_r15_resource_outcome_v1.py"


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = _load("native_g1g2_r15_runner_test", RUNNER_PATH)
reporter = _load("native_g1g2_r15_reporter_test", REPORTER_PATH)


class FakeProcess:
    def __init__(self, pid: int, rss: int, *, children=None,
                 children_error: Exception | None = None,
                 memory_error: Exception | None = None,
                 name: str = "fake") -> None:
        self.pid = pid
        self.rss = rss
        self.child_list = list(children or [])
        self.children_error = children_error
        self.memory_error = memory_error
        self.fake_name = name

    def children(self, recursive: bool = False):
        if self.children_error is not None:
            raise self.children_error
        return self.child_list

    def oneshot(self):
        return nullcontext()

    def memory_info(self):
        if self.memory_error is not None:
            raise self.memory_error
        return SimpleNamespace(rss=self.rss)

    def cpu_times(self):
        return SimpleNamespace(user=0.25, system=0.125)

    def name(self):
        return self.fake_name

    def cmdline(self):
        return [self.fake_name]

    def create_time(self):
        return 1.0


def _complete_sample(pid: int = 201, rss: int = 120_000_000) -> dict:
    member = {
        "pid": pid,
        "name": "julia",
        "cmdline": ["julia"],
        "create_time": 1.0,
        "rss_bytes": rss,
        "cpu_user_seconds": 1.0,
        "cpu_system_seconds": 0.5,
    }
    return {
        "utc": "2026-09-24T00:00:00Z",
        "elapsed_seconds": 0.0,
        "root_pid": pid,
        "process_tree_sample_complete": True,
        "process_tree_sample_errors": [],
        "process_tree_expected_member_count": 1,
        "process_tree_measured_member_count": 1,
        "process_tree_pids": [pid],
        "process_tree_discovered_pids": [pid],
        "process_tree_measured_pids": [pid],
        "process_tree_processes": [member],
        "process_tree_rss_bytes": rss,
        "partial_process_tree_rss_bytes": rss,
    }


def _incomplete_access_denied_sample(parent_rss: int = 1_200_000_000) -> dict:
    sample = _complete_sample(301, parent_rss)
    sample.update({
        "process_tree_sample_complete": False,
        "process_tree_sample_errors": [{
            "phase": "member_resource_read",
            "pid": 302,
            "category": "access_denied",
            "reason": None,
            "exception_type": "AccessDenied",
            "exception_message": "psutil.AccessDenied (pid=302)",
            "exception_repr": "psutil.AccessDenied(pid=302)",
        }],
        "process_tree_expected_member_count": 2,
        "process_tree_measured_member_count": 1,
        "process_tree_pids": [301, 302],
        "process_tree_discovered_pids": [301, 302],
        "process_tree_measured_pids": [301],
        "process_tree_processes": [
            sample["process_tree_processes"][0],
            {"pid": 302, "name": None, "cmdline": None, "create_time": None,
             "rss_bytes": None, "cpu_user_seconds": None, "cpu_system_seconds": None},
        ],
    })
    return sample


def _write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def _report_from_sample(sample: dict) -> dict:
    with tempfile.TemporaryDirectory() as temp:
        leaf = Path(temp)
        stage_dir = leaf / "01_parse_all"
        stage_dir.mkdir()
        raw = (json.dumps(sample, sort_keys=True) + "\n").encode("utf-8")
        (stage_dir / "samples.jsonl").write_bytes(raw)
        peak = sample["process_tree_rss_bytes"]
        monitor_complete = sample.get("process_tree_sample_complete") is True
        failure = None if monitor_complete else {
            "failure_class": "resource_monitor_incomplete",
            "sample_index": 1,
            "partial_process_tree_rss_bytes": sample.get("partial_process_tree_rss_bytes"),
            "process_tree_pids": sample.get("process_tree_pids"),
            "process_tree_measured_pids": sample.get("process_tree_measured_pids"),
            "raw_errors": sample.get("process_tree_sample_errors"),
        }
        final = {
            "schema": "native-g1g2-recorded-stage-v1",
            "index": 1,
            "stage": "parse_all",
            "exit_code": 15 if not monitor_complete else 0,
            "stop_reason": "resource_monitor_incomplete" if not monitor_complete else "natural_exit",
            "sample_count": 1,
            "peak_process_tree_rss_bytes": peak,
            "peak_process_tree_rss_sample_index": 1,
            "peak_process_tree_rss_sample_utc": sample["utc"],
            "peak_process_tree_rss_sample_elapsed_seconds": sample["elapsed_seconds"],
            "peak_process_tree_rss_sample_bytes": peak,
            "resource_monitor_complete": monitor_complete,
            "resource_monitor_status": "complete" if monitor_complete else "incomplete",
            "resource_monitor_failure": failure,
        }
        _write_json(stage_dir / "final.json", final)
        _write_json(leaf / "summary.json", {
            "schema": "native-g1g2-run-summary-v1",
            "mode": "actual",
            "runtime_executed": True,
            "status": "pass" if monitor_complete else "resource_monitor_incomplete",
            "resource_monitor_complete": monitor_complete,
            "stages": [final],
            "numerical_status": "not_established",
            "physical_status": "unknown",
        })
        return reporter.build_report(leaf)


class TreeResourcesFailClosedTests(unittest.TestCase):
    def test_complete_tree_reports_full_sum_and_member_set(self) -> None:
        child = FakeProcess(12, 300, name="child")
        parent = FakeProcess(11, 200, children=[child], name="parent")
        result = runner.tree_resources(parent)
        self.assertTrue(result["complete"])
        self.assertEqual(result["partial_rss_bytes"], 500)
        self.assertEqual(result["discovered_pids"], [11, 12])
        self.assertEqual(result["measured_pids"], [11, 12])
        self.assertEqual(result["expected_member_count"], 2)
        self.assertEqual(result["errors"], [])

    def test_access_denied_member_read_is_incomplete(self) -> None:
        parent = FakeProcess(41, 1_200_000_000, name="parent")
        child = FakeProcess(42, 1_200_000_000,
            memory_error=psutil.AccessDenied(pid=42, name="child"), name="child")
        parent.child_list = [child]
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["partial_rss_bytes"], 1_200_000_000)
        self.assertEqual(result["discovered_pids"], [41, 42])
        self.assertEqual(result["measured_pids"], [41])
        self.assertEqual(result["errors"][0]["category"], "access_denied")
        self.assertEqual(result["errors"][0]["exception_type"], "AccessDenied")
        self.assertTrue(result["errors"][0]["exception_message"])
        self.assertTrue(result["errors"][0]["exception_repr"])

    def test_access_denied_child_discovery_is_incomplete(self) -> None:
        parent = FakeProcess(51, 1_200_000_000,
            children_error=psutil.AccessDenied(pid=51, name="parent"))
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["partial_rss_bytes"], 1_200_000_000)
        self.assertEqual(result["discovered_pids"], [51])
        self.assertIsNone(result["expected_member_count"])
        self.assertEqual(result["errors"][0]["phase"], "children_enumeration")
        self.assertEqual(result["errors"][0]["category"], "access_denied")

    def test_disappearing_child_is_incomplete(self) -> None:
        parent = FakeProcess(61, 900)
        child = FakeProcess(62, 800,
            memory_error=psutil.NoSuchProcess(pid=62, name="child"), name="child")
        parent.child_list = [child]
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["category"], "process_disappeared_during_sample")
        self.assertEqual(result["errors"][0]["exception_type"], "NoSuchProcess")
        self.assertEqual(result["discovered_pids"], [61, 62])

    def test_unexpected_member_read_error_is_incomplete(self) -> None:
        parent = FakeProcess(71, 1000)
        child = FakeProcess(72, 1000, memory_error=PermissionError("denied"))
        parent.child_list = [child]
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["category"], "unexpected_sample_error")
        self.assertEqual(result["errors"][0]["exception_type"], "PermissionError")


class ResourceOutcomeFailClosedTests(unittest.TestCase):
    def test_reporter_preserves_partial_rss_pids_and_exception(self) -> None:
        report = _report_from_sample(_incomplete_access_denied_sample())
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertTrue(report["resource_failure"])
        stage = report["stage_reports"][0]
        self.assertTrue(stage["resource_monitor_incomplete"])
        details = stage["incomplete_samples"][0]
        self.assertEqual(details["partial_process_tree_rss_bytes"], 1_200_000_000)
        self.assertEqual(details["process_tree_discovered_pids"], [301, 302])
        self.assertEqual(details["process_tree_measured_pids"], [301])
        self.assertEqual(details["raw_errors"][0]["exception_type"], "AccessDenied")
        self.assertFalse(report["claim_boundary"]["solver_success_claimed"])
        self.assertFalse(report["claim_boundary"]["numerical_credit_on_monitor_incomplete"])
        self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")

    def test_partial_rss_over_threshold_still_means_monitor_incomplete(self) -> None:
        sample = _incomplete_access_denied_sample(2_400_000_000)
        report = _report_from_sample(sample)
        stage = report["stage_reports"][0]
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertTrue(stage["resource_failure"])
        self.assertFalse(stage["rss_threshold"]["sampled_threshold_hit_in_complete_samples"])
        self.assertTrue(stage["rss_threshold"]["partial_samples_never_clear_threshold"])

    def test_missing_completeness_marker_cannot_be_no_crossing(self) -> None:
        sample = _complete_sample()
        sample.pop("process_tree_sample_complete")
        report = _report_from_sample(sample)
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertEqual(report["stage_reports"][0]["disposition"], "resource_monitor_incomplete")

    def test_error_on_sample_marked_complete_is_fail_closed(self) -> None:
        sample = _complete_sample()
        sample["process_tree_sample_errors"] = [{
            "phase": "children_enumeration", "category": "access_denied",
            "exception_type": "AccessDenied", "exception_message": "denied",
            "exception_repr": "AccessDenied()",
        }]
        report = _report_from_sample(sample)
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertFalse(report["resource_monitor_complete"])

    def test_complete_below_threshold_sample_keeps_diagnostic_ceiling(self) -> None:
        report = _report_from_sample(_complete_sample())
        self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
        self.assertTrue(report["resource_monitor_complete"])
        self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")
        self.assertEqual(report["claim_boundary"]["physical_status"], "unknown")


if __name__ == "__main__":
    unittest.main()
