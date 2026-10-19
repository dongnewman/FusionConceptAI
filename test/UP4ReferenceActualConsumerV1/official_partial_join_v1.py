"""Source-grounded, metadata-only partial join for MAST shot 30421.

This adapter parses a pinned UKAEA FAIR-MAST ingestion mapping and its already
captured shot-30421 Level-2 metadata. It reports declared mappings and gaps; it
does not read numerical current/profile chunks, apply scale factors, map EFM
segments, or authorize a likelihood/inverse.
"""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any

import yaml

SOURCE_COMMIT = "ed6ea4e2a81f2317ae474f7c5421071994220948"
MAPPING_URL = (
    "https://github.com/ukaea/fair-mast-ingestion/blob/"
    + SOURCE_COMMIT + "/mappings/level2/mast.yml"
)
SHOT_DATA_URL = "https://s3.echo.stfc.ac.uk/mast/level2/shots/30421.zarr"
MAPPING_SNAPSHOT = Path(
    "runs/e/up4_firstparty_source_search_r4/mappings__level2__mast.yml"
)
SELECTED_METADATA = Path(
    "runs/e/up4_firstparty_source_search_r4/pf_thomson_selected_metadata.json"
)
ZARR_METADATA = Path(
    "runs/e/up4_firstparty_source_search_r4/shot30421_level2_zarr.json.json"
)
MAPPING_RECEIPT = Path(
    "runs/e/up4_firstparty_source_search_r4/ingestion_sources_receipt.json"
)
ZARR_RECEIPT = Path(
    "runs/e/up4_firstparty_source_search_r4/shot30421_level2_group_lookup_receipt.json"
)


def _require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def _read_text(root: Path, relative: Path) -> str:
    path = (root / relative).resolve()
    path.relative_to(root.resolve())
    if not path.is_file():
        raise FileNotFoundError(relative.as_posix())
    return path.read_text(encoding="utf-8")


def _read_json(root: Path, relative: Path) -> Any:
    return json.loads(_read_text(root, relative))


def _mapping_document(text: str) -> dict[str, Any]:
    document = yaml.safe_load(text)
    _require(isinstance(document, dict), "pinned mapping root must be a YAML object")
    datasets = document.get("datasets")
    _require(isinstance(datasets, dict), "pinned mapping datasets must be a YAML object")
    return datasets


def _json_metadata_map(rows: Any) -> dict[str, dict[str, Any]]:
    _require(isinstance(rows, list), "selected Level-2 metadata must be a list")
    output: dict[str, dict[str, Any]] = {}
    for row in rows:
        if isinstance(row, dict) and isinstance(row.get("path"), str):
            output[row["path"]] = row
    return output


def _shot_source(source_rows: Any, expected_name: str, shot_id: int) -> dict[str, Any]:
    _require(isinstance(source_rows, list), f"{expected_name} source declarations must be a list")
    matches = [row for row in source_rows
               if isinstance(row, dict) and row.get("name") == expected_name]
    _require(len(matches) == 1, f"expected one {expected_name} shot-range source")
    shot_range = matches[0].get("shot_range")
    _require(isinstance(shot_range, dict), f"{expected_name} source shot range missing")
    lower = shot_range.get("shot_min")
    upper = shot_range.get("shot_max")
    _require(isinstance(lower, int) and isinstance(upper, int),
             f"{expected_name} source shot range must contain integer bounds")
    return {
        "source_name": expected_name,
        "shot_range": [lower, upper],
        "applies_to_shot": lower <= shot_id <= upper,
    }


