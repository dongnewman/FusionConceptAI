"""Static QA plus independent oracle for UP2-EXEC-01.

This command is intentionally Python-only.  It never launches Julia, DESC,
providers, mesh builders, or a solver.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "test" / "RuntimeV4" / "UP2ExecutableDiffusionTransferComposition"
SOURCE = ROOT / "src" / "RuntimeV4" / "ExecutableDiffusionTransferCompositionV1.jl"
TEST = BASE / "up2_executable_diffusion_transfer_composition_v1_tests.jl"
FIXTURE = BASE / "up2_executable_diffusion_transfer_composition_v1_fixture.json"
ORACLE = BASE / "up2_executable_diffusion_transfer_composition_v1_oracle.py"

sys.path.insert(0, str(BASE))
import up2_executable_diffusion_transfer_composition_v1_oracle as oracle  # noqa: E402


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    oracle_result = oracle.validate_fixture(fixture)

    required_source = (
        "ExecutableDiffusionTransferCompositionV1", "ExecutableTopologyIdentityV1",
        "ExecutableTopologyTransferV1", "ExecutableDiffusionInputsV1",
        "ExecutableDiffusionEquationUnitsV1",
        "ExecutableTypedPortV1", "ExecutableCompositionPlanV1",
        "ExecutableSourceDeclarationV1", "ExecutableCaseBindingV1",
        "ExecutableDiffusionCaseV1", "ExecutableTransferReceiptV1",
        "ExecutableAccountKeyV1", "ExecutableAccountEffectV1",
        "assemble_variable_coefficient_diffusion", "solve_joint_linear_screen",
        "validate_executable_case_binding", "validate_executable_topology_identity",
        "validate_executable_transfer", "validate_executable_composition",
        "validate_diffusion_equation_units", "apply_old_to_new_state",
        "binding_digest", "source_declarations", "semantic_digest", "receipt_hash",
        "conservation_residual", "equation_unit_mismatch", "nonfinite_derived",
        "state_semantics", ":pre_transfer", ":expected_post_transfer",
        "declared_target_state", "transfer_state_mismatch", "ExecutableAccountEffectV1",
        ":coefficient", "expected_source", "ku.exponents[1] == 2",
        "duplicate_producer", "unit_mismatch", "missing_closure",
        "invalid_overlap", "singular_matrix", ":fail_closed",
        ":terminal_deferred", ":numerical_fail", ":manufactured_numerical_screen",
        ":screen_only", "provider_call_count", "mesh_call_count",
        "solver_invocation_count", "assembly_hash", "k_faces", "source", "boundary",
        "candidate_ref", "mission_ref", "scenario_ref", "old", "new", "overlap",
        "initial_state", "transfer_receipt_hash", "k_unit", "source_unit", "boundary_unit",
        "topology.semantic_digest == transfer.new.semantic_digest",
        "transfer_admission = validate_executable_transfer(transfer)",
        "composition_admission = validate_executable_composition(plan)",
        "transfer admission rejected", "composition admission rejected",
        "Typed terminal constructor", "new(old, new_topology",
    )
    missing_source = [token for token in required_source if token not in source]
    assert not missing_source, f"missing required source tokens: {missing_source}"
    assert "include(" not in source and "using FusionConceptAI" not in source
    assert not re.search(r"\b(provider|mesh|DESC)\s*\(", source, re.I)
    assert "default_operator_registry" not in source
    assert "topology.topology_ref == transfer.new.topology_ref" not in source
    assert "\n        ExecutableTopologyTransferV1(old, new_topology," not in source
    assert "accepted=false" not in source.lower()  # accepted is a field, not a claim in source
    required_test = (
        "using Test", "using JSON3", "include(EDC_SOURCE)", "real variable-coefficient stencil",
        "constructor recursion guard", "transfer_probe",
        "typed case binding, source declarations, and digest receipt",
        "full topology identity and explicit old-to-new transfer",
        "base.assembly_hash", "label erasure and component permutation invariance",
        "duplicate_producer", "unit_mismatch", "missing_closure", "invalid_overlap",
        "singular_matrix", "nonfinite_derived", "binding_malformed", "equation_unit_mismatch",
        "observed_negative", "expected_negative", "pairs(fixture.negative_expectations)",
        "Set(keys(observed_negative))", "observed_negative == expected_negative",
        "permuted_outcome", "renamed_outcome.receipt.result_hash",
        "@test_throws ArgumentError assemble_variable_coefficient_diffusion",
        "provider_call_count == 0", "mesh_call_count == 0",
        "accepted === false", "manufactured_numerical_screen", "screen_only",
    )
    missing_test = [token for token in required_test if token not in test]
    assert not missing_test, f"missing focused test seams: {missing_test}"
    assert "executed_negative_vectors" not in test
    assert test.count("@test_throws ArgumentError assemble_variable_coefficient_diffusion") >= 4

    assert fixture["schema"].endswith("executable-diffusion-transfer-composition-v1")
    assert fixture["claim_ceiling"] == "manufactured_numerical_screen"
    assert fixture["evidence_scope"] == "screen_only"
    assert fixture["accepted"] is False
    assert fixture["execution"] == {
        "provider_calls": 0, "mesh_calls": 0,
        "desc_executed": False, "julia_executed": False,
    }
    assert fixture["invariance"]["assembly_hash_drivers"] == ["K", "source", "boundary"]
    assert fixture["topology"]["old_state_semantics"] == "pre_transfer"
    assert fixture["topology"]["new_state_semantics"] == "expected_post_transfer"
    assert set(fixture["negative_expectations"]) == {
        "binding_malformed", "binding_mismatch", "topology_identity_mismatch",
        "equation_unit_mismatch", "duplicate_producer", "unit_mismatch",
        "missing_closure", "invalid_overlap", "singular_matrix", "nonfinite_derived",
    }
    for vector in fixture["negative_expectations"]:
        assert vector in test, f"focused product test omits fixture vector: {vector}"
    assert test.count("execute_executable_diffusion_screen") >= 10
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    print(json.dumps({
        "schema": "ExecutableDiffusionTransferCompositionStaticQAV1",
        "status": "pass", "julia_executed": False, "desc_executed": False,
        "provider_calls": 0, "mesh_calls": 0, "solver_calls": 0,
        "oracle": oracle_result,
        "source_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
