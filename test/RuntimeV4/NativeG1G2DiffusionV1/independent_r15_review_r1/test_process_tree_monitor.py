"""Independent Python-only adversarial tests for the frozen Native G1/G2 r15 monitor.

This tester-owned file imports the frozen runner and outcome reporter without
launching Julia. Invalid RSS assertions intentionally express the required
fail-closed contract; failures mean the frozen implementation did not meet it.
"""

from __future__ import annotations

from contextlib import nullcontext
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import psutil


ROOT = Path(__file__).resolve().parents[4]
OWNER = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1"
RUNNER_PATH = OWNER / "run_recorded_r15_v1.py"
REPORTER_PATH = OWNER / "report_r15_resource_outcome_v1.py"
PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r15_v1/r15_static_v1/protocol.json"


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = _load("independent_native_r15_runner", RUNNER_PATH)
reporter = _load("independent_native_r15_reporter", REPORTER_PATH)


class FakeProcess:
    def __init__(self, pid: int, rss, *, children=None, children_error=None,
                 memory_error=None) -> None:
        self.pid = pid
        self.rss = rss
        self._children = list(children or [])
        self._children_error = children_error
        self._memory_error = memory_error

    def children(self, recursive: bool = False):
        if self._children_error is not None:
            raise self._children_error
        return self._children

    def oneshot(self):
        return nullcontext()

    def memory_info(self):
        if self._memory_error is not None:
            raise self._memory_error
        return SimpleNamespace(rss=self.rss)

    def cpu_times(self):
        return SimpleNamespace(user=0.0, system=0.0)

    def name(self):
        return "fake"

    def cmdline(self):
        return ["fake"]

    def create_time(self):
        return 1.0


class FakeChild:
    def __init__(self, *, crossing: bool) -> None:
        self.pid = 9981
        self.crossing = crossing
        self.poll_count = 0

    def poll(self):
        self.poll_count += 1
        if self.crossing or self.poll_count == 1:
            return None
        return 0

    def wait(self):
        return 15 if self.crossing else 0

    def kill(self):
        return None


def _environment() -> dict[str, str]:
    return {
        "JULIA_LOAD_PATH": "@;.",
        "JULIA_NUM_THREADS": "1",
        "OPENBLAS_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
    }


def _run_step_with_fake_rss(rss) -> tuple[dict, Path]:
    root_pid = 9981
    observed = FakeProcess(root_pid, rss)
    crossing = type(rss) is int and rss >= runner.PROCESS_TREE_RSS_LIMIT_BYTES
    fake_child = FakeChild(crossing=crossing)
    temp = tempfile.TemporaryDirectory()
    output = Path(temp.name)
    patches = (
        patch.object(runner, "heavy_processes", return_value=[]),
        patch.object(runner.subprocess, "Popen", return_value=fake_child),
        patch.object(runner.psutil, "Process", side_effect=lambda pid: observed),
        patch.object(runner, "kill_tree", return_value=None),
        patch.object(runner.time, "sleep", return_value=None),
    )
    with patches[0], patches[1], patches[2], patches[3], patches[4]:
        final = runner.run_step(
            output, 1, "parse_all", ["python.exe", "-B", "-c", "pass"], {}, _environment()
        )
    # Attach the tempdir owner so the caller can read files before cleanup.
    final["_test_temp_owner"] = temp
    return final, output


def _write_report_leaf(final: dict, output: Path) -> dict:
    keys = (
        "stage", "index", "exit_code", "stop_reason", "sample_count",
        "peak_process_tree_rss_bytes", "peak_process_tree_rss_sample_index",
        "peak_process_tree_rss_sample_utc", "peak_process_tree_rss_sample_elapsed_seconds",
        "peak_process_tree_rss_sample_bytes", "resource_monitor_complete",
        "resource_monitor_status", "resource_monitor_failure",
    )
    summary = {
        "schema": "native-g1g2-run-summary-v1",
        "mode": "actual",
        "runtime_executed": True,
        "status": "resource_failure" if final["stop_reason"] == "process_tree_rss_limit" else "pass",
        "resource_monitor_complete": final["resource_monitor_complete"],
        "stages": [{key: final[key] for key in keys}],
        "numerical_status": "not_established",
        "physical_status": "unknown",
    }
    (output / "summary.json").write_text(json.dumps(summary) + "\n", encoding="utf-8")
    return reporter.build_report(output)


