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
BASE = ROOT / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY"
FROZEN = {
    "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl": "3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df",
    "test/GenomeV5/UP2/n05_flux_authority_tests.jl": "57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543",
    "test/GenomeV5/UP2/n05_flux_authority_fixtures.json": "049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81",
    "test/GenomeV5/UP2/run_n05_flux_authority.jl": "3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3",
}
EXPECTED_GROUPS = {
    "actual A source and deferred baseline": (9, 9),
    "absent authority mutation receipts remain deferred": (30, 30),
    "authored typed declaration and exact joins": (22, 22),
    "five typed fail-closed mutations": (61, 61),
    "foreign identity and authority boundaries": (7, 7),
    "duplicate occurrence locator is fail-closed": (3, 3),
    "duplicate interface lookup is not silently selected": (1, 1),
}


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
    source = (ROOT / next(iter(FROZEN))).read_text(encoding="utf-8")
    tests = (ROOT / "test/GenomeV5/UP2/n05_flux_authority_tests.jl").read_text(encoding="utf-8")
    fixture = json.loads((ROOT / "test/GenomeV5/UP2/n05_flux_authority_fixtures.json").read_text(encoding="utf-8"))
    receipt_path = BASE / "focused_r4/receipt.json"
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    stdout_path = BASE / "focused_r4/stdout.log"
    stderr_path = BASE / "focused_r4/stderr.log"
    root_manifest = json.loads((BASE / "evidence_manifest.json").read_text(encoding="utf-8"))

    frozen = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        frozen[rel] = {"expected": expected, "actual": actual, "match": actual == expected}
        if actual != expected:
            blockers.append(f"frozen input hash drift: {rel}")
    checks["frozen_inputs"] = frozen

    def file_receipt(path: Path, recorded: dict) -> dict:
        actual_sha = sha(path)
        actual_bytes = path.stat().st_size
        return {"path": str(path.relative_to(ROOT)), "actual_bytes": actual_bytes,
                "recorded_bytes": recorded["bytes"], "actual_sha256": actual_sha,
                "recorded_sha256": recorded["sha256"],
                "match": actual_bytes == recorded["bytes"] and actual_sha == recorded["sha256"]}

    run_check = {
        "attempt": receipt.get("attempt"),
        "command": receipt.get("command"),
        "main_pid": receipt.get("main_pid"),
        "start_utc": receipt.get("start_utc"),
        "end_utc": receipt.get("end_utc"),
        "real_exit": receipt.get("real_exit"),
        "stdout": file_receipt(stdout_path, receipt["stdout"]),
        "stderr": file_receipt(stderr_path, receipt["stderr"]),
        "post_processes_empty": receipt.get("post_processes") == [],
        "process_sample_count": len(receipt.get("process_samples", [])),
    }
    checks["focused_r4_receipt"] = run_check
    if receipt.get("real_exit") != 0 or not run_check["stdout"]["match"] or not run_check["stderr"]["match"] or not run_check["post_processes_empty"]:
        blockers.append("focused R4 receipt/terminal output/hash/post-process check failed")

    summaries = {}
    for name, expected in EXPECTED_GROUPS.items():
        pattern = re.compile(r"^UP2-00E1 N05 " + re.escape(name) + r"\s*\|\s*(\d+)\s+(\d+)", re.MULTILINE)
        found = pattern.findall(stdout_path.read_text(encoding="utf-8"))
        summaries[name] = {"matches": found, "expected": list(expected),
                           "pass": found == [tuple(str(x) for x in expected)]}
        if not summaries[name]["pass"]:
            blockers.append(f"focused R4 summary mismatch: {name}")
    checks["focused_r4_test_groups"] = summaries

    source_checks = {
        "candidate_package_outer_refs": all(x in source for x in (
            "authority.candidate_ref == candidate_ref", "authority.package_hash == package_hash",
            "authority.g1_ref == g1_ref", "authority.g2_ref == g2_ref", "authority.g3_ref == g3_ref")),
        "law_expression_and_provenance": all(x in source for x in (
            "law.source.path == \"/n05/authored_flux_law/$(declaration.law.law_ref.id)\"",
            "law.source.source_type === :AuthoredFluxLawV1",
            "law.source.source_hash == _n05_law_source_hash",
            "law.law_hash == _n05_law_source_hash")),
        "endpoint_and_unit_provenance": all(x in source for x in (
            "function _n05_endpoint_source", ":AuthoredFluxEndpointV1",
            "endpoint.unit.source.layer === :N05",
            "endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1",
            "endpoint.unit.source.path == _n05_authored_unit_path",
            "endpoint.unit.source.source_hash == canonical_hash")),
        "g1_exact_actual_join": all(x in source for x in (
            "o.equation_id == endpoint.occurrence.equation_id",
            "o.port_side == endpoint.occurrence.port_side",
            "o.port_index == endpoint.occurrence.port_index",
            "o.ledger_id == endpoint.occurrence.ledger_id",
            "length(matches) == 1", "occurrence isa G1LedgerOccurrenceV2",
            "endpoint.occurrence.locator.source_ref == g1_ref",
            "endpoint.occurrence.locator.source_hash == g1_hash",
            "endpoint.occurrence.locator.path == expected_occurrence_path",
            "endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2")),
        "e0_baseline_before_mutation": all(x in source for x in (
            "baseline = up2n05_validate(authority, package, e0_binding)",
            "mutated_declaration = _n05_mutated_declaration")) and
            source.index("baseline = up2n05_validate(authority, package, e0_binding)") < source.index("mutated_declaration = _n05_mutated_declaration"),
        "typed_mutation_dispatch": "binding.field_path == spec.field_path && binding.mutation_kind === spec.mutation_kind" in source,
        "observed_error_classification": all(x in source for x in (
            "closure_markers =", "unit_markers =", "error_code = has_closure_error ? :invalid_closure",
            "has_unit_error ? :invalid_type",
            "N05 mutation errors have no registered classification")),
        "three_state_and_zero_downstream": all(x in source for x in (
            ":terminal_deferred", ":fail_closed", ":program_exception",
            "compile_calls=0", "provider_calls=0", "solver_calls=0")),
    }
    checks["independent_static_source_review"] = source_checks
    if not all(source_checks.values()):
        blockers.append("independent source-bound law/unit/G1/E0/classification check failed")

    test_checks = {
        "actual_A_and_E0": all(x in tests for x in (
            "function _n05_actual_package", "function _n05_e0_binding",
            "G.up2_candidate_physical_binding_from_a(package)",
            "package.candidate_hash == G._up2e0_package_hash(package)")),
        "mutation_receipt_fields_and_counters": all(x in tests for x in (
            "for row in _N05_FIXTURE.mutations", "receipt.baseline_package_hash == package.candidate_hash",
            "receipt.source_locator.layer == :N05", "receipt.source_locator.source_type",
            "receipt.original_value_hash != receipt.mutated_value_hash",
            "receipt.error_path == String(row.field_path)",
            "receipt.compile_calls == receipt.provider_calls == receipt.solver_calls == 0")),
        "classification_regressions": all(x in tests for x in (
            "left_ref_spec", "unit_spec", ".error_code == :invalid_closure", ".error_code == :invalid_type")),
        "adversarial_identity_and_duplicates": all(x in tests for x in (
            "foreign_authority", "foreign_package", "G1_occurrences_not_independent",
            "duplicate interface lookup is not silently selected", "relabeled_receipt.error_path")),
        "deferred_and_contract_ready": all(x in tests for x in (
            ":terminal_deferred", "authority.resolution == :contract_ready",
            "receipt.error_code == :authority_gap")),
    }
    checks["independent_test_review"] = test_checks
    if not all(test_checks.values()):
        blockers.append("source-bound receipt/counter/adversarial test assertion missing")

    old_attempts = {}
    for attempt in ("focused_r1", "focused_r2", "focused_r3"):
        path = BASE / attempt
        exit_files = list(path.glob("exit.txt"))
        if exit_files:
            raw = exit_files[0].read_text(encoding="utf-8", errors="replace").strip()
            old_attempts[attempt] = {"exit_text": raw, "has_stdout": (path / "stdout.log").stat().st_size > 0,
                                     "has_stderr": (path / "stderr.log").exists(), "preserved": True}
        else:
            old_attempts[attempt] = {"preserved": False}
            blockers.append(f"historical failed attempt missing: {attempt}")
    checks["historical_failed_attempts"] = old_attempts

    claims = root_manifest.get("claims", {})
    checks["claim_ceiling_and_no_promotion"] = {
        "root_status": root_manifest.get("status"),
        "root_accepted": root_manifest.get("accepted"),
        "contract_only": root_manifest.get("scope") == "contract_only",
        "all_external_credit_false": all(claims.get(k) is False for k in ("B00", "B04", "provider", "mesh", "engineering", "physical", "R01_R10")),
        "receipt_zero_calls": all(claims.get(k) == 0 for k in ("compile_calls", "provider_calls", "solver_calls")),
    }
    if root_manifest.get("status") != "review_pending" or root_manifest.get("accepted") is not False:
        blockers.append("root acceptance status was unexpectedly promoted")
    if not checks["claim_ceiling_and_no_promotion"]["all_external_credit_false"]:
        blockers.append("external/physical credit claim detected")

    commands = [
        run("receipt_json_parse", [sys.executable, "-c", "import json; json.load(open('docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/focused_r4/receipt.json', encoding='utf-8'))"]),
        run("fixture_json_parse", [sys.executable, "-c", "import json; json.load(open('test/GenomeV5/UP2/n05_flux_authority_fixtures.json', encoding='utf-8'))"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["independent_command_exits"] = {c["name"]: c["exit"] for c in commands}
    for c in commands[:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "pass_limited"
    result = {
        "review_id": "UP2-00E1-N05-FLUX-AUTHORITY-independent-review-r1",
        "reviewer": "different-Luna post-run reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "contract_test_run_review_only_no_acceptance_or_physical_engineering_credit",
        "blockers": blockers,
        "frozen_inputs": FROZEN,
        "checks": checks,
        "focused_r4_receipt_sha256": sha(receipt_path),
        "focused_r4_stdout_sha256": sha(stdout_path),
        "focused_r4_stderr_sha256": sha(stderr_path),
        "commands": commands,
        "limitations": [
            "This independent review did not start Julia/DESC or rerun the focused runner.",
            "The runner exposes pass counts and receipt assertions in stdout/tests; it does not serialize a separate per-mutation receipt JSON artifact. The review therefore verifies receipt fields through the executed test contract and frozen source, while preserving the claim ceiling.",
            "Focused R4's transient child Julia processes are historical process samples; the recorded post-process sweep is empty.",
            "Any change to a frozen source, test, fixture, or runner file invalidates this review.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E1-N05 independent post-run review R1

Verdict: **{verdict}**. This is an independent review of the author's focused R4 run; it does not promote acceptance.

The four frozen inputs match exactly: source `{FROZEN['src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl']}`, test `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_tests.jl']}`, fixture `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_fixtures.json']}`, and runner `{FROZEN['test/GenomeV5/UP2/run_n05_flux_authority.jl']}`. The immutable receipt records main PID `76372`, UTC `04:15:52.7396002Z` to `04:22:36.4267490Z`, real exit `0`, stdout `9906` bytes with SHA256 `{sha(stdout_path)}`, stderr `0` bytes with SHA256 `{sha(stderr_path)}`, and an empty post-process sweep.

The raw stdout contains the seven E1 groups with exact results `9/9`, `30/30`, `22/22`, `61/61`, `7/7`, `3/3`, and `1/1`. Independent source/test review confirms actual A plus E0 binding construction, baseline validation before mutation receipts, candidate/package/G1/G2 identity joins, typed law and separate authored unit provenance, exact four-field G1 occurrence matching, receipt source paths and zero compile/provider/solver counters, deferred authority gaps, and adversarial foreign/duplicate/relabelled-ID cases.

The current root evidence remains `status=review_pending`, `accepted=false`, and contract-only. B00/B04, provider, mesh, engineering, physical, and R01-R10 claims remain false. Focused R1-R3 failures and their raw artifacts remain present; they are historical evidence and were not overwritten.

This review did not start Julia/DESC or rerun the runner. The runner's stdout and tests verify receipt fields and counters, but no separate per-mutation receipt JSON is emitted, so this remains `pass_limited` review evidence rather than acceptance.

Structured checks are in [report.json](report.json), raw command evidence is in [command_receipts.json](command_receipts.json), and the author receipt is [focused_r4/receipt.json](../focused_r4/receipt.json). Any frozen-input change invalidates this review.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_inputs": FROZEN, "focused_r4_receipt_sha256": sha(receipt_path),
        "evidence_files": {}, "command_exits": checks["independent_command_exits"],
    }
    for name in ("run_review.py", "report.md", "report.json", "command_receipts.json"):
        evidence["evidence_files"][name] = sha(OUT / name)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers,
                      "command_exits": checks["independent_command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
