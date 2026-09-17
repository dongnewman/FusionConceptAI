from __future__ import annotations

import hashlib
import json
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r2"
RAW = OUT / "raw"


def sha(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_time(value: str):
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return value.endswith("Z") or "+00:00" in value
    except (TypeError, ValueError):
        return False


checks = []


def check(name, ok, detail=""):
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


a = json.loads((RAW / "matrix_a.stdout.raw").read_text(encoding="utf-8"))
b = json.loads((RAW / "matrix_b.stdout.raw").read_text(encoding="utf-8"))
volatile = {"started_at_utc", "ended_at_utc", "pid", "parent_pid"}
semantic_a = {k: v for k, v in a.items() if k not in volatile}
semantic_b = {k: v for k, v in b.items() if k not in volatile}
check("matrix_labels", a["TEST_ONLY"] is True and a["non_evidence"] is True and b["TEST_ONLY"] is True and b["non_evidence"] is True)
check("matrix_exit_raw", a["case_count"] == 47 and b["case_count"] == 47 and all(row.get("ok") for row in a["rows"]) and all(row.get("ok") for row in b["rows"]))
check("matrix_two_process_semantic_equality", semantic_a == semantic_b, f"A_pid={a['pid']};B_pid={b['pid']}")
check("matrix_distinct_pids", a["pid"] != b["pid"] and a["pid"] > 0 and b["pid"] > 0)
check("matrix_process_receipts", all(isinstance(x, int) and x > 0 for x in (a["parent_pid"], b["parent_pid"])) and all(valid_time(a[k]) and valid_time(b[k]) for k in ("started_at_utc", "ended_at_utc")))
required_r1 = {"G2-POS-TEST_ONLY-SCHEMA", "G2-POS-TEST_ONLY-EVALUATE", "G2-POS-TYPED-ABSENT", "G2-SEC-PRODUCTION-NO-AUTHORITY", "G2-NEG-DUPLICATE-JSON-TOP", "G2-NEG-DUPLICATE-JSON-NESTED", "G2-NEG-UNKNOWN-TOP", "G2-NEG-UNKNOWN-NESTED", "G2-NEG-AXIS-DUPLICATE-ID", "G2-NEG-AXIS-MISSING", "G2-NEG-AXIS-DUPLICATE-EVIDENCE-REF", "G2-NEG-AXIS-BAD-VERSION", "G2-NEG-EDGE-FORWARD-HASH", "G2-NEG-EDGE-REVERSE-HASH", "G2-NEG-EDGE-FORWARD-REF", "G2-NEG-EDGE-REVERSE-REF", "G2-NEG-FOREIGN-CANDIDATE-INCONSISTENT", "G2-NEG-FOREIGN-SOURCE-INCONSISTENT", "G2-NEG-ISSUER", "G2-NEG-KEY-ID", "G2-NEG-POLICY-OID", "G2-NEG-NAME-CONSTRAINT", "G2-NEG-EKU", "G2-NEG-KEY-USAGE", "G2-NEG-REVOCATION", "G2-NEG-FRESHNESS", "G2-NEG-NONCE", "G2-NEG-SEQUENCE", "G2-NEG-IDEMPOTENCY", "G2-NEG-REPLAY", "G2-NEG-WRONG-TYPE", "G2-NEG-FOREIGN-CANDIDATE-SELF-CONSISTENT", "G2-NEG-FOREIGN-SOURCE-SELF-CONSISTENT", "G2-POS-ARRAY-PERMUTATION"}
present = {row["case_id"] for row in a["rows"]}
check("r1_34_cases_replayed", required_r1 <= present, f"missing={sorted(required_r1-present)}")
added = {"G2-NEG-EXPECTED-BINDING-MISSING", "G2-NEG-EXPECTED-BINDING-REPLACED-CANDIDATE", "G2-NEG-EXPECTED-BINDING-AXIS-REPLACED", "G2-NEG-EXPECTED-BINDING-SELF-REFERENCE", "G2-NEG-CANONICAL-DECLARATION-FORGED", "G2-NEG-CANONICAL-DECLARATION-MISSING", "G2-NEG-SOURCE-IDENTITY-FORGED", "G2-NEG-INTEGRITY-SOURCE-FORGED", "G2-NEG-SIGNATURE-PAYLOAD-FORGED", "G2-NEG-SIGNATURE-PAYLOAD-MISSING", "G2-NEG-RECEIPT-FORGED", "G2-NEG-RECEIPT-MISSING", "G2-NEG-CANONICAL-AXIS-REORDER"}
check("r2_added_attack_cases", added <= present, f"missing={sorted(added-present)}")
check("no_heavy_lane", not any(x in (RAW / "matrix_a.stdout.raw").read_text(encoding="utf-8").lower() for x in ("julia", "desc", "solver", "provider", "mesh")))

component_manifest_path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping/manifest.json"
component_manifest = json.loads(component_manifest_path.read_text(encoding="utf-8"))
for rel, meta in component_manifest["input_artifact_hashes"].items():
    path = ROOT / rel
    check(f"component_hash:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and sha(path) == meta["sha256"], str(path))
check("component_claim_ceiling", component_manifest["authority_verified"] is False and component_manifest["production_credit"] is False)

review_manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
for section in ("input_hashes", "review_outputs", "retained_raw"):
    base = ROOT if section == "input_hashes" else OUT
    for rel, meta in review_manifest[section].items():
        path = base / rel
        check(f"review_manifest:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and sha(path) == meta["sha256"], str(path))

r2_receipt = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping/run_receipt_r2_rework.json"
rr = json.loads(r2_receipt.read_text(encoding="utf-8"))
for replay in rr["two_process_replay"]:
    check(f"rework_receipt:{replay['lane']}:pid_utc_exit", replay["pid"] > 0 and isinstance(replay["exit_code"], int) and replay["exit_code"] == 0 and valid_time(replay["utc_start"]) and valid_time(replay["utc_end"]))
    for stream in ("stdout", "stderr"):
        meta = replay[stream]; path = r2_receipt.parent / meta["path"]
        check(f"rework_receipt:{replay['lane']}:{stream}", path.is_file() and path.stat().st_size == meta["bytes"] and sha(path) == meta["sha256"], str(path))
for replay in (rr["semantic_replay_cli"]["a"], rr["semantic_replay_cli"]["b"]):
    check(f"rework_cli:{replay['pid']}:pid_utc_exit", replay["pid"] > 0 and replay["exit_code"] == 0 and valid_time(replay["utc_start"]) and valid_time(replay["utc_end"]))
    for stream in ("stdout", "stderr"):
        meta = replay[stream]; path = r2_receipt.parent / meta["path"]
        check(f"rework_cli:{replay['pid']}:{stream}", path.is_file() and path.stat().st_size == meta["bytes"] and sha(path) == meta["sha256"], str(path))
check("rework_cli_byte_equal", rr["semantic_replay_cli"]["outputs_byte_equal"] is True)

for label in ("test_only", "typed_absent"):
    receipt = json.loads((RAW / f"cli_{label}.receipt.raw").read_text(encoding="utf-8"))
    check(f"independent_cli:{label}:labels", receipt["TEST_ONLY"] is True and receipt["non_evidence"] is True)
    check(f"independent_cli:{label}:pid_utc_exit", receipt["pid"] > 0 and receipt["parent_pid"] > 0 and receipt["numeric_exit_code"] == 0 and valid_time(receipt["started_at_utc"]) and valid_time(receipt["ended_at_utc"]))
    for stream in ("stdout", "stderr"):
        path = ROOT / Path(receipt[f"{stream}_path"])
        check(f"independent_cli:{label}:{stream}", path.is_file() and sha(path) == receipt[f"{stream}_sha256"], str(path))

result = {"TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(x["ok"] for x in checks), "failed": sum(not x["ok"] for x in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if result["failed"] == 0 else 1)
