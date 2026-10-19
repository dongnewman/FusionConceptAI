from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
from typing import Any, Callable


EXPECTED_SHARD_MODES = ["preflight", "authority", "fault_n10", "t1_handoff"]
EXPECTED_FORMAL_PHASES = [
    "actual_formal_baseline", "actual_formal_preflight",
    "actual_formal_authority", "actual_formal_fault_n10",
    "actual_formal_t1_handoff"]
ATTEMPT8_PROTOCOL = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2/protocol.json")
EXPECTED_ATTEMPT9C_PROTOCOL = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9c_final/protocol.json")
DEFAULT_EVIDENCE = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt9c_final_r4r5_argv_projection_20260923_r3")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def relative_path(root: Path, value: str) -> Path:
    pure = PurePosixPath(value)
    if pure.is_absolute() or ".." in pure.parts:
        raise RuntimeError(f"path is not a root-relative POSIX path: {value}")
    path = root.joinpath(*pure.parts).resolve()
    path.relative_to(root.resolve())
    return path


def file_receipt(root: Path, path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": path.resolve().relative_to(root.resolve()).as_posix(),
            "bytes": len(data), "sha256": sha256(data)}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def expect_reject(name: str, operation: Callable[[], Any],
                  controls: list[dict[str, str]]) -> None:
    try:
        operation()
    except Exception as error:  # The specific type is recorded for diagnosis.
        controls.append({"name": name, "status": "pass",
                         "rejected_as": type(error).__name__})
        return
    raise RuntimeError(f"negative control unexpectedly accepted: {name}")


def verify_current_input_pins(root: Path,
                              protocol: dict[str, Any]) -> dict[str, Any]:
    inputs = protocol.get("inputs")
    require(isinstance(inputs, dict), "protocol inputs are not a mapping")
    require(protocol.get("input_count") == len(inputs),
            "protocol input_count differs from inputs mapping")
    checked: dict[str, dict[str, Any]] = {}
    for relative, expected in sorted(inputs.items()):
        path = relative_path(root, relative)
        actual = file_receipt(root, path)
        require(actual == expected,
                f"current input pin mismatch: {relative}")
        checked[relative] = actual
    return {"input_count": len(checked),
            "input_set_sha256": sha256(
                json.dumps(checked, sort_keys=True, separators=(",", ":")
                ).encode("utf-8")),
            "checked_input_receipts": checked}


