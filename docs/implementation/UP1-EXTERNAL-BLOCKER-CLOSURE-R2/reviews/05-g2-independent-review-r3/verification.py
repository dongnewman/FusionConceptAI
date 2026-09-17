from __future__ import annotations

import hashlib
import json
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r3"
RAW = OUT / "raw"
EVIDENCE = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping"


def sha(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_time(v):
    try:
        datetime.fromisoformat(v.replace("Z", "+00:00"))
        return v.endswith("Z") or "+00:00" in v
    except (TypeError, ValueError):
        return False


checks = []


def check(name, ok, detail=""):
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


manifest = json.loads((EVIDENCE / "manifest.json").read_text(encoding="utf-8"))
for rel, meta in manifest["input_artifact_hashes"].items():
    p = ROOT / rel
    check(f"manifest:{rel}", p.is_file() and p.stat().st_size == meta["bytes"] and sha(p) == meta["sha256"], str(p))
check("manifest_claim_ceiling", manifest["authority_verified"] is False and manifest["production_credit"] is False and manifest["status"].startswith("pass_limited"))
check("manifest_receipt_hash_audit_contract", manifest["receipt_hash_audit"] == {"validator": "tools/up1_external_closure_r2/g2_mapping/integrity_validator.py", "receipts_checked": ["run_receipt.json", "run_receipt_r2_rework.json"], "raw_stream_count": 15, "empty_raw_stream_count": 4, "all_true": True})

receipt = json.loads((EVIDENCE / "run_receipt_r2_rework.json").read_text(encoding="utf-8"))
all_streams = []
def collect(value):
    if isinstance(value, dict):
        if {"path", "bytes", "sha256"} <= set(value) and isinstance(value["path"], str) and value["path"].startswith("raw/"):
            all_streams.append(value)
        for x in value.values(): collect(x)
    elif isinstance(value, list):
        for x in value: collect(x)
collect(json.loads((EVIDENCE / "run_receipt.json").read_text(encoding="utf-8")))
collect(receipt)
unique = {x["path"]: x for x in all_streams}
check("r2_receipt_stream_count", len(unique) == 15, str(len(unique)))
empty_sha = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
for rel, item in unique.items():
    p = EVIDENCE / rel
    actual_bytes = p.stat().st_size if p.is_file() else -1
    actual_sha = sha(p) if p.is_file() else "missing"
    check(f"raw:{rel}", p.is_file() and actual_bytes == item["bytes"] and actual_sha == item["sha256"], f"expected={item['bytes']}/{item['sha256']} actual={actual_bytes}/{actual_sha}")
    if item["bytes"] == 0:
        check(f"empty_sha:{rel}", actual_sha == empty_sha, actual_sha)
rework_empty = [lane["stdout"]["path"] for lane in receipt["two_process_replay"]] + [receipt["semantic_replay_cli"][key]["stderr"]["path"] for key in ("a", "b")]
check("rework_empty_stream_count", len(rework_empty) == 4 and all(unique[path]["bytes"] == 0 for path in rework_empty))

audit = json.loads((EVIDENCE / "integrity_audit_receipt.json").read_text(encoding="utf-8"))
check("integrity_audit_receipt_true", audit["result"] == {"all_true": True, "receipts_checked": 2, "raw_stream_count": 15, "empty_raw_stream_count": 4, "manifest_artifact_count": 10})
for stream in ("stdout", "stderr"):
    meta = audit[stream]; p = EVIDENCE / meta["path"]
    check(f"integrity_audit:{stream}", p.is_file() and p.stat().st_size == meta["bytes"] and sha(p) == meta["sha256"], str(p))
check("integrity_audit_pid_utc_exit", audit["pid"] > 0 and audit["exit_code"] == 0 and valid_time(audit["utc_start"]) and valid_time(audit["utc_end"]))

a = json.loads((RAW / "r2_logic_a.stdout.raw").read_text(encoding="utf-8"))
b = json.loads((RAW / "r2_logic_b.stdout.raw").read_text(encoding="utf-8"))
volatile = {"started_at_utc", "ended_at_utc", "pid", "parent_pid"}
sem_a = {k: v for k, v in a.items() if k not in volatile}; sem_b = {k: v for k, v in b.items() if k not in volatile}
check("r2_logic_47_all_pass", a["case_count"] == 47 and b["case_count"] == 47 and all(x["ok"] for x in a["rows"]) and all(x["ok"] for x in b["rows"]))
check("r2_logic_semantic_replay", sem_a == sem_b, f"A={a['pid']} B={b['pid']}")
check("r2_logic_fresh_process", a["pid"] != b["pid"] and a["parent_pid"] > 0 and b["parent_pid"] > 0 and valid_time(a["started_at_utc"]) and valid_time(b["ended_at_utc"]))
historical = json.loads((ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r2/raw/matrix_a.stdout.raw").read_text(encoding="utf-8"))
check("r2_logic_not_drifted_from_review_r2", {k: v for k, v in historical.items() if k not in volatile} == sem_a)
for label in ("r2_logic_a", "r2_logic_b"):
    for stream in ("stdout", "stderr"):
        p = RAW / f"{label}.{stream}.raw"
        check(f"r3_raw:{label}.{stream}", p.is_file() and (p.stat().st_size == 0) == (stream == "stderr"), str(p))

result = {"schema": "UP1.external-closure-r2.g2-independent-review-r3-verification.v1", "TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(x["ok"] for x in checks), "failed": sum(not x["ok"] for x in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if result["failed"] == 0 else 1)
