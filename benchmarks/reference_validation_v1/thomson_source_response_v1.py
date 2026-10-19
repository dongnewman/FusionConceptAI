"""Executable, uncalibrated Thomson source-response diagnostics for shot 30421.

This module consumes the frozen twenty-array source acquisition together with
the existing Level-1 error-data package.  It validates every raw/assembled
identity and every storage coordinate before computing acquired-versus-fitted
spectral residuals and conditional pressure/PSD diagnostics.

The result is deliberately not a calibrated diagnostic response or a
likelihood.  Blank source units and unknown error/covariance semantics are
preserved, no 20-to-284 or 130-to-131 registration is inferred, and all
conditional PSD-invalid cells remain in their original populations.
"""
from __future__ import annotations

import hashlib
import json
import math
import struct
from dataclasses import dataclass
from pathlib import Path
from types import MappingProxyType
from typing import Any, Iterator, Mapping, Sequence

import numpy as np

import level1_error_adapter as level1
import reference_adapter as core


SOURCE_RESPONSE_VERSION = "mast_thomson_source_response_diagnostic_v1"
SOURCE_SCHEMA = "mast-thomson-response-acquisition-v1"
SELECTION_SCHEMA = "mast-thomson-response-selection-v1"
DEFAULT_SOURCE_ROOT = (
    Path(__file__).resolve().parents[1]
    / "reference_source_fields_v1"
    / "shot30421_thomson_response_r1"
)
EXPECTED_SHOT = 30421
EXPECTED_ACQUISITION_SHA256 = (
    "2b587e265faad6757458c3edaeaff2f87e0c0877866c3da7b148be4b83f72678"
)
EXPECTED_SELECTION_SHA256 = (
    "afdd60d4f232b0cb0346c8f841e02a584ae39626843af3d2cc377f34476f85d3"
)
EXPECTED_ZMETADATA_SHA256 = (
    "362932d6cfeb62f01109a56b825b235b7daaedc928c17340be59c7a1398e7db1"
)
EXPECTED_TOTAL_DECODED_BYTES = 4_035_240
OBSERVED_PRESSURE_COEFFICIENT_FINGERPRINT = 1.609e-19
EXACT_SI_ELEMENTARY_CHARGE = 1.602176634e-19
SPECTRAL_CANONICAL_DIMENSIONS = ("time", "radial_index", "spectral_index")
PROFILE_CANONICAL_DIMENSIONS = ("time", "radial_index")

# The dimension order is the frozen storage contract.  Numerical code still
# derives axis permutations from these names instead of indexing unvalidated
# array positions.
SOURCE_ARRAY_CONTRACTS: tuple[tuple[str, tuple[str, ...], str], ...] = (
    ("ayc/angle", ("radial_index",), ""),
    ("ayc/instrument_dr", ("instrument_time", "radial_index"), "m"),
    ("ayc/instrument_time", ("instrument_time",), "s"),
    ("ayc/scat_length", ("arb",), "m"),
    ("ayc/arb", ("arb",), " arb "),
    ("ayc/spectra", SPECTRAL_CANONICAL_DIMENSIONS, "V"),
    ("ayc/aspectra", SPECTRAL_CANONICAL_DIMENSIONS, "V"),
    ("ayc/spectra_error", SPECTRAL_CANONICAL_DIMENSIONS, ""),
    ("ayc/spectra_stray_light", SPECTRAL_CANONICAL_DIMENSIONS, "V"),
    ("ayc/poisson_error", SPECTRAL_CANONICAL_DIMENSIONS, "V"),
    ("ayc/plasmalight_error", SPECTRAL_CANONICAL_DIMENSIONS, "V"),
    ("ayc/chi2", PROFILE_CANONICAL_DIMENSIONS, ""),
    ("ayc/laser_energy", ("time",), "J"),
    ("ayc/laser_track", ("time",), ""),
    ("ayc/time", ("time",), "s"),
    ("ayc/radial_index", ("radial_index",), " arb "),
    ("ayc/spectral_index", ("spectral_index",), ""),
    ("ayc/pe", PROFILE_CANONICAL_DIMENSIONS, ""),
    ("ayc/pe_error", PROFILE_CANONICAL_DIMENSIONS, ""),
    ("ayc/interferometer_corr", ("time",), " - "),
)
SOURCE_ARRAY_NAMES = tuple(item[0] for item in SOURCE_ARRAY_CONTRACTS)
SOURCE_ARRAY_CONTRACT_BY_NAME = {
    name: (dimensions, unit)
    for name, dimensions, unit in SOURCE_ARRAY_CONTRACTS
}

CLAIM_CEILING = (
    "same-shot raw source-response diagnostics only; detector calibration, "
    "response kernels, statistical error semantics, covariance weights, "
    "likelihood, held-out validation, physical acceptance, B03/B07B/R02/R06, "
    "and parent UP4-03 completion remain deferred"
)


def _readonly(values: Any, dtype: Any) -> np.ndarray:
    result = np.ascontiguousarray(values, dtype=dtype)
    result.setflags(write=False)
    return result


def _readonly_f32(values: Any) -> np.ndarray:
    return _readonly(values, "<f4")


def _readonly_f64(values: Any) -> np.ndarray:
    return _readonly(values, "<f8")


def _readonly_bool(values: Any) -> np.ndarray:
    return _readonly(values, np.bool_)


def _readonly_i64(values: Any) -> np.ndarray:
    return _readonly(values, "<i8")


def _array_sha256(values: np.ndarray) -> str:
    contiguous = np.ascontiguousarray(values)
    return hashlib.sha256(contiguous.tobytes(order="C")).hexdigest()


def _array_storage_identity(values: Any) -> dict[str, Any]:
    array = np.asarray(values)
    return {
        "dtype": array.dtype.str,
        "shape": list(array.shape),
        "sha256": _array_sha256(array),
    }


def _array_storage_equal(left: Any, right: Any) -> bool:
    left_array = np.asarray(left)
    right_array = np.asarray(right)
    return (
        left_array.dtype == right_array.dtype
        and left_array.shape == right_array.shape
        and np.ascontiguousarray(left_array).tobytes(order="C")
        == np.ascontiguousarray(right_array).tobytes(order="C")
    )


def _coordinate_values_exact(candidate: Any, source: Any) -> bool:
    candidate_array = np.asarray(candidate)
    source_array = np.asarray(source)
    return (
        candidate_array.dtype.kind == "f"
        and source_array.dtype.kind == "f"
        and candidate_array.dtype.itemsize >= source_array.dtype.itemsize
        and candidate_array.shape == source_array.shape
        and np.array_equal(
            candidate_array,
            source_array.astype(candidate_array.dtype, copy=False),
        )
    )


def _mask_sha256(values: np.ndarray) -> str:
    mask = np.ascontiguousarray(values, dtype=np.bool_)
    packed = np.packbits(mask.reshape(-1), bitorder="little")
    return hashlib.sha256(packed.tobytes()).hexdigest()


def _canonical_hash(value: Any) -> str:
    return hashlib.sha256(core.canonical_json_bytes(value)).hexdigest()


def _safe_child(root: Path, relative: str, code: str) -> Path:
    core._require(isinstance(relative, str) and relative, code, "path is missing")
    path = (root / relative).resolve()
    try:
        path.relative_to(root.resolve())
    except ValueError as exc:
        raise core.AdapterError(code, f"path escapes source root: {relative!r}") from exc
    core._require(path.is_file(), code, f"missing source file: {relative}")
    return path


def _mapping(value: Mapping[str, Any]) -> Mapping[str, Any]:
    return MappingProxyType(dict(value))


def _array_in_dimensions(
    array: "SourceArrayV1", requested_dimensions: Sequence[str]
) -> np.ndarray:
    requested = tuple(requested_dimensions)
    core._require(
        len(requested) == len(array.dimensions)
        and set(requested) == set(array.dimensions),
        "source_dimension_error",
        f"{array.name}: cannot map {array.dimensions} to {requested}",
    )
    permutation = tuple(array.dimensions.index(name) for name in requested)
    mapped = np.transpose(array.values, axes=permutation)
    mapped.setflags(write=False)
    return mapped


@dataclass(frozen=True)
class ChunkIdentityV1:
    chunk_index: tuple[int, ...]
    compressed_path: str
    compressed_bytes: int
    compressed_sha256: str
    decoded_path: str
    decoded_bytes: int
    decoded_sha256: str

    def manifest_entry(self) -> dict[str, Any]:
        return {
            "chunk_index": list(self.chunk_index),
            "compressed_path": self.compressed_path,
            "compressed_bytes": self.compressed_bytes,
            "compressed_sha256": self.compressed_sha256,
            "decoded_path": self.decoded_path,
            "decoded_bytes": self.decoded_bytes,
            "decoded_sha256": self.decoded_sha256,
        }


@dataclass(frozen=True)
class SourceArrayIdentityV1:
    name: str
    dimensions: tuple[str, ...]
    shape: tuple[int, ...]
    dtype: str
    unit: str
    assembled_path: str
    assembled_bytes: int
    assembled_sha256: str
    field_metadata_path: str
    field_metadata_sha256: str
    chunks: tuple[ChunkIdentityV1, ...]

    def manifest_entry(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "dimensions": list(self.dimensions),
            "shape": list(self.shape),
            "dtype": self.dtype,
            "unit": self.unit,
            "assembled_path": self.assembled_path,
            "assembled_bytes": self.assembled_bytes,
            "assembled_sha256": self.assembled_sha256,
            "field_metadata_path": self.field_metadata_path,
            "field_metadata_sha256": self.field_metadata_sha256,
            "chunks": [item.manifest_entry() for item in self.chunks],
        }


@dataclass(frozen=True)
class SourceArrayV1:
    name: str
    dimensions: tuple[str, ...]
    shape: tuple[int, ...]
    dtype: str
    unit: str
    values: np.ndarray
    finite_mask: np.ndarray
    identity: SourceArrayIdentityV1


