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

from tools.up4_reference_validation.freegs_observed_dirichlet_boundary_v2 import (
    MAX_PREPROJECT_DELTA_WB_PER_RAD,
    temporary_observed_dirichlet_projection,
)
from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v4 import (
    BASELINE_REVISION,
    BASELINE_RUNNER,
    VERSIONED_REVISION,
    versioned_v2_main_globals,
)
from tools.up4_reference_validation.verify_freegs_v4_protocol_candidate import (
    verify_candidate,
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

    def test_proxy_receipt_requires_finite_to_none_and_exact_callback(self) -> None:
        _, receipt, _, _ = run_fake_solve(callback=self.callback, edges=self.edges)
        actions = [event["proxy_action"] for event in receipt["boundary_scalar_events"]]  # type: ignore[index]
        self.assertIn("applied_observed_box_boundary_convergence_proxy", actions)
        applied = next(event for event in receipt["boundary_scalar_events"] if event["proxy_action"] != "skipped")  # type: ignore[index]
        self.assertEqual(applied["previous_psi_bndry"], 1.25)
        self.assertIsNone(applied["native_post_update_psi_bndry"])
        self.assertEqual(applied["corner_psi_0_0"], float(self.edges["r_min"][0]))
        self.assertIn("not separatrix/physical plasma boundary flux", receipt["target"]["boundary_scalar_label"])  # type: ignore[index]

    def test_existing_xpoint_skips_only_scalar_proxy(self) -> None:
        eq, receipt, _, _ = run_fake_solve(
            callback=self.callback, edges=self.edges, mode="xpoint"
        )
        self.assertTrue(receipt["plasma_psi_projection_events"][0]["projection_applied"])  # type: ignore[index]
        self.assertTrue(
            all(event["proxy_action"] == "skipped" for event in receipt["boundary_scalar_events"])  # type: ignore[index]
        )
        self.assertEqual(
            receipt["boundary_scalar_events"][0]["proxy_skip_reason"],  # type: ignore[index]
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
            # A changed input revision is rejected and the v4 output identity
            # remains visible after the wrapper's exception path.
            with self.assertRaises((KeyError, TypeError, ValueError)):
                bad_input = copy.deepcopy(frozen_input)
                bad_input["revision"] = "wrong-revision"
                globals_dict["validate_wrapper"](bad_input)
            self.assertEqual(globals_dict["REVISION"], VERSIONED_REVISION)
        self.assertEqual(globals_dict["REVISION"], original_revision)
        self.assertIs(globals_dict["validate_wrapper"], original_validator)


class ProtocolPreflightTests(unittest.TestCase):
    protocol_path = REPOSITORY_ROOT / (
        "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_r1_20260923/"
        "native_axisymmetric_forward_v4/actual_run_protocol_v12_review_candidate_v1.json"
    )

    @staticmethod
    def _write_protocol(document: dict[str, object], directory: str, name: str) -> Path:
        path = Path(directory) / name
        path.write_text(json.dumps(document, indent=2, sort_keys=True), encoding="utf-8")
        return path

    @staticmethod
    def _rebind_supervisor_pin(
        document: dict[str, object], old_path: str, new_path: str, digest: str, byte_count: int
    ) -> None:
        pins = document["dependency_file_pins"]  # type: ignore[index]
        found = False
        for pin in pins:
            if pin["path"] == old_path:
                pin.update({"path": new_path, "sha256": digest, "bytes": byte_count})
                found = True
        if not found:
            raise AssertionError(f"input dependency pin not found: {old_path}")
        argv = document["steps"][0]["launcher_argv_template"]  # type: ignore[index]
        for index, value in enumerate(argv):
            if value == "--require-file-sha256" and argv[index + 1].startswith(old_path + "="):
                argv[index + 1] = new_path + "=" + digest
                break
        else:
            raise AssertionError(f"input supervisor pin not found: {old_path}")
        separator = argv.index("--")
        child = argv[separator + 1 :]
        child[child.index("--input") + 1] = new_path
        argv[separator + 1 :] = child
        document["steps"][0]["command_length_chars"] = len(" ".join(argv))  # type: ignore[index]
        document["dependency_file_pin_count"] = len(pins)  # type: ignore[index]

    def test_python_only_preflight_rehashes_all_155_launcher_pins(self) -> None:
        result = verify_candidate(self.protocol_path)
        self.assertEqual(result["status"], "static_protocol_check_pass")
        self.assertEqual(result["launcher_pin_count"], 155)
        self.assertTrue(result["all_supervisor_pins_rehashed"])
        self.assertTrue(result["child_argv_binding_valid"])
        self.assertFalse(result["root_resource_slot_granted"])
        self.assertFalse(result["solver_output_leaf_exists"])

    def test_protocol_preflight_rejects_a_changed_supervisor_pin(self) -> None:
        document = json.loads(self.protocol_path.read_text(encoding="utf-8"))
        argv = document["steps"][0]["launcher_argv_template"]
        pin_index = argv.index("--require-file-sha256") + 1
        path, digest = argv[pin_index].rsplit("=", 1)
        argv[pin_index] = path + "=" + ("0" if digest[0] != "0" else "1") + digest[1:]
        document["steps"][0]["command_length_chars"] = len(" ".join(argv))
        with tempfile.TemporaryDirectory() as directory:
            candidate = self._write_protocol(document, directory, "bad-pin.json")
            with self.assertRaisesRegex(ValueError, "launcher supervisor pins"):
                verify_candidate(candidate)

    def test_protocol_preflight_rejects_wrong_input_hash_even_when_repinned(self) -> None:
        document = json.loads(self.protocol_path.read_text(encoding="utf-8"))
        input_pin = next(
            pin for pin in document["dependency_file_pins"]
            if "solver_input.canonical.json" in pin["path"]
        )
        with tempfile.TemporaryDirectory() as directory:
            bad_input = Path(directory) / "solver_input.canonical.json"
            input_doc = json.loads(Path(input_pin["path"]).read_text(encoding="utf-8"))
            input_doc["review_negative_control"] = True
            payload = json.dumps(input_doc, indent=2, sort_keys=True).encode("utf-8") + b"\n"
            bad_input.write_bytes(payload)
            import hashlib

            digest = hashlib.sha256(payload).hexdigest()
            self._rebind_supervisor_pin(
                document,
                input_pin["path"],
                str(bad_input),
                digest,
                len(payload),
            )
            candidate = self._write_protocol(document, directory, "bad-input-hash.json")
            with self.assertRaisesRegex(ValueError, "frozen v10 solver input hash"):
                verify_candidate(candidate)


if __name__ == "__main__":
    unittest.main()
