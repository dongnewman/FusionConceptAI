from __future__ import annotations

import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, ok: bool, detail: str = "") -> None:
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


checks: list[dict] = []
matrix = json.loads((OUT / "attack_matrix.json").read_text(encoding="utf-8"))
manifest = json.loads((OUT / "evidence_manifest.json").read_text(encoding="utf-8"))
receipt = json.loads((OUT / "run_receipt.json").read_text(encoding="utf-8"))
expected_findings = {
    "AUTH-ISSUER-ONLY-NO-SIGNATURE-TIME-G2",
    "FOREIGN-MATERIAL-SOURCE-DIGEST",
    "UNKNOWN-SCHEMA-AND-FIELDS",
    "SCALAR-MATERIAL-SILENTLY-DROPPED",
    "SCALAR-EDGE-SILENTLY-DROPPED",
    "ERROR-ORDER-AXIS-PERMUTATION",
    "MISSING-SIGNATURE-TRUSTED-TIME-G2-MAPPING",
    "DUPLICATE-JSON-KEY-CLI",
    "CAPTURE-MISSING-HEAD-TREE",
    "CAPTURE-UNTRACKED-CONTENT-BLIND",
}
check("review_test_only", matrix["TEST_ONLY"] is True and matrix["non_evidence"] is True)
check("review_status_rework", manifest["status"] == "rework" and receipt["status"] == "rework")
check("matrix_findings_visible", set(matrix["findings"]) == expected_findings, str(matrix["findings"]))
check("focused_tests_exit", matrix["focused_tests"]["exit_code"] == 0)
check("focused_tests_raw_hashes", all(digest(OUT / item["stdout"]["path"]) == item["stdout"]["sha256"] and digest(OUT / item["stderr"]["path"]) == item["stderr"]["sha256"] for item in (matrix["focused_tests"],)))
cli = matrix["two_process_cli"]
check("two_process_semantic_replay", cli["semantic_equal"] and cli["pids_distinct"] and cli["a"]["exit_code"] == 0 and cli["b"]["exit_code"] == 0)
check("cli_raw_hashes", all(digest(OUT / item[key]["path"]) == item[key]["sha256"] for item in (cli["a"], cli["b"]) for key in ("stdout", "stderr")))
for rel, meta in manifest["artifact_hashes"].items():
    path = ROOT / rel
    check(f"artifact:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and digest(path) == meta["sha256"] and meta["line_endings"]["crlf"] == 0, f"exists={path.is_file()}")
component = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding"
component_receipt = json.loads((component / "validation_receipt.json").read_text(encoding="utf-8"))
for key in ("stdout_path", "stderr_path"):
    p = component / component_receipt["cli_probe"][key]
    expected_sha = component_receipt["cli_probe"][key.replace("_path", "_sha256")]
    check(f"component_receipt:{key}", p.is_file() and digest(p) == expected_sha, str(p))
check("frozen_source_revision", matrix["source_revision"] == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("frozen_source_tree", matrix["source_tree"] == "e28da2ff057201c2257f6b879d3860b7a49cb428")
result = {"schema": "UP1-R2.source-axis-binding.independent-review-verification.v1", "TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(x["ok"] for x in checks), "failed": sum(not x["ok"] for x in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if result["failed"] == 0 else 1)
