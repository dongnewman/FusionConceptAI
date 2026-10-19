from __future__ import annotations

import argparse
import ast
import copy
import difflib
import hashlib
import importlib.util
import json
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
HISTORICAL_ATTEMPT3_LAUNCHER = TEST_ROOT / "frozen_launcher_attempt3.ps1"
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r4.py"
ACTUAL_FORMAL_DRIVER = TEST_ROOT / "actual_formal_negative_driver_r6.jl"
ATTEMPT7_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt7")
ATTEMPT7_EXECUTION = ATTEMPT7_ARCHIVE_LEAF / "actual_negative_execution_r2"
ATTEMPT7_BASELINE = ATTEMPT7_EXECUTION / "actual_formal_baseline"
ATTEMPT7_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
T2_EVIDENCE_ROOT = ROOT / "docs/implementation/UP1-04A-VNEXT-T2"
ATTEMPT10_EXECUTION = T2_EVIDENCE_ROOT / (
    "formal_t2_actual_negative_r5_attempt10_case_progress")
ATTEMPT10_ARCHIVE_LEAF = T2_EVIDENCE_ROOT / (
    "archive/r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress")
ATTEMPT10_RELATIVE_FAILURE_FILES = {
    "attempt10_protocol": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress/protocol.json",
    "attempt10_coverage_map": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress/coverage_map_r7.json",
    "pipeline_start": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/pipeline_start.json",
    "pipeline_final": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/pipeline_final.json",
    "baseline_phase": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_baseline/phase.json",
    "baseline_summary": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_baseline/artifacts/summary.json",
    "preflight_phase": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/phase.json",
    "preflight_stdout": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/stdout.raw",
    "preflight_stderr": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/stderr.raw",
    "preflight_samples": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/samples.jsonl",
    "preflight_observations": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/artifacts/observations.jsonl",
    "preflight_stage_trace": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/artifacts/stage_trace.tsv",
    "preflight_transport_observation": "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r5_attempt10_case_progress/actual_formal_preflight/artifacts/context_transport_observation.json",
}
ATTEMPT10_LINEAGE_SHA256 = {
    "root_observation": "6711e3cdd06faf20180651b1ec678f57409b728dc44dd3373657bb21c29c69e3",
    "root_decision": "1aa6725c461350b30cf287e38bafb913ee80faca3d0ee6cea04e5549a0c2b35b",
    "independent_review": "d800a165ecf9386f8d32ce1ed32193a6d8df18b6855f90a9f7a1289e2ac19892",
    "independent_tester_review": "3a3d28f4c7c0eba74d12a4dca9ac06e0cbf95c09797e64a4d5e4a42e80b5429d",
}
ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF = T2_EVIDENCE_ROOT / (
    "archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s")
ATTEMPT11_INITIAL_FREEZE_FAILURE_RELATIVE_FILES = {
    "freeze_failure": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/freeze_failure.json",
    "stdout": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/freezer.stdout.raw",
    "stderr": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/freezer.stderr.raw",
    "coverage_map": "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/coverage_map_r8.json",
}
ATTEMPT11_RETRY1_FAILURE_LEAF = T2_EVIDENCE_ROOT / (
    "archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1")
ATTEMPT11_RETRY1_FAILURE_RELATIVE = (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1/"
    "static_qa_failure.json")
ATTEMPT11_RETRY2_FAILURE_LEAF = T2_EVIDENCE_ROOT / (
    "archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry2")
ATTEMPT11_RETRY2_FAILURE_FILES = {
    "command_argv.json", "coverage_map_r8.json", "dispatch.json",
    "protocol.json", "static_qa.json", "static_qa.stderr.raw",
    "static_qa.stdout.raw",
    "projection24_reuse_preflight/phase.json",
    "projection24_reuse_preflight/reuse_receipt.json",
    "projection24_reuse_preflight/stderr.raw",
    "projection24_reuse_preflight/stdout.raw",
}
ATTEMPT9C_TRANSPORT = T2_EVIDENCE_ROOT / (
    "formal_t2_actual_negative_r4_attempt9c_final/"
    "actual_formal_authority/artifacts/context_transport_observation.json")