@dataclass(frozen=True)
class ThomsonSourceResponseSourceV1:
    shot_id: int
    source_root: str
    acquisition_path: str
    acquisition_sha256: str
    selection_path: str
    selection_sha256: str
    zmetadata_path: str
    zmetadata_sha256: str
    arrays: Mapping[str, SourceArrayV1]
    source_bundle_sha256: str
    raw_values_only: bool
    likelihood_ready: bool
    scientific_acceptance: bool

    def array(self, name: str) -> SourceArrayV1:
        core._require(
            name in self.arrays,
            "source_array_missing",
            f"source array is absent: {name}",
        )
        return self.arrays[name]

    @property
    def raw_source_identities(self) -> tuple[SourceArrayIdentityV1, ...]:
        return tuple(self.arrays[name].identity for name in SOURCE_ARRAY_NAMES)

    def manifest_entry(self) -> dict[str, Any]:
        validate_thomson_source_response_source_v1(self)
        return {
            "schema": "mast-thomson-source-response-source-v1",
            "shot_id": self.shot_id,
            "acquisition": {
                "path": self.acquisition_path,
                "sha256": self.acquisition_sha256,
            },
            "selection": {
                "path": self.selection_path,
                "sha256": self.selection_sha256,
            },
            "zmetadata": {
                "path": self.zmetadata_path,
                "sha256": self.zmetadata_sha256,
            },
            "array_count": len(self.arrays),
            "arrays": [item.manifest_entry() for item in self.raw_source_identities],
            "source_bundle_sha256": self.source_bundle_sha256,
            "raw_values_only": self.raw_values_only,
            "likelihood_ready": self.likelihood_ready,
            "scientific_acceptance": self.scientific_acceptance,
        }


@dataclass(frozen=True)
class CandidateSpectralPredictionV1:
    candidate_id: str
    values: np.ndarray
    dimensions: tuple[str, str, str]
    time_s: np.ndarray
    radial_index: np.ndarray
    spectral_index: np.ndarray
    finite_mask: np.ndarray
    unit: str
    unit_semantics_source: str
    role: str = "uncalibrated_candidate_prediction"
    calibrated_response: bool = False


@dataclass(frozen=True)
class ChannelResidualV1:
    channel_label: float
    role: str
    source_role: str
    comparator_role: str
    unit: str
    unit_semantics_source: str
    mask: np.ndarray
    source_values: np.ndarray
    comparator_values: np.ndarray
    residual_values: np.ndarray
    mask_sha256: str
    residual_sha256: str
    source_cell_identity_root_sha256: str
    calibrated_response: bool
    selection_authorized: bool


@dataclass(frozen=True)
class ConditionalPressureDiagnosticV1:
    profile_mask: np.ndarray
    pressure_mask: np.ndarray
    pressure_error_mask: np.ndarray
    psd_eligible_mask: np.ndarray
    psd_invalid_mask: np.ndarray
    linearized_variance_negative_mask: np.ndarray
    positive_variance_comparison_mask: np.ndarray
    positive_variance_psd_invalid_mask: np.ndarray
    rho_star: np.ndarray
    linearized_variance_base: np.ndarray
    pressure_residual_fingerprint: np.ndarray
    pressure_residual_exact_si: np.ndarray
    pressure_error_residual_fingerprint: np.ndarray
    pressure_error_residual_exact_si: np.ndarray
    observed_coefficient_median: float
    observed_coefficient_min: float
    observed_coefficient_max: float
    psd_invalid_count: int
    negative_variance_count: int
    positive_variance_comparison_count: int
    positive_variance_psd_invalid_count: int
    existing_level1_conditional: Mapping[str, Any]
    pressure_unit: str
    pressure_error_unit: str
    error_semantics: str
    producer_formula_confirmed: bool
    correction_applied: bool
    likelihood_ready: bool


@dataclass(frozen=True)
class ThomsonSourceResponseDiagnosticV1:
    version: str
    source: ThomsonSourceResponseSourceV1
    level1_observation: level1.Level1ErrorObservation
    fitted_channel_residuals: tuple[ChannelResidualV1, ...]
    candidate_channel_residuals: tuple[ChannelResidualV1, ...]
    candidate_prediction: CandidateSpectralPredictionV1 | None
    pressure: ConditionalPressureDiagnosticV1
    spectral_masks: Mapping[str, np.ndarray]
    profile_masks: Mapping[str, np.ndarray]
    conditional_spectral_fit: Mapping[str, Any]
    auxiliary_inventory: tuple[Mapping[str, Any], ...]
    diagnostic_sha256: str
    calibrated_response: bool
    likelihood_ready: bool
    covariance_weights_authorized: bool
    selection_authorized: bool
    claim_ceiling: str

    def require_covariance_weights(self) -> None:
        raise core.AdapterError(
            "covariance_weights_prohibited",
            "error/covariance semantics are unknown; covariance weights are unavailable",
        )

    def require_likelihood_ready(self) -> None:
        raise core.AdapterError(
            "source_response_likelihood_prohibited",
            "no calibrated response or provider-bound statistical semantics exist",
        )

    def manifest_entry(self) -> dict[str, Any]:
        validate_thomson_source_response_diagnostic_v1(self)
        return {
            "schema": self.version,
            "status": "pass_conditional_diagnostics_only",
            "shot_id": self.source.shot_id,
            "source_bundle_sha256": self.source.source_bundle_sha256,
            "level1": {
                "record_id": self.level1_observation.record_id,
                "canonical_payload_sha256": (
                    self.level1_observation.canonical_payload_sha256
                ),
                "sample_lineage_sha256": (
                    self.level1_observation.sample_lineage_sha256
                ),
                "acquisition_sha256": self.level1_observation.acquisition_sha256,
                "zmetadata_sha256": self.level1_observation.zmetadata_sha256,
            },
            "raw_source_identities": [
                item.manifest_entry() for item in self.source.raw_source_identities
            ],
            "spectral": {
                "fitted_role": "acquired_provider_fitted_spectra",
                "candidate_role": (
                    self.candidate_prediction.role
                    if self.candidate_prediction is not None
                    else "not_supplied"
                ),
                "channel_count": len(self.fitted_channel_residuals),
                "finite_counts": [
                    int(item.mask.sum()) for item in self.fitted_channel_residuals
                ],
                "fitted_residual_sha256": [
                    item.residual_sha256 for item in self.fitted_channel_residuals
                ],
                "candidate_residual_sha256": [
                    item.residual_sha256 for item in self.candidate_channel_residuals
                ],
                "conditional_fit": core._plain(dict(self.conditional_spectral_fit)),
            },
            "pressure": {
                "observed_coefficient_fingerprint": (
                    OBSERVED_PRESSURE_COEFFICIENT_FINGERPRINT
                ),
                "exact_si_elementary_charge_baseline": EXACT_SI_ELEMENTARY_CHARGE,
                "observed_coefficient_median": (
                    self.pressure.observed_coefficient_median
                ),
                "psd_invalid_count": self.pressure.psd_invalid_count,
                "negative_linearized_variance_count": (
                    self.pressure.negative_variance_count
                ),
                "positive_variance_comparison_count": (
                    self.pressure.positive_variance_comparison_count
                ),
                "positive_variance_psd_invalid_retained_count": (
                    self.pressure.positive_variance_psd_invalid_count
                ),
                "pressure_unit": self.pressure.pressure_unit,
                "pressure_error_unit": self.pressure.pressure_error_unit,
                "producer_formula_confirmed": False,
                "correction_applied": False,
                "likelihood_ready": False,
            },
            "registration_gaps": {
                "instrument_time_20_to_measurement_time_284": "typed_absent",
                "scat_length_130_to_radial_index_131": "typed_absent",
                "inference_or_index_shift_applied": False,
            },
            "diagnostic_sha256": self.diagnostic_sha256,
            "calibrated_response": self.calibrated_response,
            "likelihood_ready": self.likelihood_ready,
            "covariance_weights_authorized": self.covariance_weights_authorized,
            "selection_authorized": self.selection_authorized,
            "claim_ceiling": self.claim_ceiling,
        }


def _load_chunk_identities(
    source_root: Path, records: Sequence[Mapping[str, Any]], name: str
) -> tuple[ChunkIdentityV1, ...]:
    identities: list[ChunkIdentityV1] = []
    seen: set[tuple[int, ...]] = set()
    for record in records:
        index = tuple(int(value) for value in record.get("chunk_index", []))
        core._require(
            index and index not in seen,
            "source_chunk_identity_error",
            f"{name}: duplicate or empty chunk index {index}",
        )
        seen.add(index)
        compressed_path = str(record.get("compressed_path", ""))
        decoded_path = str(record.get("decoded_path", ""))
        compressed = _safe_child(
            source_root, compressed_path, "source_chunk_file_error"
        )
        decoded = _safe_child(source_root, decoded_path, "source_chunk_file_error")
        core._require(
            compressed.stat().st_size == record.get("compressed_bytes")
            and core.sha256_file(compressed) == record.get("compressed_sha256"),
            "source_chunk_identity_error",
            f"{name}: compressed chunk differs at {index}",
        )
        core._require(
            decoded.stat().st_size == record.get("decoded_bytes")
            and core.sha256_file(decoded) == record.get("decoded_sha256"),
            "source_chunk_identity_error",
            f"{name}: decoded chunk differs at {index}",
        )
        identities.append(
            ChunkIdentityV1(
                chunk_index=index,
                compressed_path=compressed_path,
                compressed_bytes=int(record["compressed_bytes"]),
                compressed_sha256=str(record["compressed_sha256"]),
                decoded_path=decoded_path,
                decoded_bytes=int(record["decoded_bytes"]),
                decoded_sha256=str(record["decoded_sha256"]),
            )
        )
    return tuple(identities)


