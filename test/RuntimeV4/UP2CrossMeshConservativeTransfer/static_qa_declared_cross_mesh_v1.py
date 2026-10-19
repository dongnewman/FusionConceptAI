"""Python-only static QA for the additive UP2 cross-mesh slice.

This checker inspects the declared Julia seams and the two fixture contracts;
the independent arithmetic oracle is run separately by the handoff command.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "DeclaredCrossMeshConservativeTransferExecutionV1.jl"
TEST = Path(__file__).with_name("cross_mesh_conservative_transfer_v1_tests.jl")
FIXTURE = Path(__file__).with_name("fixture.json")
ORACLE = Path(__file__).with_name("independent_oracle_declared_cross_mesh_v1.py")


def _assert_close_matrix(actual, expected, label):
    assert actual == expected, f"{label} mismatch: {actual!r} != {expected!r}"

def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    required_source = (
        "DeclaredCrossMeshIdentityV1", "DeclaredCrossMeshV1",
        "declared_cross_mesh_identity_v1", "declared_cross_mesh_transfer_v1",
        "execute_declared_cross_mesh_v1", "source_integrated_total",
        "target_integrated_total", "local_defects", "interface_defects",
        "global_defect", "source_overlap_coverage", "target_overlap_coverage",
        "formal_up2_credit", "formal_r_credit", "screen_only",
        "one_dimensional_diffusion_solved", "noncovering_overlap",
        "missing_external_return_account", "body_hash", "bundle_hash",
        "axis_hashes", "mesh_hash", "owner_mismatch", "state_shape_mismatch",
        "space_mismatch", "mesh_side_mismatch", "one_dimensional_diffusion_solved",
        "declared_axisymmetric_global_consumer_v1",
        "assemble_coupled_mhd_global_v1", "solve_coupled_mhd_global_v1",
        "coupled_mhd_global_consumer",
        "state_vector = vec(Float64.(collect(state)))",
        "state_dofs=length(state_vector)",
        "policy_hash=hasproperty(policy,:policy_hash)",
    )
    missing = [token for token in required_source if token not in source]
    assert not missing, f"source missing required contract tokens: {missing}"
    for token in ("execute_declared_cross_mesh_v1", "declared_cross_mesh_transfer_v1",
                  "0.25,0.75", "mesh:source-2", "mesh:target-4",
                  "wrong_candidate", "noncovering_overlap", "missing_external",
                  "axis_bad", "forged_mesh", "wrong_owner", "shape",
                  "remesh adapter dispatches only to existing CoupledMHD APIs",
                  "assembly_missing_closures", "solver_missing_closures"):
        assert token in test, f"test does not exercise {token}"
    for token in ("_cm_remesh_global_api_fixture", "status === :evaluated_screen_only",
                  "assembly_status === :assembled", "solver_status === :converged",
                  "purpose=:global_consumer_vector_dispatch_fixture"):
        assert token in test, f"positive global consumer seam is missing {token}"
    assert "(1.0, 3.0)" not in test
    assert ORACLE.exists(), "independent arithmetic oracle is missing"
    oracle_source = ORACLE.read_text(encoding="utf-8")
    assert "import FusionConceptAI" not in oracle_source
    assert "using FusionConceptAI" not in oracle_source
    assert "overlap_transfer" in oracle_source and "holdout" in oracle_source

    assert fixture["accepted"] is False
    assert fixture["claim_ceiling"] == "screen_only"
    assert fixture["formal_up2_credit"] is False and fixture["formal_r_credit"] is False
    assert fixture["source_cells"] == 2 and fixture["target_cells"] == 4
    assert set(fixture["fixtures"]) == {"main", "holdout"}

    main_fixture = fixture["fixtures"]["main"]
    assert main_fixture["old_edges"] == [0.0, 0.5, 1.0]
    assert main_fixture["new_edges"] == [0.0, 0.25, 0.5, 0.75, 1.0]
    assert main_fixture["old_state"] == [0.25, 0.75]
    main_expected = main_fixture["expected"]
    assert main_expected["transferred_state"] == [0.25, 0.25, 0.75, 0.75]
    assert main_expected["source_mass"] == 0.5
    assert main_expected["target_mass"] == 0.5
    _assert_close_matrix(main_expected["overlap_lengths"],
                         [[0.25, 0.25, 0.0, 0.0],
                          [0.0, 0.0, 0.25, 0.25]], "main overlap lengths")
    _assert_close_matrix(main_expected["P"],
                         [[1.0, 1.0, 0.0, 0.0],
                          [0.0, 0.0, 1.0, 1.0]], "main P")
    assert main_expected["source_coverage"] == 1.0
    assert main_expected["target_coverage"] == 1.0
    assert main_expected["local_defects"] == [0.0, 0.0, 0.0, 0.0]
    assert main_expected["interface_defects"] == [0.0]
    assert main_expected["global_defect"] == 0.0
    diffusion = main_expected["diffusion"]
    _assert_close_matrix(diffusion["matrix"],
                         [[8.0, -4.0, 0.0, 0.0],
                          [-4.0, 8.0, -4.0, 0.0],
                          [0.0, -4.0, 8.0, -4.0],
                          [0.0, 0.0, -4.0, 8.0]], "main 4x4 diffusion matrix")
    assert diffusion["rhs"] == [0.25, 0.25, 0.75, 4.75]
    assert diffusion["solution"] == [0.4, 0.7375, 1.0125, 1.1]

    holdout = fixture["fixtures"]["holdout"]
    assert holdout["old_edges"] == [0.0, 0.4, 1.0]
    assert holdout["new_edges"] == [0.0, 0.2, 0.5, 0.8, 1.0]
    assert holdout["old_state"] == [2.0, -1.0]
    holdout_expected = holdout["expected"]
    assert holdout_expected["transferred_state"] == [2.0, 1.0, -1.0, -1.0]
    assert holdout_expected["source_mass"] == 0.2
    assert holdout_expected["target_mass"] == 0.2
    assert holdout_expected["source_coverage"] == 1.0
    assert holdout_expected["target_coverage"] == 1.0
    assert holdout_expected["local_defects"] == [0.0, 0.0, 0.0, 0.0]
    assert holdout_expected["interface_defects"] == [0.0]
    assert holdout_expected["global_defect"] == 0.0
    print("DECLARED_CROSS_MESH_CONSERVATIVE_TRANSFER_V1_STATIC_QA=PASS")

if __name__ == "__main__":
    main()