def verify_protocol_and_map(root: Path, protocol_path: Path,
                            previous_protocol_path: Path
                            ) -> tuple[dict[str, Any], dict[str, Any],
                                       dict[str, Any], dict[str, Any],
                                       dict[str, Any]]:
    protocol = load_object(protocol_path)
    previous_protocol = load_object(previous_protocol_path)
    require(protocol.get("schema") ==
            "vnext-t2-independent-negative-protocol-r4",
            "attempt9c_final protocol schema mismatch")
    require(protocol.get("formal_t2_accepted") is False and
            protocol.get("status") == "frozen_static_ready_not_executed",
            "attempt9c_final status crosses the static/not-executed boundary")

    current_map_pin = protocol.get("coverage_map")
    previous_map_pin = previous_protocol.get("coverage_map")
    require(isinstance(current_map_pin, dict) and
            isinstance(previous_map_pin, dict), "coverage map receipt absent")
    current_map_path = relative_path(root, current_map_pin["path"])
    previous_map_path = relative_path(root, previous_map_pin["path"])
    current_map = load_object(current_map_path)
    previous_map = load_object(previous_map_path)
    current_map_receipt = file_receipt(root, current_map_path)
    require(current_map_receipt == current_map_pin,
            "attempt9c_final coverage map receipt differs from current bytes")
    require(current_map_pin["sha256"] == previous_map_pin["sha256"] and
            current_map == previous_map,
            "coverage projection/map differs from attempt8 final2")
    map_input = protocol["inputs"].get(current_map_pin["path"])
    require(map_input == current_map_pin,
            "coverage map is not pinned identically in protocol inputs")

    require(current_map.get("schema") ==
            "vnext-t2-independent-negative-coverage-map-r3" and
            current_map.get("status") == "static_coverage_map_no_julia" and
            current_map.get("formal_t2_accepted") is False,
            "coverage map status/schema changed")
    require(current_map.get("successor_case_count") == 60 and
            len(current_map.get("successor_cases", [])) == 60 and
            current_map.get("successor_assertion_site_count") == 214 and
            len(current_map.get("successor_assertion_sites", [])) == 214 and
            current_map.get("successor_expected_runtime_hit_count") == 622,
            "successor coverage count regression")

    sites = current_map["successor_assertion_sites"]
    site_ids = [row["id"] for row in sites]
    require(len(site_ids) == len(set(site_ids)),
            "assertion-site IDs are not unique")
    require(sum(int(row["runtime_multiplicity"]) for row in sites) == 622,
            "site runtime multiplicities do not total 622")
    phase_hit_plan = current_map["successor_assertion_runtime_hit_plan"]
    require(phase_hit_plan.get("assertion_site_count") == 214 and
            phase_hit_plan.get("expected_runtime_hit_count") == 622 and
            phase_hit_plan.get("status") ==
            "expected_source_site_hits_static_plan_actual_hits_pending",
            "site-hit plan count/status regression")
    per_phase = phase_hit_plan["phase_site_hit_counts"]
    require(sum(sum(int(v) for v in row.values())
                for row in per_phase.values()) == 622,
            "per-phase site-hit plan does not total 622")

    runtime = current_map["runtime_execution_plan"]
    previous_runtime = previous_map["runtime_execution_plan"]
    require(protocol.get("runtime_execution_plan") == runtime and
            protocol.get("coverage_assertion_hit_plan") == phase_hit_plan,
            "protocol coverage projection differs from the frozen coverage map")
    actual_cases = runtime.get("actual_formal_summary_case_ids")
    previous_actual_cases = previous_runtime.get(
        "actual_formal_summary_case_ids")
    require(isinstance(actual_cases, list) and len(actual_cases) == 45 and
            len(actual_cases) == len(set(actual_cases)) and
            actual_cases == previous_actual_cases,
            "formal actual-case inventory differs from attempt8")
    require(runtime.get("actual_formal_phase_case_ids") ==
            previous_runtime.get("actual_formal_phase_case_ids") and
            runtime.get("actual_formal_phase_observation_ids") ==
            previous_runtime.get("actual_formal_phase_observation_ids") and
            runtime.get("actual_formal_observation_ids") ==
            previous_runtime.get("actual_formal_observation_ids"),
            "formal case/observation phase projection differs from attempt8")
    phase_cases = runtime["actual_formal_phase_case_ids"]
    formal_phases = EXPECTED_FORMAL_PHASES
    require(set(phase_cases) == set(formal_phases),
            "formal phase order differs from baseline plus four shard modes")
    flattened_cases = [case_id for phase in formal_phases
                       for case_id in phase_cases[phase]]
    require(flattened_cases == actual_cases,
            "45 formal IDs do not equal ordered five-phase projection")
    require(runtime.get("expected_unique_case_count") == 60 and
            runtime.get("expected_runtime_case_hit_count") == 68 and
            current_map.get("successor_case_count") == 60,
            "complete 60/68 case runtime plan regressed")

    source_span_counts: dict[int, int] = {}
    for site in sites:
        source_path = site.get("path")
        source_pin = protocol["inputs"].get(source_path)
        require(source_pin is not None,
                f"site source is not pinned: {source_path}")
        source_file = relative_path(root, source_path)
        source_text = source_file.read_text(encoding="utf-8").splitlines()
        line_number = site.get("line")
        require(isinstance(line_number, int) and
                1 <= line_number <= len(source_text),
                f"site line is outside source: {site.get('id')}")
        text_value = site.get("source_text")
        matched_span = None
        first_line = line_number - 1
        for last_line in range(first_line, min(len(source_text), first_line + 9)):
            source_window = " ".join(
                line.strip() for line in source_text[first_line:last_line + 1]
            ).strip()
            if source_window == text_value:
                matched_span = last_line - first_line + 1
                break
        require(matched_span is not None and
                sha256(text_value.encode("utf-8")) ==
                site.get("source_text_sha256"),
                f"site source text/hash mismatch: {site.get('id')}")
        source_span_counts[matched_span] = \
            source_span_counts.get(matched_span, 0) + 1

    comparison = protocol.get("attempt7_coverage_comparison")
    require(isinstance(comparison, dict) and
            comparison.get("formal_case_count") == 45 and
            comparison.get("successor_assertion_site_count") == 214 and
            comparison.get("successor_expected_runtime_hit_count") == 622 and
            comparison.get("semantic_case_ids_and_site_ids_equal") is True and
            comparison.get(
                "site_assertion_text_multiplicity_and_phase_hits_equal") is True,
            "attempt7 comparison summary weakens coverage semantics")
    ledger = comparison.get("path_line_relocation_ledger")
    require(isinstance(ledger, dict),
            "attempt7 source relocation ledger is absent")
    ledger_entries = ledger.get("entries")
    require(isinstance(ledger_entries, list) and len(ledger_entries) == 214 and
            ledger.get("site_count") == 214 and
            ledger.get("current_source_line_verified_count") == 214 and
            ledger.get("source_text_match_count") == 214,
            "attempt7 source relocation ledger is not 214 rows")
    changed_paths = sum(row.get("path_changed") is True
                        for row in ledger_entries)
    changed_lines = sum(row.get("line_delta") != 0
                        for row in ledger_entries)
    unchanged_paths = sum(row.get("path_changed") is False
                          for row in ledger_entries)
    require(changed_paths == 175 and changed_lines == 0 and
            unchanged_paths == 39,
            "attempt7 source relocation projection regressed")
    current_sites_by_id = {site["id"]: site for site in sites}
    for row in ledger_entries:
        site = current_sites_by_id.get(row.get("id"))
        current = row.get("attempt8", {})
        require(site is not None and
                row.get("current_source_line_verified") is True and
                row.get("source_text_matches_attempt7") is True and
                current.get("path") == site.get("path") and
                current.get("line") == site.get("line") and
                row.get("source_text") == site.get("source_text") and
                row.get("source_text_sha256") ==
                site.get("source_text_sha256"),
                f"relocation ledger/source mismatch: {row.get('id')}")

    projection = protocol.get("projection24_reuse")
    previous_projection = previous_protocol.get("projection24_reuse")
    require(isinstance(projection, dict) and
            projection.get("schema") ==
            "vnext-t2-projection24-cross-run-reuse-r1" and
            projection.get("status") ==
            "frozen_r1_evidence_with_exact_current_join" and
            projection == previous_projection,
            "projection24 plan differs from attempt8")
    require(projection.get("source_input_count") == 157 and
            projection.get("r1_input_intersection_count") == 151 and
            projection.get("excluded_r1_input_count") == 6 and
            projection.get("dependency_subset_count") == 159 and
            len(projection.get("r1_input_intersection", {})) == 151 and
            len(projection.get("excluded_r1_input_rows", [])) == 6 and
            len(projection.get("dependency_subset", {})) == 159,
            "projection24 closure counts regressed")
    dependencies = projection["dependency_subset"]
    require(set(dependencies).issubset(protocol["inputs"]),
            "projection24 dependencies escape current input closure")
    for dependency_path, dependency_pin in dependencies.items():
        require(protocol["inputs"][dependency_path] == dependency_pin,
                f"projection24 join differs from current pin: {dependency_path}")

    projection_validator = protocol.get("projection24_reuse_validator_path")
    require(projection_validator ==
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "validate_projection24_reuse_r4.py",
            "attempt9c_final does not select the versioned r4 projection validator")
    validator_pin = protocol["inputs"].get(projection_validator)
    require(validator_pin is not None and
            file_receipt(root, relative_path(root, projection_validator)) ==
            validator_pin,
            "r4 projection validator is not pinned")
    source_resolution = {
        "resolved_site_count": sum(source_span_counts.values()),
        "line_span_histogram": {
            str(span): source_span_counts[span]
            for span in sorted(source_span_counts)},
    }
    return (protocol, current_map, previous_protocol, previous_map,
            source_resolution)


