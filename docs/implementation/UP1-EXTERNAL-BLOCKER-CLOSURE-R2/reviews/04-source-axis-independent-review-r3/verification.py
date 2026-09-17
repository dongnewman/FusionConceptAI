from __future__ import annotations

import hashlib
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[4]
checks = []


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def check(name: str, ok: bool, detail: str = "") -> None:
    checks.append({"name": name, "ok": bool(ok), "detail": detail})


matrix = json.loads((OUT / "attack_matrix.json").read_text(encoding="utf-8"))
manifest = json.loads((OUT / "evidence_manifest.json").read_text(encoding="utf-8"))
receipt = json.loads((OUT / "run_receipt.json").read_text(encoding="utf-8"))
check("pass_limited_and_non_evidence", matrix["status"] == "pass_limited" and matrix["TEST_ONLY"] and matrix["non_evidence"] and manifest["status"] == "pass_limited" and receipt["status"] == "pass_limited")
check("no_findings", matrix["findings"] == [])
check("focused_tests_exit", matrix["focused_tests"]["exit_code"] == 0)
check("compile_exit", matrix["compile"]["exit_code"] == 0)
for proc in (matrix["focused_tests"], matrix["compile"], matrix["two_process_cli"]["a"], matrix["two_process_cli"]["b"]):
    for stream in ("stdout", "stderr"):
        meta = proc[stream]
        check(f"raw:{meta['path']}", (OUT / meta["path"]).is_file() and sha(OUT / meta["path"]) == meta["sha256"])
cli = matrix["two_process_cli"]
check("two_process_cli_byte_determinism", cli["semantic_equal"] and cli["pids_distinct"] and cli["a"]["exit_code"] == 0 and cli["b"]["exit_code"] == 0)
for rel, meta in manifest["artifact_hashes"].items():
    path = ROOT / rel
    check(f"artifact:{rel}", path.is_file() and path.stat().st_size == meta["bytes"] and sha(path) == meta["sha256"] and meta["crlf"] == 0)
component = ROOT / "docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/04-source-axis-binding"
component_receipt = json.loads((component / "validation_receipt.json").read_text(encoding="utf-8"))
for key in ("stdout_path", "stderr_path"):
    meta = component_receipt["cli_probe"]; path = component / meta[key]
    check(f"component_receipt:{key}", path.is_file() and sha(path) == meta[key.replace("_path", "_sha256")])
check("frozen_head", matrix["source_revision"] == "b2c04d8339774635aaecd73651efcdb101e01b5d")
check("frozen_tree", matrix["source_tree"] == "e28da2ff057201c2257f6b879d3860b7a49cb428")
result = {"schema": "UP1-R2.source-axis-binding.independent-review-verification.v3", "TEST_ONLY": True, "non_evidence": True, "check_count": len(checks), "passed": sum(x["ok"] for x in checks), "failed": sum(not x["ok"] for x in checks), "checks": checks}
(OUT / "verification.json").write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")), encoding="utf-8")
print(json.dumps(result, ensure_ascii=False, sort_keys=True, separators=(",", ":")))
raise SystemExit(0 if result["failed"] == 0 else 1)
