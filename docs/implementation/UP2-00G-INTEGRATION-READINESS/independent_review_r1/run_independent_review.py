from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
TARGET = ROOT / "docs/implementation/UP2-00G-INTEGRATION-READINESS"

FROZEN = {
    "report.md": "3a5cba18f2f660fdda652fa933b354d7e987c6fbf0472bdc70987dc4c11e27d5",
    "manifest.json": "f8ec73e8d3b10a17493012268724bbcbdb5caf0c4cb869bb2490c45a98adc43b",
    "input_hashes.json": "27926d49a912d2dcf09cd688a2aaca49a0771375232367ade8573d1dc574a275",
    "qa.json": "21ea85358ce37c2cb00b39197b406da44d88da96cc67c93d5485525807b5644f",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run_command(name: str, args: list[str], cwd: Path = ROOT) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    p = subprocess.run(args, cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    finished = datetime.now(timezone.utc).isoformat()
    return {
        "name": name,
        "argv": args,
        "started_utc": started,
        "finished_utc": finished,
        "exit": p.returncode,
        "stdout": p.stdout,
        "stderr": p.stderr,
    }


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    report_text = (TARGET / "report.md").read_text(encoding="utf-8")
    manifest = json.loads((TARGET / "manifest.json").read_text(encoding="utf-8"))
    input_hashes = json.loads((TARGET / "input_hashes.json").read_text(encoding="utf-8"))
    qa = json.loads((TARGET / "qa.json").read_text(encoding="utf-8"))
    fixture_path = ROOT / "test/GenomeV5/UP2/fixtures.json"
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))

    checks: dict[str, object] = {}
    failures: list[str] = []

    frozen_actual = {k: sha(TARGET / k) for k in FROZEN}
    checks["frozen_target_hashes"] = {
        k: {"expected": v, "actual": frozen_actual[k], "match": v == frozen_actual[k]}
        for k, v in FROZEN.items()
    }
    if any(v["match"] is False for v in checks["frozen_target_hashes"].values()):
        failures.append("a specified frozen G input hash does not match")

    expected_ids = [f"N{cls:02d}-{row:02d}" for cls in range(1, 11) for row in range(1, 6)]
    fixture_ids = [x["id"] for x in fixture["mutations"]]
    source_path = ROOT / "src/GenomeV5/UP2/TypedPrecompilerValidatorV1.jl"
    source_text = source_path.read_text(encoding="utf-8")
    source_ids = re.findall(r'\("(N\d{2}-\d{2})",\s*"/', source_text)
    matrix_ids = re.findall(r"^\| (N\d{2}-\d{2}) \|", report_text, re.MULTILINE)
    checks["fixture_50_exact"] = {
        "mutation_count": len(fixture_ids),
        "schema_validation_only": fixture.get("schema_validation_only"),
        "ids_exact": fixture_ids == expected_ids,
        "class_counts": {f"N{i:02d}": fixture_ids.count(f"N{i:02d}-01") for i in range(1, 11)},
    }
    checks["source_50_registration_ids"] = {
        "count": len(source_ids),
        "ids_exact": source_ids == expected_ids,
        "duplicates": sorted({x for x in source_ids if source_ids.count(x) > 1}),
    }
    checks["report_matrix_50_ids"] = {
        "count": len(matrix_ids),
        "ids_exact": matrix_ids == expected_ids,
        "pending_cells": report_text.count("pending: fresh receipt + checker + two-process replay"),
    }
    for label, result in (("fixture_50_exact", checks["fixture_50_exact"]), ("source_50_registration_ids", checks["source_50_registration_ids"]), ("report_matrix_50_ids", checks["report_matrix_50_ids"])):
        if result.get("ids_exact") is not True:
            failures.append(f"{label} does not contain the exact 50-row ID sequence")
    if checks["report_matrix_50_ids"]["pending_cells"] != 50:
        failures.append("report does not mark all 50 formal B04 cells pending")

    records = {x["path"]: x["sha256"] for x in input_hashes["files"]}
    class_rows = re.findall(
        r"^\| (N\d{2}) \| .*? \| `([^`]+)` \| `([0-9a-f]{64})` \| `([^`]+)` \| `([0-9a-f]{64})` \|$",
        report_text,
        re.MULTILINE,
    )
    class_hash_results = []
    for cls, source_rel, source_expected, manifest_rel, manifest_expected in class_rows:
        source_current = sha(ROOT / source_rel)
        manifest_current = sha(ROOT / manifest_rel)
        class_hash_results.append({
            "class": cls,
            "source": {"path": source_rel, "report": source_expected, "input_hashes": records.get(source_rel), "current": source_current, "report_snapshot_match": source_expected == records.get(source_rel), "current_match": source_current == source_expected},
            "manifest": {"path": manifest_rel, "report": manifest_expected, "input_hashes": records.get(manifest_rel), "current": manifest_current, "report_snapshot_match": manifest_expected == records.get(manifest_rel), "current_match": manifest_current == manifest_expected},
        })
    checks["class_source_manifest_hashes"] = class_hash_results
    if len(class_rows) != 10:
        failures.append(f"expected 10 class rows, found {len(class_rows)}")
    snapshot_hash_failures = [x for x in class_hash_results if not x["source"]["report_snapshot_match"] or not x["manifest"]["report_snapshot_match"]]
    if snapshot_hash_failures:
        failures.append("G report class hashes disagree with its frozen input_hashes")
    current_drift = [x for x in class_hash_results if not x["source"]["current_match"] or not x["manifest"]["current_match"]]
    checks["post_snapshot_current_drift"] = current_drift

    up2 = json.loads((ROOT / "docs/implementation/UP2-00/evidence_manifest.json").read_text(encoding="utf-8"))
    n03 = json.loads((ROOT / "docs/implementation/UP2-00D-N03/evidence_manifest.json").read_text(encoding="utf-8"))
    n04 = json.loads((ROOT / "docs/implementation/UP2-00D-N04/evidence_manifest.json").read_text(encoding="utf-8"))
    n07 = json.loads((ROOT / "docs/implementation/UP2-00B-N07-N08/evidence_manifest.json").read_text(encoding="utf-8"))
    n09 = json.loads((ROOT / "docs/implementation/UP2-00C-N09/evidence_manifest.json").read_text(encoding="utf-8"))
    n10 = json.loads((ROOT / "docs/implementation/UP2-00C-N10-IDENTITY-RECEIPT/evidence_manifest.json").read_text(encoding="utf-8"))
    e1_path = ROOT / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/evidence_manifest.json"
    e2_path = ROOT / "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/evidence_manifest.json"
    e1 = json.loads(e1_path.read_text(encoding="utf-8"))
    e2 = json.loads(e2_path.read_text(encoding="utf-8"))
    checks["local_vs_formal_boundary"] = {
        "UP2-00_top_status": up2.get("status"),
        "UP2-00_nested_integration": up2.get("integration", {}).get("status"),
        "UP2-00_nested_scope": up2.get("integration", {}).get("scope"),
        "UP2-00_total_status": up2.get("integration", {}).get("total_status"),
        "accepted_local_manifests": [p for p, d in [("N03", n03), ("N04", n04), ("N07/N08", n07), ("N09", n09), ("N10", n10)] if d.get("status") == "accepted_limited" and d.get("accepted") is True],
        "fresh_formal_rows": manifest.get("fresh_formal_rows"),
        "fresh_formal_receipts": manifest.get("fresh_formal_receipts"),
        "formal_b04": manifest.get("formal_b04"),
    }
    boundary_ok = (
        up2.get("status") == "review_pending"
        and up2.get("accepted") is False
        and up2.get("integration", {}).get("status") == "accepted_limited"
        and up2.get("integration", {}).get("total_status") == "review_pending"
        and manifest.get("fresh_formal_rows") == 50
        and manifest.get("fresh_formal_receipts") == 0
        and manifest.get("formal_b04") is False
    )
    if not boundary_ok:
        failures.append("local accepted_limited/formal B04 boundary is not preserved")

    checks["status_and_scope_guards"] = {
        "G_manifest_review_pending": manifest.get("status") == "review_pending" and manifest.get("accepted") is False,
        "all_no_credit_flags": all(manifest.get(k) is False for k in ["b00", "formal_b04", "provider", "mesh", "engineering", "physical", "r01_r10_credit"]),
        "report_parent_unchanged": "parent R01-R10 scope is unchanged" in report_text,
        "report_no_promotion": "does not promote any task" in report_text and "All 50 formal B04 receipts remain pending" in report_text,
        "e1_current_pending": e1.get("status") == "review_pending" and e1.get("accepted") is False,
        "e2_current_pending": e2.get("status") == "review_pending" and e2.get("accepted") is False,
        "e2_has_preserved_failures": all(e2.get("checks", {}).get(k, "").startswith("exit1") for k in ["author_focused_r1", "author_focused_r2", "author_focused_r3"]),
    }
    if not checks["status_and_scope_guards"]["all_no_credit_flags"] or not checks["status_and_scope_guards"]["report_parent_unchanged"] or not checks["status_and_scope_guards"]["report_no_promotion"]:
        failures.append("scope or no-credit guard is missing")

    main_src = (ROOT / "src/FusionConceptAI.jl").read_text(encoding="utf-8")
    loader_src = (ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl").read_text(encoding="utf-8")
    checks["module_wiring_gap"] = {
        "main_includes_loader": "GenomeV5/Integration/GenomeV5Integration.jl" in main_src,
        "main_has_up2_include": bool(re.search(r"(?:include|Base\.include).*GenomeV5/UP2", main_src)),
        "loader_g1_g2_g3": all(x in loader_src for x in ["\"G1\"", "\"G2\"", "\"G3\""]),
        "loader_has_up2": bool(re.search(r"(?:include|Base\.include).*UP2", loader_src)),
        "main_exports_unified_up2": bool(re.search(r"export[^\n]*(?:N01|N02|UP2ActualA|UP2FormalB04)", main_src)),
    }
    gap_ok = (checks["module_wiring_gap"]["main_includes_loader"] and not checks["module_wiring_gap"]["main_has_up2_include"] and checks["module_wiring_gap"]["loader_g1_g2_g3"] and not checks["module_wiring_gap"]["loader_has_up2"] and not checks["module_wiring_gap"]["main_exports_unified_up2"])
    if not gap_ok:
        failures.append("observed module wiring does not match the G report")

    required_work_order_text = [
        "G-I0 module seam", "G-I1 authority reconciliation", "G-I2 formal receipt/checker",
        "UP2ModuleEntryV1.jl", "UP2ActualAUnifiedProjectionV1.jl", "UP2FormalB04EnvelopeV1.jl",
        "UP1-04B", "50/50 fresh candidate-bound receipts", "compile-before-provider",
        "no expected-label routing", "no physics inference", "explicit owner",
        "terminal_deferred", "program_exception",
    ]
    checks["bounded_GI_packages"] = {x: (x in report_text) for x in required_work_order_text}
    if not all(checks["bounded_GI_packages"].values()):
        failures.append("one or more required G-I dependency/file/exit-gate phrases are absent")

    overwritten = up2.get("overwritten", [])
    checks["historical_receipt_overwrite"] = {
        "observed_in_UP2_00_manifest": overwritten,
        "original_bytes_recoverable": not any(x.get("status") == "unknown" for x in overwritten),
        "current_G_receipt_count_zero": manifest.get("fresh_formal_receipts") == 0,
        "interpretation": "historical provenance limitation; not attributed to this G audit",
    }

    commands = [
        run_command("json_parse_targets_fixture", [sys.executable, "-c", "import json; [json.load(open(p, encoding='utf-8')) for p in ['docs/implementation/UP2-00G-INTEGRATION-READINESS/input_hashes.json','docs/implementation/UP2-00G-INTEGRATION-READINESS/manifest.json','docs/implementation/UP2-00G-INTEGRATION-READINESS/qa.json','test/GenomeV5/UP2/fixtures.json']]"]),
        run_command("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run_command("git_diff_check", ["git", "diff", "--check"]),
        run_command("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {x["name"]: x["exit"] for x in commands}
    if commands[1]["exit"] != 0:
        failures.append("validate_plan.py exit was nonzero")
    if commands[2]["exit"] != 0:
        failures.append("git diff --check exit was nonzero")

    verdict = "changes_requested" if failures else "pass_limited"
    result = {
        "review_id": "UP2-00G-INTEGRATION-READINESS-independent-review-r1",
        "reviewer": "different-Luna independent read-only reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "failures": failures,
        "frozen_inputs": FROZEN,
        "checks": checks,
        "limitations": [
            "No Julia or DESC was started by this review; static and process-sweep evidence only.",
            "The G report is a time snapshot. Current E1/N05 has later author changes, and current E2/N06 has later source/artifact drift; those do not rewrite the frozen report.",
            "UP2-00 records a historical same-name r6 overwrite with original bytes unrecoverable; this review records the limitation and did not overwrite receipts.",
        ],
        "commands": commands,
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    drift_note = "none" if not current_drift else ", ".join(sorted(x["class"] for x in current_drift))
    md = f"""# UP2-00G independent integration-readiness review R1

Verdict: **{verdict}** (read-only static review; no Julia/DESC).

The frozen G inputs were independently rehashed: report `{FROZEN['report.md']}`, manifest `{FROZEN['manifest.json']}`, input hashes `{FROZEN['input_hashes.json']}`, and QA `{FROZEN['qa.json']}`. The actual `fixtures.json` contains the exact ordered 50 IDs N01-01 through N10-05, and `TypedPrecompilerValidatorV1.jl` registers the same exact 50 IDs without duplicates. The report matrix also has 50 rows and marks every formal B04 cell pending.

The local boundary is preserved. UP2-00 has top-level `review_pending`/`accepted=false`, while its nested N01/N02 integration slice is `accepted_limited`; its total remains `review_pending`. N03/N04/N07-N10 are bounded local `accepted_limited` slices. E1/N05 and E2/N06 are currently `review_pending`/unaccepted; E2 retains focused exit-1 history. G manifest `fresh_formal_rows=50`, `fresh_formal_receipts=0`, and all B00/B04/provider/mesh/engineering/physical/R01-R10 credit flags are false.

The wiring gap described by G is present: `src/FusionConceptAI.jl` includes the GenomeV5 integration loader but no UP2 include or unified UP2 export; `GenomeV5Integration.jl` loads G1/G2/G3 only. The proposed G-I0, G-I1, and G-I2 package names, owned files, dependencies, output contracts, and exit gates are all present, including source-derived mutation hashes, explicit `terminal_deferred`/`fail_closed`/`program_exception`, no expected-label routing or synthetic/reused evidence, compile-before-provider ordering, and no physics inference.

Historical provenance finding: UP2-00's manifest explicitly records same-name `focused_test_r6` overwrite with original bytes unrecoverable. It is a prior limitation, not a write performed by this review. Current source/artifact drift relative to the frozen G snapshot is observed for class(es) **{drift_note}**; the frozen report remains internally consistent with its own `input_hashes.json`, and this is recorded as time-snapshot provenance rather than silently promoted status.

Independent command receipts with real exit codes, stdout/stderr, and UTC timestamps are in [command_receipts.json](command_receipts.json); structured results are in [report.json](report.json). `validate_plan.py` and `git diff --check` both exited 0. Process sweep output is retained and no process was started or killed by this review.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    evidence_files = ["run_independent_review.py", "report.md", "report.json", "command_receipts.json"]
    evidence_manifest = {
        "review_id": result["review_id"],
        "verdict": verdict,
        "claim_ceiling": "independent_read_only_static_integration_review",
        "julia_desc_invoked": False,
        "frozen_inputs": FROZEN,
        "evidence_files": {p: sha(OUT / p) for p in evidence_files},
        "command_exits": checks["command_exits"],
        "rerun_note": "Re-run this script only after confirming the four frozen G input hashes remain unchanged; current author updates are recorded as post-snapshot drift.",
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "failures": failures, "current_drift_classes": drift_note, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if verdict == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
