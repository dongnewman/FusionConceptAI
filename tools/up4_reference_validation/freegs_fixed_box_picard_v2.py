"""Versioned Picard policy for a prescribed, observed four-edge Dirichlet box.

This policy is deliberately separate from ``freegs.picard.solve``.  It keeps
FreeGS 0.8.2's profile/Equilibrium.solve ordering, psi-change formula,
``rtol``/``atol`` tests, blending parameter, and maxits counter semantics, but
uses the fixed observed edge vector as the boundary convergence state.  It
never reads or writes ``eq.psi_bndry`` to manufacture a scalar boundary flux.
The edge vector is required to remain byte-identical to the frozen input at
every solve call.  A terminal X-point or limited state fails closed; transient
X-points are recorded and may disappear during the solve.  This is a
test-only numerical policy and never grants physical or inverse credit.
"""

from __future__ import annotations

import base64
import hashlib
import inspect
import math
import re
import struct
from typing import Any, MutableMapping

import numpy as np


POLICY_REVISION = "freegs-fixed-observed-box-dirichlet-picard-v2"
NATIVE_PICARD_REVISION = "freegs.picard.solve-0.8.2"
NONCONVERGENCE_MESSAGE = (
    "fixed observed-box Dirichlet Picard policy failed to converge "
    "within configured maxits"
)


class FixedBoxPicardError(RuntimeError):
    """Base class for explicit, classified fixed-box solver outcomes."""


class FixedBoxPicardNonconvergence(FixedBoxPicardError):
    """The policy reached its configured iteration limit."""


class FixedBoxBoundaryDriftError(FixedBoxPicardError):
    """A prescribed edge changed, including a signed-zero byte change."""


class FixedBoxTerminalTopologyUnsupported(FixedBoxPicardError):
    """The converged candidate still has an X-point or is limited."""


class FixedBoxTopologyObservationUnavailable(FixedBoxPicardError):
    """The observer did not provide a complete terminal topology record."""


class FixedBoxNumericalStateError(FixedBoxPicardError):
    """A non-finite, malformed, or degenerate numerical state was observed."""


def _float64_bytes(values: Any) -> bytes:
    array = np.asarray(values)
    if array.dtype.kind != "f" or array.dtype.itemsize != 8:
        raise FixedBoxBoundaryDriftError("boundary values must remain float64")
    return np.ascontiguousarray(array, dtype=np.dtype("<f8")).tobytes(order="C")


def _edge_views(psi: Any) -> dict[str, Any]:
    array = np.asarray(psi)
    if array.ndim != 2 or array.dtype != np.dtype(np.float64):
        raise FixedBoxBoundaryDriftError("psi must be a float64 two-dimensional grid")
    if min(array.shape) < 3:
        raise FixedBoxBoundaryDriftError("psi grid is too small for a four-edge interior")
    return {
        "r_min": array[0, :],
        "r_max": array[-1, :],
        "z_min": array[:, 0],
        "z_max": array[:, -1],
    }


def _copy_frozen_edges_from_adapter_callback(eq: Any) -> dict[str, np.ndarray]:
    """Read the already hash-pinned v16 adapter's immutable edge closure.

    The actual runner pins the v16 adapter source and only calls this after its
    marked callback has been installed on the target Equilibrium.  Tests use a
    fake callback with the same explicit ``edges`` closure field.
    """
    callback = getattr(eq, "_applyBoundary", None)
    try:
        closure = inspect.getclosurevars(callback).nonlocals
    except (TypeError, ValueError) as exc:
        raise FixedBoxBoundaryDriftError(
            "marked observed-boundary callback closure is unavailable"
        ) from exc
    edges = closure.get("edges")
    if not isinstance(edges, dict) or set(edges) != {"r_min", "r_max", "z_min", "z_max"}:
        raise FixedBoxBoundaryDriftError(
            "pinned adapter did not expose the exact four frozen edge arrays"
        )
    result: dict[str, np.ndarray] = {}
    for name, raw in edges.items():
        array = np.asarray(raw)
        if array.ndim != 1 or array.dtype.kind != "f" or array.dtype.itemsize != 8:
            raise FixedBoxBoundaryDriftError(f"frozen edge has invalid shape or dtype: {name}")
        if not bool(np.isfinite(array).all()):
            raise FixedBoxBoundaryDriftError(f"frozen edge is non-finite: {name}")
        result[name] = np.array(array, dtype=np.dtype("<f8"), copy=True)
    if result["r_min"].size != result["r_max"].size:
        raise FixedBoxBoundaryDriftError("r-edge lengths differ")
    if result["z_min"].size != result["z_max"].size:
        raise FixedBoxBoundaryDriftError("z-edge lengths differ")
    corners = (
        (result["r_min"][0], result["z_min"][0]),
        (result["r_min"][-1], result["z_max"][0]),
        (result["r_max"][0], result["z_min"][-1]),
        (result["r_max"][-1], result["z_max"][-1]),
    )
    if any(_float64_bytes(left) != _float64_bytes(right) for left, right in corners):
        raise FixedBoxBoundaryDriftError("frozen edge endpoints are not byte-compatible")
    return result


