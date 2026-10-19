#!/usr/bin/env python3
"""Independent Python-only positive/negative checks for the T2 projection24 reuse contract."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[5]
EXPECTED_PROTOCOL_SCHEMA = "vnext-t2-independent-negative-protocol-r2"
EXPECTED_SOURCE_PROTOCOL_SCHEMA = "vnext-t2-independent-negative-protocol-r1"
EXPECTED_REUSE_SCHEMA = "vnext-t2-projection24-cross-run-reuse-r1"
EXPECTED_VALIDATOR_RECEIPT_SCHEMA = "vnext-t2-projection24-cross-run-validation-r2"
EXPECTED_R1_INTERSECTION_COUNT = 151
EXPECTED_EXCLUDED_R1_INPUT_COUNT = 6
REQUIRED_PHASE_FILE_KEYS = {"phase", "actual_observation", "stdout", "stderr"}
EXPECTED_PHASE_FILE_KEYS = REQUIRED_PHASE_FILE_KEYS | {"samples"}
EXPECTED_GROUP_COUNTS = {
    "reload_content_equivalence": 8,
    "wire_byte_tamper_detection": 7,
    "source_byte_tamper_detection": 7,
    "admission_envelope_projection": 2,
}


class CheckFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "path": path.resolve().relative_to(ROOT).as_posix(),
        "bytes": len(data),
        "sha256": sha256(data),
    }


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"expected JSON object: {path}")
    return value


def safe_repo_path(relative: Any, label: str) -> Path:
    require(isinstance(relative, str) and relative != "",
            f"{label} path is absent")
    normalized = relative.replace("\\", "/")
    pure = PurePosixPath(normalized)
    require(not pure.is_absolute() and ".." not in pure.parts and
            re.fullmatch(r"[A-Za-z]:.*", normalized) is None,
            f"{label} path is absolute or escapes repository")
    path = (ROOT / Path(*pure.parts)).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError as exc:
        raise CheckFailure(f"{label} resolves outside repository") from exc
    return path


def verify_record(record: Any, label: str) -> tuple[str, dict[str, Any], Path]:
    require(isinstance(record, dict), f"{label} receipt is malformed")
    relative = record.get("path")
    path = safe_repo_path(relative, label)
    expected = {
        "path": str(relative).replace("\\", "/"),
        "bytes": record.get("bytes"),
        "sha256": record.get("sha256"),
    }
    require(isinstance(expected["bytes"], int) and expected["bytes"] >= 0 and
            isinstance(expected["sha256"], str) and
            re.fullmatch(r"[0-9a-f]{64}", expected["sha256"]) is not None,
            f"{label} receipt lacks exact byte/SHA fields")
    actual = file_receipt(path)
    require(actual == expected, f"{label} path/bytes/SHA drift")
    return expected["path"], actual, path


def verify_projection_plan(protocol: dict[str, Any],
                           coverage: dict[str, Any]) -> dict[str, Any]:
    require(protocol.get("schema") == EXPECTED_PROTOCOL_SCHEMA,
            "negative protocol schema mismatch")
    plan = protocol.get("projection24_reuse")
    require(isinstance(plan, dict) and
            plan.get("schema") == EXPECTED_REUSE_SCHEMA,
            "frozen projection24 reuse plan/schema absent")
    require(plan.get("status") ==
            "frozen_r1_evidence_with_exact_current_join" and
            plan.get("source_input_count") == 157,
            "projection24 reuse plan count/status mismatch")

    mapped = protocol.get("coverage_assertion_hit_plan", {}).get(
        "projection24_mapping")
    coverage_mapped = coverage.get("successor_assertion_runtime_hit_plan", {}).get(
        "projection24_mapping")
    require(isinstance(mapped, dict) and mapped == coverage_mapped and
            mapped.get("assertion_site_count") == 24 and
            mapped.get("planned_runtime_hit_count") == 24,
            "projection24 reuse plan differs from protocol/coverage static mapping")

    dependencies = plan.get("dependency_subset")
    require(isinstance(dependencies, dict) and len(dependencies) >= 100,
            "projection24 reuse dependency subset is incomplete")
    verified_dependencies: dict[str, dict[str, Any]] = {}
    for relative, record in sorted(dependencies.items()):
        require(relative == record.get("path"),
                f"dependency key/path mismatch: {relative}")
        _, actual, _ = verify_record(record, f"projection dependency {relative}")
        verified_dependencies[relative] = actual

    protocol_inputs = protocol.get("inputs")
    require(isinstance(protocol_inputs, dict) and
            protocol.get("input_count") == len(protocol_inputs),
            "frozen R2 input closure is malformed")
    for relative, record in verified_dependencies.items():
        require(protocol_inputs.get(relative) == record,
                f"projection dependency is not bound by the R2 input closure: {relative}")

    named_records = {
        "source_protocol": plan.get("source_protocol"),
        "source_pipeline_final": plan.get("source_pipeline_final"),
        "source_timeout_execution_receipt": plan.get(
            "source_timeout_execution_receipt"),
    }
    verified_sources: dict[str, dict[str, Any]] = {}
    named_source_paths: set[str] = set()
    named_source_documents: dict[str, dict[str, Any]] = {}
    for label, record in named_records.items():
        relative, actual, _ = verify_record(record, label)
        require(verified_dependencies.get(relative) == actual,
                f"{label} is not included in the frozen dependency subset")
        verified_sources[label] = actual
        named_source_paths.add(relative)
        named_source_documents[label] = json_object(safe_repo_path(relative, label))

    r1_protocol = named_source_documents["source_protocol"]
    require(r1_protocol.get("schema") == EXPECTED_SOURCE_PROTOCOL_SCHEMA,
            "projection reuse source protocol is not the frozen R1 protocol")
    r1_pins = r1_protocol.get("inputs")
    current_pins = protocol.get("inputs")
    require(isinstance(r1_pins, dict) and len(r1_pins) == 157 and
            isinstance(current_pins, dict),
            "R1/R2 input closure is malformed for projection reuse comparison")
    intersection = {
        relative: copy.deepcopy(row)
        for relative, row in r1_pins.items()
        if current_pins.get(relative) == row
    }
    excluded_rows: list[dict[str, Any]] = []
    for relative, historical_pin in sorted(r1_pins.items()):
        current_pin = current_pins.get(relative)
        if current_pin == historical_pin:
            continue
        if current_pin is None:
            classification = "missing_from_current_r2_input_closure"
        else:
            classification = "current_path_bytes_or_sha256_changed"
        excluded_rows.append({
            "historical_pin": copy.deepcopy(historical_pin),
            "classification": classification,
            "current_pin": copy.deepcopy(current_pin),
        })
    require(len(intersection) == EXPECTED_R1_INTERSECTION_COUNT and
            len(excluded_rows) == EXPECTED_EXCLUDED_R1_INPUT_COUNT,
            "R1/R2 input intersection or excluded-row counts differ from the frozen contract")
    require(plan.get("r1_input_intersection_count") == len(intersection) and
            plan.get("r1_input_intersection") == intersection,
            "frozen R1 input intersection differs from the exact R1/R2 path+bytes+SHA join")
    require(plan.get("excluded_r1_input_count") == len(excluded_rows) and
            plan.get("excluded_r1_input_rows") == excluded_rows,
            "frozen R1 excluded-input rows do not classify missing/changed pins exactly")

    phase_files = plan.get("phase_files")
    require(isinstance(phase_files, dict) and
            set(phase_files) == EXPECTED_PHASE_FILE_KEYS,
            "projection24 phase file inventory is incomplete")
    verified_phase_files: dict[str, dict[str, Any]] = {}
    phase_paths: dict[str, Path] = {}
    for label, record in sorted(phase_files.items()):
        relative, actual, path = verify_record(record, f"phase file {label}")
        require(verified_dependencies.get(relative) == actual,
                f"phase file is not included in the frozen dependency subset: {label}")
        verified_phase_files[label] = actual
        phase_paths[label] = path
        named_source_paths.add(relative)

    expected_dependency_paths = set(intersection) | named_source_paths
    expected_dependencies = {
        relative: current_pins[relative]
        for relative in expected_dependency_paths
    }
    require(verified_dependencies == expected_dependencies and
            plan.get("dependency_subset_count") == len(expected_dependencies),
            "projection24 dependency subset is not the exact intersection-plus-evidence closure")

    phase = json_object(phase_paths["phase"])
    require(phase.get("name") == "package_full_content_projection_regression" and
            phase.get("stop_reason") == "natural_exit" and
            phase.get("exit_code") == 0 and
            phase.get("timeout_seconds") == 300 and
            phase.get("working_set_limit_bytes") == 2_147_483_648 and
            phase.get("peak_process_tree_working_set_bytes", 2_147_483_648) <
            2_147_483_648 and phase.get("residual_heavy_processes") == [] and
            phase.get("stderr", {}).get("bytes") == 0,
            "projection24 source phase did not pass its natural-exit/resource gates")

    observation = json_object(phase_paths["actual_observation"])
    require(observation.get("schema") ==
            "vnext-t2-package-full-content-projection-actual-r1" and
            observation.get("status") == "actual_observed" and
            observation.get("planned_test_sites") == 24 and
            observation.get("assertion_sites_completed") == 0 and
            observation.get("recorded_before_assertions") is True,
            "projection24 observe-first record schema/boundary mismatch")
    group_counts = {name: row.get("planned_sites")
                    for name, row in observation.get("groups", {}).items()}
    require(group_counts == EXPECTED_GROUP_COUNTS,
            "projection24 semantic group map differs from the 8/7/7/2 contract")

    stdout = phase_paths["stdout"].read_text(encoding="utf-8", errors="replace")
    require("VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4" in stdout,
            "projection24 post-assertion PASS marker absent")
    timeout = json_object(safe_repo_path(
        named_records["source_timeout_execution_receipt"]["path"],
        "source timeout execution receipt"))
    require(timeout.get("completed_coverage", {}).get(
                "projection_assertion_sites_completed") == 24 and
            timeout.get("inputs_stable") is True,
            "projection24 enclosing prior-execution receipt is invalid")

    return {
        "schema": EXPECTED_REUSE_SCHEMA,
        "plan_status": plan["status"],
        "source_input_count": plan["source_input_count"],
        "projection_assertion_sites": 24,
        "projection_planned_hits": 24,
        "dependency_count": len(verified_dependencies),
        "r1_input_intersection_count": len(intersection),
        "excluded_r1_input_count": len(excluded_rows),
        "dependency_set_sha256": sha256(json.dumps(
            verified_dependencies, sort_keys=True, separators=(",", ":")
        ).encode("utf-8")),
        "source_receipt_count": len(verified_sources),
        "phase_file_count": len(verified_phase_files),
        "phase_file_labels": sorted(verified_phase_files),
        "semantic_group_site_counts": group_counts,
        "source_phase_natural_exit_zero": True,
        "source_timeout_projection_sites_completed": 24,
        "formal_t2_accepted": False,
    }


def invoke_validator(validator: Path, protocol_path: Path, output_path: Path,
                     label: str, output_dir: Path) -> dict[str, Any]:
    require(not output_path.exists(), f"validator output already exists: {label}")
    argv = [sys.executable, "-B", str(validator), str(protocol_path),
            str(output_path)]
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    completed = subprocess.run(argv, cwd=ROOT, env=env, capture_output=True,
                               text=False, timeout=90, check=False)
    stdout = completed.stdout or b""
    stderr = completed.stderr or b""
    safe_label = re.sub(r"[^a-zA-Z0-9_-]+", "_", label)
    stdout_path = output_dir / f"{safe_label}.stdout.raw"
    stderr_path = output_dir / f"{safe_label}.stderr.raw"
    stdout_path.write_bytes(stdout)
    stderr_path.write_bytes(stderr)
    return {
        "label": label,
        "argv": argv,
        "exit_code": completed.returncode,
        "output_created": output_path.is_file(),
        "stdout": file_receipt(stdout_path),
        "stderr": file_receipt(stderr_path),
        "output": file_receipt(output_path) if output_path.is_file() else None,
        "stdout_text": stdout.decode("utf-8", errors="replace"),
        "stderr_text": stderr.decode("utf-8", errors="replace"),
    }


def run_controls(protocol: dict[str, Any], validator: Path,
                 output_dir: Path) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    controls: list[dict[str, Any]] = []
    passing_permutations: list[dict[str, Any]] = []

    reversed_maps = copy.deepcopy(protocol)
    plan = reversed_maps["projection24_reuse"]
    plan["dependency_subset"] = dict(reversed(list(
        plan["dependency_subset"].items())))
    plan["r1_input_intersection"] = dict(reversed(list(
        plan["r1_input_intersection"].items())))
    plan["phase_files"] = dict(reversed(list(plan["phase_files"].items())))
    permuted_path = output_dir / "mutant_reordered_semantic_maps.json"
    permuted_receipt_path = output_dir / "receipt_reordered_semantic_maps.json"
    permuted_path.write_text(json.dumps(reversed_maps, indent=2) + "\n",
                             encoding="utf-8")
    permutation = invoke_validator(validator, permuted_path,
                                  permuted_receipt_path,
                                  "positive_reordered_semantic_maps", output_dir)
    require(permutation["exit_code"] == 0 and permutation["output_created"],
            "validator rejected semantically equivalent map key reordering")
    permutation_doc = json_object(permuted_receipt_path)
    require(permutation_doc.get("status") == "pass" and
            permutation_doc.get("assertion_sites_completed") == 24,
            "reordered-map positive receipt does not report exact projection reuse")
    passing_permutations.append({
        "name": "dependency_subset and phase_files key reordering preserves semantics",
        "exit_code": permutation["exit_code"],
        "argv": permutation["argv"],
        "receipt": file_receipt(permuted_receipt_path),
        "stdout": permutation["stdout"],
        "stderr": permutation["stderr"],
    })

    baseline_plan = protocol["projection24_reuse"]
    first_dependency = next(iter(baseline_plan["dependency_subset"]))
    first_phase_file = next(iter(baseline_plan["phase_files"]))

    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("missing_projection24_reuse_plan",
         lambda value: value.pop("projection24_reuse")),
        ("wrong_projection24_reuse_schema",
         lambda value: value["projection24_reuse"].__setitem__(
             "schema", "vnext-t2-projection24-cross-run-reuse-unknown")),
        ("projection_plan_status_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "status", "actual_execution_passed")),
        ("R1_source_input_count_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "source_input_count", 156)),
        ("R1_intersection_count_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "r1_input_intersection_count", EXPECTED_R1_INTERSECTION_COUNT - 1)),
        ("missing_R1_intersection_pin",
         lambda value: value["projection24_reuse"][
             "r1_input_intersection"].pop(next(iter(
                 value["projection24_reuse"]["r1_input_intersection"])))),
        ("extra_R1_intersection_pin",
         lambda value: value["projection24_reuse"][
             "r1_input_intersection"].update({
                 "docs/__independent_projection24_intersection__.md": {
                     "path": "docs/__independent_projection24_intersection__.md",
                     "bytes": 0, "sha256": sha256(b"")}})),
        ("excluded_R1_count_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "excluded_r1_input_count", EXPECTED_EXCLUDED_R1_INPUT_COUNT + 1)),
        ("excluded_R1_classification_drift",
         lambda value: value["projection24_reuse"][
             "excluded_r1_input_rows"][0].__setitem__(
                 "classification", "unclassified")),
        ("reordered_excluded_R1_rows",
         lambda value: value["projection24_reuse"][
             "excluded_r1_input_rows"].reverse()),
        ("dependency_subset_count_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "dependency_subset_count", value["projection24_reuse"][
                 "dependency_subset_count"] + 1)),
        ("dependency_count_drift",
         lambda value: value["projection24_reuse"].__setitem__(
             "dependency_count", value["projection24_reuse"][
                 "dependency_count"] + 1)),
        ("missing_dependency_receipt",
         lambda value: value["projection24_reuse"][
             "dependency_subset"].pop(first_dependency)),
        ("extra_dependency_receipt",
         lambda value: value["projection24_reuse"][
             "dependency_subset"].update({
                 "docs/__independent_projection24_extra__.md": {
                     "path": "docs/__independent_projection24_extra__.md",
                     "bytes": 0, "sha256": sha256(b"")}})),
        ("dependency_sha_drift",
         lambda value: value["projection24_reuse"]["dependency_subset"][
             first_dependency].__setitem__("sha256", "0" * 64)),
        ("dependency_bytes_drift",
         lambda value: value["projection24_reuse"]["dependency_subset"][
             first_dependency].__setitem__("bytes",
                 value["projection24_reuse"]["dependency_subset"][
                     first_dependency]["bytes"] + 1)),
        ("source_protocol_sha_drift",
         lambda value: value["projection24_reuse"]["source_protocol"].__setitem__(
             "sha256", "0" * 64)),
        ("source_timeout_path_missing",
         lambda value: value["projection24_reuse"][
             "source_timeout_execution_receipt"].__setitem__(
                 "path", "docs/__independent_missing_timeout_receipt__.json")),
        ("missing_projection_phase_receipt",
         lambda value: value["projection24_reuse"]["phase_files"].pop("phase")),
        ("projection_phase_sha_drift",
         lambda value: value["projection24_reuse"]["phase_files"][
             first_phase_file].__setitem__("sha256", "0" * 64)),
    ]
    for index, (label, mutate) in enumerate(mutations, start=1):
        changed = copy.deepcopy(protocol)
        mutate(changed)
        changed_path = output_dir / f"mutant_{index:02d}_{label}.json"
        changed_output = output_dir / f"receipt_{index:02d}_{label}.json"
        changed_path.write_text(json.dumps(changed, indent=2) + "\n",
                                encoding="utf-8")
        outcome = invoke_validator(validator, changed_path, changed_output,
                                   f"negative_{label}", output_dir)
        require(outcome["exit_code"] != 0 and not outcome["output_created"],
                f"projection validator accepted malformed plan: {label}")
        controls.append({
            "name": label,
            "status": "pass_rejected",
            "exit_code": outcome["exit_code"],
            "argv": outcome["argv"],
            "stdout": outcome["stdout"],
            "stderr": outcome["stderr"],
            "output_created": outcome["output_created"],
        })
    return passing_permutations, controls


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--coverage-map", required=True)
    parser.add_argument("--validator", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--expected-protocol-sha256")
    args = parser.parse_args()

    protocol_path = Path(args.protocol).resolve()
    coverage_path = Path(args.coverage_map).resolve()
    validator_path = Path(args.validator).resolve()
    output_dir = Path(args.output_dir).resolve()
    require(not output_dir.exists(), f"refusing to overwrite evidence leaf: {output_dir}")
    output_dir.mkdir(parents=True)

    result: dict[str, Any] = {
        "schema": "vnext-t2-independent-projection24-reuse-check-r1",
        "status": "fail",
        "evidence_kind": "independent_python_validator_contract_check",
        "julia_executed": False,
        "actual_model_attestation": "unavailable",
        "formal_t2_accepted": False,
        "checks": [],
        "passing_permutations": [],
        "negative_controls": [],
    }
    try:
        require(protocol_path.is_file() and coverage_path.is_file() and
                validator_path.is_file(), "protocol/map/validator file is missing")
        protocol_raw = protocol_path.read_bytes()
        protocol_sha = sha256(protocol_raw)
        if args.expected_protocol_sha256:
            require(protocol_sha == args.expected_protocol_sha256.lower(),
                    "frozen protocol SHA-256 differs from supplied receipt")
        protocol = json.loads(protocol_raw.decode("utf-8"))
        coverage = json_object(coverage_path)
        require(isinstance(protocol, dict), "frozen protocol is not a JSON object")
        plan_summary = verify_projection_plan(protocol, coverage)
        result["projection24_plan"] = plan_summary
        result["inputs"] = {
            "protocol": file_receipt(protocol_path),
            "coverage_map": file_receipt(coverage_path),
            "validator": file_receipt(validator_path),
            "independent_test_source": file_receipt(Path(__file__).resolve()),
        }

        dispatch_path = protocol_path.parent / "dispatch.json"
        if dispatch_path.is_file():
            dispatch = json_object(dispatch_path)
            require(dispatch.get("protocol") == file_receipt(protocol_path),
                    "frozen dispatch does not bind exact protocol path/bytes/SHA")
            result["inputs"]["dispatch"] = file_receipt(dispatch_path)
            result["checks"].append({
                "name": "attempt dispatch binds frozen protocol receipt",
                "status": "pass",
            })
        expected_coverage = protocol.get("coverage_map")
        require(expected_coverage == file_receipt(coverage_path),
                "protocol does not bind exact frozen coverage-map receipt")
        result["checks"].append({
            "name": "protocol binds exact coverage-map path/bytes/SHA",
            "status": "pass",
        })

        positive_output = output_dir / "projection24_validator_positive_receipt.json"
        positive = invoke_validator(validator_path, protocol_path, positive_output,
                                    "positive_frozen_attempt", output_dir)
        require(positive["exit_code"] == 0 and positive["output_created"],
                "projection24 validator rejected frozen attempt protocol")
        positive_receipt = json_object(positive_output)
        require(positive_receipt.get("schema") == EXPECTED_VALIDATOR_RECEIPT_SCHEMA and
                positive_receipt.get("status") == "pass" and
                positive_receipt.get("natural_exit_zero") is True and
                positive_receipt.get("post_assertion_pass_marker") is True and
                positive_receipt.get("assertion_sites_completed") == 24 and
                positive_receipt.get("semantic_group_site_counts") ==
                EXPECTED_GROUP_COUNTS and
                positive_receipt.get("r1_source_input_count") == 157 and
                positive_receipt.get("r1_input_intersection_count") == 151 and
                positive_receipt.get("excluded_r1_input_count") == 6 and
                positive_receipt.get("dependency_count") == 159 and
                positive_receipt.get("formal_t2_accepted") is False and
                positive_receipt.get("scientific_acceptance") is False and
                positive_receipt.get("physical_acceptance") is False,
                "projection24 positive validator receipt schema/count/boundary mismatch")
        require("T2_PROJECTION24_REUSE=PASS sites=24 groups=4" in
                positive["stdout_text"],
                "projection24 validator stdout PASS marker missing")
        result["positive_validator_run"] = {
            "exit_code": positive["exit_code"],
            "argv": positive["argv"],
            "receipt": file_receipt(positive_output),
            "stdout": positive["stdout"],
            "stderr": positive["stderr"],
            "natural_exit_zero": positive_receipt["natural_exit_zero"],
            "assertion_sites_completed": positive_receipt[
                "assertion_sites_completed"],
            "dependency_count": positive_receipt["dependency_count"],
            "r1_source_input_count": positive_receipt["r1_source_input_count"],
            "r1_input_intersection_count": positive_receipt[
                "r1_input_intersection_count"],
            "excluded_r1_input_count": positive_receipt[
                "excluded_r1_input_count"],
        }
        result["checks"].append({
            "name": "validator accepts frozen projection24 plan and returns exact receipt schema",
            "status": "pass",
        })

        permutations, negatives = run_controls(protocol, validator_path, output_dir)
        result["passing_permutations"] = permutations
        result["negative_controls"] = negatives
        result["checks"].append({
            "name": "semantic-map key reorder accepted; malformed plan mutations rejected",
            "status": "pass",
        })

        pins = protocol.get("inputs", {})
        require(isinstance(pins, dict), "protocol current-input pin map is malformed")
        current_pins = 0
        for relative, expected in pins.items():
            require(expected.get("path") == relative,
                    f"protocol current-input pin key/path mismatch: {relative}")
            _, _, _ = verify_record(expected, f"R2 current input {relative}")
            current_pins += 1
        require(protocol.get("input_count") == current_pins,
                "protocol current-input pin count changed during independent check")
        result["checks"].append({
            "name": "all frozen protocol current-input pins remain path/bytes/SHA exact",
            "status": "pass",
        })
        result["current_input_pin_count"] = current_pins
        result["status"] = "pass_static_projection24_validator_contract_only"
        result["actual_projection_test_reexecuted"] = False
    except Exception as exc:
        result["failure"] = {"type": type(exc).__name__, "message": str(exc)}

    result_path = output_dir / "projection24_independent_check_result.json"
    result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "pass_static_projection24_validator_contract_only" else 1


if __name__ == "__main__":
    raise SystemExit(main())
