from __future__ import annotations

import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
checks = []


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, ok: bool, detail: str = "") -> None:
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


matrix = json.loads((OUT / "attack_matrix.json").read_text(encoding="utf-8"))
manifest = json.loads((OUT / "evidence_manifest.json").read_text(encoding="utf-8"))
receipt = json.loads((OUT / "run_receipt.json").read_text(encoding="utf-8"))
expected_findings = {"ISSUER-ONLY-NO-AUTHORITY", "NESTED-IDENTITY-UNKNOWN-FIELD", "IDENTITY-SCHEMA-VERSION-UNKNOWN", "UNKNOWN-STATE", "UNKNOWN-PROVENANCE", "AD56-CANNOT-ESCALATE"}
check("review_non_evidence", matrix["TEST_ONLY"] is True and matrix["non_evidence"] is True and manifest["non_evidence"] is True)
check("rework_visible", matrix["status"] == "rework" and manifest["status"] == "rework" and receipt["status"] == "rework")
check("expected_findings_visible", set(matrix["findings"]) == expected_findings, str(matrix["findings"]))
check("focused_tests_exit", matrix["focused_tests"]["exit_code"] == 0)
for item in (matrix["focused_tests"], matrix["two_process_cli"]["a"], matrix["two_process_cli"]["b"]):
    for stream in ("stdout", "stderr"):
        check(f"raw:{item['stdout']['path'] if stream == 'stdout' else item['stderr']['path']}", digest(OUT / item[stream]["path"]) == item[stream]["sha256"])
cli = matrix["two_process_cli"]
check("two_process_cli", cli["semantic_equal"] and cli["pids_distinct"] and cli["a"]["exit_code"] == 0 and cli["b"]["exit_code"] == 0)
for rel, meta in manifest["artifact_hashes"].items():
    path = ROOT / rel
    check(f"artifact:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and digest(path) == meta["sha256"] and meta["crlf"] == 0)
component = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding"
component_receipt = json.loads((component / "validation_receipt.json").read_text(encoding="utf-8"))
for key in ("stdout_path", "stderr_path"):
    item = component_receipt["cli_probe"]; path = component / item[key]; expected = item[key.replace("_path", "_sha256")]
    check(f"component_receipt:{key}", path.is_file() and digest(path) == expected)
check("frozen_head", matrix["source_revision"] == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("frozen_tree", matrix["source_tree"] == "e28da2ff057201c2257f6b879d3860b7a49cb428")
result = {"schema": "UP1-R2.source-axis-binding.independent-review-verification.v2", "TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(x["ok"] for x in checks), "failed": sum(not x["ok"] for x in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if result["failed"] == 0 else 1)
