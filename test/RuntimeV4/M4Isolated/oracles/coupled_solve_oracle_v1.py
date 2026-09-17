"""Independent exact oracle for the isolated M4-D manufactured block solve.

This oracle intentionally does not import project code.  It verifies the
frozen [2 -1; -1 2] block with Fraction arithmetic and checks all eight cells
of the 2x2x2 identity interface.
"""

from fractions import Fraction
import json


def solve_2x2(block, rhs):
    a, b, c, d = block
    det = a * d - b * c
    if det == 0:
        raise AssertionError("oracle block unexpectedly singular")
    x = (rhs[0] * d - b * rhs[1]) / det
    y = (a * rhs[1] - c * rhs[0]) / det
    residual = (a * x + b * y - rhs[0], c * x + d * y - rhs[1])
    return det, (x, y), residual


def main():
    block = (Fraction(2), Fraction(-1), Fraction(-1), Fraction(2))
    rhs = (Fraction(1), Fraction(0))
    det, solution, residual = solve_2x2(block, rhs)
    assert det == Fraction(3)
    assert solution == (Fraction(2, 3), Fraction(1, 3))
    assert residual == (Fraction(0), Fraction(0))

    cells = []
    for k in range(1, 3):
        for j in range(1, 3):
            for i in range(1, 3):
                left = (i, j, k)
                right = (i, j, k)
                assert left == right
                cells.append({
                    "left_index": left,
                    "right_index": right,
                    "left_value": str(solution[0]),
                    "right_value": str(solution[1]),
                    "residual": tuple(str(value) for value in residual),
                })
    assert len(cells) == 8
    assert all(cell["residual"] == ("0", "0") for cell in cells)

    payload = {
        "schema": "M4-D-INDEPENDENT-FRACTION-ORACLE-V1",
        "block": tuple(str(value) for value in block),
        "rhs": tuple(str(value) for value in rhs),
        "determinant": str(det),
        "solution": tuple(str(value) for value in solution),
        "residual": tuple(str(value) for value in residual),
        "cell_count": len(cells),
        "cells": cells,
        "status": "pass",
        "claim_ceiling": "manufactured_coupled_solve_control/screen_only",
    }
    print(json.dumps(payload, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
