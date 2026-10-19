from __future__ import annotations

import hashlib
import json
import sys
import tempfile
import types
import unittest
from contextvars import ContextVar
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.up4_reference_validation.freegs_fixed_box_picard_v1 import (
    FixedBoxBoundaryDriftError,
    FixedBoxNumericalStateError,
    FixedBoxPicardNonconvergence,
    FixedBoxTerminalTopologyUnsupported,
    FixedBoxTopologyObservationUnavailable,
    solve_fixed_observed_box,
)
from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v8 import (
    _classify_policy_failure,
    make_freegs_policy_proxy,
    temporary_v17_runner_bindings,
)
from tools.up4_reference_validation.verify_freegs_v17_protocol_candidate import (
    validate_mandatory_sidecars,
)


def frozen_grid() -> np.ndarray:
    return np.array(
        [
            [0.0, 0.1, 0.2],
            [0.3, 0.5, 0.4],
            [0.6, 0.7, 0.8],
        ],
        dtype=np.float64,
    )


def marked_callback(edges: dict[str, np.ndarray]):
    def observed_dirichlet_boundary(_eq, _jtor, _psi):
        # Keep the edge mapping in a closure like the pinned adapter callback.
        return edges["r_min"][0] if False else None

    return observed_dirichlet_boundary


def observer_call(x_before: int | None, x_after: int | None) -> dict:
    if x_before is None or x_after is None:
        boundary_events = [{"scope": "equilibrium_boundary_update"}]
    else:
        boundary_events = [
            {"scope": "equilibrium_boundary_update", "x_points": [None] * x_before},
            {"scope": "profile_jtor", "x_points": []},
            {"scope": "equilibrium_boundary_update", "x_points": [None] * x_after},
        ]
    return {"critical_calls": boundary_events}


class FakeObserver:
    def __init__(self):
        self.calls: list[dict] = []


class FakeEq:
    def __init__(self, sequence, *, limited=False, signed_zero=False):
        self._psi = frozen_grid()
        matrix = self._psi
        edges = {
            "r_min": matrix[0, :].copy(),
            "r_max": matrix[-1, :].copy(),
            "z_min": matrix[:, 0].copy(),
            "z_max": matrix[:, -1].copy(),
        }
        self._applyBoundary = marked_callback(edges)
        self.sequence = list(sequence)
        self.observer = FakeObserver()
        self.is_limited = limited
        self.check_limited = None
        self.solve_calls: list[dict] = []
        self.signed_zero = signed_zero
        self._psi_bndry_accesses = 0

    @property
    def psi_bndry(self):
        self._psi_bndry_accesses += 1
        raise AssertionError("v17 policy must not read eq.psi_bndry")

    @psi_bndry.setter
    def psi_bndry(self, _value):
        self._psi_bndry_accesses += 1
        raise AssertionError("v17 policy must not write eq.psi_bndry")

    def psi(self):
        return self._psi.copy()

    def solve(self, profiles, *, psi, psi_bndry):
        item = self.sequence.pop(0)
        self.solve_calls.append({"profiles": profiles, "psi_bndry": psi_bndry})
        self.check_limited = False
        if self.signed_zero and not self.solve_calls[:-1]:
            self._psi[0, 0] = -0.0
        elif "edge_value" in item:
            self._psi[0, 1] = item["edge_value"]
        self._psi[1, 1] = item["center"]
        self.is_limited = bool(item.get("limited", False))
        self.observer.calls.append(observer_call(item.get("x_before", 0), item.get("x_after", 0)))
        return None


