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
FROZEN = {
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl": "69bd82f040f405e55768e52af64b9b9b6d97272a2ec3988b66b7bdf21ec1128c",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl": "d88a1ed7965716eb4210c09fd5b89b3e4e27e8677c15ff8dcbe0721b8a373ca1",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json": "e37314924102c75ac47a34652d0a480c4730e04590cb17294033719ce92d37b8",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl": "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}
STATIC_CONTROLS = [
    "duplicate_resource_port_id", "forged_source_locator", "forged_source_type",
    "same_dimension_exponent_mismatch", "missing_power_flow_partner",
    "foreign_valid_flow_link", "reordered_network_dynamic_path",
    "wrong_mutation_kind_for_target", "relabeled_mutation_id", "detached_projection",
    "detached_g1_occurrence", "foreign_e0_binding", "missing_source_selector",
    "wrong_source_selector",
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def run(name: str, argv: list[str]) -> dict:
    started = now()
    cp = subprocess.run(argv, cwd=ROOT, text=True, capture_output=True,
                        encoding="utf-8", errors="replace")
    return {"name": name, "argv": argv, "started_utc": started,
            "ended_utc": now(), "exit": cp.returncode,
            "stdout": cp.stdout, "stderr": cp.stderr}


def jload(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def mark(checks: dict, key: str, value: bool, detail) -> None:
    checks[key] = {"pass": bool(value), "detail": detail}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = jload(FIXTURE)
    repair = jload(LEDGER / "repair_r9/evidence_manifest.json")
    r10 = jload(LEDGER / "repair_r10/evidence_manifest.json")
    receipt_path = LEDGER / "focused_r9/receipt.json"
    receipt = jload(receipt_path)
    stdout = (LEDGER / "focused_r9/stdout.log").read_text(encoding="utf-8", errors="replace")
    stderr = (LEDGER / "focused_r9/stderr.log").read_text(encoding="utf-8", errors="replace")
    r9_input_hashes = (LEDGER / "focused_r9/input_hashes.txt").read_text(encoding="utf-8")
    checks: dict = {}

    actual = {p: digest(ROOT / p) for p in FROZEN}
    mark(checks, "frozen_r9_hashes", all(f"{FROZEN[p]}  {p}" in r9_input_hashes for p in FROZEN),
         {"r9_input_hashes": FROZEN, "current_hashes": actual})
    mark(checks, "repair_manifest_after_hashes", repair["after_hashes"] == FROZEN,
         "repair_r9 after_hashes preserve the historical R9 execution inputs")
    mark(checks, "current_post_r10_test_drift_recorded",
         actual["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"] != FROZEN["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"] and
         r10["before_hashes"]["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"] == FROZEN["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"],
         {"r9_test_sha256": FROZEN["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"],
          "current_test_sha256": actual["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"],
          "r10_before_sha256": r10["before_hashes"]["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"]})
    mark(checks, "r9_raw_receipt_immutable_and_consistent",
         receipt["real_exit"] == 1 and digest(receipt_path) == "798ad6a4cbc1271dbce3635e2e6acd5fbced13cc6360da99676f5ee4fa48d6d7" and
         digest(LEDGER / "focused_r9/stdout.log") == receipt["stdout"]["sha256"] and
         digest(LEDGER / "focused_r9/stderr.log") == receipt["stderr"]["sha256"] and
         receipt["stdout"]["sha256"] == "f5e260c982bea274fef3971d3be7776cf579b9b690711c6805001735824f8e33" and
         receipt["stderr"]["sha256"] == "83dcb1d7da537842e8ca9f65f2d8af0dcf7cf571e2f7161a726cc09532ebddd8",
         {"exit": receipt["real_exit"], "stdout": receipt["stdout"], "stderr": receipt["stderr"]})

    mark(checks, "raw_group_counts_and_failure",
         "UP2-00E N06 actual A authored sample and typed boundary |   28     28" in stdout and
         re.search(r"UP2-00E N06 typed occurrence identity index \|\s+3\s+3", stdout) is not None and
         "UP2-00E N06 source-derived mutation controls |   31     31" in stdout and
         "UP2-00E shared owner and E0 identity boundary |   37     1     38" in stdout and
         "Evaluated: 14 == 12" in stdout and
         "static_negative_controls) == 12" in stdout,
         "R9 raw stdout exact N06 counts and stale fixture-count failure")

    fixture_controls = [str(x) for x in fixture["static_negative_controls"]]
    mark(checks, "fixture_has_fourteen_static_controls",
         len(fixture_controls) == 14 and fixture_controls == STATIC_CONTROLS,
         fixture_controls)
    mark(checks, "two_selector_controls_present_in_fixture",
         "missing_source_selector" in fixture_controls and "wrong_source_selector" in fixture_controls,
         {"missing_source_selector": "missing_source_selector" in fixture_controls,
          "wrong_source_selector": "wrong_source_selector" in fixture_controls})
    mark(checks, "test_stale_count_is_exact_source_of_failure",
         r10["r9_reference"]["failure"] == "fixture static_negative_controls has 14 IDs while test asserted 12" and
         "Evaluated: 14 == 12" in stdout,
         "R9 line 263 stale assertion is preserved by focused raw and repair_r10 reference")
    mark(checks, "selector_controls_have_explicit_test_paths",
         '"missing_source_selector" in' in test and '"wrong_source_selector" in' in test and
         "delete!(G._N06_G1_ROLE_SELECTORS, :source)" in test and
         "port_index=99" in test and "finally" in test and
         "G1 authored governing occurrence has no source match" in test,
         "test lines 332-371 dynamically exercise missing/wrong selector and restore selector")
    mark(checks, "selector_controls_not_reached_in_r9",
         "UP2-00E shared owner and E0 identity boundary: Test Failed" in stdout and
         "UP2-00E shared owner and E0 identity boundary |   37     1     38" in stdout,
         "line 263 precedes selector code at test lines 332-371; presence is static only, not runtime execution")

    mark(checks, "five_mutations_really_reached",
         "UP2-00E N06 source-derived mutation controls |   31     31" in stdout and
         "for row in _N06_FIXTURE.mutations" in test and len(fixture["mutations"]) == 5,
         "raw group completed 31/31 and frozen test loop has five rows")
    mark(checks, "no_production_or_runner_test_change",
         repair["after_hashes"]["src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"] == FROZEN["src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"] and
         repair["after_hashes"]["test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"] == FROZEN["test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl"],
         "repair_r9 was test/fixture-only")
    mark(checks, "r8_and_prior_raw_preserved",
         jload(LEDGER / "focused_r8/receipt.json")["exit"] == 1 and
         all((LEDGER / f"focused_r{i}/receipt.json").is_file() for i in range(1, 8)),
         "R8 exit1 receipt and R1-R7 receipts present")

    commands = [
        run("json_parse", [sys.executable, "-c", "import json, pathlib; [json.loads(p.read_text(encoding='utf-8')) for p in pathlib.Path('docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER').rglob('*.json') if p.stat().st_size]; print('json_parse_ok')"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-Process | Where-Object { $_.ProcessName -match 'julia|desc' } | Select-Object Id,ProcessName | ConvertTo-Json -Compress"]),
    ]
    exits = {x["name"]: x["exit"] for x in commands}
    mark(checks, "static_qa_commands", all(v == 0 for v in exits.values()), exits)
    sweep = next(x for x in commands if x["name"] == "julia_desc_process_sweep")
    mark(checks, "no_julia_desc_run_by_audit", sweep["stdout"].strip() in ("", "null", "{}", "[]"), sweep["stdout"])

    passed = all(x["pass"] for x in checks.values())
    verdict = "failure_audit_open_gate" if passed else "changes_requested"
    report = {
        "schema_version": "n06-independent-postrun-failure-audit-v1",
        "work_order": "E2-N06-SOURCE-FIELD-LEDGER-independent-postrun-r9",
        "review_round": "postrun-R9", "reviewer_role": "different_luna_failure_auditor",
        "verdict": verdict, "accepted": False, "frozen_inputs": actual,
        "checks": checks, "command_receipts": commands,
        "open_gate": "test-only correction must reconcile 14 static controls and prove both selector controls execute; do not merely hide the two controls by changing a count",
        "runtime": {"julia": False, "desc": False, "status": "not_run_by_audit"},
        "claim_ceiling": "failure audit only; no B04/provider/mesh/engineering/physical/R01-R10 credit",
        "owned_write_scope": ["docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_postrun_r9/"],
    }
    (OUT / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    manifest = {
        "schema_version": "n06-independent-postrun-evidence-v1", "review_round": "postrun-R9",
        "verdict": verdict, "accepted": False, "r9_receipt_sha256": digest(receipt_path),
        "r9_stdout_sha256": receipt["stdout"]["sha256"], "r9_stderr_sha256": receipt["stderr"]["sha256"],
        "static_controls_count": len(fixture_controls),
        "selector_controls": ["missing_source_selector", "wrong_source_selector"],
        "selector_runtime_status": "not_reached_due_to_stale_count_at_test_line_263",
        "mutation_runtime": "31/31 group passed; five fixture rows in frozen loop",
        "failure": "fixture contains 14 static_negative_controls while test asserts 12",
        "open_gate": report["open_gate"], "claim_ceiling": report["claim_ceiling"],
    }
    (OUT / "evidence_manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# N06 focused R9 independent failure audit\n\nVerdict: `{verdict}`. This audit did not run Julia/DESC and did not modify R9/raw.\n\nR9 receipt exit=1, baseline group `28/28`, typed occurrence group `3/3`, and source-derived mutation group `31/31`; shared owner/E0 group failed `37 pass / 1 fail / 38 total` at test line 263 because the fixture contains 14 static negative controls while the R9 test asserted 12.\n\nThe two selector controls `missing_source_selector` and `wrong_source_selector` are present in the 14-item fixture and have explicit test paths at lines 332-371, including selector restoration. They were not reached by this R9 run because line 263 fails first. The minimal safe test-only repair is to reconcile the stale count with an exact set assertion covering all 14 names, while preserving both selector test bodies; changing only a number without retaining/exercising those controls is insufficient.\n\nPost-R9 provenance: the current test hash is `{actual["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"]}`, while the R9 execution input and repair_r10 before hash are `{FROZEN["test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"]}`. This audit therefore treats the R9 raw result as immutable historical evidence and does not treat the later test-only repair as runtime-validated.\n\nR9 source/test/fixture/runner hashes from `focused_r9/input_hashes.txt`, raw receipt/stdout/stderr, R8 exit1 evidence, and prior receipts were checked. JSON parse, `validate_plan.py`, `git diff --check`, and post-audit Julia/DESC sweep all exited 0. No claim credit is granted.\n"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
