from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
DRIVER = TEST_ROOT / "actual_formal_negative_driver_r6.jl"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r10.py"
STATIC_QA = TEST_ROOT / "static_qa_independent_negative_r9.py"
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r4.py"
HISTORICAL_ATTEMPT3_LAUNCHER = TEST_ROOT / "frozen_launcher_attempt3.ps1"
OLD_SUITE = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "vnext_t2_identity_receipt_v2_tests.jl")
PROJECTION_SUITE = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "vnext_t2_package_full_content_projection_r1.jl")
T1_MANIFEST = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T1/"
    "formal_software_acceptance_r26_v9_r1/software_acceptance_manifest.json")
V3_QUALIFICATION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
    "software_acceptance_runtime_r5_r1/software_qualification.json")
R1_FAILURE_EVIDENCE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_independent_negative_r1")
R1_TIMEOUT_RECEIPT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_actual_r1_timeout_20260922/execution_receipt.json")
R1_SOURCE_PROTOCOL = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_dispatch_r1/protocol.json")
R1_PIPELINE_FINAL = R1_FAILURE_EVIDENCE / "pipeline_final.json"
R1_PROJECTION_DIR = R1_FAILURE_EVIDENCE / \
    "package_full_content_projection_regression"
R1_PROJECTION_PHASE_FILES = {
    "phase": R1_PROJECTION_DIR / "phase.json",
    "actual_observation": R1_PROJECTION_DIR / "actual_observation.json",
    "samples": R1_PROJECTION_DIR / "samples.jsonl",
    "stdout": R1_PROJECTION_DIR / "stdout.raw",
    "stderr": R1_PROJECTION_DIR / "stderr.raw",
}
PROJECTION_PASS_MARKER = \
    "T2_PROJECTION24_REUSE=PASS sites=24 groups=4"
ACTIVE_GUIDANCE = (
    ROOT / "docs/v4_multitopology_generation/README.md",
    ROOT / "docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md",
    ROOT / "docs/v4_multitopology_generation/10_genome_upgrade_execution.md",
    ROOT / "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
    ROOT / "docs/v4_multitopology_generation/16_execution_work_orders.md",
    ROOT / "docs/v4_multitopology_generation/21_next_execution_batches.md",
    ROOT / "docs/v4_multitopology_generation/22_agent_local_execution.md",
    ROOT / "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md",
    ROOT / "docs/v4_multitopology_generation/task_manifest.json",
)
ARCHIVE_COVERAGE = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry3/coverage_map_r8.json")
ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s")
ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES = {
    "freeze_failure": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freeze_failure.json",
    "stdout": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freezer.stdout.raw",
    "stderr": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freezer.stderr.raw",
    "coverage_map": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "coverage_map_r8.json",
}
ATTEMPT11_RETRY1_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1")
ATTEMPT11_RETRY1_FAILURE = ATTEMPT11_RETRY1_FAILURE_LEAF / "static_qa_failure.json"
ATTEMPT11_RETRY2_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry2")
ATTEMPT11_RETRY2_FAILURE_FILES = {
    "command_argv.json", "coverage_map_r8.json", "dispatch.json",
    "protocol.json", "static_qa.json", "static_qa.stderr.raw",
    "static_qa.stdout.raw",
    "projection24_reuse_preflight/phase.json",
    "projection24_reuse_preflight/reuse_receipt.json",
    "projection24_reuse_preflight/stderr.raw",
    "projection24_reuse_preflight/stdout.raw",
}
ATTEMPT7_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt7")
ATTEMPT7_EXECUTION = ATTEMPT7_ARCHIVE_LEAF / "actual_negative_execution_r2"
ATTEMPT7_BASELINE = ATTEMPT7_EXECUTION / "actual_formal_baseline"
ATTEMPT7_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
ATTEMPT10_EXECUTION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_actual_negative_r5_attempt10_case_progress")
ATTEMPT10_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress")
ATTEMPT10_FAILURE_FILES = {
    "attempt10_protocol": ATTEMPT10_ARCHIVE_LEAF / "protocol.json",
    "attempt10_coverage_map": ATTEMPT10_ARCHIVE_LEAF / "coverage_map_r7.json",
    "pipeline_start": ATTEMPT10_EXECUTION / "pipeline_start.json",
    "pipeline_final": ATTEMPT10_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT10_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT10_EXECUTION /
        "actual_formal_baseline/artifacts/summary.json",
    "preflight_phase": ATTEMPT10_EXECUTION / "actual_formal_preflight/phase.json",
    "preflight_stdout": ATTEMPT10_EXECUTION / "actual_formal_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT10_EXECUTION / "actual_formal_preflight/stderr.raw",
    "preflight_samples": ATTEMPT10_EXECUTION / "actual_formal_preflight/samples.jsonl",
    "preflight_observations": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/observations.jsonl",
    "preflight_stage_trace": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/stage_trace.tsv",
    "preflight_transport_observation": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/context_transport_observation.json",
}
ATTEMPT10_LINEAGE_FILES = {
    "root_observation": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "root_attempt10_postrun_observation_20260924/observation.json",
        "6711e3cdd06faf20180651b1ec678f57409b728dc44dd3373657bb21c29c69e3"),
    "root_decision": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "root_attempt10_postrun_observation_20260924/decision.md",
        "1aa6725c461350b30cf287e38bafb913ee80faca3d0ee6cea04e5549a0c2b35b"),
    "independent_review": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "independent_attempt10_postrun_review_20260924/review.json",
        "d800a165ecf9386f8d32ce1ed32193a6d8df18b6855f90a9f7a1289e2ac19892"),
    "independent_tester_review": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "independent_attempt10_postrun_tester_20260924/"
        "attempt10_postrun_independent_review.json",
        "3a3d28f4c7c0eba74d12a4dca9ac06e0cbf95c09797e64a4d5e4a42e80b5429d"),
}
ATTEMPT9C_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9c_final")
ATTEMPT9C_EXECUTION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_actual_negative_r4_attempt9c_final")
ATTEMPT9C_FAILURE_FILES = {
    "archive_protocol": ATTEMPT9C_ARCHIVE_LEAF / "protocol.json",
    "archive_coverage_map": ATTEMPT9C_ARCHIVE_LEAF / "coverage_map_r3.json",
    "pipeline_start": ATTEMPT9C_EXECUTION / "pipeline_start.json",
    "pipeline_final": ATTEMPT9C_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT9C_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT9C_EXECUTION / "actual_formal_baseline/artifacts/summary.json",
    "baseline_context": ATTEMPT9C_EXECUTION / "actual_formal_baseline/artifacts/baseline_context.jls",
    "baseline_authorization": ATTEMPT9C_EXECUTION / "actual_formal_baseline_authorization.json",
    "authority_phase": ATTEMPT9C_EXECUTION / "actual_formal_authority/phase.json",
    "authority_stdout": ATTEMPT9C_EXECUTION / "actual_formal_authority/stdout.raw",
    "authority_stderr": ATTEMPT9C_EXECUTION / "actual_formal_authority/stderr.raw",
    "authority_samples": ATTEMPT9C_EXECUTION / "actual_formal_authority/samples.jsonl",
    "authority_observations": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/observations.jsonl",
    "authority_transport": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/context_transport_observation.json",
    "authority_stage_trace": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/stage_trace.tsv",
}
ATTEMPT8_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2")
ATTEMPT8_EXECUTION = ATTEMPT8_ARCHIVE_LEAF / "actual_negative_execution_r3"
ATTEMPT8_FAILURE_FILES = {
    "protocol": ATTEMPT8_ARCHIVE_LEAF / "protocol.json",
    "dispatch": ATTEMPT8_ARCHIVE_LEAF / "dispatch.json",
    "pipeline_final": ATTEMPT8_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT8_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT8_EXECUTION /
        "actual_formal_baseline/artifacts/summary.json",
    "baseline_authorization": ATTEMPT8_EXECUTION /
        "actual_formal_baseline_authorization.json",
    "preflight_phase": ATTEMPT8_EXECUTION /
        "actual_formal_preflight/phase.json",
    "preflight_stderr": ATTEMPT8_EXECUTION /
        "actual_formal_preflight/stderr.raw",
}
ATTEMPT8_EXPECTED_DRIVER_ERROR = (
    "ERROR: LoadError: expected mode, four authority path/hash pairs, "
    "context path/hash, authorization path/hash, output dir, coverage map path/hash")
ATTEMPT9_FIRST_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9")
ATTEMPT9_FIRST_FAILURE_FILES = {
    "protocol": ATTEMPT9_FIRST_FAILURE_LEAF / "protocol.json",
    "coverage_map": ATTEMPT9_FIRST_FAILURE_LEAF / "coverage_map_r3.json",
    "preflight_phase": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json",
    "preflight_stdout": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw",
}
ATTEMPT9_EXPECTED_VALIDATOR_ERROR = \
    "RuntimeError: projection reuse protocol schema mismatch"
ATTEMPT9B_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9b")
ATTEMPT9B_FAILURE_FILES = {
    "protocol": ATTEMPT9B_FAILURE_LEAF / "protocol.json",
    "coverage_map": ATTEMPT9B_FAILURE_LEAF / "coverage_map_r3.json",
    "dispatch": ATTEMPT9B_FAILURE_LEAF / "dispatch.json",
    "command": ATTEMPT9B_FAILURE_LEAF / "command_argv.json",
    "preflight_phase": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json",
    "preflight_receipt": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/reuse_receipt.json",
    "preflight_stdout": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw",
    "static_qa": ATTEMPT9B_FAILURE_LEAF / "static_qa.json",
    "static_qa_stdout": ATTEMPT9B_FAILURE_LEAF / "static_qa.stdout.raw",
    "static_qa_stderr": ATTEMPT9B_FAILURE_LEAF / "static_qa.stderr.raw",
}
ATTEMPT9B_EXPECTED_QA_FAILURE = {
    "type": "KeyError", "message": "'manifest_path'",
}
GENERATED_PYTHON_CACHE = {
    "freeze_independent_negative_protocol_r3.cpython-313.pyc": {
        "bytes": 48089,
        "sha256": "ebc3c1cfc31b7acf306d5f9addfaff5e45ca4a6772877585148a7df57d897608",
    },
    "static_qa_independent_negative_r3.cpython-313.pyc": {
        "bytes": 72660,
        "sha256": "30cf8b444ec15c98e018a8cfb261e650acc61cf431e83ef65d59535cc5e51e4b",
    },
}
PHASE_ORDER = [
    "parse_gate", "coverage_ast_inventory", "projection24_cross_run_validation",
    "actual_formal_baseline", "actual_formal_preflight",
    "actual_formal_authority", "actual_formal_fault_n10",
    "actual_formal_t1_handoff", "supplementary_edited_operation",
    "supplementary_child_coupling", "artifact_hash_precondition",
    "artifact_recomputed_corrupt", "artifact_zero_malformed",
    "artifact_attack_fixture_generation",
    "formal_driver_artifact_raw_hash_precondition",
    "formal_driver_artifact_deserialize_precondition",
    "formal_driver_artifact_zero_precondition",
    "formal_driver_artifact_wrong_type_precondition",
    "formal_driver_artifact_foreign_package_precondition",
    "preexisting_candidate_package_jls",
    "preexisting_candidate_t1_admission_receipt_json",
    "preexisting_t2_result_jls", "preexisting_run_receipt_json",
    "preexisting_replay_uncommitted_attempt_json",
    "preexisting_prior_success_set", "preexisting_prior_uncommitted",
    "preexisting_symlink_owned_target", "candidate_receipt_precondition",
    "serialized_result_postcondition", "stable_projection_postcondition",
]
CHILD_PHASE_BINDINGS = {
    "parse_gate": "PARSE_GATE",
    "coverage_ast_inventory": "AST_INVENTORY_DRIVER",
    "projection24_cross_run_validation": "PROJECTION_REUSE_VALIDATOR",
    "actual_formal_baseline": "ACTUAL_DRIVER",
    "actual_formal_preflight": "ACTUAL_DRIVER",
    "actual_formal_authority": "ACTUAL_DRIVER",
    "actual_formal_fault_n10": "ACTUAL_DRIVER",
    "actual_formal_t1_handoff": "ACTUAL_DRIVER",
    "supplementary_edited_operation": "SUPPLEMENTARY_DRIVER",
    "supplementary_child_coupling": "SUPPLEMENTARY_DRIVER",
    "artifact_hash_precondition": "ARTIFACT_DRIVER",
    "artifact_recomputed_corrupt": "ARTIFACT_DRIVER",
    "artifact_zero_malformed": "ARTIFACT_DRIVER",
    "artifact_attack_fixture_generation": "ATTACK_FIXTURE_DRIVER",
    "formal_driver_artifact_raw_hash_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_deserialize_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_zero_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_wrong_type_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_foreign_package_precondition": "CANDIDATE_DRIVER",
    "preexisting_candidate_package_jls": "CANDIDATE_DRIVER",
    "preexisting_candidate_t1_admission_receipt_json": "CANDIDATE_DRIVER",
    "preexisting_t2_result_jls": "CANDIDATE_DRIVER",
    "preexisting_run_receipt_json": "CANDIDATE_DRIVER",
    "preexisting_replay_uncommitted_attempt_json": "CANDIDATE_DRIVER",
    "preexisting_prior_success_set": "CANDIDATE_DRIVER",
    "preexisting_prior_uncommitted": "CANDIDATE_DRIVER",
    "preexisting_symlink_owned_target": "CANDIDATE_DRIVER",
    "candidate_receipt_precondition": "CANDIDATE_DRIVER",
    "serialized_result_postcondition": "CANDIDATE_DRIVER",
    "stable_projection_postcondition": "CANDIDATE_DRIVER",
}
CHILD_BINDING_PATHS = {
    "PARSE_GATE": (
        "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl"),
    "AST_INVENTORY_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "coverage_ast_inventory_r3.jl"),
    "PROJECTION_REUSE_VALIDATOR": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "validate_projection24_reuse_r4.py"),
    "ACTUAL_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "actual_formal_negative_driver_r6.jl"),
    "SUPPLEMENTARY_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "supplementary_contract_driver_r1.jl"),
    "ARTIFACT_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "artifact_preflight_negative_driver_r1.jl"),
    "ATTACK_FIXTURE_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "artifact_attack_fixture_driver_r1.jl"),
    "CANDIDATE_DRIVER": (
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
        "formal_candidate_driver.jl"),
}


