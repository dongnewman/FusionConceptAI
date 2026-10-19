"""Python-only integrity preflight for the isolated G3 MFP V2 negative test.

This checks the fixture/test pins and their declared determinant case. It does
not execute Julia or substitute for the targeted Julia constructor test.
"""

from __future__ import annotations

import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TEST_DIR = ROOT / "test/GenomeV5/G3/G3MaterialFieldProjectionV2"
SOURCE = ROOT / "src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl"
BASELINE_TEST = TEST_DIR / "focused_tests.jl"
TARGET_TEST = TEST_DIR / "determinant_negative_v1_tests.jl"
FIXTURE_PATH = TEST_DIR / "determinant_negative_v1_fixture.json"

PINNED_SHA256 = {
    SOURCE: "d08dff9064808e36762a226b94b2295a4cc38f81981f8008ce1425a80531771a",
    BASELINE_TEST: "a4752286960efe44566bd9c745c94efedbceb43e1c8e6754b3c1ea91b1a88064",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class DeterminantNegativeStaticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fixture = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        cls.source = SOURCE.read_text(encoding="utf-8-sig")
        cls.test = TARGET_TEST.read_text(encoding="utf-8-sig")

    def test_reviewed_source_and_existing_focused_test_are_pinned(self) -> None:
        for path, expected in PINNED_SHA256.items():
            with self.subTest(path=path.relative_to(ROOT).as_posix()):
                self.assertEqual(sha256(path), expected)

    def test_fixture_is_symmetric_with_positive_first_two_minors_and_negative_determinant(self) -> None:
        self.assertEqual(self.fixture["version"], "v1")
        a, b, c, d, e, f, g, h, i = self.fixture["conductivity_tensor_w_m_k"]
        self.assertEqual((b, c, f), (d, g, h))
        self.assertEqual(a, self.fixture["expected_gate"]["first_leading_principal_minor"])
        self.assertEqual(a * e - b * d,
                         self.fixture["expected_gate"]["second_leading_principal_minor"])
        determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
        self.assertEqual(determinant, self.fixture["expected_gate"]["determinant"])
        self.assertEqual(determinant, -1)
        self.assertFalse(self.fixture["expected_gate"]["spd"])

    def test_targeted_julia_test_reaches_both_spd_helper_and_public_constructor(self) -> None:
        self.assertIn("_g3mfp2_tensor_spd(tensor) === false", self.test)
        self.assertIn("G.G3MFPConductivityTensorSelectionV2(", self.test)
        self.assertIn("observed_error isa ArgumentError", self.test)
        self.assertEqual(
            self.fixture["expected_gate"]["reject_reason_contains"],
            "symmetric positive definite",
        )
        self.assertIn("FIXTURE.expected_gate.reject_reason_contains", self.test)
        self.assertIn("determinant_negative_v1_fixture.json", self.test)

    def test_source_has_full_determinant_spd_gate(self) -> None:
        self.assertIn("determinant = a * (e * i - f * f)", self.source)
        self.assertIn("minor1 > 0 && minor2 > 0 && determinant > 0", self.source)
        self.assertIn("_g3mfp2_tensor_spd(tensor) || throw(ArgumentError", self.source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
