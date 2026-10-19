from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import math
import os
import subprocess
import sys
import tempfile
import types
from pathlib import Path
from typing import Any
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
R20_CONTROLLER = TEST_ROOT / "independent_negative_controller_r20.py"
R21_CONTROLLER = TEST_ROOT / "independent_negative_controller_r21.py"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r22.py"
R21_TRACKED_EXIT_TEST = TEST_ROOT / "test_r21_tracked_sample_exit_independent.py"
R21_TRACKED_EXIT_TEST_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/r21_tracked_sample_exit_python_controls_20260926_r2")
R22_PRE_TREE_TEST = TEST_ROOT / "test_r22_pre_tree_tracked_exit_independent.py"
R22_PRE_TREE_TEST_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_python_controls_20260926_r7")
R19_CONTROLLER = TEST_ROOT / "independent_negative_controller_r19.py"
R10_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r10.py"
R11_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r11.py"
R12_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r12.py"
PROJECTION_REUSE_VALIDATOR = R12_PROJECTION_REUSE_VALIDATOR
R23_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
R23_SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
R23_TEST_SUITE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r23_v1.py"
HOST_SMOKE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r20_native_monitor_host_smoke_20260926_r9")
HOST_SMOKE_RUNNER = TEST_ROOT / "r20_native_monitor_host_smoke_r9.py"
R22_HOST_SMOKE_RUNNER = TEST_ROOT / "r22_pre_tree_tracked_exit_host_smoke_r2.py"
R22_HOST_SMOKE_FIXTURE = TEST_ROOT / "r22_pre_tree_tracked_exit_host_fixture.py"
R22_HOST_SMOKE_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_20260926_r3")
R22_HOST_SMOKE_LAUNCHER_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_launcher_20260926_r3")
R22_HOST_SMOKE_INVOCATION_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_invocation_20260926_r3")
R22_HOST_SMOKE_LAUNCHER_SHA256 = (
    "2a44d7d9e4e75a6bc39a1e17fe99430b0cc983e5dc843a6f5ebf5c159c75ef9f")
R22_HOST_SMOKE_QA_SNAPSHOT = R22_HOST_SMOKE_LAUNCHER_LEAF / \
    "pre_host_static_qa_r22.py"
R22_HOST_SMOKE_QA_SNAPSHOT_BYTES = 168149
R22_HOST_SMOKE_QA_SNAPSHOT_SHA256 = \
    "7d381e1b1a229adf98e795cb786b9d56c69ece4632faf4918a1790b5175a82bf"
HOST_SMOKE_CONTROLLER_SOURCE = ROOT / (
    "runs/UP1-04A-VNEXT-T2/source_snapshots/"
    "controller_r20_pre_runs_path_gate_c1607.py")
HOST_SMOKE_FAILURE_LEAVES = {
    f"r{index}": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        f"r20_native_monitor_host_smoke_20260926_r{index}")
    for index in range(1, 9)
}
HOST_SMOKE_FAILURE_EXPECTATIONS = {
    "r1": (19, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "controlled descendant did not exit before the real registry OpenProcess"),
    "r2": (23, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "R20 recovery lost the exact PID/raw FILETIME from the before-SPI row"),
    "r3": (21, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "controlled descendant did not exit before real OpenProcess/liveness binding"),
    "r4": (24, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "R20 did not discard all partial first-attempt metrics before a fresh full retry"),
    "r5": (31, "vnext-t2-r20-native-monitor-host-smoke-r5",
           "R20 did not discard all partial first-attempt metrics before a fresh full retry"),
    "r6": (52, "vnext-t2-r20-native-monitor-host-smoke-r6",
           "failed-open orphan cleanup was reported as complete or left a root descendant"),
    "r7": (104, "vnext-t2-r20-native-monitor-host-smoke-r7",
           "orphan control did not remain an incomplete non-retry failed-open sample"),
    "r8": (39, "vnext-t2-r20-native-monitor-host-smoke-r8",
           "R20 race phase did not retain exactly one source-row recovery receipt"),
}
RETRY8_PROTOCOL = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry8/"
    "protocol.json")
PLANNING_REFRESH = ROOT / (
    "docs/v4_multitopology_generation/planning_refresh_20260926.json")
PLANNING_VALIDATION = ROOT / (
    "docs/v4_multitopology_generation/planning_validation_20260926.json")
PLANNING_MIGRATION_INPUTS = {
    "docs/v4_multitopology_generation/16_execution_work_orders.md":
        "16_execution_work_orders.md",
    "docs/v4_multitopology_generation/21_next_execution_batches.md":
        "21_next_execution_batches.md",
    "docs/v4_multitopology_generation/22_agent_local_execution.md":
        "22_agent_local_execution.md",
    "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md":
        "25_astra_execution_and_recovery.md",
    "docs/v4_multitopology_generation/README.md": "README.md",
    "docs/v4_multitopology_generation/task_manifest.json":
        "task_manifest.json",
}
PLANNING_REFRESH_SHA256 = (
    "582312eeb33e863f4996c6dd322c26388155b275a03238d21d5939359d57080a")
PLANNING_VALIDATION_SHA256 = (
    "a6241b8c763e1d4ce47f055c9bbbc301ec147a66e1fed6645503fb423093551d")
PLANNING_RETAINED_CONTRACT_SHA256 = (
    "550716a845f5986e4fa873a099c406c9f3e69c38f640f7c6a58452e0b1a5db3c")
R17_BASELINE_GATE_FAILURE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r17_r23_r8")
R17_BASELINE_GATE_FAILURE_FILES = {
    "pipeline_start": R17_BASELINE_GATE_FAILURE / "pipeline_start.json",
    "pipeline_final": R17_BASELINE_GATE_FAILURE / "pipeline_final.json",
}
R18_SUPERSEDED_MAP_EXPERIMENT_FILES = (
    TEST_ROOT / "build_coverage_map_r18.py",
    TEST_ROOT / "coverage_map_r17.json",
)
R18_RETRY1_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r18_baseline_audit_retry1")
R19_RETRY1_PROJECTION_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry1")
R19_RETRY2_STATIC_QA_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry2")
R18_FREEZE_RETRY2_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r18_baseline_audit_retry2")
R18_PREDICATE_TESTER_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_t2_r18_audit_predicate_tester_20260925")
R18_REVIEW_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt11_r18_prelaunch_review_20260925_r1")
R18_PREDICATE_TESTER_SOURCE = ROOT / (
    "test/GenomeV5/Integration/VNextT2AuditIndependentR18/"
    "test_r18_audit_predicate.py")
HOST_SMOKE_RETRY_LEAVES = {
    "r5": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r17_native_monitor_host_smoke_20260925_r5"),
    "r6": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r17_native_monitor_host_smoke_20260925_r6"),
}
ATTEMPT7_MAP = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, Any]:
    path = path.resolve()
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(),
            "bytes": len(data), "sha256": sha(data)}


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def reject(name: str, action: Any, controls: list[dict[str, str]]) -> None:
    try:
        action()
    except Exception as error:
        controls.append({"name": name, "status": "pass",
                         "rejected_as": type(error).__name__})
        return
    raise RuntimeError(f"negative control unexpectedly accepted: {name}")


def load_source_module(name: str, path: Path, expected: dict[str, Any]) -> Any:
    actual = receipt(path)
    require(actual == expected, f"source pin drift before compile/exec: {path}")
    module = types.ModuleType(name)
    module.__file__ = str(path.resolve())
    source = path.read_bytes()
    exec(compile(source, str(path.resolve()), "exec"), module.__dict__)
    return module


