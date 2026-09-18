"""Python-only static QA for UP4-02A; intentionally does not invoke Julia."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "EngineeringFeedbackBridgeContractV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "UP4" / "engineering_feedback_bridge_contract_v1_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "UP4" / "engineering_feedback_bridge_contract_v1_fixture.json"
EXPECTED_SOURCE_SHA256 = "0436da2fcd60974ce61d6823585488e944ffaf4c59a0b3633d4f23e882b64f55"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    if sha256(SOURCE) != EXPECTED_SOURCE_SHA256:
        raise AssertionError("product source hash guard drifted; repair scope forbids source edits")
    required = (
        "EngineeringFeedbackTypedRefV1", "EngineeringFeedbackVersionAxesV1",
        "EngineeringFeedbackBindingV1", "EngineeringFeedbackResourceBundleV1",
        "EngineeringFeedbackLedgerClosureV1", "EngineeringFeedbackFeedbackTargetV1",
        "EngineeringFeedbackBridgeContractV1", "EngineeringFeedbackBridgeResolutionV1",
        "sign", "resource_hash", "candidate_hash", "g1_hash", "g2_hash", "g3_hash",
        "candidate", "g1", "g2", "g3", "parent", "mission", "scenario",
        "physical_subject", "design_hash", "realization_plan_hash", "control_plan_hash",
        "binding_hash", "source", "coil", "driver", "return_ref", "heat_sink",
        "material", "manufacturing", "cooling", "support", "control_fault",
        "_UP4_02A_RESOURCE_RULES", "identity_projection_hash", "candidate_projection_hash",
        "scenario_projection_hash", "isempty(request.feedback_targets)",
        "energy", "material", "thermal", "mechanical", "unit_mismatch",
        "direction_mismatch", "owner_mismatch", "capacity_exceeded", "passive_source",
        "feedback_control_resource_link_mismatch", "static_flux_to_emf",
        "time_derivative_declared", "motion_declared", "drive_declared",
        "provider_dropout", "ambiguous_provider", "solver_capability_gap",
        "checker_capability_gap", "validate_engineering_feedback_bridge",
        "missing_source", "missing_link", "duplicate_ledger", "empty_entry", "forged_residual",
        "accepted=false", "claim_ceiling=:contract_only", "provider_calls=0",
        "solver_calls=0", "checker_calls=0",
    )
    missing = [token for token in required if token not in source]
    if missing:
        raise AssertionError(f"missing contract token(s): {missing}")
    forbidden = (
        "default_operator_registry", "invoke_provider", "execute_once!", "solve_pde",
        "run_solver", "DESC.", "provider_call(", "HTTP.get", "Pkg.add",
    )
    found = [token for token in forbidden if token in source]
    if found:
        raise AssertionError(f"execution/shared-registry token(s) found: {found}")
    if fixture["scope"] != "contract_only" or fixture["accepted"] is not False:
        raise AssertionError("fixture claim boundary drifted")
    if fixture["claim_ceiling"] != "contract_only":
        raise AssertionError("claim ceiling drifted")
    if any(fixture[k] != 0 for k in ("provider_calls", "solver_calls", "checker_calls")):
        raise AssertionError("execution counters are not zero")
    expected = {
        "candidate_projection_mismatch", "scenario_projection_mismatch", "candidate_hash_mismatch", "g3_hash_mismatch", "missing_return", "missing_heat_sink",
        "ledger_imbalance", "unit_mismatch", "passive_source", "capacity_exceeded",
        "missing_support_boundary", "unknown_material", "provider_dropout", "ambiguous_provider",
        "static_flux_to_emf", "feedback_edge_removed", "feedback_control_resource_link_mismatch", "scenario_reuse_mismatch", "missing_source",
        "direction_mismatch", "owner_mismatch", "missing_link", "duplicate_ledger", "empty_entry",
        "forged_residual",
    }
    negative = {item["id"] for item in fixture["negative"]}
    if negative != expected or len(negative) < 15:
        raise AssertionError(f"negative matrix drifted: {sorted(negative)}")
    if set(fixture["dispatch"]) != negative or any(
            fixture["dispatch"][item["id"]] != item["dispatch"] for item in fixture["negative"]):
        raise AssertionError("fixture registry/dispatch is not closed")
    if "EngineeringFeedbackBridgeContractV1" not in test or "length(fixture.negative) >= 15" not in test:
        raise AssertionError("focused test does not cover the contract and 15-negative matrix")
    normalized_literal_tokens = (
        "capacity=100//1",
        "capacity=mutation === :capacity_exceeded ? 5//1 : 100//1",
        "10//1", "2//1", "3//1", "4//1", "5//1",
        "static_flux=mutation === :static_flux_to_emf ? 1//1 : 0//1",
        "emf=mutation === :static_flux_to_emf ? 1//1 : 0//1",
    )
    missing_normalized = [token for token in normalized_literal_tokens if token not in test]
    if missing_normalized:
        raise AssertionError(f"constructor-normalized Rational literals missing: {missing_normalized}")
    positive_assert = test.index("@test canonical_hash(request) == request.request_hash")
    positive_validate = test.index("result = validate_engineering_feedback_bridge(request)")
    if positive_assert > positive_validate:
        raise AssertionError("positive request hash closure is asserted after validator")
    mutation_anchor = test.index("req = _up4_request(mutation)")
    mutation_assert = test.index("@test canonical_hash(req) == req.request_hash", mutation_anchor)
    mutation_validate = test.index("got = validate_engineering_feedback_bridge(req)", mutation_anchor)
    if mutation_assert > mutation_validate:
        raise AssertionError("mutation request hash closure is asserted after validator")
    if fixture["dispatch"].get("capacity_exceeded") != "capacity_exceeded":
        raise AssertionError("capacity_exceeded is not dispatched through its validator mutation")
    if "feedback_edge_removed\", \"dispatch\":\"feedback_edge_removed" not in FIXTURE.read_text(encoding="utf-8"):
        raise AssertionError("typed-absent feedback deletion case is not executable")
    if "missing_link\", \"dispatch\":\"missing_link" not in FIXTURE.read_text(encoding="utf-8"):
        raise AssertionError("missing ledger/resource hash case is not executable")
    if "import FusionConceptAI:" not in source:
        raise AssertionError("source import boundary is not explicit")
    hashes = {str(path.relative_to(ROOT)): sha256(path) for path in (SOURCE, TEST, FIXTURE, Path(__file__))}
    print(json.dumps({
        "status": "PASS static_qa_up4_02a_engineering_feedback_bridge_v1",
        "negative_case_count": len(negative),
        "provider_solver_checker_calls": [0, 0, 0],
        "r4_failure_lineage": {
            "failure": "constructor/hash drift before validator",
            "root_cause": "fixture hashed Int literals while constructors stored Rational{Int64}",
            "normalized_fields": ["typed_ref.capacity", "request.static_flux", "request.emf"],
            "capacity_exceeded": "reaches validator after typed-ref hash closure",
        },
        "residual_gaps": fixture["residual_gaps"],
        "sha256": hashes,
    }, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
