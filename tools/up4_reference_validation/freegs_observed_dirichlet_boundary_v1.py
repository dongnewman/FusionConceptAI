"""Scoped FreeGS 0.8.2 adapter for observed nonzero Dirichlet box boundaries.

FreeGS Equilibrium._updateBoundaryPsi recognises a fixed boundary by function
identity. The v2 reference runner must instead apply observed edge arrays, so
its callback cannot be freegs.boundary.fixedBoundary (which writes zero edges).
This adapter gives only the active main-solve instance an observed-box boundary
convergence proxy, without changing the edge arrays or claiming physical-boundary
flux semantics.
"""

from __future__ import annotations

from contextlib import contextmanager
import hashlib
import inspect
import math
import os
from pathlib import Path
import sys
from typing import Any, Iterator


_MISSING = object()
PINNED_FREEGS_SOURCE_SHA256 = {
    "equilibrium.py": "1eece1ff87587a90aeba662b1ab15bb313d1e1493b140074db33e8b2ff93567e",
    "picard.py": "731722b98c97dfd758428a411dce684806e36e8cb6e38e69f23552451646880f",
    "boundary.py": "919556898783ba9fd99533ed787976c38562aa9eb5b037feb896cce02acf57ca",
    "jtor.py": "5aea52eaae072bf50e761b0dc6a7e65c93f6a657297d7a60daec1d238f27f61b",
}


def _normalised_path(path: str | os.PathLike[str]) -> str:
    return os.path.normcase(os.path.realpath(os.fspath(path)))


def is_pinned_observed_dirichlet_callback(
    callback: Any, expected_runner_file: str | os.PathLike[str]
) -> bool:
    """Match only the observed callback defined by the pinned v2 runner."""
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


def verify_pinned_freegs_sources(equilibrium_class: type) -> dict[str, str]:
    """Verify the exact FreeGS source and method API used by this adapter."""
    module = sys.modules.get(getattr(equilibrium_class, "__module__", ""))
    module_file = getattr(module, "__file__", None)
    if module_file is None or Path(module_file).name != "equilibrium.py":
        raise RuntimeError("pinned FreeGS Equilibrium module is unavailable")

    equilibrium_path = Path(module_file).resolve()
    method = getattr(equilibrium_class, "_updateBoundaryPsi", None)
    code = getattr(method, "__code__", None)
    if (
        code is None
        or code.co_name != "_updateBoundaryPsi"
        or _normalised_path(code.co_filename) != _normalised_path(equilibrium_path)
    ):
        raise RuntimeError("FreeGS _updateBoundaryPsi API differs from the pinned source")
    try:
        signature = inspect.signature(method)
    except (TypeError, ValueError) as exc:
        raise RuntimeError("FreeGS _updateBoundaryPsi API cannot be inspected") from exc
    if list(signature.parameters) != ["self", "psi"]:
        raise RuntimeError("FreeGS _updateBoundaryPsi signature differs from the pinned API")

    return verify_pinned_freegs_source_tree(equilibrium_path.parent)


def verify_pinned_freegs_source_tree(source_root: str | os.PathLike[str]) -> dict[str, str]:
    """Fail closed unless all four behavior-defining FreeGS files are pinned."""
    source_root = Path(source_root)
    observed: dict[str, str] = {}
    for filename, expected_digest in PINNED_FREEGS_SOURCE_SHA256.items():
        path = source_root / filename
        if not path.is_file():
            raise RuntimeError(f"pinned FreeGS source is missing: {filename}")
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != expected_digest:
            raise RuntimeError(
                f"pinned FreeGS source hash mismatch for {filename}: "
                f"expected {expected_digest}, got {digest}"
            )
        observed[filename] = digest
    return observed


def verify_pinned_freegs_solve_api(
    freegs_package: Any,
    picard_module: Any,
    source_root: str | os.PathLike[str],
) -> None:
    """Require the public solve name to be the pinned Picard solver API."""
    public_solve = getattr(freegs_package, "solve", None)
    picard_solve = getattr(picard_module, "solve", None)
    code = getattr(picard_solve, "__code__", None)
    if public_solve is not picard_solve or code is None or code.co_name != "solve":
        raise RuntimeError("FreeGS public solve API differs from the pinned Picard solver")
    expected_file = Path(source_root) / "picard.py"
    if _normalised_path(code.co_filename) != _normalised_path(expected_file):
        raise RuntimeError("FreeGS Picard solver source path differs from the pinned package")
    try:
        signature = inspect.signature(picard_solve)
    except (TypeError, ValueError) as exc:
        raise RuntimeError("FreeGS Picard solve API cannot be inspected") from exc
    expected_parameters = [
        "eq", "profiles", "constrain", "rtol", "atol", "blend", "show", "axis",
        "pause", "psi_bndry", "maxits", "convergenceInfo", "check_limited",
        "wait_for_limited", "limit_it",
    ]
    if list(signature.parameters) != expected_parameters:
        raise RuntimeError("FreeGS Picard solve signature differs from the pinned API")


