"""Tests for the independent mathematical and discrete Q1 oracle."""

from __future__ import annotations

import math
import unittest
from fractions import Fraction as F

import independent_q1_oracle as oracle


class ManufacturedPolynomialTests(unittest.TestCase):
    def test_reference_vanishes_on_all_six_faces(self) -> None:
        for axis in range(3):
            for side in (0, 1):
                point = [oracle.LOWER[i] + oracle.LENGTHS[i] / 2
                         for i in range(3)]
                point[axis] = (oracle.LOWER[axis] if side == 0 else
                               oracle.LOWER[axis] + oracle.LENGTHS[axis])
                self.assertEqual(oracle.exact_value(point), F(0))

    def test_strong_source_contains_variable_coefficient_derivative(self) -> None:
        point = (F(3, 4), F(7, 6), F(5, 4))
        t = tuple((point[i] - oracle.LOWER[i]) / oracle.LENGTHS[i]
                  for i in range(3))
        ks = oracle.diagonal_k(point)
        full = oracle.strong_source(point)
        omitted_product_rule_term = sum(
            2 * ks[i] / oracle.LENGTHS[i] ** 2
            * math.prod(oracle._bubble(t[j]) for j in range(3) if j != i)
            for i in range(3)
        )
        self.assertIsInstance(full, F)
        self.assertGreater(abs(full - omitted_product_rule_term), F(1, 10000))

    def test_continuous_source_and_boundary_flux_balance_exactly(self) -> None:
        source, outward, defect = oracle.exact_balance()
        self.assertGreater(source, 0.0)
        self.assertLess(outward, 0.0)
        self.assertEqual(defect, 0.0)
        exact_source = oracle._fraction_source_integral()
        exact_outward = oracle._fraction_outward_conormal()
        self.assertEqual(exact_source + exact_outward, F(0))
        self.assertEqual(source, float(exact_source))
        self.assertEqual(outward, float(exact_outward))


class IndependentDiscreteOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.series = oracle.run_frozen_series()

    def test_oracle_uses_the_frozen_grid_and_unchanged_thresholds(self) -> None:
        self.assertEqual(self.series["grid_levels"], oracle.GRID_LEVELS)
        self.assertEqual(oracle.THRESHOLDS, {
            "residual_abs_tol": 1.0e-9,
            "residual_rel_tol": 1.0e-11,
            "boundary_abs_tol": 1.0e-10,
            "source_integral_abs_tol": 1.0e-10,
            "analytic_identity_abs_tol": 1.0e-12,
            "reaction_balance_abs_tol": 1.0e-9,
            "l2_order_interval": (1.4, 2.6),
            "h1_order_interval": (0.6, 1.4),
            "finest_l2_max": 5.0e-3,
            "finest_h1_seminorm_max": 1.0e-2,
        })

    def test_each_grid_has_small_residual_and_correct_global_balance(self) -> None:
        for row in self.series["levels"]:
            self.assertTrue(
                row["residual_abs"] <= oracle.THRESHOLDS["residual_abs_tol"]
                or row["residual_rel"] <= oracle.THRESHOLDS["residual_rel_tol"]
            )
            self.assertLessEqual(row["boundary_linf"],
                                 oracle.THRESHOLDS["boundary_abs_tol"])
            self.assertLessEqual(row["source_integral_error"],
                                 oracle.THRESHOLDS["source_integral_abs_tol"])
            self.assertLessEqual(abs(row["analytic_identity_defect"]),
                                 oracle.THRESHOLDS["analytic_identity_abs_tol"])
            self.assertLessEqual(row["discrete_interior_reaction_linf"],
                                 oracle.THRESHOLDS["residual_abs_tol"])
            self.assertLessEqual(abs(row["discrete_boundary_reaction_balance_defect"]),
                                 oracle.THRESHOLDS["reaction_balance_abs_tol"])

    def test_three_grid_orders_and_finest_errors_meet_frozen_gates(self) -> None:
        self.assertEqual(len(self.series["levels"]), 3)
        self.assertTrue(all(
            self.series["levels"][i]["l2_error"] >
            self.series["levels"][i + 1]["l2_error"]
            for i in range(2)
        ))
        self.assertTrue(all(
            self.series["levels"][i]["h1_seminorm_error"] >
            self.series["levels"][i + 1]["h1_seminorm_error"]
            for i in range(2)
        ))
        self.assertTrue(all(
            oracle.THRESHOLDS["l2_order_interval"][0] <= q <=
            oracle.THRESHOLDS["l2_order_interval"][1]
            for q in self.series["l2_orders"]
        ))
        self.assertTrue(all(
            oracle.THRESHOLDS["h1_order_interval"][0] <= q <=
            oracle.THRESHOLDS["h1_order_interval"][1]
            for q in self.series["h1_orders"]
        ))
        self.assertLessEqual(self.series["levels"][-1]["l2_error"],
                             oracle.THRESHOLDS["finest_l2_max"])
        self.assertLessEqual(self.series["levels"][-1]["h1_seminorm_error"],
                             oracle.THRESHOLDS["finest_h1_seminorm_max"])
        self.assertEqual(oracle.acceptance_failures(self.series), ())


if __name__ == "__main__":
    unittest.main(verbosity=2)
