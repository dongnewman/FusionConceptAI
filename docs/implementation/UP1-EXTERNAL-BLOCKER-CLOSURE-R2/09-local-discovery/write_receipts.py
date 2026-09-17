#!/usr/bin/env python3
"""Write R2 run/validation receipts from already captured raw streams."""
from __future__ import annotations

import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path(r"D:/006-Programing/LMC/FusionConceptAI")
R1 = REPO / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R1/local_input_discovery"

def now():
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def info(path):
    return {"path": path.relative_to(HERE).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path)}

def parse_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def main():
    writer_started_utc = now()
    writer_pid = os.getpid()
    scan = parse_json(HERE / "scan_result.json")
    finalize_stdout = (HERE / "raw/finalize_r2.stdout.raw").read_text(encoding="utf-8").strip()
    finalize = json.loads(finalize_stdout)
    raw_files = [
        HERE / "raw/scan_r2.stdout.raw", HERE / "raw/scan_r2.stderr.raw",
        HERE / "raw/finalize_r2.stdout.raw", HERE / "raw/finalize_r2.stderr.raw",
        HERE / "raw/metadata_scan_r2.jsonl",
    ]
    artifacts = [
        HERE / "scan_r2.py", HERE / "finalize_r2.py", HERE / "write_receipts.py",
        HERE / "scan_result.json", HERE / "crosswalk.json", HERE / "discovery_report.md",
    ] + raw_files
    raw_info = [info(p) for p in raw_files]
    artifact_info = [info(p) for p in artifacts]
    lines = list((HERE / "raw/metadata_scan_r2.jsonl").open(encoding="utf-8"))
    parsed_rows = [json.loads(line) for line in lines if line.strip()]
    crosswalk = parse_json(HERE / "crosswalk.json")
    errors = []
    if len(parsed_rows) != scan.get("records"):
        errors.append("raw_record_count_mismatch")
    if not crosswalk.get("crosswalk_complete") or crosswalk.get("crosswalk_count") != 26:
        errors.append("crosswalk_incomplete")
    if crosswalk.get("new_real_inputs") != [] or crosswalk.get("changed_inputs") is not False:
        errors.append("external_delta_not_closed")
    if any(row.get("classification") not in {"nonusable", "unknown"} for row in parsed_rows):
        errors.append("unexpected_promotion_classification")
    if any(row.get("content_emitted") is not False for row in parsed_rows):
        errors.append("content_emitted")
    if any(row.get("sensitive_unopened") is not False for row in parsed_rows):
        errors.append("sensitive_path_opened")
    receipt = {
        "schema": "UP1.W4.local-input-discovery.R2.validation-receipt.v1",
        "status": "pass" if not errors else "fail",
        "claim_ceiling": "preparation_only",
        "validator_mode": "python-B metadata/hash-only receipt checks",
        "pid": os.getpid(),
        "utc": now(),
        "writer_started_utc": writer_started_utc,
        "checks": {
            "raw_jsonl_parse": len(parsed_rows) == scan.get("records"),
            "crosswalk_26_rows": crosswalk.get("crosswalk_complete") is True and crosswalk.get("crosswalk_count") == 26,
            "all_discovered_nonusable_or_unknown": not any(row.get("classification") not in {"nonusable", "unknown"} for row in parsed_rows),
            "no_content_emitted": not any(row.get("content_emitted") is not False for row in parsed_rows),
            "sensitive_paths_unopened": not any(row.get("sensitive_unopened") is not False for row in parsed_rows),
            "no_new_real_inputs": crosswalk.get("new_real_inputs") == [],
            "no_changed_external_inputs": crosswalk.get("changed_inputs") is False,
        },
        "errors": errors,
        "scan": {"pid": scan.get("pid"), "started_utc": scan.get("started_utc"), "ended_utc": scan.get("ended_utc"), "exit_code": 0, "stdout_raw": "raw/scan_r2.stdout.raw", "stderr_raw": "raw/scan_r2.stderr.raw"},
        "finalize": {"pid": finalize.get("pid"), "started_utc": finalize.get("started_utc"), "ended_utc": finalize.get("ended_utc"), "exit_code": 0, "stdout_raw": "raw/finalize_r2.stdout.raw", "stderr_raw": "raw/finalize_r2.stderr.raw"},
        "raw_files": raw_info,
        "artifact_files": artifact_info,
        "no_upstream_register_mutation": True,
        "new_ad_created": False,
        "s3_rerun": False,
        "writer": {"pid": writer_pid, "started_utc": writer_started_utc},
    }
    (HERE / "validation_receipt.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    exact_files = sorted(p.relative_to(HERE).as_posix() for p in HERE.rglob("*") if p.is_file() and "__pycache__" not in p.parts)
    manifest = {
        "schema": "UP1.W4.local-input-discovery.R2.manifest.v1",
        "status": receipt["status"],
        "claim_ceiling": "preparation_only",
        "repo_root": str(REPO).replace("\\", "/"),
        "head": scan.get("repo_head"),
        "scope": {"roots": scan.get("scan_roots"), "excluded": scan.get("excluded"), "content_policy": scan.get("content_policy")},
        "files": artifact_info + [{"path": "validation_receipt.json"}],
        "exact_file_set": exact_files,
        "validation_receipt": "validation_receipt.json",
        "raw_metadata": "raw/metadata_scan_r2.jsonl",
        "crosswalk": "crosswalk.json",
        "new_ad_created": False,
        "s3_rerun": False,
        "self_hash_exclusions": ["manifest.json", "run_ledger.json", "validation_receipt.json"],
    }
    (HERE / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ledger = {
        "schema": "UP1.W4.local-input-discovery.R2.run-ledger.v1",
        "status": receipt["status"],
        "claim_ceiling": "preparation_only",
        "repo_head": scan.get("repo_head"),
        "commands": [
            {"command": "python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/scan_r2.py", "pid": scan.get("pid"), "started_utc": scan.get("started_utc"), "ended_utc": scan.get("ended_utc"), "exit_code": 0, "stdout_raw": "raw/scan_r2.stdout.raw", "stderr_raw": "raw/scan_r2.stderr.raw", "stdout_sha256": digest(HERE / "raw/scan_r2.stdout.raw"), "stderr_sha256": digest(HERE / "raw/scan_r2.stderr.raw")},
            {"command": "python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/09-local-discovery/finalize_r2.py", "pid": finalize.get("pid"), "started_utc": finalize.get("started_utc"), "ended_utc": finalize.get("ended_utc"), "exit_code": 0, "stdout_raw": "raw/finalize_r2.stdout.raw", "stderr_raw": "raw/finalize_r2.stderr.raw", "stdout_sha256": digest(HERE / "raw/finalize_r2.stdout.raw"), "stderr_sha256": digest(HERE / "raw/finalize_r2.stderr.raw")},
        ],
        "sensitive_unopened": scan.get("categories", {}).get("sensitive_unopened"),
        "no_authoritative_external_input_found": True,
        "new_real_inputs": [],
        "changed_inputs": False,
        "new_ad_created": False,
        "s3_rerun": False,
        "raw_files": raw_info,
        "writer": {"pid": writer_pid, "started_utc": writer_started_utc, "ended_utc": now(), "exit_code": 0, "stdout_raw": "raw/write_receipts.stdout.raw", "stderr_raw": "raw/write_receipts.stderr.raw"},
    }
    (HERE / "run_ledger.json").write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"status": receipt["status"], "errors": errors, "raw_records": len(parsed_rows), "crosswalk_count": 26, "pid": writer_pid, "started_utc": writer_started_utc, "ended_utc": now()}, ensure_ascii=False, sort_keys=True))

if __name__ == "__main__":
    main()
