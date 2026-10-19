#!/usr/bin/env python3
"""Execute a bounded real-data reference consumer without asserting inverse readiness.

This test-path runner joins the existing FAIR-MAST Level-2 package, Level-1
error package, shot-30421 Thomson source-response diagnostic, and raw EFM
fcoil_x/fcoil_c comparison. It does not create candidate predictions, run an
optimizer, or promote any evidence.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import numpy as np
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


def find_repo_root(script_path: Path) -> Path:
    for candidate in script_path.resolve().parents:
        if (candidate / "AGENTS.md").is_file() and (
            candidate / "benchmarks" / "reference_validation_v1"
        ).is_dir():
            return candidate
    raise RuntimeError(f"cannot locate FusionConceptAI root from {script_path}")


REPO_ROOT = find_repo_root(Path(__file__))
RUNNER_REPO_PATH = Path(__file__).resolve().relative_to(REPO_ROOT).as_posix()
if RUNNER_REPO_PATH != "test/UP4ReferenceActualConsumerV1/consume_actual_reference.py":
    raise RuntimeError(f"runner is outside its owned test path: {RUNNER_REPO_PATH}")
VALIDATION_DIR = REPO_ROOT / "benchmarks" / "reference_validation_v1"
sys.path.insert(0, str(VALIDATION_DIR))

import level1_error_adapter as level1  # noqa: E402
import reference_adapter as reference  # noqa: E402
import thomson_source_response_v1 as thomson  # noqa: E402
import official_partial_join_v1 as official_partial  # noqa: E402


EFM_SOURCE_DIR = REPO_ROOT / "benchmarks" / "reference_source_fields_v1" / "shot30421_coil_geometry_r1"
EFM_FCOIL_X_SOURCE_DIR = REPO_ROOT / "benchmarks" / "reference_source_fields_v1" / "shot30421_fcoil_x_r1"
EFM_FIELD_NAMES = (
    "efm__fcoil_r", "efm__fcoil_z", "efm__fcoil_width", "efm__fcoil_height",
    "efm__fcoil_ang1", "efm__fcoil_ang2", "efm__fcoil_circ",
    "efm__fcoil_turns", "efm__fcoil_xmult", "efm__fcoil_c",
    "efm__limiterr", "efm__limiterz", "efm__qpsi_c",
)
AYC_INPUT_DIR = REPO_ROOT / "runs" / "e" / "up4_mast_ayc_inputs_20261001_r6"


STATIC_INPUTS = (
    "AGENTS.md",
    "docs/v4_multitopology_generation/README.md",
    "docs/v4_multitopology_generation/16_execution_work_orders.md",
    "docs/v4_multitopology_generation/task_manifest.json",
    "docs/v4_multitopology_generation/12_composition_and_inverse_realization.md",
    "docs/v4_multitopology_generation/13_acceptance_benchmarks_and_evidence.md",
    "docs/v4_multitopology_generation/21_next_execution_batches.md",
    "docs/v4_multitopology_generation/25_astra_execution_and_recovery.md",
    "benchmarks/reference_data_v2/reference_manifest.json",
    "benchmarks/reference_data_v2/inverse_protocol.json",
    "benchmarks/reference_validation_v1/protocol.json",
    "benchmarks/reference_validation_v1/level1_protocol.json",
    "benchmarks/reference_validation_v1/source_evidence.json",
    "benchmarks/reference_validation_expansion_v1/protocol.json",
    "benchmarks/reference_validation_expansion_v1/acquisition_index.json",
    "benchmarks/reference_data_level1_expansion_v1/selection.json",
    # These formerly referenced deleted historical review snapshots. Bind the
    # currently present source acquisitions and their explicit findings instead.
    "runs/e/up4_mast_efm_inputs_20261001_r6/findings.md",
    "benchmarks/reference_source_fields_v1/shot30421_coil_geometry_r1/acquisition.json",
    "benchmarks/reference_source_fields_v1/shot30421_coil_geometry_r1/selection.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/acquisition.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/selection.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/zmetadata.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__fcoil_x/field_metadata.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__fcoil_x/assembled.raw",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__time/field_metadata.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__time/assembled.raw",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__fcoil_n/field_metadata.json",
    "benchmarks/reference_source_fields_v1/shot30421_fcoil_x_r1/fields/efm__fcoil_n/assembled.raw",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/findings.md",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_profile_array_acquisition.json",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_small_object_intake_original.md",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_small_object_receipt_original.json",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_small_object_values_original.json",
    "runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_zmetadata_shot30421.raw.json",
    "runs/e/up4_firstparty_source_search_r4/mappings__level2__mast.yml",
    "runs/e/up4_firstparty_source_search_r4/ingestion_sources_receipt.json",
    "runs/e/up4_firstparty_source_search_r4/pf_thomson_selected_metadata.json",
    "runs/e/up4_firstparty_source_search_r4/shot30421_level2_zarr.json.json",
    "runs/e/up4_firstparty_source_search_r4/shot30421_level2_group_lookup_receipt.json",
) + tuple(
    f"benchmarks/reference_source_fields_v1/shot30421_coil_geometry_r1/fields/{name}/{leaf}"
    for name in EFM_FIELD_NAMES
    for leaf in ("field_metadata.json", "assembled.raw")
) + tuple(
    f"runs/e/up4_mast_ayc_inputs_20261001_r6/ayc_raw/{name}"
    for name in (
        "passnumber.chunk.raw", "polyname.chunk.raw", "polyname.decoded.f32le",
        "status.chunk.raw", "version_fibre.chunk.raw", "version_poly.chunk.raw",
        "version_raman.chunk.raw",
    )
)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False
    ).encode("utf-8") + b"\n"


def write_json(path: Path, value: Any) -> str:
    payload = json.dumps(
        value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False
    ).encode("utf-8") + b"\n"
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest()


def workspace_state() -> dict[str, Any]:
    return {
        "workspace_root": str(REPO_ROOT),
        "consumer_cwd": str(Path.cwd().resolve()),
        "consumer_path": RUNNER_REPO_PATH,
        "source_state": "git_metadata_not_queried",
    }


def static_file_hashes() -> dict[str, str]:
    hashes: dict[str, str] = {}
    for relative in STATIC_INPUTS:
        path = REPO_ROOT / Path(relative)
        if not path.is_file():
            raise FileNotFoundError(f"required frozen input is missing: {relative}")
        hashes[relative] = sha256_file(path)
    return hashes


def mast_efm_source_snapshot() -> dict[str, Any]:
    """Verify the acquired classic-MAST EFM input package without inventing a join."""
    acquisition_path = EFM_SOURCE_DIR / "acquisition.json"
    selection_path = EFM_SOURCE_DIR / "selection.json"
    acquisition = json.loads(acquisition_path.read_text(encoding="utf-8"))
    selection = json.loads(selection_path.read_text(encoding="utf-8"))
    if acquisition.get("shot") != 30421 or selection.get("shot") != 30421:
        raise RuntimeError("EFM source package is not bound to shot 30421")
    records = {item["requested_path"]: item for item in acquisition["arrays"]}
    selected = {item["requested_path"]: item for item in selection["requested_fields"]}
    field_identities: dict[str, Any] = {}
    for name in EFM_FIELD_NAMES:
        requested = name.replace("__", "/")
        if requested not in records or requested not in selected:
            raise RuntimeError(f"EFM source field is absent from frozen selection: {requested}")
        record = records[requested]
        relative = record.get("assembled_raw_path")
        if not isinstance(relative, str) or not relative:
            raise RuntimeError(f"EFM assembled raw path is missing: {requested}")
        raw_path = (EFM_SOURCE_DIR / relative).resolve()
        try:
            raw_path.relative_to(EFM_SOURCE_DIR.resolve())
        except ValueError as exc:
            raise RuntimeError(f"EFM source path escapes package: {requested}") from exc
        if not raw_path.is_file():
            raise FileNotFoundError(f"EFM assembled raw source is missing: {relative}")
        raw = raw_path.read_bytes()
        digest = hashlib.sha256(raw).hexdigest()
        if len(raw) != record.get("assembled_raw_bytes") or digest != record.get("assembled_raw_sha256"):
            raise RuntimeError(f"EFM assembled source does not match acquisition receipt: {requested}")
        metadata_path = raw_path.parent / "field_metadata.json"
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        attributes = metadata.get("attributes", {})
        if metadata.get("requested_path") != requested or attributes.get("shot_id") != 30421:
            raise RuntimeError(f"EFM field metadata is not bound to shot 30421: {requested}")
        field_identities[requested] = {
            "shape": metadata.get("shape"),
            "dimensions": metadata.get("dimensions"),
            "dtype": metadata.get("dtype"),
            "units": attributes.get("units"),
            "quality": attributes.get("quality"),
            "assembled_bytes": len(raw),
            "assembled_sha256": digest,
        }

    circuit_ids = field_identities["efm/fcoil_circ"]
    turns = field_identities["efm/fcoil_turns"]
    multiplier = field_identities["efm/fcoil_xmult"]
    geometry_shape = [938]
    for path in ("efm/fcoil_circ", "efm/fcoil_turns", "efm/fcoil_xmult"):
        if field_identities[path]["shape"] != geometry_shape:
            raise RuntimeError(f"EFM segment shape is not 938 for {path}")
    if field_identities["efm/fcoil_c"]["shape"] != [120, 101]:
        raise RuntimeError("EFM computed current shape changed from [120, 101]")
    comparator = mast_efm_fcoil_current_comparison(acquisition)
    return {
        "shot_id": 30421,
        "source_revision": "Level-1 EFM version 0; fields are provider-labelled Analysed / Not Checked",
        "acquisition_path": acquisition_path.relative_to(REPO_ROOT).as_posix(),
        "selection_path": selection_path.relative_to(REPO_ROOT).as_posix(),
        "field_count": len(field_identities),
        "field_identities": field_identities,
        "fcoil_current_comparison": comparator,
        "segment_geometry_count": 938,
        "fcoil_c_dimension": "[time, fcoil_n] = [120, 101], computed current",
        "measured_fcoil_x_in_acquired_geometry_package": "acquired_in_separate_hash-bound_first-party_source_package",
        "candidate_circuit_id_crosswalk": "observed values 1..101 are compatible with zero-based 0..100 slots; index-base join not source-confirmed",
        "signed_segment_current": "typed_absent",
        "turns_and_xmult_use": "typed_absent; both source metadata unit labels are deg and no authoritative multiplication rule is present",
        "per_circuit_winding_polarity": "typed_absent",
        "likelihood_ready": False,
    }


def mast_efm_fcoil_current_comparison(geometry_acquisition: dict[str, Any]) -> dict[str, Any]:
    """Compare provider-labelled fitted currents without projecting segment currents."""
    acquisition_path = EFM_FCOIL_X_SOURCE_DIR / "acquisition.json"
    selection_path = EFM_FCOIL_X_SOURCE_DIR / "selection.json"
    acquisition = json.loads(acquisition_path.read_text(encoding="utf-8"))
    selection = json.loads(selection_path.read_text(encoding="utf-8"))
    if acquisition.get("shot") != 30421 or selection.get("shot") != 30421:
        raise RuntimeError("EFM fcoil_x source package is not bound to shot 30421")
    if acquisition.get("metadata_sha256") != geometry_acquisition.get("metadata_sha256"):
        raise RuntimeError("EFM fcoil_x and geometry packages use different Level-1 metadata snapshots")
    records = {item["requested_path"]: item for item in acquisition["arrays"]}
    selected = {item["requested_path"] for item in selection["requested_fields"]}
    geometry_acquisition_path = EFM_SOURCE_DIR / "acquisition.json"
    geometry_selection_path = EFM_SOURCE_DIR / "selection.json"
    geometry_acquisition = json.loads(geometry_acquisition_path.read_text(encoding="utf-8"))
    geometry_selection = json.loads(geometry_selection_path.read_text(encoding="utf-8"))
    geometry_records = {item["requested_path"]: item for item in geometry_acquisition["arrays"]}
    geometry_selected = {item["requested_path"] for item in geometry_selection["requested_fields"]}

    def load_field(path: str) -> tuple[dict[str, Any], np.ndarray]:
        package = EFM_SOURCE_DIR if path in geometry_records else EFM_FCOIL_X_SOURCE_DIR
        package_records = geometry_records if package == EFM_SOURCE_DIR else records
        package_selected = geometry_selected if package == EFM_SOURCE_DIR else selected
        if path not in package_records or path not in package_selected:
            raise RuntimeError(f"EFM fcoil comparator field is absent from selection: {path}")
        record = package_records[path]
        raw_relative = record.get("assembled_raw_path")
        if not isinstance(raw_relative, str) or not raw_relative:
            raise RuntimeError(f"EFM fcoil comparator raw path is missing: {path}")
        raw_path = (package / raw_relative).resolve()
        try:
            raw_path.relative_to(package.resolve())
        except ValueError as exc:
            raise RuntimeError(f"EFM fcoil comparator path escapes package: {path}") from exc
        raw = raw_path.read_bytes()
        if len(raw) != record.get("assembled_raw_bytes") or hashlib.sha256(raw).hexdigest() != record.get("assembled_raw_sha256"):
            raise RuntimeError(f"EFM fcoil comparator raw bytes do not match receipt: {path}")
        metadata_path = raw_path.parent / "field_metadata.json"
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        attributes = metadata.get("attributes", {})
        if metadata.get("requested_path") != path or attributes.get("shot_id") not in (None, 30421):
            raise RuntimeError(f"EFM fcoil comparator field metadata is not bound to shot 30421: {path}")
        dtype = np.dtype(metadata["dtype"])
        values = np.frombuffer(raw, dtype=dtype).reshape(metadata["shape"], order="C")
        identity = {
            "requested_path": path,
            "shape": metadata.get("shape"),
            "dimensions": metadata.get("dimensions"),
            "dtype": metadata.get("dtype"),
            "units": attributes.get("units"),
            "signal_type": attributes.get("signal_type"),
            "version": attributes.get("version"),
            "uuid": attributes.get("uuid"),
            "raw_sha256": hashlib.sha256(raw).hexdigest(),
        }
        return identity, values

    x_identity, x = load_field("efm/fcoil_x")
    c_identity, c = load_field("efm/fcoil_c")
    time_identity, times = load_field("efm/time")
    coil_identity, coils = load_field("efm/fcoil_n")
    expected_dims = ["time", "fcoil_n"]
    for name, identity in (("fcoil_x", x_identity), ("fcoil_c", c_identity)):
        if identity["shape"] != [120, 101] or identity["dimensions"] != expected_dims or identity["units"] != "A":
            raise RuntimeError(f"EFM {name} metadata shape/dimensions/units differ from the Level-1 catalog")
        if identity["signal_type"] != "Analysed" or identity["version"] != 0:
            raise RuntimeError(f"EFM {name} source identity differs from shot 30421 Level-1 version 0")
    if x.shape != c.shape or time_identity["shape"] != [120] or time_identity["dimensions"] != ["time"]:
        raise RuntimeError("EFM measured/computed current shapes or time coordinate shape do not match")
    if time_identity["units"] != "S" or not np.all(np.isfinite(times)):
        raise RuntimeError("EFM time coordinate is not a finite seconds-valued source coordinate")
    if coil_identity["shape"] != [101] or coil_identity["dimensions"] != ["fcoil_n"]:
        raise RuntimeError("EFM current coil coordinate shape/dimension does not match catalog")
    if not np.all(np.isfinite(coils)):
        raise RuntimeError("EFM current coil coordinate contains non-finite values")
    for current_path in ("efm/fcoil_x", "efm/fcoil_c"):
        record = (geometry_records if current_path == "efm/fcoil_c" else records).get(current_path)
        coordinates = record.get("coordinate_paths", []) if record else []
        if [(item.get("dimension"), item.get("path")) for item in coordinates] != [
            ("time", "efm/time"), ("fcoil_n", "efm/fcoil_n")
        ]:
            raise RuntimeError(f"EFM {current_path} does not declare the acquired time and coil coordinates")
    mask = np.isfinite(x) & np.isfinite(c)
    if not np.any(mask):
        raise RuntimeError("EFM measured/computed current comparison has no jointly finite samples")
    delta = x[mask].astype(np.float64) - c[mask].astype(np.float64)
    return {
        "status": "compared_provider_labelled_fitted_currents_only",
        "acquisition_path": acquisition_path.relative_to(REPO_ROOT).as_posix(),
        "selection_path": selection_path.relative_to(REPO_ROOT).as_posix(),
        "source_revision": "Level-1 EFM version 0; fields are provider-labelled Analysed / Not Checked",
        "metadata_sha256": acquisition["metadata_sha256"],
        "measured_fcoil_x": x_identity,
        "computed_fcoil_c": c_identity,
        "shared_coordinate_identity": {
            "time": time_identity,
            "fcoil_n": coil_identity,
            "coordinate_values_equal_by_shared_metadata_source": True,
            "time_coordinate_finite_count": int(np.isfinite(times).sum()),
            "fcoil_n_coordinate_finite_count": int(np.isfinite(coils).sum()),
        },
        "comparison": {
            "joint_finite_count": int(mask.sum()),
            "measured_finite_count": int(np.isfinite(x).sum()),
            "computed_finite_count": int(np.isfinite(c).sum()),
            "exact_equal_count": int(np.count_nonzero(x[mask] == c[mask])),
            "difference_definition": "fcoil_x - fcoil_c for jointly finite provider-labelled fitted-current samples",
            "mean_difference_A": float(np.mean(delta)),
            "root_mean_square_difference_A": float(np.sqrt(np.mean(delta * delta))),
            "maximum_absolute_difference_A": float(np.max(np.abs(delta))),
        },
        "signed_segment_projection": "not_performed; fcoil_circ join, segment polarity, turns/xmult use remain typed_absent",
        "calibration_or_inverse_claim": False,
    }


def mast_ayc_source_snapshot() -> dict[str, Any]:
    """Summarize acquired Level-1 arrays while preserving unknown semantics."""
    acquisition_path = AYC_INPUT_DIR / "ayc_profile_array_acquisition.json"
    acquisition = json.loads(acquisition_path.read_text(encoding="utf-8"))
    if acquisition.get("shot") != 30421:
        raise RuntimeError("AYC source acquisition is not bound to shot 30421")
    arrays = {item["name"]: item for item in acquisition["arrays"]}
    requested = (
        "ne", "te", "ne_error", "te_error", "covariance_ne_te", "r", "time",
        "radial_index", "instrument_dr", "instrument_time",
    )
    summary: dict[str, Any] = {}
    for name in requested:
        item = arrays.get(name)
        if item is None:
            summary[name] = {"status": "typed_absent"}
            continue
        summary[name] = {
            "status": item.get("status"),
            "shape": item.get("metadata", {}).get("shape"),
            "attribute_shape": item.get("attributes", {}).get("shape"),
            "dimensions": item.get("attributes", {}).get("_ARRAY_DIMENSIONS"),
            "units": item.get("attributes", {}).get("units"),
            "finite_count": item.get("finite_count"),
            "total_count": item.get("total_count"),
            "raw_sha256": item.get("raw_sha256"),
        }
    return {
        "shot_id": 30421,
        "acquisition_path": acquisition_path.relative_to(REPO_ROOT).as_posix(),
        "arrays": summary,
        "reported_error_statistical_semantics": "typed_absent; do not interpret as standard deviation or inverse-variance weights",
        "calibration_identity_and_coefficients": "typed_absent",
        "polychromator_fibre_to_131_slot_map": "typed_absent; polyname has 130 labels while profile arrays store 131 radial_index slots",
        "profile_shape_conflict": "metadata .zarray is 284x131 while descriptive shape attribute is 145x130; no trimming, padding, or shift is authorized",
        "level2_registration": "typed_absent; Level-1 cells are not joined to Level-2 by index, shape, time, or radius",
        "likelihood_ready": False,
    }


def compact_level2_observation(item: Any) -> dict[str, Any]:
    entry = item.manifest_entry()
    raw = entry["raw"]
    canonical = entry["canonical"]
    return {
        "record_id": item.record_id,
        "shot_id": item.shot_id,
        "channel": item.channel,
        "split": item.split,
        "quantity": item.quantity,
        "raw": {
            "dimensions": raw["dimensions"],
            "shape": raw["shape"],
            "unit": raw["unit"],
            "response_sha256": raw["response_sha256"],
            "schema_sha256": raw["schema_sha256"],
            "catalog_sha256": entry["catalog"]["sha256"],
        },
        "canonical": {
            "dimensions": canonical["dimensions"],
            "shape": canonical["shape"],
            "unit": canonical["unit"],
            "payload_sha256": canonical["payload_sha256"],
            "sample_lineage_sha256": canonical["sample_lineage_sha256"],
            "observed_count": canonical["observed_count"],
            "missing_count": canonical["missing_count"],
        },
        "catalog_comparison": entry["catalog"]["comparison"],
        "uncertainty": entry["uncertainty"],
    }


def gate_probe(label: str, action: Callable[[], Any]) -> dict[str, Any]:
    try:
        action()
    except reference.AdapterError as exc:
        return {
            "gate": label,
            "result": "blocked_as_expected",
            "error": str(exc),
        }
    raise RuntimeError(f"{label}: likelihood gate unexpectedly returned ready")


def task_progress_snapshot() -> dict[str, Any]:
    path = REPO_ROOT / "docs/v4_multitopology_generation/task_manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    task = next(
        item for item in manifest["tasks"]
        if item.get("id") == "UP4-03-REFERENCE-VALIDATION-PREC"
    )
    progress = task.get("execution_progress")
    if not isinstance(progress, dict):
        progress = None
    current_state = manifest.get("current_state")
    if not isinstance(current_state, dict):
        current_state = {}
    return {
        "task_status": task["status"],
        "scope_status": task.get("scope_status"),
        "acceptance_scope": task.get("scope_status"),
        "accepted": task["accepted"],
        "current_state_up4": current_state.get("up4", "typed_absent"),
        "execution_progress_status": (
            "present_in_manifest" if progress is not None
            else "typed_absent_not_reported_in_current_manifest"
        ),
        "formal_inverse": progress.get("formal_inverse") if progress is not None else None,
        "B03": progress.get("B03") if progress is not None else None,
        "B07B": progress.get("B07B") if progress is not None else None,
        "reference_inversion_G1_G2_G3": (
            progress.get("reference_inversion_G1_G2_G3")
            if progress is not None else None
        ),
        "expansion_new_acquisition": (
            progress.get("new_acquisition") if progress is not None else None
        ),
        "thomson_r2": progress.get("thomson_r2") if progress is not None else None,
        "pf_primary_review": (
            progress.get("pf_primary_review") if progress is not None else None
        ),
    }


def execute_consumer() -> dict[str, Any]:
    task_progress = task_progress_snapshot()
    efm_source = mast_efm_source_snapshot()
    ayc_source = mast_ayc_source_snapshot()
    official_partial_source = official_partial.build_partial_source_record(
        REPO_ROOT, shot_id=30421
    )
    level2_package = reference.load_reference_package()
    level2_integrity = reference.validate_reference_package_integrity(level2_package)
    level2_split = reference.validate_no_leakage(level2_package)

    level1_package = level1.load_level1_error_package()
    level1_integrity = level1.validate_level1_package_integrity(level1_package)
    level1_split = level1.validate_level1_no_leakage(
        level1_package.observations, level1_package.protocol
    )

    source = thomson.load_thomson_source_response_source_v1()
    diagnostic = thomson.diagnose_thomson_source_response_v1(
        level1_package, source, candidate_prediction=None
    )
    diagnostic_check = thomson.validate_thomson_source_response_diagnostic_v1(
        diagnostic
    )

    l2_observations = sorted(
        (compact_level2_observation(item) for item in level2_package.observations),
        key=lambda item: (item["shot_id"], item["channel"]),
    )
    l1_observations = sorted(
        (item.manifest_entry() for item in level1_package.observations),
        key=lambda item: item["shot_id"],
    )
    source_manifest = source.manifest_entry()
    diagnostic_manifest = diagnostic.manifest_entry()
    response_summary = {
        "entrypoint": "diagnose_thomson_source_response_v1",
        "module": "benchmarks/reference_validation_v1/thomson_source_response_v1.py",
        "invoked": True,
        "candidate_prediction_supplied": diagnostic.candidate_prediction is not None,
        "validated_result": diagnostic_check,
        "diagnostic_sha256": diagnostic.diagnostic_sha256,
        "spectral_conditional_fit": diagnostic_manifest["spectral"]["conditional_fit"],
        "pressure": diagnostic_manifest["pressure"],
        "registration_gaps": diagnostic_manifest["registration_gaps"],
        "calibrated_response": diagnostic.calibrated_response,
        "likelihood_ready": diagnostic.likelihood_ready,
        "covariance_weights_authorized": diagnostic.covariance_weights_authorized,
        "selection_authorized": diagnostic.selection_authorized,
        "claim_ceiling": diagnostic.claim_ceiling,
    }

    likelihood_gates = [
        gate_probe("level2_reference_package", level2_package.require_likelihood_ready),
        gate_probe("level1_error_package", level1_package.require_likelihood_ready),
        gate_probe("thomson_source_response_diagnostic", diagnostic.require_likelihood_ready),
        gate_probe(
            "thomson_consumer_request_likelihood",
            lambda: thomson.diagnose_thomson_source_response_v1(
                level1_package, source, request_likelihood=True
            ),
        ),
    ]

    raw_identities: dict[str, Any] = {
        "level2": [
            {
                "shot_id": item["shot_id"],
                "channel": item["channel"],
                "response_sha256": item["raw"]["response_sha256"],
                "schema_sha256": item["raw"]["schema_sha256"],
                "catalog_sha256": item["raw"]["catalog_sha256"],
                "canonical_payload_sha256": item["canonical"]["payload_sha256"],
            }
            for item in l2_observations
        ],
        "level1": [
            {
                "shot_id": item["shot_id"],
                "acquisition_sha256": item["acquisition_sha256"],
                "zmetadata_sha256": item["zmetadata_sha256"],
                "array_sha256": item["raw"]["array_sha256"],
            }
            for item in l1_observations
        ],
        "thomson_source_response": {
            "acquisition_sha256": source_manifest["acquisition"]["sha256"],
            "selection_sha256": source_manifest["selection"]["sha256"],
            "zmetadata_sha256": source_manifest["zmetadata"]["sha256"],
            "source_bundle_sha256": source_manifest["source_bundle_sha256"],
            "arrays": source_manifest["arrays"],
        },
        "official_partial_source": {
            "shot_id": official_partial_source["shot_id"],
            "source_record_sha256": official_partial_source["source_record_sha256"],
        },
    }

    return {
        "schema_version": "up4_03_actual_reference_consumer_slice_r2",
        "classification": "bounded_actual_source_consumer_only",
        "task_progress_snapshot": task_progress,
        "loaded_packages": {
            "level2": {
                "adapter": "reference_validation_v1.reference_adapter.load_reference_package",
                "integrity": level2_integrity,
                "split_receipt": reference._plain(dict(level2_package.split_receipt)),
                "observation_count": len(l2_observations),
                "observations": l2_observations,
                "claim_ceiling": level2_package.claim_ceiling,
            },
            "level1": {
                "adapter": "reference_validation_v1.level1_error_adapter.load_level1_error_package",
                "integrity": level1_integrity,
                "split_receipt": level1_split,
                "observations": l1_observations,
                "claim_ceiling": level1_package.claim_ceiling,
            },
            "thomson_source_response": {
                "shot_id": source.shot_id,
                "source_bundle_sha256": source.source_bundle_sha256,
                "array_count": len(source.arrays),
                "raw_values_only": source.raw_values_only,
                "likelihood_ready": source.likelihood_ready,
                "scientific_acceptance": source.scientific_acceptance,
                "source_manifest": source_manifest,
            },
        },
        "actual_consumer": response_summary,
        "actual_source_boundaries": {
            "mast_efm": efm_source,
            "mast_ayc": ayc_source,
            "official_partial_join": official_partial_source,
            "interpretation": "acquired first-party values are reported as source observations only; absent joins, calibration, and measurement semantics remain typed_absent",
        },
        "likelihood_gate_probes": likelihood_gates,
        "formal_inverse_boundary": {
            "candidate_forward_called": False,
            "optimizer_called": False,
            "G1_G2_G3_exported": False,
            "identifiability_report": "not_executed",
            "blind_heldout_prediction": "not_executed",
            "likelihood_ready": False,
            "formal_inverse": "not_executed",
            "B03": False,
            "B07B": False,
            "R02": False,
            "R06": False,
            "heldout_classification": "30420 was loaded and consumed during prior development; it is not blind validation",
            "current_expansion_heldout": "four values remain unreleased/unread per frozen current task record",
        },
        "theta_inverse_connection_contract": {
            "status": "not_implemented_in_current_chain",
            "available_chain": "source diagnostics and package validation only; no fitted theta, candidate forward, optimizer, Genome export, or held-out prediction",
            "unidentified_parameter_scopes": {
                "G1": "mechanism and constitutive parameters have no source-backed observation mapping, prior/bounds, or likelihood",
                "G2": "field/boundary/geometry parameters lack an accepted signed PF map and a source-backed diagnostic operator; EFM fcoil_c is a reconstructed output, not a hidden truth supplied to an inverse",
                "G3": "actuator/control parameters lack a source-backed current-sign/winding map, channel calibration, and common-forward controls mapping",
            },
            "minimum_wiring": [
                "freeze shot/pass/version, source identities, units, missing masks, and candidate-independent calibration/validation/held-out IDs",
                "define each theta field with G1/G2/G3 ownership, applicability, bounds or prior, and an identifiability target",
                "provide an authoritative PF 101-to-938 signed mapping and a shot-applicable Thomson channel/calibration/error model; keep all unresolved fields typed_absent",
                "implement a diagnostic operator H over the same existing producer chain used for candidate forward, with likelihood enabled only from source-defined errors",
                "optimize from multiple declared starts, record failed attempts and Jacobian rank/condition/equivalence classes, then freeze theta and predict untouched held-out data through that same forward chain",
                "replay the frozen mapping and held-out prediction in an independent process before assigning any B03/B07B/R02/R06 scope",
            ],
            "current_result": "source diagnostics have not inverted G1/G2/G3 theta; 30420 was consumed during prior development and is not blind validation, and the four expansion held-out arrays remain unreleased/unread",
        },
        "pf_geometry_semantic_review": {
            "source_findings_path": "runs/e/up4_mast_efm_inputs_20261001_r6/findings.md",
            "source_findings_available": True,
            "production_G3": False,
            "measurement_current_sign": "unknown",
            "P6_reversal": "unknown",
            "EFM_segment_formula_and_circ_index": "inferred_not_source_confirmed",
        },
        "input_identities": raw_identities,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    output = args.output.resolve()
    if output.exists():
        raise FileExistsError(f"refusing to overwrite existing output: {output}")
    output.mkdir(parents=True)

    started = time.monotonic()
    started_utc = utc_now()
    before = static_file_hashes()
    state_before = workspace_state()
    write_json(output / "static_inputs_before.json", before)
    try:
        result = execute_consumer()
        result_sha = write_json(output / "consumer_result.json", result)
        after = static_file_hashes()
        state_after = workspace_state()
        write_json(output / "static_inputs_after.json", after)
        execution = {
            "schema_version": "up4_03_actual_reference_consumer_execution_r2",
            "command": [sys.executable, "-B", str(Path(__file__).resolve()), "--output", str(output)],
            "runner_repo_path": RUNNER_REPO_PATH,
            "pid": os.getpid(),
            "cwd": str(REPO_ROOT),
            "started_utc": started_utc,
            "completed_utc": utc_now(),
            "wall_seconds": round(time.monotonic() - started, 6),
            "python_version": platform.python_version(),
            "workspace_before": state_before,
            "workspace_after": state_after,
            "workspace_context_unchanged": state_before == state_after,
            "static_inputs_unchanged": before == after,
            "static_input_hashes_before": before,
            "static_input_hashes_after": after,
            "consumer_result_sha256": result_sha,
            "exit_code": 0 if before == after else 2,
        }
        execution_sha = write_json(output / "execution.json", execution)
        artifacts = []
        for path in sorted(item for item in output.iterdir() if item.is_file()):
            artifacts.append({
                "path": path.name,
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
            })
        write_json(output / "artifact_manifest.json", {
            "schema_version": "up4_03_actual_reference_consumer_artifacts_r2",
            "files": artifacts,
            "execution_sha256": execution_sha,
        })
        print(json.dumps({
            "status": "pass_bounded_actual_consumer",
            "exit_code": execution["exit_code"],
            "wall_seconds": execution["wall_seconds"],
            "consumer_result_sha256": result_sha,
            "actual_consumer": result["actual_consumer"],
            "formal_inverse_boundary": result["formal_inverse_boundary"],
        }, ensure_ascii=False, sort_keys=True, indent=2))
        return int(execution["exit_code"])
    except BaseException as exc:
        error = {
            "schema_version": "up4_03_actual_reference_consumer_failure_r2",
            "started_utc": started_utc,
            "completed_utc": utc_now(),
            "wall_seconds": round(time.monotonic() - started, 6),
            "exception_type": type(exc).__name__,
            "exception": str(exc),
            "traceback": traceback.format_exc(),
            "workspace_at_failure": state_before,
        }
        write_json(output / "failure.json", error)
        print(json.dumps(error, ensure_ascii=False, sort_keys=True, indent=2), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
