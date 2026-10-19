"""Python-only static/negative checks for the additive G3 MFP V2 slice.

This does not parse or execute Julia and is not a Julia test substitute. It
checks source-level contract markers, fixture coverage, and immutable V1 pins.
"""

from __future__ import annotations

import hashlib
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl"
FOCUSED = ROOT / "test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl"
V1_SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV1.jl"
V1_TEST = ROOT / "test/GenomeV5/G3/G3MaterialFieldProjectionV1/focused_tests.jl"
G3SF_SOURCE = ROOT / "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl"
G3SF_TEST = ROOT / "test/GenomeV5/G3/up2_g3_source_feedback_v1_tests.jl"

FROZEN_INPUT_SHA256 = {
    V1_SOURCE: "74df80b1204a4ede798171fb06926ab4f1291fccd7fe658d15d626ba9f4e6598",
    V1_TEST: "85a57e248872ff62ebeec70c40389a531c47ab86186e1c0817dd2086a35208d6",
    G3SF_SOURCE: "616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7",
    G3SF_TEST: "2569086821d04a2a1a77584cf07fbc27a06278e3eef37a31591c5f34fcea9f31",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class G3MFPV2StaticContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = SOURCE.read_text(encoding="utf-8-sig")
        cls.focused = FOCUSED.read_text(encoding="utf-8-sig")

    def test_frozen_v1_and_g3sf_inputs_are_unchanged(self) -> None:
        for path, expected in FROZEN_INPUT_SHA256.items():
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                self.assertEqual(sha256(path), expected)

    def test_source_and_heat_witnesses_are_distinct_candidate_condition_bound_types(self) -> None:
        self.assertIn("struct G3MFPSourceOperatingPointV2", self.source)
        self.assertIn("struct G3MFPHeatEndpointWitnessV2", self.source)
        for field in (
            "candidate_ref::QualifiedRefV1",
            "source_ref::QualifiedRefV1",
            "declaration_hash::Digest256",
            "operating_condition_ref::QualifiedRefV1",
            "operating_condition_hash::Digest256",
            "evidence_sha256::Digest256",
        ):
            self.assertGreaterEqual(self.source.count(field), 2, field)

    def test_projection_runs_g3sf_evaluator_and_checks_external_heat_witness(self) -> None:
        self.assertIn("g3_sf_evaluate_v1(declaration, source.source_power_w)", self.source)
        self.assertIn("heat_witness.heat_power_w == evaluation.heat_power", self.source)
        self.assertIn("heat_witness.endpoint_id == declaration.law.heat_endpoint_id", self.source)
        self.assertIn("heat_witness.record_hash", self.source)
        self.assertIn("independent_candidate_bound_heat_endpoint_witness_missing", self.source)

    def test_only_evaluated_heat_power_feeds_the_spatial_rhs(self) -> None:
        self.assertIn("evaluation.heat_power * weight", self.source)
        self.assertIn("integrated_heat == heat_witness.heat_power_w", self.source)
        self.assertNotIn("source.source_power_w * weight", self.source)
        self.assertNotIn("witness.power_w * weight", self.source)

    def test_allocation_requires_region_binding_jacobian_and_uniform_profile(self) -> None:
        for marker in (
            "heat_witness_hash::Digest256",
            "g2_region_map_hash::Digest256",
            "jacobian_included::Bool",
            "profile_kind !== :uniform_within_region",
            "sum(r.allocation_fraction for r in allocation.region_support; init=0 // 1) == 1",
            "physical_measure_jacobian_missing",
            "candidate_bound_heat_to_region_allocation_missing",
        ):
            self.assertIn(marker, self.source)

    def test_material_property_is_a_positive_definite_si_tensor(self) -> None:
        for marker in (
            "conductivity_tensor_w_m_k::NTuple{9,Rational{Int64}}",
            "conductivity_domain_lower=x.conductivity_domain_lower",
            "selected isotropic conductivity must lie in its positive declared domain",
            "g2_region_map_ref=x.g2_region_map_ref",
            "physical_frame_ref=x.physical_frame_ref",
            "conductivity_region_map_mismatch:",
            "conductivity_physical_frame_mismatch:",
            "material_law === :isotropic_scalar",
            "return (scalar, 0 // 1, 0 // 1, 0 // 1, scalar, 0 // 1, 0 // 1, 0 // 1, scalar)",
            "minor1 > 0 && minor2 > 0 && determinant > 0",
            "conductivity tensor must use SI W/(m*K)",
            "duplicate_region_conductivity_selection",
        ):
            self.assertIn(marker, self.source)

    def test_missing_and_contradictory_evidence_have_separate_status_paths(self) -> None:
        for marker in (
            "status=:terminal_deferred",
            "status=:fail_closed",
            "heat_endpoint_witness_disagrees_with_evaluated_ledger",
            "heat_region_allocation_fractions_not_conservative",
            "conductivity_selection_for_unmapped_region",
            "region_conductivity_selection_missing:",
        ):
            self.assertIn(marker, self.source)

    def test_no_runtime_or_solver_integration_was_added(self) -> None:
        for forbidden in ("Gridap.", "CartesianDiscreteModel", "solve(", "include("):
            self.assertNotIn(forbidden, self.source)
        self.assertNotIn("g3_mfp_project_v1", self.source)
        self.assertIn("compiler_calls=0", self.source)
        self.assertIn("provider_calls=0", self.source)
        self.assertIn("mesh_calls=0", self.source)
        self.assertIn("solver_calls=0", self.source)

    def test_receipt_cannot_claim_acceptance_or_physical_credit(self) -> None:
        for marker in (
            "accepted=false",
            "claim_ceiling=G3_MFP_V2_CLAIM_CEILING",
            "physical_status=:unknown",
            "formal_up2_credit=false",
            "formal_r_credit=false",
            "discovery_credit=false",
            "engineering_credit=false",
        ):
            self.assertIn(marker, self.source)

    def test_focused_fixture_covers_120_to_15w_and_no_credit(self) -> None:
        for marker in (
            "receipt.source_power_w == 120 // 1",
            "receipt.field_power_w == 90 // 1",
            "receipt.return_power_w == 15 // 1",
            "receipt.heat_power_w == 15 // 1",
            "receipt.integrated_heat_power_w == 15 // 1",
            "receipt.accepted === false",
            "receipt.physical_status === :unknown",
        ):
            self.assertIn(marker, self.focused)

    def test_focused_fixture_contains_fail_closed_and_deferred_negative_controls(self) -> None:
        for marker in (
            "no_heat.status == :terminal_deferred",
            "no_allocation.status == :terminal_deferred",
            "jacobian=false",
            "unsupported_profile.status == :terminal_deferred",
            "mismatched_heat.status == :fail_closed",
            "wrong_heat_candidate.status == :fail_closed",
            "wrong_heat_condition.status == :fail_closed",
            "wrong_condition.status == :fail_closed",
            "wrong_map.status == :fail_closed",
            "wrong_frame.status == :fail_closed",
            "bad_allocation.status == :fail_closed",
            "duplicate.status == :fail_closed",
            "anisotropic.conductivity_tensor_w_m_k[2] == 1 // 1",
            "@test_throws ArgumentError",
            "-1 // 1",
            ":symmetric_positive_definite_tensor",
        ):
            self.assertIn(marker, self.focused)


if __name__ == "__main__":
    unittest.main(verbosity=2)
