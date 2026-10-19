"""Bounded static QA for the R3 runtime-input local parent adapter.

This checker reads source/test/fixture text and JSON only.  It never invokes
Julia, DESC, a provider, mesh, solver, or a shared entry.
"""
from __future__ import annotations

import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl"
TEST = ROOT / "test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/Integration/vnext_parent_baseline_binding_local_v1_fixture.json"
ENTRY = ROOT / "src/FusionConceptAI.jl"

checks: dict[str, bool] = {}
errors: list[str] = []


def require(name: str, condition: bool, detail: str) -> None:
    checks[name] = condition
    if not condition:
        errors.append(f"{name}: {detail}")


source = SOURCE.read_text(encoding="utf-8") if SOURCE.is_file() else ""
test = TEST.read_text(encoding="utf-8") if TEST.is_file() else ""
fixture_text = FIXTURE.read_text(encoding="utf-8") if FIXTURE.is_file() else ""
entry = ENTRY.read_text(encoding="utf-8") if ENTRY.is_file() else ""

require("source_exists", SOURCE.is_file(), str(SOURCE))
require("test_exists", TEST.is_file(), str(TEST))
require("fixture_exists", FIXTURE.is_file(), str(FIXTURE))
require("not_shared_entry", "VNextParentBaselineBindingLocalV1.jl" not in entry,
        "adapter must remain additive and standalone")
require("no_old_source_edit", "VNextParentBaselineBindingV1.jl" not in source,
        "R3 adapter must not import or edit the old scaffold")
require("no_julia_execution", "julia" not in source.lower(),
        "implementation must not launch Julia")
require("no_heavy_backend", all(token not in source for token in
        ("DESC.", "Gridap", "run_solver", "default_operator_registry",
         "provider_call", "mesh_backend")), "heavy execution hook present")
require("no_include", "Base.include" not in source and "include(" not in source,
        "adapter must remain an explicit include target")
require("no_untyped_any", "::Any" not in source and "Vararg{Any" not in source,
        "closed typed input surface required")
require("no_unbound_review_boolean", "candidate_identity_reviewed" not in source,
        "candidate review must be a typed receipt")
require("reason_symbol_equality",
        ":source_backed_receipt_unavailable in" not in test and
        "reason === :source_backed_receipt_unavailable" in test,
        "reason is a Symbol and must be compared with ===")
require("tamper_snapshot_contract",
        "tampered_snapshot" in test and
        "tamper_receipt.prior_canonical_bytes == tampered_snapshot" in test and
        "state.canonical_sha256 == before_sha" in test and
        "state.state_hash == before_state_hash" in test and
        "state.history == before_history" in test,
        "tamper receipt must echo the mutated snapshot without advancing state")
require("factory_identity_required_guard",
        re.search(r"!isempty\(String\(factory_identity\)\)\s*\|\|\s*throw", source) is not None,
        "factory identity guard must reject empty values and accept non-empty values")
require("factory_version_required_guard",
        re.search(r"!isempty\(String\(factory_version\)\)\s*\|\|\s*throw", source) is not None,
        "factory version guard must reject empty values and accept non-empty values")

required_source = (
    "LocalDigestBytesV1", "LocalCandidateIdentityV1", "LocalQualifiedRefV1",
    "LocalSourceLocatorV1", "LocalCandidateIdentityReviewReceiptV1",
    "LocalFactoryReceiptV1", "LocalDeclarationRecordV1",
    "VNEXT_LOCAL_PBB_FACTORY_VERSION_V1", "VNEXT_LOCAL_PBB_REVIEW_VERSION_V1",
    "PresentLocalParentBaselineBindingV1", "AbsentLocalParentBaselineBindingV1",
    "LocalParentBaselineBindingUnionV1",
    "PresentLocalParentBaselineBundleV1", "AbsentLocalParentBaselineBundleV1",
    "LocalParentBaselineBindResultV1", "bind_local_parent_baseline_v1",
    "PresentT0LocalParentBaselineBindingV1", "PresentT0LocalParentBaselineBundleV1",
    "AbsentT0LocalParentBaselineBundleV1", "T0LocalParentBaselineInputV1",
    "T0LocalParentBaselineBindResultV1", "bind_local_parent_baseline_from_t0_v1",
    "verify_present_t0_local_binding_v1",
    "verify_present_t0_local_binding_self_consistency_v1",
    "verify_present_t0_local_parent_bundle_v1", "verify_absent_t0_local_bundle_v1",
    "t0_parent_authority_commitment_v1", "authority_commitment",
    "VNEXT_LOCAL_PBB_T0_SUCCESSOR_VERSION_V1",
    "source_ref", "declaration_ref", "source_bytes_sha256",
    "declaration_bytes_sha256", "semantic_body_sha256", "source_locator_sha256",
    "factory_receipt_sha256", "declaration_receipt_sha256",
    "semantic_body_identity_hash", "source_locator_identity_hash",
    "factory_receipt_identity_hash", "declaration_receipt_identity_hash",
    "diagnostic_type_hash", "diagnostic_message_hash", "program_exception",
    "same_candidate_identity_hash", "source_locator_bytes",
    "source_bytes", "semantic_body_bytes", "factory_receipt", "candidate_identity_review",
    "review_bytes", "review_sha256", "review_version", "reviewer_ref",
    "VNEXT_LOCAL_PBB_AXES_COUNT_V1", "terminal_deferred", "fail_closed",
    "duplicate_layer", "duplicate_child", "foreign_candidate", "foreign_layer",
    "source_bytes_hash_mismatch", "source_locator_hash_mismatch",
    "factory_receipt_bytes_hash_mismatch", "factory_receipt_ref_mismatch",
    "source_ref_hash_mismatch", "declaration_ref_hash_mismatch",
    "child_contract_hash_mismatch", "declaration_hash_mismatch", "parent_binding_hash_mismatch",
    "child_request_binding_mismatch", "child_request_ref_mismatch", "child_request_hash_mismatch",
    "factory_version_mismatch", "review_version_mismatch",
    "review_bytes_hash_mismatch", "review_candidate_mismatch", "review_layer_mismatch",
    "review_ref_mismatch", "review_axes_mismatch", "review_status_invalid",
    "LocalCanonicalStateV1", "verify_local_state_v1", "recompute_local_bundle_hash_v1",
    "bundle.candidate", "bundle.g1.candidate", "bundle.g2.candidate",
    "expected_prior_state_hash", "expected_prior_source_content_hash",
    "stale_state_hash", "stale_source_hash", "stale_history", "expected_prior_history",
    "_vnl_history_hash", "history_hash", "failure_atomic",
    "replace_local_source_payload_v1", "baseline_authority_absent",
    "promote_absent_local_to_present_v1", "absent_to_present_cas_forbidden",
)
for token in required_source:
    require(f"source_token:{token}", token in source, token)

