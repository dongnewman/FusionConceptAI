"""Python-only preflight/contract negatives; does not launch Julia or Gridap."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import run_native_g1g2_gridap_consumer_r28_v1 as r28


PROTOCOL = r28.repo_path(r28.REL_PROTOCOL)


def load_candidate() -> dict:
    return r28.load_protocol(PROTOCOL)


class R28ProtocolContractTests(unittest.TestCase):
    def test_frozen_r13_resource_and_consumer_gates(self) -> None:
        protocol = load_candidate()
        r28.validate_protocol_shape(protocol)
        self.assertEqual(protocol["limits"]["sample_interval_seconds"], 0.2)
        self.assertEqual(protocol["limits"]["wall_seconds_per_stage"], 480.0)
        self.assertEqual(protocol["limits"]["sampled_rss_stop_threshold_bytes"], 2_147_483_648)
        self.assertEqual(protocol["limits"]["julia_heap_size_hint"], "1G")
        self.assertEqual(protocol["limits"]["compiler_mode"], "--compile=min")
        self.assertEqual(protocol["execution_plan"]["stage_order"], ["parse_all", "primary", "fresh_replay"])
        self.assertTrue(protocol["fixture_and_solver_thresholds_unchanged"])
        self.assertEqual(protocol["failed_launch_cleanup_contract"],
                         r28.FAILED_LAUNCH_CLEANUP_CONTRACT)
        self.assertTrue(protocol["execution_plan"]["compile_min_is_only_non_path_argv_delta_from_R13"])
        self.assertFalse(protocol["acceptance_boundary"]["numerical_credit"])
        self.assertFalse(protocol["acceptance_boundary"]["physical_credit"])
        self.assertEqual(protocol["sampled_tracked_race_recovery_contract"],
                         r28.SAMPLED_TRACKED_RACE_RECOVERY_CONTRACT)

    def test_static_and_actual_argv_roles_do_not_alias(self) -> None:
        protocol = load_candidate()
        contract = protocol["invocation_contract"]
        self.assertNotEqual(contract["static_verifier_argv"], contract["actual_supervisor_argv"])
        self.assertIn("bind_failure_fault_injection_command", protocol["static_qa"])
        self.assertIn("sample_race_fault_injection_command", protocol["static_qa"])
        r28.validate_invocation("static_verifier", contract["static_verifier_argv"], protocol)
        r28.validate_invocation("actual_supervisor", contract["actual_supervisor_argv"], protocol)
        with self.assertRaisesRegex(r28.PreflightError, "selected role"):
            r28.validate_invocation("actual_supervisor", contract["static_verifier_argv"], protocol)
        with self.assertRaisesRegex(r28.PreflightError, "selected role"):
            r28.validate_invocation("static_verifier", contract["actual_supervisor_argv"], protocol)

    def test_stage_commands_use_one_frozen_consumer_and_only_compile_min_delta(self) -> None:
        protocol = load_candidate()
        output = r28.repo_path(protocol["planned_output_leaf"])
        commands = r28.planned_stage_commands(protocol, output)
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
        with self.assertRaisesRegex(r28.PreflightError, "resource/compiler contract"):
            r28.validate_protocol_shape(protocol)

    def test_failed_launch_cleanup_contract_mutation_is_rejected(self) -> None:
        protocol = load_candidate()
        protocol["failed_launch_cleanup_contract"]["initial_bind_failure_can_be_complete"] = True
        with self.assertRaisesRegex(r28.PreflightError, "failed Popen launch-binding cleanup"):
            r28.validate_protocol_shape(protocol)

    def test_protocol_rejects_duplicate_or_missing_source_pins(self) -> None:
        protocol = load_candidate()
        protocol["input_pins"].append(dict(protocol["input_pins"][0]))
        with self.assertRaisesRegex(r28.PreflightError, "duplicated"):
            r28.validate_protocol_shape(protocol)
        protocol = load_candidate()
        protocol["input_pins"] = [x for x in protocol["input_pins"]
                                  if x["path"] != r28.REL_FOCUSED]
        protocol["input_pin_count"] = len(protocol["input_pins"])
        with self.assertRaisesRegex(r28.PreflightError, "required consumer/helper"):
            r28.validate_protocol_shape(protocol)

    def test_pin_checker_detects_modified_input_without_dispatch(self) -> None:
        protocol = load_candidate()
        pin = next(x for x in protocol["input_pins"] if x["path"] == "Project.toml")
        original = dict(pin)
        pin["sha256"] = "0" * 64
        with self.assertRaisesRegex(r28.PreflightError, "frozen input pins"):
            r28.verify_input_pins(protocol)
        pin.update(original)

    def test_runtime_entry_requires_explicit_dispatch_mode(self) -> None:
        with self.assertRaisesRegex(r28.PreflightError, "explicit --dispatch-actual"):
            r28.main(["--protocol", str(PROTOCOL), "--output", str(r28.repo_path(r28.REL_OUTPUT))])

    def test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit(self) -> None:
        _, audit = r28._load_r23()
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
        source = Path(r28.repo_path(r28.REL_RUNNER)).read_text(encoding="utf-8")
        for anchor in ("bind_popen_generation", "sample_process_tree",
                       "signal_exact_process", "read_process_handle_identity",
                       "query_native_process_table", "audit_residual_identities"):
            self.assertIn(anchor, source)
        self.assertNotIn("process.terminate(", source)
        self.assertNotIn("process.kill(", source)
        self.assertNotIn("create_time()", source)

    def test_root_bind_failure_routes_to_original_handle_cleanup(self) -> None:
        source = Path(r28.repo_path(r28.REL_RUNNER)).read_text(encoding="utf-8")
        self.assertIn("launch_binding_failure is not None", source)
        self.assertIn("_recover_failed_popen_launch(", source)
        self.assertIn("_cleanup_original_popen_handle_after_incomplete_tree(", source)
        self.assertIn('residual["residual_clear"] = False', source)

    def test_tree_failure_has_same_handle_fallback_and_serial_stage_stop(self) -> None:
        source = Path(r28.repo_path(r28.REL_RUNNER)).read_text(encoding="utf-8")
        self.assertIn('failure_phase="tracked_tree_cleanup_incomplete"', source)
        self.assertIn('"schema": "native-g1g2-r28-tree-cleanup-fallback-v1"', source)
        self.assertIn('"next_stage_after_tree_cleanup_incomplete": False', source)

    def test_sample_race_contract_records_exact_transition_and_forbids_unresolved_clear(self) -> None:
        protocol = load_candidate()
        contract = protocol["sampled_tracked_race_recovery_contract"]
        self.assertEqual(contract["max_retry_count_per_sampling_tick"], 1)
        self.assertTrue(contract["every_missing_tracked_generation_requires_exact_natural_exit_receipt"])
        self.assertTrue(contract["every_newly_observed_descendant_requires_exact_retained_handle_or_explicit_unaccounted"])
        self.assertEqual(contract["unaccounted_observed_generation"],
                         "resource_monitor_incomplete_residual_clear_false_no_next_stage")
        self.assertFalse(contract["numerical_credit_on_recovery"])
        self.assertFalse(contract["physical_credit_on_recovery"])
        source = Path(r28.repo_path(r28.REL_RUNNER)).read_text(encoding="utf-8")
        for anchor in ("tracked_before_sample", "sample_attempts.jsonl",
                       "_recover_missing_tracked_sample_race(",
                       "digest_observed_descendant_missing_before_handle_bind",
                       'residual["residual_clear"] = False'):
            self.assertIn(anchor, source)
        self.assertIn("ancestry_ticks: dict[int, int] = {pid: ticks for pid, ticks in tracked_ids}",
                      source)
        self.assertIn('"orphan_chain_descendant_identities"', source)


class _R28Identity:
    def __init__(self, pid: int, ticks: int) -> None:
        self.pid = pid
        self.create_time_100ns = ticks


class _R28Row:
    def __init__(self, pid: int, ticks: int, ppid: int, name: str) -> None:
        self.identity = _R28Identity(pid, ticks)
        self.ppid = ppid
        self.name = name


class _R28Snapshot:
    def __init__(self, rows: list[_R28Row]) -> None:
        self.rows = list(rows)
        self.by_pid = {row.identity.pid: row for row in self.rows}


class _R28Process:
    def __init__(self, table: "_R28RaceTable", handle: object) -> None:
        self.pid = table.root_identity[0]
        self._handle = handle
        self._table = table
        self.wait_calls: list[float] = []

    def wait(self, timeout: float) -> int:
        self.wait_calls.append(timeout)
        if self._table.root_identity not in self._table.exited:
            raise RuntimeError("injected Popen root remains active")
        return self._table.exit_codes[self._table.root_identity]


class _R28RaceTable:
    def __init__(self, *, observed_descendant_present: bool = True,
                 observed_descendant_generation: int | None = None,
                 tracked_child_exits: bool = True) -> None:
        self.root_identity = (740, 134345421427015664)
        self.tracked_child = (741, 134345421427015665)
        self.new_child = (742, 134345421427015666)
        self.root_handle = object()
        self.handles = {self.root_identity: self.root_handle}
        self.handle_ids = {id(self.root_handle): self.root_identity}
        self.exited: set[tuple[int, int]] = set()
        self.exit_codes = {self.root_identity: 0, self.tracked_child: 0, self.new_child: 0}
        self.wait_calls: list[tuple[tuple[int, int], float]] = []
        self.terminate_handles: list[object] = []
        self.close_handles: list[object] = []
        self.snapshot_calls = 0
        self.observed_descendant_present = observed_descendant_present
        self.observed_descendant_generation = observed_descendant_generation or self.new_child[1]
        self.tracked_child_exits = tracked_child_exits
        self.rows = []

    def _row(self, identity: tuple[int, int], ppid: int, name: str) -> _R28Row:
        return _R28Row(identity[0], identity[1], ppid, name)

    def query_native_process_table(self) -> _R28Snapshot:
        self.snapshot_calls += 1
        n = self.snapshot_calls
        if n == 1:
            rows: list[_R28Row] = []  # prelaunch inventory
        elif n == 2:
            rows = [self._row(self.root_identity, 1, "julia.exe")]
        elif n in (3, 4):
            rows = [self._row(self.root_identity, 1, "julia.exe"),
                    self._row(self.tracked_child, self.root_identity[0], "tracked-helper.exe")]
        else:
            rows = []
            if self.root_identity not in self.exited:
                rows.append(self._row(self.root_identity, 1, "julia.exe"))
            if self.tracked_child not in self.exited:
                rows.append(self._row(self.tracked_child, self.root_identity[0], "tracked-helper.exe"))
            if self.observed_descendant_present and self.new_child not in self.exited:
                new_id = (self.new_child[0], self.observed_descendant_generation)
                rows.append(self._row(new_id, self.root_identity[0], "git.exe"))
        self.rows = rows
        return _R28Snapshot(rows)

    @staticmethod
    def validate_snapshot(snapshot: _R28Snapshot) -> _R28Snapshot:
        return snapshot

    @staticmethod
    def validate_identity(value: object) -> tuple[int, int]:
        if type(value) not in (tuple, list) or len(value) != 2 or \
                type(value[0]) is not int or value[0] <= 0 or \
                type(value[1]) is not int or value[1] <= 0:
            raise RuntimeError("R28 fake identity is malformed")
        return value[0], value[1]

    def read_process_handle_identity(self, handle: object) -> tuple[int, int]:
        identity = self.handle_ids.get(id(handle))
        if identity is None:
            raise RuntimeError("unknown R28 fake handle")
        return identity

    def require_same_identity(self, actual: object, expected: object, *, phase: str) -> tuple[int, int]:
        left, right = self.validate_identity(actual), self.validate_identity(expected)
        if left != right:
            raise RuntimeError(f"R28 generation mismatch at {phase}")
        return left

    def descendant_identities(self, snapshot: _R28Snapshot, root_identity: tuple[int, int],
                              *, previously_tracked: object = ()) -> tuple[_R28Identity, ...]:
        root = self.validate_identity(root_identity)
        ids: dict[int, tuple[int, int]] = {root[0]: root}
        for raw in previously_tracked:
            pid, ticks = self.validate_identity(raw)
            row = snapshot.by_pid.get(pid)
            if row is None:
                raise RuntimeError(r28.SAMPLED_TRACKED_RACE_ERROR)
            if (row.identity.pid, row.identity.create_time_100ns) != (pid, ticks):
                raise RuntimeError("R28 tracked PID generation changed")
            ids[pid] = (pid, ticks)
        changed = True
        while changed:
            changed = False
            for row in snapshot.rows:
                if row.ppid in ids and row.identity.pid not in ids:
                    ids[row.identity.pid] = (row.identity.pid, row.identity.create_time_100ns)
                    changed = True
        return tuple(_R28Identity(*identity) for identity in sorted(ids.values()))

    def open_exact_process_handle(self, row: _R28Row) -> object:
        identity = (row.identity.pid, row.identity.create_time_100ns)
        current = self.handles.get(identity)
        if current is not None:
            return current
        handle = object()
        self.handles[identity] = handle
        self.handle_ids[id(handle)] = identity
        self.exit_codes.setdefault(identity, 0)
        return handle

    def require_handle_matches_table(self, handle: object, identity: tuple[int, int],
                                     snapshot: _R28Snapshot, **kwargs: object) -> None:
        exact = self.validate_identity(identity)
        if self.read_process_handle_identity(handle) != exact:
            raise RuntimeError("R28 handle/table identity mismatch")
        row = snapshot.by_pid.get(exact[0])
        if row is None or (row.identity.pid, row.identity.create_time_100ns) != exact:
            raise RuntimeError("R28 exact row is absent")

    def wait_for_process_exit(self, handle: object, timeout: float) -> bool:
        identity = self.read_process_handle_identity(handle)
        self.wait_calls.append((identity, timeout))
        if identity == self.tracked_child and self.tracked_child_exits:
            self.exited.add(identity)
        return identity in self.exited

    def process_exit_code(self, handle: object) -> int:
        identity = self.read_process_handle_identity(handle)
        if identity not in self.exited:
            raise RuntimeError("R28 requested exit code for live identity")
        return self.exit_codes[identity]

    def terminate_process_handle(self, handle: object) -> None:
        identity = self.read_process_handle_identity(handle)
        self.terminate_handles.append(handle)
        self.exited.add(identity)

    @staticmethod
    def signal_exact_process(handle: object, identity: tuple[int, int], **kwargs: object) -> dict:
        return {"complete": False, "identity": {"pid": identity[0],
                "create_time_100ns": identity[1]}, "reason": "fake cleanup not authorized"}

    def close_process_handle(self, handle: object) -> None:
        self.close_handles.append(handle)


class _R28RaceAudit:
    SAMPLE_SCHEMA = "native-g1g2-r23-process-tree-sample-v1"

    def __init__(self, table: _R28RaceTable, *, observed_descendant_present: bool = True) -> None:
        self.table = table
        self.sample_calls = 0
        self.observed_descendant_present = observed_descendant_present

    def bind_popen_generation(self, process: _R28Process, snapshot: _R28Snapshot,
                              *, handle_identity_reader: object) -> tuple[int, int]:
        identity = self.table.read_process_handle_identity(process._handle)
        row = snapshot.by_pid.get(identity[0])
        if row is None or (row.identity.pid, row.identity.create_time_100ns) != identity:
            raise RuntimeError("R28 fake root bind mismatch")
        return identity

    @staticmethod
    def global_heavy_processes(snapshot: _R28Snapshot) -> tuple[tuple[int, int], ...]:
        return tuple(sorted((row.identity.pid, row.identity.create_time_100ns)
                            for row in snapshot.rows if row.name.casefold() in
                            {"julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh"}))

    def sample_process_tree(self, root_identity: tuple[int, int], *, snapshot_provider: object,
                            handle_provider: object, resource_reader: object,
                            handle_identity_reader: object, previously_tracked: tuple,
                            sample_index: int, elapsed_seconds: float) -> dict:
        self.sample_calls += 1
        if self.sample_calls == 1:
            self.table.exited.add(self.table.tracked_child)
            snapshot = snapshot_provider()
            digest = [[0, 0, 134345421481717430, ""],
                      [root_identity[0], 1, root_identity[1], "julia.exe"]]
            if self.observed_descendant_present:
                digest.append([self.table.new_child[0], root_identity[0],
                               self.table.observed_descendant_generation, "git.exe"])
            digest.sort()
            return {"schema": self.SAMPLE_SCHEMA, "sample_index": sample_index,
                "elapsed_seconds": elapsed_seconds,
                "root_identity": {"pid": root_identity[0], "create_time_100ns": root_identity[1]},
                "complete": False, "processes": [], "discovered_identities": [],
                "measured_identities": [], "partial_rss_bytes": 0, "rss_bytes": None,
                "native_snapshot_before_rows": None, "native_snapshot_after_rows": None,
                "native_snapshot_before_digest": digest, "native_snapshot_after_digest": None,
                "identity_source": "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
                "errors": [{"phase": "sample_process_tree", "type": "ProcessTableError",
                    "message": r28.SAMPLED_TRACKED_RACE_ERROR,
                    "repr": f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
                "numerical_credit": False, "numerical_status": "not_established",
                "physical_status": "unknown", "solver_success_claimed": False}

        snapshot = snapshot_provider()
        identities = self.table.descendant_identities(snapshot, root_identity,
            previously_tracked=previously_tracked)
        for row in snapshot.rows:
            if (row.identity.pid, row.identity.create_time_100ns) in {
                    (item.pid, item.create_time_100ns) for item in identities}:
                handle_provider(row)
        processes = [{"pid": item.pid, "create_time_100ns": item.create_time_100ns,
                      "rss_bytes": 10, "cpu_user_seconds": 0.0,
                      "cpu_system_seconds": 0.0, "cmdline": ["fake"]}
                     for item in identities]
        rss = sum(item["rss_bytes"] for item in processes)
        digest = [[row.identity.pid, row.ppid, row.identity.create_time_100ns, row.name]
                  for row in snapshot.rows]
        digest.sort()
        return {"schema": self.SAMPLE_SCHEMA, "sample_index": sample_index,
            "elapsed_seconds": elapsed_seconds,
            "root_identity": {"pid": root_identity[0], "create_time_100ns": root_identity[1]},
            "complete": True, "processes": processes,
            "discovered_identities": [{"pid": item.pid, "create_time_100ns": item.create_time_100ns}
                                       for item in identities],
            "measured_identities": [{"pid": x["pid"], "create_time_100ns": x["create_time_100ns"]}
                                     for x in processes],
            "partial_rss_bytes": rss, "rss_bytes": rss,
            "native_snapshot_before_rows": len(snapshot.rows),
            "native_snapshot_after_rows": len(snapshot.rows),
            "native_snapshot_before_digest": digest, "native_snapshot_after_digest": digest,
            "identity_source": "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
            "errors": [], "numerical_credit": False, "numerical_status": "not_established",
            "physical_status": "unknown", "solver_success_claimed": False}

    @staticmethod
    def sampled_resource_disposition(samples: list) -> dict:
        if not samples or any(row.get("complete") is not True for row in samples):
            return {"disposition": "resource_monitor_incomplete", "complete": False,
                    "reason": "incomplete", **r28.NO_CREDIT}
        return {"disposition": "no_sampled_rss_threshold_crossing", "complete": True,
                **r28.NO_CREDIT}

    @staticmethod
    def signal_exact_process(handle: object, identity: tuple[int, int], **kwargs: object) -> dict:
        return {"complete": False, "identity": {"pid": identity[0],
                "create_time_100ns": identity[1]}, "reason": "fake cleanup not authorized"}

    @staticmethod
    def audit_residual_identities(expected: set[tuple[int, int]], snapshot: _R28Snapshot) -> dict:
        live = {(row.identity.pid, row.identity.create_time_100ns) for row in snapshot.rows}
        residual = sorted(expected & live)
        return {"schema": "fake-r28-residual", "complete": True,
                "residual_clear": not residual, "residual_identities": [list(x) for x in residual]}


class R28SampleRaceRecoveryTests(unittest.TestCase):
    def _run_recovered_stage(self, *, present_when_rebinding: bool = True,
                             observed_ticks: int | None = None,
                             child_exits: bool = True) -> tuple[dict, _R28RaceTable,
                                                                _R28RaceAudit, list[dict]]:
        table = _R28RaceTable(observed_descendant_present=present_when_rebinding,
            observed_descendant_generation=observed_ticks, tracked_child_exits=child_exits)
        audit = _R28RaceAudit(table, observed_descendant_present=True)
        process = _R28Process(table, table.root_handle)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r28-sample-race-") as temp:
            output = Path(temp)
            def finish_processes(*_args: object) -> None:
                table.exited.update({table.root_identity, table.new_child})
            with patch.object(r28.subprocess, "Popen", return_value=process), \
                    patch.object(r28.time, "sleep", side_effect=finish_processes), \
                    patch.object(r28, "_native_resource_reader", return_value={
                        "rss_bytes": 10, "cpu_user_seconds": 0.0,
                        "cpu_system_seconds": 0.0, "cmdline": ["fake"]}):
                stage = r28._run_stage(output, 1, "primary", ["fake-julia"], {}, table, audit)
            attempts = [json.loads(line) for line in
                (output / "01_primary" / "sample_attempts.jsonl").read_text().splitlines()]
            return stage, table, audit, attempts

    def test_exact_missing_receipt_and_new_git_descendant_bind_then_one_retry(self) -> None:
        stage, table, audit, attempts = self._run_recovered_stage()
        self.assertEqual(audit.sample_calls, 2)
        self.assertEqual(stage["stop_reason"], "natural_exit")
        self.assertTrue(stage["resource_monitor_complete"])
        self.assertEqual(stage["sample_recovery_count"], 1)
        self.assertEqual([x["identity"] for x in stage["stage_exit_receipts"][:1]], [
            {"pid": table.tracked_child[0], "create_time_100ns": table.tracked_child[1]}])
        self.assertTrue(all(x["complete"] is True for x in stage["stage_exit_receipts"]))
        self.assertIn(table.new_child, table.handles)
        self.assertIn(table.new_child, {(x["pid"], x["create_time_100ns"])
                                        for x in stage["samples"][0]["measured_identities"]})
        self.assertEqual(len(attempts), 2)
        failed = attempts[0]
        self.assertEqual(failed["outcome"], "recoverable_exact_tracked_race")
        self.assertEqual(failed["tracked_before_sample"], [
            {"pid": table.root_identity[0], "create_time_100ns": table.root_identity[1]},
            {"pid": table.tracked_child[0], "create_time_100ns": table.tracked_child[1]}])
        self.assertEqual(failed["recovery"]["new_observed_descendant_identities"], [
            {"pid": table.new_child[0], "create_time_100ns": table.new_child[1]}])
        self.assertEqual(stage["unaccounted_observed_generations"], [])
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])

    def test_digest_observed_child_gone_before_binding_is_unaccounted_and_residual_unclear(self) -> None:
        stage, table, audit, _ = self._run_recovered_stage(present_when_rebinding=False)
        self.assertEqual(audit.sample_calls, 1)
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        self.assertFalse(stage["final_residual_audit"]["residual_clear"])
        self.assertTrue(stage["final_residual_audit"]["cleanup_unconfirmed"])
        unaccounted = stage["final_residual_audit"]["unaccounted_observed_generations"]
        self.assertEqual((unaccounted[0]["pid"], unaccounted[0]["create_time_100ns"]),
                         table.new_child)
        self.assertFalse(stage["resource_monitor_complete"])
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])

    def test_digest_observed_child_pid_reuse_is_unaccounted_not_receipted_as_new_generation(self) -> None:
        table = _R28RaceTable(observed_descendant_present=True,
            observed_descendant_generation=_R28RaceTable().new_child[1] + 1)
        table.snapshot_calls = 4
        audit = _R28RaceAudit(table, observed_descendant_present=True)
        sample = {"schema": audit.SAMPLE_SCHEMA, "complete": False,
            "root_identity": {"pid": table.root_identity[0], "create_time_100ns": table.root_identity[1]},
            "errors": [{"phase": "sample_process_tree", "type": "ProcessTableError",
                "message": r28.SAMPLED_TRACKED_RACE_ERROR,
                "repr": f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
            "processes": [], "discovered_identities": [], "measured_identities": [],
            "partial_rss_bytes": 0, "rss_bytes": None,
            "native_snapshot_before_digest": [[table.root_identity[0],1,table.root_identity[1],"julia.exe"],
                [table.new_child[0],table.root_identity[0],table.new_child[1],"git.exe"]],
            "native_snapshot_after_digest": None}
        tracked={table.root_identity,table.tracked_child}
        child_handle = object()
        table.handles[table.tracked_child] = child_handle
        table.handle_ids[id(child_handle)] = table.tracked_child
        handles={table.root_identity:table.root_handle, table.tracked_child:child_handle}
        receipts=[]
        diag=r28._recover_missing_tracked_sample_race(sample,
            tuple(sorted(tracked)),table.root_identity,tracked,handles,receipts,
            table,audit,table.query_native_process_table)
        self.assertFalse(diag["complete"])
        self.assertEqual(diag["reason"],"digest_observed_descendant_unaccounted")
        self.assertEqual(diag["unaccounted_observed_generations"][0]["reason"],
                         "digest_observed_descendant_generation_or_parent_changed")
        self.assertEqual(receipts[0]["identity"], {"pid":table.tracked_child[0],
                                                    "create_time_100ns":table.tracked_child[1]})
        self.assertTrue(diag["unaccounted_observed_generations"])

    def test_root_missing_and_nonmatching_error_never_enter_recovery(self) -> None:
        table = _R28RaceTable()
        audit = _R28RaceAudit(table)
        base={"schema":audit.SAMPLE_SCHEMA,"complete":False,
            "root_identity":{"pid":table.root_identity[0],"create_time_100ns":table.root_identity[1]},
            "errors":[{"phase":"sample_process_tree","type":"ProcessTableError",
                "message":r28.SAMPLED_TRACKED_RACE_ERROR,
                "repr":f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
            "processes":[],"discovered_identities":[],"measured_identities":[],
            "partial_rss_bytes":0,"rss_bytes":None,"native_snapshot_after_digest":None}
        tracked=tuple(sorted({table.root_identity,table.tracked_child}))
        root_missing=dict(base,native_snapshot_before_digest=[])
        root_diag=r28._classify_missing_tracked_sample_race(root_missing,tracked,
            table.root_identity,table,audit)
        self.assertFalse(root_diag["eligible"])
        self.assertEqual(root_diag["reason"],"sample_before_digest_missing_or_reused_root")
        altered=json.loads(json.dumps(base))
        altered["errors"][0]["message"]="different R23 failure"
        altered["native_snapshot_before_digest"]=[[table.root_identity[0],1,
            table.root_identity[1],"julia.exe"]]
        err_diag=r28._classify_missing_tracked_sample_race(altered,tracked,
            table.root_identity,table,audit)
        self.assertFalse(err_diag["eligible"])

    def test_malformed_duplicate_digest_and_pid_alias_fail_closed(self) -> None:
        table=_R28RaceTable(); audit=_R28RaceAudit(table)
        sample={"schema":audit.SAMPLE_SCHEMA,"complete":False,
            "root_identity":{"pid":table.root_identity[0],"create_time_100ns":table.root_identity[1]},
            "errors":[{"phase":"sample_process_tree","type":"ProcessTableError",
                "message":r28.SAMPLED_TRACKED_RACE_ERROR,
                "repr":f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
            "processes":[],"discovered_identities":[],"measured_identities":[],
            "partial_rss_bytes":0,"rss_bytes":None,"native_snapshot_after_digest":None,
            "native_snapshot_before_digest":[[table.root_identity[0],1,table.root_identity[1],"julia.exe"],
                [table.root_identity[0],1,table.root_identity[1],"julia.exe"]]}
        tracked=tuple(sorted({table.root_identity,table.tracked_child}))
        duplicate=r28._classify_missing_tracked_sample_race(sample,tracked,
            table.root_identity,table,audit)
        self.assertFalse(duplicate["eligible"])
        self.assertEqual(duplicate["reason"],"sample_race_diagnostic_invalid")
        sample["native_snapshot_before_digest"]=[[table.root_identity[0],1,
            table.root_identity[1],"julia.exe"],[table.tracked_child[0],1,
            True,"tracked-helper.exe"]]
        invalid=r28._classify_missing_tracked_sample_race(sample,tracked,
            table.root_identity,table,audit)
        self.assertFalse(invalid["eligible"])

    def test_active_missing_tracked_handle_cannot_generate_natural_exit_receipt(self) -> None:
        table=_R28RaceTable(tracked_child_exits=False); audit=_R28RaceAudit(table)
        table.exited.clear()
        table.exited.discard(table.tracked_child)
        digest=[[table.root_identity[0],1,table.root_identity[1],"julia.exe"]]
        sample={"schema":audit.SAMPLE_SCHEMA,"complete":False,
            "root_identity":{"pid":table.root_identity[0],"create_time_100ns":table.root_identity[1]},
            "errors":[{"phase":"sample_process_tree","type":"ProcessTableError",
                "message":r28.SAMPLED_TRACKED_RACE_ERROR,
                "repr":f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
            "processes":[],"discovered_identities":[],"measured_identities":[],
            "partial_rss_bytes":0,"rss_bytes":None,"native_snapshot_before_digest":digest,
            "native_snapshot_after_digest":None}
        child_handle=object(); table.handle_ids[id(child_handle)]=table.tracked_child
        tracked={table.root_identity,table.tracked_child}
        handles={table.root_identity:table.root_handle,table.tracked_child:child_handle}
        receipts=[]
        diag=r28._recover_missing_tracked_sample_race(sample,tuple(sorted(tracked)),
            table.root_identity,tracked,handles,receipts,table,audit,table.query_native_process_table)
        self.assertFalse(diag["complete"])
        self.assertEqual(diag["reason"],"missing_tracked_generation_exit_receipt_incomplete")
        self.assertFalse(receipts[0]["complete"])


class _R28OrphanChainTable(_R28RaceTable):
    def __init__(self, *, fresh_descendants: bool = True,
                 reparent_after_parent_exit: bool = True,
                 child_generation_reuse: bool = False,
                 parent_generation_reuse: bool = False,
                 orphan_parent_chronology_ambiguous: bool = False) -> None:
        super().__init__(observed_descendant_present=True, tracked_child_exits=True)
        self.grandchild = (743, self.new_child[1] + 1)
        self.exit_codes[self.grandchild] = 0
        self.fresh_descendants = fresh_descendants
        self.reparent_after_parent_exit = reparent_after_parent_exit
        self.child_generation_reuse = child_generation_reuse
        self.parent_generation_reuse = parent_generation_reuse
        self.orphan_parent_chronology_ambiguous = orphan_parent_chronology_ambiguous
        self.sample_issued = False

    def query_native_process_table(self) -> _R28Snapshot:
        self.snapshot_calls += 1
        n = self.snapshot_calls
        if n == 1:
            rows: list[_R28Row] = []
        elif n == 2:
            rows = [self._row(self.root_identity, 1, "julia.exe")]
        elif n in (3, 4):
            rows = [self._row(self.root_identity, 1, "julia.exe"),
                    self._row(self.tracked_child, self.root_identity[0], "tracked-helper.exe")]
        else:
            rows = []
            if self.root_identity not in self.exited:
                rows.append(self._row(self.root_identity, 1, "julia.exe"))
            if n == 5 or not self.sample_issued:
                # Exact failing-snapshot shape: B is gone, but the table still
                # names B as C's parent; D is nested below C.
                child = (self.new_child[0], self.tracked_child[1] - 1) \
                    if self.orphan_parent_chronology_ambiguous else self.new_child
                rows.append(self._row(child, self.tracked_child[0], "git.exe"))
                rows.append(self._row(self.grandchild, self.new_child[0], "orphan-helper.exe"))
            elif self.fresh_descendants:
                child = (self.new_child[0], self.new_child[1] + 1) \
                    if self.child_generation_reuse else self.new_child
                child_parent = (self.root_identity[0] if self.reparent_after_parent_exit
                                else self.tracked_child[0])
                if child not in self.exited:
                    rows.append(self._row(child, child_parent, "git.exe"))
                if self.grandchild not in self.exited:
                    rows.append(self._row(self.grandchild, self.new_child[0], "orphan-helper.exe"))
            if self.parent_generation_reuse and n > 5:
                reused = (self.tracked_child[0], self.tracked_child[1] + 1)
                rows.append(self._row(reused, self.root_identity[0], "reused-helper.exe"))
        self.rows = rows
        return _R28Snapshot(rows)


class _R28OrphanChainAudit(_R28RaceAudit):
    def __init__(self, table: _R28OrphanChainTable) -> None:
        super().__init__(table, observed_descendant_present=True)

    def sample_process_tree(self, root_identity: tuple[int, int], **kwargs: object) -> dict:
        if self.sample_calls:
            return super().sample_process_tree(root_identity, **kwargs)
        self.sample_calls = 1
        table: _R28OrphanChainTable = self.table
        table.exited.add(table.tracked_child)
        snapshot = kwargs["snapshot_provider"]()
        digest = [[row.identity.pid, row.ppid, row.identity.create_time_100ns, row.name]
                  for row in snapshot.rows]
        digest.sort()
        table.sample_issued = True
        return {"schema": self.SAMPLE_SCHEMA, "sample_index": kwargs["sample_index"],
            "elapsed_seconds": kwargs["elapsed_seconds"],
            "root_identity": {"pid": root_identity[0], "create_time_100ns": root_identity[1]},
            "complete": False, "processes": [], "discovered_identities": [],
            "measured_identities": [], "partial_rss_bytes": 0, "rss_bytes": None,
            "native_snapshot_before_rows": len(snapshot.rows),
            "native_snapshot_after_rows": None,
            "native_snapshot_before_digest": digest, "native_snapshot_after_digest": None,
            "identity_source": "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
            "errors": [{"phase": "sample_process_tree", "type": "ProcessTableError",
                "message": r28.SAMPLED_TRACKED_RACE_ERROR,
                "repr": f"ProcessTableError({r28.SAMPLED_TRACKED_RACE_ERROR!r})"}],
            "numerical_credit": False, "physical_credit": False,
            "solver_success_claimed": False}


class R28OrphanChainRecoveryTests(unittest.TestCase):
    def _run_orphan_stage(self, **table_options: object) -> tuple[dict, _R28OrphanChainTable,
                                                                  _R28OrphanChainAudit, list[dict]]:
        table = _R28OrphanChainTable(**table_options)
        audit = _R28OrphanChainAudit(table)
        process = _R28Process(table, table.root_handle)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r28-orphan-chain-") as temp:
            output = Path(temp)
            def finish_processes(*_args: object) -> None:
                table.exited.update({table.root_identity, table.new_child, table.grandchild})
            with patch.object(r28.subprocess, "Popen", return_value=process), \
                    patch.object(r28.time, "sleep", side_effect=finish_processes), \
                    patch.object(r28, "_native_resource_reader", return_value={
                        "rss_bytes": 10, "cpu_user_seconds": 0.0,
                        "cpu_system_seconds": 0.0, "cmdline": ["fake"]}):
                stage = r28._run_stage(output, 1, "primary", ["fake-julia"], {}, table, audit)
            attempts = [json.loads(line) for line in
                (output / "01_primary" / "sample_attempts.jsonl").read_text().splitlines()]
            return stage, table, audit, attempts

    def test_missing_tracked_parent_orphan_chain_is_closed_and_bound_after_exact_reparent(self) -> None:
        stage, table, audit, attempts = self._run_orphan_stage()
        self.assertEqual(stage["stop_reason"], "natural_exit")
        self.assertTrue(stage["resource_monitor_complete"])
        self.assertEqual(stage["sample_recovery_count"], 1)
        self.assertEqual(audit.sample_calls, 2)
        recovery = attempts[0]["recovery"]
        self.assertEqual(recovery["orphan_chain_roots"], [
            {"pid": table.tracked_child[0], "create_time_100ns": table.tracked_child[1]}])
        self.assertEqual(recovery["orphan_chain_descendant_identities"], [
            {"pid": table.new_child[0], "create_time_100ns": table.new_child[1]},
            {"pid": table.grandchild[0], "create_time_100ns": table.grandchild[1]}])
        self.assertEqual({(x["pid"], x["create_time_100ns"])
                          for x in recovery["bound_observed_generations"]},
                         {table.new_child, table.grandchild})
        self.assertEqual(recovery["reparented_observed_generations"][0]["pid"], table.new_child[0])
        self.assertTrue(recovery["reparented_observed_generations"][0]["parent_exit_receipt_verified"])
        self.assertIn(table.new_child, table.handles)
        self.assertIn(table.grandchild, table.handles)
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])

    def test_orphan_descendant_missing_or_reused_before_bind_is_unaccounted(self) -> None:
        cases = [
            ({"fresh_descendants": False}, "digest_observed_descendant_missing_before_handle_bind"),
            ({"child_generation_reuse": True}, "digest_observed_descendant_generation_or_parent_changed"),
            ({"parent_generation_reuse": True}, "orphan_descendant_parent_generation_reused"),
        ]
        for options, reason in cases:
            with self.subTest(options=options):
                stage, _table, _audit, attempts = self._run_orphan_stage(**options)
                self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
                self.assertFalse(stage["resource_monitor_complete"])
                self.assertFalse(stage["final_residual_audit"]["residual_clear"])
                self.assertEqual(stage["sample_recovery_count"], 0)
                reasons = {x.get("reason") for x in attempts[0]["recovery"][
                    "unaccounted_observed_generations"]}
                self.assertIn(reason, reasons)
                self.assertFalse(stage["numerical_credit"])
                self.assertFalse(stage["physical_credit"])

    def test_orphan_chain_parent_chronology_ambiguity_fails_before_recovery(self) -> None:
        stage, _table, _audit, attempts = self._run_orphan_stage(
            orphan_parent_chronology_ambiguous=True)
        self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
        self.assertEqual(stage["sample_recovery_count"], 0)
        self.assertEqual(attempts[0]["outcome"], "incomplete_unrecovered")
        self.assertEqual(attempts[0]["recovery"]["reason"],
                         "sample_before_digest_orphan_chain_parent_chronology_ambiguous")
        self.assertFalse(stage["final_residual_audit"]["residual_clear"])

    def test_unaccounted_orphan_chain_stops_serial_sequence_before_replay(self) -> None:
        failed, _table, _audit, _attempts = self._run_orphan_stage(fresh_descendants=False)
        calls: list[str] = []
        plans = [{"stage": name, "argv": ["fake", name]}
                 for name in ("parse_all", "primary", "fresh_replay")]

        def injected_stage(output: Path, index: int, name: str, argv: list[str],
                           environment: object, table: object, audit: object) -> dict:
            calls.append(name)
            if name == "primary":
                return failed
            return {"stage": name, "stop_reason": "natural_exit", "root_exit_code": 0,
                    "resource_monitor_complete": True}

        def injected_pass(output: Path, stage: dict, index: int) -> tuple[bool, str | None]:
            if stage["stage"] == "primary":
                return False, "primary: stop_reason=resource_monitor_incomplete"
            return True, None

        with patch.object(r28, "_run_stage", side_effect=injected_stage), \
                patch.object(r28, "_stage_pass", side_effect=injected_pass):
            stages, failure = r28._run_stage_sequence(Path("."), plans, {}, object(), object())
        self.assertEqual(calls, ["parse_all", "primary"])
        self.assertEqual(len(stages), 2)
        self.assertIn("stop_reason=resource_monitor_incomplete", failure or "")
        self.assertFalse(failed["final_residual_audit"]["residual_clear"])

    def test_protocol_contract_declares_missing_parent_ancestry_closure(self) -> None:
        protocol = json.loads(r28.repo_path(r28.REL_PROTOCOL).read_text(encoding="utf-8"))
        contract = protocol["sampled_tracked_race_recovery_contract"]
        self.assertTrue(contract["missing_tracked_pid_remains_an_ancestry_root_for_digest_closure"])
        self.assertTrue(contract["descendants_of_missing_tracked_rows_must_not_be_omitted"])
        self.assertEqual(contract["ambiguous_orphan_ancestry"], "fail_closed_no_retry")
        self.assertIn("R28OrphanChainRecoveryTests -v",
                      protocol["static_qa"]["orphan_chain_fault_injection_command"])

    def test_missing_parent_receipt_binds_descendant_when_ppid_snapshot_stays_stale(self) -> None:
        stage, table, _audit, attempts = self._run_orphan_stage(
            reparent_after_parent_exit=False)
        self.assertEqual(stage["stop_reason"], "natural_exit")
        recovery = attempts[0]["recovery"]
        self.assertEqual(recovery["orphan_parent_bindings"], [{
            "pid": table.new_child[0],
            "create_time_100ns": table.new_child[1],
            "parent_pid": table.tracked_child[0],
            "parent_identity": {"pid": table.tracked_child[0],
                                "create_time_100ns": table.tracked_child[1]},
            "parent_exit_receipt_verified": True,
            "sampled_ppid_persists_after_exit": True,
        }])
        self.assertEqual({(x["pid"], x["create_time_100ns"])
                          for x in recovery["bound_observed_generations"]},
                         {table.new_child, table.grandchild})
        self.assertTrue(stage["resource_monitor_complete"])
        self.assertFalse(stage["numerical_credit"])
        self.assertFalse(stage["physical_credit"])


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


class R28LaunchBindingFailureTests(unittest.TestCase):
    def _run_injected_stage(self, missing_handle: bool = False) -> tuple[dict, _FakeTable, Path, _FakeProcess]:
        table = _FakeTable(report_unbound_child=missing_handle)
        process = _FakeProcess(table.identity[0], None if missing_handle else table.handle, table)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r28-fake-") as temp:
            output = Path(temp)
            with patch.object(r28.subprocess, "Popen", return_value=process):
                stage = r28._run_stage(output, 1, "primary", ["fake-julia"], {},
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
        passed, _ = r28._stage_pass(output, stage, 1)
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
        passed, _ = r28._stage_pass(output, stage, 1)
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


class R28TrackedTreeCleanupFallbackTests(unittest.TestCase):
    def _run(self, *, fail_cleanup: bool = False) -> tuple[dict, _FakeTable, _FakeProcess, Path]:
        table = _FakeTable(report_unbound_child=True, fail_cleanup=fail_cleanup)
        process = _FakeProcess(table.identity[0], table.handle, table)
        with tempfile.TemporaryDirectory(prefix="native-g1g2-r28-tree-fallback-") as temp:
            output = Path(temp)
            with patch.object(r28.subprocess, "Popen", return_value=process), \
                    patch.object(r28, "_terminate_tracked", return_value={
                        "schema": "fake-tree-termination", "complete": False,
                        "failure": "injected tracked-tree cleanup failure"}):
                stage = r28._run_stage(output, 1, "primary", ["fake-julia"], {},
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
        passed, _ = r28._stage_pass(output, stage, 1)
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
        passed, _ = r28._stage_pass(output, stage, 1)
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

        with patch.object(r28, "_run_stage", side_effect=injected_stage):
            stages, failure = r28._run_stage_sequence(Path("."), plans, {}, object(), object())
        self.assertEqual(calls, ["parse_all"])
        self.assertEqual(len(stages), 1)
        self.assertIn("stop_reason=resource_monitor_incomplete", failure or "")


if __name__ == "__main__":
    unittest.main(verbosity=2)
