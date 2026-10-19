from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import traceback
from typing import Any

import psutil


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
IMPLEMENTATION_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2IdentityReceiptV2"
ACTUAL_DRIVER = TEST_ROOT / "actual_formal_negative_driver_r5.jl"
SUPPLEMENTARY_DRIVER = TEST_ROOT / "supplementary_contract_driver_r1.jl"
ARTIFACT_DRIVER = TEST_ROOT / "artifact_preflight_negative_driver_r1.jl"
ATTACK_FIXTURE_DRIVER = TEST_ROOT / "artifact_attack_fixture_driver_r1.jl"
AST_INVENTORY_DRIVER = TEST_ROOT / "coverage_ast_inventory_r3.jl"
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r4.py"
CANDIDATE_DRIVER = IMPLEMENTATION_ROOT / "formal_candidate_driver.jl"
PROJECTION_DRIVER = IMPLEMENTATION_ROOT / (
    "vnext_t2_package_full_content_projection_r1.jl")
PARSE_GATE = ROOT / (
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl")
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
AUTHORITY_CASE_ORDER = [
    "PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
    "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
    "ACTUAL_FORMAL_GATE_REJECTION",
    "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
    "ACTUAL_DUPLICATE_INVOCATION",
]
AUTHORITY_PHASE_TIMEOUT_SECONDS = 2400
AUTHORITY_CASE_TIMEOUT_SECONDS = 1200
AUTHORITY_WORKING_SET_LIMIT_BYTES = 2_147_483_648

OWNED_CANDIDATE_ARTIFACTS = (
    "candidate_package.jls",
    "candidate_t1_admission_receipt.json",
    "t2_result.jls",
    "run_receipt.json",
    "replay_uncommitted_attempt.json",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data),
            "sha256": sha256_bytes(data)}


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        value = json.loads(line)
        if not isinstance(value, dict):
            raise RuntimeError(f"expected JSON object at {path}:{number}")
        rows.append(value)
    return rows


