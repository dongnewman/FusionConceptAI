"""Static checks for the isolated SearchPhysicalConsumerV2 revision.

This verifier neither parses nor executes Julia and does not run FreeGS. It
checks the frozen upstream seam and source-level fail-closed boundaries only.
"""
from __future__ import annotations

import hashlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/SearchPhysicalConsumerV2.jl"
V1_SOURCE = ROOT / "src/RuntimeV4/SearchPhysicalConsumerV1.jl"
JULIA_TEST = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV2/search_physical_consumer_v2_tests.jl"
ENTRY = ROOT / "src/RuntimeV4/FusionRuntimeV4.jl"

PINNED = {
    "src/Canonical/CanonicalJSON.jl": "612edaeb822c1beeff44f7134497426fd0c8ff1eea9c16a651421e2c63f8ab93",
    "src/FusionConceptAI.jl": "7fba6b0f632ce28cd2dd6e250561998988e241963b0ab44a3ef1677fdb270066",
    "src/RuntimeV4/SearchPhysicalConsumerV1.jl": "7e3e573cd8da4af80c4504b5f47654041f5de37ebb339a1c414e2dc374cba3bb",
    "test/RuntimeV4/SearchPhysicalConsumerV1/search_physical_consumer_v1_tests.jl": "fac3bd186c4e30ae16c9c10416d9352b12fd806669db30fac9ac8ac22341edca",
    "examples/runtime_v4_declared_fixture.jl": "b8c3140f65574c53163193c310c114b76da7fac868daa13af0381a322a652b6e",
    "docs/implementation/UP5-01/archive/search_physical_consumer_v1_reference_inverse_review_r1_20260924/review.md": "6cf03729ea2277523884a7fd949968d55ae9dbc7ce704dc822535fd2567f7f6d",
    "src/RuntimeV4/Search.jl": "3068b8b65a53745f1f1ac5cb4eee50133a2383c94ed48a60a4a5547aa75d3a83",
    "src/RuntimeV4/Compiler.jl": "7a550e2b9ac27693f7e7008f3562ef6d5f52795997bc89c676440cb2e4bab4aa",
    "src/RuntimeV4/RuntimePipeline.jl": "8c40d60a64560043546baabcb9623e8e261303d1278719fb2cd8033621a738e7",
    "src/RuntimeV4/FusionRuntimeV4.jl": "de87c548c716a041cb7d600cca4bb3d6712dc4222d3d8c526014d598075e8767",
    "src/RuntimeV4/ForwardChainContext.jl": "cabb8ad76db0186681df01fdf9d30d27631d27550dd756c77b8e0255409f977e",
    "src/RuntimeV4/TrustedProviderRegistryV4.jl": "2b3d54fdfb076a91da0739f4e5d4cff800165aef26e3c6596895e4a241b06339",
    "src/RuntimeV4/TrustedFreeGSAxisymmetricProviderV4.jl": "d90d691decbae92eb6939f7afe8e3739f3303a41cf788fec48552b2a792d988b",
    "src/RuntimeV4/FreeGSAxisymmetricExecution.jl": "0aafede1bba391c3422e4ff5f3dfb65101ece1850131f3acfef72941d197dfc5",
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SearchPhysicalConsumerV2StaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8-sig")
        cls.v1_source = V1_SOURCE.read_text(encoding="utf-8-sig")
        cls.test = JULIA_TEST.read_text(encoding="utf-8-sig")
        cls.entry = ENTRY.read_text(encoding="utf-8-sig")

    def test_frozen_v1_and_shared_seam_hashes_match(self) -> None:
        for relative, expected in PINNED.items():
            with self.subTest(path=relative):
                path = ROOT / relative
                self.assertTrue(path.is_file())
                self.assertEqual(digest(path), expected)

    def test_v2_remains_additive_and_outside_shared_entry(self) -> None:
        self.assertIn("module SearchPhysicalConsumerV2", self.source)
        self.assertIn("not included by `FusionRuntimeV4.jl`", self.source)
        self.assertNotIn('include("SearchPhysicalConsumerV2.jl")', self.entry)
        self.assertNotIn("function next_compilable!", self.source)
        self.assertNotIn("function compile_candidate", self.source)

    def test_v1_and_v2_extend_package_semantic_view_and_canonical_hash(self) -> None:
        self.assertIn("import FusionConceptAI: canonical_hash, semantic_view", self.source)
        self.assertIn("semantic_view(x::SearchPhysicalConsumerV1.SearchPhysicalConsumerReceiptV1)", self.source)
        self.assertIn("semantic_view(x::SearchPhysicalConsumerReceiptV2)", self.source)
        self.assertIn("canonical_json(record)", self.test)
        self.assertIn("search-physical-consumer-v2", self.test)

    def test_dispatch_uses_only_repository_executor_and_no_callback_api(self) -> None:
        self.assertIn("execute_trusted_provider(registry, context, request)", self.source)
        self.assertIn("function execute_search_physical_consumer_v2!(queue::CandidateQueueV4,", self.source)
        self.assertNotIn("executor::Function", self.source)
        self.assertNotIn("executor=", self.source)
        self.assertIn("executor=fake_provider", self.test)
        self.assertIn("@test_throws MethodError", self.test)

    def test_queue_dispatch_has_single_owner_lease_snapshot_and_replay_guard(self) -> None:
        for fragment in (
            "const _SPC2_OWNER_GUARD = ReentrantLock()",
            "const _SPC2_QUEUE_OWNERS = WeakKeyDict",
            "const _SPC2_DISPATCHED = WeakKeyDict",
            "function _spc2_claim_dispatch!",
            "function _spc2_dispatch_gate",
            "function _spc2_mark_dispatched!",
            "queue_changed_before_dispatch",
            "already_dispatched",
            "queue_changed_during_dispatch",
            "caller must not mutate the queue during",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)
        self.assertIn("queue_owner_busy", self.test)
        self.assertIn("_spc2_dispatch_gate", self.test)
        self.assertIn("already_dispatched", self.test)
        self.assertIn("priority + 1, :active", self.test)

    def test_exception_and_tampered_receipt_paths_are_fail_closed(self) -> None:
        for fragment in (
            "failure_code=:trusted_dispatch_exception",
            "failure_code=:trusted_receipt_invalid",
            "validate_trusted_provider_execution_receipt(receipt,",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)
        self.assertIn("failure_code=:preflight_exception", self.v1_source)
        self.assertIn("malformed_registry", self.test)
        self.assertIn("state === :program_exception", self.test)
        self.assertIn("!R2.validate_trusted_provider_execution_receipt(tampered,", self.test)
        self.assertIn("calls[] == 0", self.test)
        self.assertNotIn("execute_trusted_provider(", self.test)

    def test_claim_ceiling_is_screen_only_and_zero_credit(self) -> None:
        for fragment in (
            "claim_ceiling == (x.state === :screen_only ? screen_only : none)",
            "!x.physical_validation && !x.engineering_validation",
            "x.candidate_discovery_credit == 0 && x.credible_device_count == 0",
            "outer_state = stable ? inner.state : :deferred",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)
        self.assertNotIn("engineering_pass", self.source)
        self.assertNotIn("candidate_discovery!", self.source)

    def test_focused_test_does_not_launch_solver_or_provider(self) -> None:
        self.assertNotIn("execute_trusted_provider(", self.test)
        self.assertNotIn("run(`", self.test)
        self.assertNotIn("freegs_solve", self.test.lower())
        self.assertIn("_spc2_execution_receipt_valid", self.test)
        self.assertIn("synthetic tamper negative control", self.test)


if __name__ == "__main__":
    unittest.main(verbosity=2)
