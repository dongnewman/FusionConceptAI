"""Root-dispatched native G1/G2 compiler -> Gridap consumer supervisor (R29).

This is the single formal consumer runner for this version. It wraps the
unchanged Julia focused test and delegates process-generation identity,
process-tree sampling, and exact-handle termination to the frozen R23 helper.
Importing this module never launches Julia. Runtime dispatch requires the
explicit --dispatch-actual mode and exact protocol-pinned invocation argv.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
REL_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r29_v1.py"
REL_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r29_v1.py"
REL_LEGACY_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r28_v1.py"
REL_VERIFIER = "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r29_v1.py"
REL_R23_TABLE = "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
REL_R23_SUPERVISOR = "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
REL_FOCUSED = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl"
REL_PARSE_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/parse_manifest.tsv"
)
REL_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r29_v1/protocol.json"
)
REL_OUTPUT = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r29_v1/actual_run_root_grant_01"
)
REL_R13_SUMMARY = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/summary.json"
)
REL_R13_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/protocol.json"
)
REL_R23_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_r23_spi_static_20260925_r1/protocol.json"
)
REL_R24_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r24_v1/protocol.json"
)
REL_R24_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r24_v1/freeze_manifest.json"
)
REL_R24_REVIEW = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r24_review_20260925/review.md"
)
REL_R24_REVIEW_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r24_review_20260925/review_manifest.json"
)
REL_R25_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r25_v1/protocol.json"
)
REL_R25_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r25_v1/freeze_manifest.json"
)
REL_R25_REVIEW = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r25_review_20260925/review.md"
)
REL_R25_REVIEW_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r25_review_20260925/review_manifest.json"
)
REL_R26_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r26_v1/protocol.json"
)
REL_R26_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r26_v1/freeze_manifest.json"
)
REL_R26_REVIEW = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r26_review_20260925/review.md"
)
REL_R26_REVIEW_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r26_review_20260925/review_manifest.json"
)
REL_R26_POSTRUN_REVIEW = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r26_postrun_search_chain_r1_20260925/review.md"
)
REL_R26_POSTRUN_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r26_postrun_search_chain_r1_20260925/evidence_manifest.json"
)
REL_R26_ACTUAL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r26_v1/actual_run_root_grant_01"
)
REL_R27_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r27_v1/protocol.json"
)
REL_R27_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r27_v1/freeze_manifest.json"
)
REL_R27_REVIEW = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r27_tester_search_chain_r1_20260926/review.md"
)
REL_R27_REVIEW_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "independent_native_g1g2_r27_tester_search_chain_r1_20260926/evidence_manifest.json"
)

SCHEMA = "native-g1g2-gridap-consumer-r29-protocol-v1"
SUMMARY_SCHEMA = "native-g1g2-gridap-consumer-r29-summary-v1"
RSS_LIMIT_BYTES = 2_147_483_648
SAMPLE_INTERVAL_SECONDS = 0.2
WALL_SECONDS_PER_STAGE = 480.0
JULIA_HEAP_HINT = "1G"
COMPILER_MODE = "--compile=min"
STAGES = ("parse_all", "primary", "fresh_replay")
NO_CREDIT = {
    "numerical_credit": False,
    "numerical_status": "not_established",
    "physical_credit": False,
    "physical_status": "unknown",
    "solver_success_claimed": False,
}
FAILED_LAUNCH_CLEANUP_CONTRACT = {
    "after_popen_before_stage_monitor": "retain_original_popen_handle_immediately",
    "on_initial_root_bind_or_snapshot_failure": "fail_stage_and_do_not_launch_next_stage",
    "identity_recovery": "read_positive_PID_and_exact_raw_FILETIME_from_same_Popen_handle",
    "cleanup_target": "same_original_Popen_handle_only_no_PID_lookup",
    "cleanup_actions": ["native_wait_probe", "exact_handle_terminate_if_live", "native_wait_confirm",
                        "Popen_wait_exit_code_crosscheck", "fresh_process_table_residual_audit"],
    "table_join_available": "attempt_full_tracked_process_tree_cleanup",
    "table_join_unavailable": "reap_original_handle_but_keep_process_tree_and_stage_incomplete",
    "missing_or_unconfirmed_handle": "cleanup_unconfirmed_orphan_uncertainty_and_residual_clear_false",
    "initial_bind_failure_can_be_complete": False,
    "numerical_credit_on_any_bind_failure": False,
    "physical_credit_on_any_bind_failure": False,
    "on_tracked_tree_cleanup_incomplete": "same_original_popen_handle_cleanup_then_fresh_residual_audit",
    "tree_cleanup_fallback_cleanup_unconfirmed": "orphan_uncertainty_and_residual_clear_false",
    "stage_can_pass_after_tree_cleanup_incomplete": False,
    "next_stage_after_tree_cleanup_incomplete": False,
}
SAMPLED_TRACKED_RACE_ERROR = "previously tracked process is missing; exit receipt required"
SAMPLED_TRACKED_RACE_RECOVERY_CONTRACT = {
    "max_retry_count_per_sampling_tick": 1,
    "trigger": "exact_R23_ProcessTableError_for_previously_tracked_identity_absent_from_sampler_before_digest",
    "must_record": ["tracked_before_sample", "full_sampler_before_digest",
                    "all_digest_descendants", "missing_tracked_exit_receipts",
                    "new_descendant_handle_bindings", "orphan_chain_descendants",
                    "orphan_parent_bindings", "reparent_after_missing_parent_exit_receipts",
                    "unaccounted_observed_generations"],
    "root_identity_must_be_present_exactly": True,
    "every_missing_tracked_generation_requires_exact_natural_exit_receipt": True,
    "every_newly_observed_descendant_requires_exact_retained_handle_or_explicit_unaccounted": True,
    "missing_tracked_pid_remains_an_ancestry_root_for_digest_closure": True,
    "descendants_of_missing_tracked_rows_must_not_be_omitted": True,
    "ppid_change_after_missing_parent_exit":
        "allow_only_exact_child_generation_and_name_with_exact_parent_exit_receipt_and_no_parent_pid_reuse",
    "ambiguous_orphan_ancestry": "fail_closed_no_retry",
    "pid_reuse_or_malformed_digest": "fail_closed_no_retry",
    "unaccounted_observed_generation": "resource_monitor_incomplete_residual_clear_false_no_next_stage",
    "retry_must_be_complete": True,
    "incomplete_attempt_is_not_an_RSS_observation": True,
    "numerical_credit_on_recovery": False,
    "physical_credit_on_recovery": False,
}


class PreflightError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": sha256_bytes(data)}


def repo_path(relative: str) -> Path:
    candidate = (ROOT / Path(relative)).resolve()
    try:
        candidate.relative_to(ROOT.resolve())
    except ValueError as exc:
        raise PreflightError(f"repository pin path escapes root: {relative}") from exc
    return candidate


def load_protocol(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise PreflightError(f"protocol read/JSON failure: {type(exc).__name__}: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise PreflightError("protocol schema mismatch")
    return value


def validate_protocol_shape(protocol: Mapping[str, Any]) -> None:
    limits = protocol.get("limits")
    if not isinstance(limits, Mapping):
        raise PreflightError("limits object missing")
    expected_limits = {
        "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
        "wall_seconds_per_stage": WALL_SECONDS_PER_STAGE,
        "sampled_rss_stop_threshold_bytes": RSS_LIMIT_BYTES,
        "julia_heap_size_hint": JULIA_HEAP_HINT,
        "compiler_mode": COMPILER_MODE,
        "julia_threads": 1,
        "blas_threads": 1,
    }
    if dict(limits) != expected_limits:
        raise PreflightError("frozen R29 resource/compiler contract mismatch")
    execution = protocol.get("execution_plan")
    if not isinstance(execution, Mapping) or list(execution.get("stage_order", ())) != list(STAGES):
        raise PreflightError("stage order must remain parse_all/primary/fresh_replay")
    if execution.get("consumer_script") != REL_FOCUSED:
        raise PreflightError("formal consumer script is not the frozen R14 consumer")
    if execution.get("primary_replay_same_consumer_script") is not True:
        raise PreflightError("primary/replay consumer identity is not explicit")
    if execution.get("compile_min_is_only_non_path_argv_delta_from_R13") is not True:
        raise PreflightError("non-path execution argv delta is not limited to --compile=min")
    expected_load_path = f"@;{ROOT};@stdlib"
    if execution.get("julia_load_path") != expected_load_path:
        raise PreflightError("frozen Julia load path differs from R13 environment")
    environment = protocol.get("environment_contract")
    expected_environment = {
        "JULIA_LOAD_PATH": expected_load_path,
        "JULIA_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
    }
    if environment != expected_environment:
        raise PreflightError("runtime environment contract differs from the frozen single-thread R13 setup")
    if protocol.get("fixture_and_solver_thresholds_unchanged") is not True:
        raise PreflightError("fixture/numerical threshold preservation is not declared")
    if protocol.get("archive_is_evidence_only") is not True:
        raise PreflightError("archive scope must be evidence-only")
    if protocol.get("failed_launch_cleanup_contract") != FAILED_LAUNCH_CLEANUP_CONTRACT:
        raise PreflightError("failed Popen launch-binding cleanup contract mismatch")
    if protocol.get("sampled_tracked_race_recovery_contract") != \
            SAMPLED_TRACKED_RACE_RECOVERY_CONTRACT:
        raise PreflightError("sampled tracked-descendant race recovery contract mismatch")
    pins = protocol.get("input_pins")
    if not isinstance(pins, list) or not pins:
        raise PreflightError("input pin list is missing")
    paths: set[str] = set()
    for pin in pins:
        if not isinstance(pin, Mapping):
            raise PreflightError("input pin entry must be an object")
        rel = pin.get("path")
        digest = pin.get("sha256")
        byte_count = pin.get("bytes")
        if type(rel) is not str or rel in paths:
            raise PreflightError("input pin path is malformed or duplicated")
        if type(digest) is not str or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise PreflightError(f"input pin SHA-256 is malformed: {rel}")
        if type(byte_count) is not int or byte_count < 0:
            raise PreflightError(f"input pin byte count is malformed: {rel}")
        paths.add(rel)
    if protocol.get("input_pin_count") != len(pins):
        raise PreflightError("input pin count does not match the frozen pin list")
    required = {
        REL_RUNNER, REL_TEST, REL_LEGACY_TEST, REL_VERIFIER, REL_R23_TABLE, REL_R23_SUPERVISOR,
        REL_FOCUSED, REL_PARSE_MANIFEST, REL_R13_SUMMARY, REL_R23_PROTOCOL,
        REL_R13_PROTOCOL, REL_R24_PROTOCOL, REL_R24_MANIFEST, REL_R24_REVIEW,
        REL_R24_REVIEW_MANIFEST, REL_R25_PROTOCOL, REL_R25_MANIFEST,
        REL_R25_REVIEW, REL_R25_REVIEW_MANIFEST,
        REL_R26_PROTOCOL, REL_R26_MANIFEST, REL_R26_REVIEW,
        REL_R26_REVIEW_MANIFEST, REL_R26_POSTRUN_REVIEW,
        REL_R26_POSTRUN_MANIFEST,
        REL_R27_PROTOCOL, REL_R27_MANIFEST, REL_R27_REVIEW,
        REL_R27_REVIEW_MANIFEST,
        f"{REL_R26_ACTUAL}/summary.json",
        f"{REL_R26_ACTUAL}/02_primary/final.json",
        f"{REL_R26_ACTUAL}/02_primary/samples.jsonl",
        f"{REL_R26_ACTUAL}/02_primary/start.json",
        f"{REL_R26_ACTUAL}/02_primary/stdout.raw",
        "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl",
        "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
        "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl",
        "Project.toml", "Manifest.toml",
    }
    absent = sorted(required - paths)
    if absent:
        raise PreflightError("required consumer/helper/environment pins missing: " + ", ".join(absent))
    lineage = protocol.get("parent_lineage")
    r24_review = lineage.get("r24_runtime_no_go_review") if isinstance(lineage, Mapping) else None
    if not isinstance(r24_review, Mapping) or r24_review.get("verdict") != "NO-GO_RUNTIME" or \
            r24_review.get("path") != REL_R24_REVIEW or \
            r24_review.get("manifest_path") != REL_R24_REVIEW_MANIFEST:
        raise PreflightError("R24 failed-run review lineage is missing or malformed")
    for rel, key in ((REL_R24_REVIEW, "sha256"),
                     (REL_R24_REVIEW_MANIFEST, "manifest_sha256"),
                     (REL_R24_PROTOCOL, "protocol_sha256"),
                     (REL_R24_MANIFEST, "freeze_manifest_sha256")):
        pinned = next((item for item in pins if item["path"] == rel), None)
        if pinned is None or pinned["sha256"] != r24_review.get(key):
            raise PreflightError(f"R24 failed-run lineage hash is not pinned: {rel}")
    r25_review = lineage.get("r25_runtime_followup") if isinstance(lineage, Mapping) else None
    if not isinstance(r25_review, Mapping) or \
            r25_review.get("path") != REL_R25_REVIEW or \
            r25_review.get("manifest_path") != REL_R25_REVIEW_MANIFEST or \
            r25_review.get("root_followup_blocker") != \
                "tracked_tree_cleanup_incomplete_without_original_popen_handle_fallback":
        raise PreflightError("R25 follow-up blocker/review lineage is missing or malformed")
    for rel, key in ((REL_R25_REVIEW, "sha256"),
                     (REL_R25_REVIEW_MANIFEST, "manifest_sha256"),
                     (REL_R25_PROTOCOL, "protocol_sha256"),
                     (REL_R25_MANIFEST, "freeze_manifest_sha256")):
        pinned = next((item for item in pins if item["path"] == rel), None)
        if pinned is None or pinned["sha256"] != r25_review.get(key):
            raise PreflightError(f"R25 review/freeze lineage hash is not pinned: {rel}")
    r26_failure = lineage.get("r26_actual_failure") if isinstance(lineage, Mapping) else None
    if not isinstance(r26_failure, Mapping) or \
            r26_failure.get("actual_leaf") != REL_R26_ACTUAL or \
            r26_failure.get("stop_reason") != "resource_monitor_incomplete" or \
            r26_failure.get("numerical_credit") is not False or \
            r26_failure.get("physical_credit") is not False or \
            r26_failure.get("exact_missing_tracked_identity_recoverable_from_r26") is not False:
        raise PreflightError("R26 actual failure/no-credit lineage is missing or malformed")
    r26_bound_hashes = (
        (REL_R26_PROTOCOL, "protocol_sha256"),
        (REL_R26_MANIFEST, "freeze_manifest_sha256"),
        (REL_R26_REVIEW, "review_sha256"),
        (REL_R26_REVIEW_MANIFEST, "review_manifest_sha256"),
        (REL_R26_POSTRUN_REVIEW, "postrun_review_sha256"),
        (REL_R26_POSTRUN_MANIFEST, "postrun_manifest_sha256"),
        (f"{REL_R26_ACTUAL}/summary.json", "summary_sha256"),
        (f"{REL_R26_ACTUAL}/02_primary/final.json", "primary_final_sha256"),
        (f"{REL_R26_ACTUAL}/02_primary/samples.jsonl", "primary_samples_sha256"),
        (f"{REL_R26_ACTUAL}/02_primary/start.json", "primary_start_sha256"),
        (f"{REL_R26_ACTUAL}/02_primary/stdout.raw", "primary_stdout_sha256"),
    )
    for rel, key in r26_bound_hashes:
        pin = next((item for item in pins if item["path"] == rel), None)
        if pin is None or pin["sha256"] != r26_failure.get(key):
            raise PreflightError(f"R26 actual-failure evidence is not pinned: {rel}")
    r27_no_go = lineage.get("r27_orphan_chain_no_go") if isinstance(lineage, Mapping) else None
    if not isinstance(r27_no_go, Mapping) or \
            r27_no_go.get("protocol_path") != REL_R27_PROTOCOL or \
            r27_no_go.get("manifest_path") != REL_R27_MANIFEST or \
            r27_no_go.get("review_path") != REL_R27_REVIEW or \
            r27_no_go.get("review_manifest_path") != REL_R27_REVIEW_MANIFEST or \
            r27_no_go.get("runtime_dispatch_verdict") != "NO-GO" or \
            r27_no_go.get("failure_shape") != \
                "live_descendant_under_missing_tracked_parent_was_omitted_and_reported_complete":
        raise PreflightError("R27 frozen orphan-chain NO-GO lineage is missing or malformed")
    for rel, key in ((REL_R27_PROTOCOL, "protocol_sha256"),
                     (REL_R27_MANIFEST, "freeze_manifest_sha256"),
                     (REL_R27_REVIEW, "review_sha256"),
                     (REL_R27_REVIEW_MANIFEST, "review_manifest_sha256")):
        pin = next((item for item in pins if item["path"] == rel), None)
        if pin is None or pin["sha256"] != r27_no_go.get(key):
            raise PreflightError(f"R27 orphan-chain failure lineage is not pinned: {rel}")
    r13_summary = json.loads(repo_path(REL_R13_SUMMARY).read_text(encoding="utf-8"))
    for rel, expected_pin in r13_summary["dependencies_before"].items():
        pinned = next((item for item in pins if item["path"] == rel), None)
        if pinned is None or pinned["bytes"] != expected_pin["bytes"] or \
                pinned["sha256"] != expected_pin["sha256"]:
            raise PreflightError(f"R13 frozen input pin missing/drifted in R29: {rel}")
    process_contract = protocol.get("process_table_contract")
    if not isinstance(process_contract, Mapping) or \
            process_contract.get("host_build_pin") != [10, 0, 26200, "AMD64"] or \
            process_contract.get("helper_schema") != "native-g1g2-windows-process-table-r23-v1":
        raise PreflightError("R23 build-pinned native process table contract mismatch")
    if protocol.get("acceptance_boundary", {}).get("numerical_credit") is not False or \
            protocol.get("acceptance_boundary", {}).get("physical_credit") is not False:
        raise PreflightError("R29 static/runtime preparation cannot pregrant numerical or physical credit")
    invocation = protocol.get("invocation_contract")
    if not isinstance(invocation, Mapping):
        raise PreflightError("invocation contract missing")
    static_argv = invocation.get("static_verifier_argv")
    actual_argv = invocation.get("actual_supervisor_argv")
    if type(static_argv) is not list or type(actual_argv) is not list or static_argv == actual_argv:
        raise PreflightError("static and runtime invocation roles must be separately pinned")
    python_pin = invocation.get("python_interpreter")
    if not isinstance(python_pin, Mapping) or type(python_pin.get("path")) is not str:
        raise PreflightError("Python interpreter identity pin is malformed")
    static_qa = protocol.get("static_qa")
    expected_tests = (python_pin["path"] + " -B " + str(repo_path(REL_LEGACY_TEST)) + " -v")
    expected_failure_tests = (python_pin["path"] + " -B " + str(repo_path(REL_LEGACY_TEST)) +
                              " R28LaunchBindingFailureTests -v")
    expected_tree_failure_tests = (python_pin["path"] + " -B " + str(repo_path(REL_LEGACY_TEST)) +
                                   " R28TrackedTreeCleanupFallbackTests -v")
    expected_sample_race_tests = (python_pin["path"] + " -B " + str(repo_path(REL_LEGACY_TEST)) +
                                  " R28SampleRaceRecoveryTests -v")
    expected_orphan_chain_tests = (python_pin["path"] + " -B " + str(repo_path(REL_LEGACY_TEST)) +
                                   " R28OrphanChainRecoveryTests -v")
    expected_pid_reuse_tests = (python_pin["path"] + " -B " + str(repo_path(REL_TEST)) +
                                " R29NaturalExitPidReuseTests -v")
    expected_verifier_command = (python_pin["path"] + " -B " + str(repo_path(REL_VERIFIER)) +
                                 " --protocol " + str(repo_path(REL_PROTOCOL)))
    if not isinstance(static_qa, Mapping) or \
            static_qa.get("python_tests_command") != expected_tests or \
            static_qa.get("bind_failure_fault_injection_command") != expected_failure_tests or \
            static_qa.get("tree_cleanup_fault_injection_command") != expected_tree_failure_tests or \
            static_qa.get("sample_race_fault_injection_command") != expected_sample_race_tests or \
            static_qa.get("orphan_chain_fault_injection_command") != expected_orphan_chain_tests or \
            static_qa.get("pid_reuse_fault_injection_command") != expected_pid_reuse_tests or \
            static_qa.get("verifier_command") != expected_verifier_command:
        raise PreflightError("R29 static QA argv does not target the pinned tests/verifier")
    protocol_abs = str(repo_path(REL_PROTOCOL))
    expected_static = [python_pin["path"], "-B", str(repo_path(REL_VERIFIER)),
                       "--protocol", protocol_abs]
    expected_actual = [python_pin["path"], "-B", str(repo_path(REL_RUNNER)),
                       "--dispatch-actual", "--protocol", protocol_abs,
                       "--output", str(repo_path(REL_OUTPUT))]
    if static_argv != expected_static or actual_argv != expected_actual:
        raise PreflightError("frozen static/runtime argv does not address the unique R29 verifier/consumer")
    planned_output = protocol.get("planned_output_leaf")
    if planned_output != REL_OUTPUT:
        raise PreflightError("runtime output leaf differs from frozen unique leaf")
    # The R13 actual protocol is the command parent. Apart from the explicit
    # compile-min mode flag and versioned consumer/artifact paths, every token
    # and stage role must remain exactly equal.
    parent = json.loads(repo_path(REL_R13_PROTOCOL).read_text(encoding="utf-8"))
    parent_commands = parent["execution_plan"]["stage_commands"]
    planned = execution["stage_commands"]
    old_output = parent["execution_plan"]["planned_actual_output"]
    if len(parent_commands) != 3 or len(planned) != 3:
        raise PreflightError("R13/R29 stage command count changed")
    for old, new in zip(parent_commands, planned):
        old_argv = list(old["argv"])
        if old_argv.count(COMPILER_MODE) != 0 or old_argv.count("--threads=1") != 1:
            raise PreflightError("R13 compiler/thread argv parent is unexpected")
        old_argv.insert(old_argv.index("--threads=1") + 1, COMPILER_MODE)
        if old["stage"] != "parse_all":
            old_argv = [arg.replace(old_output, str(repo_path(REL_OUTPUT))) for arg in old_argv]
        old_argv = [arg.replace("focused_tests_r12_markers.jl", Path(REL_FOCUSED).name)
                    for arg in old_argv]
        if new != {"stage": old["stage"], "argv": old_argv}:
            raise PreflightError(f"R29 command is not the pinned R13 command plus approved path/mode delta: {old['stage']}")


def verify_input_pins(protocol: Mapping[str, Any]) -> dict[str, Any]:
    checked: list[dict[str, Any]] = []
    missing: list[dict[str, str]] = []
    changed: list[dict[str, Any]] = []
    for pin in protocol["input_pins"]:
        path = repo_path(pin["path"])
        if not path.is_file():
            missing.append({"path": pin["path"], "reason": "missing_or_not_file"})
            continue
        current = file_receipt(path)
        checked.append({"path": pin["path"], "bytes": current["bytes"], "sha256": current["sha256"]})
        if current["bytes"] != pin["bytes"] or current["sha256"] != pin["sha256"]:
            changed.append({"path": pin["path"], "expected_bytes": pin["bytes"],
                            "actual_bytes": current["bytes"], "expected_sha256": pin["sha256"],
                            "actual_sha256": current["sha256"]})
    result = {"complete": not missing and not changed, "checked_count": len(checked),
              "missing": missing, "changed": changed, "checked": checked}
    if not result["complete"]:
        raise PreflightError("frozen input pins are not complete: " + json.dumps(result, sort_keys=True))
    return result


def validate_invocation(mode: str, observed_argv: list[str], protocol: Mapping[str, Any]) -> None:
    if mode not in ("static_verifier", "actual_supervisor"):
        raise PreflightError("invocation role must be explicitly static_verifier or actual_supervisor")
    expected = protocol["invocation_contract"][f"{mode}_argv"]
    if observed_argv != expected:
        raise PreflightError(
            "observed invocation argv does not match the selected role: " +
            json.dumps({"role": mode, "expected": expected, "observed": observed_argv}, sort_keys=True)
        )


def _load_r23() -> tuple[Any, Any]:
    table_name = "native_process_table_r23_v1"
    table = sys.modules.get(table_name)
    if table is None:
        path = repo_path(REL_R23_TABLE)
        spec = importlib.util.spec_from_file_location(table_name, path)
        if spec is None or spec.loader is None:
            raise PreflightError("frozen R23 process-table helper cannot load")
        table = importlib.util.module_from_spec(spec)
        sys.modules[table_name] = table
        spec.loader.exec_module(table)
    supervisor_name = "supervise_r16_root_audit_r23_v1"
    supervisor = sys.modules.get(supervisor_name)
    if supervisor is None:
        path = repo_path(REL_R23_SUPERVISOR)
        spec = importlib.util.spec_from_file_location(supervisor_name, path)
        if spec is None or spec.loader is None:
            raise PreflightError("frozen R23 exact supervisor helpers cannot load")
        supervisor = importlib.util.module_from_spec(spec)
        sys.modules[supervisor_name] = supervisor
        spec.loader.exec_module(supervisor)
    return table, supervisor


def parse_script_text() -> str:
    return (
        'using SHA; '
        'function ng12_parse_issue(x); '
        'x isa Expr || return nothing; '
        'x.head in (:error,:incomplete) && return x.head; '
        'for child in x.args; issue=ng12_parse_issue(child); '
        'issue===nothing || return issue; end; nothing; end; '
        'function main(args); manifest=args[1]; root=args[2]; count=0; '
        'for line in eachline(manifest); expected,relative=split(line,"\\t";limit=2); '
        'path=joinpath(root,split(relative,\'/\')...); '
        'bytes=read(path); bytes2hex(SHA.sha256(bytes))==expected || '
        'error("parse pin mismatch: "*relative); '
        'parsed=Meta.parseall(String(bytes)); issue=ng12_parse_issue(parsed); '
        'issue===nothing || error("parse tree "*String(issue)*": "*relative); '
        'count+=1; end; println("NG12_PARSE status=pass files=",count); end; '
        'main(ARGS)'
    )


def julia_prefix(julia_exe: str, gridap_project: str) -> list[str]:
    return [julia_exe, f"--project={gridap_project}", "--startup-file=no",
            "--history-file=no", "--threads=1", COMPILER_MODE,
            f"--heap-size-hint={JULIA_HEAP_HINT}"]


def planned_stage_commands(protocol: Mapping[str, Any], output: Path) -> list[dict[str, Any]]:
    execution = protocol["execution_plan"]
    julia = execution["julia_executable"]["path"]
    prefix = julia_prefix(julia, execution["gridap_project"])
    artifact = output / "artifacts" / "primary.bin"
    parse_manifest = repo_path(REL_PARSE_MANIFEST)
    return [
        {"stage": "parse_all", "argv": [*prefix, "-e", parse_script_text(),
            str(parse_manifest), str(ROOT)]},
        {"stage": "primary", "argv": [*prefix, str(repo_path(REL_FOCUSED)),
            "primary", str(artifact)]},
        {"stage": "fresh_replay", "argv": [*prefix, str(repo_path(REL_FOCUSED)),
            "replay", str(artifact)]},
    ]


def _native_resource_reader(pid: int) -> Mapping[str, Any]:
    import psutil
    process = psutil.Process(pid)
    memory = process.memory_info()
    cpu = process.cpu_times()
    command = process.cmdline()
    return {"rss_bytes": memory.rss, "cpu_user_seconds": cpu.user,
            "cpu_system_seconds": cpu.system, "cmdline": command}


def _id_dict(identity: tuple[int, int]) -> dict[str, int]:
    return {"pid": identity[0], "create_time_100ns": identity[1]}


def _identity_map(value: Any) -> tuple[int, int]:
    table, _ = _load_r23()
    return table.validate_identity(value)


def _natural_exit_receipt(identity: tuple[int, int], handle: Any,
                          snapshot_provider: Any, table: Any,
                          wait_for_exit: Any, exit_code_reader: Any) -> dict[str, Any]:
    """Receipt an exit by the already bound exact handle, then reconcile SPI."""
    try:
        table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                    phase="natural-exit-prewait-handle")
        if not wait_for_exit(handle, 0.001):
            return {"identity": _id_dict(identity), "complete": False,
                    "reason": "exact_handle_not_signaled"}
        table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                    phase="natural-exit-postwait-handle")
        code = exit_code_reader(handle)
        after = table.validate_snapshot(snapshot_provider())
        row = after.by_pid.get(identity[0])
        if row is not None and (row.identity.pid, row.identity.create_time_100ns) == identity:
            raise RuntimeError("same exact generation remains after signaled handle")
        return {"schema": "native-g1g2-r29-natural-exit-receipt-v1",
                "identity": _id_dict(identity), "complete": True,
                "signal_sent": False, "wait_confirmed": True,
                "exit_code": code,
                "pid_reused_after_exit": row is not None,
                "replacement_create_time_100ns": (
                    row.identity.create_time_100ns if row is not None else None)}
    except Exception as exc:
        return {"schema": "native-g1g2-r29-natural-exit-receipt-v1",
                "identity": _id_dict(identity), "complete": False,
                "signal_sent": False, "wait_confirmed": False,
                "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)},
                **NO_CREDIT}


def _sample_before_rows(sample: Mapping[str, Any]) -> dict[int, tuple[int, int, str]]:
    """Validate and index the exact SPI digest returned by the R23 sampler."""
    digest = sample.get("native_snapshot_before_digest")
    if type(digest) is not list:
        raise ValueError("sampler before-digest is absent or not a native list")
    rows: dict[int, tuple[int, int, str]] = {}
    for index, row in enumerate(digest):
        if type(row) not in (list, tuple) or len(row) != 4:
            raise ValueError(f"sampler before-digest row {index} is malformed")
        pid, ppid, ticks, name = row
        if type(pid) is not int or pid < 0 or pid > 0xFFFFFFFF or \
                type(ppid) is not int or ppid < 0 or ppid > 0xFFFFFFFF or \
                type(ticks) is not int or ticks <= 0 or ticks > (1 << 63) - 1 or \
                type(name) is not str or "\x00" in name:
            raise ValueError(f"sampler before-digest row {index} has invalid native fields")
        if (pid == 0 and (ppid != 0 or name != "")) or \
                (pid != 0 and not name) or pid in rows:
            raise ValueError(f"sampler before-digest row {index} has an invalid or duplicate PID")
        rows[pid] = (ppid, ticks, name)
    return rows


def _classify_missing_tracked_sample_race(
    sample: Mapping[str, Any], tracked_before_sample: tuple[tuple[int, int], ...],
    root_identity: tuple[int, int], table: Any, audit: Any,
) -> dict[str, Any]:
    """Classify only the exact R23 missing-tracked-row failure; never infer around other errors."""
    rejected = {"eligible": False, "complete": False, "reason": "sample_failure_not_exact_tracked_race",
                "missing_tracked_identities": [], "observed_descendant_identities": [],
                "new_observed_descendant_identities": [], "unaccounted_observed_generations": [],
                "exit_receipts": [], "bound_observed_generations": [],
                "reparented_observed_generations": [], **NO_CREDIT}
    try:
        root = table.validate_identity(root_identity)
        if sample.get("schema") != audit.SAMPLE_SCHEMA or sample.get("complete") is not False:
            return rejected
        sample_root = sample.get("root_identity")
        if type(sample_root) is not dict or table.validate_identity((
                sample_root.get("pid"), sample_root.get("create_time_100ns"))) != root:
            rejected["reason"] = "sample_root_identity_mismatch"
            return rejected
        errors = sample.get("errors")
        if type(errors) is not list or len(errors) != 1 or type(errors[0]) is not dict:
            return rejected
        error = errors[0]
        if error.get("phase") != "sample_process_tree" or \
                error.get("type") != "ProcessTableError" or \
                error.get("message") != SAMPLED_TRACKED_RACE_ERROR or \
                error.get("repr") != f"ProcessTableError({SAMPLED_TRACKED_RACE_ERROR!r})":
            return rejected
        if sample.get("processes") != [] or sample.get("discovered_identities") != [] or \
                sample.get("measured_identities") != [] or sample.get("rss_bytes") is not None or \
                sample.get("partial_rss_bytes") != 0 or sample.get("native_snapshot_after_digest") is not None:
            rejected["reason"] = "exact_tracked_race_shape_has_partial_or_after-sample-data"
            return rejected
        for key in ("numerical_credit", "physical_credit", "solver_success_claimed"):
            if key in sample and sample[key] is not False:
                rejected["reason"] = "sample_failure_claims_credit"
                return rejected
        rows = _sample_before_rows(sample)
        root_row = rows.get(root[0])
        if root_row is None or (root[0], root_row[1]) != root:
            rejected["reason"] = "sample_before_digest_missing_or_reused_root"
            return rejected

        tracked_ids: list[tuple[int, int]] = []
        for raw_identity in tracked_before_sample:
            identity = table.validate_identity(raw_identity)
            tracked_ids.append(identity)
        if len(set(tracked_ids)) != len(tracked_ids) or len({x[0] for x in tracked_ids}) != len(tracked_ids) or \
                tracked_ids.count(root) != 1:
            rejected["reason"] = "tracked_before_sample_set_is_duplicate_or_lacks_exact_root"
            return rejected

        missing: list[tuple[int, int]] = []
        for identity in tracked_ids:
            current = rows.get(identity[0])
            if current is None:
                missing.append(identity)
            elif current[1] != identity[1]:
                rejected["reason"] = "tracked_pid_generation_mismatch_in_sample_digest"
                rejected["unaccounted_observed_generations"] = [_id_dict(identity)]
                return rejected
        if not missing:
            return rejected
        if root in missing:
            rejected["reason"] = "tracked_root_missing_from_sample_digest"
            rejected["unaccounted_observed_generations"] = [_id_dict(root)]
            return rejected

        # Reconstruct every descendant represented by the failing native digest.
        # Every exact tracked-before PID remains an ancestry root even if its row
        # has disappeared from the sampler's independent process-table snapshot.
        known_rows: dict[int, tuple[int, int, str]] = {}
        ancestry_ticks: dict[int, int] = {pid: ticks for pid, ticks in tracked_ids}
        for identity in tracked_ids:
            row = rows.get(identity[0])
            if row is not None and row[1] == identity[1]:
                known_rows[identity[0]] = row
        if root[0] not in known_rows:
            rejected["reason"] = "sample_before_digest_root_not_seeded"
            return rejected
        changed = True
        while changed:
            changed = False
            for pid, row in rows.items():
                if pid in ancestry_ticks or row[0] not in ancestry_ticks:
                    continue
                parent_ticks = ancestry_ticks[row[0]]
                if row[1] < parent_ticks:
                    rejected["reason"] = "sample_before_digest_orphan_chain_parent_chronology_ambiguous"
                    ambiguous_pids = {pid}
                    changed_orphan = True
                    while changed_orphan:
                        changed_orphan = False
                        for child_pid, child_row in rows.items():
                            if child_pid not in ambiguous_pids and child_row[0] in ambiguous_pids:
                                ambiguous_pids.add(child_pid)
                                changed_orphan = True
                    rejected["unaccounted_observed_generations"] = [
                        {"pid": child_pid, "create_time_100ns": rows[child_pid][1],
                         "parent_pid": rows[child_pid][0],
                         "reason": "sample_before_digest_orphan_chain_parent_chronology_ambiguous"}
                        for child_pid in sorted(ambiguous_pids)]
                    return rejected
                ancestry_ticks[pid] = row[1]
                known_rows[pid] = row
                changed = True
        all_descendants = sorted((pid, row[1]) for pid, row in known_rows.items())
        new_descendants = [identity for identity in all_descendants if identity not in tracked_ids]
        orphan_chain_pids = {pid for pid, _ticks in missing}
        changed = True
        while changed:
            changed = False
            for pid, row in rows.items():
                if pid not in orphan_chain_pids and row[0] in orphan_chain_pids:
                    orphan_chain_pids.add(pid)
                    changed = True
        rejected.update({
            "eligible": True,
            "reason": "exact_tracked_generation_missing_from_sampler_before_digest",
            "tracked_before_sample": [_id_dict(x) for x in tracked_ids],
            "missing_tracked_identities": [_id_dict(x) for x in missing],
            "observed_descendant_identities": [_id_dict(x) for x in all_descendants],
            "new_observed_descendant_identities": [_id_dict(x) for x in new_descendants],
            "orphan_chain_roots": [_id_dict(x) for x in missing
                                    if any(row[0] == x[0] for row in rows.values())],
            "orphan_chain_descendant_identities": [
                _id_dict(identity) for identity in all_descendants
                if identity[0] in orphan_chain_pids and identity[0] not in {x[0] for x in missing}],
            "sample_before_digest_row_count": len(rows),
        })
        return rejected
    except Exception as exc:
        rejected["reason"] = "sample_race_diagnostic_invalid"
        rejected["diagnostic_error"] = {"type": type(exc).__name__,
            "message": str(exc), "repr": repr(exc)}
        return rejected


def _recover_missing_tracked_sample_race(
    sample: Mapping[str, Any], tracked_before_sample: tuple[tuple[int, int], ...],
    root_identity: tuple[int, int], tracked: set[tuple[int, int]],
    handles: dict[tuple[int, int], Any], exit_receipts: list[dict[str, Any]],
    table: Any, audit: Any, snapshot_provider: Any,
) -> dict[str, Any]:
    """Receipt absent tracked generations and bind every descendant in the failed digest."""
    diagnostic = _classify_missing_tracked_sample_race(
        sample, tracked_before_sample, root_identity, table, audit)
    if diagnostic.get("eligible") is not True:
        diagnostic["complete"] = False
        return diagnostic

    for item in diagnostic["missing_tracked_identities"]:
        identity = table.validate_identity((item["pid"], item["create_time_100ns"]))
        handle = handles.get(identity)
        if handle is None:
            diagnostic["unaccounted_observed_generations"].append(_id_dict(identity))
            diagnostic["reason"] = "missing_tracked_generation_has_no_retained_exact_handle"
            return diagnostic
        receipt = _natural_exit_receipt(identity, handle, snapshot_provider, table,
            table.wait_for_process_exit, table.process_exit_code)
        exit_receipts.append(receipt)
        diagnostic["exit_receipts"].append(receipt)
        if receipt.get("complete") is not True:
            diagnostic["reason"] = "missing_tracked_generation_exit_receipt_incomplete"
            return diagnostic
        if receipt.get("pid_reused_after_exit") is not False:
            # The exact old parent exited, but its natural-exit SPI already saw
            # another generation under the same PID. That replacement can exit
            # before the recovery SPI, leaving a child with the stale PPID and
            # making the apparent orphan ancestry ambiguous. Do not bind those
            # rows or authorize the one bounded retry.
            reused = receipt.get("pid_reused_after_exit") is True
            diagnostic["reason"] = (
                "missing_tracked_generation_pid_reused_after_natural_exit" if reused else
                "missing_tracked_generation_pid_reuse_state_unverifiable_after_natural_exit")
            diagnostic["complete"] = False
            diagnostic["residual_clear"] = False
            diagnostic["residual_clear_reason"] = "parent_pid_reuse_makes_orphan_ancestry_ambiguous"
            diagnostic["cleanup_unconfirmed"] = True
            diagnostic["orphan_uncertainty"] = (
                "a replacement parent generation was observed after exact-handle exit; "
                "sampled descendants may retain its reused PPID")
            diagnostic["retry_authorized"] = False
            diagnostic["retry_count"] = 0
            diagnostic["pid_reuse_exit_receipt"] = {
                "identity": receipt.get("identity"),
                "pid_reused_after_exit": receipt.get("pid_reused_after_exit"),
                "replacement_create_time_100ns": receipt.get("replacement_create_time_100ns"),
            }
            replacement_ticks = receipt.get("replacement_create_time_100ns")
            diagnostic["unaccounted_observed_generations"].append({
                "pid": identity[0], "create_time_100ns": replacement_ticks,
                "reason": "replacement_generation_observed_after_missing_parent_exit",
            })

            digest_rows = _sample_before_rows(sample)
            affected_pids = {pid for pid, row in digest_rows.items() if row[0] == identity[0]}
            changed = True
            while changed:
                changed = False
                for pid, row in digest_rows.items():
                    if pid not in affected_pids and row[0] in affected_pids:
                        affected_pids.add(pid)
                        changed = True
            for item in diagnostic["new_observed_descendant_identities"]:
                if item.get("pid") in affected_pids:
                    diagnostic["unaccounted_observed_generations"].append({
                        **_id_dict((item["pid"], item["create_time_100ns"])),
                        "reason": "descendant_ancestry_ambiguous_after_parent_pid_reuse",
                    })
            return diagnostic
        tracked.discard(identity)

    try:
        fresh = table.validate_snapshot(snapshot_provider())
        fresh_rows = fresh.by_pid
        digest_rows = _sample_before_rows(sample)
        missing_by_pid = {item["pid"]: table.validate_identity((
            item["pid"], item["create_time_100ns"]))
            for item in diagnostic["missing_tracked_identities"]}
        exact_parent_exit_receipts = {
            (receipt.get("identity", {}).get("pid"),
             receipt.get("identity", {}).get("create_time_100ns"))
            for receipt in diagnostic["exit_receipts"]
            if receipt.get("complete") is True and isinstance(receipt.get("identity"), Mapping)
        }
        orphan_parent_bindings = diagnostic.setdefault("orphan_parent_bindings", [])
        for item in diagnostic["new_observed_descendant_identities"]:
            identity = table.validate_identity((item["pid"], item["create_time_100ns"]))
            expected = digest_rows.get(identity[0])
            row = fresh_rows.get(identity[0])
            if row is None:
                diagnostic["unaccounted_observed_generations"].append({
                    **_id_dict(identity), "reason": "digest_observed_descendant_missing_before_handle_bind"})
                continue
            observed = table.validate_identity((row.identity.pid, row.identity.create_time_100ns))
            if observed != identity or expected is None or row.name != expected[2]:
                diagnostic["unaccounted_observed_generations"].append({
                    **_id_dict(identity), "reason": "digest_observed_descendant_generation_or_parent_changed"})
                continue
            expected_parent_row = digest_rows.get(expected[0])
            missing_parent = missing_by_pid.get(expected[0])
            expected_parent_identity = ((expected[0], expected_parent_row[1])
                if expected_parent_row is not None else missing_parent)
            if expected_parent_identity is None:
                diagnostic["unaccounted_observed_generations"].append({
                    **_id_dict(identity),
                    "reason": "orphan_descendant_parent_identity_not_proven_by_digest_or_tracked_set"})
                continue
            fresh_old_parent = fresh_rows.get(expected[0])
            if fresh_old_parent is not None:
                observed_parent_identity = table.validate_identity((
                    fresh_old_parent.identity.pid, fresh_old_parent.identity.create_time_100ns))
                if observed_parent_identity != expected_parent_identity:
                    diagnostic["unaccounted_observed_generations"].append({
                        **_id_dict(identity),
                        "reason": "orphan_descendant_parent_generation_reused"})
                    continue
            elif expected_parent_identity not in missing_by_pid.values() or \
                    expected_parent_identity not in exact_parent_exit_receipts:
                diagnostic["unaccounted_observed_generations"].append({
                    **_id_dict(identity),
                    "reason": "orphan_descendant_parent_absent_without_exact_exit_receipt"})
                continue

            if row.ppid != expected[0]:
                new_parent_row = fresh_rows.get(row.ppid)
                if missing_parent is None or expected_parent_identity != missing_parent or \
                        missing_parent not in exact_parent_exit_receipts or \
                        fresh_old_parent is not None or new_parent_row is None:
                    diagnostic["unaccounted_observed_generations"].append({
                        **_id_dict(identity),
                        "reason": "orphan_descendant_parent_changed_without_exact_parent_exit"})
                    continue
                new_parent_identity = table.validate_identity((
                    new_parent_row.identity.pid, new_parent_row.identity.create_time_100ns))
                if identity[1] < new_parent_identity[1]:
                    diagnostic["unaccounted_observed_generations"].append({
                        **_id_dict(identity),
                        "reason": "orphan_descendant_reparent_target_chronology_ambiguous"})
                    continue
                diagnostic["reparented_observed_generations"].append({
                    **_id_dict(identity),
                    "before_parent_pid": expected[0],
                    "before_parent_identity": _id_dict(expected_parent_identity),
                    "after_parent_pid": row.ppid,
                    "after_parent_identity": _id_dict(new_parent_identity),
                    "parent_exit_receipt_verified": True,
                })
            elif fresh_old_parent is None:
                orphan_parent_bindings.append({
                    **_id_dict(identity),
                    "parent_pid": expected[0],
                    "parent_identity": _id_dict(expected_parent_identity),
                    "parent_exit_receipt_verified": True,
                    "sampled_ppid_persists_after_exit": True,
                })
            existing = handles.get(identity)
            if existing is None:
                exact_handle = table.open_exact_process_handle(row)
                try:
                    table.require_handle_matches_table(exact_handle, identity, fresh,
                        handle_identity_reader=table.read_process_handle_identity)
                except Exception:
                    try:
                        table.close_process_handle(exact_handle)
                    except Exception:
                        pass
                    raise
                handles[identity] = exact_handle
            else:
                table.require_handle_matches_table(existing, identity, fresh,
                    handle_identity_reader=table.read_process_handle_identity)
            tracked.add(identity)
            diagnostic["bound_observed_generations"].append(_id_dict(identity))

        if diagnostic["unaccounted_observed_generations"]:
            diagnostic["reason"] = "digest_observed_descendant_unaccounted"
            return diagnostic

        # Bind any additional descendants that appeared after the failed digest.
        _bind_tree(fresh, root_identity, tracked, handles, table)
        heavy_unowned = set(audit.global_heavy_processes(fresh)) - tracked
        if heavy_unowned:
            diagnostic["reason"] = "unowned_heavy_process_after_sample_race"
            diagnostic["unaccounted_observed_generations"].extend(
                {"pid": pid, "create_time_100ns": ticks,
                 "reason": "unowned_heavy_process_after_sample_race"}
                for pid, ticks in sorted(heavy_unowned))
            return diagnostic
    except Exception as exc:
        diagnostic["reason"] = "sample_race_rebind_or_reconcile_failed"
        diagnostic["recovery_error"] = {"type": type(exc).__name__,
            "message": str(exc), "repr": repr(exc)}
        bound = {(item.get("pid"), item.get("create_time_100ns"))
                 for item in diagnostic["bound_observed_generations"]
                 if isinstance(item, Mapping)}
        diagnostic["unaccounted_observed_generations"].extend(
            item for item in diagnostic["new_observed_descendant_identities"]
            if (item.get("pid"), item.get("create_time_100ns")) not in bound)
        return diagnostic

    diagnostic["complete"] = True
    diagnostic["reason"] = "missing_generations_receipted_and_all_observed_descendants_bound"
    return diagnostic


def _append_jsonl(path: Path, row: Mapping[str, Any]) -> None:
    with path.open("a", encoding="utf-8", newline="\n") as stream:
        stream.write(json.dumps(row, sort_keys=True) + "\n")


def _sample_attempt_record(attempt_index: int, sample_index: int,
                           tracked_before_sample: tuple[tuple[int, int], ...],
                           sample: Mapping[str, Any], *, outcome: str,
                           recovery: Mapping[str, Any] | None = None) -> dict[str, Any]:
    sample_bytes = json.dumps(sample, sort_keys=True, separators=(",", ":")).encode("utf-8")
    record: dict[str, Any] = {
        "schema": "native-g1g2-r29-sample-attempt-v1",
        "attempt_index": attempt_index, "sample_index": sample_index,
        "tracked_before_sample": [_id_dict(x) for x in tracked_before_sample],
        "sample_complete": sample.get("complete") is True,
        "sample_sha256": sha256_bytes(sample_bytes),
        "outcome": outcome,
    }
    if sample.get("complete") is not True:
        record["incomplete_sample"] = dict(sample)
    if recovery is not None:
        record["recovery"] = dict(recovery)
    return record


def _capture_popen_handle_identity(process: Any, table: Any) -> tuple[int, int]:
    """Read the exact generation from the Popen-owned handle after table bind fails."""
    pid = getattr(process, "pid", None)
    handle = getattr(process, "_handle", None)
    if type(pid) is not int or pid <= 0 or handle is None:
        raise RuntimeError("Popen child PID or original handle is unavailable")
    identity = table.validate_identity(table.read_process_handle_identity(handle))
    if identity[0] != pid:
        raise RuntimeError("original Popen handle PID does not match Popen.pid")
    return identity


def _cleanup_original_popen_handle_after_incomplete_tree(
    process: Any, table: Any, expected_identity: tuple[int, int] | None,
    *, failure_phase: str,
) -> dict[str, Any]:
    """Reap the exact launched handle after an incomplete tree audit.

    This only confirms the Popen-owned root. The stage remains incomplete
    because tree cleanup or sampling failed, and descendants require the
    separate fresh global/process-tree residual audit.
    """
    handle = getattr(process, "_handle", None)
    pid = getattr(process, "pid", None)
    receipt: dict[str, Any] = {
        "schema": "native-g1g2-r29-original-popen-handle-cleanup-v1",
        "failure_phase": failure_phase,
        "complete": False,
        "cleanup_target": "same_original_Popen_handle_no_PID_lookup",
        "signal_sent": False,
        "wait_confirmed": False,
        "popen_wait_confirmed": False,
        "root_handle_exit_confirmed": False,
        "process_tree_cleanup_complete": False,
        "identity_confirmed": False,
        **NO_CREDIT,
    }
    if handle is None or type(pid) is not int or pid <= 0 or \
            handle is not getattr(process, "_handle", None):
        receipt["failure"] = {"phase": "popen_handle_precondition",
                              "reason": "original Popen handle or positive native PID missing"}
        return receipt

    before_identity: tuple[int, int] | None = None
    try:
        candidate_identity = table.validate_identity(table.read_process_handle_identity(handle))
        if candidate_identity[0] != pid:
            raise RuntimeError("Popen handle PID differs from Popen.pid")
        if expected_identity is not None and candidate_identity != expected_identity:
            raise RuntimeError("Popen handle generation changed during bind-failure recovery")
        before_identity = candidate_identity
        receipt["identity_before"] = _id_dict(before_identity)
        receipt["identity_confirmed"] = True
    except Exception as exc:
        receipt["identity_before_error"] = {
            "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}

    try:
        already_exited = table.wait_for_process_exit(handle, 0.001)
        if type(already_exited) is not bool:
            raise RuntimeError("native handle wait returned a non-bool value")
    except Exception as exc:
        already_exited = False
        receipt["initial_wait_error"] = {
            "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
    if not already_exited:
        try:
            # Popen._handle is the original kernel process handle acquired at
            # launch; this signal cannot be redirected by PID reuse.
            table.terminate_process_handle(handle)
            receipt["signal_sent"] = True
        except Exception as exc:
            receipt["signal_error"] = {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
    try:
        waited = already_exited or table.wait_for_process_exit(handle, 10.0)
        if type(waited) is not bool or waited is not True:
            raise RuntimeError("native wait on original Popen handle did not confirm exit")
        receipt["wait_confirmed"] = True
    except Exception as exc:
        receipt["wait_error"] = {
            "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}

    if receipt["wait_confirmed"]:
        try:
            after_identity = table.validate_identity(table.read_process_handle_identity(handle))
            if after_identity[0] != pid:
                raise RuntimeError("post-wait original Popen handle PID differs from Popen.pid")
            receipt["identity_after"] = _id_dict(after_identity)
            if before_identity is not None and after_identity != before_identity:
                raise RuntimeError("original Popen handle generation changed across cleanup")
            receipt["identity_confirmed"] = before_identity is not None and \
                after_identity == before_identity
            receipt["observed_identity"] = _id_dict(after_identity)
        except Exception as exc:
            receipt["identity_after_error"] = {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
        try:
            code = table.process_exit_code(handle)
            if type(code) is not int or code == 259:
                raise RuntimeError("original Popen handle exit code is malformed or STILL_ACTIVE")
            receipt["native_exit_code"] = code
        except Exception as exc:
            receipt["native_exit_code_error"] = {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
        try:
            popen_code = process.wait(timeout=0)
            if type(popen_code) is not int:
                raise RuntimeError("Popen wait returned a malformed exit code")
            receipt["popen_exit_code"] = popen_code
            if type(receipt.get("native_exit_code")) is not int or \
                    popen_code != receipt["native_exit_code"]:
                raise RuntimeError("Popen wait result differs from native original-handle exit code")
            receipt["popen_wait_confirmed"] = True
        except Exception as exc:
            receipt["popen_wait_error"] = {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
        receipt["root_handle_exit_confirmed"] = receipt["popen_wait_confirmed"] and \
            receipt.get("native_exit_code") == receipt.get("popen_exit_code")
        if receipt["root_handle_exit_confirmed"]:
            receipt["reason"] = "original_popen_handle_exit_confirmed_after_incomplete_tree_audit"
    return receipt


def _recover_failed_popen_launch(
    process: Any,
    root_identity: tuple[int, int] | None,
    handles: dict[tuple[int, int], Any],
    tracked: set[tuple[int, int]],
    table: Any,
    audit: Any,
) -> dict[str, Any]:
    """Try full exact tree cleanup, then reap the original Popen handle fail-closed."""
    if root_identity is None:
        try:
            root_identity = _capture_popen_handle_identity(process, table)
            tracked.add(root_identity)
            handles[root_identity] = getattr(process, "_handle", None)
        except Exception:
            root_identity = None

    snapshot_error: dict[str, Any] | None = None
    if root_identity is not None:
        try:
            snapshot = table.validate_snapshot(table.query_native_process_table())
            row = snapshot.by_pid.get(root_identity[0])
            if row is not None and \
                    (row.identity.pid, row.identity.create_time_100ns) == root_identity:
                tree_receipt = _terminate_tracked(root_identity, handles, tracked, table, audit)
                try:
                    popen_code = process.wait(timeout=0)
                    popen_wait = {"confirmed": type(popen_code) is int,
                                  "exit_code": popen_code}
                except Exception as exc:
                    popen_wait = {"confirmed": False,
                                  "error": {"type": type(exc).__name__,
                                            "message": str(exc), "repr": repr(exc)}}
                handle_cleanup = None
                if tree_receipt.get("complete") is not True or popen_wait.get("confirmed") is not True:
                    handle_cleanup = _cleanup_original_popen_handle_after_incomplete_tree(
                        process, table, root_identity,
                        failure_phase="initial_root_bind_recovery_tree_cleanup_incomplete")
                return {
                    "schema": "native-g1g2-r29-popen-bind-failure-cleanup-v1",
                    "complete": False,
                    "root_identity": _id_dict(root_identity),
                    "process_tree_cleanup_complete": tree_receipt.get("complete") is True,
                    "tree_termination_receipt": tree_receipt,
                    "original_popen_handle_cleanup": handle_cleanup,
                    "popen_wait": popen_wait,
                    "reason": "initial_process_table_generation_join_failed",
                    **NO_CREDIT,
                }
            snapshot_error = {"phase": "root_generation_row_missing_or_mismatched",
                              "root_identity": _id_dict(root_identity),
                              "observed_row": (
                                  {"pid": row.identity.pid,
                                   "create_time_100ns": row.identity.create_time_100ns}
                                  if row is not None else None)}
        except Exception as exc:
            snapshot_error = {"phase": "recovery_snapshot",
                              "type": type(exc).__name__, "message": str(exc),
                              "repr": repr(exc)}

    handle_receipt = _cleanup_original_popen_handle_after_incomplete_tree(
        process, table, root_identity, failure_phase="initial_root_bind_failure")
    observed_identity = handle_receipt.get("observed_identity")
    if root_identity is None and isinstance(observed_identity, Mapping):
        try:
            recovered = table.validate_identity((observed_identity.get("pid"),
                                                  observed_identity.get("create_time_100ns")))
            if recovered[0] == getattr(process, "pid", None):
                root_identity = recovered
                tracked.add(recovered)
                handles[recovered] = getattr(process, "_handle", None)
        except Exception:
            pass
    return {
        "schema": "native-g1g2-r29-popen-bind-failure-cleanup-v1",
        "complete": False,
        "root_identity": _id_dict(root_identity) if root_identity is not None else None,
        "process_tree_cleanup_complete": False,
        "snapshot_error": snapshot_error,
        "original_popen_handle_cleanup": handle_receipt,
        "reason": "initial_process_table_generation_join_failed_tree_not_bound",
        **NO_CREDIT,
    }


def _resource_tree_depth(identity: tuple[int, int], root_identity: tuple[int, int],
                         snapshot: Any, table: Any) -> int:
    by_pid = {row.identity.pid: row for row in snapshot.rows}
    depth = 0
    current = by_pid.get(identity[0])
    seen: set[int] = set()
    while current is not None and current.identity.pid != root_identity[0]:
        if current.identity.pid in seen:
            raise RuntimeError("cycle in process parent chain")
        seen.add(current.identity.pid)
        parent_pid = current.ppid
        if parent_pid == 0:
            raise RuntimeError("tracked descendant no longer traces to root")
        depth += 1
        current = by_pid.get(parent_pid)
    if current is None:
        raise RuntimeError("tracked descendant parent row missing")
    if (current.identity.pid, current.identity.create_time_100ns) != root_identity:
        raise RuntimeError("root PID generation changed while ordering termination")
    return depth


def _bind_tree(snapshot: Any, root_identity: tuple[int, int], tracked: set[tuple[int, int]],
               handles: dict[tuple[int, int], Any], table: Any) -> tuple[tuple[int, int], ...]:
    identities = table.descendant_identities(snapshot, root_identity,
        previously_tracked=tuple(sorted(tracked)))
    for item in identities:
        identity = (item.pid, item.create_time_100ns)
        if identity not in handles:
            row = snapshot.by_pid.get(identity[0])
            if row is None:
                raise RuntimeError("new descendant disappeared before exact handle binding")
            handles[identity] = table.open_exact_process_handle(row)
        table.require_handle_matches_table(handles[identity], identity, snapshot,
            handle_identity_reader=table.read_process_handle_identity)
        tracked.add(identity)
    return tuple(sorted((item.pid, item.create_time_100ns) for item in identities))


def _terminate_tracked(root_identity: tuple[int, int], handles: dict[tuple[int, int], Any],
                       tracked: set[tuple[int, int]], table: Any, audit: Any) -> dict[str, Any]:
    signalled: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    snapshot_provider = table.query_native_process_table
    # Discover and terminate exact current descendants for bounded passes.
    for pass_index in range(1, 9):
        try:
            snapshot = table.validate_snapshot(snapshot_provider())
            root_row = snapshot.by_pid.get(root_identity[0])
            if root_row is not None and \
                    (root_row.identity.pid, root_row.identity.create_time_100ns) != root_identity:
                raise RuntimeError("root PID was reused during termination")
            present: list[tuple[int, int]] = []
            if root_row is not None:
                live_tracked: set[tuple[int, int]] = set()
                for identity in tuple(sorted(tracked)):
                    handle = handles.get(identity)
                    if handle is None:
                        raise RuntimeError("tracked identity has no exact retained handle")
                    table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                                phase="termination-preflight-handle")
                    row = snapshot.by_pid.get(identity[0])
                    row_is_exact = row is not None and \
                        (row.identity.pid, row.identity.create_time_100ns) == identity
                    if table.wait_for_process_exit(handle, 0.001):
                        receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                            table, table.wait_for_process_exit, table.process_exit_code)
                        signalled.append(receipt)
                        if receipt.get("complete") is not True:
                            errors.append({"pass": pass_index, "natural_exit": receipt})
                    elif row_is_exact:
                        live_tracked.add(identity)
                    else:
                        raise RuntimeError("tracked generation vanished without exact wait receipt")
                ids = table.descendant_identities(snapshot, root_identity,
                    previously_tracked=tuple(sorted(live_tracked)))
                for item in ids:
                    identity = (item.pid, item.create_time_100ns)
                    if identity not in handles:
                        row = snapshot.by_pid[item.pid]
                        handles[identity] = table.open_exact_process_handle(row)
                    tracked.add(identity)
                    present.append(identity)
                order = sorted(present, key=lambda item: _resource_tree_depth(
                    item, root_identity, snapshot, table), reverse=True)
            else:
                # Root exited: any row recursively parented by a tracked PID is
                # conservatively treated as a remaining descendant.
                rows = snapshot.by_pid
                pid_depth: dict[int, tuple[int, int]] = {root_identity[0]: root_identity}
                changed = True
                while changed:
                    changed = False
                    for row in snapshot.rows:
                        parent = pid_depth.get(row.ppid)
                        if parent is None or row.identity.pid in pid_depth:
                            continue
                        if row.identity.create_time_100ns < parent[1]:
                            raise RuntimeError("orphan child chronology is ambiguous")
                        identity = (row.identity.pid, row.identity.create_time_100ns)
                        pid_depth[row.identity.pid] = identity
                        tracked.add(identity)
                        if identity not in handles:
                            handles[identity] = table.open_exact_process_handle(row)
                        changed = True
                present = [identity for pid, identity in pid_depth.items()
                           if pid != root_identity[0] and rows.get(pid) is not None and
                           (rows[pid].identity.pid, rows[pid].identity.create_time_100ns) == identity]
                order = sorted(present, key=lambda item: item[1], reverse=True)
            for identity in order:
                handle = handles.get(identity)
                if handle is None:
                    errors.append({"pass": pass_index, "identity": _id_dict(identity),
                                   "reason": "missing_exact_handle_before_signal"})
                    continue
                if table.wait_for_process_exit(handle, 0.001):
                    receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                        table, table.wait_for_process_exit, table.process_exit_code)
                    signalled.append(receipt)
                    if receipt.get("complete") is not True:
                        errors.append({"pass": pass_index, "natural_exit": receipt})
                    continue
                result = audit.signal_exact_process(
                    handle, identity,
                    snapshot_provider=snapshot_provider,
                    handle_identity_reader=table.read_process_handle_identity,
                    signal_sender=table.terminate_process_handle,
                    wait_for_exit=table.wait_for_process_exit,
                    exit_code_reader=table.process_exit_code,
                    timeout_seconds=10.0,
                )
                signalled.append(result)
                if result.get("complete") is not True:
                    errors.append({"pass": pass_index, "identity": _id_dict(identity),
                                   "result": result})
            final = table.validate_snapshot(snapshot_provider())
            residual = audit.audit_residual_identities(tracked, final)
            if residual.get("complete") is not True or residual.get("residual_clear") is not True:
                errors.append({"pass": pass_index, "residual_audit": residual})
                continue
            heavy = audit.global_heavy_processes(final)
            if heavy:
                errors.append({"pass": pass_index, "unowned_heavy_identities": [list(x) for x in heavy]})
                continue
            if not errors:
                return {"schema": "native-g1g2-r29-exact-termination-v1",
                        "complete": True, "passes": pass_index,
                        "signals": signalled, "residual_audit": residual,
                        "unowned_heavy_identities": []}
        except Exception as exc:
            errors.append({"pass": pass_index, "type": type(exc).__name__,
                           "message": str(exc), "repr": repr(exc)})
    return {"schema": "native-g1g2-r29-exact-termination-v1", "complete": False,
            "passes": 8, "signals": signalled, "errors": errors,
            **NO_CREDIT}


def _run_stage(output: Path, index: int, stage_name: str, command: list[str],
               environment: Mapping[str, str], table: Any, audit: Any) -> dict[str, Any]:
    stage_dir = output / f"{index:02d}_{stage_name}"
    stage_dir.mkdir()
    sample_attempts_path = stage_dir / "sample_attempts.jsonl"
    sample_attempts_path.write_bytes(b"")
    started: float | None = None
    started_utc: str | None = None
    samples: list[dict[str, Any]] = []
    sample_attempt_count = 0
    sample_recovery_count = 0
    sample_recovery_unresolved = False
    unaccounted_observed_generations: list[dict[str, Any]] = []
    tracked: set[tuple[int, int]] = set()
    exit_receipts: list[dict[str, Any]] = []
    termination_receipt: dict[str, Any] | None = None
    monitor_error: dict[str, Any] | None = None
    launch_binding_failure: dict[str, Any] | None = None
    stop_reason = "natural_exit"
    root_identity: tuple[int, int] | None = None
    root_exit_code: int | None = None
    stage_wall = WALL_SECONDS_PER_STAGE
    root_handle = None
    handles: dict[tuple[int, int], Any] = {}
    cache: dict[str, Any] = {"snapshot": None}

    def snapshot_provider() -> Any:
        value = table.query_native_process_table()
        cache["snapshot"] = table.validate_snapshot(value)
        return cache["snapshot"]

    def handle_provider(row: Any) -> Any:
        snapshot = cache.get("snapshot")
        if snapshot is None:
            raise RuntimeError("R23 sample requested a handle without a pinned snapshot")
        identity = (row.identity.pid, row.identity.create_time_100ns)
        if identity not in handles:
            handles[identity] = table.open_exact_process_handle(row)
        table.require_handle_matches_table(handles[identity], identity, snapshot,
            handle_identity_reader=table.read_process_handle_identity)
        tracked.add(identity)
        return handles[identity]

    # Check and record the global inventory before each child launch.
    prelaunch_snapshot = snapshot_provider()
    heavy_before = audit.global_heavy_processes(prelaunch_snapshot)
    if heavy_before:
        raise RuntimeError("pre-run heavy process inventory is not empty: " + repr(heavy_before))
    with (stage_dir / "stdout.raw").open("xb") as stdout, \
            (stage_dir / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(
            command, cwd=str(ROOT), env=dict(environment), stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        started = time.monotonic()
        started_utc = utc_now()
        root_handle = getattr(process, "_handle", None)
        try:
            initial_snapshot = snapshot_provider()
            root_identity = audit.bind_popen_generation(process, initial_snapshot,
                handle_identity_reader=table.read_process_handle_identity)
            tracked.add(root_identity)
            handles[root_identity] = root_handle
        except Exception as exc:
            monitor_error = {"phase": "root_launch_binding", "type": type(exc).__name__,
                             "message": str(exc), "repr": repr(exc)}
            launch_binding_failure = dict(monitor_error)
            # The first SPI join failed, but Popen still owns the exact child
            # handle. Recover its raw identity immediately for residual audit;
            # this does not restore stage completeness or permit execution.
            try:
                root_identity = _capture_popen_handle_identity(process, table)
                tracked.add(root_identity)
                handles[root_identity] = root_handle
                launch_binding_failure["popen_handle_identity_recovered"] = _id_dict(root_identity)
            except Exception as recovery_exc:
                launch_binding_failure["popen_handle_identity_recovery_error"] = {
                    "type": type(recovery_exc).__name__, "message": str(recovery_exc),
                    "repr": repr(recovery_exc)}
            monitor_error = launch_binding_failure
            stop_reason = "resource_monitor_incomplete"
        start_receipt = {
            "schema": "native-g1g2-r29-stage-start-v1", "stage": stage_name,
            "started_utc": started_utc, "argv": command, "cwd": str(ROOT),
            "root_pid": process.pid,
            "root_identity": _id_dict(root_identity) if root_identity else None,
            "identity_source": "Popen_original_handle_plus_build_pinned_SPI_raw_FILETIME",
            "global_heavy_before": [list(x) for x in heavy_before],
            "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
            "wall_seconds_per_stage": stage_wall,
            "sampled_rss_stop_threshold_bytes": RSS_LIMIT_BYTES,
            "sampled_stop_semantics": True,
            "environment": {k: environment.get(k) for k in (
                "JULIA_LOAD_PATH", "JULIA_NUM_THREADS", "JULIA_PKG_OFFLINE",
                "JULIA_PKG_PRECOMPILE_AUTO", "OPENBLAS_NUM_THREADS",
                "OMP_NUM_THREADS", "MKL_NUM_THREADS")},
        }
        (stage_dir / "start.json").write_text(json.dumps(start_receipt, indent=2, sort_keys=True),
                                               encoding="utf-8")

        while stop_reason == "natural_exit":
            now_elapsed = time.monotonic() - started
            if now_elapsed >= stage_wall:
                stop_reason = "resource_failure"
                monitor_error = {"phase": "wall_deadline", "elapsed_seconds": now_elapsed,
                                 "limit_seconds": stage_wall,
                                 "reason": "stage_wall_deadline"}
                break
            try:
                current = snapshot_provider()
                # Receipt exits only through the already generation-bound handle.
                for identity in tuple(sorted(tracked)):
                    handle = handles.get(identity)
                    if handle is None:
                        raise RuntimeError("tracked exact identity has no retained handle")
                    table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                                phase="tracked-stage-loop-handle")
                    waited = table.wait_for_process_exit(handle, 0.001)
                    row = current.by_pid.get(identity[0])
                    same_row = row is not None and \
                        (row.identity.pid, row.identity.create_time_100ns) == identity
                    if waited:
                        receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                            table, table.wait_for_process_exit, table.process_exit_code)
                        exit_receipts.append(receipt)
                        if receipt.get("complete") is not True:
                            raise RuntimeError("exact natural-exit receipt incomplete")
                        tracked.remove(identity)
                        if identity == root_identity:
                            root_exit_code = receipt["exit_code"]
                    elif not same_row:
                        raise RuntimeError("tracked identity absent/reused but original handle is active")

                if root_identity not in tracked:
                    if tracked:
                        raise RuntimeError("consumer root exited while descendants remain; stopping fail-closed")
                    break

                current = snapshot_provider()
                _bind_tree(current, root_identity, tracked, handles, table)
                heavy_unowned = set(audit.global_heavy_processes(current)) - tracked
                if heavy_unowned:
                    raise RuntimeError("unowned heavy process appeared during stage: " +
                                       repr(sorted(heavy_unowned)))

                elapsed = time.monotonic() - started
                sample_index = len(samples) + 1
                tracked_before_sample = tuple(sorted(tracked))
                sample = audit.sample_process_tree(
                    root_identity, snapshot_provider=snapshot_provider,
                    handle_provider=handle_provider,
                    resource_reader=_native_resource_reader,
                    handle_identity_reader=table.read_process_handle_identity,
                    previously_tracked=tracked_before_sample,
                    sample_index=sample_index, elapsed_seconds=elapsed)
                sample_attempt_count += 1
                if sample.get("complete") is True:
                    _append_jsonl(sample_attempts_path, _sample_attempt_record(
                        sample_attempt_count, sample_index, tracked_before_sample,
                        sample, outcome="accepted_complete_sample"))
                    samples.append(sample)
                    _append_jsonl(stage_dir / "samples.jsonl", sample)
                else:
                    recovery = _recover_missing_tracked_sample_race(
                        sample, tracked_before_sample, root_identity, tracked, handles,
                        exit_receipts, table, audit, snapshot_provider)
                    sample_recovery_unresolved = recovery.get("complete") is not True
                    for item in recovery.get("unaccounted_observed_generations", []):
                        if isinstance(item, Mapping):
                            unaccounted_observed_generations.append(dict(item))
                    _append_jsonl(sample_attempts_path, _sample_attempt_record(
                        sample_attempt_count, sample_index, tracked_before_sample,
                        sample, outcome=("recoverable_exact_tracked_race" if
                            recovery.get("complete") is True else "incomplete_unrecovered"),
                        recovery=recovery))
                    if recovery.get("complete") is not True:
                        stop_reason = "resource_monitor_incomplete"
                        monitor_error = {"phase": "sample_process_tree", "sample": sample,
                                         "sample_race_recovery": recovery}
                        break

                    sample_recovery_count += 1
                    retry_tracked_before_sample = tuple(sorted(tracked))
                    retry_elapsed = time.monotonic() - started
                    retry_sample = audit.sample_process_tree(
                        root_identity, snapshot_provider=snapshot_provider,
                        handle_provider=handle_provider,
                        resource_reader=_native_resource_reader,
                        handle_identity_reader=table.read_process_handle_identity,
                        previously_tracked=retry_tracked_before_sample,
                        sample_index=sample_index, elapsed_seconds=retry_elapsed)
                    sample_attempt_count += 1
                    retry_outcome = ("accepted_recovered_sample" if
                                     retry_sample.get("complete") is True else
                                     "recovery_retry_incomplete")
                    _append_jsonl(sample_attempts_path, _sample_attempt_record(
                        sample_attempt_count, sample_index, retry_tracked_before_sample,
                        retry_sample, outcome=retry_outcome,
                        recovery={"schema": "native-g1g2-r29-sample-retry-link-v1",
                                  "prior_attempt_index": sample_attempt_count - 1,
                                  "prior_failure_sample_sha256": sha256_bytes(json.dumps(
                                      sample, sort_keys=True, separators=(",", ":")).encode("utf-8")),
                                  "retry_limit": 1, **NO_CREDIT}))
                    if retry_sample.get("complete") is not True:
                        sample_recovery_unresolved = True
                        stop_reason = "resource_monitor_incomplete"
                        monitor_error = {"phase": "sample_process_tree_retry",
                                         "sample": retry_sample,
                                         "prior_sample": sample,
                                         "sample_race_recovery": recovery}
                        break
                    sample = retry_sample
                    samples.append(sample)
                    _append_jsonl(stage_dir / "samples.jsonl", sample)
                tracked.update({
                    (item["pid"], item["create_time_100ns"])
                    for item in sample["discovered_identities"]
                })
                after_sample = snapshot_provider()
                _bind_tree(after_sample, root_identity, tracked, handles, table)
                heavy_unowned = set(audit.global_heavy_processes(after_sample)) - tracked
                if heavy_unowned:
                    raise RuntimeError("unowned heavy process appeared across sample: " +
                                       repr(sorted(heavy_unowned)))
                disposition = audit.sampled_resource_disposition(samples)
                if disposition.get("disposition") == "resource_failure":
                    stop_reason = "resource_failure"
                    monitor_error = {"phase": "sampled_resource_gate", "disposition": disposition}
                    break
                # Sampled interval is an observation cadence, not a hard RSS cap.
                time.sleep(SAMPLE_INTERVAL_SECONDS)
            except Exception as exc:
                monitor_error = {"phase": "stage_monitor", "type": type(exc).__name__,
                                 "message": str(exc), "repr": repr(exc)}
                stop_reason = "resource_monitor_incomplete"
                break

        if stop_reason != "natural_exit":
            if launch_binding_failure is not None:
                termination_receipt = _recover_failed_popen_launch(
                    process, root_identity, handles, tracked, table, audit)
                recovered_dict = termination_receipt.get("root_identity")
                if root_identity is None and isinstance(recovered_dict, Mapping):
                    try:
                        root_identity = table.validate_identity((
                            recovered_dict.get("pid"), recovered_dict.get("create_time_100ns")))
                    except Exception:
                        root_identity = None
                monitor_error = dict(monitor_error or launch_binding_failure)
                monitor_error["launch_failure_cleanup"] = termination_receipt
                # Initial process-table join failure permanently fails this
                # stage even when exact-handle cleanup succeeds.
                stop_reason = "resource_monitor_incomplete"
            elif root_identity is not None:
                tree_receipt = _terminate_tracked(root_identity, handles, tracked, table, audit)
                termination_receipt = tree_receipt
                if termination_receipt.get("complete") is not True:
                    stop_reason = "resource_monitor_incomplete"
                    try:
                        pre_fallback_code = process.wait(timeout=0)
                        pre_fallback_wait = {"confirmed": type(pre_fallback_code) is int,
                                             "exit_code": pre_fallback_code}
                    except Exception as exc:
                        pre_fallback_wait = {
                            "confirmed": False,
                            "error": {"type": type(exc).__name__,
                                      "message": str(exc), "repr": repr(exc)},
                        }
                    handle_cleanup = _cleanup_original_popen_handle_after_incomplete_tree(
                        process, table, root_identity,
                        failure_phase="tracked_tree_cleanup_incomplete")
                    termination_receipt = {
                        "schema": "native-g1g2-r29-tree-cleanup-fallback-v1",
                        "complete": False,
                        "process_tree_cleanup_complete": False,
                        "tree_termination_receipt": tree_receipt,
                        "pre_fallback_popen_wait": pre_fallback_wait,
                        "original_popen_handle_cleanup": handle_cleanup,
                        "reason": "tracked_tree_cleanup_incomplete_same_popen_handle_fallback_attempted",
                        **NO_CREDIT,
                    }
                    if isinstance(monitor_error, dict):
                        monitor_error["tree_cleanup_fallback"] = termination_receipt

        # A final inventory and exact residual audit are mandatory on all exits.
        try:
            final_snapshot = snapshot_provider()
            residual = audit.audit_residual_identities(set(handles), final_snapshot)
            heavy_after = audit.global_heavy_processes(final_snapshot)
            residual_complete = residual.get("complete") is True and \
                residual.get("residual_clear") is True and not heavy_after
        except Exception as exc:
            residual = {"complete": False, "failure": {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}}
            heavy_after = ()
            residual_complete = False
        if not residual_complete:
            stop_reason = "resource_monitor_incomplete"
            monitor_error = monitor_error or {"phase": "final_residual_audit",
                                              "residual": residual,
                                              "heavy_after": [list(x) for x in heavy_after]}
        if unaccounted_observed_generations or sample_recovery_unresolved:
            residual_complete = False
            if isinstance(residual, dict):
                residual["complete"] = False
                residual["residual_clear"] = False
                residual["cleanup_unconfirmed"] = True
                residual["unaccounted_observed_generations"] = unaccounted_observed_generations
                residual["sample_recovery_unresolved"] = sample_recovery_unresolved
                residual["residual_clear_reason"] = (
                    "sample_failure_left_observed_process_generations_unaccounted"
                    if unaccounted_observed_generations else
                    "sample_attempt_did_not_complete_bounded_exact_recovery")
                residual["orphan_uncertainty"] = (
                    "an observed process-table generation could not be bound or receipted"
                    if unaccounted_observed_generations else
                    "the failed sample attempt was not fully recovered and re-observed")
            stop_reason = "resource_monitor_incomplete"
        if launch_binding_failure is not None:
            residual_complete = False
            if isinstance(residual, dict):
                residual["launch_binding_failure"] = launch_binding_failure
                residual["resource_monitor_complete"] = False
                cleanup = termination_receipt or {}
                tree_complete = cleanup.get("process_tree_cleanup_complete") is True
                handle_cleanup = cleanup.get("original_popen_handle_cleanup", {})
                handle_exit_confirmed = handle_cleanup.get("root_handle_exit_confirmed") is True
                if not tree_complete:
                    residual["residual_clear"] = False
                    residual["residual_clear_reason"] = (
                        "process_tree_cleanup_unconfirmed_after_initial_root_join_failure")
                if not handle_exit_confirmed:
                    residual["cleanup_unconfirmed"] = True
                    residual["orphan_uncertainty"] = (
                        "launched child generation is unbound and original Popen handle cleanup was not confirmed"
                        if root_identity is None else
                        "original Popen handle exit was not confirmed after initial launch binding failure")
                    residual["residual_clear"] = False
                    residual["residual_clear_reason"] = "original_popen_handle_cleanup_unconfirmed"
                    if isinstance(monitor_error, dict):
                        monitor_error["orphan_uncertainty"] = residual["orphan_uncertainty"]

        if isinstance(termination_receipt, dict) and \
                termination_receipt.get("schema") == "native-g1g2-r29-tree-cleanup-fallback-v1":
            handle_cleanup = termination_receipt.get("original_popen_handle_cleanup") or {}
            if handle_cleanup.get("root_handle_exit_confirmed") is not True:
                residual["cleanup_unconfirmed"] = True
                residual["orphan_uncertainty"] = (
                    "tracked tree cleanup was incomplete and original Popen handle exit was not confirmed")
                residual["residual_clear"] = False
                residual["residual_clear_reason"] = "original_popen_handle_cleanup_unconfirmed_after_tree_failure"
                if isinstance(monitor_error, dict):
                    monitor_error["cleanup_unconfirmed"] = True
                    monitor_error["orphan_uncertainty"] = residual["orphan_uncertainty"]

        close_receipt = {"complete": True, "closed_owned_handles": []}
        for identity, handle in list(handles.items()):
            if identity == root_identity:
                continue  # Popen owns and closes its original handle.
            try:
                table.close_process_handle(handle)
                close_receipt["closed_owned_handles"].append(_id_dict(identity))
                handles.pop(identity)
            except Exception as exc:
                close_receipt["complete"] = False
                close_receipt.setdefault("errors", []).append({
                    "identity": _id_dict(identity), "type": type(exc).__name__,
                    "message": str(exc), "repr": repr(exc)})
        if close_receipt.get("complete") is not True:
            stop_reason = "resource_monitor_incomplete"

        finished = time.monotonic()
        all_exit_receipts_complete = bool(exit_receipts) and all(
            item.get("complete") is True for item in exit_receipts)
        root_receipts = [item for item in exit_receipts
                         if item.get("identity") == _id_dict(root_identity)
                         ] if root_identity is not None else []
        if len(root_receipts) != 1 or root_receipts[0].get("complete") is not True:
            stop_reason = "resource_monitor_incomplete"
        if stop_reason == "natural_exit" and root_exit_code is None and root_receipts:
            root_exit_code = root_receipts[0].get("exit_code")
        disposition = audit.sampled_resource_disposition(samples) if samples else {
            "disposition": "resource_monitor_incomplete", "complete": False,
            "reason": "no_samples", **NO_CREDIT}
        if stop_reason == "resource_failure" and disposition.get("disposition") != "resource_failure":
            reason = (monitor_error or {}).get("disposition", {}).get("reason")
            disposition = {"disposition": "resource_failure", "complete": True,
                           "reason": reason or "stage_wall_deadline", **NO_CREDIT}
        elif stop_reason == "resource_monitor_incomplete":
            disposition = {"disposition": "resource_monitor_incomplete", "complete": False,
                           "reason": "monitor_or_residual_audit_incomplete", **NO_CREDIT}
        final = {
            "schema": "native-g1g2-r29-stage-final-v1", "stage": stage_name,
            "started_utc": started_utc, "finished_utc": utc_now(),
            "elapsed_seconds": finished - started, "argv": command,
            "root_identity": _id_dict(root_identity) if root_identity else None,
            "root_exit_code": root_exit_code,
            "root_exit_receipt": root_receipts[0] if root_receipts else None,
            "stage_exit_receipts": exit_receipts,
            "all_stage_exit_receipts_complete": all_exit_receipts_complete,
            "samples": samples,
            "sample_attempts_path": "sample_attempts.jsonl",
            "sample_attempt_count": sample_attempt_count,
            "sample_recovery_count": sample_recovery_count,
            "unaccounted_observed_generations": unaccounted_observed_generations,
            "resource_disposition": disposition,
            "stop_reason": stop_reason,
            "termination_receipt": termination_receipt,
            "final_residual_audit": residual,
            "global_heavy_after": [list(x) for x in heavy_after],
            "handle_close_receipt": close_receipt,
            "resource_monitor_complete": stop_reason == "natural_exit" and residual_complete and
                all_exit_receipts_complete and disposition.get("complete") is True,
            "monitor_error": monitor_error,
            **NO_CREDIT,
        }
        (stage_dir / "final.json").write_text(json.dumps(final, indent=2, sort_keys=True),
                                               encoding="utf-8")
        return final


def _stage_pass(output: Path, stage: Mapping[str, Any], stage_index: int) -> tuple[bool, str | None]:
    if stage.get("stop_reason") != "natural_exit":
        return False, f"{stage.get('stage')}: stop_reason={stage.get('stop_reason')}"
    if stage.get("root_exit_code") != 0:
        return False, f"{stage.get('stage')}: natural root exit code is not zero"
    if stage.get("resource_monitor_complete") is not True:
        return False, f"{stage.get('stage')}: monitor or residual audit incomplete"
    raw = (output / f"{stage_index:02d}_{stage['stage']}" / "stdout.raw").read_text(
        encoding="utf-8", errors="replace")
    marker = "NG12_PARSE status=pass files=108" if stage["stage"] == "parse_all" else (
        f"NG12_RESULT mode={'primary' if stage['stage'] == 'primary' else 'replay'} status=pass")
    if marker not in raw:
        return False, f"{stage.get('stage')}: required consumer marker missing"
    return True, None


def _run_stage_sequence(output: Path, commands: list[Mapping[str, Any]],
                        environment: Mapping[str, str], table: Any, audit: Any
                        ) -> tuple[list[dict[str, Any]], str | None]:
    """Run stages serially and stop immediately on any incomplete receipt."""
    stages: list[dict[str, Any]] = []
    for index, plan in enumerate(commands, 1):
        stage = dict(_run_stage(output, index, plan["stage"], plan["argv"],
                                environment, table, audit))
        stages.append(stage)
        passed, failure = _stage_pass(output, stage, index)
        if not passed:
            return stages, failure
    return stages, None


def _set_environment(protocol: Mapping[str, Any]) -> dict[str, str]:
    env = dict(os.environ)
    env.update({
        "JULIA_LOAD_PATH": protocol["execution_plan"]["julia_load_path"],
        "JULIA_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
    })
    return env


def dispatch_actual(protocol_path: Path, output: Path, observed_argv: list[str]) -> int:
    protocol = load_protocol(protocol_path)
    validate_protocol_shape(protocol)
    validate_invocation("actual_supervisor", observed_argv, protocol)
    if os.name != "nt":
        raise PreflightError("R23 exact process-table runtime is Windows-only")
    if output.resolve() != repo_path(REL_OUTPUT).resolve():
        raise PreflightError("runtime output must equal the single frozen actual leaf")
    if output.exists():
        raise PreflightError("runtime output leaf already exists; choose a new version, never overwrite")
    pins = verify_input_pins(protocol)
    table, audit = _load_r23()
    if tuple(table.WINDOWS_BUILD_PIN) != tuple(protocol["process_table_contract"]["host_build_pin"]):
        raise PreflightError("runtime Windows build pin differs from R23")
    julia = protocol["execution_plan"]["julia_executable"]
    julia_path = Path(julia["path"])
    if not julia_path.is_file() or file_receipt(julia_path)["sha256"] != julia["sha256"]:
        raise PreflightError("pinned Julia executable is missing or changed")
    python_pin = protocol["invocation_contract"]["python_interpreter"]
    python_path = Path(python_pin["path"])
    if not python_path.is_file():
        raise PreflightError("pinned Python supervisor interpreter is unavailable")
    python_receipt = file_receipt(python_path)
    if python_receipt["bytes"] != python_pin["bytes"] or \
            python_receipt["sha256"] != python_pin["sha256"]:
        raise PreflightError("pinned Python supervisor interpreter changed")
    before_snapshot = table.query_native_process_table()
    heavy_before = audit.global_heavy_processes(before_snapshot)
    if heavy_before:
        raise PreflightError("pre-run heavy process inventory is not empty and complete")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir()
    (output / "artifacts").mkdir()
    (output / "prelaunch.json").write_text(json.dumps({
        "schema": "native-g1g2-r29-prelaunch-receipt-v1",
        "created_utc": utc_now(), "protocol_sha256": file_receipt(protocol_path)["sha256"],
        "actual_supervisor_argv": observed_argv, "input_pin_count": pins["checked_count"],
        "input_pins_before": pins, "process_table_before": table.smoke_summary(before_snapshot),
        "global_heavy_before": [list(x) for x in heavy_before],
        "runtime_executed": True, "numerical_credit": False, "physical_credit": False,
    }, indent=2, sort_keys=True), encoding="utf-8")
    environment = _set_environment(protocol)
    commands = planned_stage_commands(protocol, output)
    stages, failure = _run_stage_sequence(output, commands, environment, table, audit)
    if failure is None and len(stages) == len(STAGES):
        artifact = output / "artifacts" / "primary.bin"
        required_artifacts = [artifact, Path(str(artifact) + ".preassert.bin"),
            Path(str(artifact) + ".wrong-sign-preassert.bin"),
            Path(str(artifact) + ".replay-preassert.bin")]
        missing = [str(p) for p in required_artifacts if not p.is_file()]
        if missing:
            failure = "consumer artifact/checkpoint missing: " + ", ".join(missing)
    after_pins = verify_input_pins(protocol)
    after_snapshot = table.query_native_process_table()
    residual_heavy = audit.global_heavy_processes(after_snapshot)
    if residual_heavy:
        failure = failure or "post-run global heavy process inventory is nonempty"
    complete = failure is None and len(stages) == len(STAGES) and \
        all(stage.get("resource_monitor_complete") is True for stage in stages)
    summary = {
        "schema": SUMMARY_SCHEMA, "created_utc": utc_now(),
        "runtime_executed": True,
        "formal_consumer": "NativeG1G2DiffusionCompilerV1 -> GridapNativeG1G2DiffusionAdapterV1",
        "unique_consumer_script": REL_FOCUSED,
        "status": "focused_consumer_pass" if complete else "not_established",
        "failure": failure, "stage_order": [stage["stage"] for stage in stages],
        "stages": stages, "input_pins_before": pins,
        "input_pins_after": after_pins,
        "input_pins_unchanged": pins["checked"] == after_pins["checked"],
        "global_heavy_after": [list(x) for x in residual_heavy],
        "resource_contract": dict(protocol["limits"]),
        "software_status": "pass" if complete else "not_established",
        "focused_assertion_status": "passed" if complete else "not_established",
        "numerical_credit": False,
        "numerical_status": "focused_test_assertions_only" if complete else "not_established",
        "physical_credit": False, "physical_status": "unknown",
        "scientific_status": "not_accepted", "resolution": "terminal_deferred",
        "model_provenance": protocol["model_provenance"],
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True),
                                          encoding="utf-8")
    print(json.dumps({"status": summary["status"], "output": str(output),
        "runtime_executed": True, "completed_stages": summary["stage_order"],
        "failure": failure, "numerical_credit": False, "physical_credit": False}, sort_keys=True))
    return 0 if complete else 1


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dispatch-actual", action="store_true")
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    if not args.dispatch_actual:
        raise PreflightError("runtime dispatch requires explicit --dispatch-actual root-grant invocation")
    protocol_path = Path(args.protocol).resolve()
    output = Path(args.output).resolve()
    observed = list(getattr(sys, "orig_argv", []))
    if not observed:
        observed = [sys.executable, *sys.argv]
    return dispatch_actual(protocol_path, output, observed)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PreflightError as exc:
        print(json.dumps({"status": "preflight_failed", "runtime_executed": False,
                          "error": str(exc), **NO_CREDIT}, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)
