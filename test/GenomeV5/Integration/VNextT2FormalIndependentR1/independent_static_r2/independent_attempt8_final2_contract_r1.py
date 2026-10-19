from __future__ import annotations

import ast
import copy
import hashlib
import json
import re
import sys
import traceback
from pathlib import Path
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[5]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2"
)
ATTEMPT7 = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt7"
)
OLD_MAP_PATH = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json"
)
RESULT_DIR = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt8_final2_static_20260923_r1"
)

EXPECTED_FREEZE_HASHES = {
    "protocol.json": "4ad2c2448c8fe406fd05877ee8acbcd81acb10227fe598d8a5f0d0e118ca3ee4",
    "coverage_map_r3.json": "59442e71116459b9de143d8edcfe451a6c1fbf8ad09187b89ba5fdd3b1a3af27",
    "static_qa.json": "bb7a0c0bf3b991622ab969b253ce3b7be156abcf564411eadaf33abce2ede06f",
}
EXPECTED_SOURCE_HASHES = {
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r3.jl":
        "e1e2946c960da8c4220e66896ae4dc89202e6ef9394d2d0c0d8853bab86c2c1e",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r3.py":
        "1c8dedba22f2f4f327dca30f2c92f36bf70cfe35fce398445e8325707744ed16",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/build_coverage_map_r3.py":
        "0cd5d4b929dc256ecc6baedbc4eaf3d32e134716822ef623129a66fe7a8949e0",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/freeze_independent_negative_protocol_r3.py":
        "9af35d20e6aa87cba4d0a339c336bd5142cf145612114daabee589c16a54ebf2",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r3.py":
        "c065499f1ce051ae1fe4671d5a1c6b2196175bc0d433db722c65d25707b26472",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_ast_inventory_r3.jl":
        "804af0740293f5c489c9652b3814e8bc2b7db1938617497e2c070ba651ea3787",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/validate_projection24_reuse_r3.py":
        "ca46d5c73d4f95b2f328f25fe9e1a3647ab7afd02b9a00c50aeb73f63c7af2c9",
}

EXPECTED_CACHE_ROWS = [
    {
        "path": (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "__pycache__/freeze_independent_negative_protocol_r3.cpython-313.pyc"
        ),
        "bytes": 48089,
        "sha256": "ebc3c1cfc31b7acf306d5f9addfaff5e45ca4a6772877585148a7df57d897608",
    },
    {
        "path": (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "__pycache__/static_qa_independent_negative_r3.cpython-313.pyc"
        ),
        "bytes": 72660,
        "sha256": "30cf8b444ec15c98e018a8cfb261e650acc61cf431e83ef65d59535cc5e51e4b",
    },
]

