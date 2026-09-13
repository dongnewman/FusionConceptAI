"""Independent raw-HDF5 to derived-subject join check (screen-only).

This deliberately uses h5py and the stored arrays directly; it does not import
DESC or claim a physical, solver, or measurement validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import h5py


ROOT = Path(__file__).resolve().parent
DEFAULT_SOURCE = ROOT / "source.json"
DEFAULT_NORMALIZED = ROOT.parent.parent / "runs" / "goal_recovery_20260913_012528_cst" / "n2_desc_heliotron_normalize_r3" / "result.json"
DEFAULT_INTERIOR = ROOT.parent.parent / "runs" / "goal_recovery_20260913_012528_cst" / "n2_desc_heliotron_interior_r1" / "result.json"
TOLERANCE = 1e-12


def file_sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def _text(value) -> str:
    return value.decode() if isinstance(value, bytes) else str(value)


def _jacobi(order: int, alpha: int, beta: int, x: float) -> float:
    if order == 0:
        return 1.0
    previous = 1.0
    current = 0.5 * (alpha - beta + (alpha + beta + 2) * x)
    if order == 1:
        return current
    for n in range(2, order + 1):
        a1 = 2 * n * (n + alpha + beta) * (2 * n + alpha + beta - 2)
        a2 = (2 * n + alpha + beta - 1) * (alpha * alpha - beta * beta)
        a3 = (2 * n + alpha + beta - 1) * (2 * n + alpha + beta) * (2 * n + alpha + beta - 2)
        a4 = 2 * (n + alpha - 1) * (n + beta - 1) * (2 * n + alpha + beta)
        previous, current = current, ((a2 + a3 * x) * current - a4 * previous) / a1
    return current


def _zernike_at_one(term: dict) -> float:
    m = abs(int(term["m"]))
    order = (int(term["l"]) - m) // 2
    return (-1.0 if order % 2 else 1.0) * _jacobi(order, m, 0, -1.0)


def _terms(group, name: str):
    basis = group[f"_{name}_basis"]
    modes = basis["_modes"][()]
    values = group[f"_{name}_lmn"][()]
    return [{"l": int(mode[0]), "m": int(mode[1]), "n": int(mode[2]), "coefficient_m": float(value)}
            for mode, value in zip(modes, values, strict=True)]


def _trimmed_profile(group, tolerance: float):
    modes = group["_basis"]["_modes"][()]
    values = group["_params"][()]
    if any(len(mode) != 3 or int(mode[1]) != 0 or int(mode[2]) != 0 for mode in modes):
        raise ValueError("profile contains non-radial modes")
    kept = {int(mode[0]): float(value) for mode, value in zip(modes, values, strict=True)
            if abs(float(value)) > tolerance}
    if not kept:
        raise ValueError("profile has no significant coefficients")
    return [kept.get(power, 0.0) for power in range(max(kept) + 1)]


def validate(source_path: Path, normalized_path: Path, interior_path: Path) -> dict:
    manifest = json.loads(source_path.read_text(encoding="utf-8"))
    normalized = json.loads(normalized_path.read_text(encoding="utf-8"))
    interior = json.loads(interior_path.read_text(encoding="utf-8"))
    source = source_path.parent / manifest["artifact"]["path"]
    source_hash = file_sha(source)
    if source_hash != manifest["artifact"]["sha256"]:
        raise ValueError("source artifact hash mismatch")
    if normalized["subject_canonical_json"] != canonical_bytes(normalized["subject"]).decode():
        raise ValueError("normalized canonical wire mismatch")
    if normalized["subject_hash"] != hashlib.sha256(normalized["subject_canonical_json"].encode()).hexdigest():
        raise ValueError("normalized subject hash mismatch")
    if interior["subject_canonical_json"] != canonical_bytes(interior["subject"]).decode():
        raise ValueError("interior canonical wire mismatch")
    if interior["subject_hash"] != hashlib.sha256(interior["subject_canonical_json"].encode()).hexdigest():
        raise ValueError("interior subject hash mismatch")
    for label, record in (("normalized", normalized), ("interior", interior)):
        authority = record.get("authority", {})
        if (authority.get("physical_validation") != "unsupported" or
                authority.get("independent_solver") is not False or
                authority.get("measurement") is not False or
                authority.get("credible_device_count") != 0):
            raise ValueError(f"{label} input authority exceeds source-only scope")
    with h5py.File(source, "r") as stream:
        family = stream["_equilibria"]
        indices = sorted(int(k) for k in family if k.isdigit())
        selected = int(manifest["artifact"]["selected_equilibrium_index"])
        if indices != list(range(len(indices))) or len(indices) != 4 or selected != 3:
            raise ValueError("equilibrium family/member selection mismatch")
        member = family[str(selected)]
        version = _text(stream["__version__"][()])
        if version != manifest["artifact"]["embedded_producer_version"]:
            raise ValueError("embedded producer version mismatch")
        resolution = {key: int(member[f"_{key}"][()]) for key in ("L", "M", "N", "NFP")}
        if resolution != {"L": 24, "M": 12, "N": 3, "NFP": 19}:
            raise ValueError("selected member resolution mismatch")
        if interior["subject"].get("source_resolution") != resolution:
            raise ValueError("interior source resolution differs from raw HDF5")
        if normalized["subject"].get("field_periods") != resolution["NFP"]:
            raise ValueError("normalized field periods differ from raw HDF5")
        for key in ("R", "Z"):
            if _text(member[f"_{key}_basis"]["__class__"][()]) != "desc.basis.FourierZernikeBasis":
                raise ValueError(f"{key} basis class mismatch")
            basis = member[f"_{key}_basis"]
            expected_symmetry = "cos" if key == "R" else "sin"
            if (_text(basis["_sym"][()]) != expected_symmetry or
                    _text(basis["_spectral_indexing"][()]) != "fringe"):
                raise ValueError(f"{key} basis symmetry/indexing mismatch")
        if _text(member["__version__"][()]) != manifest["artifact"]["embedded_producer_version"]:
            raise ValueError("selected member embedded version mismatch")
        raw_interior = {name: _terms(member, name) for name in ("R", "Z")}
        subject_i = interior["subject"]
        for name in ("R", "Z"):
            if raw_interior[name] != subject_i[name]["terms"]:
                raise ValueError(f"interior {name} terms differ from raw HDF5")
        surface = member["_surface"]
        if int(surface["_rho"][()]) != 1 or int(surface["_NFP"][()]) != 19:
            raise ValueError("raw _surface rho/NFP mismatch")
        if _text(surface["__version__"][()]) != manifest["artifact"]["embedded_producer_version"]:
            raise ValueError("raw _surface embedded version mismatch")
        maxima = {}
        all_magnitudes = []
        aggregate_sums = []
        max_terms_per_sum = 0
        for name, key in (("R", "radial_modes"), ("Z", "vertical_modes")):
            raw_surface = _terms(surface, name)
            surface_basis = surface[f"_{name}_basis"]
            expected_symmetry = "cos" if name == "R" else "sin"
            if (_text(surface_basis["_sym"][()]) != expected_symmetry or
                    _text(surface_basis["_spectral_indexing"][()]) != "linear"):
                raise ValueError(f"surface {name} basis symmetry/indexing mismatch")
            all_magnitudes.extend(abs(t["coefficient_m"]) for t in raw_surface)
            raw_kept = {(t["m"], t["n"]): t["coefficient_m"] for t in raw_surface if abs(t["coefficient_m"]) > TOLERANCE}
            normalized_modes = {(int(t["m"]), int(t["n"])): float(t["coefficient_m"]) for t in normalized["subject"]["boundary"][key]}
            if raw_kept.keys() != normalized_modes.keys():
                raise ValueError(f"boundary {name} mode set differs from raw _surface")
            maxima[f"boundary_{name}_raw_vs_normalized_m"] = max(abs(raw_kept[k] - normalized_modes[k]) for k in raw_kept) if raw_kept else 0.0
            aggregate = {}
            contributions = {}
            for term in raw_interior[name]:
                k = (term["m"], term["n"])
                contribution = term["coefficient_m"] * _zernike_at_one(term)
                aggregate[k] = aggregate.get(k, 0.0) + contribution
                contributions.setdefault(k, []).append(contribution)
            max_terms_per_sum = max(max_terms_per_sum, *(len(v) for v in contributions.values()))
            aggregate_sums.extend(sum(abs(v) for v in values) for values in contributions.values())
            surface_all = {(t["m"], t["n"]): t["coefficient_m"] for t in raw_surface}
            union = set(aggregate) | set(surface_all) | set(normalized_modes)
            maxima[f"rho1_{name}_interior_vs_raw_surface_m"] = max(abs(aggregate.get(k, 0.0) - surface_all.get(k, 0.0)) for k in union)
            maxima[f"rho1_{name}_interior_vs_normalized_boundary_union_m"] = max(abs(aggregate.get(k, 0.0) - normalized_modes.get(k, 0.0)) for k in union)
        all_magnitudes.extend(abs(float(t["coefficient_m"])) for name in ("R", "Z") for t in raw_interior[name])
        all_magnitudes.extend(abs(float(t["coefficient_m"])) for name, key in (("R", "radial_modes"), ("Z", "vertical_modes")) for t in normalized["subject"]["boundary"][key])
        scale = max(1.0, *all_magnitudes)
        gamma = (max_terms_per_sum * math.ulp(1.0)) / (1.0 - max_terms_per_sum * math.ulp(1.0))
        budget = max(32.0 * math.ulp(1.0) * scale, gamma * max(aggregate_sums, default=scale))
        if any(value > budget for key, value in maxima.items() if key.startswith("boundary_")):
            raise ValueError("raw _surface comparison exceeds explicit roundoff budget")
        if any(value > budget for key, value in maxima.items() if key.startswith("rho1_")):
            raise ValueError("rho=1 interior aggregation exceeds numerical join tolerance")
        subject_n = normalized["subject"]
        if subject_n["source_artifact_sha256"] != source_hash or subject_i["source_artifact_sha256"] != source_hash:
            raise ValueError("derived subjects do not name the raw artifact")
        if subject_n["provenance"]["selected_equilibrium_index"] != selected:
            raise ValueError("normalized selected member mismatch")
        for name, key in (("_pressure", "pressure_profile"), ("_iota", "rotational_or_current_profile")):
            raw = _trimmed_profile(member[name], TOLERANCE)
            derived = [float(value) for value in normalized["subject"][key]["coefficients_by_power"]]
            if raw != derived:
                raise ValueError(f"{name} profile differs from raw HDF5")
        if abs(float(member["_Psi"][()]) - float(normalized["subject"]["toroidal_flux"]["value"])) > 0.0:
            raise ValueError("toroidal flux differs from raw HDF5")
    return {"schema_version": "n2-desc-heliotron-member-join-v1", "status": "screen_only_raw_member_join_verified",
            "source_artifact_sha256": source_hash, "source_json_sha256": file_sha(source_path),
            "validator_script_sha256": file_sha(Path(__file__)),
            "normalized_result_sha256": file_sha(normalized_path), "interior_result_sha256": file_sha(interior_path),
            "selected_equilibrium_index": 3, "equilibrium_count": 4, "resolution": {"L": 24, "M": 12, "N": 3, "NFP": 19},
            "numerical_join_tolerance_m": budget,
            "join_tolerance_basis": "max(32*eps*max_coefficient, gamma_n*max_sum_abs_aggregation); numerical join tolerance, not rigorous proof",
            "maximum_aggregation_terms": max_terms_per_sum, "numeric_maxima_m": maxima,
            "gap_flags": ["independent_physical_validation_missing", "independent_solver_missing", "measurement_missing"],
            "authority": {"claim_ceiling": "screen_only", "geometry_proved": False, "physical_validation": "unsupported", "measurement": False, "inverse_ready": False, "credible_device_count": 0}}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--normalized", type=Path, default=DEFAULT_NORMALIZED)
    parser.add_argument("--interior", type=Path, default=DEFAULT_INTERIOR)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit("refusing to overwrite existing output")
    result = validate(args.source, args.normalized, args.interior)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        raise SystemExit("refusing to overwrite existing output")
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"N2_MEMBER_JOIN_OUTPUT={args.output.resolve()}")
    print("N2_MEMBER_JOIN_STATUS=screen_only_raw_member_join_verified")
    print("N2_PHYSICAL_VALIDATION=unsupported")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
