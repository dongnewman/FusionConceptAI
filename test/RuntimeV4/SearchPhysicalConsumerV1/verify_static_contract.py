"""Static boundary checks for the isolated SearchPhysicalConsumerV1 slice.

This verifier does not parse or execute Julia and is not a substitute for the
focused Julia test or a real FreeGS execution receipt.
"""
from __future__ import annotations

import hashlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "src/RuntimeV4/SearchPhysicalConsumerV1.jl"
JULIA_TEST = ROOT / "test/RuntimeV4/SearchPhysicalConsumerV1/search_physical_consumer_v1_tests.jl"

PINNED = {
    "src/RuntimeV4/SearchPhysicalConsumerV1.jl": "7e3e573cd8da4af80c4504b5f47654041f5de37ebb339a1c414e2dc374cba3bb",
    "test/RuntimeV4/SearchPhysicalConsumerV1/search_physical_consumer_v1_tests.jl": "fac3bd186c4e30ae16c9c10416d9352b12fd806669db30fac9ac8ac22341edca",
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


class SearchPhysicalConsumerStaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8-sig")
        cls.test = JULIA_TEST.read_text(encoding="utf-8-sig")
        cls.entrypoint = (ROOT / "src/RuntimeV4/FusionRuntimeV4.jl").read_text(encoding="utf-8-sig")

    def test_all_frozen_input_and_new_source_test_hashes_match(self) -> None:
        for relative, expected in PINNED.items():
            path = ROOT / relative
            with self.subTest(path=relative):
                self.assertTrue(path.is_file())
                self.assertEqual(digest(path), expected)

    def test_module_stays_outside_shared_production_entry(self) -> None:
        self.assertIn("module SearchPhysicalConsumerV1", self.source)
        self.assertNotIn('include("SearchPhysicalConsumerV1.jl")', self.entrypoint)
        self.assertIn("not included by FusionRuntimeV4", self.source)

    def test_canonical_hash_extension_uses_explicit_import(self) -> None:
        self.assertIn("import FusionConceptAI: canonical_hash", self.source)
        self.assertNotIn("using FusionConceptAI: Digest256, ClaimCeiling, canonical_hash", self.source)

    def test_exact_trusted_freegs_request_and_receipt_apis_are_used(self) -> None:
        for symbol in (
            "trusted_freegs_axisymmetric_capability(context)",
            "make_trusted_freegs_axisymmetric_input(context, capability)",
            "build_trusted_provider_dispatch_request(registry, context,",
            "execute_trusted_provider(registry, context, request)",
            "validate_trusted_provider_execution_receipt(receipt, request,",
        ):
            with self.subTest(symbol=symbol):
                self.assertIn(symbol, self.source)

    def test_search_activation_and_identity_gates_are_fail_closed(self) -> None:
        for fragment in (
            "entry.status === :active",
            "entry.compiled.compilation_status === :prefix_consistent",
            "isempty(entry.compiled.unresolved_nonterminals)",
            "entry.compiled.prefix_hash == entry_ref",
            "context.compiled.prefix_hash == entry_ref",
            "context.registry_hash == entry.registry_hash",
            "context.registry_hash == canonical_hash(context.registry)",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)
        self.assertNotIn("function next_compilable!", self.source)

    def test_revalidation_binds_current_queue_status_and_prefix(self) -> None:
        for fragment in (
            "entry.status == record.queue_status",
            "record.state in (:ready_for_dispatch, :screen_only)",
            "record.queue_status !== :active",
            "entry.compiled.prefix_hash == record.prefix_hash == context.compiled.prefix_hash",
            "_runtime_validate_compiled_prefix(entry.compiled, entry.candidate,",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)

    def test_receipt_binds_all_three_genomes_scenario_provider_and_raw_hashes(self) -> None:
        for fragment in (
            "g1_hash::Digest256",
            "g2_hash::Digest256",
            "g3_hash::Digest256",
            "scenario_hash::Digest256",
            "trusted_registry_hash::Digest256",
            "request_hash::Union{Nothing,Digest256}",
            "trusted_receipt_hash::Union{Nothing,Digest256}",
            "output_hash::Union{Nothing,Digest256}",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)

    def test_result_ceiling_never_promotes_physical_or_engineering_credit(self) -> None:
        for fragment in (
            "physical_validation::Bool",
            "engineering_validation::Bool",
            "candidate_discovery_credit::Int",
            "credible_device_count::Int",
            "candidate_discovery_credit == 0",
            "credible_device_count == 0",
            "receipt.status === :physical_model_screen",
            "state=:deferred",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.source)
        self.assertNotIn("engineering_pass", self.source)

    def test_focused_julia_tests_create_active_entries_through_search_api(self) -> None:
        self.assertIn("R.next_compilable!(queue)", self.test)
        self.assertIn("status === :active", self.test)
        self.assertNotIn("CandidateQueueEntryV4(", self.test)
        self.assertNotIn("status=:active", self.test)

    def test_focused_tests_cover_scenario_g3_registry_and_deferred_negatives(self) -> None:
        for fragment in (
            "other_scenario.state === :deferred",
            "foreign_g3=true",
            "search_context_candidate_or_prefix_mismatch",
            "search_entry_not_active",
            "search_registry_identity_mismatch",
            "!SPC.validate_search_physical_consumer_receipt(record, active.queue,",
            "request === nothing",
        ):
            with self.subTest(fragment=fragment):
                self.assertIn(fragment, self.test)

    def test_focused_tests_do_not_execute_freegs(self) -> None:
        self.assertIn("prepare_search_physical_consumer", self.test)
        self.assertNotIn("execute_search_physical_consumer!(", self.test)
        self.assertNotIn("execute_trusted_provider(", self.test)


if __name__ == "__main__":
    unittest.main(verbosity=2)
