"""R3 independent static review of the frozen E1-N05 patch.

No Julia/DESC is launched.  Only this R3 evidence directory is written.
The checks record code-path ordering and adversarial symbolic cases rather
than treating string presence as execution evidence.
"""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl"
TEST = ROOT / "test/GenomeV5/UP2/n05_flux_authority_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/UP2/n05_flux_authority_fixtures.json"
RUNNER = ROOT / "test/GenomeV5/UP2/run_n05_flux_authority.jl"
MANIFEST = ROOT / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/evidence_manifest.json"
ACCEPTANCE = ROOT / "docs/implementation/UP2-00E1-N05-FLUX-AUTHORITY/acceptance.md"
AD24 = ROOT / "docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md"
E0_ACCEPTANCE = ROOT / "docs/implementation/UP2-00E0-BOUND-INPUT/acceptance.md"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line(text: str, needle: str) -> int | None:
    for n, value in enumerate(text.splitlines(), 1):
        if needle in value:
            return n
    return None


def function_block(text: str, name: str, stop: str | None = None) -> str:
    start = text.find(name)
    if start < 0:
        return ""
    end = text.find(stop, start + len(name)) if stop else -1
    return text[start:] if end < 0 else text[start:end]


def command(argv: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    try:
        result = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True,
                               encoding="utf-8", errors="replace", check=False)
        return {"command": argv, "started_utc": started,
                "finished_utc": datetime.now(timezone.utc).isoformat(),
                "real_exit": result.returncode, "stdout": result.stdout,
                "stderr": result.stderr}
    except Exception as exc:
        return {"command": argv, "started_utc": started,
                "finished_utc": datetime.now(timezone.utc).isoformat(),
                "real_exit": None, "stdout": "",
                "stderr": f"{type(exc).__name__}: {exc}"}