def _load_source_array(
    source_root: Path,
    selection_item: Mapping[str, Any],
    acquisition_item: Mapping[str, Any],
    zmetadata: Mapping[str, Any],
) -> SourceArrayV1:
    name = str(selection_item.get("resolved_path", ""))
    core._require(
        name in SOURCE_ARRAY_CONTRACT_BY_NAME
        and acquisition_item.get("resolved_path") == name
        and selection_item.get("requested_path") == name
        and acquisition_item.get("requested_path") == name
        and selection_item.get("metadata_resolution") == "exact_path"
        and acquisition_item.get("metadata_resolution") == "exact_path",
        "source_array_contract_error",
        f"unexpected source array identity: {name!r}",
    )
    expected_dimensions, expected_unit = SOURCE_ARRAY_CONTRACT_BY_NAME[name]
    zarray = selection_item.get("zarray", {})
    attributes = selection_item.get("attributes", {})
    dimensions = tuple(str(value) for value in selection_item.get("dimensions", []))
    shape = tuple(int(value) for value in selection_item.get("shape", []))
    core._require(
        zarray == acquisition_item.get("zarray")
        and attributes == acquisition_item.get("attributes")
        and list(shape) == acquisition_item.get("shape")
        and list(dimensions) == acquisition_item.get("dimensions"),
        "source_array_receipt_mismatch",
        f"{name}: selection and acquisition metadata differ",
    )
    core._require(
        tuple(zarray.get("shape", [])) == shape
        and tuple(attributes.get("_ARRAY_DIMENSIONS", [])) == dimensions
        and dimensions == expected_dimensions,
        "source_storage_dimension_error",
        f"{name}: storage dimensions differ from the frozen named-axis contract",
    )
    dtype = str(zarray.get("dtype", ""))
    unit = str(attributes.get("units", ""))
    core._require(
        dtype == "<f4"
        and zarray.get("order") == "C"
        and zarray.get("filters") is None
        and zarray.get("zarr_format") == 2,
        "source_storage_contract_error",
        f"{name}: unsupported array storage",
    )
    core._require(
        unit == expected_unit,
        "source_unit_contract_error",
        f"{name}: expected raw unit {expected_unit!r}, got {unit!r}",
    )
    metadata = zmetadata.get("metadata", {})
    core._require(
        metadata.get(name + "/.zarray") == zarray
        and metadata.get(name + "/.zattrs") == attributes,
        "source_zmetadata_binding_error",
        f"{name}: frozen zmetadata differs",
    )
    field_dir_name = name.replace("/", "__")
    field_metadata_relative = f"fields/{field_dir_name}/field_metadata.json"
    field_metadata_path = _safe_child(
        source_root, field_metadata_relative, "source_field_metadata_error"
    )
    field_metadata = core._load_json(
        field_metadata_path, "source_field_metadata_error"
    )
    core._require(
        field_metadata.get("zarray") == zarray
        and field_metadata.get("attributes") == attributes,
        "source_field_metadata_error",
        f"{name}: field metadata differs",
    )
    assembled_relative = str(acquisition_item.get("assembled_path", ""))
    core._require(
        assembled_relative == f"fields/{field_dir_name}/assembled.raw",
        "source_assembled_path_error",
        f"{name}: unexpected assembled path",
    )
    assembled_path = _safe_child(
        source_root, assembled_relative, "source_assembled_file_error"
    )
    raw = assembled_path.read_bytes()
    expected_bytes = math.prod(shape) * 4
    expected_hash = str(acquisition_item.get("assembled_sha256", ""))
    core._require(
        expected_bytes == acquisition_item.get("assembled_bytes")
        == acquisition_item.get("decoded_bytes")
        and len(raw) == expected_bytes
        and core.sha256_bytes(raw) == expected_hash,
        "source_assembled_identity_error",
        f"{name}: assembled bytes differ from acquisition receipt",
    )
    values = np.frombuffer(raw, dtype="<f4").reshape(shape)
    values.setflags(write=False)
    finite_mask = _readonly_bool(np.isfinite(values))
    finite = values[finite_mask]
    core._require(
        int(finite_mask.sum()) == acquisition_item.get("finite_count")
        and values.size == acquisition_item.get("total_count"),
        "source_array_population_error",
        f"{name}: finite population differs from acquisition receipt",
    )
    if finite.size:
        core._require(
            float(finite.min()) == acquisition_item.get("minimum")
            and float(finite.max()) == acquisition_item.get("maximum"),
            "source_array_population_error",
            f"{name}: finite extrema differ from acquisition receipt",
        )
    chunks = _load_chunk_identities(
        source_root, acquisition_item.get("chunks_acquired", []), name
    )
    identity = SourceArrayIdentityV1(
        name=name,
        dimensions=dimensions,
        shape=shape,
        dtype=dtype,
        unit=unit,
        assembled_path=assembled_relative,
        assembled_bytes=len(raw),
        assembled_sha256=expected_hash,
        field_metadata_path=field_metadata_relative,
        field_metadata_sha256=core.sha256_file(field_metadata_path),
        chunks=chunks,
    )
    return SourceArrayV1(
        name=name,
        dimensions=dimensions,
        shape=shape,
        dtype=dtype,
        unit=unit,
        values=values,
        finite_mask=finite_mask,
        identity=identity,
    )


def _source_bundle_body(
    shot_id: int,
    acquisition_sha256: str,
    selection_sha256: str,
    zmetadata_sha256: str,
    arrays: Mapping[str, SourceArrayV1],
) -> dict[str, Any]:
    return {
        "domain": "FusionConceptAI.thomson_source_response.source_bundle.v1",
        "shot_id": shot_id,
        "acquisition_sha256": acquisition_sha256,
        "selection_sha256": selection_sha256,
        "zmetadata_sha256": zmetadata_sha256,
        "arrays": [
            arrays[name].identity.manifest_entry() for name in SOURCE_ARRAY_NAMES
        ],
    }


def load_thomson_source_response_source_v1(
    source_root: Path | str = DEFAULT_SOURCE_ROOT,
) -> ThomsonSourceResponseSourceV1:
    """Load and hash-validate all twenty frozen source arrays."""

    root = Path(source_root).resolve()
    acquisition_path = root / "acquisition.json"
    selection_path = root / "selection.json"
    zmetadata_path = root / "zmetadata.json"
    for path in (acquisition_path, selection_path, zmetadata_path):
        core._require(path.is_file(), "source_package_file_missing", str(path))
    acquisition_sha = core.sha256_file(acquisition_path)
    selection_sha = core.sha256_file(selection_path)
    zmetadata_sha = core.sha256_file(zmetadata_path)
    core._require(
        acquisition_sha == EXPECTED_ACQUISITION_SHA256
        and selection_sha == EXPECTED_SELECTION_SHA256
        and zmetadata_sha == EXPECTED_ZMETADATA_SHA256,
        "source_package_identity_error",
        "acquisition, selection, or zmetadata differs from the frozen package",
    )
    acquisition = core._load_json(acquisition_path, "source_acquisition_read_error")
    selection = core._load_json(selection_path, "source_selection_read_error")
    zmetadata = core._load_json(zmetadata_path, "source_zmetadata_read_error")
    core._require(
        acquisition.get("schema") == SOURCE_SCHEMA
        and selection.get("schema") == SELECTION_SCHEMA
        and acquisition.get("shot") == selection.get("shot") == EXPECTED_SHOT
        and acquisition.get("status") == "acquired_requires_independent_decode_review"
        and acquisition.get("exit_code") == 0
        and acquisition.get("raw_values_only") is True
        and acquisition.get("likelihood_ready") is False
        and acquisition.get("scientific_acceptance") is False
        and acquisition.get("inputs_unchanged") is True,
        "source_package_contract_error",
        "source acquisition status or scientific ceiling differs",
    )
    core._require(
        acquisition.get("selection_sha256") == selection_sha
        and selection.get("metadata_sha256") == zmetadata_sha
        and acquisition.get("total_decoded_bytes") == EXPECTED_TOTAL_DECODED_BYTES
        and selection.get("total_decoded_bytes") == EXPECTED_TOTAL_DECODED_BYTES,
        "source_package_binding_error",
        "selection, zmetadata, or decoded-byte binding differs",
    )
    selected = selection.get("fields", [])
    acquired = acquisition.get("arrays", [])
    core._require(
        len(selected) == len(acquired) == len(SOURCE_ARRAY_NAMES)
        and tuple(item.get("resolved_path") for item in selected)
        == SOURCE_ARRAY_NAMES
        and tuple(item.get("resolved_path") for item in acquired)
        == SOURCE_ARRAY_NAMES,
        "source_array_inventory_error",
        "expected the frozen ordered twenty-array inventory",
    )
    arrays = {
        str(selection_item["resolved_path"]): _load_source_array(
            root, selection_item, acquisition_item, zmetadata
        )
        for selection_item, acquisition_item in zip(selected, acquired, strict=True)
    }
    body = _source_bundle_body(
        EXPECTED_SHOT, acquisition_sha, selection_sha, zmetadata_sha, arrays
    )
    source = ThomsonSourceResponseSourceV1(
        shot_id=EXPECTED_SHOT,
        source_root=str(root),
        acquisition_path="acquisition.json",
        acquisition_sha256=acquisition_sha,
        selection_path="selection.json",
        selection_sha256=selection_sha,
        zmetadata_path="zmetadata.json",
        zmetadata_sha256=zmetadata_sha,
        arrays=MappingProxyType(arrays),
        source_bundle_sha256=_canonical_hash(body),
        raw_values_only=True,
        likelihood_ready=False,
        scientific_acceptance=False,
    )
    validate_thomson_source_response_source_v1(source)
    return source


