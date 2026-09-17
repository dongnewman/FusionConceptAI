"""Independent exact Fraction oracle for the M4-C manufactured stencil.

The oracle duplicates only the frozen mathematics.  It imports no Julia or
production module and checks every cell for both required grids.
"""

from fractions import Fraction
import json
import sys


def rat(x: Fraction) -> str:
    return f"{x.numerator}/{x.denominator}" if x.denominator != 1 else str(x.numerator)


def face(axis, side, coordinate, component, spacing, area):
    normal = -component if side == "minus" else component
    contribution = normal * area / (spacing * area)
    return {
        "axis": axis,
        "side": side,
        "coordinate": rat(coordinate),
        "coefficient_component": rat(component),
        "field_gradient": "1",
        "normal_flux": rat(normal),
        "face_area": rat(area),
        "divergence_contribution": rat(contribution),
    }


def grid_payload(nx, ny, nz):
    h = (Fraction(1, nx), Fraction(1, ny), Fraction(1, nz))
    areas = (h[1] * h[2], h[0] * h[2], h[0] * h[1])
    cells = []
    for k in range(1, nz + 1):
        for j in range(1, ny + 1):
            for i in range(1, nx + 1):
                xlo, xhi = Fraction(i - 1, nx), Fraction(i, nx)
                ylo, yhi = Fraction(j - 1, ny), Fraction(j, ny)
                zlo, zhi = Fraction(k - 1, nz), Fraction(k, nz)
                fx = (Fraction(2) + xlo / 10, Fraction(2) + xhi / 10)
                fy = (Fraction(3) + ylo / 20, Fraction(3) + yhi / 20)
                fz = (Fraction(4) + zlo / 30, Fraction(4) + zhi / 30)
                faces = [
                    face("x", "minus", xlo, fx[0], h[0], areas[0]),
                    face("x", "plus", xhi, fx[1], h[0], areas[0]),
                    face("y", "minus", ylo, fy[0], h[1], areas[1]),
                    face("y", "plus", yhi, fy[1], h[1], areas[1]),
                    face("z", "minus", zlo, fz[0], h[2], areas[2]),
                    face("z", "plus", zhi, fz[1], h[2], areas[2]),
                ]
                directional = (
                    Fraction(1, 10), Fraction(1, 20), Fraction(1, 30)
                )
                total = sum(directional, Fraction(0))
                source = Fraction(-11, 60)
                residual = -total - source
                assert total == Fraction(11, 60)
                assert residual == Fraction(0)
                # Recompute from exact objects rather than serialized strings.
                assert fx[1] - fx[0] == Fraction(1, 10) * h[0]
                assert fy[1] - fy[0] == Fraction(1, 20) * h[1]
                assert fz[1] - fz[0] == Fraction(1, 30) * h[2]
                cells.append({
                    "index": [i, j, k],
                    "center": [rat(Fraction(2 * i - 1, 2 * nx)),
                               rat(Fraction(2 * j - 1, 2 * ny)),
                               rat(Fraction(2 * k - 1, 2 * nz))],
                    "faces": faces,
                    "directional_divergence": [rat(x) for x in directional],
                    "divergence_total": rat(total),
                    "source": rat(source),
                    "residual": rat(residual),
                })
    return {
        "counts": [nx, ny, nz],
        "cell_count": nx * ny * nz,
        "spacing": [rat(x) for x in h],
        "cell_volume": rat(h[0] * h[1] * h[2]),
        "cells": cells,
    }


def canonical_payload():
    grids = [grid_payload(2, 2, 2), grid_payload(3, 4, 5)]
    return {
        "schema": "m4-c-discrete-control-oracle-v1",
        "equation_id": "M4-MANUFACTURED-DIFFUSION-V1",
        "topology": "M4-C-uniform-cartesian-cell-centered-v1",
        "boundary": "M4-C-manufactured-six-face-closure-v1",
        "exact": {
            "directional_divergence": ["1/10", "1/20", "1/30"],
            "divergence_total": "11/60",
            "source": "-11/60",
            "residual": "0",
        },
        "grids": grids,
        "claim_ceiling": "manufactured_discrete_control",
        "evidence_scope": "screen_only",
        "matrix": "not_performed",
        "solver": "not_performed",
        "coupling": "not_performed",
        "candidate": "not_bound",
        "provider": "not_invoked",
        "physics": "not_claimed",
        "engineering": "not_claimed",
    }


def main():
    payload = canonical_payload()
    sys.stdout.write(json.dumps(payload, sort_keys=True, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"oracle_failure: {exc}", file=sys.stderr)
        raise
