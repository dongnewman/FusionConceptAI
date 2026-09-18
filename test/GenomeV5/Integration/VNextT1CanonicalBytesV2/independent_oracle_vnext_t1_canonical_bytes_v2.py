"""Independent byte/hash/base64 oracle for the VNext T1 V2 slice.

This file deliberately does not import Julia, FusionConceptAI, or the source
implementation.  It is a cross-process replay oracle over fixture.json.
"""

from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path


def materialize(case: dict) -> bytes:
    if "bytes" in case:
        return bytes(case["bytes"])
    pattern = case["pattern"]
    return bytes(
        (i * pattern["multiplier"] + pattern["offset"]) % pattern["modulo"]
        for i in range(case["length"])
    )


def check_case(case: dict) -> int:
    payload = materialize(case)
    assert len(payload) == case["length"], case["id"]
    assert hashlib.sha256(payload).hexdigest() == case["sha256"], case["id"]
    if "base64" in case:
        assert base64.b64encode(payload).decode("ascii") == case["base64"], case["id"]
    return 3 if "base64" in case else 2


def main() -> int:
    fixture = json.loads(Path(__file__).with_name("fixture.json").read_text(encoding="utf-8"))
    assert fixture["schema"] == "GenomeV5/Contracts/VNextT1CanonicalBytes"
    assert fixture["version"] == "v2"
    assert fixture["encoding"] == "base64"
    checks = 3
    for case in fixture["cases"]:
        checks += check_case(case)
    checks += check_case(fixture["large"])
    invalid = next(case for case in fixture["cases"] if case["id"] == "invalid_utf8")
    projection = {
        "schema": fixture["schema"], "version": fixture["version"],
        "encoding": fixture["encoding"], "base64": invalid["base64"],
        "length": invalid["length"], "sha256": {"value": invalid["sha256"]},
    }
    expected_json = '{"base64":"//7DKA==","encoding":"base64","length":4,"schema":"GenomeV5/Contracts/VNextT1CanonicalBytes","sha256":{"value":"33dcc67f14832821b0ea5ff6a8e488c5032470a94422e5836015be475b123943"},"version":"v2"}'
    assert json.dumps(projection, sort_keys=True, separators=(",", ":")) == expected_json
    nested = {"z": [projection, "tail"], "a": {"carrier": projection, "enabled": True}}
    expected_nested = '{"a":{"carrier":' + expected_json + ',"enabled":true},"z":[' + expected_json + ',"tail"]}'
    assert json.dumps(nested, sort_keys=True, separators=(",", ":")) == expected_nested
    checks += 2
    assert fixture["runtime"] == "r1_program_exception_base64_dependency_repaired_not_rerun"
    assert fixture["integration"] == "not_connected"
    print(json.dumps({"status": "PASS", "checks": checks, "cases": len(fixture["cases"]) + 1,
                      "runtime": "R1_PROGRAM_EXCEPTION_NO_CREDIT",
                      "integration": "NOT_CONNECTED"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