class FixedBoxPicardPolicyTests(unittest.TestCase):
    def run_policy(self, eq: FakeEq, **kwargs):
        receipt: dict = {}
        result = solve_fixed_observed_box(
            eq,
            profiles=object(),
            rtol=1e-5,
            atol=1e-10,
            blend=0.0,
            psi_bndry=-0.030191900208592415,
            maxits=100,
            convergenceInfo=True,
            check_limited=False,
            wait_for_limited=False,
            limit_it=0,
            observer=eq.observer,
            policy_receipt=receipt,
            **kwargs,
        )
        return result, receipt

    def test_transient_xpoints_4_to_2_to_0_are_recorded_terminal_empty_passes(self):
        eq = FakeEq(
            [
                {"center": 0.4, "x_before": 4, "x_after": 2},
                {"center": 0.4, "x_before": 2, "x_after": 0},
            ]
        )
        (max_change, rel_change), receipt = self.run_policy(eq)
        self.assertEqual(len(eq.solve_calls), 2)
        self.assertEqual(receipt["status"], "test_only_fixed_box_policy_converged")
        self.assertEqual(receipt["controls"], {"rtol": 1e-5, "atol": 1e-10, "maxits": 100, "blend": 0.0})
        self.assertEqual([x["xpoints_before_solve"] for x in receipt["iteration_history"]], [4, 2])
        self.assertEqual([x["xpoints_after_solve"] for x in receipt["iteration_history"]], [2, 0])
        self.assertEqual(receipt["observed_xpoint_count_sequence"], [4, 2, 0])
        self.assertEqual(
            receipt["topology_transitions"],
            [
                {"policy_iteration_index": 1, "xpoints_before_solve": 4, "xpoints_after_solve": 2},
                {"policy_iteration_index": 2, "xpoints_before_solve": 2, "xpoints_after_solve": 0},
            ],
        )
        self.assertEqual(receipt["terminal_topology"]["xpoint_count"], 0)
        self.assertEqual(len(max_change), 2)
        self.assertEqual(float(max_change[-1]), 0.0)
        self.assertEqual(float(rel_change[-1]), 0.0)
        self.assertEqual(eq._psi_bndry_accesses, 0)
        self.assertFalse(receipt["corner_proxy_written"])
        self.assertFalse(receipt["physics_credit"])
        self.assertFalse(receipt["inverse_credit"])

    def test_terminal_xpoint_fails_closed_after_psi_gate(self):
        eq = FakeEq(
            [
                {"center": 0.4, "x_before": 2, "x_after": 1},
                {"center": 0.4, "x_before": 1, "x_after": 1},
            ]
        )
        receipt: dict = {}
        with self.assertRaises(FixedBoxTerminalTopologyUnsupported):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )
        self.assertEqual(receipt["status"], "unsupported_terminal_topology")
        self.assertEqual(receipt["terminal_topology"]["xpoint_count"], 1)
        self.assertEqual(len(eq.solve_calls), 2)

    def test_terminal_limited_state_fails_closed(self):
        eq = FakeEq(
            [
                {"center": 0.4, "x_before": 0, "x_after": 0},
                {"center": 0.4, "x_before": 0, "x_after": 0, "limited": True},
            ]
        )
        receipt: dict = {}
        with self.assertRaises(FixedBoxTerminalTopologyUnsupported):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )
        self.assertTrue(receipt["terminal_topology"]["is_limited"])

    def test_signed_zero_edge_drift_fails_even_when_array_equal_is_true(self):
        eq = FakeEq([{"center": 0.5, "x_before": 0, "x_after": 0}], signed_zero=True)
        self.assertTrue(np.array_equal(eq._psi[0, :], frozen_grid()[0, :]))
        receipt: dict = {}
        with self.assertRaises(FixedBoxBoundaryDriftError):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )
        self.assertEqual(len(eq.solve_calls), 1)

    def test_any_nonzero_edge_delta_fails_without_projection(self):
        eq = FakeEq([{"center": 0.5, "edge_value": 0.20000000000000004, "x_before": 0, "x_after": 0}])
        receipt: dict = {}
        with self.assertRaises(FixedBoxBoundaryDriftError):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )
        self.assertEqual(eq._psi[0, 1], 0.20000000000000004)

    def test_observer_missing_or_malformed_fails_closed(self):
        eq = FakeEq([{"center": 0.4, "x_before": None, "x_after": None}])
        receipt: dict = {}
        with self.assertRaises(FixedBoxTopologyObservationUnavailable):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )

    def test_v17_policy_maxits_counter_semantics_are_measured_not_inferred(self):
        seq = [
            {"center": 0.1 if i % 2 else 0.9, "x_before": 0, "x_after": 0}
            for i in range(3)
        ]
        eq = FakeEq(seq)
        receipt: dict = {}
        with self.assertRaises(FixedBoxPicardNonconvergence):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=1, convergenceInfo=True,
                observer=eq.observer, policy_receipt=receipt,
            )
        self.assertEqual(receipt["controls"]["maxits"], 1)
        self.assertEqual(receipt["policy_iteration_count"], 2)
        self.assertEqual(receipt["observed_equilibrium_solve_calls"], 2)

    def test_noninteger_maxits_is_rejected_before_solving(self):
        eq = FakeEq([{"center": 0.4, "x_before": 0, "x_after": 0}])
        with self.assertRaises(ValueError):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=1.5, convergenceInfo=True,
                observer=eq.observer, policy_receipt={},
            )
        self.assertEqual(eq.solve_calls, [])

    def test_nonfinite_iterate_fails_without_boundary_repair(self):
        eq = FakeEq([{"center": 0.4, "x_before": 0, "x_after": 0}])
        original_solve = eq.solve

        def return_nonfinite(*args, **kwargs):
            original_solve(*args, **kwargs)
            eq._psi[1, 1] = np.inf

        eq.solve = return_nonfinite
        with self.assertRaises(FixedBoxNumericalStateError):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt={},
            )
        self.assertTrue(np.isinf(eq._psi[1, 1]))
        self.assertEqual(eq._psi_bndry_accesses, 0)

    def test_frozen_edge_corner_incompatibility_fails_before_solve(self):
        eq = FakeEq([{"center": 0.4, "x_before": 0, "x_after": 0}])
        edges = next(
            cell.cell_contents for cell in eq._applyBoundary.__closure__
            if isinstance(cell.cell_contents, dict)
        )
        edges["z_min"][0] = -0.0
        with self.assertRaises(FixedBoxBoundaryDriftError):
            solve_fixed_observed_box(
                eq, object(), rtol=1e-5, atol=1e-10, blend=0.0,
                psi_bndry=None, maxits=100, convergenceInfo=True,
                observer=eq.observer, policy_receipt={},
            )
        self.assertEqual(eq.solve_calls, [])

    def test_freegs_proxy_does_not_mutate_imported_module(self):
        original = lambda *_a, **_kw: "native"
        package = types.SimpleNamespace(solve=original, Equilibrium=object)
        policy = lambda *_a, **_kw: "policy"
        proxy = make_freegs_policy_proxy(package, policy)
        self.assertIsNot(proxy, package)
        self.assertIs(package.solve, original)
        self.assertIs(proxy.solve, policy)
        self.assertIs(proxy.Equilibrium, package.Equilibrium)

    def test_runner_binding_context_restores_and_marks_v17_output(self):
        module = types.SimpleNamespace(solve=lambda: None, marker=object())
        proxy = make_freegs_policy_proxy(module, lambda: None)
        observer_context: ContextVar = ContextVar("test_v17_observer", default=None)
        policy_receipt = {"status": "test_only_fixed_box_policy_converged", "iteration_history": []}
        receipt: dict = {}
        result_holder: list[dict] = []

        def environment_manifest():
            return {}, module, np, object()

        class Observer:
            pass

        def classify(exc, state):
            return type(exc).__name__, 5

        def write_result(path, result):
            result_holder.append(result)
            return ("written", len(result))

        def canonical_hash(value):
            return hashlib.sha256(json.dumps(value, sort_keys=True, default=str).encode()).hexdigest()

        globals_map = {
            "environment_manifest": environment_manifest,
            "EquilibriumSolveObserver": Observer,
            "classify_failure": classify,
            "write_result": write_result,
            "canonical_hash": canonical_hash,
        }
        originals = {name: globals_map[name] for name in (
            "environment_manifest", "EquilibriumSolveObserver", "classify_failure", "write_result"
        )}
        module_dict_before = dict(module.__dict__)
        original_module_solve = module.solve
        with temporary_v17_runner_bindings(
            globals_map, module, proxy, observer_context, policy_receipt, receipt
        ):
            env, selected, _, _ = globals_map["environment_manifest"]()
            self.assertIs(selected, proxy)
            observer = globals_map["EquilibriumSolveObserver"]()
            self.assertIs(observer_context.get(), observer)
            status = globals_map["classify_failure"](FixedBoxPicardNonconvergence("x"), {})
            self.assertEqual(status, ("numerical_fail_nonconvergence", 4))
            result = {
                "status": "conditional_fixed_boundary_solver_converged_residual_measured",
                "result_sha256": "old",
                "numerical_assessment": {},
            }
            globals_map["write_result"]("ignored", result)
            self.assertEqual(result["status"], "test_only_fixed_observed_box_dirichlet_policy_converged_residual_measured")
            self.assertFalse(result["solver_algorithm"]["native_freegs_picard_called"])
            self.assertEqual(result_holder[-1]["result_sha256"], canonical_hash({k:v for k,v in result.items() if k!="result_sha256"}))
        self.assertTrue(receipt["restored_exact"])
        self.assertTrue(receipt["freegs_module_object_unchanged"])
        for name, original in originals.items():
            self.assertIs(globals_map[name], original)
        self.assertIs(module.solve, original_module_solve)
        self.assertEqual(set(module.__dict__), set(module_dict_before))
        self.assertTrue(all(module.__dict__[key] is value for key, value in module_dict_before.items()))
        self.assertIsNone(observer_context.get())

    def test_runner_binding_context_restores_after_body_exception(self):
        module = types.SimpleNamespace(solve=lambda: "native", marker=object())
        proxy = make_freegs_policy_proxy(module, lambda: "v17")
        observer_context: ContextVar = ContextVar("test_v17_exception_observer", default=None)
        receipt: dict = {}

        def environment_manifest():
            return {}, module, np, object()

        class Observer:
            pass

        def classify(exc, state):
            return "program_exception", 5

        def write_result(path, result):
            return None

        globals_map = {
            "environment_manifest": environment_manifest,
            "EquilibriumSolveObserver": Observer,
            "classify_failure": classify,
            "write_result": write_result,
        }
        originals = dict(globals_map)
        with self.assertRaisesRegex(RuntimeError, "synthetic v17 failure"):
            with temporary_v17_runner_bindings(
                globals_map, module, proxy, observer_context, {}, receipt
            ):
                observer = globals_map["EquilibriumSolveObserver"]()
                self.assertIs(observer_context.get(), observer)
                raise RuntimeError("synthetic v17 failure")
        self.assertTrue(receipt["context_entered"])
        self.assertTrue(receipt["restore_attempted"])
        self.assertTrue(receipt["restored_exact"])
        self.assertTrue(receipt["freegs_module_object_unchanged"])
        for key, original in originals.items():
            self.assertIs(globals_map[key], original)
        self.assertIsNone(observer_context.get())

    def test_v17_sidecar_verifier_binds_all_required_files_to_new_leaf(self):
        with tempfile.TemporaryDirectory() as raw:
            leaf = Path(raw) / "archive" / "new-freegs-run"
            output = leaf / "solver_output.json"
            sidecars = {
                "adapter_receipt": str(leaf / "freegs_adapter_receipt_v17.json"),
                "execution": str(leaf / "execution.json"),
                "solver_output": str(output),
                "stdout": str(leaf / "stdout.raw"),
                "stderr": str(leaf / "stderr.raw"),
                "storage_rule": "raw run/exit/hash/review evidence only under docs/implementation/.../archive/**",
            }
            accepted = validate_mandatory_sidecars(sidecars, output)
            self.assertEqual(set(accepted), {"adapter_receipt", "execution", "solver_output", "stdout", "stderr"})
            for key in ("adapter_receipt", "execution", "solver_output", "stdout", "stderr"):
                tampered = dict(sidecars)
                tampered[key] = str(leaf.parent / f"retargeted-{key}.json")
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    validate_mandatory_sidecars(tampered, output)

    def test_v17_sidecar_verifier_rejects_output_outside_archive(self):
        with tempfile.TemporaryDirectory() as raw:
            leaf = Path(raw) / "unarchived"
            output = leaf / "solver_output.json"
            sidecars = {
                "adapter_receipt": str(leaf / "freegs_adapter_receipt_v17.json"),
                "execution": str(leaf / "execution.json"),
                "solver_output": str(output),
                "stdout": str(leaf / "stdout.raw"),
                "stderr": str(leaf / "stderr.raw"),
                "storage_rule": "raw run/exit/hash/review evidence only under docs/implementation/.../archive/**",
            }
            with self.assertRaisesRegex(RuntimeError, "outside archive"):
                validate_mandatory_sidecars(sidecars, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
