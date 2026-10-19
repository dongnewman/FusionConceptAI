from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import sys
import time
import traceback
import types
from pathlib import Path
from typing import Any
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
CONTROLLER_R20 = TEST_ROOT / "independent_negative_controller_r20.py"
CONTROLLER_R21 = TEST_ROOT / "independent_negative_controller_r21.py"
R23_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
R23_SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
RUNS_ROOT = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()


class CheckFailure(AssertionError):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def load_controller(path: Path) -> tuple[Any, str]:
    source = path.read_bytes()
    digest = sha256(source)
    module = types.ModuleType("independent_r21_tracked_exit_controller")
    module.__file__ = str(path.resolve())
    module.__package__ = ""
    exec(compile(source, str(path.resolve()), "exec"), module.__dict__)
    return module, digest


def table(controller: Any, rows: list[tuple[int, int, int, str]]) -> Any:
    native = controller._R23_TABLE
    typed = tuple(native.ProcessRow(native.ProcessIdentity(pid, ticks), ppid, name)
                  for pid, ticks, ppid, name in rows)
    return native.ProcessTableSnapshot(
        rows=typed, host_identity=tuple(native.WINDOWS_BUILD_PIN),
        buffer_bytes=native.SPI_FIXED_HEADER_BYTES, query_attempts=1,
        ntstatus_u32=0)


def identity_rows(controller: Any) -> dict[str, tuple[int, int]]:
    ticks = controller._R23_TABLE.WINDOWS_EPOCH_100NS
    return {
        "root": (100, ticks + 100),
        "stable": (150, ticks + 150),
        "target": (200, ticks + 200),
        "child": (300, ticks + 300),
    }


def make_tables(controller: Any) -> dict[str, Any]:
    ids = identity_rows(controller)
    root, stable, target, child = (ids[key] for key in
                                   ("root", "stable", "target", "child"))
    sys_ticks = controller._R23_TABLE.WINDOWS_EPOCH_100NS + 1
    return {
        "source": table(controller, [
            (0, sys_ticks, 0, ""), (4, sys_ticks, 0, "System"),
            (root[0], root[1], 4, "julia.exe"),
            (stable[0], stable[1], root[0], "tracked-sibling.exe"),
            (target[0], target[1], root[0], "conhost.exe"),
            (child[0], child[1], target[0], "conhost-child.exe"),
        ]),
        "after": table(controller, [
            (0, sys_ticks, 0, ""), (4, sys_ticks, 0, "System"),
            (root[0], root[1], 4, "julia.exe"),
            (stable[0], stable[1], root[0], "tracked-sibling.exe"),
        ]),
        "final": table(controller, [
            (0, sys_ticks, 0, ""), (4, sys_ticks, 0, "System"),
        ]),
    }


class FakeProcess:
    def __init__(self, identity: tuple[int, int]):
        self.pid = identity[0]
        self._handle = identity


class FakeRegistry:
    def __init__(self, controller: Any, ids: dict[str, tuple[int, int]]):
        self.native = controller._R23_TABLE
        self._handles = {identity: identity for identity in ids.values()}
        self._owned = {ids["stable"], ids["target"], ids["child"]}
        self.opened: list[tuple[int, int]] = []
        self.closed: list[tuple[int, int]] = []
        self.signalled: list[tuple[int, int]] = []

    def for_row(self, row: Any, snapshot: Any) -> tuple[int, int]:
        pid = row.identity.pid
        identity = (pid, row.identity.create_time_100ns)
        table_value = self.native.validate_snapshot(snapshot)
        observed = table_value.by_pid.get(pid)
        if observed is None or (
                observed.identity.pid,
                observed.identity.create_time_100ns) != identity:
            raise PermissionError("synthetic row is not bound to source SPI table")
        handle = self._handles.get(identity)
        if handle is None:
            handle = identity
            self._handles[identity] = handle
            self._owned.add(identity)
        self.opened.append(identity)
        return handle

    def close_owned(self) -> dict[str, Any]:
        for identity in sorted(self._owned):
            self.closed.append(identity)
            self._handles.pop(identity, None)
        closed = [{"pid": pid, "create_time_100ns": ticks}
                  for pid, ticks in self.closed]
        self._owned.clear()
        return {"schema": "native-g1g2-r23-handle-close-receipt-r1",
                "complete": True, "closed_owned_handles": closed,
                "errors": [], "popen_handles_not_owned_by_registry": 1}


