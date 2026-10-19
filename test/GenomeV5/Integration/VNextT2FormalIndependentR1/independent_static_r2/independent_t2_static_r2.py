#!/usr/bin/env python3
"""Independent, Julia-free static negative checks for the VNext T2 r2 plan."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import sys
import types
from pathlib import Path
from typing import Any, Callable


REPO = Path(__file__).resolve().parents[5]
TEST_ROOT = REPO / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
IMPLEMENTATION = REPO / "docs/implementation/UP1-04A-VNEXT-T2"
R3_DISPATCH = IMPLEMENTATION / "formal_t2_dispatch_r3"
R3_REPLAY = IMPLEMENTATION / "formal_t2_serial_replay_r3"
DEFAULT_PROTOCOL_CANDIDATES = (
    IMPLEMENTATION / "independent_negative_dispatch_r2/protocol.json",
    IMPLEMENTATION / "independent_negative_dispatch_r1/protocol.json",
)
DEFAULT_COVERAGE = (
    IMPLEMENTATION / "archive/r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json"
)
DEFAULT_CONTROLLER = TEST_ROOT / "independent_negative_controller_r2.py"
EXPECTED_PHASES = (
    "actual_formal_baseline",
    "actual_formal_preflight",
    "actual_formal_authority",
    "actual_formal_fault_n10",
    "actual_formal_t1_handoff",
)
EXPECTED_SHARDS = EXPECTED_PHASES[1:]
EXPECTED_SITE_PHASES = EXPECTED_PHASES + (
    "supplementary_edited_operation",
    "supplementary_child_coupling",
)
EXPECTED_ACTIVE_GUIDANCE_PATHS = {
    "docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md",
    "docs/v4_multitopology_generation/10_genome_upgrade_execution.md",
    "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/v4_multitopology_generation/21_next_execution_batches.md",
    "docs/v4_multitopology_generation/22_agent_local_execution.md",
    "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md",
    "docs/v4_multitopology_generation/README.md",
    "docs/v4_multitopology_generation/task_manifest.json",
}
EXPECTED_INDEPENDENT_REVIEW_DIRS = {
    "docs/implementation/UP1-04A-VNEXT-T2/actual_negative_r1_resource_review",
    "docs/implementation/UP1-04A-VNEXT-T2/astra_full_acceptance_harness_review_r1_20260922",
    "docs/implementation/UP1-04A-VNEXT-T2/astra_positive_postrun_r3_review_20260922",
}
EXPECTED_EXCLUDED_HISTORICAL_LAUNCHER = {
    "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/frozen_launcher_attempt3.ps1",
    "bytes": 1178,
    "sha256": "1ed49386390d7dd1343429177ad59777d8e5f30f0a7d8988a7fc8dc897f05283",
}
EXPECTED_SHARD_MODES = (
    ("actual_formal_preflight", "preflight"),
    ("actual_formal_authority", "authority"),
    ("actual_formal_fault_n10", "fault_n10"),
    ("actual_formal_t1_handoff", "t1_handoff"),
)
SHARD_INVARIANTS = {
    "producer_package_unchanged": True,
    "candidate_receipt_unchanged": True,
    "context_unchanged": True,
    "source_revalidation_status": "source_ready",
    "rebuilt_input_full_content_join": True,
    "package_wire_unchanged": True,
    "prior_ledger_unchanged": True,
}


class CheckFailure(RuntimeError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return receipt_for_bytes(path, data)


def receipt_for_bytes(path: Path, data: bytes) -> dict[str, Any]:
    return {"path": path.resolve().relative_to(REPO).as_posix(),
            "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def canonical_pin_map(value: Any, label: str) -> dict[str, dict[str, Any]]:
    require(isinstance(value, dict), f"{label} is not a path-keyed object")
    normalized: dict[str, dict[str, Any]] = {}
    for key, raw in value.items():
        require(isinstance(key, str) and isinstance(raw, dict),
                f"{label} contains a malformed pin")
        path = raw.get("path")
        size = raw.get("bytes")
        digest = raw.get("sha256")
        require(path == key and isinstance(size, int) and size >= 0 and
                isinstance(digest, str) and len(digest) == 64 and
                all(ch in "0123456789abcdef" for ch in digest.lower()),
                f"{label} has an invalid path/bytes/SHA record: {key}")
        normalized[key] = {"path": path, "bytes": size,
                           "sha256": digest.lower()}
    return normalized


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"expected JSON object: {path}")
    return value


def load_controller(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("vnext_t2_controller_r2", path)
    require(spec is not None and spec.loader is not None,
            "cannot load r2 controller module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def load_controller_snapshot(path: Path, source_bytes: bytes) -> Any:
    module = types.ModuleType("vnext_t2_controller_r2_snapshot")
    module.__file__ = str(path.resolve())
    exec(compile(source_bytes.decode("utf-8"), str(path), "exec"),
         module.__dict__)
    return module


def assert_current_file_pins(pins: dict[str, dict[str, Any]],
                             label: str) -> int:
    checked = 0
    for relative, expected in pins.items():
        path = (REPO / relative).resolve()
        try:
            path.relative_to(REPO)
        except ValueError as exc:
            raise CheckFailure(f"{label} pin escapes repository: {relative}") from exc
        require(path.is_file(), f"{label} pinned file is missing: {relative}")
        actual = receipt(path)
        require(actual["bytes"] == expected["bytes"] and
                actual["sha256"] == expected["sha256"],
                f"{label} source drift: {relative}")
        checked += 1
    return checked


def validate_positive_pin_join(protocol: dict[str, Any],
                               runtime_inputs: dict[str, Any],
                               positive_replay: dict[str, Any],
                               runtime_inputs_path: Path,
                               replay_path: Path,
                               *, check_current_files: bool) -> dict[str, Any]:
    source_pins = canonical_pin_map(runtime_inputs.get("inputs"),
                                    "positive r3 runtime inputs")
    require(runtime_inputs.get("schema") == "vnext-t2-formal-runtime-inputs-r3",
            "positive runtime-input schema is not r3")
    require(runtime_inputs.get("runtime_dependency_count") == 104 and
            len(source_pins) == 104,
            "positive r3 dependency count is not exactly 104")

    negative_pins = canonical_pin_map(protocol.get("inputs"),
                                      "negative protocol input pins")
    for relative, expected in source_pins.items():
        require(negative_pins.get(relative) == expected,
                f"negative protocol does not bind r3 pin exactly: {relative}")

    positive_dispatch = protocol.get("positive_dispatch")
    require(isinstance(positive_dispatch, dict),
            "negative protocol positive_dispatch receipt absent")
    runtime_receipt = positive_dispatch.get("runtime_inputs")
    actual_runtime_receipt = receipt(runtime_inputs_path)
    require(runtime_receipt == actual_runtime_receipt,
            "negative protocol runtime_inputs receipt differs from r3 file")

    positive_evidence = protocol.get("positive_evidence")
    require(isinstance(positive_evidence, dict),
            "negative protocol positive_evidence absent")
    replay_record = positive_evidence.get("formal_serial_replay")
    pipeline_record = positive_evidence.get("pipeline_final")
    require(isinstance(replay_record, dict) and
            replay_record.get("path") == receipt(replay_path)["path"] and
            replay_record.get("bytes") == receipt(replay_path)["bytes"] and
            replay_record.get("sha256") == receipt(replay_path)["sha256"],
            "negative protocol formal replay receipt differs from r3")
    pipeline_path = R3_REPLAY / "pipeline_final.json"
    pipeline_actual = receipt(pipeline_path)
    require(isinstance(pipeline_record, dict) and
            pipeline_record == pipeline_actual,
            "negative protocol pipeline receipt differs from r3")

    for field in ("inputs_before", "inputs_after"):
        replay_pins = canonical_pin_map(positive_replay.get(field),
                                        f"positive replay {field}")
        require(replay_pins == source_pins,
                f"positive replay {field} differs from r3 runtime input set")
    require(positive_replay.get("pinned_input_changes") == [] and
            positive_replay.get("status") == "pass",
            "positive replay did not preserve the pinned input set")

    checked = assert_current_file_pins(source_pins, "positive r3") \
        if check_current_files else 0
    return {
        "positive_input_count": len(source_pins),
        "protocol_input_count": len(negative_pins),
        "joined_input_count": len(source_pins),
        "runtime_inputs_receipt": actual_runtime_receipt,
        "formal_replay_receipt": receipt(replay_path),
        "positive_files_rehashed": checked,
        "pin_map_order_semantics": "path-keyed object; key order is ignored",
    }


def validate_r2_protocol_objects(protocol: dict[str, Any],
                                 coverage: dict[str, Any],
                                 dispatch: dict[str, Any],
                                 protocol_receipt: dict[str, Any],
                                 coverage_receipt: dict[str, Any],
                                 runtime_inputs: dict[str, Any]
                                 ) -> dict[str, Any]:
    """Independently validate the frozen R2 protocol/coverage/dispatch objects."""
    require(protocol.get("schema") ==
            "vnext-t2-independent-negative-protocol-r2" and
            protocol.get("status") == "frozen_static_ready_not_executed",
            "R2 negative protocol schema/status mismatch")
    require(dispatch.get("schema") ==
            "vnext-t2-independent-negative-dispatch-r2" and
            dispatch.get("status") == "frozen_static_ready_not_executed" and
            dispatch.get("julia_started") is False and
            dispatch.get("actual_source_site_hits") ==
            "pending_julia_execution",
            "R2 dispatch claims execution or has wrong schema/status")
    require(dispatch.get("protocol") == protocol_receipt,
            "dispatch protocol path/bytes/SHA receipt mismatch")
    require(protocol.get("coverage_map") == coverage_receipt,
            "protocol coverage-map path/bytes/SHA receipt mismatch")
    require(protocol.get("actual_source_site_hits") ==
            "pending_julia_execution" and
            protocol.get("actual_model_attestation") == "unavailable" and
            protocol.get("formal_t2_accepted") is False and
            protocol.get("physical_acceptance") is False and
            protocol.get("scientific_acceptance") is False,
            "R2 protocol execution/acceptance boundary is mislabeled")

    input_pins = canonical_pin_map(protocol.get("inputs"),
                                   "frozen R2 protocol inputs")
    require(protocol.get("input_count") == 207 and len(input_pins) == 207,
            "R2 protocol does not bind exactly 207 inputs")
    excluded_raw = protocol.get("excluded_historical_execution_artifacts")
    if isinstance(excluded_raw, list):
        require(len(excluded_raw) == 1 and isinstance(excluded_raw[0], dict),
                "R2 historical launcher exclusion receipt is absent or ambiguous")
        excluded_row = excluded_raw[0]
    elif isinstance(excluded_raw, dict):
        require(set(excluded_raw) == {"attempt3_scope_violation_launcher"} and
                isinstance(excluded_raw["attempt3_scope_violation_launcher"], dict),
                "R2 historical launcher exclusion receipt is absent or ambiguous")
        excluded_row = excluded_raw["attempt3_scope_violation_launcher"]
    else:
        raise CheckFailure("R2 historical launcher exclusion receipt is absent or ambiguous")
    excluded = {key: excluded_row.get(key)
                for key in ("path", "bytes", "sha256")}
    exclusion_reason = excluded_row.get(
        "reason", protocol.get("historical_execution_artifact_exclusion_reason", ""))
    require(excluded == EXPECTED_EXCLUDED_HISTORICAL_LAUNCHER and
            isinstance(exclusion_reason, str) and
            "historical" in exclusion_reason and
            "not a current execution dependency" in exclusion_reason and
            excluded["path"] not in input_pins,
            "R2 excluded historical launcher receipt/path mismatch")
    current_excluded = receipt(REPO / excluded["path"])
    require(current_excluded["bytes"] == excluded["bytes"] and
            current_excluded["sha256"] == excluded["sha256"],
            "R2 excluded historical launcher source drift")
    positive_pins = canonical_pin_map(
        protocol.get("positive_reuse_input_pins"),
        "frozen R2 positive reuse pins")
    r3_pins = canonical_pin_map(runtime_inputs.get("inputs"),
                                "positive R3 runtime inputs")
    require(len(positive_pins) == 104 and positive_pins == r3_pins and
            runtime_inputs.get("runtime_dependency_count") == 104,
            "R2 positive reuse pins differ from the exact R3 104-input set")
    require(all(input_pins.get(path) == row
                for path, row in positive_pins.items()),
            "R3 positive reuse pin is absent or differs in the R2 207-input closure")

    guidance = canonical_pin_map(protocol.get("active_guidance_pins"),
                                 "R2 active guidance pins")
    require(set(guidance) == EXPECTED_ACTIVE_GUIDANCE_PATHS and
            len(guidance) == 9 and
            all(input_pins.get(path) == row for path, row in guidance.items()),
            "R2 protocol does not bind the exact nine active guidance files")

    reviews = protocol.get("independent_review_inputs")
    require(isinstance(reviews, list) and len(reviews) == 15,
            "R2 independent review input inventory is not 15 receipts")
    review_paths = [row.get("path") for row in reviews if isinstance(row, dict)]
    review_dirs = {Path(path).parent.as_posix() for path in review_paths
                   if isinstance(path, str)}
    require(len(review_paths) == 15 and len(set(review_paths)) == 15 and
            review_dirs == EXPECTED_INDEPENDENT_REVIEW_DIRS and
            all(input_pins.get(row["path"]) == {
                "path": row["path"], "bytes": row["bytes"],
                "sha256": row["sha256"].lower()} for row in reviews),
            "R2 historical independent-review receipts differ from pinned closure")

    hit_plan = protocol.get("coverage_assertion_hit_plan")
    expected_hit_plan = coverage.get("successor_assertion_runtime_hit_plan")
    require(isinstance(hit_plan, dict) and hit_plan == expected_hit_plan and
            hit_plan.get("schema") ==
            "vnext-t2-independent-negative-assertion-hit-plan-r2" and
            hit_plan.get("status") ==
            "expected_source_site_hits_static_plan_actual_hits_pending" and
            hit_plan.get("assertion_site_count") == 214 and
            hit_plan.get("expected_runtime_hit_count") == 622,
            "R2 protocol source-site hit plan/schema differs from frozen coverage map")
    require(protocol.get("expected_phase_count") == len(protocol.get("phase_order", [])) ==
            dispatch.get("phase_count") == len(dispatch.get("phase_order", [])) == 30 and
            protocol.get("phase_order") == dispatch.get("phase_order"),
            "R2 protocol/dispatch phase sequence differs")

    return {
        "schema": protocol["schema"],
        "protocol_status": protocol["status"],
        "protocol_input_count": len(input_pins),
        "excluded_historical_artifact_count": 1,
        "excluded_historical_artifact": excluded,
        "positive_r3_input_count": len(positive_pins),
        "active_guidance_count": len(guidance),
        "independent_review_input_count": len(reviews),
        "independent_review_directory_count": len(review_dirs),
        "assertion_site_plan_sites": hit_plan["assertion_site_count"],
        "assertion_site_plan_hits": hit_plan["expected_runtime_hit_count"],
        "phase_count": len(protocol["phase_order"]),
        "actual_source_site_hits": protocol["actual_source_site_hits"],
        "julia_started": dispatch["julia_started"],
        "formal_t2_accepted": protocol["formal_t2_accepted"],
    }


def verify_r2_protocol_current_inputs(protocol: dict[str, Any],
                                      paths: set[str] | None = None) -> int:
    pins = canonical_pin_map(protocol.get("inputs"),
                             "frozen R2 protocol inputs")
    require(protocol.get("input_count") == 207 and len(pins) == 207,
            "R2 protocol input count differs from 207")
    selected = set(pins) if paths is None else paths
    require(selected.issubset(pins), "selected R2 input pin is absent")
    for relative in sorted(selected):
        path = (REPO / relative).resolve()
        path.relative_to(REPO)
        actual = receipt(path)
        require(actual["bytes"] == pins[relative]["bytes"] and
                actual["sha256"] == pins[relative]["sha256"],
                f"R2 protocol current input drift: {relative}")
    return len(selected)


def r2_protocol_object_controls(protocol: dict[str, Any],
                                coverage: dict[str, Any],
                                dispatch: dict[str, Any],
                                protocol_receipt: dict[str, Any],
                                coverage_receipt: dict[str, Any],
                                runtime_inputs: dict[str, Any],
                                checks: list[dict[str, Any]]) -> None:
    reverse_inputs = copy.deepcopy(protocol)
    reverse_inputs["inputs"] = dict(reversed(list(
        reverse_inputs["inputs"].items())))
    validate_r2_protocol_objects(reverse_inputs, coverage, dispatch,
                                 protocol_receipt, coverage_receipt,
                                 runtime_inputs)
    verify_r2_protocol_current_inputs(reverse_inputs, set())
    checks.append({"name": "R2 protocol input pin object key order is semantic-map order",
                   "status": "pass"})

    base_inputs = protocol["inputs"]
    first_pin = next(iter(base_inputs))
    for label, mutation, paths in (
            ("missing R2 input pin", lambda p: p["inputs"].pop(first_pin), set()),
            ("extra R2 input pin", lambda p: p["inputs"].update({
                "src/__independent_extra__.jl": {
                    "path": "src/__independent_extra__.jl", "bytes": 0,
                    "sha256": hashlib.sha256(b"").hexdigest()}}), set()),
            ("R2 input SHA drift", lambda p: p["inputs"][first_pin].__setitem__(
                "sha256", "0" * 64), {first_pin}),
            ("R2 input byte drift", lambda p: p["inputs"][first_pin].__setitem__(
                "bytes", p["inputs"][first_pin]["bytes"] + 1), {first_pin})):
        changed = copy.deepcopy(protocol)
        mutation(changed)
        expect_rejection(label,
                         lambda p=changed, selected=paths:
                             verify_r2_protocol_current_inputs(p, selected),
                         checks)

    for label, mutate_protocol, mutate_coverage, mutate_dispatch in (
            ("missing active guidance pin",
             lambda p: p["active_guidance_pins"].pop(next(iter(
                 p["active_guidance_pins"]))), None, None),
            ("extra active guidance pin",
             lambda p: p["active_guidance_pins"].update({
                 "docs/__independent_extra__.md": {
                     "path": "docs/__independent_extra__.md", "bytes": 0,
                     "sha256": hashlib.sha256(b"").hexdigest()}}), None, None),
            ("site-hit plan site missing",
             lambda p: p["coverage_assertion_hit_plan"][
                 "site_expected_phase_hits"].pop(next(iter(
                     p["coverage_assertion_hit_plan"][
                         "site_expected_phase_hits"]))), None, None),
            ("site-hit plan phase reordered", lambda p: p[
                "coverage_assertion_hit_plan"]["phase_order"].reverse(), None, None),
            ("coverage map SHA drift",
             lambda p: p["coverage_map"].__setitem__("sha256", "0" * 64), None, None),
            ("dispatch protocol SHA drift", None, None,
             lambda d: d["protocol"].__setitem__("sha256", "0" * 64)),
            ("R2 actual-site status overclaim",
             lambda p: p.__setitem__("actual_source_site_hits", "622_observed"),
             None, None)):
        changed_protocol = copy.deepcopy(protocol)
        changed_coverage = copy.deepcopy(coverage)
        changed_dispatch = copy.deepcopy(dispatch)
        if mutate_protocol:
            mutate_protocol(changed_protocol)
        if mutate_coverage:
            mutate_coverage(changed_coverage)
        if mutate_dispatch:
            mutate_dispatch(changed_dispatch)
        expect_rejection(label, lambda p=changed_protocol, c=changed_coverage,
                         d=changed_dispatch:
                         validate_r2_protocol_objects(
                             p, c, d, protocol_receipt, coverage_receipt,
                             runtime_inputs), checks)


def validate_r2_archive_scope(protocol_path: Path,
                              protocol: dict[str, Any],
                              dispatch: dict[str, Any]) -> dict[str, Any]:
    archive_dir = protocol_path.parent
    command_path = archive_dir / "command_argv.json"
    coverage_path = archive_dir / "coverage_map_r2.json"
    dispatch_path = archive_dir / "dispatch.json"
    qa_path = archive_dir / "static_qa.json"
    snapshot_path = archive_dir / "freeze_snapshot.json"
    stdout_path = archive_dir / "static_qa.stdout.raw"
    stderr_path = archive_dir / "static_qa.stderr.raw"
    required = (command_path, coverage_path, dispatch_path, qa_path,
                snapshot_path, stdout_path, stderr_path)
    require(all(path.is_file() for path in required),
            "R2 freeze archive is missing command/map/dispatch/QA/snapshot artifacts")

    protocol_file_receipt = receipt(protocol_path)
    command_receipt = receipt(command_path)
    coverage_file_receipt = receipt(coverage_path)
    dispatch_receipt = receipt(dispatch_path)
    qa_receipt = receipt(qa_path)
    snapshot_receipt = receipt(snapshot_path)
    stdout_receipt = receipt(stdout_path)
    stderr_receipt = receipt(stderr_path)
    require(dispatch.get("command") == command_receipt and
            dispatch.get("protocol") == protocol_file_receipt,
            "dispatch does not pin the protocol and non-executable command data")

    command = load_json(command_path)
    require(command.get("schema") ==
            "vnext-t2-independent-negative-command-argv-r2" and
            command.get("kind") == "non_executable_command_data" and
            command.get("julia_started") is False and
            command.get("formal_t2_accepted") is False and
            isinstance(command.get("argv"), list) and command["argv"] and
            all(isinstance(value, str) for value in command["argv"]),
            "archive command payload is not pinned non-executable argv data")
    require(dispatch.get("command_argv") == command.get("argv"),
            "dispatch argv differs from command_argv.json data")
    executable_suffixes = {".ps1", ".psm1", ".cmd", ".bat", ".exe",
                           ".sh", ".py", ".jl"}
    executable_paths = [path.relative_to(archive_dir).as_posix()
                        for path in archive_dir.rglob("*")
                        if path.is_file() and
                        path.suffix.lower() in executable_suffixes]
    require(not executable_paths,
            "R2 freeze archive contains executable/source files: " +
            ", ".join(executable_paths))

    qa = load_json(qa_path)
    controller_path = TEST_ROOT / "independent_negative_controller_r2.py"
    controller_receipt = receipt(controller_path)
    require(qa.get("schema") == "vnext-t2-independent-negative-static-qa-r2" and
            qa.get("status") == "pass" and qa.get("julia_executed") is False and
            qa.get("julia_parse_executed") is False and
            qa.get("actual_model_attestation") == "unavailable" and
            qa.get("protocol") == protocol_file_receipt and
            qa.get("coverage_map") == coverage_file_receipt and
            qa.get("controller") == controller_receipt and
            qa.get("input_count") == 207 and
            qa.get("positive_r3_input_pin_count") == 104 and
            qa.get("actual_source_site_hits") == "pending_julia_execution" and
            qa.get("successor_assertion_sites_static_plan") == 214 and
            qa.get("successor_runtime_hits_static_plan") == 622 and
            qa.get("formal_t2_accepted") is False,
            "R2 static QA receipt failed or overclaims execution")

    snapshot = load_json(snapshot_path)
    require(snapshot.get("schema") ==
            "vnext-t2-independent-negative-freeze-snapshot-r2" and
            snapshot.get("status") == "pass" and
            snapshot.get("julia_started") is False and
            snapshot.get("formal_t2_accepted") is False and
            snapshot.get("input_count") == 207 and
            snapshot.get("positive_r3_input_pin_count") == 104 and
            snapshot.get("protocol") == protocol_file_receipt and
            snapshot.get("coverage_map") == coverage_file_receipt and
            snapshot.get("command") == command_receipt and
            snapshot.get("dispatch") == dispatch_receipt and
            snapshot.get("static_qa") == qa_receipt and
            snapshot.get("static_qa_stdout") == stdout_receipt and
            snapshot.get("static_qa_stderr") == stderr_receipt,
            "R2 freeze snapshot does not bind the static QA artifacts")
    require(stderr_receipt["bytes"] == 0,
            "R2 static QA stderr is not empty")
    evidence_dir = protocol.get("planned_evidence_directory")
    require(protocol.get("planned_evidence_directory_absent") is True and
            isinstance(evidence_dir, str) and
            not (REPO / evidence_dir).exists(),
            "R2 negative runtime output already exists or was claimed executed")
    return {
        "archive_path": archive_dir.resolve().relative_to(REPO).as_posix(),
        "command_kind": command["kind"],
        "archive_executable_source_file_count": len(executable_paths),
        "protocol_receipt": protocol_file_receipt,
        "coverage_map_receipt": coverage_file_receipt,
        "command_argv_receipt": command_receipt,
        "dispatch_receipt": dispatch_receipt,
        "static_qa_receipt": qa_receipt,
        "freeze_snapshot_receipt": snapshot_receipt,
        "static_qa_negative_control_count": len(qa.get("negative_controls", [])),
        "julia_started": False,
        "actual_source_site_hits": "pending_julia_execution",
    }


def expect_rejection(name: str, operation: Callable[[], Any],
                     checks: list[dict[str, Any]]) -> None:
    try:
        operation()
    except Exception as exc:  # expected rejection boundary
        checks.append({"name": name, "status": "pass",
                       "observed": f"rejected:{type(exc).__name__}"})
        return
    raise CheckFailure(f"negative control unexpectedly accepted: {name}")


def validate_coverage(coverage: dict[str, Any]) -> dict[str, Any]:
    require(coverage.get("schema") ==
            "vnext-t2-independent-negative-coverage-map-r2",
            "coverage map schema is not r2")
    require(coverage.get("status") == "static_coverage_map_no_julia" and
            coverage.get("formal_t2_accepted") is False and
            coverage.get("scientific_acceptance") is False,
            "coverage map overclaims execution or acceptance")

    old_sites = coverage.get("old_assertion_sites")
    new_sites = coverage.get("successor_assertion_sites")
    cases = coverage.get("successor_cases")
    require(isinstance(old_sites, list) and len(old_sites) == 154 and
            isinstance(new_sites, list) and len(new_sites) == 214 and
            isinstance(cases, list) and len(cases) == 60,
            "old/successor lexical inventory counts differ")
    old_ids = [row.get("id") for row in old_sites]
    new_ids = [row.get("id") for row in new_sites]
    case_ids = [row.get("id") for row in cases]
    require(len(old_ids) == len(set(old_ids)) and
            len(new_ids) == len(set(new_ids)) and
            len(case_ids) == len(set(case_ids)),
            "old, successor, or semantic case IDs are duplicated")
    require(sum(row.get("runtime_multiplicity", 0) for row in old_sites) == 174,
            "old lexical-to-runtime multiplicity no longer sums to 174")
    require(sum(row.get("runtime_multiplicity", 0) for row in new_sites) == 622,
            "successor lexical-to-runtime multiplicity no longer sums to 622")
    new_id_set = set(new_ids)
    for row in old_sites:
        mapped = row.get("successor_assertion_ids")
        require(isinstance(mapped, list) and mapped and
                set(mapped).issubset(new_id_set),
                f"old obligation has missing/unknown successor sites: {row.get('id')}")

    obligation_map = coverage.get("active_work_order_obligation_map")
    require(isinstance(obligation_map, dict) and len(obligation_map) == 21,
            "active work-order obligation map does not contain 21 obligations")
    case_id_set = set(case_ids)
    for obligation, mapped_cases in obligation_map.items():
        require(isinstance(mapped_cases, list) and mapped_cases and
                set(mapped_cases).issubset(case_id_set),
                f"active obligation mapping is incomplete: {obligation}")

    plan = coverage.get("runtime_execution_plan")
    require(isinstance(plan, dict) and
            plan.get("expected_unique_case_count") == 60 and
            plan.get("expected_runtime_case_hit_count") == 68 and
            len(plan.get("expected_unique_case_ids", [])) == 60 and
            len(plan.get("expected_runtime_case_hit_counts", {})) == 60 and
            set(plan["expected_unique_case_ids"]) ==
            set(plan["expected_runtime_case_hit_counts"]),
            "runtime unique-case/hit inventory is inconsistent")
    require(sum(plan["expected_runtime_case_hit_counts"].values()) == 68,
            "runtime hit counts do not sum to 68")
    bindings = coverage.get("runtime_validation_bindings")
    require(isinstance(bindings, list) and len(bindings) == 60,
            "runtime validation bindings are incomplete")
    for binding in bindings:
        case_id = binding.get("case_id")
        require(case_id in plan["expected_runtime_case_hit_counts"] and
                binding.get("expected_runtime_hits") ==
                plan["expected_runtime_case_hit_counts"][case_id] and
                set(binding.get("julia_assertion_ids", [])).issubset(new_id_set),
                f"runtime binding mismatch: {case_id}")

    context_ids = coverage.get("context_transport_assertion_ids")
    require(isinstance(context_ids, list) and len(context_ids) == 23 and
            len(set(context_ids)) == 23 and set(context_ids).issubset(new_id_set) and
            coverage.get("context_transport_assertion_site_count") == 23 and
            coverage.get("context_transport_expected_runtime_hit_count") == 92 and
            sum(next(row["runtime_multiplicity"] for row in new_sites
                     if row["id"] == site_id) for site_id in context_ids) == 92,
            "four-shard context transport obligation count is inconsistent")
    require(coverage.get("preserved_successor_assertion_site_count") == 191 and
            coverage.get("preserved_successor_expected_runtime_hit_count") == 530 and
            191 + 23 == 214 and 530 + 92 == 622,
            "preserved plus context transport coverage does not equal r2 totals")

    site_hit_summary = validate_site_hit_plan(coverage)
    source_binding_count = validate_coverage_source_bindings(coverage)

    return {
        "old_sites": len(old_sites),
        "old_expected_hits": 174,
        "successor_sites": len(new_sites),
        "successor_expected_hits": 622,
        "successor_cases": len(cases),
        "active_obligation_categories": len(obligation_map),
        "context_transport_sites": len(context_ids),
        "context_transport_expected_hits": 92,
        "site_hit_plan": site_hit_summary,
        "source_binding_count": source_binding_count,
    }


def validate_coverage_source_bindings(coverage: dict[str, Any]) -> int:
    receipts = [coverage.get("active_work_order"),
                coverage.get("old_focused_suite")]
    ast_plan = coverage.get("ast_inventory_plan")
    require(isinstance(ast_plan, dict) and
            isinstance(ast_plan.get("sources"), list),
            "AST inventory source receipts absent")
    receipts.extend(ast_plan["sources"])
    count = 0
    for expected in receipts:
        require(isinstance(expected, dict) and
                isinstance(expected.get("path"), str),
                "coverage source receipt malformed")
        actual = receipt(REPO / expected["path"])
        require(actual["bytes"] == expected.get("bytes") and
                actual["sha256"] == expected.get("sha256"),
                f"coverage source receipt drift: {expected['path']}")
        count += 1

    controller_sites = [site for binding in coverage["runtime_validation_bindings"]
                        for site in binding.get("controller_validation_sites", [])]
    require(controller_sites,
            "coverage map does not bind its controller validation sites")
    seen: set[tuple[str, int]] = set()
    for site in controller_sites:
        relative = site.get("path")
        line_no = site.get("line")
        require(isinstance(relative, str) and isinstance(line_no, int) and
                line_no > 0, "controller validation-site receipt malformed")
        key = (relative, line_no)
        if key in seen:
            continue
        seen.add(key)
        source_path = REPO / relative
        require(source_path.is_file(),
                f"controller validation source missing: {relative}")
        lines = source_path.read_text(encoding="utf-8").splitlines()
        require(line_no <= len(lines),
                f"controller validation line moved: {relative}:{line_no}")
        actual_text = lines[line_no - 1].strip()
        require(actual_text == site.get("source_text") and
                hashlib.sha256(actual_text.encode("utf-8")).hexdigest() ==
                site.get("source_text_sha256"),
                f"controller validation source drift: {relative}:{line_no}")
    return count + len(seen)


def validate_site_hit_plan(coverage: dict[str, Any]) -> dict[str, Any]:
    """Check the planned assertion-site hit matrix; it is not runtime evidence."""
    sites = coverage["successor_assertion_sites"]
    plan = coverage.get("successor_assertion_runtime_hit_plan")
    require(isinstance(plan, dict) and
            plan.get("schema") ==
            "vnext-t2-independent-negative-assertion-hit-plan-r2" and
            plan.get("status") ==
            "expected_source_site_hits_static_plan_actual_hits_pending" and
            plan.get("site_ids_are_unique_source_path_and_line_targets") is True,
            "assertion-site hit plan schema/status/identity contract mismatch")
    site_ids = [row["id"] for row in sites]
    expected_by_site = plan.get("site_expected_phase_hits")
    require(isinstance(expected_by_site, dict) and
            set(expected_by_site) == set(site_ids) and
            plan.get("assertion_site_count") == 214 and
            len(expected_by_site) == 214 and
            plan.get("expected_runtime_hit_count") == 622,
            "assertion-site hit plan does not bind all 214 sites/622 hits")
    phase_order = plan.get("phase_order")
    phase_totals = plan.get("phase_site_hit_counts")
    require(phase_order == list(EXPECTED_SITE_PHASES) and
            len(phase_order) == len(set(phase_order)) and
            isinstance(phase_totals, dict) and
            set(phase_totals) == set(phase_order),
            "assertion-site hit phase inventory is incomplete")
    site_rows = {row["id"]: row for row in sites}
    recomputed_phase_totals: dict[str, dict[str, int]] = {
        phase: {} for phase in phase_order}
    for site_id, phase_counts in expected_by_site.items():
        require(isinstance(phase_counts, dict) and phase_counts,
                f"assertion site has no expected phase hits: {site_id}")
        require(set(phase_counts).issubset(set(phase_order)) and
                all(isinstance(count, int) and count > 0
                    for count in phase_counts.values()),
                f"assertion site has invalid phase hit counts: {site_id}")
        total = sum(phase_counts.values())
        require(total == site_rows[site_id].get("runtime_multiplicity") and
                site_rows[site_id].get("expected_phase_hits") == phase_counts,
                f"assertion-site expected hit multiplicity mismatch: {site_id}")
        for phase, count in phase_counts.items():
            recomputed_phase_totals[phase][site_id] = count
    normalized_phase_totals = {
        phase: {site_id: count for site_id, count in sorted(values.items())}
        for phase, values in phase_totals.items()}
    require(normalized_phase_totals == recomputed_phase_totals,
            "phase-to-site hit matrix differs from per-site hit assignments")
    require(sum(sum(values.values()) for values in phase_totals.values()) == 622,
            "phase-to-site expected hits do not sum to 622")
    preserved = plan.get("preserved_successor")
    context = plan.get("context_transport")
    require(isinstance(preserved, dict) and isinstance(context, dict) and
            preserved.get("assertion_site_count") == 191 and
            preserved.get("expected_runtime_hit_count") == 530 and
            context.get("assertion_site_count") == 23 and
            context.get("expected_runtime_hit_count") == 92 and
            set(preserved.get("site_ids", [])) | set(context.get("site_ids", [])) ==
            set(site_ids) and
            set(preserved.get("site_ids", [])).isdisjoint(context.get("site_ids", [])) and
            sum(sum(expected_by_site[site_id].values())
                for site_id in preserved.get("site_ids", [])) == 530 and
            sum(sum(expected_by_site[site_id].values())
                for site_id in context.get("site_ids", [])) == 92,
            "preserved/context site-hit subplans do not partition 214/622")
    old = plan.get("old_focused_suite_mapping")
    require(isinstance(old, dict) and old.get("assertion_site_count") == 154 and
            old.get("planned_runtime_hit_count") == 174 and
            old.get("status") == "mapped_to_successor_not_executed_by_r2_shards",
            "old focused suite execution boundary is mislabeled")
    return {"planned_sites": 214, "planned_hits": 622,
            "phase_count": len(phase_order),
            "preserved_sites": 191, "preserved_hits": 530,
            "context_transport_sites": 23, "context_transport_hits": 92,
            "actual_hits_executed": False}


def site_hit_plan_controls(coverage: dict[str, Any],
                           checks: list[dict[str, Any]]) -> None:
    plan = coverage["successor_assertion_runtime_hit_plan"]
    missing = copy.deepcopy(coverage)
    missing["successor_assertion_runtime_hit_plan"][
        "site_expected_phase_hits"].pop(next(iter(
            missing["successor_assertion_runtime_hit_plan"][
                "site_expected_phase_hits"])))
    expect_rejection("site-hit plan rejects missing lexical site",
                     lambda: validate_site_hit_plan(missing), checks)
    extra = copy.deepcopy(coverage)
    extra["successor_assertion_runtime_hit_plan"][
        "site_expected_phase_hits"]["UNEXPECTED-SITE"] = {
            "actual_formal_baseline": 1}
    expect_rejection("site-hit plan rejects extra lexical site",
                     lambda: validate_site_hit_plan(extra), checks)
    drift = copy.deepcopy(coverage)
    first = next(iter(drift["successor_assertion_runtime_hit_plan"][
        "site_expected_phase_hits"]))
    phase = next(iter(drift["successor_assertion_runtime_hit_plan"][
        "site_expected_phase_hits"][first]))
    drift["successor_assertion_runtime_hit_plan"][
        "site_expected_phase_hits"][first][phase] += 1
    expect_rejection("site-hit plan rejects source-site multiplicity drift",
                     lambda: validate_site_hit_plan(drift), checks)
    reordered = copy.deepcopy(coverage)
    reordered["successor_assertion_runtime_hit_plan"]["phase_order"].reverse()
    expect_rejection("site-hit plan rejects reordered phase list",
                     lambda: validate_site_hit_plan(reordered), checks)


def synthetic_site_hit_summaries(coverage: dict[str, Any],
                                 coverage_map_sha256: str
                                 ) -> list[dict[str, Any]]:
    """Build synthetic complete receipts for exercising the production validators."""
    plan = coverage["successor_assertion_runtime_hit_plan"]
    sites = coverage["successor_assertion_sites"]
    summaries = []
    for phase in plan["phase_order"]:
        phase_sites = [row for row in sites
                       if phase in row.get("expected_phase_hits", {})]
        source_paths = {row["path"] for row in phase_sites}
        require(len(source_paths) == 1,
                f"synthetic hit phase must have one source: {phase}")
        source_path = next(iter(source_paths))
        source_receipts = [row for row in
                           coverage.get("ast_inventory_plan", {}).get("sources", [])
                           if row.get("path") == source_path]
        require(len(source_receipts) == 1 and
                isinstance(source_receipts[0].get("sha256"), str),
                f"synthetic hit phase lacks one frozen source digest: {phase}")
        source_site_ids = [row["id"] for row in sites
                           if row["path"] == source_path]
        counts = {
            row["id"]: int(row.get("expected_phase_hits", {}).get(phase, 0))
            for row in sites if row["path"] == source_path
        }
        require(set(counts) == set(source_site_ids),
                f"synthetic receipt is not zero-filled: {phase}")
        summaries.append({
            "assertion_site_hit_receipt_schema":
                "vnext-t2-source-site-hit-receipt-r1",
            "assertion_site_hit_phase": phase,
            "assertion_site_hit_coverage_map_sha256": coverage_map_sha256,
            "assertion_site_hit_source_path": source_path,
            "assertion_site_hit_source_sha256": source_receipts[0]["sha256"],
            "assertion_site_hit_counts": counts,
            "assertion_site_hit_count_observed": sum(counts.values()),
            "unmapped_assertion_sources": [],
        })
    return summaries


def verify_aggregate_site_hit_output(value: dict[str, Any],
                                     coverage: dict[str, Any],
                                     coverage_map_sha256: str) -> None:
    """Independently check the production aggregate's exact serialized contract."""
    sites = coverage["successor_assertion_sites"]
    expected = {row["id"]: int(row.get("runtime_multiplicity", 0))
                for row in sites}
    plan = coverage["successor_assertion_runtime_hit_plan"]
    expected_phase_totals = {
        phase: sum(counts.values())
        for phase, counts in plan["phase_site_hit_counts"].items()
    }
    context_ids = set(coverage["context_transport_assertion_ids"])
    context_hits = sum(expected[site_id] for site_id in context_ids)
    preserved_hits = sum(count for site_id, count in expected.items()
                         if site_id not in context_ids)
    require(value.get("schema") == "vnext-t2-source-site-hit-aggregate-r1" and
            value.get("status") ==
            "actual_observed_and_exactly_matched_to_static_plan",
            "source-site aggregate schema/status mismatch")
    require(value.get("phase_order") == plan["phase_order"] and
            value.get("phase_observed_hit_counts") == expected_phase_totals and
            value.get("coverage_map_sha256") == coverage_map_sha256,
            "source-site aggregate phase order/counts/map pin mismatch")
    observed = value.get("assertion_site_runtime_hits_observed")
    require(isinstance(observed, dict) and observed == expected and
            len(observed) == 214 and
            value.get("assertion_site_count_observed") == 214 and
            value.get("assertion_site_hit_count_observed") == 622 and
            sum(observed.values()) == 622,
            "source-site aggregate does not exactly cover 214/622")
    require(value.get("context_transport_assertion_sites_completed_observed") ==
            context_hits == 92 and
            value.get("preserved_successor_runtime_hit_count_observed") ==
            preserved_hits == 530 and value.get("formal_t2_accepted") is False,
            "source-site aggregate context/preserved/acceptance boundary mismatch")


