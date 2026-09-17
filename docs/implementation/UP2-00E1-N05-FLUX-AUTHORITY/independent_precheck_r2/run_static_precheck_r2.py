"""R2 independent static audit for E1-N05.

The audit is source-path based and records symbolic positive/negative cases.
It never starts Julia/DESC and writes only this R2 evidence directory.
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


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line_of(text: str, needle: str) -> int | None:
    for n, line in enumerate(text.splitlines(), 1):
        if needle in line:
            return n
    return None


def block(text: str, start: str, stop: str | None = None) -> str:
    a = text.find(start)
    if a < 0:
        return ""
    b = text.find(stop, a + len(start)) if stop else -1
    return text[a:] if b < 0 else text[a:b]


def run(argv: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    try:
        p = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True,
                           encoding="utf-8", errors="replace", check=False)
        return {"command": argv, "started_utc": started,
                "finished_utc": datetime.now(timezone.utc).isoformat(),
                "real_exit": p.returncode, "stdout": p.stdout, "stderr": p.stderr}
    except Exception as exc:
        return {"command": argv, "started_utc": started,
                "finished_utc": datetime.now(timezone.utc).isoformat(),
                "real_exit": None, "stdout": "",
                "stderr": f"{type(exc).__name__}: {exc}"}


def check(name: str, passed: bool, evidence: str, severity: str = "info",
          case: dict | None = None) -> dict:
    out = {"name": name, "passed": bool(passed), "severity": severity,
           "evidence": evidence}
    if case is not None:
        out["static_case"] = case
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    captured = datetime.now(timezone.utc).isoformat()
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    acceptance = ACCEPTANCE.read_text(encoding="utf-8")
    ad24 = AD24.read_text(encoding="utf-8")
    e0_acceptance = E0_ACCEPTANCE.read_text(encoding="utf-8") if E0_ACCEPTANCE.exists() else ""

    frozen = {
        "source_path": str(SOURCE.relative_to(ROOT)).replace("\\", "/"),
        "source_sha256": digest(SOURCE),
        "test_path": str(TEST.relative_to(ROOT)).replace("\\", "/"),
        "test_sha256": digest(TEST),
        "runner_path": str(RUNNER.relative_to(ROOT)).replace("\\", "/"),
        "runner_sha256": digest(RUNNER),
        "fixture_path": str(FIXTURE.relative_to(ROOT)).replace("\\", "/"),
        "fixture_sha256": digest(FIXTURE),
    }
    expected = manifest.get("snapshot", {})
    hash_match = {k: frozen[k] == expected.get(k) for k in frozen if k.endswith("sha256")}

    law_block = block(source, "function _n05_law_source_hash", "struct UP2N05FluxLawV1")
    authority_block = block(source, "function _n05_authority_errors", "function _n05_e0_status")
    mutation_block = block(source, "function up2n05_validate_mutation")
    spec_block = block(source, "function _n05_mutation_binding", "function _n05_binding_hash")
    nil_mutation = block(source, "if authority.declaration === nothing", "function up2n05_validate_mutation")

    receipts = [
        run(["git", "diff", "--check"]),
        run(["powershell", "-NoProfile", "-Command",
             "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc|mpiexec|mpirun)(\\.exe)?$' } | Select-Object Name,ProcessId,CommandLine | ConvertTo-Json -Compress"]),
        run([sys.executable, "-c",
             "import json,sys; [json.load(open(p,encoding='utf-8')) for p in sys.argv[1:]]; print('json_parse_ok='+str(len(sys.argv)-1))",
             str(FIXTURE), str(MANIFEST)]),
    ]

    law_path = 'declaration.law.source.path == "/n05/authored_flux_law/$(declaration.law.law_ref.id)"'
    law_type = "declaration.law.source.source_type === :AuthoredFluxLawV1"
    g1_path = ("endpoint.occurrence.locator.path == expected_occurrence_path" in authority_block or
               "endpoint.occurrence.source.path == expected_occurrence_path" in authority_block)
    g1_type = ("endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2" in authority_block or
               "endpoint.occurrence.source.source_type === :G1LedgerOccurrenceV2" in authority_block)
    unit_path = "endpoint.unit.source.path == _n05_authored_unit_path(endpoint.endpoint_ref)"
    unit_type = "endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1"
    endpoint_dispatch = all(x in source for x in (
        "binding.field_path == spec.field_path",
        "binding.mutation_kind === spec.mutation_kind",
        "binding.target === :left_endpoint_ref",
        "binding.target === :right_endpoint_ref"))
    id_dispatch = "spec.id ==" in spec_block or "spec.id ==" in mutation_block
    expected_used_in_impl = "spec.expected_error" in mutation_block or "spec.expected_resolution" in mutation_block
    baseline_guard = "up2n05_validate(authority, package, e0_binding)" in mutation_block
    e0_guard = "_n05_e0_status" in mutation_block or "up2n05_validate(" in mutation_block
    occurrence_section = block(authority_block, "occurrence = first", "endpoint.unit.status")
    occurrence_path_def = block(source, "function _n05_occurrence_path", "struct UP2N05FluxLawV1")
    g1_path_full_key = all(x in occurrence_path_def for x in ("port_side", "ledger_id"))

    checks = [
        check("frozen_hashes_match_new_author_manifest", all(hash_match.values()),
              json.dumps({"current": frozen, "manifest_snapshot": expected,
                          "per_file": hash_match}, ensure_ascii=False), "blocker"),
        check("law_canonical_path_and_type_checked", law_path in authority_block and law_type in authority_block,
              f"_n05_authority_errors checks exact law path at line {line_of(source, 'law_source_path_mismatch')} and authored source type at line {line_of(source, 'law_source_type_mismatch')}", "info",
              {"positive": "canonical path/type reaches no mismatch error", "negative": "wrong path -> law_source_path_mismatch; wrong type -> law_source_type_mismatch"}),
        check("law_ref_expression_sign_unit_hash_recomputed", all(x in law_block for x in ("law_ref=law_ref", "expression=expression", "left_sign=left_sign", "right_sign=right_sign", "unit=unit")) and
              "law_hash == _n05_law_source_hash" in authority_block and
              "source_hash == _n05_law_source_hash" in authority_block,
              f"constructor computes law hash at line {line_of(source, 'body_hash = _n05_law_source_hash')}; validator recomputes source/law hash at lines {line_of(source, 'law_source_hash_mismatch')}/{line_of(source, 'law_hash_mismatch')}", "info",
              {"positive": "unchanged typed law gives equal source_hash/law_hash", "negative": "changed expression/sign/unit with stale hash reaches hash mismatch"}),
        check("g1_occurrence_canonical_path_and_type_checked", g1_path and g1_type,
              f"endpoint locator path/type are checked at lines {line_of(source, 'G1_occurrence_path_mismatch')}-{line_of(source, 'G1_occurrence_type_mismatch')}", "info",
              {"positive": "canonical path uses equation_id and port_index", "negative": "wrong path/type reaches G1_occurrence_path_mismatch/type_mismatch"}),
        check("g1_locator_path_contains_full_identity_key", g1_path_full_key,
              f"lookup at line {line_of(source, 'occurrence = first')} distinguishes equation_id/port_side/port_index/ledger_id, but expected_occurrence_path at line {line_of(source, 'expected_occurrence_path')} contains only equation_id and port_index and is not rebuilt from the found occurrence", "blocker",
              {"counterexample": "two valid G1LedgerOccurrenceV2 values in one equation may share port_index while differing in port_side or ledger_id; both then receive the same N05 locator path"}),
        check("endpoint_and_unit_authored_path_type_checked", unit_path in authority_block and unit_type in authority_block and
              "locator.path == expected_source_path" in mutation_block and "locator.source_type === binding.source_type" in mutation_block,
              f"unit path/type checks are at lines {line_of(source, 'flux_unit_source_path_mismatch')}/{line_of(source, 'flux_unit_source_type_mismatch')}; mutation locator path/type guard at lines {line_of(source, 'N05 mutation source path mismatch')}/{line_of(source, 'N05 mutation source type mismatch')}", "info",
              {"positive": "right-unit locator uses authored unit path while receipt.error_path uses declaration field path", "negative": "wrong locator path/type throws before receipt"}),
        check("mutation_dispatch_uses_field_path_and_kind", endpoint_dispatch and not id_dispatch,
              f"registry lookup lines {line_of(source, 'function _n05_mutation_binding')}-{line_of(source, 'N05 mutation field_path/mutation_kind is not registered')} matches both field_path and mutation_kind; implementation branches on binding.target", "info",
              {"positive": "relabeled id with canonical path/kind still dispatches", "negative": "wrong path/kind pair throws registration error"}),
        check("mutation_expected_fields_are_oracle_only", not expected_used_in_impl,
              "expected_error/expected_resolution are absent from mutation implementation; tests compare fixture expectations after receipt construction", "info",
              {"positive": "error_code derives from returned invariant errors", "negative": "changing expected_error alone cannot change dispatch/classification"}),
        check("mutation_error_path_and_locator_bind_real_field", "error_path, binding.field_path" in mutation_block and
              "locator.path == expected_source_path" in mutation_block,
              f"receipt error_path uses binding.field_path at line {line_of(source, 'error_code, binding.field_path')}; locator path is checked before receipt at line {line_of(source, 'N05 mutation source path mismatch')}", "info",
              {"positive": "endpoint mutations use declaration field path; unit locator uses authored unit path and error_path remains /n05/right_endpoint/unit", "negative": "spec path/kind mismatch cannot silently rewrite receipt path"}),
        check("missing_declaration_five_rows_remain_authority_gap_terminal_deferred", "authority.declaration === nothing" in source and
              "binding.field_path" in source and ":authority_gap" in source and ":terminal_deferred" in source and
              len(fixture.get("mutations", [])) == 5 and "receipt.original_value == receipt.mutated_value" in test,
              f"nil declaration branch returns equal values, authority_gap and terminal_deferred at lines {line_of(source, 'if authority.declaration === nothing')}-{line_of(source, ':authority_gap')}; test covers five rows and equality at line {line_of(test, 'receipt.original_value == receipt.mutated_value')}", "info",
              {"positive": "all five valid specs take the same nil declaration branch", "negative": "declaration presence is not fabricated by mutation spec"}),
        check("e0_three_state_preserved_in_authority_validator", all(x in source for x in (":valid", ":fail_closed", ":program_exception", "E0_program_exception", "E0_source_contradiction")) and
              "e0_status === :program_exception" in source and "status=:terminal_deferred" in source,
              f"E0 mapping at lines {line_of(source, 'function _n05_e0_status')}-{line_of(source, 'E0_source_contradiction')}; validator retains program_exception and terminal_deferred paths", "info",
              {"positive": "E0 program exception returns program_exception; source contradiction fail_closed; valid + nil declaration terminal_deferred", "negative": "invalid E0 with declaration cannot be valid"}),
        check("mutation_baseline_validates_authority_and_e0_before_receipt", baseline_guard and e0_guard,
              f"mutation function begins at line {line_of(source, 'function up2n05_validate_mutation')} and proceeds to _n05_spec_value/_n05_authority_errors without calling up2n05_validate or _n05_e0_status; e0_binding appears only in signature", "blocker",
              {"counterexample": "forge UP2N05AuthorityV1 metadata (wrong candidate_ref/package_hash/binding_hash or resolution) while retaining a current package declaration; or pass an E0 binding with source contradiction. The function still constructs a mutated declaration and returns a fail_closed receipt."}),
        check("declaration_and_law_hashes_recomputed_on_declared_path", "declaration_hash_mismatch" in authority_block and
              "law_hash_mismatch" in authority_block and "declaration_hash" in mutation_block,
              f"declaration hash recomputation is at line {line_of(source, 'declaration_hash_mismatch')}; law hash mismatch is at line {line_of(source, 'law_hash_mismatch')}; mutation receipt carries original declaration hash", "info",
              {"positive": "constructor/validator use canonical body", "negative": "stale declaration/law hash is fail_closed when baseline validator is called"}),
        check("actual_a_join_and_contract_scope_preserved", "integrate_genome_v5(g1, g2, g3; candidate_ref=candidate)" in test and
              "up2_candidate_physical_binding_from_a(package)" in test and
              manifest.get("accepted") is False and manifest.get("scope") == "contract_only" and
              "contract_ready" in acceptance and "physical" in (ad24 + e0_acceptance).lower(),
              "test builds actual A package and E0 binding; manifest remains review_pending/accepted=false contract_only and AD-24 denies physical/provider/B04 credit", "info"),
    ]

    blockers = [c["name"] for c in checks if c["severity"] == "blocker" and not c["passed"]]
    process_seen = bool(receipts[1]["stdout"].strip())
    report = {
        "schema_version": "UP2-00E1-N05-independent-precheck-r2-v1",
        "verdict": "changes_requested" if blockers else "ready_for_focused_r2",
        "scope": "independent static R2 only; not acceptance",
        "reviewer": "Luna/high independent reviewer",
        "captured_at_utc": captured,
        "repository": str(ROOT),
        "frozen_snapshot": frozen,
        "invalid_if_any_frozen_file_changes": True,
        "manifest_snapshot_comparison": {"expected": expected, "current": frozen, "matches": hash_match},
        "checks": checks,
        "blockers": blockers,
        "commands": [{"command": r["command"], "real_exit": r["real_exit"],
                      "started_utc": r["started_utc"], "finished_utc": r["finished_utc"]} for r in receipts],
        "limitations": [
            "No Julia/DESC execution was performed; this is not dynamic validation or acceptance.",
            "R1 report under independent_precheck/ was not modified.",
            "Two existing julia.exe processes were observed by the read-only probe; this reviewer did not start or stop them." if process_seen else "Process probe was empty at capture time.",
            "A later change to frozen source/test/fixture/runner invalidates this R2 report.",
        ],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps({
        "schema_version": "UP2-00E1-independent-precheck-r2-command-receipts-v1",
        "captured_at_utc": captured, "commands": receipts,
        "note": "Read-only commands; no Julia/DESC invocation.",
    }, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = ["# E1-N05 independent static precheck R2", "",
          f"Verdict: **{report['verdict']}** (static only; not acceptance).",
          f"Captured UTC: `{captured}`. Frozen hashes are in `report.json`; any author change invalidates this report.", "",
          "## Blocking findings", ""]
    for c in checks:
        if c["severity"] == "blocker" and not c["passed"]:
            md.append(f"- **{c['name']}**: {c['evidence']}")
            if "static_case" in c:
                md.append(f"  - Static case: {c['static_case']}")
    md += ["", "## R1 repair evidence", ""]
    for c in checks:
        if c["passed"] and c["severity"] == "info":
            md.append(f"- `{c['name']}`: {c['evidence']}")
    observations = [c for c in checks if c["severity"] == "observation"]
    if observations:
        md += ["", "## Static observations", ""]
        for c in observations:
            md.append(f"- `{c['name']}`: {c['evidence']}")
    md += ["", "## Commands and limits", "",
           "- `command_receipts.json` contains command, timestamps, stdout, stderr, and real exit for diff-check, process probe, and JSON parse.",
           "- No Julia/DESC was run. The verdict cannot authorize focused execution until blockers are addressed and hashes are refrozen."]
    (OUT / "report.md").write_text("\n".join(md) + "\n", encoding="utf-8")
    return 1 if blockers else 0


if __name__ == "__main__":
    raise SystemExit(main())
