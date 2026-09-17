"""Independent exact oracle for the isolated M4-B residual lane.

Only the frozen manufactured scalar control is represented.  This file must
not import Julia or any production module: Fraction arithmetic is the
independent source of truth for the three divergence contributions.
"""

from fractions import Fraction
import json
import sys


def canonical_payload():
    terms = (Fraction(1, 10), Fraction(1, 20), Fraction(1, 30))
    total = sum(terms, Fraction(0, 1))
    source = Fraction(-11, 60)
    residual = -total - source
    assert total == Fraction(11, 60), total
    assert source == Fraction(-11, 60), source
    assert residual == Fraction(0, 1), residual
    assert abs(float(residual)) <= 1e-12

    return {
        "schema": "m4-b-residual-lowering-oracle-v1",
        "equation_id": "M4-MANUFACTURED-DIFFUSION-V1",
        "domain": {"id": "Omega", "dimension": 3,
                   "bounds_m": [[0, 1], [0, 1], [0, 1]],
                   "length_scale_m": "1"},
        "field": {"id": "u", "units": "1"},
        "operator": {"id": "NEG_DIV_K_GRAD_MINUS_SOURCE", "version": "v1",
                      "expression": "-div(K*grad(u)) - f = 0"},
        "source": {"id": "f", "equation_id": "M4-MANUFACTURED-DIFFUSION-V1",
                   "units": "1", "owner": "M4-A-manufactured-source"},
        "coefficient": {"units": "m^2"},
        "conservation_owner": "M4-A-equation-balance",
        "exact": {
            "terms": ["1/10", "1/20", "1/30"],
            "divergence_total": "11/60",
            "source": "-11/60",
            "residual": "0",
        },
        "claim_ceiling": "manufactured_residual_lowering",
        "evidence_scope": "screen_only",
        "time_scope": "terminal_deferred",
        "multifield_scope": "terminal_deferred",
        "discrete": "not_performed",
        "assembly": "not_performed",
        "solver": "not_performed",
        "coupling": "not_performed",
        "candidate": "not_bound",
        "provider": "not_invoked",
    }


def main():
    # Compact sorted JSON is the canonical byte representation used by the
    # execution receipt and is intentionally independent of Julia show().
    sys.stdout.write(json.dumps(canonical_payload(), sort_keys=True,
                                separators=(",", ":"), allow_nan=False) + "\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"oracle_failure: {exc}", file=sys.stderr)
        raise
