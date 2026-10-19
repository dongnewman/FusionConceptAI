from __future__ import annotations

import ast
import hashlib
import json
import sys
import traceback
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[5]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
ARCHIVE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2"
)
RUNTIME = ARCHIVE / "actual_negative_execution_r3"
RESULT_DIR = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt8_final2_argv_arity_20260923_r1"
)
PROTOCOL_SHA256 = "4ad2c2448c8fe406fd05877ee8acbcd81acb10227fe598d8a5f0d0e118ca3ee4"
MAP_SHA256 = "59442e71116459b9de143d8edcfe451a6c1fbf8ad09187b89ba5fdd3b1a3af27"
CONTROLLER_SHA256 = "1c8dedba22f2f4f327dca30f2c92f36bf70cfe35fce398445e8325707744ed16"
DRIVER_SHA256 = "e1e2946c960da8c4220e66896ae4dc89202e6ef9394d2d0c0d8853bab86c2c1e"
SHARD_PHASES = [
    ("actual_formal_preflight", "preflight"),
    ("actual_formal_authority", "authority"),
    ("actual_formal_fault_n10", "fault_n10"),
    ("actual_formal_t1_handoff", "t1_handoff"),
]
PASS_MARKER = "T2_DRIVER_ARGV_ARITY=EXPECTED_DEFECT_CONFIRMED"


class ContractFailure(AssertionError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractFailure(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path, relative: str | None = None) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "path": relative if relative is not None else path.as_posix(),
        "bytes": len(data),
        "sha256": sha256(data),
    }


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"expected JSON object: {path}")
    return value


def assigned_value(tree: ast.AST, name: str) -> ast.AST:
    matches = []
    for node in ast.walk(tree):
        if not isinstance(node, (ast.Assign, ast.AnnAssign)):
            continue
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        value = node.value
        if value is None:
            continue
        if any(isinstance(target, ast.Name) and target.id == name
               for target in targets):
            matches.append(value)
    require(len(matches) == 1,
            f"controller assignment must be unique: {name} ({len(matches)})")
    return matches[0]


def assigned_run_phase(tree: ast.AST, target_name: str) -> ast.Call:
    matches = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == target_name
                   for target in node.targets):
            continue
        if isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) \
                and node.value.func.id == "run_phase":
            matches.append(node.value)
    require(len(matches) == 1,
            f"run_phase assignment must be unique: {target_name}")
    return matches[0]


def static_driver_args_expression(call: ast.Call, label: str) -> tuple[list[ast.AST], list[ast.AST]]:
    require(len(call.args) >= 2, f"{label} run_phase lacks a command argument")
    expression = call.args[1]
    parts: list[ast.AST] = []

    def flatten(node: ast.AST) -> None:
        if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Add):
            flatten(node.left)
            flatten(node.right)
        else:
            parts.append(node)

    flatten(expression)
    require(len(parts) == 3 and
            isinstance(parts[0], ast.Name) and parts[0].id == "julia_common" and
            isinstance(parts[1], ast.Name) and parts[1].id == "actual_common" and
            isinstance(parts[2], ast.List),
            f"{label} command expression shape changed")
    return parts, parts[2].elts


def count_driver_args(elements: list[ast.AST], authority_count: int) -> int:
    count = 0
    for element in elements:
        if isinstance(element, ast.Starred):
            require(isinstance(element.value, ast.Name) and
                    element.value.id == "actual_authorities",
                    "unexpected starred driver argument list")
            count += authority_count
        else:
            count += 1
    return count


def validate_driver_args(args: list[str], map_path: str,
                         map_sha256: str, modes: set[str]) -> bool:
    return (len(args) == 16 and args[0] in modes and
            args[14] == map_path and args[15] == map_sha256)


def record_control(controls: list[dict[str, Any]], name: str,
                   accepted: bool, expected_acceptance: bool) -> None:
    require(accepted is expected_acceptance,
            f"argv arity control had unexpected result: {name}")
    controls.append({
        "name": name,
        "status": "pass",
        "accepted": accepted,
        "expected_acceptance": expected_acceptance,
    })


