"""Static QA for the declared G1/G2/G3 R4 slice; never invokes Julia/DESC."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src/RuntimeV4/DeclaredG123DiffusionExecutionV1.jl"
FIXTURE = Path(__file__).with_name("fixture.json")
TEST = Path(__file__).with_name("focused_tests.jl")
FIXTURE_JL = Path(__file__).with_name("fixture.jl")
ORACLE = Path(__file__).with_name("independent_oracle.py")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SRC.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    test = TEST.read_text(encoding="utf-8")
    checks = {
        "schema_and_revision": fixture["schema"] in source and fixture["revision"] in source,
        "actual_declaration_types": all(t in source for t in ("G1DiffusionDeclarationV1", "G2MBDeclarationV1", "G3SFDeclarationV1", "VNextT0LocalTransportV1")),
        "exact_hash_binding": all(t in source for t in ("DeclaredG123HashSetV1", "vnext_t0_local_bundle_hash_recompute_v1", "recomputed_bundle == bundle.bundle_hash", "_dgd_g1_body", "_dgd_g2_body", "_dgd_g3_body", "bundle_body_hash_mismatch", "canonical_json(declaration)", "_vnl_t0_factory_result_bytes", "receipt.bytes.bytes == expected_receipt_bytes.bytes", "factory receipt source bytes mismatch", "declaration receipt source bytes mismatch", "factory receipt declaration bytes mismatch", "declaration receipt declaration bytes mismatch", "factory_result_hash == canonical_hash(receipt.factory_result)")),
        "expression_subset_closed": all(t in source for t in ("DGD_ALLOWED_U_EXPRESSIONS_V1", "DGD_ALLOWED_F_EXPRESSIONS_V1", "unsupported_expression_subset")),
        "g2_mesh_derived": all(t in source for t in ("dgd_local_mesh_v1", "g2mb_chart_map", "mesh_hash", "cells", "quadrature_points", "quadrature_weights", "execution_status", "y_z_topology")),
        "conservative_transfer": all(t in source for t in ("dgd_transfer_v1", "conservation_residual", "invalid_overlap", "overlap_fraction", "malformed_state_shape")),
        "typed_composition_and_g3_ledger": all(t in source for t in ("dgd_composition_admit_v1", "g3_sf_admit_v1", "g3_sf_evaluate_v1", "g2_admission_terminal_deferred", "g3_admission_terminal_deferred")),
        "sparse_bounded_solve": all(t in source for t in ("using SparseArrays", "sparse", "dgd_numerical_solve_v1", "singular_or_nonfinite_sparse_system", "_dgd_rhs_from_g2_faces", "source_values")),
        "separate_receipts": all(t in source for t in ("DGDCompileReceiptV1", "DGDTransferReceiptV1", "DGDCompositionReceiptV1", "DGDNumericalReceiptV1", "DGDAggregateReceiptV1")),
        "typed_public_fail_closed_boundary": all(t in source for t in ("dgd_execute_declared_v1", "_dgd_public_error_code", "_dgd_public_failure", "candidate_mismatch", ":fail_closed")),
        "legal_g2_mesh_status_only": fixture["g2_mesh_execution_status"] in {"declared", "not_executed"} and "execution_status=:executed" not in source and "execution_status=:executed" not in test,
        "no_formal_credit": all(t in source for t in ("screen_only", "formal_up_credit", "formal_r_credit", "accepted::Bool", "composition.status !== :ready", "DGDAggregateReceiptV1")) and fixture["positive"]["aggregate_status"] == "terminal_deferred" and fixture["positive"]["numerical_status"] == "ready",
        "admission_status_resolution_gate": fixture["positive"]["g2_admission_status"] == "terminal_deferred" and fixture["positive"]["g2_admission_resolution"] == "terminal_deferred" and fixture["positive"]["g3_admission_status"] == "proposal" and fixture["positive"]["g3_admission_resolution"] == "terminal_deferred" and all(t in source for t in ("g2a.status === :valid", "g2a.resolution === :resolved", "a.status === :proposal", "a.resolution === :resolved")),
        "zero_external_counters": all(t in source for t in ("provider_calls::Int", "mesh_calls::Int", "provider_calls=0", "mesh_calls=0")),
        "negative_gate_vectors": set(fixture["negative_gates"]) == {"candidate_mismatch", "body_hash_mismatch", "bundle_hash_mismatch", "unsupported_expression_subset", "missing_mesh_authority", "missing_feedback_authority", "invalid_overlap", "singular_sparse_system", "nonfinite_derived", "ledger_contradiction"} and fixture["negative_gates"]["unsupported_expression_subset"] == ["terminal_deferred", "unsupported_expression_subset"] and fixture["negative_gates"]["ledger_contradiction"] == ["fail_closed", "ledger_contradiction"],
        "positive_sensitivity_vectors": len(fixture["sensitivities"]) >= 4 and "g1_k_slope_edit" in fixture["sensitivities"],
        "independent_oracle_no_product_import": "import FusionConceptAI" not in ORACLE.read_text(encoding="utf-8"),
        "python_only_boundary": "julia" not in ORACLE.read_text(encoding="utf-8").lower() or "julia_or_desc_executed" in ORACLE.read_text(encoding="utf-8"),
        "focused_command_declared": "DeclaredG123DiffusionExecutionV1.jl" in test and "JULIA_OR_DESC_EXECUTED=false" in test,
        "focused_all_product_stages": all(t in test for t in ("dgd_compile_v1", "dgd_local_mesh_v1", "dgd_transfer_v1", "dgd_composition_admit_v1", "dgd_numerical_solve_v1", "dgd_execute_v1")),
        "focused_exact_negative_set": "expected_codes == Set" not in test and all(t in test for t in ("observed[", "observed == expected", "candidate_mismatch", "unsupported_expression_subset", "ledger_contradiction", "bundle_hash_mismatch", "dgd_admission_dispatch_v1", "dgd_numerical_solve_v1")),
        "all_ten_cases_dispatch": all(t in test for t in ("candidate_bad = dgd_execute_declared_v1", "body_bad = dgd_execute_declared_v1", "bundle_bad = dgd_execute_declared_v1", "bad_compile = dgd_compile_v1", "g2_admission = dgd_admission_dispatch_v1", "g3_admission = dgd_admission_dispatch_v1", "invalid = dgd_transfer_v1", "singular = dgd_numerical_solve_v1", "nonfinite = dgd_numerical_solve_v1", "ledger_bad = dgd_composition_admit_v1")),
    }
    files = {str(p.relative_to(ROOT)).replace("\\", "/"): sha256(p) for p in (SRC, FIXTURE, TEST, FIXTURE_JL, ORACLE, Path(__file__))}
    result = {"record_kind": "DeclaredG123DiffusionExecutionV1-static-QA", "checks": checks,
              "files_sha256": files, "exit_code": 0 if all(checks.values()) else 1,
              "julia_executed": False, "desc_executed": False, "provider_calls": 0,
              "mesh_calls": 0, "formal_physical_evidence": False, "accepted": False,
              "claim_ceiling": "screen_only"}
    print(json.dumps(result, indent=2, sort_keys=True))
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
