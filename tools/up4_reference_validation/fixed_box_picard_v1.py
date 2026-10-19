"""Proposed v14 fixed-box Picard iteration for FreeGS 0.8.2.

This module is a numerical-method candidate, not a dispatchable solver.  It
uses the pinned Equilibrium.solve API with the caller's original profile,
psi_bndry input, and observed four-edge Dirichlet callback.  It removes only
FreeGS picard.solve's separatrix-scalar stopping conjunct; it never assigns
eq.psi_bndry and it does not alter the profile, source, boundary arrays, or
the rtol/atol tests on psi.

The returned convergence state is a discrete Picard fixed-point observation,
not a Grad-Shafranov residual acceptance result or physical validation.
"""

from __future__ import annotations

from dataclasses import dataclass
import hashlib
import math
from typing import Any, Mapping

import numpy as np


EDGE_NAMES = ("r_min", "r_max", "z_min", "z_max")
STRATEGY_ID = "fixed-observed-box-psi-delta-picard-v1-proposal"


@dataclass(frozen=True)
class FixedBoxPicardResult:
    """One terminal observation from the proposed fixed-box Picard driver."""

    status: str
    converged: bool
    outer_picard_iterations: int
    eq_solve_attempt_count: int
    eq_solve_completed_count: int
    requested_maxits: int
    maximum_eq_solve_calls_from_pinned_guard: int
    final_max_abs_change: float | None
    final_relative_change: float | None
    requested_rtol: float
    requested_atol: float
    requested_blend: float
    final_psi: np.ndarray
    iteration_history: tuple[dict[str, Any], ...]


def _array_sha256(value: Any) -> str:
    array = np.ascontiguousarray(np.asarray(value))
    return hashlib.sha256(array.tobytes(order="C")).hexdigest()


def _edge_views(psi: np.ndarray) -> dict[str, np.ndarray]:
    return {
        "r_min": psi[0, :],
        "r_max": psi[-1, :],
        "z_min": psi[:, 0],
        "z_max": psi[:, -1],
    }


def _validate_edges(expected_edges: Mapping[str, Any], shape: tuple[int, ...]) -> dict[str, np.ndarray]:
    if set(expected_edges) != set(EDGE_NAMES):
        raise ValueError("expected_edges must contain exactly r_min/r_max/z_min/z_max")
    if len(shape) != 2 or min(shape) < 3:
        raise ValueError("fixed-box psi must be a two-dimensional interior grid")
    edges = {name: np.asarray(expected_edges[name]) for name in EDGE_NAMES}
    expected_shapes = {
        "r_min": (shape[1],),
        "r_max": (shape[1],),
        "z_min": (shape[0],),
        "z_max": (shape[0],),
    }
    for name, edge in edges.items():
        if edge.shape != expected_shapes[name]:
            raise ValueError(f"fixed-box edge {name} has shape {edge.shape}, expected {expected_shapes[name]}")
        if not bool(np.isfinite(edge).all()):
            raise ValueError(f"fixed-box edge {name} contains non-finite values")

    corners = (
        (edges["r_min"][0], edges["z_min"][0]),
        (edges["r_min"][-1], edges["z_max"][0]),
        (edges["r_max"][0], edges["z_min"][-1]),
        (edges["r_max"][-1], edges["z_max"][-1]),
    )
    if not all(bool(left == right) for left, right in corners):
        raise ValueError("frozen fixed-box Dirichlet edge arrays are not exactly corner-compatible")
    return edges


def _edge_exactness(psi: np.ndarray, expected: Mapping[str, np.ndarray]) -> dict[str, bool]:
    actual = _edge_views(psi)
    return {name: bool(np.array_equal(actual[name], expected[name])) for name in EDGE_NAMES}


def _record_boundary_scalar(value: Any) -> float | None | dict[str, str]:
    if value is None:
        return None
    try:
        scalar = float(value)
    except (TypeError, ValueError, OverflowError):
        return {"type": type(value).__name__, "repr": repr(value)}
    if not math.isfinite(scalar):
        return {"nonfinite": repr(scalar)}
    return scalar


