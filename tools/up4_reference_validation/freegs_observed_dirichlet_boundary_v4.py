"""Observed-box FreeGS adapter using exact Dirichlet degree elimination.

The adapter is versioned and test-only. It shares only identity/hash helpers
with the frozen v15 adapter. A target Equilibrium's default order-4 sparse
solver is replaced, for the duration of one FreeGS solve call, by the
mathematically equivalent A_II/A_IB reduced solve. It never writes psi_bndry,
never projects a full-grid solver result, and never falls back to that solver.
"""

from __future__ import annotations

from contextlib import contextmanager
import importlib
import inspect
import os
from pathlib import Path
import sys
from typing import Any, Callable, Iterator

if __package__:
    from . import freegs_observed_dirichlet_boundary_v3 as _common
    from .freegs_dirichlet_elimination_v1 import (
        HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD,
        ReducedDirichletLinearSystem,
    )
else:
    import freegs_observed_dirichlet_boundary_v3 as _common
    from freegs_dirichlet_elimination_v1 import (
        HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD,
        ReducedDirichletLinearSystem,
    )


PINNED_ADDITIONAL_SOURCE_SHA256 = {
    "gradshafranov.py": "96c7eb78397a9c721aecf2e0de1f8e7425a706b669648ca0032ad90db8dc6ea5",
    "multigrid.py": "a35a094934bad28b99baf8205c4b97c7c1db81e3f0b34810012ceca28d2ea12e",
}
EDGE_NAMES = _common.EDGE_NAMES
_MISSING = _common._MISSING


def verify_pinned_freegs_sources(equilibrium_class: type) -> dict[str, str]:
    source_root = _common._source_root(equilibrium_class)
    observed = _common.verify_pinned_freegs_sources(equilibrium_class)
    for filename, expected in PINNED_ADDITIONAL_SOURCE_SHA256.items():
        path = source_root / filename
        if not path.is_file():
            raise RuntimeError(f"pinned FreeGS source is missing: {filename}")
        digest = _common.hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"pinned FreeGS source hash mismatch for {filename}")
        observed[filename] = digest
    return observed


def verify_pinned_freegs_solve_api(
    freegs_package: Any, picard_module: Any, source_root: str | os.PathLike[str]
) -> None:
    _common.verify_pinned_freegs_solve_api(freegs_package, picard_module, source_root)


def _pinned_order4_operator(eq: Any, equilibrium_class: type) -> tuple[Any, dict[str, str]]:
    if getattr(eq, "order", None) != 4:
        raise RuntimeError("v16 elimination supports only the frozen FreeGS order=4 operator")
    shape = tuple(getattr(getattr(eq, "R", None), "shape", ()))
    if shape != (int(getattr(eq, "nx", -1)), int(getattr(eq, "ny", -1))):
        raise RuntimeError("FreeGS equilibrium coordinate grid shape is inconsistent")
    package_name = equilibrium_class.__module__.rsplit(".", 1)[0]
    multigrid = importlib.import_module(package_name + ".multigrid")
    gradshafranov = importlib.import_module(package_name + ".gradshafranov")
    old_solver = getattr(eq, "_solver", None)
    if type(old_solver) is not getattr(multigrid, "MGDirect", None):
        raise RuntimeError("FreeGS solver is not the pinned full-grid MGDirect implementation")
    generator_cls = getattr(gradshafranov, "GSsparse4thOrder", None)
    if not isinstance(generator_cls, type):
        raise RuntimeError("pinned GSsparse4thOrder generator is unavailable")
    expected_path = _common._source_root(equilibrium_class) / "gradshafranov.py"
    for method in (generator_cls.__init__, generator_cls.__call__):
        code = getattr(method, "__code__", None)
        if code is None or _common._normalised_path(code.co_filename) != _common._normalised_path(expected_path):
            raise RuntimeError("FreeGS order-4 generator does not match the pinned source")
    if list(inspect.signature(generator_cls).parameters) != ["Rmin", "Rmax", "Zmin", "Zmax"]:
        raise RuntimeError("GSsparse4thOrder constructor signature differs from the pinned API")
    if list(inspect.signature(generator_cls.__call__).parameters) != ["self", "nx", "ny"]:
        raise RuntimeError("GSsparse4thOrder call signature differs from the pinned API")
    generator = generator_cls(float(eq.Rmin), float(eq.Rmax), float(eq.Zmin), float(eq.Zmax))
    matrix = generator(int(eq.nx), int(eq.ny))
    return matrix, {
        "generator": "freegs.gradshafranov.GSsparse4thOrder",
        "solver": "freegs.multigrid.MGDirect",
        "operator_source_sha256": PINNED_ADDITIONAL_SOURCE_SHA256["gradshafranov.py"],
        "direct_solver_source_sha256": PINNED_ADDITIONAL_SOURCE_SHA256["multigrid.py"],
    }


