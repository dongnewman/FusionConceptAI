"""Static QA for the declared G1/G2/G3 R21 slice; never invokes Julia/DESC."""
from __future__ import annotations

import hashlib
import json
import re
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
    unqualified_dgd_calls = [name for name in re.findall(r"(?<![\w.])(dgd_[A-Za-z0-9_]+)\s*\(", test)
                             if name not in {"dgd_fixture_numeric_v1", "dgd_fixture_negative_gates_v1"}]
    runtime_type_names = (
        "DGDLocalMeshV1", "DeclaredG123InputV1", "DGD_STATUSES_V1", "DGD_CLAIM_CEILING_V1",
        "DeclaredG123HashSetV1", "DGDCompileReceiptV1", "DGDTransferReceiptV1",
        "DGDCompositionReceiptV1", "DGDNumericalReceiptV1", "DGDAggregateReceiptV1")
    unqualified_runtime_names = [name for name in runtime_type_names
                                 if re.search(rf"(?<![\w.]){name}\b", test)]
    external_g1_g3_vnext_names = set(re.findall(
        r"\b(?:G1|G3|VNext)[A-Z][A-Za-z0-9_]*|\b(?:g1|g3|vnext)_[A-Za-z0-9_]+", test))
    allowed_fixture_external_names = {
        "G3SourceFeedbackLawV1", "g3_admission", "vnext_declaration_transport_local_v1",
        "vnext_declaration_transport_local_v1_tests"}
    unqualified_g1_g3_vnext = [name for name in external_g1_g3_vnext_names
                               if name not in allowed_fixture_external_names and
                               re.search(rf"(?<![\w.]){name}\b", test)]
    checks = {
        "schema_and_revision": fixture["schema"] in source and fixture["revision"] in source,
        "actual_declaration_types": all(t in source for t in ("G1DiffusionDeclarationV1", "G2MBDeclarationV1", "G3SFDeclarationV1", "VNextT0LocalTransportV1")),
        "exact_hash_binding": all(t in source for t in ("DeclaredG123HashSetV1", "vnext_t0_local_bundle_hash_recompute_v1", "recomputed_bundle == bundle.bundle_hash", "_dgd_g1_body", "_dgd_g2_body", "_dgd_g3_body", "bundle_body_hash_mismatch", "canonical_json(declaration)", "_vnl_t0_factory_result_bytes", "receipt.bytes.bytes == expected_receipt_bytes.bytes", "factory receipt source bytes mismatch", "declaration receipt source bytes mismatch", "factory receipt declaration bytes mismatch", "declaration receipt declaration bytes mismatch", "factory_result_hash == canonical_hash(receipt.factory_result)")),
        "dgd_semantic_method_coverage": all(t in source for t in ("semantic_view(x::DeclaredG123HashSetV1)", "canonical_json(x::DeclaredG123HashSetV1)", "semantic_view(x::DeclaredG123InputV1)", "semantic_view(x::DGDCompileReceiptV1)", "semantic_view(x::DGDLocalMeshV1)", "semantic_view(x::DGDTransferReceiptV1)", "semantic_view(x::DGDCompositionReceiptV1)", "semantic_view(x::DGDNumericalReceiptV1)", "semantic_view(x::DGDAggregateReceiptV1)", "canonical_json(x::DGDAggregateReceiptV1)")),
        "expression_subset_closed": all(t in source for t in ("DGD_ALLOWED_U_EXPRESSIONS_V1", "DGD_ALLOWED_F_EXPRESSIONS_V1", "unsupported_expression_subset")),
        "g2_mesh_derived": all(t in source for t in ("dgd_local_mesh_v1", "g2mb_chart_map", "mesh_hash", "cells", "quadrature_points", "quadrature_weights", "execution_status", "y_z_topology")),
        "conservative_transfer": all(t in source for t in ("dgd_transfer_v1", "conservation_residual", "invalid_overlap", "overlap_fraction", "malformed_state_shape")),
        "invalid_overlap_product_dispatch": fixture["negative_dispatch"]["invalid_overlap"] == {"entry": "dgd_execute_v1", "overlap": [3.0, 3.0]} and all(t in test for t in ("invalid_execution = _DGD.dgd_execute_v1", "overlap=(3.0, 3.0)", "invalid = invalid_execution.transfer", "invalid.code === :invalid_overlap")),
        "typed_composition_and_g3_ledger": all(t in source for t in ("dgd_composition_admit_v1", "g3_sf_admit_v1", "g3_sf_evaluate_v1", "g2_admission_terminal_deferred", "g3_admission_terminal_deferred")),
        "sparse_bounded_solve": all(t in source for t in ("using SparseArrays", "sparse", "dgd_numerical_solve_v1", "singular_or_nonfinite_sparse_system", "_dgd_rhs_from_g2_faces", "source_values")),
        "k_scalar_evaluation_guard": fixture["positive"]["k_evaluation_api"] == "diagonal_matrix_tuple_scalar_extraction" and all(t in source for t in ("_dgd_k_scalar_sample_v1", "g1_diffusion_k_eval(k, p1)", "g1_diffusion_k_eval(k, pm)", "g1_diffusion_k_eval(k, p2)", ":non_scalar_or_nonfinite_k_evaluation")) and "Float64(kval[1][1])" not in source,
        "nonfinite_typed_failure_dispatch": fixture["negative_dispatch"]["nonfinite_derived"] == {"entry": "dgd_numerical_solve_v1", "hash_body": "spacing_status=nonfinite"} and all(t in source for t in ("spacing_status=:nonfinite", "mesh_hash=mesh.mesh_hash", ":numerical_fail", ":singular_or_nonfinite_sparse_system")) and all(t in test for t in ("nonfinite_mesh", "nonfinite = _DGD.dgd_numerical_solve_v1", "nonfinite.status", "nonfinite.code")),
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
        "external_symbol_namespace": "admission = _DGD.vnext_declaration_transport_local_v1" in test and "admission = vnext_declaration_transport_local_v1" not in test and "isdefined(_DGD, :vnext_declaration_transport_local_v1)" in test and test.count("VNextDeclarationTransportLocalV1.jl") == 0 and test.index("vnext_declaration_transport_local_v1_tests.jl") < test.index("DeclaredG123DiffusionExecutionV1.jl"),
        "focused_all_product_stages": all(t in test for t in ("dgd_compile_v1", "dgd_local_mesh_v1", "dgd_transfer_v1", "dgd_composition_admit_v1", "dgd_numerical_solve_v1", "dgd_execute_v1")),
        "focused_fixture_numeric_comparisons": all(t in test for t in ("_dgd_numeric_close(transfer.new_state, spec.transferred_state)", "_dgd_numeric_close(transfer.conservation_residual, spec.conservation_residual)", "_dgd_numeric_close(numerical.matrix, spec.matrix)", "_dgd_numeric_close(numerical.rhs, spec.rhs)", "_dgd_numeric_close(numerical.solution, spec.solution)", "_dgd_numeric_close(numerical.residual_norm, spec.residual_norm;", "_dgd_numeric_close(aggregate.numerical.matrix, spec.matrix)")),
        "residual_fixture_binding": fixture["positive"]["residual_norm"] > 0.0 and fixture["positive"]["residual_tolerance"] == 1e-13 and all(t in test for t in ("spec.residual_norm > 0.0", "spec.residual_tolerance <= 1.0e-13", "atol=spec.residual_tolerance")) and "residual_norm=8.005932084973442e-16" in FIXTURE_JL.read_text(encoding="utf-8"),
        "candidate_metadata_binding": fixture["candidate_ref"] == "local://candidate/up1-04a" and all(t in test for t in ("spec.candidate == _T0L_CANDIDATE.id", "actual.input.candidate_ref == _T0L_CANDIDATE", "actual.bundle.candidate_ref == _T0L_CANDIDATE", "actual.bundle.candidate_ref.id == spec.candidate", "compile.candidate_ref == _T0L_CANDIDATE", "aggregate.candidate_ref == _T0L_CANDIDATE")),
        "k_fixture_metadata_guard": "spec.k_evaluation_api === :diagonal_matrix_tuple_scalar_extraction" in test and fixture["positive"]["k_evaluation_api"] == "diagonal_matrix_tuple_scalar_extraction",
        "qualified_runtime_calls": not unqualified_dgd_calls and "_DGD.dgd_input_v1" in test and "_DGD.dgd_execute_declared_v1" in test,
        "qualified_runtime_types_and_constants": not unqualified_runtime_names and all(
            (f"_DGD.{name}" in test) or (f"struct {name}" in source)
            for name in runtime_type_names),
        "qualified_g1_g3_vnext_symbols": not unqualified_g1_g3_vnext and all(
            (f"_DGD.{name}" in test) or (name in allowed_fixture_external_names)
            for name in external_g1_g3_vnext_names),
        "focused_exact_negative_set": "expected_codes == Set" not in test and all(t in test for t in ("observed[", "observed == expected", "candidate_mismatch", "unsupported_expression_subset", "ledger_contradiction", "bundle_hash_mismatch", "dgd_admission_dispatch_v1", "dgd_numerical_solve_v1")),
        "all_ten_cases_dispatch": all(t in test for t in ("candidate_bad = _DGD.dgd_execute_declared_v1", "body_bad = _DGD.dgd_execute_declared_v1", "bundle_bad = _DGD.dgd_execute_declared_v1", "bad_compile = _DGD.dgd_compile_v1", "g2_admission = _DGD.dgd_admission_dispatch_v1", "g3_admission = _DGD.dgd_admission_dispatch_v1", "invalid_execution = _DGD.dgd_execute_v1", "singular = _DGD.dgd_numerical_solve_v1", "nonfinite = _DGD.dgd_numerical_solve_v1", "ledger_bad = _DGD.dgd_composition_admit_v1")),
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
