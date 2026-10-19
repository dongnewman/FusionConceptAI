#!/usr/bin/env python3
"""Read-only post-run verification of the archived MMS replay-only R10 attempt."""

from __future__ import annotations

import hashlib
import json
import math
import os
import pathlib
import sys
from datetime import datetime, timezone


REPO = pathlib.Path(__file__).resolve().parents[3]
BASE = REPO / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r10"
RUN = BASE / "runtime_replay_r10"
PROTOCOL = BASE / "replay_protocol_v10.json"
EVIDENCE = REPO / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/independent_replay_r10_postrun_tester_20260924"
EXPECTED_PROTOCOL_SHA256 = "d479581b3a4bd0624a6f1d06513d3323ca37739cc83fa9eb03397f77cfc0e340"
EXPECTED_V10_SOURCE_INPUT_MANIFEST_SHA256 = "057d32f6bee2b1f771c039a7bc0a085dbdd5adb556a779013104d69267b5247b"
PHASES = (
    "canonical_body_parse",
    "concrete_type_check",
    "json3_typed_parse",
    "result_digest_injection",
    "semantic_hash_recompute",
    "typed_wire_encoding",
)


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def read_json(path: pathlib.Path) -> object:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def require(condition: bool, label: str, failures: list[str]) -> None:
    if not condition:
        failures.append(label)


def current_pin_rows(entries: list[dict], repo: pathlib.Path, failures: list[str]) -> list[dict]:
    rows = []
    seen: set[str] = set()
    for item in entries:
        rel = item.get("path")
        key = os.path.normcase(os.path.normpath(rel)) if isinstance(rel, str) else "<invalid>"
        require(key not in seen, f"duplicate_snapshot_path:{rel}", failures)
        seen.add(key)
        path = repo / pathlib.Path(rel.replace("/", os.sep)) if isinstance(rel, str) else repo / "<invalid>"
        exists = path.is_file()
        size = path.stat().st_size if exists else None
        actual = sha256_file(path) if exists else None
        status = "match" if exists and size == item.get("bytes") and actual == item.get("sha256") else "mismatch"
        rows.append({
            "path": rel,
            "expected_bytes": item.get("bytes"),
            "actual_bytes": size,
            "expected_sha256": item.get("sha256"),
            "actual_sha256": actual,
            "status": status,
        })
        require(status == "match", f"current_input_pin:{rel}", failures)
    return rows