def empty_heavy_receipt(controller: Any, snapshot: Any) -> dict[str, Any]:
    return {
        "schema": "vnext-t2-r23-global-heavy-audit-r1",
        "complete": True,
        "processes": [],
        "controller_processes": [],
        "native_heavy_identities": [],
        "errors": [],
        "snapshot": controller._r23_snapshot_receipt(snapshot),
    }


def test_static_contract(controller: Any, r20_controller: Any) -> dict[str, Any]:
    source = CONTROLLER_R21.read_text(encoding="utf-8")
    tree = ast.parse(source)
    run_phase = next(node for node in tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
                     and node.name == "run_phase")
    run_phase_source = ast.get_source_segment(source, run_phase) or ""
    require("active_tracked.difference_update(retired)" in run_phase_source and
            "full_sample_completed_after_retry" in run_phase_source and
            "retired.issubset(active_tracked)" in run_phase_source and
            "identity not in tracked" in run_phase_source,
            "run_phase does not gate active-set retirement on proof, retry, and historical tracking")

    def function_dump(module: Any, name: str) -> str:
        module_tree = ast.parse(Path(module.__file__).read_text(encoding="utf-8"))
        node = next(item for item in module_tree.body
                    if isinstance(item, (ast.FunctionDef, ast.AsyncFunctionDef))
                    and item.name == name)
        return ast.dump(node, include_attributes=False)

    require(function_dump(controller, "_r20_confirm_unbound_sample_race") ==
            function_dump(r20_controller, "_r20_confirm_unbound_sample_race"),
            "R21 changed the existing R20 unbound-race guard")
    require(controller.R20_MAX_WHOLE_SAMPLE_ATTEMPTS == 2 and
            controller._R23_SUPERVISOR.RSS_THRESHOLD_BYTES == 2_147_483_648 and
            controller._R23_SUPERVISOR.STAGE_WALL_SECONDS == 480.0 and
            controller._R23_SUPERVISOR.SAMPLE_INTERVAL_SECONDS == 0.2,
            "R21 changed a retry/resource/time/sample threshold")
    return {"unbound_guard_ast_identical_to_r20": True,
            "active_retirement_gated_by_exact_receipt_and_retry": True,
            "whole_sample_retry_cap": controller.R20_MAX_WHOLE_SAMPLE_ATTEMPTS,
            "rss_threshold_bytes": controller._R23_SUPERVISOR.RSS_THRESHOLD_BYTES,
            "stage_wall_seconds": controller._R23_SUPERVISOR.STAGE_WALL_SECONDS,
            "sample_interval_seconds": controller._R23_SUPERVISOR.SAMPLE_INTERVAL_SECONDS}