EXPECTED_FORMAL_PHASES = [
    "actual_formal_baseline",
    "actual_formal_preflight",
    "actual_formal_authority",
    "actual_formal_fault_n10",
    "actual_formal_t1_handoff",
]
EXPECTED_HIT_PHASES = [
    "actual_formal_baseline",
    "actual_formal_preflight",
    "actual_formal_authority",
    "actual_formal_fault_n10",
    "actual_formal_t1_handoff",
    "supplementary_edited_operation",
    "supplementary_child_coupling",
]
EXPECTED_TAIL_MARKERS = [
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


class ContractFailure(AssertionError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractFailure(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path, relative: str | None = None) -> dict[str, Any]:
    raw = path.read_bytes()
    return {
        "path": relative if relative is not None else path.as_posix(),
        "bytes": len(raw),
        "sha256": sha256(raw),
    }


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"JSON root is not an object: {path}")
    return value


def relative_receipt(relative: str) -> dict[str, Any]:
    return receipt(ROOT / relative, relative)


def pin_matches_live(relative: str, pin: dict[str, Any]) -> bool:
    if not isinstance(pin, dict):
        return False
    return relative_receipt(relative) == {
        "path": relative,
        "bytes": pin.get("bytes"),
        "sha256": pin.get("sha256"),
    } and pin.get("path", relative) == relative


def site_index(coverage: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = coverage.get("successor_assertion_sites")
    require(isinstance(rows, list), "successor_assertion_sites is not a list")
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        require(isinstance(row, dict) and isinstance(row.get("id"), str),
                "site row has no string id")
        site_id = row["id"]
        require(site_id not in result, f"duplicate assertion site id: {site_id}")
        result[site_id] = row
    return result


def reconstruct_source_site(lines: list[str], line_number: int,
                           expected_text: str, site_id: str) -> tuple[str, int]:
    pieces: list[str] = []
    for end in range(line_number - 1, min(line_number + 20, len(lines))):
        piece = lines[end].strip()
        if piece:
            pieces.append(piece)
        reconstructed = " ".join(pieces)
        if reconstructed == expected_text:
            return reconstructed, end + 1
        require(expected_text.startswith(reconstructed),
                f"source site text diverges while resolving physical lines: {site_id}")
    raise ContractFailure(
        f"source site text does not close from its pinned starting line: {site_id}"
    )


def validate_formal_cases(old: dict[str, Any], new: dict[str, Any]) -> dict[str, Any]:
    old_plan = old["runtime_execution_plan"]
    new_plan = new["runtime_execution_plan"]
    for field in (
        "actual_formal_phase_case_ids",
        "actual_formal_phase_observation_ids",
        "actual_formal_summary_case_ids",
    ):
        require(old_plan.get(field) == new_plan.get(field),
                f"attempt7→8 formal execution plan changed: {field}")
    phase_cases = new_plan["actual_formal_phase_case_ids"]
    require(set(phase_cases) == set(EXPECTED_FORMAL_PHASES),
            "formal case phase key set changed")
    formal_ids = [
        case_id
        for phase in EXPECTED_FORMAL_PHASES
        for case_id in phase_cases[phase]
    ]
    require(len(formal_ids) == 45 and len(set(formal_ids)) == 45,
            "formal case inventory is not 45 unique IDs")
    require(len(new["successor_cases"]) == 60 and
            new["successor_cases"] == old["successor_cases"],
            "full 60-case successor plan changed")
    require(new_plan["actual_formal_summary_case_ids"] ==
            [case["id"] for case in new["successor_cases"]
             if case["id"] in set(formal_ids)],
            "formal summary case mapping differs from case inventory")
    return {
        "formal_case_count": len(formal_ids),
        "formal_case_ids": formal_ids,
        "successor_case_count": len(new["successor_cases"]),
        "phase_counts": {phase: len(phase_cases[phase])
                         for phase in EXPECTED_FORMAL_PHASES},
    }


def validate_site_plan(old: dict[str, Any], new: dict[str, Any],
                       protocol: dict[str, Any]) -> dict[str, Any]:
    old_sites = site_index(old)
    new_sites = site_index(new)
    require(len(old_sites) == 214 and len(new_sites) == 214,
            "attempt7/8 successor site count must be 214")
    require(set(old_sites) == set(new_sites),
            "attempt7/8 successor site ID set changed")

    old_driver = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "actual_formal_negative_driver_r2.jl"
    )
    new_driver = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "actual_formal_negative_driver_r3.jl"
    )
    path_moves = 0
    unchanged = 0
    relocation_rows: dict[str, dict[str, Any]] = {}
    current_source_lines_verified = 0
    for site_id in sorted(old_sites):
        previous = old_sites[site_id]
        current = new_sites[site_id]
        previous_semantics = {
            k: v for k, v in previous.items() if k not in ("path", "line")
        }
        current_semantics = {
            k: v for k, v in current.items() if k not in ("path", "line")
        }
        require(previous_semantics == current_semantics,
                f"site semantic obligation changed: {site_id}")
        require(current.get("line") == previous.get("line"),
                f"site line moved: {site_id}")
        require(current.get("source_text_matches_attempt7", True) is True,
                f"unexpected source-text mismatch for {site_id}")
        old_path = previous.get("path")
        new_path = current.get("path")
        path_changed = old_path != new_path
        line_delta = current["line"] - previous["line"]
        if path_changed:
            require(old_path == old_driver and new_path == new_driver,
                    f"unapproved site path relocation: {site_id}")
            path_moves += 1
        else:
            require(old_path == new_path and old_path != old_driver,
                    f"unexpected unchanged driver source path: {site_id}")
            unchanged += 1
        require(line_delta == 0, f"nonzero line delta for {site_id}")

        source_path = ROOT / new_path
        source_pin = protocol["inputs"].get(new_path)
        require(source_pin is not None and pin_matches_live(new_path, source_pin),
                f"current assertion source is absent or not hash pinned: {site_id}")
        lines = source_path.read_text(encoding="utf-8").splitlines()
        line_number = current.get("line")
        require(isinstance(line_number, int) and 1 <= line_number <= len(lines),
                f"current source line is out of range: {site_id}")
        source_text, source_end_line = reconstruct_source_site(
            lines, line_number, current.get("source_text", ""), site_id
        )
        require(sha256(source_text.encode("utf-8")) ==
                current.get("source_text_sha256"),
                f"current source line hash mismatch: {site_id}")
        current_source_lines_verified += 1
        relocation_rows[site_id] = {
            "attempt7": {"path": old_path, "line": previous["line"]},
            "attempt8": {"path": new_path, "line": line_number},
            "line_delta": line_delta,
            "path_changed": path_changed,
            "source_text": current["source_text"],
            "source_text_sha256": current["source_text_sha256"],
            "source_text_matches_attempt7": True,
            "current_source_line_verified": True,
            "id": site_id,
        }

    require(path_moves == 175 and unchanged == 39 and
            current_source_lines_verified == 214,
            "path relocation counts must be 175 / 39 with 214 current lines verified")
    ledger = protocol["attempt7_coverage_comparison"]["path_line_relocation_ledger"]
    require(ledger.get("status") ==
            "semantic_contract_equal_with_each_current_source_line_verified" and
            ledger.get("site_count") == 214 and
            ledger.get("path_changed_site_count") == 175 and
            ledger.get("line_changed_site_count") == 0 and
            ledger.get("current_source_line_verified_count") == 214 and
            ledger.get("source_text_match_count") == 214,
            "protocol relocation ledger summary mismatch")
    recorded_rows = {row["id"]: row for row in ledger["entries"]}
    require(set(recorded_rows) == set(relocation_rows),
            "protocol relocation ledger site ID set mismatch")
    for site_id, computed in relocation_rows.items():
        require(recorded_rows[site_id] == computed,
                f"protocol relocation ledger row mismatch: {site_id}")

    old_hits = old["successor_assertion_runtime_hit_plan"]
    new_hits = new["successor_assertion_runtime_hit_plan"]
    normalized_new_hits = copy.deepcopy(new_hits)
    expected_label_deltas = [
        {
            "key": "schema",
            "attempt7": "vnext-t2-independent-negative-assertion-hit-plan-r2",
            "attempt8": "vnext-t2-independent-negative-assertion-hit-plan-r3",
        },
        {
            "key": "old_focused_suite_mapping.status",
            "attempt7": "mapped_to_successor_not_executed_by_r2_shards",
            "attempt8": "mapped_to_successor_not_executed_by_r3_shards",
        },
        {
            "key": "projection24_mapping.status",
            "attempt7": "prior_actual_execution_reused_by_r2_python_validator",
            "attempt8": "prior_actual_execution_reused_by_r3_python_validator",
        },
    ]
    require(old_hits["schema"] == expected_label_deltas[0]["attempt7"] and
            new_hits["schema"] == expected_label_deltas[0]["attempt8"] and
            old_hits["old_focused_suite_mapping"]["status"] ==
            expected_label_deltas[1]["attempt7"] and
            new_hits["old_focused_suite_mapping"]["status"] ==
            expected_label_deltas[1]["attempt8"] and
            old_hits["projection24_mapping"]["status"] ==
            expected_label_deltas[2]["attempt7"] and
            new_hits["projection24_mapping"]["status"] ==
            expected_label_deltas[2]["attempt8"],
            "hit-plan generation label deltas differ from the exact allowlist")
    normalized_new_hits["schema"] = old_hits["schema"]
    normalized_new_hits["old_focused_suite_mapping"]["status"] = \
        old_hits["old_focused_suite_mapping"]["status"]
    normalized_new_hits["projection24_mapping"]["status"] = \
        old_hits["projection24_mapping"]["status"]
    require(normalized_new_hits == old_hits,
            "attempt7→8 hit plan changed beyond the three exact generation labels")
    require(new_hits["assertion_site_count"] == 214 and
            new_hits["expected_runtime_hit_count"] == 622,
            "expected hit plan must retain 214 sites / 622 hits")
    require(new_hits["phase_order"] == EXPECTED_HIT_PHASES,
            "site-hit phase order changed")
    computed_site_phase_hits = {
        site_id: new_sites[site_id]["expected_phase_hits"]
        for site_id in sorted(new_sites)
    }
    require(new_hits["site_expected_phase_hits"] == computed_site_phase_hits,
            "site_expected_phase_hits does not match per-site phase map")
    computed_phase_counts: dict[str, dict[str, int]] = {
        phase: {} for phase in EXPECTED_HIT_PHASES
    }
    for site_id, site in new_sites.items():
        hits = site.get("expected_phase_hits")
        require(isinstance(hits, dict) and hits,
                f"site has no expected phase hit relation: {site_id}")
        require(sum(hits.values()) == site["runtime_multiplicity"],
                f"site multiplicity differs from phase relation: {site_id}")
        for phase, count in hits.items():
            require(phase in computed_phase_counts and isinstance(count, int) and count > 0,
                    f"unknown or invalid expected phase relation: {site_id}/{phase}")
            computed_phase_counts[phase][site_id] = count
    require(new_hits["phase_site_hit_counts"] == computed_phase_counts,
            "per-phase site hit map differs from source-site relationships")
    require(sum(sum(rows.values()) for rows in computed_phase_counts.values()) == 622,
            "static site plan does not total 622 expected hits")
    require(protocol["coverage_assertion_hit_plan"]["site_expected_phase_hits"] ==
            computed_site_phase_hits,
            "protocol and coverage-map site hit maps differ")
    comparison = protocol["attempt7_coverage_comparison"]
    require(comparison.get("formal_case_count") == 45 and
            comparison.get("case_count") == 60 and
            comparison.get("successor_assertion_site_count") == 214 and
            comparison.get("successor_expected_runtime_hit_count") == 622 and
            comparison.get("semantic_case_ids_and_site_ids_equal") is True and
            comparison.get("site_assertion_text_multiplicity_and_phase_hits_equal") is True and
            comparison.get("full_path_line_map_byte_equal") is False,
            "attempt7→8 semantic comparison summary is inconsistent")
    return {
        "site_count": len(new_sites),
        "planned_hit_count": 622,
        "path_move_count": path_moves,
        "unchanged_path_count": unchanged,
        "line_delta_counts": {"zero": 214, "nonzero": 0},
        "current_source_line_verified": current_source_lines_verified,
        "hit_phase_counts": {
            phase: sum(rows.values())
            for phase, rows in computed_phase_counts.items()
        },
        "generation_label_deltas": expected_label_deltas,
    }


