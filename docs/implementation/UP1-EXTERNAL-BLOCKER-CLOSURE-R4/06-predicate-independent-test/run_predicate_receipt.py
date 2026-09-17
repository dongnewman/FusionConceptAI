"""Emit one machine receipt for the independent 26-vector predicate replay."""
from __future__ import annotations

import hashlib
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
REPO = HERE.parents[4]
TEST_DIR = REPO / "test" / "up1_external_closure_r3" / "atomic_bundle"
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(TEST_DIR))

from test_atomic_bundle_vectors import (  # noqa: E402
    _json_bytes,
    _semantic_execute,
    all_vectors,
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def main() -> int:
    started = utc_now()
    rows = []
    for vector in all_vectors():
        built = vector.build()
        raw = _json_bytes(built)
        actual_code, called_function, result = _semantic_execute(vector, built, raw)
        expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
        if actual_code != expected_code or result["decision"] != vector.decision or not called_function:
            raise AssertionError({
                "vector_id": vector.vector_id,
                "expected_code": expected_code,
                "actual_code": actual_code,
                "expected_decision": vector.decision,
                "actual_decision": result["decision"],
                "called_function": called_function,
            })
        rows.append({
            "vector_id": vector.vector_id,
            "mutation_path": vector.mutation_path,
            "input_sha256": hashlib.sha256(raw).hexdigest(),
            "expected_code": expected_code or "no_failure_code",
            "actual_code": actual_code or "no_failure_code",
            "expected_decision": vector.decision,
            "actual_decision": result["decision"],
            "called_function": called_function,
            "no_publish": bool(result["no_publish"]),
        })
    finished = utc_now()
    receipt = {
        "schema": "UP1-R4.predicate-independent-test.receipt.v1",
        "status": "pass_limited",
        "claim_ceiling": "prototype_test_only",
        "run": {"pid": os.getpid(), "started_utc": started, "finished_utc": finished, "exit_code": 0},
        "vectors": rows,
        "count": len(rows),
        "expected_count": 26,
        "all_no_publish": all(row["no_publish"] for row in rows),
        "limitations": {
            "R01_R23": "public validate_bundle parser/schema path retained",
            "R08_R15_R17_R22": "actual existing production paths retained",
            "R22": "direct semantic harness uses a clean EHP-04 payload because the complete wire envelope has a self-referential quarantine raw digest",
            "symlink_reparse_probe": "host-dependent; the repair suite records a skip when Windows symlink privilege is unavailable",
            "authority_credit": False,
        },
    }
    print(json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