def extract_builder(controller_path: Path,
                    driver_path: Path) -> Callable[..., list[str]]:
    source = controller_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(controller_path))
    builders = [node for node in tree.body
                if isinstance(node, ast.FunctionDef) and
                node.name == "build_actual_formal_shard_command"]
    require(len(builders) == 1, "controller builder missing or duplicated")
    module = ast.Module(body=builders, type_ignores=[])
    namespace: dict[str, Any] = {"ACTUAL_DRIVER": driver_path.resolve()}
    exec(compile(module, str(controller_path), "exec"), namespace, namespace)
    builder = namespace["build_actual_formal_shard_command"]

    main_nodes = [node for node in tree.body
                  if isinstance(node, ast.FunctionDef) and node.name == "main"]
    require(len(main_nodes) == 1, "controller main() missing or duplicated")
    main = main_nodes[0]
    actual_shard_assignments = []
    for node in ast.walk(main):
        if not isinstance(node, ast.Assign):
            continue
        if any(isinstance(target, ast.Name) and target.id == "actual_shards"
               for target in node.targets):
            actual_shard_assignments.append(node.value)
    require(len(actual_shard_assignments) == 1,
            "controller actual_shards assignment missing or duplicated")
    observed_modes = [tuple(row) for row in
                      ast.literal_eval(actual_shard_assignments[0])]
    require(observed_modes == [
        ("actual_formal_preflight", "preflight"),
        ("actual_formal_authority", "authority"),
        ("actual_formal_fault_n10", "fault_n10"),
        ("actual_formal_t1_handoff", "t1_handoff"),
    ], "controller's production four-shard inventory/order changed")

    builder_loop_found = False
    for node in ast.walk(main):
        if not isinstance(node, ast.For) or not isinstance(node.target, ast.Tuple):
            continue
        names = [item.id for item in node.target.elts
                 if isinstance(item, ast.Name)]
        if names != ["phase_name", "mode"]:
            continue
        assigns_builder = any(
            isinstance(child, ast.Assign) and
            any(isinstance(target, ast.Name) and target.id == "shard_command"
                for target in child.targets) and
            isinstance(child.value, ast.Call) and
            isinstance(child.value.func, ast.Name) and
            child.value.func.id == "build_actual_formal_shard_command"
            for child in ast.walk(node))
        calls_run_phase = any(
            isinstance(child, ast.Call) and isinstance(child.func, ast.Name) and
            child.func.id == "run_phase" and len(child.args) >= 2 and
            isinstance(child.args[1], ast.Name) and
            child.args[1].id == "shard_command"
            for child in ast.walk(node))
        if assigns_builder and calls_run_phase:
            builder_loop_found = True
    require(builder_loop_found,
            "production shard loop does not execute the tested builder")

    baseline_assignment = []
    for node in ast.walk(main):
        if not isinstance(node, ast.Assign):
            continue
        if any(isinstance(target, ast.Name) and target.id == "baseline_phase"
               for target in node.targets):
            baseline_assignment.append(node.value)
    require(len(baseline_assignment) == 1,
            "actual baseline command assignment missing or duplicated")
    baseline_call = baseline_assignment[0]
    require(isinstance(baseline_call, ast.Call) and
            isinstance(baseline_call.func, ast.Name) and
            baseline_call.func.id == "run_phase" and
            isinstance(baseline_call.args[0], ast.Constant) and
            baseline_call.args[0].value == "actual_formal_baseline",
            "baseline phase call shape changed")
    command_expression = baseline_call.args[1]
    list_nodes = [item for item in ast.walk(command_expression)
                  if isinstance(item, ast.List) and item.elts and
                  isinstance(item.elts[0], ast.Constant) and
                  item.elts[0].value == "baseline"]
    require(len(list_nodes) == 1 and len(list_nodes[0].elts) == 9,
            "baseline argv authority/context/output/map expression changed")
    baseline_items = list_nodes[0].elts
    require(ast.unparse(baseline_items[-2]) ==
            "str(ROOT / protocol['coverage_map']['path'])" and
            isinstance(baseline_items[-1], ast.Name) and
            baseline_items[-1].id == "coverage_map_sha256",
            "baseline command omits the pinned coverage map path/hash")
    return builder


