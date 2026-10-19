from __future__ import annotations

import argparse
import ast
from datetime import datetime, timezone
import difflib
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[4]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
from tools.execution.t2_source_inputs import T2SourceInputs

_T2_SOURCE_INPUTS: T2SourceInputs | None = None
_T2_SOURCE_LAYOUT: dict[str, Any] | None = None
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
DRIVER = TEST_ROOT / "actual_formal_negative_driver_r6.jl"
R19_CONTROLLER = TEST_ROOT / "independent_negative_controller_r19.py"
R20_CONTROLLER = TEST_ROOT / "independent_negative_controller_r20.py"
R21_CONTROLLER = TEST_ROOT / "independent_negative_controller_r21.py"
R22_CONTROLLER = TEST_ROOT / "independent_negative_controller_r22.py"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r23.py"
R23_CONTROLLER_PREIMAGE = ROOT / "runs/e/code_consolidation_20260927/t2_controller_before.py"
R23_CONTROLLER_PAIR_PREIMAGE = ROOT / (
    "runs/e/up1_inplace_resume_20260927/controller_a5ba_before_pair.py")
R23_CONTROLLER_MANAGED_PREIMAGE = ROOT / (
    "runs/e/lifecycle_systemic_repair_20260927_r1/live_consumer_integration/"
    "preimages/test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
    "independent_negative_controller_r23.py")
R21_TRACKED_EXIT_TEST = TEST_ROOT / "test_r21_tracked_sample_exit_independent.py"
R21_TRACKED_EXIT_TEST_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/r21_tracked_sample_exit_python_controls_20260926_r2")
R22_PRE_TREE_TEST = TEST_ROOT / "test_r22_pre_tree_tracked_exit_independent.py"
R22_PRE_TREE_TEST_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_python_controls_20260926_r7")
HISTORICAL_CONTROLLER_R12 = TEST_ROOT / "independent_negative_controller_r12.py"
HISTORICAL_CONTROLLER_R13 = TEST_ROOT / "independent_negative_controller_r13.py"
HISTORICAL_CONTROLLER_R14 = TEST_ROOT / "independent_negative_controller_r14.py"
R22_STATIC_QA = TEST_ROOT / "static_qa_independent_negative_r22.py"
STATIC_QA = TEST_ROOT / "static_qa_independent_negative_r23.py"
R10_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r10.py"
R11_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r11.py"
R12_PROJECTION_REUSE_VALIDATOR = TEST_ROOT / "validate_projection24_reuse_r12.py"
R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE = ROOT / (
    "runs/e/projection_reuse_r12_adapter_r1/"
    "validate_projection24_reuse_r12.preimage")
PROJECTION_REUSE_VALIDATOR = R12_PROJECTION_REUSE_VALIDATOR
MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS = (
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
HISTORICAL_PROJECTION_REUSE_VALIDATOR_R5 = TEST_ROOT / "validate_projection24_reuse_r5.py"
HISTORICAL_PROJECTION_REUSE_VALIDATOR_R6 = TEST_ROOT / "validate_projection24_reuse_r6.py"
HISTORICAL_PROJECTION_REUSE_VALIDATOR_R7 = TEST_ROOT / "validate_projection24_reuse_r7.py"
HISTORICAL_ATTEMPT3_LAUNCHER = TEST_ROOT / "frozen_launcher_attempt3.ps1"
OLD_SUITE = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "vnext_t2_identity_receipt_v2_tests.jl")
PROJECTION_SUITE = ROOT / (
    "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
    "vnext_t2_package_full_content_projection_r1.jl")
T1_MANIFEST = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T1/"
    "formal_software_acceptance_r26_v9_r1/software_acceptance_manifest.json")
V3_QUALIFICATION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/"
    "software_acceptance_runtime_r5_r1/software_qualification.json")
R1_FAILURE_EVIDENCE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_independent_negative_r1")
R1_TIMEOUT_RECEIPT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_actual_r1_timeout_20260922/execution_receipt.json")
R1_SOURCE_PROTOCOL = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "independent_negative_dispatch_r1/protocol.json")
R1_PIPELINE_FINAL = R1_FAILURE_EVIDENCE / "pipeline_final.json"
R1_PROJECTION_DIR = R1_FAILURE_EVIDENCE / \
    "package_full_content_projection_regression"
R1_PROJECTION_PHASE_FILES = {
    "phase": R1_PROJECTION_DIR / "phase.json",
    "actual_observation": R1_PROJECTION_DIR / "actual_observation.json",
    "samples": R1_PROJECTION_DIR / "samples.jsonl",
    "stdout": R1_PROJECTION_DIR / "stdout.raw",
    "stderr": R1_PROJECTION_DIR / "stderr.raw",
}
PROJECTION_PASS_MARKER = \
    "T2_PROJECTION24_REUSE=PASS sites=24 groups=4"
ACTIVE_GUIDANCE = (
    ROOT / "docs/v4_multitopology_generation/README.md",
    ROOT / "docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md",
    ROOT / "docs/v4_multitopology_generation/10_genome_upgrade_execution.md",
    ROOT / "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
    ROOT / "docs/v4_multitopology_generation/16_execution_work_orders.md",
    ROOT / "docs/v4_multitopology_generation/21_next_execution_batches.md",
    ROOT / "docs/v4_multitopology_generation/22_agent_local_execution.md",
    ROOT / "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md",
    ROOT / "docs/v4_multitopology_generation/task_manifest.json",
)
PLANNING_REFRESH = ROOT / (
    "docs/v4_multitopology_generation/planning_refresh_20260926.json")
PLANNING_VALIDATION = ROOT / (
    "docs/v4_multitopology_generation/planning_validation_20260926.json")
PLANNING_MIGRATION_INPUTS = {
    "docs/v4_multitopology_generation/16_execution_work_orders.md":
        "16_execution_work_orders.md",
    "docs/v4_multitopology_generation/21_next_execution_batches.md":
        "21_next_execution_batches.md",
    "docs/v4_multitopology_generation/22_agent_local_execution.md":
        "22_agent_local_execution.md",
    "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md":
        "25_astra_execution_and_recovery.md",
    "docs/v4_multitopology_generation/README.md": "README.md",
    "docs/v4_multitopology_generation/task_manifest.json":
        "task_manifest.json",
}
PLANNING_REFRESH_SHA256 = (
    "582312eeb33e863f4996c6dd322c26388155b275a03238d21d5939359d57080a")
PLANNING_VALIDATION_SHA256 = (
    "a6241b8c763e1d4ce47f055c9bbbc301ec147a66e1fed6645503fb423093551d")
PLANNING_RETAINED_CONTRACT_SHA256 = (
    "550716a845f5986e4fa873a099c406c9f3e69c38f640f7c6a58452e0b1a5db3c")
ARCHIVE_COVERAGE = Path(
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r16.json")
R23_TABLE = ROOT / (
    "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py")
R23_SUPERVISOR = ROOT / (
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py")
R23_TEST_SUITE = ROOT / (
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r23_v1.py")
R20_HOST_SMOKE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r20_native_monitor_host_smoke_20260926_r9")
R20_HOST_SMOKE_RUNNER = TEST_ROOT / "r20_native_monitor_host_smoke_r9.py"
R22_HOST_SMOKE_RUNNER = TEST_ROOT / "r22_pre_tree_tracked_exit_host_smoke_r2.py"
R22_HOST_SMOKE_FIXTURE = TEST_ROOT / "r22_pre_tree_tracked_exit_host_fixture.py"
R22_HOST_SMOKE_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_20260926_r3")
R22_HOST_SMOKE_LAUNCHER_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_launcher_20260926_r3")
R22_HOST_SMOKE_INVOCATION_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r22_pre_tree_tracked_exit_host_smoke_invocation_20260926_r3")
R22_PRIOR_FORMAL_FAILURE_PROTOCOL = ROOT / (
    "runs/UP1-04A-VNEXT-T2/"
    "r7_protocol_freeze_20260926_t2_protocol_r22_pre_tree_r3/protocol.json")
R22_PRIOR_FORMAL_FAILURE_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r22_r10_r3")
R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF = ROOT / (
    "runs/UP1-04A-VNEXT-T2/formal_launcher_r22_r10_r3_20260926_r1")
R22_PRIOR_FORMAL_FAILURE_SNAPSHOT = R22_PRIOR_FORMAL_FAILURE_LEAF / (
    "source_snapshots_r22_actual_failure_20260926_r1")
R22_HOST_SMOKE_LAUNCHER_SHA256 = (
    "2a44d7d9e4e75a6bc39a1e17fe99430b0cc983e5dc843a6f5ebf5c159c75ef9f")
R22_HOST_SMOKE_QA_SNAPSHOT = R22_HOST_SMOKE_LAUNCHER_LEAF / \
    "pre_host_static_qa_r22.py"
R20_HOST_SMOKE_CONTROLLER_SOURCE = ROOT / (
    "runs/UP1-04A-VNEXT-T2/source_snapshots/"
    "controller_r20_pre_runs_path_gate_c1607.py")
R20_HOST_SMOKE_FAILURE_LEAVES = {
    f"r{index}": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        f"r20_native_monitor_host_smoke_20260926_r{index}")
    for index in range(1, 9)
}
R20_HOST_SMOKE_FAILURE_EXPECTATIONS = {
    "r1": (19, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "controlled descendant did not exit before the real registry OpenProcess"),
    "r2": (23, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "R20 recovery lost the exact PID/raw FILETIME from the before-SPI row"),
    "r3": (21, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "controlled descendant did not exit before real OpenProcess/liveness binding"),
    "r4": (24, "vnext-t2-r20-native-monitor-host-smoke-r1",
           "R20 did not discard all partial first-attempt metrics before a fresh full retry"),
    "r5": (31, "vnext-t2-r20-native-monitor-host-smoke-r5",
           "R20 did not discard all partial first-attempt metrics before a fresh full retry"),
    "r6": (52, "vnext-t2-r20-native-monitor-host-smoke-r6",
           "failed-open orphan cleanup was reported as complete or left a root descendant"),
    "r7": (104, "vnext-t2-r20-native-monitor-host-smoke-r7",
           "orphan control did not remain an incomplete non-retry failed-open sample"),
    "r8": (39, "vnext-t2-r20-native-monitor-host-smoke-r8",
           "R20 race phase did not retain exactly one source-row recovery receipt"),
}
R17_BASELINE_GATE_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r17_r23_r8")
R17_BASELINE_GATE_FAILURE_FILES = {
    "pipeline_start": R17_BASELINE_GATE_FAILURE_LEAF / "pipeline_start.json",
    "pipeline_final": R17_BASELINE_GATE_FAILURE_LEAF / "pipeline_final.json",
}
R18_SUPERSEDED_MAP_EXPERIMENT_FILES = (
    TEST_ROOT / "build_coverage_map_r18.py",
    TEST_ROOT / "coverage_map_r17.json",
)
R18_RETRY1_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r18_baseline_audit_retry1")
R19_RETRY1_PROJECTION_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry1")
R19_RETRY2_STATIC_QA_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r19_snapshot_receipt_retry2")
R18_FREEZE_RETRY2_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260925_t2_protocol_r18_baseline_audit_retry2")
R18_PREDICATE_TESTER_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_t2_r18_audit_predicate_tester_20260925")
R18_REVIEW_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt11_r18_prelaunch_review_20260925_r1")
R18_PREDICATE_TESTER_SOURCE = ROOT / (
    "test/GenomeV5/Integration/VNextT2AuditIndependentR18/"
    "test_r18_audit_predicate.py")
R17_HOST_SMOKE_RETRY_LEAVES = {
    "r5": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r17_native_monitor_host_smoke_20260925_r5"),
    "r6": ROOT / (
        "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "r17_native_monitor_host_smoke_20260925_r6"),
}
ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s")
ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES = {
    "freeze_failure": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freeze_failure.json",
    "stdout": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freezer.stdout.raw",
    "stderr": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "freezer.stderr.raw",
    "coverage_map": ATTEMPT11_INITIAL_FREEZE_FAILURE_LEAF / "coverage_map_r8.json",
}
ATTEMPT11_RETRY1_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry1")
ATTEMPT11_RETRY1_FAILURE = ATTEMPT11_RETRY1_FAILURE_LEAF / "static_qa_failure.json"
ATTEMPT11_RETRY2_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry2")
ATTEMPT11_RETRY2_FAILURE_FILES = {
    "command_argv.json", "coverage_map_r8.json", "dispatch.json",
    "protocol.json", "static_qa.json", "static_qa.stderr.raw",
    "static_qa.stdout.raw",
    "projection24_reuse_preflight/phase.json",
    "projection24_reuse_preflight/reuse_receipt.json",
    "projection24_reuse_preflight/stderr.raw",
    "projection24_reuse_preflight/stdout.raw",
}
ATTEMPT11_RETRY4_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry4")
ATTEMPT11_RETRY4_FAILURE_FILES = {
    "protocol": ATTEMPT11_RETRY4_FAILURE_LEAF / "protocol.json",
    "phase": ATTEMPT11_RETRY4_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json",
    "stdout": ATTEMPT11_RETRY4_FAILURE_LEAF /
        "projection24_reuse_preflight/stdout.raw",
    "stderr": ATTEMPT11_RETRY4_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw",
}
ATTEMPT11_RETRY3_NO_GO_ROOT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "root_attempt11_retry3_static_no_go_20260924")
ATTEMPT11_RETRY3_REVIEW_ROOT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_t2_attempt11_retry3_static_review_20260924")
ATTEMPT11_RETRY3_TESTER_ROOT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt11_retry3_static_review_20260924")
ATTEMPT11_RETRY3_NO_GO_EXPECTED = {
    "decision": "17627d424287ebb78fc4c68a274103204b9319174fe2e383340f2614ab2a307e",
    "reviewer_report": "1850362826c4ce87d95b4a91b68b28833a9dc22dbfea94d9158108d5664a34ed",
    "reviewer_manifest": "350e74139dabb32aa02e6a7a286beaa7059cfd97b36fb814a63c49a192a4c68e",
    "tester_report": "8a16c369a6f1cbd2e6ea980db293d3ad3717b82f71991f91bdb30ee732480f0f",
}
ATTEMPT7_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt7")
ATTEMPT7_EXECUTION = ATTEMPT7_ARCHIVE_LEAF / "actual_negative_execution_r2"
ATTEMPT7_BASELINE = ATTEMPT7_EXECUTION / "actual_formal_baseline"
ATTEMPT7_COVERAGE = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
ATTEMPT10_EXECUTION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_actual_negative_r5_attempt10_case_progress")
ATTEMPT10_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress")
ATTEMPT10_FAILURE_FILES = {
    "attempt10_protocol": ATTEMPT10_ARCHIVE_LEAF / "protocol.json",
    "attempt10_coverage_map": ATTEMPT10_ARCHIVE_LEAF / "coverage_map_r7.json",
    "pipeline_start": ATTEMPT10_EXECUTION / "pipeline_start.json",
    "pipeline_final": ATTEMPT10_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT10_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT10_EXECUTION /
        "actual_formal_baseline/artifacts/summary.json",
    "preflight_phase": ATTEMPT10_EXECUTION / "actual_formal_preflight/phase.json",
    "preflight_stdout": ATTEMPT10_EXECUTION / "actual_formal_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT10_EXECUTION / "actual_formal_preflight/stderr.raw",
    "preflight_samples": ATTEMPT10_EXECUTION / "actual_formal_preflight/samples.jsonl",
    "preflight_observations": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/observations.jsonl",
    "preflight_stage_trace": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/stage_trace.tsv",
    "preflight_transport_observation": ATTEMPT10_EXECUTION /
        "actual_formal_preflight/artifacts/context_transport_observation.json",
}
ATTEMPT10_LINEAGE_FILES = {
    "root_observation": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "root_attempt10_postrun_observation_20260924/observation.json",
        "6711e3cdd06faf20180651b1ec678f57409b728dc44dd3373657bb21c29c69e3"),
    "root_decision": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "root_attempt10_postrun_observation_20260924/decision.md",
        "1aa6725c461350b30cf287e38bafb913ee80faca3d0ee6cea04e5549a0c2b35b"),
    "independent_review": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "independent_attempt10_postrun_review_20260924/review.json",
        "d800a165ecf9386f8d32ce1ed32193a6d8df18b6855f90a9f7a1289e2ac19892"),
    "independent_tester_review": (
        ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/"
        "independent_attempt10_postrun_tester_20260924/"
        "attempt10_postrun_independent_review.json",
        "3a3d28f4c7c0eba74d12a4dca9ac06e0cbf95c09797e64a4d5e4a42e80b5429d"),
}
ATTEMPT9C_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9c_final")
ATTEMPT9C_EXECUTION = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_actual_negative_r4_attempt9c_final")
ATTEMPT9C_FAILURE_FILES = {
    "archive_protocol": ATTEMPT9C_ARCHIVE_LEAF / "protocol.json",
    "archive_coverage_map": ATTEMPT9C_ARCHIVE_LEAF / "coverage_map_r3.json",
    "pipeline_start": ATTEMPT9C_EXECUTION / "pipeline_start.json",
    "pipeline_final": ATTEMPT9C_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT9C_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT9C_EXECUTION / "actual_formal_baseline/artifacts/summary.json",
    "baseline_context": ATTEMPT9C_EXECUTION / "actual_formal_baseline/artifacts/baseline_context.jls",
    "baseline_authorization": ATTEMPT9C_EXECUTION / "actual_formal_baseline_authorization.json",
    "authority_phase": ATTEMPT9C_EXECUTION / "actual_formal_authority/phase.json",
    "authority_stdout": ATTEMPT9C_EXECUTION / "actual_formal_authority/stdout.raw",
    "authority_stderr": ATTEMPT9C_EXECUTION / "actual_formal_authority/stderr.raw",
    "authority_samples": ATTEMPT9C_EXECUTION / "actual_formal_authority/samples.jsonl",
    "authority_observations": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/observations.jsonl",
    "authority_transport": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/context_transport_observation.json",
    "authority_stage_trace": ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/stage_trace.tsv",
}
ATTEMPT8_ARCHIVE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt8_final2")
ATTEMPT8_EXECUTION = ATTEMPT8_ARCHIVE_LEAF / "actual_negative_execution_r3"
ATTEMPT8_FAILURE_FILES = {
    "protocol": ATTEMPT8_ARCHIVE_LEAF / "protocol.json",
    "dispatch": ATTEMPT8_ARCHIVE_LEAF / "dispatch.json",
    "pipeline_final": ATTEMPT8_EXECUTION / "pipeline_final.json",
    "baseline_phase": ATTEMPT8_EXECUTION / "actual_formal_baseline/phase.json",
    "baseline_summary": ATTEMPT8_EXECUTION /
        "actual_formal_baseline/artifacts/summary.json",
    "baseline_authorization": ATTEMPT8_EXECUTION /
        "actual_formal_baseline_authorization.json",
    "preflight_phase": ATTEMPT8_EXECUTION /
        "actual_formal_preflight/phase.json",
    "preflight_stderr": ATTEMPT8_EXECUTION /
        "actual_formal_preflight/stderr.raw",
}
ATTEMPT8_EXPECTED_DRIVER_ERROR = (
    "ERROR: LoadError: expected mode, four authority path/hash pairs, "
    "context path/hash, authorization path/hash, output dir, coverage map path/hash")
ATTEMPT11_RETRY8_FREEZE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry8")
ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "root_attempt11_retry8_runtime_grant_20260924")
ATTEMPT11_RETRY8_REVIEW_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_attempt11_retry8_postrun_pid0_review_20260924_r1")
ATTEMPT11_RETRY8_REVIEW_SHA256 = (
    "c4783c7f4fbd0590482406426f03c49aa9f727858d26a7c4060824588526ad04")
ATTEMPT11_RETRY8_ROOT_OUTPUT = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/"
    "formal_t2_actual_negative_r6_attempt11_retry8")
ATTEMPT11_RETRY8_ROOT_FAILURE_FILES = {
    "start": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "start.json",
    "invocation": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "invocation.json",
    "stdout": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "invocation.stdout.raw",
    "stderr": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "invocation.stderr.raw",
    "exit": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "invocation.exit.txt",
    "decision": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "decision.md",
    "postrun_assessment": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF /
        "postrun_assessment.md",
    "run_once": ATTEMPT11_RETRY8_ROOT_FAILURE_LEAF / "run_once.py",
}
ATTEMPT9_FIRST_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9")
ATTEMPT9_FIRST_FAILURE_FILES = {
    "protocol": ATTEMPT9_FIRST_FAILURE_LEAF / "protocol.json",
    "coverage_map": ATTEMPT9_FIRST_FAILURE_LEAF / "coverage_map_r3.json",
    "preflight_phase": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json",
    "preflight_stdout": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw",
}
ATTEMPT9_EXPECTED_VALIDATOR_ERROR = \
    "RuntimeError: projection reuse protocol schema mismatch"
ATTEMPT9B_FAILURE_LEAF = ROOT / (
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol_attempt9b")
ATTEMPT9B_FAILURE_FILES = {
    "protocol": ATTEMPT9B_FAILURE_LEAF / "protocol.json",
    "coverage_map": ATTEMPT9B_FAILURE_LEAF / "coverage_map_r3.json",
    "dispatch": ATTEMPT9B_FAILURE_LEAF / "dispatch.json",
    "command": ATTEMPT9B_FAILURE_LEAF / "command_argv.json",
    "preflight_phase": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json",
    "preflight_receipt": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/reuse_receipt.json",
    "preflight_stdout": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/stdout.raw",
    "preflight_stderr": ATTEMPT9B_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw",
    "static_qa": ATTEMPT9B_FAILURE_LEAF / "static_qa.json",
    "static_qa_stdout": ATTEMPT9B_FAILURE_LEAF / "static_qa.stdout.raw",
    "static_qa_stderr": ATTEMPT9B_FAILURE_LEAF / "static_qa.stderr.raw",
}
ATTEMPT9B_EXPECTED_QA_FAILURE = {
    "type": "KeyError", "message": "'manifest_path'",
}
GENERATED_PYTHON_CACHE = {
    "freeze_independent_negative_protocol_r3.cpython-313.pyc": {
        "bytes": 48089,
        "sha256": "ebc3c1cfc31b7acf306d5f9addfaff5e45ca4a6772877585148a7df57d897608",
    },
    "static_qa_independent_negative_r3.cpython-313.pyc": {
        "bytes": 72660,
        "sha256": "30cf8b444ec15c98e018a8cfb261e650acc61cf431e83ef65d59535cc5e51e4b",
    },
}
PHASE_ORDER = [
    "parse_gate", "coverage_ast_inventory", "projection24_cross_run_validation",
    "actual_formal_baseline", "actual_formal_preflight",
    "actual_formal_authority", "actual_formal_fault_n10",
    "actual_formal_t1_handoff", "supplementary_edited_operation",
    "supplementary_child_coupling", "artifact_hash_precondition",
    "artifact_recomputed_corrupt", "artifact_zero_malformed",
    "artifact_attack_fixture_generation",
    "formal_driver_artifact_raw_hash_precondition",
    "formal_driver_artifact_deserialize_precondition",
    "formal_driver_artifact_zero_precondition",
    "formal_driver_artifact_wrong_type_precondition",
    "formal_driver_artifact_foreign_package_precondition",
    "preexisting_candidate_package_jls",
    "preexisting_candidate_t1_admission_receipt_json",
    "preexisting_t2_result_jls", "preexisting_run_receipt_json",
    "preexisting_replay_uncommitted_attempt_json",
    "preexisting_prior_success_set", "preexisting_prior_uncommitted",
    "preexisting_symlink_owned_target", "candidate_receipt_precondition",
    "serialized_result_postcondition", "stable_projection_postcondition",
]
CHILD_PHASE_BINDINGS = {
    "parse_gate": "PARSE_GATE",
    "coverage_ast_inventory": "AST_INVENTORY_DRIVER",
    "projection24_cross_run_validation": "PROJECTION_REUSE_VALIDATOR",
    "actual_formal_baseline": "ACTUAL_DRIVER",
    "actual_formal_preflight": "ACTUAL_DRIVER",
    "actual_formal_authority": "ACTUAL_DRIVER",
    "actual_formal_fault_n10": "ACTUAL_DRIVER",
    "actual_formal_t1_handoff": "ACTUAL_DRIVER",
    "supplementary_edited_operation": "SUPPLEMENTARY_DRIVER",
    "supplementary_child_coupling": "SUPPLEMENTARY_DRIVER",
    "artifact_hash_precondition": "ARTIFACT_DRIVER",
    "artifact_recomputed_corrupt": "ARTIFACT_DRIVER",
    "artifact_zero_malformed": "ARTIFACT_DRIVER",
    "artifact_attack_fixture_generation": "ATTACK_FIXTURE_DRIVER",
    "formal_driver_artifact_raw_hash_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_deserialize_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_zero_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_wrong_type_precondition": "CANDIDATE_DRIVER",
    "formal_driver_artifact_foreign_package_precondition": "CANDIDATE_DRIVER",
    "preexisting_candidate_package_jls": "CANDIDATE_DRIVER",
    "preexisting_candidate_t1_admission_receipt_json": "CANDIDATE_DRIVER",
    "preexisting_t2_result_jls": "CANDIDATE_DRIVER",
    "preexisting_run_receipt_json": "CANDIDATE_DRIVER",
    "preexisting_replay_uncommitted_attempt_json": "CANDIDATE_DRIVER",
    "preexisting_prior_success_set": "CANDIDATE_DRIVER",
    "preexisting_prior_uncommitted": "CANDIDATE_DRIVER",
    "preexisting_symlink_owned_target": "CANDIDATE_DRIVER",
    "candidate_receipt_precondition": "CANDIDATE_DRIVER",
    "serialized_result_postcondition": "CANDIDATE_DRIVER",
    "stable_projection_postcondition": "CANDIDATE_DRIVER",
}
CHILD_BINDING_PATHS = {
    "PARSE_GATE": (
        "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl"),
    "AST_INVENTORY_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "coverage_ast_inventory_r3.jl"),
    "PROJECTION_REUSE_VALIDATOR": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "validate_projection24_reuse_r12.py"),
    "ACTUAL_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "actual_formal_negative_driver_r6.jl"),
    "SUPPLEMENTARY_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "supplementary_contract_driver_r1.jl"),
    "ARTIFACT_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "artifact_preflight_negative_driver_r1.jl"),
    "ATTACK_FIXTURE_DRIVER": (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "artifact_attack_fixture_driver_r1.jl"),
    "CANDIDATE_DRIVER": (
        "test/GenomeV5/Integration/VNextT2IdentityReceiptV2/"
        "formal_candidate_driver.jl"),
}


def build_controller_child_script_plan() -> dict[str, Any]:
    if list(CHILD_PHASE_BINDINGS) != PHASE_ORDER or \
            set(CHILD_BINDING_PATHS) != set(CHILD_PHASE_BINDINGS.values()):
        raise RuntimeError("controller child script plan does not cover phase order")
    phase_to_paths = {
        phase: [CHILD_BINDING_PATHS[binding]]
        for phase, binding in CHILD_PHASE_BINDINGS.items()
    }
    unique_paths = list(dict.fromkeys(
        path for phase in PHASE_ORDER for path in phase_to_paths[phase]))
    return {
        "schema": "vnext-t2-controller-child-script-plan-r2",
        "phase_count": len(PHASE_ORDER),
        "unique_script_count": len(unique_paths),
        "phase_ids": list(PHASE_ORDER),
        "script_paths": unique_paths,
        "phase_to_script_paths": phase_to_paths,
        "python_child_phase_ids": ["projection24_cross_run_validation"],
        "dynamic_python_imports_in_controller": [],
    }


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _source_inputs() -> T2SourceInputs:
    global _T2_SOURCE_INPUTS
    if _T2_SOURCE_INPUTS is None:
        _T2_SOURCE_INPUTS = T2SourceInputs(ROOT)
    return _T2_SOURCE_INPUTS


def _source_layout() -> dict[str, Any]:
    global _T2_SOURCE_LAYOUT
    if _T2_SOURCE_LAYOUT is None:
        _T2_SOURCE_LAYOUT = _source_inputs().describe()
    return _T2_SOURCE_LAYOUT


def _historical_expected_receipt(path: Path) -> dict[str, Any] | None:
    sources = _source_inputs()
    relative = sources.logical_path(path)
    return _source_layout()["historical_source_data"].get(relative)


def read_source_text(path: Path, encoding: str = "utf-8") -> str:
    sources = _source_inputs()
    layout = _source_layout()
    expected = _historical_expected_receipt(path)
    if expected is not None:
        text = sources.read_historical_text(
            path, layout["snapshot_id"], expected, encoding=encoding,
            errors="strict")
    else:
        text = sources.read_text(path, encoding=encoding, errors="strict")
    return text.replace("\r\n", "\n").replace("\r", "\n")


def receipt(path: Path) -> dict[str, Any]:
    sources = _source_inputs()
    layout = _source_layout()
    expected = _historical_expected_receipt(path)
    if expected is not None:
        return sources.historical_receipt(path, layout["snapshot_id"], expected)
    return sources.receipt(path)


