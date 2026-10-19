from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
import types
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = Path(__file__).resolve().parent
RUNNER = Path(__file__).resolve()
FIXTURE = TEST_ROOT / "r22_pre_tree_tracked_exit_host_fixture.py"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r22.py"
VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r12.py"
NATIVE_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
STATIC_QA = TEST_ROOT / "static_qa_independent_negative_r22.py"
CONTROL_TEST = TEST_ROOT / "test_r22_pre_tree_tracked_exit_independent.py"
WORKING_SET_LIMIT_BYTES = 2_147_483_648
PHASE_TIMEOUT_SECONDS = 30.0


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.resolve().relative_to(ROOT).as_posix(),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def source_pins() -> dict[str, dict[str, Any]]:
    return {name: file_receipt(path) for name, path in (
        ("runner", RUNNER), ("fixture", FIXTURE), ("controller", CONTROLLER),
        ("projection_validator", VALIDATOR), ("native_process_table", NATIVE_TABLE),
        ("supervisor", SUPERVISOR), ("static_qa", STATIC_QA),
        ("focused_python_controls", CONTROL_TEST))}


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def snapshot_rows(module: types.ModuleType, snapshot: Any) -> list[dict[str, Any]]:
    table = module._R23_TABLE.validate_snapshot(snapshot)
    return [{"pid": row.identity.pid,
             "create_time_100ns": row.identity.create_time_100ns,
             "ppid": row.ppid, "name": row.name}
            for row in sorted(table.rows, key=lambda value: value.identity.pid)]


def identity_from_row(row: Any) -> tuple[int, int]:
    return row.identity.pid, row.identity.create_time_100ns


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_controller(expected_sha256: str) -> types.ModuleType:
    source = CONTROLLER.read_bytes()
    observed = hashlib.sha256(source).hexdigest()
    require(observed == expected_sha256,
            f"R22 controller pin mismatch: expected {expected_sha256}, got {observed}")
    module = types.ModuleType("r22_pre_tree_host_smoke_controller")
    module.__file__ = str(CONTROLLER)
    module.__package__ = ""
    sys.dont_write_bytecode = True
    exec(compile(source, str(CONTROLLER), "exec"), module.__dict__)
    return module


def target_row_receipt(module: types.ModuleType, snapshot: Any,
                       target_pid: int) -> dict[str, Any]:
    table = module._R23_TABLE.validate_snapshot(snapshot)
    row = table.by_pid.get(target_pid)
    require(row is not None, f"target PID {target_pid} absent from required source table")
    return {"pid": row.identity.pid,
            "create_time_100ns": row.identity.create_time_100ns,
            "ppid": row.ppid, "name": row.name}


