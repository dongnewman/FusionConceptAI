"""Independent deterministic digest oracle for the T1 static fixture.

This is deliberately independent of Julia canonicalization and does not claim
to reproduce a Julia package hash. It proves that the frozen, reviewable
contract input has one stable SHA-256 digest before runtime execution.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


FIXTURE = Path(__file__).with_name("vnext_t1_candidate_state_package_v5_next_fixture.json")


def canonical_bytes(payload: object) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def expected_digest() -> str:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    return hashlib.sha256(canonical_bytes(fixture["oracle_payload"])).hexdigest()


def fixed_pattern_digests() -> dict[str, str]:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    expected = fixture["sha256_vector_pattern"]["expected"]
    actual = {
        str(length): hashlib.sha256(bytes(i % 251 for i in range(int(length)))).hexdigest()
        for length in expected
    }
    if actual != expected:
        raise AssertionError(
            f"fixed vector digest mismatch: expected {expected}, got {actual}"
        )
    return actual


def main() -> int:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    actual = expected_digest()
    expected = fixture["oracle_expected_sha256"]
    if actual != expected:
        raise AssertionError(f"oracle digest mismatch: expected {expected}, got {actual}")
    fixed = fixed_pattern_digests()
    print(f"ORACLE_CANONICAL_BYTES_SHA256={actual}")
    print("ORACLE_INPUT=fixture.oracle_payload")
    print(f"ORACLE_FIXED_VECTOR_DIGESTS={len(fixed)}")
    print("ORACLE_RUNTIME=NOT_RUN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