def _channel_rows(channels: Any, source_unit_comment: str,
                  turn_scale_comment: str) -> list[dict[str, Any]]:
    _require(isinstance(channels, list), "AMC channel declarations must be a list")
    rows: list[dict[str, Any]] = []
    for channel_spec in channels:
        if isinstance(channel_spec, str):
            channel, factor = channel_spec, None
        elif isinstance(channel_spec, dict) and len(channel_spec) == 1:
            channel, properties = next(iter(channel_spec.items()))
            _require(isinstance(channel, str) and isinstance(properties, dict),
                     "scaled AMC channel must map to a property object")
            factor = properties.get("scale")
            _require(isinstance(factor, int) and factor > 0,
                     f"scaled AMC channel has invalid declared scale: {channel}")
        else:
            raise ValueError(f"unsupported AMC channel declaration: {channel_spec!r}")
        _require(channel.startswith("AMC_"), f"unexpected non-AMC channel: {channel}")
        token = channel.removeprefix("AMC_").removesuffix(" FEED CURRENT").removesuffix(" CURRENT")
        group = None
        match = re.fullmatch(r"P([2-6])(I|O)?([UL])", token)
        if match:
            coil_number, inner_outer, upper_lower = match.groups()
            group = f"p{coil_number}_"
            if inner_outer:
                group += ("inner_" if inner_outer == "I" else "outer_")
            group += ("upper" if upper_lower == "U" else "lower")
        elif token == "SOL":
            group = "sol"
        rows.append({
            "source_channel": channel,
            "channel_label_group_candidate": group,
            "channel_label_group_join_status": "label_derived_candidate_only" if group else "typed_absent",
            "mapping_declared_scale": factor,
            "scale_unit_semantics": turn_scale_comment if factor is not None else "typed_absent_no_scale_declared",
            "source_unit_text": source_unit_comment if factor is not None else "typed_absent_in_mapping",
            "source_unit_comment_attached_to_channel": "AMC_P2IL FEED CURRENT",
            "comment_scope_for_this_channel": (
                "explicit_inline_comment_on_this_channel" if channel == "AMC_P2IL FEED CURRENT"
                else "applicability_not_declared_for_this_channel"
            ),
            "target_unit": "A",
            "mapping_scale_applied": False,
            "unit_conflict": (
                (
                    f"{source_unit_comment} × declared turn scale does not produce target A without a stated conversion; mapping gives no explicit factor 1000"
                    if channel == "AMC_P2IL FEED CURRENT" else
                    "a scale is declared, but the inline source-unit comment is attached to P2IL and its applicability here is not declared; conversion is unresolved"
                ) if factor is not None else "raw source unit is unspecified in mapping"
            ),
            "signed_winding_polarity": "typed_absent",
            "coil_geometry_orientation_join": "typed_absent",
            "efm_segment_join": "typed_absent_never_joined",
        })
    _require(len(rows) == 13, f"expected 13 declared AMC coil-current channels, found {len(rows)}")
    return rows


def _profile_mapping(thomson_section: dict[str, Any],
                     metadata: dict[str, dict[str, Any]], shot_id: int) -> dict[str, Any]:
    profiles = thomson_section.get("profiles")
    _require(isinstance(profiles, dict), "Thomson profile declarations must be a YAML object")
    te_block, ne_block = profiles.get("t_e"), profiles.get("n_e")
    _require(isinstance(te_block, dict) and isinstance(ne_block, dict),
             "Thomson t_e/n_e declarations must be YAML objects")
    te_src = _shot_source(te_block.get("source"), "AYC_TE", shot_id)
    ne_src = _shot_source(ne_block.get("source"), "AYC_NE", shot_id)
    te_dimensions = te_block.get("dimensions", {})
    radius_dimension = te_dimensions.get("major_radius", {}) if isinstance(te_dimensions, dict) else {}
    _require(isinstance(radius_dimension, dict), "AYC_R radius dimension must be a YAML object")
    r_src = _shot_source(radius_dimension.get("source"), "AYC_R", shot_id)
    r_range = r_src["shot_range"]

    interpolation = thomson_section.get("interpolate", {})
    radius_interpolation = interpolation.get("major_radius", {}) if isinstance(interpolation, dict) else {}
    _require(isinstance(radius_interpolation, dict), "major-radius interpolation declaration is missing")
    for key in ("start", "end", "step", "fill", "method"):
        _require(key in radius_interpolation, f"major-radius interpolation field missing: {key}")

    def field(path: str) -> dict[str, Any]:
        row = metadata.get(path)
        _require(row is not None, f"shot-30421 Level-2 metadata is missing {path}")
        return {
            "path": path,
            "shape": row.get("shape"),
            "dimensions": row.get("dimensions"),
            "units": row.get("attributes", {}).get("units"),
            "imas": row.get("attributes", {}).get("imas"),
            "uda_name": row.get("attributes", {}).get("uda_name"),
        }

    ne_meta = field("thomson_scattering/n_e")
    te_meta = field("thomson_scattering/t_e")
    r_meta = field("thomson_scattering/major_radius")
    time_meta = field("thomson_scattering/time")
    _require(ne_meta["shape"] == te_meta["shape"] == [120, 283], "shot profile shapes differ from captured 120x283")
    _require(r_meta["shape"] == [120] and time_meta["shape"] == [283], "shot radius/time shape mismatch")
    _require(ne_meta["units"] == "1 / m ** 3" and te_meta["units"] == "eV", "shot profile units differ from captured metadata")
    _require(r_meta["units"] == "m" and time_meta["units"] == "s", "shot radius/time units differ from captured metadata")
    _require(all(src["applies_to_shot"] for src in (te_src, ne_src, r_src)),
             "AYC source mapping does not cover requested shot")
    return {
        "status": "partial_source_metadata_join",
        "shot_id": shot_id,
        "target_product": "FAIR-MAST Level-2 thomson_scattering",
        "sources": {"n_e": ne_src, "t_e": te_src, "major_radius": r_src},
        "mapping_path": "mappings/level2/mast.yml#/thomson_scattering/profiles",
        "fields": {"n_e": ne_meta, "t_e": te_meta, "radius": r_meta, "time": time_meta},
        "declared_time_axes": {"n_e": "thomson_scattering.channel[:].n_e.time", "t_e": "thomson_scattering.channel[:].t_e.time", "raw_time_channel_source": "typed_absent_not_explicit_in_profile_mapping"},
        "declared_radius_interpolation": {
            "start_m": float(radius_interpolation["start"]),
            "end_m": float(radius_interpolation["end"]),
            "step_m": float(radius_interpolation["step"]),
            "fill": radius_interpolation["fill"],
            "method": radius_interpolation["method"],
        },
        "raw_level1_radial_slot_to_fibre_polychromator_map": "typed_absent",
        "shot_applicable_calibration_identity_coefficients": "typed_absent",
        "observation_operator_H": "typed_absent",
        "ne_te_error_formula_units_statistical_meaning": "typed_absent",
        "ne_te_covariance_formula_units_statistical_meaning": "typed_absent",
        "likelihood_ready": False,
        "inverse_ready": False,
        "credit": "source_metadata_join_only",
    }


