import unittest

import numpy as np
import desc.io

from compare_interior import POINTS, TOLERANCE_M, compare
from evaluate_interior import (ROOT, _fourier, _zernike_radial,
                               evaluate_rz, load_subject)


class InteriorEvaluationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.subject = load_subject()
        cls.equilibrium = desc.io.load(ROOT / "HELIOTRON_output.h5")[3]

    def test_negative_modes_are_sine_not_single_phase_guess(self):
        self.assertAlmostEqual(_fourier(0.3, -1), np.sin(0.3))
        self.assertAlmostEqual(_fourier(0.3, 1), np.cos(0.3))
        self.assertAlmostEqual(_fourier(0.03, -1, 19), np.sin(0.57))
        self.assertAlmostEqual(_zernike_radial(2, 0, 0.5), -0.5)
        self.assertAlmostEqual(_zernike_radial(3, 1, 1.0), 1.0)

    def test_exact_source_interior_reconstructs_desc_at_frozen_nodes(self):
        for point in POINTS:
            with self.subTest(point=point):
                expected_r = float((np.asarray(
                    self.equilibrium.R_basis.evaluate(np.asarray([point]))) @
                    np.asarray(self.equilibrium.R_lmn))[0])
                expected_z = float((np.asarray(
                    self.equilibrium.Z_basis.evaluate(np.asarray([point]))) @
                    np.asarray(self.equilibrium.Z_lmn))[0])
                actual_r, actual_z = evaluate_rz(self.subject, *point)
                self.assertLess(abs(actual_r - expected_r), TOLERANCE_M)
                self.assertLess(abs(actual_z - expected_z), TOLERANCE_M)

    def test_comparison_receipt_has_no_physical_authority(self):
        result = compare()
        self.assertTrue(result["all_nodes_pass"])
        self.assertEqual(len(result["rows"]), len(POINTS))
        self.assertEqual(result["authority"]["physical_validation"],
                         "unsupported")
        self.assertFalse(result["authority"]["independent_physical_solver"])

    def test_rho_outside_declared_domain_fails(self):
        with self.assertRaisesRegex(ValueError, "rho in"):
            evaluate_rz(self.subject, -0.1, 0.1, 0.1)


if __name__ == "__main__":
    unittest.main()
