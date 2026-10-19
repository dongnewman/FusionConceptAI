"""Independent arithmetic oracle for the DCCE V1 contract.

It reads fixture.json only.  It deliberately does not import Julia, the
FusionConceptAI package, or the product source.
"""
from __future__ import annotations

import json
import math
from pathlib import Path


def solve(k, source, boundary, spacing, side_load=1.0 / 6.0):
    # Independent oracle for the submitted G123 2x2 lane.  The spatial FV
    # holdout is recomputed separately below and is never conflated with it.
    k0, k1, k2 = k
    h2 = spacing * spacing
    matrix = [[(k0 + k1) / h2, -k1 / h2],
              [-k1 / h2, (k1 + k2) / h2]]
    rhs = [source[0] + side_load + k0 * boundary[0] / h2,
           source[1] + side_load + 1.0 / spacing]
    det = matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]
    assert math.isfinite(det) and abs(det) > 1e-14
    solution = [(rhs[0] * matrix[1][1] - matrix[0][1] * rhs[1]) / det,
                (matrix[0][0] * rhs[1] - rhs[0] * matrix[1][0]) / det]
    residual = [matrix[0][0] * solution[0] + matrix[0][1] * solution[1] - rhs[0],
                matrix[1][0] * solution[0] + matrix[1][1] * solution[1] - rhs[1]]
    return matrix, rhs, solution, math.hypot(*residual)


def spatial_fv(edges, k, source, left, right):
    n = len(k)
    centers = [(edges[i] + edges[i + 1]) / 2.0 for i in range(n)]
    matrix = [[0.0 for _ in range(n)] for _ in range(n)]
    rhs = [source[i] * (edges[i + 1] - edges[i]) for i in range(n)]
    for i in range(n - 1):
        face = edges[i + 1]
        t = 1.0 / ((face - centers[i]) / k[i] + (centers[i + 1] - face) / k[i + 1])
        matrix[i][i] += t
        matrix[i + 1][i + 1] += t
        matrix[i][i + 1] -= t
        matrix[i + 1][i] -= t
    left_t = k[0] / (centers[0] - edges[0])
    right_t = k[-1] / (edges[-1] - centers[-1])
    matrix[0][0] += left_t
    rhs[0] += left_t * left
    matrix[-1][-1] += right_t
    rhs[-1] += right_t * right
    aug = [matrix[i][:] + [rhs[i]] for i in range(n)]
    for i in range(n):
        pivot = max(range(i, n), key=lambda j: abs(aug[j][i]))
        aug[i], aug[pivot] = aug[pivot], aug[i]
        for j in range(i + 1, n):
            scale = aug[j][i] / aug[i][i]
            for c in range(i, n + 1):
                aug[j][c] -= scale * aug[i][c]
    solution = [0.0] * n
    for i in range(n - 1, -1, -1):
        solution[i] = (aug[i][-1] - sum(aug[i][j] * solution[j] for j in range(i + 1, n))) / aug[i][i]
    residual = max(abs(sum(matrix[i][j] * solution[j] for j in range(n)) - rhs[i]) for i in range(n))
    return matrix, rhs, solution, residual


def solve_dense(matrix, rhs):
    n = len(rhs)
    aug = [matrix[i][:] + [rhs[i]] for i in range(n)]
    for i in range(n):
        pivot = max(range(i, n), key=lambda j: abs(aug[j][i]))
        aug[i], aug[pivot] = aug[pivot], aug[i]
        assert abs(aug[i][i]) > 1e-14
        for j in range(i + 1, n):
            scale = aug[j][i] / aug[i][i]
            for c in range(i, n + 1):
                aug[j][c] -= scale * aug[i][c]
    solution = [0.0] * n
    for i in range(n - 1, -1, -1):
        solution[i] = (aug[i][-1] - sum(aug[i][j] * solution[j]
                                        for j in range(i + 1, n))) / aug[i][i]
    residual = max(abs(sum(matrix[i][j] * solution[j] for j in range(n)) - rhs[i])
                   for i in range(n))
    return solution, residual