def fixed_box_picard_solve(
    eq: Any,
    profiles: Any,
    *,
    psi_bndry: float | None,
    expected_edges: Mapping[str, Any],
    rtol: float,
    atol: float,
    blend: float,
    maxits: int,
) -> tuple[FixedBoxPicardResult, dict[str, Any]]:
    """Run a proposal-only outer Picard loop over ``eq.solve``.

    The loop follows FreeGS 0.8.2 ``picard.solve`` ordering, except it checks
    only that call's existing psi maximum/relative change criterion.  Pinned
    FreeGS increments ``iteration`` after a failed convergence check and raises
    only when ``iteration > maxits``; therefore a supplied maxits of N permits
    at most N+1 calls to ``Equilibrium.solve``.  This function preserves that
    ordering and reports both counts explicitly.

    The exact frozen observed edges are an invariant checked before the first
    solve and after every completed solve.  The function never projects/writes
    edges and never writes ``eq.psi_bndry``; any edge mismatch is a typed
    numerical failure in the returned result.

    Final GS residual evaluation is intentionally outside this routine.  The
    caller must run the existing independent residual measurement on final
    ``eq.psi()`` and the actual final ``eq.Jtor``; no residual threshold is
    defined here.
    """
    if not callable(getattr(eq, "solve", None)) or not callable(getattr(eq, "psi", None)):
        raise TypeError("eq must expose callable pinned FreeGS solve() and psi() methods")
    if not isinstance(maxits, int) or isinstance(maxits, bool) or maxits < 1:
        raise ValueError("maxits must be a positive integer; unbounded/zero limits are unsupported")
    rtol = float(rtol)
    atol = float(atol)
    blend = float(blend)
    if not (math.isfinite(rtol) and rtol > 0.0):
        raise ValueError("rtol must be finite and positive")
    if not (math.isfinite(atol) and atol > 0.0):
        raise ValueError("atol must be finite and positive")
    if not (math.isfinite(blend) and 0.0 <= blend <= 1.0):
        raise ValueError("blend must be finite and within [0, 1]")

    psi = np.asarray(eq.psi())
    if psi.ndim != 2 or not bool(np.isfinite(psi).all()):
        raise ValueError("initial equilibrium psi must be a finite two-dimensional array")
    edges = _validate_edges(expected_edges, tuple(psi.shape))
    initial_exactness = _edge_exactness(psi, edges)
    if not all(initial_exactness.values()):
        raise ValueError("initial equilibrium psi does not exactly match the frozen observed edges")

    receipt: dict[str, Any] = {
        "strategy_id": STRATEGY_ID,
        "status": "running",
        "convergence_semantics": "psi_delta_only; separatrix_boundary_scalar_not_a_stop_gate",
        "physics_credit": False,
        "residual_acceptance_threshold": "typed_absent_not_defined",
        "requested_rtol": rtol,
        "requested_atol": atol,
        "requested_maxits": maxits,
        "requested_blend": blend,
        "input_psi_sha256": _array_sha256(psi),
        "frozen_edge_sha256": {name: _array_sha256(edges[name]) for name in EDGE_NAMES},
        "initial_edge_exactness": initial_exactness,
        "maximum_eq_solve_calls_from_pinned_guard": maxits + 1,
        "explicit_source_psi_bndry_argument": _record_boundary_scalar(psi_bndry),
        "native_eq_psi_bndry_initial": _record_boundary_scalar(getattr(eq, "psi_bndry", None)),
        "outer_picard_iterations_started": 0,
        "outer_picard_iterations_completed": 0,
        "eq_solve_attempt_count": 0,
        "eq_solve_completed_count": 0,
        "eq_solve_in_progress": False,
        "driver_eq_psi_bndry_write_attempted": False,
        "iteration_history": [],
        "final_independent_gs_residual": "not_computed_by_iteration_driver",
    }

    history: list[dict[str, Any]] = []
    final_maxchange: float | None = None
    final_relchange: float | None = None

    for iteration_index in range(maxits + 1):
        iteration_number = iteration_index + 1
        psi_last = np.asarray(psi).copy()
        receipt["outer_picard_iterations_started"] = iteration_number
        receipt["eq_solve_attempt_count"] += 1
        receipt["eq_solve_in_progress"] = True
        native_boundary_before = _record_boundary_scalar(getattr(eq, "psi_bndry", None))

        # Mirrors the pinned caller's `check_limited=False` setting and exact
        # Equilibrium.solve call signature used by FreeGS 0.8.2 picard.solve.
        eq.check_limited = False
        try:
            eq.solve(profiles, psi=psi, psi_bndry=psi_bndry)
        except BaseException as exc:
            receipt["eq_solve_in_progress"] = False
            receipt["status"] = "solver_call_exception"
            receipt["last_call_exception_type"] = type(exc).__name__
            receipt["last_call_exception_message"] = str(exc)
            receipt["last_call_native_eq_psi_bndry_before"] = native_boundary_before
            receipt["last_call_native_eq_psi_bndry_after"] = _record_boundary_scalar(
                getattr(eq, "psi_bndry", None)
            )
            receipt["iteration_history"] = history
            # Keep the backend exception's identity/type and attach the actual
            # partial loop receipt for an outer runner to serialize.
            try:
                setattr(exc, "fixed_box_picard_receipt", receipt)
            except Exception:
                pass
            raise

        receipt["eq_solve_in_progress"] = False
        receipt["eq_solve_completed_count"] += 1
        receipt["outer_picard_iterations_completed"] = iteration_number
        psi = np.asarray(eq.psi())
        native_boundary_after = _record_boundary_scalar(getattr(eq, "psi_bndry", None))
        if psi.shape != psi_last.shape:
            receipt["status"] = "numerical_fail_psi_shape_changed"
            receipt["iteration_history"] = history
            raise RuntimeError("Equilibrium.solve changed the psi grid shape")

        if not bool(np.isfinite(psi).all()):
            history.append({
                "iteration": iteration_number,
                "eq_solve_call_index": receipt["eq_solve_completed_count"],
                "psi_input_sha256": _array_sha256(psi_last),
                "psi_output_sha256": _array_sha256(psi),
                "native_eq_psi_bndry_before": native_boundary_before,
                "native_eq_psi_bndry_after": native_boundary_after,
                "finite_output": False,
                "edge_exactness": _edge_exactness(psi, edges),
                "criterion_met": False,
            })
            receipt["status"] = "numerical_fail_nonfinite_psi"
            receipt["iteration_history"] = history
            break

        change = psi_last - psi
        final_maxchange = float(np.max(np.abs(change)))
        psi_range = float(np.max(psi) - np.min(psi))
        with np.errstate(divide="ignore", invalid="ignore"):
            final_relchange = float(np.divide(final_maxchange, psi_range))
        edge_exactness = _edge_exactness(psi, edges)
        psi_criterion = (final_maxchange < atol) or (final_relchange < rtol)
        edges_exact = all(edge_exactness.values())
        converged = bool(psi_criterion and edges_exact)
        history.append({
            "iteration": iteration_number,
            "eq_solve_call_index": receipt["eq_solve_completed_count"],
            "psi_input_sha256": _array_sha256(psi_last),
            "psi_output_sha256": _array_sha256(psi),
            "native_eq_psi_bndry_before": native_boundary_before,
            "native_eq_psi_bndry_after": native_boundary_after,
            "psi_max_abs_change_wb_per_rad": final_maxchange,
            "psi_range_wb_per_rad": psi_range,
            "psi_relative_change": final_relchange,
            "atol_criterion_met": bool(final_maxchange < atol),
            "rtol_criterion_met": bool(final_relchange < rtol),
            "edge_exactness": edge_exactness,
            "finite_output": True,
            "criterion_met": converged,
        })

        if not edges_exact:
            receipt["status"] = "numerical_fail_observed_edge_invariant"
            receipt["iteration_history"] = history
            break
        if converged:
            receipt["status"] = "picard_converged_by_psi_delta_only"
            receipt["iteration_history"] = history
            break
        if iteration_index == maxits:
            receipt["status"] = "numerical_fail_iteration_limit"
            receipt["iteration_history"] = history
            break

        # This is FreeGS 0.8.2's post-step blend expression. Frozen v10 uses
        # blend=0; retaining the expression documents the complete API logic.
        psi = (1.0 - blend) * np.asarray(eq.psi()) + blend * psi_last

    receipt["final_max_abs_change"] = final_maxchange
    receipt["final_relative_change"] = final_relchange
    receipt["final_psi_sha256"] = _array_sha256(psi)
    receipt["iteration_history"] = history
    terminal_converged = receipt["status"] == "picard_converged_by_psi_delta_only"
    result = FixedBoxPicardResult(
        status=str(receipt["status"]),
        converged=terminal_converged,
        outer_picard_iterations=int(receipt["outer_picard_iterations_completed"]),
        eq_solve_attempt_count=int(receipt["eq_solve_attempt_count"]),
        eq_solve_completed_count=int(receipt["eq_solve_completed_count"]),
        requested_maxits=maxits,
        maximum_eq_solve_calls_from_pinned_guard=maxits + 1,
        final_max_abs_change=final_maxchange,
        final_relative_change=final_relchange,
        requested_rtol=rtol,
        requested_atol=atol,
        requested_blend=blend,
        final_psi=np.asarray(eq.psi()).copy(),
        iteration_history=tuple(history),
    )
    return result, receipt
