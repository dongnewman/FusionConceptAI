"""Scoped FreeGS 0.8.2 adapter for exact observed box-edge updates.

This adapter is a versioned test-only numerical candidate, not a physics
validator. It reapplies the four frozen observed edges only to the marked
target equilibrium, immediately before FreeGS updates its spline and boundary
metadata. A strict pre-projection roundoff cap prevents the adapter from
hiding a material solver boundary change. Interior samples, source values,
controls, and the runner's exact postprocess edge gate are unchanged.

When the native boundary update changes ``eq.psi_bndry`` from finite to None,
the adapter may record the finite observed-box corner as a read-only diagnostic.
It never writes that value to ``eq.psi_bndry``. Pinned FreeGS 0.8.2
``picard.solve`` reads ``eq.psi_bndry`` in its ``bndry_relchange`` convergence
stop, so leaving the native value unchanged preserves native stopping behavior.
The recorded corner is not a separatrix/physical boundary flux and carries no
physics credit.
"""

from __future__ import annotations

from contextlib import contextmanager
import hashlib
import inspect
import math
import os
from pathlib import Path
import sys
from typing import Any, Iterator, Mapping


_MISSING = object()
MAX_PREPROJECT_DELTA_WB_PER_RAD = 1.0e-12
PINNED_FREEGS_SOURCE_SHA256 = {
    "equilibrium.py": "1eece1ff87587a90aeba662b1ab15bb313d1e1493b140074db33e8b2ff93567e",
    "picard.py": "731722b98c97dfd758428a411dce684806e36e8cb6e38e69f23552451646880f",
    "boundary.py": "919556898783ba9fd99533ed787976c38562aa9eb5b037feb896cce02acf57ca",
    "jtor.py": "5aea52eaae072bf50e761b0dc6a7e65c93f6a657297d7a60daec1d238f27f61b",
}
EDGE_NAMES = ("r_min", "r_max", "z_min", "z_max")


def _normalised_path(path: str | os.PathLike[str]) -> str:
    return os.path.normcase(os.path.realpath(os.fspath(path)))


def is_pinned_observed_dirichlet_callback(
    callback: Any, expected_runner_file: str | os.PathLike[str]
) -> bool:
    code = getattr(callback, "__code__", None)
    return bool(
        code is not None
        and getattr(callback, "__name__", None) == "observed_dirichlet_boundary"
        and getattr(callback, "__qualname__", None)
        == "solve.<locals>.observed_dirichlet_boundary"
        and code.co_name == "observed_dirichlet_boundary"
        and _normalised_path(code.co_filename)
        == _normalised_path(expected_runner_file)
    )


def _np() -> Any:
    import numpy as np

    return np


def _finite_scalar(value: Any) -> float | None:
    try:
        scalar = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return scalar if math.isfinite(scalar) else None


def _hash_float64(values: Any) -> str:
    np = _np()
    array = np.ascontiguousarray(np.asarray(values), dtype=np.dtype("<f8"))
    return hashlib.sha256(array.tobytes(order="C")).hexdigest()


def _edge_arrays(callback: Any) -> dict[str, Any]:
    """Read the exact frozen edge arrays closed over by the pinned v2 callback."""
    np = _np()
    try:
        closure = inspect.getclosurevars(callback).nonlocals
    except (TypeError, ValueError) as exc:
        raise RuntimeError("observed boundary callback closure is unavailable") from exc
    raw_edges = closure.get("boundary_edges")
    if not isinstance(raw_edges, Mapping) or set(raw_edges) != set(EDGE_NAMES):
        raise RuntimeError("observed callback does not close over the exact four boundary edges")
    edges: dict[str, Any] = {}
    for name in EDGE_NAMES:
        array = np.asarray(raw_edges[name])
        if array.ndim != 1 or array.dtype.kind != "f" or array.dtype.itemsize != 8:
            raise RuntimeError(f"observed boundary edge has an unexpected dtype/shape: {name}")
        if not bool(np.isfinite(array).all()):
            raise RuntimeError(f"observed boundary edge is non-finite: {name}")
        edges[name] = np.array(array, dtype=np.dtype("<f8"), copy=True)
    if edges["r_min"].size != edges["r_max"].size:
        raise RuntimeError("radial observed boundary edge lengths differ")
    if edges["z_min"].size != edges["z_max"].size:
        raise RuntimeError("vertical observed boundary edge lengths differ")
    corners = (
        edges["r_min"][0] == edges["z_min"][0],
        edges["r_min"][-1] == edges["z_max"][0],
        edges["r_max"][0] == edges["z_min"][-1],
        edges["r_max"][-1] == edges["z_max"][-1],
    )
    if not all(bool(value) for value in corners):
        raise RuntimeError("frozen observed Dirichlet edges have incompatible corners")
    return edges