def install_hooks(module: types.ModuleType, phase_dir: Path,
                  state: dict[str, Any]) -> dict[str, Any]:
    native = module._R23_TABLE
    registry_class = module._R23_SUPERVISOR.ExactHandleRegistry
    originals = {
        "query": native.query_native_process_table,
        "for_row": registry_class.for_row,
        "wait": native.wait_for_process_exit,
        "exit_code": native.process_exit_code,
        "sample": module._r20_native_sample,
        "resource_reader": module._r23_resource_reader,
    }
    root_ready = phase_dir / "root_ready.json"
    start_child = phase_dir / "start_child.json"
    target_ready = phase_dir / "target_ready.json"
    target_release = phase_dir / "target_release.json"
    target_parent_wait = phase_dir / "target_parent_wait.json"
    target_natural_exit = phase_dir / "target_natural_exit.json"
    root_release = phase_dir / "root_release.json"
    deadline = time.monotonic() + PHASE_TIMEOUT_SECONDS - 2.0

    def wait_json(path: Path, label: str, until: float = deadline) -> dict[str, Any]:
        while time.monotonic() < until:
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
                if isinstance(value, dict):
                    return value
            except (OSError, ValueError):
                pass
            time.sleep(0.01)
        raise RuntimeError(f"R22 fixture marker did not arrive: {label}")

    def query_native() -> Any:
        # The special outside-sample query is the run_phase outer reconciliation
        # table immediately after complete sample 3. Preserve that exact object
        # even though the target naturally exits before the inner sample query.
        if (state.get("last_completed_sample_index") == 3 and
                state.get("inside_sample") is not True and
                state.get("race_boundary_triggered") is not True):
            outer = native.validate_snapshot(originals["query"]())
            root_identity = state.get("root_identity")
            target_pid = state.get("target_pid")
            require(outer.complete is True,
                    "outer reconciliation SPI snapshot was incomplete")
            require(type(root_identity) is tuple and type(target_pid) is int,
                    "sample-3 exact root/target generation was not captured")
            root_row = outer.by_pid.get(root_identity[0])
            row = outer.by_pid.get(target_pid)
            require(root_row is not None and identity_from_row(root_row) == root_identity,
                    "outer reconciliation source lost/reused the exact root")
            require(row is not None and identity_from_row(row) ==
                    state.get("target_identity") and row.ppid == root_identity[0],
                    "outer reconciliation source did not retain the exact direct child")
            state["outer_reconcile_snapshot"] = outer
            state["outer_reconcile_rows"] = snapshot_rows(module, outer)
            state["outer_reconcile_receipt"] = module._r23_snapshot_receipt(outer)
            state["race_boundary_triggered"] = True
            write_json(target_release, {
                "schema": "vnext-t2-r22-host-target-natural-exit-request-r1",
                "target_identity": {"pid": row.identity.pid,
                                    "create_time_100ns": row.identity.create_time_100ns},
                "reason": "after exact live outer reconciliation snapshot and sample 3"})
            parent_receipt = wait_json(target_parent_wait, "target parent wait")
            natural_receipt = wait_json(target_natural_exit, "target natural exit")
            require(parent_receipt.get("target_pid") == target_pid and
                    parent_receipt.get("wait_exit_code") == 0 and
                    parent_receipt.get("parent_reaped_target") is True and
                    natural_receipt.get("pid") == target_pid and
                    natural_receipt.get("natural_exit") is True and
                    natural_receipt.get("release_marker_seen") is True,
                    "fixture child did not exit naturally with parent wait/receipt")
            state["target_natural_exit_receipt"] = natural_receipt
            state["target_parent_wait_receipt"] = parent_receipt
            absence_deadline = min(deadline, time.monotonic() + 4.0)
            absence_checks = []
            while time.monotonic() < absence_deadline:
                after = native.validate_snapshot(originals["query"]())
                require(after.complete is True,
                        "post-exit real SPI absence check returned an incomplete table")
                current = after.by_pid.get(target_pid)
                if current is not None:
                    require(identity_from_row(current) == state["target_identity"],
                            "target PID was reused before absence was observed")
                absence_checks.append({
                    "snapshot": module._r23_snapshot_receipt(after),
                    "target_pid_present": current is not None,
                    "target_identity": (list(identity_from_row(current))
                                        if current is not None else None),
                })
                if current is None:
                    state["natural_exit_spi_absence_confirmed"] = True
                    break
                time.sleep(0.01)
            require(state.get("natural_exit_spi_absence_confirmed") is True,
                    "target PID did not disappear from real SPI within the bounded poll")
            state["pre_inner_absence_poll"] = absence_checks
            # Return the unchanged outer current. The controller must take a new
            # inner before-sample snapshot, where the target is now absent.
            return outer

        snapshot = originals["query"]()
        if state.get("inside_sample") is True:
            sample_index = state.get("active_sample_index")
            state.setdefault("sample_query_receipts", {}).setdefault(
                sample_index, []).append(module._r23_snapshot_receipt(snapshot))
            state.setdefault("sample_query_rows", {}).setdefault(
                sample_index, []).append(snapshot_rows(module, snapshot))
        return snapshot

    def for_row(registry: Any, row: Any, snapshot: Any) -> Any:
        identity = identity_from_row(row)
        target_identity = state.get("target_identity")
        call = {"identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "sample_index": state.get("active_sample_index"),
                "after_race_boundary": state.get("race_boundary_triggered") is True,
                "already_cached": identity in registry._handles}
        handle = originals["for_row"](registry, row, snapshot)
        if identity == target_identity:
            call["opened_by_registry"] = not call["already_cached"]
            state.setdefault("target_for_row_calls", []).append(call)
            state["target_registry_handle"] = handle
        return handle

    def wait_for_exit(handle: Any, timeout_seconds: float) -> bool:
        result = originals["wait"](handle, timeout_seconds)
        identity = native.read_process_handle_identity(handle)
        if identity == state.get("target_identity"):
            state.setdefault("target_waits", []).append({
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "timeout_seconds": timeout_seconds,
                "result": result,
                "wait_object_0": result is True,
            })
        return result

    def exit_code_reader(handle: Any) -> int:
        code = originals["exit_code"](handle)
        identity = native.read_process_handle_identity(handle)
        if identity == state.get("target_identity"):
            state.setdefault("target_exit_codes", []).append({
                "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
                "exit_code": code,
            })
        return code

    def resource_reader(pid: int) -> dict[str, Any]:
        state.setdefault("resource_reads", []).append({
            "pid": pid,
            "sample_index": state.get("active_sample_index"),
            "after_race_boundary": state.get("race_boundary_triggered") is True,
        })
        return originals["resource_reader"](pid)

    def sample_hook(*args: Any, **kwargs: Any) -> dict[str, Any]:
        sample_index = kwargs.get("sample_index")
        require(type(sample_index) is int,
                "R22 sampler hook did not receive an integer sample index")
        state["active_sample_index"] = sample_index
        if sample_index == 1:
            wait_json(root_ready, "root ready")
            write_json(start_child, {
                "schema": "vnext-t2-r22-host-fixture-start-child-r1",
                "after_outer_sample_1_query": True})
            ready = wait_json(target_ready, "tracked child ready")
            require(type(ready.get("pid")) is int and ready["pid"] > 0,
                    "fixture child ready marker lacks native PID")
            target_pid = ready["pid"]
            state["target_pid"] = target_pid
            ready_table = native.validate_snapshot(originals["query"]())
            ready_row = ready_table.by_pid.get(target_pid)
            require(len(args) > 2,
                    "sampler hook did not receive its exact root identity")
            root_identity = tuple(args[2])
            state["root_identity"] = root_identity
            root_row = ready_table.by_pid.get(root_identity[0])
            require(ready_table.complete is True and ready_row is not None and
                    identity_from_row(ready_row)[0] == target_pid and
                    root_row is not None and identity_from_row(root_row) == root_identity and
                    ready_row.ppid == root_identity[0],
                    "real target child was not directly under the exact root before sample 1")
            state["target_identity"] = identity_from_row(ready_row)
            state["sample_one_ready_snapshot"] = module._r23_snapshot_receipt(ready_table)

        if sample_index == 4:
            previous_source = kwargs.get("previous_accepted_source_snapshot")
            outer_source = kwargs.get("outer_reconcile_snapshot")
            require(kwargs.get("previous_accepted_sample_index") == 3 and
                    previous_source is not None and outer_source is
                    state.get("outer_reconcile_snapshot"),
                    "sample 4 did not receive the two distinct sample-3/outer source snapshots")
            previous_source = native.validate_snapshot(previous_source)
            outer_source = native.validate_snapshot(outer_source)
            for label, table in (("previous accepted sample 3", previous_source),
                                 ("outer reconciliation", outer_source)):
                root_row = table.by_pid.get(state["root_identity"][0])
                target_row = table.by_pid.get(state["target_pid"])
                require(table.complete is True and root_row is not None and
                        identity_from_row(root_row) == state["root_identity"] and
                        target_row is not None and
                        identity_from_row(target_row) == state["target_identity"] and
                        target_row.ppid == state["root_identity"][0],
                        f"{label} failed to preserve the exact target subtree")
            state["sample4_source_binding"] = {
                "previous_accepted_sample_index": 3,
                "previous_accepted_source_receipt": module._r23_snapshot_receipt(previous_source),
                "outer_reconcile_source_receipt": module._r23_snapshot_receipt(outer_source),
                "different_snapshot_objects": previous_source is not outer_source,
                "target_identity": {"pid": state["target_identity"][0],
                                    "create_time_100ns": state["target_identity"][1]},
            }
            registry = args[1]
            cached = registry._handles.get(state["target_identity"])
            require(cached is not None and cached is state.get("target_registry_handle") and
                    native.read_process_handle_identity(cached) == state["target_identity"],
                    "sample 4 lost the cached original target handle before exact exit proof")
            state["cached_original_handle_identity_before_proof"] = list(
                native.read_process_handle_identity(cached))

        state["inside_sample"] = True
        try:
            value = originals["sample"](*args, **kwargs)
        finally:
            state["inside_sample"] = False

        if value.get("sample_complete") is True:
            state["last_completed_sample_index"] = sample_index
            outputs = kwargs.get("completed_source_snapshot_out")
            if type(outputs) is list and outputs:
                state.setdefault("completed_source_snapshots", {})[sample_index] = outputs[0]
            if sample_index in (1, 2, 3):
                source = (outputs[0] if type(outputs) is list and outputs else None)
                require(source is not None,
                        f"complete sample {sample_index} did not expose its source SPI table")
                table = native.validate_snapshot(source)
                root_row = table.by_pid.get(state["root_identity"][0])
                target_row = table.by_pid.get(state["target_pid"])
                require(table.complete is True and root_row is not None and
                        identity_from_row(root_row) == state["root_identity"] and
                        target_row is not None and
                        identity_from_row(target_row) == state["target_identity"] and
                        target_row.ppid == state["root_identity"][0],
                        f"sample {sample_index} did not measure the same live root/target closure")
                state.setdefault("three_live_sample_sources", []).append({
                    "sample_index": sample_index,
                    "snapshot": module._r23_snapshot_receipt(table),
                    "target_identity": {"pid": state["target_identity"][0],
                                        "create_time_100ns": state["target_identity"][1]},
                })
        if sample_index == 4:
            state["sample4_result"] = value
            # Release the root regardless of the sample result so failed test
            # runs still reach controller-owned termination and final audit.
            write_json(root_release, {
                "schema": "vnext-t2-r22-host-fixture-root-release-r1",
                "after_sample_index": 4,
                "sample_complete": value.get("sample_complete") is True})
        return value

    native.query_native_process_table = query_native
    native.wait_for_process_exit = wait_for_exit
    native.process_exit_code = exit_code_reader
    module._r23_resource_reader = resource_reader
    registry_class.for_row = for_row
    module._r20_native_sample = sample_hook

    def restore() -> None:
        native.query_native_process_table = originals["query"]
        native.wait_for_process_exit = originals["wait"]
        native.process_exit_code = originals["exit_code"]
        module._r23_resource_reader = originals["resource_reader"]
        registry_class.for_row = originals["for_row"]
        module._r20_native_sample = originals["sample"]

    return {"restore": restore, "originals": originals}