def check_current_inputs(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    pins = protocol.get("inputs")
    require(isinstance(pins, dict) and len(pins) >= 459,
            "current input closure is missing or below the frozen 459-pin floor")
    actual_rows = []
    for relative, expected in sorted(pins.items()):
        path = (ROOT / relative).resolve()
        path.relative_to(ROOT)
        actual = receipt(path)
        require(expected == actual, f"current input path/bytes/SHA drift: {relative}")
        actual_rows.append(actual)
    require(protocol.get("input_count") == len(pins),
            "protocol input_count differs from exact current pins")
    required = {
        R21_CONTROLLER.relative_to(ROOT).as_posix(),
        CONTROLLER.relative_to(ROOT).as_posix(),
        R22_PRE_TREE_TEST.relative_to(ROOT).as_posix(),
        R22_HOST_SMOKE_RUNNER.relative_to(ROOT).as_posix(),
        R22_HOST_SMOKE_QA_SNAPSHOT.relative_to(ROOT).as_posix(),
        R22_HOST_SMOKE_FIXTURE.relative_to(ROOT).as_posix(),
        PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        R23_TABLE.relative_to(ROOT).as_posix(),
        R23_SUPERVISOR.relative_to(ROOT).as_posix(),
        HOST_SMOKE_CONTROLLER_SOURCE.relative_to(ROOT).as_posix(),
        HOST_SMOKE_RUNNER.relative_to(ROOT).as_posix(),
    }
    require(required.issubset(pins),
            "controller/R23 monitor source is missing from the input closure")
    return actual_rows


def verify_authorized_planning_migration(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt11_retry8_windows_pid0_failure_basis", {})
    migration = basis.get("authorized_planning_migration")
    old_protocol = load(RETRY8_PROTOCOL)
    old_inputs = old_protocol.get("inputs")
    require(old_protocol.get("schema") ==
            "vnext-t2-independent-negative-protocol-r6" and
            old_protocol.get("input_count") == 459 and
            isinstance(old_inputs, dict) and len(old_inputs) == 459,
            "historical R8 protocol input pins are malformed")
    require(isinstance(migration, dict) and
            migration.get("schema") ==
                "v4-planning-refresh-r20-historical-input-bridge-r1" and
            migration.get("status") ==
                "authorized_planning_migration_historical_bytes_not_current" and
            migration.get("historical_r8_protocol_and_pins_preserved") is True and
            migration.get("historical_bytes_are_current") is False and
            migration.get("historical_input_count") == 459 and
            migration.get("unchanged_historical_pin_count") == 453 and
            migration.get("migrated_input_count") == 6,
            "R8 historical bytes were represented as current or migration scope drifted")

    refresh = load(PLANNING_REFRESH)
    validation = load(PLANNING_VALIDATION)
    refresh_receipt = receipt(PLANNING_REFRESH)
    validation_receipt = receipt(PLANNING_VALIDATION)
    require(refresh_receipt["sha256"] == PLANNING_REFRESH_SHA256 and
            validation_receipt["sha256"] == PLANNING_VALIDATION_SHA256 and
            inputs.get(refresh_receipt["path"]) == refresh_receipt and
            inputs.get(validation_receipt["path"]) == validation_receipt and
            migration.get("planning_refresh_receipt") == refresh_receipt and
            migration.get("planning_validation_receipt") == validation_receipt,
            "planning refresh/validation receipts are not pinned in the current closure")
    require(refresh.get("schema") == "planning-refresh-20260926-v1" and
            refresh.get("record_kind") ==
                "planning_change_not_runtime_or_scientific_acceptance" and
            refresh.get("base_head") == "63792ca22958ffca8c3fa8e642256eb9f7240724" and
            refresh.get("existing_task_count") == 46 and
            refresh.get("accepted_limited_count") == 21 and
            refresh.get("open_task_count") == 25 and
            refresh.get("goal_achieved") is False and
            refresh.get("credible_candidate_count") == 0,
            "planning refresh record status/task totals drifted")
    before = refresh.get("before_sha256")
    migrated = migration.get("migrated_inputs")
    require(isinstance(before, dict) and isinstance(migrated, dict) and
            set(migrated) == set(PLANNING_MIGRATION_INPUTS),
            "planning migration does not name the exact six authorized inputs")
    unchanged_count = 0
    for relative, old_pin in sorted(old_inputs.items()):
        current_pin = inputs.get(relative)
        require(isinstance(current_pin, dict),
                f"historical input is missing from current closure: {relative}")
        if relative in PLANNING_MIGRATION_INPUTS:
            refresh_name = PLANNING_MIGRATION_INPUTS[relative]
            row = migrated.get(relative)
            require(isinstance(row, dict) and
                    old_pin.get("path") == relative and
                    old_pin.get("sha256") == before.get(refresh_name) and
                    row.get("historical_r8_pin") == old_pin and
                    row.get("planning_refresh_before_sha256") ==
                        before.get(refresh_name) and
                    row.get("current_r20_input") == current_pin and
                    row.get("historical_bytes_are_current") is False and
                    current_pin != old_pin,
                    f"authorized historical-to-current bridge mismatch: {relative}")
        else:
            require(current_pin == old_pin,
                    f"unapproved historical input drift: {relative}")
            unchanged_count += 1
    require(unchanged_count == 453,
            "R8 unchanged historical pin count is not exactly 453")

    manifest_path = ROOT / "docs/v4_multitopology_generation/task_manifest.json"
    manifest = load(manifest_path)
    keys = refresh.get("retained_contract_keys")
    tasks = manifest.get("tasks")
    require(isinstance(keys, list) and isinstance(tasks, list) and len(tasks) == 46,
            "planning task contract is malformed")
    retained = {item["id"]: {key: item[key] for key in keys if key in item}
                for item in tasks}
    retained_hash = sha(json.dumps(
        retained, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8"))
    result = migration.get("planning_validation_result")
    require(retained_hash == PLANNING_RETAINED_CONTRACT_SHA256 and
            refresh.get("retained_contract_sha256") == retained_hash and
            isinstance(result, dict) and
            validation.get("record_kind") ==
                "planning_document_validation_not_physics_or_implementation_acceptance" and
            validation.get("checks") == "pass" and
            validation.get("task_count") == 46 and
            validation.get("task_dag_acyclic") is True and
            validation.get("retained_acceptance_items") == 124 and
            validation.get("retained_task_contract_sha256") == retained_hash and
            validation.get("runtime_inputs_require_exact_restore_and_fresh_freeze") is True and
            validation.get("errors") == [] and
            result.get("checks") == validation.get("checks") and
            result.get("retained_task_contract_sha256") == retained_hash and
            result.get("retained_acceptance_items") == 124,
            "planning validation result or retained acceptance contract drifted")
    return {
        "historical_input_count": 459,
        "unchanged_historical_pin_count": unchanged_count,
        "authorized_migrated_input_count": len(migrated),
        "historical_bytes_are_current": False,
        "planning_refresh": refresh_receipt,
        "planning_validation": validation_receipt,
        "retained_contract_sha256": retained_hash,
        "retained_acceptance_items": 124,
        "validation_status": "pass",
    }


def check_map_schema(value: dict[str, Any]) -> None:
    require(value.get("schema") ==
            "vnext-t2-independent-negative-coverage-map-r16",
            "coverage map schema mismatch")


def verify_r20_controller_sample_delta(protocol: dict[str, Any],
                                      controller_source: str,
                                      controller_pin: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r19_r20_process_sample_delta")
    r19_source = receipt(R19_CONTROLLER)
    expected_changes = [
        "_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race",
        "_r20_descendants_from_pid_set",
        "_r20_native_sample",
        "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows",
        "_r20_valid_snapshot_receipt",
        "_r23_audit_and_cleanup",
        "_r23_final_audit",
        "_r23_native_sample",
        "main",
        "require_t2_execution_leaf",
        "run_phase",
        "verify_authority_resume_ancestry",
    ]
    require(isinstance(delta, dict) and
            delta.get("schema") ==
                "vnext-t2-r19-r20-process-sample-race-delta-r1" and
            delta.get("r19_source") == r19_source and
            delta.get("r20_source") == controller_pin and
            delta.get("changed_top_level_functions") == expected_changes and
            delta.get("before_snapshot_handle_binding") is True and
            delta.get("post_open_failure_fresh_snapshot_count") == 3 and
            delta.get("requires_target_subtree_and_orphans_absent") is True and
            delta.get("requires_exact_root_and_previous_generations") is True and
            delta.get("whole_sample_retry_cap") == 2 and
            delta.get("failed_attempt_metric_credit_bytes") == 0 and
            delta.get("failed_attempt_exit_credit") is False and
            delta.get("coverage_thresholds_changed") is False and
            delta.get("resource_limits_changed") is False,
            "R19-to-R20 process-sample delta receipt is missing or changes the frozen contract")

    previous_functions = {
        node.name: ast.dump(node, include_attributes=False)
        for node in ast.parse(R19_CONTROLLER.read_text(encoding="utf-8")).body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    current_tree = ast.parse(controller_source)
    current_functions = {
        node.name: ast.dump(node, include_attributes=False)
        for node in current_tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    observed_changes = sorted(
        name for name in previous_functions.keys() | current_functions.keys()
        if previous_functions.get(name) != current_functions.get(name))
    require(observed_changes == expected_changes,
            "R20 process-sample source diff exceeds its versioned function delta")

    sample = next((node for node in current_tree.body
                   if isinstance(node, ast.FunctionDef) and
                   node.name == "_r20_native_sample"), None)
    nested_functions = {
        node.name: node for node in ast.walk(sample)
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
    } if sample else {}
    handle_provider = nested_functions.get("handle_provider")
    snapshot_provider = nested_functions.get("snapshot_provider")
    recovery_helper = nested_functions.get("record_unbound_sample_race")
    resource_reader = nested_functions.get("sample_resource_reader")
    require(sample is not None and handle_provider is not None and
            snapshot_provider is not None and recovery_helper is not None and
            resource_reader is not None,
            "R20 sample lacks source-snapshot, exact-row, race-recovery, or resource callbacks")

    def call_is_registry_bind(node: ast.AST) -> bool:
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and
                node.func.attr == "for_row" and len(node.args) >= 2 and
                isinstance(node.func.value, ast.Name) and
                node.func.value.id == "registry" and
                isinstance(node.args[0], ast.Name) and node.args[0].id == "row" and
                isinstance(node.args[1], ast.Name) and node.args[1].id == "source")

    def call_is_fresh_spi_query(node: ast.AST) -> bool:
        return (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and
                node.func.attr == "query_native_process_table")

    def direct_calls(node: ast.AST, name: str) -> list[ast.Call]:
        return [child for child in ast.walk(node)
                if isinstance(child, ast.Call) and isinstance(child.func, ast.Name) and
                child.func.id == name]

    bind_nodes = [node for node in ast.walk(handle_provider)
                  if call_is_registry_bind(node)]
    open_try = next((node for node in handle_provider.body
                     if isinstance(node, ast.Try) and
                     any(call_is_registry_bind(child) for child in ast.walk(node))), None)
    open_recovery = [node for handler in open_try.handlers for statement in handler.body
                     for node in direct_calls(statement, "record_unbound_sample_race")]
    source_snapshot_queries = [node for node in ast.walk(snapshot_provider)
                               if call_is_fresh_spi_query(node)]
    recovery_queries = [node for node in ast.walk(recovery_helper)
                        if call_is_fresh_spi_query(node)]
    recovery_loop = next((node for node in ast.walk(recovery_helper)
                          if isinstance(node, ast.For) and
                          isinstance(node.iter, ast.Call) and
                          isinstance(node.iter.func, ast.Name) and
                          node.iter.func.id == "range" and len(node.iter.args) == 1 and
                          isinstance(node.iter.args[0], ast.Constant) and
                          node.iter.args[0].value == 3), None)
    helper_queries_in_loop = [node for statement in recovery_loop.body
                              for node in ast.walk(statement)
                              if call_is_fresh_spi_query(node)] if recovery_loop else []
    recovery_calls = [node for node in ast.walk(sample)
                      if isinstance(node, ast.Call) and
                      isinstance(node.func, ast.Name) and
                      node.func.id == "record_unbound_sample_race"]
    owner_by_call: dict[int, str] = {}
    for name, function in nested_functions.items():
        if function is sample:
            continue
        for call in direct_calls(function, "record_unbound_sample_race"):
            owner_by_call[id(call)] = name
    top_level_calls = [node for node in direct_calls(sample,
                                                      "record_unbound_sample_race")
                       if id(node) not in owner_by_call]
    owner_counts = {name: sum(owner == name for owner in owner_by_call.values())
                    for name in ("handle_provider", "sample_resource_reader")}

    def assigned_dict_value(function: ast.AST, key: str, expected: Any) -> bool:
        for node in ast.walk(function):
            if not isinstance(node, ast.Assign):
                continue
            target = node.targets[0] if node.targets else None
            if (isinstance(target, ast.Subscript) and
                    isinstance(target.value, ast.Name) and
                    target.value.id == "recovery" and
                    isinstance(target.slice, ast.Constant) and
                    target.slice.value == key and
                    isinstance(node.value, ast.Constant) and
                    node.value.value == expected):
                return True
        return False

    source_first_snapshot = any(
        isinstance(node, ast.Assign) and
        any(isinstance(target, ast.Subscript) and
            isinstance(target.value, ast.Name) and target.value.id == "attempt_state" and
            isinstance(target.slice, ast.Constant) and
            target.slice.value == "first_snapshot"
            for target in node.targets) and
        isinstance(node.value, ast.Name) and node.value.id == "snapshot"
        for node in ast.walk(snapshot_provider))
    helper_source_guard = any(
        isinstance(node, ast.If) and
        any(isinstance(child, ast.Compare) and
            isinstance(child.left, ast.Name) and child.left.id == "source" and
            any(isinstance(op, ast.Is) for op in child.ops) and
            any(isinstance(comp, ast.Constant) and comp.value is None
                for comp in child.comparators)
            for child in ast.walk(node.test))
        for node in ast.walk(recovery_helper))
    require(len(bind_nodes) == 1 and open_try is not None and
            source_first_snapshot and len(source_snapshot_queries) == 1 and
            not any(call_is_fresh_spi_query(node) for node in ast.walk(handle_provider)) and
            len(recovery_queries) == 1 and recovery_loop is not None and
            helper_queries_in_loop == recovery_queries and
            len(recovery_calls) == 3 and owner_counts == {
                "handle_provider": 1, "sample_resource_reader": 1} and
            len(top_level_calls) == 1 and helper_source_guard and
            all(assigned_dict_value(recovery_helper, key, value) for key, value in (
                ("exact_handle_exit_receipt_created", False),
                ("exit_code_credit_issued", False),
                ("rss_credit_bytes", 0))) and
            open_recovery and
            not any(call_is_fresh_spi_query(node) for node in ast.walk(open_try)),
            "R20 source binding or nested three-query failure recovery path changed")

    # Resource-reader exits and incomplete post-sample exits are distinct
    # failure sites; both must invoke the same exact three-snapshot helper.
    post_sample_recovery = top_level_calls[0]
    post_sample_guard = any(
        isinstance(node, ast.If) and any(
            isinstance(child, ast.Name) and child.id == "signaled_after_sample"
            for child in ast.walk(node.test)) and
        any(child is post_sample_recovery for statement in node.body
            for child in ast.walk(statement))
        for node in ast.walk(sample))
    resource_recovery = direct_calls(resource_reader, "record_unbound_sample_race")
    require(post_sample_guard and len(resource_recovery) == 1,
            "R20 liveness/resource/post-sample failures do not all route through race recovery")
    return {"status": "pass", "changed_functions": observed_changes,
            "before_snapshot_binding": True,
            "post_open_failure_fresh_snapshot_count": 3,
            "coverage_thresholds_changed": False,
            "resource_limits_changed": False}


def verify_r20_host_smoke(protocol: dict[str, Any],
                         inputs: dict[str, Any]) -> dict[str, Any]:
    host = protocol.get("r20_native_monitor_host_smoke")
    require(isinstance(host, dict) and
            host.get("schema") == "vnext-t2-r20-native-monitor-host-smoke-r9" and
            host.get("status") == "pass_python_only" and host.get("exit_code") == 0 and
            host.get("leaf") == HOST_SMOKE.relative_to(ROOT).as_posix() and
            host.get("file_count") == 63 and
            host.get("julia_started") is False and
            host.get("formal_t2_accepted") is False and
            host.get("independent_review") == {
                "status": "GO",
                "scope": "R9 host smoke as a freezer input only",
                "basis": "root-confirmed independent raw R9 review",
                "formal_t2_execution_authorized": False,
                "review_artifact_pinned_in_repository": False,
            },
            "R9 raw host-smoke success receipt is absent or overclaims T2")
    rows = host.get("files")
    actual_paths = {path.relative_to(HOST_SMOKE).as_posix()
                    for path in HOST_SMOKE.rglob("*") if path.is_file()}
    require(isinstance(rows, dict) and len(rows) == 63 and
            set(rows) == actual_paths,
            "R9 recursive host-smoke file inventory is not exact")
    for name, expected in rows.items():
        path = HOST_SMOKE / name
        require(receipt(path) == expected and inputs.get(expected["path"]) == expected,
                f"R9 host-smoke member receipt drift: {name}")

    raw_controller = receipt(HOST_SMOKE_CONTROLLER_SOURCE)
    current_controller = inputs.get(R20_CONTROLLER.relative_to(ROOT).as_posix())
    require(host.get("raw_controller_source") == raw_controller and
            host.get("controller_source_snapshot") == raw_controller and
            inputs.get(raw_controller["path"]) == raw_controller and
            host.get("current_controller") == current_controller and
            host.get("runner") == inputs.get(HOST_SMOKE_RUNNER.relative_to(ROOT).as_posix()) and
            host.get("native_process_table") ==
                inputs.get(R23_TABLE.relative_to(ROOT).as_posix()) and
            host.get("supervisor") ==
                inputs.get(R23_SUPERVISOR.relative_to(ROOT).as_posix()) and
            host.get("test_suite_source") ==
                inputs.get(R23_TEST_SUITE.relative_to(ROOT).as_posix()),
            "R9 raw controller witness or helper source pins are not in the closure")
    require(raw_controller["sha256"] ==
            "c1607fc4508356366e9eee350582dd9df2248b3b89022ce4ea43928d1148d9b4" and
            host.get("source_pins_stable") is True and
            host.get("source_pins_before") == host.get("source_pins_after"),
            "R9 did not pin one stable pre-path-gate controller source")

    command = load(HOST_SMOKE / "command_argv.json")
    result = load(HOST_SMOKE / "exit_code.json")
    argv = command.get("argv")
    require(command.get("kind") == "python_only_host_supervisor_smoke" and
            command.get("julia_started") is False and
            command.get("formal_t2_accepted") is False and
            command.get("controller_sha256") == raw_controller["sha256"] and
            isinstance(argv, list) and len(argv) == 4 and argv[1] == "-B" and
            Path(argv[2]).resolve() == HOST_SMOKE_RUNNER.resolve() and
            argv[3] == HOST_SMOKE.relative_to(ROOT).as_posix() and
            Path(command.get("cwd", "")).resolve() == ROOT and
            result.get("exit_code") == 0 and
            result.get("status") == host.get("status") and
            result.get("julia_started") is False and
            result.get("formal_t2_accepted") is False and
            host.get("command") == receipt(HOST_SMOKE / "command_argv.json") and
            host.get("stdout") == receipt(HOST_SMOKE / "stdout.raw") and
            host.get("stderr") == receipt(HOST_SMOKE / "stderr.raw") and
            host.get("exit") == receipt(HOST_SMOKE / "exit_code.json"),
            "R9 raw argv/exit receipt does not derive the bounded Python pass")
    payload = json.loads((HOST_SMOKE / "stdout.raw").read_text(encoding="utf-8"))
    require(payload.get("schema") == host.get("schema") and
            payload.get("source_pins_stable") is True and
            payload.get("source_pins_before") == host.get("source_pins_before") and
            payload.get("source_pins_after") == host.get("source_pins_after") and
            payload.get("julia_started") is False and
            payload.get("formal_t2_accepted") is False,
            "R9 stdout differs from the raw source-pin and claim-ceiling receipt")

    preprobe = payload.get("openprocess_race_preprobe")
    require(isinstance(preprobe, dict) and
            preprobe.get("schema") == "vnext-t2-r20-openprocess-exit-race-preprobe-r1" and
            preprobe.get("complete") is True and
            preprobe.get("child_wait_exit_code") == 15 and
            preprobe.get("parent_popen_handle_closed") is True and
            preprobe.get("final_pid_absent_from_spi") is True and
            preprobe.get("post_exit_pid_absent_from_spi") is True and
            preprobe.get("openprocess_result", {}).get("outcome") ==
                "openprocess_failed_after_spi_absence" and
            len(preprobe.get("post_exit_absence_snapshots", [])) == 1 and
            all(snapshot.get("complete") is True
                for snapshot in preprobe.get("post_exit_absence_snapshots", [])),
            "R9 did not retain the real post-exit OpenProcess race preprobe")

    race_fixture = payload.get("terminal_race_fixture")
    require(isinstance(race_fixture, dict) and
            race_fixture.get("schema") ==
                "vnext-t2-r20-terminal-race-scheduling-fixture-r1" and
            race_fixture.get("second_sample_hook_entered") is True and
            race_fixture.get("child_wait_natural_exit_code") == 0 and
            race_fixture.get("original_native_sampler_called_after_wait") is True and
            race_fixture.get("sampler_replaced_only_for_natural_phase") is True,
            "R9 deterministic terminal-race scheduling fixture is incomplete")
    phases = (payload.get("natural_phase"), payload.get("timeout_phase"))
    require(all(isinstance(phase, dict) for phase in phases),
            "R9 host-smoke phase observations are missing")
    natural, timed = phases
    require(natural.get("stop_reason") == "natural_exit" and
            natural.get("exit_code") == 0 and
            natural.get("process_tree_samples_complete") is True and
            natural.get("final_process_tree_audit", {}).get("complete") is True and
            natural.get("final_process_tree_audit", {}).get("root_exit_confirmed") is True and
            natural.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [] and
            isinstance(natural.get("terminal_sample_race"), dict) and
            natural["terminal_sample_race"].get(
                "exact_root_handle_wait_confirmed") is True,
            "R9 natural child lacks exact terminal-exit-race evidence")
    termination = timed.get("termination_receipt")
    require(timed.get("stop_reason") == "phase_wall_timeout" and
            timed.get("exit_code") == 15 and isinstance(termination, dict) and
            termination.get("verified") is True and
            timed.get("final_process_tree_audit", {}).get("complete") is True and
            timed.get("final_process_tree_audit", {}).get("root_exit_confirmed") is True and
            timed.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [] and
            timed.get("residual_heavy_processes") == [],
            "R9 timed child was not exactly terminated and audited")
    for phase in phases:
        monitor = phase.get("monitor_source_pins", {})
        close_receipt = phase.get("handle_close_receipt")
        require(monitor.get("native_process_table", {}).get("sha256") ==
                host["native_process_table"]["sha256"] and
                monitor.get("supervisor", {}).get("sha256") ==
                host["supervisor"]["sha256"] and
                monitor.get("load_mode") == "hash-pinned compile-exec; no pyc read/write",
                "R9 phase did not execute the hash-pinned native monitor sources")
        require(isinstance(close_receipt, dict) and
                close_receipt.get("schema") ==
                    "native-g1g2-r23-handle-close-receipt-v1" and
                close_receipt.get("complete") is True and
                close_receipt.get("errors") == [] and
                isinstance(close_receipt.get("closed_owned_handles"), list) and
                close_receipt.get("popen_handle_close_policy") ==
                    "retained_until_phase_return_then_closed_by_Popen_handle_owner",
                "R9 phase lacks a complete owned-handle cleanup receipt")

    race = payload.get("source_snapshot_handle_race")
    source_identity = race.get("source_row", {}) if isinstance(race, dict) else {}
    identity_pair = [source_identity.get("pid"),
                     source_identity.get("create_time_100ns")]
    absence_snapshots = (race or {}).get("post_open_failure_absence_snapshots", [])
    race_phase = (race or {}).get("phase", {})
    recoveries = race_phase.get("sample_handoff_recoveries", [])
    recovery = recoveries[0] if len(recoveries) == 1 else {}
    require(isinstance(race, dict) and
            race.get("attempt_count") == 2 and
            race.get("retry_sample_index") == 2 and
            race.get("registry_open_succeeded") is True and
            race.get("post_open_handle_wait_signaled") is True and
            race.get("exact_keeper_handle_closed_before_absence_queries") is True and
            race.get("post_open_failure_snapshot_count") == 3 and
            len(absence_snapshots) == 3 and
            all(snapshot.get("complete") is True for snapshot in absence_snapshots) and
            race.get("discarded_partial_rss_bytes") == 29_790_208 and
            race.get("discarded_rss_credit_bytes") == 0 and
            race.get("discarded_cpu_credit_seconds") == {"system": 0.0, "user": 0.0} and
            race.get("keeper_handle_identity") == identity_pair and
            race.get("registry_handle_identity") == identity_pair and
            recovery.get("status") == "recovered_by_new_complete_whole_sample" and
            recovery.get("full_sample_attempt_index") == 2 and
            recovery.get("retry_started") is True and
            race_phase.get("sample_handoff_recovery_count") == 1 and
            race_phase.get("stop_reason") == "natural_exit" and
            race_phase.get("exit_code") == 0 and
            race_phase.get("final_process_tree_audit", {}).get("complete") is True and
            race_phase.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [] and
            race.get("final_no_residual_audit") is True,
            "R9 source-snapshot-to-handle race receipt failed its identity, retry, or cleanup gates")

    orphan = payload.get("unbound_orphan_cleanup")
    orphan_phase = (orphan or {}).get("phase", {})
    final_unbound = orphan_phase.get("unbound_observation_final_audit", {})
    termination = orphan_phase.get("termination_receipt", {})
    unbound_cleanup = termination.get("unbound_cleanup", {})
    cleanup_plan = unbound_cleanup.get("plan", {})
    post_cleanup = (orphan or {}).get("post_cleanup_confirmation", {})
    generations = orphan_phase.get("unbound_observed_generations", [])
    signal_attempts = unbound_cleanup.get("signal_attempts", [])
    checks = post_cleanup.get("target_generation_checks", [])
    expected_generations = {(row.get("pid"), row.get("create_time_100ns"))
                            for row in generations}
    cleaned_generations = {(row.get("identity", {}).get("pid"),
                            row.get("identity", {}).get("create_time_100ns"))
                           for row in signal_attempts}
    require(isinstance(orphan, dict) and
            orphan.get("schema") == "vnext-t2-r20-unbound-open-denial-cleanup-r9" and
            orphan.get("phase_stop_reason") == "process_tree_monitor_incomplete" and
            orphan.get("phase_exit_code") == 15 and
            orphan.get("sample_retry") is False and
            orphan.get("termination_complete") is False and
            len(generations) == 4 and len(signal_attempts) == 4 and
            expected_generations == cleaned_generations and
            final_unbound.get("complete") is False and
            final_unbound.get("observed_generation_count") == 4 and
            final_unbound.get("errors") == [{
                "exception_type": "RuntimeError",
                "message": "unbound observation record 0 is incomplete or malformed",
                "pid": None,
                "stage": "r20_unbound_observation_final_audit",
            }] and
            cleanup_plan.get("complete") is True and
            cleanup_plan.get("unresolved") == [] and
            unbound_cleanup.get("complete") is True and
            all(row.get("receipt", {}).get("signal_sent") is True and
                row.get("receipt", {}).get("wait_confirmed") is True and
                row.get("receipt", {}).get("complete") is True
                for row in signal_attempts) and
            post_cleanup.get("complete") is True and
            post_cleanup.get("target_process_ids_absent") is True and
            len(checks) == 4 and all(row.get("pid_absent") is True
                                     for row in checks) and
            post_cleanup.get("errors") == [] and
            orphan_phase.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [],
            "R9 open-denied orphan cleanup did not preserve fail-closed status and exact cleanup evidence")
    return {
        "status": "pass",
        "raw_status_derived_from_exit_receipt": True,
        "r9_controller_scope": "C1607 pre-path-gate controller only",
        "recursive_file_count": len(rows),
        "natural_and_timeout_phases_complete": True,
        "openprocess_preprobe_complete": True,
        "source_snapshot_to_handle_race_recovered": True,
        "partial_first_attempt_metrics_credited": False,
        "unbound_orphan_cleanup_complete_with_expected_fail_closed_audit": True,
        "formal_t2_accepted": False,
    }


def verify_r20_host_smoke_failure_lineage(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    lineage = protocol.get("r20_native_monitor_host_smoke_failure_lineage")
    require(isinstance(lineage, dict) and lineage.get("attempt_count") == 8 and
            set(lineage.get("attempts", {})) == set(HOST_SMOKE_FAILURE_LEAVES) and
            lineage.get("failure_evidence_overwritten") is False and
            lineage.get("julia_started") is False and
            lineage.get("formal_t2_accepted") is False,
            "R1-R8 R20 host-smoke failure lineage is incomplete")
    for label, leaf in HOST_SMOKE_FAILURE_LEAVES.items():
        attempt = lineage["attempts"][label]
        expected_count, expected_schema, expected_message = \
            HOST_SMOKE_FAILURE_EXPECTATIONS[label]
        actual_paths = {path.relative_to(leaf).as_posix()
                        for path in leaf.rglob("*") if path.is_file()}
        rows = attempt.get("file_receipts")
        require(attempt.get("leaf") == leaf.relative_to(ROOT).as_posix() and
                attempt.get("file_count") == expected_count and
                attempt.get("exit_code") == 1 and attempt.get("status") == "fail" and
                attempt.get("stdout_schema") == expected_schema and
                attempt.get("failure_message") == expected_message and
                attempt.get("julia_started") is False and
                attempt.get("formal_t2_accepted") is False and
                isinstance(rows, dict) and len(rows) == expected_count and
                set(rows) == actual_paths,
                f"R20 host-smoke {label} failure member list/class changed")
        for name, expected in rows.items():
            path = leaf / name
            require(receipt(path) == expected and inputs.get(expected["path"]) == expected,
                    f"R20 host-smoke {label} failure pin drift: {name}")
        command = load(leaf / "command_argv.json")
        result = load(leaf / "exit_code.json")
        stdout = load(leaf / "stdout.raw")
        require(command.get("kind") == "python_only_host_supervisor_smoke" and
                command.get("julia_started") is False and
                command.get("formal_t2_accepted") is False and
                result.get("exit_code") == 1 and result.get("status") == "fail" and
                result.get("julia_started") is False and
                result.get("formal_t2_accepted") is False and
                stdout.get("schema") == expected_schema and
                stdout.get("smoke_assertion", {}).get("message") == expected_message,
                f"R20 host-smoke {label} no longer preserves its exact Python-only failure")
    return {"status": "pass", "attempt_count": 8,
            "failure_evidence_overwritten": False,
            "julia_started": False, "formal_t2_accepted": False}


def verify_r20_runs_only_path_gate(
        protocol: dict[str, Any], inputs: dict[str, Any], controller: Any,
        controller_source: str, controller_pin: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r20_runs_only_path_gate_delta")
    before_receipt = receipt(HOST_SMOKE_CONTROLLER_SOURCE)
    path_policy = protocol.get("execution_evidence_path_policy", {})
    expected_changes = ["main", "require_t2_execution_leaf",
                        "verify_authority_resume_ancestry"]
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-r20-runs-only-path-gate-delta-r1" and
            delta.get("pre_gate_controller") == before_receipt and
            delta.get("current_controller") == controller_pin and
            delta.get("changed_top_level_functions") == expected_changes and
            delta.get("required_direct_child_root") ==
                "runs/UP1-04A-VNEXT-T2" and
            delta.get("path_gate_call_sites") ==
                ["output", "resume_authority_from", "resume_root"] and
            delta.get("normalized_source_equal_after_removing_path_gate") is True and
            delta.get("sampling_pid_identity_cleanup_logic_changed") is False and
            delta.get("resource_and_coverage_gates_changed") is False and
            delta.get("independent_review") == {
                "status": "GO",
                "scope": "current runs-only output/resume path gate only",
                "basis": "root-confirmed independent tester GO with stable pre/post source hash",
                "review_artifact_pinned_in_repository": False,
            } and
            inputs.get(before_receipt["path"]) == before_receipt and
            path_policy.get("schema") ==
                "vnext-t2-r20-runs-only-execution-path-policy-r1" and
            path_policy.get("required_direct_child_root") ==
                "runs/UP1-04A-VNEXT-T2" and
            path_policy.get("direct_child_only") is True and
            path_policy.get("rejects_docs_nested_external_and_junctioned_parents")
                is True and
            path_policy.get("applies_to") == [
                "controller.main(--evidence-dir)",
                "controller.main(--resume-authority-from)",
                "controller.verify_authority_resume_ancestry(resume_root)",
            ] and
            path_policy.get("r9_host_smoke_is_current_path_gate_test") is False and
            path_policy.get("r9_host_smoke_controller_sha256") ==
                before_receipt["sha256"] and
            path_policy.get("current_controller_sha256") ==
                controller_pin["sha256"] and
            path_policy.get("freeze_protocol_output_root") ==
                "runs/UP1-04A-VNEXT-T2",
            "R9-to-current controller path-gate delta receipt is missing or widened")

    before_text = HOST_SMOKE_CONTROLLER_SOURCE.read_text(encoding="utf-8")
    old_tree = ast.parse(before_text)
    new_tree = ast.parse(controller_source)
    old_functions = {node.name: node for node in old_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: node for node in new_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    observed = sorted(name for name in old_functions.keys() | new_functions.keys()
                      if old_functions.get(name) is None or new_functions.get(name) is None or
                      ast.dump(old_functions[name], include_attributes=False) !=
                      ast.dump(new_functions[name], include_attributes=False))
    require(observed == expected_changes and
            before_receipt["sha256"] ==
                "c1607fc4508356366e9eee350582dd9df2248b3b89022ce4ea43928d1148d9b4" and
            receipt(R20_CONTROLLER) == controller_pin and
            protocol.get("execution_evidence_path_policy", {}).get(
                "required_direct_child_root") == "runs/UP1-04A-VNEXT-T2",
            "current controller path gate does not match the frozen source transition")

    class StripPathOnlyChanges(ast.NodeTransformer):
        def __init__(self, current: bool):
            self.current = current
            self.function_stack: list[str | None] = []

        def visit_Module(self, node: ast.Module) -> ast.Module:
            retained = []
            for statement in node.body:
                if self.current and isinstance(statement, ast.FunctionDef) and \
                        statement.name == "require_t2_execution_leaf":
                    continue
                if self.current and isinstance(statement, ast.Assign) and any(
                        isinstance(target, ast.Name) and
                        target.id == "T2_RAW_EVIDENCE_ROOT"
                        for target in statement.targets):
                    continue
                retained.append(self.visit(statement))
            node.body = retained
            return node

        def visit_FunctionDef(self, node: ast.FunctionDef) -> ast.FunctionDef:
            inherited = self.function_stack[-1] if self.function_stack else None
            path_context = node.name if node.name in {
                "main", "verify_authority_resume_ancestry"} else inherited
            self.function_stack.append(path_context)
            try:
                return self.generic_visit(node)
            finally:
                self.function_stack.pop()

        def visit_Expr(self, node: ast.Expr) -> ast.AST | None:
            context = self.function_stack[-1] if self.function_stack else None
            if context is not None and self._is_path_gate_statement(node, context):
                return None
            return self.generic_visit(node)

        def _is_path_gate_statement(self, statement: ast.stmt,
                                    function_name: str) -> bool:
            if not isinstance(statement, ast.Expr) or \
                    not isinstance(statement.value, ast.Call):
                return False
            call = statement.value
            if self.current:
                return isinstance(call.func, ast.Name) and \
                    call.func.id == "require_t2_execution_leaf"
            if not isinstance(call.func, ast.Attribute) or \
                    call.func.attr != "relative_to" or len(call.args) != 1:
                return False
            allowed_values = {
                "main": {"output", "resume_authority_from"},
                "verify_authority_resume_ancestry": {"resume_root"},
            }
            if not isinstance(call.func.value, ast.Name) or \
                    call.func.value.id not in allowed_values[function_name]:
                return False
            expected_root = ast.parse(
                "ROOT / 'docs/implementation/UP1-04A-VNEXT-T2'").body[0].value
            return ast.dump(call.args[0], include_attributes=False) == \
                ast.dump(expected_root, include_attributes=False)

    normalized_before = StripPathOnlyChanges(current=False).visit(
        ast.parse(before_text))
    normalized_current = StripPathOnlyChanges(current=True).visit(
        ast.parse(controller_source))
    require(ast.dump(normalized_current, include_attributes=False) ==
            ast.dump(normalized_before, include_attributes=False),
            "controller source changed beyond the three path-gate edits")
    require(controller.T2_RAW_EVIDENCE_ROOT.resolve() ==
            (ROOT / "runs/UP1-04A-VNEXT-T2").resolve(),
            "controller runs-only root constant changed")

    controls: list[dict[str, str]] = []
    direct = controller.T2_RAW_EVIDENCE_ROOT / "qa_direct_child"
    controller.require_t2_execution_leaf(direct)
    controls.append({"name": "runs-root direct child accepted", "status": "pass"})
    reject("docs archive leaf rejected",
           lambda: controller.require_t2_execution_leaf(
               ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/qa_leaf"), controls)
    reject("nested runs leaf rejected",
           lambda: controller.require_t2_execution_leaf(
               controller.T2_RAW_EVIDENCE_ROOT / "nested" / "qa_leaf"), controls)
    with tempfile.TemporaryDirectory(prefix="r20-path-gate-") as raw_temp:
        external_leaf = Path(raw_temp) / "external_leaf"
        reject("external leaf rejected",
               lambda: controller.require_t2_execution_leaf(external_leaf), controls)
        root_before = controller.T2_RAW_EVIDENCE_ROOT
        try:
            controller.T2_RAW_EVIDENCE_ROOT = Path(raw_temp).resolve()
            target = Path(raw_temp) / "target"
            target.mkdir()
            junction = Path(raw_temp) / "junction"
            completed = subprocess.run(
                ["cmd.exe", "/c", "mklink", "/J", str(junction), str(target)],
                capture_output=True, text=True, timeout=15, check=False)
            require(completed.returncode == 0 and junction.exists() and
                    junction.resolve() == target.resolve(),
                    "could not create/resolve the deterministic directory junction control")
            if hasattr(os.path, "isjunction"):
                require(os.path.isjunction(junction),
                        "Windows path control was not a junction")
            reject("junctioned parent rejected",
                   lambda: controller.require_t2_execution_leaf(junction / "qa_leaf"),
                   controls)
            junction.rmdir()
        finally:
            controller.T2_RAW_EVIDENCE_ROOT = root_before
    require(len(controls) == 5 and all(row.get("status") == "pass"
                                       for row in controls),
            "runs-only output/resume path gate controls are incomplete")
    return {
        "status": "pass",
        "source_delta": delta["schema"],
        "path_controls": controls,
        "source_snapshot_to_handle_logic_unchanged": True,
        "pid_filetime_cleanup_logic_unchanged": True,
        "resource_and_coverage_gates_unchanged": True,
    }


def verify_host_smoke_failure_lineage(protocol: dict[str, Any],
                                      inputs: dict[str, Any]) -> dict[str, Any]:
    lineage = protocol.get("r17_native_monitor_host_smoke_failure_lineage")
    require(isinstance(lineage, dict) and lineage.get("attempt_count") == 2 and
            set(lineage.get("attempts", {})) == {"r5", "r6"} and
            lineage.get("failure_evidence_overwritten") is False,
            "R17 host smoke retry failure lineage is incomplete")
    for label, leaf in HOST_SMOKE_RETRY_LEAVES.items():
        attempt = lineage["attempts"][label]
        expected_files = {
            "r5": {
                "command_argv.json", "exit_code.json", "stderr.raw", "stdout.raw",
                "natural_python_child/phase.json",
                "natural_python_child/samples.jsonl",
                "natural_python_child/stderr.raw",
                "natural_python_child/stdout.raw",
                "timed_python_child/phase.json",
                "timed_python_child/samples.jsonl",
                "timed_python_child/stderr.raw",
                "timed_python_child/stdout.raw",
            },
            "r6": {
                "command_argv.json", "exit_code.json", "stderr.raw", "stdout.raw",
                "natural_python_child/samples.jsonl",
                "natural_python_child/stderr.raw",
                "natural_python_child/stdout.raw",
            },
        }[label]
        require(attempt.get("leaf") == leaf.relative_to(ROOT).as_posix() and
                attempt.get("exit_code") == 1 and
                attempt.get("formal_t2_accepted") is False,
                f"R17 host smoke {label} is not a preserved failure")
        rows = attempt.get("file_receipts")
        require(isinstance(rows, dict) and set(rows) == expected_files,
            f"R17 host smoke {label} failure file set is not exact")
        for name, expected in rows.items():
            path = leaf / name
            require(receipt(path) == expected and inputs.get(expected["path"]) == expected,
                    f"R17 host smoke {label} lineage pin drift: {name}")
        command = load(leaf / "command_argv.json")
        result = load(leaf / "exit_code.json")
        require(command.get("kind") == "python_only_host_supervisor_smoke" and
                command.get("julia_started") is False and
                result.get("exit_code") == 1,
                f"R17 host smoke {label} lineage claim mismatch")
        if label == "r5":
            stdout = (leaf / "stdout.raw").read_text(encoding="utf-8")
            observation = json.loads(stdout.splitlines()[0])
            natural = observation.get("natural_phase", {})
            samples = [json.loads(line) for line in
                       (leaf / "natural_python_child/samples.jsonl")
                       .read_text(encoding="utf-8").splitlines()]
            require(attempt.get("failure_class") ==
                    "natural_terminal_sample_missing_root; rejected" and
                    natural.get("process_tree_samples_complete") is False and
                    natural.get("stop_reason") == "process_tree_monitor_incomplete" and
                    any(row.get("sample_complete") is False and any(
                        error.get("type") == "ProcessTableError" and
                        error.get("message") ==
                        "root process is absent from process table"
                        for error in row.get("errors", [])) for row in samples),
                    "R17 host smoke r5 failure classification drift")
        else:
            stderr = (leaf / "stderr.raw").read_text(encoding="utf-8")
            require(attempt.get("failure_class") ==
                    "terminal_sample_race_unboundlocalerror; rejected" and
                    "UnboundLocalError: cannot access local variable 'terminal_sample_race'"
                    in stderr,
                    "R17 host smoke r6 failure classification drift")
    return {"status": "pass", "attempts": 2,
            "r5_failure_pinned": True, "r6_failure_pinned": True}


def verify_r18_predicate_no_go_lineage(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    lineage = protocol.get("r18_predicate_probe_no_go_lineage")
    require(isinstance(lineage, dict) and
            lineage.get("schema") == "vnext-t2-r18-predicate-probe-no-go-r1" and
            lineage.get("status") == "preserved_no_go" and
            lineage.get("passed_case_count") == 39 and
            lineage.get("test_count") == 49 and
            lineage.get("failure_count") == 10,
            "R18 predicate tester NO-GO lineage is missing")
    tester_files = {
        path.relative_to(R18_PREDICATE_TESTER_LEAF).as_posix(): receipt(path)
        for path in R18_PREDICATE_TESTER_LEAF.rglob("*") if path.is_file()
    }
    require(lineage.get("tester_files") == tester_files and
            all(inputs.get(row["path"]) == row for row in tester_files.values()),
            "R18 predicate tester raw/source evidence pins drift")
    r18_protocol_pin = receipt(R18_FREEZE_RETRY2_LEAF / "protocol.json")
    require(lineage.get("r18_protocol") == r18_protocol_pin and
            inputs.get(r18_protocol_pin["path"]) == r18_protocol_pin,
            "R18 predecessor protocol pin drift")

    r18_probe = json.loads((R18_PREDICATE_TESTER_LEAF /
                            "predicate_probe_r4.stdout.raw").read_text(encoding="utf-8"))
    expected_failures = {
        "snapshot_missing_host_identity", "snapshot_wrong_host_identity",
        "snapshot_missing_system_information_class",
        "snapshot_wrong_system_information_class",
        "snapshot_missing_buffer_bytes", "snapshot_wrong_buffer_bytes",
        "snapshot_missing_query_attempts", "snapshot_wrong_query_attempts",
        "snapshot_missing_raw_identity_digest",
        "snapshot_malformed_raw_identity_digest",
    }
    require((R18_PREDICATE_TESTER_LEAF / "predicate_probe_r4.exit.txt")
            .read_text(encoding="ascii").strip() == "1" and
            r18_probe.get("schema") == "independent-t2-r18-audit-predicate-probe-r1" and
            r18_probe.get("status") == "fail" and
            r18_probe.get("protocol_sha256") == r18_protocol_pin["sha256"] and
            r18_probe.get("negative_case_count") == 47 and
            r18_probe.get("positive_case_count") == 2 and
            r18_probe.get("passed_case_count") == 39 and
            r18_probe.get("test_count") == 49 and
            set(r18_probe.get("failures", [])) == expected_failures,
            "R18 predicate probe failure does not match the exact 39/49 snapshot gap")

    review_files = {
        path.relative_to(R18_REVIEW_LEAF).as_posix(): receipt(path)
        for path in R18_REVIEW_LEAF.rglob("*") if path.is_file()
    }
    expected_review = {
        "review.json": "7840672478b7236efc5b8c96dcaf36930a0e947e4c18720e4966ce4ee36f5e83",
        "evidence_manifest.json": "93fdbbd1c359d32f54a7548fec8278e66a44326ec55aa9dce9f4cd1ba768dea6",
    }
    require(all(review_files.get(name, {}).get("sha256") == expected_sha
                for name, expected_sha in expected_review.items()) and
            lineage.get("review_files") == review_files and
            all(inputs.get(row["path"]) == row for row in review_files.values()),
            "R18 prelaunch review lineage is not the sealed report/manifest")
    tester_source = receipt(R18_PREDICATE_TESTER_SOURCE)
    require(lineage.get("tester_source") == tester_source and
            inputs.get(tester_source["path"]) == tester_source,
            "R18 predicate tester source is not pinned")
    return {"status": "pass", "r18_predicate_tester_no_go_preserved": True,
            "failed_cases": sorted(expected_failures),
            "review_lineage_pinned": True}


def make_r19_native_table(controller: Any) -> Any:
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS + 123_456_789
    rows = (
        native.ProcessRow(native.ProcessIdentity(0, ticks), 0, ""),
        native.ProcessRow(native.ProcessIdentity(4, ticks), 0, "System"),
    )
    return native.ProcessTableSnapshot(
        rows=rows, host_identity=tuple(native.WINDOWS_BUILD_PIN),
        buffer_bytes=native.SPI_FIXED_HEADER_BYTES, query_attempts=1,
        ntstatus_u32=0)


def run_r19_final_audit_with_receipt(controller: Any, table: Any,
                                     heavy_receipt: dict[str, Any]) -> dict[str, Any]:
    root_identity = (0xFFFFFFFE, controller._R23_TABLE.WINDOWS_EPOCH_100NS + 999)
    with patch.object(controller, "_r23_exact_heavy_audit",
                      return_value=copy.deepcopy(heavy_receipt)):
        return controller._r23_final_audit(
            root_identity, [root_identity], table, root_exit_confirmed=True)


def make_r20_process_table(controller: Any,
                           rows: list[tuple[int, int, int, str]]) -> Any:
    native = controller._R23_TABLE
    typed = tuple(native.ProcessRow(native.ProcessIdentity(pid, ticks), ppid, name)
                  for pid, ticks, ppid, name in rows)
    return native.ProcessTableSnapshot(
        rows=typed, host_identity=tuple(native.WINDOWS_BUILD_PIN),
        buffer_bytes=native.SPI_FIXED_HEADER_BYTES, query_attempts=1,
        ntstatus_u32=0)


def run_r20_sample_handoff_controls(controller: Any,
                                    controls: list[dict[str, str]],
                                    positives: list[str]) -> dict[str, Any]:
    negative_start = len(controls)
    positive_start = len(positives)
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS
    source = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
        (200, ticks + 200, 100, "git.exe"),
        (300, ticks + 300, 200, "git-helper.exe"),
        (400, ticks + 400, 300, "git-child.exe"),
    ])
    absent = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
    ])
    root = (100, ticks + 100)
    tracked = [(150, ticks + 150)]
    target = (200, ticks + 200)
    accepted_record = controller._r20_confirm_unbound_sample_race(
        source, target, root, tracked, absent, [absent, absent])
    require(accepted_record.get("complete") is True and
            accepted_record.get("confirmation_snapshot_count") == 2 and
            len(accepted_record.get("observed_generations", [])) == 3 and
            accepted_record.get("exact_handle_opened") is False and
            accepted_record.get("exact_handle_waited") is False and
            accepted_record.get("exact_handle_exit_receipt_created") is False and
            accepted_record.get("exit_code_credit_issued") is False and
            accepted_record.get("rss_credit_bytes") == 0 and
            accepted_record.get("cpu_credit_seconds") ==
                {"user": 0.0, "system": 0.0},
            "R20 rejected a valid two-absence unbound descendant subtree")
    positives.append("R20 accepts bounded absent subtree as unbound, with no exit/RSS credit")

    direct_cases = {
        "same target remains present": (source, [absent, absent]),
        "target PID reused by one FILETIME tick": (make_r20_process_table(controller, [
            (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
            (100, ticks + 100, 4, "julia.exe"),
            (150, ticks + 150, 100, "tracked-worker.exe"),
            (200, ticks + 201, 100, "reused.exe"),
        ]), [absent, absent]),
        "known child remains orphaned under vanished parent": (
            make_r20_process_table(controller, [
                (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (100, ticks + 100, 4, "julia.exe"),
                (150, ticks + 150, 100, "tracked-worker.exe"),
                (400, ticks + 400, 300, "git-child.exe"),
            ]), [absent, absent]),
        "new orphan chain under vanished parent": (
            make_r20_process_table(controller, [
                (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (100, ticks + 100, 4, "julia.exe"),
                (150, ticks + 150, 100, "tracked-worker.exe"),
                (500, ticks + 500, 300, "new-orphan-child.exe"),
                (900, ticks + 900, 500, "new-orphan-grandchild.exe"),
            ]), [absent, absent]),
        "root missing during confirmation": (
            make_r20_process_table(controller, [
                (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (150, ticks + 150, 100, "tracked-worker.exe"),
            ]), [absent, absent]),
        "previously tracked row missing during confirmation": (
            make_r20_process_table(controller, [
                (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (100, ticks + 100, 4, "julia.exe"),
            ]), [absent, absent]),
        "root PID reused during confirmation": (
            make_r20_process_table(controller, [
                (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (100, ticks + 101, 4, "reused-root.exe"),
                (150, ticks + 150, 100, "tracked-worker.exe"),
            ]), [absent, absent]),
        "only one extra confirmation supplied": (absent, [absent]),
        "incomplete table supplied": (None, [absent, absent]),
    }
    for label, (lookup, confirmations) in direct_cases.items():
        result = controller._r20_confirm_unbound_sample_race(
            source, target, root, tracked, lookup, confirmations)
        require(result.get("complete") is False and result.get("errors"),
                f"R20 accepted unsafe race confirmation: {label}")
        controls.append({"name": f"R20 rejects unsafe unbound-race confirmation: {label}",
                         "status": "pass", "rejected_as": "monitor_incomplete"})

    source_missing_target = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
    ])
    missing_source = controller._r20_confirm_unbound_sample_race(
        source_missing_target, target, root, tracked, absent, [absent, absent])
    require(missing_source.get("complete") is False and
            missing_source.get("errors"),
            "R20 credited a child that was never present in its source snapshot")
    controls.append({"name": "R20 rejects an unbound target absent from source snapshot",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    class FakeRegistry:
        def __init__(self, deny: set[tuple[int, int]] | None = None,
                     failures: dict[tuple[int, int], list[BaseException]] | None = None,
                     expected_source: Any = None):
            self.deny = deny or set()
            self.failures = {key: list(value)
                             for key, value in (failures or {}).items()}
            self.expected_source = expected_source
            self.open_attempts: list[dict[str, Any]] = []

        def for_row(self, row: Any, snapshot: Any) -> tuple[int, int]:
            identity = (row.identity.pid, row.identity.create_time_100ns)
            table = native.validate_snapshot(snapshot)
            observed = table.by_pid.get(identity[0])
            source_exact = snapshot is self.expected_source
            self.open_attempts.append({"identity": identity,
                                       "snapshot": snapshot,
                                       "source_snapshot_exact": source_exact})
            if observed is None or (observed.identity.pid,
                                    observed.identity.create_time_100ns) != identity:
                raise PermissionError("synthetic row not bound to supplied SPI snapshot")
            failures = self.failures.get(identity, [])
            if failures:
                raise failures.pop(0)
            if identity in self.deny:
                raise PermissionError("synthetic open-denied control")
            return identity

    class FakeProcess:
        pass

    def fake_resource_reader(pid: int) -> dict[str, Any]:
        return {"rss_bytes": 100 if pid == root[0] else 50,
                "cpu_user_seconds": 0.2, "cpu_system_seconds": 0.1,
                "cmdline": ["synthetic"]}

    def execute_sample(snapshot_rows: list[Any], *, denied: set[tuple[int, int]] | None = None,
                       failures: dict[tuple[int, int], list[BaseException]] | None = None,
                       registry: Any = None,
                       query_log: list[Any] | None = None,
                       resource_reader: Any = None,
                       native_wait: Any = False
                       ) -> dict[str, Any]:
        iterator = iter(snapshot_rows)
        registry = registry or FakeRegistry(denied, failures)

        def next_snapshot() -> Any:
            value = next(iterator)
            if query_log is not None:
                query_log.append(value)
            return value

        with patch.object(native, "query_native_process_table",
                          side_effect=next_snapshot), \
                patch.object(native, "read_process_handle_identity",
                             side_effect=lambda handle: handle), \
                patch.object(native, "wait_for_process_exit",
                             side_effect=(native_wait if callable(native_wait) else
                                          lambda handle, timeout: native_wait)), \
                patch.object(controller, "_r23_resource_reader",
                             side_effect=resource_reader or fake_resource_reader):
            return controller._r20_native_sample(
                FakeProcess(), registry, root, tracked,
                sample_index=9, elapsed=0.0,
                deadline_monotonic=controller.time.monotonic() + 10.0)

    recovery_query_log: list[Any] = []
    recovery_registry = FakeRegistry(
        failures={target: [FileNotFoundError("synthetic child exited before OpenProcess")]},
        expected_source=source)
    recovered = execute_sample(
        [source, absent, absent, absent, absent, absent],
        registry=recovery_registry, query_log=recovery_query_log)
    require(recovered.get("sample_complete") is True and
            recovered.get("sample_attempt_count") == 2 and
            recovered.get("process_tree_working_set_bytes") == 150 and
            recovered.get("process_tree_user_cpu_seconds") == 0.4 and
            recovered.get("observed_process_count") == 2 and
            len(recovered.get("sample_handoff_recoveries", [])) == 1,
            "R20 did not replace a partial sample with one fresh complete sample")
    recovery = recovered["sample_handoff_recoveries"][0]
    require(recovery.get("full_sample_completed_after_retry") is True and
            recovery.get("exact_handle_open_failure", {}).get("pid") == target[0] and
            recovery.get("exact_handle_open_failure", {}).get(
                "exception_type") == "FileNotFoundError" and
            recovery.get("source_snapshot") ==
                controller._r23_snapshot_receipt(source) and
            recovery.get("lookup_snapshot") ==
                controller._r23_snapshot_receipt(absent) and
            recovery.get("confirmation_snapshots") == [
                controller._r23_snapshot_receipt(absent),
                controller._r23_snapshot_receipt(absent)] and
            recovery.get("exact_handle_exit_receipt_created") is False and
            recovery.get("exit_code_credit_issued") is False and
            recovery.get("rss_credit_bytes") == 0 and
            recovery.get("cpu_credit_seconds") ==
                {"user": 0.0, "system": 0.0} and
            recovery.get("discarded_attempt", {}).get(
                "observed_partial_rss_bytes_not_credited") == 150 and
            recovery.get("discarded_attempt", {}).get("credited_rss_bytes") == 0 and
            recovery.get("rss_credit_bytes") == 0 and
            recovery.get("exit_code_credit_issued") is False and
            recovery.get("exact_handle_exit_receipt_created") is False and
            [item.get("pid") for item in recovery["observed_generations"]] ==
                [200, 300, 400],
            "R20 discarded-attempt metrics or transient generation closure are misreported")
    target_attempts = [item for item in recovery_registry.open_attempts
                       if item["identity"] == target]
    require(len(target_attempts) == 1 and
            target_attempts[0].get("source_snapshot_exact") is True and
            target_attempts[0].get("snapshot") is source and
            len(recovery_query_log) == 6 and
            recovery_query_log[:4] == [source, absent, absent, absent],
            "R20 did not bind the disappearing git row to its before-SPI snapshot "
            "or did not take exactly three post-failure snapshots")
    positives.append("R20 binds the R19-style disappearing git row to before-SPI; retries only a fresh whole sample")

    stable_no_exit = execute_sample([source, source], native_wait=False)
    require(stable_no_exit.get("sample_complete") is True and
            stable_no_exit.get("sample_attempt_count") == 1 and
            stable_no_exit.get("sample_handoff_recoveries") == [] and
            stable_no_exit.get("process_tree_working_set_bytes") > 0,
            "R20 zero-time non-signaled handle control changed the stable positive path")
    positives.append("R20 non-signaled exact process handles retain the complete positive sample path")

    signaled_log: list[Any] = []
    signaled_registry = FakeRegistry(expected_source=source)
    signaled_retry = execute_sample(
        [source, absent, absent, absent, absent, absent],
        registry=signaled_registry, query_log=signaled_log,
        native_wait=lambda handle, timeout: handle == target)
    require(signaled_retry.get("sample_complete") is True and
            signaled_retry.get("sample_attempt_count") == 2 and
            len(signaled_retry.get("sample_handoff_recoveries", [])) == 1,
            "R20 did not retry a whole sample after OpenProcess returned an already-signaled handle")
    signaled_recovery = signaled_retry["sample_handoff_recoveries"][0]
    require(signaled_recovery.get("exact_handle_opened") is True and
            signaled_recovery.get("exact_handle_waited") is True and
            signaled_recovery.get("exact_handle_already_signaled") is True and
            signaled_recovery.get("exact_handle_binding", {}).get("identity") == {
                "pid": target[0], "create_time_100ns": target[1]} and
            signaled_recovery.get("complete") is True and
            signaled_recovery.get("full_sample_completed_after_retry") is True and
            signaled_recovery.get("exact_handle_exit_receipt_created") is False and
            signaled_recovery.get("exit_code_credit_issued") is False and
            signaled_recovery.get("rss_credit_bytes") == 0 and
            signaled_recovery.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            signaled_recovery.get("discarded_attempt", {}).get("credited_rss_bytes") == 0 and
            signaled_recovery.get("discarded_attempt", {}).get(
                "exact_handle_exit_receipt_created") is False and
            signaled_log[:4] == [source, absent, absent, absent],
            "R20 granted metric/exit credit or skipped three fresh snapshots for a signaled handle")
    positives.append("R20 routes a successfully opened but already-signaled generation through the same three-snapshot full-sample retry")

    for label, wait_result in (
            ("non-boolean native wait", lambda handle, timeout: 1
             if handle == target else False),
            ("native wait exception", lambda handle, timeout: (
                (_ for _ in ()).throw(OSError("synthetic native wait failure"))
                if handle == target else False))):
        wait_failure = execute_sample(
            [source, source, source, source],
            registry=FakeRegistry(expected_source=source),
            native_wait=wait_result)
        wait_recovery = wait_failure.get("sample_handoff_recoveries", [{}])[0]
        require(wait_failure.get("sample_complete") is False and
                wait_failure.get("sample_attempt_count") == 1 and
                wait_failure.get("process_tree_working_set_bytes") == 0 and
                wait_failure.get("process_tree_user_cpu_seconds") == 0.0 and
                wait_recovery.get("exact_handle_opened") is True and
                wait_recovery.get("exact_handle_waited") is True and
                wait_recovery.get("complete") is False and
                wait_recovery.get("retry_started") is False and
                wait_recovery.get("full_sample_completed_after_retry") is False and
                wait_recovery.get("exact_handle_exit_receipt_created") is False and
                wait_recovery.get("exit_code_credit_issued") is False and
                wait_recovery.get("rss_credit_bytes") == 0 and
                wait_failure.get("exact_monitor_receipt", {}).get(
                    "numerical_credit") is False,
                f"R20 treated {label} as live or granted credit")
        controls.append({"name": f"R20 {label} fails closed without metric/exit credit",
                         "status": "pass", "rejected_as": "monitor_incomplete"})

    closed_handles: list[tuple[int, int]] = []
    real_registry = controller._R23_SUPERVISOR.ExactHandleRegistry(
        opener=lambda row: (row.identity.pid, row.identity.create_time_100ns),
        identity_reader=lambda handle: handle,
        closer=closed_handles.append)
    close_verified_retry = execute_sample(
        [source, absent, absent, absent, absent, absent],
        registry=real_registry,
        native_wait=lambda handle, timeout: handle == target)
    close_receipt = real_registry.close_owned()
    require(close_verified_retry.get("sample_complete") is True and
            close_verified_retry.get("sample_handoff_recoveries", [{}])[0].get(
                "exact_handle_already_signaled") is True and
            close_receipt.get("complete") is True and
            {"pid": target[0], "create_time_100ns": target[1]} in
                close_receipt.get("closed_owned_handles", []) and
            target in closed_handles,
            "R20 did not close the owned exact handle opened for the already-signaled generation")
    positives.append("R20 closes the exact owned handle used to classify an already-signaled generation")

    repeated = execute_sample(
        [source, absent, absent, absent, source, absent, absent, absent],
        failures={target: [FileNotFoundError("first synthetic child exit"),
                           FileNotFoundError("second synthetic child exit")]})
    require(repeated.get("sample_complete") is False and
            repeated.get("sample_attempt_count") == 2 and
            repeated.get("process_tree_working_set_bytes") == 0 and
            repeated.get("process_tree_user_cpu_seconds") == 0.0 and
            len(repeated.get("sample_handoff_recoveries", [])) == 2 and
            repeated["sample_handoff_recoveries"][-1].get("status") ==
                "retry_exhausted_or_phase_deadline_monitor_incomplete" and
            repeated["sample_handoff_recoveries"][-1].get(
                "full_sample_completed_after_retry") is False,
            "R20 retry exhaustion granted sample/metric credit")
    controls.append({"name": "R20 retry exhaustion remains incomplete with zero metric credit",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    denied = execute_sample([source, source, source, source], denied={target})
    denied_recovery = denied.get("sample_handoff_recoveries", [{}])[0]
    denied_open = denied_recovery.get("exact_handle_open_failure", {})
    require(denied.get("sample_complete") is False and
            denied.get("sample_attempt_count") == 1 and
            len(denied.get("sample_handoff_recoveries", [])) == 1 and
            denied_recovery.get("complete") is False and
            denied_recovery.get(
                "full_sample_completed_after_retry") is False and
            denied_recovery.get("retry_started") is False and
            denied_open.get("exception_type") == "PermissionError" and
            "synthetic open-denied control" in denied_open.get("message", "") and
            denied.get("process_tree_working_set_bytes") == 0 and
            denied.get("process_tree_user_cpu_seconds") == 0.0 and
            denied.get("exact_monitor_receipt", {}).get("numerical_credit") is False,
            "R20 treated open-denied as an absent-process race")
    controls.append({"name": "R20 open-denied is not converted to transient absence",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    one_tick_reuse = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
        (200, ticks + 201, 100, "reused-one-tick.exe"),
    ])
    orphan_after_parent = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
        (500, ticks + 500, 300, "new-orphan.exe"),
    ])
    unbound_failure_cases = (
        ("one-tick PID reuse in the third fresh table",
         [source, absent, absent, one_tick_reuse],
         {target: [FileNotFoundError("synthetic exit before handle")]}),
        ("orphan remains beneath the vanished subtree",
         [source, absent, orphan_after_parent, absent],
         {target: [FileNotFoundError("synthetic exit before handle")]}),
        ("malformed fresh SPI snapshot",
         [source, absent, None],
         {target: [FileNotFoundError("synthetic exit before handle")]}),
    )
    for label, queued_tables, injected_failures in unbound_failure_cases:
        rejected = execute_sample(queued_tables, failures=injected_failures)
        require(rejected.get("sample_complete") is False and
                rejected.get("sample_attempt_count") == 1 and
                len(rejected.get("sample_handoff_recoveries", [])) == 1 and
                rejected["sample_handoff_recoveries"][0].get("complete") is False and
                rejected["sample_handoff_recoveries"][0].get(
                    "exact_handle_exit_receipt_created") is False and
                rejected["sample_handoff_recoveries"][0].get(
                    "exit_code_credit_issued") is False and
                rejected["sample_handoff_recoveries"][0].get("rss_credit_bytes") == 0 and
                rejected.get("process_tree_working_set_bytes") == 0 and
                rejected.get("process_tree_user_cpu_seconds") == 0.0,
                f"R20 granted completion/credit after {label}")
        controls.append({"name": f"R20 open-race fails closed: {label}",
                         "status": "pass", "rejected_as": "monitor_incomplete"})

    appeared_after_source = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (100, ticks + 100, 4, "julia.exe"),
        (150, ticks + 150, 100, "tracked-worker.exe"),
        (500, ticks + 500, 100, "appeared-after-before.exe"),
    ])
    appeared = execute_sample([absent, appeared_after_source])
    require(appeared.get("sample_complete") is False and
            appeared.get("sample_handoff_recoveries") == [] and
            appeared.get("exact_monitor_receipt", {}).get("complete") is False and
            appeared.get("exact_monitor_receipt", {}).get("numerical_credit") is False,
            "R20 accepted a child that appeared after the before-SPI snapshot")
    controls.append({"name": "R20 rejects a new child appearing after before-SPI",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    measured_then_exited = execute_sample([source, absent])
    require(measured_then_exited.get("sample_complete") is False and
            measured_then_exited.get("sample_handoff_recoveries") == [] and
            measured_then_exited.get("exact_monitor_receipt", {}).get("complete") is False and
            measured_then_exited.get("exact_handle_exit_receipt_created") is not True and
            measured_then_exited.get("exact_monitor_receipt", {}).get(
                "numerical_credit") is False,
            "R20 treated a post-measurement exit as a complete sample or exit receipt")
    controls.append({"name": "R20 post-measurement exit remains incomplete without an exact exit receipt",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    def resource_reader_fails(pid: int) -> dict[str, Any]:
        raise RuntimeError("synthetic resource-read failure")

    resource_failure = execute_sample([absent], resource_reader=resource_reader_fails)
    require(resource_failure.get("sample_complete") is False and
            resource_failure.get("process_tree_working_set_bytes") == 0 and
            resource_failure.get("process_tree_user_cpu_seconds") == 0.0 and
            resource_failure.get("exact_monitor_receipt", {}).get("complete") is False and
            any("synthetic resource-read failure" in str(error)
                for error in resource_failure.get("errors", [])),
            "R20 accepted a failed resource read or issued metric credit")
    controls.append({"name": "R20 resource-reader failure remains incomplete with zero credit",
                     "status": "pass", "rejected_as": "monitor_incomplete"})

    accepted_record["full_sample_completed_after_retry"] = True
    final_empty = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System")])
    final_present = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (200, ticks + 200, 4, "reappeared-or-reused.exe")])
    final_orphan = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (500, ticks + 500, 300, "late-child.exe"),
        (900, ticks + 900, 500, "late-grandchild.exe")])
    fake_root = (0xFFFFFFFE, ticks + 999)

    def final_audit(table: Any, record: dict[str, Any]) -> dict[str, Any]:
        valid_heavy = {
            "schema": "vnext-t2-r23-global-heavy-audit-r1", "complete": True,
            "processes": [], "controller_processes": [],
            "native_heavy_identities": [], "errors": [],
            "snapshot": controller._r23_snapshot_receipt(table),
        }
        with patch.object(controller, "_r23_exact_heavy_audit",
                          return_value=copy.deepcopy(valid_heavy)):
            return controller._r23_final_audit(
                fake_root, [fake_root], table, root_exit_confirmed=True,
                unbound_observation_records=[copy.deepcopy(record)])

    final_positive = final_audit(final_empty, accepted_record)
    require(final_positive.get("complete") is True and
            final_positive.get("unbound_observation_final_audit", {}).get(
                "complete") is True,
            "R20 final audit rejected an absent verified transient subtree")
    positives.append("R20 final audit accounts for all absent unbound generations")
    for label, table in (("transient PID reappears or is reused", final_present),
                         ("orphan chain under transient parent remains", final_orphan)):
        final = final_audit(table, accepted_record)
        require(final.get("complete") is False and
                final.get("unbound_observation_final_audit", {}).get(
                    "complete") is False,
                f"R20 final audit accepted {label}")
        controls.append({"name": f"R20 final audit rejects {label}",
                         "status": "pass", "rejected_as": "incomplete_final_audit"})

    for field, value in (
            ("exact_handle_exit_receipt_created", True),
            ("full_sample_completed_after_retry", False),
            ("rss_credit_bytes", 1),
            ("confirmation_snapshot_count", 1)):
        malformed = copy.deepcopy(accepted_record)
        malformed[field] = value
        final = final_audit(final_empty, malformed)
        require(final.get("complete") is False and any(
            error.get("stage") == "r20_unbound_observation_final_audit"
            for error in final.get("errors", [])),
            f"R20 final audit accepted malformed recovery receipt field {field}")
        controls.append({"name": f"R20 final audit rejects malformed recovery field {field}",
                         "status": "pass", "rejected_as": "incomplete_final_audit"})
    return {"positive_count": len(positives) - positive_start,
            "negative_count": len(controls) - negative_start,
            "contract": "two complete absence confirmations; full fresh sample; no exact exit credit",
            "orphan_chain_control": "a child+grandchild under vanished-parent generations is rejected",
            "final_audit_checks_unbound_ids_and_orphan_descendants": True}


def run_r20_phase_cleanup_controls(controller: Any,
                                   controls: list[dict[str, str]],
                                   positives: list[str],
                                   observation: dict[str, Any]) -> dict[str, Any]:
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS
    root_identity = (8000, ticks + 8000)
    table = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (root_identity[0], root_identity[1], 4, "julia.exe"),
    ])

    class FakeProcess:
        pid = root_identity[0]
        _handle = "synthetic-popen-handle"

        def __init__(self) -> None:
            self.poll_count = 0

        def poll(self) -> int | None:
            self.poll_count += 1
            return 0 if self.poll_count >= 3 else None

        def wait(self, timeout: float | None = None) -> int:
            return 0

    class FakeRegistry:
        def __init__(self, receipt_value: dict[str, Any]):
            self.receipt_value = copy.deepcopy(receipt_value)

        def bind_popen(self, process: Any, snapshot: Any) -> tuple[int, int]:
            native.validate_snapshot(snapshot)
            return root_identity

        def close_owned(self) -> dict[str, Any]:
            return copy.deepcopy(self.receipt_value)

    def execute(close_complete: bool) -> tuple[dict[str, Any], list[dict[str, Any]]]:
        close_receipt = {
            "schema": "native-g1g2-r23-handle-close-receipt-v1",
            "complete": close_complete,
            "closed_owned_handles": [],
            "errors": ([] if close_complete else [{
                "pid": 9000, "create_time_100ns": ticks + 9000,
                "type": "OSError", "message": "synthetic CloseHandle failure"}]),
            "popen_handles_not_owned_by_registry": 1,
        }
        sample = {
            "schema": "vnext-t2-process-tree-sample-r3-r20-unbound-race",
            "sample_complete": True,
            "sample_index": 1,
            "sample_handoff_recoveries": [],
            "process_tree_working_set_bytes": 1,
            "process_tree_user_cpu_seconds": 0.0,
            "process_tree_system_cpu_seconds": 0.0,
            "exact_monitor_receipt": {
                "complete": True,
                "discovered_identities": [{"pid": root_identity[0],
                                            "create_time_100ns": root_identity[1]}],
            },
        }

        def synthetic_native_sample(
                _process: Any, _registry: Any,
                sample_root_identity: tuple[int, int],
                sample_previous: list[tuple[int, int]], *,
                sample_index: int, elapsed: float, deadline_monotonic: float,
                previous_accepted_source_snapshot: Any | None = None,
                outer_reconcile_snapshot: Any | None = None,
                previous_accepted_sample_index: int | None = None,
                completed_source_snapshot_out: list[Any] | None = None
                ) -> dict[str, Any]:
            checked_table = native.validate_snapshot(table)
            require(checked_table == table and
                    native.validate_snapshot(outer_reconcile_snapshot) == checked_table and
                    sample_root_identity == root_identity and
                    sample_previous == [root_identity] and
                    sample_index == 1 and
                    previous_accepted_source_snapshot is None and
                    previous_accepted_sample_index is None and
                    type(completed_source_snapshot_out) is list and
                    completed_source_snapshot_out == [],
                    "R20 synthetic sampler received an unexpected source-table handoff")
            completed_source_snapshot_out.append(checked_table)
            return copy.deepcopy(sample)
        final_audit = {
            "schema": "vnext-t2-r23-final-process-tree-audit-r1",
            "complete": True,
            "root_exit_confirmed": True,
            "residual_descendant_processes": [],
            "global_heavy_process_audit": {"complete": True, "processes": []},
        }
        with tempfile.TemporaryDirectory(prefix="r20-cleanup-receipt-") as temp_dir:
            output = Path(temp_dir) / "phase"
            registry = FakeRegistry(close_receipt)
            with patch.object(controller.psutil, "Popen", return_value=FakeProcess()), \
                    patch.object(controller._R23_SUPERVISOR, "ExactHandleRegistry",
                                 return_value=registry), \
                    patch.object(native, "query_native_process_table", return_value=table), \
                    patch.object(native, "read_process_handle_identity",
                                 return_value=root_identity), \
                    patch.object(native, "wait_for_process_exit", return_value=True), \
                    patch.object(native, "process_exit_code", return_value=0), \
                    patch.object(controller, "_r23_reconcile_missing_tracked",
                                 return_value=([root_identity], [])), \
                    patch.object(controller, "_r20_native_sample",
                                 side_effect=synthetic_native_sample), \
                    patch.object(controller, "_r23_audit_and_cleanup",
                                 return_value=(final_audit, None)), \
                    patch.object(controller.time, "sleep", return_value=None):
                phase = controller.run_phase(
                    "r20_synthetic_handle_close", ["python", "-B", "synthetic"],
                    output, timeout_seconds=3.0,
                    working_set_limit_bytes=2_147_483_648,
                    environment={"R20_SYNTHETIC": "1"})
                sample_rows = [json.loads(line) for line in
                               (output / "samples.jsonl").read_text(
                                   encoding="utf-8").splitlines() if line]
                return phase, sample_rows

    def capture_phase(phase: dict[str, Any],
                      sample_rows: list[dict[str, Any]]) -> dict[str, Any]:
        keys = ("stop_reason", "exit_code", "process_tree_samples_complete",
                "process_tree_sample_count", "final_process_tree_audit",
                "residual_process_audit", "handle_close_receipt")
        return {**{key: copy.deepcopy(phase.get(key)) for key in keys},
                "formal_t2_accepted": False, "julia_executed": False,
                "process_tree_sample_rows": copy.deepcopy(sample_rows),
                "scope": "synthetic_preparation_control_only"}

    closed, closed_sample_rows = execute(True)
    observation["closed"] = capture_phase(closed, closed_sample_rows)
    close_failed, close_failed_sample_rows = execute(False)
    observation["close_failed"] = capture_phase(
        close_failed, close_failed_sample_rows)
    observation["status"] = "observed_synthetic_preparation_only"

    close_receipt = closed.get("handle_close_receipt")
    require(closed.get("stop_reason") == "natural_exit",
            "R20 synthetic natural-exit phase stop_reason was not natural_exit")
    require(closed.get("exit_code") == 0,
            "R20 synthetic natural-exit phase exit_code was not zero")
    require(closed.get("process_tree_samples_complete") is True and
            len(closed_sample_rows) == 1 and
            closed_sample_rows[0].get("sample_complete") is True,
            "R20 synthetic natural-exit phase did not complete its exact source sample")
    require(closed.get("final_process_tree_audit", {}).get("complete") is True,
            "R20 synthetic natural-exit phase final audit was incomplete")
    require(isinstance(close_receipt, dict) and
            close_receipt.get("schema") ==
                "native-g1g2-r23-handle-close-receipt-v1" and
            close_receipt.get("complete") is True and
            close_receipt.get("errors") == [] and
            close_receipt.get("closed_owned_handles") == [] and
            close_receipt.get("popen_handles_not_owned_by_registry") == 1 and
            close_receipt.get("popen_handle_close_policy") ==
                "retained_until_phase_return_then_closed_by_Popen_handle_owner",
            "R20 synthetic natural-exit phase owned-handle close receipt was invalid")
    positives.append(
        "R20 synthetic natural-exit path preserves a complete owned-handle close receipt")

    failed_close_receipt = close_failed.get("handle_close_receipt")
    require(close_failed.get("stop_reason") == "process_tree_monitor_incomplete",
            "R20 synthetic close-failure phase did not fail closed")
    require(close_failed.get("exit_code") == 0 and
            close_failed.get("process_tree_samples_complete") is True and
            len(close_failed_sample_rows) == 1 and
            close_failed_sample_rows[0].get("sample_complete") is True,
            "R20 synthetic close-failure phase changed the successful sample/exit")
    require(close_failed.get("final_process_tree_audit", {}).get("complete") is True,
            "R20 synthetic close-failure phase lost the isolated final-audit fixture")
    require(isinstance(failed_close_receipt, dict) and
            failed_close_receipt.get("schema") ==
                "native-g1g2-r23-handle-close-receipt-v1" and
            failed_close_receipt.get("complete") is False and
            failed_close_receipt.get("errors") and
            failed_close_receipt.get("popen_handles_not_owned_by_registry") == 1 and
            failed_close_receipt.get("popen_handle_close_policy") ==
                "retained_until_phase_return_then_closed_by_Popen_handle_owner",
            "R20 synthetic close-failure receipt did not retain its error")
    require(close_failed.get("formal_t2_accepted") is not True,
            "R20 synthetic close-failure phase claimed formal acceptance")
    controls.append({"name": "R20 synthetic cleanup failure blocks natural completion",
                     "status": "pass", "rejected_as": "process_tree_monitor_incomplete"})
    observation["status"] = "pass_synthetic_preparation_only"
    return {"positive_count": 1, "negative_count": 1,
            "scope": "synthetic_preparation_control_only",
            "synthetic_close_receipt_control_passed": True,
            "cleanup_failure_blocks_natural_exit": True,
            "formal_t2_accepted": False, "julia_executed": False}


def run_r20_unbound_cleanup_controls(controller: Any,
                                     controls: list[dict[str, str]],
                                     positives: list[str]) -> dict[str, Any]:
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS
    root = (100, ticks + 100)
    target = (200, ticks + 200)
    orphan = (300, ticks + 300)
    source = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (root[0], root[1], 4, "julia.exe"),
        (target[0], target[1], root[0], "git.exe"),
        (orphan[0], orphan[1], target[0], "git-helper.exe"),
    ])
    incomplete = controller._r20_confirm_unbound_sample_race(
        source, target, root, [], source, [source, source])
    require(incomplete.get("complete") is False and
            [item.get("pid") for item in incomplete.get(
                "observed_generations", [])] == [target[0], orphan[0]],
            "R20 cleanup fixture did not retain the exact failed-open source closure")
    incomplete["exact_handle_open_failure"] = {
        "stage": "r20_exact_handle_open_or_bind", "pid": target[0],
        "exception_type": "PermissionError", "message": "synthetic denied-open"}
    incomplete["full_sample_completed_after_retry"] = False
    incomplete["discarded_attempt"] = {
        "observed_partial_rss_bytes_not_credited": 77,
        "credited_rss_bytes": 0, "exit_code_credit_issued": False,
        "exact_handle_exit_receipt_created": False}

    class FakeProcess:
        pid = root[0]
        _handle = ("popen-root", *root)

    class FakeRegistry:
        def __init__(self):
            self.opened: list[tuple[int, int]] = []

        def for_row(self, row: Any, snapshot: Any) -> tuple[int, int]:
            table = native.validate_snapshot(snapshot)
            observed = table.by_pid.get(row.identity.pid)
            identity = (row.identity.pid, row.identity.create_time_100ns)
            require(observed is not None and
                    (observed.identity.pid, observed.identity.create_time_100ns) == identity,
                    "R20 unbound cleanup attempted to bind a row outside its SPI generation")
            self.opened.append(identity)
            return identity

    def cleanup_case(initial: Any, *, signal_exact: tuple[int, int] | None
                      ) -> tuple[dict[str, Any], dict[str, Any] | None,
                                 FakeRegistry, list[tuple[int, int]], dict[str, Any]]:
        state = {"snapshot": initial}
        registry = FakeRegistry()
        sent: list[tuple[int, int]] = []

        def send(identity: tuple[int, int], handle: Any, *,
                 timeout_seconds: float = 8.0) -> dict[str, Any]:
            require(tuple(handle) == tuple(identity),
                    "R20 unbound cleanup signalled a PID through a different handle identity")
            sent.append(identity)
            if identity == signal_exact:
                state["snapshot"] = clean
                return {"schema": "vnext-t2-r23-exact-signal-r1",
                        "complete": True, "verified": True,
                        "identity": {"pid": identity[0],
                                     "create_time_100ns": identity[1]},
                        "wait_confirmed": True, "errors": []}
            return {"schema": "vnext-t2-r23-exact-signal-r1",
                    "complete": False, "verified": False,
                    "identity": {"pid": identity[0],
                                 "create_time_100ns": identity[1]},
                    "wait_confirmed": False,
                    "errors": [{"message": "unexpected synthetic cleanup target"}]}

        def heavy(table: Any) -> dict[str, Any]:
            return {"schema": "vnext-t2-r23-global-heavy-audit-r1",
                    "complete": True, "processes": [],
                    "controller_processes": [], "native_heavy_identities": [],
                    "errors": [], "snapshot": controller._r23_snapshot_receipt(table)}

        with patch.object(native, "query_native_process_table",
                          side_effect=lambda: state["snapshot"]), \
                patch.object(controller, "_r23_signal_one", side_effect=send), \
                patch.object(controller, "_r23_exact_heavy_audit", side_effect=heavy):
            audit, receipt_value = controller._r23_audit_and_cleanup(
                FakeProcess(), registry, root, {root}, True,
                unbound_observation_records=[copy.deepcopy(incomplete)])
        return audit, receipt_value, registry, sent, state

    orphan_table = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (orphan[0], orphan[1], target[0], "git-helper.exe"),
    ])
    clean = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System")])
    audit, cleanup_receipt, registry, sent, state = cleanup_case(
        orphan_table, signal_exact=orphan)
    require(isinstance(cleanup_receipt, dict) and
            isinstance(cleanup_receipt.get("unbound_cleanup"), dict),
            "R20 cleanup omitted an explicit unbound-observation cleanup receipt")
    unbound_receipt = cleanup_receipt["unbound_cleanup"]
    plan = unbound_receipt.get("plan", {})
    targets = plan.get("targets", [])
    require(plan.get("schema") == "vnext-t2-r20-unbound-cleanup-plan-r1" and
            plan.get("complete") is True and
            any(item.get("pid") == orphan[0] and
                item.get("create_time_100ns") == orphan[1] and
                item.get("provenance") in {
                    "observed_generation",
                    "live_descendant_of_exact_observed_generation"}
                for item in targets) and
            registry.opened == [orphan] and sent == [orphan] and
            state["snapshot"] is clean and
            unbound_receipt.get("post_cleanup_confirmation", {}).get("complete") is True,
            "R20 failed to bind, clean, and confirm only the exact unbound orphan generation")
    signal_rows = unbound_receipt.get("signal_attempts", [])
    require(any(item.get("identity") == {
                    "pid": orphan[0], "create_time_100ns": orphan[1]} and
                item.get("receipt", {}).get("complete") is True
                for item in signal_rows),
            "R20 omitted exact signal/wait receipt for its unbound orphan cleanup")
    positives.append("R20 cleanup binds and confirms an incomplete-record orphan by exact PID+FILETIME")

    reused = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (orphan[0], orphan[1] + 1, 4, "reused-unrelated.exe"),
    ])
    reused_audit, reused_receipt, reused_registry, reused_sent, reused_state = cleanup_case(
        reused, signal_exact=None)
    reused_unbound = (reused_receipt or {}).get("unbound_cleanup", {})
    reused_plan = reused_unbound.get("plan", {})
    unresolved = reused_plan.get("unresolved", [])
    require(reused_audit.get("complete") is False and
            reused_plan.get("complete") is False and
            any(item.get("pid") == orphan[0] and
                item.get("expected_create_time_100ns") == orphan[1] and
                item.get("observed_create_time_100ns") == orphan[1] + 1
                for item in unresolved) and
            reused_registry.opened == [] and reused_sent == [] and
            reused_state["snapshot"] is reused and
            reused_unbound.get("complete") is False,
            "R20 cleanup signalled or accepted a reused PID generation")
    controls.append({"name": "R20 incomplete failed-open closure is cleanup-visible; PID reuse is never signalled",
                     "status": "pass", "rejected_as": "unresolved_monitor_incomplete"})
    return {"positive_count": 1, "negative_count": 1,
            "incomplete_failed_open_closure_is_cleanup_visible": True,
            "exact_generation_cleanup_confirmed": True,
            "pid_reuse_never_signalled": True}


def verify_r21_controller_tracked_exit_delta(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r20_r21_tracked_sample_exit_delta")
    r20_pin = receipt(R20_CONTROLLER)
    controller_source = R21_CONTROLLER.read_text(encoding="utf-8")
    controller_pin = receipt(R21_CONTROLLER)
    require(inputs.get(controller_pin["path"]) == controller_pin,
            "historical R21 controller is outside exact current input closure")
    expected = ["_r20_native_sample", "_r21_audit_tracked_sample_exit_races",
        "_r21_confirm_tracked_sample_exit", "_r23_audit_and_cleanup",
        "_r23_final_audit", "run_phase", "verify_protocol"]
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-r20-r21-tracked-sample-exit-delta-r1" and
            delta.get("r20_source") == r20_pin and
            delta.get("r21_source") == controller_pin and
            delta.get("changed_top_level_functions") == expected and
            delta.get("changed_top_level_assignments") == ["R21_CONTROLLER_RELATIVE_PATH"] and
            delta.get("r20_unbound_lane_ast_identical") is True and
            delta.get("tracked_exit_receipt_bound_to_phase_root_and_historical_set") is True and
            delta.get("exact_three_complete_absence_snapshots_and_subtree_closure") is True and
            delta.get("partial_sample_credit_bytes") == 0 and
            delta.get("exit_credit") is False and
            delta.get("coverage_thresholds_changed") is False and
            delta.get("resource_limits_changed") is False,
            "R20-to-R21 source delta is missing or widens tracked-exit recovery")
    old = {node.name: ast.dump(node, include_attributes=False)
           for node in ast.parse(R20_CONTROLLER.read_text(encoding="utf-8")).body
           if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_tree = ast.parse(controller_source)
    new = {node.name: ast.dump(node, include_attributes=False)
           for node in new_tree.body if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    observed = sorted(name for name in old.keys() | new.keys()
                      if old.get(name) != new.get(name))
    require(observed == expected, "R20-to-R21 exact AST delta differs from pinned allowlist")
    sample_node = next(node for node in new_tree.body
                       if isinstance(node, ast.FunctionDef) and node.name == "_r20_native_sample")
    audit_node = next(node for node in new_tree.body
                      if isinstance(node, ast.FunctionDef) and node.name == "_r23_final_audit")
    require(any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
                "_r21_confirm_tracked_sample_exit" for node in ast.walk(sample_node)) and
            any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
                "_r21_audit_tracked_sample_exit_races" for node in ast.walk(audit_node)),
            "R21 typed tracked-exit recovery is not connected to sample and final audit")
    def assignments(tree: ast.Module) -> dict[str, str]:
        rows = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                rows[node.targets[0].id] = ast.dump(node, include_attributes=False)
        return rows
    old_assignments = assignments(ast.parse(R20_CONTROLLER.read_text(encoding="utf-8")))
    new_assignments = assignments(new_tree)
    assignment_delta = sorted(name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    require(assignment_delta == ["R21_CONTROLLER_RELATIVE_PATH"],
            "R20-to-R21 module-level assignment delta is wider than the versioned path pin")
    r20_helpers = ["_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race", "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows", "_r20_valid_snapshot_receipt"]
    require(all(old.get(name) == new.get(name) for name in r20_helpers),
            "R21 changed the R20 unbound fail-closed helper AST")
    test = protocol.get("r21_tracked_sample_exit_python_controls")
    leaf = R21_TRACKED_EXIT_TEST_LEAF
    paths = {path.relative_to(leaf).as_posix(): receipt(path)
             for path in leaf.rglob("*") if path.is_file()}
    require(isinstance(test, dict) and
            test.get("schema") == "vnext-t2-r21-tracked-sample-exit-python-controls-r2" and
            test.get("status") == "pass_python_only" and
            test.get("leaf") == leaf.relative_to(ROOT).as_posix() and
            test.get("source") == receipt(R21_TRACKED_EXIT_TEST) and
            test.get("files") == paths and test.get("file_count") == 5 and
            test.get("exit_code") == 0 and test.get("positive_control_count") == 1 and
            test.get("negative_control_count") == 24 and
            test.get("julia_started") is False and
            test.get("formal_t2_accepted") is False and
            all(inputs.get(row["path"]) == row for row in paths.values()),
            "R21 focused test files are absent from exact current input closure")
    evidence = load(leaf / "evidence.json")
    command = json.loads((leaf / "command_argv.json").read_text(encoding="utf-8"))
    exit_text = (leaf / "exit_code.txt").read_text(encoding="utf-8").strip()
    stdout = (leaf / "stdout.raw").read_text(encoding="utf-8")
    before = evidence.get("source_pins_before", {})
    after = evidence.get("source_pins_after", {})
    positive = evidence.get("sample_controls", {}).get("positive", {})
    require(evidence.get("source_pins_unchanged") is True and before == after and
            isinstance(command, list) and len(command) == 5 and command[1] == "-B" and
            Path(command[2]).resolve() == R21_TRACKED_EXIT_TEST.resolve() and
            command[3:] == ["--output", leaf.relative_to(ROOT).as_posix()] and
            exit_text == "0" and
            before.get(R20_CONTROLLER.relative_to(ROOT).as_posix()) == r20_pin["sha256"] and
            before.get(R21_CONTROLLER.relative_to(ROOT).as_posix()) == controller_pin["sha256"] and
            evidence.get("positive_control_count") == 1 and
            evidence.get("negative_control_count") == 24 and
            evidence.get("julia_executed") is False and
            evidence.get("formal_t2_accepted") is False and
            positive.get("partial_rss_bytes_not_credited") == 7500 and
            positive.get("absence_snapshot_count") == 3 and
            positive.get("exact_exit_receipt_count") == 2 and
            "R21_TRACKED_SAMPLE_EXIT_TESTS=PASS" in stdout,
            "R21 raw Python output does not prove the bounded tracked-exit controls")
    return {"status": "pass", "changed_functions": observed,
            "positive_controls": 1, "negative_controls": 24,
            "formal_t2_accepted": False, "julia_executed": False}


def verify_r22_pre_tree_test_receipt(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    test = protocol.get("r22_pre_tree_tracked_exit_python_controls")
    leaf = R22_PRE_TREE_TEST_LEAF
    require(R22_PRE_TREE_TEST.is_file() and leaf.is_dir(),
            "R22 focused pre-tree test source or raw leaf is absent")
    paths = {path.relative_to(leaf).as_posix(): receipt(path)
             for path in leaf.rglob("*") if path.is_file()}
    expected_names = {"command_argv.json", "evidence.json", "exit_code.txt",
                      "stderr.raw", "stdout.raw"}
    require(set(paths) == expected_names and len(paths) == 5 and
            isinstance(test, dict) and
            test.get("schema") == "vnext-t2-r22-pre-tree-tracked-exit-python-controls-r1" and
            test.get("status") == "pass_python_only" and
            test.get("leaf") == leaf.relative_to(ROOT).as_posix() and
            test.get("source") == receipt(R22_PRE_TREE_TEST) and
            test.get("files") == paths and test.get("file_count") == 5 and
            test.get("exit_code") == 0 and test.get("positive_control_count") == 1 and
            test.get("negative_control_count") == 9 and
            test.get("formal_t2_accepted") is False and test.get("julia_started") is False and
            all(inputs.get(row["path"]) == row for row in paths.values()),
            "R22 focused pre-tree test raw files are not exactly pinned")
    evidence = load(leaf / "evidence.json")
    command = json.loads((leaf / "command_argv.json").read_text(encoding="utf-8"))
    stdout = (leaf / "stdout.raw").read_text(encoding="utf-8")
    stderr = (leaf / "stderr.raw").read_bytes()
    exit_text = (leaf / "exit_code.txt").read_text(encoding="utf-8").strip()
    controller_pin = receipt(CONTROLLER)
    validator_pin = receipt(PROJECTION_REUSE_VALIDATOR)
    source_before = evidence.get("source_pins_before", {})
    source_after = evidence.get("source_pins_after", {})
    expected_source_rows = {
        R20_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R20_CONTROLLER)["sha256"],
        R21_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R21_CONTROLLER)["sha256"],
        CONTROLLER.relative_to(ROOT).as_posix(): controller_pin["sha256"],
        R22_PRE_TREE_TEST.relative_to(ROOT).as_posix(): receipt(R22_PRE_TREE_TEST)["sha256"],
        PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(): validator_pin["sha256"],
        R23_TABLE.relative_to(ROOT).as_posix(): receipt(R23_TABLE)["sha256"],
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): receipt(R23_SUPERVISOR)["sha256"],
    }
    positive = evidence.get("positive_control", {})
    negatives = evidence.get("negative_controls", [])
    require(evidence.get("schema") == "independent-vnext-t2-r22-pre-tree-tracked-exit-tests-r1" and
            evidence.get("status") == "pass" and evidence.get("test_exit_code") == 0 and
            evidence.get("controller_path") == CONTROLLER.relative_to(ROOT).as_posix() and
            evidence.get("projection_validator") == {
                "path": validator_pin["path"], "sha256": validator_pin["sha256"],
                "accepted_protocol_schema": "vnext-t2-independent-negative-protocol-r10",
                "validation_receipt_schema": "vnext-t2-projection24-cross-run-validation-r10"} and
            evidence.get("positive_control_count") == 1 and
            evidence.get("negative_control_count") == 9 and
            evidence.get("python_executed") is True and evidence.get("julia_executed") is False and
            evidence.get("formal_t2_accepted") is False and
            evidence.get("source_pins_unchanged") is True and source_before == source_after and
            all(source_before.get(path) == digest
                for path, digest in expected_source_rows.items()) and
            isinstance(command, list) and evidence.get("exact_launcher_argv") == command and
            len(command) == 7 and command[1] == "-B" and
            Path(command[2]).resolve() == R22_PRE_TREE_TEST.resolve() and
            command[3] == "--output" and Path(command[4]).resolve() == leaf.resolve() and
            command[5] == "--controller" and
            Path(command[6]).resolve() == CONTROLLER.resolve() and
            exit_text == "0" and stderr == b"" and
            "R22_PRE_TREE_TRACKED_EXIT_TESTS=PASS" in stdout and
            positive.get("status") == "pass" and positive.get("sample_attempt_count") == 2 and
            positive.get("absence_snapshot_count") == 3 and
            positive.get("failed_attempt_resource_reads") == 0 and
            positive.get("final_audit_complete") is True and
            positive.get("target_opened_for_sampling") is False and
            positive.get("retired_generation_count") == 1 and
            isinstance(negatives, list) and len(negatives) == 9 and
            all(row.get("status") == "pass" for row in negatives),
            "R22 raw positive/negative controls or exact R12 source pins are invalid")
    for source_path, digest in expected_source_rows.items():
        pin = inputs.get(source_path)
        require(pin is not None and pin.get("sha256") == digest,
                f"R22 test source pin is outside current closure: {source_path}")
    return {"status": "pass", "positive_controls": 1,
            "negative_controls": 9, "r12_consumer_pinned": True,
            "formal_t2_accepted": False, "julia_executed": False}


def verify_r22_windows_host_smoke(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    host = protocol.get("r22_windows_host_smoke")
    launcher = protocol.get("r22_windows_host_smoke_launcher")
    require(isinstance(host, dict) and
            host.get("schema") ==
                "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2" and
            host.get("status") == "pass_windows_host_smoke_only" and
            host.get("leaf") == R22_HOST_SMOKE_LEAF.relative_to(ROOT).as_posix() and
            host.get("exit_code") == 0 and
            host.get("tracked_subtree_generation_count") == 2 and
            host.get("pre_tree_recovery_and_final_cleanup_complete") is True and
            host.get("formal_t2_accepted") is False and
            host.get("julia_started") is False and
            host.get("independent_review") == {
                "status": "GO",
                "scope": "R3 Windows host smoke as a freezer input only",
                "basis": "root-confirmed independent raw R3 review",
                "formal_t2_execution_authorized": False,
                "review_artifact_pinned_in_repository": False,
            },
            "R3 Windows host-smoke receipt is absent or overclaims formal T2")
    require(R22_HOST_SMOKE_RUNNER.is_file() and
            R22_HOST_SMOKE_FIXTURE.is_file() and
            R22_HOST_SMOKE_QA_SNAPSHOT.is_file() and
            R22_HOST_SMOKE_LEAF.is_dir() and
            R22_HOST_SMOKE_LAUNCHER_LEAF.is_dir(),
            "R3 host-smoke source snapshot or raw leaves are absent")

    def exact_input(path: Path) -> dict[str, Any]:
        row = receipt(path)
        require(inputs.get(row["path"]) == row,
                f"R3 host-smoke source/raw file is outside current closure: {row['path']}")
        return row

    snapshot_pin = exact_input(R22_HOST_SMOKE_QA_SNAPSHOT)
    require(snapshot_pin["bytes"] == R22_HOST_SMOKE_QA_SNAPSHOT_BYTES and
            snapshot_pin["sha256"] == R22_HOST_SMOKE_QA_SNAPSHOT_SHA256,
            "R3 host source does not retain the exact pre-host QA snapshot")
    current_qa_pin = inputs.get(Path(__file__).resolve().relative_to(ROOT).as_posix())
    require(current_qa_pin == receipt(Path(__file__).resolve()),
            "live static QA input pin is missing or stale")

    inner_paths = sorted(path for path in R22_HOST_SMOKE_LEAF.rglob("*")
                         if path.is_file())
    inner_files = {path.relative_to(R22_HOST_SMOKE_LEAF).as_posix(): path
                   for path in inner_paths}
    required_inner = {"command_argv.json", "stdout.raw", "stderr.raw",
                      "exit_code.json", "manifest.json", "phase/phase.json",
                      "phase/samples.jsonl", "phase/stdout.raw", "phase/stderr.raw",
                      "phase/target_natural_exit.json",
                      "phase/target_parent_wait.json", "phase/root_natural_exit.json"}
    require(required_inner.issubset(inner_files),
            "R3 inner host-smoke recursive inventory is incomplete")
    inner_rows = {relative: exact_input(path)
                  for relative, path in sorted(inner_files.items())}
    require(host.get("files") == inner_rows and
            host.get("file_count") == len(inner_rows),
            "R3 inner host-smoke file receipts differ from current raw bytes")
    payload_bytes = inner_files["stdout.raw"].read_bytes()
    payload = json.loads(payload_bytes.decode("utf-8"))
    command = load(R22_HOST_SMOKE_LEAF / "command_argv.json")
    exit_receipt = load(R22_HOST_SMOKE_LEAF / "exit_code.json")
    manifest = load(R22_HOST_SMOKE_LEAF / "manifest.json")
    phase_report = load(R22_HOST_SMOKE_LEAF / "phase/phase.json")
    manifest_rows = []
    for relative, path in sorted(inner_files.items()):
        if relative == "manifest.json":
            continue
        data = path.read_bytes()
        manifest_rows.append({"path": relative, "bytes": len(data),
                              "sha256": hashlib.sha256(data).hexdigest()})
    require(manifest.get("schema") ==
                "vnext-t2-r22-pre-tree-tracked-exit-host-manifest-r2" and
            manifest.get("complete") is True and
            manifest.get("top_level_schema") == payload.get("schema") and
            manifest.get("files") == manifest_rows and
            manifest.get("source_pins_before") ==
                manifest.get("source_pins_after") and
            manifest.get("formal_t2_accepted") is False and
            manifest.get("julia_started") is False,
            "R3 inner manifest does not close the exact host-smoke files")

    static_qa_host_pin = {
        "path": Path(__file__).resolve().relative_to(ROOT).as_posix(),
        "bytes": snapshot_pin["bytes"],
        "sha256": snapshot_pin["sha256"],
    }
    expected_pins = {
        "runner": exact_input(R22_HOST_SMOKE_RUNNER),
        "fixture": exact_input(R22_HOST_SMOKE_FIXTURE),
        "controller": exact_input(CONTROLLER),
        "projection_validator": exact_input(PROJECTION_REUSE_VALIDATOR),
        "native_process_table": exact_input(R23_TABLE),
        "supervisor": exact_input(R23_SUPERVISOR),
        "static_qa": static_qa_host_pin,
        "focused_python_controls": exact_input(R22_PRE_TREE_TEST),
    }
    expected_external_pins = {
        row["path"]: row for row in expected_pins.values()}
    require(len(expected_pins) == 8 and len(expected_external_pins) == 8 and
            all(set(row) == {"path", "bytes", "sha256"} and
                row.get("path") == path
                for path, row in expected_external_pins.items()),
            "R3 external source pins are not eight unique exact receipts")
    pins_before = payload.get("source_pins_before")
    pins_after = payload.get("source_pins_after")
    argv = command.get("argv")
    require(payload.get("schema") ==
                "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2" and
            payload.get("source_pins_stable") is True and
            pins_before == expected_pins and pins_after == expected_pins and
            exit_receipt.get("exit_code") == 0 and
            exit_receipt.get("status") == "pass_python_only" and
            exit_receipt.get("source_pins_before") == expected_pins and
            exit_receipt.get("source_pins_after") == expected_pins and
            command.get("kind") ==
                "python_only_r22_pre_tree_tracked_exit_host_smoke_r2" and
            command.get("phase_timeout_seconds") == 30.0 and
            command.get("working_set_limit_bytes") == 2_147_483_648 and
            command.get("formal_t2_accepted") is False and
            command.get("julia_started") is False and
            isinstance(argv, list) and len(argv) == 9 and argv[1] == "-B" and
            Path(argv[2]).resolve() == R22_HOST_SMOKE_RUNNER.resolve() and
            argv[3] == "--output" and
            Path(argv[4]).resolve() == R22_HOST_SMOKE_LEAF.resolve() and
            argv[5] == "--controller-sha256" and
            argv[6] == expected_pins["controller"]["sha256"] and
            argv[7] == "--validator-sha256" and
            argv[8] == expected_pins["projection_validator"]["sha256"] and
            manifest.get("source_pins_before") == expected_pins and
            manifest.get("source_pins_after") == expected_pins and
            payload.get("formal_t2_accepted") is False and
            payload.get("julia_started") is False,
            "R3 inner host-smoke status, command, or eight source pins are invalid")

    verified = payload.get("verified_race", {})
    def empty_global_heavy_audit(value: Any) -> bool:
        return isinstance(value, dict) and \
            value.get("schema") == "vnext-t2-r23-global-heavy-audit-r1" and \
            value.get("complete") is True and \
            all(value.get(field) == [] for field in
                ("processes", "controller_processes",
                 "native_heavy_identities", "errors")) and \
            value.get("snapshot", {}).get("complete") is True

    phase_tree = phase_report.get("final_process_tree_audit", {})
    phase_residual = phase_tree.get("residual_process_audit", {})
    require(empty_global_heavy_audit(phase_report.get("residual_process_audit")) and
            empty_global_heavy_audit(
                phase_tree.get("global_heavy_process_audit")) and
            phase_tree.get("schema") ==
                "vnext-t2-r23-final-process-tree-audit-r1" and
            phase_tree.get("complete") is True and phase_tree.get("errors") == [] and
            phase_tree.get("root_exit_confirmed") is True and
            phase_tree.get("root_identity_absent") is True and
            phase_tree.get("residual_descendant_processes") == [] and
            phase_tree.get("tracked_pid_reuse") == [] and
            phase_tree.get("snapshot", {}).get("complete") is True and
            phase_residual.get("schema") ==
                "native-g1g2-r23-residual-audit-v1" and
            phase_residual.get("complete") is True and
            phase_residual.get("residual_clear") is True and
            phase_residual.get("residual_exact_identities") == [] and
            phase_residual.get("expected_identity_count") == 4,
            "R3 phase/global/final residual audits are not complete and empty")
    phase_r20 = phase_tree.get("unbound_observation_final_audit", {})
    phase_r21 = phase_tree.get("tracked_sample_exit_final_audit", {})
    phase_r22 = phase_tree.get("pre_tree_tracked_exit_final_audit", {})
    require(phase_r20.get("complete") is True and phase_r20.get("errors") == [] and
            phase_r20.get("observed_unbound_generations") == [] and
            phase_r20.get("orphan_descendants") == [] and
            phase_r20.get("residual_observed_generations") == [] and
            phase_r21.get("complete") is True and phase_r21.get("errors") == [] and
            phase_r21.get("residual_retired_generations") == [] and
            phase_r22.get("complete") is True and phase_r22.get("errors") == [] and
            phase_r22.get("residual_retired_generations") == [],
            "R3 R20/R21/R22 generation cleanup audits are incomplete")
    target = verified.get("target_identity", {})
    root = verified.get("root_identity", {})
    outer_source = verified.get("outer_reconcile_source", {})
    outer_row = outer_source.get("target_row", {})
    binding = verified.get("sample4_source_binding", {})
    subtree = verified.get("expected_tracked_subtree", [])
    exits = verified.get("exact_cached_generation_exits", [])
    absences = verified.get("three_post_wait_absence_receipts", [])
    pre_tree_audit = verified.get("pre_tree_final_audit", {})
    def identity_key(value: Any) -> tuple[int, int]:
        require(isinstance(value, dict) and type(value.get("pid")) is int and
                value.get("pid") > 0 and
                type(value.get("create_time_100ns")) is int and
                value.get("create_time_100ns") > 0,
                "R3 exact PID/FILETIME generation row is malformed")
        return value["pid"], value["create_time_100ns"]
    subtree_keys = [identity_key(value) for value in subtree]
    exit_keys = [identity_key(value.get("identity")) for value in exits]
    retired_keys = [identity_key(value) for value in
                    pre_tree_audit.get("retired_tracked_identities", [])]
    closed_keys = [identity_key(value) for value in
                   verified.get("target_handle_close_receipt", {}).get(
                       "closed_owned_handles", [])]
    source_receipt = outer_source.get("receipt")
    require(type(root.get("pid")) is int and type(root.get("create_time_100ns")) is int and
            identity_key(target) in subtree_keys and target.get("pid") != root.get("pid") and
            outer_source.get("unchanged_table_returned") is True and
            outer_row.get("pid") == target.get("pid") and
            outer_row.get("create_time_100ns") == target.get("create_time_100ns") and
            outer_row.get("ppid") == root.get("pid") and
            outer_row.get("create_time_100ns") > root.get("create_time_100ns") and
            outer_source.get("target_natural_exit_receipt", {}).get("natural_exit") is True and
            outer_source.get("target_natural_exit_receipt", {}).get("pid") == target.get("pid") and
            outer_source.get("parent_wait_receipt", {}).get("target_pid") == target.get("pid") and
            outer_source.get("parent_wait_receipt", {}).get("parent_reaped_target") is True and
            outer_source.get("parent_wait_receipt", {}).get("wait_exit_code") == 0 and
            binding.get("different_snapshot_objects") is True and
            binding.get("previous_accepted_sample_index") == 3 and
            binding.get("previous_accepted_source_receipt") == source_receipt and
            binding.get("outer_reconcile_source_receipt") == source_receipt and
            binding.get("target_identity") == target and
            verified.get("failed_inner_source", {}).get(
                "root_present_target_absent") is True and
            verified.get("failed_inner_source", {}).get("receipt", {}).get(
                "complete") is True and
            len(subtree_keys) == 2 and len(set(subtree_keys)) == 2 and
            len(exits) == 2 and len(exit_keys) == 2 and
            set(exit_keys) == set(subtree_keys) and
            all(item.get("complete") is True and item.get("wait_confirmed") is True and
                item.get("identity") == item.get("handle_identity_before_wait") ==
                    item.get("handle_identity_after_wait") and
                type(item.get("exit_code")) is int and item.get("exit_code") != 259 and
                item.get("errors") == [] and
                item.get("exit_code_credit_issued") is False for item in exits) and
            len(absences) == 3 and
            all(item.get("complete") is True and
                item.get("schema") == "vnext-t2-r23-native-snapshot-receipt-r1" and
                item.get("query_attempts") == 1 for item in absences) and
            len(verified.get("three_complete_live_samples", [])) == 3 and
            [row.get("sample_index") for row in
             verified.get("three_complete_live_samples", [])] == [1, 2, 3] and
            all(row.get("snapshot", {}).get("complete") is True and
                row.get("target_identity") == target for row in
                verified.get("three_complete_live_samples", [])) and
            verified.get("attempt_one_zero_credit", {}).get("rss_credit_bytes") == 0 and
            verified.get("attempt_one_zero_credit", {}).get(
                "cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            verified.get("attempt_one_zero_credit", {}).get(
                "exit_code_credit_issued") is False and
            verified.get("fresh_full_sample_attempt", {}).get("started") is True and
            verified.get("fresh_full_sample_attempt", {}).get("attempt_index") == 2 and
            verified.get("fresh_full_sample_attempt", {}).get("completed") is True and
            verified.get("fresh_full_sample_attempt", {}).get(
                "retry_source_absent_target") is True and
            pre_tree_audit.get("schema") ==
                "vnext-t2-r22-pre-tree-tracked-exit-final-audit-r1" and
            pre_tree_audit.get("complete") is True and
            pre_tree_audit.get("errors") == [] and
            set(retired_keys) == set(subtree_keys) and len(retired_keys) == 2 and
            pre_tree_audit.get("residual_retired_generations") == [] and
            verified.get("target_handle_close_receipt", {}).get("complete") is True and
            verified.get("target_handle_close_receipt", {}).get("errors") == [] and
            set(subtree_keys).issubset(closed_keys) and
            verified.get("phase_exit", {}).get("stop_reason") == "natural_exit" and
            verified.get("phase_exit", {}).get("exit_code") == 0 and
            type(verified.get("phase_exit", {}).get("seconds")) in (int, float) and
            not isinstance(verified.get("phase_exit", {}).get("seconds"), bool) and
            verified.get("phase_exit", {}).get("seconds", 10**9) <= 30.0 and
            verified.get("phase_exit", {}).get("timeout_seconds") == 30.0 and
            verified.get("phase_exit", {}).get("stderr_bytes") == 0 and
            verified.get("phase_exit", {}).get("working_set_limit_bytes") ==
                2_147_483_648 and
            verified.get("final_process_tree_audit", {}).get("complete") is True and
            verified.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [],
            "R3 host evidence does not close the exact two-generation pre-tree recovery")

    resource_reads = verified.get("resource_reads", [])
    reads_by_sample = {
        sample_index: [row for row in resource_reads
                       if row.get("sample_index") == sample_index]
        for sample_index in (1, 2, 3, 4)}
    subtree_pids = {pid for pid, _ticks in subtree_keys}
    baseline_pid_sets = [
        {row.get("pid") for row in reads_by_sample[index]}
        for index in (1, 2, 3)]
    registry_calls = verified.get("target_registry_open_calls", [])
    require(len(resource_reads) == 14 and
            all(len(reads_by_sample[index]) == 4 and
                len({row.get("pid") for row in reads_by_sample[index]}) == 4 and
                all(row.get("after_race_boundary") is False
                    for row in reads_by_sample[index])
                for index in (1, 2, 3)) and
            baseline_pid_sets[0] == baseline_pid_sets[1] == baseline_pid_sets[2] and
            subtree_pids.issubset(baseline_pid_sets[0]) and
            root["pid"] in baseline_pid_sets[0] and
            len(reads_by_sample[4]) == 2 and
            {row.get("pid") for row in reads_by_sample[4]} ==
                baseline_pid_sets[0] - subtree_pids and
            all(row.get("after_race_boundary") is True
                for row in reads_by_sample[4]) and
            not any(row.get("pid") in subtree_pids and
                    row.get("after_race_boundary") is True
                    for row in resource_reads) and
            len(registry_calls) == 3 and
            [row.get("sample_index") for row in registry_calls] == [1, 2, 3] and
            all(row.get("identity") == target and
                row.get("after_race_boundary") is False for row in registry_calls) and
            [row.get("opened_by_registry") for row in registry_calls] ==
                [True, False, False] and
            [row.get("already_cached") for row in registry_calls] ==
                [False, True, True],
            "R3 resource reads or target registry calls crossed the race boundary")

    outer_paths = sorted(path for path in R22_HOST_SMOKE_LAUNCHER_LEAF.rglob("*")
                         if path.is_file())
    outer_files = {path.relative_to(R22_HOST_SMOKE_LAUNCHER_LEAF).as_posix(): path
                   for path in outer_paths}
    outer_rows = {relative: exact_input(path)
                  for relative, path in sorted(outer_files.items())}
    required_outer = {"command_argv.json", "outer_command_argv.json", "stdout.raw",
                      "stderr.raw", "external_exit_receipt.json", "launch_host.ps1",
                      "processes_before.json", "processes_after.json",
                      "pre_host_static_qa_r22.py", "root_manifest.json"}
    require(required_outer.issubset(outer_files),
            "R3 external launcher inventory is incomplete")
    outer_command = json.loads(
        outer_files["command_argv.json"].read_text(encoding="utf-8"))
    process_command = json.loads(
        outer_files["outer_command_argv.json"].read_text(encoding="utf-8"))
    external = load(R22_HOST_SMOKE_LAUNCHER_LEAF / "external_exit_receipt.json")
    root_manifest = load(R22_HOST_SMOKE_LAUNCHER_LEAF / "root_manifest.json")
    inner_exit_pin = receipt(R22_HOST_SMOKE_LEAF / "exit_code.json")
    inner_manifest_pin = receipt(R22_HOST_SMOKE_LEAF / "manifest.json")
    expected_manifest_rows = []
    for relative, path in sorted(outer_files.items()):
        if relative == "root_manifest.json":
            continue
        data = path.read_bytes()
        expected_manifest_rows.append({"path": relative, "bytes": len(data),
                                       "sha256": hashlib.sha256(data).hexdigest()})
    manifest_files = root_manifest.get("files")
    names = [row.get("path") for row in manifest_files
             if isinstance(row, dict)] if isinstance(manifest_files, list) else []
    outer_stdout = outer_files["stdout.raw"].read_bytes()
    outer_stderr = outer_files["stderr.raw"].read_bytes()
    before_processes = json.loads(
        outer_files["processes_before.json"].read_text(encoding="utf-8"))
    after_processes = json.loads(
        outer_files["processes_after.json"].read_text(encoding="utf-8"))
    require(isinstance(launcher, dict) and
            launcher.get("schema") == "vnext-t2-r22-host-smoke-launcher-exit-r1" and
            launcher.get("status") == "pass_external_windows_python_only" and
            launcher.get("leaf") ==
                R22_HOST_SMOKE_LAUNCHER_LEAF.relative_to(ROOT).as_posix() and
            launcher.get("files") == outer_rows and
            launcher.get("file_count") == len(outer_rows) and
            launcher.get("manifest_schema") ==
                "vnext-t2-r22-host-smoke-launcher-manifest-r1" and
            launcher.get("manifest") == outer_rows.get("root_manifest.json") and
            launcher.get("exit_code") == 0 and
            launcher.get("formal_t2_accepted") is False and
            launcher.get("julia_started") is False and
            root_manifest.get("schema") ==
                "vnext-t2-r22-host-smoke-launcher-manifest-r1" and
            names == [row["path"] for row in expected_manifest_rows] and
            manifest_files == expected_manifest_rows and
            set(outer_files) == set(names) | {"root_manifest.json"} and
            root_manifest.get("inner_manifest_ref") == inner_manifest_pin and
            root_manifest.get("formal_t2_accepted") is False and
            root_manifest.get("julia_started") is False and
            external.get("schema") == "vnext-t2-r22-host-smoke-launcher-exit-r1" and
            external.get("exit_code") == 0 and
            external.get("status") == "pass_python_only" and
            external.get("source_pins_unchanged") is True and
            external.get("source_pins_before") == expected_external_pins and
            external.get("source_pins_after") == expected_external_pins and
            external.get("stdout") == outer_rows["stdout.raw"] and
            external.get("stderr") == outer_rows["stderr.raw"] and
            external.get("inner_exit_code") == inner_exit_pin and
            external.get("inner_manifest") == inner_manifest_pin and
            external.get("outer_stdout_equals_inner_payload") is True and
            external.get("inner_self_report_exit_code") == 0 and
            external.get("outer_timeout") is False and
            external.get("outer_timeout_seconds") == 45 and
            external.get("processes_after_count") == 0 and
            type(external.get("wall_seconds")) in (int, float) and
            not isinstance(external.get("wall_seconds"), bool) and
            0 <= external.get("wall_seconds") < 45 and
            external.get("launcher_mode") == "powershell_dotnet_direct_cli" and
            outer_command == command.get("argv") and outer_stdout == payload_bytes and
            outer_stderr == b"" and before_processes == [] and after_processes == [] and
            isinstance(process_command, list) and len(process_command) == 6 and
            Path(process_command[0]).name.lower() == "pwsh.exe" and
            process_command[1:5] == ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"] and
            Path(process_command[5]).resolve() ==
                (R22_HOST_SMOKE_LAUNCHER_LEAF / "launch_host.ps1").resolve(),
            "R3 external launcher receipt, OS exit, streams, or live inventory is invalid")
    invocation = verify_r22_host_smoke_invocation(protocol, inputs, launcher)
    return {"status": "pass", "inner_status": host["status"],
            "external_status": launcher["status"], "source_pin_count": 8,
            "tracked_subtree_generation_count": 2,
            "outer_manifest_member_count": len(manifest_files),
            "outer_powershell_invocation": invocation,
            "formal_t2_accepted": False, "julia_executed": False}


def verify_r22_host_smoke_invocation(
        protocol: dict[str, Any], inputs: dict[str, Any],
        launcher: dict[str, Any]) -> dict[str, Any]:
    leaf = R22_HOST_SMOKE_INVOCATION_LEAF
    require(leaf.is_dir(), "R3 outer PowerShell invocation leaf is absent")
    paths = sorted(path for path in leaf.rglob("*") if path.is_file())
    files = {path.relative_to(leaf).as_posix(): path for path in paths}
    expected_names = {"command_argv.json", "os_exit_receipt.json",
                      "powershell.stdout.raw", "powershell.stderr.raw"}
    require(set(files) == expected_names,
            "R3 PowerShell invocation raw inventory changed")
    rows = {}
    for relative, path in sorted(files.items()):
        pin = receipt(path)
        require(inputs.get(pin["path"]) == pin,
                f"R3 invocation raw file is outside current closure: {pin['path']}")
        rows[relative] = pin
    command = json.loads(files["command_argv.json"].read_text(encoding="utf-8"))
    os_receipt = load(leaf / "os_exit_receipt.json")
    stdout = files["powershell.stdout.raw"].read_bytes()
    stderr = files["powershell.stderr.raw"].read_bytes()
    summary = json.loads(stdout.decode("utf-8"))
    launcher_path = R22_HOST_SMOKE_LAUNCHER_LEAF / "launch_host.ps1"
    launcher_pin = receipt(launcher_path)
    require(inputs.get(launcher_pin["path"]) == launcher_pin and
            launcher.get("files", {}).get("launch_host.ps1") == launcher_pin,
            "R3 PowerShell launcher is not pinned by the outer raw inventory")
    outer_command = json.loads((R22_HOST_SMOKE_LAUNCHER_LEAF /
                                "outer_command_argv.json").read_text(encoding="utf-8"))
    external_receipt_pin = launcher.get("external_exit_receipt")
    require(os_receipt.get("schema") == "root-powershell-host-smoke-invocation-r3" and
            os_receipt.get("actual_powershell_os_exit") == 0 and
            os_receipt.get("invocation_timeout") is False and
            os_receipt.get("launcher_source_unchanged") is True and
            launcher_pin["sha256"] == R22_HOST_SMOKE_LAUNCHER_SHA256 and
            os_receipt.get("launcher_sha_before") ==
                R22_HOST_SMOKE_LAUNCHER_SHA256 and
            os_receipt.get("launcher_sha_after") ==
                R22_HOST_SMOKE_LAUNCHER_SHA256 and
            os_receipt.get("launcher_sha_expected") ==
                R22_HOST_SMOKE_LAUNCHER_SHA256 and
            os_receipt.get("command_argv") == command == outer_command and
            isinstance(command, list) and len(command) == 6 and
            Path(command[0]).name.lower() == "pwsh.exe" and
            command[1:5] == ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"] and
            Path(command[5]).resolve() == launcher_path.resolve() and
            rows["powershell.stdout.raw"]["sha256"] ==
                os_receipt.get("stdout_sha256") and
            rows["powershell.stderr.raw"]["sha256"] ==
                os_receipt.get("stderr_sha256") and stderr == b"" and
            isinstance(external_receipt_pin, dict) and
            summary.get("actual_os_exit") == 0 and
            summary.get("status") == "pass_python_only" and
            summary.get("source_pins_stable") is True and
            summary.get("stdout_identical") is True and
            summary.get("processes_after") == 0 and
            summary.get("external_receipt_sha256") ==
                external_receipt_pin.get("sha256") and
            os_receipt.get("formal_t2_accepted") is False and
            os_receipt.get("julia_started") is False and
            launcher.get("formal_t2_accepted") is False and
            launcher.get("julia_started") is False and
            type(os_receipt.get("wall_seconds")) in (int, float) and
            not isinstance(os_receipt.get("wall_seconds"), bool) and
            0 <= os_receipt.get("wall_seconds") < 45,
            "R3 PowerShell OS exit, timeout, source, or raw-stream evidence is invalid")
    protocol_receipt = protocol.get("r22_windows_host_smoke_invocation")
    require(isinstance(protocol_receipt, dict) and
            protocol_receipt.get("schema") ==
                "vnext-t2-r22-host-smoke-invocation-r3" and
            protocol_receipt.get("raw_schema") ==
                "root-powershell-host-smoke-invocation-r3" and
            protocol_receipt.get("status") ==
                "pass_outer_powershell_invocation_only" and
            protocol_receipt.get("leaf") == leaf.relative_to(ROOT).as_posix() and
            protocol_receipt.get("files") == rows and
            protocol_receipt.get("file_count") == len(rows) and
            protocol_receipt.get("command") == rows["command_argv.json"] and
            protocol_receipt.get("os_exit_receipt") ==
                rows["os_exit_receipt.json"] and
            protocol_receipt.get("stdout") == rows["powershell.stdout.raw"] and
            protocol_receipt.get("stderr") == rows["powershell.stderr.raw"] and
            protocol_receipt.get("actual_powershell_os_exit") == 0 and
            protocol_receipt.get("invocation_timeout") is False and
            protocol_receipt.get("launcher_sha256") == launcher_pin["sha256"] and
            protocol_receipt.get("external_receipt_sha256") ==
                external_receipt_pin.get("sha256") and
            protocol_receipt.get("formal_t2_accepted") is False and
            protocol_receipt.get("julia_started") is False,
            "R3 PowerShell invocation receipt does not bind its raw files")
    return {"status": "pass", "actual_powershell_os_exit": 0,
            "invocation_timeout": False, "launcher_sha256": launcher_pin["sha256"],
            "file_count": len(rows), "formal_t2_accepted": False,
            "julia_executed": False}


def verify_r22_controller_pre_tree_delta(
        protocol: dict[str, Any], inputs: dict[str, Any],
        controller_source: str, controller_pin: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r21_r22_pre_tree_tracked_exit_delta")
    old_tree = ast.parse(R21_CONTROLLER.read_text(encoding="utf-8"))
    new_tree = ast.parse(controller_source)
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in old_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in new_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    observed = sorted(name for name in old_functions.keys() | new_functions.keys()
                      if old_functions.get(name) != new_functions.get(name))
    expected = ["_r20_native_sample", "_r22_audit_pre_tree_tracked_exit_races",
        "_r22_confirm_pre_tree_tracked_exit", "_r22_snapshot_bundle",
        "_r22_snapshot_from_bundle", "_r22_tracked_closure",
        "_r23_audit_and_cleanup", "_r23_final_audit", "run_phase",
        "verify_protocol"]
    def assignments(tree: ast.Module) -> dict[str, str]:
        return {node.targets[0].id: ast.dump(node, include_attributes=False)
                for node in tree.body if isinstance(node, ast.Assign) and
                len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)}
    old_assignments, new_assignments = assignments(old_tree), assignments(new_tree)
    assignment_delta = sorted(name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    expected_assignments = ["PROJECTION_REUSE_VALIDATOR",
                            "R21_CONTROLLER_RELATIVE_PATH",
                            "R22_CONTROLLER_RELATIVE_PATH"]
    r21_pin = receipt(R21_CONTROLLER)
    r20_tree = ast.parse(R20_CONTROLLER.read_text(encoding="utf-8"))
    r20_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in r20_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    preserved_r20 = ["_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race", "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows", "_r20_valid_snapshot_receipt"]
    preserved_r21 = ["_r21_audit_tracked_sample_exit_races",
                     "_r21_confirm_tracked_sample_exit"]
    test_receipt = protocol.get("r22_pre_tree_tracked_exit_python_controls")
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-r21-r22-pre-tree-tracked-exit-delta-r1" and
            delta.get("r21_source") == r21_pin and delta.get("r22_source") == controller_pin and
            observed == expected and delta.get("changed_top_level_functions") == expected and
            assignment_delta == expected_assignments and
            delta.get("changed_top_level_assignments") == expected_assignments and
            all(r20_functions.get(name) == new_functions.get(name) for name in preserved_r20) and
            all(old_functions.get(name) == new_functions.get(name) for name in preserved_r21) and
            delta.get("r20_unbound_lane_ast_identical") is True and
            delta.get("r21_tracked_exit_lane_ast_identical") is True and
            delta.get("prior_and_outer_exact_source_closure_required") is True and
            delta.get("failed_first_sample_target_absence_required") is True and
            delta.get("same_cached_handle_natural_exit_and_three_absences_required") is True and
            delta.get("partial_sample_credit_bytes") == 0 and
            delta.get("exit_credit") is False and
            delta.get("full_whole_sample_retry_required") is True and
            delta.get("final_typed_audit_required") is True and
            delta.get("coverage_thresholds_changed") is False and
            delta.get("resource_limits_changed") is False and
            isinstance(test_receipt, dict) and test_receipt.get("status") == "pass_python_only",
            "R21-to-R22 typed pre-tree lane delta or preserved gates differ")
    sample = next(node for node in new_tree.body
                  if isinstance(node, ast.FunctionDef) and node.name == "_r20_native_sample")
    audit = next(node for node in new_tree.body
                 if isinstance(node, ast.FunctionDef) and node.name == "_r23_final_audit")
    require(any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
                "_r22_confirm_pre_tree_tracked_exit" for node in ast.walk(sample)) and
            any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
                "_r22_audit_pre_tree_tracked_exit_races" for node in ast.walk(audit)) and
            "validate_projection24_reuse_r12.py" in controller_source and
            protocol.get("schema") == "vnext-t2-independent-negative-protocol-r10" and
            protocol.get("controller_path") == controller_pin["path"] and
            inputs.get(controller_pin["path"]) == controller_pin,
            "R22 typed lane or r10/R12 consumer binding is not live")
    return {"status": "pass", "changed_functions": observed,
            "changed_assignments": assignment_delta,
            "r20_unbound_lane_ast_identical": True,
            "r21_tracked_exit_lane_ast_identical": True,
            "positive_controls": 1, "negative_controls": 9,
            "formal_t2_accepted": False, "julia_executed": False}


def verify_projection_reuse_validator_r10_r11_delta(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("projection24_reuse_validator_r10_r11_delta")
    old = R10_PROJECTION_REUSE_VALIDATOR.read_text(encoding="utf-8")
    new = R11_PROJECTION_REUSE_VALIDATOR.read_text(encoding="utf-8")
    old_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r8":'
    new_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":'
    r10_pin, r11_pin = receipt(R10_PROJECTION_REUSE_VALIDATOR), receipt(R11_PROJECTION_REUSE_VALIDATOR)
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-projection-reuse-validator-r10-r11-schema-delta-r1" and
            delta.get("r10_source") == r10_pin and delta.get("r11_source") == r11_pin and
            delta.get("only_change") ==
                "accept vnext-t2-independent-negative-protocol-r9 in the same top-level schema gate" and
            delta.get("all_projection_plan_and_receipt_assertions_unchanged") is True and
            old.count(old_gate) == 1 and new == old.replace(old_gate, new_gate, 1) and
            inputs.get(r10_pin["path"]) == r10_pin and inputs.get(r11_pin["path"]) == r11_pin and
            inputs.get(r11_pin["path"]) == r11_pin,
            "R10-to-R11 validator is not an exact schema-only r9 adaptation")
    return {"status": "pass", "changed_contract": "top-level protocol schema r8 to r9",
            "projection_reuse_assertions_changed": False}


def verify_projection_reuse_validator_r11_r12_delta(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("projection24_reuse_validator_r11_r12_delta")
    old = R11_PROJECTION_REUSE_VALIDATOR.read_text(encoding="utf-8")
    new = R12_PROJECTION_REUSE_VALIDATOR.read_text(encoding="utf-8")
    old_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":'
    new_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r10":'
    old_usage = "usage: validate_projection24_reuse_r10.py <protocol.json> <receipt.json>"
    new_usage = "usage: validate_projection24_reuse_r12.py <protocol.json> <receipt.json>"
    expected = old.replace(old_usage, new_usage, 1).replace(old_gate, new_gate, 1)
    r11_pin, r12_pin = receipt(R11_PROJECTION_REUSE_VALIDATOR), receipt(R12_PROJECTION_REUSE_VALIDATOR)
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-projection-reuse-validator-r11-r12-schema-delta-r1" and
            delta.get("r11_source") == r11_pin and delta.get("r12_source") == r12_pin and
            delta.get("only_changes") == [
                "accept vnext-t2-independent-negative-protocol-r10 in the same top-level schema gate",
                "version the CLI usage label to validate_projection24_reuse_r12.py"] and
            delta.get("all_projection_plan_source_input_hash_and_24_site_checks_unchanged") is True and
            old.count(old_usage) == 1 and old.count(old_gate) == 1 and new == expected and
            inputs.get(r11_pin["path"]) == r11_pin and inputs.get(r12_pin["path"]) == r12_pin and
            protocol.get("projection24_reuse_validator_path") == r12_pin["path"],
            "R11-to-R12 consumer delta is not an exact schema-only r10 adaptation")
    return {"status": "pass", "accepted_protocol_schema":
            "vnext-t2-independent-negative-protocol-r10",
            "projection_plan_input_hash_and_coverage_checks_changed": False}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--protocol-sha256", required=True)
    parser.add_argument("--dispatch", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    report_path = Path(args.report).resolve()
    report: dict[str, Any] = {
        "schema": "vnext-t2-independent-negative-static-qa-r22-r23",
        "status": "fail", "julia_executed": False,
        "formal_t2_accepted": False, "negative_controls": [],
    }
    try:
        require(__name__ == "__main__" and sys.dont_write_bytecode and
                Path(sys.argv[0]).resolve() == Path(__file__).resolve(),
                "static QA must run as a direct -B source entrypoint")
        protocol_path = Path(args.protocol).resolve()
        dispatch_path = Path(args.dispatch).resolve()
        command_path = Path(args.command).resolve()
        for path in (protocol_path, dispatch_path, command_path, report_path.parent):
            path.relative_to(ROOT)
        freeze_root = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()
        require(protocol_path.parent == dispatch_path.parent ==
                command_path.parent == report_path.parent and
                protocol_path.parent.parent == freeze_root and
                protocol_path.name == "protocol.json" and
                dispatch_path.name == "dispatch.json" and
                command_path.name == "command_argv.json" and
                report_path.name == "static_qa.json",
                "frozen protocol, dispatch, command, and QA report must share a direct runs leaf")
        protocol_bytes = protocol_path.read_bytes()
        require(sha(protocol_bytes) == args.protocol_sha256.lower(),
                "protocol SHA mismatch")
        protocol = load(protocol_path)
        dispatch = load(dispatch_path)
        command_data = load(command_path)
        require(protocol.get("schema") == "vnext-t2-independent-negative-protocol-r10" and
                protocol.get("formal_t2_accepted") is False and
                protocol.get("scientific_acceptance") is False and
                protocol.get("physical_acceptance") is False,
                "protocol schema or claim ceiling mismatch")
        inputs = protocol.get("inputs", {})
        current_rows = check_current_inputs(protocol)
        report["input_count"] = len(current_rows)
        report["projection24_reuse_validator_r10_r11_delta"] = \
            verify_projection_reuse_validator_r10_r11_delta(protocol, inputs)
        report["projection24_reuse_validator_r11_r12_delta"] = \
            verify_projection_reuse_validator_r11_r12_delta(protocol, inputs)
        report["authorized_v4_planning_migration"] = \
            verify_authorized_planning_migration(protocol, inputs)
        controller_pin = inputs.get(CONTROLLER.relative_to(ROOT).as_posix())
        require(controller_pin is not None and
                protocol.get("controller_path") == controller_pin["path"],
                "current R22 controller is outside the exact input closure")
        controller = load_source_module("t2_r22_current_controller", CONTROLLER,
                                        controller_pin)
        controller_source = CONTROLLER.read_text(encoding="utf-8")
        r20_pin = inputs.get(R20_CONTROLLER.relative_to(ROOT).as_posix())
        require(r20_pin is not None and inputs.get(r20_pin["path"]) == r20_pin,
                "historical R20 controller is outside the exact input closure")
        r20_source = R20_CONTROLLER.read_text(encoding="utf-8")
        r20_controller = load_source_module("t2_r20_historical_controller",
                                            R20_CONTROLLER, r20_pin)
        require("verify_baseline_heavy_processes_clear(baseline_heavy)" in
                controller_source and
                "verify_baseline_heavy_processes_clear(heavy)" in controller_source,
                "baseline/final trust boundaries do not share the strict audit predicate")

        coverage_pin = protocol.get("coverage_map")
        require(isinstance(coverage_pin, dict) and
                inputs.get(coverage_pin.get("path")) == coverage_pin,
                "coverage map is not self-bound into current inputs")
        coverage_path = ROOT / coverage_pin["path"]
        coverage = load(coverage_path)
        require(coverage_pin == receipt(coverage_path),
                "coverage map path/bytes/SHA pin drift")
        check_map_schema(coverage)
        excluded_map = protocol.get("r18_superseded_map_experiment_exclusion")
        expected_excluded = [receipt(path) for path in
                             R18_SUPERSEDED_MAP_EXPERIMENT_FILES]
        cleanup = protocol.get("r18_owned_temp_cleanup_receipt")
        require(isinstance(excluded_map, dict) and
                excluded_map.get("schema") ==
                    "vnext-t2-r18-superseded-map-experiment-exclusion-r1" and
                excluded_map.get("status") ==
                    "retained_on_disk_not_current_execution_input" and
                excluded_map.get("cleanup_attempt") == "blocked_by_tool_policy" and
                excluded_map.get("files") == expected_excluded and
                all(inputs.get(row["path"]) is None for row in expected_excluded) and
                excluded_map.get("current_coverage_map") == coverage_pin and
                excluded_map.get("current_coverage_map_schema") == coverage.get("schema") and
                excluded_map.get("not_referenced_by_runtime_command") is True and
                excluded_map.get("read_only_for_exact_exclusion_rehash") is True,
                "superseded map experiment exclusion is not exact")
        require(isinstance(cleanup, dict) and
                cleanup.get("schema") == "vnext-t2-r18-owned-temp-cleanup-r1" and
                cleanup.get("status") ==
                    "blocked_by_tool_policy_retained_and_exactly_excluded" and
                cleanup.get("cleanup_command_attempted") is True and
                cleanup.get("cleanup_command_exit") == "tool_rejected_before_execution" and
                cleanup.get("deleted") is False and cleanup.get("files") == expected_excluded and
                cleanup.get("failure_evidence_preserved") is True and
                cleanup.get("julia_started") is False,
                "owned temporary map cleanup receipt is inconsistent")
        require(
                coverage.get("status") == "static_coverage_map_no_julia" and
                coverage.get("formal_t2_accepted") is False and
                coverage.get("old_assertion_site_count") == 154 and
                coverage.get("old_expected_runtime_hit_count") == 174 and
                coverage.get("successor_case_count") == 60 and
                coverage.get("successor_assertion_site_count") == 214 and
                coverage.get("successor_expected_runtime_hit_count") == 622 and
                coverage.get("preserved_successor_assertion_site_count") == 191 and
                coverage.get("preserved_successor_expected_runtime_hit_count") == 530 and
                coverage.get("context_transport_assertion_site_count") == 23 and
                coverage.get("context_transport_expected_runtime_hit_count") == 92 and
                coverage.get("versioned_product_repair_regression", {}).get(
                    "assertion_site_count") == 24,
                "coverage counts/schema differ from frozen complete contract")
        runtime_plan = coverage.get("runtime_execution_plan")
        phase_order = protocol.get("phase_order")
        require(isinstance(phase_order, list) and len(phase_order) == 30 and
                isinstance(runtime_plan, dict) and
                len(runtime_plan.get("actual_formal_summary_case_ids", [])) == 45 and
                runtime_plan.get("expected_unique_case_count") == 60 and
                runtime_plan.get("expected_runtime_case_hit_count") == 68 and
                controller.verify_coverage_runtime_plan(protocol, coverage) ==
                    runtime_plan,
                "30-phase or 45/60/68 runtime plan self-binding failed")
        controller.verify_frozen_coverage_map_counts(coverage, runtime_plan)

        historical = load(ATTEMPT7_MAP)
        cases = sorted(row["id"] for row in coverage["successor_cases"])
        prior_cases = sorted(row["id"] for row in historical["successor_cases"])
        sites = sorted(row["id"] for row in coverage["successor_assertion_sites"])
        prior_sites = sorted(row["id"] for row in historical["successor_assertion_sites"])
        require(cases == prior_cases and sites == prior_sites and
                len(set(sites)) == 214 and
                coverage.get("attempt9c_relocation_summary", {}).get(
                    "entry_count") == 175,
                "case/site set or relocation ledger changed")
        controls: list[dict[str, str]] = report["negative_controls"]
        baseline_failure = protocol.get("r17_baseline_heavy_truthiness_failure")
        require(isinstance(baseline_failure, dict) and
                baseline_failure.get("schema") ==
                    "vnext-t2-r17-baseline-heavy-truthiness-failure-r1" and
                baseline_failure.get("leaf") ==
                    R17_BASELINE_GATE_FAILURE.relative_to(ROOT).as_posix() and
                baseline_failure.get("julia_started") is False and
                baseline_failure.get("phases") == [],
                "R17 baseline truthiness failure lineage is missing or inconsistent")
        for key, path in R17_BASELINE_GATE_FAILURE_FILES.items():
            expected = baseline_failure.get(key)
            require(expected == receipt(path) and
                    inputs.get(expected.get("path")) == expected,
                    f"R17 baseline truthiness failure pin drift: {key}")
        retry1 = protocol.get("r18_retry1_static_qa_failure")
        require(isinstance(retry1, dict) and retry1.get("schema") ==
                "vnext-t2-r18-retry1-static-qa-failure-r1" and
                retry1.get("leaf") == R18_RETRY1_FAILURE_LEAF.relative_to(ROOT).as_posix() and
                retry1.get("freezer_exit_code") == 1 and
                retry1.get("static_qa_status") == "fail" and
                retry1.get("failure_message") ==
                    "R23 natural child did not complete with the exact terminal-exit-race receipt" and
                retry1.get("julia_started") is False and
                retry1.get("formal_t2_accepted") is False,
                "R18 retry1 failed static QA lineage is missing")
        expected_retry1 = {
            path.relative_to(R18_RETRY1_FAILURE_LEAF).as_posix(): receipt(path)
            for path in R18_RETRY1_FAILURE_LEAF.rglob("*") if path.is_file()
        }
        require(retry1.get("files") == expected_retry1 and
                all(inputs.get(row["path"]) == row
                    for row in expected_retry1.values()),
                "R18 retry1 failure file inventory or input pins drift")
        old_retry1_qa = load(R18_RETRY1_FAILURE_LEAF / "static_qa.json")
        require(old_retry1_qa.get("failure", {}).get("message") ==
                retry1.get("failure_message") and
                old_retry1_qa.get("julia_executed") is False,
                "R18 retry1 failure classification does not match its pinned QA")
        projection_failure = protocol.get(
            "r19_retry1_projection_schema_failure")
        require(isinstance(projection_failure, dict) and
                projection_failure.get("schema") ==
                    "vnext-t2-r19-retry1-projection-schema-failure-r1" and
                projection_failure.get("leaf") ==
                    R19_RETRY1_PROJECTION_FAILURE_LEAF.relative_to(ROOT).as_posix() and
                projection_failure.get("protocol_schema_at_failure") ==
                    "vnext-t2-independent-negative-protocol-r9" and
                projection_failure.get("projection_validator") ==
                    receipt(R10_PROJECTION_REUSE_VALIDATOR) and
                projection_failure.get("exit_code") == 1 and
                projection_failure.get("stop_reason") == "natural_exit" and
                projection_failure.get("failure_message") ==
                    'RuntimeError("projection reuse protocol schema mismatch")' and
                projection_failure.get("stdout_bytes") == 0 and
                projection_failure.get("julia_started") is False and
                projection_failure.get("formal_t2_accepted") is False,
                "R19 retry1 projection-schema failure lineage is missing")
        expected_projection_failure_files = {
            path.relative_to(R19_RETRY1_PROJECTION_FAILURE_LEAF).as_posix():
                receipt(path)
            for path in R19_RETRY1_PROJECTION_FAILURE_LEAF.rglob("*")
            if path.is_file()
        }
        require(projection_failure.get("files") ==
                    expected_projection_failure_files and
                all(inputs.get(row["path"]) == row
                    for row in expected_projection_failure_files.values()) and
                projection_failure.get("phase") == expected_projection_failure_files.get(
                    "projection24_reuse_preflight/phase.json"),
                "R19 retry1 failure inventory or input pins drift")
        projection_failure_phase = load(
            R19_RETRY1_PROJECTION_FAILURE_LEAF /
            "projection24_reuse_preflight/phase.json")
        projection_failure_stderr = (
            R19_RETRY1_PROJECTION_FAILURE_LEAF /
            "projection24_reuse_preflight/stderr.raw").read_text(
                encoding="utf-8", errors="replace")
        projection_failure_command = projection_failure_phase.get(
            "command_argv")
        require(projection_failure_phase.get("schema") ==
                    "vnext-t2-projection24-python-preflight-phase-r1" and
                projection_failure_phase.get("exit_code") == 1 and
                projection_failure_phase.get("status") == "fail" and
                projection_failure_phase.get("stop_reason") == "natural_exit" and
                projection_failure_phase.get("julia_started") is False and
                projection_failure_phase.get("formal_t2_accepted") is False and
                projection_failure_phase.get("stdout", {}).get("bytes") == 0 and
                isinstance(projection_failure_command, list) and
                len(projection_failure_command) == 5 and
                projection_failure_command[2] ==
                    str(R10_PROJECTION_REUSE_VALIDATOR.resolve()) and
                projection_failure_command[3] == str(
                    (R19_RETRY1_PROJECTION_FAILURE_LEAF / "protocol.json").resolve()) and
                'RuntimeError("projection reuse protocol schema mismatch")' in
                    projection_failure_stderr,
                "R19 retry1 projection failure phase does not match its pinned cause")
        retry2_failure = protocol.get("r19_retry2_static_qa_failure")
        require(isinstance(retry2_failure, dict) and
                retry2_failure.get("schema") ==
                    "vnext-t2-r19-retry2-static-qa-failure-r1" and
                retry2_failure.get("leaf") ==
                    R19_RETRY2_STATIC_QA_FAILURE_LEAF.relative_to(ROOT).as_posix() and
                retry2_failure.get("protocol_schema") ==
                    "vnext-t2-independent-negative-protocol-r8" and
                retry2_failure.get("static_qa_status") == "fail" and
                retry2_failure.get("static_qa_failure_message") ==
                    "R19 retry1 projection failure phase does not match its pinned cause" and
                retry2_failure.get("projection24_preflight_exit_code") == 0 and
                retry2_failure.get("projection24_pass_marker_observed") is True and
                retry2_failure.get("julia_started") is False and
                retry2_failure.get("formal_t2_accepted") is False,
                "R19 retry2 static-QA failure lineage is missing")
        expected_retry2_files = {
            path.relative_to(R19_RETRY2_STATIC_QA_FAILURE_LEAF).as_posix():
                receipt(path)
            for path in R19_RETRY2_STATIC_QA_FAILURE_LEAF.rglob("*")
            if path.is_file()
        }
        require(retry2_failure.get("files") == expected_retry2_files and
                all(inputs.get(row["path"]) == row
                    for row in expected_retry2_files.values()),
                "R19 retry2 failure file inventory or input pins drift")
        retry2_protocol = load(
            R19_RETRY2_STATIC_QA_FAILURE_LEAF / "protocol.json")
        retry2_static_qa = load(
            R19_RETRY2_STATIC_QA_FAILURE_LEAF / "static_qa.json")
        retry2_preflight = load(
            R19_RETRY2_STATIC_QA_FAILURE_LEAF /
            "projection24_reuse_preflight/phase.json")
        retry2_static_qa_stderr = json.loads(
            (R19_RETRY2_STATIC_QA_FAILURE_LEAF / "static_qa.stderr.raw").read_text(
                encoding="utf-8"))
        require(retry2_protocol.get("schema") ==
                    retry2_failure.get("protocol_schema") and
                retry2_static_qa.get("status") == "fail" and
                retry2_static_qa.get("failure", {}).get("message") ==
                    retry2_failure.get("static_qa_failure_message") and
                retry2_static_qa.get("julia_executed") is False and
                retry2_preflight.get("exit_code") == 0 and
                retry2_preflight.get("pass_marker_observed") is True and
                retry2_preflight.get("julia_started") is False and
                retry2_static_qa_stderr.get("failure", {}).get("message") ==
                    retry2_failure.get("static_qa_failure_message"),
                "R19 retry2 failure classification differs from pinned files")
        r18_r19_delta = protocol.get("controller_r18_r19_snapshot_predicate_delta")
        r18_controller_path = TEST_ROOT / "independent_negative_controller_r18.py"
        require(isinstance(r18_r19_delta, dict) and
                r18_r19_delta.get("schema") ==
                    "vnext-t2-r18-r19-snapshot-predicate-delta-r1" and
                r18_r19_delta.get("r18_source") == receipt(r18_controller_path) and
                r18_r19_delta.get("r19_source") == receipt(R19_CONTROLLER) and
                r18_r19_delta.get("exact_snapshot_fields") == sorted([
                    "schema", "complete", "row_count", "host_identity",
                    "system_information_class", "buffer_bytes", "query_attempts",
                    "raw_identity_digest_sha256", "identity_authority"]) and
                r18_r19_delta.get("native_host_build_pin") == [10, 0, 26200, "AMD64"] and
                r18_r19_delta.get("field_ranges_and_digest_format_fail_closed") is True and
                r18_r19_delta.get("baseline_and_final_share_predicate") is True and
                r18_r19_delta.get("coverage_or_threshold_changed") is False,
                "R18-to-R19 snapshot predicate delta receipt is invalid")
        old_controller_source = r18_controller_path.read_text(encoding="utf-8")
        r19_controller_source = R19_CONTROLLER.read_text(encoding="utf-8")
        old_controller_functions = {
            node.name: ast.dump(node, include_attributes=False)
            for node in ast.parse(old_controller_source).body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
        current_controller_functions = {
            node.name: ast.dump(node, include_attributes=False)
            for node in ast.parse(r19_controller_source).body
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
        observed_changed_functions = sorted(
            name for name in old_controller_functions.keys() |
            current_controller_functions.keys()
            if old_controller_functions.get(name) !=
            current_controller_functions.get(name))
        require(observed_changed_functions == [
                    "_verify_r23_native_snapshot_receipt",
                    "verify_baseline_heavy_processes_clear"] and
                r18_r19_delta.get("changed_top_level_functions") ==
                    observed_changed_functions,
                "R19 controller diff changed unrelated functions")
        report["controller_r18_r19_snapshot_predicate_delta"] = {
            "status": "pass", "changed_functions": observed_changed_functions,
            "coverage_or_threshold_changed": False}
        report["controller_r19_r20_process_sample_delta"] = \
            verify_r20_controller_sample_delta(protocol, r20_source, r20_pin)
        report["controller_r20_r21_tracked_sample_exit_delta"] = \
            verify_r21_controller_tracked_exit_delta(protocol, inputs)
        report["controller_r21_r22_pre_tree_tracked_exit_delta"] = \
            verify_r22_controller_pre_tree_delta(
                protocol, inputs, controller_source, controller_pin)
        report["r22_pre_tree_tracked_exit_python_controls"] = \
            verify_r22_pre_tree_test_receipt(protocol, inputs)
        report["r22_windows_host_smoke"] = \
            verify_r22_windows_host_smoke(protocol, inputs)
        report["r18_predicate_probe_no_go_lineage"] = \
            verify_r18_predicate_no_go_lineage(protocol, inputs)
        prior_start = load(R17_BASELINE_GATE_FAILURE_FILES["pipeline_start"])
        prior_final = load(R17_BASELINE_GATE_FAILURE_FILES["pipeline_final"])
        prior_audit = prior_start.get("baseline_heavy_processes")
        require(isinstance(prior_audit, dict) and
                prior_audit.get("complete") is True and
                all(prior_audit.get(key) == [] for key in
                    ("processes", "controller_processes",
                     "native_heavy_identities", "errors")) and
                prior_final.get("failure", {}).get("message") ==
                    "serialized Julia lane occupied" and
                prior_final.get("phases") == [] and
                prior_final.get("formal_t2_accepted") is False,
                "R17 failure no longer demonstrates the baseline dict truthiness bug")

        valid_audit = copy.deepcopy(prior_audit)
        controller.verify_baseline_heavy_processes_clear(valid_audit)
        report.setdefault("positive_controls", []).append(
            "R17 real empty complete audit accepted by R19 predicate")
        negative_count_before = len(controls)
        reject("non-object baseline audit rejected",
               lambda: controller.verify_baseline_heavy_processes_clear(None), controls)
        malformed = copy.deepcopy(valid_audit)
        malformed["schema"] = "wrong-schema"
        reject("unknown baseline audit schema rejected",
               lambda: controller.verify_baseline_heavy_processes_clear(malformed), controls)
        for field in ("complete", "processes", "controller_processes",
                      "native_heavy_identities", "errors", "snapshot"):
            malformed = copy.deepcopy(valid_audit)
            malformed.pop(field)
            reject(f"missing baseline audit field rejected: {field}",
                   lambda value=malformed:
                       controller.verify_baseline_heavy_processes_clear(value), controls)
        malformed = copy.deepcopy(valid_audit)
        malformed["complete"] = 1
        reject("non-boolean complete rejected",
               lambda: controller.verify_baseline_heavy_processes_clear(malformed), controls)
        for field in ("processes", "controller_processes",
                      "native_heavy_identities", "errors"):
            malformed = copy.deepcopy(valid_audit)
            malformed[field] = None
            reject(f"wrong-type audit list rejected: {field}",
                   lambda value=malformed:
                       controller.verify_baseline_heavy_processes_clear(value), controls)
            malformed = copy.deepcopy(valid_audit)
            malformed[field] = [{"unexpected": "residual"}]
            reject(f"nonempty audit list rejected: {field}",
                   lambda value=malformed:
                       controller.verify_baseline_heavy_processes_clear(value), controls)
        for field, value, label in (
                ("complete", False, "incomplete"),
                ("snapshot", None, "missing snapshot object")):
            malformed = copy.deepcopy(valid_audit)
            malformed[field] = value
            reject(f"contradictory audit receipt rejected: {label}",
                   lambda item=malformed:
                       controller.verify_baseline_heavy_processes_clear(item), controls)
        for field, value, label in (
                ("complete", False, "snapshot incomplete"),
                ("schema", "wrong", "snapshot schema"),
                ("row_count", True, "boolean row count"),
                ("row_count", 0, "empty native process table"),
                ("identity_authority", "rounded psutil time", "wrong identity authority")):
            malformed = copy.deepcopy(valid_audit)
            malformed["snapshot"][field] = value
            reject(f"malformed native snapshot rejected: {label}",
                   lambda item=malformed:
                       controller.verify_baseline_heavy_processes_clear(item), controls)

        native_table = make_r19_native_table(controller)
        snapshot_cases = {
            "host_identity": ([10, 0, 26201, "AMD64"],
                              [10, 0, 26200, True]),
            "system_information_class": (6, True),
            "buffer_bytes": (0, controller._R23_TABLE.MAX_BUFFER_BYTES + 1, True),
            "query_attempts": (0, controller._R23_TABLE.MAX_QUERY_ATTEMPTS + 1, True),
            "raw_identity_digest_sha256": ("g" * 64, "a" * 63, 7),
        }
        final_positive = run_r19_final_audit_with_receipt(
            controller, native_table, valid_audit)
        require(final_positive.get("complete") is True and
                final_positive.get("errors") == [],
                "R19 final audit rejected a valid complete empty heavy receipt")
        report.setdefault("positive_controls", []).append(
            "R19 final audit accepts exact complete empty R23 receipt")

        snapshot_boundary_count = 0
        for field, bad_values in snapshot_cases.items():
            mutations = [("missing", None)] + [
                (f"invalid_{index}", bad_value)
                for index, bad_value in enumerate(bad_values, 1)]
            for mutation, case_label in mutations:
                malformed = copy.deepcopy(valid_audit)
                if mutation == "missing":
                    malformed["snapshot"].pop(field)
                else:
                    malformed["snapshot"][field] = case_label
                name = f"R19 baseline rejects {mutation} snapshot {field}"
                reject(name, lambda item=malformed:
                       controller.verify_baseline_heavy_processes_clear(item), controls)
                snapshot_boundary_count += 1

                final = run_r19_final_audit_with_receipt(
                    controller, native_table, malformed)
                require(final.get("complete") is False and any(
                    error.get("stage") == "r23_global_heavy_audit"
                    for error in final.get("errors", [])),
                    f"final audit accepted {mutation} snapshot field {field}")
                controls.append({
                    "name": f"R19 final audit rejects {mutation} snapshot {field}",
                    "status": "pass",
                    "rejected_as": "incomplete_final_receipt_with_global_audit_error",
                })
                snapshot_boundary_count += 1

        malformed_extra = copy.deepcopy(valid_audit)
        malformed_extra["snapshot"]["unrecognized"] = "ignored-by-r18"
        reject("R19 baseline rejects extra snapshot fields",
               lambda: controller.verify_baseline_heavy_processes_clear(
                   malformed_extra), controls)
        snapshot_boundary_count += 1

        final_extra = run_r19_final_audit_with_receipt(
            controller, native_table, malformed_extra)
        require(final_extra.get("complete") is False and any(
            error.get("stage") == "r23_global_heavy_audit"
            for error in final_extra.get("errors", [])),
            "final audit accepted an extra snapshot field")
        controls.append({
            "name": "R19 final audit rejects extra snapshot fields",
            "status": "pass",
            "rejected_as": "incomplete_final_receipt_with_global_audit_error",
        })
        snapshot_boundary_count += 1
        report["baseline_heavy_preflight_controls"] = {
            "production_helper": "verify_baseline_heavy_processes_clear",
            "baseline_and_final_audit_share_helper": True,
            "positive_count": 2,
            "negative_count": len(controls) - negative_count_before,
        }
        report["r19_snapshot_receipt_controls"] = {
            "snapshot_fields": sorted(snapshot_cases),
            "baseline_and_final_boundaries_each_rejected": snapshot_boundary_count,
            "expected_negative_count": snapshot_boundary_count,
            "final_audit_positive_complete": True,
            "field_shape_is_exact": True,
        }
        report["r20_sample_handoff_controls"] = run_r20_sample_handoff_controls(
            controller, controls, report.setdefault("positive_controls", []))
        r20_phase_cleanup_observation: dict[str, Any] = {
            "schema": "vnext-t2-r20-synthetic-phase-cleanup-observation-r1",
            "status": "synthetic_preparation_observation_started",
            "scope": "synthetic_preparation_control_only",
            "formal_t2_accepted": False,
            "julia_executed": False,
            "host_cleanup_credit": False,
            "final_audit_scope": "preexisting_isolated_mock",
        }
        report["r20_phase_cleanup_controls"] = r20_phase_cleanup_observation
        r20_phase_cleanup_summary = run_r20_phase_cleanup_controls(
            controller, controls, report.setdefault("positive_controls", []),
            r20_phase_cleanup_observation)
        r20_phase_cleanup_observation.update(r20_phase_cleanup_summary)
        report["r20_unbound_cleanup_controls"] = run_r20_unbound_cleanup_controls(
            controller, controls, report.setdefault("positive_controls", []))
        bad_plan = copy.deepcopy(protocol)
        bad_plan["runtime_execution_plan"]["actual_formal_summary_case_ids"].pop()
        reject("missing formal case rejected by plan/map equality",
               lambda: controller.verify_coverage_runtime_plan(bad_plan, coverage),
               controls)
        bad_plan = copy.deepcopy(protocol)
        bad_plan["runtime_execution_plan"]["expected_unique_case_count"] = 59
        reject("unique case count reduction rejected",
               lambda: controller.verify_coverage_runtime_plan(bad_plan, coverage),
               controls)
        bad_coverage = copy.deepcopy(coverage)
        bad_coverage["successor_assertion_site_count"] = 213
        reject("assertion site reduction rejected",
               lambda: controller.verify_frozen_coverage_map_counts(
                   bad_coverage, runtime_plan),
               controls)
        bad_coverage = copy.deepcopy(coverage)
        bad_coverage["successor_assertion_runtime_hit_plan"][
            "expected_runtime_hit_count"] = 621
        reject("site hit reduction rejected",
               lambda: controller.verify_frozen_coverage_map_counts(
                   bad_coverage, runtime_plan),
               controls)
        bad_coverage = copy.deepcopy(coverage)
        bad_coverage["schema"] = "vnext-t2-independent-negative-coverage-map-r15"
        reject("unexpected map schema rejected",
               lambda: check_map_schema(bad_coverage), controls)

        positive_join = controller.verify_positive_reuse_input_pins(protocol)
        require(positive_join.get("status") == "pass" and
                positive_join.get("positive_runtime_input_count") == 104,
                "positive r3 104-input current join failed")
        positive = protocol["positive_evidence"]
        controller.verify_frozen_positive_evidence(
            ROOT / positive["root"], positive)
        positive_command_values = controller.read_positive(
            ROOT / positive["root"],
            positive["formal_serial_replay"]["sha256"],
            positive["pipeline_final"]["sha256"])

        julia_common = [protocol["julia_executable"],
                        "--project=" + str(ROOT)]
        authorities = []
        for idx in range(4):
            authorities.extend([str(ROOT / f"static-authority-{idx}.json"),
                                 "a" * 64])
        context_path = ROOT / "static-context.jls"
        authorization_path = ROOT / "static-authorization.json"
        coverage_sha = coverage_pin["sha256"]
        mode_order = ["preflight", "fault_n10", "t1_handoff",
                      *["authority-case:" + case_id for case_id in
                        controller.AUTHORITY_CASE_ORDER]]
        generated = []
        for index, mode in enumerate(mode_order):
            argv = controller.build_actual_formal_shard_command(
                julia_common, mode, authorities, context_path, "b" * 64,
                authorization_path, "c" * 64,
                ROOT / "planned-static-do-not-create" / str(index),
                coverage_path, coverage_sha)
            driver_index = argv.index(str(controller.ACTUAL_DRIVER))
            driver_args = argv[driver_index + 1:]
            require(len(driver_args) == 16 and driver_args[0] == mode and
                    driver_args[14] == str(coverage_path) and
                    driver_args[15] == coverage_sha,
                    f"actual command builder emitted invalid 16-arg shard: {mode}")
            generated.append({"mode": mode, "driver_args": driver_args,
                              "argument_count": len(driver_args)})
        bad_argv = copy.deepcopy(generated[0]["driver_args"])
        bad_argv.pop()
        reject("malformed coverage-map SHA rejected by actual builder guard",
               lambda: controller.build_actual_formal_shard_command(
                   julia_common, "preflight", authorities, context_path, "b" * 64,
                   authorization_path, "c" * 64, ROOT / "x", coverage_path,
                   coverage_sha[:-1]), controls)

        command_argv = command_data.get("argv")
        require(command_data.get("kind") == "non_executable_command_data" and
                command_data.get("julia_started") is False and
                command_data.get("formal_t2_accepted") is False and
                isinstance(command_argv, list) and
                command_argv == dispatch.get("command_argv") and
                command_data.get("environment") == dispatch.get("environment") and
                dispatch.get("julia_started") is False and
                dispatch.get("julia_lane_granted") is False and
                dispatch.get("phase_order") == phase_order and
                dispatch.get("phase_count") == 30,
                "frozen formal command/dispatch mismatch")
        require(command_argv[0] == sys.executable and command_argv[1] == "-B" and
                Path(command_argv[2]).resolve() == CONTROLLER.resolve() and
                "--protocol" in command_argv and
                str(Path(args.protocol).resolve()) ==
                    command_argv[command_argv.index("--protocol") + 1] and
            "--evidence-dir" in command_argv,
                "formal controller argv is not the exact direct launcher")
        planned = ROOT / protocol["planned_evidence_directory"]
        require(planned.resolve().parent ==
                (ROOT / "runs/UP1-04A-VNEXT-T2").resolve() and
                not planned.exists() and
                protocol.get("planned_evidence_directory_absent") is True,
                "actual formal T2 output must be an absent direct child of the runs root")
        evidence_arg = command_argv.index("--evidence-dir")
        require(evidence_arg + 1 < len(command_argv) and
                Path(command_argv[evidence_arg + 1]).resolve() == planned.resolve(),
                "formal controller evidence-dir differs from the frozen runs leaf")
        if "--resume-authority-from" in command_argv:
            resume_arg = command_argv.index("--resume-authority-from")
            require(resume_arg + 1 < len(command_argv) and
                    Path(command_argv[resume_arg + 1]).resolve().parent ==
                        (ROOT / "runs/UP1-04A-VNEXT-T2").resolve() and
                    Path(command_argv[resume_arg + 1]).resolve() != planned.resolve(),
                    "authority resume must use a different direct runs-root leaf")
        path_policy = protocol.get("execution_evidence_path_policy", {})
        require(path_policy.get("schema") ==
                    "vnext-t2-r20-runs-only-execution-path-policy-r1" and
                path_policy.get("required_direct_child_root") ==
                    "runs/UP1-04A-VNEXT-T2" and
                path_policy.get("direct_child_only") is True and
                path_policy.get("rejects_docs_nested_external_and_junctioned_parents")
                    is True and
                path_policy.get("r9_host_smoke_is_current_path_gate_test") is False and
                path_policy.get("freeze_protocol_output_root") ==
                    "runs/UP1-04A-VNEXT-T2",
                "execution evidence path policy drift")

        gates = protocol.get("resource_gates", {})
        require(gates.get("process_tree_working_set_bytes") == 2_147_483_648 and
                gates.get("julia_threads") == 1 and gates.get("openblas_threads") == 1 and
                gates.get("phase_wall_seconds") == 480 and
                gates.get("phase_wall_timeout_overrides") ==
                    {"actual_formal_preflight": 600} and
                gates.get("authority_phase_wall_seconds") == 2400 and
                gates.get("authority_case_wall_seconds") == 2400 and
                protocol.get("controller_wall_budget_summary", {}).get(
                    "summed_phase_wall_cap_seconds") == 16440,
                "frozen timeout/resource contract drift")

        monitor_inputs = {
            R23_TABLE.relative_to(ROOT).as_posix(): protocol[
                "r20_native_monitor_host_smoke"][
                "native_process_table"],
            R23_SUPERVISOR.relative_to(ROOT).as_posix(): protocol[
                "r20_native_monitor_host_smoke"][
                "supervisor"],
        }
        require(all(inputs.get(path) == pin for path, pin in monitor_inputs.items()),
                "R9 exact inventory/supervisor source is not pinned in closure")
        host_status = verify_r20_host_smoke(protocol, inputs)
        report["r20_native_monitor_host_smoke"] = host_status
        report["r20_native_monitor_host_smoke_failure_lineage"] = \
            verify_r20_host_smoke_failure_lineage(protocol, inputs)
        report["controller_r20_runs_only_path_gate"] = \
            verify_r20_runs_only_path_gate(protocol, inputs, r20_controller,
                                           r20_source, r20_pin)
        report["r17_host_smoke_failure_lineage"] = \
            verify_host_smoke_failure_lineage(protocol, inputs)
        report["r18_predicate_probe_no_go_lineage"] = \
            verify_r18_predicate_no_go_lineage(protocol, inputs)
        report["positive_runtime_input_count"] = positive_join[
            "positive_runtime_input_count"]
        report["coverage"] = {
            "phase_count": len(phase_order), "case_count": len(cases),
            "formal_case_count": len(runtime_plan["actual_formal_summary_case_ids"]),
            "runtime_unique_cases": runtime_plan["expected_unique_case_count"],
            "runtime_case_hits": runtime_plan["expected_runtime_case_hit_count"],
            "source_sites": len(sites),
            "planned_source_site_hits": coverage[
                "successor_expected_runtime_hit_count"],
            "authority_source_sites": 175, "authority_nonzero_sites": 75,
            "authority_planned_hits": 118, "transport_site_ids": 23,
            "transport_planned_hits": 92, "projection_sites": 24,
            "attempt7_case_site_set_equal": True,
            "relocated_site_count": 175,
        }
        report["generated_actual_shard_argv"] = generated
        report["resource_gates"] = gates
        report["r20_monitor_source_pins"] = monitor_inputs
        report["negative_control_count"] = len(controls)
        report["positive_control_count"] = len(report.get("positive_controls", []))
        report["actual_source_site_hits"] = "pending_julia_execution"
        report["julia_executed"] = False
        report["formal_t2_accepted"] = False
        report["status"] = "pass_static_r20_r23_no_julia"
    except Exception as error:
        report["failure"] = {"type": type(error).__name__, "message": str(error)}
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, sort_keys=True,
                                          indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        return 1
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, sort_keys=True,
                                      indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": report["status"],
                      "input_count": report["input_count"],
                      "negative_control_count": report["negative_control_count"],
                      "coverage": report["coverage"],
                      "report": receipt(report_path)},
                     ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