def _equilibrium_basis(eq: Any) -> tuple[Any, ...]:
    np = _common._np()
    r = np.asarray(getattr(eq, "R", None))
    z = np.asarray(getattr(eq, "Z", None))
    shape = (int(getattr(eq, "nx", -1)), int(getattr(eq, "ny", -1)))
    if r.shape != shape or z.shape != shape:
        raise RuntimeError("equilibrium R/Z coordinates do not match nx/ny")
    rmin = float(getattr(eq, "Rmin"))
    rmax = float(getattr(eq, "Rmax"))
    zmin = float(getattr(eq, "Zmin"))
    zmax = float(getattr(eq, "Zmax"))
    if not np.isfinite(r).all() or not np.isfinite(z).all():
        raise RuntimeError("equilibrium R/Z coordinates are non-finite")
    expected_r, expected_z = np.meshgrid(
        np.linspace(rmin, rmax, shape[0]),
        np.linspace(zmin, zmax, shape[1]),
        indexing="ij",
    )
    if not np.array_equal(r, expected_r) or not np.array_equal(z, expected_z):
        raise RuntimeError("equilibrium coordinates differ from the frozen tensor grid")
    return (
        getattr(eq, "order", None),
        shape,
        rmin,
        rmax,
        zmin,
        zmax,
        _common._hash_float64(r),
        _common._hash_float64(z),
    )