ATTEMPT9B_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9b")
ATTEMPT9B_EXPECTED_QA_FAILURE = {
    "type": "KeyError", "message": "'manifest_path'",
}
ATTEMPT9B_FAILURE_RELATIVE_PATHS = {
    "protocol": "protocol.json",
    "coverage_map": "coverage_map_r3.json",
    "dispatch": "dispatch.json",
    "command": "command_argv.json",
    "preflight_phase": "projection24_reuse_preflight/phase.json",
    "preflight_receipt": "projection24_reuse_preflight/reuse_receipt.json",
    "preflight_stdout": "projection24_reuse_preflight/stdout.raw",
    "preflight_stderr": "projection24_reuse_preflight/stderr.raw",
    "static_qa": "static_qa.json",
    "static_qa_stdout": "static_qa.stdout.raw",
    "static_qa_stderr": "static_qa.stderr.raw",
}
ACTIVE_GUIDANCE = (
    "docs/v4_multitopology_generation/README.md",
    "docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md",
    "docs/v4_multitopology_generation/10_genome_upgrade_execution.md",
    "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/v4_multitopology_generation/21_next_execution_batches.md",
    "docs/v4_multitopology_generation/22_agent_local_execution.md",
    "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md",
    "docs/v4_multitopology_generation/task_manifest.json",
)
EXPECTED_GENERATED_CACHE = [
    {"path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
             "__pycache__/freeze_independent_negative_protocol_r3.cpython-313.pyc",
     "bytes": 48089,
     "sha256": "ebc3c1cfc31b7acf306d5f9addfaff5e45ca4a6772877585148a7df57d897608"},
    {"path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
             "__pycache__/static_qa_independent_negative_r3.cpython-313.pyc",
     "bytes": 72660,
     "sha256": "30cf8b444ec15c98e018a8cfb261e650acc61cf431e83ef65d59535cc5e51e4b"},
]
EXPECTED_CONTROLLER_PHASES = [
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


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.resolve().relative_to(ROOT).as_posix(),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def expect_reject(name: str, operation: Callable[[], Any],
                  controls: list[dict[str, str]]) -> None:
    try:
        operation()
    except Exception as error:
        controls.append({"name": name, "status": "pass",
                         "observed": f"rejected:{type(error).__name__}"})
        return
    raise RuntimeError(f"negative control unexpectedly accepted: {name}")


def load_controller(path: Path) -> Any:
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("vnext_t2_controller_r10", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import r4 controller")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_projection_validator(path: Path) -> Any:
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location(
        "vnext_t2_projection24_reuse_r4", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot import r4 projection reuse validator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def synthetic_site_summaries(coverage: dict[str, Any],
                             map_sha256: str) -> list[dict[str, Any]]:
    hit_plan = coverage["successor_assertion_runtime_hit_plan"]
    result = []
    for phase in hit_plan["phase_order"]:
        expected = hit_plan["phase_site_hit_counts"][phase]
        paths = {row["path"] for row in coverage["successor_assertion_sites"]
                 if phase in row["expected_phase_hits"]}
        require(len(paths) == 1, f"phase source path is ambiguous: {phase}")
        path = next(iter(paths))
        source_receipts = [row for row in coverage["ast_inventory_plan"]["sources"]
                           if row["path"] == path]
        require(len(source_receipts) == 1,
                f"source receipt is missing or duplicate: {path}")
        site_ids = [row["id"] for row in coverage["successor_assertion_sites"]
                    if row["path"] == path]
        counts = {site_id: int(expected.get(site_id, 0))
                  for site_id in site_ids}
        result.append({
            "assertion_site_hit_receipt_schema":
                "vnext-t2-source-site-hit-receipt-r1",
            "assertion_site_hit_phase": phase,
            "assertion_site_hit_source_path": path,
            "assertion_site_hit_source_sha256": source_receipts[0]["sha256"],
            "assertion_site_hit_coverage_map_sha256": map_sha256,
            "assertion_site_hit_count_observed": sum(counts.values()),
            "assertion_site_hit_counts": counts,
            "unmapped_assertion_sources": [],
        })
    return result


def verify_attempt7_coverage_equivalence(
        current: dict[str, Any], prior: dict[str, Any]) -> None:
    if prior.get("schema") != "vnext-t2-independent-negative-coverage-map-r2":
        raise RuntimeError("attempt7 reference coverage map schema mismatch")
    site_fields = ("id", "macro_name", "source_text", "source_text_sha256",
                   "runtime_multiplicity", "expected_phase_hits")
    current_sites = [{key: row[key] for key in site_fields}
                     for row in current["successor_assertion_sites"]]
    prior_sites = [{key: row[key] for key in site_fields}
                   for row in prior["successor_assertion_sites"]]
    if current_sites != prior_sites:
        raise RuntimeError("attempt8 successor assertion IDs/content/hits differ from attempt7")
    current_cases = {row["id"]: row for row in current["successor_cases"]}
    prior_cases = {row["id"]: row for row in prior["successor_cases"]}
    if current_cases != prior_cases:
        raise RuntimeError("attempt8 semantic case IDs/contracts differ from attempt7")
    for field in ("successor_case_assertion_ids", "runtime_execution_plan"):
        if current[field] != prior[field]:
            raise RuntimeError(f"attempt8 {field} differs from attempt7")
    current_plan = copy.deepcopy(current["successor_assertion_runtime_hit_plan"])
    prior_plan = copy.deepcopy(prior["successor_assertion_runtime_hit_plan"])
    for plan in (current_plan, prior_plan):
        plan.pop("schema", None)
        plan["old_focused_suite_mapping"].pop("status", None)
        plan["projection24_mapping"].pop("status", None)
    # The new authority-case receipt plan is additive metadata. Its IDs/hits
    # are verified separately from the unchanged attempt7 phase/site plan.
    current_plan.pop("authority_case_hit_plan", None)
    if current_plan != prior_plan:
        raise RuntimeError("attempt8 assertion-site phase/count plan differs from attempt7")
    runtime = current["runtime_execution_plan"]
    if len(runtime["actual_formal_summary_case_ids"]) != 45 or \
            runtime["expected_unique_case_count"] != 60 or \
            runtime["expected_runtime_case_hit_count"] != 68 or \
            current["successor_assertion_site_count"] != 214 or \
            current["successor_expected_runtime_hit_count"] != 622:
        raise RuntimeError("attempt8 formal/runtime/site coverage counts changed")


def verify_attempt7_relocation_ledger(
        protocol: dict[str, Any], current: dict[str, Any],
        prior: dict[str, Any]) -> dict[str, int]:
    comparison = protocol.get("attempt7_coverage_comparison")
    ledger = comparison.get("path_line_relocation_ledger") \
        if isinstance(comparison, dict) else None
    if not isinstance(ledger, dict) or ledger.get("schema") != \
            "vnext-t2-attempt7-attempt8-source-relocation-ledger-r1" or \
            ledger.get("status") != \
            "semantic_contract_equal_with_each_current_source_line_verified":
        raise RuntimeError("attempt7 source relocation ledger is missing")
    if ledger.get("attempt7_coverage_map") != file_receipt(ATTEMPT7_COVERAGE) or \
            ledger.get("attempt8_coverage_map") != file_receipt(
                ROOT / protocol["coverage_map"]["path"]):
        raise RuntimeError("relocation ledger coverage-map pin mismatch")
    old_sites = {row["id"]: row for row in prior["successor_assertion_sites"]}
    new_sites = {row["id"]: row for row in current["successor_assertion_sites"]}
    entries = ledger.get("entries")
    if set(old_sites) != set(new_sites) or not isinstance(entries, list) or \
            len(entries) != 214:
        raise RuntimeError("relocation ledger site inventory mismatch")
    source_cache: dict[str, list[str]] = {}
    path_changes = line_changes = text_matches = verified_lines = 0
    expected_entries = []
    for site_id in sorted(old_sites):
        old, new = old_sites[site_id], new_sites[site_id]
        if any(old[field] != new[field] for field in (
                "macro_name", "source_text", "source_text_sha256",
                "runtime_multiplicity", "expected_phase_hits")):
            raise RuntimeError(f"relocation content changed from attempt7: {site_id}")
        relative = new["path"]
        if relative not in protocol["inputs"]:
            raise RuntimeError(f"relocation source is outside protocol pins: {relative}")
        path = ROOT / relative
        if relative not in source_cache:
            source_cache[relative] = path.read_text(encoding="utf-8").splitlines()
        lines = source_cache[relative]
        if not isinstance(new["line"], int) or not 1 <= new["line"] <= len(lines):
            raise RuntimeError(f"relocated source line is invalid: {site_id}")
        source_line = lines[new["line"] - 1]
        stripped = source_line.lstrip()
        indent = len(source_line) - len(stripped)
        pieces = [stripped]
        cursor = new["line"]
        while cursor < len(lines):
            candidate = lines[cursor]
            candidate_stripped = candidate.lstrip()
            candidate_indent = len(candidate) - len(candidate_stripped)
            if not candidate_stripped or candidate_stripped.startswith("#") or \
                    candidate_indent <= indent:
                break
            pieces.append(candidate_stripped)
            cursor += 1
        source_text = " ".join(piece.strip() for piece in pieces)
        source_hash = hashlib.sha256(source_text.encode("utf-8")).hexdigest()
        if source_text != new["source_text"] or \
                source_hash != new["source_text_sha256"] or \
                not source_text.startswith(("@test ", "@test_throws ")):
            raise RuntimeError(f"relocated source line text/hash mismatch: {site_id}")
        row = {
            "id": site_id,
            "attempt7": {"path": old["path"], "line": old["line"]},
            "attempt8": {"path": new["path"], "line": new["line"]},
            "line_delta": new["line"] - old["line"],
            "path_changed": new["path"] != old["path"],
            "source_text": new["source_text"],
            "source_text_sha256": new["source_text_sha256"],
            "source_text_matches_attempt7": True,
            "current_source_line_verified": True,
        }
        expected_entries.append(row)
        path_changes += row["path_changed"]
        line_changes += row["line_delta"] != 0
        text_matches += 1
        verified_lines += 1
    if entries != expected_entries or \
            ledger.get("site_count") != len(expected_entries) or \
            ledger.get("path_changed_site_count") != path_changes or \
            ledger.get("line_changed_site_count") != line_changes or \
            ledger.get("source_text_match_count") != text_matches or \
            ledger.get("current_source_line_verified_count") != verified_lines:
        raise RuntimeError("relocation ledger rows/counts differ from pinned source map")
    return {"site_count": len(expected_entries),
            "path_changed_site_count": path_changes,
            "line_changed_site_count": line_changes,
            "source_text_match_count": text_matches,
            "current_source_line_verified_count": verified_lines}


def verify_attempt7_interruption(protocol: dict[str, Any]) -> None:
    record = protocol.get("attempt7_interruption_basis")
    if not isinstance(record, dict) or \
            record.get("status") != "phase_wall_timeout_incomplete_not_accepted" or \
            record.get("archive_leaf") != ATTEMPT7_ARCHIVE_LEAF.relative_to(ROOT).as_posix():
        raise RuntimeError("attempt7 interruption basis missing or reclassified")
    expected_hashes = {
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
    evidence = record.get("evidence")
    if not isinstance(evidence, dict) or set(evidence) != set(expected_hashes):
        raise RuntimeError("attempt7 evidence receipt inventory mismatch")
    for name, expected_sha in expected_hashes.items():
        pin = evidence[name]
        if not isinstance(pin, dict) or file_receipt(ROOT / pin["path"]) != pin or \
                pin["sha256"] != expected_sha or \
                protocol["inputs"].get(pin["path"]) != pin:
            raise RuntimeError(f"attempt7 immutable evidence pin mismatch: {name}")
    for path in sorted(item for item in ATTEMPT7_ARCHIVE_LEAF.rglob("*")
                        if item.is_file()):
        relative = path.resolve().relative_to(ROOT).as_posix()
        if relative not in protocol["inputs"] or \
                file_receipt(path) != protocol["inputs"][relative]:
            raise RuntimeError(f"attempt7 archive input is not frozen: {relative}")
    phase = load_object(ATTEMPT7_BASELINE / "phase.json")
    pipeline = load_object(ATTEMPT7_EXECUTION / "pipeline_final.json")
    prior_protocol = load_object(ATTEMPT7_ARCHIVE_LEAF / "protocol.json")
    observations = [json.loads(line) for line in
                    (ATTEMPT7_BASELINE / "artifacts/observations.jsonl")
                    .read_text(encoding="utf-8").splitlines() if line.strip()]
    trace_lines = (ATTEMPT7_BASELINE / "artifacts/stage_trace.tsv")\
        .read_text(encoding="utf-8").splitlines()
    marker = next((line for line in reversed(trace_lines)
                   if line.startswith("five_consumer_baseline.end\t")), None)
    missing = [ATTEMPT7_BASELINE / "artifacts/summary.json",
               ATTEMPT7_BASELINE / "artifacts/baseline_context.jls",
               ATTEMPT7_EXECUTION / "actual_formal_baseline_authorization.json"]
    phase_record = record.get("baseline_phase", {})
    if phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or phase.get("timeout_seconds") != 300.0 or \
            phase_record.get("elapsed_seconds") != phase.get("seconds") or \
            protocol.get("phase_order") != prior_protocol.get("phase_order") or \
            len(protocol.get("phase_order", [])) != 30 or \
            protocol.get("resource_gates", {}).get(
                "process_tree_working_set_bytes") != \
                prior_protocol.get("resource_gates", {}).get(
                    "process_tree_working_set_bytes") or \
            protocol.get("resource_gates", {}).get("julia_threads") != \
                prior_protocol.get("resource_gates", {}).get("julia_threads") or \
            protocol.get("resource_gates", {}).get("openblas_threads") != \
                prior_protocol.get("resource_gates", {}).get("openblas_threads") or \
            record.get("last_completed_marker") != marker or \
            not marker or "detail=status=complete_contract_receipts" not in marker or \
            pipeline.get("status") != "fail" or \
            [row.get("case_id") for row in observations] != [
                "ACTUAL_BASELINE_POSITIVE"] or \
            record.get("pre_assertion_observation_ids") != [
                "ACTUAL_BASELINE_POSITIVE"] or \
            record.get("pre_assertion_observation_count") != 1 or \
            any(path.exists() for path in missing) or \
            record.get("baseline_completion_artifacts_absent") != [
                path.relative_to(ROOT).as_posix() for path in missing] or \
            record.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt7 timeout/partial observation evidence mismatch")


def verify_attempt11_source_timeout_contract(
        controller_source: str) -> dict[str, Any]:
    tree = ast.parse(controller_source)
    assignments = {}
    functions = {}
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                isinstance(node.targets[0], ast.Name):
            assignments[node.targets[0].id] = node.value
        elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            functions[node.name] = node
    cap = assignments.get("PREFLIGHT_PHASE_TIMEOUT_SECONDS")
    if not isinstance(cap, ast.Constant) or cap.value != 600:
        raise RuntimeError("preflight timeout constant is not 600 seconds")
    helper = functions.get("actual_formal_shard_timeout")
    if helper is None:
        raise RuntimeError("preflight timeout selector helper is missing")
    helper_returns = []
    for node in ast.walk(helper):
        if isinstance(node, ast.Return):
            helper_returns.append(node.value)
    if not helper_returns or not any(
            isinstance(value, ast.Name) and
            value.id == "PREFLIGHT_PHASE_TIMEOUT_SECONDS"
            for value in helper_returns):
        raise RuntimeError("preflight selector does not return its dedicated cap")
    main_fn = functions.get("main")
    if main_fn is None:
        raise RuntimeError("controller main is missing")
    uses_override = False
    for node in ast.walk(main_fn):
        if not isinstance(node, ast.Call) or \
                not isinstance(node.func, ast.Name) or node.func.id != "run_phase":
            continue
        timeout = next((keyword.value for keyword in node.keywords
                        if keyword.arg == "timeout_seconds"), None)
        if not isinstance(timeout, ast.Call) or \
                not isinstance(timeout.func, ast.Name) or \
                timeout.func.id != "actual_formal_shard_timeout" or \
                len(timeout.args) != 2 or \
                not isinstance(timeout.args[0], ast.Name) or \
                timeout.args[0].id != "mode" or \
                not isinstance(timeout.args[1], ast.Attribute) or \
                timeout.args[1].attr != "phase_timeout":
            continue
        uses_override = True
    if not uses_override:
        raise RuntimeError("formal shard run_phase does not use the preflight-only selector")
    if 'mode == "preflight"' not in ast.get_source_segment(
            controller_source, helper) or \
            'return configured_default' not in ast.get_source_segment(
                controller_source, helper):
        raise RuntimeError("timeout selector is not fail-closed to the preflight mode")
    return {"status": "pass", "preflight_cap_seconds": 600,
            "all_other_formal_shards_use_base_cap": True,
            "selection_is_on_actual_run_path": True}


def verify_attempt10_preflight_interruption_basis(
        protocol: dict[str, Any], coverage: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt10_preflight_interruption_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt10-preflight-wall-interruption-r1" or \
            basis.get("status") != \
            "preserved_resource_interruption_partial_not_scientific_failure" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt10 partial preflight basis is absent or overclaims")
    files = basis.get("files")
    if not isinstance(files, dict) or set(files) != \
            set(ATTEMPT10_RELATIVE_FAILURE_FILES):
        raise RuntimeError("attempt10 preflight receipt inventory is incomplete")
    for name, relative in ATTEMPT10_RELATIVE_FAILURE_FILES.items():
        expected = files[name]
        actual = file_receipt(ROOT / relative)
        if expected != actual or expected.get("path") != relative or \
                protocol.get("inputs", {}).get(relative) != expected:
            raise RuntimeError(f"attempt10 interruption input drift: {name}")
    lineage = basis.get("parent_decision_and_independent_reviews")
    if not isinstance(lineage, dict) or set(lineage) != \
            set(ATTEMPT10_LINEAGE_SHA256):
        raise RuntimeError("attempt10 parent/reviewer lineage set is incomplete")
    for name, expected_sha256 in ATTEMPT10_LINEAGE_SHA256.items():
        expected = lineage[name]
        actual = file_receipt(ROOT / expected.get("path", ""))
        if expected != actual or expected.get("sha256") != expected_sha256 or \
                protocol.get("inputs", {}).get(expected["path"]) != expected:
            raise RuntimeError(f"attempt10 root/reviewer lineage drift: {name}")
    old_protocol = load_object(ROOT / files["attempt10_protocol"]["path"])
    old_coverage = load_object(ROOT / files["attempt10_coverage_map"]["path"])
    pipeline = load_object(ROOT / files["pipeline_final"]["path"])
    baseline = load_object(ROOT / files["baseline_phase"]["path"])
    baseline_summary = load_object(ROOT / files["baseline_summary"]["path"])
    phase = load_object(ROOT / files["preflight_phase"]["path"])
    observations_path = ROOT / files["preflight_observations"]["path"]
    observations = [json.loads(line) for line in observations_path.read_text(
        encoding="utf-8").splitlines() if line.strip()]
    stdout_path = ROOT / files["preflight_stdout"]["path"]
    marker = "VNEXT_T2_NEGATIVE_ACTUAL="
    actual_rows = [json.loads(line[len(marker):]) for line in
        stdout_path.read_text(encoding="utf-8", errors="replace").splitlines()
        if line.startswith(marker)]
    expected_cases = coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    old_cases = old_coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    sample_rows = [json.loads(line) for line in
        (ROOT / files["preflight_samples"]["path"]).read_text(
            encoding="utf-8").splitlines() if line.strip()]
    peak = max((row.get("process_tree_working_set_bytes", 0)
                for row in sample_rows), default=0)
    observed_ids = [row.get("case_id") for row in observations]
    marker_ids = [row.get("case_id") for row in actual_rows]
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            old_protocol.get("formal_t2_accepted") is not False or \
            old_coverage.get("schema") != \
            "vnext-t2-independent-negative-coverage-map-r7" or \
            old_coverage.get("successor_assertion_site_count") != 214 or \
            old_coverage.get("successor_expected_runtime_hit_count") != 622 or \
            old_cases != expected_cases or len(expected_cases) != 18 or \
            baseline.get("name") != "actual_formal_baseline" or \
            baseline.get("stop_reason") != "natural_exit" or \
            baseline.get("exit_code") != 0 or \
            baseline.get("working_set_limit_bytes") != 2_147_483_648 or \
            baseline.get("peak_process_tree_working_set_bytes") != 1_669_619_712 or \
            baseline_summary.get("status") != "pass" or \
            baseline_summary.get("assertion_site_hit_count_observed") != 53 or \
            phase.get("name") != "actual_formal_preflight" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or \
            phase.get("timeout_seconds") != 480.0 or \
            abs(phase.get("seconds", 0) - 480.1707022000046) > 0.01 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_754_058_752 or \
            peak != 1_754_058_752 or len(sample_rows) != 2031 or \
            observed_ids != expected_cases[:16] or marker_ids != observed_ids or \
            observed_ids[-1:] != ["CHILD_FOREIGN"] or \
            expected_cases[16:] != ["FEEDBACK_STALE", "FEEDBACK_FOREIGN"] or \
            pipeline.get("status") != "fail" or \
            pipeline.get("failure", {}).get("message") != \
                "actual_formal_preflight stop=phase_wall_timeout" or \
            pipeline.get("assertion_site_hit_aggregate") is not None or \
            pipeline.get("assertion_site_hit_count_observed") is not None or \
            pipeline.get("formal_t2_accepted") is not False or \
            (ATTEMPT10_EXECUTION / "actual_formal_authority").exists():
        raise RuntimeError("attempt10 interruption evidence differs from exact 16/18 partial")
    preflight = basis.get("preflight", {})
    budget = basis.get("attempt11_budget_change", {})
    post_prepare = phase["seconds"] - preflight.get(
        "prep_before_attack_group_seconds", 0)
    remaining_estimate = post_prepare / 16 * 2
    remaining_wall = 600 - phase["seconds"]
    finalization_margin = remaining_wall - remaining_estimate
    if preflight.get("planned_case_count") != 18 or \
            preflight.get("actual_complete_observation_count") != 16 or \
            preflight.get("completed_case_ids") != observed_ids or \
            preflight.get("remaining_case_ids") != expected_cases[16:] or \
            preflight.get("remaining_cases_claimed_executed") is not False or \
            budget.get("new_preflight_phase_wall_seconds") != 600 or \
            budget.get("other_formal_phase_wall_seconds") != 480 or \
            budget.get("additional_wall_seconds_after_attempt10_timeout") != \
                round(remaining_wall, 6) or \
            abs(budget.get(
                "estimated_finalization_margin_after_remaining_cases_seconds", 0) -
                round(finalization_margin, 6)) > 0.000001 or \
            budget.get("estimate_is_guarantee") is not False or \
            budget.get("attempt10_partial_cases_reused") is not False or \
            budget.get("failed_attempt11_partial_cases_credit") != 0 or \
            budget.get("coverage_thresholds_changed") is not False or \
            budget.get("working_set_limit_bytes") != 2_147_483_648 or \
            budget.get("julia_threads") != 1 or \
            budget.get("openblas_threads") != 1:
        raise RuntimeError("attempt11 preflight budget rationale/partial-credit policy drift")
    return {"status": "pass", "attempt10_completed_cases": 16,
            "attempt10_planned_cases": 18,
            "attempt10_uncredited_remaining_case_ids": expected_cases[16:],
            "estimated_finalization_margin_seconds": round(finalization_margin, 6),
            "estimate_is_guarantee": False}


def verify_attempt11_initial_freeze_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt11_initial_freeze_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt11-initial-freeze-failure-basis-r1" or \
            basis.get("status") != \
            "preserved_pre_execution_freezer_failure_only" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt11 initial freeze failure basis is absent")
    files = basis.get("files")
    if not isinstance(files, dict) or set(files) != \
            set(ATTEMPT11_INITIAL_FREEZE_FAILURE_RELATIVE_FILES):
        raise RuntimeError("attempt11 first-freeze failure inventory is incomplete")
    for name, relative in ATTEMPT11_INITIAL_FREEZE_FAILURE_RELATIVE_FILES.items():
        expected = files[name]
        actual = file_receipt(ROOT / relative)
        if expected != actual or expected.get("path") != relative or \
                protocol.get("inputs", {}).get(relative) != expected:
            raise RuntimeError(f"attempt11 first-freeze failure input drift: {name}")
    failure = load_object(ROOT / files["freeze_failure"]["path"])
    if basis.get("failure") != failure or \
            failure.get("schema") != \
            "vnext-t2-attempt11-initial-freezer-failure-r1" or \
            failure.get("status") != \
            "preserved_python_freezer_lineage_guard_failure_no_t2_execution" or \
            failure.get("exit_code") != 1 or \
            failure.get("failure_message") != \
            "controller r9 changed unapproved module bindings" or \
            failure.get("freezer_source_at_failure", {}).get("sha256") != \
            "4cb636ec1de1160ce1ec15094efb4b1e48ac61a4e2baebb4c78a3fbf9a72b5d5" or \
            failure.get("protocol_written") is not False or \
            failure.get("dispatch_written") is not False or \
            failure.get("static_qa_written") is not False or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            (ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "protocol.json").exists() or \
            (ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "static_qa.json").exists():
        raise RuntimeError("attempt11 first-freeze failure was relabeled or mutated")
    return {"status": "pass", "first_freeze_exit_code": 1,
            "classification": "python_freezer_lineage_guard_only",
            "julia_started": False, "formal_t2_accepted": False}


def verify_attempt11_retry1_static_qa_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt11_retry1_static_qa_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt11-retry1-static-qa-failure-basis-r1" or \
            basis.get("status") != \
            "preserved_static_qa_failure_only_no_julia" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt11 retry1 static QA failure basis is absent")
    failure_receipt = basis.get("failure_receipt")
    if failure_receipt != file_receipt(ROOT / ATTEMPT11_RETRY1_FAILURE_RELATIVE) or \
            protocol.get("inputs", {}).get(ATTEMPT11_RETRY1_FAILURE_RELATIVE) != \
            failure_receipt:
        raise RuntimeError("attempt11 retry1 failure receipt pin drift")
    failure = load_object(ROOT / ATTEMPT11_RETRY1_FAILURE_RELATIVE)
    if basis.get("failure") != failure or \
            failure.get("schema") != \
            "vnext-t2-attempt11-retry1-static-qa-failure-r1" or \
            failure.get("status") != \
            "preserved_static_qa_failure_after_projection_preflight_not_acceptance" or \
            failure.get("freezer_exit_code") != 1 or \
            failure.get("static_qa_exit_code") != 1 or \
            failure.get("failure") != {
                "type": "RuntimeError",
                "message": "controller r8/r9 source binding drift"} or \
            failure.get("static_qa_source_at_failure") != {
                "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                        "static_qa_independent_negative_r9.py",
                "bytes": 202670,
                "sha256": "97d723d11fc389cbcbc9551f6cbccb1cc440c9b0cf3ea4327727d0ae7e9b9d88"} or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            failure.get("freeze_snapshot_written") is not False:
        raise RuntimeError("attempt11 retry1 failure was changed or overclaimed")
    files = failure.get("preserved_retry1_files")
    if not isinstance(files, dict) or len(files) != 11 or \
            basis.get("preserved_retry1_files") != files:
        raise RuntimeError("attempt11 retry1 preserved raw inventory is incomplete")
    for relative, expected in files.items():
        if expected != file_receipt(ROOT / relative) or \
                protocol.get("inputs", {}).get(relative) != expected:
            raise RuntimeError(f"attempt11 retry1 pinned artifact drift: {relative}")
    protocol_receipt = failure.get("protocol")
    protocol_old = load_object(ROOT / protocol_receipt["path"])
    qa_old = load_object(ROOT / files[
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1/"
        "static_qa.json"]["path"])
    phase_old = load_object(ROOT / files[
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1/"
        "projection24_reuse_preflight/phase.json"]["path"])
    if protocol_old.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            protocol_old.get("formal_t2_accepted") is not False or \
            protocol_old.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            qa_old.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            qa_old.get("status") != "fail" or qa_old.get("failure") != \
                failure["failure"] or \
            phase_old.get("exit_code") != 0 or \
            phase_old.get("pass_marker") != "T2_PROJECTION24_REUSE=PASS sites=24 groups=4" or \
            (ATTEMPT11_RETRY1_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt11 retry1 phase/static QA outcome drift")
    return {"status": "pass", "retry1_static_qa_exit_code": 1,
            "projection24_preflight_exit_code": 0,
            "failure_classification": "stale_historical_protocol_controller_path_assertion",
            "julia_started": False}


def verify_attempt11_retry2_static_qa_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt11_retry2_static_qa_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt11-retry2-static-qa-failure-basis-r1" or \
            basis.get("status") != \
            "preserved_static_qa_failure_only_no_julia" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt11 retry2 static QA failure basis is absent")
    files = basis.get("files")
    expected = {
        (ATTEMPT11_RETRY2_FAILURE_LEAF / relative).relative_to(ROOT).as_posix()
        for relative in ATTEMPT11_RETRY2_FAILURE_FILES}
    if not isinstance(files, dict) or set(files) != expected or len(files) != 11:
        raise RuntimeError("attempt11 retry2 preserved artifact inventory drift")
    for relative, expected_receipt in files.items():
        if expected_receipt != file_receipt(ROOT / relative) or \
                protocol.get("inputs", {}).get(relative) != expected_receipt:
            raise RuntimeError(f"attempt11 retry2 pinned artifact drift: {relative}")

    retry2_protocol_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "protocol.json"
    retry2_dispatch_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "dispatch.json"
    retry2_command_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "command_argv.json"
    retry2_coverage_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "coverage_map_r8.json"
    retry2_qa_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa.json"
    retry2_phase_path = ATTEMPT11_RETRY2_FAILURE_LEAF / \
        "projection24_reuse_preflight/phase.json"
    retry2_protocol = load_object(retry2_protocol_path)
    retry2_dispatch = load_object(retry2_dispatch_path)
    retry2_command = load_object(retry2_command_path)
    retry2_coverage = load_object(retry2_coverage_path)
    retry2_qa = load_object(retry2_qa_path)
    retry2_phase = load_object(retry2_phase_path)
    controller_path = TEST_ROOT / "independent_negative_controller_r10.py"
    controller_receipt = file_receipt(controller_path)
    source_paths = {
        "freezer": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                  "freeze_independent_negative_protocol_r9.py",
        "static_qa": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                     "static_qa_independent_negative_r9.py",
        "controller": controller_receipt["path"],
    }
    historical_source_pins = {
        name: retry2_protocol.get("inputs", {}).get(path)
        for name, path in source_paths.items()}
    failure = basis.get("failure")
    expected_old_module_names = [
        "vnext_t2_controller_r9", "vnext_t2_projection24_reuse_r4"]
    if not isinstance(failure, dict) or \
            failure.get("schema") != \
            "vnext-t2-attempt11-retry2-static-qa-failure-r1" or \
            failure.get("status") != \
            "preserved_static_qa_failure_after_projection_preflight_not_acceptance" or \
            failure.get("freezer_exit_code") != 1 or \
            failure.get("freezer_failure") != {
                "type": "RuntimeError",
                "message": "r5 Python static QA failed: exit=1"} or \
            failure.get("static_qa_exit_code") != 1 or \
            failure.get("static_qa_failure") != {
                "type": "RuntimeError",
                "message": "dynamic Python module loader targets are not explicit"} or \
            failure.get("historical_source_pins") != historical_source_pins or \
            not all(isinstance(pin, dict) and
                    pin.get("path") == source_paths[name] and
                    isinstance(pin.get("bytes"), int) and
                    len(pin.get("sha256", "")) == 64
                    for name, pin in historical_source_pins.items()) or \
            historical_source_pins.get("controller") != controller_receipt or \
            failure.get("files") != files or \
            failure.get("projection24_phase") != files[
                retry2_phase_path.relative_to(ROOT).as_posix()] or \
            failure.get("projection24_exit_code") != 0 or \
            failure.get("coverage_map") != files[
                retry2_coverage_path.relative_to(ROOT).as_posix()] or \
            failure.get("python_module_binding_at_failure") != \
                expected_old_module_names or \
            failure.get("expected_controller_module_binding") != \
                "vnext_t2_controller_r10" or \
            failure.get("actual_qa_loader_module_binding") != \
                "vnext_t2_controller_r10" or \
            failure.get("julia_started") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            failure.get("freeze_snapshot_written") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            retry2_protocol.get("schema") != \
                "vnext-t2-independent-negative-protocol-r4" or \
            retry2_protocol.get("formal_t2_accepted") is not False or \
            retry2_protocol.get("controller_path") != controller_receipt["path"] or \
            retry2_protocol.get("coverage_map") != file_receipt(retry2_coverage_path) or \
            retry2_protocol.get("python_cache_exclusion", {}).get(
                "qa_dynamic_import_module_names") != expected_old_module_names or \
            retry2_protocol.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            retry2_dispatch.get("protocol") != file_receipt(retry2_protocol_path) or \
            retry2_dispatch.get("julia_started") is not False or \
            retry2_command.get("argv") != retry2_dispatch.get("command_argv") or \
            retry2_command.get("julia_started") is not False or \
            retry2_coverage.get("schema") != \
                "vnext-t2-independent-negative-coverage-map-r8" or \
            retry2_coverage.get("successor_assertion_site_count") != 214 or \
            retry2_coverage.get("successor_expected_runtime_hit_count") != 622 or \
            retry2_qa.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            retry2_qa.get("status") != "fail" or \
            retry2_qa.get("failure") != failure.get("static_qa_failure") or \
            retry2_qa.get("julia_executed") is not False or \
            retry2_phase.get("name") != "projection24_reuse_python_preflight" or \
            retry2_phase.get("status") != "pass" or \
            retry2_phase.get("stop_reason") != "natural_exit" or \
            retry2_phase.get("exit_code") != 0 or \
            retry2_phase.get("pass_marker") != \
                "T2_PROJECTION24_REUSE=PASS sites=24 groups=4" or \
            retry2_phase.get("pass_marker_observed") is not True or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "freeze_snapshot.json").exists() or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa_failure.json").exists() or \
            (ROOT / retry2_protocol["planned_evidence_directory"]).exists():
        raise RuntimeError("attempt11 retry2 failure evidence was altered or overclaimed")
    return {"status": "pass", "retry2_static_qa_exit_code": 1,
            "projection24_preflight_exit_code": 0,
            "failure_classification": "r10_loader_name_mismatch_in_protocol_cache_contract",
            "case_work_started": False, "julia_started": False}


def verify_attempt11_cleanup_receipt(protocol: dict[str, Any]) -> dict[str, Any]:
    cleanup = protocol.get("attempt11_cleanup_receipt")
    cache = protocol.get("python_cache_exclusion", {})
    if not isinstance(cleanup, dict) or cleanup.get("schema") != \
            "vnext-t2-attempt11-owned-temp-cleanup-inventory-r1" or \
            cleanup.get("status") != \
            "pass_no_task_owned_disposable_artifacts" or \
            cleanup.get("python_commands_used_dash_b") is not True or \
            cleanup.get("task_owned_disposable_paths") != [] or \
            cleanup.get("deleted_paths") != [] or \
            cleanup.get("preserved_preexisting_excluded_cache_files") != \
                cache.get("excluded_files") or \
            cleanup.get("excluded_cache_files_were_cleaned") is not False or \
            cleanup.get("failure_evidence_preserved") is not True or \
            cleanup.get("julia_started") is not False:
        raise RuntimeError("attempt11 cleanup receipt is incomplete or inaccurate")
    return {"status": "pass", "task_owned_disposable_paths": [],
            "preserved_excluded_cache_count": len(cache.get("excluded_files", [])),
            "excluded_cache_files_cleaned": False}


def verify_attempt11_budget(protocol: dict[str, Any], dispatch: dict[str, Any],
                            command_data: dict[str, Any],
                            controller_source: str,
                            controller: Any | None = None) -> dict[str, Any]:
    base = {"phase_wall_seconds": 480,
            "authority_phase_wall_seconds": 2400,
            "authority_case_wall_seconds": 2400,
            "process_tree_working_set_bytes": 2_147_483_648,
            "julia_threads": 1, "openblas_threads": 1}
    expected = dict(base)
    expected["phase_wall_timeout_overrides"] = {
        "actual_formal_preflight": 600}
    if protocol.get("resource_gates") != expected or \
            dispatch.get("resource_gates") != expected or \
            protocol.get("expected_phase_count") != 30 or \
            dispatch.get("phase_count") != 30:
        raise RuntimeError("attempt11 resource gates/phase count differ from contract")
    change = protocol.get("preflight_phase_budget_change")
    expected_change = {
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
    }
    if change != expected_change:
        raise RuntimeError("attempt11 preflight timeout evidence/rationale differs")
    argv = command_data.get("argv")
    if not isinstance(argv, list) or "--phase-timeout" not in argv:
        raise RuntimeError("attempt11 controller argv lacks base timeout")
    idx = argv.index("--phase-timeout")
    if idx + 1 >= len(argv) or argv[idx + 1] != "480" or \
            "--working-set-limit" not in argv or \
            argv[argv.index("--working-set-limit") + 1] != "2147483648" or \
            "--authority-phase-timeout" not in argv or \
            argv[argv.index("--authority-phase-timeout") + 1] != "2400" or \
            "--authority-case-timeout" not in argv or \
            argv[argv.index("--authority-case-timeout") + 1] != "2400":
        raise RuntimeError("attempt11 command argv changed non-preflight resources")
    source_contract = verify_attempt11_source_timeout_contract(controller_source)
    if controller is not None:
        if getattr(controller, "actual_formal_shard_timeout", None) is None or \
                controller.actual_formal_shard_timeout("preflight", 480) != 600 or \
                controller.actual_formal_shard_timeout("fault_n10", 480) != 480 or \
                controller.actual_formal_shard_timeout("t1_handoff", 480) != 480:
            raise RuntimeError("controller runtime helper does not implement preflight-only timeout")
        try:
            controller.actual_formal_shard_timeout("authority", 480)
        except ValueError:
            pass
        else:
            raise RuntimeError("timeout helper accepts a non-sharded authority mode")
    if "args.phase_timeout != 480" not in controller_source or \
            "PREFLIGHT_PHASE_TIMEOUT_SECONDS = 600" not in controller_source or \
            "phase_wall_timeout_overrides" not in controller_source:
        raise RuntimeError("controller fixed/default timeout guard changed")
    return {"status": "pass", "resource_gates": expected,
            "preflight_only_timeout_source": source_contract,
            "command_base_phase_timeout_seconds": 480,
            "authority_phase_seconds": 2400,
            "authority_case_seconds": 2400,
            "working_set_limit_bytes": 2_147_483_648}


def verify_controller_r9_r10_preflight_budget_delta(
        protocol: dict[str, Any], controller_source: str) -> dict[str, Any]:
    delta = protocol.get("controller_r9_r10_preflight_budget_delta")
    prior_path = TEST_ROOT / "independent_negative_controller_r9.py"
    current_relative = protocol.get("controller_path")
    if not isinstance(current_relative, str) or current_relative not in \
            protocol.get("inputs", {}):
        raise RuntimeError("attempt11 controller path is not input-pinned")
    current_path = ROOT / current_relative
    prior_receipt = file_receipt(prior_path)
    current_receipt = file_receipt(current_path)
    if not isinstance(delta, dict) or \
            delta.get("schema") != \
            "vnext-t2-controller-r9-r10-preflight-budget-delta-r1" or \
            delta.get("r9_source") != prior_receipt or \
            delta.get("r10_source") != current_receipt or \
            protocol["inputs"].get(prior_receipt["path"]) != prior_receipt or \
            protocol["inputs"].get(current_receipt["path"]) != current_receipt or \
            delta.get("changed_top_level_functions") != \
                ["actual_formal_shard_timeout", "main"] or \
            delta.get("changed_module_bindings") != [
                "PREFLIGHT_PHASE_TIMEOUT_SECONDS"] or \
            delta.get("unchanged_other_module_bindings_and_functions") is not True or \
            delta.get("coverage_semantics_changed") is not False or \
            delta.get("preflight_phase_wall_budget_delta") != {
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
                    "observations remain mandatory.")
            }:
        raise RuntimeError("attempt11 controller timeout-delta evidence drift")
    prior_text = prior_path.read_text(encoding="utf-8")
    normalized = controller_source
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
            raise RuntimeError("attempt11 controller source delta normalization is ambiguous")
        normalized = normalized.replace(current_fragment, prior_fragment, 1)
    if normalized != prior_text:
        raise RuntimeError("attempt11 controller has changes beyond the exact timeout policy")
    unified = "".join(difflib.unified_diff(
        prior_text.splitlines(keepends=True),
        controller_source.splitlines(keepends=True),
        fromfile=prior_receipt["path"], tofile=current_relative))
    if delta.get("unified_diff") != unified or delta.get(
            "unified_diff_sha256") != hashlib.sha256(
                unified.encode("utf-8")).hexdigest():
        raise RuntimeError("attempt11 controller unified delta pin mismatch")
    verify_attempt11_source_timeout_contract(controller_source)
    return {"status": "pass", "changed_functions":
            delta["changed_top_level_functions"],
            "only_preflight_phase_budget_changed": True,
            "coverage_semantics_changed": False}


