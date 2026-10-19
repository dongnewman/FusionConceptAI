from __future__ import annotations

import argparse
import ast
import copy
import difflib
import hashlib
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
HISTORICAL_ATTEMPT3_LAUNCHER = TEST_ROOT / "frozen_launcher_attempt3.ps1"
PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r4.py"
ACTUAL_FORMAL_DRIVER = TEST_ROOT / "actual_formal_negative_driver_r3.jl"
ATTEMPT7_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt7")
ATTEMPT7_EXECUTION = ATTEMPT7_ARCHIVE_LEAF / "actual_negative_execution_r2"
ATTEMPT7_BASELINE = ATTEMPT7_EXECUTION / "actual_formal_baseline"
ATTEMPT7_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
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
    spec = importlib.util.spec_from_file_location("vnext_t2_controller_r4", path)
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


def verify_attempt8_budget(protocol: dict[str, Any], dispatch: dict[str, Any],
                            command_data: dict[str, Any],
                            controller_source: str) -> None:
    gates = protocol.get("resource_gates")
    expected = {"phase_wall_seconds": 480,
                "process_tree_working_set_bytes": 2_147_483_648,
                "julia_threads": 1, "openblas_threads": 1}
    if gates != expected or dispatch.get("resource_gates") != expected or \
            protocol.get("expected_phase_count") != 30 or \
            dispatch.get("phase_count") != 30:
        raise RuntimeError("attempt8 resource budget/phase count differs from contract")
    argv = command_data.get("argv")
    if not isinstance(argv, list) or "--phase-timeout" not in argv:
        raise RuntimeError("attempt8 controller argv lacks timeout gate")
    index = argv.index("--phase-timeout")
    if index + 1 >= len(argv) or argv[index + 1] != "480" or \
            "--working-set-limit" not in argv or \
            argv[argv.index("--working-set-limit") + 1] != "2147483648" or \
            "args.phase_timeout != 480" not in controller_source or \
            "args.working_set_limit != 2_147_483_648" not in controller_source:
        raise RuntimeError("attempt8 controller timeout/RSS gates do not match argv")


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


