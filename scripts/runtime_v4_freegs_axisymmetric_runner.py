#!/usr/bin/env python3
"""Controlled FreeGS 0.8.2 process for the Runtime V4 typed bridge.

The JSON dictionary exists only at this process boundary. The Julia caller
constructs it from an externally revalidated typed subject binding and hashes
the exact input/output bytes. This runner never emits validation or feasibility
claims; dependency and solver exceptions become recoverable unknown artifacts.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.metadata
import json
import math
import platform
import sys
import traceback
import warnings
from pathlib import Path
from typing import Optional


RUNNER_REVISION = "runtime-v4-freegs-axisymmetric-execution-v1"
INPUT_SCHEMA = "fusionconceptai:runtime-v4-freegs-axisymmetric-input"
SUMMARY_MARKER = "FUSION_FREEGS_V4"


def canonical_hash(value: object) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False)
    return hashlib.sha256(encoded.encode("utf-8")).hexdigest()


def file_hash(path: str) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_exact(mapping: object, keys: set[str], label: str) -> dict:
    if not isinstance(mapping, dict):
        raise ValueError(f"{label} must be an object")
    actual = set(mapping)
    if actual != keys:
        missing = sorted(keys - actual)
        extra = sorted(actual - keys)
        raise ValueError(f"{label} keys mismatch; missing={missing}, extra={extra}")
    return mapping


def finite(value: object, label: str) -> float:
    if isinstance(value, bool):
        raise ValueError(f"{label} must not be boolean")
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{label} must be finite")
    return result


def refine_stationary_critical_points(R: object, Z: object, psi: object,
                                     opoints: list, xpoints: list) -> tuple[list, list]:
    """Refine FreeGS seeds on the identical cubic spline; reject wrong Hessian types."""
    import numpy as np
    import scipy
    from scipy.interpolate import RectBivariateSpline
    from scipy.optimize import root

    radius = np.asarray(R[:, 0], dtype=float)
    vertical = np.asarray(Z[0, :], dtype=float)
    flux = np.asarray(psi, dtype=float)
    if (flux.shape != (radius.size, vertical.size) or
            not np.all(np.isfinite(flux)) or radius.size < 4 or vertical.size < 4):
        raise ValueError("stationary critical-point input grid is invalid")
    spline = RectBivariateSpline(radius, vertical, flux)
    dr, dz = float(np.min(np.diff(radius))), float(np.min(np.diff(vertical)))
    if dr <= 0.0 or dz <= 0.0:
        raise ValueError("stationary critical-point axes must increase")
    flux_scale = max(float(np.max(np.abs(flux))), np.finfo(float).tiny)
    grad_tol = 1.0e-10 * flux_scale / min(dr, dz)
    hessian_tol = 1.0e-10 * flux_scale / min(dr, dz) ** 2
    max_shift = 3.0 * math.hypot(dr, dz)
    root_method = "lm"
    root_options = {"ftol": 1.0e-12, "xtol": 1.0e-12,
                    "gtol": 1.0e-12, "maxiter": 100}

    def gradient(q: object) -> object:
        return np.asarray((spline.ev(q[0], q[1], dx=1, dy=0),
                           spline.ev(q[0], q[1], dx=0, dy=1)), dtype=float)

    def hessian(q: object) -> object:
        cross = spline.ev(q[0], q[1], dx=1, dy=1)
        return np.asarray(((spline.ev(q[0], q[1], dx=2, dy=0), cross),
                           (cross, spline.ev(q[0], q[1], dx=0, dy=2))), dtype=float)

    def stationary_failure_diagnostic(kind: str, seed_index: int, q0: object,
                                      q: object, solution: object, reason: str,
                                      gradient_at_q: object, residual: float,
                                      shift: float, inside_domain: bool,
                                      failed_gates: list[str],
                                      hessian_at_q: object = None,
                                      eigenvalues: object = None,
                                      actual_hessian_type: object = None) -> dict:
        finite_or_none = lambda value: float(value) if math.isfinite(float(value)) else None
        q_values = np.asarray(q, dtype=float)
        q_is_2d = q_values.shape == (2,)
        refined = [finite_or_none(v) for v in q_values] if q_is_2d else None
        try:
            refined_psi = finite_or_none(spline.ev(q_values[0], q_values[1])) if q_is_2d else None
        except Exception:
            refined_psi = None
        try:
            hessian_values = ([[finite_or_none(v) for v in row] for row in hessian_at_q]
                              if hessian_at_q is not None else None)
        except Exception:
            hessian_values = None
        try:
            eigenvalue_values = ([finite_or_none(v) for v in eigenvalues]
                                 if eigenvalues is not None else None)
        except Exception:
            eigenvalue_values = None
        return {
            "schema": "fusionconceptai:stationary-critical-point-failure-v1",
            "reason": reason,
            "kind": kind,
            "seed_index_zero_based": int(seed_index),
            "seed_rz_m": [finite_or_none(v) for v in q0],
            "refined_rz_m": refined,
            "refined_psi_wb_per_rad": refined_psi,
            "root": {
                "method": root_method,
                "xtol": root_options["xtol"],
                "options": dict(root_options),
                "success": bool(solution.success),
                "status": int(solution.status),
                "message": str(solution.message),
                "nfev": int(solution.nfev),
                "njev": int(solution.njev) if getattr(solution, "njev", None) is not None else None,
            },
            "checks": {
                "expected_hessian_type": "same-sign nonzero eigenvalues" if kind == "O" else "one negative and one positive eigenvalue",
                "actual_hessian_type": actual_hessian_type,
                "root_success_gate_passed": bool(solution.success),
                "root_shape": list(q_values.shape),
                "root_finite": bool(q_is_2d and np.all(np.isfinite(q_values))),
                "finite_gradient_gate_passed": bool(math.isfinite(float(residual))),
                "gradient_rz_wb_per_rad_m": ([finite_or_none(v) for v in gradient_at_q]
                                               if gradient_at_q is not None else None),
                "gradient_norm_wb_per_rad_m": finite_or_none(residual),
                "gradient_tolerance_wb_per_rad_m": finite_or_none(grad_tol),
                "gradient_within_tolerance": bool(math.isfinite(float(residual)) and residual <= grad_tol),
                "root_in_strict_spline_interior": bool(inside_domain),
                "seed_to_root_shift_m": finite_or_none(shift),
                "maximum_shift_m": finite_or_none(max_shift),
                "finite_shift_gate_passed": bool(math.isfinite(float(shift))),
                "shift_within_maximum": bool(math.isfinite(float(shift)) and shift <= max_shift),
                "hessian_rz_wb_per_rad_m2": hessian_values,
                "hessian_eigenvalues_wb_per_rad_m2": eigenvalue_values,
                "hessian_tolerance_wb_per_rad_m2": finite_or_none(hessian_tol),
            },
            "failed_gates": list(failed_gates),
            "grid": {
                "axis_order": "[R_index][Z_index]",
                "interpolant": "RectBivariateSpline(kx=3, ky=3, s=0)",
                "R_nodes_m": radius.tolist(),
                "Z_nodes_m": vertical.tolist(),
                "psi_wb_per_rad": flux.tolist(),
            },
            "freegs_seeds_rz_m": {
                "O": [[finite_or_none(point[0]), finite_or_none(point[1])] for point in opoints],
                "X": [[finite_or_none(point[0]), finite_or_none(point[1])] for point in xpoints],
            },
            "source_call": {
                "path": "freegs.solve -> Equilibrium.solve -> Equilibrium._updateBoundaryPsi -> critical_point_provider(R,Z,psi,opt,xpt)",
                "callback": "refine_stationary_critical_points(R,Z,psi,opoints,xpoints)",
            "root_call": "root(gradient, seed, jac=hessian, method='lm', options={'ftol': 1e-12, 'xtol': 1e-12, 'gtol': 1e-12, 'maxiter': 100})",
                "numpy_version": np.__version__,
                "scipy_version": scipy.__version__,
            },
        }

    def refine(points: list, kind: str) -> list:
        if not points:
            finite_or_none = lambda value: float(value) if math.isfinite(float(value)) else None

            def seed_coordinates(candidates: list) -> list:
                return [[finite_or_none(point[0]), finite_or_none(point[1])]
                        for point in candidates]

            error = ValueError(f"stationary critical-point search has no {kind}-point seeds")
            error.stationary_critical_point_diagnostic = {
                "schema": "fusionconceptai:stationary-critical-point-failure-v1",
                "reason": f"no_{kind}_point_seeds",
                "kind": kind,
                "seed_index_zero_based": None,
                "seed_rz_m": None,
                "refined_rz_m": None,
                "root": {"method": root_method, "xtol": root_options["xtol"],
                         "options": dict(root_options)},
                "checks": {
                    "expected_hessian_type": "same-sign nonzero eigenvalues" if kind == "O" else "one negative and one positive eigenvalue",
                    "gradient_tolerance_wb_per_rad_m": finite_or_none(grad_tol),
                    "maximum_shift_m": finite_or_none(max_shift),
                    "hessian_tolerance_wb_per_rad_m2": finite_or_none(hessian_tol),
                    "freegs_seed_count": 0,
                },
                "failed_gates": ["nonempty_seed_list"],
                "grid": {
                    "axis_order": "[R_index][Z_index]",
                    "quantity": "total_psi_passed_to_critical_point_provider",
                    "interpolant": "RectBivariateSpline(kx=3, ky=3, s=0)",
                    "R_nodes_m": [finite_or_none(value) for value in radius],
                    "Z_nodes_m": [finite_or_none(value) for value in vertical],
                    "psi_wb_per_rad": [[finite_or_none(value) for value in row]
                                        for row in flux],
                },
                "freegs_seeds_rz_m": {
                    "O": seed_coordinates(opoints),
                    "X": seed_coordinates(xpoints),
                },
                "source_call": {
                    "path": "freegs.solve -> Equilibrium.solve -> Equilibrium._updateBoundaryPsi -> critical_point_provider(R,Z,psi,opt,xpt)",
                    "callback": "refine_stationary_critical_points(R,Z,psi,opoints,xpoints)",
                    "root_call": f"not_called_for_empty_{kind}_seed_list",
                    "numpy_version": np.__version__,
                    "scipy_version": scipy.__version__,
                },
            }
            raise error
        refined = []
        for seed_index, seed in enumerate(points):
            q0 = np.asarray((float(seed[0]), float(seed[1])), dtype=float)
            if not (radius[0] < q0[0] < radius[-1] and vertical[0] < q0[1] < vertical[-1]):
                raise ValueError(f"{kind}-point seed is outside the spline interior")
            solution = root(gradient, q0, jac=hessian, method=root_method,
                            options=dict(root_options))
            q = np.asarray(solution.x, dtype=float)
            if q.shape == (2,):
                try:
                    gradient_at_q = gradient(q)
                    residual = float(np.linalg.norm(gradient_at_q))
                except Exception:
                    gradient_at_q = None
                    residual = float("nan")
            else:
                gradient_at_q = None
                residual = float("nan")
            q_finite = bool(q.shape == (2,) and np.all(np.isfinite(q)))
            shift = float(np.linalg.norm(q - q0)) if q.shape == q0.shape else float("nan")
            finite_shift = bool(math.isfinite(shift))
            inside_domain = bool(q_finite and radius[0] < q[0] < radius[-1] and
                                 vertical[0] < q[1] < vertical[-1])
            failed_gates = []
            if not solution.success:
                failed_gates.append("root_success")
            if q.shape != (2,):
                failed_gates.append("root_shape")
            if not q_finite:
                failed_gates.append("finite_root")
            if not math.isfinite(residual):
                failed_gates.append("finite_gradient")
            if residual > grad_tol:
                failed_gates.append("gradient_tolerance")
            if not finite_shift:
                failed_gates.append("finite_shift")
            elif shift > max_shift:
                failed_gates.append("maximum_shift")
            if not inside_domain:
                failed_gates.append("strict_domain")
            if failed_gates:
                error = ValueError(f"{kind}-point stationary refinement failed its gradient/domain/shift gate")
                error.stationary_critical_point_diagnostic = stationary_failure_diagnostic(
                    kind, seed_index, q0, q, solution, "root_refinement_gate_failed",
                    gradient_at_q, residual, shift, inside_domain, failed_gates)
                raise error
            hessian_at_q = hessian(q)
            eigenvalues = np.linalg.eigvalsh(hessian_at_q)
            if (np.all(eigenvalues > hessian_tol) or
                    np.all(eigenvalues < -hessian_tol)):
                actual_kind = "O"
                actual_hessian_type = "same-sign nonzero eigenvalues"
            elif eigenvalues[0] < -hessian_tol and eigenvalues[1] > hessian_tol:
                actual_kind = "X"
                actual_hessian_type = "one negative and one positive eigenvalue"
            else:
                actual_kind = None
                actual_hessian_type = "degenerate or unresolved eigenvalues"
            # FreeGS's first seed in each list is a primary anchor. Keep its
            # class fixed; secondary labels are only root initializers.
            if actual_kind is None or (seed_index == 0 and actual_kind != kind):
                error = ValueError(f"{kind}-point stationary refinement has the wrong Hessian type")
                error.stationary_critical_point_diagnostic = stationary_failure_diagnostic(
                    kind, seed_index, q0, q, solution, "wrong_hessian_type",
                    gradient_at_q, residual, shift, inside_domain,
                    ["hessian_type"], hessian_at_q, eigenvalues,
                    actual_hessian_type)
                raise error
            refined.append({
                "seed_kind": kind,
                "seed_index_zero_based": seed_index,
                "kind": actual_kind,
                "point": (float(q[0]), float(q[1]), float(spline.ev(q[0], q[1]))),
            })
        return refined

    refined_candidates = refine(opoints, "O") + refine(xpoints, "X")
    primary_o_candidate = next(
        item for item in refined_candidates
        if item["seed_kind"] == "O" and item["seed_index_zero_based"] == 0)
    primary_x_candidate = next(
        item for item in refined_candidates
        if item["seed_kind"] == "X" and item["seed_index_zero_based"] == 0)
    # Keep the original FreeGS O0/X0 anchors first. Reclassified secondary
    # roots follow in their original O-seed-then-X-seed order.
    refined_o = [primary_o_candidate["point"]] + [
        item["point"] for item in refined_candidates
        if item["kind"] == "O" and item is not primary_o_candidate]
    refined_x = [primary_x_candidate["point"]] + [
        item["point"] for item in refined_candidates
        if item["kind"] == "X" and item is not primary_x_candidate]
    def reject_refined_duplicates(points: list, kind: str) -> None:
        # Apply the existing duplicate gate after Hessian classification, once
        # per actual point type; each refined root belongs to only one list.
        for i, point in enumerate(points):
            for other in points[:i]:
                if ((point[0] - other[0]) ** 2 + (point[1] - other[1]) ** 2) < 1.0e-5:
                    raise ValueError(f"refined {kind}-point candidates became duplicates")
    reject_refined_duplicates(refined_o, "O")
    reject_refined_duplicates(refined_x, "X")
    seeded_primary_o = refined_o[0]
    seeded_primary_x = refined_x[0]
    rmid = 0.5 * (radius[-1] + radius[0])
    zmid = 0.5 * (vertical[-1] + vertical[0])
    refined_o.sort(key=lambda p: (p[0] - rmid) ** 2 + (p[1] - zmid) ** 2)
    if refined_o[0] != seeded_primary_o:
        raise ValueError("stationary refinement changes the primary O-point correspondence")
    axis_flux = refined_o[0][2]
    refined_x.sort(key=lambda p: abs(p[2] - axis_flux))
    # Reapply FreeGS's existing primary-O to X-point monotonic-path eligibility
    # to refined roots. Never retain a root solely because its old seed passed.
    primary_o = refined_o[0]
    eligible_x = []
    for xpoint in refined_x:
        rline = np.linspace(primary_o[0], xpoint[0], num=50)
        zline = np.linspace(primary_o[1], xpoint[1], num=50)
        pline = np.asarray(spline.ev(rline, zline), dtype=float)
        if xpoint[2] < primary_o[2]:
            pline *= -1.0
        maxp = float(np.max(pline))
        denominator = maxp - float(pline[0])
        if not math.isfinite(denominator) or denominator <= 0.0:
            raise ValueError("refined O-X path has an invalid monotonicity scale")
        if (maxp - float(pline[-1])) / denominator > 0.001:
            continue
        ind = int(np.argmin(pline))
        if ((rline[ind] - primary_o[0]) ** 2 +
                (zline[ind] - primary_o[1]) ** 2) > 1.0e-4:
            continue
        eligible_x.append(xpoint)
    if not eligible_x:
        raise ValueError("refined critical candidates contain no FreeGS-eligible X-point")
    if eligible_x[0] != seeded_primary_x:
        raise ValueError("refined eligible X-points change the primary correspondence")
    return refined_o, eligible_x


def environment_manifest() -> tuple[dict, object, object, object]:
    import freegs
    import numpy as np
    import scipy

    manifest = {
        "python_executable": str(Path(sys.executable).resolve()),
        "python_executable_sha256": file_hash(sys.executable),
        "python_version": platform.python_version(),
        "platform": platform.platform(),
        "freegs_version": importlib.metadata.version("FreeGS"),
        "freeqdsk_version": importlib.metadata.version("freeqdsk"),
        "numpy_version": np.__version__,
        "scipy_version": scipy.__version__,
    }
    manifest["environment_hash"] = canonical_hash(manifest)
    return manifest, freegs, np, scipy


def independent_gs_residual(eq: object, np: object, mu_0: float) -> dict:
    psi = np.asarray(eq.plasma_psi, dtype=float)
    radius = np.asarray(eq.R, dtype=float)
    current = np.asarray(eq.Jtor, dtype=float)
    dr = float(radius[1, 0] - radius[0, 0])
    dz = float(eq.Z[0, 1] - eq.Z[0, 0])
    center = psi[1:-1, 1:-1]
    operator = (
        (psi[2:, 1:-1] - 2.0 * center + psi[:-2, 1:-1]) / dr**2
        - (psi[2:, 1:-1] - psi[:-2, 1:-1])
        / (2.0 * dr * radius[1:-1, 1:-1])
        + (psi[1:-1, 2:] - 2.0 * center + psi[1:-1, :-2]) / dz**2
    )
    rhs = -mu_0 * radius[1:-1, 1:-1] * current[1:-1, 1:-1]
    residual = operator - rhs
    plasma_mask = np.abs(rhs) > max(1.0e-30, 1.0e-12 * np.max(np.abs(rhs)))
    if not bool(np.any(plasma_mask)):
        raise RuntimeError("independent residual has no plasma support")

    def relative_l2(mask: object) -> float:
        return float(np.linalg.norm(residual[mask]) / max(np.linalg.norm(rhs[mask]), 1.0e-30))

    def relative_linf(mask: object) -> float:
        return float(np.max(np.abs(residual[mask])) / max(np.max(np.abs(rhs[mask])), 1.0e-30))

    return {
        "plasma_l2_relative": relative_l2(plasma_mask),
        "plasma_linf_relative": relative_linf(plasma_mask),
        "plasma_rms_absolute": float(np.sqrt(np.mean(residual[plasma_mask] ** 2))),
    }


def validate_payload(payload: object) -> dict:
    wrapper_keys = {
        "schema", "revision", "context_hash", "candidate_hash", "compiled_prefix_hash",
        "physical_subject_hash", "scenario_hash", "field_geometry_genome_hash",
        "field_geometry_graph_hash", "field_geometry_graph_binding_hash",
        "binding_hash", "declaration_hash", "solver_input",
    }
    adapter_key = "mastu_source_adapter"
    exact_wrapper_keys = wrapper_keys | ({adapter_key} if isinstance(payload, dict) and adapter_key in payload else set())
    wrapper = require_exact(payload, exact_wrapper_keys, "wrapper")
    if wrapper["schema"] != INPUT_SCHEMA or wrapper["revision"] != RUNNER_REVISION:
        raise ValueError("Runtime V4 FreeGS input schema/revision mismatch")
    for key in wrapper_keys - {"schema", "revision", "solver_input"}:
        value = wrapper[key]
        if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            raise ValueError(f"{key} must be a lowercase SHA-256 digest")

    solver_value = wrapper["solver_input"]
    if not isinstance(solver_value, dict):
        raise ValueError("solver_input must be an object")
    solver_keys = {"machine", "domain", "profile", "constraints", "solver"}
    actual_solver_keys = set(solver_value)
    extra_solver_keys = actual_solver_keys - solver_keys
    if not solver_keys <= actual_solver_keys or not extra_solver_keys <= {
            "sample_points_rz_m", "sample_constitutive_fields", "sample_lcfs_trace",
            "coil_current_mode", "capture_control_result", "initial_plasma_psi_wb_per_rad",
            "plasma_current_topology", "state_sample_time_s"}:
        missing = sorted(solver_keys - actual_solver_keys)
        extra = sorted(extra_solver_keys)
        raise ValueError(f"solver_input keys mismatch; missing={missing}, extra={extra}")
    solver = solver_value
    if "state_sample_time_s" in solver:
        finite(solver["state_sample_time_s"], "state_sample_time_s")
    if "plasma_current_topology" in solver:
        expected_topology = {
            "model": "ideal_axisymmetric_periodic_lcfs_no_normal_current",
            "phi_interval": {"lower_rad": 0.0, "upper_rad": 2.0 * math.pi, "periodic": True},
            "lcfs_boundary_law": "J_dot_n_zero",
            "external_return_conductor": "outside_declared_model",
            "return_current_path": "periodic_toroidal_plasma_with_zero_normal_current_at_LCFS",
        }
        topology = solver["plasma_current_topology"]
        phi_interval = topology.get("phi_interval") if isinstance(topology, dict) else None
        if (topology != expected_topology or not isinstance(phi_interval, dict)
                or phi_interval.get("periodic") is not True
                or isinstance(phi_interval.get("lower_rad"), bool)
                or isinstance(phi_interval.get("upper_rad"), bool)):
            raise ValueError("unsupported explicit plasma current topology / return path")
    coil_current_mode = solver.get("coil_current_mode", "shape_controlled")
    if coil_current_mode not in ("shape_controlled", "fixed_current_forward"):
        raise ValueError("unsupported coil_current_mode")
    capture_control_result = solver_value.get("capture_control_result", False)
    if not isinstance(capture_control_result, bool):
        raise ValueError("capture_control_result must be boolean")
    if capture_control_result and coil_current_mode != "shape_controlled":
        raise ValueError("SLSQP result capture applies only to shape_controlled mode")
    machine = require_exact(solver["machine"], {"kind", "coils"}, "machine")
    if machine["kind"] != "explicit_filament_coils":
        raise ValueError("only explicit_filament_coils is supported")
    if not isinstance(machine["coils"], list) or not 4 <= len(machine["coils"]) <= 32:
        raise ValueError("the bridge requires 4 to 32 explicit coils")
    coil_ids: list[str] = []
    for index, coil_value in enumerate(machine["coils"]):
        coil_fields = {"id", "major_radius_m", "vertical_position_m"}
        if coil_current_mode == "fixed_current_forward":
            coil_fields.add("current_A_per_turn")
        coil = require_exact(coil_value, coil_fields, f"coil[{index}]")
        if not isinstance(coil["id"], str) or not coil["id"].strip():
            raise ValueError("coil id cannot be empty")
        coil_ids.append(coil["id"])
        if finite(coil["major_radius_m"], "coil major radius") <= 0:
            raise ValueError("coil major radius must be positive")
        finite(coil["vertical_position_m"], "coil vertical position")
        if coil_current_mode == "fixed_current_forward":
            finite(coil["current_A_per_turn"], "fixed coil current A per turn")
    if len(set(coil_ids)) != len(coil_ids):
        raise ValueError("coil IDs must be unique")

    domain = require_exact(solver["domain"],
                           {"r_min_m", "r_max_m", "z_min_m", "z_max_m", "nx", "ny", "boundary"},
                           "domain")
    if domain["boundary"] != "freeBoundaryHagenow":
        raise ValueError("only freeBoundaryHagenow is supported")
    nx, ny = int(domain["nx"]), int(domain["ny"])
    if not (17 <= nx <= 257 and 17 <= ny <= 257 and nx % 2 == 1 and ny % 2 == 1):
        raise ValueError("FreeGS grids must be odd and within 17..257")
    if finite(domain["r_min_m"], "r_min_m") <= 0 or not finite(domain["r_min_m"], "r_min_m") < finite(domain["r_max_m"], "r_max_m"):
        raise ValueError("radial domain is invalid")
    if not finite(domain["z_min_m"], "z_min_m") < finite(domain["z_max_m"], "z_max_m"):
        raise ValueError("vertical domain is invalid")

    sample_points = solver.get("sample_points_rz_m", [])
    if not isinstance(sample_points, list):
        raise ValueError("sample_points_rz_m must be a list")
    constitutive = solver.get("sample_constitutive_fields", False)
    if not isinstance(constitutive, bool):
        raise ValueError("sample_constitutive_fields must be boolean")
    if constitutive and not sample_points:
        raise ValueError("constitutive sampling requires sample_points_rz_m")
    lcfs_trace = solver.get("sample_lcfs_trace", False)
    if not isinstance(lcfs_trace, bool):
        raise ValueError("sample_lcfs_trace must be boolean")
    r_min = finite(domain["r_min_m"], "r_min_m")
    r_max = finite(domain["r_max_m"], "r_max_m")
    z_min = finite(domain["z_min_m"], "z_min_m")
    z_max = finite(domain["z_max_m"], "z_max_m")
    for index, point in enumerate(sample_points):
        if not isinstance(point, list) or len(point) != 2:
            raise ValueError(f"sample point {index} must contain exactly (R,Z)")
        radius = finite(point[0], f"sample point {index} R_m")
        vertical = finite(point[1], f"sample point {index} Z_m")
        if radius <= 0 or not r_min <= radius <= r_max or not z_min <= vertical <= z_max:
            raise ValueError(f"sample point {index} is outside the declared (R,Z) domain")

    base_profile_fields = {"kind", "axis_pressure_pa", "plasma_current_a", "vacuum_f_tm",
                           "alpha_m", "alpha_n", "profile_axis_radius_m"}
    profile_raw = solver["profile"]
    if not isinstance(profile_raw, dict):
        raise ValueError("profile must be an object")
    profile_fields = set(profile_raw)
    if profile_fields == base_profile_fields:
        profile = require_exact(profile_raw, base_profile_fields, "profile")
    elif profile_fields == base_profile_fields | {"critical_point_refinement"}:
        profile = require_exact(profile_raw, base_profile_fields | {"critical_point_refinement"},
                                "profile")
        if profile["critical_point_refinement"] != "stationary_cubic_spline_gradient_hessian_v2":
            raise ValueError("unsupported critical_point_refinement rule")
    else:
        profile = require_exact(profile_raw, base_profile_fields, "profile")
    if profile["kind"] != "ConstrainPaxisIp":
        raise ValueError("only ConstrainPaxisIp is supported")
    for key in ("axis_pressure_pa", "plasma_current_a", "vacuum_f_tm", "alpha_m",
                "alpha_n", "profile_axis_radius_m"):
        finite(profile[key], key)

    constraint_fields = {"xpoints_m", "isoflux_m", "gamma"}
    optional_constraint_fields = {"current_lims_A_per_turn", "max_total_current_A"}
    raw_constraints = solver["constraints"]
    if not isinstance(raw_constraints, dict) or not constraint_fields <= set(raw_constraints) or \
            not set(raw_constraints) <= constraint_fields | optional_constraint_fields:
        raise ValueError("constraints fields mismatch")
    constraints = raw_constraints
    if not isinstance(constraints["xpoints_m"], list) or not constraints["xpoints_m"]:
        raise ValueError("at least one X-point is required")
    if not isinstance(constraints["isoflux_m"], list) or not constraints["isoflux_m"]:
        raise ValueError("at least one isoflux constraint is required")
    for point in constraints["xpoints_m"]:
        if not isinstance(point, list) or len(point) != 2:
            raise ValueError("X-point shape mismatch")
        tuple(finite(value, "X-point coordinate") for value in point)
    for item in constraints["isoflux_m"]:
        if not isinstance(item, list) or len(item) != 4:
            raise ValueError("isoflux shape mismatch")
        tuple(finite(value, "isoflux coordinate") for value in item)
    if finite(constraints["gamma"], "gamma") <= 0:
        raise ValueError("constraint gamma must be positive")
    if "current_lims_A_per_turn" in constraints:
        current_lims = constraints["current_lims_A_per_turn"]
        if not isinstance(current_lims, list) or len(current_lims) != len(machine["coils"]):
            raise ValueError("per-turn current limits must match all declared coils")
        for index, bounds in enumerate(current_lims):
            if not isinstance(bounds, list) or len(bounds) != 2:
                raise ValueError(f"per-turn current limit {index} must contain lower/upper bounds")
            lower = finite(bounds[0], f"per-turn current lower limit {index}")
            upper = finite(bounds[1], f"per-turn current upper limit {index}")
            if lower > upper:
                raise ValueError(f"per-turn current limit {index} is reversed")
        if coil_current_mode == "fixed_current_forward":
            for index, (bounds, coil) in enumerate(zip(current_lims, machine["coils"])):
                current = finite(coil["current_A_per_turn"], f"fixed coil current {index}")
                if not float(bounds[0]) <= current <= float(bounds[1]):
                    raise ValueError(f"fixed coil current {index} violates its declared per-turn limit")
    if "max_total_current_A" in constraints and \
            finite(constraints["max_total_current_A"], "max_total_current_A") < 0:
        raise ValueError("max_total_current_A must be nonnegative")
    has_current_limits = ("current_lims_A_per_turn" in constraints or
                          "max_total_current_A" in constraints)
    if coil_current_mode == "shape_controlled" and capture_control_result and not has_current_limits:
        raise ValueError("SLSQP result capture requires declared per-coil or total-current bounds")
    if coil_current_mode == "shape_controlled" and has_current_limits and not capture_control_result:
        raise ValueError("bounded shape control requires SLSQP result capture for pre-apply feasibility checks")
    if coil_current_mode == "fixed_current_forward" and "max_total_current_A" in constraints:
        total_current = sum(abs(float(coil["current_A_per_turn"])) for coil in machine["coils"])
        if total_current > finite(constraints["max_total_current_A"], "max_total_current_A"):
            raise ValueError("fixed coil currents exceed max_total_current_A")

    initial = solver.get("initial_plasma_psi_wb_per_rad")
    if initial is not None:
        if coil_current_mode != "fixed_current_forward":
            raise ValueError("initial plasma psi is valid only in fixed-current forward mode")
        if not isinstance(initial, list) or len(initial) != nx or any(
                not isinstance(row, list) or len(row) != ny for row in initial):
            raise ValueError("initial plasma psi shape must match the declared [R_index][Z_index] grid")
        for i, row in enumerate(initial):
            for j, value in enumerate(row):
                finite(value, f"initial plasma psi[{i}][{j}]")

    settings = require_exact(solver["solver"], {"rtol", "atol", "max_iterations"}, "solver")
    if not 0 < finite(settings["rtol"], "rtol") < 1:
        raise ValueError("rtol must be within (0,1)")
    if not 0 < finite(settings["atol"], "atol") < 1:
        raise ValueError("atol must be within (0,1)")
    if int(settings["max_iterations"]) < 1:
        raise ValueError("max_iterations must be positive")
    return wrapper


def sample_constitutive_fields(eq: object, profiles: object, points: list,
                               np: object) -> list[dict]:
    """Evaluate final-psi constitutive fields on an isolated, linked FreeGS copy.

    eq.Jtor is the preceding linear-solve RHS, so it is deliberately not used.
    Only native grid points with raw core_mask == 1 and 0 <= psiN <= 1
    are supported. Never threshold the bicubic mask_func or extrapolate pressure.
    Native coordinates may differ from requested coordinates by roundoff only.
    """
    from freegs import critical
    from freegs.gradshafranov import mu0

    def source_state():
        # These are the numerical caches Jtor can change, plus the accepted
        # final field, preceding linear RHS, spline coefficients and coil currents.
        arrays = tuple(np.asarray(getattr(eq, key)).tobytes()
                       for key in ("R", "Z", "plasma_psi", "Jtor"))
        mask = None if eq.mask is None else np.asarray(eq.mask).tobytes()
        mask_spline = None if eq.mask is None else eq.mask_func.get_coeffs().tobytes()
        profile_state = tuple(getattr(profiles, key) for key in
                              ("L", "Beta0", "psi_axis", "psi_bndry", "paxis",
                               "Ip", "_fvac", "alpha_m", "alpha_n", "Raxis"))
        return (arrays, mask, mask_spline, eq.psi_func.get_coeffs().tobytes(),
                np.asarray(eq.psi()).tobytes(), eq.psi_axis, eq.psi_bndry,
                eq.is_limited, tuple(getattr(eq, key, None) for key in
                                     ("psi_limit", "psi_xpt", "Rlim", "Zlim")), profile_state,
                tuple((label, coil.current) for label, coil in eq.tokamak.coils))

    original_state = source_state()

    # Copy the pair in one operation: profiles.eq and eq._profiles must stay linked.
    sampled_eq, sampled_profiles = copy.deepcopy((eq, profiles))
    if sampled_profiles.eq is not sampled_eq or sampled_eq._profiles is not sampled_profiles:
        raise RuntimeError("isolated FreeGS equilibrium/profile linkage failed")
    for name in ("R", "Z", "plasma_psi", "Jtor"):
        if np.shares_memory(getattr(eq, name), getattr(sampled_eq, name)):
            raise RuntimeError("constitutive evaluation aliases source equilibrium")
    psi = np.asarray(sampled_eq.psi(), dtype=float)
    copied_currents = tuple((label, coil.current) for label, coil in sampled_eq.tokamak.coils)
    current = np.asarray(sampled_profiles.Jtor(sampled_eq.R, sampled_eq.Z, psi), dtype=float)
    if not np.array_equal(psi, sampled_eq.psi()) or copied_currents != tuple(
            (label, coil.current) for label, coil in sampled_eq.tokamak.coils):
        raise RuntimeError("constitutive reconstruction changed copied flux or coil currents")
    if getattr(sampled_eq, "critical_point_provider", None) is not None:
        opt, xpt = sampled_eq.critical_points
    else:
        opt, xpt = critical.find_critical(sampled_eq.R, sampled_eq.Z, psi)
    mask = critical.core_mask(sampled_eq.R, sampled_eq.Z, psi, opt, xpt,
                              sampled_profiles.psi_bndry) if opt and xpt else None
    span = float(sampled_profiles.psi_bndry - sampled_profiles.psi_axis)
    if not math.isfinite(span) or span == 0:
        raise RuntimeError("constitutive normalized-flux span is invalid")
    normalized = (psi - sampled_profiles.psi_axis) / span
    value_keys = ("native_R_m", "native_Z_m", "psi_normalized", "Btor_T",
                  "pressure_Pa", "Jphi_A_per_m2", "psi_native_wb_per_rad",
                  "psi_axis_wb_per_rad", "psi_boundary_wb_per_rad", "core_mask",
                  "pprime_Pa_per_flux", "ffprime_T2_m2_per_flux", "mu0_N_per_A2")
    rows = []
    for radius, vertical in points:
        row = dict.fromkeys(value_keys)
        row.update(status="typed_absent", reason="not_native_grid")
        i = int(np.argmin(np.abs(sampled_eq.R[:, 0] - radius)))
        j = int(np.argmin(np.abs(sampled_eq.Z[0, :] - vertical)))
        native_r, native_z = float(sampled_eq.R[i, j]), float(sampled_eq.Z[i, j])
        # A few machine epsilons accommodate Julia/Python grid arithmetic only.
        tol = 8.0 * np.finfo(float).eps * max(1.0, abs(radius), abs(vertical))
        if abs(native_r - radius) > tol or abs(native_z - vertical) > tol:
            rows.append(row)
            continue
        pn = float(normalized[i, j])
        if not (0 < i < psi.shape[0] - 1 and 0 < j < psi.shape[1] - 1):
            row["reason"] = "domain_boundary"
        elif mask is None:
            row["reason"] = "core_mask_unavailable"
        elif mask[i, j] != 1.0 or not math.isfinite(pn) or not 0.0 <= pn <= 1.0:
            row["reason"] = "outside_supported_core"
        elif sampled_profiles.fvac() <= 0:
            # FreeGS fpol uses the positive square-root branch.
            row["reason"] = "unsupported_fvac_branch"
        else:
            row.update(status="present", reason="native_core_final_psi",
                       native_R_m=native_r, native_Z_m=native_z, psi_normalized=pn,
                       Btor_T=finite(sampled_profiles.fpol(pn) / native_r, "sample Btor_T"),
                       pressure_Pa=finite(sampled_profiles.pressure(pn), "sample pressure_Pa"),
                       Jphi_A_per_m2=finite(current[i, j], "sample Jphi_A_per_m2"),
                       psi_native_wb_per_rad=finite(psi[i, j], "native final psi"),
                       psi_axis_wb_per_rad=finite(sampled_profiles.psi_axis, "profile psi axis"),
                       psi_boundary_wb_per_rad=finite(sampled_profiles.psi_bndry, "profile psi boundary"),
                       core_mask=finite(mask[i, j], "native core mask"),
                       pprime_Pa_per_flux=finite(sampled_profiles.pprime(pn), "sample pprime"),
                       ffprime_T2_m2_per_flux=finite(sampled_profiles.ffprime(pn), "sample FFprime"),
                       mu0_N_per_A2=float(mu0))
        rows.append(row)
    if source_state() != original_state or eq._profiles is not profiles or profiles.eq is not eq:
        raise RuntimeError("constitutive sampling mutated the accepted equilibrium/profile state")
    return rows


def sample_lcfs_trace(eq: object, profiles: object, np: object) -> dict:
    """Return an opt-in, same-final-equilibrium LCFS trace and coil responses.

    The accepted equilibrium/profile pair is never refreshed in place. A linked
    copy refreshes the ConstrainPaxisIp law from final psi, then traces the first
    outward psi_N=1 crossing on each radial ray. Coil fields and sensitivities
    come only from the same final eq.tokamak; total eq.Br/Bz remain separate.
    """
    from freegs import critical
    from freegs.gradshafranov import Greens, mu0
    from scipy.special import ellipk, ellipe
    from scipy.interpolate import RectBivariateSpline
    from scipy.optimize import brentq

    representation = "final_total_psi_grid_spline_radial_lcfs"

    def absent(reason: str) -> dict:
        return {"status": "typed_absent", "reason": reason,
                "representation": representation}

    sampled_eq, sampled_profiles = copy.deepcopy((eq, profiles))
    if sampled_profiles.eq is not sampled_eq or sampled_eq._profiles is not sampled_profiles:
        raise RuntimeError("LCFS trace equilibrium/profile linkage failed")
    for name in ("R", "Z", "plasma_psi", "Jtor"):
        if np.shares_memory(getattr(eq, name), getattr(sampled_eq, name)):
            raise RuntimeError("LCFS trace aliases the accepted equilibrium")

    if bool(getattr(sampled_eq, "is_limited", False)):
        return absent("limited_equilibrium_has_no_separatrix_trace")
    psi = np.asarray(sampled_eq.psi(), dtype=float)
    if psi.ndim != 2 or not np.all(np.isfinite(psi)):
        return absent("final_psi_grid_nonfinite_or_invalid")
    try:
        # Refresh p', F', L and Beta0 from the accepted final psi on the linked
        # copy. This is a profile evaluation, not another equilibrium solve.
        jphi_native = np.asarray(sampled_profiles.Jtor(
            sampled_eq.R, sampled_eq.Z, psi), dtype=float)
        if getattr(sampled_eq, "critical_point_provider", None) is not None:
            opoints, xpoints = sampled_eq.critical_points
        else:
            opoints, xpoints = critical.find_critical(sampled_eq.R, sampled_eq.Z, psi)
    except (ValueError, RuntimeError, FloatingPointError):
        return absent("final_psi_profile_refresh_or_critical_points_unavailable")
    if not opoints:
        return absent("no_magnetic_axis")
    if not xpoints:
        return absent("no_xpoint_separatrix")

    psi_axis = finite(sampled_profiles.psi_axis, "LCFS psi_axis_wb_per_rad")
    psi_boundary = finite(sampled_profiles.psi_bndry, "LCFS psi_boundary_wb_per_rad")
    span = psi_boundary - psi_axis
    if not math.isfinite(span) or span == 0.0:
        return absent("final_psi_normalization_span_invalid")
    normalized_grid = (psi - psi_axis) / span
    if not np.all(np.isfinite(normalized_grid)):
        return absent("normalized_final_psi_grid_nonfinite")
    try:
        core_mask = critical.core_mask(sampled_eq.R, sampled_eq.Z, psi, opoints,
                                       xpoints, psi_boundary)
    except (ValueError, RuntimeError, FloatingPointError):
        core_mask = None
    if core_mask is None or core_mask.shape != psi.shape:
        return absent("final_psi_core_mask_unavailable")
    if bool(getattr(sampled_eq, "is_limited", False)):
        return absent("limited_equilibrium_has_no_separatrix_trace")

    radius_grid = np.asarray(sampled_eq.R[:, 0], dtype=float)
    vertical_grid = np.asarray(sampled_eq.Z[0, :], dtype=float)
    if (not np.all(np.diff(radius_grid) > 0.0) or
            not np.all(np.diff(vertical_grid) > 0.0)):
        return absent("final_psi_grid_axes_invalid")
    normalized_spline = RectBivariateSpline(radius_grid, vertical_grid,
                                            normalized_grid)
    psi_spline = RectBivariateSpline(radius_grid, vertical_grid, psi)
    r0, z0 = (finite(opoints[0][0], "magnetic axis R_m"),
              finite(opoints[0][1], "magnetic axis Z_m"))
    rmin, rmax = float(radius_grid[0]), float(radius_grid[-1])
    zmin, zmax = float(vertical_grid[0]), float(vertical_grid[-1])
    if not (rmin < r0 < rmax and zmin < z0 < zmax):
        return absent("magnetic_axis_outside_interior_grid")

    ntheta = 64
    theta = (np.arange(ntheta, dtype=float) + 0.5) * (2.0 * math.pi / ntheta)
    xpoint_theta = [math.atan2(float(xp[0]) - r0, float(xp[1]) - z0) %
                    (2.0 * math.pi) for xp in xpoints]
    if any(min(abs(t - tx), 2.0 * math.pi - abs(t - tx)) < 1.0e-3
           for t in theta for tx in xpoint_theta):
        theta = theta + math.pi / ntheta
    if any(min(abs((t % (2.0 * math.pi)) - tx),
               2.0 * math.pi - abs((t % (2.0 * math.pi)) - tx)) < 1.0e-3
           for t in theta for tx in xpoint_theta):
        return absent("fixed_lcfs_nodes_intersect_xpoint")

    def nearest_grid_mask(radius: float, vertical: float) -> float:
        i = int(np.argmin(np.abs(radius_grid - radius)))
        j = int(np.argmin(np.abs(vertical_grid - vertical)))
        return float(core_mask[i, j])

    if jphi_native.shape != psi.shape or not np.all(np.isfinite(jphi_native)):
        return absent("final_profile_native_Jphi_grid_invalid")
    mask_values = np.unique(np.asarray(core_mask, dtype=float))
    if not set(float(value) for value in mask_values) <= {0.0, 1.0}:
        return absent("final_core_mask_has_unsupported_values")
    if np.any(jphi_native[np.asarray(core_mask) == 0.0] != 0.0):
        return absent("profile_Jphi_nonzero_outside_final_core_mask")
    dR_values, dZ_values = np.diff(radius_grid), np.diff(vertical_grid)
    dR, dZ = float(dR_values[0]), float(dZ_values[0])
    grid_tol = 16.0 * np.finfo(float).eps * max(1.0, abs(rmin), abs(rmax),
                                                 abs(zmin), abs(zmax))
    if (dR <= 0.0 or dZ <= 0.0 or
            not np.all(np.abs(dR_values - dR) <= grid_tol) or
            not np.all(np.abs(dZ_values - dZ) <= grid_tol)):
        return absent("final_native_grid_is_not_uniform_rectilinear")
    # Nodal trapezoidal area weights: endpoints get half-width in each axis.
    # Interior rings therefore carry exactly Jphi*dR*dZ; edge/corner rings get
    # the appropriate half/quarter cell area and all source currents stay signed.
    wR, wZ = np.ones(len(radius_grid), dtype=float), np.ones(len(vertical_grid), dtype=float)
    wR[[0, -1]] = 0.5
    wZ[[0, -1]] = 0.5
    area_weights = np.outer(wR, wZ) * dR * dZ
    ring_currents = jphi_native * area_weights
    if (not np.all(np.isfinite(area_weights)) or np.any(area_weights <= 0.0) or
            not np.all(np.isfinite(ring_currents))):
        return absent("native_RZ_area_weight_or_ring_current_invalid")
    current_integral = float(np.sum(ring_currents, dtype=np.float64))
    solver_current = finite(sampled_eq.plasmaCurrent(), "FreeGS solver plasma current A")
    area_total = float(np.sum(area_weights, dtype=np.float64))
    # Export only the already-computed points passed to this exact core_mask.
    # No second critical-point search and no accepted-equilibrium mutation.
    def critical_point_records(points):
        return tuple({
            "R_m": finite(point[0], "native critical point R_m"),
            "Z_m": finite(point[1], "native critical point Z_m"),
            "psi_wb_per_rad": finite(point[2], "native critical point psi"),
            "nearest_native_id": int(np.argmin(np.abs(radius_grid - point[0]))) * len(vertical_grid)
                + int(np.argmin(np.abs(vertical_grid - point[1]))) + 1,
        } for point in points)

    critical_point_metadata = {
        "method": ("fusionconceptai.stationary_cubic_spline_gradient_hessian_v2"
                   if getattr(sampled_eq, "critical_point_provider", None) is not None
                   else "freegs.critical.find_critical"),
        "flux_source": "sampled_eq.psi_native_total_grid",
        "core_mask_method": "freegs.critical.core_mask",
        "xpoint_neighborhood_rule": "block_nearest_3x3_then_restore_psiN_lt_1_without_connectivity_recheck",
        "opoints": critical_point_records(opoints),
        "xpoints": critical_point_records(xpoints),
        "core_mask_psi_axis_wb_per_rad": finite(opoints[0][2], "core_mask actual axis psi"),
        "core_mask_psi_boundary_wb_per_rad": psi_boundary,
    }
    if getattr(sampled_eq, "critical_point_provider", None) is not None:
        critical_point_metadata["critical_point_refinement"] = (
            "stationary_cubic_spline_gradient_hessian_v2")

    current_support = {
        "status": "present",
        "reason": "same_final_psi_profile_native_grid_Jphi",
        "representation": "FreeGS_profile_Jtor_final_psi_RZ_nodes",
        "axis_order": "[R_index][Z_index]",
        "current_density_component": "toroidal_Jphi_A_per_m2",
        "positive_current_direction": "positive_cylindrical_phi; values remain signed",
        "R_m": tuple(float(value) for value in radius_grid),
        "Z_m": tuple(float(value) for value in vertical_grid),
        "psi_wb_per_rad": tuple(tuple(finite(value, "native psi Wb/rad") for value in row)
                                  for row in psi),
        "psi_normalized": tuple(tuple(finite(value, "native psi_N") for value in row)
                                 for row in normalized_grid),
        "core_mask": tuple(tuple(float(value) for value in row) for row in core_mask),
        "critical_points": critical_point_metadata,
        "Jphi_A_per_m2": tuple(tuple(finite(value, "native Jphi A/m2") for value in row)
                                for row in jphi_native),
        "area_weight_m2": tuple(tuple(finite(value, "native RZ area weight m2") for value in row)
                                 for row in area_weights),
        "ring_current_A": tuple(tuple(finite(value, "native ring current A") for value in row)
                                 for row in ring_currents),
        "dR_m": finite(dR, "native dR m; positive",),
        "dZ_m": finite(dZ, "native dZ m; positive",),
        "area_weight_rule": "tensor_product_trapezoid; dR*dZ interior, half endpoint widths",
        "ring_current_rule": "I_phi[i,j] = Jphi[i,j] * area_weight_m2[i,j]",
        "current_integral_trapezoid_A": finite(current_integral, "native trapezoid current A"),
        "solver_plasma_current_A": solver_current,
        "native_RZ_area_m2": finite(area_total, "native RZ area m2"),
        "independent_toroidal_field_source": {
            "status": "typed_absent",
            "reason": "candidate_bound_TF_coil_current_and_geometry_unavailable"
        },
    }
    raw_samples = []
    def greens_gradient(radius: float, vertical: float) -> tuple[float, float, bool]:
        """Analytic derivative of linked tokamak Greens, with source check."""
        eps = 1.0e-5 * max(1.0, abs(radius), abs(vertical))
        total_r, total_z = 0.0, 0.0
        check_r, check_z = 0.0, 0.0
        for _label, coil in sampled_eq.tokamak.coils:
            rc, zc = float(coil.R), float(coil.Z)
            current = float(coil.current) * int(coil.turns)

            def k2_at(r: float, z: float) -> float:
                return 4.0 * r * rc / ((r + rc) ** 2 + (z - zc) ** 2)

            k2 = k2_at(radius, vertical)
            stencil = (k2_at(radius + eps, vertical), k2_at(radius - eps, vertical),
                       k2_at(radius, vertical + eps), k2_at(radius, vertical - eps))
            if (not math.isfinite(k2) or not 1.0e-10 < k2 < 1.0 - 1.0e-10 or
                    any(not math.isfinite(value) or
                        not 1.0e-10 < value < 1.0 - 1.0e-10 for value in stencil)):
                return 0.0, 0.0, False
            kcomp, ecomp = float(ellipk(k2)), float(ellipe(k2))
            numerator = (2.0 - k2) * kcomp - 2.0 * ecomp
            numerator_prime = -0.5 * kcomp + ecomp / (2.0 * (1.0 - k2))
            h = numerator / math.sqrt(k2)
            h_prime = numerator_prime / math.sqrt(k2) - numerator / (2.0 * k2 ** 1.5)
            denominator = (radius + rc) ** 2 + (vertical - zc) ** 2
            dk2_dr = k2 * (1.0 / radius - 2.0 * (radius + rc) / denominator)
            dk2_dz = -2.0 * k2 * (vertical - zc) / denominator
            scale = mu0 / (2.0 * math.pi)
            dpsi_dr = scale * math.sqrt(rc * radius) * (
                h / (2.0 * radius) + h_prime * dk2_dr)
            dpsi_dz = scale * math.sqrt(rc * radius) * h_prime * dk2_dz
            fd_dr = (float(Greens(rc, zc, radius + eps, vertical)) -
                     float(Greens(rc, zc, radius - eps, vertical))) / (2.0 * eps)
            fd_dz = (float(Greens(rc, zc, radius, vertical + eps)) -
                     float(Greens(rc, zc, radius, vertical - eps))) / (2.0 * eps)
            total_r += current * dpsi_dr
            total_z += current * dpsi_dz
            check_r += current * fd_dr
            check_z += current * fd_dz
        scale = max(1.0e-30, abs(total_r), abs(total_z), abs(check_r), abs(check_z))
        ok = (math.isfinite(total_r) and math.isfinite(total_z) and
              math.isfinite(check_r) and math.isfinite(check_z) and
              max(abs(total_r - check_r), abs(total_z - check_z)) <=
              5.0e-6 * scale + 1.0e-12)
        return total_r, total_z, ok

    btor_mask_matches_current_support = (
        getattr(sampled_eq, "mask", None) is not None and
        np.asarray(sampled_eq.mask).shape == np.asarray(core_mask).shape and
        np.array_equal(np.asarray(sampled_eq.mask), np.asarray(core_mask)))
    for angle in theta:
        dr, dz = math.sin(float(angle)), math.cos(float(angle))
        limits = []
        limits.append((rmax - r0) / dr if dr > 0 else (rmin - r0) / dr)
        limits.append((zmax - z0) / dz if dz > 0 else (zmin - z0) / dz)
        ray_end = min(value for value in limits if value > 0.0)
        if not math.isfinite(ray_end) or ray_end <= 0.0:
            return absent("radial_ray_has_no_domain_exit")
        ray_t = np.linspace(0.0, ray_end * (1.0 - 1.0e-10), 1025)
        ray_r = r0 + ray_t * dr
        ray_z = z0 + ray_t * dz
        ray_psi_n = np.asarray(normalized_spline.ev(ray_r, ray_z), dtype=float)
        if not np.all(np.isfinite(ray_psi_n)) or ray_psi_n[0] >= 1.0:
            return absent("radial_ray_does_not_start_inside_plasma")
        crossings = np.flatnonzero((ray_psi_n[:-1] < 1.0) &
                                   (ray_psi_n[1:] > 1.0))
        if crossings.size == 0:
            return absent("radial_ray_has_no_outward_psi1_crossing")
        k = int(crossings[0])
        t_left, t_right = float(ray_t[k]), float(ray_t[k + 1])
        root_t = brentq(lambda t: float(normalized_spline.ev(
            r0 + t * dr, z0 + t * dz)) - 1.0, t_left, t_right,
            xtol=1.0e-12, rtol=8.0 * np.finfo(float).eps)
        radius, vertical = r0 + root_t * dr, z0 + root_t * dz
        psi_n = float(normalized_spline.ev(radius, vertical))
        if not math.isfinite(psi_n) or abs(psi_n - 1.0) > 1.0e-9:
            return absent("lcfs_root_tolerance_failed")

        # Find actual inside/outside core-mask cells adjacent to the first
        # flux crossing. These are support evidence, not interpolated mask data.
        inside = None
        for index in range(k, -1, -1):
            if ray_psi_n[index] < 1.0 and nearest_grid_mask(
                    float(ray_r[index]), float(ray_z[index])) == 1.0:
                inside = index
                break
        outside = None
        for index in range(k + 1, len(ray_t)):
            if ray_psi_n[index] > 1.0 and nearest_grid_mask(
                    float(ray_r[index]), float(ray_z[index])) == 0.0:
                outside = index
                break
        if inside is None or outside is None:
            return absent("lcfs_inside_outside_core_mask_support_unavailable")
        core_mask_inside = nearest_grid_mask(float(ray_r[inside]), float(ray_z[inside]))
        core_mask_outside = nearest_grid_mask(float(ray_r[outside]), float(ray_z[outside]))
        if core_mask_inside != 1.0 or core_mask_outside != 0.0:
            return absent("lcfs_core_mask_transition_invalid")

        grad_r = float(normalized_spline.ev(radius, vertical, dx=1, dy=0))
        grad_z = float(normalized_spline.ev(radius, vertical, dx=0, dy=1))
        gradient_norm = math.hypot(grad_r, grad_z)
        if not math.isfinite(gradient_norm) or gradient_norm <= 1.0e-12:
            return absent("lcfs_normal_gradient_unsupported")
        normal_r, normal_z = grad_r / gradient_norm, grad_z / gradient_norm
        if normal_r * dr + normal_z * dz <= 0.0:
            return absent("lcfs_normal_not_outward")

        # The root coordinate is numerically within tolerance of psi_N=1.
        # Evaluate the profile on its exact declared boundary endpoint so tiny
        # quadrature roundoff from a reversed [1+ulp, 1] interval cannot create
        # a negative pressure. The reported psi_n remains the actual spline root.
        psi_profile = 1.0
        current_density = (radius * float(sampled_profiles.pprime(psi_profile)) +
                           float(sampled_profiles.ffprime(psi_profile)) /
                           (radius * mu0)) * core_mask_inside
        f_t_m = finite(sampled_profiles.fpol(psi_profile), "LCFS F_T_m")
        pressure = finite(sampled_profiles.pressure(psi_profile), "LCFS pressure_Pa")
        psi_value = finite(psi_spline.ev(radius, vertical), "LCFS psi_wb_per_rad")
        total_br = finite(sampled_eq.Br(radius, vertical), "LCFS total Br_T")
        total_bz = finite(sampled_eq.Bz(radius, vertical), "LCFS total Bz_T")
        coil_br = finite(sampled_eq.tokamak.Br(radius, vertical), "LCFS coil-only Br_T")
        coil_bz = finite(sampled_eq.tokamak.Bz(radius, vertical), "LCFS coil-only Bz_T")
        response_br = tuple(finite(value, "LCFS coil dBr/dI")
                            for value in sampled_eq.tokamak.controlBr(radius, vertical))
        response_bz = tuple(finite(value, "LCFS coil dBz/dI")
                            for value in sampled_eq.tokamak.controlBz(radius, vertical))
        control_coils = tuple((label, coil) for label, coil in sampled_eq.tokamak.coils
                              if bool(coil.control))
        if len(response_br) != len(control_coils) or len(response_bz) != len(control_coils):
            return absent("coil_control_response_count_mismatch")
        if len(control_coils) != len(sampled_eq.tokamak.coils):
            return absent("noncontrol_coils_require_fixed_field_decomposition")
        response_rows = tuple({
            "coil_id": str(label),
            "current_A_per_turn": finite(coil.current, "coil current A per turn"),
            "turns": int(coil.turns),
            "dBr_dI_per_turn_T_per_A": response_br[i],
            "dBz_dI_per_turn_T_per_A": response_bz[i],
        } for i, (label, coil) in enumerate(control_coils))
        if any(row["turns"] <= 0 for row in response_rows):
            return absent("coil_turn_count_invalid")
        reconstructed_br = math.fsum(row["current_A_per_turn"] *
                                     row["dBr_dI_per_turn_T_per_A"]
                                     for row in response_rows)
        reconstructed_bz = math.fsum(row["current_A_per_turn"] *
                                     row["dBz_dI_per_turn_T_per_A"]
                                     for row in response_rows)
        response_error = max(abs(reconstructed_br - coil_br),
                             abs(reconstructed_bz - coil_bz))
        tolerance = 1.0e-10 * max(1.0, abs(coil_br), abs(coil_bz))
        if not math.isfinite(response_error) or response_error > tolerance:
            return absent("coil_actuator_superposition_check_failed")
        offgrid_source = {
            "status": "typed_absent",
            "reason": "offgrid_source_evaluation_unavailable",
            "representation": "linked_copied_equilibrium_profile_at_lcfs_point",
        }
        try:
            psi_physical = finite(sampled_eq.psiRZ(radius, vertical),
                                  "LCFS off-grid physical psi")
            coil_psi = finite(sampled_eq.tokamak.psi(radius, vertical),
                              "LCFS off-grid fixed-coil psi")
            eq_axis = finite(sampled_eq.psi_axis, "LCFS equilibrium psi axis")
            eq_boundary = finite(sampled_eq.psi_bndry, "LCFS equilibrium psi boundary")
            profile_axis = finite(sampled_profiles.psi_axis, "LCFS profile psi axis")
            profile_boundary = finite(sampled_profiles.psi_bndry,
                                      "LCFS profile psi boundary")
            eq_span = eq_boundary - eq_axis
            if not math.isfinite(eq_span) or eq_span == 0.0:
                raise ValueError("equilibrium_flux_span_invalid")
            eq_psi_normalized = (psi_physical - eq_axis) / eq_span
            mask_func = getattr(sampled_eq, "mask_func", None)
            if mask_func is None:
                raise ValueError("equilibrium_btor_mask_unavailable")
            mask_value = finite(mask_func(radius, vertical, grid=False),
                                "LCFS actual Btor mask")
            mask_r = finite(mask_func(radius, vertical, dx=1, dy=0, grid=False),
                            "LCFS actual Btor mask d/dR")
            mask_z = finite(mask_func(radius, vertical, dx=0, dy=1, grid=False),
                            "LCFS actual Btor mask d/dZ")
            actual_btor = finite(sampled_eq.Btor(radius, vertical),
                                 "LCFS actual FreeGS Btor")
            actual_fpol = finite(sampled_profiles.fpol(eq_psi_normalized),
                                 "LCFS actual off-grid fpol")
            actual_pressure = finite(sampled_profiles.pressure(eq_psi_normalized),
                                     "LCFS actual off-grid pressure")
            if actual_fpol <= 0.0:
                raise ValueError("offgrid_fpol_not_on_positive_sqrt_branch")
            grad_r, grad_z, gradient_ok = greens_gradient(radius, vertical)
            offgrid_source = {
                "status": "present",
                "reason": "actual_linked_freegs_source_evaluations",
                "representation": "linked_copied_equilibrium_profile_at_lcfs_point",
                "psi_physical_wb_per_rad": psi_physical,
                "coil_psi_wb_per_rad": coil_psi,
                "eq_psi_axis_wb_per_rad": eq_axis,
                "eq_psi_boundary_wb_per_rad": eq_boundary,
                "profile_psi_axis_wb_per_rad": profile_axis,
                "profile_psi_boundary_wb_per_rad": profile_boundary,
                "mask_value": mask_value,
                "mask_gradient_RZ_per_m": (mask_r, mask_z),
                "mask_source": "sampled_eq.mask_func RectBivariateSpline of sampled_eq.mask",
                "mask_matches_refreshed_current_support": bool(
                    btor_mask_matches_current_support),
                "Btor_T": actual_btor,
                "profile_pressure_Pa": actual_pressure,
                "fpol_T_m": actual_fpol,
                "psi_normalized": finite(eq_psi_normalized,
                                          "LCFS eq-normalized off-grid psi"),
                "coil_psi_gradient_status": "present" if gradient_ok else "typed_absent",
                "coil_psi_gradient_reason": (
                    "analytic_greens_gradient_checked_against_source_centered_difference"
                    if gradient_ok else
                    "coil_psi_gradient_clip_singularity_or_source_difference_failed"),
                "branch_metadata": {
                    "profile_type": type(sampled_profiles).__name__,
                    "fpol_sqrt_branch": "positive",
                    "fpol_positive_checked": True,
                    "pressure_evaluation": "FreeGS_profile_pressure_at_eq_normalized_psi",
                    "psi_normalization_axis_pair": "equilibrium",
                    "profile_integral_axis_pair": "profile",
                    "eq_profile_axis_pairs_equal": bool(
                        eq_axis == profile_axis and eq_boundary == profile_boundary),
                },
            }
            if gradient_ok:
                offgrid_source["coil_psi_gradient_RZ_Wb_per_rad_m"] = (grad_r, grad_z)
        except (AttributeError, TypeError, ValueError, RuntimeError,
                FloatingPointError, OverflowError) as exc:
            offgrid_source["reason"] = "offgrid_source_evaluation_failed"
            offgrid_source["detail_reason"] = str(exc) or type(exc).__name__
        raw_samples.append({
            "R_m": finite(radius, "LCFS R_m"),
            "Z_m": finite(vertical, "LCFS Z_m"),
            "normal_R": finite(normal_r, "LCFS normal_R"),
            "normal_Z": finite(normal_z, "LCFS normal_Z"),
            "psi_normalized": finite(psi_n, "LCFS psi_normalized"),
            "psi_wb_per_rad": psi_value,
            "Br_T": total_br,
            "Btor_T": finite(f_t_m / radius, "LCFS Btor_T"),
            "Bz_T": total_bz,
            "pressure_Pa": pressure,
            "F_T_m": f_t_m,
            "Jphi_A_per_m2": finite(current_density, "LCFS Jphi_A_per_m2"),
            "offgrid_source": offgrid_source,
            "core_mask_inside": core_mask_inside,
            "core_mask_outside": core_mask_outside,
            "coil_Br_T": coil_br,
            "coil_Bz_T": coil_bz,
            "coil_response": response_rows,
        })

    profile_law = {
        "L_A_per_m2": finite(sampled_profiles.L, "profile L_A_per_m2"),
        "Beta0": finite(sampled_profiles.Beta0, "profile Beta0"),
        "alpha_m": finite(sampled_profiles.alpha_m, "profile alpha_m"),
        "alpha_n": finite(sampled_profiles.alpha_n, "profile alpha_n"),
        "Raxis_m": finite(sampled_profiles.Raxis, "profile Raxis_m"),
        "fvac_T_m": finite(sampled_profiles.fvac(), "profile fvac_T_m"),
    }
    if profile_law["alpha_m"] <= 0.0 or profile_law["alpha_n"] <= 0.0 or profile_law["Raxis_m"] <= 0.0:
        return absent("final_profile_law_outside_supported_domain")
    coils = tuple({
        "coil_id": str(label),
        "major_radius_m": finite(coil.R, "coil major radius m"),
        "vertical_position_m": finite(coil.Z, "coil vertical position m"),
        "current_A_per_turn": finite(coil.current, "coil current A per turn"),
        "turns": int(coil.turns),
        "ampere_turns_A": finite(coil.current * coil.turns, "coil ampere-turns A"),
        "control": bool(coil.control),
    } for label, coil in sampled_eq.tokamak.coils)
    if len(coils) != len(raw_samples[0]["coil_response"]):
        return absent("coil_state_response_binding_mismatch")
    if tuple(row["coil_id"] for row in coils) != tuple(
            row["coil_id"] for row in raw_samples[0]["coil_response"]):
        return absent("coil_id_response_binding_mismatch")
    return {
        "status": "present",
        "reason": "same_final_equilibrium_lcfs_trace",
        "representation": representation,
        "psi_axis_wb_per_rad": finite(sampled_profiles.psi_axis, "profile psi_axis"),
        "psi_boundary_wb_per_rad": finite(sampled_profiles.psi_bndry, "profile psi_boundary"),
        "mu0_N_per_A2": finite(mu0, "mu0_N_per_A2"),
        "profile_boundary_pressure_Pa": finite(sampled_profiles.pressure(1.0),
                                                   "profile boundary pressure"),
        "profile_law": profile_law,
        "coil_current_semantics": "current_A_per_turn; turns reported separately; actuator response is T per A-per-turn at fixed plasma/geometry/profile",
        "coil_response_method": "FreeGS tokamak.controlBr/controlBz on the same final equilibrium; each response includes that coil's turns",
        "offgrid_source_method": {
            "schema": "lcfs_offgrid_source_v1",
            "psi_method": "FreeGS_Equilibrium_psiRZ",
            "btor_method": "FreeGS_Equilibrium_Btor",
            "profile_method": "linked_sampled_profiles_at_eq_psi_normalized",
            "mask_method": "sampled_eq_mask_func_RectBivariateSpline_value_and_first_derivatives",
            "mask_support_comparison": "numpy_array_equal_sampled_eq_mask_vs_refreshed_core_mask",
            "gradient_method": "analytic_installed_FreeGS_Greens_sum_weighted_by_current_times_turns",
            "gradient_validation": "centered_difference_of_installed_FreeGS_Greens_source_per_LCFS_point",
            "gradient_validation_rtol": 5.0e-6,
            "gradient_validation_atol_Wb_per_rad_m": 1.0e-12,
            "gradient_support_rule": "typed_absent_on_any_clipped_or_singular_source_stencil_or_gradient_mismatch",
        },
        "coil_response_identity_max_abs_error_T": max(
            max(abs(math.fsum(row["current_A_per_turn"] * row["dBr_dI_per_turn_T_per_A"]
                            for row in sample["coil_response"]) - sample["coil_Br_T"]),
                abs(math.fsum(row["current_A_per_turn"] * row["dBz_dI_per_turn_T_per_A"]
                            for row in sample["coil_response"]) - sample["coil_Bz_T"]))
            for sample in raw_samples),
        "coils": coils,
        "current_support": current_support,
        "samples": tuple(raw_samples),
    }


def sample_solver_jtor_diagnostic(eq: object, profiles: object, np: object) -> dict:
    """Capture FreeGS's retained last-solve Jtor and compare it to final-psi Jphi.

    ``eq.Jtor`` is the actual current-density array assigned by the last
    ``Equilibrium.solve`` call. The comparison field is recomputed on a linked
    copy from the accepted final psi/profile, like the existing LCFS current
    support. They represent different evaluation states and are never aliased
    or presumed equal here.
    """
    representation = "FreeGS_eq_Jtor_last_linear_solve_RZ_nodes"

    def absent(reason: str) -> dict:
        return {"status": "typed_absent", "reason": reason,
                "representation": representation}

    retained = getattr(eq, "Jtor", None)
    if retained is None:
        return absent("accepted_equilibrium_has_no_retained_Jtor")
    solver_jtor = np.array(retained, dtype=float, copy=True)
    if (solver_jtor.ndim != 2 or solver_jtor.shape != np.asarray(eq.R).shape or
            solver_jtor.shape != np.asarray(eq.Z).shape or
            not np.all(np.isfinite(solver_jtor))):
        return absent("accepted_equilibrium_retained_Jtor_shape_or_values_invalid")

    sampled_eq, sampled_profiles = copy.deepcopy((eq, profiles))
    if sampled_profiles.eq is not sampled_eq or sampled_eq._profiles is not sampled_profiles:
        return absent("final_profile_comparison_copy_linkage_invalid")
    psi = np.asarray(sampled_eq.psi(), dtype=float)
    try:
        recomputed_jphi = np.asarray(sampled_profiles.Jtor(
            sampled_eq.R, sampled_eq.Z, psi), dtype=float)
    except (ValueError, RuntimeError, FloatingPointError):
        return absent("final_psi_profile_Jphi_recompute_unavailable")
    if (psi.ndim != 2 or psi.shape != solver_jtor.shape or
            recomputed_jphi.shape != solver_jtor.shape or
            not np.all(np.isfinite(psi)) or not np.all(np.isfinite(recomputed_jphi))):
        return absent("final_psi_profile_Jphi_shape_or_values_invalid")

    radius = np.asarray(eq.R[:, 0], dtype=float)
    vertical = np.asarray(eq.Z[0, :], dtype=float)
    dR_values, dZ_values = np.diff(radius), np.diff(vertical)
    if (len(dR_values) == 0 or len(dZ_values) == 0 or
            not np.all(np.isfinite(radius)) or not np.all(np.isfinite(vertical)) or
            not np.all(dR_values > 0.0) or not np.all(dZ_values > 0.0)):
        return absent("native_RZ_axes_invalid_for_comparison")
    dR, dZ = float(dR_values[0]), float(dZ_values[0])
    grid_tol = 16.0 * np.finfo(float).eps * max(
        1.0, abs(float(radius[0])), abs(float(radius[-1])),
        abs(float(vertical[0])), abs(float(vertical[-1])))
    if (not np.all(np.abs(dR_values - dR) <= grid_tol) or
            not np.all(np.abs(dZ_values - dZ) <= grid_tol)):
        return absent("native_RZ_axes_not_uniform_for_trapezoid_comparison")

    wR, wZ = np.ones(len(radius), dtype=float), np.ones(len(vertical), dtype=float)
    wR[[0, -1]] = 0.5
    wZ[[0, -1]] = 0.5
    area_weights = np.outer(wR, wZ) * dR * dZ
    difference = solver_jtor - recomputed_jphi
    solver_norm = float(np.linalg.norm(solver_jtor.ravel()))
    recomputed_norm = float(np.linalg.norm(recomputed_jphi.ravel()))
    difference_norm = float(np.linalg.norm(difference.ravel()))
    solver_trapezoid = float(np.sum(solver_jtor * area_weights, dtype=np.float64))
    recomputed_trapezoid = float(np.sum(recomputed_jphi * area_weights, dtype=np.float64))
    difference_trapezoid = float(np.sum(difference * area_weights, dtype=np.float64))
    stats = (solver_norm, recomputed_norm, difference_norm, solver_trapezoid,
             recomputed_trapezoid, difference_trapezoid)
    if not all(math.isfinite(value) for value in stats):
        return absent("Jtor_comparison_norm_or_integral_nonfinite")

    return {
        "status": "present",
        "reason": "accepted_final_equilibrium_last_solve_vs_recomputed_final_psi_profile",
        "representation": representation,
        "axis_order": "[R_index][Z_index]",
        "current_density_component": "toroidal_Jphi_A_per_m2",
        "positive_current_direction": "positive_cylindrical_phi; values remain signed",
        "solver_array_provenance": "eq.Jtor retained after final Picard Equilibrium.solve call; last Grad-Shafranov RHS current-density grid",
        "solver_array_update_semantics": "Equilibrium.solve computes or receives Jtor before its elliptic flux update, then assigns self.Jtor=Jtor; Picard calls solve repeatedly and returns with the final call retained",
        "comparison_array_provenance": "ConstrainPaxisIp.Jtor recomputed from accepted final psi on a linked deep copy; separate from retained eq.Jtor",
        "R_m": tuple(float(value) for value in radius),
        "Z_m": tuple(float(value) for value in vertical),
        "solver_eq_Jtor_A_per_m2": tuple(
            tuple(finite(value, "retained solver eq.Jtor A/m2") for value in row)
            for row in solver_jtor),
        "recomputed_final_psi_Jphi_A_per_m2": tuple(
            tuple(finite(value, "recomputed final-psi profile Jphi A/m2") for value in row)
            for row in recomputed_jphi),
        "solver_minus_recomputed_norms": {
            "difference_Linf_A_per_m2": finite(np.max(np.abs(difference)), "Jtor difference Linf"),
            "difference_L2_frobenius_A_per_m2": finite(difference_norm, "Jtor difference L2"),
            "relative_difference_L2_dimensionless": finite(
                difference_norm / max(solver_norm, recomputed_norm, 1.0e-300),
                "Jtor relative difference L2"),
            "difference_RZ_trapezoid_integral_A": finite(
                difference_trapezoid, "Jtor difference trapezoid current A"),
        },
        "current_integrals": {
            "solver_eq_Jtor_RZ_trapezoid_A": finite(solver_trapezoid, "solver Jtor trapezoid current A"),
            "recomputed_final_psi_Jphi_RZ_trapezoid_A": finite(
                recomputed_trapezoid, "recomputed Jphi trapezoid current A"),
            "difference_solver_minus_recomputed_trapezoid_A": finite(
                difference_trapezoid, "Jtor trapezoid current difference A"),
            "solver_eq_plasmaCurrent_Romberg_A": finite(
                eq.plasmaCurrent(), "FreeGS solver stored Romberg plasma current A"),
        },
        "RZ_area_weight_rule": "tensor_product_trapezoid; dR*dZ interior, half endpoint widths",
        "difference_integral_rule": "sum((solver_eq_Jtor - recomputed_final_psi_Jphi) * RZ_area_weight)",
    }


def sample_native_gs4_state(eq: object, diagnostic: dict, np: object,
                            trace: dict,
                            source_response_path: Optional[Path] = None) -> dict:
    """Same-equilibrium plasma flux and absolute GS4 interior residuals.

    Retained and final-profile currents are deliberately separate states.
    This export neither changes the solve nor subtracts its residual.
    """
    absent = lambda reason: {"status": "typed_absent", "reason": reason}
    if diagnostic.get("status") != "present":
        return absent("retained_and_final_profile_currents_unavailable")
    if getattr(eq, "order", None) != 4:
        return absent("unsupported_native_GS_order")
    boundary = getattr(eq, "_applyBoundary", None)
    if (getattr(boundary, "__module__", None), getattr(boundary, "__name__", None)) != (
            "freegs.boundary", "freeBoundaryHagenow"):
        return absent("unsupported_native_boundary_method")
    plasma = np.asarray(eq.plasma_psi, dtype=float)
    R, Z = np.asarray(eq.R, dtype=float), np.asarray(eq.Z, dtype=float)
    if (plasma.shape != R.shape or plasma.shape != Z.shape or plasma.ndim != 2 or
            min(plasma.shape) < 6 or not np.all(np.isfinite(plasma))):
        return absent("native_plasma_flux_shape_or_values_invalid")
    from freegs import boundary as freegs_boundary
    from freegs.gradshafranov import GSsparse4thOrder, mu0
    operator = GSsparse4thOrder(float(R[0, 0]), float(R[-1, 0]),
                               float(Z[0, 0]), float(Z[0, -1]))(*plasma.shape)
    from scipy.sparse import eye
    from scipy.sparse.linalg import splu
    nr, nz = plasma.shape
    rr, zz = np.indices(plasma.shape)
    edge_mask = (rr == 0) | (rr == nr - 1) | (zz == 0) | (zz == nz - 1)
    solver_boundary_ids = np.flatnonzero(edge_mask.ravel(order="C"))
    solver_interior_ids = np.flatnonzero(~edge_mask.ravel(order="C"))
    if operator.shape != (nr * nz, nr * nz) or solver_boundary_ids.size + solver_interior_ids.size != nr * nz:
        raise ValueError("native GS4 matrix and Dirichlet partition dimensions differ")
    Aii = operator[solver_interior_ids, :][:, solver_interior_ids].tocsc()
    Aib = operator[solver_interior_ids, :][:, solver_boundary_ids].tocsc()
    Abb = operator[solver_boundary_ids, :][:, solver_boundary_ids].tocsr()
    Abi = operator[solver_boundary_ids, :][:, solver_interior_ids].tocsr()
    if (Abb - eye(len(solver_boundary_ids), format="csr")).nnz or Abi.nnz:
        raise ValueError("native FreeGS GS4 boundary rows are not identity/decoupled")
    source_Aii_lu = splu(Aii)
    solve_Aii = source_Aii_lu.solve

    class ExactDirichletEliminationSolver:
        """Solve the unchanged full GS4 equations after exact edge elimination."""

        def __call__(self, initial: object, rhs: object) -> object:
            del initial  # Direct solve; retain FreeGS's solver(x, b) interface.
            rhs_array = np.asarray(rhs, dtype=float)
            if rhs_array.shape != plasma.shape or not np.all(np.isfinite(rhs_array)):
                raise ValueError("native GS4 solver RHS shape or values are invalid")
            rhs_flat = rhs_array.ravel(order="C")
            x_boundary = rhs_flat[solver_boundary_ids]  # A_BB=I and A_BI=0.
            rhs_interior = rhs_flat[solver_interior_ids] - Aib @ x_boundary
            solution = np.zeros(rhs_flat.shape, dtype=float)
            solution[solver_boundary_ids] = x_boundary
            solution[solver_interior_ids] = solve_Aii(rhs_interior)
            return solution.reshape(plasma.shape, order="C")

    source_linear_solver = ExactDirichletEliminationSolver()
    flux_operator = (operator @ plasma.ravel(order="C")).reshape(plasma.shape)
    retained = np.asarray(diagnostic["solver_eq_Jtor_A_per_m2"], dtype=float)
    final = np.asarray(diagnostic["recomputed_final_psi_Jphi_A_per_m2"], dtype=float)
    if retained.shape != plasma.shape or final.shape != plasma.shape:
        return absent("native_GS_current_shape_mismatch")
    support = trace.get("current_support", {})
    law = trace.get("profile_law", {})
    if support.get("status") != "present" or not law:
        return absent("native_Hagenow_profile_support_unavailable")
    psi = np.asarray(support.get("psi_wb_per_rad"), dtype=float)
    psi_n = np.asarray(support.get("psi_normalized"), dtype=float)
    core = np.asarray(support.get("core_mask"), dtype=float)
    if any(array.shape != plasma.shape for array in (psi, psi_n, core)):
        return absent("native_Hagenow_profile_support_shape_mismatch")
    if (not np.all(np.isfinite(psi)) or not np.all(np.isfinite(psi_n)) or
            not np.all(np.isin(core, (0.0, 1.0)))):
        return absent("native_Hagenow_profile_support_values_invalid")
    alpha_m, alpha_n = float(law["alpha_m"]), float(law["alpha_n"])
    if (alpha_m, alpha_n) != (1.0, 2.0):
        return absent("native_Hagenow_profile_exponents_unsupported")
    Raxis = float(law["Raxis_m"])
    psi_axis = float(trace["psi_axis_wb_per_rad"])
    psi_boundary = float(trace["psi_boundary_wb_per_rad"])
    L = float(law["L_A_per_m2"])
    beta0 = float(law["Beta0"])
    span = psi_boundary - psi_axis
    if not all(math.isfinite(value) for value in (Raxis, psi_axis, psi_boundary, L, beta0, span)) or Raxis <= 0 or span == 0:
        return absent("native_Hagenow_profile_law_invalid")
    shape = (1.0 - np.clip(psi_n, 0.0, 1.0)) ** 2
    shape *= core
    coeff_u = R / Raxis
    coeff_v = Raxis / R
    u, v = L * beta0, L * (1.0 - beta0)
    dJ_dpsi = (u * coeff_u + v * coeff_v) * (2.0 * (psi - psi_boundary) / (span * span)) * core
    dJ_du = coeff_u * shape
    dJ_dv = coeff_v * shape
    boundary_mask = np.zeros(plasma.shape, dtype=bool)
    boundary_mask[[0, -1], :] = True
    boundary_mask[:, [0, -1]] = True
    boundary_ids = np.flatnonzero(boundary_mask.ravel(order="C")) + 1
    plasma_before = plasma.copy()
    retained_before = np.asarray(eq.Jtor, dtype=float).copy()
    coils_before = tuple((str(label), float(coil.current)) for label, coil in eq.tokamak.coils)

    def source_boundary(current: object, label: str) -> tuple[float, ...]:
        psi_copy = plasma.copy()
        current_copy = np.asarray(current, dtype=float).copy()
        if current_copy.shape != plasma.shape or not np.all(np.isfinite(current_copy)):
            raise ValueError(f"invalid current input for independent FreeGS boundary call: {label}")
        previous_solver = eq._solver
        eq.setSolver(source_linear_solver)
        try:
            freegs_boundary.freeBoundaryHagenow(eq, current_copy, psi_copy)
        finally:
            eq.setSolver(previous_solver)
        if (not np.array_equal(np.asarray(eq.plasma_psi), plasma_before) or
                not np.array_equal(np.asarray(eq.Jtor), retained_before) or
                tuple((str(label), float(coil.current)) for label, coil in eq.tokamak.coils) != coils_before):
            raise RuntimeError("independent FreeGS boundary reference mutated accepted equilibrium state")
        if eq._solver is not previous_solver:
            raise RuntimeError("independent FreeGS boundary reference did not restore the equilibrium solver")
        values = psi_copy.ravel(order="C")[boundary_ids - 1]
        return tuple(finite(value, f"FreeGS source {label} boundary psi") for value in values)

    source_feedback = {
        "status": "present",
        "api": "freegs.boundary.freeBoundaryHagenow",
        "api_module": freegs_boundary.freeBoundaryHagenow.__module__,
        "api_name": freegs_boundary.freeBoundaryHagenow.__name__,
        "boundary_native_ids": tuple(int(value) for value in boundary_ids),
        "final_profile_boundary_values_wb_per_rad": source_boundary(final, "accepted final Jphi"),
        "psi_direction_boundary_values_wb_per_rad": source_boundary(dJ_dpsi, "dJphi/dpsi core direction"),
        "u_direction_boundary_values_wb_per_rad": source_boundary(dJ_du, "dJphi/du core direction"),
        "v_direction_boundary_values_wb_per_rad": source_boundary(dJ_dv, "dJphi/dv core direction"),
        "direction_definition": "source freeBoundaryHagenow applied directly to full-grid accepted Jphi and its full-core profile derivative currents",
        "source_solver_backend": "Equilibrium.setSolver(ExactDirichletEliminationSolver); direct sparse LU on GS4 A_II; x_B=b_B; interior RHS b_I-A_IB*x_B",
        "source_solver_matrix": "original FreeGS GSsparse4thOrder full matrix, exact Dirichlet elimination; no equation or boundary law change",
        "source_solver_restored_after_each_call": True,
        "equilibrium_iteration_solver_preserved": True,
        "equilibrium_iteration_solver_backend": type(eq._solver).__name__,
        "axis_order": "[R_index][Z_index]",
        "absolute_boundary_anchor_subtracted": False,
        "source_eq_mutated": False,
        "source_eq_mutation_check": "plasma_psi,Jtor,PF_currents",
        "source_plasma_psi_input_copy": True,
        "full_hagenow_jacobian_status": "not_executed",
    }
    if source_response_path is not None:
        from freegs.gradshafranov import Greens
        from scipy.integrate import romb
        from scipy.sparse import csr_matrix

        nr, nz = plasma.shape
        dR, dZ = float(R[1, 0] - R[0, 0]), float(Z[0, 1] - Z[0, 0])
        core_ids = np.flatnonzero(core.ravel(order="C") == 1.0)
        core_native_ids = (core_ids + 1).tolist()
        if not core_ids.size or not np.all(np.isin(core_ids, solver_interior_ids)):
            raise ValueError("Hagenow source response core must be nonempty and interior to the fixed GS4 edge")

        # Independently spell out FreeGS's fourth-order face traces. The two
        # oriented face incidences at each corner intentionally share the same
        # diagonal trace; Q therefore has 2*nR+2*nZ rows.
        trace_rows: list[int] = []
        trace_cols: list[int] = []
        trace_values: list[float] = []
        coefficients = ((0, 25.0 / 12), (1, -4.0), (2, 3.0),
                        (3, -16.0 / 12), (4, 1.0 / 4))
        diagonal_step = math.hypot(dR, dZ)
        offset = 0
        for face in range(4):
            count = nr if face < 2 else nz
            for pos in range(count):
                corner = pos == 0 or pos == count - 1
                for depth, weight in coefficients:
                    if face == 0:  # down
                        i, j = ((depth, depth) if pos == 0 else
                                (nr - 1 - depth, depth) if pos == nr - 1 else
                                (pos, depth))
                        scale = 1.0 / (diagonal_step if corner else dZ)
                    elif face == 1:  # up
                        i, j = ((depth, nz - 1 - depth) if pos == 0 else
                                (nr - 1 - depth, nz - 1 - depth) if pos == nr - 1 else
                                (pos, nz - 1 - depth))
                        scale = 1.0 / (diagonal_step if corner else dZ)
                    elif face == 2:  # left
                        i, j = ((depth, depth) if pos == 0 else
                                (depth, nz - 1 - depth) if pos == nz - 1 else
                                (depth, pos))
                        scale = 1.0 / (diagonal_step if corner else dR)
                    else:  # right
                        i, j = ((nr - 1 - depth, depth) if pos == 0 else
                                (nr - 1 - depth, nz - 1 - depth) if pos == nz - 1 else
                                (nr - 1 - depth, pos))
                        scale = 1.0 / (diagonal_step if corner else dR)
                    trace_rows.append(offset + pos)
                    trace_cols.append(i * nz + j)
                    trace_values.append(weight * scale)
            offset += count
        Q = csr_matrix((trace_values, (trace_rows, trace_cols)),
                       shape=(2 * nr + 2 * nz, nr * nz))

        # Build source C using its 1 cm outward observation shift (R shift wins
        # at corners), FreeGS Greens, Romberg weights, and face spacings.
        boundary_list = [int(value) for value in boundary_ids]
        weights_r = np.asarray([romb(np.eye(nr)[k]) for k in range(nr)])
        weights_z = np.asarray([romb(np.eye(nz)[k]) for k in range(nz)])
        face_offsets = (0, nr, 2 * nr, 2 * nr + nz)
        C = np.zeros((len(boundary_list), 2 * nr + 2 * nz), dtype=float)
        for row, native_id in enumerate(boundary_list):
            i, j = divmod(native_id - 1, nz)
            robs, zobs = float(R[i, j]), float(Z[i, j])
            if i == 0:
                robs -= 1.0e-2
            elif i == nr - 1:
                robs += 1.0e-2
            elif j == 0:
                zobs -= 1.0e-2
            elif j == nz - 1:
                zobs += 1.0e-2
            C[row, face_offsets[0]:face_offsets[1]] = (
                Greens(R[:, 0], Z[:, 0], robs, zobs) * weights_r * dR / R[:, 0])
            C[row, face_offsets[1]:face_offsets[2]] = (
                Greens(R[:, -1], Z[:, -1], robs, zobs) * weights_r * dR / R[:, -1])
            C[row, face_offsets[2]:face_offsets[3]] = (
                Greens(R[0, :], Z[0, :], robs, zobs) * weights_z * dZ / R[0, :])
            C[row, face_offsets[3]:] = (
                Greens(R[-1, :], Z[-1, :], robs, zobs) * weights_z * dZ / R[-1, :])

        interior_core_rows = np.searchsorted(solver_interior_ids, core_ids)
        QI = Q[:, solver_interior_ids].tocsr()
        Rcore = R.ravel(order="C")[core_ids]
        source_H = np.empty((len(boundary_list), len(core_ids)), dtype=float)
        batch_size = 24
        for start in range(0, len(core_ids), batch_size):
            stop = min(start + batch_size, len(core_ids))
            columns = np.arange(start, stop)
            rhs = np.zeros((len(solver_interior_ids), len(columns)), dtype=float)
            rhs[interior_core_rows[columns], np.arange(len(columns))] = Rcore[columns]
            source_H[:, start:stop] = C @ (QI @ source_Aii_lu.solve(rhs))

        binary_path = source_response_path.with_name("hagenow_source_response.f64")
        source_H_le_f = np.asarray(source_H, dtype="<f8", order="F")
        raw_source_H = source_H_le_f.tobytes(order="F")
        binary_path.parent.mkdir(parents=True, exist_ok=True)
        binary_path.write_bytes(raw_source_H)
        source_feedback["source_response_matrix"] = {
            "status": "present",
            "file_name": binary_path.name,
            "shape": [len(boundary_list), len(core_ids)],
            "byte_count": len(raw_source_H),
            "sha256": hashlib.sha256(raw_source_H).hexdigest(),
            "encoding": "ieee754_float64_little_endian_column_major",
            "boundary_native_ids": boundary_list,
            "core_native_ids": core_native_ids,
        }
    def grid(values, label):
        return tuple(tuple(finite(v, label) for v in row) for row in values)
    return {
        "status": "present", "reason": "same_accepted_equilibrium_absolute_GS4_state",
        "axis_order": "[R_index][Z_index]", "order": int(eq.order),
        "boundary_module": boundary.__module__, "boundary_method": boundary.__name__,
        "plasma_psi_wb_per_rad": grid(plasma, "native plasma psi"),
        "interior_node_rule": "R_indices_1_to_nR_minus_2_then_Z_indices_1_to_nZ_minus_2_zero_based",
        "retained_current_interior_residual": grid(
            (flux_operator + mu0 * R * retained)[1:-1, 1:-1], "retained GS4 residual"),
        "final_profile_interior_residual": grid(
            (flux_operator + mu0 * R * final)[1:-1, 1:-1], "final-profile GS4 residual"),
        "residual_units": "T", "boundary_rows_exported_as_equations": False,
        "residual_baseline_subtracted": False,
        "hagenow_source_feedback": source_feedback,
    }


def _solve_fixed_current_with_anderson(eq: object, profiles: object, freegs: object,
                                       np: object, scipy: object, *, rtol: float,
                                       atol: float, maxits: int) -> tuple:
    """Accelerate only the fixed-current outer GS map, then verify with FreeGS Picard."""
    if maxits < 4:
        return freegs.solve(eq, profiles, None, rtol=rtol, atol=atol,
                            maxits=maxits, convergenceInfo=True)

    eq_state_names = (
        "_profiles", "check_limited", "is_limited", "Rlim", "Zlim", "_current",
        "Jtor", "psi_axis", "psi_bndry", "psi_xpt", "psi_limit",
        "critical_points", "mask", "mask_func", "plasma_psi", "psi_func",
    )
    profile_state_names = ("L", "Beta0", "psi_axis", "psi_bndry")
    missing = object()

    def clone(value: object) -> object:
        if isinstance(value, np.ndarray):
            return value.copy()
        if isinstance(value, (tuple, list, dict)):
            return copy.deepcopy(value)
        return value

    def capture(owner: object, names: tuple[str, ...]) -> dict:
        return {name: (missing if not hasattr(owner, name) else clone(getattr(owner, name)))
                for name in names}

    def restore(owner: object, snapshot: dict) -> None:
        for name, value in snapshot.items():
            if value is missing:
                if hasattr(owner, name):
                    delattr(owner, name)
            else:
                setattr(owner, name, clone(value))

    baseline_eq = capture(eq, eq_state_names)
    baseline_profiles = capture(profiles, profile_state_names)
    initial_total_psi = np.asarray(eq.psi(), dtype=float).copy()
    if initial_total_psi.ndim != 2 or not np.all(np.isfinite(initial_total_psi)):
        raise RuntimeError("initial total psi is malformed")
    coil_psi = np.asarray(eq.tokamak.calcPsiFromGreens(eq._pgreen), dtype=float).copy()
    static_solver, static_machine, static_green = eq._solver, eq.tokamak, eq._pgreen
    original_eq_solve = eq.solve
    instance_solve = vars(eq).get("solve", missing)
    total_map_calls = 0
    anderson_evaluation_attempts = 0
    active_stage = None
    anderson_attempt_limit = maxits - 2

    def counted_eq_solve(*args, **kwargs):
        nonlocal total_map_calls
        if total_map_calls >= maxits:
            raise RuntimeError("fixed-current GS-map call budget exhausted")
        if active_stage not in ("anderson", "picard_verification"):
            raise RuntimeError(f"unclassified fixed-current GS-map stage: {active_stage!r}")
        total_map_calls += 1
        return original_eq_solve(*args, **kwargs)

    def reset_to_candidate(total_psi: object) -> object:
        if (eq._solver is not static_solver or eq.tokamak is not static_machine or
                eq._pgreen is not static_green):
            raise RuntimeError("fixed-current map mutated a static equilibrium operator or machine")
        restore(eq, baseline_eq)
        restore(profiles, baseline_profiles)
        if profiles.eq is not eq:
            raise RuntimeError("profile/equilibrium link changed during fixed-current reset")
        candidate_total = np.asarray(total_psi, dtype=float).reshape(initial_total_psi.shape).copy()
        if not np.all(np.isfinite(candidate_total)):
            raise ValueError("Anderson candidate psi contains non-finite values")
        eq._updatePlasmaPsi(candidate_total - coil_psi)
        if (eq.psi().shape != initial_total_psi.shape or not np.allclose(
                eq.psi(), candidate_total, rtol=0.0, atol=1.0e-14)):
            raise RuntimeError("FreeGS plasma-plus-fixed-coil reconstruction changed candidate psi")
        return candidate_total

    def residual_function(flat_psi: object) -> object:
        nonlocal active_stage, anderson_evaluation_attempts
        if anderson_evaluation_attempts >= anderson_attempt_limit:
            raise RuntimeError("fixed-current Anderson evaluation budget exhausted")
        anderson_evaluation_attempts += 1
        candidate_total = reset_to_candidate(flat_psi)
        active_stage = "anderson"
        try:
            eq.solve(profiles, psi=candidate_total, psi_bndry=None)
        finally:
            active_stage = None
        psi_out = np.asarray(eq.psi(), dtype=float)
        if not np.all(np.isfinite(psi_out)):
            raise RuntimeError("FreeGS GS map returned non-finite psi")
        return (psi_out - candidate_total).ravel().copy()

    eq.solve = counted_eq_solve
    try:
        # In SciPy's nonlin_solve call chain, Anderson.solve returns -alpha*F
        # and nonlin_solve negates it. For F=G(x)-x, alpha=1 gives x+dx=G(x).
        candidate_total = scipy.optimize.anderson(
            residual_function, initial_total_psi.ravel().copy(),
            maxiter=anderson_attempt_limit, alpha=1.0, M=5, w0=0.01,
            f_tol=6.0e-6, line_search="armijo",
        )
        candidate_total = reset_to_candidate(candidate_total)
        remaining = maxits - total_map_calls
        if remaining < 2:
            raise RuntimeError("less than two GS-map calls remain for original Picard verification")
        verification_maxits = remaining - 1  # FreeGS may make maxits + 1 map calls.
        active_stage = "picard_verification"
        try:
            result = freegs.solve(
                eq, profiles, None, rtol=rtol, atol=atol, blend=0.0,
                maxits=verification_maxits, convergenceInfo=True,
                check_limited=False, wait_for_limited=False, limit_it=0,
            )
        finally:
            active_stage = None
        if total_map_calls > maxits:
            raise RuntimeError("fixed-current GS-map call budget exceeded")
        return result
    finally:
        if instance_solve is missing:
            if hasattr(eq, "solve"):
                delattr(eq, "solve")
        else:
            eq.solve = instance_solve


def solve(wrapper: dict, environment: dict, freegs: object, np: object, scipy: object,
          output_path: Optional[Path] = None) -> dict:
    from scipy.constants import mu_0

    payload = wrapper["solver_input"]
    machine = payload["machine"]
    coil_current_mode = payload.get("coil_current_mode", "shape_controlled")
    coils = [
        (str(item["id"]), freegs.machine.Coil(float(item["major_radius_m"]),
            float(item["vertical_position_m"]),
            current=float(item["current_A_per_turn"]) if coil_current_mode == "fixed_current_forward" else 0.0))
        for item in machine["coils"]
    ]
    tokamak = freegs.machine.Machine(coils)
    domain = payload["domain"]
    profile = payload["profile"]
    critical_rule = profile.get("critical_point_refinement", "freegs_native_v1")
    equilibrium_kwargs = {}
    initial = payload.get("initial_plasma_psi_wb_per_rad")
    if initial is not None:
        equilibrium_kwargs["psi"] = np.asarray(initial, dtype=float)
    if critical_rule == "stationary_cubic_spline_gradient_hessian_v2":
        import inspect
        if "critical_point_provider" not in inspect.signature(
                freegs.Equilibrium).parameters:
            raise RuntimeError("stationary critical-point candidate requires the owned Equilibrium provider hook")
        equilibrium_kwargs["critical_point_provider"] = refine_stationary_critical_points
    eq = freegs.Equilibrium(
        tokamak=tokamak,
        Rmin=float(domain["r_min_m"]), Rmax=float(domain["r_max_m"]),
        Zmin=float(domain["z_min_m"]), Zmax=float(domain["z_max_m"]),
        nx=int(domain["nx"]), ny=int(domain["ny"]),
        boundary=freegs.boundary.freeBoundaryHagenow,
        **equilibrium_kwargs,
    )
    profiles = freegs.jtor.ConstrainPaxisIp(
        eq, float(profile["axis_pressure_pa"]), float(profile["plasma_current_a"]),
        float(profile["vacuum_f_tm"]), alpha_m=float(profile["alpha_m"]),
        alpha_n=float(profile["alpha_n"]), Raxis=float(profile["profile_axis_radius_m"]),
    )
    constraints = payload["constraints"]
    xpoints = [tuple(map(float, point)) for point in constraints["xpoints_m"]]
    isoflux = [tuple(map(float, item)) for item in constraints["isoflux_m"]]
    capture_control_result = bool(payload.get("capture_control_result", False))
    optimizer_results: list[dict] = []
    controller = None
    legacy_control_module = None
    legacy_optimize_module = None
    legacy_minimize = None
    legacy_capture_minimize = None
    legacy_optimize_proxy = None
    if coil_current_mode == "shape_controlled":
        controller_factory = freegs.control.constrain
        controller_kwargs = {"xpoints": xpoints, "isoflux": isoflux,
                             "gamma": float(constraints["gamma"])}
        if capture_control_result:
            import inspect

            def capture_result(result: object) -> None:
                success = bool(getattr(result, "success", False))
                objective = finite(getattr(result, "fun", float("nan")), "SLSQP objective")
                iterations = int(getattr(result, "nit", -1))
                if iterations < 0:
                    raise ValueError("SLSQP iteration count is invalid")
                control_rows = [(str(label), coil) for label, coil in tokamak.coils
                                if bool(coil.control)]
                declared_ids = tuple(str(item["id"]) for item in machine["coils"])
                if tuple(label for label, _ in control_rows) != declared_ids:
                    raise RuntimeError("bounded handback requires every declared coil to be controlled in declared order")
                changes = np.asarray(getattr(result, "x", None), dtype=float)
                before = np.asarray([float(coil.current) for _, coil in control_rows], dtype=float)
                if (changes.shape != before.shape or not np.all(np.isfinite(changes)) or
                        not np.all(np.isfinite(before))):
                    raise ValueError("SLSQP current vector is invalid for feasibility checking")
                candidate = before + changes
                if not np.all(np.isfinite(candidate)):
                    raise ValueError("SLSQP candidate coil currents are non-finite")
                bounds = constraints.get("current_lims_A_per_turn")
                if bounds is not None:
                    for index, (current, bound) in enumerate(zip(candidate, bounds)):
                        if not float(bound[0]) <= float(current) <= float(bound[1]):
                            raise RuntimeError(f"SLSQP candidate coil current {index} violates exact per-turn bounds")
                total_abs_current = math.fsum(abs(float(value)) for value in candidate)
                if not math.isfinite(total_abs_current):
                    raise ValueError("SLSQP sum of absolute controlled-coil currents is non-finite")
                total_limit = constraints.get("max_total_current_A")
                if total_limit is not None and total_abs_current > finite(
                        total_limit, "max_total_current_A"):
                    raise RuntimeError("SLSQP candidate exceeds the declared sum-absolute-current limit")
                record = {"success": success, "message": str(getattr(result, "message", "")),
                          "iterations": iterations, "objective": objective,
                          "candidate_currents_a_per_turn": {
                              label: float(candidate[index])
                              for index, (label, _) in enumerate(control_rows)}}
                if not success:
                    raise RuntimeError("SLSQP coil-control result was unsuccessful")
                optimizer_results.append(record)

            controller_parameters = inspect.signature(controller_factory).parameters
            if "result_callback" in controller_parameters:
                controller_kwargs["result_callback"] = capture_result
            else:
                # FreeGS 0.8.2 discards scipy.optimize.minimize's result after
                # assigning sol.x, so capture its SLSQP result at that boundary.
                if not {"current_lims", "max_total_current"}.issubset(controller_parameters):
                    raise RuntimeError("FreeGS provider has no supported SLSQP result-capture boundary")
                legacy_optimize_module = getattr(freegs.control, "optimize", None)
                legacy_minimize = getattr(legacy_optimize_module, "minimize", None)
                if not callable(legacy_minimize):
                    raise RuntimeError("FreeGS provider has no supported SLSQP result-capture boundary")

                def capture_legacy_minimize(*args: object, **kwargs: object) -> object:
                    result = legacy_minimize(*args, **kwargs)
                    if kwargs.get("method") == "SLSQP":
                        capture_result(result)
                    return result

                class _DelegatingOptimizeProxy:
                    def __init__(self, module: object, minimize: object) -> None:
                        self._module = module
                        self.minimize = minimize

                    def __getattr__(self, name: str) -> object:
                        return getattr(self._module, name)

                legacy_control_module = freegs.control
                legacy_capture_minimize = capture_legacy_minimize
                legacy_optimize_proxy = _DelegatingOptimizeProxy(
                    legacy_optimize_module, legacy_capture_minimize)
        if "current_lims_A_per_turn" in constraints:
            controller_kwargs["current_lims"] = constraints["current_lims_A_per_turn"]
        if "max_total_current_A" in constraints:
            controller_kwargs["max_total_current"] = constraints["max_total_current_A"]
        controller = controller_factory(**controller_kwargs)
    settings = payload["solver"]
    if legacy_control_module is not None:
        legacy_control_module.optimize = legacy_optimize_proxy
    try:
        with warnings.catch_warnings(record=True) as caught:
            warnings.simplefilter("always")
            if coil_current_mode == "fixed_current_forward":
                max_change, relative_change = _solve_fixed_current_with_anderson(
                    eq, profiles, freegs, np, scipy,
                    rtol=float(settings["rtol"]), atol=float(settings["atol"]),
                    maxits=int(settings["max_iterations"]),
                )
            else:
                max_change, relative_change = freegs.solve(
                    eq, profiles, controller, rtol=float(settings["rtol"]),
                    atol=float(settings["atol"]), maxits=int(settings["max_iterations"]),
                    convergenceInfo=True,
                )
    finally:
        if legacy_control_module is not None:
            legacy_control_module.optimize = legacy_optimize_module

    if getattr(eq, "critical_point_provider", None) is not None:
        # Bind final observables to the actual post-solve total-psi array,
        # never to a profile cache from the preceding Picard RHS evaluation.
        eq._updateBoundaryPsi(eq.psi())
    residual = independent_gs_residual(eq, np, mu_0)
    total_flux = np.asarray(eq.psi(), dtype=float)
    flux_span = float(np.ptp(total_flux))
    xpoint_fields = []
    for radius, vertical in xpoints:
        br = float(eq.Br(radius, vertical))
        bz = float(eq.Bz(radius, vertical))
        xpoint_fields.append({"r_m": radius, "z_m": vertical, "br_t": br,
                              "bz_t": bz, "bp_t": math.hypot(br, bz)})
    isoflux_residuals = []
    for r1, z1, r2, z2 in isoflux:
        absolute = abs(float(eq.psiRZ(r1, z1) - eq.psiRZ(r2, z2)))
        isoflux_residuals.append({"absolute_wb_per_rad": absolute,
                                  "relative_to_flux_span": absolute / max(flux_span, 1.0e-30)})
    field_samples = []
    for radius, vertical in payload.get("sample_points_rz_m", []):
        radius = float(radius)
        vertical = float(vertical)
        field_samples.append({
            "R_m": radius,
            "Z_m": vertical,
            "psi_wb_per_rad": finite(eq.psiRZ(radius, vertical), "sample psi_wb_per_rad"),
            "Br_T": finite(eq.Br(radius, vertical), "sample Br_T"),
            "Bz_T": finite(eq.Bz(radius, vertical), "sample Bz_T"),
        })
    if payload.get("sample_constitutive_fields", False):
        constitutive_rows = sample_constitutive_fields(
            eq, profiles, payload["sample_points_rz_m"], np)
        for row, constitutive_row in zip(field_samples, constitutive_rows):
            row["constitutive"] = constitutive_row
    if getattr(eq, "critical_point_provider", None) is not None:
        primary_o = eq.critical_points[0][0]
        axis_r, axis_z, axis_psi = map(float, primary_o)
    else:
        axis_r, axis_z, axis_psi = map(float, eq.magneticAxis())
    q_values = np.asarray(eq.q(np.asarray([0.01, 0.50, 0.95])), dtype=float)
    coil_currents_A_per_turn = {label: float(coil.current) for label, coil in tokamak.coils}
    if coil_current_mode == "fixed_current_forward":
        expected_fixed = {str(item["id"]): float(item["current_A_per_turn"])
                          for item in machine["coils"]}
        if coil_currents_A_per_turn != expected_fixed:
            raise RuntimeError("fixed-current forward changed an authored coil current")
        coil_control = {"mode": coil_current_mode, "status": "fixed_current_forward",
                        "optimizer_calls": [],
                        "coil_currents_a_per_turn": coil_currents_A_per_turn}
    elif capture_control_result:
        if not optimizer_results or not all(item["success"] for item in optimizer_results):
            raise RuntimeError("shape-controlled solve omitted a successful SLSQP result")
        coil_control = {"mode": coil_current_mode, "status": "slsqp_success",
                        "optimizer_calls": optimizer_results,
                        "coil_currents_a_per_turn": coil_currents_A_per_turn}
    result = {
        "schema": "fusionconceptai:runtime-v4-freegs-axisymmetric-output",
        "revision": RUNNER_REVISION,
        "status": "physical_model_screen",
        "context_hash": wrapper["context_hash"],
        "candidate_hash": wrapper["candidate_hash"],
        "compiled_prefix_hash": wrapper["compiled_prefix_hash"],
        "physical_subject_hash": wrapper["physical_subject_hash"],
        "scenario_hash": wrapper["scenario_hash"],
        "field_geometry_genome_hash": wrapper["field_geometry_genome_hash"],
        "field_geometry_graph_hash": wrapper["field_geometry_graph_hash"],
        "field_geometry_graph_binding_hash": wrapper["field_geometry_graph_binding_hash"],
        "binding_hash": wrapper["binding_hash"],
        "declaration_hash": wrapper["declaration_hash"],
        "semantic_input_hash": canonical_hash(wrapper),
        "environment": environment,
        "convergence": {
            "iterations": int(len(relative_change)),
            "final_relative_change": float(relative_change[-1]),
            "final_max_change": float(max_change[-1]),
            "requested_rtol": float(settings["rtol"]),
            "requested_atol": float(settings["atol"]),
            "max_iterations": int(settings["max_iterations"]),
        },
        "independent_residual": residual,
        "constraints": {
            "xpoint_field_residuals": xpoint_fields,
            "isoflux_residuals": isoflux_residuals,
        },
        "equilibrium": {
            "magnetic_axis_r_m": axis_r,
            "magnetic_axis_z_m": axis_z,
            "magnetic_axis_psi_wb_per_rad": axis_psi,
            "plasma_current_a": float(eq.plasmaCurrent()),
            "plasma_volume_m3": float(eq.plasmaVolume()),
            "minor_radius_m": float(eq.minorRadius()),
            "elongation": float(eq.elongation()),
            "q_95": float(q_values[2]),
            "beta_n": float(eq.betaN()),
        },
        "coil_currents_a": coil_currents_A_per_turn,
        "warnings": list(dict.fromkeys(str(item.message) for item in caught)),
        "claim_boundary": {
            "claim_ceiling": "screen_only",
            "physical_validation": False,
            "engineering_validation": False,
            "p5_ready": False,
            "terminal_authority": False,
            "description": "Candidate-bound FreeGS physical-model execution screen only.",
        },
    }
    if coil_current_mode == "fixed_current_forward" or capture_control_result:
        result["coil_control"] = coil_control
        result["coil_currents_a_per_turn"] = coil_currents_A_per_turn
    if field_samples:
        result["field_samples_rz_m"] = field_samples
    if "state_sample_time_s" in payload:
        result["state_sample_time_s"] = finite(payload["state_sample_time_s"], "state_sample_time_s")
    if payload.get("sample_lcfs_trace", False):
        result["lcfs_trace"] = sample_lcfs_trace(eq, profiles, np)
        # Keep actual last-solve eq.Jtor audit separate from the existing
        # lcfs_trace.current_support final-psi profile Jphi contract. The
        # accepted Julia current-field input remains unchanged until evidence
        # supports admitting both states.
        result["solver_jtor_diagnostic"] = sample_solver_jtor_diagnostic(
            eq, profiles, np)
        result["native_gs_state"] = sample_native_gs4_state(
            eq, result["solver_jtor_diagnostic"], np, result["lcfs_trace"],
            source_response_path=output_path)
    result["result_hash"] = canonical_hash(result)
    return result


def write_result(path: Path, result: dict) -> str:
    output_bytes = (json.dumps(result, indent=2, sort_keys=True, allow_nan=False) + "\n").encode("utf-8")
    path.write_bytes(output_bytes)
    return hashlib.sha256(output_bytes).hexdigest()


def emit_summary(result: dict, wrapper: dict, output_file_hash: str) -> None:
    metrics = [""] * 14
    if result["status"] == "physical_model_screen":
        convergence = result["convergence"]
        residual = result["independent_residual"]
        equilibrium = result["equilibrium"]
        constraints = result["constraints"]
        metrics = [
            str(convergence["iterations"]),
            repr(convergence["final_relative_change"]),
            repr(residual["plasma_l2_relative"]),
            repr(residual["plasma_linf_relative"]),
            repr(equilibrium["magnetic_axis_r_m"]),
            repr(equilibrium["magnetic_axis_z_m"]),
            repr(equilibrium["plasma_current_a"]),
            repr(equilibrium["plasma_volume_m3"]),
            repr(equilibrium["minor_radius_m"]),
            repr(equilibrium["elongation"]),
            repr(equilibrium["q_95"]),
            repr(equilibrium["beta_n"]),
            repr(max(item["bp_t"] for item in constraints["xpoint_field_residuals"])),
            repr(max(item["relative_to_flux_span"] for item in constraints["isoflux_residuals"])),
        ]
    fields = [
        SUMMARY_MARKER,
        result["status"],
        result.get("environment", {}).get("freegs_version", ""),
        result.get("environment", {}).get("environment_hash", ""),
        result.get("result_hash", ""),
        wrapper.get("context_hash", ""),
        wrapper.get("binding_hash", ""),
        result.get("semantic_input_hash", ""),
        *metrics,
        output_file_hash,
        result.get("gap_kind", "none"),
    ]
    print("\t".join(fields), flush=True)


def mastu_source_adapter_blocked_result(wrapper: dict) -> dict:
    """Validate this exact shot-45425 source extraction and stop before FreeGS.

    The Julia caller verifies the retained raw-member bytes against the static
    report receipt. This process validates and echoes that data-only provenance;
    it never resolves the reported raw path or transforms reconstructed values
    into physical point-coil or profile inputs.
    """
    adapter = wrapper.get("mastu_source_adapter")
    if not isinstance(adapter, dict) or adapter.get("schema") != \
            "fusionconceptai:mastu-static-source-adapter-v1":
        raise ValueError("unsupported MAST-U source adapter schema")
    if adapter.get("source_member_bytes") != 86_888_862:
        raise ValueError("MAST-U source member length differs from reviewed receipt")
    source_path = adapter.get("source_member_path")
    report_path = adapter.get("static_report_path")
    if (not isinstance(source_path, str) or not source_path.lower().endswith(
            "mast-u_shot_45425.pickle") or not isinstance(report_path, str) or not report_path):
        raise ValueError("MAST-U raw source/report paths are missing or for another member")
    source_digest = adapter.get("source_member_sha256")
    if not isinstance(source_digest, str) or len(source_digest) != 64 or any(
            char not in "0123456789abcdef" for char in source_digest):
        raise ValueError("MAST-U source-member data SHA-256 is malformed")
    if adapter.get("source_role") != \
            "EFIT++ reconstruction package; not independent observation":
        raise ValueError("MAST-U source role boundary is missing")
    extraction = adapter.get("index_134_extraction")
    if not isinstance(extraction, dict) or extraction.get("index") != 134:
        raise ValueError("MAST-U index-134 extraction is missing")
    if (extraction.get("reference_time_path") != "root.efit_times" or
            finite(extraction.get("reference_time_value"), "EFIT time") != 0.7):
        raise ValueError("MAST-U recorded index-134 EFIT time is not exact 0.7")
    joins = extraction.get("time_axis_joins")
    if (not isinstance(joins, list) or len(joins) != 5 or any(
            row.get("index") != 134 or row.get("time_value") != 0.7 or
            row.get("exact_match_to_efit_times") is not True for row in joins)):
        raise ValueError("MAST-U five index-134 EFIT time joins differ from the reviewed extraction")
    current_join = extraction.get("active_current_name_value_joins")
    if not isinstance(current_join, dict) or len(current_join.get("rows", [])) != 64:
        raise ValueError("MAST-U named current rows are incomplete")
    branches = extraction.get("pfcoil_branches")
    if (not isinstance(branches, list) or len(branches) != 25 or
            sum(int(row.get("count", -1)) for row in branches) != 1484):
        raise ValueError("MAST-U PF branch/geometry counts differ from the reviewed extraction")
    passive = extraction.get("passive_geometry_components")
    passive_joins = extraction.get("passive_geometry_current_name_joins")
    if (not isinstance(passive, list) or len(passive) != 45 or
            not isinstance(passive_joins, list) or len(passive_joins) != 201):
        raise ValueError("MAST-U passive geometry/current joins differ from the reviewed extraction")
    unmatched_passive = sum(
        row.get("matching_current_channel_count") != 1 for row in passive_joins)
    if unmatched_passive != 133:
        raise ValueError("MAST-U unresolved passive join count differs from the reviewed extraction")
    diagnostics = extraction.get("diagnostic_value_geometry_joins")
    if not isinstance(diagnostics, dict):
        raise ValueError("MAST-U sensor geometry joins are missing")
    expected_sensor_rows = {"pickups": 186, "fluxloops": 71}
    for name, count in expected_sensor_rows.items():
        records = diagnostics.get(name)
        if (not isinstance(records, dict) or len(records.get("rows", [])) != count or
                any(row.get("full_name_match_count") != 1 for row in records["rows"])):
            raise ValueError(f"MAST-U {name} value/geometry joins differ from the reviewed extraction")
    if len(extraction.get("time_major_arrays_at_index", [])) != 38:
        raise ValueError("MAST-U index-134 numerical array inventory differs from the reviewed extraction")

    extraction_digest = canonical_hash(extraction)
    missing = [
        {"field": "pf_geometry_units_and_branch_orientation", "status": "typed_absent"},
        {"field": "pf_channel_to_branch_signed_current_turn_mapping", "status": "typed_absent"},
        {"field": "current_A_vs_A_per_turn_semantics", "status": "typed_absent"},
        {"field": "passive_current_mapping_and_dynamic_response", "status": "typed_absent",
         "unmatched_or_ambiguous_rows": unmatched_passive},
        {"field": "ConstrainPaxisIp_axis_pressure_field_binding", "status": "typed_absent"},
        {"field": "ConstrainPaxisIp_vacuum_F_signed_branch_binding", "status": "typed_absent"},
        {"field": "sensor_calibration_and_independence", "status": "typed_absent",
         "source_role": "EFIT++-included constraints"},
        {"field": "sigma_units_and_statistical_semantics", "status": "typed_absent"},
        {"field": "heldout_observation_rows", "status": "typed_absent"},
    ]
    result = {
        "schema": "fusionconceptai:runtime-v4-freegs-axisymmetric-output",
        "revision": RUNNER_REVISION,
        "status": "recoverable_gap_unknown",
        "gap_kind": "source_adapter_blocked",
        "message": "Shot-45425 static source data reached the FreeGS consumer boundary; physical bindings are incomplete, so no solver was invoked.",
        "semantic_input_hash": canonical_hash(wrapper),
        "source_adapter": {
            "schema": adapter["schema"],
            "status": "typed_absent",
            "source_member_path": source_path,
            "source_member_bytes": adapter["source_member_bytes"],
            "source_member_sha256": source_digest,
            "static_report_path": report_path,
            "index": 134,
            "time_s": extraction["reference_time_value"],
            "extraction_data_sha256": extraction_digest,
            "input_counts": {"time_axis_joins": 5, "time_major_arrays_at_index": 38,
                             "named_currents": 64, "pf_branches": 25,
                             "pf_geometry_points": 1484, "passive_components": 45,
                             "passive_join_rows": 201,
                             "unmatched_or_ambiguous_passive_rows": unmatched_passive,
                             "pickup_rows": expected_sensor_rows["pickups"],
                             "fluxloop_rows": expected_sensor_rows["fluxloops"]},
            "missing_fields": missing,
            "solver_invoked": False,
            "source_role": "EFIT++ reconstruction package; not independent observation",
            "claim_ceiling": "screen_only",
            "physical_validation": False,
            "engineering_validation": False,
            "p5_ready": False,
            "terminal_authority": False,
        },
        "environment": {"freegs_version": "not_loaded", "environment_hash": ""},
        "claim_boundary": {"claim_ceiling": "screen_only",
                            "physical_validation": False,
                            "engineering_validation": False,
                            "p5_ready": False,
                            "terminal_authority": False},
    }
    result["result_hash"] = canonical_hash(result)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    input_path, output_path = Path(args.input), Path(args.output)
    raw_payload: object = {}
    wrapper: dict = {}
    try:
        raw_payload = json.loads(input_path.read_text(encoding="utf-8"))
        wrapper = validate_payload(raw_payload)
        if "mastu_source_adapter" in wrapper:
            result = mastu_source_adapter_blocked_result(wrapper)
        else:
            environment, freegs, np, scipy = environment_manifest()
            result = solve(wrapper, environment, freegs, np, scipy, output_path=output_path)
    except Exception as error:  # Recoverable by contract; no terminal unsupported.
        if isinstance(raw_payload, dict):
            wrapper = raw_payload
        environment = {
            "python_executable": str(Path(sys.executable).resolve()),
            "python_executable_sha256": file_hash(sys.executable),
            "python_version": platform.python_version(),
            "platform": platform.platform(),
            "dependency_error": type(error).__name__,
        }
        environment["environment_hash"] = canonical_hash(environment)
        result = {
            "schema": "fusionconceptai:runtime-v4-freegs-axisymmetric-output",
            "revision": RUNNER_REVISION,
            "status": "recoverable_gap_unknown",
            "gap_kind": "dependency_or_solver_gap",
            "message": str(error),
            "error_type": type(error).__name__,
            "traceback": traceback.format_exc(),
            "semantic_input_hash": canonical_hash(raw_payload),
            "environment": environment,
            "claim_boundary": {
                "claim_ceiling": "screen_only",
                "physical_validation": False,
                "engineering_validation": False,
                "p5_ready": False,
                "terminal_authority": False,
            },
        }
        diagnostic = getattr(error, "stationary_critical_point_diagnostic", None)
        if diagnostic is not None:
            diagnostic = dict(diagnostic)
            solver_input = wrapper.get("solver_input", {})
            diagnostic["execution"] = {
                "candidate_hash": wrapper.get("candidate_hash"),
                "context_hash": wrapper.get("context_hash"),
                "physical_subject_hash": wrapper.get("physical_subject_hash"),
                "scenario_hash": wrapper.get("scenario_hash"),
                "binding_hash": wrapper.get("binding_hash"),
                "coil_current_mode": solver_input.get("coil_current_mode", "shape_controlled"),
                "semantic_input_hash": canonical_hash(raw_payload),
            }
            result["stationary_critical_point_diagnostic"] = diagnostic
        result["result_hash"] = canonical_hash(result)
    output_file_hash = write_result(output_path, result)
    emit_summary(result, wrapper, output_file_hash)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
