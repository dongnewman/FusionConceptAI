from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime
from pathlib import Path

ROOT = Path.cwd().resolve()
OUT = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r1"
RAW = OUT / "raw"


def h(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def valid_time(value: str) -> bool:
    try:
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return value.endswith("Z") or "+00:00" in value
    except ValueError:
        return False


checks = []
def check(name: str, ok: bool, detail: str = ""):
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


ma = json.loads((RAW / "matrix_a.stdout.raw").read_text(encoding="utf-8"))
mb = json.loads((RAW / "matrix_b.stdout.raw").read_text(encoding="utf-8"))
check("matrix_a_label", ma["TEST_ONLY"] is True and ma["non_evidence"] is True)
check("matrix_b_label", mb["TEST_ONLY"] is True and mb["non_evidence"] is True)
volatile = {"started_at_utc", "ended_at_utc", "pid", "parent_pid"}
def semantic(doc):
    return {k: v for k, v in doc.items() if k not in volatile}
check("two_process_semantic_replay", semantic(ma) == semantic(mb), f"A_pid={ma.get('pid')};B_pid={mb.get('pid')}")
check("fresh_process_pids_distinct", ma.get("pid") != mb.get("pid"), f"{ma.get('pid')} vs {mb.get('pid')}")
check("matrix_a_process_receipt", isinstance(ma.get("parent_pid"), int) and ma["parent_pid"] > 0 and valid_time(ma["started_at_utc"]) and valid_time(ma["ended_at_utc"]) and ma.get("source_revision") == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("matrix_b_process_receipt", isinstance(mb.get("parent_pid"), int) and mb["parent_pid"] > 0 and valid_time(mb["started_at_utc"]) and valid_time(mb["ended_at_utc"]) and mb.get("source_revision") == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("matrix_case_count", ma["case_count"] == 34 and len(ma["rows"]) == 34)
check("matrix_expected_findings_visible", [r["case_id"] for r in ma["rows"] if r.get("classification") == "finding"] == ["G2-NEG-FOREIGN-CANDIDATE-SELF-CONSISTENT", "G2-NEG-FOREIGN-SOURCE-SELF-CONSISTENT"])
for stream in ("matrix_a.stdout.raw", "matrix_a.stderr.raw", "matrix_b.stdout.raw", "matrix_b.stderr.raw"):
    check(f"raw:{stream}", (RAW / stream).is_file(), str(RAW / stream))

component_manifest = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping/manifest.json"
manifest = json.loads(component_manifest.read_text(encoding="utf-8"))
for rel, meta in manifest["input_artifact_hashes"].items():
    path = ROOT / rel
    check(f"component_manifest:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and h(path) == meta["sha256"], f"exists={path.is_file()} bytes={path.stat().st_size if path.exists() else None} sha={h(path) if path.exists() else None}")
check("component_manifest_claim_ceiling", manifest["authority_verified"] is False and manifest["production_credit"] is False and "no_external_authority" in manifest["claim_ceiling"])

review_manifest = json.loads((OUT / "manifest.json").read_text(encoding="utf-8"))
for section in ("review_outputs", "retained_raw"):
    for rel, meta in review_manifest[section].items():
        path = OUT / rel
        check(f"review_manifest:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and h(path) == meta["sha256"], f"exists={path.is_file()} bytes={path.stat().st_size if path.exists() else None} sha={h(path) if path.exists() else None}")

receipt_path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping/run_receipt.json"
receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
check("component_receipt_exit", isinstance(receipt.get("exit_code"), int) and receipt["exit_code"] == 0)
check("component_receipt_pid", isinstance(receipt.get("pid"), int) and receipt["pid"] > 0)
check("component_receipt_utc", valid_time(receipt["utc_start"]) and valid_time(receipt["utc_end"]))
for item in [receipt["raw_streams"][x] for x in ("stdout", "stderr", "combined")]:
    path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping" / item["path"]
    check(f"component_raw:{item['path']}", path.is_file() and path.stat().st_size == item["bytes"] and h(path) == item["sha256"], str(path))
for item in receipt["cli_controls"]:
    for stream in ("stdout", "stderr"):
        meta = item[stream]
        path = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/05-g2-mapping" / meta["path"]
        check(f"component_cli_raw:{meta['path']}", path.is_file() and path.stat().st_size == meta["bytes"] and h(path) == meta["sha256"], str(path))
    check(f"component_cli:{item['case']}:pid", isinstance(item["pid"], int) and item["pid"] > 0)
    check(f"component_cli:{item['case']}:exit", isinstance(item["exit_code"], int))
    check(f"component_cli:{item['case']}:utc", valid_time(item["utc_start"]) and valid_time(item["utc_end"]))

check("source_revision_frozen", ma["source_revision"] == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("no_heavy_lane_in_matrix", not any(x in (RAW / "matrix_a.stdout.raw").read_text(encoding="utf-8").lower() for x in ("julia", "desc", "solver", "provider", "mesh")))
check("no_extra_review_raw_missing", all(p.is_file() for p in RAW.iterdir() if p.suffix == ".raw"))
for label in ("test_only", "typed_absent"):
    receipt = json.loads((RAW / f"cli_wrapper_{label}.receipt.raw").read_text(encoding="utf-8"))
    check(f"wrapped_cli:{label}:labels", receipt["TEST_ONLY"] is True and receipt["non_evidence"] is True)
    check(f"wrapped_cli:{label}:pid", isinstance(receipt["pid"], int) and receipt["pid"] > 0 and isinstance(receipt["parent_pid"], int) and receipt["parent_pid"] > 0)
    check(f"wrapped_cli:{label}:exit", isinstance(receipt["numeric_exit_code"], int) and receipt["numeric_exit_code"] == 0)
    check(f"wrapped_cli:{label}:utc", valid_time(receipt["started_at_utc"]) and valid_time(receipt["ended_at_utc"]))
    for field in ("stdout_path", "stderr_path"):
        path = ROOT / Path(receipt[field])
        digest = h(path)
        check(f"wrapped_cli:{label}:{field}", path.is_file() and digest == receipt[field.replace("_path", "_sha256")], str(path))

result = {"TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(c["ok"] for c in checks), "failed": sum(not c["ok"] for c in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if all(c["ok"] for c in checks) else 1)
