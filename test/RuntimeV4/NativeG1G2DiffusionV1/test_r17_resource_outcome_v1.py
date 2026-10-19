"""Python-only fake-process and reporter tests for r17 PID-reuse-safe RSS reporting."""

from __future__ import annotations

from contextlib import nullcontext
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

import psutil


HERE = Path(__file__).resolve().parent
RUNNER_PATH = HERE / "run_recorded_r16_v1.py"
REPORTER_PATH = HERE / "report_r17_resource_outcome_v1.py"
LEGACY_REPORTER_PATH = HERE / "report_r16_resource_outcome_v1.py"


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


runner = _load("native_g1g2_r16_runner_test", RUNNER_PATH)
reporter = _load("native_g1g2_r17_reporter_test", REPORTER_PATH)
legacy_reporter = _load("native_g1g2_r16_legacy_reporter_test", LEGACY_REPORTER_PATH)


class FakeProcess:
    def __init__(self, pid: int, rss: int, *, children=None,
                 children_error: Exception | None = None,
                 memory_error: Exception | None = None,
                 kill_error: Exception | None = None,
                 name: str = "fake") -> None:
        self.pid = pid
        self.rss = rss
        self.child_list = list(children or [])
        self.children_error = children_error
        self.memory_error = memory_error
        self.kill_error = kill_error
        self.kill_called = False
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

    def kill(self):
        self.kill_called = True
        if self.kill_error is not None:
            raise self.kill_error


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


def _complete_parent_child_sample() -> dict:
    sample = _complete_sample(301, 80_000_000)
    child = {
        "pid": 302,
        "name": "julia-worker",
        "cmdline": ["julia-worker"],
        "create_time": 7.0,
        "rss_bytes": 40_000_000,
        "cpu_user_seconds": 0.25,
        "cpu_system_seconds": 0.125,
    }
    sample.update({
        "process_tree_expected_member_count": 2,
        "process_tree_measured_member_count": 2,
        "process_tree_pids": [301, 302],
        "process_tree_discovered_pids": [301, 302],
        "process_tree_measured_pids": [301, 302],
        "process_tree_processes": [sample["process_tree_processes"][0], child],
        "process_tree_rss_bytes": 120_000_000,
        "partial_process_tree_rss_bytes": 120_000_000,
    })
    return sample


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


