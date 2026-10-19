from __future__ import annotations

import copy
import json
import math
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from typing import Any
from unittest.mock import patch

import supervise_r16_root_audit_r21_v1 as audit


class FakeProcess:
    def __init__(
        self,
        pid: int,
        create_time: float,
        *,
        name: str = "python.exe",
        ppid: int = 1,
        rss: Any = 1024,
        cpu_user: Any = 0.5,
        cpu_system: Any = 0.25,
        cmdline: list[str] | None = None,
        descendants: list["FakeProcess"] | None = None,
    ) -> None:
        self.pid = pid
        self.created = create_time
        self._name = name
        self._ppid = ppid
        self._rss = rss
        self._cpu_user = cpu_user
        self._cpu_system = cpu_system
        self._cmdline = cmdline if cmdline is not None else [name]
        self.descendants = descendants or []
        self.fail_children: Exception | None = None
        self.fail_rss: Exception | None = None
        self.fail_cpu: Exception | None = None
        self.fail_name: Exception | None = None
        self.fail_cmdline: Exception | None = None
        self.fail_kill: Exception | None = None
        self.fail_wait: Exception | None = None
        self.exit_code = 0
        self.killed = False
        self.create_calls = 0
        self.create_time_values: list[Any] | None = None
        self.wait_calls = 0

    def create_time(self) -> Any:
        self.create_calls += 1
        if self.create_time_values:
            if len(self.create_time_values) > 1:
                return self.create_time_values.pop(0)
            return self.create_time_values[0]
        return self.created

    def children(self, recursive: bool = False) -> list["FakeProcess"]:
        if self.fail_children:
            raise self.fail_children
        return list(self.descendants)

    def memory_info(self) -> SimpleNamespace:
        if self.fail_rss:
            raise self.fail_rss
        return SimpleNamespace(rss=self._rss)

    def cpu_times(self) -> SimpleNamespace:
        if self.fail_cpu:
            raise self.fail_cpu
        return SimpleNamespace(user=self._cpu_user, system=self._cpu_system)

    def ppid(self) -> int:
        return self._ppid

    def name(self) -> str:
        if self.fail_name:
            raise self.fail_name
        return self._name

    def cmdline(self) -> list[str]:
        if self.fail_cmdline:
            raise self.fail_cmdline
        return list(self._cmdline)

    def kill(self) -> None:
        if self.fail_kill:
            raise self.fail_kill
        self.killed = True

    def wait(self, timeout: float | None = None) -> int:
        self.wait_calls += 1
        if self.fail_wait:
            raise self.fail_wait
        return self.exit_code


def valid_launch_binding(identity: tuple[int, float]) -> dict[str, Any]:
    ticks = audit._unix_seconds_filetime_roundtrip(identity[1])
    created = audit._filetime_unix_seconds(ticks)
    roundtrip_ticks = audit._unix_seconds_filetime_roundtrip(created)
    return {
        "schema": "native-g1g2-r21-popen-process-identity-binding-v1",
        "method": "exact raw FILETIME ticks: Popen handle vs fresh PID handles before/after psutil lookup",
        "filetime_ticks_per_second": audit.FILETIME_TICKS_PER_SECOND,
        "complete": True,
        "identity_match": True,
        "popen_pid": identity[0],
        "popen_handle_pid": identity[0],
        "popen_handle_creation_filetime_ticks": ticks,
        "fresh_pid_handle_before_pid": identity[0],
        "fresh_pid_handle_before_creation_filetime_ticks": ticks,
        "fresh_pid_handle_after_pid": identity[0],
        "fresh_pid_handle_after_creation_filetime_ticks": ticks,
        "psutil_process_pid": identity[0],
        "psutil_process_create_time": created,
        "psutil_create_time_expected_from_filetime": created,
        "psutil_create_time_filetime_roundtrip_ticks": roundtrip_ticks,
        "psutil_float_filetime_roundtrip_delta_ticks": roundtrip_ticks - ticks,
        "psutil_float_crosscheck_semantics":
            "diagnostic_only; generation decided by exact raw handle FILETIME ticks",
        "generation_identity": {"pid": identity[0], "creation_filetime_ticks": ticks},
        "errors": [],
    }


