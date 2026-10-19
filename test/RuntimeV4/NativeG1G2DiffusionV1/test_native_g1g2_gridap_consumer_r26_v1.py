"""Python-only preflight/contract negatives; does not launch Julia or Gridap."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run_native_g1g2_gridap_consumer_r26_v1 as r26


PROTOCOL = r26.repo_path(r26.REL_PROTOCOL)


def load_candidate() -> dict:
    return r26.load_protocol(PROTOCOL)


class R26ProtocolContractTests(unittest.TestCase):
    def test_frozen_r13_resource_and_consumer_gates(self) -> None:
        protocol = load_candidate()
        r26.validate_protocol_shape(protocol)
        self.assertEqual(protocol["limits"]["sample_interval_seconds"], 0.2)
        self.assertEqual(protocol["limits"]["wall_seconds_per_stage"], 480.0)
        self.assertEqual(protocol["limits"]["sampled_rss_stop_threshold_bytes"], 2_147_483_648)
        self.assertEqual(protocol["limits"]["julia_heap_size_hint"], "1G")
        self.assertEqual(protocol["limits"]["compiler_mode"], "--compile=min")
        self.assertEqual(protocol["execution_plan"]["stage_order"], ["parse_all", "primary", "fresh_replay"])
        self.assertTrue(protocol["fixture_and_solver_thresholds_unchanged"])
        self.assertEqual(protocol["failed_launch_cleanup_contract"],
                         r26.FAILED_LAUNCH_CLEANUP_CONTRACT)
        self.assertTrue(protocol["execution_plan"]["compile_min_is_only_non_path_argv_delta_from_R13"])
        self.assertFalse(protocol["acceptance_boundary"]["numerical_credit"])
        self.assertFalse(protocol["acceptance_boundary"]["physical_credit"])

    def test_static_and_actual_argv_roles_do_not_alias(self) -> None:
        protocol = load_candidate()
        contract = protocol["invocation_contract"]
        self.assertNotEqual(contract["static_verifier_argv"], contract["actual_supervisor_argv"])
        self.assertIn("bind_failure_fault_injection_command", protocol["static_qa"])
        r26.validate_invocation("static_verifier", contract["static_verifier_argv"], protocol)
        r26.validate_invocation("actual_supervisor", contract["actual_supervisor_argv"], protocol)
        with self.assertRaisesRegex(r26.PreflightError, "selected role"):
            r26.validate_invocation("actual_supervisor", contract["static_verifier_argv"], protocol)
        with self.assertRaisesRegex(r26.PreflightError, "selected role"):
            r26.validate_invocation("static_verifier", contract["actual_supervisor_argv"], protocol)

    def test_stage_commands_use_one_frozen_consumer_and_only_compile_min_delta(self) -> None:
        protocol = load_candidate()
        output = r26.repo_path(protocol["planned_output_leaf"])
        commands = r26.planned_stage_commands(protocol, output)
        self.assertEqual([x["stage"] for x in commands], ["parse_all", "primary", "fresh_replay"])
        primary, replay = commands[1]["argv"], commands[2]["argv"]
        self.assertEqual(primary[-2], "primary")
        self.assertEqual(replay[-2], "replay")
        self.assertEqual(primary[-3], replay[-3])
        self.assertTrue(primary[-3].endswith("focused_tests_r14_compile_min.jl"))
        for plan in commands:
            argv = plan["argv"]
            self.assertEqual(argv.count("--compile=min"), 1)
            self.assertEqual(argv.count("--threads=1"), 1)
            self.assertIn("--heap-size-hint=1G", argv)

    def test_stage_contract_mutation_is_rejected(self) -> None:
        protocol = load_candidate()
        protocol["limits"]["sample_interval_seconds"] = 0.25
        with self.assertRaisesRegex(r26.PreflightError, "resource/compiler contract"):
            r26.validate_protocol_shape(protocol)

    def test_failed_launch_cleanup_contract_mutation_is_rejected(self) -> None:
        protocol = load_candidate()
        protocol["failed_launch_cleanup_contract"]["initial_bind_failure_can_be_complete"] = True
        with self.assertRaisesRegex(r26.PreflightError, "failed Popen launch-binding cleanup"):
            r26.validate_protocol_shape(protocol)

    def test_protocol_rejects_duplicate_or_missing_source_pins(self) -> None:
        protocol = load_candidate()
        protocol["input_pins"].append(dict(protocol["input_pins"][0]))
        with self.assertRaisesRegex(r26.PreflightError, "duplicated"):
            r26.validate_protocol_shape(protocol)
        protocol = load_candidate()
        protocol["input_pins"] = [x for x in protocol["input_pins"]
                                  if x["path"] != r26.REL_FOCUSED]
        protocol["input_pin_count"] = len(protocol["input_pins"])
        with self.assertRaisesRegex(r26.PreflightError, "required consumer/helper"):
            r26.validate_protocol_shape(protocol)

    def test_pin_checker_detects_modified_input_without_dispatch(self) -> None:
        protocol = load_candidate()
        pin = next(x for x in protocol["input_pins"] if x["path"] == "Project.toml")
        original = dict(pin)
        pin["sha256"] = "0" * 64
        with self.assertRaisesRegex(r26.PreflightError, "frozen input pins"):
            r26.verify_input_pins(protocol)
        pin.update(original)

    def test_runtime_entry_requires_explicit_dispatch_mode(self) -> None:
        with self.assertRaisesRegex(r26.PreflightError, "explicit --dispatch-actual"):
            r26.main(["--protocol", str(PROTOCOL), "--output", str(r26.repo_path(r26.REL_OUTPUT))])

    def test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit(self) -> None:
        _, audit = r26._load_r23()
        below = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_147_483_647, "elapsed_seconds": 2.0}])
        hit = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_147_483_648, "elapsed_seconds": 2.0}])
        overshoot = audit.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_196_549_632, "elapsed_seconds": 242.0}])
        incomplete = audit.sampled_resource_disposition([
            {"complete": False, "rss_bytes": None, "elapsed_seconds": 2.0}])
        self.assertEqual(below["disposition"], "no_sampled_rss_threshold_crossing")
        self.assertEqual(hit["disposition"], "resource_failure")
        self.assertEqual(overshoot["disposition"], "resource_failure")
        self.assertEqual(incomplete["disposition"], "resource_monitor_incomplete")
        for result in (below, hit, overshoot, incomplete):
            self.assertFalse(result["numerical_credit"])
            self.assertEqual(result.get("physical_status"), "unknown")

    def test_r23_exact_generation_apis_are_the_only_runtime_identity_path(self) -> None:
        source = Path(r26.repo_path(r26.REL_RUNNER)).read_text(encoding="utf-8")
        for anchor in ("bind_popen_generation", "sample_process_tree",
                       "signal_exact_process", "read_process_handle_identity",
                       "query_native_process_table", "audit_residual_identities"):
            self.assertIn(anchor, source)
        self.assertNotIn("process.terminate(", source)
        self.assertNotIn("process.kill(", source)
        self.assertNotIn("create_time()", source)

    def test_root_bind_failure_routes_to_original_handle_cleanup(self) -> None:
        source = Path(r26.repo_path(r26.REL_RUNNER)).read_text(encoding="utf-8")
        self.assertIn("launch_binding_failure is not None", source)
        self.assertIn("_recover_failed_popen_launch(", source)
        self.assertIn("_cleanup_original_popen_handle_after_incomplete_tree(", source)
        self.assertIn('residual["residual_clear"] = False', source)

    def test_tree_failure_has_same_handle_fallback_and_serial_stage_stop(self) -> None:
        source = Path(r26.repo_path(r26.REL_RUNNER)).read_text(encoding="utf-8")
        self.assertIn('failure_phase="tracked_tree_cleanup_incomplete"', source)
        self.assertIn('"schema": "native-g1g2-r26-tree-cleanup-fallback-v1"', source)
        self.assertIn('"next_stage_after_tree_cleanup_incomplete": False', source)


class _FakeSnapshot:
    def __init__(self, rows: list | None = None) -> None:
        self.rows = list(rows or [])
        self.by_pid = {row.identity.pid: row for row in self.rows}


class _FakeRow:
    def __init__(self, pid: int, ticks: int, name: str = "julia.exe") -> None:
        self.identity = type("Identity", (), {"pid": pid, "create_time_100ns": ticks})()
        self.ppid = 0
        self.name = name


class _FakeProcess:
    def __init__(self, pid: int, handle: object | None, table: "_FakeTable") -> None:
        self.pid = pid
        self._handle = handle
        self._table = table
        self.wait_calls: list[float] = []

    def wait(self, timeout: float) -> int:
        self.wait_calls.append(timeout)
        if not self._table.exited:
            raise RuntimeError("injected child remains alive")
        return self._table.exit_code


class _FakeTable:
    def __init__(self, pid: int = 734, handle: object | None = None,
                 report_unbound_child: bool = False, fail_cleanup: bool = False) -> None:
        self.identity = (pid, 134345421427015664)
        self.handle = handle if handle is not None else object()
        self.exited = False
        self.exit_code = 143
        self.report_unbound_child = report_unbound_child
        self.fail_cleanup = fail_cleanup
        self.query_count = 0
        self.terminate_handles: list[object] = []
        self.wait_calls: list[float] = []

    def query_native_process_table(self) -> _FakeSnapshot:
        self.query_count += 1
        if self.report_unbound_child and self.query_count >= 2 and not self.exited:
            return _FakeSnapshot([_FakeRow(*self.identity)])
        return _FakeSnapshot()

    @staticmethod
    def validate_snapshot(snapshot: _FakeSnapshot) -> _FakeSnapshot:
        return snapshot

    @staticmethod
    def validate_identity(value: object) -> tuple[int, int]:
        if type(value) is not tuple or len(value) != 2 or \
                type(value[0]) is not int or value[0] <= 0 or \
                type(value[1]) is not int or value[1] <= 0:
            raise RuntimeError("fake identity malformed")
        return value

    def read_process_handle_identity(self, handle: object) -> tuple[int, int]:
        if handle is not self.handle:
            raise RuntimeError("wrong fake process handle")
        return self.identity

    def descendant_identities(self, snapshot: _FakeSnapshot, root_identity: tuple[int, int],
                              *, previously_tracked: object = ()) -> tuple[object, ...]:
        row = snapshot.by_pid.get(root_identity[0])
        if row is None or (row.identity.pid, row.identity.create_time_100ns) != root_identity:
            raise RuntimeError("fake root row missing")
        return (row.identity,)

    def open_exact_process_handle(self, row: _FakeRow) -> object:
        if (row.identity.pid, row.identity.create_time_100ns) != self.identity:
            raise RuntimeError("unexpected fake process generation")
        return self.handle

    def require_handle_matches_table(self, handle: object, identity: tuple[int, int],
                                     snapshot: _FakeSnapshot, **kwargs: object) -> None:
        if handle is not self.handle or identity != self.identity:
            raise RuntimeError("fake exact handle/table mismatch")
        row = snapshot.by_pid.get(identity[0])
        if row is None or (row.identity.pid, row.identity.create_time_100ns) != identity:
            raise RuntimeError("fake exact process row missing")

    def wait_for_process_exit(self, handle: object, timeout: float) -> bool:
        if handle is not self.handle:
            raise RuntimeError("wait used a different handle")
        self.wait_calls.append(timeout)
        if timeout == 0.001:
            return self.exited
        if timeout == 10.0:
            if self.fail_cleanup:
                raise RuntimeError("injected original-handle wait failure")
            self.exited = True
            return True
        raise RuntimeError("unexpected wait timeout")

    def terminate_process_handle(self, handle: object) -> None:
        if handle is not self.handle:
            raise RuntimeError("signal used a different handle")
        self.terminate_handles.append(handle)
        if self.fail_cleanup:
            raise RuntimeError("injected exact-handle terminate failure")
        self.exited = True

    def process_exit_code(self, handle: object) -> int:
        if handle is not self.handle or not self.exited:
            raise RuntimeError("exit status requested before exact handle exit")
        return self.exit_code


class _FakeAudit:
    def bind_popen_generation(self, process: _FakeProcess, snapshot: _FakeSnapshot,
                              *, handle_identity_reader: object) -> tuple[int, int]:
        raise RuntimeError("injected initial SPI bind failure")

    @staticmethod
    def global_heavy_processes(snapshot: _FakeSnapshot) -> tuple[tuple[int, int], ...]:
        heavy_names = {"julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh"}
        return tuple(sorted((row.identity.pid, row.identity.create_time_100ns)
                            for row in snapshot.rows if row.name.casefold() in heavy_names))

    @staticmethod
    def audit_residual_identities(tracked: object, snapshot: _FakeSnapshot) -> dict:
        return {"complete": True, "residual_clear": True, "residual_identities": []}

    @staticmethod
    def sampled_resource_disposition(samples: list) -> dict:
        return {"disposition": "resource_monitor_incomplete", "complete": False,
                "reason": "no_samples", "numerical_credit": False,
                "physical_credit": False, "physical_status": "unknown"}


class R26LaunchBindingFailureTests(unittest.TestCase):
    def _run_injected_stage(self, missing_handle: bool = False) -> tuple[dict, _FakeTable, Path, _FakeProcess]:
        table = _FakeTable(report_unbound_child=missing_handle)
        process = _FakeProcess(table.identity[0], None if missing_handle else table.handle, table)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r26-fake-") as temp:
            output = Path(temp)
            with patch.object(r26.subprocess, "Popen", return_value=process):
                stage = r26._run_stage(output, 1, "primary", ["fake-julia"], {},
                                       table, _FakeAudit())
            # The caller owns the temporary directory, so keep this method's
            # assertion data before cleanup; stage receipts are already loaded.
            return stage, table, output, process

    def test_bind_failure_terminates_and_waits_same_popen_handle_but_never_passes(self) -> None:
        stage, table, output, process = self._run_injected_stage()
        cleanup = stage["termination_receipt"]["original_popen_handle_cleanup"]
        self.assertEqual(table.terminate_handles, [table.handle])
        self.assertEqual(table.wait_calls, [0.001, 10.0])
        self.assertTrue(cleanup["root_handle_exit_confirmed"])
        self.assertTrue(cleanup["identity_confirmed"])
        self.assertEqual(process.wait(timeout=0), table.exit_code)
        self.assertFalse(stage["resource_monitor_complete"])
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        self.assertFalse(stage["final_residual_audit"]["residual_clear"])
        passed, _ = r26._stage_pass(output, stage, 1)
        self.assertFalse(passed)

    def test_missing_popen_handle_keeps_cleanup_and_residual_unconfirmed(self) -> None:
        stage, table, output, process = self._run_injected_stage(missing_handle=True)
        cleanup = stage["termination_receipt"]["original_popen_handle_cleanup"]
        self.assertEqual(table.terminate_handles, [])
        self.assertFalse(table.exited)
        self.assertEqual(stage["global_heavy_after"], [list(table.identity)])
        self.assertFalse(cleanup["root_handle_exit_confirmed"])
        self.assertFalse(stage["resource_monitor_complete"])
        self.assertFalse(stage["final_residual_audit"]["residual_clear"])
        self.assertTrue(stage["final_residual_audit"]["cleanup_unconfirmed"])
        self.assertIn("launched child generation is unbound",
                      stage["final_residual_audit"]["orphan_uncertainty"])
        passed, _ = r26._stage_pass(output, stage, 1)
        self.assertFalse(passed)


class _TreeFailureAudit(_FakeAudit):
    def bind_popen_generation(self, process: _FakeProcess, snapshot: _FakeSnapshot,
                              *, handle_identity_reader: object) -> tuple[int, int]:
        identity = process._table.read_process_handle_identity(process._handle)
        row = snapshot.by_pid.get(identity[0])
        if row is None or (row.identity.pid, row.identity.create_time_100ns) != identity:
            raise RuntimeError("injected root generation row missing")
        return identity

    def sample_process_tree(self, *args: object, **kwargs: object) -> dict:
        return {"schema": "fake-sample", "complete": False, "rss_bytes": None,
                "elapsed_seconds": 0.01, "discovered_identities": [],
                "failure": "injected sample incompleteness",
                "numerical_credit": False, "physical_credit": False}

    @staticmethod
    def audit_residual_identities(tracked: object, snapshot: _FakeSnapshot) -> dict:
        residual = [(row.identity.pid, row.identity.create_time_100ns)
                    for row in snapshot.rows]
        return {"complete": not residual, "residual_clear": not residual,
                "residual_identities": [list(x) for x in residual]}


class R26TrackedTreeCleanupFallbackTests(unittest.TestCase):
    def _run(self, *, fail_cleanup: bool = False) -> tuple[dict, _FakeTable, _FakeProcess, Path]:
        table = _FakeTable(report_unbound_child=True, fail_cleanup=fail_cleanup)
        process = _FakeProcess(table.identity[0], table.handle, table)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r26-tree-fallback-") as temp:
            output = Path(temp)
            with patch.object(r26.subprocess, "Popen", return_value=process), \
                    patch.object(r26, "_terminate_tracked", return_value={
                        "schema": "fake-tree-termination", "complete": False,
                        "failure": "injected tracked-tree cleanup failure"}):
                stage = r26._run_stage(output, 1, "primary", ["fake-julia"], {},
                                       table, _TreeFailureAudit())
            return stage, table, process, output

    def test_incomplete_tree_cleanup_falls_back_to_original_handle_and_stage_fails(self) -> None:
        stage, table, process, output = self._run()
        receipt = stage["termination_receipt"]
        fallback = receipt["original_popen_handle_cleanup"]
        self.assertFalse(receipt["process_tree_cleanup_complete"])
        self.assertFalse(receipt["pre_fallback_popen_wait"]["confirmed"])
        self.assertEqual(table.terminate_handles, [table.handle])
        self.assertEqual(table.wait_calls, [0.001, 10.0])
        self.assertTrue(fallback["root_handle_exit_confirmed"])
        self.assertTrue(fallback["identity_confirmed"])
        self.assertEqual(process.wait_calls, [0, 0])
        self.assertEqual(process.wait(timeout=0), table.exit_code)
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        self.assertFalse(stage["resource_monitor_complete"])
        passed, _ = r26._stage_pass(output, stage, 1)
        self.assertFalse(passed)

    def test_unconfirmed_tree_fallback_sets_orphan_uncertainty_and_unclear_residual(self) -> None:
        stage, table, process, output = self._run(fail_cleanup=True)
        fallback = stage["termination_receipt"]["original_popen_handle_cleanup"]
        residual = stage["final_residual_audit"]
        self.assertEqual(table.terminate_handles, [table.handle])
        self.assertFalse(table.exited)
        self.assertFalse(stage["termination_receipt"]["pre_fallback_popen_wait"]["confirmed"])
        self.assertEqual(process.wait_calls, [0])
        self.assertFalse(fallback["root_handle_exit_confirmed"])
        self.assertTrue(residual["cleanup_unconfirmed"])
        self.assertIn("original Popen handle exit was not confirmed",
                      residual["orphan_uncertainty"])
        self.assertFalse(residual["residual_clear"])
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        passed, _ = r26._stage_pass(output, stage, 1)
        self.assertFalse(passed)

    def test_failed_stage_sequence_never_launches_later_stages(self) -> None:
        calls: list[str] = []
        plans = [{"stage": name, "argv": ["fake", name]}
                 for name in ("parse_all", "primary", "fresh_replay")]

        def injected_stage(output: Path, index: int, name: str, argv: list[str],
                           environment: object, table: object, audit: object) -> dict:
            calls.append(name)
            return {"stage": name, "stop_reason": "resource_monitor_incomplete",
                    "root_exit_code": None, "resource_monitor_complete": False}

        with patch.object(r26, "_run_stage", side_effect=injected_stage):
            stages, failure = r26._run_stage_sequence(Path("."), plans, {}, object(), object())
        self.assertEqual(calls, ["parse_all"])
        self.assertEqual(len(stages), 1)
        self.assertIn("stop_reason=resource_monitor_incomplete", failure or "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
