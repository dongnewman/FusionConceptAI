"""Independent Python-only checks for the isolated UP5 edge contract.

This intentionally does not import the owner's Python test or load Julia. The
synthetic receipt model checks edge scoping and fail-closed cases; source text
checks bind those expectations to the frozen Julia implementation. It is not a
runtime, Search-consumer, or physical-validation test.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl"
FIXTURE = ROOT / "examples/runtime_v4_declared_fixture.jl"
STRONG_G1 = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV5/search_physical_consumer_v5_deferred_tests.jl"


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def edge(index: int, *, layer: str = "g1_mechanism") -> dict[str, object]:
    shared: dict[str, object] = {
        "schema": "fusionconceptai:up5-physical-edge-identity-v1",
        "layer": layer,
        "genome_role": "mechanism" if layer == "g1_mechanism" else "realization",
        "graph_role": "mechanism" if layer == "g1_mechanism" else "realization",
        "graph_hash": "1" * 64,
        "program_hash": "2" * 64,
        "root_position": 1,
        "root_node_hash": "3" * 64,
        "operator_id": "IDENTITY",
        "operator_version": "v1",
        "operator_manifest_hash": None,
    }
    sites = ("runtime-site-a", "runtime-site-b")
    edge_hashes = ("4" * 64, "5" * 64)
    shared.update(edge_position=index + 1, edge_id=sites[index], edge_hash=edge_hashes[index])
    return shared


EDGES = (edge(0), edge(1))
EDGE_HASHES = tuple(canonical_hash(item) for item in EDGES)
CONTEXT = {
    "candidate": "a" * 64,
    "bundle": "b" * 64,
    "context": "c" * 64,
    "scenario": "d" * 64,
    "registry": "e" * 64,
    "capability": "f" * 64,
}


def make_attempt(index: int, *, envelope_changes: dict[str, str] | None = None,
                 registry_hash: str | None = None, status: str = "completed",
                 exit_code: int = 0, receipt_hash: str | None = None) -> dict[str, object]:
    envelope = {
        "edge_identity_hash": EDGE_HASHES[index],
        "candidate_hash": CONTEXT["candidate"],
        "genome_bundle_hash": CONTEXT["bundle"],
        "context_hash": CONTEXT["context"],
        "scenario_hash": CONTEXT["scenario"],
        "capability_hash": CONTEXT["capability"],
        "provider_payload_hash": "9" * 64,
    }
    envelope.update(envelope_changes or {})
    request_hash = canonical_hash(envelope)
    body = {
        "edge_identity_hash": envelope.get("edge_identity_hash"),
        "candidate_hash": envelope.get("candidate_hash"),
        "genome_bundle_hash": envelope.get("genome_bundle_hash"),
        "context_hash": envelope.get("context_hash"),
        "scenario_hash": envelope.get("scenario_hash"),
        "capability_hash": envelope.get("capability_hash"),
        "registry_hash": registry_hash or CONTEXT["registry"],
        "request_hash": request_hash,
        "status": status,
        "exit_code": exit_code,
    }
    return {
        "envelope": envelope,
        "request_hash": request_hash,
        "body": body,
        "receipt_hash": receipt_hash or canonical_hash(body),
    }


def bind_synthetic(attempt: object, expected_edge_index: int) -> bool:
    if not isinstance(attempt, dict):
        return False
    envelope = attempt.get("envelope")
    body = attempt.get("body")
    if not isinstance(envelope, dict) or not isinstance(body, dict):
        return False
    expected = {
        "edge_identity_hash": EDGE_HASHES[expected_edge_index],
        "candidate_hash": CONTEXT["candidate"],
        "genome_bundle_hash": CONTEXT["bundle"],
        "context_hash": CONTEXT["context"],
        "scenario_hash": CONTEXT["scenario"],
        "capability_hash": CONTEXT["capability"],
    }
    if any(envelope.get(key) != value or body.get(key) != value
           for key, value in expected.items()):
        return False
    receipt_hash = attempt.get("receipt_hash")
    return (
        body.get("registry_hash") == CONTEXT["registry"]
        and attempt.get("request_hash") == canonical_hash(envelope) == body.get("request_hash")
        and isinstance(receipt_hash, str)
        and re.fullmatch(r"[0-9a-f]{64}", receipt_hash) is not None
        and receipt_hash == canonical_hash(body)
    )


def exact_inventory(actual: tuple[str, ...], expected: tuple[str, ...]) -> bool:
    return len(actual) == len(set(actual)) and actual == expected


class IndependentPhysicalEdgeContractChecks(unittest.TestCase):
    def test_01_strong_g1_fixture_has_two_sites_and_same_identity_program(self) -> None:
        fixture = FIXTURE.read_text(encoding="utf-8")
        self.assertIn('program = _fixture_program()', fixture)
        self.assertIn('AtomicMIMOHyperedgeV1("runtime-site-a"', fixture)
        self.assertIn('AtomicMIMOHyperedgeV1("runtime-site-b"', fixture)
        self.assertIn('(edge_a, edge_b)', fixture)
        self.assertIn('OperatorRefV1("IDENTITY", "v1")', fixture)

    def test_02_strong_g1_regression_asserts_two_atomic_edges_and_gap(self) -> None:
        text = STRONG_G1.read_text(encoding="utf-8")
        self.assertIn('@test length(edges) == 2', text)
        self.assertIn('@test all(typeof(edge) === AtomicMIMOHyperedgeV1 for edge in edges)', text)
        self.assertIn('required_physical_capability:IDENTITY@v1', text)

    def test_03_source_identity_commits_position_id_and_edge_hash(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        for field in ("edge_position=", "edge_id=", "edge_hash="):
            self.assertIn(field, text)

    def test_04_source_enumerates_each_edge_and_program_root(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("enumerate(graph.hyperedges)", text)
        self.assertIn("eachindex(roots)", text)

    def test_05_source_requires_exact_ordered_inventory(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("actual_hashes == expected_hashes", text)
        self.assertIn("typed obligation set does not cover every edge/root", text)

    def test_06_source_binds_candidate_context_and_scenario(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        for fragment in (
            "obligation.candidate_hash == context.candidate_hash",
            "obligation.context_hash == context.context_hash",
            "obligation.scenario_hash == context.scenario_hash",
        ):
            self.assertIn(fragment, text)

    def test_07_source_rejects_missing_edge_envelope(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("edge_input isa PhysicalEdgeProviderInputV1", text)
        self.assertIn("request_missing_edge_identity", text)

    def test_08_source_revalidates_repository_request_and_receipt(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("validate_trusted_provider_dispatch_request", text)
        self.assertIn("validate_trusted_provider_execution_receipt", text)

    def test_09_source_keeps_unresolved_compiler_gap_deferred(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        self.assertIn("compiler_gap_has_no_edge_bound_resolution", text)

    def test_10_source_hardcodes_deferred_activation_ceiling(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        for fragment in (
            "(status=:deferred, activated=false",
            "physical_validation=false",
            "engineering_validation=false",
            "candidate_discovery_credit=0",
            "credible_device_count=0",
        ):
            self.assertIn(fragment, text)

    def test_11_two_g1_identity_edges_remain_distinct(self) -> None:
        self.assertEqual(EDGES[0]["operator_id"], EDGES[1]["operator_id"])
        self.assertEqual(EDGES[0]["operator_version"], EDGES[1]["operator_version"])
        self.assertNotEqual(EDGE_HASHES[0], EDGE_HASHES[1])

    def test_12_two_distinct_edge_receipts_bind(self) -> None:
        self.assertTrue(bind_synthetic(make_attempt(0), 0))
        self.assertTrue(bind_synthetic(make_attempt(1), 1))

    def test_13_edge_a_receipt_cannot_bind_edge_b(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0), 1))

    def test_14_malformed_receipt_hash_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0, receipt_hash="not-a-hash"), 0))

    def test_15_foreign_candidate_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0, envelope_changes={"candidate_hash": "0" * 64}), 0))

    def test_16_stale_context_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0, envelope_changes={"context_hash": "0" * 64}), 0))

    def test_17_foreign_registry_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0, registry_hash="0" * 64), 0))

    def test_18_foreign_capability_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(make_attempt(0, envelope_changes={"capability_hash": "0" * 64}), 0))

    def test_19_missing_receipt_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic(None, 0))

    def test_20_unwrapped_legacy_request_is_rejected(self) -> None:
        self.assertFalse(bind_synthetic({"body": make_attempt(0)["body"]}, 0))

    def test_21_receipt_reuse_cannot_discharge_second_edge(self) -> None:
        receipt = make_attempt(0)
        self.assertTrue(bind_synthetic(receipt, 0))
        self.assertFalse(bind_synthetic(receipt, 1))

    def test_22_provider_failure_is_not_completion(self) -> None:
        failed = make_attempt(0, status="failed", exit_code=7)
        self.assertTrue(bind_synthetic(failed, 0))
        self.assertFalse(failed["body"]["status"] == "completed" and failed["body"]["exit_code"] == 0)

    def test_23_inventory_must_be_complete_unique_and_ordered(self) -> None:
        expected = EDGE_HASHES
        self.assertTrue(exact_inventory(expected, expected))
        self.assertFalse(exact_inventory(expected[:1], expected))
        self.assertFalse(exact_inventory(tuple(reversed(expected)), expected))
        self.assertFalse(exact_inventory((expected[0], expected[0]), expected))

    def test_24_g3_identity_is_not_same_as_g1_identity(self) -> None:
        g3_hash = canonical_hash(edge(0, layer="g3_realization"))
        self.assertNotEqual(g3_hash, EDGE_HASHES[0])

    def test_25_unresolved_identity_gap_blocks_positive_synthetic_receipts(self) -> None:
        text = SOURCE.read_text(encoding="utf-8")
        all_receipts_valid = all(bind_synthetic(make_attempt(i), i) for i in range(2))
        unresolved = ("required_physical_capability:IDENTITY@v1",)
        self.assertTrue(all_receipts_valid)
        self.assertTrue(unresolved)
        self.assertIn("compiler_gap_has_no_edge_bound_resolution", text)

    def test_26_positive_contract_still_has_zero_activation_credit(self) -> None:
        result = {
            "status": "deferred",
            "activated": False,
            "physical_validation": False,
            "engineering_validation": False,
            "candidate_discovery_credit": 0,
            "credible_device_count": 0,
        }
        self.assertEqual(result["status"], "deferred")
        self.assertFalse(result["activated"])
        self.assertEqual(result["candidate_discovery_credit"], 0)
        self.assertEqual(result["credible_device_count"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