def r21_protocol() -> dict[str, Any]:
    parent = json.loads(audit.R16_PARENT_PROTOCOL.read_text(encoding="utf-8"))
    julia = parent["execution_plan"]["julia_executable"]
    output_leaf = "r16_root_supervised_actual_r21_v1"
    supervisor = str((audit.TEST_DIR / "supervise_r16_root_audit_r21_v1.py").resolve())
    python = str(Path(audit.sys.executable).resolve())
    parent_pins = [
        {"role": role, "path": path.relative_to(audit.ROOT).as_posix(), "sha256": digest}
        for role, (path, digest) in {
            "r16_parent_protocol": (audit.R16_PARENT_PROTOCOL, audit.R16_PARENT_PROTOCOL_SHA256),
            "r16_runner": (audit.R16_RUNNER, audit.R16_RUNNER_SHA256),
            "r16_reporter": (audit.R16_RESOURCE_REPORTER, audit.R16_RESOURCE_REPORTER_SHA256),
            "r18_parent_protocol": (audit.R18_PARENT_PROTOCOL, audit.R18_PARENT_PROTOCOL_SHA256),
            "r18_reporter": (audit.R18_REPORTER, audit.R18_REPORTER_SHA256),
            "r18_test": (audit.R18_TEST, audit.R18_TEST_SHA256),
        }.items()
    ]
    return {
        "schema": "native-g1g2-r21-root-supervisor-protocol-v1",
        "identity_type_contract": copy.deepcopy(audit.IDENTITY_TYPE_CONTRACT),
        "runtime_dispatch_status": copy.deepcopy(audit.R21_RUNTIME_DISPATCH_STATUS),
        "windows_idle_inventory_rule": copy.deepcopy(audit.WINDOWS_IDLE_INVENTORY_RULE),
        "r20_runtime_failure_context": copy.deepcopy(audit.R20_RUNTIME_FAILURE_CONTEXT),
        "r16_limits": {
            "stage_order": list(audit.STAGE_ORDER),
            "wall_seconds_per_stage": audit.STAGE_WALL_SECONDS,
            "sampled_rss_stop_threshold_bytes": audit.RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": audit.SAMPLE_INTERVAL_SECONDS,
            "julia_threads": 1,
            "blas_threads": 1,
            "julia_heap_size_hint": audit.HEAP_HINT,
            "compiler_mode": audit.COMPILER_MODE,
        },
        "claim_ceiling": {
            "numerical_status": "not_established",
            "physical_status": "unknown",
            "solver_success_claimed": False,
            "numerical_credit_before_outer_audit": False,
            "numerical_credit_on_monitor_incomplete": False,
        },
        "receipt_policy": {
            "schema": "root_owned_write_once_run_receipt_v1",
            "write_once": True,
            "cryptographic_signature": False,
            "authenticate_by": "root-owned child launch and measured provenance",
            "binds_actual_outer_supervisor_argv": True,
            "binds_r16_runner_protocol_summary_stage_raw_and_artifact_hashes": True,
            "binds_r18_reporter_path_sha256": True,
            "binds_report_output_to_outer_receipt_via_write_once_followup": True,
        },
        "dispatch": {
            "python_executable": python,
            "python_executable_sha256": audit.sha256_file(Path(python)),
            "python_executable_bytes": Path(python).stat().st_size,
            "julia_executable": julia["path"],
            "julia_executable_sha256": julia["sha256"],
            "julia_executable_bytes": julia["bytes"],
            "output_leaf": output_leaf,
            "static_argv": [python, "-B", supervisor, "--static-only", "--output", output_leaf],
            "runtime_argv": [python, "-B", supervisor, "--output", output_leaf,
                             "--dispatch-actual", audit.ACTUAL_DISPATCH_TOKEN],
        },
        "monitoring_contract": {
            "rss_semantics": "sampled_stop_trigger_not_instantaneous_hard_cap",
            "rss_threshold_bytes": audit.RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": audit.SAMPLE_INTERVAL_SECONDS,
            "threshold_hit_or_overshoot_disposition": "resource_failure",
            "popen_generation_binding": "exact_raw_filetime_ticks_from_original_and_fresh_pid_handles_before_after_psutil",
            "filetime_ticks_per_second": audit.FILETIME_TICKS_PER_SECOND,
            "psutil_float_create_time_semantics":
                "diagnostic_only; exact raw handle FILETIME ticks decide generation",
            "stage_wall_seconds": audit.STAGE_WALL_SECONDS,
            "stage_order": list(audit.STAGE_ORDER),
            "compiler_mode": audit.COMPILER_MODE,
            "heap_hint": audit.HEAP_HINT,
            "incomplete_observation_disposition": "resource_monitor_incomplete_no_numerical_credit",
            "windows_idle_inventory_rule": copy.deepcopy(audit.WINDOWS_IDLE_INVENTORY_RULE),
        },
        "frozen_files": [
            {
                "role": role,
                "path": path.relative_to(audit.ROOT).as_posix(),
                "bytes": path.stat().st_size,
                "sha256": audit.sha256_file(path),
            }
            for role, path in (
                ("supervisor", audit.TEST_DIR / "supervise_r16_root_audit_r21_v1.py"),
                ("python_tests", audit.TEST_DIR / "test_r16_root_audit_r21_v1.py"),
            )
        ],
        "frozen_parent_pins": parent_pins,
    }


