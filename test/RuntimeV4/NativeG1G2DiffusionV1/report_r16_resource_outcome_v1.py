"""Additive r16 sampled-RSS, strict-type, and containment outcome reporter.

Reads one completed r16 run leaf and writes an additive report. An incomplete
process-tree sample always fails closed as ``resource_monitor_incomplete``;
the report preserves the partial RSS, discovered/measured PIDs, and raw error
details, and never treats partial RSS as evidence below the threshold.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RSS_THRESHOLD_BYTES = 2_147_483_648
RSS_SAMPLE_INTERVAL_SECONDS = 0.2
RSS_LIMIT_STOP_REASON = "process_tree_rss_limit"
MONITOR_INCOMPLETE_STOP_REASON = "resource_monitor_incomplete"
OUTPUT_FILENAME = "resource_report_r16.json"
OUTER_AUDIT_FILENAME = "outer_supervisor_audit.json"
EXPECTED_STAGE_ORDER = ("parse_all", "primary", "fresh_replay")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def _nonnegative_int(value: Any, field: str) -> int:
    if type(value) is not int or value < 0:
        raise ValueError(f"{field} must be a nonnegative integer")
    return value


def _read_json(path: Path, field: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read {field}: {path}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{field} must contain a JSON object")
    return value


def _pid_list(value: Any, field: str) -> list[int]:
    if not isinstance(value, list):
        raise ValueError(f"{field} must be a list")
    result = [_nonnegative_int(pid, f"{field}[{index}]") for index, pid in enumerate(value)]
    if any(pid <= 0 for pid in result):
        raise ValueError(f"{field} must contain positive process ids")
    return result


def _sample_completeness(row: dict[str, Any], line_number: int) -> tuple[bool, list[str]]:
    """Validate the runner's observed enumeration/member-read completeness claim."""
    reasons: list[str] = []
    marker = row.get("process_tree_sample_complete")
    if marker is not True:
        reasons.append("sample_completeness_marker_missing_or_false")

    errors = row.get("process_tree_sample_errors")
    if not isinstance(errors, list):
        reasons.append("sample_error_receipt_missing_or_malformed")
        errors = []
    elif errors:
        reasons.append("sample_contains_resource_monitor_errors")

    discovered = _pid_list(row.get("process_tree_discovered_pids"),
                           f"sample[{line_number}].process_tree_discovered_pids")
    pids = _pid_list(row.get("process_tree_pids"),
                     f"sample[{line_number}].process_tree_pids")
    measured = _pid_list(row.get("process_tree_measured_pids"),
                         f"sample[{line_number}].process_tree_measured_pids")
    if pids != discovered:
        reasons.append("sample_pids_disagree_with_discovered_pids")

    expected_count = row.get("process_tree_expected_member_count")
    measured_count = row.get("process_tree_measured_member_count")
    if type(expected_count) is not int or expected_count < 1:
        reasons.append("expected_process_tree_member_count_unavailable")
    elif expected_count != len(discovered):
        reasons.append("expected_member_count_disagrees_with_discovered_pids")
    if type(measured_count) is not int or measured_count < 0:
        reasons.append("measured_process_tree_member_count_unavailable")
    elif measured_count != len(measured):
        reasons.append("measured_member_count_disagrees_with_measured_pids")
    if set(measured) - set(discovered):
        reasons.append("measured_pid_missing_from_discovery")

    rows = row.get("process_tree_processes")
    if not isinstance(rows, list) or any(not isinstance(item, dict) for item in rows):
        reasons.append("process_tree_process_rows_missing_or_malformed")
        rows = []
    row_pids: list[int] = []
    rss_total = 0
    rss_pids: list[int] = []
    for index, item in enumerate(rows):
        pid = item.get("pid")
        if type(pid) is not int or pid <= 0:
            reasons.append(f"process_tree_row[{index}]_pid_missing")
        else:
            row_pids.append(pid)
        rss = item.get("rss_bytes")
        if type(rss) is int and rss >= 0:
            rss_total += rss
            if type(pid) is int and pid > 0:
                rss_pids.append(pid)
        else:
            reasons.append(f"process_tree_row[{index}]_rss_missing")
    if sorted(row_pids) != sorted(discovered):
        reasons.append("process_tree_rows_disagree_with_discovered_pids")
    if sorted(rss_pids) != sorted(measured):
        reasons.append("process_tree_rows_disagree_with_measured_pids")

    partial = _nonnegative_int(
        row.get("partial_process_tree_rss_bytes"),
        f"sample[{line_number}].partial_process_tree_rss_bytes",
    )
    reported = _nonnegative_int(
        row.get("process_tree_rss_bytes"),
        f"sample[{line_number}].process_tree_rss_bytes",
    )
    if partial != reported:
        reasons.append("partial_and_legacy_rss_fields_disagree")
    if partial != rss_total:
        reasons.append("partial_rss_disagrees_with_measured_member_rows")
    if marker is True and errors == [] and not reasons:
        return True, []
    return False, reasons or ["sample_is_incomplete"]


