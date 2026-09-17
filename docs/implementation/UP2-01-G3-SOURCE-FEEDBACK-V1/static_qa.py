from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from fractions import Fraction

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
FIXTURE = ROOT / "test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json"
TEST = ROOT / "test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl"
MANIFEST = ROOT / "docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/agent_local_r2/evidence_manifest.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    source = SRC.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    expected = {
        "schema_id": "GenomeV5/G3/G3SourceFeedbackLawV1",
        "source_id": "g3-source-v1-demo",
        "candidate_version": "v5",
        "feedback_layers": {"G1", "G2"},
        "authority_status": {"missing"},
    }
    actual = {
        "schema_id": "GenomeV5/G3/G3SourceFeedbackLawV1" if "G3SourceFeedbackLawV1" in source else "",
        "source_id": fixture["source_id"],
        "candidate_version": fixture["candidate_ref"]["version"],
        "feedback_layers": {x["layer"] for x in fixture["feedback_targets"]},
        "authority_status": {x["status"] for x in fixture["upstream_authority"]},
    }
    source_power = Fraction(120, 1)
    declared = {e["effect"]: Fraction(*e["coefficient"]) for e in fixture["ledger_entries"]}
    source_amount = source_power * declared["source"]
    field = -source_power * declared["field"]
    returned = -source_power * declared["return"]
    heat = -source_power * declared["heat"]
    ledger_residual = sum(source_power * value for value in declared.values())
    checks = {
        "json_parse": True,
        "schema_and_fixture": actual == expected,
        "declared_ledger_roles_complete": set(declared) == {"source", "field", "return", "heat"},
        "exact_energy_residual_zero": source_amount - field - returned - heat == 0,
        "exact_ledger_residual_zero": ledger_residual == 0,
        "numeric_values": (field, returned, heat) == (Fraction(90), Fraction(15), Fraction(15)),
        "typed_relation_api_present": all(token in source for token in ("G3SFConservativeSplitV1", "G3SFHeatRelationV1", "G3SFLedgerRelationV1")),
        "no_free_text_formula_fields": "energy_equation::String" not in source and "heat_equation::String" not in source and "equation::String" not in source,
        "edit_api_present": "g3_sf_edit_efficiency_v1" in source and "declaration_hash !=" in test,
        "hash_tamper_gate_present": "declaration_hash_mismatch" in source and "tampered" in test,
        "public_fault_seam_removed": "function g3_sf_admit_v1(x::Any; fault_seam" not in source and
        "_g3sf_admit_fault_seam_v1" in source,
        "public_fault_injection_rejected": "@test_throws MethodError G.g3_sf_admit_v1(declaration; fault_seam=:internal_validation_fault)" in test,
        "internal_fault_seam_test_present": "G._g3sf_admit_fault_seam_v1(declaration).status == :program_exception" in test and
        "_g3sf_admit_core_v1(x; inject_internal_fault=true)" in source,
        "efficiency_edit_closure_coverage": all(token in test for token in (
            "edited_value.return_power == 0", "edited_value.heat_power == 15",
            "edited_value.energy_residual == 0", "edited_value.ledger_residual == 0",
            "edited_coefficients == Dict(:source => 1 // 1, :field => -7 // 8",
        )),
        "authority_gap_api_present": "external_authority_gap" in source and "terminal_deferred" in source,
        "unattested_actual_gate_present": "unattested_authority" in source and "authority_status=:actual" in test,
        "classification_split_present": "program_exception" in source and "fail_closed" in source,
        "endpoint_role_closure_present": "endpoint_role_count_mismatch" in source and '(:source, :field, :return, :heat, :ledger)' in source,
        "duplicate_upstream_rejection_present": "duplicate_upstream_authority_layer" in source and "duplicate_upstream_authority_layer" in test,
        "duplicate_feedback_rejection_present": all(token in source and token in test for token in (
            "duplicate_feedback_target_id", "duplicate_or_ambiguous_feedback_target")),
        "duplicate_closure_rejection_present": "duplicate_ledger_closure_entry_id" in source and "duplicate_ledger_closure_entry_id" in test,
        "feedback_authority_pairing_present": "feedback_authority_mismatch" in source and "feedback_authority_mismatch:g1-field-residual" in test,
        "authority_ref_hash_pairing_present": "authority contract_ref and contract_hash must be paired" in source,
        "authority_source_material_fields_present": all(token in source for token in (
            "source_ref::Union{Nothing,QualifiedRefV1}", "source_bytes::Union{Nothing,Int}",
            "source_sha256::Union{Nothing,Digest256}")) and "source_ref=source_ref" in test,
        "authority_namespace_gate_present": all(token in source and token in test for token in (
            "authority_contract_namespace_mismatch", "authority_source_namespace_mismatch")),
        "authority_hash_source_binding_present": "authority_contract_hash_source_binding_mismatch" in source and "wrong-bound-hash" in test,
        "authority_half_pair_negative_present": test.count("@test_throws ArgumentError G.G3SFAuthorityV1") >= 2 and
            "actual_ref, nothing" in test and "nothing, actual_hash" in test,
        "authority_status_body_negative_present": "authority_status_body_mismatch" in source and
            "authority_status_body_mismatch:G1" in test,
        "no_julia_or_desc_invocation": all(x not in source.lower() for x in ("run(`julia", "subprocess", "desc run")),
        "test_fixture_is_candidate_owned": fixture["candidate_ref"]["id"].startswith("fusionconceptai://candidate/") and "candidate_ref" in test,
    }
    files = {p.relative_to(ROOT).as_posix(): sha256(p) for p in (SRC, FIXTURE, TEST, Path(__file__))}
    manifest_files = manifest.get("files_sha256", {})
    checks["manifest_hashes_match"] = all(manifest_files.get(k) == v for k, v in files.items() if k != Path(__file__).resolve().relative_to(ROOT).as_posix())
    result = {
        "record_kind": "UP2-01-G3-SOURCE-FEEDBACK-V1-static-QA",
        "command": r"D:\Users\Newman\anaconda3\python.exe docs/implementation/UP2-01-G3-SOURCE-FEEDBACK-V1/static_qa.py",
        "pid": os.getpid(),
        "exit_code": 0 if all(checks.values()) else 1,
        "checks": checks,
        "files_sha256": files,
        "status": "proposal",
        "review_pending": True,
        "accepted": False,
        "julia_run": False,
        "desc_run": False,
        "compiler_calls": 0,
        "provider_calls": 0,
        "mesh_calls": 0,
        "solver_calls": 0,
        "physical_evidence": False,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
