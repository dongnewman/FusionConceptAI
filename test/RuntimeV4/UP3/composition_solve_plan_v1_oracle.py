"""Independent schema oracle for the UP3 composition-solve contract fixture.

This oracle validates only the frozen contract matrix and deterministic
identity recipe. It does not import Julia, invoke a provider, or solve.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


FIXTURE = Path(__file__).with_name("composition_solve_plan_v1_fixture.json")


def canonical_hash(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()
    return hashlib.sha256(payload).hexdigest()


def validate_fixture(fixture: dict) -> dict:
    assert fixture["schema"] == "fusionconceptai:composition-solve-plan-v1"
    assert fixture["claim_ceiling"] == "contract_only"
    assert fixture["accepted"] is False
    assert fixture["provider_invocation_count"] == 0
    assert fixture["solver_invocation_count"] == 0
    assert fixture["positive"] == {
        "status": "ready", "edges": 2, "outcome_code": "ready",
        "stage_spaces": ["chain-space-a", "chain-space-b"],
    }
    assert fixture["mimo"] == {
        "status": "ready", "edges": 2, "parallel_component_pairs": 1,
    }
    assert set(fixture["deferred"]) >= {
        "missing_binding", "binding_missing_matrix", "provider_missing", "code_missing", "backend_missing",
        "singular_preclassified", "nonconvergent_preclassified",
    }
    assert set(fixture["fail_closed"]) >= {
        "unit_mismatch", "space_mismatch", "direction_mismatch", "provider_poisoning",
        "code_poisoning", "backend_poisoning", "protocol_mismatch", "ambiguous_match",
        "ambiguous_with_deferred",
        "unmatched_port", "cycle", "duplicate_component", "duplicate_port",
        "missing_ledger", "invalid_input",
    }
    assert fixture["preclassified"] == {
        "singular": "terminal_deferred",
        "nonconvergent": "terminal_deferred",
    }
    assert fixture["constructor_rejected"] == [
        "invalid_port_direction", "invalid_preclassification_bool",
    ]
    assert fixture["negative_expectations"]["invalid_port_direction"] == {
        "status": "constructor_rejected", "code": "invalid_port_direction"
    }
    vectors = set(fixture["deferred"] + fixture["fail_closed"]
                  + fixture["constructor_rejected"])
    assert set(fixture["negative_expectations"]) == vectors
    assert fixture["negative_expectations"]["direction_mismatch"] == {
        "status": "fail_closed", "code": "direction_mismatch"
    }
    assert fixture["negative_expectations"]["ambiguous_match"] == {
        "status": "fail_closed", "code": "ambiguous_match"
    }
    assert fixture["negative_expectations"]["ambiguous_with_deferred"] == {
        "status": "fail_closed", "code": "ambiguous_match"
    }
    identity = {"schema": fixture["schema"], "positive": fixture["positive"],
                "provider_invocation_count": 0, "solver_invocation_count": 0}
    return {"fixture_identity_sha256": canonical_hash(identity), "status": "pass"}


def main() -> int:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    print(json.dumps(validate_fixture(fixture), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