def _corner_value(psi: Any) -> float | None:
    try:
        try:
            value = psi[0, 0]
        except (TypeError, IndexError, KeyError):
            value = psi[0][0]
        scalar = float(value)
    except (TypeError, ValueError, OverflowError, IndexError, KeyError, AttributeError):
        return None
    return scalar if math.isfinite(scalar) else None


def _finite_scalar(value: Any) -> float | None:
    """Convert a scalar boundary value to finite float, otherwise return None."""
    try:
        scalar = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return scalar if math.isfinite(scalar) else None


@contextmanager
def temporary_observed_dirichlet_semantics(
    equilibrium_class: type,
    expected_runner_file: str | os.PathLike[str],
    *,
    solver_owner: Any | None = None,
) -> Iterator[None]:
    """Temporarily adapt only the marked instance passed to top-level solve.

    The class initializer is wrapped to register instances carrying the exact
    callback from the pinned v2 runner. No instance method is wrapped until that
    same object is passed to ``solver_owner.solve``. In particular, the v2
    pre-solve ``diagnostic_eq.solve`` path stays unchanged. The target method
    wrapper is restored as soon as the solver call returns or raises.

    On the target instance, a finite-to-None transition proves the pinned
    callback branch has no X-point. The corner scalar is an observed-box
    boundary convergence proxy, never separatrix or physical plasma boundary
    flux. The adapter does not project or rewrite the observed edge arrays.
    """
    original_init = equilibrium_class.__init__
    registered_instances: dict[int, tuple[Any, Any]] = {}
    original_solver = None
    solver_owner_dict: dict[str, Any] = {}
    had_instance_solver = False
    saved_instance_solver: Any = _MISSING

    def init_with_observed_boundary(self: Any, *args: Any, **kwargs: Any) -> None:
        original_init(self, *args, **kwargs)
        callback = getattr(self, "_applyBoundary", None)
        if not is_pinned_observed_dirichlet_callback(callback, expected_runner_file):
            return
        registered_instances[id(self)] = (self, callback)

    if solver_owner is not None:
        solver_owner_dict = getattr(solver_owner, "__dict__", None)
        if not isinstance(solver_owner_dict, dict):
            raise RuntimeError("FreeGS solve owner cannot be safely restored")
        had_instance_solver = "solve" in solver_owner_dict
        saved_instance_solver = solver_owner_dict.get("solve", _MISSING)
        original_solver = getattr(solver_owner, "solve", None)
        if not callable(original_solver):
            raise RuntimeError("pinned FreeGS top-level solve API is unavailable")

        def solve_for_active_equilibrium(eq: Any, *args: Any, **kwargs: Any) -> Any:
            registered = registered_instances.get(id(eq))
            if registered is None or registered[0] is not eq:
                return original_solver(eq, *args, **kwargs)
            callback = registered[1]
            if getattr(eq, "_applyBoundary", None) is not callback:
                return original_solver(eq, *args, **kwargs)

            instance_dict = getattr(eq, "__dict__", None)
            if not isinstance(instance_dict, dict):
                raise RuntimeError("FreeGS Equilibrium instance cannot be safely restored")
            had_instance_update = "_updateBoundaryPsi" in instance_dict
            saved_instance_update = instance_dict.get("_updateBoundaryPsi", _MISSING)
            original_bound_update = eq._updateBoundaryPsi

            def update_boundary_for_observed_edges(
                *update_args: Any, **update_kwargs: Any
            ) -> Any:
                if "psi" in update_kwargs:
                    psi = update_kwargs["psi"]
                elif update_args:
                    psi = update_args[0]
                else:
                    psi = None
                if psi is None:
                    psi = eq.psi()

                previous_boundary = getattr(eq, "psi_bndry", _MISSING)
                result = original_bound_update(*update_args, **update_kwargs)
                previous_boundary_value = (
                    None
                    if previous_boundary is _MISSING or previous_boundary is None
                    else _finite_scalar(previous_boundary)
                )
                boundary_was_lost = (
                    getattr(eq, "_applyBoundary", None) is callback
                    and previous_boundary_value is not None
                    and getattr(eq, "psi_bndry", _MISSING) is None
                )
                if boundary_was_lost:
                    corner = _corner_value(psi)
                    if corner is not None:
                        # Metadata-only convergence proxy; never rewrite box edges.
                        eq.psi_bndry = corner
                return result

            eq._updateBoundaryPsi = update_boundary_for_observed_edges
            try:
                return original_solver(eq, *args, **kwargs)
            finally:
                if had_instance_update:
                    eq._updateBoundaryPsi = saved_instance_update
                else:
                    instance_dict.pop("_updateBoundaryPsi", None)

    try:
        equilibrium_class.__init__ = init_with_observed_boundary
        if solver_owner is not None:
            solver_owner.solve = solve_for_active_equilibrium
        yield
    finally:
        equilibrium_class.__init__ = original_init
        if solver_owner is not None:
            if had_instance_solver:
                solver_owner.solve = saved_instance_solver
            else:
                solver_owner_dict.pop("solve", None)