def validate_site_contract(old: dict[str, Any], new: dict[str, Any],
                            protocol: dict[str, Any]) -> None:
    validate_formal_cases(old, new)
    validate_site_plan(old, new, protocol)


def validate_budget(protocol: dict[str, Any], command: dict[str, Any],
                    controller_source: str) -> None:
    gates = protocol["resource_gates"]
    require(gates.get("phase_wall_seconds") == 480,
            "protocol phase budget is not exactly 480 seconds")
    require(gates.get("process_tree_working_set_bytes") == 2_147_483_648,
            "protocol memory cap is not exactly 2 GiB")
    require(gates.get("julia_threads") == 1 and
            gates.get("openblas_threads") == 1,
            "thread limit changed")
    argv = command["argv"]
    require(argv[argv.index("--phase-timeout") + 1] == "480" and
            argv[argv.index("--working-set-limit") + 1] == "2147483648",
            "frozen command data does not carry exact 480s/2GiB limits")
    require(command.get("julia_started") is False and
            command.get("formal_t2_accepted") is False and
            command.get("kind") == "non_executable_command_data",
            "dispatch data unexpectedly claims execution or is executable")
    exact_gate = re.compile(
        r"if\s+args\.phase_timeout\s*!=\s*480\s+or\s+"
        r"args\.working_set_limit\s*!=\s*2_147_483_648\s*:"
    )
    require(exact_gate.search(controller_source) is not None,
            "controller lacks exact 480s / 2GiB gate")
    tree = ast.parse(controller_source)
    run_calls = [
        node for node in ast.walk(tree)
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
        and node.func.id == "run_phase"
    ]
    require(len(run_calls) == 12,
            "controller phase runner call-site inventory changed")
    for call in run_calls:
        timeout_kw = next((kw.value for kw in call.keywords
                           if kw.arg == "timeout_seconds"), None)
        require(isinstance(timeout_kw, ast.Attribute) and
                timeout_kw.attr == "phase_timeout" and
                isinstance(timeout_kw.value, ast.Name) and
                timeout_kw.value.id == "args",
                "a phase bypasses the fixed timeout argument")


def validate_markers(protocol: dict[str, Any], driver_source: str) -> None:
    markers = protocol.get("baseline_diagnostic_marker_contract")
    require(markers == EXPECTED_TAIL_MARKERS,
            "baseline tail marker contract differs from expected order")
    event_patterns = [
        '_t2_neg_stage_begin("post_consumer_require_baseline")',
        '_t2_neg_stage_end("post_consumer_require_baseline"',
        '_t2_neg_stage_begin("baseline_second_up2_validate_input")',
        '_t2_neg_stage_end("baseline_second_up2_validate_input"',
        '_t2_neg_stage_begin("baseline_context_construction")',
        '_t2_neg_stage_end("baseline_context_construction"',
        '_t2_neg_stage_begin("baseline_context_serialization")',
        '_t2_neg_stage_end("baseline_context_serialization"',
        '_t2_neg_stage_event("baseline_summary_complete"',
    ]
    for pattern in event_patterns:
        require(driver_source.count(pattern) == 1,
                f"tail marker missing or duplicated: {pattern}")

    helper_start = driver_source.index("function _t2_neg_require_baseline!")
    helper_end = driver_source.index("\nend", helper_start)
    helper = driver_source[helper_start:helper_end]
    helper_order = [
        helper.index('_t2_neg_stage_begin("baseline_second_up2_validate_input")'),
        helper.index("FusionConceptAI.vnext_t2_up2_validate_input_v2(build.input)"),
        helper.index('_t2_neg_stage_end("baseline_second_up2_validate_input"'),
        helper.index("@test input_validation.status === :valid"),
    ]
    require(helper_order == sorted(helper_order),
            "nested baseline validation telemetry order changed")

    outer_order_patterns = [
        'assertion_started = _t2_neg_stage_begin("post_consumer_require_baseline")',
        "_t2_neg_require_baseline!(stream, live.build, result,",
        '_t2_neg_stage_end("post_consumer_require_baseline"',
        'context_build_started = _t2_neg_stage_begin("baseline_context_construction")',
        '_t2_neg_stage_end("baseline_context_construction"',
        'context_write_started = _t2_neg_stage_begin("baseline_context_serialization")',
        "_t2_neg_write_context(context_path, context)",
        '_t2_neg_stage_end("baseline_context_serialization"',
        '_t2_neg_stage_event("baseline_summary_complete"',
    ]
    outer_positions = [driver_source.index(pattern)
                       for pattern in outer_order_patterns]
    require(outer_positions == sorted(outer_positions),
            "baseline tail telemetry no longer encloses assertions/context in order")


def strip_r3_instrumentation(driver_source: str) -> str:
    normalized = driver_source.replace("r3", "r2").replace("R3", "R2")
    removals = [
        (
            'input_validation_started = _t2_neg_stage_begin("baseline_second_up2_validate_input"); ',
            "",
        ),
        (
            '; _t2_neg_stage_end("baseline_second_up2_validate_input", input_validation_started, detail="status=$(input_validation.status)")',
            "",
        ),
        (
            'assertion_started = _t2_neg_stage_begin("post_consumer_require_baseline"); ',
            "",
        ),
        (
            '; _t2_neg_stage_end("post_consumer_require_baseline", assertion_started, detail="status=complete"); context_build_started = _t2_neg_stage_begin("baseline_context_construction")',
            "",
        ),
        (
            '_t2_neg_stage_end("baseline_context_construction", context_build_started, detail="status=constructed"); context_write_started = _t2_neg_stage_begin("baseline_context_serialization"); ',
            "",
        ),
        (
            '; _t2_neg_stage_end("baseline_context_serialization", context_write_started, detail="bytes=$(context_receipt.bytes)")',
            "",
        ),
        (
            '; _t2_neg_stage_event("baseline_summary_complete", detail="status=$(summary.status)")',
            "",
        ),
    ]
    for old, new in removals:
        require(normalized.count(old) == 1,
                f"expected exactly one instrumentation fragment: {old[:70]}")
        normalized = normalized.replace(old, new, 1)
    return normalized