def verify_authority_case_budget_delta(protocol: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("authority_case_budget_change")
    expected = {
        "schema": "vnext-t2-authority-case-budget-delta-r1",
        "prior_case_timeout_seconds": 1200,
        "new_case_timeout_seconds": 2400,
        "authority_invocation_timeout_seconds": 2400,
        "effective_child_timeout_policy":
            "min(per_case_cap, remaining_invocation_budget)",
        "rationale": (
            "attempt9c did not complete a case before the 480s phase timeout, "
            "so the old 1200s per-case cap was not evidence-backed; 2400s "
            "lets one case use the full bounded invocation while later cases "
            "continue through exact resume"),
        "coverage_thresholds_changed": False,
        "working_set_limit_bytes": 2_147_483_648,
        "julia_threads": 1,
        "openblas_threads": 1,
        "formal_t2_accepted": False,
    }
    if delta != expected:
        raise RuntimeError("authority per-case budget change differs from the approved 2400s contract")
    return {
        "status": "pass", "prior_case_timeout_seconds": 1200,
        "current_case_timeout_seconds": 2400,
        "invocation_timeout_seconds": 2400,
        "effective_child_timeout_policy":
            "min(per_case_cap, remaining_invocation_budget)",
        "coverage_thresholds_changed": False,
        "working_set_limit_bytes": 2_147_483_648,
    }


def verify_attempt8_preflight_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt8_preflight_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt8-preflight-arity-failure-r1" or \
            basis.get("status") != \
            "preserved_natural_exit_failure_not_acceptance" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt8 preflight failure basis is absent or overclaims")
    expected_names = {
        "protocol", "dispatch", "pipeline_final", "baseline_phase",
        "baseline_summary", "baseline_authorization", "preflight_phase",
        "preflight_stderr",
    }
    files = basis.get("files")
    if not isinstance(files, dict) or set(files) != expected_names:
        raise RuntimeError("attempt8 failure receipt inventory is incomplete")
    for name, expected in files.items():
        actual = file_receipt(ROOT / expected["path"])
        if actual != expected or protocol.get("inputs", {}).get(
                expected["path"]) != expected:
            raise RuntimeError(f"attempt8 failure receipt drift: {name}")
    previous_protocol = load_object(ROOT / files["protocol"]["path"])
    previous_dispatch = load_object(ROOT / files["dispatch"]["path"])
    pipeline = load_object(ROOT / files["pipeline_final"]["path"])
    baseline_phase = load_object(ROOT / files["baseline_phase"]["path"])
    baseline_summary = load_object(ROOT / files["baseline_summary"]["path"])
    failed_phase = load_object(ROOT / files["preflight_phase"]["path"])
    driver_path = ROOT / previous_protocol["driver_path"]
    controller_path = ROOT / previous_protocol["controller_path"]
    if basis.get("driver_path") != previous_protocol.get("driver_path") or \
            basis.get("controller_path") != previous_protocol.get("controller_path") or \
            previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r3" or \
            previous_dispatch.get("formal_t2_accepted") is not False or \
            pipeline.get("status") != "fail" or \
            pipeline.get("formal_t2_accepted") is not False or \
            baseline_phase.get("name") != "actual_formal_baseline" or \
            baseline_phase.get("stop_reason") != "natural_exit" or \
            baseline_phase.get("exit_code") != 0 or \
            baseline_summary.get("status") != "pass" or \
            failed_phase.get("name") != "actual_formal_preflight" or \
            failed_phase.get("stop_reason") != "natural_exit" or \
            failed_phase.get("exit_code") != 1 or \
            failed_phase.get("timeout_seconds") != 480.0 or \
            failed_phase.get("working_set_limit_bytes") != 2_147_483_648:
        raise RuntimeError("attempt8 preflight failure phase status drift")
    command = failed_phase.get("command")
    if not isinstance(command, list) or str(driver_path.resolve()) not in command:
        raise RuntimeError("attempt8 preflight lacks its driver invocation")
    driver_args = command[command.index(str(driver_path.resolve())) + 1:]
    driver_source = driver_path.read_text(encoding="utf-8")
    expected_error = (
        "ERROR: LoadError: expected mode, four authority path/hash pairs, "
        "context path/hash, authorization path/hash, output dir, "
        "coverage map path/hash")
    stderr = (ROOT / files["preflight_stderr"]["path"]).read_text(
        encoding="utf-8", errors="replace").splitlines()
    expected_map = basis.get("missing_final_coverage_map_pair")
    if len(driver_args) != 14 or driver_args[0] != "preflight" or \
            basis.get("driver_expected_argument_count") != 16 or \
            basis.get("observed_preflight_argument_count") != 14 or \
            basis.get("observed_preflight_exit_code") != 1 or \
            basis.get("observed_preflight_stop_reason") != "natural_exit" or \
            basis.get("observed_error_line") != expected_error or \
            not stderr or stderr[0] != expected_error or \
            not isinstance(expected_map, dict) or \
            expected_map.get("path") != str(
                (ROOT / previous_protocol["coverage_map"]["path"]).resolve()) or \
            expected_map.get("sha256") != previous_protocol[
                "coverage_map"]["sha256"] or \
            driver_args[-2:] == [expected_map["path"], expected_map["sha256"]] or \
            "length(ARGS) == 16 || error(" not in driver_source or \
            "abspath(ARGS[15])" not in driver_source or \
            "lowercase(ARGS[16])" not in driver_source:
        raise RuntimeError("attempt8 preflight missing-map argv failure is not proven")
    old_pins = previous_protocol.get("inputs", {})
    for path in (driver_path, controller_path):
        relative = path.relative_to(ROOT).as_posix()
        if old_pins.get(relative) != file_receipt(path) or \
                protocol.get("inputs", {}).get(relative) != file_receipt(path):
            raise RuntimeError(f"attempt8 code source pin drift: {relative}")
    return {"status": basis["status"], "baseline_exit_code": 0,
            "preflight_exit_code": 1, "preflight_argument_count": 14,
            "driver_expected_argument_count": 16,
            "coverage_map_pair_omitted": True,
            "formal_t2_accepted": False}


def verify_attempt9_projection_preflight_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt9_projection_preflight_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt9-projection-schema-preflight-failure-r1" or \
            basis.get("status") != \
            "preserved_natural_exit_failure_not_acceptance" or \
            basis.get("julia_started") is not False or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt9 projection failure basis is absent or overclaims")
    expected_names = {"protocol", "coverage_map", "preflight_phase",
                      "preflight_stdout", "preflight_stderr"}
    files = basis.get("files")
    if not isinstance(files, dict) or set(files) != expected_names:
        raise RuntimeError("attempt9 projection failure receipt inventory is incomplete")
    for name, expected in files.items():
        if file_receipt(ROOT / expected["path"]) != expected or \
                protocol.get("inputs", {}).get(expected["path"]) != expected:
            raise RuntimeError(f"attempt9 failure pin drift: {name}")
    previous_protocol = load_object(ROOT / files["protocol"]["path"])
    phase = load_object(ROOT / files["preflight_phase"]["path"])
    previous_coverage = files["coverage_map"]
    validator_path = basis.get("validator_r3_path")
    if not isinstance(validator_path, str) or validator_path not in protocol.get(
            "inputs", {}):
        raise RuntimeError("attempt9 r3 validator source pin is absent")
    validator_receipt = protocol["inputs"][validator_path]
    validator_actual = file_receipt(ROOT / validator_path)
    stderr_lines = (ROOT / files["preflight_stderr"]["path"]).read_text(
        encoding="utf-8", errors="replace").splitlines()
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_started") is True or \
            previous_protocol.get("coverage_map") != previous_coverage or \
            phase.get("schema") != \
            "vnext-t2-projection24-python-preflight-phase-r1" or \
            phase.get("name") != "projection24_reuse_python_preflight" or \
            phase.get("status") != "fail" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 1 or \
            phase.get("julia_started") is not False or \
            phase.get("formal_t2_accepted") is not False or \
            phase.get("pass_marker_observed") is not False or \
            phase.get("command_argv", [None])[2] != str(
                TEST_ROOT / "validate_projection24_reuse_r3.py") or \
            basis.get("validator_r3_sha256") != validator_receipt.get("sha256") or \
            validator_actual != validator_receipt or \
            basis.get("observed_exit_code") != 1 or \
            basis.get("observed_stop_reason") != "natural_exit" or \
            basis.get("protocol_schema_expected") != \
            "vnext-t2-independent-negative-protocol-r3" or \
            basis.get("protocol_schema_observed") != previous_protocol.get("schema") or \
            not stderr_lines or \
            stderr_lines[-1] != basis.get("observed_stderr_final_line") or \
            not stderr_lines[-1].endswith(
                "RuntimeError: projection reuse protocol schema mismatch") or \
            (ROOT / files["protocol"]["path"]).parent.joinpath(
                "static_qa.json").exists() or \
            (ROOT / files["protocol"]["path"]).parent.joinpath(
                "freeze_snapshot.json").exists() or \
            (ROOT / files["preflight_phase"]["path"]).parent.joinpath(
                "reuse_receipt.json").exists():
        raise RuntimeError("attempt9 projection schema mismatch failure is not proven")
    return {"status": basis["status"], "preflight_exit_code": 1,
            "stop_reason": "natural_exit", "validator_schema_mismatch": True,
            "julia_started": False, "formal_t2_accepted": False}


def verify_attempt9b_static_qa_failure_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt9b_static_qa_failure_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt9b-static-qa-failure-r1" or \
            basis.get("status") != \
            "preserved_static_qa_failure_not_acceptance" or \
            basis.get("observed_failure") != ATTEMPT9B_EXPECTED_QA_FAILURE or \
            basis.get("projection_preflight_natural_exit_code") != 0 or \
            basis.get("projection_reuse_sites_completed") != 24 or \
            basis.get("julia_started") is not False or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt9b static QA failure basis is absent or overclaims")
    files = basis.get("files")
    if not isinstance(files, dict) or set(files) != \
            set(ATTEMPT9B_FAILURE_RELATIVE_PATHS):
        raise RuntimeError("attempt9b failure evidence inventory is incomplete")
    for name, relative_tail in ATTEMPT9B_FAILURE_RELATIVE_PATHS.items():
        expected_path = (ATTEMPT9B_FAILURE_LEAF / relative_tail).relative_to(
            ROOT).as_posix()
        expected = files[name]
        if expected.get("path") != expected_path or \
                file_receipt(ROOT / expected_path) != expected or \
                protocol.get("inputs", {}).get(expected_path) != expected:
            raise RuntimeError(f"attempt9b failure evidence pin drift: {name}")
    previous_protocol = load_object(ROOT / files["protocol"]["path"])
    previous_phase = load_object(ROOT / files["preflight_phase"]["path"])
    previous_dispatch = load_object(ROOT / files["dispatch"]["path"])
    previous_command = load_object(ROOT / files["command"]["path"])
    previous_reuse = load_object(ROOT / files["preflight_receipt"]["path"])
    previous_qa = load_object(ROOT / files["static_qa"]["path"])
    old_qa_path = TEST_ROOT / "static_qa_independent_negative_r4b.py"
    old_qa_receipt = file_receipt(old_qa_path)
    old_qa_source = old_qa_path.read_text(encoding="utf-8")
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("status") != \
            "frozen_static_ready_not_executed" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_started") is True or \
            previous_dispatch.get("julia_started") is not False or \
            previous_command.get("julia_started") is not False or \
            previous_dispatch.get("protocol") != files["protocol"] or \
            previous_dispatch.get("command") != files["command"] or \
            previous_phase.get("status") != "pass" or \
            previous_phase.get("stop_reason") != "natural_exit" or \
            previous_phase.get("exit_code") != 0 or \
            previous_phase.get("julia_started") is not False or \
            previous_phase.get("formal_t2_accepted") is not False or \
            previous_phase.get("command_argv", [None])[2] != str(
                PROJECTION_REUSE_VALIDATOR) or \
            previous_reuse.get("schema") != \
            "vnext-t2-projection24-cross-run-validation-r4" or \
            previous_reuse.get("assertion_sites_completed") != 24 or \
            previous_reuse.get("natural_exit_zero") is not True or \
            previous_reuse.get("post_assertion_pass_marker") is not True or \
            previous_qa.get("status") != "fail" or \
            previous_qa.get("failure") != ATTEMPT9B_EXPECTED_QA_FAILURE or \
            previous_qa.get("julia_executed") is not False or \
            previous_protocol.get("inputs", {}).get(
                old_qa_receipt["path"]) != old_qa_receipt or \
            "positive_evidence_receipts,\n            controller_source, controls)" not in old_qa_source or \
            'authority_args = [str(positive["manifest_path"])' not in old_qa_source or \
            (ATTEMPT9B_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt9b static QA failure details are inconsistent")
    return {"status": basis["status"], "failure": basis["observed_failure"],
            "projection_preflight_exit_code": 0,
            "projection_reuse_sites_completed": 24,
            "julia_started": False, "formal_t2_accepted": False}


def verify_attempt9c_authority_interruption_basis(
        protocol: dict[str, Any]) -> dict[str, Any]:
    basis = protocol.get("attempt9c_authority_interruption_basis")
    if not isinstance(basis, dict) or basis.get("schema") != \
            "vnext-t2-attempt9c-authority-resource-interruption-r1" or \
            basis.get("status") != \
            "resource_interruption_incomplete_not_scientific_fail_not_accepted" or \
            basis.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt9c resource interruption basis is absent or reclassified")
    fixed_pins = ("attempt9c_protocol", "attempt9c_coverage_map",
        "pipeline_start", "pipeline_final")
    for name in fixed_pins:
        pin = basis.get(name)
        if not isinstance(pin, dict) or file_receipt(ROOT / pin["path"]) != pin or \
                protocol.get("inputs", {}).get(pin["path"]) != pin:
            raise RuntimeError(f"attempt9c failure pin drift: {name}")
    for name in ("baseline_phase", "authority_phase"):
        row = basis.get(name)
        if not isinstance(row, dict) or not isinstance(row.get("receipt"), dict) or \
                file_receipt(ROOT / row["receipt"]["path"]) != row["receipt"] or \
                protocol.get("inputs", {}).get(row["receipt"]["path"]) != row["receipt"]:
            raise RuntimeError(f"attempt9c phase pin drift: {name}")
    raw = basis.get("authority_raw_receipts")
    expected_raw = {"authority_stdout", "authority_stderr", "authority_samples",
                    "authority_observations", "authority_transport",
                    "authority_stage_trace"}
    if not isinstance(raw, dict) or set(raw) != expected_raw:
        raise RuntimeError("attempt9c raw failure receipt inventory mismatch")
    for name, pin in raw.items():
        if file_receipt(ROOT / pin["path"]) != pin or \
                protocol.get("inputs", {}).get(pin["path"]) != pin:
            raise RuntimeError(f"attempt9c raw failure pin drift: {name}")
    pipeline_path = ROOT / basis["pipeline_final"]["path"]
    pipeline = load_object(pipeline_path)
    phase_path = ROOT / basis["authority_phase"]["receipt"]["path"]
    phase = load_object(phase_path)
    baseline_path = ROOT / basis["baseline_phase"]["receipt"]["path"]
    baseline = load_object(baseline_path)
    transport_path = ROOT / raw["authority_transport"]["path"]
    transport = load_object(transport_path)
    observations_path = ROOT / raw["authority_observations"]["path"]
    observations = [json.loads(line) for line in observations_path.read_text(
        encoding="utf-8").splitlines() if line.strip()]
    expected_pre_assertion_observation = {
        "case_id": "PARENT_STALE",
        "status": "fail_closed",
        "resolution": "none",
        "first_reason": "t2_preflight_parent_commitment_mismatch",
        "committed": False,
        "ledger_status": "complete_contract_receipts",
    }
    stdout_path = ROOT / raw["authority_stdout"]["path"]
    stdout_lines = stdout_path.read_text(encoding="utf-8",
        errors="replace").splitlines()
    trace_path = ROOT / raw["authority_stage_trace"]["path"]
    trace_lines = trace_path.read_text(encoding="utf-8").splitlines()
    last_stdout = next((line.removeprefix("VNEXT_T2_NEGATIVE_STAGE=")
        for line in reversed(stdout_lines)
        if line.startswith("VNEXT_T2_NEGATIVE_STAGE=")), "")
    missing = [
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r4_attempt9c_final/actual_formal_authority/artifacts/summary.json",
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r4_attempt9c_final/actual_formal_authority/artifacts/case_progress.jsonl",
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r4_attempt9c_final/actual_formal_authority/artifacts/authority_case_aggregate.json",
    ]
    if baseline.get("stop_reason") != "natural_exit" or \
            baseline.get("exit_code") != 0 or \
            phase.get("name") != "actual_formal_authority" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or \
            phase.get("timeout_seconds") != 480.0 or \
            phase.get("seconds") != 480.20754000000306 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_703_682_048 or \
            phase.get("residual_heavy_processes") != [] or \
            pipeline.get("status") != "fail" or \
            pipeline.get("formal_t2_accepted") is not False or \
            pipeline.get("inputs_before") != pipeline.get("inputs_after") or \
            not trace_lines or trace_lines[-1] != basis.get(
                "last_completed_stage_marker") or \
            last_stdout != basis.get("last_stdout_stage_marker") or \
            last_stdout != trace_lines[-1] or \
            last_stdout.split("\t", 1)[0] != "attack_group_authority.begin" or \
            basis.get("assertion_completion_status") != \
                "unknown_no_authority_summary_or_case_progress" or \
            basis.get("pre_assertion_observation_case_ids") != ["PARENT_STALE"] or \
            basis.get("pre_assertion_observation") != \
                expected_pre_assertion_observation or \
            len(observations) != 1 or \
            {"case_id": observations[0].get("case_id"),
             "status": observations[0].get("status"),
             "resolution": observations[0].get("resolution"),
             "first_reason": observations[0].get("first_reason"),
             "committed": observations[0].get("committed"),
             "ledger_status": observations[0].get("ledger", {}).get("status")
            } != expected_pre_assertion_observation or \
            transport.get("shard") != "authority" or \
            transport.get("recorded_before_assertions") is not True or \
            any(path.exists() for path in missing) or \
            basis.get("authority_completion_artifacts_absent") != [
                path.relative_to(ROOT).as_posix() for path in missing]:
        raise RuntimeError("attempt9c authority interruption evidence differs from failure basis")
    return {"status": basis["status"], "authority_exit_code": 15,
            "timeout_seconds": 480.0, "peak_working_set_bytes": 1_703_682_048,
            "last_marker": last_stdout,
            "pre_assertion_observation": expected_pre_assertion_observation,
            "assertion_completion_status": basis["assertion_completion_status"],
            "formal_t2_accepted": False}


def verify_projection_validator_r3_r4_delta(
        protocol: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("projection_validator_r3_r4_delta")
    if not isinstance(delta, dict) or delta.get("schema") != \
            "vnext-t2-projection-validator-r3-r4-delta-r1":
        raise RuntimeError("projection validator version delta is absent")
    old_path = TEST_ROOT / "validate_projection24_reuse_r3.py"
    new_path = TEST_ROOT / "validate_projection24_reuse_r4.py"
    old_receipt = file_receipt(old_path)
    new_receipt = file_receipt(new_path)
    if delta.get("r3_source") != old_receipt or \
            delta.get("r4_source") != new_receipt or \
            protocol.get("inputs", {}).get(old_receipt["path"]) != old_receipt or \
            protocol.get("inputs", {}).get(new_receipt["path"]) != new_receipt:
        raise RuntimeError("projection validator version source pin drift")
    old_text = old_path.read_text(encoding="utf-8")
    new_text = new_path.read_text(encoding="utf-8")
    substitutions = [
        ("validate_projection24_reuse_r3.py",
         "validate_projection24_reuse_r4.py"),
        ("vnext-t2-independent-negative-protocol-r3",
         "vnext-t2-independent-negative-protocol-r4"),
        ("vnext-t2-projection24-cross-run-validation-r3",
         "vnext-t2-projection24-cross-run-validation-r4"),
    ]
    expected_replacements = [
        {"from": old, "to": new, "occurrences": 1}
        for old, new in substitutions]
    normalized = new_text
    for old, new in substitutions:
        if old_text.count(old) != 1 or new_text.count(new) != 1:
            raise RuntimeError(f"projection validator delta occurrence drift: {old}")
        normalized = normalized.replace(new, old)
    actual_diff = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=old_receipt["path"], tofile=new_receipt["path"]))
    if normalized != old_text or delta.get("allowed_replacements") != \
            expected_replacements or delta.get("unified_diff") != actual_diff or \
            delta.get("non_schema_semantic_changes") != 0 or \
            delta.get("normalized_r4_source_equals_r3") is not True:
        raise RuntimeError("projection validator diff changes semantics beyond schema identity")
    return {"status": "pass", "r3_source": old_receipt,
            "r4_source": new_receipt, "allowed_replacement_count": 3,
            "non_schema_semantic_changes": 0,
            "exact_unified_diff_sha256": hashlib.sha256(
                actual_diff.encode("utf-8")).hexdigest()}


