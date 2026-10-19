#!/usr/bin/env python3
"""Focused read-only tests for the UP2-04 artifact analyzer."""

from __future__ import annotations

import pathlib
import json
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
import up2_04_physics_closure_diagnostic as diagnostic  # noqa: E402


class PhysicsClosureDiagnosticTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = diagnostic.analyze(ROOT)

    def test_read_only_source_binding(self) -> None:
        self.assertEqual(
            self.report["source"]["sha256"],
            self.report["n1"]["production_source_sha256"],
        )
        self.assertTrue(self.report["causal_assessment"]["source_hash_matches_n1_receipt"])

    def test_w24_has_four_terminal_cases_per_run(self) -> None:
        for run_id in diagnostic.W24_IDS:
            run = self.report["w24"]["cases"][run_id]
            declared = self.report["w24"]["pair"]["case_sets"][run_id]
            self.assertEqual(set(run["cases"]), set(declared["result"]))
            self.assertEqual(set(declared["result"]), set(declared["physics"]))
            self.assertEqual(set(declared["result"]), set(declared["verification"]))
            self.assertEqual(set(declared["result"]), set(declared["execution_manifest"]))
            for case in run["cases"].values():
                self.assertEqual(case["solver_exit_code"], 4)
                self.assertFalse(case["gate_pass"])
                self.assertGreater(case["scaled_max"], 1.0e-3)

    def test_w24_block_dominance_is_explicit(self) -> None:
        parent = self.report["w24"]["cases"]["w24_spatial_parent_r1"]["cases"]
        child = self.report["w24"]["cases"]["w24_spatial_g2_child_r2"]["cases"]
        self.assertEqual(max(parent["nominal_coarse"]["residual_blocks"], key=lambda k: parent["nominal_coarse"]["residual_blocks"][k]["objective_share"]), "divB_Wb")
        self.assertEqual(max(parent["nominal_fine"]["residual_blocks"], key=lambda k: parent["nominal_fine"]["residual_blocks"][k]["objective_share"]), "momentum_N")
        self.assertEqual(max(child["nominal_coarse"]["residual_blocks"], key=lambda k: child["nominal_coarse"]["residual_blocks"][k]["objective_share"]), "divB_Wb")

    def test_rank_diagnostic_is_not_promoted_to_continuum_closure(self) -> None:
        for run_id in diagnostic.W24_IDS:
            for case in self.report["w24"]["cases"][run_id]["cases"].values():
                rank = case["solver"]["rank"]
                self.assertEqual(rank["physical_closure"], "pressure_current_topology_not_fixed")
                self.assertEqual(rank["continuum_uniqueness"], "unsupported")
                self.assertEqual(rank["rank_estimate"], case["solver"]["free_column_count"])

    def test_parent_child_audit_remains_failed_closed(self) -> None:
        pair = self.report["w24"]["pair"]
        self.assertTrue(pair["candidate_identity_differs"])
        self.assertTrue(pair["context_identity_differs"])
        self.assertEqual(pair["pair_audit"]["status"], "failed_before_output")
        self.assertGreater(pair["manifest_audit"]["mismatch_count"], 0)

    def test_n1_recomputes_negative_order_and_rejects_asymptotic_claim(self) -> None:
        n1 = self.report["n1"]
        self.assertFalse(n1["asymptotic_region_established"])
        p1 = n1["perturbations"]["1"]["pairs"][1]
        self.assertAlmostEqual(p1["observed_order_recomputed"], -6.157952975473273, places=12)
        self.assertFalse(p1["error_decreases"])
        self.assertLess(p1["to_truth_scaled_residual_max"], p1["from_truth_scaled_residual_max"])

    def test_causal_boundary_and_capability_labels_are_conservative(self) -> None:
        causal = self.report["causal_assessment"]
        self.assertEqual(causal["model"]["classification"], "confirmed_gap")
        self.assertEqual(causal["boundary"]["classification"], "unresolved_compatibility_check")
        self.assertEqual(causal["capability"]["classification"], "terminal_deferred")
        self.assertTrue(self.report["acceptance_boundary"]["queue_required"])
        self.assertFalse(self.report["acceptance_boundary"]["threshold_changed"])
        self.assertFalse(self.report["acceptance_boundary"]["unknowns_fixed"])

    def test_cli_negative_missing_root_fails_closed(self) -> None:
        command = [
            sys.executable,
            "-B",
            str(ROOT / "tools" / "up2_04_physics_closure_diagnostic.py"),
            "--root",
            str(ROOT / "this-input-does-not-exist"),
            "--strict",
        ]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn("diagnostic failed closed", result.stderr)

    def test_negative_row_schema_scale_and_nonfinite_inputs_fail_closed(self) -> None:
        with self.assertRaises(ValueError):
            diagnostic._block_stats([{"row": "1", "block": "x", "residual": "1", "declared_scale": "-1"}])
        with self.assertRaises(ValueError):
            diagnostic._block_stats([{"row": "1", "block": "x", "residual": "nan", "declared_scale": "1"}])
        with self.assertRaises(ValueError):
            diagnostic._block_stats([{"row": "1", "block": "x", "residual": "1"}])

    def test_negative_non_strict_solver_attempt_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "solver_attempts.json"
            path.write_text(json.dumps({
                "attempt_count": 1,
                "accepted_update_count": 1,
                "attempts": [{
                    "accepted": True,
                    "progress_classification": "accepted_strict_decrease",
                    "strict_objective_decrease": False,
                    "scaled_state_change": True,
                    "accepted_alpha": 1.0,
                    "objective_before": 1.0,
                    "objective_after": 0.5,
                }],
                "last_attempt": {},
            }), encoding="utf-8")
            with self.assertRaises(ValueError):
                diagnostic._solver_summary(path)

    def test_negative_exit_zero_without_iterations_fails_closed(self) -> None:
        for iterations_contents in (None, "iteration,scaled_max\n", "iteration,scaled_max\n1,2e-6\n", "iteration,scaled_max\n1,nan\n"):
            with self.subTest(iterations_contents=iterations_contents):
                with tempfile.TemporaryDirectory() as directory:
                    case_dir = pathlib.Path(directory) / "case"
                    physics = case_dir / "physics" / "synthetic"
                    physics.mkdir(parents=True)
                    (physics / "residual_rows.csv").write_text("row,block,residual,declared_scale\n1,x,0,1\n", encoding="utf-8")
                    (physics / "full_jacobian.csv").write_text("row,column,value\n1,1,1\n", encoding="utf-8")
                    (physics / "solver_attempts.json").write_text(json.dumps({"attempt_count": 0, "accepted_update_count": 0, "attempts": [], "last_attempt": {}}), encoding="utf-8")
                    (physics / "solver.exitcode").write_text("0\n", encoding="utf-8")
                    if iterations_contents is not None:
                        (physics / "iterations.csv").write_text(iterations_contents, encoding="utf-8")
                    with self.assertRaises((FileNotFoundError, ValueError)):
                        diagnostic.summarize_case(case_dir, "synthetic")

    def test_negative_objective_decrease_inconsistency_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = pathlib.Path(directory) / "solver_attempts.json"
            path.write_text(json.dumps({
                "attempt_count": 1,
                "accepted_update_count": 1,
                "attempts": [{
                    "accepted": True,
                    "progress_classification": "accepted_strict_decrease",
                    "strict_objective_decrease": True,
                    "scaled_state_change": True,
                    "accepted_alpha": 1.0,
                    "objective_before": 1.0,
                    "objective_after": 0.5,
                    "objective_decrease": 0.51,
                }],
                "last_attempt": {},
            }), encoding="utf-8")
            with self.assertRaises(ValueError):
                diagnostic._solver_summary(path)

    def test_negative_physical_case_registration_mismatch_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            run_dir = pathlib.Path(directory) / "run"
            (run_dir / "physics" / "expected").mkdir(parents=True)
            (run_dir / "physics" / "extra_unregistered").mkdir()
            manifest = {"artifacts": [{"path": str(run_dir / "physics" / "expected" / "residual_rows.csv")}]}
            with self.assertRaises(ValueError):
                diagnostic._physical_artifact_inventory(run_dir, manifest, ("expected",), "synthetic")

    def test_negative_n1_perturbation_metadata_mismatch_fails_closed(self) -> None:
        source = {
            "observed_orders": [
                {"perturbation_index": 1, "observed_order": 1.0},
                {"perturbation_index": 2, "observed_order": 1.0},
            ]
        }
        with self.assertRaises(ValueError):
            diagnostic._validate_n1_perturbation_set(source, {1, 3})


if __name__ == "__main__":
    unittest.main(verbosity=2)
