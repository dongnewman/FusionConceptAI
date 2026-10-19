"""Root-dispatched native G1/G2 compiler -> Gridap consumer supervisor (R30).

This private successor preserves the R29 stage chain and runtime limits while
reading the pinned parse manifest from the frozen ZIP through the R30 provider.
It never restores ZIP members into the checkout. Importing this module never
launches Julia; dispatch still requires an explicit pinned invocation.
"""

from __future__ import annotations

import hashlib
import json
import math
import msvcrt
import os
import copy
import secrets
import struct
import threading
import subprocess
import sys
import time
import types
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
REL_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r30_v1.py"
REL_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r30_v1_tests.py"
REL_LEGACY_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r28_v1.py"
REL_VERIFIER = "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r30_v1.py"
REL_INPUT_PROVIDER = "test/RuntimeV4/NativeG1G2DiffusionV1/pinned_zip_input_provider_r30_v1.py"
REL_PARSE_CONSUMER = "test/RuntimeV4/NativeG1G2DiffusionV1/parse_manifest_r30_stdin_v1.jl"
REL_PROTOCOL_BUILDER = "test/RuntimeV4/NativeG1G2DiffusionV1/build_protocol_r30_v1.py"
REL_R29_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r29_v1.py"
REL_R29_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r29_v1.py"
REL_R29_VERIFIER = "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r29_v1.py"
REL_R23_TABLE = "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
REL_R23_SUPERVISOR = "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
REL_LIFECYCLE_CORE = "tools/execution/windows_process_lifecycle.py"
REL_MANAGED_CLIENT = "src/GenomeV5/Integration/ManagedExternalProcessV1.jl"
REL_NATIVE_GIT_COMPAT = "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"
REL_PROJECT = "Project.toml"
REL_G1_FACTORY = "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl"
REL_G2_FACTORY = "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl"
REL_G3_FACTORY = "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl"
REL_T0_TEST = "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"
REL_FOCUSED = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl"
REL_PARSE_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/parse_manifest.tsv"
)
REL_PROTOCOL = "runs/NativeG1G2DiffusionV1/managed_lifecycle_refreeze_root_20260928_r1/protocol.json"
REL_R29_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r29_v1/protocol.json"
)
R29_PROTOCOL_PIN = {
    "path": REL_R29_PROTOCOL,
    "bytes": 78155,
    "sha256": "abab03601790bf7e095d19fcbca53426b353c662b6c0d4693c519fd79541dc8a",
}
REL_OUTPUT = "runs/NativeG1G2DiffusionV1/managed_lifecycle_formal_root_20260927_r1"
R30_ARCHIVE_PATH = r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\precleanup_docs_runs_tmp.zip"
R30_ARCHIVE_BYTES = 472888641
R30_ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
R30_READINESS_PIN = {
    "path": "runs/NativeG1G2DiffusionV1/r30_manifest_readiness_20260926_r1/archive_window_receipt_r1.json",
    "bytes": 104099,
    "sha256": "fb7fc3abb9873933448afb2fe1087e4922d04fd9d6f2e91ad5467ca822108c19",
}
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

SCHEMA = "native-g1g2-gridap-consumer-r30-protocol-v1"
SUMMARY_SCHEMA = "native-g1g2-gridap-consumer-r30-summary-v1"
RSS_LIMIT_BYTES = 2_147_483_648
SAMPLE_INTERVAL_SECONDS = 0.2
WALL_SECONDS_PER_STAGE = 480.0
JULIA_HEAP_HINT = "1G"
COMPILER_MODE = "--compile=min"
STAGES = ("parse_all", "primary", "fresh_replay")
PARSE_REBINDING_MARKER = (
    "NG12_PARSE_REBINDING status=pass manifest_entries=108 original_bytes_verified=4 "
    "original_sources_parsed=0 current_sources_parsed=4 total_files=110"
)
CURRENT_INPUT_REBINDING_PATHS = (
    REL_PROJECT, REL_G1_FACTORY, REL_G2_FACTORY, REL_G3_FACTORY, REL_T0_TEST,
    REL_R23_SUPERVISOR,
)
EXPECTED_CURRENT_INPUT_PINS = {
    REL_PROJECT: {"path": REL_PROJECT, "bytes": 660,
                  "sha256": "fa092ec89dd3c01d69d85cc4bce0e98712ad523dd0a5702eebbe2403255e4f21"},
    REL_G1_FACTORY: {"path": REL_G1_FACTORY, "bytes": 31853,
                     "sha256": "1acf9b7a05891f2ce030da147be7ceb1535f7dbc85f23ceb5d83527f1c2ead55"},
    REL_G2_FACTORY: {"path": REL_G2_FACTORY, "bytes": 28115,
                     "sha256": "83a9c517849a96fd2fadcd4f4a2a13d76fb13df726de65a8f792bf26c247d428"},
    REL_G3_FACTORY: {"path": REL_G3_FACTORY, "bytes": 35876,
                     "sha256": "98bb0f8c97f1ee5638adf6c690de9963a5d91a69fd5e3aca278cdadee8a79f8c"},
    REL_T0_TEST: {"path": REL_T0_TEST, "bytes": 77595,
                  "sha256": "c40e5b71c4cb111359f0a436bf5b5092098649b68dc27e27f70e443d080d138a"},
    REL_R23_SUPERVISOR: {"path": REL_R23_SUPERVISOR, "bytes": 53583,
                         "sha256": "b63c56f2a3100e280e70bb484ba68b67adcfe0cb79a56bb9d7ea4ba5105f2084"},
}
EXPECTED_CURRENT_ORIGINAL_PINS = {
    REL_PROJECT: {"path": REL_PROJECT, "bytes": 611,
                  "sha256": "e923c66b2d2ea42e79bec67efd7ee1f100ae092897363b4d49ed58984058ff4e"},
    REL_G1_FACTORY: {"path": REL_G1_FACTORY, "bytes": 31396,
                     "sha256": "de5a0d14d71c02244df6344c1a339a56d3dc051f115d975a4072a260d0204bf2"},
    REL_G2_FACTORY: {"path": REL_G2_FACTORY, "bytes": 27640,
                     "sha256": "2e15b97676e8cef51af62c47f83f0bce061e98366e42d3d68bb2a120876436fc"},
    REL_G3_FACTORY: {"path": REL_G3_FACTORY, "bytes": 35485,
                     "sha256": "d07805ce5b708be33232fccd25fd491efb4d8a05c6320ccf4b274ef4644b05e"},
    REL_T0_TEST: {"path": REL_T0_TEST, "bytes": 76191,
                  "sha256": "b1c355c94467c2469fff724c4d02134e9a17ac245b9cc674358393a31864814b"},
    REL_R23_SUPERVISOR: {"path": REL_R23_SUPERVISOR, "bytes": 25343,
                         "sha256": "ed38b5e1d9d7c506bd8db4c311948601fbb12be47ac68e2d3e4ac2e710342192"},
}
FOUNDATION_REBINDING_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/live_foundation_integration/integration_receipt.json",
    "bytes": 6850,
    "sha256": "1740d82f1899582c466ca993095528461108b2ffc7963417af17556c930a87b8",
}
SUPERVISOR_PREIMAGE_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/live_consumer_integration/preimage_receipt.json",
    "bytes": 5570,
    "sha256": "11f4574b48ed25256bfc450cffb0fcab6381a24d64c22ea3973921a1cd4f3370",
}
CURRENT_INPUT_REBINDING_RECEIPT_CONTRACT = {
    "schema": "native-g1g2-r30-current-input-rebinding-preimage-receipts-v1",
    "foundation_integration_receipt": FOUNDATION_REBINDING_RECEIPT,
    "supervisor_preimage_receipt": SUPERVISOR_PREIMAGE_RECEIPT,
}
EXPECTED_LIFECYCLE_SOURCE_PINS = {
    REL_LIFECYCLE_CORE: {"path": REL_LIFECYCLE_CORE, "bytes": 165319,
        "sha256": "0d35a38fa2195958fee80f8e722233cbcf23ff619ff13028d0c01878bb17a58a"},
    REL_MANAGED_CLIENT: {"path": REL_MANAGED_CLIENT, "bytes": 81256,
        "sha256": "d57fdacc4798927f1750354fc065b383a176cedeb15afec5a614909569fb9c82"},
    REL_NATIVE_GIT_COMPAT: {"path": REL_NATIVE_GIT_COMPAT, "bytes": 16306,
        "sha256": "c50ed841e0ffef2f141aac9845d51f21a326db20512462493c636fdc8aecf56b"},
}
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
BOUNDARY_NATURAL_EXIT_RECONCILIATION_CONTRACT = {
    "schema": "native-g1g2-r30-boundary-natural-exit-reconciliation-v1",
    "trigger": "exact_ProcessTableError_missing_previously_tracked_identity",
    "maximum_missing_tracked_generations": 1,
    "missing_generation_must_be_nonroot": True,
    "root_must_remain_exact_and_live_before_and_after": True,
    "all_other_tracked_generations_must_remain_exact_and_live": True,
    "all_visible_descendants_must_already_be_exactly_tracked": True,
    "orphan_or_new_generation_or_pid_reuse": "fail_closed",
    "natural_exit_proof": "retained_exact_handle_non259_exit_and_fresh_spi_absence",
    "whole_bind_retry_limit": 1,
    "cannot_combine_with_sample_race_recovery_for_same_sample": True,
    "failed_boundary_sample_resource_credit": False,
    "numerical_credit": False,
    "physical_credit": False,
}


class PreflightError(RuntimeError):
    pass


class BoundaryReconciliationRejected(RuntimeError):
    def __init__(self, receipt: Mapping[str, Any]):
        self.receipt = dict(receipt)
        super().__init__(str(self.receipt.get("reason", "boundary reconciliation rejected")))


_INPUT_PROVIDER: Any | None = None
_ACTIVE_PROTOCOL: Mapping[str, Any] | None = None
_ACTIVE_PROTOCOL_SHA256: str | None = None


def _exec_exact_pinned_source(module_name: str, relative_path: str,
                              pin: Mapping[str, Any], source_bytes: bytes
                              ) -> types.ModuleType:
    """Execute already-verified source bytes without consulting a .pyc cache."""
    if type(source_bytes) is not bytes or not isinstance(pin, Mapping):
        raise PreflightError("pinned Python source inputs are malformed")
    if pin.get("path") != relative_path or type(pin.get("bytes")) is not int or \
            type(pin.get("sha256")) is not str or len(pin["sha256"]) != 64 or \
            len(source_bytes) != pin["bytes"] or sha256_bytes(source_bytes) != pin["sha256"]:
        raise PreflightError(f"pinned Python source bytes differ: {relative_path}")
    existing = sys.modules.get(module_name)
    if existing is not None:
        if getattr(existing, "__r30_source_pin__", None) != dict(pin):
            raise PreflightError(f"Python module name is already bound to different bytes: {module_name}")
        return existing
    module = types.ModuleType(module_name)
    module.__file__ = str(_physical_repo_path(relative_path))
    module.__package__ = ""
    module.__r30_source_pin__ = dict(pin)
    sys.modules[module_name] = module
    try:
        code = compile(source_bytes, module.__file__, "exec", dont_inherit=True, optimize=0)
        exec(code, module.__dict__)
    except BaseException:
        if sys.modules.get(module_name) is module:
            del sys.modules[module_name]
        raise
    return module


def _protocol_pin_for_path(protocol: Mapping[str, Any], relative_path: str
                           ) -> tuple[Mapping[str, Any], bytes]:
    """Return the one authoritative current or historical source pin and bytes."""
    for map_key in ("managed_process_lifecycle_source_pins", "r30_source_pins"):
        source_map = protocol.get(map_key)
        if isinstance(source_map, Mapping) and relative_path in source_map:
            pin = source_map[relative_path]
            if not isinstance(pin, Mapping):
                raise PreflightError(f"source pin is malformed in {map_key}: {relative_path}")
            path = _physical_repo_path(relative_path)
            if path.is_symlink() or not path.is_file():
                raise PreflightError(f"pinned source file is unavailable: {relative_path}")
            raw = path.read_bytes()
            if type(pin.get("bytes")) is not int or type(pin.get("sha256")) is not str or \
                    len(raw) != pin["bytes"] or sha256_bytes(raw) != pin["sha256"]:
                raise PreflightError(f"source bytes no longer match their exact pin: {relative_path}")
            return pin, raw
    current = protocol.get("current_input_rebindings", {})
    if isinstance(current, Mapping) and relative_path in current:
        row = current[relative_path]
        if not isinstance(row, Mapping):
            raise PreflightError(f"current source rebind is malformed: {relative_path}")
        pin = row.get("current_pin")
        path = _physical_repo_path(relative_path)
        if not isinstance(pin, Mapping) or path.is_symlink() or not path.is_file():
            raise PreflightError(f"current source file is unavailable: {relative_path}")
        raw = path.read_bytes()
    else:
        pins = protocol.get("input_pins")
        if type(pins) is not list:
            raise PreflightError("historical input pins are unavailable")
        matches = [row for row in pins if isinstance(row, Mapping) and
                   row.get("path") == relative_path]
        if len(matches) != 1:
            raise PreflightError(f"source does not have exactly one historical input pin: {relative_path}")
        pin = matches[0]
        if _INPUT_PROVIDER is None:
            path = _physical_repo_path(relative_path)
            if path.is_symlink() or not path.is_file():
                raise PreflightError(f"pinned source file is unavailable: {relative_path}")
            raw = path.read_bytes()
        else:
            raw = _INPUT_PROVIDER.read_bytes(relative_path)
    if type(pin.get("bytes")) is not int or type(pin.get("sha256")) is not str or \
            len(raw) != pin["bytes"] or sha256_bytes(raw) != pin["sha256"]:
        raise PreflightError(f"source bytes no longer match their exact pin: {relative_path}")
    return pin, raw


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _exact_json_equal(left: Any, right: Any) -> bool:
    """Compare JSON values without Python's bool/int or int/float coercions."""
    if type(left) is not type(right):
        return False
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            _exact_json_equal(left[key], right[key]) for key in left)
    if isinstance(left, list):
        return len(left) == len(right) and all(
            _exact_json_equal(a, b) for a, b in zip(left, right))
    return left == right


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": sha256_bytes(data)}


def _physical_repo_path(relative: str) -> Path:
    candidate = ROOT / Path(relative)
    absolute_candidate = candidate.absolute()
    try:
        candidate.resolve(strict=False).relative_to(ROOT.resolve())
    except ValueError as exc:
        raise PreflightError(f"repository pin path escapes root: {relative}") from exc
    return absolute_candidate


