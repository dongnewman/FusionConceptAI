from __future__ import annotations

import argparse
import ast
import copy
import hashlib
import json
import math
import os
import stat
import subprocess
import sys
import tempfile
import types
from pathlib import Path
from typing import Any
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.execution.t2_source_inputs import T2SourceInputs

_T2_SOURCE_INPUTS: T2SourceInputs | None = None
_T2_SOURCE_PROTOCOL: dict[str, Any] | None = None
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
R20_CONTROLLER = TEST_ROOT / "independent_negative_controller_r20.py"
R21_CONTROLLER = TEST_ROOT / "independent_negative_controller_r21.py"
R22_CONTROLLER = TEST_ROOT / "independent_negative_controller_r22.py"
R22_STATIC_QA = TEST_ROOT / "static_qa_independent_negative_r22.py"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r23.py"
R23_CONTROLLER_PREIMAGE = ROOT / (
    "runs/e/code_consolidation_20260927/t2_controller_before.py")
R23_CONTROLLER_PAIR_PREIMAGE = ROOT / (
    "runs/e/up1_inplace_resume_20260927/controller_a5ba_before_pair.py")
R23_CONTROLLER_LIFECYCLE_PREIMAGE = ROOT / (
    "runs/e/lifecycle_systemic_repair_20260927_r1/live_consumer_integration/"
    "preimages/test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
    "independent_negative_controller_r23.py")
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
R12_PROJECTION_REUSE_PREIMAGE = ROOT / (
    "runs/e/projection_reuse_r12_adapter_r1/"
    "validate_projection24_reuse_r12.preimage")
R12_PROJECTION_REUSE_PREIMAGE_BYTES = 13712
R12_PROJECTION_REUSE_PREIMAGE_SHA256 = (
    "04f3cf18221b69942815a8fd4d724e956ae3a230077200a24c49d57474344d41")
R12_ARCHIVED_COVERAGE_BUILDER = TEST_ROOT / "build_coverage_map_r1.py"
R12_ARCHIVED_COVERAGE_BUILDER_BYTES = 45694
R12_ARCHIVED_COVERAGE_BUILDER_SHA256 = (
    "0659248e18e9ee67e59343a7778a07e422320d81ff36749a1e432b0524d1e506")
PROJECTION_REUSE_VALIDATOR = R12_PROJECTION_REUSE_VALIDATOR
R23_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
R23_SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
R23_TEST_SUITE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r23_v1.py"
MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS = (
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
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
R22_PRIOR_FORMAL_FAILURE_PROTOCOL = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r7_protocol_freeze_20260926_t2_protocol_r22_pre_tree_r3/protocol.json")
R22_PRIOR_FORMAL_FAILURE_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r22_r10_r3")
R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "formal_launcher_r22_r10_r3_20260926_r1")
R22_PRIOR_FORMAL_FAILURE_SNAPSHOT = R22_PRIOR_FORMAL_FAILURE_LEAF / (
    "source_snapshots_r22_actual_failure_20260926_r1")
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


def _source_inputs() -> T2SourceInputs:
    global _T2_SOURCE_INPUTS
    if _T2_SOURCE_INPUTS is None:
        _T2_SOURCE_INPUTS = T2SourceInputs(ROOT)
    return _T2_SOURCE_INPUTS


def bind_source_protocol(protocol: dict[str, Any]) -> T2SourceInputs:
    global _T2_SOURCE_PROTOCOL
    sources = _source_inputs()
    sources.verify_protocol_layout(protocol)
    _T2_SOURCE_PROTOCOL = protocol
    return sources


def _historical_receipt_for(path: Path) -> tuple[str, dict[str, Any]] | None:
    if _T2_SOURCE_PROTOCOL is None:
        return None
    sources = _source_inputs()
    relative = sources.logical_path(path)
    layout = _T2_SOURCE_PROTOCOL.get("source_layout")
    if not isinstance(layout, dict):
        raise RuntimeError("T2 source protocol layout was not bound")
    historical = layout.get("historical_source_data")
    if not isinstance(historical, dict):
        raise RuntimeError("T2 historical source allowlist is absent")
    expected = historical.get(relative)
    if expected is None:
        return None
    snapshot_id = layout.get("snapshot_id")
    if not isinstance(snapshot_id, str):
        raise RuntimeError("T2 source snapshot identity is absent")
    return snapshot_id, expected


def read_bytes(path: Path) -> bytes:
    sources = _source_inputs()
    try:
        historical = _historical_receipt_for(path)
    except ValueError:
        # Temporary controls may deliberately read files outside the checkout;
        # they are never eligible for archive lookup.
        return Path(path).read_bytes()
    if historical is not None:
        snapshot_id, expected = historical
        return sources.read_historical_bytes(path, snapshot_id, expected)
    return sources.read_bytes(path)


def read_text(path: Path, encoding: str = "utf-8", errors: str = "strict") -> str:
    sources = _source_inputs()
    try:
        historical = _historical_receipt_for(path)
    except ValueError:
        return Path(path).read_text(encoding=encoding, errors=errors)
    if historical is not None:
        snapshot_id, expected = historical
        text = sources.read_historical_text(path, snapshot_id, expected,
                                            encoding=encoding, errors=errors)
    else:
        text = sources.read_text(path, encoding=encoding, errors=errors)
    return text.replace("\r\n", "\n").replace("\r", "\n")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, Any]:
    path = Path(path)
    sources = _source_inputs()
    historical = _historical_receipt_for(path)
    if historical is not None:
        snapshot_id, expected = historical
        return sources.historical_receipt(path, snapshot_id, expected)
    data = sources.read_bytes(path)
    return {"path": sources.logical_path(path),
            "bytes": len(data), "sha256": sha(data)}


def load(path: Path) -> dict[str, Any]:
    value = json.loads(read_text(path, encoding="utf-8"))
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
    _source_inputs().require_local_execution(path)
    actual = receipt(path)
    require(actual == expected, f"source pin drift before compile/exec: {path}")
    module = types.ModuleType(name)
    module.__file__ = str(path.resolve())
    source = _source_inputs().read_bytes(path)
    exec(compile(source, str(path.resolve()), "exec"), module.__dict__)
    return module


def source_paths_under(directory: Path) -> list[Path]:
    sources = _source_inputs()
    historical = sources.history_paths_under(directory)
    local = []
    if directory.is_dir():
        local = [path for path in directory.rglob("*") if path.is_file()]
    return sorted(set(historical + local))


def source_is_available(path: Path) -> bool:
    sources = _source_inputs()
    try:
        relative = sources.logical_path(path)
    except ValueError:
        return path.is_file()
    historical = _historical_receipt_for(path)
    if historical is not None:
        return _T2_SOURCE_PROTOCOL is not None and \
            _T2_SOURCE_PROTOCOL.get("inputs", {}).get(relative) == {
                "path": relative, "bytes": historical[1]["bytes"],
                "sha256": historical[1]["sha256"]}
    return path.is_file()


def _validated_local_argument_path(value: str, role: str) -> Path:
    supplied = Path(value)
    require(".." not in supplied.parts,
            f"{role} path must not contain parent traversal")
    lexical = supplied.absolute()
    sources = _source_inputs()
    sources.require_local_execution(lexical)
    resolved = lexical.resolve(strict=True)
    resolved.relative_to(sources.root)
    return resolved


def _validated_new_report_path(value: str) -> Path:
    supplied = Path(value)
    require(".." not in supplied.parts,
            "report path must not contain parent traversal")
    lexical = supplied.absolute()
    sources = _source_inputs()
    relative = sources.logical_path(lexical)
    require(relative not in sources.history,
            "report path cannot target historical source data")
    root = sources.root
    parent = lexical.parent
    parent.relative_to(root)

    for component in reversed((parent, *parent.parents)):
        info = component.lstat()
        require(not stat.S_ISLNK(info.st_mode) and
                not (getattr(info, "st_file_attributes", 0) & 0x400) and
                stat.S_ISDIR(info.st_mode),
                f"report parent is not a real directory: {component}")

    try:
        lexical.lstat()
    except FileNotFoundError:
        pass
    else:
        raise RuntimeError("report destination must be a new, absent leaf")

    resolved_parent = parent.resolve(strict=True)
    resolved_parent.relative_to(root)
    require(resolved_parent == parent,
            "report parent resolved through an alias")
    return lexical


