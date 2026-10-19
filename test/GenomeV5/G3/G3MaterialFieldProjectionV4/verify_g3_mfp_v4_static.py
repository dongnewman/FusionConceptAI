"""Python-only static contract and ancestry checks for G3 MFP V4."""

from __future__ import annotations

from hashlib import sha256
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV4.jl"
JULIA_TEST = Path(__file__).with_name("focused_tests.jl")
V3_SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV3.jl"
V3_TEST = ROOT / "test/GenomeV5/G3/G3MaterialFieldProjectionV3/focused_tests.jl"
SOURCE_LAW = ROOT / "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
V3_FIXTURE = ROOT / "test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json"

V3_SOURCE_SHA256 = "ce7cb1329d095ede85cd3903ca080b6d3ffccf9ca9a1d1b9b840fb1cd058d27c"
V3_TEST_SHA256 = "83eb2eefae1eb8c5deb858e458fa3fc4456aa25d37889aa5b65a3399a642d05c"
SOURCE_LAW_SHA256 = "616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7"
V3_FIXTURE_SHA256 = "7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40"


def digest(path: Path) -> str:
    return sha256(path.read_bytes()).hexdigest()


class G3MFPV4StaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")
        cls.test = JULIA_TEST.read_text(encoding="utf-8")

    def test_v3_and_source_law_ancestors_are_frozen(self) -> None:
        self.assertEqual(digest(V3_SOURCE), V3_SOURCE_SHA256)
        self.assertEqual(digest(V3_TEST), V3_TEST_SHA256)
        self.assertEqual(digest(SOURCE_LAW), SOURCE_LAW_SHA256)
        self.assertEqual(digest(V3_FIXTURE), V3_FIXTURE_SHA256)

    def test_new_schema_and_hash_domain_are_v4(self) -> None:
        self.assertIn('G3_MFP_V4_SCHEMA_ID = "GenomeV5/G3/G3MaterialFieldProjectionV4"', self.source)
        self.assertIn('G3_MFP_V4_VERSION = "v4"', self.source)
        self.assertIn('G3_MFP_V4_HASH_DOMAIN = "G3-MFP-V4-projection-receipt"', self.source)
        self.assertIn('canonical_hash((domain=G3_MFP_V4_HASH_DOMAIN, body=body))', self.source)

    def test_receipt_inner_constructor_is_sealed_and_not_fieldwise_default(self) -> None:
        body = self.source.split("struct G3MFPProjectionReceiptV4", 1)[1].split("\nend", 1)[0]
        self.assertIn("function G3MFPProjectionReceiptV4(", body)
        self.assertIn("seal::Base.RefValue{Nothing}", body)
        self.assertIn("seal === _G3MFP_PROJECTION_RECEIPT_V4_SEAL", body)
        self.assertNotIn("accepted::Bool", body)
        self.assertNotIn("formal_up2_credit::Bool", body)
        self.assertIn("@test_throws MethodError G.G3MFPProjectionReceiptV4", self.test)

    def test_v3_hash_and_no_credit_invariants_are_revalidated(self) -> None:
        for token in (
            "canonical_hash(_g3mfp3_receipt_content(receipt))",
            "v3_receipt_accepted_flag_not_false",
            "v3_receipt_claim_ceiling_not_screen_only",
            "v3_receipt_physical_status_not_unknown",
            "v3_receipt_credit_flag_set",
            "v3_receipt_execution_count_nonzero",
        ):
            self.assertIn(token, self.source)

    def test_semantic_view_revalidates_final_v4_hash(self) -> None:
        self.assertIn("function semantic_view(receipt::G3MFPProjectionReceiptV4)", self.source)
        self.assertIn("g3_mfp_validate_projection_receipt_v4(receipt)", self.source)
        self.assertIn("v4_receipt_hash_mismatch", self.source)
        self.assertIn("throw(ArgumentError", self.source)

    def test_v4_projector_uses_v3_screen_path_and_private_wrapper(self) -> None:
        self.assertIn("upstream = g3_mfp_project_v3(declaration, source_point; kwargs...)", self.source)
        self.assertIn("_g3mfp4_wrap_v3_receipt(upstream)", self.source)
        self.assertNotIn("function g3_mfp_projection_receipt_v4", self.source)

    def test_unverified_g2_and_jacobian_claims_remain_screen_only(self) -> None:
        self.assertIn("g2_map_provenance=:opaque_unverified", self.source)
        self.assertIn("jacobian_payload_verified=false", self.source)
        self.assertIn("claim_ceiling=G3_MFP_V4_CLAIM_CEILING", self.source)
        self.assertIn("physical_status=:unknown", self.source)

    def test_focused_julia_tests_cover_valid_forged_and_tampered_receipts(self) -> None:
        for token in (
            '"G3 MFP V4 sealed no-credit receipt view"',
            '"G3 MFP V4 wraps the synthetic V3 screen projection"',
            '"G3 MFP V4 rejects the V3 public-constructor credit forgery"',
            '"G3 MFP V4 rejects stale upstream hash and invalid outer semantics"',
            '"G3 MFP V4 has no default fieldwise constructor"',
            "semantic_view(outer)",
            "accepted=true",
        ):
            self.assertIn(token, self.test)
        self.assertIn("view.upstream_v3_receipt.content.heat_power_w == 15 // 1", self.test)
        self.assertIn("view.upstream_v3_receipt.content.integrated_heat_power_w == 15 // 1", self.test)

    def test_focused_suite_reuses_pinned_v3_synthetic_fixture(self) -> None:
        self.assertIn(
            'include(joinpath(@__DIR__, "..", "G3MaterialFieldProjectionV3", "focused_tests.jl"))',
            self.test,
        )

    def test_focused_julia_test_resolves_repository_root(self) -> None:
        self.assertIn(
            'joinpath(@__DIR__, "..", "..", "..", "..", "src", "GenomeV5", "G3")',
            self.test,
        )

    def test_no_claim_of_julia_runtime_or_physical_acceptance(self) -> None:
        self.assertIn("does not authenticate the opaque G2 map/frame", self.source)
        self.assertIn("therefore remains screen-only", self.source)
        self.assertNotIn("@test G.g3_mfp_project_v4", self.test)


if __name__ == "__main__":
    unittest.main(verbosity=2)
