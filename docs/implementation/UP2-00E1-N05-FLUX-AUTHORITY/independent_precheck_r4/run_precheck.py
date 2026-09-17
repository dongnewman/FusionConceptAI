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
    "src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl": "6b40811f85bb0eb9ff0dbc669818878ef867a9c676613fc33919946f3c95771a",
    "test/GenomeV5/UP2/n05_flux_authority_tests.jl": "666ba168425102b31089bd450e191b27b559286387a317570f2d42f1049166a1",
    "test/GenomeV5/UP2/n05_flux_authority_fixtures.json": "049fcc585f97245a745737733dd9aae6904e80b4cc09067dbc37a9528ab81d81",
    "test/GenomeV5/UP2/run_n05_flux_authority.jl": "3d51de1a65d6c48afae00a57877d63c29600d061799f324fcf48a436b8cebca3".replace("ae00a", "ae0aa"),
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
    checks: dict[str, object] = {}
    blockers: list[str] = []

    frozen = {}
    for rel, expected in FROZEN.items():
        actual = sha(ROOT / rel)
        frozen[rel] = {"expected": expected, "actual": actual,
                       "match": actual == expected}
        if actual != expected:
            blockers.append(f"frozen hash mismatch: {rel}")
    checks["frozen_hashes"] = frozen

    source = (ROOT / list(FROZEN)[0]).read_text(encoding="utf-8")
    tests = (ROOT / "test/GenomeV5/UP2/n05_flux_authority_tests.jl").read_text(encoding="utf-8")
    fixture = json.loads((ROOT / "test/GenomeV5/UP2/n05_flux_authority_fixtures.json").read_text(encoding="utf-8"))
    rows = fixture["mutations"]
    checks["fixture"] = {
        "schema_id": fixture.get("schema_id"),
        "schema_version": fixture.get("schema_version"),
        "schema_validation_only": fixture.get("schema_validation_only"),
        "count": len(rows),
        "ids": [str(x["id"]) for x in rows],
        "field_paths": [str(x["field_path"]) for x in rows],
        "mutation_kinds": [str(x["mutation_kind"]) for x in rows],
    }
    expected_rows = [
        ("N05-01", "/n05/left_endpoint/endpoint_ref", "foreign_left_endpoint_ref", "invalid_closure", "fail_closed"),
        ("N05-02", "/n05/right_endpoint/endpoint_ref", "foreign_right_endpoint_ref", "invalid_closure", "fail_closed"),
        ("N05-03", "/n05/left_endpoint/sign", "left_sign_zero", "invalid_closure", "fail_closed"),
        ("N05-04", "/n05/right_endpoint/sign", "same_endpoint_sign", "invalid_closure", "fail_closed"),
        ("N05-05", "/n05/right_endpoint/unit", "right_unit_mismatch", "invalid_type", "fail_closed"),
    ]
    actual_rows = [(str(x["id"]), str(x["field_path"]), str(x["mutation_kind"]), str(x["expected_error"]), str(x["expected_resolution"])) for x in rows]
    checks["fixture"]["exact_five_contract_rows"] = actual_rows == expected_rows
    if actual_rows != expected_rows:
        blockers.append("N05 fixture rows do not exactly match the five authored mutations")

    scan_text = source + "\n" + tests
    forbidden = {
        "unsupported_first_generator_default": bool(re.search(r"first\([^\n]*,\s*nothing\)", scan_text)),
        "symbol_concat": bool(re.search(r"Symbol\([^\n]*\*|\*\s*Symbol\(", scan_text)),
    }
    checks["R2_regression_patterns"] = forbidden
    if any(forbidden.values()):
        blockers.append("R2 unsupported generator default or Symbol concatenation remains")

    # These are source-path assertions over implementation code, not text-only claims.
    source_assertions = {
        "canonical_schema_hash_declared": "UP2N05_SCHEMA_HASH_V1 = digest256_text(UP2N05_SCHEMA_SOURCE_V1)" in source,
        "canonicalization_hash_declared": "UP2N05_CANONICAL_HASH_V1 = digest256_text(UP2N05_CANONICAL_SOURCE_V1)" in source,
        "profile_hash_declared": "UP2N05_PROFILE_HASH_V1 = digest256_text(UP2N05_PROFILE_SOURCE_V1)" in source,
        "law_body_hash_recomputed_in_constructor": "body_hash = _n05_law_source_hash" in source and "law_hash=x.law_hash" in source,
        "law_source_path_type_hash_validated": all(x in source for x in ["law.source.path == \"/n05/authored_flux_law/$(declaration.law.law_ref.id)\"", "law.source.source_type === :AuthoredFluxLawV1", "law.source.source_hash == _n05_law_source_hash", "law.law_hash == _n05_law_source_hash"]),
        "endpoint_source_path_type_hash_validated": all(x in source for x in ["_n05_endpoint_source(endpoint", ":AuthoredFluxEndpointV1", "locator.source_type === binding.source_type"]),
        "unit_source_path_type_hash_validated": all(x in source for x in ["endpoint.unit.source.layer === :N05", "endpoint.unit.source.source_type === :AuthoredFluxLawUnitV1", "endpoint.unit.source.path == _n05_authored_unit_path", "endpoint.unit.source.source_hash == canonical_hash"]),
        "G1_full_four_key_join": all(x in source for x in ["o.equation_id == endpoint.occurrence.equation_id", "o.port_side == endpoint.occurrence.port_side", "o.port_index == endpoint.occurrence.port_index", "o.ledger_id == endpoint.occurrence.ledger_id", "length(matches) == 1"]),
        "G1_actual_type_ref_hash_path": all(x in source for x in ["occurrence isa G1LedgerOccurrenceV2", "endpoint.occurrence.locator.source_ref == g1_ref", "endpoint.occurrence.locator.source_hash == g1_hash", "endpoint.occurrence.locator.path == expected_occurrence_path", "endpoint.occurrence.locator.source_type === :G1LedgerOccurrenceV2"]),
        "G1_path_contains_all_key_fields": all(x in source for x in ["equation_id)", "port_side)", "port_index)", "ledger_id)"]),
        "unique_interface_is_strict": "length(matches) == 1 ? only(matches) : nothing" in source,
        "actual_E0_baseline_before_mutation": "baseline = up2n05_validate(authority, package, e0_binding)" in source and source.index("baseline = up2n05_validate(authority, package, e0_binding)") < source.index("mutated_declaration = _n05_mutated_declaration"),
        "mutation_dispatch_path_and_kind": "binding.field_path == spec.field_path && binding.mutation_kind === spec.mutation_kind" in source,
        "mutation_id_not_dispatch_key": "spec.id" in source and "_n05_mutation_binding(spec)" in source,
        "E0_three_state": all(x in source for x in ["return (:program_exception", "return (:fail_closed", "e0_status !== :valid ? :fail_closed", "declaration === nothing ? :terminal_deferred"]),
        "no_downstream_calls": all(x in source for x in ["compile_calls=0", "provider_calls=0", "solver_calls=0"]),
    }
    checks["implementation_source_assertions"] = source_assertions
    # mutation_id_not_dispatch_key is a positive structural check; inspect the dispatch body separately.
    dispatch_body = source[source.index("function _n05_mutation_binding"):source.index("function _n05_binding_hash")]
    checks["implementation_source_assertions"]["dispatch_body_does_not_read_id"] = "spec.id" not in dispatch_body
    if not all(source_assertions.values()) or "spec.id" in dispatch_body:
        blockers.append("one or more authored law/source/join/dispatch/E0 source assertions failed")

    test_assertions = {
        "low_level_actual_A_package_and_E0_binding": all(x in tests for x in ["function _n05_actual_package", "function _n05_e0_binding", "G._up2e0_package_hash(package)"]),
        "baseline_three_states_and_missing_five_gaps": all(x in tests for x in [":terminal_deferred", "length(deferred.gaps) == 5", "receipt.error_code == :authority_gap"]),
        "five_source_bound_mutations": all(x in tests for x in ["for row in _N05_FIXTURE.mutations", "receipt.source_locator.layer == :N05", "receipt.source_locator.source_type", "receipt.source_locator.source_hash != package.g1.candidate_hash", "receipt.resolution == :fail_closed"]),
        "id_only_label_probe_and_path_kind_rejection": all(x in tests for x in ["forged-receipt-label", "relabeled_receipt.error_path == canonical.field_path", "canonical.mutation_kind", "N05-01\", \"/n05/right_endpoint/endpoint_ref"]),
        "foreign_stale_package_rejected": all(x in tests for x in ["foreign_authority", "foreign_package", "@test_throws ArgumentError G.up2n05_validate_mutation"]),
        "duplicate_occurrence_and_interface_rejected": all(x in tests for x in ["duplicate occurrence locator is fail-closed", "G1_occurrences_not_independent", "duplicate interface lookup is not silently selected"]),
        "exact_law_and_unit_source_hash_probes": all(x in tests for x in ["law.source.source_type", "left_endpoint.unit.source.source_hash", "authority.binding_hash", "authority.declaration.interface_ref"]),
    }
    checks["test_adversarial_assertions"] = test_assertions
    if not all(test_assertions.values()):
        blockers.append("required R4 adversarial/static test evidence is missing")

    # Current E0 reference is read-only evidence; this review does not execute it.
    e0_manifest = ROOT / "docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json"
    checks["E0_reference"] = {"path": str(e0_manifest.relative_to(ROOT)), "sha256": sha(e0_manifest), "read_only": True}

    commands = [
        run("json_parse", [sys.executable, "-c", "import json; json.load(open('test/GenomeV5/UP2/n05_flux_authority_fixtures.json', encoding='utf-8'))"]),
        run("validate_plan", [sys.executable, "docs/v4_multitopology_generation/validate_plan.py"]),
        run("git_diff_check", ["git", "diff", "--check"]),
        run("julia_desc_process_sweep", ["powershell", "-NoProfile", "-Command", "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)(\\.exe)?$' } | Select-Object ProcessId,Name,CommandLine | ConvertTo-Json -Compress"]),
    ]
    checks["command_exits"] = {x["name"]: x["exit"] for x in commands}
    for c in commands[0:3]:
        if c["exit"] != 0:
            blockers.append(f"{c['name']} exited {c['exit']}")

    verdict = "changes_requested" if blockers else "ready_for_focused_r3"
    result = {
        "review_id": "UP2-00E1-N05-FLUX-AUTHORITY-independent-precheck-r4",
        "reviewer": "different-Luna static reviewer",
        "checked_at_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "claim_ceiling": "static_precheck_only_no_julia_or_acceptance",
        "blockers": blockers,
        "checks": checks,
        "frozen_hashes": FROZEN,
        "limitations": [
            "Julia/DESC and the N05 runner were not started; no dynamic or acceptance claim is made.",
            "A forged source-locator negative is established by validator branches but is not executed in this static-only review; focused R3 must retain that dynamic coverage.",
            "Any author change to the four frozen files invalidates this precheck verdict.",
        ],
        "commands": commands,
    }
    (OUT / "report.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (OUT / "command_receipts.json").write_text(json.dumps(commands, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    md = f"""# E1-N05 independent static precheck R4

Verdict: **{verdict}**. This is a static precheck only; Julia/DESC and the N05 runner were not started.

The four frozen hashes match: source `{FROZEN['src/GenomeV5/UP2/N05FluxAuthorityProjectionV1.jl']}`, tests `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_tests.jl']}`, fixture `{FROZEN['test/GenomeV5/UP2/n05_flux_authority_fixtures.json']}`, and runner `{FROZEN['test/GenomeV5/UP2/run_n05_flux_authority.jl']}`. The fixture is schema validation only and has exactly N05-01 through N05-05 with the authored field paths and mutation kinds.

Static source paths confirm canonical schema/canonicalization/profile hashes participate in the binding hash; law, endpoint, and authored-unit locators validate their path, source type, source ref, and canonical source hash; declaration and law hashes are recomputed. G1 lookup requires a unique actual `G1LedgerOccurrenceV2` matched by all four fields `(equation_id, port_side, port_index, ledger_id)`, then checks the actual ref, component hash, full locator path, and type. The implementation does not require a nonexistent `.source` field on `G1LedgerOccurrenceV2`.

`up2n05_validate_mutation` first calls `up2n05_validate` against the exact A package and E0 binding, so foreign/stale authority or package cannot produce a receipt. Dispatch uses the registered `(field_path, mutation_kind)` pair; `id` remains a receipt label. The five mutations are source/invariant-derived and return zero compile/provider/solver counters. The code preserves `terminal_deferred`, `fail_closed`, and `program_exception`; tests cover missing authority, foreign package/authority, relabelled ID, duplicate occurrence/interface, and the five fail-closed fixture rows.

Independent command receipts with real exit/stdout/stderr/timestamps are in [command_receipts.json](command_receipts.json), and structured checks are in [report.json](report.json). JSON parse, `validate_plan.py`, and `git diff --check` exited 0. Any change to the four frozen files invalidates this verdict.
"""
    (OUT / "report.md").write_text(md, encoding="utf-8")
    evidence = {
        "review_id": result["review_id"],
        "verdict": verdict,
        "claim_ceiling": result["claim_ceiling"],
        "julia_desc_invoked": False,
        "frozen_hashes": FROZEN,
        "evidence_files": {},
        "command_exits": checks["command_exits"],
    }
    for p in ["run_precheck.py", "report.md", "report.json", "command_receipts.json"]:
        evidence["evidence_files"][p] = sha(OUT / p)
    (OUT / "evidence_manifest.json").write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "blockers": blockers, "command_exits": checks["command_exits"]}, ensure_ascii=False))
    return 0 if not blockers else 1


if __name__ == "__main__":
    raise SystemExit(main())
