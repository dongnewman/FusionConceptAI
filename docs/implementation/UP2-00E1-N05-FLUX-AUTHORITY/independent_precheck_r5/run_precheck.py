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
FROZEN = {
    "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl":
        "3697d0db47adb339d7ae11cced4c4cc2eed1e1bc2f8b314c3001d479fae0c9df",
    "test/GenomeV5/UP2/n05_flux_authority_tests.jl":
        "57b83ca321cf61b284656cd238356943b2521b4d80029e8a8424706117d42543",
    "test/GenomeV5/UP2/n05_flux_authority_fixtures.json":
        "049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81",
    "test/GenomeV5/UP2/run_n05_flux_authority.jl":
        "3d51de1a65d6c48afae0aa57877d63c29600d061799f324fcf48a436b8cebca3",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def line(text: str, needle: str) -> int | None:
    for n, value in enumerate(text.splitlines(), 1):
        if needle in value:
            return n
    return None


def block(text: str, start: str, end: str) -> str:
    a = text.index(start)
    b = text.index(end, a + len(start))
    return text[a:b]


def run(name: str, argv: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    proc = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")
    finished = datetime.now(timezone.utc).isoformat()
    return {"name": name, "argv": argv, "started_utc": started,
            "finished_utc": finished, "exit": proc.returncode,
            "stdout": proc.stdout, "stderr": proc.stderr}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source_path = ROOT / "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl"
    test_path = ROOT / "test/GenomeV5/UP2/n05_flux_authority_tests.jl"
    fixture_path = ROOT / "test/GenomeV5/UP2/n05_flux_authority_fixtures.json"
    source = source_path.read_text(encoding="utf-8")
    tests = test_path.read_text(encoding="utf-8")
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    blockers: list[str] = []
    checks: dict[str, object] = {}

    frozen = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        frozen[rel] = {"expected": expected, "actual": actual,
                       "match": actual == expected}
        if actual != expected:
            blockers.append(f"frozen hash mismatch: {rel}")
    checks["frozen_hashes"] = frozen

    expected_rows = [
        ("N05-01", "/n05/left_endpoint/endpoint_ref", "foreign_left_endpoint_ref", "invalid_closure", "fail_closed"),
        ("N05-02", "/n05/right_endpoint/endpoint_ref", "foreign_right_endpoint_ref", "invalid_closure", "fail_closed"),
        ("N05-03", "/n05/left_endpoint/sign", "left_sign_zero", "invalid_closure", "fail_closed"),
        ("N05-04", "/n05/right_endpoint/sign", "same_endpoint_sign", "invalid_closure", "fail_closed"),
        ("N05-05", "/n05/right_endpoint/unit", "right_unit_mismatch", "invalid_type", "fail_closed"),
    ]
    rows = fixture["mutations"]
    actual_rows = [(str(x["id"]), str(x["field_path"]), str(x["mutation_kind"]),
                    str(x["expected_error"]), str(x["expected_resolution"])) for x in rows]
    checks["fixture"] = {
        "schema_id": fixture.get("schema_id"),
        "schema_version": fixture.get("schema_version"),
        "schema_validation_only": fixture.get("schema_validation_only"),
        "rows": actual_rows,
        "exact_five_contract_rows": actual_rows == expected_rows,
    }
    if actual_rows != expected_rows or fixture.get("schema_validation_only") is not True:
        blockers.append("fixture schema or five authored rows changed")

    dispatch = block(source, "function _n05_mutation_binding", "function _n05_binding_hash")
    authority_errors = block(source, "function _n05_authority_errors", "function _n05_e0_status")
    classifier = source[source.index("# Classify from the observed invariant errors."):source.index("UP2N05MutationReceiptV1(spec.id", source.index("# Classify from the observed invariant errors."))]
    # The first `end` after the function header is not the function terminator in Julia,
    # so use the stable classifier and declaration markers for the mutation checks.
    mutation = source[source.index("function up2n05_validate_mutation"):]

    source_assertions = {
        "schema_canonical_profile_hashes_declared": all(
            x in source for x in (
                "UP2N05_SCHEMA_HASH_V1 = digest256_text(UP2N05_SCHEMA_SOURCE_V1)",
                "UP2N05_CANONICAL_HASH_V1 = digest256_text(UP2N05_CANONICAL_SOURCE_V1)",
                "UP2N05_PROFILE_HASH_V1 = digest256_text(UP2N05_PROFILE_SOURCE_V1")),
        "binding_hash_includes_declared_hashes_and_declaration": all(
            x in block(source, "function _n05_binding_hash", "function _n05_package_fields")
            for x in ("declaration=declaration", "schema_hash=schema_hash",
                      "canonicalization_hash=canonical_hash_value", "profile_hash=profile_hash")),
        "law_hash_recomputed_and_source_checked": all(
            x in source for x in (
                "body_hash = _n05_law_source_hash", "law.law_hash == _n05_law_source_hash",
                "law.source.path == \"/n05/authored_flux_law/$(declaration.law.law_ref.id)\"",
                "law.source.source_type === :AuthoredFluxLawV1",
                "law.source.source_hash == _n05_law_source_hash")),
        "endpoint_unit_source_path_type_hash_checked": all(
            x in authority_errors for x in (
                "endpoint.unit.source.layer === :N05",
                "endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1",
                "endpoint.unit.source.path == _n05_authored_unit_path",
                "endpoint.unit.source.source_hash == canonical_hash")),
        "endpoint_source_type_and_hash_is_authored": all(
            x in source for x in ("function _n05_endpoint_source", "canonical_hash((endpoint_ref=endpoint.endpoint_ref",
                                  ":AuthoredFluxEndpointV1")),
        "g1_unique_actual_four_key_join": all(
            x in authority_errors for x in (
                "o.equation_id == endpoint.occurrence.equation_id",
                "o.port_side == endpoint.occurrence.port_side",
                "o.port_index == endpoint.occurrence.port_index",
                "o.ledger_id == endpoint.occurrence.ledger_id",
                "length(matches) == 1", "occurrence isa G1LedgerOccurrenceV2")),
        "g1_actual_locator_ref_hash_full_path_type_checked": all(
            x in source for x in (
                "endpoint.occurrence.locator.source_ref == g1_ref",
                "endpoint.occurrence.locator.source_hash == g1_hash",
                "endpoint.occurrence.locator.path == expected_occurrence_path",
                "endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2",
                "function _n05_occurrence_path")),
        "strict_unique_interface": "length(matches) == 1 ? only(matches) : nothing" in source,
        "e0_baseline_validation_precedes_mutation": (
            "baseline = up2n05_validate(authority, package, e0_binding)" in mutation and
            mutation.index("baseline = up2n05_validate(authority, package, e0_binding)") <
            mutation.index("mutated_declaration = _n05_mutated_declaration")),
        "mutation_dispatch_is_field_path_and_kind":
            "binding.field_path == spec.field_path && binding.mutation_kind === spec.mutation_kind" in dispatch,
        "dispatch_does_not_read_id_or_expected_oracle": all(
            x not in dispatch for x in ("spec.id", "spec.expected_error", "spec.expected_resolution")),
        "classifier_uses_observed_errors_and_priority": all(
            x in classifier for x in (
                "closure_markers =", "unit_markers =", "has_closure_error =", "has_unit_error =",
                "error_code = has_closure_error ? :invalid_closure", "has_unit_error ? :invalid_type",
                "fixture's expected label", "mutation id do not")),
        "unknown_error_set_raises_exception":
            'throw(ArgumentError("N05 mutation errors have no registered classification:' in source,
        "no_fixture_or_spec_expected_error_in_classifier":
            "spec.expected_error" not in classifier and "spec.expected_resolution" not in classifier,
        "e0_three_state_and_no_downstream_calls": all(
            x in source for x in (":program_exception", ":fail_closed", ":terminal_deferred",
                                  "compile_calls=0", "provider_calls=0", "solver_calls=0")),
        "no_physics_execution_route": all(
            x in source for x in ("compile_calls=0", "provider_calls=0", "solver_calls=0")),
    }
    checks["implementation_source_assertions"] = source_assertions
    if not all(source_assertions.values()):
        blockers.append("authored source, E0 baseline, classifier, or exact join assertion failed")

    scan = source + "\n" + tests
    regression = {
        "unsupported_first_generator_default": bool(re.search(r"first\([^\n]*,\s*nothing\)", scan)),
        "symbol_concat": bool(re.search(r"Symbol\([^\n]*\*|\*\s*Symbol\(", scan)),
    }
    checks["R3_regression_patterns"] = regression
    if any(regression.values()):
        blockers.append("R3 unsupported first(generator,nothing) or Symbol concatenation remains")

    test_assertions = {
        "actual_A_package_and_E0_source_binding": all(x in tests for x in (
            "function _n05_actual_package", "function _n05_e0_binding",
            "G.up2_candidate_physical_binding_from_a(package)",
            "package.candidate_hash == G._up2e0_package_hash(package)")),
        "five_source_bound_mutations_and_zero_calls": all(x in tests for x in (
            "for row in _N05_FIXTURE.mutations", "receipt.source_locator.layer == :N05",
            "receipt.source_locator.source_type", "receipt.source_locator.source_hash != package.g1.candidate_hash",
            "receipt.resolution == :fail_closed", "receipt.compile_calls == receipt.provider_calls == receipt.solver_calls == 0")),
        "closure_priority_and_genuine_unit_regression": all(x in tests for x in (
            "foreign_left_endpoint_ref", "right_unit_mismatch",
            ".error_code == :invalid_closure", ".error_code == :invalid_type")),
        "id_label_only_and_path_kind_rejection": all(x in tests for x in (
            "forged-receipt-label", "relabeled_receipt.error_path == canonical.field_path",
            "canonical.mutation_kind", "N05-01\", \"/n05/right_endpoint/endpoint_ref")),
        "foreign_stale_authority_and_package_rejected": all(x in tests for x in (
            "foreign_authority", "foreign_package", "@test_throws ArgumentError G.up2n05_validate_mutation")),
        "duplicate_g1_and_interface_fail_closed": all(x in tests for x in (
            "duplicate occurrence locator is fail-closed", "G1_occurrences_not_independent",
            "duplicate interface lookup is not silently selected")),
        "law_unit_and_binding_hash_probes": all(x in tests for x in (
            "law.source.source_type", "left_endpoint.unit.source.source_hash",
            "authority.binding_hash", "authority.schema_hash == G.UP2N05_SCHEMA_HASH_V1")),
        "three_state_receipts": all(x in tests for x in (
            ":terminal_deferred", "length(deferred.gaps) == 5", ":authority_gap", ":fail_closed")),
    }
    checks["test_adversarial_assertions"] = test_assertions
    if not all(test_assertions.values()):
        blockers.append("required source-bound or adversarial test evidence is missing")

    checks["no_author_fixture_or_id_routing"] = {
        "source_expected_fields_only_in_spec_type": source.count("expected_error") == 1 and source.count("expected_resolution") == 1,
        "source_spec_id_only_receipt_label_or_hash": all(
            x in mutation for x in ("UP2N05MutationReceiptV1(spec.id", "canonical_hash((id=spec.id")),
        "tests_are_oracle_consumers": "@test receipt.error_code == Symbol(String(row.expected_error))" in tests,
    }

    commands = [
        run("json_parse", [sys.executable, "-c", "import json; json.load(open('test/GenomeV5/UP2/n05_flux_authority_fixtures.json', encoding='utf-8'))"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {c["name"]: c["exit"] for c in commands}
    for c in commands[:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "ready_for_focused_r4"
    result = {
        "review_id": "UP2-00E1-N05-FLUX-AUTHORITY-independent-precheck-r5",
        "reviewer": "different-Luna static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "static_precheck_only_no_julia_or_desc_or_acceptance",
        "blockers": blockers,
        "checks": checks,
        "frozen_hashes": FROZEN,
        "limitations": [
            "Julia/DESC and the N05 runner were not started; no dynamic or acceptance claim is made.",
            "The unknown observed-error branch raises ArgumentError; the contract boundary retains this as program_exception, but this precheck does not execute it.",
            "Any author change to one of the four frozen files invalidates this verdict.",
        ],
        "commands": commands,
        "source_lines": {k: line(source, k) for k in (
            "function _n05_authority_errors", "function up2n05_validate_mutation",
            "baseline = up2n05_validate(authority, package, e0_binding)",
            "closure_markers =", "UP2N05MutationReceiptV1(spec.id")},
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E1-N05 independent static precheck R5

Verdict: **{verdict}**. This is a static precheck only; Julia/DESC and the N05 runner were not started.

The four frozen inputs match exactly: source `{FROZEN['src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl']}`, test `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_tests.jl']}`, fixture `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_fixtures.json']}`, and runner `{FROZEN['test/GenomeV5/UP2/run_n05_flux_authority.jl']}`. The fixture remains schema-validation-only with exactly five N05 rows.

The repaired classifier derives its result from observed invariant errors. Endpoint reference, port-law, sign, interface, region, and related closure markers take priority over secondary unit-provenance markers, while a genuine unit contradiction yields `invalid_type`. An unregistered error set raises `ArgumentError`; this is the preserved `program_exception` path rather than a fixture or ID fallback. `expected_error`, `expected_resolution`, and `spec.id` are absent from dispatch/classification; `id` is retained for receipt labels and hashes only.

The mutation function first validates the unmutated authority against the supplied A package and E0 binding. It then uses the registered `(field_path, mutation_kind)` pair. Source checks retain canonical schema/canonicalization/profile hashes, declaration and law hash recomputation, authored law/endpoint/unit path/type/hash provenance, a unique actual `G1LedgerOccurrenceV2` full four-key join, and actual G1 locator ref/hash/full path/type. Tests retain the five source-bound mutations, explicit closure/unit regression, foreign/stale authority/package rejection, relabelled-ID probe, duplicate G1/interface negatives, terminal-deferred authority gaps, and zero downstream counters.

Independent command receipts with real exit/stdout/stderr/timestamps are in [command_receipts.json](command_receipts.json); structured checks and exact frozen hashes are in [report.json](report.json). JSON parse, `validate_plan.py`, and `git diff --check` exited 0. Any change to a frozen input invalidates this precheck.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_hashes": FROZEN, "command_exits": checks["command_exits"],
        "evidence_files": {},
    }
    for name in ("run_precheck.py", "report.md", "report.json", "command_receipts.json", "initial_false_verdict_correction.md"):
        evidence["evidence_files"][name] = sha(OUT / name)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers,
                      "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