def validate_driver_args(args: list[str], mode: str,
                         authority_args: list[str], context_path: str,
                         context_sha: str, authorization_path: str,
                         authorization_sha: str, output_path: str,
                         expected_map_path: str,
                         expected_map_sha: str) -> None:
    require(len(args) == 16, "driver ARGS length is not 16")
    require(args[0] == mode, "driver mode changed")
    require(args[1:9] == authority_args, "authority path/hash positions changed")
    require(args[9:11] == [context_path, context_sha],
            "context path/hash positions changed")
    require(args[11:13] == [authorization_path, authorization_sha],
            "authorization path/hash positions changed")
    require(args[13] == output_path, "artifact output position changed")
    require(args[14:16] == [expected_map_path, expected_map_sha],
            "coverage map path/hash positions differ from frozen pin")


def verify_builder_and_driver(root: Path, protocol: dict[str, Any],
                              controls: list[dict[str, str]]) -> dict[str, Any]:
    controller_path = relative_path(root, protocol["controller_path"])
    driver_path = relative_path(root, protocol["driver_path"])
    controller_pin = protocol["inputs"].get(protocol["controller_path"])
    driver_pin = protocol["inputs"].get(protocol["driver_path"])
    require(controller_pin == file_receipt(root, controller_path),
            "controller is not pinned by current protocol")
    require(driver_pin == file_receipt(root, driver_path),
            "driver is not pinned by current protocol")
    driver_source = driver_path.read_text(encoding="utf-8")
    require("length(ARGS) == 16 || error(" in driver_source and
            "const T2_NEG_COVERAGE_MAP_PATH = abspath(ARGS[15])" in
            driver_source and
            "const T2_NEG_COVERAGE_MAP_SHA256 = lowercase(ARGS[16])" in
            driver_source,
            "r3 driver argument parser no longer matches frozen contract")

    contract = protocol.get("actual_formal_shard_argv_contract")
    require(isinstance(contract, dict) and contract.get("schema") ==
            "vnext-t2-formal-shard-argv-contract-r1" and
            contract.get("driver_path") == protocol["driver_path"] and
            contract.get("controller_builder") ==
            "build_actual_formal_shard_command" and
            contract.get("expected_driver_argument_count") == 16 and
            contract.get("coverage_map_path_driver_argv_index_1_based") == 15 and
            contract.get("coverage_map_sha256_driver_argv_index_1_based") == 16 and
            contract.get("shard_modes") == EXPECTED_SHARD_MODES and
            contract.get("static_actual_command_builder_test") is True,
            "frozen shard argv contract missing or malformed")

    builder = extract_builder(controller_path, driver_path)
    map_path = str(relative_path(root, protocol["coverage_map"]["path"]))
    map_sha = protocol["coverage_map"]["sha256"]
    authority_args = []
    for index in range(4):
        authority_args.extend([str(root / f"tester/authority_{index}.json"),
                               f"{index + 1:064x}"])
    context_path = str(root / "tester/baseline_context.jls")
    context_sha = "a" * 64
    authorization_path = str(root / "tester/authorization.json")
    authorization_sha = "b" * 64
    julia_prefix = ["julia", "--project=tester-project"]
    command_receipts = []

    for phase, mode in (
            ("actual_formal_preflight", "preflight"),
            ("actual_formal_authority", "authority"),
            ("actual_formal_fault_n10", "fault_n10"),
            ("actual_formal_t1_handoff", "t1_handoff")):
        output_path = str(root / f"tester/{phase}/artifacts")
        command = builder(julia_prefix, mode, list(authority_args),
                          Path(context_path), context_sha,
                          Path(authorization_path), authorization_sha,
                          Path(output_path), Path(map_path), map_sha)
        driver_index = command.index(str(driver_path.resolve()))
        args = command[driver_index + 1:]
        validate_driver_args(args, mode, authority_args, context_path,
                             context_sha, authorization_path,
                             authorization_sha, output_path, map_path, map_sha)
        command_receipts.append({"phase": phase, "mode": mode,
                                 "driver_argument_count": len(args),
                                 "driver_argv": args,
                                 "coverage_map_path": args[14],
                                 "coverage_map_sha256": args[15]})

    sample = command_receipts[0]["driver_argv"]
    expect_reject("shard missing map path and hash",
                  lambda: validate_driver_args(
                      sample[:-2], "preflight", authority_args, context_path,
                      context_sha, authorization_path, authorization_sha,
                      str(root / "tester/actual_formal_preflight/artifacts"),
                      map_path, map_sha), controls)
    wrong_path = list(sample)
    wrong_path[14] = str(root / "stale/coverage_map.json")
    expect_reject("shard stale map path", lambda: validate_driver_args(
        wrong_path, "preflight", authority_args, context_path, context_sha,
        authorization_path, authorization_sha,
        str(root / "tester/actual_formal_preflight/artifacts"),
        map_path, map_sha), controls)
    wrong_sha = list(sample)
    wrong_sha[15] = "0" * 64
    expect_reject("shard stale map sha", lambda: validate_driver_args(
        wrong_sha, "preflight", authority_args, context_path, context_sha,
        authorization_path, authorization_sha,
        str(root / "tester/actual_formal_preflight/artifacts"),
        map_path, map_sha), controls)
    reordered = list(sample)
    reordered[14], reordered[15] = reordered[15], reordered[14]
    expect_reject("shard map path/hash reorder", lambda: validate_driver_args(
        reordered, "preflight", authority_args, context_path, context_sha,
        authorization_path, authorization_sha,
        str(root / "tester/actual_formal_preflight/artifacts"),
        map_path, map_sha), controls)
    expect_reject("builder rejects unsupported mode", lambda: builder(
        julia_prefix, "baseline", list(authority_args), Path(context_path),
        context_sha, Path(authorization_path), authorization_sha,
        Path("unused"), Path(map_path), map_sha), controls)
    expect_reject("builder rejects missing authority pair", lambda: builder(
        julia_prefix, "preflight", authority_args[:-2], Path(context_path),
        context_sha, Path(authorization_path), authorization_sha,
        Path("unused"), Path(map_path), map_sha), controls)
    expect_reject("builder rejects malformed map sha", lambda: builder(
        julia_prefix, "preflight", list(authority_args), Path(context_path),
        context_sha, Path(authorization_path), authorization_sha,
        Path("unused"), Path(map_path), "not-a-sha256"), controls)
    return {"status": "pass", "mode_order": EXPECTED_SHARD_MODES,
            "expected_driver_argument_count": 16,
            "coverage_map_path_index_1_based": 15,
            "coverage_map_sha256_index_1_based": 16,
            "commands": command_receipts,
            "negative_controls": len(controls),
            "baseline_map_arguments_verified_in_controller_ast": True}


