"""Opt-in adapter for the candidate-owned N2 DESC replay request.

The adapter reconstructs a fresh DESC Equilibrium from normalized fields. It
never loads the source solved equilibrium as an initial state. Construction and
solver results remain screen-only; a successful optimizer is not validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np

from validate_member_join import validate as validate_member_join


ROOT = Path(__file__).resolve().parent
BUILDER = ROOT.parent.parent / "src" / "RuntimeV4" / "N2SourceDESCReplayRequestV4.jl"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _finite(value, label):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(float(value)):
        raise ValueError(f"{label} is not finite SI data")
    return float(value)


def _dict_mode(row, label):
    if not isinstance(row, dict) or set(row) != {"m", "n", "coefficient_m"}:
        raise ValueError(f"{label} mode schema mismatch")
    return int(row["m"]), int(row["n"]), _finite(row["coefficient_m"], label)


def _paths(request):
    names = ("source_artifact_path", "source_manifest_path", "interior_result_path",
             "normalized_result_path", "member_join_receipt_path")
    paths = {name.removesuffix("_path"): Path(request[name]).resolve() for name in names}
    return paths


R2_REQUEST_SHA256 = "6b7dfba27172b52ca206b8bcbc6ea43aeafe08bba2e82706fef4826a4c981abe"


def validate_request(request_path: Path, expected_request_sha256: str) -> tuple[dict, dict, dict]:
    if sha(request_path) != expected_request_sha256.lower():
        raise ValueError("request file hash mismatch")
    request = json.loads(request_path.read_text(encoding="utf-8"))
    required = {"schema_version", "revision", "request_builder_sha256", "request_hash",
                "source_artifact_path", "source_artifact_sha256", "source_manifest_path",
                "interior_result_path", "interior_result_sha256", "normalized_result_path",
                "normalized_result_sha256", "member_join_receipt_path",
                "member_join_receipt_sha256", "selected_equilibrium_index", "source_basis",
                "surface_basis", "profile_basis", "field_periods", "resolution", "boundary",
                "pressure_coefficients", "iota_coefficients", "toroidal_flux_wb", "authority"}
    if not required.issubset(request):
        raise ValueError("source replay request schema is incomplete")
    if request["schema_version"] != "fusionconceptai:runtime-v4-n2-source-desc-replay-request" or request["revision"] != "v1":
        raise ValueError("source replay request schema/revision mismatch")
    if sha(BUILDER) != request["request_builder_sha256"]:
        raise ValueError("request builder source hash mismatch")
    if request["authority"] != {"claim_ceiling": "screen_only", "geometry_proved": False,
                                  "provider_executed": False, "physical_validation": "unsupported",
                                  "credible_device_count": 0}:
        raise ValueError("replay request authority was promoted")
    controls = request.get("controls", {})
    if (controls.get("optimizer"), controls.get("objective")) != ("lsq-exact", "force"):
        raise ValueError("replay controls are not the frozen force/lsq-exact controls")
    if not isinstance(controls.get("maxiter"), int) or isinstance(controls.get("maxiter"), bool) or not 1 <= controls["maxiter"] <= 1000:
        raise ValueError("replay maxiter is invalid")
    for key in ("ftol", "xtol", "gtol"):
        if isinstance(controls.get(key), bool) or not isinstance(controls.get(key), (int, float)) or not math.isfinite(float(controls[key])) or float(controls[key]) <= 0:
            raise ValueError(f"replay control {key} is invalid")
    paths = _paths(request)
    expected = {"source_artifact_path": paths["source_artifact"], "source_manifest_path": paths["source_manifest"],
                "interior_result_path": paths["interior_result"], "normalized_result_path": paths["normalized_result"],
                "member_join_receipt_path": paths["member_join_receipt"]}
    for name, path in expected.items():
        if not path.is_file():
            raise ValueError(f"replay input is missing: {name}")
    if sha(paths["source_artifact"]) != request["source_artifact_sha256"] or sha(paths["interior_result"]) != request["interior_result_sha256"] or sha(paths["normalized_result"]) != request["normalized_result_sha256"] or sha(paths["member_join_receipt"]) != request["member_join_receipt_sha256"]:
        raise ValueError("replay input hash mismatch")
    manifest = json.loads(paths["source_manifest"].read_text(encoding="utf-8"))
    normalized = json.loads(paths["normalized_result"].read_text(encoding="utf-8"))
    interior = json.loads(paths["interior_result"].read_text(encoding="utf-8"))
    receipt = json.loads(paths["member_join_receipt"].read_text(encoding="utf-8"))
    if str(paths["source_manifest"]) != str((paths["source_artifact"].parent / "source.json").resolve()):
        raise ValueError("source manifest is not adjacent to source artifact")
    joined = validate_member_join(paths["source_manifest"], paths["normalized_result"], paths["interior_result"])
    if not set(joined).issubset(receipt) or any(receipt[k] != value for k, value in joined.items()):
        raise ValueError("member receipt does not reproduce current raw join")
    if request["selected_equilibrium_index"] != 3 or request["field_periods"] != 19:
        raise ValueError("source member/NFP contract mismatch")
    source_basis = request["source_basis"]
    if source_basis != {"class": "desc.basis.FourierZernikeBasis", "indexing": "fringe", "R_symmetry": "cos", "Z_symmetry": "sin"}:
        raise ValueError("source Fourier-Zernike convention mismatch")
    surface_basis = request["surface_basis"]
    if surface_basis != {"class": "desc.basis.DoubleFourierSeries", "indexing": "linear", "R_symmetry": "cos", "Z_symmetry": "sin"}:
        raise ValueError("surface convention mismatch")
    if request["profile_basis"] != {"class": "desc.profiles.PowerSeriesProfile", "symmetry": "even", "coordinate": "rho", "pressure_unit": "Pa", "iota_unit": "1"}:
        raise ValueError("profile convention mismatch")
    resolution = request["resolution"]
    if resolution != {"L": 24, "M": 12, "N": 3, "L_grid": 36, "M_grid": 18, "N_grid": 6}:
        raise ValueError("source resolution/grid contract mismatch")
    subject = normalized["subject"]
    if subject["source_artifact_sha256"] != request["source_artifact_sha256"] or subject["field_periods"] != 19 or subject["source_resolution"]["L"] != 24 or subject["source_resolution"]["M"] != 12 or subject["source_resolution"]["N"] != 3:
        raise ValueError("normalized physics-bearing fields differ from request")
    for name, rows in (("R", request["boundary"]["R_modes"]), ("Z", request["boundary"]["Z_modes"])):
        expected = subject["boundary"]["radial_modes" if name == "R" else "vertical_modes"]
        if [_dict_mode(row, name) for row in rows] != [_dict_mode(row, name) for row in expected]:
            raise ValueError(f"request boundary {name} differs from normalized subject")
    for key, field in (("pressure_coefficients", "pressure_profile"), ("iota_coefficients", "rotational_or_current_profile")):
        values = tuple(_finite(x, key) for x in request[key])
        expected = tuple(_finite(x, key) for x in subject[field]["coefficients_by_power"])
        if values != expected or any(values[i] != 0.0 for i in range(1, len(values), 2)):
            raise ValueError(f"request {key} is not the normalized finite even profile")
    if request["toroidal_flux_wb"] != _finite(subject["toroidal_flux"]["value"], "toroidal flux"):
        raise ValueError("request toroidal flux differs from normalized subject")
    for value in request["pressure_coefficients"] + request["iota_coefficients"]:
        _finite(value, "profile")
    return request, normalized, joined


def construct_equilibrium(request: dict):
    try:
        from desc.equilibrium import Equilibrium
        from desc.geometry import FourierRZToroidalSurface
        from desc.profiles import PowerSeriesProfile
    except ImportError as error:
        raise RuntimeError(f"DESC is unavailable for construction: {error}") from error
    b = request["boundary"]
    R = [(_dict_mode(x, "R")) for x in b["R_modes"]]
    Z = [(_dict_mode(x, "Z")) for x in b["Z_modes"]]
    surface = FourierRZToroidalSurface(R_lmn=[x[2] for x in R], Z_lmn=[x[2] for x in Z],
        modes_R=[[x[0], x[1]] for x in R], modes_Z=[[x[0], x[1]] for x in Z], NFP=19, sym=True)
    def profile(dense):
        modes = [power for power, value in enumerate(dense)
                 if power % 2 == 0 and value != 0.0]
        params = [dense[mode] for mode in modes]
        return PowerSeriesProfile(params, modes=modes, sym="even")
    return Equilibrium(L=24, M=12, N=3, L_grid=36, M_grid=18, N_grid=6,
        NFP=19, Psi=float(request["toroidal_flux_wb"]), surface=surface,
        pressure=profile(request["pressure_coefficients"]),
        iota=profile(request["iota_coefficients"]), spectral_indexing="fringe")


def verify_constructed_equilibrium(eq, request: dict) -> None:
    if (eq.NFP, eq.L, eq.M, eq.N) != (19, 24, 12, 3) or (eq.L_grid, eq.M_grid, eq.N_grid) != (36, 18, 6):
        raise ValueError("constructed equilibrium resolution differs from request")
    if getattr(eq, "spectral_indexing", None) != "fringe" or eq.surface.NFP != 19 or not bool(eq.surface.sym):
        raise ValueError("constructed equilibrium basis/orientation differs from request")
    if not math.isclose(float(eq.Psi), float(request["toroidal_flux_wb"]), rel_tol=0.0, abs_tol=0.0):
        raise ValueError("constructed equilibrium flux differs from request")
    def coeffs(basis, values):
        return {(int(m[1]), int(m[2])): float(v) for m, v in zip(basis.modes, values, strict=True)}
    for name, rows, basis, values in (("R", request["boundary"]["R_modes"], eq.surface.R_basis, eq.surface.R_lmn), ("Z", request["boundary"]["Z_modes"], eq.surface.Z_basis, eq.surface.Z_lmn)):
        actual = coeffs(basis, values)
        for row in rows:
            m, n, value = _dict_mode(row, name)
            if not math.isclose(actual[(m, n)], value, rel_tol=1e-12, abs_tol=1e-12):
                raise ValueError(f"constructed equilibrium {name} coefficient mismatch")
    for name, profile, expected in (("pressure", eq.pressure, request["pressure_coefficients"]),
                                    ("iota", eq.iota, request["iota_coefficients"])):
        if getattr(profile.basis, "sym", None) != "even":
            raise ValueError(f"constructed {name} profile basis is not even")
        modes = profile.basis.modes
        actual = {(int(mode[0]), int(mode[1]), int(mode[2])): float(value)
                  for mode, value in zip(modes, profile.params, strict=True)}
        expected_nonzero = {(index, 0, 0): float(value)
                            for index, value in enumerate(expected)
                            if index % 2 == 0 and value != 0.0}
        actual_nonzero = {mode: value for mode, value in actual.items() if value != 0.0}
        if actual_nonzero != expected_nonzero or any(mode[0] % 2 or mode[1:] != (0, 0) for mode in actual):
            raise ValueError(f"constructed {name} profile modes/coefficients mismatch")
        for rho in (0.0, 0.5, 1.0):
            expected_value = sum(float(value) * rho ** index
                                 for index, value in enumerate(expected))
            actual_value = float(profile(rho)[0])
            if not math.isclose(actual_value, expected_value, rel_tol=1e-12, abs_tol=1e-12):
                raise ValueError(f"constructed {name} profile evaluation mismatch at rho={rho}")


def run(request_path: Path, output_dir: Path, expected_request_sha256: str,
        solve: bool = True) -> dict:
    if output_dir.exists() and any(output_dir.iterdir()):
        raise ValueError("refusing to overwrite non-empty output directory")
    output_dir.mkdir(parents=True, exist_ok=True)
    request, normalized, joined = validate_request(request_path, expected_request_sha256)
    eq = construct_equilibrium(request)
    verify_constructed_equilibrium(eq, request)
    import desc
    result = {"schema_version": "n2-source-desc-replay-result-v1", "status": "constructed_screen_only",
              "request_sha256": sha(request_path), "declared_request_hash": request["request_hash"],
              "request_builder_sha256": sha(BUILDER),
              "adapter_sha256": sha(Path(__file__)), "desc_version": desc.__version__,
              "python_version": sys.version.split()[0],
              "candidate_hash": request["candidate_hash"], "context_hash": request["context_hash"],
              "physical_subject_hash": request["physical_subject_hash"],
              "candidate_geometry_binding_hash": request["candidate_geometry_binding_hash"],
              "source_geometry_program_hash": request["source_geometry_program_hash"],
              "source_artifact_sha256": request["source_artifact_sha256"],
              "normalized_result_sha256": request["normalized_result_sha256"],
              "interior_result_sha256": request["interior_result_sha256"],
              "member_join_receipt_sha256": request["member_join_receipt_sha256"],
              "member_join_status": joined["status"], "solve_requested": solve,
              "solver": None, "output_hdf5_sha256": None,
              "authority": {"claim_ceiling": "screen_only", "geometry_proved": False,
                             "provider_executed": False, "physical_validation": "unsupported",
                             "measurement": False, "inverse_ready": False,
                             "credible_device_count": 0}}
    checkpoint = {"status": "pre_solve_constructed", "request_sha256": result["request_sha256"],
                  "source_artifact_sha256": result["source_artifact_sha256"], "candidate_hash": result["candidate_hash"],
                  "controls": request["controls"], "authority": result["authority"]}
    (output_dir / "pre_solve_checkpoint.json").write_text(json.dumps(checkpoint, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if solve:
        controls = request["controls"]
        try:
            solved, info = eq.solve(objective="force", optimizer="lsq-exact", maxiter=controls["maxiter"],
                                    ftol=controls["ftol"], xtol=controls["xtol"], gtol=controls["gtol"], verbose=0, copy=True)
        except Exception as error:
            (output_dir / "solve_exception.json").write_text(json.dumps({"status": "solver_exception", "type": type(error).__name__, "message": str(error), "request_sha256": result["request_sha256"], "authority": result["authority"]}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
            raise
        success = getattr(info, "success", None)
        nit = getattr(info, "nit", None)
        fun = getattr(info, "fun", None)
        residual = None if fun is None else np.asarray(fun, dtype=float).reshape(-1)
        residual_finite = (residual is not None and residual.size > 0 and
                           bool(np.all(np.isfinite(residual))))
        result["status"] = ("solver_numerical_fail_screen_only" if not residual_finite else
                            "solver_converged_screen_only" if bool(success) else
                            "solver_nonconverged_screen_only")
        result["solver"] = {"success": bool(success) if success is not None else None,
                             "message": str(getattr(info, "message", "")),
                             "niter": int(nit) if nit is not None else None,
                             "residual_count": int(residual.size) if residual is not None else None,
                             "residual_all_finite": residual_finite,
                             "residual_l2_norm": float(np.linalg.norm(residual)) if residual_finite else None,
                             "residual_max_abs": float(np.max(np.abs(residual))) if residual_finite else None}
        verify_constructed_equilibrium(solved, request)
        output = output_dir / "replay_equilibrium.h5"
        solved.save(output)
        result["output_hdf5_sha256"] = sha(output)
    (output_dir / "result.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("request", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--expected-request-sha256", required=True)
    parser.add_argument("--construct-only", action="store_true")
    parser.add_argument("--solve", action="store_true")
    args = parser.parse_args()
    if args.construct_only and args.solve:
        raise SystemExit("choose --construct-only or --solve")
    if args.expected_request_sha256.lower() != R2_REQUEST_SHA256:
        raise SystemExit("expected request SHA is not the frozen r2 artifact")
    result = run(args.request.resolve(), args.output_dir.resolve(), solve=not args.construct_only,
                 expected_request_sha256=args.expected_request_sha256)
    print(f"N2_SOURCE_DESC_REPLAY_OUTPUT={args.output_dir.resolve()}")
    print(f"N2_SOURCE_DESC_REPLAY_STATUS={result['status']}")
    print("N2_SOURCE_DESC_REPLAY_PHYSICAL_VALIDATION=unsupported")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
