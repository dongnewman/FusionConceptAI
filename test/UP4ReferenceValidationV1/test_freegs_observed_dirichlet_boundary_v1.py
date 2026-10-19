from __future__ import annotations

import copy
import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from typing import Any

from tools.up4_reference_validation.freegs_observed_dirichlet_boundary_v1 import (
    PINNED_FREEGS_SOURCE_SHA256,
    is_pinned_observed_dirichlet_callback,
    temporary_observed_dirichlet_semantics,
    verify_pinned_freegs_source_tree,
    verify_pinned_freegs_solve_api,
    verify_pinned_freegs_sources,
)
from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v3 import (
    BASELINE_REVISION,
    BASELINE_RUNNER,
    PINNED_BASELINE_SHA256,
    VERSIONED_REVISION,
    install_versioned_input_validation,
    run_baseline,
    verify_baseline_hash,
)


def fixedBoundary(_eq: Any, _jtor: Any, psi: Any) -> None:
    psi[0][0] = 0.0


def freeBoundary(_eq: Any, _jtor: Any, _psi: Any) -> None:
    return None


def unrelated_custom_boundary(_eq: Any, _jtor: Any, _psi: Any) -> None:
    return None


def observed_callback_from_pinned_runner():
    source = (
        "def solve():\n"
        "    def observed_dirichlet_boundary(_eq, _jtor, psi):\n"
        "        psi[0][0] = psi[0][0]\n"
        "    return observed_dirichlet_boundary\n"
    )
    namespace: dict[str, Any] = {}
    exec(compile(source, str(BASELINE_RUNNER.resolve()), "exec"), namespace)
    return namespace["solve"]()


class FakeEquilibrium:
    def __init__(
        self,
        boundary: Any,
        psi: list[list[float]],
        *,
        xpoint: bool = False,
    ) -> None:
        self._applyBoundary = boundary
        self._psi = copy.deepcopy(psi)
        self._has_xpoint = xpoint
        self.psi_bndry = 12.5
        self.mask: Any = None

    def psi(self):
        return self._psi

    def _updateBoundaryPsi(self, psi=None):
        values = self.psi() if psi is None else psi
        if self._has_xpoint:
            self.psi_bndry = 8.25
            self.mask = "xpoint-mask"
        elif self._applyBoundary is fixedBoundary:
            self.psi_bndry = float(values[0][0])
            self.mask = None
        else:
            # Mirrors FreeGS 0.8.2's non-sentinel custom-callback no-X-point branch.
            self.psi_bndry = None
            self.mask = None
        return "base-update-result"


class FakeSolverOwner:
    def __init__(self, *, fail_after_update: bool = False) -> None:
        self.fail_after_update = fail_after_update

    def solve(self, eq):
        result = eq._updateBoundaryPsi()
        if self.fail_after_update:
            raise RuntimeError("injected solver failure")
        return result