def _assert_exact_edges(psi: Any, frozen: dict[str, np.ndarray], phase: str) -> None:
    views = _edge_views(psi)
    for name, expected in frozen.items():
        current = views[name]
        if current.shape != expected.shape or _float64_bytes(current) != _float64_bytes(expected):
            raise FixedBoxBoundaryDriftError(
                f"observed Dirichlet edge changed at {phase}: {name}"
            )


def _valid_digest(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def _validate_critical_point_collection(points: Any, *, event_index: int, field: str) -> None:
    """Check that the observer serialized complete, finite (R, Z, psi) triples."""
    if not isinstance(points, list):
        raise FixedBoxTopologyObservationUnavailable(
            f"critical event {event_index} {field} is not an explicit list"
        )
    for point_index, point in enumerate(points, start=1):
        if not isinstance(point, dict):
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] is malformed"
            )
        payload = point.get("values")
        readable = point.get("readable_values")
        if not isinstance(payload, dict) or not isinstance(readable, list):
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] is incomplete"
            )
        if (
            payload.get("shape") != [3]
            or payload.get("encoding_dtype") != "<f8"
            or payload.get("encoding") != "base64_raw_c_order"
            or not isinstance(payload.get("source_dtype"), str)
            or len(payload["source_dtype"]) == 0
            or not _valid_digest(payload.get("values_sha256"))
        ):
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] payload metadata is invalid"
            )
        for count_key in ("finite_count", "total_count"):
            count = payload.get(count_key)
            if isinstance(count, bool) or not isinstance(count, int) or count != 3:
                raise FixedBoxTopologyObservationUnavailable(
                    f"critical event {event_index} {field}[{point_index}] {count_key} is invalid"
                )
        try:
            source_dtype = np.dtype(payload["source_dtype"])
        except (TypeError, ValueError) as exc:
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] source dtype is invalid"
            ) from exc
        if source_dtype.kind != "f" or source_dtype.itemsize != 8:
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] source dtype is not float64"
            )
        try:
            raw = base64.b64decode(payload.get("values_base64", ""), validate=True)
        except (ValueError, TypeError) as exc:
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] payload is not valid base64"
            ) from exc
        if len(raw) != 24 or hashlib.sha256(raw).hexdigest() != payload["values_sha256"]:
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] payload hash/length mismatch"
            )
        decoded = np.frombuffer(raw, dtype=np.dtype("<f8"))
        minimum, maximum = payload.get("finite_minimum"), payload.get("finite_maximum")
        if (
            len(readable) != 3
            or not bool(np.isfinite(decoded).all())
            or isinstance(minimum, bool)
            or not isinstance(minimum, (int, float))
            or not math.isfinite(float(minimum))
            or isinstance(maximum, bool)
            or not isinstance(maximum, (int, float))
            or not math.isfinite(float(maximum))
            or struct.pack("<d", float(minimum)) != struct.pack("<d", float(np.min(decoded)))
            or struct.pack("<d", float(maximum)) != struct.pack("<d", float(np.max(decoded)))
            or base64.b64encode(raw).decode("ascii") != payload.get("values_base64")
        ):
            raise FixedBoxTopologyObservationUnavailable(
                f"critical event {event_index} {field}[{point_index}] coordinates are not finite triples"
            )
        for raw_value, readable_value in zip(decoded, readable):
            if (
                isinstance(readable_value, (bool, np.bool_))
                or not isinstance(readable_value, (int, float, np.integer, np.floating))
                or not math.isfinite(float(readable_value))
                or struct.pack("<d", float(readable_value)) != struct.pack("<d", float(raw_value))
            ):
                raise FixedBoxTopologyObservationUnavailable(
                    f"critical event {event_index} {field}[{point_index}] readable values disagree with payload"
                )