def verify_controller_projection_route(root: Path,
                                       protocol: dict[str, Any]
                                       ) -> dict[str, Any]:
    r4_relative = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "independent_negative_controller_r4.py")
    r5_relative = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "independent_negative_controller_r5.py")
    require(protocol.get("controller_path") == r5_relative,
            "protocol does not select controller r5")
    r4_path = relative_path(root, r4_relative)
    r5_path = relative_path(root, r5_relative)
    r4_pin = protocol["inputs"].get(r4_relative)
    r5_pin = protocol["inputs"].get(r5_relative)
    require(r4_pin == file_receipt(root, r4_path),
            "controller r4 predecessor is not pinned")
    require(r5_pin == file_receipt(root, r5_path),
            "controller r5 is not pinned")
    old_text = r4_path.read_text(encoding="utf-8")
    new_text = r5_path.read_text(encoding="utf-8")
    old_route = "validate_projection24_reuse_r3.py"
    new_route = "validate_projection24_reuse_r4.py"
    require(old_text.count(old_route) == 1 and
            new_text.count(new_route) == 1,
            "controller projection validator route identity is ambiguous")
    normalized = new_text.replace(new_route, old_route, 1)
    require(normalized == old_text,
            "controller r4->r5 diff exceeds the single validator route")

    validator_relative = protocol.get("projection24_reuse_validator_path")
    require(validator_relative ==
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "validate_projection24_reuse_r4.py" and
            new_route in validator_relative,
            "protocol/controller projection validator route does not join")
    tree = ast.parse(new_text, filename=str(r5_path))
    route_assignments = [node for node in tree.body
                         if isinstance(node, ast.Assign) and
                         any(isinstance(target, ast.Name) and
                             target.id == "PROJECTION_REUSE_VALIDATOR"
                             for target in node.targets)]
    require(len(route_assignments) == 1 and
            ast.unparse(route_assignments[0].value) ==
            "TEST_ROOT / 'validate_projection24_reuse_r4.py'",
            "r5 controller constant does not resolve to the pinned r4 validator")
    main_nodes = [node for node in tree.body
                  if isinstance(node, ast.FunctionDef) and node.name == "main"]
    require(len(main_nodes) == 1, "controller r5 main() missing or duplicated")
    main = main_nodes[0]

    assigned: dict[str, list[ast.AST]] = {
        "projection_dir": [],
        "projection_reuse_receipt_path": [],
        "projection_phase": [],
    }
    for node in ast.walk(main):
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id in assigned:
                assigned[target.id].append(node.value)
    require(all(len(values) == 1 for values in assigned.values()),
            "controller projection phase variables are missing/duplicated")
    require(ast.unparse(assigned["projection_dir"][0]) ==
            "output / 'projection24_cross_run_validation'" and
            ast.unparse(assigned["projection_reuse_receipt_path"][0]) ==
            "projection_dir / 'reuse_receipt.json'",
            "projection child output path is not phase-bound")
    phase_call = assigned["projection_phase"][0]
    require(isinstance(phase_call, ast.Call) and
            isinstance(phase_call.func, ast.Name) and
            phase_call.func.id == "run_phase" and len(phase_call.args) >= 3 and
            isinstance(phase_call.args[0], ast.Constant) and
            phase_call.args[0].value == "projection24_cross_run_validation" and
            ast.unparse(phase_call.args[1]) ==
            "[sys.executable, '-B', str(PROJECTION_REUSE_VALIDATOR), "
            "str(protocol_path), str(projection_reuse_receipt_path)]" and
            isinstance(phase_call.args[2], ast.Name) and
            phase_call.args[2].id == "projection_dir",
            "projection child argv is not bound to the expected phase/pins/output")
    phase_order = protocol.get("phase_order")
    require(isinstance(phase_order, list) and
            "projection24_cross_run_validation" in phase_order and
            phase_order.index("projection24_cross_run_validation") == 2,
            "protocol phase order omits/misplaces the projection validator")
    projection_phase_actions = [ast.unparse(node) for node in ast.walk(main)
                                if isinstance(node, ast.Call)]
    require("phases.append(projection_phase)" in projection_phase_actions and
            "require_natural(projection_phase, exit_zero=True)" in
            projection_phase_actions,
            "projection phase result is not required to exit naturally with zero")
    return {
        "status": "pass",
        "controller_r4": r4_pin,
        "controller_r5": r5_pin,
        "allowed_source_diff": {
            "field": "PROJECTION_REUSE_VALIDATOR route",
            "old": old_route,
            "new": new_route},
        "normalized_r5_matches_r4": True,
        "child_phase": "projection24_cross_run_validation",
        "child_argv_ast": ast.unparse(phase_call.args[1]),
        "child_output_path_ast": ast.unparse(phase_call.args[2]),
        "phase_order_index": 2,
        "natural_exit_zero_required": True,
    }


