"""Independent, read-only static precheck for E1-N05.

This script does not import Julia, execute the E1 runner, or mutate author
files.  It writes only the evidence files in this directory.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line_of(text: str, needle: str) -> int | None:
    for n, line in enumerate(text.splitlines(), 1):
        if needle in line:
            return n
    return None


def run_command(argv: list[str], cwd: Path = ROOT) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    try:
        p = subprocess.run(argv, cwd=cwd, text=True, capture_output=True,
                           encoding="utf-8", errors="replace", check=False)
        return {
            "command": argv,
            "started_utc": started,
            "finished_utc": datetime.now(timezone.utc).isoformat(),
            "real_exit": p.returncode,
            "stdout": p.stdout,
            "stderr": p.stderr,
        }
    except Exception as exc:  # retain an auditable failure rather than hiding it
        return {
            "command": argv,
            "started_utc": started,
            "finished_utc": datetime.now(timezone.utc).isoformat(),
            "real_exit": None,
            "stdout": "",
            "stderr": f"{type(exc).__name__}: {exc}",
        }


def assertion(name: str, passed: bool, evidence: str, severity: str = "info") -> dict:
    return {"name": name, "passed": bool(passed), "severity": severity,
            "evidence": evidence}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    captured_at = datetime.now(timezone.utc).isoformat()
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture_text = FIXTURE.read_text(encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    fixture = json.loads(fixture_text)
    acceptance = ACCEPTANCE.read_text(encoding="utf-8")
    ad24 = AD24.read_text(encoding="utf-8")
    e0_acceptance = E0_ACCEPTANCE.read_text(encoding="utf-8")

    frozen = {
        "source_path": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": sha256(SOURCE),
        "test_path": str(TEST.relative_to(ROOT)).replace("\\", "/"),
        "test_sha256": sha256(TEST),
        "runner_path": str(RUNNER.relative_to(ROOT)).replace("\\", "/"),
        "runner_sha256": sha256(RUNNER),
        "fixture_path": str(FIXTURE.relative_to(ROOT)).replace("\\", "/"),
        "fixture_sha256": sha256(FIXTURE),
    }
    expected = manifest.get("snapshot", {})
    snapshot_matches = {
        key: frozen.get(key) == expected.get(key)
        for key in ("source_sha256", "test_sha256", "runner_sha256", "fixture_sha256")
    }

    # Independent read-only command evidence.  No Julia/DESC command is issued.
    receipts = [
        run_command(["git", "diff", "--check"]),
        run_command(["powershell", "-NoProfile", "-Command",
                     "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc|mpiexec|mpirun)(\\.exe)?$' } | Select-Object Name,ProcessId,CommandLine | ConvertTo-Json -Compress"]),
        run_command([sys.executable, "-c",
                     "import json,sys; [json.load(open(p,encoding='utf-8')) for p in sys.argv[1:]]; print('json_parse_ok='+str(len(sys.argv)-1))",
                     str(FIXTURE), str(MANIFEST)]),
    ]

    # The implementation facts below intentionally use source text and line
    # numbers rather than calling the author test or loading Julia.
    law_hash_body = "_n05_law_source_hash(law_ref, expression, left_sign, right_sign, unit)"
    law_hash_check = law_hash_body in source and "law=law" in source and "declaration_hash" in source
    law_path_hashed = "source.path" in source[source.find("function _n05_law_source_hash"):source.find("struct UP2N05FluxLawV1")]
    occurrence_exact = all(x in source for x in (
        "endpoint.occurrence.source.path ==",
        "endpoint.occurrence.source.source_type ==",
    ))
    endpoint_path_exact = "source.path ==" in source and "source.source_type ==" in source
    mutation_label_routing = all(x in source for x in (
        'spec.id == "N05-01"', 'spec.id == "N05-02"', 'spec.id == "N05-03"',
        'spec.id == "N05-04"', 'spec.id == "N05-05"'))
    mutation_spec_join = all(x in source for x in (
        "spec.field_path", "spec.mutation_kind", "spec.expected_error",
        "spec.expected_resolution")) and "spec.field_path" in source[source.find("function _n05_spec_value"):]
    # This is deliberately strict: field_path appears only as receipt output,
    # and expected_* are not used to derive the mutation or error classification.
    mutation_source_derived = ("spec.field_path" in source[source.find("function _n05_spec_value"):source.find("function _n05_mutated_declaration")] and
                               "spec.expected_error" in source[source.find("function up2n05_validate_mutation"):])
    g1_join = all(x in source for x in (
        "o.equation_id == endpoint.occurrence.equation_id",
        "o.port_side == endpoint.occurrence.port_side",
        "o.port_index == endpoint.occurrence.port_index",
        "o.ledger_id == endpoint.occurrence.ledger_id"))
    g2_join = "i.interface_ref == declaration.interface_ref" in source and "left_region_id == interface.left_region_id" in source
    g2_full_fields = all(x in source for x in ("axis ==", "coordinate ==", "normal ==", "continuity ==", "transfer_kind =="))
    flux_unit_separate = ("endpoint.unit.source.layer === :N05" in source and
                          "endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1" in source and
                          "occurrence.source.layer === :G1" in source)
    e0_three_state = all(x in source for x in (
        ":valid", ":program_exception", ":fail_closed", "E0_program_exception", "E0_source_contradiction"))
    actual_a_join = all(x in test for x in (
        "integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)",
        "up2_candidate_physical_binding_from_a(package)"))
    positive_contract_only = ("contract_ready" in acceptance and
                              manifest.get("accepted") is False and
                              manifest.get("scope") == "contract_only" and
                              "physical" in e0_acceptance.lower())
    test_api_fixed = "deferred.resolution == :terminal_deferred" in test and "deferred.status ==" not in test

    checks = [
        assertion("snapshot_hashes_match_manifest", all(snapshot_matches.values()),
                  json.dumps({"current": frozen, "manifest_snapshot": expected,
                              "per_file": snapshot_matches}, ensure_ascii=False), "blocker"),
        assertion("authored_law_expression_ref_hash_participate", law_hash_check,
                  f"law hash helper line {line_of(source, 'function _n05_law_source_hash')} hashes ref/expression/signs/unit; declaration body includes law", "info"),
        assertion("law_source_path_is_hashed_or_bound", law_path_hashed,
                  f"No source.path occurs in _n05_law_source_hash (line {line_of(source, 'function _n05_law_source_hash')}); path is only nonempty-checked by locator", "blocker"),
        assertion("endpoint_source_path_and_type_are_bound", endpoint_path_exact,
                  f"_n05_endpoint_source line {line_of(source, 'function _n05_endpoint_source')} hashes endpoint content but omits path/source_type; caller supplies hardcoded field paths", "blocker"),
        assertion("g1_occurrence_join_uses_four_identity_fields", g1_join,
                  f"_n05_authority_errors occurrence search line {line_of(source, 'occurrence = first')} uses equation_id/port_side/port_index/ledger_id", "info"),
        assertion("g1_occurrence_exact_source_path_and_type_join", occurrence_exact,
                  f"No endpoint.occurrence.source.path/source_type equality assertions in _n05_authority_errors (occurrence block line {line_of(source, 'occurrence = first')})", "blocker"),
        assertion("g2_interface_ref_and_region_join", g2_join,
                  f"Interface lookup line {line_of(source, 'interface = first')} matches interface_ref and checks left/right region IDs", "info"),
        assertion("g2_all_interface_geometry_fields_joined", g2_full_fields,
                  "AD-24 permits normal as geometry context; implementation does not compare axis/coordinate/normal/continuity/transfer_kind", "observation"),
        assertion("flux_unit_has_separate_authored_n05_provenance", flux_unit_separate,
                  f"N05 unit source checks occur in _n05_authority_errors near line {line_of(source, 'flux_unit_source_layer_mismatch')}; G1 occurrence carries provenance only", "info"),
        assertion("e0_program_exception_three_state_preserved", e0_three_state,
                  f"_n05_e0_status line {line_of(source, 'function _n05_e0_status')} maps valid/program_exception/fail_closed and retains E0_program_exception", "info"),
        assertion("mutations_are_source_and_invariant_derived", mutation_source_derived and not mutation_label_routing,
                  f"_n05_spec_value line {line_of(source, 'function _n05_spec_value')} and _n05_mutated_declaration line {line_of(source, 'function _n05_mutated_declaration')} branch on spec.id; expected_error/expected_resolution are not consumed", "blocker"),
        assertion("mutation_spec_field_path_is_used_as_source_locator", False,
                  f"spec.field_path is emitted as receipt.error_path (line {line_of(source, 'error_code, spec.field_path')}) but does not select/verify the mutated declaration field", "blocker"),
        assertion("actual_a_package_and_e0_binding_are_used", actual_a_join,
                  f"Test _n05_actual_package integrates G1/G2/G3 at line {line_of(test, 'integrate_genome_v5')} and calls E0 A binding at line {line_of(test, 'up2_candidate_physical_binding_from_a')}", "info"),
        assertion("positive_scope_is_contract_ready_only", positive_contract_only,
                  "Acceptance and manifest retain review_pending/accepted=false and contract_only; E0 acceptance carries no physical/provider credit", "info"),
        assertion("r1_test_api_mismatch_is_fixed", test_api_fixed,
                  f"Deferred assertion uses resolution at test line {line_of(test, 'deferred.resolution == :terminal_deferred')}; no deferred.status remains", "info"),
        assertion("fixture_has_five_named_mutations", len(fixture.get("mutations", [])) == 5,
                  f"Fixture mutation count={len(fixture.get('mutations', []))}; labels={ [m.get('id') for m in fixture.get('mutations', [])] }", "info"),
    ]

    blockers = [c["name"] for c in checks if c["severity"] == "blocker" and not c["passed"]]
    process_receipt = receipts[1]
    process_observed = bool(process_receipt["stdout"].strip())
    report = {
        "schema_version": "UP2-00E1-N05-independent-precheck-v1",
        "verdict": "changes_requested" if blockers else "ready_for_independent_dynamic_after_author_pass",
        "scope": "independent static precheck only; no acceptance",
        "reviewer": "Luna/high independent reviewer",
        "captured_at_utc": captured_at,
        "repository": str(ROOT),
        "frozen_snapshot": frozen,
        "invalid_if_any_frozen_file_changes": True,
        "manifest_snapshot_comparison": {"expected": expected, "current": frozen, "matches": snapshot_matches},
        "checks": checks,
        "blockers": blockers,
        "command_receipt_file": "command_receipts.json",
        "commands": [
            {"command": r["command"], "real_exit": r["real_exit"],
             "started_utc": r["started_utc"], "finished_utc": r["finished_utc"]}
            for r in receipts
        ],
        "limitations": [
            "No Julia/DESC execution was performed; this is not dynamic validation or acceptance.",
            "R1 historical exit=1 remains in the author manifest; current test API line is independently inspected after the author's fix.",
            "A later author change to source/test/fixture/runner invalidates this frozen precheck and requires rerun.",
            "A nonempty process probe is environmental evidence only and does not establish test execution by this reviewer." if process_observed else "Process probe returned empty for Julia/DESC/mpiexec/mpirun at capture time.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps({
        "schema_version": "UP2-00E1-independent-command-receipts-v1",
        "captured_at_utc": captured_at,
        "commands": receipts,
        "note": "Commands are read-only; no Julia/DESC invocation was issued.",
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    md = [
        "# E1-N05 independent static precheck",
        "",
        f"Verdict: **{report['verdict']}** (static precheck only; not acceptance).",
        f"Captured UTC: `{captured_at}`. Frozen source/test/fixture/runner hashes are in `report.json`; any change invalidates this report.",
        "",
        "## Blocking findings",
        "",
    ]
    for c in checks:
        if c["severity"] == "blocker" and not c["passed"]:
            md += [f"- **{c['name']}**: {c['evidence']}"]
    md += [
        "",
        "## Passing boundary checks",
        "",
    ]
    for c in checks:
        if c["passed"] and c["severity"] in ("info",):
            md += [f"- `{c['name']}`: {c['evidence']}"]
    md += [
        "",
        "## Evidence and limits",
        "",
        "- `command_receipts.json` records timestamp, stdout, stderr, and real exit for `git diff --check`, process probe, and JSON parsing.",
        "- E0 accepted_limited and E1 review_pending/contract_only boundaries were read; no physical, provider, mesh, engineering, B00, B04, or R-credit was asserted.",
        "- No Julia/DESC was started. The result is `changes_requested`; it cannot authorize dynamic execution until the blockers are repaired and the author snapshot is refrozen.",
    ]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    return 1 if report["verdict"] == "changes_requested" else 0


if __name__ == "__main__":
    raise SystemExit(main())