def _validate_critical_event(item: Any, expected_index: int) -> dict[str, Any]:
    if not isinstance(item, dict):
        raise FixedBoxTopologyObservationUnavailable(
            f"critical event {expected_index} is not an object"
        )
    index = item.get("call_index")
    if isinstance(index, bool) or not isinstance(index, int) or index != expected_index:
        raise FixedBoxTopologyObservationUnavailable(
            f"critical event index is missing, duplicated, or out of order at {expected_index}"
        )
    if item.get("scope") not in ("equilibrium_boundary_update", "profile_jtor"):
        raise FixedBoxTopologyObservationUnavailable(
            f"critical event {expected_index} has an unexpected phase scope"
        )
    if not _valid_digest(item.get("input_psi_sha256")):
        raise FixedBoxTopologyObservationUnavailable(
            f"critical event {expected_index} lacks a readable input psi hash"
        )
    _validate_critical_point_collection(item.get("o_points"), event_index=expected_index, field="o_points")
    _validate_critical_point_collection(item.get("x_points"), event_index=expected_index, field="x_points")
    return item


def _latest_boundary_xpoint_counts(
    observer: Any, expected_call_index: int
) -> tuple[int, int, dict[str, Any]]:
    calls = getattr(observer, "calls", None)
    if not isinstance(calls, list) or len(calls) != expected_call_index:
        raise FixedBoxTopologyObservationUnavailable(
            "fixed-box policy did not receive exactly the next observed Equilibrium.solve call"
        )
    call = calls[-1]
    call_index = call.get("eq_solve_call_index") if isinstance(call, dict) else None
    if (
        not isinstance(call, dict)
        or isinstance(call_index, bool)
        or not isinstance(call_index, int)
        or call_index != expected_call_index
    ):
        raise FixedBoxTopologyObservationUnavailable(
            "Equilibrium.solve observer call index is missing, duplicated, or out of order"
        )
    if call.get("call_completed") is not True:
        raise FixedBoxTopologyObservationUnavailable(
            "Equilibrium.solve observer did not prove a completed native solve call"
        )
    observation_errors = call.get("observation_errors")
    if not isinstance(observation_errors, list) or observation_errors:
        raise FixedBoxTopologyObservationUnavailable(
            "Equilibrium.solve observer recorded an error or omitted its error list"
        )
    critical_calls = call.get("critical_calls") if isinstance(call, dict) else None
    if not isinstance(critical_calls, list):
        raise FixedBoxTopologyObservationUnavailable(
            "Equilibrium.solve observer has no critical-point events"
        )
    if len(critical_calls) < 2:
        raise FixedBoxTopologyObservationUnavailable(
            "Equilibrium.solve observer is missing one or both expected boundary-update events"
        )
    events = [
        _validate_critical_event(item, index)
        for index, item in enumerate(critical_calls, start=1)
    ]
    boundary_positions = [
        index for index, item in enumerate(events)
        if item["scope"] == "equilibrium_boundary_update"
    ]
    if (
        len(boundary_positions) != 2
        or boundary_positions[0] != 0
        or boundary_positions[1] != len(events) - 1
        or any(item["scope"] != "profile_jtor" for item in events[1:-1])
    ):
        raise FixedBoxTopologyObservationUnavailable(
            "boundary topology events do not match pinned pre-update / profile / post-update order"
        )
    before_event, after_event = events[0], events[-1]
    if before_event is after_event:
        raise FixedBoxTopologyObservationUnavailable(
            "pre-solve boundary event was reused as the post-solve event"
        )
    before, after = before_event["x_points"], after_event["x_points"]
    topology_observation = {
        "observed_eq_solve_call_index": expected_call_index,
        "call_completed": True,
        "observation_errors": [],
        "critical_event_count": len(events),
        "event_order": [item["scope"] for item in events],
        "intermediate_profile_events": [
            {
                "call_index": item["call_index"],
                "input_psi_sha256": item["input_psi_sha256"],
                "o_point_count": len(item["o_points"]),
                "x_point_count": len(item["x_points"]),
                "payloads_complete": True,
            }
            for item in events[1:-1]
        ],
        "pre_solve_boundary_update": {
            "call_index": before_event["call_index"],
            "input_psi_sha256": before_event["input_psi_sha256"],
            "o_points": before_event["o_points"],
            "x_points": before,
            "xpoint_count": len(before),
        },
        "post_solve_boundary_update": {
            "call_index": after_event["call_index"],
            "input_psi_sha256": after_event["input_psi_sha256"],
            "o_points": after_event["o_points"],
            "x_points": after,
            "xpoint_count": len(after),
        },
        "validated_complete_ordered_observation": True,
    }
    return len(before), len(after), topology_observation


