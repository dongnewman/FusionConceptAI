"""Python-only static checks for the additive G3 MFP V3 body-parity candidate."""

from __future__ import annotations

import hashlib
import json
import re
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV3.jl"
FOCUSED = HERE / "focused_tests.jl"
FIXTURE = ROOT / "test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json"
V2_SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl"
V2_TEST = ROOT / "test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl"
LAW_SOURCE = ROOT / "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
V2_ACTUAL = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/root_g3_focused_v2_grant_20260924/actual_run_v1"

PINNED_OLD_BYTES = {
    V2_SOURCE: "d08dff9064808e36762a226b94b2295a4cc38f81981f8008ce1425a80531771a",
    V2_TEST: "a4752286960efe44566bd9c745c94efedbceb43e1c8e6754b3c1ea91b1a88064",
    LAW_SOURCE: "616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7",
    FIXTURE: "7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40",
    V2_ACTUAL / "final.json": "03c008751f1e7f3c13ea7eef2c5e68d73b49e1b11bc12405290403d3328af029",
    V2_ACTUAL / "stdout.raw": "eb5cf84322a3fe5c932e8eb422462a98b9819ce9c9142be72eecd4c8f1d073f6",
}


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _function_body(source: str, signature: str) -> str:
    match = re.search(re.escape(signature) + r"\n(.*?)\nend", source, re.DOTALL)
    if match is None:
        raise AssertionError(f"function not found: {signature}")
    return match.group(1)


def _draft_body(source: str, constructor: str) -> str:
    start = source.find(f"function {constructor}(")
    if start < 0:
        raise AssertionError(f"constructor not found: {constructor}")
    draft_start = source.find("draft = (", start)
    authority_start = source.find("authority_hash =", draft_start)
    if draft_start < 0 or authority_start < 0:
        raise AssertionError(f"hashed draft not found: {constructor}")
    return source[draft_start:authority_start]


