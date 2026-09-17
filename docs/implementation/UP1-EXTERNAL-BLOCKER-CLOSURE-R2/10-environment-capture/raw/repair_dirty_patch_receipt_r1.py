"""Repair the environment receipt's dirty-patch digest using existing raw bytes only."""
from __future__ import annotations

import hashlib
import json
import os
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "raw"


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(name: str):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def dump(name: str, value) -> None:
    (ROOT / name).write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n"
    )


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def main() -> int:
    started = utc()
    pid = os.getpid()
    machine = load("machine_observation.json")
    manifest = load("manifest.json")
    prior_cleanup = load("cleanup_inventory.json")
    raw_path = RAW / "git_diff_binary.stdout.raw"
    cached_path = RAW / "git_diff_cached_binary.stdout.raw"
    raw_sha = sha(raw_path)
    cached_sha = sha(cached_path)
    old_sha = machine.get("git", {}).get("dirty_patch_sha256")
    historical = {
        "id": "F1-environment-dirty-patch-digest-r1",
        "state": "historical_failure_preserved",
        "recorded_sha256": old_sha,
        "raw_and_fresh_sha256": raw_sha,
        "source": "reviews/external-facts-independent-review-r1/findings.json",
        "reason": "prior receipt used a digest over concatenated decoded stdout values instead of exact raw receipt bytes",
        "superseded_by": "exact raw byte SHA-256 below",
    }
    machine.setdefault("historical_failures", [])
    if not any(x.get("id") == historical["id"] for x in machine["historical_failures"]):
        machine["historical_failures"].append(historical)
    machine["git"]["dirty_patch_sha256"] = raw_sha
    machine["git"]["cached_diff_sha256"] = cached_sha
    machine["git"]["dirty_patch_digest"] = {
        "algorithm": "SHA-256",
        "input_path": "raw/git_diff_binary.stdout.raw",
        "input_bytes": "exact raw bytes as captured; no text decoding or newline normalization",
        "raw_sha256": raw_sha,
        "normalized_sha256": None,
        "normalization": "none",
        "purpose": "authoritative local dirty-patch receipt for this observation only",
    }
    machine["observation_status"] = "local_observation_only"
    machine["repair_receipt"] = {
        "name": "repair_dirty_patch_receipt_r1",
        "pid": pid,
        "started_utc": started,
        "input_raw": "raw/git_diff_binary.stdout.raw",
        "input_raw_sha256": raw_sha,
        "input_cached_raw": "raw/git_diff_cached_binary.stdout.raw",
        "input_cached_raw_sha256": cached_sha,
        "old_inconsistent_sha256": old_sha,
        "status": "repaired_exact_raw_byte_digest",
    }
    dump("machine_observation.json", machine)

    receipt = {
        "schema": "UP1.R2.environment-dirty-patch-repair-receipt.v1",
        "task_id": machine["task_id"],
        "pid": pid,
        "started_utc": started,
        "ended_utc": utc(),
        "exit_code": 0,
        "input_raw_path": "raw/git_diff_binary.stdout.raw",
        "input_raw_sha256": raw_sha,
        "input_cached_path": "raw/git_diff_cached_binary.stdout.raw",
        "input_cached_sha256": cached_sha,
        "old_recorded_sha256": old_sha,
        "new_recorded_sha256": raw_sha,
        "normalization": "none",
        "failure": None,
    }
    receipt_text = json.dumps(receipt, ensure_ascii=False, indent=2) + "\n"
    (RAW / "repair_dirty_patch_receipt_r1.stdout.raw").write_text(receipt_text, encoding="utf-8", newline="\n")
    (RAW / "repair_dirty_patch_receipt_r1.stderr.raw").write_text("", encoding="utf-8", newline="\n")
    (RAW / "repair_dirty_patch_receipt_r1.combined.raw").write_text(receipt_text, encoding="utf-8", newline="\n")
    receipt["stdout_sha256"] = sha(RAW / "repair_dirty_patch_receipt_r1.stdout.raw")
    receipt["stderr_sha256"] = sha(RAW / "repair_dirty_patch_receipt_r1.stderr.raw")
    receipt["combined_sha256"] = sha(RAW / "repair_dirty_patch_receipt_r1.combined.raw")

    manifest["status"] = "repair_r1_completed_review_pending"
    manifest["repair_receipt"] = receipt
    manifest["historical_failures"] = [historical]
    manifest["source_observation"]["dirty_patch_sha256"] = raw_sha
    manifest["source_observation"]["cached_diff_sha256"] = cached_sha
    manifest["source_observation"]["dirty_patch_digest"] = machine["git"]["dirty_patch_digest"]
    manifest["source_observation"]["note"] = "Exact raw bytes are used; no normalized digest is claimed. Local observation is not trusted provenance."
    fresh_receipt_path = RAW / "fresh_python_b1_check.receipt.json"
    if fresh_receipt_path.is_file():
        manifest["fresh_python_b1_self_check"] = json.loads(fresh_receipt_path.read_text(encoding="utf-8"))
    manifest["exact_file_set"] = sorted(
        rel(p) for p in ROOT.rglob("*") if p.is_file() and rel(p) not in {"manifest.json", "cleanup_inventory.json"}
    ) + ["cleanup_inventory.json"]
    manifest["exact_file_set"] = sorted(set(manifest["exact_file_set"]))
    hashes = {}
    for path_text in manifest["exact_file_set"]:
        if path_text in {"manifest.json", "cleanup_inventory.json"}:
            continue
        path = ROOT / Path(path_text)
        if path.is_file():
            hashes[path_text] = sha(path)
    manifest["artifact_sha256"] = hashes
    manifest["self_hash_policy"] = "manifest and cleanup_inventory self-hashes excluded; every other exact file is byte-hashed"
    dump("manifest.json", manifest)

    prior = {x.get("path"): x for x in prior_cleanup.get("entries", [])}
    rows = []
    for path in sorted(p for p in ROOT.rglob("*") if p.is_file()):
        path_text = rel(path)
        before = prior.get(path_text, {})
        rows.append(
            {
                "path": path_text,
                "owner": "W3/10-environment-capture",
                "category": "raw_receipt_or_repair_tool" if path_text.startswith("raw/") else "declared_output",
                "before_exists": before.get("before_exists", False),
                "after_exists": True,
                "before_sha256": before.get("before_sha256"),
                "after_sha256": None if path_text == "cleanup_inventory.json" else sha(path),
                "action": "retain",
                "reason": "declared capture output or mandatory raw/evidence receipt",
            }
        )
    cleanup = {
        "schema": "UP1.R2.cleanup-inventory.v1",
        "task_id": machine["task_id"],
        "status": "repair_r1_refresh_no_cleanup_required",
        "observed_utc": utc(),
        "root": str(ROOT),
        "exact_owned_set": [x["path"] for x in rows],
        "entries": rows,
        "self_hash_excluded": True,
        "note": "R1 repair refreshed dependent hashes; historical inconsistent digest is retained in machine_observation and manifest.",
    }
    dump("cleanup_inventory.json", cleanup)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        (RAW / "repair_dirty_patch_receipt_r1.stderr.raw").write_text(traceback.format_exc(), encoding="utf-8", newline="\n")
        raise
