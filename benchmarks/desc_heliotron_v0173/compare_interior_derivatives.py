"""Frozen same-source DESC derivative and Cartesian Gram-metric receipt.

This verifies basis semantics only. It is not an independent physical solver,
an admissibility certificate, or a field-equilibrium validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import desc.io
import numpy as np

from compare_interior import POINTS
from evaluate_interior import DEFAULT_INTERIOR, ROOT, load_subject
from normalize_reference import sha256_file


DERIVATIVE_TOLERANCE_M = 1e-8
GRAM_TOLERANCE_M2 = 1e-7
DERIVATIVES = ((0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1))


def _desc_component(basis, coefficients, node):
    return [float((np.asarray(basis.evaluate(node, derivatives=derivative)) @
                   np.asarray(coefficients))[0]) for derivative in DERIVATIVES]


def _gram(r, z, zeta):
    cos_zeta, sin_zeta = math.cos(zeta), math.sin(zeta)
    vectors = (
        (r[1] * cos_zeta, r[1] * sin_zeta, z[1]),
        (r[2] * cos_zeta, r[2] * sin_zeta, z[2]),
        (r[3] * cos_zeta - r[0] * sin_zeta,
         r[3] * sin_zeta + r[0] * cos_zeta, z[3]),
    )
    return [[sum(a * b for a, b in zip(vectors[i], vectors[j]))
             for j in range(3)] for i in range(3)]


def compare(input_path: Path = DEFAULT_INTERIOR) -> dict:
    subject = load_subject(input_path)
    artifact = ROOT / "HELIOTRON_output.h5"
    selected = desc.io.load(artifact)[subject["selected_equilibrium_index"]]
    rows = []
    for point in POINTS:
        node = np.asarray([point])
        radial = _desc_component(selected.R_basis, selected.R_lmn, node)
        vertical = _desc_component(selected.Z_basis, selected.Z_lmn, node)
        rows.append({
            "node_rho_theta_zeta_radians": list(point),
            "desc_R_and_derivatives_m": radial,
            "desc_Z_and_derivatives_m": vertical,
            "desc_cartesian_gram_m2": _gram(radial, vertical, point[2]),
        })
    return {
        "schema_version": "n2-source-interior-derivative-receipt-v1",
        "source_artifact_sha256": sha256_file(artifact),
        "interior_result_sha256": sha256_file(input_path),
        "interior_subject_sha256": hashlib.sha256(
            json.loads(input_path.read_text(encoding="utf-8"))[
                "subject_canonical_json"].encode("utf-8")).hexdigest(),
        "selected_equilibrium_index": 3,
        "derivative_order": [list(d) for d in DERIVATIVES],
        "predeclared_absolute_derivative_tolerance_m": DERIVATIVE_TOLERANCE_M,
        "predeclared_absolute_gram_tolerance_m2": GRAM_TOLERANCE_M2,
        "rows": rows,
        "authority": {
            "scope": "same_DESC_family_geometry_derivative_and_metric_basis_only",
            "claim_ceiling": "screen_only",
            "metric_positivity_certified": False,
            "independent_physical_solver": False,
            "physical_validation": "unsupported",
            "credible_device_count": 0,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--input", type=Path, default=DEFAULT_INTERIOR)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("refusing to overwrite an existing derivative receipt")
    receipt = compare(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"N2_DERIVATIVE_RECEIPT={args.output.resolve()}")
    print("N2_PHYSICAL_VALIDATION=unsupported")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
