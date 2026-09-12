"""Reproducible five-node geometry comparison against the frozen DESC member."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import desc.io
import numpy as np

from evaluate_interior import DEFAULT_INTERIOR, ROOT, evaluate_rz, load_subject
from normalize_reference import sha256_file


POINTS = (
    (0.0, 0.0, 0.0),
    (0.2, 0.13, 0.02),
    (0.47, 1.1, 0.09),
    (0.85, 2.4, 0.23),
    (1.0, 3.8, 0.31),
)
TOLERANCE_M = 1e-9


def compare(input_path: Path = DEFAULT_INTERIOR) -> dict:
    subject = load_subject(input_path)
    artifact = ROOT / "HELIOTRON_output.h5"
    family = desc.io.load(artifact)
    selected = family[subject["selected_equilibrium_index"]]
    rows = []
    for point in POINTS:
        node = np.asarray([point])
        expected = (
            float((np.asarray(selected.R_basis.evaluate(node)) @
                   np.asarray(selected.R_lmn))[0]),
            float((np.asarray(selected.Z_basis.evaluate(node)) @
                   np.asarray(selected.Z_lmn))[0]),
        )
        actual = evaluate_rz(subject, *point)
        absolute_error = [abs(a - b) for a, b in zip(actual, expected)]
        rows.append({
            "node_rho_theta_zeta_radians": list(point),
            "independent_RZ_m": list(actual),
            "desc_RZ_m": list(expected),
            "absolute_error_RZ_m": absolute_error,
            "pass": all(value <= TOLERANCE_M for value in absolute_error),
        })
    result = {
        "schema_version": "n2-source-interior-evaluation-comparison-v1",
        "source_artifact_sha256": sha256_file(artifact),
        "interior_result_sha256": sha256_file(input_path),
        "interior_subject_sha256": hashlib.sha256(
            json.loads(input_path.read_text(encoding="utf-8"))[
                "subject_canonical_json"].encode("utf-8")).hexdigest(),
        "selected_equilibrium_index": subject["selected_equilibrium_index"],
        "predeclared_tolerance_m": TOLERANCE_M,
        "rows": rows,
        "all_nodes_pass": all(row["pass"] for row in rows),
        "authority": {
            "scope": "same_DESC_family_geometry_basis_numeric_reconstruction_only",
            "independent_physical_solver": False,
            "measurement": False,
            "inverse_ready": False,
            "held_out_prediction_ready": False,
            "physical_validation": "unsupported",
            "credible_device_count": 0,
        },
    }
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--input", type=Path, default=DEFAULT_INTERIOR)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("refusing to overwrite an existing comparison")
    result = compare(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"N2_INTERIOR_COMPARISON_OUTPUT={args.output.resolve()}")
    print(f"N2_INTERIOR_COMPARISON_PASS={int(result['all_nodes_pass'])}")
    print("N2_PHYSICAL_VALIDATION=unsupported")
    return 0 if result["all_nodes_pass"] else 4


if __name__ == "__main__":
    raise SystemExit(main())