def verify_controller_r8_r9_authority_progress_delta(
        protocol: dict[str, Any]) -> dict[str, Any]:
    delta = protocol.get("controller_r8_r9_authority_progress_delta")
    if not isinstance(delta, dict) or delta.get("schema") != \
            "vnext-t2-controller-r8-r9-authority-progress-delta-r1":
        raise RuntimeError("controller r8/r9 authority progress delta is absent")
    old_path = TEST_ROOT / "independent_negative_controller_r8.py"
    new_path = TEST_ROOT / "independent_negative_controller_r9.py"
    old_receipt = file_receipt(old_path)
    new_receipt = file_receipt(new_path)
    if delta.get("r8_source") != old_receipt or \
            delta.get("r9_source") != new_receipt or \
            protocol.get("inputs", {}).get(old_receipt["path"]) != old_receipt or \
            protocol.get("inputs", {}).get(new_receipt["path"]) != new_receipt:
        raise RuntimeError("controller r8/r9 source binding drift")
    old_text = old_path.read_text(encoding="utf-8")
    new_text = new_path.read_text(encoding="utf-8")
    old_tree = ast.parse(old_text)
    new_tree = ast.parse(new_text)
    mutable = {"_authority_source_ids", "verify_authority_case_receipt",
               "run_authority_case_phase", "summarize_authority_case_progress_prefix",
               "main"}
    mutable_bindings = {"ACTUAL_DRIVER", "AUTHORITY_CASE_TIMEOUT_SECONDS"}
    def normalized(tree: ast.Module) -> tuple[list[str], dict[str, str]]:
        fixed = []
        functions = {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name) and \
                    node.targets[0].id in mutable_bindings:
                continue
            else:
                fixed.append(ast.dump(node, include_attributes=False))
        return fixed, functions
    old_fixed, old_functions = normalized(old_tree)
    new_fixed, new_functions = normalized(new_tree)
    changed_functions = sorted(name for name in set(old_functions) | set(new_functions)
        if old_functions.get(name) != new_functions.get(name))
    old_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in old_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    new_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in new_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    changed_bindings = sorted(name for name in mutable_bindings
        if old_assignments.get(name) != new_assignments.get(name))
    actual_diff = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=old_receipt["path"], tofile=new_receipt["path"]))
    expected_changed = sorted(mutable)
    expected_budget_delta = {
        "prior_case_seconds": 1200,
        "current_case_seconds": 2400,
        "invocation_cap_seconds": 2400,
        "effective_timeout":
            "min(per_case_cap, remaining_invocation_budget)",
        "rationale": (
            "a 1200s child cap has no evidence-backed sufficiency after "
            "attempt9c observed no case completion under the 480s invocation "
            "cutoff; matching the child cap to the invocation cap lets a "
            "case finish and then permits safe resume of later incomplete cases"),
    }
    if old_fixed != new_fixed or changed_functions != expected_changed or \
            changed_bindings != sorted(mutable_bindings) or \
            delta.get("changed_top_level_functions") != expected_changed or \
            delta.get("changed_module_bindings") != sorted(mutable_bindings) or \
            delta.get("unchanged_other_module_bindings_and_functions") is not True or \
            delta.get("coverage_semantics_changed") is not False or \
            delta.get("authority_case_wall_budget_delta") != expected_budget_delta or \
            delta.get("unified_diff") != actual_diff or \
            delta.get("unified_diff_sha256") != hashlib.sha256(
                actual_diff.encode("utf-8")).hexdigest():
        raise RuntimeError("controller r9 source delta escapes authority progress/resource changes")
    return {"status": "pass", "r8_source": old_receipt,
            "r9_source": new_receipt,
            "changed_top_level_functions": expected_changed,
            "changed_module_bindings": sorted(mutable_bindings),
            "coverage_semantics_changed": False,
            "exact_unified_diff_sha256": hashlib.sha256(
                actual_diff.encode("utf-8")).hexdigest()}


def derive_controller_child_script_plan(
        controller_source: str, phase_order: list[str]) -> dict[str, Any]:
    if phase_order != EXPECTED_CONTROLLER_PHASES or \
            set(CHILD_PHASE_BINDINGS) != set(EXPECTED_CONTROLLER_PHASES):
        raise RuntimeError("controller phase order differs from child script plan")
    tree = ast.parse(controller_source)
    expected_roots = {
        "PARSE_GATE": ("ROOT", "test/GenomeV5/Integration/"
                       "VNextT2ConcreteSourceWitnessV3/parse_gate.jl"),
        "AST_INVENTORY_DRIVER": ("TEST_ROOT", "coverage_ast_inventory_r3.jl"),
        "PROJECTION_REUSE_VALIDATOR": ("TEST_ROOT", "validate_projection24_reuse_r4.py"),
        "ACTUAL_DRIVER": ("TEST_ROOT", "actual_formal_negative_driver_r6.jl"),
        "SUPPLEMENTARY_DRIVER": ("TEST_ROOT", "supplementary_contract_driver_r1.jl"),
        "ARTIFACT_DRIVER": ("TEST_ROOT", "artifact_preflight_negative_driver_r1.jl"),
        "ATTACK_FIXTURE_DRIVER": ("TEST_ROOT", "artifact_attack_fixture_driver_r1.jl"),
        "CANDIDATE_DRIVER": ("IMPLEMENTATION_ROOT", "formal_candidate_driver.jl"),
    }
    assignments: dict[str, tuple[str, str]] = {}
    for node in tree.body:
        if isinstance(node, ast.Assign):
            targets, value = node.targets, node.value
        elif isinstance(node, ast.AnnAssign):
            targets, value = [node.target], node.value
        else:
            continue
        if not isinstance(value, ast.BinOp) or not isinstance(value.op, ast.Div) or \
                not isinstance(value.left, ast.Name) or \
                not isinstance(value.right, ast.Constant) or \
                not isinstance(value.right.value, str):
            continue
        for target in targets:
            if isinstance(target, ast.Name) and target.id in expected_roots:
                if target.id in assignments:
                    raise RuntimeError(f"duplicate child script binding: {target.id}")
                assignments[target.id] = (value.left.id, value.right.value)
    if assignments != expected_roots:
        raise RuntimeError("controller child script path constants drifted")
    loaded_names = {node.id for node in ast.walk(tree)
                    if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Load)}
    if not set(expected_roots).issubset(loaded_names):
        raise RuntimeError("controller declares an unused expected child script")

    def call_source(phase_name: str, binding_name: str) -> bool:
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call) or \
                    not isinstance(node.func, ast.Name) or \
                    node.func.id != "run_phase" or len(node.args) < 2:
                continue
            phase_arg = node.args[0]
            if not isinstance(phase_arg, ast.Constant) or \
                    phase_arg.value != phase_name:
                continue
            return any(isinstance(child, ast.Name) and
                       child.id == binding_name
                       for child in ast.walk(node.args[1]))
        return False

    direct_checks = {
        "parse_gate": "PARSE_GATE",
        "coverage_ast_inventory": "AST_INVENTORY_DRIVER",
        "projection24_cross_run_validation": "PROJECTION_REUSE_VALIDATOR",
        "artifact_attack_fixture_generation": "ATTACK_FIXTURE_DRIVER",
    }
    if any(not call_source(phase, binding)
           for phase, binding in direct_checks.items()):
        raise RuntimeError("direct phase call is not bound to its expected script")
    required_routes = (
        "actual_common = [str(ACTUAL_DRIVER)]",
        "actual_shards = (",
        "for phase_name, mode in actual_shards:",
        "build_actual_formal_shard_command(",
        "str(ACTUAL_DRIVER)",
        "str(SUPPLEMENTARY_DRIVER)",
        "str(ARTIFACT_DRIVER)",
        "str(ATTACK_FIXTURE_DRIVER)",
        "str(CANDIDATE_DRIVER)",
        "def candidate_command(",
        "for phase_name, mode, expected_case in (",
        "artifact_specs = (",
        "formal_artifact_specs = (",
    )
    if any(fragment not in controller_source for fragment in required_routes):
        raise RuntimeError("controller child script is not connected to a planned phase")
    executable_refs = [node for node in ast.walk(tree)
                       if isinstance(node, ast.Attribute) and
                       isinstance(node.value, ast.Name) and
                       node.value.id == "sys" and node.attr == "executable"]
    python_calls = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not isinstance(node.func, ast.Name) or \
                node.func.id != "run_phase" or len(node.args) < 2:
            continue
        phase_arg, command_arg = node.args[0], node.args[1]
        if isinstance(phase_arg, ast.Constant) and \
                isinstance(phase_arg.value, str) and \
                isinstance(command_arg, ast.List) and command_arg.elts and \
                isinstance(command_arg.elts[0], ast.Attribute) and \
                isinstance(command_arg.elts[0].value, ast.Name) and \
                command_arg.elts[0].value.id == "sys" and \
                command_arg.elts[0].attr == "executable":
            python_calls.append((phase_arg.value, command_arg))
    if len(executable_refs) != 1 or len(python_calls) != 1 or \
            python_calls[0][0] != "projection24_cross_run_validation":
        raise RuntimeError("controller Python child path set has an extra/missing phase")
    command_nodes = python_calls[0][1].elts
    if len(command_nodes) != 5 or \
            not (isinstance(command_nodes[1], ast.Constant) and
                 command_nodes[1].value == "-B") or \
            not (isinstance(command_nodes[2], ast.Call) and
                 isinstance(command_nodes[2].func, ast.Name) and
                 command_nodes[2].func.id == "str" and
                 len(command_nodes[2].args) == 1 and
                 isinstance(command_nodes[2].args[0], ast.Name) and
                 command_nodes[2].args[0].id == "PROJECTION_REUSE_VALIDATOR"):
        raise RuntimeError("controller Python child argv is not the pinned validator")

    path_by_binding = {}
    for name, (root_name, suffix) in expected_roots.items():
        path_by_binding[name] = (
            suffix if root_name == "ROOT" else
            "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/" + suffix
            if root_name == "IMPLEMENTATION_ROOT" else
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/" + suffix)
    phase_paths = {phase: [path_by_binding[binding]]
                   for phase, binding in CHILD_PHASE_BINDINGS.items()}
    paths = []
    for phase in phase_order:
        path = phase_paths[phase][0]
        if path not in paths:
            paths.append(path)
    dynamic_imports = [node for node in ast.walk(tree)
                       if isinstance(node, ast.Call) and
                       ((isinstance(node.func, ast.Name) and
                         node.func.id == "__import__") or
                        (isinstance(node.func, ast.Attribute) and
                         node.func.attr in {"import_module", "run_module",
                                            "spec_from_file_location"}))]
    if dynamic_imports:
        raise RuntimeError("controller contains dynamic module loading")
    return {
        "schema": "vnext-t2-controller-child-script-plan-r2",
        "phase_count": len(phase_paths),
        "unique_script_count": len(paths),
        "phase_ids": phase_order,
        "script_paths": paths,
        "phase_to_script_paths": phase_paths,
        "python_child_phase_ids": ["projection24_cross_run_validation"],
        "dynamic_python_imports_in_controller": [],
    }


def verify_controller_child_script_plan(
        protocol: dict[str, Any], controller_source: str) -> dict[str, Any]:
    actual = derive_controller_child_script_plan(
        controller_source, protocol.get("phase_order", []))
    if protocol.get("controller_child_script_plan") != actual:
        raise RuntimeError("controller child script set differs from phase plan")
    for path in actual["script_paths"]:
        if path not in protocol.get("inputs", {}):
            raise RuntimeError(f"controller child script is unpinned: {path}")
    return {"status": "pass", **actual}


def verify_actual_formal_shard_argv_contract(
        protocol: dict[str, Any], controller: Any,
        positive: dict[str, Any], controller_source: str,
        controls: list[dict[str, str]]) -> dict[str, Any]:
    contract = protocol.get("actual_formal_shard_argv_contract")
    case_order = ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
        "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
        "ACTUAL_FORMAL_GATE_REJECTION", "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
        "ACTUAL_DUPLICATE_INVOCATION"]
    expected_modes = ["preflight", "fault_n10", "t1_handoff",
                      *["authority-case:" + case_id for case_id in case_order]]
    if not isinstance(contract, dict) or \
            contract.get("schema") != "vnext-t2-formal-shard-argv-contract-r1" or \
            contract.get("driver_path") != ACTUAL_FORMAL_DRIVER.relative_to(
                ROOT).as_posix() or \
            contract.get("controller_builder") != \
            "build_actual_formal_shard_command" or \
            contract.get("expected_driver_argument_count") != 16 or \
            contract.get("coverage_map_path_driver_argv_index_1_based") != 15 or \
            contract.get("coverage_map_sha256_driver_argv_index_1_based") != 16 or \
            contract.get("shard_modes") != expected_modes or \
            contract.get("static_actual_command_builder_test") is not True:
        raise RuntimeError("formal shard argv contract plan is malformed")
    driver_source = ACTUAL_FORMAL_DRIVER.read_text(encoding="utf-8")
    if "length(ARGS) == 16 || error(" not in driver_source or \
            "const T2_NEG_COVERAGE_MAP_PATH = abspath(ARGS[15])" not in driver_source or \
            "const T2_NEG_COVERAGE_MAP_SHA256 = lowercase(ARGS[16])" not in driver_source:
        raise RuntimeError("actual r3 driver ARGS semantic contract drift")
    required_controller_calls = (
        "def build_actual_formal_shard_command(",
        "str(output_dir), str(coverage_map_path), coverage_map_sha256",
        "shard_command = build_actual_formal_shard_command(",
        "run_phase(phase_name,\n                    shard_command, shard_dir",
        "run_authority_case_phase(",
        'f"authority-case:{case_id}"',
    )
    if any(fragment not in controller_source for fragment in required_controller_calls) or \
            "julia_common + actual_common + [mode, *actual_authorities" in controller_source:
        raise RuntimeError("runtime shard path bypasses the tested argv builder")
    map_path = str((ROOT / protocol["coverage_map"]["path"]).resolve())
    map_sha = protocol["coverage_map"]["sha256"]
    authority_args = [str(positive["manifest_path"]), positive["manifest_sha256"],
        str(positive["verification_path"]), positive["verification_sha256"],
        str(positive["candidate_path"]), positive["candidate_sha256"],
        str(positive["package_path"]), positive["package_sha256"]]
    planned = ROOT / protocol["planned_evidence_directory"]
    context_path = str(planned / "actual_formal_baseline/artifacts/baseline_context.jls")
    authorization_path = str(planned / "actual_formal_baseline_authorization.json")
    context_sha = "a" * 64
    authorization_sha = "b" * 64
    julia_prefix = [protocol["julia_executable"], f"--project={ROOT}",
                    "--startup-file=no", "--history-file=no", "--threads=1"]

    def expected_artifacts(mode: str) -> str:
        if mode.startswith("authority-case:"):
            case_id = mode.split(":", 1)[1]
            return str(planned / "actual_formal_authority" / "cases" /
                       case_id / "artifacts")
        return str(planned / f"actual_formal_{mode}/artifacts")

    def validate_driver_args(args: list[str], mode: str) -> None:
        if len(args) != 16 or args[0] != mode or args[1:9] != authority_args or \
                args[9:11] != [context_path, context_sha] or \
                args[11:13] != [authorization_path, authorization_sha] or \
                args[13] != expected_artifacts(mode) or \
                args[14:16] != [map_path, map_sha]:
            raise RuntimeError(f"driver ARGS mismatch for shard {mode}")

    command_receipts = []
    for mode in expected_modes:
        command = controller.build_actual_formal_shard_command(
            julia_prefix, mode, authority_args, context_path, context_sha,
            authorization_path, authorization_sha,
            expected_artifacts(mode), map_path, map_sha)
        driver_index = command.index(str(ACTUAL_FORMAL_DRIVER.resolve()))
        driver_args = command[driver_index + 1:]
        validate_driver_args(driver_args, mode)
        command_receipts.append({"mode": mode,
                                 "driver_argument_count": len(driver_args),
                                 "coverage_map_path": driver_args[14],
                                 "coverage_map_sha256": driver_args[15]})

    sample_mode = expected_modes[-1]
    sample_args = controller.build_actual_formal_shard_command(
        julia_prefix, sample_mode, authority_args, context_path, context_sha,
        authorization_path, authorization_sha,
        expected_artifacts(sample_mode), map_path, map_sha)
    sample_driver_args = sample_args[
        sample_args.index(str(ACTUAL_FORMAL_DRIVER.resolve())) + 1:]
    expect_reject("formal shard rejects both missing map argv values",
                  lambda: validate_driver_args(sample_driver_args[:-2],
                                               sample_mode), controls)
    expect_reject("formal shard rejects missing map SHA argv value",
                  lambda: validate_driver_args(sample_driver_args[:-1], sample_mode), controls)
    wrong_path = list(sample_driver_args)
    wrong_path[14] += ".stale"
    expect_reject("formal shard rejects coverage map path drift",
                  lambda: validate_driver_args(wrong_path, sample_mode), controls)
    wrong_sha = list(sample_driver_args)
    wrong_sha[15] = "0" * 64
    expect_reject("formal shard rejects coverage map SHA drift",
                  lambda: validate_driver_args(wrong_sha, sample_mode), controls)
    swapped = list(sample_driver_args)
    swapped[14], swapped[15] = swapped[15], swapped[14]
    expect_reject("formal shard rejects coverage map argv reordering",
                  lambda: validate_driver_args(swapped, sample_mode), controls)
    return {"status": "pass", "shard_count": len(command_receipts),
            "expected_driver_argument_count": 16,
            "coverage_map_path_index_1_based": 15,
            "coverage_map_sha256_index_1_based": 16,
            "coverage_map": protocol["coverage_map"],
            "commands": command_receipts,
            "outer_actual_shard_count": 4,
            "authority_case_child_count": 9,
            "negative_controls": 5,
            "runtime_uses_tested_builder": True}