def solve_fixed_observed_box(
    eq: Any,
    profiles: Any,
    constrain: Any = None,
    rtol: float = 1.0e-3,
    atol: float = 1.0e-10,
    blend: float = 0.0,
    show: bool = False,
    axis: Any = None,
    pause: float = 0.0001,
    psi_bndry: Any = None,
    maxits: int | None = 50,
    convergenceInfo: bool = False,
    check_limited: bool = False,
    wait_for_limited: bool = False,
    limit_it: int = 0,
    *,
    observer: Any,
    policy_receipt: MutableMapping[str, Any],
) -> Any:
    """Run pinned Picard ordering with an exact fixed-box boundary metric.

    ``eq.psi_bndry`` is passed to ``eq.solve`` exactly as supplied by the
    frozen runner but is never read or assigned for stopping.  Boundary
    convergence is instead the bit-exact equality of the complete four-edge
    vector against its frozen values; if exact equality holds, the boundary
    change is exactly zero.  Terminal topology is read from the independent
    critical-point observer.  Intermediate X-points are retained in the
    receipt; only the converged terminal state is gated.
    """
    del show, axis, pause  # The frozen runner uses FreeGS defaults for plotting.
    if not math.isfinite(float(rtol)) or not 0.0 < float(rtol) < 1.0:
        raise ValueError("rtol must be finite and lie in (0, 1)")
    if not math.isfinite(float(atol)) or not 0.0 < float(atol) < 1.0:
        raise ValueError("atol must be finite and lie in (0, 1)")
    if float(blend) != 0.0:
        raise ValueError("v18 fixed observed-box policy is pinned to blend=0")
    if constrain is not None or check_limited or wait_for_limited or limit_it != 0:
        raise FixedBoxTerminalTopologyUnsupported(
            "fixed observed-box policy requires constrain=None, check_limited=False, "
            "wait_for_limited=False, and limit_it=0"
        )
    if maxits is not None and (
        isinstance(maxits, (bool, np.bool_))
        or not isinstance(maxits, (int, np.integer))
        or int(maxits) < 1
    ):
        raise ValueError("maxits must be a positive integer or None")
    if observer is None or not isinstance(policy_receipt, MutableMapping):
        raise FixedBoxTopologyObservationUnavailable(
            "fixed-box policy requires its solve observer and receipt"
        )

    frozen = _copy_frozen_edges_from_adapter_callback(eq)
    psi = np.asarray(eq.psi())
    if psi.dtype != np.dtype(np.float64) or not bool(np.isfinite(psi).all()):
        raise FixedBoxNumericalStateError("initial psi is not finite float64")
    _assert_exact_edges(psi, frozen, "initial_state")
    psi = psi.copy()

    policy_receipt.update({
        "schema": "fusionconceptai:freegs-fixed-observed-box-picard-receipt-v2",
        "policy_revision": POLICY_REVISION,
        "native_picard_revision": NATIVE_PICARD_REVISION,
        "native_freegs_picard_called": False,
        "fixed_box_boundary_metric": "byte-exact equality of all four frozen observed edges",
        "fixed_box_boundary_change_wb_per_rad": 0.0,
        "boundary_scalar_used_for_stopping": False,
        "eq_psi_bndry_read_for_stopping": False,
        "eq_psi_bndry_written": False,
        "corner_proxy_written": False,
        "physical_boundary_flux_claim": False,
        "physics_credit": False,
        "inverse_credit": False,
        "numerical_result_scope": "test_only_fixed_observed_box_iteration",
        "final_residual_source": "baseline_v2_postprocess_from_final_candidate; acceptance_threshold_undefined",
        "observed_xpoint_count_sequence": [],
        "topology_transitions": [],
        "topology_observations": [],
        "controls": {
            "rtol": float(rtol), "atol": float(atol),
            "maxits": maxits, "blend": float(blend),
        },
        "control_semantics": {
            "maxits": "configured upper limit only; versioned policy loop count is separately measured",
            "native_freegs_picard_iterations": "not_run_not_inferred",
            "psi_criterion": "psi_maxchange < atol OR psi_relchange_to_full_grid_span < rtol",
            "boundary_criterion": "all four frozen observed edges remain byte-identical at every solve boundary",
            "physical_or_inverse_acceptance": "not_defined_not_granted",
        },
        "iteration_history": [],
        "status": "started",
    })
    psi_maxchange_iterations: list[float] = []
    psi_relchange_iterations: list[float] = []
    observer_start = len(getattr(observer, "calls", []))
    iteration = 0

    while True:
        psi_last = psi.copy()
        _assert_exact_edges(psi_last, frozen, "pre_solve")
        eq.check_limited = False
        eq.solve(profiles, psi=psi, psi_bndry=psi_bndry)
        psi_new = np.asarray(eq.psi())
        if psi_new.dtype != np.dtype(np.float64) or not bool(np.isfinite(psi_new).all()):
            raise FixedBoxNumericalStateError("Equilibrium.solve returned non-finite psi")
        _assert_exact_edges(psi_new, frozen, "post_solve")
        expected_observed_call_index = observer_start + iteration + 1
        xpoints_before, xpoints_after, topology_observation = _latest_boundary_xpoint_counts(
            observer, expected_observed_call_index
        )
        trajectory = policy_receipt["observed_xpoint_count_sequence"]
        if not trajectory:
            trajectory.append(xpoints_before)
        elif trajectory[-1] != xpoints_before:
            trajectory.append(xpoints_before)
        trajectory.append(xpoints_after)
        policy_receipt["topology_transitions"].append({
            "policy_iteration_index": iteration + 1,
            "xpoints_before_solve": xpoints_before,
            "xpoints_after_solve": xpoints_after,
        })
        policy_receipt["topology_observations"].append(topology_observation)
        limited_after = bool(eq.is_limited)
        psi_change = psi_last - psi_new
        psi_maxchange = float(np.max(np.abs(psi_change)))
        psi_span = float(np.max(psi_new) - np.min(psi_new))
        if not math.isfinite(psi_maxchange) or not math.isfinite(psi_span) or psi_span <= 0.0:
            raise FixedBoxNumericalStateError("psi change or full-grid span is invalid")
        psi_relchange = psi_maxchange / psi_span
        iteration += 1
        policy_receipt["latest_psi_maxchange_wb_per_rad"] = psi_maxchange
        policy_receipt["latest_psi_relchange_to_full_grid_span"] = psi_relchange
        psi_maxchange_iterations.append(psi_maxchange)
        psi_relchange_iterations.append(psi_relchange)
        policy_receipt["iteration_history"].append({
            "policy_iteration_index": iteration,
            "observed_equilibrium_solve_call_index": len(observer.calls),
            "psi_maxchange_wb_per_rad": psi_maxchange,
            "psi_relchange_to_full_grid_span": psi_relchange,
            "fixed_box_boundary_change_wb_per_rad": 0.0,
            "all_four_edges_bitwise_exact": True,
            "xpoints_before_solve": xpoints_before,
            "xpoints_after_solve": xpoints_after,
            "is_limited_after_solve": limited_after,
        })

        psi_gate = psi_maxchange < float(atol) or psi_relchange < float(rtol)
        # Exact edge equality is checked before and after every Equilibrium.solve
        # and after blending. The invariant itself is the fixed-box condition;
        # it is not a scalar-flux convergence proxy.
        if psi_gate:
            if limited_after or xpoints_after != 0:
                policy_receipt["status"] = "unsupported_terminal_topology"
                policy_receipt["terminal_topology"] = {
                    "xpoint_count": xpoints_after,
                    "is_limited": limited_after,
                    "gate": "fail_closed",
                }
                raise FixedBoxTerminalTopologyUnsupported(
                    "converged fixed-box candidate has terminal X-point or limited topology"
                )
            psi = psi_new.copy()
            policy_receipt["status"] = "test_only_fixed_box_policy_v2_converged"
            policy_receipt["terminal_topology"] = {
                "xpoint_count": 0, "is_limited": False,
                "gate": "passed_terminal_topology_only_no_physics_credit",
            }
            policy_receipt["policy_iteration_count"] = iteration
            policy_receipt["observed_equilibrium_solve_calls"] = len(observer.calls) - observer_start
            policy_receipt["final_psi_maxchange_wb_per_rad"] = psi_maxchange
            policy_receipt["final_psi_relchange_to_full_grid_span"] = psi_relchange
            break

        psi = psi_new.copy()
        if constrain is not None:
            constrain(eq)
        psi = (1.0 - float(blend)) * np.asarray(eq.psi()) + float(blend) * psi_last
        _assert_exact_edges(psi, frozen, "post_blend")

        # Match FreeGS 0.8.2's maxits counter semantics exactly: the check is
        # performed after increment, so maxits=100 permits up to 101 loop calls.
        if maxits:
            if iteration > int(maxits):
                policy_receipt["status"] = "numerical_fail_nonconvergence"
                policy_receipt["policy_iteration_count"] = iteration
                policy_receipt["observed_equilibrium_solve_calls"] = len(observer.calls) - observer_start
                raise FixedBoxPicardNonconvergence(NONCONVERGENCE_MESSAGE)

    if convergenceInfo:
        return np.array(psi_maxchange_iterations), np.array(psi_relchange_iterations)
    return None
