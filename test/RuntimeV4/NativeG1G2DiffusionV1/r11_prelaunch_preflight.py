"""Python-only verifier for the frozen Native G1/G2 r11 launch contract.

This program must pass before any Julia stage is started.  It checks the exact
r10 source baseline, the one-file diagnostic test delta, every current source
pin, and the complete supervisor/Julia argv recorded in the protocol.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sys
from typing import Any

import psutil


R10_BASELINE_SHA256 = "eefb6b07e8d1a4d7ca67bcfe63a21e0c506adce2182124e579a06ee994a6d7bf"
R10_PARSE_MANIFEST_SHA256 = "4abb91920481650c5fb7b6d8da6f2f4369dd9880c40e4a52735f939ccfada2f5"
R10_PROTOCOL_SHA256 = "ab22013fa088cc6d68bcc175efcd5be8670ec1a0eee10663f5bdf0e6c543b1ae"
R10_BASELINE_PIN_COUNT = 115
R10_JULIA_SOURCE_COUNT = 108
R11_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r11.py"
R11_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r11_precompile.jl"
R10_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests.jl"
R11_PREFLIGHT = "test/RuntimeV4/NativeG1G2DiffusionV1/r11_prelaunch_preflight.py"
R11_PREFLIGHT_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_r11_prelaunch_preflight.py"
R10_PROTOCOL_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
    "independent_r10_source_marker_review_20260923/frozen_protocol/protocol.json"
)
R10_MANIFEST_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
    "independent_r10_source_marker_review_20260923/frozen_protocol/static_preflight.json"
)
R10_PARSE_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
    "independent_r10_source_marker_review_20260923/frozen_protocol/parse_manifest.tsv"
)
EVIDENCE_ROOT_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/"
    "archive/native_g1g2_precompile_r11_v1"
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def under(root: Path, value: str, label: str) -> Path:
    path = Path(value).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as error:
        raise ValueError(f"{label} escapes repository root: {value}") from error
    return path


def manifest_rows(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        pieces = line.split("\t", 1)
        require(len(pieces) == 2, f"malformed parse manifest line {line_number}")
        digest, relative = pieces
        require(relative not in rows, f"duplicate parse manifest path: {relative}")
        require(len(digest) == 64, f"malformed SHA-256 at parse line {line_number}")
        rows[relative] = digest.lower()
    return rows


def load_runner(path: Path) -> Any:
    spec = importlib.util.spec_from_file_location("_native_g1g2_r11_runner", path)
    require(spec is not None and spec.loader is not None, "cannot load pinned r11 runner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def verify_parent_invocation(
    expected: list[str], mode: str, preparation_output: Path,
    planned_output: Path, julia: str, runner_path: Path,
    evidence_root: Path,
    observed_parent_argv: list[str] | None = None,
) -> list[str]:
    parent = psutil.Process(os.getppid())
    observed = parent.cmdline() if observed_parent_argv is None else observed_parent_argv
    require(observed == expected,
        "prelaunch parent command line differs from frozen actual_invocation_argv")
    require(len(expected) >= 6, "supervisor argv is too short")
    require(Path(expected[0]).resolve() == Path(sys.executable).resolve(),
        "supervisor interpreter differs from this Python runtime")
    require(expected[1] == "-B", "supervisor must use Python -B")
    require(Path(expected[2]).resolve() == runner_path.resolve(),
        "supervisor script path is not the pinned r11 runner")
    args = expected[3:]
    require(args.count("--output") == 1 and args.count("--julia") == 1,
        "supervisor must provide exactly one --output and --julia")
    output_arg = args[args.index("--output") + 1]
    julia_arg = args[args.index("--julia") + 1]
    output_path = Path(output_arg)
    if not output_path.is_absolute():
        output_path = evidence_root / output_path
    require(output_path.resolve() == preparation_output.resolve(),
        "supervisor --output does not resolve to the preparation/current leaf")
    require(Path(julia_arg).resolve() == Path(julia).resolve(),
        "supervisor --julia differs from the resolved pinned Julia executable")
    static_only = "--static-only" in args
    require(static_only == (mode == "static_only"),
        "supervisor --static-only flag disagrees with recorded run mode")
    if mode == "static_only":
        require(args.count("--planned-output") == 1,
            "static preparation requires exactly one --planned-output")
        planned_arg = args[args.index("--planned-output") + 1]
        planned_arg_path = Path(planned_arg)
        if not planned_arg_path.is_absolute():
            planned_arg_path = evidence_root / planned_arg_path
        require(planned_arg_path.resolve() == planned_output.resolve(),
            "supervisor --planned-output differs from frozen actual output")
    else:
        require("--planned-output" not in args,
            "actual supervisor argv must not include --planned-output")
        require(preparation_output.resolve() == planned_output.resolve(),
            "actual run output and planned output differ")
    return observed


def verify_protocol(
    protocol_path: Path,
    static_path: Path,
    baseline_manifest_path: Path,
    baseline_parse_manifest_path: Path,
    baseline_protocol_path: Path,
    *,
    observed_parent_argv: list[str] | None = None,
) -> dict[str, Any]:
    protocol_path = protocol_path.resolve()
    static_path = static_path.resolve()
    repo_root = Path.cwd().resolve()
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    static = json.loads(static_path.read_text(encoding="utf-8"))
    require(protocol.get("schema") == "native-g1g2-gridap-recorded-protocol-r11-v1",
        "unexpected r11 protocol schema")
    require(protocol.get("run_revision") == "r11_precompile_marker_test_only",
        "unexpected r11 test-only revision")
    execution = protocol.get("execution_plan", {})
    preparation_output = under(repo_root, str(protocol.get("preparation_output", "")),
        "preparation output")
    planned_output = under(repo_root, str(execution.get("planned_actual_output", "")),
        "planned actual output")
    evidence_root = (repo_root / EVIDENCE_ROOT_REL).resolve()
    for label, path in (("preparation output", preparation_output),
                        ("planned actual output", planned_output)):
        try:
            path.relative_to(evidence_root)
        except ValueError as error:
            raise ValueError(f"{label} is outside the owned r11 archive") from error
    mode = protocol.get("run_mode")
    require(mode in {"static_only", "actual"}, "protocol run_mode is invalid")
    require(execution.get("runtime_executed") is (mode == "actual"),
        "runtime_executed disagrees with run_mode")
    require(protocol_path.parent.resolve() == preparation_output,
        "protocol path does not match its preparation output leaf")
    require(static_path == preparation_output / "static_preflight.json",
        "static preflight path does not match the output leaf")
    if mode == "static_only":
        require(preparation_output != planned_output,
            "static-only evidence and future runtime output must be distinct")
        require(not planned_output.exists(), "planned actual output leaf already exists")
    else:
        require(preparation_output == planned_output,
            "actual run output must equal planned actual output")

    for path, digest, label in (
        (baseline_manifest_path, R10_BASELINE_SHA256, "r10 static baseline"),
        (baseline_parse_manifest_path, R10_PARSE_MANIFEST_SHA256, "r10 parse manifest"),
        (baseline_protocol_path, R10_PROTOCOL_SHA256, "r10 protocol"),
    ):
        require(path.is_file() and sha256_file(path) == digest,
            f"{label} hash differs from frozen r10")
    require(baseline_manifest_path.resolve() == (repo_root / R10_MANIFEST_REL).resolve(),
        "r10 baseline manifest path is unexpected")
    require(baseline_parse_manifest_path.resolve() == (repo_root / R10_PARSE_REL).resolve(),
        "r10 parse manifest path is unexpected")
    require(baseline_protocol_path.resolve() == (repo_root / R10_PROTOCOL_REL).resolve(),
        "r10 protocol path is unexpected")
    expected_baseline = {
        "static_preflight_path": str(baseline_manifest_path.resolve()),
        "static_preflight_sha256": R10_BASELINE_SHA256,
        "parse_manifest_path": str(baseline_parse_manifest_path.resolve()),
        "parse_manifest_sha256": R10_PARSE_MANIFEST_SHA256,
        "protocol_path": str(baseline_protocol_path.resolve()),
        "protocol_sha256": R10_PROTOCOL_SHA256,
        "pinned_input_count": R10_BASELINE_PIN_COUNT,
    }
    require(protocol.get("r10_baseline") == expected_baseline and
        static.get("r10_baseline") == expected_baseline,
        "r11 candidate does not bind the exact frozen r10 baseline inputs")

    baseline_manifest = json.loads(baseline_manifest_path.read_text(encoding="utf-8"))
    baseline_dependencies = baseline_manifest.get("dependencies")
    require(isinstance(baseline_dependencies, dict) and
        len(baseline_dependencies) == R10_BASELINE_PIN_COUNT,
        "r10 baseline must contain exactly 115 pinned inputs")
    current_dependencies = static.get("dependencies")
    require(isinstance(current_dependencies, dict),
        "r11 static preflight dependencies are missing")
    mismatches: list[str] = []
    for relative, expected in baseline_dependencies.items():
        require(relative in current_dependencies,
            f"r11 snapshot dropped an r10 pinned input: {relative}")
        require(current_dependencies[relative] == expected,
            f"r11 snapshot changed frozen r10 pin: {relative}")
    for relative, expected in current_dependencies.items():
        path = under(repo_root, relative, "dependency pin")
        if not path.is_file():
            mismatches.append(relative + ":missing")
            continue
        actual = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        if actual != expected:
            mismatches.append(relative)
    require(not mismatches, "source/dependency pins changed: " + ", ".join(mismatches))
    require(len(current_dependencies) >= R10_BASELINE_PIN_COUNT,
        "r11 snapshot does not contain the complete r10 input set")

    baseline_protocol = json.loads(baseline_protocol_path.read_text(encoding="utf-8"))
    require(protocol.get("numerical_protocol") == baseline_protocol.get("numerical_protocol"),
        "r11 numerical fixtures or thresholds differ from frozen r10 protocol")
    require(protocol.get("stage_order") == baseline_protocol.get("stage_order") ==
        ["parse_all", "primary", "fresh_replay"],
        "r11 stage order differs from r10")
    require(protocol.get("limits_per_julia_stage") == baseline_protocol.get("limits_per_julia_stage"),
        "r11 hard wall/RSS/thread limits differ from r10")
    require(protocol["limits_per_julia_stage"] == {
        "wall_seconds": 300.0,
        "whole_process_tree_rss_bytes": 2_147_483_648,
        "julia_threads": 1,
        "blas_threads": 1,
    }, "r11 hard 300s/2GiB gate or thread limits changed")
    memory = protocol.get("memory_observability", {})
    require(memory.get("julia_heap_size_hint") == "1G" and
        memory.get("julia_heap_size_hint_bytes") == 1_073_741_824 and
        memory.get("whole_tree_rss_hard_cap_bytes") == 2_147_483_648 and
        memory.get("forced_gc_at_markers") is False,
        "r11 GC hint or unchanged hard RSS gate is invalid")

    baseline_rows = manifest_rows(baseline_parse_manifest_path)
    require(len(baseline_rows) == R10_JULIA_SOURCE_COUNT,
        "frozen r10 Julia parse manifest does not contain 108 sources")
    parse_info = protocol.get("parse_manifest", {})
    current_parse_path = preparation_output / "parse_manifest.tsv"
    require(current_parse_path.is_file(), "r11 parse manifest is missing")
    current_parse_hash = sha256_file(current_parse_path)
    require(parse_info.get("sha256") == current_parse_hash and
        parse_info.get("bytes") == current_parse_path.stat().st_size and
        parse_info.get("entries") == R10_JULIA_SOURCE_COUNT,
        "r11 parse manifest receipt does not match its bytes")
    current_rows = manifest_rows(current_parse_path)
    expected_rows = dict(baseline_rows)
    expected_rows.pop(R10_TEST, None)
    expected_rows[R11_TEST] = current_dependencies[R11_TEST]["sha256"]
    require(current_rows == expected_rows,
        "r11 parse inputs must equal r10's 108 files with only the focused test version replaced")
    for relative, digest in current_rows.items():
        require(relative in current_dependencies and
            current_dependencies[relative]["sha256"] == digest,
            f"parse manifest disagrees with pinned dependency: {relative}")

    for relative in (
        "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl",
        "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
        "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl",
        R10_TEST,
    ):
        require(current_dependencies.get(relative) == baseline_dependencies.get(relative),
            f"r11 changed frozen solver/fixture input: {relative}")
    old_test = (repo_root / R10_TEST).read_text(encoding="utf-8")
    new_test = (repo_root / R11_TEST).read_text(encoding="utf-8")
    dispatch = 'ng12_stage("dispatch.before"; detail="mode=" * mode)\n'
    require(old_test.count(dispatch) == new_test.count(dispatch) == 1,
        "r10/r11 focused test dispatch marker is ambiguous")
    require(old_test.split(dispatch, 1)[0] == new_test.split(dispatch, 1)[0],
        "r11 changed fixture/test body before the diagnostic dispatch")
    for token in (
        'ng12_stage("precompile.before"',
        "precompile(ng12_primary, (String,))",
        "catch error",
        "precompile_exception = error",
        'ng12_stage("precompile.after"',
        "ng12_primary(artifact_path)",
        "ng12_replay(artifact_path)",
    ):
        require(token in new_test, f"r11 diagnostic marker/fallback is missing: {token}")
    precompile = protocol.get("precompile_diagnostic", {})
    require(precompile.get("request") == "precompile(ng12_primary, (String,))" and
        precompile.get("markers") == ["precompile.before", "precompile.after"] and
        precompile.get("numerical_thresholds_changed") is False and
        precompile.get("fixture_cases_or_mesh_levels_changed") is False and
        precompile.get("diagnostic_is_numerical_success") is False,
        "precompile diagnostic protocol is not test-only or changes frozen numerical scope")

    guard = protocol.get("prelaunch_guard", {})
    guard_path = repo_root / R11_PREFLIGHT
    require(guard.get("path") == R11_PREFLIGHT and guard_path.is_file(),
        "r11 prelaunch verifier path is not the owned Python-only verifier")
    require(guard.get("sha256") == sha256_file(guard_path) and
        current_dependencies.get(R11_PREFLIGHT, {}).get("sha256") == sha256_file(guard_path),
        "r11 prelaunch verifier is not source-pinned")
    require(guard.get("required_before_julia") is True and
        guard.get("implementation") == "python_only_no_julia_import_or_launch",
        "r11 prelaunch verifier policy is missing")
    expected_preflight_command = [
        str(Path(sys.executable).resolve()), "-B", str(guard_path.resolve()),
        "--protocol", str(protocol_path),
        "--static-preflight", str(static_path),
        "--baseline-manifest", str(baseline_manifest_path.resolve()),
        "--baseline-parse-manifest", str(baseline_parse_manifest_path.resolve()),
        "--baseline-protocol", str(baseline_protocol_path.resolve()),
    ]
    require(guard.get("command") == expected_preflight_command,
        "r11 preflight argv differs from frozen protocol/input paths")

    runner_path = (repo_root / R11_RUNNER).resolve()
    runner_module = load_runner(runner_path)
    julia = str(execution.get("julia_executable", {}).get("path", ""))
    julia_path = Path(julia).resolve()
    julia_receipt = execution.get("julia_executable", {})
    require(julia_path.is_file() and
        {"bytes": julia_path.stat().st_size, "sha256": sha256_file(julia_path)} ==
            {"bytes": julia_receipt.get("bytes"), "sha256": julia_receipt.get("sha256")},
        "Julia executable receipt does not match pinned bytes")
    expected_supervisor = runner_module.planned_supervisor_argv(planned_output, julia)
    require(execution.get("supervisor_argv") == expected_supervisor,
        "frozen supervisor argv differs from r11 canonical command construction")
    invocation = execution.get("actual_invocation_argv")
    require(isinstance(invocation, list) and all(isinstance(item, str) for item in invocation),
        "actual supervisor invocation argv is missing")
    if observed_parent_argv is None:
        observed_parent_argv = psutil.Process(os.getppid()).cmdline()
    require(observed_parent_argv == invocation,
        "observed supervisor command line differs from recorded invocation argv")
    require(Path(invocation[2]).resolve() == runner_path,
        "actual supervisor is not the r11 runner")
    require(Path(invocation[0]).resolve() == Path(sys.executable).resolve() and
        invocation[1] == "-B", "actual supervisor interpreter/-B argv differs")
    verify_parent_invocation(invocation, mode, preparation_output, planned_output,
        julia, runner_path, evidence_root, observed_parent_argv)
    expected_stages = [
        {"stage": name, "argv": command}
        for name, command in runner_module.planned_stage_commands(planned_output, julia)
    ]
    require(protocol.get("execution_plan", {}).get("stage_commands") == expected_stages,
        "frozen Julia stage argv does not match the r11 runner or actual output leaf")
    commands = [item["argv"] for item in expected_stages]
    require(commands[0][-2:] == [str(planned_output / "parse_manifest.tsv"), str(repo_root)],
        "parse stage source-manifest/root argv binding is wrong")
    expected_artifact = str(planned_output / "artifacts/primary.bin")
    require(commands[1][-2:] == ["primary", expected_artifact] and
        commands[2][-2:] == ["replay", expected_artifact],
        "primary/fresh replay do not bind the same artifact path")

    return {
        "schema": "native-g1g2-r11-prelaunch-preflight-receipt-v1",
        "status": "pass",
        "protocol_sha256": sha256_file(protocol_path),
        "static_preflight_sha256": sha256_file(static_path),
        "r10_baseline_pin_count": R10_BASELINE_PIN_COUNT,
        "r10_baseline_pins_preserved": True,
        "current_dependency_count": len(current_dependencies),
        "julia_source_count": R10_JULIA_SOURCE_COUNT,
        "actual_invocation_argv_exact": True,
        "canonical_future_supervisor_argv_exact": True,
        "all_julia_stage_argv_exact": True,
        "only_r11_parse_delta": R11_TEST,
        "fixture_and_numerical_protocol_unchanged": True,
        "hard_wall_seconds": 300.0,
        "hard_process_tree_rss_bytes": 2_147_483_648,
        "julia_started": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True, type=Path)
    parser.add_argument("--static-preflight", required=True, type=Path)
    parser.add_argument("--baseline-manifest", required=True, type=Path)
    parser.add_argument("--baseline-parse-manifest", required=True, type=Path)
    parser.add_argument("--baseline-protocol", required=True, type=Path)
    args = parser.parse_args()
    try:
        result = verify_protocol(
            args.protocol, args.static_preflight, args.baseline_manifest,
            args.baseline_parse_manifest, args.baseline_protocol,
        )
    except Exception as error:
        print(json.dumps({"status": "fail_closed", "error": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