def verify_authority_case_hit_contract(
        protocol: dict[str, Any], coverage: dict[str, Any],
        driver_source: str, controller_source: str,
        controls: list[dict[str, str]]) -> dict[str, Any]:
    phases = ["actual_formal_preflight", "actual_formal_authority",
              "actual_formal_fault_n10", "actual_formal_t1_handoff"]
    hit_plan = coverage.get("successor_assertion_runtime_hit_plan", {})
    authority_plan = hit_plan.get("authority_case_hit_plan")
    contract = protocol.get("authority_case_execution_contract")
    case_order = ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE", "G3_FOREIGN",
        "ACTUAL_FOREIGN_SCENARIO", "ACTUAL_TYPED_ABSENCE",
        "ACTUAL_FORMAL_GATE_REJECTION", "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
        "ACTUAL_DUPLICATE_INVOCATION"]
    driver_path = protocol.get("driver_path")
    source_rows = [row for row in coverage.get("successor_assertion_sites", [])
                   if row.get("path") == driver_path]
    source_ids = {row.get("id") for row in source_rows}
    transport_ids = coverage.get("context_transport_assertion_ids")
    expected_transport = sorted(transport_ids or [])
    expected_case_counts = {
        case_id: sum(authority_plan["case_site_hit_counts"][case_id].values())
        for case_id in case_order
    } if isinstance(authority_plan, dict) else {}

    def validate(plan_protocol: dict[str, Any], plan_coverage: dict[str, Any],
                 plan_driver_source: str) -> dict[str, Any]:
        hit = plan_coverage.get("successor_assertion_runtime_hit_plan", {})
        actual_plan = hit.get("authority_case_hit_plan")
        authority_contract = plan_protocol.get("authority_case_execution_contract")
        site_rows = [row for row in plan_coverage.get(
            "successor_assertion_sites", [])
            if row.get("path") == plan_protocol.get("driver_path")]
        ids = {row.get("id") for row in site_rows}
        transport = plan_coverage.get("context_transport_assertion_ids")
        if not isinstance(transport, list) or len(transport) != 23 or \
                len(set(transport)) != 23 or set(transport) != set(
                    hit.get("context_transport", {}).get("site_ids", [])):
            raise RuntimeError("context transport source-site ID set mismatch")
        if not isinstance(actual_plan, dict) or \
                hit.get("schema") != \
                    "vnext-t2-independent-negative-assertion-hit-plan-r8" or \
                actual_plan.get("case_order") != case_order or \
                actual_plan.get("source_site_count") != 175 or \
                actual_plan.get("nonzero_site_count") != 75 or \
                actual_plan.get("expected_hit_count") != 118 or \
                actual_plan.get("context_transport_site_ids") != transport or \
                set(actual_plan.get("expected_phase_site_hits", {})) != ids or \
                set(actual_plan.get("case_site_hit_counts", {})) != set(case_order):
            raise RuntimeError("authority case hit plan identity/count mismatch")
        phase_hit_map = hit.get("phase_site_hit_counts", {})
        if set(phase_hit_map) != set(hit.get("phase_order", [])):
            raise RuntimeError("phase source-site plan is incomplete")
        for phase in phases:
            counts = phase_hit_map.get(phase)
            if not isinstance(counts, dict) or any(
                    counts.get(site_id) != 1 for site_id in transport):
                raise RuntimeError(f"transport site not hit once in {phase}")
        for phase, counts in phase_hit_map.items():
            if phase not in phases and any(counts.get(site_id, 0)
                                           for site_id in transport):
                raise RuntimeError(f"unexpected transport site hit in {phase}")
        phase_hits = actual_plan.get("expected_phase_site_hits", {})
        case_hits = actual_plan.get("case_site_hit_counts", {})
        if set(phase_hits) != ids or any(
                not isinstance(count, int) or count < 0
                for count in phase_hits.values()):
            raise RuntimeError("authority phase site map is not exact/zero-filled")
        merged = {site_id: 0 for site_id in ids}
        case_totals = {}
        for case_id in case_order:
            hits = case_hits.get(case_id)
            if not isinstance(hits, dict) or set(hits) != ids or any(
                    not isinstance(count, int) or count < 0
                    for count in hits.values()):
                raise RuntimeError(f"authority case site map is not zero-filled: {case_id}")
            case_totals[case_id] = sum(hits.values())
            for site_id, count in hits.items():
                merged[site_id] += count
        if merged != phase_hits or sum(merged.values()) != 118 or \
                sum(value > 0 for value in merged.values()) != 75 or \
                case_totals["PARENT_STALE"] != 38 or \
                sum(case_hits["PARENT_STALE"][site_id]
                    for site_id in transport) != 23 or any(
                        sum(case_hits[case_id][site_id] for site_id in transport)
                        != (23 if case_id == "PARENT_STALE" else 0)
                        for case_id in case_order):
            raise RuntimeError("authority 9-case measured-hit allocation plan mismatch")
        expected_contract = {
            "schema": "vnext-t2-authority-case-resumable-execution-r2",
            "phase": "actual_formal_authority",
            "case_order": case_order,
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
            "expected_case_hit_counts_static_plan": case_totals,
            "context_transport_source_site_count": 23,
            "context_transport_site_ids": transport,
            "context_transport_formal_phase_order": phases,
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
        }
        if authority_contract != expected_contract:
            raise RuntimeError("authority case protocol contract differs from coverage map")

        transport_rows = [row for row in site_rows
                          if row.get("id") in set(transport)]
        transport_function_start = plan_driver_source.find(
            "function _t2_neg_require_transport!(facts)")
        if transport_function_start < 0:
            raise RuntimeError("transport assertion function is absent")
        transport_function_end = plan_driver_source.find(
            "\nend\n", transport_function_start)
        if transport_function_end < 0:
            raise RuntimeError("transport assertion function has no terminator")
        transport_function = plan_driver_source[
            transport_function_start:transport_function_end]
        function_start_line = plan_driver_source[:transport_function_start].count("\n") + 1
        transport_lines = [function_start_line + offset for offset, line in
            enumerate(transport_function.splitlines())
            if line.lstrip().startswith("@test ")]
        mapped_transport_lines = {row.get("line") for row in transport_rows}
        if len(transport_rows) != 23 or len(mapped_transport_lines) != 23 or \
                set(transport_lines) != mapped_transport_lines or any(
                    plan_driver_source.splitlines()[row["line"] - 1].strip()
                    != row.get("source_text") for row in transport_rows):
            raise RuntimeError("the 23 mapped transport source assertions drifted")
        measured_source_requirements = (
            "function Test.record(testset::T2NegAssertionSiteTestSet,",
            "site_id = get(T2_NEG_SITE_ID_BY_LINE, source.line, nothing)",
            "testset.hits[site_id] += 1",
            "hits = Dict{String,Int}(String(row.id) => 0",
            "function _t2_neg_assertion_site_hit_receipt(phase)",
            "hit_counts=Dict(sort(collect(testset.hits); by=first))",
            "site_counts[id] = delta",
            "_t2_neg_authority_case_complete!(case_id)",
            "T2_NEG_R6_CASE_PROGRESS_SCHEMA",
            "vnext-t2-authority-case-progress-r3",
            "recorded = Test.record(testset.inner, result)",
            "_t2_neg_authority_progress_note_result!(result, source, site_id)",
            '"event" => "assertion_result"',
            '"source_line" => source_line',
            '"source_file" => source_file',
            '"record_ordinal" => T2_NEG_R6_ACTIVE_RESULT_ORDINAL[]',
            '"record_completed" => true',
            '"monotonic_time_ns" => time_ns()',
            "per_assertion_events_match_counts",
        )
        if any(fragment not in plan_driver_source
               for fragment in measured_source_requirements) or \
                "authority_case_hit_plan" in plan_driver_source:
            raise RuntimeError("driver hit receipt is not sourced from Test.record")
        shard_start = plan_driver_source.find("function _t2_neg_run_shard(")
        shard_end = plan_driver_source.find("\nend\n", shard_start)
        shard_function = plan_driver_source[shard_start:shard_end]
        if shard_start < 0 or shard_end < 0 or \
                "if mode != \"authority\" ||" not in shard_function or \
                "T2_NEG_R6_SELECTED_AUTHORITY_CASE[] ==" not in shard_function or \
                "first(T2_NEG_R6_PROGRESS_CASE_ORDER)" not in shard_function or \
                "_t2_neg_require_transport!(rebuilt.transport_facts)" not in shard_function:
            raise RuntimeError("transport assertion execution is not shard/case gated")
        controller_required = (
            "observed_raw != expected_summary",
            "complete.get(\"assertion_site_hit_counts_observed\")",
            "merged != expected_full",
            "sum(merged.values()) != 118",
            "sum(count > 0 for count in merged.values()) != 75",
            "verify_authority_resume_ancestry(",
            "source_case_dir.resolve().is_relative_to(resume_from.resolve())",
            "prior_final.get(\"inputs_after\")",
            "summarize_authority_case_progress_prefix(",
            '"valid_flushed_partial_prefix"',
            '"partial_actual_source_hit_count_observed"',
            '"authority_case_wall_budget_seconds": authority_case_timeout',
        )
        if any(fragment not in controller_source for fragment in controller_required):
            raise RuntimeError("authority receipt/replay runtime gates are incomplete")
        return {"case_order": case_order, "authority_source_site_count": len(ids),
                "case_zero_fill_count": 9 * len(ids),
                "case_hit_counts_static_plan": case_totals,
                "authority_nonzero_site_count_static_plan": 75,
                "authority_hit_count_static_plan": 118,
                "transport_site_count": 23,
                "transport_hits_per_formal_phase_static_plan": 23,
                "transport_total_across_four_phases_static_plan": 92,
                "transport_hits_in_authority_static_plan": 23,
                "parent_stale_total_hits_static_plan": 38,
                "driver_hit_source": "Test.record actual results",
                "actual_hits": "pending_julia_execution"}

    result = validate(protocol, coverage, driver_source)
    for label, mutate_protocol, mutate_coverage, mutate_driver in (
            ("authority transport map missing ID rejected", None,
             lambda value: value["context_transport_assertion_ids"].pop(), None),
            ("authority transport map extra ID rejected", None,
             lambda value: value["context_transport_assertion_ids"].append(
                 "NEW-ACT-FAKE-TRANSPORT"), None),
            ("authority transport phase hit drift rejected", None,
             lambda value: value["successor_assertion_runtime_hit_plan"]
                 ["phase_site_hit_counts"]["actual_formal_fault_n10"]
                 .update({"NEW-ACT-087": 0}), None),
            ("authority transport moved to wrong case rejected", None,
             lambda value: value["successor_assertion_runtime_hit_plan"]
                 ["authority_case_hit_plan"]["case_site_hit_counts"]
                 ["PARENT_STALE"].update({"NEW-ACT-087": 0}), None),
            ("authority protocol transport total drift rejected",
             lambda value: value["authority_case_execution_contract"].update(
                 context_transport_total_hits_across_four_formal_phases_static_plan=91),
             None, None),
            ("authority runtime Test.record counter removal rejected", None,
             None, lambda value: value.replace(
                 "testset.hits[site_id] += 1", "testset.hits[site_id] += 0", 1)),
            ("authority transport function source drift rejected", None,
             None, lambda value: value.replace(
                 "@test facts.context_authorization_join",
                 "@test facts.context_authorization_join_drift", 1)),
            ("authority flushed per-record event removal rejected", None,
             None, lambda value: value.replace(
                 '"event" => "assertion_result"',
                 '"event" => "removed_assertion_result"', 1)),
            ("authority per-record source line drift rejected", None,
             None, lambda value: value.replace(
                 '"source_line" => source_line',
                 '"source_line" => 0', 1))):
        changed_protocol = copy.deepcopy(protocol)
        changed_coverage = copy.deepcopy(coverage)
        if mutate_protocol is not None:
            mutate_protocol(changed_protocol)
        if mutate_coverage is not None:
            mutate_coverage(changed_coverage)
        changed_driver = (driver_source if mutate_driver is None else
                          mutate_driver(driver_source))
        expect_reject(label,
            lambda p=changed_protocol, c=changed_coverage, s=changed_driver:
                validate(p, c, s), controls)
    return {"status": "pass", **result, "negative_controls": 9}


