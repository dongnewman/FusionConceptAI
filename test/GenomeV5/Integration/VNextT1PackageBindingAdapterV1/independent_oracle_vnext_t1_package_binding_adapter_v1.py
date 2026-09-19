"""Independent package-to-V2 mapping oracle; does not import Julia."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


FIXTURE = Path(__file__).with_name("fixture.json")


def classify(package: dict) -> tuple[str, str, bool]:
    if package["package_status"] != "prepared_not_executed":
        return "fail_closed", "package_status_conflict", False
    if package["package_resolution"] != "terminal_deferred":
        return "fail_closed", "package_resolution_conflict", False
    if package["package_metadata"] != package.get("expected_package_metadata"):
        return "fail_closed", "package_metadata_conflict", False
    if package["stored_layer_contract_hashes"] != package.get("derived_layer_contract_hashes"):
        return "fail_closed", "layer_contract_hash_conflict", False
    if package["component_count_receipt"] != package.get("expected_component_count_receipt"):
        return "fail_closed", "component_count_conflict", False
    gate = package["t0_gate"]
    if (gate["status"], gate["resolution"], gate["accepted"],
            gate["claim_ceiling"]) != (
                "local_checked_present", "resolved", False, "contract_only"):
        return "fail_closed", "t0_gate_conflict", False
    if (gate["candidate_ref"] != package["candidate_ref"] or
            not gate["declaration_identity_hashes_join"] or
            not gate["child_identity_hashes_join"] or
            not gate["feedback_hashes_join"] or
            not gate["prior_bundle_join"]):
        return "fail_closed", "t0_gate_join_conflict", False
    if package["candidate_ref"] != package.get("component_candidate_ref", package["candidate_ref"]):
        return "fail_closed", "candidate_ref_conflict", False
    if package["semantic_identity"] != package.get("expected_semantic_identity", package["semantic_identity"]):
        return "fail_closed", "semantic_identity_mismatch", False
    if package["package_hash"] != package.get("expected_package_hash", package["package_hash"]):
        return "fail_closed", "package_hash_mismatch", False
    if "typed_absent" in package["g3_child_statuses"]:
        return "terminal_deferred", "g3_typed_absent", False
    return "prepared_not_executed", "mapped_prepared_not_executed", True


def main() -> int:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    wire_hash = hashlib.sha256(bytes(fixture["wire_bytes"])).hexdigest()
    valid = dict(fixture, expected_semantic_identity=fixture["semantic_identity"],
                 expected_package_hash=fixture["package_hash"],
                 component_candidate_ref=fixture["candidate_ref"])
    typed_absent = dict(valid, g3_child_statuses=fixture["typed_absent_g3_child_statuses"])
    checks = {
        "wire_hash": wire_hash == fixture["wire_hash"],
        "valid_mapping": classify(valid) ==
            ("prepared_not_executed", "mapped_prepared_not_executed", True),
        "g3_typed_absent_is_not_fabricated": classify(typed_absent) ==
            ("terminal_deferred", "g3_typed_absent", False),
        "status_conflict_fail_closed": classify(dict(valid,
            package_status="executed")) ==
            ("fail_closed", "package_status_conflict", False),
        "resolution_conflict_fail_closed": classify(dict(valid,
            package_resolution="resolved")) ==
            ("fail_closed", "package_resolution_conflict", False),
        "metadata_conflict_fail_closed": classify(dict(valid,
            package_metadata=dict(valid["package_metadata"], schema_version="stale"))) ==
            ("fail_closed", "package_metadata_conflict", False),
        "layer_contract_hash_conflict_fail_closed": classify(dict(valid,
            stored_layer_contract_hashes={"schema": ["00"],
                "canonicalization": ["44", "55", "66"],
                "profile": ["77", "88", "99"]})) ==
            ("fail_closed", "layer_contract_hash_conflict", False),
        "component_count_conflict_fail_closed": classify(dict(valid,
            component_count_receipt=dict(valid["component_count_receipt"],
                feedback_ids=["g2-thermal", "g1-residual"]))) ==
            ("fail_closed", "component_count_conflict", False),
        "t0_gate_conflict_fail_closed": classify(dict(valid,
            t0_gate=dict(valid["t0_gate"], accepted=True))) ==
            ("fail_closed", "t0_gate_conflict", False),
        "t0_gate_join_conflict_fail_closed": classify(dict(valid,
            t0_gate=dict(valid["t0_gate"], feedback_hashes_join=False))) ==
            ("fail_closed", "t0_gate_join_conflict", False),
        "candidate_conflict_fail_closed": classify(dict(valid,
            component_candidate_ref={"id": "foreign", "version": "v5"})) ==
            ("fail_closed", "candidate_ref_conflict", False),
        "semantic_hash_conflict_fail_closed": classify(dict(valid,
            expected_semantic_identity="0" * 64)) ==
            ("fail_closed", "semantic_identity_mismatch", False),
        "package_hash_conflict_fail_closed": classify(dict(valid,
            expected_package_hash="0" * 64)) ==
            ("fail_closed", "package_hash_mismatch", False),
        "no_acceptance_credit": fixture["accepted"] is False and
            fixture["claim_ceiling"] == "contract_only" and
            fixture["runtime"] == "not_run",
        "no_integration": fixture["integration"] == "not_connected",
        "diagnostic_probe_expected_not_run": fixture["diagnostic_probe"] == {
            "classification": "diagnostic_expected",
            "expected": True,
            "status": "not_run",
            "stage": "no_legacy",
            "exception_type": "ArgumentError",
            "message_digest": "fixed_status_stage_exception_digest_only",
            "full_exception_text": "not_recorded",
            "runtime_credit": "none",
        },
        "r1_program_exception_observed_only": fixture["r1_observed"] == {
            "classification": "program_exception",
            "admission_status": "fail_closed",
            "admission_error": "t1_projection_invalid",
            "stage": "not_observed",
            "exception_type": "not_observed",
            "message_digest": "not_observed",
            "full_exception_text": "not_recorded",
            "runtime_credit": "none",
        },
    }
    failed = [name for name, ok in checks.items() if not ok]
    print(json.dumps({"status": "FAIL" if failed else "PASS", "failed": failed,
                      "checks": checks if failed else len(checks),
                      "oracle": "python_independent_no_julia"}, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
