"""Static boundary checks for the additive V2 candidate-binding slice."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src" / "Contracts" / "VNextT1CandidateBindingV2.jl"
TEST = Path(__file__).with_name("vnext_t1_candidate_binding_v2_tests.jl")
ORACLE = Path(__file__).with_name("independent_oracle_vnext_t1_candidate_binding_v2.py")
FIXTURE = Path(__file__).with_name("fixture.json")
DOCS = ROOT / "docs" / "implementation" / "UP1-04A-VNEXT-T1-CANDIDATE-BINDING-V2"
PROTECTED = {
    ROOT / "src" / "Contracts" / "CandidateStatePackageV5Next.jl":
        (53197, "14e8f519dd4ffe56ca5678ae8e4b82009ced12616e05de11165e36c3b4adae73"),
    ROOT / "src" / "FusionConceptAI.jl":
        (10144, "e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783"),
    ROOT / "src" / "Contracts" / "VNextT1CanonicalBytesV2.jl":
        (2602, "49c03ff3d81a8568bfb475d5c11e8d21c421b8a25e2e263b06d9caf820ca87fb"),
}


def unchanged(path: Path, expected: tuple[int, str]) -> bool:
    data = path.read_bytes()
    return len(data) == expected[0] and hashlib.sha256(data).hexdigest() == expected[1]


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    oracle = ORACLE.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    checks = {
        "source_exists": SOURCE.is_file(),
        "definition_only": "include(joinpath" not in source and "export " not in source and "register(" not in source,
        "fixed_domain_schema": all(x in source for x in (
            "VNEXT_T1_CANDIDATE_BINDING_V2_DOMAIN",
            "VNEXT_T1_CANDIDATE_BINDING_V2_SCHEMA",
            "VNEXT_T1_CANDIDATE_BINDING_V2_VERSION")),
        "explicit_inputs": all(x in source for x in (
            "candidate_ref::QualifiedRefV1", "candidate_digest::Digest256",
            "source_package_hash::Digest256", "wire::Union{Nothing,VNextT1CanonicalBytesV2}")),
        "three_statuses": all(f":{x}" in source for x in ("bound", "terminal_deferred", "fail_closed")),
        "contract_only": "accepted === false" in source and "claim ceiling must remain contract_only" in source,
        "no_label_uri_inference": all(x not in source for x in (
            "candidate_label", "startswith(", "occursin(", "split(", "match(")),
        "separate_hashes": all(x in source for x in (
            "wire_hash::Union{Nothing,Digest256}", "receipt_hash::Digest256",
            "receipt_hash=x.receipt_hash", "VNEXT_T1_CANDIDATE_BINDING_V2_RECEIPT_DOMAIN")),
        "sealed_receipt": all(x in source for x in (
            "candidate-binding domain mismatch", "candidate-binding schema mismatch",
            "candidate-binding version mismatch", "candidate-binding status/reason mismatch",
            "candidate-binding receipt_hash mismatch")),
        "typed_absence": all(x in source for x in (
            ":missing_observation", ":missing_expected_wire", ":missing_observed_wire")),
        "foreign_and_tamper": all(x in source for x in (
            ":foreign_candidate_ref", ":candidate_digest_mismatch",
            ":source_package_hash_mismatch", ":wire_hash_mismatch")),
        "duplicate_fail_closed": "count == 1 || return _vnext_t1_binding_receipt(:fail_closed" in source,
        "test_matrix": all(x in test for x in (
            "foreign_ref", "foreign_digest", "foreign_package", "wire_hash_mismatch",
            "(binding(), binding())", "(binding(), binding(ref=foreign_ref))")),
        "ref_and_precedence_negatives": all(x in test for x in (
            "foreign_version", "case_mismatch", "payload=nothing),)).reason === :foreign_candidate_ref")),
        "path_alias_and_cross_splice": all(x in test for x in (
            '"fusion.candidate/a/../b"', '"fusion.candidate/b"',
            "cross_splice = B.QualifiedRefV1(foreign_ref.id, foreign_version.version)")),
        "constructor_tamper_negatives": test.count("@test_throws ArgumentError B.VNextT1CandidateBindingReceiptV2") == 4,
        "stable_replay_fields": all(x in test for x in (
            "VNEXT_T1_CANDIDATE_BINDING_V2_REPLAY", '" schema="', '" version="',
            '" status="', '" candidate_digest="', '" wire_hash="', '" receipt_hash="')),
        "receipt_golden": fixture["bound_receipt_hash"] ==
            "f03d93a582a6f4f48443bbe68f7eced2c16933d43556b43a48565bcf6b34ecc7",
        "no_v1_package_construction": "CandidateStatePackageV5Next" not in source and "VNextT1CanonicalBytesV1" not in source,
        "independent_oracle": all(x in oracle for x in ("hashlib", "fixture.json", "does not import Julia")),
        "fixture_boundary": fixture["accepted"] is False and fixture["claim_ceiling"] == "contract_only"
            and fixture["integration"] == "not_connected" and fixture["runtime"] == "not_run",
        "docs_present": all((DOCS / name).is_file() for name in ("README.md", "manifest.json", "report.md")),
        "protected_unchanged": all(unchanged(path, expected) for path, expected in PROTECTED.items()),
    }
    failed = [name for name, ok in checks.items() if not ok]
    print(json.dumps({"status": "FAIL" if failed else "PASS", "failed": failed,
                      "checks": checks if failed else len(checks), "runtime": "NOT_RUN",
                      "integration": "NOT_CONNECTED"}, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
