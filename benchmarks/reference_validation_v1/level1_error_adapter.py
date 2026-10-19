"""Versioned FAIR-MAST Level-1 AYC error-data observation adapter.

This loader consumes the separately acquired Level-1 shot packages.  It keeps
the provider's error and covariance-labelled values attached to their own
``[time, radial_index]`` measurement product.  Blank error units and unknown
statistical semantics are preserved; the values are never treated as standard
deviations, likelihood weights, or an index-aligned uncertainty for Level-2.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterator, Mapping, Sequence

import numpy as np

import reference_adapter as core


LEVEL1_ADAPTER_VERSION = "mast_level1_error_adapter_v1"
LEVEL1_SCHEMA_VERSION = "mast_level1_error_protocol_v1"
HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
DEFAULT_SOURCE_ROOT = HERE.parent / "reference_data_level1_v1"
DEFAULT_PROTOCOL = HERE / "level1_protocol.json"
ACQUISITION_SCRIPT = REPO_ROOT / "tools" / "fetch_mast_level1_uncertainty_v1.py"
CANONICAL_DIMENSIONS = ("time", "radial_index")
OBSERVATION_ARRAYS = (
    "ne",
    "te",
    "ne_error",
    "te_error",
    "covariance_ne_te",
    "radius",
)
COORDINATE_ARRAYS = ("time", "radial_index")
ACQUIRED_ARRAYS = OBSERVATION_ARRAYS + COORDINATE_ARRAYS + (
    "instrument_dr",
    "instrument_time",
)
ARRAY_UNITS = {
    "ne": "1 / m ** 3",
    "te": "eV",
    "ne_error": "",
    "te_error": "",
    "covariance_ne_te": "eV / m ** 3",
    "radius": "m",
    "time": "s",
    "radial_index": " arb ",
}
EXPECTED_SHOTS = (
    {
        "shot_id": 30421,
        "split": "calibration",
        "directory": "shot30421_r1",
        "shape": [284, 131],
        "acquisition_sha256": "b517dcd2929f46968d78970f8107645d5082a128b5e9b5267e525803032742b7",
        "zmetadata_sha256": "362932d6cfeb62f01109a56b825b235b7daaedc928c17340be59c7a1398e7db1",
        "source_records_sha256": "2593d0182fa55222351b26a90bc3b0b7d9447c61d15aa02bc40a0c1be049db96",
    },
    {
        "shot_id": 30420,
        "split": "held_out",
        "directory": "shot30420_r1",
        "shape": [73, 131],
        "acquisition_sha256": "b5bb5d906f701af2bd1ee84f8132558c6e17f7c6d469480c86f5cf3d963e9978",
        "zmetadata_sha256": "be43c2dca2e772d413fa5151590c904d5ce18bb6e5d4946c852c0f537f14819c",
        "source_records_sha256": "80df2e3e228e067c57316f318d94bab382a23db51d008d5e20fe88f995d19188",
    },
)
CLAIM_CEILING = (
    "Level-1 error-data observation adapter only; error values are present but "
    "statistical semantics, likelihood, calibrated diagnostic response, B03, "
    "B07B, R02, R06, and parent UP4-03 acceptance remain deferred"
)


def _readonly_f32(values: Any) -> np.ndarray:
    result = np.ascontiguousarray(values, dtype="<f4")
    result.setflags(write=False)
    return result


def _readonly_bool(values: Any) -> np.ndarray:
    result = np.ascontiguousarray(values, dtype=np.bool_)
    result.setflags(write=False)
    return result


def _verify_protocol(protocol: Mapping[str, Any]) -> None:
    core._require(
        protocol.get("schema_version") == LEVEL1_SCHEMA_VERSION,
        "level1_protocol_schema_error",
        f"expected {LEVEL1_SCHEMA_VERSION}",
    )
    core._require(
        protocol.get("protocol_id")
        == "UP4-03-reference-validation-level1-error-data-v1"
        and protocol.get("source_root") == "benchmarks/reference_data_level1_v1"
        and protocol.get("shots") == list(EXPECTED_SHOTS),
        "unsupported_level1_protocol",
        "source package or shot identities differ from the implemented v1 contract",
    )
    canonical = protocol.get("canonical_contract", {})
    expected_canonical = {
        "version": "mast_ayc_level1_error_observation_v1",
        "dimensions": ["time", "radial_index"],
        "dtype": "float32_little_endian",
        "mapping": (
            "identity: canonical[time,radial_index] = raw[time,radial_index]"
        ),
        "scale": 1.0,
        "offset": 0.0,
        "resampling": "none",
        "imputation": "none",
        "dynamic_radius": "radius_m[time,radial_index] retained per cell",
    }
    for key, expected in expected_canonical.items():
        core._require(
            canonical.get(key) == expected,
            "unsupported_level1_protocol",
            f"canonical_contract.{key} differs from the implemented v1 contract",
        )
    configured_arrays = canonical.get("arrays", {})
    core._require(
        set(configured_arrays) == set(ARRAY_UNITS),
        "unsupported_level1_protocol",
        "canonical array set differs",
    )
    for name, unit in ARRAY_UNITS.items():
        core._require(
            configured_arrays.get(name, {}).get("unit") == unit,
            "unsupported_level1_protocol",
            f"canonical_contract.arrays.{name}.unit differs",
        )
    semantics = protocol.get("error_semantics", {})
    core._require(
        semantics.get("status") == "present_values_unknown_statistical_semantics"
        and semantics.get("acquisition_semantics")
        == "unverified_not_assumed_standard_deviation"
        and semantics.get("standard_deviation_interpretation") == "prohibited"
        and semantics.get("inverse_variance_weighting") == "prohibited"
        and semantics.get("likelihood_ready") is False
        and semantics.get("calibration_semantics") == "typed_absent",
        "unsupported_level1_protocol",
        "error semantics or likelihood policy differs",
    )
    conditional = protocol.get("conditional_consistency_diagnostic", {})
    core._require(
        conditional.get("status") == "conditional_assumption_check_only"
        and conditional.get("formula")
        == "rho_star = covariance_ne_te / (ne_error * te_error)",
        "unsupported_level1_protocol",
        "conditional diagnostic contract differs",
    )
    core._require(
        protocol.get("level2_binding", {}).get("status")
        == "prohibited_unbound_products"
        and protocol.get("split", {})
        == {
            "calibration_shot_ids": [30421],
            "validation_shot_ids": [],
            "held_out_shot_ids": [30420],
            "validation_status": "typed_absent",
            "formal_minimum_met": False,
        }
        and protocol.get("iter_design_separation")
        == {"included": False, "measurement_status": "typed_absent"}
        and protocol.get("claim_ceiling") == CLAIM_CEILING,
        "unsupported_level1_protocol",
        "binding, split, ITER, or claim ceiling differs",
    )


def _payload_hash(
    *,
    shot_id: int,
    split: str,
    shape: tuple[int, int],
    source_directory: str,
    acquisition_sha256: str,
    zmetadata_sha256: str,
    arrays: Mapping[str, np.ndarray],
    source_records: Mapping[str, Mapping[str, Any]],
) -> str:
    header = {
        "domain": "FusionConceptAI.reference_validation.level1_error_observation.v1",
        "shot_id": shot_id,
        "split_independent_identity": True,
        "source_directory": source_directory,
        "acquisition_sha256": acquisition_sha256,
        "zmetadata_sha256": zmetadata_sha256,
        "dimensions": list(CANONICAL_DIMENSIONS),
        "shape": list(shape),
        "dtype": "float32_little_endian",
        "mapping": "identity",
        "error_semantics": "unverified_not_assumed_standard_deviation",
        "source_records": {
            name: core._plain(dict(source_records[name]))
            for name in sorted(source_records)
        },
    }
    digest = hashlib.sha256()
    digest.update(core.canonical_json_bytes(header))
    for name in sorted(arrays):
        digest.update(name.encode("ascii") + b"\0")
        digest.update(arrays[name].astype("<f4", copy=False).tobytes(order="C"))
    return digest.hexdigest()


def _sample_lineage_hash(
    payload_hash: str,
    arrays: Mapping[str, np.ndarray],
    observed_mask: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.reference_validation.level1_cells.v1\0")
    digest.update(payload_hash.encode("ascii"))
    for t_index, r_index in np.argwhere(observed_mask):
        t, r = int(t_index), int(r_index)
        digest.update(struct.pack("<II", t, r))
        for name in OBSERVATION_ARRAYS:
            digest.update(struct.pack("<f", float(arrays[name][t, r])))
    return digest.hexdigest()


def _source_records_hash(
    source_records: Mapping[str, Mapping[str, Any]],
) -> str:
    """Bind live record metadata to the independently pinned acquisition receipt."""

    try:
        normalized = {
            name: core._plain(dict(source_records[name]))
            for name in sorted(source_records)
        }
        encoded = core.canonical_json_bytes(normalized)
    except (KeyError, TypeError, ValueError) as exc:
        raise core.AdapterError(
            "level1_source_records_binding_error",
            f"source records cannot be canonicalized: {exc}",
        ) from exc
    return hashlib.sha256(encoded).hexdigest()


@dataclass(frozen=True)
class Level1ErrorObservation:
    shot_id: int
    split: str
    dimensions: tuple[str, str]
    shape: tuple[int, int]
    ne: np.ndarray
    te: np.ndarray
    ne_error: np.ndarray
    te_error: np.ndarray
    covariance_ne_te: np.ndarray
    radius_m: np.ndarray
    time_s: np.ndarray
    radial_index: np.ndarray
    observed_mask: np.ndarray
    source_directory: str
    acquisition_sha256: str
    zmetadata_sha256: str
    source_records: Mapping[str, Mapping[str, Any]]
    error_semantics: str
    likelihood_ready: bool
    canonical_payload_sha256: str
    sample_lineage_sha256: str

    @property
    def record_id(self) -> str:
        return f"mast:{self.shot_id}:level1:ayc:error_data"

    @property
    def arrays(self) -> dict[str, np.ndarray]:
        return {
            "ne": self.ne,
            "te": self.te,
            "ne_error": self.ne_error,
            "te_error": self.te_error,
            "covariance_ne_te": self.covariance_ne_te,
            "radius": self.radius_m,
            "time": self.time_s,
            "radial_index": self.radial_index,
        }

    @property
    def observed_count(self) -> int:
        return int(self.observed_mask.sum())

    def require_likelihood_ready(self) -> None:
        validate_level1_observation(self)
        raise core.AdapterError(
            "level1_error_semantics_unknown",
            "Level-1 error values are present, but blank error units and absent "
            "provider statistical/calibration semantics prohibit a likelihood",
        )

    def manifest_entry(self) -> dict[str, Any]:
        integrity = validate_level1_observation(self)
        return {
            "record_id": self.record_id,
            "shot_id": self.shot_id,
            "split": self.split,
            "source_directory": self.source_directory,
            "acquisition_sha256": self.acquisition_sha256,
            "zmetadata_sha256": self.zmetadata_sha256,
            "raw": {
                "dimensions": list(self.dimensions),
                "shape": list(self.shape),
                "dtype": "float32_little_endian",
                "array_sha256": {
                    name: self.source_records[name]["raw_sha256"]
                    for name in sorted(self.source_records)
                },
            },
            "mapping": {
                "rule": "canonical[time,radial_index] = raw[time,radial_index]",
                "axis_permutation": [0, 1],
                "scale": 1.0,
                "offset": 0.0,
                "resampling": "none",
                "imputation": "none",
                "radius_role": "dynamic radius_m[time,radial_index] coordinate",
            },
            "canonical": {
                "dimensions": list(self.dimensions),
                "shape": list(self.shape),
                "payload_sha256": self.canonical_payload_sha256,
                "sample_lineage_sha256": self.sample_lineage_sha256,
                "observed_count": self.observed_count,
            },
            "error_data": {
                "status": "present_values_unknown_statistical_semantics",
                "provider_fields": ["ne_error", "te_error", "covariance_ne_te"],
                "ne_error_unit": "",
                "te_error_unit": "",
                "covariance_ne_te_unit": "eV / m ** 3",
                "standard_deviation_interpretation": "prohibited",
                "likelihood_ready": False,
            },
            "conditional_consistency_diagnostic": conditional_error_consistency(self),
            "integrity": integrity,
        }


@dataclass(frozen=True)
class Level1ErrorPackage:
    adapter_version: str
    protocol: Mapping[str, Any]
    protocol_sha256: str
    observations: tuple[Level1ErrorObservation, ...]
    split_receipt: Mapping[str, Any]
    claim_ceiling: str

    def observation(self, shot_id: int) -> Level1ErrorObservation:
        matches = [item for item in self.observations if item.shot_id == shot_id]
        core._require(
            len(matches) == 1,
            "level1_observation_identity_error",
            f"expected one Level-1 observation for shot {shot_id}",
        )
        validate_level1_observation(matches[0])
        return matches[0]

    def require_likelihood_ready(self) -> None:
        validate_level1_package_integrity(self)
        raise core.AdapterError(
            "level1_error_semantics_unknown",
            "no Level-1 record has provider-bound standard-deviation, covariance, "
            "calibration, or likelihood semantics",
        )


def _load_acquired_array(
    shot_dir: Path,
    entry: Mapping[str, Any],
) -> np.ndarray:
    name = str(entry.get("name"))
    raw_path = shot_dir / f"{name}.raw"
    compressed_path = shot_dir / f"{name}.blosc"
    core._require(
        raw_path.is_file() and compressed_path.is_file(),
        "level1_source_file_missing",
        f"missing acquired files for {name}",
    )
    raw_bytes = raw_path.read_bytes()
    core._require(
        core.sha256_bytes(raw_bytes) == entry.get("raw_sha256")
        and len(raw_bytes) == entry.get("raw_bytes"),
        "level1_raw_hash_mismatch",
        f"{raw_path} differs from its acquisition receipt",
    )
    core._require(
        core.sha256_file(compressed_path) == entry.get("compressed_sha256"),
        "level1_compressed_hash_mismatch",
        f"{compressed_path} differs from its acquisition receipt",
    )
    metadata = entry.get("metadata", {})
    shape = tuple(metadata.get("shape", []))
    core._require(
        metadata.get("dtype") == "<f4"
        and metadata.get("order") == "C"
        and metadata.get("chunks") == list(shape)
        and metadata.get("filters") is None
        and len(shape) in {1, 2},
        "level1_array_storage_contract_error",
        f"{name}: unsupported Zarr-v2 storage contract",
    )
    core._require(
        len(raw_bytes) == int(np.prod(shape)) * 4,
        "level1_raw_size_mismatch",
        f"{name}: byte count does not match shape",
    )
    array = _readonly_f32(np.frombuffer(raw_bytes, dtype="<f4").reshape(shape))
    finite = array[np.isfinite(array)]
    core._require(
        int(finite.size) == entry.get("finite_count")
        and int(array.size) == entry.get("total_count")
        and int(np.count_nonzero(finite < 0.0)) == entry.get("negative_finite_count"),
        "level1_acquisition_stat_mismatch",
        f"{name}: recomputed counts differ from acquisition receipt",
    )
    if finite.size:
        core._require(
            float(finite.min()) == entry.get("minimum")
            and float(finite.max()) == entry.get("maximum"),
            "level1_acquisition_stat_mismatch",
            f"{name}: recomputed extrema differ from acquisition receipt",
        )
    return array


def _load_shot(
    source_root: Path,
    shot_contract: Mapping[str, Any],
) -> Level1ErrorObservation:
    shot_id = int(shot_contract["shot_id"])
    shot_dir = (source_root / str(shot_contract["directory"])).resolve()
    core._require(
        shot_dir.parent == source_root,
        "level1_source_path_error",
        f"shot path escapes source root: {shot_dir}",
    )
    acquisition_path = shot_dir / "acquisition.json"
    metadata_path = shot_dir / "zmetadata.json"
    core._require(
        acquisition_path.is_file() and metadata_path.is_file(),
        "level1_source_file_missing",
        f"shot {shot_id}: acquisition or metadata missing",
    )
    acquisition_hash = core.sha256_file(acquisition_path)
    metadata_hash = core.sha256_file(metadata_path)
    core._require(
        acquisition_hash == shot_contract.get("acquisition_sha256"),
        "level1_acquisition_hash_mismatch",
        f"shot {shot_id}: acquisition receipt changed",
    )
    core._require(
        metadata_hash == shot_contract.get("zmetadata_sha256"),
        "level1_metadata_hash_mismatch",
        f"shot {shot_id}: zmetadata changed",
    )
    acquisition = core._load_json(acquisition_path, "level1_acquisition_read_error")
    core._require(
        acquisition.get("schema") == "mast-level1-raw-acquisition-v1"
        and acquisition.get("shot") == shot_id
        and acquisition.get("metadata_sha256") == metadata_hash
        and acquisition.get("error_semantics")
        == "unverified_not_assumed_standard_deviation"
        and acquisition.get("likelihood_ready") is False
        and acquisition.get("scientific_acceptance") is False
        and acquisition.get("exit_code") == 0
        and acquisition.get("failures") == [],
        "level1_acquisition_contract_error",
        f"shot {shot_id}: acquisition receipt does not preserve the frozen scope",
    )
    core._require(
        ACQUISITION_SCRIPT.is_file()
        and core.sha256_file(ACQUISITION_SCRIPT) == acquisition.get("script_sha256"),
        "level1_acquisition_script_hash_mismatch",
        "acquisition implementation differs from the receipt",
    )
    entries = {str(item.get("name")): item for item in acquisition.get("arrays", [])}
    core._require(
        len(entries) == len(ACQUIRED_ARRAYS)
        and set(entries) == set(ACQUIRED_ARRAYS),
        "level1_array_set_error",
        f"shot {shot_id}: expected the frozen ten-array acquisition",
    )
    arrays = {name: _load_acquired_array(shot_dir, entries[name]) for name in entries}
    expected_shape = tuple(shot_contract["shape"])
    for name in OBSERVATION_ARRAYS:
        entry = entries[name]
        core._require(
            arrays[name].shape == expected_shape
            and entry.get("attributes", {}).get("_ARRAY_DIMENSIONS")
            == list(CANONICAL_DIMENSIONS)
            and entry.get("attributes", {}).get("units") == ARRAY_UNITS[name],
            "level1_array_contract_error",
            f"shot {shot_id} {name}: shape/dimensions/unit differ",
        )
    core._require(
        arrays["time"].shape == (expected_shape[0],)
        and entries["time"].get("attributes", {}).get("_ARRAY_DIMENSIONS") == ["time"]
        and entries["time"].get("attributes", {}).get("units") == "s"
        and arrays["radial_index"].shape == (expected_shape[1],)
        and entries["radial_index"].get("attributes", {}).get("_ARRAY_DIMENSIONS")
        == ["radial_index"]
        and entries["radial_index"].get("attributes", {}).get("units") == " arb ",
        "level1_coordinate_contract_error",
        f"shot {shot_id}: coordinate shape/dimensions/unit differ",
    )
    source_records = {
        name: {
            "path": f"{shot_contract['directory']}/{name}.raw",
            "compressed_path": f"{shot_contract['directory']}/{name}.blosc",
            "raw_sha256": entries[name]["raw_sha256"],
            "compressed_sha256": entries[name]["compressed_sha256"],
            "metadata": entries[name]["metadata"],
            "attributes": entries[name]["attributes"],
            "url": entries[name]["url"],
        }
        for name in entries
    }
    primary_mask = np.logical_and.reduce(
        [np.isfinite(arrays[name]) for name in OBSERVATION_ARRAYS]
    )
    observed_mask = _readonly_bool(primary_mask)
    payload_hash = _payload_hash(
        shot_id=shot_id,
        split=str(shot_contract["split"]),
        shape=expected_shape,
        source_directory=str(shot_contract["directory"]),
        acquisition_sha256=acquisition_hash,
        zmetadata_sha256=metadata_hash,
        arrays={name: arrays[name] for name in OBSERVATION_ARRAYS + COORDINATE_ARRAYS},
        source_records=source_records,
    )
    lineage_hash = _sample_lineage_hash(payload_hash, arrays, observed_mask)
    observation = Level1ErrorObservation(
        shot_id=shot_id,
        split=str(shot_contract["split"]),
        dimensions=CANONICAL_DIMENSIONS,
        shape=expected_shape,
        ne=arrays["ne"],
        te=arrays["te"],
        ne_error=arrays["ne_error"],
        te_error=arrays["te_error"],
        covariance_ne_te=arrays["covariance_ne_te"],
        radius_m=arrays["radius"],
        time_s=arrays["time"],
        radial_index=arrays["radial_index"],
        observed_mask=observed_mask,
        source_directory=str(shot_contract["directory"]),
        acquisition_sha256=acquisition_hash,
        zmetadata_sha256=metadata_hash,
        source_records=source_records,
        error_semantics="unverified_not_assumed_standard_deviation",
        likelihood_ready=False,
        canonical_payload_sha256=payload_hash,
        sample_lineage_sha256=lineage_hash,
    )
    validate_level1_observation(observation)
    return observation


def validate_level1_observation(
    observation: Level1ErrorObservation,
) -> dict[str, Any]:
    expected = {int(item["shot_id"]): item for item in EXPECTED_SHOTS}.get(
        observation.shot_id
    )
    core._require(
        expected is not None
        and observation.split == expected["split"]
        and observation.source_directory == expected["directory"]
        and observation.acquisition_sha256 == expected["acquisition_sha256"]
        and observation.zmetadata_sha256 == expected["zmetadata_sha256"]
        and list(observation.shape) == expected["shape"]
        and observation.dimensions == CANONICAL_DIMENSIONS,
        "level1_observation_identity_error",
        f"shot {observation.shot_id}: identity/split/shape differs",
    )
    arrays = observation.arrays
    core._require(
        set(observation.source_records) == set(ACQUIRED_ARRAYS),
        "level1_observation_source_record_error",
        "source-record array set differs from the acquired package",
    )
    actual_source_records_hash = _source_records_hash(observation.source_records)
    core._require(
        actual_source_records_hash == expected["source_records_sha256"],
        "level1_source_records_binding_error",
        f"shot {observation.shot_id}: live source records differ from the frozen acquisition receipt",
    )
    core._require(
        isinstance(observation.observed_mask, np.ndarray)
        and observation.observed_mask.dtype == np.dtype(np.bool_)
        and observation.observed_mask.shape == observation.shape
        and bool(observation.observed_mask.flags.c_contiguous)
        and not bool(observation.observed_mask.flags.writeable),
        "level1_observation_mask_contract_error",
        "observed_mask must be a read-only contiguous bool array with canonical shape",
    )
    for name, array in arrays.items():
        core._require(
            isinstance(array, np.ndarray)
            and array.dtype == np.dtype("<f4")
            and bool(array.flags.c_contiguous)
            and not bool(array.flags.writeable),
            "level1_observation_array_contract_error",
            f"{name}: expected read-only contiguous little-endian float32",
        )
        live_raw_hash = hashlib.sha256(array.tobytes(order="C")).hexdigest()
        core._require(
            live_raw_hash == observation.source_records[name]["raw_sha256"],
            "level1_source_array_binding_error",
            f"shot {observation.shot_id} {name}: live canonical bytes differ from the frozen raw acquisition",
        )
    for name in OBSERVATION_ARRAYS:
        core._require(
            arrays[name].shape == observation.shape,
            "level1_observation_shape_error",
            f"{name}: shape differs",
        )
    core._require(
        observation.time_s.shape == (observation.shape[0],)
        and observation.radial_index.shape == (observation.shape[1],)
        and bool(np.isfinite(observation.time_s).all())
        and bool(np.all(np.diff(observation.time_s) > 0.0))
        and np.array_equal(
            observation.radial_index,
            np.arange(observation.shape[1], dtype="<f4"),
        ),
        "level1_observation_coordinate_error",
        "time/radial_index coordinates differ from the acquired contract",
    )
    value_masks = [
        np.isfinite(getattr(observation, name))
        for name in ("ne", "te", "ne_error", "te_error", "covariance_ne_te")
    ]
    core._require(
        all(np.array_equal(value_masks[0], mask) for mask in value_masks[1:])
        and np.all(np.isfinite(observation.radius_m[value_masks[0]]))
        and np.array_equal(observation.observed_mask, value_masks[0])
        and bool(np.all(observation.ne_error[observation.observed_mask] > 0.0))
        and bool(np.all(observation.te_error[observation.observed_mask] > 0.0)),
        "level1_observation_alignment_error",
        "measurement/error/covariance/radius masks or reported error values differ",
    )
    core._require(
        observation.error_semantics == "unverified_not_assumed_standard_deviation"
        and observation.likelihood_ready is False
        and observation.source_records["ne_error"]["attributes"].get("units") == ""
        and observation.source_records["te_error"]["attributes"].get("units") == "",
        "level1_error_semantics_contract_error",
        "blank units or unknown statistical semantics were not preserved",
    )
    actual_payload = _payload_hash(
        shot_id=observation.shot_id,
        split=observation.split,
        shape=observation.shape,
        source_directory=observation.source_directory,
        acquisition_sha256=observation.acquisition_sha256,
        zmetadata_sha256=observation.zmetadata_sha256,
        arrays=arrays,
        source_records=observation.source_records,
    )
    core._require(
        actual_payload == observation.canonical_payload_sha256,
        "level1_payload_hash_mismatch",
        f"shot {observation.shot_id}: canonical content identity is stale",
    )
    actual_lineage = _sample_lineage_hash(
        actual_payload, arrays, observation.observed_mask
    )
    core._require(
        actual_lineage == observation.sample_lineage_sha256,
        "level1_sample_lineage_hash_mismatch",
        f"shot {observation.shot_id}: cell lineage identity is stale",
    )
    return {
        "status": "pass",
        "record_id": observation.record_id,
        "canonical_payload_sha256": actual_payload,
        "sample_lineage_sha256": actual_lineage,
        "source_records_sha256": actual_source_records_hash,
        "observed_count": observation.observed_count,
    }


def conditional_error_consistency(
    observation: Level1ErrorObservation,
) -> dict[str, Any]:
    """Run a conditional Cauchy/2x2-PSD check without assigning semantics."""

    validate_level1_observation(observation)
    mask = (
        observation.observed_mask
        & (observation.ne_error > 0.0)
        & (observation.te_error > 0.0)
    )
    numerator = observation.covariance_ne_te[mask].astype(np.float64)
    denominator = observation.ne_error[mask].astype(np.float64) * observation.te_error[
        mask
    ].astype(np.float64)
    rho = numerator / denominator
    finite = np.isfinite(rho)
    rho = rho[finite]
    violations = int(np.count_nonzero(np.abs(rho) > 1.0))
    return {
        "status": "conditional_assumption_check_only",
        "assumption": (
            "ne_error and te_error are positive one-standard-deviation scales in "
            "the corresponding signal units, and covariance_ne_te is their covariance"
        ),
        "assumption_supported_by_provider_evidence": False,
        "eligible_cell_count": int(mask.sum()),
        "finite_rho_star_count": int(rho.size),
        "rho_star_min": float(rho.min()) if rho.size else None,
        "rho_star_max": float(rho.max()) if rho.size else None,
        "abs_rho_star_gt_one_count": violations,
        "conditional_2x2_psd_failure_count": violations,
        "interpretation": (
            "violations reject the complete stated assumption set at those cells; "
            "the diagnostic does not identify actual error semantics or authorize a likelihood"
        ),
        "error_semantics": "unknown",
        "likelihood_ready": False,
    }


def iter_level1_cells(
    observation: Level1ErrorObservation,
) -> Iterator[dict[str, Any]]:
    """Yield aligned Level-1 reported values with raw/canonical identity mapping."""

    validate_level1_observation(observation)
    for t_index, r_index in np.argwhere(observation.observed_mask):
        t, r = int(t_index), int(r_index)
        sample_id = f"{observation.record_id}:t{t}:ri{r}"
        digest = hashlib.sha256()
        digest.update(b"FusionConceptAI.reference_validation.level1_cell.v1\0")
        digest.update(observation.canonical_payload_sha256.encode("ascii"))
        digest.update(sample_id.encode("utf-8"))
        digest.update(struct.pack("<II", t, r))
        yield {
            "sample_id": sample_id,
            "sample_sha256": digest.hexdigest(),
            "record_id": observation.record_id,
            "raw_index": [t, r],
            "canonical_index": [t, r],
            "time_s": float(observation.time_s[t]),
            "radial_index": float(observation.radial_index[r]),
            "radius_m": float(observation.radius_m[t, r]),
            "ne": float(observation.ne[t, r]),
            "te": float(observation.te[t, r]),
            "ne_error_reported": float(observation.ne_error[t, r]),
            "te_error_reported": float(observation.te_error[t, r]),
            "covariance_ne_te_reported": float(
                observation.covariance_ne_te[t, r]
            ),
            "error_semantics": "unknown",
            "likelihood_ready": False,
        }


def validate_level1_no_leakage(
    observations: Sequence[Level1ErrorObservation],
    protocol: Mapping[str, Any],
) -> dict[str, Any]:
    _verify_protocol(protocol)
    core._require(
        len(observations) == 2
        and len({item.shot_id for item in observations}) == 2
        and len({item.record_id for item in observations}) == 2,
        "level1_duplicate_observation_identity",
        "exactly one unique Level-1 record per frozen shot is required",
    )
    for item in observations:
        validate_level1_observation(item)
    by_split = {
        label: tuple(item for item in observations if item.split == label)
        for label in ("calibration", "validation", "held_out")
    }
    expected_shots = {
        "calibration": {30421},
        "validation": set(),
        "held_out": {30420},
    }
    for label, expected in expected_shots.items():
        core._require(
            {item.shot_id for item in by_split[label]} == expected,
            "level1_split_coverage_error",
            f"{label} shot coverage differs",
        )
    response_names = ("ne", "te", "ne_error", "te_error", "covariance_ne_te")
    intersections: dict[str, list[str]] = {}
    for name in response_names:
        calibration_hashes = {
            item.source_records[name]["raw_sha256"] for item in by_split["calibration"]
        }
        heldout_hashes = {
            item.source_records[name]["raw_sha256"] for item in by_split["held_out"]
        }
        overlap = sorted(calibration_hashes & heldout_hashes)
        intersections[name] = overlap
        core._require(
            not overlap,
            "level1_split_leakage",
            f"{name} raw artifact reused across calibration/held-out",
        )
    payload_overlap = {
        item.canonical_payload_sha256 for item in by_split["calibration"]
    } & {item.canonical_payload_sha256 for item in by_split["held_out"]}
    lineage_overlap = {
        item.sample_lineage_sha256 for item in by_split["calibration"]
    } & {item.sample_lineage_sha256 for item in by_split["held_out"]}
    core._require(
        not payload_overlap and not lineage_overlap,
        "level1_split_leakage",
        "canonical payload or cell lineage reused across splits",
    )
    radial_hashes = {
        item.source_records["radial_index"]["raw_sha256"] for item in observations
    }
    return {
        "schema_version": "mast_level1_error_split_receipt_v1",
        "status": "pass_no_cross_split_level1_response_or_error_artifact",
        "response_hash_intersections": intersections,
        "canonical_payload_hash_intersection": sorted(payload_overlap),
        "sample_lineage_hash_intersection": sorted(lineage_overlap),
        "counts": {label: len(records) for label, records in by_split.items()},
        "validation_status": "typed_absent",
        "shared_non_response_artifacts": {
            "radial_index_sha256": sorted(radial_hashes)
            if len(radial_hashes) == 1
            else [],
            "role": "index coordinate only",
        },
        "strict_any_artifact_policy": {
            "status": "terminal_deferred" if len(radial_hashes) == 1 else "pass",
            "reason": "both shots share the radial_index coordinate bytes"
            if len(radial_hashes) == 1
            else None,
        },
        "formal_split_ready": False,
        "claim_ceiling": "Level-1 adapter split only; no formal B03/B07B credit",
    }


def validate_level1_package_integrity(
    package: Level1ErrorPackage,
) -> dict[str, Any]:
    _verify_protocol(package.protocol)
    core._require(
        package.adapter_version == LEVEL1_ADAPTER_VERSION
        and package.protocol_sha256 == core.sha256_file(DEFAULT_PROTOCOL)
        and package.claim_ceiling == CLAIM_CEILING,
        "level1_package_metadata_error",
        "adapter version, protocol hash, or claim ceiling differs from frozen v1",
    )
    current_split = validate_level1_no_leakage(
        package.observations, package.protocol
    )
    core._require(
        core.canonical_json_bytes(current_split)
        == core.canonical_json_bytes(core._plain(dict(package.split_receipt))),
        "level1_split_receipt_stale",
        "stored split receipt differs from live Level-1 observations",
    )
    return {
        "status": "pass",
        "adapter_version": package.adapter_version,
        "protocol_sha256": package.protocol_sha256,
        "observation_count": len(package.observations),
        "error_data_status": "present_values_unknown_statistical_semantics",
        "likelihood_ready": False,
    }


def load_level1_error_package(
    source_root: Path | str = DEFAULT_SOURCE_ROOT,
    protocol_path: Path | str = DEFAULT_PROTOCOL,
) -> Level1ErrorPackage:
    source_root = Path(source_root).resolve()
    protocol_path = Path(protocol_path).resolve()
    protocol = core._load_json(protocol_path, "level1_protocol_read_error")
    _verify_protocol(protocol)
    observations = tuple(
        _load_shot(source_root, shot_contract)
        for shot_contract in protocol.get("shots", [])
    )
    split_receipt = validate_level1_no_leakage(observations, protocol)
    package = Level1ErrorPackage(
        adapter_version=LEVEL1_ADAPTER_VERSION,
        protocol=protocol,
        protocol_sha256=core.sha256_file(protocol_path),
        observations=observations,
        split_receipt=split_receipt,
        claim_ceiling=CLAIM_CEILING,
    )
    validate_level1_package_integrity(package)
    return package


def _write_bytes(path: Path, data: bytes, output: Path) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return {
        "path": str(path.relative_to(output)).replace("\\", "/"),
        "bytes": len(data),
        "sha256": core.sha256_bytes(data),
    }


def _write_json(path: Path, value: Any, output: Path) -> dict[str, Any]:
    data = json.dumps(
        value, ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2
    ).encode("utf-8") + b"\n"
    return _write_bytes(path, data, output)


def write_level1_error_package(
    package: Level1ErrorPackage,
    output: Path | str,
) -> dict[str, Any]:
    validate_level1_package_integrity(package)
    current_split = validate_level1_no_leakage(package.observations, package.protocol)
    output = Path(output).resolve()
    core._require(
        not output.exists(),
        "output_exists",
        f"refusing to overwrite existing output {output}",
    )
    output.mkdir(parents=True)
    artifacts: list[dict[str, Any]] = []
    entries: list[dict[str, Any]] = []
    for observation in package.observations:
        shot_dir = output / f"shot_{observation.shot_id}"
        files: dict[str, dict[str, Any]] = {}
        for name, values in observation.arrays.items():
            record = _write_bytes(
                shot_dir / f"{name}.f32le",
                values.astype("<f4", copy=False).tobytes(order="C"),
                output,
            )
            artifacts.append(record)
            files[name] = record
        mask_record = _write_bytes(
            shot_dir / "observed_mask.u8",
            observation.observed_mask.astype(np.uint8).tobytes(order="C"),
            output,
        )
        artifacts.append(mask_record)
        entry = observation.manifest_entry()
        entry["canonical"]["files"] = {**files, "observed_mask": mask_record}
        entries.append(entry)
    manifest = {
        "schema_version": "mast_level1_error_canonical_package_v1",
        "adapter_version": package.adapter_version,
        "protocol_sha256": package.protocol_sha256,
        "observations": entries,
        "split_receipt": current_split,
        "level2_binding": package.protocol.get("level2_binding"),
        "iter_included": False,
        "claim_ceiling": package.claim_ceiling,
    }
    report = {
        "schema_version": "mast_level1_error_adapter_report_v1",
        "task_id": "UP4-03-REFERENCE-VALIDATION-PREC",
        "program_state": "pass_with_scope",
        "records": len(entries),
        "finite_joint_cells": sum(item.observed_count for item in package.observations),
        "error_data_status": "present_values_unknown_statistical_semantics",
        "likelihood_ready": False,
        "physical_state": "unknown",
        "resolution": "terminal_deferred",
        "formal_inverse": "not_executed",
        "b03": "not_claimed",
        "b07b": "not_claimed",
        "parent_UP4_03": "not_accepted",
        "conditional_diagnostics": {
            str(item.shot_id): conditional_error_consistency(item)
            for item in package.observations
        },
        "claim_ceiling": package.claim_ceiling,
    }
    manifest_record = _write_json(output / "canonical_manifest.json", manifest, output)
    split_record = _write_json(output / "split_receipt.json", current_split, output)
    report_record = _write_json(output / "adapter_report.json", report, output)
    artifact_manifest = {
        "schema_version": "mast_level1_error_artifact_manifest_v1",
        "files": sorted(
            artifacts + [manifest_record, split_record, report_record],
            key=lambda item: item["path"],
        ),
    }
    _write_json(output / "artifact_manifest.json", artifact_manifest, output)
    return report


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Load the acquired FAIR-MAST Level-1 AYC error-data products"
    )
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    package = load_level1_error_package(args.source, args.protocol)
    report = write_level1_error_package(package, args.output)
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
