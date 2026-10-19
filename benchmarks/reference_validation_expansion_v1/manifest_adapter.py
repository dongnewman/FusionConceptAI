"""Split-first manifest adapter for the frozen FAIR-MAST Level-1 expansion.

Only calibration and validation values are indexed. Held-out and reserve
requests fail before any control or source path is opened. Reported error data
retain unknown statistical semantics and cannot enable a likelihood.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Iterator, Mapping, Sequence

import numpy as np


HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
HELPER_DIR = HERE.parent / "reference_validation_v1"
if str(HELPER_DIR) not in sys.path:
    sys.path.insert(0, str(HELPER_DIR))
import level1_error_adapter as level1  # noqa: E402

core = level1.core
ADAPTER_VERSION = "mast_level1_expansion_manifest_adapter_v1"
SCHEMA_VERSION = "mast_level1_expansion_protocol_v1"
DEFAULT_SOURCE_ROOT = HERE.parent / "reference_data_level1_expansion_v1"
DEFAULT_SELECTION = DEFAULT_SOURCE_ROOT / "selection.json"
DEFAULT_ACQUISITION_INDEX = HERE / "acquisition_index.json"
DEFAULT_PROTOCOL = HERE / "protocol.json"
HELPER_PATH = HELPER_DIR / "level1_error_adapter.py"
EXPECTED_PROTOCOL_SHA256 = "1331869e56117ff331decb8fb11c5bf863d3d9f190379e1cb624c3048d53878f"
EXPECTED_SELECTION_SHA256 = "b962c135e1569457e80efb5ab05842d73b05347ffd56732bf465f8869fa04c78"
EXPECTED_INDEX_SHA256 = "a3750fd5a7b0ad8fdfb865feeb981c05633cfab5b0d80bf8c4dd1f549bc7e045"
EXPECTED_HELPER_SHA256 = "7dcdd5c49815e7fd166ad958a9441abd71e15ebf981fccaf3e0b37038635d9af"
SELECTION_ID = "mast-ayc-m9-expansion-r1"
LOADABLE_SPLITS = {
    "calibration": (30463, 30468, 30459, 30462, 30464, 30460, 30456, 30466),
    "validation": (30469,),
}
BLOCKED_SPLITS = {
    "held_out": (30471, 30467, 30457, 30458),
    "reserve": (30461, 30470, 30465),
}
MEASUREMENT_ARRAYS = (
    "ne", "te", "ne_error", "te_error", "covariance_ne_te", "radius"
)
RESPONSE_AND_ERROR_ARRAYS = MEASUREMENT_ARRAYS[:-1]
ACQUIRED_ARRAYS = (
    "ne", "te", "ne_error", "te_error", "covariance_ne_te",
    "time", "radial_index", "radius", "instrument_dr", "instrument_time",
)
ARRAY_UNITS = {
    "ne": "1 / m ** 3", "te": "eV", "ne_error": "", "te_error": "",
    "covariance_ne_te": "eV / m ** 3", "time": "s",
    "radial_index": " arb ", "radius": "m", "instrument_dr": "m",
    "instrument_time": "s",
}
INDEX_ARRAY_KEYS = (
    "attributes", "compressed_sha256", "finite_count", "maximum", "metadata",
    "minimum", "name", "negative_finite_count", "raw_bytes", "raw_sha256",
    "status", "total_count",
)
CLAIM_CEILING = (
    "manifest-driven Level-1 calibration/validation data preparation only; "
    "held-out and reserve values remain unreleased; error statistics, calibrated "
    "diagnostic response, formal inverse, B03, B07B, physical independence, ITER "
    "measurement status, and parent UP4-03 acceptance remain deferred"
)


def _guard_split(split: str) -> None:
    if split in BLOCKED_SPLITS:
        raise core.AdapterError(
            "expansion_split_release_required",
            f"{split} has no indexed source paths; a versioned post-optimizer release is required",
        )
    core._require(
        split in LOADABLE_SPLITS,
        "expansion_split_not_supported",
        f"split must be one of {sorted(LOADABLE_SPLITS)}",
    )


def _is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str) and len(value) == 64
        and all(c in "0123456789abcdef" for c in value)
    )


def _verify_protocol(protocol: Mapping[str, Any]) -> None:
    split = protocol.get("split_contract", {})
    canonical = protocol.get("canonical_contract", {})
    core._require(
        protocol.get("schema_version") == SCHEMA_VERSION
        and protocol.get("protocol_id") == "UP4-03-reference-validation-level1-expansion-v1"
        and protocol.get("source_root") == "benchmarks/reference_data_level1_expansion_v1"
        and protocol.get("selection", {}).get("sha256") == EXPECTED_SELECTION_SHA256
        and protocol.get("acquisition_index", {}).get("sha256") == EXPECTED_INDEX_SHA256
        and protocol.get("verified_helper", {}).get("sha256") == EXPECTED_HELPER_SHA256
        and split.get("loadable") == {k: list(v) for k, v in LOADABLE_SPLITS.items()}
        and split.get("release_required") == {k: list(v) for k, v in BLOCKED_SPLITS.items()}
        and split.get("one_split_per_execution") is True
        and split.get("formal_minimum_met") is False
        and canonical.get("dimensions") == ["time", "radial_index"]
        and canonical.get("dtype") == "float32_little_endian"
        and canonical.get("array_names") == list(ACQUIRED_ARRAYS)
        and canonical.get("scale") == 1.0 and canonical.get("offset") == 0.0
        and canonical.get("resampling") == "none" and canonical.get("imputation") == "none",
        "unsupported_expansion_protocol",
        "source, helper, split, or canonical contract differs from frozen v1",
    )
    errors = protocol.get("error_semantics", {})
    release = protocol.get("held_out_release", {})
    core._require(
        errors.get("status") == "present_values_unknown_statistical_semantics"
        and errors.get("standard_deviation_interpretation") == "prohibited"
        and errors.get("covariance_likelihood_interpretation") == "prohibited"
        and errors.get("likelihood_ready") is False
        and release.get("status") == "release_required_no_source_paths_indexed"
        and protocol.get("formal_acceptance") is False
        and protocol.get("iter_included") is False
        and protocol.get("claim_ceiling") == CLAIM_CEILING,
        "unsupported_expansion_protocol",
        "uncertainty, release, acceptance, ITER, or claim ceiling differs",
    )


def _validate_index_paths(index: Mapping[str, Any]) -> None:
    records = index.get("records")
    core._require(
        isinstance(records, list),
        "expansion_acquisition_index_contract_error",
        "acquisition index records must be a list",
    )
    for record in records:
        relative = record.get("relative_directory") if isinstance(record, dict) else None
        split = record.get("split") if isinstance(record, dict) else None
        shot_id = record.get("shot_id") if isinstance(record, dict) else None
        valid = isinstance(relative, str) and "\\" not in relative
        parts = PurePosixPath(relative).parts if valid else ()
        valid = (
            valid and not PurePosixPath(relative).is_absolute() and ".." not in parts
            and parts == (str(split), f"shot{shot_id}_r1") and split in LOADABLE_SPLITS
        )
        core._require(
            valid, "expansion_source_path_error",
            f"unsafe or non-canonical indexed directory: {relative!r}",
        )


def _validate_selection(selection: Mapping[str, Any]) -> None:
    policy = selection.get("selection_algorithm", {})
    core._require(
        selection.get("schema") == "mast-level1-expansion-acquisition-selection-v1"
        and selection.get("selection_id") == SELECTION_ID
        and selection.get("status") == "frozen_acquisition_only_not_formal_b03"
        and policy.get("selection_was_frozen_before_acquisition") is True
        and policy.get("response_value_filtering") == "prohibited",
        "expansion_selection_contract_error",
        "selection identity or pre-acquisition/no-filter policy differs",
    )
    groups = selection.get("groups", {})
    for name, ids in {**LOADABLE_SPLITS, **BLOCKED_SPLITS}.items():
        group = groups.get(name, {})
        acquire = name in LOADABLE_SPLITS
        core._require(
            group.get("shot_ids") == list(ids) and group.get("count") == len(ids)
            and group.get("acquire_metadata") is acquire
            and group.get("acquire_arrays") is acquire,
            "expansion_selection_group_error",
            f"selection group {name} differs from the frozen assignment",
        )
    ids = [shot for shots in {**LOADABLE_SPLITS, **BLOCKED_SPLITS}.values() for shot in shots]
    candidates = selection.get("candidate_metadata", [])
    core._require(
        len(candidates) == len(ids) and {x.get("shot_id") for x in candidates} == set(ids)
        and len({x.get("catalog_uuid") for x in candidates}) == len(ids)
        and len({x.get("selection_key_sha256") for x in candidates}) == len(ids)
        and all(_is_sha256(x.get("selection_key_sha256")) for x in candidates),
        "expansion_selection_candidate_error",
        "candidate identities are incomplete or duplicated",
    )
    acquisition = selection.get("acquisition_contract", {})
    core._require(
        acquisition.get("array_names_per_selected_shot") == list(ACQUIRED_ARRAYS)
        and acquisition.get("array_count_per_selected_shot") == len(ACQUIRED_ARRAYS),
        "expansion_selection_contract_error",
        "selection acquisition array contract differs",
    )


def _array_entries(record: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    arrays = record.get("arrays", [])
    core._require(
        isinstance(arrays, list) and len(arrays) == len(ACQUIRED_ARRAYS)
        and [x.get("name") for x in arrays] == list(ACQUIRED_ARRAYS),
        "expansion_array_set_error",
        f"shot {record.get('shot_id')}: expected ordered ten-array acquisition",
    )
    return {str(item["name"]): item for item in arrays}


def _record_shape(record: Mapping[str, Any]) -> tuple[int, int]:
    entries = _array_entries(record)
    raw_shape = entries["ne"].get("metadata", {}).get("shape")
    core._require(
        isinstance(raw_shape, list) and len(raw_shape) == 2
        and isinstance(raw_shape[0], int) and raw_shape[0] > 0 and raw_shape[1] == 131,
        "expansion_array_shape_error",
        f"shot {record.get('shot_id')}: unsupported ne shape",
    )
    shape = (raw_shape[0], raw_shape[1])
    shapes = {**{n: shape for n in MEASUREMENT_ARRAYS}, "time": (shape[0],),
              "radial_index": (shape[1],), "instrument_dr": (20, shape[1]),
              "instrument_time": (20,)}
    dims = {**{n: ["time", "radial_index"] for n in MEASUREMENT_ARRAYS},
            "time": ["time"], "radial_index": ["radial_index"],
            "instrument_dr": ["instrument_time", "radial_index"],
            "instrument_time": ["instrument_time"]}
    for name, entry in entries.items():
        metadata, attrs = entry.get("metadata", {}), entry.get("attributes", {})
        entry_shape = tuple(metadata.get("shape", []))
        total = int(np.prod(entry_shape)) if entry_shape else -1
        core._require(
            entry_shape == shapes[name] and metadata.get("dtype") == "<f4"
            and metadata.get("order") == "C" and metadata.get("chunks") == list(entry_shape)
            and metadata.get("filters") is None and metadata.get("zarr_format") == 2
            and metadata.get("compressor", {}).get("id") == "blosc"
            and attrs.get("_ARRAY_DIMENSIONS") == dims[name]
            and attrs.get("units") == ARRAY_UNITS[name]
            and entry.get("raw_bytes") == total * 4 and entry.get("total_count") == total
            and isinstance(entry.get("finite_count"), int)
            and 0 <= entry["finite_count"] <= total
            and isinstance(entry.get("negative_finite_count"), int)
            and 0 <= entry["negative_finite_count"] <= entry["finite_count"]
            and _is_sha256(entry.get("raw_sha256"))
            and _is_sha256(entry.get("compressed_sha256"))
            and entry.get("status") == "decoded_raw_values_no_uncertainty_interpretation",
            "expansion_array_contract_error",
            f"shot {record.get('shot_id')} {name}: storage/shape/dimension/unit differs",
        )
    return shape


def validate_acquisition_index_no_leakage(
    index: Mapping[str, Any], selection: Mapping[str, Any]
) -> dict[str, Any]:
    """Check frozen identities and response/error separation without loading values."""
    _validate_selection(selection)
    _validate_index_paths(index)
    candidates = {int(x["shot_id"]): x for x in selection.get("candidate_metadata", [])}
    records = index.get("records", [])
    expected = [(s, shot) for s, shots in LOADABLE_SPLITS.items() for shot in shots]
    actual = [(x.get("split"), x.get("shot_id")) for x in records]
    core._require(
        index.get("schema_version") == "mast_level1_expansion_acquisition_index_v1"
        and index.get("selection_id") == SELECTION_ID
        and index.get("selection_sha256") == EXPECTED_SELECTION_SHA256
        and index.get("included_splits") == list(LOADABLE_SPLITS) and actual == expected,
        "expansion_acquisition_index_contract_error",
        "index identity, selection binding, splits, or order differs",
    )
    expected_blocked = {k: {"shot_ids": list(v), "status": "release_required_no_source_paths_indexed"}
                        for k, v in BLOCKED_SPLITS.items()}
    core._require(
        index.get("blocked_splits") == expected_blocked
        and index.get("combination_unit") == "one complete shot-level paired AYC ne/te bundle"
        and str(index.get("error_semantics", "")).startswith("unknown;"),
        "expansion_acquisition_index_contract_error",
        "index blocking, combination, or error semantics differs",
    )
    seen = {name: set() for name in ("shot", "catalog", "selection_key", "directory")}
    by_split: dict[str, list[dict[str, Mapping[str, Any]]]] = {k: [] for k in LOADABLE_SPLITS}
    for record in records:
        shot = int(record["shot_id"])
        candidate = candidates.get(shot, {})
        core._require(
            record.get("catalog_uuid") == candidate.get("catalog_uuid")
            and record.get("selection_key_sha256") == candidate.get("selection_key_sha256")
            and record.get("error_semantics") == "unverified_not_assumed_standard_deviation"
            and record.get("likelihood_ready") is False
            and _is_sha256(record.get("acquisition_receipt_sha256"))
            and _is_sha256(record.get("zmetadata_sha256"))
            and record.get("acquisition_script_sha256") == core.sha256_file(level1.ACQUISITION_SCRIPT),
            "expansion_acquisition_index_contract_error",
            f"shot {shot}: provenance or semantics differs",
        )
        _record_shape(record)
        identities = {"shot": shot, "catalog": record["catalog_uuid"],
                      "selection_key": record["selection_key_sha256"],
                      "directory": record["relative_directory"]}
        for name, value in identities.items():
            core._require(value not in seen[name], "expansion_duplicate_identity", f"duplicate {name}")
            seen[name].add(value)
        by_split[str(record["split"])].append(_array_entries(record))
    response_overlap, all_overlap = {}, {}
    for name in ACQUIRED_ARRAYS:
        calibration = {x[name]["raw_sha256"] for x in by_split["calibration"]}
        validation = {x[name]["raw_sha256"] for x in by_split["validation"]}
        overlap = sorted(calibration & validation)
        all_overlap[name] = overlap
        if name in RESPONSE_AND_ERROR_ARRAYS:
            response_overlap[name] = overlap
            core._require(not overlap, "expansion_split_leakage", f"{name} is reused across splits")
    calibration_response_hashes = {
        arrays[name]["raw_sha256"]
        for arrays in by_split["calibration"]
        for name in RESPONSE_AND_ERROR_ARRAYS
    }
    validation_response_hashes = {
        arrays[name]["raw_sha256"]
        for arrays in by_split["validation"]
        for name in RESPONSE_AND_ERROR_ARRAYS
    }
    global_response_overlap = sorted(calibration_response_hashes & validation_response_hashes)
    core._require(
        not global_response_overlap,
        "expansion_split_leakage",
        "a response/error artifact is reused across splits under different array names",
    )
    shared = {k: v for k, v in all_overlap.items() if k not in RESPONSE_AND_ERROR_ARRAYS and v}
    return {
        "schema_version": "mast_level1_expansion_index_leakage_receipt_v1",
        "status": "pass_no_cross_split_response_or_error_artifact",
        "response_error_hash_intersections": response_overlap,
        "global_response_error_hash_intersection": global_response_overlap,
        "shared_non_response_artifacts": shared,
        "strict_any_artifact_policy": {
            "status": "terminal_deferred" if shared else "pass",
            "reason": "coordinate/instrument artifacts are shared across included splits" if shared else None,
        },
        "counts": {k: len(v) for k, v in LOADABLE_SPLITS.items()},
        "held_out_status": "release_required_no_source_paths_indexed",
        "formal_split_ready": False,
    }


def _load_control(
    split: str, protocol_path: Path | str, selection_path: Path | str,
    index_path: Path | str,
) -> dict[str, Any]:
    _guard_split(split)
    protocol_path, selection_path, index_path = map(
        lambda value: Path(value).resolve(), (protocol_path, selection_path, index_path)
    )
    protocol = core._load_json(protocol_path, "expansion_protocol_read_error")
    selection = core._load_json(selection_path, "expansion_selection_read_error")
    index = core._load_json(index_path, "expansion_acquisition_index_read_error")
    _validate_index_paths(index)  # path safety precedes any source-data open
    hashes = {
        "protocol_sha256": core.sha256_file(protocol_path),
        "selection_sha256": core.sha256_file(selection_path),
        "index_sha256": core.sha256_file(index_path),
        "helper_sha256": core.sha256_file(HELPER_PATH),
    }
    for name, expected, code in (
        ("protocol_sha256", EXPECTED_PROTOCOL_SHA256, "expansion_protocol_hash_mismatch"),
        ("selection_sha256", EXPECTED_SELECTION_SHA256, "expansion_selection_hash_mismatch"),
        ("index_sha256", EXPECTED_INDEX_SHA256, "expansion_acquisition_index_hash_mismatch"),
        ("helper_sha256", EXPECTED_HELPER_SHA256, "expansion_helper_hash_mismatch"),
    ):
        core._require(hashes[name] == expected, code, f"{name} differs from frozen v1")
    _verify_protocol(protocol)
    _validate_selection(selection)
    leakage = validate_acquisition_index_no_leakage(index, selection)
    return {"protocol": protocol, "selection": selection, "index": index,
            "index_leakage_receipt": leakage, **hashes}


def inspect_selection_manifest(
    split: str, *, protocol_path: Path | str = DEFAULT_PROTOCOL,
    selection_path: Path | str = DEFAULT_SELECTION,
    index_path: Path | str = DEFAULT_ACQUISITION_INDEX,
) -> dict[str, Any]:
    control = _load_control(split, protocol_path, selection_path, index_path)
    records = [x for x in control["index"]["records"] if x["split"] == split]
    return {
        "selection_id": SELECTION_ID, "split": split,
        "shot_ids": [x["shot_id"] for x in records], "combination_count": len(records),
        "selection_sha256": control["selection_sha256"],
        "acquisition_index_sha256": control["index_sha256"],
        "helper_sha256": control["helper_sha256"],
        "held_out_status": "release_required_no_source_paths_indexed",
        "formal_split_ready": False,
    }


def _resolve_shot_directory(root: Path, relative: str, split: str, shot: int) -> Path:
    parts = PurePosixPath(relative).parts
    core._require(
        parts == (split, f"shot{shot}_r1") and ".." not in parts,
        "expansion_source_path_error", f"shot {shot}: directory is not canonical",
    )
    result = (root / Path(*parts)).resolve()
    try:
        result.relative_to(root)
    except ValueError as exc:
        raise core.AdapterError("expansion_source_path_error", f"shot {shot}: path escapes root") from exc
    core._require(result.parent == (root / split).resolve(), "expansion_source_path_error",
                  f"shot {shot}: path escapes split")
    return result


def _project_array(entry: Mapping[str, Any]) -> dict[str, Any]:
    return {key: core._plain(entry.get(key)) for key in INDEX_ARRAY_KEYS}


def _source_records(record: Mapping[str, Any]) -> dict[str, dict[str, Any]]:
    relative = str(record["relative_directory"])
    return {
        str(entry["name"]): {
            "path": f"{relative}/{entry['name']}.raw",
            "compressed_path": f"{relative}/{entry['name']}.blosc",
            "raw_sha256": entry["raw_sha256"],
            "compressed_sha256": entry["compressed_sha256"],
            "metadata": core._plain(entry["metadata"]),
            "attributes": core._plain(entry["attributes"]),
        } for entry in record["arrays"]
    }


def _source_records_hash(records: Mapping[str, Mapping[str, Any]]) -> str:
    try:
        normalized = {name: core._plain(dict(records[name])) for name in sorted(records)}
        return hashlib.sha256(core.canonical_json_bytes(normalized)).hexdigest()
    except (KeyError, TypeError, ValueError) as exc:
        raise core.AdapterError("expansion_source_records_binding_error", str(exc)) from exc


def _payload_hash(
    *, shot_id: int, source_directory: str, acquisition_sha256: str,
    zmetadata_sha256: str, selection_key_sha256: str, catalog_uuid: str,
    shape: tuple[int, int], arrays: Mapping[str, np.ndarray],
    source_records: Mapping[str, Mapping[str, Any]],
) -> str:
    base = level1._payload_hash(
        shot_id=shot_id, split="split_independent", shape=shape,
        source_directory=source_directory, acquisition_sha256=acquisition_sha256,
        zmetadata_sha256=zmetadata_sha256, arrays=arrays, source_records=source_records,
    )
    identity = {
        "domain": "FusionConceptAI.reference_validation.level1_expansion_observation.v1",
        "selection_id": SELECTION_ID, "selection_sha256": EXPECTED_SELECTION_SHA256,
        "acquisition_index_sha256": EXPECTED_INDEX_SHA256,
        "verified_helper_sha256": EXPECTED_HELPER_SHA256, "shot_id": shot_id,
        "selection_key_sha256": selection_key_sha256, "catalog_uuid": catalog_uuid,
        "helper_payload_sha256": base,
    }
    return hashlib.sha256(core.canonical_json_bytes(identity)).hexdigest()


@dataclass(frozen=True)
class ExpansionObservation:
    shot_id: int
    split: str
    catalog_uuid: str
    selection_key_sha256: str
    source_directory: str
    acquisition_sha256: str
    zmetadata_sha256: str
    shape: tuple[int, int]
    arrays: Mapping[str, np.ndarray]
    observed_mask: np.ndarray
    source_records: Mapping[str, Mapping[str, Any]]
    source_records_sha256: str
    error_semantics: str
    likelihood_ready: bool
    canonical_payload_sha256: str
    sample_lineage_sha256: str

    @property
    def record_id(self) -> str:
        return f"mast:{self.shot_id}:level1:ayc:expansion:{SELECTION_ID}"

    @property
    def observed_count(self) -> int:
        return int(self.observed_mask.sum())

    def require_likelihood_ready(self) -> None:
        validate_expansion_observation(self)
        raise core.AdapterError(
            "expansion_error_semantics_unknown",
            "reported error data lack provider statistical/calibration semantics",
        )


@dataclass(frozen=True)
class ExpansionPackage:
    adapter_version: str
    split: str
    protocol: Mapping[str, Any]
    protocol_sha256: str
    selection_sha256: str
    acquisition_index_sha256: str
    helper_sha256: str
    observations: tuple[ExpansionObservation, ...]
    split_receipt: Mapping[str, Any]
    error_semantics: str
    likelihood_ready: bool
    claim_ceiling: str

    def observation(self, shot_id: int) -> ExpansionObservation:
        matches = [x for x in self.observations if x.shot_id == shot_id]
        core._require(len(matches) == 1, "expansion_observation_identity_error",
                      f"expected one observation for shot {shot_id}")
        validate_expansion_observation(matches[0])
        return matches[0]

    def require_likelihood_ready(self) -> None:
        validate_expansion_package(self)
        raise core.AdapterError(
            "expansion_error_semantics_unknown",
            "no record has provider-bound uncertainty, calibration, or likelihood semantics",
        )


def _record_for(observation: ExpansionObservation, control: Mapping[str, Any]) -> Mapping[str, Any]:
    matches = [x for x in control["index"]["records"] if x["shot_id"] == observation.shot_id]
    core._require(len(matches) == 1, "expansion_observation_identity_error",
                  f"shot {observation.shot_id}: no unique frozen record")
    return matches[0]


def _load_record(root: Path, record: Mapping[str, Any]) -> ExpansionObservation:
    split, shot = str(record["split"]), int(record["shot_id"])
    shot_dir = _resolve_shot_directory(root, str(record["relative_directory"]), split, shot)
    acquisition_path, metadata_path = shot_dir / "acquisition.json", shot_dir / "zmetadata.json"
    core._require(acquisition_path.is_file() and metadata_path.is_file(),
                  "expansion_source_file_missing", f"shot {shot}: source package missing")
    acquisition_hash, metadata_hash = core.sha256_file(acquisition_path), core.sha256_file(metadata_path)
    core._require(acquisition_hash == record["acquisition_receipt_sha256"],
                  "expansion_acquisition_hash_mismatch", f"shot {shot}: receipt changed")
    core._require(metadata_hash == record["zmetadata_sha256"],
                  "expansion_zmetadata_hash_mismatch", f"shot {shot}: zmetadata changed")
    acquisition = core._load_json(acquisition_path, "expansion_acquisition_read_error")
    zmetadata = core._load_json(metadata_path, "expansion_zmetadata_read_error")
    core._require(
        acquisition.get("schema") == "mast-level1-raw-acquisition-v1"
        and acquisition.get("shot") == shot and acquisition.get("metadata_sha256") == metadata_hash
        and acquisition.get("script_sha256") == record["acquisition_script_sha256"]
        and acquisition.get("error_semantics") == "unverified_not_assumed_standard_deviation"
        and acquisition.get("likelihood_ready") is False
        and acquisition.get("scientific_acceptance") is False
        and acquisition.get("exit_code") == 0 and acquisition.get("failures") == [],
        "expansion_acquisition_contract_error", f"shot {shot}: acquisition scope differs",
    )
    receipt = {str(x.get("name")): x for x in acquisition.get("arrays", [])}
    indexed, metadata = _array_entries(record), zmetadata.get("metadata", {})
    core._require(set(receipt) == set(ACQUIRED_ARRAYS)
                  and zmetadata.get("zarr_consolidated_format") == 1
                  and isinstance(metadata, dict), "expansion_zmetadata_contract_error",
                  f"shot {shot}: array set or zmetadata contract differs")
    for name in ACQUIRED_ARRAYS:
        core._require(
            core.canonical_json_bytes(_project_array(receipt[name]))
            == core.canonical_json_bytes(_project_array(indexed[name])),
            "expansion_acquisition_index_binding_error",
            f"shot {shot} {name}: receipt differs from frozen index",
        )
        core._require(
            metadata.get(f"ayc/{name}/.zarray") == receipt[name].get("metadata")
            and metadata.get(f"ayc/{name}/.zattrs") == receipt[name].get("attributes"),
            "expansion_zmetadata_array_binding_error",
            f"shot {shot} {name}: receipt differs from zmetadata",
        )
    arrays = {name: level1._load_acquired_array(shot_dir, receipt[name]) for name in ACQUIRED_ARRAYS}
    shape = _record_shape(record)
    core._require(
        bool(np.isfinite(arrays["time"]).all()) and bool(np.all(np.diff(arrays["time"]) > 0))
        and np.array_equal(arrays["radial_index"], np.arange(shape[1], dtype="<f4"))
        and bool(np.isfinite(arrays["instrument_time"]).all())
        and bool(np.all(np.diff(arrays["instrument_time"]) > 0)),
        "expansion_coordinate_contract_error", f"shot {shot}: coordinate values differ",
    )
    mask = level1._readonly_bool(np.logical_and.reduce(
        [np.isfinite(arrays[name]) for name in MEASUREMENT_ARRAYS]
    ))
    records = _source_records(record)
    records_hash = _source_records_hash(records)
    payload = _payload_hash(
        shot_id=shot, source_directory=str(record["relative_directory"]),
        acquisition_sha256=acquisition_hash, zmetadata_sha256=metadata_hash,
        selection_key_sha256=str(record["selection_key_sha256"]),
        catalog_uuid=str(record["catalog_uuid"]), shape=shape, arrays=arrays,
        source_records=records,
    )
    observation = ExpansionObservation(
        shot, split, str(record["catalog_uuid"]), str(record["selection_key_sha256"]),
        str(record["relative_directory"]), acquisition_hash, metadata_hash, shape,
        arrays, mask, records, records_hash, "unverified_not_assumed_standard_deviation",
        False, payload, level1._sample_lineage_hash(payload, arrays, mask),
    )
    _validate_observation(observation, record)
    return observation


def _validate_observation(
    observation: ExpansionObservation, record: Mapping[str, Any]
) -> dict[str, Any]:
    shape, indexed = _record_shape(record), _array_entries(record)
    core._require(
        observation.shot_id == record["shot_id"] and observation.split == record["split"]
        and observation.catalog_uuid == record["catalog_uuid"]
        and observation.selection_key_sha256 == record["selection_key_sha256"]
        and observation.source_directory == record["relative_directory"]
        and observation.acquisition_sha256 == record["acquisition_receipt_sha256"]
        and observation.zmetadata_sha256 == record["zmetadata_sha256"]
        and observation.shape == shape,
        "expansion_observation_identity_error",
        f"shot {observation.shot_id}: identity or shape differs",
    )
    expected_records = _source_records(record)
    expected_records_hash, actual_records_hash = (
        _source_records_hash(expected_records), _source_records_hash(observation.source_records)
    )
    core._require(
        set(observation.source_records) == set(ACQUIRED_ARRAYS)
        and core.canonical_json_bytes(core._plain(dict(observation.source_records)))
        == core.canonical_json_bytes(expected_records)
        and actual_records_hash == expected_records_hash
        and observation.source_records_sha256 == expected_records_hash,
        "expansion_source_records_binding_error",
        f"shot {observation.shot_id}: source records differ from frozen index",
    )
    core._require(set(observation.arrays) == set(ACQUIRED_ARRAYS),
                  "expansion_observation_array_set_error", "live array set differs")
    for name in ACQUIRED_ARRAYS:
        array = observation.arrays[name]
        core._require(
            isinstance(array, np.ndarray) and array.dtype == np.dtype("<f4")
            and array.shape == tuple(indexed[name]["metadata"]["shape"])
            and bool(array.flags.c_contiguous) and not bool(array.flags.writeable),
            "expansion_observation_array_contract_error",
            f"shot {observation.shot_id} {name}: dtype/shape/memory contract differs",
        )
        core._require(
            hashlib.sha256(array.tobytes(order="C")).hexdigest() == indexed[name]["raw_sha256"],
            "expansion_source_array_binding_error",
            f"shot {observation.shot_id} {name}: live bytes differ from raw acquisition",
        )
    mask = observation.observed_mask
    core._require(
        isinstance(mask, np.ndarray) and mask.dtype == np.dtype(np.bool_)
        and mask.shape == shape and bool(mask.flags.c_contiguous) and not bool(mask.flags.writeable),
        "expansion_observation_mask_contract_error",
        "observed_mask must be read-only contiguous bool with canonical shape",
    )
    expected_mask = np.logical_and.reduce(
        [np.isfinite(observation.arrays[name]) for name in MEASUREMENT_ARRAYS]
    )
    core._require(
        np.array_equal(mask, expected_mask)
        and bool(np.all(observation.arrays["ne_error"][mask] > 0))
        and bool(np.all(observation.arrays["te_error"][mask] > 0))
        and bool(np.isfinite(observation.arrays["time"]).all())
        and bool(np.all(np.diff(observation.arrays["time"]) > 0))
        and np.array_equal(observation.arrays["radial_index"], np.arange(shape[1], dtype="<f4")),
        "expansion_observation_alignment_error", "mask/error/time/radial alignment differs",
    )
    core._require(
        observation.error_semantics == "unverified_not_assumed_standard_deviation"
        and observation.likelihood_ready is False,
        "expansion_error_semantics_contract_error", "unknown semantics were not preserved",
    )
    payload = _payload_hash(
        shot_id=observation.shot_id, source_directory=observation.source_directory,
        acquisition_sha256=observation.acquisition_sha256,
        zmetadata_sha256=observation.zmetadata_sha256,
        selection_key_sha256=observation.selection_key_sha256,
        catalog_uuid=observation.catalog_uuid, shape=shape, arrays=observation.arrays,
        source_records=observation.source_records,
    )
    core._require(payload == observation.canonical_payload_sha256,
                  "expansion_payload_hash_mismatch", "canonical payload identity is stale")
    lineage = level1._sample_lineage_hash(payload, observation.arrays, mask)
    core._require(lineage == observation.sample_lineage_sha256,
                  "expansion_sample_lineage_hash_mismatch", "sample lineage is stale")
    return {"status": "pass", "record_id": observation.record_id,
            "source_records_sha256": actual_records_hash,
            "canonical_payload_sha256": payload, "sample_lineage_sha256": lineage,
            "observed_count": observation.observed_count}


def validate_expansion_observation(observation: ExpansionObservation) -> dict[str, Any]:
    control = _load_control(
        observation.split, DEFAULT_PROTOCOL, DEFAULT_SELECTION, DEFAULT_ACQUISITION_INDEX
    )
    return _validate_observation(observation, _record_for(observation, control))


def iter_expansion_cells(observation: ExpansionObservation) -> Iterator[dict[str, Any]]:
    """Yield aligned identity-mapped cells without assigning error semantics."""
    validate_expansion_observation(observation)
    a = observation.arrays
    for t_raw, r_raw in np.argwhere(observation.observed_mask):
        t, r = int(t_raw), int(r_raw)
        sample_id = f"{observation.record_id}:t{t}:ri{r}"
        digest = hashlib.sha256()
        digest.update(b"FusionConceptAI.reference_validation.expansion_cell.v1\0")
        digest.update(observation.canonical_payload_sha256.encode("ascii"))
        digest.update(sample_id.encode("utf-8")); digest.update(struct.pack("<II", t, r))
        yield {
            "sample_id": sample_id, "sample_sha256": digest.hexdigest(),
            "record_id": observation.record_id, "raw_index": [t, r],
            "canonical_index": [t, r], "time_s": float(a["time"][t]),
            "radial_index": float(a["radial_index"][r]), "radius_m": float(a["radius"][t, r]),
            "ne": float(a["ne"][t, r]), "te": float(a["te"][t, r]),
            "ne_error_reported": float(a["ne_error"][t, r]),
            "te_error_reported": float(a["te_error"][t, r]),
            "covariance_ne_te_reported": float(a["covariance_ne_te"][t, r]),
            "error_semantics": "unknown", "likelihood_ready": False,
        }


def _split_receipt(
    observations: Sequence[ExpansionObservation], split: str, control: Mapping[str, Any]
) -> dict[str, Any]:
    expected = LOADABLE_SPLITS[split]
    core._require(
        len(observations) == len(expected) and tuple(x.shot_id for x in observations) == expected
        and len({x.shot_id for x in observations}) == len(observations)
        and len({x.record_id for x in observations}) == len(observations),
        "expansion_split_coverage_error",
        f"{split} must contain every frozen shot once in manifest order",
    )
    for observation in observations:
        _validate_observation(observation, _record_for(observation, control))
    return {
        "schema_version": "mast_level1_expansion_split_receipt_v1", "split": split,
        "shot_ids": list(expected),
        "combination_unit": "one complete shot-level paired AYC ne/te bundle",
        "combination_count": len(observations), "record_count": len(observations),
        "canonical_payload_sha256": [x.canonical_payload_sha256 for x in observations],
        "sample_lineage_sha256": [x.sample_lineage_sha256 for x in observations],
        "index_leakage_receipt": control["index_leakage_receipt"],
        "held_out_status": "release_required_no_source_paths_indexed",
        "formal_split_ready": False,
    }


def validate_expansion_no_leakage(
    observations: Sequence[ExpansionObservation], split: str
) -> dict[str, Any]:
    control = _load_control(split, DEFAULT_PROTOCOL, DEFAULT_SELECTION, DEFAULT_ACQUISITION_INDEX)
    return _split_receipt(observations, split, control)


def load_expansion_split(
    split: str, source_root: Path | str = DEFAULT_SOURCE_ROOT,
    protocol_path: Path | str = DEFAULT_PROTOCOL,
    selection_path: Path | str = DEFAULT_SELECTION,
    index_path: Path | str = DEFAULT_ACQUISITION_INDEX,
) -> ExpansionPackage:
    _guard_split(split)
    control = _load_control(split, protocol_path, selection_path, index_path)
    root = Path(source_root).resolve()
    records = [x for x in control["index"]["records"] if x["split"] == split]
    observations = tuple(_load_record(root, record) for record in records)
    receipt = _split_receipt(observations, split, control)
    package = ExpansionPackage(
        ADAPTER_VERSION, split, control["protocol"], control["protocol_sha256"],
        control["selection_sha256"], control["index_sha256"], control["helper_sha256"],
        observations, receipt, "present_values_unknown_statistical_semantics", False,
        CLAIM_CEILING,
    )
    validate_expansion_package(package)
    return package


def validate_expansion_package(package: ExpansionPackage) -> dict[str, Any]:
    control = _load_control(
        package.split, DEFAULT_PROTOCOL, DEFAULT_SELECTION, DEFAULT_ACQUISITION_INDEX
    )
    core._require(
        package.adapter_version == ADAPTER_VERSION
        and package.protocol_sha256 == EXPECTED_PROTOCOL_SHA256
        and package.selection_sha256 == EXPECTED_SELECTION_SHA256
        and package.acquisition_index_sha256 == EXPECTED_INDEX_SHA256
        and package.helper_sha256 == EXPECTED_HELPER_SHA256
        and core.canonical_json_bytes(core._plain(dict(package.protocol)))
        == core.canonical_json_bytes(control["protocol"])
        and package.error_semantics == "present_values_unknown_statistical_semantics"
        and package.likelihood_ready is False and package.claim_ceiling == CLAIM_CEILING,
        "expansion_package_metadata_error",
        "package provenance, semantics, readiness, or claim ceiling differs",
    )
    receipt = _split_receipt(package.observations, package.split, control)
    core._require(
        core.canonical_json_bytes(receipt)
        == core.canonical_json_bytes(core._plain(dict(package.split_receipt))),
        "expansion_split_receipt_stale", "stored split receipt differs from live records",
    )
    return {"status": "pass", "split": package.split,
            "combination_count": len(package.observations),
            "joint_observed_cells": sum(x.observed_count for x in package.observations),
            "error_semantics": "unknown", "likelihood_ready": False,
            "formal_split_ready": False}


def _write_bytes(path: Path, data: bytes, output: Path) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
    return {"path": str(path.relative_to(output)).replace("\\", "/"),
            "bytes": len(data), "sha256": core.sha256_bytes(data)}


def _write_json(path: Path, value: Any, output: Path) -> dict[str, Any]:
    data = json.dumps(value, ensure_ascii=False, allow_nan=False,
                      sort_keys=True, indent=2).encode("utf-8") + b"\n"
    return _write_bytes(path, data, output)


def _manifest_entry(observation: ExpansionObservation, record: Mapping[str, Any]) -> dict[str, Any]:
    integrity = _validate_observation(observation, record)
    return {
        "record_id": observation.record_id, "shot_id": observation.shot_id,
        "split": observation.split, "catalog_uuid": observation.catalog_uuid,
        "selection_key_sha256": observation.selection_key_sha256,
        "source_directory": observation.source_directory,
        "acquisition_sha256": observation.acquisition_sha256,
        "zmetadata_sha256": observation.zmetadata_sha256,
        "source_records_sha256": observation.source_records_sha256,
        "raw": {
            "array_sha256": {n: observation.source_records[n]["raw_sha256"] for n in ACQUIRED_ARRAYS},
            "compressed_sha256": {n: observation.source_records[n]["compressed_sha256"] for n in ACQUIRED_ARRAYS},
        },
        "canonical": {"dimensions": ["time", "radial_index"],
                      "shape": list(observation.shape), "mapping": "identity",
                      "payload_sha256": observation.canonical_payload_sha256,
                      "sample_lineage_sha256": observation.sample_lineage_sha256,
                      "observed_count": observation.observed_count},
        "error_data": {"status": "present_values_unknown_statistical_semantics",
                       "standard_deviation_interpretation": "prohibited",
                       "covariance_likelihood_interpretation": "prohibited",
                       "likelihood_ready": False},
        "integrity": integrity,
    }


def write_expansion_package(package: ExpansionPackage, output: Path | str) -> dict[str, Any]:
    validate_expansion_package(package)
    control = _load_control(
        package.split, DEFAULT_PROTOCOL, DEFAULT_SELECTION, DEFAULT_ACQUISITION_INDEX
    )
    receipt = _split_receipt(package.observations, package.split, control)
    output = Path(output).resolve()
    core._require(not output.exists(), "output_exists", f"refusing to overwrite {output}")
    output.mkdir(parents=True)
    artifacts, entries = [], []
    for observation in package.observations:
        files = {}
        for name in ACQUIRED_ARRAYS:
            item = _write_bytes(output / f"shot_{observation.shot_id}" / f"{name}.f32le",
                                observation.arrays[name].tobytes(order="C"), output)
            artifacts.append(item); files[name] = item
        mask = _write_bytes(output / f"shot_{observation.shot_id}" / "observed_mask.u8",
                            observation.observed_mask.astype(np.uint8).tobytes(), output)
        artifacts.append(mask)
        entry = _manifest_entry(observation, _record_for(observation, control))
        entry["canonical"]["files"] = {**files, "observed_mask": mask}; entries.append(entry)
    manifest = {
        "schema_version": "mast_level1_expansion_canonical_package_v1",
        "adapter_version": ADAPTER_VERSION, "protocol_sha256": EXPECTED_PROTOCOL_SHA256,
        "selection_sha256": EXPECTED_SELECTION_SHA256,
        "acquisition_index_sha256": EXPECTED_INDEX_SHA256,
        "verified_helper_sha256": EXPECTED_HELPER_SHA256, "split": package.split,
        "observations": entries, "split_receipt": receipt,
        "held_out_status": "release_required_no_source_paths_indexed",
        "iter_included": False, "claim_ceiling": CLAIM_CEILING,
    }
    report = {
        "schema_version": "mast_level1_expansion_adapter_report_v1",
        "task_id": "UP4-03-REFERENCE-VALIDATION-PREC", "program_state": "pass_with_scope",
        "split": package.split, "records": len(entries),
        "combination_unit": "one complete shot-level paired AYC ne/te bundle",
        "combination_count": len(entries),
        "joint_observed_cells": sum(x.observed_count for x in package.observations),
        "error_data_status": "present_values_unknown_statistical_semantics",
        "likelihood_ready": False, "held_out_status": "release_required_no_source_paths_indexed",
        "formal_split_ready": False, "formal_inverse": "not_executed",
        "physical_state": "unknown", "b03": "not_claimed", "b07b": "not_claimed",
        "parent_UP4_03": "not_accepted", "resolution": "terminal_deferred",
        "claim_ceiling": CLAIM_CEILING,
    }
    primary = [
        _write_json(output / "canonical_manifest.json", manifest, output),
        _write_json(output / "split_receipt.json", receipt, output),
        _write_json(output / "adapter_report.json", report, output),
    ]
    _write_json(output / "artifact_manifest.json",
                {"schema_version": "mast_level1_expansion_artifact_manifest_v1",
                 "files": sorted(artifacts + primary, key=lambda x: x["path"])}, output)
    return report


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Load one released Level-1 expansion split")
    parser.add_argument("--split", required=True)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    parser.add_argument("--selection", type=Path, default=DEFAULT_SELECTION)
    parser.add_argument("--index", type=Path, default=DEFAULT_ACQUISITION_INDEX)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv)
    package = load_expansion_split(
        args.split, args.source, args.protocol, args.selection, args.index
    )
    report = write_expansion_package(package, args.output)
    print(json.dumps(report, ensure_ascii=False, allow_nan=False, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
