"""Additive R14 sampled-RSS outcome reporter, version 7.

Reads one completed recorded run leaf and writes a new resource_report_v7.json
sidecar. It does not modify runner summaries, stage finals, raw streams, or
sample series. It does not launch Julia or infer numerical/physical success.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RSS_THRESHOLD_BYTES = 2_147_483_648
RSS_SAMPLE_INTERVAL_SECONDS = 0.2
RSS_LIMIT_STOP_REASON = "process_tree_rss_limit"
OUTPUT_FILENAME = "resource_report_v7.json"
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


def _read_samples(path: Path) -> tuple[list[int], bytes]:
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise ValueError(f"cannot read RSS sample file: {path}") from exc
    values: list[int] = []
    for line_number, line in enumerate(raw.splitlines(), start=1):
        if not line.strip():
            continue
        try:
            row = json.loads(line.decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError) as exc:
            raise ValueError(f"invalid RSS sample JSON at line {line_number}") from exc
        if not isinstance(row, dict):
            raise ValueError(f"RSS sample at line {line_number} must be an object")
        values.append(_nonnegative_int(row.get("process_tree_rss_bytes"),
                                       f"sample[{line_number}].process_tree_rss_bytes"))
    return values, raw


def _check_summary_stage_agreement(summary_stage: dict[str, Any],
                                   final: dict[str, Any]) -> None:
    for key in ("stage", "index", "exit_code", "stop_reason", "sample_count",
                "peak_process_tree_rss_bytes"):
        if summary_stage.get(key) != final.get(key):
            raise ValueError(f"runner summary disagrees with stage final field: {key}")


def _classify_stage(actual_leaf: Path, summary_stage: dict[str, Any]) -> dict[str, Any]:
    index = _nonnegative_int(summary_stage.get("index"), "stage.index")
    if index < 1:
        raise ValueError("stage.index must be positive")
    stage_name = summary_stage.get("stage")
    if not isinstance(stage_name, str) or stage_name not in EXPECTED_STAGE_ORDER:
        raise ValueError("stage.stage is outside the frozen R14 stage set")
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
    values, samples_raw = _read_samples(samples_path)
    declared_count = _nonnegative_int(final.get("sample_count"), "final.sample_count")
    if declared_count != len(values):
        raise ValueError("stage final sample_count disagrees with sample series")
    calculated_peak = max(values, default=0)
    declared_peak = _nonnegative_int(final.get("peak_process_tree_rss_bytes"),
                                     "final.peak_process_tree_rss_bytes")
    if declared_peak != calculated_peak:
        raise ValueError("stage final peak RSS disagrees with sampled RSS series")

    threshold_reached = any(value >= RSS_THRESHOLD_BYTES for value in values)
    if stop_reason == RSS_LIMIT_STOP_REASON and not threshold_reached:
        raise ValueError("RSS-limit stop reason has no sampled threshold hit")
    resource_failure = threshold_reached or stop_reason == RSS_LIMIT_STOP_REASON
    if resource_failure:
        disposition = "resource_failure"
    else:
        disposition = "no_sampled_rss_threshold_crossing"

    if threshold_reached and stop_reason != RSS_LIMIT_STOP_REASON:
        consistency = "sampled_threshold_hit_but_low_level_stop_reason_differs"
    elif threshold_reached:
        consistency = "consistent"
    else:
        consistency = "no_sampled_threshold_hit"

    return {
        "stage": stage_name,
        "index": index,
        "disposition": disposition,
        "resource_failure": resource_failure,
        "rss_threshold": {
            "threshold_bytes": RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": RSS_SAMPLE_INTERVAL_SECONDS,
            "sampled_threshold_hit": threshold_reached,
            "peak_sampled_rss_bytes": calculated_peak,
            "overshoot_bytes": max(0, calculated_peak - RSS_THRESHOLD_BYTES),
            "continuous_between_sample_peak": "unknown",
            "enforcement_semantics": "sampled_stop_trigger",
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
    stages = summary.get("stages")
    if not isinstance(stages, list):
        raise ValueError("run summary stages must be a list")
    stage_reports = []
    for ordinal, item in enumerate(stages, start=1):
        if not isinstance(item, dict):
            raise ValueError("run summary stage entry must be an object")
        if ordinal > len(EXPECTED_STAGE_ORDER):
            raise ValueError("run summary contains more stages than the frozen R14 plan")
        if item.get("index") != ordinal or item.get("stage") != EXPECTED_STAGE_ORDER[ordinal - 1]:
            raise ValueError("run summary stage order differs from the frozen R14 plan")
        stage_reports.append(_classify_stage(leaf, item))
    failed = [row for row in stage_reports if row["resource_failure"]]
    run_disposition = "resource_failure" if failed else "no_sampled_rss_threshold_crossing"
    return {
        "schema": "native-g1g2-r14-rss-outcome-report-v7",
        "report_status": "emitted",
        "run_disposition": run_disposition,
        "resource_failure": bool(failed),
        "failed_stages": [row["stage"] for row in failed],
        "low_level_runner_summary": {
            "path": "summary.json",
            "sha256": sha256_file(summary_path),
            "status": summary.get("status"),
            "runtime_executed": summary.get("runtime_executed"),
        },
        "stage_reports": stage_reports,
        "claim_boundary": {
            "numerical_status": "not_established",
            "physical_status": "unknown",
            "solver_success_claimed": False,
            "resource_failure_is_not_a_numerical_or_physical_verdict": True,
        },
        "reporter": {
            "threshold_bytes": RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": RSS_SAMPLE_INTERVAL_SECONDS,
            "output_is_additive": True,
            "input_bytes_modified": False,
        },
    }


def write_new_report(actual_leaf: Path, output_path: Path | None = None) -> Path:
    leaf = actual_leaf.resolve()
    output = (output_path or (leaf / OUTPUT_FILENAME)).resolve()
    if output.parent != leaf:
        raise ValueError("report output must be directly inside the actual run leaf")
    report = build_report(leaf)
    report["created_utc"] = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    try:
        with output.open("x", encoding="utf-8", newline="\n") as stream:
            json.dump(report, stream, sort_keys=True, indent=2)
            stream.write("\n")
    except FileExistsError:
        raise
    return output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actual-leaf", required=True,
                        help="completed owned R14 actual output leaf")
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
        "report_path": str(report_path),
        "reporter_exit_means": "report_written_only",
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