def _make_incomplete_report(rss: int) -> dict:
    root_pid = 8801
    parent = FakeProcess(
        root_pid, rss,
        children_error=psutil.AccessDenied(pid=root_pid, name="fake-root"),
    )
    observed = runner.tree_resources(parent)
    sample = {
        "utc": "2026-09-24T00:00:00Z",
        "elapsed_seconds": 0.0,
        "root_pid": root_pid,
        "process_tree_sample_complete": observed["complete"],
        "process_tree_sample_errors": observed["errors"],
        "process_tree_expected_member_count": observed["expected_member_count"],
        "process_tree_measured_member_count": observed["measured_member_count"],
        "process_tree_pids": observed["discovered_pids"],
        "process_tree_discovered_pids": observed["discovered_pids"],
        "process_tree_measured_pids": observed["measured_pids"],
        "process_tree_processes": observed["processes"],
        "process_tree_rss_bytes": observed["partial_rss_bytes"],
        "partial_process_tree_rss_bytes": observed["partial_rss_bytes"],
    }
    with tempfile.TemporaryDirectory() as temp:
        output = Path(temp)
        stage = output / "01_parse_all"
        stage.mkdir()
        (stage / "samples.jsonl").write_text(json.dumps(sample) + "\n", encoding="utf-8")
        failure = {
            "failure_class": "resource_monitor_incomplete",
            "sample_index": 1,
            "partial_process_tree_rss_bytes": observed["partial_rss_bytes"],
            "process_tree_pids": observed["discovered_pids"],
            "process_tree_measured_pids": observed["measured_pids"],
            "process_tree_expected_member_count": observed["expected_member_count"],
            "process_tree_measured_member_count": observed["measured_member_count"],
            "raw_errors": observed["errors"],
        }
        peak = observed["partial_rss_bytes"]
        final = {
            "schema": "native-g1g2-recorded-stage-v1", "index": 1, "stage": "parse_all",
            "exit_code": 15, "stop_reason": "resource_monitor_incomplete", "sample_count": 1,
            "peak_process_tree_rss_bytes": peak, "peak_process_tree_rss_sample_index": 1,
            "peak_process_tree_rss_sample_utc": sample["utc"],
            "peak_process_tree_rss_sample_elapsed_seconds": 0.0,
            "peak_process_tree_rss_sample_bytes": peak,
            "resource_monitor_complete": False, "resource_monitor_status": "incomplete",
            "resource_monitor_failure": failure,
        }
        (stage / "final.json").write_text(json.dumps(final) + "\n", encoding="utf-8")
        keys = (
            "stage", "index", "exit_code", "stop_reason", "sample_count",
            "peak_process_tree_rss_bytes", "peak_process_tree_rss_sample_index",
            "peak_process_tree_rss_sample_utc", "peak_process_tree_rss_sample_elapsed_seconds",
            "peak_process_tree_rss_sample_bytes", "resource_monitor_complete",
            "resource_monitor_status", "resource_monitor_failure",
        )
        summary = {
            "schema": "native-g1g2-run-summary-v1", "mode": "actual", "runtime_executed": True,
            "status": "resource_monitor_incomplete", "resource_monitor_complete": False,
            "stages": [{key: final[key] for key in keys}],
            "numerical_status": "not_established", "physical_status": "unknown",
        }
        (output / "summary.json").write_text(json.dumps(summary) + "\n", encoding="utf-8")
        return reporter.build_report(output)