def runtime_site_hit_controls(controller: Any,
                             coverage: dict[str, Any],
                             coverage_map_sha256: str,
                             checks: list[dict[str, Any]]) -> dict[str, Any]:
    """Exercise production hit validators with synthetic data, never Julia output."""
    summaries = synthetic_site_hit_summaries(coverage, coverage_map_sha256)
    phase_order = coverage["successor_assertion_runtime_hit_plan"]["phase_order"]
    observed_by_phase: dict[str, dict[str, int]] = {}
    for phase, summary in zip(phase_order, summaries):
        observed_by_phase[phase] = controller.verify_assertion_site_hit_summary(
            summary, coverage, phase,
            coverage_map_sha256=coverage_map_sha256)
    checks.append({"name": "controller accepts complete synthetic zero-filled per-phase hit maps",
                   "status": "pass"})

    reversed_keys = copy.deepcopy(summaries[0])
    reversed_keys["assertion_site_hit_counts"] = dict(reversed(list(
        reversed_keys["assertion_site_hit_counts"].items())))
    controller.verify_assertion_site_hit_summary(
        reversed_keys, coverage, phase_order[0],
        coverage_map_sha256=coverage_map_sha256)
    checks.append({"name": "controller treats source-site hit object key order as semantic-map order",
                   "status": "pass"})

    negative_controls: list[dict[str, Any]] = []
    missing_site = copy.deepcopy(summaries[0])
    missing_site["assertion_site_hit_counts"].pop(next(iter(
        missing_site["assertion_site_hit_counts"])))
    expect_rejection("runtime hit receipt rejects missing zero-filled source site",
                     lambda: controller.verify_assertion_site_hit_summary(
                         missing_site, coverage, phase_order[0],
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)

    extra_site = copy.deepcopy(summaries[0])
    extra_site["assertion_site_hit_counts"]["INDEPENDENT-EXTRA-SITE"] = 0
    expect_rejection("runtime hit receipt rejects extra source site",
                     lambda: controller.verify_assertion_site_hit_summary(
                         extra_site, coverage, phase_order[0],
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)

    swapped = copy.deepcopy(summaries[1])
    counts = swapped["assertion_site_hit_counts"]
    distinct = next(((first, second) for first in counts for second in counts
                     if counts[first] != counts[second]), None)
    require(distinct is not None,
            "no unequal synthetic hit counts available for swapped-site control")
    first, second = distinct
    counts[first], counts[second] = counts[second], counts[first]
    expect_rejection("runtime hit receipt rejects hit counts attributed to the wrong sites",
                     lambda: controller.verify_assertion_site_hit_summary(
                         swapped, coverage, phase_order[1],
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)

    wrong_total = copy.deepcopy(summaries[0])
    wrong_total["assertion_site_hit_count_observed"] += 1
    expect_rejection("runtime hit receipt rejects phase total drift",
                     lambda: controller.verify_assertion_site_hit_summary(
                         wrong_total, coverage, phase_order[0],
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)

    for field, wrong_value, label in (
            ("assertion_site_hit_phase", phase_order[1], "wrong phase"),
            ("assertion_site_hit_coverage_map_sha256", "0" * 64, "coverage map SHA drift"),
            ("assertion_site_hit_source_sha256", "0" * 64, "source SHA drift"),
            ("assertion_site_hit_source_path", "src/__wrong_source__.jl", "wrong source path"),
            ("unmapped_assertion_sources", ["unmapped/source.jl"], "unmapped assertion source")):
        malformed = copy.deepcopy(summaries[0])
        malformed[field] = wrong_value
        expect_rejection(f"runtime hit receipt rejects {label}",
                         lambda m=malformed: controller.verify_assertion_site_hit_summary(
                             m, coverage, phase_order[0],
                             coverage_map_sha256=coverage_map_sha256),
                         negative_controls)

    aggregate = controller.aggregate_assertion_site_hit_receipts(
        summaries, coverage, coverage_map_sha256=coverage_map_sha256)
    verify_aggregate_site_hit_output(aggregate, coverage, coverage_map_sha256)
    checks.append({"name": "controller aggregate matches synthetic 214-site/622-hit receipt contract",
                   "status": "pass"})
    reversed_aggregate_keys = copy.deepcopy(aggregate)
    reversed_aggregate_keys["assertion_site_runtime_hits_observed"] = dict(
        reversed(list(reversed_aggregate_keys[
            "assertion_site_runtime_hits_observed"].items())))
    verify_aggregate_site_hit_output(reversed_aggregate_keys, coverage,
                                     coverage_map_sha256)
    checks.append({"name": "independent aggregate validator treats hit object key order as semantic-map order",
                   "status": "pass"})

    expect_rejection("aggregate rejects missing phase receipt",
                     lambda: controller.aggregate_assertion_site_hit_receipts(
                         summaries[:-1], coverage,
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)
    expect_rejection("aggregate rejects duplicate/extra phase receipt",
                     lambda: controller.aggregate_assertion_site_hit_receipts(
                         summaries + [copy.deepcopy(summaries[-1])], coverage,
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)
    expect_rejection("aggregate rejects reordered phase receipts",
                     lambda: controller.aggregate_assertion_site_hit_receipts(
                         list(reversed(summaries)), coverage,
                         coverage_map_sha256=coverage_map_sha256),
                     negative_controls)

    for label, mutation in (
            ("missing aggregate source site",
             lambda value: value["assertion_site_runtime_hits_observed"].pop(
                 next(iter(value["assertion_site_runtime_hits_observed"]))),
             ),
            ("extra aggregate source site",
             lambda value: value["assertion_site_runtime_hits_observed"].update(
                 {"INDEPENDENT-EXTRA-SITE": 0}),
             ),
            ("aggregate site multiplicity drift",
             lambda value: value["assertion_site_runtime_hits_observed"].__setitem__(
                 next(iter(value["assertion_site_runtime_hits_observed"])),
                 next(iter(value["assertion_site_runtime_hits_observed"].values())) + 1),
             ),
            ("aggregate phase order drift",
             lambda value: value["phase_order"].reverse(),
             ),
            ("aggregate phase total drift",
             lambda value: value["phase_observed_hit_counts"].__setitem__(
                 next(iter(value["phase_observed_hit_counts"])), 0),
             ),
            ("aggregate total drift",
             lambda value: value.__setitem__("assertion_site_hit_count_observed", 621),
             )):
        malformed = copy.deepcopy(aggregate)
        mutation(malformed)
        expect_rejection(f"independent aggregate validator rejects {label}",
                         lambda m=malformed: verify_aggregate_site_hit_output(
                             m, coverage, coverage_map_sha256),
                         negative_controls)

    checks.extend(negative_controls)
    return {
        "evidence_kind": "synthetic_validator_contract_only",
        "julia_executed": False,
        "phase_receipt_count": len(summaries),
        "source_ids_zero_filled_per_phase": sorted({
            len(summary["assertion_site_hit_counts"]) for summary in summaries}),
        "aggregate_sites": aggregate["assertion_site_count_observed"],
        "aggregate_hits": aggregate["assertion_site_hit_count_observed"],
        "aggregate_status_string_is_not_execution_evidence": aggregate["status"],
        "negative_control_count": len(negative_controls),
        "actual_hits_pending": True,
    }


def controller_plan_controls(controller: Any,
                             coverage: dict[str, Any]) -> list[dict[str, Any]]:
    plan = copy.deepcopy(coverage["runtime_execution_plan"])
    checks: list[dict[str, Any]] = []
    controller.verify_runtime_plan({"runtime_execution_plan": copy.deepcopy(plan)})
    checks.append({"name": "controller accepts canonical phase plan",
                   "status": "pass"})

    reversed_plan = copy.deepcopy(plan)
    reversed_plan["actual_formal_phase_case_ids"] = dict(
        reversed(list(reversed_plan["actual_formal_phase_case_ids"].items())))
    reversed_plan["actual_formal_phase_observation_ids"] = dict(
        reversed(list(reversed_plan["actual_formal_phase_observation_ids"].items())))
    controller.verify_runtime_plan({"runtime_execution_plan": reversed_plan})
    checks.append({"name": "controller accepts reversed semantic phase-map keys",
                   "status": "pass"})

    for field in ("actual_formal_phase_case_ids",
                  "actual_formal_phase_observation_ids"):
        missing = copy.deepcopy(plan)
        missing[field].pop(EXPECTED_PHASES[0])
        expect_rejection(f"controller rejects missing {field} key",
                         lambda p=missing: controller.verify_runtime_plan(
                             {"runtime_execution_plan": p}),
                         checks)
        extra = copy.deepcopy(plan)
        extra[field]["unexpected_phase"] = []
        expect_rejection(f"controller rejects extra {field} key",
                         lambda p=extra: controller.verify_runtime_plan(
                             {"runtime_execution_plan": p}),
                         checks)

    reordered_values = copy.deepcopy(plan)
    reordered_values["actual_formal_phase_case_ids"][
        "actual_formal_preflight"] = list(reversed(
            reordered_values["actual_formal_phase_case_ids"][
                "actual_formal_preflight"]))
    expect_rejection("controller rejects reordered case IDs within a shard",
                     lambda: controller.verify_runtime_plan(
                         {"runtime_execution_plan": reordered_values}),
                     checks)
    return checks


def positive_reuse_pin_controls(controller: Any,
                                protocol: dict[str, Any],
                                checks: list[dict[str, Any]],
                                runtime_inputs_path: Path,
                                replay_path: Path) -> dict[str, Any]:
    """Check production's exact positive-r3 pin closure and its mutation guards."""
    protocol_kind = "frozen_negative_protocol"
    if not isinstance(protocol.get("positive_reuse_input_pins"), dict):
        runtime_inputs = load_json(runtime_inputs_path)
        pins = runtime_inputs.get("inputs")
        protocol = {
            "positive_dispatch": {
                "root": str(R3_DISPATCH),
                "runtime_inputs": controller.file_receipt(runtime_inputs_path),
            },
            "positive_reuse_input_pins": copy.deepcopy(pins),
            "inputs": copy.deepcopy(pins),
            "positive_evidence": {
                "formal_serial_replay": {
                    "path": replay_path.resolve().relative_to(REPO).as_posix(),
                },
            },
        }
        protocol_kind = "synthetic_wrapper_around_frozen_r3_evidence"
    observed = controller.verify_positive_reuse_input_pins(protocol)
    require(observed.get("positive_runtime_input_count") == 104 and
            observed.get("schema") == "vnext-t2-positive-r3-input-pin-join-r1",
            "controller positive reuse pin join did not verify exactly 104 r3 inputs")
    checks.append({"name": "controller joins all 104 positive r3 pins by path/bytes/SHA",
                   "status": "pass"})

    reversed_protocol = copy.deepcopy(protocol)
    reversed_protocol["positive_reuse_input_pins"] = dict(reversed(list(
        reversed_protocol["positive_reuse_input_pins"].items())))
    controller.verify_positive_reuse_input_pins(reversed_protocol)
    checks.append({"name": "controller accepts reversed semantic positive pin map keys",
                   "status": "pass"})

    negative_controls: list[dict[str, Any]] = []
    pins = protocol["positive_reuse_input_pins"]
    first_pin = next(iter(pins))
    for label, mutation in (
            ("SHA drift", lambda changed: changed["positive_reuse_input_pins"][
                first_pin].__setitem__("sha256", "0" * 64)),
            ("byte drift", lambda changed: changed["positive_reuse_input_pins"][
                first_pin].__setitem__("bytes",
                    changed["positive_reuse_input_pins"][first_pin]["bytes"] + 1)),
            ("missing positive pin", lambda changed: changed[
                "positive_reuse_input_pins"].pop(first_pin)),
            ("extra positive pin", lambda changed: changed[
                "positive_reuse_input_pins"].update({
                    "src/__independent_extra__.jl": {
                        "path": "src/__independent_extra__.jl", "bytes": 0,
                        "sha256": hashlib.sha256(b"").hexdigest()}})),
            ("missing protocol closure pin", lambda changed: changed[
                "inputs"].pop(first_pin)),
            ("protocol closure SHA drift", lambda changed: changed[
                "inputs"][first_pin].__setitem__("sha256", "0" * 64)),
            ("protocol closure byte drift", lambda changed: changed[
                "inputs"][first_pin].__setitem__("bytes",
                    changed["inputs"][first_pin]["bytes"] + 1))):
        changed = copy.deepcopy(protocol)
        mutation(changed)
        expect_rejection(f"positive reuse pin join rejects {label}",
                         lambda p=changed:
                             controller.verify_positive_reuse_input_pins(p),
                         negative_controls)
    checks.extend(negative_controls)
    return {
        "status": "pass",
        "protocol_kind": protocol_kind,
        "positive_runtime_input_count": observed["positive_runtime_input_count"],
        "pin_identity_sha256": observed["pin_identity_sha256"],
        "verified_current_pin_count": len(observed["verified_current_pins"]),
        "verified_current_pins": observed["verified_current_pins"],
        "negative_control_count": len(negative_controls),
        "negative_controls": negative_controls,
    }


def synthetic_shard_rows(plan: dict[str, Any], pin_identity: str) -> list[dict[str, Any]]:
    rows = []
    for phase_name, mode in EXPECTED_SHARD_MODES:
        rows.append({
            "phase_name": phase_name,
            "mode": mode,
            "status": "pass",
            "case_ids": list(plan["actual_formal_phase_case_ids"][phase_name]),
            "observation_ids": list(
                plan["actual_formal_phase_observation_ids"][phase_name]),
            "invariants": copy.deepcopy(SHARD_INVARIANTS),
            "pin_identity": pin_identity,
            "five_consumer_execution_count": 0,
            "context_transport_validation_count": 1,
        })
    return rows


def validate_four_shard_merge(rows: list[dict[str, Any]],
                              plan: dict[str, Any],
                              pin_identity: str) -> dict[str, Any]:
    require(len(rows) == 4, "actual formal merge requires exactly four shards")
    require([row.get("phase_name") for row in rows] == list(EXPECTED_SHARDS),
            "actual formal shards are missing, extra, or out of order")
    merged_cases = list(plan["actual_formal_phase_case_ids"][
        "actual_formal_baseline"])
    merged_observations = list(plan["actual_formal_phase_observation_ids"][
        "actual_formal_baseline"])
    require(plan.get("baseline_five_consumer_execution_count") == 1,
            "baseline five-consumer execution must occur exactly once")
    for row, (phase_name, mode) in zip(rows, EXPECTED_SHARD_MODES):
        require(row.get("mode") == mode and row.get("status") == "pass",
                f"invalid shard identity/status: {phase_name}")
        require(row.get("case_ids") ==
                plan["actual_formal_phase_case_ids"][phase_name],
                f"shard case list mismatch: {phase_name}")
        require(row.get("observation_ids") ==
                plan["actual_formal_phase_observation_ids"][phase_name],
                f"shard observation list mismatch: {phase_name}")
        require(row.get("invariants") == SHARD_INVARIANTS,
                f"shard lost protected state/source invariant: {phase_name}")
        require(row.get("pin_identity") == pin_identity,
                f"shard source/protocol pins drifted: {phase_name}")
        require(row.get("five_consumer_execution_count") == 0 and
                row.get("context_transport_validation_count") == 1,
                f"baseline or context transport multiplicity mismatch: {phase_name}")
        merged_cases.extend(row["case_ids"])
        merged_observations.extend(row["observation_ids"])
    require(merged_cases == plan["actual_formal_summary_case_ids"],
            "merged case coverage is not the exact frozen sequence")
    require(merged_observations == plan["actual_formal_observation_ids"],
            "merged observe-first coverage is not the exact frozen sequence")
    require(set(merged_cases) == set(plan["actual_formal_summary_case_ids"]) and
            len(merged_cases) == len(set(merged_cases)),
            "merged coverage has missing, extra, or repeated cases")
    require(plan.get("context_transport_validation_execution_count") == 4,
            "context transport must be validated once per negative shard")
    return {"negative_shard_count": 4,
            "merged_actual_case_count": len(merged_cases),
            "merged_actual_observation_count": len(merged_observations),
            "five_consumer_baseline_count": 1,
            "context_transport_validation_count": 4}


def verify_controller_merge_source(controller_path: Path) -> dict[str, Any]:
    import ast

    source = controller_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(controller_path))
    actual_shards = None
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and any(
                isinstance(target, ast.Name) and target.id == "actual_shards"
                for target in node.targets):
            actual_shards = ast.literal_eval(node.value)
            break
    require(actual_shards == EXPECTED_SHARD_MODES,
            "controller's production shard order/count differs from four-shard contract")
    required_guards = (
        "aggregated_actual_case_ids != expected_actual_case_ids",
        "aggregated_actual_observation_ids != runtime_plan[",
        'shard_summary.get("observed_case_ids") != expected_ids',
        'shard_summary.get("rebuilt_input_full_content_join") is not True',
        'shard_summary.get("prior_ledger_unchanged") is not True',
    )
    missing = [needle for needle in required_guards if needle not in source]
    require(not missing, "controller shard merge guards missing: " + "; ".join(missing))
    return {"controller_shard_order": [name for name, _ in actual_shards],
            "controller_shard_modes": [mode for _, mode in actual_shards],
            "ordered_merge_guards_present": len(required_guards)}


def choose_protocol(argument: str | None) -> tuple[Path, str]:
    candidates = [Path(argument).resolve()] if argument else [
        candidate.resolve() for candidate in DEFAULT_PROTOCOL_CANDIDATES
        if candidate.is_file()]
    if not candidates:
        raise CheckFailure("no negative protocol found; pass --negative-protocol")
    path = candidates[0]
    schema = load_json(path).get("schema")
    if schema == "vnext-t2-independent-negative-protocol-r2":
        return path, "r2"
    if schema == "vnext-t2-independent-negative-protocol-r1":
        return path, "r1_reference"
    return path, "explicit_unknown_schema"


def run_site_hit_contract_only(coverage_path: Path,
                               controller_path: Path,
                               output_path: Path) -> int:
    """Run only static and synthetic hit-receipt contract checks."""
    result: dict[str, Any] = {
        "schema": "vnext-t2-independent-static-site-hit-contract-r1",
        "status": "fail",
        "evidence_kind": "synthetic_validator_contract_only",
        "julia_executed": False,
        "actual_hits_pending": True,
        "actual_model_attestation": "unavailable",
        "checks": [],
        "negative_controls": [],
    }
    try:
        coverage_bytes = coverage_path.read_bytes()
        controller_bytes = controller_path.read_bytes()
        coverage = json.loads(coverage_bytes.decode("utf-8"))
        require(isinstance(coverage, dict), "expected coverage JSON object")
        controller = load_controller_snapshot(controller_path, controller_bytes)
        coverage_snapshot = receipt_for_bytes(coverage_path, coverage_bytes)
        controller_snapshot = receipt_for_bytes(controller_path, controller_bytes)
        map_sha = coverage_snapshot["sha256"]
        runtime_inputs_path = R3_DISPATCH / "runtime_inputs.json"
        replay_path = R3_REPLAY / "formal_t2_serial_replay.json"
        stability_paths = [coverage_path, controller_path, Path(__file__).resolve(),
                           runtime_inputs_path, replay_path]
        before_receipts = {str(path.resolve()): receipt(path)
                           for path in stability_paths}
        result.update({
            "coverage_receipt": coverage_snapshot,
            "controller_receipt": controller_snapshot,
            "input_snapshot_receipts": before_receipts,
        })
        positive_pin_checks = positive_reuse_pin_controls(
            controller, {}, result["checks"],
            runtime_inputs_path, replay_path)
        result["positive_reuse_pin_contract"] = positive_pin_checks
        result["negative_controls"].extend(
            positive_pin_checks["negative_controls"])
        result["site_hit_plan"] = validate_site_hit_plan(coverage)
        result["checks"].append({
            "name": "214-site/622-hit static plan and phase partition",
            "status": "pass",
        })
        site_hit_plan_controls(coverage, result["negative_controls"])
        result["synthetic_runtime_site_hit_contract"] = runtime_site_hit_controls(
            controller, coverage, map_sha, result["checks"])
        source_receipts = coverage.get("ast_inventory_plan", {}).get("sources", [])
        for source in source_receipts:
            source_path = REPO / source["path"]
            actual_source = receipt(source_path)
            require(actual_source["bytes"] == source.get("bytes") and
                    actual_source["sha256"] == source.get("sha256"),
                    f"coverage AST source receipt drift: {source['path']}")
        for relative, expected in positive_pin_checks.get(
                "verified_current_pins", {}).items():
            actual = receipt(REPO / relative)
            require(actual["bytes"] == expected["bytes"] and
                    actual["sha256"] == expected["sha256"],
                    f"positive r3 pin drift during test: {relative}")
        changed = [path for path, expected in before_receipts.items()
                   if receipt(Path(path)) != expected]
        require(not changed,
                "input changed during static test: " + "; ".join(changed))
        result["checks"].append({
            "name": "coverage/controller/replay/runtime-input/source receipts remained stable during test",
            "status": "pass",
        })
        result["negative_control_count"] = (
            len(result["negative_controls"]) +
            result["synthetic_runtime_site_hit_contract"]["negative_control_count"])
        result["status"] = "pass_synthetic_contract_only"
    except Exception as exc:
        result["failure"] = {"type": type(exc).__name__, "message": str(exc)}

    output_path = output_path.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] == "pass_synthetic_contract_only" else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--negative-protocol")
    parser.add_argument("--coverage-map", default=str(DEFAULT_COVERAGE))
    parser.add_argument("--controller", default=str(DEFAULT_CONTROLLER))
    parser.add_argument("--output")
    parser.add_argument("--site-hit-contract-only", action="store_true")
    parser.add_argument("--skip-current-pin-rehash", action="store_true")
    args = parser.parse_args()

    if args.site_hit_contract_only:
        output = Path(args.output) if args.output else (
            IMPLEMENTATION / "archive/independent_static_r2_20260923_synthetic_site_hits" /
            "independent_site_hit_contract_result.json")
        return run_site_hit_contract_only(Path(args.coverage_map).resolve(),
                                          Path(args.controller).resolve(), output)

    result: dict[str, Any] = {
        "schema": "vnext-t2-independent-static-negative-r2",
        "status": "fail",
        "julia_executed": False,
        "actual_model_attestation": "unavailable",
        "checks": [],
        "negative_controls": [],
    }
    try:
        protocol_path, protocol_source = choose_protocol(args.negative_protocol)
        coverage_path = Path(args.coverage_map).resolve()
        controller_path = Path(args.controller).resolve()
        runtime_inputs_path = R3_DISPATCH / "runtime_inputs.json"
        replay_path = R3_REPLAY / "formal_t2_serial_replay.json"
        protocol = load_json(protocol_path)
        coverage = load_json(coverage_path)
        runtime_inputs = load_json(runtime_inputs_path)
        replay = load_json(replay_path)
        controller = load_controller(controller_path)

        result.update({
            "protocol_source": protocol_source,
            "protocol_schema": protocol.get("schema"),
            "protocol_receipt": receipt(protocol_path),
            "coverage_receipt": receipt(coverage_path),
            "controller_receipt": receipt(controller_path),
            "positive_runtime_inputs_receipt": receipt(runtime_inputs_path),
            "positive_replay_receipt": receipt(replay_path),
        })

        join = validate_positive_pin_join(
            protocol, runtime_inputs, replay, runtime_inputs_path, replay_path,
            check_current_files=not args.skip_current_pin_rehash)
        result["positive_pin_join"] = join
        result["checks"].append({"name": "negative protocol to positive r3 104-pin join",
                                 "status": "pass"})

        coverage_summary = validate_coverage(coverage)
        result["coverage"] = coverage_summary
        result["checks"].append({"name": "214-site/622-hit and old-obligation map",
                                 "status": "pass"})

        negative_controls: list[dict[str, Any]] = result["negative_controls"]
        if protocol_source == "r2":
            dispatch_path = protocol_path.parent / "dispatch.json"
            dispatch = load_json(dispatch_path)
            r2_contract = validate_r2_protocol_objects(
                protocol, coverage, dispatch, result["protocol_receipt"],
                result["coverage_receipt"], runtime_inputs)
            controller_protocol = controller.verify_protocol(
                protocol_path, dispatch["protocol"]["sha256"])
            require(controller_protocol == protocol,
                    "production controller parsed a different R2 protocol")
            controller_plan = controller.verify_coverage_runtime_plan(
                protocol, coverage)
            require(controller_plan == coverage.get("runtime_execution_plan"),
                    "production controller returned a different frozen runtime plan")
            independently_rehashed = verify_r2_protocol_current_inputs(protocol)
            archive_scope = validate_r2_archive_scope(
                protocol_path, protocol, dispatch)
            r2_contract["independently_rehashed_current_input_count"] = (
                independently_rehashed)
            r2_contract["controller_verified_current_input_count"] = len(
                protocol["inputs"])
            r2_contract["archive_scope"] = archive_scope
            result["r2_protocol_contract"] = r2_contract
            result["checks"].extend([
                {"name": "R2 protocol/map/dispatch exact receipt and pending boundary",
                 "status": "pass"},
                {"name": "production controller verifies protocol SHA, HEAD, and current 207-pin closure",
                 "status": "pass"},
                {"name": "production controller binds protocol runtime plan to coverage map",
                 "status": "pass"},
                {"name": "independent rehash of all 207 current R2 pins",
                 "status": "pass"},
                {"name": "R2 static QA, snapshot, argv-only command, and archive scope",
                 "status": "pass"},
            ])
            r2_protocol_object_controls(
                protocol, coverage, dispatch, result["protocol_receipt"],
                result["coverage_receipt"], runtime_inputs, negative_controls)

        site_hit_plan_controls(coverage, negative_controls)
        positive_pin_checks = positive_reuse_pin_controls(
            controller, protocol, result["checks"], runtime_inputs_path,
            replay_path)
        result["positive_reuse_pin_contract"] = positive_pin_checks
        negative_controls.extend(positive_pin_checks["negative_controls"])
        result["synthetic_runtime_site_hit_contract"] = runtime_site_hit_controls(
            controller, coverage, result["coverage_receipt"]["sha256"],
            result["checks"])
        base_protocol = copy.deepcopy(protocol)
        drift = copy.deepcopy(base_protocol)
        first_pin = next(iter(runtime_inputs["inputs"]))
        drift["inputs"][first_pin]["sha256"] = "0" * 64
        expect_rejection("protocol source hash drift", lambda: validate_positive_pin_join(
            drift, runtime_inputs, replay, runtime_inputs_path, replay_path,
            check_current_files=False), negative_controls)
        drift_bytes = copy.deepcopy(base_protocol)
        drift_bytes["inputs"][first_pin]["bytes"] += 1
        expect_rejection("protocol source byte-count drift", lambda: validate_positive_pin_join(
            drift_bytes, runtime_inputs, replay, runtime_inputs_path, replay_path,
            check_current_files=False), negative_controls)
        missing = copy.deepcopy(base_protocol)
        del missing["inputs"][first_pin]
        expect_rejection("missing positive input pin", lambda: validate_positive_pin_join(
            missing, runtime_inputs, replay, runtime_inputs_path, replay_path,
            check_current_files=False), negative_controls)
        extra_manifest = copy.deepcopy(runtime_inputs)
        extra_manifest["inputs"]["src/__independent_extra__.jl"] = {
            "path": "src/__independent_extra__.jl", "bytes": 0,
            "sha256": hashlib.sha256(b"").hexdigest()}
        expect_rejection("extra positive input pin", lambda: validate_positive_pin_join(
            base_protocol, extra_manifest, replay, runtime_inputs_path, replay_path,
            check_current_files=False), negative_controls)

        # JSON object key order is semantic-map order, while shard and ID arrays are ordered.
        reordered_pins = copy.deepcopy(runtime_inputs)
        reordered_pins["inputs"] = dict(reversed(list(reordered_pins["inputs"].items())))
        validate_positive_pin_join(base_protocol, reordered_pins, replay,
                                   runtime_inputs_path, replay_path,
                                   check_current_files=False)
        result["checks"].append({"name": "positive pin map key reordering preserves identity",
                                 "status": "pass"})

        plan = coverage["runtime_execution_plan"]
        result["checks"].extend(controller_plan_controls(controller, coverage))
        merge_source = verify_controller_merge_source(controller_path)
        pin_identity = hashlib.sha256(json.dumps(
            canonical_pin_map(runtime_inputs["inputs"], "positive r3 runtime inputs"),
            sort_keys=True, separators=(",", ":")).encode("utf-8")).hexdigest()
        rows = synthetic_shard_rows(plan, pin_identity)
        merge_summary = validate_four_shard_merge(rows, plan, pin_identity)
        result["four_shard_merge"] = {**merge_summary, **merge_source}
        result["checks"].append({"name": "four-shard merge and production source guards",
                                 "status": "pass"})

        expect_rejection("missing shard", lambda: validate_four_shard_merge(
            rows[:-1], plan, pin_identity), negative_controls)
        expect_rejection("extra shard", lambda: validate_four_shard_merge(
            rows + [copy.deepcopy(rows[-1])], plan, pin_identity), negative_controls)
        expect_rejection("reordered shard sequence", lambda: validate_four_shard_merge(
            list(reversed(rows)), plan, pin_identity), negative_controls)
        wrong_order = copy.deepcopy(rows)
        wrong_order[0]["case_ids"] = list(reversed(wrong_order[0]["case_ids"]))
        expect_rejection("reordered case IDs within shard", lambda: validate_four_shard_merge(
            wrong_order, plan, pin_identity), negative_controls)
        wrong_pin = copy.deepcopy(rows)
        wrong_pin[2]["pin_identity"] = "0" * 64
        expect_rejection("source/protocol pin drift across shard", lambda: validate_four_shard_merge(
            wrong_pin, plan, pin_identity), negative_controls)
        wrong_invariant = copy.deepcopy(rows)
        wrong_invariant[1]["invariants"]["prior_ledger_unchanged"] = False
        expect_rejection("prior ledger mutation in shard", lambda: validate_four_shard_merge(
            wrong_invariant, plan, pin_identity), negative_controls)

        result["status"] = "pass"
        result["negative_control_count"] = len(negative_controls)
        result["formal_t2_accepted"] = False
        if protocol_source == "r1_reference":
            result["r2_protocol_pin_join_status"] = "not_executed_r2_protocol_absent"
            result["status"] = "pass_reference_only_r2_protocol_absent"
        elif protocol_source == "r2":
            result["r2_protocol_pin_join_status"] = "pass"
        else:
            result["r2_protocol_pin_join_status"] = "not_executed_unknown_protocol_schema"
    except Exception as exc:
        result["failure"] = {"type": type(exc).__name__, "message": str(exc)}
        result["r2_protocol_pin_join_status"] = (
            "not_executed_r2_protocol_absent"
            if result.get("protocol_source") == "r1_reference"
            else "failed" if result.get("protocol_source") == "r2"
            else "not_executed_unknown_protocol_schema")
    output = Path(args.output).resolve() if args.output else (
        IMPLEMENTATION / "archive/independent_static_r2_20260923" /
        "independent_static_r2_after_fix_result.json").resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
                      encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if result["status"] in ("pass", "pass_reference_only_r2_protocol_absent") else 1


if __name__ == "__main__":
    raise SystemExit(main())
