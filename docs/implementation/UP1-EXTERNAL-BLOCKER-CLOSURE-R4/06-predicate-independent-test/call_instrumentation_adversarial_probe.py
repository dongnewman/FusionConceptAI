"""Run an independent transparent-trap probe over the newly-owned predicates."""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch

HERE = Path(__file__).resolve()
REPO = HERE.parents[4]
TEST_DIR = REPO / "test" / "up1_external_closure_r3" / "atomic_bundle"
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(TEST_DIR))

from test_atomic_bundle_vectors import (  # noqa: E402
    _OWNED_PREDICATES,
    _json_bytes,
    _semantic_execute,
    all_vectors,
)
from tools.up1_external_closure_r3.atomic_bundle import bundle as impl  # noqa: E402


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def main() -> int:
    started = utc_now()
    vectors = {vector.vector_id: vector for vector in all_vectors()}
    rows = []
    for vector_id, function_name in _OWNED_PREDICATES.items():
        vector = vectors[vector_id]
        built = vector.build()
        raw = _json_bytes(built)
        observed: list[str] = []
        original = getattr(impl, function_name)

        def trap(*args, _original=original, _name=function_name, **kwargs):
            observed.append(_name)
            return _original(*args, **kwargs)

        with patch.object(impl, function_name, trap):
            actual_code, called_function, result = _semantic_execute(vector, built, raw)
        expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
        if observed != [function_name] or called_function != function_name or actual_code != expected_code or result["decision"] != vector.decision:
            raise AssertionError({"vector_id": vector_id, "observed": observed, "called_function": called_function, "actual_code": actual_code, "expected_code": expected_code, "actual_decision": result["decision"], "expected_decision": vector.decision})
        rows.append({"vector_id": vector_id, "target_function": function_name, "trap_invocations": observed, "called_function": called_function, "actual_code": actual_code or "no_failure_code", "actual_decision": result["decision"], "no_publish": bool(result["no_publish"])})
    receipt = {"schema": "UP1-R4.predicate-independent-test.adversarial-probe.v1", "status": "pass_limited", "run": {"pid": os.getpid(), "started_utc": started, "finished_utc": utc_now(), "exit_code": 0}, "target_count": len(rows), "targets": rows, "probe": "transparent trap delegates to original production function; bypass yields missing trap invocation and fails closed", "authority_credit": False}
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
