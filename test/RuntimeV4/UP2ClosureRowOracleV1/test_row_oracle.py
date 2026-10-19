from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path

import numpy as np


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))
import row_oracle as oracle  # noqa: E402


RUN = (REPO / "docs" / "implementation" / "UP2-04-CLOSURE-REPAIR-PREC" /
       "agent_r2_n1_20260922" / "runtime_manufactured_staged_r1" /
       "producer_process" / "numerical")
MODEL_PATH = RUN / "preflight" / "canonical_input.json"
DECLARATION_PATH = RUN / "preflight" / "canonical_declaration.json"
PRIMARY_PATH = RUN / "production" / "n1_q1_2" / "solver_primary.json"


class IndependentRowOracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        for path in (MODEL_PATH, DECLARATION_PATH, PRIMARY_PATH):
            if not path.is_file():
                raise FileNotFoundError(f"retained v10 partial evidence is required: {path}")
        cls.model = json.loads(MODEL_PATH.read_text(encoding="utf-8"))
        cls.declaration = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
        cls.primary = json.loads(PRIMARY_PATH.read_text(encoding="utf-8"))
        cls.mesh = oracle.build_mesh(cls.model)

    def test_frozen_mesh_row_and_dof_ownership(self) -> None:
        self.assertEqual(len(self.mesh.nodes_q), 10)
        self.assertEqual(len(self.mesh.cell_nodes), 8)
        self.assertEqual(len(self.mesh.faces), 24)
        self.assertEqual(4 * len(self.mesh.nodes_q), 40)
        self.assertEqual(len(self.mesh.row_blocks), 289)
        self.assertEqual(self.mesh.row_blocks[-1], "total_flux_Wb")
        self.assertEqual(sum(block == "momentum_N" for block in self.mesh.row_blocks), 168)
        self.assertEqual(sum(block == "divB_Wb" for block in self.mesh.row_blocks), 56)
        self.assertEqual(sum(block == "traction_N" for block in self.mesh.row_blocks), 48)
        self.assertEqual(sum(block == "normal_B_Wb" for block in self.mesh.row_blocks), 16)

    def test_declared_gauss_rules_integrate_polynomial_moments(self) -> None:
        for order in (3, 5, 7, 9):
            roots, weights = oracle._gauss(self.model, order)
            for degree in range(2 * order):
                expected = 0.0 if degree % 2 else 2.0 / (degree + 1)
                self.assertAlmostEqual(float(weights @ roots**degree), expected, places=13)

    def test_saved_initial_state_matches_rebuilt_analytic_nodal_state(self) -> None:
        reference = oracle.reference_state(self.mesh, self.model)
        perturbation = np.asarray(self.model["initialization"]["perturbation"])
        expected = reference + np.tile(perturbation, len(self.mesh.nodes_q))
        actual = np.asarray(self.primary["initial_state"], dtype=float)
        self.assertEqual(actual.size, 40)
        self.assertLessEqual(float(np.max(np.abs(expected - actual))), 2e-10)

    def test_exact_field_gl3_flux_closes_on_declared_cut(self) -> None:
        state = oracle.reference_state(self.mesh, self.model)
        result = oracle.assemble(self.model, self.declaration, self.mesh,
                                 state, 3, mode="exact")
        self.assertEqual(result["residual"].size, 289)
        self.assertTrue(np.all(np.isfinite(result["residual"])))
        self.assertLessEqual(abs(float(result["residual"][-1])), 2e-12)
        self.assertAlmostEqual(float(self.model["flux"]["nominal_Wb"]), math.pi,
                               places=14)


if __name__ == "__main__":
    unittest.main(verbosity=2)
