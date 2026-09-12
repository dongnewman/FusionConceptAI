"""Independent scalar Fourier-Zernike reconstruction of frozen source data.

The input must pass the source-interior wire/authority validator first. This
only evaluates geometry; it does not solve an equilibrium or grant validation.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from scipy.special import eval_jacobi

from normalize_interior import validate_interior
from normalize_reference import sha256_file


ROOT = Path(__file__).resolve().parent
DEFAULT_INTERIOR = (ROOT.parents[1] / "runs" /
    "goal_recovery_20260913_012528_cst" /
    "n2_desc_heliotron_interior_r1" / "result.json")


def _zernike_radial(l: int, m: int, rho: float) -> float:
    absolute_m = abs(m)
    if l < absolute_m or (l - absolute_m) % 2:
        return 0.0
    order = (l - absolute_m) // 2
    return ((-1.0) ** order * rho ** absolute_m *
            float(eval_jacobi(order, absolute_m, 0, 1 - 2 * rho * rho)))


def _fourier(angle: float, mode: int, nfp: int = 1) -> float:
    phase = abs(mode) * nfp * angle
    return math.cos(phase) if mode >= 0 else math.sin(phase)


def evaluate_component(component: dict, rho: float, theta: float,
                       zeta: float, nfp: int) -> float:
    if not all(math.isfinite(value) for value in (rho, theta, zeta)) or not 0 <= rho <= 1:
        raise ValueError("evaluation point must have finite angles and rho in [0,1]")
    return math.fsum(
        term["coefficient_m"] *
        _zernike_radial(term["l"], term["m"], rho) *
        _fourier(theta, term["m"]) *
        _fourier(zeta, term["n"], nfp)
        for term in component["terms"])


def load_subject(path: Path = DEFAULT_INTERIOR) -> dict:
    record = json.loads(path.read_text(encoding="utf-8"))
    source_manifest = json.loads((ROOT / "source.json").read_text(encoding="utf-8"))
    artifact = ROOT / source_manifest["artifact"]["path"]
    actual_source_hash = sha256_file(artifact)
    if actual_source_hash != source_manifest["artifact"]["sha256"]:
        raise ValueError("source artifact hash mismatch")
    validate_interior(record, expected_source_hash=actual_source_hash)
    return record["subject"]


def evaluate_rz(subject: dict, rho: float, theta: float,
                zeta: float) -> tuple[float, float]:
    nfp = subject["source_resolution"]["NFP"]
    return (evaluate_component(subject["R"], rho, theta, zeta, nfp),
            evaluate_component(subject["Z"], rho, theta, zeta, nfp))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INTERIOR)
    parser.add_argument("--rho", type=float, required=True)
    parser.add_argument("--theta", type=float, required=True,
                        help="physical poloidal radians")
    parser.add_argument("--zeta", type=float, required=True,
                        help="physical toroidal radians")
    args = parser.parse_args()
    subject = load_subject(args.input)
    R, Z = evaluate_rz(subject, args.rho, args.theta, args.zeta)
    print(json.dumps({"R_m": R, "Z_m": Z,
                      "authority": "external_simulation_geometry_only",
                      "provider_executed": False,
                      "physical_validation": "unsupported"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
