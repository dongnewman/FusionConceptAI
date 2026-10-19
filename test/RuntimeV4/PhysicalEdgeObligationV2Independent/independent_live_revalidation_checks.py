"""Independent Python-only probes for UP5 PhysicalEdgeObligationV2.

The synthetic trust callback is a test double. This file never imports the
owner's oracle, loads Julia, runs a provider, or grants a physical claim.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
V1 = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl"
V2 = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV2.jl"
OWNER_TEST = ROOT / "test/RuntimeV4/PhysicalEdgeObligationV2/verify_static_contract.py"
JULIA_FIXTURE = ROOT / "test/RuntimeV4/PhysicalEdgeObligationV2/physical_edge_obligation_v2_tests.jl"
STRONG_G1 = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV5/search_physical_consumer_v5_deferred_tests.jl"
RUNTIME_ENTRY = ROOT / "src/RuntimeV4/FusionRuntimeV4.jl"
PACKAGE_ENTRY = ROOT / "src/FusionConceptAI.jl"


def canonical_hash(value: object) -> str:
    body = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


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
    operator: str

    @property
    def identity(self) -> str:
        return canonical_hash(dataclasses.asdict(self))


@dataclasses.dataclass(frozen=True)
class Attempt:
    edge_identity: str
    obligation_hash: str
    candidate: str
    bundle: str
    context: str
    scenario: str
    registry: str
    capability: str
    request_hash: str
    receipt_hash: str
    provider_status: str = "completed"
    exit_code: int = 0

    def receipt_body(self) -> dict[str, object]:
        return {
            "edge_identity": self.edge_identity,
            "obligation_hash": self.obligation_hash,
            "candidate": self.candidate,
            "bundle": self.bundle,
            "context": self.context,
            "scenario": self.scenario,
            "registry": self.registry,
            "capability": self.capability,
            "request_hash": self.request_hash,
            "provider_status": self.provider_status,
            "exit_code": self.exit_code,
        }


@dataclasses.dataclass(frozen=True)
class Cached:
    edge: Edge
    obligation_hash: str
    capability: str
    receipt_state: str = "validated"
    provider_state: str = "completed"
    attempt: Attempt | None = None


CONTEXT = {
    "candidate": "a" * 64,
    "bundle": "b" * 64,
    "context": "c" * 64,
    "scenario": "d" * 64,
    "registry": "e" * 64,
    "capability": "f" * 64,
}
EDGES = (
    Edge("g1_mechanism", "mechanism", "1" * 64, 1, "runtime-site-a", "2" * 64,
         "3" * 64, 1, "IDENTITY@v1"),
    Edge("g1_mechanism", "mechanism", "1" * 64, 2, "runtime-site-b", "4" * 64,
         "3" * 64, 1, "IDENTITY@v1"),
)


def make_attempt(edge: Edge, *, obligation_hash: str | None = None,
                 changes: dict[str, object] | None = None,
                 provider_status: str = "completed", exit_code: int = 0,
                 bad_receipt_hash: str | None = None) -> Attempt:
    ob_hash = obligation_hash or canonical_hash({"edge": edge.identity, "revision": "V1"})
    req_body = {
        "edge_identity": edge.identity,
        "obligation_hash": ob_hash,
        "candidate": CONTEXT["candidate"],
        "bundle": CONTEXT["bundle"],
        "context": CONTEXT["context"],
        "scenario": CONTEXT["scenario"],
        "registry": CONTEXT["registry"],
        "capability": CONTEXT["capability"],
    }
    req_body.update(changes or {})
    request_hash = canonical_hash(req_body)
    draft = {
        "edge_identity": req_body.get("edge_identity"),
        "obligation_hash": req_body.get("obligation_hash"),
        "candidate": req_body.get("candidate"),
        "bundle": req_body.get("bundle"),
        "context": req_body.get("context"),
        "scenario": req_body.get("scenario"),
        "registry": req_body.get("registry"),
        "capability": req_body.get("capability"),
        "request_hash": request_hash,
        "provider_status": provider_status,
        "exit_code": exit_code,
    }
    return Attempt(
        str(draft["edge_identity"]), str(draft["obligation_hash"]),
        str(draft["candidate"]), str(draft["bundle"]), str(draft["context"]),
        str(draft["scenario"]), str(draft["registry"]), str(draft["capability"]),
        request_hash, bad_receipt_hash or canonical_hash(draft), provider_status, exit_code,
    )


def valid_live_attempt(edge: Edge, cached: Cached, attempt: Attempt,
                       admitted: set[int]) -> bool:
    if id(attempt) not in admitted:
        return False
    if attempt.edge_identity != edge.identity or attempt.obligation_hash != cached.obligation_hash:
        return False
    if (attempt.candidate, attempt.bundle, attempt.context, attempt.scenario,
            attempt.registry, attempt.capability) != (
            CONTEXT["candidate"], CONTEXT["bundle"], CONTEXT["context"],
            CONTEXT["scenario"], CONTEXT["registry"], CONTEXT["capability"]):
        return False
    request_body = {
        "edge_identity": attempt.edge_identity,
        "obligation_hash": attempt.obligation_hash,
        "candidate": attempt.candidate,
        "bundle": attempt.bundle,
        "context": attempt.context,
        "scenario": attempt.scenario,
        "registry": attempt.registry,
        "capability": attempt.capability,
    }
    if attempt.request_hash != canonical_hash(request_body):
        return False
    return attempt.receipt_hash == canonical_hash(attempt.receipt_body())


def assess_v1_cached(cached: tuple[Cached, ...], expected: tuple[Edge, ...], *, gaps: tuple[str, ...] = ()) -> str:
    if tuple(x.edge.identity for x in cached) != tuple(x.identity for x in expected):
        return "deferred"
    if gaps or not cached:
        return "deferred"
    if any(x.receipt_state != "validated" or x.provider_state != "completed" for x in cached):
        return "deferred"
    return "contract_ready_unwired"


def assess_v2(cached: tuple[Cached, ...], attempts: tuple[Attempt, ...], *,
              admitted: set[int], gaps: tuple[str, ...] = ()) -> str:
    if tuple(x.edge.identity for x in cached) != tuple(x.identity for x in EDGES):
        return "deferred:typed_obligation_set_invalid"
    if gaps:
        return "deferred:compiler_gap_has_no_edge_bound_resolution"
    if len(attempts) != len(cached):
        return "deferred:live_receipt_revalidation_required"
    identities = tuple(x.edge_identity for x in attempts)
    if len(set(identities)) != len(identities):
        return "deferred:duplicate_live_edge_attempt"
    if set(identities) != {x.edge.identity for x in cached}:
        return "deferred:live_attempt_set_has_missing_or_foreign_edge"
    request_hashes: list[str] = []
    receipt_hashes: list[str] = []
    for obligation in cached:
        matches = [a for a in attempts if a.edge_identity == obligation.edge.identity]
        if len(matches) != 1:
            return "deferred:live_attempt_edge_ambiguous"
        attempt = matches[0]
        if not valid_live_attempt(obligation.edge, obligation, attempt, admitted):
            return "deferred:live_receipt_revalidation_failed"
        if attempt.provider_status != "completed" or attempt.exit_code != 0:
            return "deferred:live_provider_attempt_not_successful"
        fresh = Cached(obligation.edge, obligation.obligation_hash, CONTEXT["capability"],
                       "validated", "completed", attempt)
        if (obligation.receipt_state, obligation.provider_state, obligation.capability,
                obligation.attempt) != (fresh.receipt_state, fresh.provider_state,
                fresh.capability, fresh.attempt):
            return "deferred:cached_state_differs_from_live_revalidation"
        request_hashes.append(attempt.request_hash)
        receipt_hashes.append(attempt.receipt_hash)
    if len(set(request_hashes)) != len(request_hashes):
        return "deferred:live_request_reused_across_edges"
    if len(set(receipt_hashes)) != len(receipt_hashes):
        return "deferred:live_receipt_reused_across_edges"
    return "live_receipts_revalidated_unwired"


def cached_only_pair() -> tuple[Cached, ...]:
    return tuple(Cached(e, canonical_hash({"edge": e.identity, "revision": "V1"}),
                        CONTEXT["capability"]) for e in EDGES)


def valid_pair() -> tuple[tuple[Cached, ...], tuple[Attempt, ...], set[int]]:
    attempts = tuple(make_attempt(e) for e in EDGES)
    cached = tuple(Cached(e, a.obligation_hash, CONTEXT["capability"],
                          "validated", "completed", a) for e, a in zip(EDGES, attempts))
    return cached, attempts, {id(a) for a in attempts}


class IndependentV2RevalidationChecks(unittest.TestCase):
    def test_01_v2_source_and_owner_suite_are_separately_pinned(self) -> None:
        self.assertTrue(V2.is_file() and OWNER_TEST.is_file())
        self.assertIn("V1_FROZEN_SHA256", OWNER_TEST.read_text(encoding="utf-8"))

    def test_02_v2_is_not_in_shared_entries(self) -> None:
        self.assertNotIn("PhysicalEdgeObligationV2", RUNTIME_ENTRY.read_text(encoding="utf-8"))
        self.assertNotIn("PhysicalEdgeObligationV2", PACKAGE_ENTRY.read_text(encoding="utf-8"))

    def test_03_v2_requires_live_validator_calls(self) -> None:
        text = V2.read_text(encoding="utf-8")
        for token in ("validate_trusted_provider_dispatch_request", "validate_trusted_provider_execution_receipt",
                      "bind_trusted_provider_receipt_v1"):
            self.assertIn(token, text)

    def test_04_v2_compares_fresh_binding_to_cached_snapshot(self) -> None:
        text = V2.read_text(encoding="utf-8")
        self.assertIn("cached_provider_state_differs_from_live", text)
        self.assertIn("cached_capability_requirement_differs_from_live", text)

    def test_05_v2_requires_one_attempt_per_obligation(self) -> None:
        self.assertIn("length(live_attempts) == length(obligations)", V2.read_text(encoding="utf-8"))

    def test_06_v2_checks_unique_and_exact_edge_attempt_set(self) -> None:
        text = V2.read_text(encoding="utf-8")
        self.assertIn("length(unique(attempt_hashes)) == length(attempt_hashes)", text)
        self.assertIn("Set(attempt_hashes) == Set(identity_hashes)", text)

    def test_07_v2_rejects_reused_request_and_receipt(self) -> None:
        text = V2.read_text(encoding="utf-8")
        self.assertIn("live_request_reused_across_edges", text)
        self.assertIn("live_receipt_reused_across_edges", text)

    def test_08_v1_readiness_uses_cached_success_fields(self) -> None:
        text = V1.read_text(encoding="utf-8")
        self.assertIn("x.provider.receipt_state !== :validated", text)
        self.assertIn("x.provider.provider_state !== :completed", text)
        self.assertIn("x.requirement.match_state !== :matched", text)
        self.assertIn("status=:contract_ready_unwired", text)

    def test_09_v2_fake_julia_test_contrasts_v1_and_v2(self) -> None:
        text = JULIA_FIXTURE.read_text(encoding="utf-8")
        self.assertIn("old_assessment.status === :contract_ready_unwired", text)
        self.assertIn("fresh_assessment.status === :deferred", text)
        self.assertIn("fabricated_cached_successes_v2", text)

    def test_10_two_g1_identity_edges_remain_distinct(self) -> None:
        self.assertEqual(EDGES[0].operator, EDGES[1].operator)
        self.assertNotEqual(EDGES[0].identity, EDGES[1].identity)
        self.assertNotEqual(EDGES[0].edge_position, EDGES[1].edge_position)

    def test_11_strong_g1_fixture_still_asserts_two_identity_edges(self) -> None:
        text = STRONG_G1.read_text(encoding="utf-8")
        self.assertIn("@test length(edges) == 2", text)
        self.assertIn("required_physical_capability:IDENTITY@v1", text)

    def test_12_v1_forged_cached_pair_reaches_old_readiness_in_model(self) -> None:
        self.assertEqual(assess_v1_cached(cached_only_pair(), EDGES), "contract_ready_unwired")

    def test_13_v2_forged_cached_pair_without_live_receipts_defers(self) -> None:
        self.assertEqual(assess_v2(cached_only_pair(), (), admitted=set()),
                         "deferred:live_receipt_revalidation_required")

    def test_14_exact_fake_live_pair_is_revalidated_but_unwired(self) -> None:
        cached, attempts, admitted = valid_pair()
        self.assertEqual(assess_v2(cached, attempts, admitted=admitted),
                         "live_receipts_revalidated_unwired")

    def test_15_foreign_edge_attempt_defers(self) -> None:
        cached, attempts, admitted = valid_pair()
        wrong = dataclasses.replace(attempts[0], edge_identity="0" * 64)
        self.assertNotEqual(assess_v2(cached, (wrong, attempts[1]), admitted={id(wrong), id(attempts[1])}),
                            "live_receipts_revalidated_unwired")

    def test_16_foreign_candidate_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        wrong = make_attempt(EDGES[0], changes={"candidate": "0" * 64})
        self.assertEqual(assess_v2(cached, (wrong, attempts[1]), admitted={id(wrong), id(attempts[1])}),
                         "deferred:live_receipt_revalidation_failed")

    def test_17_stale_context_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        stale = make_attempt(EDGES[0], changes={"context": "0" * 64})
        self.assertEqual(assess_v2(cached, (stale, attempts[1]), admitted={id(stale), id(attempts[1])}),
                         "deferred:live_receipt_revalidation_failed")

    def test_18_foreign_registry_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        foreign = make_attempt(EDGES[0], changes={"registry": "0" * 64})
        self.assertEqual(assess_v2(cached, (foreign, attempts[1]), admitted={id(foreign), id(attempts[1])}),
                         "deferred:live_receipt_revalidation_failed")

    def test_19_foreign_capability_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        foreign = make_attempt(EDGES[0], changes={"capability": "0" * 64})
        self.assertEqual(assess_v2(cached, (foreign, attempts[1]), admitted={id(foreign), id(attempts[1])}),
                         "deferred:live_receipt_revalidation_failed")

    def test_20_malformed_receipt_hash_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        malformed = make_attempt(EDGES[0], bad_receipt_hash="not-a-digest")
        self.assertEqual(assess_v2(cached, (malformed, attempts[1]), admitted={id(malformed), id(attempts[1])}),
                         "deferred:live_receipt_revalidation_failed")

    def test_21_duplicate_edge_attempt_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        self.assertEqual(assess_v2(cached, (attempts[0], attempts[0]),
                                   admitted={id(attempts[0])}),
                         "deferred:duplicate_live_edge_attempt")

    def test_22_duplicate_receipt_across_distinct_edges_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        reused = dataclasses.replace(attempts[1], receipt_hash=attempts[0].receipt_hash)
        # The malformed second receipt fails revalidation before the reuse gate.
        self.assertNotEqual(assess_v2(cached, (attempts[0], reused),
                                      admitted={id(attempts[0]), id(reused)}),
                            "live_receipts_revalidated_unwired")

    def test_23_provider_failure_defers(self) -> None:
        cached, attempts, _ = valid_pair()
        failed = make_attempt(EDGES[0], provider_status="failed", exit_code=9)
        self.assertEqual(assess_v2(cached, (failed, attempts[1]), admitted={id(failed), id(attempts[1])}),
                         "deferred:live_provider_attempt_not_successful")

    def test_24_reused_request_hash_defers(self) -> None:
        self.assertIn("live_request_reused_across_edges", V2.read_text(encoding="utf-8"))
        cached, attempts, _ = valid_pair()
        reused = dataclasses.replace(attempts[1], request_hash=attempts[0].request_hash)
        self.assertNotEqual(assess_v2(cached, (attempts[0], reused),
                                      admitted={id(attempts[0]), id(reused)}),
                            "live_receipts_revalidated_unwired")

    def test_25_cached_state_drift_defers(self) -> None:
        _, attempts, admitted = valid_pair()
        stale_cache = tuple(Cached(e, canonical_hash({"edge": e.identity, "revision": "V1"}),
                                   CONTEXT["capability"], "rejected", "failed", a)
                            for e, a in zip(EDGES, attempts))
        self.assertEqual(assess_v2(stale_cache, attempts, admitted=admitted),
                         "deferred:cached_state_differs_from_live_revalidation")

    def test_26_unresolved_string_gap_defers(self) -> None:
        cached, attempts, admitted = valid_pair()
        self.assertEqual(assess_v2(cached, attempts, admitted=admitted,
                                   gaps=("required_physical_capability:IDENTITY@v1",)),
                         "deferred:compiler_gap_has_no_edge_bound_resolution")

    def test_27_full_model_result_has_no_activation_or_credit(self) -> None:
        text = V2.read_text(encoding="utf-8")
        for token in ("activated=false", "physical_validation=false", "engineering_validation=false",
                      "candidate_discovery_credit=0", "credible_device_count=0"):
            self.assertIn(token, text)
        cached, attempts, admitted = valid_pair()
        self.assertEqual(assess_v2(cached, attempts, admitted=admitted),
                         "live_receipts_revalidated_unwired")


if __name__ == "__main__":
    unittest.main(verbosity=2)