repo_path = _physical_repo_path


def bind_input_provider(protocol: Mapping[str, Any]) -> Any:
    """Bind the explicit R30 provider to this module's path-reading seam."""
    global _INPUT_PROVIDER, repo_path
    if _INPUT_PROVIDER is not None:
        raise PreflightError("R30 input provider was already bound")
    provider_path = _physical_repo_path(REL_INPUT_PROVIDER)
    source_rows = protocol.get("r30_source_pins")
    if type(source_rows) is not list:
        raise PreflightError("R30 source pins are required before provider import")
    matches = [row for row in source_rows if isinstance(row, Mapping) and
               row.get("path") == REL_INPUT_PROVIDER]
    if len(matches) != 1:
        raise PreflightError("R30 strict input provider source must have one frozen source pin")
    try:
        provider_receipt = file_receipt(provider_path)
    except OSError as exc:
        raise PreflightError("pinned R30 ZIP input provider source is missing") from exc
    if provider_path.is_symlink() or provider_receipt["bytes"] != matches[0].get("bytes") or \
            provider_receipt["sha256"] != matches[0].get("sha256"):
        raise PreflightError("R30 strict ZIP input provider source differs from its frozen pin")
    module_name = "native_g1g2_pinned_zip_input_provider_r30_v1"
    provider_pin, provider_source = _protocol_pin_for_path(protocol, REL_INPUT_PROVIDER)
    provider_module = _exec_exact_pinned_source(
        module_name, REL_INPUT_PROVIDER, provider_pin, provider_source)
    verify_current_input_rebindings(protocol, "before_active_provider_bind")
    provider_protocol = copy.deepcopy(dict(protocol))
    historical_rows = provider_protocol.get("input_pins")
    if type(historical_rows) is not list or len(historical_rows) != 214:
        raise PreflightError("R30 active provider requires the unchanged ordered 214 historical rows")
    historical_by_path = {row.get("path"): index for index, row in enumerate(historical_rows)
                          if isinstance(row, Mapping)}
    if len(historical_by_path) != 214 or len(historical_rows) != 214:
        raise PreflightError("R30 provider overlay found malformed or duplicate historical rows")
    for relative in CURRENT_INPUT_REBINDING_PATHS:
        index = historical_by_path.get(relative)
        row = protocol["current_input_rebindings"][relative]
        if index is None or not _exact_json_equal(historical_rows[index], row["original_pin"]):
            raise PreflightError(f"R30 provider overlay is not bound to the original row: {relative}")
        historical_rows[index] = dict(row["current_pin"])
    try:
        provider = provider_module.PinnedZipInputProvider.from_protocol(provider_protocol, ROOT)
    except Exception as exc:
        raise PreflightError(
            f"strict R30 input provider rejected frozen inputs: {type(exc).__name__}: {exc}") from exc
    _INPUT_PROVIDER = provider
    repo_path = provider.repo_path_adapter(_physical_repo_path)
    return provider


def load_protocol_with_receipt(path: Path) -> tuple[dict[str, Any], dict[str, Any]]:
    """Parse one exact protocol byte snapshot and return its identity receipt."""
    path = Path(path)
    if path.is_symlink() or not path.is_file():
        raise PreflightError("protocol input must be a regular non-symlink file")
    try:
        resolved = path.resolve(strict=True)
        raw = path.read_bytes()
        value = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise PreflightError(f"protocol read/JSON failure: {type(exc).__name__}: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise PreflightError("protocol schema mismatch")
    receipt = {"path": str(resolved), "bytes": len(raw), "sha256": sha256_bytes(raw)}
    return value, receipt


def load_protocol(path: Path) -> dict[str, Any]:
    """Compatibility loader for callers that do not dispatch a runtime."""
    protocol, _ = load_protocol_with_receipt(path)
    return protocol


def verify_loaded_protocol_file(path: Path, expected_receipt: Mapping[str, Any],
                                phase: str) -> dict[str, Any]:
    """Require the physical protocol to remain the exact bytes originally parsed."""
    if type(phase) is not str or not phase.strip():
        raise PreflightError("protocol-file verification phase is malformed")
    if not isinstance(expected_receipt, Mapping) or \
            set(expected_receipt) != {"path", "bytes", "sha256"} or \
            type(expected_receipt.get("path")) is not str or not expected_receipt.get("path") or \
            type(expected_receipt.get("bytes")) is not int or \
            type(expected_receipt.get("sha256")) is not str or \
            len(expected_receipt.get("sha256", "")) != 64 or \
            any(ch not in "0123456789abcdef" for ch in expected_receipt.get("sha256", "")):
        raise PreflightError("loaded protocol receipt is malformed")
    protocol_path = Path(path)
    if protocol_path.is_symlink() or not protocol_path.is_file():
        raise PreflightError("loaded protocol file is absent or is not a regular non-symlink file")
    try:
        resolved = protocol_path.resolve(strict=True)
        raw = protocol_path.read_bytes()
    except Exception as exc:
        raise PreflightError(
            f"loaded protocol file cannot be re-read: {type(exc).__name__}: {exc}") from exc
    observed = {"path": str(resolved), "bytes": len(raw), "sha256": sha256_bytes(raw)}
    if not _exact_json_equal(observed, dict(expected_receipt)):
        raise PreflightError(
            f"protocol file differs from the exact bytes parsed at load time during {phase}")
    return {"phase": phase, "complete": True, **observed}


def verify_owned_source_pins(protocol: Mapping[str, Any], phase: str) -> dict[str, Any]:
    if type(phase) is not str or not phase:
        raise PreflightError("R30 owned-source verification phase is malformed")
    rows = protocol.get("r30_source_pins")
    if type(rows) is not list:
        raise PreflightError("R30 owned source pins are missing")
    expected_paths = {REL_RUNNER, REL_TEST, REL_VERIFIER, REL_INPUT_PROVIDER,
                      REL_PARSE_CONSUMER, REL_PROTOCOL_BUILDER}
    by_path: dict[str, Mapping[str, Any]] = {}
    for row in rows:
        if not isinstance(row, Mapping) or type(row.get("path")) is not str or \
                type(row.get("bytes")) is not int or row["bytes"] < 0 or \
                type(row.get("sha256")) is not str or len(row["sha256"]) != 64 or \
                any(ch not in "0123456789abcdef" for ch in row["sha256"]):
            raise PreflightError("R30 owned source pin row is malformed")
        if row["path"] in by_path:
            raise PreflightError(f"duplicate R30 owned source pin: {row['path']}")
        by_path[row["path"]] = row
    if set(by_path) != expected_paths:
        raise PreflightError("R30 owned source pin set differs from the six frozen implementation files")
    observed: list[dict[str, Any]] = []
    for relative in sorted(expected_paths):
        path = _physical_repo_path(relative)
        if path.is_symlink() or not path.is_file():
            raise PreflightError(f"R30 owned source file is missing or not regular: {relative}")
        actual = file_receipt(path)
        expected = by_path[relative]
        if actual["bytes"] != expected["bytes"] or actual["sha256"] != expected["sha256"]:
            raise PreflightError(f"R30 owned source differs from its frozen pin: {relative}")
        observed.append({"path": relative, "bytes": actual["bytes"],
                         "sha256": actual["sha256"]})
    return {"phase": phase, "complete": True, "count": len(observed), "rows": observed}


def verify_r29_parent_protocol(protocol: Mapping[str, Any], phase: str) -> dict[str, Any]:
    """Verify the separately pinned R29 protocol and exact inherited 214 rows."""
    if type(phase) is not str or not phase:
        raise PreflightError("R29 parent-protocol verification phase is malformed")
    lineage = protocol.get("parent_lineage")
    parent_pin = lineage.get("r29_protocol") if isinstance(lineage, Mapping) else None
    if not isinstance(parent_pin, Mapping) or \
            not _exact_json_equal(dict(parent_pin), R29_PROTOCOL_PIN):
        raise PreflightError("R29 protocol ancestry pin differs from the frozen source identity")
    path = _physical_repo_path(REL_R29_PROTOCOL)
    if path.is_symlink() or not path.is_file():
        raise PreflightError("frozen R29 parent protocol is physically absent or not a regular file")
    try:
        raw = path.read_bytes()
        parent = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise PreflightError(
            f"frozen R29 parent protocol cannot be read: {type(exc).__name__}: {exc}") from exc
    actual = {"path": REL_R29_PROTOCOL, "bytes": len(raw), "sha256": sha256_bytes(raw)}
    if actual != R29_PROTOCOL_PIN:
        raise PreflightError("frozen R29 parent protocol bytes differ from the pinned ancestry")
    if not isinstance(parent, Mapping) or parent.get("schema") != \
            "native-g1g2-gridap-consumer-r29-protocol-v1":
        raise PreflightError("frozen R29 parent protocol schema is malformed")
    parent_rows = parent.get("input_pins")
    current_rows = protocol.get("input_pins")
    if not isinstance(parent_rows, list) or not isinstance(current_rows, list) or \
            not _exact_json_equal(current_rows, parent_rows) or len(parent_rows) != 214 or \
            parent.get("input_pin_count") != 214:
        raise PreflightError(
            "R30 input_pins must equal the complete ordered R29 214-row list, including every field")
    return {"phase": phase, "complete": True, **actual,
            "input_pin_count": len(parent_rows), "input_pins_exactly_match": True}


def _strict_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise PreflightError(f"duplicate JSON object key: {key}")
        result[key] = value
    return result


def _read_exact_pinned_json(pin: Mapping[str, Any], phase: str) -> dict[str, Any]:
    if not isinstance(pin, Mapping) or set(pin) != {"path", "bytes", "sha256"} or \
            type(pin.get("path")) is not str or type(pin.get("bytes")) is not int or \
            type(pin.get("sha256")) is not str:
        raise PreflightError(f"{phase}: pinned receipt shape is malformed")
    path = _physical_repo_path(pin["path"])
    if path.is_symlink() or not path.is_file():
        raise PreflightError(f"{phase}: required source receipt is absent or not regular: {pin['path']}")
    raw = path.read_bytes()
    actual = {"path": pin["path"], "bytes": len(raw), "sha256": sha256_bytes(raw)}
    if not _exact_json_equal(actual, dict(pin)):
        raise PreflightError(f"{phase}: required source receipt differs from its frozen pin: {pin['path']}")
    try:
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=_strict_json_object)
    except Exception as exc:
        raise PreflightError(f"{phase}: pinned receipt JSON is malformed: {pin['path']}: {exc}") from exc
    if type(value) is not dict:
        raise PreflightError(f"{phase}: pinned receipt root is not an object: {pin['path']}")
    return value


def _expected_original_input_pin(protocol: Mapping[str, Any], relative: str
                                 ) -> dict[str, Any]:
    if relative != REL_G3_FACTORY:
        return dict(EXPECTED_CURRENT_ORIGINAL_PINS[relative])
    parent_path = _physical_repo_path(REL_R29_PROTOCOL)
    if parent_path.is_symlink() or not parent_path.is_file():
        raise PreflightError("frozen R29 parent protocol is physically absent or not a regular file")
    raw = parent_path.read_bytes()
    if {"path": REL_R29_PROTOCOL, "bytes": len(raw),
            "sha256": sha256_bytes(raw)} != R29_PROTOCOL_PIN:
        raise PreflightError("frozen R29 parent protocol bytes differ from the pinned ancestry")
    try:
        parent = json.loads(raw.decode("utf-8"), object_pairs_hook=_strict_json_object)
    except Exception as exc:
        raise PreflightError(f"frozen R29 parent protocol is malformed: {exc}") from exc
    if not isinstance(parent, Mapping) or parent.get("schema") != \
            "native-g1g2-gridap-consumer-r29-protocol-v1" or \
            parent.get("input_pin_count") != 214:
        raise PreflightError("frozen R29 parent input pin contract is malformed")
    rows = parent.get("input_pins")
    if type(rows) is not list or len(rows) != 214:
        raise PreflightError("frozen R29 parent input rows are malformed")
    matches = [row for row in rows if isinstance(row, Mapping) and
               row.get("path") == relative]
    if len(matches) != 1:
        raise PreflightError("R30 inherited G3 original pin is absent or duplicated")
    pin = matches[0]
    if set(pin) != {"path", "bytes", "sha256"} or \
            type(pin.get("bytes")) is not int or pin["bytes"] < 0 or \
            type(pin.get("sha256")) is not str or len(pin["sha256"]) != 64 or \
            any(char not in "0123456789abcdef" for char in pin["sha256"]):
        raise PreflightError("R30 inherited G3 original pin is malformed")
    return dict(pin)


def _validate_current_rebinding_shape(protocol: Mapping[str, Any]) -> None:
    receipt_contract = protocol.get("current_input_rebinding_preimage_receipts")
    if not _exact_json_equal(receipt_contract, CURRENT_INPUT_REBINDING_RECEIPT_CONTRACT):
        raise PreflightError("R30 current-input preimage receipt contract differs from frozen sources")
    rows = protocol.get("current_input_rebindings")
    if type(rows) is not dict or set(rows) != set(CURRENT_INPUT_REBINDING_PATHS):
        raise PreflightError("R30 current-input rebindings must contain the exact six canonical paths")
    for relative in CURRENT_INPUT_REBINDING_PATHS:
        row = rows.get(relative)
        if type(row) is not dict or set(row) != {"original_pin", "current_pin", "preserved_original_pin"}:
            raise PreflightError(f"R30 current-input rebind row has wrong schema: {relative}")
        for key in ("original_pin", "current_pin", "preserved_original_pin"):
            pin = row[key]
            if type(pin) is not dict or set(pin) != {"path", "bytes", "sha256"} or \
                    type(pin.get("path")) is not str or type(pin.get("bytes")) is not int or \
                    pin["bytes"] < 0 or type(pin.get("sha256")) is not str or \
                    len(pin["sha256"]) != 64 or any(c not in "0123456789abcdef" for c in pin["sha256"]):
                raise PreflightError(f"R30 current-input rebind {key} is malformed: {relative}")
    lifecycle = protocol.get("managed_process_lifecycle_source_pins")
    if type(lifecycle) is not dict or set(lifecycle) != set(EXPECTED_LIFECYCLE_SOURCE_PINS):
        raise PreflightError("R30 managed lifecycle source map must contain exactly three sources")
    for relative, expected in EXPECTED_LIFECYCLE_SOURCE_PINS.items():
        if not _exact_json_equal(lifecycle.get(relative), expected):
            raise PreflightError(f"R30 lifecycle source pin differs from its fixed source identity: {relative}")
    execution = protocol.get("execution_plan")
    if not isinstance(execution, Mapping):
        raise PreflightError("R30 execution plan is absent")
    extras = execution.get("additional_julia_parse_sources")
    expected_extras = [EXPECTED_LIFECYCLE_SOURCE_PINS[REL_MANAGED_CLIENT],
                       EXPECTED_LIFECYCLE_SOURCE_PINS[REL_NATIVE_GIT_COMPAT]]
    if not _exact_json_equal(extras, expected_extras):
        raise PreflightError("R30 Julia parse extras differ from the two exact lifecycle source pins")
    rebindings = execution.get("parse_source_rebindings")
    expected_rebindings = [
        {"path": relative,
         "original_pin": _expected_original_input_pin(protocol, relative),
         "current_pin": EXPECTED_CURRENT_INPUT_PINS[relative]}
        for relative in CURRENT_INPUT_REBINDING_PATHS[1:5]
    ]
    if not _exact_json_equal(rebindings, expected_rebindings):
        raise PreflightError("R30 parse-source rebindings differ from the exact four G1/G2/G3/T0 rows")


