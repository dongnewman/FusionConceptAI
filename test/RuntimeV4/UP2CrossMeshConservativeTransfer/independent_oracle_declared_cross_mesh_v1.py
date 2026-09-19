"""Independent arithmetic oracle for the UP2 cross-mesh fixtures.

The oracle is deliberately pure Python: it reads the JSON fixture, computes
geometric overlap transfer, conservation witnesses, and the small target-mesh
diffusion system, and never imports Julia or FusionConceptAI product code.
"""

from __future__ import annotations

import json
import math
from pathlib import Path


def overlap_lengths(old_edges, new_edges):
    return [
        [max(0.0, min(old_edges[i + 1], new_edges[j + 1]) -
         max(old_edges[i], new_edges[j]))
         for j in range(len(new_edges) - 1)]
        for i in range(len(old_edges) - 1)
    ]


def overlap_transfer(old_edges, new_edges, old_state):
    lengths = overlap_lengths(old_edges, new_edges)
    target_widths = [new_edges[j + 1] - new_edges[j]
                     for j in range(len(new_edges) - 1)]
    return [sum(lengths[i][j] * old_state[i]
                for i in range(len(old_state))) / target_widths[j]
            for j in range(len(target_widths))]


def transfer_matrix(lengths, new_edges):
    target_widths = [new_edges[j + 1] - new_edges[j]
                     for j in range(len(new_edges) - 1)]
    return [[length / target_widths[j] for j, length in enumerate(row)]
            for row in lengths]


def mass(edges, state):
    return sum(state[i] * (edges[i + 1] - edges[i])
               for i in range(len(state)))


def conservation_witness(old_edges, new_edges, old_state):
    lengths = overlap_lengths(old_edges, new_edges)
    state = overlap_transfer(old_edges, new_edges, old_state)
    old_widths = [old_edges[i + 1] - old_edges[i]
                  for i in range(len(old_state))]
    new_widths = [new_edges[j + 1] - new_edges[j]
                  for j in range(len(state))]
    local = [new_widths[j] * state[j] -
             sum(lengths[i][j] * old_state[i] for i in range(len(old_state)))
             for j in range(len(state))]
    interfaces = []
    for face_index in range(1, len(old_edges) - 1):
        face = old_edges[face_index]
        crossing = [j for j in range(len(state)
                                     ) if new_edges[j] < face < new_edges[j + 1]]
        interfaces.append(sum(new_widths[j] * state[j] for j in crossing) -
                          sum(lengths[i][j] * old_state[i]
                              for i in range(len(old_state)) for j in crossing))
    overlap_total = sum(sum(row) for row in lengths)
    return {
        "transferred_state": state,
        "source_mass": mass(old_edges, old_state),
        "target_mass": mass(new_edges, state),
        "overlap_lengths": lengths,
        "P": transfer_matrix(lengths, new_edges),
        "source_coverage": overlap_total / sum(old_widths),
        "target_coverage": overlap_total / sum(new_widths),
        "local_defects": local,
        "interface_defects": interfaces,
        "global_defect": mass(new_edges, state) - mass(old_edges, old_state),
    }


def assemble_diffusion(edges, state, left=0.0, right=1.0):
    n = len(state)
    matrix = [[0.0] * n for _ in range(n)]
    rhs = list(state)
    for i in range(n):
        h = edges[i + 1] - edges[i]
        if i == 0:
            matrix[i][i] += 1.0 / h
            rhs[i] += left / h
        else:
            conductance = 1.0 / (0.5 * ((edges[i] - edges[i - 1]) + h))
            matrix[i][i] += conductance
            matrix[i][i - 1] -= conductance
        if i == n - 1:
            matrix[i][i] += 1.0 / h
            rhs[i] += right / h
        else:
            conductance = 1.0 / (0.5 * (h + (edges[i + 2] - edges[i + 1])))
            matrix[i][i] += conductance
            matrix[i][i + 1] -= conductance
    return matrix, rhs


def solve(matrix, rhs):
    augmented = [row[:] + [rhs[i]] for i, row in enumerate(matrix)]
    n = len(rhs)
    for col in range(n):
        pivot = max(range(col, n), key=lambda row: abs(augmented[row][col]))
        if abs(augmented[pivot][col]) <= 1e-14:
            raise ArithmeticError("singular oracle matrix")
        augmented[col], augmented[pivot] = augmented[pivot], augmented[col]
        scale = augmented[col][col]
        augmented[col] = [value / scale for value in augmented[col]]
        for row in range(n):
            if row == col:
                continue
            factor = augmented[row][col]
            augmented[row] = [augmented[row][j] - factor * augmented[col][j]
                              for j in range(n + 1)]
    return [augmented[i][-1] for i in range(n)]


def assert_close(actual, expected, label, tolerance=1e-12):
    if isinstance(actual, list):
        assert len(actual) == len(expected), label
        for index, (left, right) in enumerate(zip(actual, expected)):
            assert_close(left, right, f"{label}[{index}]", tolerance)
    else:
        assert math.isclose(actual, expected, rel_tol=0.0, abs_tol=tolerance), \
            f"{label}: {actual!r} != {expected!r}"


def validate_case(case, name):
    actual = conservation_witness(case["old_edges"], case["new_edges"], case["old_state"])
    expected = case["expected"]
    for key in ("transferred_state", "source_mass", "target_mass", "overlap_lengths",
                "P", "source_coverage", "target_coverage", "local_defects",
                "interface_defects", "global_defect"):
        assert_close(actual[key], expected[key], f"{name}.{key}")
    return actual


def main():
    fixture = json.loads(Path(__file__).with_name("fixture.json").read_text(encoding="utf-8"))
    main_case = fixture["fixtures"]["main"]
    holdout_case = fixture["fixtures"]["holdout"]
    main_actual = validate_case(main_case, "main")
    holdout_actual = validate_case(holdout_case, "holdout")

    diffusion_matrix, diffusion_rhs = assemble_diffusion(
        main_case["new_edges"], main_actual["transferred_state"])
    diffusion_solution = solve(diffusion_matrix, diffusion_rhs)
    expected_diffusion = main_case["expected"]["diffusion"]
    assert_close(diffusion_matrix, expected_diffusion["matrix"], "main.diffusion.matrix")
    assert_close(diffusion_rhs, expected_diffusion["rhs"], "main.diffusion.rhs")
    assert_close(diffusion_solution, expected_diffusion["solution"], "main.diffusion.solution",
                 tolerance=1e-10)

    print(json.dumps({
        "schema": "DeclaredCrossMeshConservativeTransferIndependentOracleV1",
        "status": "pass",
        "fixtures": {"main": main_actual, "holdout": holdout_actual},
        "diffusion": {"matrix": diffusion_matrix, "rhs": diffusion_rhs,
                       "solution": diffusion_solution},
        "julia_executed": False,
        "product_code_imported": False,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
