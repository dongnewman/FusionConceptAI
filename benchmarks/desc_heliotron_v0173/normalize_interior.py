"""Freeze the complete selected DESC Fourier-Zernike interior without fitting.

This is an external-simulation representation artifact, not an interpreter,
provider receipt, independent solver comparison, or physical validation.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import h5py
import numpy as np

from normalize_reference import (DEFAULT_SOURCE, _decode_hdf5_scalar,
                                 _embedded_metadata, canonical_bytes,
                                 sha256_file)


def _component(group, name: str, resolution: dict) -> dict:
    basis = group[f"_{name}_basis"]
    values = np.asarray(group[f"_{name}_lmn"][()])
    modes = np.asarray(basis["_modes"][()])
    if values.ndim != 1 or modes.shape != (len(values), 3):
        raise ValueError(f"{name} Fourier-Zernike shape mismatch")
    if not np.issubdtype(modes.dtype, np.integer) or not np.all(np.isfinite(values)):
        raise ValueError(f"{name} Fourier-Zernike modes or values invalid")
    if len(set(tuple(int(x) for x in mode) for mode in modes)) != len(modes):
        raise ValueError(f"{name} Fourier-Zernike (l,m,n) mode duplicate")
    basis_name = _decode_hdf5_scalar(basis["__class__"][()])
    symmetry = _decode_hdf5_scalar(basis["_sym"][()])
    indexing = _decode_hdf5_scalar(basis["_spectral_indexing"][()])
    if (basis_name != "desc.basis.FourierZernikeBasis" or
            symmetry != ("cos" if name == "R" else "sin") or
            indexing != "fringe"):
        raise ValueError(f"{name} Fourier-Zernike basis convention mismatch")
    for key in ("L", "M", "N", "NFP"):
        if int(basis[f"_{key}"][()]) != resolution[key]:
            raise ValueError(f"{name} basis resolution or period mismatch")
    terms = [{"l": int(mode[0]), "m": int(mode[1]), "n": int(mode[2]),
              "coefficient_m": float(value)}
             for mode, value in zip(modes, values, strict=True)]
    if any(not math.isfinite(term["coefficient_m"]) for term in terms):
        raise ValueError(f"{name} non-finite Fourier-Zernike coefficient")
    return {
        "basis_class": basis_name,
        "spectral_indexing": indexing,
        "symmetry": symmetry,
        "coefficient_unit": "m",
        "mode_order": "HDF5 stored order; each tuple is (l,m,n)",
        "radial_degree_semantics": "DESC Fourier-Zernike radial basis degree; not rho^l",
        "coefficient_count": len(terms),
        "terms": terms,
    }


def normalize_interior(source_path: Path = DEFAULT_SOURCE) -> dict:
    source_path = source_path.resolve()
    manifest = json.loads(source_path.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != "n2-external-equilibrium-source-v1":
        raise ValueError("unsupported source manifest schema")
    artifact = source_path.parent / manifest["artifact"]["path"]
    if not artifact.is_file():
        raise ValueError("source artifact is missing")
    source_hash = sha256_file(artifact)
    if source_hash != manifest["artifact"]["sha256"]:
        raise ValueError("source artifact hash mismatch")
    if artifact.stat().st_size != manifest["artifact"]["bytes"]:
        raise ValueError("source artifact byte count mismatch")
    embedded = _embedded_metadata(artifact, manifest)
    index = embedded["selected_equilibrium_index"]
    with h5py.File(artifact, "r") as stream:
        group = stream["_equilibria"][str(index)]
        resolution = {key: int(group[f"_{key}"][()])
                      for key in ("L", "M", "N", "NFP")}
        subject = {
            "schema_version": "n2-source-owned-interior-subject-v1",
            "source_class": "external_simulation",
            "source_artifact_sha256": source_hash,
            "selected_equilibrium_index": index,
            "equilibrium_count": embedded["equilibrium_count"],
            "embedded_producer_version": embedded["container_embedded_version"],
            "distribution_tag": manifest["artifact"]["distributed_in_release_tag"],
            "source_resolution": resolution,
            "coordinate_semantics": {
                "radial_coordinate": "rho=sqrt(psi/psi_boundary)",
                "angular_basis": "DESC stored FourierZernikeBasis; phase/sign requires independently checked evaluator",
                "scope": "selected solved-equilibrium interior R/Z spectral coefficients",
            },
            "R": _component(group, "R", resolution),
            "Z": _component(group, "Z", resolution),
        }
    wire = canonical_bytes(subject).decode("utf-8")
    result = {
        "schema_version": "n2-source-owned-interior-result-v1",
        "subject": subject,
        "subject_canonical_json": wire,
        "subject_hash": hashlib.sha256(wire.encode("utf-8")).hexdigest(),
        "authority": {
            "evidence_authority": "external_simulation_input_only",
            "physical_validation": "unsupported",
            "independent_solver": False,
            "measurement": False,
            "inverse_ready": False,
            "held_out_prediction_ready": False,
            "credible_device_count": 0,
        },
        "status": "source_interior_spectral_representation_only",
        "remaining_gaps": [
            "typed_FourierZernike_basis_and_exact_evaluator",
            "independent_phase_and_derivative_convention_checks",
            "candidate_owned_coordinate_metric_program_binding",
            "NFP19_and_resolution_contract_admission",
            "provider_reexecution_and_independent_spatial_comparison",
        ],
    }
    validate_interior(result, expected_source_hash=source_hash)
    return result


def validate_interior(result: dict, *, expected_source_hash: str | None = None) -> None:
    if result.get("schema_version") != "n2-source-owned-interior-result-v1":
        raise ValueError("interior result schema mismatch")
    subject = result.get("subject", {})
    wire = result.get("subject_canonical_json")
    if not isinstance(wire, str) or wire != canonical_bytes(subject).decode("utf-8"):
        raise ValueError("interior canonical subject wire mismatch")
    if result.get("subject_hash") != hashlib.sha256(wire.encode("utf-8")).hexdigest():
        raise ValueError("interior subject hash mismatch")
    if expected_source_hash is not None and subject.get("source_artifact_sha256") != expected_source_hash:
        raise ValueError("interior source artifact hash mismatch")
    if (subject.get("source_class") != "external_simulation" or
            subject.get("selected_equilibrium_index") != 3 or
            subject.get("equilibrium_count") != 4 or
            subject.get("source_resolution") != {"L": 24, "M": 12, "N": 3, "NFP": 19}):
        raise ValueError("interior selected-member identity mismatch")
    for name, count, symmetry in (("R", 598, "cos"), ("Z", 585, "sin")):
        component = subject.get(name, {})
        terms = component.get("terms", [])
        if (component.get("basis_class") != "desc.basis.FourierZernikeBasis" or
                component.get("spectral_indexing") != "fringe" or
                component.get("symmetry") != symmetry or
                component.get("coefficient_unit") != "m" or
                component.get("coefficient_count") != count or len(terms) != count):
            raise ValueError(f"{name} interior basis contract mismatch")
        keys = [(term["l"], term["m"], term["n"]) for term in terms]
        if len(set(keys)) != count or any(
                not math.isfinite(float(term["coefficient_m"])) for term in terms):
            raise ValueError(f"{name} interior mode identity or coefficient invalid")
    authority = result.get("authority", {})
    if (authority.get("evidence_authority") != "external_simulation_input_only" or
            authority.get("physical_validation") != "unsupported" or
            authority.get("independent_solver") is not False or
            authority.get("measurement") is not False or
            authority.get("inverse_ready") is not False or
            authority.get("held_out_prediction_ready") is not False or
            authority.get("credible_device_count") != 0):
        raise ValueError("interior authority ceiling exceeded")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--validate-output", type=Path)
    args = parser.parse_args()
    if args.validate_output:
        validate_interior(json.loads(args.validate_output.read_text(encoding="utf-8")))
        print("N2_INTERIOR_REPRESENTATION_VALID=1")
        return 0
    if args.output is None:
        parser.error("output is required unless --validate-output is used")
    result = normalize_interior(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(f"N2_INTERIOR_OUTPUT={args.output.resolve()}")
    print(f"N2_INTERIOR_SUBJECT_HASH={result['subject_hash']}")
    print("N2_INTERIOR_EVALUATOR=absent")
    print("N2_PHYSICAL_VALIDATION=unsupported")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
