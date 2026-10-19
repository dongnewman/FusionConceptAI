"""Executable FAIR-MAST Level-2 observation adapter for UP4-03 preparation.

This module reads the immutable ``reference_data_v2`` source package, verifies
every consumed byte against its source manifest, decodes the real Zarr-v3
chunks, and maps each Thomson profile from the raw ``[major_radius, time]``
layout to the canonical ``[time, major_radius]`` layout.

The implemented observation operator is deliberately narrow: it selects
finite samples from a prediction already evaluated on the exact acquired grid.
It is not a calibrated Thomson response model.  The acquired Level-2 profile
contains no bound uncertainty arrays, so weighted likelihood construction is
rejected with a typed error and formal UP4-03/B07B remains deferred.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

import numpy as np


ADAPTER_VERSION = "reference_validation_adapter_v1"
SCHEMA_VERSION = "reference_validation_protocol_v1"
HERE = Path(__file__).resolve().parent
DEFAULT_SOURCE_ROOT = HERE.parent / "reference_data_v2"
DEFAULT_PROTOCOL = HERE / "protocol.json"
DEFAULT_SOURCE_EVIDENCE = HERE / "source_evidence.json"
CANONICAL_DIMENSIONS = ("time", "major_radius")
CHANNEL_CONTRACTS = {
    "n_e": {
        "raw_path": "thomson_scattering/n_e",
        "raw_kind": "zarr_v3_chunk_thomson_scattering_n_e",
        "raw_unit": "1 / m ** 3",
        "canonical_unit": "m^-3",
        "quantity": "electron_density",
    },
    "t_e": {
        "raw_path": "thomson_scattering/t_e",
        "raw_kind": "zarr_v3_chunk_thomson_scattering_t_e",
        "raw_unit": "eV",
        "canonical_unit": "eV",
        "quantity": "electron_temperature",
    },
}
COORDINATE_CONTRACTS = {
    "major_radius": {
        "raw_path": "thomson_scattering/major_radius",
        "raw_kind": "zarr_v3_chunk_thomson_scattering_major_radius",
        "unit": "m",
    },
    "time": {
        "raw_path": "thomson_scattering/time",
        "raw_kind": "zarr_v3_chunk_thomson_scattering_time",
        "unit": "s",
    },
}


class AdapterError(ValueError):
    """Fail-closed adapter error with a stable machine-readable code."""

    def __init__(self, code: str, message: str):
        super().__init__(f"{code}: {message}")
        self.code = code
        self.message = message


def _require(condition: bool, code: str, message: str) -> None:
    if not condition:
        raise AdapterError(code, message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _load_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise AdapterError(code, f"cannot read JSON object {path}: {exc}") from exc
    _require(isinstance(value, dict), code, f"JSON object required: {path}")
    return value


def _readonly_f64(values: Any) -> np.ndarray:
    result = np.ascontiguousarray(values, dtype="<f8")
    result.setflags(write=False)
    return result


def _readonly_bool(values: Any) -> np.ndarray:
    result = np.ascontiguousarray(values, dtype=np.bool_)
    result.setflags(write=False)
    return result


def _plain(value: Any) -> Any:
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, tuple):
        return [_plain(item) for item in value]
    if isinstance(value, list):
        return [_plain(item) for item in value]
    if isinstance(value, dict):
        return {str(key): _plain(item) for key, item in value.items()}
    return value


@dataclass(frozen=True)
class CanonicalObservation:
    """One source shot/channel mapped into the canonical observation layout."""

    record_id: str
    shot_id: int
    channel: str
    split: str
    quantity: str
    raw_dimensions: tuple[str, str]
    raw_shape: tuple[int, int]
    raw_unit: str
    canonical_dimensions: tuple[str, str]
    canonical_shape: tuple[int, int]
    canonical_unit: str
    axis_permutation: tuple[int, int]
    values: np.ndarray
    observed_mask: np.ndarray
    time_s: np.ndarray
    major_radius_m: np.ndarray
    source_response_path: str
    source_response_sha256: str
    source_schema_path: str
    source_schema_sha256: str
    source_time_path: str
    source_time_sha256: str
    source_radius_path: str
    source_radius_sha256: str
    catalog_path: str
    catalog_sha256: str
    catalog_row: Mapping[str, Any]
    catalog_comparison: Mapping[str, Any]
    uncertainty: Mapping[str, Any]
    canonical_payload_sha256: str
    sample_lineage_sha256: str

    @property
    def observed_count(self) -> int:
        return int(self.observed_mask.sum())

    @property
    def missing_count(self) -> int:
        return int(self.observed_mask.size - self.observed_count)

    def manifest_entry(self) -> dict[str, Any]:
        validate_observation_integrity(self)
        finite = self.values[self.observed_mask]
        return {
            "record_id": self.record_id,
            "shot_id": self.shot_id,
            "channel": self.channel,
            "split": self.split,
            "quantity": self.quantity,
            "raw": {
                "dimensions": list(self.raw_dimensions),
                "shape": list(self.raw_shape),
                "unit": self.raw_unit,
                "response_path": self.source_response_path,
                "response_sha256": self.source_response_sha256,
                "schema_path": self.source_schema_path,
                "schema_sha256": self.source_schema_sha256,
                "time_path": self.source_time_path,
                "time_sha256": self.source_time_sha256,
                "major_radius_path": self.source_radius_path,
                "major_radius_sha256": self.source_radius_sha256,
            },
            "mapping": {
                "rule": "canonical[t,r] = raw[r,t]",
                "axis_permutation": list(self.axis_permutation),
                "scale": 1.0,
                "offset": 0.0,
                "resampling": "none",
                "imputation": "none",
                "missingness": "isfinite(raw); NaN retained in canonical values",
            },
            "canonical": {
                "dimensions": list(self.canonical_dimensions),
                "shape": list(self.canonical_shape),
                "unit": self.canonical_unit,
                "dtype": "float64_little_endian",
                "payload_sha256": self.canonical_payload_sha256,
                "sample_lineage_sha256": self.sample_lineage_sha256,
                "observed_count": self.observed_count,
                "missing_count": self.missing_count,
                "finite_min": float(finite.min()),
                "finite_max": float(finite.max()),
                "time_min_s": float(self.time_s[0]),
                "time_max_s": float(self.time_s[-1]),
                "major_radius_min_m": float(self.major_radius_m[0]),
                "major_radius_max_m": float(self.major_radius_m[-1]),
            },
            "catalog": {
                "path": self.catalog_path,
                "sha256": self.catalog_sha256,
                "row": _plain(dict(self.catalog_row)),
                "comparison": _plain(dict(self.catalog_comparison)),
            },
            "uncertainty": _plain(dict(self.uncertainty)),
        }


@dataclass(frozen=True)
class ProjectedObservation:
    record_id: str
    operator_id: str
    operator_status: str
    sample_ids: tuple[str, ...]
    observed_values: np.ndarray
    predicted_values: np.ndarray
    unit: str
    projection_sha256: str
    uncertainty_status: str
    likelihood_ready: bool


@dataclass(frozen=True)
class ReferencePackage:
    adapter_version: str
    protocol: Mapping[str, Any]
    protocol_sha256: str
    source_evidence_sha256: str
    source_manifest_sha256: str
    source_inverse_protocol_sha256: str
    observations: tuple[CanonicalObservation, ...]
    catalog_records: Mapping[int, tuple[Mapping[str, Any], ...]]
    split_receipt: Mapping[str, Any]
    design_references: tuple[Mapping[str, Any], ...]
    uncertainty: Mapping[str, Any]
    claim_ceiling: str

    def observation(self, shot_id: int, channel: str) -> CanonicalObservation:
        matches = [
            item
            for item in self.observations
            if item.shot_id == shot_id and item.channel == channel
        ]
        _require(
            len(matches) == 1,
            "observation_identity_error",
            f"expected one observation for shot={shot_id}, channel={channel}",
        )
        validate_observation_integrity(matches[0])
        return matches[0]

    def for_split(self, split: str) -> tuple[CanonicalObservation, ...]:
        _require(
            split in {"calibration", "validation", "held_out"},
            "invalid_split",
            f"unknown split {split!r}",
        )
        records = tuple(item for item in self.observations if item.split == split)
        for item in records:
            validate_observation_integrity(item)
        return records

    def require_likelihood_ready(self) -> None:
        validate_reference_package_integrity(self)
        raise AdapterError(
            "uncertainty_typed_absent",
            "frozen v1 selected Level-2 Thomson profiles have no bound measurement "
            "uncertainty/covariance; weighted likelihood is terminal_deferred",
        )


def _raw_entry(reference: Mapping[str, Any], kind: str) -> Mapping[str, Any]:
    matches = [item for item in reference.get("raw_files", []) if item.get("kind") == kind]
    _require(
        len(matches) == 1,
        "raw_entry_error",
        f"shot {reference.get('shot_id')}: expected one raw file of kind {kind}",
    )
    return matches[0]


def _source_path(source_root: Path, entry: Mapping[str, Any]) -> Path:
    relative = entry.get("path")
    _require(
        isinstance(relative, str) and relative.startswith("raw/"),
        "raw_path_error",
        f"raw path must remain under raw/: {relative!r}",
    )
    path = source_root / relative
    _require(path.is_file(), "missing_raw_file", f"missing source file {path}")
    return path


def _verify_raw_entry(source_root: Path, entry: Mapping[str, Any]) -> Path:
    path = _source_path(source_root, entry)
    actual_hash = sha256_file(path)
    _require(
        actual_hash == entry.get("sha256"),
        "raw_hash_mismatch",
        f"SHA-256 mismatch for {entry.get('path')}",
    )
    _require(
        path.stat().st_size == entry.get("bytes"),
        "raw_size_mismatch",
        f"byte-count mismatch for {entry.get('path')}",
    )
    return path


def _mast_reference(manifest: Mapping[str, Any], shot_id: int) -> Mapping[str, Any]:
    matches = [
        item
        for item in manifest.get("references", [])
        if item.get("device_name") == "MAST" and item.get("shot_id") == shot_id
    ]
    _require(
        len(matches) == 1,
        "source_reference_error",
        f"expected one MAST reference for shot {shot_id}",
    )
    reference = matches[0]
    _require(
        reference.get("evidence_class") == "measurement"
        and reference.get("raw_data_obtained") is True,
        "source_reference_error",
        f"shot {shot_id} is not an acquired measurement reference",
    )
    return reference


def _split_for_shot(protocol: Mapping[str, Any], shot_id: int) -> str:
    split = protocol.get("split", {})
    memberships = [
        label
        for label in ("calibration", "validation", "held_out")
        if shot_id in split.get(label, {}).get("shot_ids", [])
    ]
    _require(
        len(memberships) == 1,
        "shot_split_membership_error",
        f"shot {shot_id} must occur in exactly one split, got {memberships}",
    )
    return memberships[0]


def _load_protocol(protocol_path: Path) -> tuple[dict[str, Any], str, dict[str, Any], str]:
    protocol = _load_json(protocol_path, "protocol_read_error")
    _require(
        protocol.get("schema_version") == SCHEMA_VERSION,
        "protocol_schema_error",
        f"expected {SCHEMA_VERSION}",
    )
    _verify_executable_protocol(protocol)
    evidence_path = protocol_path.with_name(protocol.get("source_evidence_file", ""))
    evidence = _load_json(evidence_path, "source_evidence_read_error")
    _require(
        evidence.get("schema_version") == "reference_validation_source_evidence_v1",
        "source_evidence_schema_error",
        "unexpected source evidence schema",
    )
    return protocol, sha256_file(protocol_path), evidence, sha256_file(evidence_path)


def _verify_executable_protocol(protocol: Mapping[str, Any]) -> None:
    """Reject same-schema policy documents that this v1 code does not execute.

    This adapter is intentionally a single frozen transform.  Versioned policy
    changes must receive a new implementation instead of silently diverging
    from the constants used below.
    """

    expected_top = {
        "protocol_id": "UP4-03-reference-validation-prec-v1",
        "source_evidence_file": "source_evidence.json",
        "claim_ceiling": (
            "canonical_observation_adapter_only; formal likelihood, B03, B07B, "
            "R02, R06, physical validation, and parent UP4-03 remain not accepted"
        ),
    }
    for key, expected in expected_top.items():
        _require(
            protocol.get(key) == expected,
            "unsupported_protocol_contract",
            f"{key}: expected {expected!r}, got {protocol.get(key)!r}",
        )

    source = protocol.get("source_package", {})
    expected_source = {
        "path": "benchmarks/reference_data_v2",
        "shot_ids": [30421, 30420],
        "protected": True,
    }
    for key, expected in expected_source.items():
        _require(
            source.get(key) == expected,
            "unsupported_protocol_contract",
            f"source_package.{key}: expected {expected!r}, got {source.get(key)!r}",
        )

    canonical = protocol.get("canonical_contract", {})
    expected_canonical = {
        "version": "mast_thomson_canonical_observation_v1",
        "channels": ["n_e", "t_e"],
        "dimensions": ["time", "major_radius"],
        "units": {
            "n_e": "m^-3",
            "t_e": "eV",
            "time": "s",
            "major_radius": "m",
        },
        "raw_mapping": "canonical[t,r] = raw[r,t]",
        "mapping_source": "raw Zarr dimension_names only",
        "scale": 1.0,
        "offset": 0.0,
        "resampling": "none",
        "imputation": "none",
        "mask": "isfinite(raw)",
        "catalog_reconciliation": "prohibited",
    }
    for key, expected in expected_canonical.items():
        _require(
            canonical.get(key) == expected,
            "unsupported_protocol_contract",
            f"canonical_contract.{key}: expected {expected!r}, got {canonical.get(key)!r}",
        )

    diagnostic = protocol.get("diagnostic_operator", {})
    expected_diagnostic = {
        "id": "H_mast_thomson_exact_grid_sample_v1",
        "status": "idealized_same_grid_sample_projection",
        "interpolation": "prohibited",
        "calibration": "typed_absent",
        "spatial_response": "typed_absent",
        "temporal_response": "typed_absent",
        "diagnostic_response_complete": False,
        "formal_H_status": "terminal_deferred",
    }
    for key, expected in expected_diagnostic.items():
        _require(
            diagnostic.get(key) == expected,
            "unsupported_protocol_contract",
            f"diagnostic_operator.{key}: expected {expected!r}, got {diagnostic.get(key)!r}",
        )

    uncertainty = protocol.get("uncertainty", {})
    expected_uncertainty = {
        "status": "typed_absent",
        "scope": "selected_fair_mast_level2_thomson_profiles",
        "likelihood_policy": "reject_weighted_likelihood_until_present_bound",
    }
    for key, expected in expected_uncertainty.items():
        _require(
            uncertainty.get(key) == expected,
            "unsupported_protocol_contract",
            f"uncertainty.{key}: expected {expected!r}, got {uncertainty.get(key)!r}",
        )

    split = protocol.get("split", {})
    expected_split = {
        "enforce_disjoint": [
            "shot_id",
            "observation_id",
            "response_artifact_hash",
            "time_artifact_hash",
            "catalog_row_uuid",
            "canonical_payload_hash",
            "sample_lineage_hash",
            "derived_lineage_id",
        ],
        "formal_minimum": {
            "calibration_observations": 8,
            "validation_observations": 1,
            "held_out_observations": 4,
        },
        "status": "response_lineage_disjoint_but_formal_split_insufficient",
    }
    for key, expected in expected_split.items():
        _require(
            split.get(key) == expected,
            "unsupported_protocol_contract",
            f"split.{key}: expected {expected!r}, got {split.get(key)!r}",
        )
    _require(
        split.get("validation", {}).get("status") == "typed_absent",
        "unsupported_protocol_contract",
        "split.validation.status must remain typed_absent",
    )

    design = protocol.get("iter_design_separation", {})
    expected_design = {
        "reference_id": "iter_design_v1",
        "evidence_class": "design_target",
        "measurement_status": "typed_absent",
        "included_in_mast_observations": False,
    }
    for key, expected in expected_design.items():
        _require(
            design.get(key) == expected,
            "unsupported_protocol_contract",
            f"iter_design_separation.{key}: expected {expected!r}, got {design.get(key)!r}",
        )


def _verify_source_contract(
    source_root: Path,
    protocol: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], str, str]:
    manifest_path = source_root / "reference_manifest.json"
    inverse_path = source_root / "inverse_protocol.json"
    _require(manifest_path.is_file(), "missing_source_manifest", str(manifest_path))
    _require(inverse_path.is_file(), "missing_source_protocol", str(inverse_path))
    manifest_hash = sha256_file(manifest_path)
    inverse_hash = sha256_file(inverse_path)
    expected = protocol.get("source_package", {})
    _require(
        manifest_hash == expected.get("reference_manifest_sha256"),
        "source_manifest_hash_mismatch",
        f"unexpected source manifest {manifest_hash}",
    )
    _require(
        inverse_hash == expected.get("inverse_protocol_sha256"),
        "source_inverse_protocol_hash_mismatch",
        f"unexpected source inverse protocol {inverse_hash}",
    )
    manifest = _load_json(manifest_path, "source_manifest_read_error")
    inverse = _load_json(inverse_path, "source_inverse_protocol_read_error")
    _require(
        manifest.get("schema_version") == "reference_manifest_v2",
        "source_manifest_schema_error",
        "reference_manifest_v2 required",
    )
    _require(
        inverse.get("schema_version") == "inverse_protocol_v2",
        "source_inverse_protocol_schema_error",
        "inverse_protocol_v2 required",
    )
    _verify_split_binding(manifest, inverse, protocol)
    return manifest, inverse, manifest_hash, inverse_hash


def _verify_split_binding(
    manifest: Mapping[str, Any],
    inverse: Mapping[str, Any],
    protocol: Mapping[str, Any],
) -> None:
    source = manifest.get("split_protocol", {})
    source_inverse = inverse.get("split", {})
    frozen = protocol.get("split", {})
    mappings = {
        "calibration": ("calibration_shot_ids", "calibration_observation_ids"),
        "validation": ("validation_shot_ids", "validation_observation_ids"),
        "held_out": ("held_out_shot_ids", "held_out_observation_ids"),
    }
    for label, (shot_key, observation_key) in mappings.items():
        _require(
            source.get(shot_key, []) == frozen.get(label, {}).get("shot_ids", []),
            "protected_split_changed",
            f"source/frozen {label} shot IDs differ",
        )
        _require(
            source.get(observation_key, [])
            == frozen.get(label, {}).get("observation_ids", []),
            "protected_split_changed",
            f"source/frozen {label} observation IDs differ",
        )
    _require(
        source_inverse.get("calibration", {}).get("shot_ids", [])
        == frozen.get("calibration", {}).get("shot_ids", []),
        "protected_split_changed",
        "inverse calibration split differs",
    )
    _require(
        source_inverse.get("validation", {}).get("shot_ids", [])
        == frozen.get("validation", {}).get("shot_ids", []),
        "protected_split_changed",
        "inverse validation split differs",
    )
    _require(
        source_inverse.get("blind_held_out", {}).get("shot_ids", [])
        == frozen.get("held_out", {}).get("shot_ids", []),
        "protected_split_changed",
        "inverse held-out split differs",
    )


def _zarr_metadata(
    source_root: Path,
    reference: Mapping[str, Any],
) -> tuple[Path, Mapping[str, Any], Mapping[str, Any]]:
    schema_entry = _raw_entry(reference, "zarr_v3_consolidated_schema")
    schema_path = _verify_raw_entry(source_root, schema_entry)
    schema = _load_json(schema_path, "zarr_schema_read_error")
    _require(schema.get("zarr_format") == 3, "zarr_format_error", "Zarr v3 required")
    metadata = schema.get("consolidated_metadata", {}).get("metadata")
    _require(isinstance(metadata, dict), "zarr_metadata_error", "consolidated metadata missing")
    return schema_path, schema_entry, metadata


def _decode_zarr_array(
    source_root: Path,
    reference: Mapping[str, Any],
    metadata: Mapping[str, Any],
    array_path: str,
    raw_kind: str,
) -> tuple[np.ndarray, Mapping[str, Any], Mapping[str, Any]]:
    node = metadata.get(array_path)
    _require(
        isinstance(node, dict) and node.get("node_type") == "array",
        "missing_zarr_array",
        f"missing array {array_path}",
    )
    shape = node.get("shape")
    _require(
        isinstance(shape, list)
        and shape
        and all(isinstance(size, int) and size > 0 for size in shape),
        "zarr_shape_error",
        f"invalid shape for {array_path}: {shape!r}",
    )
    _require(
        node.get("data_type") == "float64",
        "zarr_dtype_error",
        f"{array_path} must be float64",
    )
    chunk_shape = node.get("chunk_grid", {}).get("configuration", {}).get("chunk_shape")
    _require(
        chunk_shape == shape,
        "zarr_chunk_layout_error",
        f"single full-shape chunk required for {array_path}",
    )
    codecs = node.get("codecs")
    _require(
        isinstance(codecs, list)
        and len(codecs) == 2
        and codecs[0].get("name") == "bytes"
        and codecs[0].get("configuration", {}).get("endian") == "little"
        and codecs[1].get("name") == "zstd",
        "zarr_codec_error",
        f"unsupported codecs for {array_path}: {codecs!r}",
    )
    entry = _raw_entry(reference, raw_kind)
    chunk_path = _verify_raw_entry(source_root, entry)
    try:
        import zstandard
    except ImportError as exc:  # pragma: no cover - dependency failure is explicit
        raise AdapterError("missing_zstandard", "zstandard is required for Zarr decode") from exc
    expected_bytes = math.prod(shape) * 8
    try:
        decoded = zstandard.ZstdDecompressor().decompress(
            chunk_path.read_bytes(), max_output_size=expected_bytes
        )
    except Exception as exc:
        raise AdapterError("zarr_decode_error", f"cannot decode {chunk_path}: {exc}") from exc
    _require(
        len(decoded) == expected_bytes,
        "zarr_decoded_size_error",
        f"{array_path}: expected {expected_bytes} decoded bytes, got {len(decoded)}",
    )
    values = np.frombuffer(decoded, dtype="<f8").reshape(tuple(shape)).copy()
    return values, node, entry


def canonicalize_profile(
    raw_values: np.ndarray,
    *,
    raw_dimensions: Sequence[str],
    raw_unit: str,
    channel: str,
    time_s: np.ndarray,
    major_radius_m: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, tuple[int, int]]:
    """Map a decoded raw profile to canonical ``[time, major_radius]``.

    This pure function is also the fail-closed unit/shape/dimension boundary
    used by the executable loader and its negative tests.
    """

    _require(channel in CHANNEL_CONTRACTS, "unknown_channel", channel)
    contract = CHANNEL_CONTRACTS[channel]
    dimensions = tuple(raw_dimensions)
    _require(
        len(dimensions) == 2 and set(dimensions) == set(CANONICAL_DIMENSIONS),
        "dimension_contract_error",
        f"{channel}: expected exactly time and major_radius, got {dimensions}",
    )
    _require(
        len(set(dimensions)) == 2,
        "dimension_contract_error",
        f"{channel}: duplicate dimension names {dimensions}",
    )
    _require(
        raw_unit == contract["raw_unit"],
        "unit_contract_error",
        f"{channel}: expected raw unit {contract['raw_unit']!r}, got {raw_unit!r}",
    )
    raw = np.asarray(raw_values)
    _require(raw.ndim == 2, "shape_contract_error", f"{channel}: rank 2 required")
    sizes = {name: int(raw.shape[index]) for index, name in enumerate(dimensions)}
    _require(
        sizes["time"] == len(time_s),
        "time_alignment_error",
        f"{channel}: time extent {sizes['time']} != coordinate length {len(time_s)}",
    )
    _require(
        sizes["major_radius"] == len(major_radius_m),
        "radius_alignment_error",
        f"{channel}: radius extent {sizes['major_radius']} != coordinate length {len(major_radius_m)}",
    )
    permutation = tuple(dimensions.index(name) for name in CANONICAL_DIMENSIONS)
    canonical = _readonly_f64(np.transpose(raw, axes=permutation))
    mask = _readonly_bool(np.isfinite(canonical))
    _require(mask.any(), "empty_observation", f"{channel}: no finite observations")
    return canonical, mask, permutation


def _decode_coordinates(
    source_root: Path,
    reference: Mapping[str, Any],
    metadata: Mapping[str, Any],
) -> tuple[np.ndarray, np.ndarray, dict[str, Mapping[str, Any]]]:
    decoded: dict[str, np.ndarray] = {}
    entries: dict[str, Mapping[str, Any]] = {}
    for name, contract in COORDINATE_CONTRACTS.items():
        values, node, entry = _decode_zarr_array(
            source_root,
            reference,
            metadata,
            contract["raw_path"],
            contract["raw_kind"],
        )
        _require(
            node.get("dimension_names") == [name],
            "coordinate_dimension_error",
            f"{name}: expected dimension [{name}]",
        )
        _require(
            node.get("attributes", {}).get("units") == contract["unit"],
            "coordinate_unit_error",
            f"{name}: expected unit {contract['unit']}",
        )
        coordinate = _readonly_f64(values.reshape(-1))
        _require(
            bool(np.isfinite(coordinate).all()),
            "coordinate_finite_error",
            f"{name}: non-finite coordinate",
        )
        _require(
            bool(np.all(np.diff(coordinate) > 0.0)),
            "coordinate_order_error",
            f"{name}: coordinate must be strictly increasing",
        )
        decoded[name] = coordinate
        entries[name] = entry
    return decoded["time"], decoded["major_radius"], entries


def _catalog_rows(
    source_root: Path,
    reference: Mapping[str, Any],
) -> tuple[tuple[dict[str, Any], ...], Mapping[str, Any]]:
    entry = _raw_entry(reference, "catalog_signal_metadata")
    path = _verify_raw_entry(source_root, entry)
    try:
        import duckdb
    except ImportError as exc:  # pragma: no cover - dependency failure is explicit
        raise AdapterError("missing_duckdb", "duckdb is required to decode catalog parquet") from exc
    columns = (
        "shot_id,name,description,rank,dimensions,shape,units,quality,source,"
        "url,endpoint_url,uuid,imas,version"
    )
    try:
        connection = duckdb.connect(database=":memory:")
        cursor = connection.execute(
            f"SELECT {columns} FROM read_parquet(?) "
            "WHERE source = 'thomson_scattering' AND name IN ('n_e','t_e') "
            "ORDER BY name",
            [str(path)],
        )
        names = [item[0] for item in cursor.description]
        rows = tuple(dict(zip(names, row)) for row in cursor.fetchall())
        connection.close()
    except Exception as exc:
        raise AdapterError("catalog_decode_error", f"cannot decode {path}: {exc}") from exc
    _require(len(rows) == 2, "catalog_row_error", f"expected n_e/t_e rows in {path}")
    _require(
        {row["name"] for row in rows} == {"n_e", "t_e"},
        "catalog_row_error",
        f"unexpected Thomson rows in {path}",
    )
    return tuple(_plain(row) for row in rows), entry


def _verify_catalog_snapshot(
    shot_id: int,
    rows: Sequence[Mapping[str, Any]],
    source_evidence: Mapping[str, Any],
) -> None:
    expected = source_evidence.get("catalog_snapshots", {}).get(str(shot_id), {}).get("rows")
    _require(isinstance(expected, list), "catalog_evidence_error", f"shot {shot_id}")
    _require(
        list(rows) == expected,
        "catalog_snapshot_changed",
        f"decoded catalog rows changed for shot {shot_id}",
    )


def _canonical_payload_hash(
    *,
    record_id: str,
    shot_id: int,
    channel: str,
    quantity: str,
    raw_dimensions: Sequence[str],
    raw_shape: Sequence[int],
    raw_unit: str,
    canonical_dimensions: Sequence[str],
    canonical_unit: str,
    axis_permutation: Sequence[int],
    values: np.ndarray,
    mask: np.ndarray,
    time_s: np.ndarray,
    major_radius_m: np.ndarray,
    source_response_sha256: str,
    source_schema_sha256: str,
    source_time_sha256: str,
    source_radius_sha256: str,
    catalog_sha256: str,
    catalog_row: Mapping[str, Any],
    catalog_comparison: Mapping[str, Any],
    uncertainty: Mapping[str, Any],
) -> str:
    header = {
        "domain": "FusionConceptAI.reference_validation.canonical_observation.v1",
        "record_id": record_id,
        "shot_id": shot_id,
        "channel": channel,
        "quantity": quantity,
        "raw_dimensions": list(raw_dimensions),
        "raw_shape": list(raw_shape),
        "raw_unit": raw_unit,
        "canonical_dimensions": list(canonical_dimensions),
        "canonical_unit": canonical_unit,
        "axis_permutation": list(axis_permutation),
        "shape": list(values.shape),
        "source_response_sha256": source_response_sha256,
        "source_schema_sha256": source_schema_sha256,
        "source_time_sha256": source_time_sha256,
        "source_radius_sha256": source_radius_sha256,
        "catalog_sha256": catalog_sha256,
        "catalog_row": _plain(dict(catalog_row)),
        "catalog_comparison": _plain(dict(catalog_comparison)),
        "uncertainty": _plain(dict(uncertainty)),
    }
    digest = hashlib.sha256()
    digest.update(canonical_json_bytes(header))
    digest.update(time_s.astype("<f8", copy=False).tobytes(order="C"))
    digest.update(major_radius_m.astype("<f8", copy=False).tobytes(order="C"))
    digest.update(values.astype("<f8", copy=False).tobytes(order="C"))
    digest.update(mask.astype(np.uint8, copy=False).tobytes(order="C"))
    return digest.hexdigest()


def _sample_hash(observation: CanonicalObservation, t_index: int, r_index: int) -> str:
    sample_id = f"{observation.record_id}:t{t_index}:r{r_index}"
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.sample.v1\0")
    digest.update(observation.canonical_payload_sha256.encode("ascii"))
    digest.update(sample_id.encode("utf-8"))
    digest.update(struct.pack("<II", t_index, r_index))
    digest.update(struct.pack("<ddd", float(observation.time_s[t_index]), float(observation.major_radius_m[r_index]), float(observation.values[t_index, r_index])))
    return digest.hexdigest()


def iter_canonical_samples(observation: CanonicalObservation) -> Iterator[dict[str, Any]]:
    """Yield every finite sample with explicit raw/canonical index lineage."""

    validate_observation_integrity(observation)
    for t_index, r_index in np.argwhere(observation.observed_mask):
        t = int(t_index)
        r = int(r_index)
        sample_id = f"{observation.record_id}:t{t}:r{r}"
        yield {
            "sample_id": sample_id,
            "sample_sha256": _sample_hash(observation, t, r),
            "record_id": observation.record_id,
            "source_response_sha256": observation.source_response_sha256,
            "raw_index": [r, t],
            "canonical_index": [t, r],
            "time_s": float(observation.time_s[t]),
            "major_radius_m": float(observation.major_radius_m[r]),
            "value": float(observation.values[t, r]),
            "unit": observation.canonical_unit,
        }


def _sample_lineage_hash_from_parts(
    *,
    record_id: str,
    source_response_sha256: str,
    canonical_payload_sha256: str,
    values: np.ndarray,
    mask: np.ndarray,
    time_s: np.ndarray,
    major_radius_m: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.sample_lineage.v1\0")
    digest.update(record_id.encode("utf-8"))
    digest.update(source_response_sha256.encode("ascii"))
    digest.update(canonical_payload_sha256.encode("ascii"))
    for t_index, r_index in np.argwhere(mask):
        t = int(t_index)
        r = int(r_index)
        digest.update(struct.pack("<II", t, r))
        digest.update(struct.pack("<ddd", float(time_s[t]), float(major_radius_m[r]), float(values[t, r])))
    return digest.hexdigest()


def validate_observation_integrity(
    observation: CanonicalObservation,
) -> dict[str, Any]:
    """Recompute a canonical record's schema, content, and lineage identity.

    Dataclass immutability does not make contained NumPy buffers immutable and
    ``dataclasses.replace`` can pair changed content with stale digests.  Every
    public consumer calls this boundary instead of trusting stored hashes.
    """

    _require(
        observation.channel in CHANNEL_CONTRACTS,
        "observation_unknown_channel",
        observation.channel,
    )
    contract = CHANNEL_CONTRACTS[observation.channel]
    expected_record_id = (
        f"mast:{observation.shot_id}:thomson_scattering:{observation.channel}"
    )
    _require(
        observation.record_id == expected_record_id,
        "observation_identity_error",
        f"expected {expected_record_id}, got {observation.record_id}",
    )
    _require(
        observation.quantity == contract["quantity"],
        "observation_quantity_error",
        f"expected {contract['quantity']}, got {observation.quantity}",
    )
    _require(
        len(observation.raw_dimensions) == 2
        and len(set(observation.raw_dimensions)) == 2
        and set(observation.raw_dimensions) == set(CANONICAL_DIMENSIONS),
        "observation_dimension_error",
        f"invalid raw dimensions {observation.raw_dimensions}",
    )
    expected_permutation = tuple(
        observation.raw_dimensions.index(name) for name in CANONICAL_DIMENSIONS
    )
    _require(
        tuple(observation.axis_permutation) == expected_permutation,
        "observation_axis_permutation_error",
        f"expected {expected_permutation}, got {observation.axis_permutation}",
    )
    _require(
        tuple(observation.canonical_dimensions) == CANONICAL_DIMENSIONS,
        "observation_dimension_error",
        f"invalid canonical dimensions {observation.canonical_dimensions}",
    )
    _require(
        observation.raw_unit == contract["raw_unit"]
        and observation.canonical_unit == contract["canonical_unit"],
        "observation_unit_error",
        f"unexpected {observation.raw_unit!r} -> {observation.canonical_unit!r}",
    )
    _require(
        len(observation.raw_shape) == 2
        and all(isinstance(item, int) and item > 0 for item in observation.raw_shape),
        "observation_shape_error",
        f"invalid raw shape {observation.raw_shape}",
    )
    expected_canonical_shape = tuple(
        observation.raw_shape[index] for index in expected_permutation
    )
    _require(
        tuple(observation.canonical_shape) == expected_canonical_shape,
        "observation_shape_error",
        f"expected canonical shape {expected_canonical_shape}, got {observation.canonical_shape}",
    )

    arrays = {
        "values": observation.values,
        "observed_mask": observation.observed_mask,
        "time_s": observation.time_s,
        "major_radius_m": observation.major_radius_m,
    }
    for name, array in arrays.items():
        _require(
            isinstance(array, np.ndarray),
            "observation_array_type_error",
            f"{name} must be a numpy.ndarray",
        )
        _require(
            bool(array.flags.c_contiguous),
            "observation_array_layout_error",
            f"{name} must be C contiguous",
        )
        _require(
            not bool(array.flags.writeable),
            "observation_array_writeable_error",
            f"{name} must be read-only",
        )
    _require(
        observation.values.dtype == np.dtype("<f8")
        and observation.time_s.dtype == np.dtype("<f8")
        and observation.major_radius_m.dtype == np.dtype("<f8")
        and observation.observed_mask.dtype == np.dtype(np.bool_),
        "observation_dtype_error",
        "values/coordinates must be little-endian float64 and mask must be bool",
    )
    _require(
        observation.values.shape == tuple(observation.canonical_shape)
        and observation.observed_mask.shape == tuple(observation.canonical_shape),
        "observation_shape_error",
        "value/mask arrays do not match canonical_shape",
    )
    _require(
        observation.time_s.shape == (observation.canonical_shape[0],)
        and observation.major_radius_m.shape == (observation.canonical_shape[1],),
        "observation_coordinate_shape_error",
        "coordinate arrays do not align with canonical dimensions",
    )
    _require(
        bool(np.isfinite(observation.time_s).all())
        and bool(np.isfinite(observation.major_radius_m).all()),
        "observation_coordinate_finite_error",
        "canonical coordinates must be finite",
    )
    _require(
        bool(np.all(np.diff(observation.time_s) > 0.0))
        and bool(np.all(np.diff(observation.major_radius_m) > 0.0)),
        "observation_coordinate_order_error",
        "canonical coordinates must be strictly increasing",
    )
    expected_mask = np.isfinite(observation.values)
    _require(
        np.array_equal(observation.observed_mask, expected_mask),
        "observation_mask_mismatch",
        "observed_mask must equal isfinite(values)",
    )
    _require(
        bool(observation.observed_mask.any()),
        "empty_observation",
        f"{observation.record_id}: no finite observations",
    )

    for name in (
        "source_response_sha256",
        "source_schema_sha256",
        "source_time_sha256",
        "source_radius_sha256",
        "catalog_sha256",
        "canonical_payload_sha256",
        "sample_lineage_sha256",
    ):
        value = getattr(observation, name)
        _require(
            isinstance(value, str)
            and len(value) == 64
            and all(character in "0123456789abcdef" for character in value),
            "observation_hash_format_error",
            f"{name} is not a lower-case SHA-256",
        )
    _require(
        observation.catalog_row.get("shot_id") == observation.shot_id
        and observation.catalog_row.get("name") == observation.channel
        and observation.catalog_row.get("source") == "thomson_scattering",
        "observation_catalog_identity_error",
        "catalog row does not identify this shot/channel",
    )
    _require(
        observation.catalog_comparison.get("raw_dimensions")
        == list(observation.raw_dimensions)
        and observation.catalog_comparison.get("raw_shape")
        == list(observation.raw_shape)
        and observation.catalog_comparison.get("raw_unit") == observation.raw_unit,
        "observation_catalog_comparison_error",
        "catalog comparison does not bind the raw representation",
    )
    _require(
        observation.uncertainty.get("status") == "typed_absent"
        and observation.uncertainty.get("scope")
        == "selected_fair_mast_level2_thomson_profile"
        and observation.uncertainty.get("shot_id") == observation.shot_id
        and observation.uncertainty.get("channel") == observation.channel
        and observation.uncertainty.get("likelihood_ready") is False,
        "observation_uncertainty_contract_error",
        "uncertainty record is not the scoped Level-2 typed absence",
    )

    actual_payload_hash = _canonical_payload_hash(
        record_id=observation.record_id,
        shot_id=observation.shot_id,
        channel=observation.channel,
        quantity=observation.quantity,
        raw_dimensions=observation.raw_dimensions,
        raw_shape=observation.raw_shape,
        raw_unit=observation.raw_unit,
        canonical_dimensions=observation.canonical_dimensions,
        canonical_unit=observation.canonical_unit,
        axis_permutation=observation.axis_permutation,
        values=observation.values,
        mask=observation.observed_mask,
        time_s=observation.time_s,
        major_radius_m=observation.major_radius_m,
        source_response_sha256=observation.source_response_sha256,
        source_schema_sha256=observation.source_schema_sha256,
        source_time_sha256=observation.source_time_sha256,
        source_radius_sha256=observation.source_radius_sha256,
        catalog_sha256=observation.catalog_sha256,
        catalog_row=observation.catalog_row,
        catalog_comparison=observation.catalog_comparison,
        uncertainty=observation.uncertainty,
    )
    _require(
        actual_payload_hash == observation.canonical_payload_sha256,
        "canonical_payload_hash_mismatch",
        f"{observation.record_id}: stored canonical payload identity is stale",
    )
    actual_lineage_hash = _sample_lineage_hash_from_parts(
        record_id=observation.record_id,
        source_response_sha256=observation.source_response_sha256,
        canonical_payload_sha256=actual_payload_hash,
        values=observation.values,
        mask=observation.observed_mask,
        time_s=observation.time_s,
        major_radius_m=observation.major_radius_m,
    )
    _require(
        actual_lineage_hash == observation.sample_lineage_sha256,
        "sample_lineage_hash_mismatch",
        f"{observation.record_id}: stored sample lineage identity is stale",
    )
    return {
        "status": "pass",
        "record_id": observation.record_id,
        "canonical_payload_sha256": actual_payload_hash,
        "sample_lineage_sha256": actual_lineage_hash,
        "observed_count": observation.observed_count,
    }


def _expected_package_uncertainty(protocol: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "status": "typed_absent",
        "scope": "selected_fair_mast_level2_thomson_profiles",
        "likelihood_ready": False,
        "diagnostic_response_complete": False,
        "formal_H_status": "terminal_deferred",
        "candidate_level1_error_arrays": protocol.get("uncertainty", {}).get(
            "candidate_level1_error_arrays"
        ),
        "reason": protocol.get("uncertainty", {}).get("reason"),
    }


def validate_reference_package_integrity(
    package: ReferencePackage,
) -> dict[str, Any]:
    """Validate live package metadata and every observation before consumption."""

    _verify_executable_protocol(package.protocol)
    _require(
        package.adapter_version == ADAPTER_VERSION,
        "reference_package_metadata_error",
        f"expected adapter version {ADAPTER_VERSION}",
    )
    _require(
        package.protocol_sha256 == sha256_file(DEFAULT_PROTOCOL),
        "reference_package_metadata_error",
        "protocol hash is not the supported frozen v1 protocol",
    )
    _require(
        package.source_evidence_sha256 == sha256_file(DEFAULT_SOURCE_EVIDENCE),
        "reference_package_metadata_error",
        "source-evidence hash is not the supported frozen v1 evidence",
    )
    source_contract = package.protocol.get("source_package", {})
    _require(
        package.source_manifest_sha256
        == source_contract.get("reference_manifest_sha256")
        and package.source_inverse_protocol_sha256
        == source_contract.get("inverse_protocol_sha256"),
        "reference_package_metadata_error",
        "source package identities differ from the frozen protocol",
    )
    expected_uncertainty = _expected_package_uncertainty(package.protocol)
    _require(
        canonical_json_bytes(_plain(dict(package.uncertainty)))
        == canonical_json_bytes(expected_uncertainty),
        "reference_package_uncertainty_error",
        "package uncertainty metadata contradicts the frozen typed absence",
    )
    _require(
        package.claim_ceiling == package.protocol.get("claim_ceiling"),
        "reference_package_metadata_error",
        "package claim ceiling differs from the frozen protocol",
    )
    expected_catalogs: dict[int, list[Mapping[str, Any]]] = {}
    for observation in package.observations:
        validate_observation_integrity(observation)
        expected_catalogs.setdefault(observation.shot_id, []).append(
            observation.catalog_row
        )
    _require(
        set(package.catalog_records) == set(expected_catalogs),
        "reference_package_catalog_error",
        "package catalog shot keys differ from observations",
    )
    for shot_id, rows in expected_catalogs.items():
        actual = sorted(
            (_plain(dict(row)) for row in package.catalog_records[shot_id]),
            key=lambda row: str(row.get("name")),
        )
        expected = sorted(
            (_plain(dict(row)) for row in rows),
            key=lambda row: str(row.get("name")),
        )
        _require(
            actual == expected,
            "reference_package_catalog_error",
            f"shot {shot_id}: package catalog rows differ from observations",
        )
    _require(
        len(package.design_references) == 1
        and package.design_references[0].get("reference_id") == "iter_design_v1"
        and package.design_references[0].get("evidence_class") == "design_target"
        and package.design_references[0].get("measurement_status") == "typed_absent",
        "reference_package_design_separation_error",
        "ITER design reference identity or measurement separation differs",
    )
    current_split = validate_no_leakage_records(
        package.observations, package.protocol
    )
    _require(
        canonical_json_bytes(current_split)
        == canonical_json_bytes(_plain(dict(package.split_receipt))),
        "split_receipt_stale",
        "stored split receipt differs from recomputed observation identities",
    )
    return {
        "status": "pass",
        "adapter_version": package.adapter_version,
        "protocol_sha256": package.protocol_sha256,
        "source_evidence_sha256": package.source_evidence_sha256,
        "observation_count": len(package.observations),
        "uncertainty_status": "typed_absent",
        "likelihood_ready": False,
    }


def _uncertainty_record(protocol: Mapping[str, Any], shot_id: int, channel: str) -> dict[str, Any]:
    configured = protocol.get("uncertainty", {})
    return {
        "status": "typed_absent",
        "scope": "selected_fair_mast_level2_thomson_profile",
        "shot_id": shot_id,
        "channel": channel,
        "source_profile_identity": f"fair-mast:level2:shot:{shot_id}:thomson_scattering:{channel}",
        "searched_schema_fields": configured.get("searched_schema_fields", []),
        "missing_required": configured.get("missing_required", []),
        "candidate_level1_error_arrays": configured.get("candidate_level1_error_arrays"),
        "reason": configured.get("reason"),
        "likelihood_ready": False,
        "formal_H_status": "terminal_deferred",
    }


def _load_observation_from_context(
    *,
    source_root: Path,
    protocol: Mapping[str, Any],
    source_evidence: Mapping[str, Any],
    reference: Mapping[str, Any],
    metadata: Mapping[str, Any],
    schema_entry: Mapping[str, Any],
    coordinate_entries: Mapping[str, Mapping[str, Any]],
    time_s: np.ndarray,
    major_radius_m: np.ndarray,
    catalog_rows: Sequence[Mapping[str, Any]],
    catalog_entry: Mapping[str, Any],
    channel: str,
) -> CanonicalObservation:
    shot_id = int(reference["shot_id"])
    contract = CHANNEL_CONTRACTS[channel]
    raw, node, response_entry = _decode_zarr_array(
        source_root,
        reference,
        metadata,
        contract["raw_path"],
        contract["raw_kind"],
    )
    raw_dimensions = tuple(node.get("dimension_names", []))
    raw_unit = node.get("attributes", {}).get("units")
    values, observed_mask, permutation = canonicalize_profile(
        raw,
        raw_dimensions=raw_dimensions,
        raw_unit=raw_unit,
        channel=channel,
        time_s=time_s,
        major_radius_m=major_radius_m,
    )
    split = _split_for_shot(protocol, shot_id)
    record_id = f"mast:{shot_id}:thomson_scattering:{channel}"
    _require(
        record_id in protocol.get("split", {}).get(split, {}).get("observation_ids", []),
        "observation_split_membership_error",
        f"{record_id} absent from frozen {split} split",
    )
    catalog_matches = [row for row in catalog_rows if row.get("name") == channel]
    _require(
        len(catalog_matches) == 1,
        "catalog_row_error",
        f"shot {shot_id}: expected one catalog row for {channel}",
    )
    catalog_row = catalog_matches[0]
    comparison = {
        "status": "conflict_preserved",
        "root_cause_status": "unproven",
        "catalog_dimensions": catalog_row.get("dimensions"),
        "catalog_shape": catalog_row.get("shape"),
        "catalog_unit": catalog_row.get("units"),
        "catalog_quality": catalog_row.get("quality"),
        "raw_dimensions": list(raw_dimensions),
        "raw_shape": list(raw.shape),
        "raw_unit": raw_unit,
        "normalization": "none",
        "resolution_rule": "raw Zarr schema drives this raw-byte adapter; catalog conflict is not reconciled or assigned a cause",
    }
    response_hash = str(response_entry["sha256"])
    uncertainty = _uncertainty_record(protocol, shot_id, channel)
    payload_hash = _canonical_payload_hash(
        record_id=record_id,
        shot_id=shot_id,
        channel=channel,
        quantity=contract["quantity"],
        raw_dimensions=raw_dimensions,
        raw_shape=raw.shape,
        raw_unit=str(raw_unit),
        canonical_dimensions=CANONICAL_DIMENSIONS,
        canonical_unit=contract["canonical_unit"],
        axis_permutation=permutation,
        values=values,
        mask=observed_mask,
        time_s=time_s,
        major_radius_m=major_radius_m,
        source_response_sha256=response_hash,
        source_schema_sha256=str(schema_entry["sha256"]),
        source_time_sha256=str(coordinate_entries["time"]["sha256"]),
        source_radius_sha256=str(coordinate_entries["major_radius"]["sha256"]),
        catalog_sha256=str(catalog_entry["sha256"]),
        catalog_row=catalog_row,
        catalog_comparison=comparison,
        uncertainty=uncertainty,
    )
    sample_hash = _sample_lineage_hash_from_parts(
        record_id=record_id,
        source_response_sha256=response_hash,
        canonical_payload_sha256=payload_hash,
        values=values,
        mask=observed_mask,
        time_s=time_s,
        major_radius_m=major_radius_m,
    )
    return CanonicalObservation(
        record_id=record_id,
        shot_id=shot_id,
        channel=channel,
        split=split,
        quantity=contract["quantity"],
        raw_dimensions=(str(raw_dimensions[0]), str(raw_dimensions[1])),
        raw_shape=(int(raw.shape[0]), int(raw.shape[1])),
        raw_unit=str(raw_unit),
        canonical_dimensions=CANONICAL_DIMENSIONS,
        canonical_shape=(int(values.shape[0]), int(values.shape[1])),
        canonical_unit=contract["canonical_unit"],
        axis_permutation=(int(permutation[0]), int(permutation[1])),
        values=values,
        observed_mask=observed_mask,
        time_s=time_s,
        major_radius_m=major_radius_m,
        source_response_path=str(response_entry["path"]),
        source_response_sha256=response_hash,
        source_schema_path=str(schema_entry["path"]),
        source_schema_sha256=str(schema_entry["sha256"]),
        source_time_path=str(coordinate_entries["time"]["path"]),
        source_time_sha256=str(coordinate_entries["time"]["sha256"]),
        source_radius_path=str(coordinate_entries["major_radius"]["path"]),
        source_radius_sha256=str(coordinate_entries["major_radius"]["sha256"]),
        catalog_path=str(catalog_entry["path"]),
        catalog_sha256=str(catalog_entry["sha256"]),
        catalog_row=catalog_row,
        catalog_comparison=comparison,
        uncertainty=uncertainty,
        canonical_payload_sha256=payload_hash,
        sample_lineage_sha256=sample_hash,
    )


def validate_no_leakage_records(
    observations: Sequence[CanonicalObservation],
    protocol: Mapping[str, Any],
) -> dict[str, Any]:
    """Enforce shot/response/time/derived-lineage separation across splits."""

    _verify_executable_protocol(protocol)
    split_names = ("calibration", "validation", "held_out")
    by_split = {
        split: tuple(item for item in observations if item.split == split)
        for split in split_names
    }
    for item in observations:
        _require(item.split in split_names, "invalid_split", item.split)
    record_ids = [item.record_id for item in observations]
    _require(
        len(record_ids) == len(set(record_ids)),
        "duplicate_observation_identity",
        "observation IDs must be globally unique",
    )
    shot_channel_ids = [(item.shot_id, item.channel) for item in observations]
    _require(
        len(shot_channel_ids) == len(set(shot_channel_ids)),
        "duplicate_shot_channel_identity",
        "shot/channel identities must be globally unique",
    )
    identities: dict[str, dict[str, set[Any]]] = {}
    for split, records in by_split.items():
        identities[split] = {
            "shot_ids": {item.shot_id for item in records},
            "observation_ids": {item.record_id for item in records},
            "response_artifact_hashes": {item.source_response_sha256 for item in records},
            "time_artifact_hashes": {item.source_time_sha256 for item in records},
            "catalog_row_uuids": {item.catalog_row.get("uuid") for item in records},
            "canonical_payload_hashes": {
                item.canonical_payload_sha256 for item in records
            },
            "sample_lineage_hashes": {item.sample_lineage_sha256 for item in records},
            "derived_lineage_ids": {
                f"mast-shot:{item.shot_id}:response:{item.source_response_sha256}:time:{item.source_time_sha256}"
                for item in records
            },
        }
    intersections: dict[str, dict[str, list[Any]]] = {}
    for left_index, left in enumerate(split_names):
        for right in split_names[left_index + 1 :]:
            key = f"{left}__{right}"
            intersections[key] = {}
            for identity_name in identities[left]:
                overlap = identities[left][identity_name] & identities[right][identity_name]
                intersections[key][identity_name] = sorted(overlap, key=str)
                _require(
                    not overlap,
                    "split_leakage",
                    f"{identity_name} overlap across {left}/{right}: {sorted(overlap, key=str)}",
                )
    expected_ids = {
        label: set(protocol.get("split", {}).get(label, {}).get("observation_ids", []))
        for label in split_names
    }
    for label in split_names:
        _require(
            identities[label]["observation_ids"] == expected_ids[label],
            "split_coverage_error",
            f"{label} observation IDs differ from frozen protocol",
        )
    for item in observations:
        validate_observation_integrity(item)
    shared_radius_hashes = sorted(
        {
            item.source_radius_sha256
            for left_index, left in enumerate(split_names)
            for right in split_names[left_index + 1 :]
            for item in by_split[left]
            if item.source_radius_sha256
            in {other.source_radius_sha256 for other in by_split[right]}
        }
    )
    formal_minimum = protocol.get("split", {}).get("formal_minimum", {})
    counts = {
        label: len(identities[label]["observation_ids"]) for label in split_names
    }
    formal_count_ready = (
        counts["calibration"] >= int(formal_minimum.get("calibration_observations", 0))
        and counts["held_out"] >= int(formal_minimum.get("held_out_observations", 0))
        and counts["validation"] >= int(formal_minimum.get("validation_observations", 0))
    )
    return {
        "schema_version": "reference_validation_split_receipt_v1",
        "status": "pass_no_cross_split_response_lineage",
        "checked_identities": list(next(iter(identities.values())).keys()),
        "intersections": intersections,
        "counts": counts,
        "shared_non_response_artifacts": {
            "major_radius_coordinate_sha256": shared_radius_hashes,
            "role": "declared_coordinate_grid_only; excluded from response/fit lineage",
        },
        "strict_any_artifact_policy": {
            "status": "terminal_deferred" if shared_radius_hashes else "pass",
            "reason": "the acquired shots share an identical major-radius coordinate artifact"
            if shared_radius_hashes
            else None,
        },
        "validation_split": {
            "status": "typed_absent" if not by_split["validation"] else "present",
            "observation_count": counts["validation"],
        },
        "formal_minimum_met": formal_count_ready,
        "formal_split_ready": bool(formal_count_ready and by_split["validation"]),
        "claim_ceiling": "prepared_adapter_only; no formal B03/B07B split credit",
    }


def validate_no_leakage(package: ReferencePackage) -> dict[str, Any]:
    _verify_executable_protocol(package.protocol)
    return validate_no_leakage_records(package.observations, package.protocol)


def _design_references(manifest: Mapping[str, Any]) -> tuple[Mapping[str, Any], ...]:
    designs = tuple(
        item
        for item in manifest.get("references", [])
        if item.get("evidence_class") == "design_target"
    )
    for item in designs:
        _require(
            item.get("measurement_status") == "typed_absent",
            "design_measurement_separation_error",
            f"{item.get('reference_id')}: design target cannot enter measurement observations",
        )
    return designs


def load_reference_package(
    source_root: Path | str = DEFAULT_SOURCE_ROOT,
    protocol_path: Path | str = DEFAULT_PROTOCOL,
) -> ReferencePackage:
    """Load and validate the complete two-shot canonical observation package."""

    source_root = Path(source_root).resolve()
    protocol_path = Path(protocol_path).resolve()
    protocol, protocol_hash, source_evidence, source_evidence_hash = _load_protocol(protocol_path)
    manifest, _inverse, manifest_hash, inverse_hash = _verify_source_contract(
        source_root, protocol
    )
    observations: list[CanonicalObservation] = []
    catalogs: dict[int, tuple[Mapping[str, Any], ...]] = {}
    for shot_id in protocol.get("source_package", {}).get("shot_ids", []):
        reference = _mast_reference(manifest, int(shot_id))
        for raw_entry in reference.get("raw_files", []):
            _verify_raw_entry(source_root, raw_entry)
        _schema_path, schema_entry, metadata = _zarr_metadata(source_root, reference)
        uncertainty_like = [
            key
            for key in metadata
            if key.startswith("thomson_scattering/")
            and any(
                token in key.lower()
                for token in ("uncert", "error", "sigma", "covariance", "quality")
            )
        ]
        _require(
            not uncertainty_like,
            "unexpected_level2_uncertainty_schema",
            f"shot {shot_id}: protocol requires review before binding {uncertainty_like}",
        )
        time_s, radius_m, coordinate_entries = _decode_coordinates(
            source_root, reference, metadata
        )
        catalog_rows, catalog_entry = _catalog_rows(source_root, reference)
        _verify_catalog_snapshot(int(shot_id), catalog_rows, source_evidence)
        catalogs[int(shot_id)] = catalog_rows
        for channel in protocol.get("canonical_contract", {}).get("channels", []):
            observations.append(
                _load_observation_from_context(
                    source_root=source_root,
                    protocol=protocol,
                    source_evidence=source_evidence,
                    reference=reference,
                    metadata=metadata,
                    schema_entry=schema_entry,
                    coordinate_entries=coordinate_entries,
                    time_s=time_s,
                    major_radius_m=radius_m,
                    catalog_rows=catalog_rows,
                    catalog_entry=catalog_entry,
                    channel=str(channel),
                )
            )
        per_shot = [item for item in observations if item.shot_id == int(shot_id)]
        _require(
            len(per_shot) == 2
            and np.array_equal(per_shot[0].observed_mask, per_shot[1].observed_mask),
            "paired_mask_alignment_error",
            f"shot {shot_id}: n_e/t_e finite masks differ",
        )
    split_receipt = validate_no_leakage_records(observations, protocol)
    uncertainty = _expected_package_uncertainty(protocol)
    package = ReferencePackage(
        adapter_version=ADAPTER_VERSION,
        protocol=protocol,
        protocol_sha256=protocol_hash,
        source_evidence_sha256=source_evidence_hash,
        source_manifest_sha256=manifest_hash,
        source_inverse_protocol_sha256=inverse_hash,
        observations=tuple(observations),
        catalog_records=catalogs,
        split_receipt=split_receipt,
        design_references=_design_references(manifest),
        uncertainty=uncertainty,
        claim_ceiling=str(protocol.get("claim_ceiling")),
    )
    validate_reference_package_integrity(package)
    return package


def load_mast_observation(
    shot_id: int,
    channel: str,
    split: str,
    source_root: Path | str = DEFAULT_SOURCE_ROOT,
    protocol_path: Path | str = DEFAULT_PROTOCOL,
) -> CanonicalObservation:
    package = load_reference_package(source_root, protocol_path)
    observation = package.observation(shot_id, channel)
    _require(
        observation.split == split,
        "split_request_mismatch",
        f"requested {split}, frozen split is {observation.split}",
    )
    return observation


def apply_thomson_sample_operator(
    observation: CanonicalObservation,
    predicted_values: np.ndarray,
    predicted_unit: str,
    major_radius_m: np.ndarray,
    time_s: np.ndarray,
) -> ProjectedObservation:
    """Project an exact-grid prediction onto the acquired finite sample mask.

    No interpolation, response convolution, calibration, or uncertainty
    weighting is performed.  A future formal diagnostic operator must be a new
    version and bind provider-supported response/calibration evidence.
    """

    validate_observation_integrity(observation)
    _require(
        predicted_unit == observation.canonical_unit,
        "prediction_unit_error",
        f"expected {observation.canonical_unit}, got {predicted_unit}",
    )
    predicted = np.asarray(predicted_values, dtype="<f8")
    _require(
        predicted.shape == observation.canonical_shape,
        "prediction_shape_error",
        f"expected {observation.canonical_shape}, got {predicted.shape}",
    )
    supplied_time = np.asarray(time_s, dtype="<f8")
    supplied_radius = np.asarray(major_radius_m, dtype="<f8")
    _require(
        np.array_equal(supplied_time, observation.time_s),
        "prediction_time_grid_error",
        "time grid differs; interpolation is not authorized",
    )
    _require(
        np.array_equal(supplied_radius, observation.major_radius_m),
        "prediction_radius_grid_error",
        "major-radius grid differs; interpolation is not authorized",
    )
    selected_prediction = _readonly_f64(predicted[observation.observed_mask])
    _require(
        bool(np.isfinite(selected_prediction).all()),
        "prediction_nonfinite_error",
        "prediction is non-finite at one or more observed samples",
    )
    selected_observation = _readonly_f64(observation.values[observation.observed_mask])
    sample_ids = tuple(
        f"{observation.record_id}:t{int(t)}:r{int(r)}"
        for t, r in np.argwhere(observation.observed_mask)
    )
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.projection.v1\0")
    digest.update(observation.canonical_payload_sha256.encode("ascii"))
    digest.update(selected_prediction.tobytes(order="C"))
    return ProjectedObservation(
        record_id=observation.record_id,
        operator_id="H_mast_thomson_exact_grid_sample_v1",
        operator_status="idealized_same_grid_sample_projection",
        sample_ids=sample_ids,
        observed_values=selected_observation,
        predicted_values=selected_prediction,
        unit=observation.canonical_unit,
        projection_sha256=digest.hexdigest(),
        uncertainty_status=str(observation.uncertainty.get("status")),
        likelihood_ready=False,
    )


def _write_bytes(path: Path, data: bytes) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return {"path": path.as_posix(), "bytes": len(data), "sha256": sha256_bytes(data)}


def _write_json(path: Path, value: Any) -> dict[str, Any]:
    data = json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2
    ).encode("utf-8") + b"\n"
    return _write_bytes(path, data)


def write_canonical_package(package: ReferencePackage, output: Path | str) -> dict[str, Any]:
    """Materialize a deterministic, directly consumable canonical package."""

    output = Path(output).resolve()
    _require(
        not output.exists(),
        "output_exists",
        f"refusing to overwrite existing output {output}",
    )
    validate_reference_package_integrity(package)
    current_split_receipt = validate_no_leakage(package)
    current_uncertainty = _expected_package_uncertainty(package.protocol)
    current_claim_ceiling = str(package.protocol.get("claim_ceiling"))
    output.mkdir(parents=True)
    artifacts: list[dict[str, Any]] = []
    entries: list[dict[str, Any]] = []
    coordinates_written: set[int] = set()
    for observation in package.observations:
        validate_observation_integrity(observation)
        shot_dir = output / f"shot_{observation.shot_id}"
        if observation.shot_id not in coordinates_written:
            for name, values in (
                ("time_s.f64le", observation.time_s),
                ("major_radius_m.f64le", observation.major_radius_m),
            ):
                record = _write_bytes(shot_dir / name, values.tobytes(order="C"))
                record["path"] = str((shot_dir / name).relative_to(output)).replace("\\", "/")
                artifacts.append(record)
            coordinates_written.add(observation.shot_id)
        value_path = shot_dir / f"{observation.channel}.f64le"
        mask_path = shot_dir / f"{observation.channel}.mask.u8"
        sample_path = shot_dir / f"{observation.channel}.samples.jsonl"
        value_record = _write_bytes(value_path, observation.values.tobytes(order="C"))
        mask_record = _write_bytes(
            mask_path, observation.observed_mask.astype(np.uint8).tobytes(order="C")
        )
        digest = hashlib.sha256()
        sample_count = 0
        with sample_path.open("wb") as stream:
            for sample in iter_canonical_samples(observation):
                line = canonical_json_bytes(sample) + b"\n"
                stream.write(line)
                digest.update(line)
                sample_count += 1
        sample_record = {
            "path": str(sample_path.relative_to(output)).replace("\\", "/"),
            "bytes": sample_path.stat().st_size,
            "sha256": digest.hexdigest(),
            "records": sample_count,
        }
        for record, path in ((value_record, value_path), (mask_record, mask_path)):
            record["path"] = str(path.relative_to(output)).replace("\\", "/")
            artifacts.append(record)
        artifacts.append(sample_record)
        entry = observation.manifest_entry()
        entry["canonical"]["files"] = {
            "values": value_record,
            "mask": mask_record,
            "samples": sample_record,
        }
        entries.append(entry)
    manifest = {
        "schema_version": "canonical_reference_package_v1",
        "adapter_version": package.adapter_version,
        "protocol_sha256": package.protocol_sha256,
        "source_evidence_sha256": package.source_evidence_sha256,
        "source_manifest_sha256": package.source_manifest_sha256,
        "source_inverse_protocol_sha256": package.source_inverse_protocol_sha256,
        "canonical_dimensions": list(CANONICAL_DIMENSIONS),
        "observations": entries,
        "split_receipt": current_split_receipt,
        "uncertainty": current_uncertainty,
        "diagnostic_operator": package.protocol.get("diagnostic_operator"),
        "design_references": [
            {
                "reference_id": item.get("reference_id"),
                "evidence_class": item.get("evidence_class"),
                "measurement_status": item.get("measurement_status"),
                "included_in_observations": False,
            }
            for item in package.design_references
        ],
        "formal_inverse": "not_executed",
        "b03": "not_claimed",
        "b07b": "not_claimed",
        "claim_ceiling": current_claim_ceiling,
    }
    catalog_snapshot = {
        "schema_version": "decoded_catalog_snapshot_v1",
        "backend": "duckdb",
        "shots": {
            str(shot): [_plain(dict(row)) for row in rows]
            for shot, rows in package.catalog_records.items()
        },
        "root_cause_status": "unproven",
        "normalization": "none",
    }
    report = {
        "schema_version": "reference_validation_adapter_report_v1",
        "task_id": "UP4-03-REFERENCE-VALIDATION-PREC",
        "program_state": "pass_with_scope",
        "execution_classification": "process_completed",
        "numerical_state": "not_executed",
        "physical_state": "unknown",
        "resolution": "terminal_deferred",
        "engineering_state": "not_applicable",
        "records": len(entries),
        "finite_samples": sum(item.observed_count for item in package.observations),
        "uncertainty_status": current_uncertainty.get("status"),
        "likelihood_ready": False,
        "diagnostic_response_complete": False,
        "formal_H_status": "terminal_deferred",
        "formal_parent_consumer": "not_executed",
        "formal_inverse": "not_executed",
        "b03": "not_claimed",
        "b07b": "not_claimed",
        "parent_UP4_03": "not_accepted",
        "claim_ceiling": current_claim_ceiling,
        "remaining_gaps": package.protocol.get("remaining_gaps", []),
    }
    manifest_record = _write_json(output / "canonical_manifest.json", manifest)
    split_record = _write_json(output / "split_receipt.json", current_split_receipt)
    catalog_record = _write_json(output / "catalog_snapshot.json", catalog_snapshot)
    report_record = _write_json(output / "adapter_report.json", report)
    for record, path in (
        (manifest_record, output / "canonical_manifest.json"),
        (split_record, output / "split_receipt.json"),
        (catalog_record, output / "catalog_snapshot.json"),
        (report_record, output / "adapter_report.json"),
    ):
        record["path"] = str(path.relative_to(output)).replace("\\", "/")
    artifact_manifest = {
        "schema_version": "reference_validation_artifact_manifest_v1",
        "files": sorted(
            artifacts
            + [manifest_record, split_record, catalog_record, report_record],
            key=lambda item: item["path"],
        ),
    }
    _write_json(output / "artifact_manifest.json", artifact_manifest)
    return report


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Decode and canonicalize the acquired FAIR-MAST reference observations"
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    try:
        package = load_reference_package(args.source, args.protocol)
        report = write_canonical_package(package, args.output)
    except AdapterError as exc:
        print(
            json.dumps(
                {
                    "program_state": "fail",
                    "execution_classification": "program_exception",
                    "error_code": exc.code,
                    "error": exc.message,
                },
                ensure_ascii=False,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