required_test = (
    "status === :present", "status === :typed_absent", "status === :fail_closed",
    "foreign", "duplicate", "stale_state_hash", "stale_source_hash",
    "source_claim", "receipt_layer", "receipt_source_ref", "state_hash_mismatch",
    "receipt_claim", "review_claim", "review_candidate", "review_status",
    "factory_version", "review_version", "foreign_id_child", "foreign_contract_present",
    "future_factory_present", "stale_review_present", "malformed_absent", "bad_child",
    "missing_child_record", "missing_declaration_record", "baseline_authority_absent",
    "verify_local_state_v1", "tampered_history", "tampered_bundle", "cross_candidate",
    "history",
    "published", "terminal_deferred",
    "empty_factory_identity", "empty_factory_version",
    "tampered_snapshot", "prior_canonical_bytes == tampered_snapshot",
    "_t0l_present", "_t0l_g1", "_t0l_g2", "T0 source-backed G1/G2 successor adapter",
    "t0_declaration_invalid", "t0_candidate_mismatch", "t0_absence_invalid",
    "source_locator_bytes", "factory_receipt_bytes", "declaration_receipt_bytes",
    "changed_source", "changed_declaration", "changed_semantic", "changed_locator",
    "changed_factory", "changed_declaration_receipt", "_fully_rebound",
    "rewritten_source", "rewritten_declaration", "rewritten_semantic",
    "rewritten_locator", "rewritten_factory", "rewritten_declaration_receipt",
    "self_consistency",
)
for token in required_test:
    require(f"test_token:{token}", token in test, token)

try:
    fixture = json.loads(fixture_text)
    require("fixture_schema", fixture.get("schema_id") ==
            "GenomeV5/Integration/VNextParentBaselineBindingLocalV1", "schema id")
    require("fixture_runtime_only", fixture.get("authority") == "runtime_input_only",
            "fixture cannot be authority")
    require("fixture_not_present", fixture.get("fixture_is_authority") is False,
            "fixture must not authorize present")
    require("fixture_no_old_hash", not re.search(r"[0-9a-f]{64}", fixture_text),
            "fixture must not freeze a current source hash")
    require("fixture_negatives", len(fixture.get("negative_controls", [])) >= 15,
            "negative-control matrix too small")
    require("fixture_cas", fixture.get("cas", {}).get("failure_atomic") is True,
            "CAS failure atomicity missing")
    require("fixture_history_cas", fixture.get("cas", {}).get("expected_history") is True,
            "history CAS binding missing")
    require("fixture_review_receipt", fixture.get("review_authority") ==
            "typed_candidate_identity_review_receipt_required",
            "typed candidate review receipt missing")
    require("fixture_version_domains", fixture.get("version_domains", {}).get("factory_version") ==
            "GenomeV5/Integration/VNextParentBaselineBindingLocalV1/factory-v1",
            "factory version domain missing")
    require("fixture_review_version_domain", fixture.get("version_domains", {}).get("review_version") ==
            "GenomeV5/Integration/VNextParentBaselineBindingLocalV1/review-v1",
            "review version domain missing")
    require("fixture_t0_successor_domain", fixture.get("version_domains", {}).get("t0_successor_version") ==
            "GenomeV5/Integration/VNextParentBaselineBindingLocalV1/t0-parent-baseline-successor-v1",
            "T0 successor version domain missing")
    require("fixture_t0_adapter", fixture.get("t0_adapter", {}).get("legacy_review_mapping") ==
            "forbidden" and fixture.get("t0_adapter", {}).get("non_lossless_mapping") ==
            "fail_closed_capability_gap", "T0 adapter lossless/fail-closed contract missing")
    negative_controls = set(fixture.get("negative_controls", []))
    require("fixture_factory_constructor_negatives",
            {"empty_factory_identity", "empty_factory_version"} <= negative_controls,
            "empty factory identity/version constructor negatives missing")
except (json.JSONDecodeError, TypeError) as exc:
    require("fixture_json", False, str(exc))

require("no_old_hash_literals", not re.search(r"[0-9a-f]{64}", source),
        "source must bind runtime hashes rather than old frozen values")

print(json.dumps({
    "record_kind": "vnext-parent-baseline-binding-local-v1-static-qa",
    "python": sys.executable,
    "checks": "pass" if not errors else "fail",
    "check_count": len(checks),
    "passed": sum(checks.values()),
    "errors": errors,
    "scope": [str(path.relative_to(ROOT)).replace("\\", "/") for path in
              (SOURCE, TEST, FIXTURE, Path(__file__))],
}, ensure_ascii=False, indent=2))
sys.exit(0 if not errors else 1)
