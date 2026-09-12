"""Normalize one hash-bound DESC equilibrium into a label-neutral N2 subject.

The HDF5 is an external simulation artifact.  Loading and normalization do not
turn it into measurement evidence, an independent solver comparison, or an
inverse-recovery result.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent
DEFAULT_SOURCE = ROOT / "source.json"


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False).encode("utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def subject_hash(record: dict) -> str:
    """Hash physics-bearing fields only; display labels cannot affect routing."""
    return hashlib.sha256(canonical_bytes(record["subject"])).hexdigest()


def _trimmed_profile(profile, tolerance: float, quantity: str, unit: str) -> dict:
    modes = profile.basis.modes.tolist()
    params = profile.params.tolist()
    pairs: list[tuple[int, float]] = []
    discarded = 0.0
    for mode, value in zip(modes, params, strict=True):
        if len(mode) != 3 or mode[1:] != [0, 0]:
            raise ValueError(f"{quantity} profile contains a non-radial mode")
        exponent = int(mode[0])
        number = float(value)
        if not math.isfinite(number) or exponent < 0:
            raise ValueError(f"{quantity} profile contains an invalid coefficient")
        if abs(number) > tolerance:
            pairs.append((exponent, number))
        else:
            discarded = max(discarded, abs(number))
    if not pairs:
        raise ValueError(f"{quantity} profile has no significant coefficients")
    largest = max(exponent for exponent, _ in pairs)
    dense = [0.0] * (largest + 1)
    for exponent, number in pairs:
        dense[exponent] = number
    return {
        "quantity": quantity,
        "unit": unit,
        "basis": "power_series_in_rho",
        "radial_domain": [0.0, 1.0],
        "coefficients_by_power": dense,
        "maximum_discarded_coefficient": discarded,
    }


def _trimmed_boundary(surface, tolerance: float) -> dict:
    def component(modes, values, name):
        kept = []
        discarded = 0.0
        for mode, value in zip(modes.tolist(), values.tolist(), strict=True):
            if len(mode) != 3 or int(mode[0]) != 0:
                raise ValueError(f"{name} boundary contains a non-surface mode")
            number = float(value)
            if not math.isfinite(number):
                raise ValueError(f"{name} boundary contains a non-finite coefficient")
            if abs(number) > tolerance:
                kept.append({"m": int(mode[1]), "n": int(mode[2]),
                             "coefficient_m": number})
            else:
                discarded = max(discarded, abs(number))
        kept.sort(key=lambda row: (row["n"], row["m"]))
        return kept, discarded

    radial, radial_discarded = component(surface.R_basis.modes,
                                          surface.R_lmn, "R")
    vertical, vertical_discarded = component(surface.Z_basis.modes,
                                              surface.Z_lmn, "Z")
    return {
        "coordinate_system": "cylindrical_R_phi_Z",
        "coefficient_unit": "m",
        "radial_modes": radial,
        "vertical_modes": vertical,
        "maximum_discarded_coefficient_m": max(radial_discarded,
                                                 vertical_discarded),
    }


def normalize(source_path: Path = DEFAULT_SOURCE) -> dict:
    source_path = source_path.resolve()
    manifest = json.loads(source_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "n2-external-equilibrium-source-v1":
        raise ValueError("unsupported source manifest schema")
    artifact = source_path.parent / manifest["artifact"]["path"]
    if not artifact.is_file():
        raise ValueError("source artifact is missing")
    actual_hash = sha256_file(artifact)
    if actual_hash != manifest["artifact"]["sha256"]:
        raise ValueError("source artifact hash mismatch")
    if artifact.stat().st_size != manifest["artifact"]["bytes"]:
        raise ValueError("source artifact byte count mismatch")

    import desc
    import desc.io
    from desc.equilibrium import EquilibriaFamily

    if desc.__version__ != manifest["artifact"]["producer_version"]:
        raise ValueError("DESC producer version mismatch")
    loaded = desc.io.load(artifact)
    equilibrium = loaded[-1] if isinstance(loaded, EquilibriaFamily) else loaded
    if equilibrium.pressure is None:
        raise ValueError("source equilibrium has no pressure profile")
    if (equilibrium.iota is None) == (equilibrium.current is None):
        raise ValueError("source equilibrium must own exactly one iota/current profile")

    tolerance = float(manifest["normalization"]["coefficient_zero_tolerance"])
    rotational = (_trimmed_profile(equilibrium.iota, tolerance, "iota", "1")
                  if equilibrium.iota is not None else
                  _trimmed_profile(equilibrium.current, tolerance,
                                   "current", "A"))
    surface = equilibrium.get_surface_at(rho=1)
    subject = {
        "schema_version": "n2-label-neutral-equilibrium-subject-v1",
        "source_class": manifest["source_class"],
        "source_artifact_sha256": actual_hash,
        "producer": {
            "name": manifest["artifact"]["producer"],
            "version": desc.__version__,
            "source_tag_commit": manifest["artifact"]["source_tag_commit"],
        },
        "equilibrium_scope": "fixed_boundary_static_ideal_mhd",
        "field_periods": int(equilibrium.NFP),
        "stellarator_symmetric": bool(equilibrium.sym),
        "toroidal_flux": {"value": float(equilibrium.Psi), "unit": "Wb"},
        "boundary": _trimmed_boundary(surface, tolerance),
        "pressure_profile": _trimmed_profile(equilibrium.pressure, tolerance,
                                               "pressure", "Pa"),
        "rotational_or_current_profile": rotational,
        "source_resolution": {
            "L": int(equilibrium.L), "M": int(equilibrium.M),
            "N": int(equilibrium.N), "L_grid": int(equilibrium.L_grid),
            "M_grid": int(equilibrium.M_grid),
            "N_grid": int(equilibrium.N_grid),
        },
    }
    result = {
        "schema_version": "n2-normalized-reference-v1",
        "reference": {
            "reference_id": manifest["reference_id"],
            "display_name": manifest["display_name"],
            "source_url": manifest["artifact"]["url"],
            "license": manifest["source"]["license"],
        },
        "subject": subject,
        "subject_hash": hashlib.sha256(canonical_bytes(subject)).hexdigest(),
        "normalization": copy.deepcopy(manifest["normalization"]),
        "authority": copy.deepcopy(manifest["authority"]),
        "status": "normalized_external_simulation_input",
        "remaining_gaps": [
            "typed_RuntimeV4_subject_binding",
            "fresh_same_subject_DESC_reexecution",
            "independent_spatial_mapping_and_comparison",
            "genuine_hidden_parameter_inverse",
            "independent_held_out_prediction",
            "experimental_validation",
        ],
    }
    validate_normalized(result, expected_source_hash=actual_hash)
    return result


def _poly(coefficients: list[float], rho: float) -> float:
    return sum(value * rho ** power
               for power, value in enumerate(coefficients))


def validate_normalized(record: dict, *, expected_source_hash: str | None = None) -> None:
    if record.get("schema_version") != "n2-normalized-reference-v1":
        raise ValueError("unsupported normalized schema")
    subject = record.get("subject", {})
    if record.get("subject_hash") != hashlib.sha256(canonical_bytes(subject)).hexdigest():
        raise ValueError("normalized subject hash mismatch")
    if expected_source_hash is not None and subject.get("source_artifact_sha256") != expected_source_hash:
        raise ValueError("normalized source hash mismatch")
    if subject.get("source_class") != "external_simulation":
        raise ValueError("source class cannot be promoted or relabeled")
    authority = record.get("authority", {})
    if (authority.get("physical_validation") != "unsupported" or
            authority.get("independent_solver") is not False or
            authority.get("measurement") is not False or
            authority.get("inversion_ready") is not False or
            authority.get("held_out_prediction_ready") is not False or
            authority.get("credible_device_count") != 0):
        raise ValueError("normalized authority ceiling exceeded")
    pressure = subject.get("pressure_profile", {})
    rotational = subject.get("rotational_or_current_profile", {})
    if pressure.get("quantity") != "pressure" or pressure.get("unit") != "Pa":
        raise ValueError("pressure profile ownership or unit mismatch")
    if rotational.get("quantity") not in {"iota", "current"}:
        raise ValueError("exactly one iota/current profile is required")
    if rotational.get("unit") != ("1" if rotational["quantity"] == "iota" else "A"):
        raise ValueError("rotational/current profile unit mismatch")
    coefficients = pressure.get("coefficients_by_power", [])
    if not coefficients or not all(math.isfinite(float(value)) for value in coefficients):
        raise ValueError("pressure coefficients are missing or non-finite")
    samples = [_poly(coefficients, index / 100.0) for index in range(101)]
    scale = max(abs(value) for value in samples)
    if min(samples) < -1e-10 * max(scale, 1.0) or abs(samples[-1]) > 1e-10 * max(scale, 1.0):
        raise ValueError("pressure profile is negative or not closed at rho=1")
    flux = subject.get("toroidal_flux", {})
    if flux.get("unit") != "Wb" or not math.isfinite(float(flux.get("value", math.nan))):
        raise ValueError("toroidal flux is missing or invalid")
    boundary = subject.get("boundary", {})
    radial = boundary.get("radial_modes", [])
    if len([row for row in radial if row.get("m") == 0 and row.get("n") == 0
            and row.get("coefficient_m", 0) > 0]) != 1:
        raise ValueError("boundary lacks one positive major-radius mode")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--validate-output", type=Path)
    args = parser.parse_args()
    if args.validate_output:
        record = json.loads(args.validate_output.read_text(encoding="utf-8"))
        validate_normalized(record)
        print("N2_NORMALIZED_REFERENCE_VALID=1")
        return 0
    if args.output is None:
        parser.error("output is required unless --validate-output is used")
    result = normalize(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"N2_NORMALIZED_REFERENCE_OUTPUT={args.output.resolve()}")
    print(f"N2_SUBJECT_HASH={result['subject_hash']}")
    print("N2_PHYSICAL_VALIDATION=unsupported")
    print("N2_INVERSION_READY=0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
