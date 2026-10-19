"""Fail-closed validator for the UP4-03 reference-data preparation package.

The checker is intentionally stdlib-only.  It verifies provenance bytes, Zarr
schema/units, a distinct-shot split, and the absence of a fabricated inverse.
It does not decode or solve the scientific model and cannot grant B07B credit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST = Path(__file__).with_name("reference_manifest.json")
PROTOCOL = Path(__file__).with_name("inverse_protocol.json")
REQUIRED_ARRAYS = {
    "thomson_scattering/n_e": {"units": "1 / m ** 3", "dims": ["major_radius", "time"]},
    "thomson_scattering/t_e": {"units": "eV", "dims": ["major_radius", "time"]},
    "thomson_scattering/major_radius": {"units": "m", "dims": ["major_radius"]},
    "thomson_scattering/time": {"units": "s", "dims": ["time"]},
}


class ValidationError(ValueError):
    pass


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def _load(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - message is part of the receipt
        raise ValidationError(f"invalid JSON {path}: {exc}") from exc
    _require(isinstance(value, dict), f"JSON object required: {path}")
    return value


def _raw_entry(ref: dict[str, Any], kind: str) -> dict[str, Any]:
    matches = [x for x in ref.get("raw_files", []) if x.get("kind") == kind]
    _require(len(matches) == 1, f"{ref.get('reference_id')}: expected one raw file kind {kind}")
    return matches[0]


def validate_raw_files(ref: dict[str, Any], root: Path = ROOT) -> dict[str, Any]:
    _require(ref.get("raw_data_obtained") is True, f"{ref.get('reference_id')}: raw_data_obtained must be true for acquired refs")
    hashes: dict[str, str] = {}
    for item in ref.get("raw_files", []):
        rel = item.get("path")
        _require(isinstance(rel, str) and rel.startswith("raw/"), f"{ref.get('reference_id')}: raw path outside raw/: {rel}")
        path = root / "benchmarks" / "reference_data_v2" / rel
        _require(path.is_file(), f"{ref.get('reference_id')}: missing raw file {rel}")
        actual = sha256(path)
        _require(actual == item.get("sha256"), f"{ref.get('reference_id')}: sha256 mismatch {rel}")
        _require(path.stat().st_size == item.get("bytes"), f"{ref.get('reference_id')}: byte count mismatch {rel}")
        _require(item.get("url", "").startswith("https://"), f"{ref.get('reference_id')}: first-party URL missing {rel}")
        hashes[rel] = actual
    return hashes


def validate_zarr_schema(ref: dict[str, Any], root: Path = ROOT) -> dict[str, Any]:
    schema_entry = _raw_entry(ref, "zarr_v3_consolidated_schema")
    schema_path = root / "benchmarks" / "reference_data_v2" / schema_entry["path"]
    schema = _load(schema_path)
    _require(schema.get("zarr_format") == 3, f"{ref['reference_id']}: expected Zarr v3")
    metadata = schema.get("consolidated_metadata", {}).get("metadata", {})
    _require(isinstance(metadata, dict), f"{ref['reference_id']}: missing consolidated metadata")
    declared = ref.get("raw_schema", {}).get("arrays", {})
    out: dict[str, Any] = {}
    for array_name, expected in REQUIRED_ARRAYS.items():
        node = metadata.get(array_name)
        _require(isinstance(node, dict) and node.get("node_type") == "array", f"{ref['reference_id']}: missing array {array_name}")
        attrs = node.get("attributes", {})
        units = attrs.get("units")
        dims = node.get("dimension_names")
        _require(units == expected["units"], f"{ref['reference_id']}: raw unit mismatch {array_name}: {units!r}")
        _require(dims == expected["dims"], f"{ref['reference_id']}: dimensions mismatch {array_name}: {dims!r}")
        _require(node.get("data_type") == "float64", f"{ref['reference_id']}: data type mismatch {array_name}")
        _require(all(isinstance(n, int) and n > 0 for n in node.get("shape", [])), f"{ref['reference_id']}: empty shape {array_name}")
        _require(declared.get(array_name, {}).get("units") == units, f"{ref['reference_id']}: manifest/schema unit disagreement {array_name}")
        out[array_name] = {"shape": node["shape"], "units": units, "dims": dims}
    _require(ref.get("raw_schema", {}).get("measurement_uncertainty", {}).get("status") == "typed_absent", f"{ref['reference_id']}: uncertainty status must remain typed_absent")
    # Metadata alone is not an observation.  Every required array must have a
    # non-empty chunk whose kind is tied to that array.
    for array_name in REQUIRED_ARRAYS:
        kind = "zarr_v3_chunk_" + array_name.replace("/", "_")
        chunk = _raw_entry(ref, kind)
        path = root / "benchmarks" / "reference_data_v2" / chunk["path"]
        _require(path.stat().st_size > 0, f"{ref['reference_id']}: empty raw chunk {array_name}")
    return out


def validate_shot_metadata(ref: dict[str, Any], root: Path = ROOT) -> None:
    metadata = _load(root / "benchmarks" / "reference_data_v2" / _raw_entry(ref, "shot_metadata_json")["path"])
    _require(metadata.get("shot_id") == ref.get("shot_id"), f"{ref['reference_id']}: shot metadata id mismatch")
    _require(metadata.get("url", "").startswith("s3://mast/"), f"{ref['reference_id']}: unexpected source URL")


def _validate_observation_split(split: dict[str, Any], label: str) -> None:
    groups = {
        "calibration": set(split.get("calibration_observation_ids", [])),
        "validation": set(split.get("validation_observation_ids", [])),
        "held_out": set(split.get("held_out_observation_ids", [])),
    }
    for left, left_ids in groups.items():
        for right, right_ids in groups.items():
            if left >= right:
                continue
            _require(not (left_ids & right_ids), f"{label}: observation ID leakage {left}∩{right}")


def validate_manifest(manifest: dict[str, Any], protocol: dict[str, Any] | None = None, root: Path = ROOT) -> dict[str, Any]:
    _require(manifest.get("schema_version") == "reference_manifest_v2", "schema_version")
    _require(manifest.get("claim_ceiling") == "prepared_not_executed; no formal inverse, B07B, physical validation, or parent UP4-03 acceptance", "claim ceiling was broadened")
    refs = manifest.get("references")
    _require(isinstance(refs, list) and refs, "references missing")
    ids = {r.get("reference_id") for r in refs}
    _require(len(ids) == len(refs), "duplicate reference_id")
    # Only the newly acquired measurement package has raw/** entries.  The
    # frozen DESC simulation artifact is intentionally referenced, not copied
    # into this preparation directory, and therefore is validated by its own
    # source manifest rather than by this checker.
    acquired = [r for r in refs if r.get("raw_data_obtained") is True and r.get("evidence_class") == "measurement"]
    reports = []
    for ref in acquired:
        _require(ref.get("source", {}).get("accessed_at_utc"), f"{ref.get('reference_id')}: access time missing")
        hashes = validate_raw_files(ref, root)
        schema = validate_zarr_schema(ref, root)
        validate_shot_metadata(ref, root)
        mismatch = ref.get("catalog_vs_raw_identity_mismatch", {})
        _require(mismatch.get("root_cause_status") == "unproven", f"{ref['reference_id']}: catalog/raw mismatch root cause must remain unproven")
        _require(str(mismatch.get("normalization", "")).startswith("none_declared"), f"{ref['reference_id']}: catalog/raw mismatch cannot claim normalization")
        reports.append({"reference_id": ref["reference_id"], "raw_files": len(hashes), "arrays": schema})
    split = manifest.get("split_protocol", {})
    cal = set(split.get("calibration_shot_ids", [])); val = set(split.get("validation_shot_ids", [])); hold = set(split.get("held_out_shot_ids", []))
    _require(not (cal & val or cal & hold or val & hold), "shot split leakage")
    _validate_observation_split(split, "manifest split")
    _require(split.get("intersection_check") == "zero", "split intersection receipt is not zero")
    _require(30421 in cal and 30420 in hold, "required independent MAST shot split is missing")
    mast = [r for r in acquired if r.get("device_name") == "MAST"]
    _require(len(mast) >= 2, "both calibration and held-out MAST raw references are required")
    ne_hashes = [_raw_entry(r, "zarr_v3_chunk_thomson_scattering_n_e")["sha256"] for r in mast]
    te_hashes = [_raw_entry(r, "zarr_v3_chunk_thomson_scattering_t_e")["sha256"] for r in mast]
    _require(len(set(ne_hashes)) == len(ne_hashes), "n_e held-out chunk is an anchor copy")
    _require(len(set(te_hashes)) == len(te_hashes), "t_e held-out chunk is an anchor copy")
    if protocol is not None:
        _require(protocol.get("schema_version") == "inverse_protocol_v2", "inverse protocol schema_version")
        expected_manifest_hash = protocol.get("manifest", {}).get("sha256")
        _require(expected_manifest_hash == sha256(MANIFEST), "inverse protocol manifest hash mismatch")
        _require(protocol.get("status") == "frozen_preparation_not_executed", "inverse protocol executed/rewritten")
        starts = protocol.get("multi_start", {}).get("starts", [])
        _require(len(starts) >= 8 and protocol.get("multi_start", {}).get("required_count") == 8, "at least eight multi-starts must be frozen")
        _require(protocol.get("split", {}).get("candidate_independent") is True, "candidate-independent split missing")
        _require(protocol.get("formal_execution", {}).get("status") == "not_executed", "formal execution cannot be claimed")
        protocol_split = protocol.get("split", {})
        _validate_observation_split({
            "calibration_observation_ids": protocol_split.get("calibration", {}).get("observation_ids", []),
            "validation_observation_ids": protocol_split.get("validation", {}).get("observation_ids", []),
            "held_out_observation_ids": protocol_split.get("blind_held_out", {}).get("observation_ids", []),
        }, "protocol split")
        mismatch = protocol.get("observation_model", {}).get("catalog_vs_raw_identity_mismatch", {})
        _require(mismatch.get("root_cause_status") == "unproven", "protocol catalog/raw mismatch root cause must remain unproven")
        _require(mismatch.get("normalization") == "none_declared", "protocol catalog/raw mismatch cannot claim normalization")
        layers = {x.get("genome_layer") for r in refs for x in r.get("theta_to_genome_mapping", [])}
        _require({"G1", "G2", "G3"}.issubset(layers), "G1/G2/G3 theta mapping incomplete")
    return {"status": "pass", "acquired_references": reports, "formal_inverse": "not_executed", "b07b": "not_claimed"}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, default=MANIFEST)
    parser.add_argument("--protocol", type=Path, default=PROTOCOL)
    args = parser.parse_args(argv)
    try:
        manifest = _load(args.manifest)
        protocol = _load(args.protocol)
        report = validate_manifest(manifest, protocol, ROOT)
    except ValidationError as exc:
        print(json.dumps({"status": "fail", "error": str(exc)}, ensure_ascii=False, sort_keys=True))
        return 2
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
