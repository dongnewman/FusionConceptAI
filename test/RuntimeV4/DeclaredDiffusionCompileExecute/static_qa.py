"""Read-only static QA for the DCCE V1 additive slice."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "src/RuntimeV4/DeclaredDiffusionCompileExecuteV1.jl"
SPATIAL = ROOT / "src/RuntimeV4/DeclaredSpatialCompositionExecutionV1.jl"
FIXTURE = Path(__file__).with_name("fixture.json")
TEST = Path(__file__).with_name("focused_tests.jl")
ORACLE = Path(__file__).with_name("independent_oracle.py")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SRC.read_text(encoding="utf-8")
    spatial = SPATIAL.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    test = TEST.read_text(encoding="utf-8")
    oracle = ORACLE.read_text(encoding="utf-8")
    checks = {
        "schema_revision": fixture["schema"] in source and fixture["revision"] in source,
        "reuses_dgd_and_dsc": all(name in source for name in (
            "dgd_input_v1", "dgd_compile_v1", "dgd_composition_admit_v1",
            "DeclaredG123InputV1", "DeclaredG123HashSetV1",
            "DeclaredSpatialCaseV1", "auto_typed_port_edges",
            "measure_overlap_transfer", "assemble_declared_spatial_fv",
            "_dcce_solve_with_one_refinement")),
        "typed_lowering": all(name in source for name in (
            "DCCETypedLoweringV1", "dcce_typed_lower_v1", "typed_lowering_ready",
            "DCCE_EXPRESSION_SUBSET_V1", "G1DiffusionDiagonalAffineKFieldV1",
            "dimension", "field_count", "temporal", "coefficient_kind")),
        "separate_phases": all(name in source for name in (
            "compile::Any", "lowering::Any", "composition::Any", "numerical::Any",
            "aggregate::Any", "DCCEOutcomeV1")),
        "separate_dgd_fv_lanes": all(name in source for name in (
            "dgd_numerical_solve_v1", "dgd_transfer", "dgd=dgd_numerical",
            "fv_numerical", "must never be placed in one receipt")),
        "focused_fv_numeric_checks": all(name in test for name in (
            "expected_fv_matrix", "expected_fv_rhs", "expected_fv_solution",
            "out.composition.transfer.transfer.new_state", "conservation_residual",
            "out.composition.semantic_hash")),
        "current_source_fixture_bootstrap": all(name in test for name in (
            "_thermal_source_case(candidate_directory)", "actual.t0.transport",
            "actual.built.g1.declaration", "actual.built.g2.declaration",
            "actual.built.g3.declaration")) and
            "vnext_declaration_transport_local_v1_tests.jl" not in test,
        "transient_scalar_real_system": all(name in source for name in (
            "diagonal_affine_backward_euler", "declared_spatial_backward_euler_system",
            "time_step", "fv_matrix", "fv_rhs", "time_capacity_typed_absent",
            "unsupported_time_mass_units", "mass.source_ref == input.g1.source_ref")) and all(name in spatial for name in (
            "time_interval::Union{Nothing,Tuple{Float64,Float64}}",
            "mass[i] / dt", "mass[i] * state[i] / dt", "time_mass::Union",
            "source .* cell_width", "expected_source_ref=nothing",
            "time_mass_source_binding_absent", "time_mass_source_mismatch")) and all(name in test for name in (
            "single-step transient scalar diffusion", "bad_interval",
            "bad_history", "missing_capacity", "time_step.mass",
            "time_step.history", "mass_capacity", "wrong_source",
            "unbound_mass")),
        "multifield_block_system": all(name in source for name in (
            "component_fields", "component_boundaries", "component_old_states",
            "assemble_declared_spatial_multifield_fv",
            "declared_spatial_multifield_backward_euler_system",
            "diagonal_affine_multifield_backward_euler",
            "multifield_coupling_invalid", "coupling_gain=field_edge.producer.magnitude")) and all(name in spatial for name in (
            "component_fields::Tuple", "component_boundaries::Tuple",
            "component_old_states::Tuple", "left_component", "right_component",
            "DeclaredSpatialCouplingV1",
            "multifield_finite_volume_assembled", "coefficient*cell_width",
            "multifield_backward_euler_assembled")) and all(name in test for name in (
            "coupled two-field block diffusion", "unseen-left", "unseen-right",
            "out.numerical.fv.matrix", "oracle_rhs", "residual_at(v)", "bad_binding",
            "component_transfers")) and fixture["multifield_boundary"]["status"] == "implemented_unexecuted",
        "oracle_fv_numeric_checks": all(name in oracle for name in (
            "spatial_fv", "spatial_holdout", "transfer_new_state",
            "fv_matrix", "fv_solution", "fv_residual")),
        "hash_receipts": all(name in source for name in (
            "DCCEHashReceiptV1", "source_hashes", "declaration_hashes",
            "g1_body_hash", "g2_body_hash", "g3_body_hash", "bundle_hash",
            "dgd_input_v1", "hash_or_declaration_mismatch")),
        "closed_subset": all(name in source for name in (
            "unsupported_nonlinear", "unsupported_time", "unsupported_anisotropic",
            "multifield_or_size_mismatch", "units_dimension_mismatch",
            "DGD_ALLOWED_U_EXPRESSIONS_V1", "DGD_ALLOWED_F_EXPRESSIONS_V1")),
        "edge_safety": all(name in source for name in (
            "auto_typed_port_edges", "duplicate_producer", "missing_boundary",
            "missing_return", "ledger_contradiction", "semantic_edges",
            "_dsc_port_key")),
        "numerical_gates": all(name in source for name in (
            "pure_neumann_singular", "singular_matrix", "nonfinite_derived",
            "residual_norm", "finite_volume_solved")),
        "label_erasure": all(name in source for name in (
            "Component/port labels are diagnostic", "semantic_edges",
            "sort([(_dsc_port_key", "plan_hash")),
        "screen_only_boundary": fixture["claim_ceiling"] == "screen_only" and
            fixture["accepted"] is False and all(name in source for name in (
                "DCCE_CLAIM_CEILING_V1", "screen_only", "accepted=false",
                "formal_up_credit=false", "formal_r_credit=false")),
        "review_pending_boundary": fixture["accepted"] is False and
            fixture.get("review_state") == "review_pending" and
            (not (ROOT / "docs/implementation/UP2-DECLARED-DIFFUSION-COMPILE-EXECUTE-V1/manifest.json").exists() or
             "review_pending" in (ROOT / "docs/implementation/UP2-DECLARED-DIFFUSION-COMPILE-EXECUTE-V1/manifest.json").read_text(encoding="utf-8")) and
            (not (ROOT / "docs/implementation/UP2-DECLARED-DIFFUSION-COMPILE-EXECUTE-V1/README.md").exists() or
             "accepted_limited" in (ROOT / "docs/implementation/UP2-DECLARED-DIFFUSION-COMPILE-EXECUTE-V1/README.md").read_text(encoding="utf-8")),
        "zero_external_counters": all(name in source for name in (
            "provider_calls=0", "mesh_calls=0",
            "dgd_numerical.solver_calls + solve_work.solver_calls",
            "dgd_solver_calls=dgd_numerical.solver_calls",
            "fv_solver_calls=solve_work.solver_calls")),
        "negative_dispatch_accounting": fixture["negative_dispatched"] == 3 and
            len(fixture["negative_pending"]) == 16 and set(fixture["negative_gates"]) == {
                "candidate_mismatch", "missing_boundary", "pure_neumann"},
        "focused_dispatch": all(name in test for name in (
            "dcce_compile_execute_v1", "DCCE_CLAIM_CEILING_V1",
            "out.compile.status", "out.lowering.status", "out.composition.status",
            "out.numerical.status", "out.aggregate.status",
            "JULIA_FOCUSED_COMPLETED=true", "DESC_EXECUTED=false")),
        "focused_negative_dispatch_accounting": all(name in test for name in (
            "candidate_mismatch", "missing_boundary", "pure_neumann",
            "observed[:candidate_mismatch]", "observed[:missing_boundary]",
            "observed[:pure_neumann]")),
        "oracle_independent": "import FusionConceptAI" not in oracle and
            "DeclaredDiffusionCompileExecuteV1" not in oracle and
            "multifield_be" in oracle and "multifield_matrix" in oracle and
            "julia_or_desc_executed" in oracle.lower(),
        "no_shared_registry": not any(name in source for name in (
            "default_operator_registry", "Compiler.jl", "include(", "DESC")),
        "python_only_execution": fixture["execution"]["julia_executed"] is False and
            fixture["execution"]["desc_executed"] is False,
    }
    files = {str(p.relative_to(ROOT)).replace("\\", "/"): sha256(p)
             for p in (SRC, SPATIAL, FIXTURE, TEST, ORACLE, Path(__file__))}
    result = {
        "record_kind": "DeclaredDiffusionCompileExecuteV1-static-QA",
        "checks": checks, "files_sha256": files,
        "exit_code": 0 if all(checks.values()) else 1,
        "julia_executed": False, "desc_executed": False,
        "provider_calls": 0, "mesh_calls": 0, "solver_calls": 0,
        "formal_physical_evidence": False, "accepted": False,
        "claim_ceiling": "screen_only",
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return result["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
