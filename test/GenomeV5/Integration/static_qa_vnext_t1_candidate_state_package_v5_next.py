"""Definition-only QA for the UP1 T1 local-contract focused lane.

This checker deliberately does not import Julia, execute a provider, or run
the focused test.  It verifies the additive boundary, explicit status ceiling,
chain coverage, and the negative matrix declared by the fixture.
"""
from __future__ import annotations

import json
import importlib.util
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TEST = Path(__file__).resolve()
CONTRACT = ROOT / "src" / "Contracts" / "CandidateStatePackageV5Next.jl"
ADMISSION = ROOT / "src" / "GenomeV5" / "Integration" / "VNextGenomeV5Integration.jl"
FIXTURE = TEST.with_name("vnext_t1_candidate_state_package_v5_next_fixture.json")


def require(text: str, needle: str, label: str, checks: list[str]) -> None:
    checks.append(label)
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def main() -> int:
    contract = CONTRACT.read_text(encoding="utf-8")
    admission = ADMISSION.read_text(encoding="utf-8")
    test = TEST.with_name("vnext_t1_candidate_state_package_v5_next_tests.jl").read_text(
        encoding="utf-8"
    )
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    checks: list[str] = []

    required_contract = (
        "CandidateStatePackageV5Next",
        "VNextT1NoLegacyReceiptV1",
        "VNextT1CanonicalBytesV1",
        "VNextT1PriorBundleSnapshotV1",
        "VNextT1LabelErasedIdentityV1",
        "VNextT1ComponentCountReceiptV1",
        "vnext_t1_package_schema_hash_v1",
        "vnext_t1_package_canonicalization_hash_v1",
        "vnext_t1_package_profile_hash_v1",
        "_vnext_t1_validate_locator",
        "_vnext_t1_validate_feedback_order",
        "_vnext_t1_validate_no_legacy_receipt",
        "_vnext_t1_validate_factory_result",
        "declaration.factory_receipt.factory_result.contract_ref",
        "factory result contract mismatch",
        "_vnext_t1_validate_present_child_body",
        "_vnext_t1_label_erased_identity",
        "status=:prepared_not_executed",
        "resolution=:terminal_deferred",
        "accepted=false",
        "claim_ceiling=:contract_only",
    )
    for needle in required_contract:
        require(contract, needle, "contract feature", checks)
    checks.append("factory result contract projection path")
    if "declaration.contract_identity.contract_ref" in contract:
        raise AssertionError(
            "factory result validator must not read contract_identity from the T0 declaration"
        )

    required_admission = (
        "VNextT1AdmissionInputV1",
        "VNextT1AdmissionResultV1",
        "_vnext_t1_snapshot",
        "local_checked_present",
        "resolved",
        "recomputed_bundle_hash",
        "canonical prior bundle bytes mismatch",
        "_vnext_t1_output_gate",
        "vnext_t1_admit_skeleton_v1",
        "t1_runtime_unresolved",
        "T0 child/gap semantic mismatch",
        "T0 child gap must be all typed absent",
        "T0 no-gap state must be all present",
    )
    for needle in required_admission:
        require(admission, needle, "admission feature", checks)

    required_test = (
        "vnext_declaration_transport_local_v1_tests.jl",
        "VNextDeclarationAuthorityRecheckLocalV1.jl",
        "CandidateStatePackageV5Next.jl",
        "VNextGenomeV5Integration.jl",
        "vnext_declaration_transport_local_v1",
        "vnext_declaration_authority_recheck_local_v1",
        "vnext_t1_admit_skeleton_v1",
        "package.component_count_receipt.component_count == 3",
        "package.no_legacy_receipt.legacy_refs == ()",
        "label-erased component identity",
        "typed absence fails closed",
        "canonical_json(package)",
        "round_trip",
        "forged_legacy",
        "legacy_result",
        "t1_projection_invalid",
        "@test_throws ArgumentError",
        "T2_UP2_R_CREDIT=false",
    )
    for needle in required_test:
        require(test, needle, "focused test feature", checks)

    checks.append("no second main-module include")
    if "include(G, joinpath(_T1_ROOT, \"src\", \"FusionConceptAI.jl\"))" in test:
        raise AssertionError("focused test must not include a second main module")
    for forbidden in ("run(`julia", "Base.run", "Pkg.test", "julia --", "DESC"):
        checks.append(f"no forbidden launcher: {forbidden}")
        if forbidden in test:
            raise AssertionError(f"focused test contains forbidden runtime launcher: {forbidden}")

    checks.append("fixture status")
    if fixture.get("status") != "prepared_not_executed":
        raise AssertionError("fixture status must remain prepared_not_executed")
    checks.append("fixture claim ceiling")
    if fixture.get("claim_ceiling") != "contract_only":
        raise AssertionError("fixture claim ceiling must remain contract_only")
    checks.append("fixture accepted")
    if fixture.get("accepted") is not False:
        raise AssertionError("fixture accepted must be false")
    checks.append("fixture component count")
    if fixture.get("component_count") != 3:
        raise AssertionError("fixture component count must be 3")
    checks.append("fixture negative count")
    if fixture.get("negative_case_count") != 9:
        raise AssertionError("fixture negative-case count drifted")
    checks.append("fixture known T0 gap")
    if fixture.get("known_t0_gap") != ["g3_child_terminal_deferred"]:
        raise AssertionError("fixture T0 gap drifted")
    checks.append("fixture oracle payload")
    if not isinstance(fixture.get("oracle_payload"), dict):
        raise AssertionError("fixture oracle payload missing")
    checks.append("fixture oracle digest")
    if len(fixture.get("oracle_expected_sha256", "")) != 64:
        raise AssertionError("fixture oracle digest missing")

    negative_cases = fixture.get("negative_cases", [])
    checks.append("negative dispatch arity")
    if len(negative_cases) != fixture["negative_case_count"]:
        raise AssertionError("fixture negative dispatch is not one-to-one")
    checks.append("negative dispatch uniqueness")
    if len({case["name"] for case in negative_cases}) != len(negative_cases):
        raise AssertionError("fixture negative dispatch has duplicate names")
    expected = {"t0_recheck_missing", "t0_transport_missing", "foreign_candidate",
                "foreign_no_legacy_receipt", "invalid_transport", "feedback_reordered",
                "feedback_duplicate", "bundle_hash_mismatch", "legacy_status_constructor"}
    checks.append("negative dispatch names")
    if {case["name"] for case in negative_cases} != expected:
        raise AssertionError("fixture negative dispatch does not cover the frozen matrix")

    oracle_path = TEST.with_name("vnext_t1_candidate_state_package_v5_next_oracle.py")
    spec = importlib.util.spec_from_file_location("t1_oracle", oracle_path)
    if spec is None or spec.loader is None:
        raise AssertionError("oracle module could not be loaded")
    oracle = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(oracle)
    checks.append("independent oracle digest")
    if oracle.expected_digest() != fixture["oracle_expected_sha256"]:
        raise AssertionError("independent oracle digest mismatch")

    print("STATIC_QA=PASS")
    print(f"CHECKS={len(checks)}")
    print("NEGATIVE_CASES=9")
    print("RUNTIME=NOT_RUN")
    print("T1=PREPARED_NOT_EXECUTED")
    print("CLAIM_CEILING=CONTRACT_ONLY")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
