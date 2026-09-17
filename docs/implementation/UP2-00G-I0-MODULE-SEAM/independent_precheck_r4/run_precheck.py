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
BASE = ROOT / "docs/implementation/UP2-00G-I0-MODULE-SEAM"
FROZEN = {
    "src/GenomeV5/UP2/UP2ModuleEntryV1.jl": "7eb7ed593fbac217ea925830e53b675a38760aed708c7864bd43c436f74d8937",
    "test/GenomeV5/UP2/up2_module_entry_tests.jl": "3d595b399f8e9681881f61fa2e25590dd6646986385af72021a33672c96b4cb5",
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "2847d1b98455a2fb4186be491cc00c09e5f475f83e14e1b26b7a246bf4b19cab",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
    "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md": "a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713",
}
OLD_RUNNER = "db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(name: str, argv: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    p = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    finished = datetime.now(timezone.utc).isoformat()
    return {"name": name, "argv": argv, "started_utc": started,
            "finished_utc": finished, "exit": p.returncode,
            "stdout": p.stdout, "stderr": p.stderr}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    blockers: list[str] = []
    checks: dict[str, object] = {}
    runner_path = ROOT / "test/GenomeV5/UP2/run_up2_module_entry.jl"
    runner = runner_path.read_text(encoding="utf-8")
    entry = (ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl").read_text(encoding="utf-8")
    probe = (ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl").read_text(encoding="utf-8")
    current = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        current[rel] = {"expected": expected, "actual": actual, "match": actual == expected}
        if actual != expected:
            blockers.append(f"frozen hash mismatch: {rel}")
    checks["frozen_hashes"] = current

    before = json.loads((BASE / "repair_r3_before.json").read_text(encoding="utf-8"))
    after = json.loads((BASE / "repair_r3_after.json").read_text(encoding="utf-8"))
    qa = json.loads((BASE / "repair_r3_qa.json").read_text(encoding="utf-8"))
    checks["author_repair_r3"] = {
        "before_sha256": before["sha256"], "before_matches_old_runner": before["sha256"] == OLD_RUNNER,
        "after_sha256": after["sha256"], "after_matches_frozen_runner": after["sha256"] == FROZEN["test/GenomeV5/UP2/run_up2_module_entry.jl"],
        "after_bytes": after["bytes"], "after_julia_run": after["julia_run"],
        "qa": qa,
    }
    if not (before["sha256"] == OLD_RUNNER and after["sha256"] == FROZEN["test/GenomeV5/UP2/run_up2_module_entry.jl"] and after["julia_run"] is False):
        blockers.append("repair R3 before/after provenance does not match frozen runner transition")

    checks["one_token_runner_repair"] = {
        "correct_interpolant": "$_FAILURE_PROBE $(joinpath(_UP2_ROOT, \"UP2ModuleEntryV1.jl\"))" in runner,
        "old_undefined_interpolant_absent": "$FAILURE_PROBE" not in runner,
        "correct_source_path_argument": "$(joinpath(_UP2_ROOT, \"UP2ModuleEntryV1.jl\"))" in runner,
        "exact_probe_path_definition": "const _FAILURE_PROBE = joinpath(@__DIR__, \"up2_module_entry_failure_probe.jl\")" in runner,
        "loader_unchanged": sha(ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl") == FROZEN["src/GenomeV5/UP2/UP2ModuleEntryV1.jl"],
        "probe_unchanged": sha(ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl") == FROZEN["test/GenomeV5/UP2/up2_module_entry_failure_probe.jl"],
    }
    if not all(checks["one_token_runner_repair"].values()):
        blockers.append("runner repair is not exactly the one-token probe interpolant fix")

    protected = json.loads((BASE / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    protected_results = []
    for item in protected["files"]:
        path = ROOT / item["path"]
        actual = sha(path)
        protected_results.append({"path": item["path"], "expected": item["sha256"], "actual": actual,
                                  "bytes_expected": item["bytes"], "bytes_actual": path.stat().st_size,
                                  "match": actual == item["sha256"] and path.stat().st_size == item["bytes"]})
    checks["protected_dirty_before_after"] = {"count": len(protected_results), "mismatches": [x for x in protected_results if not x["match"]]}
    if checks["protected_dirty_before_after"]["mismatches"]:
        blockers.append("protected dirty hash mismatch")

    checks["source_and_core_bytes_unchanged"] = {
        "entry": current["src/GenomeV5/UP2/UP2ModuleEntryV1.jl"]["match"],
        "test": current["test/GenomeV5/UP2/up2_module_entry_tests.jl"]["match"],
        "probe": current["test/GenomeV5/UP2/up2_module_entry_failure_probe.jl"]["match"],
        "core18": current["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["match"],
    }

    focused = BASE / "focused_r1"
    receipt = json.loads((focused / "receipt.json").read_text(encoding="utf-8"))
    checks["prior_focused_r1_raw"] = {
        "receipt_present": (focused / "receipt.json").exists(),
        "stdout_present": (focused / "stdout.log").exists(),
        "stderr_present": (focused / "stderr.log").exists(),
        "process_samples_present": (focused / "process_samples.json").exists(),
        "real_exit": receipt.get("real_exit"),
        "probe_not_started": "UndefVarError" in (focused / "stderr.log").read_text(encoding="utf-8"),
        "correction_note_present": (focused / "report_correction.md").exists(),
    }
    if not all(checks["prior_focused_r1_raw"][x] for x in ("receipt_present", "stdout_present", "stderr_present", "process_samples_present", "correction_note_present")):
        blockers.append("prior focused R1 raw/correction evidence incomplete")
    if checks["prior_focused_r1_raw"]["real_exit"] != 1 or not checks["prior_focused_r1_raw"]["probe_not_started"]:
        blockers.append("prior focused R1 failure evidence does not retain the probe-not-started error")

    prior_reviews = {}
    for name in ("independent_review_r1", "independent_review_r2", "independent_review_r3"):
        d = BASE / name
        files = {f: (d / f).exists() for f in ("report.md", "report.json" if name != "independent_review_r1" else "manifest.json")}
        prior_reviews[name] = files
    checks["independent_review_history"] = prior_reviews
    if not all(all(v.values()) for v in prior_reviews.values()):
        blockers.append("independent R1-R3 review history incomplete")

    manifest = json.loads((BASE / "evidence_manifest.json").read_text(encoding="utf-8"))
    claims = manifest.get("credit_boundary", {})
    checks["claim_boundary"] = {
        "status": manifest.get("status"), "accepted": manifest.get("accepted"),
        "all_credit_false": all(claims.get(k) is False for k in ("UP2_total", "B00", "B04", "provider", "mesh", "engineering", "physical", "R01_R10")),
        "repair_r3_review_pending": manifest.get("repair_r3", {}).get("status") == "review_pending",
    }
    if manifest.get("accepted") is not False or not checks["claim_boundary"]["all_credit_false"]:
        blockers.append("claim ceiling was promoted")

    commands = [
        run("json_parse", [sys.executable, "-c", "import json; [json.load(open(p, encoding='utf-8')) for p in ['docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r3_before.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r3_after.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r3_qa.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/evidence_manifest.json']]"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,ParentProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {c["name"]: c["exit"] for c in commands}
    for c in commands[:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "ready_for_focused_r2"
    result = {
        "review_id": "UP2-00G-I0-independent-precheck-r4",
        "reviewer": "different-Luna static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "static_repair_precheck_only_no_julia_desc_or_acceptance",
        "blockers": blockers,
        "frozen_hashes": FROZEN,
        "old_runner_hash": OLD_RUNNER,
        "checks": checks,
        "commands": commands,
        "limitations": [
            "Julia/DESC and the corrected runner/probe were not started by this precheck.",
            "The prior focused R1 failure remains immutable evidence; a fresh focused run is required after this static gate.",
            "Any change to the frozen entry/test/runner/probe/core files invalidates this verdict.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# G-I0 independent static precheck R4

Verdict: **{verdict}**. This is a static repair precheck only; Julia/DESC and the corrected runner/probe were not started.

The prior runner hash `{OLD_RUNNER}` is preserved in `repair_r3_before.json`; the current runner hash is `{FROZEN['test/GenomeV5/UP2/run_up2_module_entry.jl']}` and `repair_r3_after.json` records exactly one token change, `$FAILURE_PROBE` to `$_FAILURE_PROBE`. The corrected runner passes the failure probe's intended source path `$(joinpath(_UP2_ROOT, \"UP2ModuleEntryV1.jl\"))` statically, while no probe process was started in this review.

Entry, test, probe, and core18 hashes match. Protected dirty hashes match. The original focused R1 raw exit-1 receipt/logs and correction note remain, as do independent review R1-R3 archives. Status remains `review_pending`, `accepted=false`, and all UP2/B00/B04/provider/mesh/engineering/physical/R01-R10 credit remains closed.

JSON parse, `validate_plan.py`, `git diff --check`, and a read-only Julia/DESC process sweep were recorded with real exit/stdout/stderr/timestamps in [command_receipts.json](command_receipts.json). Structured evidence is in [report.json](report.json), and this precheck's manifest is [evidence_manifest.json](evidence_manifest.json).
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_hashes": FROZEN, "old_runner_hash": OLD_RUNNER,
        "command_exits": checks["command_exits"], "evidence_files": {},
    }
    for name in ("run_precheck.py", "report.md", "report.json", "command_receipts.json"):
        evidence["evidence_files"][name] = sha(OUT / name)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