def verify_current_input_rebindings(protocol: Mapping[str, Any], phase: str
                                    ) -> dict[str, Any]:
    """Verify preserved original bytes and the six explicitly rebound current files."""
    if type(phase) is not str or not phase:
        raise PreflightError("R30 current-input rebind verification phase is malformed")
    _validate_current_rebinding_shape(protocol)
    foundation = _read_exact_pinned_json(FOUNDATION_REBINDING_RECEIPT, phase)
    supervisor_receipt = _read_exact_pinned_json(SUPERVISOR_PREIMAGE_RECEIPT, phase)
    if foundation.get("schema") != "root-exact-source-integration-receipt-v1" or \
            foundation.get("runtime_credit") is not False or foundation.get("formal_credit") is not False or \
            foundation.get("deleted_files") != 0 or supervisor_receipt.get("schema") != \
            "root-consumer-live-preimage-preservation-v1" or supervisor_receipt.get("live_modified") is not False:
        raise PreflightError("R30 current-input lineage receipts no longer state their exact no-credit scope")
    foundation_rows = foundation.get("rows")
    supervisor_rows = supervisor_receipt.get("rows")
    if type(foundation_rows) is not list or type(supervisor_rows) is not list:
        raise PreflightError("R30 current-input lineage receipt rows are malformed")
    by_foundation: dict[str, Mapping[str, Any]] = {}
    for item in foundation_rows:
        if not isinstance(item, Mapping) or type(item.get("relative_path")) is not str or \
                item["relative_path"] in by_foundation:
            raise PreflightError("R30 foundation receipt contains a malformed/duplicate row")
        by_foundation[item["relative_path"]] = item
    by_supervisor: dict[str, Mapping[str, Any]] = {}
    for item in supervisor_rows:
        if not isinstance(item, Mapping) or not isinstance(item.get("original_pin"), Mapping):
            raise PreflightError("R30 supervisor preimage receipt contains a malformed row")
        original_path = item["original_pin"].get("path")
        if type(original_path) is not str or original_path in by_supervisor:
            raise PreflightError("R30 supervisor preimage receipt contains duplicate/malformed paths")
        by_supervisor[original_path] = item
    protocol_input_pins = protocol.get("input_pins")
    if type(protocol_input_pins) is not list:
        raise PreflightError("R30 historical input_pins must remain an ordered list")
    historical = {row.get("path"): row for row in protocol_input_pins if isinstance(row, Mapping)}
    if len(historical) != 214 or len(protocol_input_pins) != 214:
        raise PreflightError("R30 historical 214 input rows are malformed or duplicated")

    observed_rows: list[dict[str, Any]] = []
    for relative in CURRENT_INPUT_REBINDING_PATHS:
        row = protocol["current_input_rebindings"][relative]
        expected_current = EXPECTED_CURRENT_INPUT_PINS[relative]
        expected_original = _expected_original_input_pin(protocol, relative)
        preserved_rel = ("runs/e/lifecycle_systemic_repair_20260927_r1/live_consumer_integration/"
                         "preimages/" + relative if relative == REL_R23_SUPERVISOR else
                         "runs/e/lifecycle_systemic_repair_20260927_r1/live_foundation_integration/"
                         "preimages/" + relative)
        expected_preserved = {**expected_original, "path": preserved_rel}
        if not _exact_json_equal(row["current_pin"], expected_current) or \
                not _exact_json_equal(row["original_pin"], expected_original) or \
                not _exact_json_equal(row["preserved_original_pin"], expected_preserved):
            raise PreflightError(f"R30 current-input pin tuple differs from fixed preserved/current bytes: {relative}")
        if not _exact_json_equal(historical.get(relative), expected_original):
            raise PreflightError(f"R30 original pin is not the exact inherited 214-row value: {relative}")
        if relative == REL_R23_SUPERVISOR:
            lineage_row = by_supervisor.get(relative)
            if not isinstance(lineage_row, Mapping) or \
                    not _exact_json_equal(lineage_row.get("original_pin"), expected_original) or \
                    not _exact_json_equal(lineage_row.get("preserved_original_pin"), expected_preserved):
                raise PreflightError("R30 supervisor original bytes differ from the preserved source receipt")
        else:
            receipt_row = by_foundation.get(relative)
            before = receipt_row.get("before") if isinstance(receipt_row, Mapping) else None
            after = receipt_row.get("after") if isinstance(receipt_row, Mapping) else None
            if not isinstance(before, Mapping) or not isinstance(after, Mapping) or \
                    before.get("bytes") != expected_original["bytes"] or \
                    str(before.get("sha256", "")).lower() != expected_original["sha256"] or \
                    after.get("bytes") != expected_current["bytes"] or \
                    str(after.get("sha256", "")).lower() != expected_current["sha256"]:
                raise PreflightError(f"R30 foundation receipt does not bind exact old/current bytes: {relative}")
        for pin, label in ((expected_current, "current"), (expected_preserved, "preserved_original")):
            path = _physical_repo_path(pin["path"])
            if path.is_symlink() or not path.is_file():
                raise PreflightError(f"R30 {label} source is missing/not regular: {pin['path']}")
            actual = file_receipt(path)
            if actual["bytes"] != pin["bytes"] or actual["sha256"] != pin["sha256"]:
                raise PreflightError(f"R30 {label} source bytes changed: {pin['path']}")
        observed_rows.append({"path": relative, "original_pin": dict(expected_original),
            "current_pin": dict(expected_current), "preserved_original_pin": dict(expected_preserved)})
    return {"phase": phase, "complete": True, "count": len(observed_rows),
            "rows": observed_rows,
            "preimage_receipts": [dict(FOUNDATION_REBINDING_RECEIPT),
                                  dict(SUPERVISOR_PREIMAGE_RECEIPT)]}


def verify_managed_lifecycle_source_pins(protocol: Mapping[str, Any], phase: str
                                         ) -> dict[str, Any]:
    if type(phase) is not str or not phase:
        raise PreflightError("R30 lifecycle-source verification phase is malformed")
    rows = protocol.get("managed_process_lifecycle_source_pins")
    if type(rows) is not dict or set(rows) != set(EXPECTED_LIFECYCLE_SOURCE_PINS):
        raise PreflightError("R30 lifecycle source pin map is not the exact three-source set")
    observed: list[dict[str, Any]] = []
    for relative in (REL_LIFECYCLE_CORE, REL_MANAGED_CLIENT, REL_NATIVE_GIT_COMPAT):
        expected = EXPECTED_LIFECYCLE_SOURCE_PINS[relative]
        pin = rows.get(relative)
        if not _exact_json_equal(pin, expected):
            raise PreflightError(f"R30 lifecycle source pin differs from the approved identity: {relative}")
        path = _physical_repo_path(relative)
        if path.is_symlink() or not path.is_file():
            raise PreflightError(f"R30 managed lifecycle source is absent/not regular: {relative}")
        actual = file_receipt(path)
        if actual["bytes"] != expected["bytes"] or actual["sha256"] != expected["sha256"]:
            raise PreflightError(f"R30 managed lifecycle source bytes differ from frozen identity: {relative}")
        observed.append({"path": relative, "bytes": actual["bytes"], "sha256": actual["sha256"]})
    return {"phase": phase, "complete": True, "count": len(observed), "rows": observed}


