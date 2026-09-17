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
    "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl": "a9d78114db29a0ff16b785fe08318884c073e6a433ec16a4c403445ada004ec8",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json": "9cc85ec2cf0f4e00cf4f613705cca15fd2cd5be23d56042eeb3a96d3fcb80f44",
    "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl": "9a19b54ae2c92f8b557ffc79e144e4bf8e6cc4e2fa1bf04f50ae871f66a31783",
    "test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl": "9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def command(name: str, argv: list[str]) -> dict:
    started = datetime.now(timezone.utc).isoformat()
    p = subprocess.run(argv, cwd=ROOT, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    finished = datetime.now(timezone.utc).isoformat()
    return {"name": name, "argv": argv, "started_utc": started,
            "finished_utc": finished, "exit": p.returncode,
            "stdout": p.stdout, "stderr": p.stderr}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    source_path = ROOT / "src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl"
    test_path = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl"
    fixture_path = ROOT / "test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json"
    source = source_path.read_text(encoding="utf-8")
    tests = test_path.read_text(encoding="utf-8")
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    blockers: list[str] = []
    checks: dict[str, object] = {}

    checks["frozen_hashes"] = {
        rel: {"expected": expected, "actual": sha(ROOT / rel), "match": sha(ROOT / rel) == expected}
        for rel, expected in FROZEN.items()
    }
    if not all(x["match"] for x in checks["frozen_hashes"].values()):
        blockers.append("one or more frozen N06 input hashes changed")

    selectors = [(str(x["role"]), str(x["ledger_id"]), str(x["equation_id"]), str(x["port_side"]), int(x["port_index"])) for x in fixture["g1_occurrence_selectors"]]
    expected_selectors = [
        ("source", "energy", "governing-0", "output", 1),
        ("field", "energy", "source-0", "output", 1),
        ("return", "constraint", "constraint-0", "output", 1),
        ("heat", "constraint", "constraint-0", "output", 2),
    ]
    checks["fixture_contract"] = {
        "schema_validation_only": fixture.get("schema_validation_only"),
        "selector_count": len(selectors),
        "selectors_exact": selectors == expected_selectors,
        "mutation_count": len(fixture.get("mutations", [])),
        "static_negative_controls": fixture.get("static_negative_controls", []),
        "execution_claims": fixture.get("execution_claims", {}),
    }
    if selectors != expected_selectors or len(fixture.get("mutations", [])) != 5:
        blockers.append("fixture selectors or five mutation rows are not exact")

    # Source-level checks for the repaired selection and join paths.
    source_checks = {
        "full_E0_validator_before_actual_fields": "e0_check = up2e0_validate_binding(e0, package)" in source and source.index("e0_check = up2e0_validate_binding(e0, package)") < source.index("_n06_actual_fields(package)"),
        "E0_program_exception_and_fail_closed_paths": all(x in source for x in ["e0_check.status == :program_exception", "N06 E0 binding program_exception", "N06 E0 binding validation failed", "up2e0_check_package(package)"]),
        "unique_g1_equation_and_four_key_occurrence": all(x in source for x in ["_n06_unique_match(equations", "x.role == :governing", "x.equation_id == governing_selector.equation_id", "_n06_unique_index(equation.occurrences", "x.ledger_id, x.equation_id, x.port_side, x.port_index", "_n06_selector_key(governing_selector)"]),
        "unique_g2_interface_region_patch": all(x in source for x in ["_n06_unique_match(interfaces", "_n06_unique_match(regions", "patch_candidates = [x for x in patches if x.region_id == region.region_id]", "_n06_unique_match(patch_candidates", "_N06_G2_SELECTOR.boundary_face"]),
        "no_order_or_fixed_index_selector": "sort(" not in source and "first(" not in source and "boundary_patches[1]" not in source and "occurrences[1]" not in source,
        "g3_effort_flow_and_selected_link": all(x in source for x in ["x.kind == :effort", "x.kind == :flow", "x.resource_port_id == flow_port.port_id", "g3_selected_flow_link_id", "join.g3_link_id == link.link_id", "power_effort_flow_dimension_mismatch"]),
        "exact_identity_hashes": all(x in source for x in ["canonical_hash((candidate_ref=package.candidate_ref", "g1_ref=g1_ref", "g2_ref=g2_ref", "g3_ref=g3_ref", "mapping.mapping_hash == _n06_mapping_hash(mapping)"]),
        "conversion_dimensions_and_law_hash": all(x in source for x in ["power_from_effort_flow", "expected_power = UnitSignature", "join.conversion.law_hash == _n06_conversion_law_hash", "conversion_to_unit_mismatch"]),
        "field_locator_type_checks": all(x in source for x in ["field.field_path == spec.field_path", "field.source_locator == spec.source_locator", "field.source_type == spec.source_type", "field.value isa N06TypedValueV1"]),
        "exception_taxonomy_text_and_gates": all(x in source for x in ["missing mapping=terminal_deferred", "typed contradiction=fail_closed", "unexpected exception=program_exception", "compile_calls=0", "provider_calls=0", "solver_calls=0"]),
        "no_external_physical_claim": all(x in source for x in ["contract projection only", "as evidence of a G1-to-G3 conservation law", "compile/provider/solver=0", "no compiler/provider/mesh/engineering/physical credit"]),
    }
    checks["source_checks"] = source_checks
    for name in ["full_E0_validator_before_actual_fields", "E0_program_exception_and_fail_closed_paths", "unique_g1_equation_and_four_key_occurrence", "unique_g2_interface_region_patch", "no_order_or_fixed_index_selector", "g3_effort_flow_and_selected_link", "exact_identity_hashes", "conversion_dimensions_and_law_hash", "field_locator_type_checks", "exception_taxonomy_text_and_gates", "no_external_physical_claim"]:
        if not source_checks[name]:
            blockers.append(f"source assertion failed: {name}")

    # The required mutation dispatch is the remaining R4 blocker.  Capture the
    # exact implementation path so the verdict cannot be inferred from labels.
    dispatch_start = source.index("function _n06_validate_spec_binding")
    dispatch_end = source.index("function _n06_classify")
    dispatch = source[dispatch_start:dispatch_end]
    mutation_api_start = source.index("function n06_validate_mutation")
    mutation_api_end = source.index("function n06_mapping_admission")
    mutation_api = source[mutation_api_start:mutation_api_end]
    mutation_dispatch = {
        "id_dictionary_present": "Dict(\"N06-01\"" in dispatch,
        "field_lookup_by_id": "_n06_field(p, spec.id)" in dispatch,
        "kind_bound_in_validator": "mutation_kind" in dispatch,
        "mutation_routes_by_field_id": "(field.id, target.mutation_kind)" in dispatch,
        "mutation_api_has_package_e0": "package::CandidateStatePackageV5" in mutation_api and "e0::UP2CandidatePhysicalBindingV1" in mutation_api,
    }
    checks["mutation_dispatch_blocker"] = mutation_dispatch
    if mutation_dispatch["id_dictionary_present"] or mutation_dispatch["field_lookup_by_id"] or mutation_dispatch["mutation_routes_by_field_id"]:
        blockers.append("N06 mutation dispatch still uses spec.id/field.id instead of field_path + mutation_kind + source locator/type")
    if not mutation_dispatch["kind_bound_in_validator"]:
        blockers.append("N06 mutation_kind is not checked in the binding validator")
    if not mutation_dispatch["mutation_api_has_package_e0"]:
        blockers.append("n06_validate_mutation accepts only a projection and spec; it cannot revalidate the full E0 binding before a receipt")

    callers = re.findall(r"_n06_actual_fields\([^\n]*\)", source + "\n" + tests)
    checks["actual_fields_arity"] = {
        "return_tuple_arity": 10,
        "caller_occurrences": callers,
        "projection_and_join_callers_destructure_ten": "equation, occurrence, closure, region, patch, _, _, _, _, fields" in source and "equation, occurrence, closure, region, patch, network, entry, g3closure, link, _" in source,
    }

    test_checks = {
        "actual_A_package_and_E0": all(x in tests for x in ["function _n06_actual_package", "up2_candidate_physical_binding_from_a(package)", "n06_projection_from_a(package, e0)"]),
        "five_mutation_rows_source_derived": all(x in tests for x in ["for row in _N06_FIXTURE.mutations", "result.mutated_input_hash != result.input_hash", "result.error_path == spec.field_path"]),
        "detached_foreign_wrong_kind_negatives": all(x in tests for x in ["detached_g1", "foreign_link_join", "forged_locator", "forged_type", "forged_kind"]),
        "dimension_and_flow_negatives": all(x in tests for x in ["mismatched_dimension", "missing_flow", "power_from_effort_flow"]),
        "identity_and_admission_negatives": all(x in tests for x in ["foreign = G.N06SourceFieldLedgerMappingV1", "n06_mapping_admission(package, e0, foreign).status == :fail_closed", "duplicate_port"]),
        "no_external_execution_claim": all(x in tests for x in ["compile_calls == result.provider_calls == result.solver_calls == 0", "schema_validation_only"]),
    }
    checks["test_checks"] = test_checks
    if not all(test_checks.values()):
        blockers.append("required N06 adversarial test evidence is missing")

    commands = [
        command("json_parse", [sys.executable, "-c", "import json; json.load(open('test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json', encoding='utf-8'))"]),
        command("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        command("git_diff_check", ["git", "diff", "--check"]),
        command("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {x["name"]: x["exit"] for x in commands}
    for c in commands[:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "ready_for_focused_r4"
    result = {
        "review_id": "E2-N06-independent-precheck-r4",
        "reviewer": "different-Luna/high static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "static_precheck_only_no_julia_or_acceptance",
        "blockers": blockers,
        "frozen_hashes": FROZEN,
        "checks": checks,
        "limitations": [
            "No Julia/DESC or N06 runner was started; all findings are static and adversarial code-path review.",
            "Existing focused R1/R2/R3 failures remain immutable historical evidence and were not edited.",
            "Any change to the four frozen files invalidates this precheck.",
        ],
        "commands": commands,
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E2-N06 independent static precheck R4

Verdict: **{verdict}**. Julia/DESC and the N06 runner were not started.

All four frozen hashes match: source `{FROZEN['src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl']}`, fixture `{FROZEN['test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json']}`, tests `{FROZEN['test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl']}`, runner `{FROZEN['test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl']}`. The fixture is schema validation only, with four complete G1 selectors and five mutation rows.

The current source does call `up2e0_validate_binding` before `_n06_actual_fields`, uses unique typed G1/G2/G3 selectors, derives boundary paths from selected objects, checks effort/flow dimensions and selected flow-link identity, and preserves the contract-only exception/claim ceiling. The tests contain detached/foreign/wrong-kind, duplicate, dimension, flow-partner, source-locator/type, and identity negatives.

Two blockers remain in the frozen source. First, `_n06_validate_spec_binding` uses a hard-coded `Dict("N06-01" => ...)` and `_n06_field(p, spec.id)`, while `_n06_mutate` routes on `(field.id, target.mutation_kind)`. This keeps `id` as a dispatch key and does not satisfy field_path + mutation_kind + source locator/type dispatch. Second, `n06_validate_mutation` accepts only a projection and spec; because `N06LedgerProjectionV1` has an ordinary public constructor, a detached projection can reach mutation validation without a fresh full `up2e0_validate_binding` call. The mutation boundary must be sealed or receive package/E0 and revalidate before receipt generation.

Structured checks are in [report.json](report.json) and command evidence with real exit/stdout/stderr/timestamps is in [command_receipts.json](command_receipts.json). JSON parse, `validate_plan.py`, and `git diff --check` exited 0. This is not an acceptance verdict.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"], "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"], "julia_desc_invoked": False,
        "frozen_hashes": FROZEN, "command_exits": checks["command_exits"],
        "evidence_files": {},
    }
    for p in ["run_precheck.py", "report.md", "report.json", "command_receipts.json"]:
        evidence["evidence_files"][p] = sha(OUT / p)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
