"""Independent arithmetic oracle for the declared spatial composition slice.

This file reads only the fixture and reimplements overlap transfer, centred
finite-volume assembly/solve, and the MMS order check.  It never imports Julia
or product code and never starts a provider, mesh backend, or DESC.
"""

from __future__ import annotations

import json
import math
from pathlib import Path


def overlap_transfer(old_edges, new_edges, old_state):
    out = []
    for j in range(len(new_edges) - 1):
        lo, hi = new_edges[j:j + 2]
        volume = hi - lo
        out.append(sum(max(0.0, min(hi, old_edges[jj + 1]) -
                         max(lo, old_edges[jj])) * old_state[jj]
                    for jj in range(len(old_edges) - 1)) / volume)
    return out


def assemble(edges, k, source, left, right):
    n = len(k)
    centers = [(edges[i] + edges[i + 1]) / 2.0 for i in range(n)]
    matrix = [[0.0] * n for _ in range(n)]
    rhs = [source[i] * (edges[i + 1] - edges[i]) for i in range(n)]
    for i in range(n - 1):
        face_k = 2.0 * k[i] * k[i + 1] / (k[i] + k[i + 1])
        t = face_k / (centers[i + 1] - centers[i])
        matrix[i][i] += t
        matrix[i + 1][i + 1] += t
        matrix[i][i + 1] -= t
        matrix[i + 1][i] -= t
    matrix[0][0] += k[0] / (centers[0] - edges[0])
    rhs[0] += k[0] / (centers[0] - edges[0]) * left
    matrix[-1][-1] += k[-1] / (edges[-1] - centers[-1])
    rhs[-1] += k[-1] / (edges[-1] - centers[-1]) * right
    return matrix, rhs


def solve(matrix, rhs):
    n = len(rhs)
    a = [row[:] + [rhs[i]] for i, row in enumerate(matrix)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda row: abs(a[row][col]))
        if abs(a[pivot][col]) <= 1e-14:
            return None
        a[col], a[pivot] = a[pivot], a[col]
        p = a[col][col]
        a[col] = [v / p for v in a[col]]
        for row in range(n):
            if row == col:
                continue
            fac = a[row][col]
            a[row] = [a[row][j] - fac * a[col][j] for j in range(n + 1)]
    return [a[i][-1] for i in range(n)]


def pure_neumann_matrix(edges, k):
    n = len(k)
    centers = [(edges[i] + edges[i + 1]) / 2.0 for i in range(n)]
    matrix = [[0.0] * n for _ in range(n)]
    for i in range(n - 1):
        face = edges[i + 1]
        dleft = face - centers[i]
        dright = centers[i + 1] - face
        t = 1.0 / (dleft / k[i] + dright / k[i + 1])
        matrix[i][i] += t
        matrix[i + 1][i + 1] += t
        matrix[i][i + 1] -= t
        matrix[i + 1][i] -= t
    return matrix


def mms_order():
    errors = []
    for n in (8, 16, 32):
        edges = [i / n for i in range(n + 1)]
        centers = [(edges[i] + edges[i + 1]) / 2 for i in range(n)]
        matrix, rhs = assemble(edges, [1.0] * n,
                               [math.pi ** 2 * math.sin(math.pi * x) for x in centers], 0.0, 0.0)
        numerical = solve(matrix, rhs)
        exact = [math.sin(math.pi * x) for x in centers]
        errors.append(math.sqrt(sum((a - b) ** 2 for a, b in zip(numerical, exact)) / n))
    return math.log(errors[-2] / errors[-1]) / math.log(2.0)