def r22_projection_validator_source_bindings(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    """Bind R22 execution identity to its sealed bytes without aliasing live code."""
    add_input(inputs, R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE)
    add_input(inputs, PROJECTION_REUSE_VALIDATOR)
    preimage_data_input = receipt(R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE)
    current_live_input = receipt(PROJECTION_REUSE_VALIDATOR)
    expected_preimage = {
        "path": R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE.relative_to(ROOT).as_posix(),
        "bytes": 13712,
        "sha256": "04f3cf18221b69942815a8fd4d724e956ae3a230077200a24c49d57474344d41",
    }
    expected_current_input = {
        "path": PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        "bytes": 17370,
        "sha256": "5c0082bbdf4dd6f98ebe806564c4b4c9d36572f8b9cb249a644ccd20e74467d1",
    }
    if preimage_data_input != expected_preimage:
        raise RuntimeError("sealed R12 validator preimage identity changed")
    historical_executed_source = {
        "path": PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        "bytes": preimage_data_input["bytes"],
        "sha256": preimage_data_input["sha256"],
    }
    if inputs.get(preimage_data_input["path"]) != preimage_data_input or \
            inputs.get(current_live_input["path"]) != current_live_input or \
            current_live_input["path"] != historical_executed_source["path"] or \
            current_live_input != expected_current_input or \
            current_live_input["sha256"] == historical_executed_source["sha256"]:
        raise RuntimeError("R22 historical validator and current input roles are not distinct")
    return {
        "historical_executed_source": historical_executed_source,
        "sealed_preimage_data_input": preimage_data_input,
        "current_input": current_live_input,
        "historical_execution_allowed": False,
    }


def generated_python_cache_exclusions() -> list[dict[str, Any]]:
    cache_dir = TEST_ROOT / "__pycache__"
    if not cache_dir.is_dir():
        raise RuntimeError("expected generated Python cache directory is absent")
    entries = sorted(cache_dir.rglob("*"))
    files = [path for path in entries if path.is_file()]
    if any(not path.is_file() for path in entries) or \
            [path.name for path in files] != sorted(GENERATED_PYTHON_CACHE):
        raise RuntimeError("generated Python cache inventory gained/lost a file")
    rows = [receipt(path) for path in files]
    for row in rows:
        expected = GENERATED_PYTHON_CACHE[Path(row["path"]).name]
        if row["bytes"] != expected["bytes"] or \
                row["sha256"] != expected["sha256"]:
            raise RuntimeError("generated Python cache bytes/SHA changed")
    return rows


def load_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise RuntimeError(f"expected JSON object: {path}")
    return value


def assertion_expression(lines: list[str], line_number: int) -> str:
    line = lines[line_number - 1]
    stripped = line.lstrip()
    indent = len(line) - len(stripped)
    body = [stripped]
    cursor = line_number
    while cursor < len(lines):
        candidate = lines[cursor]
        candidate_stripped = candidate.lstrip()
        candidate_indent = len(candidate) - len(candidate_stripped)
        if not candidate_stripped or candidate_stripped.startswith("#") or \
                candidate_indent <= indent:
            break
        body.append(candidate_stripped)
        cursor += 1
    return " ".join(part.strip() for part in body)


def write_json_new(path: Path, value: Any) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def files_under(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path
        return
    if not path.is_dir():
        raise FileNotFoundError(path)
    yield from sorted(item for item in path.rglob("*") if item.is_file())


def add_input(inputs: dict[str, dict[str, Any]], path: Path) -> None:
    row = receipt(path)
    old = inputs.get(row["path"])
    if old is not None and old != row:
        raise RuntimeError(f"input changed while freezing: {row['path']}")
    inputs[row["path"]] = row


def build_r20_host_smoke_failure_lineage(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    attempts: dict[str, Any] = {}
    for label, leaf in R20_HOST_SMOKE_FAILURE_LEAVES.items():
        expected_count, expected_schema, expected_message = \
            R20_HOST_SMOKE_FAILURE_EXPECTATIONS[label]
        paths = list(files_under(leaf))
        if len(paths) != expected_count:
            raise RuntimeError(f"R20 host smoke {label} recursive file count changed")
        rows: dict[str, dict[str, Any]] = {}
        for path in paths:
            add_input(inputs, path)
            rows[path.relative_to(leaf).as_posix()] = receipt(path)
        command = load_object(leaf / "command_argv.json")
        result = load_object(leaf / "exit_code.json")
        stdout = load_object(leaf / "stdout.raw")
        assertion = stdout.get("smoke_assertion")
        if command.get("kind") != "python_only_host_supervisor_smoke" or \
                command.get("julia_started") is not False or \
                command.get("formal_t2_accepted") is not False or \
                result.get("exit_code") != 1 or result.get("status") != "fail" or \
                result.get("julia_started") is not False or \
                result.get("formal_t2_accepted") is not False or \
                stdout.get("schema") != expected_schema or \
                stdout.get("julia_started") is not False or \
                stdout.get("formal_t2_accepted") is not False or \
                not isinstance(assertion, dict) or \
                assertion.get("type") != "RuntimeError" or \
                assertion.get("message") != expected_message:
            raise RuntimeError(f"R20 host smoke {label} failure receipt drift")
        attempts[label] = {
            "leaf": leaf.relative_to(ROOT).as_posix(),
            "file_count": len(rows),
            "file_receipts": rows,
            "exit_code": result["exit_code"],
            "status": result["status"],
            "stdout_schema": stdout["schema"],
            "failure_message": assertion["message"],
            "julia_started": False,
            "formal_t2_accepted": False,
        }
    return {
        "schema": "vnext-t2-r20-native-monitor-host-smoke-failure-lineage-r1",
        "attempt_count": len(attempts),
        "attempts": attempts,
        "failure_evidence_overwritten": False,
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def build_r20_host_smoke_receipt(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    paths = list(files_under(R20_HOST_SMOKE_LEAF))
    if len(paths) != 63:
        raise RuntimeError("R9 host smoke recursive file count changed")
    rows: dict[str, dict[str, Any]] = {}
    for path in paths:
        add_input(inputs, path)
        rows[path.relative_to(R20_HOST_SMOKE_LEAF).as_posix()] = receipt(path)
    for path in (R20_HOST_SMOKE_RUNNER, R20_HOST_SMOKE_CONTROLLER_SOURCE):
        add_input(inputs, path)

    command = load_object(R20_HOST_SMOKE_LEAF / "command_argv.json")
    result = load_object(R20_HOST_SMOKE_LEAF / "exit_code.json")
    payload = load_object(R20_HOST_SMOKE_LEAF / "stdout.raw")
    expected_raw_controller = {
        "path": R20_CONTROLLER.relative_to(ROOT).as_posix(),
        "bytes": 326817,
        "sha256": "c1607fc4508356366e9eee350582dd9df2248b3b89022ce4ea43928d1148d9b4",
    }
    raw_controller = receipt(R20_HOST_SMOKE_CONTROLLER_SOURCE)
    source_before = payload.get("source_pins_before")
    source_after = payload.get("source_pins_after")
    if raw_controller["bytes"] != expected_raw_controller["bytes"] or \
            raw_controller["sha256"] != expected_raw_controller["sha256"] or \
            not isinstance(source_before, dict) or source_before != source_after or \
            source_before.get("controller") != expected_raw_controller or \
            command.get("source_pins_before") != source_before or \
            command.get("source_pins_after") != source_after or \
            command.get("controller_sha256") != raw_controller["sha256"] or \
            result.get("source_pins_after") != source_after:
        raise RuntimeError("R9 raw controller source witness/pin is incomplete")

    raw_source_paths = {
        "controller": R20_CONTROLLER,
        "native_process_table": R23_TABLE,
        "runner": R20_HOST_SMOKE_RUNNER,
        "supervisor": R23_SUPERVISOR,
        "test_suite_source": R23_TEST_SUITE,
    }
    for name, path in raw_source_paths.items():
        raw_pin = source_before.get(name)
        source_receipt = receipt(path)
        if not isinstance(raw_pin, dict) or \
                raw_pin.get("path") != source_receipt["path"] or \
                raw_pin.get("bytes") != source_receipt["bytes"] or \
                raw_pin.get("sha256") != source_receipt["sha256"]:
            if name == "controller":
                continue
            raise RuntimeError(f"R9 host smoke source pin drift: {name}")

    if command.get("kind") != "python_only_host_supervisor_smoke" or \
            command.get("julia_started") is not False or \
            command.get("formal_t2_accepted") is not False or \
            result.get("exit_code") != 0 or \
            result.get("status") != "pass_python_only" or \
            result.get("julia_started") is not False or \
            result.get("formal_t2_accepted") is not False or \
            payload.get("schema") != "vnext-t2-r20-native-monitor-host-smoke-r9" or \
            payload.get("source_pins_stable") is not True or \
            payload.get("julia_started") is not False or \
            payload.get("formal_t2_accepted") is not False:
        raise RuntimeError("R9 host smoke raw exit/stdout does not prove bounded pass")

    return {
        "schema": payload["schema"],
        "status": result["status"],
        "exit_code": result["exit_code"],
        "leaf": R20_HOST_SMOKE_LEAF.relative_to(ROOT).as_posix(),
        "file_count": len(rows),
        "files": rows,
        "command": receipt(R20_HOST_SMOKE_LEAF / "command_argv.json"),
        "stdout": receipt(R20_HOST_SMOKE_LEAF / "stdout.raw"),
        "stderr": receipt(R20_HOST_SMOKE_LEAF / "stderr.raw"),
        "exit": receipt(R20_HOST_SMOKE_LEAF / "exit_code.json"),
        "runner": receipt(R20_HOST_SMOKE_RUNNER),
        "raw_controller_source": raw_controller,
        "current_controller": receipt(R20_CONTROLLER),
        "controller_source_snapshot": raw_controller,
        "native_process_table": receipt(R23_TABLE),
        "supervisor": receipt(R23_SUPERVISOR),
        "test_suite_source": receipt(R23_TEST_SUITE),
        "source_pins_before": source_before,
        "source_pins_after": source_after,
        "source_pins_stable": True,
        "independent_review": {
            "status": "GO",
            "scope": "R9 host smoke as a freezer input only",
            "basis": "root-confirmed independent raw R9 review",
            "formal_t2_execution_authorized": False,
            "review_artifact_pinned_in_repository": False,
        },
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def build_r20_runs_only_path_gate_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    before_path = R20_HOST_SMOKE_CONTROLLER_SOURCE
    current_path = R20_CONTROLLER
    add_input(inputs, before_path)
    add_input(inputs, current_path)
    before_text = read_source_text(before_path)
    current_text = read_source_text(current_path)
    before_tree = ast.parse(before_text)
    current_tree = ast.parse(current_text)
    expected_changed = [
        "main", "require_t2_execution_leaf", "verify_authority_resume_ancestry",
    ]
    before_functions = {
        node.name: node for node in before_tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    current_functions = {
        node.name: node for node in current_tree.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in before_functions.keys() | current_functions.keys()
                     if before_functions.get(name) is None or
                     current_functions.get(name) is None or
                     ast.dump(before_functions[name], include_attributes=False) !=
                     ast.dump(current_functions[name], include_attributes=False))

    path_root = next((node for node in current_tree.body
                      if isinstance(node, (ast.Assign, ast.AnnAssign)) and
                      "T2_RAW_EVIDENCE_ROOT" in ast.unparse(node)), None)
    path_helper = current_functions.get("require_t2_execution_leaf")
    path_calls = [node for node in ast.walk(current_tree)
                  if isinstance(node, ast.Call) and
                  isinstance(node.func, ast.Name) and
                  node.func.id == "require_t2_execution_leaf"]
    call_sites = sorted(ast.unparse(node.args[0]) for node in path_calls
                        if len(node.args) == 1)
    if changed != expected_changed or path_root is None or path_helper is None or \
            ast.unparse(path_root) != \
            "T2_RAW_EVIDENCE_ROOT = (ROOT / 'runs/UP1-04A-VNEXT-T2').resolve()" or \
            call_sites != ["output", "resume_authority_from", "resume_root"] or \
            "path.resolve().parent != T2_RAW_EVIDENCE_ROOT" not in \
                ast.get_source_segment(current_text, path_helper):
        raise RuntimeError("C1607-to-current path-gate source delta is not exact")

    class StripPathOnlyChanges(ast.NodeTransformer):
        def __init__(self, current: bool):
            self.current = current
            self.function_stack: list[str | None] = []

        def visit_Module(self, node: ast.Module) -> ast.Module:
            retained = []
            for statement in node.body:
                if self.current and isinstance(statement, ast.FunctionDef) and \
                        statement.name == "require_t2_execution_leaf":
                    continue
                if self.current and isinstance(statement, ast.Assign) and any(
                        isinstance(target, ast.Name) and
                        target.id == "T2_RAW_EVIDENCE_ROOT"
                        for target in statement.targets):
                    continue
                retained.append(self.visit(statement))
            node.body = retained
            return node

        def visit_FunctionDef(self, node: ast.FunctionDef) -> ast.FunctionDef:
            inherited = self.function_stack[-1] if self.function_stack else None
            path_context = node.name if node.name in {
                "main", "verify_authority_resume_ancestry"} else inherited
            self.function_stack.append(path_context)
            try:
                return self.generic_visit(node)
            finally:
                self.function_stack.pop()

        def visit_Expr(self, node: ast.Expr) -> ast.AST | None:
            context = self.function_stack[-1] if self.function_stack else None
            if context is not None and self._is_path_gate_statement(node, context):
                return None
            return self.generic_visit(node)

        def _is_path_gate_statement(self, statement: ast.stmt,
                                    function_name: str) -> bool:
            if not isinstance(statement, ast.Expr) or \
                    not isinstance(statement.value, ast.Call):
                return False
            call = statement.value
            if self.current:
                return isinstance(call.func, ast.Name) and \
                    call.func.id == "require_t2_execution_leaf"
            if not isinstance(call.func, ast.Attribute) or \
                    call.func.attr != "relative_to" or len(call.args) != 1:
                return False
            allowed_values = {
                "main": {"output", "resume_authority_from"},
                "verify_authority_resume_ancestry": {"resume_root"},
            }
            if not isinstance(call.func.value, ast.Name) or \
                    call.func.value.id not in allowed_values[function_name]:
                return False
            expected_root = ast.parse(
                "ROOT / 'docs/implementation/UP1-04A-VNEXT-T2'").body[0].value
            return ast.dump(call.args[0], include_attributes=False) == \
                ast.dump(expected_root, include_attributes=False)

    normalized_before = StripPathOnlyChanges(current=False).visit(ast.parse(before_text))
    normalized_current = StripPathOnlyChanges(current=True).visit(ast.parse(current_text))
    if ast.dump(normalized_current, include_attributes=False) != \
            ast.dump(normalized_before, include_attributes=False):
        raise RuntimeError("current R20 differs from the R9 controller outside path-only changes")

    return {
        "schema": "vnext-t2-r20-runs-only-path-gate-delta-r1",
        "pre_gate_controller": receipt(before_path),
        "current_controller": receipt(current_path),
        "changed_top_level_functions": changed,
        "required_direct_child_root": "runs/UP1-04A-VNEXT-T2",
        "path_gate_call_sites": call_sites,
        "normalized_source_equal_after_removing_path_gate": True,
        "sampling_pid_identity_cleanup_logic_changed": False,
        "resource_and_coverage_gates_changed": False,
        "independent_review": {
            "status": "GO",
            "scope": "current runs-only output/resume path gate only",
            "basis": "root-confirmed independent tester GO with stable pre/post source hash",
            "review_artifact_pinned_in_repository": False,
        },
    }


def build_r17_host_smoke_retry_lineage(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    attempts: dict[str, Any] = {}
    for label, leaf in R17_HOST_SMOKE_RETRY_LEAVES.items():
        expected_files = {
            "r5": {
                "command_argv.json", "exit_code.json", "stderr.raw", "stdout.raw",
                "natural_python_child/phase.json",
                "natural_python_child/samples.jsonl",
                "natural_python_child/stderr.raw",
                "natural_python_child/stdout.raw",
                "timed_python_child/phase.json",
                "timed_python_child/samples.jsonl",
                "timed_python_child/stderr.raw",
                "timed_python_child/stdout.raw",
            },
            "r6": {
                "command_argv.json", "exit_code.json", "stderr.raw", "stdout.raw",
                "natural_python_child/samples.jsonl",
                "natural_python_child/stderr.raw",
                "natural_python_child/stdout.raw",
            },
        }[label]
        rows: dict[str, dict[str, Any]] = {}
        for path in files_under(leaf):
            add_input(inputs, path)
            rows[path.relative_to(leaf).as_posix()] = receipt(path)
        if set(rows) != expected_files:
            raise RuntimeError(f"R17 host smoke {label} file set changed")
        command = load_object(leaf / "command_argv.json")
        result = load_object(leaf / "exit_code.json")
        stdout = (leaf / "stdout.raw").read_text(encoding="utf-8")
        stderr = (leaf / "stderr.raw").read_text(encoding="utf-8")
        if command.get("kind") != "python_only_host_supervisor_smoke" or \
                command.get("julia_started") is not False or \
                result.get("exit_code") != 1 or \
                result.get("julia_started") is not False:
            raise RuntimeError(f"R17 host smoke {label} is not a preserved Python failure")
        if label == "r5":
            observation = json.loads(stdout.splitlines()[0])
            phase = observation.get("natural_phase", {})
            sample_rows = [json.loads(line) for line in
                           (leaf / "natural_python_child/samples.jsonl")
                           .read_text(encoding="utf-8").splitlines()]
            if phase.get("process_tree_samples_complete") is not False or \
                    phase.get("stop_reason") != "process_tree_monitor_incomplete" or \
                    not any(row.get("sample_complete") is False and any(
                        error.get("type") == "ProcessTableError" and
                        error.get("message") ==
                        "root process is absent from process table"
                        for error in row.get("errors", []))
                        for row in sample_rows):
                raise RuntimeError("R17 host smoke r5 failure class drift")
            failure_class = "natural_terminal_sample_missing_root; rejected"
        else:
            if "UnboundLocalError: cannot access local variable 'terminal_sample_race'" \
                    not in stderr:
                raise RuntimeError("R17 host smoke r6 failure class drift")
            failure_class = "terminal_sample_race_unboundlocalerror; rejected"
        attempts[label] = {
            "leaf": str(leaf.relative_to(ROOT).as_posix()),
            "file_receipts": dict(sorted(rows.items())),
            "command_controller_sha256": command.get("controller_sha256"),
            "exit_code": result["exit_code"],
            "failure_class": failure_class,
            "formal_t2_accepted": False,
        }
    return {
        "schema": "vnext-t2-r17-native-monitor-smoke-failure-lineage-r1",
        "attempts": attempts,
        "attempt_count": len(attempts),
        "all_failure_files_in_current_input_closure": True,
        "failure_evidence_overwritten": False,
        "formal_t2_accepted": False,
    }


def build_retry8_pid0_failure_basis(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    previous_protocol_path = ATTEMPT11_RETRY8_FREEZE_LEAF / "protocol.json"
    previous_protocol = load_object(previous_protocol_path)
    previous_inputs = previous_protocol.get("inputs")
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r6" or \
            previous_protocol.get("input_count") != 459 or \
            not isinstance(previous_inputs, dict) or len(previous_inputs) != 459:
        raise RuntimeError("retry8 historical 459-pin protocol is malformed")
    refresh = load_object(PLANNING_REFRESH)
    validation = load_object(PLANNING_VALIDATION)
    refresh_pin = receipt(PLANNING_REFRESH)
    validation_pin = receipt(PLANNING_VALIDATION)
    expected_migration_paths = set(PLANNING_MIGRATION_INPUTS)
    refresh_before = refresh.get("before_sha256")
    if refresh_pin["sha256"] != PLANNING_REFRESH_SHA256 or \
            validation_pin["sha256"] != PLANNING_VALIDATION_SHA256 or \
            refresh.get("schema") != "planning-refresh-20260926-v1" or \
            refresh.get("record_kind") != \
                "planning_change_not_runtime_or_scientific_acceptance" or \
            refresh.get("base_head") != EXPECTED_HEAD or \
            not isinstance(refresh_before, dict) or \
            refresh.get("retained_contract_sha256") != \
                PLANNING_RETAINED_CONTRACT_SHA256 or \
            refresh.get("existing_task_count") != 46 or \
            refresh.get("accepted_limited_count") != 21 or \
            refresh.get("open_task_count") != 25 or \
            refresh.get("goal_achieved") is not False or \
            refresh.get("credible_candidate_count") != 0 or \
            refresh.get("baseline_document_validation") != {
                "exit_code": 1,
                "reason": "historical snapshot INDEX.md moved into cleanup recovery archive",
            } or \
            validation.get("record_kind") != \
                "planning_document_validation_not_physics_or_implementation_acceptance" or \
            validation.get("checks") != "pass" or \
            validation.get("task_count") != 46 or \
            validation.get("task_dag_acyclic") is not True or \
            validation.get("retained_acceptance_items") != 124 or \
            validation.get("retained_task_contract_sha256") != \
                PLANNING_RETAINED_CONTRACT_SHA256 or \
            validation.get("runtime_inputs_require_exact_restore_and_fresh_freeze") is not True or \
            validation.get("errors") != []:
        raise RuntimeError("authorized v4 planning migration receipt is not exact")

    manifest_path = ROOT / "docs/v4_multitopology_generation/task_manifest.json"
    manifest = load_object(manifest_path)
    retained_keys = refresh.get("retained_contract_keys")
    tasks = manifest.get("tasks")
    if not isinstance(retained_keys, list) or not isinstance(tasks, list) or \
            len(tasks) != 46:
        raise RuntimeError("authorized v4 planning migration task contract is malformed")
    retained = {
        item["id"]: {key: item[key] for key in retained_keys if key in item}
        for item in tasks
    }
    retained_hash = sha256_bytes(json.dumps(
        retained, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8"))
    if retained_hash != PLANNING_RETAINED_CONTRACT_SHA256:
        raise RuntimeError("authorized v4 retained task contract hash drift")

    migrated_inputs: dict[str, dict[str, Any]] = {}
    unchanged_pin_count = 0
    for relative, expected in sorted(previous_inputs.items()):
        current_path = ROOT / relative
        actual = receipt(current_path)
        if relative in expected_migration_paths:
            refresh_name = PLANNING_MIGRATION_INPUTS[relative]
            if expected.get("path") != relative or \
                    expected.get("sha256") != refresh_before.get(refresh_name) or \
                    expected == actual:
                raise RuntimeError(
                    f"authorized planning migration does not match historical pin: {relative}")
            add_input(inputs, current_path)
            migrated_inputs[relative] = {
                "historical_r8_pin": dict(expected),
                "planning_refresh_before_sha256": refresh_before[refresh_name],
                "current_r20_input": actual,
                "historical_bytes_are_current": False,
            }
        else:
            if expected != actual:
                raise RuntimeError(f"retry8 historical input pin drift: {relative}")
            unchanged_pin_count += 1
            add_input(inputs, current_path)
    if set(migrated_inputs) != expected_migration_paths or \
            unchanged_pin_count != 453:
        raise RuntimeError("retry8 to R20 planning migration scope is not exact")
    add_input(inputs, PLANNING_REFRESH)
    add_input(inputs, PLANNING_VALIDATION)

    planning_migration = {
        "schema": "v4-planning-refresh-r20-historical-input-bridge-r1",
        "status": "authorized_planning_migration_historical_bytes_not_current",
        "historical_r8_protocol_and_pins_preserved": True,
        "historical_bytes_are_current": False,
        "historical_input_count": len(previous_inputs),
        "unchanged_historical_pin_count": unchanged_pin_count,
        "migrated_input_count": len(migrated_inputs),
        "migrated_inputs": dict(sorted(migrated_inputs.items())),
        "planning_refresh_receipt": refresh_pin,
        "planning_validation_receipt": validation_pin,
        "planning_refresh_record": {
            "schema": refresh["schema"],
            "record_kind": refresh["record_kind"],
            "base_head": refresh["base_head"],
            "before_sha256": {
                name: refresh_before[name]
                for name in sorted(PLANNING_MIGRATION_INPUTS.values())
            },
            "retained_contract_sha256": retained_hash,
            "baseline_document_validation": refresh[
                "baseline_document_validation"],
            "goal_achieved": refresh["goal_achieved"],
            "credible_candidate_count": refresh["credible_candidate_count"],
        },
        "planning_validation_result": {
            "record_kind": validation["record_kind"],
            "checks": validation["checks"],
            "task_count": validation["task_count"],
            "task_dag_acyclic": validation["task_dag_acyclic"],
            "retained_acceptance_items": validation[
                "retained_acceptance_items"],
            "retained_task_contract_sha256": validation[
                "retained_task_contract_sha256"],
            "runtime_inputs_require_exact_restore_and_fresh_freeze": validation[
                "runtime_inputs_require_exact_restore_and_fresh_freeze"],
            "errors": validation["errors"],
        },
    }

    freeze_files: dict[str, dict[str, Any]] = {}
    for path in files_under(ATTEMPT11_RETRY8_FREEZE_LEAF):
        add_input(inputs, path)
        freeze_files[path.relative_to(ATTEMPT11_RETRY8_FREEZE_LEAF).as_posix()] = \
            receipt(path)
    root_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT11_RETRY8_ROOT_FAILURE_FILES.items():
        add_input(inputs, path)
        root_files[name] = receipt(path)
    review_files: dict[str, dict[str, Any]] = {}
    for path in files_under(ATTEMPT11_RETRY8_REVIEW_LEAF):
        add_input(inputs, path)
        review_files[path.relative_to(ATTEMPT11_RETRY8_REVIEW_LEAF).as_posix()] = \
            receipt(path)
    review_path = ATTEMPT11_RETRY8_REVIEW_LEAF / "review.json"
    review = load_object(review_path)
    start = load_object(ATTEMPT11_RETRY8_ROOT_FAILURE_FILES["start"])
    invocation = load_object(ATTEMPT11_RETRY8_ROOT_FAILURE_FILES["invocation"])
    stderr_path = ATTEMPT11_RETRY8_ROOT_FAILURE_FILES["stderr"]
    stderr = stderr_path.read_text(
        encoding="utf-8", errors="replace")
    stdout = ATTEMPT11_RETRY8_ROOT_FAILURE_FILES["stdout"].read_bytes()
    exit_text = ATTEMPT11_RETRY8_ROOT_FAILURE_FILES["exit"].read_text(
        encoding="ascii", errors="strict").strip()
    output_entries = sorted(path.relative_to(
        ATTEMPT11_RETRY8_ROOT_OUTPUT).as_posix()
        for path in files_under(ATTEMPT11_RETRY8_ROOT_OUTPUT))
    if start.get("protocol_sha256") != receipt(previous_protocol_path)["sha256"] or \
            start.get("checked_input_count") != 459 or \
            start.get("head") != EXPECTED_HEAD or \
            invocation.get("schema") != \
            "root-t2-attempt11-retry8-invocation-v1" or \
            invocation.get("controller_exit_code") != 1 or \
            invocation.get("stdout_sha256") != sha256_bytes(stdout) or \
            invocation.get("stderr_sha256") != sha256_bytes(stderr_path.read_bytes()) or \
            invocation.get("formal_t2_accepted_by_root") is not False or \
            receipt(review_path)["sha256"] != ATTEMPT11_RETRY8_REVIEW_SHA256 or \
            review.get("schema") != "independent-t2-attempt11-retry8-postrun-review-r1" or \
            review.get("verdict") != "NO_GO_RETRY8_RUNTIME_ATTEMPT_CONSUMED" or \
            review.get("classification") != \
                "pre_julia_program_exception_baseline_process_monitor_incomplete" or \
            review.get("formal_coverage_credit") is not False or \
            exit_text != "1" or stdout or \
            "PID inventory contains invalid PID values" not in stderr or \
            "pid_inventory_before" not in stderr or \
            output_entries or not ATTEMPT11_RETRY8_ROOT_OUTPUT.is_dir():
        raise RuntimeError("retry8 root failure is not exact PID0 baseline interruption")
    return {
        "schema": "vnext-t2-attempt11-retry8-windows-pid0-failure-basis-r1",
        "status": "immutable_program_monitor_failure_before_julia_no_acceptance",
        "frozen_protocol": receipt(previous_protocol_path),
        "historical_input_count": len(previous_inputs),
        "historical_input_pins": dict(sorted(previous_inputs.items())),
        "authorized_planning_migration": planning_migration,
        "frozen_archive_files": dict(sorted(freeze_files.items())),
        "root_runtime_failure_files": root_files,
        "independent_postrun_review": {
            "review": receipt(review_path),
            "review_sha256_expected": ATTEMPT11_RETRY8_REVIEW_SHA256,
            "files": dict(sorted(review_files.items())),
            "julia_or_heavy_execution": False,
            "source_or_test_edits": False,
        },
        "root_output_directory": {
            "path": ATTEMPT11_RETRY8_ROOT_OUTPUT.relative_to(ROOT).as_posix(),
            "exists": True, "entries": output_entries, "empty": not output_entries,
        },
        "observed": {
            "controller_exit_code": 1,
            "failure_stage": "pid_inventory_before",
            "failure_message": "PID inventory contains invalid PID values",
            "julia_started": False,
            "stdout_bytes": len(stdout),
            "formal_phase_receipts": 0,
            "scientific_negative_failure": False,
            "formal_t2_accepted": False,
        },
    }


def build_attempt8_preflight_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT8_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT8_FAILURE_FILES["protocol"])
    previous_dispatch = load_object(ATTEMPT8_FAILURE_FILES["dispatch"])
    previous_pipeline = load_object(ATTEMPT8_FAILURE_FILES["pipeline_final"])
    baseline_phase = load_object(ATTEMPT8_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT8_FAILURE_FILES["baseline_summary"])
    failed_phase = load_object(ATTEMPT8_FAILURE_FILES["preflight_phase"])
    driver_path = ROOT / previous_protocol["driver_path"]
    controller_path = ROOT / previous_protocol["controller_path"]
    prior_protocol_inputs = previous_protocol.get("inputs", {})
    for path in (driver_path, controller_path):
        add_input(inputs, path)
        expected = prior_protocol_inputs.get(path.relative_to(ROOT).as_posix())
        if expected != receipt(path):
            raise RuntimeError(f"attempt8 source pin drift: {path}")
    command = failed_phase.get("command")
    if not isinstance(command, list) or str(driver_path.resolve()) not in command:
        raise RuntimeError("attempt8 preflight command lacks the pinned r3 driver")
    driver_index = command.index(str(driver_path.resolve()))
    driver_args = command[driver_index + 1:]
    driver_source = read_source_text(driver_path)
    prior_coverage = previous_protocol.get("coverage_map", {})
    expected_map_path = str((ROOT / prior_coverage.get("path", "")).resolve())
    expected_map_sha = prior_coverage.get("sha256")
    stderr = ATTEMPT8_FAILURE_FILES["preflight_stderr"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r3" or \
            previous_dispatch.get("formal_t2_accepted") is not False or \
            baseline_phase.get("name") != "actual_formal_baseline" or \
            baseline_phase.get("stop_reason") != "natural_exit" or \
            baseline_phase.get("exit_code") != 0 or \
            baseline_summary.get("status") != "pass" or \
            failed_phase.get("name") != "actual_formal_preflight" or \
            failed_phase.get("stop_reason") != "natural_exit" or \
            failed_phase.get("exit_code") != 1 or \
            failed_phase.get("timeout_seconds") != 480.0 or \
            failed_phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            failed_phase.get("formal_t2_accepted") is True or \
            not stderr or stderr[0] != ATTEMPT8_EXPECTED_DRIVER_ERROR or \
            "length(ARGS) == 16 || error(" not in driver_source or \
            "abspath(ARGS[15])" not in driver_source or \
            "lowercase(ARGS[16])" not in driver_source or \
            len(driver_args) != 14 or driver_args[0] != "preflight" or \
            driver_args[-2:] == [expected_map_path, expected_map_sha] or \
            previous_pipeline.get("status") != "fail" or \
            previous_pipeline.get("formal_t2_accepted") is not False:
        raise RuntimeError("attempt8 preflight failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt8-preflight-arity-failure-r1",
        "status": "preserved_natural_exit_failure_not_acceptance",
        "files": frozen_files,
        "driver_path": previous_protocol["driver_path"],
        "controller_path": previous_protocol["controller_path"],
        "driver_expected_argument_count": 16,
        "observed_preflight_argument_count": len(driver_args),
        "observed_preflight_exit_code": failed_phase["exit_code"],
        "observed_preflight_stop_reason": failed_phase["stop_reason"],
        "observed_error_line": stderr[0],
        "missing_final_coverage_map_pair": {
            "path": expected_map_path, "sha256": expected_map_sha,
        },
        "baseline_natural_exit_zero": True,
        "formal_t2_accepted": False,
    }


def build_attempt9_projection_preflight_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT9_FIRST_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT9_FIRST_FAILURE_FILES["protocol"])
    previous_phase = load_object(
        ATTEMPT9_FIRST_FAILURE_FILES["preflight_phase"])
    previous_coverage_receipt = previous_protocol.get("coverage_map", {})
    validator_r3 = TEST_ROOT / "validate_projection24_reuse_r3.py"
    relative_validator = validator_r3.relative_to(ROOT).as_posix()
    stderr_lines = ATTEMPT9_FIRST_FAILURE_FILES["preflight_stderr"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    phase_argv = previous_phase.get("command_argv")
    expected_protocol_path = str(
        (ATTEMPT9_FIRST_FAILURE_LEAF / "protocol.json").resolve())
    expected_receipt_path = str((ATTEMPT9_FIRST_FAILURE_LEAF /
        "projection24_reuse_preflight/reuse_receipt.json").resolve())
    previous_pins = previous_protocol.get("inputs", {})
    add_input(inputs, validator_r3)
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("status") != \
            "frozen_static_ready_not_executed" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_executed") is True or \
            previous_protocol.get("julia_started") is True or \
            previous_coverage_receipt.get("path") != \
            ATTEMPT9_FIRST_FAILURE_FILES["coverage_map"].relative_to(
                ROOT).as_posix() or \
            receipt(ATTEMPT9_FIRST_FAILURE_FILES["coverage_map"]) != {
                "path": previous_coverage_receipt.get("path"),
                "bytes": previous_coverage_receipt.get("bytes"),
                "sha256": previous_coverage_receipt.get("sha256"),
            } or previous_pins.get(relative_validator) != receipt(validator_r3) or \
            previous_phase.get("name") != \
            "projection24_reuse_python_preflight" or \
            previous_phase.get("status") != "fail" or \
            previous_phase.get("stop_reason") != "natural_exit" or \
            previous_phase.get("exit_code") != 1 or \
            previous_phase.get("timeout_seconds") != 300 or \
            previous_phase.get("julia_started") is not False or \
            previous_phase.get("formal_t2_accepted") is not False or \
            previous_phase.get("pass_marker_observed") is not False or \
            phase_argv != [sys.executable, "-B", str(validator_r3),
                           expected_protocol_path, expected_receipt_path] or \
            (not stderr_lines or not stderr_lines[-1].endswith(
                ATTEMPT9_EXPECTED_VALIDATOR_ERROR)) or \
            (ATTEMPT9_FIRST_FAILURE_LEAF / "static_qa.json").exists() or \
            (ATTEMPT9_FIRST_FAILURE_LEAF / "freeze_snapshot.json").exists() or \
            (ATTEMPT9_FIRST_FAILURE_LEAF /
             "projection24_reuse_preflight/reuse_receipt.json").exists():
        raise RuntimeError("attempt9 projection schema failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt9-projection-schema-preflight-failure-r1",
        "status": "preserved_natural_exit_failure_not_acceptance",
        "files": frozen_files,
        "validator_r3_path": relative_validator,
        "validator_r3_sha256": receipt(validator_r3)["sha256"],
        "observed_exit_code": previous_phase["exit_code"],
        "observed_stop_reason": previous_phase["stop_reason"],
        "observed_stderr_final_line": stderr_lines[-1],
        "protocol_schema_expected": "vnext-t2-independent-negative-protocol-r3",
        "protocol_schema_observed": previous_protocol["schema"],
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def build_projection_validator_r3_r4_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r3_path = TEST_ROOT / "validate_projection24_reuse_r3.py"
    r4_path = TEST_ROOT / "validate_projection24_reuse_r4.py"
    add_input(inputs, r3_path)
    add_input(inputs, r4_path)
    r3_text = read_source_text(r3_path)
    r4_text = read_source_text(r4_path)
    substitutions = [
        ("validate_projection24_reuse_r3.py",
         "validate_projection24_reuse_r4.py"),
        ("vnext-t2-independent-negative-protocol-r3",
         "vnext-t2-independent-negative-protocol-r4"),
        ("vnext-t2-projection24-cross-run-validation-r3",
         "vnext-t2-projection24-cross-run-validation-r4"),
    ]
    normalized = r4_text
    for old, new in substitutions:
        if r3_text.count(old) != 1 or r4_text.count(new) != 1:
            raise RuntimeError(f"projection validator schema delta is ambiguous: {old}")
        normalized = normalized.replace(new, old)
    if normalized != r3_text:
        raise RuntimeError("projection validator r3/r4 changed non-schema semantics")
    unified = "".join(difflib.unified_diff(
        r3_text.splitlines(keepends=True), r4_text.splitlines(keepends=True),
        fromfile=r3_path.relative_to(ROOT).as_posix(),
        tofile=r4_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-projection-validator-r3-r4-delta-r1",
        "r3_source": receipt(r3_path),
        "r4_source": receipt(r4_path),
        "allowed_replacements": [
            {"from": old, "to": new, "occurrences": 1}
            for old, new in substitutions],
        "non_schema_semantic_changes": 0,
        "normalized_r4_source_equals_r3": True,
        "unified_diff": unified,
    }


def build_projection_validator_r4_r5_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r4_path = TEST_ROOT / "validate_projection24_reuse_r4.py"
    r5_path = HISTORICAL_PROJECTION_REUSE_VALIDATOR_R5
    add_input(inputs, r4_path)
    add_input(inputs, r5_path)
    r4_text = read_source_text(r4_path)
    r5_text = read_source_text(r5_path)
    old_tree, new_tree = ast.parse(r4_text), ast.parse(r5_text)

    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}

    old_functions, new_functions = functions(old_tree), functions(new_tree)
    changed_functions = sorted(
        name for name in set(old_functions) | set(new_functions)
        if old_functions.get(name) != new_functions.get(name))
    if changed_functions != ["main", "verify_projection24_reuse_plan"] or \
            "vnext-t2-independent-negative-protocol-r5" not in r5_text or \
            "vnext-t2-projection24-cross-run-validation-r5" not in r5_text or \
            "validate_projection24_reuse_r5.py" not in r5_text or \
            "coverage_map_r10.json" not in r5_text or \
            "vnext-t2-independent-negative-coverage-map-r10" not in r5_text:
        raise RuntimeError("projection validator r4/r5 delta exceeds strict compatibility scope")
    unified = "".join(difflib.unified_diff(
        r4_text.splitlines(keepends=True), r5_text.splitlines(keepends=True),
        fromfile=r4_path.relative_to(ROOT).as_posix(),
        tofile=r5_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-projection-validator-r4-r5-delta-r1",
        "r4_source": receipt(r4_path),
        "r5_source": receipt(r5_path),
        "changed_top_level_functions": changed_functions,
        "protocol_schema": "vnext-t2-independent-negative-protocol-r5",
        "coverage_map_schema": "vnext-t2-independent-negative-coverage-map-r10",
        "current_map_path": (
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
            "coverage_map_r10.json"),
        "projection_plan_schema_and_151_6_159_closure_unchanged": True,
        "coverage_pin_must_equal_current_protocol_input_pin": True,
        "generic_schema_acceptance": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }



def build_projection_validator_r5_r6_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r5_path = HISTORICAL_PROJECTION_REUSE_VALIDATOR_R5
    r6_path = HISTORICAL_PROJECTION_REUSE_VALIDATOR_R6
    add_input(inputs, r5_path)
    add_input(inputs, r6_path)
    old_text = read_source_text(r5_path)
    new_text = read_source_text(r6_path)
    old_tree, new_tree = ast.parse(old_text), ast.parse(new_text)
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in old_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in new_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in set(old_functions) | set(new_functions)
                     if old_functions.get(name) != new_functions.get(name))
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=r5_path.relative_to(ROOT).as_posix(),
        tofile=r6_path.relative_to(ROOT).as_posix()))
    if changed != ["main", "verify_projection24_reuse_plan"] or \
            "vnext-t2-independent-negative-protocol-r6" not in new_text or \
            "vnext-t2-projection24-cross-run-validation-r6" not in new_text or \
            "validate_projection24_reuse_r6.py" not in new_text or \
            "coverage_map_r11.json" not in new_text or \
            "vnext-t2-independent-negative-coverage-map-r11" not in new_text or \
            "current_inputs.get(coverage_path) != coverage_pin" not in new_text:
        raise RuntimeError("projection validator r5/r6 delta exceeds exact schema/map compatibility")
    return {
        "schema": "vnext-t2-projection-validator-r5-r6-delta-r1",
        "r5_source": receipt(r5_path), "r6_source": receipt(r6_path),
        "changed_top_level_functions": changed,
        "protocol_schema": "vnext-t2-independent-negative-protocol-r6",
        "coverage_map_schema": "vnext-t2-independent-negative-coverage-map-r11",
        "current_map_path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r11.json",
        "projection_plan_schema_and_151_6_159_closure_unchanged": True,
        "coverage_pin_must_equal_current_protocol_input_pin": True,
        "generic_schema_acceptance": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_projection_validator_r6_r7_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r6_path = HISTORICAL_PROJECTION_REUSE_VALIDATOR_R6
    r7_path = HISTORICAL_PROJECTION_REUSE_VALIDATOR_R7
    add_input(inputs, r6_path)
    add_input(inputs, r7_path)
    old_text, new_text = (read_source_text(r6_path),
                          read_source_text(r7_path))
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in ast.parse(old_text).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in ast.parse(new_text).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=r6_path.relative_to(ROOT).as_posix(),
        tofile=r7_path.relative_to(ROOT).as_posix()))
    if changed != ["main", "verify_projection24_reuse_plan"] or \
            "vnext-t2-independent-negative-protocol-r7" not in new_text or \
            "vnext-t2-projection24-cross-run-validation-r7" not in new_text or \
            "validate_projection24_reuse_r7.py" not in new_text or \
            "coverage_map_r12.json" not in new_text or \
            "vnext-t2-independent-negative-coverage-map-r12" not in new_text or \
            "current_inputs.get(coverage_path) != coverage_pin" not in new_text:
        raise RuntimeError("projection validator r6/r7 delta exceeds exact schema/map compatibility")
    return {
        "schema": "vnext-t2-projection-validator-r6-r7-delta-r1",
        "r6_source": receipt(r6_path), "r7_source": receipt(r7_path),
        "changed_top_level_functions": changed,
        "protocol_schema": "vnext-t2-independent-negative-protocol-r7",
        "coverage_map_schema": "vnext-t2-independent-negative-coverage-map-r12",
        "current_map_path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r12.json",
        "projection_plan_schema_and_151_6_159_closure_unchanged": True,
        "coverage_pin_must_equal_current_protocol_input_pin": True,
        "generic_schema_acceptance": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r13_r14_windows_pid0_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r13_path, r14_path = HISTORICAL_CONTROLLER_R13, HISTORICAL_CONTROLLER_R14
    add_input(inputs, r13_path)
    add_input(inputs, r14_path)
    old_text = read_source_text(r13_path)
    new_text = read_source_text(r14_path)

    def split(source: str) -> tuple[dict[str, str], dict[str, str], set[str]]:
        tree = ast.parse(source)
        functions: dict[str, str] = {}
        assignments: dict[str, str] = {}
        imports: set[str] = set()
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                assignments[node.targets[0].id] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Import):
                imports.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                imports.add((node.module or "") + ":" + ",".join(
                    alias.name for alias in node.names))
        return functions, assignments, imports

    old_functions, old_assignments, old_imports = split(old_text)
    new_functions, new_assignments, new_imports = split(new_text)
    changed_functions = sorted(
        name for name in old_functions.keys() | new_functions.keys()
        if old_functions.get(name) != new_functions.get(name))
    changed_assignments = sorted(
        name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    added_imports, removed_imports = sorted(new_imports - old_imports), \
        sorted(old_imports - new_imports)
    expected_functions = [
        "_is_windows_idle_process_info", "_is_windows_idle_sentinel",
        "_process_table_snapshot",
        "_valid_pid_inventory", "main", "verify_protocol",
    ]
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=r13_path.relative_to(ROOT).as_posix(),
        tofile=r14_path.relative_to(ROOT).as_posix()))
    guard_fragments = (
        "type(value) is int and value > 0",
        "def _valid_pid_inventory(value: Any, *, platform_name: str | None = None)",
        "def _is_windows_idle_process_info(info: Any)",
        "def _is_windows_idle_sentinel(value: Any)",
        "platform == \"nt\" and type(value) is int and value == 0",
        "info.get(\"name\") != \"System Idle Process\"",
        "info.get(\"ppid\") != 0",
        "info.get(\"pid\") != 0",
        "if _is_windows_idle_sentinel(pid):",
        "if not _is_windows_idle_process_info(info):",
        "vnext-t2-process-table-snapshot-r2",
        "validate_projection24_reuse_r7.py",
        "vnext-t2-independent-negative-protocol-r7",
        "vnext-t2-independent-negative-coverage-map-r12",
    )
    if changed_functions != expected_functions or \
            changed_assignments != ["PROJECTION_REUSE_VALIDATOR"] or \
            added_imports or removed_imports or \
            any(fragment not in new_text for fragment in guard_fragments):
        raise RuntimeError("controller R13/R14 delta differs from Windows PID0 inventory scope")
    return {
        "schema": "vnext-t2-controller-r13-r14-windows-pid0-delta-r1",
        "r13_source": receipt(r13_path), "r14_source": receipt(r14_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_assignments": changed_assignments,
        "added_imports": added_imports, "removed_imports": removed_imports,
        "pid0_inventory_contract": {
            "inventory_sentinel": "exact_builtin_int_zero_on_windows_only",
            "normalized_from_before_after_final_pid_sets": True,
            "normalized_from_process_iteration_only_on_windows": True,
            "sentinel_counted_in_receipt": True,
            "process_iteration_row": "exact_windows_pid0_system_idle_process_ppid0_ctime0",
            "actual_root_child_tracked_and_kill_pids": "exact_builtin_int_positive",
            "bool_zero_float_negative_and_nonwindows_zero": "rejected",
            "malformed_inventory": "typed_monitor_incomplete_nonzero_no_acceptance",
        },
        "coverage_semantics_changed": False,
        "phase_wall_budget_changed": False,
        "working_set_limit_changed": False,
        "thread_limits_changed": False,
        "semantic_thresholds_changed": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_retry5_retry6_failure_lineage(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    archive = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive"
    leaves = {
        "retry5": archive / "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry5",
        "retry6": archive / "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry6",
    }
    expected: dict[str, dict[str, tuple[int, str]]] = {
        "retry5": {
            "command_argv.json": (1714, "ae8015240b863a49f1667af26f50c89e0d5cff3024ab33fed195a145f4b69a63"),
            "dispatch.json": (10678, "720a97c9af856736f6671334dddbe3fbf83fa0b9f345b5cdf140cd9d2137bfab"),
            "protocol.json": (723930, "ecc75f64c746e5155c74d9db5a69617f0bf1f9a3ec0a408b7b3b7b1705954419"),
            "static_qa.json": (916, "764c4633acb906c5022ee3285a113d6ddada3db73d57cdfe8a24fa614e427e68"),
            "static_qa.stderr.raw": (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            "static_qa.stdout.raw": (945, "43f111d4e9ed1a4460f34d04be98546bb8206e00238fe02e7b6ba0e56937f1c6"),
            "projection24_reuse_preflight/phase.json": (2085, "6d158ba87291d3a3417f7c08a65f351cff7cced6389706f92ee82449308227f6"),
            "projection24_reuse_preflight/reuse_receipt.json": (48553, "1e621d5e849f6736e15d79f90e488d43baa79e64a5e00b3f060add44ac81a0a0"),
            "projection24_reuse_preflight/stderr.raw": (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            "projection24_reuse_preflight/stdout.raw": (349, "2514a280952b56ab0c9bc2b391faa22b068791dd4fbdd912bf3fe6de08617e59"),
        },
        "retry6": {
            "command_argv.json": (1714, "69612b97651b19a1927841c683104b1e1e513c4b96c68880e0d74dda5a4a6e14"),
            "dispatch.json": (10678, "4dfce10a45717df35708b0f1e6d27e66397695f975413afc2ba27ccbe60bc9cf"),
            "protocol.json": (723930, "5c9a4c02c18e3b73ac182f0318da897048968da3cb55ce87e6a6940dc3f115f2"),
            "static_qa.json": (24980, "c17ce4afeffd6bab067a9bc1dd3a6aa3ca4c1a94417e80e52a696317ea37d9c0"),
            "static_qa.stderr.raw": (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            "static_qa.stdout.raw": (25775, "ba7af67f77d939b9a4016226806a6477a40b99ffb8b25ff4d83d819d3c3ff31c"),
            "projection24_reuse_preflight/phase.json": (2085, "af28f28c5c0d4cef30a53713a592343e7fc9fa8d4af5154c3976ce5c8749bc7e"),
            "projection24_reuse_preflight/reuse_receipt.json": (48553, "1e621d5e849f6736e15d79f90e488d43baa79e64a5e00b3f060add44ac81a0a0"),
            "projection24_reuse_preflight/stderr.raw": (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            "projection24_reuse_preflight/stdout.raw": (349, "e466188211638011ba73a1acb47db3403e55aadd742625e2651bb6bb986725a1"),
        },
    }
    results: dict[str, Any] = {}
    for label, leaf in leaves.items():
        observed_paths = sorted(path for path in leaf.rglob("*") if path.is_file())
        observed = {path.relative_to(leaf).as_posix(): receipt(path)
                    for path in observed_paths}
        rows = expected[label]
        if set(observed) != set(rows):
            raise RuntimeError(f"{label} failure leaf inventory changed")
        for relative, (byte_count, digest) in rows.items():
            if observed[relative]["bytes"] != byte_count or \
                    observed[relative]["sha256"] != digest:
                raise RuntimeError(f"{label} immutable failure pin drift: {relative}")
            add_input(inputs, leaf / relative)
        protocol = load_object(leaf / "protocol.json")
        qa = load_object(leaf / "static_qa.json")
        dispatch = load_object(leaf / "dispatch.json")
        command = load_object(leaf / "command_argv.json")
        expected_message = (
            "attempt9b static QA failure details are inconsistent"
            if label == "retry5" else
            "authority case resource contract mismatch: PARENT_STALE")
        if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r5" or \
                protocol.get("formal_t2_accepted") is not False or \
                protocol.get("coverage_assertion_hit_plan", {}).get(
                    "assertion_site_count") != 214 or \
                protocol.get("coverage_assertion_hit_plan", {}).get(
                    "expected_runtime_hit_count") != 622 or \
                qa.get("schema") != "vnext-t2-independent-negative-static-qa-r8" or \
                qa.get("status") != "fail" or qa.get("julia_executed") is not False or \
                qa.get("failure") != {"type": "RuntimeError", "message": expected_message} or \
                dispatch.get("julia_started") is not False or \
                command.get("julia_started") is not False or \
                dispatch.get("formal_t2_accepted") is not False or \
                command.get("formal_t2_accepted") is not False or \
                (leaf / "freeze_snapshot.json").exists():
            raise RuntimeError(f"{label} partial static failure classification drift")
        results[label] = {
            "archive_leaf": leaf.relative_to(ROOT).as_posix(),
            "files": observed, "protocol_schema": protocol["schema"],
            "static_qa_schema": qa["schema"], "static_qa_exit_code": 1,
            "failure": qa["failure"], "julia_executed": False,
            "formal_t2_accepted": False,
        }
    return {
        "schema": "vnext-t2-retry5-retry6-preserved-static-failure-lineage-r1",
        "status": "both_immutable_partial_failures_pinned_no_acceptance",
        "retry5": results["retry5"], "retry6": results["retry6"],
        "julia_started": False, "formal_t2_accepted": False,
    }

def build_controller_r8_r9_authority_progress_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r8.py"
    current_path = TEST_ROOT / "independent_negative_controller_r9.py"
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_tree = ast.parse(read_source_text(prior_path))
    current_tree = ast.parse(read_source_text(current_path))
    mutable_names = {"_authority_source_ids", "verify_authority_case_receipt",
                     "run_authority_case_phase",
                     "summarize_authority_case_progress_prefix", "main"}
    mutable_bindings = {"ACTUAL_DRIVER", "AUTHORITY_CASE_TIMEOUT_SECONDS"}
    def normalized(tree: ast.Module) -> tuple[list[str], dict[str, str]]:
        untouched = []
        functions = {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name) and \
                    node.targets[0].id in mutable_bindings:
                continue
            elif isinstance(node, (ast.Import, ast.ImportFrom)):
                untouched.append(ast.dump(node, include_attributes=False))
            else:
                untouched.append(ast.dump(node, include_attributes=False))
        return untouched, functions
    prior_top, prior_functions = normalized(prior_tree)
    current_top, current_functions = normalized(current_tree)
    prior_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in prior_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    current_assignments = {node.targets[0].id: ast.dump(node, include_attributes=False)
        for node in current_tree.body if isinstance(node, ast.Assign) and
        len(node.targets) == 1 and isinstance(node.targets[0], ast.Name) and
        node.targets[0].id in mutable_bindings}
    changed_bindings = sorted(name for name in mutable_bindings
        if prior_assignments.get(name) != current_assignments.get(name))
    if prior_top != current_top or changed_bindings != sorted(mutable_bindings):
        raise RuntimeError("controller r9 changed unapproved module bindings")
    changed_functions = sorted(name for name in set(prior_functions) | set(current_functions)
        if prior_functions.get(name) != current_functions.get(name))
    if changed_functions != sorted(mutable_names):
        raise RuntimeError(f"controller r9 changed unexpected functions: {changed_functions}")
    old_text = read_source_text(prior_path)
    new_text = read_source_text(current_path)
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r8-r9-authority-progress-delta-r1",
        "r8_source": receipt(prior_path),
        "r9_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_bindings": changed_bindings,
        "unchanged_other_module_bindings_and_functions": True,
        "coverage_semantics_changed": False,
        "authority_case_wall_budget_delta": {
            "prior_case_seconds": 1200,
            "current_case_seconds": 2400,
            "invocation_cap_seconds": 2400,
            "effective_timeout": "min(per_case_cap, remaining_invocation_budget)",
            "rationale": "a 1200s child cap has no evidence-backed sufficiency after attempt9c observed no case completion under the 480s invocation cutoff; matching the child cap to the invocation cap lets a case finish and then permits safe resume of later incomplete cases",
        },
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r9_r10_preflight_budget_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r9.py"
    current_path = TEST_ROOT / "independent_negative_controller_r10.py"
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_text = read_source_text(prior_path)
    current_text = read_source_text(current_path)
    prior_tree = ast.parse(prior_text)
    current_tree = ast.parse(current_text)
    mutable_functions = {"actual_formal_shard_timeout", "main"}
    mutable_bindings = {"PREFLIGHT_PHASE_TIMEOUT_SECONDS"}
    def split(tree: ast.Module) -> tuple[list[str], dict[str, str], dict[str, str]]:
        fixed, functions, bindings = [], {}, {}
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name) and \
                    node.targets[0].id in mutable_bindings:
                bindings[node.targets[0].id] = ast.dump(
                    node, include_attributes=False)
            else:
                fixed.append(ast.dump(node, include_attributes=False))
        return fixed, functions, bindings
    prior_fixed, prior_functions, prior_bindings = split(prior_tree)
    current_fixed, current_functions, current_bindings = split(current_tree)
    changed_functions = sorted(name for name in
        set(prior_functions) | set(current_functions)
        if prior_functions.get(name) != current_functions.get(name))
    changed_bindings = sorted(name for name in mutable_bindings
        if prior_bindings.get(name) != current_bindings.get(name))
    if prior_fixed != current_fixed or \
            changed_functions != sorted(mutable_functions) or \
            changed_bindings != sorted(mutable_bindings) or \
            current_bindings.get("PREFLIGHT_PHASE_TIMEOUT_SECONDS") is None:
        raise RuntimeError("controller r10 contains changes outside the preflight timeout policy")
    normalized = current_text
    exact_replacements = [
        ("PREFLIGHT_PHASE_TIMEOUT_SECONDS = 600\n", ""),
        ("\n\ndef actual_formal_shard_timeout(mode: str, configured_default: float) -> float:\n"
         "    if configured_default != 480:\n"
         "        raise ValueError(\"formal shard default phase timeout must remain 480s\")\n"
         "    if mode == \"preflight\":\n"
         "        return PREFLIGHT_PHASE_TIMEOUT_SECONDS\n"
         "    if mode not in {\"fault_n10\", \"t1_handoff\"}:\n"
         "        raise ValueError(f\"unsupported timeout policy for shard: {mode}\")\n"
         "    return configured_default\n\n", "\n"),
        ("negative formal phases require 480s default, 600s preflight override, 2GiB, and authority 2400s/2400s gates",
         "negative formal phases require 480s/2GiB and authority 2400s/2400s gates"),
        ("    if protocol.get(\"resource_gates\", {}).get(\n"
         "            \"phase_wall_timeout_overrides\") != {\n"
         "                \"actual_formal_preflight\": PREFLIGHT_PHASE_TIMEOUT_SECONDS}:\n"
         "        raise RuntimeError(\"preflight phase timeout override differs from controller policy\")\n", ""),
        ("        \"preflight_phase_timeout_seconds\": PREFLIGHT_PHASE_TIMEOUT_SECONDS,\n", ""),
        ("timeout_seconds=actual_formal_shard_timeout(\n"
         "                        mode, args.phase_timeout),", "timeout_seconds=args.phase_timeout,"),
        ("vnext-t2-independent-negative-coverage-map-r8",
         "vnext-t2-independent-negative-coverage-map-r7"),
    ]
    for current_fragment, prior_fragment in exact_replacements:
        if normalized.count(current_fragment) != 1:
            raise RuntimeError("controller r10 exact preflight-only normalization is ambiguous")
        normalized = normalized.replace(current_fragment, prior_fragment, 1)
    if normalized != prior_text:
        raise RuntimeError("controller r9/r10 changed more than the exact preflight timeout delta")
    unified = "".join(difflib.unified_diff(
        prior_text.splitlines(keepends=True), current_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r9-r10-preflight-budget-delta-r1",
        "r9_source": receipt(prior_path),
        "r10_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_bindings": changed_bindings,
        "unchanged_other_module_bindings_and_functions": True,
        "coverage_semantics_changed": False,
        "preflight_phase_wall_budget_delta": {
            "prior_phase_seconds": 480,
            "current_preflight_seconds": 600,
            "only_phase_override": "actual_formal_preflight",
            "other_formal_phases_seconds": 480,
            "julia_threads": 1,
            "openblas_threads": 1,
            "working_set_limit_bytes": 2_147_483_648,
            "coverage_thresholds_changed": False,
            "rationale": (
                "attempt10 completed 16 of 18 planned preflight observations "
                "within 480.1707022s after 183.6627444s of fresh preparation; "
                "at the conservative whole-attempt average the final two "
                "observations need about 37.0635s and the 600s limit leaves "
                "about 82.7658s for variance and natural summary/finalization. "
                "This estimate is not a guarantee; natural exit and all 18 "
                "observations remain mandatory."),
        },
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r10_r11_monitor_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r10.py"
    current_path = TEST_ROOT / "independent_negative_controller_r11.py"
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_text = read_source_text(prior_path)
    current_text = read_source_text(current_path)
    prior_tree, current_tree = ast.parse(prior_text), ast.parse(current_text)

    def split(tree: ast.Module) -> tuple[dict[str, str], dict[str, str],
                                        set[str]]:
        functions: dict[str, str] = {}
        assignments: dict[str, str] = {}
        imports: set[str] = set()
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(
                    node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                assignments[node.targets[0].id] = ast.dump(
                    node, include_attributes=False)
            elif isinstance(node, ast.Import):
                imports.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                imports.add((node.module or "") + ":" + ",".join(
                    alias.name for alias in node.names))
        return functions, assignments, imports

    old_functions, old_assignments, old_imports = split(prior_tree)
    new_functions, new_assignments, new_imports = split(current_tree)
    changed_functions = sorted(
        name for name in set(old_functions) | set(new_functions)
        if old_functions.get(name) != new_functions.get(name))
    expected_functions = sorted([
        "_descendant_rows", "_final_process_tree_audit", "_monitor_error",
        "_process_table_snapshot", "_tasklist_process_names",
        "heavy_processes", "kill_tree", "main", "process_tree_sample",
        "require_natural", "run_authority_case_phase", "run_phase",
        "verify_authority_case_receipt", "verify_protocol",
    ])
    changed_assignments = sorted(
        name for name in set(old_assignments) | set(new_assignments)
        if old_assignments.get(name) != new_assignments.get(name))
    added_imports = sorted(new_imports - old_imports)
    removed_imports = sorted(old_imports - new_imports)
    if changed_functions != expected_functions or changed_assignments or \
            added_imports != ["csv", "io"] or removed_imports:
        raise RuntimeError("r10/r11 controller delta exceeds the monitored scope")
    unified = "".join(difflib.unified_diff(
        prior_text.splitlines(keepends=True),
        current_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r10-r11-fail-closed-monitor-delta-r1",
        "r10_source": receipt(prior_path),
        "r11_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_assignments": changed_assignments,
        "added_imports": added_imports,
        "removed_imports": removed_imports,
        "monitor_behavior": [
            "every complete sample has exactly one expected root pid/create_time",
            "recursive child enumeration and resource-read failures are incomplete",
            "process-tree RSS sums only fully identified successful rows",
            "termination validates tree identity, kill, wait, and post-state",
            "PID reuse is an incomplete monitor state",
            "residual process enumeration and command-line failures are incomplete",
            "blank psutil names require exact tasklist CSV resolution",
        ],
        "coverage_semantics_changed": False,
        "phase_wall_budget_changed": False,
        "working_set_limit_changed": False,
        "thread_limits_changed": False,
        "semantic_thresholds_changed": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r11_r12_generation_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    prior_path = TEST_ROOT / "independent_negative_controller_r11.py"
    current_path = HISTORICAL_CONTROLLER_R12
    add_input(inputs, prior_path)
    add_input(inputs, current_path)
    prior_text = read_source_text(prior_path)
    current_text = read_source_text(current_path)
    prior_tree, current_tree = ast.parse(prior_text), ast.parse(current_text)

    def split(tree: ast.Module) -> tuple[dict[str, str], dict[str, str],
                                        set[str]]:
        functions: dict[str, str] = {}
        assignments: dict[str, str] = {}
        imports: set[str] = set()
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                functions[node.name] = ast.dump(
                    node, include_attributes=False)
            elif isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                assignments[node.targets[0].id] = ast.dump(
                    node, include_attributes=False)
            elif isinstance(node, ast.Import):
                imports.update(alias.name for alias in node.names)
            elif isinstance(node, ast.ImportFrom):
                imports.add((node.module or "") + ":" + ",".join(
                    alias.name for alias in node.names))
        return functions, assignments, imports

    old_functions, old_assignments, old_imports = split(prior_tree)
    new_functions, new_assignments, new_imports = split(current_tree)
    changed_functions = sorted(
        name for name in set(old_functions) | set(new_functions)
        if old_functions.get(name) != new_functions.get(name))
    changed_assignments = sorted(
        name for name in set(old_assignments) | set(new_assignments)
        if old_assignments.get(name) != new_assignments.get(name))
    added_imports = sorted(new_imports - old_imports)
    removed_imports = sorted(old_imports - new_imports)
    expected_functions = sorted([
        "_bind_launch_root_identity", "_process_table_snapshot",
        "_terminate_unbound_launch", "main", "require_natural", "run_phase",
    ])
    if changed_functions != expected_functions or \
            changed_assignments != ["PROJECTION_REUSE_VALIDATOR"] or \
            added_imports != ["math"] or removed_imports:
        raise RuntimeError("r11/r12 launch-generation delta exceeds its scope")
    unified = "".join(difflib.unified_diff(
        prior_text.splitlines(keepends=True),
        current_text.splitlines(keepends=True),
        fromfile=prior_path.relative_to(ROOT).as_posix(),
        tofile=current_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-controller-r11-r12-launch-generation-delta-r1",
        "r11_source": receipt(prior_path),
        "r12_source": receipt(current_path),
        "changed_top_level_functions": changed_functions,
        "changed_module_assignments": changed_assignments,
        "added_imports": added_imports,
        "removed_imports": removed_imports,
        "launch_identity_contract": {
            "binding_handle": "psutil.Popen",
            "binding_identity": ["pid", "finite_positive_create_time"],
            "post_launch_lookup_must_match_handle_generation": True,
            "lookup_or_launch_identity_unreadable_or_mismatched":
                "typed_monitor_incomplete_no_acceptance",
            "cleanup_uses_exact_launch_handle": True,
        },
        "process_table_generation_contract": {
            "retained_rows_live_create_time_rechecked": True,
            "same_pid_different_generation": "incomplete_unless_pid_absent_in_final_inventory",
            "inaccessible_live_generation": "incomplete",
            "static_pid_set_equality_alone_is_sufficient": False,
        },
        "coverage_semantics_changed": False,
        "phase_wall_budget_changed": False,
        "working_set_limit_changed": False,
        "thread_limits_changed": False,
        "semantic_thresholds_changed": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_attempt11_retry3_no_go_lineage(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    decision = ATTEMPT11_RETRY3_NO_GO_ROOT / "decision.md"
    reviewer_report = ATTEMPT11_RETRY3_REVIEW_ROOT / "review.json"
    reviewer_manifest = ATTEMPT11_RETRY3_REVIEW_ROOT / "evidence_manifest.json"
    tester_report = ATTEMPT11_RETRY3_TESTER_ROOT / "review.json"
    tester_manifest = ATTEMPT11_RETRY3_TESTER_ROOT / "archive_manifest.json"
    paths = {
        "decision": decision, "reviewer_report": reviewer_report,
        "reviewer_manifest": reviewer_manifest,
        "tester_report": tester_report, "tester_manifest": tester_manifest,
    }
    receipts: dict[str, dict[str, Any]] = {}
    for name, path in paths.items():
        pin = receipt(path)
        expected = ATTEMPT11_RETRY3_NO_GO_EXPECTED.get(name)
        if expected is not None and pin["sha256"] != expected:
            raise RuntimeError(f"retry3 final NO-GO lineage hash drift: {name}")
        inputs[pin["path"]] = pin
        receipts[name] = pin
    for directory in (ATTEMPT11_RETRY3_REVIEW_ROOT,
                      ATTEMPT11_RETRY3_TESTER_ROOT):
        for path in files_under(directory):
            add_input(inputs, path)
    reviewer_manifest_value = load_object(reviewer_manifest)
    tester_manifest_value = load_object(tester_manifest)
    reviewer_rows = reviewer_manifest_value.get("files", [])
    reviewer_row = next((row for row in reviewer_rows
                         if row.get("path") == reviewer_report.name), None)
    if reviewer_row != {"path": reviewer_report.name,
                        "bytes": receipts["reviewer_report"]["bytes"],
                        "sha256": receipts["reviewer_report"]["sha256"]} or \
            tester_manifest_value.get("review") != receipts["tester_report"]:
        raise RuntimeError("retry3 independent report manifests do not bind reports")
    return {
        "schema": "vnext-t2-attempt11-retry3-final-no-go-lineage-r1",
        "status": "preserved_retry3_no_go_with_final_independent_receipts",
        "decision": receipts["decision"],
        "reviewer_report": receipts["reviewer_report"],
        "reviewer_manifest": receipts["reviewer_manifest"],
        "tester_report": receipts["tester_report"],
        "tester_manifest": receipts["tester_manifest"],
        "formal_t2_accepted": False,
        "julia_started_by_retry4_freezer": False,
    }


def build_attempt10_preflight_interruption_record(
        inputs: dict[str, dict[str, Any]], coverage: dict[str, Any]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT10_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    lineage = {}
    for name, (path, expected_sha256) in ATTEMPT10_LINEAGE_FILES.items():
        add_input(inputs, path)
        pinned = receipt(path)
        if pinned["sha256"] != expected_sha256:
            raise RuntimeError(f"attempt10 root/reviewer lineage pin drift: {name}")
        lineage[name] = pinned
    old_protocol = load_object(ATTEMPT10_FAILURE_FILES["attempt10_protocol"])
    old_coverage = load_object(ATTEMPT10_FAILURE_FILES["attempt10_coverage_map"])
    pipeline = load_object(ATTEMPT10_FAILURE_FILES["pipeline_final"])
    baseline_phase = load_object(ATTEMPT10_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT10_FAILURE_FILES["baseline_summary"])
    phase = load_object(ATTEMPT10_FAILURE_FILES["preflight_phase"])
    expected_cases = coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    old_expected_cases = old_coverage["runtime_execution_plan"][
        "actual_formal_phase_case_ids"]["actual_formal_preflight"]
    observations = [json.loads(line) for line in
        ATTEMPT10_FAILURE_FILES["preflight_observations"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    stdout_text = ATTEMPT10_FAILURE_FILES["preflight_stdout"].read_text(
        encoding="utf-8", errors="replace")
    actual_rows = []
    for line in stdout_text.splitlines():
        marker = "VNEXT_T2_NEGATIVE_ACTUAL="
        if line.startswith(marker):
            actual_rows.append(json.loads(line[len(marker):]))
    sample_rows = [json.loads(line) for line in
        ATTEMPT10_FAILURE_FILES["preflight_samples"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    trace_lines = ATTEMPT10_FAILURE_FILES["preflight_stage_trace"].read_text(
        encoding="utf-8").splitlines()
    trace = {}
    for line in trace_lines[1:]:
        parts = line.split("\t")
        if len(parts) >= 3:
            event, *fields = parts
            values = {}
            for field in fields:
                if "=" in field:
                    key, value = field.split("=", 1)
                    values[key] = value
            trace.setdefault(event, []).append(values)
    sample_peak = max(row.get("process_tree_working_set_bytes", 0)
                      for row in sample_rows)
    observation_ids = [row.get("case_id") for row in observations]
    marker_ids = [row.get("case_id") for row in actual_rows]
    script_entry = trace.get("script_entry", [{}])[0].get("time_ns")
    attack_begin = trace.get("attack_group_preflight.begin", [{}])[0].get(
        "time_ns")
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            old_protocol.get("coverage_map") != receipt(
                ATTEMPT10_FAILURE_FILES["attempt10_coverage_map"]) or \
            old_protocol.get("formal_t2_accepted") is not False or \
            old_protocol.get("julia_started") is True or \
            old_coverage.get("schema") != \
            "vnext-t2-independent-negative-coverage-map-r7" or \
            old_coverage.get("successor_assertion_site_count") != 214 or \
            old_coverage.get("successor_expected_runtime_hit_count") != 622 or \
            old_expected_cases != expected_cases or len(expected_cases) != 18 or \
            baseline_phase.get("name") != "actual_formal_baseline" or \
            baseline_phase.get("stop_reason") != "natural_exit" or \
            baseline_phase.get("exit_code") != 0 or \
            baseline_phase.get("seconds") != 318.56537460000254 or \
            baseline_phase.get("peak_process_tree_working_set_bytes") != \
                1_669_619_712 or baseline_phase.get(
                    "working_set_limit_bytes") != 2_147_483_648 or \
            baseline_summary.get("status") != "pass" or \
            baseline_summary.get("assertion_site_hit_count_observed") != 53 or \
            baseline_summary.get("formal_t2_accepted") is not False or \
            phase.get("name") != "actual_formal_preflight" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or \
            phase.get("timeout_seconds") != 480.0 or \
            abs(phase.get("seconds", 0) - 480.1707022000046) > 0.01 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_754_058_752 or \
            phase.get("formal_t2_accepted") is True or sample_peak != 1_754_058_752 or \
            len(sample_rows) != 2031 or len(observations) != 16 or \
            observation_ids != expected_cases[:16] or marker_ids != observation_ids or \
            observation_ids[-1] != "CHILD_FOREIGN" or \
            expected_cases[16:] != ["FEEDBACK_STALE", "FEEDBACK_FOREIGN"] or \
            "attack_group_preflight.begin" not in trace or \
            "attack_group_preflight.end" in trace or \
            not isinstance(script_entry, str) or not script_entry.isdigit() or \
            not isinstance(attack_begin, str) or not attack_begin.isdigit() or \
            int(attack_begin) <= int(script_entry) or \
            abs((int(attack_begin) - int(script_entry)) / 1_000_000_000 -
                183.6627444) > 0.01 or \
            ATTEMPT10_FAILURE_FILES["preflight_stderr"].read_bytes() != b"" or \
            pipeline.get("status") != "fail" or \
            pipeline.get("failure", {}).get("message") != \
                "actual_formal_preflight stop=phase_wall_timeout" or \
            pipeline.get("assertion_site_hit_aggregate") is not None or \
            pipeline.get("assertion_site_hit_count_observed") is not None or \
            pipeline.get("formal_t2_accepted") is not False or \
            (ATTEMPT10_EXECUTION / "actual_formal_authority").exists():
        raise RuntimeError("attempt10 preflight interruption or 16/18 observation evidence mismatch")
    elapsed = phase["seconds"]
    prep = (int(attack_begin) - int(script_entry)) / 1_000_000_000
    post_prepare = elapsed - prep
    expected_remaining = post_prepare / len(observation_ids) * (
        len(expected_cases) - len(observation_ids))
    extra_budget = 600.0 - elapsed
    estimated_finalization_margin = extra_budget - expected_remaining
    return {
        "schema": "vnext-t2-attempt10-preflight-wall-interruption-r1",
        "status": "preserved_resource_interruption_partial_not_scientific_failure",
        "files": frozen_files,
        "parent_decision_and_independent_reviews": lineage,
        "prior_protocol_schema": old_protocol["schema"],
        "prior_coverage_map": frozen_files["attempt10_coverage_map"],
        "baseline": {
            "natural_exit_code": 0,
            "seconds": baseline_phase["seconds"],
            "actual_assertion_site_hits":
                baseline_summary["assertion_site_hit_count_observed"],
            "peak_process_tree_working_set_bytes":
                baseline_phase["peak_process_tree_working_set_bytes"],
        },
        "preflight": {
            "planned_case_count": len(expected_cases),
            "actual_complete_observation_count": len(observation_ids),
            "completed_case_ids": observation_ids,
            "last_complete_case_id": observation_ids[-1],
            "remaining_case_ids": expected_cases[len(observation_ids):],
            "remaining_cases_claimed_executed": False,
            "timeout_seconds": phase["timeout_seconds"],
            "elapsed_seconds": elapsed,
            "exit_code": phase["exit_code"],
            "stop_reason": phase["stop_reason"],
            "stdout_marker_count": len(actual_rows),
            "stderr_bytes": 0,
            "sample_count": len(sample_rows),
            "peak_process_tree_working_set_bytes": sample_peak,
            "stage_trace_receipt": frozen_files["preflight_stage_trace"],
            "prep_before_attack_group_seconds": round(prep, 6),
            "post_prepare_until_timeout_seconds": round(post_prepare, 6),
            "remaining_two_case_time_at_observed_average_seconds":
                round(expected_remaining, 6),
        },
        "attempt11_budget_change": {
            "prior_preflight_phase_wall_seconds": 480,
            "new_preflight_phase_wall_seconds": 600,
            "other_formal_phase_wall_seconds": 480,
            "additional_wall_seconds_after_attempt10_timeout":
                round(extra_budget, 6),
            "estimated_finalization_margin_after_remaining_cases_seconds":
                round(estimated_finalization_margin, 6),
            "estimate_is_guarantee": False,
            "one_fresh_process_repeats_initialization": True,
            "attempt10_partial_cases_reused": False,
            "failed_attempt11_partial_cases_credit": 0,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "coverage_thresholds_changed": False,
            "formal_t2_accepted": False,
        },
        "formal_t2_accepted": False,
    }


def build_attempt11_initial_freeze_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    files = {}
    for name, path in ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES.items():
        add_input(inputs, path)
        files[name] = receipt(path)
    failure = load_object(ATTEMPT11_INITIAL_FREEZE_FAILURE_FILES[
        "freeze_failure"])
    if failure.get("schema") != \
            "vnext-t2-attempt11-initial-freezer-failure-r1" or \
            failure.get("status") != \
            "preserved_python_freezer_lineage_guard_failure_no_t2_execution" or \
            failure.get("exit_code") != 1 or \
            failure.get("failure_message") != \
            "controller r9 changed unapproved module bindings" or \
            failure.get("failure_location", {}).get("function") != \
            "build_controller_r8_r9_authority_progress_delta" or \
            failure.get("protocol_written") is not False or \
            failure.get("dispatch_written") is not False or \
            failure.get("static_qa_written") is not False or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            failure.get("coverage_map") != files["coverage_map"] or \
            failure.get("stdout") != files["stdout"] or \
            failure.get("stderr") != files["stderr"] or \
            failure.get("freezer_source_at_failure", {}).get("sha256") != \
                "4cb636ec1de1160ce1ec15094efb4b1e48ac61a4e2baebb4c78a3fbf9a72b5d5" or \
            files["freeze_failure"].get("path") != (
                "docs/implementation/UP1-04A-VNEXT-T2/archive/"
                "r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s/"
                "freeze_failure.json") or \
            files["coverage_map"]["sha256"] != \
                "9fb16233ae8c0c4373781450c3f1bffedd3373f4e5a6e44f34f804132f93df41":
        raise RuntimeError("attempt11 initial Python freeze failure is not precisely pinned")
    return {"schema": "vnext-t2-attempt11-initial-freeze-failure-basis-r1",
            "status": "preserved_pre_execution_freezer_failure_only",
            "files": files, "failure": failure,
            "formal_t2_accepted": False}


def build_attempt11_retry1_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, ATTEMPT11_RETRY1_FAILURE)
    failure = load_object(ATTEMPT11_RETRY1_FAILURE)
    preserved_files = failure.get("preserved_retry1_files")
    if not isinstance(preserved_files, dict) or len(preserved_files) != 11:
        raise RuntimeError("attempt11 retry1 failure file inventory is incomplete")
    for relative, expected in preserved_files.items():
        actual = receipt(ROOT / relative)
        if actual != expected:
            raise RuntimeError(f"attempt11 retry1 preserved file drift: {relative}")
        add_input(inputs, ROOT / relative)
    for name in ("protocol", "dispatch", "command_data", "coverage_map"):
        expected = failure.get(name)
        if not isinstance(expected, dict) or \
                preserved_files.get(expected.get("path")) != expected:
            raise RuntimeError(f"attempt11 retry1 failure source pin missing: {name}")
    if failure.get("static_qa_source_at_failure") != {
            "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
                    "static_qa_independent_negative_r9.py",
            "bytes": 202670,
            "sha256": "97d723d11fc389cbcbc9551f6cbccb1cc440c9b0cf3ea4327727d0ae7e9b9d88"} or \
            failure.get("controller_source") != receipt(
                TEST_ROOT / "independent_negative_controller_r10.py"):
        raise RuntimeError("attempt11 retry1 source-at-failure evidence drift")
    protocol = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "protocol.json")
    dispatch = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "dispatch.json")
    qa = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF / "static_qa.json")
    projection_phase = load_object(ATTEMPT11_RETRY1_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json")
    if failure.get("schema") != \
            "vnext-t2-attempt11-retry1-static-qa-failure-r1" or \
            failure.get("status") != \
            "preserved_static_qa_failure_after_projection_preflight_not_acceptance" or \
            failure.get("freezer_exit_code") != 1 or \
            failure.get("static_qa_exit_code") != 1 or \
            failure.get("failure") != {
                "type": "RuntimeError",
                "message": "controller r8/r9 source binding drift"} or \
            failure.get("expected_projection24_natural_exit_code") != 0 or \
            failure.get("observed_projection24_phase") != {
                "name": "projection24_reuse_python_preflight",
                "status": "pass", "stop_reason": "natural_exit", "exit_code": 0,
                "pass_marker_observed": True,
                "pass_marker": PROJECTION_PASS_MARKER} or \
            failure.get("protocol") != preserved_files.get(
                failure.get("protocol", {}).get("path")) or \
            failure.get("dispatch") != preserved_files.get(
                failure.get("dispatch", {}).get("path")) or \
            failure.get("command_data") != preserved_files.get(
                failure.get("command_data", {}).get("path")) or \
            failure.get("coverage_map") != preserved_files.get(
                failure.get("coverage_map", {}).get("path")) or \
            protocol.get("schema") != "vnext-t2-independent-negative-protocol-r4" or \
            protocol.get("formal_t2_accepted") is not False or \
            protocol.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            dispatch.get("formal_t2_accepted") is not False or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            qa.get("status") != "fail" or qa.get("failure") != \
                failure.get("failure") or \
            projection_phase.get("exit_code") != 0 or \
            projection_phase.get("pass_marker") != PROJECTION_PASS_MARKER or \
            failure.get("freeze_snapshot_written") is not False or \
            failure.get("julia_started") is not False or \
            failure.get("formal_t2_accepted") is not False or \
            failure.get("planned_execution_directory_absent") is not True or \
            (ATTEMPT11_RETRY1_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt11 retry1 static QA failure is not precisely pinned")
    return {"schema": "vnext-t2-attempt11-retry1-static-qa-failure-basis-r1",
            "status": "preserved_static_qa_failure_only_no_julia",
            "failure_receipt": receipt(ATTEMPT11_RETRY1_FAILURE),
            "preserved_retry1_files": preserved_files,
            "failure": failure,
            "formal_t2_accepted": False}


def build_attempt11_retry2_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    observed_paths = list(files_under(ATTEMPT11_RETRY2_FAILURE_LEAF))
    observed_relative = {
        path.relative_to(ATTEMPT11_RETRY2_FAILURE_LEAF).as_posix()
        for path in observed_paths}
    if observed_relative != ATTEMPT11_RETRY2_FAILURE_FILES:
        raise RuntimeError("attempt11 retry2 failure artifact inventory drift")
    files = {}
    for path in observed_paths:
        relative = path.relative_to(ROOT).as_posix()
        files[relative] = receipt(path)
        add_input(inputs, path)
    protocol_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "protocol.json"
    dispatch_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "dispatch.json"
    command_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "command_argv.json"
    coverage_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "coverage_map_r8.json"
    qa_path = ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa.json"
    projection_phase_path = ATTEMPT11_RETRY2_FAILURE_LEAF / \
        "projection24_reuse_preflight/phase.json"
    protocol = load_object(protocol_path)
    dispatch = load_object(dispatch_path)
    command = load_object(command_path)
    coverage = load_object(coverage_path)
    qa = load_object(qa_path)
    phase = load_object(projection_phase_path)
    controller_relative = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "independent_negative_controller_r10.py")
    freezer_relative = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "freeze_independent_negative_protocol_r9.py")
    qa_relative = (
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/"
        "static_qa_independent_negative_r9.py")
    historical_sources = {
        "freezer": protocol.get("inputs", {}).get(freezer_relative),
        "static_qa": protocol.get("inputs", {}).get(qa_relative),
        "controller": protocol.get("inputs", {}).get(controller_relative),
    }
    historical_source_paths = {
        "freezer": freezer_relative, "static_qa": qa_relative,
        "controller": controller_relative,
    }
    if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r4" or \
            protocol.get("formal_t2_accepted") is not False or \
            protocol.get("controller_path") != controller_relative or \
            protocol.get("coverage_map") != receipt(coverage_path) or \
            protocol.get("input_count") != len(protocol.get("inputs", {})) or \
            protocol.get("resource_gates", {}).get(
                "phase_wall_timeout_overrides") != {
                    "actual_formal_preflight": 600} or \
            protocol.get("python_cache_exclusion", {}).get(
                "qa_dynamic_import_module_names") != [
                    "vnext_t2_controller_r9",
                    "vnext_t2_projection24_reuse_r4"] or \
            not all(isinstance(historical_sources.get(name), dict) and
                    historical_sources[name].get("path") == relative and
                    isinstance(historical_sources[name].get("bytes"), int) and
                    len(historical_sources[name].get("sha256", "")) == 64
                    for name, relative in historical_source_paths.items()) or \
            historical_sources["controller"] != receipt(
                TEST_ROOT / "independent_negative_controller_r10.py") or \
            dispatch.get("protocol") != receipt(protocol_path) or \
            dispatch.get("formal_t2_accepted") is not False or \
            dispatch.get("julia_started") is not False or \
            command.get("argv") != dispatch.get("command_argv") or \
            command.get("julia_started") is not False or \
            coverage.get("schema") != \
                "vnext-t2-independent-negative-coverage-map-r8" or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622 or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r6" or \
            qa.get("status") != "fail" or \
            qa.get("failure") != {
                "type": "RuntimeError",
                "message": "dynamic Python module loader targets are not explicit"} or \
            qa.get("julia_executed") is not False or \
            phase.get("name") != "projection24_reuse_python_preflight" or \
            phase.get("status") != "pass" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 0 or \
            phase.get("pass_marker") != PROJECTION_PASS_MARKER or \
            phase.get("pass_marker_observed") is not True or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "freeze_snapshot.json").exists() or \
            (ATTEMPT11_RETRY2_FAILURE_LEAF / "static_qa_failure.json").exists():
        raise RuntimeError("attempt11 retry2 static QA failure evidence drift")
    failure = {
        "schema": "vnext-t2-attempt11-retry2-static-qa-failure-r1",
        "status": "preserved_static_qa_failure_after_projection_preflight_not_acceptance",
        "freezer_exit_code": 1,
        "freezer_failure": {
            "type": "RuntimeError",
            "message": "r5 Python static QA failed: exit=1"},
        "static_qa_exit_code": 1,
        "static_qa_failure": qa["failure"],
        "historical_source_pins": historical_sources,
        "files": files,
        "projection24_phase": files[
            projection_phase_path.relative_to(ROOT).as_posix()],
        "projection24_exit_code": 0,
        "coverage_map": files[coverage_path.relative_to(ROOT).as_posix()],
        "python_module_binding_at_failure": protocol[
            "python_cache_exclusion"]["qa_dynamic_import_module_names"],
        "expected_controller_module_binding": "vnext_t2_controller_r10",
        "actual_qa_loader_module_binding": "vnext_t2_controller_r10",
        "julia_started": False,
        "planned_execution_directory_absent": not (
            ROOT / protocol["planned_evidence_directory"]).exists(),
        "freeze_snapshot_written": False,
        "formal_t2_accepted": False,
    }
    if failure["planned_execution_directory_absent"] is not True:
        raise RuntimeError("attempt11 retry2 planned execution directory exists")
    return {
        "schema": "vnext-t2-attempt11-retry2-static-qa-failure-basis-r1",
        "status": "preserved_static_qa_failure_only_no_julia",
        "files": files,
        "failure": failure,
        "formal_t2_accepted": False,
    }


def build_attempt11_retry4_projection_schema_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    expected_hashes = {
        "protocol": "23a5dc1356afdf9b5e9a9272b5fa2f115cce4a3a7f7b89956dca139140f12ee6",
        "phase": "fd1c6cf0536bcb33306ca7440f30e1ab00caf9c586b314b8fbb2476fdb5a84b1",
        "stdout": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "stderr": "0a205f744a100e33ee784c7ffa41c44f85e5a584c0be87a43ba6c72c0e3f0794",
    }
    observed = {}
    for name, path in ATTEMPT11_RETRY4_FAILURE_FILES.items():
        pin = receipt(path)
        if pin["sha256"] != expected_hashes[name]:
            raise RuntimeError(f"retry4 projection failure evidence drift: {name}")
        add_input(inputs, path)
        observed[name] = pin
    old_protocol = load_object(ATTEMPT11_RETRY4_FAILURE_FILES["protocol"])
    phase = load_object(ATTEMPT11_RETRY4_FAILURE_FILES["phase"])
    stderr_text = ATTEMPT11_RETRY4_FAILURE_FILES["stderr"].read_text(
        encoding="utf-8", errors="replace")
    command = phase.get("command_argv")
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r5" or \
            old_protocol.get("coverage_map", {}).get("path") != \
            "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r9.json" or \
            phase.get("schema") != "vnext-t2-projection24-python-preflight-phase-r1" or \
            phase.get("name") != "projection24_reuse_python_preflight" or \
            phase.get("status") != "fail" or \
            phase.get("stop_reason") != "natural_exit" or \
            phase.get("exit_code") != 1 or \
            phase.get("julia_started") is not False or \
            phase.get("pass_marker_observed") is not False or \
            not isinstance(command, list) or len(command) != 5 or \
            Path(command[2]).name != "validate_projection24_reuse_r4.py" or \
            "RuntimeError: projection reuse protocol schema mismatch" not in stderr_text:
        raise RuntimeError("retry4 projection schema failure is not exact")
    return {
        "schema": "vnext-t2-attempt11-retry4-projection-schema-failure-r1",
        "status": "preserved_projection_preflight_failure_no_julia",
        "failure_class": "validator_schema_compatibility_error",
        "protocol_schema": old_protocol["schema"],
        "coverage_map_schema": "vnext-t2-independent-negative-coverage-map-r9",
        "validator_path": old_protocol["projection24_reuse_validator_path"],
        "phase": observed["phase"],
        "files": observed,
        "natural_exit_code": 1,
        "stderr_error": "RuntimeError: projection reuse protocol schema mismatch",
        "formal_t2_accepted": False,
        "julia_started": False,
    }


def build_attempt9c_interruption_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    receipts = {}
    expected = {
        "archive_protocol": "c8c258a73e824824734578b440906c6db69394c33c78ad216917f70efe3dc708",
        "archive_coverage_map": "59442e71116459b9de143d8edcfe451a6c1fbf8ad09187b89ba5fdd3b1a3af27",
        "pipeline_start": "7099389719d2adafb87a379efbd2efc6568fd85c3f8170f01ced2ba6ca18567e",
        "pipeline_final": "e92131b85b6e595ab9034a38df6100cdb035bd4cf047811074b10ddd3f8cd2f0",
        "baseline_phase": "0e38783819a4385a19701ce30d0ddf56a7e2a01ce0d5cc08016f5eeb0b980c23",
        "baseline_summary": "eeca7d2dd4e882800a589ad07266ae91738c1d9e13f8de5e1910e2f3ab2df0a2",
        "baseline_context": "794ee8232c7f2b67be8de58421d557d133a336396547e215d4e4f7ef5b0f68d1",
        "baseline_authorization": "7f1a78c6b8a2eea7a27d46d619be548379820c2eece28a72ca5c09ad9419e664",
        "authority_phase": "78dc730a1fa9f823ce57d12330e1dfd0a3f0bd6bcc516d6060e90b2149f5115d",
        "authority_stdout": "7688d6dda69029dc0da4059c9529f58b92174bfe3595f90741ab48d28e6ea396",
        "authority_stderr": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "authority_samples": "a091b18fdf1254b11265bdca99d1b4179d4abde4b805089f0a4fe92564909c87",
        "authority_observations": "e6bc7fe03984b2697cbd40af32b826d4a04da1aafd7d2b53e032b72a089e6fb5",
        "authority_transport": "e6f9b52f5f9f3a364dc2064f1cbf8c5b7eedb108754a9c2d32423a68bf9a1dd9",
        "authority_stage_trace": "b6148109e31860c7fabc3c72e26ace2d59476e2560ee5e8061c0ab171eb6baed",
    }
    for name, path in ATTEMPT9C_FAILURE_FILES.items():
        pin = receipt(path)
        if pin["sha256"] != expected[name] or inputs.get(pin["path"]) != pin:
            raise RuntimeError(f"attempt9c interruption pin drift: {name}")
        receipts[name] = pin
    pipeline = load_object(ATTEMPT9C_FAILURE_FILES["pipeline_final"])
    baseline = load_object(ATTEMPT9C_FAILURE_FILES["baseline_phase"])
    baseline_summary = load_object(ATTEMPT9C_FAILURE_FILES["baseline_summary"])
    phase = load_object(ATTEMPT9C_FAILURE_FILES["authority_phase"])
    trace_lines = ATTEMPT9C_FAILURE_FILES["authority_stage_trace"].read_text(
        encoding="utf-8").splitlines()
    stdout_lines = ATTEMPT9C_FAILURE_FILES["authority_stdout"].read_text(
        encoding="utf-8", errors="replace").splitlines()
    observations = [json.loads(line) for line in
        ATTEMPT9C_FAILURE_FILES["authority_observations"].read_text(
            encoding="utf-8").splitlines() if line.strip()]
    last_trace = trace_lines[-1] if trace_lines else ""
    last_stdout = next((line.removeprefix("VNEXT_T2_NEGATIVE_STAGE=")
        for line in reversed(stdout_lines)
        if line.startswith("VNEXT_T2_NEGATIVE_STAGE=")), "")
    expected_pre_assertion_observation = {
        "case_id": "PARENT_STALE",
        "status": "fail_closed",
        "resolution": "none",
        "first_reason": "t2_preflight_parent_commitment_mismatch",
        "committed": False,
        "ledger_status": "complete_contract_receipts",
    }
    if baseline.get("stop_reason") != "natural_exit" or baseline.get("exit_code") != 0 or \
            baseline_summary.get("status") != "pass" or \
            phase.get("name") != "actual_formal_authority" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or phase.get("timeout_seconds") != 480.0 or \
            phase.get("seconds") != 480.20754000000306 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase.get("peak_process_tree_working_set_bytes") != 1_703_682_048 or \
            phase.get("residual_heavy_processes") != [] or \
            pipeline.get("status") != "fail" or \
            pipeline.get("formal_t2_accepted") is not False or \
            pipeline.get("inputs_before") != pipeline.get("inputs_after") or \
            last_trace.split("\t", 1)[0] != "attack_group_authority.begin" or \
            last_stdout != last_trace or \
            len(observations) != 1 or observations[0].get("case_id") != "PARENT_STALE" or \
            observations[0].get("status") != "fail_closed" or \
            observations[0].get("resolution") != "none" or \
            observations[0].get("first_reason") != \
                "t2_preflight_parent_commitment_mismatch" or \
            observations[0].get("committed") is not False or \
            observations[0].get("ledger", {}).get("status") != \
                "complete_contract_receipts":
        raise RuntimeError("attempt9c authority interruption does not match pinned failure")
    missing = [
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/summary.json",
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/case_progress.jsonl",
        ATTEMPT9C_EXECUTION / "actual_formal_authority/artifacts/authority_case_aggregate.json",
    ]
    if any(path.exists() for path in missing):
        raise RuntimeError("attempt9c interruption has forbidden completion artifacts")
    return {
        "schema": "vnext-t2-attempt9c-authority-resource-interruption-r1",
        "status": "resource_interruption_incomplete_not_scientific_fail_not_accepted",
        "attempt9c_protocol": receipts["archive_protocol"],
        "attempt9c_coverage_map": receipts["archive_coverage_map"],
        "pipeline_start": receipts["pipeline_start"],
        "pipeline_final": receipts["pipeline_final"],
        "baseline_phase": {"receipt": receipts["baseline_phase"],
            "stop_reason": baseline["stop_reason"], "exit_code": baseline["exit_code"],
            "summary_status": baseline_summary["status"]},
        "authority_phase": {"receipt": receipts["authority_phase"],
            "stop_reason": phase["stop_reason"], "exit_code": phase["exit_code"],
            "elapsed_seconds": phase["seconds"], "timeout_seconds": phase["timeout_seconds"],
            "working_set_limit_bytes": phase["working_set_limit_bytes"],
            "peak_process_tree_working_set_bytes": phase[
                "peak_process_tree_working_set_bytes"],
            "residual_heavy_processes": phase["residual_heavy_processes"]},
        "authority_raw_receipts": {name: receipts[name] for name in
            ("authority_stdout", "authority_stderr", "authority_samples",
             "authority_observations", "authority_transport", "authority_stage_trace")},
        "last_completed_stage_marker": last_trace,
        "last_stdout_stage_marker": last_stdout,
        "pre_assertion_observation_case_ids": [row["case_id"] for row in observations],
        "pre_assertion_observation": expected_pre_assertion_observation,
        "assertion_completion_status": "unknown_no_authority_summary_or_case_progress",
        "authority_completion_artifacts_absent": [p.relative_to(ROOT).as_posix()
            for p in missing],
        "input_pins_unchanged": pipeline["inputs_before"] == pipeline["inputs_after"],
        "formal_t2_accepted": False,
    }


def build_attempt9b_static_qa_failure_record(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    frozen_files: dict[str, dict[str, Any]] = {}
    for name, path in ATTEMPT9B_FAILURE_FILES.items():
        add_input(inputs, path)
        frozen_files[name] = receipt(path)
    previous_protocol = load_object(ATTEMPT9B_FAILURE_FILES["protocol"])
    previous_phase = load_object(ATTEMPT9B_FAILURE_FILES["preflight_phase"])
    previous_dispatch = load_object(ATTEMPT9B_FAILURE_FILES["dispatch"])
    previous_command = load_object(ATTEMPT9B_FAILURE_FILES["command"])
    previous_receipt = load_object(
        ATTEMPT9B_FAILURE_FILES["preflight_receipt"])
    qa = load_object(ATTEMPT9B_FAILURE_FILES["static_qa"])
    previous_static_qa = TEST_ROOT / "static_qa_independent_negative_r4b.py"
    previous_static_qa_receipt = receipt(previous_static_qa)
    if previous_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r4" or \
            previous_protocol.get("formal_t2_accepted") is not False or \
            previous_protocol.get("julia_started") is True or \
            previous_protocol.get("coverage_map") != frozen_files["coverage_map"] or \
            previous_dispatch.get("julia_started") is not False or \
            previous_command.get("julia_started") is not False or \
            previous_phase.get("name") != \
            "projection24_reuse_python_preflight" or \
            previous_phase.get("status") != "pass" or \
            previous_phase.get("stop_reason") != "natural_exit" or \
            previous_phase.get("exit_code") != 0 or \
            previous_phase.get("julia_started") is not False or \
            previous_phase.get("formal_t2_accepted") is not False or \
            previous_phase.get("command_argv", [None])[2] != str(
                TEST_ROOT / "validate_projection24_reuse_r4.py") or \
            previous_receipt.get("schema") != \
            "vnext-t2-projection24-cross-run-validation-r4" or \
            previous_receipt.get("assertion_sites_completed") != 24 or \
            previous_receipt.get("natural_exit_zero") is not True or \
            previous_receipt.get("post_assertion_pass_marker") is not True or \
            qa.get("schema") != "vnext-t2-independent-negative-static-qa-r4" or \
            qa.get("status") != "fail" or qa.get("failure") != \
            ATTEMPT9B_EXPECTED_QA_FAILURE or \
            qa.get("julia_executed") is not False or \
            previous_protocol.get("inputs", {}).get(
                previous_static_qa_receipt["path"]) != previous_static_qa_receipt or \
            inputs.get(previous_static_qa_receipt["path"]) != \
                previous_static_qa_receipt or \
            "positive_evidence_receipts,\n            controller_source, controls)" not in \
                read_source_text(previous_static_qa) or \
            (ATTEMPT9B_FAILURE_LEAF / "freeze_snapshot.json").exists():
        raise RuntimeError("attempt9b static QA failure basis is inconsistent")
    return {
        "schema": "vnext-t2-attempt9b-static-qa-failure-r1",
        "status": "preserved_static_qa_failure_not_acceptance",
        "files": frozen_files,
        "observed_failure": ATTEMPT9B_EXPECTED_QA_FAILURE,
        "projection_preflight_natural_exit_code": 0,
        "projection_reuse_sites_completed": 24,
        "julia_started": False,
        "formal_t2_accepted": False,
    }


def require_runtime_pins(inputs: dict[str, dict[str, Any]],
                         runtime_inputs: dict[str, Any]) -> dict[str, dict[str, Any]]:
    source = runtime_inputs.get("inputs")
    if not isinstance(source, dict) or runtime_inputs.get("schema") != \
            "vnext-t2-formal-runtime-inputs-r3" or \
            runtime_inputs.get("runtime_dependency_count") != 104 or \
            len(source) != 104:
        raise RuntimeError("positive r3 runtime input inventory is not 104")
    pins: dict[str, dict[str, Any]] = {}
    for relative, raw in sorted(source.items()):
        if not isinstance(raw, dict) or raw.get("path") != relative or \
                not isinstance(raw.get("bytes"), int) or raw["bytes"] < 0 or \
                not isinstance(raw.get("sha256"), str) or \
                len(raw["sha256"]) != 64:
            raise RuntimeError(f"malformed positive r3 input pin: {relative}")
        actual = receipt(ROOT / relative)
        if actual != raw:
            raise RuntimeError(f"positive r3 current input drift: {relative}")
        pins[relative] = dict(raw)
        inputs[relative] = dict(raw)
    return pins


def build_projection24_reuse_plan(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    old_protocol = load_object(R1_SOURCE_PROTOCOL)
    historical_inputs = old_protocol.get("inputs")
    if old_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r1" or \
            not isinstance(historical_inputs, dict) or \
            len(historical_inputs) != 157:
        raise RuntimeError("historical r1 protocol input contract is invalid")

    intersection = {
        relative: dict(historical_inputs[relative])
        for relative in sorted(historical_inputs)
        if inputs.get(relative) == historical_inputs[relative]
    }
    exclusions = []
    for relative in sorted(historical_inputs):
        old_pin = historical_inputs[relative]
        current_pin = inputs.get(relative)
        if current_pin == old_pin:
            continue
        exclusions.append({
            "historical_pin": dict(old_pin),
            "classification": (
                "missing_from_current_protocol_input_closure"
                if current_pin is None else
                "current_path_bytes_or_sha256_changed"),
            "current_pin": dict(current_pin) if current_pin is not None else None,
        })

    direct_paths = {
        "source_protocol": R1_SOURCE_PROTOCOL,
        "source_pipeline_final": R1_PIPELINE_FINAL,
        "source_timeout_execution_receipt": R1_TIMEOUT_RECEIPT,
    }
    direct_receipts = {name: receipt(path)
                       for name, path in direct_paths.items()}
    phase_receipts = {name: receipt(path) for name, path in
                      sorted(R1_PROJECTION_PHASE_FILES.items())}
    consumed_paths = set(intersection)
    consumed_paths.update(pin["path"] for pin in direct_receipts.values())
    consumed_paths.update(pin["path"] for pin in phase_receipts.values())
    missing_consumed = sorted(path for path in consumed_paths if path not in inputs)
    if missing_consumed:
        raise RuntimeError(
            "projection24 validator dependencies are outside current pins: " +
            ", ".join(missing_consumed))
    dependencies = {path: dict(inputs[path]) for path in sorted(consumed_paths)}
    if any(row != inputs[path] for path, row in dependencies.items()):
        raise RuntimeError("projection24 dependency map differs from current inputs")
    return {
        "schema": "vnext-t2-projection24-cross-run-reuse-r1",
        "status": "frozen_r1_evidence_with_exact_current_join",
        "source_protocol": direct_receipts["source_protocol"],
        "source_pipeline_final": direct_receipts["source_pipeline_final"],
        "source_timeout_execution_receipt":
            direct_receipts["source_timeout_execution_receipt"],
        "phase_files": phase_receipts,
        "source_input_count": len(historical_inputs),
        "r1_input_intersection": intersection,
        "r1_input_intersection_count": len(intersection),
        "excluded_r1_input_rows": exclusions,
        "excluded_r1_input_count": len(exclusions),
        "dependency_subset": dependencies,
        "dependency_subset_count": len(dependencies),
        "dependency_count": len(dependencies),
    }


def build_attempt7_interruption_record() -> dict[str, Any]:
    protocol_path = ATTEMPT7_ARCHIVE_LEAF / "protocol.json"
    pipeline_path = ATTEMPT7_EXECUTION / "pipeline_final.json"
    phase_path = ATTEMPT7_BASELINE / "phase.json"
    stage_trace_path = ATTEMPT7_BASELINE / "artifacts/stage_trace.tsv"
    observation_path = ATTEMPT7_BASELINE / "artifacts/observations.jsonl"
    stdout_path = ATTEMPT7_BASELINE / "stdout.raw"
    stderr_path = ATTEMPT7_BASELINE / "stderr.raw"
    sample_path = ATTEMPT7_BASELINE / "samples.jsonl"
    receipts = {
        "protocol": receipt(protocol_path),
        "pipeline_final": receipt(pipeline_path),
        "coverage_map": receipt(ATTEMPT7_COVERAGE),
        "phase": receipt(phase_path),
        "stage_trace": receipt(stage_trace_path),
        "observations": receipt(observation_path),
        "stdout": receipt(stdout_path),
        "stderr": receipt(stderr_path),
        "samples": receipt(sample_path),
    }
    expected_sha256 = {
        "protocol": "3a792f89ab2e9db3bff408dd0a7da3c5eb564d6807090c8fa0bbfa6004ec5c00",
        "pipeline_final": "99f8c45f176c0cbf0f9cab0d084466e0b800b1ffa8f48cd08ebf24457f99ff13",
        "coverage_map": "4e79435b9842ecd435fadeb50334e1f500e5635d8f9fef760bfc085ef655bd3d",
        "phase": "08b58aff9bf0ff0882c241661d02e1058f0228cf182e3738e75d93d3bd621c30",
        "stage_trace": "d8db64827821d907445a04f8c44cba1d7a4917a435b78c1777d5ffd4bebc5dec",
        "observations": "b2dd75ba13c1d79d707c8e5cd493cd32e82f8e20de53674a5a22a88118adea66",
        "stdout": "26a5c424d0ad4ea9377b1cc4db66009f0a3971c22a1f9e5be9d3e5c5ab2115aa",
        "stderr": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "samples": "9f74adf8431ba3af8cbe4eba6182c16759c040efa3de85d0568504dd14d76c42",
    }
    if any(receipts[name]["sha256"] != sha for name, sha in
           expected_sha256.items()):
        raise RuntimeError("attempt7 immutable interruption evidence drift")
    phase = load_object(phase_path)
    pipeline = load_object(pipeline_path)
    observation_rows = [json.loads(line) for line in
                       observation_path.read_text(encoding="utf-8").splitlines()
                       if line.strip()]
    trace_rows = stage_trace_path.read_text(encoding="utf-8").splitlines()
    last_marker = next((line for line in reversed(trace_rows)
                        if line.startswith("five_consumer_baseline.end\t")), None)
    required_missing = [
        ATTEMPT7_BASELINE / "artifacts/summary.json",
        ATTEMPT7_BASELINE / "artifacts/baseline_context.jls",
        ATTEMPT7_EXECUTION / "actual_formal_baseline_authorization.json",
    ]
    if phase.get("name") != "actual_formal_baseline" or \
            phase.get("stop_reason") != "phase_wall_timeout" or \
            phase.get("exit_code") != 15 or phase.get("timeout_seconds") != 300.0 or \
            phase.get("working_set_limit_bytes") != 2_147_483_648 or \
            pipeline.get("status") != "fail" or \
            len(observation_rows) != 1 or \
            observation_rows[0].get("case_id") != "ACTUAL_BASELINE_POSITIVE" or \
            observation_rows[0].get("status") != "complete_contract_receipts" or \
            last_marker is None or \
            "detail=status=complete_contract_receipts" not in last_marker or \
            any(path.exists() for path in required_missing):
        raise RuntimeError("attempt7 interruption state does not match frozen failure")
    return {
        "status": "phase_wall_timeout_incomplete_not_accepted",
        "archive_leaf": ATTEMPT7_ARCHIVE_LEAF.relative_to(ROOT).as_posix(),
        "evidence": receipts,
        "baseline_phase": {
            "name": phase["name"], "stop_reason": phase["stop_reason"],
            "exit_code": phase["exit_code"], "timeout_seconds": phase["timeout_seconds"],
            "elapsed_seconds": phase["seconds"],
            "working_set_limit_bytes": phase["working_set_limit_bytes"],
            "peak_process_tree_working_set_bytes":
                phase["peak_process_tree_working_set_bytes"],
        },
        "last_completed_marker": last_marker,
        "pre_assertion_observation_ids": [
            row["case_id"] for row in observation_rows],
        "pre_assertion_observation_count": len(observation_rows),
        "baseline_completion_artifacts_absent": [
            path.relative_to(ROOT).as_posix() for path in required_missing],
        "formal_t2_accepted": False,
    }


def build_attempt7_relocation_ledger(
        current: dict[str, Any], prior: dict[str, Any],
        current_map_path: Path) -> dict[str, Any]:
    old_sites = {row["id"]: row for row in prior["successor_assertion_sites"]}
    new_sites = {row["id"]: row for row in current["successor_assertion_sites"]}
    if set(old_sites) != set(new_sites) or len(old_sites) != 214:
        raise RuntimeError("attempt7 source relocation requires the exact 214 IDs")
    source_cache: dict[str, list[str]] = {}
    entries = []
    for site_id in sorted(old_sites):
        old, new = old_sites[site_id], new_sites[site_id]
        if any(old[field] != new[field] for field in (
                "macro_name", "source_text", "source_text_sha256",
                "runtime_multiplicity", "expected_phase_hits")):
            raise RuntimeError(f"attempt7 assertion content/hit drift: {site_id}")
        relative = new["path"]
        source_path = ROOT / relative
        if relative not in source_cache:
            source_cache[relative] = read_source_text(source_path).splitlines()
        lines = source_cache[relative]
        if not 1 <= new["line"] <= len(lines):
            raise RuntimeError(f"attempt8 source line is outside file: {site_id}")
        actual_text = assertion_expression(lines, new["line"])
        actual_sha = sha256_bytes(actual_text.encode("utf-8"))
        if actual_text != new["source_text"] or \
                actual_sha != new["source_text_sha256"]:
            raise RuntimeError(f"attempt8 source text/line drift: {site_id}")
        entries.append({
            "id": site_id,
            "attempt7": {"path": old["path"], "line": old["line"]},
            "attempt8": {"path": new["path"], "line": new["line"]},
            "line_delta": new["line"] - old["line"],
            "path_changed": new["path"] != old["path"],
            "source_text": new["source_text"],
            "source_text_sha256": new["source_text_sha256"],
            "source_text_matches_attempt7": True,
            "current_source_line_verified": True,
        })
    return {
        "schema": "vnext-t2-attempt7-attempt8-source-relocation-ledger-r1",
        "status": "semantic_contract_equal_with_each_current_source_line_verified",
        "attempt7_coverage_map": receipt(ATTEMPT7_COVERAGE),
        "attempt8_coverage_map": receipt(current_map_path),
        "site_count": len(entries),
        "path_changed_site_count": sum(row["path_changed"] for row in entries),
        "line_changed_site_count": sum(row["line_delta"] != 0 for row in entries),
        "source_text_match_count": sum(
            row["source_text_matches_attempt7"] for row in entries),
        "current_source_line_verified_count": sum(
            row["current_source_line_verified"] for row in entries),
        "entries": entries,
    }


def run_projection24_preflight(output: Path,
                               protocol_path: Path) -> dict[str, Any]:
    evidence_dir = output / "projection24_reuse_preflight"
    evidence_dir.mkdir()
    receipt_path = evidence_dir / "reuse_receipt.json"
    stdout_path = evidence_dir / "stdout.raw"
    stderr_path = evidence_dir / "stderr.raw"
    phase_path = evidence_dir / "phase.json"
    command = [sys.executable, "-B", str(PROJECTION_REUSE_VALIDATOR),
               str(protocol_path), str(receipt_path)]
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    started = datetime.now(timezone.utc).isoformat()
    start_tick = time.perf_counter()
    try:
        result = subprocess.run(
            command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, timeout=300, check=False)
        stop_reason = "natural_exit"
        returncode: int | None = result.returncode
        stdout_bytes, stderr_bytes = result.stdout, result.stderr
    except subprocess.TimeoutExpired as error:
        stop_reason = "phase_wall_timeout"
        returncode = None
        stdout_bytes = error.stdout or b""
        stderr_bytes = error.stderr or b""
    elapsed = time.perf_counter() - start_tick
    ended = datetime.now(timezone.utc).isoformat()
    stdout_path.write_bytes(stdout_bytes)
    stderr_path.write_bytes(stderr_bytes)
    phase = {
        "schema": "vnext-t2-projection24-python-preflight-phase-r1",
        "name": "projection24_reuse_python_preflight",
        "status": "pass" if stop_reason == "natural_exit" and
        returncode == 0 else "fail",
        "stop_reason": stop_reason,
        "exit_code": returncode,
        "started_utc": started,
        "ended_utc": ended,
        "elapsed_seconds": elapsed,
        "timeout_seconds": 300,
        "command_argv": command,
        "working_directory": str(ROOT),
        "stdout": receipt(stdout_path),
        "stderr": receipt(stderr_path),
        "receipt": receipt(receipt_path) if receipt_path.is_file() else None,
        "pass_marker": PROJECTION_PASS_MARKER,
        "pass_marker_observed": PROJECTION_PASS_MARKER in
        stdout_bytes.decode("utf-8", errors="replace"),
        "julia_started": False,
        "formal_t2_accepted": False,
    }
    write_json_new(phase_path, phase)
    if returncode != 0 or stop_reason != "natural_exit":
        raise RuntimeError(
            f"projection24 Python preflight did not naturally exit 0: "
            f"{stop_reason} exit={returncode}")
    if PROJECTION_PASS_MARKER not in stdout_bytes.decode(
            "utf-8", errors="replace") or not receipt_path.is_file():
        raise RuntimeError("projection24 Python preflight marker/receipt absent")
    reuse = load_object(receipt_path)
    if reuse.get("status") != "pass" or \
            reuse.get("assertion_sites_completed") != 24 or \
            reuse.get("natural_exit_zero") is not True or \
            reuse.get("post_assertion_pass_marker") is not True:
        raise RuntimeError("projection24 Python preflight receipt is incomplete")
    return receipt(phase_path)


def build_controller_r18_r19_snapshot_predicate_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r18_path = TEST_ROOT / "independent_negative_controller_r18.py"
    r19_path = R19_CONTROLLER
    add_input(inputs, r18_path)
    add_input(inputs, r19_path)
    old_text = read_source_text(r18_path)
    new_text = read_source_text(r19_path)
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in ast.parse(old_text).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in ast.parse(new_text).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected_changed = ["_verify_r23_native_snapshot_receipt",
                        "verify_baseline_heavy_processes_clear"]
    if changed != expected_changed or \
            "_verify_r23_native_snapshot_receipt(snapshot)" not in new_text or \
            "set(snapshot) != expected_fields" not in new_text or \
            "raw_identity_digest_sha256" not in new_text or \
            "WINDOWS_BUILD_PIN" not in new_text or \
            "SYSTEM_INFORMATION_CLASS" not in new_text or \
            "SPI_FIXED_HEADER_BYTES" not in new_text or \
            "MAX_QUERY_ATTEMPTS" not in new_text:
        raise RuntimeError("R18-to-R19 controller delta exceeds full snapshot receipt validation")
    unified = "".join(difflib.unified_diff(
        old_text.splitlines(keepends=True), new_text.splitlines(keepends=True),
        fromfile=r18_path.relative_to(ROOT).as_posix(),
        tofile=r19_path.relative_to(ROOT).as_posix()))
    return {
        "schema": "vnext-t2-r18-r19-snapshot-predicate-delta-r1",
        "r18_source": receipt(r18_path),
        "r19_source": receipt(r19_path),
        "changed_top_level_functions": changed,
        "exact_snapshot_fields": sorted([
            "schema", "complete", "row_count", "host_identity",
            "system_information_class", "buffer_bytes", "query_attempts",
            "raw_identity_digest_sha256", "identity_authority"]),
        "native_host_build_pin": [10, 0, 26200, "AMD64"],
        "field_ranges_and_digest_format_fail_closed": True,
        "baseline_and_final_share_predicate": True,
        "coverage_or_threshold_changed": False,
        "unified_diff_sha256": sha256_bytes(unified.encode("utf-8")),
        "unified_diff": unified,
    }


def build_controller_r19_r20_process_sample_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r19_path = R19_CONTROLLER
    r20_path = R20_CONTROLLER
    add_input(inputs, r19_path)
    add_input(inputs, r20_path)
    old_text = read_source_text(r19_path)
    new_text = read_source_text(r20_path)
    old_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in ast.parse(old_text).body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    new_tree = ast.parse(new_text)
    new_functions = {node.name: ast.dump(node, include_attributes=False)
                     for node in new_tree.body
                     if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected_changed = [
        "_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race",
        "_r20_descendants_from_pid_set",
        "_r20_native_sample",
        "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows",
        "_r20_valid_snapshot_receipt",
        "_r23_audit_and_cleanup",
        "_r23_final_audit",
        "_r23_native_sample",
        "main",
        "require_t2_execution_leaf",
        "run_phase",
        "verify_authority_resume_ancestry",
    ]
    sampler_node = next((node for node in new_tree.body
                         if isinstance(node, ast.FunctionDef) and
                         node.name == "_r20_native_sample"), None)
    sampler_source = ast.get_source_segment(new_text, sampler_node) \
        if sampler_node is not None else None
    nested_functions = {node.name: node for node in ast.walk(sampler_node)
                        if isinstance(node, ast.FunctionDef)} if sampler_node else {}

    def called_name(node: ast.AST) -> str | None:
        if not isinstance(node, ast.Call):
            return None
        return ast.unparse(node.func)

    def call_count(node: ast.AST | None, name: str) -> int:
        if node is None:
            return 0
        return sum(called_name(child) == name for child in ast.walk(node))

    race_helper = nested_functions.get("record_unbound_sample_race")
    handle_provider_node = nested_functions.get("handle_provider")
    resource_reader_node = nested_functions.get("sample_resource_reader")
    race_helper_source = ast.get_source_segment(new_text, race_helper) \
        if race_helper is not None else None
    loops = [node for node in ast.walk(race_helper) if isinstance(node, ast.For) and
             isinstance(node.target, ast.Name) and node.target.id == "_" and
             isinstance(node.iter, ast.Call) and called_name(node.iter) == "range" and
             len(node.iter.args) == 1 and isinstance(node.iter.args[0], ast.Constant) and
             node.iter.args[0].value == 3] if race_helper is not None else []
    loop_queries = [node for loop in loops for node in ast.walk(loop)
                    if called_name(node) == "_R23_TABLE.query_native_process_table"]
    validated_query_calls = [node for loop in loops for node in ast.walk(loop)
                             if called_name(node) == "_R23_TABLE.validate_snapshot" and
                             any(called_name(child) ==
                                 "_R23_TABLE.query_native_process_table"
                                 for child in ast.walk(node))]
    open_try = next((node for node in ast.walk(handle_provider_node)
                     if isinstance(node, ast.Try) and
                     call_count(node, "registry.for_row") == 1), None) \
        if handle_provider_node is not None else None
    open_failure_calls_race = open_try is not None and \
        sum(call_count(handler, "record_unbound_sample_race")
            for handler in open_try.handlers) == 1
    resource_failure_calls_race = call_count(
        resource_reader_node, "record_unbound_sample_race") == 1
    resource_reader_source = ast.get_source_segment(new_text, resource_reader_node) \
        if resource_reader_node is not None else None
    resource_liveness_gate = resource_reader_source is not None and \
        resource_reader_source.index("if not already_exited:") < \
            resource_reader_source.index("record_unbound_sample_race(")
    post_sample_guards = [node for node in ast.walk(sampler_node)
                          if isinstance(node, ast.If) and
                          "final_exact.get('complete') is not True" in ast.unparse(node.test) and
                          "attempt_state.get('unbound_race') is None" in ast.unparse(node.test)] \
        if sampler_node is not None else []
    post_sample_failure_calls_race = len(post_sample_guards) == 1 and \
        call_count(post_sample_guards[0], "record_unbound_sample_race") == 1
    post_sample_signaled_gates = [node for node in ast.walk(sampler_node)
                                  if isinstance(node, ast.If) and
                                  "type(signaled_after_sample) is bool and signaled_after_sample" \
                                      in ast.unparse(node.test)]
    post_sample_liveness_gate = len(post_sample_signaled_gates) == 1 and \
        call_count(post_sample_signaled_gates[0],
                   "record_unbound_sample_race") == 1
    source_bound_before_open = sampler_source is not None and \
        "source.by_pid.get(identity[0])" in sampler_source and \
        sampler_source.index("source.by_pid.get(identity[0])") < \
            sampler_source.index("handle = registry.for_row(row, source)")
    race_helper_valid = race_helper_source is not None and \
        len(loops) == 1 and len(loop_queries) == 1 and \
        call_count(race_helper,
                   "_R23_TABLE.query_native_process_table") == 1 and \
        len(validated_query_calls) == 1 and \
        call_count(race_helper, "_r20_confirm_unbound_sample_race") == 1 and \
        "fresh_tables.append" in race_helper_source and \
        "time.monotonic() >= deadline_monotonic" in race_helper_source
    if changed != expected_changed or sampler_source is None or \
            "lookup = _R23_TABLE.validate_snapshot" in sampler_source or \
            not source_bound_before_open or not race_helper_valid or \
            not open_failure_calls_race or not resource_failure_calls_race or \
            not resource_liveness_gate or not post_sample_failure_calls_race or \
            not post_sample_liveness_gate or \
            "R20_MAX_WHOLE_SAMPLE_ATTEMPTS = 2" not in new_text:
        raise RuntimeError(
            "R19-to-R20 controller delta does not bind the before-snapshot, run "
            "exactly three validated confirmation snapshots, and route each "
            "handle/resource/post-sample exit race through the shared fail-closed recovery")
    return {
        "schema": "vnext-t2-r19-r20-process-sample-race-delta-r1",
        "r19_source": receipt(r19_path),
        "r20_source": receipt(r20_path),
        "changed_top_level_functions": changed,
        "before_snapshot_handle_binding": True,
        "post_open_failure_fresh_snapshot_count": 3,
        "requires_target_subtree_and_orphans_absent": True,
        "requires_exact_root_and_previous_generations": True,
        "whole_sample_retry_cap": 2,
        "failed_attempt_metric_credit_bytes": 0,
        "failed_attempt_exit_credit": False,
        "coverage_thresholds_changed": False,
        "resource_limits_changed": False,
    }


def build_r18_predicate_probe_no_go_lineage(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r18_protocol_path = R18_FREEZE_RETRY2_LEAF / "protocol.json"
    r18_qa_path = R18_FREEZE_RETRY2_LEAF / "static_qa.json"
    r18_snapshot_path = R18_FREEZE_RETRY2_LEAF / "freeze_snapshot.json"
    for path in files_under(R18_FREEZE_RETRY2_LEAF):
        add_input(inputs, path)
    tester_files_list = list(files_under(R18_PREDICATE_TESTER_LEAF))
    for path in tester_files_list:
        add_input(inputs, path)
    review_files_list = list(files_under(R18_REVIEW_LEAF))
    for path in review_files_list:
        add_input(inputs, path)
    add_input(inputs, R18_PREDICATE_TESTER_SOURCE)

    r18_protocol = load_object(r18_protocol_path)
    r18_qa = load_object(r18_qa_path)
    if r18_protocol.get("schema") != "vnext-t2-independent-negative-protocol-r8" or \
            r18_protocol.get("formal_t2_accepted") is not False or \
            r18_qa.get("status") != "pass_static_r18_r23_no_julia" or \
            r18_qa.get("julia_executed") is not False:
        raise RuntimeError("R18 frozen predecessor is not the expected static-only artifact")
    r18_protocol_pin = receipt(r18_protocol_path)
    tester_output_path = R18_PREDICATE_TESTER_LEAF / "predicate_probe_r4.stdout.raw"
    probe = load_object(tester_output_path)
    expected_failures = {
        "snapshot_missing_host_identity", "snapshot_wrong_host_identity",
        "snapshot_missing_system_information_class",
        "snapshot_wrong_system_information_class",
        "snapshot_missing_buffer_bytes", "snapshot_wrong_buffer_bytes",
        "snapshot_missing_query_attempts", "snapshot_wrong_query_attempts",
        "snapshot_missing_raw_identity_digest",
        "snapshot_malformed_raw_identity_digest",
    }
    review_hashes = {
        path.relative_to(R18_REVIEW_LEAF).as_posix(): receipt(path)
        for path in review_files_list
    }
    if (R18_PREDICATE_TESTER_LEAF / "predicate_probe_r4.exit.txt") \
            .read_text(encoding="ascii").strip() != "1" or \
            probe.get("schema") != "independent-t2-r18-audit-predicate-probe-r1" or \
            probe.get("protocol_sha256") != r18_protocol_pin["sha256"] or \
            probe.get("status") != "fail" or probe.get("passed_case_count") != 39 or \
            probe.get("test_count") != 49 or \
            set(probe.get("failures", [])) != expected_failures or \
            receipt(R18_REVIEW_LEAF / "review.json")["sha256"] != \
                "7840672478b7236efc5b8c96dcaf36930a0e947e4c18720e4966ce4ee36f5e83" or \
            receipt(R18_REVIEW_LEAF / "evidence_manifest.json")["sha256"] != \
                "93fdbbd1c359d32f54a7548fec8278e66a44326ec55aa9dce9f4cd1ba768dea6":
        raise RuntimeError("R18 predicate NO-GO evidence does not match sealed tester/review")
    tester_rehash = load_object(R18_PREDICATE_TESTER_LEAF / "input_rehash.json")
    tester_source = receipt(R18_PREDICATE_TESTER_SOURCE)
    if tester_rehash.get("tester_source_sha256") != tester_source["sha256"] or \
            tester_rehash.get("protocol_sha256") != r18_protocol_pin["sha256"]:
        raise RuntimeError("R18 independent tester source/protocol lineage drift")
    return {
        "schema": "vnext-t2-r18-predicate-probe-no-go-r1",
        "status": "preserved_no_go",
        "r18_protocol": r18_protocol_pin,
        "r18_static_qa": receipt(r18_qa_path),
        "r18_freeze_snapshot": receipt(r18_snapshot_path),
        "tester_leaf": R18_PREDICATE_TESTER_LEAF.relative_to(ROOT).as_posix(),
        "tester_files": {
            path.relative_to(R18_PREDICATE_TESTER_LEAF).as_posix(): receipt(path)
            for path in tester_files_list
        },
        "tester_source": tester_source,
        "tester_source_previous_pin_was_missing":
            tester_rehash.get("tester_source_is_pinned") is False,
        "review_leaf": R18_REVIEW_LEAF.relative_to(ROOT).as_posix(),
        "review_files": review_hashes,
        "passed_case_count": 39, "test_count": 49,
        "failure_count": len(expected_failures),
        "failed_fields": sorted(expected_failures),
        "formal_t2_accepted": False, "julia_started": False,
    }


def build_r21_tracked_exit_test_receipt(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    if not R21_TRACKED_EXIT_TEST.is_file() or not R21_TRACKED_EXIT_TEST_LEAF.is_dir():
        raise FileNotFoundError("R21 focused Python receipt or source is absent")
    add_input(inputs, R21_TRACKED_EXIT_TEST)
    paths = sorted(files_under(R21_TRACKED_EXIT_TEST_LEAF))
    expected_names = {"command_argv.json", "evidence.json", "exit_code.txt",
                      "stderr.raw", "stdout.raw"}
    if {path.name for path in paths} != expected_names or len(paths) != 5:
        raise RuntimeError("R21 focused test evidence inventory changed")
    rows = {}
    for path in paths:
        add_input(inputs, path)
        rows[path.name] = receipt(path)
    evidence = load_object(R21_TRACKED_EXIT_TEST_LEAF / "evidence.json")
    command = json.loads((R21_TRACKED_EXIT_TEST_LEAF / "command_argv.json").read_text(
        encoding="utf-8"))
    exit_text = (R21_TRACKED_EXIT_TEST_LEAF / "exit_code.txt").read_text(encoding="utf-8").strip()
    stdout = (R21_TRACKED_EXIT_TEST_LEAF / "stdout.raw").read_text(encoding="utf-8")
    r20_pin = receipt(R20_CONTROLLER)
    r21_pin = receipt(R21_CONTROLLER)
    if evidence.get("schema") != "independent-vnext-t2-r21-tracked-sample-exit-tests-r2" or \
            evidence.get("status") != "pass" or evidence.get("test_exit_code") != 0 or \
            evidence.get("positive_control_count") != 1 or \
            evidence.get("negative_control_count") != 24 or \
            evidence.get("julia_executed") is not False or \
            evidence.get("formal_t2_accepted") is not False or \
            evidence.get("controller_path") != R21_CONTROLLER.relative_to(ROOT).as_posix() or \
            evidence.get("source_pins_before", {}).get(r20_pin["path"]) != r20_pin["sha256"] or \
            evidence.get("source_pins_after", {}).get(r20_pin["path"]) != r20_pin["sha256"] or \
            evidence.get("source_pins_before", {}).get(r21_pin["path"]) != r21_pin["sha256"] or \
            evidence.get("source_pins_after", {}).get(r21_pin["path"]) != r21_pin["sha256"] or \
            evidence.get("source_pins_unchanged") is not True or exit_text != "0" or \
            "R21_TRACKED_SAMPLE_EXIT_TESTS=PASS" not in stdout or \
            not isinstance(command, list) or len(command) != 5 or \
            command[1] != "-B" or Path(command[2]).resolve() != R21_TRACKED_EXIT_TEST.resolve() or \
            command[3:] != ["--output", R21_TRACKED_EXIT_TEST_LEAF.relative_to(ROOT).as_posix()]:
        raise RuntimeError("R21 focused tracked-exit test receipt is not a bounded pass")
    positive = evidence.get("sample_controls", {}).get("positive", {})
    if positive.get("status") != "pass" or \
            positive.get("absence_snapshot_count") != 3 or \
            positive.get("exact_exit_receipt_count") != 2 or \
            positive.get("partial_rss_bytes_not_credited") != 7500 or \
            positive.get("retry_rss_bytes") != 2500 or \
            positive.get("final_cleanup_complete") is not True:
        raise RuntimeError("R21 focused positive receipt does not prove exact tracked exit recovery")
    return {
        "schema": "vnext-t2-r21-tracked-sample-exit-python-controls-r2",
        "status": "pass_python_only",
        "leaf": R21_TRACKED_EXIT_TEST_LEAF.relative_to(ROOT).as_posix(),
        "source": receipt(R21_TRACKED_EXIT_TEST),
        "files": rows, "file_count": len(rows),
        "evidence": rows["evidence.json"],
        "command": rows["command_argv.json"],
        "stdout": rows["stdout.raw"], "stderr": rows["stderr.raw"],
        "exit": rows["exit_code.txt"], "exit_code": 0,
        "positive_control_count": 1, "negative_control_count": 24,
        "formal_t2_accepted": False, "julia_started": False,
    }

def build_controller_r20_r21_tracked_exit_delta(
        inputs: dict[str, dict[str, Any]],
        test_receipt: dict[str, Any]) -> dict[str, Any]:
    add_input(inputs, R20_CONTROLLER)
    add_input(inputs, R21_CONTROLLER)
    old_text = read_source_text(R20_CONTROLLER)
    new_text = read_source_text(R21_CONTROLLER)
    old_tree, new_tree = ast.parse(old_text), ast.parse(new_text)
    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    old_functions, new_functions = functions(old_tree), functions(new_tree)
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected_changed = ["_r20_native_sample",
        "_r21_audit_tracked_sample_exit_races",
        "_r21_confirm_tracked_sample_exit", "_r23_audit_and_cleanup",
        "_r23_final_audit", "run_phase", "verify_protocol"]
    def assignments(tree: ast.Module) -> dict[str, str]:
        out = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                out[node.targets[0].id] = ast.dump(node, include_attributes=False)
        return out
    old_assignments, new_assignments = assignments(old_tree), assignments(new_tree)
    changed_assignments = sorted(name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    if changed != expected_changed or changed_assignments != ["R21_CONTROLLER_RELATIVE_PATH"]:
        raise RuntimeError("R20-to-R21 controller source delta is wider than tracked-exit recovery")
    unbound_names = ["_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race", "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows", "_r20_valid_snapshot_receipt"]
    if any(old_functions.get(name) != new_functions.get(name) for name in unbound_names):
        raise RuntimeError("R20 unbound fail-closed lane changed in R21")
    sample = next(node for node in new_tree.body if isinstance(node, ast.FunctionDef)
                  and node.name == "_r20_native_sample")
    audit = next(node for node in new_tree.body if isinstance(node, ast.FunctionDef)
                 and node.name == "_r23_final_audit")
    if not any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
               "_r21_confirm_tracked_sample_exit" for node in ast.walk(sample)) or \
            not any(isinstance(node, ast.Call) and ast.unparse(node.func) ==
               "_r21_audit_tracked_sample_exit_races" for node in ast.walk(audit)):
        raise RuntimeError("R21 typed tracked-exit helper/audit is not wired into sample and final audit")
    return {
        "schema": "vnext-t2-r20-r21-tracked-sample-exit-delta-r1",
        "r20_source": receipt(R20_CONTROLLER), "r21_source": receipt(R21_CONTROLLER),
        "changed_top_level_functions": changed,
        "changed_top_level_assignments": changed_assignments,
        "r20_unbound_lane_ast_identical": True,
        "tracked_exit_receipt_bound_to_phase_root_and_historical_set": True,
        "exact_three_complete_absence_snapshots_and_subtree_closure": True,
        "partial_sample_credit_bytes": 0, "exit_credit": False,
        "coverage_thresholds_changed": False, "resource_limits_changed": False,
        "focused_python_controls": test_receipt,
    }


def build_r22_pre_tree_python_test_receipt(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    if not R22_PRE_TREE_TEST.is_file() or not R22_PRE_TREE_TEST_LEAF.is_dir():
        raise FileNotFoundError("R22 focused Python receipt or source is absent")
    add_input(inputs, R22_PRE_TREE_TEST)
    paths = sorted(files_under(R22_PRE_TREE_TEST_LEAF))
    expected_names = {"command_argv.json", "evidence.json", "exit_code.txt",
                      "stderr.raw", "stdout.raw"}
    if {path.name for path in paths} != expected_names or len(paths) != 5:
        raise RuntimeError("R22 focused Python test evidence inventory changed")
    rows = {}
    for path in paths:
        add_input(inputs, path)
        rows[path.name] = receipt(path)
    evidence = load_object(R22_PRE_TREE_TEST_LEAF / "evidence.json")
    command = json.loads((R22_PRE_TREE_TEST_LEAF / "command_argv.json").read_text(
        encoding="utf-8"))
    exit_text = (R22_PRE_TREE_TEST_LEAF / "exit_code.txt").read_text(
        encoding="utf-8").strip()
    stdout = (R22_PRE_TREE_TEST_LEAF / "stdout.raw").read_text(encoding="utf-8")
    controller_pin = receipt(R22_CONTROLLER)
    validator_bindings = r22_projection_validator_source_bindings(inputs)
    validator_pin = validator_bindings["historical_executed_source"]
    before = evidence.get("source_pins_before", {})
    after = evidence.get("source_pins_after", {})
    positive = evidence.get("positive_control", {})
    negatives = evidence.get("negative_controls", [])
    expected_source_pins = {
        R20_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R20_CONTROLLER)["sha256"],
        R21_CONTROLLER.relative_to(ROOT).as_posix(): receipt(R21_CONTROLLER)["sha256"],
        R22_CONTROLLER.relative_to(ROOT).as_posix(): controller_pin["sha256"],
        R22_PRE_TREE_TEST.relative_to(ROOT).as_posix(): receipt(R22_PRE_TREE_TEST)["sha256"],
        PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(): validator_pin["sha256"],
        R23_TABLE.relative_to(ROOT).as_posix(): receipt(R23_TABLE)["sha256"],
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): receipt(R23_SUPERVISOR)["sha256"],
    }
    if evidence.get("schema") != "independent-vnext-t2-r22-pre-tree-tracked-exit-tests-r1" or \
            evidence.get("status") != "pass" or evidence.get("test_exit_code") != 0 or \
            evidence.get("positive_control_count") != 1 or \
            evidence.get("negative_control_count") != 9 or \
            evidence.get("python_executed") is not True or \
            evidence.get("julia_executed") is not False or \
            evidence.get("formal_t2_accepted") is not False or \
            evidence.get("controller_path") != R22_CONTROLLER.relative_to(ROOT).as_posix() or \
            evidence.get("projection_validator") != {
                "path": validator_pin["path"], "sha256": validator_pin["sha256"],
                "accepted_protocol_schema": "vnext-t2-independent-negative-protocol-r10",
                "validation_receipt_schema": "vnext-t2-projection24-cross-run-validation-r10"} or \
            before != after or any(before.get(path) != digest
                                   for path, digest in expected_source_pins.items()) or \
            evidence.get("source_pins_unchanged") is not True or \
            evidence.get("exact_launcher_argv") != command or \
            not isinstance(command, list) or len(command) != 7 or command[1] != "-B" or \
            Path(command[2]).resolve() != R22_PRE_TREE_TEST.resolve() or \
            command[3] != "--output" or \
            Path(command[4]).resolve() != R22_PRE_TREE_TEST_LEAF.resolve() or \
            command[5] != "--controller" or \
            Path(command[6]).resolve() != R22_CONTROLLER.resolve() or \
            exit_text != "0" or not isinstance(negatives, list) or len(negatives) != 9 or \
            any(row.get("status") != "pass" for row in negatives) or \
            positive.get("status") != "pass" or \
            positive.get("sample_attempt_count") != 2 or \
            positive.get("absence_snapshot_count") != 3 or \
            positive.get("failed_attempt_resource_reads") != 0 or \
            positive.get("final_audit_complete") is not True or \
            positive.get("target_opened_for_sampling") is not False or \
            positive.get("retired_generation_count") != 1 or \
            "R22_PRE_TREE_TRACKED_EXIT_TESTS=PASS" not in stdout or \
            (R22_PRE_TREE_TEST_LEAF / "stderr.raw").stat().st_size != 0:
        raise RuntimeError("R22 focused pre-tree test receipt is not a bounded pass")
    historical_alias_binding = None
    for source_path, digest in expected_source_pins.items():
        if source_path == validator_pin["path"]:
            if digest != validator_pin["sha256"] or \
                    validator_pin["bytes"] != \
                    validator_bindings["sealed_preimage_data_input"]["bytes"] or \
                    validator_pin["sha256"] != \
                    validator_bindings["sealed_preimage_data_input"]["sha256"]:
                raise RuntimeError(
                    "R22 historical validator alias is not bound to sealed preimage bytes")
            historical_alias_binding = validator_bindings
            continue
        add_input(inputs, ROOT / source_path)
        if inputs[source_path]["sha256"] != digest:
            raise RuntimeError(f"R22 focused suite input drift: {source_path}")
    if historical_alias_binding is None:
        raise RuntimeError("R22 focused source pins omitted the historical validator alias")
    return {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-python-controls-r1",
        "status": "pass_python_only",
        "leaf": R22_PRE_TREE_TEST_LEAF.relative_to(ROOT).as_posix(),
        "source": receipt(R22_PRE_TREE_TEST),
        "files": rows, "file_count": len(rows),
        "evidence": rows["evidence.json"],
        "command": rows["command_argv.json"],
        "stdout": rows["stdout.raw"], "stderr": rows["stderr.raw"],
        "exit": rows["exit_code.txt"], "exit_code": 0,
        "positive_control_count": 1, "negative_control_count": 9,
        "historical_alias_binding": historical_alias_binding,
        "formal_t2_accepted": False, "julia_started": False,
    }


def build_controller_r21_r22_pre_tree_delta(
        inputs: dict[str, dict[str, Any]],
        test_receipt: dict[str, Any]) -> dict[str, Any]:
    add_input(inputs, R21_CONTROLLER)
    add_input(inputs, R22_CONTROLLER)
    old_text = read_source_text(R21_CONTROLLER)
    new_text = read_source_text(R22_CONTROLLER)
    old_tree, new_tree = ast.parse(old_text), ast.parse(new_text)
    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}
    old_functions, new_functions = functions(old_tree), functions(new_tree)
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected_changed = ["_r20_native_sample",
        "_r22_audit_pre_tree_tracked_exit_races",
        "_r22_confirm_pre_tree_tracked_exit", "_r22_snapshot_bundle",
        "_r22_snapshot_from_bundle", "_r22_tracked_closure",
        "_r23_audit_and_cleanup", "_r23_final_audit", "run_phase",
        "verify_protocol"]
    def assignments(tree: ast.Module) -> dict[str, str]:
        out = {}
        for node in tree.body:
            if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                    isinstance(node.targets[0], ast.Name):
                out[node.targets[0].id] = ast.dump(node, include_attributes=False)
        return out
    old_assignments, new_assignments = assignments(old_tree), assignments(new_tree)
    changed_assignments = sorted(name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    expected_assignments = ["PROJECTION_REUSE_VALIDATOR",
                            "R21_CONTROLLER_RELATIVE_PATH",
                            "R22_CONTROLLER_RELATIVE_PATH"]
    if changed != expected_changed or changed_assignments != expected_assignments:
        raise RuntimeError("R21-to-R22 controller AST delta exceeds the tracked pre-tree lane")
    for names, label in (
            (["_r20_audit_unbound_observations", "_r20_confirm_unbound_sample_race",
              "_r20_unbound_cleanup_plan", "_r20_unbound_observed_rows",
              "_r20_valid_snapshot_receipt"], "R20 unbound fail-closed lane"),
            (["_r21_audit_tracked_sample_exit_races",
              "_r21_confirm_tracked_sample_exit"], "R21 tracked-exit lane")):
        if any(old_functions.get(name) != new_functions.get(name) for name in names):
            raise RuntimeError(f"R22 changed the preserved {label}")
    sample = next(node for node in new_tree.body
                  if isinstance(node, ast.FunctionDef) and node.name == "_r20_native_sample")
    audit = next(node for node in new_tree.body
                 if isinstance(node, ast.FunctionDef) and node.name == "_r23_final_audit")
    sample_calls = {ast.unparse(node.func) for node in ast.walk(sample)
                    if isinstance(node, ast.Call)}
    audit_calls = {ast.unparse(node.func) for node in ast.walk(audit)
                   if isinstance(node, ast.Call)}
    if "_r22_confirm_pre_tree_tracked_exit" not in sample_calls or \
            "_r22_audit_pre_tree_tracked_exit_races" not in audit_calls:
        raise RuntimeError("R22 pre-tree confirmer/final audit is not wired")
    if "vnext-t2-independent-negative-protocol-r10" not in new_text or \
            "validate_projection24_reuse_r12.py" not in new_text or \
            test_receipt.get("status") != "pass_python_only":
        raise RuntimeError("R22 protocol, R12 consumer, or focused controls are not bound")
    return {
        "schema": "vnext-t2-r21-r22-pre-tree-tracked-exit-delta-r1",
        "r21_source": receipt(R21_CONTROLLER), "r22_source": receipt(R22_CONTROLLER),
        "changed_top_level_functions": changed,
        "changed_top_level_assignments": changed_assignments,
        "r20_unbound_lane_ast_identical": True,
        "r21_tracked_exit_lane_ast_identical": True,
        "prior_and_outer_exact_source_closure_required": True,
        "failed_first_sample_target_absence_required": True,
        "same_cached_handle_natural_exit_and_three_absences_required": True,
        "partial_sample_credit_bytes": 0, "exit_credit": False,
        "full_whole_sample_retry_required": True,
        "final_typed_audit_required": True,
        "coverage_thresholds_changed": False, "resource_limits_changed": False,
        "focused_python_controls": test_receipt,
    }


def build_r22_windows_host_smoke_receipt(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    if not R22_HOST_SMOKE_RUNNER.is_file() or \
            not R22_HOST_SMOKE_FIXTURE.is_file() or \
            not R22_HOST_SMOKE_LEAF.is_dir() or \
            not R22_HOST_SMOKE_QA_SNAPSHOT.is_file():
        raise FileNotFoundError("R22 host smoke runner, fixture, or raw leaf is absent")
    add_input(inputs, R22_HOST_SMOKE_RUNNER)
    add_input(inputs, R22_HOST_SMOKE_FIXTURE)
    add_input(inputs, R22_STATIC_QA)
    add_input(inputs, R22_PRE_TREE_TEST)
    add_input(inputs, R22_HOST_SMOKE_QA_SNAPSHOT)
    paths = sorted(files_under(R22_HOST_SMOKE_LEAF))
    required = {"command_argv.json", "stdout.raw", "stderr.raw",
                "exit_code.json", "manifest.json", "phase/phase.json",
                "phase/samples.jsonl", "phase/stdout.raw", "phase/stderr.raw"}
    observed = {path.relative_to(R22_HOST_SMOKE_LEAF).as_posix()
                for path in paths}
    if not required.issubset(observed) or "phase/target_natural_exit.json" not in observed or \
            "phase/target_parent_wait.json" not in observed or \
            "phase/root_natural_exit.json" not in observed:
        raise RuntimeError("R22 Windows smoke raw inventory is incomplete")
    file_receipts = {}
    manifest_files = []
    for path in paths:
        add_input(inputs, path)
        relative = path.relative_to(R22_HOST_SMOKE_LEAF).as_posix()
        file_receipts[relative] = receipt(path)
        if relative != "manifest.json":
            data = path.read_bytes()
            manifest_files.append({
                "path": relative, "bytes": len(data),
                "sha256": sha256_bytes(data),
            })
    payload = load_object(R22_HOST_SMOKE_LEAF / "stdout.raw")
    command = load_object(R22_HOST_SMOKE_LEAF / "command_argv.json")
    exit_receipt = load_object(R22_HOST_SMOKE_LEAF / "exit_code.json")
    manifest = load_object(R22_HOST_SMOKE_LEAF / "manifest.json")
    phase_report = load_object(R22_HOST_SMOKE_LEAF / "phase/phase.json")

    def empty_global_heavy_audit(value: Any) -> bool:
        return isinstance(value, dict) and \
            value.get("schema") == "vnext-t2-r23-global-heavy-audit-r1" and \
            value.get("complete") is True and \
            all(value.get(field) == [] for field in
                ("processes", "controller_processes",
                 "native_heavy_identities", "errors")) and \
            value.get("snapshot", {}).get("complete") is True

    phase_final = phase_report.get("final_process_tree_audit", {})
    if not empty_global_heavy_audit(phase_report.get("residual_process_audit")) or \
            not empty_global_heavy_audit(
                phase_final.get("global_heavy_process_audit")):
        raise RuntimeError("R3 phase did not prove both empty global-heavy audits")
    phase_residual = phase_final.get("residual_process_audit", {})
    if phase_final.get("schema") != "vnext-t2-r23-final-process-tree-audit-r1" or \
            phase_final.get("complete") is not True or \
            phase_final.get("errors") != [] or \
            phase_final.get("root_exit_confirmed") is not True or \
            phase_final.get("root_identity_absent") is not True or \
            phase_final.get("residual_descendant_processes") != [] or \
            phase_final.get("tracked_pid_reuse") != [] or \
            phase_final.get("snapshot", {}).get("complete") is not True or \
            phase_residual.get("schema") != "native-g1g2-r23-residual-audit-v1" or \
            phase_residual.get("complete") is not True or \
            phase_residual.get("residual_clear") is not True or \
            phase_residual.get("residual_exact_identities") != [] or \
            phase_residual.get("expected_identity_count") != 4:
        raise RuntimeError("R3 phase final process-tree residual audits are incomplete")
    phase_r20 = phase_final.get("unbound_observation_final_audit", {})
    phase_r21 = phase_final.get("tracked_sample_exit_final_audit", {})
    phase_r22 = phase_final.get("pre_tree_tracked_exit_final_audit", {})
    if phase_r20.get("complete") is not True or phase_r20.get("errors") != [] or \
            phase_r20.get("observed_unbound_generations") != [] or \
            phase_r20.get("orphan_descendants") != [] or \
            phase_r20.get("residual_observed_generations") != [] or \
            phase_r21.get("complete") is not True or phase_r21.get("errors") != [] or \
            phase_r21.get("residual_retired_generations") != [] or \
            phase_r22.get("complete") is not True or phase_r22.get("errors") != [] or \
            phase_r22.get("residual_retired_generations") != []:
        raise RuntimeError("R3 R20/R21/R22 final generation audits are incomplete")
    controller_pin = receipt(R22_CONTROLLER)
    validator_bindings = r22_projection_validator_source_bindings(inputs)
    validator_pin = validator_bindings["historical_executed_source"]
    runner_pin = receipt(R22_HOST_SMOKE_RUNNER)
    fixture_pin = receipt(R22_HOST_SMOKE_FIXTURE)
    native_pin = receipt(R23_TABLE)
    supervisor_pin = receipt(R23_SUPERVISOR)
    # The host launcher ran against the exact pre-host QA snapshot. The live
    # QA is now versioned forward, so its current source pin stays independent.
    static_qa_snapshot_pin = receipt(R22_HOST_SMOKE_QA_SNAPSHOT)
    static_qa_pin = {
        "path": R22_STATIC_QA.relative_to(ROOT).as_posix(),
        "bytes": static_qa_snapshot_pin["bytes"],
        "sha256": static_qa_snapshot_pin["sha256"],
    }
    expected_pins = {
        "runner": runner_pin, "fixture": fixture_pin,
        "controller": controller_pin,
        "projection_validator": validator_pin,
        "native_process_table": native_pin,
        "supervisor": supervisor_pin,
        "static_qa": static_qa_pin,
        "focused_python_controls": receipt(R22_PRE_TREE_TEST),
    }
    historical_alias_binding = validator_bindings
    pins_before = payload.get("source_pins_before")
    pins_after = payload.get("source_pins_after")
    verified = payload.get("verified_race", {})
    phase_exit = verified.get("phase_exit", {})
    target = verified.get("target_identity", {})
    root = verified.get("root_identity", {})
    outer = verified.get("outer_reconcile_source", {})
    exact_exit = verified.get("exact_cached_generation_exit", {})
    absences = verified.get("three_post_wait_absence_receipts", [])
    zero_credit = verified.get("attempt_one_zero_credit", {})
    retry = verified.get("fresh_full_sample_attempt", {})
    close = verified.get("target_handle_close_receipt", {})
    final_audit = verified.get("final_process_tree_audit", {})
    if payload.get("schema") != "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2" or \
            exit_receipt.get("exit_code") != 0 or \
            exit_receipt.get("status") != "pass_python_only" or \
            manifest.get("schema") != "vnext-t2-r22-pre-tree-tracked-exit-host-manifest-r2" or \
            manifest.get("complete") is not True or \
            manifest.get("top_level_schema") != payload.get("schema") or \
            manifest.get("files") != manifest_files or \
            pins_before != pins_after or \
            payload.get("source_pins_stable") is not True or \
            exit_receipt.get("source_pins_before") != pins_before or \
            exit_receipt.get("source_pins_after") != pins_after or \
            manifest.get("source_pins_before") != pins_before or \
            manifest.get("source_pins_after") != pins_after or \
            pins_before != expected_pins or command.get("source_pins_before") != pins_before or \
            command.get("source_pins_after") != pins_after or \
            command.get("kind") != "python_only_r22_pre_tree_tracked_exit_host_smoke_r2" or \
            command.get("phase_timeout_seconds") != 30.0 or \
            command.get("working_set_limit_bytes") != 2_147_483_648 or \
            command.get("formal_t2_accepted") is not False or \
            command.get("julia_started") is not False or \
            payload.get("formal_t2_accepted") is not False or \
            payload.get("julia_started") is not False or \
            manifest.get("formal_t2_accepted") is not False or \
            manifest.get("julia_started") is not False or \
            not isinstance(command.get("argv"), list) or len(command["argv"]) != 9:
        raise RuntimeError("R22 Windows host smoke raw status, input pins, or argv is invalid")
    argv = command["argv"]
    if argv[1] != "-B" or Path(argv[2]).resolve() != R22_HOST_SMOKE_RUNNER.resolve() or \
            argv[3] != "--output" or Path(argv[4]).resolve() != R22_HOST_SMOKE_LEAF.resolve() or \
            argv[5] != "--controller-sha256" or argv[6] != controller_pin["sha256"] or \
            argv[7] != "--validator-sha256" or argv[8] != validator_pin["sha256"]:
        raise RuntimeError("R22 Windows smoke argv does not pin the reviewed R22/R12 sources")
    subtree = verified.get("expected_tracked_subtree", [])
    exits = verified.get("exact_cached_generation_exits", [])
    def identity_key(value: Any) -> tuple[int, int]:
        if not isinstance(value, dict):
            raise RuntimeError("R22 host smoke generation identity is malformed")
        pid = value.get("pid")
        ticks = value.get("create_time_100ns")
        if type(pid) is not int or pid <= 0 or type(ticks) is not int or ticks <= 0:
            raise RuntimeError("R22 host smoke generation identity is malformed")
        return pid, ticks
    try:
        subtree_keys = [identity_key(value) for value in subtree]
        target_key = identity_key(target)
        root_key = identity_key(root)
        exit_keys = [identity_key(value.get("identity")) for value in exits]
        retired_keys = [identity_key(value)
                        for value in verified.get("pre_tree_final_audit", {}).get(
                            "retired_tracked_identities", [])]
        closed_keys = [identity_key(value) for value in
                       close.get("closed_owned_handles", [])]
    except (TypeError, ValueError) as error:
        raise RuntimeError("R22 host smoke exact generation closure is malformed") from error
    if len(subtree_keys) != 2 or len(set(subtree_keys)) != 2 or \
            target_key not in subtree_keys or target_key == root_key or \
            set(exit_keys) != set(subtree_keys) or len(exit_keys) != 2 or \
            set(retired_keys) != set(subtree_keys) or len(retired_keys) != 2 or \
            not set(subtree_keys).issubset(closed_keys) or len(exits) != 2 or \
            any(item.get("complete") is not True or
                item.get("wait_confirmed") is not True or
                item.get("handle_identity_before_wait") != item.get("identity") or
                item.get("handle_identity_after_wait") != item.get("identity") or
                type(item.get("exit_code")) is not int or
                item.get("exit_code") == 259 or item.get("errors") != [] or
                item.get("exit_code_credit_issued") is not False
                for item in exits):
        raise RuntimeError("R22 host smoke did not prove both tracked subtree generations")
    binding = verified.get("sample4_source_binding", {})
    pre_tree_audit = verified.get("pre_tree_final_audit", {})
    absences = verified.get("three_post_wait_absence_receipts", [])
    if phase_exit.get("stop_reason") != "natural_exit" or \
            phase_exit.get("exit_code") != 0 or \
            type(phase_exit.get("seconds")) not in (int, float) or \
            isinstance(phase_exit.get("seconds"), bool) or \
            phase_exit.get("seconds", 10**9) > 30.0 or \
            phase_exit.get("timeout_seconds") != 30.0 or \
            phase_exit.get("working_set_limit_bytes") != 2_147_483_648 or \
            phase_exit.get("stderr_bytes") != 0 or \
            len(verified.get("three_complete_live_samples", [])) != 3 or \
            outer.get("unchanged_table_returned") is not True or \
            outer.get("target_row", {}).get("pid") != target.get("pid") or \
            outer.get("target_row", {}).get("create_time_100ns") != target.get("create_time_100ns") or \
            outer.get("target_row", {}).get("ppid") != root.get("pid") or \
            outer.get("target_row", {}).get("create_time_100ns", 0) <= \
                root.get("create_time_100ns", 0) or \
            outer.get("target_natural_exit_receipt", {}).get("pid") != target.get("pid") or \
            outer.get("target_natural_exit_receipt", {}).get("natural_exit") is not True or \
            outer.get("parent_wait_receipt", {}).get("target_pid") != target.get("pid") or \
            outer.get("parent_wait_receipt", {}).get("parent_reaped_target") is not True or \
            outer.get("parent_wait_receipt", {}).get("wait_exit_code") != 0 or \
            verified.get("failed_inner_source", {}).get("root_present_target_absent") is not True or \
            verified.get("failed_inner_source", {}).get("receipt", {}).get("complete") is not True or \
            identity_key(target) not in subtree_keys or \
            len(absences) != 3 or any(item.get("complete") is not True or
                item.get("schema") != "vnext-t2-r23-native-snapshot-receipt-r1" or
                item.get("query_attempts") != 1 for item in absences) or \
            exact_exit.get("complete") is not True or \
            exact_exit.get("identity") != target or \
            exact_exit.get("handle_identity_before_wait") != target or \
            exact_exit.get("handle_identity_after_wait") != target or \
            exact_exit.get("wait_confirmed") is not True or \
            exact_exit.get("exit_code") == 259 or exact_exit.get("errors") != [] or \
            binding.get("different_snapshot_objects") is not True or \
            binding.get("previous_accepted_sample_index") != 3 or \
            binding.get("target_identity") != target or \
            binding.get("previous_accepted_source_receipt") != outer.get("receipt") or \
            binding.get("outer_reconcile_source_receipt") != outer.get("receipt") or \
            len(verified.get("three_complete_live_samples", [])) != 3 or \
            [row.get("sample_index") for row in
             verified.get("three_complete_live_samples", [])] != [1, 2, 3] or \
            not all(row.get("snapshot", {}).get("complete") is True and
                    row.get("target_identity") == target
                    for row in verified.get("three_complete_live_samples", [])) or \
            pre_tree_audit.get("schema") != \
                "vnext-t2-r22-pre-tree-tracked-exit-final-audit-r1" or \
            pre_tree_audit.get("complete") is not True or \
            pre_tree_audit.get("errors") != [] or \
            pre_tree_audit.get("residual_retired_generations") != [] or \
            pre_tree_audit.get("record_count") != 1 or \
            len(absences) != 3 or any(item.get("complete") is not True for item in absences) or \
            zero_credit.get("rss_credit_bytes") != 0 or \
            zero_credit.get("cpu_credit_seconds") != {"user": 0.0, "system": 0.0} or \
            zero_credit.get("exit_code_credit_issued") is not False or \
            retry.get("started") is not True or retry.get("attempt_index") != 2 or \
            retry.get("completed") is not True or retry.get("retry_source_absent_target") is not True:
        raise RuntimeError("R22 Windows smoke did not prove exact exit, three absences, and full retry")
    resource_reads = verified.get("resource_reads", [])
    reads_by_sample = {
        sample_index: [row for row in resource_reads
                       if row.get("sample_index") == sample_index]
        for sample_index in (1, 2, 3, 4)
    }
    subtree_pids = {pid for pid, _ticks in subtree_keys}
    baseline_pid_sets = [
        {row.get("pid") for row in reads_by_sample[index]}
        for index in (1, 2, 3)
    ]
    registry_calls = verified.get("target_registry_open_calls", [])
    if len(resource_reads) != 14 or any(
            len(reads_by_sample[index]) != 4 or
            len({row.get("pid") for row in reads_by_sample[index]}) != 4 or
            any(row.get("after_race_boundary") is not False
                for row in reads_by_sample[index])
            for index in (1, 2, 3)) or \
            not baseline_pid_sets[0] == baseline_pid_sets[1] == baseline_pid_sets[2] or \
            not subtree_pids.issubset(baseline_pid_sets[0]) or \
            root_key[0] not in baseline_pid_sets[0] or \
            len(reads_by_sample[4]) != 2 or \
            {row.get("pid") for row in reads_by_sample[4]} != \
                baseline_pid_sets[0] - subtree_pids or \
            any(row.get("after_race_boundary") is not True
                for row in reads_by_sample[4]) or \
            any(row.get("pid") in subtree_pids and
                row.get("after_race_boundary") is True for row in resource_reads) or \
            len(registry_calls) != 3 or \
            [row.get("sample_index") for row in registry_calls] != [1, 2, 3] or \
            any(row.get("identity") != target or
                row.get("after_race_boundary") is not False for row in registry_calls) or \
            [row.get("opened_by_registry") for row in registry_calls] != \
                [True, False, False] or \
            [row.get("already_cached") for row in registry_calls] != \
                [False, True, True]:
        raise RuntimeError("R3 resource reads or target registry calls crossed race boundary")
    if close.get("complete") is not True or close.get("errors") != [] or \
            not any(item.get("pid") == target.get("pid") and
                    item.get("create_time_100ns") == target.get("create_time_100ns")
                    for item in close.get("closed_owned_handles", [])) or \
            final_audit.get("complete") is not True or \
            final_audit.get("residual_descendant_processes") != []:
        raise RuntimeError("R22 Windows smoke handle cleanup/final audit is incomplete")
    return {
        "schema": "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2",
        "status": "pass_windows_host_smoke_only",
        "runner": runner_pin, "fixture": fixture_pin,
        "controller": controller_pin, "projection_validator": validator_pin,
        "leaf": R22_HOST_SMOKE_LEAF.relative_to(ROOT).as_posix(),
        "historical_alias_binding": historical_alias_binding,
        "files": file_receipts, "file_count": len(file_receipts),
        "manifest": file_receipts["manifest.json"],
        "stdout_payload": file_receipts["stdout.raw"],
        "command": file_receipts["command_argv.json"],
        "exit": file_receipts["exit_code.json"],
        "exit_code": 0, "phase_timeout_seconds": 30.0,
        "working_set_limit_bytes": 2_147_483_648,
        "tracked_subtree_generation_count": 2,
        "pre_tree_recovery_and_final_cleanup_complete": True,
        "independent_review": {
            "status": "GO",
            "scope": "R3 Windows host smoke as a freezer input only",
            "basis": "root-confirmed independent raw R3 review",
            "formal_t2_execution_authorized": False,
            "review_artifact_pinned_in_repository": False,
        },
        "formal_t2_accepted": False, "julia_started": False,
    }


def build_r22_host_smoke_launcher_receipt(
        inputs: dict[str, dict[str, Any]],
        internal: dict[str, Any]) -> dict[str, Any]:
    if not R22_HOST_SMOKE_LAUNCHER_LEAF.is_dir():
        raise FileNotFoundError("R22 external launcher raw receipt leaf is absent")
    outer_paths = sorted(files_under(R22_HOST_SMOKE_LAUNCHER_LEAF))
    outer_files = {path.relative_to(R22_HOST_SMOKE_LAUNCHER_LEAF).as_posix(): path
                   for path in outer_paths}
    required_names = {"command_argv.json", "outer_command_argv.json",
                      "stdout.raw", "stderr.raw", "external_exit_receipt.json",
                      "launch_host.ps1", "processes_before.json",
                      "processes_after.json", "root_manifest.json"}
    if not required_names.issubset(outer_files):
        raise RuntimeError("R22 external launcher receipt inventory is incomplete")
    rows = {}
    for relative, path in sorted(outer_files.items()):
        add_input(inputs, path)
        rows[relative] = receipt(path)
    command = json.loads(outer_files["command_argv.json"].read_text(encoding="utf-8"))
    outer_command = json.loads(
        outer_files["outer_command_argv.json"].read_text(encoding="utf-8"))
    exit_receipt = load_object(outer_files["external_exit_receipt.json"])
    root_manifest = load_object(outer_files["root_manifest.json"])
    inner_command = load_object(R22_HOST_SMOKE_LEAF / "command_argv.json")
    inner_stdout = (R22_HOST_SMOKE_LEAF / "stdout.raw").read_bytes()
    outer_stdout = outer_files["stdout.raw"].read_bytes()
    outer_stderr = outer_files["stderr.raw"].read_bytes()
    expected_outer_argv = inner_command.get("argv")
    static_qa_snapshot_pin = receipt(R22_HOST_SMOKE_QA_SNAPSHOT)
    static_qa_host_pin = {
        "path": R22_STATIC_QA.relative_to(ROOT).as_posix(),
        "bytes": static_qa_snapshot_pin["bytes"],
        "sha256": static_qa_snapshot_pin["sha256"],
    }
    validator_bindings = r22_projection_validator_source_bindings(inputs)
    validator_pin = validator_bindings["historical_executed_source"]
    expected_pins = {
        "runner": receipt(R22_HOST_SMOKE_RUNNER),
        "fixture": receipt(R22_HOST_SMOKE_FIXTURE),
        "controller": receipt(R22_CONTROLLER),
        "projection_validator": validator_pin,
        "native_process_table": receipt(R23_TABLE),
        "supervisor": receipt(R23_SUPERVISOR),
        "static_qa": static_qa_host_pin,
        "focused_python_controls": receipt(R22_PRE_TREE_TEST),
    }
    external_expected_pins = {
        row["path"]: row for row in expected_pins.values()}
    if len(expected_pins) != 8 or len(external_expected_pins) != 8 or \
            any(set(row) != {"path", "bytes", "sha256"} or
                row.get("path") != path
                for path, row in external_expected_pins.items()):
        raise RuntimeError("R3 external source-pin rows are not eight unique exact receipts")
    pins_before = exit_receipt.get("source_pins_before")
    pins_after = exit_receipt.get("source_pins_after")
    inner_exit_pin = receipt(R22_HOST_SMOKE_LEAF / "exit_code.json")
    inner_manifest_pin = receipt(R22_HOST_SMOKE_LEAF / "manifest.json")
    manifest_rows = root_manifest.get("files")
    expected_manifest_rows = []
    for relative, path in sorted(outer_files.items()):
        if relative == "root_manifest.json":
            continue
        data = path.read_bytes()
        expected_manifest_rows.append({
            "path": relative, "bytes": len(data),
            "sha256": sha256_bytes(data),
        })
    if not isinstance(manifest_rows, list) or any(
            not isinstance(row, dict) or
            not isinstance(row.get("path"), str) for row in manifest_rows):
        raise RuntimeError("R22 external launcher manifest file rows are malformed")
    actual_manifest_names = [row["path"] for row in manifest_rows]
    expected_manifest_names = [row["path"] for row in expected_manifest_rows]
    before_processes = json.loads(
        outer_files["processes_before.json"].read_text(encoding="utf-8"))
    after_processes = json.loads(
        outer_files["processes_after.json"].read_text(encoding="utf-8"))
    outer_manifest_pin = receipt(outer_files["root_manifest.json"])
    inner_payload = json.loads(inner_stdout.decode("utf-8"))
    if exit_receipt.get("schema") != \
            "vnext-t2-r22-host-smoke-launcher-exit-r1" or \
            exit_receipt.get("exit_code") != 0 or \
            exit_receipt.get("status") != "pass_python_only" or \
            exit_receipt.get("source_pins_unchanged") is not True or \
            exit_receipt.get("formal_t2_accepted") is not False or \
            exit_receipt.get("julia_started") is not False or \
            pins_before != external_expected_pins or \
            pins_after != external_expected_pins or \
            type(exit_receipt.get("wall_seconds")) not in (int, float) or \
            isinstance(exit_receipt.get("wall_seconds"), bool) or \
            not 0 <= exit_receipt.get("wall_seconds") < 45 or \
            exit_receipt.get("stdout") != rows["stdout.raw"] or \
            exit_receipt.get("stderr") != rows["stderr.raw"] or \
            exit_receipt.get("inner_exit_code") != inner_exit_pin or \
            exit_receipt.get("inner_manifest") != inner_manifest_pin or \
            command != expected_outer_argv or not isinstance(command, list) or \
            not isinstance(outer_command, list) or len(outer_command) != 6 or \
            Path(outer_command[0]).name.lower() != "pwsh.exe" or \
            outer_command[1:5] != ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"] or \
            Path(outer_command[5]).resolve() != \
                (R22_HOST_SMOKE_LAUNCHER_LEAF / "launch_host.ps1").resolve() or \
            Path(outer_command[5]).resolve() != outer_files["launch_host.ps1"].resolve() or \
            outer_stdout != inner_stdout or outer_stderr != b"":
        raise RuntimeError("R22 external launcher OS result or raw stream closure is invalid")
    if inner_payload.get("schema") != \
            "vnext-t2-r22-pre-tree-tracked-exit-host-smoke-r2" or \
            json.loads(outer_stdout.decode("utf-8")) != inner_payload or \
            exit_receipt.get("outer_stdout_equals_inner_payload") is not True or \
            exit_receipt.get("inner_self_report_exit_code") != 0 or \
            exit_receipt.get("outer_timeout") is not False or \
            exit_receipt.get("outer_timeout_seconds") != 45 or \
            exit_receipt.get("processes_after_count") != 0 or \
            exit_receipt.get("launcher_mode") != "powershell_dotnet_direct_cli" or \
            before_processes != [] or after_processes != []:
        raise RuntimeError("R22 external launcher process and inner-output evidence is invalid")
    inner_exit = load_object(R22_HOST_SMOKE_LEAF / "exit_code.json")
    if inner_exit.get("exit_code") != 0 or \
            inner_exit.get("status") != "pass_python_only" or \
            inner_exit.get("source_pins_before") != expected_pins or \
            inner_exit.get("source_pins_after") != expected_pins:
        raise RuntimeError("R22 inner host runner exit/status differs from external receipt")
    if root_manifest.get("schema") != \
            "vnext-t2-r22-host-smoke-launcher-manifest-r1" or \
            actual_manifest_names != expected_manifest_names or \
            manifest_rows != expected_manifest_rows or \
            set(outer_files) != set(actual_manifest_names) | {"root_manifest.json"} or \
            root_manifest.get("inner_manifest_ref") != inner_manifest_pin or \
            root_manifest.get("formal_t2_accepted") is not False or \
            root_manifest.get("julia_started") is not False:
        raise RuntimeError("R22 external manifest does not close every launcher member and inner leaf")
    return {
        "schema": "vnext-t2-r22-host-smoke-launcher-exit-r1",
        "status": "pass_external_windows_python_only",
        "leaf": R22_HOST_SMOKE_LAUNCHER_LEAF.relative_to(ROOT).as_posix(),
        "files": rows, "file_count": len(rows),
        "manifest_schema": root_manifest["schema"],
        "manifest": outer_manifest_pin,
        "command": rows["command_argv.json"],
        "stdout": rows["stdout.raw"], "stderr": rows["stderr.raw"],
        "external_exit_receipt": rows["external_exit_receipt.json"],
        "root_manifest": rows["root_manifest.json"],
        "exit_code": 0, "inner_exit_code": inner_exit_pin,
        "inner_manifest": inner_manifest_pin,
        "source_pins": expected_pins,
        "historical_alias_binding": validator_bindings,
        "wall_seconds": exit_receipt["wall_seconds"],
        "formal_t2_accepted": False, "julia_started": False,
    }


def build_r22_host_smoke_invocation_receipt(
        inputs: dict[str, dict[str, Any]],
        launcher: dict[str, Any]) -> dict[str, Any]:
    if not R22_HOST_SMOKE_INVOCATION_LEAF.is_dir():
        raise FileNotFoundError("R3 outer PowerShell invocation leaf is absent")
    paths = sorted(files_under(R22_HOST_SMOKE_INVOCATION_LEAF))
    files = {path.relative_to(R22_HOST_SMOKE_INVOCATION_LEAF).as_posix(): path
             for path in paths}
    expected_names = {"command_argv.json", "os_exit_receipt.json",
                      "powershell.stdout.raw", "powershell.stderr.raw"}
    if set(files) != expected_names:
        raise RuntimeError("R3 PowerShell invocation raw inventory changed")
    rows = {}
    for relative, path in sorted(files.items()):
        add_input(inputs, path)
        rows[relative] = receipt(path)
    command = json.loads(files["command_argv.json"].read_text(encoding="utf-8"))
    receipt_data = load_object(files["os_exit_receipt.json"])
    stdout = files["powershell.stdout.raw"].read_bytes()
    stderr = files["powershell.stderr.raw"].read_bytes()
    summary = json.loads(stdout.decode("utf-8"))
    outer_command = json.loads(
        (R22_HOST_SMOKE_LAUNCHER_LEAF / "outer_command_argv.json")
        .read_text(encoding="utf-8"))
    launcher_path = R22_HOST_SMOKE_LAUNCHER_LEAF / "launch_host.ps1"
    launcher_pin = receipt(launcher_path)
    validator_bindings = r22_projection_validator_source_bindings(inputs)
    external_pin = launcher.get("external_exit_receipt")
    ok = (
        receipt_data.get("schema") == "root-powershell-host-smoke-invocation-r3" and
        receipt_data.get("actual_powershell_os_exit") == 0 and
        receipt_data.get("invocation_timeout") is False and
        receipt_data.get("launcher_source_unchanged") is True and
        launcher_pin["sha256"] == R22_HOST_SMOKE_LAUNCHER_SHA256 and
        receipt_data.get("launcher_sha_before") ==
            R22_HOST_SMOKE_LAUNCHER_SHA256 and
        receipt_data.get("launcher_sha_after") ==
            R22_HOST_SMOKE_LAUNCHER_SHA256 and
        receipt_data.get("launcher_sha_expected") ==
            R22_HOST_SMOKE_LAUNCHER_SHA256 and
        receipt_data.get("command_argv") == command == outer_command and
        isinstance(command, list) and len(command) == 6 and
        Path(command[0]).name.lower() == "pwsh.exe" and
        command[1:5] == ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"] and
        Path(command[5]).resolve() == launcher_path.resolve() and
        rows["powershell.stdout.raw"]["sha256"] == receipt_data.get("stdout_sha256") and
        rows["powershell.stderr.raw"]["sha256"] == receipt_data.get("stderr_sha256") and
        stderr == b"" and isinstance(external_pin, dict) and
        summary.get("actual_os_exit") == 0 and
        summary.get("status") == "pass_python_only" and
        summary.get("source_pins_stable") is True and
        summary.get("stdout_identical") is True and
        summary.get("processes_after") == 0 and
        summary.get("external_receipt_sha256") == external_pin.get("sha256") and
        receipt_data.get("formal_t2_accepted") is False and
        receipt_data.get("julia_started") is False and
        launcher.get("formal_t2_accepted") is False and
        launcher.get("julia_started") is False and
        launcher.get("historical_alias_binding") == validator_bindings and
        type(receipt_data.get("wall_seconds")) in (int, float) and
        not isinstance(receipt_data.get("wall_seconds"), bool) and
        0 <= receipt_data.get("wall_seconds") < 45
    )
    if not ok:
        raise RuntimeError("R3 PowerShell OS-exit/source/stdout receipt is invalid")
    return {
        "schema": "vnext-t2-r22-host-smoke-invocation-r3",
        "raw_schema": receipt_data["schema"],
        "status": "pass_outer_powershell_invocation_only",
        "leaf": R22_HOST_SMOKE_INVOCATION_LEAF.relative_to(ROOT).as_posix(),
        "files": rows, "file_count": len(rows),
        "command": rows["command_argv.json"],
        "os_exit_receipt": rows["os_exit_receipt.json"],
        "stdout": rows["powershell.stdout.raw"],
        "stderr": rows["powershell.stderr.raw"],
        "actual_powershell_os_exit": 0,
        "invocation_timeout": False,
        "launcher_sha256": launcher_pin["sha256"],
        "external_receipt_sha256": external_pin["sha256"],
        "historical_alias_binding": validator_bindings,
        "formal_t2_accepted": False, "julia_started": False,
    }


def build_prior_r22_actual_failure(inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    paths = {
        "protocol": R22_PRIOR_FORMAL_FAILURE_PROTOCOL,
        "command_argv": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "command_argv.json",
        "outer_receipt": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "external_exit_receipt.json",
        "launcher": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "launch_formal_r22.ps1",
        "stderr": R22_PRIOR_FORMAL_FAILURE_LAUNCHER_LEAF / "stderr.raw",
        "pipeline_final": R22_PRIOR_FORMAL_FAILURE_LEAF / "pipeline_final.json",
        "source_snapshot_manifest": R22_PRIOR_FORMAL_FAILURE_SNAPSHOT / "manifest.json",
    }
    expected = {
        "protocol": (1_412_507,
            "93a2432cd4baea43192eda6b3ed54641ef3b7dbb5b3e1fb95087057efb33b1b7"),
        "command_argv": (1_259,
            "fc197657756e47d2473ec684d5e2bd1f31fb77871b5910d6df00307173a22c19"),
        "outer_receipt": (3_318,
            "0c4f11dce6c0ae6d399395908efa7e12158c6a7877aa06df3403b07b4792047a"),
        "launcher": (9_137,
            "cfb4464075c7775672a7cfe0d8ef67837ed52e253a1cfe8f491f804391651b7d"),
        "stderr": (1_157,
            "2b34daa06ea41aa2654a064838f0825a7e5539c78803de32507daffc70c007b0"),
        "pipeline_final": (899_583,
            "a4840b01da19ad9d2ac7c80426fc56d49a901a373314452af5a8606d275ce1f1"),
        "source_snapshot_manifest": (2_858,
            "f13955a3084fe9e73db78c6d829bd923f03e5cfa71de8bbb459a0ede6d34d48f"),
    }
    rows = {}
    for role, path in paths.items():
        add_input(inputs, path)
        rows[role] = receipt(path)
        if (rows[role]["bytes"], rows[role]["sha256"]) != expected[role]:
            raise RuntimeError(f"R22 actual-failure {role} pin changed")

    old_protocol = load_object(paths["protocol"])
    command_argv = json.loads(paths["command_argv"].read_text(encoding="utf-8"))
    outer = load_object(paths["outer_receipt"])
    pipeline = load_object(paths["pipeline_final"])
    manifest = load_object(paths["source_snapshot_manifest"])
    phases = pipeline.get("phases", [])
    phase = phases[0] if isinstance(phases, list) and len(phases) == 1 else {}
    if old_protocol.get("schema") != "vnext-t2-independent-negative-protocol-r10" or \
            old_protocol.get("formal_t2_accepted") is not False or \
            old_protocol.get("controller_path") != R22_CONTROLLER.relative_to(ROOT).as_posix() or \
            outer.get("schema") != "root-t2-r22-actual-formal-external-exit-r1" or \
            outer.get("argv") != command_argv or \
            outer.get("actual_child_os_exit_code") != 1 or \
            outer.get("outer_timeout") is not False or \
            outer.get("wall_seconds") != 1.8564528 or \
            outer.get("source_pin_count") != 1_092 or \
            outer.get("source_pins_unchanged") is not True or \
            outer.get("physical_acceptance_credit") is not False or \
            pipeline.get("status") != "fail" or \
            pipeline.get("formal_t2_accepted") is not False or \
            pipeline.get("scientific_acceptance") is not False or \
            pipeline.get("physical_acceptance") is not False or \
            phase.get("name") != "parse_gate" or phase.get("exit_code") != 15 or \
            phase.get("stop_reason") != "process_tree_monitor_incomplete" or \
            phase.get("process_tree_sample_count") != 1 or \
            phase.get("process_tree_samples_complete") is not False or \
            pipeline.get("executed_unique_case_count") != 0 or \
            pipeline.get("executed_runtime_case_hit_count") != 0 or \
            pipeline.get("versioned_product_repair_assertion_sites_completed") != 0:
        raise RuntimeError("R22 actual-failure facts no longer match its raw evidence")

    expected_source_files = {
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r22.py":
            (394_560, "9c6e760369e9c19bcd6e859988b6590a79956540e6dfcf0550d3d00c59785e16"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r22.py":
            (204_884, "f0e96e4a38e0f818ca29629c7e71c962ed613b9346aa2e42e74ba13102092841"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/freeze_independent_negative_protocol_r22.py":
            (273_756, "115745a1d16a8785d89f4d6ee2907cda89448d28044be0baa3c6b5685563264b"),
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/validate_projection24_reuse_r12.py":
            (13_712, "04f3cf18221b69942815a8fd4d724e956ae3a230077200a24c49d57474344d41"),
    }
    if manifest.get("schema") != "vnext-t2-r22-failure-source-snapshot-r1" or \
            manifest.get("evidence_leaf") != R22_PRIOR_FORMAL_FAILURE_LEAF.relative_to(ROOT).as_posix() or \
            manifest.get("preexisting_evidence_unchanged_after_snapshot") is not True or \
            not isinstance(manifest.get("source_files"), list) or \
            len(manifest["source_files"]) != len(expected_source_files):
        raise RuntimeError("R22 execution source-snapshot manifest changed")
    snapshots = {}
    for row in manifest["source_files"]:
        repo_path = row.get("repo_path")
        expected_source = expected_source_files.get(repo_path)
        if expected_source is None or row.get("execution_pin_equal") is not True or \
                (row.get("bytes"), row.get("sha256")) != expected_source:
            raise RuntimeError(f"R22 executed source snapshot changed: {repo_path}")
        path = R22_PRIOR_FORMAL_FAILURE_SNAPSHOT / row["snapshot_path"]
        add_input(inputs, path)
        pin = receipt(path)
        if (pin["bytes"], pin["sha256"]) != expected_source:
            raise RuntimeError(f"R22 archived executed source bytes changed: {repo_path}")
        snapshots[repo_path] = pin
    if set(snapshots) != set(expected_source_files):
        raise RuntimeError("R22 source snapshot omitted or duplicated an execution input")
    return {
        "schema": "vnext-t2-r23-prior-r22-actual-failure-r1",
        "classification": "no_credit_actual_failure",
        "files": rows,
        "source_snapshots": snapshots,
        "facts": {
            "outer_os_exit_code": 1,
            "outer_timeout": False,
            "wall_seconds": 1.8564528,
            "source_pin_count": 1_092,
            "formal_phase_pass_count": 0,
            "formal_case_pass_count": 0,
            "parse_child_exit_code": 15,
            "partial_resource_credit": False,
            "formal_t2_accepted": False,
            "physical_acceptance_credit": False,
        },
        "phase": "parse_gate",
        "phase_stop_reason": "process_tree_monitor_incomplete",
        "formal_t2_accepted": False,
        "physical_acceptance_credit": False,
    }


def build_controller_r22_r23_membership_growth_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, R22_CONTROLLER)
    add_input(inputs, R23_CONTROLLER_PREIMAGE)
    add_input(inputs, CONTROLLER)
    old_tree = ast.parse(read_source_text(R22_CONTROLLER))
    new_tree = ast.parse(read_source_text(R23_CONTROLLER_PREIMAGE))

    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}

    old_functions, new_functions = functions(old_tree), functions(new_tree)
    changed = sorted(name for name in old_functions.keys() | new_functions.keys()
                     if old_functions.get(name) != new_functions.get(name))
    expected_changed = [
        "_r20_native_sample", "_r23_append_snapshot_history",
        "_r23_audit_and_cleanup", "_r23_audit_descendant_terminal_root_sample_exits",
        "_r23_audit_membership_growth",
        "_r23_audit_terminal_root_sample_exits",
        "_r23_bind_membership_growth_retry", "_r23_confirm_membership_growth",
        "_r23_confirm_descendant_terminal_root_sample_exit",
        "_r23_confirm_terminal_root_sample_exit",
        "_r23_final_audit", "_r23_membership_growth_retry_binding",
        "_r23_monitor_digest_matches", "_r23_observed_root_reachable_rows",
        "_r23_reconcile_missing_tracked", "_r23_root_closure_rows",
        "_r23_row_evidence", "_r23_snapshot_bundle", "_r23_snapshot_from_bundle",
        "_r23_snapshot_history_hash", "_r23_snapshot_history_pid_hash",
        "_r23_snapshot_history_prefix_receipt", "_r23_snapshot_history_reference",
        "_r23_snapshot_witness_bytes", "_r23_snapshot_witness_ledger_receipt",
        "_r23_terminal_root_closure_rows",
        "_r23_validate_snapshot_history", "_r23_verify_snapshot_history_reference",
        "_r23_wait_gone", "run_phase", "verify_protocol",
    ]

    def assignments(tree: ast.Module) -> dict[str, str]:
        return {node.targets[0].id: ast.dump(node, include_attributes=False)
                for node in tree.body if isinstance(node, ast.Assign) and
                len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)}

    old_assignments, new_assignments = assignments(old_tree), assignments(new_tree)
    changed_assignments = sorted(
        name for name in old_assignments.keys() | new_assignments.keys()
        if old_assignments.get(name) != new_assignments.get(name))
    expected_assignments = ["R22_CONTROLLER_RELATIVE_PATH",
                            "R23_CONTROLLER_RELATIVE_PATH"]
    if changed != sorted(expected_changed) or changed_assignments != expected_assignments:
        raise RuntimeError("R22-to-R23 controller AST delta exceeded the growth and terminal-root lanes")

    r20_functions = functions(ast.parse(read_source_text(R20_CONTROLLER)))
    r21_functions = functions(ast.parse(read_source_text(R21_CONTROLLER)))
    preserved_r20 = ["_r20_audit_unbound_observations",
        "_r20_confirm_unbound_sample_race", "_r20_unbound_cleanup_plan",
        "_r20_unbound_observed_rows", "_r20_valid_snapshot_receipt"]
    preserved_r21 = ["_r21_audit_tracked_sample_exit_races",
                     "_r21_confirm_tracked_sample_exit"]
    preserved_r22 = ["_r22_audit_pre_tree_tracked_exit_races",
        "_r22_confirm_pre_tree_tracked_exit", "_r22_snapshot_bundle",
        "_r22_snapshot_from_bundle", "_r22_tracked_closure"]
    if any(r20_functions.get(name) != new_functions.get(name)
           for name in preserved_r20) or \
            any(r21_functions.get(name) != new_functions.get(name)
                for name in preserved_r21) or \
            any(old_functions.get(name) != new_functions.get(name)
                for name in preserved_r22):
        raise RuntimeError("R23 changed a preserved R20/R21/R22 fail-closed lane")
    source = read_source_text(R22_CONTROLLER) + \
        read_source_text(R23_CONTROLLER_PREIMAGE)
    if "vnext-t2-independent-negative-protocol-r10" not in source or \
            "validate_projection24_reuse_r12.py" not in source:
        raise RuntimeError("R23 changed the R10/R12 formal consumer contract")
    terminal_failure_files = {
        "outer_receipt": (ROOT / "runs/UP1-04A-VNEXT-T2/formal_launcher_r23_direct_git_r9_20260926_r1/external_exit_receipt.json",
                          "afecb80c97477489f8e107065db1ad6f551283b5c5a0e4266938598ee4122540"),
        "pipeline_final": (ROOT / "runs/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r23_direct_git_r9/pipeline_final.json",
                           "9d34287ab8b9a6296e7106b98d1adec4c568dceacf92d313abd9349c20a4f04d"),
        "preservation_manifest": (ROOT / "runs/e/t2r23p9/manifest.json",
                                  "4355b2324b6b60bd6f8d2479f9338641129704367b9770998e4fd7942d66e56c"),
    }
    terminal_failure_pins = {}
    for name, (path, expected_sha256) in terminal_failure_files.items():
        pin = receipt(path)
        if pin["sha256"] != expected_sha256:
            raise RuntimeError(f"R9 terminal-root triggering evidence drift: {name}")
        add_input(inputs, path)
        terminal_failure_pins[name] = pin
    terminal_outer = load_object(terminal_failure_files["outer_receipt"][0])
    terminal_pipeline = load_object(terminal_failure_files["pipeline_final"][0])
    terminal_phases = terminal_pipeline.get("phases", [])
    if terminal_outer.get("actual_child_os_exit_code") != 1 or \
            terminal_outer.get("outer_timeout") is not False or \
            terminal_pipeline.get("formal_t2_accepted") is not False or \
            len(terminal_phases) != 2 or \
            terminal_phases[0].get("name") != "parse_gate" or \
            terminal_phases[0].get("exit_code") != 0 or \
            terminal_phases[0].get("stop_reason") != "natural_exit" or \
            terminal_phases[1].get("name") != "coverage_ast_inventory" or \
            terminal_phases[1].get("stop_reason") != "process_tree_monitor_incomplete" or \
            terminal_phases[1].get("process_tree_sample_count") != 18 or \
            terminal_phases[1].get("process_tree_samples_complete") is not False:
        raise RuntimeError("R9 terminal-root triggering failure semantics changed")
    descendant_failure_files = {
        "outer_receipt": (ROOT / "runs/UP1-04A-VNEXT-T2/formal_launcher_r23_terminal_root_r12_20260926_r1/external_exit_receipt.json",
                          "3836a50fbd52a5bcc3d61eaf98c56afa5671b7e088c8ab1f0d695be6af370056"),
        "pipeline_final": (ROOT / "runs/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r23_terminal_root_r12/pipeline_final.json",
                           "154dff62ed6bd0c071cb08073a59de54286d4fcb4f18a24fb5dc435626c81963"),
        "preservation_manifest": (ROOT / "runs/e/t2r23p12/manifest.json",
                                  "a48a3af9bc5a664de7366b0f5d4aeee05c7e57b6c8df3894075e2f7f838cb106"),
    }
    descendant_failure_pins = {}
    for name, (path, expected_sha256) in descendant_failure_files.items():
        pin = receipt(path)
        if pin["sha256"] != expected_sha256:
            raise RuntimeError(f"R12 descendant-terminal triggering evidence drift: {name}")
        add_input(inputs, path)
        descendant_failure_pins[name] = pin
    descendant_outer = load_object(descendant_failure_files["outer_receipt"][0])
    descendant_pipeline = load_object(descendant_failure_files["pipeline_final"][0])
    descendant_phases = descendant_pipeline.get("phases", [])
    if descendant_outer.get("actual_child_os_exit_code") != 1 or \
            descendant_outer.get("outer_timeout") is not False or \
            descendant_pipeline.get("formal_t2_accepted") is not False or \
            len(descendant_phases) != 1:
        raise RuntimeError("R12 descendant-terminal triggering outer failure changed")
    descendant_phase = descendant_phases[0]
    descendant_races = descendant_phase.get("tracked_sample_exit_races", [])
    if descendant_phase.get("name") != "parse_gate" or \
            descendant_phase.get("exit_code") != 0 or \
            descendant_phase.get("stop_reason") != "process_tree_monitor_incomplete" or \
            descendant_phase.get("process_tree_sample_count") != 4 or \
            descendant_phase.get("process_tree_samples_complete") is not False or \
            descendant_phase.get("terminal_root_sample_exit_count") != 0 or \
            len(descendant_races) != 1:
        raise RuntimeError("R12 descendant-terminal triggering phase changed")
    descendant_race = descendant_races[0]
    if descendant_race.get("schema") != "vnext-t2-r21-tracked-sample-exit-r1" or \
            descendant_race.get("status") != "tracked_exit_unconfirmed_monitor_incomplete" or \
            descendant_race.get("complete") is not False or \
            descendant_race.get("absence_snapshot_count") != 1 or \
            descendant_race.get("retry_started") is not False or \
            descendant_race.get("rss_credit_bytes") != 0 or \
            descendant_race.get("cpu_credit_seconds") != {"user": 0.0, "system": 0.0} or \
            descendant_race.get("exit_code_credit_issued") is not False or \
            descendant_race.get("whole_sample_attempt_index") != 1 or \
            descendant_race.get("logical_sample_index") != 4 or \
            descendant_race.get("errors") != [{
                "exception_type": "ProcessTableError",
                "message": "tracked-exit confirmation 2 lost or reused the stage root",
                "pid": 36792,
                "stage": "r21_tracked_sample_exit_confirmation",
            }]:
        raise RuntimeError("R12 failed R21 evidence was reclassified or changed")
    return {
        "schema": "vnext-t2-r22-r23-membership-growth-delta-r1",
        "r22_source": receipt(R22_CONTROLLER),
        "r23_source": receipt(R23_CONTROLLER_PREIMAGE),
        "original_controller_path": CONTROLLER.relative_to(ROOT).as_posix(),
        "changed_top_level_functions": changed,
        "changed_top_level_assignments": changed_assignments,
        "r20_unbound_lane_ast_identical": True,
        "r21_tracked_exit_lane_ast_identical": True,
        "r22_pre_tree_lane_ast_identical": True,
        "phase_snapshot_history_pid_prefix_required": True,
        "independent_captured_source_witnesses_required": True,
        "outer_tracked_exit_query_recorded_before_sample_source": True,
        "prior_full_phase_pid_absence_required": True,
        "same_generation_complete_retry_required": True,
        "unrelated_off_tree_churn_allowed": True,
        "growth_cleanup_exact_handle_wait_and_non_259_exit_required": True,
        "discarded_attempt_rss_credit_bytes": 0,
        "discarded_attempt_cpu_credit_seconds": {"user": 0.0, "system": 0.0},
        "discarded_attempt_exit_credit_issued": False,
        "terminal_root_sample_exit_disposition": {
            "triggering_actual_r9_failure": terminal_failure_pins,
            "triggering_failure_reclassified": False,
            "tracked_launch_root_only": True,
            "prior_complete_sample_and_exact_active_closure_required": True,
            "same_generation_original_handles_wait_and_non_259_exit_required": True,
            "three_distinct_ascending_complete_absence_witnesses_required": True,
            "pid_reuse_or_orphan_or_new_generation_rejected": True,
            "discarded_attempt_never_a_completed_resource_sample": True,
            "partial_rss_at_or_above_original_cap_rejected": True,
            "final_audit_consumes_real_completed_sample_ledger": True,
            "final_audit_record_errors_empty_and_sample_index_sequential": True,
            "maximum_terminal_records": 1,
            "whole_sample_attempt_limit": 2,
            "new_retry_credit": False,
        },
        "descendant_terminal_root_sample_exit_disposition": {
            "schema": "vnext-t2-r23-descendant-terminal-root-sample-exit-disposition-r1",
            "triggering_actual_r12_failure": descendant_failure_pins,
            "triggering_failure_reclassified": False,
            "exact_nonroot_no_such_process_and_r21_confirmation_two_root_loss_required": True,
            "failed_r21_original_incomplete_status_one_absence_and_zero_credit_required": True,
            "failed_r21_canonical_digest_history_sequence_and_witness_binding_required": True,
            "r21_two_query_observations_captured_in_history_required": True,
            "accepted_outer_failed_and_previous_active_closures_equal_required": True,
            "original_popen_and_all_retained_handles_exact_generation_wait_non_259_required": True,
            "three_distinct_ascending_complete_raw_spi_absence_witnesses_required": True,
            "pid_reuse_or_orphan_or_outside_active_generation_rejected": True,
            "failed_sample_stays_incomplete_separate_and_never_retried": True,
            "partial_rss_cpu_and_exit_credit_zero_required": True,
            "independent_final_audit_recomputes_trigger_history_witness_and_failed_r21_digest": True,
            "original_natural_exit_final_process_tree_and_cleanup_gates_unchanged": True,
            "maximum_terminal_records": 1,
            "whole_sample_attempt_limit": 2,
            "new_retry_credit": False,
        },
        "coverage_thresholds_changed": False,
        "resource_limits_changed": False,
    }


def build_source_layout_rebase(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, R23_CONTROLLER_PREIMAGE)
    add_input(inputs, R23_CONTROLLER_PAIR_PREIMAGE)
    add_input(inputs, R23_CONTROLLER_MANAGED_PREIMAGE)
    add_input(inputs, CONTROLLER)
    parent_source = receipt(R23_CONTROLLER_PREIMAGE)
    current_source = receipt(R23_CONTROLLER_PAIR_PREIMAGE)
    current_executable_source = receipt(R23_CONTROLLER_MANAGED_PREIMAGE)
    if parent_source["bytes"] != 624265 or \
            parent_source["sha256"] != \
            "32854f365980ed1ea981277d758cdebcd486b276d950a2f395088fefcfa9f523":
        raise RuntimeError("original R23 controller preimage pin changed")
    if current_source != {
            "path": R23_CONTROLLER_PAIR_PREIMAGE.relative_to(ROOT).as_posix(),
            "bytes": 625360,
            "sha256": "a5ba94c56af75878d07cc2136c12f4c1232804cbd8c6fe3e90ff15c27ddb7367",
    }:
        raise RuntimeError("R23 A5 controller data preimage pin changed")
    if current_executable_source != {
            "path": R23_CONTROLLER_MANAGED_PREIMAGE.relative_to(ROOT).as_posix(),
            "bytes": 626070,
            "sha256": "b5a1cb43a3ba3a1c65c663530c238236018e6d5712a7a74c96ec395412577a5c",
    }:
        raise RuntimeError("R23 managed lifecycle historical controller pin changed")
    if (
            parent_source["path"] !=
            "runs/e/code_consolidation_20260927/t2_controller_before.py" or
            current_source["path"] !=
            R23_CONTROLLER_PAIR_PREIMAGE.relative_to(ROOT).as_posix() or
            current_executable_source["path"] !=
            R23_CONTROLLER_MANAGED_PREIMAGE.relative_to(ROOT).as_posix()):
        raise RuntimeError("R23 source-layout rebase paths are not canonical")

    parent_tree = ast.parse(read_source_text(R23_CONTROLLER_PREIMAGE))
    current_tree = ast.parse(read_source_text(R23_CONTROLLER_PAIR_PREIMAGE))

    def functions(tree: ast.Module) -> dict[str, str]:
        return {node.name: ast.dump(node, include_attributes=False)
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))}

    parent_functions = functions(parent_tree)
    current_functions = functions(current_tree)
    changed_functions = sorted(
        name for name in parent_functions.keys() | current_functions.keys()
        if parent_functions.get(name) != current_functions.get(name))
    expected_functions = [
        "_source_inputs", "input_receipts", "main", "verify_protocol"]
    if changed_functions != expected_functions:
        raise RuntimeError("R23 source-layout rebase changed an unexpected controller function")

    parent_main = next((node for node in parent_tree.body
                        if isinstance(node, ast.FunctionDef) and node.name == "main"), None)
    current_main = next((node for node in current_tree.body
                         if isinstance(node, ast.FunctionDef) and node.name == "main"), None)
    expected_main_guard = ast.parse(
        "_source_inputs().require_local_execution(Path(args.protocol))").body[0]
    expected_protocol_assignment = ast.parse(
        "protocol_path = Path(args.protocol).resolve()").body[0]
    guard_matches = [index for index, node in enumerate(current_main.body)
                     if ast.dump(node, include_attributes=False) ==
                     ast.dump(expected_main_guard, include_attributes=False)] \
        if current_main is not None else []
    if parent_main is None or current_main is None or len(guard_matches) != 1:
        raise RuntimeError("R23 main local-execution guard is absent or ambiguous")
    guard_index = guard_matches[0]
    if guard_index + 1 >= len(current_main.body) or \
            ast.dump(current_main.body[guard_index + 1], include_attributes=False) != \
            ast.dump(expected_protocol_assignment, include_attributes=False):
        raise RuntimeError("R23 main local-execution guard is not immediately before protocol resolution")
    guard_node = current_main.body.pop(guard_index)
    try:
        main_without_guard_matches_parent = \
            ast.dump(current_main, include_attributes=False) == \
            ast.dump(parent_main, include_attributes=False)
    finally:
        current_main.body.insert(guard_index, guard_node)
    if not main_without_guard_matches_parent:
        raise RuntimeError("R23 main changed beyond the protocol local-execution guard")

    added_sources = [
        "if str(ROOT) not in sys.path:\n    sys.path.insert(0, str(ROOT))",
        "from tools.execution.t2_source_inputs import T2SourceInputs",
        "_T2_SOURCE_INPUTS = None",
    ]
    added_nodes = [ast.parse(source).body[0] for source in added_sources]
    added_dumps = [ast.dump(node, include_attributes=False) for node in added_nodes]
    parent_nonfunctions = [
        ast.dump(node, include_attributes=False) for node in parent_tree.body
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
    current_nonfunctions = [
        ast.dump(node, include_attributes=False) for node in current_tree.body
        if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))]
    remaining = list(current_nonfunctions)
    for expected in added_dumps:
        if expected not in remaining:
            raise RuntimeError("R23 source-layout rebase setup statement is absent")
        remaining.remove(expected)
    unaffected_equal = remaining == parent_nonfunctions

    root_assignment_dump = ast.dump(ast.parse(
        "ROOT = Path(__file__).resolve().parents[4]").body[0],
        include_attributes=False)
    root_index = next((index for index, node in enumerate(current_tree.body)
                       if ast.dump(node, include_attributes=False) ==
                       root_assignment_dump), None)
    if root_index is None or [
            ast.dump(node, include_attributes=False)
            for node in current_tree.body[root_index + 1:root_index + 4]
    ] != added_dumps:
        raise RuntimeError("R23 source-layout bootstrap is not adjacent to ROOT")
    if not unaffected_equal:
        raise RuntimeError("R23 source-layout rebase changed unrelated top-level AST")

    pair_preimage_text = read_source_text(R23_CONTROLLER_PAIR_PREIMAGE)
    pair_current_text = read_source_text(R23_CONTROLLER_MANAGED_PREIMAGE)
    pair_anchor_before = (
        "            record = _r23_confirm_descendant_terminal_root_sample_exit(\n"
        "                previous_accepted_source_snapshot,\n"
        "                outer_reconcile_snapshot,\n"
        "                source,\n"
        "                root_identity,\n"
        "                r21_record.get(\"target_identity\"),\n"
        "                attempt_previous,\n")
    pair_anchor_after = (
        "            target_value = r21_record.get(\"target_identity\")\n"
        "            if (\n"
        "                    type(target_value) is not dict or\n"
        "                    set(target_value) != {\"pid\", \"create_time_100ns\"} or\n"
        "                    type(target_value[\"pid\"]) is not int or\n"
        "                    target_value[\"pid\"] <= 0 or\n"
        "                    type(target_value[\"create_time_100ns\"]) is not int or\n"
        "                    target_value[\"create_time_100ns\"] <= 0):\n"
        "                raise _R23_TABLE.ProcessTableError(\n"
        "                    \"descendant-terminal target identity is not strict PID/FILETIME mapping\")\n"
        "            target_identity = _R23_TABLE.validate_identity(\n"
        "                (target_value[\"pid\"], target_value[\"create_time_100ns\"]))\n"
        "            record = _r23_confirm_descendant_terminal_root_sample_exit(\n"
        "                previous_accepted_source_snapshot,\n"
        "                outer_reconcile_snapshot,\n"
        "                source,\n"
        "                root_identity,\n"
        "                target_identity,\n"
        "                attempt_previous,\n")
    pair_anchor_count = pair_preimage_text.count(pair_anchor_before)
    if pair_anchor_count != 1:
        raise RuntimeError("R23 descendant target-identity pair anchor is absent or ambiguous")
    pair_expected_text = pair_preimage_text.replace(
        pair_anchor_before, pair_anchor_after, 1)
    pair_full_source_text_equal = pair_current_text == pair_expected_text
    if not pair_full_source_text_equal:
        raise RuntimeError("R23 controller changed outside the strict target-identity pair anchor")

    pair_preimage_tree = ast.parse(pair_preimage_text)
    pair_current_tree = ast.parse(pair_current_text)
    pair_preimage_functions = functions(pair_preimage_tree)
    pair_current_functions = functions(pair_current_tree)
    pair_changed_functions = sorted(
        name for name in pair_preimage_functions.keys() | pair_current_functions.keys()
        if pair_preimage_functions.get(name) != pair_current_functions.get(name))
    if pair_changed_functions != ["_r20_native_sample"]:
        raise RuntimeError("R23 pair-adapter changed an unexpected controller function")

    def assignments(tree: ast.Module) -> dict[str, str]:
        return {node.targets[0].id: ast.dump(node, include_attributes=False)
                for node in tree.body if isinstance(node, ast.Assign) and
                len(node.targets) == 1 and isinstance(node.targets[0], ast.Name)}

    pair_preimage_assignments = assignments(pair_preimage_tree)
    pair_current_assignments = assignments(pair_current_tree)
    pair_changed_assignments = sorted(
        name for name in pair_preimage_assignments.keys() |
        pair_current_assignments.keys()
        if pair_preimage_assignments.get(name) != pair_current_assignments.get(name))
    pair_full_ast_equal = ast.dump(pair_current_tree, include_attributes=False) == \
        ast.dump(ast.parse(pair_expected_text), include_attributes=False)
    if pair_changed_assignments or not pair_full_ast_equal:
        raise RuntimeError("R23 pair-adapter changed top-level assignments or unrelated AST")

    pair_adapter = {
        "schema": "vnext-t2-r23-descendant-target-identity-pair-adapter-r1",
        "preimage_source": current_source,
        "current_source": current_executable_source,
        "anchor_id": "r21_target_identity_mapping_to_strict_native_pair",
        "anchor_count": pair_anchor_count,
        "changed_top_level_functions": pair_changed_functions,
        "changed_top_level_assignments": pair_changed_assignments,
        "accepted_mapping_keys": ["pid", "create_time_100ns"],
        "exact_positive_integer_values": True,
        "native_validator": "_R23_TABLE.validate_identity",
        "coercion_applied": False,
        "full_source_text_equal_after_anchor": pair_full_source_text_equal,
        "full_ast_equal_after_anchor": pair_full_ast_equal,
        "consumer": {
            "entrypoint": "scripts/vnext_t2.py",
            "ordered_commands": ["build", "verify", "run"],
        },
    }

    return {
        "schema": "vnext-t2-source-layout-rebase-v1",
        "parent_source": parent_source,
        "current_source": current_source,
        "current_executable_source": current_executable_source,
        "layer_scope": "historical_source_lineage_only",
        "original_controller_path": CONTROLLER.relative_to(ROOT).as_posix(),
        "changed_top_level_functions": changed_functions,
        "main_protocol_path_guard_verified": True,
        "added_top_level_statements": added_dumps,
        "unaffected_top_level_ast_equal": unaffected_equal,
        "descendant_terminal_target_identity_pair_adapter": pair_adapter,
    }


def build_managed_process_lifecycle_controller_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, R23_CONTROLLER_MANAGED_PREIMAGE)
    add_input(inputs, CONTROLLER)
    historical_predecessor_source = receipt(R23_CONTROLLER_MANAGED_PREIMAGE)
    current_source = receipt(CONTROLLER)
    expected_historical = {
        "path": R23_CONTROLLER_MANAGED_PREIMAGE.relative_to(ROOT).as_posix(),
        "bytes": 626070,
        "sha256": "b5a1cb43a3ba3a1c65c663530c238236018e6d5712a7a74c96ec395412577a5c",
    }
    expected_current = {
        "path": CONTROLLER.relative_to(ROOT).as_posix(),
        "bytes": 677366,
        "sha256": "a1cdf6e97a51b67c4369779ad258afa5943c0f92d76d8295e1fa2a84c6cf998c",
    }
    if historical_predecessor_source != expected_historical or \
            current_source != expected_current:
        raise RuntimeError("managed lifecycle controller source pins changed")

    historical_tree = ast.parse(read_source_text(R23_CONTROLLER_MANAGED_PREIMAGE))
    current_tree = ast.parse(read_source_text(CONTROLLER))

    def named_nodes(tree: ast.Module, node_types: tuple[type, ...], name_of):
        rows = {}
        count = 0
        for node in tree.body:
            if isinstance(node, node_types):
                name = name_of(node)
                if name is not None:
                    count += 1
                    if name in rows:
                        raise RuntimeError("managed controller has duplicate top-level "
                                           "declaration names")
                    rows[name] = ast.dump(node, include_attributes=False)
        if count != len(rows):
            raise RuntimeError("managed controller top-level declaration inventory is ambiguous")
        return rows

    def function_name(node):
        return node.name

    def assignment_name(node):
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and \
                isinstance(node.targets[0], ast.Name):
            return node.targets[0].id
        return None

    def annotated_assignment_name(node):
        if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
            return node.target.id
        return None

    def class_name(node):
        return node.name

    historical_functions = named_nodes(
        historical_tree, (ast.FunctionDef, ast.AsyncFunctionDef), function_name)
    current_functions = named_nodes(
        current_tree, (ast.FunctionDef, ast.AsyncFunctionDef), function_name)
    changed_functions = sorted(
        name for name in historical_functions.keys() | current_functions.keys()
        if historical_functions.get(name) != current_functions.get(name))
    added_functions = sorted(current_functions.keys() - historical_functions.keys())
    removed_functions = sorted(historical_functions.keys() - current_functions.keys())
    expected_changed_functions = [
        "_load_managed_lifecycle", "_r20_native_sample",
        "_r23_audit_and_cleanup", "_r23_exact_heavy_audit",
        "_r23_final_audit", "_r23_handle_for_identity",
        "_r23_root_handle", "_r23_validate_snapshot_history",
        "configure_managed_lifecycle", "git_head", "main",
        "require_natural", "run_phase",
    ]
    expected_added_functions = [
        "_load_managed_lifecycle", "_r23_root_handle",
        "configure_managed_lifecycle",
    ]
    if changed_functions != expected_changed_functions or \
            added_functions != expected_added_functions or removed_functions:
        raise RuntimeError("managed lifecycle controller function delta changed")

    historical_assignments = named_nodes(
        historical_tree, (ast.Assign,), assignment_name)
    current_assignments = named_nodes(
        current_tree, (ast.Assign,), assignment_name)
    changed_assignments = sorted(
        name for name in historical_assignments.keys() | current_assignments.keys()
        if historical_assignments.get(name) != current_assignments.get(name))
    added_assignments = sorted(
        current_assignments.keys() - historical_assignments.keys())
    removed_assignments = sorted(
        historical_assignments.keys() - current_assignments.keys())
    expected_changed_assignments = [
        "_R23_LIFECYCLE_PATH", "_R23_LIFECYCLE_RELATIVE_PATH",
        "_R23_SUPERVISOR_SHA256",
    ]
    expected_added_assignments = [
        "_R23_LIFECYCLE_PATH", "_R23_LIFECYCLE_RELATIVE_PATH",
    ]
    if changed_assignments != expected_changed_assignments or \
            added_assignments != expected_added_assignments or removed_assignments:
        raise RuntimeError("managed lifecycle controller assignment delta changed")

    historical_annotated = named_nodes(
        historical_tree, (ast.AnnAssign,), annotated_assignment_name)
    current_annotated = named_nodes(
        current_tree, (ast.AnnAssign,), annotated_assignment_name)
    changed_annotated = sorted(
        name for name in historical_annotated.keys() | current_annotated.keys()
        if historical_annotated.get(name) != current_annotated.get(name))
    added_annotated = sorted(current_annotated.keys() - historical_annotated.keys())
    removed_annotated = sorted(historical_annotated.keys() - current_annotated.keys())
    expected_added_annotated = [
        "_R23_ACTIVE_PROTOCOL", "_R23_ACTIVE_PROTOCOL_SHA256",
        "_R23_MANAGED_LIFECYCLE",
    ]
    if changed_annotated != expected_added_annotated or \
            added_annotated != expected_added_annotated or removed_annotated:
        raise RuntimeError("managed lifecycle controller annotated-assignment delta changed")

    historical_classes = named_nodes(
        historical_tree, (ast.ClassDef,), class_name)
    current_classes = named_nodes(
        current_tree, (ast.ClassDef,), class_name)
    changed_classes = sorted(
        name for name in historical_classes.keys() & current_classes.keys()
        if historical_classes[name] != current_classes[name])
    added_classes = sorted(current_classes.keys() - historical_classes.keys())
    removed_classes = sorted(historical_classes.keys() - current_classes.keys())
    if changed_classes or added_classes != ["_R23ManagedObserver"] or removed_classes:
        raise RuntimeError("managed lifecycle controller class delta changed")

    added_import_statements = [
        "import msvcrt", "import secrets", "from typing import Any, Mapping",
    ]
    removed_import_statements = ["from typing import Any"]
    def import_dumps(tree: ast.Module) -> list[str]:
        return [ast.dump(node, include_attributes=False) for node in tree.body
                if isinstance(node, (ast.Import, ast.ImportFrom))]

    def import_delta(before: list[str], after: list[str]) -> tuple[list[str], list[str]]:
        def counts(values: list[str]) -> dict[str, int]:
            out: dict[str, int] = {}
            for value in values:
                out[value] = out.get(value, 0) + 1
            return out
        before_counts, after_counts = counts(before), counts(after)
        added = [value for value in sorted(before_counts.keys() | after_counts.keys())
                 for _ in range(max(0, after_counts.get(value, 0) -
                                      before_counts.get(value, 0)))]
        removed = [value for value in sorted(before_counts.keys() | after_counts.keys())
                   for _ in range(max(0, before_counts.get(value, 0) -
                                        after_counts.get(value, 0)))]
        return added, removed

    expected_added_import_dumps = [
        ast.dump(ast.parse(source).body[0], include_attributes=False)
        for source in added_import_statements
    ]
    expected_removed_import_dumps = [
        ast.dump(ast.parse(source).body[0], include_attributes=False)
        for source in removed_import_statements
    ]
    actual_added_import_dumps, actual_removed_import_dumps = import_delta(
        import_dumps(historical_tree), import_dumps(current_tree))
    if sorted(actual_added_import_dumps) != sorted(expected_added_import_dumps) or \
            sorted(actual_removed_import_dumps) != sorted(expected_removed_import_dumps):
        raise RuntimeError("managed lifecycle controller import delta changed")

    added_annotated_statements = [
        "_R23_ACTIVE_PROTOCOL: dict[str, Any] | None = None",
        "_R23_ACTIVE_PROTOCOL_SHA256: str | None = None",
        "_R23_MANAGED_LIFECYCLE: Any | None = None",
    ]
    if any(not isinstance(ast.parse(source).body[0], ast.AnnAssign)
           for source in added_annotated_statements):
        raise RuntimeError("managed lifecycle annotated statement contract is malformed")

    changed_function_names = set(changed_functions)
    changed_assignment_names = set(changed_assignments)
    changed_annotated_names = set(changed_annotated)
    changed_class_names = set(added_classes) | set(removed_classes)
    changed_import_dumps = set(actual_added_import_dumps) | set(actual_removed_import_dumps)

    def unapproved_nodes(tree: ast.Module) -> list[str]:
        values = []
        for node in tree.body:
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and \
                    node.name in changed_function_names:
                continue
            assignment = assignment_name(node) if isinstance(node, ast.Assign) else None
            if assignment is not None and assignment in changed_assignment_names:
                continue
            annotated = (annotated_assignment_name(node)
                         if isinstance(node, ast.AnnAssign) else None)
            if annotated is not None and annotated in changed_annotated_names:
                continue
            if isinstance(node, ast.ClassDef) and node.name in changed_class_names:
                continue
            if isinstance(node, (ast.Import, ast.ImportFrom)) and \
                    ast.dump(node, include_attributes=False) in changed_import_dumps:
                continue
            values.append(ast.dump(node, include_attributes=False))
        return values

    all_unapproved_top_level_ast_equal = \
        unapproved_nodes(historical_tree) == unapproved_nodes(current_tree) and \
        [ast.dump(node, include_attributes=False)
         for node in historical_tree.type_ignores] == \
        [ast.dump(node, include_attributes=False)
         for node in current_tree.type_ignores]
    if not all_unapproved_top_level_ast_equal:
        raise RuntimeError("managed lifecycle controller changed unapproved top-level AST")

    return {
        "schema": "vnext-t2-managed-controller-source-delta-v1",
        "historical_predecessor_source": historical_predecessor_source,
        "current_source": current_source,
        "changed_top_level_functions": changed_functions,
        "added_functions": added_functions,
        "removed_functions": removed_functions,
        "changed_top_level_assignments": changed_assignments,
        "added_top_level_assignments": added_assignments,
        "removed_top_level_assignments": removed_assignments,
        "added_top_level_annotated_assignments": added_annotated_statements,
        "removed_top_level_annotated_assignments": [],
        "added_import_statements": added_import_statements,
        "removed_import_statements": removed_import_statements,
        "added_classes": added_classes,
        "removed_classes": removed_classes,
        "all_unapproved_top_level_ast_equal": all_unapproved_top_level_ast_equal,
    }


def build_projection_reuse_validator_r10_r11_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, R10_PROJECTION_REUSE_VALIDATOR)
    add_input(inputs, R11_PROJECTION_REUSE_VALIDATOR)
    old = read_source_text(R10_PROJECTION_REUSE_VALIDATOR)
    new = read_source_text(R11_PROJECTION_REUSE_VALIDATOR)
    old_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r8":'
    new_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":'
    if old.count(old_gate) != 1 or new != old.replace(old_gate, new_gate, 1):
        raise RuntimeError("R10-to-R11 projection validator changed outside the r9 schema gate")
    return {"schema": "vnext-t2-projection-reuse-validator-r10-r11-schema-delta-r1",
            "r10_source": receipt(R10_PROJECTION_REUSE_VALIDATOR),
            "r11_source": receipt(R11_PROJECTION_REUSE_VALIDATOR),
            "only_change": "accept vnext-t2-independent-negative-protocol-r9 in the same top-level schema gate",
            "all_projection_plan_and_receipt_assertions_unchanged": True}


def build_projection_reuse_validator_r11_r12_delta(
        inputs: dict[str, dict[str, Any]]) -> dict[str, Any]:
    add_input(inputs, R11_PROJECTION_REUSE_VALIDATOR)
    add_input(inputs, R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE)
    add_input(inputs, R12_PROJECTION_REUSE_VALIDATOR)
    r11_source = read_source_text(R11_PROJECTION_REUSE_VALIDATOR)
    preimage = read_source_text(R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE)
    current = read_source_text(R12_PROJECTION_REUSE_VALIDATOR)
    r11_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r9":'
    r12_gate = 'if protocol.get("schema") != "vnext-t2-independent-negative-protocol-r10":'
    r11_usage = "usage: validate_projection24_reuse_r10.py <protocol.json> <receipt.json>"
    r12_usage = "usage: validate_projection24_reuse_r12.py <protocol.json> <receipt.json>"
    expected_r12_preimage = r11_source.replace(r11_usage, r12_usage, 1).replace(
        r11_gate, r12_gate, 1)
    preimage_receipt = receipt(R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE)
    current_receipt = receipt(R12_PROJECTION_REUSE_VALIDATOR)
    if r11_source.count(r11_usage) != 1 or r11_source.count(r11_gate) != 1 or \
            preimage != expected_r12_preimage or \
            preimage_receipt != {
                "path": R12_PROJECTION_REUSE_VALIDATOR_PREIMAGE.relative_to(
                    ROOT).as_posix(),
                "bytes": 13712,
                "sha256": "04f3cf18221b69942815a8fd4d724e956ae3a230077200a24c49d57474344d41"}:
        raise RuntimeError(
            "R11-to-sealed-R12 data preimage changed beyond its r10 schema/usage delta")

    transformations = [
        ("bootstrap",
         "ROOT = Path(__file__).resolve().parents[4]\n",
         "ROOT = Path(__file__).resolve().parents[4]\n"
         "if str(ROOT) not in sys.path:\n"
         "    sys.path.insert(0, str(ROOT))\n"
         "from tools.execution.t2_source_inputs import T2SourceInputs\n\n"),
        ("receipt",
         "def receipt(path: Path) -> dict[str, Any]:\n"
         "    data = path.read_bytes()\n"
         "    return {\"path\": path.relative_to(ROOT).as_posix(), \"bytes\": len(data),\n"
         "            \"sha256\": sha256_bytes(data)}\n",
         "def receipt(path: Path, protocol: dict[str, Any],\n"
         "            source_inputs: T2SourceInputs, *,\n"
         "            include_bytes: bool = False) -> Any:\n"
         "    data = source_inputs.read_protocol_input_bytes(protocol, path)\n"
         "    actual = {\"path\": source_inputs.logical_path(path), \"bytes\": len(data),\n"
         "              \"sha256\": sha256_bytes(data)}\n"
         "    return (actual, data) if include_bytes else actual\n"),
        ("require_receipt",
         "def require_receipt(path: Path, expected: dict[str, Any]) -> dict[str, Any]:\n"
         "    actual = receipt(path)\n"
         "    if actual != expected:\n"
         "        raise RuntimeError(f\"projection reuse receipt drift: {path}\")\n"
         "    return actual\n",
         "def require_receipt(path: Path, expected: dict[str, Any],\n"
         "                    protocol: dict[str, Any],\n"
         "                    source_inputs: T2SourceInputs, *,\n"
         "                    include_bytes: bool = False) -> Any:\n"
         "    relative = source_inputs.logical_path(path)\n"
         "    protocol_inputs = protocol.get(\"inputs\")\n"
         "    if not isinstance(protocol_inputs, dict) or \\\n"
         "            protocol_inputs.get(relative) != expected:\n"
         "        raise RuntimeError(\n"
         "            f\"projection reuse expected pin is not a protocol input: {relative}\")\n"
         "    observed = receipt(path, protocol, source_inputs,\n"
         "                       include_bytes=include_bytes)\n"
         "    if include_bytes:\n"
         "        actual, data = observed\n"
         "    else:\n"
         "        actual = observed\n"
         "    if actual != expected:\n"
         "        raise RuntimeError(f\"projection reuse receipt drift: {path}\")\n"
         "    return (actual, data) if include_bytes else actual\n"),
        ("main_protocol_local_read",
         "    protocol_path = Path(sys.argv[1]).resolve()\n"
         "    output_path = Path(sys.argv[2]).resolve()\n"
         "    if output_path.exists():\n"
         "        raise FileExistsError(output_path)\n"
         "    protocol = load(protocol_path)\n",
         "    source_inputs = T2SourceInputs(ROOT)\n"
         "    validator_path = Path(__file__)\n"
         "    protocol_argument = Path(sys.argv[1])\n"
         "    source_inputs.require_local_execution(validator_path)\n"
         "    source_inputs.require_local_execution(protocol_argument)\n"
         "    protocol_path = protocol_argument.resolve(strict=True)\n"
         "    output_path = Path(sys.argv[2]).resolve()\n"
         "    if output_path.exists():\n"
         "        raise FileExistsError(output_path)\n"
         "    protocol_bytes = source_inputs.read_bytes(protocol_argument)\n"
         "    protocol = json.loads(protocol_bytes.decode(\"utf-8\"))\n"
         "    if not isinstance(protocol, dict):\n"
         "        raise TypeError(protocol_path)\n"
         "    source_inputs.verify_protocol_layout(protocol)\n"
         "    validator_relative = source_inputs.logical_path(validator_path)\n"
         "    validator_pin = protocol[\"inputs\"].get(validator_relative)\n"
         "    validator_receipt = receipt(validator_path, protocol, source_inputs)\n"
         "    if validator_receipt != validator_pin:\n"
         "        raise RuntimeError(\"projection reuse executing validator pin mismatch\")\n"),
        ("main_old_protocol_bytes",
         "    old_protocol_receipt = require_receipt(\n"
         "        ROOT / old_protocol_pin[\"path\"], old_protocol_pin)\n"
         "    old_protocol = load(ROOT / old_protocol_pin[\"path\"])\n",
         "    old_protocol_path = ROOT / old_protocol_pin[\"path\"]\n"
         "    old_protocol_receipt, old_protocol_bytes = require_receipt(\n"
         "        old_protocol_path, old_protocol_pin, protocol, source_inputs,\n"
         "        include_bytes=True)\n"
         "    old_protocol = json.loads(old_protocol_bytes.decode(\"utf-8\"))\n"
         "    if not isinstance(old_protocol, dict):\n"
         "        raise TypeError(old_protocol_path)\n"),
        ("main_dependency_read_loop",
         "    dependencies = frozen[\"dependency_subset\"]\n"
         "    observed_dependencies = {\n"
         "        relative: require_receipt(ROOT / relative, expected)\n"
         "        for relative, expected in sorted(dependencies.items())\n"
         "    }\n",
         "    dependencies = frozen[\"dependency_subset\"]\n"
         "    old_protocol_relative = source_inputs.logical_path(old_protocol_path)\n"
         "    if dependencies.get(old_protocol_relative) != old_protocol_pin:\n"
         "        raise RuntimeError(\"projection reuse source protocol is outside its dependency subset\")\n"
         "    observed_dependencies = {old_protocol_relative: old_protocol_receipt}\n"
         "    phase_path = ROOT / frozen[\"phase_files\"][\"phase\"][\"path\"]\n"
         "    observation_path = ROOT / frozen[\"phase_files\"][\"actual_observation\"][\"path\"]\n"
         "    stdout_path = ROOT / frozen[\"phase_files\"][\"stdout\"][\"path\"]\n"
         "    timeout_path = ROOT / frozen[\"source_timeout_execution_receipt\"][\"path\"]\n"
         "    phase = None\n"
         "    observation = None\n"
         "    timeout = None\n"
         "    stdout = None\n"
         "    for relative, expected in sorted(dependencies.items()):\n"
         "        if relative == old_protocol_relative:\n"
         "            continue\n"
         "        path = ROOT / relative\n"
         "        if path in (phase_path, observation_path, stdout_path, timeout_path):\n"
         "            actual, data = require_receipt(\n"
         "                path, expected, protocol, source_inputs, include_bytes=True)\n"
         "            if path == phase_path:\n"
         "                phase = json.loads(data.decode(\"utf-8\"))\n"
         "                if not isinstance(phase, dict):\n"
         "                    raise TypeError(path)\n"
         "            elif path == observation_path:\n"
         "                observation = json.loads(data.decode(\"utf-8\"))\n"
         "                if not isinstance(observation, dict):\n"
         "                    raise TypeError(path)\n"
         "            elif path == stdout_path:\n"
         "                stdout = data.decode(\"utf-8\", errors=\"replace\")\n"
         "            else:\n"
         "                timeout = json.loads(data.decode(\"utf-8\"))\n"
         "                if not isinstance(timeout, dict):\n"
         "                    raise TypeError(path)\n"
         "        else:\n"
         "            actual = require_receipt(path, expected, protocol, source_inputs)\n"
         "        observed_dependencies[relative] = actual\n"),
        ("main_dependency_reuse",
         "    old_pipeline = require_receipt(\n"
         "        ROOT / frozen[\"source_pipeline_final\"][\"path\"],\n"
         "        frozen[\"source_pipeline_final\"])\n"
         "    timeout_receipt = require_receipt(\n"
         "        ROOT / frozen[\"source_timeout_execution_receipt\"][\"path\"],\n"
         "        frozen[\"source_timeout_execution_receipt\"])\n"
         "    phase_files = {\n"
         "        name: require_receipt(ROOT / expected[\"path\"], expected)\n"
         "        for name, expected in sorted(frozen[\"phase_files\"].items())\n"
         "    }\n\n"
         "    phase = load(ROOT / frozen[\"phase_files\"][\"phase\"][\"path\"])\n",
         "    old_pipeline = observed_dependencies[\n"
         "        frozen[\"source_pipeline_final\"][\"path\"]]\n"
         "    timeout_receipt = observed_dependencies[\n"
         "        frozen[\"source_timeout_execution_receipt\"][\"path\"]]\n"
         "    phase_files = {\n"
         "        name: observed_dependencies[expected[\"path\"]]\n"
         "        for name, expected in sorted(frozen[\"phase_files\"].items())\n"
         "    }\n"
         "    if not isinstance(phase, dict) or not isinstance(observation, dict) or \\\n"
         "            not isinstance(timeout, dict) or not isinstance(stdout, str):\n"
         "        raise RuntimeError(\"projection reuse local evidence was not read from the pinned dependency set\")\n\n"),
        ("main_remove_observation_reread",
         "    observation = load(\n"
         "        ROOT / frozen[\"phase_files\"][\"actual_observation\"][\"path\"])\n", ""),
        ("main_remove_stdout_reread",
         "    stdout = (ROOT / frozen[\"phase_files\"][\"stdout\"][\"path\"]).read_text(\n"
         "        encoding=\"utf-8\", errors=\"replace\")\n", ""),
        ("main_remove_timeout_reread",
         "    timeout = load(\n"
         "        ROOT / frozen[\"source_timeout_execution_receipt\"][\"path\"])\n", ""),
        ("main_output_receipt",
         "    print(\"T2_PROJECTION24_REUSE=PASS sites=24 groups=4\", flush=True)\n"
         "    print(json.dumps({\"status\": \"pass\", \"receipt\": receipt(output_path)},\n"
         "                     sort_keys=True), flush=True)\n",
         "    output_bytes = output_path.read_bytes()\n"
         "    output_receipt = {\"path\": output_path.relative_to(ROOT).as_posix(),\n"
         "                      \"bytes\": len(output_bytes),\n"
         "                      \"sha256\": sha256_bytes(output_bytes)}\n"
         "    print(\"T2_PROJECTION24_REUSE=PASS sites=24 groups=4\", flush=True)\n"
         "    print(json.dumps({\"status\": \"pass\", \"receipt\": output_receipt},\n"
         "                     sort_keys=True), flush=True)\n"),
    ]
    replacement_ids = [name for name, _before, _after in transformations]
    if len(transformations) != 11 or len(set(replacement_ids)) != 11:
        raise RuntimeError("R12 source-layout adapter transformation list changed")
    expected_current = preimage
    for name, before, after in transformations:
        count = expected_current.count(before)
        if count != 1:
            raise RuntimeError(
                f"R12 source-layout adapter anchor {name} occurs {count} times")
        expected_current = expected_current.replace(before, after, 1)
    if current != expected_current or \
            ast.dump(ast.parse(current), include_attributes=False) != \
            ast.dump(ast.parse(expected_current), include_attributes=False):
        raise RuntimeError("R12 source-layout adapter differs from anchored expected source")

    r11_r12 = {
        "schema": "vnext-t2-projection-reuse-validator-r11-r12-schema-delta-r1",
        "r11_source": receipt(R11_PROJECTION_REUSE_VALIDATOR),
        "r12_source": preimage_receipt,
        "r12_source_role": "sealed_data_preimage_not_current_executable",
        "only_changes": [
            "accept vnext-t2-independent-negative-protocol-r10 in the same top-level schema gate",
            "version the CLI usage label to validate_projection24_reuse_r12.py"],
        "all_projection_plan_source_input_hash_and_24_site_checks_unchanged": True,
    }
    adapter = {
        "schema": "vnext-t2-projection-reuse-validator-r12-source-layout-adapter-r1",
        "preimage_role": "sealed_data_preimage_not_current_executable",
        "preimage_source": preimage_receipt,
        "current_source": current_receipt,
        "reconstruction": "11_exact_anchored_text_replacements_then_full_source_and_ast_equality",
        "replacement_count": len(transformations),
        "replacement_ids": replacement_ids,
        "changed_top_level_functions": ["main", "receipt", "require_receipt"],
        "added_top_level_statements": [
            "source_inputs_bootstrap_guard", "T2SourceInputs_import"],
        "all_other_top_level_ast_equal": True,
        "full_source_text_equal": current == expected_current,
        "full_ast_equal": True,
    }
    return {
        "r11_r12_delta": r11_r12,
        "r12_source_layout_adapter": adapter,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--positive-dispatch-dir", required=True)
    parser.add_argument("--positive-evidence-dir", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--planned-evidence-dir", required=True)
    parser.add_argument("--julia", required=True)
    parser.add_argument("--coverage-map", default=str(ROOT / ARCHIVE_COVERAGE))
    parser.add_argument("--review-input", action="append", default=[])
    args = parser.parse_args()

    source_provider = _source_inputs()
    source_layout = _source_layout()
    source_provider.require_local_execution(Path(__file__))
    for current_source in (
            DRIVER, CONTROLLER, STATIC_QA, PROJECTION_REUSE_VALIDATOR,
            R23_TABLE, R23_SUPERVISOR, R23_TEST_SUITE,
            OLD_SUITE, PROJECTION_SUITE):
        source_provider.require_local_execution(current_source)
    for relative in MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS:
        source_provider.require_local_execution(ROOT / relative)

    freezer_script = Path(__file__).resolve()
    freezer_argv0 = Path(sys.argv[0]).resolve()
    if __name__ != "__main__" or freezer_argv0 != freezer_script or \
            not sys.dont_write_bytecode:
        raise RuntimeError("freezer must run as a direct -B Python script")

    positive_dispatch = Path(args.positive_dispatch_dir).absolute()
    positive_evidence = Path(args.positive_evidence_dir).absolute()
    julia_executable = Path(args.julia).resolve()
    output = Path(args.output_dir).resolve()
    planned = Path(args.planned_evidence_dir).resolve()
    coverage_path = Path(args.coverage_map).absolute()
    execution_evidence_root = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()
    for path in (positive_dispatch, positive_evidence, output, planned,
                 coverage_path):
        path.relative_to(ROOT)
    if output.parent != execution_evidence_root:
        raise RuntimeError("R23 freeze output must be a direct runs-root leaf")
    if planned.parent != execution_evidence_root:
        raise RuntimeError("formal T2 evidence must be a direct runs-root leaf")
    if not output.is_dir() or not coverage_path.is_file():
        raise FileNotFoundError("runs output leaf or frozen r16 coverage map is missing")
    for name in ("protocol.json", "dispatch.json", "command_argv.json", "static_qa.json",
                 "static_qa.stdout.raw", "static_qa.stderr.raw", "freeze_snapshot.json"):
        if (output / name).exists():
            raise FileExistsError(output / name)
    if (output / "projection24_reuse_preflight").exists():
        raise FileExistsError(output / "projection24_reuse_preflight")
    if planned.exists():
        raise RuntimeError("planned T2 execution evidence directory already exists")
    if not julia_executable.is_file():
        raise FileNotFoundError(julia_executable)
    cache_exclusions = generated_python_cache_exclusions()
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout.strip()
    if head != EXPECTED_HEAD:
        raise RuntimeError(f"repository HEAD mismatch: {head}")

    runtime_inputs_path = positive_dispatch / "runtime_inputs.json"
    positive_protocol_path = positive_dispatch / "protocol.json"
    positive_dispatch_path = positive_dispatch / "dispatch.json"
    positive_command_path = positive_dispatch / "command.txt"
    for path in (runtime_inputs_path, positive_protocol_path,
                 positive_dispatch_path, positive_command_path):
        if not path.is_file():
            raise FileNotFoundError(path)
    runtime_inputs = load_object(runtime_inputs_path)
    positive_final_path = positive_evidence / "formal_t2_serial_replay.json"
    positive_pipeline_path = positive_evidence / "pipeline_final.json"
    positive_final = load_object(positive_final_path)
    positive_pipeline = load_object(positive_pipeline_path)
    if positive_final.get("status") != "pass" or \
            positive_final.get("formal_gate_evidence_kind") != "formal_t1_actual" or \
            positive_final.get("formal_gate_verified") is not True or \
            positive_final.get("formal_t2_accepted") is not False or \
            positive_pipeline.get("status") != "pass" or \
            positive_pipeline.get("failure") is not None or \
            positive_pipeline.get("pinned_input_changes") != [] or \
            positive_pipeline.get("residual_heavy_processes") != []:
        raise RuntimeError("positive r3 replay or pipeline is not a bounded clean pass")

    inputs: dict[str, dict[str, Any]] = {}
    historical_paths = source_provider.history_paths_under(TEST_ROOT)
    historical_relatives = [source_provider.logical_path(path)
                            for path in historical_paths]
    if historical_relatives != sorted(source_layout["historical_source_data"]):
        raise RuntimeError(
            "registered historical source set is not exactly scoped under the R23 test root")
    historical_path_set = set(historical_relatives)
    for relative in sorted(source_layout["binding_inputs"]):
        add_input(inputs, ROOT / relative)
    for path in historical_paths:
        add_input(inputs, path)

    managed_process_lifecycle_source_pins: dict[str, dict[str, Any]] = {}
    for relative in MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS:
        path = ROOT / relative
        add_input(inputs, path)
        row = inputs.get(relative)
        if row is None or row.get("path") != relative:
            raise RuntimeError(
                f"managed lifecycle source is not bound in the current input closure: {relative}")
        managed_process_lifecycle_source_pins[relative] = row

    positive_pins = require_runtime_pins(inputs, runtime_inputs)
    for path in files_under(positive_dispatch):
        add_input(inputs, path)
    for path in files_under(positive_evidence):
        add_input(inputs, path)
    for path in files_under(R1_FAILURE_EVIDENCE):
        add_input(inputs, path)
    add_input(inputs, R1_TIMEOUT_RECEIPT)
    add_input(inputs, R1_SOURCE_PROTOCOL)
    attempt7_interruption = build_attempt7_interruption_record()
    for path in files_under(ATTEMPT7_ARCHIVE_LEAF):
        add_input(inputs, path)
    add_input(inputs, ATTEMPT7_COVERAGE)
    for path in files_under(ATTEMPT9C_ARCHIVE_LEAF):
        add_input(inputs, path)
    for path in ATTEMPT9C_FAILURE_FILES.values():
        add_input(inputs, path)
    for path in ATTEMPT10_FAILURE_FILES.values():
        add_input(inputs, path)
    test_root_relative = source_provider.logical_path(TEST_ROOT)
    superseded_map_relatives = {
        source_provider.logical_path(path)
        for path in R18_SUPERSEDED_MAP_EXPERIMENT_FILES
    }
    historical_attempt3_relative = source_provider.logical_path(
        HISTORICAL_ATTEMPT3_LAUNCHER)
    skipped_static_directories = {
        "independent_static_r2", "independent_static_r3",
        "independent_static_r4", "independent_static_r5",
        "independent_static_r6", "independent_static_r7",
        "independent_static_r8", "independent_static_r9",
        "independent_static_r10", "independent_static_r11",
        "independent_static_r12", "independent_static_r13",
        "independent_static_r14",
    }
    for path in files_under(TEST_ROOT):
        relative = source_provider.logical_path(path)
        if relative in historical_path_set:
            continue
        relative_parts = Path(relative).parts
        if "__pycache__" in relative_parts:
            continue
        if relative in superseded_map_relatives:
            continue
        if any(relative.startswith(f"{test_root_relative}/{name}/") or
               relative == f"{test_root_relative}/{name}"
               for name in skipped_static_directories):
            continue
        if relative == historical_attempt3_relative:
            continue
        add_input(inputs, path)
    add_input(inputs, coverage_path)
    for path in (OLD_SUITE, PROJECTION_SUITE, T1_MANIFEST, V3_QUALIFICATION,
                 *ACTIVE_GUIDANCE):
        add_input(inputs, path)
    for path in (R23_TABLE, R23_SUPERVISOR, R23_TEST_SUITE):
        add_input(inputs, path)
    r20_host_smoke = build_r20_host_smoke_receipt(inputs)
    r20_host_smoke_failure_lineage = \
        build_r20_host_smoke_failure_lineage(inputs)
    r20_runs_only_path_gate_delta = \
        build_r20_runs_only_path_gate_delta(inputs)
    for path in R17_BASELINE_GATE_FAILURE_FILES.values():
        add_input(inputs, path)
    r18_retry1_files = list(files_under(R18_RETRY1_FAILURE_LEAF))
    for path in r18_retry1_files:
        add_input(inputs, path)
    r18_retry1_qa = load_object(R18_RETRY1_FAILURE_LEAF / "static_qa.json")
    r18_retry1_exit = load_object(R18_RETRY1_FAILURE_LEAF / "freezer_exit_code.json")
    if r18_retry1_exit.get("exit_code") != 1 or \
            r18_retry1_exit.get("julia_started") is not False or \
            r18_retry1_qa.get("status") != "fail" or \
            r18_retry1_qa.get("julia_executed") is not False or \
            r18_retry1_qa.get("failure", {}).get("message") != \
                "R23 natural child did not complete with the exact terminal-exit-race receipt":
        raise RuntimeError("R18 retry1 failed static QA lineage drift")
    r18_retry1_lineage = {
        "schema": "vnext-t2-r18-retry1-static-qa-failure-r1",
        "leaf": R18_RETRY1_FAILURE_LEAF.relative_to(ROOT).as_posix(),
        "files": {path.relative_to(R18_RETRY1_FAILURE_LEAF).as_posix():
                  receipt(path) for path in r18_retry1_files},
        "freezer_exit_code": 1,
        "static_qa_status": "fail",
        "failure_message": r18_retry1_qa["failure"]["message"],
        "julia_started": False, "formal_t2_accepted": False,
    }
    r19_retry1_files = list(files_under(R19_RETRY1_PROJECTION_FAILURE_LEAF))
    for path in r19_retry1_files:
        add_input(inputs, path)
    r19_retry1_protocol = load_object(
        R19_RETRY1_PROJECTION_FAILURE_LEAF / "protocol.json")
    r19_retry1_phase = load_object(
        R19_RETRY1_PROJECTION_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json")
    r19_retry1_stderr_path = (
        R19_RETRY1_PROJECTION_FAILURE_LEAF /
        "projection24_reuse_preflight/stderr.raw")
    r19_retry1_stderr = r19_retry1_stderr_path.read_text(
        encoding="utf-8", errors="replace")
    r19_retry1_protocol_path = (
        R19_RETRY1_PROJECTION_FAILURE_LEAF / "protocol.json")
    r19_retry1_expected_error = (
        'RuntimeError("projection reuse protocol schema mismatch")')
    if r19_retry1_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r9" or \
            r19_retry1_protocol.get("formal_t2_accepted") is not False or \
            r19_retry1_phase.get("schema") != \
                "vnext-t2-projection24-python-preflight-phase-r1" or \
            r19_retry1_phase.get("exit_code") != 1 or \
            r19_retry1_phase.get("status") != "fail" or \
            r19_retry1_phase.get("stop_reason") != "natural_exit" or \
            r19_retry1_phase.get("julia_started") is not False or \
            r19_retry1_phase.get("formal_t2_accepted") is not False or \
            r19_retry1_phase.get("stdout", {}).get("bytes") != 0 or \
            r19_retry1_phase.get("command_argv", [None])[2] != \
                str(R10_PROJECTION_REUSE_VALIDATOR.resolve()) or \
            r19_retry1_phase.get("command_argv", [None, None, None, None])[3] != \
                str(r19_retry1_protocol_path.resolve()) or \
            r19_retry1_expected_error not in r19_retry1_stderr:
        raise RuntimeError("R19 retry1 projection-schema failure evidence drift")
    r19_retry1_projection_failure_lineage = {
        "schema": "vnext-t2-r19-retry1-projection-schema-failure-r1",
        "leaf": R19_RETRY1_PROJECTION_FAILURE_LEAF.relative_to(ROOT).as_posix(),
        "files": {path.relative_to(
            R19_RETRY1_PROJECTION_FAILURE_LEAF).as_posix(): receipt(path)
            for path in r19_retry1_files},
        "protocol_schema_at_failure": r19_retry1_protocol["schema"],
        "projection_validator": receipt(R10_PROJECTION_REUSE_VALIDATOR),
        "phase": receipt(R19_RETRY1_PROJECTION_FAILURE_LEAF /
                         "projection24_reuse_preflight/phase.json"),
        "exit_code": 1,
        "stop_reason": "natural_exit",
        "failure_message": r19_retry1_expected_error,
        "stdout_bytes": 0,
        "julia_started": False,
        "formal_t2_accepted": False,
    }
    r19_retry2_files = list(files_under(R19_RETRY2_STATIC_QA_FAILURE_LEAF))
    for path in r19_retry2_files:
        add_input(inputs, path)
    r19_retry2_protocol = load_object(
        R19_RETRY2_STATIC_QA_FAILURE_LEAF / "protocol.json")
    r19_retry2_qa = load_object(
        R19_RETRY2_STATIC_QA_FAILURE_LEAF / "static_qa.json")
    r19_retry2_phase = load_object(
        R19_RETRY2_STATIC_QA_FAILURE_LEAF /
        "projection24_reuse_preflight/phase.json")
    r19_retry2_expected_error = \
        "R19 retry1 projection failure phase does not match its pinned cause"
    r19_retry2_qa_stderr = (
        R19_RETRY2_STATIC_QA_FAILURE_LEAF / "static_qa.stderr.raw").read_text(
            encoding="utf-8", errors="replace")
    if r19_retry2_protocol.get("schema") != \
            "vnext-t2-independent-negative-protocol-r8" or \
            r19_retry2_qa.get("status") != "fail" or \
            r19_retry2_qa.get("failure", {}).get("message") != \
                r19_retry2_expected_error or \
            r19_retry2_qa.get("julia_executed") is not False or \
            r19_retry2_qa.get("formal_t2_accepted") is not False or \
            r19_retry2_phase.get("exit_code") != 0 or \
            r19_retry2_phase.get("julia_started") is not False or \
            r19_retry2_phase.get("pass_marker_observed") is not True or \
            r19_retry2_phase.get("formal_t2_accepted") is not False or \
            r19_retry2_expected_error not in r19_retry2_qa_stderr:
        raise RuntimeError("R19 retry2 static-QA failure evidence drift")
    r19_retry2_static_failure_lineage = {
        "schema": "vnext-t2-r19-retry2-static-qa-failure-r1",
        "leaf": R19_RETRY2_STATIC_QA_FAILURE_LEAF.relative_to(ROOT).as_posix(),
        "files": {path.relative_to(
            R19_RETRY2_STATIC_QA_FAILURE_LEAF).as_posix(): receipt(path)
            for path in r19_retry2_files},
        "protocol_schema": r19_retry2_protocol["schema"],
        "static_qa_status": "fail",
        "static_qa_failure_message": r19_retry2_expected_error,
        "projection24_preflight_exit_code": 0,
        "projection24_pass_marker_observed": True,
        "julia_started": False,
        "formal_t2_accepted": False,
    }
    r18_predicate_no_go_lineage = build_r18_predicate_probe_no_go_lineage(inputs)
    r18_r19_snapshot_predicate_delta = \
        build_controller_r18_r19_snapshot_predicate_delta(inputs)
    r19_r20_process_sample_delta = \
        build_controller_r19_r20_process_sample_delta(inputs)
    r21_tracked_exit_test = build_r21_tracked_exit_test_receipt(inputs)
    r20_r21_tracked_exit_delta = build_controller_r20_r21_tracked_exit_delta(
        inputs, r21_tracked_exit_test)
    r22_pre_tree_test = build_r22_pre_tree_python_test_receipt(inputs)
    r21_r22_pre_tree_delta = build_controller_r21_r22_pre_tree_delta(
        inputs, r22_pre_tree_test)
    r22_host_smoke = build_r22_windows_host_smoke_receipt(inputs)
    r22_host_smoke_launcher = build_r22_host_smoke_launcher_receipt(
        inputs, r22_host_smoke)
    r22_host_smoke_invocation = build_r22_host_smoke_invocation_receipt(
        inputs, r22_host_smoke_launcher)
    prior_r22_actual_failure = build_prior_r22_actual_failure(inputs)
    controller_r22_r23_membership_growth_delta = \
        build_controller_r22_r23_membership_growth_delta(inputs)
    source_layout_rebase = build_source_layout_rebase(inputs)
    managed_process_lifecycle_controller_delta = \
        build_managed_process_lifecycle_controller_delta(inputs)
    projection_validator_r10_r11_delta = build_projection_reuse_validator_r10_r11_delta(inputs)
    projection_validator_r11_r12_delta = build_projection_reuse_validator_r11_r12_delta(inputs)
    r17_failure_start = load_object(
        R17_BASELINE_GATE_FAILURE_FILES["pipeline_start"])
    r17_failure_final = load_object(
        R17_BASELINE_GATE_FAILURE_FILES["pipeline_final"])
    r17_failure_audit = r17_failure_start.get("baseline_heavy_processes")
    if not isinstance(r17_failure_audit, dict) or \
            r17_failure_audit.get("complete") is not True or \
            any(r17_failure_audit.get(field) != [] for field in
                ("processes", "controller_processes",
                 "native_heavy_identities", "errors")) or \
            r17_failure_final.get("failure", {}).get("message") != \
                "serialized Julia lane occupied" or \
            r17_failure_final.get("phases") != [] or \
            r17_failure_final.get("formal_t2_accepted") is not False:
        raise RuntimeError("R17 baseline-heavy truthiness failure evidence drift")
    r17_baseline_truthiness_failure = {
        "schema": "vnext-t2-r17-baseline-heavy-truthiness-failure-r1",
        "leaf": R17_BASELINE_GATE_FAILURE_LEAF.relative_to(ROOT).as_posix(),
        "pipeline_start": receipt(R17_BASELINE_GATE_FAILURE_FILES["pipeline_start"]),
        "pipeline_final": receipt(R17_BASELINE_GATE_FAILURE_FILES["pipeline_final"]),
        "failure_message": "serialized Julia lane occupied",
        "phases": [], "julia_started": False,
        "failure_class": "complete empty audit dict rejected by dict truthiness",
    }
    r17_host_smoke_retry_lineage = build_r17_host_smoke_retry_lineage(inputs)
    retry8_pid0_failure_basis = build_retry8_pid0_failure_basis(inputs)
    review_receipts = []
    for raw in args.review_input:
        review_path = Path(raw).absolute()
        review_path.relative_to(ROOT)
        for path in files_under(review_path):
            add_input(inputs, path)
            review_receipts.append(receipt(path))
    retry3_no_go_lineage = build_attempt11_retry3_no_go_lineage(inputs)
    retry5_retry6_failure_lineage = build_retry5_retry6_failure_lineage(inputs)
    attempt8_preflight_failure_basis = \
        build_attempt8_preflight_failure_record(inputs)
    attempt9c_interruption_basis = build_attempt9c_interruption_record(inputs)
    attempt9_projection_preflight_failure_basis = \
        build_attempt9_projection_preflight_failure_record(inputs)
    projection_validator_delta = build_projection_validator_r3_r4_delta(inputs)
    projection_validator_r4_r5_delta = \
        build_projection_validator_r4_r5_delta(inputs)
    projection_validator_r5_r6_delta = \
        build_projection_validator_r5_r6_delta(inputs)
    projection_validator_r6_r7_delta = \
        build_projection_validator_r6_r7_delta(inputs)
    attempt9b_static_qa_failure_basis = \
        build_attempt9b_static_qa_failure_record(inputs)
    controller_binding_delta = build_controller_r8_r9_authority_progress_delta(inputs)

    coverage = load_object(coverage_path)
    if coverage.get("schema") != "vnext-t2-independent-negative-coverage-map-r16" or \
            coverage.get("status") != "static_coverage_map_no_julia" or \
            coverage.get("formal_t2_accepted") is not False or \
            coverage.get("successor_assertion_site_count") != 214 or \
            coverage.get("successor_expected_runtime_hit_count") != 622:
        raise RuntimeError("coverage map is not a bounded 214/622 static plan")
    attempt10_preflight_interruption_basis = \
        build_attempt10_preflight_interruption_record(inputs, coverage)
    attempt11_initial_freeze_failure_basis = \
        build_attempt11_initial_freeze_failure_record(inputs)
    attempt11_retry1_static_qa_failure_basis = \
        build_attempt11_retry1_static_qa_failure_record(inputs)
    attempt11_retry2_static_qa_failure_basis = \
        build_attempt11_retry2_static_qa_failure_record(inputs)
    attempt11_retry4_projection_failure_basis = \
        build_attempt11_retry4_projection_schema_failure_record(inputs)
    controller_r9_r10_preflight_delta =         build_controller_r9_r10_preflight_budget_delta(inputs)
    controller_r10_r11_monitor_delta = \
        build_controller_r10_r11_monitor_delta(inputs)
    controller_r11_r12_generation_delta = \
        build_controller_r11_r12_generation_delta(inputs)
    controller_r13_r14_pid0_delta = \
        build_controller_r13_r14_windows_pid0_delta(inputs)
    runtime_plan = coverage["runtime_execution_plan"]
    if len(PHASE_ORDER) != 30 or runtime_plan.get(
            "actual_formal_phase_case_ids") is None:
        raise RuntimeError("r3 phase contract is malformed")
    attempt7_coverage = load_object(ATTEMPT7_COVERAGE)
    case_ids = sorted(row["id"] for row in coverage["successor_cases"])
    site_ids = sorted(row["id"] for row in coverage["successor_assertion_sites"])
    if len(runtime_plan["actual_formal_summary_case_ids"]) != 45 or \
            runtime_plan["expected_unique_case_count"] != 60 or \
            runtime_plan["expected_runtime_case_hit_count"] != 68 or \
            case_ids != sorted(row["id"] for row in
                               attempt7_coverage["successor_cases"]) or \
            site_ids != sorted(row["id"] for row in
                               attempt7_coverage["successor_assertion_sites"]):
        raise RuntimeError("attempt8 formal case/site coverage differs from attempt7")
    relocation_ledger = build_attempt7_relocation_ledger(
        coverage, attempt7_coverage, coverage_path)
    positive_producer = positive_evidence / "producer"
    positive_receipts = {
        "root": positive_evidence.relative_to(ROOT).as_posix(),
        "formal_serial_replay": receipt(positive_final_path),
        "pipeline_final": receipt(positive_pipeline_path),
        "producer_candidate_package": receipt(
            positive_producer / "candidate_package.jls"),
        "producer_candidate_t1_receipt": receipt(
            positive_producer / "candidate_t1_admission_receipt.json"),
        "producer_result": receipt(positive_producer / "t2_result.jls"),
        "producer_run_receipt": receipt(positive_producer / "run_receipt.json"),
        "replay_candidate_package": receipt(
            positive_evidence / "replay/candidate_package.jls"),
        "replay_candidate_t1_receipt": receipt(
            positive_evidence / "replay/candidate_t1_admission_receipt.json"),
        "replay_result": receipt(positive_evidence / "replay/t2_result.jls"),
        "replay_run_receipt": receipt(positive_evidence / "replay/run_receipt.json"),
    }
    candidate_receipt = load_object(
        positive_producer / "candidate_t1_admission_receipt.json")
    parse_julia = sorted(path for path in inputs
                         if path.endswith(".jl") and
                         path not in historical_path_set)
    parse_python = sorted(path for path in inputs
                          if path.endswith(".py") and
                          path not in historical_path_set)
    guidance_pins = {row["path"]: row for row in
                     (receipt(path) for path in ACTIVE_GUIDANCE)}
    protocol = {
        "schema": "vnext-t2-independent-negative-protocol-r10",
        "status": "frozen_static_ready_not_executed",
        "repository_head": EXPECTED_HEAD,
        "inputs": dict(sorted(inputs.items())),
        "input_count": len(inputs),
        "source_layout": source_layout,
        "source_layout_rebase": source_layout_rebase,
        "managed_process_lifecycle_controller_delta":
            managed_process_lifecycle_controller_delta,
        "managed_process_lifecycle_source_pins": dict(sorted(
            managed_process_lifecycle_source_pins.items())),
        "python_cache_exclusion": {
            "schema": "vnext-t2-generated-python-cache-exclusion-r1",
            "status": "excluded_from_current_input_closure_not_cleaned",
            "cleaned": False,
            "excluded_files": cache_exclusions,
            "excluded_file_count": len(cache_exclusions),
            "exclusion_reason": (
                "these two bytecode files were created by a local Python import "
                "preflight; exact cleanup was rejected by tool safety, so they "
                "remain present and are excluded from execution inputs"),
            "freeze_entrypoint": {
                "mode": "direct_script_as_main",
                "path": freezer_script.relative_to(ROOT).as_posix(),
                "argv0_matches_source": True,
                "sys_dont_write_bytecode": sys.dont_write_bytecode,
            },
            "static_qa_direct_argv_prefix": [
                sys.executable, "-B", str(STATIC_QA)],
            "cache_module_import_targets": [],
            "qa_dynamic_import_module_names": [],
        },
        "attempt11_cleanup_receipt": {
            "schema": "vnext-t2-attempt11-owned-temp-cleanup-inventory-r1",
            "status": "pass_no_task_owned_disposable_artifacts",
            "python_commands_used_dash_b": True,
            "task_owned_disposable_paths": [],
            "deleted_paths": [],
            "preserved_preexisting_excluded_cache_files": cache_exclusions,
            "excluded_cache_files_were_cleaned": False,
            "failure_evidence_preserved": True,
            "julia_started": False,
        },
        "excluded_historical_execution_artifacts": [
            receipt(HISTORICAL_ATTEMPT3_LAUNCHER),
        ],
        "historical_execution_artifact_exclusion_reason": (
            "migrated unchanged from attempt3 archive after scope violation; "
            "historical command data, not a current execution dependency"),
        "positive_reuse_input_pins": positive_pins,
        "active_guidance_pins": guidance_pins,
        "julia_parse_paths": parse_julia,
        "julia_parse_file_count": len(parse_julia),
        "python_parse_paths": parse_python,
        "python_parse_file_count": len(parse_python),
        "coverage_map": receipt(coverage_path),
        "coverage_map_schema": coverage["schema"],
        "r20_native_monitor_host_smoke": r20_host_smoke,
        "r20_native_monitor_host_smoke_failure_lineage":
            r20_host_smoke_failure_lineage,
        "controller_r20_runs_only_path_gate_delta":
            r20_runs_only_path_gate_delta,
        "execution_evidence_path_policy": {
            "schema": "vnext-t2-r20-runs-only-execution-path-policy-r1",
            "required_direct_child_root": "runs/UP1-04A-VNEXT-T2",
            "applies_to": [
                "controller.main(--evidence-dir)",
                "controller.main(--resume-authority-from)",
                "controller.verify_authority_resume_ancestry(resume_root)",
            ],
            "direct_child_only": True,
            "rejects_docs_nested_external_and_junctioned_parents": True,
            "freeze_protocol_output_root":
                "runs/UP1-04A-VNEXT-T2",
            "r9_host_smoke_controller_sha256":
                r20_host_smoke["raw_controller_source"]["sha256"],
            "current_controller_sha256":
                r20_host_smoke["current_controller"]["sha256"],
            "r9_host_smoke_is_current_path_gate_test": False,
        },
        "r17_native_monitor_host_smoke_failure_lineage":
            r17_host_smoke_retry_lineage,
        "r17_baseline_heavy_truthiness_failure":
            r17_baseline_truthiness_failure,
        "r18_retry1_static_qa_failure": r18_retry1_lineage,
        "r19_retry1_projection_schema_failure":
            r19_retry1_projection_failure_lineage,
        "r19_retry2_static_qa_failure": r19_retry2_static_failure_lineage,
        "r18_predicate_probe_no_go_lineage": r18_predicate_no_go_lineage,
        "r18_superseded_map_experiment_exclusion": {
            "schema": "vnext-t2-r18-superseded-map-experiment-exclusion-r1",
            "status": "retained_on_disk_not_current_execution_input",
            "cleanup_attempt": "blocked_by_tool_policy",
            "files": [receipt(path) for path in
                      R18_SUPERSEDED_MAP_EXPERIMENT_FILES],
            "not_referenced_by_runtime_command": True,
            "read_only_for_exact_exclusion_rehash": True,
            "current_coverage_map": receipt(coverage_path),
            "current_coverage_map_schema": coverage["schema"],
        },
        "r18_owned_temp_cleanup_receipt": {
            "schema": "vnext-t2-r18-owned-temp-cleanup-r1",
            "status": "blocked_by_tool_policy_retained_and_exactly_excluded",
            "cleanup_command_attempted": True,
            "cleanup_command_exit": "tool_rejected_before_execution",
            "deleted": False,
            "files": [receipt(path) for path in
                      R18_SUPERSEDED_MAP_EXPERIMENT_FILES],
            "failure_evidence_preserved": True,
            "julia_started": False,
        },
        "controller_r17_r18_preflight_delta": {
            "baseline_and_final_audit_share_helper": True,
            "helper": "verify_baseline_heavy_processes_clear",
            "required_empty_fields": ["processes", "controller_processes",
                                      "native_heavy_identities", "errors"],
            "requires_complete_true": True,
            "formal_coverage_or_threshold_change": False,
            "repaired_retry7_failure": receipt(
                R17_BASELINE_GATE_FAILURE_FILES["pipeline_final"]),
        },
        "controller_r18_r19_snapshot_predicate_delta":
            r18_r19_snapshot_predicate_delta,
        "controller_r19_r20_process_sample_delta":
            r19_r20_process_sample_delta,
        "controller_r20_r21_tracked_sample_exit_delta":
            r20_r21_tracked_exit_delta,
        "r21_tracked_sample_exit_python_controls": r21_tracked_exit_test,
        "controller_r21_r22_pre_tree_tracked_exit_delta":
            r21_r22_pre_tree_delta,
        "r22_pre_tree_tracked_exit_python_controls": r22_pre_tree_test,
        "r22_windows_host_smoke": r22_host_smoke,
        "r22_windows_host_smoke_launcher": r22_host_smoke_launcher,
        "r22_windows_host_smoke_invocation": r22_host_smoke_invocation,
        "controller_r22_r23_membership_growth_delta":
            controller_r22_r23_membership_growth_delta,
        "prior_r22_actual_failure": prior_r22_actual_failure,
        "coverage_assertion_hit_plan":
            coverage["successor_assertion_runtime_hit_plan"],
        "ast_inventory_plan": coverage["ast_inventory_plan"],
        "versioned_product_repair_regression":
            coverage["versioned_product_repair_regression"],
        "runtime_execution_plan": runtime_plan,
        "projection24_reuse_validator_path":
            PROJECTION_REUSE_VALIDATOR.relative_to(ROOT).as_posix(),
        "projection24_reuse_validator_r10_r11_delta":
            projection_validator_r10_r11_delta,
        "projection24_reuse_validator_r11_r12_delta":
            projection_validator_r11_r12_delta["r11_r12_delta"],
        "projection24_reuse_validator_r12_source_layout_adapter":
            projection_validator_r11_r12_delta["r12_source_layout_adapter"],
        "projection24_reuse": build_projection24_reuse_plan(inputs),
        "positive_dispatch": {
            "root": positive_dispatch.relative_to(ROOT).as_posix(),
            "protocol": receipt(positive_protocol_path),
            "runtime_inputs": receipt(runtime_inputs_path),
            "dispatch": receipt(positive_dispatch_path),
            "command": receipt(positive_command_path),
        },
        "positive_evidence": positive_receipts,
        "positive_candidate_driver_version":
            candidate_receipt.get("producer_version"),
        "authorities": {
            "formal_t1_manifest": receipt(T1_MANIFEST),
            "v3_software_qualification": receipt(V3_QUALIFICATION),
        },
        "r1_failure_basis": {
            "formal_negative_pipeline_final": receipt(
                R1_FAILURE_EVIDENCE / "pipeline_final.json"),
            "timeout_execution_receipt": receipt(R1_TIMEOUT_RECEIPT),
            "r1_actual_matrix_exit_code": 15,
            "r1_actual_matrix_stop_reason": "phase_wall_timeout",
            "r1_actual_matrix_wall_seconds": 300.3165626000009,
            "r1_actual_observations_present": False,
            "r1_executed_case_hit_count": 0,
            "r1_projection24_assertion_sites_completed": 24,
        },
        "attempt7_interruption_basis": attempt7_interruption,
        "attempt9c_authority_interruption_basis": attempt9c_interruption_basis,
        "attempt10_preflight_interruption_basis":
            attempt10_preflight_interruption_basis,
        "attempt11_initial_freeze_failure_basis":
            attempt11_initial_freeze_failure_basis,
        "attempt11_retry1_static_qa_failure_basis":
            attempt11_retry1_static_qa_failure_basis,
        "attempt11_retry2_static_qa_failure_basis":
            attempt11_retry2_static_qa_failure_basis,
        "attempt11_retry4_projection_schema_failure_basis":
            attempt11_retry4_projection_failure_basis,
        "attempt11_retry3_final_no_go_lineage": retry3_no_go_lineage,
        "attempt8_preflight_failure_basis": attempt8_preflight_failure_basis,
        "attempt9_projection_preflight_failure_basis":
            attempt9_projection_preflight_failure_basis,
        "attempt9b_static_qa_failure_basis":
            attempt9b_static_qa_failure_basis,
        "projection_validator_r3_r4_delta": projection_validator_delta,
        "projection_validator_r4_r5_delta":
            projection_validator_r4_r5_delta,
        "projection_validator_r5_r6_delta":
            projection_validator_r5_r6_delta,
        "projection_validator_r6_r7_delta":
            projection_validator_r6_r7_delta,
        "controller_r8_r9_authority_progress_delta": controller_binding_delta,
        "controller_r9_r10_preflight_budget_delta":
            controller_r9_r10_preflight_delta,
        "controller_r10_r11_fail_closed_monitor_delta":
            controller_r10_r11_monitor_delta,
        "controller_r11_r12_launch_generation_delta":
            controller_r11_r12_generation_delta,
        "controller_r13_r14_windows_pid0_delta":
            controller_r13_r14_pid0_delta,
        "attempt11_retry5_retry6_static_failure_lineage":
            retry5_retry6_failure_lineage,
        "attempt11_retry8_windows_pid0_failure_basis":
            retry8_pid0_failure_basis,
        "controller_child_script_plan":
            build_controller_child_script_plan(),
        "attempt7_coverage_comparison": {
            "attempt7_coverage_map": receipt(ATTEMPT7_COVERAGE),
            "case_count": len(case_ids), "formal_case_count": 45,
            "runtime_unique_case_count": runtime_plan[
                "expected_unique_case_count"],
            "runtime_case_hit_count": runtime_plan[
                "expected_runtime_case_hit_count"],
            "successor_assertion_site_count":
                coverage["successor_assertion_site_count"],
            "successor_expected_runtime_hit_count":
                coverage["successor_expected_runtime_hit_count"],
            "case_id_set_sha256": sha256_bytes(json.dumps(
                case_ids, separators=(",", ":")).encode("utf-8")),
            "assertion_site_id_set_sha256": sha256_bytes(json.dumps(
                site_ids, separators=(",", ":")).encode("utf-8")),
            "semantic_case_ids_and_site_ids_equal": True,
            "site_assertion_text_multiplicity_and_phase_hits_equal": True,
            "full_path_line_map_byte_equal": False,
            "path_line_relocation_ledger": relocation_ledger,
        },
        "independent_review_inputs": review_receipts,
        "driver_path": DRIVER.relative_to(ROOT).as_posix(),
        "controller_path": CONTROLLER.relative_to(ROOT).as_posix(),
        "phase_order": PHASE_ORDER,
        "expected_phase_count": len(PHASE_ORDER),
        "resource_gates": {
            "phase_wall_seconds": 480,
            "phase_wall_timeout_overrides": {
                "actual_formal_preflight": 600},
            "authority_phase_wall_seconds": 2400,
            "authority_case_wall_seconds": 2400,
            "process_tree_working_set_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
        },
        "controller_wall_budget_summary": {
            "schema": "vnext-t2-controller-summed-phase-wall-budget-r1",
            "phase_count": 30,
            "ordinary_phase_seconds": 480,
            "preflight_phase_seconds": 600,
            "authority_phase_seconds": 2400,
            "summed_phase_wall_cap_seconds": 16440,
            "sum_formula": "30*480 + (600-480) + (2400-480)",
            "single_end_to_end_controller_timeout_enforced": False,
            "excludes_setup_interphase_and_finalization_overhead": True,
        },
        "process_cleanup_contract": {
            "schema": "vnext-t2-process-monitor-cleanup-contract-r1",
            "timeout_termination_function": "kill_tree",
            "wait_procs_timeout_seconds": 5,
            "natural_exit_requires_root_exit_confirmation": True,
            "natural_exit_requires_complete_final_tree_audit": True,
            "natural_exit_requires_root_identity_absent": True,
            "natural_exit_requires_complete_empty_residual_audit": True,
            "incomplete_termination_or_audit": "typed_monitor_incomplete_nonzero_no_acceptance",
            "nonempty_residual_processes": "fail_closed",
            "julia_executed_by_freezer": False,
        },
        "julia_executable": str(julia_executable),
        "planned_evidence_directory": planned.relative_to(ROOT).as_posix(),
        "planned_evidence_directory_absent": True,
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
        "actual_source_site_hits": "pending_julia_execution",
        "actual_model_attestation": "unavailable",
        "baseline_diagnostic_marker_contract": [
            "post_consumer_require_baseline.begin",
            "post_consumer_require_baseline.end",
            "baseline_second_up2_validate_input.begin",
            "baseline_second_up2_validate_input.end",
            "baseline_context_construction.begin",
            "baseline_context_construction.end",
            "baseline_context_serialization.begin",
            "baseline_context_serialization.end",
            "baseline_summary_complete",
        ],
        "actual_formal_shard_argv_contract": {
            "schema": "vnext-t2-formal-shard-argv-contract-r1",
            "driver_path": DRIVER.relative_to(ROOT).as_posix(),
            "controller_builder": "build_actual_formal_shard_command",
            "expected_driver_argument_count": 16,
            "coverage_map_path_driver_argv_index_1_based": 15,
            "coverage_map_sha256_driver_argv_index_1_based": 16,
            "shard_modes": ["preflight", "fault_n10", "t1_handoff",
                *["authority-case:" + case_id for case_id in
                  ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE",
                   "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
                   "ACTUAL_TYPED_ABSENCE", "ACTUAL_FORMAL_GATE_REJECTION",
                   "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
                   "ACTUAL_DUPLICATE_INVOCATION"]]],
            "static_actual_command_builder_test": True,
        },
        "authority_case_execution_contract": {
            "schema": "vnext-t2-authority-case-resumable-execution-r2",
            "phase": "actual_formal_authority",
            "case_order": ["PARENT_STALE", "PARENT_FOREIGN", "G3_STALE",
                "G3_FOREIGN", "ACTUAL_FOREIGN_SCENARIO",
                "ACTUAL_TYPED_ABSENCE", "ACTUAL_FORMAL_GATE_REJECTION",
                "ACTUAL_FORMAL_GATE_REJECTION_NO_PRIOR",
                "ACTUAL_DUPLICATE_INVOCATION"],
            "case_mode_template": "authority-case:<case_id>",
            "driver_argument_count": 16,
            "coverage_map_path_argument_index_1_based": 15,
            "coverage_map_sha256_argument_index_1_based": 16,
            "per_case_wall_seconds": 2400,
            "phase_wall_seconds": 2400,
            "effective_child_timeout_policy": "min(per_case_cap, remaining_invocation_budget)",
            "per_assertion_progress_event_schema":
                "vnext-t2-authority-case-progress-r3",
            "per_assertion_events_are_flushed_after_test_record": True,
            "partial_record_event_prefix_is_observational_only": True,
            "resume_skips_only_natural_exit_zero_complete_child_receipts": True,
            "working_set_bytes": 2_147_483_648,
            "source_site_count_zero_filled_per_case": 175,
            "phase_nonzero_site_count": 75,
            "phase_expected_hit_count": 118,
            "expected_case_hit_counts_static_plan": {
                case_id: sum(coverage["successor_assertion_runtime_hit_plan"]
                    ["authority_case_hit_plan"]["case_site_hit_counts"][case_id]
                    .values())
                for case_id in coverage["successor_assertion_runtime_hit_plan"]
                    ["authority_case_hit_plan"]["case_order"]},
            "context_transport_source_site_count": 23,
            "context_transport_site_ids": coverage[
                "successor_assertion_runtime_hit_plan"][
                    "authority_case_hit_plan"]["context_transport_site_ids"],
            "context_transport_formal_phase_order": [
                "actual_formal_preflight", "actual_formal_authority",
                "actual_formal_fault_n10", "actual_formal_t1_handoff"],
            "context_transport_hits_per_site_per_formal_phase_static_plan": 1,
            "context_transport_execution_count_per_formal_phase": 1,
            "context_transport_total_hits_across_four_formal_phases_static_plan": 92,
            "context_transport_case_id": "PARENT_STALE",
            "context_transport_hits_in_authority_case_static_plan": 23,
            "parent_stale_case_total_hits_static_plan": 38,
            "case_site_hits_are_observed_from_test_record": True,
            "partial_or_unterminated_case_receipts_joinable": False,
            "resume_requires_exact_parent_pipeline_phase_and_child_receipt_ancestry": True,
            "partial_case_receipts_joinable": False,
            "resume_policy": "reuse_only_natural_exit_zero_ancestry_and_actual_hit_receipts_with_exact_current_protocol_inputs_and_case_ids",
            "formal_t2_accepted": False,
        },
        "preflight_phase_budget_change": {
            "schema": "vnext-t2-preflight-phase-wall-budget-delta-r1",
            "prior_phase_seconds": 480,
            "current_preflight_seconds": 600,
            "only_phase_override": "actual_formal_preflight",
            "other_formal_phases_seconds": 480,
            "attempt10_observed_complete_cases": 16,
            "attempt10_planned_cases": 18,
            "attempt10_remaining_case_ids": ["FEEDBACK_STALE", "FEEDBACK_FOREIGN"],
            "attempt10_preparation_seconds": 183.662744,
            "attempt10_phase_seconds": 480.170702,
            "estimated_remaining_two_case_seconds_at_observed_average": 37.063495,
            "estimated_extra_wall_margin_after_remaining_cases_seconds": 82.7658,
            "estimate_is_guarantee": False,
            "attempt10_partial_cases_reused": False,
            "failed_attempt11_partial_cases_credit": 0,
            "coverage_thresholds_changed": False,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "formal_t2_accepted": False,
        },
        "authority_case_budget_change": {
            "schema": "vnext-t2-authority-case-budget-delta-r1",
            "prior_case_timeout_seconds": 1200,
            "new_case_timeout_seconds": 2400,
            "authority_invocation_timeout_seconds": 2400,
            "effective_child_timeout_policy": "min(per_case_cap, remaining_invocation_budget)",
            "rationale": "attempt9c did not complete a case before the 480s phase timeout, so the old 1200s per-case cap was not evidence-backed; 2400s lets one case use the full bounded invocation while later cases continue through exact resume",
            "coverage_thresholds_changed": False,
            "working_set_limit_bytes": 2_147_483_648,
            "julia_threads": 1,
            "openblas_threads": 1,
            "formal_t2_accepted": False,
        },
    }
    source_provider.verify_protocol_layout(protocol)
    write_json_new(output / "protocol.json", protocol)
    protocol_path = output / "protocol.json"
    protocol_receipt = receipt(protocol_path)
    projection_preflight_phase = run_projection24_preflight(
        output, protocol_path)
    command_argv = [
        sys.executable, "-B", str(CONTROLLER), "--julia", str(julia_executable),
        "--project", str(ROOT), "--protocol", str(protocol_path),
        "--protocol-sha256", protocol_receipt["sha256"],
        "--positive-evidence", str(positive_evidence),
        "--positive-final-sha256",
        positive_receipts["formal_serial_replay"]["sha256"],
        "--positive-pipeline-final-sha256", positive_receipts["pipeline_final"]["sha256"],
        "--evidence-dir", str(planned), "--phase-timeout", "480",
        "--authority-phase-timeout", "2400",
        "--authority-case-timeout", "2400",
        "--working-set-limit", "2147483648",
    ]
    command_path = output / "command_argv.json"
    write_json_new(command_path, {
        "schema": "vnext-t2-independent-negative-command-argv-r6",
        "kind": "non_executable_command_data",
        "working_directory": str(ROOT),
        "argv": command_argv,
        "environment": {"PYTHONDONTWRITEBYTECODE": "1",
                        "JULIA_NUM_THREADS": "1",
                        "OPENBLAS_NUM_THREADS": "1"},
        "julia_started": False,
        "formal_t2_accepted": False,
    })
    dispatch = {
        "schema": "vnext-t2-independent-negative-dispatch-r6",
        "status": "frozen_static_ready_not_executed",
        "repository_head": EXPECTED_HEAD,
        "protocol": protocol_receipt,
        "command": receipt(command_path),
        "command_argv": command_argv,
        "environment": {"PYTHONDONTWRITEBYTECODE": "1",
                        "JULIA_NUM_THREADS": "1",
                        "OPENBLAS_NUM_THREADS": "1"},
        "positive_evidence": positive_receipts,
        "projection24_reuse_preflight": projection_preflight_phase,
        "attempt9b_static_qa_failure_basis":
            attempt9b_static_qa_failure_basis,
        "phase_order": PHASE_ORDER,
        "phase_count": len(PHASE_ORDER),
        "resource_gates": protocol["resource_gates"],
        "expected_unique_case_count": runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count": runtime_plan[
            "expected_runtime_case_hit_count"],
        "planned_evidence_directory": planned.relative_to(ROOT).as_posix(),
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "physical_acceptance": False,
        "julia_lane_granted": False,
        "julia_started": False,
        "actual_source_site_hits": "pending_julia_execution",
        "actual_model_attestation": "unavailable",
    }
    dispatch_path = output / "dispatch.json"
    write_json_new(dispatch_path, dispatch)

    static_report_path = output / "static_qa.json"
    static_command = [
        sys.executable, "-B", str(STATIC_QA), "--protocol", str(protocol_path),
        "--protocol-sha256", protocol_receipt["sha256"],
        "--dispatch", str(dispatch_path), "--command", str(command_path),
        "--report", str(static_report_path),
    ]
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(static_command, cwd=ROOT, env=env,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (output / "static_qa.stdout.raw").write_bytes(result.stdout)
    (output / "static_qa.stderr.raw").write_bytes(result.stderr)
    if result.returncode != 0:
        raise RuntimeError(f"R23 Python static QA failed: exit={result.returncode}")
    cache_exclusions_after_qa = generated_python_cache_exclusions()
    if cache_exclusions_after_qa != cache_exclusions:
        raise RuntimeError("Python cache exclusion inventory changed during QA")
    snapshot = {
        "schema": "vnext-t2-independent-negative-freeze-snapshot-r6",
        "status": "pass", "repository_head": EXPECTED_HEAD,
        "protocol": protocol_receipt,
        "dispatch": receipt(dispatch_path), "command": receipt(command_path),
        "static_qa": receipt(static_report_path),
        "static_qa_stdout": receipt(output / "static_qa.stdout.raw"),
        "static_qa_stderr": receipt(output / "static_qa.stderr.raw"),
        "projection24_reuse_preflight": projection_preflight_phase,
        "projection24_reuse_receipt": receipt(
            output / "projection24_reuse_preflight/reuse_receipt.json"),
        "projection24_reuse_stdout": receipt(
            output / "projection24_reuse_preflight/stdout.raw"),
        "projection24_reuse_stderr": receipt(
            output / "projection24_reuse_preflight/stderr.raw"),
        "coverage_map": receipt(coverage_path),
        "positive_evidence": positive_receipts,
        "python_cache_exclusion": {
            "status": "excluded_not_cleaned_and_stable_across_qa",
            "cleaned": False,
            "before_qa": cache_exclusions,
            "after_qa": cache_exclusions_after_qa,
        },
        "input_count": len(inputs),
        "projection24_r1_input_intersection_count":
            protocol["projection24_reuse"]["r1_input_intersection_count"],
        "projection24_excluded_r1_input_count":
            protocol["projection24_reuse"]["excluded_r1_input_count"],
        "projection24_dependency_subset_count":
            protocol["projection24_reuse"]["dependency_subset_count"],
        "positive_r3_input_pin_count": len(positive_pins),
        "julia_parse_file_count_not_executed": len(parse_julia),
        "python_parse_file_count": len(parse_python),
        "expected_phase_count": len(PHASE_ORDER),
        "expected_unique_case_count": runtime_plan["expected_unique_case_count"],
        "expected_runtime_case_hit_count":
            runtime_plan["expected_runtime_case_hit_count"],
        "successor_assertion_site_count_static_plan": 214,
        "successor_runtime_hit_count_static_plan": 622,
        "formal_t2_accepted": False,
        "julia_started": False,
        "actual_model_attestation": "unavailable",
    }
    write_json_new(output / "freeze_snapshot.json", snapshot)
    print(json.dumps({
        "status": "pass", "protocol": protocol_receipt,
        "coverage_map": receipt(coverage_path),
        "static_qa": receipt(static_report_path),
        "input_count": len(inputs),
        "positive_r3_input_pin_count": len(positive_pins),
        "phase_count": len(PHASE_ORDER),
        "julia_started": False, "formal_t2_accepted": False,
    }, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