def _read_samples(path: Path) -> tuple[list[int | None], list[dict[str, Any]], bytes, list[dict[str, Any]], list[bool]]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"cannot read process-tree samples: {path}") from exc
    values: list[int | None] = []
    rows: list[dict[str, Any]] = []
    incomplete: list[dict[str, Any]] = []
    valid_complete_samples: list[bool] = []
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ValueError(f"invalid process-tree sample JSON at line {line_number}") from exc
        if not isinstance(row, dict):
            raise ValueError(f"process-tree sample at line {line_number} must be an object")
        raw_value = row.get("process_tree_rss_bytes")
        if type(raw_value) is int and raw_value >= 0:
            value: int | None = raw_value
            top_level_rss_valid = True
        else:
            value = None
            top_level_rss_valid = False
        sample_utc = row.get("utc")
        if not isinstance(sample_utc, str) or not sample_utc:
            raise ValueError(f"sample[{line_number}].utc must be a non-empty string")
        elapsed = row.get("elapsed_seconds")
        if isinstance(elapsed, bool) or not isinstance(elapsed, (int, float)) or \
                not math.isfinite(float(elapsed)) or elapsed < 0:
            raise ValueError(f"sample[{line_number}].elapsed_seconds must be finite and nonnegative")
        try:
            complete, reasons = _sample_completeness(row, line_number)
        except ValueError as exc:
            complete, reasons = False, ["malformed_sample_numeric_field", str(exc)]
        if not top_level_rss_valid:
            complete = False
            reasons.append("top_level_rss_is_not_native_nonnegative_integer")
        values.append(value)
        rows.append(row)
        valid_complete_samples.append(complete)
        if not complete:
            incomplete.append({
                "sample_index": len(rows),
                "sample_line_number": line_number,
                "validation_reasons": reasons,
                "raw_process_tree_rss_bytes": raw_value,
                "raw_errors": row.get("process_tree_sample_errors"),
                "partial_process_tree_rss_bytes": row.get("partial_process_tree_rss_bytes"),
                "process_tree_pids": row.get("process_tree_pids"),
                "process_tree_discovered_pids": row.get("process_tree_discovered_pids"),
                "process_tree_measured_pids": row.get("process_tree_measured_pids"),
                "process_tree_expected_member_count": row.get("process_tree_expected_member_count"),
                "process_tree_measured_member_count": row.get("process_tree_measured_member_count"),
            })
    return values, rows, raw, incomplete, valid_complete_samples


def _check_summary_stage_agreement(summary_stage: dict[str, Any],
                                   final: dict[str, Any]) -> None:
    for key in ("stage", "index", "exit_code", "stop_reason", "sample_count",
                "peak_process_tree_rss_bytes", "peak_process_tree_rss_sample_index",
                "peak_process_tree_rss_sample_utc",
                "peak_process_tree_rss_sample_elapsed_seconds",
                "peak_process_tree_rss_sample_bytes", "resource_monitor_complete",
                "resource_monitor_status", "resource_monitor_failure", "root_pid",
                "root_process_create_time", "internal_termination_status",
                "internal_termination_receipt"):
        if summary_stage.get(key) != final.get(key):
            raise ValueError(f"runner summary disagrees with stage final field: {key}")