def validate_projection(protocol: dict[str, Any], root: Path,
                        projection_receipt: dict[str, Any]) -> dict[str, Any]:
    plan = protocol["projection24_reuse"]
    current_inputs = protocol["inputs"]
    require(plan.get("schema") ==
            "vnext-t2-projection24-cross-run-reuse-r1" and
            plan.get("status") == "frozen_r1_evidence_with_exact_current_join",
            "projection reuse plan schema/status mismatch")
    intersection = plan["r1_input_intersection"]
    excluded = plan["excluded_r1_input_rows"]
    dependencies = plan["dependency_subset"]
    phase_files = plan["phase_files"]
    require(len(intersection) == 151 and
            plan.get("source_input_count") == 157 and len(excluded) == 6 and
            plan.get("r1_input_intersection_count") == 151 and
            plan.get("excluded_r1_input_count") == 6 and
            len(dependencies) == 159 and
            plan.get("dependency_subset_count") == 159 and
            plan.get("dependency_count") == 159,
            "projection reuse counts differ from 157/151/6/159")
    require(set(phase_files) == {
        "actual_observation", "phase", "samples", "stderr", "stdout",
    }, "projection phase receipt file inventory changed")
    explicitly_used = [
        plan["source_protocol"]["path"],
        plan["source_pipeline_final"]["path"],
        plan["source_timeout_execution_receipt"]["path"],
        *[pin["path"] for pin in phase_files.values()],
    ]
    expected_dependency_paths = set(intersection) | set(explicitly_used)
    require(len(expected_dependency_paths) == 159 and
            set(dependencies) == expected_dependency_paths,
            "projection dependency set is not exact intersection plus receipts")
    explicit_pins = [
        plan["source_protocol"],
        plan["source_pipeline_final"],
        plan["source_timeout_execution_receipt"],
        *phase_files.values(),
    ]
    for pin in explicit_pins:
        relative = pin.get("path")
        require(relative in dependencies and dependencies[relative] == pin,
                f"projection explicit read pin is not joined: {relative}")
    for relative, pin in dependencies.items():
        require(pin == current_inputs.get(relative) and
                pin_matches_live(relative, pin),
                f"projection dependency pin differs from current input: {relative}")
    for relative, pin in intersection.items():
        require(pin.get("path") == relative and
                pin == dependencies.get(relative) and
                pin_matches_live(relative, pin),
                f"projection R1 intersection pin mismatch: {relative}")
    for row in excluded:
        historical = row["historical_pin"]
        require(row["classification"] in (
            "missing_from_current_r3_input_closure",
            "current_path_bytes_or_sha256_changed",
        ), "projection exclusion classification is invalid")
        current = row.get("current_pin")
        if row["classification"] == "missing_from_current_r3_input_closure":
            require(current is None and historical["path"] not in current_inputs,
                    "missing-input projection exclusion is not absent")
        else:
            require(current is not None and current["path"] in current_inputs and
                    current != historical,
                    "changed-input projection exclusion lacks a changed current pin")

    phase = projection_receipt["phase"]
    expected_phase_command = [
        protocol["python_cache_exclusion"]["static_qa_direct_argv_prefix"][0],
        "-B",
        str(root / protocol["projection24_reuse_validator_path"]),
        str(LEAF / "protocol.json"),
        str(LEAF / "projection24_reuse_preflight" / "reuse_receipt.json"),
    ]
    require(phase.get("status") == "pass" and phase.get("exit_code") == 0 and
            phase.get("stop_reason") == "natural_exit" and
            phase.get("command_argv") == expected_phase_command and
            phase.get("julia_started") is False and
            phase.get("formal_t2_accepted") is False and
            phase.get("pass_marker_observed") is True and
            phase.get("pass_marker") ==
            "T2_PROJECTION24_REUSE=PASS sites=24 groups=4" and
            phase.get("receipt") == projection_receipt["receipt_file_pin"] and
            phase.get("stdout") == projection_receipt["stdout_file_pin"] and
            phase.get("stderr") == projection_receipt["stderr_file_pin"] and
            projection_receipt["stderr"] == b"",
            "projection preflight phase receipt is not the expected Python check")
    receipt_data = projection_receipt["receipt"]
    require(receipt_data.get("schema") ==
            "vnext-t2-projection24-cross-run-validation-r3" and
            receipt_data.get("status") == "pass" and
            receipt_data.get("assertion_sites_completed") == 24 and
            receipt_data.get("formal_t2_accepted") is False and
            receipt_data.get("scientific_acceptance") is False and
            receipt_data.get("physical_acceptance") is False and
            receipt_data.get("natural_exit_zero") is True and
            receipt_data.get("post_assertion_pass_marker") is True and
            receipt_data.get("semantic_group_site_counts") == {
                "admission_envelope_projection": 2,
                "reload_content_equivalence": 8,
                "source_byte_tamper_detection": 7,
                "wire_byte_tamper_detection": 7,
            },
            "projection preflight receipt lacks 24-site nonqualifying result")
    stdout = projection_receipt["stdout"].decode("utf-8")
    require("T2_PROJECTION24_REUSE=PASS sites=24 groups=4" in stdout,
            "projection reuse natural-zero marker missing")
    return {
        "source_input_count": 157,
        "intersection_count": 151,
        "excluded_count": 6,
        "dependency_count": 159,
        "preflight_exit": 0,
        "projection_sites": 24,
        "projection_groups": 4,
    }