def _validate_live_source_receipts(
    source: ThomsonSourceResponseSourceV1,
) -> None:
    """Bind public source objects back to the frozen files and receipts."""

    root = Path(source.source_root).resolve()
    acquisition_path = _safe_child(
        root, source.acquisition_path, "source_package_file_missing"
    )
    selection_path = _safe_child(
        root, source.selection_path, "source_package_file_missing"
    )
    zmetadata_path = _safe_child(
        root, source.zmetadata_path, "source_package_file_missing"
    )
    core._require(
        core.sha256_file(acquisition_path) == source.acquisition_sha256
        and core.sha256_file(selection_path) == source.selection_sha256
        and core.sha256_file(zmetadata_path) == source.zmetadata_sha256,
        "source_live_package_identity_error",
        "live acquisition, selection, or zmetadata differs from source object",
    )
    acquisition = core._load_json(
        acquisition_path, "source_acquisition_read_error"
    )
    selection = core._load_json(selection_path, "source_selection_read_error")
    zmetadata = core._load_json(zmetadata_path, "source_zmetadata_read_error")
    acquired = {
        str(item.get("resolved_path")): item
        for item in acquisition.get("arrays", [])
    }
    selected = {
        str(item.get("resolved_path")): item for item in selection.get("fields", [])
    }
    core._require(
        tuple(acquired) == SOURCE_ARRAY_NAMES
        and tuple(selected) == SOURCE_ARRAY_NAMES,
        "source_live_array_inventory_error",
        "live receipts do not contain the frozen twenty-array order",
    )
    metadata = zmetadata.get("metadata", {})
    for name in SOURCE_ARRAY_NAMES:
        array = source.arrays[name]
        identity = array.identity
        acquisition_item = acquired[name]
        selection_item = selected[name]
        expected_chunk_entries = tuple(
            {
                "chunk_index": list(int(value) for value in record["chunk_index"]),
                "compressed_path": str(record["compressed_path"]),
                "compressed_bytes": int(record["compressed_bytes"]),
                "compressed_sha256": str(record["compressed_sha256"]),
                "decoded_path": str(record["decoded_path"]),
                "decoded_bytes": int(record["decoded_bytes"]),
                "decoded_sha256": str(record["decoded_sha256"]),
            }
            for record in acquisition_item.get("chunks_acquired", [])
        )
        core._require(
            identity.assembled_path == acquisition_item.get("assembled_path")
            and identity.assembled_bytes == acquisition_item.get("assembled_bytes")
            and identity.assembled_sha256
            == acquisition_item.get("assembled_sha256")
            and list(identity.shape) == acquisition_item.get("shape")
            and list(identity.dimensions) == acquisition_item.get("dimensions")
            and identity.dtype == acquisition_item.get("dtype")
            and identity.unit
            == acquisition_item.get("attributes", {}).get("units", "")
            and tuple(item.manifest_entry() for item in identity.chunks)
            == expected_chunk_entries,
            "source_array_receipt_identity_error",
            f"{name}: public array identity differs from frozen acquisition receipt",
        )
        core._require(
            selection_item.get("zarray") == acquisition_item.get("zarray")
            and selection_item.get("attributes")
            == acquisition_item.get("attributes")
            and metadata.get(name + "/.zarray") == selection_item.get("zarray")
            and metadata.get(name + "/.zattrs")
            == selection_item.get("attributes"),
            "source_live_metadata_binding_error",
            f"{name}: live selection/acquisition/zmetadata differ",
        )
        assembled_path = _safe_child(
            root, identity.assembled_path, "source_assembled_file_error"
        )
        field_metadata_path = _safe_child(
            root, identity.field_metadata_path, "source_field_metadata_error"
        )
        field_metadata = core._load_json(
            field_metadata_path, "source_field_metadata_error"
        )
        core._require(
            assembled_path.stat().st_size == identity.assembled_bytes
            and core.sha256_file(assembled_path) == identity.assembled_sha256
            and core.sha256_file(field_metadata_path)
            == identity.field_metadata_sha256
            and field_metadata.get("zarray") == selection_item.get("zarray")
            and field_metadata.get("attributes")
            == selection_item.get("attributes"),
            "source_live_array_identity_error",
            f"{name}: live assembled or field-metadata bytes differ",
        )
        for chunk in identity.chunks:
            compressed = _safe_child(
                root, chunk.compressed_path, "source_chunk_file_error"
            )
            decoded = _safe_child(root, chunk.decoded_path, "source_chunk_file_error")
            core._require(
                compressed.stat().st_size == chunk.compressed_bytes
                and core.sha256_file(compressed) == chunk.compressed_sha256
                and decoded.stat().st_size == chunk.decoded_bytes
                and core.sha256_file(decoded) == chunk.decoded_sha256,
                "source_live_chunk_identity_error",
                f"{name}: live chunk bytes differ at {chunk.chunk_index}",
            )


def validate_thomson_source_response_source_v1(
    source: ThomsonSourceResponseSourceV1,
) -> dict[str, Any]:
    core._require(
        source.shot_id == EXPECTED_SHOT
        and source.acquisition_sha256 == EXPECTED_ACQUISITION_SHA256
        and source.selection_sha256 == EXPECTED_SELECTION_SHA256
        and source.zmetadata_sha256 == EXPECTED_ZMETADATA_SHA256
        and source.raw_values_only is True
        and source.likelihood_ready is False
        and source.scientific_acceptance is False,
        "source_object_metadata_error",
        "source object metadata differs from frozen package",
    )
    core._require(
        tuple(source.arrays) == SOURCE_ARRAY_NAMES,
        "source_array_inventory_error",
        "source object does not retain all twenty arrays in frozen order",
    )
    _validate_live_source_receipts(source)
    for name in SOURCE_ARRAY_NAMES:
        array = source.arrays[name]
        expected_dimensions, expected_unit = SOURCE_ARRAY_CONTRACT_BY_NAME[name]
        core._require(
            array.name == name
            and array.dimensions == expected_dimensions
            and array.shape == array.values.shape == array.finite_mask.shape
            and array.dtype == "<f4"
            and array.values.dtype == np.dtype("<f4")
            and array.unit == expected_unit
            and array.identity.name == name
            and array.identity.dimensions == array.dimensions
            and array.identity.shape == array.shape
            and array.identity.dtype == array.dtype
            and array.identity.unit == array.unit,
            "source_array_object_error",
            f"{name}: source array fields are inconsistent",
        )
        core._require(
            np.array_equal(array.finite_mask, np.isfinite(array.values))
            and _array_sha256(array.values) == array.identity.assembled_sha256
            and array.values.nbytes == array.identity.assembled_bytes,
            "source_array_identity_error",
            f"{name}: values or finite mask differ from raw identity",
        )
    spectral_labels = _array_in_dimensions(
        source.array("ayc/spectral_index"), ("spectral_index",)
    )
    core._require(
        np.array_equal(spectral_labels, np.asarray([1, 2, 3, 4], dtype="<f4")),
        "source_spectral_label_order_error",
        "spectral labels must retain acquired order [1,2,3,4]",
    )
    time_values = _array_in_dimensions(source.array("ayc/time"), ("time",))
    radial_values = _array_in_dimensions(
        source.array("ayc/radial_index"), ("radial_index",)
    )
    core._require(
        bool(np.isfinite(time_values).all())
        and bool(np.all(np.diff(time_values.astype(np.float64)) > 0.0))
        and np.array_equal(radial_values, np.arange(131, dtype="<f4")),
        "source_coordinate_semantics_error",
        "time must be finite/increasing and radial labels must remain 0:130",
    )
    body = _source_bundle_body(
        source.shot_id,
        source.acquisition_sha256,
        source.selection_sha256,
        source.zmetadata_sha256,
        source.arrays,
    )
    core._require(
        _canonical_hash(body) == source.source_bundle_sha256,
        "source_bundle_hash_mismatch",
        "source bundle identity is stale",
    )
    return {
        "status": "pass",
        "shot_id": source.shot_id,
        "array_count": len(source.arrays),
        "source_bundle_sha256": source.source_bundle_sha256,
        "likelihood_ready": False,
    }


def _validate_source_level1_join(
    source: ThomsonSourceResponseSourceV1,
    observation: level1.Level1ErrorObservation,
) -> dict[str, Any]:
    validate_thomson_source_response_source_v1(source)
    level1.validate_level1_observation(observation)
    core._require(
        observation.shot_id == source.shot_id
        and observation.zmetadata_sha256 == source.zmetadata_sha256,
        "source_level1_identity_error",
        "source and Level-1 shot/zmetadata identities differ",
    )
    source_time = _array_in_dimensions(source.array("ayc/time"), ("time",))
    source_radial = _array_in_dimensions(
        source.array("ayc/radial_index"), ("radial_index",)
    )
    core._require(
        source.array("ayc/time").identity.assembled_sha256
        == observation.source_records["time"]["raw_sha256"]
        and source.array("ayc/radial_index").identity.assembled_sha256
        == observation.source_records["radial_index"]["raw_sha256"],
        "source_level1_coordinate_identity_error",
        "source and Level-1 coordinate byte identities differ",
    )
    core._require(
        np.array_equal(source_time, observation.time_s)
        and np.array_equal(source_radial, observation.radial_index),
        "source_level1_coordinate_mismatch",
        "source and Level-1 coordinate values differ; interpolation is prohibited",
    )
    pe = _array_in_dimensions(source.array("ayc/pe"), PROFILE_CANONICAL_DIMENSIONS)
    pe_error = _array_in_dimensions(
        source.array("ayc/pe_error"), PROFILE_CANONICAL_DIMENSIONS
    )
    core._require(
        np.array_equal(np.isfinite(pe), observation.observed_mask)
        and np.array_equal(np.isfinite(pe_error), observation.observed_mask),
        "source_profile_mask_mismatch",
        "pressure/error finite populations differ from Level-1 profile population",
    )
    return {
        "status": "pass_exact_storage_coordinate_join",
        "time_sha256": source.array("ayc/time").identity.assembled_sha256,
        "radial_index_sha256": (
            source.array("ayc/radial_index").identity.assembled_sha256
        ),
        "profile_cell_count": observation.observed_count,
    }


