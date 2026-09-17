"""Audit R2 G2 evidence receipts against the bytes on disk.

This read-only checker is intentionally separate from the mapping evaluator.
It recalculates every receipt-referenced raw stream and manifest input hash,
including zero-byte streams, so a hand-written receipt cannot pass.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


COMPONENT = Path(__file__).resolve().parent
REPO = COMPONENT.parents[2]
EVIDENCE = REPO / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R2" / "05-g2-mapping"
EMPTY_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"


def digest(path: Path) -> tuple[int, str]:
    data = path.read_bytes()
    return len(data), hashlib.sha256(data).hexdigest()


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def receipt_streams(value: Any, out: list[dict[str, Any]]) -> None:
    if isinstance(value, dict):
        if {"path", "bytes", "sha256"} <= set(value) and isinstance(value["path"], str) and value["path"].startswith("raw/"):
            out.append(value)
        for item in value.values():
            receipt_streams(item, out)
    elif isinstance(value, list):
        for item in value:
            receipt_streams(item, out)


def run() -> dict[str, Any]:
    receipts = [EVIDENCE / "run_receipt.json", EVIDENCE / "run_receipt_r2_rework.json"]
    streams: list[dict[str, Any]] = []
    for receipt in receipts:
        if not receipt.is_file():
            raise ValueError(f"missing_receipt:{receipt.name}")
        receipt_streams(load(receipt), streams)
    checks: list[dict[str, Any]] = []
    seen: set[str] = set()
    for entry in streams:
        rel = entry["path"]
        if rel in seen:
            continue
        seen.add(rel)
        path = EVIDENCE / rel
        if not path.is_file():
            raise ValueError(f"missing_raw:{rel}")
        actual_bytes, actual_sha = digest(path)
        ok = actual_bytes == entry["bytes"] and actual_sha == entry["sha256"]
        checks.append({"path": rel, "ok": ok, "expected_bytes": entry["bytes"], "actual_bytes": actual_bytes, "expected_sha256": entry["sha256"], "actual_sha256": actual_sha})
        if not ok:
            raise ValueError(f"raw_hash_mismatch:{rel}")

    rework = load(EVIDENCE / "run_receipt_r2_rework.json")
    empty_paths = []
    for lane in rework["two_process_replay"]:
        empty_paths.append(lane["stdout"]["path"])
    for lane in (rework["semantic_replay_cli"]["a"], rework["semantic_replay_cli"]["b"]):
        if lane["stderr"]["bytes"] == 0:
            empty_paths.append(lane["stderr"]["path"])
    if len(empty_paths) != 4 or any(next(item["actual_bytes"] for item in checks if item["path"] == rel) != 0 or next(item["actual_sha256"] for item in checks if item["path"] == rel) != EMPTY_SHA256 for rel in empty_paths):
        raise ValueError("empty_raw_stream_sha256_mismatch")

    manifest = load(EVIDENCE / "manifest.json")
    artifact_checks = []
    for rel, expected in manifest["input_artifact_hashes"].items():
        path = REPO / rel
        actual_bytes, actual_sha = digest(path)
        ok = actual_bytes == expected["bytes"] and actual_sha == expected["sha256"]
        artifact_checks.append({"path": rel, "ok": ok, "bytes": actual_bytes, "sha256": actual_sha})
        if not ok:
            raise ValueError(f"manifest_hash_mismatch:{rel}")
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return {"schema": "UP1.external-closure-r2.g2-mapping-integrity-validator.v1", "test_only": True, "non_evidence": True, "pid": os.getpid(), "utc": now, "exit_code": 0, "receipts_checked": [x.name for x in receipts], "raw_stream_count": len(checks), "raw_checks": checks, "empty_raw_stream_count": len(empty_paths), "manifest_artifact_count": len(artifact_checks), "manifest_checks": artifact_checks, "all_true": True}


if __name__ == "__main__":
    try:
        print(json.dumps(run(), ensure_ascii=False, sort_keys=True, separators=(",", ":")))
    except Exception as exc:
        print(json.dumps({"schema": "UP1.external-closure-r2.g2-mapping-integrity-validator.v1", "test_only": True, "non_evidence": True, "pid": os.getpid(), "exit_code": 1, "all_true": False, "error": str(exc)}, sort_keys=True, separators=(",", ":")))
        raise SystemExit(1)