def identity_pair(value: Any, label: str) -> tuple[int, int]:
    require(type(value) is dict and type(value.get("pid")) is int and
            0 < value["pid"] <= 0xFFFFFFFF and
            type(value.get("create_time_100ns")) is int and
            value["create_time_100ns"] > 0,
            f"{label} is not an exact native PID/FILETIME identity")
    return value["pid"], value["create_time_100ns"]


def identity_set(values: Any, label: str) -> set[tuple[int, int]]:
    require(type(values) is list,
            f"{label} is not an identity list")
    result = [identity_pair(value, label) for value in values]
    require(len(result) == len(set(result)),
            f"{label} contains duplicate PID/FILETIME generations")
    require(len({pid for pid, _ in result}) == len(result),
            f"{label} contains multiple generations for one PID")
    return set(result)


def row_map(rows: Any, label: str) -> dict[int, dict[str, Any]]:
    require(type(rows) is list,
            f"{label} is not a native row list")
    result: dict[int, dict[str, Any]] = {}
    for row in rows:
        require(type(row) is dict and type(row.get("pid")) is int and
                0 <= row["pid"] <= 0xFFFFFFFF and
                type(row.get("create_time_100ns")) is int and
                row["create_time_100ns"] > 0 and
                type(row.get("ppid")) is int and
                0 <= row["ppid"] <= 0xFFFFFFFF and
                type(row.get("name")) is str,
                f"{label} contains a malformed native process row")
        require(row["pid"] not in result,
                f"{label} contains duplicate PID rows")
        result[row["pid"]] = {
            "pid": row["pid"],
            "create_time_100ns": row["create_time_100ns"],
            "ppid": row["ppid"],
            "name": row["name"],
        }
    return result