class ObservedDirichletBoundaryTests(unittest.TestCase):
    def test_baseline_runner_hash_is_frozen_and_mismatch_fails_closed(self):
        self.assertEqual(verify_baseline_hash(), PINNED_BASELINE_SHA256)
        with tempfile.TemporaryDirectory() as temp_dir:
            wrong_baseline = Path(temp_dir) / "wrong-runner.py"
            wrong_baseline.write_text("not the pinned runner", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "runner hash mismatch"):
                verify_baseline_hash(wrong_baseline)

    def test_freegs_source_hashes_and_api_fail_closed(self):
        self.assertEqual(set(PINNED_FREEGS_SOURCE_SHA256), {
            "equilibrium.py", "picard.py", "boundary.py", "jtor.py"
        })
        with tempfile.TemporaryDirectory() as temp_dir:
            source_root = Path(temp_dir)
            for filename in PINNED_FREEGS_SOURCE_SHA256:
                (source_root / filename).write_text("unpinned", encoding="utf-8")
            with self.assertRaisesRegex(RuntimeError, "source hash mismatch"):
                verify_pinned_freegs_source_tree(source_root)
        with self.assertRaisesRegex(RuntimeError, "Equilibrium module is unavailable"):
            verify_pinned_freegs_sources(FakeEquilibrium)

    def test_freegs_public_solve_identity_and_signature_are_pinned(self):
        source = (
            "def solve(eq, profiles, constrain=None, rtol=1e-3, atol=1e-10, "
            "blend=0.0, show=False, axis=None, pause=0.0001, psi_bndry=None, "
            "maxits=50, convergenceInfo=False, check_limited=False, "
            "wait_for_limited=False, limit_it=0):\n"
            "    return None\n"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            expected_file = Path(temp_dir) / "picard.py"
            namespace: dict[str, Any] = {}
            exec(compile(source, str(expected_file), "exec"), namespace)
            solve = namespace["solve"]
            package = SimpleNamespace(solve=solve)
            picard = SimpleNamespace(solve=solve)
            verify_pinned_freegs_solve_api(package, picard, temp_dir)

            package.solve = lambda *_args, **_kwargs: None
            with self.assertRaisesRegex(RuntimeError, "public solve API differs"):
                verify_pinned_freegs_solve_api(package, picard, temp_dir)

            wrong_signature = compile(
                "def solve(eq):\n    return eq\n",
                str(expected_file),
                "exec",
            )
            bad_namespace: dict[str, Any] = {}
            exec(wrong_signature, bad_namespace)
            package.solve = bad_namespace["solve"]
            picard.solve = bad_namespace["solve"]
            with self.assertRaisesRegex(RuntimeError, "signature differs"):
                verify_pinned_freegs_solve_api(package, picard, temp_dir)

    def test_v2_input_revision_is_scoped_and_output_revision_is_v3(self):
        namespace: dict[str, Any] = {"REVISION": BASELINE_REVISION}
        seen: list[str] = []
        controls = {
            "rtol": 1e-5,
            "atol": 1e-10,
            "max_iterations": 100,
            "blend": 0.0,
        }

        def validate_wrapper(value):
            seen.append(namespace["REVISION"])
            if value["revision"] != namespace["REVISION"]:
                raise ValueError("input revision mismatch")
            return value

        namespace["validate_wrapper"] = validate_wrapper
        install_versioned_input_validation(namespace)
        self.assertEqual(namespace["REVISION"], VERSIONED_REVISION)
        self.assertEqual(
            namespace["validate_wrapper"](
                {"revision": BASELINE_REVISION, "controls": controls}
            ),
            {"revision": BASELINE_REVISION, "controls": controls},
        )
        self.assertEqual(
            controls,
            {"rtol": 1e-5, "atol": 1e-10, "max_iterations": 100, "blend": 0.0},
        )
        self.assertEqual(seen, [BASELINE_REVISION])
        self.assertEqual(namespace["REVISION"], VERSIONED_REVISION)

    def test_wrong_v2_input_revision_fails_and_restores_v3_identity(self):
        namespace: dict[str, Any] = {"REVISION": BASELINE_REVISION}

        def validate_wrapper(value):
            if value["revision"] != namespace["REVISION"]:
                raise ValueError("input revision mismatch")

        namespace["validate_wrapper"] = validate_wrapper
        install_versioned_input_validation(namespace)
        with self.assertRaisesRegex(ValueError, "revision mismatch"):
            namespace["validate_wrapper"]({"revision": "wrong-revision"})
        self.assertEqual(namespace["REVISION"], VERSIONED_REVISION)

    def _equilibrium(self, callback, psi=None, *, xpoint=False):
        return FakeEquilibrium(
            callback,
            psi if psi is not None else [[0.25, 0.5], [0.75, 1.0]],
            xpoint=xpoint,
        )

    def test_only_current_solver_target_gets_finite_corner_proxy(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner()
        original_init = FakeEquilibrium.__init__
        edges = [[0.25, 0.5], [0.75, 1.0]]
        edge_hash_before = hashlib.sha256(
            json.dumps(edges, separators=(",", ":")).encode("utf-8")
        ).hexdigest()
        with temporary_observed_dirichlet_semantics(
            FakeEquilibrium,
            expected_runner_file=BASELINE_RUNNER,
            solver_owner=owner,
        ):
            diagnostic_eq = self._equilibrium(callback, edges)
            target_eq = self._equilibrium(callback, edges)
            self.assertEqual(diagnostic_eq._updateBoundaryPsi(), "base-update-result")
            self.assertIsNone(diagnostic_eq.psi_bndry)
            self.assertNotIn("_updateBoundaryPsi", diagnostic_eq.__dict__)

            self.assertEqual(owner.solve(target_eq), "base-update-result")
            self.assertEqual(target_eq.psi_bndry, 0.25)
            self.assertIsNone(target_eq.mask)
            self.assertIs(target_eq._applyBoundary, callback)
            self.assertEqual(target_eq.psi(), edges)
            edge_hash_after = hashlib.sha256(
                json.dumps(target_eq.psi(), separators=(",", ":")).encode("utf-8")
            ).hexdigest()
            self.assertEqual(edge_hash_after, edge_hash_before)
            self.assertEqual(diagnostic_eq.psi(), edges)
            self.assertNotIn("_updateBoundaryPsi", target_eq.__dict__)

        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertNotIn("solve", owner.__dict__)
        self.assertIs(owner.solve.__func__, FakeSolverOwner.solve)

    def test_transition_requires_prior_finite_boundary(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner()
        with temporary_observed_dirichlet_semantics(
            FakeEquilibrium,
            expected_runner_file=BASELINE_RUNNER,
            solver_owner=owner,
        ):
            eq = self._equilibrium(callback)
            eq.psi_bndry = None
            owner.solve(eq)
            self.assertIsNone(eq.psi_bndry)

    def test_nonfinite_prior_boundary_is_not_adapted(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner()
        for value in (float("nan"), float("inf"), "not-a-number"):
            with self.subTest(previous_boundary=value):
                with temporary_observed_dirichlet_semantics(
                    FakeEquilibrium,
                    expected_runner_file=BASELINE_RUNNER,
                    solver_owner=owner,
                ):
                    eq = self._equilibrium(callback)
                    eq.psi_bndry = value
                    owner.solve(eq)
                    self.assertIsNone(eq.psi_bndry)

    def test_native_fixed_free_and_unmarked_callbacks_remain_unadapted(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner()
        for boundary in (fixedBoundary, freeBoundary, unrelated_custom_boundary):
            with self.subTest(boundary=boundary.__name__):
                with temporary_observed_dirichlet_semantics(
                    FakeEquilibrium,
                    expected_runner_file=BASELINE_RUNNER,
                    solver_owner=owner,
                ):
                    eq = self._equilibrium(boundary)
                    owner.solve(eq)
                    self.assertNotIn("_updateBoundaryPsi", eq.__dict__)
                    if boundary is fixedBoundary:
                        self.assertEqual(eq.psi_bndry, 0.25)
                    else:
                        self.assertIsNone(eq.psi_bndry)

        self.assertTrue(is_pinned_observed_dirichlet_callback(callback, BASELINE_RUNNER))
        self.assertFalse(
            is_pinned_observed_dirichlet_callback(
                unrelated_custom_boundary, BASELINE_RUNNER
            )
        )

    def test_existing_xpoint_and_nonfinite_corner_are_not_overwritten(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner()
        with temporary_observed_dirichlet_semantics(
            FakeEquilibrium,
            expected_runner_file=BASELINE_RUNNER,
            solver_owner=owner,
        ):
            xpoint_eq = self._equilibrium(callback, xpoint=True)
            owner.solve(xpoint_eq)
            self.assertEqual(xpoint_eq.psi_bndry, 8.25)
            self.assertEqual(xpoint_eq.mask, "xpoint-mask")

            psi = [[float("nan"), 0.5], [0.75, 1.0]]
            finite_guard_eq = self._equilibrium(callback, psi)
            before = copy.deepcopy(finite_guard_eq.psi())
            owner.solve(finite_guard_eq)
            self.assertIsNone(finite_guard_eq.psi_bndry)
            self.assertEqual(finite_guard_eq.psi(), before)

    def test_class_solver_and_instance_method_restore_after_solver_exception(self):
        callback = observed_callback_from_pinned_runner()
        owner = FakeSolverOwner(fail_after_update=True)
        original_init = FakeEquilibrium.__init__
        eq = None
        with self.assertRaisesRegex(RuntimeError, "injected solver failure"):
            with temporary_observed_dirichlet_semantics(
                FakeEquilibrium,
                expected_runner_file=BASELINE_RUNNER,
                solver_owner=owner,
            ):
                eq = self._equilibrium(callback)
                with self.assertRaisesRegex(RuntimeError, "injected solver failure"):
                    owner.solve(eq)
                self.assertNotIn("_updateBoundaryPsi", eq.__dict__)
                raise RuntimeError("injected solver failure")
        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertNotIn("solve", owner.__dict__)
        self.assertIs(owner.solve.__func__, FakeSolverOwner.solve)
        self.assertNotIn("_updateBoundaryPsi", eq.__dict__)

    def test_delegate_preserves_argv_and_tags_versioned_result(self):
        original_init = FakeEquilibrium.__init__
        seen: dict[str, Any] = {}
        argv = [
            "--input", "frozen-input.json", "--source", "frozen-source.json",
            "--output", "v11/solver_output.json",
        ]

        def fake_loader(path: str, *, run_name: str):
            namespace: dict[str, Any] = {"REVISION": BASELINE_REVISION}
            self.assertEqual(Path(path), BASELINE_RUNNER)
            self.assertEqual(run_name, "_up4_reference_validation_v3_baseline")

            def fake_main(actual_argv):
                seen["argv"] = actual_argv
                seen["revision"] = namespace["REVISION"]
                seen["namespace"] = namespace
                seen["original_validator"] = original_validator
                return 0

            def fake_validate_wrapper(_value):
                return {}

            original_validator = fake_validate_wrapper
            namespace["main"] = fake_main
            namespace["validate_wrapper"] = fake_validate_wrapper
            return namespace

        self.assertEqual(
            run_baseline(
                argv,
                equilibrium_class=FakeEquilibrium,
                runner_loader=fake_loader,
            ),
            0,
        )
        self.assertEqual(seen["argv"], argv)
        self.assertEqual(seen["revision"], VERSIONED_REVISION)
        self.assertEqual(seen["namespace"]["REVISION"], BASELINE_REVISION)
        self.assertIs(
            seen["namespace"]["validate_wrapper"], seen["original_validator"]
        )
        self.assertIs(FakeEquilibrium.__init__, original_init)

    def test_delegate_restores_revision_and_validator_after_exception(self):
        observed: dict[str, Any] = {}

        def fake_loader(_path: str, *, run_name: str):
            namespace: dict[str, Any] = {"REVISION": BASELINE_REVISION}
            original_validator = lambda _value: {}

            def fake_main(_argv):
                observed["revision_during_run"] = namespace["REVISION"]
                observed["namespace"] = namespace
                observed["original_validator"] = original_validator
                raise RuntimeError("delegate failure")

            namespace["main"] = fake_main
            namespace["validate_wrapper"] = original_validator
            return namespace

        with self.assertRaisesRegex(RuntimeError, "delegate failure"):
            run_baseline(
                ["--input", "unused", "--source", "unused", "--output", "unused"],
                equilibrium_class=FakeEquilibrium,
                runner_loader=fake_loader,
            )
        self.assertEqual(observed["revision_during_run"], VERSIONED_REVISION)
        self.assertEqual(observed["namespace"]["REVISION"], BASELINE_REVISION)
        self.assertIs(
            observed["namespace"]["validate_wrapper"],
            observed["original_validator"],
        )


if __name__ == "__main__":
    unittest.main()
