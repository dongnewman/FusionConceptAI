"""Python-only contract oracle and source checks for UP5 edge obligations.

This does not load Julia. The model below checks the frozen identity/binding
rules; source checks verify the isolated Julia implementation exposes the same
fields and fail-closed seams. A pass is not runtime, evaluator, Search, or
physical evidence.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
MODULE = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl"
RUNTIME_ENTRY = ROOT / "src/RuntimeV4/FusionRuntimeV4.jl"
PACKAGE_ENTRY = ROOT / "src/FusionConceptAI.jl"
STRONG_G1_TEST = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV5/search_physical_consumer_v5_deferred_tests.jl"


def canonical_hash(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


@dataclasses.dataclass(frozen=True)
class Edge:
    layer: str
    graph_role: str
    graph_hash: str
    edge_position: int
    edge_id: str
    edge_hash: str
    program_hash: str
    root_position: int
    operator_id: str
    operator_version: str

    @property
    def identity_hash(self) -> str:
        return canonical_hash(dataclasses.asdict(self))


@dataclasses.dataclass(frozen=True)
class Attempt:
    edge_identity_hash: str | None
    candidate_hash: str
    context_hash: str
    scenario_hash: str
    registry_hash: str
    capability_hash: str
    request_hash: str
    receipt_hash: str
    input_hash: str
    output_hash: str
    provider_status: str
    exit_code: int

    def receipt_body(self) -> dict[str, object]:
        return {
            "edge_identity_hash": self.edge_identity_hash,
            "candidate_hash": self.candidate_hash,
            "context_hash": self.context_hash,
            "scenario_hash": self.scenario_hash,
            "registry_hash": self.registry_hash,
            "capability_hash": self.capability_hash,
            "request_hash": self.request_hash,
            "input_hash": self.input_hash,
            "output_hash": self.output_hash,
            "provider_status": self.provider_status,
            "exit_code": self.exit_code,
        }


@dataclasses.dataclass(frozen=True)
class BoundObligation:
    edge: Edge
    candidate_hash: str
    context_hash: str
    scenario_hash: str
    capability_hash: str | None = None
    receipt_state: str = "missing"
    provider_state: str = "unresolved"
    attempt: Attempt | None = None


def make_two_identity_edges() -> tuple[Edge, Edge]:
    # The deliberately same capability and source program model two distinct
    # strong G1 edges; edge position/id and edge hash must preserve both.
    shared = dict(layer="g1_mechanism", graph_role="mechanism",
                  graph_hash="1" * 64, program_hash="2" * 64,
                  root_position=1, operator_id="IDENTITY",
                  operator_version="v1")
    return (
        Edge(**shared, edge_position=1, edge_id="g1_identity_left", edge_hash="3" * 64),
        Edge(**shared, edge_position=2, edge_id="g1_identity_right", edge_hash="4" * 64),
    )


def sample_attempt(edge: Edge, *, candidate: str = "a" * 64,
                   context: str = "b" * 64, scenario: str = "c" * 64,
                   registry: str = "d" * 64, capability: str = "e" * 64,
                   status: str = "completed", exit_code: int = 0) -> Attempt:
    request_hash = canonical_hash({"candidate": candidate, "context": context,
                                   "scenario": scenario, "registry": registry,
                                   "capability": capability,
                                   "edge_identity": edge.identity_hash})
    fields = dict(candidate_hash=candidate, context_hash=context,
                  edge_identity_hash=edge.identity_hash,
                  scenario_hash=scenario, registry_hash=registry,
                  capability_hash=capability, request_hash=request_hash,
                  receipt_hash="0" * 64, input_hash="5" * 64,
                  output_hash="6" * 64, provider_status=status,
                  exit_code=exit_code)
    item = Attempt(**fields)
    return dataclasses.replace(item, receipt_hash=canonical_hash(item.receipt_body()))


def bind_model(obligation: BoundObligation, attempt: Attempt | None,
               *, expected_candidate: str, expected_context: str,
               expected_scenario: str, expected_registry: str,
               expected_capability: str) -> BoundObligation:
    if attempt is None:
        return obligation
    if (attempt.candidate_hash != expected_candidate or
            attempt.context_hash != expected_context or
            attempt.scenario_hash != expected_scenario):
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="stale", attempt=attempt)
    if attempt.edge_identity_hash != obligation.edge.identity_hash:
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="foreign", attempt=attempt)
    if attempt.registry_hash != expected_registry:
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="foreign", attempt=attempt)
    if attempt.capability_hash != expected_capability:
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="invalid", attempt=attempt)
    expected_request_hash = canonical_hash({
        "candidate": expected_candidate, "context": expected_context,
        "scenario": expected_scenario, "registry": expected_registry,
        "capability": expected_capability,
        "edge_identity": obligation.edge.identity_hash,
    })
    if attempt.request_hash != expected_request_hash:
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="foreign", attempt=attempt)
    if attempt.receipt_hash != canonical_hash(attempt.receipt_body()):
        return dataclasses.replace(obligation, receipt_state="rejected",
                                   provider_state="foreign", attempt=attempt)
    state = "completed" if attempt.provider_status == "completed" and attempt.exit_code == 0 else "failed"
    return dataclasses.replace(obligation, capability_hash=expected_capability,
                               receipt_state="validated", provider_state=state,
                               attempt=attempt)


def assess_model(obligations: tuple[BoundObligation, ...], expected_edges: tuple[Edge, ...],
                 *, unresolved_nonterminals: tuple[str, ...] = ()) -> dict[str, object]:
    actual = tuple(item.edge.identity_hash for item in obligations)
    expected = tuple(item.identity_hash for item in expected_edges)
    if len(actual) != len(set(actual)) or actual != expected:
        return {"status": "deferred", "reason": "typed_obligation_set_invalid", "activated": False}
    if unresolved_nonterminals:
        return {"status": "deferred", "reason": "compiler_gap_has_no_edge_bound_resolution", "activated": False}
    if any(item.receipt_state != "validated" for item in obligations):
        return {"status": "deferred", "reason": "provider_receipt_missing_or_rejected", "activated": False}
    if any(item.provider_state != "completed" for item in obligations):
        return {"status": "deferred", "reason": "provider_did_not_complete", "activated": False}
    requests = tuple(item.attempt.request_hash for item in obligations if item.attempt is not None)
    if len(requests) != len(set(requests)):
        return {"status": "deferred", "reason": "edge_receipt_reused", "activated": False}
    return {"status": "contract_ready_unwired", "reason": "shared_compiler_queue_entry_not_wired", "activated": False}


class PhysicalEdgeContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.edges = make_two_identity_edges()
        self.candidate = "a" * 64
        self.context = "b" * 64
        self.scenario = "c" * 64
        self.registry = "d" * 64
        self.capability = "e" * 64
        self.pending = tuple(BoundObligation(edge, self.candidate,
            self.context, self.scenario) for edge in self.edges)

    def test_two_strong_identity_edges_remain_two_obligations(self) -> None:
        self.assertEqual(self.edges[0].operator_id, self.edges[1].operator_id)
        self.assertEqual(self.edges[0].operator_version, self.edges[1].operator_version)
        self.assertNotEqual(self.edges[0].identity_hash, self.edges[1].identity_hash)
        self.assertEqual(len({x.edge.identity_hash for x in self.pending}), 2)

    def test_same_operator_text_in_g1_and_g3_has_distinct_edge_identity(self) -> None:
        g1 = self.edges[0]
        g3 = dataclasses.replace(g1, layer="g3_control", graph_role="control",
                                 graph_hash="9" * 64)
        self.assertEqual((g1.operator_id, g1.operator_version),
                         (g3.operator_id, g3.operator_version))
        self.assertNotEqual(g1.identity_hash, g3.identity_hash)

    def test_duplicate_identity_edges_require_separate_edge_bound_requests(self) -> None:
        bound = bind_model(self.pending[1], sample_attempt(self.edges[0]),
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "foreign"))

    def test_legacy_request_without_edge_identity_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0])
        legacy = dataclasses.replace(attempt, edge_identity_hash=None)
        bound = bind_model(self.pending[0], legacy,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "foreign"))

    def test_duplicate_identity_edges_accept_only_two_distinct_edge_bound_receipts(self) -> None:
        completed = tuple(bind_model(item, sample_attempt(item.edge),
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability) for item in self.pending)
        self.assertEqual(assess_model(completed, self.edges)["status"],
                         "contract_ready_unwired")
        reused = (completed[0], dataclasses.replace(completed[1],
            attempt=completed[0].attempt))
        self.assertEqual(assess_model(reused, self.edges)["reason"], "edge_receipt_reused")

    def test_collapsed_duplicate_capability_is_rejected(self) -> None:
        result = assess_model(self.pending[:1], self.edges)
        self.assertEqual(result["reason"], "typed_obligation_set_invalid")
        self.assertFalse(result["activated"])

    def test_missing_receipts_defer(self) -> None:
        result = assess_model(self.pending, self.edges)
        self.assertEqual(result["reason"], "provider_receipt_missing_or_rejected")

    def test_foreign_candidate_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], candidate="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "stale"))

    def test_stale_context_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], context="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "stale"))

    def test_foreign_registry_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], registry="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "foreign"))

    def test_foreign_capability_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], capability="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "invalid"))

    def test_receipt_hash_tampering_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0])
        forged = dataclasses.replace(attempt, output_hash="f" * 64)
        bound = bind_model(self.pending[0], forged,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "foreign"))

    def test_nonzero_provider_result_is_not_contract_complete(self) -> None:
        edge = Edge(layer="g2_field_geometry", graph_role="field_geometry",
            graph_hash="7" * 64, edge_position=1, edge_id="g2_grad",
            edge_hash="8" * 64, program_hash="9" * 64, root_position=1,
            operator_id="GRAD", operator_version="v1")
        obligation = BoundObligation(edge, self.candidate, self.context, self.scenario)
        attempt = sample_attempt(edge, status="executor_error", exit_code=1)
        bound = bind_model(obligation, attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual(bound.receipt_state, "validated")
        self.assertEqual(bound.provider_state, "failed")
        self.assertEqual(assess_model((bound,), (edge,))["reason"],
                         "provider_did_not_complete")

    def test_string_only_compiler_gap_cannot_activate(self) -> None:
        completed = tuple(bind_model(item, sample_attempt(item.edge),
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability) for item in self.pending)
        result = assess_model(completed, self.edges,
            unresolved_nonterminals=("required_physical_capability:IDENTITY@v1",))
        self.assertEqual(result["reason"], "compiler_gap_has_no_edge_bound_resolution")
        self.assertFalse(result["activated"])

    def test_positive_contract_still_does_not_activate_or_award_credit(self) -> None:
        edge = Edge(layer="g2_field_geometry", graph_role="field_geometry",
            graph_hash="7" * 64, edge_position=1, edge_id="g2_grad",
            edge_hash="8" * 64, program_hash="9" * 64, root_position=1,
            operator_id="GRAD", operator_version="v1")
        obligation = BoundObligation(edge, self.candidate, self.context, self.scenario)
        completed = (bind_model(obligation, sample_attempt(edge),
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability),)
        result = assess_model(completed, (edge,))
        self.assertEqual(result["status"], "contract_ready_unwired")
        self.assertFalse(result["activated"])

    def test_one_receipt_hash_cannot_be_reused_for_two_edges(self) -> None:
        left, right = self.edges
        shared_attempt = sample_attempt(left)
        left_bound = dataclasses.replace(self.pending[0], receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=shared_attempt)
        right_bound = dataclasses.replace(self.pending[1], receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=shared_attempt)
        result = assess_model((left_bound, right_bound), self.edges)
        self.assertEqual(result["reason"], "edge_receipt_reused")


class JuliaSourceBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = MODULE.read_text(encoding="utf-8")

    def test_module_is_not_wired_into_shared_entries(self) -> None:
        self.assertNotIn("PhysicalEdgeObligationV1.jl", RUNTIME_ENTRY.read_text(encoding="utf-8"))
        self.assertNotIn("PhysicalEdgeObligationV1", PACKAGE_ENTRY.read_text(encoding="utf-8"))

    def test_edge_enumerator_keeps_each_edge_and_root(self) -> None:
        self.assertIn("for (edge_position, edge) in enumerate(graph.hyperedges)", self.source)
        self.assertIn("for root_position in eachindex(roots)", self.source)
        for token in ("graph_hash::Digest256", "edge_position::Int", "edge_id::String",
                      "edge_hash::Digest256", "root_position::Int", "operator_id::String",
                      "operator_version::String", "candidate_hash::Digest256",
                      "genome_bundle_hash::Digest256", "context_hash::Digest256",
                      "scenario_hash::Digest256"):
            self.assertIn(token, self.source)
        for layer_token in ("return :g1_mechanism", "return :g2_field_geometry",
                            "return :g3_realization", "return :g3_control"):
            self.assertIn(layer_token, self.source)

    def test_receipt_binding_uses_repository_types_and_revalidators(self) -> None:
        for token in ("TrustedProviderDispatchRequestV4", "TrustedProviderExecutionReceiptV4",
                      "validate_trusted_provider_dispatch_request(",
                      "validate_trusted_provider_execution_receipt(",
                      "request.registry_hash == registry.registry_hash",
                      "request.context_hash == context.context_hash"):
            self.assertIn(token, self.source)

    def test_duplicate_operator_mapping_fails_closed(self) -> None:
        self.assertIn("obligations::Tuple{Vararg{PhysicalEdgeObligationV1}}", self.source)
        self.assertIn("struct PhysicalEdgeProviderInputV1", self.source)
        self.assertIn("request_missing_edge_identity", self.source)
        self.assertIn("edge_input.edge_identity_hash == obligation.identity.identity_hash", self.source)
        self.assertIn("one trusted provider request cannot discharge multiple edge obligations", self.source)

    def test_existing_strong_g1_fixture_is_two_atomic_identity_edges(self) -> None:
        test_source = STRONG_G1_TEST.read_text(encoding="utf-8")
        self.assertIn("length(edges) == 2", test_source)
        self.assertIn("typeof(edge) === AtomicMIMOHyperedgeV1", test_source)
        self.assertIn('"required_physical_capability:IDENTITY@v1"', test_source)

    def test_no_provider_dispatch_or_queue_mutation_surface(self) -> None:
        self.assertNotRegex(self.source, r"\bexecute_trusted_provider\s*\(")
        self.assertNotRegex(self.source, r"\b(?:enqueue_candidate!|next_compilable!|mark_failed!)\s*\(")

    def test_activation_is_explicitly_deferred_and_zero_credit(self) -> None:
        body = self.source.split("function search_activation_disposition_v1", 1)[1]
        self.assertIn("status=:deferred", body)
        self.assertIn("activated=false", body)
        self.assertIn("candidate_discovery_credit=0", body)
        self.assertIn("engineering_validation=false", body)


if __name__ == "__main__":
    unittest.main(verbosity=2)