def run_sample(controller: Any, mode: str = "positive") -> tuple[dict[str, Any], FakeRegistry, dict[str, Any]]:
    native = controller._R23_TABLE
    ids = identity_rows(controller)
    tables = make_tables(controller)
    source = tables["source"]
    after = tables["after"]
    final = tables["final"]
    confirmations = [after, after, after]
    retry_source: Any = after
    retry_after: Any = after

    if mode == "reuse_during_confirmation":
        ticks = ids["target"][1] + 1
        confirmations[1] = table(controller, [
            (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
            (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
            (ids["root"][0], ids["root"][1], 4, "julia.exe"),
            (ids["stable"][0], ids["stable"][1], ids["root"][0], "tracked-sibling.exe"),
            (ids["target"][0], ticks, ids["root"][0], "reused-one-tick.exe"),
        ])
    elif mode == "incomplete_confirmation":
        confirmations[1] = None
    elif mode == "other_tracked_missing":
        confirmations[1] = table(controller, [
            (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
            (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
            (ids["root"][0], ids["root"][1], 4, "julia.exe"),
        ])
    elif mode == "orphan_remains":
        confirmations[1] = table(controller, [
            (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
            (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
            (ids["root"][0], ids["root"][1], 4, "julia.exe"),
            (ids["stable"][0], ids["stable"][1], ids["root"][0], "tracked-sibling.exe"),
            (500, native.WINDOWS_EPOCH_100NS + 500, ids["target"][0], "orphan-after-exit.exe"),
        ])
    elif mode == "target_reappears":
        confirmations[1] = source
    elif mode == "retry_sample_incomplete":
        retry_source = None
    elif mode not in ("positive", "root_exits"):
        raise CheckFailure(f"unknown sample fixture mode: {mode}")

    if mode == "root_exits":
        after = table(controller, [
            (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
            (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
            (ids["target"][0], ids["target"][1], ids["root"][0], "conhost.exe"),
        ])
        confirmations = [after, after, after]
        retry_source = None

    queries = [source, after, *confirmations, retry_source, retry_after]
    query_log: list[Any] = []
    registry = FakeRegistry(controller, ids)
    process = FakeProcess(ids["root"])
    query_index = 0
    wait_count: dict[tuple[int, int], int] = {}

    def query() -> Any:
        nonlocal query_index
        if query_index >= len(queries):
            raise CheckFailure(f"synthetic SPI query overrun in {mode}")
        value = queries[query_index]
        query_index += 1
        query_log.append(value)
        return value

    def native_wait(handle: Any, timeout: float) -> bool:
        identity = tuple(handle) if isinstance(handle, tuple) else handle
        wait_count[identity] = wait_count.get(identity, 0) + 1
        if identity in (ids["target"], ids["child"]):
            return wait_count[identity] >= 2
        if mode == "root_exits" and identity == ids["root"]:
            return wait_count[identity] >= 2
        return False

    metrics = {
        ids["root"][0]: (1000, 0.10, 0.11),
        ids["stable"][0]: (1500, 0.15, 0.16),
        ids["target"][0]: (2000, 0.20, 0.21),
        ids["child"][0]: (3000, 0.30, 0.31),
    }

    def resource_reader(pid: int) -> dict[str, Any]:
        rss, user, system = metrics[pid]
        return {"rss_bytes": rss, "cpu_user_seconds": user,
                "cpu_system_seconds": system, "cmdline": [f"pid-{pid}"]}

    with patch.object(native, "query_native_process_table", side_effect=query), \
            patch.object(native, "read_process_handle_identity",
                         side_effect=lambda handle: tuple(handle)), \
            patch.object(native, "wait_for_process_exit", side_effect=native_wait), \
            patch.object(native, "process_exit_code", side_effect=lambda handle: 17), \
            patch.object(controller, "_r23_resource_reader", side_effect=resource_reader):
        sample = controller._r20_native_sample(
            process, registry, ids["root"],
            [ids["root"], ids["stable"], ids["target"], ids["child"]],
            sample_index=14, elapsed=0.0,
            deadline_monotonic=controller.time.monotonic() + 60.0)
    sample["_test_query_log"] = query_log
    sample["_test_registry"] = registry
    sample["_test_final_snapshot"] = final
    return sample, registry, {"ids": ids, "final_snapshot": final,
                              "wait_count": wait_count, "query_count": query_index}


def assert_no_credit(sample: dict[str, Any], record: dict[str, Any] | None) -> None:
    if record is not None:
        require(record.get("rss_credit_bytes") == 0 and
                record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                record.get("exit_code_credit_issued") is False,
                "tracked-exit recovery credited an incomplete sample")
        discarded = record.get("discarded_attempt", {})
        if discarded:
            require(discarded.get("credited_rss_bytes") == 0 and
                    discarded.get("credited_cpu_seconds") == {
                        "user": 0.0, "system": 0.0} and
                    discarded.get("exit_code_credit_issued") is False,
                    "discarded tracked-exit attempt received RSS/CPU/exit credit")
    require(sample.get("sample_complete") is False and
            sample.get("process_tree_user_cpu_seconds") == 0.0 and
            sample.get("process_tree_system_cpu_seconds") == 0.0 and
            sample.get("process_tree_working_set_bytes") == 0,
            "failed tracked-exit sample retained sample-level numerical credit")


def test_final_audit_binding_controls(
        controller: Any, record: dict[str, Any], ids: dict[str, tuple[int, int]],
        final_snapshot: Any) -> list[dict[str, Any]]:
    """Mutate one R21 receipt at a time and require final audit to reject it."""
    controls: list[dict[str, Any]] = []

    def reject(label: str, candidate: dict[str, Any]) -> None:
        audit = controller._r21_audit_tracked_sample_exit_races(
            final_snapshot, [candidate], ids["root"], list(ids.values()))
        require(audit.get("complete") is False and
                len(audit.get("errors", [])) >= 1,
                f"final audit accepted forged tracked-exit evidence: {label}")
        controls.append({"name": label, "status": "pass",
                         "audit_complete": audit.get("complete"),
                         "error_count": len(audit.get("errors", []))})

    wrong_root = copy.deepcopy(record)
    wrong_root["root_identity"] = {
        "pid": ids["stable"][0], "create_time_100ns": ids["stable"][1]}
    reject("record root differs from the actual phase root", wrong_root)

    wrong_ppid = copy.deepcopy(record)
    unreachable_parent_pid = 999_999
    for rows_name in ("source_root_closure", "observed_generations"):
        rows = wrong_ppid.get(rows_name)
        require(type(rows) is list,
                f"R21 receipt lacks {rows_name} needed for source-row binding")
        target_row = next((row for row in rows
                           if row.get("pid") == ids["target"][0]), None)
        require(target_row is not None,
                f"R21 receipt lacks target source row in {rows_name}")
        target_row["ppid"] = unreachable_parent_pid
    reject("target source PPID points outside the exact root closure", wrong_ppid)

    inverted_time = copy.deepcopy(record)
    old_child = ids["child"]
    inverted_child = (old_child[0], ids["target"][1] - 1)
    for rows_name in ("source_root_closure", "observed_generations",
                      "previously_tracked_identities", "retired_tracked_identities"):
        rows = inverted_time.get(rows_name)
        require(type(rows) is list,
                f"R21 receipt lacks {rows_name} needed for generation chronology control")
        for row in rows:
            if (row.get("pid"), row.get("create_time_100ns")) == old_child:
                row["create_time_100ns"] = inverted_child[1]
    for receipt in inverted_time.get("exact_exit_receipts", []):
        for field in ("identity", "handle_identity_before_wait",
                      "handle_identity_after_wait"):
            value = receipt.get(field, {})
            if (value.get("pid"), value.get("create_time_100ns")) == old_child:
                value["create_time_100ns"] = inverted_child[1]
    reject("child FILETIME predates its exact source parent", inverted_time)

    unreachable_subtree = copy.deepcopy(record)
    for rows_name in ("source_root_closure", "observed_generations"):
        rows = unreachable_subtree.get(rows_name)
        require(type(rows) is list,
                f"R21 receipt lacks {rows_name} needed for target-subtree closure control")
        child_row = next((row for row in rows
                          if row.get("pid") == ids["child"][0]), None)
        require(child_row is not None,
                f"R21 receipt lacks child source row in {rows_name}")
        # This keeps the child reachable from the stage root through the stable
        # sibling while severing its required membership under the exited target.
        child_row["ppid"] = ids["stable"][0]
    reject("retired source row is outside the exact target subtree", unreachable_subtree)
    return controls


def test_sample_controls(controller: Any) -> dict[str, Any]:
    positive, registry, context = run_sample(controller)
    require(positive.get("sample_complete") is True and
            positive.get("sample_attempt_count") == 2 and
            positive.get("sample_handoff_recoveries") == [],
            "tracked natural exit did not use one separate typed recovery and whole-sample retry")
    records = positive.get("tracked_sample_exit_races", [])
    require(type(records) is list and len(records) == 1,
            "positive sample did not retain exactly one R21 tracked-exit record")
    record = records[0]
    ids = context["ids"]
    retired = {(item.get("pid"), item.get("create_time_100ns"))
               for item in record.get("retired_tracked_identities", [])}
    expected_retired = {ids["target"], ids["child"]}
    require(record.get("schema") == "vnext-t2-r21-tracked-sample-exit-r1" and
            record.get("complete") is True and
            record.get("retry_started") is True and
            record.get("full_sample_completed_after_retry") is True and
            retired == expected_retired,
            "positive tracked-exit receipt did not prove and retire the exact subtree")
    receipts = record.get("exact_exit_receipts", [])
    receipt_ids = {(item.get("identity", {}).get("pid"),
                    item.get("identity", {}).get("create_time_100ns"))
                   for item in receipts}
    require(len(receipts) == 2 and receipt_ids == expected_retired and
            all(item.get("complete") is True and
                item.get("wait_confirmed") is True and
                item.get("exit_code_credit_issued") is False and
                item.get("handle_identity_before_wait") == item.get("identity") and
                item.get("handle_identity_after_wait") == item.get("identity") and
                type(item.get("exit_code")) is int and item.get("exit_code") != 259
                for item in receipts),
            "not every retired tracked generation has its own same-handle natural-exit receipt")
    absences = record.get("absence_snapshots", [])
    checks = record.get("absence_checks", [])
    require(record.get("absence_snapshot_count") == 3 and
            len(absences) == 3 and len(checks) == 3 and
            all(item.get("complete") is True for item in absences) and
            all(check.get("root_exact") is True and
                check.get("other_previously_tracked_exact") is True and
                check.get("subtree_pids_absent") == sorted(pid for pid, _ in expected_retired) and
                check.get("orphan_descendant_count") == 0
                for check in checks),
            "positive recovery lacks three complete root/sibling-preserving subtree absences")
    discarded = record.get("discarded_attempt", {})
    require(type(record.get("partial_rss_bytes_not_credited")) is int and
            record["partial_rss_bytes_not_credited"] > 0 and
            discarded.get("observed_partial_rss_bytes_not_credited") ==
                record["partial_rss_bytes_not_credited"] and
            discarded.get("credited_rss_bytes") == 0 and
            discarded.get("credited_cpu_seconds") == {"user": 0.0, "system": 0.0} and
            discarded.get("exit_code_credit_issued") is False and
            record.get("rss_credit_bytes") == 0 and
            record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            record.get("exit_code_credit_issued") is False,
            "positive failed attempt did not discard positive partial RSS/CPU/exit values")
    require(positive.get("process_tree_working_set_bytes") == 2500 and
            positive.get("process_tree_user_cpu_seconds") == 0.25 and
            positive.get("process_tree_system_cpu_seconds") == 0.27 and
            {item.get("pid") for item in positive.get("processes", [])} == {
                ids["root"][0], ids["stable"][0]},
            "whole-sample retry credited stale first-attempt metrics or retained retired identities")

    close_receipt = registry.close_owned()
    closed = {(item.get("pid"), item.get("create_time_100ns"))
              for item in close_receipt.get("closed_owned_handles", [])}
    require(close_receipt.get("complete") is True and
            expected_retired.issubset(closed) and not registry.signalled,
            "successful natural-exit cleanup did not close exact owned handles without signalling")

    final_snapshot = context["final_snapshot"]
    with patch.object(controller, "_r23_exact_heavy_audit",
                      side_effect=lambda snapshot: empty_heavy_receipt(
                          controller, snapshot)):
        audit, termination = controller._r23_audit_and_cleanup(
            FakeProcess(ids["root"]), registry, ids["root"],
            set(ids.values()), True,
            unbound_observation_records=[],
            tracked_sample_exit_records=records)
    r21_audit = audit.get("tracked_sample_exit_final_audit", {})
    require(audit.get("complete") is True and
            r21_audit.get("complete") is True and
            r21_audit.get("residual_retired_generations") == [] and
            audit.get("residual_descendant_processes") == [] and
            audit.get("global_heavy_process_audit", {}).get("complete") is True and
            (termination is None or termination.get("signal_attempts") == []),
            "final cleanup did not close the tracked-exit receipt with no residuals/signals")

    final_audit_mutation_controls = test_final_audit_binding_controls(
        controller, record, ids, final_snapshot)

    cases = [{"name": "tracked conhost subtree natural exit, three absences, full retry, exact cleanup",
              "status": "pass", "retired_identity_count": len(expected_retired),
              "partial_rss_bytes_not_credited": record["partial_rss_bytes_not_credited"],
              "retry_rss_bytes": positive["process_tree_working_set_bytes"],
              "absence_snapshot_count": len(absences),
              "exact_exit_receipt_count": len(receipts),
              "final_cleanup_complete": audit.get("complete") is True}]

    for mode in ("reuse_during_confirmation", "incomplete_confirmation",
                 "other_tracked_missing", "orphan_remains", "target_reappears",
                 "retry_sample_incomplete", "root_exits"):
        rejected, rejected_registry, rejected_context = run_sample(controller, mode)
        rejected_records = rejected.get("tracked_sample_exit_races", [])
        candidate = rejected_records[0] if rejected_records else None
        if mode == "retry_sample_incomplete":
            require(len(rejected_records) == 1 and candidate is not None and
                    candidate.get("complete") is True and
                    candidate.get("retry_started") is True and
                    candidate.get("full_sample_completed_after_retry") is False and
                    rejected.get("sample_attempt_count") == 2,
                    "retry exhaustion was not recorded as incomplete after exactly one retry")
        elif mode == "root_exits":
            require(rejected.get("sample_complete") is False and
                    rejected.get("tracked_sample_exit_races") == [] and
                    rejected.get("sample_attempt_count") == 1,
                    "root exit was incorrectly accepted as a tracked descendant exit")
        else:
            require(candidate is not None and candidate.get("complete") is False and
                    candidate.get("retry_started") is False and
                    rejected.get("sample_attempt_count") == 1,
                    f"unsafe tracked-exit case {mode} retried or was marked complete")
        assert_no_credit(rejected, candidate)
        require(not rejected_registry.signalled,
                f"unsafe tracked-exit case {mode} signalled a process")
        cases.append({"name": f"{mode} fails closed without retry or credit",
                      "status": "pass",
                      "tracked_exit_record_count": len(rejected_records),
                      "query_count": rejected_context["query_count"]})

    return {"positive": cases[0], "controls": cases[1:],
            "final_audit_binding_controls": final_audit_mutation_controls,
            "final_audit_binding_negative_control_count":
                len(final_audit_mutation_controls),
            "positive_control_count": 1, "negative_control_count": len(cases) - 1}


def test_helper_negative_controls(controller: Any) -> list[dict[str, Any]]:
    native = controller._R23_TABLE
    ids = identity_rows(controller)
    tables = make_tables(controller)
    source = tables["source"]
    clean = tables["after"]
    root, stable, target, child = (ids[key] for key in
                                   ("root", "stable", "target", "child"))
    previous = [root, stable, target, child]
    base_receipt_tables = [clean, clean, clean]
    controls: list[dict[str, Any]] = []

    def invoke(label: str, *, target_id: tuple[int, int] = target,
               source_table: Any = source,
               prior: list[tuple[int, int]] = previous,
               handles: dict[tuple[int, int], Any] | None = None,
               confirmation_tables: list[Any] | None = None,
               wait_mode: str = "signaled",
               exit_mode: str = "valid",
               expired: bool = False) -> dict[str, Any]:
        handle_map = ({target: target, child: child} if handles is None else handles)
        queued = list(base_receipt_tables if confirmation_tables is None
                      else confirmation_tables)
        query_log: list[Any] = []

        def query() -> Any:
            if not queued:
                raise CheckFailure(f"unexpected confirmation query in {label}")
            value = queued.pop(0)
            query_log.append(value)
            return value

        def wait(handle: Any, timeout: float) -> bool:
            identity = tuple(handle)
            if wait_mode == "error":
                raise OSError("synthetic wait failure")
            if wait_mode == "timeout":
                return False
            if wait_mode == "non_boolean":
                return 1  # type: ignore[return-value]
            return identity in (target, child)

        def exit_code(handle: Any) -> int:
            identity = tuple(handle)
            if exit_mode == "error":
                raise OSError("synthetic GetExitCodeProcess failure")
            if exit_mode == "still_active" and identity == target:
                return 259
            return 17

        actual_deadline = (time.monotonic() - 1.0 if expired else
                           time.monotonic() + 60.0)
        with patch.object(native, "read_process_handle_identity",
                          side_effect=lambda handle: tuple(handle)), \
                patch.object(native, "wait_for_process_exit", side_effect=wait), \
                patch.object(native, "process_exit_code", side_effect=exit_code):
            record = controller._r21_confirm_tracked_sample_exit(
                source_table, target_id, root, prior, handle_map,
                sample_index=14, attempt_index=1,
                deadline_monotonic=actual_deadline, snapshot_provider=query)
        if record.get("complete") is not True:
            require(record.get("rss_credit_bytes") == 0 and
                    record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                    record.get("exit_code_credit_issued") is False and
                    record.get("retry_started") is False,
                    f"negative helper case {label} exposed credits or retry")
        controls.append({"name": label, "status": "pass",
                         "complete": record.get("complete") is True,
                         "error_count": len(record.get("errors", [])),
                         "absence_snapshot_count": record.get("absence_snapshot_count")})
        return record

    cases: list[tuple[str, dict[str, Any]]] = [
        ("root is not a recoverable tracked target", {"target_id": root}),
        ("cached handle PID/FILETIME mismatch", {
            "handles": {target: (target[0], target[1] + 1), child: child}}),
        ("WAIT_TIMEOUT does not prove natural exit", {"wait_mode": "timeout"}),
        ("native wait exception fails closed", {"wait_mode": "error"}),
        ("non-boolean native wait fails closed", {"wait_mode": "non_boolean"}),
        ("STILL_ACTIVE exit code fails closed", {"exit_mode": "still_active"}),
        ("exit-code read exception fails closed", {"exit_mode": "error"}),
        ("one-tick PID reuse in absence confirmation", {
            "confirmation_tables": [clean, table(controller, [
                (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
                (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
                (root[0], root[1], 4, "julia.exe"),
                (stable[0], stable[1], root[0], "tracked-sibling.exe"),
                (target[0], target[1] + 1, root[0], "reused.exe"),
            ]), clean]}),
        ("incomplete confirmation table fails closed", {
            "confirmation_tables": [clean, None, clean]}),
        ("another tracked identity missing fails closed", {
            "confirmation_tables": [clean, table(controller, [
                (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
                (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
                (root[0], root[1], 4, "julia.exe"),
            ]), clean]}),
        ("orphan descendant remains beneath retired generation", {
            "confirmation_tables": [clean, table(controller, [
                (0, native.WINDOWS_EPOCH_100NS + 1, 0, ""),
                (4, native.WINDOWS_EPOCH_100NS + 1, 0, "System"),
                (root[0], root[1], 4, "julia.exe"),
                (stable[0], stable[1], root[0], "tracked-sibling.exe"),
                (500, native.WINDOWS_EPOCH_100NS + 500, target[0], "orphan.exe"),
            ]), clean]}),
        ("target subtree reappears in confirmation", {
            "confirmation_tables": [clean, source, clean]}),
        ("deadline expiration prevents confirmation", {"expired": True}),
    ]
    for name, kwargs in cases:
        record = invoke(name, **kwargs)
        require(record.get("complete") is False and record.get("retry_started") is False,
                f"unsafe helper case was accepted: {name}")
    return controls


def run_suite(output: Path, controller_path: Path) -> tuple[int, dict[str, Any], str, str]:
    require(sys.dont_write_bytecode, "run this test with Python -B")
    output = output.resolve()
    require(output.parent == RUNS_ROOT,
            "R21 test evidence must be a direct child of the owned T2 runs directory")
    require(not output.exists(), f"refusing to overwrite existing run leaf: {output}")
    output.mkdir(parents=True, exist_ok=False)

    test_source = Path(__file__).resolve().read_bytes()
    test_hash_before = sha256(test_source)
    controller_path = controller_path.resolve()
    controller_hash_before = sha256(controller_path.read_bytes())
    controller, loaded_hash = load_controller(controller_path)
    require(loaded_hash == controller_hash_before,
            "controller bytes changed between pin and in-memory compile")
    r20_controller, r20_hash_before = load_controller(CONTROLLER_R20)
    receipt: dict[str, Any] = {
        "schema": "independent-vnext-t2-r21-tracked-sample-exit-tests-r2",
        "status": "fail",
        "python_executed": True,
        "julia_executed": False,
        "formal_t2_accepted": False,
        "controller_path": controller_path.relative_to(ROOT).as_posix(),
        "source_pins_before": {
            controller_path.relative_to(ROOT).as_posix(): controller_hash_before,
            CONTROLLER_R20.relative_to(ROOT).as_posix(): r20_hash_before,
            R23_TABLE.relative_to(ROOT).as_posix(): sha256(R23_TABLE.read_bytes()),
            R23_SUPERVISOR.relative_to(ROOT).as_posix(): sha256(R23_SUPERVISOR.read_bytes()),
            Path(__file__).resolve().relative_to(ROOT).as_posix(): test_hash_before,
        },
        "exact_launcher_argv": [sys.executable, "-B",
                                str(Path(__file__).resolve()), *sys.argv[1:]],
        "static_controls": None,
        "sample_controls": None,
        "helper_negative_controls": [],
        "negative_control_count": 0,
        "positive_control_count": 0,
    }
    stdout_text = ""
    stderr_text = ""
    exit_code = 1
    try:
        receipt["static_controls"] = test_static_contract(controller, r20_controller)
        receipt["sample_controls"] = test_sample_controls(controller)
        receipt["helper_negative_controls"] = test_helper_negative_controls(controller)
        receipt["positive_control_count"] = receipt["sample_controls"]["positive_control_count"]
        receipt["negative_control_count"] = (
            receipt["sample_controls"]["negative_control_count"] +
            len(receipt["helper_negative_controls"]) +
            receipt["sample_controls"]["final_audit_binding_negative_control_count"])
        receipt["status"] = "pass"
        exit_code = 0
        stdout_text = (
            "R21_TRACKED_SAMPLE_EXIT_TESTS=PASS\n"
            f"positive_controls={receipt['positive_control_count']}\n"
            f"negative_controls={receipt['negative_control_count']}\n")
    except Exception:
        stderr_text = traceback.format_exc()
        receipt["status"] = "fail"
        receipt["failure"] = stderr_text
        stdout_text = "R21_TRACKED_SAMPLE_EXIT_TESTS=FAIL\n"

    source_after = {
        controller_path.relative_to(ROOT).as_posix(): sha256(controller_path.read_bytes()),
        CONTROLLER_R20.relative_to(ROOT).as_posix(): sha256(CONTROLLER_R20.read_bytes()),
        R23_TABLE.relative_to(ROOT).as_posix(): sha256(R23_TABLE.read_bytes()),
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): sha256(R23_SUPERVISOR.read_bytes()),
        Path(__file__).resolve().relative_to(ROOT).as_posix(): sha256(Path(__file__).resolve().read_bytes()),
    }
    receipt["source_pins_after"] = source_after
    receipt["source_pins_unchanged"] = source_after == receipt["source_pins_before"]
    receipt["test_exit_code"] = exit_code
    if not receipt["source_pins_unchanged"]:
        receipt["status"] = "fail"
        receipt["test_exit_code"] = 1
        exit_code = 1
        stdout_text = "R21_TRACKED_SAMPLE_EXIT_TESTS=FAIL\n"
        stderr_text += "Source bytes changed during the test run.\n"
    (output / "stdout.raw").write_text(stdout_text, encoding="utf-8", newline="\n")
    (output / "stderr.raw").write_text(stderr_text, encoding="utf-8", newline="\n")
    (output / "exit_code.txt").write_text(f"{exit_code}\n", encoding="ascii")
    (output / "command_argv.json").write_text(
        json.dumps(receipt["exact_launcher_argv"], indent=2) + "\n",
        encoding="utf-8", newline="\n")
    (output / "evidence.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n")
    print(stdout_text, end="", flush=True)
    if stderr_text:
        print(stderr_text, end="", file=sys.stderr, flush=True)
    return exit_code, receipt, stdout_text, stderr_text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--controller", default=str(CONTROLLER_R21))
    args = parser.parse_args()
    exit_code, _, _, _ = run_suite(Path(args.output), Path(args.controller))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
