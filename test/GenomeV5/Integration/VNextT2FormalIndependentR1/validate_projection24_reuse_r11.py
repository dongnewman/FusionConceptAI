from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import sys
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
R1_SOURCE_PROTOCOL_PATH = (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_dispatch_r1/protocol.json")
R1_PIPELINE_FINAL_PATH = (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_independent_negative_r1/pipeline_final.json")
R1_TIMEOUT_RECEIPT_PATH = (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_actual_r1_timeout_20260922/execution_receipt.json")
R1_PROJECTION_DIR = (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_independent_negative_r1/"
    "package_full_content_projection_regression")
EXPECTED_PHASE_FILE_PATHS = {
    "phase": R1_PROJECTION_DIR + "/phase.json",
    "actual_observation": R1_PROJECTION_DIR + "/actual_observation.json",
    "samples": R1_PROJECTION_DIR + "/samples.jsonl",
    "stdout": R1_PROJECTION_DIR + "/stdout.raw",
    "stderr": R1_PROJECTION_DIR + "/stderr.raw",
}
EXPECTED_PROJECTION_MARKER = \
    "VNEXT_T2_PACKAGE_PROJECTION_REGRESSION=PASS sites=24 groups=4"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(data),
            "sha256": sha256_bytes(data)}


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise TypeError(path)
    return value


def _require_pin_shape(relative: str, row: Any) -> None:
    if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256"} or \
            row.get("path") != relative or \
            not isinstance(row.get("bytes"), int) or row["bytes"] < 0 or \
            not isinstance(row.get("sha256"), str) or \
            len(row["sha256"]) != 64:
        raise RuntimeError(f"malformed path/bytes/SHA pin: {relative}")


def verify_projection24_reuse_plan(
        protocol: dict[str, Any], old_protocol: dict[str, Any]) -> dict[str, Any]:
    """Pure structural validator for the frozen cross-run plan.

    The plan is an exact current-input join of the 151 unchanged historical R1
    pins plus all eight files directly consumed by this validator. Six old R1
    pins are represented as explicit exclusions with a reason and, for changed
    paths, the current receipt. The historical 157-pin inventory is never
    described as a complete current closure.
    """
    frozen = protocol.get("projection24_reuse")
    if not isinstance(frozen, dict) or frozen.get("schema") != \
            "vnext-t2-projection24-cross-run-reuse-r1":
        raise RuntimeError("projection reuse plan absent or schema mismatch")
    if frozen.get("status") != "frozen_r1_evidence_with_exact_current_join" or \
            frozen.get("source_input_count") != 157:
        raise RuntimeError("projection reuse source closure status/count mismatch")

    current_inputs = protocol.get("inputs")
    historical_inputs = old_protocol.get("inputs")
    if not isinstance(current_inputs, dict) or not isinstance(historical_inputs, dict) or \
            old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r1" or \
            len(historical_inputs) != 157:
        raise RuntimeError("projection reuse source/current input inventories invalid")
    coverage_path = (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "coverage_map_r16.json")
    coverage_pin = protocol.get("coverage_map")
    _require_pin_shape(coverage_path, coverage_pin)
    if current_inputs.get(coverage_path) != coverage_pin or \
            protocol.get("coverage_map_schema") != \
            "vnext-t2-independent-negative-coverage-map-r16":
        raise RuntimeError("projection reuse current coverage-map pin/schema mismatch")
    for relative, row in historical_inputs.items():
        _require_pin_shape(relative, row)
    for relative, row in current_inputs.items():
        _require_pin_shape(relative, row)

    expected_intersection = {
        relative: historical_inputs[relative]
        for relative in sorted(historical_inputs)
        if current_inputs.get(relative) == historical_inputs[relative]
    }
    expected_excluded = []
    for relative in sorted(historical_inputs):
        historical_pin = historical_inputs[relative]
        current_pin = current_inputs.get(relative)
        if current_pin == historical_pin:
            continue
        if current_pin is None:
            classification = "missing_from_current_protocol_input_closure"
        else:
            classification = "current_path_bytes_or_sha256_changed"
        expected_excluded.append({
            "historical_pin": historical_pin,
            "classification": classification,
            "current_pin": current_pin,
        })

    if frozen.get("r1_input_intersection") != expected_intersection or \
            frozen.get("r1_input_intersection_count") != len(expected_intersection) or \
            len(expected_intersection) != 151:
        raise RuntimeError("projection reuse R1/current exact intersection mismatch")
    if frozen.get("excluded_r1_input_rows") != expected_excluded or \
            frozen.get("excluded_r1_input_count") != len(expected_excluded) or \
            len(expected_excluded) != 6:
        raise RuntimeError("projection reuse R1 exclusions/reasons mismatch")

    direct_receipts = {
        "source_protocol": frozen.get("source_protocol"),
        "source_pipeline_final": frozen.get("source_pipeline_final"),
        "source_timeout_execution_receipt": frozen.get(
            "source_timeout_execution_receipt"),
    }
    expected_direct_paths = {
        "source_protocol": R1_SOURCE_PROTOCOL_PATH,
        "source_pipeline_final": R1_PIPELINE_FINAL_PATH,
        "source_timeout_execution_receipt": R1_TIMEOUT_RECEIPT_PATH,
    }
    consumed_paths = set(expected_intersection)
    for name, relative in expected_direct_paths.items():
        pin = direct_receipts[name]
        _require_pin_shape(relative, pin)
        if pin != current_inputs.get(relative):
            raise RuntimeError(f"projection reuse direct pin is not a current input: {name}")
        consumed_paths.add(relative)

    phase_files = frozen.get("phase_files")
    if not isinstance(phase_files, dict) or \
            set(phase_files) != set(EXPECTED_PHASE_FILE_PATHS):
        raise RuntimeError("projection reuse phase-file roles mismatch")
    for name, relative in EXPECTED_PHASE_FILE_PATHS.items():
        pin = phase_files[name]
        _require_pin_shape(relative, pin)
        if pin != current_inputs.get(relative):
            raise RuntimeError(f"projection reuse phase file is not a current input: {name}")
        consumed_paths.add(relative)

    expected_dependencies = {
        relative: current_inputs[relative]
        for relative in sorted(consumed_paths)
    }
    dependencies = frozen.get("dependency_subset")
    if dependencies != expected_dependencies or \
            frozen.get("dependency_subset_count") != len(expected_dependencies) or \
            frozen.get("dependency_count") != len(expected_dependencies):
        raise RuntimeError("projection reuse dependency subset is not exact current join")

    return {
        "source_input_count": len(historical_inputs),
        "r1_input_intersection_count": len(expected_intersection),
        "excluded_r1_input_count": len(expected_excluded),
        "dependency_subset_count": len(expected_dependencies),
        "excluded_r1_input_rows": expected_excluded,
        "explicitly_consumed_paths": sorted(
            set(expected_direct_paths.values()) |
            set(EXPECTED_PHASE_FILE_PATHS.values())),
    }


def require_receipt(path: Path, expected: dict[str, Any]) -> dict[str, Any]:
    actual = receipt(path)
    if actual != expected:
        raise RuntimeError(f"projection reuse receipt drift: {path}")
    return actual


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit(
            "usage: validate_projection24_reuse_r10.py <protocol.json> <receipt.json>")
    protocol_path = Path(sys.argv[1]).resolve()
    output_path = Path(sys.argv[2]).resolve()
    if output_path.exists():
        raise FileExistsError(output_path)
    protocol = load(protocol_path)
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":
        raise RuntimeError("projection reuse protocol schema mismatch")
    frozen = protocol.get("projection24_reuse")
    if not isinstance(frozen, dict):
        raise RuntimeError("projection reuse plan absent")
    old_protocol_pin = frozen.get("source_protocol")
    if not isinstance(old_protocol_pin, dict):
        raise RuntimeError("projection reuse source protocol pin absent")
    old_protocol_receipt = require_receipt(
        ROOT / old_protocol_pin["path"], old_protocol_pin)
    old_protocol = load(ROOT / old_protocol_pin["path"])
    plan_summary = verify_projection24_reuse_plan(protocol, old_protocol)

    dependencies = frozen["dependency_subset"]
    observed_dependencies = {
        relative: require_receipt(ROOT / relative, expected)
        for relative, expected in sorted(dependencies.items())
    }

    old_pipeline = require_receipt(
        ROOT / frozen["source_pipeline_final"]["path"],
        frozen["source_pipeline_final"])
    timeout_receipt = require_receipt(
        ROOT / frozen["source_timeout_execution_receipt"]["path"],
        frozen["source_timeout_execution_receipt"])
    phase_files = {
        name: require_receipt(ROOT / expected["path"], expected)
        for name, expected in sorted(frozen["phase_files"].items())
    }

    phase = load(ROOT / frozen["phase_files"]["phase"]["path"])
    if phase.get("name") != "package_full_content_projection_regression" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 0 or \
            phase.get("timeout_seconds") != 300 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes", 2_147_483_648) >= \
            2_147_483_648 or phase.get("residual_heavy_processes") != []:
        raise RuntimeError("projection reuse phase did not naturally pass gates")
    if phase.get("stderr", {}).get("bytes") != 0:
        raise RuntimeError("projection reuse phase stderr was nonempty")

    observation = load(
        ROOT / frozen["phase_files"]["actual_observation"]["path"])
    if observation.get("schema") != \
            "vnext-t2-package-full-content-projection-actual-r1" or \
            observation.get("status") != "actual_observed" or \
            observation.get("planned_test_sites") != 24 or \
            observation.get("assertion_sites_completed") != 0 or \
            observation.get("recorded_before_assertions") is not True:
        raise RuntimeError("projection reuse observation mismatch")
    group_counts = {
        name: row.get("planned_sites")
        for name, row in observation.get("groups", {}).items()
    }
    if group_counts != {"reload_content_equivalence": 8,
                        "wire_byte_tamper_detection": 7,
                        "source_byte_tamper_detection": 7,
                        "admission_envelope_projection": 2}:
        raise RuntimeError("projection reuse semantic groups mismatch")
    stdout = (ROOT / frozen["phase_files"]["stdout"]["path"]).read_text(
        encoding="utf-8", errors="replace")
    if EXPECTED_PROJECTION_MARKER not in stdout:
        raise RuntimeError("projection reuse post-assertion PASS marker absent")
    timeout = load(
        ROOT / frozen["source_timeout_execution_receipt"]["path"])
    if timeout.get("completed_coverage", {}).get(
            "projection_assertion_sites_completed") != 24 or \
            timeout.get("inputs_stable") is not True:
        raise RuntimeError("projection reuse enclosing execution receipt invalid")

    output = {
        "schema": "vnext-t2-projection24-cross-run-validation-r10",
        "status": "pass",
        "source_protocol": old_protocol_receipt,
        "source_pipeline_final": old_pipeline,
        "source_timeout_execution_receipt": timeout_receipt,
        "phase_files": phase_files,
        "dependency_subset": observed_dependencies,
        "dependency_count": len(observed_dependencies),
        "r1_source_input_count": plan_summary["source_input_count"],
        "r1_input_intersection_count":
            plan_summary["r1_input_intersection_count"],
        "excluded_r1_input_count": plan_summary["excluded_r1_input_count"],
        "excluded_r1_input_rows": plan_summary["excluded_r1_input_rows"],
        "explicitly_consumed_paths": plan_summary["explicitly_consumed_paths"],
        "natural_exit_zero": True,
        "post_assertion_pass_marker": True,
        "assertion_sites_completed": 24,
        "semantic_group_site_counts": group_counts,
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(output, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    print("T2_PROJECTION24_REUSE=PASS sites=24 groups=4", flush=True)
    print(json.dumps({"status": "pass", "receipt": receipt(output_path)},
                     sort_keys=True), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