def validate_fixture(fixture):
    geometry = fixture["geometry"]
    positive = fixture["positive"]
    transfer = overlap_transfer(geometry["old_edges"], geometry["new_edges"], geometry["old_state"])
    assert all(math.isclose(a, b, abs_tol=1e-12) for a, b in zip(transfer, geometry["transferred_state"]))
    old_total = sum(geometry["old_state"][i] * (geometry["old_edges"][i + 1] - geometry["old_edges"][i])
                    for i in range(2))
    new_total = sum(transfer[i] * (geometry["new_edges"][i + 1] - geometry["new_edges"][i])
                    for i in range(4))
    assert abs(old_total - new_total) <= 1e-12
    matrix, rhs = assemble(geometry["new_edges"], positive["k_cells"], positive["source"], 0.0, 1.0)
    expected = positive["matrix"]
    assert all(math.isclose(matrix[i][j], expected[i][j], rel_tol=0, abs_tol=1e-12)
               for i in range(4) for j in range(4))
    assert all(math.isclose(rhs[i], positive["rhs"][i], rel_tol=0, abs_tol=1e-12) for i in range(4))
    numerical = solve(matrix, rhs)
    assert numerical is not None
    assert all(math.isclose(numerical[i], positive["solution"][i], rel_tol=0, abs_tol=1e-10)
               for i in range(4))
    holdout = fixture["holdout"]
    holdout_matrix, holdout_rhs = assemble(geometry["new_edges"], holdout["k_cells"],
                                           holdout["source"], holdout["boundary"]["left"][1],
                                           holdout["boundary"]["right"][1])
    holdout_solution = solve(holdout_matrix, holdout_rhs)
    assert all(math.isclose(holdout_matrix[i][j], holdout["matrix"][i][j], rel_tol=0, abs_tol=1e-12)
               for i in range(4) for j in range(4))
    assert all(math.isclose(holdout_rhs[i], holdout["rhs"][i], rel_tol=0, abs_tol=1e-12)
               for i in range(4))
    assert all(math.isclose(holdout_solution[i], holdout["solution"][i], rel_tol=0, abs_tol=1e-10)
               for i in range(4))
    probe = fixture["neumann_probe"]
    assert probe["left_kind"] == "neumann"
    assert math.isclose(probe["left_value"], probe["expected_boundary_rhs_contribution"],
                        rel_tol=0, abs_tol=1e-12)
    pure_probe = fixture["pure_neumann_probe"]
    assert pure_probe == {
        "left_value": 0.0,
        "right_value": 0.0,
        "expected_status": "numerical_fail",
        "expected_code": "pure_neumann_singular",
    }
    assert solve(pure_neumann_matrix(geometry["new_edges"], positive["k_cells"]),
                positive["rhs"]) is None
    assert positive["mms_order"] > 1.8 and mms_order() > 1.8
    assert fixture["execution"] == {"provider_calls": 0, "solver_invocations": 1,
                                     "julia_executed": False, "desc_executed": False}
    assert fixture["accepted"] is False and fixture["claim_ceiling"] == "screen_only"
    expected_negative = {
        "duplicate_producer": ["fail_closed", "duplicate_producer"],
        "unit_mismatch": ["fail_closed", "unit_mismatch"],
        "missing_boundary": ["fail_closed", "missing_boundary"],
        "nonoverlap": ["terminal_deferred", "nonoverlap"],
        "nonfinite_K": ["fail_closed", "nonfinite_K"],
        "pure_neumann_singular": ["numerical_fail", "pure_neumann_singular"],
        "missing_return": ["fail_closed", "missing_return"],
        "geometry_hash_change": ["fail_closed", "geometry_hash_mismatch"],
    }
    assert fixture["negative_expectations"] == {
        key: value for key, value in expected_negative.items()
    }
    return {"status": "pass", "transfer": transfer, "mms_order": mms_order(),
            "matrix": matrix, "rhs": rhs, "solution": numerical,
            "holdout_solution": holdout_solution,
            "negative_vectors": len(expected_negative)}


def main():
    fixture = json.loads(Path(__file__).with_name("fixture.json").read_text(encoding="utf-8"))
    print(json.dumps({"schema": "DeclaredSpatialCompositionIndependentOracleV1",
                      **validate_fixture(fixture)}, sort_keys=True))


if __name__ == "__main__":
    main()