def _write_new_report(path: Path, report: dict[str, Any]) -> None:
    validated = _validated_new_report_path(str(path))
    require(validated == path,
            "report destination changed after its initial path validation")
    payload = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n"
    with validated.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def check_current_inputs(protocol: dict[str, Any]) -> list[dict[str, Any]]:
    sources = bind_source_protocol(protocol)
    pins = protocol.get("inputs")
    require(isinstance(pins, dict) and len(pins) >= 459,
            "current input closure is missing or below the frozen 459-pin floor")
    actual_rows = []
    for relative, expected in sorted(pins.items()):
        path = ROOT / relative
        sources.logical_path(path)
        actual = sources.protocol_input_receipt(protocol, path)
        require(expected == actual, f"current input path/bytes/SHA drift: {relative}")
        actual_rows.append(actual)
    require(protocol.get("input_count") == len(pins),
            "protocol input_count differs from exact current pins")
    required = {
        R21_CONTROLLER.relative_to(ROOT).as_posix(),
        R22_CONTROLLER.relative_to(ROOT).as_posix(),
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
        *MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS,
    }
    require(required.issubset(pins),
            "controller/R23 monitor source is missing from the input closure")
    lifecycle_pins = protocol.get("managed_process_lifecycle_source_pins")
    require(isinstance(lifecycle_pins, dict) and
            set(lifecycle_pins) == set(MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS),
            "managed process lifecycle source pin closure is missing or has extra paths")
    for relative in MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS:
        expected = pins.get(relative)
        lifecycle = lifecycle_pins.get(relative)
        require(isinstance(expected, dict) and isinstance(lifecycle, dict) and
                set(expected) == {"path", "bytes", "sha256"} and
                lifecycle == expected and expected.get("path") == relative and
                type(expected.get("bytes")) is int and expected["bytes"] > 0 and
                isinstance(expected.get("sha256"), str) and
                len(expected["sha256"]) == 64 and
                all(ch in "0123456789abcdef" for ch in expected["sha256"]),
                f"managed process lifecycle source receipt differs from current input pin: {relative}")
        actual = sources.protocol_input_receipt(protocol, ROOT / relative)
        require(actual == expected,
                f"managed process lifecycle source does not match canonical bytes: {relative}")
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
        for node in ast.parse(read_text(R19_CONTROLLER, encoding="utf-8")).body
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
                    for path in source_paths_under(HOST_SMOKE)}
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
    payload = json.loads(read_text(HOST_SMOKE / "stdout.raw", encoding="utf-8"))
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
                        for path in source_paths_under(leaf)}
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
        controller_source: str, controller_pin: dict[str, Any],
        current_controller_source: str) -> dict[str, Any]:
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

    before_text = read_text(HOST_SMOKE_CONTROLLER_SOURCE, encoding="utf-8")
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
    current_tree = ast.parse(current_controller_source)
    current_functions = {node.name: node for node in current_tree.body
                         if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    r20_gate = next((node for node in new_tree.body
                     if isinstance(node, ast.FunctionDef) and
                     node.name == "require_t2_execution_leaf"), None)
    current_gate = current_functions.get("require_t2_execution_leaf")
    require(r20_gate is not None and current_gate is not None and
            ast.dump(r20_gate, include_attributes=False) ==
                ast.dump(current_gate, include_attributes=False),
            "current R23 runs-only guard differs from the exact frozen R20 guard body")

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
        "r20_guard_ast_replayed_by_current_r23": True,
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
            stdout = read_text(leaf / "stdout.raw", encoding="utf-8")
            observation = json.loads(stdout.splitlines()[0])
            natural = observation.get("natural_phase", {})
            samples = [json.loads(line) for line in
                       read_text(leaf / "natural_python_child/samples.jsonl",
                                 encoding="utf-8").splitlines()]
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
            stderr = read_text(leaf / "stderr.raw", encoding="utf-8")
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
        for path in source_paths_under(R18_PREDICATE_TESTER_LEAF)
    }
    require(lineage.get("tester_files") == tester_files and
            all(inputs.get(row["path"]) == row for row in tester_files.values()),
            "R18 predicate tester raw/source evidence pins drift")
    r18_protocol_pin = receipt(R18_FREEZE_RETRY2_LEAF / "protocol.json")
    require(lineage.get("r18_protocol") == r18_protocol_pin and
            inputs.get(r18_protocol_pin["path"]) == r18_protocol_pin,
            "R18 predecessor protocol pin drift")

    r18_probe = json.loads(read_text(R18_PREDICATE_TESTER_LEAF /
                                     "predicate_probe_r4.stdout.raw",
                                     encoding="utf-8"))
    expected_failures = {
        "snapshot_missing_host_identity", "snapshot_wrong_host_identity",
        "snapshot_missing_system_information_class",
        "snapshot_wrong_system_information_class",
        "snapshot_missing_buffer_bytes", "snapshot_wrong_buffer_bytes",
        "snapshot_missing_query_attempts", "snapshot_wrong_query_attempts",
        "snapshot_missing_raw_identity_digest",
        "snapshot_malformed_raw_identity_digest",
    }
    require(read_text(R18_PREDICATE_TESTER_LEAF / "predicate_probe_r4.exit.txt",
                      encoding="ascii").strip() == "1" and
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
        for path in source_paths_under(R18_REVIEW_LEAF)
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


def make_r23_final_audit_history(controller: Any, table: Any,
                                 root_identity: tuple[int, int]
                                 ) -> tuple[list[dict[str, Any]], tuple[str, ...]]:
    native = controller._R23_TABLE
    final_table = native.validate_snapshot(table)
    root = native.validate_identity(root_identity)
    launch_rows = [row for row in final_table.rows
                   if row.identity.pid in (0, 4)]
    require({row.identity.pid for row in launch_rows} == {0, 4},
            "synthetic final-audit source lost the Windows idle/System rows")
    launch_rows.append(native.ProcessRow(
        native.ProcessIdentity(*root), 0, "r23-final-audit-test-root"))
    launch = native.ProcessTableSnapshot(
        rows=tuple(launch_rows), host_identity=tuple(final_table.host_identity),
        buffer_bytes=final_table.buffer_bytes,
        query_attempts=final_table.query_attempts,
        ntstatus_u32=final_table.ntstatus_u32)
    history: list[dict[str, Any]] = []
    captured_witnesses: list[str] = []
    controller._r23_append_snapshot_history(
        history, captured_witnesses, launch, sample_index=0,
        attempt_index=0, source_role="phase_launch")
    return history, tuple(captured_witnesses)


def run_r19_final_audit_with_receipt(controller: Any, table: Any,
                                     heavy_receipt: dict[str, Any]) -> dict[str, Any]:
    root_identity = (0xFFFFFFFE, controller._R23_TABLE.WINDOWS_EPOCH_100NS + 999)
    phase_history, phase_witnesses = make_r23_final_audit_history(
        controller, table, root_identity)
    with patch.object(controller, "_r23_exact_heavy_audit",
                      return_value=copy.deepcopy(heavy_receipt)):
        return controller._r23_final_audit(
            root_identity, [root_identity], table, root_exit_confirmed=True,
            phase_snapshot_history=phase_history,
            phase_snapshot_witnesses=phase_witnesses)


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
            return root if identity == root else identity

    class FakeProcess:
        def __init__(self) -> None:
            self.pid = root[0]
            self._handle = root

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
        phase_history, phase_witnesses = make_r23_final_audit_history(
            controller, table, fake_root)
        with patch.object(controller, "_r23_exact_heavy_audit",
                          return_value=copy.deepcopy(valid_heavy)):
            return controller._r23_final_audit(
                fake_root, [fake_root], table, root_exit_confirmed=True,
                unbound_observation_records=[copy.deepcopy(record)],
                phase_snapshot_history=phase_history,
                phase_snapshot_witnesses=phase_witnesses)

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
                working_set_limit_bytes: int,
                previous_accepted_source_snapshot: Any | None = None,
                outer_reconcile_snapshot: Any | None = None,
                outer_reconcile_history_sequence: int | None = None,
                previous_accepted_sample_index: int | None = None,
                previous_accepted_source_history_sequence: int | None = None,
                phase_snapshot_history: list[dict[str, Any]] | None = None,
                phase_snapshot_witnesses: list[str] | None = None,
                completed_source_snapshot_out: list[Any] | None = None,
                completed_source_snapshot_history_sequence_out:
                    list[int] | None = None
                ) -> dict[str, Any]:
            checked_table = native.validate_snapshot(table)
            require(checked_table == table and
                    native.validate_snapshot(outer_reconcile_snapshot) == checked_table and
                    sample_root_identity == root_identity and
                    sample_previous == [root_identity] and
                    sample_index == 1 and
                    working_set_limit_bytes == 2_147_483_648 and
                    previous_accepted_source_snapshot is None and
                    previous_accepted_sample_index is None and
                    previous_accepted_source_history_sequence is None and
                    outer_reconcile_history_sequence == 1 and
                    type(phase_snapshot_history) is list and
                    type(phase_snapshot_witnesses) is list and
                    len(phase_snapshot_history) == len(phase_snapshot_witnesses) == 2 and
                    type(completed_source_snapshot_out) is list and
                    completed_source_snapshot_out == [] and
                    type(completed_source_snapshot_history_sequence_out) is list and
                    completed_source_snapshot_history_sequence_out == [],
                    "R20 synthetic sampler received an unexpected source-table handoff")
            outer_binding = controller._r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                outer_reconcile_history_sequence, checked_table,
                sample_index=sample_index, attempt_index=0,
                source_role="outer_reconcile")
            outer_history_entry = phase_snapshot_history[
                outer_reconcile_history_sequence]
            expected_outer_pids = sorted(
                row.identity.pid for row in checked_table.rows)
            expected_outer_receipt = controller._r23_snapshot_receipt(
                checked_table)
            expected_outer_pid_hash = controller._r23_snapshot_history_pid_hash(
                expected_outer_pids)
            require(type(outer_binding) is dict and
                    set(outer_binding) == {
                        "sequence", "snapshot_receipt", "pid_set_sha256",
                        "prefix_sha256"} and
                    outer_binding.get("sequence") == 1 and
                    outer_binding.get("snapshot_receipt") ==
                        expected_outer_receipt and
                    type(outer_history_entry) is dict and
                    outer_history_entry.get("sequence") == 1 and
                    outer_history_entry.get("snapshot_receipt") ==
                        expected_outer_receipt and
                    outer_history_entry.get("pids") == expected_outer_pids and
                    outer_binding.get("pid_set_sha256") ==
                        outer_history_entry.get("pid_set_sha256") ==
                        expected_outer_pid_hash and
                    outer_binding.get("prefix_sha256") ==
                        outer_history_entry.get("prefix_sha256"),
                    "R20 synthetic sampler outer source-history binding changed")
            source_history_sequence = controller._r23_append_snapshot_history(
                phase_snapshot_history, phase_snapshot_witnesses, checked_table,
                sample_index=sample_index, attempt_index=1,
                source_role="sample_source_before")
            controller._r23_snapshot_history_reference(
                phase_snapshot_history, phase_snapshot_witnesses,
                source_history_sequence, checked_table,
                sample_index=sample_index, attempt_index=1,
                source_role="sample_source_before")
            completed_source_snapshot_out.append(checked_table)
            completed_source_snapshot_history_sequence_out.append(
                source_history_sequence)
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
                    environment={"R20_SYNTHETIC": "1"},
                    legacy_fixture_only=True)
                sample_rows = [json.loads(line) for line in
                               read_text(output / "samples.jsonl",
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


def run_r23_membership_growth_controls(controller: Any,
                                      controls: list[dict[str, str]],
                                      positives: list[str],
                                      positive_observation: dict[str, Any]
                                      ) -> dict[str, Any]:
    """Exercise only the new strict root-closure growth and fresh-retry route."""
    negative_start = len(controls)
    positive_start = len(positives)
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS
    root = (100, ticks + 100)
    child = (200, ticks + 200)

    def append_history(history: list[dict[str, Any]],
                       witnesses: list[str], snapshot: Any, *,
                       sample_index: int, attempt_index: int,
                       source_role: str) -> int:
        return controller._r23_append_snapshot_history(
            history, witnesses, snapshot, sample_index=sample_index,
            attempt_index=attempt_index, source_role=source_role)

    def table(children: list[tuple[int, int, int, str]] | None = None,
              extra: list[tuple[int, int, int, str]] | None = None,
              root_identity: tuple[int, int] = root) -> Any:
        rows = [(0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
                (root_identity[0], root_identity[1], 4, "julia.exe")]
        rows.extend(children or [])
        rows.extend(extra or [])
        return make_r20_process_table(controller, rows)

    # The unrelated row is present in outer/before and gone after. It must not
    # change the root-closed membership proof; only the newly reachable child
    # is eligible to enter the growth record.
    before = table(extra=[(900, ticks + 900, 4, "unrelated-before.exe")])
    after = table(children=[(child[0], child[1], root[0], "new-child.exe")])

    def failed_monitor(before_table: Any, after_table: Any,
                       partial_rss: int = 100) -> dict[str, Any]:
        return {
            "complete": False,
            "errors": [{
                "message": "process tree membership/generation changed during sample"}],
            "partial_rss_bytes": partial_rss,
            "measured_identities": [{
                "pid": root[0], "create_time_100ns": root[1]}],
            "native_snapshot_before_digest": native.native_snapshot_digest(
                native.validate_snapshot(before_table)),
            "native_snapshot_after_digest": native.native_snapshot_digest(
                native.validate_snapshot(after_table)),
        }

    def build_growth_history(*, accepted: Any, outer: Any,
                             failed_before: Any, failed_after: Any,
                             previous_index: int | None, sample_index: int,
                             attempt_index: int,
                             earlier_tables: list[Any] | None = None
                             ) -> tuple[list[dict[str, Any]], dict[str, int | None],
                                        list[str]]:
        history: list[dict[str, Any]] = []
        witnesses: list[str] = []
        prior_sources = list(earlier_tables or [])
        launch_source = (prior_sources[0] if prior_sources else
                         accepted if accepted is not None else outer)
        append_history(history, witnesses, launch_source,
            sample_index=0, attempt_index=0, source_role="phase_launch")
        accepted_sequence: int | None = None
        if accepted is not None:
            if type(previous_index) is not int or previous_index <= 0 or \
                    sample_index != previous_index + 1:
                raise AssertionError(
                    "synthetic R23 history only models consecutive accepted samples")
            for prior_sample in range(1, previous_index + 1):
                prior_snapshot = accepted
                append_history(history, witnesses, prior_snapshot,
                    sample_index=prior_sample, attempt_index=0,
                    source_role="outer_reconcile")
                accepted_sequence = append_history(
                    history, witnesses, prior_snapshot,
                    sample_index=prior_sample, attempt_index=1,
                    source_role="sample_source_before")
        outer_sequence = append_history(
            history, witnesses, outer, sample_index=sample_index,
            attempt_index=0, source_role="outer_reconcile")
        before_sequence = None
        if isinstance(failed_before, native.ProcessTableSnapshot):
            before_sequence = append_history(
                history, witnesses, failed_before, sample_index=sample_index,
                attempt_index=attempt_index, source_role="sample_source_before")
        after_sequence = None
        if isinstance(failed_after, native.ProcessTableSnapshot):
            after_sequence = append_history(
                history, witnesses, failed_after, sample_index=sample_index,
                attempt_index=attempt_index, source_role="sample_source_after")
        return history, {
            "accepted": accepted_sequence,
            "outer": outer_sequence,
            "before": before_sequence,
            "after": after_sequence,
        }, witnesses

    def confirm_growth(*, accepted: Any = None, outer: Any = before,
                       failed_before: Any = before, failed_after: Any = after,
                       previously_tracked: list[tuple[int, int]] | None = None,
                       previous_index: int | None = None, sample_index: int = 1,
                       attempt_index: int = 1, deadline: float | None = None,
                       monitor: dict[str, Any] | None = None,
                       earlier_tables: list[Any] | None = None,
                       history_override: list[dict[str, Any]] | None = None,
                       history_sequences_override: dict[str, int | None] | None = None,
                       witnesses_override: list[str] | None = None
                       ) -> dict[str, Any]:
        digest_before = (failed_before if isinstance(
            failed_before, native.ProcessTableSnapshot) else before)
        digest_after = (failed_after if isinstance(
            failed_after, native.ProcessTableSnapshot) else after)
        exact_failure = monitor if monitor is not None else failed_monitor(
            digest_before, digest_after)
        if history_override is None:
            history, history_sequences, witnesses = build_growth_history(
                accepted=accepted, outer=outer,
                failed_before=failed_before, failed_after=failed_after,
                previous_index=previous_index, sample_index=sample_index,
                attempt_index=attempt_index, earlier_tables=earlier_tables)
        else:
            history = history_override
            history_sequences = history_sequences_override or {}
            witnesses = witnesses_override or []
        return controller._r23_confirm_membership_growth(
            accepted, outer, failed_before, failed_after, root,
            previously_tracked if previously_tracked is not None else [root],
            previous_accepted_sample_index=previous_index,
            sample_index=sample_index, attempt_index=attempt_index,
            phase_snapshot_history=history,
            phase_snapshot_witnesses=witnesses,
            previous_accepted_source_history_sequence=
                history_sequences.get("accepted"),
            outer_reconcile_history_sequence=history_sequences.get("outer"),
            failed_attempt_before_history_sequence=history_sequences.get("before"),
            failed_attempt_after_history_sequence=history_sequences.get("after"),
            deadline_monotonic=deadline,
            partial_rss_bytes=exact_failure.get("partial_rss_bytes"),
            exact_monitor_receipt=exact_failure)

    class FakeRegistry:
        def __init__(self) -> None:
            self.opened: list[dict[str, Any]] = []
            self._handles: dict[tuple[int, int], Any] = {}
            self.identities: set[tuple[int, int]] = set()

        def for_row(self, row: Any, snapshot: Any) -> tuple[int, int]:
            identity = controller._r23_raw_identity(row)
            source = native.validate_snapshot(snapshot)
            source_row = source.by_pid.get(identity[0])
            require(source_row is not None and
                    controller._r23_raw_identity(source_row) == identity and
                    source_row.ppid == row.ppid and source_row.name == row.name,
                    "R23 growth handle open was not bound to its exact first SPI row")
            self.opened.append({"identity": identity, "snapshot": snapshot})
            self._handles[identity] = identity
            self.identities.add(identity)
            return identity

    class FakeProcess:
        def __init__(self) -> None:
            self.pid = root[0]
            self._handle = root

    def run_sample(snapshots: list[Any], earlier_tables: list[Any] | None = None
                   ) -> tuple[dict[str, Any], FakeRegistry, list[Any], list[int],
                              list[Any], list[dict[str, Any]], list[str], list[int]]:
        sequence = iter(snapshots)
        query_log: list[Any] = []
        registry = FakeRegistry()
        resource_reads: list[int] = []

        def query() -> Any:
            value = next(sequence)
            query_log.append(value)
            return value

        def resources(pid: int) -> dict[str, Any]:
            resource_reads.append(pid)
            return {"rss_bytes": 100 if pid == root[0] else 50,
                    "cpu_user_seconds": 0.2,
                    "cpu_system_seconds": 0.1,
                    "cmdline": ["synthetic"]}

        completed_sources: list[Any] = []
        completed_history_sequences: list[int] = []
        phase_history: list[dict[str, Any]] = []
        phase_witnesses: list[str] = []
        launch_snapshot = (earlier_tables[0] if earlier_tables else before)
        append_history(phase_history, phase_witnesses, launch_snapshot,
            sample_index=0, attempt_index=0, source_role="phase_launch")
        outer_history_sequence = append_history(
            phase_history, phase_witnesses, before, sample_index=1,
            attempt_index=0, source_role="outer_reconcile")
        with patch.object(native, "query_native_process_table", side_effect=query), \
                patch.object(native, "read_process_handle_identity",
                             side_effect=lambda handle: handle), \
                patch.object(native, "wait_for_process_exit",
                             side_effect=lambda handle, timeout: False), \
                patch.object(controller, "_r23_resource_reader", side_effect=resources):
            result = controller._r20_native_sample(
                FakeProcess(), registry, root, [root], sample_index=1,
                elapsed=0.0,
                deadline_monotonic=controller.time.monotonic() + 10.0,
                previous_accepted_source_snapshot=None,
                outer_reconcile_snapshot=before,
                outer_reconcile_history_sequence=outer_history_sequence,
                previous_accepted_sample_index=None,
                phase_snapshot_history=phase_history,
                phase_snapshot_witnesses=phase_witnesses,
                completed_source_snapshot_out=completed_sources,
                completed_source_snapshot_history_sequence_out=(
                    completed_history_sequences))
        return (result, registry, query_log, resource_reads, completed_sources,
                phase_history, phase_witnesses, completed_history_sequences)

    (result, registry, query_log, resource_reads, completed_sources,
     phase_history, phase_witnesses, completed_history_sequences) = run_sample(
        [before, after, after, after],
        earlier_tables=[table(extra=[(901, ticks + 901, 4,
                                       "prior-unrelated.exe")])])
    records = result.get("membership_growth_records", [])

    def observe_snapshot(snapshot: Any) -> dict[str, Any]:
        try:
            checked = native.validate_snapshot(snapshot)
            return {
                "status": "complete",
                "snapshot_receipt": controller._r23_snapshot_receipt(checked),
                "rows": [{
                    "pid": row.identity.pid,
                    "create_time_100ns": row.identity.create_time_100ns,
                    "ppid": row.ppid,
                    "name": row.name,
                } for row in checked.rows],
            }
        except Exception as error:
            return {"status": "invalid", "error_type": type(error).__name__,
                    "error": str(error)}

    try:
        witness_ledger = controller._r23_snapshot_witness_ledger_receipt(
            tuple(phase_witnesses))
    except Exception as error:
        witness_ledger = {"status": "invalid", "error_type": type(error).__name__,
                          "error": str(error)}
    positive_observation.update({
        "schema": "vnext-t2-r23-membership-growth-positive-observation-r1",
        "status": "observed_before_positive_assertions",
        "formal_t2_accepted": False,
        "julia_executed": False,
        "sample_result": {
            "sample_complete": result.get("sample_complete"),
            "sample_attempt_count": result.get("sample_attempt_count"),
            "process_tree_working_set_bytes": result.get(
                "process_tree_working_set_bytes"),
            "process_tree_user_cpu_seconds": result.get(
                "process_tree_user_cpu_seconds"),
            "process_tree_system_cpu_seconds": result.get(
                "process_tree_system_cpu_seconds"),
            "observed_process_count": result.get("observed_process_count"),
            "errors": copy.deepcopy(result.get("errors")),
            "exact_monitor_receipt": copy.deepcopy(
                result.get("exact_monitor_receipt")),
            "processes": copy.deepcopy(result.get("processes")),
            "membership_growth_records": copy.deepcopy(records),
            "membership_growth_observed_generations": copy.deepcopy(
                result.get("membership_growth_observed_generations")),
        },
        "query_source_snapshots": [observe_snapshot(item) for item in query_log],
        "resource_read_pids_in_order": list(resource_reads),
        "registry_open_attempts": [{
            "identity": list(item.get("identity", ())),
            "source_snapshot": observe_snapshot(item.get("snapshot")),
        } for item in registry.opened],
        "completed_source_snapshots": [
            observe_snapshot(item) for item in completed_sources],
        "completed_source_history_sequences": list(completed_history_sequences),
        "phase_snapshot_history": copy.deepcopy(phase_history),
        "captured_source_witnesses": list(phase_witnesses),
        "captured_source_witness_ledger": witness_ledger,
    })
    require(result.get("sample_complete") is True and
            result.get("sample_attempt_count") == 2 and
            result.get("process_tree_working_set_bytes") == 150 and
            result.get("process_tree_user_cpu_seconds") == 0.4 and
            result.get("process_tree_system_cpu_seconds") == 0.2 and
            result.get("observed_process_count") == 2 and
            len(records) == 1 and len(query_log) == 4 and
            query_log == [before, after, after, after] and
            len(completed_sources) == 1 and completed_sources[0] is after,
            "R23 did not recover a before-root-only/after-root-plus-child sample with a fresh whole retry")
    require(completed_history_sequences == [4] and
            phase_history[completed_history_sequences[0]].get(
                "source_role") == "sample_source_before" and
            phase_history[completed_history_sequences[0]].get(
                "attempt_index") == 2,
            "R23 did not retain the successful retry's exact first-source history sequence")
    require(len(phase_witnesses) == len(phase_history) and
            controller._r23_validate_snapshot_history(
                phase_history, tuple(phase_witnesses)) == phase_history and
            controller._r23_snapshot_witness_ledger_receipt(
                phase_witnesses).get("entry_count") == len(phase_history),
            "R23 synthetic phase history is not bound to its independent captured-source witnesses")
    record = records[0]
    observed = record.get("observed_generations", [])
    require(record.get("schema") == "vnext-t2-r23-membership-growth-r2" and
            record.get("growth_verified") is True and
            record.get("complete") is True and
            record.get("retry_started") is True and
            record.get("full_sample_completed_after_retry") is True and
            record.get("attempt_index") == 1 and
            record.get("full_sample_attempt_index") == 2 and
            observed == [{"pid": child[0], "create_time_100ns": child[1],
                          "ppid": root[0], "name": "new-child.exe"}] and
            record.get("partial_rss_bytes_not_credited", 0) > 0 and
            record.get("rss_credit_bytes") == 0 and
            record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            record.get("exit_code_credit_issued") is False and
            record.get("exact_handle_exit_receipt_created") is False and
            record.get("discarded_attempt", {}).get("credited_rss_bytes") == 0 and
            record.get("discarded_attempt", {}).get("credited_cpu_seconds") ==
                {"user": 0.0, "system": 0.0} and
            record.get("discarded_attempt", {}).get("exit_code_credit_issued") is False,
            "R23 growth record did not prove exact one-child addition and zero failed-attempt credit")
    history_binding = record.get("snapshot_history_binding", {})
    absence_prefix = history_binding.get("pre_growth_absence_prefix", {})
    require(absence_prefix.get("schema") ==
                "vnext-t2-r23-phase-snapshot-pid-history-prefix-r2" and
                absence_prefix.get("entry_count") == 3 and
                absence_prefix.get("first_sequence") == 0 and
                absence_prefix.get("last_sequence") == 2 and
                absence_prefix.get("captured_source_witness_ledger") ==
                    controller._r23_snapshot_witness_ledger_receipt(
                        phase_witnesses[:3]) and
                all(child[0] not in entry.get("pids", [])
                    for entry in phase_history[:3]) and
            record.get("snapshot_history_binding", {}).get(
                "failed_attempt_after_source", {}).get("sequence") == 3,
            "R23 positive did not bind an all-prior-table PID absence prefix")
    fresh = record.get("fresh_final_binding", {})
    fresh_handles = fresh.get("handle_identity_receipts", [])
    retry_history_binding = fresh.get("snapshot_history_binding", {})
    require(fresh.get("schema") ==
                "vnext-t2-r23-membership-growth-fresh-binding-r2" and
            fresh.get("complete") is True and
            fresh.get("exact_identity_count") == 2 and
            retry_history_binding.get("schema") ==
                "vnext-t2-r23-membership-growth-retry-history-binding-r2" and
            retry_history_binding.get("source_failed_attempt_after", {}).get(
                "sequence") == 3 and
            retry_history_binding.get("retry_source_before", {}).get(
                "sequence") == 4 and
            retry_history_binding.get("retry_source_after", {}).get(
                "sequence") == 5 and
            retry_history_binding.get("retry_prefix", {}).get(
                "entry_count") == 6 and
            retry_history_binding.get("retry_prefix", {}).get(
                "captured_source_witness_ledger") ==
                    controller._r23_snapshot_witness_ledger_receipt(
                        phase_witnesses[:6]) and
            {item.get("pid") for item in fresh_handles} == {root[0], child[0]} and
            {item.get("identity") for item in registry.opened if
             item.get("identity")[0] == child[0]} == {child} and
            len(registry.opened) == 3 and
            registry.opened[0].get("identity") == root and
            registry.opened[0].get("snapshot") is before and
            all(item.get("snapshot") is after for item in registry.opened[1:]) and
            resource_reads.count(root[0]) == 2 and
            resource_reads.count(child[0]) == 1 and
            result.get("exact_monitor_receipt", {}).get("complete") is True,
            "R23 retry did not bind every grown generation to fresh exact handles/resources")
    clean_final = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System")])
    growth_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], phase_history,
        phase_witnesses)
    require(growth_audit.get("complete") is True and
            growth_audit.get("record_count") == 1 and
            growth_audit.get("observed_generation_count") == 1 and
            growth_audit.get("residual_observed_generations") == [] and
            growth_audit.get("errors") == [],
            "R23 final audit did not accept the fully rebound, absent growth generation")

    # A successful outer reconciliation wait queries SPI after the outer
    # snapshot. That exact full table must be witnessed in order before the
    # sampler's first source and included in the candidate-PID absence prefix.
    reconciled_child = (150, ticks + 150)
    observer_growth_child = (250, ticks + 250)
    launch_with_tracked_child = table(children=[(
        reconciled_child[0], reconciled_child[1], root[0], "prior-child.exe")])
    outer_root_only = table()
    observer_growth_after = table(children=[(
        observer_growth_child[0], observer_growth_child[1], root[0],
        "observer-growth.exe")])
    observer_history: list[dict[str, Any]] = []
    observer_witnesses: list[str] = []
    append_history(observer_history, observer_witnesses, launch_with_tracked_child,
        sample_index=0, attempt_index=0, source_role="phase_launch")
    observer_outer_sequence = append_history(
        observer_history, observer_witnesses, outer_root_only,
        sample_index=1, attempt_index=0, source_role="outer_reconcile")

    class ObserverRegistry:
        _handles = {reconciled_child: reconciled_child}

    class ObserverProcess:
        pid = root[0]
        _handle = root

    observed_outer_queries: list[Any] = []

    def capture_outer_exit(snapshot: Any) -> None:
        observed_outer_queries.append(snapshot)
        append_history(observer_history, observer_witnesses, snapshot,
            sample_index=1, attempt_index=0,
            source_role=f"outer_tracked_exit_{len(observed_outer_queries)}")

    with patch.object(native, "read_process_handle_identity",
                      side_effect=lambda handle: handle), \
            patch.object(native, "wait_for_process_exit",
                         side_effect=lambda handle, timeout: True), \
            patch.object(native, "process_exit_code", side_effect=lambda handle: 0), \
            patch.object(native, "query_native_process_table",
                         return_value=outer_root_only):
        observer_active, observer_exits = controller._r23_reconcile_missing_tracked(
            {root, reconciled_child}, ObserverRegistry(), ObserverProcess(),
            outer_root_only, snapshot_observer=capture_outer_exit)
    observer_before_sequence = append_history(
        observer_history, observer_witnesses, outer_root_only,
        sample_index=1, attempt_index=1, source_role="sample_source_before")
    observer_after_sequence = append_history(
        observer_history, observer_witnesses, observer_growth_after,
        sample_index=1, attempt_index=1, source_role="sample_source_after")
    observer_growth = confirm_growth(
        outer=outer_root_only, failed_before=outer_root_only,
        failed_after=observer_growth_after, sample_index=1,
        history_override=observer_history,
        history_sequences_override={
            "accepted": None,
            "outer": observer_outer_sequence,
            "before": observer_before_sequence,
            "after": observer_after_sequence},
        witnesses_override=observer_witnesses)
    observer_prefix = observer_growth.get(
        "snapshot_history_binding", {}).get("pre_growth_absence_prefix", {})
    require(observer_active == [root] and len(observer_exits) == 1 and
            observer_exits[0].get("complete") is True and
            observer_exits[0].get("identity") == {
                "pid": reconciled_child[0],
                "create_time_100ns": reconciled_child[1]} and
            observer_exits[0].get("wait_confirmed") is True and
            observer_exits[0].get("exit_code") == 0 and
            observer_exits[0].get("errors") == [] and
            len(observed_outer_queries) == 1 and
            observed_outer_queries[0] is outer_root_only and
            observer_history[2].get("source_role") == "outer_tracked_exit_1" and
            observer_history[2].get("sample_index") == 1 and
            observer_history[2].get("attempt_index") == 0 and
            observer_history[3].get("source_role") == "sample_source_before" and
            observer_prefix.get("entry_count") == 4 and
            observer_prefix.get("last_sequence") == observer_before_sequence and
            observer_prefix.get("captured_source_witness_ledger") ==
                controller._r23_snapshot_witness_ledger_receipt(
                    observer_witnesses[:observer_before_sequence + 1]) and
            observer_growth.get("growth_verified") is True and
            observer_growth.get("complete") is True and
            observer_growth.get("observed_generations") == [{
                "pid": observer_growth_child[0],
                "create_time_100ns": observer_growth_child[1],
                "ppid": root[0], "name": "observer-growth.exe"}],
            "R23 did not order the exact outer tracked-exit SPI receipt before the growth absence prefix")
    positives.append(
        "R23 records exact outer tracked-exit query before the next sample and includes it in growth prefix")

    class CleanupProcess:
        pid = root[0]
        _handle = root

    def cleanup_case(*, handle_identity: tuple[int, int] = child,
                     wait_result: bool = True,
                     exit_code: int = 0) -> tuple[dict[str, Any], dict[str, Any] | None,
                                                   FakeRegistry, list[Any], list[Any], list[Any]]:
        # Reuse the exact target handle retained by the successful fresh retry.
        # Negative variants alter only that cached handle's observed identity,
        # native wait result, or native exit code.
        cleanup_registry = FakeRegistry()
        cleanup_registry._handles[child] = handle_identity
        cleanup_registry.identities.add(child)
        cleanup_registry.opened = [copy.deepcopy(item) for item in registry.opened]
        query_calls: list[Any] = []
        wait_calls: list[Any] = []
        exit_code_calls: list[Any] = []

        def query() -> Any:
            query_calls.append(clean_final)
            return clean_final

        def read_identity(handle: Any) -> tuple[int, int]:
            return tuple(handle)

        def wait(handle: Any, timeout: float) -> bool:
            wait_calls.append((handle, timeout))
            return wait_result

        def read_exit_code(handle: Any) -> int:
            exit_code_calls.append(handle)
            return exit_code

        def empty_heavy(snapshot: Any) -> dict[str, Any]:
            checked = native.validate_snapshot(snapshot)
            return {"schema": "vnext-t2-r23-global-heavy-audit-r1",
                    "complete": True, "processes": [],
                    "controller_processes": [], "native_heavy_identities": [],
                    "errors": [],
                    "snapshot": controller._r23_snapshot_receipt(checked)}

        with patch.object(native, "query_native_process_table",
                          side_effect=query), \
                patch.object(native, "read_process_handle_identity",
                             side_effect=read_identity), \
                patch.object(native, "wait_for_process_exit", side_effect=wait), \
                patch.object(native, "process_exit_code", side_effect=read_exit_code), \
                patch.object(controller, "_r23_exact_heavy_audit",
                             side_effect=empty_heavy):
            audit, termination = controller._r23_audit_and_cleanup(
                CleanupProcess(), cleanup_registry, root, {root, child}, True,
                membership_growth_records=records,
                phase_snapshot_history=phase_history,
                phase_snapshot_witnesses=phase_witnesses)
        return (audit, termination, cleanup_registry, query_calls,
                wait_calls, exit_code_calls)

    (cleanup_audit, cleanup_termination, cleanup_registry, cleanup_queries,
     cleanup_waits, cleanup_exit_reads) = cleanup_case()
    cleanup = (cleanup_termination or {}).get("unbound_cleanup", {})
    cleanup_plan = cleanup.get("plan", {})
    exit_receipts = cleanup.get("membership_growth_exact_exit_receipts", [])
    require(cleanup_audit.get("complete") is True and
            cleanup_termination is not None and
            cleanup_termination.get("complete") is True and
            cleanup.get("complete") is True and
            cleanup_plan.get("complete") is True and
            cleanup_plan.get("unresolved") == [] and
            len(exit_receipts) == 1 and
            cleanup_plan.get("membership_growth_exact_exit_receipts") ==
                exit_receipts and
            cleanup.get("post_cleanup_confirmation", {}).get(
                "plan", {}).get("membership_growth_exact_exit_receipts") ==
                exit_receipts and
            cleanup.get("post_cleanup_confirmation", {}).get("complete") is True and
            cleanup.get("post_cleanup_confirmation", {}).get("errors") == [] and
            cleanup.get("errors") == [] and
            exit_receipts[0].get("schema") ==
                "vnext-t2-r23-membership-growth-exact-exit-cleanup-r1" and
            exit_receipts[0].get("complete") is True and
            exit_receipts[0].get("identity") == {
                "pid": child[0], "create_time_100ns": child[1]} and
            exit_receipts[0].get("handle_identity_before_wait") ==
                exit_receipts[0].get("identity") and
            exit_receipts[0].get("handle_identity_after_wait") ==
                exit_receipts[0].get("identity") and
            exit_receipts[0].get("exact_wait_receipt", {}).get("complete") is True and
            exit_receipts[0].get("exact_wait_receipt", {}).get("wait_confirmed") is True and
            exit_receipts[0].get("exact_wait_receipt", {}).get("exit_code") == 0 and
            exit_receipts[0].get("exit_code") == 0 and
            exit_receipts[0].get("exit_code_credit_issued") is False and
            exit_receipts[0].get("errors") == [] and
            cleanup_audit.get("schema") ==
                "vnext-t2-r23-final-process-tree-audit-r1" and
            cleanup_queries == [clean_final, clean_final, clean_final] and
            cleanup_waits == [(child, 0.001)] and cleanup_exit_reads == [child] and
            len([item for item in cleanup_registry.opened
                 if item.get("identity") == child]) ==
                len([item for item in registry.opened
                     if item.get("identity") == child]) == 1,
            "R23 cleanup did not prove same-generation cached-handle natural exit")
    positives.append(
        "R23 cleanup resolves an absent grown generation only with exact cached-handle wait and non-STILL_ACTIVE exit")

    for label, kwargs in [
            ("cached handle is still unsignaled", {"wait_result": False}),
            ("cached handle identity was reused", {
                "handle_identity": (child[0], child[1] + 1)}),
            ("cached handle exit code is STILL_ACTIVE", {"exit_code": 259})]:
        (bad_audit, bad_termination, bad_registry, bad_queries, bad_waits,
         bad_exit_reads) = cleanup_case(**kwargs)
        bad_cleanup = (bad_termination or {}).get("unbound_cleanup", {})
        bad_plan = bad_cleanup.get("plan", {})
        bad_receipts = bad_cleanup.get("membership_growth_exact_exit_receipts", [])
        require(bad_termination is not None and
                bad_termination.get("complete") is False and
                bad_cleanup.get("complete") is False and
                bad_plan.get("complete") is False and
                bad_plan.get("membership_growth_exact_exit_receipts") ==
                    bad_receipts and
                any(item.get("pid") == child[0] and
                    item.get("expected_create_time_100ns") == child[1]
                    for item in bad_plan.get("unresolved", [])) and
                len(bad_receipts) == 1 and
                bad_receipts[0].get("complete") is False and
                bad_receipts[0].get("exit_code_credit_issued") is False and
                bad_receipts[0].get("errors") and
                bad_audit.get("schema") ==
                    "vnext-t2-r23-final-process-tree-audit-r1" and
                bad_registry.opened == registry.opened and
                len(bad_queries) == (3 if kwargs.get("exit_code") == 259 else 2) and
                not any(action.get("identity") == {
                    "pid": child[0], "create_time_100ns": child[1]}
                    for action in bad_cleanup.get("signal_attempts", [])) and
                not (kwargs.get("handle_identity") and bad_waits) and
                (kwargs.get("wait_result", True) or bad_exit_reads == []),
                f"R23 cleanup falsely resolved cached growth handle: {label}")
        controls.append({"name": f"R23 cleanup fails closed when {label}",
                         "status": "pass",
                         "rejected_as": "membership_growth_cached_handle_exit_unconfirmed"})

    positives.append(
        "R23 accepts one exact root-closed child addition only after a complete zero-credit whole-sample retry")

    def reject_growth(label: str, *, accepted: Any = None, outer: Any = before,
                      failed_before: Any = before, failed_after: Any = after,
                      previously_tracked: list[tuple[int, int]] | None = None,
                      previous_index: int | None = None, sample_index: int = 1,
                      attempt_index: int = 1, deadline: float | None = None,
                      monitor: dict[str, Any] | None = None,
                      earlier_tables: list[Any] | None = None,
                      history_override: list[dict[str, Any]] | None = None,
                      history_sequences_override: dict[str, int | None] | None = None,
                      witnesses_override: list[str] | None = None
                      ) -> dict[str, Any]:
        rejected = confirm_growth(
            accepted=accepted, outer=outer, failed_before=failed_before,
            failed_after=failed_after, previously_tracked=previously_tracked,
            previous_index=previous_index, sample_index=sample_index,
            attempt_index=attempt_index, deadline=deadline, monitor=monitor,
            earlier_tables=earlier_tables, history_override=history_override,
            history_sequences_override=history_sequences_override,
            witnesses_override=witnesses_override)
        require(rejected.get("complete") is False and
                rejected.get("growth_verified") is False and rejected.get("errors") and
                rejected.get("retry_started") is False and
                rejected.get("rss_credit_bytes") == 0 and
                rejected.get("cpu_credit_seconds") == {
                    "user": 0.0, "system": 0.0} and
                rejected.get("exit_code_credit_issued") is False,
                f"R23 accepted unsafe membership-growth source: {label}")
        controls.append({"name": f"R23 rejects unsafe membership-growth source: {label}",
                         "status": "pass", "rejected_as": "monitor_incomplete"})
        return rejected

    off_tree = table(children=[(child[0], child[1], 777, "off-tree.exe")])
    reject_growth("foreign/off-tree PID is not a root-closure addition",
                  failed_after=off_tree)

    preexisting_pid = table(extra=[(child[0], ticks + 199, 4, "prior-unrelated.exe")])
    reused_as_child = table(children=[(child[0], child[1], root[0], "new-child.exe")])
    reject_growth("added PID existed in the earlier full SPI under another row",
                  outer=preexisting_pid, failed_before=preexisting_pid,
                  failed_after=reused_as_child)

    earlier_pid_table = table(extra=[(child[0], ticks + 199, 4,
                                       "earlier-unrelated.exe")])
    old_history_record = reject_growth(
        "added PID appeared in an older full phase table outside the latest sources",
        earlier_tables=[earlier_pid_table])
    require(any("prior complete phase SPI source" in item.get("message", "")
                for item in old_history_record.get("errors", [])),
            "R23 did not reject a growth PID found only in older phase history")

    valid_history, valid_sequences, valid_witnesses = build_growth_history(
        accepted=None, outer=before, failed_before=before, failed_after=after,
        previous_index=None, sample_index=1, attempt_index=1)
    reject_growth("phase history is missing",
                  history_override=[],
                  history_sequences_override=valid_sequences,
                  witnesses_override=[])

    duplicate_history = copy.deepcopy(valid_history)
    duplicate_history[1]["sequence"] = duplicate_history[0]["sequence"]
    duplicate_witnesses = list(valid_witnesses)
    duplicate_witnesses[1] = controller._r23_snapshot_witness_bytes(
        duplicate_history[1]).decode("ascii")
    reject_growth("phase history has a duplicate/out-of-order sequence",
                  history_override=duplicate_history,
                  history_sequences_override=valid_sequences,
                  witnesses_override=duplicate_witnesses)

    reordered_sequences = dict(valid_sequences)
    reordered_sequences["after"] = valid_sequences["before"]
    reject_growth("growth-after reference is reordered before its source",
                  history_override=valid_history,
                  history_sequences_override=reordered_sequences,
                  witnesses_override=valid_witnesses)

    reject_growth("history receipt does not match the referenced raw table",
                  outer=after,
                  history_override=valid_history,
                  history_sequences_override=valid_sequences,
                  witnesses_override=valid_witnesses)

    old_child = (150, ticks + 150)
    old_before = table(children=[(old_child[0], old_child[1], root[0], "old-child.exe")])
    old_after = table(children=[(old_child[0], old_child[1], 4, "old-child.exe"),
                                (child[0], child[1], root[0], "new-child.exe")])
    reject_growth("previously accepted root member disappeared from the new closure",
                  accepted=old_before, outer=old_before, failed_before=old_before,
                  failed_after=old_after, previously_tracked=[root, old_child],
                  previous_index=1, sample_index=2)

    reused_root = table(children=[(child[0], child[1], root[0], "new-child.exe")],
                        root_identity=(root[0], root[1] + 1))
    reject_growth("phase root generation changed", failed_after=reused_root)

    predating_child = table(children=[(child[0], root[1] - 1,
                                       root[0], "predating-child.exe")])
    reject_growth("added child FILETIME predates its exact parent",
                  failed_after=predating_child)

    reject_growth("required prior accepted source missing on a later sample",
                  accepted=None, previous_index=1, sample_index=2)
    reject_growth("failed-before source missing/incomplete", failed_before=None)
    reject_growth("exact monitor membership-change receipt missing",
                  monitor={"complete": False, "errors": [], "partial_rss_bytes": 100})
    reject_growth("whole-sample retry budget already exhausted", attempt_index=2)
    reject_growth("phase deadline expired before confirmation",
                  deadline=controller.time.monotonic() - 1.0)

    def retry_failure(label: str, retry_before: Any, retry_after: Any) -> None:
        failed_retry, failed_registry, failed_queries, _, _, _, _, _ = run_sample(
            [before, after, retry_before, retry_after])
        retry_records = failed_retry.get("membership_growth_records", [])
        require(failed_retry.get("sample_complete") is False and
                failed_retry.get("sample_attempt_count") == 2 and
                failed_retry.get("process_tree_working_set_bytes") == 0 and
                failed_retry.get("process_tree_user_cpu_seconds") == 0.0 and
                failed_retry.get("process_tree_system_cpu_seconds") == 0.0 and
                len(retry_records) == 1 and
                retry_records[0].get("growth_verified") is True and
                retry_records[0].get("full_sample_completed_after_retry") is False and
                retry_records[0].get("complete") is False and
                retry_records[0].get("fresh_final_binding") is None and
                len(failed_queries) == 4,
                f"R23 granted credit or completed retry after {label}")
        controls.append({"name": f"R23 growth retry rejects {label} without credit",
                         "status": "pass", "rejected_as": "monitor_incomplete"})

    retry_missing = table()
    retry_failure("added child disappears before fresh retry", retry_missing, retry_missing)
    reused_child = table(children=[(child[0], child[1] + 1, root[0],
                                    "reused-child.exe")])
    retry_failure("added child PID is reused on fresh retry", reused_child, reused_child)
    retry_orphan = table(children=[(child[0], child[1], 777, "orphan-child.exe")])
    retry_failure("added child becomes an orphan on fresh retry", retry_orphan, retry_orphan)

    forged = copy.deepcopy(record)
    forged["observed_generations"][0]["name"] = "forged-name.exe"
    forged_audit = controller._r23_audit_membership_growth(
        clean_final, [forged], root, [root, child], phase_history,
        phase_witnesses)
    require(forged_audit.get("complete") is False and forged_audit.get("errors"),
            "R23 final audit accepted a forged added-generation row")
    controls.append({"name": "R23 final audit rejects a forged growth source row",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    forged_prefix_history = copy.deepcopy(phase_history)
    forged_prefix_history[0]["prefix_sha256"] = "0" * 64
    forged_prefix_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], forged_prefix_history,
        phase_witnesses)
    require(forged_prefix_audit.get("complete") is False and
            forged_prefix_audit.get("errors"),
            "R23 final audit accepted a forged phase-history prefix")
    controls.append({"name": "R23 final audit rejects a forged history prefix",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    missing_witness_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], phase_history,
        phase_witnesses[:-1])
    require(missing_witness_audit.get("complete") is False and
            missing_witness_audit.get("errors"),
            "R23 final audit accepted a missing captured-source witness")
    controls.append({"name": "R23 final audit rejects a missing source witness",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    changed_witnesses = list(phase_witnesses)
    changed_witnesses[0] = changed_witnesses[0][:-1] + " "
    changed_witness_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], phase_history,
        changed_witnesses)
    require(changed_witness_audit.get("complete") is False and
            changed_witness_audit.get("errors"),
            "R23 final audit accepted a changed captured-source witness")
    controls.append({"name": "R23 final audit rejects a changed source witness",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    extra_witness_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], phase_history,
        [*phase_witnesses, phase_witnesses[-1]])
    require(extra_witness_audit.get("complete") is False and
            extra_witness_audit.get("errors"),
            "R23 final audit accepted an extra captured-source witness")
    controls.append({"name": "R23 final audit rejects an extra source witness",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    reordered_witnesses = list(phase_witnesses)
    reordered_witnesses[0], reordered_witnesses[1] = (
        reordered_witnesses[1], reordered_witnesses[0])
    reordered_witness_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], phase_history,
        reordered_witnesses)
    require(reordered_witness_audit.get("complete") is False and
            reordered_witness_audit.get("errors"),
            "R23 final audit accepted reordered captured-source witnesses")
    controls.append({"name": "R23 final audit rejects reordered source witnesses",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    rehashed_history = copy.deepcopy(phase_history)
    prior_pids = set(rehashed_history[0]["pids"])
    prior_unrelated_pid = next(pid for pid in prior_pids
                               if pid not in {0, 4, root[0]})
    rehashed_history[0]["pids"] = sorted(
        (prior_pids - {prior_unrelated_pid}) | {child[0]})
    previous_prefix = None
    for sequence_index, entry in enumerate(rehashed_history):
        entry["sequence"] = sequence_index
        entry["previous_prefix_sha256"] = previous_prefix
        entry["pid_set_sha256"] = controller._r23_snapshot_history_pid_hash(
            entry["pids"])
        entry["prefix_sha256"] = controller._r23_snapshot_history_hash(entry)
        previous_prefix = entry["prefix_sha256"]
    rehashed_prefix_audit = controller._r23_audit_membership_growth(
        clean_final, records, root, [root, child], rehashed_history,
        phase_witnesses)
    require(rehashed_prefix_audit.get("complete") is False and
            rehashed_prefix_audit.get("errors"),
            "R23 final audit let a self-rehashed historical PID set detach from its bound source refs")
    controls.append({"name": "R23 final audit rejects a rehashed historical PID-set forgery",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    reordered_record = copy.deepcopy(record)
    reordered_record["snapshot_history_binding"][
        "failed_attempt_after_source"]["sequence"] = \
        reordered_record["snapshot_history_binding"][
            "failed_attempt_before_source"]["sequence"]
    reordered_history_audit = controller._r23_audit_membership_growth(
        clean_final, [reordered_record], root, [root, child], phase_history,
        phase_witnesses)
    require(reordered_history_audit.get("complete") is False and
            reordered_history_audit.get("errors"),
            "R23 final audit accepted a reordered growth-after source")
    controls.append({"name": "R23 final audit rejects reordered after-source evidence",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    reused_final = make_r20_process_table(controller, [
        (0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System"),
        (child[0], child[1] + 1, 4, "reused-final.exe")])
    reused_audit = controller._r23_audit_membership_growth(
        reused_final, records, root, [root, child], phase_history,
        phase_witnesses)
    require(reused_audit.get("complete") is False and reused_audit.get("errors"),
            "R23 final audit accepted a reused observed-growth PID")
    controls.append({"name": "R23 final audit rejects reuse of an observed-growth PID",
                     "status": "pass", "rejected_as": "incomplete_final_audit"})

    return {"positive_count": len(positives) - positive_start,
            "negative_count": len(controls) - negative_start,
            "sample_route": "_r20_native_sample",
            "record_schema": "vnext-t2-r23-membership-growth-r2",
            "source_order": ["earlier_full_history", "outer_reconcile",
                             "outer_tracked_exit_N", "failed_before", "failed_after",
                             "fresh_retry_before", "fresh_retry_after"],
            "history_schema": "vnext-t2-r23-phase-snapshot-pid-history-entry-r1",
            "history_prefix_schema":
                "vnext-t2-r23-phase-snapshot-pid-history-prefix-r2",
            "captured_source_witness_schema":
                "vnext-t2-r23-captured-source-witnesses-r1",
            "captured_source_witness_ledger_schema":
                "vnext-t2-r23-captured-source-witness-ledger-r1",
            "full_phase_history_prefix_replayed": True,
            "captured_witness_missing_extra_reordered_changed_rejected": True,
            "self_rehashed_unreferenced_history_mutation_rejected_by_witness": True,
            "outer_tracked_exit_query_witnessed_before_sample_source": True,
            "unrelated_full_table_churn_does_not_widen_root_membership_gate": True,
            "partial_rss_was_positive_and_discarded": True,
            "fresh_retry_exact_handles_and_resources_bound": True,
            "growth_final_audit_replayed": True,
            "membership_growth_exact_exit_cleanup_receipt": True,
            "cached_unsignaled_identity_mismatch_and_still_active_fail_closed": True}


def verify_r21_controller_tracked_exit_delta(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r20_r21_tracked_sample_exit_delta")
    r20_pin = receipt(R20_CONTROLLER)
    controller_source = read_text(R21_CONTROLLER, encoding="utf-8")
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
           for node in ast.parse(read_text(R20_CONTROLLER, encoding="utf-8")).body
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
    old_assignments = assignments(ast.parse(read_text(R20_CONTROLLER, encoding="utf-8")))
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
             for path in source_paths_under(leaf)}
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
    command = json.loads(read_text(leaf / "command_argv.json", encoding="utf-8"))
    exit_text = read_text(leaf / "exit_code.txt", encoding="utf-8").strip()
    stdout = read_text(leaf / "stdout.raw", encoding="utf-8")
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


def verify_r22_projection_validator_source_bindings(
        protocol: dict[str, Any], proof: dict[str, Any],
        inputs: dict[str, Any]) -> dict[str, Any]:
    logical_path = R12_PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix()
    preimage = receipt(R12_PROJECTION_REUSE_PREIMAGE)
    current = receipt(R12_PROJECTION_REUSE_VALIDATOR)
    historical = {
        "path": logical_path,
        "bytes": R12_PROJECTION_REUSE_PREIMAGE_BYTES,
        "sha256": R12_PROJECTION_REUSE_PREIMAGE_SHA256,
    }
    expected_preimage = {
        "path": R12_PROJECTION_REUSE_PREIMAGE.relative_to(ROOT).as_posix(),
        "bytes": R12_PROJECTION_REUSE_PREIMAGE_BYTES,
        "sha256": R12_PROJECTION_REUSE_PREIMAGE_SHA256,
    }
    expected_current = {
        "path": logical_path,
        "bytes": 17370,
        "sha256": "5c0082bbdf4dd6f98ebe806564c4b4c9d36572f8b9cb249a644ccd20e74467d1",
    }
    source_layout = protocol.get("source_layout")
    history = source_layout.get("historical_source_data") \
        if isinstance(source_layout, dict) else None
    bindings = {
        "historical_executed_source": historical,
        "sealed_preimage_data_input": preimage,
        "current_input": current,
        "historical_execution_allowed": False,
    }
    require(isinstance(source_layout, dict) and
            isinstance(history, dict) and logical_path not in history and
            isinstance(proof, dict),
            "R22 current validator cannot be classified as historical data")
    _source_inputs().require_local_execution(R12_PROJECTION_REUSE_VALIDATOR)
    require(preimage == expected_preimage and current == expected_current and
            inputs.get(preimage["path"]) == preimage and
            inputs.get(current["path"]) == current and
            proof.get("historical_alias_binding") == bindings,
            "R22 historical validator execution and current source pins are conflated")
    return bindings


def verify_r22_pre_tree_test_receipt(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    test = protocol.get("r22_pre_tree_tracked_exit_python_controls")
    leaf = R22_PRE_TREE_TEST_LEAF
    require(source_is_available(R22_PRE_TREE_TEST) and bool(source_paths_under(leaf)),
            "R22 focused pre-tree test source or raw leaf is absent")
    paths = {path.relative_to(leaf).as_posix(): receipt(path)
             for path in source_paths_under(leaf)}
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
    command = json.loads(read_text(leaf / "command_argv.json", encoding="utf-8"))
    stdout = read_text(leaf / "stdout.raw", encoding="utf-8")
    stderr = read_bytes(leaf / "stderr.raw")
    exit_text = read_text(leaf / "exit_code.txt", encoding="utf-8").strip()
    controller_pin = receipt(R22_CONTROLLER)
    validator_sources = verify_r22_projection_validator_source_bindings(
        protocol, test, inputs)
    validator_pin = validator_sources["historical_executed_source"]
    source_before = evidence.get("source_pins_before", {})
    source_after = evidence.get("source_pins_after", {})
    expected_source_rows = {
        R20_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R20_CONTROLLER)["sha256"],
        R21_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R21_CONTROLLER)["sha256"],
        R22_CONTROLLER.relative_to(ROOT).as_posix(): controller_pin["sha256"],
        R22_PRE_TREE_TEST.relative_to(ROOT).as_posix(): receipt(R22_PRE_TREE_TEST)["sha256"],
        R23_TABLE.relative_to(ROOT).as_posix(): receipt(R23_TABLE)["sha256"],
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): receipt(R23_SUPERVISOR)["sha256"],
    }
    positive = evidence.get("positive_control", {})
    negatives = evidence.get("negative_controls", [])
    require(evidence.get("schema") == "independent-vnext-t2-r22-pre-tree-tracked-exit-tests-r1" and
            evidence.get("status") == "pass" and evidence.get("test_exit_code") == 0 and
            evidence.get("controller_path") == R22_CONTROLLER.relative_to(ROOT).as_posix() and
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
            source_before.get(validator_pin["path"]) == validator_pin["sha256"] and
            isinstance(command, list) and evidence.get("exact_launcher_argv") == command and
            len(command) == 7 and command[1] == "-B" and
            Path(command[2]).resolve() == R22_PRE_TREE_TEST.resolve() and
            command[3] == "--output" and Path(command[4]).resolve() == leaf.resolve() and
            command[5] == "--controller" and
            Path(command[6]).resolve() == R22_CONTROLLER.resolve() and
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
            "historical_alias_binding": validator_sources,
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
    host_validator_sources = verify_r22_projection_validator_source_bindings(
        protocol, host, inputs)
    launcher_validator_sources = verify_r22_projection_validator_source_bindings(
        protocol, launcher, inputs)
    require(host_validator_sources == launcher_validator_sources,
            "R22 host and launcher validator source roles differ")
    require(source_is_available(R22_HOST_SMOKE_RUNNER) and
            source_is_available(R22_HOST_SMOKE_FIXTURE) and
            source_is_available(R22_HOST_SMOKE_QA_SNAPSHOT) and
            bool(source_paths_under(R22_HOST_SMOKE_LEAF)) and
            bool(source_paths_under(R22_HOST_SMOKE_LAUNCHER_LEAF)),
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

    inner_paths = source_paths_under(R22_HOST_SMOKE_LEAF)
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
    payload_bytes = read_bytes(inner_files["stdout.raw"])
    payload = json.loads(payload_bytes.decode("utf-8"))
    command = load(R22_HOST_SMOKE_LEAF / "command_argv.json")
    exit_receipt = load(R22_HOST_SMOKE_LEAF / "exit_code.json")
    manifest = load(R22_HOST_SMOKE_LEAF / "manifest.json")
    phase_report = load(R22_HOST_SMOKE_LEAF / "phase/phase.json")
    manifest_rows = []
    for relative, path in sorted(inner_files.items()):
        if relative == "manifest.json":
            continue
        data = read_bytes(path)
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
        "path": R22_STATIC_QA.relative_to(ROOT).as_posix(),
        "bytes": snapshot_pin["bytes"],
        "sha256": snapshot_pin["sha256"],
    }
    expected_pins = {
        "runner": exact_input(R22_HOST_SMOKE_RUNNER),
        "fixture": exact_input(R22_HOST_SMOKE_FIXTURE),
        "controller": exact_input(R22_CONTROLLER),
        "projection_validator":
            host_validator_sources["historical_executed_source"],
        "native_process_table": exact_input(R23_TABLE),
        "supervisor": exact_input(R23_SUPERVISOR),
        "static_qa": static_qa_host_pin,
        "focused_python_controls": exact_input(R22_PRE_TREE_TEST),
    }
    require(host.get("projection_validator") ==
                host_validator_sources["historical_executed_source"] and
            launcher.get("source_pins") == expected_pins,
            "R22 host/launcher raw pins do not retain the historical validator alias")
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

    outer_paths = source_paths_under(R22_HOST_SMOKE_LAUNCHER_LEAF)
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
        read_text(outer_files["command_argv.json"], encoding="utf-8"))
    process_command = json.loads(
        read_text(outer_files["outer_command_argv.json"], encoding="utf-8"))
    external = load(R22_HOST_SMOKE_LAUNCHER_LEAF / "external_exit_receipt.json")
    root_manifest = load(R22_HOST_SMOKE_LAUNCHER_LEAF / "root_manifest.json")
    inner_exit_pin = receipt(R22_HOST_SMOKE_LEAF / "exit_code.json")
    inner_manifest_pin = receipt(R22_HOST_SMOKE_LEAF / "manifest.json")
    expected_manifest_rows = []
    for relative, path in sorted(outer_files.items()):
        if relative == "root_manifest.json":
            continue
        data = read_bytes(path)
        expected_manifest_rows.append({"path": relative, "bytes": len(data),
                                       "sha256": hashlib.sha256(data).hexdigest()})
    manifest_files = root_manifest.get("files")
    names = [row.get("path") for row in manifest_files
             if isinstance(row, dict)] if isinstance(manifest_files, list) else []
    outer_stdout = read_bytes(outer_files["stdout.raw"])
    outer_stderr = read_bytes(outer_files["stderr.raw"])
    before_processes = json.loads(
        read_text(outer_files["processes_before.json"], encoding="utf-8"))
    after_processes = json.loads(
        read_text(outer_files["processes_after.json"], encoding="utf-8"))
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
    paths = source_paths_under(leaf)
    require(bool(paths), "R3 outer PowerShell invocation leaf is absent")
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
    command = json.loads(read_text(files["command_argv.json"], encoding="utf-8"))
    os_receipt = load(leaf / "os_exit_receipt.json")
    stdout = read_bytes(files["powershell.stdout.raw"])
    stderr = read_bytes(files["powershell.stderr.raw"])
    summary = json.loads(stdout.decode("utf-8"))
    launcher_path = R22_HOST_SMOKE_LAUNCHER_LEAF / "launch_host.ps1"
    launcher_pin = receipt(launcher_path)
    require(inputs.get(launcher_pin["path"]) == launcher_pin and
            launcher.get("files", {}).get("launch_host.ps1") == launcher_pin,
            "R3 PowerShell launcher is not pinned by the outer raw inventory")
    outer_command = json.loads(read_text(
        R22_HOST_SMOKE_LAUNCHER_LEAF / "outer_command_argv.json", encoding="utf-8"))
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
    invocation_validator_sources = verify_r22_projection_validator_source_bindings(
        protocol, protocol_receipt, inputs)
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
            launcher.get("historical_alias_binding") ==
                invocation_validator_sources and
            protocol_receipt.get("formal_t2_accepted") is False and
            protocol_receipt.get("julia_started") is False,
            "R3 PowerShell invocation receipt does not bind its raw files")
    return {"status": "pass", "actual_powershell_os_exit": 0,
            "invocation_timeout": False, "launcher_sha256": launcher_pin["sha256"],
            "historical_alias_binding": invocation_validator_sources,
            "file_count": len(rows), "formal_t2_accepted": False,
            "julia_executed": False}


def verify_r22_controller_pre_tree_delta(
        protocol: dict[str, Any], inputs: dict[str, Any],
        controller_source: str, controller_pin: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r21_r22_pre_tree_tracked_exit_delta")
    old_tree = ast.parse(read_text(R21_CONTROLLER, encoding="utf-8"))
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
    r20_tree = ast.parse(read_text(R20_CONTROLLER, encoding="utf-8"))
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
            inputs.get(controller_pin["path"]) == controller_pin,
            "R22 typed lane or r10/R12 consumer binding is not live")
    return {"status": "pass", "changed_functions": observed,
            "changed_assignments": assignment_delta,
            "r20_unbound_lane_ast_identical": True,
            "r21_tracked_exit_lane_ast_identical": True,
            "positive_controls": 1, "negative_controls": 9,
            "formal_t2_accepted": False, "julia_executed": False}


def run_r23_terminal_root_sample_exit_controls(
        controller: Any, controls: list[dict[str, str]],
        positives: list[str],
        positive_observation: dict[str, Any]) -> dict[str, Any]:
    """Check the terminal root resource-read disposition and its final audit."""
    negative_start = len(controls)
    positive_start = len(positives)
    native = controller._R23_TABLE
    ticks = native.WINDOWS_EPOCH_100NS
    root = (6_100, ticks + 6_100)
    child = (6_200, ticks + 6_200)
    previous = [root, child]
    limit = controller.AUTHORITY_WORKING_SET_LIMIT_BYTES
    terminal_error = (
        "exact generation exited during resource read; discard sample and "
        "require typed exact-generation recovery")

    def table(*, include_root: bool = True, include_child: bool = True,
              child_identity: tuple[int, int] = child,
              extra: list[tuple[int, int, int, str]] | None = None) -> Any:
        rows = [(0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System")]
        if include_root:
            rows.append((root[0], root[1], 4, "julia.exe"))
        if include_child:
            rows.append((child_identity[0], child_identity[1], root[0], "worker.exe"))
        rows.extend(extra or [])
        return make_r20_process_table(controller, rows)

    source = table()
    absent = table(include_root=False, include_child=False)

    def make_fixture(*, previously_tracked: list[tuple[int, int]] | None = None,
                     failure: BaseException | None = None,
                     retained_child: bool = True, waited: bool = True,
                     deadline: float | None = None,
                     absence_tables: list[Any] | None = None
                     ) -> dict[str, Any]:
        history: list[dict[str, Any]] = []
        witnesses: list[str] = []

        def append(snapshot: Any, sample_index: int, attempt_index: int,
                   source_role: str) -> int:
            return controller._r23_append_snapshot_history(
                history, witnesses, snapshot, sample_index=sample_index,
                attempt_index=attempt_index, source_role=source_role)

        append(source, 0, 0, "phase_launch")
        append(source, 1, 0, "outer_reconcile")
        accepted_sequence = append(source, 1, 1, "sample_source_before")
        outer_sequence = append(source, 2, 0, "outer_reconcile")
        source_sequence = append(source, 2, 1, "sample_source_before")
        root_handle = root
        handles = {child: child} if retained_child else {}
        bound_receipts = [{
            "pid": root[0], "create_time_100ns": root[1],
            "source_snapshot": controller._r23_snapshot_receipt(source),
        }]
        absence_iter = iter(absence_tables or [absent, absent, absent])
        resource_failure = failure or controller.psutil.NoSuchProcess(root[0])

        with patch.object(native, "read_process_handle_identity",
                          side_effect=lambda handle: handle), \
                patch.object(native, "wait_for_process_exit",
                             side_effect=lambda handle, timeout: waited), \
                patch.object(native, "process_exit_code", return_value=0):
            record = controller._r23_confirm_terminal_root_sample_exit(
                source, source, source, root,
                previously_tracked if previously_tracked is not None else previous,
                root_handle, handles,
                bound_handle_identity_receipts=bound_receipts,
                sample_index=2, attempt_index=1,
                previous_accepted_sample_index=1,
                previous_accepted_source_history_sequence=accepted_sequence,
                outer_reconcile_history_sequence=outer_sequence,
                source_history_sequence=source_sequence,
                deadline_monotonic=(deadline if deadline is not None else
                                    controller.time.monotonic() + 30.0),
                resource_failure=resource_failure,
                phase_snapshot_history=history,
                phase_snapshot_witnesses=witnesses,
                snapshot_provider=lambda: next(absence_iter))

        return {
            "record": record, "history": history, "witnesses": witnesses,
            "root_handle": root_handle, "handles": handles,
            "final_snapshot": absent, "resource_failure": resource_failure,
        }

    fixture = make_fixture()
    record = fixture["record"]
    try:
        witness_ledger = controller._r23_snapshot_witness_ledger_receipt(
            tuple(fixture["witnesses"]))
    except Exception as error:
        witness_ledger = {"status": "invalid", "error_type": type(error).__name__,
                          "error": str(error)}
    positive_observation.update({
        "schema": "vnext-t2-r23-terminal-root-sample-exit-positive-observation-r1",
        "status": "observed_before_positive_assertions",
        "formal_t2_accepted": False, "julia_executed": False,
        "sample_complete": record.get("sample_complete"),
        "retry_started": record.get("retry_started"),
        "full_sample_completed_after_retry": record.get(
            "full_sample_completed_after_retry"),
        "root_identity": copy.deepcopy(record.get("root_identity")),
        "previously_tracked_identities": copy.deepcopy(
            record.get("previously_tracked_identities")),
        "source_snapshot": copy.deepcopy(record.get("source_snapshot")),
        "source_root_closure": copy.deepcopy(record.get("source_root_closure")),
        "exact_exit_receipts": copy.deepcopy(record.get("exact_exit_receipts")),
        "absence_snapshot_count": record.get("absence_snapshot_count"),
        "absence_snapshots": copy.deepcopy(record.get("absence_snapshot_bundles")),
        "history_count": len(fixture["history"]),
        "source_witness_ledger": witness_ledger,
        "credit": {
            "rss_bytes": record.get("rss_credit_bytes"),
            "cpu_seconds": copy.deepcopy(record.get("cpu_credit_seconds")),
            "exit_code": record.get("exit_code_credit_issued"),
        },
    })
    require(record.get("complete") is True and
            record.get("schema") ==
                "vnext-t2-r23-terminal-root-sample-exit-r1" and
            record.get("sample_complete") is False and
            record.get("retry_started") is False and
            record.get("full_sample_completed_after_retry") is False and
            record.get("rss_credit_bytes") == 0 and
            record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            record.get("exit_code_credit_issued") is False and
            record.get("absence_snapshot_count") == 3 and
            len(record.get("exact_exit_receipts", [])) == len(previous),
            "R23 terminal root did not prove an uncredited exact-handle disposition")

    resource_error = {
        "phase": "sample_process_tree", "type": "MonitorIncomplete",
        "message": terminal_error,
    }
    measured = [
        {"pid": root[0], "create_time_100ns": root[1]},
        {"pid": child[0], "create_time_100ns": child[1]},
    ]
    monitor = {
        "complete": False, "sample_index": 2,
        "partial_rss_bytes": 256, "errors": [resource_error],
        "measured_identities": copy.deepcopy(measured),
        "rss_bytes": None, "numerical_credit": False,
        "solver_success_claimed": False,
    }
    record["partial_rss_bytes_not_credited"] = 256
    record["sample_failure_monitor_errors"] = [copy.deepcopy(resource_error)]
    record["discarded_attempt"] = {
        "sample_index": 2, "attempt_index": 1,
        "complete": False, "sample_complete": False,
        "observed_partial_rss_bytes_not_credited": 256,
        "measured_identities_not_credited": copy.deepcopy(measured),
        "credited_rss_bytes": 0,
        "credited_cpu_seconds": {"user": 0.0, "system": 0.0},
        "exit_code_credit_issued": False,
        "exact_monitor_receipt": copy.deepcopy(monitor),
        "errors": [copy.deepcopy(resource_error)],
    }
    terminal_partial = {
        "sample_index": 2, "sample_complete": False,
        "sample_attempt_count": 1,
        "process_tree_working_set_bytes": 0,
        "process_tree_user_cpu_seconds": 0.0,
        "process_tree_system_cpu_seconds": 0.0,
        "processes": [], "errors": [copy.deepcopy(resource_error)],
        "exact_monitor_receipt": copy.deepcopy(monitor),
        "terminal_root_sample_exit_races": [record],
    }
    prior_monitor = {
        "complete": True, "sample_index": 1,
        "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
        "errors": [],
        "discovered_identities": [
            {"pid": pid, "create_time_100ns": create_ticks}
            for pid, create_ticks in previous],
    }
    prior_sample = {
        "sample_index": 1, "sample_complete": True,
        "sample_attempt_count": 1,
        "completed_source_history_sequence":
            record["previous_accepted_source_history_sequence"],
        "completed_source_history_reference": copy.deepcopy(
            record["previous_accepted_source_history_reference"]),
        "root_process_identity": {
            "pid": root[0], "create_time_100ns": root[1]},
        "exact_monitor_receipt": prior_monitor,
        "errors": [],
    }

    def audit(candidate: dict[str, Any], *,
              completed_samples: Any = None,
              partial: dict[str, Any] | None = None) -> dict[str, Any]:
        partial_sample = copy.deepcopy(terminal_partial if partial is None else partial)
        partial_sample["terminal_root_sample_exit_races"] = [candidate]
        return controller._r23_audit_terminal_root_sample_exits(
            fixture["final_snapshot"], [candidate], root, list(previous),
            root_exit_confirmed=True, root_exit_code=0,
            working_set_limit_bytes=limit,
            root_popen_handle=fixture["root_handle"],
            retained_handles=fixture["handles"],
            completed_samples=(
                [prior_sample] if completed_samples is None else completed_samples),
            terminal_partial_sample=partial_sample,
            other_race_records=[],
            phase_snapshot_history=fixture["history"],
            phase_snapshot_witnesses=fixture["witnesses"])

    with patch.object(native, "read_process_handle_identity",
                      side_effect=lambda handle: handle), \
            patch.object(native, "wait_for_process_exit",
                         side_effect=lambda handle, timeout: True), \
            patch.object(native, "process_exit_code", return_value=0):
        accepted = audit(record)
        positive_observation["final_audit_observed_before_assertions"] = copy.deepcopy(
            accepted)
        require(accepted.get("complete") is True and
                accepted.get("record_count") == 1 and
                accepted.get("errors") == [] and
                accepted.get("validated_records", [{}])[0].get(
                    "absence_snapshot_count") == 3 and
                accepted.get("validated_records", [{}])[0].get(
                    "sample_complete") is False,
                "R23 terminal-root final audit rejected the exact completed-ledger positive")

        def reject_audit(name: str, mutate: Any, *,
                         completed_samples: Any = None) -> None:
            candidate = copy.deepcopy(record)
            partial = copy.deepcopy(terminal_partial)
            mutate(candidate, partial)
            result = audit(candidate, completed_samples=completed_samples,
                           partial=partial)
            require(result.get("complete") is False and
                    isinstance(result.get("errors"), list) and
                    bool(result["errors"]),
                    f"terminal-root final audit accepted {name}")
            controls.append({"name": f"R23 terminal-root final audit rejects {name}",
                             "status": "pass",
                             "rejected_as": "incomplete_terminal_root_final_audit"})

        reject_audit(
            "sample index that skips its prior completed sample",
            lambda candidate, partial: candidate.update({"logical_sample_index": 3}))
        reject_audit(
            "missing prior completed-sample ledger",
            lambda candidate, partial: None, completed_samples=[])
        incomplete_prior = copy.deepcopy(prior_sample)
        incomplete_prior["sample_complete"] = False
        reject_audit(
            "incomplete prior sample in the completed-sample ledger",
            lambda candidate, partial: None, completed_samples=[incomplete_prior])
        reject_audit(
            "nonempty terminal record errors",
            lambda candidate, partial: candidate.update({
                "errors": [{"phase": "forged", "message": "must fail"}]}))
        reject_audit(
            "discarded monitor errors inconsistent with the outer receipt",
            lambda candidate, partial: candidate[
                "discarded_attempt"]["exact_monitor_receipt"].update({
                    "errors": [{"phase": "tampered", "message": "changed"}]}))
        reject_audit(
            "discarded measured identities inconsistent with its monitor receipt",
            lambda candidate, partial: candidate["discarded_attempt"].update({
                "measured_identities_not_credited": []}))
        reject_audit(
            "top-level and nested discarded partial RSS mismatch",
            lambda candidate, partial: candidate.update({
                "partial_rss_bytes_not_credited": 257}))
        reject_audit(
            "top-level nonzero RSS credit",
            lambda candidate, partial: candidate.update({"rss_credit_bytes": 1}))
        reject_audit(
            "nested discarded nonzero CPU credit",
            lambda candidate, partial: candidate["discarded_attempt"].update({
                "credited_cpu_seconds": {"user": 0.1, "system": 0.0}}))

        def at_exact_cap(candidate: dict[str, Any], partial: dict[str, Any]) -> None:
            candidate["partial_rss_bytes_not_credited"] = limit
            discarded = candidate["discarded_attempt"]
            discarded["observed_partial_rss_bytes_not_credited"] = limit
            nested = discarded["exact_monitor_receipt"]
            nested["partial_rss_bytes"] = limit
            partial["exact_monitor_receipt"] = copy.deepcopy(nested)
            partial["terminal_root_sample_exit_races"] = [candidate]

        reject_audit("partial RSS equal to the hard ceiling", at_exact_cap)

    def reject_helper(name: str, **kwargs: Any) -> None:
        candidate = make_fixture(**kwargs)["record"]
        require(candidate.get("complete") is False and
                candidate.get("sample_complete") is False and
                candidate.get("retry_started") is False and
                candidate.get("rss_credit_bytes") == 0 and
                candidate.get("cpu_credit_seconds") == {
                    "user": 0.0, "system": 0.0} and
                candidate.get("exit_code_credit_issued") is False and
                bool(candidate.get("errors")),
                f"terminal-root helper accepted {name}")
        controls.append({"name": f"R23 terminal-root helper rejects {name}",
                         "status": "pass",
                         "rejected_as": "incomplete_zero_credit_terminal_disposition"})

    outsider = (6_300, ticks + 6_300)
    reject_helper("previous-active outsider omitted from exact root closure",
                  previously_tracked=[root, child, outsider])
    reject_helper("resource failure for the wrong PID",
                  failure=controller.psutil.NoSuchProcess(outsider[0]))
    reject_helper("resource failure that is not NoSuchProcess",
                  failure=PermissionError(root[0], "resource access denied"))
    reject_helper("missing retained child handle", retained_child=False)
    reject_helper("unsignaled original exact handle", waited=False)
    reused_absence = table(include_root=False, include_child=True,
                           child_identity=(child[0], child[1] + 1))
    reject_helper("PID reuse in a post-exit absence table",
                  absence_tables=[reused_absence, absent, absent])
    orphan_absence = table(include_root=False, include_child=False,
                           extra=[(6_300, ticks + 6_300, child[0], "late-worker.exe")])
    reject_helper("orphan descendant in a post-exit absence table",
                  absence_tables=[orphan_absence, absent, absent])
    reject_helper("deadline exhausted before terminal proof", deadline=0.0)

    positives.append("R23 exact terminal-root resource exit is separately audited without sample credit")
    root_lane_negative_count = len(controls) - negative_start
    root_lane_positive_count = len(positives) - positive_start
    require(root_lane_negative_count == 18 and root_lane_positive_count == 1,
            "R23 root-resource terminal controls changed while adding the R12 handoff lane")
    require(len(controls) == 144 and len(positives) == 14,
            "R12 handoff preparation changed the retained 144-negative/14-positive R23 baseline")

    descendant_negative_start = len(controls)
    descendant_positive_start = len(positives)
    descendant_observation: dict[str, Any] = {
        "schema": "vnext-t2-r23-descendant-terminal-root-positive-observation-r1",
        "status": "awaiting_run_phase_observation",
        "formal_t2_accepted": False, "julia_executed": False,
    }

    def r12_table(*, root_live: bool = True, child_live: bool = True,
                  child_identity: tuple[int, int] = child,
                  child_parent: int | None = None,
                  extra: list[tuple[int, int, int, str]] | None = None) -> Any:
        rows = [(0, ticks + 1, 0, ""), (4, ticks + 1, 0, "System")]
        if root_live:
            rows.append((root[0], root[1], 4, "julia.exe"))
        if child_live:
            rows.append((child_identity[0], child_identity[1],
                         root[0] if child_parent is None else child_parent,
                         "conhost.exe"))
        rows.extend(extra or [])
        return make_r20_process_table(controller, rows)

    live_table = r12_table()
    child_gone_root_live = r12_table(child_live=False)
    all_gone_table = r12_table(root_live=False, child_live=False)

    class R12Handle:
        def __init__(self, identity: tuple[int, int]):
            self.identity = identity

    class R12Process:
        def __init__(self) -> None:
            self.pid = root[0]
            self._handle = R12Handle(root)
            self.returncode: int | None = None

        def poll(self) -> int | None:
            if self.returncode is None and r12_state["root_gone"]:
                self.returncode = 0
            return self.returncode

        def wait(self, timeout: float | None = None) -> int:
            if not r12_state["root_gone"]:
                raise TimeoutError("synthetic R12 stage root has not exited")
            self.returncode = 0
            return self.returncode

    r12_state: dict[str, Any] = {
        "child_gone": False, "root_gone": False,
        "post_child_queries": 0, "query_count": 0,
        "query_trace": [], "resource_counts": {root[0]: 0, child[0]: 0},
        "resource_trace": [], "opened_child_handles": [],
        "closed_owned_handles": [], "registries": [],
    }
    r12_process = R12Process()
    registry_type = controller._R23_SUPERVISOR.ExactHandleRegistry

    def r12_registry_factory() -> Any:
        def opener(row: Any) -> Any:
            handle = R12Handle((row.identity.pid, row.identity.create_time_100ns))
            if handle.identity == child:
                r12_state["opened_child_handles"].append(handle)
            return handle

        def closer(handle: Any) -> None:
            r12_state["closed_owned_handles"].append(handle.identity)

        registry = registry_type(opener=opener,
                                 identity_reader=lambda handle: handle.identity,
                                 closer=closer)
        r12_state["registries"].append(registry)
        return registry

    def r12_query() -> Any:
        r12_state["query_count"] += 1
        if not r12_state["child_gone"]:
            snapshot = live_table
            role = "live_root_and_child"
        else:
            r12_state["post_child_queries"] += 1
            if r12_state["post_child_queries"] == 1:
                snapshot = child_gone_root_live
                role = "r21_absence_1_root_exact"
            else:
                r12_state["root_gone"] = True
                snapshot = all_gone_table
                role = ("r21_absence_2_root_absent" if
                        r12_state["post_child_queries"] == 2 else
                        "post_handoff_all_absent")
        checked = native.validate_snapshot(snapshot)
        r12_state["query_trace"].append({
            "index": r12_state["query_count"], "role": role,
            "root_present": root[0] in checked.by_pid,
            "child_present": child[0] in checked.by_pid,
        })
        return snapshot

    def r12_wait(handle: Any, timeout: float) -> bool:
        if handle.identity == child:
            return r12_state["child_gone"]
        if handle.identity == root:
            return r12_state["root_gone"]
        return False

    def r12_resource_reader(pid: int) -> dict[str, Any]:
        count = r12_state["resource_counts"].get(pid, 0) + 1
        r12_state["resource_counts"][pid] = count
        if pid == child[0] and count == 4:
            r12_state["child_gone"] = True
            r12_state["resource_trace"].append({
                "pid": pid, "call": count, "outcome": "NoSuchProcess"})
            raise controller.psutil.NoSuchProcess(pid)
        r12_state["resource_trace"].append({
            "pid": pid, "call": count, "outcome": "measured"})
        return {"rss_bytes": 64 if pid == root[0] else 32,
                "cpu_user_seconds": 0.01, "cpu_system_seconds": 0.0,
                "cmdline": ["synthetic-r12", str(pid)]}

    r12_helper_observations: list[dict[str, Any]] = []

    def make_r12_helper_observer(observations: list[dict[str, Any]]) -> Any:
        real_helper = controller._r23_confirm_descendant_terminal_root_sample_exit
        def observe(*args: Any, **kwargs: Any) -> Any:
            call_kwargs = dict(kwargs)
            target = args[4] if len(args) > 4 else call_kwargs.get("target_identity")
            row: dict[str, Any] = {
                "target_identity": copy.deepcopy(target),
                "absence_query_count": 0,
            }
            provider = call_kwargs.get("snapshot_provider")
            if callable(provider):
                def counted_provider() -> Any:
                    row["absence_query_count"] += 1
                    return provider()
                call_kwargs["snapshot_provider"] = counted_provider
            try:
                result = real_helper(*args, **call_kwargs)
                row.update({
                    "complete": result.get("complete"),
                    "errors": copy.deepcopy(result.get("errors")),
                    "retry_started": result.get("retry_started"),
                    "rss_credit_bytes": result.get("rss_credit_bytes"),
                    "cpu_credit_seconds": copy.deepcopy(result.get("cpu_credit_seconds")),
                    "exit_code_credit_issued": result.get("exit_code_credit_issued"),
                })
                return result
            except Exception as error:
                row.update({"raised_type": type(error).__name__,
                            "raised_message": str(error)})
                raise
            finally:
                observations.append(row)
        return observe

    with tempfile.TemporaryDirectory(prefix="r23-r12-descendant-terminal-") as temp_dir:
        output = Path(temp_dir) / "phase"
        with patch.object(controller.psutil, "Popen",
                          return_value=r12_process), \
                patch.object(controller._R23_SUPERVISOR, "ExactHandleRegistry",
                             side_effect=r12_registry_factory), \
                patch.object(native, "query_native_process_table",
                             side_effect=r12_query), \
                patch.object(native, "read_process_handle_identity",
                             side_effect=lambda handle: handle.identity), \
                patch.object(native, "wait_for_process_exit", side_effect=r12_wait), \
                patch.object(native, "process_exit_code", return_value=0), \
                patch.object(controller, "_r23_resource_reader",
                             side_effect=r12_resource_reader), \
                patch.object(controller,
                             "_r23_confirm_descendant_terminal_root_sample_exit",
                             side_effect=make_r12_helper_observer(
                                 r12_helper_observations)), \
                patch.object(controller.time, "sleep", return_value=None):
            r12_phase = controller.run_phase(
                "r23_r12_descendant_terminal_handoff",
                ["python", "-B", "synthetic-r12-descendant"],
                output, timeout_seconds=10.0,
                working_set_limit_bytes=limit,
                environment={"R23_SYNTHETIC_R12": "1"},
                legacy_fixture_only=True)
            r12_sample_rows = [json.loads(line) for line in
                read_text(output / "samples.jsonl", encoding="utf-8").splitlines()
                if line]
            terminal_path = output / "terminal_sample_race.json"
            r12_terminal_leaf = (load(terminal_path)
                                 if source_is_available(terminal_path) else None)

    def run_r12_mutated_case(name: str, target_mutator: Any) -> dict[str, Any]:
        r12_state.clear()
        r12_state.update({
            "child_gone": False, "root_gone": False,
            "post_child_queries": 0, "query_count": 0,
            "query_trace": [], "resource_counts": {root[0]: 0, child[0]: 0},
            "resource_trace": [], "opened_child_handles": [],
            "closed_owned_handles": [], "registries": [],
        })
        r12_process.returncode = None
        mutations: list[dict[str, Any]] = []
        helper_rows: list[dict[str, Any]] = []
        real_r21 = controller._r21_confirm_tracked_sample_exit
        def mutate_r21(*args: Any, **kwargs: Any) -> Any:
            record = real_r21(*args, **kwargs)
            identity = record.get("target_identity")
            if type(identity) is dict and identity == {
                    "pid": child[0], "create_time_100ns": child[1]}:
                target_mutator(record)
                mutations.append({
                    "after": copy.deepcopy(record.get("target_identity")),
                    "record": copy.deepcopy(record),
                })
            return record
        with tempfile.TemporaryDirectory(
                prefix="r23-r12-pair-" + name.replace("_", "-") + "-") as temp_dir:
            output = Path(temp_dir) / "phase"
            with patch.object(controller.psutil, "Popen",
                              return_value=r12_process), \
                    patch.object(controller._R23_SUPERVISOR, "ExactHandleRegistry",
                                 side_effect=r12_registry_factory), \
                    patch.object(native, "query_native_process_table",
                                 side_effect=r12_query), \
                    patch.object(native, "read_process_handle_identity",
                                 side_effect=lambda handle: handle.identity), \
                    patch.object(native, "wait_for_process_exit",
                                 side_effect=r12_wait), \
                    patch.object(native, "process_exit_code", return_value=0), \
                    patch.object(controller, "_r23_resource_reader",
                                 side_effect=r12_resource_reader), \
                    patch.object(controller, "_r21_confirm_tracked_sample_exit",
                                 side_effect=mutate_r21), \
                    patch.object(controller,
                                 "_r23_confirm_descendant_terminal_root_sample_exit",
                                 side_effect=make_r12_helper_observer(helper_rows)), \
                    patch.object(controller.time, "sleep", return_value=None):
                phase = controller.run_phase(
                    "r23_r12_pair_" + name,
                    ["python", "-B", "synthetic-r12-pair-" + name],
                    output, timeout_seconds=10.0,
                    working_set_limit_bytes=limit,
                    environment={"R23_SYNTHETIC_R12": "1"},
                    legacy_fixture_only=True)
                sample_path = output / "samples.jsonl"
                samples = ([json.loads(line) for line in
                            read_text(sample_path, encoding="utf-8").splitlines()
                            if line] if source_is_available(sample_path) else [])
            return {"phase": copy.deepcopy(phase),
                    "samples": copy.deepcopy(samples),
                    "mutations": mutations, "helper_rows": helper_rows}

    r12_record = (r12_terminal_leaf.get(
        "descendant_terminal_root_sample_exit")
        if isinstance(r12_terminal_leaf, dict) else None)
    r21_handoff = (r12_record.get("r21_incomplete_handoff_observation")
                   if isinstance(r12_record, dict) else None)
    r12_history = r12_phase.get("native_snapshot_pid_history", [])
    r12_witnesses = r12_phase.get("native_snapshot_source_witnesses", [])
    try:
        history_validation = controller._r23_validate_snapshot_history(
            r12_history, r12_witnesses)
    except Exception as error:
        history_validation = {"error_type": type(error).__name__,
                              "error": str(error)}
    descendant_observation.update({
        "status": "observed_before_r12_assertions",
        "phase": {key: copy.deepcopy(r12_phase.get(key)) for key in (
            "stop_reason", "exit_code", "process_tree_samples_complete",
            "process_tree_sample_count", "descendant_terminal_root_sample_exit_count",
            "descendant_terminal_root_sample_exit_final_audit",
            "final_process_tree_audit", "residual_process_audit",
            "handle_close_receipt", "native_snapshot_source_witness_ledger")},
        "completed_samples": copy.deepcopy(r12_sample_rows),
        "terminal_leaf": copy.deepcopy(r12_terminal_leaf),
        "native_query_trace": copy.deepcopy(r12_state["query_trace"]),
        "resource_trace": copy.deepcopy(r12_state["resource_trace"]),
        "history_validation": history_validation,
        "r21_handoff": copy.deepcopy(r21_handoff),
        "terminal_record": copy.deepcopy(r12_record),
        "formal_t2_accepted": False, "julia_executed": False,
    })
    wire_target = (r21_handoff.get("target_identity")
                   if isinstance(r21_handoff, dict) else None)
    helper_target = (r12_helper_observations[0].get("target_identity")
                     if len(r12_helper_observations) == 1 else None)
    pair_positive_observation = {
        "name": "adapter_accepts_exact_two_int_dict_and_calls_helper_with_tuple_pair",
        "status": "observed_before_assertions",
        "wire_target_identity": copy.deepcopy(wire_target),
        "helper_target_identity": copy.deepcopy(helper_target),
        "helper_call_count": len(r12_helper_observations),
        "helper_absence_query_count": sum(
            item.get("absence_query_count", 0) for item in r12_helper_observations),
        "helper_complete": (r12_helper_observations[0].get("complete")
                            if len(r12_helper_observations) == 1 else None),
        "helper_errors": (copy.deepcopy(r12_helper_observations[0].get("errors"))
                          if len(r12_helper_observations) == 1 else None),
    }
    descendant_observation["target_identity_pair_adapter_positive"] = \
        pair_positive_observation
    require(type(wire_target) is dict and
            set(wire_target) == {"pid", "create_time_100ns"} and
            type(wire_target["pid"]) is int and
            type(wire_target["create_time_100ns"]) is int and
            wire_target == {"pid": child[0], "create_time_100ns": child[1]} and
            type(helper_target) is tuple and helper_target == child and
            len(r12_helper_observations) == 1 and
            r12_helper_observations[0].get("complete") is True and
            r12_helper_observations[0].get("errors") == [] and
            r12_helper_observations[0].get("absence_query_count") == 3,
            "R23 real run_phase did not convert its exact wire identity to a native pair")
    pair_positive_observation["status"] = "pass_observed_run_phase_adapter"
    positive_observation["descendant_terminal_handoff"] = descendant_observation
    require(r12_phase.get("stop_reason") == "natural_exit" and
            r12_phase.get("exit_code") == 0 and
            r12_phase.get("final_process_tree_audit", {}).get(
                "root_exit_confirmed") is True,
            "R12 descendant handoff did not preserve natural exact-root exit")
    require(r12_phase.get("process_tree_sample_count") == 3 and
            r12_phase.get("process_tree_samples_complete") is True and
            len(r12_sample_rows) == 3 and
            [row.get("sample_index") for row in r12_sample_rows] == [1, 2, 3] and
            all(row.get("sample_complete") is True for row in r12_sample_rows),
            "R12 descendant handoff changed the three accepted complete samples")
    require(isinstance(r12_terminal_leaf, dict) and
            r12_terminal_leaf.get("schema") ==
                "vnext-t2-r23-terminal-descendant-root-sample-race-r1" and
            r12_terminal_leaf.get("status") ==
                "descendant_exit_then_terminal_root_proven" and
            r12_terminal_leaf.get("formal_t2_accepted") is False and
            isinstance(r12_record, dict) and r12_record.get("complete") is True and
            r12_record.get("status") ==
                "descendant_exit_then_terminal_root_proven_partial_sample_uncredited" and
            r12_record.get("sample_complete") is False and
            r12_record.get("retry_started") is False and
            r12_record.get("full_sample_completed_after_retry") is False and
            r12_record.get("whole_sample_attempt_index") == 1 and
            r12_record.get("logical_sample_index") == 4,
            "R12 terminal handoff did not remain a separate incomplete first-attempt record")
    require(isinstance(r21_handoff, dict) and
            r21_handoff.get("schema") ==
                "vnext-t2-r21-tracked-sample-exit-r1" and
            r21_handoff.get("complete") is False and
            r21_handoff.get("status") ==
                "tracked_exit_unconfirmed_monitor_incomplete" and
            r21_handoff.get("absence_snapshot_count") == 1 and
            r21_handoff.get("retry_started") is False and
            r21_handoff.get("full_sample_completed_after_retry") is False and
            r21_handoff.get("rss_credit_bytes") == 0 and
            r21_handoff.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            r21_handoff.get("exit_code_credit_issued") is False and
            r21_handoff.get("errors") == [{
                "exception_type": "ProcessTableError",
                "message": "tracked-exit confirmation 2 lost or reused the stage root",
                "pid": child[0], "stage": "r21_tracked_sample_exit_confirmation"}],
            "R12 handoff reclassified or changed the original incomplete R21 evidence")
    require(r12_record.get("trigger_resource_failure", {}).get("type") ==
                "NoSuchProcess" and
            r12_record.get("trigger_resource_failure", {}).get("pid") == child[0] and
            r12_record.get("partial_rss_bytes_not_credited", 0) > 0 and
            r12_record.get("rss_credit_bytes") == 0 and
            r12_record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            r12_record.get("exit_code_credit_issued") is False and
            r12_record.get("absence_snapshot_count") == 3 and
            len(r12_record.get("absence_checks", [])) == 3 and
            len(r12_record.get("exact_exit_receipts", [])) == 2 and
            r12_record.get("errors") == [] and
            r12_phase.get("descendant_terminal_root_sample_exit_count") == 1 and
            r12_phase.get("descendant_terminal_root_sample_exit_final_audit", {}).get(
                "complete") is True and
            r12_phase.get("final_process_tree_audit", {}).get("complete") is True and
            r12_phase.get("final_process_tree_audit", {}).get(
                "residual_descendant_processes") == [] and
            r12_phase.get("residual_process_audit", {}).get("complete") is True and
            r12_phase.get("residual_process_audit", {}).get("processes") == [] and
            r12_phase.get("handle_close_receipt", {}).get("complete") is True and
            r12_phase.get("handle_close_receipt", {}).get("errors") == [] and
            r12_phase.get("handle_close_receipt", {}).get(
                "closed_owned_handles") == [{
                    "pid": child[0], "create_time_100ns": child[1]}] and
            r12_phase.get("handle_close_receipt", {}).get(
                "popen_handles_not_owned_by_registry") == 1,
            "R12 terminal proof, cleanup, or zero-credit receipts are incomplete")
    require(len(r12_record.get("r21_probe_snapshot_bundles", [])) == 2 and
            len(r12_record.get("r21_probe_history_references", [])) == 2 and
            [entry.get("source_role") for entry in
                r12_record.get("r21_probe_snapshot_bundles", [])] == [
                    "tracked_exit_absence_1", "tracked_exit_absence_2"] and
            len(r12_record.get("source_history_references", [])) == 3 and
            len(r12_record.get("absence_snapshot_bundles", [])) == 3 and
            len(r12_record.get("absence_history_references", [])) == 3 and
            [entry.get("source_role") for entry in
                r12_record.get("absence_snapshot_bundles", [])] == [
                    "descendant_terminal_root_absence_1",
                    "descendant_terminal_root_absence_2",
                    "descendant_terminal_root_absence_3"] and
            history_validation is not None and
            isinstance(history_validation, list) and
            len(history_validation) == len(r12_witnesses) and
            r12_phase.get("native_snapshot_source_witness_ledger", {}).get(
                "complete") is True and
            r12_phase.get("native_snapshot_source_witness_ledger", {}).get(
                "entry_count") == len(r12_history) and
            len(r12_state["opened_child_handles"]) == 1 and
            r12_state["closed_owned_handles"] == [child],
            "R12 source/probe/absence witness order or exact owned-handle closure changed")
    require(r12_state["resource_counts"] == {root[0]: 4, child[0]: 4} and
            r12_state["resource_trace"][-1] == {
                "pid": child[0], "call": 4, "outcome": "NoSuchProcess"} and
            len(r12_state["query_trace"]) >= 17 and
            r12_state["query_trace"][12] == {
                "index": 13, "role": "r21_absence_1_root_exact",
                "root_present": True, "child_present": False} and
            r12_state["query_trace"][13] == {
                "index": 14, "role": "r21_absence_2_root_absent",
                "root_present": False, "child_present": False},
            "R12 positive did not observe the actual NoSuchProcess and ordered two-table handoff")
    positives.append(
        "R12 R21 failure remains incomplete while a separate run-phase terminal handoff proves exact root closure")

    def helper_attempt(*, handoff_mutator: Any | None = None,
                       observations_mutator: Any | None = None,
                       resource_failure: BaseException | None = None,
                       handles_mutator: Any | None = None,
                       wait_result: bool = True,
                       exit_code: int = 0,
                       sample_index: int = 4,
                       attempt_index: int = 1,
                       target_identity: Any = child,
                       absence_tables: list[Any] | None = None
                       ) -> dict[str, Any]:
        candidate_record = copy.deepcopy(r12_record)
        handoff = copy.deepcopy(r21_handoff)
        if handoff_mutator is not None:
            handoff_mutator(handoff)
        bundles = candidate_record["r21_probe_snapshot_bundles"]
        observations = [{
            "sequence": bundle["sequence"],
            "snapshot": controller._r22_snapshot_from_bundle(
                bundle["snapshot_bundle"]),
        } for bundle in bundles]
        if observations_mutator is not None:
            observations_mutator(observations)
        history_prefix_end = max(
            item["sequence"] for item in
            candidate_record["r21_probe_history_references"]) + 1
        history = copy.deepcopy(r12_history[:history_prefix_end])
        witnesses = copy.deepcopy(r12_witnesses[:history_prefix_end])
        source_refs = {item["role"]: item["reference"]["sequence"]
                       for item in candidate_record["source_history_references"]}
        source_table = controller._r22_snapshot_from_bundle(
            candidate_record["source_table"])
        source_receipt = candidate_record["source_snapshot"]
        exact_handles = {child: r12_state["opened_child_handles"][0]}
        if handles_mutator is not None:
            handles_mutator(exact_handles)
        bound_receipts = [{
            "pid": item["pid"],
            "create_time_100ns": item["create_time_100ns"],
            "source_snapshot": source_receipt,
        } for item in candidate_record["source_root_closure"]]
        query_tables = list(absence_tables if absence_tables is not None
                            else [all_gone_table, all_gone_table, all_gone_table])
        query_iterator = iter(query_tables)
        absence_query_count = [0]
        def counted_absence_query() -> Any:
            absence_query_count[0] += 1
            return next(query_iterator)
        with patch.object(native, "read_process_handle_identity",
                          side_effect=lambda handle: handle.identity), \
                patch.object(native, "wait_for_process_exit",
                             return_value=wait_result), \
                patch.object(native, "process_exit_code", return_value=exit_code):
            result = controller._r23_confirm_descendant_terminal_root_sample_exit(
                controller._r22_snapshot_from_bundle(
                    candidate_record["previous_accepted_source"]),
                controller._r22_snapshot_from_bundle(
                    candidate_record["outer_reconcile_source"]),
                source_table, root, target_identity, previous,
                r12_process._handle, exact_handles,
                bound_handle_identity_receipts=bound_receipts,
                sample_index=sample_index, attempt_index=attempt_index,
                previous_accepted_sample_index=3,
                previous_accepted_source_history_sequence=source_refs[
                    "previous_accepted_source"],
                outer_reconcile_history_sequence=source_refs["outer_reconcile"],
                source_history_sequence=source_refs["failed_sample_source"],
                r21_probe_record=handoff,
                r21_probe_observations=observations,
                deadline_monotonic=controller.time.monotonic() + 30.0,
                resource_failure=(resource_failure if resource_failure is not None
                                  else controller.psutil.NoSuchProcess(child[0])),
                partial_rss_bytes=candidate_record[
                    "partial_rss_bytes_not_credited"],
                working_set_limit_bytes=limit,
                phase_snapshot_history=history,
                phase_snapshot_witnesses=witnesses,
                snapshot_provider=counted_absence_query)
        return {"record": result, "history": history,
                "witnesses": witnesses, "source": source_table,
                "probe_observations": observations,
                "absence_query_count": absence_query_count[0]}

    def require_helper_rejected(name: str, **kwargs: Any) -> None:
        observed = helper_attempt(**kwargs)
        rejected = observed["record"]
        descendant_observation.setdefault("helper_negative_observations", {})[name] = {
            "complete": rejected.get("complete"),
            "status": rejected.get("status"),
            "errors": copy.deepcopy(rejected.get("errors")),
            "rss_credit_bytes": rejected.get("rss_credit_bytes"),
            "cpu_credit_seconds": copy.deepcopy(
                rejected.get("cpu_credit_seconds")),
            "exit_code_credit_issued": rejected.get("exit_code_credit_issued"),
            "retry_started": rejected.get("retry_started"),
        }
        require(rejected.get("complete") is False and
                rejected.get("sample_complete") is False and
                rejected.get("retry_started") is False and
                rejected.get("full_sample_completed_after_retry") is False and
                rejected.get("rss_credit_bytes") == 0 and
                rejected.get("cpu_credit_seconds") == {
                    "user": 0.0, "system": 0.0} and
                rejected.get("exit_code_credit_issued") is False and
                bool(rejected.get("errors")),
                f"R12 terminal helper accepted {name}")
        controls.append({"name": f"R12 terminal helper rejects {name}",
                         "status": "pass",
                         "rejected_as": "incomplete_zero_credit_terminal_handoff"})

    require_helper_rejected(
        "non-NoSuchProcess resource failure",
        resource_failure=PermissionError(child[0], "resource access denied"))
    require_helper_rejected(
        "NoSuchProcess for a different PID",
        resource_failure=controller.psutil.NoSuchProcess(outsider[0]))
    require_helper_rejected(
        "missing R21 incomplete handoff observation",
        handoff_mutator=lambda handoff: handoff.clear())
    require_helper_rejected(
        "R21 raw-query order changed without matching captured history",
        observations_mutator=lambda observations: observations.reverse())
    require_helper_rejected(
        "missing retained original child handle",
        handles_mutator=lambda handles: handles.clear())
    require_helper_rejected(
        "mismatched retained child-handle generation",
        handles_mutator=lambda handles: handles.update({
            child: R12Handle((child[0], child[1] + 1))}))
    require_helper_rejected("original closure handle wait not signaled",
                            wait_result=False)
    require_helper_rejected("original closure handle reports STILL_ACTIVE",
                            exit_code=259)
    reused_child_table = r12_table(root_live=False, child_live=True,
                                   child_identity=(child[0], child[1] + 1),
                                   child_parent=4)
    require_helper_rejected(
        "PID reuse in a new terminal absence query",
        absence_tables=[reused_child_table, all_gone_table, all_gone_table])
    orphan_child_table = r12_table(
        root_live=False, child_live=False,
        extra=[(6_300, ticks + 6_300, child[0], "orphan-worker.exe")])
    require_helper_rejected(
        "untracked descendant remains after the entire source closure disappears",
        absence_tables=[orphan_child_table, all_gone_table, all_gone_table])
    require_helper_rejected(
        "fewer than three fresh absence queries",
        absence_tables=[all_gone_table, all_gone_table])
    require_helper_rejected("extra whole-sample attempt", attempt_index=2)

    def audit_descendant(candidate: dict[str, Any],
                         partial: dict[str, Any] | None = None) -> dict[str, Any]:
        terminal_partial = copy.deepcopy(
            r12_terminal_leaf["partial_sample"] if partial is None else partial)
        terminal_partial["descendant_terminal_root_sample_exit_races"] = [candidate]
        with patch.object(native, "read_process_handle_identity",
                          side_effect=lambda handle: handle.identity), \
                patch.object(native, "wait_for_process_exit", return_value=True), \
                patch.object(native, "process_exit_code", return_value=0):
            return controller._r23_audit_descendant_terminal_root_sample_exits(
                all_gone_table, [candidate], root, list(previous),
                root_exit_confirmed=True, root_exit_code=0,
                working_set_limit_bytes=limit,
                root_popen_handle=r12_process._handle,
                retained_handles={child: r12_state["opened_child_handles"][0]},
                completed_samples=r12_sample_rows,
                terminal_partial_sample=terminal_partial,
                other_race_records=[],
                phase_snapshot_history=r12_history,
                phase_snapshot_witnesses=tuple(r12_witnesses))

    def require_audit_rejected(name: str, mutate: Any) -> None:
        candidate = copy.deepcopy(r12_record)
        partial = copy.deepcopy(r12_terminal_leaf["partial_sample"])
        mutate(candidate, partial)
        rejected = audit_descendant(candidate, partial)
        descendant_observation.setdefault("audit_negative_observations", {})[name] = {
            "complete": rejected.get("complete"),
            "errors": copy.deepcopy(rejected.get("errors")),
        }
        require(rejected.get("complete") is False and
                bool(rejected.get("errors")),
                f"R12 terminal final audit accepted {name}")
        controls.append({"name": f"R12 terminal final audit rejects {name}",
                         "status": "pass",
                         "rejected_as": "incomplete_descendant_terminal_final_audit"})

    require_audit_rejected(
        "nested failed R21 record reclassified as complete",
        lambda candidate, partial: candidate[
            "r21_incomplete_handoff_observation"].update({"complete": True}))
    require_audit_rejected(
        "R21 captured-history sequence reference drift",
        lambda candidate, partial: candidate[
            "r21_probe_history_references"][1].update({
                "sequence": candidate["r21_probe_history_references"][1][
                    "sequence"] + 1}))
    require_audit_rejected(
        "missing per-generation original-handle exit receipt",
        lambda candidate, partial: candidate["exact_exit_receipts"].pop())
    require_audit_rejected(
        "missing one of the three fresh absence witnesses",
        lambda candidate, partial: candidate["absence_snapshot_bundles"].pop())
    require_audit_rejected(
        "terminal record error or retry claim",
        lambda candidate, partial: candidate.update({
            "errors": [{"type": "forged"}], "retry_started": True}))
    require_audit_rejected(
        "nonzero nested discarded-attempt resource credit",
        lambda candidate, partial: candidate["discarded_attempt"].update({
            "credited_rss_bytes": 1}))

    supplemental_pair_controls: dict[str, Any] = {
        "schema": "vnext-t2-strict-identity-pair-controls-r1",
        "status": "observed_before_assertions",
        "consumer": {"entrypoint": "scripts/vnext_t2.py",
                     "ordered_commands": ["build", "verify", "run"]},
        "core_counts_unchanged": {"negative_controls": 162,
                                  "positive_controls": 15,
                                  "root_lane_negative_controls": 18,
                                  "root_lane_positive_controls": 1},
        "callsite_adapter": {
            "positive_observation": pair_positive_observation,
            "positive_control_count_added": 0,
            "negative_control_count": 8, "negative_observations": []},
        "native_pair_shapes": {
            "positive_control_count": 2, "positive_observations": [],
            "negative_control_count": 11, "negative_observations": []},
        "negative_control_count": 19,
        "formal_t2_accepted": False, "julia_executed": False,
    }
    descendant_observation["supplemental_pair_controls"] = supplemental_pair_controls
    def identity_mutator(value: Any) -> Any:
        def apply(record: dict[str, Any]) -> None:
            record["target_identity"] = copy.deepcopy(value)
        return apply
    cases = [
        ("run_phase_rejects_missing_pid_key_before_helper", "r21_trigger_predicate",
         lambda r: r["target_identity"].pop("pid", None), {"create_time_100ns": child[1]}),
        ("run_phase_rejects_missing_create_time_key_at_pair_adapter", "strict_pair_adapter",
         lambda r: r["target_identity"].pop("create_time_100ns", None), {"pid": child[0]}),
        ("run_phase_rejects_extra_key_at_pair_adapter", "strict_pair_adapter",
         lambda r: r["target_identity"].update({"extra": 1}),
         {"pid": child[0], "create_time_100ns": child[1], "extra": 1}),
        ("run_phase_rejects_bool_pid_before_pair_adapter", "r21_trigger_predicate",
         lambda r: r["target_identity"].update({"pid": True}),
         {"pid": True, "create_time_100ns": child[1]}),
        ("run_phase_rejects_bool_create_time_at_pair_adapter", "strict_pair_adapter",
         lambda r: r["target_identity"].update({"create_time_100ns": True}),
         {"pid": child[0], "create_time_100ns": True}),
        ("run_phase_rejects_string_pid_before_pair_adapter", "r21_trigger_predicate",
         lambda r: r["target_identity"].update({"pid": str(child[0])}),
         {"pid": str(child[0]), "create_time_100ns": child[1]}),
        ("run_phase_rejects_string_create_time_at_pair_adapter", "strict_pair_adapter",
         lambda r: r["target_identity"].update({
             "create_time_100ns": str(child[1])}),
         {"pid": child[0], "create_time_100ns": str(child[1])}),
        ("run_phase_rejects_non_dict_target_before_pair_adapter", "r21_trigger_predicate",
         identity_mutator([child[0], child[1]]), [child[0], child[1]]),
    ]
    for name, stage, mutate, expected in cases:
        observed = run_r12_mutated_case(name, mutate)
        changes, helper_rows = observed["mutations"], observed["helper_rows"]
        phase, samples = observed["phase"], observed["samples"]
        completed_sample_indices = [
            x.get("sample_index") for x in samples
            if x.get("sample_complete") is True]
        failed_sample_rows = [
            x for x in samples if x.get("sample_complete") is not True]
        sample_failure_errors = [
            error for sample in failed_sample_rows
            for error in sample.get("errors", []) if isinstance(error, dict)]
        record = changes[0]["record"] if len(changes) == 1 else None
        identity = changes[0]["after"] if len(changes) == 1 else None
        row = {
            "name": name, "status": "observed_before_assertions",
            "rejection_stage": stage,
            "expected_identity": copy.deepcopy(expected),
            "observed_identity": copy.deepcopy(identity),
            "r21_mutation_count": len(changes),
            "r21_complete": record.get("complete") if isinstance(record, dict) else None,
            "r21_errors": copy.deepcopy(record.get("errors"))
                if isinstance(record, dict) else None,
            "retry_started": record.get("retry_started")
                if isinstance(record, dict) else None,
            "rss_credit_bytes": record.get("rss_credit_bytes")
                if isinstance(record, dict) else None,
            "cpu_credit_seconds": copy.deepcopy(record.get("cpu_credit_seconds"))
                if isinstance(record, dict) else None,
            "exit_code_credit_issued": record.get("exit_code_credit_issued")
                if isinstance(record, dict) else None,
            "helper_call_count": len(helper_rows),
            "helper_absence_query_count": sum(
                item.get("absence_query_count", 0) for item in helper_rows),
            "phase_stop_reason": phase.get("stop_reason"),
            "phase_sample_count": phase.get("process_tree_sample_count"),
            "completed_sample_indices": completed_sample_indices,
            "failed_sample_rows": copy.deepcopy(failed_sample_rows),
            "sample_failure_errors": copy.deepcopy(sample_failure_errors),
            "descendant_terminal_record_count":
                phase.get("descendant_terminal_root_sample_exit_count"),
            "numerical_credit": False,
        }
        supplemental_pair_controls["callsite_adapter"]["negative_observations"].append(row)
        pair_error_messages = [
            item.get("message") for item in sample_failure_errors]
        if stage == "strict_pair_adapter":
            stage_observed = (
                "descendant-terminal target identity is not strict PID/FILETIME mapping"
                in pair_error_messages)
        else:
            stage_observed = (
                "descendant-terminal target identity is not strict PID/FILETIME mapping"
                not in pair_error_messages)
        row["observed_rejection_stage_matches"] = stage_observed
        require(len(changes) == 1 and type(identity) is type(expected) and
                identity == expected and isinstance(record, dict) and
                record.get("complete") is False and
                record.get("retry_started") is False and
                record.get("rss_credit_bytes") == 0 and
                record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                record.get("exit_code_credit_issued") is False and
                helper_rows == [] and phase.get("stop_reason") != "natural_exit" and
                phase.get("stop_reason") == "process_tree_monitor_incomplete" and
                phase.get("process_tree_samples_complete") is False and
                completed_sample_indices == [1, 2, 3] and
                len(failed_sample_rows) == 1 and
                failed_sample_rows[0].get("sample_complete") is False and
                failed_sample_rows[0].get("process_tree_working_set_bytes") == 0 and
                failed_sample_rows[0].get("process_tree_user_cpu_seconds") == 0.0 and
                failed_sample_rows[0].get("process_tree_system_cpu_seconds") == 0.0 and
                bool(sample_failure_errors) and stage_observed and
                phase.get("descendant_terminal_root_sample_exit_count") == 0,
                f"run_phase accepted malformed identity {name}")
        row["status"] = "pass_observed_fail_closed"
    require(len(supplemental_pair_controls["callsite_adapter"][
                "negative_observations"]) == 8,
            "R23 run_phase pair-control inventory changed")

    for name, identity in [
            ("native_helper_accepts_exact_two_int_tuple_pair", child),
            ("native_helper_accepts_exact_two_int_list_pair", list(child))]:
        try:
            observed = helper_attempt(target_identity=identity)
            record = observed["record"]
            row = {
                "name": name, "status": "observed_before_assertions",
                "input_type": type(identity).__name__, "input_value": copy.deepcopy(identity),
                "complete": record.get("complete"), "errors": copy.deepcopy(record.get("errors")),
                "retry_started": record.get("retry_started"),
                "sample_complete": record.get("sample_complete"),
                "absence_query_count": observed.get("absence_query_count"),
                "rss_credit_bytes": record.get("rss_credit_bytes"),
                "cpu_credit_seconds": copy.deepcopy(record.get("cpu_credit_seconds")),
                "exit_code_credit_issued": record.get("exit_code_credit_issued"),
            }
        except Exception as error:
            row = {"name": name, "status": "raised_before_assertions",
                   "input_type": type(identity).__name__,
                   "input_value": copy.deepcopy(identity),
                   "raised_type": type(error).__name__,
                   "raised_message": str(error)}
            record, observed = {}, {}
        supplemental_pair_controls["native_pair_shapes"]["positive_observations"].append(row)
        require(record.get("complete") is True and record.get("errors") == [] and
                record.get("retry_started") is False and
                record.get("sample_complete") is False and
                observed.get("absence_query_count") == 3 and
                record.get("rss_credit_bytes") == 0 and
                record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                record.get("exit_code_credit_issued") is False,
                f"native helper rejected accepted pair {name}")
        row["status"] = "pass_native_helper_pair_shape"

    bad_shapes = [
        ("native_helper_rejects_named_dict_even_with_exact_fields",
         {"pid": child[0], "create_time_100ns": child[1]}),
        ("native_helper_rejects_short_tuple", (child[0],)),
        ("native_helper_rejects_long_tuple", (child[0], child[1], 0)),
        ("native_helper_rejects_short_list", [child[0]]),
        ("native_helper_rejects_long_list", [child[0], child[1], 0]),
        ("native_helper_rejects_bool_pid", (True, child[1])),
        ("native_helper_rejects_bool_create_time", (child[0], True)),
        ("native_helper_rejects_string_pid_without_coercion",
         (str(child[0]), child[1])),
        ("native_helper_rejects_string_create_time_without_coercion",
         (child[0], str(child[1]))),
        ("native_helper_rejects_unknown_pid_generation", outsider),
        ("native_helper_rejects_same_pid_reused_filetime", (child[0], child[1] + 1)),
    ]
    for name, identity in bad_shapes:
        try:
            observed = helper_attempt(target_identity=identity)
            record = observed["record"]
            row = {
                "name": name, "status": "observed_before_assertions",
                "input_type": type(identity).__name__, "input_value": copy.deepcopy(identity),
                "complete": record.get("complete"), "errors": copy.deepcopy(record.get("errors")),
                "retry_started": record.get("retry_started"),
                "sample_complete": record.get("sample_complete"),
                "absence_query_count": observed.get("absence_query_count"),
                "rss_credit_bytes": record.get("rss_credit_bytes"),
                "cpu_credit_seconds": copy.deepcopy(record.get("cpu_credit_seconds")),
                "exit_code_credit_issued": record.get("exit_code_credit_issued"),
            }
        except Exception as error:
            row = {"name": name, "status": "raised_before_assertions",
                   "input_type": type(identity).__name__,
                   "input_value": copy.deepcopy(identity),
                   "raised_type": type(error).__name__,
                   "raised_message": str(error)}
            record, observed = {}, {}
        supplemental_pair_controls["native_pair_shapes"]["negative_observations"].append(row)
        require(record.get("complete") is False and
                record.get("sample_complete") is False and
                record.get("retry_started") is False and
                record.get("full_sample_completed_after_retry") is False and
                bool(record.get("errors")) and observed.get("absence_query_count") == 0 and
                record.get("rss_credit_bytes") == 0 and
                record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                record.get("exit_code_credit_issued") is False,
                f"native helper accepted invalid pair {name}")
        row["status"] = "pass_native_helper_rejection"
    require(len(supplemental_pair_controls["native_pair_shapes"][
                "positive_observations"]) == 2 and
            len(supplemental_pair_controls["native_pair_shapes"][
                "negative_observations"]) == 11,
            "R23 native pair-shape inventory changed")
    supplemental_pair_controls["status"] = "pass_supplemental_strict_identity_pair_controls"

    descendant_negative_count = len(controls) - descendant_negative_start
    descendant_positive_count = len(positives) - descendant_positive_start
    require(descendant_negative_count == 18 and descendant_positive_count == 1,
            "R12 descendant-terminal control inventory changed")
    descendant_observation["status"] = "pass_synthetic_r12_run_phase_handoff_controls"
    descendant_observation["negative_control_count"] = descendant_negative_count

    negative_count = len(controls) - negative_start
    positive_count = len(positives) - positive_start
    require(negative_count == root_lane_negative_count + descendant_negative_count and
            positive_count == root_lane_positive_count + descendant_positive_count and
            len(controls) == 162 and len(positives) == 15,
            "R23 terminal-root control inventory changed")
    positive_observation["status"] = "pass_synthetic_terminal_root_exit_controls"
    positive_observation["negative_control_count"] = negative_count
    return {
        "status": "pass_synthetic_terminal_root_exit_controls",
        "positive_controls": positive_count,
        "negative_controls": negative_count,
        "root_resource_positive_controls": root_lane_positive_count,
        "root_resource_negative_controls": root_lane_negative_count,
        "descendant_handoff_positive_controls": descendant_positive_count,
        "descendant_handoff_negative_controls": descendant_negative_count,
        "proof_schema": "vnext-t2-r23-terminal-root-sample-exit-r1",
        "descendant_handoff_proof_schema":
            "vnext-t2-r23-descendant-terminal-root-sample-exit-r1",
        "partial_sample_credit": False,
        "retry_claimed": False,
        "supplemental_pair_controls": supplemental_pair_controls,
        "formal_t2_accepted": False,
        "julia_executed": False,
    }


def verify_source_layout_rebase(
        protocol: dict[str, Any], inputs: dict[str, Any],
        parent_source: str, current_source: str, executable_source: str,
        parent_pin: dict[str, Any], current_pin: dict[str, Any],
        executable_pin: dict[str, Any]) -> dict[str, Any]:
    rebase = protocol.get("source_layout_rebase")
    parent_path = R23_CONTROLLER_PREIMAGE.relative_to(ROOT).as_posix()
    current_path = R23_CONTROLLER_PAIR_PREIMAGE.relative_to(ROOT).as_posix()
    executable_path = R23_CONTROLLER_LIFECYCLE_PREIMAGE.relative_to(ROOT).as_posix()
    canonical_controller_path = CONTROLLER.relative_to(ROOT).as_posix()
    expected_parent = {
        "path": parent_path, "bytes": 624265,
        "sha256": "32854f365980ed1ea981277d758cdebcd486b276d950a2f395088fefcfa9f523",
    }
    expected_current = {
        "path": current_path, "bytes": 625360,
        "sha256": "a5ba94c56af75878d07cc2136c12f4c1232804cbd8c6fe3e90ff15c27ddb7367",
    }
    expected_executable = {
        "path": executable_path, "bytes": 626070,
        "sha256": "b5a1cb43a3ba3a1c65c663530c238236018e6d5712a7a74c96ec395412577a5c",
    }
    expected_functions = [
        "_source_inputs", "input_receipts", "main", "verify_protocol"]
    added_sources = [
        "if str(ROOT) not in sys.path:\n    sys.path.insert(0, str(ROOT))",
        "from tools.execution.t2_source_inputs import T2SourceInputs",
        "_T2_SOURCE_INPUTS = None",
    ]
    added_nodes = [ast.parse(source).body[0] for source in added_sources]
    added_dumps = [ast.dump(node, include_attributes=False) for node in added_nodes]
    pair_metadata = {
        "schema": "vnext-t2-r23-descendant-target-identity-pair-adapter-r1",
        "preimage_source": current_pin, "current_source": executable_pin,
        "anchor_id": "r21_target_identity_mapping_to_strict_native_pair",
        "anchor_count": 1,
        "changed_top_level_functions": ["_r20_native_sample"],
        "changed_top_level_assignments": [],
        "accepted_mapping_keys": ["pid", "create_time_100ns"],
        "exact_positive_integer_values": True,
        "native_validator": "_R23_TABLE.validate_identity",
        "coercion_applied": False,
        "full_source_text_equal_after_anchor": True,
        "full_ast_equal_after_anchor": True,
        "consumer": {"entrypoint": "scripts/vnext_t2.py",
                     "ordered_commands": ["build", "verify", "run"]},
    }
    require(isinstance(rebase, dict) and
            parent_pin == expected_parent and
            parent_source is not None and current_pin == expected_current and
            executable_pin == expected_executable and
            inputs.get(parent_path) == parent_pin and
            inputs.get(current_path) == current_pin and
            inputs.get(executable_path) == executable_pin and
            rebase.get("main_protocol_path_guard_verified") is True and
            rebase == {
                "schema": "vnext-t2-source-layout-rebase-v1",
                "parent_source": parent_pin,
                "current_source": current_pin,
                "current_executable_source": executable_pin,
                "layer_scope": "historical_source_lineage_only",
                "original_controller_path": canonical_controller_path,
                "changed_top_level_functions": expected_functions,
                "main_protocol_path_guard_verified": True,
                "added_top_level_statements": added_dumps,
                "unaffected_top_level_ast_equal": True,
                "descendant_terminal_target_identity_pair_adapter": pair_metadata,
            },
            "R23 source-layout rebase metadata or exact source pins differ")

    parent_tree = ast.parse(parent_source)
    current_tree = ast.parse(current_source)

    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}

    parent_functions = functions(parent_tree)
    current_functions = functions(current_tree)
    changed_functions = sorted(
        name for name in parent_functions.keys() | current_functions.keys()
        if parent_functions.get(name) != current_functions.get(name))

    parent_main = next((node for node in parent_tree.body
                        if isinstance(node, ast.FunctionDef) and
                        node.name == "main"), None)
    current_main = next((node for node in current_tree.body
                         if isinstance(node, ast.FunctionDef) and
                         node.name == "main"), None)
    require(parent_main is not None and current_main is not None,
            "R23 parent/current controller main function is absent")

    def protocol_assignment_positions(function: ast.FunctionDef) -> list[int]:
        return [index for index, statement in enumerate(function.body)
                if isinstance(statement, ast.Assign) and
                len(statement.targets) == 1 and
                isinstance(statement.targets[0], ast.Name) and
                statement.targets[0].id == "protocol_path"]

    parent_protocol_positions = protocol_assignment_positions(parent_main)
    current_protocol_positions = protocol_assignment_positions(current_main)
    expected_protocol_guard = ast.parse(
        "_source_inputs().require_local_execution(Path(args.protocol))"
    ).body[0]
    expected_protocol_assignment = ast.dump(ast.parse(
        "protocol_path = Path(args.protocol).resolve()"
    ).body[0], include_attributes=False)
    expected_main_body = [ast.dump(statement, include_attributes=False)
                          for statement in parent_main.body]
    expected_main_body.insert(
        parent_protocol_positions[0] if len(parent_protocol_positions) == 1 else 0,
        ast.dump(expected_protocol_guard, include_attributes=False))
    current_main_body = [ast.dump(statement, include_attributes=False)
                         for statement in current_main.body]
    main_delta_exact = (
        len(parent_protocol_positions) == 1 and
        ast.dump(parent_main.body[parent_protocol_positions[0]],
                 include_attributes=False) == expected_protocol_assignment and
        current_protocol_positions == [parent_protocol_positions[0] + 1] and
        ast.dump(current_main.body[current_protocol_positions[0]],
                 include_attributes=False) == expected_protocol_assignment and
        current_main_body == expected_main_body)
    parent_nonfunctions = [
        ast.dump(node, include_attributes=False) for node in parent_tree.body
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
    current_nonfunctions = [
        ast.dump(node, include_attributes=False) for node in current_tree.body
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
    remaining = list(current_nonfunctions)
    for expected in added_dumps:
        require(expected in remaining,
                "R23 source-layout bootstrap statement is missing")
        remaining.remove(expected)
    unaffected_equal = remaining == parent_nonfunctions
    root_assignment_dump = ast.dump(ast.parse(
        "ROOT = Path(__file__).resolve().parents[4]").body[0],
        include_attributes=False)
    root_index = next((index for index, node in enumerate(current_tree.body)
                       if ast.dump(node, include_attributes=False) ==
                       root_assignment_dump), None)
    require(changed_functions == expected_functions and main_delta_exact and
            unaffected_equal and
            root_index is not None and [
                ast.dump(node, include_attributes=False)
                for node in current_tree.body[root_index + 1:root_index + 4]
            ] == added_dumps,
            "R23 source-layout rebase changed unapproved functions or top-level AST")

    before_anchor = (
        """            record = _r23_confirm_descendant_terminal_root_sample_exit(
                previous_accepted_source_snapshot,
                outer_reconcile_snapshot,
                source,
                root_identity,
                r21_record.get("target_identity"),
                attempt_previous,
""")
    after_anchor = (
        """            target_value = r21_record.get("target_identity")
            if (
                    type(target_value) is not dict or
                    set(target_value) != {"pid", "create_time_100ns"} or
                    type(target_value["pid"]) is not int or
                    target_value["pid"] <= 0 or
                    type(target_value["create_time_100ns"]) is not int or
                    target_value["create_time_100ns"] <= 0):
                raise _R23_TABLE.ProcessTableError(
                    "descendant-terminal target identity is not strict PID/FILETIME mapping")
            target_identity = _R23_TABLE.validate_identity(
                (target_value["pid"], target_value["create_time_100ns"]))
            record = _r23_confirm_descendant_terminal_root_sample_exit(
                previous_accepted_source_snapshot,
                outer_reconcile_snapshot,
                source,
                root_identity,
                target_identity,
                attempt_previous,
""")
    anchor_count = current_source.count(before_anchor)
    require(anchor_count == 1, "R23 strict pair source anchor is missing or ambiguous")
    expected_pair_source = current_source.replace(before_anchor, after_anchor, 1)
    pair_text_equal = executable_source == expected_pair_source
    pair_before_tree, pair_after_tree = ast.parse(current_source), ast.parse(executable_source)
    before_functions = {n.name: ast.dump(n, include_attributes=False)
                        for n in pair_before_tree.body
                        if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
    after_functions = {n.name: ast.dump(n, include_attributes=False)
                       for n in pair_after_tree.body
                       if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))}
    pair_changed = sorted(name for name in before_functions.keys() | after_functions.keys()
                          if before_functions.get(name) != after_functions.get(name))
    pair_ast_equal = ast.dump(pair_after_tree, include_attributes=False) == ast.dump(
        ast.parse(expected_pair_source), include_attributes=False)
    def assignment_map(tree: ast.Module) -> dict[str, str]:
        return {n.targets[0].id: ast.dump(n, include_attributes=False)
                for n in tree.body if isinstance(n, ast.Assign) and
                len(n.targets) == 1 and isinstance(n.targets[0], ast.Name)}
    before_assignments, after_assignments = assignment_map(pair_before_tree), assignment_map(pair_after_tree)
    pair_assignment_delta = sorted(name for name in before_assignments.keys() | after_assignments.keys()
                                   if before_assignments.get(name) != after_assignments.get(name))
    require(pair_text_equal and pair_ast_equal and
            pair_changed == ["_r20_native_sample"] and pair_assignment_delta == [],
            "R23 executable differs from the exact PID/FILETIME adapter source")
    pair_observed = copy.deepcopy(pair_metadata)
    pair_observed.update({
        "anchor_count": anchor_count,
        "full_source_text_equal_after_anchor": pair_text_equal,
        "full_ast_equal_after_anchor": pair_ast_equal,
        "changed_top_level_functions": pair_changed,
        "changed_top_level_assignments": pair_assignment_delta,
    })
    return {
        "status": "pass",
        "parent_source": parent_pin,
        "current_source": current_pin,
        "current_executable_source": executable_pin,
        "layer_scope": "historical_source_lineage_only",
        "changed_top_level_functions": changed_functions,
        "main_protocol_local_guard_inserted_before_resolve": main_delta_exact,
        "added_top_level_statements": added_dumps,
        "unaffected_top_level_ast_equal": unaffected_equal,
        "descendant_terminal_target_identity_pair_adapter": pair_observed,
        "julia_executed": False,
        "formal_t2_accepted": False,
    }


def verify_managed_process_lifecycle_controller_delta(
        protocol: dict[str, Any], inputs: dict[str, Any],
        historical_source: str, current_source: str,
        historical_pin: dict[str, Any], current_pin: dict[str, Any]) -> dict[str, Any]:
    historical_path = R23_CONTROLLER_LIFECYCLE_PREIMAGE.relative_to(ROOT).as_posix()
    current_path = CONTROLLER.relative_to(ROOT).as_posix()
    expected_historical = {
        "path": historical_path, "bytes": 626070,
        "sha256": "b5a1cb43a3ba3a1c65c663530c238236018e6d5712a7a74c96ec395412577a5c",
    }
    expected_current = {
        "path": current_path, "bytes": 677366,
        "sha256": "a1cdf6e97a51b67c4369779ad258afa5943c0f92d76d8295e1fa2a84c6cf998c",
    }
    require(historical_pin == expected_historical and
            current_pin == expected_current and
            inputs.get(historical_path) == historical_pin and
            inputs.get(current_path) == current_pin and
            historical_source is not None and current_source is not None,
            "managed controller lifecycle source receipts differ from frozen inputs")

    old_tree = ast.parse(historical_source)
    new_tree = ast.parse(current_source)

    sample_cap_assignments = [
        node for node in new_tree.body
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and
        isinstance(node.targets[0], ast.Name) and
        node.targets[0].id == "R20_MAX_WHOLE_SAMPLE_ATTEMPTS",
    ]
    natural_functions = [
        node for node in new_tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and
        node.name == "require_natural",
    ]
    require(
        len(sample_cap_assignments) == 1 and
        type(ast.literal_eval(sample_cap_assignments[0].value)) is int and
        ast.literal_eval(sample_cap_assignments[0].value) == 2 and
        len(natural_functions) == 1,
        "managed controller whole-sample retry cap binding is not unique/frozen")
    natural_names = [
        node for node in ast.walk(natural_functions[0])
        if isinstance(node, ast.Name)
    ]
    require(
        any(node.id == "R20_MAX_WHOLE_SAMPLE_ATTEMPTS" and
            isinstance(node.ctx, ast.Load) for node in natural_names) and
        not any(node.id == "_R20_MAX_WHOLE_SAMPLE_ATTEMPTS" and
                isinstance(node.ctx, ast.Load) for node in natural_names) and
        not any(node.id == "R20_MAX_WHOLE_SAMPLE_ATTEMPTS" and
                isinstance(node.ctx, ast.Store) for node in natural_names),
        "require_natural does not resolve the frozen whole-sample retry cap")

    def named_nodes(tree: ast.Module, node_type: type | tuple[type, ...]) -> dict[str, str]:
        result: dict[str, str] = {}
        for node in tree.body:
            if isinstance(node, node_type):
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef,
                                     ast.ClassDef)):
                    name = node.name
                elif isinstance(node, ast.Assign):
                    if len(node.targets) != 1 or not isinstance(node.targets[0], ast.Name):
                        continue
                    name = node.targets[0].id
                elif isinstance(node, ast.AnnAssign):
                    if not isinstance(node.target, ast.Name):
                        continue
                    name = node.target.id
                else:
                    continue
                require(name not in result,
                        f"managed lifecycle source has duplicate top-level name: {name}")
                result[name] = ast.dump(node, include_attributes=False)
        return result

    old_functions = named_nodes(old_tree, (ast.FunctionDef, ast.AsyncFunctionDef))
    new_functions = named_nodes(new_tree, (ast.FunctionDef, ast.AsyncFunctionDef))
    changed_functions = sorted(
        name for name in old_functions.keys() | new_functions.keys()
        if old_functions.get(name) != new_functions.get(name))
    added_functions = sorted(new_functions.keys() - old_functions.keys())
    removed_functions = sorted(old_functions.keys() - new_functions.keys())

    old_assignments = named_nodes(old_tree, ast.Assign)
    new_assignments = named_nodes(new_tree, ast.Assign)
    changed_assignments = sorted(
        name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    added_assignments = sorted(new_assignments.keys() - old_assignments.keys())
    removed_assignments = sorted(old_assignments.keys() - new_assignments.keys())

    old_annotated = named_nodes(old_tree, ast.AnnAssign)
    new_annotated = named_nodes(new_tree, ast.AnnAssign)
    changed_annotated = sorted(
        name for name in old_annotated.keys() | new_annotated.keys()
        if old_annotated.get(name) != new_annotated.get(name))
    added_annotated = sorted(new_annotated.keys() - old_annotated.keys())
    removed_annotated = sorted(old_annotated.keys() - new_annotated.keys())

    old_classes = named_nodes(old_tree, ast.ClassDef)
    new_classes = named_nodes(new_tree, ast.ClassDef)
    changed_classes = sorted(
        name for name in old_classes.keys() | new_classes.keys()
        if old_classes.get(name) != new_classes.get(name))
    added_classes = sorted(new_classes.keys() - old_classes.keys())
    removed_classes = sorted(old_classes.keys() - new_classes.keys())

    def import_nodes(tree: ast.Module) -> list[str]:
        return [ast.dump(node, include_attributes=False) for node in tree.body
                if isinstance(node, (ast.Import, ast.ImportFrom))]

    old_imports, new_imports = import_nodes(old_tree), import_nodes(new_tree)

    def import_delta(before: list[str], after: list[str]) -> tuple[list[str], list[str]]:
        def counts(values: list[str]) -> dict[str, int]:
            out: dict[str, int] = {}
            for value in values:
                out[value] = out.get(value, 0) + 1
            return out
        before_counts, after_counts = counts(before), counts(after)
        added = [value for value in sorted(before_counts.keys() | after_counts.keys())
                 for _ in range(max(0, after_counts.get(value, 0) -
                                      before_counts.get(value, 0)))]
        removed = [value for value in sorted(before_counts.keys() | after_counts.keys())
                   for _ in range(max(0, before_counts.get(value, 0) -
                                        after_counts.get(value, 0)))]
        return added, removed

    added_import_dumps, removed_import_dumps = import_delta(old_imports, new_imports)

    def assignment_name(node: ast.AST) -> str | None:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                isinstance(node.targets[0], ast.Name):
            return node.targets[0].id
        return None

    def annotated_name(node: ast.AST) -> str | None:
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            return node.target.id
        return None

    changed_function_names = set(changed_functions)
    changed_assignment_names = set(changed_assignments)
    changed_annotated_names = set(changed_annotated)
    changed_class_names = set(added_classes) | set(removed_classes) | set(
        name for name in old_classes.keys() & new_classes.keys()
        if old_classes[name] != new_classes[name])
    changed_import_dumps = set(added_import_dumps) | set(removed_import_dumps)

    def unapproved_nodes(tree: ast.Module) -> list[str]:
        values = []
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and \
                    node.name in changed_function_names:
                continue
            assignment = assignment_name(node)
            if assignment is not None and assignment in changed_assignment_names:
                continue
            annotated = annotated_name(node)
            if annotated is not None and annotated in changed_annotated_names:
                continue
            if isinstance(node, ast.ClassDef) and node.name in changed_class_names:
                continue
            if isinstance(node, (ast.Import, ast.ImportFrom)) and \
                    ast.dump(node, include_attributes=False) in changed_import_dumps:
                continue
            values.append(ast.dump(node, include_attributes=False))
        return values

    all_unapproved_equal = unapproved_nodes(old_tree) == unapproved_nodes(new_tree) and \
        [ast.dump(node, include_attributes=False)
         for node in old_tree.type_ignores] == \
        [ast.dump(node, include_attributes=False)
         for node in new_tree.type_ignores]

    expected_changed_functions = sorted([
        "_load_managed_lifecycle", "_r20_native_sample", "_r23_audit_and_cleanup",
        "_r23_exact_heavy_audit", "_r23_final_audit", "_r23_handle_for_identity",
        "_r23_root_handle", "_r23_validate_snapshot_history",
        "configure_managed_lifecycle", "git_head", "main", "require_natural",
        "run_phase",
    ])
    expected_added_functions = sorted([
        "_load_managed_lifecycle", "_r23_root_handle", "configure_managed_lifecycle",
    ])
    expected_changed_assignments = sorted([
        "_R23_LIFECYCLE_PATH", "_R23_LIFECYCLE_RELATIVE_PATH",
        "_R23_SUPERVISOR_SHA256",
    ])
    expected_added_assignments = sorted([
        "_R23_LIFECYCLE_PATH", "_R23_LIFECYCLE_RELATIVE_PATH",
    ])
    expected_added_annotated_statements = [
        "_R23_ACTIVE_PROTOCOL: dict[str, Any] | None = None",
        "_R23_ACTIVE_PROTOCOL_SHA256: str | None = None",
        "_R23_MANAGED_LIFECYCLE: Any | None = None",
    ]
    expected_added_annotated = sorted(
        ast.parse(source).body[0].target.id
        for source in expected_added_annotated_statements)
    expected_added_import_statements = [
        "import msvcrt", "import secrets", "from typing import Any, Mapping",
    ]
    expected_removed_import_statements = ["from typing import Any"]
    expected_added_imports = sorted(ast.dump(ast.parse(source).body[0],
                                               include_attributes=False)
                                    for source in expected_added_import_statements)
    expected_removed_imports = sorted(ast.dump(ast.parse(source).body[0],
                                                  include_attributes=False)
                                      for source in expected_removed_import_statements)
    expected_added_classes = ["_R23ManagedObserver"]

    observed = {
        "schema": "vnext-t2-managed-controller-source-delta-v1",
        "historical_predecessor_source": historical_pin,
        "current_source": current_pin,
        "changed_top_level_functions": changed_functions,
        "added_functions": added_functions,
        "removed_functions": removed_functions,
        "changed_top_level_assignments": changed_assignments,
        "added_top_level_assignments": added_assignments,
        "removed_top_level_assignments": removed_assignments,
        "added_top_level_annotated_assignments": added_annotated_statements,
        "removed_top_level_annotated_assignments": removed_annotated,
        "added_import_statements": expected_added_import_statements,
        "removed_import_statements": expected_removed_import_statements,
        "added_classes": added_classes,
        "removed_classes": removed_classes,
        "all_unapproved_top_level_ast_equal": all_unapproved_equal,
    }
    expected = {
        "schema": "vnext-t2-managed-controller-source-delta-v1",
        "historical_predecessor_source": expected_historical,
        "current_source": expected_current,
        "changed_top_level_functions": expected_changed_functions,
        "added_functions": expected_added_functions,
        "removed_functions": [],
        "changed_top_level_assignments": expected_changed_assignments,
        "added_top_level_assignments": expected_added_assignments,
        "removed_top_level_assignments": [],
        "added_top_level_annotated_assignments": expected_added_annotated_statements,
        "removed_top_level_annotated_assignments": [],
        "added_import_statements": expected_added_import_statements,
        "removed_import_statements": expected_removed_import_statements,
        "added_classes": expected_added_classes,
        "removed_classes": [],
        "all_unapproved_top_level_ast_equal": True,
    }
    require(changed_functions == expected_changed_functions and
            added_functions == expected_added_functions and not removed_functions and
            changed_assignments == expected_changed_assignments and
            added_assignments == expected_added_assignments and not removed_assignments and
            changed_annotated == expected_added_annotated and
            added_annotated == expected_added_annotated and not removed_annotated and
            changed_classes == expected_added_classes and
            added_classes == expected_added_classes and not removed_classes and
            added_import_dumps == expected_added_imports and
            removed_import_dumps == expected_removed_imports and
            all_unapproved_equal and
            protocol.get("managed_process_lifecycle_controller_delta") == expected,
            "managed lifecycle controller source delta contains an unapproved change")
    return {
        "status": "pass_source_delta_only",
        "historical_predecessor_source": historical_pin,
        "current_source": current_pin,
        "observed_ast_delta": observed,
        "formal_t2_accepted": False,
        "julia_executed": False,
    }


def verify_r22_r23_membership_growth_delta(
        protocol: dict[str, Any], inputs: dict[str, Any],
        r22_source: str, r23_source: str,
        r22_pin: dict[str, Any], r23_pin: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r22_r23_membership_growth_delta")
    old_tree = ast.parse(r22_source)
    new_tree = ast.parse(r23_source)
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in old_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in new_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected = [
        "_r20_native_sample", "_r23_append_snapshot_history",
        "_r23_audit_and_cleanup",
        "_r23_audit_descendant_terminal_root_sample_exits",
        "_r23_audit_membership_growth",
        "_r23_audit_terminal_root_sample_exits",
        "_r23_bind_membership_growth_retry",
        "_r23_confirm_descendant_terminal_root_sample_exit",
        "_r23_confirm_membership_growth",
        "_r23_confirm_terminal_root_sample_exit",
        "_r23_final_audit", "_r23_membership_growth_retry_binding",
        "_r23_monitor_digest_matches", "_r23_observed_root_reachable_rows",
        "_r23_reconcile_missing_tracked", "_r23_root_closure_rows",
        "_r23_row_evidence", "_r23_snapshot_bundle", "_r23_snapshot_from_bundle",
        "_r23_snapshot_history_hash", "_r23_snapshot_history_pid_hash",
        "_r23_snapshot_history_prefix_receipt", "_r23_snapshot_history_reference",
        "_r23_snapshot_witness_bytes", "_r23_snapshot_witness_ledger_receipt",
        "_r23_terminal_root_closure_rows",
        "_r23_validate_snapshot_history", "_r23_verify_snapshot_history_reference",
        "_r23_wait_gone", "run_phase", "verify_protocol",
    ]

    def assignments(tree: ast.Module) -> dict[str, str]:
        return {node.targets[0].id: ast.dump(node, include_attributes=False)
                for node in tree.body if isinstance(node, ast.Assign) and
                len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)}

    old_assignments, new_assignments = assignments(old_tree), assignments(new_tree)
    assignment_delta = sorted(
        name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    expected_assignments = ["R22_CONTROLLER_RELATIVE_PATH",
                            "R23_CONTROLLER_RELATIVE_PATH"]
    r20_tree = ast.parse(read_text(R20_CONTROLLER, encoding="utf-8"))
    r21_tree = ast.parse(read_text(R21_CONTROLLER, encoding="utf-8"))
    r20_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in r20_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    r21_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in r21_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    preserved_r20 = ["_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race", "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows", "_r20_valid_snapshot_receipt"]
    preserved_r21 = ["_r21_audit_tracked_sample_exit_races",
                     "_r21_confirm_tracked_sample_exit"]
    preserved_r22 = ["_r22_audit_pre_tree_tracked_exit_races",
        "_r22_confirm_pre_tree_tracked_exit", "_r22_snapshot_bundle",
        "_r22_snapshot_from_bundle", "_r22_tracked_closure"]
    sample_node = next(node for node in new_tree.body
                       if isinstance(node, ast.FunctionDef) and
                       node.name == "_r20_native_sample")
    phase_node = next(node for node in new_tree.body
                      if isinstance(node, ast.FunctionDef) and node.name == "run_phase")
    final_audit_node = next(node for node in new_tree.body
                            if isinstance(node, ast.FunctionDef) and
                            node.name == "_r23_final_audit")
    terminal_audit_node = next(node for node in new_tree.body
                               if isinstance(node, ast.FunctionDef) and
                               node.name == "_r23_audit_terminal_root_sample_exits")
    descendant_terminal_audit_node = next(
        node for node in new_tree.body
        if isinstance(node, ast.FunctionDef) and
        node.name == "_r23_audit_descendant_terminal_root_sample_exits")

    def calls_named(node: ast.AST, function_name: str) -> bool:
        return any(isinstance(child, ast.Call) and
                   ast.unparse(child.func) == function_name
                   for child in ast.walk(node))

    phase_source = ast.unparse(phase_node)
    terminal_disposition = (delta.get("terminal_root_sample_exit_disposition")
                            if isinstance(delta, dict) else None)
    descendant_terminal_disposition = (
        delta.get("descendant_terminal_root_sample_exit_disposition")
        if isinstance(delta, dict) else None)
    terminal_failure_paths = {
        "outer_receipt": ROOT / (
            "runs/UP1-04A-VNEXT-T2/"
            "formal_launcher_r23_direct_git_r9_20260926_r1/external_exit_receipt.json"),
        "pipeline_final": ROOT / (
            "runs/UP1-04A-VNEXT-T2/"
            "formal_t2_actual_negative_r23_direct_git_r9/pipeline_final.json"),
        "preservation_manifest": ROOT / "runs/e/t2r23p9/manifest.json",
    }
    terminal_failure_pins = {
        role: receipt(path) for role, path in terminal_failure_paths.items()}
    descendant_terminal_failure_paths = {
        "outer_receipt": ROOT / (
            "runs/UP1-04A-VNEXT-T2/"
            "formal_launcher_r23_terminal_root_r12_20260926_r1/external_exit_receipt.json"),
        "pipeline_final": ROOT / (
            "runs/UP1-04A-VNEXT-T2/"
            "formal_t2_actual_negative_r23_terminal_root_r12/pipeline_final.json"),
        "preservation_manifest": ROOT / "runs/e/t2r23p12/manifest.json",
    }
    descendant_terminal_failure_pins = {
        role: receipt(path)
        for role, path in descendant_terminal_failure_paths.items()}
    require(isinstance(delta, dict) and
            delta.get("schema") ==
                "vnext-t2-r22-r23-membership-growth-delta-r1" and
            delta.get("r22_source") == r22_pin and
            delta.get("r23_source") == r23_pin and
            inputs.get(r22_pin["path"]) == r22_pin and
            inputs.get(r23_pin["path"]) == r23_pin and
            changed == expected and
            delta.get("changed_top_level_functions") == expected and
            assignment_delta == expected_assignments and
            delta.get("changed_top_level_assignments") == expected_assignments and
            all(r20_functions.get(name) == new_functions.get(name)
                for name in preserved_r20) and
            all(r21_functions.get(name) == new_functions.get(name)
                for name in preserved_r21) and
            all(old_functions.get(name) == new_functions.get(name)
                for name in preserved_r22) and
            calls_named(sample_node, "_r23_confirm_membership_growth") and
            calls_named(sample_node, "_r23_confirm_terminal_root_sample_exit") and
            calls_named(sample_node,
                        "_r23_confirm_descendant_terminal_root_sample_exit") and
            calls_named(final_audit_node, "_r23_audit_membership_growth") and
            calls_named(final_audit_node, "_r23_audit_terminal_root_sample_exits") and
            calls_named(final_audit_node,
                        "_r23_audit_descendant_terminal_root_sample_exits") and
            calls_named(terminal_audit_node, "_r23_verify_snapshot_history_reference") and
            calls_named(descendant_terminal_audit_node,
                        "_r23_verify_snapshot_history_reference") and
            "terminal_sample_race.json" in phase_source and
            "terminal_root_sample_exit_races" in phase_source and
            "descendant_terminal_root_sample_exit_races" in phase_source and
            "descendant_exit_then_terminal_root_proven" in phase_source and
            "sample_excluded_from_completed_resource_samples" in phase_source and
            "snapshot_observer=capture_outer_tracked_exit_snapshot" in phase_source and
            "phase_snapshot_witnesses=phase_snapshot_witnesses" in phase_source and
            delta.get("r20_unbound_lane_ast_identical") is True and
            delta.get("r21_tracked_exit_lane_ast_identical") is True and
            delta.get("r22_pre_tree_lane_ast_identical") is True and
            delta.get("phase_snapshot_history_pid_prefix_required") is True and
            delta.get("independent_captured_source_witnesses_required") is True and
            delta.get("outer_tracked_exit_query_recorded_before_sample_source") is True and
            delta.get("prior_full_phase_pid_absence_required") is True and
            delta.get("same_generation_complete_retry_required") is True and
            delta.get("unrelated_off_tree_churn_allowed") is True and
            delta.get("growth_cleanup_exact_handle_wait_and_non_259_exit_required") is True and
            isinstance(terminal_disposition, dict) and
            terminal_disposition.get("triggering_actual_r9_failure") ==
                terminal_failure_pins and
            all(inputs.get(pin["path"]) == pin
                for pin in terminal_failure_pins.values()) and
            terminal_disposition.get("triggering_failure_reclassified") is False and
            terminal_disposition.get("tracked_launch_root_only") is True and
            terminal_disposition.get("prior_complete_sample_and_exact_active_closure_required") is True and
            terminal_disposition.get("same_generation_original_handles_wait_and_non_259_exit_required") is True and
            terminal_disposition.get("three_distinct_ascending_complete_absence_witnesses_required") is True and
            terminal_disposition.get("pid_reuse_or_orphan_or_new_generation_rejected") is True and
            terminal_disposition.get("discarded_attempt_never_a_completed_resource_sample") is True and
            terminal_disposition.get("partial_rss_at_or_above_original_cap_rejected") is True and
            terminal_disposition.get("final_audit_consumes_real_completed_sample_ledger") is True and
            terminal_disposition.get("final_audit_record_errors_empty_and_sample_index_sequential") is True and
            terminal_disposition.get("maximum_terminal_records") == 1 and
            terminal_disposition.get("whole_sample_attempt_limit") == 2 and
            terminal_disposition.get("new_retry_credit") is False and
            isinstance(descendant_terminal_disposition, dict) and
            descendant_terminal_disposition.get("schema") ==
                "vnext-t2-r23-descendant-terminal-root-sample-exit-disposition-r1" and
            descendant_terminal_disposition.get(
                "triggering_actual_r12_failure") ==
                descendant_terminal_failure_pins and
            all(inputs.get(pin["path"]) == pin
                for pin in descendant_terminal_failure_pins.values()) and
            descendant_terminal_disposition.get(
                "triggering_failure_reclassified") is False and
            descendant_terminal_disposition.get(
                "exact_nonroot_no_such_process_and_r21_confirmation_two_root_loss_required") is True and
            descendant_terminal_disposition.get(
                "failed_r21_original_incomplete_status_one_absence_and_zero_credit_required") is True and
            descendant_terminal_disposition.get(
                "failed_r21_canonical_digest_history_sequence_and_witness_binding_required") is True and
            descendant_terminal_disposition.get(
                "r21_two_query_observations_captured_in_history_required") is True and
            descendant_terminal_disposition.get(
                "accepted_outer_failed_and_previous_active_closures_equal_required") is True and
            descendant_terminal_disposition.get(
                "original_popen_and_all_retained_handles_exact_generation_wait_non_259_required") is True and
            descendant_terminal_disposition.get(
                "three_distinct_ascending_complete_raw_spi_absence_witnesses_required") is True and
            descendant_terminal_disposition.get(
                "pid_reuse_or_orphan_or_outside_active_generation_rejected") is True and
            descendant_terminal_disposition.get(
                "failed_sample_stays_incomplete_separate_and_never_retried") is True and
            descendant_terminal_disposition.get(
                "partial_rss_cpu_and_exit_credit_zero_required") is True and
            descendant_terminal_disposition.get(
                "independent_final_audit_recomputes_trigger_history_witness_and_failed_r21_digest") is True and
            descendant_terminal_disposition.get(
                "original_natural_exit_final_process_tree_and_cleanup_gates_unchanged") is True and
            descendant_terminal_disposition.get("maximum_terminal_records") == 1 and
            descendant_terminal_disposition.get("whole_sample_attempt_limit") == 2 and
            descendant_terminal_disposition.get("new_retry_credit") is False and
            delta.get("discarded_attempt_rss_credit_bytes") == 0 and
            delta.get("discarded_attempt_cpu_credit_seconds") ==
                {"user": 0.0, "system": 0.0} and
            delta.get("discarded_attempt_exit_credit_issued") is False and
            delta.get("coverage_thresholds_changed") is False and
            delta.get("resource_limits_changed") is False and
            protocol.get("schema") == "vnext-t2-independent-negative-protocol-r10",
            "R22-to-R23 membership-growth source delta, history proof, or preserved gates differ")
    return {"status": "pass", "changed_functions": changed,
            "changed_assignments": assignment_delta,
            "r20_unbound_lane_ast_identical": True,
            "r21_tracked_exit_lane_ast_identical": True,
            "r22_pre_tree_lane_ast_identical": True,
            "terminal_root_sample_exit_disposition_pinned": True,
            "descendant_terminal_root_sample_exit_disposition_pinned": True,
            "phase_snapshot_history_and_source_witnesses_required": True,
            "outer_tracked_exit_query_ordered": True,
            "coverage_thresholds_changed": False,
            "resource_limits_changed": False,
            "formal_t2_accepted": False, "julia_executed": False}


def verify_prior_r22_actual_failure(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    """Pin the R22 formal NO-GO from its actual launcher and executed bytes."""
    prior = protocol.get("prior_r22_actual_failure")
    require(isinstance(prior, dict) and
            prior.get("schema") ==
                "vnext-t2-r23-prior-r22-actual-failure-r1" and
            prior.get("classification") == "no_credit_actual_failure",
            "R23 protocol omitted the typed R22 actual-failure lineage")
    paths = {
        "protocol": R22_PRIOR_FORMAL_FAILURE_PROTOCOL,
        "command_argv": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "command_argv.json",
        "outer_receipt": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "external_exit_receipt.json",
        "launcher": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "launch_formal_r22.ps1",
        "stderr": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "stderr.raw",
        "pipeline_final": R22_PRIOR_FORMAL_FAILURE_LEAF / "pipeline_final.json",
        "source_snapshot_manifest": R22_PRIOR_FORMAL_FAILURE_SNAPSHOT / "manifest.json",
    }
    expected_files = {role: receipt(path) for role, path in paths.items()}
    pinned_sizes_and_hashes = {
        "protocol": (1_412_507,
            "93a2432cd4baea43192eda6b3ed54641ef3b7dbb5b3e1fb95087057efb33b1b7"),
        "command_argv": (1_259,
            "fc197657756e47d2473ec684d5e2bd1f31fb77871b5910d6df00307173a22c19"),
        "outer_receipt": (3_318,
            "0c4f11dce6c0ae6d399395908efa7e12158c6a7877aa06df3403b07b4792047a"),
        "launcher": (9_137,
            "cfb4464075c7775672a7cfe0d8ef67837ed52e253a1cfe8f491f804391651b7d"),
        "stderr": (1_157,
            "2b34daa06ea41aa2654a064838f0825a7e5539c78803de32507daffc70c007b0"),
        "pipeline_final": (899_583,
            "a4840b01da19ad9d2ac7c80426fc56d49a901a373314452af5a8606d275ce1f1"),
        "source_snapshot_manifest": (2_858,
            "f13955a3084fe9e73db78c6d829bd923f03e5cfa71de8bbb459a0ede6d34d48f"),
    }
    require(set(prior.get("files", {})) == set(paths) and
            prior.get("files") == expected_files and
            all(expected_files[role].get("bytes") == expected[0] and
                expected_files[role].get("sha256") == expected[1]
                for role, expected in pinned_sizes_and_hashes.items()) and
            all(inputs.get(row["path"]) == row for row in expected_files.values()),
            "R22 formal failure raw-file inventory or exact pins drifted")

    old_protocol = load(R22_PRIOR_FORMAL_FAILURE_PROTOCOL)
    outer = load(paths["outer_receipt"])
    command_argv = json.loads(read_text(paths["command_argv"], encoding="utf-8"))
    pipeline = load(paths["pipeline_final"])
    snapshot_manifest = load(paths["source_snapshot_manifest"])

    def raw_receipt_matches(actual: Any, expected: dict[str, Any]) -> bool:
        if not isinstance(actual, dict):
            return False
        try:
            actual_path = Path(actual.get("path", "")).resolve()
            expected_path = (ROOT / expected["path"]).resolve()
        except (OSError, TypeError, ValueError):
            return False
        return actual_path == expected_path and \
            actual.get("bytes") == expected.get("bytes") and \
            actual.get("sha256") == expected.get("sha256") and \
            actual.get("exists", True) is True

    require(old_protocol.get("schema") ==
                "vnext-t2-independent-negative-protocol-r10" and
            old_protocol.get("formal_t2_accepted") is False and
            old_protocol.get("controller_path") ==
                R22_CONTROLLER.relative_to(ROOT).as_posix() and
            isinstance(command_argv, list) and command_argv and
            outer.get("argv") == command_argv and
            outer.get("schema") == "root-t2-r22-actual-formal-external-exit-r1" and
            outer.get("actual_child_os_exit_code") == 1 and
            outer.get("outer_timeout") is False and
            outer.get("wall_seconds") == 1.8564528 and
            outer.get("protocol_sha256") == expected_files["protocol"]["sha256"] and
            outer.get("source_pin_count") == 1_092 and
            outer.get("source_pins_unchanged") is True and
            outer.get("launch_script_sha256_before") ==
                expected_files["launcher"]["sha256"] and
            outer.get("launch_script_sha256_after") ==
                expected_files["launcher"]["sha256"] and
            outer.get("formal_acceptance_not_inferred_from_os_exit") is True and
            outer.get("physical_acceptance_credit") is False and
            outer.get("julia_exit_not_inferred") is True and
            outer.get("stdout", {}).get("bytes") == 0 and
            outer.get("stdout", {}).get("sha256") ==
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" and
            raw_receipt_matches(outer.get("stderr"), expected_files["stderr"]) and
            raw_receipt_matches(outer.get("pipeline"), expected_files["pipeline_final"]),
            "R22 external launcher receipt does not prove the recorded actual failure")
    require(pipeline.get("schema") ==
                "vnext-t2-independent-negative-pipeline-final-r4" and
            pipeline.get("status") == "fail" and
            pipeline.get("formal_t2_accepted") is False and
            pipeline.get("scientific_acceptance") is False and
            pipeline.get("physical_acceptance") is False and
            raw_receipt_matches(pipeline.get("protocol"), expected_files["protocol"]) and
            len(pipeline.get("phases", [])) == 1 and
            pipeline["phases"][0].get("name") == "parse_gate" and
            pipeline["phases"][0].get("exit_code") == 15 and
            pipeline["phases"][0].get("stop_reason") ==
                "process_tree_monitor_incomplete" and
            pipeline["phases"][0].get("process_tree_sample_count") == 1 and
            pipeline["phases"][0].get("process_tree_samples_complete") is False and
            pipeline["phases"][0].get("final_process_tree_audit", {}).get("complete") is True and
            pipeline["phases"][0].get("final_process_tree_audit", {}).get(
                "root_exit_confirmed") is True and
            pipeline.get("executed_unique_case_count") == 0 and
            pipeline.get("executed_runtime_case_hit_count") == 0 and
            pipeline.get("versioned_product_repair_assertion_sites_completed") == 0,
            "R22 formal pipeline is not the preserved zero-credit parse-gate failure")

    expected_source_files = {
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r22.py":
            (394_560, "9c6e760369e9c19bcd6e859988b6590a79956540e6dfcf0550d3d00c59785e16"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r22.py":
            (204_884, "f0e96e4a38e0f818ca29629c7e71c962ed613b9346aa2e42e74ba13102092841"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/freeze_independent_negative_protocol_r22.py":
            (273_756, "115745a1d16a8785d89f4d6ee2907cda89448d28044be0baa3c6b5685563264b"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/validate_projection24_reuse_r12.py":
            (13_712, "04f3cf18221b69942815a8fd4d724e956ae3a230077200a24c49d57474344d41"),
    }
    require(snapshot_manifest.get("schema") ==
                "vnext-t2-r22-failure-source-snapshot-r1" and
            snapshot_manifest.get("evidence_leaf") ==
                R22_PRIOR_FORMAL_FAILURE_LEAF.relative_to(ROOT).as_posix() and
            snapshot_manifest.get("snapshot_scope") ==
                "exact current source bytes verified against actual launcher source_pins_before" and
            snapshot_manifest.get("preexisting_evidence_unchanged_after_snapshot") is True and
            isinstance(snapshot_manifest.get("source_files"), list) and
            len(snapshot_manifest["source_files"]) == len(expected_source_files) and
            set(inputs).issuperset(expected_files[role]["path"] for role in expected_files),
            "R22 execution-source snapshot manifest is malformed or incomplete")
    source_snapshot_pins = {}
    for row in snapshot_manifest["source_files"]:
        repo_path = row.get("repo_path")
        expected = expected_source_files.get(repo_path)
        require(expected is not None and row.get("execution_pin_equal") is True and
                row.get("bytes") == expected[0] and row.get("sha256") == expected[1],
                f"R22 executed source snapshot changed: {repo_path}")
        snapshot_path = R22_PRIOR_FORMAL_FAILURE_SNAPSHOT / row["snapshot_path"]
        source_pin = receipt(snapshot_path)
        require(source_pin.get("bytes") == row["bytes"] and
                source_pin.get("sha256") == row["sha256"] and
                inputs.get(source_pin["path"]) == source_pin,
                f"R22 exact executed source snapshot is not input-pinned: {repo_path}")
        source_snapshot_pins[repo_path] = source_pin
    require(set(source_snapshot_pins) == set(expected_source_files),
            "R22 source snapshot omitted or duplicated an execution input")
    require(all(inputs.get(row["path"]) == row for row in expected_files.values()),
            "R22 formal-failure receipt is outside the current R23 input closure")
    return {"status": "pass", "classification": "no_credit_actual_failure",
            "protocol_sha256": expected_files["protocol"]["sha256"],
            "outer_actual_os_exit": 1, "outer_timeout": False,
            "source_pin_count": 1_092, "source_snapshot_count": 4,
            "phase": "parse_gate", "phase_exit": 15,
            "completed_formal_cases": 0,
            "formal_t2_accepted": False, "physical_acceptance_credit": False}


def verify_projection_reuse_validator_r10_r11_delta(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("projection24_reuse_validator_r10_r11_delta")
    old = read_text(R10_PROJECTION_REUSE_VALIDATOR, encoding="utf-8")
    new = read_text(R11_PROJECTION_REUSE_VALIDATOR, encoding="utf-8")
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
    sources = _source_inputs()
    r11_bytes = sources.read_protocol_input_bytes(protocol, R11_PROJECTION_REUSE_VALIDATOR)
    old = r11_bytes.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    preimage_bytes = sources.read_bytes(R12_PROJECTION_REUSE_PREIMAGE)
    require(len(preimage_bytes) == R12_PROJECTION_REUSE_PREIMAGE_BYTES and
            sha(preimage_bytes) == R12_PROJECTION_REUSE_PREIMAGE_SHA256,
            "sealed R12 data-only preimage identity changed")
    new = preimage_bytes.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    old_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":'
    new_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r10":'
    old_usage = "usage: validate_projection24_reuse_r10.py <protocol.json> <receipt.json>"
    new_usage = "usage: validate_projection24_reuse_r12.py <protocol.json> <receipt.json>"
    expected = old.replace(old_usage, new_usage, 1).replace(old_gate, new_gate, 1)
    r11_pin = {
        "path": R11_PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        "bytes": len(r11_bytes), "sha256": sha(r11_bytes),
    }
    r12_pin = {
        "path": R12_PROJECTION_REUSE_PREIMAGE.relative_to(ROOT).as_posix(),
        "bytes": len(preimage_bytes), "sha256": sha(preimage_bytes),
    }
    require(isinstance(delta, dict) and
            delta.get("schema") == "vnext-t2-projection-reuse-validator-r11-r12-schema-delta-r1" and
            delta.get("r11_source") == r11_pin and delta.get("r12_source") == r12_pin and
            delta.get("r12_source_role") ==
                "sealed_data_preimage_not_current_executable" and
            delta.get("only_changes") == [
                "accept vnext-t2-independent-negative-protocol-r10 in the same top-level schema gate",
                "version the CLI usage label to validate_projection24_reuse_r12.py"] and
            delta.get("all_projection_plan_source_input_hash_and_24_site_checks_unchanged") is True and
            old.count(old_usage) == 1 and old.count(old_gate) == 1 and new == expected and
            inputs.get(r11_pin["path"]) == r11_pin and
            protocol.get("projection24_reuse_validator_path") ==
                R12_PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
            "R11-to-sealed-R12-preimage delta is not an exact schema-only r10 adaptation")
    return {"status": "pass", "accepted_protocol_schema":
            "vnext-t2-independent-negative-protocol-r10",
            "projection_plan_input_hash_and_coverage_checks_changed": False,
            "sealed_preimage": r12_pin}


def verify_projection_reuse_validator_r12_source_layout_adapter(
        protocol: dict[str, Any], inputs: dict[str, Any]) -> dict[str, Any]:
    sources = _source_inputs()
    current_path = R12_PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix()
    source_layout = protocol.get("source_layout")
    require(isinstance(source_layout, dict) and
            current_path not in source_layout.get("historical_source_data", {}),
            "current R12 validator cannot be classified as historical data")
    sources.require_local_execution(R12_PROJECTION_REUSE_VALIDATOR)
    current_bytes = sources.read_protocol_input_bytes(
        protocol, R12_PROJECTION_REUSE_VALIDATOR)
    current_pin = {"path": current_path, "bytes": len(current_bytes),
                   "sha256": sha(current_bytes)}
    require(current_pin == {
                "path": current_path,
                "bytes": 17370,
                "sha256": "5c0082bbdf4dd6f98ebe806564c4b4c9d36572f8b9cb249a644ccd20e74467d1",
            } and inputs.get(current_path) == current_pin and
            protocol.get("projection24_reuse_validator_path") == current_path,
            "current R12 validator differs from its frozen local consumer pin")

    preimage_bytes = sources.read_bytes(R12_PROJECTION_REUSE_PREIMAGE)
    require(len(preimage_bytes) == R12_PROJECTION_REUSE_PREIMAGE_BYTES and
            sha(preimage_bytes) == R12_PROJECTION_REUSE_PREIMAGE_SHA256,
            "sealed R12 data-only preimage identity changed")
    preimage_pin = {
        "path": R12_PROJECTION_REUSE_PREIMAGE.relative_to(ROOT).as_posix(),
        "bytes": len(preimage_bytes), "sha256": sha(preimage_bytes),
    }
    adapter = protocol.get("projection24_reuse_validator_r12_source_layout_adapter")
    replacement_ids = [
        "bootstrap", "receipt", "require_receipt",
        "main_protocol_local_read", "main_old_protocol_bytes",
        "main_dependency_read_loop", "main_dependency_reuse",
        "main_remove_observation_reread", "main_remove_stdout_reread",
        "main_remove_timeout_reread", "main_output_receipt",
    ]
    require(isinstance(adapter, dict) and
            adapter.get("schema") ==
                "vnext-t2-projection-reuse-validator-r12-source-layout-adapter-r1" and
            adapter.get("preimage_role") ==
                "sealed_data_preimage_not_current_executable" and
            adapter.get("preimage_source") == preimage_pin and
            inputs.get(preimage_pin["path"]) == preimage_pin and
            adapter.get("current_source") == current_pin and
            adapter.get("reconstruction") ==
                "11_exact_anchored_text_replacements_then_full_source_and_ast_equality" and
            adapter.get("replacement_count") == 11 and
            adapter.get("replacement_ids") == replacement_ids and
            adapter.get("changed_top_level_functions") ==
                ["main", "receipt", "require_receipt"] and
            adapter.get("added_top_level_statements") ==
                ["source_inputs_bootstrap_guard", "T2SourceInputs_import"] and
            adapter.get("all_other_top_level_ast_equal") is True and
            adapter.get("full_source_text_equal") is True and
            adapter.get("full_ast_equal") is True,
            "R12 adapter metadata differs from its frozen exact reconstruction contract")

    preimage_tree = ast.parse(preimage_bytes.decode("utf-8"))
    current_tree = ast.parse(current_bytes.decode("utf-8"))

    def function_nodes(tree: ast.Module) -> dict[str, ast.AST]:
        return {node.name: node for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}

    preimage_functions = function_nodes(preimage_tree)
    current_functions = function_nodes(current_tree)
    changed_functions = sorted(
        name for name in set(preimage_functions) | set(current_functions)
        if name not in preimage_functions or name not in current_functions or
        ast.dump(preimage_functions[name], include_attributes=False) !=
        ast.dump(current_functions[name], include_attributes=False))
    require(changed_functions == ["main", "receipt", "require_receipt"],
            "R12 adapter changed a function outside the exact three-function contract")

    bootstrap = ast.parse(
        "if str(ROOT) not in sys.path:\n"
        "    sys.path.insert(0, str(ROOT))\n"
        "from tools.execution.t2_source_inputs import T2SourceInputs\n")
    bootstrap_dumps = [ast.dump(node, include_attributes=False)
                       for node in bootstrap.body]
    preimage_nonfunctions = [ast.dump(node, include_attributes=False)
                             for node in preimage_tree.body
                             if not isinstance(node,
                                               (ast.FunctionDef, ast.AsyncFunctionDef))]
    current_nonfunctions = [ast.dump(node, include_attributes=False)
                            for node in current_tree.body
                            if not isinstance(node,
                                              (ast.FunctionDef, ast.AsyncFunctionDef))]
    require(all(current_nonfunctions.count(node) == 1 for node in bootstrap_dumps) and
            [node for node in current_nonfunctions if node not in bootstrap_dumps] ==
                preimage_nonfunctions,
            "R12 adapter changed module-level AST outside its exact bootstrap nodes")

    reuse_plan = protocol.get("projection24_reuse")
    legacy_delta = protocol.get("projection24_reuse_validator_r11_r12_delta")
    require(isinstance(reuse_plan, dict) and
            reuse_plan.get("source_input_count") == 157 and
            reuse_plan.get("r1_input_intersection_count") == 151 and
            reuse_plan.get("excluded_r1_input_count") == 6 and
            reuse_plan.get("dependency_subset_count") == 159 and
            reuse_plan.get("dependency_count") == 159 and
            isinstance(reuse_plan.get("dependency_subset"), dict) and
            len(reuse_plan["dependency_subset"]) == 159 and
            isinstance(legacy_delta, dict) and
            legacy_delta.get("all_projection_plan_source_input_hash_and_24_site_checks_unchanged") is True,
            "R12 adapter altered the 151+6/159 dependency or 24-site contract")

    history_path = R12_ARCHIVED_COVERAGE_BUILDER
    history_relative = history_path.relative_to(ROOT).as_posix()
    history_pin = {
        "path": history_relative,
        "bytes": R12_ARCHIVED_COVERAGE_BUILDER_BYTES,
        "sha256": R12_ARCHIVED_COVERAGE_BUILDER_SHA256,
    }
    require(inputs.get(history_relative) == history_pin and
            source_layout.get("historical_source_data", {}).get(history_relative) ==
                history_pin,
            "R12 archived coverage builder lacks its exact protocol-bound data pin")
    physical_before = None
    try:
        info = history_path.lstat()
        physical_before = (info.st_mode, info.st_size, info.st_mtime_ns,
                           getattr(info, "st_ino", None))
    except FileNotFoundError:
        pass
    local_read = sources.read_bytes

    def forbid_archived_local_read(path: Path) -> bytes:
        if sources.logical_path(path) == history_relative:
            raise RuntimeError("archived data must not be read through the workspace path")
        return local_read(path)

    with patch.object(sources, "read_bytes", side_effect=forbid_archived_local_read):
        history_bytes = sources.read_protocol_input_bytes(protocol, history_path)
    history_receipt = {"path": history_relative, "bytes": len(history_bytes),
                       "sha256": sha(history_bytes)}
    require(history_receipt == history_pin,
            "protocol-bound R1 coverage-builder data differs from the exact 82-source pin")
    try:
        info = history_path.lstat()
        physical_after = (info.st_mode, info.st_size, info.st_mtime_ns,
                          getattr(info, "st_ino", None))
    except FileNotFoundError:
        physical_after = None
    require(physical_after == physical_before,
            "protocol-bound historical read modified the workspace path")

    adapter_controls: list[dict[str, str]] = []

    def reject_input(name: str, action: Any, expected_message: str) -> None:
        try:
            action()
        except Exception as error:
            require(expected_message in str(error),
                    f"R12 input control failed at the wrong gate: {name}: {error}")
            adapter_controls.append({"name": name, "status": "pass",
                                     "rejected_as": type(error).__name__})
            return
        raise RuntimeError(f"R12 input control unexpectedly accepted: {name}")

    missing_pin = copy.deepcopy(protocol)
    missing_pin["inputs"].pop(history_relative)
    reject_input(
        "missing historical protocol pin",
        lambda: sources.read_protocol_input_bytes(missing_pin, history_path),
        f"T2 protocol omitted or changed a source binding: {history_relative}")
    bad_bytes_pin = copy.deepcopy(protocol)
    bad_bytes_pin["inputs"][history_relative]["bytes"] += 1
    reject_input(
        "historical protocol byte-count drift",
        lambda: sources.read_protocol_input_bytes(bad_bytes_pin, history_path),
        f"T2 protocol omitted or changed a source binding: {history_relative}")
    bad_sha_pin = copy.deepcopy(protocol)
    bad_sha_pin["inputs"][history_relative]["sha256"] = "0" * 64
    reject_input(
        "historical protocol SHA drift",
        lambda: sources.read_protocol_input_bytes(bad_sha_pin, history_path),
        f"T2 protocol omitted or changed a source binding: {history_relative}")
    missing_history = copy.deepcopy(protocol)
    missing_history["source_layout"]["historical_source_data"].pop(history_relative)
    reject_input(
        "historical source-map omission",
        lambda: sources.read_protocol_input_bytes(missing_history, history_path),
        "T2 protocol source layout differs from the frozen binding")
    wrong_snapshot = copy.deepcopy(protocol)
    wrong_snapshot["source_layout"]["snapshot_id"] = "unapproved-snapshot"
    reject_input(
        "wrong historical snapshot",
        lambda: sources.read_protocol_input_bytes(wrong_snapshot, history_path),
        "T2 protocol source layout differs from the frozen binding")
    reject_input(
        "historical code cannot be executed",
        lambda: sources.require_local_execution(history_path),
        f"T2 historical source is data and cannot be executed: {history_relative}")
    unpinned = TEST_ROOT / "__unmapped_projection_input__.dat"
    reject_input(
        "unpinned logical path",
        lambda: sources.read_protocol_input_bytes(protocol, unpinned),
        "T2 protocol input has no exact path/bytes/SHA pin")
    bad_local_pin = copy.deepcopy(protocol)
    bad_local_pin["inputs"][current_path]["sha256"] = "0" * 64
    reject_input(
        "current local source pin drift without archive fallback",
        lambda: sources.read_protocol_input_bytes(
            bad_local_pin, R12_PROJECTION_REUSE_VALIDATOR),
        f"T2 protocol input differs from its exact pin: {current_path}")
    require(len(adapter_controls) == 8,
            "R12 protocol-bound adapter controls changed")

    return {
        "status": "pass",
        "preimage_source": preimage_pin,
        "current_source": current_pin,
        "changed_top_level_functions": changed_functions,
        "added_top_level_statements": [
            "source_inputs_bootstrap_guard", "T2SourceInputs_import"],
        "all_other_top_level_ast_equal": True,
        "full_source_sha256": sha(current_bytes),
        "projection_reuse_counts": {
            "r1_source_input_count": reuse_plan["source_input_count"],
            "r1_intersection": reuse_plan["r1_input_intersection_count"],
            "excluded": reuse_plan["excluded_r1_input_count"],
            "dependency_subset": reuse_plan["dependency_subset_count"],
            "projection_sites": 24,
        },
        "archived_data_read": history_receipt,
        "workspace_identity_unchanged": True,
        "protocol_input_negative_controls": adapter_controls,
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--protocol-sha256", required=True)
    parser.add_argument("--dispatch", required=True)
    parser.add_argument("--command", required=True)
    parser.add_argument("--report", required=True)
    args = parser.parse_args()
    report_path: Path | None = None
    report: dict[str, Any] = {
        "schema": "vnext-t2-independent-negative-static-qa-r23-r23",
        "status": "fail", "julia_executed": False,
        "formal_t2_accepted": False, "negative_controls": [],
    }
    try:
        require(__name__ == "__main__" and sys.dont_write_bytecode and
                Path(sys.argv[0]).resolve() == Path(__file__).resolve(),
                "static QA must run as a direct -B source entrypoint")
        protocol_path = _validated_local_argument_path(args.protocol, "protocol")
        dispatch_path = _validated_local_argument_path(args.dispatch, "dispatch")
        command_path = _validated_local_argument_path(args.command, "command")
        report_candidate = _validated_new_report_path(args.report)
        report_parent = report_candidate.parent.resolve(strict=True)
        for path in (protocol_path, dispatch_path, command_path, report_parent):
            path.relative_to(ROOT)
        freeze_root = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()
        require(protocol_path.parent == dispatch_path.parent ==
                command_path.parent == report_parent and
                protocol_path.parent.parent == freeze_root and
                protocol_path.name == "protocol.json" and
                dispatch_path.name == "dispatch.json" and
                command_path.name == "command_argv.json" and
                report_candidate.name == "static_qa.json",
                "frozen protocol, dispatch, command, and QA report must share a direct runs leaf")
        report_path = report_candidate
        protocol_bytes = read_bytes(protocol_path)
        require(sha(protocol_bytes) == args.protocol_sha256.lower(),
                "protocol SHA mismatch")
        protocol = json.loads(protocol_bytes.decode("utf-8"))
        require(isinstance(protocol, dict),
                "expected JSON object from SHA-verified protocol bytes")
        bind_source_protocol(protocol)
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
        report["projection24_reuse_validator_r12_source_layout_adapter"] = \
            verify_projection_reuse_validator_r12_source_layout_adapter(
                protocol, inputs)
        report["authorized_v4_planning_migration"] = \
            verify_authorized_planning_migration(protocol, inputs)
        controller_pin = inputs.get(CONTROLLER.relative_to(ROOT).as_posix())
        require(controller_pin is not None and
                protocol.get("controller_path") == controller_pin["path"],
                "current R23 controller is outside the exact input closure")
        controller = load_source_module("t2_r23_current_controller", CONTROLLER,
                                        controller_pin)
        controller_source = read_text(CONTROLLER, encoding="utf-8")
        parent_controller_path = R23_CONTROLLER_PREIMAGE.relative_to(ROOT).as_posix()
        parent_controller_pin = inputs.get(parent_controller_path)
        expected_parent_controller_pin = {
            "path": parent_controller_path,
            "bytes": 624265,
            "sha256": "32854f365980ed1ea981277d758cdebcd486b276d950a2f395088fefcfa9f523",
        }
        require(parent_controller_pin == expected_parent_controller_pin and
                inputs.get(CONTROLLER.relative_to(ROOT).as_posix()) == controller_pin,
                "R23 current/preimage controller pair is not pinned exactly")
        parent_controller_source = read_text(R23_CONTROLLER_PREIMAGE,
                                             encoding="utf-8")
        pair_path = R23_CONTROLLER_PAIR_PREIMAGE.relative_to(ROOT).as_posix()
        pair_pin = inputs.get(pair_path)
        require(pair_pin == {
                    "path": pair_path, "bytes": 625360,
                    "sha256": "a5ba94c56af75878d07cc2136c12f4c1232804cbd8c6fe3e90ff15c27ddb7367"} and
                inputs.get(CONTROLLER.relative_to(ROOT).as_posix()) == controller_pin,
                "R23 A5 data preimage or current executable is outside input closure")
        pair_source = read_text(R23_CONTROLLER_PAIR_PREIMAGE, encoding="utf-8")
        historical_lifecycle_path = \
            R23_CONTROLLER_LIFECYCLE_PREIMAGE.relative_to(ROOT).as_posix()
        historical_lifecycle_pin = inputs.get(historical_lifecycle_path)
        require(historical_lifecycle_pin == {
                    "path": historical_lifecycle_path,
                    "bytes": 626070,
                    "sha256": "b5a1cb43a3ba3a1c65c663530c238236018e6d5712a7a74c96ec395412577a5c",
                } and inputs.get(historical_lifecycle_path) == historical_lifecycle_pin,
                "saved B5 lifecycle predecessor is outside the exact input closure")
        historical_lifecycle_source = read_text(
            R23_CONTROLLER_LIFECYCLE_PREIMAGE, encoding="utf-8")
        report["controller_source_layout_rebase"] = \
            verify_source_layout_rebase(
                protocol, inputs, parent_controller_source, pair_source,
                historical_lifecycle_source, parent_controller_pin, pair_pin,
                historical_lifecycle_pin)
        report["controller_managed_process_lifecycle_delta"] = \
            verify_managed_process_lifecycle_controller_delta(
                protocol, inputs, historical_lifecycle_source, controller_source,
                historical_lifecycle_pin, controller_pin)
        r20_pin = inputs.get(R20_CONTROLLER.relative_to(ROOT).as_posix())
        require(r20_pin is not None and inputs.get(r20_pin["path"]) == r20_pin,
                "historical R20 controller is outside the exact input closure")
        r20_source = read_text(R20_CONTROLLER, encoding="utf-8")
        r22_pin = inputs.get(R22_CONTROLLER.relative_to(ROOT).as_posix())
        require(r22_pin is not None and inputs.get(r22_pin["path"]) == r22_pin,
                "historical R22 controller is outside the exact input closure")
        r22_source = read_text(R22_CONTROLLER, encoding="utf-8")
        report["controller_r22_r23_membership_growth_delta"] = \
            verify_r22_r23_membership_growth_delta(
                protocol, inputs, r22_source, parent_controller_source,
                r22_pin, parent_controller_pin)
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
            for path in source_paths_under(R18_RETRY1_FAILURE_LEAF)
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
            for path in source_paths_under(R19_RETRY1_PROJECTION_FAILURE_LEAF)
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
        projection_failure_stderr = read_text(
            R19_RETRY1_PROJECTION_FAILURE_LEAF /
            "projection24_reuse_preflight/stderr.raw",
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
            for path in source_paths_under(R19_RETRY2_STATIC_QA_FAILURE_LEAF)
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
        retry2_static_qa_stderr = json.loads(read_text(
            R19_RETRY2_STATIC_QA_FAILURE_LEAF / "static_qa.stderr.raw",
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
        old_controller_source = read_text(r18_controller_path, encoding="utf-8")
        r19_controller_source = read_text(R19_CONTROLLER, encoding="utf-8")
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
                protocol, inputs, r22_source, r22_pin)
        report["r22_pre_tree_tracked_exit_python_controls"] = \
            verify_r22_pre_tree_test_receipt(protocol, inputs)
        report["r22_windows_host_smoke"] = \
            verify_r22_windows_host_smoke(protocol, inputs)
        report["prior_r22_actual_failure"] = \
            verify_prior_r22_actual_failure(protocol, inputs)
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
            verify_r20_runs_only_path_gate(protocol, inputs, controller,
                                           r20_source, r20_pin,
                                           controller_source)
        report["r17_host_smoke_failure_lineage"] = \
            verify_host_smoke_failure_lineage(protocol, inputs)
        report["r18_predicate_probe_no_go_lineage"] = \
            verify_r18_predicate_no_go_lineage(protocol, inputs)
        legacy_negative_count = len(controls)
        legacy_positive_count = len(report.get("positive_controls", []))
        require(legacy_negative_count == 96 and legacy_positive_count == 10,
                "R23 preparation changed the retained 96-negative/10-positive R22 QA baseline")
        report["retained_r22_qa_baseline"] = {
            "negative_control_count": legacy_negative_count,
            "positive_control_count": legacy_positive_count,
            "immutable_r22_controller_path": R22_CONTROLLER.relative_to(ROOT).as_posix(),
            "current_generic_controls_controller_path": CONTROLLER.relative_to(ROOT).as_posix(),
        }
        report["r23_membership_growth_controls"] = \
            run_r23_membership_growth_controls(
                controller, controls, report.setdefault("positive_controls", []),
                report.setdefault("r23_membership_growth_positive_observation", {
                    "schema":
                        "vnext-t2-r23-membership-growth-positive-observation-r1",
                    "status": "awaiting_positive_assertions",
                    "formal_t2_accepted": False,
                    "julia_executed": False,
                }))
        report["r23_terminal_root_sample_exit_controls"] = \
            run_r23_terminal_root_sample_exit_controls(
                controller, controls, report.setdefault("positive_controls", []),
                report.setdefault("r23_terminal_root_sample_exit_positive_observation", {
                    "schema":
                        "vnext-t2-r23-terminal-root-sample-exit-positive-observation-r1",
                    "status": "awaiting_terminal_root_observation",
                    "formal_t2_accepted": False,
                    "julia_executed": False,
                }))
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
        if report_path is not None:
            try:
                _write_new_report(report_path, report)
            except Exception as write_error:
                print(json.dumps({
                    "qa_failure": report["failure"],
                    "report_write_failure": {
                        "type": type(write_error).__name__,
                        "message": str(write_error),
                    },
                    "report_written": False,
                }, ensure_ascii=False, sort_keys=True), file=sys.stderr)
            else:
                print(json.dumps(report, ensure_ascii=False, sort_keys=True),
                      file=sys.stderr)
                return 1
        else:
            print(json.dumps(report, ensure_ascii=False, sort_keys=True),
                  file=sys.stderr)
        return 1
    require(report_path is not None,
            "validated report destination was not retained")
    try:
        _write_new_report(report_path, report)
    except Exception as error:
        print(json.dumps({
            "status": "fail",
            "failure": {"type": type(error).__name__, "message": str(error)},
            "report_written": False,
            "julia_executed": False,
            "formal_t2_accepted": False,
        }, ensure_ascii=False, sort_keys=True), file=sys.stderr)
        return 1
    print(json.dumps({"status": report["status"],
                      "input_count": report["input_count"],
                      "negative_control_count": report["negative_control_count"],
                      "coverage": report["coverage"],
                      "report": receipt(report_path)},
                     ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
