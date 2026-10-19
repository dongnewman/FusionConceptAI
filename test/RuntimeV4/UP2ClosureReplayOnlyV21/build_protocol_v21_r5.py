#!/usr/bin/env python3
"""Freeze the R5 UP2 replay successor without changing the preserved R4 protocol."""
from __future__ import annotations

import argparse
import ast
import copy
import difflib
import hashlib
import json
import os
import pathlib
import re


BASE = pathlib.Path(__file__).resolve().parent
ROOT = BASE.parents[2]
R4_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r4.json"
R4_BYTES = 1_028_450
R4_SHA = "d4b221074907f5e79d063012f48d97c41a73acaee8e6c9260dd7cb4dd5846a0f"
R5_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r5.json"
R5_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r5.json"
R5_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r5.py"
CANONICAL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
WRAPPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"
TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
R5_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r5"
R5_STAGE = R5_ROOT / "archive_mirror"
R5_LEAF = R5_ROOT / "runtime_replay_r21_r5"
R5_PATH = ROOT / R5_REL
MUTABLE_SOURCE_PATHS = {CANONICAL_REL, WRAPPER_REL, TEST_REL}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def wire(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def source_path(relative: str) -> pathlib.Path:
    logical = pathlib.PurePosixPath(relative)
    if logical.is_absolute() or any(part in ("", ".", "..") for part in logical.parts):
        raise ValueError(f"non-confined source path: {relative}")
    result = (ROOT / pathlib.Path(*logical.parts)).resolve()
    if not result.is_relative_to(ROOT.resolve()) or not result.is_file():
        raise FileNotFoundError(f"required source absent: {relative}")
    return result


def source_row(relative: str) -> dict[str, object]:
    content = source_path(relative).read_bytes()
    return {"path": relative, "bytes": len(content), "sha256": sha(content)}


def exact_overlay(original: bytes, spec: dict[str, object]) -> bytes:
    source = original.decode("utf-8")
    replacements = spec.get("replacements")
    if not isinstance(replacements, list) or len(replacements) != 8:
        raise ValueError("R5 overlay must have exactly eight replacements")
    mapping = {}
    for row in replacements:
        if not isinstance(row, dict) or not isinstance(row.get("old_line"), str) or \
                not isinstance(row.get("new_line"), str) or row["old_line"] in mapping:
            raise ValueError("malformed or duplicate R5 overlay line")
        mapping[row["old_line"]] = row["new_line"]
    nodes = [node for node in ast.parse(source).body
             if isinstance(node, ast.FunctionDef) and node.name == "verify_v20_actual_failure"]
    if len(nodes) != 1 or nodes[0].end_lineno is None:
        raise ValueError("R5 V20 exact function missing")
    order_line = "    if file_inventory(runtime_root) != runtime_entries:"
    counts = {old: 0 for old in mapping}
    transformed = []
    for lineno, line in enumerate(source.splitlines(keepends=True), 1):
        body = line.rstrip("\r\n")
        if body == order_line and not nodes[0].lineno <= lineno <= nodes[0].end_lineno:
            transformed.append(line)
        elif body in mapping:
            counts[body] += 1
            transformed.append(mapping[body] + line[len(body):])
        else:
            transformed.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R5 overlay line cardinality changed: {counts}")
    return "".join(transformed).encode("utf-8")


def path_binding_addendum(parent: dict[str, object], base: bytes) -> dict[str, object]:
    addendum = copy.deepcopy(parent)
    replacements = addendum.get("replacements")
    if not isinstance(replacements, list) or len(replacements) != 2:
        raise ValueError("R4 V10 path-binding cardinality changed")
    mapping = {row["old_line"]: row["new_line"] for row in replacements}
    if len(mapping) != 2:
        raise ValueError("R4 V10 path-binding duplicate")
    counts = {old: 0 for old in mapping}
    output = []
    for line in base.decode("utf-8").splitlines(keepends=True):
        body = line.rstrip("\r\n")
        if body in mapping:
            counts[body] += 1
            output.append(mapping[body] + line[len(body):])
        else:
            output.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R5 V10 path-binding line cardinality changed: {counts}")
    addendum["base_transformed_source_sha256"] = sha(base)
    addendum["transformed_source_sha256"] = sha("".join(output).encode("utf-8"))
    return addendum


def build() -> tuple[dict[str, object], dict[str, object]]:
    r4_path = source_path(R4_REL)
    r4_wire = r4_path.read_bytes()
    if len(r4_wire) != R4_BYTES or sha(r4_wire) != R4_SHA:
        raise ValueError("preserved R4 parent protocol bytes differ")
    r4 = json.loads(r4_wire)
    if (r4.get("schema"), r4.get("version"), r4.get("classification"), r4.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v21", 21, "test_only_continuation", False):
        raise ValueError("R4 parent status or no-credit boundary changed")
    for path in (R5_ROOT, R5_STAGE, R5_LEAF):
        if path.exists() or path.resolve().is_relative_to((ROOT / "docs").resolve()):
            raise FileExistsError(f"R5 output root must be absent and outside repository docs: {path}")
    if R5_PATH.exists():
        raise FileExistsError("R5 protocol already exists; never overwrite it")
    spec = json.loads(source_path(R5_SPEC_REL).read_bytes())
    original = source_path(CANONICAL_REL).read_bytes()
    if spec.get("schema") != "mms-v21-r5-controller-overlay-spec-v1" or \
            spec.get("original_controller_path") != CANONICAL_REL or \
            spec.get("original_controller_sha256") != sha(original) or \
            spec.get("replacement_count") != 8:
        raise ValueError("R5 spec is not bound to the current canonical source")
    r4_spec = json.loads(source_path(
        "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r4.json").read_bytes())
    r4_replacements = r4_spec.get("replacements")
    replacements = spec.get("replacements")
    if not isinstance(replacements, list) or not isinstance(r4_replacements, list) or len(replacements) != 8:
        raise ValueError("R5 overlay row count differs")
    for index, (old, new) in enumerate(zip(r4_replacements, replacements)):
        if old.get("old_line") != new.get("old_line"):
            raise ValueError(f"R5 overlay changed inherited source predicate at row {index}")
        if index in (0, 4, 5, 6, 7) and old.get("new_line") != new.get("new_line"):
            raise ValueError(f"R5 overlay changed unrelated R4 behavior at row {index}")
    if "replay_protocol_v21_r5.json" not in replacements[1]["new_line"] or \
            "up2_replay_v21_r5" not in replacements[2]["new_line"] or \
            "up2_replay_v21_r5" not in replacements[3]["new_line"]:
        raise ValueError("R5 protocol and output routes do not name the fixed successor")
    transformed = exact_overlay(original, spec)
    diff = "".join(difflib.unified_diff(
        original.decode("utf-8").splitlines(keepends=True),
        transformed.decode("utf-8").splitlines(keepends=True),
        fromfile="run_replay_staged_v21.py (R5 frozen source)",
        tofile="run_replay_staged_v21_r4.py (R5 eight exact overlays)"))
    result = copy.deepcopy(r4)
    output_old = pathlib.Path(r4["r4_output_ownership"]["raw_external_root"])
    if output_old == R5_ROOT or not output_old.is_absolute():
        raise ValueError("R4 output ownership malformed")
    old_stage = pathlib.Path(r4["r4_output_ownership"]["archive_mirror_root"])
    old_leaf = pathlib.Path(r4["r4_output_ownership"]["runtime_output_leaf"])
    if old_stage != output_old / "archive_mirror" or old_leaf.parent != output_old:
        raise ValueError("R4 output tree malformed")
    result["parent_r4_protocol"] = {"path": R4_REL, "bytes": R4_BYTES, "sha256": R4_SHA}
    result["controller"] = WRAPPER_REL
    result["archived_input_source"]["staging_root"] = str(R5_STAGE.resolve())
    producer = result["child_command_contract"]["producer"]
    if len(producer) != 10 or old_stage.as_posix().lower() not in producer[6].replace("\\", "/").lower():
        raise ValueError("R4 producer command is not bound to its old mirror")
    producer[6] = producer[6].replace(str(old_stage), str(R5_STAGE.resolve()))
    if producer[6] == r4["child_command_contract"]["producer"][6]:
        raise ValueError("R5 producer command did not move to the new mirror")
    result["output_leaf"] = str(R5_LEAF.resolve())
    result["coverage_contract"]["output_leaf"] = str(R5_LEAF.resolve())
    ownership = result["r4_output_ownership"]
    ownership["raw_external_root"] = str(R5_ROOT.resolve())
    ownership["archive_mirror_root"] = str(R5_STAGE.resolve())
    ownership["runtime_output_leaf"] = str(R5_LEAF.resolve())
    ownership["owner"] = "UP2ClosureReplayOnlyV21 R5 exact V10 input resolver successor"
    for key in ("r4_checked_path_v6_scopefix_addendum_route",
                "r4_checked_path_v10_root_observation_input_route"):
        result[key]["materialization_root"] = str(R5_STAGE.resolve())
    result["controller_command_template"] = (
        f'{result["runtime"]["python_executable"]} -B {WRAPPER_REL} --protocol {R5_REL} '
        f'--protocol-sha256 <protocol-sha256> --output {R5_LEAF.resolve()} --root-serial-slot-granted')
    prior_overlay = result["r4_controller_overlay"]
    prior_overlay["original_controller_sha256_before"] = sha(original)
    prior_overlay["original_controller_sha256_after"] = sha(original)
    prior_overlay["transformed_source_sha256"] = sha(transformed)
    prior_overlay["overlay_spec_path"] = R5_SPEC_REL
    prior_overlay["overlay_spec_sha256"] = sha(source_path(R5_SPEC_REL).read_bytes())
    prior_overlay["replacement_count"] = 8
    prior_overlay["replacements"] = copy.deepcopy(replacements)
    prior_overlay["guard_consumption_binding_correction"]["corrected_call"] = replacements[6]["new_line"]
    prior_overlay["unified_diff"] = diff
    prior_overlay["unified_diff_sha256"] = sha(diff.encode("utf-8"))
    result["r4_v10_recorded_path_binding_addendum"] = path_binding_addendum(
        r4["r4_v10_recorded_path_binding_addendum"], transformed)
    old_rows = r4.get("owned_source_files")
    if not isinstance(old_rows, list) or len(old_rows) != 20:
        raise ValueError("R4 source inventory count changed")
    old_pins = {row["path"]: row for row in old_rows}
    if len(old_pins) != 20:
        raise ValueError("R4 source inventory duplicate")
    for relative, row in old_pins.items():
        if relative not in MUTABLE_SOURCE_PATHS:
            actual = source_row(relative)
            if actual != row:
                raise ValueError(f"immutable R4 ancestor source differs: {relative}")
    rels = sorted(set(old_pins) | {R5_BUILDER_REL, R5_SPEC_REL})
    rows = [source_row(relative) for relative in rels]
    result["owned_source_files"] = rows
    result["owned_source_files_by_path"] = {row["path"]: row["sha256"] for row in rows}
    result["r5_exact_input_resolution"] = {
        "schema": "mms-v21-r5-exact-v10-workspace-input-resolution-v1",
        "non_doc_rows": 71,
        "docs_rows": 18,
        "total_v10_rows": 89,
        "resolver_symbol": "resolve_non_doc_v10_input",
        "source_path": CANONICAL_REL,
        "source_sha256": sha(original),
        "runtime_grant": False,
        "numerical_credit": False,
        "physical_credit": False,
        "r4_protocol_unchanged": True,
    }
    expected_coverage = copy.deepcopy(r4["coverage_contract"])
    expected_coverage["output_leaf"] = str(R5_LEAF.resolve())
    frozen_equal_keys = (
        "aggregate_child_wall_contract", "aggregate_child_wall_definition",
        "aggregate_overrun_policy", "controller_overhead_definition",
        "controller_overhead_seconds_limit", "total_child_wall_limit_seconds",
        "termination_cleanup_grace_seconds", "process_tree_monitor_contract",
        "receipt_contract", "preserved_numerical_status",
        "original_v10_contract_not_retroactively_closed", "runtime_grant",
        "classification", "static_test_contract",
    )
    if result["coverage_contract"] != expected_coverage or \
            result["stage_limits"] != r4["stage_limits"] or \
            result["stage_limits"].get("seconds") != 480 or \
            result["stage_limits"].get("working_set_bytes") != 2_147_483_648 or \
            result["resource_contract"] != r4["resource_contract"] or \
            result["resource_contract"].get("aggregate_child_wall_limit_seconds") != 960 or \
            result["resource_contract"].get("controller_overhead_limit_seconds") != 120 or \
            result["controller_overhead_seconds_limit"] != 120 or \
            result["total_child_wall_limit_seconds"] != 960 or \
            result["preserved_numerical_status"] != {
                "authority": "no_publish", "physical_validation": "unsupported",
                "solver_exit_code": 2, "status": "fail",
                "stopping_reason": "stationary_nonzero_residual"} or \
            result["classification"] != "test_only_continuation" or \
            result["runtime_grant"] is not False or \
            any(result.get(key) != r4.get(key) for key in frozen_equal_keys) or \
            len(result["archived_input_source"]["entries"]) != 613 or \
            len(result["archived_input_source"]["referenced_paths"]) != 645 or \
            result["v10_protocol"].get("pinned_input_count") != 89:
        raise ValueError("R5 coverage, resources, or archive closure changed")
    summary = {
        "schema": "mms-v21-r5-builder-summary-v1",
        "parent_r4_sha256": R4_SHA,
        "source_rows": len(rows),
        "archive_rows": 613,
        "archive_refs": 645,
        "v10_rows": 89,
        "output_root_absent": not R5_ROOT.exists(),
        "runtime_grant": False,
    }
    return result, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    protocol, summary = build()
    content = wire(protocol)
    summary["protocol_bytes"] = len(content)
    summary["protocol_sha256"] = sha(content)
    if args.write:
        with R5_PATH.open("xb") as target:
            target.write(content)
            target.flush()
            os.fsync(target.fileno())
        summary["written"] = True
    else:
        summary["written"] = False
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
