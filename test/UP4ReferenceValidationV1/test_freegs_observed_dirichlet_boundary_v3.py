from __future__ import annotations

import copy
import json
import runpy
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import numpy as np


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(REPOSITORY_ROOT))
FROZEN_V10_INPUT = Path(
    "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_r1_20260922/"
    "native_axisymmetric_forward_v2/actual_run_r10/julia_closure/validate_artifacts/"
    "solver_input.canonical.json"
)

from tools.up4_reference_validation.freegs_observed_dirichlet_boundary_v3 import (
    MAX_PREPROJECT_DELTA_WB_PER_RAD,
    temporary_observed_dirichlet_projection,
)
from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v5 import (
    BASELINE_REVISION,
    BASELINE_RUNNER,
    VERSIONED_REVISION,
    versioned_v2_main_globals,
    run_baseline,
)
from tools.up4_reference_validation.verify_freegs_v5_protocol_candidate import (
    validate_mandatory_sidecar_binding,
)


def make_edges(shape: tuple[int, int] = (5, 6)) -> dict[str, np.ndarray]:
    r_count, z_count = shape
    psi = np.arange(r_count * z_count, dtype=np.float64).reshape(shape) / 17.0
    return {
        "r_min": psi[0, :].copy(),
        "r_max": psi[-1, :].copy(),
        "z_min": psi[:, 0].copy(),
        "z_max": psi[:, -1].copy(),
    }


def observed_callback(edges: dict[str, np.ndarray], filename: str) -> object:
    source = """\
def solve(boundary_edges):
    def observed_dirichlet_boundary(_eq, _jtor, psi):
        psi[0, :] = boundary_edges['r_min']
        psi[-1, :] = boundary_edges['r_max']
        psi[:, 0] = boundary_edges['z_min']
        psi[:, -1] = boundary_edges['z_max']
    return observed_dirichlet_boundary
"""
    namespace: dict[str, object] = {}
    exec(compile(source, filename, "exec"), namespace)
    return namespace["solve"](edges)  # type: ignore[index,operator]


class FakeEquilibrium:
    def __init__(self, callback: object, psi: np.ndarray, mode: str = "none") -> None:
        self._applyBoundary = callback
        self.plasma_psi = psi.copy()
        self.psi_bndry: float | None = 1.25
        self.mode = mode
        self.diagnostic_eq_metadata = {"marker": "must remain unchanged"}
        self.spline_update_count = 0
        self.critical_update_count = 0

    def psi(self) -> np.ndarray:
        return self.plasma_psi

    def _updateBoundaryPsi(self, psi: np.ndarray | None = None) -> None:
        if self.mode == "none":
            self.psi_bndry = None
        elif self.mode == "xpoint":
            self.psi_bndry = 0.75

    def _updatePlasmaPsi(self, plasma_psi: np.ndarray) -> None:
        self.plasma_psi = plasma_psi
        self.spline_update_count += 1
        self._updateBoundaryPsi()
        self.critical_update_count += 1


def run_fake_solve(
    *,
    callback: object,
    edges: dict[str, np.ndarray],
    delta: float = 5.0e-13,
    mode: str = "none",
    interior_delta: float = 0.0,
    raise_after_update: bool = False,
) -> tuple[FakeEquilibrium, dict[str, object], type, object]:
    psi = np.full((len(edges["z_min"]), len(edges["r_min"])), 0.5, dtype=np.float64)
    psi[0, :] = edges["r_min"]
    psi[-1, :] = edges["r_max"]
    psi[:, 0] = edges["z_min"]
    psi[:, -1] = edges["z_max"]
    owner = SimpleNamespace()
    eq_holder: list[FakeEquilibrium] = []

    def solve(eq: FakeEquilibrium, *args: object, **kwargs: object) -> str:
        eq_holder.append(eq)
        eq._updateBoundaryPsi(eq.psi())
        eq._applyBoundary(eq, np.zeros_like(eq.psi()), eq.psi())  # type: ignore[operator]
        plasma_psi = eq.psi().copy()
        plasma_psi[0, 1] += delta
        plasma_psi[1, 1] += interior_delta
        eq._updatePlasmaPsi(plasma_psi)
        if raise_after_update:
            raise RuntimeError("solver failure after projected update")
        return "returned"

    owner.solve = solve
    original_init = FakeEquilibrium.__init__
    original_solve = owner.solve
    receipt: dict[str, object] = {}
    filename = str(Path(tempfile.gettempdir()) / "pinned_v2_runner.py")
    with temporary_observed_dirichlet_projection(
        FakeEquilibrium,
        filename,
        solver_owner=owner,
        receipt=receipt,
    ):
        eq = FakeEquilibrium(callback, psi, mode=mode)
        if raise_after_update:
            try:
                owner.solve(eq)
            except RuntimeError as exc:
                assert str(exc) == "solver failure after projected update"
            else:
                raise AssertionError("expected fake solver exception after projected update")
        else:
            result = owner.solve(eq)
            assert result == "returned"
    assert FakeEquilibrium.__init__ is original_init
    assert owner.solve is original_solve
    assert eq._applyBoundary is callback
    assert "_updateBoundaryPsi" not in eq.__dict__
    assert "_updatePlasmaPsi" not in eq.__dict__
    return eq, receipt, FakeEquilibrium, original_solve


class ObservedBoundaryProjectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.edges = make_edges()
        self.runner_file = str(Path(tempfile.gettempdir()) / "pinned_v2_runner.py")
        self.callback = observed_callback(self.edges, self.runner_file)

    def test_projection_is_before_original_update_and_preserves_interior(self) -> None:
        frozen_edges = {key: value.copy() for key, value in self.edges.items()}
        eq, receipt, _, _ = run_fake_solve(callback=self.callback, edges=self.edges)
        event = receipt["plasma_psi_projection_events"][0]  # type: ignore[index]
        self.assertTrue(event["projection_applied"])  # type: ignore[index]
        self.assertTrue(event["interior_unchanged"])  # type: ignore[index]
        self.assertEqual(event["interior_sha256_before"], event["interior_sha256_after"])  # type: ignore[index]
        self.assertTrue(event["original_update_called"])  # type: ignore[index]
        self.assertTrue(all(x["exact"] for x in event["postprojection_edges"].values()))  # type: ignore[index]
        self.assertEqual(eq.spline_update_count, 1)
        self.assertEqual(eq.critical_update_count, 1)
        self.assertEqual(receipt["boundary_callback_events"][0]["callback_identity_exact"], True)  # type: ignore[index]
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]
        self.assertEqual(eq.diagnostic_eq_metadata, {"marker": "must remain unchanged"})
        for key, value in frozen_edges.items():
            np.testing.assert_array_equal(self.edges[key], value)

    def test_solver_exception_after_projection_restores_hooks_and_metadata(self) -> None:
        eq, receipt, _, _ = run_fake_solve(
            callback=self.callback,
            edges=self.edges,
            raise_after_update=True,
        )
        event = receipt["plasma_psi_projection_events"][0]  # type: ignore[index]
        self.assertTrue(event["projection_applied"])  # type: ignore[index]
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]
        self.assertEqual(eq.diagnostic_eq_metadata, {"marker": "must remain unchanged"})
        self.assertTrue(all(item["exact"] for item in event["final_eq_edges"].values()))  # type: ignore[index]

    def test_corner_diagnostic_requires_finite_to_none_and_never_changes_solver_scalar(self) -> None:
        eq, receipt, _, _ = run_fake_solve(callback=self.callback, edges=self.edges)
        events = receipt["boundary_scalar_events"]  # type: ignore[index]
        self.assertGreaterEqual(len(events), 1)
        self.assertTrue(all(event["solver_psi_bndry_mutated"] is False for event in events))
        self.assertTrue(all(event["solver_psi_bndry_write_attempted"] is False for event in events))
        diagnostic = receipt["boundary_scalar_events"][0]  # type: ignore[index]
        self.assertEqual(diagnostic["previous_psi_bndry"], 1.25)
        self.assertIsNone(diagnostic["native_post_update_psi_bndry"])
        self.assertEqual(diagnostic["observed_box_corner_diagnostic"], float(self.edges["r_min"][0]))
        self.assertEqual(diagnostic["diagnostic_action"], "recorded_observed_box_corner_read_only")
        self.assertFalse(diagnostic["solver_psi_bndry_mutated"])
        self.assertIsNone(diagnostic["final_psi_bndry_after_adapter"])
        self.assertIsNone(eq.psi_bndry)
        self.assertEqual(diagnostic["picard_stop_effect"], "native_eq_psi_bndry_value_preserved")
        self.assertIn("read-only observed-box corner diagnostic", receipt["target"]["boundary_scalar_label"])  # type: ignore[index]
        stop = receipt["target"]["picard_stop_semantics"]  # type: ignore[index]
        self.assertFalse(stop["solver_psi_bndry_mutated"])
        self.assertEqual(stop["picard_stop_behavior"], "native_eq_psi_bndry_value_preserved")
        self.assertFalse(stop["diagnostic_corner_used_by_picard"])
        self.assertFalse(stop["physics_credit"])

    def test_existing_xpoint_keeps_native_boundary_and_skips_corner_diagnostic(self) -> None:
        eq, receipt, _, _ = run_fake_solve(
            callback=self.callback, edges=self.edges, mode="xpoint"
        )
        self.assertTrue(receipt["plasma_psi_projection_events"][0]["projection_applied"])  # type: ignore[index]
        self.assertTrue(
            all(event["diagnostic_action"] == "skipped" for event in receipt["boundary_scalar_events"])  # type: ignore[index]
        )
        self.assertEqual(
            receipt["boundary_scalar_events"][0]["diagnostic_skip_reason"],  # type: ignore[index]
            "native_post_update_boundary_not_none",
        )
        self.assertEqual(eq.psi_bndry, 0.75)

    def test_unmarked_fixed_free_and_other_callbacks_are_not_registered(self) -> None:
        for name in ("fixedBoundary", "freeBoundary", "other_callback"):
            with self.subTest(name=name):
                def unmarked(_eq: object, _jtor: object, _psi: object) -> None:
                    return None

                unmarked.__name__ = name
                eq, receipt, _, _ = run_fake_solve(
                    callback=unmarked,
                    edges=self.edges,
                    delta=0.0,
                )
                self.assertIsNone(receipt["target"])
                self.assertEqual(receipt["plasma_psi_projection_events"], [])
                self.assertEqual(eq._applyBoundary, unmarked)

    def test_roundoff_cap_rejects_material_drift_before_update(self) -> None:
        psi = np.full((len(self.edges["z_min"]), len(self.edges["r_min"])), 0.5)
        for key, edge in (("r_min", psi[0, :]), ("r_max", psi[-1, :]),
                          ("z_min", psi[:, 0]), ("z_max", psi[:, -1])):
            edge[:] = self.edges[key]
        owner = SimpleNamespace()
        holder: list[FakeEquilibrium] = []

        def solve(eq: FakeEquilibrium) -> None:
            holder.append(eq)
            out = eq.psi().copy()
            out[0, 1] += MAX_PREPROJECT_DELTA_WB_PER_RAD * 1.1
            eq._updatePlasmaPsi(out)

        owner.solve = solve
        original_init = FakeEquilibrium.__init__
        original_solve = owner.solve
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_projection(
            FakeEquilibrium, self.runner_file, solver_owner=owner, receipt=receipt
        ):
            eq = FakeEquilibrium(self.callback, psi)
            with self.assertRaisesRegex(RuntimeError, "exceeds frozen roundoff"):
                owner.solve(eq)
        event = receipt["plasma_psi_projection_events"][0]  # type: ignore[index]
        self.assertFalse(event["projection_applied"])  # type: ignore[index]
        self.assertEqual(
            event["projection_abort_reason"],  # type: ignore[index]
            "preprojection_delta_exceeds_frozen_roundoff_cap",
        )
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]
        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertIs(owner.solve, original_solve)
        self.assertIs(eq._applyBoundary, self.callback)

    def test_nonfinite_psi_fails_closed_and_restores_hooks(self) -> None:
        psi = np.full((len(self.edges["z_min"]), len(self.edges["r_min"])), 0.5)
        for key, edge in (("r_min", psi[0, :]), ("r_max", psi[-1, :]),
                          ("z_min", psi[:, 0]), ("z_max", psi[:, -1])):
            edge[:] = self.edges[key]
        owner = SimpleNamespace()

        def solve(eq: FakeEquilibrium) -> None:
            out = eq.psi().copy()
            out[1, 1] = np.nan
            eq._updatePlasmaPsi(out)

        owner.solve = solve
        original_init = FakeEquilibrium.__init__
        original_solve = owner.solve
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_projection(
            FakeEquilibrium, self.runner_file, solver_owner=owner, receipt=receipt
        ):
            eq = FakeEquilibrium(self.callback, psi)
            with self.assertRaisesRegex(RuntimeError, "non-finite"):
                owner.solve(eq)
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]
        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertIs(owner.solve, original_solve)
        self.assertIs(eq._applyBoundary, self.callback)

    def test_callback_corner_incompatibility_fails_closed(self) -> None:
        bad = copy.deepcopy(self.edges)
        bad["z_max"][0] += 0.1
        callback = observed_callback(bad, self.runner_file)
        psi = np.full((len(bad["z_min"]), len(bad["r_min"])), 0.5)
        owner = SimpleNamespace(solve=lambda eq: None)
        original_init = FakeEquilibrium.__init__
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_projection(
            FakeEquilibrium, self.runner_file, solver_owner=owner, receipt=receipt
        ):
            with self.assertRaisesRegex(RuntimeError, "incompatible corners"):
                FakeEquilibrium(callback, psi)
        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]


