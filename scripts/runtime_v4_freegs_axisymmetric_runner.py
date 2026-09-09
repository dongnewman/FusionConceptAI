#!/usr/bin/env python3
"""Controlled FreeGS 0.8.2 process for the Runtime V4 typed bridge.

The JSON dictionary exists only at this process boundary. The Julia caller
constructs it from an externally revalidated typed subject binding and hashes
the exact input/output bytes. This runner never emits validation or feasibility
claims; dependency and solver exceptions become recoverable unknown artifacts.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import math
import platform
import sys
import traceback
import warnings
from pathlib import Path


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
    wrapper = require_exact(payload, wrapper_keys, "wrapper")
    if wrapper["schema"] != INPUT_SCHEMA or wrapper["revision"] != RUNNER_REVISION:
        raise ValueError("Runtime V4 FreeGS input schema/revision mismatch")
    for key in wrapper_keys - {"schema", "revision", "solver_input"}:
        value = wrapper[key]
        if not isinstance(value, str) or len(value) != 64 or any(c not in "0123456789abcdef" for c in value):
            raise ValueError(f"{key} must be a lowercase SHA-256 digest")

    solver = require_exact(wrapper["solver_input"],
                           {"machine", "domain", "profile", "constraints", "solver"},
                           "solver_input")
    machine = require_exact(solver["machine"], {"kind", "coils"}, "machine")
    if machine["kind"] != "explicit_filament_coils":
        raise ValueError("only explicit_filament_coils is supported")
    if not isinstance(machine["coils"], list) or not 4 <= len(machine["coils"]) <= 32:
        raise ValueError("the bridge requires 4 to 32 explicit coils")
    coil_ids: list[str] = []
    for index, coil_value in enumerate(machine["coils"]):
        coil = require_exact(coil_value, {"id", "major_radius_m", "vertical_position_m"},
                             f"coil[{index}]")
        if not isinstance(coil["id"], str) or not coil["id"].strip():
            raise ValueError("coil id cannot be empty")
        coil_ids.append(coil["id"])
        if finite(coil["major_radius_m"], "coil major radius") <= 0:
            raise ValueError("coil major radius must be positive")
        finite(coil["vertical_position_m"], "coil vertical position")
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

    profile = require_exact(solver["profile"],
                            {"kind", "axis_pressure_pa", "plasma_current_a", "vacuum_f_tm",
                             "alpha_m", "alpha_n", "profile_axis_radius_m"}, "profile")
    if profile["kind"] != "ConstrainPaxisIp":
        raise ValueError("only ConstrainPaxisIp is supported")
    for key in ("axis_pressure_pa", "plasma_current_a", "vacuum_f_tm", "alpha_m",
                "alpha_n", "profile_axis_radius_m"):
        finite(profile[key], key)

    constraints = require_exact(solver["constraints"], {"xpoints_m", "isoflux_m", "gamma"},
                                "constraints")
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

    settings = require_exact(solver["solver"], {"rtol", "atol", "max_iterations"}, "solver")
    if not 0 < finite(settings["rtol"], "rtol") < 1:
        raise ValueError("rtol must be within (0,1)")
    if not 0 < finite(settings["atol"], "atol") < 1:
        raise ValueError("atol must be within (0,1)")
    if int(settings["max_iterations"]) < 1:
        raise ValueError("max_iterations must be positive")
    return wrapper


def solve(wrapper: dict, environment: dict, freegs: object, np: object, scipy: object) -> dict:
    from scipy.constants import mu_0

    payload = wrapper["solver_input"]
    machine = payload["machine"]
    coils = [
        (str(item["id"]), freegs.machine.Coil(float(item["major_radius_m"]),
                                              float(item["vertical_position_m"])))
        for item in machine["coils"]
    ]
    tokamak = freegs.machine.Machine(coils)
    domain = payload["domain"]
    eq = freegs.Equilibrium(
        tokamak=tokamak,
        Rmin=float(domain["r_min_m"]), Rmax=float(domain["r_max_m"]),
        Zmin=float(domain["z_min_m"]), Zmax=float(domain["z_max_m"]),
        nx=int(domain["nx"]), ny=int(domain["ny"]),
        boundary=freegs.boundary.freeBoundaryHagenow,
    )
    profile = payload["profile"]
    profiles = freegs.jtor.ConstrainPaxisIp(
        eq, float(profile["axis_pressure_pa"]), float(profile["plasma_current_a"]),
        float(profile["vacuum_f_tm"]), alpha_m=float(profile["alpha_m"]),
        alpha_n=float(profile["alpha_n"]), Raxis=float(profile["profile_axis_radius_m"]),
    )
    constraints = payload["constraints"]
    xpoints = [tuple(map(float, point)) for point in constraints["xpoints_m"]]
    isoflux = [tuple(map(float, item)) for item in constraints["isoflux_m"]]
    controller = freegs.control.constrain(xpoints=xpoints, isoflux=isoflux,
                                          gamma=float(constraints["gamma"]))
    settings = payload["solver"]
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        max_change, relative_change = freegs.solve(
            eq, profiles, controller, rtol=float(settings["rtol"]),
            atol=float(settings["atol"]), maxits=int(settings["max_iterations"]),
            convergenceInfo=True,
        )

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
    axis_r, axis_z, axis_psi = map(float, eq.magneticAxis())
    q_values = np.asarray(eq.q(np.asarray([0.01, 0.50, 0.95])), dtype=float)
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
        "coil_currents_a": {label: float(coil.current) for label, coil in tokamak.coils},
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
        environment, freegs, np, scipy = environment_manifest()
        result = solve(wrapper, environment, freegs, np, scipy)
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
        result["result_hash"] = canonical_hash(result)
    output_file_hash = write_result(output_path, result)
    emit_summary(result, wrapper, output_file_hash)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