def verify_projection_validator_diff(root: Path, protocol: dict[str, Any],
                                     previous_protocol: dict[str, Any]
                                     ) -> dict[str, Any]:
    old_path = relative_path(root,
        previous_protocol["projection24_reuse_validator_path"])
    new_path = relative_path(root,
        protocol["projection24_reuse_validator_path"])
    old_text = old_path.read_text(encoding="utf-8")
    new_text = new_path.read_text(encoding="utf-8")
    exact_changes = [
        {"field": "CLI usage filename",
         "old": "validate_projection24_reuse_r3.py",
         "new": "validate_projection24_reuse_r4.py"},
        {"field": "protocol schema guard",
         "old": "vnext-t2-independent-negative-protocol-r3",
         "new": "vnext-t2-independent-negative-protocol-r4"},
        {"field": "projection validation receipt schema",
         "old": "vnext-t2-projection24-cross-run-validation-r3",
         "new": "vnext-t2-projection24-cross-run-validation-r4"},
    ]
    normalized = new_text
    for change in exact_changes:
        require(normalized.count(change["new"]) == 1,
                f"expected one r4 identity field: {change['field']}")
        normalized = normalized.replace(change["new"], change["old"], 1)
    require(normalized == old_text,
            "r3->r4 projection validator diff exceeds exact identity changes")
    require(file_receipt(root, old_path) ==
            previous_protocol["inputs"][old_path.relative_to(root).as_posix()],
            "r3 projection validator differs from attempt8 input pin")
    require(file_receipt(root, new_path) ==
            protocol["inputs"][new_path.relative_to(root).as_posix()],
            "r4 projection validator differs from attempt9c_final input pin")
    return {"status": "pass", "allowed_changes": exact_changes,
            "old_source": file_receipt(root, old_path),
            "new_source": file_receipt(root, new_path),
            "normalized_new_sha256": sha256(normalized.encode("utf-8"))}


