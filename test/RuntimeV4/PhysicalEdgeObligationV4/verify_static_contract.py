"""Fail-closed live-receipt oracle and source checks for UP5 V3.

The callback stands for request/receipt content revalidation only. The current
repository API has no executor-issued receipt proof, so even callback success
must remain deferred. This model makes no provider, physical, engineering,
Search, or candidate-discovery claim.
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
import pathlib
import re
import unittest
from collections.abc import Callable, Iterable


ROOT = pathlib.Path(__file__).resolve().parents[3]
MODULE = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV3.jl"
V1_MODULE = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1.jl"
TRUSTED_API = ROOT / "src/RuntimeV4/TrustedProviderRegistryV4.jl"
RUNTIME_ENTRY = ROOT / "src/RuntimeV4/FusionRuntimeV4.jl"
PACKAGE_ENTRY = ROOT / "src/FusionConceptAI.jl"
JULIA_TEST = pathlib.Path(__file__).with_name("physical_edge_obligation_v4_tests.jl")
V1_FROZEN_SHA256 = "9663dcb3ef6b64eda0ef7e09e1ec0785adfc1e6512f9c84bdd633288e6abcb80"


def canonical_hash(value: object) -> str:
    payload = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


@dataclasses.dataclass(frozen=True)
class Edge:
    layer: str
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
    shared = dict(layer="g1_mechanism", graph_hash="1" * 64,
                  program_hash="2" * 64, root_position=1,
                  operator_id="IDENTITY", operator_version="v1")
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
    item = Attempt(edge.identity_hash, candidate, context, scenario, registry,
                   capability, request_hash, "0" * 64, "5" * 64, "6" * 64,
                   status, exit_code)
    return dataclasses.replace(item, receipt_hash=canonical_hash(item.receipt_body()))


def bind_model(obligation: BoundObligation, attempt: Attempt | None, *,
               expected_candidate: str, expected_context: str,
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


class TestOnlyTrustedValidator:
    """Explicit live-proof stand-in; only exact captured objects are admitted."""

    def __init__(self, attempts: Iterable[Attempt]) -> None:
        self._admitted = {id(attempt): attempt for attempt in attempts}

    def __call__(self, edge: Edge, attempt: Attempt, *, candidate: str,
                 context: str, scenario: str, registry: str,
                 capability: str) -> bool:
        if self._admitted.get(id(attempt)) is not attempt:
            return False
        if attempt.edge_identity_hash != edge.identity_hash:
            return False
        if (attempt.candidate_hash, attempt.context_hash, attempt.scenario_hash,
                attempt.registry_hash, attempt.capability_hash) != (
                candidate, context, scenario, registry, capability):
            return False
        expected_request = canonical_hash({
            "candidate": candidate, "context": context, "scenario": scenario,
            "registry": registry, "capability": capability,
            "edge_identity": edge.identity_hash,
        })
        return (attempt.request_hash == expected_request and
                attempt.receipt_hash == canonical_hash(attempt.receipt_body()))


def assess_model(obligations: tuple[BoundObligation, ...],
                 expected_edges: tuple[Edge, ...], *,
                 expected_candidate: str = "a" * 64,
                 expected_context: str = "b" * 64,
                 expected_scenario: str = "c" * 64,
                 expected_registry: str = "d" * 64,
                 expected_capability: str = "e" * 64,
                 trusted_revalidator: Callable[..., bool] | None = None,
                 unresolved_nonterminals: tuple[str, ...] = ()) -> dict[str, object]:
    actual = tuple(item.edge.identity_hash for item in obligations)
    expected = tuple(item.identity_hash for item in expected_edges)
    if len(actual) != len(set(actual)) or actual != expected:
        return {"status": "deferred", "reason": "typed_obligation_set_invalid", "activated": False}
    if unresolved_nonterminals:
        return {"status": "deferred", "reason": "compiler_gap_has_no_edge_bound_resolution", "activated": False}
    if trusted_revalidator is None:
        return {"status": "deferred", "reason": "live_receipt_revalidation_required", "activated": False}

    fresh: list[BoundObligation] = []
    for cached in obligations:
        attempt = cached.attempt
        if attempt is None or not trusted_revalidator(
                cached.edge, attempt, candidate=expected_candidate,
                context=expected_context, scenario=expected_scenario,
                registry=expected_registry, capability=expected_capability):
            return {"status": "deferred", "reason": "live_attempt_revalidation_failed", "activated": False}
        current = bind_model(BoundObligation(cached.edge, expected_candidate,
            expected_context, expected_scenario), attempt,
            expected_candidate=expected_candidate, expected_context=expected_context,
            expected_scenario=expected_scenario, expected_registry=expected_registry,
            expected_capability=expected_capability)
        if current.receipt_state != "validated" or current.provider_state != "completed":
            return {"status": "deferred", "reason": "live_provider_attempt_not_complete", "activated": False}
        if (cached.receipt_state, cached.provider_state, cached.capability_hash,
                cached.attempt) != (current.receipt_state, current.provider_state,
                current.capability_hash, current.attempt):
            return {"status": "deferred", "reason": "cached_state_differs_from_live_revalidation", "activated": False}
        fresh.append(current)

    request_hashes = tuple(item.attempt.request_hash for item in fresh if item.attempt)
    receipt_hashes = tuple(item.attempt.receipt_hash for item in fresh if item.attempt)
    if len(request_hashes) != len(set(request_hashes)) or len(receipt_hashes) != len(set(receipt_hashes)):
        return {"status": "deferred", "reason": "live_receipt_reused_across_edges", "activated": False}
    return {
        "status": "deferred",
        "reason": "executor_issuance_provenance_unavailable",
        "activated": False,
        "claim_ceiling": "none",
        "physical_validation": False,
        "engineering_validation": False,
        "candidate_discovery_credit": 0,
        "credible_device_count": 0,
    }


class PhysicalEdgeLiveReceiptTests(unittest.TestCase):
    def setUp(self) -> None:
        self.edges = make_two_identity_edges()
        self.candidate = "a" * 64
        self.context = "b" * 64
        self.scenario = "c" * 64
        self.registry = "d" * 64
        self.capability = "e" * 64
        self.pending = tuple(BoundObligation(edge, self.candidate,
            self.context, self.scenario) for edge in self.edges)

    def bind_all(self, attempts: tuple[Attempt, ...]) -> tuple[BoundObligation, ...]:
        return tuple(bind_model(item, attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
            for item, attempt in zip(self.pending, attempts, strict=True))

    def test_cached_completed_flags_alone_defer(self) -> None:
        attempts = tuple(sample_attempt(edge) for edge in self.edges)
        cached = tuple(dataclasses.replace(item, receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=attempt) for item, attempt in zip(self.pending, attempts, strict=True))
        self.assertEqual(assess_model(cached, self.edges)["reason"],
                         "live_receipt_revalidation_required")

    def test_hash_consistent_fabricated_foreign_attempt_is_rejected(self) -> None:
        foreign = sample_attempt(self.edges[0], candidate="f" * 64)
        forged = dataclasses.replace(self.pending[0], receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=foreign)
        self.assertEqual(assess_model((forged, self.pending[1]), self.edges)["reason"],
                         "live_receipt_revalidation_required")
        result = assess_model((forged, self.pending[1]), self.edges,
            trusted_revalidator=TestOnlyTrustedValidator((foreign,)))
        self.assertEqual(result["reason"], "live_attempt_revalidation_failed")

    def test_foreign_candidate_receipt_fails_fresh_binding(self) -> None:
        foreign = sample_attempt(self.edges[0], candidate="f" * 64)
        bound = bind_model(self.pending[0], foreign,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "stale"))

    def test_exact_objects_pass_hash_revalidation_but_still_defer_without_issuer_proof(self) -> None:
        attempts = tuple(sample_attempt(edge) for edge in self.edges)
        cached = self.bind_all(attempts)
        validator = TestOnlyTrustedValidator(attempts)
        result = assess_model(cached, self.edges, trusted_revalidator=validator)
        self.assertEqual(result["status"], "deferred")
        self.assertEqual(result["reason"], "executor_issuance_provenance_unavailable")
        self.assertFalse(result["activated"])
        self.assertEqual(result["candidate_discovery_credit"], 0)
        self.assertFalse(result["physical_validation"])
        self.assertFalse(result["engineering_validation"])

    def test_fabricated_copy_of_admitted_object_is_not_live_proof(self) -> None:
        attempt = sample_attempt(self.edges[0])
        copied = dataclasses.replace(attempt)
        cached = dataclasses.replace(self.pending[0], receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=copied)
        validator = TestOnlyTrustedValidator((attempt,))
        result = assess_model((cached, self.pending[1]), self.edges,
            trusted_revalidator=validator)
        self.assertEqual(result["reason"], "live_attempt_revalidation_failed")

    def test_cached_state_drift_from_live_binder_defers(self) -> None:
        attempts = tuple(sample_attempt(edge) for edge in self.edges)
        cached = self.bind_all(attempts)
        tampered = (dataclasses.replace(cached[0], provider_state="failed"), cached[1])
        result = assess_model(tampered, self.edges,
            trusted_revalidator=TestOnlyTrustedValidator(attempts))
        self.assertEqual(result["reason"], "cached_state_differs_from_live_revalidation")

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

    def test_foreign_scenario_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], scenario="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "stale"))

    def test_foreign_capability_receipt_is_rejected(self) -> None:
        attempt = sample_attempt(self.edges[0], capability="f" * 64)
        bound = bind_model(self.pending[0], attempt,
            expected_candidate=self.candidate, expected_context=self.context,
            expected_scenario=self.scenario, expected_registry=self.registry,
            expected_capability=self.capability)
        self.assertEqual((bound.receipt_state, bound.provider_state), ("rejected", "invalid"))

    def test_duplicate_identity_edges_still_need_distinct_attempts(self) -> None:
        one = sample_attempt(self.edges[0])
        reused = (self.pending[0], dataclasses.replace(self.pending[1],
            receipt_state="validated", provider_state="completed",
            capability_hash=self.capability, attempt=one))
        result = assess_model(reused, self.edges,
            trusted_revalidator=TestOnlyTrustedValidator((one,)))
        self.assertEqual(result["reason"], "live_attempt_revalidation_failed")

    def test_tampered_receipt_hash_defers(self) -> None:
        attempt = sample_attempt(self.edges[0])
        tampered = dataclasses.replace(attempt, output_hash="f" * 64)
        cached = dataclasses.replace(self.pending[0], receipt_state="validated",
            provider_state="completed", capability_hash=self.capability,
            attempt=tampered)
        result = assess_model((cached, self.pending[1]), self.edges,
            trusted_revalidator=TestOnlyTrustedValidator((tampered,)))
        self.assertEqual(result["reason"], "live_attempt_revalidation_failed")

    def test_provider_failure_never_returns_revalidated_status(self) -> None:
        attempts = tuple(sample_attempt(edge, status="executor_error", exit_code=1)
                         for edge in self.edges)
        cached = self.bind_all(attempts)
        result = assess_model(cached, self.edges,
            trusted_revalidator=TestOnlyTrustedValidator(attempts))
        self.assertEqual(result["reason"], "live_provider_attempt_not_complete")

    def test_string_only_compiler_gap_still_defers(self) -> None:
        attempts = tuple(sample_attempt(edge) for edge in self.edges)
        cached = self.bind_all(attempts)
        result = assess_model(cached, self.edges,
            trusted_revalidator=TestOnlyTrustedValidator(attempts),
            unresolved_nonterminals=("required_physical_capability:IDENTITY@v1",))
        self.assertEqual(result["reason"], "compiler_gap_has_no_edge_bound_resolution")

    def test_missing_attempts_defer_even_when_cached_states_claim_success(self) -> None:
        cached = tuple(dataclasses.replace(item, receipt_state="validated",
            provider_state="completed", capability_hash=self.capability) for item in self.pending)
        validator = TestOnlyTrustedValidator(())
        result = assess_model(cached, self.edges, trusted_revalidator=validator)
        self.assertEqual(result["reason"], "live_attempt_revalidation_failed")


class JuliaSourceBoundaryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = MODULE.read_text(encoding="utf-8")

    def test_frozen_v1_bytes_are_unchanged(self) -> None:
        self.assertEqual(hashlib.sha256(V1_MODULE.read_bytes()).hexdigest(), V1_FROZEN_SHA256)

    def test_v3_is_not_wired_into_shared_entries(self) -> None:
        self.assertNotIn("PhysicalEdgeObligationV3.jl", RUNTIME_ENTRY.read_text(encoding="utf-8"))
        self.assertNotIn("PhysicalEdgeObligationV3", PACKAGE_ENTRY.read_text(encoding="utf-8"))

    def test_assessment_receives_live_registry_context_and_attempts(self) -> None:
        signature = self.source.split("function assess_candidate_obligations_v3", 1)[1]
        self.assertIn("context::ForwardChainContextV4", signature)
        self.assertIn("registry::TrustedProviderRegistryV4", signature)
        self.assertIn("live_attempts::Tuple{Vararg{PhysicalEdgeLiveAttemptV3}}", signature)

    def test_live_request_and_receipt_are_revalidated_at_assessment(self) -> None:
        self.assertIn("validate_trusted_provider_dispatch_request(attempt.request, registry,", self.source)
        self.assertIn("validate_trusted_provider_execution_receipt(attempt.receipt,", self.source)
        self.assertIn("PEO1.bind_trusted_provider_receipt_v1", self.source)
        self.assertIn("canonical_hash(freshly_bound.provider) ==", self.source)

    def test_cached_state_or_constructor_token_is_not_the_authority(self) -> None:
        self.assertIn("trusts_cached_provider_state=false", self.source)
        self.assertIn("live_receipt_revalidation_required", self.source)
        self.assertIn("live_attempt_obligation_snapshot_mismatch", self.source)
        self.assertIn("cached_provider_state_differs_from_live", self.source)

    def test_edge_candidate_context_scenario_and_capability_are_rebound(self) -> None:
        for token in ("input.edge_identity_hash == obligation.identity.identity_hash",
                      "input.candidate_hash == context.candidate_hash",
                      "input.genome_bundle_hash == context.candidate.canonical_hashes.genome_bundle_hash",
                      "input.context_hash == context.context_hash",
                      "input.scenario_hash == context.scenario_hash",
                      "input.capability_hash == canonical_hash(attempt.capability)"):
            self.assertIn(token, self.source)

    def test_attempt_and_receipt_reuse_or_foreign_identity_defer(self) -> None:
        for token in ("duplicate_live_edge_attempt", "live_attempt_set_has_missing_or_foreign_edge",
                      "live_request_reused_across_edges", "live_receipt_reused_across_edges"):
            self.assertIn(token, self.source)

    def test_no_dispatch_queue_mutation_or_credit_surface(self) -> None:
        self.assertNotRegex(self.source, r"\bexecute_trusted_provider\s*\(")
        self.assertNotRegex(self.source, r"\b(?:enqueue_candidate!|next_compilable!|mark_failed!)\s*\(")
        self.assertIn("physical_validation_credit=0", self.source)
        self.assertIn("engineering_validation_credit=0", self.source)
        self.assertIn("candidate_discovery_credit=0", self.source)

    def test_julia_negative_reproduces_cached_v1_false_readiness(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        self.assertIn("old_assessment.status === :contract_ready_unwired", test)
        self.assertIn("fresh_assessment.status === :deferred", test)
        self.assertIn("(:live_receipt_revalidation_required,)", test)
        self.assertIn("PEO1_2._peo_provider_state", test)

    def test_assessment_never_promotes_hash_revalidation_to_issuer_proof(self) -> None:
        self.assertIn("receipt_validator_is_issuer_attestation=false", self.source)
        self.assertIn("executor_issuance_provenance_available=false", self.source)
        self.assertIn("_deferred(:executor_issuance_provenance_unavailable)", self.source)
        self.assertNotIn("status=:live_receipts_revalidated_unwired", self.source)

    def test_current_receipt_validator_has_no_issuer_binding(self) -> None:
        api = TRUSTED_API.read_text(encoding="utf-8")
        start = api.index("function validate_trusted_provider_execution_receipt(")
        body = api[start:api.index("\nend", start) + len("\nend")]
        self.assertIn("_tpr_receipt_body", body)
        self.assertIn("receipt.receipt_hash == expected", body)
        self.assertNotIn("execute_trusted_provider(", body)
        self.assertNotIn("issuer_proof", body)
        self.assertNotIn("execution_identity", body)

    def test_julia_fixture_constructs_self_consistent_unissued_receipt(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        for token in ("build_trusted_provider_dispatch_request(",
                      "TrustedProviderExecutionReceiptV4(R3._TPR_TOKEN",
                      "R3._tpr_receipt_body(",
                      "@test R3.validate_trusted_provider_execution_receipt(",
                      ":caller_forged_without_dispatch"):
            self.assertIn(token, test)

    def test_julia_forged_v1_state_fixture_uses_nonempty_capability_states(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        self.assertIn('identity.operator_version), ("u",),', test)




COMPAT_MODULE = ROOT / "src/RuntimeV4/PhysicalEdgeObligationV1Compat.jl"
V3_TEST = ROOT / "test/RuntimeV4/PhysicalEdgeObligationV3/physical_edge_obligation_v3_tests.jl"
V3_FROZEN_SHA256 = "674b6897096f16f54801922e0d058fa08c16304f4c04fb12330bfe174c1fef6c"


class NamespaceCompatBoundaryTests(unittest.TestCase):
    def test_frozen_v1_has_the_reported_module_struct_collision(self) -> None:
        source = V1_MODULE.read_text(encoding="utf-8")
        self.assertRegex(source, r"(?m)^module PhysicalEdgeObligationV1$")
        self.assertRegex(source, r"(?m)^struct PhysicalEdgeObligationV1$")
        self.assertEqual(len(re.findall(r"(?m)^module PhysicalEdgeObligationV1$", source)), 1)

    def test_compat_source_changes_only_outer_module_name_and_end_comment(self) -> None:
        original = V1_MODULE.read_bytes()
        compat = COMPAT_MODULE.read_bytes()
        expected = original.replace(b"module PhysicalEdgeObligationV1",
                                    b"module PhysicalEdgeObligationV1Compat", 1)
        expected = expected.replace(b"end # module PhysicalEdgeObligationV1",
                                    b"end # module PhysicalEdgeObligationV1Compat", 1)
        self.assertEqual(compat, expected)
        self.assertRegex(compat.decode("utf-8"), r"(?m)^module PhysicalEdgeObligationV1Compat$")
        self.assertRegex(compat.decode("utf-8"), r"(?m)^struct PhysicalEdgeObligationV1$")
        self.assertNotRegex(compat.decode("utf-8"), r"(?m)^struct PhysicalEdgeObligationV1Compat$")

    def test_v4_loader_binds_alias_between_compat_and_frozen_v3_loads(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        compat_load = test.index("Base.include(parent, compat_path)")
        alias_bind = test.index("Core.eval(parent, :(const PhysicalEdgeObligationV1 = PhysicalEdgeObligationV1Compat))")
        v3_load = test.index('"PhysicalEdgeObligationV3.jl"')
        self.assertLess(compat_load, alias_bind)
        self.assertLess(alias_bind, v3_load)
        self.assertIn("const PEO1_2 = _load_v1_compat_with_parent_alias!(R2, V1_COMPAT_PATH)", test)
        self.assertIn("const PEO3 = R2.PhysicalEdgeObligationV3", test)
        self.assertIn("@test PEO3.PEO1 === PEO1_2", test)

    def test_v4_loader_rejects_duplicate_and_foreign_parent_aliases(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        self.assertIn("parent namespace already binds PhysicalEdgeObligationV1", test)
        self.assertIn("parent namespace already loaded PhysicalEdgeObligationV1Compat", test)
        self.assertIn("@test_throws ArgumentError _load_v1_compat_with_parent_alias!(\n        R2, V1_COMPAT_PATH)", test)
        self.assertIn("@test_throws ArgumentError _load_v1_compat_with_parent_alias!(\n        PhysicalEdgeObligationV4ForeignAliasFixture, V1_COMPAT_PATH)", test)
        self.assertIn(":foreign_alias", test)

    def test_julia_fixture_contains_disposable_module_struct_collision_negative(self) -> None:
        test = JULIA_TEST.read_text(encoding="utf-8")
        self.assertIn("probe = Module(gensym(:UP5PhysicalEdgeCollisionProbe))", test)
        self.assertIn("module PhysicalEdgeObligationV1\n                struct PhysicalEdgeObligationV1 end", test)
        self.assertIn('occursin("invalid redefinition of constant", message)', test)
        self.assertIn('occursin("PhysicalEdgeObligationV1.PhysicalEdgeObligationV1", message)', test)

    def test_v1_v2_v3_sources_and_v3_test_remain_pinned(self) -> None:
        anchors = {
            V1_MODULE: V1_FROZEN_SHA256,
            ROOT / "src/RuntimeV4/PhysicalEdgeObligationV2.jl": "9ae869282fe4d2f15918f225b2976370e092396ab5222ef20ed184199a407ba2",
            ROOT / "src/RuntimeV4/PhysicalEdgeObligationV3.jl": "5f2a73c5c38b06aeae4273d6945da362f74f5bb12ddbcb972fe2efb75422850b",
            V3_TEST: V3_FROZEN_SHA256,
        }
        for path, expected in anchors.items():
            with self.subTest(path=path):
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), expected)

    def test_no_shared_entry_includes_the_compat_module_or_v4_test(self) -> None:
        for path in (RUNTIME_ENTRY, PACKAGE_ENTRY):
            source = path.read_text(encoding="utf-8")
            self.assertNotIn("PhysicalEdgeObligationV1Compat", source)
            self.assertNotIn("PhysicalEdgeObligationV4", source)
if __name__ == "__main__":
    unittest.main(verbosity=2)
