"""Python-only checks for the isolated V4 strong-payload fixture repair.

This verifier does not execute Julia, FreeGS, or any provider. The historical
V3 failure is pinned as a fixture-construction negative control; the V4 Julia
suite must be run separately under an explicit bounded grant.
"""
from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
FIXTURE = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV4/search_physical_consumer_fixture_v4.jl"
JULIA_TEST = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV4/search_physical_consumer_v4_tests.jl"
MECHANISM_CONTRACT = ROOT / "src/Genomes/MechanismGenomePayload.jl"
OLD_FAILURE_ROOT = ROOT / "docs/implementation/UP5-01/archive/root_search_physical_consumer_v3_focused_grant_20260924/actual_run_v1"
STATIC_RECEIPT_ROOT = ROOT / "docs/implementation/UP5-01/archive/search_physical_consumer_v3_fixture_failure_observe_search_chain_r1_20260924"

PINNED = {
    "src/Canonical/CanonicalJSON.jl": "612edaeb822c1beeff44f7134497426fd0c8ff1eea9c16a651421e2c63f8ab93",
    "src/FusionConceptAI.jl": "7fba6b0f632ce28cd2dd6e250561998988e241963b0ab44a3ef1677fdb270066",
    "src/Genomes/MechanismGenomePayload.jl": "fb8cb4966726328a4b9226b730586eb795e6603c39218bde142a247b6b8fab8f",
    "src/RuntimeV4/FusionRuntimeV4.jl": "de87c548c716a041cb7d600cca4bb3d6712dc4222d3d8c526014d598075e8767",
    "src/RuntimeV4/ForwardChainContext.jl": "cabb8ad76db0186681df01fdf9d30d27631d27550dd756c77b8e0255409f977e",
    "src/RuntimeV4/FreeGSAxisymmetricExecution.jl": "0aafede1bba391c3422e4ff5f3dfb65101ece1850131f3acfef72941d197dfc5",
    "src/RuntimeV4/TrustedProviderRegistryV4.jl": "2b3d54fdfb076a91da0739f4e5d4cff800165aef26e3c6596895e4a241b06339",
    "src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl": "d90d691decbae92eb6939f7afe8e3739f3303a41cf788fec48552b2a792d988b",
    "src/RuntimeV4/SearchPhysicalConsumerV1.jl": "7e3e573cd8da4af80c4504b5f47654041f5de37ebb339a1c414e2dc374cba3bb",
    "src/RuntimeV4/SearchPhysicalConsumerV3.jl": "9ec75245de59aa18e5b9321a352b95dac5927a2d83f9d9a515be2cf18956f27f",
    "src/RuntimeV4/Search.jl": "3068b8b65a53745f1f1ac5cb4eee50133a2383c94ed48a60a4a5547aa75d3a83",
    "src/RuntimeV4/Compiler.jl": "7a550e2b9ac27693f7e7008f3562ef6d5f52795997bc89c676440cb2e4bab4aa",
    "src/RuntimeV4/RuntimePipeline.jl": "8c40d60a64560043546baabcb9623e8e261303d1278719fb2cd8033621a738e7",
    "examples/runtime_v4_declared_fixture.jl": "b8c3140f65574c53163193c310c114b76da7fac868daa13af0381a322a652b6e",
    "test/RuntimeV4/SearchPhysicalConsumerV1/search_physical_consumer_v1_tests.jl": "fac3bd186c4e30ae16c9c10416d9352b12fd806669db30fac9ac8ac22341edca",
    "test/RuntimeV4/SearchPhysicalConsumerV3/search_physical_consumer_v3_tests.jl": "015264be636274e8092a8a15df44567b8a76f19d25bb9e1377ed77800be77c57",
    "test/RuntimeV4/SearchPhysicalConsumerV3/verify_static_contract.py": "9fcd0a95ac67c9d333067ece4131af8e32d9abcdc93ec941c2045cb151284c49",
    "test/RuntimeV4/SearchPhysicalConsumerV4/search_physical_consumer_fixture_v4.jl": "4765ad14cd0f32727bb1c4f06f882083536a6d3d69dabed75d33cc8a171ebc58",
    "test/RuntimeV4/SearchPhysicalConsumerV4/search_physical_consumer_v4_tests.jl": "c06bc77f1cecdf9d08910e42601989ab9da15ad339ea90f492261d332b8593ad",
}

