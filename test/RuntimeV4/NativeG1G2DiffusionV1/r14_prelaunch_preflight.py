"""Python-only verifier for the frozen Native G1/G2 r14 argv-role contract.

This program must pass before any Julia stage is started.  It checks the exact
r10 source baseline, the one-file diagnostic test delta, every current source
pin, and the mode-specific parent argv plus all Julia stage argv in the protocol.
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
R14_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14.py"
R14_JULIA_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl"
R10_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests.jl"
R14_PREFLIGHT = "test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight.py"
R14_PREFLIGHT_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_prelaunch_preflight.py"
R13_STATIC_PROTOCOL_REL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_static_v1/protocol.json"
)
R13_STATIC_PROTOCOL_SHA256 = "622cc2ad4bfa32917b0690e0ec268ac408108a2ba83727416273e8d3d64b49a1"

R10_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/protocol.json": "60d590bc83ab3465c71ce38a70096f9274937db9e7f2616f4bf5384caafa9446",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/summary.json": "1781213362b2894e1885492da7c30df1f127b3623ecf283700c77b57632eeb46",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/final.json": "f653af01048c39af84fbebae9aa71f8ecf23542c3f67a83514ccf5ad1d5abeb2",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/stdout.raw": "c4edca785554ec75726f37199f9c759a4f80c3154703b8c57019fd9f9c8290d3",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/agent_r1_20260922/runtime_r10_actual_r1/02_primary/samples.jsonl": "5f222225fcf59f51005c21a09809bdeb6449ef0e1fe82279532d171ae4efb2a8",
}
R11_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r11_grant_20260923/grant.json": "4cfefe298a13ea0399a9bc768125fefc411b0fe3954c85a67431fbe9901b4650",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r11_grant_20260923/observation.json": "f1202bbcb8171dd0d6583fb5117a6ced9681c5a4ba762fdbcb2715d136ce937e",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_static_v1/protocol.json": "fc1170e86a63ca71e16e0d530fff824bb1bec7d5317e0e91fd52d2fbd11c1e6f",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/protocol.json": "00ed4cccd1ae0d31ed56c5edab4044e836d8b4319b367e125cdb193b2d9a064d",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/summary.json": "868b6a2b027bfbd444f32e24771105e9f77d55ec3d847f27816ce76fd4e2ba85",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/final.json": "1c08baf96505a6309df7d4bba21e8a6c34963eadf5cf2c6a9fea819656a42413",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/stdout.raw": "4098aaa4c099ae88fedd9848c11baeffbadcff31149226e281f37c75d864b132",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r11_v1/r11_actual_v1/02_primary/samples.jsonl": "c4a2e104e8273a291691049496ddf00fea6469fa154bffac0e99f6c012d7e6da",
}
R12_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/protocol.json": "b89d676db9161d81a19aed9ac1f988bd0809bd69a3c9f382cbf4bd2984aba9e3",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/static_preflight.json": "bab5d91e0aeaff3d416e1c3a9166d2e30240807ae9c05ffbadf3054765b34855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_static_v2/parse_manifest.tsv": "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa",
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r12.py": "0f93760f1c80cb037d37e6d16d5db0dc44144a7cded75c7ab99d88854b4b1123",
    "test/RuntimeV4/NativeG1G2DiffusionV1/r12_prelaunch_preflight.py": "9098604b6963e45714be02c41583d65c2eee81590eadfc46e7442a5f1543f8e1",
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r12_prelaunch_preflight.py": "8e48449959243a313e56aed12a959fe7842e7f670974f392d12d35c580e6975d",
    "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r12_markers.jl": "7365639c802b3ff2ac5106bf368ea7ceea307afbe9bbfc78822907b186a99f78",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/protocol.json": "9bc491f79ceedb947957b3cd6ea442c632bd633d5cd5b171cb076861ca68d45e",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.stdout.raw": "acae313680dce3c7296ce930e451743b0f47ea6ff44aaa09272fd65455583c36",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_precompile_r12_v1/r12_actual_v1/prelaunch.exit.txt": "f1b2f662800122bed0ff255693df89c4487fbdcf453d3524a42d4ec20c3d9c04",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_native_r12_grant_20260923/grant.json": "b1cb769a76a9a982c082254a57f20bbcfd8de1bebe751d2ccd2e74a7e22d9716",
}
R12_PRIOR_FACTS = {
    "r12_prelaunch_setup_failure": {
        "status": "fail_closed",
        "prelaunch_exit_code": 1,
        "failure_class": "argv_identity_mismatch",
        "julia_started": False,
        "solver_run_observed": False,
        "argument_token_root_cause_claimed": False,
    },
}
R13_PRIOR_EVIDENCE_SHA256 = {
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_static_v1/protocol.json": "622cc2ad4bfa32917b0690e0ec268ac408108a2ba83727416273e8d3d64b49a1",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/protocol.json": "19a521ee7a7c59b44e6e379ccec32dcabeb9cb3081eeffc38ca28a8c0db02000",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/summary.json": "e0ebc5cfd90ac36f4249af1022a2f05277c3e9850816244ca63bbb40ce1a5044",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/final.json": "81fd260954e9cb0e6d76d8e337c044e9f812456c283c694be7a57d29538e14a0",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/stdout.raw": "2a61130c55dc3f7d6886092c406d876bb0a2430e1ae0403dace93a0c357d6595",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/stderr.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/samples.jsonl": "8f018ea7d4ae7e9f86b78229420f68d06d34b87f7b51d84207394b92810918af",
}
R13_PRIOR_FACTS = {
    "r13_primary_resource_failure": {
        "status": "process_tree_rss_limit",
        "outer_exit_code": 1,
        "stage_exit_code": 15,
        "stage_elapsed_seconds": 242.2365240000072,
        "peak_process_tree_rss_bytes": 2196549632,
        "hard_rss_limit_bytes": 2147483648,
        "over_limit_bytes": 49066984,
        "last_flushed_marker": "NG12_STAGE stage=precompile.before elapsed_ms=8456 gc_live_bytes=56114510 jit_total_bytes=48814 process_maxrss_bytes=517369856 gc_time_ns=204766300 detail=target=ng12_primary signature=(String,)",
        "precompile_return_observed": False,
        "primary_function_entry_observed": False,
        "solver_run_observed": False,
        "fresh_replay_executed": False,
        "parse_all_exit_code": 0,
        "parse_all_files": 108,
        "numerical_status": "not_established",
    },
}
PRIOR_RUN_FACTS = {
    "r10_first_call": {
        "status": "wall_timeout",
        "exit_code": 15,
        "elapsed_seconds": 300.30108749999636,
        "peak_process_tree_rss_bytes": 2014654464,
        "last_flushed_marker": "NG12_STAGE stage=dispatch.before elapsed_ms=16642",
        "function_body_entry_observed": False,
        "solver_run_observed": False,
    },
    "r11_explicit_precompile": {
        "status": "wall_timeout",
        "exit_code": 15,
        "elapsed_seconds": 300.51891890000115,
        "peak_process_tree_rss_bytes": 2102079488,
        "rss_limit_bytes": 2147483648,
        "rss_margin_bytes": 45404160,
        "peak_sample_elapsed_seconds": 147.04105659999914,
        "last_sample_elapsed_seconds": 300.232050300001,
        "last_sample_rss_bytes": 2029449216,
        "last_sample_cpu_user_seconds": 280.21875,
        "last_flushed_marker": "NG12_STAGE stage=precompile.before elapsed_ms=16649 target=ng12_primary signature=(String,)",
        "precompile_return_observed": False,
        "primary_function_entry_observed": False,
        "solver_run_observed": False,
        "fresh_replay_executed": False,
    },
}
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
    "archive/native_g1g2_prelaunch_r14_v1"
)
EXPECTED_ARGV_IDENTITY_CONTRACT = {
    "schema": "native-g1g2-argv-role-contract-v1",
    "runner_invocation_argv": "exact argv of the current r14 launcher process",
    "expected_runtime_supervisor_argv": "canonical actual-run supervisor command",
    "selected_expected_field_by_run_mode": {
        "static_only": "runner_invocation_argv",
        "actual": "expected_runtime_supervisor_argv",
    },
    "actual_mode_runner_invocation_must_equal_runtime_expected": True,
    "failure_diagnostic_fields": [
        "run_mode", "selected_expected_field", "expected_argv",
        "observed_parent_argv", "runner_invocation_argv",
        "expected_runtime_supervisor_argv", "protocol_path",
    ],
}
EXPECTED_COMPILER_STRATEGY = {
    "schema": "native-g1g2-compiler-resource-diagnostic-v1",
    "claim_scope": "compiler_resource_diagnostic",
    "mode": "--compile=min",
    "argv_delta_from_r13": "add exactly one --compile=min to each Julia stage argv",
    "precompile_marker_preserved": True,
    "numerical_fixtures_or_thresholds_changed": False,
    "hard_rss_limit_bytes_unchanged": 2_147_483_648,
    "rss_limit_is_hard_stop": True,
    "diagnostic_is_numerical_success": False,
    "numerical_status_predeclared": "not_established",
    "physical_status_predeclared": "unknown",
}


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
    spec = importlib.util.spec_from_file_location("_native_g1g2_r14_runner", path)
    require(spec is not None and spec.loader is not None, "cannot load pinned r14 runner")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ParentArgvIdentityMismatch(ValueError):
    def __init__(self, diagnostic: dict[str, Any]):
        self.diagnostic = diagnostic
        super().__init__(diagnostic["error"])


def verify_argv_identity(
    mode: str,
    runner_invocation_argv: list[str],
    expected_runtime_supervisor_argv: list[str],
    observed_parent_argv: list[str],
    protocol_path: Path,
) -> tuple[str, list[str]]:
    require(mode in {"static_only", "actual"}, "run mode is invalid for argv identity check")
    if mode == "static_only":
        selected_field = "runner_invocation_argv"
        expected = runner_invocation_argv
    else:
        selected_field = "expected_runtime_supervisor_argv"
        expected = expected_runtime_supervisor_argv
    observed_matches = observed_parent_argv == expected
    invocation_matches = (
        mode != "actual" or runner_invocation_argv == expected_runtime_supervisor_argv
    )
    if not observed_matches or not invocation_matches:
        raise ParentArgvIdentityMismatch({
            "status": "fail_closed",
            "error": "observed parent argv differs from selected expected argv",
            "run_mode": mode,
            "selected_expected_field": selected_field,
            "expected_argv": expected,
            "observed_parent_argv": observed_parent_argv,
            "runner_invocation_argv": runner_invocation_argv,
            "expected_runtime_supervisor_argv": expected_runtime_supervisor_argv,
            "observed_matches_expected": observed_matches,
            "runner_invocation_matches_runtime_expected": invocation_matches,
            "protocol_path": str(protocol_path.resolve()),
        })
    return selected_field, expected


def verify_parent_invocation(
    expected: list[str], mode: str, preparation_output: Path,
    planned_output: Path, julia: str, runner_path: Path,
    evidence_root: Path,
    observed_parent_argv: list[str] | None = None,
) -> list[str]:
    parent = psutil.Process(os.getppid())
    observed = parent.cmdline() if observed_parent_argv is None else observed_parent_argv
    require(len(expected) >= 6, "supervisor argv is too short")
    require(Path(expected[0]).resolve() == Path(sys.executable).resolve(),
        "supervisor interpreter differs from this Python runtime")
    require(expected[1] == "-B", "supervisor must use Python -B")
    require(Path(expected[2]).resolve() == runner_path.resolve(),
        "supervisor script path is not the pinned r14 runner")
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


def verify_compile_min_delta(
    candidate_stages: list[dict[str, Any]],
    r13_stages: list[dict[str, Any]],
    repo_root: Path,
    planned_output: Path,
) -> None:
    require(len(candidate_stages) == len(r13_stages) == 3,
        "r14/r13 stage command counts differ")
    old_output = (repo_root /
        "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
        "native_g1g2_prelaunch_r13_v1/r13_actual_v1").resolve()
    old_test = (repo_root /
        "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r12_markers.jl").resolve()
    new_test = (repo_root / R14_JULIA_TEST).resolve()
    for candidate, previous in zip(candidate_stages, r13_stages, strict=True):
        require(candidate.get("stage") == previous.get("stage"),
            "r14 stage names/order differ from r13")
        prior_argv = previous.get("argv")
        candidate_argv = candidate.get("argv")
        require(isinstance(prior_argv, list) and isinstance(candidate_argv, list),
            "r13/r14 stage argv is malformed")
        expected_argv = [
            token.replace(str(old_output), str(planned_output.resolve()))
                 .replace(str(old_test), str(new_test))
            for token in prior_argv
        ]
        require("--compile=min" not in expected_argv,
            "r13 parent stage unexpectedly already has compile=min")
        require(expected_argv.count("--threads=1") == 1,
            "r13 parent stage thread pin is ambiguous")
        expected_argv.insert(expected_argv.index("--threads=1") + 1, "--compile=min")
        require(candidate.get("argv") == expected_argv,
            f"r14 {candidate['stage']} argv differs from r13 by more than one compile-mode token")


def verify_compiler_strategy(strategy: dict[str, Any]) -> None:
    require(strategy == EXPECTED_COMPILER_STRATEGY,
        "r14 compiler strategy overstates claim or changes the frozen resource/numerical contract")


def verify_numerical_protocol_unchanged(
    candidate_protocol: dict[str, Any], baseline_protocol: dict[str, Any]
) -> None:
    require(candidate_protocol.get("numerical_protocol") ==
        baseline_protocol.get("numerical_protocol"),
        "r14 numerical fixtures or thresholds differ from frozen r10 protocol")


def verify_prior_run_lineage(protocol: dict[str, Any], repo_root: Path) -> None:
    expected = {
        "files": {
            **{path: digest for path, digest in R10_PRIOR_EVIDENCE_SHA256.items()},
            **{path: digest for path, digest in R11_PRIOR_EVIDENCE_SHA256.items()},
            **{path: digest for path, digest in R12_PRIOR_EVIDENCE_SHA256.items()},
            **{path: digest for path, digest in R13_PRIOR_EVIDENCE_SHA256.items()},
        },
        **PRIOR_RUN_FACTS,
        **R12_PRIOR_FACTS,
        **R13_PRIOR_FACTS,
    }
    require(protocol.get("prior_run_lineage") == expected,
        "r10/r11/r12/r13 prior run lineage facts or pins differ from frozen evidence")
    for relative, digest in expected["files"].items():
        path = under(repo_root, relative, "prior-run lineage")
        require(path.is_file() and sha256_file(path) == digest,
            f"prior-run lineage hash mismatch: {relative}")


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
    require(protocol.get("schema") == "native-g1g2-gridap-recorded-protocol-r14-v1",
        "unexpected r14 protocol schema")
    require(protocol.get("run_revision") == "r14_compile_min_resource_diagnostic_test_only",
        "unexpected r14 compiler-resource diagnostic revision")
    require(protocol.get("argv_identity_contract") == EXPECTED_ARGV_IDENTITY_CONTRACT,
        "r14 argv identity roles or failure diagnostics differ from the frozen contract")
    verify_prior_run_lineage(protocol, repo_root)
    r13_protocol_path = under(repo_root, R13_STATIC_PROTOCOL_REL,
        "r13 static protocol")
    require(r13_protocol_path.is_file() and
        sha256_file(r13_protocol_path) == R13_STATIC_PROTOCOL_SHA256,
        "r13 static protocol is not the pinned parent candidate")
    r13_protocol = json.loads(r13_protocol_path.read_text(encoding="utf-8"))
    execution = protocol.get("execution_plan", {})
    require("actual_invocation_argv" not in execution and "supervisor_argv" not in execution,
        "ambiguous legacy argv fields are forbidden by r14")
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
            raise ValueError(f"{label} is outside the owned r14 archive") from error
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
        "r14 candidate does not bind the exact frozen r10 baseline inputs")

    baseline_manifest = json.loads(baseline_manifest_path.read_text(encoding="utf-8"))
    baseline_dependencies = baseline_manifest.get("dependencies")
    require(isinstance(baseline_dependencies, dict) and
        len(baseline_dependencies) == R10_BASELINE_PIN_COUNT,
        "r10 baseline must contain exactly 115 pinned inputs")
    current_dependencies = static.get("dependencies")
    require(isinstance(current_dependencies, dict),
        "r14 static preflight dependencies are missing")
    mismatches: list[str] = []
    for relative, expected in baseline_dependencies.items():
        require(relative in current_dependencies,
            f"r14 snapshot dropped an r10 pinned input: {relative}")
        require(current_dependencies[relative] == expected,
            f"r14 snapshot changed frozen r10 pin: {relative}")
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
        "r14 snapshot does not contain the complete r10 input set")

    baseline_protocol = json.loads(baseline_protocol_path.read_text(encoding="utf-8"))
    verify_numerical_protocol_unchanged(protocol, baseline_protocol)
    require(protocol.get("stage_order") == baseline_protocol.get("stage_order") ==
        ["parse_all", "primary", "fresh_replay"],
        "r14 stage order differs from r10")
    r10_limits = baseline_protocol.get("limits_per_julia_stage", {})
    expected_r14_limits = dict(r10_limits)
    expected_r14_limits["wall_seconds"] = 480.0
    require(r10_limits == {
        "wall_seconds": 300.0,
        "whole_process_tree_rss_bytes": 2_147_483_648,
        "julia_threads": 1,
        "blas_threads": 1,
    }, "frozen r10 limits are not the expected 300s/2GiB baseline")
    require(protocol["limits_per_julia_stage"] == expected_r14_limits and
        protocol["limits_per_julia_stage"] == {
            "wall_seconds": 480.0,
            "whole_process_tree_rss_bytes": 2_147_483_648,
            "julia_threads": 1,
            "blas_threads": 1,
        }, "r14 retains the only per-stage wall time to 480s; 2GiB/thread gates remain")
    memory = protocol.get("memory_observability", {})
    require(memory.get("julia_heap_size_hint") == "1G" and
        memory.get("julia_heap_size_hint_bytes") == 1_073_741_824 and
        memory.get("whole_tree_rss_hard_cap_bytes") == 2_147_483_648 and
        memory.get("forced_gc_at_markers") is False,
        "r14 GC hint or unchanged hard RSS gate is invalid")
    verify_compiler_strategy(protocol.get("compiler_strategy", {}))

    baseline_rows = manifest_rows(baseline_parse_manifest_path)
    require(len(baseline_rows) == R10_JULIA_SOURCE_COUNT,
        "frozen r10 Julia parse manifest does not contain 108 sources")
    parse_info = protocol.get("parse_manifest", {})
    current_parse_path = preparation_output / "parse_manifest.tsv"
    require(current_parse_path.is_file(), "r14 parse manifest is missing")
    current_parse_hash = sha256_file(current_parse_path)
    require(parse_info.get("sha256") == current_parse_hash and
        parse_info.get("bytes") == current_parse_path.stat().st_size and
        parse_info.get("entries") == R10_JULIA_SOURCE_COUNT,
        "r14 parse manifest receipt does not match its bytes")
    current_rows = manifest_rows(current_parse_path)
    expected_rows = dict(baseline_rows)
    expected_rows.pop(R10_TEST, None)
    expected_rows[R14_JULIA_TEST] = current_dependencies[R14_JULIA_TEST]["sha256"]
    require(current_rows == expected_rows,
        "r14 parse inputs must equal r10's 108 files with only the focused test version replaced")
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
            f"r14 changed frozen solver/fixture input: {relative}")
    old_test = (repo_root / R10_TEST).read_text(encoding="utf-8")
    new_test = (repo_root / R14_JULIA_TEST).read_text(encoding="utf-8")
    dispatch = 'ng12_stage("dispatch.before"; detail="mode=" * mode)\n'
    require(old_test.count(dispatch) == new_test.count(dispatch) == 1,
        "r10/r12 focused test dispatch marker is ambiguous")
    function_entry_line = '    ng12_stage("primary.function.enter")\n'
    new_prefix = new_test.split(dispatch, 1)[0]
    require(new_prefix.count(function_entry_line) == 1 and
        new_test.count(function_entry_line) == 1,
        "r12 primary function-entry marker is missing or duplicated")
    function_header = "function ng12_primary(artifact_path::AbstractString)\n"
    require(new_test.index(function_header) + len(function_header) ==
        new_test.index(function_entry_line) <
        new_test.index('ng12_stage("primary.fixture.begin")'),
        "r12 primary entry marker is not the first function-body statement")
    require(old_test.split(dispatch, 1)[0] ==
        new_prefix.replace(function_entry_line, "", 1),
        "r14 changed no fixture/test body before dispatch beyond the one entry marker")
    for token in (
        'ng12_stage("precompile.before"',
        "precompile(ng12_primary, (String,))",
        "catch error",
        "precompile_exception = error",
        'ng12_stage("precompile.return"',
        'ng12_stage("precompile.exception"',
        'ng12_stage("precompile.after"',
        'ng12_stage("primary.function.enter")',
        "ng12_primary(artifact_path)",
        "ng12_replay(artifact_path)",
    ):
        require(token in new_test, f"r12 diagnostic marker/fallback is missing: {token}")
    precompile = protocol.get("precompile_diagnostic", {})
    require(precompile.get("request") == "precompile(ng12_primary, (String,))" and
        precompile.get("markers") == [
            "precompile.before", "precompile.return", "precompile.exception",
            "precompile.after", "primary.function.enter"
        ] and
        precompile.get("numerical_thresholds_changed") is False and
        precompile.get("fixture_cases_or_mesh_levels_changed") is False and
        precompile.get("diagnostic_is_numerical_success") is False,
        "precompile diagnostic protocol is not test-only or changes frozen numerical scope")

    guard = protocol.get("prelaunch_guard", {})
    guard_path = repo_root / R14_PREFLIGHT
    require(guard.get("path") == R14_PREFLIGHT and guard_path.is_file(),
        "r14 prelaunch verifier path is not the owned Python-only verifier")
    require(guard.get("sha256") == sha256_file(guard_path) and
        current_dependencies.get(R14_PREFLIGHT, {}).get("sha256") == sha256_file(guard_path),
        "r14 prelaunch verifier is not source-pinned")
    require(guard.get("required_before_julia") is True and
        guard.get("implementation") == "python_only_no_julia_import_or_launch",
        "r14 prelaunch verifier policy is missing")
    expected_preflight_command = [
        str(Path(sys.executable).resolve()), "-B", str(guard_path.resolve()),
        "--protocol", str(protocol_path),
        "--static-preflight", str(static_path),
        "--baseline-manifest", str(baseline_manifest_path.resolve()),
        "--baseline-parse-manifest", str(baseline_parse_manifest_path.resolve()),
        "--baseline-protocol", str(baseline_protocol_path.resolve()),
    ]
    require(guard.get("command") == expected_preflight_command,
        "r14 preflight argv differs from frozen protocol/input paths")

    runner_path = (repo_root / R14_RUNNER).resolve()
    runner_module = load_runner(runner_path)
    julia = str(execution.get("julia_executable", {}).get("path", ""))
    julia_path = Path(julia).resolve()
    julia_receipt = execution.get("julia_executable", {})
    require(julia_path.is_file() and
        {"bytes": julia_path.stat().st_size, "sha256": sha256_file(julia_path)} ==
            {"bytes": julia_receipt.get("bytes"), "sha256": julia_receipt.get("sha256")},
        "Julia executable receipt does not match pinned bytes")
    expected_supervisor = runner_module.planned_expected_runtime_supervisor_argv(
        planned_output, julia
    )
    require(execution.get("expected_runtime_supervisor_argv") == expected_supervisor,
        "frozen runtime supervisor argv differs from r14 canonical command construction")
    invocation = execution.get("runner_invocation_argv")
    require(isinstance(invocation, list) and all(isinstance(item, str) for item in invocation),
        "runner invocation argv is missing")
    if observed_parent_argv is None:
        observed_parent_argv = psutil.Process(os.getppid()).cmdline()
    selected_field, selected_expected = verify_argv_identity(
        mode, invocation, expected_supervisor, observed_parent_argv, protocol_path
    )
    require(Path(selected_expected[2]).resolve() == runner_path,
        "selected supervisor is not the pinned r14 runner")
    require(Path(selected_expected[0]).resolve() == Path(sys.executable).resolve() and
        selected_expected[1] == "-B", "selected supervisor interpreter/-B argv differs")
    verify_parent_invocation(selected_expected, mode, preparation_output, planned_output,
        julia, runner_path, evidence_root, observed_parent_argv)
    expected_stages = [
        {"stage": name, "argv": command}
        for name, command in runner_module.planned_stage_commands(planned_output, julia)
    ]
    verify_compile_min_delta(
        expected_stages,
        r13_protocol.get("execution_plan", {}).get("stage_commands", []),
        repo_root,
        planned_output,
    )
    require(protocol.get("execution_plan", {}).get("stage_commands") == expected_stages,
        "frozen Julia stage argv does not match the r14 runner or actual output leaf")
    commands = [item["argv"] for item in expected_stages]
    require(commands[0][-2:] == [str(planned_output / "parse_manifest.tsv"), str(repo_root)],
        "parse stage source-manifest/root argv binding is wrong")
    expected_artifact = str(planned_output / "artifacts/primary.bin")
    require(commands[1][-2:] == ["primary", expected_artifact] and
        commands[2][-2:] == ["replay", expected_artifact],
        "primary/fresh replay do not bind the same artifact path")

    return {
        "schema": "native-g1g2-r14-prelaunch-preflight-receipt-v1",
        "status": "pass",
        "protocol_sha256": sha256_file(protocol_path),
        "static_preflight_sha256": sha256_file(static_path),
        "r10_baseline_pin_count": R10_BASELINE_PIN_COUNT,
        "r10_baseline_pins_preserved": True,
        "current_dependency_count": len(current_dependencies),
        "julia_source_count": R10_JULIA_SOURCE_COUNT,
        "runner_invocation_argv_exact": True,
        "selected_parent_argv_field": selected_field,
        "canonical_expected_runtime_supervisor_argv_exact": True,
        "all_julia_stage_argv_exact": True,
        "r10_to_r14_julia_parse_delta": R14_JULIA_TEST,
        "compile_min_is_the_only_compiler_argv_delta_from_r13": True,
        "claim_scope": "compiler_resource_diagnostic",
        "fixture_and_numerical_protocol_unchanged": True,
        "hard_wall_seconds": 480.0,
        "only_budget_delta_from_r10": "wall_seconds:300->480; rss, threads, fixtures, thresholds unchanged",
        "prior_r10_r11_r12_r13_lineage_pins_verified": True,
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
    except ParentArgvIdentityMismatch as error:
        print(json.dumps(error.diagnostic, sort_keys=True))
        return 1
    except Exception as error:
        print(json.dumps({"status": "fail_closed", "error": str(error)}, sort_keys=True))
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