def source_bundle_rows(bundle: Any, label: str) -> dict[int, dict[str, Any]]:
    require(type(bundle) is dict and type(bundle.get("snapshot")) is dict and
            bundle["snapshot"].get("complete") is True,
            f"{label} lacks a complete source snapshot receipt")
    rows = row_map(bundle.get("rows"), label)
    require(bundle["snapshot"].get("row_count") == len(rows),
            f"{label} row count does not match its complete SPI receipt")
    return rows


def native_snapshot_rows(module: types.ModuleType, snapshot: Any,
                         label: str) -> dict[int, dict[str, Any]]:
    table = module._R23_TABLE.validate_snapshot(snapshot)
    require(table.complete is True,
            f"{label} is not a complete native process table")
    return row_map(snapshot_rows(module, table), label)


def verify_recorded_tracked_subtree(
        module: types.ModuleType, record: dict[str, Any],
        state: dict[str, Any], proof: dict[str, Any]
        ) -> tuple[set[tuple[int, int]], set[tuple[int, int]],
                   dict[tuple[int, int], dict[str, Any]]]:
    """Derive the exited subtree from both complete source tables and raw PPIDs."""
    root_identity = tuple(state.get("root_identity", ()))
    target_identity = tuple(state.get("target_identity", ()))
    require(len(root_identity) == 2 and len(target_identity) == 2 and
            root_identity != target_identity,
            "R2 fixture root/target generation identities are absent or aliased")
    root_id = identity_pair({"pid": root_identity[0],
                             "create_time_100ns": root_identity[1]},
                            "fixture root identity")
    target_id = identity_pair({"pid": target_identity[0],
                               "create_time_100ns": target_identity[1]},
                              "fixture target identity")
    record_root = identity_pair(record.get("root_identity"), "record root identity")
    record_target = identity_pair(record.get("target_identity"), "record target identity")
    proof_root = identity_pair(proof.get("root_identity"), "proof root identity")
    proof_target = identity_pair(proof.get("target_identity"), "proof target identity")
    require((record_root, record_target, proof_root, proof_target) ==
            (root_id, target_id, root_id, target_id),
            "pre-tree receipt root/target differs from the live fixture generations")

    tracked = identity_set(record.get("previously_tracked_identities"),
                           "record previously tracked identities")
    proof_tracked = identity_set(proof.get("previously_tracked_identities"),
                                 "proof previously tracked identities")
    require(tracked == proof_tracked and root_id in tracked and target_id in tracked,
            "pre-tree proof does not bind the exact historical tracked set")
    tracked_by_pid = {pid: (pid, ticks) for pid, ticks in tracked}

    accepted_rows = source_bundle_rows(
        record.get("previous_accepted_source"), "previous accepted source")
    outer_rows = source_bundle_rows(
        record.get("outer_reconcile_source"), "outer reconcile source")
    historical_rows: dict[tuple[int, int], dict[str, Any]] = {}
    for identity in tracked:
        pid, ticks = identity
        accepted = accepted_rows.get(pid)
        outer = outer_rows.get(pid)
        require(accepted is not None and outer is not None and
                accepted["create_time_100ns"] == ticks and
                outer["create_time_100ns"] == ticks and accepted == outer,
                f"source tables do not agree on exact tracked PID/FILETIME {pid}")
        historical_rows[identity] = accepted

    closure_rows = row_map(proof.get("source_root_closure"),
                           "historical source root closure")
    require(set(closure_rows) == {pid for pid, _ in tracked},
            "source closure does not enumerate every and only historical tracked PID")
    for identity, expected_row in historical_rows.items():
        require(closure_rows[identity[0]] == expected_row,
                f"source closure row differs for tracked generation {identity[0]}")

    require(historical_rows[root_id]["ppid"] > 0,
            "historical root row is missing its native parent PID")
    for identity in tracked:
        if identity == root_id:
            continue
        row = historical_rows[identity]
        parent_identity = tracked_by_pid.get(row["ppid"])
        require(parent_identity is not None and
                row["create_time_100ns"] >= parent_identity[1],
                f"tracked generation {identity[0]} lacks a monotonic exact parent edge")
        cursor = identity
        visited: set[tuple[int, int]] = set()
        while cursor != root_id:
            require(cursor not in visited,
                    f"historical tracked closure contains a parent cycle at PID {cursor[0]}")
            visited.add(cursor)
            parent = historical_rows[cursor]["ppid"]
            next_identity = tracked_by_pid.get(parent)
            require(next_identity is not None and
                    historical_rows[cursor]["create_time_100ns"] >= next_identity[1],
                    f"tracked PID {cursor[0]} is unreachable from the exact fixture root")
            cursor = next_identity

    target_row = historical_rows[target_id]
    require(target_row["ppid"] == root_id[0],
            "tracked target was not an exact direct child of the fixture root")
    subtree = {target_id}
    changed = True
    while changed:
        changed = False
        for identity in tracked - subtree:
            row = historical_rows[identity]
            parent_identity = tracked_by_pid.get(row["ppid"])
            if parent_identity in subtree:
                require(row["create_time_100ns"] >= parent_identity[1],
                        f"owned subtree edge to PID {identity[0]} is not monotonic")
                subtree.add(identity)
                changed = True
    source_subtree = {target_id}
    changed = True
    while changed:
        changed = False
        subtree_pids = {pid for pid, _ in source_subtree}
        for row in accepted_rows.values():
            if row["ppid"] not in subtree_pids:
                continue
            parent = accepted_rows.get(row["ppid"])
            require(parent is not None,
                    f"complete source table lacks parent row for PID {row['pid']}")
            if row["create_time_100ns"] < parent["create_time_100ns"]:
                continue
            child_identity = (row["pid"], row["create_time_100ns"])
            require(child_identity in tracked,
                    f"complete source table has an untracked descendant PID {row['pid']}")
            if child_identity not in source_subtree:
                source_subtree.add(child_identity)
                changed = True
    require(source_subtree == subtree,
            "tracked target subtree is not the complete descendant closure in raw SPI")
    outside = tracked - subtree
    require(root_id in outside and target_id not in outside,
            "derived exited subtree incorrectly contains or omits the exact root")

    nested_observed = row_map(proof.get("observed_generations"),
                              "observed exited tracked generations")
    expected_subtree_rows = {pid: historical_rows[(pid, ticks)]
                             for pid, ticks in subtree}
    require(nested_observed == expected_subtree_rows,
            "observed generations are not exactly the source-derived target subtree")
    return subtree, outside, historical_rows


