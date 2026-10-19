"""Independent source-contract checks for the frozen G3 spatial adapter.

These checks inspect Julia source text only. They do not parse, load, or run Julia.
"""

from __future__ import annotations

import hashlib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ADAPTER_PATH = ROOT / "src/RuntimeV4/InHouseG3SpatialAuthorityAdapterV1.jl"
G3SF_PATH = ROOT / "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
G3MFP_PATH = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV3.jl"
FROZEN_SHA256 = "DD45FFB1604FD369B1A4F704B9847B5FA965F72C5B664C739AE655FBF15C7ED9"


ADAPTER_GUARDS = {
    "candidate binding": (
        "candidate_ref::QualifiedRefV1",
        "declaration.candidate_ref != request.candidate_ref",
        "source_declaration_candidate_mismatch",
        "authority.candidate_ref == request.candidate_ref",
    ),
    "raw source byte identity": (
        "Vector{UInt8}(g1_source_bytes)",
        "Vector{UInt8}(g2_source_bytes)",
        "length(bytes) == authority.source_bytes",
        "upstream_source_byte_count_mismatch",
    ),
    "source hashes and authority hash": (
        "bytes2hex(SHA.sha256(bytes))",
        "_g3sp_digest_bytes_v1(bytes) == authority.source_sha256",
        "upstream_source_sha256_mismatch",
        "g3_sf_authority_content_hash_v1(",
        "authority.contract_hash == expected_contract_hash",
        "upstream_authority_content_hash_mismatch",
    ),
    "projection receipt integrity and replay": (
        "projection.receipt_hash != canonical_hash(_g3mfp3_receipt_content(projection))",
        "expected.receipt_hash == canonical_hash(_g3mfp3_receipt_content(expected))",
        "expected.receipt_hash == projection.receipt_hash",
        "material_projection_fresh_replay_mismatch",
    ),
    "missing versus contradictory input disposition": (
        "if declaration === nothing",
        "_g3sp_receipt_v1(request, projection, :typed_absent",
        "declaration.candidate_ref != request.candidate_ref",
        "_g3sp_receipt_v1(request, nothing, :fail_closed",
        "if projection.status === :fail_closed || !isempty(errors)",
        "_g3sp_receipt_v1(request, projection, :fail_closed",
        "if projection.resolution !== :screen_only",
        "_g3sp_receipt_v1(request, projection, :typed_absent",
    ),
    "no spatial synthesis or physical credit": (
        "mapped_spatial_closure::Nothing",
        "nothing, :contract_only,",
        ":unknown, gap_tuple, error_tuple, 0, 0, 0, 0, false",
        "g3_source_density_vector_A_m2_absent",
        "g3_return_current_spatial_distribution_and_circuit_path_absent",
        "g2_outer_boundary_B_out_T_samples_and_face_orientation_absent",
        "g3_outer_sheet_current_K_outer_A_m_and_surface_support_absent",
        "projection.accepted || projection.formal_up2_credit || projection.formal_r_credit ||",
        "projection.discovery_credit || projection.engineering_credit ||",
        "projection.physical_status !== :unknown",
        "material_projection_claim_ceiling_violation",
    ),
}


def audit_adapter_text(text: str) -> dict[str, bool]:
    return {category: all(anchor in text for anchor in anchors)
            for category, anchors in ADAPTER_GUARDS.items()}


class InHouseG3SpatialAuthorityAdapterStaticReview(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.adapter_bytes = ADAPTER_PATH.read_bytes()
        cls.adapter = cls.adapter_bytes.decode("utf-8")
        cls.g3sf = G3SF_PATH.read_text(encoding="utf-8")
        cls.g3mfp = G3MFP_PATH.read_text(encoding="utf-8")

    def test_source_is_the_requested_frozen_revision(self) -> None:
        self.assertEqual(hashlib.sha256(self.adapter_bytes).hexdigest().upper(), FROZEN_SHA256)

    def test_candidate_raw_bytes_hashes_and_replayed_projection_guards_exist(self) -> None:
        results = audit_adapter_text(self.adapter)
        for category in (
            "candidate binding",
            "raw source byte identity",
            "source hashes and authority hash",
            "projection receipt integrity and replay",
        ):
            with self.subTest(category=category):
                self.assertTrue(results[category], category)

    def test_missing_inputs_defer_while_mismatches_fail_closed(self) -> None:
        self.assertTrue(audit_adapter_text(self.adapter)["missing versus contradictory input disposition"])
        self.assertIn("G3_SPATIAL_AUTHORITY_ADAPTER_V1_GAPS", self.adapter)
        self.assertIn("_g3sp_receipt_v1(request, projection, :typed_absent", self.adapter)
        self.assertIn("_g3sp_receipt_v1(request, projection, :fail_closed", self.adapter)

    def test_result_never_constructs_spatial_values_or_physical_credit(self) -> None:
        self.assertTrue(audit_adapter_text(self.adapter)["no spatial synthesis or physical credit"])
        self.assertIn("const G3_SF_V1_CLAIM_CEILING = :contract_only", self.g3sf)
        self.assertIn("const G3_MFP_V3_CLAIM_CEILING = :screen_only", self.g3mfp)
        self.assertIn("physical_status=:unknown", self.g3mfp)
        self.assertIn("formal_up2_credit=false", self.g3mfp)
        self.assertIn("solver_calls=0", self.g3mfp)

    def test_adversarial_source_mutations_are_detected_by_static_controls(self) -> None:
        # Mutation controls validate the checker itself; they do not execute Julia.
        mutations = (
            ("candidate binding", "source_declaration_candidate_mismatch"),
            ("raw source byte identity", "upstream_source_byte_count_mismatch"),
            ("source hashes and authority hash", "upstream_source_sha256_mismatch"),
            ("projection receipt integrity and replay", "material_projection_fresh_replay_mismatch"),
            ("missing versus contradictory input disposition", "if declaration === nothing"),
            ("no spatial synthesis or physical credit", "mapped_spatial_closure::Nothing"),
        )
        for category, guard in mutations:
            with self.subTest(category=category, removed_guard=guard):
                corrupted = self.adapter.replace(guard, "", 1)
                self.assertFalse(audit_adapter_text(corrupted)[category])


if __name__ == "__main__":
    unittest.main(verbosity=2)
