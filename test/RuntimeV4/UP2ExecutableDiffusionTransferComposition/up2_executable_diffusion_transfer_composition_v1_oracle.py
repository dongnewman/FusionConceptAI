"""Independent arithmetic oracle for UP2-EXEC-01.

The oracle intentionally does not import Julia or the product source.  It
reconstructs the two-DOF stencil, determinant solve, and status vectors from
the JSON fixture only.
"""

from __future__ import annotations

import json
import math
from pathlib import Path


def assemble(k: list[float], source: list[float], boundary: list[float], h: float = 1 / 3):
    h2 = h * h
    k1, k2, k3 = k
    matrix = [[(k1 + k2) / h2, -k2 / h2], [-k2 / h2, (k2 + k3) / h2]]
    rhs = [source[0] + k1 * boundary[0] / h2,
           source[1] + k3 * boundary[1] / h2]
    return matrix, rhs


def solve(matrix: list[list[float]], rhs: list[float]):
    a, b = matrix[0]
    c, d = matrix[1]
    det = a * d - b * c
    if abs(det) <= 1e-14:
        return None
    return [(rhs[0] * d - b * rhs[1]) / det,
            (a * rhs[1] - rhs[0] * c) / det]


def transfer_state(old_state: list[float], weights: list[float]):
    x1, x2 = old_state
    w1, w2 = weights
    return [w1 * x1 + (1.0 - w1) * x2,
            (1.0 - w2) * x1 + w2 * x2]


def validate_fixture(fixture: dict) -> dict:
    positive = fixture["positive"]
    matrix, rhs = assemble(positive["k_faces"], positive["source"], positive["boundary"])
    expected_matrix = positive["matrix"]
    expected_rhs = positive["rhs"]
    assert all(math.isclose(matrix[i][j], expected_matrix[i][j], rel_tol=0, abs_tol=1e-12)
               for i in range(2) for j in range(2))
    assert all(math.isclose(rhs[i], expected_rhs[i], rel_tol=0, abs_tol=1e-12) for i in range(2))
    solution = solve(matrix, rhs)
    assert solution is not None
    assert all(math.isclose(solution[i], positive["solution"][i], rel_tol=0, abs_tol=1e-12)
               for i in range(2))
    assert positive["status"] == "ready"
    assert positive["code"] == "joint_linear_solved"
    assert positive["provider_call_count"] == 0
    assert positive["mesh_call_count"] == 0
    assert positive["solver_invocation_count"] == 1
    transferred = transfer_state(fixture["topology"]["old_state"], fixture["topology"]["transfer_weights"])
    assert fixture["topology"]["old_state_semantics"] == "pre_transfer"
    assert fixture["topology"]["new_state_semantics"] == "expected_post_transfer"
    assert all(math.isclose(transferred[i], fixture["topology"]["transferred_new_state"][i],
                            rel_tol=0, abs_tol=1e-12) for i in range(2))
    altered = transfer_state([0.75, 0.25], fixture["topology"]["transfer_weights"])
    assert altered != transferred

    expected_vectors = {
        "binding_malformed": ("fail_closed", "binding_malformed"),
        "binding_mismatch": ("fail_closed", "binding_mismatch"),
        "topology_identity_mismatch": ("fail_closed", "topology_identity_mismatch"),
        "equation_unit_mismatch": ("fail_closed", "equation_unit_mismatch"),
        "duplicate_producer": ("fail_closed", "duplicate_producer"),
        "unit_mismatch": ("fail_closed", "unit_mismatch"),
        "missing_closure": ("fail_closed", "missing_closure"),
        "invalid_overlap": ("terminal_deferred", "invalid_overlap"),
        "singular_matrix": ("numerical_fail", "singular_matrix"),
        "nonfinite_derived": ("numerical_fail", "nonfinite_derived"),
    }
    for name, expected in expected_vectors.items():
        observed = fixture["negative_expectations"][name]
        assert (observed["status"], observed["code"]) == expected
    assert fixture["execution"] == {
        "provider_calls": 0, "mesh_calls": 0,
        "desc_executed": False, "julia_executed": False,
    }
    return {
        "status": "pass",
        "matrix": matrix,
        "rhs": rhs,
        "solution": solution,
        "transferred_new_state": transferred,
        "negative_vectors": len(expected_vectors),
    }


def main() -> int:
    fixture_path = Path(__file__).with_name("up2_executable_diffusion_transfer_composition_v1_fixture.json")
    result = validate_fixture(json.loads(fixture_path.read_text(encoding="utf-8")))
    print(json.dumps({"schema": "ExecutableDiffusionTransferCompositionOracleV1", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