class RunpyRevisionBindingTests(unittest.TestCase):
    def test_runpy_copy_is_not_main_globals_and_actual_globals_are_restored(self) -> None:
        namespace = runpy.run_path(str(BASELINE_RUNNER), run_name="_v12_test_v2")
        main_function = namespace["main"]
        globals_dict = main_function.__globals__
        self.assertIsNot(namespace, globals_dict)
        original_revision = globals_dict["REVISION"]
        original_validator = globals_dict["validate_wrapper"]
        frozen_input = json.loads(FROZEN_V10_INPUT.read_text(encoding="utf-8"))
        with versioned_v2_main_globals(namespace):
            self.assertEqual(globals_dict["REVISION"], VERSIONED_REVISION)
            self.assertIsNot(globals_dict["validate_wrapper"], original_validator)
            # The unchanged v2 contract remains accepted while output identity
            # resolves through the exact globals dictionary owned by main.
            validated = globals_dict["validate_wrapper"](frozen_input)
            self.assertEqual(validated["revision"], BASELINE_REVISION)
            self.assertEqual(globals_dict["REVISION"], VERSIONED_REVISION)
            # A changed input revision is rejected and the v5 output identity
            # remains visible after the wrapper's exception path.
            with self.assertRaises((KeyError, TypeError, ValueError)):
                bad_input = copy.deepcopy(frozen_input)
                bad_input["revision"] = "wrong-revision"
                globals_dict["validate_wrapper"](bad_input)
            self.assertEqual(globals_dict["REVISION"], VERSIONED_REVISION)
        self.assertEqual(globals_dict["REVISION"], original_revision)
        self.assertIs(globals_dict["validate_wrapper"], original_validator)

    def test_context_receipt_is_true_only_after_context_exit_and_exact_restore(self) -> None:
        namespace = runpy.run_path(str(BASELINE_RUNNER), run_name="_v13_test_v2")
        main_function = namespace["main"]
        globals_dict = main_function.__globals__
        old_revision = globals_dict["REVISION"]
        old_validator = globals_dict["validate_wrapper"]
        state: dict[str, object] = {}
        with versioned_v2_main_globals(
            namespace, version_binding_receipt=state
        ):
            self.assertTrue(state["globals_context_entered"])
            self.assertFalse(state["globals_restored_after_context"])
            self.assertEqual(globals_dict["REVISION"], VERSIONED_REVISION)
        self.assertTrue(state["globals_context_restore_attempted"])
        self.assertTrue(state["globals_restored_after_context"])
        self.assertTrue(state["globals_restore_exact"])
        self.assertIs(globals_dict["REVISION"], old_revision)
        self.assertIs(globals_dict["validate_wrapper"], old_validator)

    def test_context_exception_restores_exact_globals_and_receipts_it(self) -> None:
        namespace = runpy.run_path(str(BASELINE_RUNNER), run_name="_v13_exception_test_v2")
        main_function = namespace["main"]
        globals_dict = main_function.__globals__
        old_revision = globals_dict["REVISION"]
        old_validator = globals_dict["validate_wrapper"]
        state: dict[str, object] = {}
        with self.assertRaisesRegex(RuntimeError, "inside context"):
            with versioned_v2_main_globals(
                namespace, version_binding_receipt=state
            ):
                raise RuntimeError("inside context")
        self.assertTrue(state["globals_context_entered"])
        self.assertTrue(state["globals_restored_after_context"])
        self.assertTrue(state["globals_restore_exact"])
        self.assertIs(globals_dict["REVISION"], old_revision)
        self.assertIs(globals_dict["validate_wrapper"], old_validator)

    def test_runner_precontext_failure_does_not_claim_globals_restored(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            output_path = Path(directory) / "solver_output.json"

            def fake_main(_argv: object) -> int:
                raise AssertionError("main must not be called before globals validation")

            def invalid_loader(*_args: object, **_kwargs: object) -> dict[str, object]:
                return {"main": fake_main}

            with self.assertRaisesRegex(RuntimeError, "delegated main globals"):
                run_baseline(
                    ["--output", str(output_path)],
                    equilibrium_class=FakeEquilibrium,
                    runner_loader=invalid_loader,
                )
            receipt = json.loads(
                (Path(directory) / "freegs_adapter_receipt_v13.json").read_text(encoding="utf-8")
            )
            binding = receipt["version_binding"]
            self.assertFalse(binding["globals_context_entered"])
            self.assertFalse(binding["globals_context_restore_attempted"])
            self.assertFalse(binding["globals_restored_after_context"])
            self.assertFalse(binding["globals_restore_exact"])


class MandatorySidecarBindingTests(unittest.TestCase):
    def _protocol(self, output_path: Path) -> dict[str, object]:
        leaf = output_path.parent
        return {
            "steps": [{"result_path": str(output_path)}],
            "runtime_endpoint_join": {
                "solver_output": str(output_path),
                "output_leaf": str(leaf),
                "adapter_receipt": str(leaf / "freegs_adapter_receipt_v13.json"),
            },
            "mandatory_evidence_sidecars": {
                "solver_output": str(output_path),
                "execution": str(leaf / "execution.json"),
                "stdout": str(leaf / "stdout.raw"),
                "stderr": str(leaf / "stderr.raw"),
                "adapter_receipt": str(leaf / "freegs_adapter_receipt_v13.json"),
                "storage_rule": (
                    "raw run/exit/hash/review evidence only under docs/implementation/"
                    "UP4-03-REFERENCE-VALIDATION-PREC/archive/**; tools and tests stay in "
                    "their owned source/test paths"
                ),
            },
        }

    def test_all_required_sidecars_bind_to_same_fresh_archive_leaf(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "archive"
            archive.mkdir()
            output_path = archive / "r13" / "solver_output.json"
            protocol = self._protocol(output_path)
            bound = validate_mandatory_sidecar_binding(protocol, output_path)
            self.assertEqual(set(bound), {
                "solver_output", "execution", "stdout", "stderr", "adapter_receipt"
            })

    def test_each_mandatory_sidecar_path_rejects_tampering(self) -> None:
        keys = ("solver_output", "execution", "stdout", "stderr", "adapter_receipt")
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "archive"
            archive.mkdir()
            output_path = archive / "r13" / "solver_output.json"
            for key in keys:
                with self.subTest(key=key):
                    protocol = self._protocol(output_path)
                    protocol["mandatory_evidence_sidecars"][key] = str(  # type: ignore[index]
                        archive / "tampered" / (key + ".raw")
                    )
                    with self.assertRaisesRegex(ValueError, "mandatory sidecar path is not bound"):
                        validate_mandatory_sidecar_binding(protocol, output_path)

    def test_step_and_endpoint_paths_must_also_bind_to_same_leaf(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "archive"
            archive.mkdir()
            output_path = archive / "r13" / "solver_output.json"
            for group, key in (("steps", "result_path"), ("runtime_endpoint_join", "solver_output"),
                               ("runtime_endpoint_join", "output_leaf"),
                               ("runtime_endpoint_join", "adapter_receipt")):
                protocol = self._protocol(output_path)
                target = protocol[group]
                if isinstance(target, list):
                    target[0][key] = str(archive / "tampered" / "solver_output.json")
                else:
                    target[key] = str(archive / "tampered" / key)
                with self.subTest(group=group, key=key):
                    with self.assertRaises(ValueError):
                        validate_mandatory_sidecar_binding(protocol, output_path)

    def test_resolved_path_alias_with_parent_traversal_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "archive"
            archive.mkdir()
            output_path = archive / "r13" / "solver_output.json"
            protocol = self._protocol(output_path)
            protocol["mandatory_evidence_sidecars"]["solver_output"] = str(  # type: ignore[index]
                archive / "alias" / ".." / "r13" / "solver_output.json"
            )
            with self.assertRaisesRegex(ValueError, "mandatory sidecar path is not bound"):
                validate_mandatory_sidecar_binding(protocol, output_path)


if __name__ == "__main__":
    unittest.main()
