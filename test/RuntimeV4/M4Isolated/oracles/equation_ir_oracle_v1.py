"""Independent, standard-library oracle for the frozen M4-A equation.

This oracle intentionally does not import production code or perform residual
lowering.  It derives the manufactured divergence using Fraction arithmetic
and emits one canonical JSON document for the scalar steady control only.
"""

from fractions import Fraction
import json
import math
import sys


def canonical_payload():
    # L = 1 m; u = x/L + y/L + z/L, so each component of grad(u) is 1/L.
    # For diagonal K, d(K_ii * d_i u)/d_i is the slope of K_ii divided by L.
    length_scale_m = Fraction(1, 1)
    slopes = (Fraction(1, 10), Fraction(1, 20), Fraction(1, 30))
    div_k_grad_u = sum(slopes) / (length_scale_m * length_scale_m)
    source = Fraction(-11, 60)
    residual = -div_k_grad_u - source
    residual_float = float(residual)

    if div_k_grad_u != Fraction(11, 60):
        raise AssertionError(f"divergence mismatch: {div_k_grad_u}")
    if residual != Fraction(0, 1):
        raise AssertionError(f"manufactured residual mismatch: {residual}")
    if abs(residual_float) > 1e-12:
        raise AssertionError(f"floating residual exceeds tolerance: {residual_float}")

    # Keep all exact terms explicit so an independent consumer can audit the
    # derivation without interpreting a production IR or lowering routine.
    return {
        "schema": "m4-a-equation-ir-oracle-v1",
        "equation_id": "M4-MANUFACTURED-DIFFUSION-V1",
        "domain": {"bounds_m": [[0, 1], [0, 1], [0, 1]], "length_scale_m": "1"},
        "field": {"id": "u", "expression": "x/L + y/L + z/L", "units": "1"},
        "coefficient": {
            "id": "K",
            "units": "m^2",
            "diagonal_terms": ["2 + 0.1*x/L", "3 + 0.05*y/L", "4 + z/(30*L)"],
            "slope_terms": ["1/10", "1/20", "1/30"],
            "positive_lower_bounds": ["2", "3", "4"],
        },
        "operator": {"id": "NEG_DIV_K_GRAD_MINUS_SOURCE", "version": "v1", "residual": "-div(K*grad(u)) - f"},
        "source": {"id": "f", "value": "-11/60", "units": "1"},
        "exact": {
            "div_k_grad_u": "11/60",
            "source": "-11/60",
            "residual": "0",
        },
        "float_checks": {"residual": residual_float, "abs_tolerance": 1e-12},
        "status": "manufactured_control",
        "claim_ceiling": "screen_only",
        "lowering": "not_performed",
    }


def main():
    payload = canonical_payload()
    # sort_keys and compact separators make the bytes deterministic.
    sys.stdout.write(json.dumps(payload, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"oracle_failure: {exc}", file=sys.stderr)
        raise