def verify_phase(module: types.ModuleType, phase: dict[str, Any],
                 state: dict[str, Any], phase_dir: Path) -> dict[str, Any]:
    records = phase.get("pre_tree_tracked_exit_races", [])
    require(phase.get("stop_reason") == "natural_exit" and phase.get("exit_code") == 0,
            "R22 phase did not finish with natural root exit and code 0")
    require(phase.get("seconds", 10**9) <= PHASE_TIMEOUT_SECONDS and
            phase.get("timeout_seconds") == PHASE_TIMEOUT_SECONDS and
            phase.get("working_set_limit_bytes") == WORKING_SET_LIMIT_BYTES,
            "R22 smoke phase exceeded the fixed 30-second/2-GiB contract")
    require(phase.get("stderr", {}).get("bytes") == 0,
            "R22 root fixture wrote unexpected stderr")
    require(len(records) == 1,
            "R22 phase did not retain exactly one pre-tree tracked exit receipt")
    record = records[0]
    proof = record.get("r21_exact_exit_proof", {})
    failed_bundle = record.get("failed_attempt_source", {})
    failed_rows = failed_bundle.get("rows", [])
    accepted_bundle = record.get("previous_accepted_source", {})
    outer_bundle = record.get("outer_reconcile_source", {})
    target = tuple(state.get("target_identity", ()))
    root = tuple(state.get("root_identity", ()))
    subtree, outside, historical_rows = \
        verify_recorded_tracked_subtree(module, record, state, proof)
    subtree_pids = {pid for pid, _ in subtree}
    expected_subtree_pids = sorted(subtree_pids)
    expected_outside_rows = {identity[0]: historical_rows[identity]
                             for identity in outside}
    failed_rows_by_pid = row_map(failed_rows, "failed sample source")
    require(failed_bundle.get("snapshot", {}).get("complete") is True and
            failed_bundle["snapshot"].get("row_count") == len(failed_rows_by_pid),
            "failed sample source is not a complete row-count-bound SPI table")
    target_rows_failed = [row for pid, row in failed_rows_by_pid.items()
                          if pid in subtree_pids]
    for pid, expected_row in expected_outside_rows.items():
        require(failed_rows_by_pid.get(pid) == expected_row,
                f"failed attempt lost or changed still-live tracked PID {pid}")
    exact_exit = record.get("exact_exit_receipts", [])
    proof_exact_exit = proof.get("exact_exit_receipts", [])
    exact_exit_by_identity: dict[tuple[int, int], dict[str, Any]] = {}
    for item in exact_exit:
        identity = identity_pair(item.get("identity"), "exact exit receipt identity")
        require(identity not in exact_exit_by_identity,
                "exact-exit receipts duplicate a tracked generation")
        exact_exit_by_identity[identity] = item
    proof_exit_by_identity: dict[tuple[int, int], dict[str, Any]] = {}
    for item in proof_exact_exit:
        identity = identity_pair(item.get("identity"),
                                 "nested exact exit receipt identity")
        require(identity not in proof_exit_by_identity,
                "nested exact-exit receipts duplicate a tracked generation")
        proof_exit_by_identity[identity] = item
    require(exact_exit_by_identity == proof_exit_by_identity,
            "outer and nested exact-exit receipt sets disagree")
    target_exit = exact_exit_by_identity.get(target)
    record_retired = identity_set(record.get("retired_tracked_identities"),
                                  "record retired tracked generations")
    proof_retired = identity_set(proof.get("retired_tracked_identities"),
                                 "proof retired tracked generations")
    require(record_retired == proof_retired == subtree,
            "recorded retirement set does not exactly equal the source-derived subtree")
    absences = record.get("absence_snapshots", [])
    proof_absences = proof.get("absence_snapshots", [])
    absence_checks = record.get("absence_checks", [])
    proof_absence_checks = proof.get("absence_checks", [])
    handle_close = phase.get("handle_close_receipt", {})
    final_audit = phase.get("final_process_tree_audit", {})
    r22_audit = phase.get("pre_tree_tracked_exit_final_audit", {})
    target_calls = state.get("target_for_row_calls", [])
    target_open_calls = [call for call in target_calls
                         if call.get("opened_by_registry") is True]
    target_post_boundary_calls = [call for call in target_calls
                                  if call.get("after_race_boundary") is True]
    failed_query_rows = state.get("sample_query_rows", {}).get(4, [])
    query_receipts = state.get("sample_query_receipts", {}).get(4, [])
    discarded = record.get("discarded_attempt", {})
    retried_source = state.get("completed_source_snapshots", {}).get(4)
    root_natural_exit = json.loads(
        (phase_dir / "root_natural_exit.json").read_text(encoding="utf-8"))
    target_natural_exit = state.get("target_natural_exit_receipt", {})
    target_parent_wait = state.get("target_parent_wait_receipt", {})

    require(state.get("race_boundary_triggered") is True and
            state.get("natural_exit_spi_absence_confirmed") is True and
            len(state.get("three_live_sample_sources", [])) == 3 and
            root_natural_exit.get("pid") == root[0] and
            root_natural_exit.get("target_pid") == target[0] and
            root_natural_exit.get("target_wait_exit_code") == 0 and
            root_natural_exit.get("natural_exit") is True and
            root_natural_exit.get("root_release_marker_seen") is True and
            target_natural_exit.get("pid") == target[0] and
            target_natural_exit.get("natural_exit") is True and
            target_parent_wait.get("target_pid") == target[0] and
            target_parent_wait.get("wait_exit_code") == 0 and
            target_parent_wait.get("parent_reaped_target") is True and
            not (phase_dir / "fixture_failure.json").exists(),
            "R22 live sample history or real SPI natural-exit boundary is incomplete")
    require(record.get("schema") == "vnext-t2-r22-pre-tree-tracked-exit-r1" and
            record.get("complete") is True and record.get("retry_started") is True and
            record.get("full_sample_completed_after_retry") is True and
            record.get("logical_sample_index") == 4 and
            record.get("previous_accepted_sample_index") == 3 and
            record.get("whole_sample_attempt_index") == 1 and
            record.get("full_sample_attempt_index") == 2,
            "R22 pre-tree evidence did not prove sample-4 recovery and full attempt-2 retry")
    require(record.get("root_identity") == {"pid": root[0],
                                              "create_time_100ns": root[1]} and
            record.get("target_identity") == {"pid": target[0],
                                                "create_time_100ns": target[1]} and
            accepted_bundle.get("snapshot") ==
                state["sample4_source_binding"]["previous_accepted_source_receipt"] and
            outer_bundle.get("snapshot") == state.get("outer_reconcile_receipt") and
            state["sample4_source_binding"].get("different_snapshot_objects") is True,
            "R22 two source-generation boundaries do not bind the live PID/raw FILETIME")
    require(len(target_rows_failed) == 0 and
            failed_bundle.get("snapshot", {}).get("complete") is True and
            any(row.get("pid") == root[0] and
                row.get("create_time_100ns") == root[1]
                for row in failed_rows),
            "R22 failed inner-before SPI did not retain the exact root while omitting the derived subtree")
    require(proof.get("complete") is True and proof.get("absence_snapshot_count") == 3 and
            record.get("absence_snapshot_count") == 3 and
            absences == proof_absences and len(absences) == 3 and
            absence_checks == proof_absence_checks and len(absence_checks) == 3 and
            all(item.get("complete") is True for item in absences),
            "R22 exact cached-handle proof lacks three complete absence confirmations")
    for index, (check, absence) in enumerate(zip(absence_checks, absences), start=1):
        observed_outside = identity_set(
            check.get("other_previously_tracked_identities"),
            f"absence check {index} outside tracked identities")
        require(check.get("index") == index and
                check.get("snapshot") == absence and
                absence.get("schema") == "vnext-t2-r23-native-snapshot-receipt-r1" and
                check.get("subtree_pids_absent") == expected_subtree_pids and
                check.get("root_identity") == {"pid": root[0],
                                                   "create_time_100ns": root[1]} and
                check.get("root_exact") is True and
                observed_outside == outside and
                check.get("other_previously_tracked_exact") is True and
                check.get("orphan_descendant_count") == 0,
                f"R22 absence confirmation {index} does not match the source-derived subtree")
    require(set(exact_exit_by_identity) == subtree,
            "exact old-generation exit receipts do not cover every and only retired subtree generation")
    for identity in subtree:
        receipt = exact_exit_by_identity[identity]
        identity_wire = {"pid": identity[0], "create_time_100ns": identity[1]}
        require(receipt.get("schema") ==
                "vnext-t2-r21-tracked-generation-natural-exit-r1" and
                receipt.get("complete") is True and
                receipt.get("identity") == identity_wire and
                receipt.get("handle_identity_before_wait") == identity_wire and
                receipt.get("handle_identity_after_wait") == identity_wire and
                receipt.get("wait_confirmed") is True and
                type(receipt.get("exit_code")) is int and
                receipt.get("exit_code") != 259 and
                receipt.get("exit_code_credit_issued") is False and
                receipt.get("errors") == [],
                f"tracked subtree generation {identity[0]} lacks exact handle natural-exit proof")
    require(target_exit is not None,
            "target-generation exact exit receipt was not located by PID/FILETIME identity")
    require(record.get("rss_credit_bytes") == 0 and
            record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            record.get("exit_code_credit_issued") is False and
            proof.get("rss_credit_bytes") == 0 and
            proof.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            proof.get("exit_code_credit_issued") is False and
            discarded.get("credited_rss_bytes") == 0 and
            discarded.get("credited_cpu_seconds") == {"user": 0.0, "system": 0.0} and
            discarded.get("exit_code_credit_issued") is False and
            discarded.get("observed_partial_rss_bytes_not_credited") == 0 and
            discarded.get("measured_identities_not_credited") == [],
            "R22 failed attempt received RSS, CPU, or exit credit")
    require(len(target_open_calls) == 1 and len(target_calls) >= 1 and
            target_post_boundary_calls == [],
            "R22 target was reopened or rebound after its generation exited")
    require(state.get("target_registry_handle") is not None and
            state.get("cached_original_handle_identity_before_proof") == list(target) and
            any(item.get("identity") == {"pid": target[0],
                                           "create_time_100ns": target[1]} and
                item.get("result") is True and item.get("wait_object_0") is True
                for item in state.get("target_waits", [])) and
            any(item.get("identity") == {"pid": target[0],
                                           "create_time_100ns": target[1]} and
                item.get("exit_code") == target_exit.get("exit_code")
                for item in state.get("target_exit_codes", [])),
            "R22 original registry handle did not supply observed WAIT_OBJECT_0/exit code")
    closed_subtree = identity_set(handle_close.get("closed_owned_handles", []),
                                  "closed owned process handles")
    require(handle_close.get("complete") is True and handle_close.get("errors") == [] and
            subtree.issubset(closed_subtree),
            "R22 did not close the exact owned handle for every retired subtree generation")
    final_heavy_audit = final_audit.get("global_heavy_process_audit", {})
    require(r22_audit.get("complete") is True and r22_audit.get("errors") == [] and
            r22_audit.get("record_count") == 1 and
            identity_set(r22_audit.get("retired_tracked_identities", []),
                         "final retired tracked generations") == subtree and
            r22_audit.get("residual_retired_generations") == [] and
            final_audit.get("complete") is True and
            final_audit.get("root_identity") == {
                "pid": root[0], "create_time_100ns": root[1]} and
            final_audit.get("root_exit_confirmed") is True and
            final_audit.get("residual_descendant_processes") == [] and
            phase.get("residual_process_audit", {}).get("complete") is True and
            phase.get("residual_process_audit", {}).get("processes") == [] and
            phase.get("residual_process_audit", {}).get("controller_processes") == [] and
            phase.get("residual_process_audit", {}).get("native_heavy_identities") == [] and
            phase.get("residual_process_audit", {}).get("errors") == [] and
            final_heavy_audit.get("complete") is True and
            final_heavy_audit.get("processes") == [] and
            final_heavy_audit.get("controller_processes") == [] and
            final_heavy_audit.get("native_heavy_identities") == [] and
            final_heavy_audit.get("errors") == [],
            "R22 final tracked-generation or residual audit is incomplete")
    require(len(failed_query_rows) >= 6 and len(query_receipts) >= 6 and
            query_receipts[0] == failed_bundle.get("snapshot") and
            query_receipts[1:4] == absences and
            all(item.get("complete") is True for item in query_receipts),
            "R22 failed-before, three proof absences, and fresh absent-generation retry are not visible in native query trace")
    require(row_map(failed_query_rows[0], "failed-before native query") == failed_rows_by_pid,
            "failed-before native query rows differ from the typed failed-attempt source")
    for index, rows in enumerate(failed_query_rows[1:], start=1):
        current_rows = row_map(rows, f"post-failure native query {index}")
        require(not (subtree_pids & set(current_rows)) and
                all(current_rows.get(pid) == expected
                    for pid, expected in expected_outside_rows.items()),
                f"post-exit native query {index} reused a subtree PID or lost a live tracked generation")
    require(retried_source is not None and
            module._R23_TABLE.validate_snapshot(retried_source).complete is True and
            state.get("sample4_result", {}).get("sample_complete") is True,
            "R22 fresh whole-sample retry did not complete with the retired target absent")
    retried_rows = native_snapshot_rows(module, retried_source,
                                        "fresh full-sample retry source")
    require(not (subtree_pids & set(retried_rows)) and
            all(retried_rows.get(pid) == expected
                for pid, expected in expected_outside_rows.items()),
            "fresh full-sample retry did not preserve exact outside generations and subtree absence")
    require(not any(item.get("pid") == target[0] and
                    item.get("after_race_boundary") is True
                    for item in state.get("resource_reads", [])),
            "R22 attempted a target resource read after the exact generation exited")
    require(type(record.get("partial_rss_bytes_not_credited")) is int and
            record.get("partial_rss_bytes_not_credited") >= 0,
            "R22 failed-sample discarded metric evidence is malformed")
    return {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2",
        "phase_exit": {"stop_reason": phase.get("stop_reason"),
                       "exit_code": phase.get("exit_code"),
                       "seconds": phase.get("seconds"),
                       "timeout_seconds": phase.get("timeout_seconds"),
                       "working_set_limit_bytes": phase.get("working_set_limit_bytes"),
                       "stderr_bytes": phase.get("stderr", {}).get("bytes")},
        "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
        "target_identity": {"pid": target[0], "create_time_100ns": target[1]},
        "three_complete_live_samples": state["three_live_sample_sources"],
        "outer_reconcile_source": {
            "receipt": state.get("outer_reconcile_receipt"),
            "target_row": target_row_receipt(
                module, state["outer_reconcile_snapshot"], target[0]),
            "target_natural_exit_receipt": state.get("target_natural_exit_receipt"),
            "parent_wait_receipt": state.get("target_parent_wait_receipt"),
            "unchanged_table_returned": True,
        },
        "real_spi_absence_poll": state.get("pre_inner_absence_poll"),
        "sample4_source_binding": state.get("sample4_source_binding"),
        "failed_inner_source": {
            "receipt": failed_bundle.get("snapshot"),
            "root_present_target_absent": True,
        },
        "expected_tracked_subtree": [
            {"pid": pid, "create_time_100ns": ticks}
            for pid, ticks in sorted(subtree)],
        "exact_cached_generation_exits": [
            exact_exit_by_identity[identity] for identity in sorted(subtree)],
        "exact_cached_generation_exit": target_exit,
        "three_post_wait_absence_receipts": absences,
        "attempt_one_zero_credit": {
            "partial_rss_bytes_not_credited": record.get(
                "partial_rss_bytes_not_credited"),
            "rss_credit_bytes": record.get("rss_credit_bytes"),
            "cpu_credit_seconds": record.get("cpu_credit_seconds"),
            "exit_code_credit_issued": record.get("exit_code_credit_issued"),
        },
        "fresh_full_sample_attempt": {
            "started": record.get("retry_started"),
            "attempt_index": record.get("full_sample_attempt_index"),
            "completed": record.get("full_sample_completed_after_retry"),
            "native_query_count": len(query_receipts),
            "retry_source_absent_target": True,
        },
        "target_registry_open_calls": target_calls,
        "resource_reads": state.get("resource_reads", []),
        "target_handle_close_receipt": handle_close,
        "pre_tree_final_audit": r22_audit,
        "final_process_tree_audit": final_audit,
        "root_natural_exit_receipt": root_natural_exit,
        "formal_t2_accepted": False,
        "julia_started": False,
    }


