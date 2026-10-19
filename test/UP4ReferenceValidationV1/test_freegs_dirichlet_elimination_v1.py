from __future__ import annotations

import copy
import ast
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import numpy as np
from scipy import sparse
from scipy.sparse.linalg import spsolve


ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))
RUNNER_PATH = (
    ROOT / "scripts" / "runtime_v4_freegs_axisymmetric_profile_runner_v2.py"
)

from tools.up4_reference_validation.freegs_dirichlet_elimination_v1 import (
    HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD,
    ReducedDirichletLinearSystem,
    boundary_interior_indices,
)
from tools.up4_reference_validation.freegs_observed_dirichlet_boundary_v4 import (
    temporary_observed_dirichlet_linear_solve,
)


def make_edges(shape: tuple[int, int]) -> dict[str, np.ndarray]:
    source = (np.arange(shape[0] * shape[1], dtype=np.float64).reshape(shape) + 1.0) / 37.0
    return {
        "r_min": source[0, :].copy(),
        "r_max": source[-1, :].copy(),
        "z_min": source[:, 0].copy(),
        "z_max": source[:, -1].copy(),
    }


def make_operator(shape: tuple[int, int]) -> sparse.csr_matrix:
    nx, ny = shape
    count = nx * ny
    a = sparse.lil_matrix((count, count), dtype=np.float64)
    for i in range(nx):
        for j in range(ny):
            row = i * ny + j
            if i == 0 or i == nx - 1 or j == 0 or j == ny - 1:
                a[row, row] = 1.0
            else:
                a[row, row] = 6.0
                for ni, nj in ((i - 1, j), (i + 1, j), (i, j - 1), (i, j + 1)):
                    a[row, ni * ny + nj] = -1.0
    return a.tocsr()


def make_rhs(operator: sparse.csr_matrix, edges: dict[str, np.ndarray]) -> np.ndarray:
    nx = edges["z_min"].size
    ny = edges["r_min"].size
    truth = np.arange(nx * ny, dtype=np.float64).reshape((nx, ny)) / 19.0
    truth[0, :] = edges["r_min"]
    truth[-1, :] = edges["r_max"]
    truth[:, 0] = edges["z_min"]
    truth[:, -1] = edges["z_max"]
    return np.asarray(operator.dot(truth.ravel(order="C"))).reshape((nx, ny), order="C")


def observed_callback(edges: dict[str, np.ndarray]) -> object:
    namespace: dict[str, object] = {}
    source = """
def solve(boundary_edges):
    def observed_dirichlet_boundary(_eq, _jtor, psi):
        psi[0, :] = boundary_edges['r_min']
        psi[-1, :] = boundary_edges['r_max']
        psi[:, 0] = boundary_edges['z_min']
        psi[:, -1] = boundary_edges['z_max']
    return observed_dirichlet_boundary
"""
    exec(compile(source, str(RUNNER_PATH), "exec"), namespace)
    return namespace["solve"](edges)  # type: ignore[index,operator]


class FakeEquilibrium:
    def __init__(
        self,
        callback: object,
        psi: np.ndarray,
        matrix: sparse.csr_matrix,
        *,
        boundary_mode: str = "none",
    ) -> None:
        self._applyBoundary = callback
        self.plasma_psi = psi.copy()
        self.matrix = matrix
        self.nx, self.ny = psi.shape
        self.Rmin, self.Rmax = 1.0, 2.0
        self.Zmin, self.Zmax = -1.0, 1.0
        self.order = 4
        self.R, self.Z = np.meshgrid(
            np.linspace(self.Rmin, self.Rmax, self.nx),
            np.linspace(self.Zmin, self.Zmax, self.ny),
            indexing="ij",
        )
        self.psi_bndry: float | None = 0.75
        self.boundary_mode = boundary_mode
        self.diagnostic_eq_metadata = {"marker": "unchanged"}
        self.update_calls = 0
        self._solver = FailingOriginalLinearSolver()

    def psi(self) -> np.ndarray:
        return self.plasma_psi

    def _updateBoundaryPsi(self, psi: np.ndarray | None = None) -> None:
        self.psi_bndry = None if self.boundary_mode == "none" else 0.5

    def _updatePlasmaPsi(self, value: np.ndarray) -> None:
        self.plasma_psi = value
        self.update_calls += 1
        self._updateBoundaryPsi(value)


