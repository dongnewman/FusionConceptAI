from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
LEDGER = ROOT / "docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER"
SRC = ROOT / "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"
TEST = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json"
RUNNER = ROOT / "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"
G1_FIXTURE = ROOT / "test/GenomeV5/G1/fixtures.json"
G3_FIXTURE = ROOT / "test/GenomeV5/G3/fixtures.json"

FROZEN = {
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl": "69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl": "d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json": "e37314924102c75ac47a34652d0a480c4730e04590cb17294033719ce92d37b8",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl": "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def run_command(name: str, args: list[str]) -> dict:
    started = utc_now()
    cp = subprocess.run(args, cwd=ROOT, text=True, capture_output=True,
                        encoding="utf-8", errors="replace")
    return {"name": name, "argv": args, "started_utc": started,
            "ended_utc": utc_now(), "exit": cp.returncode,
            "stdout": cp.stdout, "stderr": cp.stderr}


def jload(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def check(checks: dict, name: str, ok: bool, detail) -> None:
    checks[name] = {"pass": bool(ok), "detail": detail}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = jload(FIXTURE)
    checks: dict = {}

    actual = {rel: sha256(ROOT / rel) for rel in FROZEN}
    check(checks, "r9_frozen_hashes", actual == FROZEN, actual)
    check(checks, "r9_repair_manifest_hashes", (
        jload(LEDGER / "repair_r9/evidence_manifest.json")["after_hashes"] == FROZEN),
        "repair_r9 after_hashes equal current frozen test-only handoff")

    r9 = jload(LEDGER / "repair_r9/evidence_manifest.json")
    check(checks, "production_runner_unchanged", r9["after_hashes"]["src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"] == FROZEN["src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"] and
        r9["after_hashes"]["test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"] == FROZEN["test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"],
        "source and runner equal R8/R9 frozen values")

    # Reconstruct the unit chain from the actual G1/G3 fixture payloads.
    g1 = jload(G1_FIXTURE)
    g3 = jload(G3_FIXTURE)
    g1_ops = {x["id"]: x for x in g1["operators"]}
    selected_eqs = {x["id"]: x for x in g1["equations"]}
    selected_operator_units = {
        eq_id: g1_ops[selected_eqs[eq_id]["operator_id"]]["output_units"][0]
        for eq_id in ("governing-0", "source-0", "constraint-0")
    }
    zero = [0, 0, 0, 0, 0, 0, 0]
    check(checks, "actual_g1_selected_units", all(v == zero for v in selected_operator_units.values()),
          selected_operator_units)
    resources = {x["id"]: x for x in g3["construction"]["resources"]}
    entries = {x["id"]: x for x in g3["construction"]["entries"]}
    selected_g3_units = {
        "source_effort": resources["source_effort"]["unit"],
        "source_flow": resources["source_flow"]["unit"],
        "source_entry": entries["source-entry"]["unit"],
        "load": resources["load"]["unit"],
        "load_entry": entries["load-entry"]["unit"],
        "return": resources["return"]["unit"],
        "return_entry": entries["return-entry"]["unit"],
        "heat_sink": resources["heat_sink"]["unit"],
        "heat_entry": entries["heat-entry"]["unit"],
    }
    expected_power = [1, 2, -3, 0, 0, 0, 0]
    check(checks, "actual_g3_unit_chain", selected_g3_units["source_effort"] == [1, 2, -3, -1, 0, 0, 0] and
        selected_g3_units["source_flow"] == [0, 0, 0, 1, 0, 0, 0] and
        selected_g3_units["source_entry"] == expected_power and
        selected_g3_units["load"] == expected_power and selected_g3_units["load_entry"] == expected_power and
        selected_g3_units["return_entry"] == expected_power and selected_g3_units["heat_sink"] == expected_power and
        selected_g3_units["heat_entry"] == expected_power,
        selected_g3_units)
    check(checks, "source_effort_flow_sum_matches_entry", [a + b for a, b in zip(
        selected_g3_units["source_effort"], selected_g3_units["source_flow"])] == selected_g3_units["source_entry"],
        "actual G3 effort+flow exponent sum equals source-entry power")
    unit_audit_text = (LEDGER / "unit_gap_audit_r1/report.md").read_text(encoding="utf-8")
    repair_text = (LEDGER / "repair_r9/repair_note.md").read_text(encoding="utf-8")
    check(checks, "two_unit_audits_present_and_consistent",
          "actual A package cannot produce a complete valid four-role N06 mapping" in unit_audit_text and
          "G1 fixture gives every selected occurrence dimensionless" in unit_audit_text and
          "G3 fixture gives effort/flow/load/return/heat resources" in unit_audit_text and
          "same_dimension" in repair_text and "G1 actual occurrence" in repair_text,
          "unit_gap_audit_r1 plus repair_r9 unit/provenance boundary")

    check(checks, "baseline_exact_mismatch_and_admission_deferred",
          '"conversion_same_dimension_mismatch" in baseline_errors' in test and
          '@test_throws ArgumentError G.n06_mapping_from_a(package, e0, joins)' in test and
          'G.n06_mapping_admission(package, e0).status == :terminal_deferred' in test and
          'isempty(errors) || throw(ArgumentError("N06 mapping is structurally inconsistent: " * join(errors, ",")))' in source and
          'mapping === nothing && return (status=:terminal_deferred' in source,
          "test lines 205-211; source lines 588-593 and 854-860")

    target_codes = [
        "owner_scope_accounts_duplicate", "conversion_offset_invalid_for_derived_dimension",
        "power_flow_partner_missing", "power_flow_link_identity_mismatch",
        "g1_occurrence_not_bound_to_role_selector",
    ]
    check(checks, "five_mapping_controls_nonvacuous_relative_baseline",
          'errors = _n06_mapping_error_set(package, projection, joins)' in test and
          '@test expected_code in setdiff(errors, baseline_errors)' in test and
          all(code in test for code in target_codes) and
          'length(_N06_FIXTURE.mapping_negative_controls) == 5' in test,
          {"target_codes": target_codes, "helper": "setdiff(errors, baseline_errors)"})
    check(checks, "five_mutations_still_independently_exercised",
          'for row in _N06_FIXTURE.mutations' in test and
          'length(_N06_FIXTURE.mutations) == 5' in test and
          all(x in test for x in ["result.mutated_input_hash != result.input_hash",
                                  "result.error_path == spec.field_path",
                                  "result.status == Symbol(String(row.expected_status))",
                                  "result.error_code == Symbol(String(row.expected_error))"]),
          "test lines 225-238; five fixture rows remain in one unconditional loop")

    check(checks, "fixture_labels_not_production_classification",
          "row.expected_error" not in source and "row.expected_status" not in source and
          "spec.field_path" in source and "spec.mutation_kind" in source and
          "expected_kind = if field.source_locator" in source and
          "forged_oracle" in test and "row.mutation_kind, :terminal_deferred" in test and
          "error_code == :invalid_ref" in test,
          "production dispatch is path/source-bound; forged expected label still yields invalid_ref")
    check(checks, "mutation_dispatch_source_bound",
          all(x in source for x in ["_n06_validate_spec_binding", "field.source_locator == spec.source_locator",
                                    "field.source_type == spec.source_type", "target.mutation_kind === :wrong_resource_port",
                                    "target.mutation_kind === :wrong_entry_account", "target.mutation_kind === :missing_control_link",
                                    "target.mutation_kind === :closure_balance_mismatch", "target.mutation_kind === :wrong_resource_kind"]),
          "source lines 641-752")

    r8_receipt_path = LEDGER / "focused_r8/receipt.json"
    r8 = jload(r8_receipt_path)
    check(checks, "r8_exit1_raw_preserved",
          r8["exit"] == 1 and r8["stdout"]["sha256"] == "2c1af4ecbdc49fa85eaae9c0be449badd75dd4d5e0890ee231b3e88390c80b98" and
          r8["stderr"]["sha256"] == "8ac494a454f7fbc73af737756244bf9d08ad2aebc8e3808d99f982006b52c920" and
          sha256(LEDGER / "focused_r8/stdout.log") == r8["stdout"]["sha256"] and
          sha256(LEDGER / "focused_r8/stderr.log") == r8["stderr"]["sha256"],
          "focused R8 real exit 1 and stdout/stderr receipt hashes")
    check(checks, "r1_r7_raw_history_present",
          all((LEDGER / f"focused_r{i}" / "receipt.json").is_file() and
              (LEDGER / f"focused_r{i}" / "stdout.log").is_file() and
              (LEDGER / f"focused_r{i}" / "stderr.log").is_file() for i in range(1, 8)),
          "R1-R7 receipt/stdout/stderr files remain present")

    protected_expected = {}
    for line in (LEDGER / "focused_r8/protected_after_hashes.txt").read_text(encoding="utf-8").splitlines():
        parts = line.replace("\t", " ").split()
        if len(parts) >= 2 and re.fullmatch(r"[0-9a-f]{64}", parts[-1]):
            protected_expected[parts[0]] = parts[-1]
        elif len(parts) >= 2 and re.fullmatch(r"[0-9a-f]{64}", parts[0]):
            protected_expected[parts[1]] = parts[0]
    protected_current = {rel: sha256(ROOT / rel) for rel in protected_expected}
    check(checks, "protected_dirty_hashes_unchanged", protected_current == protected_expected,
          {"expected": protected_expected, "current": protected_current})

    commands = [
        run_command("json_parse", [sys.executable, "-c", "import json, pathlib; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER').rglob('*.json') if p.stat().st_size]; print('json_parse_ok')"]),
        run_command("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run_command("git_diff_check", ["git", "diff", "--check"]),
        run_command("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName | ConvertTo-Json -Compress"]),
    ]
    exits = {x["name"]: x["exit"] for x in commands}
    check(checks, "static_command_qa", all(x == 0 for x in exits.values()), exits)
    sweep = next(x for x in commands if x["name"] == "julia_desc_process_sweep")
    check(checks, "no_julia_desc_started_or_observed", sweep["stdout"].strip() in ("", "null", "{}", "[]"), sweep["stdout"])

    passed = all(v["pass"] for v in checks.values())
    verdict = "ready_for_focused_r9" if passed else "changes_requested"
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True,
                          capture_output=True, encoding="utf-8", errors="replace").stdout.strip()
    report = {
        "schema_version": "n06-independent-static-precheck-v1",
        "work_order": "E2-N06-SOURCE-FIELD-LEDGER-independent-precheck-r11",
        "review_round": "R11",
        "reviewer_role": "different_luna_test_only_static_reviewer",
        "head": head, "verdict": verdict, "accepted": False,
        "frozen_inputs": actual, "checks": checks, "command_receipts": commands,
        "runtime": {"julia": False, "desc": False, "status": "not_run",
                    "reason": "test-only R9 static precheck; focused R9 remains required"},
        "claim_ceiling": "contract/test readiness only; no B04/provider/mesh/engineering/physical/R01-R10 credit",
        "owned_write_scope": ["docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_precheck_r11/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": "n06-independent-evidence-manifest-v1", "review_round": "R11",
        "verdict": verdict, "accepted": False, "frozen_inputs": actual,
        "r8_receipt": {"path": "focused_r8/receipt.json", "sha256": sha256(r8_receipt_path), "exit": 1},
        "repair_r9": "repair_r9/evidence_manifest.json", "unit_audit": "unit_gap_audit_r1/",
        "raw_history": [f"focused_r{i}/" for i in range(1, 9)],
        "claim_ceiling": report["claim_ceiling"],
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E2-N06 test-only independent static precheck R11\n\nVerdict: `{verdict}` (static readiness only; no runtime acceptance).\n\nThe R9 test-only repair is frozen as source `{actual['src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl']}`, test `{actual['test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl']}`, fixture `{actual['test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json']}`, runner `{actual['test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl']}`. Production source and runner remain unchanged.\n\nStatic reconstruction confirms actual G1 selected equations are dimensionless while the G3 effort/flow/entry chain is typed and its effort+flow exponents sum to source-entry power; load/return/heat entry units remain separately visible. The unit-gap audit and R9 repair note preserve the cross-layer-law/provenance boundary. Baseline explicitly contains `conversion_same_dimension_mismatch`, expects `ArgumentError`, and leaves no-mapping admission `terminal_deferred`.\n\nThe five mapping controls call `_n06_mapping_error_set` and require each target code in `setdiff(errors, baseline_errors)` before `ArgumentError`; the five source-derived mutation rows remain an unconditional loop. Production classification binds exact field path, source locator/type, and mutation kind; fixture `expected_error`/`expected_status` labels do not appear in production. R8 exit-1 raw receipt/stdout/stderr and R1-R7 history remain preserved.\n\nJSON parse, `validate_plan.py`, `git diff --check`, and Julia/DESC process sweep are recorded in `command_receipts.json`. Julia/DESC was not run. No B04/provider/mesh/engineering/physical/R01-R10 credit is granted; one focused R9 runtime run remains required.\n"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