def validate_cache(protocol: dict[str, Any], command: dict[str, Any],
                   qa_report: dict[str, Any], actual_rows: list[dict[str, Any]],
                   test_root: Path, root: Path) -> dict[str, Any]:
    cache = protocol["python_cache_exclusion"]
    require(cache.get("schema") == "vnext-t2-generated-python-cache-exclusion-r1" and
            cache.get("status") == "excluded_from_current_input_closure_not_cleaned" and
            cache.get("cleaned") is False and cache.get("excluded_file_count") == 2,
            "cache exclusion status is not exact and non-cleaning")
    expected = EXPECTED_CACHE_ROWS
    require(cache.get("excluded_files") == expected and actual_rows == expected,
            "actual cache inventory differs from exact two pinned pyc files")
    inputs = protocol["inputs"]
    require(all(row["path"] not in inputs for row in expected),
            "excluded pyc appears in current execution input closure")
    cache_dirs = sorted(
        p.relative_to(root).as_posix()
        for p in test_root.rglob("__pycache__")
        if p.is_dir()
    )
    expected_cache_dir = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/__pycache__"
    )
    require(expected_cache_dir in cache_dirs,
            "frozen pyc cache directory is missing")
    tester_cache_dir = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "independent_static_r2/__pycache__"
    )
    extra_cache_dirs = [path for path in cache_dirs
                        if path != expected_cache_dir]
    require(extra_cache_dirs in ([], [tester_cache_dir]) and
            all(not any((root / path).iterdir()) for path in extra_cache_dirs),
            "unexpected cache directory or nonempty tester cache directory")

    freeze_entry = cache["freeze_entrypoint"]
    require(freeze_entry.get("path") ==
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "freeze_independent_negative_protocol_r3.py" and
            freeze_entry.get("mode") == "direct_script_as_main" and
            freeze_entry.get("argv0_matches_source") is True and
            freeze_entry.get("sys_dont_write_bytecode") is True,
            "freezer was not recorded as direct source execution")
    qa_argv = cache["static_qa_direct_argv_prefix"]
    require(len(qa_argv) == 3 and qa_argv[1] == "-B" and
            qa_argv[2].endswith(
                "\\test\\GenomeV5\\Integration\\VNextT2FormalIndependentR1\\"
                "static_qa_independent_negative_r3.py"),
            "static QA command is not a direct source entrypoint")
    qa_context = qa_report["python_execution_context"]
    require(qa_context.get("mode") == "direct_script_as_main" and
            qa_context.get("argv0_matches_source") is True and
            qa_context.get("sys_dont_write_bytecode") is True,
            "static QA actual execution context does not match direct source mode")
    runtime_argv = command["argv"]
    require(runtime_argv[1] == "-B" and
            runtime_argv[2].endswith(
                "\\test\\GenomeV5\\Integration\\VNextT2FormalIndependentR1\\"
                "independent_negative_controller_r3.py"),
            "runtime controller command is not direct Python source")

    module_names = cache.get("qa_dynamic_import_module_names")
    require(module_names == [
        "vnext_t2_controller_r3",
        "vnext_t2_projection24_reuse_r3",
    ], "static QA dynamic module import allowlist changed")
    require(cache.get("cache_module_import_targets") == [] and
            qa_report["python_cache_exclusion"].get(
                "cache_modules_imported_as_modules") == [] and
            qa_report["python_cache_exclusion"].get(
                "controller_and_projection_sources_hash_pinned_before_loader") is True,
            "excluded pyc modules may be imported or source pins precede no loader")
    excluded_names = {Path(row["path"]).name for row in expected}
    require(excluded_names.isdisjoint({
        "independent_negative_controller_r3.cpython-313.pyc",
        "validate_projection24_reuse_r3.cpython-313.pyc",
    }), "excluded cache matches a module loaded by QA")
    for source_path in (
        protocol["controller_path"],
        protocol["projection24_reuse_validator_path"],
    ):
        source_cache = root / Path(source_path).parent / "__pycache__" / (
            Path(source_path).stem + ".cpython-313.pyc"
        )
        require(not source_cache.exists(),
                f"imported source has a bytecode cache candidate: {source_cache}")

    freezer_source = (root / freeze_entry["path"]).read_text(encoding="utf-8")
    static_qa_source = (
        root / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "static_qa_independent_negative_r3.py"
    ).read_text(encoding="utf-8")
    controller_source = (root / protocol["controller_path"]).read_text(
        encoding="utf-8")
    projection_source = (
        root / protocol["projection24_reuse_validator_path"]
    ).read_text(encoding="utf-8")
    excluded_modules = {
        "freeze_independent_negative_protocol_r3",
        "static_qa_independent_negative_r3",
    }
    for label, source in (
        ("freezer", freezer_source),
        ("static QA", static_qa_source),
        ("controller", controller_source),
        ("projection validator", projection_source),
    ):
        tree = ast.parse(source)
        imported_modules = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported_modules.extend(alias.name.split(".")[0]
                                        for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported_modules.append(node.module.split(".")[0])
        require(not (set(imported_modules) & excluded_modules),
                f"{label} imports an excluded direct-entrypoint module: "
                f"{set(imported_modules) & excluded_modules}")
        dynamic_import_calls = []
        for node in ast.walk(tree):
            if not isinstance(node, ast.Call):
                continue
            fn = node.func
            if isinstance(fn, ast.Name) and fn.id in (
                "__import__", "import_module", "run_module", "run_path"
            ):
                dynamic_import_calls.append(fn.id)
        require(not dynamic_import_calls,
                f"{label} uses unrestricted dynamic import: {dynamic_import_calls}")

    loader_names = []
    for node in ast.walk(ast.parse(static_qa_source)):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and \
                node.func.attr == "spec_from_file_location" and node.args and \
                isinstance(node.args[0], ast.Constant):
            loader_names.append(node.args[0].value)
    require(loader_names == module_names,
            "static QA imports a module beyond controller/projection source")
    require("freeze_independent_negative_protocol_r3" not in loader_names and
            "static_qa_independent_negative_r3" not in loader_names,
            "one of the excluded direct-entrypoint pycs is imported as a module")

    return {
        "excluded_pyc_count": 2,
        "exact_live_inventory": True,
        "cache_paths_are_not_current_inputs": True,
        "direct_source_entrypoints": 3,
        "dynamic_source_imports": loader_names,
        "matching_imported_module_pycs": 0,
        "cache_cleaned": False,
        "empty_tester_cache_dirs": extra_cache_dirs,
    }


def expect_reject(name: str, action: Callable[[], Any],
                  controls: list[dict[str, Any]]) -> None:
    try:
        action()
    except (AssertionError, KeyError, TypeError, ValueError, OSError):
        controls.append({"name": name, "status": "pass", "result": "rejected"})
        return
    raise ContractFailure(f"negative control unexpectedly accepted: {name}")


def run_negative_controls(protocol: dict[str, Any], old_map: dict[str, Any],
                          new_map: dict[str, Any], command: dict[str, Any],
                          controller_source: str, driver_source: str,
                          cache_rows: list[dict[str, Any]],
                          projection_receipt: dict[str, Any],
                          qa_report: dict[str, Any], test_root: Path,
                          root: Path) -> list[dict[str, Any]]:
    controls: list[dict[str, Any]] = []

    reversed_phase_map = copy.deepcopy(new_map)
    reversed_phase_map["runtime_execution_plan"][
        "actual_formal_phase_case_ids"] = dict(reversed(
            list(reversed_phase_map["runtime_execution_plan"][
                "actual_formal_phase_case_ids"].items())
        ))
    validate_formal_cases(old_map, reversed_phase_map)
    controls.append({
        "name": "formal phase dict reverse retains semantic acceptance",
        "status": "pass",
        "result": "accepted_equivalent_key_order",
    })

    for name, mutate in (
        ("formal case omission", lambda d: d["runtime_execution_plan"][
            "actual_formal_phase_case_ids"]["actual_formal_baseline"].pop()),
        ("formal case addition", lambda d: d["runtime_execution_plan"][
            "actual_formal_phase_case_ids"]["actual_formal_baseline"].append(
                "UNEXPECTED_CASE")),
        ("formal phase key omission", lambda d: d["runtime_execution_plan"][
            "actual_formal_phase_case_ids"].pop("actual_formal_baseline")),
        ("formal phase extra key", lambda d: d["runtime_execution_plan"][
            "actual_formal_phase_case_ids"].update(
                {"unexpected_phase": ["UNEXPECTED_CASE"]})),
    ):
        mutant = copy.deepcopy(new_map)
        mutate(mutant)
        expect_reject(name, lambda m=mutant:
                      validate_formal_cases(old_map, m), controls)

    site_ids = sorted(site_index(new_map))
    target_id = site_ids[0]
    target_pos = next(i for i, s in enumerate(new_map["successor_assertion_sites"])
                      if s["id"] == target_id)
    mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("site row missing", lambda m: m["successor_assertion_sites"].pop(target_pos)),
        ("duplicate site id", lambda m: m["successor_assertion_sites"].append(
            copy.deepcopy(m["successor_assertion_sites"][target_pos]))),
        ("stale r2 site path", lambda m: m["successor_assertion_sites"][
            target_pos].update(path=(
                "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                "actual_formal_negative_driver_r2.jl"))),
        ("site wrong line", lambda m: m["successor_assertion_sites"][
            target_pos].update(line=m["successor_assertion_sites"][target_pos]["line"] + 1)),
        ("site wrong source text", lambda m: m["successor_assertion_sites"][
            target_pos].update(source_text="wrong-source-text")),
        ("site phase relation drift", lambda m: m["successor_assertion_sites"][
            target_pos]["expected_phase_hits"].update(
                actual_formal_preflight=999)),
    ]
    for name, mutate in mutations:
        mutant = copy.deepcopy(new_map)
        mutate(mutant)
        expect_reject(name, lambda m=mutant:
                      validate_site_contract(old_map, m, protocol), controls)

    for name, mutate in (
        ("hit plan missing site", lambda m: m[
            "successor_assertion_runtime_hit_plan"]["site_expected_phase_hits"].pop(
                target_id)),
        ("hit plan extra site", lambda m: m[
            "successor_assertion_runtime_hit_plan"]["site_expected_phase_hits"].update(
                {"NEW-ACT-999": {"actual_formal_baseline": 1}})),
        ("hit total drift", lambda m: m[
            "successor_assertion_runtime_hit_plan"].update(
                expected_runtime_hit_count=621)),
        ("hit phase order drift", lambda m: m[
            "successor_assertion_runtime_hit_plan"]["phase_order"].reverse()),
    ):
        mutant = copy.deepcopy(new_map)
        mutate(mutant)
        expect_reject(name, lambda m=mutant:
                      validate_site_plan(old_map, m, protocol), controls)

    for timeout in (300, 479, 481, 600):
        mutant = copy.deepcopy(protocol)
        mutant["resource_gates"]["phase_wall_seconds"] = timeout
        expect_reject(f"phase timeout {timeout} rejected",
                      lambda p=mutant:
                      validate_budget(p, command, controller_source), controls)
    for cap in (2_147_483_647, 2_147_483_649):
        mutant = copy.deepcopy(protocol)
        mutant["resource_gates"]["process_tree_working_set_bytes"] = cap
        expect_reject(f"memory cap {cap} rejected",
                      lambda p=mutant:
                      validate_budget(p, command, controller_source), controls)

    markers_mutated = driver_source.replace(
        '_t2_neg_stage_begin("baseline_context_serialization")',
        '_t2_neg_stage_begin("wrong_context_serialization")',
    )
    expect_reject("tail marker name drift", lambda:
                  validate_markers(protocol, markers_mutated), controls)
    semantic_mutation = driver_source.replace(
        "FusionConceptAI.vnext_t2_rebind_identity_receipts_v2(live.build)",
        "FusionConceptAI.vnext_t2_rebind_identity_receipts_v3(live.build)",
        1,
    )
    require(semantic_mutation != driver_source,
            "semantic mutation fixture no longer targets an existing call")
    old_driver = (ROOT / (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "actual_formal_negative_driver_r2.jl"
    )).read_text(encoding="utf-8")
    expect_reject("driver semantic code drift", lambda:
                  require(strip_r3_instrumentation(semantic_mutation) ==
                          old_driver.replace("r3", "r2").replace("R3", "R2"),
                          "semantic diff unexpectedly normalized"), controls)

    for label, mutate in (
        ("cache SHA stale", lambda rows: rows[0].update(sha256="0" * 64)),
        ("cache byte count drift", lambda rows: rows[0].update(
            bytes=rows[0]["bytes"] + 1)),
        ("third pyc inventory", lambda rows: rows.append({
            "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                    "__pycache__/third.pyc",
            "bytes": 1,
            "sha256": "0" * 64,
        })),
        ("third imported-controller pyc", lambda rows: rows.append({
            "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                    "__pycache__/independent_negative_controller_r3.cpython-313.pyc",
            "bytes": 1,
            "sha256": "0" * 64,
        })),
    ):
        mutant_rows = copy.deepcopy(cache_rows)
        mutate(mutant_rows)
        expect_reject(label, lambda rows=mutant_rows:
                      require(rows == EXPECTED_CACHE_ROWS,
                              "cache inventory differs from frozen exact set"),
                      controls)
    cache_protocol = copy.deepcopy(protocol)
    cache_protocol["python_cache_exclusion"]["excluded_files"][0][
        "sha256"] = "0" * 64
    expect_reject("stale pyc pin receipt", lambda:
                  require(cache_protocol["python_cache_exclusion"][
                      "excluded_files"] == EXPECTED_CACHE_ROWS,
                      "cache receipt pin mismatch"), controls)
    pinned_path = protocol["driver_path"]
    original_pin = copy.deepcopy(protocol["inputs"][pinned_path])
    for label, mutate in (
        ("source pin SHA stale", lambda p: p.update(sha256="0" * 64)),
        ("source pin byte count drift", lambda p: p.update(
            bytes=p["bytes"] + 1)),
        ("source pin path drift", lambda p: p.update(path="stale-driver.jl")),
    ):
        mutant_pin = copy.deepcopy(original_pin)
        mutate(mutant_pin)
        expect_reject(label, lambda p=mutant_pin:
                      require(pin_matches_live(pinned_path, p),
                              "source pin no longer matches live bytes"), controls)
    missing_inputs = copy.deepcopy(protocol["inputs"])
    missing_inputs.pop(pinned_path)
    expect_reject("current input closure missing pin", lambda:
                  require(len(missing_inputs) == 237,
                          "input pin closure count changed"), controls)
    extra_inputs = copy.deepcopy(protocol["inputs"])
    extra_inputs["unapproved-extra.txt"] = {
        "path": "unapproved-extra.txt", "bytes": 1, "sha256": "0" * 64,
    }
    expect_reject("current input closure extra pin", lambda:
                  require(len(extra_inputs) == 237,
                          "input pin closure count changed"), controls)

    for label, mutate in (
        ("projection dependency missing", lambda p: p[
            "projection24_reuse"]["dependency_subset"].pop("Manifest.toml")),
        ("projection dependency SHA stale", lambda p: p[
            "projection24_reuse"]["dependency_subset"]["Manifest.toml"].update(
                sha256="0" * 64)),
        ("projection dependency unapproved extra", lambda p: p[
            "projection24_reuse"]["dependency_subset"].update({
                "unapproved.txt": {
                    "path": "unapproved.txt", "bytes": 1,
                    "sha256": "0" * 64,
                }
            })),
    ):
        mutant_protocol = copy.deepcopy(protocol)
        mutate(mutant_protocol)
        expect_reject(label, lambda p=mutant_protocol:
                      validate_projection(p, root, projection_receipt), controls)

    for label, mutate in (
        ("projection phase marker missing", lambda r: r.update(
            stdout=r["stdout"].replace(b"T2_PROJECTION24_REUSE=PASS",
                                        b"T2_PROJECTION24_REUSE=FAIL"))),
        ("projection completed-site count drift", lambda r: r[
            "receipt"].update(assertion_sites_completed=23)),
    ):
        mutant_receipt = copy.deepcopy(projection_receipt)
        mutate(mutant_receipt)
        expect_reject(label, lambda r=mutant_receipt:
                      validate_projection(protocol, root, r), controls)

    for label, mutate in (
        ("cache import target added", lambda p: p[
            "python_cache_exclusion"].update(
                cache_module_import_targets=[EXPECTED_CACHE_ROWS[0]["path"]])),
        ("excluded QA module loader added", lambda p: p[
            "python_cache_exclusion"].update(
                qa_dynamic_import_module_names=[
                    "vnext_t2_controller_r3",
                    "vnext_t2_projection24_reuse_r3",
                    "static_qa_independent_negative_r3",
                ])),
    ):
        mutant_protocol = copy.deepcopy(protocol)
        mutate(mutant_protocol)
        expect_reject(label, lambda p=mutant_protocol:
                      validate_cache(p, command, qa_report, cache_rows,
                                     test_root, root), controls)
    return controls


def current_cache_rows(root: Path, test_root: Path) -> list[dict[str, Any]]:
    rows = []
    for path in sorted(test_root.rglob("*.pyc")):
        relative = path.relative_to(root).as_posix()
        rows.append(receipt(path, relative))
    return rows


def write_evidence(receipt_data: dict[str, Any], stdout: bytes,
                  stderr: bytes) -> None:
    RESULT_DIR.mkdir(parents=True, exist_ok=False)
    source_path = Path(__file__).resolve()
    command_data = {
        "schema": "vnext-t2-independent-attempt8-static-command-r1",
        "kind": "non_executable_command_data",
        "argv": [sys.executable, "-B", str(source_path)],
        "working_directory": str(ROOT),
        "julia_started": False,
        "actual_model_attestation": "unavailable",
    }
    (RESULT_DIR / "command_argv.json").write_text(
        json.dumps(command_data, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (RESULT_DIR / "independent_static_result.json").write_text(
        json.dumps(receipt_data, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (RESULT_DIR / "stdout.raw").write_bytes(stdout)
    (RESULT_DIR / "stderr.raw").write_bytes(stderr)


def main() -> int:
    status: dict[str, Any] = {
        "schema": "vnext-t2-independent-attempt8-final2-static-r1",
        "status": "fail",
        "julia_started": False,
        "actual_source_site_hits": "pending_julia_execution",
        "formal_t2_accepted": False,
        "checks": [],
        "negative_controls": [],
    }
    stdout = b""
    stderr = b""
    try:
        require(not RESULT_DIR.exists(),
                f"tester evidence leaf already exists: {RESULT_DIR}")
        protocol_path = LEAF / "protocol.json"
        map_path = LEAF / "coverage_map_r3.json"
        qa_path = LEAF / "static_qa.json"
        protocol = load_json(protocol_path)
        new_map = load_json(map_path)
        qa_report = load_json(qa_path)
        command = load_json(LEAF / "command_argv.json")
        dispatch = load_json(LEAF / "dispatch.json")
        old_map = load_json(OLD_MAP_PATH)
        old_protocol = load_json(ATTEMPT7 / "protocol.json")
        controller_path = ROOT / protocol["controller_path"]
        driver_path = ROOT / protocol["driver_path"]
        controller_source = controller_path.read_text(encoding="utf-8")
        driver_source = driver_path.read_text(encoding="utf-8")
        source_hashes = {}

        for filename, expected_sha in EXPECTED_FREEZE_HASHES.items():
            actual = receipt(LEAF / filename, filename)
            require(actual["sha256"] == expected_sha,
                    f"frozen handoff hash mismatch: {filename}")
            source_hashes[filename] = actual
        for relative, expected_sha in EXPECTED_SOURCE_HASHES.items():
            live = relative_receipt(relative)
            require(live["sha256"] == expected_sha,
                    f"frozen implementation source hash mismatch: {relative}")
            require(protocol["inputs"].get(relative) == live,
                    f"protocol does not pin exact source: {relative}")
            source_hashes[relative] = live
        status["checks"].append({
            "name": "frozen protocol/map/QA/source hashes",
            "status": "pass",
            "frozen_files": source_hashes,
        })

        require(protocol.get("schema") ==
                "vnext-t2-independent-negative-protocol-r3" and
                protocol.get("input_count") == 237 and
                len(protocol.get("inputs", {})) == 237,
                "protocol schema or 237-pin closure count mismatch")
        current_pins_before = {}
        for relative, pin in sorted(protocol["inputs"].items()):
            actual = relative_receipt(relative)
            require(pin.get("path") == relative and
                    actual == {
                        "path": relative,
                        "bytes": pin.get("bytes"),
                        "sha256": pin.get("sha256"),
                    },
                    f"live input pin mismatch: {relative}")
            current_pins_before[relative] = actual
        require(protocol.get("positive_reuse_input_pins") is not None and
                len(protocol["positive_reuse_input_pins"]) == 104,
                "positive current closure is not exactly 104 pins")
        for relative, pin in protocol["positive_reuse_input_pins"].items():
            require(pin_matches_live(relative, pin) and
                    protocol["inputs"].get(relative) == pin,
                    f"positive current pin mismatch: {relative}")
        require(protocol.get("formal_t2_accepted") is False and
                protocol.get("actual_source_site_hits") ==
                "pending_julia_execution",
                "static freeze claims formal acceptance or actual hits")
        status["checks"].append({
            "name": "237 live protocol inputs and 104 positive pins",
            "status": "pass",
            "input_count": len(current_pins_before),
            "positive_pin_count": len(protocol["positive_reuse_input_pins"]),
        })

        require(qa_report.get("status") == "pass" and
                qa_report.get("negative_control_count") == 42 and
                all(row.get("status") == "pass"
                    for row in qa_report.get("negative_controls", [])) and
                qa_report.get("julia_executed") is False and
                qa_report.get("julia_parse_executed") is False and
                qa_report.get("formal_t2_accepted") is False and
                dispatch.get("julia_started") is False and
                dispatch.get("julia_lane_granted") is False,
                "frozen QA/dispatch status is not static-only pass")
        require(dispatch.get("status") == "frozen_static_ready_not_executed" and
                dispatch.get("phase_count") == 30 and
                dispatch.get("phase_order") == protocol.get("phase_order") and
                dispatch.get("resource_gates") == protocol.get("resource_gates") and
                dispatch.get("command") == receipt(
                    LEAF / "command_argv.json",
                    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
                    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2/"
                    "command_argv.json") and
                command.get("argv") == dispatch.get("command_argv") and
                command.get("environment") == dispatch.get("environment"),
                "frozen command/dispatch data does not join")
        status["checks"].append({
            "name": "static QA and unexecuted dispatch",
            "status": "pass",
            "qa_negative_controls": 42,
            "phase_count": 30,
        })

        case_metrics = validate_formal_cases(old_map, new_map)
        site_metrics = validate_site_plan(old_map, new_map, protocol)
        status["checks"].append({
            "name": "attempt7→8 formal cases and source-site map",
            "status": "pass",
            **case_metrics,
            **site_metrics,
        })

        hit_plan = new_map["successor_assertion_runtime_hit_plan"]
        formal_hit_phases = [
            phase for phase in EXPECTED_HIT_PHASES
            if phase in EXPECTED_FORMAL_PHASES
        ]
        require(formal_hit_phases == EXPECTED_FORMAL_PHASES and
                protocol.get("expected_phase_count") == 30 and
                len(protocol.get("phase_order", [])) == 30 and
                old_protocol.get("phase_order") == protocol.get("phase_order"),
                "attempt7→8 30-phase order or 4 formal shards changed")
        require(protocol["coverage_assertion_hit_plan"]["expected_runtime_hit_count"]
                == 622 and hit_plan["expected_runtime_hit_count"] == 622,
                "static formal/site hit plan lost 622 hits")
        status["checks"].append({
            "name": "four formal shards and 30-phase order",
            "status": "pass",
            "formal_shard_phases": EXPECTED_FORMAL_PHASES[1:],
            "formal_case_count": 45,
            "site_count": 214,
            "planned_hits": 622,
        })

        validate_budget(protocol, command, controller_source)
        validate_markers(protocol, driver_source)
        old_driver_path = TEST_ROOT / "actual_formal_negative_driver_r2.jl"
        old_driver_source = old_driver_path.read_text(encoding="utf-8")
        require(len(driver_source.splitlines()) ==
                len(old_driver_source.splitlines()),
                "r3 driver line count changed from attempt7")
        normalized_driver = strip_r3_instrumentation(driver_source)
        require(normalized_driver == old_driver_source,
                "r3 driver contains non-marker semantic/source changes")
        status["checks"].append({
            "name": "480s/2GiB contract and no-op tail telemetry",
            "status": "pass",
            "phase_wall_seconds": 480,
            "working_set_limit_bytes": 2_147_483_648,
            "tail_markers": EXPECTED_TAIL_MARKERS,
            "normalized_driver_equals_attempt7": True,
            "driver_line_count": len(driver_source.splitlines()),
        })

        attempt7_basis = protocol["attempt7_interruption_basis"]
        require(attempt7_basis.get("baseline_phase") == {
            "elapsed_seconds": 300.33179130000644,
            "exit_code": 15,
            "name": "actual_formal_baseline",
            "peak_process_tree_working_set_bytes": 1_654_726_656,
            "stop_reason": "phase_wall_timeout",
            "timeout_seconds": 300.0,
            "working_set_limit_bytes": 2_147_483_648,
        }, "attempt7 interruption metadata changed")
        for name, pin in attempt7_basis["evidence"].items():
            require(pin_matches_live(pin["path"], pin),
                    f"attempt7 immutable evidence pin drifted: {name}")
        for relative in attempt7_basis["baseline_completion_artifacts_absent"]:
            require(not (ROOT / relative).exists(),
                    f"attempt7 interruption artifact now exists: {relative}")
        attempt7_pipeline = load_json(ATTEMPT7 /
            "actual_negative_execution_r2/pipeline_final.json")
        attempt7_phase = load_json(ATTEMPT7 /
            "actual_negative_execution_r2/actual_formal_baseline/phase.json")
        require(attempt7_phase.get("stop_reason") == "phase_wall_timeout" and
                attempt7_phase.get("exit_code") == 15 and
                attempt7_pipeline.get("formal_t2_accepted") is False and
                attempt7_pipeline.get("assertion_site_runtime_hits_observed") is None,
                "attempt7 failed-interruption evidence was not preserved")
        status["checks"].append({
            "name": "attempt7 failure lineage and interruption pins",
            "status": "pass",
            "phase_exit": 15,
            "stop_reason": "phase_wall_timeout",
            "elapsed_seconds": 300.33179130000644,
            "completion_artifacts_absent": 3,
        })

        projection_phase_path = LEAF / "projection24_reuse_preflight/phase.json"
        projection_receipt_path = LEAF / (
            "projection24_reuse_preflight/reuse_receipt.json"
        )
        projection_phase = load_json(projection_phase_path)
        projection_stdout = (LEAF /
            "projection24_reuse_preflight/stdout.raw").read_bytes()
        projection_data = {
            "phase": projection_phase,
            "receipt": load_json(projection_receipt_path),
            "receipt_file_pin": receipt(
                projection_receipt_path,
                (LEAF / "projection24_reuse_preflight/reuse_receipt.json")
                .relative_to(ROOT).as_posix(),
            ),
            "stdout": projection_stdout,
            "stdout_file_pin": receipt(
                LEAF / "projection24_reuse_preflight/stdout.raw",
                (LEAF / "projection24_reuse_preflight/stdout.raw")
                .relative_to(ROOT).as_posix(),
            ),
            "stderr": (LEAF / "projection24_reuse_preflight/stderr.raw")
            .read_bytes(),
            "stderr_file_pin": receipt(
                LEAF / "projection24_reuse_preflight/stderr.raw",
                (LEAF / "projection24_reuse_preflight/stderr.raw")
                .relative_to(ROOT).as_posix(),
            ),
        }
        projection_metrics = validate_projection(
            protocol, ROOT, projection_data
        )
        status["checks"].append({
            "name": "projection24 reuse plan and preflight",
            "status": "pass",
            **projection_metrics,
        })

        cache_rows_before = current_cache_rows(ROOT, TEST_ROOT)
        cache_metrics = validate_cache(
            protocol, command, qa_report, cache_rows_before, TEST_ROOT, ROOT
        )
        status["checks"].append({
            "name": "exact pyc exclusions and non-consumption",
            "status": "pass",
            **cache_metrics,
            "live_rows": cache_rows_before,
        })

        negative_controls = run_negative_controls(
            protocol, old_map, new_map, command, controller_source,
            driver_source, cache_rows_before, projection_data, qa_report,
            TEST_ROOT, ROOT,
        )
        status["negative_controls"] = negative_controls
        require(len(negative_controls) >= 20 and
                all(row["status"] == "pass" for row in negative_controls),
                "independent fail-closed mutation suite incomplete")
        status["checks"].append({
            "name": "independent fail-closed mutants",
            "status": "pass",
            "rejected_mutant_count": len(negative_controls),
        })

        current_pins_after = {}
        for relative, pin in sorted(protocol["inputs"].items()):
            actual = relative_receipt(relative)
            require(actual == pin,
                    f"input pin changed during independent checks: {relative}")
            current_pins_after[relative] = actual
        cache_rows_after = current_cache_rows(ROOT, TEST_ROOT)
        require(cache_rows_after == cache_rows_before == EXPECTED_CACHE_ROWS,
                "pyc inventory changed during independent check")
        status["checks"].append({
            "name": "end-of-check source and cache stability",
            "status": "pass",
            "input_count_unchanged": len(current_pins_after) == 237,
            "cache_inventory_unchanged": True,
        })
        status["status"] = "pass"
        status["static_plan_only"] = True
        status["actual_source_site_hits"] = "pending_julia_execution"
        status["tested_artifacts"] = {
            "protocol": receipt(LEAF / "protocol.json", "protocol.json"),
            "coverage_map": receipt(LEAF / "coverage_map_r3.json",
                                    "coverage_map_r3.json"),
            "static_qa": receipt(LEAF / "static_qa.json", "static_qa.json"),
            "test_source": receipt(Path(__file__).resolve(),
                                   Path(__file__).resolve().relative_to(ROOT).as_posix()),
        }
        stdout = (
            "T2_ATTEMPT8_FINAL2_INDEPENDENT=PASS "
            "formal_cases=45 sites=214 planned_hits=622 "
            "path_moves=175 line_delta=0 pyc_exclusions=2 "
            f"controls={len(negative_controls)}\n"
        ).encode("ascii")
    except Exception as error:
        status["status"] = "fail"
        status["failure"] = {
            "type": type(error).__name__,
            "message": str(error),
        }
        stderr = traceback.format_exc().encode("utf-8")
        stdout = (
            "T2_ATTEMPT8_FINAL2_INDEPENDENT=FAIL\n"
        ).encode("ascii")

    write_evidence(status, stdout, stderr)
    sys.stdout.buffer.write(stdout)
    sys.stderr.buffer.write(stderr)
    return 0 if status["status"] == "pass" else 1


def pin_matches_receipt(relative: str, pin: dict[str, Any]) -> dict[str, Any]:
    return {
        "path": relative,
        "bytes": pin.get("bytes"),
        "sha256": pin.get("sha256"),
    }


if __name__ == "__main__":
    raise SystemExit(main())
