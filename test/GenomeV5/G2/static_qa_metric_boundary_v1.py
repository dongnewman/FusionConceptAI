"""Static QA for the G2 metric-boundary V1 preparation slice.

This checker reads source, fixture and focused-test text only.  It never
invokes Julia, DESC, a mesh backend or a provider.
"""
from __future__ import annotations

import hashlib
import json
import platform
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "GenomeV5" / "G2" / "MetricBoundaryDeclarationV1.jl"
TEST = Path(__file__).with_name("metric_boundary_v1_contract_tests.jl")
FIXTURE = Path(__file__).with_name("metric_boundary_v1_fixture.json")


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fail(message: str) -> None:
    raise SystemExit(f"static_qa=fail: {message}")


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))

    required_source = (
        "G2MBChartMapV1", "g2mb_chart_map", "g2mb_chart_jacobian", "g2mb_metric",
        "g2mb_det_jacobian", "g2mb_orientation_positive", "g2mb_physical_oriented_area_vector",
        "g2mb_volume_measure", "G2MBVolumeMeasureV1", "G2MBUnitContractV1",
        "G2MBAreaMeasureV1", "g2mb_physical_oriented_area_measure",
        "g2mb_unit_algebra_errors", "reference_coordinate",
        "G2MBMeshPlanV1", "quadrature_points", "G2MBFaceOwnerV1", "G2MBFaceValueV1",
        "reference_normal", "unique_face_owner",
        "G2MBAuthorityV1", "G2MBSourceV1", "source_hash", "G2MBDeclarationV1",
        "declaration_hash", "g2mb_edit_source", "G2MBReceiptV1", "review_pending",
        "accepted", "terminal_deferred", "fail_closed", "program_exception",
        "unexpected_exception", "physical_evidence", "g2mb_schema_hash_v1",
        "g2mb_canonicalization_hash_v1", "g2mb_profile_hash_v1", "_G2MBFaultProbeV1",
        "_G2MBControlledFaultV1", "_g2mb_fault_probe", "_g2mb_canonical_faces",
        "G2MB_LABEL_ERASURE_SCOPE_V1", "display_metadata_only", "reference_normal",
        "value.kind", "value.unit.exponents",
    )
    missing = [token for token in required_source if token not in source]
    if missing:
        fail("missing source tokens: " + ", ".join(missing))

    if any(token in source for token in ("default_operator_registry", "DESC.", "Gridap", "run_solver")):
        fail("source contains a forbidden backend/provider execution hook")
    if "Base.include" in source or "include(" in source:
        fail("source must remain an additive include target, not include other modules")
    if "Tuple(sort(collect(faces)" not in source or "Tuple(f.reference_normal)" not in source:
        fail("source does not implement complete lexical face canonicalization")

    chart = fixture["source"]["chart"]
    rows = chart["jacobian_rows"]
    if len(rows) != 3 or any(len(row) != 3 for row in rows):
        fail("fixture Jacobian is not 3x3")
    diagonal = [rows[i][i] for i in range(3)]
    if diagonal != ["2/1", "3/1", "4/1"]:
        fail("fixture does not carry the declared nontrivial Jacobian")
    if fixture["source"]["mesh"]["execution_status"] != "not_executed":
        fail("fixture must exercise the unconditional not_executed mesh gap")
    units = fixture["source"]["units"]
    for key in ("reference_coordinate", "coordinate", "jacobian", "metric", "area", "volume", "field_value", "flux_value"):
        if len(units[key]) != 7 or not all(isinstance(v, int) for v in units[key]):
            fail(f"typed unit exponents missing for {key}")
    if units["reference_coordinate"] != [0, 0, 0, 0, 0, 0, 0]:
        fail("reference coordinate unit must be dimensionless")
    expected_units = {
        "coordinate": [1, 0, 0, 0, 0, 0, 0],
        "jacobian": [1, 0, 0, 0, 0, 0, 0],
        "metric": [2, 0, 0, 0, 0, 0, 0],
        "area": [2, 0, 0, 0, 0, 0, 0],
        "volume": [3, 0, 0, 0, 0, 0, 0],
    }
    if any(units[key] != expected for key, expected in expected_units.items()):
        fail("fixture derived geometry unit algebra is inconsistent")
    faces = fixture["source"]["faces"]
    if len(faces) != 6 or len({face["face"] for face in faces}) != 6:
        fail("fixture does not provide six unique boundary faces")
    expected_normals = {
        "x_min": [-1, 0, 0], "x_max": [1, 0, 0],
        "y_min": [0, -1, 0], "y_max": [0, 1, 0],
        "z_min": [0, 0, -1], "z_max": [0, 0, 1],
    }
    if any(face["normal"] != expected_normals[face["face"]] for face in faces):
        fail("fixture face orientation is inconsistent")
    if {face["kind"] for face in faces} != {"dirichlet", "neumann"}:
        fail("fixture does not cover Dirichlet and Neumann values")
    for face in faces:
        expected_role = "field_value" if face["kind"] == "dirichlet" else "flux_value"
        if face["unit_role"] != expected_role:
            fail("fixture boundary value unit role does not match boundary kind")
    label_erasure = fixture["label_erasure"]
    if label_erasure["status"] != "not_applicable" or label_erasure["display_fields"] != []:
        fail("label-erasure boundary must remain explicit and display-only")
    required_semantic_fields = {
        "candidate_ref", "face_id", "face", "owner_region_id", "value", "reference_normal"
    }
    if not required_semantic_fields.issubset(set(label_erasure["semantic_fields"])):
        fail("label-erasure boundary omitted semantic owner fields")
    if fixture["review_pending"] is not True or fixture["accepted"] is not False:
        fail("fixture state boundary is not review_pending=true/accepted=false")
    if any(fixture[key] != 0 for key in ("compile_calls", "provider_calls", "mesh_calls", "solver_calls")):
        fail("fixture claims an execution call")
    if fixture["physical_evidence"] is not False or fixture["julia_or_desc_executed"] is not False:
        fail("fixture claims forbidden execution or physical evidence")
    for token in ("mesh_chart_ref_mismatch", "mesh_basis_unsupported",
                  "quadrature_point_out_of_domain", "quadrature_weight_arity_mismatch",
                  "quadrature_weight_nonpositive", "candidate_binding_change_rehash",
                  "source_hash_tamper_rejected", "declaration_hash_tamper_rejected",
                  "duplicate_face_same_key_different_normal_value", "classification_order_invariant",
                  "reference_coordinate_unit_mismatch", "coordinate_unit_mismatch",
                  "jacobian_unit_mismatch", "metric_unit_mismatch", "area_unit_mismatch",
                  "volume_unit_mismatch", "derived_area_unit_binding", "derived_volume_unit_binding"):
        if token not in fixture["negative_controls"]:
            fail(f"fixture missing unit algebra negative/control marker: {token}")

    required_test = (
        "executable chart metric", "source and declaration identity", "contradictions fail closed",
        "terminal_deferred", "program_exception", "determinant", "physical_oriented_area_vector",
        "G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false", "mesh guards",
        "canonical face ordering", "label erasure boundary", "classification order invariant",
    )
    for token in required_test:
        if token not in test:
            fail(f"missing focused test marker: {token}")
    for token in ("mesh_chart_ref_mismatch", "quadrature_point_out_of_domain",
                  "candidate_binding_change_rehash", "source_hash_tamper_rejected",
                  "declaration_hash_tamper_rejected", "reference_coordinate_unit_mismatch",
                  "duplicate_face_same_key_different_normal_value", "classification_order_invariant",
                  "coordinate_unit_mismatch",
                  "jacobian_unit_mismatch", "metric_unit_mismatch", "area_unit_mismatch",
                  "volume_unit_mismatch", "g2mb_physical_oriented_area_measure",
                  "G2MB_LABEL_ERASURE_SCOPE_V1"):
        if token not in test:
            fail(f"missing unit algebra negative/control marker: {token}")

    # Detect accidental raw digest literals in the focused test while allowing
    # digest256_text seeds, which keep candidate identity reproducible.
    if re.search(r"Digest256\(\s*[\"']", test):
        fail("focused test constructs a raw Digest256 literal")

    print("static_qa=pass")
    print(f"python_executable={sys.executable}")
    print(f"python_version={platform.python_version()}")
    print(f"working_directory={Path.cwd()}")
    print(f"source_sha256={sha256(SOURCE)}")
    print(f"test_sha256={sha256(TEST)}")
    print(f"fixture_sha256={sha256(FIXTURE)}")
    print("julia_or_desc_executed=false")
    print("provider_or_mesh_execution=false")
    print("claim_ceiling=contract_only")
    print("review_pending=true")
    print("accepted=false")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