def load_jsonl_complete_prefix(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Read only fully newline-terminated JSONL records for partial evidence."""
    data = path.read_bytes()
    rows: list[dict[str, Any]] = []
    offset = 0
    for index, line in enumerate(data.splitlines(keepends=True)):
        end = offset + len(line)
        if not line.endswith(b"\n"):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": False}
        try:
            value = json.loads(line.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": True,
                          "invalid_complete_row": True}
        if not isinstance(value, dict):
            return rows, {"complete_row_count": len(rows),
                          "truncated_row_index": index,
                          "valid_prefix_bytes": offset,
                          "file_bytes": len(data),
                          "trailing_row_terminated": True,
                          "invalid_complete_row": True}
        rows.append(value)
        offset = end
    return rows, {"complete_row_count": len(rows),
                  "truncated_row_index": None,
                  "valid_prefix_bytes": offset,
                  "file_bytes": len(data),
                  "trailing_row_terminated": True,
                  "invalid_complete_row": False}


def first_error_line(path: Path) -> str:
    lines = [line.strip() for line in path.read_text(
        encoding="utf-8", errors="replace").splitlines() if line.strip()]
    if not lines:
        raise RuntimeError(f"missing error output: {path}")
    return lines[0]


def require_output_guard_first_error(path: Path, artifact_name: str) -> str:
    observed = first_error_line(path)
    expected = (
        "ERROR: LoadError: (:formal_t2_output_artifact_already_exists, "
        f'"{artifact_name}")')
    if observed != expected:
        raise RuntimeError(
            f"output guard first error mismatch: {observed!r} != {expected!r}")
    return observed


def digest_value(value: Any, label: str) -> str:
    if isinstance(value, str):
        digest = value
    elif isinstance(value, dict) and set(value) == {"value"}:
        digest = value["value"]
    else:
        raise RuntimeError(f"{label} is not a digest: {value!r}")
    digest = digest.lower()
    if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
        raise RuntimeError(f"{label} is not a lowercase SHA-256: {digest!r}")
    return digest


def git_head() -> str:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    return result.stdout.strip()


def utc() -> str:
    from datetime import datetime, timezone
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def heavy_processes() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for process in psutil.process_iter(
            ["pid", "name", "cmdline", "create_time"]):
        try:
            name = (process.info.get("name") or "").lower()
            command = " ".join(process.info.get("cmdline") or [])
            command_lower = command.lower()
            if "julia" in name or "formal_t2_controller.py" in command_lower or \
                    "independent_negative_controller_r4.py" in command_lower:
                if process.pid != os.getpid():
                    rows.append({
                        "pid": process.pid, "name": process.info.get("name"),
                        "command": command,
                        "create_time": process.info.get("create_time"),
                    })
        except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
            continue
    return rows


def process_tree_sample(root_process: psutil.Process) -> dict[str, Any]:
    processes = [root_process]
    try:
        processes.extend(root_process.children(recursive=True))
    except psutil.Error:
        pass
    rows: list[dict[str, Any]] = []
    total = 0
    total_user_cpu = 0.0
    total_system_cpu = 0.0
    for process in processes:
        try:
            rss = process.memory_info().rss
            cpu = process.cpu_times()
            total += rss
            total_user_cpu += cpu.user
            total_system_cpu += cpu.system
            rows.append({"pid": process.pid,
                         "create_time": process.create_time(),
                         "working_set_bytes": rss,
                         "user_cpu_seconds": cpu.user,
                         "system_cpu_seconds": cpu.system})
        except psutil.Error:
            continue
    return {"observed_utc": utc(),
            "process_tree_working_set_bytes": total,
            "process_tree_user_cpu_seconds": total_user_cpu,
            "process_tree_system_cpu_seconds": total_system_cpu,
            "processes": rows}


def kill_tree(process: psutil.Process) -> None:
    try:
        children = process.children(recursive=True)
    except psutil.Error:
        children = []
    for child in reversed(children):
        try:
            child.kill()
        except psutil.Error:
            pass
    try:
        process.kill()
    except psutil.Error:
        pass


def run_phase(name: str, command: list[str], output: Path, *,
              timeout_seconds: float, working_set_limit_bytes: int,
              environment: dict[str, str], precreated: bool = False) -> dict[str, Any]:
    if precreated:
        if not output.is_dir():
            raise RuntimeError(f"precreated phase directory absent: {output}")
    else:
        output.mkdir(parents=True, exist_ok=False)
    started_utc = utc()
    started = time.monotonic()
    stop_reason = "natural_exit"
    samples: list[dict[str, Any]] = []
    with (output / "stdout.raw").open("xb") as stdout, \
            (output / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(
            command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        observed = psutil.Process(process.pid)
        create_time = observed.create_time()
        with (output / "samples.jsonl").open(
                "x", encoding="utf-8", newline="\n", buffering=1) as sample_file:
            while process.poll() is None:
                try:
                    if observed.create_time() != create_time:
                        stop_reason = "pid_ownership_invalid"
                        break
                    sample = process_tree_sample(observed)
                    samples.append(sample)
                    sample_file.write(json.dumps(sample, sort_keys=True) + "\n")
                    if sample["process_tree_working_set_bytes"] >= \
                            working_set_limit_bytes:
                        stop_reason = "process_tree_working_set_hard_ceiling"
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "phase_wall_timeout"
                        break
                except psutil.NoSuchProcess:
                    break
                time.sleep(0.2)
            if process.poll() is None and stop_reason != "natural_exit":
                kill_tree(observed)
            exit_code = process.wait()
    phase = {
        "schema": "vnext-t2-independent-negative-phase-r4",
        "name": name, "command": command, "cwd": str(ROOT),
        "pid": process.pid, "process_create_time": create_time,
        "started_utc": started_utc, "ended_utc": utc(),
        "seconds": time.monotonic() - started,
        "exit_code": exit_code, "stop_reason": stop_reason,
        "timeout_seconds": timeout_seconds,
        "working_set_limit_bytes": working_set_limit_bytes,
        "peak_process_tree_working_set_bytes": max(
            (row["process_tree_working_set_bytes"] for row in samples),
            default=0),
        "final_sample_process_tree_user_cpu_seconds":
            samples[-1]["process_tree_user_cpu_seconds"] if samples else 0.0,
        "final_sample_process_tree_system_cpu_seconds":
            samples[-1]["process_tree_system_cpu_seconds"] if samples else 0.0,
        "stdout": file_receipt(output / "stdout.raw"),
        "stderr": file_receipt(output / "stderr.raw"),
        "residual_heavy_processes": heavy_processes(),
        "actual_model_attestation": "unavailable",
    }
    write_json_new(output / "phase.json", phase)
    return phase


def require_natural(phase: dict[str, Any], *, exit_zero: bool) -> None:
    if phase["stop_reason"] != "natural_exit":
        raise RuntimeError(f"{phase['name']} stop={phase['stop_reason']}")
    if exit_zero and phase["exit_code"] != 0:
        raise RuntimeError(f"{phase['name']} exit={phase['exit_code']}")
    if not exit_zero and phase["exit_code"] == 0:
        raise RuntimeError(f"{phase['name']} unexpectedly exited zero")
    if phase["residual_heavy_processes"]:
        raise RuntimeError(
            f"{phase['name']} left residual processes: " +
            json.dumps(phase["residual_heavy_processes"], sort_keys=True))


def verify_protocol(path: Path, expected_sha256: str) -> dict[str, Any]:
    actual = file_receipt(path)
    if actual["sha256"] != expected_sha256.lower():
        raise RuntimeError("negative protocol SHA-256 mismatch")
    protocol = load_json(path)
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r4":
        raise RuntimeError("negative protocol schema mismatch")
    if protocol.get("repository_head") != EXPECTED_HEAD:
        raise RuntimeError("negative protocol HEAD mismatch")
    for relative, expected in protocol["inputs"].items():
        current = file_receipt(ROOT / relative)
        if current["bytes"] != expected["bytes"] or \
                current["sha256"] != expected["sha256"]:
            raise RuntimeError(f"negative protocol input drift: {relative}")
    return protocol


def verify_runtime_plan(protocol: dict[str, Any]) -> dict[str, Any]:
    plan = protocol.get("runtime_execution_plan")
    if not isinstance(plan, dict):
        raise RuntimeError("negative protocol runtime plan absent")
    unique = plan.get("expected_unique_case_ids")
    counts = plan.get("expected_runtime_case_hit_counts")
    if not isinstance(unique, list) or len(unique) != len(set(unique)) or \
            not isinstance(counts, dict) or set(unique) != set(counts):
        raise RuntimeError("negative runtime case inventory invalid")
    if plan.get("expected_unique_case_count") != len(unique) or \
            plan.get("expected_runtime_case_hit_count") != sum(counts.values()):
        raise RuntimeError("negative runtime case totals invalid")
    actual = plan.get("actual_formal_summary_case_ids")
    observations = plan.get("actual_formal_observation_ids")
    if not isinstance(actual, list) or len(actual) != len(set(actual)) or \
            not isinstance(observations, list) or \
            len(observations) != len(actual) + 3:
        raise RuntimeError("actual-formal runtime inventory invalid")
    phase_cases = plan.get("actual_formal_phase_case_ids")
    phase_observations = plan.get("actual_formal_phase_observation_ids")
    expected_phases = ["actual_formal_baseline", "actual_formal_preflight",
                       "actual_formal_authority", "actual_formal_fault_n10",
                       "actual_formal_t1_handoff"]
    if not isinstance(phase_cases, dict) or \
            set(phase_cases) != set(expected_phases) or \
            [case for phase in expected_phases
             for case in phase_cases[phase]] != actual or \
            not isinstance(phase_observations, dict) or \
            set(phase_observations) != set(expected_phases) or \
            [case for phase in expected_phases
             for case in phase_observations[phase]] != observations or \
            plan.get("baseline_five_consumer_execution_count") != 1 or \
            plan.get("context_transport_validation_execution_count") != 4:
        raise RuntimeError("actual-formal shard inventory invalid")
    return plan


def verify_coverage_runtime_plan(protocol: dict[str, Any],
                                 coverage: dict[str, Any]) -> dict[str, Any]:
    """Bind the executable case plan to the independently frozen coverage map."""
    mapped = coverage.get("runtime_execution_plan")
    protocol_plan = protocol.get("runtime_execution_plan")
    if not isinstance(mapped, dict) or not isinstance(protocol_plan, dict) or \
            protocol_plan != mapped:
        raise RuntimeError("negative runtime plan differs from frozen coverage map")
    verify_runtime_plan(protocol)
    return mapped


def valid_sha256(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(
        character in "0123456789abcdef" for character in value)


def verify_ast_inventory(path: Path, coverage: dict[str, Any]) -> dict[str, Any]:
    value = load_json(path)
    plan = coverage.get("ast_inventory_plan")
    if not isinstance(plan, dict) or value.get("schema") != \
            "vnext-t2-independent-negative-ast-inventory-r3" or \
            value.get("status") != "pass" or \
            value.get("plan_schema") != plan.get("schema"):
        raise RuntimeError("AST inventory schema/status mismatch")
    expected_counts = {
        "old_assertion_site_count": coverage["old_assertion_site_count"],
        "successor_assertion_site_count":
            coverage["successor_assertion_site_count"],
        "projection_assertion_site_count": coverage[
            "versioned_product_repair_regression"]["assertion_site_count"],
        "total_assertion_site_count":
            coverage["ast_inventory_plan"]["total_assertion_site_count"],
    }
    for field, expected in expected_counts.items():
        if value.get(field) != expected or plan.get(field) != expected:
            raise RuntimeError(f"AST inventory count mismatch: {field}")
    if value.get("source_count") != plan.get("source_count") or \
            value.get("line_number_nodes_removed_only_from_semantic_hash") \
            is not True or value.get("context_fields") != \
            ["testset_path", "function_path", "control_context",
             "site_ast_path"]:
        raise RuntimeError("AST inventory transform/context mismatch")
    observed_sources = value.get("source_receipts")
    expected_sources = plan.get("sources")
    if not isinstance(observed_sources, list) or \
            len(observed_sources) != len(expected_sources):
        raise RuntimeError("AST inventory source receipt count mismatch")
    for observed, expected in zip(observed_sources, expected_sources):
        for field in ("role", "path", "bytes", "sha256",
                      "assertion_site_count"):
            if observed.get(field) != expected.get(field):
                raise RuntimeError(
                    f"AST inventory source mismatch: {expected.get('path')}:{field}")

    expected_rows = [*coverage["old_assertion_sites"],
                     *coverage["successor_assertion_sites"],
                     *coverage["versioned_product_repair_regression"][
                         "assertion_sites"]]
    rows = value.get("rows")
    if not isinstance(rows, list) or len(rows) != len(expected_rows):
        raise RuntimeError("AST inventory row count mismatch")
    for observed, expected in zip(rows, expected_rows):
        for field in ("site_id", "source_path", "line", "macro_name",
                      "source_text_sha256"):
            expected_value = expected["id"] if field == "site_id" else \
                expected["path"] if field == "source_path" else \
                expected[field]
            if observed.get(field) != expected_value:
                raise RuntimeError(
                    f"AST inventory row mismatch: {expected['id']}:{field}")
        if not valid_sha256(observed.get("expression_hash")) or \
                not valid_sha256(observed.get("semantic_expression_hash")):
            raise RuntimeError(f"AST inventory digest invalid: {expected['id']}")
        for field in ("testset_path", "function_path", "control_context",
                      "site_ast_path"):
            if not isinstance(observed.get(field), list):
                raise RuntimeError(
                    f"AST inventory context absent: {expected['id']}:{field}")
        for context in observed["control_context"]:
            if not isinstance(context, dict) or \
                    context.get("head") not in \
                    ("for", "while", "if", "try", "let") or \
                    not isinstance(context.get("ast_path"), list) or \
                    not all(isinstance(index, int) and index >= 1
                            for index in context.get("ast_path", [])) or \
                    not isinstance(context.get("child_index"), int) or \
                    context.get("child_index") != (
                        context["ast_path"][-1]
                        if context["ast_path"] else 0) or \
                    not valid_sha256(context.get("raw_context_hash")) or \
                    not valid_sha256(context.get("semantic_context_hash")):
                raise RuntimeError(
                    f"AST control context invalid: {expected['id']}")
        if not observed["site_ast_path"] or not all(
                isinstance(index, int) and index >= 1
                for index in observed["site_ast_path"]):
            raise RuntimeError(f"AST site path invalid: {expected['id']}")
    return value


def verify_projection_observation(path: Path, stdout_path: Path) -> dict[str, Any]:
    value = load_json(path)
    if value.get("schema") != \
            "vnext-t2-package-full-content-projection-actual-r1" or \
            value.get("suite") != \
            "vnext-t2-package-full-content-projection-r1" or \
            value.get("status") != "actual_observed" or \
            value.get("classification") != "supplemental_product_regression" or \
            value.get("recorded_before_assertions") is not True or \
            value.get("planned_test_sites") != 24 or \
            value.get("assertion_sites_completed") != 0 or \
            value.get("formal_t2_accepted") is not False:
        raise RuntimeError("projection observation schema/status mismatch")
    groups = value.get("groups")
    expected_groups = {
        "reload_content_equivalence": 8,
        "wire_byte_tamper_detection": 7,
        "source_byte_tamper_detection": 7,
        "admission_envelope_projection": 2,
    }
    if not isinstance(groups, dict) or set(groups) != set(expected_groups):
        raise RuntimeError("projection observation group inventory mismatch")
    for name, sites in expected_groups.items():
        row = groups[name]
        if row.get("planned_sites") != sites or \
                row.get("observed_values") != sites:
            raise RuntimeError(f"projection group count mismatch: {name}")
    reload = groups["reload_content_equivalence"]
    if reload.get("original_validation") != "none" or \
            reload.get("reloaded_validation") != "none" or \
            reload.get("package_content_equal") is not True or \
            reload.get("content_hash_equal") is not True or \
            reload.get("projection_domain") != \
            "vnext-t2-t1-package-full-content-projection-v2" or \
            reload.get("projection_key_count") != 20 or \
            reload.get("wire_base64_equal") is not True or \
            reload.get("wire_length_equal") is not True:
        raise RuntimeError("projection reload/content observation mismatch")
    for name in ("wire_byte_tamper_detection",
                 "source_byte_tamper_detection"):
        row = groups[name]
        if row.get("stored_package_hash_retained") is not True or \
                row.get("stored_semantic_identity_retained") is not True or \
                row.get("full_content_equal") is not False or \
                row.get("full_content_hash_changed") is not True or \
                row.get("build_status") != "fail_closed" or \
                row.get("build_reason") != \
                "t2_preflight_t1_reloaded_package_mismatch" or \
                row.get("attempted_events") != 0 or \
                row.get("zero_attempted_counts") is not True or \
                not counts_are(row.get("attempted_counts"),
                               (0, 0, 0, 0, 0, 0, 0, 0)):
            raise RuntimeError(f"projection tamper observation mismatch: {name}")
    admission = groups["admission_envelope_projection"]
    if admission.get("projection_domain") != \
            "vnext-t2-t1-admission-full-content-projection-v2" or \
            admission.get("package_projection_full_content_equal") is not True or \
            admission.get("package_projection_hash_equal_observation") is not True:
        raise RuntimeError("admission projection observation mismatch")
    for name in ("original_content_hash", "reloaded_content_hash",
                 "wire_tampered_content_hash", "source_tampered_content_hash"):
        if not valid_sha256(value.get(name)):
            raise RuntimeError(f"projection observation digest invalid: {name}")
    stdout = stdout_path.read_text(encoding="utf-8", errors="replace")
    marker = ("VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4 "
              "classification=supplemental_product_regression "
              "formal_t2_accepted=false")
    if marker not in stdout:
        raise RuntimeError("projection post-assertion PASS marker absent")
    return value


def input_receipts(protocol: dict[str, Any]) -> dict[str, Any]:
    return {relative: file_receipt(ROOT / relative)
            for relative in sorted(protocol["inputs"])}


def canonical_input_pins(value: Any, label: str) -> dict[str, dict[str, Any]]:
    if not isinstance(value, dict):
        raise RuntimeError(f"{label} is not a path-keyed pin object")
    normalized: dict[str, dict[str, Any]] = {}
    for relative, row in value.items():
        if not isinstance(relative, str) or not isinstance(row, dict) or \
                row.get("path") != relative or \
                not isinstance(row.get("bytes"), int) or \
                row["bytes"] < 0 or not valid_sha256(row.get("sha256")):
            raise RuntimeError(f"{label} pin is malformed: {relative}")
        normalized[relative] = {
            "path": relative, "bytes": row["bytes"],
            "sha256": row["sha256"].lower(),
        }
    return normalized


def verify_positive_reuse_input_pins(protocol: dict[str, Any]) -> dict[str, Any]:
    dispatch = protocol.get("positive_dispatch")
    if not isinstance(dispatch, dict) or not isinstance(dispatch.get("root"), str):
        raise RuntimeError("positive dispatch root is absent")
    runtime_inputs_receipt = dispatch.get("runtime_inputs")
    if not isinstance(runtime_inputs_receipt, dict) or \
            not isinstance(runtime_inputs_receipt.get("path"), str):
        raise RuntimeError("positive runtime_inputs receipt is absent")
    runtime_inputs_path = ROOT / runtime_inputs_receipt["path"]
    actual_runtime_receipt = file_receipt(runtime_inputs_path)
    if {key: runtime_inputs_receipt.get(key) for key in ("path", "bytes", "sha256")} != {
            "path": runtime_inputs_receipt["path"],
            "bytes": actual_runtime_receipt["bytes"],
            "sha256": actual_runtime_receipt["sha256"],
    }:
        raise RuntimeError("positive runtime_inputs receipt drift")
    runtime_inputs = load_json(runtime_inputs_path)
    positive_pins = canonical_input_pins(
        runtime_inputs.get("inputs"), "positive r3 runtime inputs")
    frozen_pins = canonical_input_pins(
        protocol.get("positive_reuse_input_pins"),
        "negative protocol positive-reuse input pins")
    protocol_pins = canonical_input_pins(
        protocol.get("inputs"), "negative protocol input pins")
    if runtime_inputs.get("schema") != "vnext-t2-formal-runtime-inputs-r3" or \
            runtime_inputs.get("runtime_dependency_count") != 104 or \
            len(positive_pins) != 104 or frozen_pins != positive_pins:
        raise RuntimeError("positive r3 104-input pin set differs from protocol")
    positive_evidence = protocol.get("positive_evidence")
    if not isinstance(positive_evidence, dict) or not isinstance(
            positive_evidence.get("formal_serial_replay"), dict):
        raise RuntimeError("positive r3 replay receipt is absent")
    positive_replay = load_json(ROOT / positive_evidence[
        "formal_serial_replay"]["path"])
    for field in ("inputs_before", "inputs_after"):
        if canonical_input_pins(positive_replay.get(field),
                                f"positive replay {field}") != positive_pins:
            raise RuntimeError(f"positive r3 replay {field} differs from 104 pins")
    if positive_replay.get("pinned_input_changes") != [] or \
            positive_replay.get("status") != "pass":
        raise RuntimeError("positive r3 replay is not a clean pinned-input pass")
    if any(protocol_pins.get(relative) != row
           for relative, row in positive_pins.items()):
        raise RuntimeError("positive r3 input pin differs from protocol input closure")
    current: dict[str, dict[str, Any]] = {}
    for relative, expected in sorted(positive_pins.items()):
        path = (ROOT / relative).resolve()
        path.relative_to(ROOT)
        actual = file_receipt(path)
        row = {"path": relative, "bytes": actual["bytes"],
               "sha256": actual["sha256"]}
        if row != expected:
            raise RuntimeError(f"positive r3 current input drift: {relative}")
        current[relative] = row
    identity = sha256_bytes(json.dumps(
        positive_pins, sort_keys=True, separators=(",", ":")).encode())
    return {
        "schema": "vnext-t2-positive-r3-input-pin-join-r1",
        "status": "pass",
        "positive_runtime_input_count": len(positive_pins),
        "positive_runtime_inputs_receipt": actual_runtime_receipt,
        "pin_identity_sha256": identity,
        "verified_current_pins": current,
        "actual_model_attestation": "unavailable",
    }


def verify_assertion_site_hit_summary(summary: dict[str, Any],
                                      coverage: dict[str, Any], phase: str,
                                      *, coverage_map_sha256: str
                                      ) -> dict[str, int]:
    plan = coverage.get("successor_assertion_runtime_hit_plan")
    if not isinstance(plan, dict) or plan.get("status") != \
            "expected_source_site_hits_static_plan_actual_hits_pending":
        raise RuntimeError("source-site hit plan is absent or misclassified")
    if summary.get("assertion_site_hit_receipt_schema") != \
            "vnext-t2-source-site-hit-receipt-r1" or \
            summary.get("assertion_site_hit_phase") != phase or \
            summary.get("assertion_site_hit_coverage_map_sha256") != \
            coverage_map_sha256:
        raise RuntimeError(f"source-site hit receipt identity mismatch: {phase}")
    expected_phase = plan.get("phase_site_hit_counts", {}).get(phase)
    if not isinstance(expected_phase, dict):
        raise RuntimeError(f"source-site hit phase is not planned: {phase}")
    phase_paths = {row.get("path") for row in
                   coverage.get("successor_assertion_sites", [])
                   if phase in row.get("expected_phase_hits", {})}
    if len(phase_paths) != 1:
        raise RuntimeError(f"source-site hit phase has ambiguous source: {phase}")
    source_path = next(iter(phase_paths))
    source_rows = coverage.get("ast_inventory_plan", {}).get("sources", [])
    source_receipts = [row for row in source_rows
                       if row.get("path") == source_path]
    if len(source_receipts) != 1 or \
            summary.get("assertion_site_hit_source_sha256") != \
            source_receipts[0].get("sha256"):
        raise RuntimeError(f"source-site hit source digest mismatch: {phase}")
    source_ids = {row["id"] for row in coverage["successor_assertion_sites"]
                  if row.get("path") == source_path}
    observed_raw = summary.get("assertion_site_hit_counts")
    if summary.get("assertion_site_hit_source_path") != source_path or \
            not isinstance(observed_raw, dict) or set(observed_raw) != source_ids or \
            summary.get("unmapped_assertion_sources") not in ([], ()):
        raise RuntimeError(f"source-site hit source inventory mismatch: {phase}")
    observed: dict[str, int] = {}
    for site_id, count in observed_raw.items():
        if not isinstance(count, int) or count < 0:
            raise RuntimeError(f"source-site hit count is malformed: {phase}:{site_id}")
        observed[site_id] = count
    expected_full = {site_id: int(expected_phase.get(site_id, 0))
                     for site_id in source_ids}
    if observed != expected_full:
        raise RuntimeError(f"source-site hit count mismatch: {phase}")
    expected_total = sum(expected_full.values())
    if summary.get("assertion_site_hit_count_observed") != expected_total:
        raise RuntimeError(f"source-site hit total mismatch: {phase}")
    return observed


def aggregate_assertion_site_hit_receipts(
        summaries: list[dict[str, Any]], coverage: dict[str, Any],
        *, coverage_map_sha256: str) -> dict[str, Any]:
    hit_plan = coverage.get("successor_assertion_runtime_hit_plan")
    if not isinstance(hit_plan, dict):
        raise RuntimeError("source-site hit plan is absent")
    phases = hit_plan.get("phase_order")
    if not isinstance(phases, list) or len(phases) != 7 or \
            len(summaries) != len(phases):
        raise RuntimeError("source-site hit phase inventory is incomplete")
    merged = {row["id"]: 0 for row in coverage["successor_assertion_sites"]}
    observed_phase_totals: dict[str, int] = {}
    for phase, summary in zip(phases, summaries):
        if summary.get("assertion_site_hit_coverage_map_sha256") != \
                coverage_map_sha256:
            raise RuntimeError(f"source-site hit map pin drift: {phase}")
        source_hits = verify_assertion_site_hit_summary(
            summary, coverage, phase,
            coverage_map_sha256=coverage_map_sha256)
        for site_id, count in source_hits.items():
            merged[site_id] += count
        observed_phase_totals[phase] = sum(source_hits.values())
    expected = {site_id: int(row.get("runtime_multiplicity", 0))
                for site_id, row in ((row["id"], row)
                    for row in coverage["successor_assertion_sites"])}
    if merged != expected:
        raise RuntimeError("aggregate source-site hit count differs from static plan")
    context_ids = set(coverage.get("context_transport_assertion_ids", []))
    context_hits = sum(merged[site_id] for site_id in context_ids)
    preserved_hits = sum(count for site_id, count in merged.items()
                         if site_id not in context_ids)
    if len(merged) != 214 or sum(merged.values()) != 622 or \
            len(context_ids) != 23 or context_hits != 92 or preserved_hits != 530:
        raise RuntimeError("aggregate source-site hit total is not 214/622")
    return {
        "schema": "vnext-t2-source-site-hit-aggregate-r1",
        "status": "actual_observed_and_exactly_matched_to_static_plan",
        "phase_order": phases,
        "phase_observed_hit_counts": observed_phase_totals,
        "assertion_site_runtime_hits_observed": dict(sorted(merged.items())),
        "assertion_site_count_observed": len(merged),
        "assertion_site_hit_count_observed": sum(merged.values()),
        "context_transport_assertion_sites_completed_observed": context_hits,
        "preserved_successor_runtime_hit_count_observed": preserved_hits,
        "coverage_map_sha256": coverage_map_sha256,
        "formal_t2_accepted": False,
    }


def verify_frozen_positive_evidence(
        positive_root: Path, frozen: dict[str, Any]) -> dict[str, Any]:
    expected_root = (ROOT / frozen["root"]).resolve()
    if positive_root != expected_root:
        raise RuntimeError("positive evidence root differs from frozen protocol")
    expected_labels = {
        "formal_serial_replay", "pipeline_final",
        "producer_candidate_package", "producer_candidate_t1_receipt",
        "producer_result", "producer_run_receipt",
        "replay_candidate_package", "replay_candidate_t1_receipt",
        "replay_result", "replay_run_receipt",
    }
    if set(frozen) != expected_labels | {"root"}:
        raise RuntimeError("positive evidence receipt inventory mismatch")
    observed: dict[str, Any] = {}
    for label in sorted(expected_labels):
        expected = frozen[label]
        path = (ROOT / expected["path"]).resolve()
        path.relative_to(positive_root)
        actual = file_receipt(path)
        if actual["bytes"] != expected["bytes"] or \
                actual["sha256"] != expected["sha256"]:
            raise RuntimeError(f"positive evidence receipt drift: {label}")
        observed[label] = actual
    return observed


def write_parse_manifest(path: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    paths = protocol.get("julia_parse_paths")
    if not isinstance(paths, list) or not paths or \
            len(paths) != len(set(paths)):
        raise RuntimeError("negative protocol Julia parse inventory invalid")
    expected_gate = PARSE_GATE.relative_to(ROOT).as_posix()
    if expected_gate not in paths:
        raise RuntimeError("negative protocol omits the parse gate itself")
    rows = []
    for relative in paths:
        if relative not in protocol["inputs"] or not relative.endswith(".jl"):
            raise RuntimeError(f"unbound Julia parse path: {relative}")
        rows.append(protocol["inputs"][relative]["sha256"] + "\t" + relative)
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.write("\n".join(rows) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    return file_receipt(path)


def counts_are(value: Any, expected: tuple[int, ...]) -> bool:
    if not isinstance(value, dict):
        return False
    keys = ("e0", "gi1a", "e1", "e2", "n10",
            "compiler", "provider", "solver")
    return tuple(value.get(key) for key in keys) == expected


def verify_context_transport_observation(path: Path, shard: str) -> dict[str, Any]:
    value = load_json(path)
    required_true = (
        "context_authorization_join", "producer_natural_exit_zero",
        "five_consumer_counts_verified", "source_content_join",
        "package_type_valid", "package_context_join", "package_t1_join",
        "adapter_binding_present", "candidate_hash_join",
        "candidate_bytes_join", "build_input_type_valid",
        "input_content_join", "result_committed", "ledger_type_valid",
        "ledger_input_join", "ledger_package_join", "ledger_counts_join",
    )
    if value.get("schema") != \
            "vnext-t2-independent-negative-context-transport-observation-r3" or \
            value.get("shard") != shard or \
            value.get("recorded_before_assertions") is not True or \
            value.get("formal_t2_accepted") is not False or \
            any(value.get(field) is not True for field in required_true) or \
            value.get("source_status") != "source_ready" or \
            value.get("source_errors") not in ([], ()) or \
            value.get("package_validation") is not None or \
            value.get("build_status") != "prepared_not_executed" or \
            value.get("input_validation_status") != "valid" or \
            value.get("result_status") != "complete_contract_receipts":
        raise RuntimeError(f"context transport observation mismatch: {shard}")
    return value


def write_baseline_authorization(path: Path, phase_dir: Path,
                                 phase: dict[str, Any], summary: dict[str, Any],
                                 context_path: Path) -> dict[str, Any]:
    counts = summary.get("final_ledger_fingerprint", {}).get("counts")
    natural = phase.get("stop_reason") == "natural_exit" and \
        phase.get("exit_code") == 0 and not phase.get("residual_heavy_processes")
    five_counts = counts_are(counts, (1, 1, 1, 1, 1, 0, 0, 0))
    if not natural or not five_counts or summary.get("status") != "pass" or \
            summary.get("observed_case_ids") != ["ACTUAL_BASELINE_POSITIVE"]:
        raise RuntimeError("baseline cannot be authorized")
    context = file_receipt(context_path)
    value = {
        "schema": "vnext-t2-independent-negative-baseline-authorization-r3",
        "producer_natural_exit_zero": natural,
        "five_consumer_counts_verified": five_counts,
        "context_sha256": context["sha256"],
        "context": context,
        "producer_phase": file_receipt(phase_dir / "phase.json"),
        "producer_summary": file_receipt(
            phase_dir / "artifacts" / "summary.json"),
        "producer_observations": file_receipt(
            phase_dir / "artifacts" / "observations.jsonl"),
        "producer_stage_trace": file_receipt(
            phase_dir / "artifacts" / "stage_trace.tsv"),
        "input_hash": digest_value(
            summary.get("final_ledger_fingerprint", {}).get("input_hash"),
            "baseline ledger input hash"),
        "package_hash": digest_value(
            summary.get("final_ledger_fingerprint", {}).get("package_hash"),
            "baseline ledger package hash"),
        "formal_t2_accepted": False,
    }
    write_json_new(path, value)
    return value


def verify_artifact_helper(path: Path, mode: str, attacked_path: Path,
                           expected_sha256: str) -> dict[str, Any]:
    value = load_json(path)
    expected_rejection = (
        "producer_candidate_package_raw_sha256_mismatch"
        if mode == "raw_hash_mismatch" else
        "producer_candidate_package_deserialize_failed")
    if value.get("schema") != \
            "vnext-t2-independent-artifact-preflight-negative-r1" or \
            value.get("mode") != mode or \
            value.get("expected_rejection") != expected_rejection or \
            value.get("actual_rejection") != expected_rejection:
        raise RuntimeError(f"artifact helper classification mismatch: {mode}")
    if value.get("publication_committed") is not False or \
            value.get("published_artifacts") not in ([], ()) or \
            value.get("original_artifact_unchanged") is not True:
        raise RuntimeError(f"artifact helper fail-atomic mismatch: {mode}")
    zero = (0, 0, 0, 0, 0, 0, 0, 0)
    if not counts_are(value.get("consumer_attempted_counts"), zero) or \
            not counts_are(value.get("committed_counts"), zero):
        raise RuntimeError(f"artifact helper count mismatch: {mode}")
    attacked = file_receipt(attacked_path)
    if value.get("attacked_artifact_bytes") != attacked["bytes"] or \
            value.get("attacked_artifact_actual_sha256") != attacked["sha256"] or \
            value.get("attacked_artifact_expected_sha256") != \
            expected_sha256.lower():
        raise RuntimeError(f"artifact helper input receipt mismatch: {mode}")
    if mode == "raw_hash_mismatch":
        if value.get("hash_verified") is not False or \
                value.get("deserialize_attempted") is not False:
            raise RuntimeError("raw-hash helper reached deserializer")
    elif value.get("hash_verified") is not True or \
            value.get("deserialize_attempted") is not True:
        raise RuntimeError(f"corrupt helper missed deserializer: {mode}")
    return value


def assert_no_final_publication(output: Path) -> None:
    for name in ("candidate_package.jls",
                 "candidate_t1_admission_receipt.json",
                 "t2_result.jls", "run_receipt.json"):
        if (output / name).exists() or (output / name).is_symlink():
            raise RuntimeError(f"unexpected final publication: {output / name}")


def verify_uncommitted(output: Path, stage: str, *, zero_call: bool,
                       precondition_failure: str | None = None) -> dict[str, Any]:
    path = output / "replay_uncommitted_attempt.json"
    value = load_json(path)
    if value.get("schema") != "vnext-t2-formal-replay-uncommitted-attempt-r2":
        raise RuntimeError("uncommitted receipt schema mismatch")
    if value.get("stage") != stage or value.get("publication_committed") is not False:
        raise RuntimeError(f"uncommitted stage/publication mismatch: {stage}")
    if value.get("published_artifacts") not in ([], ()):
        raise RuntimeError("uncommitted receipt lists published artifacts")
    if value.get("precondition_failure") != precondition_failure:
        raise RuntimeError(f"uncommitted precondition mismatch: {stage}")
    if value.get("caller_package_sha256_before") != \
            value.get("caller_package_sha256_after"):
        raise RuntimeError("uncommitted attempt changed caller package")
    if value.get("producer_artifact_unchanged") is not True or \
            value.get("producer_artifact_sha256_before") != \
            value.get("producer_artifact_sha256_after") or \
            value.get("producer_artifact_bytes_before") != \
            value.get("producer_artifact_bytes_after"):
        raise RuntimeError("uncommitted attempt changed producer artifact")
    attempted = value.get("attempted_counts")
    committed = value.get("committed_counts")
    expected = (0, 0, 0, 0, 0, 0, 0, 0) if zero_call else \
        (1, 1, 1, 1, 1, 0, 0, 0)
    if not counts_are(attempted, expected) or not counts_are(committed, expected):
        raise RuntimeError(f"uncommitted count mismatch: {stage}")
    if value.get("authority_input_accepted") is not (not zero_call):
        raise RuntimeError(f"uncommitted authority classification mismatch: {stage}")
    expected_consumers = [] if zero_call else \
        ["E0", "GI1A", "E1", "E2", "UP2_N10"]
    if value.get("consumers_attempted") != expected_consumers:
        raise RuntimeError(f"uncommitted consumer trace mismatch: {stage}")
    if value.get("result_committed_in_process") is not (not zero_call):
        raise RuntimeError(f"uncommitted in-process result mismatch: {stage}")
    assert_no_final_publication(output)
    return value


def read_positive(positive: Path, final_sha: str,
                  pipeline_sha: str) -> dict[str, Any]:
    final_path = positive / "formal_t2_serial_replay.json"
    pipeline_path = positive / "pipeline_final.json"
    if file_receipt(final_path)["sha256"] != final_sha.lower():
        raise RuntimeError("positive formal serial replay SHA-256 mismatch")
    if file_receipt(pipeline_path)["sha256"] != pipeline_sha.lower():
        raise RuntimeError("positive pipeline-final SHA-256 mismatch")
    final = load_json(final_path)
    pipeline = load_json(pipeline_path)
    if final.get("schema") != "vnext-t2-formal-serial-candidate-replay-r1" or \
            final.get("status") != "pass":
        raise RuntimeError("positive formal serial replay did not pass")
    if pipeline.get("status") != "pass" or pipeline.get("failure") is not None:
        raise RuntimeError("positive pipeline-final did not pass")
    if final.get("formal_gate_evidence_kind") != "formal_t1_actual" or \
            final.get("formal_gate_verified") is not True:
        raise RuntimeError("positive formal gate was not actual and verified")
    if final.get("formal_t2_accepted") is not False:
        raise RuntimeError("positive evidence overclaims T2 acceptance")
    producer = positive / "producer"
    producer_receipt_path = producer / "run_receipt.json"
    producer_receipt = load_json(producer_receipt_path)
    candidate_path = producer / "candidate_t1_admission_receipt.json"
    package_path = producer / "candidate_package.jls"
    return {
        "final_path": final_path, "pipeline_path": pipeline_path,
        "final": final, "pipeline": pipeline, "producer": producer,
        "producer_receipt_path": producer_receipt_path,
        "producer_receipt": producer_receipt,
        "candidate_path": candidate_path,
        "candidate_sha256": file_receipt(candidate_path)["sha256"],
        "package_path": package_path,
        "package_sha256": file_receipt(package_path)["sha256"],
        "stable_projection_hash": digest_value(
            producer_receipt["stable_projection_hash"],
            "positive stable projection hash"),
        "result_reload_identity_hash": digest_value(
            producer_receipt["result_reload_identity_hash"],
            "positive result reload identity hash"),
        "manifest_path": Path(
            final["software_acceptance_manifest"]["path"]).resolve(),
        "manifest_sha256": final["software_acceptance_manifest"]["sha256"],
        "verification_path": Path(
            final["software_acceptance_manifest"]["verification_path"]).resolve(),
        "verification_sha256":
            final["software_acceptance_manifest"]["verification_sha256"],
    }


def candidate_command(julia_common: list[str], positive: dict[str, Any],
                      output: Path, candidate_hash: str, stable_hash: str,
                      reload_hash: str, *, package_path: Path | None = None,
                      package_sha256: str | None = None) -> list[str]:
    supplied_package = package_path or positive["package_path"]
    supplied_package_sha256 = package_sha256 or positive["package_sha256"]
    return julia_common + [str(CANDIDATE_DRIVER), "replay",
        str(positive["manifest_path"]), positive["manifest_sha256"],
        str(positive["verification_path"]), positive["verification_sha256"],
        str(output), candidate_hash, stable_hash,
        str(supplied_package), supplied_package_sha256, reload_hash]


def build_actual_formal_shard_command(
        julia_common: list[str], mode: str, authorities: list[str],
        context_path: Path | str, context_sha256: str,
        authorization_path: Path | str, authorization_sha256: str,
        output_dir: Path | str, coverage_map_path: Path | str,
        coverage_map_sha256: str) -> list[str]:
    """Build and guard the exact r3 driver's 16-argument shard invocation."""
    expected_modes = {"preflight", "authority", "fault_n10", "t1_handoff"}
    if mode not in expected_modes and not (
            mode.startswith("authority-case:") and
            mode.split(":", 1)[1] in AUTHORITY_CASE_ORDER):
        raise ValueError(f"unsupported actual-formal shard mode: {mode}")
    if len(authorities) != 8:
        raise ValueError("actual-formal shard requires four authority path/hash pairs")
    for name, digest in (("context", context_sha256),
                         ("authorization", authorization_sha256),
                         ("coverage map", coverage_map_sha256)):
        if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
            raise ValueError(f"{name} SHA-256 must be lowercase hexadecimal")
    command = list(julia_common) + [str(ACTUAL_DRIVER), mode, *authorities,
        str(context_path), context_sha256,
        str(authorization_path), authorization_sha256,
        str(output_dir), str(coverage_map_path), coverage_map_sha256]
    driver_index = command.index(str(ACTUAL_DRIVER))
    driver_args = command[driver_index + 1:]
    if len(driver_args) != 16 or driver_args[0] != mode or \
            driver_args[14] != str(coverage_map_path) or \
            driver_args[15] != coverage_map_sha256:
        raise RuntimeError("actual-formal shard argv violates the 16-argument driver contract")
    return command


def _authority_source_ids(coverage: dict[str, Any]) -> set[str]:
    source_path = "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r5.jl"
    return {row["id"] for row in coverage["successor_assertion_sites"]
            if row.get("path") == source_path}


def verify_authority_case_receipt(
        case_id: str, case_dir: Path, expected_command: list[str],
        coverage: dict[str, Any], *, coverage_map_sha256: str,
        driver_sha256: str, context_sha256: str,
        authorization_sha256: str,
        authority_path_hash_pairs: list[str]) -> tuple[dict[str, Any], dict[str, int]]:
    if case_id not in AUTHORITY_CASE_ORDER:
        raise RuntimeError(f"unknown authority case receipt: {case_id}")
    artifact_dir = case_dir / "artifacts"
    phase_path = case_dir / "phase.json"
    summary_path = artifact_dir / "summary.json"
    progress_path = artifact_dir / "case_progress.jsonl"
    observations_path = artifact_dir / "observations.jsonl"
    transport_path = artifact_dir / "context_transport_observation.json"
    phase = load_json(phase_path)
    if phase.get("name") != f"actual_formal_authority_case_{case_id}" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 0 or phase.get("residual_heavy_processes"):
        raise RuntimeError(f"authority case did not naturally pass: {case_id}")
    if phase.get("working_set_limit_bytes") != AUTHORITY_WORKING_SET_LIMIT_BYTES or \
            not 0 < phase.get("timeout_seconds", 0) <= AUTHORITY_CASE_TIMEOUT_SECONDS:
        raise RuntimeError(f"authority case resource contract mismatch: {case_id}")
    elapsed = phase.get("seconds")
    peak = phase.get("peak_process_tree_working_set_bytes")
    if not isinstance(elapsed, (int, float)) or elapsed < 0 or \
            elapsed > phase["timeout_seconds"] + 2 or \
            not isinstance(peak, int) or peak < 0 or \
            peak >= AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise RuntimeError(f"authority case measured resource receipt invalid: {case_id}")
    stdout_path = case_dir / "stdout.raw"
    stderr_path = case_dir / "stderr.raw"
    if phase.get("stdout") != file_receipt(stdout_path) or \
            phase.get("stderr") != file_receipt(stderr_path):
        raise RuntimeError(f"authority case raw phase-output pin drift: {case_id}")
    stdout_text = stdout_path.read_text(encoding="utf-8", errors="replace")
    pass_marker = "VNEXT_T2_ACTUAL_FORMAL_SHARD=PASS mode=authority"
    if stdout_text.count(pass_marker) != 1:
        raise RuntimeError(f"authority case natural PASS marker missing/duplicate: {case_id}")
    command = phase.get("command")
    if not isinstance(command, list) or command != expected_command:
        # Resume may use a different immutable context/authorization path. Check
        # exact authority and source arguments, plus content hashes at old paths.
        if not isinstance(command, list):
            raise RuntimeError(f"authority case command is malformed: {case_id}")
        try:
            driver_index = command.index(str(ACTUAL_DRIVER))
            expected_driver_index = expected_command.index(str(ACTUAL_DRIVER))
        except ValueError as error:
            raise RuntimeError(f"authority case driver argv is malformed: {case_id}") from error
        old_args = command[driver_index + 1:]
        new_args = expected_command[expected_driver_index + 1:]
        if driver_index != expected_driver_index or \
                command[:driver_index + 1] != expected_command[:expected_driver_index + 1] or \
                len(old_args) != 16 or old_args[:9] != new_args[:9] or \
                old_args[0] != f"authority-case:{case_id}" or \
                old_args[10] != context_sha256 or old_args[12] != authorization_sha256 or \
                old_args[14:] != new_args[14:] or \
                old_args[13] != str(artifact_dir):
            raise RuntimeError(f"authority case command drift: {case_id}")
        old_context = Path(old_args[9])
        old_authorization = Path(old_args[11])
        if not old_context.is_file() or not old_authorization.is_file() or \
                file_receipt(old_context)["sha256"] != context_sha256 or \
                file_receipt(old_authorization)["sha256"] != authorization_sha256:
            raise RuntimeError(f"authority case reused context/authorization drift: {case_id}")
    driver_index = command.index(str(ACTUAL_DRIVER))
    old_args = command[driver_index + 1:]
    if old_args[1:9] != authority_path_hash_pairs or \
            old_args[0] != f"authority-case:{case_id}" or \
            old_args[10] != context_sha256 or old_args[12] != authorization_sha256:
        raise RuntimeError(f"authority case pinned input argv mismatch: {case_id}")
    summary = load_json(summary_path)
    if summary.get("schema") != "vnext-t2-independent-actual-negative-shard-summary-r5" or \
            summary.get("status") != "pass" or summary.get("shard") != "authority" or \
            summary.get("observed_case_ids") != [case_id] or \
            summary.get("observed_case_count") != 1 or \
            summary.get("formal_t2_accepted") is not False or \
            summary.get("physical_acceptance") is not False or \
            summary.get("scientific_acceptance") is not False or \
            summary.get("context_sha256") != context_sha256 or \
            summary.get("context_unchanged") is not True or \
            summary.get("source_revalidation_status") != "source_ready" or \
            summary.get("rebuilt_input_full_content_join") is not True or \
            summary.get("producer_package_unchanged") is not True or \
            summary.get("candidate_receipt_unchanged") is not True or \
            summary.get("package_wire_unchanged") is not True or \
            summary.get("prior_ledger_unchanged") is not True:
        raise RuntimeError(f"authority case summary contract mismatch: {case_id}")
    summary_markers = [line.partition("=")[2] for line in stdout_text.splitlines()
                       if line.startswith("VNEXT_T2_NEGATIVE_SHARD_SUMMARY=")]
    if len(summary_markers) != 1 or json.loads(summary_markers[0]) != summary:
        raise RuntimeError(f"authority case stdout/summary receipt mismatch: {case_id}")
    hit_plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    if hit_plan.get("case_order") != AUTHORITY_CASE_ORDER or \
            hit_plan.get("status") != "static_plan_actual_case_hits_pending":
        raise RuntimeError("authority case-hit plan identity mismatch")
    source_ids = _authority_source_ids(coverage)
    expected_summary = hit_plan["case_site_hit_counts"][case_id]
    observed_raw = summary.get("assertion_site_hit_counts")
    if summary.get("assertion_site_hit_receipt_schema") != \
            "vnext-t2-source-site-hit-receipt-r1" or \
            summary.get("assertion_site_hit_phase") != "actual_formal_authority" or \
            summary.get("assertion_site_hit_source_path") != hit_plan["source_path"] or \
            summary.get("assertion_site_hit_source_sha256") != driver_sha256 or \
            summary.get("assertion_site_hit_coverage_map_sha256") != coverage_map_sha256 or \
            not isinstance(observed_raw, dict) or set(observed_raw) != source_ids or \
            any(not isinstance(value, int) or value < 0 for value in observed_raw.values()) or \
            observed_raw != expected_summary or \
            summary.get("assertion_site_hit_count_observed") != sum(expected_summary.values()) or \
            summary.get("unmapped_assertion_sources") != []:
        raise RuntimeError(f"authority case source-site hits differ from plan: {case_id}")
    progress_rows = load_jsonl(progress_path)
    if len(progress_rows) != 3:
        raise RuntimeError(f"authority case progress event count mismatch: {case_id}")
    header, begin, complete = progress_rows
    if header.get("schema") != "vnext-t2-authority-case-progress-r2" or \
            header.get("event") != "header" or \
            header.get("phase") != "actual_formal_authority" or \
            header.get("selected_case_id") != case_id or \
            header.get("source_path") != hit_plan["source_path"] or \
            header.get("driver_version") != \
                "independent-actual-negative-r5-authority-case-replay" or \
            header.get("expected_case_ids") != [case_id] or \
            header.get("status") != "progress_only" or \
            header.get("source_sha256") != driver_sha256 or \
            header.get("coverage_map_sha256") != coverage_map_sha256 or \
            header.get("site_ids") != sorted(source_ids) or \
            header.get("actual_hit_counts_are_measured") is not True or \
            header.get("formal_t2_accepted") is not False or \
            begin.get("event") != "case_begin" or begin.get("case_id") != case_id or \
            begin.get("phase") != "actual_formal_authority" or \
            begin.get("selected_case_id") != case_id or \
            begin.get("sequence") != 1 or \
            not isinstance(begin.get("monotonic_time_ns"), int) or \
            begin.get("monotonic_time_ns", 0) <= 0 or \
            complete.get("event") != "case_complete" or \
            complete.get("case_id") != case_id or \
            complete.get("phase") != "actual_formal_authority" or \
            complete.get("selected_case_id") != case_id or \
            complete.get("sequence") != 1 or \
            not isinstance(complete.get("monotonic_time_ns"), int) or \
            complete.get("monotonic_time_ns", 0) <= 0 or \
            complete.get("status") != "completed" or \
            complete.get("case_completed") is not True or \
            complete.get("formal_t2_accepted") is not False or \
            complete.get("all_recorded_assertions_passed_observed") is not True or \
            complete.get("unmapped_assertion_source_count_observed") != 0 or \
            complete.get("status") != "completed":
        raise RuntimeError(f"authority case progress receipt invalid: {case_id}")
    expected_progress = dict(expected_summary)
    if case_id == AUTHORITY_CASE_ORDER[0]:
        for site_id in hit_plan["context_transport_site_ids"]:
            expected_progress[site_id] -= 1
            if expected_progress[site_id] < 0:
                raise RuntimeError("context transport hit was not allocated to first case")
    event_hits = complete.get("assertion_site_hit_counts_observed")
    expected_result_counts = {
        "pass": sum(expected_progress.values()), "fail": 0,
        "error": 0, "broken": 0, "other": 0}
    if not isinstance(event_hits, dict) or set(event_hits) != source_ids or \
            event_hits != expected_progress or \
            complete.get("assertion_site_hit_count_observed") != sum(expected_progress.values()) or \
            complete.get("assertion_result_count_observed") != sum(expected_progress.values()) or \
            complete.get("assertion_result_counts_observed") != expected_result_counts:
        raise RuntimeError(f"authority case actual hit event mismatch: {case_id}")
    if summary.get("authority_case_progress_path") != "case_progress.jsonl" or \
            summary.get("authority_case_progress_sha256") != file_receipt(progress_path)["sha256"] or \
            summary.get("observation_file_sha256") != file_receipt(observations_path)["sha256"]:
        raise RuntimeError(f"authority case raw receipt pin mismatch: {case_id}")
    progress_markers = [line.partition("=")[2] for line in stdout_text.splitlines()
                        if line.startswith("VNEXT_T2_NEGATIVE_CASE_PROGRESS=")]
    if len(progress_markers) != 3 or \
            [json.loads(row) for row in progress_markers] != progress_rows:
        raise RuntimeError(f"authority case flushed progress/raw mismatch: {case_id}")
    observations = load_jsonl(observations_path)
    if [row.get("case_id") for row in observations] != [case_id]:
        raise RuntimeError(f"authority case observation inventory mismatch: {case_id}")
    transport = verify_context_transport_observation(transport_path, "authority")
    if summary.get("context_transport_observation_sha256") != \
            file_receipt(transport_path)["sha256"]:
        raise RuntimeError(f"authority case context transport observation invalid: {case_id}")
    return summary, dict(observed_raw)


def write_jsonl_new(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        for row in rows:
            stream.write(json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n")
        stream.flush()
        os.fsync(stream.fileno())


def verify_authority_resume_ancestry(
        resume_root: Path, authority_dir: Path, current_protocol_path: Path,
        current_protocol_sha256: str, current_inputs: dict[str, Any],
        repository_head: str, expected_cases: list[str]
        ) -> tuple[dict[str, Any], dict[str, Path]]:
    resume_root = resume_root.resolve()
    resume_root.relative_to(ROOT / "docs/implementation/UP1-04A-VNEXT-T2")
    if not resume_root.is_dir() or resume_root == authority_dir.resolve():
        raise ValueError("authority resume source must be an existing prior T2 run leaf")
    prior_start_path = resume_root / "pipeline_start.json"
    prior_final_path = resume_root / "pipeline_final.json"
    prior_start = load_json(prior_start_path)
    prior_final = load_json(prior_final_path)
    current_protocol_receipt = file_receipt(current_protocol_path)
    if prior_start.get("repository_head") != repository_head or \
            prior_start.get("protocol_expected_sha256") != current_protocol_sha256 or \
            prior_start.get("protocol") != current_protocol_receipt or \
            prior_final.get("protocol") != current_protocol_receipt or \
            prior_start.get("inputs_before") != current_inputs or \
            prior_final.get("repository_head_before") != repository_head or \
            prior_final.get("repository_head_after") != repository_head or \
            prior_final.get("inputs_before") != current_inputs or \
            prior_final.get("inputs_after") != current_inputs or \
            prior_final.get("formal_t2_accepted") is not False:
        raise RuntimeError("authority resume source is not bound to unchanged protocol inputs")
    prior_phases = prior_final.get("phases")
    if not isinstance(prior_phases, list):
        raise RuntimeError("authority resume parent phase ancestry is absent")
    authority_phases = [phase for phase in prior_phases
        if isinstance(phase, dict) and phase.get("name") == "actual_formal_authority"]
    authority_phase_path = resume_root / "actual_formal_authority" / "phase.json"
    if len(authority_phases) != 1 or not authority_phase_path.is_file() or \
            authority_phases[0] != load_json(authority_phase_path):
        raise RuntimeError("authority resume phase is not joined to prior pipeline final")
    authority_phase = authority_phases[0]
    phase_rows = authority_phase.get("case_rows")
    completed_ids = authority_phase.get("completed_case_ids")
    if authority_phase.get("formal_t2_accepted") is not False or \
            authority_phase.get("case_count_expected") != len(expected_cases) or \
            not isinstance(phase_rows, list) or \
            not isinstance(completed_ids, list) or \
            len(completed_ids) != len(set(completed_ids)) or \
            any(case_id not in expected_cases for case_id in completed_ids):
        raise RuntimeError("authority resume case inventory is malformed")
    phase_row_ids = [row.get("case_id") for row in phase_rows
                     if isinstance(row, dict)]
    phase_positions = [expected_cases.index(case_id) for case_id in phase_row_ids
                       if case_id in expected_cases]
    if len(phase_row_ids) != len(phase_rows) or \
            len(phase_row_ids) != len(set(phase_row_ids)) or \
            len(phase_positions) != len(phase_row_ids) or \
            phase_positions != sorted(phase_positions):
        raise RuntimeError("authority resume case rows are duplicated or reordered")
    complete_statuses = {"completed_natural_exit_zero", "completed_reused"}
    row_completed_ids = [row["case_id"] for row in phase_rows
                         if row.get("status") in complete_statuses]
    if row_completed_ids != completed_ids:
        raise RuntimeError("authority resume completed-case list differs from rows")
    case_roots: dict[str, Path] = {}
    for case_id in expected_cases:
        old_case = resume_root / "actual_formal_authority" / "cases" / case_id
        if old_case.is_symlink() or not old_case.resolve().is_relative_to(resume_root):
            raise RuntimeError(f"authority resume case escapes prior run root: {case_id}")
        old_phase_path = old_case / "phase.json"
        matching_rows = [row for row in phase_rows
                         if row.get("case_id") == case_id]
        if old_phase_path.is_file():
            old_phase_receipt = file_receipt(old_phase_path)
            if len(matching_rows) == 1 and \
                    matching_rows[0].get("status") in complete_statuses and \
                    matching_rows[0].get("phase") == old_phase_receipt and \
                    case_id in completed_ids:
                case_roots[case_id] = old_case
        elif case_id in completed_ids:
            raise RuntimeError(f"completed authority case phase is missing: {case_id}")
    return authority_phase, case_roots


def run_authority_case_phase(
        *, julia_common: list[str], authorities: list[str],
        context_path: Path, context_sha256: str,
        authorization_path: Path, authorization_sha256: str,
        coverage_map_path: Path, coverage_map_sha256: str,
        coverage: dict[str, Any], driver_sha256: str,
        authority_dir: Path, environment: dict[str, str],
        working_set_limit_bytes: int, authority_phase_timeout: float,
        authority_case_timeout: float, resume_from: Path | None,
        current_protocol_path: Path, current_protocol_sha256: str,
        current_inputs: dict[str, Any],
        repository_head: str) -> dict[str, Any]:
    if authority_phase_timeout != AUTHORITY_PHASE_TIMEOUT_SECONDS or \
            authority_case_timeout != AUTHORITY_CASE_TIMEOUT_SECONDS or \
            working_set_limit_bytes != AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise RuntimeError("authority case execution limits differ from frozen contract")
    authority_dir.mkdir(parents=True, exist_ok=False)
    cases_root = authority_dir / "cases"
    cases_root.mkdir()
    artifacts = authority_dir / "artifacts"
    artifacts.mkdir()
    started_utc = utc()
    started = time.monotonic()
    case_rows: list[dict[str, Any]] = []
    case_results: dict[str, dict[str, Any]] = {}
    stop_reason = "natural_exit"
    exit_code = 0
    phase_error: str | None = None
    hit_plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    expected_cases = hit_plan["case_order"]
    if expected_cases != AUTHORITY_CASE_ORDER or len(expected_cases) != 9:
        raise RuntimeError("authority case order/coverage contract mismatch")
    resume_cases: dict[str, Path] = {}
    resume_authority_phase: dict[str, Any] | None = None
    if resume_from is not None:
        resume_authority_phase, resume_cases = verify_authority_resume_ancestry(
            resume_from, authority_dir, current_protocol_path,
            current_protocol_sha256, current_inputs, repository_head,
            expected_cases)
    all_completed = True
    child_phase_receipts: list[dict[str, Any]] = []
    for case_id in expected_cases:
        case_dir = cases_root / case_id
        command = build_actual_formal_shard_command(
            julia_common, f"authority-case:{case_id}", authorities,
            context_path, context_sha256, authorization_path,
            authorization_sha256, case_dir / "artifacts", coverage_map_path,
            coverage_map_sha256)
        source_case_dir = resume_cases.get(case_id)
        if source_case_dir is not None:
            try:
                old_artifacts = source_case_dir / "artifacts"
                old_command = build_actual_formal_shard_command(
                    julia_common, f"authority-case:{case_id}", authorities,
                    context_path, context_sha256, authorization_path,
                    authorization_sha256, old_artifacts, coverage_map_path,
                    coverage_map_sha256)
                summary, source_hits = verify_authority_case_receipt(
                    case_id, source_case_dir, old_command, coverage,
                    coverage_map_sha256=coverage_map_sha256,
                    driver_sha256=driver_sha256,
                    context_sha256=context_sha256,
                    authorization_sha256=authorization_sha256,
                    authority_path_hash_pairs=authorities)
                prior_rows = (resume_authority_phase or {}).get("case_rows", [])
                ancestry_rows = [row for row in prior_rows
                    if isinstance(row, dict) and row.get("case_id") == case_id and
                    row.get("status") in ("completed_natural_exit_zero",
                                           "completed_reused")]
                child_receipt = file_receipt(source_case_dir / "phase.json")
                if len(ancestry_rows) != 1 or \
                        ancestry_rows[0].get("phase") != child_receipt or \
                        source_case_dir.is_symlink() or \
                source_case_dir.resolve().is_relative_to(resume_from.resolve()) is False:
                    raise RuntimeError(f"authority case is not ancestry-pinned for replay: {case_id}")
                case_results[case_id] = {
                    "case_dir": source_case_dir,
                    "summary": summary,
                    "hits": source_hits,
                    "reused_from": str(source_case_dir),
                }
                phase_receipt = child_receipt
                child_phase_receipts.append({"case_id": case_id,
                    "phase": phase_receipt, "reused": True})
                case_rows.append({"case_id": case_id, "status": "completed_reused",
                    "reused_from": str(source_case_dir), "phase": phase_receipt})
                continue
            except (OSError, RuntimeError, ValueError, KeyError, TypeError):
                # A missing, interrupted, or mismatched prior case is never reused.
                pass
        remaining = authority_phase_timeout - (time.monotonic() - started)
        if remaining <= 0:
            all_completed = False
            stop_reason = "phase_wall_timeout"
            exit_code = 15
            phase_error = "authority total case budget exhausted before this case"
            case_rows.append({"case_id": case_id, "status": "not_run_total_budget_exhausted"})
            break
        case_dir.mkdir()
        case_artifacts = case_dir / "artifacts"
        case_artifacts.mkdir()
        case_timeout = min(authority_case_timeout, remaining)
        phase = run_phase(
            f"actual_formal_authority_case_{case_id}", command, case_dir,
            timeout_seconds=case_timeout,
            working_set_limit_bytes=working_set_limit_bytes,
            environment=environment, precreated=True)
        phase_receipt = file_receipt(case_dir / "phase.json")
        child_phase_receipts.append({"case_id": case_id,
            "phase": phase_receipt, "reused": False})
        if phase.get("stop_reason") != "natural_exit" or phase.get("exit_code") != 0:
            all_completed = False
            if phase.get("stop_reason") != "natural_exit":
                stop_reason = str(phase.get("stop_reason"))
                exit_code = phase.get("exit_code", 15)
            else:
                stop_reason = "authority_case_natural_exit_nonzero"
                exit_code = phase.get("exit_code", 1)
            phase_error = f"{case_id} child stop={phase.get('stop_reason')} exit={phase.get('exit_code')}"
            case_rows.append({"case_id": case_id, "status": "partial_child", "phase": phase_receipt})
            break
        try:
            summary, source_hits = verify_authority_case_receipt(
                case_id, case_dir, command, coverage,
                coverage_map_sha256=coverage_map_sha256,
                driver_sha256=driver_sha256,
                context_sha256=context_sha256,
                authorization_sha256=authorization_sha256,
                authority_path_hash_pairs=authorities)
        except (OSError, RuntimeError, ValueError, KeyError, TypeError) as error:
            all_completed = False
            stop_reason = "authority_case_receipt_invalid"
            exit_code = 1
            phase_error = f"{case_id} receipt validation failed: {error}"
            case_rows.append({"case_id": case_id, "status": "invalid_receipt",
                "phase": phase_receipt, "error": str(error)})
            break
        case_results[case_id] = {"case_dir": case_dir,
            "summary": summary, "hits": source_hits, "reused_from": None}
        case_rows.append({"case_id": case_id, "status": "completed_natural_exit_zero",
            "phase": phase_receipt})
        if time.monotonic() - started > authority_phase_timeout:
            all_completed = False
            stop_reason = "phase_wall_timeout"
            exit_code = 15
            phase_error = "authority total case budget exceeded during receipt validation"
            break
    if len(case_results) != len(expected_cases):
        all_completed = False
    if all_completed and time.monotonic() - started > authority_phase_timeout:
        all_completed = False
        stop_reason = "phase_wall_timeout"
        exit_code = 15
        phase_error = "authority total case budget exceeded before aggregate join"
    # Only measured per-case rows enter this progress projection. Raw child receipts
    # are preserved under each case directory, including partial timeout progress.
    progress_header = {
        "schema": "vnext-t2-authority-case-progress-aggregate-r1",
        "event": "header", "phase": "actual_formal_authority",
        "driver_source_sha256": driver_sha256,
        "coverage_map_sha256": coverage_map_sha256,
        "expected_case_ids": expected_cases,
        "completed_case_ids": [case_id for case_id in expected_cases
                                if case_id in case_results],
        "status": "actual_case_progress_only" if not all_completed else
                  "all_case_progress_complete_global_gate_pending",
        "actual_hits_are_measured_from_child_test_records": True,
        "formal_t2_accepted": False,
    }
    progress_rows: list[dict[str, Any]] = [progress_header]
    partial_progress_sources: list[dict[str, Any]] = []
    for case_id in expected_cases:
        result = case_results.get(case_id)
        source_dir = result["case_dir"] if result else cases_root / case_id
        source_progress = source_dir / "artifacts" / "case_progress.jsonl"
        if not source_progress.is_file():
            continue
        child_rows, prefix = load_jsonl_complete_prefix(source_progress)
        partial_progress_sources.append({
            "case_id": case_id, "receipt": file_receipt(source_progress),
            "complete_prefix": prefix,
            "formal_t2_accepted": False,
        })
        if not child_rows or child_rows[0].get("event") != "header" or \
                child_rows[0].get("selected_case_id") != case_id or \
                child_rows[0].get("coverage_map_sha256") != coverage_map_sha256 or \
                child_rows[0].get("source_sha256") != driver_sha256:
            continue
        progress_rows.extend(row for row in child_rows[1:])
    aggregate_progress_path = artifacts / "case_progress.jsonl"
    write_jsonl_new(aggregate_progress_path, progress_rows)
    aggregate_progress_receipt = file_receipt(aggregate_progress_path)
    if all_completed:
        merged = {site_id: 0 for site_id in _authority_source_ids(coverage)}
        for case_id in expected_cases:
            for site_id, count in case_results[case_id]["hits"].items():
                merged[site_id] += count
        expected_full = hit_plan["expected_phase_site_hits"]
        if merged != expected_full or sum(merged.values()) != 118 or \
                sum(count > 0 for count in merged.values()) != 75:
            all_completed = False
            stop_reason = "authority_case_aggregate_hit_mismatch"
            exit_code = 1
            phase_error = "measured 9-case aggregate differs from 75 sites/118 hits"
    if all_completed:
        case_summaries = [case_results[case_id]["summary"] for case_id in expected_cases]
        base = case_summaries[0]
        observations: list[dict[str, Any]] = []
        transport_values: list[dict[str, Any]] = []
        for case_id in expected_cases:
            case_artifacts = case_results[case_id]["case_dir"] / "artifacts"
            observations.extend(load_jsonl(case_artifacts / "observations.jsonl"))
            transport_values.append(load_json(
                case_artifacts / "context_transport_observation.json"))
        if [row.get("case_id") for row in observations] != expected_cases or \
                any(value != transport_values[0] for value in transport_values[1:]):
            all_completed = False
            stop_reason = "authority_case_aggregate_observation_mismatch"
            exit_code = 1
            phase_error = "case observation/context transport aggregate mismatch"
    if all_completed:
        observations_path = artifacts / "observations.jsonl"
        write_jsonl_new(observations_path, observations)
        transport_path = artifacts / "context_transport_observation.json"
        with transport_path.open("xb") as stream:
            stream.write((cases_root / expected_cases[0] / "artifacts" /
                          "context_transport_observation.json").read_bytes())
            stream.flush()
            os.fsync(stream.fileno())
        combined_summary = dict(base)
        combined_summary.update({
            "schema": "vnext-t2-independent-actual-negative-shard-summary-r5",
            "status": "pass", "shard": "authority",
            "observed_case_ids": expected_cases,
            "observed_case_count": len(expected_cases),
            "authority_case_completion_count_observed": len(expected_cases),
            "authority_case_source_phase_site_count_static_plan": 175,
            "authority_case_nonzero_site_count_static_plan": 75,
            "authority_case_expected_hit_count_static_plan": 118,
            "assertion_site_hit_count_observed": sum(merged.values()),
            "assertion_site_hit_counts": dict(sorted(merged.items())),
            "unmapped_assertion_sources": [],
            "authority_case_progress_path": "case_progress.jsonl",
            "authority_case_progress_sha256": aggregate_progress_receipt["sha256"],
            "observation_file_sha256": file_receipt(observations_path)["sha256"],
            "context_transport_observation_sha256": file_receipt(transport_path)["sha256"],
            "formal_t2_accepted": False,
        })
        write_json_new(artifacts / "summary.json", combined_summary)
        write_json_new(artifacts / "authority_case_aggregate.json", {
            "schema": "vnext-t2-authority-case-aggregate-r1",
            "status": "all_nine_natural_exit_zero_actual_hit_receipts",
            "case_order": expected_cases,
            "case_receipts": child_phase_receipts,
            "assertion_site_hit_counts_observed": dict(sorted(merged.items())),
            "assertion_site_count_observed": 175,
            "nonzero_site_count_observed": sum(count > 0 for count in merged.values()),
            "assertion_site_hit_count_observed": sum(merged.values()),
            "formal_t2_accepted": False,
        })
    else:
        write_json_new(artifacts / "authority_case_partial.json", {
            "schema": "vnext-t2-authority-case-partial-r1",
            "status": "partial_no_aggregate_acceptance",
            "expected_case_order": expected_cases,
            "completed_natural_case_ids": [case_id for case_id in expected_cases
                                            if case_id in case_results],
            "remaining_case_ids": [case_id for case_id in expected_cases
                                   if case_id not in case_results],
            "case_rows": case_rows,
            "phase_error": phase_error,
            "authority_phase_wall_budget_seconds": authority_phase_timeout,
            "authority_case_wall_budget_seconds": authority_case_timeout,
            "working_set_limit_bytes": working_set_limit_bytes,
            "partial_case_progress_receipt": aggregate_progress_receipt,
            "partial_progress_source_receipts": partial_progress_sources,
            "formal_t2_accepted": False,
        })
    elapsed = time.monotonic() - started
    phase = {
        "schema": "vnext-t2-independent-negative-authority-case-phase-r1",
        "name": "actual_formal_authority",
        "command": [row.get("phase") for row in child_phase_receipts],
        "started_utc": started_utc, "ended_utc": utc(), "seconds": elapsed,
        "exit_code": 0 if all_completed else exit_code,
        "stop_reason": "natural_exit" if all_completed else stop_reason,
        "timeout_seconds": authority_phase_timeout,
        "per_case_timeout_seconds": authority_case_timeout,
        "working_set_limit_bytes": working_set_limit_bytes,
        "peak_process_tree_working_set_bytes": max((
            load_json(Path(row["phase"]["path"]))["peak_process_tree_working_set_bytes"]
            for row in child_phase_receipts), default=0),
        "completed_case_ids": [case_id for case_id in expected_cases
                                if case_id in case_results],
        "case_count_expected": 9,
        "case_rows": case_rows,
        "aggregate_progress": aggregate_progress_receipt,
        "summary": file_receipt(artifacts / "summary.json")
                    if (artifacts / "summary.json").is_file() else None,
        "residual_heavy_processes": heavy_processes(),
        "formal_t2_accepted": False,
    }
    write_json_new(authority_dir / "phase.json", phase)
    return phase


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--julia", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--protocol-sha256", required=True)
    parser.add_argument("--positive-evidence", required=True)
    parser.add_argument("--positive-final-sha256", required=True)
    parser.add_argument("--positive-pipeline-final-sha256", required=True)
    parser.add_argument("--evidence-dir", required=True)
    parser.add_argument("--phase-timeout", type=float, required=True)
    parser.add_argument("--authority-phase-timeout", type=float, required=True)
    parser.add_argument("--authority-case-timeout", type=float, required=True)
    parser.add_argument("--resume-authority-from")
    parser.add_argument("--working-set-limit", type=int, required=True)
    args = parser.parse_args()

    project = Path(args.project).resolve()
    if project != ROOT:
        raise ValueError("project must resolve to repository root")
    if args.phase_timeout != 480 or \
            args.authority_phase_timeout != AUTHORITY_PHASE_TIMEOUT_SECONDS or \
            args.authority_case_timeout != AUTHORITY_CASE_TIMEOUT_SECONDS or \
            args.working_set_limit != AUTHORITY_WORKING_SET_LIMIT_BYTES:
        raise ValueError("negative formal phases require 480s/2GiB and authority 2400s/1200s gates")
    protocol_path = Path(args.protocol).resolve()
    protocol_path.relative_to(ROOT)
    positive_root = Path(args.positive_evidence).resolve()
    positive_root.relative_to(ROOT)
    output = Path(args.evidence_dir).resolve()
    output.relative_to(ROOT / "docs/implementation/UP1-04A-VNEXT-T2")
    output.mkdir(parents=True, exist_ok=False)

    protocol = verify_protocol(protocol_path, args.protocol_sha256)
    if protocol.get("driver_path") != ACTUAL_DRIVER.relative_to(ROOT).as_posix() or \
            protocol.get("driver_path") not in protocol.get("inputs", {}):
        raise RuntimeError("negative driver path is not bound by protocol inputs")
    runtime_plan = verify_runtime_plan(protocol)
    coverage = load_json(ROOT / protocol["coverage_map"]["path"])
    coverage_receipt = file_receipt(ROOT / protocol["coverage_map"]["path"])
    if coverage_receipt["sha256"] != protocol["coverage_map"]["sha256"] or \
            protocol["inputs"].get(protocol["coverage_map"]["path"]) != {
                "path": protocol["coverage_map"]["path"],
                "bytes": coverage_receipt["bytes"],
                "sha256": coverage_receipt["sha256"],
            }:
        raise RuntimeError("negative coverage-map input drift")
    runtime_plan = verify_coverage_runtime_plan(protocol, coverage)
    if coverage.get("schema") != \
            "vnext-t2-independent-negative-coverage-map-r6" or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622 or \
            coverage.get("preserved_successor_assertion_site_count") != 191 or \
            coverage.get("preserved_successor_expected_runtime_hit_count") != 530 or \
            runtime_plan.get("expected_unique_case_count") != 60 or \
            runtime_plan.get("expected_runtime_case_hit_count") != 68 or \
            len(runtime_plan.get("actual_formal_summary_case_ids", [])) != 45:
        raise RuntimeError("negative coverage-map schema/preserved coverage mismatch")
    authority_plan = coverage.get("successor_assertion_runtime_hit_plan", {}).get(
        "authority_case_hit_plan")
    authority_source_ids = _authority_source_ids(coverage)
    if not isinstance(authority_plan, dict) or \
            authority_plan.get("schema") != "vnext-t2-authority-case-hit-plan-r1" or \
            authority_plan.get("status") != "static_plan_actual_case_hits_pending" or \
            authority_plan.get("case_order") != AUTHORITY_CASE_ORDER or \
            authority_plan.get("source_site_count") != 175 or \
            authority_plan.get("nonzero_site_count") != 75 or \
            authority_plan.get("expected_hit_count") != 118 or \
            set(authority_plan.get("expected_phase_site_hits", {})) != authority_source_ids or \
            len(authority_plan.get("case_site_hit_counts", {})) != 9:
        raise RuntimeError("authority case-hit plan coverage contract mismatch")
    authority_join = {site_id: 0 for site_id in authority_source_ids}
    for case_id in AUTHORITY_CASE_ORDER:
        case_hits = authority_plan["case_site_hit_counts"].get(case_id)
        if not isinstance(case_hits, dict) or set(case_hits) != authority_source_ids:
            raise RuntimeError(f"authority case static site inventory invalid: {case_id}")
        for site_id, count in case_hits.items():
            if not isinstance(count, int) or count < 0:
                raise RuntimeError(f"authority case static hit is malformed: {case_id}:{site_id}")
            authority_join[site_id] += count
    if authority_join != authority_plan["expected_phase_site_hits"] or \
            sum(authority_join.values()) != 118:
        raise RuntimeError("authority case static plan does not reaggregate to 118")
    coverage_map_sha256 = protocol["coverage_map"]["sha256"]
    positive_input_pin_join = verify_positive_reuse_input_pins(protocol)
    frozen_positive = protocol["positive_evidence"]
    if args.positive_final_sha256.lower() != frozen_positive[
            "formal_serial_replay"]["sha256"] or \
            args.positive_pipeline_final_sha256.lower() != frozen_positive[
                "pipeline_final"]["sha256"]:
        raise RuntimeError("positive CLI hashes differ from frozen protocol")
    verify_frozen_positive_evidence(positive_root, frozen_positive)
    julia_executable = Path(args.julia).resolve()
    if str(julia_executable).lower() != str(Path(
            protocol["julia_executable"]).resolve()).lower():
        raise ValueError("Julia executable differs from frozen protocol")
    head_before = git_head()
    inputs_before = input_receipts(protocol)
    resume_authority_from = (Path(args.resume_authority_from).resolve()
        if args.resume_authority_from else None)
    if resume_authority_from is not None:
        resume_authority_from.relative_to(
            ROOT / "docs/implementation/UP1-04A-VNEXT-T2")
        if resume_authority_from == output:
            raise ValueError("authority resume source must differ from output leaf")
    baseline_heavy = heavy_processes()
    phases: list[dict[str, Any]] = []
    case_receipts: dict[str, Any] = {}
    executed_case_hits: list[str] = []
    assertion_site_hit_summaries: list[dict[str, Any]] = []
    assertion_site_hit_aggregate: dict[str, Any] | None = None
    ast_inventory_assertion_sites = 0
    projection_assertion_sites_completed = 0
    context_transport_assertion_sites_completed = 0
    failure: dict[str, Any] | None = None
    pipeline_pass = False
    write_json_new(output / "pipeline_start.json", {
        "schema": "vnext-t2-independent-negative-pipeline-start-r4",
        "created_utc": utc(), "repository_head": head_before,
        "protocol": file_receipt(protocol_path),
        "protocol_expected_sha256": args.protocol_sha256.lower(),
        "positive_evidence": str(positive_root),
        "positive_final_expected_sha256": args.positive_final_sha256.lower(),
        "positive_pipeline_final_expected_sha256":
            args.positive_pipeline_final_sha256.lower(),
        "positive_r3_runtime_input_pin_join": positive_input_pin_join,
        "inputs_before": inputs_before,
        "phase_timeout_seconds": args.phase_timeout,
        "authority_phase_timeout_seconds": args.authority_phase_timeout,
        "authority_case_timeout_seconds": args.authority_case_timeout,
        "authority_case_order": AUTHORITY_CASE_ORDER,
        "authority_case_resume_from": str(resume_authority_from)
            if resume_authority_from else None,
        "process_tree_working_set_limit_bytes": args.working_set_limit,
        "baseline_heavy_processes": baseline_heavy,
        "runtime_execution_plan_sha256": sha256_bytes(json.dumps(
            runtime_plan, sort_keys=True, separators=(",", ":")).encode()),
        "ast_inventory_plan_sha256": sha256_bytes(json.dumps(
            coverage["ast_inventory_plan"], sort_keys=True,
            separators=(",", ":")).encode()),
        "expected_ast_inventory_assertion_site_count":
            coverage["ast_inventory_plan"]["total_assertion_site_count"],
        "expected_versioned_product_repair_assertion_site_count": 24,
        "expected_preserved_successor_assertion_site_count": 191,
        "expected_preserved_successor_runtime_hit_count_static_plan": 530,
        "expected_context_transport_assertion_site_count_static_plan":
            coverage["context_transport_assertion_site_count"],
        "expected_context_transport_runtime_hit_count_static_plan":
            coverage["context_transport_expected_runtime_hit_count"],
        "expected_successor_assertion_site_count_static_plan":
            coverage["successor_assertion_runtime_hit_plan"][
                "assertion_site_count"],
        "expected_successor_assertion_runtime_hit_count_static_plan":
            coverage["successor_assertion_runtime_hit_plan"][
                "expected_runtime_hit_count"],
        "expected_phase_order": protocol["phase_order"],
        "expected_unique_case_count":
            runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count":
            runtime_plan["expected_runtime_case_hit_count"],
        "julia_threads": 1, "openblas_threads": 1,
        "python_dont_write_bytecode": True,
        "formal_t2_accepted": False,
        "actual_model_attestation": "unavailable",
    })

    try:
        if head_before != EXPECTED_HEAD:
            raise RuntimeError("repository HEAD mismatch")
        if baseline_heavy:
            raise RuntimeError("serialized Julia lane occupied")
        positive = read_positive(
            positive_root, args.positive_final_sha256,
            args.positive_pipeline_final_sha256)
        positive_receipts_consumed = verify_frozen_positive_evidence(
            positive_root, frozen_positive)
        environment = os.environ.copy()
        environment["JULIA_NUM_THREADS"] = "1"
        environment["OPENBLAS_NUM_THREADS"] = "1"
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        julia_common = [str(julia_executable), "--project=" + str(project),
            "--startup-file=no", "--history-file=no", "--threads=1"]

        parse_manifest_path = output / "runtime_parse_manifest.tsv"
        parse_manifest_receipt = write_parse_manifest(
            parse_manifest_path, protocol)
        parse_dir = output / "parse_gate"
        parse_phase = run_phase("parse_gate", julia_common + [
            str(PARSE_GATE), str(parse_manifest_path)], parse_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(parse_phase)
        require_natural(parse_phase, exit_zero=True)
        case_receipts["parse_gate"] = {
            "manifest": parse_manifest_receipt,
            "parsed_count": len(protocol["julia_parse_paths"]),
            "positive_evidence_receipt_count":
                len(positive_receipts_consumed),
        }

        ast_dir = output / "coverage_ast_inventory"
        ast_receipt_path = ast_dir / "ast_inventory.json"
        ast_phase = run_phase("coverage_ast_inventory", julia_common + [
            str(AST_INVENTORY_DRIVER),
            str(ROOT / protocol["coverage_map"]["path"]),
            str(ast_receipt_path)], ast_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(ast_phase)
        require_natural(ast_phase, exit_zero=True)
        ast_receipt = verify_ast_inventory(ast_receipt_path, coverage)
        ast_inventory_assertion_sites = ast_receipt[
            "total_assertion_site_count"]
        case_receipts["coverage_ast_inventory"] = {
            "receipt": file_receipt(ast_receipt_path),
            "source_count": ast_receipt["source_count"],
            "old_assertion_site_count":
                ast_receipt["old_assertion_site_count"],
            "successor_assertion_site_count":
                ast_receipt["successor_assertion_site_count"],
            "projection_assertion_site_count":
                ast_receipt["projection_assertion_site_count"],
            "total_assertion_site_count": ast_inventory_assertion_sites,
        }

        projection_dir = output / "projection24_cross_run_validation"
        projection_reuse_receipt_path = projection_dir / "reuse_receipt.json"
        projection_phase = run_phase(
            "projection24_cross_run_validation",
            [sys.executable, "-B", str(PROJECTION_REUSE_VALIDATOR),
             str(protocol_path), str(projection_reuse_receipt_path)],
            projection_dir, timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(projection_phase)
        require_natural(projection_phase, exit_zero=True)
        projection_reuse = load_json(projection_reuse_receipt_path)
        if projection_reuse.get("status") != "pass" or \
                projection_reuse.get("natural_exit_zero") is not True or \
                projection_reuse.get("post_assertion_pass_marker") is not True or \
                projection_reuse.get("assertion_sites_completed") != 24:
            raise RuntimeError("projection24 cross-run validation failed")
        projection_assertion_sites_completed = 24
        case_receipts["projection24_cross_run_validation"] = {
            "receipt": file_receipt(projection_reuse_receipt_path),
            "source_phase_files": projection_reuse["phase_files"],
            "dependency_count": projection_reuse["dependency_count"],
            "assertion_sites_completed": 24,
            "completion_evidence":
                "exact_stage_closure_plus_natural_exit_zero_and_pass_marker",
            "formal_qualification": False,
        }

        actual_common = [str(ACTUAL_DRIVER)]
        actual_authorities = [str(positive["manifest_path"]),
            positive["manifest_sha256"], str(positive["verification_path"]),
            positive["verification_sha256"], str(positive["candidate_path"]),
            positive["candidate_sha256"], str(positive["package_path"]),
            positive["package_sha256"]]
        baseline_dir = output / "actual_formal_baseline"
        baseline_artifacts = baseline_dir / "artifacts"
        context_path = baseline_artifacts / "baseline_context.jls"
        authorization_path = output / "actual_formal_baseline_authorization.json"
        baseline_phase = run_phase("actual_formal_baseline",
            julia_common + actual_common + ["baseline", *actual_authorities,
                str(context_path), "create", str(authorization_path), "create",
                str(baseline_artifacts),
                str(ROOT / protocol["coverage_map"]["path"]),
                coverage_map_sha256], baseline_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(baseline_phase)
        require_natural(baseline_phase, exit_zero=True)
        baseline_summary_path = baseline_artifacts / "summary.json"
        baseline_summary = load_json(baseline_summary_path)
        if baseline_summary.get("status") != "pass" or \
                baseline_summary.get("observed_case_ids") != \
                runtime_plan["actual_formal_phase_case_ids"][
                    "actual_formal_baseline"] or \
                baseline_summary.get("source_revalidation_status") != \
                "source_ready" or \
                baseline_summary.get("producer_package_unchanged") is not True or \
                baseline_summary.get("candidate_receipt_unchanged") is not True or \
                baseline_summary.get("package_wire_unchanged") is not True:
            raise RuntimeError("actual formal baseline summary failed")
        assertion_site_hit_summaries.append(baseline_summary)
        baseline_site_hits = verify_assertion_site_hit_summary(
            baseline_summary, coverage, "actual_formal_baseline",
            coverage_map_sha256=coverage_map_sha256)
        context_receipt = file_receipt(context_path)
        if baseline_summary.get("context_receipt", {}).get("bytes") != \
                context_receipt["bytes"] or \
                baseline_summary.get("context_receipt", {}).get("sha256") != \
                context_receipt["sha256"]:
            raise RuntimeError("actual formal context receipt mismatch")
        authorization = write_baseline_authorization(
            authorization_path, baseline_dir, baseline_phase,
            baseline_summary, context_path)
        authorization_receipt = file_receipt(authorization_path)
        baseline_observations_path = baseline_artifacts / "observations.jsonl"
        baseline_observations = load_jsonl(baseline_observations_path)
        baseline_observation_ids = [row.get("case_id")
                                    for row in baseline_observations]
        if baseline_observation_ids != runtime_plan[
                "actual_formal_phase_observation_ids"][
                    "actual_formal_baseline"]:
            raise RuntimeError("actual baseline observation inventory mismatch")
        aggregated_actual_case_ids = list(
            baseline_summary["observed_case_ids"])
        aggregated_actual_observation_ids = list(baseline_observation_ids)
        executed_case_hits.extend(baseline_summary["observed_case_ids"])
        case_receipts["actual_formal_baseline"] = {
            "phase": file_receipt(baseline_dir / "phase.json"),
            "summary": file_receipt(baseline_summary_path),
            "observations": file_receipt(baseline_observations_path),
            "stage_trace": file_receipt(
                baseline_artifacts / "stage_trace.tsv"),
            "context": context_receipt,
            "authorization": authorization_receipt,
            "authorization_body": authorization,
            "case_ids": baseline_summary["observed_case_ids"],
            "observation_ids": baseline_observation_ids,
            "five_consumer_execution_count": 1,
            "assertion_site_hit_counts": baseline_site_hits,
            "assertion_site_hit_count_observed": sum(
                baseline_site_hits.values()),
        }

        actual_shards = (
            ("actual_formal_preflight", "preflight"),
            ("actual_formal_authority", "authority"),
            ("actual_formal_fault_n10", "fault_n10"),
            ("actual_formal_t1_handoff", "t1_handoff"),
        )
        for phase_name, mode in actual_shards:
            shard_dir = output / phase_name
            shard_artifacts = shard_dir / "artifacts"
            if mode == "authority":
                shard_phase = run_authority_case_phase(
                    julia_common=julia_common, authorities=actual_authorities,
                    context_path=context_path,
                    context_sha256=context_receipt["sha256"],
                    authorization_path=authorization_path,
                    authorization_sha256=authorization_receipt["sha256"],
                    coverage_map_path=ROOT / protocol["coverage_map"]["path"],
                    coverage_map_sha256=coverage_map_sha256,
                    coverage=coverage,
                    driver_sha256=protocol["inputs"][
                        protocol["driver_path"]]["sha256"],
                    authority_dir=shard_dir, environment=environment,
                    working_set_limit_bytes=args.working_set_limit,
                    authority_phase_timeout=args.authority_phase_timeout,
                    authority_case_timeout=args.authority_case_timeout,
                    resume_from=resume_authority_from,
                    current_protocol_path=protocol_path,
                    current_protocol_sha256=args.protocol_sha256.lower(),
                    current_inputs=inputs_before,
                    repository_head=head_before)
            else:
                shard_command = build_actual_formal_shard_command(
                    julia_common, mode, actual_authorities,
                    context_path, context_receipt["sha256"],
                    authorization_path, authorization_receipt["sha256"],
                    shard_artifacts, ROOT / protocol["coverage_map"]["path"],
                    coverage_map_sha256)
                shard_phase = run_phase(phase_name,
                    shard_command, shard_dir,
                    timeout_seconds=args.phase_timeout,
                    working_set_limit_bytes=args.working_set_limit,
                    environment=environment)
            phases.append(shard_phase)
            require_natural(shard_phase, exit_zero=True)
            shard_summary_path = shard_artifacts / "summary.json"
            shard_summary = load_json(shard_summary_path)
            expected_ids = runtime_plan["actual_formal_phase_case_ids"][
                phase_name]
            if shard_summary.get("status") != "pass" or \
                    shard_summary.get("shard") != mode or \
                    shard_summary.get("observed_case_ids") != expected_ids or \
                    shard_summary.get("producer_package_unchanged") is not True or \
                    shard_summary.get("candidate_receipt_unchanged") is not True or \
                    shard_summary.get("context_unchanged") is not True or \
                    shard_summary.get("source_revalidation_status") != \
                    "source_ready" or \
                    shard_summary.get("rebuilt_input_full_content_join") is not True or \
                shard_summary.get("package_wire_unchanged") is not True or \
                shard_summary.get("prior_ledger_unchanged") is not True:
                raise RuntimeError(f"actual formal shard summary failed: {mode}")
            assertion_site_hit_summaries.append(shard_summary)
            shard_site_hits = verify_assertion_site_hit_summary(
                shard_summary, coverage, phase_name,
                coverage_map_sha256=coverage_map_sha256)
            transport_path = shard_artifacts / \
                "context_transport_observation.json"
            transport_observation = verify_context_transport_observation(
                transport_path, mode)
            observations_path = shard_artifacts / "observations.jsonl"
            observations = load_jsonl(observations_path)
            observation_ids = [row.get("case_id") for row in observations]
            expected_observations = runtime_plan[
                "actual_formal_phase_observation_ids"][phase_name]
            if observation_ids != expected_observations:
                raise RuntimeError(
                    f"actual formal shard observation inventory mismatch: {mode}")
            required_observation_fields = {
                "value_type", "status", "resolution", "first_reason", "errors",
                "package_fingerprint_before", "package_fingerprint_after",
                "package_artifact_before", "package_artifact_after",
                "prior_ledger_fingerprint_before",
                "prior_ledger_fingerprint_after", "attempted_counts",
                "committed_counts",
            }
            for row in observations:
                if row.get("schema") != \
                        "vnext-t2-independent-negative-observation-r1" or \
                        not required_observation_fields.issubset(row):
                    raise RuntimeError(
                        f"actual observation schema mismatch: {row.get('case_id')}")
            aggregated_actual_case_ids.extend(shard_summary["observed_case_ids"])
            aggregated_actual_observation_ids.extend(observation_ids)
            executed_case_hits.extend(shard_summary["observed_case_ids"])
            case_receipts[phase_name] = {
                "phase": file_receipt(shard_dir / "phase.json"),
                "summary": file_receipt(shard_summary_path),
                "authority_case_aggregate": file_receipt(
                    shard_artifacts / "authority_case_aggregate.json")
                    if mode == "authority" else None,
                "observations": file_receipt(observations_path),
                "context_transport_observation": file_receipt(transport_path),
                "context_transport_values": transport_observation,
                "stage_trace": file_receipt(
                    shard_artifacts / "stage_trace.tsv"),
                "case_ids": shard_summary["observed_case_ids"],
                "observation_ids": observation_ids,
                "baseline_consumer_execution_count": 0,
                "assertion_site_hit_counts": shard_site_hits,
                "assertion_site_hit_count_observed": sum(
                    shard_site_hits.values()),
                "protected_prior_ledger_source":
                    "actual_formal_baseline natural-zero five-consumer context",
            }

        expected_actual_case_ids = runtime_plan["actual_formal_summary_case_ids"]
        if aggregated_actual_case_ids != expected_actual_case_ids:
            raise RuntimeError("actual formal sharded case inventory mismatch")
        if aggregated_actual_observation_ids != runtime_plan[
                "actual_formal_observation_ids"]:
            raise RuntimeError("actual sharded observe-first inventory mismatch")
        case_receipts["actual_formal_shards"] = {
            "phase_names": [name for name, _ in actual_shards],
            "case_ids": aggregated_actual_case_ids,
            "observation_ids": aggregated_actual_observation_ids,
            "unique_baseline_five_consumer_execution_count": 1,
            "context_transport_validation_execution_count": 4,
        }

        for phase_name, mode, expected_case in (
                ("supplementary_edited_operation", "edited_operation",
                 "SUP_EDITED_OPERATION_DEFERRAL"),
                ("supplementary_child_coupling", "child_coupling",
                 "SUP_CHILD_COUPLING_CONTRADICTION")):
            supplementary_dir = output / phase_name
            supplementary_artifacts = supplementary_dir / "artifacts"
            supplementary = run_phase(phase_name,
                julia_common + [str(SUPPLEMENTARY_DRIVER), mode,
                                str(supplementary_artifacts),
                                str(ROOT / protocol["coverage_map"]["path"]),
                                coverage_map_sha256],
                supplementary_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(supplementary)
            require_natural(supplementary, exit_zero=True)
            supplementary_summary = load_json(
                supplementary_artifacts / "summary.json")
            expected_summary_ids = runtime_plan[
                "supplementary_summary_case_ids"][mode]
            if supplementary_summary.get("status") != "pass" or \
                    supplementary_summary.get("formal_qualification") is not False or \
                    supplementary_summary.get("mode") != mode or \
                    supplementary_summary.get("observed_case_ids") != \
                    expected_summary_ids:
                raise RuntimeError(
                    f"supplementary contract summary failed: {phase_name}")
            assertion_site_hit_summaries.append(supplementary_summary)
            supplementary_site_hits = verify_assertion_site_hit_summary(
                supplementary_summary, coverage, phase_name,
                coverage_map_sha256=coverage_map_sha256)
            supplementary_observations = load_jsonl(
                supplementary_artifacts / "observations.jsonl")
            if len(supplementary_observations) != 1 or \
                    supplementary_observations[0].get("case_id") != expected_case or \
                    supplementary_observations[0].get("formal_qualification") \
                    is not False:
                raise RuntimeError(
                    f"supplementary observation mismatch: {phase_name}")
            executed_case_hits.extend(expected_summary_ids)
            case_receipts[phase_name] = {
                "summary": file_receipt(
                    supplementary_artifacts / "summary.json"),
                "observations": file_receipt(
                    supplementary_artifacts / "observations.jsonl"),
                "case_ids": expected_summary_ids,
                "assertion_site_hit_counts": supplementary_site_hits,
                "assertion_site_hit_count_observed": sum(
                    supplementary_site_hits.values()),
            }

        attacks = output / "attack_inputs"
        attacks.mkdir()
        original_bytes = positive["package_path"].read_bytes()
        truncated = original_bytes[:max(1, len(original_bytes) // 2)]
        truncated_path = attacks / "candidate_package_truncated.jls"
        truncated_path.write_bytes(truncated)
        zero_path = attacks / "candidate_package_zero.jls"
        zero_path.write_bytes(b"")
        wrong_raw_hash = sha256_bytes(b"wrong producer package hash")
        artifact_specs = (
            ("artifact_hash_precondition", "raw_hash_mismatch",
             positive["package_path"], wrong_raw_hash),
            ("artifact_recomputed_corrupt", "recomputed_corrupt",
             truncated_path, sha256_bytes(truncated)),
            ("artifact_zero_malformed", "zero_malformed",
             zero_path, sha256_bytes(b"")),
        )
        for name, mode, attacked_path, expected_hash in artifact_specs:
            phase_dir = output / name
            receipt_path = phase_dir / "artifact_receipt.json"
            phase = run_phase(name, julia_common + [str(ARTIFACT_DRIVER),
                mode, str(positive["package_path"]), str(attacked_path),
                expected_hash, str(receipt_path)], phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=True)
            receipt = verify_artifact_helper(
                receipt_path, mode, attacked_path, expected_hash)
            case_id = runtime_plan["helper_phase_case_ids"][name]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "receipt": file_receipt(receipt_path),
                "case_id": case_id,
                "actual_rejection": receipt["actual_rejection"],
                "consumer_attempted_counts":
                    receipt["consumer_attempted_counts"],
                "committed_counts": receipt["committed_counts"],
            }

        attack_fixture_dir = output / "artifact_attack_fixture_generation"
        attack_fixture_artifacts = attack_fixture_dir / "artifacts"
        attack_fixture = run_phase("artifact_attack_fixture_generation",
            julia_common + [str(ATTACK_FIXTURE_DRIVER),
                            str(attack_fixture_artifacts)],
            attack_fixture_dir,
            timeout_seconds=args.phase_timeout,
            working_set_limit_bytes=args.working_set_limit,
            environment=environment)
        phases.append(attack_fixture)
        require_natural(attack_fixture, exit_zero=True)
        attack_receipt_path = attack_fixture_artifacts / \
            "attack_fixture_receipt.json"
        attack_receipt = load_json(attack_receipt_path)
        if attack_receipt.get("schema") != \
                "vnext-t2-independent-artifact-attack-fixtures-r1" or \
                attack_receipt.get("formal_t2_accepted") is not False:
            raise RuntimeError("artifact attack fixture receipt invalid")
        wrong_type_path = attack_fixture_artifacts / \
            "candidate_package_wrong_type.jls"
        foreign_package_path = attack_fixture_artifacts / \
            "candidate_package_foreign_valid.jls"
        for label, path, row in (
                ("wrong_type", wrong_type_path,
                 attack_receipt.get("wrong_type")),
                ("foreign_package", foreign_package_path,
                 attack_receipt.get("foreign_package"))):
            actual_receipt = file_receipt(path)
            if not isinstance(row, dict) or \
                    row.get("bytes") != actual_receipt["bytes"] or \
                    row.get("sha256") != actual_receipt["sha256"]:
                raise RuntimeError(f"artifact attack fixture drift: {label}")
        case_receipts["artifact_attack_fixture_generation"] = {
            "phase": file_receipt(attack_fixture_dir / "phase.json"),
            "receipt": file_receipt(attack_receipt_path),
            "foreign_observation": file_receipt(
                attack_fixture_artifacts / "foreign_package_observation.json"),
        }

        # Exercise the implementation-owned formal driver with the same damaged
        # producer artifacts.  These are distinct from the helper/deserializer
        # receipts above and must fail before candidate authority or consumers.
        formal_artifact_specs = (
            ("formal_driver_artifact_raw_hash_precondition", truncated_path,
             positive["package_sha256"], "producer_artifact_hash_precondition",
             "raw_sha256_mismatch"),
            ("formal_driver_artifact_deserialize_precondition", truncated_path,
             sha256_bytes(truncated), "producer_artifact_deserialize_precondition",
             "deserialize_error"),
            ("formal_driver_artifact_zero_precondition", zero_path,
             sha256_bytes(b""), "producer_artifact_deserialize_precondition",
             "deserialize_error"),
            ("formal_driver_artifact_wrong_type_precondition", wrong_type_path,
             file_receipt(wrong_type_path)["sha256"],
             "producer_artifact_deserialize_precondition", "type_invalid"),
            ("formal_driver_artifact_foreign_package_precondition",
             foreign_package_path, file_receipt(foreign_package_path)["sha256"],
             "producer_artifact_deserialize_precondition",
             "expected_admission_mismatch"),
        )
        for name, attacked_path, expected_hash, expected_stage, \
                expected_failure in \
                formal_artifact_specs:
            phase_dir = output / name
            artifacts = phase_dir / "artifacts"
            command = candidate_command(julia_common, positive, artifacts,
                positive["candidate_sha256"],
                positive["stable_projection_hash"],
                positive["result_reload_identity_hash"],
                package_path=attacked_path, package_sha256=expected_hash)
            phase = run_phase(name, command, phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            receipt = verify_uncommitted(artifacts, expected_stage,
                zero_call=True, precondition_failure=expected_failure)
            if file_receipt(positive["package_path"])["sha256"] != \
                    positive["package_sha256"]:
                raise RuntimeError("original producer package changed")
            case_id = runtime_plan["formal_artifact_phase_case_ids"][name]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "phase": file_receipt(phase_dir / "phase.json"),
                "receipt": file_receipt(
                    artifacts / "replay_uncommitted_attempt.json"),
                "stage": receipt["stage"],
                "precondition_failure": receipt["precondition_failure"],
                "attempted_counts": receipt["attempted_counts"],
                "committed_counts": receipt["committed_counts"],
                "attacked_artifact": file_receipt(attacked_path),
                "original_artifact": file_receipt(positive["package_path"]),
                "runtime_consumer_count_evidence": "implementation receipt r2",
                "case_id": case_id,
            }

        # The versioned implementation driver must refuse any occupied target
        # before reading formal authorities or constructing a T1/T2 chain.
        preexisting_cases: list[tuple[str, dict[str, bytes]]] = []
        for owned in OWNED_CANDIDATE_ARTIFACTS:
            preexisting_cases.append((
                "preexisting_" + owned.replace(".", "_"),
                {owned: ("sentinel:" + owned).encode()}))
        success_bytes = {
            "candidate_package.jls": positive["package_path"].read_bytes(),
            "candidate_t1_admission_receipt.json":
                positive["candidate_path"].read_bytes(),
            "t2_result.jls":
                (positive["producer"] / "t2_result.jls").read_bytes(),
            "run_receipt.json":
                positive["producer_receipt_path"].read_bytes(),
        }
        preexisting_cases.append(("preexisting_prior_success_set", success_bytes))
        preexisting_cases.append(("preexisting_prior_uncommitted", {
            "replay_uncommitted_attempt.json": b"prior-uncommitted-sentinel\n"}))
        wrong_candidate = sha256_bytes(b"wrong candidate receipt identity")
        for name, seeded in preexisting_cases:
            phase_dir = output / name
            artifacts = phase_dir / "artifacts"
            artifacts.mkdir(parents=True)
            before = {}
            for filename, data in seeded.items():
                path = artifacts / filename
                path.write_bytes(data)
                before[filename] = file_receipt(path)
            phase = run_phase(name, candidate_command(julia_common, positive,
                artifacts, wrong_candidate, positive["stable_projection_hash"],
                positive["result_reload_identity_hash"]), phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment, precreated=True)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            expected_first_owned = next(
                owned for owned in OWNED_CANDIDATE_ARTIFACTS
                if owned in seeded)
            observed_first_error = require_output_guard_first_error(
                phase_dir / "stderr.raw", expected_first_owned)
            after = {filename: file_receipt(artifacts / filename)
                     for filename in seeded}
            if before != after:
                raise RuntimeError(f"preexisting bytes changed: {name}")
            if set(path.name for path in artifacts.iterdir()) != set(seeded):
                raise RuntimeError(f"preexisting guard mixed artifacts: {name}")
            case_id = runtime_plan[
                "preexisting_owned_target_semantic_case"]
            executed_case_hits.append(case_id)
            case_receipts[name] = {
                "before": before, "after": after,
                "phase": file_receipt(phase_dir / "phase.json"),
                "case_id": case_id,
                "first_error": observed_first_error,
            }

        symlink_case: dict[str, Any]
        symlink_phase_dir = output / "preexisting_symlink_owned_target"
        symlink_artifacts = symlink_phase_dir / "artifacts"
        symlink_artifacts.mkdir(parents=True)
        external = output / "symlink_external_sentinel.bin"
        external.write_bytes(b"external-sentinel-never-overwrite\n")
        external_before = file_receipt(external)
        link = symlink_artifacts / "candidate_package.jls"
        try:
            os.symlink(external, link)
        except OSError as error:
            symlink_case = {"status": "skip_symlink_unavailable",
                            "error_type": type(error).__name__,
                            "error": str(error),
                            "external_before": external_before,
                            "external_after": file_receipt(external)}
            case_receipts["preexisting_symlink_owned_target"] = symlink_case
            raise RuntimeError(
                "preexisting symlink guard not executed: " +
                type(error).__name__ + ": " + str(error))
        else:
            phase = run_phase("preexisting_symlink_owned_target",
                candidate_command(julia_common, positive, symlink_artifacts,
                    wrong_candidate, positive["stable_projection_hash"],
                    positive["result_reload_identity_hash"]),
                symlink_phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment, precreated=True)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            symlink_first_error = require_output_guard_first_error(
                symlink_phase_dir / "stderr.raw", "candidate_package.jls")
            if file_receipt(external) != external_before:
                raise RuntimeError("symlink guard changed external sentinel")
            if not link.is_symlink() or link.resolve() != external.resolve():
                raise RuntimeError("symlink guard changed the owned link")
            if {path.name for path in symlink_artifacts.iterdir()} != \
                    {"candidate_package.jls"}:
                raise RuntimeError("symlink guard published mixed artifacts")
            symlink_case = {"status": "pass", "phase": phase,
                            "external_before": external_before,
                            "external_after": file_receipt(external),
                            "link_is_symlink": link.is_symlink(),
                            "first_error": symlink_first_error}
        symlink_case_id = runtime_plan[
            "preexisting_symlink_semantic_case"]
        executed_case_hits.append(symlink_case_id)
        symlink_case["case_id"] = symlink_case_id
        case_receipts["preexisting_symlink_owned_target"] = symlink_case

        driver_negative_specs = (
            ("candidate_receipt_precondition",
             wrong_candidate, positive["stable_projection_hash"],
             positive["result_reload_identity_hash"], True),
            ("serialized_result_postcondition",
             positive["candidate_sha256"], positive["stable_projection_hash"],
             sha256_bytes(b"wrong serialized result identity"), False),
            ("stable_projection_postcondition",
             positive["candidate_sha256"],
             sha256_bytes(b"wrong stable projection identity"),
             positive["result_reload_identity_hash"], False),
        )
        for stage, candidate_hash, stable_hash, reload_hash, zero_call in \
                driver_negative_specs:
            phase_dir = output / stage
            artifacts = phase_dir / "artifacts"
            phase = run_phase(stage, candidate_command(julia_common, positive,
                artifacts, candidate_hash, stable_hash, reload_hash), phase_dir,
                timeout_seconds=args.phase_timeout,
                working_set_limit_bytes=args.working_set_limit,
                environment=environment)
            phases.append(phase)
            require_natural(phase, exit_zero=False)
            receipt = verify_uncommitted(artifacts, stage,
                                         zero_call=zero_call)
            case_id = runtime_plan[
                "driver_postcondition_phase_case_ids"][stage]
            executed_case_hits.append(case_id)
            case_receipts[stage] = {
                "receipt": file_receipt(
                    artifacts / "replay_uncommitted_attempt.json"),
                "stage": receipt["stage"],
                "attempted_counts": receipt["attempted_counts"],
                "committed_counts": receipt["committed_counts"],
                "case_id": case_id,
            }

        actual_hit_counts = dict(sorted(Counter(executed_case_hits).items()))
        if actual_hit_counts != runtime_plan[
                "expected_runtime_case_hit_counts"]:
            raise RuntimeError("negative runtime case-hit inventory mismatch")
        if set(executed_case_hits) != set(runtime_plan[
                "expected_unique_case_ids"]):
            raise RuntimeError("negative unique case inventory mismatch")
        if [phase["name"] for phase in phases] != protocol["phase_order"] or \
                len(phases) != protocol["expected_phase_count"]:
            raise RuntimeError("negative phase order/count mismatch")
        if ast_inventory_assertion_sites != coverage[
                "ast_inventory_plan"]["total_assertion_site_count"] or \
                projection_assertion_sites_completed != 24 or \
                len(assertion_site_hit_summaries) != 7:
            raise RuntimeError("AST/projection assertion coverage incomplete")
        assertion_site_hit_aggregate = aggregate_assertion_site_hit_receipts(
            assertion_site_hit_summaries, coverage,
            coverage_map_sha256=coverage_map_sha256)
        context_transport_assertion_sites_completed = assertion_site_hit_aggregate[
            "context_transport_assertion_sites_completed_observed"]
        inputs_after = input_receipts(protocol)
        if inputs_after != inputs_before:
            raise RuntimeError("negative formal input drift")
        if git_head() != head_before:
            raise RuntimeError("repository HEAD drift")
        if heavy_processes():
            raise RuntimeError("negative formal run left residual processes")
        pipeline_pass = True
    except BaseException as error:
        failure = {"type": type(error).__name__, "message": str(error),
                   "traceback": "".join(traceback.format_exception(error))}
        raise
    finally:
        try:
            inputs_after_final = input_receipts(protocol)
            input_after_error = None
        except BaseException as snapshot_error:
            inputs_after_final = {}
            input_after_error = {"type": type(snapshot_error).__name__,
                                 "message": str(snapshot_error)}
        head_after = git_head()
        residual = heavy_processes()
        guard = pipeline_pass and failure is None and \
            input_after_error is None and inputs_after_final == inputs_before and \
            head_after == head_before and not residual
        final = {
            "schema": "vnext-t2-independent-negative-pipeline-final-r4",
            "status": "pass" if guard else "fail",
            "repository_head_before": head_before,
            "repository_head_after": head_after,
            "protocol": file_receipt(protocol_path),
            "positive_final": file_receipt(
                positive_root / "formal_t2_serial_replay.json")
                if (positive_root / "formal_t2_serial_replay.json").is_file()
                else None,
            "positive_pipeline_final": file_receipt(
                positive_root / "pipeline_final.json")
                if (positive_root / "pipeline_final.json").is_file()
                else None,
            "inputs_before": inputs_before,
            "inputs_after": inputs_after_final,
            "inputs_after_error": input_after_error,
            "phases": phases, "case_receipts": case_receipts,
            "executed_case_hits": executed_case_hits,
            "executed_case_hit_counts":
                dict(sorted(Counter(executed_case_hits).items())),
            "executed_unique_case_ids": sorted(set(executed_case_hits)),
            "executed_unique_case_count": len(set(executed_case_hits)),
            "executed_runtime_case_hit_count": len(executed_case_hits),
            "assertion_site_hit_receipt_schema":
                "vnext-t2-source-site-hit-aggregate-r1",
            "assertion_site_hit_phase_summaries":
                assertion_site_hit_summaries,
            "assertion_site_runtime_hits_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_runtime_hits_observed"],
            "assertion_site_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_count_observed"],
            "assertion_site_hit_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "assertion_site_hit_count_observed"],
            "assertion_site_hit_aggregate": assertion_site_hit_aggregate,
            "ast_inventory_assertion_site_count":
                ast_inventory_assertion_sites,
            "versioned_product_repair_assertion_sites_completed":
                projection_assertion_sites_completed,
            "context_transport_assertion_sites_completed":
                context_transport_assertion_sites_completed,
            "context_transport_assertion_sites_completed_observed":
                context_transport_assertion_sites_completed,
            "context_transport_source_site_count_observed":
                None if assertion_site_hit_aggregate is None else 23,
            "preserved_successor_runtime_hit_count_observed":
                None if assertion_site_hit_aggregate is None else
                assertion_site_hit_aggregate[
                    "preserved_successor_runtime_hit_count_observed"],
            "preserved_successor_assertion_site_count":
                coverage.get("preserved_successor_assertion_site_count"),
            "preserved_successor_expected_runtime_hit_count":
                coverage.get("preserved_successor_expected_runtime_hit_count"),
            "preserved_successor_expected_runtime_hit_count_static_plan":
                coverage.get("preserved_successor_expected_runtime_hit_count"),
            "residual_heavy_processes": residual,
            "failure": None if guard else failure,
            "formal_t2_accepted": False, "physical_acceptance": False,
            "scientific_acceptance": False,
            "actual_model_attestation": "unavailable",
        }
        write_json_new(output / "pipeline_final.json", final)

    print(json.dumps({
        "status": "pass", "pipeline_final":
            file_receipt(output / "pipeline_final.json"),
        "formal_t2_accepted": False,
    }, sort_keys=True), flush=True)
    print("VNEXT_T2_INDEPENDENT_NEGATIVES=PASS", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