def _classify_stage(actual_leaf: Path, summary_stage: dict[str, Any]) -> dict[str, Any]:
    index = _nonnegative_int(summary_stage.get("index"), "stage.index")
    if index < 1:
        raise ValueError("stage.index must be positive")
    stage_name = summary_stage.get("stage")
    if not isinstance(stage_name, str) or stage_name not in EXPECTED_STAGE_ORDER:
        raise ValueError("stage.stage is outside the frozen r16 stage set")
    stage_dir = actual_leaf / f"{index:02d}_{stage_name}"
    final_path = stage_dir / "final.json"
    samples_path = stage_dir / "samples.jsonl"
    final = _read_json(final_path, "stage final")
    _check_summary_stage_agreement(summary_stage, final)
    exit_code = final.get("exit_code")
    if type(exit_code) is not int:
        raise ValueError("stage final exit_code must be an integer")
    stop_reason = final.get("stop_reason")
    if not isinstance(stop_reason, str) or not stop_reason:
        raise ValueError("stage final stop_reason must be a non-empty string")
    values, sample_rows, samples_raw, incomplete_samples, valid_complete_samples = _read_samples(samples_path)
    if not values:
        incomplete_samples.append({
            "sample_index": None,
            "validation_reasons": ["no_process_tree_samples_recorded"],
            "raw_errors": final.get("resource_monitor_failure"),
            "partial_process_tree_rss_bytes": None,
            "process_tree_pids": [],
            "process_tree_discovered_pids": [],
            "process_tree_measured_pids": [],
        })
    declared_count = _nonnegative_int(final.get("sample_count"), "final.sample_count")
    if declared_count != len(values):
        incomplete_samples.append({
            "sample_index": None,
            "validation_reasons": ["sample_count_disagrees_with_raw_samples"],
            "raw_errors": final.get("resource_monitor_failure"),
            "partial_process_tree_rss_bytes": None,
            "process_tree_pids": [],
            "process_tree_discovered_pids": [],
            "process_tree_measured_pids": [],
        })
    valid_indices = [index for index, value in enumerate(values) if value is not None]
    sampled_peak = max((int(values[index]) for index in valid_indices), default=0)
    peak_sample_index = next(
        (index for index in valid_indices if values[index] == sampled_peak), None
    )
    peak_sample = sample_rows[peak_sample_index] if peak_sample_index is not None else None
    expected_peak_metadata = {
        "peak_process_tree_rss_sample_index": (
            peak_sample_index + 1 if peak_sample_index is not None else None
        ),
        "peak_process_tree_rss_sample_utc": (
            peak_sample["utc"] if peak_sample is not None else None
        ),
        "peak_process_tree_rss_sample_elapsed_seconds": (
            peak_sample["elapsed_seconds"] if peak_sample is not None else None
        ),
        "peak_process_tree_rss_sample_bytes": sampled_peak,
    }
    samples_numeric_complete = all(value is not None for value in values)
    if samples_numeric_complete:
        for field, expected in expected_peak_metadata.items():
            if final.get(field) != expected:
                raise ValueError(f"stage final peak sample metadata disagrees with raw samples: {field}")
    declared_peak = _nonnegative_int(final.get("peak_process_tree_rss_bytes"),
                                     "final.peak_process_tree_rss_bytes")
    if samples_numeric_complete and declared_peak != sampled_peak:
        raise ValueError("stage final peak RSS disagrees with sampled RSS series")

    runner_monitor_complete = final.get("resource_monitor_complete") is True
    monitor_incomplete = (
        bool(incomplete_samples) or not runner_monitor_complete or
        stop_reason == MONITOR_INCOMPLETE_STOP_REASON
    )
    if monitor_incomplete and not incomplete_samples:
        incomplete_samples.append({
            "sample_index": None,
            "validation_reasons": ["runner_declared_monitor_incomplete_without_incomplete_sample"],
            "raw_errors": final.get("resource_monitor_failure"),
            "partial_process_tree_rss_bytes": None,
            "process_tree_pids": [],
            "process_tree_discovered_pids": [],
            "process_tree_measured_pids": [],
        })
    complete_values = [
        int(value) for value, is_complete in zip(values, valid_complete_samples)
        if value is not None and is_complete
    ]
    threshold_reached = any(value >= RSS_THRESHOLD_BYTES for value in complete_values)
    if stop_reason == RSS_LIMIT_STOP_REASON and not threshold_reached and not monitor_incomplete:
        raise ValueError("RSS-limit stop reason has no complete sampled threshold hit")
    if monitor_incomplete:
        disposition = MONITOR_INCOMPLETE_STOP_REASON
    elif threshold_reached or stop_reason == RSS_LIMIT_STOP_REASON:
        disposition = "resource_failure"
    else:
        disposition = "no_sampled_rss_threshold_crossing"
    resource_failure = monitor_incomplete or threshold_reached or stop_reason == RSS_LIMIT_STOP_REASON

    if monitor_incomplete:
        consistency = "monitor_incomplete_partial_rss_not_threshold_evidence"
    elif threshold_reached and stop_reason != RSS_LIMIT_STOP_REASON:
        consistency = "sampled_threshold_hit_but_low_level_stop_reason_differs"
    elif threshold_reached:
        consistency = "consistent"
    else:
        consistency = "no_complete_sampled_threshold_hit"

    return {
        "stage": stage_name,
        "index": index,
        "disposition": disposition,
        "resource_failure": resource_failure,
        "resource_monitor_complete": not monitor_incomplete,
        "resource_monitor_incomplete": monitor_incomplete,
        "resource_monitor_failure": final.get("resource_monitor_failure"),
        "incomplete_samples": incomplete_samples,
        "rss_threshold": {
            "threshold_bytes": RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": RSS_SAMPLE_INTERVAL_SECONDS,
            "sampled_threshold_hit_in_complete_samples": threshold_reached,
            "peak_reported_sample_rss_bytes": sampled_peak,
            "peak_complete_sample_rss_bytes": max(complete_values, default=None),
            "partial_samples_never_clear_threshold": True,
            "overshoot_bytes_in_complete_samples": max(
                0, max(complete_values, default=0) - RSS_THRESHOLD_BYTES
            ),
            "continuous_between_sample_peak": "unknown",
            "enforcement_semantics": "sampled_stop_trigger",
        },
        "peak_sample": {
            "sample_index": expected_peak_metadata["peak_process_tree_rss_sample_index"],
            "utc": expected_peak_metadata["peak_process_tree_rss_sample_utc"],
            "elapsed_seconds": expected_peak_metadata["peak_process_tree_rss_sample_elapsed_seconds"],
            "reported_rss_bytes": expected_peak_metadata["peak_process_tree_rss_sample_bytes"],
            "tie_rule": "first sample among equal maxima",
            "complete_tree_sample": (
                peak_sample.get("process_tree_sample_complete") is True
                if peak_sample is not None else False
            ),
        },
        "low_level_stage_outcome": {
            "stop_reason": stop_reason,
            "exit_code": exit_code,
            "sample_count": len(values),
            "runner_reported_peak_process_tree_rss_bytes": declared_peak,
            "stdout_receipt": final.get("stdout"),
            "stderr_receipt": final.get("stderr"),
            "threshold_stop_consistency": consistency,
        },
        "root_process_identity": {
            "pid": final.get("root_pid"),
            "create_time": final.get("root_process_create_time"),
        },
        "observed_process_pids": sorted({
            pid for row in sample_rows
            for pid in row.get("process_tree_discovered_pids", [])
            if type(pid) is int and pid > 0
        }),
        "internal_termination": {
            "status": final.get("internal_termination_status"),
            "receipt": final.get("internal_termination_receipt"),
            "outer_supervisor_residual_audit_required": True,
        },
        "input_receipts": {
            "stage_final_path": final_path.relative_to(actual_leaf).as_posix(),
            "stage_final_sha256": sha256_file(final_path),
            "samples_path": samples_path.relative_to(actual_leaf).as_posix(),
            "samples_sha256": sha256_bytes(samples_raw),
        },
    }


