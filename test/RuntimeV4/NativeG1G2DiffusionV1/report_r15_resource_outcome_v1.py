"""Additive r15 sampled-RSS and incomplete-monitor outcome reporter.

Reads one completed r15 run leaf and writes an additive report. An incomplete
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
OUTPUT_FILENAME = "resource_report_r15.json"
EXPECTED_STAGE_ORDER = ("parse_all", "primary", "fresh_replay")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def _nonnegative_int(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
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
    return [_nonnegative_int(pid, f"{field}[{index}]") for index, pid in enumerate(value)]


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
    if isinstance(expected_count, bool) or not isinstance(expected_count, int) or expected_count < 1:
        reasons.append("expected_process_tree_member_count_unavailable")
    elif expected_count != len(discovered):
        reasons.append("expected_member_count_disagrees_with_discovered_pids")
    if isinstance(measured_count, bool) or not isinstance(measured_count, int) or measured_count < 0:
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
        if isinstance(pid, bool) or not isinstance(pid, int) or pid < 0:
            reasons.append(f"process_tree_row[{index}]_pid_missing")
        else:
            row_pids.append(pid)
        rss = item.get("rss_bytes")
        if isinstance(rss, int) and not isinstance(rss, bool) and rss >= 0:
            rss_total += rss
            if isinstance(pid, int) and not isinstance(pid, bool) and pid >= 0:
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


def _read_samples(path: Path) -> tuple[list[int], list[dict[str, Any]], bytes, list[dict[str, Any]]]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"cannot read process-tree samples: {path}") from exc
    values: list[int] = []
    rows: list[dict[str, Any]] = []
    incomplete: list[dict[str, Any]] = []
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ValueError(f"invalid process-tree sample JSON at line {line_number}") from exc
        if not isinstance(row, dict):
            raise ValueError(f"process-tree sample at line {line_number} must be an object")
        value = _nonnegative_int(row.get("process_tree_rss_bytes"),
                                 f"sample[{line_number}].process_tree_rss_bytes")
        sample_utc = row.get("utc")
        if not isinstance(sample_utc, str) or not sample_utc:
            raise ValueError(f"sample[{line_number}].utc must be a non-empty string")
        elapsed = row.get("elapsed_seconds")
        if isinstance(elapsed, bool) or not isinstance(elapsed, (int, float)) or \
                not math.isfinite(float(elapsed)) or elapsed < 0:
            raise ValueError(f"sample[{line_number}].elapsed_seconds must be finite and nonnegative")
        complete, reasons = _sample_completeness(row, line_number)
        values.append(value)
        rows.append(row)
        if not complete:
            incomplete.append({
                "sample_index": len(rows),
                "sample_line_number": line_number,
                "validation_reasons": reasons,
                "raw_errors": row.get("process_tree_sample_errors"),
                "partial_process_tree_rss_bytes": row.get("partial_process_tree_rss_bytes"),
                "process_tree_pids": row.get("process_tree_pids"),
                "process_tree_discovered_pids": row.get("process_tree_discovered_pids"),
                "process_tree_measured_pids": row.get("process_tree_measured_pids"),
                "process_tree_expected_member_count": row.get("process_tree_expected_member_count"),
                "process_tree_measured_member_count": row.get("process_tree_measured_member_count"),
            })
    return values, rows, raw, incomplete


def _check_summary_stage_agreement(summary_stage: dict[str, Any],
                                   final: dict[str, Any]) -> None:
    for key in ("stage", "index", "exit_code", "stop_reason", "sample_count",
                "peak_process_tree_rss_bytes", "peak_process_tree_rss_sample_index",
                "peak_process_tree_rss_sample_utc",
                "peak_process_tree_rss_sample_elapsed_seconds",
                "peak_process_tree_rss_sample_bytes", "resource_monitor_complete",
                "resource_monitor_status", "resource_monitor_failure"):
        if summary_stage.get(key) != final.get(key):
            raise ValueError(f"runner summary disagrees with stage final field: {key}")


def _classify_stage(actual_leaf: Path, summary_stage: dict[str, Any]) -> dict[str, Any]:
    index = _nonnegative_int(summary_stage.get("index"), "stage.index")
    if index < 1:
        raise ValueError("stage.index must be positive")
    stage_name = summary_stage.get("stage")
    if not isinstance(stage_name, str) or stage_name not in EXPECTED_STAGE_ORDER:
        raise ValueError("stage.stage is outside the frozen r15 stage set")
    stage_dir = actual_leaf / f"{index:02d}_{stage_name}"
    final_path = stage_dir / "final.json"
    samples_path = stage_dir / "samples.jsonl"
    final = _read_json(final_path, "stage final")
    _check_summary_stage_agreement(summary_stage, final)
    exit_code = final.get("exit_code")
    if isinstance(exit_code, bool) or not isinstance(exit_code, int):
        raise ValueError("stage final exit_code must be an integer")
    stop_reason = final.get("stop_reason")
    if not isinstance(stop_reason, str) or not stop_reason:
        raise ValueError("stage final stop_reason must be a non-empty string")
    values, sample_rows, samples_raw, incomplete_samples = _read_samples(samples_path)
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
    sampled_peak = max(values, default=0)
    peak_sample_index = values.index(sampled_peak) if values else None
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
    for field, expected in expected_peak_metadata.items():
        if final.get(field) != expected:
            raise ValueError(f"stage final peak sample metadata disagrees with raw samples: {field}")
    declared_peak = _nonnegative_int(final.get("peak_process_tree_rss_bytes"),
                                     "final.peak_process_tree_rss_bytes")
    if declared_peak != sampled_peak:
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
        value for value, row in zip(values, sample_rows)
        if row.get("process_tree_sample_complete") is True and
        isinstance(row.get("process_tree_sample_errors"), list) and
        not row.get("process_tree_sample_errors")
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
        "input_receipts": {
            "stage_final_path": final_path.relative_to(actual_leaf).as_posix(),
            "stage_final_sha256": sha256_file(final_path),
            "samples_path": samples_path.relative_to(actual_leaf).as_posix(),
            "samples_sha256": sha256_bytes(samples_raw),
        },
    }


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
            raise ValueError("run summary contains more stages than the frozen r15 plan")
        if item.get("index") != ordinal or item.get("stage") != EXPECTED_STAGE_ORDER[ordinal - 1]:
            raise ValueError("run summary stage order differs from the frozen r15 plan")
        stage_reports.append(_classify_stage(leaf, item))
    incomplete = [row for row in stage_reports if row["resource_monitor_incomplete"]]
    failed = [row for row in stage_reports if row["resource_failure"]]
    if incomplete:
        run_disposition = MONITOR_INCOMPLETE_STOP_REASON
    elif failed:
        run_disposition = "resource_failure"
    else:
        run_disposition = "no_sampled_rss_threshold_crossing"
    return {
        "schema": "native-g1g2-r15-rss-outcome-report-v1",
        "report_status": "emitted",
        "run_disposition": run_disposition,
        "resource_failure": bool(failed),
        "resource_monitor_complete": not bool(incomplete),
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
        "claim_boundary": {
            "numerical_status": "not_established",
            "physical_status": "unknown",
            "solver_success_claimed": False,
            "numerical_credit_on_monitor_incomplete": False,
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
                        help="completed owned r15 actual output leaf")
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
