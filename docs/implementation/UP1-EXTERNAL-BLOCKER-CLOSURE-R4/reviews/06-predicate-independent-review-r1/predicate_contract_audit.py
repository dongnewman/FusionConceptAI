"""Independent audit of the frozen predicate result contract.

This review-only probe imports the frozen production implementation and the
existing test vector builders.  It does not replace or mutate a predicate.
"""
from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve()
REPO = HERE.parents[5]
TEST_DIR = REPO / "test" / "up1_external_closure_r3" / "atomic_bundle"
sys.path.insert(0, str(REPO))
sys.path.insert(0, str(TEST_DIR))

from test_atomic_bundle_vectors import (  # noqa: E402
    _CALLED_FUNCTION,
    _json_bytes,
    _semantic_execute,
    all_vectors,
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def main() -> int:
    started = utc_now()
    rows = []
    hashes = []
    expected_owned = {"R02", "R03", "R04", "R05", "R06", "R07", "R24", "R25", "D01"}
    for vector in all_vectors():
        built = vector.build()
        raw = _json_bytes(built)
        actual_code, called_function, result = _semantic_execute(vector, built, raw)
        expected_code = None if vector.expected in {"no_failure_code", "internal accepted_all only"} else vector.expected
        digest = hashlib.sha256(raw).hexdigest()
        hashes.append(digest)
        rows.append({
            "vector_id": vector.vector_id,
            "input_sha256": digest,
            "expected_code": expected_code or "no_failure_code",
            "actual_code": actual_code or "no_failure_code",
            "expected_decision": vector.decision,
            "actual_decision": result["decision"],
            "called_function": called_function,
            "expected_function": _CALLED_FUNCTION.get(vector.vector_id, "validate_bundle"),
            "no_publish": bool(result["no_publish"]),
            "formal_credit": result["formal_credit"],
            "authority_credit": bool(result["authority_credit"]),
        })
    mismatches = [row for row in rows if row["expected_code"] != row["actual_code"] or row["expected_decision"] != row["actual_decision"] or row["called_function"] != row["expected_function"]]
    owned = [row for row in rows if row["vector_id"] in expected_owned]
    checks = {
        "count_26_of_26": len(rows) == 26,
        "unique_input_sha256_26_of_26": len(set(hashes)) == 26,
        "expected_code_decision_function_exact": not mismatches,
        "all_no_publish": all(row["no_publish"] for row in rows),
        "all_formal_credit_none": all(row["formal_credit"] == "none" for row in rows),
        "all_authority_credit_false": all(not row["authority_credit"] for row in rows),
        "owned_predicates_exactly_9": len(owned) == 9 and {row["vector_id"] for row in owned} == expected_owned,
        "owned_predicate_runtime_functions_present": all(row["called_function"] == row["expected_function"] for row in owned),
    }
    status = "pass_limited" if all(checks.values()) else "fail_limited"
    print(json.dumps({
        "schema": "UP1-R4.predicate-independent-review-r1.contract-audit.v1",
        "status": status,
        "claim_ceiling": "prototype_test_only",
        "run": {"pid": __import__("os").getpid(), "started_utc": started, "finished_utc": utc_now(), "exit_code": 0 if status == "pass_limited" else 1},
        "checks": checks,
        "rows": rows,
        "limitations": {
            "R22": "direct semantic harness uses a clean EHP-04 payload because the complete wire envelope has a self-referential quarantine raw digest",
            "authority_and_publication": "formal_credit=none, authority_credit=false, no_publish=true for every vector",
            "symlink_reparse_probe": "host-dependent; repair suite records a skip when Windows symlink privilege is unavailable",
        },
    }, sort_keys=True, separators=(",", ":")))
    return 0 if status == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