def _finite_positive_number(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(float(value)) and float(value) > 0


def _validate_outer_supervisor_audit(
    leaf: Path, stage_reports: list[dict[str, Any]]
) -> tuple[bool, list[str], dict[str, Any] | None]:
    """Require the root dispatcher's descendant-exit and residual-scan receipt."""
    path = leaf / OUTER_AUDIT_FILENAME
    if not path.is_file():
        return False, ["outer_supervisor_audit_missing"], None
    try:
        audit = _read_json(path, "root outer-supervisor audit")
    except ValueError as exc:
        return False, ["outer_supervisor_audit_unreadable", str(exc)], None
    reasons: list[str] = []
    if audit.get("schema") != "native-g1g2-root-outer-supervisor-residual-audit-v1":
        reasons.append("outer_supervisor_audit_schema_mismatch")
    if audit.get("audit_owner") != "root_dispatch_controller":
        reasons.append("outer_supervisor_audit_owner_unverified")
    if audit.get("audit_status") != "pass":
        reasons.append("outer_supervisor_audit_not_pass")
    if audit.get("run_mode") != "actual" or audit.get("runtime_executed") is not True:
        reasons.append("outer_supervisor_audit_not_bound_to_actual_run")
    if audit.get("pre_run_inventory_complete") is not True:
        reasons.append("outer_supervisor_pre_run_inventory_incomplete")
    if audit.get("post_run_inventory_complete") is not True:
        reasons.append("outer_supervisor_post_run_inventory_incomplete")
    if audit.get("post_run_heavy_process_inventory") != []:
        reasons.append("outer_supervisor_residual_heavy_processes_present")

    run_root = audit.get("run_root_pid_create_time")
    if not isinstance(run_root, dict) or type(run_root.get("pid")) is not int or \
            run_root.get("pid", 0) <= 0 or \
            not _finite_positive_number(run_root.get("create_time")):
        reasons.append("outer_supervisor_run_root_identity_unconfirmed")
    runner = audit.get("supervised_runner")
    if not isinstance(runner, dict) or type(runner.get("pid")) is not int or \
            runner.get("pid", 0) <= 0 or not _finite_positive_number(runner.get("create_time")) or \
            runner.get("exit_confirmed") is not True:
        reasons.append("outer_supervisor_runner_exit_identity_unconfirmed")
    elif isinstance(run_root, dict) and (
            runner.get("pid") != run_root.get("pid") or
            runner.get("create_time") != run_root.get("create_time")):
        reasons.append("outer_supervisor_run_root_runner_identity_mismatch")

    if audit.get("residual_scan_before_and_after_each_stage") is not True:
        reasons.append("outer_supervisor_stage_residual_scans_missing")
    scan_completeness = audit.get("residual_scan_completeness")
    if not isinstance(scan_completeness, dict) or \
            scan_completeness.get("pre_run_inventory_complete") is not True or \
            scan_completeness.get("post_run_inventory_complete") is not True:
        reasons.append("outer_supervisor_residual_scan_completeness_missing")

    stages = audit.get("stages")
    if not isinstance(stages, list) or len(stages) != len(stage_reports):
        reasons.append("outer_supervisor_stage_receipt_count_mismatch")
        stages = []
    root_receipts = audit.get("stage_root_exit_receipts")
    if not isinstance(root_receipts, list) or len(root_receipts) != len(stage_reports):
        reasons.append("outer_supervisor_stage_root_receipt_count_mismatch")
        root_receipts = []
    descendant_receipts = audit.get("tracked_descendant_exit_receipts")
    if not isinstance(descendant_receipts, list):
        reasons.append("outer_supervisor_tracked_descendant_receipts_missing")
        descendant_receipts = []
    receipt_pids_by_stage: dict[tuple[int, str], set[int]] = {}
    for index, receipt in enumerate(descendant_receipts):
        if not isinstance(receipt, dict):
            reasons.append(f"outer_supervisor_descendant[{index}]_malformed")
            continue
        stage_index = receipt.get("index")
        stage_name = receipt.get("stage")
        pid = receipt.get("pid")
        if type(stage_index) is not int or stage_index < 1 or \
                not isinstance(stage_name, str) or type(pid) is not int or pid <= 0 or \
                not _finite_positive_number(receipt.get("create_time")) or \
                receipt.get("exit_confirmed") is not True:
            reasons.append(f"outer_supervisor_descendant[{index}]_exit_unconfirmed")
            continue
        receipt_pids_by_stage.setdefault((stage_index, stage_name), set()).add(pid)

    scan_stages = scan_completeness.get("stages") \
        if isinstance(scan_completeness, dict) else None
    if not isinstance(scan_stages, list) or len(scan_stages) != len(stage_reports):
        reasons.append("outer_supervisor_per_stage_scan_completeness_count_mismatch")
        scan_stages = []
    for ordinal, (stage_audit, stage_report) in enumerate(
        zip(stages, stage_reports), start=1
    ):
        if not isinstance(stage_audit, dict):
            reasons.append(f"outer_supervisor_stage[{ordinal}]_receipt_malformed")
            continue
        if stage_audit.get("index") != stage_report["index"] or \
                stage_audit.get("stage") != stage_report["stage"]:
            reasons.append(f"outer_supervisor_stage[{ordinal}]_identity_mismatch")
        root = stage_report.get("root_process_identity", {})
        if stage_audit.get("root_pid") != root.get("pid") or \
                stage_audit.get("root_process_create_time") != root.get("create_time"):
            reasons.append(f"outer_supervisor_stage[{ordinal}]_root_identity_mismatch")
        if stage_audit.get("root_exit_confirmed") is not True:
            reasons.append(f"outer_supervisor_stage[{ordinal}]_root_exit_unconfirmed")
        if ordinal <= len(root_receipts):
            root_receipt = root_receipts[ordinal - 1]
            if not isinstance(root_receipt, dict) or \
                    root_receipt.get("index") != stage_report["index"] or \
                    root_receipt.get("stage") != stage_report["stage"] or \
                    root_receipt.get("pid") != root.get("pid") or \
                    root_receipt.get("create_time") != root.get("create_time") or \
                    root_receipt.get("exit_confirmed") is not True:
                reasons.append(f"outer_supervisor_stage[{ordinal}]_root_exit_receipt_mismatch")
        if stage_audit.get("pre_stage_inventory_complete") is not True or \
                stage_audit.get("post_stage_inventory_complete") is not True:
            reasons.append(f"outer_supervisor_stage[{ordinal}]_inventory_incomplete")
        if ordinal <= len(scan_stages):
            scan_stage = scan_stages[ordinal - 1]
            if not isinstance(scan_stage, dict) or \
                    scan_stage.get("index") != stage_report["index"] or \
                    scan_stage.get("stage") != stage_report["stage"] or \
                    scan_stage.get("pre_stage_inventory_complete") is not True or \
                    scan_stage.get("post_stage_inventory_complete") is not True:
                reasons.append(f"outer_supervisor_stage[{ordinal}]_scan_completeness_mismatch")
        if stage_audit.get("pre_stage_residual_heavy_processes") != [] or \
                stage_audit.get("post_stage_residual_heavy_processes") != []:
            reasons.append(f"outer_supervisor_stage[{ordinal}]_residual_process_present")
        receipts = stage_audit.get("tracked_descendant_exit_receipts")
        if not isinstance(receipts, list):
            reasons.append(f"outer_supervisor_stage[{ordinal}]_descendant_receipts_missing")
            receipts = []
        receipt_pids: set[int] = set()
        for receipt_index, receipt in enumerate(receipts):
            if not isinstance(receipt, dict):
                reasons.append(f"outer_supervisor_stage[{ordinal}]_descendant[{receipt_index}]_malformed")
                continue
            pid = receipt.get("pid")
            if type(pid) is not int or pid <= 0 or \
                    not _finite_positive_number(receipt.get("create_time")) or \
                    receipt.get("exit_confirmed") is not True:
                reasons.append(f"outer_supervisor_stage[{ordinal}]_descendant[{receipt_index}]_exit_unconfirmed")
                continue
            receipt_pids.add(pid)
        expected_descendants = set(stage_report.get("observed_process_pids", []))
        root_pid = root.get("pid")
        if type(root_pid) is int:
            expected_descendants.discard(root_pid)
        if not expected_descendants.issubset(receipt_pids):
            reasons.append(f"outer_supervisor_stage[{ordinal}]_observed_descendant_exit_receipt_missing")
        if not expected_descendants.issubset(
                receipt_pids_by_stage.get((stage_report["index"], stage_report["stage"]), set())):
            reasons.append(f"outer_supervisor_stage[{ordinal}]_aggregate_descendant_receipt_missing")
    return not reasons, reasons, audit


def build_report(actual_leaf: Path) -> dict[str, Any]:
    leaf = actual_leaf.resolve()
    if not leaf.is_dir():
        raise ValueError(f"actual run leaf does not exist: {leaf}")
    summary_path = leaf / "summary.json"
    summary = _read_json(summary_path, "run summary")
    if summary.get("runtime_executed") is not True:
        raise ValueError("run summary runtime_executed must be true before RSS classification")
    if summary.get("mode") == "static_only":
        raise ValueError("static_only preparation summaries are not actual run evidence")
    stages = summary.get("stages")
    if not isinstance(stages, list):
        raise ValueError("run summary stages must be a list")
    if not stages:
        raise ValueError("run summary must contain at least one actual stage")
    stage_reports = []
    for ordinal, item in enumerate(stages, start=1):
        if not isinstance(item, dict):
            raise ValueError("run summary stage entry must be an object")
        if ordinal > len(EXPECTED_STAGE_ORDER):
            raise ValueError("run summary contains more stages than the frozen r16 plan")
        if item.get("index") != ordinal or item.get("stage") != EXPECTED_STAGE_ORDER[ordinal - 1]:
            raise ValueError("run summary stage order differs from the frozen r16 plan")
        stage_reports.append(_classify_stage(leaf, item))
    outer_audit_complete, outer_audit_reasons, outer_audit = _validate_outer_supervisor_audit(
        leaf, stage_reports
    )
    for stage_report in stage_reports:
        stage_report["outer_supervisor_audit_complete"] = outer_audit_complete
        if not outer_audit_complete:
            stage_report["outer_supervisor_audit_failure_reasons"] = outer_audit_reasons
    incomplete = [row for row in stage_reports if row["resource_monitor_incomplete"]]
    failed = [row for row in stage_reports if row["resource_failure"]]
    if incomplete or not outer_audit_complete:
        run_disposition = MONITOR_INCOMPLETE_STOP_REASON
    elif failed:
        run_disposition = "resource_failure"
    else:
        run_disposition = "no_sampled_rss_threshold_crossing"
    return {
        "schema": "native-g1g2-r16-rss-outcome-report-v1",
        "report_status": "emitted",
        "run_disposition": run_disposition,
        "resource_failure": bool(failed) or not outer_audit_complete,
        "resource_monitor_complete": not bool(incomplete) and outer_audit_complete,
        "failed_stages": [row["stage"] for row in failed],
        "resource_monitor_incomplete_stages": [row["stage"] for row in incomplete],
        "low_level_runner_summary": {
            "path": "summary.json",
            "sha256": sha256_file(summary_path),
            "status": summary.get("status"),
            "runtime_executed": summary.get("runtime_executed"),
            "resource_monitor_complete": summary.get("resource_monitor_complete"),
        },
        "stage_reports": stage_reports,
        "outer_supervisor_audit": {
            "required": True,
            "complete": outer_audit_complete,
            "failure_reasons": outer_audit_reasons,
            "path": OUTER_AUDIT_FILENAME,
            "sha256": sha256_file(leaf / OUTER_AUDIT_FILENAME)
                if (leaf / OUTER_AUDIT_FILENAME).is_file() else None,
            "receipt": outer_audit,
            "internal_kill_tree_claim_suffices": False,
        },
        "claim_boundary": {
            "numerical_status": "not_established",
            "physical_status": "unknown",
            "solver_success_claimed": False,
            "numerical_credit_on_monitor_incomplete": False,
            "numerical_credit_before_outer_supervisor_audit": False,
            "resource_failure_is_not_a_numerical_or_physical_verdict": True,
        },
        "reporter": {
            "threshold_bytes": RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": RSS_SAMPLE_INTERVAL_SECONDS,
            "output_is_additive": True,
            "input_bytes_modified": False,
            "partial_sample_classification": MONITOR_INCOMPLETE_STOP_REASON,
        },
    }


def write_new_report(actual_leaf: Path, output_path: Path | None = None) -> Path:
    leaf = actual_leaf.resolve()
    output = (output_path or (leaf / OUTPUT_FILENAME)).resolve()
    if output.parent != leaf:
        raise ValueError("report output must be directly inside the actual run leaf")
    report = build_report(leaf)
    report["created_utc"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    with output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(report, stream, sort_keys=True, indent=2)
        stream.write("\n")
    return output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actual-leaf", required=True,
                        help="completed owned r16 actual output leaf")
    parser.add_argument("--output", default=None,
                        help=f"new report path (default: <actual-leaf>/{OUTPUT_FILENAME})")
    args = parser.parse_args(argv)
    actual_leaf = Path(args.actual_leaf)
    output = Path(args.output) if args.output else None
    report_path = write_new_report(actual_leaf, output)
    report = json.loads(report_path.read_text(encoding="utf-8"))
    print(json.dumps({
        "report_status": report["report_status"],
        "run_disposition": report["run_disposition"],
        "failed_stages": report["failed_stages"],
        "resource_monitor_incomplete_stages": report["resource_monitor_incomplete_stages"],
        "report_path": str(report_path),
        "reporter_exit_means": "report_written_only",
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
