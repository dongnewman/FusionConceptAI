#!/usr/bin/env python3
"""Freeze the corrected R6 UP2 replay protocol from the preserved failed R5."""
from __future__ import annotations

import argparse
import copy
import difflib
import json
import os
import pathlib

from build_protocol_v21_r5 import (
    R4_BYTES, R4_REL, R4_SHA, exact_overlay, path_binding_addendum,
    sha, source_path, source_row, wire,
)


BASE = pathlib.Path(__file__).resolve().parent
ROOT = BASE.parents[2]
R5_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r5.json"
R5_BYTES = 1_029_337
R5_SHA = "7ed9c0bd849f0540b1ccb31a805f9055ea31f3bb6d20803cca0ec7216c808274"
R6_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r6.json"
R6_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r6.json"
R6_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r6.py"
WRAPPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"
CANONICAL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
R6_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r6"
R6_STAGE = R6_ROOT / "archive_mirror"
R6_LEAF = R6_ROOT / "runtime_replay_r21_r6"
R6_PATH = ROOT / R6_REL
MUTABLE_FROM_R5 = {WRAPPER_REL, TEST_REL}


def build() -> tuple[dict[str, object], dict[str, object]]:
    parent_wire = source_path(R5_REL).read_bytes()
    if len(parent_wire) != R5_BYTES or sha(parent_wire) != R5_SHA:
        raise ValueError("preserved failed R5 protocol differs from its executed QA identity")
    parent = json.loads(parent_wire)
    if (parent.get("schema"), parent.get("version"), parent.get("classification"),
            parent.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v21", 21, "test_only_continuation", False):
        raise ValueError("R5 parent no-credit status differs")
    r4_wire = source_path(R4_REL).read_bytes()
    if parent.get("parent_r4_protocol") != {"path": R4_REL, "bytes": R4_BYTES, "sha256": R4_SHA} or \
            len(r4_wire) != R4_BYTES or sha(r4_wire) != R4_SHA:
        raise ValueError("current R4 protocol differs from the exact R5 recorded ancestor")
    for path in (R6_ROOT, R6_STAGE, R6_LEAF):
        if path.exists() or path.resolve().is_relative_to((ROOT / "docs").resolve()):
            raise FileExistsError(f"R6 output root must be absent and outside docs: {path}")
    if R6_PATH.exists():
        raise FileExistsError("R6 protocol already exists; never overwrite it")
    original = source_path(CANONICAL_REL).read_bytes()
    spec = json.loads(source_path(R6_SPEC_REL).read_bytes())
    r5_spec_rel = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r5.json"
    r5_spec = json.loads(source_path(r5_spec_rel).read_bytes())
    if spec.get("schema") != "mms-v21-r6-controller-overlay-spec-v1" or \
            spec.get("original_controller_path") != CANONICAL_REL or \
            spec.get("original_controller_sha256") != sha(original) or \
            spec.get("replacement_count") != 8:
        raise ValueError("R6 spec is not bound to the current canonical controller")
    before = r5_spec.get("replacements")
    after = spec.get("replacements")
    if not isinstance(before, list) or not isinstance(after, list) or len(before) != 8 or len(after) != 8:
        raise ValueError("R6 eight-overlay cardinality differs")
    for index, (old, new) in enumerate(zip(before, after)):
        if not isinstance(old, dict) or not isinstance(new, dict) or old.get("old_line") != new.get("old_line"):
            raise ValueError(f"R6 overlay changes inherited source predicate at row {index}")
        expected = old.get("new_line")
        if not isinstance(expected, str):
            raise ValueError(f"R5 overlay row {index} is malformed")
        if index == 1:
            expected = expected.replace("replay_protocol_v21_r5.json", "replay_protocol_v21_r6.json")
        elif index in (2, 3):
            expected = expected.replace("up2_replay_v21_r5", "up2_replay_v21_r6")
            if index == 3:
                expected = expected.replace("V21 R5 output_leaf", "V21 R6 output_leaf")
        if new.get("new_line") != expected:
            raise ValueError(f"R6 overlay changes unrelated inherited behavior at row {index}")
    transformed = exact_overlay(original, spec)
    diff = "".join(difflib.unified_diff(
        original.decode("utf-8").splitlines(keepends=True),
        transformed.decode("utf-8").splitlines(keepends=True),
        fromfile="run_replay_staged_v21.py (R6 frozen source)",
        tofile="run_replay_staged_v21_r4.py (R6 eight exact overlays)"))
    result = copy.deepcopy(parent)
    prior_owner = parent["r4_output_ownership"]
    old_root = pathlib.Path(prior_owner["raw_external_root"])
    old_stage = pathlib.Path(prior_owner["archive_mirror_root"])
    old_leaf = pathlib.Path(prior_owner["runtime_output_leaf"])
    if old_root.name != "up2_replay_v21_r5" or old_stage != old_root / "archive_mirror" or \
            old_leaf != old_root / "runtime_replay_r21_r5":
        raise ValueError("R5 parent output identity differs")
    result["parent_r5_protocol"] = {"path": R5_REL, "bytes": R5_BYTES, "sha256": R5_SHA}
    result["archived_input_source"]["staging_root"] = str(R6_STAGE.resolve())
    producer = result["child_command_contract"]["producer"]
    if len(producer) != 10 or str(old_stage) not in producer[6]:
        raise ValueError("R5 producer is not bound to the exact old mirror")
    producer[6] = producer[6].replace(str(old_stage), str(R6_STAGE.resolve()))
    result["output_leaf"] = str(R6_LEAF.resolve())
    result["coverage_contract"]["output_leaf"] = str(R6_LEAF.resolve())
    owner = result["r4_output_ownership"]
    owner["raw_external_root"] = str(R6_ROOT.resolve())
    owner["archive_mirror_root"] = str(R6_STAGE.resolve())
    owner["runtime_output_leaf"] = str(R6_LEAF.resolve())
    owner["owner"] = "UP2ClosureReplayOnlyV21 R6 corrected static handoff successor"
    for key in ("r4_checked_path_v6_scopefix_addendum_route",
                "r4_checked_path_v10_root_observation_input_route"):
        result[key]["materialization_root"] = str(R6_STAGE.resolve())
    result["controller_command_template"] = (
        f'{result["runtime"]["python_executable"]} -B {WRAPPER_REL} --protocol {R6_REL} '
        f'--protocol-sha256 <protocol-sha256> --output {R6_LEAF.resolve()} --root-serial-slot-granted')
    overlay = result["r4_controller_overlay"]
    overlay["original_controller_sha256_before"] = sha(original)
    overlay["original_controller_sha256_after"] = sha(original)
    overlay["transformed_source_sha256"] = sha(transformed)
    overlay["overlay_spec_path"] = R6_SPEC_REL
    overlay["overlay_spec_sha256"] = sha(source_path(R6_SPEC_REL).read_bytes())
    overlay["replacement_count"] = 8
    overlay["replacements"] = copy.deepcopy(after)
    overlay["guard_consumption_binding_correction"]["corrected_call"] = after[6]["new_line"]
    overlay["unified_diff"] = diff
    overlay["unified_diff_sha256"] = sha(diff.encode("utf-8"))
    result["r4_v10_recorded_path_binding_addendum"] = path_binding_addendum(
        parent["r4_v10_recorded_path_binding_addendum"], transformed)
    old_rows = parent.get("owned_source_files")
    if not isinstance(old_rows, list) or len(old_rows) != 22:
        raise ValueError("R5 source inventory count changed")
    old_pins = {row["path"]: row for row in old_rows}
    if len(old_pins) != 22:
        raise ValueError("R5 source inventory duplicate")
    for relative, row in old_pins.items():
        if relative not in MUTABLE_FROM_R5 and source_row(relative) != row:
            raise ValueError(f"immutable R5 ancestor source differs: {relative}")
    rels = sorted(set(old_pins) | {R5_REL, R6_BUILDER_REL, R6_SPEC_REL})
    rows = [source_row(relative) for relative in rels]
    result["owned_source_files"] = rows
    result["owned_source_files_by_path"] = {row["path"]: row["sha256"] for row in rows}
    expected_coverage = copy.deepcopy(parent["coverage_contract"])
    expected_coverage["output_leaf"] = str(R6_LEAF.resolve())
    frozen_equal_keys = (
        "aggregate_child_wall_contract", "aggregate_child_wall_definition",
        "aggregate_overrun_policy", "controller_overhead_definition",
        "controller_overhead_seconds_limit", "total_child_wall_limit_seconds",
        "termination_cleanup_grace_seconds", "process_tree_monitor_contract",
        "receipt_contract", "preserved_numerical_status",
        "original_v10_contract_not_retroactively_closed", "runtime_grant",
        "classification", "static_test_contract", "stage_limits", "resource_contract",
    )
    if result["coverage_contract"] != expected_coverage or \
            any(result.get(key) != parent.get(key) for key in frozen_equal_keys) or \
            result["stage_limits"].get("seconds") != 480 or \
            result["stage_limits"].get("working_set_bytes") != 2_147_483_648 or \
            result["resource_contract"].get("aggregate_child_wall_limit_seconds") != 960 or \
            result["resource_contract"].get("controller_overhead_limit_seconds") != 120 or \
            result["preserved_numerical_status"] != {
                "authority": "no_publish", "physical_validation": "unsupported",
                "solver_exit_code": 2, "status": "fail",
                "stopping_reason": "stationary_nonzero_residual"} or \
            result["classification"] != "test_only_continuation" or result["runtime_grant"] is not False or \
            len(result["archived_input_source"]["entries"]) != 613 or \
            len(result["archived_input_source"]["referenced_paths"]) != 645 or \
            result["v10_protocol"].get("pinned_input_count") != 89:
        raise ValueError("R6 coverage, resources, numerical, or closure status changed")
    return result, {
        "schema": "mms-v21-r6-builder-summary-v1", "parent_r5_sha256": R5_SHA,
        "source_rows": len(rows), "archive_rows": 613, "archive_refs": 645,
        "v10_rows": 89, "output_root_absent": not R6_ROOT.exists(),
        "runtime_grant": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    protocol, summary = build()
    content = wire(protocol)
    summary["protocol_bytes"] = len(content)
    summary["protocol_sha256"] = sha(content)
    if args.write:
        with R6_PATH.open("xb") as target:
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
