"""Independent canonical oracle for the manufactured conditional e-graph lane.

The oracle is deliberately Python-standard-library only.  It models a tiny
typed whole-program rewrite, its eight-condition contract, deterministic
trace replay, and the fail-closed outcomes used by the Julia adapter.  It is
not a semantic, physical, provider, or search proof.
"""

from dataclasses import dataclass
import hashlib
import json
import sys


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def canonical_hash(value):
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


KINDS = ("type", "rank", "domain", "unit", "port", "owner", "interface", "conservation")


@dataclass(frozen=True)
class Condition:
    kind: str
    contract_hash: str

    def payload(self):
        return {"kind": self.kind, "condition_contract_hash": self.contract_hash}


def condition_catalog(upstream_a="m5a-composition-v1", upstream_b="m5b-inverse-v1"):
    return tuple(Condition(k, canonical_hash({"kind": k, "a": upstream_a, "b": upstream_b})) for k in KINDS)


SOURCE = {"name": "source", "inputs": ["x", "y", "z"], "roots": ["add(x,z)", "y"]}
TARGET = {"name": "target", "inputs": ["x", "y", "z"], "roots": ["add(z,x)", "y"]}


def make_trace(catalog):
    conditions = [c.payload() for c in catalog]
    return [{"step": 1, "round": 1, "rule": "reassociate_add/v1",
             "source": SOURCE, "target": TARGET, "conditions": conditions}]


def replay(trace, catalog):
    expected = [c.payload() for c in catalog]
    if len(trace) != 1:
        return False
    step = trace[0]
    return (step["step"] == 1 and step["round"] == 1 and
            step["rule"] == "reassociate_add/v1" and step["source"] == SOURCE and
            step["target"] == TARGET and step["conditions"] == expected)


def evaluate(required, available):
    """A missing/mismatched condition yields no merge; never guess."""
    required = list(required)
    available = list(available)
    if len({c.kind for c in required}) != len(required):
        return {"merge": False, "status": "fail_closed", "reason": "contradictory_conditions"}
    ok = all(any(c == a for a in available) for c in required)
    return {"merge": ok, "status": "conditional_equal" if ok else "equality_unknown",
            "reason": "conditions_met" if ok else "condition_unmet"}


def bounded(catalog, max_rounds=1, max_trace_steps=1):
    if max_rounds <= 0 or max_trace_steps <= 0:
        return {"complete": False, "status": "terminal_deferred", "trace": []}
    trace = make_trace(catalog)
    return {"complete": True, "status": "valid", "trace": trace}


def make_payload():
    catalog = condition_catalog()
    trace = make_trace(catalog)
    return {
        "schema": "M5-MANUFACTURED-CONDITIONAL-EGRAPH-V1",
        "source": SOURCE,
        "target": TARGET,
        "conditions": [c.payload() for c in catalog],
        "trace": trace,
        "trace_hash": canonical_hash(trace),
        "replay": replay(trace, catalog),
        "same_config_hash": canonical_hash(bounded(catalog)) == canonical_hash(bounded(catalog)),
        "budget_incomplete": bounded(catalog, max_rounds=0),
        "unmet_condition": evaluate(catalog, catalog[:-1]),
        "mismatched_condition": evaluate(catalog, condition_catalog("foreign-a")),
        "contradiction": evaluate((catalog[0], catalog[0]), catalog),
        "claim_ceiling": "manufactured_conditional_egraph",
        "evidence_scope": "screen_only",
    }


def main():
    catalog = condition_catalog()
    payload = make_payload()
    assert tuple(c.kind for c in catalog) == KINDS
    assert payload["replay"]
    assert payload["same_config_hash"]
    assert payload["unmet_condition"]["merge"] is False
    assert payload["mismatched_condition"]["merge"] is False
    assert payload["contradiction"]["status"] == "fail_closed"
    assert payload["budget_incomplete"]["status"] == "terminal_deferred"
    print("CONDITIONAL-EGRAPH-ORACLE PASS")
    print(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"CONDITIONAL-EGRAPH-ORACLE FAIL: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise
