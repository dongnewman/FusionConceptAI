"""Static QA for the additive VNext T1 package-binding adapter."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src" / "Contracts" / "VNextT1PackageBindingAdapterV1.jl"
TEST = Path(__file__).with_name("vnext_t1_package_binding_adapter_v1_tests.jl")
ORACLE = Path(__file__).with_name("independent_oracle_vnext_t1_package_binding_adapter_v1.py")
FIXTURE = Path(__file__).with_name("fixture.json")
DOCS = ROOT / "docs" / "implementation" / "UP1-04A-VNEXT-T1-PACKAGE-BINDING-ADAPTER-V1"
PROTECTED = {
    ROOT / "src" / "FusionConceptAI.jl":
        (10144, "e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783"),
    ROOT / "src" / "Contracts" / "CandidateStatePackageV5Next.jl":
        (53197, "14e8f519dd4ffe56ca5678ae8e4b82009ced12616e05de11165e36c3b4adae73"),
    ROOT / "src" / "Contracts" / "VNextT1CandidateBindingV2.jl":
        (9967, "1f99e984c0a18c62c4f625cbab9fbbb0612d974fba1c103f1a2242dfba17e5c4"),
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
        "definition_only": all(x not in source for x in
            ("include(", "export ", "register(")),
        "fixed_identity": all(x in source for x in (
            "VNEXT_T1_PACKAGE_BINDING_ADAPTER_DOMAIN_V1",
            "VNEXT_T1_PACKAGE_BINDING_ADAPTER_SCHEMA_V1",
            "VNEXT_T1_PACKAGE_BINDING_ADAPTER_VERSION_V1")),
        "explicit_v2_mapping": all(x in source for x in (
            "CandidateStatePackageV5Next", "candidate_ref",
            "package.semantic_identity", "package.package_hash",
            "VNextT1CandidateBindingInputV2",
            "wire::Union{Nothing,VNextT1CanonicalBytesV2}")),
        "gaps_preserved": all(x in source for x in (
            ":prepared_not_executed", ":terminal_deferred",
            "package_status", "package_resolution")),
        "typed_absent_not_fabricated": all(x in source for x in (
            "VNextT1AbsentChildRecordV1", ":typed_absent", ":g3_typed_absent",
            "package, wire, nothing")),
        "structural_hash_fail_closed": all(x in source for x in (
            ":candidate_ref_conflict", ":component_structure_conflict",
            ":component_identity_mismatch", ":semantic_identity_mismatch",
            ":package_hash_mismatch", "_vnext_t1_component_identity")),
        "stored_contract_hash_joins": all(x in source for x in (
            "package.layer_contracts == identity.layer_contracts",
            "package.schema_hashes == ntuple",
            "package.canonicalization_hashes == ntuple",
            "package.profile_hashes == ntuple")),
        "package_metadata_constants": all(x in source for x in (
            "VNEXT_T1_PACKAGE_SCHEMA_VERSION_V1",
            "vnext_t1_package_schema_hash_v1()",
            "VNEXT_T1_PACKAGE_CANONICALIZATION_VERSION_V1",
            "vnext_t1_package_canonicalization_hash_v1()",
            "VNEXT_T1_PACKAGE_PROFILE_VERSION_V1",
            "vnext_t1_package_profile_hash_v1()")),
        "complete_count_receipt": all(x in source for x in (
            "VNextT1ComponentCountReceiptV1(",
            "Tuple(f.target_id for f in package.feedback)",
            "package.component_count_receipt == expected_count")),
        "deep_t0_gate_joins": all(x in source for x in (
            "package.t0_gate.status === :local_checked_present",
            "package.t0_gate.resolution === :resolved",
            "package.t0_gate.accepted === false",
            "package.t0_gate.claim_ceiling === :contract_only",
            "output_identity.declaration_identity_hashes",
            "output_identity.child_identity_hashes",
            "output_identity.feedback_hashes",
            "output_projection.declarations == package.declarations",
            "output_projection.children == package.children",
            "output_projection.feedback == package.feedback")),
        "exact_package_hash_recheck": "_vnext_t1_package_binding_adapter_package_hash_v1" in source,
        "receipt_separate": all(x in source for x in (
            "receipt_domain", "receipt_hash", "receipt_hash mismatch",
            "receipt_hash != receipt.source_package_hash")) or
            ("VNEXT_T1_PACKAGE_BINDING_ADAPTER_RECEIPT_DOMAIN_V1" in source and
             "_vnext_t1_package_binding_adapter_receipt_hash_v1" in source),
        "no_old_up2_or_v4": all(x not in source for x in ("UP2", "FusionConceptAI.jl", "RuntimeV4", "V4")),
        "no_v2_extension": "struct VNextT1CandidateBindingInputV2" not in source,
        "test_boundary": all(x in test for x in (
            "prepared_not_executed", "terminal_deferred", "g3_typed_absent",
            "@test_throws ArgumentError", "accepted === false",
            "CandidateStatePackageV5Next.jl", "vnext_declaration_transport_local_v1_tests.jl",
            "VNextDeclarationAuthorityRecheckLocalV1.jl",
            "_adapter_real_package", "vnext_t1_package_binding_adapter_v1(package",
            "stale_layers", "stale_metadata", "stale_count", "stale_gate",
            "typed_absent = _adapter_real_package")),
        "oracle_independent": all(x in oracle for x in (
            "hashlib", "does not import Julia", "g3_typed_absent",
            "package_metadata", "component_count_receipt", "t0_gate_conflict_fail_closed")),
        "fixture_boundary": fixture["accepted"] is False and
            fixture["claim_ceiling"] == "contract_only" and
            fixture["runtime"] == "not_run" and fixture["integration"] == "not_connected",
        "docs_present": all((DOCS / name).is_file() for name in
                             ("README.md", "manifest.json", "report.md")),
        "protected_unchanged": all(unchanged(path, expected) for path, expected in PROTECTED.items()),
    }
    failed = [name for name, ok in checks.items() if not ok]
    print(json.dumps({"status": "FAIL" if failed else "PASS", "failed": failed,
                      "checks": checks if failed else len(checks),
                      "runtime": "NOT_RUN", "integration": "NOT_CONNECTED"}, sort_keys=True))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