class TreeSampleTests(unittest.TestCase):
    def test_identity_comparison_validates_both_operands_before_python_equality(self) -> None:
        self.assertTrue(audit._same_identity((501, 1.0), (501, 1.0)))
        for malformed in ((501, True), (501, 1), (True, 1.0), (501, float("nan")),
                          (501, float("inf")), (501, -1.0)):
            with self.subTest(malformed=malformed):
                with self.assertRaises(ValueError):
                    audit._same_identity((501, 1.0), malformed)

    def _tree(self, **child_kwargs: Any) -> tuple[FakeProcess, FakeProcess]:
        child = FakeProcess(202, 20.0, name="julia.exe", ppid=101, **child_kwargs)
        root = FakeProcess(101, 10.0, name="python.exe", ppid=1, descendants=[child])
        return root, child

    def test_complete_sample_binds_root_and_every_member(self) -> None:
        root, _ = self._tree()
        row = audit.sample_process_tree(root, sample_index=1, sampled_utc="2026-09-24T00:00:00Z")
        self.assertTrue(row["complete"])
        self.assertEqual((row["root_pid"], row["root_create_time"]), (101, 10.0))
        self.assertEqual(row["root_row_count"], 1)
        self.assertEqual(row["rss_bytes"], 2048)
        self.assertEqual(row["measured_process_identities"], [
            {"pid": 101, "create_time": 10.0},
            {"pid": 202, "create_time": 20.0},
        ])
        self.assertEqual(audit.validate_outer_samples([row], (101, 10.0)), [])

    def test_exact_root_generation_guard_passes_and_detects_one_tick_reuse(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        created = audit._filetime_unix_seconds(ticks)
        root, _ = self._tree()
        root.created = created
        good = audit.sample_process_tree(
            root, sample_index=1, expected_root_creation_filetime_ticks=ticks,
            pid_handle_identity_reader=lambda pid: (101, ticks),
        )
        self.assertTrue(good["complete"])
        self.assertTrue(good["root_generation_guard_complete"])
        self.assertEqual(good["root_creation_filetime_ticks"], ticks)

        root, _ = self._tree()
        root.created = created
        observed = iter([(101, ticks), (101, ticks + 1)])
        bad = audit.sample_process_tree(
            root, sample_index=2, expected_root_creation_filetime_ticks=ticks,
            pid_handle_identity_reader=lambda pid: next(observed),
        )
        self.assertFalse(bad["complete"])
        self.assertFalse(bad["root_generation_guard_complete"])
        self.assertIn("root_generation_changed_during_process_tree_sample",
                      [item.get("reason") for item in bad["errors"]])

    def test_recursive_enumeration_error_preserves_error_and_fails_closed(self) -> None:
        root, _ = self._tree()
        root.fail_children = PermissionError("denied child traversal")
        row = audit.sample_process_tree(root, sample_index=1)
        self.assertFalse(row["complete"])
        self.assertIn("recursive_process_enumeration", [x["phase"] for x in row["errors"]])
        self.assertIsNone(row["rss_bytes"])
        self.assertEqual(row["root_row_count"], 1)

    def test_rss_and_cpu_read_failures_are_incomplete(self) -> None:
        for attribute in ("fail_rss", "fail_cpu"):
            with self.subTest(attribute=attribute):
                root, child = self._tree()
                setattr(child, attribute, PermissionError(attribute))
                row = audit.sample_process_tree(root, sample_index=1)
                self.assertFalse(row["complete"])
                self.assertTrue(row["errors"])

    def test_invalid_rss_values_fail_closed_without_coercion(self) -> None:
        for value in (-1, True, "123", 1.5, float("nan"), float("inf")):
            with self.subTest(value=value):
                root, child = self._tree(rss=value)
                row = audit.sample_process_tree(root, sample_index=1)
                self.assertFalse(row["complete"])
                self.assertIn("member_resource_or_identity_read", [x["phase"] for x in row["errors"]])

    def test_invalid_cpu_values_and_nonfinite_times_fail_closed(self) -> None:
        for value in (True, -0.1, float("nan"), float("inf"), "0.5"):
            with self.subTest(value=value):
                root, child = self._tree(cpu_user=value)
                row = audit.sample_process_tree(root, sample_index=1)
                self.assertFalse(row["complete"])

    def test_identity_fields_require_exact_native_types_and_finite_time(self) -> None:
        for pid, created in ((True, 10.0), (0, 10.0), (-101, 10.0), (101, True), (101, 10),
                             (101, float("nan")), (101, float("inf")), (101, -1.0)):
            with self.subTest(pid=pid, created=created):
                root = FakeProcess(pid, created)
                row = audit.sample_process_tree(root, sample_index=1)
                self.assertFalse(row["complete"])
                self.assertIsNone(row["rss_bytes"])

    def test_pid0_exception_does_not_extend_to_stage_wait_or_kill_identity(self) -> None:
        idle = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        sample = audit.sample_process_tree(idle, sample_index=1)
        self.assertFalse(sample["complete"])
        self.assertIsNone(sample["rss_bytes"])
        receipts, wait_errors = audit.process_exit_receipts({(0, 0.0): idle}, [(0, 0.0)])
        self.assertEqual(receipts, [])
        self.assertTrue(wait_errors)
        kill = audit.terminate_and_wait({(0, 0.0): idle}, [(0, 0.0)])
        self.assertFalse(kill["complete"])
        self.assertFalse(idle.killed)

    def test_member_1_0_then_true_alias_fails_after_resource_reads(self) -> None:
        root, child = self._tree()
        child.create_time_values = [1.0, True]
        row = audit.sample_process_tree(root, sample_index=1)
        self.assertFalse(row["complete"])
        self.assertIsNone(row["rss_bytes"])
        self.assertTrue(any("native float" in item.get("exception_message", "")
                            for item in row["errors"]))

    def test_duplicate_pid_with_reused_create_time_fails_closed(self) -> None:
        root = FakeProcess(101, 10.0, name="python.exe", ppid=1)
        root.descendants = [FakeProcess(101, 11.0, name="julia.exe", ppid=101)]
        row = audit.sample_process_tree(root, sample_index=1)
        self.assertFalse(row["complete"])
        self.assertTrue(any("pid_reused" in x.get("exception_message", "")
                            for x in row["errors"]))

    def test_root_identity_change_during_sample_is_incomplete(self) -> None:
        root, _ = self._tree()
        def changing_create_time() -> float:
            root.create_calls += 1
            return 10.0 if root.create_calls < 4 else 12.0
        root.create_time = changing_create_time  # type: ignore[method-assign]
        row = audit.sample_process_tree(root, sample_index=1)
        self.assertFalse(row["complete"])
        self.assertTrue(any("changed" in x.get("exception_message", "")
                            for x in row["errors"]))

    def test_complete_flag_without_unique_outer_root_is_rejected(self) -> None:
        root, _ = self._tree()
        row = audit.sample_process_tree(root, sample_index=1)
        row["processes"] = [row["processes"][1]]
        row["measured_process_identities"] = [{"pid": 202, "create_time": 20.0}]
        row["discovered_process_identities"] = [{"pid": 202, "create_time": 20.0}]
        row["rss_bytes"] = row["partial_rss_bytes"] = 1024
        self.assertIn("outer_sample_1_root_process_row_not_unique",
                      audit.validate_outer_samples([row], (101, 10.0)))

    def test_outer_validator_rejects_boolean_pid_alias(self) -> None:
        root, _ = self._tree()
        row = audit.sample_process_tree(root, sample_index=1)
        row["processes"][0]["pid"] = True
        failures = audit.validate_outer_samples([row], (101, 10.0))
        self.assertIn("outer_sample_1_malformed_process_row", failures)
        self.assertIn("outer_sample_1_root_process_row_not_unique", failures)


class ProcessTerminationTests(unittest.TestCase):
    def test_exact_identity_wait_receipt(self) -> None:
        process = FakeProcess(202, 20.0, name="julia.exe")
        receipts, errors = audit.process_exit_receipts({(202, 20.0): process}, [(202, 20.0)])
        self.assertEqual(errors, [])
        self.assertEqual(receipts, [{
            "pid": 202, "create_time": 20.0, "exit_code": 0, "exit_confirmed": True,
        }])

    def test_missing_process_handle_fails_closed(self) -> None:
        receipts, errors = audit.process_exit_receipts({}, [(202, 20.0)])
        self.assertEqual(receipts, [])
        self.assertEqual(errors[0]["reason"], "process_handle_not_tracked")

    def test_pid_reuse_before_or_after_wait_fails_closed(self) -> None:
        process = FakeProcess(202, 20.0)
        process.wait = lambda timeout=None: (setattr(process, "created", 21.0) or 0)  # type: ignore[method-assign]
        receipts, errors = audit.process_exit_receipts({(202, 20.0): process}, [(202, 20.0)])
        self.assertEqual(receipts, [])
        self.assertIn("changed across exit wait", errors[0]["exception_message"])

    def test_1_0_then_true_post_wait_alias_cannot_confirm_exit(self) -> None:
        process = FakeProcess(202, 1.0)
        process.create_time_values = [1.0, 1.0, True]
        receipts, errors = audit.process_exit_receipts({(202, 1.0): process}, [(202, 1.0)])
        self.assertEqual(receipts, [])
        self.assertEqual(process.wait_calls, 1)
        self.assertTrue(errors)
        self.assertTrue(any("native float" in item.get("exception_message", "")
                            for item in errors))

    def test_1_0_then_true_kill_alias_is_rejected_before_signal(self) -> None:
        process = FakeProcess(202, 1.0)
        process.create_time_values = [1.0, True]
        result = audit.terminate_and_wait({(202, 1.0): process}, [(202, 1.0)])
        self.assertFalse(result["complete"])
        self.assertFalse(process.killed)
        self.assertEqual(result["kill_requests"], [])
        self.assertTrue(result["errors"])

    def test_boolean_pid_request_fails_before_wait_or_signal(self) -> None:
        process = FakeProcess(1, 1.0)
        receipts, wait_errors = audit.process_exit_receipts({(1, 1.0): process}, [(True, 1.0)])
        self.assertEqual(receipts, [])
        self.assertTrue(wait_errors)
        self.assertEqual(process.wait_calls, 0)
        process = FakeProcess(1, 1.0)
        result = audit.terminate_and_wait({(1, 1.0): process}, [(True, 1.0)])
        self.assertFalse(result["complete"])
        self.assertFalse(process.killed)
        self.assertFalse(result["attempted"])

    def test_boolean_process_pid_fails_before_wait_or_signal(self) -> None:
        process = FakeProcess(1, 1.0)
        process.pid = True
        receipts, errors = audit.process_exit_receipts({(1, 1.0): process}, [(1, 1.0)])
        self.assertEqual(receipts, [])
        self.assertTrue(errors)
        self.assertEqual(process.wait_calls, 0)
        process = FakeProcess(1, 1.0)
        process.pid = True
        result = audit.terminate_and_wait({(1, 1.0): process}, [(1, 1.0)])
        self.assertFalse(result["complete"])
        self.assertFalse(process.killed)

    def test_wait_failure_and_kill_failure_are_preserved(self) -> None:
        process = FakeProcess(202, 20.0)
        process.fail_kill = PermissionError("kill denied")
        process.fail_wait = TimeoutError("wait timeout")
        result = audit.terminate_and_wait({(202, 20.0): process}, [(202, 20.0)])
        self.assertFalse(result["complete"])
        self.assertEqual(len(result["errors"]), 2)
        self.assertEqual({item["phase"] for item in result["errors"]},
                         {"kill_request", "descendant_exit_wait"})
        self.assertIn("kill denied", result["errors"][0]["exception_message"])

    def test_successful_termination_requires_exact_kill_and_wait(self) -> None:
        process = FakeProcess(202, 20.0)
        result = audit.terminate_and_wait({(202, 20.0): process}, [(202, 20.0)])
        self.assertTrue(result["complete"])
        self.assertTrue(process.killed)
        self.assertTrue(result["exit_receipts"][0]["exit_confirmed"])


class PopenGenerationBindingTests(unittest.TestCase):
    def test_popen_kill_requires_current_exact_handle_and_fresh_pid_generation(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        created = audit._filetime_unix_seconds(ticks)
        binding = valid_launch_binding((801, created))

        class FakePopen:
            pid = 801
            killed = False

            def kill(self) -> None:
                self.killed = True

        good = FakePopen()
        result = audit.kill_popen_if_bound(
            good, (801, created), binding,
            handle_identity_reader=lambda _: (801, ticks),
            pid_handle_identity_reader=lambda pid: (801, ticks),
        )
        self.assertTrue(result["signal_sent"])
        self.assertTrue(good.killed)

        reused = FakePopen()
        fresh_rows = iter([(801, True)])
        result = audit.kill_popen_if_bound(
            reused, (801, created), binding,
            handle_identity_reader=lambda _: (801, ticks),
            pid_handle_identity_reader=lambda pid: next(fresh_rows),
        )
        self.assertFalse(result["signal_sent"])
        self.assertFalse(reused.killed)
        self.assertTrue(any("malformed PID/FILETIME" in item for item in result["errors"]))

    def test_popen_control_rejects_boolean_expected_identity_before_handle_read(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        created = audit._filetime_unix_seconds(ticks)
        binding = valid_launch_binding((801, created))
        called = False

        def read_handle(_: Any) -> tuple[int, int]:
            nonlocal called
            called = True
            return 801, ticks

        errors = audit.validate_popen_generation_for_control(
            SimpleNamespace(pid=801), (801, True), binding,
            handle_identity_reader=read_handle,
        )
        self.assertEqual(errors, ["popen_control_expected_identity_malformed"])
        self.assertFalse(called)

    def test_popen_handle_and_psutil_identity_match(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        created = audit._filetime_unix_seconds(ticks)
        process = FakeProcess(801, created)
        popen = SimpleNamespace(pid=801, _handle=1234)
        observed, identity, binding = audit.bind_popen_process_identity(
            popen, process_factory=lambda pid: process,
            handle_identity_reader=lambda _: (801, ticks),
            pid_handle_identity_reader=lambda pid: (801, ticks),
        )
        self.assertIs(observed, process)
        self.assertEqual(identity, (801, created))
        self.assertTrue(binding["complete"])
        self.assertTrue(binding["identity_match"])
        self.assertEqual(binding["popen_handle_creation_filetime_ticks"], ticks)
        self.assertEqual(binding["fresh_pid_handle_before_creation_filetime_ticks"], ticks)
        self.assertEqual(binding["fresh_pid_handle_after_creation_filetime_ticks"], ticks)

    def test_psutil_float_roundtrip_delta_is_diagnostic_only(self) -> None:
        # This FILETIME value rounds through psutil's float seconds representation
        # several 100 ns ticks away from the original integer. Exact handle ticks
        # remain identical, so generation binding must still pass.
        ticks = 134346891301000007
        created = audit._filetime_unix_seconds(ticks)
        self.assertNotEqual(audit._unix_seconds_filetime_roundtrip(created), ticks)
        process = FakeProcess(801, created)
        popen = SimpleNamespace(pid=801, _handle=1234)
        observed, identity, binding = audit.bind_popen_process_identity(
            popen, process_factory=lambda pid: process,
            handle_identity_reader=lambda _: (801, ticks),
            pid_handle_identity_reader=lambda pid: (801, ticks),
        )
        self.assertIs(observed, process)
        self.assertEqual(identity, (801, created))
        self.assertTrue(binding["complete"])
        self.assertNotEqual(binding["psutil_float_filetime_roundtrip_delta_ticks"], 0)
        self.assertEqual(audit.validate_popen_generation_binding(binding, identity), [])

    def test_popen_pid_vs_handle_pid_mismatch_fails_closed(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        process = FakeProcess(801, audit._filetime_unix_seconds(ticks))
        popen = SimpleNamespace(pid=801, _handle=1234)
        _, identity, binding = audit.bind_popen_process_identity(
            popen, process_factory=lambda pid: process,
            handle_identity_reader=lambda _: (802, ticks),
            pid_handle_identity_reader=lambda pid: (801, ticks),
        )
        self.assertIsNone(identity)
        self.assertFalse(binding["complete"])
        self.assertIn("popen_pid_differs_from_process_handle_pid",
                      [error.get("reason") for error in binding["errors"]])

    def test_one_filetime_tick_pid_reuse_fails_even_when_float_seconds_alias(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        created = audit._filetime_unix_seconds(ticks)
        self.assertEqual(created, audit._filetime_unix_seconds(ticks + 1))
        process = FakeProcess(801, created)
        popen = SimpleNamespace(pid=801, _handle=1234)
        _, identity, binding = audit.bind_popen_process_identity(
            popen, process_factory=lambda pid: process,
            handle_identity_reader=lambda _: (801, ticks),
            pid_handle_identity_reader=lambda pid: (801, ticks + 1),
        )
        self.assertIsNone(identity)
        self.assertFalse(binding["complete"])
        self.assertIn("popen_and_fresh_pid_handle_generation_mismatch",
                      [error.get("reason") for error in binding["errors"]])

    def test_unreadable_original_handle_identity_fails_closed(self) -> None:
        ticks = audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)
        process = FakeProcess(801, audit._filetime_unix_seconds(ticks))
        popen = SimpleNamespace(pid=801, _handle=1234)
        _, identity, binding = audit.bind_popen_process_identity(
            popen, process_factory=lambda pid: process,
            handle_identity_reader=lambda _: (_ for _ in ()).throw(PermissionError("handle denied")),
            pid_handle_identity_reader=lambda pid: (801, ticks),
        )
        self.assertIsNone(identity)
        self.assertFalse(binding["complete"])
        self.assertIn("handle denied", binding["errors"][0]["exception_message"])

    def test_pass_flag_cannot_hide_forged_handle_generation(self) -> None:
        identity = (801, audit._filetime_unix_seconds(
            audit._unix_seconds_filetime_roundtrip(1_700_000_000.0)))
        binding = valid_launch_binding(identity)
        binding["popen_handle_creation_filetime_ticks"] += 1
        self.assertIn("popen_process_generation_binding_filetime_ticks_not_identical",
                      audit.validate_popen_generation_binding(binding, identity))


class ResidualInventoryTests(unittest.TestCase):
    def test_complete_empty_heavy_inventory(self) -> None:
        result = audit.scan_heavy_processes(lambda: [])
        self.assertTrue(result["complete"])
        self.assertIsInstance(result["sampled_utc"], str)
        self.assertEqual(result["processes"], [])
        self.assertEqual(result["errors"], [])

    def test_heavy_process_requires_complete_resources_and_identity(self) -> None:
        heavy = FakeProcess(301, 30.0, name="julia.exe", rss=4096)
        result = audit.scan_heavy_processes(lambda: [heavy])
        self.assertTrue(result["complete"])
        self.assertEqual(result["processes"][0]["pid"], 301)
        heavy.fail_rss = PermissionError("rss denied")
        result = audit.scan_heavy_processes(lambda: [heavy])
        self.assertFalse(result["complete"])
        self.assertIn("rss denied", result["errors"][0]["exception_message"])

    def test_unclassifiable_process_is_residual_unknown(self) -> None:
        unknown = FakeProcess(302, 31.0)
        unknown.fail_name = PermissionError("name denied")
        result = audit.scan_heavy_processes(lambda: [unknown])
        self.assertFalse(result["complete"])
        self.assertIn("name denied", result["errors"][0]["exception_message"])

    def test_global_process_enumeration_failure_is_incomplete(self) -> None:
        def fail() -> list[FakeProcess]:
            raise OSError("process enumeration failed")
        result = audit.scan_heavy_processes(fail)
        self.assertFalse(result["complete"])
        self.assertIn("global_process_enumeration", result["errors"][0]["phase"])

    def test_global_inventory_recheck_rejects_1_0_then_true_alias(self) -> None:
        process = FakeProcess(301, 1.0, name="python.exe")
        process.create_time_values = [1.0, True]
        result = audit.scan_heavy_processes(lambda: [process])
        self.assertFalse(result["complete"])
        self.assertEqual(result["processes"], [])
        self.assertTrue(any("native float" in item.get("exception_message", "")
                            for item in result["errors"]))

    def test_windows_pid0_idle_sentinel_is_excluded_after_exact_rechecks(self) -> None:
        idle = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        with patch.object(audit.os, "name", "nt"), \
                patch.object(audit, "psutil", SimpleNamespace(Process=FakeProcess)):
            result = audit.scan_heavy_processes(lambda: [idle])
        self.assertTrue(result["complete"])
        self.assertEqual(result["processes"], [])
        self.assertEqual(result["excluded_processes"], [{
            "pid": 0, "create_time": 0.0, "name": "System Idle Process",
            "validation": "windows_psutil_process_pid0_positive_zero_exact_name_stable",
        }])
        self.assertEqual(idle.create_calls, 2)

    def test_windows_pid0_fake_object_cannot_spoof_psutil_provider_type(self) -> None:
        if audit.psutil is None:
            self.skipTest("psutil unavailable")
        fake = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        with patch.object(audit.os, "name", "nt"):
            result = audit.scan_heavy_processes(lambda: [fake])
        self.assertFalse(result["complete"])
        self.assertEqual(result["excluded_processes"], [])
        self.assertIn("not a psutil Process object",
                      result["errors"][0].get("exception_message", ""))

        class PopenSpoof(audit.psutil.Process):
            @property
            def pid(self) -> int:
                return 0

            def create_time(self) -> float:
                return 0.0

            def name(self) -> str:
                return "System Idle Process"

        subclass_spoof = PopenSpoof()
        with patch.object(audit.os, "name", "nt"):
            subclass_result = audit.scan_heavy_processes(lambda: [subclass_spoof])
        self.assertFalse(subclass_result["complete"])
        self.assertEqual(subclass_result["excluded_processes"], [])
        self.assertIn("not a psutil Process object",
                      subclass_result["errors"][0].get("exception_message", ""))

    def test_windows_pid0_malformed_time_and_name_fail_closed(self) -> None:
        malformed = [
            (-0.0, "System Idle Process"), (True, "System Idle Process"),
            (0, "System Idle Process"), (float("nan"), "System Idle Process"),
            (float("inf"), "System Idle Process"), (-1.0, "System Idle Process"),
            (1.0, "System Idle Process"), (0.0, "Impostor Idle"),
        ]
        with patch.object(audit.os, "name", "nt"), \
                patch.object(audit, "psutil", SimpleNamespace(Process=FakeProcess)):
            for created, name in malformed:
                with self.subTest(created=created, name=name):
                    fake = FakeProcess(0, created, name=name, ppid=0)
                    result = audit.scan_heavy_processes(lambda: [fake])
                    self.assertFalse(result["complete"])
                    self.assertEqual(result["excluded_processes"], [])
                    self.assertEqual(result["errors"][0]["phase"],
                                     "windows_idle_sentinel_validation")

    def test_windows_pid0_duplicate_or_nonwindows_sentinel_fails_closed(self) -> None:
        first = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        second = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        with patch.object(audit.os, "name", "nt"), \
                patch.object(audit, "psutil", SimpleNamespace(Process=FakeProcess)):
            duplicate = audit.scan_heavy_processes(lambda: [first, second])
        self.assertFalse(duplicate["complete"])
        self.assertEqual(len(duplicate["excluded_processes"]), 1)
        self.assertIn("duplicate Windows idle sentinel",
                      duplicate["errors"][0].get("exception_message", ""))

        fake = FakeProcess(0, 0.0, name="System Idle Process", ppid=0)
        with patch.object(audit.os, "name", "posix"), \
                patch.object(audit, "psutil", SimpleNamespace(Process=FakeProcess)):
            nonwindows = audit.scan_heavy_processes(lambda: [fake])
        self.assertFalse(nonwindows["complete"])
        self.assertEqual(nonwindows["excluded_processes"], [])

        boolean_pid = FakeProcess(False, 0.0, name="System Idle Process", ppid=0)
        with patch.object(audit.os, "name", "nt"), \
                patch.object(audit, "psutil", SimpleNamespace(Process=FakeProcess)):
            malformed_pid = audit.scan_heavy_processes(lambda: [boolean_pid])
        self.assertFalse(malformed_pid["complete"])
        self.assertEqual(malformed_pid["excluded_processes"], [])

    @unittest.skipUnless(audit.os.name == "nt" and audit.psutil is not None,
                         "real Windows psutil PID 0 smoke")
    def test_real_host_windows_psutil_idle_pid0_smoke(self) -> None:
        idle = audit.psutil.Process(0)
        self.assertIs(type(idle), audit.psutil.Process)
        self.assertEqual(type(idle.pid), int)
        self.assertEqual(idle.pid, 0)
        self.assertEqual(type(idle.create_time()), float)
        self.assertEqual(idle.create_time(), 0.0)
        self.assertEqual(idle.name(), "System Idle Process")
        record = audit._windows_idle_sentinel_record(idle)
        self.assertEqual(record["pid"], 0)
        self.assertEqual(record["create_time"], 0.0)
        inventory = audit.scan_heavy_processes(lambda: [idle])
        self.assertTrue(inventory["complete"])
        self.assertEqual(inventory["processes"], [])
        self.assertEqual(inventory["excluded_processes"], [record])


class ReceiptAndProtocolTests(unittest.TestCase):
    def test_write_once_receipt_cannot_be_overwritten(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "outer_supervisor_audit.json"
            first = audit.write_new(path, {"status": "pass"})
            with self.assertRaises(FileExistsError):
                audit.write_new(path, {"status": "forged"})
            self.assertEqual(path.read_bytes(), first)

    def test_child_argv_changes_only_the_output_leaf(self) -> None:
        parent = audit._read_json(audit.R16_PARENT_PROTOCOL)
        expected = parent["execution_plan"]["expected_runtime_supervisor_argv"]
        child = audit._expected_runner_argv("r16_root_supervised_actual_r21_v1",
                                           parent["execution_plan"]["julia_executable"]["path"]
                                           if isinstance(parent["execution_plan"].get("julia_executable"), dict)
                                           else expected[-1])
        self.assertEqual(len(child), len(expected))
        self.assertEqual([value for i, value in enumerate(child) if i != 4],
                         [value for i, value in enumerate(expected) if i != 4])
        self.assertEqual(child[4], "r16_root_supervised_actual_r21_v1")

    def test_protocol_keeps_original_r16_limits_and_no_credit(self) -> None:
        protocol = r21_protocol()
        self.assertEqual(audit.verify_frozen_inputs(protocol), [])
        self.assertEqual(protocol["runtime_dispatch_status"], audit.R21_RUNTIME_DISPATCH_STATUS)
        self.assertIsNotNone(audit._runtime_dispatch_block_reason(protocol))
        self.assertEqual(protocol["r16_limits"]["sampled_rss_stop_threshold_bytes"], 2_147_483_648)
        self.assertEqual(protocol["r16_limits"]["wall_seconds_per_stage"], 480.0)
        self.assertEqual(protocol["r16_limits"]["sample_interval_seconds"], 0.2)
        self.assertEqual(protocol["claim_ceiling"]["numerical_status"], "not_established")
        self.assertEqual(protocol["claim_ceiling"]["physical_status"], "unknown")
        self.assertEqual(protocol["identity_type_contract"], audit.IDENTITY_TYPE_CONTRACT)
        self.assertEqual(protocol["monitoring_contract"]["windows_idle_inventory_rule"],
                         audit.WINDOWS_IDLE_INVENTORY_RULE)

    def test_protocol_rejects_runtime_dispatch_status_relaxation(self) -> None:
        protocol = r21_protocol()
        protocol["runtime_dispatch_status"]["eligible"] = True
        self.assertIn("r21_runtime_dispatch_status_changed_or_malformed",
                      audit.verify_frozen_inputs(protocol))
        self.assertEqual(audit._runtime_dispatch_block_reason(protocol),
                         "r21_runtime_dispatch_status_changed_or_malformed")

    def test_protocol_rejects_relaxed_identity_type_contract(self) -> None:
        protocol = r21_protocol()
        protocol["identity_type_contract"] = {"pid": "numbers accepted"}
        self.assertIn("identity_type_contract_changed_or_malformed",
                      audit.verify_frozen_inputs(protocol))

    def test_protocol_rejects_broadened_windows_idle_exemption(self) -> None:
        protocol = r21_protocol()
        protocol["monitoring_contract"]["windows_idle_inventory_rule"]["provider_gate"] = "any object"
        protocol["windows_idle_inventory_rule"] = {"platform_gate": "always"}
        errors = audit.verify_frozen_inputs(protocol)
        self.assertIn("monitoring_contract_changed_or_malformed", errors)
        self.assertIn("windows_idle_inventory_rule_changed_or_malformed", errors)

    def test_protocol_pins_r20_failed_dispatch_ancestor(self) -> None:
        protocol = r21_protocol()
        self.assertEqual(protocol["r20_runtime_failure_context"],
                         audit.R20_RUNTIME_FAILURE_CONTEXT)
        protocol["r20_runtime_failure_context"]["exit_code"] = 0
        self.assertIn("r20_runtime_failure_context_changed_or_malformed",
                      audit.verify_frozen_inputs(protocol))

    def test_root_provenance_is_not_a_cryptographic_claim(self) -> None:
        policy = r21_protocol()["receipt_policy"]
        self.assertFalse(policy["cryptographic_signature"])
        self.assertIn("root-owned", policy["authenticate_by"])
        self.assertTrue(policy["write_once"])

    def test_frozen_outer_dispatch_rejects_argv_delta(self) -> None:
        protocol = r21_protocol()
        self.assertEqual(audit.verify_frozen_inputs(protocol), [])
        protocol["dispatch"]["runtime_argv"][4] = "unexpected-leaf"
        self.assertIn("dispatch_runtime_argv_pin_mismatch",
                      audit.verify_frozen_inputs(protocol))

    def test_static_invocation_argv_is_exactly_pinned(self) -> None:
        protocol = r21_protocol()
        pinned = protocol["dispatch"]["static_argv"]
        self.assertEqual(audit._validate_invocation(protocol, "static", pinned), [])
        altered = list(pinned)
        altered[-1] = "another-output"
        self.assertEqual(audit._validate_invocation(protocol, "static", altered),
                         ["static_argv_differs_from_frozen_invocation"])

    def test_r18_parent_receipt_does_not_become_numerical_credit(self) -> None:
        protocol = r21_protocol()
        self.assertFalse(protocol["claim_ceiling"]["solver_success_claimed"])
        self.assertFalse(protocol["claim_ceiling"]["numerical_credit_before_outer_audit"])
        self.assertFalse(protocol["claim_ceiling"]["numerical_credit_on_monitor_incomplete"])


class OuterAuditFixtureTests(unittest.TestCase):
    def _make_payload(self, leaf: Path, output_name: str) -> tuple[
        dict[str, Any], list[str], tuple[int, float], list[dict[str, Any]],
        dict[tuple[int, float], FakeProcess], dict[str, dict[str, Any]],
        dict[str, dict[str, Any]], dict[str, dict[str, Any]], dict[str, dict[str, Any]],
    ]:
        leaf.mkdir(parents=True)
        julia = r"C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe"
        child_argv = audit._expected_runner_argv(output_name, julia)
        stage_commands = {name: [julia, f"--stage={name}"] for name in audit.STAGE_ORDER}
        run_protocol = {
            "schema": "native-g1g2-gridap-recorded-protocol-r16-v1",
            "run_mode": "actual",
            "execution_plan": {
                "runtime_executed": True,
                "runner_invocation_argv": child_argv,
                "expected_runtime_supervisor_argv": child_argv,
                "planned_actual_output": str(leaf.resolve()),
                "stage_commands": [
                    {"stage": name, "argv": stage_commands[name]}
                    for name in audit.STAGE_ORDER
                ],
            },
        }
        (leaf / "protocol.json").write_text(json.dumps(run_protocol), encoding="utf-8")
        (leaf / "static_preflight.json").write_text("{}\n", encoding="utf-8")
        (leaf / "parse_manifest.tsv").write_text("path\tsha256\n", encoding="utf-8")
        (leaf / "prelaunch.exit.txt").write_text("0\n", encoding="ascii")

        root_identity = (900, 90.0)
        launch_binding = valid_launch_binding(root_identity)
        root_filetime_ticks = launch_binding["popen_handle_creation_filetime_ticks"]
        root_handle = FakeProcess(900, 90.0, name="python.exe")
        handles: dict[tuple[int, float], FakeProcess] = {root_identity: root_handle}
        samples: list[dict[str, Any]] = []
        pre_scans: dict[str, dict[str, Any]] = {}
        post_scans: dict[str, dict[str, Any]] = {}
        summary_stages: list[dict[str, Any]] = []
        base = 1_790_193_600.0
        for index, name in enumerate(audit.STAGE_ORDER, start=1):
            stage_dir, start_path, final_path = audit._stage_paths(leaf, index, name)
            stage_dir.mkdir()
            start_time = base + index * 10.0
            end_time = start_time + 2.0
            start_text = datetime_utc(start_time)
            end_text = datetime_utc(end_time)
            stage_pid = 900 + index
            stage_created = 100.0 + index
            command = stage_commands[name]
            (stage_dir / "checkpoint_before_assert.json").write_text("{}\n", encoding="utf-8")
            start_path.write_text(json.dumps({
                "stage": name, "command": command, "pid": stage_pid,
                "process_create_time": stage_created, "started_utc": start_text,
            }), encoding="utf-8")
            stage_handle = FakeProcess(stage_pid, stage_created, name="julia.exe",
                                      ppid=900, cmdline=command)
            handles[(stage_pid, stage_created)] = stage_handle
            outer_rows = [
                {"pid": 900, "create_time": 90.0, "ppid": 1, "name": "python.exe",
                 "cmdline": child_argv, "rss_bytes": 100, "cpu_user_seconds": 1.0,
                 "cpu_system_seconds": 0.1},
                {"pid": stage_pid, "create_time": stage_created, "ppid": 900,
                 "name": "julia.exe", "cmdline": command, "rss_bytes": 200,
                 "cpu_user_seconds": 2.0, "cpu_system_seconds": 0.2},
            ]
            samples.append({
                "schema": "native-g1g2-r21-process-tree-sample-v1",
                "sample_index": index, "utc": datetime_utc(start_time + 1.0),
                "elapsed_seconds": float(index), "root_pid": 900,
                "root_create_time": 90.0, "root_row_count": 1,
                "root_generation_guard_required": True,
                "root_generation_guard_complete": True,
                "root_creation_filetime_ticks": root_filetime_ticks,
                "root_generation_guard_before": {
                    "pid": 900, "creation_filetime_ticks": root_filetime_ticks,
                },
                "root_generation_guard_after": {
                    "pid": 900, "creation_filetime_ticks": root_filetime_ticks,
                },
                "complete": True,
                "discovered_process_identities": [
                    {"pid": row["pid"], "create_time": row["create_time"]} for row in outer_rows
                ],
                "measured_process_identities": [
                    {"pid": row["pid"], "create_time": row["create_time"]} for row in outer_rows
                ],
                "processes": outer_rows, "partial_rss_bytes": 300, "rss_bytes": 300,
                "errors": [],
            })
            inner_sample = {
                "process_tree_processes": [{
                    "pid": stage_pid, "create_time": stage_created, "rss_bytes": 200,
                }],
            }
            (stage_dir / "samples.jsonl").write_text(json.dumps(inner_sample) + "\n", encoding="utf-8")
            (stage_dir / "stdout.raw").write_bytes(b"stage output")
            (stage_dir / "stderr.raw").write_bytes(b"")
            final = {
                "index": index, "stage": name, "root_pid": stage_pid,
                "root_process_create_time": stage_created, "command": command,
                "started_utc": start_text, "ended_utc": end_text,
                "exit_code": 0, "stop_reason": "natural_exit",
            }
            final_path.write_text(json.dumps(final), encoding="utf-8")
            summary_stages.append(final)
            pre_scans[name] = {"complete": True, "sampled_utc": datetime_utc(start_time - 1.0),
                               "processes": [], "errors": []}
            post_scans[name] = {"complete": True, "sampled_utc": datetime_utc(end_time + 1.0),
                                "processes": [], "errors": []}
        (leaf / "summary.json").write_text(json.dumps({
            "runtime_executed": True, "stages": summary_stages,
            "formal_t2_consumer_receipts_assigned": 0, "physical_status": "unknown",
        }), encoding="utf-8")
        return (run_protocol, child_argv, root_identity, samples, handles,
                pre_scans, post_scans, {name: [] for name in audit.STAGE_ORDER}, stage_commands)

    def test_positive_outer_receipt_is_bound_to_exact_run_and_r18(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            leaf = Path(temp) / "run"
            (run_protocol, child_argv, root_id, samples, handles, pre, post, _, _commands) = \
                self._make_payload(leaf, "r16_root_supervised_actual_r21_v1")
            outer_protocol = r21_protocol()
            result, failures = audit.build_outer_audit(
                leaf=leaf, protocol=outer_protocol, child_argv=child_argv,
                root_identity=root_id, runner_exit_code=0, runner_wait_confirmed=True,
                launch_identity_binding=valid_launch_binding(root_id),
                pre_inventory={"complete": True, "processes": [], "errors": []},
                post_inventory={"complete": True, "processes": [], "errors": []},
                samples=samples, handles=handles, pre_scans=pre, post_scans=post,
                forced_failures=[], external_events=[],
            )
            self.assertEqual(failures, [])
            self.assertEqual(result["audit_status"], "pass")
            self.assertEqual(result["run_root_pid_create_time"], {"pid": 900, "create_time": 90.0})
            self.assertEqual(result["stage_root_exit_receipts"], [
                {"index": 1, "stage": "parse_all", "pid": 901, "create_time": 101.0,
                 "exit_code": 0, "exit_confirmed": True},
                {"index": 2, "stage": "primary", "pid": 902, "create_time": 102.0,
                 "exit_code": 0, "exit_confirmed": True},
                {"index": 3, "stage": "fresh_replay", "pid": 903, "create_time": 103.0,
                 "exit_code": 0, "exit_confirmed": True},
            ])
            prov = result["root_owned_provenance"]
            self.assertEqual(prov["r18_reporter_sha256"], audit.R18_REPORTER_SHA256)
            self.assertTrue(prov["write_once"])
            self.assertFalse(prov["r18_reporter_sha256"] is None)

    def test_resource_event_forces_no_outer_audit_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            leaf = Path(temp) / "run"
            (_, child_argv, root_id, samples, handles, pre, post, _, _) = \
                self._make_payload(leaf, "r16_root_supervised_actual_r21_v1")
            result, failures = audit.build_outer_audit(
                leaf=leaf, protocol=r21_protocol(), child_argv=child_argv,
                root_identity=root_id, runner_exit_code=1, runner_wait_confirmed=True,
                launch_identity_binding=valid_launch_binding(root_id),
                pre_inventory={"complete": True, "processes": [], "errors": []},
                post_inventory={"complete": True, "processes": [], "errors": []},
                samples=samples, handles=handles, pre_scans=pre, post_scans=post,
                forced_failures=[], external_events=[{"kind": "sampled_rss_threshold_hit_or_overshoot"}],
            )
            self.assertIn("outer_sampled_resource_or_wall_stop_triggered", failures)
            self.assertEqual(result["audit_status"], "incomplete")
            self.assertFalse(result["claim_ceiling"]["solver_success_claimed"])

    def test_outer_receipt_requires_popen_generation_binding(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            leaf = Path(temp) / "run"
            (_, child_argv, root_id, samples, handles, pre, post, _, _) = \
                self._make_payload(leaf, "r16_root_supervised_actual_r21_v1")
            binding = valid_launch_binding(root_id)
            binding["popen_handle_creation_filetime_ticks"] += 1
            binding["identity_match"] = False
            result, failures = audit.build_outer_audit(
                leaf=leaf, protocol=r21_protocol(), child_argv=child_argv,
                root_identity=root_id, runner_exit_code=0, runner_wait_confirmed=True,
                launch_identity_binding=binding,
                pre_inventory={"complete": True, "processes": [], "errors": []},
                post_inventory={"complete": True, "processes": [], "errors": []},
                samples=samples, handles=handles, pre_scans=pre, post_scans=post,
                forced_failures=[], external_events=[],
            )
            self.assertIn("popen_process_generation_binding_incomplete", failures)
            self.assertEqual(result["audit_status"], "incomplete")

    def test_missing_required_runner_summary_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            leaf = Path(temp) / "run"
            (_, child_argv, root_id, samples, handles, pre, post, _, _) = \
                self._make_payload(leaf, "r16_root_supervised_actual_r21_v1")
            (leaf / "summary.json").unlink()
            result, failures = audit.build_outer_audit(
                leaf=leaf, protocol=r21_protocol(), child_argv=child_argv,
                root_identity=root_id, runner_exit_code=0, runner_wait_confirmed=True,
                launch_identity_binding=valid_launch_binding(root_id),
                pre_inventory={"complete": True, "processes": [], "errors": []},
                post_inventory={"complete": True, "processes": [], "errors": []},
                samples=samples, handles=handles, pre_scans=pre, post_scans=post,
                forced_failures=[], external_events=[],
            )
            self.assertIn("r16_required_payload_missing:summary.json", failures)
            self.assertEqual(result["audit_status"], "incomplete")


def datetime_utc(timestamp: float) -> str:
    from datetime import datetime, timezone
    return datetime.fromtimestamp(timestamp, timezone.utc).isoformat().replace("+00:00", "Z")


if __name__ == "__main__":
    unittest.main(verbosity=2)
