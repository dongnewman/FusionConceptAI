"""Static-only QA for the additive UP5 structure-search contract."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src" / "RuntimeV4" / "M4Isolated" / "BoundedStructureSearchV1.jl"
TEST = ROOT / "test" / "RuntimeV4" / "M4Isolated" / "bounded_structure_search_v1_tests.jl"
FIXTURE = ROOT / "test" / "RuntimeV4" / "M4Isolated" / "bounded_structure_search_v1_fixture.json"

EXPECTED_NEGATIVE_VECTORS = {
    "missing_m5c_authority", "closure_hash_mismatch", "foreign_candidate",
    "foreign_parent", "condition_unmet_zero_merge", "condition_unknown_deferred",
    "contradiction_fail_closed", "stale_condition_token", "budget_overflow",
    "saturation_incomplete", "nonfinite_synthetic_screen", "provider_nonzero",
    "solver_nonzero", "mesh_nonzero", "physical_nonzero", "pid_in_content_hash",
    "utc_in_content_hash", "run_id_in_content_hash", "replay_hash_mismatch",
    "descriptor_label_leak", "builder_gate_bypass", "freshness_hash_mismatch",
    "source_generation_mismatch", "action_order_permutation",
    "multi_lineage_parent_lookup", "proposal_overflow_pre_mutation",
    "sealed_result_counter_injection", "content_receipt_tamper",
    "operational_identity_exclusion", "direct_apply_typed_absent",
    "direct_apply_stale_freshness", "unsupported_budget_dimension_rejected",
    "receipt_status_mismatch", "receipt_counters_mismatch",
    "receipt_semantic_bytes_tamper", "receipt_edge_swap", "receipt_sequence_tamper",
    "receipt_descriptor_tamper", "receipt_semantic_bytes_self_consistent_tamper",
    "make_receipt_without_ledger_rejected", "mixed_failed_deferred_then_success",
    "foreign_emitter_rejected", "self_consistent_stale_closure_receipt",
        "typed_absent_closure_receipt", "forged_failure_hash",
        "non_frozen_seed_self_consistent_receipt", "event_limit_self_consistent_tamper",
        "budget_caps_self_consistent_tamper", "budget_hash_tamper",
        "nonprefix_counter_self_consistent_tamper", "ledger_snapshot_counter_tamper",
        "rewrite_event_self_consistent_tamper", "receipt_make_replay_schema_equality",
        "receipt_seed_cap_self_consistent_tamper", "receipt_status_forgery",
         "node_payload_dict_rejected", "node_payload_set_rejected",
         "node_payload_custom_object_rejected", "node_payload_nested_unsupported_rejected",
         "multi_seed_cap_exceeded",
}


def main() -> int:
    source = SOURCE.read_text(encoding="utf-8")
    test = TEST.read_text(encoding="utf-8")
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    test_header = test.lstrip()
    assert test_header.startswith("# Executable future-focused tests"), (
        "test harness must begin with an independent comment header"
    )
    assert not test_header.startswith('"""'), (
        "test harness header must not attach a Julia docstring to using Test"
    )
    assert re.search(r"(?m)^using Test\s*$", test), (
        "test harness must load Test explicitly"
    )
    required = (
        "SearchInputClosureV1", "StructurePrefixV1", "StructureActionV1",
        "StructureSearchBudgetV1", "BudgetEventV1", "StructureProposalV1",
        "StructureLedgerSnapshotV1",
        "StructureContentReceiptV1", "StructureOperationalEnvelopeV1",
        "StructureDescriptorV1", "StructureSearchResultV1", "candidate_ref",
        "closure_hash", "parent_prefix_hash", "canonical_hash", "apply_action(",
        "conditions_met", "condition_unmet", "equality_unknown", "contradiction",
        "terminal_deferred", "saturation_incomplete", "max_seeds", "max_provider_steps=0",
        "max_solver_steps=0", "max_mesh_steps=0", "max_physical_steps=0",
        "m5c_gate_status", "pid", "started_utc", "run identifiers",
        "candidate_generation", "source_generation", "freshness_hash",
        "expected_candidate_generation", "expected_source_generation",
        "expected_token_generation", "expected_freshness_hash",
        "_action_sort_key", "prefix_by_hash", "_budget_precheck", "pending",
        "_zero_execution_counters", "_recomputed_content_hash",
        "prefix_semantic_bytes", "proposal_semantic_bytes",
        "descriptor_semantic_bytes", "ledger_semantic_bytes",
        "prefix_lineage", "proposal_lineage", "descriptor_lineage",
        "ledger_snapshot", "typed closure does not match receipt during replay",
        "failure hash mismatch", "proposal seed is not frozen for this slice",
        "ledger event seed/edge does not match frozen authority",
        "_validate_budget_ledger", "proposal_values::Tuple", "_budget_equal", "expected_budget",
        "budget authority hash mismatch", "budget caps",
        "ledger counters do not exactly join result counters",
        "prefix budget event progression mismatch",
        "proposal budget event progression mismatch",
        "rewrite budget event progression mismatch", "_content_receipt_body",
        "_RECEIPT_STATUSES", "_valid_receipt_status",
        "distinct proposal seeds exceed budget max_seeds",
        "unsupported canonical type", "unsupported canonical vector type",
        "_validate_node_payload_canonical", "_validate_node_payload_canonical(x::AbstractDict)",
        "_validate_node_payload_canonical(x::AbstractSet)",
        "budget_hash=budget.budget_hash", "budget_caps=_budget_body(budget)",
        "length(events) == 3 * length(proposal_values)",
        "event = events[3 * i - 1]",
        "proposal edge/sequence join mismatch",
        "descriptor does not match proposal child",
        "unsupported proposal emitter for this slice",
        "typed receipt closure validation failed",
        "content receipt requires a real typed budget ledger",
        "content receipt status mismatch", "content receipt counters mismatch",
        "budget event semantic hash mismatch", "semantic bytes disagree with typed",
        "proposal edge is not present in lineage",
        "ledger prefix counter does not match lineage",
        "descriptor ledger sequence mismatch",
        "BoundedStructureSearchV1._new_result",
        "StructureSearchResultV1 is sealed", "invoke(StructureSearchResultV1",
    )
    missing = [token for token in required if token not in source and token not in test]
    assert not missing, f"missing contract markers: {missing}"
    for call in (
        "prepare_search(", "make_root_prefix(", "apply_action(",
        "build_prefix_dag(", "validate_result(", "replay_content_hash(",
        "@test prepared.status === :terminal_deferred",
        "@test !apply_action(root, unmet, c; expected_candidate_generation=1",
        "closure and freshness gates cannot be bypassed",
        "canonical multi-lineage order and saturation boundaries",
        "sealed result and receipt tamper guards",
        "forged-content",
        "direct_apply_typed_absent", "direct_apply_stale_freshness",
        "receipt_status_mismatch", "receipt_counters_mismatch",
        "receipt_semantic_bytes_tamper", "receipt_edge_swap",
        "receipt_sequence_tamper", "receipt_descriptor_tamper",
        "receipt_semantic_bytes_self_consistent_tamper",
        "make_receipt_without_ledger_rejected", "mixed_failed_deferred_then_success",
        "foreign_emitter_rejected", "self_consistent_stale_closure_receipt",
        "typed_absent_closure_receipt",
        "rewrite_event_self_consistent_tamper", "receipt_make_replay_schema_equality",
        "receipt_seed_cap_self_consistent_tamper", "receipt_status_forgery",
        "node_payload_dict_rejected", "node_payload_set_rejected",
        "node_payload_custom_object_rejected", "node_payload_nested_unsupported_rejected",
        "top-level-dict", "top-level-set", "top-level-custom", "nested-set-payload",
        "(kind=(nested=Dict(:x => 1),),)", "(kind=(nested=Set([:x]),),)",
        "multi_seed_cap_exceeded", "zero_proposal_budget",
        "multi_budget", "max_seeds=0",
        "with_a.result_hash == with_b.result_hash",
        "with_a.content_receipt.content_hash == with_b.content_receipt.content_hash",
        "seed_bound.status === :terminal_deferred",
        "rewrite_bound.status === :terminal_deferred",
        "exact_bound.status === :screen_only",
    ):
        assert call in test, f"missing executable seam call: {call}"
    assert "(kind=(nested=Dict(:x => 1),),)" in test
    assert "(kind=(nested=Set([:x]),),)" in test
    assert "(kind=(nested=Dict(:x => 1),))" not in test
    assert "(kind=(nested=Set([:x]),))" not in test
    assert "StructureOperationalEnvelopeV1" in source
    assert "content_hash" in source and "operational_hash" in source
    assert "FROZEN_SEEDS" in source
    assert fixture["schema"] == "BoundedStructureSearchFixtureV1"
    assert fixture["status"] == "contract_only"
    assert fixture["claim_ceiling"] == "screen_only"
    assert fixture["accepted"] is False and fixture["no_publish"] is True
    assert fixture["frozen_seeds"] == [11, 23, 37, 41, 53, 67, 79, 97]
    assert all(fixture["budget"][k] == 0 for k in
               ("provider_steps", "solver_steps", "mesh_steps", "physical_steps"))
    assert fixture["unsupported_budget_dimensions"] == [
        "eclasses", "enodes", "trace_rows", "screen_evaluations",
        "global_trace_rows", "qd_proposals", "mcts_proposals"
    ]
    for unsupported in fixture["unsupported_budget_dimensions"]:
        assert f"max_{unsupported}" not in source
    assert fixture["receipt_statuses"] == [
        "screen_only", "terminal_deferred", "fail_closed", "not_executed"
    ]
    assert len(fixture["negative_vectors"]) == 60
    assert set(fixture["negative_vectors"]) == EXPECTED_NEGATIVE_VECTORS
    assert set(fixture["executable_negative_vectors"]) == EXPECTED_NEGATIVE_VECTORS
    coverage_block = re.search(
        r"# BEGIN_NEGATIVE_VECTOR_COVERAGE\n(.*?)# END_NEGATIVE_VECTOR_COVERAGE",
        test, flags=re.S)
    assert coverage_block, "missing executable negative-vector coverage block"
    test_vectors = set(re.findall(r'"([a-z0-9_]+)"', coverage_block.group(1)))
    assert len(test_vectors) == 60 and test_vectors == EXPECTED_NEGATIVE_VECTORS
    assert "@test length(NEGATIVE_VECTOR_COVERAGE_V1) == 60" in test
    assert "@test length(unique(NEGATIVE_VECTOR_COVERAGE_V1)) == 60" in test
    assert {
        "receipt_status_counter_join", "receipt_semantic_bytes_recompute"
    }.issubset(set(fixture["required_evidence"]))
    assert {
        "typed_budget_authority", "budget_event_cap_join",
        "budget_counter_exact_join", "budget_hash_tamper_rejected",
        "nonprefix_counter_rejected", "distinct_seed_cap_join",
        "receipt_status_enum", "node_payload_closed_canonical_input"
        , "zero_proposal_budget_semantics", "multi_seed_budget_join"
    }.issubset(set(fixture["required_evidence"]))
    forbidden_wiring = (
        "include(joinpath(@__DIR__, \"../../../src/FusionConceptAI.jl\"))",
        "default_operator_registry", "FusionRuntimeV4.jl", "Search.jl",
    )
    assert not any(token in source for token in forbidden_wiring)
    print(json.dumps({
        "record_kind": "UP5-M5-structure-search-static-qa",
        "status": "pass",
        "julia_executed": False,
        "desc_executed": False,
        "accepted": False,
        "claim_ceiling": "screen_only",
        "formal_credit": "none",
        "negative_vector_count": len(fixture["negative_vectors"]),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
