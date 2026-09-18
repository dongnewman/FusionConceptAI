"""Independent content oracle for the contract-only structure-search slice.

It intentionally does not import Julia or the product package.  It checks the
fixture boundary and the content/operational split only; full canonical
replay remains deferred to an independent Julia lane.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def canonical_hash(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def validate_fixture(path: Path) -> dict[str, object]:
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["status"] == "contract_only"
    assert data["claim_ceiling"] == "screen_only"
    assert data["accepted"] is False and data["no_publish"] is True
    assert data["receipt_statuses"] == [
        "screen_only", "terminal_deferred", "fail_closed", "not_executed"
    ]
    assert data["budget"]["provider_steps"] == 0
    assert data["budget"]["solver_steps"] == 0
    assert data["budget"]["mesh_steps"] == 0
    assert data["budget"]["physical_steps"] == 0
    required_negative = {
        "builder_gate_bypass", "freshness_hash_mismatch",
        "source_generation_mismatch", "action_order_permutation",
        "multi_lineage_parent_lookup", "proposal_overflow_pre_mutation",
        "sealed_result_counter_injection", "content_receipt_tamper",
        "operational_identity_exclusion", "direct_apply_typed_absent",
        "direct_apply_stale_freshness", "unsupported_budget_dimension_rejected",
        "receipt_status_mismatch", "receipt_counters_mismatch",
        "receipt_semantic_bytes_tamper", "receipt_edge_swap",
        "receipt_sequence_tamper", "receipt_descriptor_tamper",
        "receipt_semantic_bytes_self_consistent_tamper",
        "make_receipt_without_ledger_rejected", "mixed_failed_deferred_then_success",
        "foreign_emitter_rejected", "self_consistent_stale_closure_receipt",
        "typed_absent_closure_receipt",
        "forged_failure_hash", "non_frozen_seed_self_consistent_receipt",
        "event_limit_self_consistent_tamper", "budget_caps_self_consistent_tamper",
        "budget_hash_tamper", "nonprefix_counter_self_consistent_tamper",
        "ledger_snapshot_counter_tamper", "rewrite_event_self_consistent_tamper",
        "receipt_make_replay_schema_equality", "receipt_seed_cap_self_consistent_tamper",
        "receipt_status_forgery", "node_payload_dict_rejected",
        "node_payload_set_rejected", "node_payload_custom_object_rejected",
        "node_payload_nested_unsupported_rejected",
        "multi_seed_cap_exceeded",
    }
    assert required_negative.issubset(set(data["negative_vectors"]))
    assert len(data["negative_vectors"]) == 60
    assert set(data["executable_negative_vectors"]) == set(data["negative_vectors"])
    required_evidence = {
        "canonical_action_sort_and_parent_index",
        "supported_budget_dimensions_prechecked",
        "unsupported_budget_dimensions_explicit_zero",
        "sealed_result_counter_boundary",
        "independent_content_receipt_recompute", "receipt_status_counter_join",
        "receipt_semantic_bytes_recompute",
        "typed_lineage_rebuild", "exact_parent_child_sequence_join",
        "typed_ledger_snapshot_rebuild", "real_ledger_required",
        "successful_proposal_sequence_contiguous",
        "attempt_sequence_separate_from_proposal_sequence",
        "grammar_emitter_only",
        "receipt_closure_revalidated",
        "typed_budget_authority", "budget_event_cap_join",
        "budget_counter_exact_join", "budget_hash_tamper_rejected",
        "nonprefix_counter_rejected", "distinct_seed_cap_join",
        "receipt_status_enum", "node_payload_closed_canonical_input",
        "zero_proposal_budget_semantics", "multi_seed_budget_join",
        "operational_identity_exclusion",
    }
    assert required_evidence.issubset(set(data["required_evidence"]))
    return data


if __name__ == "__main__":
    fixture = Path(__file__).with_name("..") / "bounded_structure_search_v1_fixture.json"
    fixture = fixture.resolve()
    data = validate_fixture(fixture)
    print(json.dumps({"status": "pass", "schema": data["schema"],
                      "fixture_hash": canonical_hash(data)}, sort_keys=True))