class G3MFPV3StaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8")
        cls.focused = FOCUSED.read_text(encoding="utf-8")

    def test_old_v2_failure_ancestry_and_inputs_are_unchanged(self) -> None:
        for path, expected in PINNED_OLD_BYTES.items():
            self.assertEqual(_sha256(path), expected, path.as_posix())
        final = json.loads((V2_ACTUAL / "final.json").read_text(encoding="utf-8"))
        self.assertEqual(final["child_exit_code"], 1)
        self.assertEqual(final["stop_reason"], "natural_exit")
        self.assertEqual(final["peak_sampled_process_tree_rss_bytes"], 544_092_160)
        self.assertEqual(final["claim_ceiling"], "constructor_gate_regression_only")
        self.assertFalse(final["physical_credit"])

    def test_all_three_constructor_drafts_bind_the_canonical_si_basis(self) -> None:
        pairs = (
            ("_g3mfp3_source_content(x)", "G3MFPSourceOperatingPointV3"),
            ("_g3mfp3_heat_content(x)", "G3MFPHeatEndpointWitnessV3"),
            ("_g3mfp3_conductivity_content(x)", "G3MFPConductivityTensorSelectionV3"),
        )
        for content_signature, constructor in pairs:
            with self.subTest(constructor=constructor):
                content = _function_body(self.source, f"function {content_signature}")
                draft = _draft_body(self.source, constructor)
                self.assertIn("unit_basis=G3_MFP_V3_SI_BASIS", content)
                self.assertIn("unit_basis=G3_MFP_V3_SI_BASIS", draft)

    def test_hash_domains_and_schema_are_new_v3_identities(self) -> None:
        self.assertIn('G3_MFP_V3_SCHEMA_ID = "GenomeV5/G3/G3MaterialFieldProjectionV3"', self.source)
        self.assertIn('G3_MFP_V3_VERSION = "v3"', self.source)
        self.assertIn("G3-MFP-V3-source-authority-binding", self.source)
        self.assertIn("G3-MFP-V3-source-operating-point", self.source)
        self.assertIn("G3-MFP-V3-heat-authority-binding", self.source)
        self.assertIn("G3-MFP-V3-heat-endpoint-witness", self.source)
        self.assertIn("G3-MFP-V3-material-authority-binding", self.source)
        self.assertIn("G3-MFP-V3-conductivity-tensor-selection", self.source)
        self.assertIn("G3-MFP-V3-heat-allocation-authority", self.source)
        self.assertIn("G3-MFP-V3-heat-allocation", self.source)
        self.assertIn("G3_MFP_V3_SCHEMA_ID, version=G3_MFP_V3_VERSION", self.source)
        self.assertNotIn("G3-MFP-V2", self.source)
        self.assertNotIn("G3_MFP_V2", self.source)

    def test_focused_runtime_oracle_and_negative_tampering_cases_are_present(self) -> None:
        for name in ("source_valid", "heat_valid", "conductivity_valid"):
            self.assertIn(f"_g3mfp3_{name}", self.focused)
        self.assertIn("G3-MFP-V2-source-authority-binding", self.focused)
        self.assertIn("G3-MFP-V2-heat-authority-binding", self.focused)
        self.assertIn("G3-MFP-V2-material-authority-binding", self.focused)
        self.assertIn("wrong_basis", self.focused)
        self.assertIn("unit_basis=wrong_basis", self.focused)
        self.assertIn('"G3MaterialFieldProjectionV3 witness hash body parity"', self.focused)
        self.assertIn('"G3MaterialFieldProjectionV3 SI basis and versioned hash tampering"', self.focused)

    def test_all_v3_identity_layers_are_recomputed_and_candidate_bound(self) -> None:
        self.assertIn("_G3MFP3_FIXTURE", self.focused)
        self.assertIn("up2_g3_source_feedback_v1_fixture.json", self.focused)
        self.assertNotIn("_G3MFP2", self.focused)
        self.assertNotIn("_g3mfp2_", self.focused)
        for token in (
            "allocation_content = G._g3mfp3_allocation_content(allocation)",
            'domain="G3-MFP-V3-heat-allocation-authority"',
            'domain="G3-MFP-V3-heat-allocation"',
            "receipt_content = G._g3mfp3_receipt_content(receipt)",
            "receipt.receipt_hash == canonical_hash(receipt_content)",
            "receipt_content.candidate_ref == declaration.candidate_ref",
            'candidate_ref=QualifiedRefV1("local://foreign/candidate", "v5")',
            "G.semantic_view(receipt).schema_id == G.G3_MFP_V3_SCHEMA_ID",
        ):
            self.assertIn(token, self.focused)

    def test_g3sf_heat_law_stays_source_bound_and_integrates_fifteen_watts(self) -> None:
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        self.assertEqual(fixture["law"]["heat_fraction"], [1, 8])
        self.assertIn("g3_sf_evaluate_v1(declaration, source.source_power_w)", self.source)
        self.assertIn("heat_witness.heat_power_w == evaluation.heat_power", self.source)
        self.assertIn("integrated_heat == heat_witness.heat_power_w", self.source)
        self.assertIn("integrated_heat_power_w == 15 // 1", self.focused)
        self.assertIn("receipt.heat_power_w == 15 // 1", self.focused)
        self.assertIn("receipt.source_power_w == 120 // 1", self.focused)

    def test_fail_closed_and_no_physics_credit_gates_remain(self) -> None:
        self.assertIn("_g3mfp3_source_valid(source)", self.source)
        self.assertIn("_g3mfp3_heat_valid(heat_witness)", self.source)
        self.assertIn("all(_g3mfp3_conductivity_valid, selections)", self.source)
        self.assertIn("conductivity tensor must be symmetric positive definite", self.source)
        self.assertIn("accepted=false", self.source)
        self.assertIn("physical_status=:unknown", self.source)
        self.assertIn("provider_calls=0, mesh_calls=0, solver_calls=0", self.source)
        self.assertIn("receipt.accepted === false", self.focused)
        self.assertIn("receipt.claim_ceiling === :screen_only", self.focused)
        self.assertIn("receipt.solver_calls) == (0, 0, 0, 0)", self.focused)

    def test_symmetric_negative_determinant_fixture_is_explicit(self) -> None:
        self.assertIn('G3MaterialFieldProjectionV3 symmetric negative determinant fails closed', self.focused)
        self.assertIn(
            "(1 // 1, 0 // 1, 0 // 1, 0 // 1, 1 // 1, 0 // 1, 0 // 1, 0 // 1, -1 // 1)",
            self.focused,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