def build_controller_child_script_plan() -> dict[str, Any]:
    if list(CHILD_PHASE_BINDINGS) != PHASE_ORDER or \
            set(CHILD_BINDING_PATHS) != set(CHILD_PHASE_BINDINGS.values()):
        raise RuntimeError("controller child script plan does not cover phase order")
    phase_to_paths = {
        phase: [CHILD_BINDING_PATHS[binding]]
        for phase, binding in CHILD_PHASE_BINDINGS.items()
    }
    unique_paths = list(dict.fromkeys(
        path for phase in PHASE_ORDER for path in phase_to_paths[phase]))
    return {
        "schema": "vnext-t2-controller-child-script-plan-r2",
        "phase_count": len(PHASE_ORDER),
        "unique_script_count": len(unique_paths),
        "phase_ids": list(PHASE_ORDER),
        "script_paths": unique_paths,
        "phase_to_script_paths": phase_to_paths,
        "python_child_phase_ids": ["projection24_cross_run_validation"],
        "dynamic_python_imports_in_controller": [],
    }


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    resolved.relative_to(ROOT)
    data = resolved.read_bytes()
    return {"path": resolved.relative_to(ROOT).as_posix(),
            "bytes": len(data), "sha256": sha256_bytes(data)}


def generated_python_cache_exclusions() -> list[dict[str, Any]]:
    cache_dir = TEST_ROOT / "__pycache__"
    if not cache_dir.is_dir():
        raise RuntimeError("expected generated Python cache directory is absent")
    entries = sorted(cache_dir.rglob("*"))
    files = [path for path in entries if path.is_file()]
    if any(not path.is_file() for path in entries) or \
            [path.name for path in files] != sorted(GENERATED_PYTHON_CACHE):
        raise RuntimeError("generated Python cache inventory gained/lost a file")
    rows = [receipt(path) for path in files]
    for row in rows:
        expected = GENERATED_PYTHON_CACHE[Path(row["path"]).name]
        if row["bytes"] != expected["bytes"] or \
                row["sha256"] != expected["sha256"]:
            raise RuntimeError("generated Python cache bytes/SHA changed")
    return rows


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def assertion_expression(lines: list[str], line_number: int) -> str:
    line = lines[line_number - 1]
    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    body = [stripped]
    cursor = line_number
    while cursor < len(lines):
        candidate = lines[cursor]
        candidate_stripped = candidate.lstrip()
        candidate_indent = len(candidate) - len(candidate_stripped)
        if not candidate_stripped or candidate_stripped.startswith("#") or \
                candidate_indent <= indent:
            break
        body.append(candidate_stripped)
        cursor += 1
    return " ".join(part.strip() for part in body)


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def files_under(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path
        return
    if not path.is_dir():
        raise FileNotFoundError(path)
    yield from sorted(item for item in path.rglob("*") if item.is_file())


def add_input(inputs: dict[str, dict[str, Any]], path: Path) -> None:
    row = receipt(path)
    old = inputs.get(row["path"])
    if old is not None and old != row:
        raise RuntimeError(f"input changed while freezing: {row['path']}")
    inputs[row["path"]] = row


def build_attempt8_preflight_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT8_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT8_FAILURE_FILES["protocol"])
    previous_dispatch = load_object(ATTEMPT8_FAILURE_FILES["dispatch"])
    previous_pipeline = load_object(ATTEMPT8_FAILURE_FILES["pipeline_final"])
    baseline_phase = load_object(ATTEMPT8_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT8_FAILURE_FILES["baseline_summary"])
    failed_phase = load_object(ATTEMPT8_FAILURE_FILES["preflight_phase"])
    driver_path = ROOT / previous_protocol["driver_path"]
    controller_path = ROOT / previous_protocol["controller_path"]
    prior_protocol_inputs = previous_protocol.get("inputs", {})
    for path in (driver_path, controller_path):
        add_input(inputs, path)
        expected = prior_protocol_inputs.get(path.relative_to(ROOT).as_posix())
        if expected != receipt(path):
            raise RuntimeError(f"attempt8 source pin drift: {path}")
    command = failed_phase.get("command")
    if not isinstance(command, list) or str(driver_path.resolve()) not in command:
        raise RuntimeError("attempt8 preflight command lacks the pinned r3 driver")
    driver_index = command.index(str(driver_path.resolve()))
    driver_args = command[driver_index + 1:]
    driver_source = driver_path.read_text(encoding="utf-8")
    prior_coverage = previous_protocol.get("coverage_map", {})
    expected_map_path = str((ROOT / prior_coverage.get("path", "")).resolve())
    expected_map_sha = prior_coverage.get("sha256")
    stderr = ATTEMPT8_FAILURE_FILES["preflight_stderr"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r3" or \
            previous_dispatch.get("formal_t2_accepted") is not False or \
            baseline_phase.get("name") != "actual_formal_baseline" or \
            baseline_phase.get("stop_reason") != "natural_exit" or \
            baseline_phase.get("exit_code") != 0 or \
            baseline_summary.get("status") != "pass" or \
            failed_phase.get("name") != "actual_formal_preflight" or \
            failed_phase.get("stop_reason") != "natural_exit" or \
            failed_phase.get("exit_code") != 1 or \
            failed_phase.get("timeout_seconds") != 480.0 or \
            failed_phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            failed_phase.get("formal_t2_accepted") is True or \
            not stderr or stderr[0] != ATTEMPT8_EXPECTED_DRIVER_ERROR or \
            "length(ARGS) == 16 || error(" not in driver_source or \
            "abspath(ARGS[15])" not in driver_source or \
            "lowercase(ARGS[16])" not in driver_source or \
            len(driver_args) != 14 or driver_args[0] != "preflight" or \
            driver_args[-2:] == [expected_map_path, expected_map_sha] or \
            previous_pipeline.get("status") != "fail" or \
            previous_pipeline.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt8 preflight failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt8-preflight-arity-failure-r1",
        "status": "preserved_natural_exit_failure_not_acceptance",
        "files": frozen_files,
        "driver_path": previous_protocol["driver_path"],
        "controller_path": previous_protocol["controller_path"],
        "driver_expected_argument_count": 16,
        "observed_preflight_argument_count": len(driver_args),
        "observed_preflight_exit_code": failed_phase["exit_code"],
        "observed_preflight_stop_reason": failed_phase["stop_reason"],
        "observed_error_line": stderr[0],
        "missing_final_coverage_map_pair": {
            "path": expected_map_path, "sha256": expected_map_sha,
        },
        "baseline_natural_exit_zero": True,
        "formal_t2_accepted": False,
    }


def build_attempt9_projection_preflight_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT9_FIRST_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT9_FIRST_FAILURE_FILES["protocol"])
    previous_phase = load_object(
        ATTEMPT9_FIRST_FAILURE_FILES["preflight_phase"])
    previous_coverage_receipt = previous_protocol.get("coverage_map", {})
    validator_r3 = TEST_ROOT / "validate_projection24_reuse_r3.py"
    relative_validator = validator_r3.relative_to(ROOT).as_posix()
    stderr_lines = ATTEMPT9_FIRST_FAILURE_FILES["preflight_stderr"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    phase_argv = previous_phase.get("command_argv")
    expected_protocol_path = str(
        (ATTEMPT9_FIRST_FAILURE_LEAF / "protocol.json").resolve())
    expected_receipt_path = str((ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/reuse_receipt.json").resolve())
    previous_pins = previous_protocol.get("inputs", {})
    add_input(inputs, validator_r3)
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("status") != \
            "frozen_static_ready_not_executed" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_executed") is True or \
            previous_protocol.get("julia_started") is True or \
            previous_coverage_receipt.get("path") != \
            ATTEMPT9_FIRST_FAILURE_FILES["coverage_map"].relative_to(
                ROOT).as_posix() or \
            receipt(ATTEMPT9_FIRST_FAILURE_FILES["coverage_map"]) != {
                "path": previous_coverage_receipt.get("path"),
                "bytes": previous_coverage_receipt.get("bytes"),
                "sha256": previous_coverage_receipt.get("sha256"),
            } or previous_pins.get(relative_validator) != receipt(validator_r3) or \
            previous_phase.get("name") != \
            "projection24_reuse_python_preflight" or \
            previous_phase.get("status") != "fail" or \
            previous_phase.get("stop_reason") != "natural_exit" or \
            previous_phase.get("exit_code") != 1 or \
            previous_phase.get("timeout_seconds") != 300 or \
            previous_phase.get("julia_started") is not False or \
            previous_phase.get("formal_t2_accepted") is not False or \
            previous_phase.get("pass_marker_observed") is not False or \
            phase_argv != [sys.executable, "-B", str(validator_r3),
                           expected_protocol_path, expected_receipt_path] or \
            (not stderr_lines or not stderr_lines[-1].endswith(
                ATTEMPT9_EXPECTED_VALIDATOR_ERROR)) or \
            (ATTEMPT9_FIRST_FAILURE_LEAF / "static_qa.json").exists() or \
            (ATTEMPT9_FIRST_FAILURE_LEAF / "freeze_snapshot.json").exists() or \
            (ATTEMPT9_FIRST_FAILURE_LEAF /
             "projection24_reuse_preflight/reuse_receipt.json").exists():
        raise RuntimeError("attempt9 projection schema failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt9-projection-schema-preflight-failure-r1",
        "status": "preserved_natural_exit_failure_not_acceptance",
        "files": frozen_files,
        "validator_r3_path": relative_validator,
        "validator_r3_sha256": receipt(validator_r3)["sha256"],
        "observed_exit_code": previous_phase["exit_code"],
        "observed_stop_reason": previous_phase["stop_reason"],
        "observed_stderr_final_line": stderr_lines[-1],
        "protocol_schema_expected": "vnext-t2-independent-negative-protocol-r3",
        "protocol_schema_observed": previous_protocol["schema"],
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def build_projection_validator_r3_r4_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r3_path = TEST_ROOT / "validate_projection24_reuse_r3.py"
    r4_path = TEST_ROOT / "validate_projection24_reuse_r4.py"
    add_input(inputs, r3_path)
    add_input(inputs, r4_path)
    r3_text = r3_path.read_text(encoding="utf-8")
    r4_text = r4_path.read_text(encoding="utf-8")
    substitutions = [
        ("validate_projection24_reuse_r3.py",
         "validate_projection24_reuse_r4.py"),
        ("vnext-t2-independent-negative-protocol-r3",
         "vnext-t2-independent-negative-protocol-r4"),
        ("vnext-t2-projection24-cross-run-validation-r3",
         "vnext-t2-projection24-cross-run-validation-r4"),
    ]
    normalized = r4_text
    for old, new in substitutions:
        if r3_text.count(old) != 1 or r4_text.count(new) != 1:
            raise RuntimeError(f"projection validator schema delta is ambiguous: {old}")
        normalized = normalized.replace(new, old)
    if normalized != r3_text:
        raise RuntimeError("projection validator r3/r4 changed non-schema semantics")
    unified = "".join(difflib.unified_diff(
        r3_text.splitlines(keepends=True), r4_text.splitlines(keepends=True),
        fromfile=r3_path.relative_to(ROOT).as_posix(),
        tofile=r4_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-projection-validator-r3-r4-delta-r1",
        "r3_source": receipt(r3_path),
        "r4_source": receipt(r4_path),
        "allowed_replacements": [
            {"from": old, "to": new, "occurrences": 1}
            for old, new in substitutions],
        "non_schema_semantic_changes": 0,
        "normalized_r4_source_equals_r3": True,
        "unified_diff": unified,
    }


def build_controller_r8_r9_authority_progress_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r8.py"
    current_path = TEST_ROOT / "independent_negative_controller_r9.py"
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_tree = ast.parse(prior_path.read_text(encoding="utf-8"))
    current_tree = ast.parse(current_path.read_text(encoding="utf-8"))
    mutable_names = {"_authority_source_ids", "verify_authority_case_receipt",
                     "run_authority_case_phase",
                     "summarize_authority_case_progress_prefix", "main"}
    mutable_bindings = {"ACTUAL_DRIVER", "AUTHORITY_CASE_TIMEOUT_SECONDS"}
    def normalized(tree: ast.Module) -> tuple[list[str], dict[str, str]]:
        untouched = []
        functions = {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name) and \
                    node.targets[0].id in mutable_bindings:
                continue
            elif isinstance(node, (ast.Import, ast.ImportFrom)):
                untouched.append(ast.dump(node, include_attributes=False))
            else:
                untouched.append(ast.dump(node, include_attributes=False))
        return untouched, functions
    prior_top, prior_functions = normalized(prior_tree)
    current_top, current_functions = normalized(current_tree)
    prior_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in prior_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    current_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in current_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    changed_bindings = sorted(name for name in mutable_bindings
        if prior_assignments.get(name) != current_assignments.get(name))
    if prior_top != current_top or changed_bindings != sorted(mutable_bindings):
        raise RuntimeError("controller r9 changed unapproved module bindings")
    changed_functions = sorted(name for name in set(prior_functions) | set(current_functions)
        if prior_functions.get(name) != current_functions.get(name))
    if changed_functions != sorted(mutable_names):
        raise RuntimeError(f"controller r9 changed unexpected functions: {changed_functions}")
    old_text = prior_path.read_text(encoding="utf-8")
    new_text = current_path.read_text(encoding="utf-8")
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r8-r9-authority-progress-delta-r1",
        "r8_source": receipt(prior_path),
        "r9_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_bindings": changed_bindings,
        "unchanged_other_module_bindings_and_functions": True,
        "coverage_semantics_changed": False,
        "authority_case_wall_budget_delta": {
            "prior_case_seconds": 1200,
            "current_case_seconds": 2400,
            "invocation_cap_seconds": 2400,
            "effective_timeout": "min(per_case_cap, remaining_invocation_budget)",
            "rationale": "a 1200s child cap has no evidence-backed sufficiency after attempt9c observed no case completion under the 480s invocation cutoff; matching the child cap to the invocation cap lets a case finish and then permits safe resume of later incomplete cases",
        },
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r9_r10_preflight_budget_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r9.py"
    current_path = CONTROLLER
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_text = prior_path.read_text(encoding="utf-8")
    current_text = current_path.read_text(encoding="utf-8")
    prior_tree = ast.parse(prior_text)
    current_tree = ast.parse(current_text)
    mutable_functions = {"actual_formal_shard_timeout", "main"}
    mutable_bindings = {"PREFLIGHT_PHASE_TIMEOUT_SECONDS"}
    def split(tree: ast.Module) -> tuple[list[str], dict[str, str], dict[str, str]]:
        fixed, functions, bindings = [], {}, {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name) and \
                    node.targets[0].id in mutable_bindings:
                bindings[node.targets[0].id] = ast.dump(
                    node, include_attributes=False)
            else:
                fixed.append(ast.dump(node, include_attributes=False))
        return fixed, functions, bindings
    prior_fixed, prior_functions, prior_bindings = split(prior_tree)
    current_fixed, current_functions, current_bindings = split(current_tree)
    changed_functions = sorted(name for name in
        set(prior_functions) | set(current_functions)
        if prior_functions.get(name) != current_functions.get(name))
    changed_bindings = sorted(name for name in mutable_bindings
        if prior_bindings.get(name) != current_bindings.get(name))
    if prior_fixed != current_fixed or \
            changed_functions != sorted(mutable_functions) or \
            changed_bindings != sorted(mutable_bindings) or \
            current_bindings.get("PREFLIGHT_PHASE_TIMEOUT_SECONDS") is None:
        raise RuntimeError("controller r10 contains changes outside the preflight timeout policy")
    normalized = current_text
    exact_replacements = [
        ("PREFLIGHT_PHASE_TIMEOUT_SECONDS = 600\n", ""),
        ("\n\ndef actual_formal_shard_timeout(mode: str, configured_default: float) -> float:\n"
         "    if configured_default != 480:\n"
         "        raise ValueError(\"formal shard default phase timeout must remain 480s\")\n"
         "    if mode == \"preflight\":\n"
         "        return PREFLIGHT_PHASE_TIMEOUT_SECONDS\n"
         "    if mode not in {\"fault_n10\", \"t1_handoff\"}:\n"
         "        raise ValueError(f\"unsupported timeout policy for shard: {mode}\")\n"
         "    return configured_default\n\n", "\n"),
        ("negative formal phases require 480s default, 600s preflight override, 2GiB, and authority 2400s/2400s gates",
         "negative formal phases require 480s/2GiB and authority 2400s/2400s gates"),
        ("    if protocol.get(\"resource_gates\", {}).get(\n"
         "            \"phase_wall_timeout_overrides\") != {\n"
         "                \"actual_formal_preflight\": PREFLIGHT_PHASE_TIMEOUT_SECONDS}:\n"
         "        raise RuntimeError(\"preflight phase timeout override differs from controller policy\")\n", ""),
        ("        \"preflight_phase_timeout_seconds\": PREFLIGHT_PHASE_TIMEOUT_SECONDS,\n", ""),
        ("timeout_seconds=actual_formal_shard_timeout(\n"
         "                        mode, args.phase_timeout),", "timeout_seconds=args.phase_timeout,"),
        ("vnext-t2-independent-negative-coverage-map-r8",
         "vnext-t2-independent-negative-coverage-map-r7"),
    ]
    for current_fragment, prior_fragment in exact_replacements:
        if normalized.count(current_fragment) != 1:
            raise RuntimeError("controller r10 exact preflight-only normalization is ambiguous")
        normalized = normalized.replace(current_fragment, prior_fragment, 1)
    if normalized != prior_text:
        raise RuntimeError("controller r9/r10 changed more than the exact preflight timeout delta")
    unified = "".join(difflib.unified_diff(
        prior_text.splitlines(keepends=True), current_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r9-r10-preflight-budget-delta-r1",
        "r9_source": receipt(prior_path),
        "r10_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_bindings": changed_bindings,
        "unchanged_other_module_bindings_and_functions": True,
        "coverage_semantics_changed": False,
        "preflight_phase_wall_budget_delta": {
            "prior_phase_seconds": 480,
            "current_preflight_seconds": 600,
            "only_phase_override": "actual_formal_preflight",
            "other_formal_phases_seconds": 480,
            "julia_threads": 1,
            "openblas_threads": 1,
            "working_set_limit_bytes": 2_147_483_648,
            "coverage_thresholds_changed": False,
            "rationale": (
                "attempt10 completed 16 of 18 planned preflight observations "
                "within 480.1707022s after 183.6627444s of fresh preparation; "
                "at the conservative whole-attempt average the final two "
                "observations need about 37.0635s and the 600s limit leaves "
                "about 82.7658s for variance and natural summary/finalization. "
                "This estimate is not a guarantee; natural exit and all 18 "
                "observations remain mandatory."),
        },
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_attempt10_preflight_interruption_record(
        inputs: dict[str, dict[str, Any]], coverage: dict[str, Any]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT10_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    lineage = {}
    for name, (path, expected_sha256) in ATTEMPT10_LINEAGE_FILES.items():
        add_input(inputs, path)
        pinned = receipt(path)
        if pinned["sha256"] != expected_sha256:
            raise RuntimeError(f"attempt10 root/reviewer lineage pin drift: {name}")
        lineage[name] = pinned
    old_protocol = load_object(ATTEMPT10_FAILURE_FILES["attempt10_protocol"])
    old_coverage = load_object(ATTEMPT10_FAILURE_FILES["attempt10_coverage_map"])
    pipeline = load_object(ATTEMPT10_FAILURE_FILES["pipeline_final"])
    baseline_phase = load_object(ATTEMPT10_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT10_FAILURE_FILES["baseline_summary"])
    phase = load_object(ATTEMPT10_FAILURE_FILES["preflight_phase"])
    expected_cases = coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    old_expected_cases = old_coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    observations = [json.loads(line) for line in
        ATTEMPT10_FAILURE_FILES["preflight_observations"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    stdout_text = ATTEMPT10_FAILURE_FILES["preflight_stdout"].read_text(
        encoding="utf-8", errors="replace")
    actual_rows = []
    for line in stdout_text.splitlines():
        marker = "VNEXT_T2_NEGATIVE_ACTUAL="
        if line.startswith(marker):
            actual_rows.append(json.loads(line[len(marker):]))
    sample_rows = [json.loads(line) for line in
        ATTEMPT10_FAILURE_FILES["preflight_samples"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    trace_lines = ATTEMPT10_FAILURE_FILES["preflight_stage_trace"].read_text(
        encoding="utf-8").splitlines()
    trace = {}
    for line in trace_lines[1:]:
        parts = line.split("\t")
        if len(parts) >= 3:
            event, *fields = parts
            values = {}
            for field in fields:
                if "=" in field:
                    key, value = field.split("=", 1)
                    values[key] = value
            trace.setdefault(event, []).append(values)
    sample_peak = max(row.get("process_tree_working_set_bytes", 0)
                      for row in sample_rows)
    observation_ids = [row.get("case_id") for row in observations]
    marker_ids = [row.get("case_id") for row in actual_rows]
    script_entry = trace.get("script_entry", [{}])[0].get("time_ns")
    attack_begin = trace.get("attack_group_preflight.begin", [{}])[0].get(
        "time_ns")
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            old_protocol.get("coverage_map") != receipt(
                ATTEMPT10_FAILURE_FILES["attempt10_coverage_map"]) or \
            old_protocol.get("formal_t2_accepted") is not False or \
            old_protocol.get("julia_started") is True or \
            old_coverage.get("schema") != \
            "vnext-t2-independent-negative-coverage-map-r7" or \
            old_coverage.get("successor_assertion_site_count") != 214 or \
            old_coverage.get("successor_expected_runtime_hit_count") != 622 or \
            old_expected_cases != expected_cases or len(expected_cases) != 18 or \
            baseline_phase.get("name") != "actual_formal_baseline" or \
            baseline_phase.get("stop_reason") != "natural_exit" or \
            baseline_phase.get("exit_code") != 0 or \
            baseline_phase.get("seconds") != 318.56537460000254 or \
            baseline_phase.get("peak_process_tree_working_set_bytes") != \
                1_669_619_712 or baseline_phase.get(
                    "working_set_limit_bytes") != 2_147_483_648 or \
            baseline_summary.get("status") != "pass" or \
            baseline_summary.get("assertion_site_hit_count_observed") != 53 or \
            baseline_summary.get("formal_t2_accepted") is not False or \
            phase.get("name") != "actual_formal_preflight" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or \
            phase.get("timeout_seconds") != 480.0 or \
            abs(phase.get("seconds", 0) - 480.1707022000046) > 0.01 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_754_058_752 or \
            phase.get("formal_t2_accepted") is True or sample_peak != 1_754_058_752 or \
            len(sample_rows) != 2031 or len(observations) != 16 or \
            observation_ids != expected_cases[:16] or marker_ids != observation_ids or \
            observation_ids[-1] != "CHILD_FOREIGN" or \
            expected_cases[16:] != ["FEEDBACK_STALE", "FEEDBACK_FOREIGN"] or \
            "attack_group_preflight.begin" not in trace or \
            "attack_group_preflight.end" in trace or \
            not isinstance(script_entry, str) or not script_entry.isdigit() or \
            not isinstance(attack_begin, str) or not attack_begin.isdigit() or \
            int(attack_begin) <= int(script_entry) or \
            abs((int(attack_begin) - int(script_entry)) / 1_000_000_000 -
                183.6627444) > 0.01 or \
            ATTEMPT10_FAILURE_FILES["preflight_stderr"].read_bytes() != b"" or \
            pipeline.get("status") != "fail" or \
            pipeline.get("failure", {}).get("message") != \
                "actual_formal_preflight stop=phase_wall_timeout" or \
            pipeline.get("assertion_site_hit_aggregate") is not None or \
            pipeline.get("assertion_site_hit_count_observed") is not None or \
            pipeline.get("formal_t2_accepted") is not False or \
            (ATTEMPT10_EXECUTION / "actual_formal_authority").exists():
        raise RuntimeError("attempt10 preflight interruption or 16/18 observation evidence mismatch")
    elapsed = phase["seconds"]
    prep = (int(attack_begin) - int(script_entry)) / 1_000_000_000
    post_prepare = elapsed - prep
    expected_remaining = post_prepare / len(observation_ids) * (
        len(expected_cases) - len(observation_ids))
    extra_budget = 600.0 - elapsed
    estimated_finalization_margin = extra_budget - expected_remaining
    return {
        "schema": "vnext-t2-attempt10-preflight-wall-interruption-r1",
        "status": "preserved_resource_interruption_partial_not_scientific_failure",
        "files": frozen_files,
        "parent_decision_and_independent_reviews": lineage,
        "prior_protocol_schema": old_protocol["schema"],
        "prior_coverage_map": frozen_files["attempt10_coverage_map"],
        "baseline": {
            "natural_exit_code": 0,
            "seconds": baseline_phase["seconds"],
            "actual_assertion_site_hits":
                baseline_summary["assertion_site_hit_count_observed"],
            "peak_process_tree_working_set_bytes":
                baseline_phase["peak_process_tree_working_set_bytes"],
        },
        "preflight": {
            "planned_case_count": len(expected_cases),
            "actual_complete_observation_count": len(observation_ids),
            "completed_case_ids": observation_ids,
            "last_complete_case_id": observation_ids[-1],
            "remaining_case_ids": expected_cases[len(observation_ids):],
            "remaining_cases_claimed_executed": False,
            "timeout_seconds": phase["timeout_seconds"],
            "elapsed_seconds": elapsed,
            "exit_code": phase["exit_code"],
            "stop_reason": phase["stop_reason"],
            "stdout_marker_count": len(actual_rows),
            "stderr_bytes": 0,
            "sample_count": len(sample_rows),
            "peak_process_tree_working_set_bytes": sample_peak,
            "stage_trace_receipt": frozen_files["preflight_stage_trace"],
            "prep_before_attack_group_seconds": round(prep, 6),
            "post_prepare_until_timeout_seconds": round(post_prepare, 6),
            "remaining_two_case_time_at_observed_average_seconds":
                round(expected_remaining, 6),
        },
        "attempt11_budget_change": {
            "prior_preflight_phase_wall_seconds": 480,
            "new_preflight_phase_wall_seconds": 600,
            "other_formal_phase_wall_seconds": 480,
            "additional_wall_seconds_after_attempt10_timeout":
                round(extra_budget, 6),
            "estimated_finalization_margin_after_remaining_cases_seconds":
                round(estimated_finalization_margin, 6),
            "estimate_is_guarantee": False,
            "one_fresh_process_repeats_initialization": True,
            "attempt10_partial_cases_reused": False,
            "failed_attempt11_partial_cases_credit": 0,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "coverage_thresholds_changed": False,
            "formal_t2_accepted": False,
        },
        "formal_t2_accepted": False,
    }


def build_attempt11_initial_freeze_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    files = {}
    for name, path in ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES.items():
        add_input(inputs, path)
        files[name] = receipt(path)
    failure = load_object(ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES[
        "freeze_failure"])
    if failure.get("schema") != \
            "vnext-t2-attempt11-initial-freezer-failure-r1" or \
            failure.get("status") != \
            "preserved_python_freezer_lineage_guard_failure_no_t2_execution" or \
            failure.get("exit_code") != 1 or \
            failure.get("failure_message") != \
            "controller r9 changed unapproved module bindings" or \
            failure.get("failure_location", {}).get("function") != \
            "build_controller_r8_r9_authority_progress_delta" or \
            failure.get("protocol_written") is not False or \
            failure.get("dispatch_written") is not False or \
            failure.get("static_qa_written") is not False or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            failure.get("coverage_map") != files["coverage_map"] or \
            failure.get("stdout") != files["stdout"] or \
            failure.get("stderr") != files["stderr"] or \
            failure.get("freezer_source_at_failure", {}).get("sha256") != \
                "4cb636ec1de1160ce1ec15094efb4b1e48ac61a4e2baebb4c78a3fbf9a72b5d5" or \
            files["freeze_failure"].get("path") != (
                "docs/implementation/UP1-04A-VNEXT-T2/archive/"
                "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/"
                "freeze_failure.json") or \
            files["coverage_map"]["sha256"] != \
                "9fb16233ae8c0c4373781450c3f1bffedd3373f4e5a6e44f34f804132f93df41":
        raise RuntimeError("attempt11 initial Python freeze failure is not precisely pinned")
    return {"schema": "vnext-t2-attempt11-initial-freeze-failure-basis-r1",
            "status": "preserved_pre_execution_freezer_failure_only",
            "files": files, "failure": failure,
            "formal_t2_accepted": False}


def build_attempt11_retry1_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, ATTEMPT11_RETRY1_FAILURE)
    failure = load_object(ATTEMPT11_RETRY1_FAILURE)
    preserved_files = failure.get("preserved_retry1_files")
    if not isinstance(preserved_files, dict) or len(preserved_files) != 11:
        raise RuntimeError("attempt11 retry1 failure file inventory is incomplete")
    for relative, expected in preserved_files.items():
        actual = receipt(ROOT / relative)
        if actual != expected:
            raise RuntimeError(f"attempt11 retry1 preserved file drift: {relative}")
        add_input(inputs, ROOT / relative)
    for name in ("protocol", "dispatch", "command_data", "coverage_map"):
        expected = failure.get(name)
        if not isinstance(expected, dict) or \
                preserved_files.get(expected.get("path")) != expected:
            raise RuntimeError(f"attempt11 retry1 failure source pin missing: {name}")
    if failure.get("static_qa_source_at_failure") != {
            "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                    "static_qa_independent_negative_r9.py",
            "bytes": 202670,
            "sha256": "97d723d11fc389cbcbc9551f6cbccb1cc440c9b0cf3ea4327727d0ae7e9b9d88"} or \
            failure.get("controller_source") != receipt(CONTROLLER):
        raise RuntimeError("attempt11 retry1 source-at-failure evidence drift")
    protocol = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "protocol.json")
    dispatch = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "dispatch.json")
    qa = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "static_qa.json")
    projection_phase = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json")
    if failure.get("schema") != \
            "vnext-t2-attempt11-retry1-static-qa-failure-r1" or \
            failure.get("status") != \
            "preserved_static_qa_failure_after_projection_preflight_not_acceptance" or \
            failure.get("freezer_exit_code") != 1 or \
            failure.get("static_qa_exit_code") != 1 or \
            failure.get("failure") != {
                "type": "RuntimeError",
                "message": "controller r8/r9 source binding drift"} or \
            failure.get("expected_projection24_natural_exit_code") != 0 or \
            failure.get("observed_projection24_phase") != {
                "name": "projection24_reuse_python_preflight",
                "status": "pass", "stop_reason": "natural_exit", "exit_code": 0,
                "pass_marker_observed": True,
                "pass_marker": PROJECTION_PASS_MARKER} or \
            failure.get("protocol") != preserved_files.get(
                failure.get("protocol", {}).get("path")) or \
            failure.get("dispatch") != preserved_files.get(
                failure.get("dispatch", {}).get("path")) or \
            failure.get("command_data") != preserved_files.get(
                failure.get("command_data", {}).get("path")) or \
            failure.get("coverage_map") != preserved_files.get(
                failure.get("coverage_map", {}).get("path")) or \
            protocol.get("schema") != "vnext-t2-independent-negative-protocol-r4" or \
            protocol.get("formal_t2_accepted") is not False or \
            protocol.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            dispatch.get("formal_t2_accepted") is not False or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            qa.get("status") != "fail" or qa.get("failure") != \
                failure.get("failure") or \
            projection_phase.get("exit_code") != 0 or \
            projection_phase.get("pass_marker") != PROJECTION_PASS_MARKER or \
            failure.get("freeze_snapshot_written") is not False or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            (ATTEMPT11_RETRY1_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt11 retry1 static QA failure is not precisely pinned")
    return {"schema": "vnext-t2-attempt11-retry1-static-qa-failure-basis-r1",
            "status": "preserved_static_qa_failure_only_no_julia",
            "failure_receipt": receipt(ATTEMPT11_RETRY1_FAILURE),
            "preserved_retry1_files": preserved_files,
            "failure": failure,
            "formal_t2_accepted": False}


def build_attempt11_retry2_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    observed_paths = list(files_under(ATTEMPT11_RETRY2_FAILURE_LEAF))
    observed_relative = {
        path.relative_to(ATTEMPT11_RETRY2_FAILURE_LEAF).as_posix()
        for path in observed_paths}
    if observed_relative != ATTEMPT11_RETRY2_FAILURE_FILES:
        raise RuntimeError("attempt11 retry2 failure artifact inventory drift")
    files = {}
    for path in observed_paths:
        relative = path.relative_to(ROOT).as_posix()
        files[relative] = receipt(path)
        add_input(inputs, path)
    protocol_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "protocol.json"
    dispatch_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "dispatch.json"
    command_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "command_argv.json"
    coverage_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "coverage_map_r8.json"
    qa_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa.json"
    projection_phase_path = ATTEMPT11_RETRY2_FAILURE_LEAF / \
        "projection24_reuse_preflight/phase.json"
    protocol = load_object(protocol_path)
    dispatch = load_object(dispatch_path)
    command = load_object(command_path)
    coverage = load_object(coverage_path)
    qa = load_object(qa_path)
    phase = load_object(projection_phase_path)
    controller_relative = CONTROLLER.relative_to(ROOT).as_posix()
    freezer_relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    qa_relative = STATIC_QA.relative_to(ROOT).as_posix()
    historical_sources = {
        "freezer": protocol.get("inputs", {}).get(freezer_relative),
        "static_qa": protocol.get("inputs", {}).get(qa_relative),
        "controller": protocol.get("inputs", {}).get(controller_relative),
    }
    historical_source_paths = {
        "freezer": freezer_relative, "static_qa": qa_relative,
        "controller": controller_relative,
    }
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r4" or \
            protocol.get("formal_t2_accepted") is not False or \
            protocol.get("controller_path") != controller_relative or \
            protocol.get("coverage_map") != receipt(coverage_path) or \
            protocol.get("input_count") != len(protocol.get("inputs", {})) or \
            protocol.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            protocol.get("python_cache_exclusion", {}).get(
                "qa_dynamic_import_module_names") != [
                    "vnext_t2_controller_r9",
                    "vnext_t2_projection24_reuse_r4"] or \
            not all(isinstance(historical_sources.get(name), dict) and
                    historical_sources[name].get("path") == relative and
                    isinstance(historical_sources[name].get("bytes"), int) and
                    len(historical_sources[name].get("sha256", "")) == 64
                    for name, relative in historical_source_paths.items()) or \
            historical_sources["controller"] != receipt(CONTROLLER) or \
            dispatch.get("protocol") != receipt(protocol_path) or \
            dispatch.get("formal_t2_accepted") is not False or \
            dispatch.get("julia_started") is not False or \
            command.get("argv") != dispatch.get("command_argv") or \
            command.get("julia_started") is not False or \
            coverage.get("schema") != \
                "vnext-t2-independent-negative-coverage-map-r8" or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622 or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            qa.get("status") != "fail" or \
            qa.get("failure") != {
                "type": "RuntimeError",
                "message": "dynamic Python module loader targets are not explicit"} or \
            qa.get("julia_executed") is not False or \
            phase.get("name") != "projection24_reuse_python_preflight" or \
            phase.get("status") != "pass" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 0 or \
            phase.get("pass_marker") != PROJECTION_PASS_MARKER or \
            phase.get("pass_marker_observed") is not True or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "freeze_snapshot.json").exists() or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa_failure.json").exists():
        raise RuntimeError("attempt11 retry2 static QA failure evidence drift")
    failure = {
        "schema": "vnext-t2-attempt11-retry2-static-qa-failure-r1",
        "status": "preserved_static_qa_failure_after_projection_preflight_not_acceptance",
        "freezer_exit_code": 1,
        "freezer_failure": {
            "type": "RuntimeError",
            "message": "r5 Python static QA failed: exit=1"},
        "static_qa_exit_code": 1,
        "static_qa_failure": qa["failure"],
        "historical_source_pins": historical_sources,
        "files": files,
        "projection24_phase": files[
            projection_phase_path.relative_to(ROOT).as_posix()],
        "projection24_exit_code": 0,
        "coverage_map": files[coverage_path.relative_to(ROOT).as_posix()],
        "python_module_binding_at_failure": protocol[
            "python_cache_exclusion"]["qa_dynamic_import_module_names"],
        "expected_controller_module_binding": "vnext_t2_controller_r10",
        "actual_qa_loader_module_binding": "vnext_t2_controller_r10",
        "julia_started": False,
        "planned_execution_directory_absent": not (
            ROOT / protocol["planned_evidence_directory"]).exists(),
        "freeze_snapshot_written": False,
        "formal_t2_accepted": False,
    }
    if failure["planned_execution_directory_absent"] is not True:
        raise RuntimeError("attempt11 retry2 planned execution directory exists")
    return {
        "schema": "vnext-t2-attempt11-retry2-static-qa-failure-basis-r1",
        "status": "preserved_static_qa_failure_only_no_julia",
        "files": files,
        "failure": failure,
        "formal_t2_accepted": False,
    }


def build_attempt9c_interruption_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    receipts = {}
    expected = {
        "archive_protocol": "c8c258a73e824824734578b440906c6db69394c33c78ad216917f70efe3dc708",
        "archive_coverage_map": "59442e71116459b9de143d8edcfe451a6c1fbf8ad09187b89ba5fdd3b1a3af27",
        "pipeline_start": "7099389719d2adafb87a379efbd2efc6568fd85c3f8170f01ced2ba6ca18567e",
        "pipeline_final": "e92131b85b6e595ab9034a38df6100cdb035bd4cf047811074b10ddd3f8cd2f0",
        "baseline_phase": "0e38783819a4385a19701ce30d0ddf56a7e2a01ce0d5cc08016f5eeb0b980c23",
        "baseline_summary": "eeca7d2dd4e882800a589ad07266ae91738c1d9e13f8de5e1910e2f3ab2df0a2",
        "baseline_context": "794ee8232c7f2b67be8de58421d557d133a336396547e215d4e4f7ef5b0f68d1",
        "baseline_authorization": "7f1a78c6b8a2eea7a27d46d619be548379820c2eece28a72ca5c09ad9419e664",
        "authority_phase": "78dc730a1fa9f823ce57d12330e1dfd0a3f0bd6bcc516d6060e90b2149f5115d",
        "authority_stdout": "7688d6dda69029dc0da4059c9529f58b92174bfe3595f90741ab48d28e6ea396",
        "authority_stderr": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "authority_samples": "a091b18fdf1254b11265bdca99d1b4179d4abde4b805089f0a4fe92564909c87",
        "authority_observations": "e6bc7fe03984b2697cbd40af32b826d4a04da1aafd7d2b53e032b72a089e6fb5",
        "authority_transport": "e6f9b52f5f9f3a364dc2064f1cbf8c5b7eedb108754a9c2d32423a68bf9a1dd9",
        "authority_stage_trace": "b6148109e31860c7fabc3c72e26ace2d59476e2560ee5e8061c0ab171eb6baed",
    }
    for name, path in ATTEMPT9C_FAILURE_FILES.items():
        pin = receipt(path)
        if pin["sha256"] != expected[name] or inputs.get(pin["path"]) != pin:
            raise RuntimeError(f"attempt9c interruption pin drift: {name}")
        receipts[name] = pin
    pipeline = load_object(ATTEMPT9C_FAILURE_FILES["pipeline_final"])
    baseline = load_object(ATTEMPT9C_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT9C_FAILURE_FILES["baseline_summary"])
    phase = load_object(ATTEMPT9C_FAILURE_FILES["authority_phase"])
    trace_lines = ATTEMPT9C_FAILURE_FILES["authority_stage_trace"].read_text(
        encoding="utf-8").splitlines()
    stdout_lines = ATTEMPT9C_FAILURE_FILES["authority_stdout"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    observations = [json.loads(line) for line in
        ATTEMPT9C_FAILURE_FILES["authority_observations"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    last_trace = trace_lines[-1] if trace_lines else ""
    last_stdout = next((line.removeprefix("VNEXT_T2_NEGATIVE_STAGE=")
        for line in reversed(stdout_lines)
        if line.startswith("VNEXT_T2_NEGATIVE_STAGE=")), "")
    expected_pre_assertion_observation = {
        "case_id": "PARENT_STALE",
        "status": "fail_closed",
        "resolution": "none",
        "first_reason": "t2_preflight_parent_commitment_mismatch",
        "committed": False,
        "ledger_status": "complete_contract_receipts",
    }
    if baseline.get("stop_reason") != "natural_exit" or baseline.get("exit_code") != 0 or \
            baseline_summary.get("status") != "pass" or \
            phase.get("name") != "actual_formal_authority" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or phase.get("timeout_seconds") != 480.0 or \
            phase.get("seconds") != 480.20754000000306 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_703_682_048 or \
            phase.get("residual_heavy_processes") != [] or \
            pipeline.get("status") != "fail" or \
            pipeline.get("formal_t2_accepted") is not False or \
            pipeline.get("inputs_before") != pipeline.get("inputs_after") or \
            last_trace.split("\t", 1)[0] != "attack_group_authority.begin" or \
            last_stdout != last_trace or \
            len(observations) != 1 or observations[0].get("case_id") != "PARENT_STALE" or \
            observations[0].get("status") != "fail_closed" or \
            observations[0].get("resolution") != "none" or \
            observations[0].get("first_reason") != \
                "t2_preflight_parent_commitment_mismatch" or \
            observations[0].get("committed") is not False or \
            observations[0].get("ledger", {}).get("status") != \
                "complete_contract_receipts":
        raise RuntimeError("attempt9c authority interruption does not match pinned failure")
    missing = [
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/summary.json",
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/case_progress.jsonl",
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/authority_case_aggregate.json",
    ]
    if any(path.exists() for path in missing):
        raise RuntimeError("attempt9c interruption has forbidden completion artifacts")
    return {
        "schema": "vnext-t2-attempt9c-authority-resource-interruption-r1",
        "status": "resource_interruption_incomplete_not_scientific_fail_not_accepted",
        "attempt9c_protocol": receipts["archive_protocol"],
        "attempt9c_coverage_map": receipts["archive_coverage_map"],
        "pipeline_start": receipts["pipeline_start"],
        "pipeline_final": receipts["pipeline_final"],
        "baseline_phase": {"receipt": receipts["baseline_phase"],
            "stop_reason": baseline["stop_reason"], "exit_code": baseline["exit_code"],
            "summary_status": baseline_summary["status"]},
        "authority_phase": {"receipt": receipts["authority_phase"],
            "stop_reason": phase["stop_reason"], "exit_code": phase["exit_code"],
            "elapsed_seconds": phase["seconds"], "timeout_seconds": phase["timeout_seconds"],
            "working_set_limit_bytes": phase["working_set_limit_bytes"],
            "peak_process_tree_working_set_bytes": phase[
                "peak_process_tree_working_set_bytes"],
            "residual_heavy_processes": phase["residual_heavy_processes"]},
        "authority_raw_receipts": {name: receipts[name] for name in
            ("authority_stdout", "authority_stderr", "authority_samples",
             "authority_observations", "authority_transport", "authority_stage_trace")},
        "last_completed_stage_marker": last_trace,
        "last_stdout_stage_marker": last_stdout,
        "pre_assertion_observation_case_ids": [row["case_id"] for row in observations],
        "pre_assertion_observation": expected_pre_assertion_observation,
        "assertion_completion_status": "unknown_no_authority_summary_or_case_progress",
        "authority_completion_artifacts_absent": [p.relative_to(ROOT).as_posix()
            for p in missing],
        "input_pins_unchanged": pipeline["inputs_before"] == pipeline["inputs_after"],
        "formal_t2_accepted": False,
    }


def build_attempt9b_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT9B_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT9B_FAILURE_FILES["protocol"])
    previous_phase = load_object(ATTEMPT9B_FAILURE_FILES["preflight_phase"])
    previous_dispatch = load_object(ATTEMPT9B_FAILURE_FILES["dispatch"])
    previous_command = load_object(ATTEMPT9B_FAILURE_FILES["command"])
    previous_receipt = load_object(
        ATTEMPT9B_FAILURE_FILES["preflight_receipt"])
    qa = load_object(ATTEMPT9B_FAILURE_FILES["static_qa"])
    previous_static_qa = TEST_ROOT / "static_qa_independent_negative_r4b.py"
    previous_static_qa_receipt = receipt(previous_static_qa)
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_started") is True or \
            previous_protocol.get("coverage_map") != frozen_files["coverage_map"] or \
            previous_dispatch.get("julia_started") is not False or \
            previous_command.get("julia_started") is not False or \
            previous_phase.get("name") != \
            "projection24_reuse_python_preflight" or \
            previous_phase.get("status") != "pass" or \
            previous_phase.get("stop_reason") != "natural_exit" or \
            previous_phase.get("exit_code") != 0 or \
            previous_phase.get("julia_started") is not False or \
            previous_phase.get("formal_t2_accepted") is not False or \
            previous_phase.get("command_argv", [None])[2] != str(
                TEST_ROOT / "validate_projection24_reuse_r4.py") or \
            previous_receipt.get("schema") != \
            "vnext-t2-projection24-cross-run-validation-r4" or \
            previous_receipt.get("assertion_sites_completed") != 24 or \
            previous_receipt.get("natural_exit_zero") is not True or \
            previous_receipt.get("post_assertion_pass_marker") is not True or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r4" or \
            qa.get("status") != "fail" or qa.get("failure") != \
            ATTEMPT9B_EXPECTED_QA_FAILURE or \
            qa.get("julia_executed") is not False or \
            previous_protocol.get("inputs", {}).get(
                previous_static_qa_receipt["path"]) != previous_static_qa_receipt or \
            inputs.get(previous_static_qa_receipt["path"]) != \
                previous_static_qa_receipt or \
            "positive_evidence_receipts,\n            controller_source, controls)" not in \
                previous_static_qa.read_text(encoding="utf-8") or \
            (ATTEMPT9B_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt9b static QA failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt9b-static-qa-failure-r1",
        "status": "preserved_static_qa_failure_not_acceptance",
        "files": frozen_files,
        "observed_failure": ATTEMPT9B_EXPECTED_QA_FAILURE,
        "projection_preflight_natural_exit_code": 0,
        "projection_reuse_sites_completed": 24,
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def require_runtime_pins(inputs: dict[str, dict[str, Any]],
                         runtime_inputs: dict[str, Any]) -> dict[str, dict[str, Any]]:
    source = runtime_inputs.get("inputs")
    if not isinstance(source, dict) or runtime_inputs.get("schema") != \
            "vnext-t2-formal-runtime-inputs-r3" or \
            runtime_inputs.get("runtime_dependency_count") != 104 or \
            len(source) != 104:
        raise RuntimeError("positive r3 runtime input inventory is not 104")
    pins: dict[str, dict[str, Any]] = {}
    for relative, raw in sorted(source.items()):
        if not isinstance(raw, dict) or raw.get("path") != relative or \
                not isinstance(raw.get("bytes"), int) or raw["bytes"] < 0 or \
                not isinstance(raw.get("sha256"), str) or \
                len(raw["sha256"]) != 64:
            raise RuntimeError(f"malformed positive r3 input pin: {relative}")
        actual = receipt(ROOT / relative)
        if actual != raw:
            raise RuntimeError(f"positive r3 current input drift: {relative}")
        pins[relative] = dict(raw)
        inputs[relative] = dict(raw)
    return pins


def build_projection24_reuse_plan(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    old_protocol = load_object(R1_SOURCE_PROTOCOL)
    historical_inputs = old_protocol.get("inputs")
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r1" or \
            not isinstance(historical_inputs, dict) or \
            len(historical_inputs) != 157:
        raise RuntimeError("historical r1 protocol input contract is invalid")

    intersection = {
        relative: dict(historical_inputs[relative])
        for relative in sorted(historical_inputs)
        if inputs.get(relative) == historical_inputs[relative]
    }
    exclusions = []
    for relative in sorted(historical_inputs):
        old_pin = historical_inputs[relative]
        current_pin = inputs.get(relative)
        if current_pin == old_pin:
            continue
        exclusions.append({
            "historical_pin": dict(old_pin),
            "classification": (
                "missing_from_current_r3_input_closure"
                if current_pin is None else
                "current_path_bytes_or_sha256_changed"),
            "current_pin": dict(current_pin) if current_pin is not None else None,
        })

    direct_paths = {
        "source_protocol": R1_SOURCE_PROTOCOL,
        "source_pipeline_final": R1_PIPELINE_FINAL,
        "source_timeout_execution_receipt": R1_TIMEOUT_RECEIPT,
    }
    direct_receipts = {name: receipt(path)
                       for name, path in direct_paths.items()}
    phase_receipts = {name: receipt(path) for name, path in
                      sorted(R1_PROJECTION_PHASE_FILES.items())}
    consumed_paths = set(intersection)
    consumed_paths.update(pin["path"] for pin in direct_receipts.values())
    consumed_paths.update(pin["path"] for pin in phase_receipts.values())
    missing_consumed = sorted(path for path in consumed_paths if path not in inputs)
    if missing_consumed:
        raise RuntimeError(
            "projection24 validator dependencies are outside current pins: " +
            ", ".join(missing_consumed))
    dependencies = {path: dict(inputs[path]) for path in sorted(consumed_paths)}
    if any(row != inputs[path] for path, row in dependencies.items()):
        raise RuntimeError("projection24 dependency map differs from current inputs")
    return {
        "schema": "vnext-t2-projection24-cross-run-reuse-r1",
        "status": "frozen_r1_evidence_with_exact_current_join",
        "source_protocol": direct_receipts["source_protocol"],
        "source_pipeline_final": direct_receipts["source_pipeline_final"],
        "source_timeout_execution_receipt":
            direct_receipts["source_timeout_execution_receipt"],
        "phase_files": phase_receipts,
        "source_input_count": len(historical_inputs),
        "r1_input_intersection": intersection,
        "r1_input_intersection_count": len(intersection),
        "excluded_r1_input_rows": exclusions,
        "excluded_r1_input_count": len(exclusions),
        "dependency_subset": dependencies,
        "dependency_subset_count": len(dependencies),
        "dependency_count": len(dependencies),
    }


def build_attempt7_interruption_record() -> dict[str, Any]:
    protocol_path = ATTEMPT7_ARCHIVE_LEAF / "protocol.json"
    pipeline_path = ATTEMPT7_EXECUTION / "pipeline_final.json"
    phase_path = ATTEMPT7_BASELINE / "phase.json"
    stage_trace_path = ATTEMPT7_BASELINE / "artifacts/stage_trace.tsv"
    observation_path = ATTEMPT7_BASELINE / "artifacts/observations.jsonl"
    stdout_path = ATTEMPT7_BASELINE / "stdout.raw"
    stderr_path = ATTEMPT7_BASELINE / "stderr.raw"
    sample_path = ATTEMPT7_BASELINE / "samples.jsonl"
    receipts = {
        "protocol": receipt(protocol_path),
        "pipeline_final": receipt(pipeline_path),
        "coverage_map": receipt(ATTEMPT7_COVERAGE),
        "phase": receipt(phase_path),
        "stage_trace": receipt(stage_trace_path),
        "observations": receipt(observation_path),
        "stdout": receipt(stdout_path),
        "stderr": receipt(stderr_path),
        "samples": receipt(sample_path),
    }
    expected_sha256 = {
        "protocol": "3a792f89ab2e9db3bff408dd0a7da3c5eb564d6807090c8fa0bbfa6004ec5c00",
        "pipeline_final": "99f8c45f176c0cbf0f9cab0d084466e0b800b1ffa8f48cd08ebf24457f99ff13",
        "coverage_map": "4e79435b9842ecd435fadeb50334e1f500e5635d8f9fef760bfc085ef655bd3d",
        "phase": "08b58aff9bf0ff0882c241661d02e1058f0228cf182e3738e75d93d3bd621c30",
        "stage_trace": "d8db64827821d907445a04f8c44cba1d7a4917a435b78c1777d5ffd4bebc5dec",
        "observations": "b2dd75ba13c1d79d707c8e5cd493cd32e82f8e20de53674a5a22a88118adea66",
        "stdout": "26a5c424d0ad4ea9377b1cc4db66009f0a3971c22a1f9e5be9d3e5c5ab2115aa",
        "stderr": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "samples": "9f74adf8431ba3af8cbe4eba6182c16759c040efa3de85d0568504dd14d76c42",
    }
    if any(receipts[name]["sha256"] != sha for name, sha in
           expected_sha256.items()):
        raise RuntimeError("attempt7 immutable interruption evidence drift")
    phase = load_object(phase_path)
    pipeline = load_object(pipeline_path)
    observation_rows = [json.loads(line) for line in
                       observation_path.read_text(encoding="utf-8").splitlines()
                       if line.strip()]
    trace_rows = stage_trace_path.read_text(encoding="utf-8").splitlines()
    last_marker = next((line for line in reversed(trace_rows)
                        if line.startswith("five_consumer_baseline.end\t")), None)
    required_missing = [
        ATTEMPT7_BASELINE / "artifacts/summary.json",
        ATTEMPT7_BASELINE / "artifacts/baseline_context.jls",
        ATTEMPT7_EXECUTION / "actual_formal_baseline_authorization.json",
    ]
    if phase.get("name") != "actual_formal_baseline" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or phase.get("timeout_seconds") != 300.0 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            pipeline.get("status") != "fail" or \
            len(observation_rows) != 1 or \
            observation_rows[0].get("case_id") != "ACTUAL_BASELINE_POSITIVE" or \
            observation_rows[0].get("status") != "complete_contract_receipts" or \
            last_marker is None or \
            "detail=status=complete_contract_receipts" not in last_marker or \
            any(path.exists() for path in required_missing):
        raise RuntimeError("attempt7 interruption state does not match frozen failure")
    return {
        "status": "phase_wall_timeout_incomplete_not_accepted",
        "archive_leaf": ATTEMPT7_ARCHIVE_LEAF.relative_to(ROOT).as_posix(),
        "evidence": receipts,
        "baseline_phase": {
            "name": phase["name"], "stop_reason": phase["stop_reason"],
            "exit_code": phase["exit_code"], "timeout_seconds": phase["timeout_seconds"],
            "elapsed_seconds": phase["seconds"],
            "working_set_limit_bytes": phase["working_set_limit_bytes"],
            "peak_process_tree_working_set_bytes":
                phase["peak_process_tree_working_set_bytes"],
        },
        "last_completed_marker": last_marker,
        "pre_assertion_observation_ids": [
            row["case_id"] for row in observation_rows],
        "pre_assertion_observation_count": len(observation_rows),
        "baseline_completion_artifacts_absent": [
            path.relative_to(ROOT).as_posix() for path in required_missing],
        "formal_t2_accepted": False,
    }


def build_attempt7_relocation_ledger(
        current: dict[str, Any], prior: dict[str, Any],
        current_map_path: Path) -> dict[str, Any]:
    old_sites = {row["id"]: row for row in prior["successor_assertion_sites"]}
    new_sites = {row["id"]: row for row in current["successor_assertion_sites"]}
    if set(old_sites) != set(new_sites) or len(old_sites) != 214:
        raise RuntimeError("attempt7 source relocation requires the exact 214 IDs")
    source_cache: dict[str, list[str]] = {}
    entries = []
    for site_id in sorted(old_sites):
        old, new = old_sites[site_id], new_sites[site_id]
        if any(old[field] != new[field] for field in (
                "macro_name", "source_text", "source_text_sha256",
                "runtime_multiplicity", "expected_phase_hits")):
            raise RuntimeError(f"attempt7 assertion content/hit drift: {site_id}")
        relative = new["path"]
        source_path = ROOT / relative
        if relative not in source_cache:
            source_cache[relative] = source_path.read_text(
                encoding="utf-8").splitlines()
        lines = source_cache[relative]
        if not 1 <= new["line"] <= len(lines):
            raise RuntimeError(f"attempt8 source line is outside file: {site_id}")
        actual_text = assertion_expression(lines, new["line"])
        actual_sha = sha256_bytes(actual_text.encode("utf-8"))
        if actual_text != new["source_text"] or \
                actual_sha != new["source_text_sha256"]:
            raise RuntimeError(f"attempt8 source text/line drift: {site_id}")
        entries.append({
            "id": site_id,
            "attempt7": {"path": old["path"], "line": old["line"]},
            "attempt8": {"path": new["path"], "line": new["line"]},
            "line_delta": new["line"] - old["line"],
            "path_changed": new["path"] != old["path"],
            "source_text": new["source_text"],
            "source_text_sha256": new["source_text_sha256"],
            "source_text_matches_attempt7": True,
            "current_source_line_verified": True,
        })
    return {
        "schema": "vnext-t2-attempt7-attempt8-source-relocation-ledger-r1",
        "status": "semantic_contract_equal_with_each_current_source_line_verified",
        "attempt7_coverage_map": receipt(ATTEMPT7_COVERAGE),
        "attempt8_coverage_map": receipt(current_map_path),
        "site_count": len(entries),
        "path_changed_site_count": sum(row["path_changed"] for row in entries),
        "line_changed_site_count": sum(row["line_delta"] != 0 for row in entries),
        "source_text_match_count": sum(
            row["source_text_matches_attempt7"] for row in entries),
        "current_source_line_verified_count": sum(
            row["current_source_line_verified"] for row in entries),
        "entries": entries,
    }


def run_projection24_preflight(output: Path,
                               protocol_path: Path) -> dict[str, Any]:
    evidence_dir = output / "projection24_reuse_preflight"
    evidence_dir.mkdir()
    receipt_path = evidence_dir / "reuse_receipt.json"
    stdout_path = evidence_dir / "stdout.raw"
    stderr_path = evidence_dir / "stderr.raw"
    phase_path = evidence_dir / "phase.json"
    command = [sys.executable, "-B", str(PROJECTION_REUSE_VALIDATOR),
               str(protocol_path), str(receipt_path)]
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    started = datetime.now(timezone.utc).isoformat()
    start_tick = time.perf_counter()
    try:
        result = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=300, check=False)
        stop_reason = "natural_exit"
        returncode: int | None = result.returncode
        stdout_bytes, stderr_bytes = result.stdout, result.stderr
    except subprocess.TimeoutExpired as error:
        stop_reason = "phase_wall_timeout"
        returncode = None
        stdout_bytes = error.stdout or b""
        stderr_bytes = error.stderr or b""
    elapsed = time.perf_counter() - start_tick
    ended = datetime.now(timezone.utc).isoformat()
    stdout_path.write_bytes(stdout_bytes)
    stderr_path.write_bytes(stderr_bytes)
    phase = {
        "schema": "vnext-t2-projection24-python-preflight-phase-r1",
        "name": "projection24_reuse_python_preflight",
        "status": "pass" if stop_reason == "natural_exit" and
        returncode == 0 else "fail",
        "stop_reason": stop_reason,
        "exit_code": returncode,
        "started_utc": started,
        "ended_utc": ended,
        "elapsed_seconds": elapsed,
        "timeout_seconds": 300,
        "command_argv": command,
        "working_directory": str(ROOT),
        "stdout": receipt(stdout_path),
        "stderr": receipt(stderr_path),
        "receipt": receipt(receipt_path) if receipt_path.is_file() else None,
        "pass_marker": PROJECTION_PASS_MARKER,
        "pass_marker_observed": PROJECTION_PASS_MARKER in
        stdout_bytes.decode("utf-8", errors="replace"),
        "julia_started": False,
        "formal_t2_accepted": False,
    }
    write_json_new(phase_path, phase)
    if returncode != 0 or stop_reason != "natural_exit":
        raise RuntimeError(
            f"projection24 Python preflight did not naturally exit 0: "
            f"{stop_reason} exit={returncode}")
    if PROJECTION_PASS_MARKER not in stdout_bytes.decode(
            "utf-8", errors="replace") or not receipt_path.is_file():
        raise RuntimeError("projection24 Python preflight marker/receipt absent")
    reuse = load_object(receipt_path)
    if reuse.get("status") != "pass" or \
            reuse.get("assertion_sites_completed") != 24 or \
            reuse.get("natural_exit_zero") is not True or \
            reuse.get("post_assertion_pass_marker") is not True:
        raise RuntimeError("projection24 Python preflight receipt is incomplete")
    return receipt(phase_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--positive-dispatch-dir", required=True)
    parser.add_argument("--positive-evidence-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--planned-evidence-dir", required=True)
    parser.add_argument("--julia", required=True)
    parser.add_argument("--coverage-map", default=str(ROOT / ARCHIVE_COVERAGE))
    parser.add_argument("--review-input", action="append", default=[])
    args = parser.parse_args()

    freezer_script = Path(__file__).resolve()
    freezer_argv0 = Path(sys.argv[0]).resolve()
    if __name__ != "__main__" or freezer_argv0 != freezer_script or \
            not sys.dont_write_bytecode:
        raise RuntimeError("freezer must run as a direct -B Python script")

    positive_dispatch = Path(args.positive_dispatch_dir).resolve()
    positive_evidence = Path(args.positive_evidence_dir).resolve()
    julia_executable = Path(args.julia).resolve()
    output = Path(args.output_dir).resolve()
    planned = Path(args.planned_evidence_dir).resolve()
    coverage_path = Path(args.coverage_map).resolve()
    for path in (positive_dispatch, positive_evidence, output, planned,
                 coverage_path):
        path.relative_to(ROOT)
    if output.parent != (ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive").resolve():
        raise RuntimeError("attempt11 freeze output must be a direct archive leaf")
    if not output.is_dir() or not coverage_path.is_file():
        raise FileNotFoundError("archive leaf or frozen r4 coverage map is missing")
    for name in ("protocol.json", "dispatch.json", "command_argv.json", "static_qa.json",
                 "static_qa.stdout.raw", "static_qa.stderr.raw", "freeze_snapshot.json"):
        if (output / name).exists():
            raise FileExistsError(output / name)
    if (output / "projection24_reuse_preflight").exists():
        raise FileExistsError(output / "projection24_reuse_preflight")
    if planned.exists():
        raise RuntimeError("planned T2 execution evidence directory already exists")
    if not julia_executable.is_file():
        raise FileNotFoundError(julia_executable)
    cache_exclusions = generated_python_cache_exclusions()
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout.strip()
    if head != EXPECTED_HEAD:
        raise RuntimeError(f"repository HEAD mismatch: {head}")

    runtime_inputs_path = positive_dispatch / "runtime_inputs.json"
    positive_protocol_path = positive_dispatch / "protocol.json"
    positive_dispatch_path = positive_dispatch / "dispatch.json"
    positive_command_path = positive_dispatch / "command.txt"
    for path in (runtime_inputs_path, positive_protocol_path,
                 positive_dispatch_path, positive_command_path):
        if not path.is_file():
            raise FileNotFoundError(path)
    runtime_inputs = load_object(runtime_inputs_path)
    positive_final_path = positive_evidence / "formal_t2_serial_replay.json"
    positive_pipeline_path = positive_evidence / "pipeline_final.json"
    positive_final = load_object(positive_final_path)
    positive_pipeline = load_object(positive_pipeline_path)
    if positive_final.get("status") != "pass" or \
            positive_final.get("formal_gate_evidence_kind") != "formal_t1_actual" or \
            positive_final.get("formal_gate_verified") is not True or \
            positive_final.get("formal_t2_accepted") is not False or \
            positive_pipeline.get("status") != "pass" or \
            positive_pipeline.get("failure") is not None or \
            positive_pipeline.get("pinned_input_changes") != [] or \
            positive_pipeline.get("residual_heavy_processes") != []:
        raise RuntimeError("positive r3 replay or pipeline is not a bounded clean pass")

    inputs: dict[str, dict[str, Any]] = {}
    positive_pins = require_runtime_pins(inputs, runtime_inputs)
    for path in files_under(positive_dispatch):
        add_input(inputs, path)
    for path in files_under(positive_evidence):
        add_input(inputs, path)
    for path in files_under(R1_FAILURE_EVIDENCE):
        add_input(inputs, path)
    add_input(inputs, R1_TIMEOUT_RECEIPT)
    add_input(inputs, R1_SOURCE_PROTOCOL)
    attempt7_interruption = build_attempt7_interruption_record()
    for path in files_under(ATTEMPT7_ARCHIVE_LEAF):
        add_input(inputs, path)
    add_input(inputs, ATTEMPT7_COVERAGE)
    for path in files_under(ATTEMPT9C_ARCHIVE_LEAF):
        add_input(inputs, path)
    for path in ATTEMPT9C_FAILURE_FILES.values():
        add_input(inputs, path)
    for path in ATTEMPT10_FAILURE_FILES.values():
        add_input(inputs, path)
    for path in files_under(TEST_ROOT):
        if "__pycache__" in path.resolve().relative_to(TEST_ROOT.resolve()).parts:
            continue
        if any(path.is_relative_to(TEST_ROOT / name) for name in
                ("independent_static_r2", "independent_static_r3",
                 "independent_static_r4", "independent_static_r5",
                "independent_static_r6", "independent_static_r7")):
            continue
        if path == HISTORICAL_ATTEMPT3_LAUNCHER.resolve():
            continue
        add_input(inputs, path)
    add_input(inputs, coverage_path)
    for path in (OLD_SUITE, PROJECTION_SUITE, T1_MANIFEST, V3_QUALIFICATION,
                 *ACTIVE_GUIDANCE):
        add_input(inputs, path)
    review_receipts = []
    for raw in args.review_input:
        review_path = Path(raw).resolve()
        review_path.relative_to(ROOT)
        for path in files_under(review_path):
            add_input(inputs, path)
            review_receipts.append(receipt(path))
    attempt8_preflight_failure_basis = \
        build_attempt8_preflight_failure_record(inputs)
    attempt9c_interruption_basis = build_attempt9c_interruption_record(inputs)
    attempt9_projection_preflight_failure_basis = \
        build_attempt9_projection_preflight_failure_record(inputs)
    projection_validator_delta = build_projection_validator_r3_r4_delta(inputs)
    attempt9b_static_qa_failure_basis = \
        build_attempt9b_static_qa_failure_record(inputs)
    controller_binding_delta = build_controller_r8_r9_authority_progress_delta(inputs)

    coverage = load_object(coverage_path)
    if coverage.get("schema") != "vnext-t2-independent-negative-coverage-map-r8" or \
            coverage.get("status") != "static_coverage_map_no_julia" or \
            coverage.get("formal_t2_accepted") is not False or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622:
        raise RuntimeError("coverage map is not a bounded 214/622 static plan")
    attempt10_preflight_interruption_basis = \
        build_attempt10_preflight_interruption_record(inputs, coverage)
    attempt11_initial_freeze_failure_basis = \
        build_attempt11_initial_freeze_failure_record(inputs)
    attempt11_retry1_static_qa_failure_basis = \
        build_attempt11_retry1_static_qa_failure_record(inputs)
    attempt11_retry2_static_qa_failure_basis = \
        build_attempt11_retry2_static_qa_failure_record(inputs)
    controller_r9_r10_preflight_delta =         build_controller_r9_r10_preflight_budget_delta(inputs)
    runtime_plan = coverage["runtime_execution_plan"]
    if len(PHASE_ORDER) != 30 or runtime_plan.get(
            "actual_formal_phase_case_ids") is None:
        raise RuntimeError("r3 phase contract is malformed")
    attempt7_coverage = load_object(ATTEMPT7_COVERAGE)
    case_ids = sorted(row["id"] for row in coverage["successor_cases"])
    site_ids = sorted(row["id"] for row in coverage["successor_assertion_sites"])
    if len(runtime_plan["actual_formal_summary_case_ids"]) != 45 or \
            runtime_plan["expected_unique_case_count"] != 60 or \
            runtime_plan["expected_runtime_case_hit_count"] != 68 or \
            case_ids != sorted(row["id"] for row in
                               attempt7_coverage["successor_cases"]) or \
            site_ids != sorted(row["id"] for row in
                               attempt7_coverage["successor_assertion_sites"]):
        raise RuntimeError("attempt8 formal case/site coverage differs from attempt7")
    relocation_ledger = build_attempt7_relocation_ledger(
        coverage, attempt7_coverage, coverage_path)
    positive_producer = positive_evidence / "producer"
    positive_receipts = {
        "root": positive_evidence.relative_to(ROOT).as_posix(),
        "formal_serial_replay": receipt(positive_final_path),
        "pipeline_final": receipt(positive_pipeline_path),
        "producer_candidate_package": receipt(
            positive_producer / "candidate_package.jls"),
        "producer_candidate_t1_receipt": receipt(
            positive_producer / "candidate_t1_admission_receipt.json"),
        "producer_result": receipt(positive_producer / "t2_result.jls"),
        "producer_run_receipt": receipt(positive_producer / "run_receipt.json"),
        "replay_candidate_package": receipt(
            positive_evidence / "replay/candidate_package.jls"),
        "replay_candidate_t1_receipt": receipt(
            positive_evidence / "replay/candidate_t1_admission_receipt.json"),
        "replay_result": receipt(positive_evidence / "replay/t2_result.jls"),
        "replay_run_receipt": receipt(positive_evidence / "replay/run_receipt.json"),
    }
    candidate_receipt = load_object(
        positive_producer / "candidate_t1_admission_receipt.json")
    parse_julia = sorted(path for path in inputs if path.endswith(".jl"))
    parse_python = sorted(path for path in inputs if path.endswith(".py"))
    guidance_pins = {row["path"]: row for row in
                     (receipt(path) for path in ACTIVE_GUIDANCE)}
    protocol = {
        "schema": "vnext-t2-independent-negative-protocol-r4",
        "status": "frozen_static_ready_not_executed",
        "repository_head": EXPECTED_HEAD,
        "inputs": dict(sorted(inputs.items())),
        "input_count": len(inputs),
        "python_cache_exclusion": {
            "schema": "vnext-t2-generated-python-cache-exclusion-r1",
            "status": "excluded_from_current_input_closure_not_cleaned",
            "cleaned": False,
            "excluded_files": cache_exclusions,
            "excluded_file_count": len(cache_exclusions),
            "exclusion_reason": (
                "these two bytecode files were created by a local Python import "
                "preflight; exact cleanup was rejected by tool safety, so they "
                "remain present and are excluded from execution inputs"),
            "freeze_entrypoint": {
                "mode": "direct_script_as_main",
                "path": freezer_script.relative_to(ROOT).as_posix(),
                "argv0_matches_source": True,
                "sys_dont_write_bytecode": sys.dont_write_bytecode,
            },
            "static_qa_direct_argv_prefix": [
                sys.executable, "-B", str(STATIC_QA)],
            "cache_module_import_targets": [],
            "qa_dynamic_import_module_names": [
                "vnext_t2_controller_r10", "vnext_t2_projection24_reuse_r4"],
        },
        "attempt11_cleanup_receipt": {
            "schema": "vnext-t2-attempt11-owned-temp-cleanup-inventory-r1",
            "status": "pass_no_task_owned_disposable_artifacts",
            "python_commands_used_dash_b": True,
            "task_owned_disposable_paths": [],
            "deleted_paths": [],
            "preserved_preexisting_excluded_cache_files": cache_exclusions,
            "excluded_cache_files_were_cleaned": False,
            "failure_evidence_preserved": True,
            "julia_started": False,
        },
        "excluded_historical_execution_artifacts": [
            receipt(HISTORICAL_ATTEMPT3_LAUNCHER),
        ],
        "historical_execution_artifact_exclusion_reason": (
            "migrated unchanged from attempt3 archive after scope violation; "
            "historical command data, not a current execution dependency"),
        "positive_reuse_input_pins": positive_pins,
        "active_guidance_pins": guidance_pins,
        "julia_parse_paths": parse_julia,
        "julia_parse_file_count": len(parse_julia),
        "python_parse_paths": parse_python,
        "python_parse_file_count": len(parse_python),
        "coverage_map": receipt(coverage_path),
        "coverage_assertion_hit_plan":
            coverage["successor_assertion_runtime_hit_plan"],
        "ast_inventory_plan": coverage["ast_inventory_plan"],
        "versioned_product_repair_regression":
            coverage["versioned_product_repair_regression"],
        "runtime_execution_plan": runtime_plan,
        "projection24_reuse_validator_path":
            PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        "projection24_reuse": build_projection24_reuse_plan(inputs),
        "positive_dispatch": {
            "root": positive_dispatch.relative_to(ROOT).as_posix(),
            "protocol": receipt(positive_protocol_path),
            "runtime_inputs": receipt(runtime_inputs_path),
            "dispatch": receipt(positive_dispatch_path),
            "command": receipt(positive_command_path),
        },
        "positive_evidence": positive_receipts,
        "positive_candidate_driver_version":
            candidate_receipt.get("producer_version"),
        "authorities": {
            "formal_t1_manifest": receipt(T1_MANIFEST),
            "v3_software_qualification": receipt(V3_QUALIFICATION),
        },
        "r1_failure_basis": {
            "formal_negative_pipeline_final": receipt(
                R1_FAILURE_EVIDENCE / "pipeline_final.json"),
            "timeout_execution_receipt": receipt(R1_TIMEOUT_RECEIPT),
            "r1_actual_matrix_exit_code": 15,
            "r1_actual_matrix_stop_reason": "phase_wall_timeout",
            "r1_actual_matrix_wall_seconds": 300.3165626000009,
            "r1_actual_observations_present": False,
            "r1_executed_case_hit_count": 0,
            "r1_projection24_assertion_sites_completed": 24,
        },
        "attempt7_interruption_basis": attempt7_interruption,
        "attempt9c_authority_interruption_basis": attempt9c_interruption_basis,
        "attempt10_preflight_interruption_basis":
            attempt10_preflight_interruption_basis,
        "attempt11_initial_freeze_failure_basis":
            attempt11_initial_freeze_failure_basis,
        "attempt11_retry1_static_qa_failure_basis":
            attempt11_retry1_static_qa_failure_basis,
        "attempt11_retry2_static_qa_failure_basis":
            attempt11_retry2_static_qa_failure_basis,
        "attempt8_preflight_failure_basis": attempt8_preflight_failure_basis,
        "attempt9_projection_preflight_failure_basis":
            attempt9_projection_preflight_failure_basis,
        "attempt9b_static_qa_failure_basis":
            attempt9b_static_qa_failure_basis,
        "projection_validator_r3_r4_delta": projection_validator_delta,
        "controller_r8_r9_authority_progress_delta": controller_binding_delta,
        "controller_r9_r10_preflight_budget_delta":
            controller_r9_r10_preflight_delta,
        "controller_child_script_plan":
            build_controller_child_script_plan(),
        "attempt7_coverage_comparison": {
            "attempt7_coverage_map": receipt(ATTEMPT7_COVERAGE),
            "case_count": len(case_ids), "formal_case_count": 45,
            "runtime_unique_case_count": runtime_plan[
                "expected_unique_case_count"],
            "runtime_case_hit_count": runtime_plan[
                "expected_runtime_case_hit_count"],
            "successor_assertion_site_count":
                coverage["successor_assertion_site_count"],
            "successor_expected_runtime_hit_count":
                coverage["successor_expected_runtime_hit_count"],
            "case_id_set_sha256": sha256_bytes(json.dumps(
                case_ids, separators=(",", ":")).encode("utf-8")),
            "assertion_site_id_set_sha256": sha256_bytes(json.dumps(
                site_ids, separators=(",", ":")).encode("utf-8")),
            "semantic_case_ids_and_site_ids_equal": True,
            "site_assertion_text_multiplicity_and_phase_hits_equal": True,
            "full_path_line_map_byte_equal": False,
            "path_line_relocation_ledger": relocation_ledger,
        },
        "independent_review_inputs": review_receipts,
        "driver_path": DRIVER.relative_to(ROOT).as_posix(),
        "controller_path": CONTROLLER.relative_to(ROOT).as_posix(),
        "phase_order": PHASE_ORDER,
        "expected_phase_count": len(PHASE_ORDER),
        "resource_gates": {
            "phase_wall_seconds": 480,
            "phase_wall_timeout_overrides": {
                "actual_formal_preflight": 600},
            "authority_phase_wall_seconds": 2400,
            "authority_case_wall_seconds": 2400,
            "process_tree_working_set_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
        },
        "julia_executable": str(julia_executable),
        "planned_evidence_directory": planned.relative_to(ROOT).as_posix(),
        "planned_evidence_directory_absent": True,
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
        "actual_source_site_hits": "pending_julia_execution",
        "actual_model_attestation": "unavailable",
        "baseline_diagnostic_marker_contract": [
            "post_consumer_require_baseline.begin",
            "post_consumer_require_baseline.end",
            "baseline_second_up2_validate_input.begin",
            "baseline_second_up2_validate_input.end",
            "baseline_context_construction.begin",
            "baseline_context_construction.end",
            "baseline_context_serialization.begin",
            "baseline_context_serialization.end",
            "baseline_summary_complete",
        ],
        "actual_formal_shard_argv_contract": {
            "schema": "vnext-t2-formal-shard-argv-contract-r1",
            "driver_path": DRIVER.relative_to(ROOT).as_posix(),
            "controller_builder": "build_actual_formal_shard_command",
            "expected_driver_argument_count": 16,
            "coverage_map_path_driver_argv_index_1_based": 15,
            "coverage_map_sha256_driver_argv_index_1_based": 16,
            "shard_modes": ["preflight", "fault_n10", "t1_handoff",
                *["authority-case:" + case_id for case_id in
                  ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE",
                   "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
                   "ACTUAL_TYPED_ABSENCE", "ACTUAL_FORMAL_GATE_REJECTION",
                   "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
                   "ACTUAL_DUPLICATE_INVOCATION"]]],
            "static_actual_command_builder_test": True,
        },
        "authority_case_execution_contract": {
            "schema": "vnext-t2-authority-case-resumable-execution-r2",
            "phase": "actual_formal_authority",
            "case_order": ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE",
                "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
                "ACTUAL_TYPED_ABSENCE", "ACTUAL_FORMAL_GATE_REJECTION",
                "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
                "ACTUAL_DUPLICATE_INVOCATION"],
            "case_mode_template": "authority-case:<case_id>",
            "driver_argument_count": 16,
            "coverage_map_path_argument_index_1_based": 15,
            "coverage_map_sha256_argument_index_1_based": 16,
            "per_case_wall_seconds": 2400,
            "phase_wall_seconds": 2400,
            "effective_child_timeout_policy": "min(per_case_cap, remaining_invocation_budget)",
            "per_assertion_progress_event_schema":
                "vnext-t2-authority-case-progress-r3",
            "per_assertion_events_are_flushed_after_test_record": True,
            "partial_record_event_prefix_is_observational_only": True,
            "resume_skips_only_natural_exit_zero_complete_child_receipts": True,
            "working_set_bytes": 2_147_483_648,
            "source_site_count_zero_filled_per_case": 175,
            "phase_nonzero_site_count": 75,
            "phase_expected_hit_count": 118,
            "expected_case_hit_counts_static_plan": {
                case_id: sum(coverage["successor_assertion_runtime_hit_plan"]
                    ["authority_case_hit_plan"]["case_site_hit_counts"][case_id]
                    .values())
                for case_id in coverage["successor_assertion_runtime_hit_plan"]
                    ["authority_case_hit_plan"]["case_order"]},
            "context_transport_source_site_count": 23,
            "context_transport_site_ids": coverage[
                "successor_assertion_runtime_hit_plan"][
                    "authority_case_hit_plan"]["context_transport_site_ids"],
            "context_transport_formal_phase_order": [
                "actual_formal_preflight", "actual_formal_authority",
                "actual_formal_fault_n10", "actual_formal_t1_handoff"],
            "context_transport_hits_per_site_per_formal_phase_static_plan": 1,
            "context_transport_execution_count_per_formal_phase": 1,
            "context_transport_total_hits_across_four_formal_phases_static_plan": 92,
            "context_transport_case_id": "PARENT_STALE",
            "context_transport_hits_in_authority_case_static_plan": 23,
            "parent_stale_case_total_hits_static_plan": 38,
            "case_site_hits_are_observed_from_test_record": True,
            "partial_or_unterminated_case_receipts_joinable": False,
            "resume_requires_exact_parent_pipeline_phase_and_child_receipt_ancestry": True,
            "partial_case_receipts_joinable": False,
            "resume_policy": "reuse_only_natural_exit_zero_ancestry_and_actual_hit_receipts_with_exact_current_protocol_inputs_and_case_ids",
            "formal_t2_accepted": False,
        },
        "preflight_phase_budget_change": {
            "schema": "vnext-t2-preflight-phase-wall-budget-delta-r1",
            "prior_phase_seconds": 480,
            "current_preflight_seconds": 600,
            "only_phase_override": "actual_formal_preflight",
            "other_formal_phases_seconds": 480,
            "attempt10_observed_complete_cases": 16,
            "attempt10_planned_cases": 18,
            "attempt10_remaining_case_ids": ["FEEDBACK_STALE", "FEEDBACK_FOREIGN"],
            "attempt10_preparation_seconds": 183.662744,
            "attempt10_phase_seconds": 480.170702,
            "estimated_remaining_two_case_seconds_at_observed_average": 37.063495,
            "estimated_extra_wall_margin_after_remaining_cases_seconds": 82.7658,
            "estimate_is_guarantee": False,
            "attempt10_partial_cases_reused": False,
            "failed_attempt11_partial_cases_credit": 0,
            "coverage_thresholds_changed": False,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "formal_t2_accepted": False,
        },
        "authority_case_budget_change": {
            "schema": "vnext-t2-authority-case-budget-delta-r1",
            "prior_case_timeout_seconds": 1200,
            "new_case_timeout_seconds": 2400,
            "authority_invocation_timeout_seconds": 2400,
            "effective_child_timeout_policy": "min(per_case_cap, remaining_invocation_budget)",
            "rationale": "attempt9c did not complete a case before the 480s phase timeout, so the old 1200s per-case cap was not evidence-backed; 2400s lets one case use the full bounded invocation while later cases continue through exact resume",
            "coverage_thresholds_changed": False,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "formal_t2_accepted": False,
        },
    }
    write_json_new(output / "protocol.json", protocol)
    protocol_path = output / "protocol.json"
    protocol_receipt = receipt(protocol_path)
    projection_preflight_phase = run_projection24_preflight(
        output, protocol_path)
    command_argv = [
        sys.executable, "-B", str(CONTROLLER), "--julia", str(julia_executable),
        "--project", str(ROOT), "--protocol", str(protocol_path),
        "--protocol-sha256", protocol_receipt["sha256"],
        "--positive-evidence", str(positive_evidence),
        "--positive-final-sha256",
        positive_receipts["formal_serial_replay"]["sha256"],
        "--positive-pipeline-final-sha256", positive_receipts["pipeline_final"]["sha256"],
        "--evidence-dir", str(planned), "--phase-timeout", "480",
        "--authority-phase-timeout", "2400",
        "--authority-case-timeout", "2400",
        "--working-set-limit", "2147483648",
    ]
    command_path = output / "command_argv.json"
    write_json_new(command_path, {
        "schema": "vnext-t2-independent-negative-command-argv-r6",
        "kind": "non_executable_command_data",
        "working_directory": str(ROOT),
        "argv": command_argv,
        "environment": {"PYTHONDONTWRITEBYTECODE": "1",
                        "JULIA_NUM_THREADS": "1",
                        "OPENBLAS_NUM_THREADS": "1"},
        "julia_started": False,
        "formal_t2_accepted": False,
    })
    dispatch = {
        "schema": "vnext-t2-independent-negative-dispatch-r6",
        "status": "frozen_static_ready_not_executed",
        "repository_head": EXPECTED_HEAD,
        "protocol": protocol_receipt,
        "command": receipt(command_path),
        "command_argv": command_argv,
        "environment": {"PYTHONDONTWRITEBYTECODE": "1",
                        "JULIA_NUM_THREADS": "1",
                        "OPENBLAS_NUM_THREADS": "1"},
        "positive_evidence": positive_receipts,
        "projection24_reuse_preflight": projection_preflight_phase,
        "attempt9b_static_qa_failure_basis":
            attempt9b_static_qa_failure_basis,
        "phase_order": PHASE_ORDER,
        "phase_count": len(PHASE_ORDER),
        "resource_gates": protocol["resource_gates"],
        "expected_unique_case_count": runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count": runtime_plan[
            "expected_runtime_case_hit_count"],
        "planned_evidence_directory": planned.relative_to(ROOT).as_posix(),
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
        "julia_lane_granted": False,
        "julia_started": False,
        "actual_source_site_hits": "pending_julia_execution",
        "actual_model_attestation": "unavailable",
    }
    dispatch_path = output / "dispatch.json"
    write_json_new(dispatch_path, dispatch)

    static_report_path = output / "static_qa.json"
    static_command = [
        sys.executable, "-B", str(STATIC_QA), "--protocol", str(protocol_path),
        "--protocol-sha256", protocol_receipt["sha256"],
        "--dispatch", str(dispatch_path), "--command", str(command_path),
        "--report", str(static_report_path),
    ]
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(static_command, cwd=ROOT, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (output / "static_qa.stdout.raw").write_bytes(result.stdout)
    (output / "static_qa.stderr.raw").write_bytes(result.stderr)
    if result.returncode != 0:
        raise RuntimeError(f"r5 Python static QA failed: exit={result.returncode}")
    cache_exclusions_after_qa = generated_python_cache_exclusions()
    if cache_exclusions_after_qa != cache_exclusions:
        raise RuntimeError("Python cache exclusion inventory changed during QA")
    snapshot = {
        "schema": "vnext-t2-independent-negative-freeze-snapshot-r5",
        "status": "pass", "repository_head": EXPECTED_HEAD,
        "protocol": protocol_receipt,
        "dispatch": receipt(dispatch_path), "command": receipt(command_path),
        "static_qa": receipt(static_report_path),
        "static_qa_stdout": receipt(output / "static_qa.stdout.raw"),
        "static_qa_stderr": receipt(output / "static_qa.stderr.raw"),
        "projection24_reuse_preflight": projection_preflight_phase,
        "projection24_reuse_receipt": receipt(
            output / "projection24_reuse_preflight/reuse_receipt.json"),
        "projection24_reuse_stdout": receipt(
            output / "projection24_reuse_preflight/stdout.raw"),
        "projection24_reuse_stderr": receipt(
            output / "projection24_reuse_preflight/stderr.raw"),
        "coverage_map": receipt(coverage_path),
        "positive_evidence": positive_receipts,
        "python_cache_exclusion": {
            "status": "excluded_not_cleaned_and_stable_across_qa",
            "cleaned": False,
            "before_qa": cache_exclusions,
            "after_qa": cache_exclusions_after_qa,
        },
        "input_count": len(inputs),
        "projection24_r1_input_intersection_count":
            protocol["projection24_reuse"]["r1_input_intersection_count"],
        "projection24_excluded_r1_input_count":
            protocol["projection24_reuse"]["excluded_r1_input_count"],
        "projection24_dependency_subset_count":
            protocol["projection24_reuse"]["dependency_subset_count"],
        "positive_r3_input_pin_count": len(positive_pins),
        "julia_parse_file_count_not_executed": len(parse_julia),
        "python_parse_file_count": len(parse_python),
        "expected_phase_count": len(PHASE_ORDER),
        "expected_unique_case_count": runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count":
            runtime_plan["expected_runtime_case_hit_count"],
        "successor_assertion_site_count_static_plan": 214,
        "successor_runtime_hit_count_static_plan": 622,
        "formal_t2_accepted": False,
        "julia_started": False,
        "actual_model_attestation": "unavailable",
    }
    write_json_new(output / "freeze_snapshot.json", snapshot)
    print(json.dumps({
        "status": "pass", "protocol": protocol_receipt,
        "coverage_map": receipt(coverage_path),
        "static_qa": receipt(static_report_path),
        "input_count": len(inputs),
        "positive_r3_input_pin_count": len(positive_pins),
        "phase_count": len(PHASE_ORDER),
        "julia_started": False, "formal_t2_accepted": False,
    }, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