def verify_authority_case_receipt_synthetic_contract(
        controller: Any, protocol: dict[str, Any], coverage: dict[str, Any],
        positive: dict[str, Any], controls: list[dict[str, str]]) -> dict[str, Any]:
    if not ATTEMPT9C_TRANSPORT.is_file():
        raise RuntimeError("attempt9c transport evidence is missing for synthetic fixture")
    plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    case_id = "PARENT_STALE"
    source_ids = {row["id"] for row in coverage["successor_assertion_sites"]
                  if row.get("path") == protocol["driver_path"]}
    map_sha = protocol["coverage_map"]["sha256"]
    driver_sha = protocol["inputs"][protocol["driver_path"]]["sha256"]
    transport_ids = set(plan["context_transport_site_ids"])
    authority_pairs = []
    for path_key, sha_key in (("manifest_path", "manifest_sha256"),
            ("verification_path", "verification_sha256"),
            ("candidate_path", "candidate_sha256"),
            ("package_path", "package_sha256")):
        authority_pairs.extend([str(positive[path_key]), positive[sha_key]])
    julia_prefix = [protocol["julia_executable"], f"--project={ROOT}",
        "--startup-file=no", "--history-file=no", "--threads=1"]
    transport_observation = json.loads(
        ATTEMPT9C_TRANSPORT.read_text(encoding="utf-8"))
    if transport_observation.get("shard") != "authority":
        raise RuntimeError("attempt9c context transport fixture has wrong shard")

    def make_fixture(case_dir: Path, *, hit_mutator=None, progress_mutator=None,
                     phase_mutator=None, stdout_mutator=None,
                     summary_map_sha: str = map_sha,
                     summary_driver_sha: str = driver_sha) -> tuple[list[str], dict[str, Any]]:
        artifacts = case_dir / "artifacts"
        artifacts.mkdir(parents=True)
        context = case_dir / "baseline_context.bin"
        context.write_bytes(b"synthetic-context\n")
        authorization = case_dir / "authorization.json"
        authorization.write_bytes(b"synthetic-authorization\n")
        context_sha = hashlib.sha256(context.read_bytes()).hexdigest()
        authorization_sha = hashlib.sha256(authorization.read_bytes()).hexdigest()
        observations_path = artifacts / "observations.jsonl"
        observations_path.write_text(json.dumps({"case_id": case_id}) + "\n",
                                     encoding="utf-8", newline="\n")
        transport_path = artifacts / "context_transport_observation.json"
        transport_path.write_text(json.dumps(transport_observation,
            sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8", newline="\n")
        header = {"schema": "vnext-t2-authority-case-progress-r3",
            "event": "header", "phase": "actual_formal_authority",
            "selected_case_id": case_id, "source_path": plan["source_path"],
            "driver_version": "independent-actual-negative-r6-authority-record-progress",
            "expected_case_ids": [case_id], "source_sha256": summary_driver_sha,
            "coverage_map_sha256": summary_map_sha,
            "site_ids": sorted(source_ids),
            "actual_hit_counts_are_measured": True, "status": "progress_only",
            "per_assertion_record_events_flushed": True,
            "formal_t2_accepted": False}
        observed_hits = dict(plan["case_site_hit_counts"][case_id])
        observed_progress_hits = dict(observed_hits)
        for site_id in transport_ids:
            observed_progress_hits[site_id] -= 1
        begin = {"event": "case_begin", "phase": "actual_formal_authority",
            "selected_case_id": case_id, "case_id": case_id, "sequence": 1,
            "monotonic_time_ns": 1, "status": "running",
            "progress_events_are_record_level": True,
            "formal_t2_accepted": False}
        hit_total = sum(observed_progress_hits.values())
        source_rows_by_id = {row["id"]: row for row in coverage[
            "successor_assertion_sites"] if row.get("path") == plan["source_path"]}
        event_rows = []
        running_site_hits = {site_id: 0 for site_id in source_ids}
        record_ordinal = 0
        for site_id in sorted(observed_progress_hits):
            for _ in range(observed_progress_hits[site_id]):
                record_ordinal += 1
                running_site_hits[site_id] += 1
                event_rows.append({
                    "schema": "vnext-t2-authority-case-progress-r3",
                    "event": "assertion_result",
                    "phase": "actual_formal_authority",
                    "selected_case_id": case_id, "case_id": case_id,
                    "record_ordinal": record_ordinal,
                    "source_file": "actual_formal_negative_driver_r6.jl",
                    "source_line": source_rows_by_id[site_id]["line"],
                    "site_id": site_id,
                    "site_hit_count_for_case_observed": running_site_hits[site_id],
                    "result_class": "pass", "record_completed": True,
                    "monotonic_time_ns": record_ordinal + 1,
                    "formal_t2_accepted": False})
        complete = {"event": "case_complete", "phase": "actual_formal_authority",
            "selected_case_id": case_id, "case_id": case_id, "sequence": 1,
            "monotonic_time_ns": record_ordinal + 2, "status": "completed",
            "case_completed": True, "formal_t2_accepted": False,
            "all_recorded_assertions_passed_observed": True,
            "unmapped_assertion_source_count_observed": 0,
            "assertion_site_hit_counts_observed": observed_progress_hits,
            "assertion_result_record_count_observed": record_ordinal,
            "assertion_site_hit_count_observed": hit_total,
            "assertion_result_count_observed": hit_total,
            "per_assertion_events_match_counts": True,
            "assertion_result_counts_observed": {"pass": hit_total,
                "fail": 0, "error": 0, "broken": 0, "other": 0}}
        progress_rows = [header, begin, *event_rows, complete]
        if progress_mutator is not None:
            progress_mutator(progress_rows)
        progress_path = artifacts / "case_progress.jsonl"
        progress_path.write_text("".join(json.dumps(row, sort_keys=True,
            separators=(",", ":")) + "\n" for row in progress_rows),
            encoding="utf-8", newline="\n")
        if hit_mutator is not None:
            hit_mutator(observed_hits)
        summary = {"schema": "vnext-t2-independent-actual-negative-shard-summary-r5",
            "status": "pass", "shard": "authority",
            "observed_case_ids": [case_id], "observed_case_count": 1,
            "formal_t2_accepted": False, "physical_acceptance": False,
            "scientific_acceptance": False, "context_sha256": context_sha,
            "context_unchanged": True, "source_revalidation_status": "source_ready",
            "rebuilt_input_full_content_join": True,
            "producer_package_unchanged": True,
            "candidate_receipt_unchanged": True, "package_wire_unchanged": True,
            "prior_ledger_unchanged": True,
            "assertion_site_hit_receipt_schema": "vnext-t2-source-site-hit-receipt-r1",
            "assertion_site_hit_phase": "actual_formal_authority",
            "assertion_site_hit_source_path": plan["source_path"],
            "assertion_site_hit_source_sha256": summary_driver_sha,
            "assertion_site_hit_coverage_map_sha256": summary_map_sha,
            "assertion_site_hit_counts": dict(observed_hits),
            "assertion_site_hit_count_observed": sum(observed_hits.values()),
            "unmapped_assertion_sources": [],
            "authority_case_progress_path": "case_progress.jsonl",
            "authority_case_progress_sha256": controller.file_receipt(
                progress_path)["sha256"],
            "observation_file_sha256": controller.file_receipt(
                observations_path)["sha256"],
            "context_transport_observation_sha256": controller.file_receipt(
                transport_path)["sha256"]}
        summary_path = artifacts / "summary.json"
        summary_path.write_text(json.dumps(summary, sort_keys=True,
            separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
        if summary_map_sha != map_sha:
            header["coverage_map_sha256"] = summary_map_sha
        stdout_path = case_dir / "stdout.raw"
        stderr_path = case_dir / "stderr.raw"
        summary_line = "VNEXT_T2_NEGATIVE_SHARD_SUMMARY=" + json.dumps(
            summary, sort_keys=True, separators=(",", ":"))
        stdout_lines = ["VNEXT_T2_NEGATIVE_CASE_PROGRESS=" + json.dumps(row,
            sort_keys=True, separators=(",", ":")) for row in progress_rows]
        stdout_lines.extend([summary_line,
            "VNEXT_T2_ACTUAL_FORMAL_SHARD=PASS mode=authority"])
        stdout_text = "\n".join(stdout_lines) + "\n"
        if stdout_mutator is not None:
            stdout_text = stdout_mutator(stdout_text)
        stdout_path.write_text(stdout_text, encoding="utf-8", newline="\n")
        stderr_path.write_bytes(b"")
        command = controller.build_actual_formal_shard_command(
            julia_prefix, f"authority-case:{case_id}", authority_pairs,
            context, context_sha, authorization, authorization_sha, artifacts,
            ROOT / protocol["coverage_map"]["path"], map_sha)
        phase = {"name": f"actual_formal_authority_case_{case_id}",
            "stop_reason": "natural_exit", "exit_code": 0,
            "residual_heavy_processes": [], "working_set_limit_bytes":
                2_147_483_648, "timeout_seconds": 2400.0, "seconds": 1.0,
            "peak_process_tree_working_set_bytes": 4096,
            "stdout": controller.file_receipt(stdout_path),
            "stderr": controller.file_receipt(stderr_path),
            "command": command}
        if phase_mutator is not None:
            phase_mutator(phase)
        (case_dir / "phase.json").write_text(json.dumps(phase,
            sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8", newline="\n")
        return command, summary

    def exercise(name: str, *, hit_mutator=None, progress_mutator=None,
                 phase_mutator=None, stdout_mutator=None,
                 summary_map_sha: str = map_sha,
                 summary_driver_sha: str = driver_sha,
                 verify_case_id: str = case_id) -> None:
        with tempfile.TemporaryDirectory(prefix="t2-authority-receipt-") as raw:
            case_dir = Path(raw) / "case"
            case_dir.mkdir()
            command, _ = make_fixture(case_dir, hit_mutator=hit_mutator,
                progress_mutator=progress_mutator, phase_mutator=phase_mutator,
                stdout_mutator=stdout_mutator,
                summary_map_sha=summary_map_sha,
                summary_driver_sha=summary_driver_sha)
            controller.verify_authority_case_receipt(verify_case_id, case_dir,
                command, coverage, coverage_map_sha256=map_sha,
                driver_sha256=driver_sha, context_sha256=hashlib.sha256(
                    b"synthetic-context\n").hexdigest(),
                authorization_sha256=hashlib.sha256(
                    b"synthetic-authorization\n").hexdigest(),
                authority_path_hash_pairs=authority_pairs)

    with tempfile.TemporaryDirectory(prefix="t2-authority-valid-") as raw:
        case_dir = Path(raw) / "case"
        case_dir.mkdir()
        command, _ = make_fixture(case_dir)
        summary, hits = controller.verify_authority_case_receipt(case_id,
            case_dir, command, coverage, coverage_map_sha256=map_sha,
            driver_sha256=driver_sha,
            context_sha256=hashlib.sha256(b"synthetic-context\n").hexdigest(),
            authorization_sha256=hashlib.sha256(
                b"synthetic-authorization\n").hexdigest(),
            authority_path_hash_pairs=authority_pairs)
        if hits != plan["case_site_hit_counts"][case_id] or \
                summary.get("assertion_site_hit_count_observed") != 38:
            raise RuntimeError("synthetic valid authority Test.record receipt mismatch")
    expect_reject("authority receipt missing source site rejected",
            lambda: exercise("missing", hit_mutator=lambda m: m.pop(sorted(source_ids)[0])),
        controls)
    expect_reject("authority receipt extra source site rejected",
        lambda: exercise("extra", hit_mutator=lambda m: m.update({
            "NEW-ACT-FAKE": 1})), controls)
    expect_reject("authority receipt wrong source hit rejected",
        lambda: exercise("wrong-count", hit_mutator=lambda m: m.update({
            "NEW-ACT-087": m["NEW-ACT-087"] + 1})), controls)
    expect_reject("authority progress wrong-case hit rejected",
        lambda: exercise("wrong-progress", progress_mutator=lambda rows:
            rows[-1]["assertion_site_hit_counts_observed"].update(
                {"NEW-ACT-087": rows[-1]["assertion_site_hit_counts_observed"]
                 ["NEW-ACT-087"] + 1})), controls)
    expect_reject("authority partial progress receipt rejected",
        lambda: exercise("partial-progress", progress_mutator=lambda rows:
            rows.pop()), controls)
    expect_reject("authority partial child phase rejected",
        lambda: exercise("partial-phase", phase_mutator=lambda p: p.update(
            stop_reason="phase_wall_timeout", exit_code=15)), controls)
    expect_reject("authority PASS marker missing rejected",
        lambda: exercise("missing-pass", stdout_mutator=lambda s:
            s.replace("VNEXT_T2_ACTUAL_FORMAL_SHARD=PASS mode=authority\n", "")),
        controls)
    expect_reject("authority map SHA drift rejected",
        lambda: exercise("map-sha", summary_map_sha="0" * 64), controls)
    expect_reject("authority source SHA drift rejected",
        lambda: exercise("source-sha", summary_driver_sha="0" * 64), controls)
    expect_reject("authority receipt wrong case ID rejected",
        lambda: exercise("wrong-case", verify_case_id="PARENT_FOREIGN"), controls)
    return {"status": "pass_synthetic_receipts_only",
            "positive_case": case_id,
            "positive_source_site_count": len(source_ids),
            "positive_observed_hit_count": sum(
                plan["case_site_hit_counts"][case_id].values()),
            "negative_controls": 10,
            "actual_julia_hits": False,
            "actual_hits_pending": True}


def verify_authority_partial_prefix_synthetic_contract(
        controller: Any, protocol: dict[str, Any], coverage: dict[str, Any],
        controls: list[dict[str, str]]) -> dict[str, Any]:
    plan = coverage["successor_assertion_runtime_hit_plan"][
        "authority_case_hit_plan"]
    case_id = "PARENT_STALE"
    source_path = protocol["driver_path"]
    source_sha = protocol["inputs"][source_path]["sha256"]
    map_sha = protocol["coverage_map"]["sha256"]
    source_rows = [row for row in coverage["successor_assertion_sites"]
                   if row.get("path") == source_path]
    source_ids = sorted(row["id"] for row in source_rows)
    by_id = {row["id"]: row for row in source_rows}
    expected = dict(plan["case_site_hit_counts"][case_id])
    for site_id in plan["context_transport_site_ids"]:
        expected[site_id] -= 1
    header = {
        "schema": "vnext-t2-authority-case-progress-r3",
        "event": "header", "phase": "actual_formal_authority",
        "selected_case_id": case_id, "source_path": source_path,
        "driver_version": "independent-actual-negative-r6-authority-record-progress",
        "expected_case_ids": [case_id], "source_sha256": source_sha,
        "coverage_map_sha256": map_sha, "site_ids": source_ids,
        "actual_hit_counts_are_measured": True,
        "per_assertion_record_events_flushed": True,
        "status": "progress_only", "formal_t2_accepted": False,
    }
    begin = {
        "schema": "vnext-t2-authority-case-progress-r3",
        "event": "case_begin", "phase": "actual_formal_authority",
        "selected_case_id": case_id, "case_id": case_id, "sequence": 1,
        "monotonic_time_ns": 1, "progress_events_are_record_level": True,
        "status": "running", "formal_t2_accepted": False,
    }
    events = []
    ordinal = 0
    for site_id in source_ids:
        if expected[site_id] <= 0:
            continue
        ordinal += 1
        events.append({
            "schema": "vnext-t2-authority-case-progress-r3",
            "event": "assertion_result", "phase": "actual_formal_authority",
            "selected_case_id": case_id, "case_id": case_id,
            "record_ordinal": ordinal,
            "source_file": Path(source_path).name,
            "source_line": by_id[site_id]["line"], "site_id": site_id,
            "site_hit_count_for_case_observed": 1,
            "result_class": "pass", "record_completed": True,
            "monotonic_time_ns": ordinal + 1, "formal_t2_accepted": False,
        })
        if ordinal == 3:
            break
    rows = [header, begin, *events]
    measured = controller.summarize_authority_case_progress_prefix(
        case_id, rows, coverage, coverage_map_sha256=map_sha,
        driver_sha256=source_sha)
    if measured.get("status") != "valid_flushed_partial_prefix" or \
            measured.get("event_count") != 3 or \
            measured.get("source_site_count_zero_filled") != 175 or \
            measured.get("source_site_hit_count_observed") != 3 or \
            measured.get("case_complete_seen") is not False or \
            measured.get("formal_t2_accepted") is not False:
        raise RuntimeError("synthetic partial Test.record prefix was not measured faithfully")

    def reject_mutation(label: str, mutate: Callable[[list[dict[str, Any]]], None]) -> None:
        changed = copy.deepcopy(rows)
        mutate(changed)
        result = controller.summarize_authority_case_progress_prefix(
            case_id, changed, coverage, coverage_map_sha256=map_sha,
            driver_sha256=source_sha)
        if result.get("status", "").startswith("valid_"):
            raise RuntimeError(f"partial progress negative control accepted: {label}")
        controls.append({"name": label, "status": "pass",
                         "observed": result.get("status", "invalid")})

    reject_mutation("partial event wrong source line rejected",
        lambda value: value[2].update(source_line=0))
    reject_mutation("partial event wrong site ID rejected",
        lambda value: value[2].update(site_id="NEW-ACT-FAKE"))
    reject_mutation("partial event ordinal gap rejected",
        lambda value: value[3].update(record_ordinal=9))
    reject_mutation("partial event wrong source file rejected",
        lambda value: value[2].update(source_file="other_driver.jl"))
    reject_mutation("partial event result class rejected",
        lambda value: value[2].update(result_class="planned"))
    reject_mutation("partial map SHA drift rejected",
        lambda value: value[0].update(coverage_map_sha256="0" * 64))
    reject_mutation("partial source SHA drift rejected",
        lambda value: value[0].update(source_sha256="0" * 64))
    reject_mutation("partial case identity drift rejected",
        lambda value: value[1].update(case_id="PARENT_FOREIGN"))
    return {"status": "pass_synthetic_partial_prefix_only",
            "case_id": case_id,
            "source_site_count_zero_filled": 175,
            "actual_record_events_in_positive_prefix": 3,
            "partial_case_is_reusable": False,
            "negative_controls": 8,
            "actual_julia_hits": False}


def verify_authority_resume_ancestry_synthetic_contract(
        controller: Any, protocol: dict[str, Any], protocol_path: Path,
        controls: list[dict[str, str]]) -> dict[str, Any]:
    protocol_receipt = controller.file_receipt(protocol_path)
    protocol_sha256 = protocol_receipt["sha256"]
    current_inputs = controller.input_receipts(protocol)
    repository_head = protocol["repository_head"]
    expected_cases = list(controller.AUTHORITY_CASE_ORDER)
    if len(expected_cases) != 9:
        raise RuntimeError("resume synthetic case order differs from nine-case plan")

    def make_parent(root: Path, *, case_status: str =
                    "completed_natural_exit_zero", row_phase_override=None,
                    completed_ids=None, inputs_after=None,
                    phases_override=None, reverse_rows: bool = False,
                    missing_child_phase: bool = False,
                    protocol_sha_override: str | None = None) -> tuple[Path, dict[str, Any]]:
        root.mkdir(parents=True)
        authority = root / "actual_formal_authority"
        case_dir = authority / "cases" / expected_cases[0]
        case_dir.mkdir(parents=True)
        child_phase_path = case_dir / "phase.json"
        if not missing_child_phase:
            child_phase_path.write_text(json.dumps({
                "name": "actual_formal_authority_case_P\u0041RENT_STALE",
                "stop_reason": "natural_exit", "exit_code": 0,
                "formal_t2_accepted": False}, sort_keys=True,
                separators=(",", ":")) + "\n", encoding="utf-8", newline="\n")
        child_pin = controller.file_receipt(child_phase_path) \
            if child_phase_path.exists() else {"path": str(child_phase_path),
                                               "bytes": 0, "sha256": "0" * 64}
        if row_phase_override is not None:
            child_pin = row_phase_override
        rows = [{"case_id": expected_cases[0], "status": case_status,
                 "phase": child_pin}]
        if reverse_rows:
            rows.append({"case_id": expected_cases[1],
                         "status": "partial_child", "phase": None})
            rows.reverse()
        authority_phase = {
            "schema": "vnext-t2-independent-negative-authority-case-phase-r1",
            "name": "actual_formal_authority",
            "stop_reason": "phase_wall_timeout",
            "exit_code": 15,
            "case_count_expected": 9,
            "case_rows": rows,
            "completed_case_ids": (completed_ids if completed_ids is not None
                else ([expected_cases[0]] if case_status in (
                    "completed_natural_exit_zero", "completed_reused") else [])),
            "formal_t2_accepted": False}
        authority_phase_path = authority / "phase.json"
        authority_phase_path.write_text(json.dumps(authority_phase,
            sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8", newline="\n")
        start = {"repository_head": repository_head,
            "protocol_expected_sha256": protocol_sha_override or protocol_sha256,
            "protocol": protocol_receipt, "inputs_before": current_inputs}
        final = {"repository_head_before": repository_head,
            "repository_head_after": repository_head,
            "protocol": protocol_receipt,
            "inputs_before": current_inputs,
            "inputs_after": current_inputs if inputs_after is None else inputs_after,
            "formal_t2_accepted": False,
            "phases": [authority_phase] if phases_override is None else phases_override}
        (root / "pipeline_start.json").write_text(json.dumps(start,
            sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8", newline="\n")
        (root / "pipeline_final.json").write_text(json.dumps(final,
            sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8", newline="\n")
        return root, authority_phase

    with tempfile.TemporaryDirectory(prefix="t2-authority-resume-valid-",
            dir=T2_EVIDENCE_ROOT) as raw:
        resume_root, _ = make_parent(Path(raw) / "parent")
        _, case_roots = controller.verify_authority_resume_ancestry(
            resume_root, resume_root / "actual_formal_authority",
            protocol_path, protocol_sha256, current_inputs, repository_head,
            expected_cases)
        if list(case_roots) != [expected_cases[0]]:
            raise RuntimeError("valid complete case did not join its parent ancestry")

    def exercise(name: str, **kwargs: Any) -> bool:
        with tempfile.TemporaryDirectory(prefix="t2-authority-resume-negative-",
                dir=T2_EVIDENCE_ROOT) as raw:
            resume_root, _ = make_parent(Path(raw) / "parent", **kwargs)
            try:
                _, case_roots = controller.verify_authority_resume_ancestry(
                    resume_root, resume_root / "actual_formal_authority",
                    protocol_path, protocol_sha256, current_inputs,
                    repository_head, expected_cases)
            except (OSError, RuntimeError, ValueError, KeyError, TypeError):
                return True
            if name == "mismatched child receipt is not reusable":
                return expected_cases[0] not in case_roots
            if name == "partial child receipt is not reusable":
                return expected_cases[0] not in case_roots
            return False

    def changed_child_pin() -> dict[str, Any]:
        return {"path": "stale/phase.json", "bytes": 1,
                "sha256": "0" * 64}
    def missing_parent_phase() -> list[dict[str, Any]]:
        return []
    changed_inputs = dict(current_inputs)
    changed_inputs["synthetic/input"] = {"path": "synthetic/input",
        "bytes": 1, "sha256": "0" * 64}
    checks = [
        ("mismatched child receipt is not reusable", {
            "row_phase_override": changed_child_pin()}),
        ("partial child receipt is not reusable", {
            "case_status": "partial_child", "completed_ids": []}),
        ("parent pipeline phase join missing rejected", {
            "phases_override": missing_parent_phase()}),
        ("resume input closure drift rejected", {
            "inputs_after": changed_inputs}),
        ("completed case with missing child phase rejected", {
            "missing_child_phase": True}),
        ("reordered parent case rows rejected", {
            "reverse_rows": True}),
        ("parent protocol SHA drift rejected", {
            "protocol_sha_override": "0" * 64}),
    ]
    for name, kwargs in checks:
        accepted = exercise(name, **kwargs)
        if not accepted:
            raise RuntimeError(f"authority resume negative control accepted: {name}")
        controls.append({"name": name, "status": "pass",
                         "observed": "rejected_or_not_reusable"})
    return {"status": "pass_synthetic_ancestry_only",
            "resumed_case_count_positive": 1,
            "negative_controls": len(checks),
            "partial_cases_are_joinable": False,
            "actual_julia_resume": False}


def verify_python_cache_exclusion(protocol: dict[str, Any],
                                  command_data: dict[str, Any],
                                  execution_context: dict[str, Any]) -> dict[str, Any]:
    cache_dir = TEST_ROOT / "__pycache__"
    if not cache_dir.is_dir():
        raise RuntimeError("generated Python cache directory unexpectedly absent")
    cache_entries = sorted(cache_dir.rglob("*"))
    if any(not path.is_file() for path in cache_entries):
        raise RuntimeError("Python cache directory has a nested/third entry")
    actual = [file_receipt(path) for path in cache_entries]
    contract = protocol.get("python_cache_exclusion")
    if not isinstance(contract, dict) or \
            contract.get("schema") != "vnext-t2-generated-python-cache-exclusion-r1" or \
            contract.get("status") != "excluded_from_current_input_closure_not_cleaned" or \
            contract.get("cleaned") is not False or \
            contract.get("excluded_files") != EXPECTED_GENERATED_CACHE or \
            contract.get("excluded_file_count") != 2 or actual != EXPECTED_GENERATED_CACHE:
        raise RuntimeError("generated Python cache exact inventory/pins differ")
    excluded_paths = {row["path"] for row in EXPECTED_GENERATED_CACHE}
    if excluded_paths.intersection(protocol.get("inputs", {})):
        raise RuntimeError("generated Python cache was included as a current input")
    freeze_entry = contract.get("freeze_entrypoint", {})
    if freeze_entry.get("mode") != "direct_script_as_main" or \
            freeze_entry.get("path") != (
                "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                "freeze_independent_negative_protocol_r9.py") or \
            freeze_entry.get("argv0_matches_source") is not True or \
            freeze_entry.get("sys_dont_write_bytecode") is not True or \
            freeze_entry.get("path") not in protocol["inputs"]:
        raise RuntimeError("freezer direct-source entrypoint receipt mismatch")
    expected_qa_prefix = [sys.executable, "-B",
                          str(TEST_ROOT / "static_qa_independent_negative_r9.py")]
    if contract.get("static_qa_direct_argv_prefix") != expected_qa_prefix or \
            execution_context != {
                "mode": "direct_script_as_main",
                "path": str(TEST_ROOT / "static_qa_independent_negative_r9.py"),
                "argv0_matches_source": True,
                "sys_dont_write_bytecode": True}:
        raise RuntimeError("static QA did not execute directly from pinned source")
    argv = command_data.get("argv")
    controller_path = ROOT / protocol["controller_path"]
    if not isinstance(argv, list) or len(argv) < 3 or \
            argv[0] != sys.executable or argv[1] != "-B" or \
            Path(argv[2]).resolve() != controller_path.resolve():
        raise RuntimeError("formal controller argv may load cached module bytecode")

    cached_module_names = {Path(row["path"]).name.split(".")[0]
                           for row in EXPECTED_GENERATED_CACHE}
    for relative in protocol.get("python_parse_paths", []):
        source_path = ROOT / relative
        tree = ast.parse(source_path.read_text(encoding="utf-8"),
                         filename=str(source_path))
        for node in ast.walk(tree):
            imported = []
            if isinstance(node, ast.Import):
                imported.extend(alias.name.split(".")[0]
                                 for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.append(node.module.split(".")[0])
            elif isinstance(node, ast.Call) and node.args and \
                    isinstance(node.args[0], ast.Constant) and \
                    isinstance(node.args[0].value, str) and \
                    (getattr(node.func, "id", "") == "__import__" or
                     (isinstance(node.func, ast.Attribute) and
                      node.func.attr in {
                          "import_module", "spec_from_file_location",
                          "run_module"})):
                imported.append(node.args[0].value.split(".")[0])
            if cached_module_names.intersection(imported):
                raise RuntimeError(
                    f"generated cache subject imported as a module by {relative}")
    if contract.get("cache_module_import_targets") != [] or \
            contract.get("qa_dynamic_import_module_names") != [
                "vnext_t2_controller_r10", "vnext_t2_projection24_reuse_r4"]:
        raise RuntimeError("dynamic Python module loader targets are not explicit")
    qa_source = (TEST_ROOT / "static_qa_independent_negative_r9.py").read_text(
        encoding="utf-8")
    if 'spec_from_file_location("vnext_t2_controller_r10", path)' not in qa_source or \
            '"vnext_t2_projection24_reuse_r4", path)' not in qa_source or \
            "spec_from_file_location(\"freeze_independent_negative_protocol_r4b\"" in qa_source or \
            "spec_from_file_location(\"static_qa_independent_negative_r4b\"" in qa_source:
        raise RuntimeError("Python source loader can target a cached entrypoint")
    return {"excluded_cache_file_count": 2,
            "excluded_cache_receipts": actual,
            "cache_files_are_current_inputs": False,
            "cache_cleaned": False,
            "direct_source_entrypoints": [
                freeze_entry["path"],
                "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                "static_qa_independent_negative_r9.py"],
            "cache_modules_imported_as_modules": [],
            "controller_and_projection_sources_hash_pinned_before_loader": True}


def verify_baseline_diagnostic_markers(protocol: dict[str, Any],
                                       source: str) -> None:
    expected = [
        "post_consumer_require_baseline.begin",
        "post_consumer_require_baseline.end",
        "baseline_second_up2_validate_input.begin",
        "baseline_second_up2_validate_input.end",
        "baseline_context_construction.begin",
        "baseline_context_construction.end",
        "baseline_context_serialization.begin",
        "baseline_context_serialization.end",
        "baseline_summary_complete",
    ]
    if protocol.get("baseline_diagnostic_marker_contract") != expected:
        raise RuntimeError("baseline marker contract list differs")
    occurrences = {
        "post_consumer_require_baseline": 2,
        "baseline_second_up2_validate_input": 2,
        "baseline_context_construction": 2,
        "baseline_context_serialization": 2,
        "baseline_summary_complete": 1,
    }
    if any(source.count(f'"{name}"') != count
           for name, count in occurrences.items()):
        raise RuntimeError("baseline diagnostic marker source count differs")
    if "time_ns()" not in source or "flush(io)" not in source or \
            "flush(stdout)" not in source:
        raise RuntimeError("baseline stage marker is not monotonic and flushed")
    run_start = source.index("function _t2_neg_run_baseline(")
    require_fn_start = source.index("function _t2_neg_require_baseline!(")
    require_fn_end = source.index("function _t2_neg_fault_case!(",
                                 require_fn_start)
    require_body = source[require_fn_start:require_fn_end]
    validation_begin = require_body.index('"baseline_second_up2_validate_input"')
    validation_call = require_body.index(
        "FusionConceptAI.vnext_t2_up2_validate_input_v2(build.input)")
    validation_end = require_body.index(
        '_t2_neg_stage_end("baseline_second_up2_validate_input"')
    require(validation_begin < validation_call < validation_end,
            "second input validation is not bracketed by markers")
    require_baseline = source.index("_t2_neg_require_baseline!(stream",
                                   run_start)
    assertion_begin = source.index(
        '_t2_neg_stage_begin("post_consumer_require_baseline")', run_start)
    assertion_end = source.index(
        '_t2_neg_stage_end("post_consumer_require_baseline"',
        assertion_begin)
    context_build = source.index("_t2_neg_context_body(live, result",
                                 run_start)
    context_build_begin = source.index(
        '_t2_neg_stage_begin("baseline_context_construction")', run_start)
    context_build_end = source.index(
        '_t2_neg_stage_end("baseline_context_construction"',
        context_build)
    context_write = source.index("_t2_neg_write_context(context_path, context)",
                                 run_start)
    context_write_begin = source.index(
        '_t2_neg_stage_begin("baseline_context_serialization")', run_start)
    context_write_end = source.index(
        '_t2_neg_stage_end("baseline_context_serialization"',
        context_write)
    summary_write = source.index("_t2_neg_write_summary(summary_path, summary)",
                                 run_start)
    summary_marker = source.index('"baseline_summary_complete"', run_start)
    if not (assertion_begin < require_baseline < assertion_end <
            context_build_begin < context_build < context_build_end <
            context_write_begin < context_write < context_write_end <
            summary_write < summary_marker):
        raise RuntimeError("baseline diagnostic markers do not bracket target work")


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
        "schema": "vnext-t2-independent-negative-static-qa-r6",
        "status": "fail", "julia_executed": False,
        "julia_parse_executed": False, "actual_model_attestation": "unavailable",
        "negative_controls": [],
    }
    script_path = Path(__file__).resolve()
    execution_context = {
        "mode": "direct_script_as_main" if __name__ == "__main__" else "imported",
        "path": str(script_path),
        "argv0_matches_source": Path(sys.argv[0]).resolve() == script_path,
        "sys_dont_write_bytecode": sys.dont_write_bytecode,
    }
    report["python_execution_context"] = execution_context
    try:
        protocol_path = Path(args.protocol).resolve()
        dispatch_path = Path(args.dispatch).resolve()
        command_path = Path(args.command).resolve()
        for path in (protocol_path, dispatch_path, command_path,
                     report_path.parent):
            path.relative_to(ROOT)
        protocol_receipt = file_receipt(protocol_path)
        require(protocol_receipt["sha256"] == args.protocol_sha256.lower(),
                "protocol SHA-256 mismatch")
        protocol = load_object(protocol_path)
        dispatch = load_object(dispatch_path)
        command_data = load_object(command_path)
        require(execution_context == {
                    "mode": "direct_script_as_main",
                    "path": str(TEST_ROOT /
                                "static_qa_independent_negative_r9.py"),
                    "argv0_matches_source": True,
                    "sys_dont_write_bytecode": True},
                "static QA was not run as direct source under -B")
        controls: list[dict[str, str]] = report["negative_controls"]
        require(protocol.get("schema") ==
                "vnext-t2-independent-negative-protocol-r4" and
                protocol.get("repository_head") == EXPECTED_HEAD,
                "current protocol schema or HEAD mismatch")
        require(command_data.get("schema") ==
                "vnext-t2-independent-negative-command-argv-r6" and
                command_data.get("kind") == "non_executable_command_data" and
                command_data.get("argv") == dispatch.get("command_argv") and
                command_data.get("environment") == dispatch.get("environment") and
                command_data.get("working_directory") == str(ROOT) and
                command_data.get("julia_started") is False and
                command_data.get("formal_t2_accepted") is False,
                "command artifact is not a non-executable argv data record")
        require(dispatch.get("schema") ==
                "vnext-t2-independent-negative-dispatch-r6" and
                dispatch.get("protocol") == protocol_receipt and
                dispatch.get("command") == file_receipt(command_path) and
                dispatch.get("julia_started") is False and
                dispatch.get("julia_lane_granted") is False,
                "r4 dispatch does not match static unexecuted freeze")
        checked_inputs = []
        for relative, expected in sorted(protocol["inputs"].items()):
            actual = file_receipt(ROOT / relative)
            require(actual == {"path": relative,
                               "bytes": expected.get("bytes"),
                               "sha256": expected.get("sha256")},
                    f"protocol input drift before any dynamic source load: {relative}")
            checked_inputs.append(actual)
        require(len(checked_inputs) == protocol.get("input_count"),
                "protocol current input inventory count mismatch")
        attempt8_failure_status = verify_attempt8_preflight_failure_basis(
            protocol)
        changed_attempt8_failure = copy.deepcopy(protocol)
        changed_attempt8_failure["attempt8_preflight_failure_basis"][
            "observed_preflight_argument_count"] = 16
        expect_reject("attempt8 14-argument interruption pin drift",
                      lambda: verify_attempt8_preflight_failure_basis(
                          changed_attempt8_failure), controls)
        attempt9_failure_status = verify_attempt9_projection_preflight_failure_basis(
            protocol)
        changed_attempt9_failure = copy.deepcopy(protocol)
        changed_attempt9_failure[
            "attempt9_projection_preflight_failure_basis"][
                "observed_exit_code"] = 0
        expect_reject("attempt9 projection natural-exit failure pin drift",
                      lambda: verify_attempt9_projection_preflight_failure_basis(
                          changed_attempt9_failure), controls)
        attempt9b_failure_status = verify_attempt9b_static_qa_failure_basis(
            protocol)
        changed_attempt9b_failure = copy.deepcopy(protocol)
        changed_attempt9b_failure["attempt9b_static_qa_failure_basis"][
            "observed_failure"]["message"] = "changed"
        expect_reject("attempt9b QA failure receipt mutation rejected",
                      lambda: verify_attempt9b_static_qa_failure_basis(
                          changed_attempt9b_failure), controls)
        attempt9c_interruption_status = \
            verify_attempt9c_authority_interruption_basis(protocol)
        authority_budget_delta_status = verify_authority_case_budget_delta(
            protocol)
        for name, field, value in (
                ("old authority child cap drift rejected",
                 "prior_case_timeout_seconds", 1199),
                ("new authority child cap drift rejected",
                 "new_case_timeout_seconds", 2401),
                ("authority invocation cap drift rejected",
                 "authority_invocation_timeout_seconds", 2399),
                ("authority coverage threshold change rejected",
                 "coverage_thresholds_changed", True),
                ("authority resource contract drift rejected",
                 "working_set_limit_bytes", 2_147_483_647),
                ("authority timeout policy drift rejected",
                 "effective_child_timeout_policy", "case_cap_only")):
            changed_budget = copy.deepcopy(protocol)
            changed_budget["authority_case_budget_change"][field] = value
            expect_reject(name, lambda p=changed_budget:
                          verify_authority_case_budget_delta(p), controls)
        changed_attempt9c_interruption = copy.deepcopy(protocol)
        changed_attempt9c_interruption[
            "attempt9c_authority_interruption_basis"][
                "assertion_completion_status"] = "completed"
        expect_reject("attempt9c timeout cannot be relabeled complete",
                      lambda: verify_attempt9c_authority_interruption_basis(
                          changed_attempt9c_interruption), controls)
        changed_attempt9c_observation = copy.deepcopy(protocol)
        changed_attempt9c_observation[
            "attempt9c_authority_interruption_basis"][
                "pre_assertion_observation"]["ledger_status"] = "pass"
        expect_reject("attempt9c pre-assertion observation cannot be mislabeled",
                      lambda: verify_attempt9c_authority_interruption_basis(
                          changed_attempt9c_observation), controls)
        projection_validator_delta_status = \
            verify_projection_validator_r3_r4_delta(protocol)
        changed_validator_delta = copy.deepcopy(protocol)
        changed_validator_delta["projection_validator_r3_r4_delta"][
            "non_schema_semantic_changes"] = 1
        expect_reject("projection validator non-schema diff rejected",
                      lambda: verify_projection_validator_r3_r4_delta(
                          changed_validator_delta), controls)
        controller_source = (ROOT / protocol["controller_path"]).read_text(
            encoding="utf-8")
        attempt11_budget_status = verify_attempt11_budget(
            protocol, dispatch, command_data, controller_source)
        controller_preflight_delta_status = \
            verify_controller_r9_r10_preflight_budget_delta(
                protocol, controller_source)
        changed_timeout_semantics = controller_source.replace(
            "if mode == \"preflight\":\n"
            "        return PREFLIGHT_PHASE_TIMEOUT_SECONDS",
            "if mode == \"preflight\":\n"
            "        return configured_default", 1)
        expect_reject("preflight timeout selector source mutation rejected",
                      lambda: verify_attempt11_source_timeout_contract(
                          changed_timeout_semantics), controls)
        changed_authority_timeout = controller_source.replace(
            "case_timeout = min(authority_case_timeout, remaining)",
            "case_timeout = authority_case_timeout", 1)
        expect_reject("authority timeout mutation outside attempt11 delta rejected",
                      lambda: verify_controller_r9_r10_preflight_budget_delta(
                          protocol, changed_authority_timeout), controls)
        controller_binding_delta_status = \
            verify_controller_r8_r9_authority_progress_delta(protocol)
        child_plan_status = verify_controller_child_script_plan(
            protocol, controller_source)
        changed_controller_delta = copy.deepcopy(protocol)
        changed_controller_delta["controller_r8_r9_authority_progress_delta"][
            "coverage_semantics_changed"] = True
        expect_reject("controller r8/r9 non-binding diff rejected",
                      lambda: verify_controller_r8_r9_authority_progress_delta(
                          changed_controller_delta), controls)
        changed_controller_budget = copy.deepcopy(protocol)
        changed_controller_budget["controller_r8_r9_authority_progress_delta"]\
            ["authority_case_wall_budget_delta"]["current_case_seconds"] = 1200
        expect_reject("controller delta cannot hide 2400s case cap drift",
                      lambda: verify_controller_r8_r9_authority_progress_delta(
                          changed_controller_budget), controls)
        changed_child_source = controller_source.replace(
            "validate_projection24_reuse_r4.py", "unplanned_child.py", 1)
        expect_reject("unplanned controller Python child rejected",
                      lambda: derive_controller_child_script_plan(
                          changed_child_source, protocol["phase_order"]),
                      controls)
        changed_child_phases = copy.deepcopy(protocol)
        changed_child_phases["phase_order"].remove(
            "projection24_cross_run_validation")
        expect_reject("controller child phase omission rejected",
                      lambda: verify_controller_child_script_plan(
                          changed_child_phases, controller_source), controls)
        verify_attempt7_interruption(protocol)
        cache_metrics = verify_python_cache_exclusion(
            protocol, command_data, execution_context)
        changed_loader_name = copy.deepcopy(protocol)
        changed_loader_name["python_cache_exclusion"][
            "qa_dynamic_import_module_names"][0] = "vnext_t2_controller_r9"
        expect_reject("stale r9 dynamic controller loader name rejected",
                      lambda: verify_python_cache_exclusion(
                          changed_loader_name, command_data, execution_context),
                      controls)
        cleanup_status = verify_attempt11_cleanup_receipt(protocol)
        changed_cleanup = copy.deepcopy(protocol)
        changed_cleanup["attempt11_cleanup_receipt"]["deleted_paths"] = [
            changed_cleanup["python_cache_exclusion"]["excluded_files"][0]["path"]]
        expect_reject("excluded cache mislabeled as cleaned rejected",
                      lambda: verify_attempt11_cleanup_receipt(
                          changed_cleanup), controls)
        for name, mutate in (
                ("generated cache stale SHA rejected",
                 lambda p: p["python_cache_exclusion"][
                     "excluded_files"][0].update(sha256="0" * 64)),
                ("third generated cache rejected",
                 lambda p: p["python_cache_exclusion"][
                     "excluded_files"].append({
                         "path": "test/GenomeV5/Integration/"
                                 "VNextT2FormalIndependentR1/__pycache__/third.pyc",
                         "bytes": 1, "sha256": "0" * 64})),
                ("excluded cache mislabeled cleaned rejected",
                 lambda p: p["python_cache_exclusion"].update(cleaned=True)),
                ("excluded cache reintroduced as runtime input rejected",
                 lambda p: p["inputs"].update({
                     EXPECTED_GENERATED_CACHE[0]["path"]:
                         EXPECTED_GENERATED_CACHE[0]}))):
            changed_cache = copy.deepcopy(protocol)
            mutate(changed_cache)
            expect_reject(name, lambda p=changed_cache:
                          verify_python_cache_exclusion(
                              p, command_data, execution_context), controls)
        for name, mutate in (
                ("phase budget 300 rejected", lambda p: p["resource_gates"].update(
                    phase_wall_seconds=300)),
                ("phase budget 600 rejected", lambda p: p["resource_gates"].update(
                    phase_wall_seconds=600)),
                ("preflight-only override missing rejected",
                 lambda p: p["resource_gates"].pop(
                     "phase_wall_timeout_overrides")),
                ("preflight timeout 599 rejected",
                 lambda p: p["resource_gates"][
                     "phase_wall_timeout_overrides"].update(
                         actual_formal_preflight=599)),
                ("preflight timeout 601 rejected",
                 lambda p: p["resource_gates"][
                     "phase_wall_timeout_overrides"].update(
                         actual_formal_preflight=601)),
                ("wrong phase timeout override rejected",
                 lambda p: p["resource_gates"][
                     "phase_wall_timeout_overrides"].update(
                         actual_formal_fault_n10=600)),
                ("extra phase timeout override rejected",
                 lambda p: p["resource_gates"][
                     "phase_wall_timeout_overrides"].update(
                         extra_phase=600)),
                ("authority phase budget drift rejected",
                 lambda p: p["resource_gates"].update(
                     authority_phase_wall_seconds=2401)),
                ("authority case budget drift rejected",
                 lambda p: p["resource_gates"].update(
                     authority_case_wall_seconds=2399)),
                ("memory cap drift rejected", lambda p: p["resource_gates"].update(
                    process_tree_working_set_bytes=2_147_483_647))):
            changed = copy.deepcopy(protocol)
            mutate(changed)
            expect_reject(name, lambda p=changed:
                          verify_attempt11_budget(p, dispatch, command_data,
                                                  controller_source), controls)
        changed_dispatch_budget = copy.deepcopy(dispatch)
        changed_dispatch_budget["resource_gates"][
            "phase_wall_timeout_overrides"]["actual_formal_preflight"] = 601
        expect_reject("dispatch preflight timeout override drift rejected",
                      lambda: verify_attempt11_budget(
                          protocol, changed_dispatch_budget, command_data,
                          controller_source), controls)
        changed_delta = copy.deepcopy(protocol)
        changed_delta["preflight_phase_budget_change"][
            "current_preflight_seconds"] = 599
        expect_reject("budget delta preflight timeout drift rejected",
                      lambda: verify_attempt11_budget(
                          changed_delta, dispatch, command_data,
                          controller_source), controls)
        changed_argv = copy.deepcopy(command_data)
        changed_argv["argv"][changed_argv["argv"].index("--phase-timeout") + 1] = "600"
        expect_reject("controller base timeout argv must remain 480 rejected",
                      lambda: verify_attempt11_budget(
                          protocol, dispatch, changed_argv, controller_source),
                      controls)
        changed_argv = copy.deepcopy(command_data)
        changed_argv["argv"][changed_argv["argv"].index("--phase-timeout") + 1] = "300"
        expect_reject("attempt8 timeout argv drift rejected",
                      lambda: verify_attempt11_budget(
                          protocol, dispatch, changed_argv, controller_source),
                      controls)
        changed_argv = copy.deepcopy(command_data)
        changed_argv["argv"][changed_argv["argv"].index(
            "--authority-phase-timeout") + 1] = "2401"
        expect_reject("authority phase timeout argv drift rejected",
                      lambda: verify_attempt11_budget(
                          protocol, dispatch, changed_argv, controller_source),
                      controls)
        changed_argv = copy.deepcopy(command_data)
        changed_argv["argv"][changed_argv["argv"].index(
            "--authority-case-timeout") + 1] = "1200"
        expect_reject("authority per-case timeout argv drift rejected",
                      lambda: verify_attempt11_budget(
                          protocol, dispatch, changed_argv, controller_source),
                      controls)
        driver_source = (ROOT / protocol["driver_path"]).read_text(
            encoding="utf-8")
        verify_baseline_diagnostic_markers(protocol, driver_source)
        changed_markers = copy.deepcopy(protocol)
        changed_markers["baseline_diagnostic_marker_contract"].pop()
        expect_reject("baseline marker contract omission rejected",
                      lambda: verify_baseline_diagnostic_markers(
                          changed_markers, driver_source), controls)
        changed_driver = driver_source.replace(
            '"baseline_context_serialization"',
            '"baseline_context_serialization_drift"', 1)
        expect_reject("baseline serialization marker omission rejected",
                      lambda: verify_baseline_diagnostic_markers(
                          protocol, changed_driver), controls)

        historical_exclusions = protocol.get(
            "excluded_historical_execution_artifacts")
        expected_historical_launcher = file_receipt(
            HISTORICAL_ATTEMPT3_LAUNCHER)
        require(historical_exclusions == [expected_historical_launcher] and
                protocol.get("historical_execution_artifact_exclusion_reason") == (
                    "migrated unchanged from attempt3 archive after scope "
                    "violation; historical command data, not a current "
                    "execution dependency"),
                "historical scope-violation launcher exclusion receipt mismatch")
        for relative in ACTIVE_GUIDANCE:
            require(relative in protocol["inputs"],
                    f"active guidance missing from input pins: {relative}")
            require(protocol.get("active_guidance_pins", {}).get(relative) ==
                    file_receipt(ROOT / relative),
                    f"active guidance receipt mismatch: {relative}")
        r1_basis = protocol.get("r1_failure_basis")
        require(isinstance(r1_basis, dict) and
                r1_basis.get("r1_actual_matrix_exit_code") == 15 and
                r1_basis.get("r1_actual_matrix_stop_reason") ==
                "phase_wall_timeout" and
                r1_basis.get("r1_actual_observations_present") is False and
                r1_basis.get("r1_executed_case_hit_count") == 0 and
                r1_basis.get("r1_projection24_assertion_sites_completed") == 24,
                "r1 timeout/coverage basis mismatch")
        r1_final_path = ROOT / r1_basis[
            "formal_negative_pipeline_final"]["path"]
        r1_timeout_path = ROOT / r1_basis["timeout_execution_receipt"]["path"]
        r1_final = load_object(r1_final_path)
        r1_timeout = load_object(r1_timeout_path)
        require(r1_basis["formal_negative_pipeline_final"] ==
                file_receipt(r1_final_path) and
                r1_basis["timeout_execution_receipt"] ==
                file_receipt(r1_timeout_path) and
                r1_final.get("status") == "fail" and
                r1_final.get("executed_runtime_case_hit_count") == 0 and
                r1_timeout.get("classification") ==
                "phase_wall_timeout_before_first_actual_observation" and
                r1_timeout.get("actual_observations_present") is False,
                "current r1 failure receipts differ from frozen basis")

        python_paths = protocol.get("python_parse_paths")
        require(isinstance(python_paths, list) and
                len(python_paths) == len(set(python_paths)) and
                len(python_paths) == protocol.get("python_parse_file_count"),
                "Python parse inventory invalid")
        python_receipts = []
        for relative in python_paths:
            require(relative in protocol["inputs"] and relative.endswith(".py"),
                    f"unbound Python parse path: {relative}")
            path = ROOT / relative
            ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            python_receipts.append(file_receipt(path))
        julia_paths = protocol.get("julia_parse_paths")
        require(isinstance(julia_paths, list) and julia_paths and
                len(julia_paths) == len(set(julia_paths)) and
                len(julia_paths) == protocol.get("julia_parse_file_count") and
                all(path in protocol["inputs"] and path.endswith(".jl")
                    for path in julia_paths),
                "Julia parse inventory is not closed over pinned inputs")

        coverage_path = ROOT / protocol["coverage_map"]["path"]
        coverage_receipt = file_receipt(coverage_path)
        coverage = load_object(coverage_path)
        require(protocol["coverage_map"] == coverage_receipt and
                coverage.get("schema") ==
                "vnext-t2-independent-negative-coverage-map-r8" and
                coverage.get("status") == "static_coverage_map_no_julia" and
                coverage.get("formal_t2_accepted") is False,
                "coverage map receipt/schema/status mismatch")
        prior_coverage_receipt = file_receipt(ATTEMPT7_COVERAGE)
        require(protocol["inputs"].get(prior_coverage_receipt["path"]) ==
                prior_coverage_receipt,
                "attempt7 coverage map is not included as an exact input pin")
        prior_coverage = load_object(ATTEMPT7_COVERAGE)
        verify_attempt7_coverage_equivalence(coverage, prior_coverage)
        relocation_metrics = verify_attempt7_relocation_ledger(
            protocol, coverage, prior_coverage)
        attempt10_interruption_status = \
            verify_attempt10_preflight_interruption_basis(protocol, coverage)
        for name, mutate in (
                ("attempt10 missing final case rejected",
                 lambda p: p["attempt10_preflight_interruption_basis"][
                     "preflight"].update(actual_complete_observation_count=18)),
                ("attempt10 partial case cannot be reused",
                 lambda p: p["attempt10_preflight_interruption_basis"][
                     "attempt11_budget_change"].update(
                         attempt10_partial_cases_reused=True)),
                ("attempt11 partial coverage credit rejected",
                 lambda p: p["attempt10_preflight_interruption_basis"][
                     "attempt11_budget_change"].update(
                         failed_attempt11_partial_cases_credit=1)),
                ("attempt10 remaining case identity drift rejected",
                 lambda p: p["attempt10_preflight_interruption_basis"][
                     "preflight"].update(
                         remaining_case_ids=["FEEDBACK_FOREIGN"])),
                ("attempt10 historical input omission rejected",
                 lambda p: p["attempt10_preflight_interruption_basis"][
                     "files"].pop("preflight_phase"))):
            changed_attempt10 = copy.deepcopy(protocol)
            mutate(changed_attempt10)
            expect_reject(name,
                          lambda p=changed_attempt10:
                          verify_attempt10_preflight_interruption_basis(
                              p, coverage), controls)
        report["attempt10_preflight_interruption"] = attempt10_interruption_status
        attempt11_first_freeze_failure_status = \
            verify_attempt11_initial_freeze_failure_basis(protocol)
        for name, mutate in (
                ("initial freeze error relabel rejected",
                 lambda p: p["attempt11_initial_freeze_failure_basis"][
                     "failure"].update(failure_message="science failure")),
                ("initial freezer source pin drift rejected",
                 lambda p: p["attempt11_initial_freeze_failure_basis"][
                     "failure"]["freezer_source_at_failure"].update(
                         sha256="0" * 64)),
                ("initial failure Julia execution claim rejected",
                 lambda p: p["attempt11_initial_freeze_failure_basis"][
                     "failure"].update(julia_started=True)),
                ("initial failure receipt omission rejected",
                 lambda p: p["attempt11_initial_freeze_failure_basis"][
                     "files"].pop("stderr"))):
            changed_initial_failure = copy.deepcopy(protocol)
            mutate(changed_initial_failure)
            expect_reject(name,
                          lambda p=changed_initial_failure:
                          verify_attempt11_initial_freeze_failure_basis(p),
                          controls)
        report["attempt11_initial_freeze_failure"] = \
            attempt11_first_freeze_failure_status
        attempt11_retry1_failure_status = \
            verify_attempt11_retry1_static_qa_failure_basis(protocol)
        for name, mutate in (
                ("retry1 static QA failure relabel rejected",
                 lambda p: p["attempt11_retry1_static_qa_failure_basis"]
                     ["failure"]["failure"].update(
                         message="scientific negative")),
                ("retry1 QA source-at-failure pin drift rejected",
                 lambda p: p["attempt11_retry1_static_qa_failure_basis"]
                     ["failure"]["static_qa_source_at_failure"].update(
                         sha256="0" * 64)),
                ("retry1 Julia execution claim rejected",
                 lambda p: p["attempt11_retry1_static_qa_failure_basis"]
                     ["failure"].update(julia_started=True)),
                ("retry1 preserved artifact omission rejected",
                 lambda p: p["attempt11_retry1_static_qa_failure_basis"]
                     ["preserved_retry1_files"].pop(
                         "docs/implementation/UP1-04A-VNEXT-T2/archive/"
                         "r2_protocol_freeze_20260924_t2_protocol_attempt11_"
                         "preflight_600s_retry1/protocol.json"))):
            changed_retry1_failure = copy.deepcopy(protocol)
            mutate(changed_retry1_failure)
            expect_reject(name,
                          lambda p=changed_retry1_failure:
                          verify_attempt11_retry1_static_qa_failure_basis(p),
                          controls)
        report["attempt11_retry1_static_qa_failure"] = \
            attempt11_retry1_failure_status
        attempt11_retry2_failure_status = \
            verify_attempt11_retry2_static_qa_failure_basis(protocol)
        for name, mutate in (
                ("retry2 QA failure reason drift rejected",
                 lambda p: p["attempt11_retry2_static_qa_failure_basis"]
                     ["failure"]["static_qa_failure"].update(
                         message="scientific negative")),
                ("retry2 stale module binding relabel rejected",
                 lambda p: p["attempt11_retry2_static_qa_failure_basis"]
                     ["failure"]["python_module_binding_at_failure"].__setitem__(
                         0, "vnext_t2_controller_r10")),
                ("retry2 projection completion omission rejected",
                 lambda p: p["attempt11_retry2_static_qa_failure_basis"]
                     ["failure"].update(projection24_exit_code=15)),
                ("retry2 Julia execution claim rejected",
                 lambda p: p["attempt11_retry2_static_qa_failure_basis"]
                     ["failure"].update(julia_started=True)),
                ("retry2 pinned artifact omission rejected",
                 lambda p: p["attempt11_retry2_static_qa_failure_basis"]
                     ["files"].pop(next(iter(p[
                         "attempt11_retry2_static_qa_failure_basis"]["files"]))))):
            changed_retry2_failure = copy.deepcopy(protocol)
            mutate(changed_retry2_failure)
            expect_reject(name,
                          lambda p=changed_retry2_failure:
                          verify_attempt11_retry2_static_qa_failure_basis(p),
                          controls)
        report["attempt11_retry2_static_qa_failure"] = \
            attempt11_retry2_failure_status
        comparison = protocol.get("attempt7_coverage_comparison", {})
        case_ids = sorted(row["id"] for row in coverage["successor_cases"])
        site_ids = sorted(row["id"] for row in
                          coverage["successor_assertion_sites"])
        case_id_sha = hashlib.sha256(json.dumps(
            case_ids, separators=(",", ":")).encode("utf-8")).hexdigest()
        site_id_sha = hashlib.sha256(json.dumps(
            site_ids, separators=(",", ":")).encode("utf-8")).hexdigest()
        require(comparison.get("attempt7_coverage_map") ==
                prior_coverage_receipt and comparison.get("case_count") == 60 and
                comparison.get("formal_case_count") == 45 and
                comparison.get("runtime_unique_case_count") == 60 and
                comparison.get("runtime_case_hit_count") == 68 and
                comparison.get("successor_assertion_site_count") == 214 and
                comparison.get("successor_expected_runtime_hit_count") == 622 and
                comparison.get("case_id_set_sha256") == case_id_sha and
                comparison.get("assertion_site_id_set_sha256") == site_id_sha and
                comparison.get("semantic_case_ids_and_site_ids_equal") is True and
                comparison.get(
                    "site_assertion_text_multiplicity_and_phase_hits_equal") is True and
                comparison.get("full_path_line_map_byte_equal") is False,
                "attempt7 semantic case/site comparison receipt mismatch")
        driver_lines = driver_source.splitlines()
        for site in coverage["successor_assertion_sites"]:
            require(site["path"] == protocol["driver_path"] or
                    site["path"] == "test/GenomeV5/Integration/"
                    "VNextT2FormalIndependentR1/supplementary_contract_driver_r1.jl",
                    f"assertion site path is outside pinned drivers: {site['id']}")
            if site["path"] == protocol["driver_path"]:
                require(1 <= site["line"] <= len(driver_lines) and
                        driver_lines[site["line"] - 1].lstrip().startswith(
                            ("@test ", "@test_throws ")),
                        f"assertion site line target drift: {site['id']}")
        equality_mutations = []
        missing_site = copy.deepcopy(coverage)
        missing_site["successor_assertion_sites"].pop()
        equality_mutations.append(("attempt7 site omission rejected", missing_site))
        extra_site = copy.deepcopy(coverage)
        fake_site = copy.deepcopy(extra_site["successor_assertion_sites"][-1])
        fake_site["id"] = "NEW-ACT-FAKE-ATTEMPT8"
        extra_site["successor_assertion_sites"].append(fake_site)
        equality_mutations.append(("attempt7 extra site rejected", extra_site))
        drift_site = copy.deepcopy(coverage)
        drift_site["successor_assertion_sites"][0]["source_text_sha256"] = "0" * 64
        equality_mutations.append(("attempt7 source assertion drift rejected", drift_site))
        missing_case = copy.deepcopy(coverage)
        missing_case["successor_cases"].pop()
        equality_mutations.append(("attempt7 case omission rejected", missing_case))
        for name, changed in equality_mutations:
            expect_reject(name, lambda m=changed:
                          verify_attempt7_coverage_equivalence(m, prior_coverage),
                          controls)
        for name, mutate in (
                ("relocation row omission rejected",
                 lambda p: p["attempt7_coverage_comparison"][
                     "path_line_relocation_ledger"]["entries"].pop()),
                ("relocation line drift rejected",
                 lambda p: p["attempt7_coverage_comparison"][
                     "path_line_relocation_ledger"]["entries"][0].update(
                         line_delta=123)),
                ("relocation source text drift rejected",
                 lambda p: p["attempt7_coverage_comparison"][
                     "path_line_relocation_ledger"]["entries"][0].update(
                         source_text="@test forged"))):
            mutated_protocol = copy.deepcopy(protocol)
            mutate(mutated_protocol)
            expect_reject(name, lambda p=mutated_protocol:
                          verify_attempt7_relocation_ledger(
                              p, coverage, prior_coverage), controls)
        report["attempt7_plan_equality"] = {
            "status": "pass", "case_count": 60,
            "formal_case_count": 45, "runtime_unique_case_count": 60,
            "runtime_hit_count": 68, "successor_site_count": 214,
            "successor_runtime_hit_count": 622,
            "case_ids_exact": True, "site_ids_and_assertions_exact": True,
            "phase_hit_map_exact": True,
            "full_path_line_map_byte_equal": False,
            "relocation_ledger": relocation_metrics}
        require(len(coverage["old_assertion_sites"]) == 154 and
                coverage["old_expected_runtime_hit_count"] == 174 and
                len(coverage["successor_assertion_sites"]) == 214 and
                coverage["successor_expected_runtime_hit_count"] == 622 and
                coverage["preserved_successor_assertion_site_count"] == 191 and
                coverage["preserved_successor_expected_runtime_hit_count"] == 530 and
                coverage["context_transport_assertion_site_count"] == 23 and
                coverage["context_transport_expected_runtime_hit_count"] == 92 and
                coverage["versioned_product_repair_regression"][
                    "assertion_site_count"] == 24,
                "frozen old/successor/context/projection coverage mismatch")
        runtime_hit_plan = coverage["successor_assertion_runtime_hit_plan"]
        require(runtime_hit_plan.get("status") ==
                "expected_source_site_hits_static_plan_actual_hits_pending" and
                runtime_hit_plan.get("assertion_site_count") == 214 and
                runtime_hit_plan.get("expected_runtime_hit_count") == 622,
                "static source-site plan overclaims runtime observation")
        controller = load_controller(ROOT / protocol["controller_path"])
        attempt11_budget_status = verify_attempt11_budget(
            protocol, dispatch, command_data, controller_source, controller)
        report["attempt11_preflight_budget"] = attempt11_budget_status
        report.setdefault("checks", []).append({
            "name": "attempt11 preflight-only 600s controller path",
            "status": "pass", "phase_override_seconds": 600,
            "base_formal_phase_seconds": 480,
            "negative_controls_added": 14})
        runtime_plan = controller.verify_coverage_runtime_plan(protocol, coverage)
        require(runtime_plan == coverage["runtime_execution_plan"],
                "protocol runtime plan differs from coverage plan")
        positive_pin_join = controller.verify_positive_reuse_input_pins(protocol)
        positive_evidence_receipts = controller.verify_frozen_positive_evidence(
            ROOT / protocol["positive_evidence"]["root"],
            protocol["positive_evidence"])
        positive_for_commands = controller.read_positive(
            ROOT / protocol["positive_evidence"]["root"],
            protocol["positive_evidence"]["formal_serial_replay"]["sha256"],
            protocol["positive_evidence"]["pipeline_final"]["sha256"])
        authority_case_contract = verify_authority_case_hit_contract(
            protocol, coverage, driver_source, controller_source, controls)
        authority_case_receipts = verify_authority_case_receipt_synthetic_contract(
            controller, protocol, coverage, positive_for_commands, controls)
        authority_partial_prefix = \
            verify_authority_partial_prefix_synthetic_contract(
                controller, protocol, coverage, controls)
        authority_resume_contract = \
            verify_authority_resume_ancestry_synthetic_contract(
                controller, protocol, protocol_path, controls)
        shard_argv_contract = verify_actual_formal_shard_argv_contract(
            protocol, controller, positive_for_commands,
            controller_source, controls)

        require(protocol.get("projection24_reuse_validator_path") ==
                PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix() and
                protocol.get("projection24_reuse_validator_path") in
                protocol["inputs"] and
                protocol.get("projection24_reuse_validator_path") in
                protocol.get("python_parse_paths", []),
                "projection24 validator is not bound into current Python inputs")
        projection_validator = load_projection_validator(
            ROOT / protocol["projection24_reuse_validator_path"])
        projection_plan = protocol.get("projection24_reuse")
        require(isinstance(projection_plan, dict),
                "frozen projection24 reuse plan is absent")
        source_protocol = load_object(
            ROOT / projection_plan["source_protocol"]["path"])
        projection_plan_summary = \
            projection_validator.verify_projection24_reuse_plan(
                protocol, source_protocol)
        require(projection_plan_summary["source_input_count"] == 157 and
                projection_plan_summary["r1_input_intersection_count"] == 151 and
                projection_plan_summary["excluded_r1_input_count"] == 6 and
                projection_plan_summary["dependency_subset_count"] ==
                projection_plan["dependency_subset_count"],
                "projection24 exact current-input join counts mismatch")
        controller_source = (ROOT / protocol["controller_path"]).read_text(
            encoding="utf-8")
        require(controller_source.count("sys.executable") == 1 and
                "validate_projection24_reuse_r4.py" in controller_source,
                "Python-only preflight audit found an unbound/extra child phase")

        preflight_expected = dispatch.get("projection24_reuse_preflight")
        require(isinstance(preflight_expected, dict),
                "projection24 Python preflight evidence pin is absent")
        preflight_phase_path = ROOT / preflight_expected["path"]
        require(file_receipt(preflight_phase_path) == preflight_expected,
                "projection24 Python preflight phase receipt drift")
        preflight_phase = load_object(preflight_phase_path)
        preflight_dir = preflight_phase_path.parent
        preflight_receipt_path = preflight_dir / "reuse_receipt.json"
        preflight_stdout_path = preflight_dir / "stdout.raw"
        preflight_stderr_path = preflight_dir / "stderr.raw"
        require(preflight_phase.get("schema") ==
                "vnext-t2-projection24-python-preflight-phase-r1" and
                preflight_phase.get("name") ==
                "projection24_reuse_python_preflight" and
                preflight_phase.get("status") == "pass" and
                preflight_phase.get("stop_reason") == "natural_exit" and
                preflight_phase.get("exit_code") == 0 and
                preflight_phase.get("julia_started") is False and
                preflight_phase.get("formal_t2_accepted") is False,
                "projection24 Python preflight did not naturally pass")
        require(preflight_phase.get("command_argv") == [
                    sys.executable, "-B", str(PROJECTION_REUSE_VALIDATOR),
                    str(protocol_path), str(preflight_receipt_path)] and
                preflight_phase.get("pass_marker_observed") is True and
                preflight_phase.get("pass_marker") ==
                "T2_PROJECTION24_REUSE=PASS sites=24 groups=4",
                "projection24 Python preflight command or marker mismatch")
        require(file_receipt(preflight_receipt_path) ==
                preflight_phase.get("receipt") and
                file_receipt(preflight_stdout_path) ==
                preflight_phase.get("stdout") and
                file_receipt(preflight_stderr_path) ==
                preflight_phase.get("stderr") and
                preflight_stderr_path.stat().st_size == 0,
                "projection24 Python preflight sidecar receipts mismatch")
        preflight_stdout = preflight_stdout_path.read_text(
            encoding="utf-8", errors="replace")
        require("T2_PROJECTION24_REUSE=PASS sites=24 groups=4" in
                preflight_stdout,
                "projection24 Python preflight PASS marker absent from stdout")
        preflight_receipt = load_object(preflight_receipt_path)
        require(preflight_receipt.get("status") == "pass" and
                preflight_receipt.get("schema") ==
                "vnext-t2-projection24-cross-run-validation-r4" and
                preflight_receipt.get("natural_exit_zero") is True and
                preflight_receipt.get("post_assertion_pass_marker") is True and
                preflight_receipt.get("assertion_sites_completed") == 24 and
                preflight_receipt.get("dependency_count") ==
                projection_plan["dependency_subset_count"] and
                preflight_receipt.get("phase_files", {}).get("phase", {}).get(
                    "sha256") ==
                "9fa149b1f2aefba2c4576e8ffd9dfedd715831bce3fc3ef4bc1315cb246c19ca" and
                preflight_receipt.get("phase_files", {}).get(
                    "actual_observation", {}).get("sha256") ==
                "49072e4519cc4eea7ba1675b644c682c475009f108271888292962cb94e5b803" and
                preflight_receipt.get("phase_files", {}).get("stdout", {}).get(
                    "sha256") ==
                "3b676de77ced4c00937e889041d21a857d9d7bdc975e8bbb8de580dc0b49b7c7",
                "projection24 historical exact marker/site receipt mismatch")

        expected_missing_r1 = {
            "docs/implementation/UP1-04A-VNEXT-T2/actualr4_failure_review/"
            "r5_patch_review/dispatch_r3_review/review.json",
            "docs/implementation/UP1-04A-VNEXT-T2/actualr4_failure_review/"
            "r5_patch_review/negative_candidate_checkpoint_r1/review.json",
            "docs/implementation/UP1-04A-VNEXT-T2/actualr4_failure_review/"
            "r5_patch_review/negative_delta_review_r2/positive_join_unit_review.json",
            "docs/implementation/UP1-04A-VNEXT-T2/actualr4_failure_review/"
            "r5_patch_review/review.json",
        }
        expected_changed_r1 = {
            "docs/v4_multitopology_generation/16_execution_work_orders.md",
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "supplementary_contract_driver_r1.jl",
        }
        excluded_rows = projection_plan["excluded_r1_input_rows"]
        actual_missing_r1 = {
            row["historical_pin"]["path"] for row in excluded_rows
            if row["classification"] ==
            "missing_from_current_r3_input_closure"}
        actual_changed_r1 = {
            row["historical_pin"]["path"] for row in excluded_rows
            if row["classification"] ==
            "current_path_bytes_or_sha256_changed"}
        require(actual_missing_r1 == expected_missing_r1 and
                actual_changed_r1 == expected_changed_r1 and
                all(row["current_pin"] is None for row in excluded_rows
                    if row["classification"] ==
                    "missing_from_current_r3_input_closure") and
                all(row["current_pin"] == protocol["inputs"][
                    row["historical_pin"]["path"]]
                    for row in excluded_rows if row["classification"] ==
                    "current_path_bytes_or_sha256_changed"),
                "projection24 exact six R1 exclusions/reasons mismatch")
        report.setdefault("checks", []).append({
            "name": "projection24 historical input join and exclusions",
            "status": "pass", "historical_input_count": 157,
            "exact_current_intersection_count": 151,
            "excluded_count": 6,
            "missing_from_current_closure": sorted(actual_missing_r1),
            "bytes_or_sha256_changed": sorted(actual_changed_r1),
            "dependency_subset_count": projection_plan[
                "dependency_subset_count"],
            "explicitly_consumed_paths": projection_plan_summary[
                "explicitly_consumed_paths"]})

        valid_reordered_projection = copy.deepcopy(protocol)
        valid_reordered_projection["projection24_reuse"][
            "dependency_subset"] = dict(reversed(list(
                valid_reordered_projection["projection24_reuse"][
                    "dependency_subset"].items())))
        projection_validator.verify_projection24_reuse_plan(
            valid_reordered_projection, source_protocol)
        report["checks"].append({
            "name": "projection24 path-keyed dependency order is semantic",
            "status": "pass"})

        def reject_projection_plan(name: str, mutate: Callable[[dict[str, Any]], None]) -> None:
            changed = copy.deepcopy(protocol)
            mutate(changed)
            expect_reject(name,
                          lambda p=changed:
                          projection_validator.verify_projection24_reuse_plan(
                              p, source_protocol), controls)

        reject_projection_plan("projection24 plan missing",
            lambda p: p.pop("projection24_reuse"))
        reject_projection_plan("projection24 schema drift",
            lambda p: p["projection24_reuse"].update(schema="unknown"))
        first_dependency = sorted(projection_plan["dependency_subset"])[0]
        reject_projection_plan("projection24 dependency missing",
            lambda p: p["projection24_reuse"]["dependency_subset"].pop(
                first_dependency))
        reject_projection_plan("projection24 dependency extra",
            lambda p: p["projection24_reuse"]["dependency_subset"].update({
                "src/__t2_projection_extra__.jl": {
                    "path": "src/__t2_projection_extra__.jl", "bytes": 0,
                    "sha256": hashlib.sha256(b"").hexdigest()}}))
        reject_projection_plan("projection24 dependency SHA drift",
            lambda p: p["projection24_reuse"]["dependency_subset"][
                first_dependency].update(sha256="0" * 64))
        reject_projection_plan("projection24 dependency byte-count drift",
            lambda p: p["projection24_reuse"]["dependency_subset"][
                first_dependency].update(bytes=
                    p["projection24_reuse"]["dependency_subset"][
                        first_dependency]["bytes"] + 1))
        reject_projection_plan("projection24 source/phase consumed pin missing",
            lambda p: p["projection24_reuse"]["dependency_subset"].pop(
                p["projection24_reuse"]["source_protocol"]["path"]))
        reject_projection_plan("projection24 phase sidecar missing",
            lambda p: p["projection24_reuse"]["phase_files"].pop("stdout"))
        reject_projection_plan("projection24 exclusion reason drift",
            lambda p: p["projection24_reuse"]["excluded_r1_input_rows"][
                0].update(classification="silently_accepted"))
        reject_projection_plan("projection24 historical intersection drift",
            lambda p: p["projection24_reuse"]["r1_input_intersection"].pop(
                next(iter(p["projection24_reuse"][
                    "r1_input_intersection"]))))
        matched_path = sorted(projection_plan["r1_input_intersection"])[0]
        def mutate_current_join(p: dict[str, Any]) -> None:
            p["inputs"][matched_path]["bytes"] += 1
            p["projection24_reuse"]["dependency_subset"][
                matched_path]["bytes"] += 1
        reject_projection_plan("projection24 current input join drift",
                              mutate_current_join)

        report["checks"].append({
            "name": "projection24 plan targeted synthetic positive/negative controls",
            "status": "pass", "negative_controls_added": 11,
            "synthetic_only": True})

        reversed_maps = copy.deepcopy(protocol)
        plan = reversed_maps["runtime_execution_plan"]
        for field in ("actual_formal_phase_case_ids",
                      "actual_formal_phase_observation_ids"):
            plan[field] = dict(reversed(list(plan[field].items())))
        controller.verify_runtime_plan(reversed_maps)
        report.setdefault("checks", []).append({
            "name": "phase semantic maps ignore JSON object key order",
            "status": "pass"})

        for field in ("actual_formal_phase_case_ids",
                      "actual_formal_phase_observation_ids"):
            missing = copy.deepcopy(protocol["runtime_execution_plan"])
            missing[field].pop(next(iter(missing[field])))
            expect_reject("missing phase key " + field,
                          lambda p=missing: controller.verify_runtime_plan(
                              {"runtime_execution_plan": p}), controls)
            extra = copy.deepcopy(protocol["runtime_execution_plan"])
            extra[field]["unexpected_phase"] = []
            expect_reject("extra phase key " + field,
                          lambda p=extra: controller.verify_runtime_plan(
                              {"runtime_execution_plan": p}), controls)
        drift_plan = copy.deepcopy(protocol)
        drift_plan["runtime_execution_plan"]["actual_formal_phase_case_ids"][
            "actual_formal_preflight"][0] += "_DRIFT"
        expect_reject("protocol plan case ID drift from coverage map",
                      lambda: controller.verify_coverage_runtime_plan(
                          drift_plan, coverage), controls)
        mismatched_plan = copy.deepcopy(protocol)
        del mismatched_plan["runtime_execution_plan"]["expected_unique_case_ids"]
        expect_reject("protocol plan field removed from coverage map copy",
                      lambda: controller.verify_coverage_runtime_plan(
                          mismatched_plan, coverage), controls)

        positive_pins = protocol["positive_reuse_input_pins"]
        first_path = sorted(positive_pins)[0]
        for name, mutate in (
                ("positive input SHA drift", lambda pins: pins[first_path].update(
                    sha256="0" * 64)),
                ("positive input byte-count drift", lambda pins: pins[first_path].update(
                    bytes=pins[first_path]["bytes"] + 1)),
                ("positive input missing", lambda pins: pins.pop(first_path)),
                ("positive input extra", lambda pins: pins.update({
                    "src/__r3_extra__.jl": {"path": "src/__r3_extra__.jl",
                        "bytes": 0, "sha256": hashlib.sha256(b"").hexdigest()}}))):
            changed = copy.deepcopy(protocol)
            mutate(changed["positive_reuse_input_pins"])
            expect_reject(name,
                          lambda p=changed:
                          controller.verify_positive_reuse_input_pins(p), controls)
        reordered_pins = copy.deepcopy(protocol)
        reordered_pins["positive_reuse_input_pins"] = dict(
            reversed(list(reordered_pins["positive_reuse_input_pins"].items())))
        controller.verify_positive_reuse_input_pins(reordered_pins)
        report["checks"].append({
            "name": "104 positive r3 pins compare as path-keyed exact records",
            "status": "pass"})

        hit_summaries = synthetic_site_summaries(
            coverage, coverage_receipt["sha256"])
        for phase, summary in zip(runtime_hit_plan["phase_order"], hit_summaries):
            controller.verify_assertion_site_hit_summary(
                summary, coverage, phase,
                coverage_map_sha256=coverage_receipt["sha256"])
        synthetic_aggregate = controller.aggregate_assertion_site_hit_receipts(
            hit_summaries, coverage,
            coverage_map_sha256=coverage_receipt["sha256"])
        report["checks"].append({
            "name": "synthetic phase hit receipts satisfy static 214/622 mapping",
            "status": "pass", "synthetic_only": True,
            "site_count": synthetic_aggregate["assertion_site_count_observed"],
            "hit_count": synthetic_aggregate["assertion_site_hit_count_observed"]})
        bad_site = copy.deepcopy(hit_summaries[0])
        bad_site["assertion_site_hit_counts"].pop(
            next(iter(bad_site["assertion_site_hit_counts"])))
        expect_reject("per-phase source-site ID missing",
                      lambda: controller.verify_assertion_site_hit_summary(
                          bad_site, coverage, runtime_hit_plan["phase_order"][0],
                          coverage_map_sha256=coverage_receipt["sha256"]), controls)
        bad_value = copy.deepcopy(hit_summaries[0])
        first_site = next(iter(bad_value["assertion_site_hit_counts"]))
        bad_value["assertion_site_hit_counts"][first_site] += 1
        bad_value["assertion_site_hit_count_observed"] += 1
        expect_reject("per-phase source-site count drift",
                      lambda: controller.verify_assertion_site_hit_summary(
                          bad_value, coverage, runtime_hit_plan["phase_order"][0],
                          coverage_map_sha256=coverage_receipt["sha256"]), controls)
        expect_reject("aggregate source-site phase order drift",
                      lambda: controller.aggregate_assertion_site_hit_receipts(
                          list(reversed(hit_summaries)), coverage,
                          coverage_map_sha256=coverage_receipt["sha256"]), controls)
        expect_reject("aggregate source-site phase missing",
                      lambda: controller.aggregate_assertion_site_hit_receipts(
                          hit_summaries[:-1], coverage,
                          coverage_map_sha256=coverage_receipt["sha256"]), controls)

        require(protocol.get("formal_t2_accepted") is False and
                protocol.get("status") == "frozen_static_ready_not_executed" and
                protocol.get("actual_model_attestation") == "unavailable" and
                protocol.get("phase_order") == dispatch.get("phase_order"),
                "protocol claims execution/acceptance or dispatch phase drift")
        cache_metrics_after_checks = verify_python_cache_exclusion(
            protocol, command_data, execution_context)
        require(cache_metrics_after_checks == cache_metrics,
                "Python cache exclusion inventory changed during static QA")
        require(not (ROOT / protocol["planned_evidence_directory"]).exists(),
                "planned execution evidence directory is already present")
        archive_leaf = protocol_path.parent
        archive_code_suffixes = {".py", ".pyc", ".jl", ".ps1", ".bat",
                                 ".cmd", ".exe", ".dll"}
        archived_files = [path for path in archive_leaf.rglob("*")
                          if path.is_file()]
        require(not [path for path in archived_files
                     if path.suffix.lower() in archive_code_suffixes],
                "attempt9 archive contains executable/source payload")
        report.update({
            "status": "pass",
            "repository_head": EXPECTED_HEAD,
            "protocol": protocol_receipt,
            "coverage_map": coverage_receipt,
            "controller": file_receipt(ROOT / protocol["controller_path"]),
            "input_count": len(checked_inputs),
            "python_parse_count": len(python_receipts),
            "julia_parse_inventory_count_not_executed": len(julia_paths),
            "positive_r3_input_pin_count":
                positive_pin_join["positive_runtime_input_count"],
            "positive_r3_pin_identity_sha256":
                positive_pin_join["pin_identity_sha256"],
            "positive_evidence_receipt_count":
                len(positive_evidence_receipts),
            "old_assertion_sites_static_mapping": 154,
            "old_runtime_hits_static_mapping": 174,
            "successor_assertion_sites_static_plan": 214,
            "successor_runtime_hits_static_plan": 622,
            "context_transport_sites_static_plan": 23,
            "context_transport_hits_static_plan": 92,
            "preserved_successor_sites_static_plan": 191,
            "preserved_successor_hits_static_plan": 530,
            "projection24_prior_reuse_mapping": 24,
            "projection24_python_preflight": preflight_expected,
            "projection24_preflight_natural_exit_zero": True,
            "projection24_historical_actual_sites_completed": 24,
            "projection24_r1_source_input_count": 157,
            "projection24_r1_exact_current_intersection_count": 151,
            "projection24_r1_excluded_input_count": 6,
            "projection24_dependency_subset_count":
                projection_plan["dependency_subset_count"],
            "projection24_python_only_child_phase_count": 1,
            "attempt8_preflight_failure_basis": attempt8_failure_status,
            "attempt9_projection_preflight_failure_basis":
                attempt9_failure_status,
            "attempt9b_static_qa_failure_basis":
                attempt9b_failure_status,
            "attempt9c_authority_interruption_basis":
                attempt9c_interruption_status,
            "authority_case_budget_change": authority_budget_delta_status,
            "projection_validator_r3_r4_delta":
                projection_validator_delta_status,
            "controller_r8_r9_authority_progress_delta":
                controller_binding_delta_status,
            "controller_child_script_plan": child_plan_status,
            "actual_formal_shard_argv_contract": shard_argv_contract,
            "authority_case_hit_contract": authority_case_contract,
            "authority_case_receipt_contract": authority_case_receipts,
            "authority_partial_prefix_contract": authority_partial_prefix,
            "authority_resume_ancestry_contract": authority_resume_contract,
            "python_cache_exclusion": cache_metrics,
            "attempt11_cleanup_inventory": cleanup_status,
            "attempt9_archive_evidence_only": True,
            "actual_source_site_hits": "pending_julia_execution",
            "four_shard_protocol_status": "frozen_not_executed",
            "formal_t2_accepted": False,
            "julia_executed": False,
            "julia_parse_executed": False,
            "actual_model_attestation": "unavailable",
            "negative_control_count": len(controls),
        })
    except Exception as error:
        report["failure"] = {"type": type(error).__name__,
                             "message": str(error)}
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8", newline="\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if report.get("status") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