class FailingOriginalLinearSolver:
    def __init__(self) -> None:
        self.calls = 0

    def __call__(self, x: np.ndarray, rhs: np.ndarray) -> np.ndarray:
        self.calls += 1
        raise AssertionError("full-grid solver must not be called as a fallback")


class FakeSolveOwner:
    def solve(
        self,
        eq: FakeEquilibrium,
        *,
        skip_callback: bool = False,
        linear_steps: int = 1,
    ) -> np.ndarray:
        out = eq.psi()
        for _ in range(linear_steps):
            eq._updateBoundaryPsi(eq.psi())
            rhs = eq.psi().copy()
            if not skip_callback:
                eq._applyBoundary(eq, np.zeros_like(rhs), rhs)  # type: ignore[operator]
            out = eq._solver(eq.psi(), rhs)
            eq._updatePlasmaPsi(out)
        return out


def fake_run(
    *,
    callback: object,
    edges: dict[str, np.ndarray],
    matrix: sparse.csr_matrix,
    skip_callback: bool = False,
    boundary_mode: str = "none",
) -> tuple[FakeEquilibrium, dict[str, object], object]:
    shape = (len(edges["z_min"]), len(edges["r_min"]))
    psi = np.full(shape, 0.25, dtype=np.float64)
    psi[0, :] = edges["r_min"]
    psi[-1, :] = edges["r_max"]
    psi[:, 0] = edges["z_min"]
    psi[:, -1] = edges["z_max"]
    owner = FakeSolveOwner()
    original_init = FakeEquilibrium.__init__
    original_bound_update = FakeEquilibrium._updateBoundaryPsi
    original_plasma_update = FakeEquilibrium._updatePlasmaPsi
    original_owner_solve = owner.solve
    receipt: dict[str, object] = {}
    with temporary_observed_dirichlet_linear_solve(
        FakeEquilibrium,
        RUNNER_PATH,
        solver_owner=owner,
        receipt=receipt,
        test_operator_builder=lambda target: target.matrix,
    ):
        eq = FakeEquilibrium(
            callback, psi, matrix, boundary_mode=boundary_mode
        )
        original_solver = eq._solver
        try:
            owner.solve(eq, skip_callback=skip_callback)
        except RuntimeError:
            if not skip_callback:
                raise
        else:
            if skip_callback:
                raise AssertionError("missing callback must fail closed")
    assert FakeEquilibrium.__init__ is original_init
    assert FakeEquilibrium._updateBoundaryPsi is original_bound_update
    assert FakeEquilibrium._updatePlasmaPsi is original_plasma_update
    assert owner.solve.__func__ is original_owner_solve.__func__
    assert eq._applyBoundary is callback
    assert eq._updateBoundaryPsi.__func__ is original_bound_update
    assert eq._updatePlasmaPsi.__func__ is original_plasma_update
    assert eq._solver is original_solver
    assert original_solver.calls == 0
    assert receipt["restoration"]["completed"] is True  # type: ignore[index]
    return eq, receipt, original_solver


class DirichletEliminationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.shape = (5, 6)
        self.edges = make_edges(self.shape)
        self.operator = make_operator(self.shape)
        self.rhs = make_rhs(self.operator, self.edges)

    def test_boundary_partition_is_unique_disjoint_and_exhaustive(self) -> None:
        boundary, interior = boundary_interior_indices(self.shape)
        self.assertEqual(boundary.size, 18)
        self.assertEqual(interior.size, 12)
        self.assertEqual(np.intersect1d(boundary, interior).size, 0)
        self.assertEqual(np.unique(boundary).size, boundary.size)
        self.assertEqual(set(boundary) | set(interior), set(range(30)))
        self.assertIn(1 * self.shape[1] + 2, interior)
        self.assertIn(0 * self.shape[1] + 2, boundary)

    def test_reduced_solution_matches_full_block_solution_and_keeps_edges_exact(self) -> None:
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        output = reduced(np.zeros(self.shape, dtype=np.float64), self.rhs)
        full = spsolve(self.operator.tocsc(), self.rhs.ravel(order="C"))
        full = np.asarray(full).reshape(self.shape, order="C")
        self.assertTrue(np.allclose(output[1:-1, 1:-1], full[1:-1, 1:-1], rtol=2e-13, atol=2e-13))
        for key, values in {
            "r_min": output[0, :], "r_max": output[-1, :],
            "z_min": output[:, 0], "z_max": output[:, -1],
        }.items():
            self.assertTrue(np.array_equal(values, self.edges[key]))

    def test_wrong_sign_negative_control_fails_full_interior_residual(self) -> None:
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        boundary, interior = reduced.boundary, reduced.interior
        rhs_flat = self.rhs.ravel(order="C")
        g = rhs_flat[boundary]
        wrong_rhs = rhs_flat[interior] + reduced.a_ib.dot(g)
        wrong_interior = spsolve(reduced.a_ii.tocsc(), wrong_rhs)
        wrong_flat = np.empty(self.shape[0] * self.shape[1], dtype=np.float64)
        wrong_flat[interior] = wrong_interior
        wrong_flat[boundary] = g
        wrong_residual = self.operator.dot(wrong_flat) - rhs_flat
        self.assertGreater(float(np.max(np.abs(wrong_residual[interior]))), 1.0e-3)
        exact = reduced(np.zeros(self.shape, dtype=np.float64), self.rhs)
        exact_residual = self.operator.dot(exact.ravel(order="C")) - rhs_flat
        self.assertLess(float(np.max(np.abs(exact_residual[interior]))), 1.0e-12)

    def test_a_ib_contains_expected_nonzero_couplings_with_correct_c_order_sign(self) -> None:
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        self.assertEqual(reduced.a_ib.nnz, 14)
        self.assertTrue(np.array_equal(reduced.a_ib.data, np.full(14, -1.0)))
        # C-order flat labels: (r=1,z=1) is row=1*ny+1; its r-min and z-min
        # neighbors are boundary labels 1 and ny respectively.
        row_in_a_ii = int(np.flatnonzero(reduced.interior == 1 * self.shape[1] + 1)[0])
        col_rmin = int(np.flatnonzero(reduced.boundary == 1)[0])
        col_zmin = int(np.flatnonzero(reduced.boundary == self.shape[1])[0])
        self.assertEqual(reduced.a_ib[row_in_a_ii, col_rmin], -1.0)
        self.assertEqual(reduced.a_ib[row_in_a_ii, col_zmin], -1.0)

    def test_residual_is_recorded_without_an_acceptance_threshold(self) -> None:
        receipt: dict[str, object] = {}
        reduced = ReducedDirichletLinearSystem(
            self.operator, self.shape, self.edges, receipt=receipt
        )
        reduced(np.zeros(self.shape, dtype=np.float64), self.rhs)
        self.assertEqual(
            receipt["reduced_linear_system"]["residual_threshold"],  # type: ignore[index]
            "not_defined_diagnostic_only",
        )
        event = receipt["linear_solver_events"][0]  # type: ignore[index]
        self.assertEqual(event["linear_residual"]["max_abs_boundary"], 0.0)  # type: ignore[index]
        self.assertTrue(event["output_edges_exact"])  # type: ignore[index]
        output = reduced(np.zeros(self.shape, dtype=np.float64), self.rhs)
        residual = self.operator.dot(output.ravel(order="C")) - self.rhs.ravel(order="C")
        boundary, interior = boundary_interior_indices(self.shape)
        second = receipt["linear_solver_events"][1]["linear_residual"]  # type: ignore[index]
        self.assertEqual(second["max_abs_boundary"], float(np.max(np.abs(residual[boundary]))))
        self.assertEqual(second["max_abs_interior"], float(np.max(np.abs(residual[interior]))))

    def test_rhs_boundary_mismatch_rejects_without_projection(self) -> None:
        rhs = self.rhs.copy()
        rhs[-1, 2] = np.nextafter(rhs[-1, 2], np.inf)
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        with self.assertRaisesRegex(RuntimeError, "RHS boundary"):
            reduced(np.zeros(self.shape, dtype=np.float64), rhs)

    def test_nonzero_boundary_to_interior_block_is_rejected(self) -> None:
        bad = self.operator.tolil(copy=True)
        bad[0, 1 * self.shape[1] + 1] = 0.25
        with self.assertRaisesRegex(RuntimeError, "A_BI"):
            ReducedDirichletLinearSystem(bad.tocsr(), self.shape, self.edges)

    def test_nonidentity_boundary_block_is_rejected(self) -> None:
        bad = self.operator.tolil(copy=True)
        bad[0, 0] = 2.0
        with self.assertRaisesRegex(RuntimeError, "A_BB"):
            ReducedDirichletLinearSystem(bad.tocsr(), self.shape, self.edges)

    def test_shape_dtype_sparse_and_finite_guards(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "sparse"):
            ReducedDirichletLinearSystem(np.eye(30), self.shape, self.edges)
        with self.assertRaisesRegex(RuntimeError, "shape"):
            ReducedDirichletLinearSystem(sparse.eye(29), self.shape, self.edges)
        with self.assertRaisesRegex(RuntimeError, "shape"):
            ReducedDirichletLinearSystem(self.operator, (5,), self.edges)  # type: ignore[arg-type]
        with self.assertRaisesRegex(RuntimeError, "float64"):
            ReducedDirichletLinearSystem(
                self.operator.astype(np.float32), self.shape, self.edges
            )
        bad = self.operator.copy().tolil()
        bad[5, 5] = np.nan
        with self.assertRaisesRegex(RuntimeError, "non-finite"):
            ReducedDirichletLinearSystem(bad.tocsr(), self.shape, self.edges)
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        with self.assertRaisesRegex(RuntimeError, "float64"):
            reduced(np.zeros(self.shape, dtype=np.float32), self.rhs)

    def test_corner_conflict_rejects(self) -> None:
        edges = copy.deepcopy(self.edges)
        edges["z_min"][0] = np.nextafter(edges["z_min"][0], np.inf)
        with self.assertRaisesRegex(RuntimeError, "incompatible corners"):
            ReducedDirichletLinearSystem(self.operator, self.shape, edges)

    def test_rhs_dimensions_and_finiteness_reject(self) -> None:
        reduced = ReducedDirichletLinearSystem(self.operator, self.shape, self.edges)
        with self.assertRaisesRegex(RuntimeError, "shape"):
            reduced(np.zeros((2, 2)), self.rhs)
        bad_rhs = self.rhs.copy()
        bad_rhs[2, 2] = np.inf
        with self.assertRaisesRegex(RuntimeError, "finite"):
            reduced(np.zeros(self.shape), bad_rhs)

    def test_historical_projection_guard_is_not_reduced(self) -> None:
        self.assertEqual(HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD, 1.0e-12)

    def test_factorization_is_per_outer_solve_and_reused_only_within_that_scope(self) -> None:
        callback = observed_callback(self.edges)
        owner = FakeSolveOwner()
        psi = np.zeros(self.shape, dtype=np.float64)
        receipt: dict[str, object] = {}
        eq: FakeEquilibrium
        initial_solver: object
        from scipy.sparse.linalg import factorized as real_factorized
        with patch("scipy.sparse.linalg.factorized", wraps=real_factorized) as factorized_spy:
            with temporary_observed_dirichlet_linear_solve(
                FakeEquilibrium,
                RUNNER_PATH,
                solver_owner=owner,
                receipt=receipt,
                test_operator_builder=lambda target: target.matrix,
            ):
                eq = FakeEquilibrium(callback, psi, self.operator)
                initial_solver = eq._solver
                owner.solve(eq, linear_steps=3)
                owner.solve(eq, linear_steps=3)
            self.assertEqual(factorized_spy.call_count, 2)
        self.assertEqual(len(receipt["linear_solver_events"]), 6)  # type: ignore[arg-type]
        self.assertEqual(len(receipt["boundary_callback_events"]), 6)  # type: ignore[arg-type]
        self.assertIs(eq._solver, initial_solver)
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]

    def test_set_solver_vcycle_identity_change_is_rejected_before_dispatch(self) -> None:
        callback = observed_callback(self.edges)
        owner = FakeSolveOwner()
        eq: FakeEquilibrium
        replacement = lambda x, b: b
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_linear_solve(
            FakeEquilibrium,
            RUNNER_PATH,
            solver_owner=owner,
            receipt=receipt,
            test_operator_builder=lambda target: target.matrix,
        ):
            eq = FakeEquilibrium(callback, np.zeros(self.shape, dtype=np.float64), self.operator)
            eq._solver = replacement
            with self.assertRaisesRegex(RuntimeError, "solver identity changed"):
                owner.solve(eq)
        self.assertIs(eq._solver, replacement)
        self.assertEqual(receipt["linear_solver_events"], [])

    def test_grid_coordinate_change_is_rejected_before_dispatch(self) -> None:
        callback = observed_callback(self.edges)
        owner = FakeSolveOwner()
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_linear_solve(
            FakeEquilibrium,
            RUNNER_PATH,
            solver_owner=owner,
            receipt=receipt,
            test_operator_builder=lambda target: target.matrix,
        ):
            eq = FakeEquilibrium(callback, np.zeros(self.shape, dtype=np.float64), self.operator)
            eq.R[1, 2] = np.nextafter(eq.R[1, 2], np.inf)
            with self.assertRaisesRegex(RuntimeError, "tensor grid"):
                owner.solve(eq)
        self.assertEqual(receipt["linear_solver_events"], [])

    def test_adapter_does_not_write_psi_bndry_or_call_set_solver_vcycle(self) -> None:
        import tools.up4_reference_validation.freegs_observed_dirichlet_boundary_v4 as adapter

        tree = ast.parse(Path(adapter.__file__).read_text(encoding="utf-8"))
        forbidden_calls = [
            node for node in ast.walk(tree)
            if isinstance(node, ast.Call)
            and isinstance(node.func, ast.Attribute)
            and node.func.attr == "setSolverVcycle"
        ]
        self.assertEqual(forbidden_calls, [])
        writes = []
        for node in ast.walk(tree):
            if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                targets = node.targets if isinstance(node, ast.Assign) else [node.target]
                writes.extend(
                    target for root in targets for target in ast.walk(root)
                    if isinstance(target, ast.Attribute) and target.attr == "psi_bndry"
                )
        self.assertEqual(writes, [])

    def test_v16_precontext_runner_failure_is_terminal_without_restore_claim(self) -> None:
        from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v7 import (
            run_baseline,
        )

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "solver_output.json"
            fake_file = Path(directory) / "not_the_pinned_v2_runner.py"
            namespace: dict[str, object] = {"__file__": str(fake_file)}
            exec(compile("def main(_args): return 0\n", str(fake_file), "exec"), namespace)
            with self.assertRaisesRegex(RuntimeError, "pinned v2 runner"):
                run_baseline(
                    ["--input", "unused", "--source", "unused", "--output", str(output)],
                    equilibrium_class=FakeEquilibrium,
                    runner_loader=lambda *_args, **_kwargs: namespace,  # type: ignore[arg-type]
                )
            receipt = json.loads(
                (Path(directory) / "freegs_adapter_receipt_v16.json").read_text(encoding="utf-8")
            )
            self.assertEqual(receipt["status"], "runner_raised")
            binding = receipt["version_binding"]
            self.assertFalse(binding["globals_context_entered"])
            self.assertFalse(binding["globals_context_restore_attempted"])
            self.assertFalse(binding["globals_restored_after_context"])
            self.assertFalse(binding["globals_restore_exact"])

    def test_v13_precontext_negative_control_remains_started(self) -> None:
        from tools.up4_reference_validation.runtime_v4_freegs_axisymmetric_profile_runner_v5 import (
            run_baseline,
        )

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "solver_output.json"
            fake_file = Path(directory) / "not_the_pinned_v2_runner.py"
            namespace: dict[str, object] = {"__file__": str(fake_file)}
            exec(compile("def main(_args): return 0\n", str(fake_file), "exec"), namespace)
            with self.assertRaisesRegex(RuntimeError, "pinned v2 runner"):
                run_baseline(
                    ["--input", "unused", "--source", "unused", "--output", str(output)],
                    equilibrium_class=FakeEquilibrium,
                    runner_loader=lambda *_args, **_kwargs: namespace,  # type: ignore[arg-type]
                )
            receipt = json.loads(
                (Path(directory) / "freegs_adapter_receipt_v13.json").read_text(encoding="utf-8")
            )
            self.assertEqual(receipt["status"], "started")
            binding = receipt["version_binding"]
            self.assertFalse(binding["globals_context_entered"])
            self.assertFalse(binding["globals_context_restore_attempted"])
            self.assertFalse(binding["globals_restored_after_context"])
            self.assertFalse(binding["globals_restore_exact"])

    def test_each_mandatory_sidecar_rejects_retargeting(self) -> None:
        from tools.up4_reference_validation.verify_freegs_v7_protocol_candidate import (
            validate_mandatory_sidecars,
        )

        names = {
            "adapter_receipt": "freegs_adapter_receipt_v16.json",
            "execution": "execution.json",
            "solver_output": "solver_output.json",
            "stdout": "stdout.raw",
            "stderr": "stderr.raw",
        }
        with tempfile.TemporaryDirectory() as directory:
            leaf = Path(directory) / "archive" / "r16"
            output = leaf / "solver_output.json"
            valid = {key: str(leaf / name) for key, name in names.items()}
            valid["storage_rule"] = "raw run/exit/hash/review evidence only under docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/**"
            self.assertEqual(set(validate_mandatory_sidecars(valid, output)), set(names))
            for key in names:
                tampered = dict(valid)
                tampered[key] = str(leaf / "elsewhere" / names[key])
                with self.subTest(sidecar=key):
                    with self.assertRaisesRegex(RuntimeError, "not bound to v16 leaf"):
                        validate_mandatory_sidecars(tampered, output)

    def test_marked_target_uses_reduced_solver_and_restores_instance_hooks(self) -> None:
        callback = observed_callback(self.edges)
        eq, receipt, _ = fake_run(
            callback=callback, edges=self.edges, matrix=self.operator
        )
        self.assertTrue(np.array_equal(eq.psi()[0, :], self.edges["r_min"]))
        self.assertTrue(np.array_equal(eq.psi()[-1, :], self.edges["r_max"]))
        self.assertEqual(len(receipt["boundary_callback_events"]), 1)  # type: ignore[arg-type]
        self.assertEqual(len(receipt["linear_solver_events"]), 1)  # type: ignore[arg-type]
        self.assertTrue(receipt["target"]["psi_bndry_proxy_write"] is False)  # type: ignore[index]
        self.assertEqual(eq.diagnostic_eq_metadata, {"marker": "unchanged"})

    def test_solver_requires_callback_before_each_solve_and_restores_after_failure(self) -> None:
        callback = observed_callback(self.edges)
        eq, receipt, _ = fake_run(
            callback=callback,
            edges=self.edges,
            matrix=self.operator,
            skip_callback=True,
        )
        self.assertEqual(eq._solver.calls, 0)  # type: ignore[attr-defined]
        self.assertFalse(receipt["target"]["formal_freegs_solve_returned"])  # type: ignore[index]
        self.assertIn("callback", receipt["target"]["target_exception"]["message"])  # type: ignore[index]

    def test_unmarked_callback_does_not_replace_original_solver(self) -> None:
        free_callback = lambda _eq, _jtor, psi: psi
        owner = FakeSolveOwner()
        eq = FakeEquilibrium(
            free_callback, np.zeros(self.shape, dtype=np.float64), self.operator
        )
        class IdentitySolver:
            def __call__(self, x: np.ndarray, rhs: np.ndarray) -> np.ndarray:
                return rhs
        old_solver = IdentitySolver()
        eq._solver = old_solver
        receipt: dict[str, object] = {}
        with temporary_observed_dirichlet_linear_solve(
            FakeEquilibrium,
            RUNNER_PATH,
            solver_owner=owner,
            receipt=receipt,
            test_operator_builder=lambda target: target.matrix,
        ):
            result = owner.solve(eq)
        self.assertIs(result, eq.psi())
        self.assertEqual(receipt["linear_solver_events"], [])
        self.assertIs(eq._solver, old_solver)

    def test_solver_exception_has_no_full_grid_fallback(self) -> None:
        callback = observed_callback(self.edges)
        owner = FakeSolveOwner()
        psi = np.zeros(self.shape, dtype=np.float64)
        original_init = FakeEquilibrium.__init__
        original_update = FakeEquilibrium._updateBoundaryPsi
        receipt: dict[str, object] = {}
        def fail_solve(_rhs: np.ndarray) -> np.ndarray:
            raise ValueError("injected reduced factorization failure")

        with patch("scipy.sparse.linalg.factorized", return_value=fail_solve):
            with temporary_observed_dirichlet_linear_solve(
                FakeEquilibrium,
                RUNNER_PATH,
                solver_owner=owner,
                receipt=receipt,
                test_operator_builder=lambda _eq: self.operator,
            ):
                eq = FakeEquilibrium(callback, psi, self.operator)
                original_solver = eq._solver
                with self.assertRaisesRegex(RuntimeError, "A_II solve failed"):
                    owner.solve(eq)
        self.assertIs(FakeEquilibrium.__init__, original_init)
        self.assertIs(FakeEquilibrium._updateBoundaryPsi, original_update)
        self.assertIs(eq._solver, original_solver)
        self.assertEqual(original_solver.calls, 0)
        self.assertTrue(receipt["restoration"]["completed"])  # type: ignore[index]


if __name__ == "__main__":
    unittest.main()