def main() -> int:
    result: dict[str, Any] = {
        "schema": "vnext-t2-independent-driver-argv-arity-r1",
        "tester_status": "fail",
        "implementation_status": "unassessed",
        "julia_started_by_tester": False,
        "formal_t2_accepted": False,
        "negative_controls": [],
    }
    stdout = b""
    stderr = b""
    try:
        require(not RESULT_DIR.exists(), f"evidence leaf already exists: {RESULT_DIR}")
        protocol_path = ARCHIVE / "protocol.json"
        map_path = ARCHIVE / "coverage_map_r3.json"
        controller_path = ROOT / (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "independent_negative_controller_r3.py"
        )
        driver_path = ROOT / (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "actual_formal_negative_driver_r3.jl"
        )
        protocol = load_json(protocol_path)
        controller_source = controller_path.read_text(encoding="utf-8")
        driver_source = driver_path.read_text(encoding="utf-8")
        controller_sha = sha256(controller_source.encode("utf-8"))
        driver_sha = sha256(driver_source.encode("utf-8"))
        protocol_sha = sha256(protocol_path.read_bytes())
        map_sha = sha256(map_path.read_bytes())
        require(protocol_sha == PROTOCOL_SHA256 and map_sha == MAP_SHA256,
                "attempt8_final2 protocol or coverage map hash drifted")
        require(controller_sha == CONTROLLER_SHA256 and driver_sha == DRIVER_SHA256,
                "attempt8_final2 controller or driver source hash drifted")
        require(protocol["inputs"].get(protocol["controller_path"]) ==
                receipt(controller_path, protocol["controller_path"]) and
                protocol["inputs"].get(protocol["driver_path"]) ==
                receipt(driver_path, protocol["driver_path"]),
                "driver/controller are not the exact frozen protocol inputs")
        require(protocol["coverage_map"]["sha256"] == MAP_SHA256 and
                protocol["coverage_map"]["path"] ==
                "docs/implementation/UP1-04A-VNEXT-T2/archive/"
                "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2/"
                "coverage_map_r3.json",
                "protocol coverage map receipt differs from frozen map")

        controller_tree = ast.parse(controller_source)
        julia_common = assigned_value(controller_tree, "julia_common")
        actual_common = assigned_value(controller_tree, "actual_common")
        actual_authorities = assigned_value(controller_tree, "actual_authorities")
        shards_node = assigned_value(controller_tree, "actual_shards")
        require(isinstance(julia_common, ast.List) and len(julia_common.elts) == 5 and
                isinstance(actual_common, ast.List) and len(actual_common.elts) == 1 and
                isinstance(actual_authorities, ast.List) and
                len(actual_authorities.elts) == 8,
                "controller Julia prefix/driver/authority argument shapes changed")
        require(ast.literal_eval(shards_node) == tuple(SHARD_PHASES),
                "controller no longer enumerates the exact four formal shard modes")

        baseline_call = assigned_run_phase(controller_tree, "baseline_phase")
        baseline_parts, baseline_elements = static_driver_args_expression(
            baseline_call, "baseline")
        baseline_static_count = count_driver_args(
            baseline_elements, len(actual_authorities.elts))
        baseline_source_text = ast.unparse(baseline_elements)
        require(baseline_static_count == 16 and
                "coverage_map" in baseline_source_text and
                "coverage_map_sha256" in baseline_source_text,
                "baseline source command does not pass map path and SHA after 14")

        shard_call = assigned_run_phase(controller_tree, "shard_phase")
        shard_parts, shard_elements = static_driver_args_expression(
            shard_call, "four-shard")
        shard_static_count = count_driver_args(
            shard_elements, len(actual_authorities.elts))
        shard_source_text = ast.unparse(shard_elements)
        require(shard_static_count == 14 and "coverage_map" not in shard_source_text and
                "coverage_map_sha256" not in shard_source_text,
                "expected frozen shard omission was not found (map path/hash)")

        for name, elements in (("baseline", baseline_elements),
                               ("four-shard-loop", shard_elements)):
            require(elements[0] == (
                baseline_elements[0] if name == "baseline" else shard_elements[0]
            ), f"{name} mode field disappeared")

        driver_contract = (
            "length(ARGS) == 16" in driver_source and
            "ARGS[14]" in driver_source and
            "ARGS[15]" in driver_source and
            "ARGS[16]" in driver_source and
            "T2_NEG_COVERAGE_MAP_PATH = abspath(ARGS[15])" in driver_source and
            "T2_NEG_COVERAGE_MAP_SHA256 = lowercase(ARGS[16])" in driver_source
        )
        require(driver_contract, "r3 driver no longer requires 16 args/map receipt")

        runtime_baseline = load_json(RUNTIME / "actual_formal_baseline/phase.json")
        runtime_preflight = load_json(RUNTIME / "actual_formal_preflight/phase.json")
        baseline_command = runtime_baseline["command"]
        preflight_command = runtime_preflight["command"]
        driver_absolute = str(driver_path)
        require(baseline_command.count(driver_absolute) == 1 and
                preflight_command.count(driver_absolute) == 1,
                "runtime phase command does not identify one r3 driver")
        baseline_args = baseline_command[baseline_command.index(driver_absolute) + 1:]
        preflight_args = preflight_command[preflight_command.index(driver_absolute) + 1:]
        map_absolute = str(map_path)
        require(validate_driver_args(
                    baseline_args, map_absolute, MAP_SHA256,
                    {"baseline", *(mode for _, mode in SHARD_PHASES)}),
                "executed baseline command does not satisfy the 16-argument contract")
        require(runtime_baseline.get("name") == "actual_formal_baseline" and
                runtime_baseline.get("exit_code") == 0 and
                runtime_baseline.get("stop_reason") == "natural_exit" and
                len(baseline_args) == 16,
                "baseline actual execution receipt is not a natural 16-arg pass")

        preflight_stderr_path = RUNTIME / "actual_formal_preflight/stderr.raw"
        preflight_stderr = preflight_stderr_path.read_bytes().decode(
            "utf-8", "replace")
        require(runtime_preflight.get("name") == "actual_formal_preflight" and
                runtime_preflight.get("exit_code") == 1 and
                runtime_preflight.get("stop_reason") == "natural_exit" and
                len(preflight_args) == 14 and preflight_args[0] == "preflight" and
                MAP_SHA256 not in preflight_args and map_absolute not in preflight_args and
                "expected mode, four authority path/hash pairs, context path/hash, "
                "authorization path/hash, output dir, coverage map path/hash"
                in preflight_stderr,
                "observed preflight failure does not match 14-arg missing-map defect")
        pipeline_path = RUNTIME / "pipeline_final.json"
        pipeline = load_json(pipeline_path)
        require(pipeline.get("status") == "fail" and
                pipeline.get("failure", {}).get("message") ==
                "actual_formal_preflight exit=1" and
                pipeline.get("formal_t2_accepted") is False and
                pipeline.get("assertion_site_runtime_hits_observed") is None and
                pipeline.get("actual_source_site_hits") is None,
                "pipeline output does not preserve preflight failure/no-hit state")
        unrun_shard_receipts = [phase for phase, _ in SHARD_PHASES[1:]
                                if not (RUNTIME / phase / "phase.json").exists()]
        require(unrun_shard_receipts == [phase for phase, _ in SHARD_PHASES[1:]],
                "later shard phases unexpectedly have execution receipts")

        controls: list[dict[str, Any]] = []
        modes = {"baseline", *(mode for _, mode in SHARD_PHASES)}
        record_control(controls, "actual baseline command accepted at 16 args",
                       validate_driver_args(baseline_args, map_absolute,
                                            MAP_SHA256, modes), True)
        record_control(controls, "actual preflight command rejected at 14 args",
                       validate_driver_args(preflight_args, map_absolute,
                                            MAP_SHA256, modes), False)
        baseline_truncated = baseline_args[:-2]
        record_control(controls, "baseline with coverage pair removed rejected",
                       validate_driver_args(baseline_truncated, map_absolute,
                                            MAP_SHA256, modes), False)
        record_control(controls, "16 args with wrong map SHA rejected",
                       validate_driver_args(
                           baseline_args[:-1] + ["0" * 64], map_absolute,
                           MAP_SHA256, modes), False)
        record_control(controls, "16 args with wrong map path rejected",
                       validate_driver_args(
                           baseline_args[:-2] + ["wrong-coverage.json", MAP_SHA256],
                           map_absolute, MAP_SHA256, modes), False)

        shard_control_rows = []
        for phase, mode in SHARD_PHASES:
            current_template = [mode, *baseline_args[1:13],
                                str(RUNTIME / phase / "artifacts")]
            require(len(current_template) == shard_static_count == 14,
                    f"static command arity disagrees for {phase}")
            record_control(controls, f"current {mode} shard rejected at 14 args",
                           validate_driver_args(current_template, map_absolute,
                                                MAP_SHA256, modes), False)
            repaired_shape = current_template + [map_absolute, MAP_SHA256]
            record_control(controls, f"{mode} shard shape accepted at 16 args",
                           validate_driver_args(repaired_shape, map_absolute,
                                                MAP_SHA256, modes), True)
            shard_control_rows.append({
                "phase": phase,
                "mode": mode,
                "controller_source_argv_arity": shard_static_count,
                "coverage_map_path_arg_present": False,
                "coverage_map_sha256_arg_present": False,
                "would_match_driver": False,
                "synthetic_corrected_shape_arity": len(repaired_shape),
                "synthetic_corrected_shape_matches_driver": True,
                "execution_receipt": "not_reached_after_preflight_exit_1",
            })

        require(len(controls) == 13 and all(row["status"] == "pass"
                                             for row in controls),
                "independent argv arity mutation suite did not pass")
        result.update({
            "tester_status": "pass_expected_defect_confirmed",
            "implementation_status": "NO_GO",
            "driver_expected_argv_arity": 16,
            "baseline_controller_source_argv_arity": baseline_static_count,
            "baseline_actual_execution": {
                "driver_args": len(baseline_args),
                "exit_code": runtime_baseline["exit_code"],
                "stop_reason": runtime_baseline["stop_reason"],
                "phase_receipt": receipt(
                    RUNTIME / "actual_formal_baseline/phase.json",
                    "actual_negative_execution_r3/actual_formal_baseline/phase.json"),
            },
            "preflight_actual_execution": {
                "driver_args": len(preflight_args),
                "exit_code": runtime_preflight["exit_code"],
                "stop_reason": runtime_preflight["stop_reason"],
                "failure": "driver expected 16 args; controller supplied 14",
                "stderr_receipt": receipt(
                    preflight_stderr_path,
                    "actual_negative_execution_r3/actual_formal_preflight/stderr.raw"),
                "phase_receipt": receipt(
                    RUNTIME / "actual_formal_preflight/phase.json",
                    "actual_negative_execution_r3/actual_formal_preflight/phase.json"),
            },
            "four_shard_source_commands": shard_control_rows,
            "later_shards_executed": False,
            "unrun_shard_phases": unrun_shard_receipts,
            "pipeline_final": {
                "status": pipeline["status"],
                "failure": pipeline["failure"],
                "formal_t2_accepted": pipeline["formal_t2_accepted"],
                "actual_source_site_hits": pipeline["actual_source_site_hits"],
                "assertion_site_runtime_hits_observed":
                    pipeline["assertion_site_runtime_hits_observed"],
                "receipt": receipt(
                    pipeline_path, "actual_negative_execution_r3/pipeline_final.json"),
            },
            "negative_controls": controls,
            "tested_artifacts": {
                "protocol": receipt(protocol_path, "protocol.json"),
                "coverage_map": receipt(map_path, "coverage_map_r3.json"),
                "controller": receipt(controller_path, protocol["controller_path"]),
                "driver": receipt(driver_path, protocol["driver_path"]),
                "test_source": receipt(
                    Path(__file__).resolve(),
                    Path(__file__).resolve().relative_to(ROOT).as_posix()),
            },
            "actual_model_attestation": "unavailable",
        })
        stdout = (
            f"{PASS_MARKER} baseline=16 preflight=14 "
            "shards=14,14,14,14 negative_controls=13 implementation=NO_GO\n"
        ).encode("ascii")
    except Exception as error:
        result["tester_status"] = "fail"
        result["implementation_status"] = "NO_GO"
        result["failure"] = {"type": type(error).__name__, "message": str(error)}
        stderr = traceback.format_exc().encode("utf-8")
        stdout = b"T2_DRIVER_ARGV_ARITY=CHECKER_FAILURE\n"

    RESULT_DIR.mkdir(parents=True, exist_ok=False)
    command_data = {
        "schema": "vnext-t2-independent-driver-argv-arity-command-r1",
        "kind": "non_executable_command_data",
        "argv": [sys.executable, "-B", str(Path(__file__).resolve())],
        "working_directory": str(ROOT),
        "julia_started": False,
        "actual_model_attestation": "unavailable",
    }
    (RESULT_DIR / "command_argv.json").write_text(
        json.dumps(command_data, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (RESULT_DIR / "independent_argv_arity_result.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (RESULT_DIR / "stdout.raw").write_bytes(stdout)
    (RESULT_DIR / "stderr.raw").write_bytes(stderr)
    sys.stdout.buffer.write(stdout)
    sys.stderr.buffer.write(stderr)
    return 0 if result["tester_status"] == "pass_expected_defect_confirmed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