def run(output: Path, controller_sha256: str, validator_sha256: str) -> int:
    if os.name != "nt":
        raise RuntimeError("R22 host smoke requires the pinned Windows process APIs")
    require(not output.exists(), f"R22 evidence output already exists: {output}")
    output.mkdir(parents=True, exist_ok=False)
    pins_before = source_pins()
    require(pins_before["controller"]["sha256"] == controller_sha256,
            "R22 controller changed from the reviewed SHA")
    require(pins_before["projection_validator"]["sha256"] == validator_sha256,
            "R12 projection validator changed from the reviewed SHA")
    module = None
    state: dict[str, Any] = {}
    phase: dict[str, Any] = {}
    payload: dict[str, Any] = {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2",
        "formal_t2_accepted": False, "julia_started": False,
        "phase_timeout_seconds": PHASE_TIMEOUT_SECONDS,
        "working_set_limit_bytes": WORKING_SET_LIMIT_BYTES,
        "source_pins_before": pins_before,
    }
    exit_code = 1
    phase_dir = output / "phase"
    try:
        module = load_controller(controller_sha256)
        hooks = install_hooks(module, phase_dir, state)
        command = [sys.executable, "-B", str(FIXTURE), "--role", "root",
                   "--phase-dir", str(phase_dir)]
        phase = module.run_phase(
            "r22_pre_tree_tracked_exit_natural_python_child_r2", command,
            phase_dir, timeout_seconds=PHASE_TIMEOUT_SECONDS,
            working_set_limit_bytes=WORKING_SET_LIMIT_BYTES,
            environment=os.environ.copy())
        hooks["restore"]()
        state["hooks_restored"] = True
        payload["phase"] = phase
        payload["race_debug"] = {
            key: value for key, value in state.items()
            if key not in {"restore", "originals", "target_registry_handle",
                           "outer_reconcile_snapshot", "completed_source_snapshots"}}
        payload["verified_race"] = verify_phase(module, phase, state, phase_dir)
        exit_code = 0
    except Exception as error:
        payload["assertion_failure"] = {
            "type": type(error).__name__, "message": str(error)}
        payload["phase"] = phase
        if state:
            payload["race_debug"] = {
                key: value for key, value in state.items()
                if key not in {"restore", "originals", "target_registry_handle",
                               "outer_reconcile_snapshot", "completed_source_snapshots"}}
        if module is not None and "hooks" in locals():
            hooks["restore"]()
    finally:
        if phase_dir.exists():
            for marker in (phase_dir / "target_release.json",
                           phase_dir / "root_release.json"):
                if not marker.exists():
                    write_json(marker, {"schema": "vnext-t2-r22-fixture-emergency-release-r1"})

    pins_after = source_pins()
    payload["source_pins_after"] = pins_after
    payload["source_pins_stable"] = pins_before == pins_after
    payload["formal_t2_accepted"] = False
    payload["julia_started"] = False
    if pins_before != pins_after:
        payload["assertion_failure"] = {
            "type": "RuntimeError",
            "message": "runner/controller/fixture/monitor source hashes changed during host smoke"}
        exit_code = 1
    raw_stdout = (json.dumps(payload, sort_keys=True) + "\n").encode("utf-8")
    (output / "stdout.raw").write_bytes(raw_stdout)
    (output / "stderr.raw").write_bytes(b"")
    write_json(output / "exit_code.json", {
        "exit_code": exit_code,
        "status": "pass_python_only" if exit_code == 0 else "fail",
        "formal_t2_accepted": False, "julia_started": False,
        "source_pins_before": pins_before, "source_pins_after": pins_after})
    write_json(output / "command_argv.json", {
        "kind": "python_only_r22_pre_tree_tracked_exit_host_smoke_r2",
        "argv": [sys.executable, "-B", str(RUNNER), *sys.argv[1:]],
        "cwd": str(Path.cwd()), "phase_command": command if "command" in locals() else None,
        "phase_timeout_seconds": PHASE_TIMEOUT_SECONDS,
        "working_set_limit_bytes": WORKING_SET_LIMIT_BYTES,
        "source_pins_before": pins_before, "source_pins_after": pins_after,
        "formal_t2_accepted": False, "julia_started": False})
    inventory = []
    for path in sorted(item for item in output.rglob("*") if item.is_file()):
        if path.name == "manifest.json":
            continue
        data = path.read_bytes()
        inventory.append({"path": path.relative_to(output).as_posix(),
                          "bytes": len(data),
                          "sha256": hashlib.sha256(data).hexdigest()})
    write_json(output / "manifest.json", {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-host-manifest-r2",
        "complete": exit_code == 0,
        "top_level_schema": payload["schema"],
        "files": inventory,
        "source_pins_before": pins_before,
        "source_pins_after": pins_after,
        "formal_t2_accepted": False,
        "julia_started": False})
    sys.stdout.buffer.write(raw_stdout)
    sys.stdout.buffer.flush()
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--controller-sha256", required=True)
    parser.add_argument("--validator-sha256", required=True)
    args = parser.parse_args()
    return run(args.output.resolve(), args.controller_sha256,
               args.validator_sha256)


if __name__ == "__main__":
    raise SystemExit(main())
