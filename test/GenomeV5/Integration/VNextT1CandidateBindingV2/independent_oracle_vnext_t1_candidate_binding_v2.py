"""Independent fixture oracle; deliberately does not import Julia."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


FIXTURE = Path(__file__).with_name("fixture.json")


def classify(expected: dict, observations: list[dict]) -> tuple[str, str]:
    if not observations:
        return "terminal_deferred", "missing_observation"
    if len(observations) != 1:
        return "fail_closed", "duplicate_conflict"
    observed = observations[0]
    for key, reason in (
        ("candidate_ref", "foreign_candidate_ref"),
        ("candidate_digest", "candidate_digest_mismatch"),
        ("source_package_hash", "source_package_hash_mismatch"),
    ):
        if observed[key] != expected[key]:
            return "fail_closed", reason
    if expected["wire_hash"] is None:
        return "terminal_deferred", "missing_expected_wire"
    if observed["wire_hash"] is None:
        return "terminal_deferred", "missing_observed_wire"
    if observed["wire_hash"] != expected["wire_hash"]:
        return "fail_closed", "wire_hash_mismatch"
    return "bound", "exact_explicit_binding"


def main() -> int:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    wire_hash = hashlib.sha256(bytes(fixture["wire_bytes"])).hexdigest()
    expected = {key: fixture[key] for key in (
        "candidate_ref", "candidate_digest", "source_package_hash", "wire_hash")}
    body = {
        "domain": fixture["domain"], "schema": fixture["schema"],
        "version": fixture["version"], "status": "bound",
        "reason": "exact_explicit_binding", "candidate_ref": fixture["candidate_ref"],
        "candidate_digest": {"value": fixture["candidate_digest"]},
        "source_package_hash": {"value": fixture["source_package_hash"]},
        "wire_hash": {"value": fixture["wire_hash"]}, "duplicate_count": 1,
        "accepted": False, "claim_ceiling": "contract_only",
    }
    receipt_json = json.dumps(
        {"receipt_domain": fixture["receipt_domain"], "body": body},
        ensure_ascii=False, sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")
    receipt_hash = hashlib.sha256(receipt_json).hexdigest()
    foreign = dict(expected, candidate_ref={"id": "foreign", "version": "v1"})
    path_expected = dict(expected, candidate_ref={"id": "/a/../b", "version": "v1"})
    path_alias = dict(expected, candidate_ref={"id": "/b", "version": "v1"})
    cross_splice = dict(expected, candidate_ref={"id": "foreign", "version": "v2"})
    tampered = dict(expected, wire_hash="0" * 64)
    checks = {
        "wire_hash": wire_hash == fixture["wire_hash"],
        "exact": classify(expected, [dict(expected)])[0] == "bound",
        "missing": classify(expected, [])[0] == "terminal_deferred",
        "foreign": classify(expected, [foreign])[0] == "fail_closed",
        "path_alias_not_normalized": classify(path_expected, [path_alias])[0] == "fail_closed",
        "id_version_cross_splice": classify(expected, [cross_splice])[0] == "fail_closed",
        "tampered": classify(expected, [tampered])[0] == "fail_closed",
        "duplicate_identical": classify(expected, [dict(expected), dict(expected)])[0] == "fail_closed",
        "duplicate_conflict": classify(expected, [dict(expected), foreign])[0] == "fail_closed",
        "receipt_domain_enveloped": fixture["receipt_domain"].endswith("/receipt/v1")
            and fixture["receipt_domain"] not in body.values(),
        "receipt_hash_golden": receipt_hash == fixture["bound_receipt_hash"],
        "receipt_wire_separate": receipt_hash != wire_hash,
        "no_runtime_credit": fixture["accepted"] is False and fixture["runtime"] == "not_run",
    }
    failed = [name for name, ok in checks.items() if not ok]
    print(json.dumps({"status": "FAIL" if failed else "PASS", "failed": failed,
                      "checks": checks if failed else len(checks),
                      "oracle": "python_independent_no_julia"}, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