OLD_FINAL_SHA256 = "7ec1221ab0d45440dbd01fab96ada09899a9ba1373c28e7496ce124bda0ac9e8"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SearchPhysicalConsumerV4FixtureStaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = FIXTURE.read_text(encoding="utf-8-sig")
        cls.test = JULIA_TEST.read_text(encoding="utf-8-sig")
        cls.payload_contract = MECHANISM_CONTRACT.read_text(encoding="utf-8-sig")

    def test_frozen_inputs_and_new_fixture_test_hashes_match(self) -> None:
        for relative, expected in PINNED.items():
            with self.subTest(path=relative):
                self.assertEqual(digest(ROOT / relative), expected)

    def test_fixture_uses_complete_validated_base_payload(self) -> None:
        self.assertIn("g1_payload = _fixture_mechanism_payload()", self.fixture)
        self.assertIn("MechanismGenomeV4(17, _fixture_refs[1], g1_payload)", self.fixture)
        self.assertNotIn("base_payload.operator_graph.nodes, ()", self.fixture)
        self.assertNotIn("g1_graph = TypedOperatorHypergraphV1", self.fixture)

    def test_fixture_documents_strong_edge_contract(self) -> None:
        self.assertIn("strong mechanism payload requires atomic graph edges", self.payload_contract)
        self.assertIn("isempty(getfield(graph, :hyperedges))", self.payload_contract)
        self.assertIn("all(typeof(edge) === AtomicMIMOHyperedgeV1", self.payload_contract)
        self.assertIn("AtomicMIMOHyperedgeV1", self.fixture)
        self.assertIn("g1_payload = _fixture_mechanism_payload()", self.fixture)

    def test_old_empty_graph_case_is_only_a_rejection_negative_control(self) -> None:
        self.assertIn("invalid_graph = TypedOperatorHypergraphV1(getfield(graph, :nodes), ()", self.test)
        self.assertIn("@test_throws ArgumentError MechanismGenomePayloadV1(", self.test)
        self.assertIn("fixture.g1_payload.states, (), invalid_graph", self.test)

    def test_v4_tests_do_not_include_the_failing_v1_test_file(self) -> None:
        self.assertNotIn("search_physical_consumer_v1_tests.jl", self.test)
        self.assertIn("search_physical_consumer_fixture_v4.jl", JULIA_TEST.read_text(encoding="utf-8-sig"))

    def test_v4_test_preserves_v3_queue_and_tamper_checks(self) -> None:
        for required in (
            "_spc3_claim_dispatch!", "queue_owner_busy", "queue_changed_before_dispatch",
            "already_dispatched", "queue_owner_task_mismatch", "synthetic tamper negative control",
            ":preflight_exception", "calls[] == 0",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.test)

    def test_no_provider_callback_or_solver_is_executed_by_the_test(self) -> None:
        self.assertNotIn("execute_trusted_provider(", self.test)
        self.assertNotIn("freegs_solve", self.test.lower())
        self.assertNotIn("run(`", self.test)
        self.assertIn("executor=fake_provider", self.test)
        self.assertIn("@test calls[] == 0", self.test)

    def test_prepared_result_keeps_zero_credit_and_no_validation(self) -> None:
        for required in (
            "record.claim_ceiling === none",
            "!record.physical_validation && !record.engineering_validation",
            "record.candidate_discovery_credit == 0 && record.credible_device_count == 0",
        ):
            with self.subTest(required=required):
                self.assertIn(required, self.test)

    def test_v3_runtime_failure_is_pinned_to_first_v1_fixture_error(self) -> None:
        final = OLD_FAILURE_ROOT / "final.json"
        self.assertEqual(digest(final), OLD_FINAL_SHA256)
        receipt = json.loads(final.read_text(encoding="utf-8"))
        self.assertEqual(receipt["child_exit_code"], 1)
        self.assertEqual(receipt["stop_reason"], "natural_exit")
        self.assertEqual(receipt["claim_ceiling"], "fixture_focused_test_only")
        self.assertFalse(receipt["physical_credit"])
        output = (OLD_FAILURE_ROOT / "stdout.raw").read_text(encoding="utf-8")
        self.assertIn("strong mechanism payload requires atomic graph edges", output)
        self.assertIn("search_physical_consumer_v1_tests.jl:116", output)
        self.assertIn("SearchPhysicalConsumerV3", output)
        self.assertIn("search_physical_consumer_v3_tests.jl:5", output)

    def test_old_actual_run_did_not_pin_the_constructor_source(self) -> None:
        receipt = json.loads((OLD_FAILURE_ROOT / "final.json").read_text(encoding="utf-8"))
        self.assertNotIn("src/Genomes/MechanismGenomePayload.jl", receipt["pins_after"])
        self.assertEqual(digest(MECHANISM_CONTRACT), PINNED["src/Genomes/MechanismGenomePayload.jl"])

    def test_v3_static_suite_passed_without_proving_julia_execution(self) -> None:
        exit_receipt = STATIC_RECEIPT_ROOT / "v3_static_exit.txt"
        self.assertEqual(exit_receipt.read_text(encoding="utf-8").strip(), "0")
        stderr = (STATIC_RECEIPT_ROOT / "v3_static_stderr.raw").read_text(encoding="utf-8")
        self.assertIn("Ran 9 tests", stderr)
        self.assertIn("OK", stderr)
        self.assertEqual(json.loads((OLD_FAILURE_ROOT / "final.json").read_text(encoding="utf-8"))["child_exit_code"], 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