def verify_actual_formal_shard_argv_contract(
        protocol: dict[str, Any], controller: Any,
        positive: dict[str, Any], controller_source: str,
        controls: list[dict[str, str]]) -> dict[str, Any]:
    contract = protocol.get("actual_formal_shard_argv_contract")
    expected_modes = ["preflight", "authority", "fault_n10", "t1_handoff"]
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
        "run_phase(phase_name,\n                shard_command, shard_dir",
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

    def validate_driver_args(args: list[str], mode: str) -> None:
        if len(args) != 16 or args[0] != mode or args[1:9] != authority_args or \
                args[9:11] != [context_path, context_sha] or \
                args[11:13] != [authorization_path, authorization_sha] or \
                args[13] != str(planned / f"actual_formal_{mode}/artifacts") or \
                args[14:16] != [map_path, map_sha]:
            raise RuntimeError(f"driver ARGS mismatch for shard {mode}")

    command_receipts = []
    for mode in expected_modes:
        command = controller.build_actual_formal_shard_command(
            julia_prefix, mode, authority_args, context_path, context_sha,
            authorization_path, authorization_sha,
            planned / f"actual_formal_{mode}/artifacts", map_path, map_sha)
        driver_index = command.index(str(ACTUAL_FORMAL_DRIVER.resolve()))
        driver_args = command[driver_index + 1:]
        validate_driver_args(driver_args, mode)
        command_receipts.append({"mode": mode,
                                 "driver_argument_count": len(driver_args),
                                 "coverage_map_path": driver_args[14],
                                 "coverage_map_sha256": driver_args[15]})

    sample_args = controller.build_actual_formal_shard_command(
        julia_prefix, "preflight", authority_args, context_path, context_sha,
        authorization_path, authorization_sha,
        planned / "actual_formal_preflight/artifacts", map_path, map_sha)
    sample_driver_args = sample_args[
        sample_args.index(str(ACTUAL_FORMAL_DRIVER.resolve())) + 1:]
    expect_reject("formal shard rejects both missing map argv values",
                  lambda: validate_driver_args(sample_driver_args[:-2],
                                               "preflight"), controls)
    expect_reject("formal shard rejects missing map SHA argv value",
                  lambda: validate_driver_args(sample_driver_args[:-1],
                                               "preflight"), controls)
    wrong_path = list(sample_driver_args)
    wrong_path[14] += ".stale"
    expect_reject("formal shard rejects coverage map path drift",
                  lambda: validate_driver_args(wrong_path, "preflight"), controls)
    wrong_sha = list(sample_driver_args)
    wrong_sha[15] = "0" * 64
    expect_reject("formal shard rejects coverage map SHA drift",
                  lambda: validate_driver_args(wrong_sha, "preflight"), controls)
    swapped = list(sample_driver_args)
    swapped[14], swapped[15] = swapped[15], swapped[14]
    expect_reject("formal shard rejects coverage map argv reordering",
                  lambda: validate_driver_args(swapped, "preflight"), controls)
    return {"status": "pass", "shard_count": len(command_receipts),
            "expected_driver_argument_count": 16,
            "coverage_map_path_index_1_based": 15,
            "coverage_map_sha256_index_1_based": 16,
            "coverage_map": protocol["coverage_map"],
            "commands": command_receipts,
            "negative_controls": 5,
            "runtime_uses_tested_builder": True}


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
                "freeze_independent_negative_protocol_r4b.py") or \
            freeze_entry.get("argv0_matches_source") is not True or \
            freeze_entry.get("sys_dont_write_bytecode") is not True or \
            freeze_entry.get("path") not in protocol["inputs"]:
        raise RuntimeError("freezer direct-source entrypoint receipt mismatch")
    expected_qa_prefix = [sys.executable, "-B",
                          str(TEST_ROOT / "static_qa_independent_negative_r4b.py")]
    if contract.get("static_qa_direct_argv_prefix") != expected_qa_prefix or \
            execution_context != {
                "mode": "direct_script_as_main",
                "path": str(TEST_ROOT / "static_qa_independent_negative_r4b.py"),
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
                "vnext_t2_controller_r4", "vnext_t2_projection24_reuse_r4"]:
        raise RuntimeError("dynamic Python module loader targets are not explicit")
    qa_source = (TEST_ROOT / "static_qa_independent_negative_r4b.py").read_text(
        encoding="utf-8")
    if 'spec_from_file_location("vnext_t2_controller_r4", path)' not in qa_source or \
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
                "static_qa_independent_negative_r4b.py"],
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
        "schema": "vnext-t2-independent-negative-static-qa-r4",
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
                                "static_qa_independent_negative_r4b.py"),
                    "argv0_matches_source": True,
                    "sys_dont_write_bytecode": True},
                "static QA was not run as direct source under -B")
        controls: list[dict[str, str]] = report["negative_controls"]
        require(protocol.get("schema") ==
                "vnext-t2-independent-negative-protocol-r4" and
                protocol.get("repository_head") == EXPECTED_HEAD,
                "r4 protocol schema or HEAD mismatch")
        require(command_data.get("schema") ==
                "vnext-t2-independent-negative-command-argv-r4" and
                command_data.get("kind") == "non_executable_command_data" and
                command_data.get("argv") == dispatch.get("command_argv") and
                command_data.get("environment") == dispatch.get("environment") and
                command_data.get("working_directory") == str(ROOT) and
                command_data.get("julia_started") is False and
                command_data.get("formal_t2_accepted") is False,
                "command artifact is not a non-executable argv data record")
        require(dispatch.get("schema") ==
                "vnext-t2-independent-negative-dispatch-r4" and
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
        verify_attempt8_budget(protocol, dispatch, command_data,
                               controller_source)
        verify_attempt7_interruption(protocol)
        cache_metrics = verify_python_cache_exclusion(
            protocol, command_data, execution_context)
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
                ("memory cap drift rejected", lambda p: p["resource_gates"].update(
                    process_tree_working_set_bytes=2_147_483_647))):
            changed = copy.deepcopy(protocol)
            mutate(changed)
            expect_reject(name, lambda p=changed:
                          verify_attempt8_budget(p, dispatch, command_data,
                                                 controller_source), controls)
        changed_argv = copy.deepcopy(command_data)
        changed_argv["argv"][changed_argv["argv"].index("--phase-timeout") + 1] = "300"
        expect_reject("attempt8 timeout argv drift rejected",
                      lambda: verify_attempt8_budget(
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
                "vnext-t2-independent-negative-coverage-map-r3" and
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
        runtime_plan = controller.verify_coverage_runtime_plan(protocol, coverage)
        require(runtime_plan == coverage["runtime_execution_plan"],
                "protocol runtime plan differs from coverage plan")
        positive_pin_join = controller.verify_positive_reuse_input_pins(protocol)
        positive_evidence_receipts = controller.verify_frozen_positive_evidence(
            ROOT / protocol["positive_evidence"]["root"],
            protocol["positive_evidence"])
        shard_argv_contract = verify_actual_formal_shard_argv_contract(
            protocol, controller, positive_evidence_receipts,
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
            "projection_validator_r3_r4_delta":
                projection_validator_delta_status,
            "actual_formal_shard_argv_contract": shard_argv_contract,
            "python_cache_exclusion": cache_metrics,
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
