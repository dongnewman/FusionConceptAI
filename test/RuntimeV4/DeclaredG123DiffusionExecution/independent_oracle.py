"""Independent arithmetic oracle for declared G1/G2/G3 R21.

It reads only fixture.json and does not import Julia or the product source.
"""
from __future__ import annotations

import json
import math
from pathlib import Path


EXPECTED_NEGATIVE_GATES = {
    "candidate_mismatch": ["fail_closed", "candidate_mismatch"],
    "body_hash_mismatch": ["fail_closed", "bundle_body_hash_mismatch"],
    "bundle_hash_mismatch": ["fail_closed", "bundle_hash_mismatch"],
    "unsupported_expression_subset": ["terminal_deferred", "unsupported_expression_subset"],
    "missing_mesh_authority": ["terminal_deferred", "g2_admission_terminal_deferred"],
    "missing_feedback_authority": ["terminal_deferred", "g3_admission_terminal_deferred"],
    "invalid_overlap": ["terminal_deferred", "invalid_overlap"],
    "singular_sparse_system": ["numerical_fail", "singular_or_nonfinite_sparse_system"],
    "nonfinite_derived": ["numerical_fail", "singular_or_nonfinite_sparse_system"],
    "ledger_contradiction": ["fail_closed", "ledger_contradiction"],
}


def solve(k, source, boundary, spacing, side_load=1.0 / 6.0):
    k1, k2, k3 = k
    h2 = spacing * spacing
    matrix = [[(k1 + k2) / h2, -k2 / h2], [-k2 / h2, (k2 + k3) / h2]]
    rhs = [source[0] + side_load + k1 * boundary[0] / h2,
           source[1] + side_load + 1.0 / spacing]
    det = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
    assert math.isfinite(det) and abs(det) > 1e-14
    out = [(rhs[0] * matrix[1][1] - matrix[0][1] * rhs[1]) / det,
           (matrix[0][0] * rhs[1] - rhs[0] * matrix[1][0]) / det]
    residual = [matrix[0][0] * out[0] + matrix[0][1] * out[1] - rhs[0],
                matrix[1][0] * out[0] + matrix[1][1] * out[1] - rhs[1]]
    return matrix, rhs, out, math.hypot(*residual)


def main() -> int:
    fixture = json.loads(Path(__file__).with_name("fixture.json").read_text(encoding="utf-8"))
    p = fixture["positive"]
    matrix, rhs, solution, residual = solve(p["k_faces"], p["source"], p["boundary"], 2.0 / 3.0)
    assert all(math.isclose(matrix[i][j], p["matrix"][i][j], abs_tol=1e-12) for i in range(2) for j in range(2))
    assert all(math.isclose(rhs[i], p["rhs"][i], abs_tol=1e-12) for i in range(2))
    assert all(math.isclose(solution[i], p["solution"][i], abs_tol=1e-12) for i in range(2))
    assert p["residual_norm"] > 0.0 and math.isfinite(p["residual_norm"])
    assert 0.0 < p["residual_tolerance"] <= 1e-13
    assert math.isclose(residual, p["residual_norm"], abs_tol=p["residual_tolerance"])
    old = fixture["transfer"]["old_state"]
    overlap = fixture["transfer"]["overlap"]
    old_bounds = [0.5, 2.5]
    w = [(overlap[1] - overlap[0]) / (old_bounds[1] - old_bounds[0])] * 2
    new = [w[0] * old[0] + (1 - w[0]) * old[1], (1 - w[1]) * old[0] + w[1] * old[1]]
    assert all(math.isclose(new[i], fixture["transfer"]["new_state"][i], abs_tol=1e-12) for i in range(2))
    assert math.isclose(sum(new) - sum(old), fixture["transfer"]["conservation_residual"], abs_tol=1e-12)
    assert p["source_power"] == p["field_power"] + p["return_power"] + p["heat_power"]
    # Positive sensitivity controls: each semantic declaration edit changes
    # the receipt-driving quantity, while a display-only edit does not.
    altered_matrix, _, _, _ = solve([2.0, 2.1, 2.2], p["source"], p["boundary"], 2.0 / 3.0)
    altered_mesh_matrix, _, _, _ = solve(p["k_faces"], p["source"], p["boundary"], 1.0 / 2.0)
    assert altered_matrix != matrix
    assert altered_mesh_matrix != matrix
    altered_field = 120.0 * (7.0 / 8.0)
    altered_heat = 120.0 * (1.0 / 8.0)
    assert altered_field != p["field_power"] and altered_heat == p["heat_power"]
    assert fixture["expression_subset"] == "diagonal_affine_static"
    assert fixture["candidate_ref"] == "local://candidate/up1-04a"
    assert p["k_evaluation_api"] == "diagonal_matrix_tuple_scalar_extraction"
    assert fixture["g2_mesh_execution_status"] in {"declared", "not_executed"}
    assert fixture["g2_mesh_execution_status"] != "executed"
    assert fixture["positive"]["status"] == "ready"
    assert fixture["positive"]["aggregate_status"] == "terminal_deferred"
    assert fixture["positive"]["composition_status"] == "terminal_deferred"
    assert fixture["positive"]["numerical_status"] == "ready"
    assert fixture["positive"]["g2_admission_resolution"] == "terminal_deferred"
    assert fixture["positive"]["g3_admission_resolution"] == "terminal_deferred"
    # This is an independent expected map, not a comparison of two product
    # literals.  The focused Julia runner observes every tuple from dispatch.
    assert fixture["negative_gates"] == EXPECTED_NEGATIVE_GATES
    assert set(fixture["negative_gates"]) == set(EXPECTED_NEGATIVE_GATES)
    assert fixture["negative_dispatch"] == {
        "invalid_overlap": {"entry": "dgd_execute_v1", "overlap": [3.0, 3.0]},
        "nonfinite_derived": {"entry": "dgd_numerical_solve_v1", "hash_body": "spacing_status=nonfinite"},
    }
    for name, expected in EXPECTED_NEGATIVE_GATES.items():
        assert len(expected) == 2 and expected[0] in {"fail_closed", "terminal_deferred", "numerical_fail"}, name
    assert fixture["execution"] == {"julia_executed": False, "desc_executed": False, "provider_calls": 0, "mesh_calls": 0, "formal_physical_evidence": False}
    print(json.dumps({"oracle": "pass", "matrix": matrix, "rhs": rhs, "solution": solution,
                      "residual_norm": residual, "transfer": new, "negative_gates": len(fixture["negative_gates"]),
                      "julia_or_desc_executed": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