def run_projection_validators(root: Path, protocol_path: Path,
                              previous_protocol: dict[str, Any],
                              protocol: dict[str, Any],
                              evidence_dir: Path) -> dict[str, Any]:
    r4_validator = relative_path(root,
        protocol["projection24_reuse_validator_path"])
    r3_validator = relative_path(root,
        previous_protocol["projection24_reuse_validator_path"])
    r4_receipt = evidence_dir / "projection_r4_receipt.json"
    r3_receipt = evidence_dir / "projection_r3_expected_reject.json"

    r4_command = [sys.executable, "-B", str(r4_validator),
                  str(protocol_path.resolve()), str(r4_receipt.resolve())]
    r4_run = subprocess.run(r4_command, cwd=root, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    (evidence_dir / "projection_r4_stdout.raw").write_bytes(r4_run.stdout)
    (evidence_dir / "projection_r4_stderr.raw").write_bytes(r4_run.stderr)
    require(r4_run.returncode == 0,
            f"r4 projection validator exit={r4_run.returncode}")
    r4_stdout = r4_run.stdout.decode("utf-8", errors="replace")
    require("T2_PROJECTION24_REUSE=PASS sites=24 groups=4" in r4_stdout,
            "r4 projection validator pass marker absent")
    require(r4_receipt.is_file(), "r4 projection validation receipt absent")
    validation = load_object(r4_receipt)
    require(validation.get("status") == "pass" and
            validation.get("schema") ==
            "vnext-t2-projection24-cross-run-validation-r4" and
            validation.get("assertion_sites_completed") == 24 and
            len(validation.get("semantic_group_site_counts", {})) == 4,
            "r4 projection validation receipt malformed")

    r3_command = [sys.executable, "-B", str(r3_validator),
                  str(protocol_path.resolve()), str(r3_receipt.resolve())]
    r3_run = subprocess.run(r3_command, cwd=root, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, check=False)
    (evidence_dir / "projection_r3_reject_stdout.raw").write_bytes(r3_run.stdout)
    (evidence_dir / "projection_r3_reject_stderr.raw").write_bytes(r3_run.stderr)
    r3_stderr = r3_run.stderr.decode("utf-8", errors="replace")
    require(r3_run.returncode != 0 and
            "projection reuse protocol schema mismatch" in r3_stderr,
            "old r3 validator did not fail closed on r4 protocol")
    require(not r3_receipt.exists(),
            "old r3 validator wrote a receipt for the r4 protocol")
    return {
        "r4": {"argv": r4_command, "exit_code": r4_run.returncode,
               "stdout": file_receipt(root, evidence_dir /
                                      "projection_r4_stdout.raw"),
               "stderr": file_receipt(root, evidence_dir /
                                      "projection_r4_stderr.raw"),
               "receipt": file_receipt(root, r4_receipt),
               "pass_marker": "T2_PROJECTION24_REUSE=PASS sites=24 groups=4"},
        "r3_negative_control": {
            "argv": r3_command, "exit_code": r3_run.returncode,
            "stdout": file_receipt(root, evidence_dir /
                                   "projection_r3_reject_stdout.raw"),
            "stderr": file_receipt(root, evidence_dir /
                                   "projection_r3_reject_stderr.raw"),
            "expected_error": "projection reuse protocol schema mismatch",
            "receipt_written": False},
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--protocol", type=Path,
                        default=EXPECTED_ATTEMPT9C_PROTOCOL)
    parser.add_argument("--previous-protocol", type=Path,
                        default=ATTEMPT8_PROTOCOL)
    parser.add_argument("--evidence-dir", type=Path, default=DEFAULT_EVIDENCE)
    args = parser.parse_args()
    root = args.root.resolve()
    protocol_path = (args.protocol if args.protocol.is_absolute()
                     else root / args.protocol).resolve()
    previous_protocol_path = (args.previous_protocol
                              if args.previous_protocol.is_absolute()
                              else root / args.previous_protocol).resolve()
    evidence_dir = (args.evidence_dir if args.evidence_dir.is_absolute()
                    else root / args.evidence_dir).resolve()
    protocol_path.relative_to(root)
    previous_protocol_path.relative_to(root)
    evidence_dir.relative_to(root)
    require(not evidence_dir.exists(),
            f"tester evidence leaf already exists: {evidence_dir}")
    evidence_dir.mkdir(parents=True)
    controls: list[dict[str, str]] = []

    (protocol, coverage, previous_protocol, previous_coverage,
     source_resolution) = \
        verify_protocol_and_map(root, protocol_path, previous_protocol_path)
    tester_source_path = Path(__file__).resolve()
    tester_source_receipt = file_receipt(root, tester_source_path)
    require(tester_source_receipt["path"] not in protocol["inputs"],
            "tester-owned checker unexpectedly entered frozen input closure")
    pins_before = verify_current_input_pins(root, protocol)
    builder_result = verify_builder_and_driver(root, protocol, controls)
    controller_route_result = verify_controller_projection_route(root, protocol)
    diff_result = verify_projection_validator_diff(
        root, protocol, previous_protocol)
    projection_commands = run_projection_validators(
        root, protocol_path, previous_protocol, protocol, evidence_dir)
    pins_after = verify_current_input_pins(root, protocol)
    require(pins_before == pins_after,
            "protocol input pins changed during independent static checks")

    result: dict[str, Any] = {
        "schema": "vnext-t2-independent-attempt9c-final-r4r5-static-test-r3",
        "status": "pass_static_not_executed",
        "formal_t2_accepted": False,
        "julia_started": False,
        "command_argv": sys.argv,
        "python_version": sys.version,
        "protocol": file_receipt(root, protocol_path),
        "previous_protocol": file_receipt(root, previous_protocol_path),
        "tester_source": tester_source_receipt,
        "coverage_map": protocol["coverage_map"],
        "site_source_text_resolution": source_resolution,
        "coverage_contract": {
            "formal_actual_case_count": 45,
            "formal_phase_order": EXPECTED_FORMAL_PHASES,
            "case_count": coverage["successor_case_count"],
            "site_count": coverage["successor_assertion_site_count"],
            "planned_runtime_hits":
                coverage["successor_expected_runtime_hit_count"],
            "relocation": {
                "rows": len(protocol["attempt7_coverage_comparison"][
                    "path_line_relocation_ledger"]["entries"]),
                "path_changed": protocol["attempt7_coverage_comparison"][
                    "path_line_relocation_ledger"]["path_changed_site_count"],
                "line_delta_nonzero": protocol[
                    "attempt7_coverage_comparison"][
                        "path_line_relocation_ledger"][
                            "line_changed_site_count"],
                "path_unchanged": sum(
                    row.get("path_changed") is False for row in
                    protocol["attempt7_coverage_comparison"][
                        "path_line_relocation_ledger"]["entries"])},
            "exact_attempt8_projection_match": coverage == previous_coverage,
        },
        "projection24_plan": protocol["projection24_reuse"],
        "argv_contract": builder_result,
        "controller_projection_route": controller_route_result,
        "projection_validator_r3_to_r4_diff": diff_result,
        "projection_validator_cli": projection_commands,
        "negative_controls": controls,
        "input_pin_audit_before": {
            "input_count": pins_before["input_count"],
            "input_set_sha256": pins_before["input_set_sha256"]},
        "input_pin_audit_after": {
            "input_count": pins_after["input_count"],
            "input_set_sha256": pins_after["input_set_sha256"]},
        "no_runtime_execution_claim":
            "Python-only static contract and projection CLI checks; no Julia",
    }
    result_path = evidence_dir / "independent_static_result.json"
    result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8", newline="\n")
    print("T2_INDEPENDENT_ATTEMPT9C_FINAL_R4R5_STATIC_R3=PASS "
          f"formal_cases=45 sites=214 planned_hits=622 "
          f"shards={len(EXPECTED_SHARD_MODES)} "
          f"negative_controls={len(controls)}")
    print(f"EVIDENCE={result_path.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
