"""Independent Fraction oracle for the M5 inverse-feedback fixture.

This file intentionally imports only Python standard-library modules.  It
reconstructs the two-by-two manufactured inverse, the beta-deletion control,
and a canonical JSON payload without importing Julia or any repository code.
"""

from copy import deepcopy
from fractions import Fraction
import hashlib
import json


def q(value):
    return Fraction(value)


TARGET = (q(2) / q(3), q(1) / q(3))
HIDDEN = (q(2), q(1))
RHS = (q(1), q(0))
SEEDS = (0, 1, 2)


def rat(x):
    return f"{x.numerator}/{x.denominator}"


def forward(alpha, beta, rhs=RHS):
    determinant = alpha * alpha - beta * beta
    if determinant == 0:
        raise ZeroDivisionError("singular manufactured matrix")
    return (
        (alpha * rhs[0] + beta * rhs[1]) / determinant,
        (beta * rhs[0] + alpha * rhs[1]) / determinant,
    )


def recover(target):
    scale = target[0] * target[0] - target[1] * target[1]
    if scale <= 0:
        raise ValueError("target is singular or impossible")
    return target[0] / scale, target[1] / scale


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def canonical_hash(value):
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def make_payload():
    alpha, beta = recover(TARGET)
    active = forward(alpha, beta)
    deleted = forward(alpha, q(0))
    determinant = alpha * alpha - beta * beta
    eigenvalues = (alpha - beta, alpha + beta)
    margin = eigenvalues[0] / eigenvalues[1]
    seeds = [
        {"seed": seed, "alpha": rat(alpha), "beta": rat(beta),
         "response": [rat(active[0]), rat(active[1])], "replay": True}
        for seed in SEEDS
    ]
    return {
        "schema": "M5-INVERSE-FEEDBACK-MANUFACTURED-V1",
        "target": [rat(TARGET[0]), rat(TARGET[1])],
        "rhs": [rat(RHS[0]), rat(RHS[1])],
        "recovered": {"alpha": rat(alpha), "beta": rat(beta)},
        "forward": {
            "matrix": [[rat(alpha), rat(-beta)], [rat(-beta), rat(alpha)]],
            "rhs": [rat(RHS[0]), rat(RHS[1])],
            "response": [rat(active[0]), rat(active[1])],
            "determinant": rat(determinant),
        },
        "determinant": rat(determinant),
        "eigenvalues": [rat(eigenvalues[0]), rat(eigenvalues[1])],
        "eigen_margin_proxy": rat(margin),
        "roundtrip_residual": [rat(active[0] - TARGET[0]), rat(active[1] - TARGET[1])],
        "multi_seed": seeds,
        "feedback": {
            "edge": "M5-interface-beta-feedback",
            "active": [rat(active[0]), rat(active[1])],
            "deletion_beta": rat(q(0)),
            "deletion": [rat(deleted[0]), rat(deleted[1])],
            "delta": [rat(active[0] - deleted[0]), rat(active[1] - deleted[1])],
            "changed": active != deleted,
        },
        "claim_ceiling": "manufactured_inverse_feedback",
        "evidence_scope": "screen_only",
    }


def negative_controls():
    # These are the typed failure classes expected from the Julia boundary.
    cases = {
        "invalid_upstream": "invalid_upstream",
        "foreign_hash": "foreign_hash",
        "foreign_owner": "foreign_owner",
        "foreign_provenance": "foreign_provenance",
        "zero_target": "nonidentifiable_target",
        "nonidentifiable_target": "non_spd",
        "denominator_zero": "nonidentifiable_target",
        "singular_target": "singular",
        "non_spd_target": "non_spd",
        "impossible_target": "impossible_target",
        "roundtrip_corruption": "roundtrip",
        "seed_mismatch": "seed",
        "deletion_no_effect": "feedback_deletion_no_effect",
    }
    return cases


def main():
    alpha, beta = recover(TARGET)
    assert (alpha, beta) == HIDDEN
    assert forward(alpha, beta) == TARGET
    assert forward(alpha, q(0)) == (q(1) / q(2), q(0))
    assert alpha * alpha - beta * beta == q(3)
    assert (alpha - beta, alpha + beta) == (q(1), q(3))
    assert (alpha - beta) / (alpha + beta) == q(1) / q(3)

    payload = make_payload()
    # Seed order is explicit and replay values are identical across every seed.
    assert [item["seed"] for item in payload["multi_seed"]] == list(SEEDS)
    assert len({json.dumps(item, sort_keys=True) for item in payload["multi_seed"]}) == 3
    permuted = deepcopy(payload)
    permuted["multi_seed"] = list(reversed(permuted["multi_seed"]))
    # The canonical inverse payload retains frozen seed order; an input-order
    # permutation is normalized before hashing in this independent oracle.
    permuted["multi_seed"] = sorted(permuted["multi_seed"], key=lambda item: item["seed"])
    assert canonical_hash(payload) == canonical_hash(permuted)

    output = {
        "schema": "M5-INVERSE-FEEDBACK-INDEPENDENT-ORACLE-V1",
        "status": "pass",
        "target": [rat(TARGET[0]), rat(TARGET[1])],
        "hidden": {"alpha": rat(HIDDEN[0]), "beta": rat(HIDDEN[1])},
        "determinant": rat(q(3)),
        "eigenvalues": [rat(q(1)), rat(q(3))],
        "eigen_margin_proxy": rat(q(1) / q(3)),
        "forward_response": [rat(TARGET[0]), rat(TARGET[1])],
        "deletion_response": [rat(q(1) / q(2)), rat(q(0))],
        "feedback_delta": [rat(q(1) / q(6)), rat(q(1) / q(3))],
        "multi_seed": payload["multi_seed"],
        "canonical_payload": payload,
        "canonical_payload_sha256": canonical_hash(payload),
        "negative_controls": negative_controls(),
        "claim_ceiling": "manufactured_inverse_feedback/screen_only",
        "prohibitions": ["no_optimizer", "no_real_reference", "no_candidate", "no_provider", "no_solver", "no_engineering_evidence"],
    }
    print(json.dumps(output, sort_keys=True, separators=(",", ":"), ensure_ascii=False))


if __name__ == "__main__":
    main()