def multifield_be(spec):
    edges = spec["edges"]
    old_edges = spec["old_edges"]
    components = spec["components"]
    n = len(edges) - 1
    count = len(components)
    matrices, loads, histories = [], [], []
    for component in components:
        matrix, rhs, _, _ = spatial_fv(edges, component["k"], component["source"],
                                        *component["boundary"])
        matrices.append(matrix)
        loads.append(rhs)
        transferred = []
        for j in range(n):
            width = edges[j + 1] - edges[j]
            transferred.append(sum(max(0.0, min(edges[j + 1], old_edges[i + 1]) -
                max(edges[j], old_edges[i])) * component["old_state"][i]
                for i in range(len(old_edges) - 1)) / width)
        histories.append(transferred)
    size = count * n
    matrix = [[0.0] * size for _ in range(size)]
    rhs = [0.0] * size
    for c in range(count):
        for i in range(n):
            row = c * n + i
            rhs[row] = loads[c][i]
            for j in range(n):
                matrix[row][c * n + j] = matrices[c][i][j]
    for cell in range(n):
        width = edges[cell + 1] - edges[cell]
        exchange = spec["coupling_coefficient"] * width
        mass = spec["capacity"] * width / spec["dt"]
        for c in range(count):
            idx = c * n + cell
            matrix[idx][idx] += mass + exchange * (count - 1)
            rhs[idx] += mass * histories[c][cell]
            for other in range(count):
                if other != c:
                    matrix[idx][other * n + cell] -= exchange
    solution, residual = solve_dense(matrix, rhs)
    return matrix, rhs, solution, residual, histories


def main() -> int:
    fixture = json.loads(Path(__file__).with_name("fixture.json").read_text(encoding="utf-8"))
    p = fixture["positive"]
    matrix, rhs, solution, residual = solve([2.0, 2.05, 2.1], [1.0, 1.0], [0.0, 1.0], 2.0 / 3.0)
    for i in range(2):
        for j in range(2):
            assert math.isclose(matrix[i][j], p["matrix"][i][j], abs_tol=1e-12)
    for got, expected in zip(rhs, p["rhs"]):
        assert math.isclose(got, expected, abs_tol=1e-12)
    for got, expected in zip(solution, p["solution"]):
        assert math.isclose(got, expected, abs_tol=1e-12)
    assert math.isfinite(residual) and residual <= p["residual_tolerance"]
    sp = p["spatial_holdout"]
    fv_matrix, fv_rhs, fv_solution, fv_residual = spatial_fv(
        [0.0, 0.25, 0.5, 0.75, 1.0], [1.0, 2.0, 1.5, 0.8],
        [1.0, 0.0, -0.5, 0.75], 0.0, 1.0)
    for got_row, expected_row in zip(fv_matrix, sp["matrix"]):
        for got, expected in zip(got_row, expected_row):
            assert math.isclose(got, expected, abs_tol=1e-12)
    for got, expected in zip(fv_rhs, sp["rhs"]):
        assert math.isclose(got, expected, abs_tol=1e-12)
    for got, expected in zip(fv_solution, sp["solution"]):
        assert math.isclose(got, expected, abs_tol=1e-12)
    assert fv_residual <= 1e-12
    assert sp["transfer_new_state"] == [0.25, 0.25, 0.75, 0.75]
    assert sp["transfer_conservation_residual"] == 0.0
    assert fixture["expression_subset"] == "diagonal_affine_static"
    assert fixture["claim_ceiling"] == "screen_only" and fixture["accepted"] is False
    assert p["compile_status"] == "ready" and p["lowering_status"] == "ready"
    assert p["composition_status"] == "terminal_deferred"
    assert p["numerical_status"] == "ready"
    assert p["aggregate_status"] == "terminal_deferred"
    assert fixture["semantic_invariance"]["expected"] == "same semantic plan/result hashes"
    multi = fixture["multifield_boundary"]["independent_oracle_input"]
    block, block_rhs, block_solution, block_residual, histories = multifield_be(multi)
    assert len(block) == 8 and all(len(row) == 8 for row in block)
    assert histories == [[0.1, 0.1, 0.3, 0.3], [0.6, 0.6, 0.8, 0.8]]
    assert all(math.isclose(block[i][j], block[j][i], abs_tol=1e-12)
               for i in range(8) for j in range(8))
    assert block_residual <= 1e-12 and all(math.isfinite(x) for x in block_solution)
    expected_negative = {
        "candidate_mismatch": ["fail_closed", "candidate_mismatch"],
        "missing_boundary": ["fail_closed", "missing_boundary"],
        "pure_neumann": ["numerical_fail", "pure_neumann_singular"],
    }
    assert fixture["negative_gates"] == expected_negative
    assert fixture["negative_dispatched"] == len(expected_negative)
    assert len(fixture["negative_pending"]) == 16
    assert fixture["execution"] == {
        "julia_executed": False, "desc_executed": False, "provider_calls": 0,
        "mesh_calls": 0, "solver_calls": 2, "formal_physical_evidence": False,
    }
    print(json.dumps({"oracle": "pass", "matrix": matrix, "rhs": rhs,
                      "solution": solution, "residual_norm": residual,
                      "multifield_matrix": block, "multifield_rhs": block_rhs,
                      "multifield_solution": block_solution,
                      "multifield_residual_norm": block_residual,
                      "negative_gates": len(expected_negative),
                      "negative_pending": len(fixture["negative_pending"]),
                      "julia_or_desc_executed": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
