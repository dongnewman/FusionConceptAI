"""Acquire and verify the bounded MAST shot-30421 PF geometry/current source set.

The input is a pinned Zarr-v3 consolidated metadata document.  The selection is
explicit and excludes PF voltages.  Compressed source chunks, decompressed
chunk bytes, and ordered assembled values are all retained and hashed.  This
tool preserves the source's development/dirty provenance and does not infer
coil turns, current signs, EFM segment mappings, uncertainty, or physical
readiness.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import itertools
import json
import math
import os
from pathlib import Path, PurePosixPath
import sys
import traceback
from typing import Any, Iterable

import numpy as np
import psutil
import requests
from requests.adapters import HTTPAdapter
import urllib3
from urllib3.util.retry import Retry
import zstandard
import zstandard.backend_c


ROOT = Path(__file__).resolve().parents[1]
METADATA_PATH = ROOT / "benchmarks/reference_data_v2/raw/shot30421/level2/shots/30421.zarr/zarr.json"
METADATA_SHA256 = "f11cb13cba43cf6e49f3fcd085fd2806c7217e8f480c8761fad89b2b8ee0d39a"
OWNERSHIP_PATH = ROOT / "docs/implementation/GOAL-EXECUTION-20260922/ownership_delta14_pf_geometry_source.json"
SOURCE_BASE = "https://s3.echo.stfc.ac.uk/mast/level2/shots/30421.zarr"
SHOT_ID = 30421
MAX_ARRAY_BYTES = 8_000_000
MAX_CHUNK_BYTES = 8_000_000
MAX_TOTAL_DECODED_BYTES = 24_000_000
MAX_PROCESS_RSS_BYTES = 536_870_912
REQUEST_TIMEOUT = (10, 30)

ACTIVE_STEMS = (
    "p2_inner_lower", "p2_inner_upper", "p2_outer_lower", "p2_outer_upper",
    "p3_lower", "p3_upper", "p4_lower", "p4_upper", "p5_lower", "p5_upper",
    "p6_lower", "p6_upper", "sol",
)
PASSIVE_STEMS = (
    "botcol", "coil_cases", "endcrown_l", "endcrown_u", "incon", "lhorw",
    "mid", "p2larm", "p2ldivpl", "p2uarm", "p2udivpl", "ring", "rodgr",
    "topcol", "uhorw", "vertw",
)
PASSIVE_CURRENT_STEMS = tuple(stem for stem in PASSIVE_STEMS if stem != "coil_cases")
PASSIVE_CHANNEL_STEMS = tuple(
    stem for stem in PASSIVE_CURRENT_STEMS if stem not in ("endcrown_l", "endcrown_u")
)


def _explicit_paths() -> tuple[str, ...]:
    active = ["pf_active/coil_current", "pf_active/current_channel", "pf_active/shot_id", "pf_active/time"]
    for stem in ACTIVE_STEMS:
        active.extend(f"pf_active/{stem}_{suffix}" for suffix in ("coordinate_element", "height", "r", "width", "z"))
    passive = ["pf_passive/shot_id", "pf_passive/time"]
    for stem in PASSIVE_STEMS:
        passive.extend(f"pf_passive/{stem}_{suffix}" for suffix in ("geometry_channel", "height", "r", "width", "z"))
        if stem != "coil_cases":
            passive.extend((f"pf_passive/{stem}_shapeAngle1", f"pf_passive/{stem}_shapeAngle2"))
    passive.extend(f"pf_passive/{stem}_current" for stem in PASSIVE_CURRENT_STEMS)
    passive.extend(f"pf_passive/{stem}_current_channel" for stem in PASSIVE_CHANNEL_STEMS)
    result = tuple(active + passive)
    if len(result) != 209 or len(set(result)) != 209:
        raise RuntimeError("internal_selection_cardinality_error")
    return result


SELECTED_ARRAYS = _explicit_paths()
EXPECTED_EXCLUDED_ARRAYS = ("pf_active/coil_voltage", "pf_active/voltage_channel")
SCIENCE_LOCKS = {
    "raw_values_only": True,
    "efm_circ_mapping_verified": False,
    "efm_segment_value_mapping_verified": False,
    "turns_semantics_verified": False,
    "current_sign_semantics_verified": False,
    "current_per_turn_semantics_verified": False,
    "source_independence_verified": False,
    "uncertainty_status": "typed_absent_not_acquired",
    "likelihood_ready": False,
    "free_boundary_ready": False,
    "reference_inversion_G1_G2_G3": False,
    "engineering_validation": False,
    "physical_validation": False,
    "scientific_acceptance": False,
    "terminal_authority": False,
    "parent_UP4_03_complete": False,
}


class PFError(RuntimeError):
    def __init__(self, code: str, detail: str):
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def require(condition: bool, code: str, detail: str) -> None:
    if not condition:
        raise PFError(code, detail)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def pretty_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")


def payload_hash(value: dict[str, Any], field: str) -> str:
    payload = {key: item for key, item in value.items() if key != field}
    return sha256_bytes(canonical_bytes(payload))


def seal(value: dict[str, Any], field: str) -> dict[str, Any]:
    value[field] = payload_hash(value, field)
    return value


def write_json(path: Path, value: Any) -> None:
    path.write_bytes(pretty_bytes(value))


def write_sealed(path: Path, value: dict[str, Any], field: str) -> None:
    seal(value, field)
    write_json(path, value)


def validate_seal(value: dict[str, Any], field: str, code: str) -> None:
    require(isinstance(value.get(field), str), code, f"missing {field}")
    require(value[field] == payload_hash(value, field), code, f"stale {field}")


def identity(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {"path": str(path.resolve()), "bytes": len(raw), "sha256": sha256_bytes(raw)}


def check_rss() -> int:
    size = psutil.Process().memory_info().rss
    require(size <= MAX_PROCESS_RSS_BYTES, "process_rss_limit", f"{size}>{MAX_PROCESS_RSS_BYTES}")
    return size


def safe_relative(root: Path, relative: str, *, code: str = "path_escape_error") -> Path:
    require(isinstance(relative, str) and relative != "", code, "empty path")
    pure = PurePosixPath(relative)
    require(not pure.is_absolute() and ".." not in pure.parts, code, relative)
    candidate = (root / Path(*pure.parts)).resolve()
    base = root.resolve()
    require(os.path.commonpath((str(base), str(candidate))) == str(base), code, relative)
    return candidate


def array_chunk_indices(shape: tuple[int, ...], chunks: tuple[int, ...]) -> Iterable[tuple[int, ...]]:
    if not shape:
        yield ()
        return
    counts = tuple(math.ceil(shape[axis] / chunks[axis]) for axis in range(len(shape)))
    yield from itertools.product(*(range(count) for count in counts))


def chunk_key(index: tuple[int, ...]) -> str:
    return "c" if not index else "c/" + "/".join(str(value) for value in index)


def edge_layout(shape: tuple[int, ...], chunks: tuple[int, ...], index: tuple[int, ...]):
    starts = tuple(index[axis] * chunks[axis] for axis in range(len(shape)))
    edge = tuple(min(chunks[axis], shape[axis] - starts[axis]) for axis in range(len(shape)))
    return starts, edge


def _numeric_dtype(data_type: str) -> np.dtype:
    mapping = {"float32": "<f4", "float64": "<f8", "int64": "<i8"}
    require(data_type in mapping, "zarr_dtype_error", data_type)
    return np.dtype(mapping[data_type])


def validate_node(path: str, node: dict[str, Any]) -> dict[str, Any]:
    require(node.get("node_type") == "array", "zarr_node_error", path)
    require(node.get("zarr_format") == 3, "zarr_format_error", path)
    require(node.get("storage_transformers") == [], "zarr_transformer_error", path)
    shape_raw = node.get("shape")
    chunks_raw = node.get("chunk_grid", {}).get("configuration", {}).get("chunk_shape")
    require(isinstance(shape_raw, list) and isinstance(chunks_raw, list), "zarr_shape_error", path)
    require(len(shape_raw) == len(chunks_raw), "zarr_shape_error", path)
    require(all(isinstance(x, int) and x > 0 for x in shape_raw), "zarr_shape_error", path)
    require(all(isinstance(x, int) and x > 0 for x in chunks_raw), "zarr_chunk_error", path)
    shape, chunks = tuple(shape_raw), tuple(chunks_raw)
    require(node.get("chunk_grid", {}).get("name") == "regular", "zarr_chunk_error", path)
    encoding = node.get("chunk_key_encoding", {})
    require(encoding.get("name") == "default" and encoding.get("configuration", {}).get("separator") == "/", "zarr_chunk_key_error", path)
    dims = node.get("dimension_names", [] if not shape else None)
    require(isinstance(dims, list) and len(dims) == len(shape), "zarr_dimension_error", path)
    require(all(isinstance(item, str) and item for item in dims), "zarr_dimension_error", path)
    data_type = node.get("data_type")
    codecs = node.get("codecs")
    require(isinstance(codecs, list) and len(codecs) == 2, "zarr_codec_error", path)
    if data_type == "string":
        require(codecs[0] == {"name": "vlen-utf8", "configuration": {}}, "zarr_string_codec_error", path)
        require(len(shape) == 1, "zarr_string_rank_error", path)
        decoded_bytes = None
    else:
        dtype = _numeric_dtype(str(data_type))
        require(codecs[0] == {"name": "bytes", "configuration": {"endian": "little"}}, "zarr_endian_error", path)
        decoded_bytes = math.prod(shape) * dtype.itemsize
        require(decoded_bytes <= MAX_ARRAY_BYTES, "array_size_limit", f"{path}:{decoded_bytes}")
    zstd = codecs[1]
    require(zstd.get("name") == "zstd", "zarr_codec_error", path)
    require(zstd.get("configuration") == {"level": 0, "checksum": False}, "zarr_zstd_config_error", path)
    full_chunk_elements = math.prod(chunks)
    if data_type != "string":
        require(full_chunk_elements * _numeric_dtype(str(data_type)).itemsize <= MAX_CHUNK_BYTES, "chunk_size_limit", path)
    return {
        "shape": list(shape), "chunks": list(chunks), "data_type": data_type,
        "dimensions": list(dims), "units": node.get("attributes", {}).get("units"),
        "decoded_bytes": decoded_bytes,
    }


def _metadata_document(metadata_path: Path) -> tuple[bytes, dict[str, Any], dict[str, Any]]:
    raw = metadata_path.read_bytes()
    require(sha256_bytes(raw) == METADATA_SHA256, "metadata_hash_error", str(metadata_path))
    try:
        document = json.loads(raw)
    except Exception as exc:
        raise PFError("metadata_json_error", str(exc)) from exc
    require(document.get("zarr_format") == 3 and document.get("node_type") == "group", "metadata_root_error", "Zarr-v3 group required")
    metadata = document.get("consolidated_metadata", {}).get("metadata")
    require(isinstance(metadata, dict), "metadata_consolidated_error", "missing inline metadata")
    return raw, document, metadata


def build_selection(metadata_path: Path = METADATA_PATH) -> dict[str, Any]:
    raw, _, metadata = _metadata_document(metadata_path)
    active_all = sorted(key for key in metadata if key.startswith("pf_active/") and metadata[key].get("node_type") == "array")
    passive_all = sorted(key for key in metadata if key.startswith("pf_passive/") and metadata[key].get("node_type") == "array")
    require(set(active_all) - set(SELECTED_ARRAYS) == set(EXPECTED_EXCLUDED_ARRAYS), "selection_active_extra_error", repr(set(active_all) - set(SELECTED_ARRAYS)))
    require(set(passive_all) <= set(SELECTED_ARRAYS), "selection_passive_extra_error", repr(set(passive_all) - set(SELECTED_ARRAYS)))
    require(set(SELECTED_ARRAYS) <= set(active_all + passive_all), "selection_missing_error", repr(set(SELECTED_ARRAYS) - set(active_all + passive_all)))
    groups = {}
    for group in ("pf_active", "pf_passive"):
        node = metadata.get(group)
        require(isinstance(node, dict) and node.get("node_type") == "group", "group_metadata_error", group)
        attrs = node.get("attributes")
        require(isinstance(attrs, dict), "group_attributes_error", group)
        require(attrs.get("ingested_at") in ("2026-07-29T16:40:45Z", "2026-07-29T16:40:38Z"), "group_ingested_at_error", group)
        require(attrs.get("commit_url", "").endswith("ab435c799d892956fb042d55391f7d1be0c950e6 (dirty)"), "group_dirty_revision_error", group)
        groups[group] = node
    fields = []
    numeric_total = 0
    for path in SELECTED_ARRAYS:
        node = metadata[path]
        summary = validate_node(path, node)
        if summary["decoded_bytes"] is not None:
            numeric_total += summary["decoded_bytes"]
        fields.append({"path": path, "node": node, **summary})
    require(numeric_total <= MAX_TOTAL_DECODED_BYTES, "selection_size_limit", str(numeric_total))
    mapping_payload = {"groups": groups, "fields": fields, "excluded": list(EXPECTED_EXCLUDED_ARRAYS)}
    selection = {
        "schema": "mast-pf-geometry-selection-v1",
        "shot_id": SHOT_ID,
        "metadata_path": str(metadata_path.resolve()),
        "metadata_sha256": sha256_bytes(raw),
        "source_base": SOURCE_BASE,
        "selection_rule": "explicit 69 pf_active current/channel/time/geometry arrays plus explicit 140 pf_passive current/channel/time/geometry arrays; PF voltages excluded",
        "group_nodes": groups,
        "fields": fields,
        "selected_array_count": len(fields),
        "active_array_count": sum(item["path"].startswith("pf_active/") for item in fields),
        "passive_array_count": sum(item["path"].startswith("pf_passive/") for item in fields),
        "excluded_arrays": list(EXPECTED_EXCLUDED_ARRAYS),
        "fixed_numeric_decoded_bytes": numeric_total,
        "string_array_count": sum(item["data_type"] == "string" for item in fields),
        "limits": {"max_array_bytes": MAX_ARRAY_BYTES, "max_chunk_bytes": MAX_CHUNK_BYTES, "max_total_decoded_bytes": MAX_TOTAL_DECODED_BYTES, "max_process_rss_bytes": MAX_PROCESS_RSS_BYTES},
        "source_mapping_payload_sha256": sha256_bytes(canonical_bytes(mapping_payload)),
        "science_locks": dict(SCIENCE_LOCKS),
    }
    return seal(selection, "selection_payload_sha256")


def decode_vlen_utf8(raw: bytes, expected_counts: tuple[int, ...]) -> list[str]:
    require(len(raw) >= 4, "string_decode_error", "missing item count")
    count = int.from_bytes(raw[:4], "little", signed=False)
    require(count in expected_counts, "string_count_error", f"{count} not in {expected_counts}")
    values, offset = [], 4
    for _ in range(count):
        require(offset + 4 <= len(raw), "string_decode_error", "truncated item length")
        length = int.from_bytes(raw[offset:offset + 4], "little", signed=False)
        offset += 4
        require(offset + length <= len(raw), "string_decode_error", "truncated UTF-8 value")
        try:
            values.append(raw[offset:offset + length].decode("utf-8"))
        except UnicodeDecodeError as exc:
            raise PFError("string_utf8_error", str(exc)) from exc
        offset += length
    require(offset == len(raw), "string_trailing_bytes_error", f"{len(raw)-offset}")
    return values


def decompress_chunk(compressed: bytes) -> bytes:
    require(0 < len(compressed) <= MAX_CHUNK_BYTES, "compressed_chunk_size_error", str(len(compressed)))
    try:
        raw = zstandard.ZstdDecompressor().decompress(compressed, max_output_size=MAX_CHUNK_BYTES)
    except Exception as exc:
        raise PFError("zstd_decode_error", str(exc)) from exc
    require(0 < len(raw) <= MAX_CHUNK_BYTES, "decoded_chunk_size_error", str(len(raw)))
    return raw


def decode_numeric(raw: bytes, data_type: str, full_shape: tuple[int, ...], edge_shape: tuple[int, ...]) -> tuple[np.ndarray, tuple[int, ...]]:
    dtype = _numeric_dtype(data_type)
    full_bytes = math.prod(full_shape) * dtype.itemsize
    edge_bytes = math.prod(edge_shape) * dtype.itemsize
    require(len(raw) in (full_bytes, edge_bytes), "numeric_decoded_size_error", f"{len(raw)} not in {(full_bytes, edge_bytes)}")
    decoded_shape = full_shape if len(raw) == full_bytes else edge_shape
    return np.frombuffer(raw, dtype=dtype).reshape(decoded_shape, order="C"), decoded_shape


def _session() -> requests.Session:
    retry = Retry(total=3, connect=3, read=3, status=3, backoff_factor=0.5, status_forcelist=(429, 500, 502, 503, 504), allowed_methods=frozenset(("GET",)))
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retry))
    return session


def _download(session: requests.Session, url: str, destination: Path) -> dict[str, Any]:
    started = utc_now()
    with session.get(url, timeout=REQUEST_TIMEOUT, stream=True) as response:
        status = response.status_code
        headers = {key: value for key, value in response.headers.items() if key.lower() in ("content-length", "content-type", "etag", "last-modified")}
        require(status == 200, "http_status_error", f"{status}:{url}")
        received = 0
        with destination.open("xb") as stream:
            for block in response.iter_content(64 * 1024):
                require(received + len(block) <= MAX_CHUNK_BYTES, "compressed_chunk_size_error", url)
                stream.write(block)
                received += len(block)
    return {"requested_utc": started, "completed_utc": utc_now(), "http_status": status, "response_headers": headers, "compressed_bytes": received}


def _record_path(root: Path, path: Path) -> str:
    return path.relative_to(root).as_posix()


def _science_locks(value: Any) -> None:
    require(value == SCIENCE_LOCKS, "science_lock_error", repr(value))


def acquire(output: Path, metadata_path: Path = METADATA_PATH) -> int:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    receipt: dict[str, Any] = {
        "schema": "mast-pf-geometry-acquisition-v1", "shot_id": SHOT_ID,
        "started_utc": utc_now(), "command": sys.argv, "pid": os.getpid(),
        "python": sys.version, "executable": sys.executable, "status": "started",
        "arrays": [], "failures": [], "science_locks": dict(SCIENCE_LOCKS),
        "limits": {"max_array_bytes": MAX_ARRAY_BYTES, "max_chunk_bytes": MAX_CHUNK_BYTES, "max_total_decoded_bytes": MAX_TOTAL_DECODED_BYTES, "max_process_rss_bytes": MAX_PROCESS_RSS_BYTES, "request_timeout": list(REQUEST_TIMEOUT)},
    }
    receipt_path = output / "acquisition.json"
    write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
    session = None
    code = 1
    try:
        pins = {
            "metadata": identity(metadata_path), "entry": identity(Path(__file__).resolve()),
            "ownership": identity(OWNERSHIP_PATH),
            "numpy_entry": identity(Path(np.__file__).resolve()),
            "psutil_entry": identity(Path(psutil.__file__).resolve()),
            "requests_entry": identity(Path(requests.__file__).resolve()),
            "urllib3_entry": identity(Path(urllib3.__file__).resolve()),
            "zstandard_entry": identity(Path(zstandard.__file__).resolve()),
            "zstandard_backend": identity(Path(zstandard.backend_c.__file__).resolve()),
        }
        require(pins["metadata"]["sha256"] == METADATA_SHA256, "metadata_hash_error", pins["metadata"]["sha256"])
        receipt["input_pins"] = pins
        selection = build_selection(metadata_path)
        metadata_raw = metadata_path.read_bytes()
        (output / "zarr.json.copy").write_bytes(metadata_raw)
        (output / "fetch_mast_pf_geometry_v1.py.copy").write_bytes(Path(__file__).read_bytes())
        write_json(output / "selection.json", selection)
        receipt.update({
            "metadata_copy": "zarr.json.copy", "metadata_copy_sha256": sha256_bytes(metadata_raw),
            "script_copy": "fetch_mast_pf_geometry_v1.py.copy",
            "selection_path": "selection.json", "selection_file_sha256": sha256_path(output / "selection.json"),
            "selection_payload_sha256": selection["selection_payload_sha256"],
            "source_mapping_payload_sha256": selection["source_mapping_payload_sha256"],
            "status": "acquiring", "peak_observed_rss_bytes": check_rss(), "actual_total_decoded_chunk_bytes": 0,
        })
        write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
        session = _session()
        for field in selection["fields"]:
            path = field["path"]
            node = field["node"]
            shape, chunks = tuple(field["shape"]), tuple(field["chunks"])
            target = output / "arrays" / path.replace("/", "__")
            chunks_dir = target / "chunks"
            chunks_dir.mkdir(parents=True, exist_ok=False)
            record = {**field, "status": "acquiring", "chunks_acquired": [], "started_utc": utc_now()}
            receipt["arrays"].append(record)
            write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
            is_string = field["data_type"] == "string"
            if is_string:
                assembled_strings = [None] * math.prod(shape)
                covered = np.zeros(shape, dtype=np.bool_)
            else:
                dtype = _numeric_dtype(field["data_type"])
                assembled = np.empty(shape, dtype=dtype, order="C")
                covered = np.zeros(shape, dtype=np.bool_)
            for index in array_chunk_indices(shape, chunks):
                starts, edge = edge_layout(shape, chunks, index)
                key = chunk_key(index)
                name = key.replace("/", "__")
                url = f"{SOURCE_BASE}/{path}/{key}"
                compressed_path = chunks_dir / f"{name}.zst"
                raw_path = chunks_dir / f"{name}.raw"
                chunk = {"chunk_index": list(index), "chunk_key": key, "starts": list(starts), "edge_shape": list(edge), "full_chunk_shape": list(chunks), "url": url, "compressed_path": _record_path(output, compressed_path), "decoded_path": _record_path(output, raw_path), "status": "downloading"}
                record["chunks_acquired"].append(chunk)
                write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
                chunk.update(_download(session, url, compressed_path))
                compressed = compressed_path.read_bytes()
                chunk["compressed_sha256"] = sha256_bytes(compressed)
                raw = decompress_chunk(compressed)
                require(receipt["actual_total_decoded_chunk_bytes"] + len(raw) <= MAX_TOTAL_DECODED_BYTES, "total_decoded_size_limit", path)
                receipt["actual_total_decoded_chunk_bytes"] += len(raw)
                raw_path.write_bytes(raw)
                chunk.update({"decoded_bytes": len(raw), "decoded_sha256": sha256_bytes(raw)})
                slices = tuple(slice(starts[axis], starts[axis] + edge[axis]) for axis in range(len(shape)))
                require(not bool(covered[slices].any()), "chunk_overlap_error", f"{path}:{key}")
                if is_string:
                    full_count, edge_count = math.prod(chunks), math.prod(edge)
                    values = decode_vlen_utf8(raw, (full_count, edge_count))
                    chunk["decoded_item_count"] = len(values)
                    chunk["decoded_shape"] = list(chunks if len(values) == full_count else edge)
                    values = values[:edge_count]
                    require(len(shape) == 1, "zarr_string_rank_error", path)
                    assembled_strings[starts[0]:starts[0] + edge[0]] = values
                else:
                    values, decoded_shape = decode_numeric(raw, field["data_type"], chunks, edge)
                    crop = tuple(slice(0, extent) for extent in edge)
                    values = values[crop]
                    require(values.shape == edge, "chunk_shape_error", f"{path}:{key}")
                    assembled[slices] = values
                    chunk["decoded_shape"] = list(decoded_shape)
                covered[slices] = True
                chunk.update({"status": "decoded", "completed_utc": utc_now()})
                receipt["peak_observed_rss_bytes"] = max(receipt["peak_observed_rss_bytes"], check_rss())
                write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
            require(bool(covered.all()), "chunk_coverage_error", path)
            if is_string:
                require(all(isinstance(item, str) for item in assembled_strings), "string_assembly_error", path)
                assembled_object = {"encoding": "canonical-json-utf8-string-array-v1", "shape": list(shape), "values": assembled_strings}
                assembled_raw = canonical_bytes(assembled_object)
                assembled_path = target / "assembled.strings.json"
                assembled_path.write_bytes(assembled_raw)
                summary = {"string_count": len(assembled_strings), "unique_string_count": len(set(assembled_strings))}
            else:
                assembled_raw = assembled.tobytes(order="C")
                require(len(assembled_raw) <= MAX_ARRAY_BYTES, "array_size_limit", path)
                assembled_path = target / "assembled.raw"
                assembled_path.write_bytes(assembled_raw)
                if np.issubdtype(assembled.dtype, np.floating):
                    finite = assembled[np.isfinite(assembled)]
                    summary = {"finite_count": int(finite.size), "total_count": int(assembled.size), "minimum": float(finite.min()) if finite.size else None, "maximum": float(finite.max()) if finite.size else None}
                else:
                    summary = {"finite_count": int(assembled.size), "total_count": int(assembled.size), "minimum": int(assembled.min()), "maximum": int(assembled.max())}
                if path.endswith("/shot_id"):
                    require(assembled.shape == () and int(assembled) == SHOT_ID, "shot_id_value_error", path)
            record.update({"status": "acquired_raw_values_semantics_unverified", "completed_utc": utc_now(), "assembled_path": _record_path(output, assembled_path), "assembled_bytes": len(assembled_raw), "assembled_sha256": sha256_bytes(assembled_raw), **summary})
            metadata_snapshot = {key: value for key, value in record.items() if key not in ("field_record_path", "field_record_sha256")}
            field_record_path = target / "field_record.json"
            write_json(field_record_path, metadata_snapshot)
            record["field_record_path"] = _record_path(output, field_record_path)
            record["field_record_sha256"] = sha256_path(field_record_path)
            write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
            print(json.dumps({"path": path, "assembled_bytes": len(assembled_raw), "assembled_sha256": record["assembled_sha256"]}, sort_keys=True), flush=True)
        after = {name: identity(Path(item["path"])) for name, item in pins.items()}
        receipt["input_pins_after"] = after
        receipt["inputs_unchanged"] = after == pins
        require(after == pins, "input_pin_drift", "source inputs changed during acquisition")
        receipt.update({"status": "acquired_requires_independent_decode_and_mapping_review", "ended_utc": utc_now(), "exit_code": 0})
        code = 0
    except Exception as exc:
        receipt["failures"].append({"utc": utc_now(), "type": type(exc).__name__, "code": getattr(exc, "code", "program_exception"), "detail": getattr(exc, "detail", str(exc))})
        receipt.update({"status": "failed_preserved", "ended_utc": utc_now(), "exit_code": 1})
        (output / "exception.txt").write_text(traceback.format_exc(), encoding="utf-8")
        print(json.dumps({"status": receipt["status"], "error_code": receipt["failures"][-1]["code"], "detail": receipt["failures"][-1]["detail"]}, sort_keys=True), file=sys.stderr, flush=True)
    finally:
        if session is not None:
            session.close()
        write_sealed(receipt_path, receipt, "acquisition_payload_sha256")
    return code


def verify_array_record(root: Path, record: dict[str, Any], field: dict[str, Any]) -> dict[str, Any]:
    path = field["path"]
    require(record["path"] == path and record["node"] == field["node"], "array_metadata_binding_error", path)
    require(record["status"] == "acquired_raw_values_semantics_unverified", "array_status_error", path)
    shape, chunks = tuple(field["shape"]), tuple(field["chunks"])
    expected_indices = list(array_chunk_indices(shape, chunks))
    chunks_by_index = {tuple(item["chunk_index"]): item for item in record["chunks_acquired"]}
    require(len(chunks_by_index) == len(record["chunks_acquired"]) and set(chunks_by_index) == set(expected_indices), "chunk_index_set_error", path)
    is_string = field["data_type"] == "string"
    covered = np.zeros(shape, dtype=np.bool_)
    assembled_strings = [None] * math.prod(shape) if is_string else None
    assembled = None if is_string else np.empty(shape, dtype=_numeric_dtype(field["data_type"]), order="C")
    decoded_total = 0
    for index in expected_indices:
        chunk = chunks_by_index[index]
        starts, edge = edge_layout(shape, chunks, index)
        key = chunk_key(index)
        name = key.replace("/", "__")
        require(chunk["chunk_key"] == key and chunk["url"] == f"{SOURCE_BASE}/{path}/{key}", "chunk_source_binding_error", f"{path}:{key}")
        require(chunk.get("starts") == list(starts) and chunk.get("edge_shape") == list(edge) and chunk.get("full_chunk_shape") == list(chunks), "chunk_layout_record_error", f"{path}:{key}")
        require(chunk.get("http_status") == 200 and chunk.get("status") == "decoded", "chunk_status_error", f"{path}:{key}")
        expected_compressed = f"arrays/{path.replace('/', '__')}/chunks/{name}.zst"
        expected_decoded = f"arrays/{path.replace('/', '__')}/chunks/{name}.raw"
        compressed_path = safe_relative(root, chunk["compressed_path"])
        raw_path = safe_relative(root, chunk["decoded_path"])
        require(chunk.get("compressed_path") == expected_compressed and chunk.get("decoded_path") == expected_decoded, "chunk_path_binding_error", f"{path}:{key}")
        require(compressed_path.is_file() and raw_path.is_file(), "chunk_file_missing", f"{path}:{key}")
        require(compressed_path.stat().st_size == chunk["compressed_bytes"] and sha256_path(compressed_path) == chunk["compressed_sha256"], "chunk_compressed_hash_error", f"{path}:{key}")
        require(raw_path.stat().st_size == chunk["decoded_bytes"] and sha256_path(raw_path) == chunk["decoded_sha256"], "chunk_decoded_hash_error", f"{path}:{key}")
        raw = decompress_chunk(compressed_path.read_bytes())
        require(raw == raw_path.read_bytes(), "chunk_redecode_mismatch", f"{path}:{key}")
        decoded_total += len(raw)
        slices = tuple(slice(starts[axis], starts[axis] + edge[axis]) for axis in range(len(shape)))
        require(not bool(covered[slices].any()), "chunk_overlap_error", f"{path}:{key}")
        if is_string:
            decoded_values = decode_vlen_utf8(raw, (math.prod(chunks), math.prod(edge)))
            expected_decoded_shape = list(chunks if len(decoded_values) == math.prod(chunks) else edge)
            require(chunk.get("decoded_item_count") == len(decoded_values) and chunk.get("decoded_shape") == expected_decoded_shape, "chunk_decoded_layout_error", f"{path}:{key}")
            values = decoded_values[:math.prod(edge)]
            assembled_strings[starts[0]:starts[0] + edge[0]] = values
        else:
            values, decoded_shape = decode_numeric(raw, field["data_type"], chunks, edge)
            require(chunk.get("decoded_shape") == list(decoded_shape), "chunk_decoded_layout_error", f"{path}:{key}")
            assembled[slices] = values[tuple(slice(0, extent) for extent in edge)]
        covered[slices] = True
    require(bool(covered.all()), "chunk_coverage_error", path)
    if is_string:
        raw = canonical_bytes({"encoding": "canonical-json-utf8-string-array-v1", "shape": list(shape), "values": assembled_strings})
        require(record.get("string_count") == len(assembled_strings) and record.get("unique_string_count") == len(set(assembled_strings)), "array_summary_error", path)
    else:
        raw = assembled.tobytes(order="C")
        if np.issubdtype(assembled.dtype, np.floating):
            finite = assembled[np.isfinite(assembled)]
            expected_summary = {"finite_count": int(finite.size), "total_count": int(assembled.size), "minimum": float(finite.min()) if finite.size else None, "maximum": float(finite.max()) if finite.size else None}
        else:
            expected_summary = {"finite_count": int(assembled.size), "total_count": int(assembled.size), "minimum": int(assembled.min()), "maximum": int(assembled.max())}
        require(all(record.get(key) == value for key, value in expected_summary.items()), "array_summary_error", path)
        if path.endswith("/shot_id"):
            require(assembled.shape == () and int(assembled) == SHOT_ID, "shot_id_value_error", path)
    expected_assembled = f"arrays/{path.replace('/', '__')}/" + ("assembled.strings.json" if is_string else "assembled.raw")
    expected_field_record_path = f"arrays/{path.replace('/', '__')}/field_record.json"
    require(record.get("assembled_path") == expected_assembled and record.get("field_record_path") == expected_field_record_path, "array_path_binding_error", path)
    assembled_path = safe_relative(root, record["assembled_path"])
    require(assembled_path.is_file(), "assembled_file_missing", path)
    require(assembled_path.stat().st_size == record["assembled_bytes"] and sha256_path(assembled_path) == record["assembled_sha256"], "assembled_hash_error", path)
    require(assembled_path.read_bytes() == raw, "assembled_reconstruction_error", path)
    field_record = safe_relative(root, record["field_record_path"])
    require(field_record.is_file() and sha256_path(field_record) == record["field_record_sha256"], "field_record_hash_error", path)
    expected_field_record = {key: value for key, value in record.items() if key not in ("field_record_path", "field_record_sha256")}
    require(json.loads(field_record.read_text(encoding="utf-8")) == expected_field_record, "field_record_content_error", path)
    return {"path": path, "decoded_chunk_bytes": decoded_total, "assembled_bytes": len(raw), "assembled_sha256": record["assembled_sha256"]}


def verify_acquisition(output: Path, metadata_path: Path = METADATA_PATH) -> dict[str, Any]:
    output = output.resolve()
    require(output.is_dir(), "acquisition_root_missing", str(output))
    receipt_path, selection_path = output / "acquisition.json", output / "selection.json"
    require(receipt_path.is_file() and selection_path.is_file(), "acquisition_manifest_missing", str(output))
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    selection = json.loads(selection_path.read_text(encoding="utf-8"))
    validate_seal(receipt, "acquisition_payload_sha256", "acquisition_payload_hash_error")
    validate_seal(selection, "selection_payload_sha256", "selection_payload_hash_error")
    _science_locks(receipt.get("science_locks"))
    _science_locks(selection.get("science_locks"))
    expected = build_selection(metadata_path)
    require(selection == expected, "selection_metadata_binding_error", "selection differs from pinned metadata projection")
    require(receipt.get("status") == "acquired_requires_independent_decode_and_mapping_review" and receipt.get("exit_code") == 0, "acquisition_status_error", str(receipt.get("status")))
    require(receipt.get("selection_file_sha256") == sha256_path(selection_path), "selection_file_hash_error", str(selection_path))
    require(receipt.get("selection_payload_sha256") == selection["selection_payload_sha256"], "selection_receipt_binding_error", "payload hash")
    require(receipt.get("source_mapping_payload_sha256") == selection["source_mapping_payload_sha256"], "source_mapping_hash_error", "receipt/selection")
    metadata_copy = safe_relative(output, receipt["metadata_copy"])
    require(metadata_copy.is_file() and sha256_path(metadata_copy) == METADATA_SHA256, "metadata_copy_hash_error", str(metadata_copy))
    require(metadata_copy.read_bytes() == metadata_path.read_bytes(), "metadata_copy_mismatch", str(metadata_copy))
    script_copy = safe_relative(output, receipt["script_copy"])
    require(script_copy.is_file() and sha256_path(script_copy) == receipt["input_pins"]["entry"]["sha256"], "script_copy_hash_error", str(script_copy))
    require(receipt.get("inputs_unchanged") is True and receipt.get("input_pins") == receipt.get("input_pins_after"), "input_pin_drift", "receipt")
    for name, pinned in receipt["input_pins"].items():
        if name == "entry":
            # The exact producer is the hash-bound script copy above.  A later
            # verifier hardening must not rewrite or invalidate raw acquisition.
            continue
        pinned_path = Path(pinned["path"])
        require(pinned_path.is_file() and pinned_path.stat().st_size == pinned["bytes"] and sha256_path(pinned_path) == pinned["sha256"], "input_pin_live_error", name)
    records = receipt.get("arrays")
    require(isinstance(records, list) and len(records) == 209, "array_record_count_error", str(len(records) if isinstance(records, list) else None))
    require([item.get("path") for item in records] == list(SELECTED_ARRAYS), "array_record_order_error", "records")
    by_path = {item.get("path"): item for item in records}
    require(len(by_path) == 209 and set(by_path) == set(SELECTED_ARRAYS), "array_record_set_error", "records")
    verified, decoded_total = [], 0
    for field in selection["fields"]:
        result = verify_array_record(output, by_path[field["path"]], field)
        verified.append(result)
        decoded_total += result["decoded_chunk_bytes"]
    require(decoded_total == receipt["actual_total_decoded_chunk_bytes"] <= MAX_TOTAL_DECODED_BYTES, "total_decoded_size_error", str(decoded_total))
    report = {
        "schema": "mast-pf-geometry-verification-v1", "verified_utc": utc_now(),
        "output": str(output), "metadata_sha256": METADATA_SHA256,
        "selection_payload_sha256": selection["selection_payload_sha256"],
        "acquisition_payload_sha256": receipt["acquisition_payload_sha256"],
        "source_mapping_payload_sha256": selection["source_mapping_payload_sha256"],
        "array_count": len(verified), "decoded_chunk_bytes": decoded_total,
        "science_locks": dict(SCIENCE_LOCKS), "status": "verified_raw_acquisition_requires_independent_decode_and_mapping_review",
        "arrays": verified,
    }
    return seal(report, "verification_payload_sha256")


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("plan", "fetch", "verify"):
        item = sub.add_parser(name)
        item.add_argument("--metadata", type=Path, default=METADATA_PATH)
        if name != "plan":
            item.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "plan":
            print(json.dumps(build_selection(args.metadata), ensure_ascii=False, sort_keys=True, indent=2))
            return 0
        if args.command == "fetch":
            return acquire(args.output, args.metadata)
        report = verify_acquisition(args.output, args.metadata)
        print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
        return 0
    except PFError as exc:
        print(json.dumps({"status": "failed", "error_code": exc.code, "detail": exc.detail}, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