def build_partial_source_record(repo_root: str | Path, shot_id: int = 30421) -> dict[str, Any]:
    """Parse actual captured 30421 mapping/metadata into a partial source record."""
    _require(shot_id == 30421, "this bounded adapter is pinned only to shot 30421")
    root = Path(repo_root).resolve()
    mapping_text = _read_text(root, MAPPING_SNAPSHOT)
    mapping_receipt = _read_json(root, MAPPING_RECEIPT)
    _require(isinstance(mapping_receipt, list), "mapping source receipt must be a list")
    map_receipt = next((item for item in mapping_receipt if item.get("path") == "mappings/level2/mast.yml"), None)
    _require(map_receipt is not None, "pinned UKAEA mapping receipt missing")
    _require(map_receipt.get("commit") == SOURCE_COMMIT, "mapping receipt commit differs from pinned source")
    _require(str(map_receipt.get("sha256", "")).lower() == hashlib.sha256(mapping_text.encode("utf-8")).hexdigest().lower(),
             "local mapping snapshot differs from its existing receipt")
    datasets = _mapping_document(mapping_text)
    rows = _json_metadata_map(_read_json(root, SELECTED_METADATA))
    zarr_receipts = _read_json(root, ZARR_RECEIPT)
    _require(isinstance(zarr_receipts, list), "shot metadata receipt must be a list")
    receipt = next((item for item in zarr_receipts if item.get("url", "").endswith("/zarr.json") and item.get("status") == 200), None)
    _require(receipt is not None, "successful shot-30421 Zarr metadata receipt missing")
    _require(receipt.get("url") == SHOT_DATA_URL + "/zarr.json", "Zarr metadata URL is not the pinned shot input")
    _require(str(receipt.get("sha256", "")).lower() == hashlib.sha256((root / ZARR_METADATA).read_bytes()).hexdigest().lower(), "shot metadata differs from existing acquisition receipt")

    pf_section = datasets.get("pf_active")
    _require(isinstance(pf_section, dict), "pf_active mapping section is missing")
    pf_profiles = pf_section.get("profiles")
    _require(isinstance(pf_profiles, dict), "pf_active profiles mapping is missing")
    current_block = pf_profiles.get("coil_current")
    _require(isinstance(current_block, dict), "pf_active coil_current mapping is missing")
    target_unit = current_block.get("target_units")
    _require(target_unit == "A", "PF target-unit declaration missing or changed")
    declared_sources = current_block.get("source")
    _require(isinstance(declared_sources, list), "PF current source declarations are missing")
    amc_sources = [item for item in declared_sources
                   if isinstance(item, dict) and item.get("name") == "AMC"]
    _require(len(amc_sources) == 1, "expected one AMC channel source declaration")
    channels = amc_sources[0].get("channels")
    comment_lines = [line for line in mapping_text.splitlines()
                     if "AMC_P2IL FEED CURRENT" in line and "#" in line]
    _require(len(comment_lines) == 1, "expected one inline source-unit/scale comment on P2IL")
    comment = comment_lines[0].split("#", 1)[1].strip()
    source_unit_match = re.search(r"Feed current is ([^.]+)\.", comment)
    turn_scale_match = re.search(r"(Each channel needs to be scaled by .*? in A\.)", comment)
    _require(source_unit_match is not None and turn_scale_match is not None,
             "declared PF source-unit/turn-scale comment changed or is missing")
    current_meta = rows.get("pf_active/coil_current")
    channel_meta = rows.get("pf_active/current_channel")
    _require(current_meta is not None and channel_meta is not None, "shot PF current metadata missing")
    _require(current_meta.get("shape") == [13, 15305] and current_meta.get("attributes", {}).get("units") == "A", "shot PF current metadata no longer matches captured 13x15305 A record")
    _require(channel_meta.get("shape") == [13], "shot PF current_channel metadata shape mismatch")
    pf_rows = _channel_rows(channels, source_unit_match.group(1).strip(),
                            turn_scale_match.group(1).strip())
    geometry_group_candidates = sorted({row["channel_label_group_candidate"] for row in pf_rows if row["channel_label_group_candidate"]})
    geometry_groups_present = sorted({
        path.removeprefix("pf_active/").removesuffix("_r")
        for path in rows if path.startswith("pf_active/") and path.endswith("_r")
    })
    for row in pf_rows:
        group = row["channel_label_group_candidate"]
        row["named_geometry_group_metadata_present"] = group in geometry_groups_present if group else False
        row["geometry_group_metadata_join_status"] = "name_only_candidate" if group in geometry_groups_present else "typed_absent"

    ts_section = datasets.get("thomson_scattering")
    _require(isinstance(ts_section, dict), "thomson_scattering mapping section is missing")
    profile_record = _profile_mapping(ts_section, rows, shot_id)
    record = {
        "schema": "up4_official_partial_source_join_v1",
        "classification": "metadata_only_partial_join_no_inverse_credit",
        "shot_id": shot_id,
        "mapping_source": {
            "url": MAPPING_URL,
            "repository": "ukaea/fair-mast-ingestion",
            "commit": SOURCE_COMMIT,
            "local_captured_path": MAPPING_SNAPSHOT.as_posix(),
            "existing_mapping_receipt_path": MAPPING_RECEIPT.as_posix(),
            "mapping_receipt_commit": map_receipt["commit"],
            "mapping_receipt_git_blob_sha": map_receipt.get("git_blob_sha"),
            "license_context": "official FAIR-MAST ingestion source snapshot",
        },
        "shot_metadata_source": {
            "url": SHOT_DATA_URL + "/zarr.json",
            "receipt_path": ZARR_RECEIPT.as_posix(),
            "local_capture_path": ZARR_METADATA.as_posix(),
            "sha256_from_existing_receipt": receipt["sha256"],
            "metadata_only": True,
            "numerical_current_or_profile_chunks_read": False,
        },
        "pf_current": {
            "status": "partial_source_metadata_join",
            "mapping_path": "mappings/level2/mast.yml#/pf_active/profiles/coil_current",
            "target_imas_path": "pf_active.coil[:].current.data",
            "target_unit_declared_in_mapping": target_unit,
            "actual_shot_metadata": {
                "path": "pf_active/coil_current", "shape": current_meta.get("shape"),
                "dimensions": current_meta.get("dimensions"), "units": current_meta.get("attributes", {}).get("units"),
                "coordinate_dimension_metadata": channel_meta.get("dimensions"),
            },
            "named_geometry_groups_in_shot_metadata": geometry_groups_present,
            "channel_rows": pf_rows,
            "signed_coil_current": "typed_absent",
            "positive_winding_direction_relative_to_geometry": "typed_absent",
            "coil_current_values_consumed": False,
            "efm_fcoil_circ_to_101_coils_or_938_segments": "typed_absent_never_joined",
            "likelihood_ready": False,
            "inverse_ready": False,
            "credit": "source_metadata_join_only",
        },
        "thomson_profile": profile_record,
        "readiness": {
            "source_record": "present_partial",
            "pf_named_channel_turn_scales": "present_partial_unit_sign_and_geometry_orientation_unresolved",
            "thomson_level2_radius_time_product": "present_partial_calibration_and_uncertainty_unresolved",
            "likelihood": False,
            "formal_inverse": False,
            "same_chain_physical_credit": False,
        },
    }
    canonical = json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    record["source_record_sha256"] = hashlib.sha256(canonical).hexdigest()
    return record