def _report_from_sample(
    sample: dict,
    *,
    include_outer_audit: bool = True,
    receipt_create_time_overrides: dict[int, float] | None = None,
    omit_descendant_receipts: bool = False,
    stage_root_create_time_override: object | None = None,
    include_legacy: bool = False,
) -> dict | tuple[dict, dict]:
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
        sample_identities = []
        for process_row in sample.get("process_tree_processes", []):
            if not isinstance(process_row, dict):
                continue
            pid = process_row.get("pid")
            created = process_row.get("create_time")
            if type(pid) is int and pid > 0 and type(created) in (int, float) and \
                    not isinstance(created, bool) and created > 0:
                sample_identities.append((pid, float(created)))
        root_pid = sample["root_pid"]
        root_identity = next(
            (identity for identity in sample_identities if identity[0] == root_pid),
            (root_pid, 1.0),
        )
        final = {
            "schema": "native-g1g2-recorded-stage-v1",
            "index": 1,
            "stage": "parse_all",
            "exit_code": 15 if not monitor_complete else 0,
            "stop_reason": "resource_monitor_incomplete" if not monitor_complete else "natural_exit",
            "sample_count": 1,
            "root_pid": sample["root_pid"],
            "root_process_create_time": root_identity[1],
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
        if include_outer_audit:
            overrides = receipt_create_time_overrides or {}
            descendant_identities = sorted({
                identity for identity in sample_identities if identity != root_identity
            })
            stage_descendant_receipts = [
                {"pid": pid,
                 "create_time": overrides.get(pid, created),
                 "exit_confirmed": True}
                for pid, created in descendant_identities
            ]
            if omit_descendant_receipts:
                stage_descendant_receipts = []
            stage_audit = {
                "index": 1,
                "stage": "parse_all",
                "root_pid": root_pid,
                "root_process_create_time": (
                    root_identity[1] if stage_root_create_time_override is None
                    else stage_root_create_time_override
                ),
                "root_exit_confirmed": True,
                "pre_stage_inventory_complete": True,
                "post_stage_inventory_complete": True,
                "pre_stage_residual_heavy_processes": [],
                "post_stage_residual_heavy_processes": [],
                "tracked_descendant_exit_receipts": stage_descendant_receipts,
            }
            aggregate_descendants = [
                {"index": 1, "stage": "parse_all", **receipt}
                for receipt in stage_descendant_receipts
            ]
            _write_json(leaf / reporter.OUTER_AUDIT_FILENAME, {
                "schema": "native-g1g2-root-outer-supervisor-residual-audit-v1",
                "audit_owner": "root_dispatch_controller",
                "audit_status": "pass",
                "run_mode": "actual",
                "runtime_executed": True,
                "run_root_pid_create_time": {"pid": 900, "create_time": 1.0},
                "pre_run_inventory_complete": True,
                "post_run_inventory_complete": True,
                "post_run_heavy_process_inventory": [],
                "supervised_runner": {
                    "pid": 900,
                    "create_time": 1.0,
                    "exit_confirmed": True,
                },
                "residual_scan_before_and_after_each_stage": True,
                "residual_scan_completeness": {
                    "pre_run_inventory_complete": True,
                    "post_run_inventory_complete": True,
                    "stages": [{"index": 1, "stage": "parse_all",
                                "pre_stage_inventory_complete": True,
                                "post_stage_inventory_complete": True}],
                },
                "stage_root_exit_receipts": [{
                    "index": 1, "stage": "parse_all", "pid": root_pid,
                    "create_time": root_identity[1], "exit_confirmed": True,
                }],
                "tracked_descendant_exit_receipts": aggregate_descendants,
                "stages": [stage_audit],
            })
        current_report = reporter.build_report(leaf)
        if include_legacy:
            return current_report, legacy_reporter.build_report(leaf)
        return current_report


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

    def test_invalid_rss_native_type_and_negative_values_fail_closed(self) -> None:
        for invalid in (-1, True, "123", 1.5):
            with self.subTest(invalid=invalid):
                result = runner.tree_resources(FakeProcess(81, invalid))
                self.assertFalse(result["complete"])
                self.assertEqual(result["partial_rss_bytes"], 0)
                self.assertEqual(result["measured_pids"], [])
                self.assertEqual(result["errors"][0]["category"], "invalid_rss_value")
                self.assertEqual(result["errors"][0]["raw_value_type"], type(invalid).__name__)
                self.assertEqual(result["errors"][0]["raw_value_repr"], repr(invalid))

    def test_kill_tree_preserves_enumeration_kill_and_wait_failures(self) -> None:
        denied = psutil.AccessDenied(pid=91, name="parent")
        parent = FakeProcess(91, 100, children_error=denied)
        with mock.patch.object(runner.psutil, "wait_procs", side_effect=RuntimeError("wait broke")):
            result = runner.kill_tree(parent)
        self.assertTrue(parent.kill_called)
        self.assertFalse(result["enumeration_complete"])
        self.assertFalse(result["internal_members_complete"])
        phases = {row["phase"] for row in result["errors"]}
        self.assertIn("termination_children_enumeration", phases)
        self.assertIn("termination_wait", phases)
        self.assertFalse(result["all_enumerated_members_exit_confirmed"])

        child = FakeProcess(92, 50, kill_error=PermissionError("kill denied"))
        parent = FakeProcess(93, 70, children=[child])
        with mock.patch.object(runner.psutil, "wait_procs", side_effect=RuntimeError("wait broke")):
            result = runner.kill_tree(parent)
        self.assertTrue(child.kill_called)
        self.assertTrue(parent.kill_called)
        phases = {row["phase"] for row in result["errors"]}
        self.assertIn("termination_kill", phases)
        self.assertIn("termination_wait", phases)
        self.assertFalse(result["internal_members_complete"])

    def test_kill_tree_records_confirmed_descendant_exits(self) -> None:
        child = FakeProcess(102, 50)
        parent = FakeProcess(101, 70, children=[child])
        with mock.patch.object(runner.psutil, "wait_procs", return_value=([child, parent], [])):
            result = runner.kill_tree(parent)
        self.assertTrue(result["all_enumerated_members_exit_confirmed"])
        self.assertEqual(result["tracked_descendant_exit_receipts"], [{
            "pid": 102,
            "create_time": 1.0,
            "role": "descendant",
            "exit_confirmed": True,
            "confirmation_method": "psutil.wait_procs_gone_set",
        }])
        self.assertTrue(result["internal_members_complete"])
        self.assertFalse(result["internal_receipt_is_full_process_tree_containment"])


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

    def test_reporter_marks_invalid_serialized_rss_incomplete(self) -> None:
        for invalid in (-1, True, "123", 1.5):
            with self.subTest(invalid=invalid):
                sample = _complete_sample()
                sample["process_tree_sample_complete"] = False
                sample["process_tree_sample_errors"] = [{
                    "category": "invalid_rss_value",
                    "phase": "member_resource_read",
                    "raw_value_type": type(invalid).__name__,
                    "raw_value_repr": repr(invalid),
                }]
                sample["process_tree_measured_member_count"] = 0
                sample["process_tree_measured_pids"] = []
                sample["process_tree_processes"][0]["rss_bytes"] = invalid
                sample["process_tree_rss_bytes"] = 0
                sample["partial_process_tree_rss_bytes"] = 0
                report = _report_from_sample(sample)
                self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
                self.assertTrue(report["stage_reports"][0]["resource_monitor_incomplete"])
                self.assertFalse(report["claim_boundary"]["numerical_credit_on_monitor_incomplete"])

    def test_missing_outer_supervisor_audit_fails_closed(self) -> None:
        report = _report_from_sample(_complete_sample(), include_outer_audit=False)
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertFalse(report["resource_monitor_complete"])
        self.assertTrue(report["resource_failure"])
        self.assertIn("outer_supervisor_audit_missing",
                      report["outer_supervisor_audit"]["failure_reasons"])

    def test_outer_supervisor_audit_descendant_receipt_gap_fails_closed(self) -> None:
        report = _report_from_sample(
            _complete_parent_child_sample(), omit_descendant_receipts=True
        )
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertIn(
            "outer_supervisor_stage[1]_observed_descendant_identity_exit_receipt_missing",
            report["outer_supervisor_audit"]["failure_reasons"],
        )

    def test_pid_reuse_with_matching_pid_but_wrong_create_time_is_rejected(self) -> None:
        sample = _complete_parent_child_sample()
        current, legacy = _report_from_sample(
            sample,
            receipt_create_time_overrides={302: 8.0},
            include_legacy=True,
        )
        self.assertEqual(legacy["run_disposition"], "no_sampled_rss_threshold_crossing")
        self.assertEqual(current["run_disposition"], "resource_monitor_incomplete")
        self.assertFalse(current["resource_monitor_complete"])
        self.assertFalse(current["claim_boundary"]["numerical_credit_on_monitor_incomplete"])
        failure_reasons = current["outer_supervisor_audit"]["failure_reasons"]
        self.assertIn(
            "outer_supervisor_stage[1]_observed_descendant_identity_exit_receipt_missing",
            failure_reasons,
        )
        self.assertIn(
            "outer_supervisor_stage[1]_aggregate_descendant_identity_receipt_missing",
            failure_reasons,
        )

    def test_exact_pid_create_time_exit_receipt_is_accepted(self) -> None:
        report = _report_from_sample(_complete_parent_child_sample())
        self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
        self.assertTrue(report["resource_monitor_complete"])
        self.assertEqual(
            report["stage_reports"][0]["observed_process_identities"],
            [{"pid": 301, "create_time": 1.0}, {"pid": 302, "create_time": 7.0}],
        )

    def test_boolean_stage_root_create_time_is_not_accepted(self) -> None:
        report = _report_from_sample(
            _complete_sample(), stage_root_create_time_override=True
        )
        self.assertEqual(report["run_disposition"], "resource_monitor_incomplete")
        self.assertIn(
            "outer_supervisor_stage[1]_root_identity_mismatch",
            report["outer_supervisor_audit"]["failure_reasons"],
        )

    def test_complete_below_threshold_sample_keeps_diagnostic_ceiling(self) -> None:
        report = _report_from_sample(_complete_sample())
        self.assertEqual(report["run_disposition"], "no_sampled_rss_threshold_crossing")
        self.assertTrue(report["resource_monitor_complete"])
        self.assertEqual(report["claim_boundary"]["numerical_status"], "not_established")
        self.assertEqual(report["claim_boundary"]["physical_status"], "unknown")


if __name__ == "__main__":
    unittest.main()
