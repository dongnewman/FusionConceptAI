#!/usr/bin/env python3
"""Generic tabulated-profile FreeGS runner with an observed Dirichlet boundary.

The runner has no device-name dispatch.  It consumes a verified generic source
snapshot plus a candidate/context wrapper, creates an explicit empty machine,
and solves the nonlinear Grad-Shafranov problem while holding the observed box
boundary fixed.  Solver convergence and the separately measured residuals are
reported independently; no residual acceptance threshold is defined.  This is
not an independent physical prediction.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import importlib.metadata
import json
import math
import platform
import sys
import traceback
import warnings
from pathlib import Path
from typing import Any, Mapping


REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v2"
INPUT_SCHEMA = "fusionconceptai:runtime-v4-freegs-axisymmetric-profile-input-v2"
SNAPSHOT_SCHEMA = "fusionconceptai:generic-axisymmetric-source-snapshot-v1"
OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-freegs-axisymmetric-profile-output-v2"
STATE_SCHEMA = "fusionconceptai:generic-axisymmetric-forward-state-v1"
SUMMARY_MARKER = "FUSION_FREEGS_PROFILE_V2"
PICARD_NONCONVERGENCE_MESSAGE = "Picard iteration failed to converge (too many iterations)"
FAILURE_EXIT_CODES = {
    "input_validation_failed": 2,
    "backend_unavailable": 3,
    "numerical_fail_nonconvergence": 4,
    "program_exception": 5,
}
SNAPSHOT_ARRAY_KEYS = {
    "r_m", "z_m", "psi_wb_per_rad", "psi_norm", "pressure_pa", "f_tm",
    "pprime_pa_rad_per_wb", "ffprime_t_rad", "lcfs_r_m", "lcfs_z_m",
    "fitted_input_currents_a",
}
CLAIM_CEILING = (
    "same-source observed-Dirichlet fixed-boundary solver-converged state and "
    "independently measured residuals only, with no residual acceptance threshold; "
    "no independent physical or engineering validation, "
    "likelihood, free-boundary prediction, formal inverse acceptance, B03, B07B, "
    "ITER measurement status, or parent UP4-03 completion"
)
SOURCE_CLAIM_CEILING = (
    "versioned MAST shot 30421 native source-field preparation for same-source "
    "conditional fixed-boundary solver execution only; independent validation, "
    "calibrated diagnostic response, likelihood, EOS/transport closure, verified "
    "coil geometry, free-boundary prediction, formal inverse acceptance, B03, B07B, "
    "ITER measurement status, and parent UP4-03 completion remain deferred"
)
COCOS_CONSUMED_SUBSET = {
    "source_interpretation": (
        "MAST efm is COCOS 3 in the official OMFIT MAST reader; this is an "
        "upstream software interpretation, not a shot-30421 metadata attestation"
    ),
    "consumed_subset": "psi,pprime,ffprime,Grad-Shafranov operator,and Br/Bz definitions only",
    "source_e_bp": 0,
    "source_sigma_bp": -1,
    "source_sigma_r_phi_z": 1,
    "source_psi_units": "Wb / rad",
    "source_pprime_units": "Pa-rad/Wb",
    "source_ffprime_units": "T-rad",
    "freegs_br_definition": "-dpsi_dz_over_r",
    "freegs_bz_definition": "dpsi_dr_over_r",
    "freegs_jtor_definition": "r_pprime_plus_ffprime_over_mu0_r",
    "freegs_rhs_definition": "minus_mu0_r_jtor",
    "mapping": "identity_no_sign_or_2pi_transform",
    "q_theta_status": "not_consumed_not_verified",
}


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def canonical_hash(value: object) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def file_hash(path: Path | str) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def require_exact(value: object, keys: set[str], label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    actual = set(value)
    if actual != keys:
        raise ValueError(
            f"{label} keys mismatch; missing={sorted(keys - actual)}, "
            f"extra={sorted(actual - keys)}")
    return value


def require_digest(value: object, label: str) -> str:
    if (not isinstance(value, str) or len(value) != 64
            or any(c not in "0123456789abcdef" for c in value)):
        raise ValueError(f"{label} must be a lowercase SHA-256 digest")
    return value


def finite(value: object, label: str) -> float:
    if isinstance(value, bool):
        raise ValueError(f"{label} cannot be boolean")
    result = float(value)
    if not math.isfinite(result):
        raise ValueError(f"{label} must be finite")
    return result


def _snapshot_body_without_payload_hash(snapshot: Mapping[str, Any]) -> dict[str, Any]:
    body = dict(snapshot)
    body.pop("snapshot_payload_sha256", None)
    return body


def _validate_array_entry(
    entry: object,
    *,
    name: str,
    dimensions: list[str],
    units: str,
    shape: tuple[int, ...],
    np: Any,
) -> Any:
    item = require_exact(entry, {"dimensions", "units", "shape", "dtype",
                                 "values_sha256", "values"}, f"array {name}")
    if item["dimensions"] != dimensions or item["units"] != units:
        raise ValueError(f"array {name} dimensions/units mismatch")
    if item["shape"] != list(shape) or item["dtype"] != "<f8":
        raise ValueError(f"array {name} shape/dtype mismatch")
    values = np.asarray(item["values"], dtype=np.dtype("<f8"))
    if tuple(values.shape) != shape or not bool(np.isfinite(values).all()):
        raise ValueError(f"array {name} values are nonfinite or misshaped")
    values = np.ascontiguousarray(values)
    if hashlib.sha256(values.tobytes(order="C")).hexdigest() != item["values_sha256"]:
        raise ValueError(f"array {name} values hash mismatch")
    return values


def validate_snapshot(snapshot: object, np: Any) -> tuple[dict[str, Any], dict[str, Any]]:
    required = {
        "schema", "adapter_version", "shot_id", "efm_time_index", "efm_time_s",
        "amc_alignment", "canonical_dimensions", "raw_to_canonical", "arrays",
        "scalars", "source_binding_sha256", "source_series_payload_sha256",
        "coil_geometry_status", "uncertainty_status", "likelihood_ready",
        "formal_acceptance", "claim_ceiling", "cocos_consumed_subset",
        "snapshot_payload_sha256",
    }
    value = require_exact(snapshot, required, "source snapshot")
    if value["schema"] != SNAPSHOT_SCHEMA or value["adapter_version"] != "native_axisymmetric_source_adapter_v2":
        raise ValueError("source snapshot schema/version mismatch")
    if value["canonical_dimensions"] != ["r", "z"]:
        raise ValueError("source snapshot dimensions must be [r,z]")
    if value["coil_geometry_status"] != "typed_absent_from_bound_source_protocol":
        raise ValueError("v2 source snapshot must preserve unbound coil geometry")
    if value["uncertainty_status"] != "typed_absent_for_source_field_likelihood":
        raise ValueError("source uncertainty status differs")
    if value["likelihood_ready"] is not False or value["formal_acceptance"] is not False:
        raise ValueError("source snapshot cannot be likelihood/formal ready")
    if value["claim_ceiling"] != SOURCE_CLAIM_CEILING:
        raise ValueError("source snapshot claim ceiling differs")
    if value["cocos_consumed_subset"] != COCOS_CONSUMED_SUBSET:
        raise ValueError("source snapshot COCOS consumed-subset contract differs")
    require_digest(value["source_binding_sha256"], "source_binding_sha256")
    require_digest(value["source_series_payload_sha256"], "source_series_payload_sha256")
    expected_payload = canonical_hash(_snapshot_body_without_payload_hash(value))
    if value["snapshot_payload_sha256"] != expected_payload:
        raise ValueError("source snapshot payload hash mismatch")
    arrays = require_exact(value["arrays"], SNAPSHOT_ARRAY_KEYS, "source arrays")
    parsed = {
        "r": _validate_array_entry(arrays["r_m"], name="r_m", dimensions=["r"],
                                    units="m", shape=(65,), np=np),
        "z": _validate_array_entry(arrays["z_m"], name="z_m", dimensions=["z"],
                                    units="m", shape=(65,), np=np),
        "psi": _validate_array_entry(arrays["psi_wb_per_rad"], name="psi_wb_per_rad",
                                      dimensions=["r", "z"], units="Wb / rad",
                                      shape=(65, 65), np=np),
        "psi_norm": _validate_array_entry(arrays["psi_norm"], name="psi_norm",
                                           dimensions=["psi_norm"], units="1",
                                           shape=(65,), np=np),
        "pressure": _validate_array_entry(arrays["pressure_pa"], name="pressure_pa",
                                           dimensions=["psi_norm"], units="Pa",
                                           shape=(65,), np=np),
        "fpol": _validate_array_entry(arrays["f_tm"], name="f_tm",
                                       dimensions=["psi_norm"], units="T-m",
                                       shape=(65,), np=np),
        "pprime": _validate_array_entry(
            arrays["pprime_pa_rad_per_wb"], name="pprime_pa_rad_per_wb",
            dimensions=["psi_norm"], units="Pa-rad/Wb", shape=(65,), np=np),
        "ffprime": _validate_array_entry(
            arrays["ffprime_t_rad"], name="ffprime_t_rad",
            dimensions=["psi_norm"], units="T-rad", shape=(65,), np=np),
    }
    lcfs_shape = tuple(arrays["lcfs_r_m"].get("shape", [])) if isinstance(arrays["lcfs_r_m"], dict) else ()
    if len(lcfs_shape) != 1 or lcfs_shape[0] < 3:
        raise ValueError("LCFS shape must contain at least three points")
    parsed["lcfs_r"] = _validate_array_entry(
        arrays["lcfs_r_m"], name="lcfs_r_m", dimensions=["lcfs_point"], units="m",
        shape=lcfs_shape, np=np)
    parsed["lcfs_z"] = _validate_array_entry(
        arrays["lcfs_z_m"], name="lcfs_z_m", dimensions=["lcfs_point"], units="m",
        shape=lcfs_shape, np=np)
    fitted_shape = tuple(arrays["fitted_input_currents_a"].get("shape", [])) if isinstance(arrays["fitted_input_currents_a"], dict) else ()
    if fitted_shape != (101,):
        raise ValueError("fitted input current shape mismatch")
    parsed["fitted_input_currents"] = _validate_array_entry(
        arrays["fitted_input_currents_a"], name="fitted_input_currents_a",
        dimensions=["fcoil_n"], units="A", shape=fitted_shape, np=np)
    if not bool(np.all(np.diff(parsed["r"]) > 0)) or not bool(np.all(np.diff(parsed["z"]) > 0)):
        raise ValueError("source coordinates must be strictly increasing")
    if not bool(np.all(np.diff(parsed["psi_norm"]) > 0)) or parsed["psi_norm"][0] != 0.0 or parsed["psi_norm"][-1] != 1.0:
        raise ValueError("psi_norm must increase exactly from zero to one")
    scalars = require_exact(value["scalars"], {
        "psi_axis_wb_per_rad", "psi_boundary_wb_per_rad", "magnetic_axis_m",
        "xpoints_m", "vacuum_f_tm", "plasma_current_a",
        "internal_pf_currents_a_turn",
    }, "source scalars")
    parsed["psi_axis"] = finite(scalars["psi_axis_wb_per_rad"], "psi axis")
    parsed["psi_boundary"] = finite(scalars["psi_boundary_wb_per_rad"], "psi boundary")
    if parsed["psi_axis"] == parsed["psi_boundary"]:
        raise ValueError("psi axis and boundary cannot coincide")
    parsed["fvac"] = finite(scalars["vacuum_f_tm"], "vacuum F")
    parsed["plasma_current"] = finite(scalars["plasma_current_a"], "plasma current")
    if parsed["fvac"] == 0.0:
        raise ValueError("vacuum F must be nonzero")
    alignment = require_exact(value["amc_alignment"], {
        "policy", "index", "time_s", "signed_delta_s", "caller_max_delta_s",
    }, "AMC alignment")
    if alignment["policy"] != "nearest_explicit_bound":
        raise ValueError("AMC alignment policy mismatch")
    if abs(finite(alignment["signed_delta_s"], "AMC delta")) > finite(alignment["caller_max_delta_s"], "AMC bound"):
        raise ValueError("AMC alignment exceeds caller bound")
    return value, parsed


def validate_wrapper(wrapper: object) -> dict[str, Any]:
    keys = {
        "schema", "revision", "context_hash", "candidate_hash", "compiled_prefix_hash",
        "physical_subject_hash", "scenario_hash", "field_geometry_genome_hash",
        "field_geometry_graph_hash", "field_geometry_graph_binding_hash", "binding_hash",
        "declaration_hash", "source_snapshot_file_sha256", "source_snapshot_payload_sha256",
        "controls",
    }
    value = require_exact(wrapper, keys, "wrapper")
    if value["schema"] != INPUT_SCHEMA or value["revision"] != REVISION:
        raise ValueError("profile runner schema/revision mismatch")
    for key in keys - {"schema", "revision", "controls"}:
        require_digest(value[key], key)
    controls = require_exact(value["controls"], {
        "mode", "rtol", "atol", "max_iterations", "blend", "coordinate_transform",
        "machine", "boundary", "cocos_mapping", "cocos_scope",
    }, "controls")
    if controls["mode"] != "source_and_observed_dirichlet_fixed_boundary":
        raise ValueError("unsupported execution mode")
    if controls["coordinate_transform"] != "linear_interp_source_r_to_uniform_solver_r":
        raise ValueError("unsupported coordinate transform")
    if controls["machine"] != "explicit_empty_machine" or controls["boundary"] != "observed_dirichlet_box_edges":
        raise ValueError("machine/boundary contract mismatch")
    if controls["cocos_mapping"] != "identity_no_sign_or_2pi_transform":
        raise ValueError("unsupported COCOS mapping")
    if controls["cocos_scope"] != "gs_bp_subset_only_q_theta_not_consumed":
        raise ValueError("unsupported COCOS scope")
    if not 0 < finite(controls["rtol"], "rtol") < 1:
        raise ValueError("rtol must lie in (0,1)")
    if not 0 < finite(controls["atol"], "atol") < 1:
        raise ValueError("atol must lie in (0,1)")
    if not isinstance(controls["max_iterations"], int) or isinstance(controls["max_iterations"], bool) or not 1 <= controls["max_iterations"] <= 1000:
        raise ValueError("max_iterations must be an integer within 1..1000")
    if not 0 <= finite(controls["blend"], "blend") < 1:
        raise ValueError("blend must lie in [0,1)")
    return value


def environment_manifest() -> tuple[dict[str, Any], Any, Any, Any]:
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
    if manifest["freegs_version"] != "0.8.2":
        raise RuntimeError(f"expected pinned FreeGS 0.8.2, got {manifest['freegs_version']}")
    manifest["environment_hash"] = canonical_hash(manifest)
    return manifest, freegs, np, scipy


def _array_payload(values: Any, dimensions: list[str], units: str, np: Any) -> dict[str, Any]:
    array = np.ascontiguousarray(values, dtype=np.dtype("<f8"))
    if not bool(np.isfinite(array).all()):
        raise RuntimeError("forward state contains nonfinite values")
    return {
        "dimensions": dimensions, "units": units, "shape": list(array.shape),
        "dtype": "<f8", "values_sha256": hashlib.sha256(array.tobytes(order="C")).hexdigest(),
        "values": array.tolist(),
    }


def independent_gs_residual(r: Any, z: Any, psi: Any, jtor: Any, mu_0: float, np: Any) -> dict[str, float]:
    dr = float(r[1] - r[0])
    dz = float(z[1] - z[0])
    radius = r[:, None]
    center = psi[1:-1, 1:-1]
    operator = (
        (psi[2:, 1:-1] - 2.0 * center + psi[:-2, 1:-1]) / dr**2
        - (psi[2:, 1:-1] - psi[:-2, 1:-1]) / (2.0 * dr * radius[1:-1])
        + (psi[1:-1, 2:] - 2.0 * center + psi[1:-1, :-2]) / dz**2
    )
    rhs = -mu_0 * radius[1:-1] * jtor[1:-1, 1:-1]
    residual = operator - rhs
    mask = np.abs(rhs) > max(1.0e-30, 1.0e-12 * float(np.max(np.abs(rhs))))
    if not bool(np.any(mask)):
        raise RuntimeError("Grad-Shafranov residual has no plasma support")
    return {
        "plasma_l2_relative": float(np.linalg.norm(residual[mask]) / max(np.linalg.norm(rhs[mask]), 1.0e-30)),
        "plasma_linf_relative": float(np.max(np.abs(residual[mask])) / max(np.max(np.abs(rhs[mask])), 1.0e-30)),
        "plasma_rms_absolute": float(np.sqrt(np.mean(residual[mask] ** 2))),
    }


def make_forward_state(kind: str, role: str, r: Any, z: Any, psi: Any, jtor: Any,
                       residual: Mapping[str, float], source_snapshot_hash: str,
                       boundary_hash: str, np: Any) -> dict[str, Any]:
    state = {
        "schema": STATE_SCHEMA,
        "kind": kind,
        "role": role,
        "dimensions": ["r", "z"],
        "r_m": _array_payload(r, ["r"], "m", np),
        "z_m": _array_payload(z, ["z"], "m", np),
        "psi_wb_per_rad": _array_payload(psi, ["r", "z"], "Wb / rad", np),
        "jtor_a_per_m2": _array_payload(jtor, ["r", "z"], "A / m ** 2", np),
        "independent_gs_residual": dict(residual),
        "residual_measurement_status": "measured_no_acceptance_threshold",
        "pde_acceptance": False,
        "source_snapshot_payload_sha256": source_snapshot_hash,
        "observed_dirichlet_boundary_sha256": boundary_hash,
        "cocos_consumed_subset": COCOS_CONSUMED_SUBSET,
        "independent_measurement": False,
        "likelihood_ready": False,
        "claim_ceiling": CLAIM_CEILING,
    }
    state["state_sha256"] = canonical_hash(state)
    validate_forward_state(state)
    return state


def validate_forward_state(state: object) -> str:
    keys = {
        "schema", "kind", "role", "dimensions", "r_m", "z_m", "psi_wb_per_rad",
        "jtor_a_per_m2", "independent_gs_residual", "source_snapshot_payload_sha256",
        "observed_dirichlet_boundary_sha256", "cocos_consumed_subset",
        "residual_measurement_status", "pde_acceptance", "independent_measurement",
        "likelihood_ready", "claim_ceiling", "state_sha256",
    }
    value = require_exact(state, keys, "forward state")
    if value["schema"] != STATE_SCHEMA or value["dimensions"] != ["r", "z"]:
        raise ValueError("forward state schema/dimensions mismatch")
    if value["role"] not in ("same_source_reference_reconstruction", "conditional_fixed_boundary_solution"):
        raise ValueError("forward state role is unsupported")
    if value["independent_measurement"] is not False or value["likelihood_ready"] is not False:
        raise ValueError("forward state cannot claim independence or likelihood readiness")
    if (value["residual_measurement_status"] != "measured_no_acceptance_threshold"
            or value["pde_acceptance"] is not False):
        raise ValueError("forward state residual acceptance metadata differs")
    if value["claim_ceiling"] != CLAIM_CEILING:
        raise ValueError("forward state claim ceiling differs")
    if value["cocos_consumed_subset"] != COCOS_CONSUMED_SUBSET:
        raise ValueError("forward state COCOS contract differs")
    require_digest(value["source_snapshot_payload_sha256"], "state source hash")
    require_digest(value["observed_dirichlet_boundary_sha256"], "state boundary hash")
    expected = canonical_hash({k: v for k, v in value.items() if k != "state_sha256"})
    if value["state_sha256"] != expected:
        raise ValueError("forward state hash mismatch")
    return expected


def _trace_float64_payload(values: Any, np: Any) -> dict[str, Any]:
    """Preserve an observed array without requiring it to be finite.

    This is deliberately separate from ``_array_payload``.  A failed numerical
    solve must retain non-finite values if they occur, while accepted forward
    states continue to require finite arrays.  Values are encoded as canonical
    little-endian float64 C-order bytes so the recorded hash and base64 payload
    describe the same bytes.
    """
    source = np.asarray(values)
    array = np.ascontiguousarray(source, dtype=np.dtype("<f8"))
    raw = array.tobytes(order="C")
    finite_mask = np.isfinite(array)
    finite_values = array[finite_mask]
    return {
        "shape": list(array.shape),
        "source_dtype": str(source.dtype),
        "encoding_dtype": "<f8",
        "encoding": "base64_raw_c_order",
        "values_sha256": hashlib.sha256(raw).hexdigest(),
        "values_base64": base64.b64encode(raw).decode("ascii"),
        "finite_count": int(finite_mask.sum()),
        "total_count": int(array.size),
        "finite_minimum": (
            float(np.min(finite_values)) if finite_values.size else None),
        "finite_maximum": (
            float(np.max(finite_values)) if finite_values.size else None),
    }


def _trace_bool_payload(values: Any, np: Any) -> dict[str, Any]:
    source = np.ascontiguousarray(np.asarray(values))
    source_raw = source.tobytes(order="C")
    array = np.ascontiguousarray(source, dtype=np.bool_)
    raw = array.tobytes(order="C")
    return {
        "shape": list(array.shape),
        "source_dtype": str(source.dtype),
        "source_encoding_dtype": source.dtype.str,
        "source_encoding": "base64_raw_c_order",
        "source_values_sha256": hashlib.sha256(source_raw).hexdigest(),
        "source_values_base64": base64.b64encode(source_raw).decode("ascii"),
        "encoding_dtype": "|b1",
        "encoding": "base64_raw_c_order",
        "values_sha256": hashlib.sha256(raw).hexdigest(),
        "values_base64": base64.b64encode(raw).decode("ascii"),
        "true_count": int(array.sum()),
        "total_count": int(array.size),
    }


def _trace_scalar(value: Any) -> dict[str, Any]:
    if value is None:
        return {"status": "typed_absent", "value": None}
    try:
        result = float(value)
    except (TypeError, ValueError, OverflowError) as exc:
        return {
            "status": "not_convertible_to_float",
            "value": None,
            "source_type": type(value).__name__,
            "error": f"{type(exc).__name__}: {exc}",
        }
    if not math.isfinite(result):
        return {
            "status": "nonfinite_observed",
            "value": None,
            "source_type": type(value).__name__,
            "nonfinite_repr": repr(result),
        }
    return {
        "status": "finite_observed",
        "value": result,
        "source_type": type(value).__name__,
    }


def _trace_critical_points(points: Any, np: Any) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for point in points:
        values = np.asarray(point).reshape(-1)
        result.append({
            "values": _trace_float64_payload(values, np),
            "readable_values": [
                float(value) if math.isfinite(float(value)) else None
                for value in values
            ],
        })
    return result


def _trace_boundary_drift(
    psi: Any, boundary_edges: Mapping[str, Any], np: Any,
) -> dict[str, Any]:
    array = np.asarray(psi, dtype=float)
    actual = {
        "r_min": array[0, :],
        "r_max": array[-1, :],
        "z_min": array[:, 0],
        "z_max": array[:, -1],
    }
    result: dict[str, Any] = {}
    for name, observed in actual.items():
        expected = np.asarray(boundary_edges[name], dtype=float)
        delta = np.asarray(observed, dtype=float) - expected
        maximum = np.max(np.abs(delta))
        result[name] = {
            "observed_values_sha256": hashlib.sha256(
                np.ascontiguousarray(observed, dtype="<f8").tobytes(order="C")
            ).hexdigest(),
            "expected_values_sha256": hashlib.sha256(
                np.ascontiguousarray(expected, dtype="<f8").tobytes(order="C")
            ).hexdigest(),
            "bit_exact": bool(np.array_equal(observed, expected)),
            "max_abs_drift_wb_per_rad": _trace_scalar(maximum),
        }
    return result


class EquilibriumSolveObserver:
    """Observe the exact bound ``Equilibrium.solve`` calls used by Picard.

    The observer wraps only the already-created equilibrium and profile
    instances.  Every wrapper calls its original exactly once and returns the
    original object unchanged.  The two critical helpers are temporarily
    wrapped only to retain the O/X-point and core-mask values actually used by
    the pinned FreeGS implementation; both helpers and both instance methods
    are restored in ``__exit__`` even when the numerical solve raises.
    """

    def __init__(
        self, *, eq: Any, profiles: Any, critical_module: Any,
        boundary_edges: Mapping[str, Any], mu_0: float, np: Any,
    ) -> None:
        self.eq = eq
        self.profiles = profiles
        self.critical_module = critical_module
        self.boundary_edges = boundary_edges
        self.mu_0 = float(mu_0)
        self.np = np
        self.calls: list[dict[str, Any]] = []
        self._active_call: dict[str, Any] | None = None
        self._profile_jtor_depth = 0
        self._eq_had_instance_solve = "solve" in getattr(eq, "__dict__", {})
        self._profile_had_instance_jtor = "Jtor" in getattr(
            profiles, "__dict__", {})
        self._eq_instance_solve = getattr(eq, "__dict__", {}).get("solve")
        self._profile_instance_jtor = getattr(
            profiles, "__dict__", {}).get("Jtor")
        self._original_eq_solve = eq.solve
        self._original_profile_jtor = profiles.Jtor
        self._original_find_critical = critical_module.find_critical
        self._original_core_mask = critical_module.core_mask
        self._installed = False

    def _scope(self) -> str:
        return "profile_jtor" if self._profile_jtor_depth else "equilibrium_boundary_update"

    def _record_observation_error(self, where: str, exc: BaseException) -> None:
        if self._active_call is not None:
            self._active_call.setdefault("observation_errors", []).append({
                "where": where,
                "exception_type": type(exc).__name__,
                "message": str(exc),
            })

    def _find_critical(self, *args: Any, **kwargs: Any) -> Any:
        result = self._original_find_critical(*args, **kwargs)
        try:
            if self._active_call is not None:
                psi = kwargs.get("psi", args[2] if len(args) > 2 else None)
                opt, xpt = result
                self._active_call["critical_calls"].append({
                    "call_index": len(self._active_call["critical_calls"]) + 1,
                    "scope": self._scope(),
                    "input_psi_sha256": (
                        _trace_float64_payload(psi, self.np)["values_sha256"]
                        if psi is not None else None),
                    "o_points": _trace_critical_points(opt, self.np),
                    "x_points": _trace_critical_points(xpt, self.np),
                })
        except BaseException as exc:  # observation must not alter solver behavior
            self._record_observation_error("find_critical", exc)
        return result

    def _core_mask(self, *args: Any, **kwargs: Any) -> Any:
        result = self._original_core_mask(*args, **kwargs)
        try:
            if self._active_call is not None:
                psi = kwargs.get("psi", args[2] if len(args) > 2 else None)
                psi_bndry = kwargs.get(
                    "psi_bndry", args[5] if len(args) > 5 else None)
                self._active_call["core_mask_calls"].append({
                    "call_index": len(self._active_call["core_mask_calls"]) + 1,
                    "scope": self._scope(),
                    "input_psi_sha256": (
                        _trace_float64_payload(psi, self.np)["values_sha256"]
                        if psi is not None else None),
                    "supplied_psi_boundary": _trace_scalar(psi_bndry),
                    "returned_mask": _trace_bool_payload(result, self.np),
                })
        except BaseException as exc:  # observation must not alter solver behavior
            self._record_observation_error("core_mask", exc)
        return result

    def _profile_jtor(self, *args: Any, **kwargs: Any) -> Any:
        record: dict[str, Any] = {
            "call_index": 0,
            "call_completed": False,
        }
        if self._active_call is not None:
            record["call_index"] = len(self._active_call["profile_jtor_calls"]) + 1
            self._active_call["profile_jtor_calls"].append(record)
        mask_start = (
            len(self._active_call["core_mask_calls"])
            if self._active_call is not None else 0)
        critical_start = (
            len(self._active_call["critical_calls"])
            if self._active_call is not None else 0)
        psi = kwargs.get("psi", args[2] if len(args) > 2 else None)
        psi_bndry = kwargs.get(
            "psi_bndry", args[3] if len(args) > 3 else None)
        try:
            if psi is not None:
                record["input_psi"] = _trace_float64_payload(psi, self.np)
            record["supplied_psi_boundary"] = _trace_scalar(psi_bndry)
        except BaseException as exc:
            self._record_observation_error("profile_jtor_before", exc)
        self._profile_jtor_depth += 1
        try:
            result = self._original_profile_jtor(*args, **kwargs)
        except BaseException as exc:
            record["exception"] = {
                "exception_type": type(exc).__name__, "message": str(exc)}
            raise
        finally:
            self._profile_jtor_depth -= 1
        record["call_completed"] = True
        try:
            returned = self.np.asarray(result, dtype=float)
            record["returned_jtor"] = _trace_float64_payload(returned, self.np)
            record["profile_psi_axis"] = _trace_scalar(
                getattr(self.profiles, "psi_axis", None))
            record["profile_psi_boundary"] = _trace_scalar(
                getattr(self.profiles, "psi_bndry", None))
            axis = float(self.profiles.psi_axis)
            boundary = float(self.profiles.psi_bndry)
            normalized = self.np.clip(
                (self.np.asarray(psi, dtype=float) - axis) / (boundary - axis),
                0.0, 1.0)
            pprime = self.profiles.pprime(normalized)
            ffprime = self.profiles.ffprime(normalized)
            radius = self.np.asarray(args[0], dtype=float)
            unmasked = radius * pprime + ffprime / (radius * self.mu_0)
            record["normalized_psi"] = _trace_float64_payload(normalized, self.np)
            record["pprime_pa_rad_per_wb"] = _trace_float64_payload(
                pprime, self.np)
            record["ffprime_t_rad"] = _trace_float64_payload(ffprime, self.np)
            record["unmasked_jtor_a_per_m2"] = _trace_float64_payload(
                unmasked, self.np)
            profile_masks = [
                item for item in self._active_call["core_mask_calls"][mask_start:]
                if item["scope"] == "profile_jtor"
            ] if self._active_call is not None else []
            profile_critical = [
                item for item in self._active_call["critical_calls"][critical_start:]
                if item["scope"] == "profile_jtor"
            ] if self._active_call is not None else []
            if profile_masks:
                mask_payload = profile_masks[-1]["returned_mask"]
                mask_raw = base64.b64decode(mask_payload["values_base64"])
                mask = self.np.frombuffer(mask_raw, dtype=self.np.bool_).reshape(
                    mask_payload["shape"])
                reconstructed = unmasked * mask
            else:
                reconstructed = unmasked
            delta = returned - reconstructed
            record["jtor_reconstruction"] = {
                "profile_function_evaluation_status": (
                    "recomputed_after_actual_call_with_same_bound_tabulated_functions"),
                "actual_critical_call_indices": [
                    item["call_index"] for item in profile_critical],
                "actual_core_mask_call_indices": [
                    item["call_index"] for item in profile_masks],
                "mask_source": (
                    "actual_intercepted_profile_core_mask_return"
                    if profile_masks else "typed_absent_no_profile_core_mask_call"),
                "bit_exact": bool(self.np.array_equal(returned, reconstructed)),
                "max_abs_delta_a_per_m2": _trace_scalar(
                    self.np.max(self.np.abs(delta))),
                "reconstructed_values_sha256": hashlib.sha256(
                    self.np.ascontiguousarray(
                        reconstructed, dtype="<f8").tobytes(order="C")
                ).hexdigest(),
            }
        except BaseException as exc:  # retain original Jtor result unchanged
            self._record_observation_error("profile_jtor_after", exc)
        return result

    def _eq_solve(self, *args: Any, **kwargs: Any) -> Any:
        call: dict[str, Any] = {
            "eq_solve_call_index": len(self.calls) + 1,
            "call_completed": False,
            "critical_calls": [],
            "core_mask_calls": [],
            "profile_jtor_calls": [],
            "observation_errors": [],
        }
        self._active_call = call
        input_psi = kwargs.get("psi", args[2] if len(args) > 2 else None)
        supplied_jtor = kwargs.get("Jtor", args[1] if len(args) > 1 else None)
        supplied_boundary = kwargs.get(
            "psi_bndry", args[3] if len(args) > 3 else None)
        try:
            if input_psi is not None:
                call["input_psi"] = _trace_float64_payload(input_psi, self.np)
            call["supplied_jtor_status"] = (
                "typed_absent_profiles_evaluated" if supplied_jtor is None
                else "present_explicit")
            if supplied_jtor is not None:
                call["supplied_jtor"] = _trace_float64_payload(
                    supplied_jtor, self.np)
            call["supplied_psi_boundary"] = _trace_scalar(supplied_boundary)
            call["eq_psi_before"] = _trace_float64_payload(
                self.eq.psi(), self.np)
            call["eq_psi_axis_before"] = _trace_scalar(
                getattr(self.eq, "psi_axis", None))
            call["eq_psi_boundary_before"] = _trace_scalar(
                getattr(self.eq, "psi_bndry", None))
        except BaseException as exc:
            self._record_observation_error("eq_solve_before", exc)
        try:
            result = self._original_eq_solve(*args, **kwargs)
        except BaseException as exc:
            call["exception"] = {
                "exception_type": type(exc).__name__, "message": str(exc)}
            try:
                self._finalize_call(call, input_psi)
            except BaseException as observe_exc:
                self._record_observation_error("eq_solve_exception_finalize", observe_exc)
            self.calls.append(call)
            self._active_call = None
            raise
        call["call_completed"] = True
        try:
            self._finalize_call(call, input_psi)
        except BaseException as exc:
            self._record_observation_error("eq_solve_after", exc)
        self.calls.append(call)
        self._active_call = None
        return result

    def _finalize_call(self, call: dict[str, Any], input_psi: Any) -> None:
        output = self.np.asarray(self.eq.psi(), dtype=float)
        call["output_psi"] = _trace_float64_payload(output, self.np)
        if input_psi is not None:
            previous = self.np.asarray(input_psi, dtype=float)
            change = previous - output
            span = float(self.np.max(output) - self.np.min(output))
            call["picard_change"] = {
                "max_abs_wb_per_rad": _trace_scalar(
                    self.np.max(self.np.abs(change))),
                "relative_to_output_span": _trace_scalar(
                    self.np.max(self.np.abs(change)) / span
                    if span != 0.0 else None),
                "output_span_wb_per_rad": _trace_scalar(span),
            }
        call["observed_boundary_drift"] = _trace_boundary_drift(
            output, self.boundary_edges, self.np)
        call["eq_psi_axis_after"] = _trace_scalar(
            getattr(self.eq, "psi_axis", None))
        call["eq_psi_boundary_after"] = _trace_scalar(
            getattr(self.eq, "psi_bndry", None))
        eq_jtor = getattr(self.eq, "Jtor", None)
        if eq_jtor is not None:
            call["eq_jtor_after"] = _trace_float64_payload(eq_jtor, self.np)
            completed_profiles = [
                item for item in call["profile_jtor_calls"]
                if item.get("call_completed") and "returned_jtor" in item]
            call["eq_jtor_matches_last_profile_return"] = bool(
                completed_profiles
                and call["eq_jtor_after"]["values_sha256"] ==
                completed_profiles[-1]["returned_jtor"]["values_sha256"])
        eq_mask = getattr(self.eq, "mask", None)
        call["eq_mask_after"] = (
            _trace_bool_payload(eq_mask, self.np) if eq_mask is not None
            else {"status": "typed_absent"})

    def __enter__(self) -> "EquilibriumSolveObserver":
        if self._installed:
            raise RuntimeError("equilibrium solve observer already installed")
        self.eq.solve = self._eq_solve
        self.profiles.Jtor = self._profile_jtor
        self.critical_module.find_critical = self._find_critical
        self.critical_module.core_mask = self._core_mask
        self._installed = True
        return self

    def __exit__(self, exc_type: Any, exc: Any, tb: Any) -> bool:
        if self._eq_had_instance_solve:
            self.eq.solve = self._eq_instance_solve
        else:
            del self.eq.solve
        if self._profile_had_instance_jtor:
            self.profiles.Jtor = self._profile_instance_jtor
        else:
            del self.profiles.Jtor
        self.critical_module.find_critical = self._original_find_critical
        self.critical_module.core_mask = self._original_core_mask
        self._installed = False
        return False

    def report(self, *, formal_solve_returned: bool) -> dict[str, Any]:
        return {
            "schema": "fusionconceptai:freegs-equilibrium-solve-observation-v1",
            "observer_scope": "actual_bound_equilibrium_solve_calls_inside_pinned_freegs_solve",
            "formal_freegs_solve_returned": bool(formal_solve_returned),
            "actual_eq_solve_call_count": len(self.calls),
            "iteration_count_claimed": False,
            "call_index_semantics": (
                "actual Equilibrium.solve invocation order; not an inferred Picard iteration count"),
            "original_callables_restored": not self._installed,
            "model_or_solver_parameter_changed": False,
            "calls": self.calls,
        }


def frozen_source_jtor_linear_diagnostic(
    *, freegs: Any, profiles: Any, source: Mapping[str, Any],
    solver_r: Any, solver_z: Any, source_psi_solver: Any, source_jtor: Any,
    observed_dirichlet_boundary: Any, boundary_edges: Mapping[str, Any],
    mu_0: float, np: Any,
) -> dict[str, Any]:
    """Run one separate linear solve with source Jtor held fixed.

    This diagnostic equilibrium never becomes the formal nonlinear equilibrium.
    Failure is retained in the diagnostic record and does not suppress the
    unchanged formal ``freegs.solve`` call.
    """
    record: dict[str, Any] = {
        "schema": "fusionconceptai:freegs-frozen-source-jtor-linear-diagnostic-v1",
        "status": "test_only_attempted",
        "formal_solve_replacement": False,
        "changes_to_formal_equilibrium": False,
        "source_psi": _trace_float64_payload(source_psi_solver, np),
        "frozen_source_jtor": _trace_float64_payload(source_jtor, np),
        "supplied_psi_boundary": _trace_scalar(source["psi_boundary"]),
        "residual_acceptance_threshold": "typed_absent_not_defined",
        "pde_acceptance": False,
        "independent_measurement": False,
    }
    try:
        diagnostic_eq = freegs.Equilibrium(
            tokamak=freegs.machine.Machine([]),
            Rmin=float(solver_r[0]), Rmax=float(solver_r[-1]),
            Zmin=float(solver_z[0]), Zmax=float(solver_z[-1]),
            nx=int(solver_r.size), ny=int(solver_z.size),
            boundary=observed_dirichlet_boundary,
            psi=np.asarray(source_psi_solver, dtype=float).copy(),
            current=source["plasma_current"], order=4, check_limited=False,
        )
        diagnostic_eq.solve(
            profiles,
            Jtor=np.asarray(source_jtor, dtype=float).copy(),
            psi=np.asarray(source_psi_solver, dtype=float).copy(),
            psi_bndry=source["psi_boundary"],
        )
        output = np.asarray(diagnostic_eq.psi(), dtype=float)
        record.update({
            "status": "test_only_completed",
            "output_psi": _trace_float64_payload(output, np),
            "output_jtor": _trace_float64_payload(diagnostic_eq.Jtor, np),
            "output_eq_psi_axis": _trace_scalar(
                getattr(diagnostic_eq, "psi_axis", None)),
            "output_eq_psi_boundary": _trace_scalar(
                getattr(diagnostic_eq, "psi_bndry", None)),
            "output_eq_mask": (
                _trace_bool_payload(diagnostic_eq.mask, np)
                if getattr(diagnostic_eq, "mask", None) is not None
                else {"status": "typed_absent"}),
            "observed_boundary_drift": _trace_boundary_drift(
                output, boundary_edges, np),
            "independent_gs_residual": independent_gs_residual(
                solver_r, solver_z, output, source_jtor, mu_0, np),
        })
    except BaseException as exc:
        record.update({
            "status": "test_only_program_exception",
            "exception_type": type(exc).__name__,
            "message": str(exc),
            "traceback": traceback.format_exc(),
        })
    record["diagnostic_sha256"] = canonical_hash(record)
    return record


def solve(wrapper: dict[str, Any], snapshot: dict[str, Any], source: dict[str, Any],
          environment: dict[str, Any], freegs: Any, np: Any, scipy: Any,
          input_file_sha256: str, execution_state: dict[str, Any]) -> dict[str, Any]:
    from scipy.constants import mu_0

    execution_state["phase"] = "numerical_setup"
    controls = wrapper["controls"]
    source_r, source_z, source_psi = source["r"], source["z"], source["psi"]
    solver_r = np.linspace(float(source_r[0]), float(source_r[-1]), source_r.size)
    solver_z = np.linspace(float(source_z[0]), float(source_z[-1]), source_z.size)
    if not np.array_equal(source_z, solver_z):
        raise RuntimeError("v2 only supports an exact uniform source z grid")
    source_psi_solver = np.empty_like(source_psi, dtype=float)
    for z_index in range(source_z.size):
        source_psi_solver[:, z_index] = np.interp(solver_r, source_r, source_psi[:, z_index])
    transform = {
        "kind": controls["coordinate_transform"],
        "source_r_sha256": hashlib.sha256(np.ascontiguousarray(source_r, dtype="<f8").tobytes()).hexdigest(),
        "solver_r_sha256": hashlib.sha256(np.ascontiguousarray(solver_r, dtype="<f8").tobytes()).hexdigest(),
        "max_abs_r_displacement_m": float(np.max(np.abs(source_r - solver_r))),
        "source_z_equals_solver_z": True,
        "adapter_resampling": "none",
        "solver_boundary_interpolation": "linear_in_r_explicitly_recorded",
    }
    profile_grid = source["psi_norm"]

    def table(values: Any):
        return lambda normalized: np.interp(normalized, profile_grid, values)

    profiles = freegs.jtor.ProfilesPprimeFfprime(
        table(source["pprime"]), table(source["ffprime"]), source["fvac"],
        p_func=table(source["pressure"]), f_func=table(source["fpol"]),
    )
    boundary_edges = {
        "r_min": source_psi_solver[0, :].copy(),
        "r_max": source_psi_solver[-1, :].copy(),
        "z_min": source_psi_solver[:, 0].copy(),
        "z_max": source_psi_solver[:, -1].copy(),
    }
    boundary_hash = canonical_hash({k: np.asarray(v, dtype=float).tolist()
                                    for k, v in boundary_edges.items()})

    def observed_dirichlet_boundary(_eq: Any, _jtor: Any, psi: Any) -> None:
        psi[0, :] = boundary_edges["r_min"]
        psi[-1, :] = boundary_edges["r_max"]
        psi[:, 0] = boundary_edges["z_min"]
        psi[:, -1] = boundary_edges["z_max"]

    machine = freegs.machine.Machine([])
    if machine.coils != []:
        raise RuntimeError("explicit empty machine construction failed")
    eq = freegs.Equilibrium(
        tokamak=machine, Rmin=float(solver_r[0]), Rmax=float(solver_r[-1]),
        Zmin=float(solver_z[0]), Zmax=float(solver_z[-1]),
        nx=int(solver_r.size), ny=int(solver_z.size),
        boundary=observed_dirichlet_boundary, psi=source_psi_solver.copy(),
        current=source["plasma_current"], order=4, check_limited=False,
    )
    if not np.array_equal(eq.R[:, 0], solver_r) or not np.array_equal(eq.Z[0, :], solver_z):
        raise RuntimeError("FreeGS constructed an unexpected solver grid")
    source_jtor = profiles.Jtor(
        eq.R, eq.Z, source_psi_solver, psi_bndry=source["psi_boundary"])
    source_residual = independent_gs_residual(
        solver_r, solver_z, source_psi_solver, source_jtor, mu_0, np)
    source_state = make_forward_state(
        "tabulated_profile_source_reconstruction", "same_source_reference_reconstruction",
        solver_r, solver_z, source_psi_solver, source_jtor, source_residual,
        snapshot["snapshot_payload_sha256"], boundary_hash, np)
    execution_state["source_state_completed"] = True
    execution_state["partial_numerics"] = {
        "source_state": source_state,
        "coordinate_transform": transform,
        "observed_dirichlet_boundary_sha256": boundary_hash,
    }

    execution_state["phase"] = "test_only_frozen_source_linear_diagnostic"
    frozen_source_linear = frozen_source_jtor_linear_diagnostic(
        freegs=freegs, profiles=profiles, source=source,
        solver_r=solver_r, solver_z=solver_z,
        source_psi_solver=source_psi_solver, source_jtor=source_jtor,
        observed_dirichlet_boundary=observed_dirichlet_boundary,
        boundary_edges=boundary_edges, mu_0=mu_0, np=np,
    )
    execution_state["partial_numerics"][
        "test_only_frozen_source_jtor_linear_diagnostic"] = frozen_source_linear

    equilibrium_module = sys.modules[type(eq).__module__]
    critical_module = getattr(equilibrium_module, "critical")
    if getattr(freegs.jtor, "critical") is not critical_module:
        raise RuntimeError(
            "FreeGS equilibrium and profile modules do not share the pinned critical module")
    observer = EquilibriumSolveObserver(
        eq=eq, profiles=profiles, critical_module=critical_module,
        boundary_edges=boundary_edges, mu_0=mu_0, np=np,
    )
    iteration_observation: dict[str, Any]

    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        execution_state["phase"] = "numerical_solve"
        execution_state["solve_attempted"] = True
        try:
            with observer:
                max_change, relative_change = freegs.solve(
                    eq, profiles, constrain=None, rtol=float(controls["rtol"]),
                    atol=float(controls["atol"]), blend=float(controls["blend"]),
                    psi_bndry=source["psi_boundary"],
                    maxits=int(controls["max_iterations"]),
                    convergenceInfo=True, check_limited=False,
                )
        except Exception:
            iteration_observation = observer.report(formal_solve_returned=False)
            execution_state["partial_numerics"][
                "actual_equilibrium_solve_observation"] = iteration_observation
            partial_psi = np.ascontiguousarray(eq.psi(), dtype=np.dtype("<f8"))
            partial_record: dict[str, Any] = {
                "dimensions": ["r", "z"],
                "units": "Wb / rad",
                "shape": list(partial_psi.shape),
                "dtype": "<f8",
                "values_sha256": hashlib.sha256(partial_psi.tobytes(order="C")).hexdigest(),
                "finite_count": int(np.isfinite(partial_psi).sum()),
                "total_count": int(partial_psi.size),
            }
            if bool(np.isfinite(partial_psi).all()):
                partial_record["values"] = partial_psi.tolist()
            execution_state["partial_numerics"]["partial_solver_psi"] = partial_record
            execution_state["partial_numerics"]["iteration_history_status"] = (
                "actual_equilibrium_solve_calls_observed_but_FreeGS_return_arrays_"
                "unavailable_when_FreeGS_0_8_2_raises")
            execution_state["partial_numerics"]["actual_eq_solve_call_count"] = len(
                observer.calls)
            execution_state["partial_numerics"]["requested_max_iterations"] = int(
                controls["max_iterations"])
            raise
    iteration_observation = observer.report(formal_solve_returned=True)
    execution_state["partial_numerics"][
        "actual_equilibrium_solve_observation"] = iteration_observation
    execution_state["solve_completed"] = True
    execution_state["phase"] = "numerical_postprocess"
    solved_psi = np.asarray(eq.psi(), dtype=float)
    solved_jtor = np.asarray(eq.Jtor, dtype=float)
    boundary_checks = {
        "r_min_exact": bool(np.array_equal(solved_psi[0, :], boundary_edges["r_min"])),
        "r_max_exact": bool(np.array_equal(solved_psi[-1, :], boundary_edges["r_max"])),
        "z_min_exact": bool(np.array_equal(solved_psi[:, 0], boundary_edges["z_min"])),
        "z_max_exact": bool(np.array_equal(solved_psi[:, -1], boundary_edges["z_max"])),
    }
    if not all(boundary_checks.values()):
        raise RuntimeError(f"observed Dirichlet boundary drifted: {boundary_checks}")
    solved_residual = independent_gs_residual(
        solver_r, solver_z, solved_psi, solved_jtor, mu_0, np)
    solved_state = make_forward_state(
        "observed_dirichlet_fixed_boundary_solution", "conditional_fixed_boundary_solution",
        solver_r, solver_z, solved_psi, solved_jtor, solved_residual,
        snapshot["snapshot_payload_sha256"], boundary_hash, np)
    psi_delta = solved_psi - source_psi_solver
    jtor_delta = solved_jtor - source_jtor
    comparison = {
        "schema": "fusionconceptai:generic-axisymmetric-forward-comparison-v1",
        "reference_state_sha256": source_state["state_sha256"],
        "prediction_state_sha256": solved_state["state_sha256"],
        "grid_identity": (source_state["r_m"]["values_sha256"] == solved_state["r_m"]["values_sha256"]
                          and source_state["z_m"]["values_sha256"] == solved_state["z_m"]["values_sha256"]),
        "psi_l2_relative": float(np.linalg.norm(psi_delta) / max(np.linalg.norm(source_psi_solver), 1.0e-30)),
        "psi_linf_relative": float(np.max(np.abs(psi_delta)) / max(np.max(np.abs(source_psi_solver)), 1.0e-30)),
        "jtor_l2_relative": float(np.linalg.norm(jtor_delta) / max(np.linalg.norm(source_jtor), 1.0e-30)),
        "conditional_boundary_from_reconstruction": True,
        "independent_validation": False,
        "likelihood_ready": False,
        "claim_ceiling": CLAIM_CEILING,
    }
    comparison["comparison_sha256"] = canonical_hash(comparison)
    result = {
        "schema": OUTPUT_SCHEMA,
        "revision": REVISION,
        "status": "conditional_fixed_boundary_solver_converged_residual_measured",
        "context_hash": wrapper["context_hash"],
        "candidate_hash": wrapper["candidate_hash"],
        "physical_subject_hash": wrapper["physical_subject_hash"],
        "scenario_hash": wrapper["scenario_hash"],
        "binding_hash": wrapper["binding_hash"],
        "declaration_hash": wrapper["declaration_hash"],
        "source_snapshot_file_sha256": wrapper["source_snapshot_file_sha256"],
        "source_snapshot_payload_sha256": snapshot["snapshot_payload_sha256"],
        "semantic_input_sha256": input_file_sha256,
        "environment": environment,
        "coordinate_transform": transform,
        "machine": {"kind": "explicit_empty_machine", "coil_count": 0,
                    "external_field_role": "encoded_only_by_observed_dirichlet_boundary"},
        "boundary": {"kind": "observed_dirichlet_box_edges",
                     "boundary_sha256": boundary_hash, **boundary_checks},
        "cocos_consumed_subset": COCOS_CONSUMED_SUBSET,
        "convergence": {
            "iterations": int(len(relative_change)),
            "final_relative_change": float(relative_change[-1]),
            "final_max_change": float(max_change[-1]),
            "requested_rtol": float(controls["rtol"]),
            "requested_atol": float(controls["atol"]),
            "max_iterations": int(controls["max_iterations"]),
        },
        "actual_equilibrium_solve_observation": iteration_observation,
        "test_only_frozen_source_jtor_linear_diagnostic": frozen_source_linear,
        "source_state": source_state,
        "solved_state": solved_state,
        "comparison": comparison,
        "numerical_assessment": {
            "solver_iteration_converged": True,
            "independent_gs_residual_measured": True,
            "independent_gs_residual_acceptance_threshold": "typed_absent_not_defined",
            "independent_pde_acceptance": False,
        },
        "unconsumed_source_inputs": {
            "internal_pf_currents": "present_unmapped_no_geometry_role",
            "fitted_input_currents": "present_unmapped_no_geometry_role",
            "heating_power": "not_part_of_grad_shafranov_solve",
        },
        "free_boundary_status": "typed_absent_unmapped_coil_geometry",
        "warnings": list(dict.fromkeys(str(item.message) for item in caught)),
        "claim_boundary": {
            "claim_ceiling": CLAIM_CEILING,
            "reference_inversion_G1_G2_G3": False,
            "executable_source_scope": "G2_profile_fixed_boundary",
            "solve_attempted": True,
            "solve_completed": True,
            "conditional_boundary_from_reconstruction": True,
            "same_source_reference": True,
            "independent_validation": False,
            "physical_validation": False,
            "engineering_validation": False,
            "likelihood_ready": False,
            "formal_acceptance": False,
            "terminal_authority": False,
        },
    }
    result["result_sha256"] = canonical_hash(result)
    execution_state["postprocess_completed"] = True
    execution_state["phase"] = "completed"
    return result


def validation_only_result(wrapper: dict[str, Any], snapshot: dict[str, Any],
                           input_file_sha256: str) -> dict[str, Any]:
    result = {
        "schema": OUTPUT_SCHEMA, "revision": REVISION,
        "status": "validated_input_no_solve",
        "context_hash": wrapper["context_hash"], "candidate_hash": wrapper["candidate_hash"],
        "physical_subject_hash": wrapper["physical_subject_hash"],
        "scenario_hash": wrapper["scenario_hash"], "binding_hash": wrapper["binding_hash"],
        "declaration_hash": wrapper["declaration_hash"],
        "source_snapshot_file_sha256": wrapper["source_snapshot_file_sha256"],
        "source_snapshot_payload_sha256": snapshot["snapshot_payload_sha256"],
        "semantic_input_sha256": input_file_sha256,
        "cocos_consumed_subset": COCOS_CONSUMED_SUBSET,
        "free_boundary_status": "typed_absent_unmapped_coil_geometry",
        "claim_boundary": {"claim_ceiling": CLAIM_CEILING,
                           "reference_inversion_G1_G2_G3": False,
                           "executable_source_scope": "G2_profile_fixed_boundary",
                           "solve_attempted": False, "solve_completed": False,
                           "independent_validation": False, "likelihood_ready": False,
                           "formal_acceptance": False, "terminal_authority": False},
    }
    result["result_sha256"] = canonical_hash(result)
    return result


def write_result(path: Path, result: dict[str, Any]) -> tuple[str, int]:
    raw = json.dumps(result, indent=2, sort_keys=True, allow_nan=False).encode("utf-8") + b"\n"
    path.write_bytes(raw)
    return hashlib.sha256(raw).hexdigest(), len(raw)


def emit_summary(result: Mapping[str, Any], output_file_sha256: str) -> None:
    convergence = result.get("convergence", {})
    comparison = result.get("comparison", {})
    fields = [
        SUMMARY_MARKER, str(result.get("status", "")), str(result.get("result_sha256", "")),
        str(result.get("context_hash", "")), str(result.get("binding_hash", "")),
        str(result.get("source_snapshot_payload_sha256", "")),
        str(convergence.get("iterations", "")), str(convergence.get("final_relative_change", "")),
        str(comparison.get("psi_l2_relative", "")), str(comparison.get("jtor_l2_relative", "")),
        output_file_sha256, str(result.get("semantic_input_sha256", "")),
        str(result.get("source_state", {}).get("state_sha256", "")),
        str(result.get("solved_state", {}).get("state_sha256", "")),
        str(result.get("comparison", {}).get("comparison_sha256", "")),
        str(result.get("boundary", {}).get("boundary_sha256", "")),
    ]
    print("\t".join(fields), flush=True)


def classify_failure(exc: Exception, execution_state: Mapping[str, Any]) -> tuple[str, int]:
    phase = str(execution_state.get("phase", "input_validation"))
    if (bool(execution_state.get("solve_attempted"))
            and isinstance(exc, RuntimeError)
            and str(exc) == PICARD_NONCONVERGENCE_MESSAGE):
        status = "numerical_fail_nonconvergence"
    elif phase == "backend_import" and isinstance(
            exc, (ImportError, OSError, importlib.metadata.PackageNotFoundError)):
        status = "backend_unavailable"
    elif phase in {"input_validation", "source_validation"}:
        status = "input_validation_failed"
    else:
        status = "program_exception"
    return status, FAILURE_EXIT_CODES[status]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args(argv)
    wrapper: dict[str, Any] = {}
    snapshot: dict[str, Any] = {}
    input_file_sha256 = ""
    actual_source_hash = ""
    environment: dict[str, Any] = {}
    execution_state: dict[str, Any] = {
        "phase": "input_validation",
        "input_validation_completed": False,
        "backend_loaded": False,
        "source_validation_completed": False,
        "source_state_completed": False,
        "solve_attempted": False,
        "solve_completed": False,
        "postprocess_completed": False,
        "partial_numerics": {},
    }
    try:
        input_file_sha256 = file_hash(args.input)
        wrapper = validate_wrapper(json.loads(args.input.read_text(encoding="utf-8")))
        execution_state["input_validation_completed"] = True
        actual_source_hash = file_hash(args.source)
        if actual_source_hash != wrapper["source_snapshot_file_sha256"]:
            raise ValueError("source snapshot file hash mismatch")
        snapshot_raw = json.loads(args.source.read_text(encoding="utf-8"))
        if args.validate_only:
            execution_state["phase"] = "backend_import"
            import numpy as np
            execution_state["backend_loaded"] = True
            execution_state["phase"] = "source_validation"
            snapshot, _ = validate_snapshot(snapshot_raw, np)
            if snapshot["snapshot_payload_sha256"] != wrapper["source_snapshot_payload_sha256"]:
                raise ValueError("wrapper/source snapshot payload mismatch")
            execution_state["source_validation_completed"] = True
            execution_state["phase"] = "completed"
            result = validation_only_result(wrapper, snapshot, input_file_sha256)
        else:
            execution_state["phase"] = "backend_import"
            environment, freegs, np, scipy = environment_manifest()
            execution_state["backend_loaded"] = True
            execution_state["phase"] = "source_validation"
            snapshot, source = validate_snapshot(snapshot_raw, np)
            if snapshot["snapshot_payload_sha256"] != wrapper["source_snapshot_payload_sha256"]:
                raise ValueError("wrapper/source snapshot payload mismatch")
            execution_state["source_validation_completed"] = True
            result = solve(wrapper, snapshot, source, environment, freegs, np, scipy,
                           input_file_sha256, execution_state)
        output_sha, _ = write_result(args.output, result)
        emit_summary(result, output_sha)
        return 0
    except Exception as exc:
        status, exit_code = classify_failure(exc, execution_state)
        failure = {
            "schema": OUTPUT_SCHEMA, "revision": REVISION,
            "status": status, "phase": execution_state["phase"],
            "runner_exit_code": exit_code,
            "execution_state": execution_state,
            "exception_type": type(exc).__name__,
            "message": str(exc), "traceback": traceback.format_exc(),
            "context_hash": wrapper.get("context_hash", ""),
            "candidate_hash": wrapper.get("candidate_hash", ""),
            "physical_subject_hash": wrapper.get("physical_subject_hash", ""),
            "scenario_hash": wrapper.get("scenario_hash", ""),
            "binding_hash": wrapper.get("binding_hash", ""),
            "declaration_hash": wrapper.get("declaration_hash", ""),
            "source_snapshot_file_sha256": actual_source_hash,
            "source_snapshot_payload_sha256": wrapper.get(
                "source_snapshot_payload_sha256", snapshot.get("snapshot_payload_sha256", "")),
            "semantic_input_sha256": input_file_sha256,
            "environment": environment,
            "cocos_consumed_subset": COCOS_CONSUMED_SUBSET,
            "claim_boundary": {"claim_ceiling": CLAIM_CEILING,
                               "reference_inversion_G1_G2_G3": False,
                               "executable_source_scope": "G2_profile_fixed_boundary",
                               "solve_attempted": execution_state["solve_attempted"],
                               "solve_completed": execution_state["solve_completed"],
                               "independent_validation": False, "likelihood_ready": False,
                               "formal_acceptance": False, "terminal_authority": False},
        }
        failure["result_sha256"] = canonical_hash(failure)
        output_sha, _ = write_result(args.output, failure)
        emit_summary(failure, output_sha)
        return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