def main() -> int:
    EVIDENCE.mkdir(parents=True, exist_ok=False)
    failures: list[str] = []
    run_before = {p.relative_to(RUN).as_posix(): (p.stat().st_size, sha256_file(p)) for p in sorted(RUN.rglob("*")) if p.is_file()}
    protocol_sha = sha256_file(PROTOCOL)
    protocol_bytes = PROTOCOL.read_bytes()
    protocol = read_json(PROTOCOL)
    source_v10_protocol_path = REPO / pathlib.Path(protocol.get("v10_protocol", {}).get("path", "<invalid>"))
    source_v10_protocol = read_json(source_v10_protocol_path) if source_v10_protocol_path.is_file() else {}
    final_path = RUN / "final.json"
    process_path = RUN / "producer_process.json"
    before_path = RUN / "inputs_before.json"
    after_path = RUN / "inputs_after.json"
    process_dir = RUN / "producer_process"
    producer_stdout_path = process_dir / "stdout.raw"
    producer_stderr_path = process_dir / "stderr.raw"
    failure_path = process_dir / "numerical/producer_failure.json"

    final = read_json(final_path)
    process = read_json(process_path)
    before_raw = before_path.read_bytes()
    after_raw = after_path.read_bytes()
    before = json.loads(before_raw)
    after = json.loads(after_raw)
    producer_after_raw = (process_dir / "inputs_after.json").read_bytes()
    producer_after = json.loads(producer_after_raw)
    failure = read_json(failure_path)

    require(protocol_sha == EXPECTED_PROTOCOL_SHA256, "protocol_sha256", failures)
    require(protocol.get("schema") == "mms-replay-only-continuation-protocol-v10", "protocol_schema", failures)
    require(protocol.get("output_leaf") == RUN.relative_to(REPO).as_posix(), "protocol_output_leaf", failures)
    require(protocol.get("v10_protocol", {}).get("input_manifest_before_sha256") == EXPECTED_V10_SOURCE_INPUT_MANIFEST_SHA256, "source_v10_before_manifest_hash_pin", failures)
    require(protocol.get("v10_protocol", {}).get("input_manifest_after_sha256") == EXPECTED_V10_SOURCE_INPUT_MANIFEST_SHA256, "source_v10_after_manifest_hash_pin", failures)
    require(protocol.get("v10_protocol", {}).get("input_manifest_before_after_equal") is True, "protocol_snapshot_equal_claim", failures)
    require(before_raw == after_raw and before == after, "before_after_input_snapshot_exact_equal", failures)
    require(producer_after_raw == after_raw and producer_after == after, "producer_local_after_snapshot_matches_final", failures)
    require(len(before) == 351 and len(after) == 351, "snapshot_entry_count_351", failures)
    live_pin_rows = current_pin_rows(before, REPO, failures)
    require(len(live_pin_rows) == 351, "live_input_rehash_count_351", failures)
    source_inputs = source_v10_protocol.get("inputs", [])
    current_by_path = {row.get("path"): row for row in before if isinstance(row, dict)}
    source_input_matches = []
    for pin in source_inputs:
        row = current_by_path.get(pin.get("path"))
        match = bool(row and row.get("bytes") == pin.get("bytes") and row.get("sha256") == pin.get("sha256"))
        source_input_matches.append(match)
        require(match, f"source_v10_protocol_input_join:{pin.get('path')}", failures)
    require(len(source_inputs) == protocol.get("v10_protocol", {}).get("pinned_input_count") == 89, "source_v10_pin_count_89", failures)
    require(sha256_file(source_v10_protocol_path) == protocol.get("v10_protocol", {}).get("sha256"), "source_v10_protocol_sha", failures)

    # The child command is historical evidence only; this checker never invokes it.
    child_command = process.get("command", [])
    require(len(child_command) == 10, "producer_command_argv_length_10", failures)
    require(len(child_command) > 7 and child_command[4] == "producer", "producer_mode_argv", failures)
    require(len(child_command) > 7 and child_command[7] == protocol_sha, "producer_command_protocol_hash", failures)
    require(process.get("exit_code") == 72 and process.get("stop_reason") == "exited", "producer_child_exit_72_natural", failures)
    require(final.get("controller_exit_code") == 72 and final.get("classification") == "replay_hydration_unsupported", "controller_exit_72_hydration_unsupported", failures)
    require(final.get("solver_exit_code") == 2, "preserved_solver_exit_code_2", failures)
    require(final.get("formal_candidate_credit") is False and final.get("authority") == "no_publish", "no_formal_credit_no_publish", failures)

    raw_stdout = producer_stdout_path.read_bytes()
    raw_stderr = producer_stderr_path.read_bytes()
    expected_stdout = process.get("stdout", {})
    expected_stderr = process.get("stderr", {})
    require(expected_stdout.get("bytes") == len(raw_stdout) and expected_stdout.get("sha256") == digest_bytes(raw_stdout), "producer_stdout_receipt_join", failures)
    require(expected_stderr.get("bytes") == len(raw_stderr) and expected_stderr.get("sha256") == digest_bytes(raw_stderr), "producer_stderr_receipt_join", failures)
    stage = final.get("stages", [{}])[0] if final.get("stages") else {}
    require(len(final.get("stages", [])) == 1 and stage.get("stage") == "producer", "single_producer_stage_only", failures)
    require(stage.get("exit_code") == process.get("exit_code") == 72, "stage_process_exit_join", failures)
    require(stage.get("stdout") == expected_stdout and stage.get("stderr") == expected_stderr, "final_stage_raw_receipt_join", failures)
    require(b"MMS_REPLAY_ONLY mode=producer" in raw_stdout, "raw_stdout_producer_marker", failures)
    require(b"MMS_REPLAY_ONLY_FAIL classification=replay_hydration_unsupported" in raw_stderr, "raw_stderr_hydration_failure_marker", failures)
    require(b"spatial result hash mismatch" in raw_stderr, "raw_stderr_spatial_hash_error", failures)

    require(failure.get("schema") == "mms-replay-only-failure-v1", "producer_failure_schema", failures)
    require(failure.get("classification") == "replay_hydration_unsupported", "producer_failure_classification", failures)
    require(failure.get("phase") == "typed_result_hydration", "producer_failure_phase", failures)
    require(failure.get("hydration_stage") == "canonical_result_hash_check", "producer_failure_hash_check_stage", failures)
    require(failure.get("error") == "ArgumentError: spatial result hash mismatch", "producer_failure_hash_mismatch", failures)
    require(failure.get("solver_exit_code") == 2, "producer_failure_preserved_solver_status", failures)
    phase_rows = []
    for name in PHASES:
        path = process_dir / "numerical/hydration_phases" / f"{name}.json"
        phase = read_json(path)
        phase_rows.append({"phase": name, "bytes": path.stat().st_size, "sha256": sha256_file(path), **phase})
        require(phase.get("phase") == name and phase.get("completed") is True, f"hydration_phase_completed:{name}", failures)
        require(phase.get("classification") == "test_only_continuation", f"hydration_phase_scope:{name}", failures)
    require(not (process_dir / "numerical/producer_complete.json").exists(), "producer_did_not_complete", failures)
    require(not (RUN / "consumer_process").exists() and not (RUN / "consumer_process.json").exists(), "consumer_never_started", failures)
    require(final.get("nonlinear_solves") == 0, "no_nonlinear_solve", failures)
    require(final.get("inputs_unchanged") is True, "final_inputs_unchanged", failures)
    require(final.get("software_complete") is False and final.get("numerical_status") == "fail", "final_not_complete", failures)
    require(final.get("physical_validation") == "unsupported", "physical_validation_unsupported", failures)

    # This controller field is a positive-proof flag, not a change detector.
    controller_path = REPO / "test/RuntimeV4/UP2ClosureReplayOnlyV10/run_replay_staged_v10.py"
    controller_source = controller_path.read_text(encoding="utf-8")
    false_assignment_line = next((i for i, line in enumerate(controller_source.splitlines(), 1) if line.strip() == "producer_tree_unchanged = False"), None)
    true_assignment_line = next((i for i, line in enumerate(controller_source.splitlines(), 1) if line.strip() == "producer_tree_unchanged = True"), None)
    require(false_assignment_line is not None and true_assignment_line is not None and false_assignment_line < true_assignment_line, "producer_tree_flag_proof_gated", failures)
    require(final.get("producer_tree_unchanged") is False and final.get("inputs_unchanged") is True, "producer_tree_unverified_not_input_drift", failures)

    # Stage and aggregate budgets. RSS is a sampled process-tree measurement, not a continuous OS limit.
    limits = final.get("stage_limits", {})
    aggregate = final.get("aggregate_child_wall_budget", {})
    overhead = final.get("controller_overhead_budget", {})
    child_wall = stage.get("child_wall_seconds")
    stage_wall_limit = stage.get("wall_limit_seconds")
    peak_rss = stage.get("peak_sampled_process_tree_working_set_bytes")
    rss_limit = stage.get("memory_limit_bytes")
    require(limits.get("seconds") == 480 and limits.get("working_set_bytes") == 2147483648, "final_stage_limit_480_2gib", failures)
    require(stage_wall_limit == 480 and isinstance(child_wall, (int, float)) and child_wall <= stage_wall_limit, "producer_within_480s", failures)
    require(rss_limit == 2147483648 and isinstance(peak_rss, int) and peak_rss <= rss_limit, "producer_within_2gib_sampled_rss", failures)
    require(limits.get("memory_measurement") == "sampled aggregate process-tree RSS; not a continuous OS hard cap", "rss_scope_recorded", failures)
    require(aggregate.get("limit_seconds") == 960 and aggregate.get("limit_status") == "within_limit", "aggregate_child_budget_within_limit", failures)
    require(aggregate.get("spent_seconds") == stage.get("child_wall_seconds") and aggregate.get("overrun_seconds") == 0.0, "aggregate_child_wall_join", failures)
    require(aggregate.get("unconfirmed_cleanup_stages") == [], "no_unconfirmed_cleanup_stages", failures)
    require(overhead.get("limit_seconds") == 120.0 and overhead.get("limit_status") == "within_limit" and overhead.get("overrun_seconds") == 0.0, "controller_overhead_within_120s", failures)
    require(stage.get("cleanup") is None and process.get("terminated_owned_processes") == [], "natural_failure_no_forced_cleanup", failures)

    # The historical final summary repeats solver fields from the preserved numerical status.
    preserved = protocol.get("preserved_numerical_status", {})
    require(preserved.get("solver_exit_code") == final.get("solver_exit_code"), "solver_status_matches_preserved_metadata", failures)
    require(preserved.get("stopping_reason") == final.get("stopping_reason"), "stopping_reason_matches_preserved_metadata", failures)
    require(final.get("stopping_reason") == "stationary_nonzero_residual", "preserved_stopping_reason_present", failures)

    raw_hashes_before = [
        {"path": rel, "bytes": size, "sha256": sha}
        for rel, (size, sha) in sorted(run_before.items())
    ]
    raw_hashes_after = []
    raw_changed = []
    for rel, (old_size, old_sha) in sorted(run_before.items()):
        path = RUN / pathlib.Path(rel)
        now_size = path.stat().st_size if path.is_file() else None
        now_sha = sha256_file(path) if path.is_file() else None
        raw_hashes_after.append({"path": rel, "bytes": now_size, "sha256": now_sha})
        if (now_size, now_sha) != (old_size, old_sha):
            raw_changed.append(rel)
    require(not raw_changed, "run_raw_files_stable_during_review", failures)
    require(len(raw_hashes_before) == 17, "raw_run_file_count_17", failures)

    inputs_live_current = [row for row in live_pin_rows if row["status"] != "match"]
    verdict = "PASS_RECORDED_HYDRATION_FAILURE_ONLY" if not failures else "NO_GO"
    receipt = {
        "schema": "independent-mms-replay-r10-postrun-verification-v1",
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "failures": failures,
        "review_scope": "read-only verification of existing R10 artifacts; checker launched no Julia or heavy solver process",
        "protocol": {
            "path": str(PROTOCOL.resolve()),
            "bytes": len(protocol_bytes),
            "sha256": protocol_sha,
            "schema": protocol.get("schema"),
            "expected_sha256": EXPECTED_PROTOCOL_SHA256,
            "producer_command_protocol_sha256": child_command[7] if len(child_command) > 7 else None,
            "protocol_pinned_input_count": protocol.get("v10_protocol", {}).get("pinned_input_count"),
            "source_v10_protocol_path": str(source_v10_protocol_path.resolve()),
            "source_v10_protocol_sha256": sha256_file(source_v10_protocol_path) if source_v10_protocol_path.is_file() else None,
            "source_v10_protocol_input_count": len(source_inputs),
            "source_v10_protocol_inputs_joined_to_run_snapshot": sum(source_input_matches),
            "source_v10_protocol_input_manifest_sha256": EXPECTED_V10_SOURCE_INPUT_MANIFEST_SHA256,
        },
        "input_snapshots": {
            "before_path": str(before_path.resolve()),
            "after_path": str(after_path.resolve()),
            "entry_count": len(before),
            "before_bytes": len(before_raw),
            "after_bytes": len(after_raw),
            "before_sha256": digest_bytes(before_raw),
            "after_sha256": digest_bytes(after_raw),
            "before_after_raw_sha256_equal": digest_bytes(before_raw) == digest_bytes(after_raw),
            "exact_bytes_equal": before_raw == after_raw,
            "exact_rows_equal": before == after,
            "producer_local_after_equals_controller_after": producer_after_raw == after_raw,
            "live_pin_rehash_count": len(live_pin_rows),
            "live_pin_mismatch_count": len(inputs_live_current),
            "live_pin_mismatches": inputs_live_current,
            "live_pin_rows": live_pin_rows,
        },
        "run_outcome": {
            "classification": final.get("classification"),
            "controller_exit_code": final.get("controller_exit_code"),
            "producer_child_exit_code": process.get("exit_code"),
            "producer_stage_exit_code": stage.get("exit_code"),
            "producer_stop_reason": process.get("stop_reason"),
            "failure_phase": failure.get("phase"),
            "failure_hydration_stage": failure.get("hydration_stage"),
            "failure_message": failure.get("error"),
            "producer_stderr": raw_stderr.decode("utf-8", errors="replace"),
            "failure_receipt": failure,
            "hydration_phases": phase_rows,
            "stages": [s.get("stage") for s in final.get("stages", [])],
            "consumer_process_dir_exists": (RUN / "consumer_process").exists(),
            "nonlinear_solves": final.get("nonlinear_solves"),
            "producer_complete_exists": (process_dir / "numerical/producer_complete.json").exists(),
        },
        "producer_tree_flag_interpretation": {
            "final_producer_tree_unchanged": final.get("producer_tree_unchanged"),
            "final_inputs_unchanged": final.get("inputs_unchanged"),
            "false_assignment_line": false_assignment_line,
            "true_assignment_line": true_assignment_line,
            "controller_source_path": str(controller_path.resolve()),
            "controller_source_sha256": sha256_file(controller_path),
            "interpretation": "producer_tree_unchanged starts false and becomes true only after successful producer transport sealing, consumer success, and before/after producer-tree digest equality. This producer failed before that proof; false means not established, not observed tree mutation. The before/after input snapshots are byte-identical and inputs_unchanged is true.",
        },
        "resource_limits": {
            "stage_limit_seconds": stage_wall_limit,
            "stage_child_wall_seconds": child_wall,
            "stage_rss_limit_bytes": rss_limit,
            "peak_sampled_process_tree_rss_bytes": peak_rss,
            "memory_measurement_scope": limits.get("memory_measurement"),
            "aggregate_child_wall_budget": aggregate,
            "controller_overhead_budget": overhead,
            "within_stage_and_aggregate_caps": not any(x in failures for x in (
                "producer_within_480s", "producer_within_2gib_sampled_rss",
                "aggregate_child_budget_within_limit", "controller_overhead_within_120s",
            )),
        },
        "claim_boundary": {
            "authority": final.get("authority"),
            "formal_candidate_credit": final.get("formal_candidate_credit"),
            "software_complete": final.get("software_complete"),
            "numerical_status": final.get("numerical_status"),
            "physical_validation": final.get("physical_validation"),
            "stopping_reason": final.get("stopping_reason"),
            "stopping_reason_source": "matches protocol.preserved_numerical_status metadata; current R10 replay failure was hydration hash mismatch",
        },
        "raw_run_file_hashes_before": raw_hashes_before,
        "raw_run_file_hashes_after": raw_hashes_after,
        "raw_files_changed_during_review": raw_changed,
    }
    receipt_path = EVIDENCE / "verification.json"
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    command_data = {
        "kind": "non_executable_command_data",
        "python_executable": sys.executable,
        "argv": list(getattr(sys, "orig_argv", [])),
        "checker_path": str(pathlib.Path(__file__).resolve()),
        "scope": "Python stdlib read-only inspection; no subprocess, Julia, FreeGS, or solver invoked",
    }
    command_path = EVIDENCE / "command_argv.json"
    command_path.write_text(json.dumps(command_data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    files = []
    for path in sorted(p for p in EVIDENCE.rglob("*") if p.is_file()):
        files.append({"path": str(path.resolve()), "bytes": path.stat().st_size, "sha256": sha256_file(path), "role": "reviewer_evidence"})
    files.extend([
        {"path": str(pathlib.Path(__file__).resolve()), "bytes": pathlib.Path(__file__).stat().st_size, "sha256": sha256_file(pathlib.Path(__file__).resolve()), "role": "reviewer_source"},
        {"path": str(PROTOCOL.resolve()), "bytes": PROTOCOL.stat().st_size, "sha256": protocol_sha, "role": "reviewed_protocol"},
        {"path": str(final_path.resolve()), "bytes": final_path.stat().st_size, "sha256": sha256_file(final_path), "role": "reviewed_run_receipt"},
        {"path": str(process_path.resolve()), "bytes": process_path.stat().st_size, "sha256": sha256_file(process_path), "role": "reviewed_process_receipt"},
    ])
    manifest = {
        "schema": "independent-mms-replay-r10-postrun-manifest-v1",
        "verdict": verdict,
        "files": files,
        "no_heavy_run_launched": True,
        "manifest_self_hash": "not_applicable",
    }
    manifest_path = EVIDENCE / "archive_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "failures": failures, "verification": str(receipt_path), "manifest": str(manifest_path)}, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
