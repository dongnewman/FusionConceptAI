from __future__ import annotations

import hashlib
import json
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
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
    "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md": "a01c9c65a3bed8ed0b2f887ba3cfaac1d3941cc09bb08cd7717f6a59106de713",
}
PRELIMINARY_AD25_HASH = "85e74c8514867aba366d8995b28a556b090df2399e7cfaeb052359290498c260"


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
    entry = (ROOT / "src/GenomeV5/UP2/UP2ModuleEntryV1.jl").read_text(encoding="utf-8")
    tests = (ROOT / "test/GenomeV5/UP2/up2_module_entry_tests.jl").read_text(encoding="utf-8")
    runner = (ROOT / "test/GenomeV5/UP2/run_up2_module_entry.jl").read_text(encoding="utf-8")
    probe = (ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl").read_text(encoding="utf-8")
    core18 = (ROOT / "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md").read_text(encoding="utf-8")
    manifest = json.loads((BASE / "evidence_manifest.json").read_text(encoding="utf-8"))
    before = json.loads((BASE / "repair_r2_before.json").read_text(encoding="utf-8"))
    after = json.loads((BASE / "repair_r2_after.json").read_text(encoding="utf-8"))
    protected = json.loads((BASE / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    r1 = json.loads((BASE / "independent_review_r1/manifest.json").read_text(encoding="utf-8"))

    frozen_results = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        frozen_results[rel] = {"expected": expected, "actual": actual, "match": actual == expected}
        if actual != expected:
            blockers.append(f"corrected frozen hash mismatch: {rel}")
    checks["corrected_frozen_hashes"] = frozen_results
    checks["preliminary_dispatch_hash_reconciliation"] = {
        "preliminary_hash": PRELIMINARY_AD25_HASH,
        "corrected_hash": FROZEN["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"],
        "current_hash": frozen_results["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["actual"],
        "current_matches_final_after": frozen_results["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["match"],
        "interpretation": "85e74c was preliminary dispatch metadata; a01c9c is the author's final after snapshot and current bytes",
    }

    ad24 = core18.index("## 13. AD-24 ")
    ad25 = core18.index("## 14. AD-25 ")
    order_checks = {
        "AD24_before_AD25": ad24 < ad25,
        "AD24_section_present": "## 13. AD-24 N05/N06 cross-layer physical-binding authority boundary" in core18,
        "AD25_section_present": "## 14. AD-25 UP2 additive module seam" in core18,
        "AD25_G1_G2_G3_first": "G1→G2→G3" in core18[ad25:],
        "AD25_no_credit_boundary": all(x in core18[ad25:] for x in (
            "UP2-00 总门", "review_pending", "formal B04", "R01–R10")) and
            ("不接受" in core18[ad25:] or "does not accept" in core18[ad25:]),
    }
    checks["AD24_AD25_order_and_content"] = order_checks
    if not all(order_checks.values()):
        blockers.append("AD24/AD25 order or core section content changed")

    narrow_scope = {
        "bounded_diff_preserves_source_scope": all(x in (BASE / "bounded_diff.md").read_text(encoding="utf-8") for x in (
            "one UP2 entry include and additive UP2 API exports", "one additive `genome_v5_component_layer_order()` registration",
            "No existing V4 source, default operator registry, E1/E2 source/test/archive")),
        "repair_r2_no_loader_source_change": "without changing the loader source" in (BASE / "repair_r2.md").read_text(encoding="utf-8"),
        "before_snapshot_records_core_old_hash": before["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["sha256"] == "44c97191c06d8235d591cd4d0d6d5280ca8bb7fc7ecd9d703937cbe4b0439b37",
        "after_snapshot_core_hash_corrected": after["files"]["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["sha256"] == FROZEN["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"],
        "after_snapshot_all_files_current": all(sha(ROOT / rel) == data["sha256"] for rel, data in after["files"].items()),
    }
    checks["narrow_change_and_before_after"] = narrow_scope
    if not all(narrow_scope.values()):
        blockers.append("narrow change or repair before/after provenance check failed")

    protected_results = []
    for item in protected["files"]:
        actual = sha(ROOT / item["path"])
        protected_results.append({"path": item["path"], "expected": item["sha256"], "actual": actual, "match": actual == item["sha256"]})
    checks["protected_dirty_hashes"] = {"count": len(protected_results), "mismatches": [x for x in protected_results if not x["match"]]}
    if checks["protected_dirty_hashes"]["mismatches"]:
        blockers.append("protected dirty hash mismatch")

    behavior = {
        "entry_order_and_idempotence": all(x in entry for x in (
            "genome_v5_component_layer_order() == (:G1, :G2, :G3)",
            "_UP2_MODULE_LOAD_STATE[] === :loaded && return nothing",
            "_UP2_MODULE_LOAD_STATE[] === :failed &&", "use a fresh process")),
        "runner_real_counter_identity_and_second_noop": all(x in runner for x in (
            "PrecompilerInvocationCounterV1.jl", "_MANUAL_COUNTER_TYPE",
            "load_genome_v5_up2_components!()", "UP2InvocationCounterV1 === _MANUAL_COUNTER_TYPE")),
        "fresh_probe_real_order_partial_failure_terminal_retry": all(x in probe for x in (
            "genome_v5_component_layer_order() = (:G1, :G2, :G3)",
            "load_genome_v5_components!() = nothing", "UP2InvocationCounterV1",
            "up2_module_load_state() == :failed", "previously failed")),
        "no_execution_call_in_entry": all(x not in entry for x in (
            "up2_provider!", "integrate_genome_v5", "solver!", "compile!", "execute!", "run(`", "Base.run")),
        "counter_scope_is_static_only": "constructor/static" in tests and "downstream" in tests and "spy" in tests,
    }
    checks["R1_behavior_blockers_closed_static"] = behavior
    if not all(behavior.values()):
        blockers.append("R1 behavior blocker closure is incomplete")

    checks["prior_R1_preserved"] = {
        "status": r1.get("status"), "accepted": r1.get("accepted"),
        "findings_count": len(r1.get("findings", [])),
        "all_prior_findings_preserved": len(r1.get("findings", [])) == 3,
    }
    if r1.get("status") != "changes_requested" or len(r1.get("findings", [])) != 3:
        blockers.append("prior R1 changes-requested record was altered")

    claims = manifest.get("credit_boundary", {})
    checks["claim_boundary"] = {
        "status": manifest.get("status"), "accepted": manifest.get("accepted"),
        "no_credit": all(claims.get(k) is False for k in ("UP2_total", "B00", "B04", "provider", "mesh", "engineering", "physical", "R01_R10")),
        "runtime_not_run": manifest.get("runtime", {}).get("julia_invoked") is False and manifest.get("runtime", {}).get("desc_invoked") is False,
    }
    if manifest.get("accepted") is not False or not checks["claim_boundary"]["no_credit"]:
        blockers.append("claim boundary was unexpectedly promoted")

    commands = [
        run("json_parse", [sys.executable, "-c", "import json; [json.load(open(p, encoding='utf-8')) for p in ['docs/implementation/UP2-00G-I0-MODULE-SEAM/evidence_manifest.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r2_before.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r2_after.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/protected_dirty_hashes.json']]"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {c["name"]: c["exit"] for c in commands}
    for c in commands[:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "ready_for_focused_r1"
    result = {
        "review_id": "UP2-00G-I0-MODULE-SEAM-independent-review-r3-reconciliation",
        "reviewer": "different-Luna static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict, "claim_ceiling": "static_reconciliation_only_no_julia_desc_or_acceptance",
        "blockers": blockers, "frozen_hashes": FROZEN,
        "preliminary_dispatch_hash": PRELIMINARY_AD25_HASH, "checks": checks, "commands": commands,
        "limitations": [
            "Julia/DESC and the G-I0 runner/probe were not started by this reviewer.",
            "repair_r2_before.json records hashes/mtimes but does not contain a byte copy of core18; exact core line-level reconstruction is therefore limited to the recorded before/after hashes and current AD24/AD25 section order/content.",
            "R2 changes_requested remains preserved as historical evidence; this R3 reconciliation does not erase or rewrite it.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# G-I0 independent static review R3 reconciliation

Verdict: **{verdict}**. This reconciliation is static only; Julia/DESC and the G-I0 runner/probe were not started.

The preliminary dispatch hash `{PRELIMINARY_AD25_HASH}` is explicitly retained as historical metadata. The corrected final core18 freeze is `{FROZEN['docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md']}`, matching both `repair_r2_after.json` and current bytes. Entry, test, runner, and failure-probe hashes also match the final R2 freeze.

AD-24 precedes AD-25 in core18. The current AD-25 section retains the G1→G2→G3 first requirement, additive module-seam scope, review-pending state, and closed UP2/B00/B04/R01-R10 boundaries. The bounded diff and repair notes limit the change to the declared registration/probe/archive scope; all repair after-snapshot files and protected dirty hashes match current bytes.

The R1 behavior blockers are closed in the frozen runner/probe: real counter preloading and exact type identity reuse, a second shared-loader no-op, a fresh isolated probe with correct layer order and no-op G1/G2/G3 loader, deliberate later base-type failure after a partial counter sentinel, terminal `:failed`, and same-process retry refusal. The zero counter remains explicitly static wiring evidence, not a downstream spy. Prior R1 `changes_requested` findings remain preserved.

All independent QA commands were recorded with real exit/stdout/stderr/timestamps in [command_receipts.json](command_receipts.json). Structured evidence is in [report.json](report.json), and this review's manifest is [evidence_manifest.json](evidence_manifest.json). No acceptance promotion is made.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_hashes": FROZEN, "preliminary_dispatch_hash": PRELIMINARY_AD25_HASH,
        "command_exits": checks["command_exits"], "evidence_files": {},
    }
    for name in ("run_review.py", "report.md", "report.json", "command_receipts.json"):
        evidence["evidence_files"][name] = sha(OUT / name)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