@contextmanager
def temporary_observed_dirichlet_linear_solve(
    equilibrium_class: type,
    expected_runner_file: str | os.PathLike[str],
    *,
    solver_owner: Any,
    receipt: dict[str, Any],
    test_operator_builder: Callable[[Any], Any] | None = None,
) -> Iterator[None]:
    """Install v16 only for the target instance and exact observed callback.

    The operator-builder injection is a fake-object test seam. Dispatch must
    keep it None, which selects the hash-verified FreeGS order-4 generator.
    """
    np = _common._np()
    if solver_owner is None:
        raise RuntimeError("pinned FreeGS solve owner is unavailable")
    original_init = equilibrium_class.__init__
    owner_dict = getattr(solver_owner, "__dict__", None)
    if not isinstance(owner_dict, dict):
        raise RuntimeError("FreeGS solve owner cannot be safely restored")
    had_solver = "solve" in owner_dict
    saved_solver = owner_dict.get("solve", _MISSING)
    original_solver = getattr(solver_owner, "solve", None)
    if not callable(original_solver):
        raise RuntimeError("pinned FreeGS top-level solve API is unavailable")
    registered: dict[int, tuple[Any, Any, dict[str, Any], tuple[int, int], Any, tuple[Any, ...]]] = {}
    receipt.setdefault("boundary_callback_events", [])
    receipt.setdefault("boundary_scalar_events", [])
    receipt.setdefault("linear_solver_events", [])
    receipt.setdefault("restoration", {"completed": False})
    receipt["adapter_status"] = "armed_for_exact_marked_callback_only"
    receipt["historical_full_grid_projection_guard_wb_per_rad"] = (
        HISTORICAL_FULL_GRID_PROJECTION_CAP_WB_PER_RAD
    )
    receipt["v16_projection_policy"] = (
        "no full-grid projection; no fallback; v15 guard value retained unchanged as historical guard"
    )

    def init_with_registration(self: Any, *args: Any, **kwargs: Any) -> None:
        original_init(self, *args, **kwargs)
        callback = getattr(self, "_applyBoundary", None)
        if not _common.is_pinned_observed_dirichlet_callback(callback, expected_runner_file):
            return
        edges = _common._edge_arrays(callback)
        shape = (int(edges["z_min"].size), int(edges["r_min"].size))
        if any(
            edges[name].size != (shape[1] if name.startswith("r_") else shape[0])
            for name in EDGE_NAMES
        ):
            raise RuntimeError("observed boundary edges are incompatible with their grid shape")
        original_instance_solver = getattr(self, "_solver", None)
        if not callable(original_instance_solver):
            raise RuntimeError("FreeGS constructor did not leave a callable default solver")
        registered[id(self)] = (
            self, callback, edges, shape, original_instance_solver, _equilibrium_basis(self)
        )

    def solve_for_marked_target(eq: Any, *args: Any, **kwargs: Any) -> Any:
        item = registered.get(id(eq))
        if item is None or item[0] is not eq:
            return original_solver(eq, *args, **kwargs)
        _, callback, edges, shape, initial_solver, initial_basis = item
        if getattr(eq, "_applyBoundary", None) is not callback:
            raise RuntimeError("marked observed-Dirichlet callback identity changed before solve")
        if getattr(eq, "_solver", None) is not initial_solver:
            raise RuntimeError(
                "FreeGS solver identity changed after construction; unchecked setSolverVcycle is forbidden"
            )
        if _equilibrium_basis(eq) != initial_basis:
            raise RuntimeError("FreeGS order/grid changed after observed boundary registration")
        instance_dict = getattr(eq, "__dict__", None)
        if not isinstance(instance_dict, dict):
            raise RuntimeError("FreeGS Equilibrium instance cannot be safely restored")
        saved: dict[str, tuple[bool, Any]] = {}
        for name in ("_applyBoundary", "_updateBoundaryPsi", "_solver"):
            saved[name] = name in instance_dict, instance_dict.get(name, _MISSING)
        original_bound_update = eq._updateBoundaryPsi
        old_solver = getattr(eq, "_solver", None)
        if not callable(old_solver):
            raise RuntimeError("FreeGS equilibrium linear solver is unavailable")
        callback_count = 0
        receipt["target"] = {
            "equilibrium_id": hex(id(eq)),
            "callback_id": hex(id(callback)),
            "callback_name": getattr(callback, "__name__", None),
            "callback_qualname": getattr(callback, "__qualname__", None),
            "callback_filename": getattr(getattr(callback, "__code__", None), "co_filename", None),
            "callback_identity_exact": True,
            "initial_solver_identity_exact": True,
            "grid_and_order_identity_exact": True,
            "target_psi_shape": list(shape),
            "frozen_edge_hashes": {
                name: _common._hash_float64(edges[name]) for name in EDGE_NAMES
            },
            "corner_compatibility": "all_four_corners_exact",
            "method": "fixed_observed_Dirichlet_dof_elimination",
            "psi_bndry_proxy_write": False,
            "picard_controls_changed": False,
            "physical_boundary_flux_claim": False,
            "physics_credit": False,
        }

        def callback_with_receipt(target: Any, jtor: Any, psi: Any) -> Any:
            nonlocal callback_count
            if target is not eq or getattr(eq, "_applyBoundary", None) is not callback_with_receipt:
                raise RuntimeError("observed boundary callback target identity changed")
            array = np.asarray(psi)
            if array.dtype != np.dtype(np.float64) or array.shape != shape:
                raise RuntimeError("observed callback array dtype/shape differs from frozen grid")
            interior_before = _common._hash_float64(array[1:-1, 1:-1])
            result = callback(target, jtor, psi)
            interior_after = _common._hash_float64(array[1:-1, 1:-1])
            edge_state = _common._edge_snapshot(array, edges)
            receipt["boundary_callback_events"].append({
                "event_index": len(receipt["boundary_callback_events"]) + 1,
                "callback_identity_exact": True,
                "target_equilibrium_identity_exact": True,
                "edge_after_callback": edge_state,
                "interior_sha256_before": interior_before,
                "interior_sha256_after": interior_after,
                "interior_unchanged": interior_before == interior_after,
                "return_was_none": result is None,
            })
            if interior_before != interior_after or not all(
                item["exact"] for item in edge_state.values()
            ):
                raise RuntimeError("observed callback changed interior or missed an exact edge")
            callback_count += 1
            return result

        def boundary_update_with_receipt(*update_args: Any, **update_kwargs: Any) -> Any:
            supplied_psi = update_kwargs.get(
                "psi", update_args[0] if update_args else None
            )
            if supplied_psi is None:
                supplied_psi = eq.psi()
            before = _common._finite_scalar(getattr(eq, "psi_bndry", None))
            result = original_bound_update(*update_args, **update_kwargs)
            after = _common._finite_scalar(getattr(eq, "psi_bndry", None))
            corner = None
            try:
                corner = _common._finite_scalar(np.asarray(supplied_psi)[0, 0])
            except (TypeError, ValueError, IndexError, AttributeError):
                pass
            receipt["boundary_scalar_events"].append({
                "event_index": len(receipt["boundary_scalar_events"]) + 1,
                "previous_psi_bndry": before,
                "native_post_update_psi_bndry": after,
                "corner_psi_0_0": corner,
                "read_only_observed_box_corner_diagnostic":
                    corner if before is not None and after is None else None,
                "solver_psi_bndry_mutated": False,
                "solver_psi_bndry_write_attempted": False,
                "picard_stop_effect": "native_eq_psi_bndry_value_preserved",
                "target_equilibrium_identity_exact": True,
            })
            if _common._finite_scalar(getattr(eq, "psi_bndry", None)) != after:
                raise RuntimeError("boundary diagnostic changed native psi_bndry")
            return result

        try:
            if test_operator_builder is None:
                matrix, operator_identity = _pinned_order4_operator(eq, equilibrium_class)
            else:
                matrix = test_operator_builder(eq)
                operator_identity = {
                    "generator": "injected_fake_test_operator",
                    "solver": "fake-test-only",
                }
            reduced_solver = ReducedDirichletLinearSystem(
                matrix, shape, edges, receipt=receipt,
                callback_count=lambda: callback_count,
            )
            receipt["target"]["operator_identity"] = operator_identity
            receipt["target"]["original_solver_identity"] = (
                f"{type(old_solver).__module__}.{type(old_solver).__qualname__}"
            )
            eq._applyBoundary = callback_with_receipt
            eq._updateBoundaryPsi = boundary_update_with_receipt
            eq._solver = reduced_solver
            result = original_solver(eq, *args, **kwargs)
            receipt["target"]["formal_freegs_solve_returned"] = True
            return result
        except BaseException as exc:
            receipt["target"]["formal_freegs_solve_returned"] = False
            receipt["target"]["target_exception"] = {
                "type": type(exc).__name__, "message": str(exc)
            }
            raise
        finally:
            for name, (had_value, value) in saved.items():
                if had_value:
                    setattr(eq, name, value)
                else:
                    instance_dict.pop(name, None)
            receipt["restoration"]["target_instance_solver_and_hooks_restored"] = all(
                (
                    getattr(eq, name, None) is value
                    if had_value else name not in instance_dict
                )
                for name, (had_value, value) in saved.items()
            )

    try:
        equilibrium_class.__init__ = init_with_registration
        solver_owner.solve = solve_for_marked_target
        yield
    finally:
        equilibrium_class.__init__ = original_init
        if had_solver:
            solver_owner.solve = saved_solver
        else:
            owner_dict.pop("solve", None)
        receipt["restoration"]["class_initializer_restored"] = (
            equilibrium_class.__init__ is original_init
        )
        receipt["restoration"]["solver_owner_restored"] = (
            getattr(solver_owner, "__dict__", {}).get("solve", _MISSING) is saved_solver
            if had_solver else "solve" not in getattr(solver_owner, "__dict__", {})
        )
        receipt["restoration"]["completed"] = bool(
            receipt["restoration"]["class_initializer_restored"]
            and receipt["restoration"]["solver_owner_restored"]
            and receipt["restoration"].get("target_instance_solver_and_hooks_restored", True)
        )