def _source_root(equilibrium_class: type) -> Path:
    module = sys.modules.get(getattr(equilibrium_class, "__module__", ""))
    module_file = getattr(module, "__file__", None)
    if module_file is None or Path(module_file).name != "equilibrium.py":
        raise RuntimeError("pinned FreeGS Equilibrium module is unavailable")
    return Path(module_file).resolve().parent


def verify_pinned_freegs_sources(equilibrium_class: type) -> dict[str, str]:
    source_root = _source_root(equilibrium_class)
    method = getattr(equilibrium_class, "_updateBoundaryPsi", None)
    code = getattr(method, "__code__", None)
    if code is None or code.co_name != "_updateBoundaryPsi" or _normalised_path(
        code.co_filename
    ) != _normalised_path(source_root / "equilibrium.py"):
        raise RuntimeError("FreeGS _updateBoundaryPsi API differs from the pinned source")
    try:
        signature = inspect.signature(method)
    except (TypeError, ValueError) as exc:
        raise RuntimeError("FreeGS _updateBoundaryPsi API cannot be inspected") from exc
    if list(signature.parameters) != ["self", "psi"]:
        raise RuntimeError("FreeGS _updateBoundaryPsi signature differs from the pinned API")
    observed: dict[str, str] = {}
    for filename, expected in PINNED_FREEGS_SOURCE_SHA256.items():
        path = source_root / filename
        if not path.is_file():
            raise RuntimeError(f"pinned FreeGS source is missing: {filename}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != expected:
            raise RuntimeError(f"pinned FreeGS source hash mismatch for {filename}")
        observed[filename] = digest
    return observed


def verify_pinned_freegs_solve_api(
    freegs_package: Any, picard_module: Any, source_root: str | os.PathLike[str]
) -> None:
    public_solve = getattr(freegs_package, "solve", None)
    picard_solve = getattr(picard_module, "solve", None)
    code = getattr(picard_solve, "__code__", None)
    if public_solve is not picard_solve or code is None or code.co_name != "solve":
        raise RuntimeError("FreeGS public solve API differs from the pinned Picard solver")
    if _normalised_path(code.co_filename) != _normalised_path(Path(source_root) / "picard.py"):
        raise RuntimeError("FreeGS Picard solver source path differs from the pinned package")
    try:
        signature = inspect.signature(picard_solve)
    except (TypeError, ValueError) as exc:
        raise RuntimeError("FreeGS Picard solve API cannot be inspected") from exc
    expected = [
        "eq", "profiles", "constrain", "rtol", "atol", "blend", "show", "axis",
        "pause", "psi_bndry", "maxits", "convergenceInfo", "check_limited",
        "wait_for_limited", "limit_it",
    ]
    if list(signature.parameters) != expected:
        raise RuntimeError("FreeGS Picard solve signature differs from the pinned API")


def _edge_snapshot(array: Any, edges: Mapping[str, Any]) -> dict[str, Any]:
    np = _np()
    actual = {
        "r_min": array[0, :], "r_max": array[-1, :],
        "z_min": array[:, 0], "z_max": array[:, -1],
    }
    result: dict[str, Any] = {}
    for name in EDGE_NAMES:
        values = np.asarray(actual[name], dtype=np.dtype("<f8"))
        expected = np.asarray(edges[name], dtype=np.dtype("<f8"))
        delta = values - expected
        maximum = float(np.max(np.abs(delta)))
        result[name] = {
            "values_sha256": _hash_float64(values),
            "expected_sha256": _hash_float64(expected),
            "exact": bool(np.array_equal(values, expected)),
            "max_abs_delta_wb_per_rad": maximum,
            "max_delta_index": int(np.argmax(np.abs(delta))),
        }
    return result


def _interior(array: Any) -> Any:
    return array[1:-1, 1:-1]


@contextmanager
def temporary_observed_dirichlet_projection(
    equilibrium_class: type,
    expected_runner_file: str | os.PathLike[str],
    *,
    solver_owner: Any,
    receipt: dict[str, Any],
) -> Iterator[None]:
    """Reproject only the marked target before its pinned update method runs.

    The exact four source edges are extracted from the pinned callback closure.
    Reprojection fails closed above the frozen 1e-12 Wb/rad per-sample cap and
    verifies the interior byte hash before calling FreeGS' original
    ``_updatePlasmaPsi`` so spline/critical metadata are rebuilt from the
    projected array. Every global/instance hook is restored in ``finally``.
    """
    np = _np()
    if solver_owner is None:
        raise RuntimeError("pinned FreeGS solve owner is unavailable")
    original_init = equilibrium_class.__init__
    registered: dict[int, tuple[Any, Any, dict[str, Any], tuple[int, int]]] = {}
    owner_dict = getattr(solver_owner, "__dict__", None)
    if not isinstance(owner_dict, dict):
        raise RuntimeError("FreeGS solve owner cannot be safely restored")
    had_solver = "solve" in owner_dict
    saved_solver = owner_dict.get("solve", _MISSING)
    original_solver = getattr(solver_owner, "solve", None)
    if not callable(original_solver):
        raise RuntimeError("pinned FreeGS top-level solve API is unavailable")
    receipt.setdefault("schema", "fusionconceptai:freegs-observed-dirichlet-adapter-receipt-v3")
    receipt.setdefault("runner_revision", "runtime-v4-freegs-axisymmetric-profile-execution-v5-observed-box-corner-diagnostic")
    receipt.setdefault("adapter_status", "armed_for_exact_marked_callback_only")
    receipt.setdefault("target", None)
    receipt.setdefault("boundary_callback_events", [])
    receipt.setdefault("boundary_scalar_events", [])
    receipt.setdefault("plasma_psi_projection_events", [])
    receipt.setdefault("restoration", {"completed": False})

    def init_with_registration(self: Any, *args: Any, **kwargs: Any) -> None:
        original_init(self, *args, **kwargs)
        callback = getattr(self, "_applyBoundary", None)
        if not is_pinned_observed_dirichlet_callback(callback, expected_runner_file):
            return
        edges = _edge_arrays(callback)
        shape = (int(edges["z_min"].size), int(edges["r_min"].size))
        if any(edges[name].size != (shape[1] if name.startswith("r_") else shape[0])
               for name in EDGE_NAMES):
            raise RuntimeError("observed boundary edges are incompatible with their grid shape")
        registered[id(self)] = (self, callback, edges, shape)

    def solve_for_marked_target(eq: Any, *args: Any, **kwargs: Any) -> Any:
        item = registered.get(id(eq))
        if item is None or item[0] is not eq:
            return original_solver(eq, *args, **kwargs)
        _, callback, edges, expected_shape = item
        if getattr(eq, "_applyBoundary", None) is not callback:
            receipt["adapter_status"] = "skipped_callback_identity_changed"
            return original_solver(eq, *args, **kwargs)
        instance_dict = getattr(eq, "__dict__", None)
        if not isinstance(instance_dict, dict):
            raise RuntimeError("FreeGS Equilibrium instance cannot be safely restored")
        saved = {}
        for name in ("_applyBoundary", "_updateBoundaryPsi", "_updatePlasmaPsi"):
            saved[name] = (name in instance_dict, instance_dict.get(name, _MISSING))
        original_bound_update = eq._updateBoundaryPsi
        original_bound_plasma_update = eq._updatePlasmaPsi
        initial_boundary = getattr(eq, "psi_bndry", _MISSING)
        receipt["target"] = {
            "equilibrium_id": hex(id(eq)),
            "callback_id": hex(id(callback)),
            "callback_name": getattr(callback, "__name__", None),
            "callback_qualname": getattr(callback, "__qualname__", None),
            "callback_filename": getattr(getattr(callback, "__code__", None), "co_filename", None),
            "callback_code_firstlineno": getattr(getattr(callback, "__code__", None), "co_firstlineno", None),
            "callback_identity_exact": True,
            "target_eq_psi_bndry_before_freegs_solve": _finite_scalar(initial_boundary),
            "target_psi_shape": list(expected_shape),
            "frozen_edge_hashes": {name: _hash_float64(edges[name]) for name in EDGE_NAMES},
            "corner_compatibility": "all_four_corners_exact",
            "preprojection_roundoff_cap_wb_per_rad": MAX_PREPROJECT_DELTA_WB_PER_RAD,
            "boundary_scalar_label": "read-only observed-box corner diagnostic; not separatrix/physical plasma boundary flux",
            "picard_stop_semantics": {
                "classification": "read_only_diagnostic_does_not_change_solver_stopping_behavior",
                "mechanism": "FreeGS 0.8.2 picard.solve reads eq.psi_bndry in its bndry_relchange convergence stop; adapter leaves it unchanged",
                "pinned_picard_source_sha256": PINNED_FREEGS_SOURCE_SHA256["picard.py"],
                "solver_psi_bndry_mutated": False,
                "picard_stop_behavior": "native_eq_psi_bndry_value_preserved",
                "diagnostic_corner_used_by_picard": False,
                "physical_boundary_flux": False,
                "physics_credit": False,
            },
        }

        def callback_with_receipt(_eq: Any, jtor: Any, psi: Any) -> Any:
            if _eq is not eq or getattr(eq, "_applyBoundary", None) is not callback_with_receipt:
                raise RuntimeError("observed boundary callback target identity changed")
            array = np.asarray(psi)
            if array.ndim != 2 or tuple(array.shape) != expected_shape:
                raise RuntimeError("observed boundary callback received an unexpected psi grid")
            before_interior = _hash_float64(_interior(array))
            result = callback(_eq, jtor, psi)
            after_interior = _hash_float64(_interior(array))
            snapshot = _edge_snapshot(array, edges)
            event = {
                "event_index": len(receipt["boundary_callback_events"]) + 1,
                "callback_object_id": hex(id(callback)),
                "callback_identity_exact": True,
                "target_equilibrium_identity_exact": True,
                "psi_shape": list(array.shape),
                "interior_sha256_before": before_interior,
                "interior_sha256_after": after_interior,
                "interior_unchanged": before_interior == after_interior,
                "edge_after_callback": snapshot,
                "return_was_none": result is None,
            }
            receipt["boundary_callback_events"].append(event)
            if before_interior != after_interior or not all(x["exact"] for x in snapshot.values()):
                raise RuntimeError("pinned observed callback changed non-edge samples or missed an exact edge")
            return result

        def update_boundary_with_receipt(*update_args: Any, **update_kwargs: Any) -> Any:
            psi = update_kwargs.get("psi", update_args[0] if update_args else None)
            if psi is None:
                psi = eq.psi()
            previous = getattr(eq, "psi_bndry", _MISSING)
            previous_value = _finite_scalar(previous)
            result = original_bound_update(*update_args, **update_kwargs)
            native_after = getattr(eq, "psi_bndry", _MISSING)
            native_after_value = _finite_scalar(native_after)
            corner = None
            try:
                corner = _finite_scalar(np.asarray(psi)[0, 0])
            except (TypeError, ValueError, IndexError, AttributeError):
                pass
            event: dict[str, Any] = {
                "event_index": len(receipt["boundary_scalar_events"]) + 1,
                "target_equilibrium_identity_exact": True,
                "registered_original_callback_identity_exact": callback is item[1],
                "marked_callback_wrapper_active": getattr(eq, "_applyBoundary", None) is callback_with_receipt,
                "previous_psi_bndry": previous_value,
                "native_post_update_psi_bndry": native_after_value,
                "corner_psi_0_0": corner,
                "diagnostic_action": "skipped",
                "diagnostic_skip_reason": None,
                "observed_box_corner_diagnostic": None,
                "solver_psi_bndry_mutated": False,
                "solver_psi_bndry_write_attempted": False,
                "picard_stop_effect": "native_eq_psi_bndry_value_preserved",
            }
            if previous_value is None:
                event["diagnostic_skip_reason"] = "previous_boundary_not_finite"
            elif native_after is not None:
                event["diagnostic_skip_reason"] = "native_post_update_boundary_not_none"
            elif getattr(eq, "_applyBoundary", None) is not callback_with_receipt:
                event["diagnostic_skip_reason"] = "marked_callback_wrapper_not_active"
            elif corner is None:
                event["diagnostic_skip_reason"] = "corner_not_finite"
            else:
                event["diagnostic_action"] = "recorded_observed_box_corner_read_only"
                event["diagnostic_skip_reason"] = None
                event["observed_box_corner_diagnostic"] = corner
            event["final_psi_bndry_after_adapter"] = _finite_scalar(getattr(eq, "psi_bndry", None))
            event["solver_psi_bndry_mutated"] = False
            event["solver_psi_bndry_write_attempted"] = False
            receipt["boundary_scalar_events"].append(event)
            return result

        def update_plasma_with_projection(plasma_psi: Any) -> Any:
            if getattr(eq, "_applyBoundary", None) is not callback_with_receipt:
                raise RuntimeError("observed callback changed before plasma psi update")
            if not isinstance(plasma_psi, np.ndarray):
                raise RuntimeError("FreeGS _updatePlasmaPsi input is not a mutable ndarray")
            array = plasma_psi
            if array.dtype != np.dtype(np.float64) or not array.flags.writeable:
                raise RuntimeError("FreeGS plasma psi array dtype or writeability differs from the pinned API")
            if tuple(array.shape) != expected_shape:
                raise RuntimeError("FreeGS plasma psi shape differs from observed boundary grid")
            if not bool(np.isfinite(array).all()):
                raise RuntimeError("FreeGS plasma psi contains non-finite values before projection")
            interior_before = _hash_float64(_interior(array))
            interior_copy = _interior(array).copy()
            before = _edge_snapshot(array, edges)
            maximum = max(item["max_abs_delta_wb_per_rad"] for item in before.values())
            event: dict[str, Any] = {
                "event_index": len(receipt["plasma_psi_projection_events"]) + 1,
                "target_equilibrium_identity_exact": True,
                "registered_original_callback_identity_exact": callback is item[1],
                "projection_stage": "before_original_FreeGS__updatePlasmaPsi",
                "preprojection_edges": before,
                "preprojection_max_abs_delta_wb_per_rad": maximum,
                "preprojection_roundoff_cap_wb_per_rad": MAX_PREPROJECT_DELTA_WB_PER_RAD,
                "corner_compatibility": "all_four_corners_exact",
                "interior_sha256_before": interior_before,
                "projection_applied": False,
                "postprojection_edges": None,
                "interior_sha256_after": None,
                "interior_unchanged": None,
                "original_update_called": False,
            }
            receipt["plasma_psi_projection_events"].append(event)
            if maximum > MAX_PREPROJECT_DELTA_WB_PER_RAD:
                event["projection_abort_reason"] = "preprojection_delta_exceeds_frozen_roundoff_cap"
                raise RuntimeError("observed boundary drift exceeds frozen roundoff projection cap")
            # The source edge arrays are already mutually corner-compatible.  Row
            # assignments followed by column assignments therefore restore the
            # exact same corner values regardless of assignment order.
            array[0, :] = edges["r_min"]
            array[-1, :] = edges["r_max"]
            array[:, 0] = edges["z_min"]
            array[:, -1] = edges["z_max"]
            after = _edge_snapshot(array, edges)
            interior_after = _hash_float64(_interior(array))
            event["projection_applied"] = True
            event["postprojection_edges"] = after
            event["interior_sha256_after"] = interior_after
            event["interior_unchanged"] = bool(
                interior_before == interior_after and np.array_equal(interior_copy, _interior(array))
            )
            if not all(item["exact"] for item in after.values()):
                raise RuntimeError("exact observed edge projection failed")
            if not event["interior_unchanged"]:
                raise RuntimeError("observed edge projection changed interior psi samples")
            try:
                result = original_bound_plasma_update(plasma_psi)
                event["original_update_called"] = True
                event["original_update_returned"] = True
                event["final_eq_psi_sha256"] = _hash_float64(eq.psi())
                event["final_eq_edges"] = _edge_snapshot(np.asarray(eq.psi()), edges)
                event["final_eq_psi_bndry"] = _finite_scalar(getattr(eq, "psi_bndry", None))
                if not all(item["exact"] for item in event["final_eq_edges"].values()):
                    raise RuntimeError("FreeGS update did not retain the projected exact observed edges")
                return result
            except BaseException as exc:
                event["original_update_called"] = True
                event["original_update_exception"] = {"type": type(exc).__name__, "message": str(exc)}
                raise

        eq._applyBoundary = callback_with_receipt
        eq._updateBoundaryPsi = update_boundary_with_receipt
        eq._updatePlasmaPsi = update_plasma_with_projection
        try:
            return original_solver(eq, *args, **kwargs)
        finally:
            for name, (had_value, value) in saved.items():
                if had_value:
                    setattr(eq, name, value)
                else:
                    instance_dict.pop(name, None)
            receipt["restoration"]["target_instance_hooks_restored"] = all(
                getattr(eq, name, None) is value if had_value else name not in instance_dict
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
            and receipt["restoration"].get("target_instance_hooks_restored", True)
        )