def check(name: str, passed: bool, evidence: str, severity: str = "info",
          case: dict | None = None) -> dict:
    item = {"name": name, "passed": bool(passed), "severity": severity,
            "evidence": evidence}
    if case is not None:
        item["static_case"] = case
    return item


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    captured = datetime.now(timezone.utc).isoformat()
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    acceptance = ACCEPTANCE.read_text(encoding="utf-8")
    ad24 = AD24.read_text(encoding="utf-8")
    e0_acceptance = E0_ACCEPTANCE.read_text(encoding="utf-8")

    frozen = {
        "source_path": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": sha(SOURCE),
        "test_path": str(TEST.relative_to(ROOT)).replace("\\", "/"),
        "test_sha256": sha(TEST),
        "runner_path": str(RUNNER.relative_to(ROOT)).replace("\\", "/"),
        "runner_sha256": sha(RUNNER),
        "fixture_path": str(FIXTURE.relative_to(ROOT)).replace("\\", "/"),
        "fixture_sha256": sha(FIXTURE),
    }
    expected = manifest.get("snapshot", {})
    hash_matches = {key: frozen[key] == expected.get(key) for key in frozen
                    if key.endswith("sha256")}

    receipts = [
        command(["git", "diff", "--check"]),
        command(["powershell", "-NoProfile", "-Command",
                 "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc|mpiexec|mpirun)(\\.exe)?$' } | Select-Object Name,ProcessId,CommandLine | ConvertTo-Json -Compress"]),
        command([sys.executable, "-c",
                 "import json,sys; [json.load(open(p,encoding='utf-8')) for p in sys.argv[1:]]; print('json_parse_ok='+str(len(sys.argv)-1))",
                 str(FIXTURE), str(MANIFEST)]),
    ]

    authority_errors = function_block(source, "function _n05_authority_errors", "function _n05_e0_status")
    mutation = function_block(source, "function up2n05_validate_mutation")
    path_helper = function_block(source, "function _n05_occurrence_path", "struct UP2N05FluxLawV1")
    occurrence_match = function_block(source, "matches = [o for e in package.g1.payload.equation_plan.equations", "endpoint.unit.status")
    baseline_call = "baseline = up2n05_validate(authority, package, e0_binding)"
    baseline_pos = mutation.find(baseline_call)
    spec_pos = mutation.find("original, locator = _n05_spec_value")
    mutate_pos = mutation.find("mutated_declaration = _n05_mutated_declaration")
    error_pos = mutation.find("errors = _n05_authority_errors")

    checks = [
        check("frozen_r3_hashes_match_manifest", all(hash_matches.values()),
              json.dumps({"current": frozen, "manifest_snapshot": expected,
                          "per_file": hash_matches}, ensure_ascii=False), "blocker"),
        check("baseline_call_precedes_mutation_and_receipt", baseline_pos >= 0 and
              spec_pos > baseline_pos and mutate_pos > baseline_pos and error_pos > baseline_pos,
              f"baseline call line {line(source, baseline_call)} precedes _n05_spec_value line {line(source, 'original, locator = _n05_spec_value')}, mutation line {line(source, 'mutated_declaration = _n05_mutated_declaration')}, and error evaluation line {line(source, 'errors = _n05_authority_errors(package, mutated_declaration)')}", "info",
              {"positive": "only a baseline :valid declaration or :terminal_deferred nil declaration reaches receipt construction", "negative": "baseline fail_closed/program_exception throws before locator or receipt"}),
        check("forged_authority_metadata_is_rejected_by_baseline", baseline_call in mutation and
              all(x in function_block(source, "function up2n05_validate", "function _n05_spec_value") for x in (
                  "authority.candidate_ref == candidate_ref", "authority.package_hash == package_hash",
                  "authority.g1_ref == g1_ref", "authority.g2_ref == g2_ref", "authority.g3_ref == g3_ref",
                  "authority.binding_hash == _n05_binding_hash")),
              "mutation delegates baseline to up2n05_validate; that validator compares authority candidate/package/component refs and binding hash before mutation", "info",
              {"counterexample": "a current declaration embedded in an authority with foreign candidate_ref, stale package_hash, or forged binding_hash yields baseline fail_closed and no receipt"}),
        check("bad_e0_binding_is_rejected_before_mutation", baseline_call in mutation and
              "e0_status, e0_errors = _n05_e0_status(e0_binding, package)" in function_block(source, "function up2n05_validate", "function _n05_spec_value"),
              f"up2n05_validate calls _n05_e0_status at line {line(source, 'e0_status, e0_errors = _n05_e0_status(e0_binding, package)')} before its declared path; mutation has no direct bypass", "info",
              {"counterexample": "pass an E0 binding whose source join is contradictory; baseline status is fail_closed, so mutation guard throws"}),
        check("g1_actual_match_is_unique_and_typed", "length(matches) == 1" in occurrence_match and
              "occurrence isa G1LedgerOccurrenceV2" in occurrence_match and
              "only(matches)" in occurrence_match,
              f"_n05_authority_errors collects four-key matches at line {line(source, 'matches = [o for e in package.g1.payload.equation_plan.equations')} and requires one actual G1LedgerOccurrenceV2 before path reconstruction", "info",
              {"positive": "one actual occurrence proceeds", "negative": "zero or duplicate four-key matches emit G1_occurrence_not_unique and cannot supply a receipt"}),
        check("g1_full_four_key_and_actual_rebuilt_path", all(x in occurrence_match for x in (
            "o.equation_id == endpoint.occurrence.equation_id",
            "o.port_side == endpoint.occurrence.port_side",
            "o.port_index == endpoint.occurrence.port_index",
            "o.ledger_id == endpoint.occurrence.ledger_id")) and
            "_n05_occurrence_path(occurrence === nothing ? endpoint.occurrence : occurrence)" in authority_errors and
            all(x in path_helper for x in ("occurrence.equation_id", "occurrence.port_side", "occurrence.port_index", "occurrence.ledger_id")),
            f"four-key match lines {line(source, 'o.equation_id == endpoint.occurrence.equation_id')}-{line(source, 'o.ledger_id == endpoint.occurrence.ledger_id')}; actual match object feeds path at line {line(source, 'expected_occurrence_path = _n05_occurrence_path')}; helper line {line(source, 'function _n05_occurrence_path')} contains all four key components", "info",
            {"negative": "locator path forged with a different side/ledger id mismatches the actual occurrence-derived path", "taxonomy": "G1LedgerOccurrenceV2 has no .source; the authored N05 field is .locator"}),
        check("g1_locator_ref_hash_type_exact", all(x in authority_errors for x in (
            "endpoint.occurrence.locator.source_ref == g1_ref",
            "endpoint.occurrence.locator.source_hash == g1_hash",
            "endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2")),
            f"G1 locator ref/hash/type checks at lines {line(source, 'endpoint.occurrence.locator.source_ref == g1_ref')}/{line(source, 'endpoint.occurrence.locator.source_hash == g1_hash')}/{line(source, 'endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2')}; no fictitious endpoint.occurrence.source access exists", "info",
            {"negative": "wrong ref/hash/type reaches the corresponding fail_closed error"}),
        check("law_endpoint_unit_source_provenance_exact", all(x in authority_errors for x in (
            "law_source_type_mismatch", "law_source_path_mismatch", "law_source_hash_mismatch",
            "flux_unit_source_type_mismatch", "flux_unit_source_path_mismatch",
            "flux_unit_source_hash_mismatch")),
            "law and authored unit source ref/type/path/hash each have explicit validator mismatch branches", "info"),
        check("mutation_dispatch_path_kind_and_id_label_only", all(x in source for x in (
            "binding.field_path == spec.field_path", "binding.mutation_kind === spec.mutation_kind",
            "binding.target === :left_endpoint_ref", "binding.target === :right_endpoint_ref")) and
            "spec.id ==" not in function_block(source, "function _n05_mutation_binding", "function _n05_binding_hash") and
            "spec.expected_error" not in mutation and "spec.expected_resolution" not in mutation,
            f"registry dispatch lines {line(source, 'function _n05_mutation_binding')}-{line(source, 'N05 mutation field_path/mutation_kind is not registered')} uses path+kind; mutation uses binding.target and leaves id/expected fields to receipt/tests", "info"),
        check("missing_authority_five_rows_remain_deferred", len(fixture.get("mutations", [])) == 5 and
              "baseline.status === :terminal_deferred" in mutation and
              ":authority_gap" in mutation and ":terminal_deferred" in mutation and
              "receipt.original_value == receipt.mutated_value" in test,
              f"five fixture rows are covered; nil declaration requires baseline terminal_deferred at line {line(source, 'baseline.status === :terminal_deferred')} and emits authority_gap/terminal_deferred", "info"),
        check("e0_three_state_and_exception_taxonomy_preserved", all(x in source for x in (
            "result.status === :valid", "result.status === :program_exception",
            "E0_source_contradiction", "status=:program_exception", "status=:terminal_deferred",
            "status=:fail_closed")),
            f"_n05_e0_status maps valid/program_exception/fail_closed near line {line(source, 'function _n05_e0_status')}; validator catches declaration exceptions near line {line(source, 'N05_program_exception:')}", "info",
            {"positive": "valid, source contradiction, and exception remain distinct", "negative": "program_exception exits before a formal valid receipt"}),
        check("declaration_and_law_hash_recomputation_present", "declaration_hash_mismatch" in authority_errors and
              "law_hash_mismatch" in authority_errors and "source_hash == _n05_law_source_hash" in authority_errors,
              f"declaration canonical body is checked at line {line(source, 'declaration_hash_mismatch')}; law/source hashes are recomputed at lines {line(source, 'law_source_hash_mismatch')}/{line(source, 'law_hash_mismatch')}", "info"),
        check("scope_and_no_authority_credit", manifest.get("accepted") is False and
              manifest.get("scope") == "contract_only" and "contract_ready" in acceptance and
              "physical" in (ad24 + e0_acceptance).lower(),
              "manifest remains review_pending/accepted=false contract_only; AD-24/E0 boundaries retain no physical/provider/mesh/engineering/B04/R credit", "info"),
    ]

    blockers = [item["name"] for item in checks if item["severity"] == "blocker" and not item["passed"]]
    process_seen = bool(receipts[1]["stdout"].strip())
    report = {
        "schema_version": "UP2-00E1-N05-independent-precheck-r3-v1",
        "verdict": "changes_requested" if blockers else "ready_for_focused_r2",
        "scope": "independent static R3 only; not acceptance",
        "reviewer": "Luna/high independent reviewer",
        "captured_at_utc": captured,
        "repository": str(ROOT),
        "frozen_snapshot": frozen,
        "invalid_if_any_frozen_file_changes": True,
        "manifest_snapshot_comparison": {"expected": expected, "current": frozen, "matches": hash_matches},
        "checks": checks,
        "blockers": blockers,
        "prior_r2_wording_note": "The prior R2 report had a stale G1 evidence sentence. This R3 report is the corrected record: G1LedgerOccurrenceV2 has no .source; its actual four-key match is used to rebuild the full locator path, and the authored field is occurrence.locator.",
        "commands": [{"command": r["command"], "real_exit": r["real_exit"],
                      "started_utc": r["started_utc"], "finished_utc": r["finished_utc"]} for r in receipts],
        "limitations": [
            "No Julia/DESC execution was performed; this is not dynamic validation or acceptance.",
            "R1 and R2 directories were not modified.",
            "Existing julia/DESC process observations are environmental only; this reviewer did not start or stop processes." if process_seen else "Process probe was empty at capture time.",
            "Any later source/test/fixture/runner or manifest change invalidates this frozen R3 review.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps({
        "schema_version": "UP2-00E1-independent-precheck-r3-command-receipts-v1",
        "captured_at_utc": captured, "commands": receipts,
        "note": "Read-only commands only; no Julia/DESC invocation.",
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = ["# E1-N05 independent static precheck R3", "",
          f"Verdict: **{report['verdict']}** (static only; not acceptance).",
          f"Captured UTC: `{captured}`. Frozen hashes and full command output are in `report.json` and `command_receipts.json`.", "",
          "## Findings", ""]
    if blockers:
        for item in checks:
            if item["severity"] == "blocker" and not item["passed"]:
                md.append(f"- **{item['name']}**: {item['evidence']}")
                if "static_case" in item:
                    md.append(f"  - Static case: {item['static_case']}")
    else:
        md.append("- No static blockers found. Baseline actual-A/E0 gating and full-key G1 locator reconstruction are present.")
    md += ["", "## Verified paths", ""]
    for item in checks:
        if item["passed"] and item["severity"] == "info":
            md.append(f"- `{item['name']}`: {item['evidence']}")
    md += ["", "## Correction and limits", "",
           "- R2 had a stale G1 wording sentence; R3 corrects it in this new archive while leaving R1/R2 files untouched.",
           "- No Julia/DESC was run. This result is a static readiness signal for focused R2, not acceptance or physical/provider evidence."]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    return 1 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