def _validate_candidate_prediction(
    candidate: CandidateSpectralPredictionV1,
    source: ThomsonSourceResponseSourceV1,
    spectral_joint_mask: np.ndarray,
) -> np.ndarray:
    core._require(
        isinstance(candidate.candidate_id, str) and candidate.candidate_id,
        "candidate_identity_missing",
        "candidate prediction requires a non-empty candidate identity",
    )
    core._require(
        candidate.role == "uncalibrated_candidate_prediction"
        and candidate.calibrated_response is False,
        "candidate_role_error",
        "candidate spectra must remain explicitly uncalibrated",
    )
    core._require(
        isinstance(candidate.unit_semantics_source, str)
        and candidate.unit_semantics_source.strip(),
        "candidate_unit_semantics_missing",
        "candidate prediction must name its unit-semantics source",
    )
    core._require(
        candidate.unit == "V",
        "candidate_unit_error",
        "this raw residual comparison requires declared volt-valued candidate output",
    )
    dimensions = tuple(candidate.dimensions)
    core._require(
        len(dimensions) == 3
        and set(dimensions) == set(SPECTRAL_CANONICAL_DIMENSIONS),
        "candidate_dimension_error",
        "candidate prediction must name time/radial_index/spectral_index axes",
    )
    values = np.asarray(candidate.values, dtype="<f8")
    finite_mask = np.asarray(candidate.finite_mask, dtype=np.bool_)
    core._require(
        values.shape == finite_mask.shape
        and np.array_equal(finite_mask, np.isfinite(values)),
        "candidate_finite_mask_mismatch",
        "candidate finite mask must exactly describe candidate values",
    )
    permutation = tuple(dimensions.index(name) for name in SPECTRAL_CANONICAL_DIMENSIONS)
    canonical = np.transpose(values, axes=permutation)
    canonical_mask = np.transpose(finite_mask, axes=permutation)
    source_spectra = _array_in_dimensions(
        source.array("ayc/spectra"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    core._require(
        canonical.shape == source_spectra.shape,
        "candidate_shape_error",
        "candidate prediction shape differs from acquired spectra",
    )
    for candidate_coordinate, source_name, code, message in (
        (
            candidate.time_s,
            "ayc/time",
            "candidate_time_grid_error",
            "candidate time coordinate differs; interpolation is prohibited",
        ),
        (
            candidate.radial_index,
            "ayc/radial_index",
            "candidate_radial_grid_error",
            "candidate radial labels differ; registration is prohibited",
        ),
        (
            candidate.spectral_index,
            "ayc/spectral_index",
            "candidate_spectral_grid_error",
            "candidate spectral labels/order differ",
        ),
    ):
        # Compare at the candidate's original precision before any narrowing.
        # A lossless float32-to-float64 promotion is valid; a float64 nextafter
        # perturbation must remain observable and fail this exact-grid join.
        core._require(
            _coordinate_values_exact(
                candidate_coordinate, source.array(source_name).values
            ),
            code,
            message,
        )
    core._require(
        bool(canonical_mask[spectral_joint_mask].all()),
        "candidate_observed_population_nonfinite",
        "candidate is non-finite at one or more acquired spectral samples",
    )
    return _readonly_f64(canonical)


def _spectral_cell_identity_root(
    source: ThomsonSourceResponseSourceV1,
    label: float,
    mask: np.ndarray,
) -> str:
    digest = hashlib.sha256()
    digest.update(b"FusionConceptAI.thomson_source_response.spectral_cells.v1\0")
    digest.update(source.source_bundle_sha256.encode("ascii"))
    digest.update(struct.pack("<f", float(label)))
    digest.update(np.argwhere(mask).astype("<i8").tobytes(order="C"))
    return digest.hexdigest()


def _channel_residuals(
    source: ThomsonSourceResponseSourceV1,
    source_values: np.ndarray,
    comparator_values: np.ndarray,
    joint_mask: np.ndarray,
    comparator_role: str,
    unit_semantics_source: str,
) -> tuple[ChannelResidualV1, ...]:
    labels = source.array("ayc/spectral_index").values
    result: list[ChannelResidualV1] = []
    for channel_index, raw_label in enumerate(labels):
        label = float(raw_label)
        mask = _readonly_bool(joint_mask[:, :, channel_index])
        source_channel = _readonly_f64(source_values[:, :, channel_index])
        comparator_channel = _readonly_f64(comparator_values[:, :, channel_index])
        residual = np.full(source_channel.shape, np.nan, dtype="<f8")
        residual[mask] = source_channel[mask] - comparator_channel[mask]
        residual = _readonly_f64(residual)
        result.append(
            ChannelResidualV1(
                channel_label=label,
                role="raw_same_grid_channel_residual",
                source_role="acquired_raw_spectra",
                comparator_role=comparator_role,
                unit="V",
                unit_semantics_source=unit_semantics_source,
                mask=mask,
                source_values=source_channel,
                comparator_values=comparator_channel,
                residual_values=residual,
                mask_sha256=_mask_sha256(mask),
                residual_sha256=_array_sha256(residual),
                source_cell_identity_root_sha256=_spectral_cell_identity_root(
                    source, label, mask
                ),
                calibrated_response=False,
                selection_authorized=False,
            )
        )
    return tuple(result)


def _conditional_spectral_fit(
    source: ThomsonSourceResponseSourceV1,
    spectra: np.ndarray,
    fitted: np.ndarray,
    error: np.ndarray,
) -> Mapping[str, Any]:
    chi2 = _array_in_dimensions(source.array("ayc/chi2"), PROFILE_CANONICAL_DIMENSIONS)
    residual = spectra.astype(np.float64) - fitted.astype(np.float64)
    with np.errstate(invalid="ignore", divide="ignore", over="ignore"):
        channel_terms_valid = (
            np.isfinite(residual) & np.isfinite(error) & (error > 0.0)
        )
        eligible = (
            np.all(channel_terms_valid, axis=2)
            & np.isfinite(chi2)
            & (chi2 != 0.0)
        )
        conditional = 0.5 * np.sum((residual / error) ** 2, axis=2)
        relative = np.full(chi2.shape, np.nan, dtype="<f8")
        relative[eligible] = np.abs(conditional[eligible] - chi2[eligible]) / np.abs(
            chi2[eligible]
        )
    return MappingProxyType(
        {
            "status": "conditional_reported_chi2_hypothesis_only",
            "assumption": (
                "reported spectra_error behaves as a channel scale and reported "
                "chi2 equals 0.5*sum((spectra-aspectra)/spectra_error)^2"
            ),
            "assumption_supported_by_provider_evidence": False,
            "eligible_cell_count": int(eligible.sum()),
            "relative_error_le_1e_5_count": int(
                np.count_nonzero(eligible & (relative <= 1.0e-5))
            ),
            "relative_error_gt_1e_2_count": int(
                np.count_nonzero(eligible & (relative > 1.0e-2))
            ),
            "relative_error_gt_1_count": int(
                np.count_nonzero(eligible & (relative > 1.0))
            ),
            "eligible_mask_sha256": _mask_sha256(eligible),
            "conditional_value_sha256": _array_sha256(conditional),
            "reported_chi2_sha256": _array_sha256(chi2),
            "error_semantics": "unknown",
            "likelihood_ready": False,
            "selection_authorized": False,
        }
    )


def _masked_residual(
    observed: np.ndarray, predicted: np.ndarray, mask: np.ndarray
) -> np.ndarray:
    result = np.full(observed.shape, np.nan, dtype="<f8")
    result[mask] = observed[mask].astype(np.float64) - predicted[mask]
    return _readonly_f64(result)


def _conditional_pressure(
    source: ThomsonSourceResponseSourceV1,
    observation: level1.Level1ErrorObservation,
) -> ConditionalPressureDiagnosticV1:
    profile_mask = _readonly_bool(observation.observed_mask)
    pe = _array_in_dimensions(source.array("ayc/pe"), PROFILE_CANONICAL_DIMENSIONS)
    pe_error = _array_in_dimensions(
        source.array("ayc/pe_error"), PROFILE_CANONICAL_DIMENSIONS
    )
    pressure_mask = _readonly_bool(np.isfinite(pe))
    pressure_error_mask = _readonly_bool(np.isfinite(pe_error))
    ne = observation.ne.astype(np.float64)
    te = observation.te.astype(np.float64)
    ne_error = observation.ne_error.astype(np.float64)
    te_error = observation.te_error.astype(np.float64)
    covariance = observation.covariance_ne_te.astype(np.float64)
    with np.errstate(invalid="ignore", divide="ignore", over="ignore"):
        denominator = ne_error * te_error
        psd_eligible = profile_mask & (ne_error > 0.0) & (te_error > 0.0)
        rho = np.full(ne.shape, np.nan, dtype="<f8")
        rho[psd_eligible] = covariance[psd_eligible] / denominator[psd_eligible]
        psd_invalid = psd_eligible & np.isfinite(rho) & (np.abs(rho) > 1.0)
        linear_base = (
            (te * ne_error) ** 2
            + (ne * te_error) ** 2
            + 2.0 * ne * te * covariance
        )
        negative = profile_mask & np.isfinite(linear_base) & (linear_base < 0.0)
        comparison = (
            profile_mask
            & pressure_error_mask
            & np.isfinite(linear_base)
            & (linear_base >= 0.0)
        )
        retained_bad = comparison & psd_invalid
        ne_te = ne * te
        fingerprint_pressure = OBSERVED_PRESSURE_COEFFICIENT_FINGERPRINT * ne_te
        exact_si_pressure = EXACT_SI_ELEMENTARY_CHARGE * ne_te
        fingerprint_error = np.full(ne.shape, np.nan, dtype="<f8")
        exact_si_error = np.full(ne.shape, np.nan, dtype="<f8")
        fingerprint_error[comparison] = (
            OBSERVED_PRESSURE_COEFFICIENT_FINGERPRINT
            * np.sqrt(linear_base[comparison])
        )
        exact_si_error[comparison] = (
            EXACT_SI_ELEMENTARY_CHARGE * np.sqrt(linear_base[comparison])
        )
        coefficient = np.full(ne.shape, np.nan, dtype="<f8")
        coefficient[profile_mask] = pe[profile_mask].astype(np.float64) / ne_te[
            profile_mask
        ]
    finite_coefficient = coefficient[np.isfinite(coefficient)]
    existing = level1.conditional_error_consistency(observation)
    psd_invalid_count = int(psd_invalid.sum())
    negative_count = int(negative.sum())
    retained_count = int(retained_bad.sum())
    core._require(
        psd_invalid_count
        == existing["conditional_2x2_psd_failure_count"]
        == 191
        and negative_count == 7
        and retained_count == 184,
        "conditional_population_identity_error",
        "frozen PSD/variance populations differ; no cells may be silently removed",
    )
    return ConditionalPressureDiagnosticV1(
        profile_mask=profile_mask,
        pressure_mask=pressure_mask,
        pressure_error_mask=pressure_error_mask,
        psd_eligible_mask=_readonly_bool(psd_eligible),
        psd_invalid_mask=_readonly_bool(psd_invalid),
        linearized_variance_negative_mask=_readonly_bool(negative),
        positive_variance_comparison_mask=_readonly_bool(comparison),
        positive_variance_psd_invalid_mask=_readonly_bool(retained_bad),
        rho_star=_readonly_f64(rho),
        linearized_variance_base=_readonly_f64(linear_base),
        pressure_residual_fingerprint=_masked_residual(
            pe, fingerprint_pressure, profile_mask
        ),
        pressure_residual_exact_si=_masked_residual(
            pe, exact_si_pressure, profile_mask
        ),
        pressure_error_residual_fingerprint=_masked_residual(
            pe_error, fingerprint_error, comparison
        ),
        pressure_error_residual_exact_si=_masked_residual(
            pe_error, exact_si_error, comparison
        ),
        observed_coefficient_median=float(np.median(finite_coefficient)),
        observed_coefficient_min=float(finite_coefficient.min()),
        observed_coefficient_max=float(finite_coefficient.max()),
        psd_invalid_count=psd_invalid_count,
        negative_variance_count=negative_count,
        positive_variance_comparison_count=int(comparison.sum()),
        positive_variance_psd_invalid_count=retained_count,
        existing_level1_conditional=MappingProxyType(dict(existing)),
        pressure_unit="unknown_blank_source_unit",
        pressure_error_unit="unknown_blank_source_unit",
        error_semantics="conditional_first_order_delta_method_only",
        producer_formula_confirmed=False,
        correction_applied=False,
        likelihood_ready=False,
    )


def _auxiliary_inventory(
    source: ThomsonSourceResponseSourceV1,
) -> tuple[Mapping[str, Any], ...]:
    result: list[Mapping[str, Any]] = []
    for name in SOURCE_ARRAY_NAMES:
        array = source.arrays[name]
        finite = array.values[array.finite_mask]
        result.append(
            MappingProxyType(
                {
                    "name": name,
                    "dimensions": list(array.dimensions),
                    "shape": list(array.shape),
                    "unit": array.unit,
                    "finite_count": int(array.finite_mask.sum()),
                    "total_count": int(array.values.size),
                    "finite_min": float(finite.min()) if finite.size else None,
                    "finite_max": float(finite.max()) if finite.size else None,
                    "assembled_sha256": array.identity.assembled_sha256,
                    "interpretation": "raw_source_identity_and_population_only",
                }
            )
        )
    return tuple(result)


def _profile_masks_from_pressure(
    pressure: ConditionalPressureDiagnosticV1,
) -> dict[str, np.ndarray]:
    return {
        "level1_profile": pressure.profile_mask,
        "reported_pressure": pressure.pressure_mask,
        "reported_pressure_error": pressure.pressure_error_mask,
        "conditional_psd_eligible": pressure.psd_eligible_mask,
        "conditional_psd_invalid": pressure.psd_invalid_mask,
        "linearized_variance_negative": (
            pressure.linearized_variance_negative_mask
        ),
        "positive_variance_comparison": (
            pressure.positive_variance_comparison_mask
        ),
        "positive_variance_psd_invalid_retained": (
            pressure.positive_variance_psd_invalid_mask
        ),
    }


def _named_mask_identity_body(
    masks: Mapping[str, np.ndarray],
) -> list[dict[str, Any]]:
    return [
        {
            "name": name,
            **_array_storage_identity(np.asarray(mask, dtype=np.bool_)),
            "true_count": int(np.asarray(mask, dtype=np.bool_).sum()),
        }
        for name, mask in masks.items()
    ]


def _channel_identity_body(item: ChannelResidualV1) -> dict[str, Any]:
    return {
        "channel_label": item.channel_label,
        "role": item.role,
        "source_role": item.source_role,
        "comparator_role": item.comparator_role,
        "unit": item.unit,
        "unit_semantics_source": item.unit_semantics_source,
        "mask": _array_storage_identity(item.mask),
        "source_values": _array_storage_identity(item.source_values),
        "comparator_values": _array_storage_identity(item.comparator_values),
        "residual_values": _array_storage_identity(item.residual_values),
        "mask_sha256": item.mask_sha256,
        "residual_sha256": item.residual_sha256,
        "source_cell_identity_root_sha256": (
            item.source_cell_identity_root_sha256
        ),
        "calibrated_response": item.calibrated_response,
        "selection_authorized": item.selection_authorized,
    }


def _pressure_identity_body(
    pressure: ConditionalPressureDiagnosticV1,
) -> dict[str, Any]:
    array_names = (
        "profile_mask",
        "pressure_mask",
        "pressure_error_mask",
        "psd_eligible_mask",
        "psd_invalid_mask",
        "linearized_variance_negative_mask",
        "positive_variance_comparison_mask",
        "positive_variance_psd_invalid_mask",
        "rho_star",
        "linearized_variance_base",
        "pressure_residual_fingerprint",
        "pressure_residual_exact_si",
        "pressure_error_residual_fingerprint",
        "pressure_error_residual_exact_si",
    )
    return {
        "arrays": {
            name: _array_storage_identity(getattr(pressure, name))
            for name in array_names
        },
        "observed_coefficient_median": pressure.observed_coefficient_median,
        "observed_coefficient_min": pressure.observed_coefficient_min,
        "observed_coefficient_max": pressure.observed_coefficient_max,
        "psd_invalid_count": pressure.psd_invalid_count,
        "negative_variance_count": pressure.negative_variance_count,
        "positive_variance_comparison_count": (
            pressure.positive_variance_comparison_count
        ),
        "positive_variance_psd_invalid_count": (
            pressure.positive_variance_psd_invalid_count
        ),
        "existing_level1_conditional": core._plain(
            dict(pressure.existing_level1_conditional)
        ),
        "pressure_unit": pressure.pressure_unit,
        "pressure_error_unit": pressure.pressure_error_unit,
        "error_semantics": pressure.error_semantics,
        "producer_formula_confirmed": pressure.producer_formula_confirmed,
        "correction_applied": pressure.correction_applied,
        "likelihood_ready": pressure.likelihood_ready,
    }


def _diagnostic_body(
    source: ThomsonSourceResponseSourceV1,
    observation: level1.Level1ErrorObservation,
    fitted: Sequence[ChannelResidualV1],
    candidate: Sequence[ChannelResidualV1],
    pressure: ConditionalPressureDiagnosticV1,
    conditional_fit: Mapping[str, Any],
    candidate_prediction: CandidateSpectralPredictionV1 | None,
    spectral_masks: Mapping[str, np.ndarray],
    profile_masks: Mapping[str, np.ndarray],
    auxiliary_inventory: Sequence[Mapping[str, Any]],
) -> dict[str, Any]:
    return {
        "domain": "FusionConceptAI.thomson_source_response.diagnostic.v1",
        "version": SOURCE_RESPONSE_VERSION,
        "source_bundle_sha256": source.source_bundle_sha256,
        "level1_payload_sha256": observation.canonical_payload_sha256,
        "level1_lineage_sha256": observation.sample_lineage_sha256,
        "fitted": [_channel_identity_body(item) for item in fitted],
        "candidate": [_channel_identity_body(item) for item in candidate],
        "candidate_prediction": _candidate_identity_body(candidate_prediction),
        "pressure": _pressure_identity_body(pressure),
        "spectral_masks": _named_mask_identity_body(spectral_masks),
        "profile_masks": _named_mask_identity_body(profile_masks),
        "conditional_spectral_fit": core._plain(dict(conditional_fit)),
        "auxiliary_inventory": [
            core._plain(dict(item)) for item in auxiliary_inventory
        ],
        "calibrated_response": False,
        "likelihood_ready": False,
        "selection_authorized": False,
    }


def _candidate_identity_body(
    candidate: CandidateSpectralPredictionV1 | None,
) -> dict[str, Any] | None:
    if candidate is None:
        return None
    return {
        "candidate_id": candidate.candidate_id,
        "role": candidate.role,
        "calibrated_response": candidate.calibrated_response,
        "dimensions": list(candidate.dimensions),
        "unit": candidate.unit,
        "unit_semantics_source": candidate.unit_semantics_source,
        "values_sha256": _array_sha256(np.asarray(candidate.values, dtype="<f8")),
        "finite_mask_sha256": _mask_sha256(candidate.finite_mask),
        "time": _array_storage_identity(candidate.time_s),
        "radial_index": _array_storage_identity(candidate.radial_index),
        "spectral_index": _array_storage_identity(candidate.spectral_index),
    }


def diagnose_thomson_source_response_v1(
    level1_package: level1.Level1ErrorPackage,
    source: ThomsonSourceResponseSourceV1,
    *,
    candidate_prediction: CandidateSpectralPredictionV1 | None = None,
    request_weights: bool = False,
    request_likelihood: bool = False,
    require_calibrated_units: bool = False,
) -> ThomsonSourceResponseDiagnosticV1:
    """Compute exact-grid raw diagnostics without granting response semantics."""

    core._require(
        request_weights is False,
        "covariance_weights_prohibited",
        "unknown covariance/error semantics prohibit weights",
    )
    core._require(
        request_likelihood is False,
        "source_response_likelihood_prohibited",
        "calibration, response kernels, and error semantics are absent",
    )
    core._require(
        require_calibrated_units is False,
        "source_unit_semantics_missing",
        "pressure, pressure-error, spectra-error, and spectral-label units are blank",
    )
    level1.validate_level1_package_integrity(level1_package)
    observation = level1_package.observation(EXPECTED_SHOT)
    _validate_source_level1_join(source, observation)
    spectra = _array_in_dimensions(
        source.array("ayc/spectra"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    fitted = _array_in_dimensions(
        source.array("ayc/aspectra"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    error = _array_in_dimensions(
        source.array("ayc/spectra_error"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    spectra_mask = _readonly_bool(np.isfinite(spectra))
    fitted_mask = _readonly_bool(np.isfinite(fitted))
    error_mask = _readonly_bool(np.isfinite(error))
    core._require(
        np.array_equal(spectra_mask, fitted_mask)
        and np.array_equal(spectra_mask, error_mask),
        "source_spectral_finite_mask_mismatch",
        "spectra, fitted spectra, and spectra-error populations differ",
    )
    core._require(
        int(spectra_mask.sum()) == 72_500,
        "source_spectral_population_identity_error",
        "frozen spectral finite population differs",
    )
    fitted_residuals = _channel_residuals(
        source,
        spectra,
        fitted,
        spectra_mask,
        "acquired_provider_fitted_spectra",
        "source ayc/spectra and ayc/aspectra attributes.units",
    )
    candidate_residuals: tuple[ChannelResidualV1, ...] = ()
    if candidate_prediction is not None:
        candidate_values = _validate_candidate_prediction(
            candidate_prediction, source, spectra_mask
        )
        candidate_residuals = _channel_residuals(
            source,
            spectra,
            candidate_values,
            spectra_mask,
            "uncalibrated_candidate_prediction",
            candidate_prediction.unit_semantics_source,
        )
    pressure = _conditional_pressure(source, observation)
    conditional_fit = _conditional_spectral_fit(source, spectra, fitted, error)
    spectral_masks = MappingProxyType(
        {
            "acquired_spectra": spectra_mask,
            "provider_fitted_spectra": fitted_mask,
            "reported_spectra_error": error_mask,
            "joint_residual_population": _readonly_bool(
                spectra_mask & fitted_mask & error_mask
            ),
        }
    )
    profile_masks = MappingProxyType(_profile_masks_from_pressure(pressure))
    auxiliary_inventory = _auxiliary_inventory(source)
    body = _diagnostic_body(
        source,
        observation,
        fitted_residuals,
        candidate_residuals,
        pressure,
        conditional_fit,
        candidate_prediction,
        spectral_masks,
        profile_masks,
        auxiliary_inventory,
    )
    diagnostic = ThomsonSourceResponseDiagnosticV1(
        version=SOURCE_RESPONSE_VERSION,
        source=source,
        level1_observation=observation,
        fitted_channel_residuals=fitted_residuals,
        candidate_channel_residuals=candidate_residuals,
        candidate_prediction=candidate_prediction,
        pressure=pressure,
        spectral_masks=spectral_masks,
        profile_masks=profile_masks,
        conditional_spectral_fit=conditional_fit,
        auxiliary_inventory=auxiliary_inventory,
        diagnostic_sha256=_canonical_hash(body),
        calibrated_response=False,
        likelihood_ready=False,
        covariance_weights_authorized=False,
        selection_authorized=False,
        claim_ceiling=CLAIM_CEILING,
    )
    validate_thomson_source_response_diagnostic_v1(diagnostic)
    return diagnostic


def validate_thomson_source_response_diagnostic_v1(
    diagnostic: ThomsonSourceResponseDiagnosticV1,
) -> dict[str, Any]:
    validate_thomson_source_response_source_v1(diagnostic.source)
    level1.validate_level1_observation(diagnostic.level1_observation)
    _validate_source_level1_join(diagnostic.source, diagnostic.level1_observation)
    core._require(
        diagnostic.version == SOURCE_RESPONSE_VERSION
        and len(diagnostic.fitted_channel_residuals) == 4
        and len(diagnostic.candidate_channel_residuals)
        in {0, 4}
        and diagnostic.calibrated_response is False
        and diagnostic.likelihood_ready is False
        and diagnostic.covariance_weights_authorized is False
        and diagnostic.selection_authorized is False
        and diagnostic.claim_ceiling == CLAIM_CEILING,
        "source_response_diagnostic_metadata_error",
        "diagnostic status, roles, or claim ceiling differs",
    )
    spectra = _array_in_dimensions(
        diagnostic.source.array("ayc/spectra"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    fitted_source = _array_in_dimensions(
        diagnostic.source.array("ayc/aspectra"), SPECTRAL_CANONICAL_DIMENSIONS
    )
    spectral_mask = np.isfinite(spectra)
    candidate_values: np.ndarray | None = None
    if diagnostic.candidate_prediction is None:
        core._require(
            not diagnostic.candidate_channel_residuals,
            "candidate_prediction_integrity_error",
            "candidate residuals exist without a candidate prediction",
        )
    else:
        core._require(
            len(diagnostic.candidate_channel_residuals) == 4,
            "candidate_prediction_integrity_error",
            "candidate prediction requires four channel residuals",
        )
        candidate_values = _validate_candidate_prediction(
            diagnostic.candidate_prediction, diagnostic.source, spectral_mask
        )
    expected_labels = (1.0, 2.0, 3.0, 4.0)
    for group, expected_comparator, expected_unit_semantics_source in (
        (
            diagnostic.fitted_channel_residuals,
            "acquired_provider_fitted_spectra",
            "source ayc/spectra and ayc/aspectra attributes.units",
        ),
        (
            diagnostic.candidate_channel_residuals,
            "uncalibrated_candidate_prediction",
            (
                diagnostic.candidate_prediction.unit_semantics_source
                if diagnostic.candidate_prediction is not None
                else ""
            ),
        ),
    ):
        if not group:
            continue
        for expected_label, item in zip(expected_labels, group, strict=True):
            core._require(
                item.channel_label == expected_label
                and item.role == "raw_same_grid_channel_residual"
                and item.source_role == "acquired_raw_spectra"
                and item.comparator_role == expected_comparator
                and item.unit == "V"
                and item.unit_semantics_source
                == expected_unit_semantics_source
                and item.calibrated_response is False
                and item.selection_authorized is False
                and np.array_equal(item.mask, np.isfinite(item.residual_values))
                and item.mask_sha256 == _mask_sha256(item.mask)
                and item.residual_sha256 == _array_sha256(item.residual_values)
                and item.source_cell_identity_root_sha256
                == _spectral_cell_identity_root(
                    diagnostic.source, item.channel_label, item.mask
                ),
                "source_response_channel_integrity_error",
                f"channel {expected_label}: residual identity or role differs",
            )
            core._require(
                np.array_equal(
                    item.residual_values[item.mask],
                    item.source_values[item.mask] - item.comparator_values[item.mask],
                ),
                "source_response_channel_integrity_error",
                f"channel {expected_label}: residual values are stale",
            )
            channel_index = int(expected_label - 1.0)
            expected_comparator_values = (
                fitted_source[:, :, channel_index]
                if expected_comparator == "acquired_provider_fitted_spectra"
                else candidate_values[:, :, channel_index]
            )
            core._require(
                np.array_equal(
                    item.source_values,
                    spectra[:, :, channel_index],
                    equal_nan=True,
                )
                and np.array_equal(
                    item.comparator_values,
                    expected_comparator_values,
                    equal_nan=True,
                )
                and np.array_equal(item.mask, spectral_mask[:, :, channel_index]),
                "source_response_channel_projection_error",
                f"channel {expected_label}: residual endpoints differ from source",
            )
    pressure = diagnostic.pressure
    expected_pressure = _conditional_pressure(
        diagnostic.source, diagnostic.level1_observation
    )
    pressure_arrays = (
        "profile_mask",
        "pressure_mask",
        "pressure_error_mask",
        "psd_eligible_mask",
        "psd_invalid_mask",
        "linearized_variance_negative_mask",
        "positive_variance_comparison_mask",
        "positive_variance_psd_invalid_mask",
        "rho_star",
        "linearized_variance_base",
        "pressure_residual_fingerprint",
        "pressure_residual_exact_si",
        "pressure_error_residual_fingerprint",
        "pressure_error_residual_exact_si",
    )
    core._require(
        all(
            _array_storage_equal(
                getattr(pressure, name), getattr(expected_pressure, name)
            )
            for name in pressure_arrays
        )
        and pressure.observed_coefficient_median
        == expected_pressure.observed_coefficient_median
        and pressure.observed_coefficient_min
        == expected_pressure.observed_coefficient_min
        and pressure.observed_coefficient_max
        == expected_pressure.observed_coefficient_max
        and pressure.psd_invalid_count == expected_pressure.psd_invalid_count
        and pressure.negative_variance_count
        == expected_pressure.negative_variance_count
        and pressure.positive_variance_comparison_count
        == expected_pressure.positive_variance_comparison_count
        and pressure.positive_variance_psd_invalid_count
        == expected_pressure.positive_variance_psd_invalid_count
        and core.canonical_json_bytes(
            core._plain(dict(pressure.existing_level1_conditional))
        )
        == core.canonical_json_bytes(
            core._plain(dict(expected_pressure.existing_level1_conditional))
        )
        and pressure.pressure_unit == expected_pressure.pressure_unit
        and pressure.pressure_error_unit == expected_pressure.pressure_error_unit
        and pressure.error_semantics == expected_pressure.error_semantics
        and pressure.producer_formula_confirmed
        is expected_pressure.producer_formula_confirmed
        and pressure.correction_applied is expected_pressure.correction_applied
        and pressure.likelihood_ready is expected_pressure.likelihood_ready,
        "conditional_pressure_recomputation_error",
        "conditional pressure arrays differ from independently rebuilt inputs",
    )
    core._require(
        pressure.psd_invalid_count == int(pressure.psd_invalid_mask.sum()) == 191
        and pressure.negative_variance_count
        == int(pressure.linearized_variance_negative_mask.sum())
        == 7
        and pressure.positive_variance_comparison_count
        == int(pressure.positive_variance_comparison_mask.sum())
        == 15_856
        and pressure.positive_variance_psd_invalid_count
        == int(pressure.positive_variance_psd_invalid_mask.sum())
        == 184
        and np.all(
            ~pressure.positive_variance_psd_invalid_mask
            | pressure.positive_variance_comparison_mask
        )
        and np.all(
            ~pressure.positive_variance_psd_invalid_mask
            | pressure.psd_invalid_mask
        )
        and pressure.pressure_unit == "unknown_blank_source_unit"
        and pressure.pressure_error_unit == "unknown_blank_source_unit"
        and pressure.error_semantics
        == "conditional_first_order_delta_method_only"
        and pressure.producer_formula_confirmed is False
        and pressure.correction_applied is False
        and pressure.likelihood_ready is False,
        "conditional_pressure_integrity_error",
        "conditional pressure populations or semantic ceiling differ",
    )
    expected_fit = _conditional_spectral_fit(
        diagnostic.source,
        spectra,
        fitted_source,
        _array_in_dimensions(
            diagnostic.source.array("ayc/spectra_error"),
            SPECTRAL_CANONICAL_DIMENSIONS,
        ),
    )
    core._require(
        core.canonical_json_bytes(core._plain(dict(diagnostic.conditional_spectral_fit)))
        == core.canonical_json_bytes(core._plain(dict(expected_fit))),
        "conditional_spectral_fit_recomputation_error",
        "conditional spectral-fit diagnostic differs from raw source arrays",
    )
    expected_spectral_masks = {
        "acquired_spectra": np.isfinite(spectra),
        "provider_fitted_spectra": np.isfinite(fitted_source),
        "reported_spectra_error": np.isfinite(
            _array_in_dimensions(
                diagnostic.source.array("ayc/spectra_error"),
                SPECTRAL_CANONICAL_DIMENSIONS,
            )
        ),
    }
    expected_spectral_masks["joint_residual_population"] = (
        expected_spectral_masks["acquired_spectra"]
        & expected_spectral_masks["provider_fitted_spectra"]
        & expected_spectral_masks["reported_spectra_error"]
    )
    core._require(
        tuple(diagnostic.spectral_masks) == tuple(expected_spectral_masks)
        and all(
            np.array_equal(diagnostic.spectral_masks[name], expected)
            for name, expected in expected_spectral_masks.items()
        ),
        "source_response_spectral_mask_integrity_error",
        "stored spectral masks differ from independent raw-array masks",
    )
    expected_profile_masks = _profile_masks_from_pressure(expected_pressure)
    core._require(
        tuple(diagnostic.profile_masks) == tuple(expected_profile_masks)
        and all(
            _array_storage_equal(diagnostic.profile_masks[name], expected)
            for name, expected in expected_profile_masks.items()
        ),
        "source_response_profile_mask_integrity_error",
        "stored profile masks differ from independently rebuilt populations",
    )
    core._require(
        core.canonical_json_bytes(
            [core._plain(dict(item)) for item in diagnostic.auxiliary_inventory]
        )
        == core.canonical_json_bytes(
            [core._plain(dict(item)) for item in _auxiliary_inventory(diagnostic.source)]
        ),
        "source_response_auxiliary_inventory_error",
        "twenty-array auxiliary inventory differs from raw source",
    )
    body = _diagnostic_body(
        diagnostic.source,
        diagnostic.level1_observation,
        diagnostic.fitted_channel_residuals,
        diagnostic.candidate_channel_residuals,
        pressure,
        diagnostic.conditional_spectral_fit,
        diagnostic.candidate_prediction,
        diagnostic.spectral_masks,
        diagnostic.profile_masks,
        diagnostic.auxiliary_inventory,
    )
    core._require(
        _canonical_hash(body) == diagnostic.diagnostic_sha256,
        "source_response_diagnostic_hash_mismatch",
        "diagnostic identity is stale",
    )
    return {
        "status": "pass_conditional_diagnostics_only",
        "shot_id": diagnostic.source.shot_id,
        "source_array_count": len(diagnostic.source.arrays),
        "spectral_finite_count": int(
            diagnostic.spectral_masks["joint_residual_population"].sum()
        ),
        "profile_cell_count": diagnostic.level1_observation.observed_count,
        "conditional_psd_invalid_count": pressure.psd_invalid_count,
        "positive_variance_psd_invalid_retained_count": (
            pressure.positive_variance_psd_invalid_count
        ),
        "diagnostic_sha256": diagnostic.diagnostic_sha256,
        "calibrated_response": False,
        "likelihood_ready": False,
        "selection_authorized": False,
    }


def iter_source_spectral_residual_cells_v1(
    diagnostic: ThomsonSourceResponseDiagnosticV1,
    *,
    comparator: str = "fitted",
) -> Iterator[dict[str, Any]]:
    """Yield traceable acquired-grid residual cells without response claims."""

    validate_thomson_source_response_diagnostic_v1(diagnostic)
    core._require(
        comparator in {"fitted", "candidate"},
        "source_response_comparator_error",
        "comparator must be fitted or candidate",
    )
    residuals = (
        diagnostic.fitted_channel_residuals
        if comparator == "fitted"
        else diagnostic.candidate_channel_residuals
    )
    core._require(
        residuals,
        "candidate_prediction_missing",
        "candidate residuals were not requested",
    )
    time_s = diagnostic.source.array("ayc/time").values
    radial_index = diagnostic.source.array("ayc/radial_index").values
    for item in residuals:
        for t_raw, r_raw in np.argwhere(item.mask):
            t_index, r_index = int(t_raw), int(r_raw)
            sample_id = (
                f"mast:{diagnostic.source.shot_id}:level1:ayc:source-response:"
                f"t{t_index}:ri{r_index}:ch{item.channel_label:g}"
            )
            digest = hashlib.sha256()
            digest.update(
                b"FusionConceptAI.thomson_source_response.spectral_cell.v1\0"
            )
            digest.update(diagnostic.source.source_bundle_sha256.encode("ascii"))
            digest.update(sample_id.encode("utf-8"))
            digest.update(struct.pack("<IIf", t_index, r_index, item.channel_label))
            yield {
                "sample_id": sample_id,
                "sample_sha256": digest.hexdigest(),
                "raw_index": [t_index, r_index, int(item.channel_label - 1.0)],
                "canonical_index": [
                    t_index,
                    r_index,
                    int(item.channel_label - 1.0),
                ],
                "time_s": float(time_s[t_index]),
                "radial_index": float(radial_index[r_index]),
                "spectral_label": item.channel_label,
                "source_value": float(item.source_values[t_index, r_index]),
                "comparator_value": float(
                    item.comparator_values[t_index, r_index]
                ),
                "residual": float(item.residual_values[t_index, r_index]),
                "unit": item.unit,
                "source_role": item.source_role,
                "comparator_role": item.comparator_role,
                "calibrated_response": False,
                "selection_authorized": False,
            }


def iter_joined_level1_profile_cells_v1(
    diagnostic: ThomsonSourceResponseDiagnosticV1,
) -> Iterator[dict[str, Any]]:
    """Reuse existing Level-1 cell IDs and add conditional pressure flags."""

    validate_thomson_source_response_diagnostic_v1(diagnostic)
    pressure = diagnostic.pressure
    pe = _array_in_dimensions(
        diagnostic.source.array("ayc/pe"), PROFILE_CANONICAL_DIMENSIONS
    )
    pe_error = _array_in_dimensions(
        diagnostic.source.array("ayc/pe_error"), PROFILE_CANONICAL_DIMENSIONS
    )
    for cell in level1.iter_level1_cells(diagnostic.level1_observation):
        t_index, r_index = cell["canonical_index"]
        yield {
            **cell,
            "reported_pressure": float(pe[t_index, r_index]),
            "reported_pressure_error": float(pe_error[t_index, r_index]),
            "conditional_psd_invalid": bool(
                pressure.psd_invalid_mask[t_index, r_index]
            ),
            "linearized_variance_negative": bool(
                pressure.linearized_variance_negative_mask[t_index, r_index]
            ),
            "included_in_positive_variance_comparison": bool(
                pressure.positive_variance_comparison_mask[t_index, r_index]
            ),
            "pressure_unit": pressure.pressure_unit,
            "pressure_error_unit": pressure.pressure_error_unit,
            "producer_formula_confirmed": False,
            "likelihood_ready": False,
        }