class R15ResourceMonitorIndependentTests(unittest.TestCase):
    def test_frozen_resource_limits_are_unchanged(self) -> None:
        protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
        self.assertEqual(runner.TIMEOUT_SECONDS, 480.0)
        self.assertEqual(runner.PROCESS_TREE_RSS_LIMIT_BYTES, 2_147_483_648)
        self.assertEqual(reporter.RSS_THRESHOLD_BYTES, 2_147_483_648)
        self.assertEqual(reporter.RSS_SAMPLE_INTERVAL_SECONDS, 0.2)
        self.assertIn("time.sleep(0.2)", RUNNER_PATH.read_text(encoding="utf-8"))
        self.assertEqual(protocol["r15_budget_contract"]["wall_seconds_per_stage"], 480.0)
        self.assertEqual(protocol["compiler_strategy"]["sampled_rss_stop_threshold_bytes_unchanged"],
                         2_147_483_648)
        self.assertEqual(protocol["compiler_strategy"]["rss_sample_interval_seconds"], 0.2)
        self.assertFalse(protocol["compiler_strategy"]["numerical_status_predeclared"] == "success")

    def test_normal_root_and_child_are_counted_once(self) -> None:
        child = FakeProcess(12, 300)
        parent = FakeProcess(11, 200, children=[child])
        result = runner.tree_resources(parent)
        self.assertTrue(result["complete"])
        self.assertEqual(result["partial_rss_bytes"], 500)
        self.assertEqual(result["discovered_pids"], [11, 12])
        self.assertEqual(result["measured_pids"], [11, 12])

    def test_children_enumeration_access_denied_is_incomplete(self) -> None:
        parent = FakeProcess(21, 100, children_error=psutil.AccessDenied(pid=21, name="root"))
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["phase"], "children_enumeration")
        self.assertEqual(result["errors"][0]["category"], "access_denied")
        self.assertEqual(result["partial_rss_bytes"], 100)

    def test_member_memory_info_access_denied_is_incomplete(self) -> None:
        child = FakeProcess(32, 999, memory_error=psutil.AccessDenied(pid=32, name="child"))
        parent = FakeProcess(31, 100, children=[child])
        result = runner.tree_resources(parent)
        self.assertFalse(result["complete"])
        self.assertEqual(result["partial_rss_bytes"], 100)
        self.assertEqual(result["measured_pids"], [31])
        self.assertEqual(result["errors"][0]["phase"], "member_resource_read")

    def test_no_such_process_race_is_incomplete(self) -> None:
        child = FakeProcess(42, 999, memory_error=psutil.NoSuchProcess(pid=42, name="gone"))
        result = runner.tree_resources(FakeProcess(41, 100, children=[child]))
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["category"], "process_disappeared_during_sample")
        self.assertEqual(result["errors"][0]["exception_type"], "NoSuchProcess")

    def test_unexpected_memory_info_exception_is_incomplete(self) -> None:
        child = FakeProcess(52, 999, memory_error=RuntimeError("injected memory_info failure"))
        result = runner.tree_resources(FakeProcess(51, 100, children=[child]))
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["category"], "unexpected_sample_error")
        self.assertEqual(result["errors"][0]["exception_message"], "injected memory_info failure")

    def test_invalid_negative_rss_is_fail_closed(self) -> None:
        result = runner.tree_resources(FakeProcess(61, -1))
        self.assertFalse(result["complete"], f"negative RSS accepted: {result}")

    def test_run_step_negative_rss_cannot_pass_as_no_threshold_crossing(self) -> None:
        final, output = _run_step_with_fake_rss(-1)
        owner = final.pop("_test_temp_owner")
        try:
            self.assertFalse(
                final["resource_monitor_complete"],
                f"runner accepted negative RSS as a complete sample: {final}",
            )
        finally:
            owner.cleanup()

    def test_invalid_boolean_rss_is_fail_closed(self) -> None:
        result = runner.tree_resources(FakeProcess(62, True))
        self.assertFalse(result["complete"], f"bool RSS accepted: {result}")

    def test_invalid_numeric_string_rss_is_fail_closed(self) -> None:
        result = runner.tree_resources(FakeProcess(63, "123"))
        self.assertFalse(result["complete"], f"string RSS accepted: {result}")

    def test_invalid_fractional_float_rss_is_fail_closed(self) -> None:
        result = runner.tree_resources(FakeProcess(64, 1.5))
        self.assertFalse(result["complete"], f"float RSS accepted: {result}")

    def test_missing_rss_is_fail_closed(self) -> None:
        result = runner.tree_resources(FakeProcess(65, None))
        self.assertFalse(result["complete"])
        self.assertEqual(result["errors"][0]["phase"], "member_resource_read")

    def test_incomplete_monitor_report_never_grants_numerical_credit(self) -> None:
        report = _make_incomplete_report(1_200_000_000)
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertTrue(report["resource_failure"])
        self.assertFalse(report["claim_boundary"]["solver_success_claimed"])
        self.assertFalse(report["claim_boundary"]["numerical_credit_on_monitor_incomplete"])
        stage = report["stage_reports"][0]
        self.assertEqual(stage["rss_threshold"]["threshold_bytes"], 2_147_483_648)
        self.assertTrue(stage["rss_threshold"]["partial_samples_never_clear_threshold"])

    def test_runner_below_threshold_is_natural_exit(self) -> None:
        final, output = _run_step_with_fake_rss(runner.PROCESS_TREE_RSS_LIMIT_BYTES - 1)
        owner = final.pop("_test_temp_owner")
        try:
            self.assertEqual(final["stop_reason"], "natural_exit")
            self.assertEqual(final["exit_code"], 0)
            self.assertTrue(final["resource_monitor_complete"])
            report = _write_report_leaf(final, output)
            self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
            self.assertEqual(report["stage_reports"][0]["rss_threshold"]["threshold_bytes"],
                             2_147_483_648)
            self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")
        finally:
            owner.cleanup()

    def test_runner_exact_threshold_is_resource_failure(self) -> None:
        final, output = _run_step_with_fake_rss(runner.PROCESS_TREE_RSS_LIMIT_BYTES)
        owner = final.pop("_test_temp_owner")
        try:
            self.assertEqual(final["stop_reason"], "process_tree_rss_limit")
            self.assertEqual(final["exit_code"], 15)
            report = _write_report_leaf(final, output)
            self.assertEqual(report["run_disposition"], "resource_failure")
            self.assertEqual(report["stage_reports"][0]["rss_threshold"]["sampled_threshold_hit_in_complete_samples"],
                             True)
            self.assertFalse(report["claim_boundary"]["solver_success_claimed"])
        finally:
            owner.cleanup()

    def test_runner_above_threshold_is_resource_failure(self) -> None:
        final, output = _run_step_with_fake_rss(runner.PROCESS_TREE_RSS_LIMIT_BYTES + 1)
        owner = final.pop("_test_temp_owner")
        try:
            self.assertEqual(final["stop_reason"], "process_tree_rss_limit")
            self.assertEqual(final["exit_code"], 15)
            report = _write_report_leaf(final, output)
            self.assertEqual(report["run_disposition"], "resource_failure")
            self.assertEqual(report["stage_reports"][0]["rss_threshold"]["overshoot_bytes_in_complete_samples"], 1)
        finally:
            owner.cleanup()


if __name__ == "__main__":
    unittest.main(verbosity=2)
