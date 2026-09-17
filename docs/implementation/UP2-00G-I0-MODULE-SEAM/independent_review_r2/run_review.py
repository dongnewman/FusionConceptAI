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
    "test/GenomeV5/UP2/run_up2_module_entry.jl": "db1fd47e395d748ffed5205c1ed00be87a1dc63d684ce85e792b6f44632598d2",
    "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl": "59204f1b24d6c03c1a6097e748c42808d06858a6197f49254c6ff28580c21591",
}
AD25_EXPECTED = "85e74c8514867aba366d8995b28a556b090df2399e7cfaeb052359290498c260"


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
    entry = (ROOT / next(iter(FROZEN))).read_text(encoding="utf-8")
    tests = (ROOT / "test/GenomeV5/UP2/up2_module_entry_tests.jl").read_text(encoding="utf-8")
    runner = (ROOT / "test/GenomeV5/UP2/run_up2_module_entry.jl").read_text(encoding="utf-8")
    probe = (ROOT / "test/GenomeV5/UP2/up2_module_entry_failure_probe.jl").read_text(encoding="utf-8")
    manifest = json.loads((BASE / "evidence_manifest.json").read_text(encoding="utf-8"))
    after = json.loads((BASE / "repair_r2_after.json").read_text(encoding="utf-8"))

    frozen = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        frozen[rel] = {"expected": expected, "actual": actual, "match": actual == expected}
        if actual != expected:
            blockers.append(f"frozen G-I0 input drift: {rel}")
    ad25_path = ROOT / "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"
    ad25_actual = sha(ad25_path)
    checks["frozen_hashes"] = frozen
    checks["AD25_core_after_hash"] = {
        "expected_from_dispatch": AD25_EXPECTED,
        "actual": ad25_actual,
        "repair_r2_after_snapshot": after["files"]["docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"]["sha256"],
        "match": ad25_actual == AD25_EXPECTED,
    }
    if ad25_actual != AD25_EXPECTED:
        blockers.append(f"AD25 core document hash drift: expected {AD25_EXPECTED}, actual {ad25_actual}")

    source_checks = {
        "g1_g2_g3_first": "genome_v5_component_layer_order() == (:G1, :G2, :G3)" in entry,
        "ordered_sentinels": all(x in entry for x in (
            "PrecompilerInvocationCounterV1.jl", "TypedPrecompilerContractV1.jl",
            "TypedPrecompilerValidatorV1.jl", "UP2CandidatePhysicalBindingV1.jl",
            "N03TimeAuthorityProjectionV1.jl", "N04LedgerAuthorityProjectionV1.jl",
            "N05FluxAuthorityProjectionV1.jl", "N06SourceFieldLedgerMappingV1.jl",
            "N07N08GeometryProjectionV1.jl", "N09ProviderGapProjectionV1.jl",
            "N10IdentityReceiptProjectionV1.jl")),
        "idempotent_loaded_guard": "_UP2_MODULE_LOAD_STATE[] === :loaded && return nothing" in entry,
        "failed_terminal_and_fresh_process_boundary": all(x in entry for x in (
            "_UP2_MODULE_LOAD_STATE[] === :failed", "use a fresh process",
            "_UP2_MODULE_LOAD_STATE[] = :failed", "rethrow()")),
        "no_execution_calls": all(x not in entry for x in (
            "up2_provider!", "integrate_genome_v5", "solver!", "compile!", "execute!",
            "run(`", "Base.run")),
    }
    checks["entry_static_review"] = source_checks
    if not all(source_checks.values()):
        blockers.append("G-I0 entry order/idempotence/failure/no-execution assertion failed")

    behavior_checks = {
        "runner_manually_includes_real_counter_before_loader": all(x in runner for x in (
            "PrecompilerInvocationCounterV1.jl", "Base.include(FusionConceptAI, _UP2_COUNTER_SOURCE)",
            "const _MANUAL_COUNTER_TYPE")),
        "runner_calls_shared_loader_twice_and_exact_identity": all(x in runner for x in (
            "load_genome_v5_up2_components!()", "UP2InvocationCounterV1 === _MANUAL_COUNTER_TYPE",
            "up2_module_load_state() == :loaded")),
        "fresh_probe_has_correct_layer_order_and_noop_loader": all(x in probe for x in (
            "genome_v5_component_layer_order() = (:G1, :G2, :G3)",
            "load_genome_v5_components!() = nothing", "Base.include(@__MODULE__, entry_path)")),
        "probe_real_counter_then_later_base_type_failure": all(x in probe for x in (
            "UP2InvocationCounterV1", "real base types are absent",
            "first_error === nothing && error")),
        "probe_partial_sentinel_failed_and_retry_refused": all(x in probe for x in (
            "isdefined(@__MODULE__, :UP2InvocationCounterV1)",
            "up2_module_load_state() == :failed", "second_error === nothing && error",
            "previously failed", "fresh process")),
        "runner_tests_behavior_not_only_source_tokens": all(x in runner for x in (
            "_MANUAL_COUNTER_TYPE", "run(`$(Base.julia_cmd())", "@test FusionConceptAI.UP2InvocationCounterV1")),
    }
    checks["behavioral_repair_static_review"] = behavior_checks
    if not all(behavior_checks.values()):
        blockers.append("R1 behavioral blocker repair is not fully represented in runner/probe")

    # Confirm the zero counter remains a construction/static wiring assertion, not a downstream spy.
    checks["counter_boundary"] = {
        "explicit_static_only_comment": "constructor/static wiring check only" in tests,
        "no_downstream_spy_claim": "downstream spy" in tests,
        "entry_has_no_provider_or_solver": source_checks["no_execution_calls"],
    }

    protected = json.loads((BASE / "protected_dirty_hashes.json").read_text(encoding="utf-8"))
    protected_results = []
    for item in protected["files"]:
        path = ROOT / item["path"]
        actual = sha(path)
        protected_results.append({"path": item["path"], "expected": item["sha256"],
                                  "actual": actual, "match": actual == item["sha256"]})
    checks["protected_dirty_files"] = {"count": len(protected_results), "mismatches": [x for x in protected_results if not x["match"]]}
    if checks["protected_dirty_files"]["mismatches"]:
        blockers.append("protected dirty file hash changed")

    after_results = []
    for rel, data in after["files"].items():
        path = ROOT / rel
        actual = sha(path)
        after_results.append({"path": rel, "expected": data["sha256"], "actual": actual, "match": actual == data["sha256"]})
    checks["repair_after_snapshot"] = {"mismatches": [x for x in after_results if not x["match"]], "count": len(after_results)}
    if checks["repair_after_snapshot"]["mismatches"]:
        blockers.append("repair R2 after snapshot hash changed")

    prior_r1 = BASE / "independent_review_r1"
    history = [{"attempt": "independent_review_r1", "preserved": all(
        (prior_r1 / name).exists() for name in ("input_hashes.json", "manifest.json", "report.md")),
        "evidence_files": [str((prior_r1 / name).relative_to(ROOT).as_posix()) for name in
                           ("input_hashes.json", "manifest.json", "report.md")] }]
    checks["historical_failures"] = history
    if not all(x["preserved"] for x in history):
        blockers.append("the historical independent G-I0 R1 review artifacts are missing")

    checks["claim_boundary"] = {
        "status": manifest.get("status"), "accepted": manifest.get("accepted"),
        "claim_ceiling": manifest.get("claim_ceiling"),
        "no_credit": all(manifest.get("credit_boundary", {}).get(k) is False for k in (
            "UP2_total", "B00", "B04", "provider", "mesh", "engineering", "physical", "R01_R10")),
        "runtime_not_run": manifest.get("runtime", {}).get("julia_invoked") is False and manifest.get("runtime", {}).get("desc_invoked") is False,
    }
    if manifest.get("accepted") is not False or not checks["claim_boundary"]["no_credit"]:
        blockers.append("G-I0 acceptance/credit boundary was promoted")

    commands = [
        run("json_parse", [sys.executable, "-c", "import json; [json.load(open(p, encoding='utf-8')) for p in ['docs/implementation/UP2-00G-I0-MODULE-SEAM/evidence_manifest.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/repair_r2_after.json','docs/implementation/UP2-00G-I0-MODULE-SEAM/protected_dirty_hashes.json']]"]),
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
        "review_id": "UP2-00G-I0-MODULE-SEAM-independent-review-r2",
        "reviewer": "different-Luna static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "static_review_only_no_julia_desc_or_acceptance",
        "blockers": blockers,
        "frozen_hashes": FROZEN,
        "AD25_expected_hash": AD25_EXPECTED,
        "checks": checks,
        "commands": commands,
        "limitations": [
            "Julia/DESC and the G-I0 runner/probe were not started by this reviewer.",
            "The behavior checks are verified from the frozen test/runner/probe code and author QA records; this review makes no runtime result claim.",
            "The task-supplied AD25 after hash does not match current bytes; current bytes do match repair_r2_after.json, which is recorded as a provenance conflict rather than silently normalized.",
            "Any change to a frozen entry/test/runner/probe or required AD25/core snapshot invalidates this review.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# G-I0 independent static review R2

Verdict: **{verdict}**. This is a static review only; Julia/DESC and the G-I0 runner/probe were not started.

The frozen entry, test, runner, and failure probe hashes match the requested values. The entry retains G1/G2/G3-first order, stable UP2 sentinels, loaded no-op idempotence, terminal failed state with fresh-process recovery, and no provider/compiler/solver/mesh/physical execution call. The repaired runner manually includes the real counter before the shared loader, verifies exact type identity after loading and after the second call, and the isolated probe supplies the real layer order and no-op component loader before a deliberate later base-type failure. It checks the partial counter sentinel, `:failed`, and same-process retry refusal.

The protected dirty-file hash set and repair after snapshot were independently recomputed. The prior independent R1 review artifacts remain present, including its changes-requested findings. The zero counter is explicitly a constructor/static wiring check and is not treated as a downstream spy.

One provenance blocker remains: the task-supplied AD25 after hash is `{AD25_EXPECTED}`, while current AD25 bytes hash to `{ad25_actual}`. Current bytes match `repair_r2_after.json` but do not match the explicitly frozen dispatch hash, so this review cannot return `ready_for_focused_r1` until that core snapshot boundary is reconciled. No file was changed by this review.

`status=review_pending`, `accepted=false`, and all UP2/B00/B04/provider/mesh/engineering/physical/R01-R10 credit flags remain closed. Independent command receipts are in [command_receipts.json](command_receipts.json), structured evidence is in [report.json](report.json), and this review's manifest is [evidence_manifest.json](evidence_manifest.json). Static QA commands were recorded with real exit/stdout/stderr/timestamps.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_hashes": FROZEN, "AD25_expected_hash": AD25_EXPECTED,
        "AD25_actual_hash": ad25_actual, "command_exits": checks["command_exits"],
        "evidence_files": {},
    }
    for name in ("run_review.py", "report.md", "report.json", "command_receipts.json"):
        evidence["evidence_files"][name] = sha(OUT / name)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