def _read_bound_archive_json(logical_path: str) -> Mapping[str, Any]:
    """Read one archived JSON input through the explicitly pinned provider."""
    if _INPUT_PROVIDER is None:
        raise PreflightError(
            "R30 pinned ZIP input provider must be bound before archived JSON validation")
    try:
        value = _INPUT_PROVIDER.read_json(logical_path)
    except Exception as exc:
        raise PreflightError(
            f"R30 pinned archived JSON input failed: {logical_path}: "
            f"{type(exc).__name__}: {exc}") from exc
    if not isinstance(value, Mapping):
        raise PreflightError(f"R30 pinned archived JSON input is not an object: {logical_path}")
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
    if not _exact_json_equal(dict(limits), expected_limits):
        raise PreflightError("frozen R30 resource/compiler contract mismatch")
    execution = protocol.get("execution_plan")
    if not isinstance(execution, Mapping) or list(execution.get("stage_order", ())) != list(STAGES):
        raise PreflightError("stage order must remain parse_all/primary/fresh_replay")
    if execution.get("consumer_script") != REL_FOCUSED:
        raise PreflightError("formal consumer script is not the frozen R14 consumer")
    if execution.get("primary_replay_same_consumer_script") is not True:
        raise PreflightError("primary/replay consumer identity is not explicit")
    if execution.get("compile_min_is_only_non_path_argv_delta_from_R13") is not True:
        raise PreflightError("primary/replay non-path argv delta is not limited to --compile=min")
    if execution.get("parse_manifest_transport_delta_from_R13") != \
            "pinned_manifest_bytes_on_stdin_with_length_sha_and_eof_checks":
        raise PreflightError("parse_all manifest transport is not the frozen R30 stdin protocol")
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
    _validate_current_rebinding_shape(protocol)
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
    required = {
        REL_R29_RUNNER, REL_R29_TEST, REL_LEGACY_TEST, REL_R29_VERIFIER,
        REL_R23_TABLE, REL_R23_SUPERVISOR,
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
    if type(protocol.get("input_pin_count")) is not int or \
            protocol.get("input_pin_count") != len(pins) or len(pins) != 214:
        raise PreflightError("input pin count does not match the frozen pin list")
    verify_r29_parent_protocol(protocol, "protocol_shape")
    provider_contract = protocol.get("archive_input_provider")
    if not isinstance(provider_contract, Mapping) or \
            provider_contract.get("schema") != "native-g1g2-r30-archive-input-provider-v1" or \
            provider_contract.get("path") != R30_ARCHIVE_PATH or \
            type(provider_contract.get("bytes")) is not int or \
            provider_contract.get("bytes") != R30_ARCHIVE_BYTES or \
            provider_contract.get("sha256") != R30_ARCHIVE_SHA256 or \
            not _exact_json_equal(provider_contract.get("source_readiness_receipt"),
                                  R30_READINESS_PIN) or \
            provider_contract.get("source_map_origin") != "verified_original_r29_214_pin_join" or \
            type(provider_contract.get("zip_member_paths")) is not list or \
            len(provider_contract.get("zip_member_paths")) != 47 or \
            any(type(path) is not str for path in provider_contract.get("zip_member_paths", [])) or \
            provider_contract.get("zip_member_paths") != sorted(set(provider_contract.get("zip_member_paths"))):
        raise PreflightError("R30 explicit ZIP-backed source-class map is malformed")
    if len(paths) != 214 or len(paths - set(provider_contract["zip_member_paths"])) != 167 or \
            not set(provider_contract["zip_member_paths"]).issubset(paths):
        raise PreflightError("R30 source-class map must retain 167 workspace and 47 ZIP pins")
    verify_owned_source_pins(protocol, "protocol_shape")
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
    r13_summary = _read_bound_archive_json(REL_R13_SUMMARY)
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
        raise PreflightError("R30 static/runtime preparation cannot pregrant numerical or physical credit")
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
    expected_pid_reuse_tests = (python_pin["path"] + " -B " + str(repo_path(REL_R29_TEST)) +
                                " R29NaturalExitPidReuseTests -v")
    expected_verifier_command = (python_pin["path"] + " -B " + str(repo_path(REL_VERIFIER)) +
                                 " --protocol " + str(repo_path(REL_PROTOCOL)))
    expected_provider_tests = python_pin["path"] + " -B " + str(repo_path(REL_TEST)) + " -v"
    if not isinstance(static_qa, Mapping) or \
            static_qa.get("python_tests_command") != expected_tests or \
            static_qa.get("bind_failure_fault_injection_command") != expected_failure_tests or \
            static_qa.get("tree_cleanup_fault_injection_command") != expected_tree_failure_tests or \
            static_qa.get("sample_race_fault_injection_command") != expected_sample_race_tests or \
            static_qa.get("orphan_chain_fault_injection_command") != expected_orphan_chain_tests or \
            static_qa.get("pid_reuse_fault_injection_command") != expected_pid_reuse_tests or \
            static_qa.get("verifier_command") != expected_verifier_command or \
            static_qa.get("r30_input_provider_tests_command") != expected_provider_tests:
        raise PreflightError("R30 static QA argv does not target the pinned tests/verifier")
    protocol_abs = str(repo_path(REL_PROTOCOL))
    expected_static = [python_pin["path"], "-B", str(repo_path(REL_VERIFIER)),
                       "--protocol", protocol_abs]
    expected_actual = [python_pin["path"], "-B", str(repo_path(REL_RUNNER)),
                       "--dispatch-actual", "--protocol", protocol_abs,
                       "--output", str(repo_path(REL_OUTPUT))]
    if static_argv != expected_static or actual_argv != expected_actual:
        raise PreflightError("frozen static/runtime argv does not address the unique R30 verifier/consumer")
    planned_output = protocol.get("planned_output_leaf")
    if planned_output != REL_OUTPUT:
        raise PreflightError("runtime output leaf differs from frozen unique leaf")
    # The R13 actual protocol is the command parent. Primary and fresh replay
    # retain every token except the frozen output/consumer paths and --compile=min.
    # parse_all changes only its manifest transport: exact pinned bytes, size,
    # hash, row count, and root are bound to the R30 stdin consumer.
    parent = _read_bound_archive_json(REL_R13_PROTOCOL)
    parent_commands = parent["execution_plan"]["stage_commands"]
    planned = execution["stage_commands"]
    old_output = parent["execution_plan"]["planned_actual_output"]
    if len(parent_commands) != 3 or len(planned) != 3:
        raise PreflightError("R13/R30 stage command count changed")
    parse_manifest = execution.get("parse_manifest")
    expected_parse_manifest = {
        "path": REL_PARSE_MANIFEST,
        "bytes": 11504,
        "sha256": "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa",
        "entries": 108,
    }
    if not isinstance(parse_manifest, Mapping) or \
            not _exact_json_equal(dict(parse_manifest), expected_parse_manifest):
        raise PreflightError("R30 parse manifest input identity differs from the original R13 pin")
    parse_pin = next((item for item in pins if item["path"] == REL_PARSE_MANIFEST), None)
    if parse_pin is None or parse_pin.get("bytes") != parse_manifest["bytes"] or \
            parse_pin.get("sha256") != parse_manifest["sha256"]:
        raise PreflightError("R30 stdin manifest transport is not bound to the original 214-pin row")
    for old, new in zip(parent_commands, planned):
        old_argv = list(old["argv"])
        if old_argv.count(COMPILER_MODE) != 0 or old_argv.count("--threads=1") != 1:
            raise PreflightError("R13 compiler/thread argv parent is unexpected")
        old_argv.insert(old_argv.index("--threads=1") + 1, COMPILER_MODE)
        if old["stage"] == "parse_all":
            try:
                eval_index = old_argv.index("-e")
            except ValueError as exc:
                raise PreflightError("R13 parse_all command has no inline consumer boundary") from exc
            expected_prefix = old_argv[:eval_index]
            expected_root = old_argv[-1]
            parse_tail = [str(parse_manifest["bytes"]), parse_manifest["sha256"],
                          str(parse_manifest["entries"]), expected_root]
            for source_pin in execution["additional_julia_parse_sources"]:
                parse_tail.extend(["--extra-source", source_pin["path"],
                                   str(source_pin["bytes"]), source_pin["sha256"]])
            for source_row in execution["parse_source_rebindings"]:
                old_pin, new_pin = source_row["original_pin"], source_row["current_pin"]
                parse_tail.extend(["--source-rebinding", source_row["path"],
                    str(old_pin["bytes"]), old_pin["sha256"], str(new_pin["bytes"]),
                    new_pin["sha256"]])
            expected_new = {
                "stage": "parse_all",
                "argv": [*expected_prefix, str(repo_path(REL_PARSE_CONSUMER)), *parse_tail],
                "stdin_provider_path": REL_PARSE_MANIFEST,
                "stdin_manifest_contract": dict(parse_manifest),
            }
            if expected_root != str(ROOT) or new != expected_new:
                raise PreflightError("R30 parse_all command differs from the 214-pin-bound 36-argument rebind contract")
        else:
            old_argv = [arg.replace(old_output, str(repo_path(REL_OUTPUT))) for arg in old_argv]
            old_argv = [arg.replace("focused_tests_r12_markers.jl", Path(REL_FOCUSED).name)
                        for arg in old_argv]
            if new != {"stage": old["stage"], "argv": old_argv}:
                raise PreflightError(
                    f"R30 primary/replay command differs from pinned R13 path/mode delta: {old['stage']}")


def verify_input_pins(protocol: Mapping[str, Any], phase: str = "input_pin_check") -> dict[str, Any]:
    if _INPUT_PROVIDER is None:
        raise PreflightError("R30 strict input provider is not bound")
    try:
        result = _INPUT_PROVIDER.verify_all(phase)
    except Exception as exc:
        raise PreflightError(
            f"frozen R30 inputs are not complete: {type(exc).__name__}: {exc}") from exc
    if result.get("input_count") != 214 or result.get("workspace_count") != 167 or \
            result.get("zip_member_count") != 47 or result.get("complete") is not True:
        raise PreflightError("R30 strict provider did not verify the frozen 214/167/47 source map")
    owned_sources = verify_owned_source_pins(protocol, phase)
    parent_protocol = verify_r29_parent_protocol(protocol, phase)
    current_rebindings = verify_current_input_rebindings(protocol, phase)
    lifecycle_sources = verify_managed_lifecycle_source_pins(protocol, phase)
    checked = [{"path": row["path"], "bytes": row["bytes"], "sha256": row["sha256"],
                "source": row["source"]} for row in result["rows"]]
    return {"complete": True, "checked_count": len(checked), "missing": [], "changed": [],
            "checked": checked, "source_counts": {"workspace": 167, "zip_member": 47},
            "archive_before": result["archive_before"],
            "archive_after": result["archive_after"], "phase": result["phase"],
            "owned_sources": owned_sources, "r29_parent_protocol": parent_protocol,
            "current_input_rebindings": current_rebindings,
            "managed_process_lifecycle_source_pins": lifecycle_sources}


def validate_invocation(mode: str, observed_argv: list[str], protocol: Mapping[str, Any]) -> None:
    if mode not in ("static_verifier", "actual_supervisor"):
        raise PreflightError("invocation role must be explicitly static_verifier or actual_supervisor")
    expected = protocol["invocation_contract"][f"{mode}_argv"]
    if observed_argv != expected:
        raise PreflightError(
            "observed invocation argv does not match the selected role: " +
            json.dumps({"role": mode, "expected": expected, "observed": observed_argv}, sort_keys=True)
        )


def _load_r23(protocol: Mapping[str, Any] | None = None) -> tuple[Any, Any]:
    active = protocol if protocol is not None else _ACTIVE_PROTOCOL
    if not isinstance(active, Mapping):
        raise PreflightError("R23 source loader requires the already validated R30 protocol")
    table_name = "native_process_table_r23_v1"
    table = sys.modules.get(table_name)
    if table is None:
        table_pin, table_source = _protocol_pin_for_path(active, REL_R23_TABLE)
        table = _exec_exact_pinned_source(table_name, REL_R23_TABLE, table_pin, table_source)
    supervisor_name = "supervise_r16_root_audit_r23_v1"
    supervisor = sys.modules.get(supervisor_name)
    if supervisor is None:
        supervisor_pin, supervisor_source = _protocol_pin_for_path(active, REL_R23_SUPERVISOR)
        supervisor = _exec_exact_pinned_source(
            supervisor_name, REL_R23_SUPERVISOR, supervisor_pin, supervisor_source)
    return table, supervisor

def parse_script_text() -> str:
    raise PreflightError("R30 parse_all runs the pinned stdin consumer file, not inline Julia code")


def prepare_parse_manifest_stdin(provider: Any,
                                 manifest_contract: Mapping[str, Any]
                                 ) -> tuple[bytes, dict[str, Any]]:
    """Read and bind the exact manifest bytes that will be streamed to Julia."""
    if not isinstance(manifest_contract, Mapping) or \
            manifest_contract.get("path") != REL_PARSE_MANIFEST or \
            type(manifest_contract.get("bytes")) is not int or \
            type(manifest_contract.get("sha256")) is not str or \
            type(manifest_contract.get("entries")) is not int:
        raise PreflightError("R30 parse manifest contract is malformed")
    data = provider.read_bytes(REL_PARSE_MANIFEST)
    receipt = provider.receipt(REL_PARSE_MANIFEST)
    actual_sha = hashlib.sha256(data).hexdigest()
    if len(data) != manifest_contract["bytes"] or actual_sha != manifest_contract["sha256"] or \
            receipt.get("path") != REL_PARSE_MANIFEST or \
            receipt.get("bytes") != len(data) or receipt.get("sha256") != actual_sha or \
            receipt.get("source") != "zip_member":
        raise PreflightError("R30 manifest bytes differ from the pinned ZIP-backed source")
    return data, dict(receipt)


def julia_prefix(julia_exe: str, gridap_project: str) -> list[str]:
    return [julia_exe, f"--project={gridap_project}", "--startup-file=no",
            "--history-file=no", "--threads=1", COMPILER_MODE,
            f"--heap-size-hint={JULIA_HEAP_HINT}"]


def planned_stage_commands(protocol: Mapping[str, Any], output: Path) -> list[dict[str, Any]]:
    execution = protocol["execution_plan"]
    julia = execution["julia_executable"]["path"]
    prefix = julia_prefix(julia, execution["gridap_project"])
    artifact = output / "artifacts" / "primary.bin"
    manifest = execution["parse_manifest"]
    parse_tail: list[str] = [str(manifest["bytes"]), manifest["sha256"],
                             str(manifest["entries"]), str(ROOT)]
    for pin in execution["additional_julia_parse_sources"]:
        parse_tail.extend(["--extra-source", pin["path"], str(pin["bytes"]), pin["sha256"]])
    for row in execution["parse_source_rebindings"]:
        old_pin = row["original_pin"]
        new_pin = row["current_pin"]
        parse_tail.extend(["--source-rebinding", row["path"], str(old_pin["bytes"]),
                           old_pin["sha256"], str(new_pin["bytes"]), new_pin["sha256"]])
    return [
        {"stage": "parse_all", "argv": [*prefix, str(repo_path(REL_PARSE_CONSUMER)),
            *parse_tail],
         "stdin_provider_path": REL_PARSE_MANIFEST,
         "stdin_manifest_contract": dict(manifest)},
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
        return {"schema": "native-g1g2-r30-natural-exit-receipt-v1",
                "identity": _id_dict(identity), "complete": True,
                "signal_sent": False, "wait_confirmed": True,
                "exit_code": code,
                "pid_reused_after_exit": row is not None,
                "replacement_create_time_100ns": (
                    row.identity.create_time_100ns if row is not None else None)}
    except Exception as exc:
        return {"schema": "native-g1g2-r30-natural-exit-receipt-v1",
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
        "schema": "native-g1g2-r30-sample-attempt-v1",
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
        "schema": "native-g1g2-r30-original-popen-handle-cleanup-v1",
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
                    "schema": "native-g1g2-r30-popen-bind-failure-cleanup-v1",
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
        "schema": "native-g1g2-r30-popen-bind-failure-cleanup-v1",
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


def _seal_native_snapshot(snapshot: Any, table: Any) -> dict[str, Any]:
    """Serialize and hash the complete native SPI snapshot used by a boundary receipt."""
    validated = table.validate_snapshot(snapshot)
    rows = [list(row) for row in table.native_snapshot_digest(validated)]
    payload = {
        "schema": "native-g1g2-r30-sealed-process-snapshot-v1",
        "host_identity": list(validated.host_identity),
        "buffer_bytes": validated.buffer_bytes,
        "query_attempts": validated.query_attempts,
        "ntstatus_u32": validated.ntstatus_u32,
        "process_rows": rows,
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {**payload, "row_count": len(rows), "sha256": sha256_bytes(raw)}


def _require_live_exact_generation(snapshot: Any, identity: tuple[int, int],
                                   handles: Mapping[tuple[int, int], Any], table: Any,
                                   *, phase: str) -> dict[str, Any]:
    handle = handles.get(identity)
    if handle is None:
        raise RuntimeError(f"{phase}: retained exact process handle is absent")
    table_identity = table.require_handle_matches_table(handle, identity, snapshot,
        handle_identity_reader=table.read_process_handle_identity)
    before_wait = table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                              phase=f"{phase}-prewait-handle")
    if table.wait_for_process_exit(handle, 0.001):
        raise RuntimeError(f"{phase}: exact tracked generation exited during boundary reconciliation")
    after_wait = table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                             phase=f"{phase}-postwait-handle")
    return {"identity": _id_dict(identity),
            "snapshot_identity": _id_dict(table_identity),
            "handle_identity_before_wait": _id_dict(before_wait),
            "wait_signaled": False,
            "handle_identity_after_wait": _id_dict(after_wait)}


def _validate_boundary_snapshot(snapshot: Any, root_identity: tuple[int, int],
                                expected_tracked: set[tuple[int, int]],
                                missing_identity: tuple[int, int],
                                handles: Mapping[tuple[int, int], Any], table: Any,
                                *, phase: str) -> dict[str, Any]:
    """Require a complete rooted closure with only the receipted generation absent."""
    validated = table.validate_snapshot(snapshot)
    if root_identity not in expected_tracked:
        raise RuntimeError(f"{phase}: root identity is absent from the expected tracked set")
    if missing_identity in expected_tracked:
        raise RuntimeError(f"{phase}: naturally exited identity remains in the expected tracked set")
    live_generation_checks: list[dict[str, Any]] = []
    for identity in sorted(expected_tracked):
        row = validated.by_pid.get(identity[0])
        if row is None:
            raise RuntimeError(f"{phase}: another tracked PID is absent")
        observed = table.validate_identity((row.identity.pid, row.identity.create_time_100ns))
        if observed != identity:
            raise RuntimeError(f"{phase}: another tracked PID has a different generation")
        live_generation_checks.append(_require_live_exact_generation(
            validated, identity, handles, table, phase=phase))

    replacement = validated.by_pid.get(missing_identity[0])
    if replacement is not None:
        raise RuntimeError(f"{phase}: missing PID is present under another or same generation")
    if handles.get(missing_identity) is None:
        raise RuntimeError(f"{phase}: missing generation has no retained exact handle")
    missing_handle_identity = table.require_same_identity(
        table.read_process_handle_identity(handles[missing_identity]), missing_identity,
        phase=f"{phase}-missing-retained-handle")
    if any(row.ppid == missing_identity[0] for row in validated.rows):
        raise RuntimeError(f"{phase}: a visible process is orphaned from the missing parent PID")

    descendants = table.descendant_identities(validated, root_identity, previously_tracked=())
    descendant_ids = {(item.pid, item.create_time_100ns) for item in descendants}
    if descendant_ids != set(expected_tracked):
        raise RuntimeError(f"{phase}: observed rooted tree has an unbound or missing generation")
    return {"phase": phase,
            "snapshot_row_count": len(validated.rows),
            "root_identity": _id_dict(root_identity),
            "expected_tracked_identities": [_id_dict(x) for x in sorted(expected_tracked)],
            "missing_identity_absent": _id_dict(missing_identity),
            "missing_handle_identity": _id_dict(missing_handle_identity),
            "live_generation_checks": live_generation_checks,
            "root_live": True,
            "descendant_identities": [_id_dict(x) for x in sorted(descendant_ids)]}


def _reconcile_boundary_natural_exit(
    snapshot: Any, error: BaseException, boundary: str, sampling_event_index: int,
    root_identity: tuple[int, int], tracked: set[tuple[int, int]],
    handles: dict[tuple[int, int], Any], table: Any, snapshot_provider: Any,
    exit_receipts: list[dict[str, Any]], *, recovery_allowed: bool,
) -> tuple[dict[str, Any], Any | None, tuple[tuple[int, int], ...]]:
    """Receipt one exact nonroot natural exit, then retry the complete boundary bind once."""
    tracked_before = set(tracked)
    receipt: dict[str, Any] = {
        "schema": BOUNDARY_NATURAL_EXIT_RECONCILIATION_CONTRACT["schema"],
        "boundary": boundary,
        "sampling_event_index": sampling_event_index,
        "trigger": {"type": type(error).__name__, "message": str(error), "repr": repr(error)},
        "tracked_before": [_id_dict(x) for x in sorted(tracked_before)],
        "missing_tracked_identities": [],
        "same_pid_different_generation": [],
        "failure_before_snapshot": None,
        "natural_exit_receipt": None,
        "fresh_after_exit_snapshot": None,
        "after_retry_snapshot": None,
        "recovery_allowed": recovery_allowed,
        "whole_bind_retry_limit": 1,
        "whole_bind_retry_count": 0,
        "root_live_before": False,
        "root_live_after": False,
        "complete": False,
        "reason": "not_started",
        **NO_CREDIT,
    }
    try:
        validated = table.validate_snapshot(snapshot)
        receipt["failure_before_snapshot"] = _seal_native_snapshot(validated, table)
        missing = tuple(identity for identity in sorted(tracked_before)
                        if validated.by_pid.get(identity[0]) is None)
        mismatched = tuple(identity for identity in sorted(tracked_before)
                           if validated.by_pid.get(identity[0]) is not None and
                           table.validate_identity((validated.by_pid[identity[0]].identity.pid,
                               validated.by_pid[identity[0]].identity.create_time_100ns)) != identity)
        receipt["missing_tracked_identities"] = [_id_dict(x) for x in missing]
        receipt["same_pid_different_generation"] = [_id_dict(x) for x in mismatched]

        if type(error) is not table.ProcessTableError or str(error) != SAMPLED_TRACKED_RACE_ERROR:
            receipt["reason"] = "trigger_is_not_the_exact_tracked_missing_process_table_error"
            return receipt, None, ()
        if not recovery_allowed:
            receipt["reason"] = "boundary_recovery_cannot_mix_with_sampling_recovery"
            return receipt, None, ()
        if mismatched:
            receipt["reason"] = "tracked_pid_generation_mismatch"
            return receipt, None, ()
        if len(missing) != 1:
            receipt["reason"] = "missing_tracked_generation_count_is_not_exactly_one"
            return receipt, None, ()
        missing_identity = missing[0]
        if missing_identity == root_identity or root_identity not in tracked_before:
            receipt["reason"] = "root_missing_or_missing_identity_is_root"
            return receipt, None, ()

        # Before accepting the race, prove all other tracked generations still
        # form the complete rooted closure and remain live through their handles.
        expected_remaining = tracked_before - {missing_identity}
        receipt["failure_before_closure"] = _validate_boundary_snapshot(
            validated, root_identity, expected_remaining, missing_identity, handles, table,
            phase=f"{boundary}-failure-before")
        receipt["root_live_before"] = True

        exit_handle = handles.get(missing_identity)
        if exit_handle is None:
            receipt["reason"] = "missing_generation_has_no_retained_exact_handle"
            return receipt, None, ()
        natural = _natural_exit_receipt(missing_identity, exit_handle, snapshot_provider,
            table, table.wait_for_process_exit, table.process_exit_code)
        receipt["natural_exit_receipt"] = natural
        exit_receipts.append(natural)
        if natural.get("complete") is not True or natural.get("pid_reused_after_exit") is not False or \
                type(natural.get("exit_code")) is not int or natural.get("exit_code") == 259:
            receipt["reason"] = "exact_natural_exit_receipt_incomplete_or_reused"
            return receipt, None, ()

        tracked.discard(missing_identity)
        fresh_after_exit = table.validate_snapshot(snapshot_provider())
        receipt["fresh_after_exit_snapshot"] = _seal_native_snapshot(fresh_after_exit, table)
        receipt["fresh_after_exit_closure"] = _validate_boundary_snapshot(
            fresh_after_exit, root_identity, expected_remaining, missing_identity, handles, table,
            phase=f"{boundary}-fresh-after-exit")

        # One complete whole-tree bind retry against the fresh SPI. A second
        # retry, including an exact same-message failure here, is never attempted.
        receipt["whole_bind_retry_count"] = 1
        try:
            bound = _bind_tree(fresh_after_exit, root_identity, tracked, handles, table)
        except Exception as retry_error:
            receipt["retry_bind_error"] = {"type": type(retry_error).__name__,
                "message": str(retry_error), "repr": repr(retry_error)}
            receipt["reason"] = "single_whole_bind_retry_failed"
            return receipt, None, ()

        after_retry = table.validate_snapshot(snapshot_provider())
        receipt["after_retry_snapshot"] = _seal_native_snapshot(after_retry, table)
        receipt["after_retry_closure"] = _validate_boundary_snapshot(
            after_retry, root_identity, expected_remaining, missing_identity, handles, table,
            phase=f"{boundary}-after-retry")
        receipt["root_live_after"] = True
        receipt["retry_bound_identities"] = [_id_dict(x) for x in bound]
        receipt["complete"] = True
        receipt["reason"] = "single_generation_receipted_and_full_boundary_bind_retried"
        return receipt, after_retry, bound
    except Exception as exc:
        receipt["reason"] = "boundary_reconciliation_evidence_incomplete"
        receipt["reconciliation_error"] = {"type": type(exc).__name__,
            "message": str(exc), "repr": repr(exc)}
        return receipt, None, ()


def _bind_tree_at_boundary(
    snapshot: Any, root_identity: tuple[int, int], tracked: set[tuple[int, int]],
    handles: dict[tuple[int, int], Any], table: Any, snapshot_provider: Any,
    exit_receipts: list[dict[str, Any]], boundary_records: list[dict[str, Any]],
    boundary_records_path: Path, *, boundary: str, sampling_event_index: int,
    recovery_allowed: bool,
) -> tuple[tuple[tuple[int, int], ...], dict[str, Any] | None, Any]:
    try:
        bound = _bind_tree(snapshot, root_identity, tracked, handles, table)
        return bound, None, snapshot
    except table.ProcessTableError as exc:
        if type(exc) is not table.ProcessTableError or str(exc) != SAMPLED_TRACKED_RACE_ERROR:
            raise
        record, reconciled_snapshot, bound = _reconcile_boundary_natural_exit(
            snapshot, exc, boundary, sampling_event_index, root_identity, tracked,
            handles, table, snapshot_provider, exit_receipts,
            recovery_allowed=recovery_allowed)
        boundary_records.append(record)
        _append_jsonl(boundary_records_path, record)
        if record.get("complete") is not True or reconciled_snapshot is None:
            raise BoundaryReconciliationRejected(record)
        return bound, record, reconciled_snapshot


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
                return {"schema": "native-g1g2-r30-exact-termination-v1",
                        "complete": True, "passes": pass_index,
                        "signals": signalled, "residual_audit": residual,
                        "unowned_heavy_identities": []}
        except Exception as exc:
            errors.append({"pass": pass_index, "type": type(exc).__name__,
                           "message": str(exc), "repr": repr(exc)})
    return {"schema": "native-g1g2-r30-exact-termination-v1", "complete": False,
            "passes": 8, "signals": signalled, "errors": errors,
            **NO_CREDIT}


def _run_stage(output: Path, index: int, stage_name: str, command: list[str],
               environment: Mapping[str, str], table: Any, audit: Any,
               stdin_bytes: bytes | None = None,
               stdin_source_receipt: Mapping[str, Any] | None = None) -> dict[str, Any]:
    """Run one stage using the exact-pinned, suspended native lifecycle core."""
    if os.name != "nt" or not isinstance(_ACTIVE_PROTOCOL, Mapping) or not _ACTIVE_PROTOCOL_SHA256:
        raise PreflightError("R30 managed stage lacks Windows or exact protocol-byte binding")
    stage_dir = output / f"{index:02d}_{stage_name}"
    stage_dir.mkdir()
    ack_dir = stage_dir / "managed_ack"
    ack_dir.mkdir()
    for name in ("sample_attempts.jsonl", "samples.jsonl", "sample_boundary_acceptances.jsonl",
                 "boundary_reconciliations.jsonl", "managed_source_history.jsonl",
                 "managed_birth_measurements.jsonl", "managed_resource_measurements.jsonl",
                 "managed_lifecycle_events.jsonl"):
        (stage_dir / name).write_bytes(b"")

    started = time.monotonic()
    started_utc = utc_now()
    deadline = started + WALL_SECONDS_PER_STAGE
    samples: list[dict[str, Any]] = []
    acceptances: list[dict[str, Any]] = []
    sample_attempt_count = sample_recovery_count = 0
    monitor_error = None
    stop_reason = "natural_exit"
    termination_requested = False
    termination_error = None
    session = core = backend = registry = None
    lifecycle_summary: dict[str, Any] = {}
    cleanup_summary: dict[str, Any] = {}
    ack_inventory: dict[str, Any] = {"complete": False, "files": [], **NO_CREDIT}
    root_identity: tuple[int, int] | None = None
    root_exit_code = None
    stdin_required = stdin_bytes is not None
    stdin_state: dict[str, Any] = {
        "required": stdin_required, "expected_bytes": len(stdin_bytes) if stdin_bytes is not None else 0,
        "expected_sha256": hashlib.sha256(stdin_bytes).hexdigest() if stdin_bytes is not None else None,
        "source_receipt": dict(stdin_source_receipt or {}), "written_bytes": 0,
        "written_sha256": None, "eof_sent": False, "complete": not stdin_required, "error": None}
    stdin_error = threading.Event()
    stdin_read_fd = stdin_write_fd = None
    stdin_writer = None
    stdout = stderr = None
    heavy_before: tuple[tuple[int, int], ...] = ()
    heavy_after: tuple[tuple[int, int], ...] = ()
    residual: dict[str, Any] = {"complete": False, "residual_clear": False, **NO_CREDIT}
    residual_complete = False
    close_receipt: dict[str, Any] = {"complete": False}
    termination_receipt = None

    def append_sync(path: Path, value: Mapping[str, Any]) -> None:
        raw = (json.dumps(dict(value), sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
        with path.open("ab") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())

    class Observer:
        def __init__(self, native: Any, lifecycle: Any) -> None:
            self.native, self.lifecycle = native, lifecycle
            self.sequence = 0

        def birth_source_witness(self, pid: int, *, phase: str, event_sequence: int) -> Any:
            if phase != "managed_create" or type(event_sequence) is not int or event_sequence <= 0:
                raise RuntimeError("unexpected managed birth witness phase/sequence")
            snapshot = table.validate_snapshot(table.query_native_process_table())
            row = snapshot.by_pid.get(pid)
            if row is None:
                raise RuntimeError("CREATE-barrier source snapshot omits event PID")
            sealed = _seal_native_snapshot(snapshot, table)
            seq = self.sequence
            self.sequence += 1
            receipt = {"schema": "native-g1g2-r30-managed-source-witness-v1",
                "complete": True, "phase": phase, "sequence": seq, "event_sequence": event_sequence,
                "row_identity": {"pid": row.identity.pid, "create_time_100ns": row.identity.create_time_100ns},
                "row_ppid": row.ppid, "row_name": row.name,
                "snapshot_row_count": sealed["row_count"], "snapshot_sha256": sealed["sha256"],
                "source": "build_pinned_r23_spi_raw_filetime"}
            append_sync(stage_dir / "managed_source_history.jsonl",
                        {"history_sequence": seq, "event_sequence": event_sequence,
                         "snapshot": sealed, "source_receipt": receipt})
            return self.lifecycle.BirthSourceWitness(row, snapshot, receipt)

        def measure_exact_handle(self, handle: int, identity: Any, row: Any, *,
                                 phase: str, event_receipt: Mapping[str, Any]) -> Mapping[str, Any]:
            values = self.lifecycle.measurement_values_for_exact_handle(handle, identity)
            before = values["handle_identity_before"]
            after = values["handle_identity_after"]
            if before != identity or after != identity or before != after:
                raise RuntimeError("exact handle identity changed across resource read")
            seq = event_receipt.get("event_sequence")
            if type(seq) is not int or seq <= 0:
                raise RuntimeError("resource event sequence is malformed")
            ident = {"pid": identity.pid, "creation_time_100ns": identity.creation_time_100ns}
            return {"schema": "fca-managed-resource-measurement-v1", "phase": phase,
                "identity": ident, "handle_identity_before": ident, "handle_identity_after": ident,
                "event_sequence": seq, "complete": True, "rss_bytes": values["rss_bytes"],
                "cpu_user_seconds": values["cpu_user_seconds"],
                "cpu_system_seconds": values["cpu_system_seconds"],
                "cmdline": list(values["cmdline"]), "source_tags": list(audit.RESOURCE_SOURCE_TAGS)}

        def record_birth_measurement(self, value: Mapping[str, Any]) -> bool:
            append_sync(stage_dir / "managed_birth_measurements.jsonl", value)
            return True

        def record_resource_measurement(self, value: Mapping[str, Any]) -> bool:
            append_sync(stage_dir / "managed_resource_measurements.jsonl", value)
            return True

        def record_lifecycle_event(self, value: Mapping[str, Any]) -> None:
            append_sync(stage_dir / "managed_lifecycle_events.jsonl", value)

        def validate_initial_loader_breakpoint(self, *args: Any, **kwargs: Any) -> bool:
            return False

    def snapshot_provider() -> Any:
        return table.validate_snapshot(table.query_native_process_table())

    def recording_snapshot_provider(records: list[Any]) -> Any:
        def capture() -> Any:
            observed = snapshot_provider()
            records.append(observed)
            return observed
        return capture

    def pair(identity: Any) -> tuple[int, int]:
        return int(identity.pid), int(identity.creation_time_100ns)

    def active(current: Any) -> set[tuple[int, int]]:
        registered = {(x["pid"], x["creation_time_100ns"])
            for x in current.summary().get("registered_identities", [])}
        exited = {pair(x.identity) for x in current.exit_receipts
            if x.exit_proof_complete is True and x.resource_measurement_complete is True}
        return registered - exited

    def exit_wire(item: Any) -> dict[str, Any]:
        i = item.identity
        return {"schema": item.schema, "identity": {"pid": i.pid, "creation_time_100ns": i.creation_time_100ns},
            "debug_event_pid": item.debug_event_pid, "debug_event_exit_code": item.debug_event_exit_code,
            "pre_continue_measurement": dict(item.pre_continue_measurement),
            "duplicate_handle_wait_result": item.duplicate_handle_wait_result,
            "retained_handle_exit_code": item.retained_handle_exit_code,
            "exit_proof_complete": item.exit_proof_complete,
            "resource_measurement_complete": item.resource_measurement_complete,
            "event_sequence": item.event_sequence, "birth_source_sequence": item.birth_source_sequence,
            "sample_attempt_id": item.sample_attempt_id}

    def verify_acks(current: Any) -> dict[str, Any]:
        expected = {(x["pid"], x["creation_time_100ns"])
                    for x in current.summary().get("registered_identities", [])}
        files = sorted(ack_dir.glob("*.ack.json"), key=lambda x: x.name)
        names = {f"{pid}_{ticks}.ack.json" for pid, ticks in expected}
        seqs: set[int] = set()
        rows = []
        for path in files:
            if path.is_symlink() or not path.is_file():
                raise RuntimeError("ACK inventory contains a nonregular file")
            raw = path.read_bytes()
            ack = core.RegistrationAck.from_mapping(
                json.loads(raw.decode("utf-8"), object_pairs_hook=_strict_json_object))
            if path.name != f"{ack.child_pid}_{ack.child_creation_time_100ns}.ack.json" or \
                    ack.session_id != current.summary().get("session_id") or \
                    ack.scope_sha256 != _ACTIVE_PROTOCOL_SHA256 or ack.registration_sequence in seqs:
                raise RuntimeError("ACK wire does not bind the managed session/identity")
            seqs.add(ack.registration_sequence)
            rows.append({"path": path.name, "bytes": len(raw), "sha256": sha256_bytes(raw),
                         "registration_sequence": ack.registration_sequence})
        complete = {p.name for p in files} == names and seqs == set(range(1, len(expected) + 1))
        return {"schema": "native-g1g2-r30-managed-ack-inventory-v1", "complete": complete,
                "expected_count": len(expected), "observed_count": len(files), "files": rows, **NO_CREDIT}

    try:
        before = snapshot_provider()
        heavy_before = audit.global_heavy_processes(before)
        if heavy_before:
            raise RuntimeError("pre-run heavy process inventory is not empty: " + repr(heavy_before))
        core_pin, core_bytes = _protocol_pin_for_path(_ACTIVE_PROTOCOL, REL_LIFECYCLE_CORE)
        core = _exec_exact_pinned_source(
            "fca_windows_process_lifecycle_r30_v1", REL_LIFECYCLE_CORE, core_pin, core_bytes)
        backend = core._Win32Api()
        monitor = core.WindowsDebugLifecycle.current_process_identity(backend)
        registry = audit.ExactHandleRegistry(identity_reader=table.read_process_handle_identity,
            closer=table.close_process_handle, strict_registered_births=True, phase_root=ack_dir)
        observer = Observer(backend, core)
        env = dict(environment)
        env.update({
            "FCA_MANAGED_SESSION_ID": secrets.token_hex(32),
            "FCA_MANAGED_ACK_DIRECTORY": str(ack_dir.resolve()),
            "FCA_MANAGED_SCOPE_SHA256": _ACTIVE_PROTOCOL_SHA256,
            "FCA_MANAGED_MONITOR_PID": str(monitor.pid),
            "FCA_MANAGED_MONITOR_CREATE_100NS": str(monitor.creation_time_100ns),
            "FCA_MANAGED_HANDSHAKE_SECONDS": "5",
        })
        started = time.monotonic()
        started_utc = utc_now()
        deadline = started + WALL_SECONDS_PER_STAGE
        stdout = (stage_dir / "stdout.raw").open("xb", buffering=0)
        stderr = (stage_dir / "stderr.raw").open("xb", buffering=0)
        stdin_handle = None
        if stdin_required:
            stdin_read_fd, stdin_write_fd = os.pipe()
            stdin_handle = int(msvcrt.get_osfhandle(stdin_read_fd))
        session = core.WindowsDebugLifecycle.spawn_suspended(
            command, str(ROOT), env, None, registry, observer, deadline,
            stdio_handles=(stdin_handle, int(msvcrt.get_osfhandle(stdout.fileno())),
                           int(msvcrt.get_osfhandle(stderr.fileno()))), native_api=backend)
        root_identity = pair(session.root_identity)
        if pair(backend.read_identity(session.root_handle)) != root_identity or \
                session.summary().get("identity_complete") is not True:
            raise RuntimeError("root CREATE is not bound to exact original handle")
        ack0 = verify_acks(session)
        if ack0.get("complete") is not True or ack0.get("observed_count") != 1:
            raise RuntimeError("root ACK was not published before resume")
        start_record = {"schema": "native-g1g2-r30-stage-start-v1", "stage": stage_name,
            "started_utc": started_utc, "argv": command, "cwd": str(ROOT), "root_pid": session.pid,
            "root_identity": _id_dict(root_identity),
            "identity_source": "source_pinned_debug_create_exact_handle_plus_r23_spi_birth_witness",
            "managed_process_lifecycle": {"schema": core.LIFECYCLE_SCHEMA, "source_pin": dict(core_pin),
                "session_id": env["FCA_MANAGED_SESSION_ID"], "scope_sha256": _ACTIVE_PROTOCOL_SHA256,
                "ack_directory": str(ack_dir), "initial_root_ack_inventory": ack0,
                "root_primary_thread_resumed_after_ack": False},
            "global_heavy_before": [list(x) for x in heavy_before],
            "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
            "wall_seconds_per_stage": WALL_SECONDS_PER_STAGE,
            "sampled_rss_stop_threshold_bytes": RSS_LIMIT_BYTES,
            "stdin_transfer": {"required": stdin_required, "expected_bytes": stdin_state["expected_bytes"],
                "expected_sha256": stdin_state["expected_sha256"],
                "source_receipt": stdin_state["source_receipt"], "writer_is_separate_from_monitor_loop": stdin_required}}
        (stage_dir / "start.json").write_text(json.dumps(start_record, indent=2, sort_keys=True), encoding="utf-8")
        # Take and persist one genuine complete resource sample while the root's
        # primary thread is still suspended.  This closes the startup window in
        # which an immediate natural exit could otherwise precede the first
        # whole-tree observation.  A failed initial sample receives no credit
        # and does not get a hidden startup retry.
        try:
            startup_active = active(session)
            if startup_active != {root_identity}:
                raise RuntimeError("suspended startup boundary is not exactly the registered root")
            startup_snapshot = snapshot_provider()
            startup_root_row = startup_snapshot.by_pid.get(root_identity[0])
            if startup_root_row is None or pair(startup_root_row.identity) != root_identity:
                raise RuntimeError("suspended startup root differs from exact pre-sample SPI")
            startup_foreign = set(audit.global_heavy_processes(startup_snapshot)) - startup_active
            if startup_foreign:
                raise RuntimeError("unowned heavy generation before suspended startup sample: " +
                                   repr(sorted(startup_foreign)))
            startup_tracked: tuple[tuple[int, int], ...] = ()
            startup_sample_snapshots: list[Any] = []
            startup_sample = audit.sample_process_tree(root_identity,
                snapshot_provider=recording_snapshot_provider(startup_sample_snapshots),
                handle_provider=session.handle_provider,
                resource_reader=session.resource_reader,
                handle_identity_reader=table.read_process_handle_identity,
                previously_tracked=startup_tracked, sample_index=1,
                elapsed_seconds=time.monotonic() - started, lifecycle_session=session,
                lifecycle_identity_factory=lambda p: core.ProcessIdentity(p[0], p[1]))
            sample_attempt_count += 1
            startup_boundary = startup_sample.get("sample_attempt_boundary")
            startup_boundary_complete = (isinstance(startup_boundary, Mapping) and
                startup_boundary.get("complete") is True and
                startup_boundary.get("membership_changed") is False and
                startup_boundary.get("pending_event_codes") == [] and
                startup_boundary.get("reason") is None)
            startup_found = {(x["pid"], x["create_time_100ns"])
                for x in startup_sample.get("discovered_identities", [])}
            startup_complete = (startup_sample.get("complete") is True and
                                startup_boundary_complete and startup_found == startup_active)
            if startup_sample.get("complete") is True and not startup_complete:
                startup_sample["complete"] = False
                startup_sample["credited_rss_bytes"] = 0
            startup_attempt = _sample_attempt_record(sample_attempt_count, 1, startup_tracked,
                startup_sample, outcome="complete_suspended_root_boundary" if startup_complete
                else "incomplete_suspended_startup_boundary")
            _append_jsonl(stage_dir / "sample_attempts.jsonl", startup_attempt)
            if not startup_complete:
                stop_reason = "resource_monitor_incomplete"
                monitor_error = {"phase": "suspended_startup_sample", "sample": startup_sample,
                                 "boundary": dict(startup_boundary) if isinstance(startup_boundary, Mapping)
                                 else None, **NO_CREDIT}
            else:
                post_startup_active = active(session)
                if post_startup_active != {root_identity}:
                    raise RuntimeError("managed membership changed across suspended startup sample")
                if len(startup_sample_snapshots) < 2:
                    raise RuntimeError("suspended startup sample did not retain both SPI boundary snapshots")
                startup_seal = _seal_native_snapshot(startup_sample_snapshots[-1], table)
                if startup_seal["row_count"] != startup_sample.get("native_snapshot_after_rows") or \
                        startup_seal["process_rows"] != [list(row) for row in
                            startup_sample.get("native_snapshot_after_digest", ())]:
                    raise RuntimeError("suspended startup sample seal differs from its exact post-sample SPI")
                startup_sample_bytes = json.dumps(startup_sample, sort_keys=True,
                    separators=(",", ":")).encode("utf-8")
                startup_acceptance = {"schema": "native-g1g2-r30-managed-boundary-confirmed-sample-v1",
                    "sample_index": 1, "sample_attempt_index": sample_attempt_count,
                    "sample_sha256": sha256_bytes(startup_sample_bytes), "sample_complete": True,
                    "sample_race_retry_used": False,
                    "after_sample_snapshot_row_count": startup_seal["row_count"],
                    "after_sample_snapshot_sha256": startup_seal["sha256"],
                    "included_as_complete_resource_observation": True, **NO_CREDIT}
                acceptances.append(startup_acceptance)
                _append_jsonl(stage_dir / "sample_boundary_acceptances.jsonl", startup_acceptance)
                samples.append(startup_sample)
                _append_jsonl(stage_dir / "samples.jsonl", startup_sample)
                startup_disposition = audit.sampled_resource_disposition(samples)
                if startup_disposition.get("disposition") == "resource_failure":
                    stop_reason = "resource_failure"
                    monitor_error = {"phase": "suspended_startup_resource_gate",
                                     "disposition": startup_disposition}
                start_record["managed_process_lifecycle"]["suspended_startup_sample"] = {
                    "sample_index": 1, "sample_attempt_index": sample_attempt_count,
                    "sample_sha256": sha256_bytes(startup_sample_bytes),
                    "sample_complete": True, "boundary_complete": True,
                    "included_as_complete_resource_observation": True, **NO_CREDIT}
                (stage_dir / "start.json").write_text(
                    json.dumps(start_record, indent=2, sort_keys=True), encoding="utf-8")
        except Exception as exc:
            stop_reason = "resource_monitor_incomplete"
            monitor_error = {"phase": "suspended_startup_sample", "type": type(exc).__name__,
                "message": str(exc), "repr": repr(exc), "winerror": getattr(exc, "winerror", None),
                **NO_CREDIT}

        if stop_reason == "natural_exit":
            session.resume_root_after_ack()
            start_record["managed_process_lifecycle"]["root_primary_thread_resumed_after_ack"] = True
            (stage_dir / "start.json").write_text(
                json.dumps(start_record, indent=2, sort_keys=True), encoding="utf-8")
            if stdin_read_fd is not None:
                os.close(stdin_read_fd)
                stdin_read_fd = None

            if stdin_required:
                def write_manifest() -> None:
                    digest = hashlib.sha256()
                    written = 0
                    view = memoryview(stdin_bytes)
                    try:
                        while written < len(view):
                            count = os.write(stdin_write_fd, view[written:min(written + 4096, len(view))])
                            if type(count) is not int or count <= 0:
                                raise OSError("managed stdin returned a nonpositive write")
                            digest.update(view[written:written + count])
                            written += count
                        os.close(stdin_write_fd)
                        stdin_state.update({"written_bytes": written, "written_sha256": digest.hexdigest(),
                                            "eof_sent": True, "complete": written == len(view) and
                                            digest.hexdigest() == stdin_state["expected_sha256"]})
                        if not stdin_state["complete"]:
                            raise OSError("managed stdin length/SHA mismatch")
                    except Exception as exc:
                        stdin_state.update({"written_bytes": written, "written_sha256": digest.hexdigest(),
                            "error": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}})
                        stdin_error.set()
                        try:
                            os.close(stdin_write_fd)
                        except Exception:
                            pass
                stdin_writer = threading.Thread(target=write_manifest, name=f"r30-stdin-{index}", daemon=True)
                stdin_writer.start()

        next_sample = time.monotonic() + SAMPLE_INTERVAL_SECONDS
        while stop_reason == "natural_exit":
            if stdin_error.is_set():
                stop_reason = "resource_monitor_incomplete"
                monitor_error = {"phase": "stdin_transfer", "transfer": dict(stdin_state)}
                break
            now = time.monotonic()
            elapsed = now - started
            if elapsed >= WALL_SECONDS_PER_STAGE:
                stop_reason = "resource_failure"
                monitor_error = {"phase": "wall_deadline", "elapsed_seconds": elapsed,
                    "limit_seconds": WALL_SECONDS_PER_STAGE, "reason": "stage_wall_deadline"}
                break
            try:
                session.poll()
                if session.returncode is not None and session.exit_proof_complete:
                    root_exit_code = session.returncode
                    break
                if now < next_sample:
                    time.sleep(min(0.05, next_sample - now))
                    continue
                if session.returncode is not None:
                    time.sleep(min(0.05, max(0.0, deadline - time.monotonic())))
                    continue
                sample_index = len(samples) + 1
                accepted = None
                retried = False
                for attempt in (1, 2):
                    active_now = active(session)
                    if root_identity not in active_now:
                        raise RuntimeError("active lifecycle registry lacks root generation")
                    tracked = tuple(sorted(active_now - {root_identity}))
                    snap = snapshot_provider()
                    root_row = snap.by_pid.get(root_identity[0])
                    if root_row is None or (root_row.identity.pid, root_row.identity.create_time_100ns) != root_identity:
                        raise RuntimeError("root identity differs from pre-sample SPI")
                    foreign = set(audit.global_heavy_processes(snap)) - active_now
                    if foreign:
                        raise RuntimeError("unowned heavy generation before sample: " + repr(sorted(foreign)))
                    sample_snapshots: list[Any] = []
                    sample = audit.sample_process_tree(root_identity,
                        snapshot_provider=recording_snapshot_provider(sample_snapshots),
                        handle_provider=session.handle_provider,
                        resource_reader=session.resource_reader,
                        handle_identity_reader=table.read_process_handle_identity,
                        previously_tracked=tracked, sample_index=sample_index,
                        elapsed_seconds=time.monotonic() - started, lifecycle_session=session,
                        lifecycle_identity_factory=lambda p: core.ProcessIdentity(p[0], p[1]))
                    sample_attempt_count += 1
                    boundary = sample.get("sample_attempt_boundary")
                    if sample.get("complete") is True:
                        found = {(x["pid"], x["create_time_100ns"]) for x in sample.get("discovered_identities", [])}
                        if found != active_now:
                            sample["complete"] = False
                            sample["credited_rss_bytes"] = 0
                    if sample.get("complete") is True:
                        _append_jsonl(stage_dir / "sample_attempts.jsonl", _sample_attempt_record(
                            sample_attempt_count, sample_index, tracked, sample,
                            outcome="complete_managed_boundary"))
                        accepted = sample
                        break
                    events = boundary.get("released_boundary_events") if isinstance(boundary, Mapping) else None
                    event_rows = events.get("events") if isinstance(events, Mapping) else None
                    retry = (attempt == 1 and isinstance(boundary, Mapping) and
                             boundary.get("membership_changed") is True and
                             isinstance(events, Mapping) and events.get("complete") is True and
                             type(events.get("count")) is int and events["count"] > 0 and
                             type(event_rows) is list and len(event_rows) == events["count"] and
                             boundary.get("release_error") is None)
                    evidence = {"schema": "native-g1g2-r30-managed-boundary-retry-v1",
                        "complete": retry, "retry_authorized": retry, "tick_attempt": attempt,
                        "retry_limit": 1, "boundary": dict(boundary) if isinstance(boundary, Mapping) else None,
                        "partial_sample_resource_credit": False, **NO_CREDIT}
                    _append_jsonl(stage_dir / "sample_attempts.jsonl", _sample_attempt_record(
                        sample_attempt_count, sample_index, tracked, sample,
                        outcome="retry_after_exact_held_boundary_events" if retry else "incomplete_unrecovered",
                        recovery=evidence))
                    if not retry:
                        monitor_error = {"phase": "managed_sample", "sample": sample,
                                         "boundary_retry": evidence}
                        stop_reason = "resource_monitor_incomplete"
                        break
                    sample_recovery_count += 1
                    retried = True
                if stop_reason != "natural_exit":
                    break
                if accepted is None:
                    stop_reason = "resource_monitor_incomplete"
                    monitor_error = {"phase": "managed_sample", "reason": "two whole-sample attempts failed"}
                    break
                raw = json.dumps(accepted, sort_keys=True, separators=(",", ":")).encode("utf-8")
                if len(sample_snapshots) < 2:
                    raise RuntimeError("complete sample did not retain both SPI boundary snapshots")
                seal = _seal_native_snapshot(sample_snapshots[-1], table)
                if seal["row_count"] != accepted.get("native_snapshot_after_rows") or \
                        seal["process_rows"] != [list(row) for row in
                            accepted.get("native_snapshot_after_digest", ())]:
                    raise RuntimeError("sample acceptance seal differs from its exact post-sample SPI")
                acceptance = {"schema": "native-g1g2-r30-managed-boundary-confirmed-sample-v1",
                    "sample_index": sample_index, "sample_attempt_index": sample_attempt_count,
                    "sample_sha256": sha256_bytes(raw), "sample_complete": True,
                    "sample_race_retry_used": retried,
                    "after_sample_snapshot_row_count": seal["row_count"],
                    "after_sample_snapshot_sha256": seal["sha256"],
                    "included_as_complete_resource_observation": True, **NO_CREDIT}
                acceptances.append(acceptance)
                _append_jsonl(stage_dir / "sample_boundary_acceptances.jsonl", acceptance)
                samples.append(accepted)
                _append_jsonl(stage_dir / "samples.jsonl", accepted)
                disposition = audit.sampled_resource_disposition(samples)
                if disposition.get("disposition") == "resource_failure":
                    stop_reason = "resource_failure"
                    monitor_error = {"phase": "sampled_resource_gate", "disposition": disposition}
                    break
                next_sample = time.monotonic() + SAMPLE_INTERVAL_SECONDS
            except Exception as exc:
                stop_reason = "resource_monitor_incomplete"
                monitor_error = {"phase": "managed_stage_monitor", "type": type(exc).__name__,
                    "message": str(exc), "repr": repr(exc), "winerror": getattr(exc, "winerror", None)}
                break

    except Exception as exc:
        stop_reason = "resource_monitor_incomplete"
        monitor_error = {"phase": "managed_launch_or_monitor", "type": type(exc).__name__,
            "message": str(exc), "repr": repr(exc), "winerror": getattr(exc, "winerror", None)}
        if session is None:
            session = getattr(exc, "session", None)
    finally:
        if stdin_read_fd is not None:
            try:
                os.close(stdin_read_fd)
            except Exception:
                stop_reason = "resource_monitor_incomplete"
            stdin_read_fd = None
        if session is not None and stop_reason != "natural_exit":
            termination_requested = True
            try:
                session.terminate()
            except Exception as exc:
                termination_error = {"type": type(exc).__name__, "message": str(exc),
                                     "repr": repr(exc), "winerror": getattr(exc, "winerror", None)}
            while time.monotonic() < deadline and not session.exit_proof_complete:
                try:
                    if session.returncode is None:
                        session.wait(min(0.05, deadline - time.monotonic()))
                    else:
                        session.poll()
                        time.sleep(min(0.01, max(0.0, deadline - time.monotonic())))
                except TimeoutError:
                    continue
                except Exception as exc:
                    monitor_error = monitor_error or {"phase": "managed_cleanup_wait",
                        "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}
                    break
        if stdin_writer is not None:
            stdin_writer.join(timeout=min(0.25, max(0.0, deadline - time.monotonic())))
            if stdin_writer.is_alive():
                stdin_state["complete"] = False
                stdin_state["error"] = stdin_state.get("error") or {"type": "WriterStillActive"}
                stop_reason = "resource_monitor_incomplete"
        if stdin_required and not stdin_state.get("complete"):
            stop_reason = "resource_monitor_incomplete"
        if session is not None:
            try:
                if session.exit_proof_complete:
                    cleanup_summary = dict(session.close())
                    lifecycle_summary = dict(session.summary())
                    close_receipt = {"complete": lifecycle_summary.get("cleanup_complete") is True,
                        "cleanup_summary": cleanup_summary,
                        "closed_owned_handles": cleanup_summary.get("closed_owned_handles", []),
                        "cleanup_errors": cleanup_summary.get("cleanup_errors", [])}
                    root_exit_code = session.returncode
                else:
                    lifecycle_summary = dict(session.summary())
                    close_receipt = {"complete": False, "reason": "exit proof incomplete; handles retained",
                                     "lifecycle_summary": lifecycle_summary, **NO_CREDIT}
                    stop_reason = "resource_monitor_incomplete"
            except Exception as exc:
                lifecycle_summary = dict(session.summary())
                close_receipt = {"complete": False, "error": {"type": type(exc).__name__,
                    "message": str(exc), "repr": repr(exc)}, "lifecycle_summary": lifecycle_summary, **NO_CREDIT}
                stop_reason = "resource_monitor_incomplete"
        for stream in (stdout, stderr):
            if stream is not None:
                try:
                    stream.close()
                except Exception as exc:
                    stop_reason = "resource_monitor_incomplete"
                    monitor_error = monitor_error or {"phase": "log_close", "type": type(exc).__name__,
                                                      "message": str(exc), "repr": repr(exc)}
        if stdin_write_fd is not None and (stdin_writer is None or not stdin_writer.is_alive()):
            try:
                os.close(stdin_write_fd)
            except OSError:
                pass
            stdin_write_fd = None

    exit_receipts: list[dict[str, Any]] = []
    if session is not None:
        try:
            lifecycle_summary = dict(session.summary())
            exit_receipts = [exit_wire(x) for x in session.exit_receipts]
            root_identity = pair(session.root_identity)
            roots = [x for x in exit_receipts if x.get("identity") == _id_dict(root_identity)]
            if len(roots) == 1 and roots[0].get("exit_proof_complete") is True and \
                    roots[0].get("resource_measurement_complete") is True:
                root_exit_code = roots[0]["retained_handle_exit_code"]
            ack_inventory = verify_acks(session)
            loader = [x for x in lifecycle_summary.get("event_receipts", [])
                      if isinstance(x, Mapping) and x.get("event") == "initial_loader_breakpoint"]
            count = lifecycle_summary.get("registration_count")
            loader_ok = (type(count) is int and len(loader) == count and
                all(isinstance(x.get("native_witness"), Mapping) and
                    x["native_witness"].get("complete") is True for x in loader) and
                lifecycle_summary.get("module_lineage_errors") == {})
            lifecycle_summary["initial_loader_witness_complete"] = loader_ok
            if not loader_ok or ack_inventory.get("complete") is not True:
                stop_reason = "resource_monitor_incomplete"
                monitor_error = monitor_error or {"phase": "managed_identity_or_loader_receipt",
                    "loader_event_count": len(loader), "registration_count": count,
                    "ack_inventory": ack_inventory, **NO_CREDIT}
        except Exception as exc:
            stop_reason = "resource_monitor_incomplete"
            monitor_error = monitor_error or {"phase": "managed_final_summary",
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}

    try:
        final_snapshot = snapshot_provider()
        registered = {(x["pid"], x["creation_time_100ns"])
                      for x in lifecycle_summary.get("registered_identities", [])}
        residual = audit.audit_residual_identities(registered, final_snapshot)
        heavy_after = audit.global_heavy_processes(final_snapshot)
        residual_complete = residual.get("complete") is True and residual.get("residual_clear") is True and not heavy_after
    except Exception as exc:
        residual = {"complete": False, "residual_clear": False,
            "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}, **NO_CREDIT}
    if not residual_complete or close_receipt.get("complete") is not True:
        stop_reason = "resource_monitor_incomplete"
        monitor_error = monitor_error or {"phase": "final_cleanup_or_residual", "residual": residual,
                                          "close_receipt": close_receipt, **NO_CREDIT}

    disposition = audit.sampled_resource_disposition(samples) if samples else {
        "disposition": "resource_monitor_incomplete", "complete": False,
        "reason": "no_complete_samples", **NO_CREDIT}
    if stop_reason == "resource_failure" and disposition.get("disposition") != "resource_failure":
        disposition = {"disposition": "resource_failure", "complete": True,
            "reason": "stage_wall_deadline", **NO_CREDIT}
    elif stop_reason == "resource_monitor_incomplete":
        disposition = {"disposition": "resource_monitor_incomplete", "complete": False,
            "reason": "managed_monitor_or_residual_audit_incomplete", **NO_CREDIT}
    all_exits = bool(exit_receipts) and all(x.get("exit_proof_complete") is True and
        x.get("resource_measurement_complete") is True for x in exit_receipts)
    all_samples = bool(samples) and len(acceptances) == len(samples) and all(
        x.get("sample_complete") is True and x.get("included_as_complete_resource_observation") is True
        for x in acceptances)
    boundaries_complete = bool(samples) and all(
        isinstance(sample.get("sample_attempt_boundary"), Mapping) and
        sample["sample_attempt_boundary"].get("complete") is True and
        sample["sample_attempt_boundary"].get("membership_changed") is False and
        sample["sample_attempt_boundary"].get("pending_event_codes") == [] and
        sample["sample_attempt_boundary"].get("reason") is None
        for sample in samples)
    monitor_complete = (stop_reason == "natural_exit" and residual_complete and all_exits and all_samples and
        boundaries_complete and lifecycle_summary.get("exit_proof_complete") is True and
        lifecycle_summary.get("cleanup_complete") is True and
        lifecycle_summary.get("initial_loader_witness_complete") is True and
        ack_inventory.get("complete") is True and disposition.get("complete") is True and
        stdin_state.get("complete") is True)
    roots = [x for x in exit_receipts if root_identity is not None and x.get("identity") == _id_dict(root_identity)]
    final = {
        "schema": "native-g1g2-r30-stage-final-v1", "stage": stage_name,
        "started_utc": started_utc, "finished_utc": utc_now(),
        "elapsed_seconds": time.monotonic() - started, "argv": command,
        "root_identity": _id_dict(root_identity) if root_identity else None,
        "root_exit_code": root_exit_code, "root_exit_receipt": roots[0] if len(roots) == 1 else None,
        "stage_exit_receipts": exit_receipts, "all_stage_exit_receipts_complete": all_exits,
        "samples": samples, "sample_attempts_path": "sample_attempts.jsonl",
        "sample_boundary_acceptances": acceptances,
        "sample_boundary_acceptances_path": "sample_boundary_acceptances.jsonl",
        "all_samples_boundary_confirmed": all_samples,
        "boundary_reconciliations": [], "boundary_reconciliations_path": "boundary_reconciliations.jsonl",
        "all_boundary_reconciliations_complete": boundaries_complete,
        "sample_attempt_count": sample_attempt_count, "sample_recovery_count": sample_recovery_count,
        "unaccounted_observed_generations": [], "resource_disposition": disposition,
        "stop_reason": stop_reason,
        "termination_receipt": {"schema": "native-g1g2-r30-managed-termination-v1",
            "termination_requested": termination_requested,
            "termination_error": termination_error,
            "exit_proof_complete": lifecycle_summary.get("exit_proof_complete") is True,
            "cleanup_complete": lifecycle_summary.get("cleanup_complete") is True,
            "complete": lifecycle_summary.get("exit_proof_complete") is True and
                        lifecycle_summary.get("cleanup_complete") is True, **NO_CREDIT} if session is not None else None,
        "final_residual_audit": residual, "global_heavy_before": [list(x) for x in heavy_before],
        "global_heavy_after": [list(x) for x in heavy_after], "handle_close_receipt": close_receipt,
        "stdin_transfer": dict(stdin_state),
        "managed_process_lifecycle": {"summary": lifecycle_summary, "cleanup_summary": cleanup_summary,
            "ack_inventory": ack_inventory, "source_receipt_paths": ["managed_source_history.jsonl",
            "managed_birth_measurements.jsonl", "managed_resource_measurements.jsonl",
            "managed_lifecycle_events.jsonl"]},
        "resource_monitor_complete": monitor_complete, "monitor_error": monitor_error, **NO_CREDIT}
    (stage_dir / "final.json").write_text(json.dumps(final, indent=2, sort_keys=True), encoding="utf-8")
    return final


def _stage_pass(output: Path, stage: Mapping[str, Any], stage_index: int) -> tuple[bool, str | None]:
    if stage.get("stop_reason") != "natural_exit":
        return False, f"{stage.get('stage')}: stop_reason={stage.get('stop_reason')}"
    if stage.get("root_exit_code") != 0:
        return False, f"{stage.get('stage')}: natural root exit code is not zero"
    if stage.get("resource_monitor_complete") is not True:
        return False, f"{stage.get('stage')}: monitor or residual audit incomplete"
    if stage.get("protocol_file_integrity_complete") is not True:
        return False, f"{stage.get('stage')}: loaded protocol file identity incomplete"
    if stage.get("source_integrity_complete") is not True:
        return False, f"{stage.get('stage')}: R30 owned source pin changed or could not be verified"
    if stage.get("stage") == "parse_all" and \
            stage.get("stdin_transfer", {}).get("complete") is not True:
        return False, "parse_all: pinned manifest stdin transfer incomplete"
    raw = (output / f"{stage_index:02d}_{stage['stage']}" / "stdout.raw").read_text(
        encoding="utf-8", errors="replace")
    marker = "NG12_PARSE status=pass files=108" if stage["stage"] == "parse_all" else (
        f"NG12_RESULT mode={'primary' if stage['stage'] == 'primary' else 'replay'} status=pass")
    if marker not in raw:
        return False, f"{stage.get('stage')}: required consumer marker missing"
    if stage["stage"] == "parse_all" and PARSE_REBINDING_MARKER not in raw:
        return False, "parse_all: required current-source rebinding marker missing"
    return True, None


def _run_stage_sequence(output: Path, commands: list[Mapping[str, Any]],
                        protocol: Mapping[str, Any], environment: Mapping[str, str],
                        table: Any, audit: Any, protocol_path: Path,
                        loaded_protocol_receipt: Mapping[str, Any]
                        ) -> tuple[list[dict[str, Any]], str | None]:
    """Run stages serially and stop immediately on any incomplete receipt."""
    stages: list[dict[str, Any]] = []
    for index, plan in enumerate(commands, 1):
        try:
            protocol_before = verify_loaded_protocol_file(
                protocol_path, loaded_protocol_receipt, f"before_{plan['stage']}")
            source_before = verify_owned_source_pins(
                protocol, f"before_{plan['stage']}")
            parent_before = verify_r29_parent_protocol(
                protocol, f"before_{plan['stage']}")
            current_before = verify_current_input_rebindings(
                protocol, f"before_{plan['stage']}")
            lifecycle_before = verify_managed_lifecycle_source_pins(
                protocol, f"before_{plan['stage']}")
        except Exception as exc:
            return stages, (
                f"{plan.get('stage')}: protocol/source preflight failed: "
                f"{type(exc).__name__}: {exc}")
        stdin_bytes: bytes | None = None
        stdin_receipt: dict[str, Any] | None = None
        stdin_path = plan.get("stdin_provider_path")
        if stdin_path is not None:
            if _INPUT_PROVIDER is None or stdin_path != REL_PARSE_MANIFEST:
                return stages, "parse_all: unsupported or unbound stdin provider path"
            try:
                stdin_bytes, stdin_receipt = prepare_parse_manifest_stdin(
                    _INPUT_PROVIDER, plan.get("stdin_manifest_contract"))
            except Exception as exc:
                return stages, f"parse_all: provider manifest bytes differ from the original pin: {exc}"
        stage = dict(_run_stage(output, index, plan["stage"], plan["argv"],
                                environment, table, audit, stdin_bytes, stdin_receipt))
        try:
            protocol_after = verify_loaded_protocol_file(
                protocol_path, loaded_protocol_receipt, f"after_{plan['stage']}")
            protocol_unchanged = _exact_json_equal(
                {key: value for key, value in protocol_before.items()
                 if key not in ("phase", "complete")},
                {key: value for key, value in protocol_after.items()
                 if key not in ("phase", "complete")})
        except Exception as exc:
            protocol_after = {"phase": f"after_{plan['stage']}", "complete": False,
                              "error": {"type": type(exc).__name__, "message": str(exc),
                                        "repr": repr(exc)}}
            protocol_unchanged = False
        try:
            source_after = verify_owned_source_pins(
                protocol, f"after_{plan['stage']}")
            parent_after = verify_r29_parent_protocol(
                protocol, f"after_{plan['stage']}")
            current_after = verify_current_input_rebindings(
                protocol, f"after_{plan['stage']}")
            lifecycle_after = verify_managed_lifecycle_source_pins(
                protocol, f"after_{plan['stage']}")
            sources_unchanged = source_before["rows"] == source_after["rows"] and \
                parent_before == {**parent_after, "phase": parent_before["phase"]}
            current_unchanged = current_before["rows"] == current_after["rows"] and \
                current_before["preimage_receipts"] == current_after["preimage_receipts"]
            lifecycle_unchanged = lifecycle_before["rows"] == lifecycle_after["rows"]
            sources_unchanged = sources_unchanged and current_unchanged and lifecycle_unchanged
        except Exception as exc:
            source_after = {"phase": f"after_{plan['stage']}", "complete": False,
                            "error": {"type": type(exc).__name__, "message": str(exc),
                                      "repr": repr(exc)}}
            parent_after = {"phase": f"after_{plan['stage']}", "complete": False,
                            "error": {"type": type(exc).__name__, "message": str(exc),
                                      "repr": repr(exc)}}
            current_after = {"phase": f"after_{plan['stage']}", "complete": False,
                             "error": {"type": type(exc).__name__, "message": str(exc),
                                       "repr": repr(exc)}}
            lifecycle_after = {"phase": f"after_{plan['stage']}", "complete": False,
                               "error": {"type": type(exc).__name__, "message": str(exc),
                                         "repr": repr(exc)}}
            sources_unchanged = False
        stage["protocol_file_before"] = protocol_before
        stage["protocol_file_after"] = protocol_after
        stage["protocol_file_integrity_complete"] = bool(
            protocol_before.get("complete") is True and
            protocol_after.get("complete") is True and protocol_unchanged)
        if not stage["protocol_file_integrity_complete"]:
            stage["stop_reason"] = "protocol_file_drift"
            stage["protocol_file_integrity_error"] = {
                "reason": "R30 protocol file no longer matches the exact bytes parsed at load time",
                **NO_CREDIT,
            }
        stage["owned_source_pins_before"] = source_before
        stage["owned_source_pins_after"] = source_after
        stage["r29_parent_protocol_before"] = parent_before
        stage["r29_parent_protocol_after"] = parent_after
        stage["current_input_rebindings_before"] = current_before
        stage["current_input_rebindings_after"] = current_after
        stage["managed_process_lifecycle_source_pins_before"] = lifecycle_before
        stage["managed_process_lifecycle_source_pins_after"] = lifecycle_after
        stage["source_integrity_complete"] = bool(
            source_before.get("complete") is True and source_after.get("complete") is True and
            current_before.get("complete") is True and current_after.get("complete") is True and
            lifecycle_before.get("complete") is True and lifecycle_after.get("complete") is True and
            sources_unchanged)
        if stage["protocol_file_integrity_complete"] and \
                not stage["source_integrity_complete"]:
            stage["stop_reason"] = "owned_source_drift"
            stage["source_integrity_error"] = {
                "reason": "R30 owned source or R29 parent protocol identity changed or could not be reverified",
                **NO_CREDIT,
            }
        final_path = output / f"{index:02d}_{plan['stage']}" / "final.json"
        final_path.write_text(json.dumps(stage, indent=2, sort_keys=True), encoding="utf-8")
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
    global _ACTIVE_PROTOCOL, _ACTIVE_PROTOCOL_SHA256
    protocol, loaded_protocol_receipt = load_protocol_with_receipt(protocol_path)
    _ACTIVE_PROTOCOL = protocol
    _ACTIVE_PROTOCOL_SHA256 = loaded_protocol_receipt["sha256"]
    bind_input_provider(protocol)
    validate_protocol_shape(protocol)
    validate_invocation("actual_supervisor", observed_argv, protocol)
    protocol_loaded_check = verify_loaded_protocol_file(
        protocol_path, loaded_protocol_receipt, "after_protocol_validation")
    if os.name != "nt":
        raise PreflightError("R23 exact process-table runtime is Windows-only")
    if output.resolve() != repo_path(REL_OUTPUT).resolve():
        raise PreflightError("runtime output must equal the single frozen actual leaf")
    if output.exists():
        raise PreflightError("runtime output leaf already exists; choose a new version, never overwrite")
    pins = verify_input_pins(protocol, "pre_dispatch")
    protocol_dispatch_check = verify_loaded_protocol_file(
        protocol_path, loaded_protocol_receipt, "before_dispatch_output_creation")
    table, audit = _load_r23(protocol)
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
        "schema": "native-g1g2-r30-prelaunch-receipt-v1",
        "created_utc": utc_now(), "protocol_sha256": loaded_protocol_receipt["sha256"],
        "protocol_file_at_load": loaded_protocol_receipt,
        "protocol_file_after_validation": protocol_loaded_check,
        "protocol_file_before_dispatch": protocol_dispatch_check,
        "actual_supervisor_argv": observed_argv, "input_pin_count": pins["checked_count"],
        "input_pins_before": pins, "process_table_before": table.smoke_summary(before_snapshot),
        "global_heavy_before": [list(x) for x in heavy_before],
        "runtime_executed": True, "numerical_credit": False, "physical_credit": False,
    }, indent=2, sort_keys=True), encoding="utf-8")
    environment = _set_environment(protocol)
    commands = planned_stage_commands(protocol, output)
    stages, failure = _run_stage_sequence(
        output, commands, protocol, environment, table, audit,
        protocol_path, loaded_protocol_receipt)
    if failure is None and len(stages) == len(STAGES):
        artifact = output / "artifacts" / "primary.bin"
        required_artifacts = [artifact, Path(str(artifact) + ".preassert.bin"),
            Path(str(artifact) + ".wrong-sign-preassert.bin"),
            Path(str(artifact) + ".replay-preassert.bin")]
        missing = [str(p) for p in required_artifacts if not p.is_file()]
        if missing:
            failure = "consumer artifact/checkpoint missing: " + ", ".join(missing)
    try:
        after_pins = verify_input_pins(protocol, "post_dispatch")
    except Exception as exc:
        after_pins = {"complete": False, "phase": "post_dispatch",
                      "error": {"type": type(exc).__name__, "message": str(exc),
                                "repr": repr(exc)}}
        failure = failure or "post-dispatch input/source pin verification failed"
    try:
        protocol_after_dispatch = verify_loaded_protocol_file(
            protocol_path, loaded_protocol_receipt, "after_dispatch")
        protocol_file_unchanged = _exact_json_equal(
            {key: value for key, value in protocol_after_dispatch.items()
             if key not in ("phase", "complete")},
            dict(loaded_protocol_receipt))
    except Exception as exc:
        protocol_after_dispatch = {
            "phase": "after_dispatch", "complete": False,
            "error": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}}
        protocol_file_unchanged = False
        failure = failure or "post-dispatch protocol file identity verification failed"
    after_snapshot = table.query_native_process_table()
    residual_heavy = audit.global_heavy_processes(after_snapshot)
    if residual_heavy:
        failure = failure or "post-run global heavy process inventory is nonempty"
    owned_sources_unchanged = after_pins.get("complete") is True and \
        pins.get("owned_sources", {}).get("rows") == \
        after_pins.get("owned_sources", {}).get("rows")
    parent_before = pins.get("r29_parent_protocol", {})
    parent_after = after_pins.get("r29_parent_protocol", {})
    r29_parent_unchanged = after_pins.get("complete") is True and \
        parent_before.get("complete") is True and parent_after.get("complete") is True and \
        all(parent_before.get(key) == parent_after.get(key) for key in (
            "path", "bytes", "sha256", "input_pin_count", "input_pins_exactly_match"))
    if not owned_sources_unchanged:
        failure = failure or "R30 owned source pins changed between pre/post dispatch"
    if not r29_parent_unchanged:
        failure = failure or "R29 parent protocol identity changed between pre/post dispatch"
    if not protocol_file_unchanged:
        failure = failure or "R30 protocol file changed after its exact bytes were parsed"
    complete = failure is None and len(stages) == len(STAGES) and \
        all(stage.get("resource_monitor_complete") is True and
            stage.get("source_integrity_complete") is True and
            stage.get("protocol_file_integrity_complete") is True for stage in stages) and \
        owned_sources_unchanged and r29_parent_unchanged and protocol_file_unchanged
    summary = {
        "schema": SUMMARY_SCHEMA, "created_utc": utc_now(),
        "runtime_executed": True,
        "formal_consumer": "NativeG1G2DiffusionCompilerV1 -> GridapNativeG1G2DiffusionAdapterV1",
        "unique_consumer_script": REL_FOCUSED,
        "status": "focused_consumer_pass" if complete else "not_established",
        "failure": failure, "stage_order": [stage["stage"] for stage in stages],
        "stages": stages, "input_pins_before": pins,
        "input_pins_after": after_pins,
        "protocol_file_at_load": loaded_protocol_receipt,
        "protocol_file_after_dispatch": protocol_after_dispatch,
        "protocol_file_unchanged": protocol_file_unchanged,
        "input_pins_unchanged": pins.get("checked") == after_pins.get("checked"),
        "owned_source_pins_unchanged": owned_sources_unchanged,
        "r29_parent_protocol_unchanged": r29_parent_unchanged,
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
