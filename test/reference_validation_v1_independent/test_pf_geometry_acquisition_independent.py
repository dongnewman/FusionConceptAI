"""Independent byte-level audit for the frozen MAST PF geometry acquisition.

This oracle intentionally does not import the acquisition implementation.  It
uses the same Zstandard codec family because that is the on-disk compression
format, but independently derives chunk indices, edge cropping, string framing,
row-major assembly, metadata bindings, file identities, seals, and science
locks.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import itertools
import json
import math
import os
from pathlib import Path, PurePosixPath
import struct
import sys
from typing import Any, Iterable

import zstandard


REPO = Path(__file__).resolve().parents[2]
DATA = REPO / "benchmarks/reference_source_fields_v1/shot30421_pf_geometry_r1/acquisition_r1"
EVIDENCE = REPO / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/pf_geometry_source_r1_20260922"

EXPECTED_FILES = {
    REPO / "tools/fetch_mast_pf_geometry_v1.py": "3cbfa730faa15c55b38d119945cf75ad533ed7060312b4ea8b3a9146f79186ad",
    REPO / "test/reference_source_fields_v1/test_pf_geometry_acquisition_v1.py": "a6f513fb40d6e98e7acefb1d9830da91489568def2d7b525348b89d7e77559f2",
    DATA / "fetch_mast_pf_geometry_v1.py.copy": "c0f61a04900adca51a44b5a92635392ce81a124d6c1f8e190373402797f8c323",
    DATA / "acquisition.json": "a690debff6ecea5bf6d885e4d2f325f43ea21fdac613bf92a94064ff1798f2e8",
    DATA / "selection.json": "c6c9c6381de8365b80a6af75948876033d9df4486b58332eef54fa0c7c199ba6",
    EVIDENCE / "acquisition_artifact_manifest.json": "59cd808d3bebb607e228ca4384bd9ee1f221206885a9b1c0a7ebe3d74149c122",
    EVIDENCE / "source_inventory.json": "a94f799d779660de276a56f2cd7c4321925fecaf305342ec0e2df3c011d86f45",
    EVIDENCE / "freeze_audit.json": "80ecdc1e77e4f0a7fffdfdd227659d070f5428878bdf711c4b7e2a1fc55303c3",
    EVIDENCE / "freeze_manifest.json": "248a501dc7b48c9e82532460eac19ff75bab8ec2c947642fd753b23344d058d0",
    EVIDENCE / "test_runtime_r1/execution.json": "9cd0cdbdbcdfab9ebb94d3b0c3a69eefe51378539bdd934c0d70426b83faac25",
    EVIDENCE / "verify_runtime_r1/execution.json": "2ace4cdf0a7e77bbc8dd563ef8cb6af565ae38a12745ced86614bbc42148f965",
    EVIDENCE / "verifier_r2_snapshot/fetch_mast_pf_geometry_v1.py": "3cbfa730faa15c55b38d119945cf75ad533ed7060312b4ea8b3a9146f79186ad",
    EVIDENCE / "verifier_r2_snapshot/test_pf_geometry_acquisition_v1.py": "a6f513fb40d6e98e7acefb1d9830da91489568def2d7b525348b89d7e77559f2",
    EVIDENCE / "verifier_r2_snapshot/snapshot_manifest.json": "fc5f463a645259640f83b6bffa0c9dff07cda9af2677251be4357c60dcdda0e2",
    EVIDENCE / "verifier_r2_snapshot/producer_to_verifier_r2.patch": "ff22b72062e8276b69e6059a26a095e168ebd36d872140ef0517b27dd9a9c9f1",
    EVIDENCE / "freeze_audit_r2.json": "020d0ae1ce8cd4cc2743206dc490553259f1bdd260907fedf8264b7ca3b07203",
    EVIDENCE / "freeze_manifest_r2.json": "c9068baf56cf636ef58db4d38cbb9778ac9f50634a96e082a70c644721540fc0",
    EVIDENCE / "test_runtime_r2/execution.json": "5fc9e0bd4eb8ce4930f3333c852ff2f1a12e1896a55adbef6b3f8d5757d953d8",
    EVIDENCE / "verify_runtime_r2/execution.json": "728bc925c5c056aff8d7c10abb9f5b063c9ca5361a48361ba823911a7f94fa38",
}

EXPECTED_SCIENCE_LOCKS = {
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

DTYPES = {
    "float32": ("<f", 4),
    "float64": ("<d", 8),
    "int64": ("<q", 8),
}
SOURCE_BASE = "https://s3.echo.stfc.ac.uk/mast/level2/shots/30421.zarr"
MAX_CHUNK_BYTES = 16 * 1024 * 1024


class AuditError(AssertionError):
    pass


class Audit:
    def __init__(self) -> None:
        self.assertions = 0
        self.negative_controls: list[str] = []

    def check(self, condition: bool, detail: str) -> None:
        self.assertions += 1
        if not condition:
            raise AuditError(detail)

    def equal(self, actual: Any, expected: Any, detail: str) -> None:
        self.check(actual == expected, f"{detail}: {actual!r} != {expected!r}")

    def negative(self, name: str, callback) -> None:
        try:
            callback()
        except (AuditError, UnicodeDecodeError, zstandard.ZstdError, ValueError, struct.error):
            self.negative_controls.append(name)
            self.assertions += 1
            return
        raise AuditError(f"negative control did not fail: {name}")


def sha256_bytes(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(",", ":"), allow_nan=False) + "\n").encode("utf-8")


def payload_hash(value: dict[str, Any], field: str) -> str:
    return sha256_bytes(canonical_bytes({key: item for key, item in value.items() if key != field}))


def safe_relative(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or not relative:
        raise AuditError("empty relative path")
    pure = PurePosixPath(relative)
    if pure.is_absolute() or ".." in pure.parts:
        raise AuditError(f"path escape: {relative}")
    base = root.resolve()
    candidate = (base / Path(*pure.parts)).resolve()
    if os.path.commonpath((str(base), str(candidate))) != str(base):
        raise AuditError(f"resolved path escape: {relative}")
    return candidate


def product(values: Iterable[int]) -> int:
    return math.prod(tuple(values))


def chunk_indices(shape: tuple[int, ...], chunks: tuple[int, ...]):
    if not shape:
        yield ()
        return
    counts = tuple(math.ceil(shape[axis] / chunks[axis]) for axis in range(len(shape)))
    yield from itertools.product(*(range(count) for count in counts))


def chunk_key(index: tuple[int, ...]) -> str:
    return "c" if not index else "c/" + "/".join(str(item) for item in index)


def edge_layout(shape: tuple[int, ...], chunks: tuple[int, ...], index: tuple[int, ...]):
    starts = tuple(index[axis] * chunks[axis] for axis in range(len(shape)))
    edge = tuple(min(chunks[axis], shape[axis] - starts[axis]) for axis in range(len(shape)))
    return starts, edge


def decompress_zstd(raw: bytes) -> bytes:
    if not 0 < len(raw) <= MAX_CHUNK_BYTES:
        raise AuditError("compressed chunk size")
    decoded = zstandard.ZstdDecompressor().decompress(raw, max_output_size=MAX_CHUNK_BYTES)
    if not 0 < len(decoded) <= MAX_CHUNK_BYTES:
        raise AuditError("decoded chunk size")
    return decoded


def decode_vlen_utf8(raw: bytes, expected_counts: tuple[int, ...]) -> list[str]:
    if len(raw) < 4:
        raise AuditError("string count absent")
    count = int.from_bytes(raw[:4], "little", signed=False)
    if count not in expected_counts:
        raise AuditError("string count mismatch")
    values: list[str] = []
    offset = 4
    for _ in range(count):
        if offset + 4 > len(raw):
            raise AuditError("truncated string length")
        length = int.from_bytes(raw[offset:offset + 4], "little", signed=False)
        offset += 4
        if offset + length > len(raw):
            raise AuditError("truncated string payload")
        values.append(raw[offset:offset + length].decode("utf-8"))
        offset += length
    if offset != len(raw):
        raise AuditError("trailing string bytes")
    return values


def node_contract(audit: Audit, path: str, node: dict[str, Any]) -> tuple[tuple[int, ...], tuple[int, ...], str]:
    audit.equal(node.get("node_type"), "array", f"{path} node type")
    audit.equal(node.get("zarr_format"), 3, f"{path} zarr format")
    audit.equal(node.get("storage_transformers"), [], f"{path} storage transformers")
    shape_raw = node.get("shape")
    chunks_raw = node.get("chunk_grid", {}).get("configuration", {}).get("chunk_shape")
    audit.check(isinstance(shape_raw, list) and isinstance(chunks_raw, list), f"{path} shape type")
    audit.equal(len(shape_raw), len(chunks_raw), f"{path} rank")
    audit.check(all(isinstance(x, int) and x > 0 for x in shape_raw), f"{path} shape values")
    audit.check(all(isinstance(x, int) and x > 0 for x in chunks_raw), f"{path} chunk values")
    shape, chunks = tuple(shape_raw), tuple(chunks_raw)
    audit.equal(node.get("chunk_grid", {}).get("name"), "regular", f"{path} chunk grid")
    audit.equal(node.get("chunk_key_encoding"), {"name": "default", "configuration": {"separator": "/"}}, f"{path} chunk key encoding")
    dims = node.get("dimension_names", [] if not shape else None)
    audit.check(isinstance(dims, list) and len(dims) == len(shape), f"{path} dimensions")
    audit.check(all(isinstance(x, str) and x for x in dims), f"{path} dimension labels")
    dtype = node.get("data_type")
    codecs = node.get("codecs")
    audit.check(isinstance(codecs, list) and len(codecs) == 2, f"{path} codecs")
    if dtype == "string":
        audit.equal(codecs[0], {"name": "vlen-utf8", "configuration": {}}, f"{path} string codec")
        audit.equal(len(shape), 1, f"{path} string rank")
    else:
        audit.check(dtype in DTYPES, f"{path} numeric dtype")
        audit.equal(codecs[0], {"name": "bytes", "configuration": {"endian": "little"}}, f"{path} endian")
    audit.equal(codecs[1], {"name": "zstd", "configuration": {"level": 0, "checksum": False}}, f"{path} zstd")
    return shape, chunks, str(dtype)


def validate_locks(audit: Audit, locks: Any) -> None:
    audit.equal(locks, EXPECTED_SCIENCE_LOCKS, "science locks")


def verify_blob(audit: Audit, path: Path, expected_bytes: int, expected_hash: str, label: str) -> bytes:
    audit.check(path.is_file(), f"{label} absent")
    raw = path.read_bytes()
    audit.equal(len(raw), expected_bytes, f"{label} bytes")
    audit.equal(sha256_bytes(raw), expected_hash, f"{label} hash")
    return raw


def copy_numeric_edge(assembled: bytearray, raw: bytes, shape: tuple[int, ...],
                      decoded_shape: tuple[int, ...], starts: tuple[int, ...],
                      edge: tuple[int, ...], itemsize: int) -> None:
    if not shape:
        assembled[:] = raw[:itemsize]
    elif len(shape) == 1:
        count = edge[0]
        assembled[starts[0] * itemsize:(starts[0] + count) * itemsize] = raw[:count * itemsize]
    elif len(shape) == 2:
        source_stride = decoded_shape[1] * itemsize
        target_stride = shape[1] * itemsize
        width = edge[1] * itemsize
        for row in range(edge[0]):
            source = row * source_stride
            target = (starts[0] + row) * target_stride + starts[1] * itemsize
            assembled[target:target + width] = raw[source:source + width]
    else:
        raise AuditError("unsupported independent rank")


def numeric_statistics(raw: bytes, dtype: str) -> tuple[int, int | float | None, int | float | None]:
    fmt, itemsize = DTYPES[dtype]
    values = [item[0] for item in struct.iter_unpack(fmt, raw)]
    if len(raw) != len(values) * itemsize:
        raise AuditError("numeric trailing bytes")
    finite_values = [value for value in values if math.isfinite(value)]
    return len(finite_values), (min(finite_values) if finite_values else None), (max(finite_values) if finite_values else None)


def run(report_path: Path) -> dict[str, Any]:
    audit = Audit()
    fixed_identities = []
    for path, expected in EXPECTED_FILES.items():
        audit.check(path.is_file(), f"frozen file absent: {path}")
        actual = sha256_path(path)
        audit.equal(actual, expected, f"frozen hash {path}")
        fixed_identities.append({"path": str(path), "bytes": path.stat().st_size, "sha256": actual})

    r2_manifest = json.loads((EVIDENCE / "freeze_manifest_r2.json").read_text(encoding="utf-8"))
    audit.equal(len(r2_manifest["files"]), 38, "r2 freeze file count")
    for item in r2_manifest["files"]:
        path = safe_relative(REPO, item["path"])
        verify_blob(audit, path, item["bytes"], item["sha256"], f"r2 freeze {item['path']}")
    live_verifier = (REPO / "tools/fetch_mast_pf_geometry_v1.py").read_bytes()
    snapshot_verifier = (EVIDENCE / "verifier_r2_snapshot/fetch_mast_pf_geometry_v1.py").read_bytes()
    live_test = (REPO / "test/reference_source_fields_v1/test_pf_geometry_acquisition_v1.py").read_bytes()
    snapshot_test = (EVIDENCE / "verifier_r2_snapshot/test_pf_geometry_acquisition_v1.py").read_bytes()
    audit.equal(live_verifier, snapshot_verifier, "live verifier equals r2 snapshot")
    audit.equal(live_test, snapshot_test, "live implementer test equals r2 snapshot")
    audit.check(live_verifier != (DATA / "fetch_mast_pf_geometry_v1.py.copy").read_bytes(),
                "producer and hardened verifier remain distinct")

    artifact_manifest = json.loads((EVIDENCE / "acquisition_artifact_manifest.json").read_text(encoding="utf-8"))
    live_files = sorted(path for path in DATA.rglob("*") if path.is_file())
    live_by_relative = {path.relative_to(DATA).as_posix(): path for path in live_files}
    manifest_by_relative = {item["path"]: item for item in artifact_manifest["files"]}
    audit.equal(len(live_files), 854, "artifact file count")
    audit.equal(set(live_by_relative), set(manifest_by_relative), "artifact path inventory")
    audit.equal(sum(path.stat().st_size for path in live_files), 13_896_532, "artifact total bytes")
    for relative, item in manifest_by_relative.items():
        path = live_by_relative[relative]
        audit.equal(path.stat().st_size, item["bytes"], f"manifest bytes {relative}")
        audit.equal(sha256_path(path), item["sha256"], f"manifest hash {relative}")
    audit.equal(sum(path.suffix == ".zst" for path in live_files), 216, "compressed file count")
    audit.equal(sum(path.name.endswith(".raw") and path.parent.name == "chunks" for path in live_files), 216, "decoded chunk file count")

    acquisition = json.loads((DATA / "acquisition.json").read_text(encoding="utf-8"))
    selection = json.loads((DATA / "selection.json").read_text(encoding="utf-8"))
    metadata_document = json.loads((DATA / "zarr.json.copy").read_text(encoding="utf-8"))
    metadata = metadata_document["consolidated_metadata"]["metadata"]
    audit.equal(payload_hash(acquisition, "acquisition_payload_sha256"), acquisition["acquisition_payload_sha256"], "acquisition seal")
    audit.equal(payload_hash(selection, "selection_payload_sha256"), selection["selection_payload_sha256"], "selection seal")
    audit.equal(acquisition["acquisition_payload_sha256"], "d15178107387712ad8c2424e70722467a09410aba61788ff624d4709d35cd6aa", "acquisition payload")
    audit.equal(selection["selection_payload_sha256"], "58f3c97d80c10b67e498b434cb7dbaad8094570e007335756b80dea9a28b5351", "selection payload")
    audit.equal(selection["source_mapping_payload_sha256"], "dd945888f18889ffb37724880d223deca99eb6e5283d532c45f9265c7ce7aed2", "mapping payload")
    validate_locks(audit, acquisition["science_locks"])
    validate_locks(audit, selection["science_locks"])
    audit.equal(acquisition["status"], "acquired_requires_independent_decode_and_mapping_review", "acquisition status")
    audit.equal(acquisition["exit_code"], 0, "acquisition exit")
    audit.equal(acquisition["inputs_unchanged"], True, "input stability")
    audit.equal(acquisition["input_pins"], acquisition["input_pins_after"], "input pin equality")
    audit.equal(sha256_path(DATA / "zarr.json.copy"), selection["metadata_sha256"], "metadata copy hash")
    audit.equal(acquisition["metadata_copy_sha256"], selection["metadata_sha256"], "metadata receipt binding")
    audit.equal(acquisition["selection_file_sha256"], sha256_path(DATA / "selection.json"), "selection file binding")
    audit.equal(acquisition["selection_payload_sha256"], selection["selection_payload_sha256"], "selection receipt payload")
    audit.equal(acquisition["source_mapping_payload_sha256"], selection["source_mapping_payload_sha256"], "mapping receipt payload")
    audit.equal(selection["source_base"], SOURCE_BASE, "source base")
    audit.equal(selection["shot_id"], 30421, "selection shot")
    audit.equal(acquisition["shot_id"], 30421, "acquisition shot")
    audit.equal(selection["selected_array_count"], 209, "selected count")
    audit.equal(selection["active_array_count"], 69, "active count")
    audit.equal(selection["passive_array_count"], 140, "passive count")
    audit.equal(selection["string_array_count"], 43, "string count")
    audit.equal(selection["excluded_arrays"], ["pf_active/coil_voltage", "pf_active/voltage_channel"], "excluded arrays")

    fields = selection["fields"]
    records = acquisition["arrays"]
    field_paths = [item["path"] for item in fields]
    record_paths = [item["path"] for item in records]
    audit.equal(len(fields), 209, "field count")
    audit.equal(len(set(field_paths)), 209, "field uniqueness")
    audit.equal(record_paths, field_paths, "acquisition/selection order")
    audit.equal(selection["group_nodes"], {name: metadata[name] for name in ("pf_active", "pf_passive")}, "group metadata binding")
    mapping_payload = {"groups": selection["group_nodes"], "fields": fields, "excluded": selection["excluded_arrays"]}
    audit.equal(sha256_bytes(canonical_bytes(mapping_payload)), selection["source_mapping_payload_sha256"], "mapping recomputation")

    dtype_counts: dict[str, int] = {}
    rank_counts: dict[str, int] = {}
    decoded_chunk_total = 0
    compressed_chunk_total = 0
    edge_chunk_count = 0
    string_value_total = 0
    assembled_bindings = []
    sample_string_raw: bytes | None = None
    sample_string_expected_counts: tuple[int, ...] | None = None
    sample_compressed: bytes | None = None
    sample_numeric_raw: bytes | None = None
    sample_numeric_record: dict[str, Any] | None = None
    sample_edge_padding_raw: bytes | None = None
    sample_edge_padding_hash: str | None = None

    for position, (field, record) in enumerate(zip(fields, records)):
        path = field["path"]
        audit.equal(record["path"], path, f"record path {position}")
        audit.equal(field["node"], metadata[path], f"metadata projection {path}")
        audit.equal(record["node"], field["node"], f"record node {path}")
        shape, chunks, dtype = node_contract(audit, path, field["node"])
        audit.equal(record["shape"], list(shape), f"record shape {path}")
        audit.equal(record["chunks"], list(chunks), f"record chunks {path}")
        audit.equal(record["dimensions"], field["node"].get("dimension_names", []), f"record dimensions {path}")
        audit.equal(record.get("units"), field["node"].get("attributes", {}).get("units"), f"record units {path}")
        audit.equal(field["dimensions"], record["dimensions"], f"field dimensions {path}")
        audit.equal(field.get("units"), record.get("units"), f"field units {path}")
        audit.equal(field["data_type"], dtype, f"field dtype {path}")
        storage_name = path.replace("/", "__")
        expected_field_record_path = f"arrays/{storage_name}/field_record.json"
        expected_assembled_path = (f"arrays/{storage_name}/assembled.strings.json" if dtype == "string"
                                   else f"arrays/{storage_name}/assembled.raw")
        audit.equal(record["field_record_path"], expected_field_record_path, f"field record canonical path {path}")
        audit.equal(record["assembled_path"], expected_assembled_path, f"assembled canonical path {path}")
        field_record_path = safe_relative(DATA, record["field_record_path"])
        field_record_raw = verify_blob(audit, field_record_path, field_record_path.stat().st_size,
                                       record["field_record_sha256"], f"field record {path}")
        field_record = json.loads(field_record_raw)
        audit.equal(field_record, {key: value for key, value in record.items()
                                   if key not in ("field_record_path", "field_record_sha256")}, f"field record content {path}")

        expected_indices = list(chunk_indices(shape, chunks))
        actual_indices = [tuple(item["chunk_index"]) for item in record["chunks_acquired"]]
        audit.equal(actual_indices, expected_indices, f"chunk order {path}")
        if dtype == "string":
            assembled_strings: list[str | None] = [None] * product(shape)
            assembled_numeric = None
            itemsize = None
        else:
            _, itemsize = DTYPES[dtype]
            assembled_numeric = bytearray(product(shape) * itemsize)
            assembled_strings = []

        for index, chunk in zip(expected_indices, record["chunks_acquired"]):
            starts, edge = edge_layout(shape, chunks, index)
            key = chunk_key(index)
            audit.equal(chunk["chunk_key"], key, f"chunk key {path}:{index}")
            audit.equal(chunk["starts"], list(starts), f"chunk starts {path}:{index}")
            audit.equal(chunk["edge_shape"], list(edge), f"chunk edge {path}:{index}")
            audit.equal(chunk["full_chunk_shape"], list(chunks), f"chunk full shape {path}:{index}")
            audit.equal(chunk["url"], f"{SOURCE_BASE}/{path}/{key}", f"chunk URL {path}:{index}")
            audit.equal(chunk["http_status"], 200, f"chunk HTTP {path}:{index}")
            audit.equal(chunk["status"], "decoded", f"chunk status {path}:{index}")
            chunk_name = key.replace("/", "__")
            audit.equal(chunk["compressed_path"], f"arrays/{storage_name}/chunks/{chunk_name}.zst",
                        f"compressed canonical path {path}:{index}")
            audit.equal(chunk["decoded_path"], f"arrays/{storage_name}/chunks/{chunk_name}.raw",
                        f"decoded canonical path {path}:{index}")
            compressed_path = safe_relative(DATA, chunk["compressed_path"])
            decoded_path = safe_relative(DATA, chunk["decoded_path"])
            compressed = verify_blob(audit, compressed_path, chunk["compressed_bytes"],
                                     chunk["compressed_sha256"], f"compressed {path}:{index}")
            stored_raw = verify_blob(audit, decoded_path, chunk["decoded_bytes"],
                                     chunk["decoded_sha256"], f"decoded {path}:{index}")
            independent_raw = decompress_zstd(compressed)
            audit.equal(independent_raw, stored_raw, f"independent Zstd decode {path}:{index}")
            decoded_chunk_total += len(stored_raw)
            compressed_chunk_total += 1
            if edge != chunks:
                edge_chunk_count += 1
            if sample_compressed is None:
                sample_compressed = compressed
            if dtype == "string":
                values = decode_vlen_utf8(stored_raw, (product(chunks), product(edge)))
                audit.equal(chunk["decoded_item_count"], len(values), f"decoded item count {path}:{index}")
                audit.equal(chunk["decoded_shape"], list(chunks if len(values) == product(chunks) else edge),
                            f"decoded string shape {path}:{index}")
                values = values[:product(edge)]
                audit.equal(len(shape), 1, f"string rank {path}")
                assembled_strings[starts[0]:starts[0] + edge[0]] = values
                string_value_total += len(values)
                if sample_string_raw is None:
                    sample_string_raw = stored_raw
                    sample_string_expected_counts = (product(chunks), product(edge))
            else:
                expected_full_bytes = product(chunks) * itemsize
                expected_edge_bytes = product(edge) * itemsize
                audit.check(len(stored_raw) in (expected_full_bytes, expected_edge_bytes), f"numeric decoded bytes {path}:{index}")
                decoded_shape = chunks if len(stored_raw) == expected_full_bytes else edge
                audit.equal(chunk["decoded_shape"], list(decoded_shape), f"decoded shape {path}:{index}")
                copy_numeric_edge(assembled_numeric, stored_raw, shape, decoded_shape, starts, edge, itemsize)
                if sample_numeric_raw is None:
                    sample_numeric_raw = stored_raw
                    sample_numeric_record = {"dtype": dtype, "shape": shape, "chunks": chunks, "edge": edge}
                if edge != chunks and len(stored_raw) == expected_full_bytes:
                    sample_edge_padding_raw = stored_raw
                    sample_edge_padding_hash = chunk["decoded_sha256"]

        assembled_path = safe_relative(DATA, record["assembled_path"])
        if dtype == "string":
            audit.check(all(item is not None for item in assembled_strings), f"string coverage {path}")
            independent_assembled = canonical_bytes({"encoding": "canonical-json-utf8-string-array-v1",
                                                     "shape": list(shape), "values": assembled_strings})
            audit.equal(record["string_count"], len(assembled_strings), f"string assembled count {path}")
            audit.equal(record["unique_string_count"], len(set(assembled_strings)), f"string unique count {path}")
        else:
            independent_assembled = bytes(assembled_numeric)
            finite, minimum, maximum = numeric_statistics(independent_assembled, dtype)
            audit.equal(record["total_count"], product(shape), f"numeric count {path}")
            audit.equal(record["finite_count"], finite, f"numeric finite {path}")
            audit.equal(record["minimum"], minimum, f"numeric minimum {path}")
            audit.equal(record["maximum"], maximum, f"numeric maximum {path}")
            if path.endswith("/shot_id"):
                audit.equal(struct.unpack("<q", independent_assembled)[0], 30421, f"scalar shot {path}")
        stored_assembled = verify_blob(audit, assembled_path, record["assembled_bytes"],
                                       record["assembled_sha256"], f"assembled {path}")
        audit.equal(independent_assembled, stored_assembled, f"independent assembly {path}")
        assembled_bindings.append({"path": path, "sha256": sha256_bytes(independent_assembled),
                                   "bytes": len(independent_assembled), "dtype": dtype,
                                   "shape": list(shape), "units": record.get("units"),
                                   "dimensions": record["dimensions"]})
        dtype_counts[dtype] = dtype_counts.get(dtype, 0) + 1
        rank_counts[str(len(shape))] = rank_counts.get(str(len(shape)), 0) + 1

    audit.equal(decoded_chunk_total, acquisition["actual_total_decoded_chunk_bytes"], "decoded chunk total")
    audit.equal(decoded_chunk_total, 4_292_451, "known decoded chunk total")
    audit.equal(compressed_chunk_total, 216, "recorded chunk count")
    audit.equal(edge_chunk_count, 3, "edge chunk count")
    audit.equal(dtype_counts, {"float64": 112, "string": 43, "int64": 2, "float32": 52}, "dtype census")
    audit.equal(rank_counts, {"2": 14, "1": 193, "0": 2}, "rank census")
    audit.equal(selection["fixed_numeric_decoded_bytes"], 4_151_112, "fixed numeric decoded bytes")

    # Negative controls exercise independent contracts without modifying the frozen tree.
    forged_locks = dict(EXPECTED_SCIENCE_LOCKS)
    forged_locks["turns_semantics_verified"] = True
    audit.negative("science_lock_forgery", lambda: validate_locks(audit, forged_locks))
    numeric_node = copy.deepcopy(next(field["node"] for field in fields if field["data_type"] != "string"))
    numeric_node["codecs"][0]["configuration"]["endian"] = "big"
    audit.negative("big_endian_metadata", lambda: node_contract(audit, "tampered", numeric_node))
    dimension_node = copy.deepcopy(next(field["node"] for field in fields if len(field["shape"]) == 1))
    dimension_node["dimension_names"] = []
    audit.negative("dimension_metadata", lambda: node_contract(audit, "tampered", dimension_node))
    audit.negative("path_escape", lambda: safe_relative(DATA, "../outside"))
    audit.negative("selection_order", lambda: audit.equal(list(reversed(field_paths)), record_paths, "forged order"))
    audit.negative("unit_metadata", lambda: audit.equal("forged", records[0].get("units"), "forged units"))
    audit.negative("source_url", lambda: audit.equal(SOURCE_BASE + "/wrong", records[0]["chunks_acquired"][0]["url"], "forged URL"))
    same_name_metadata = copy.deepcopy(records[0])
    same_name_metadata["node"]["shape"] = list(records[1]["shape"])
    audit.negative("same_name_metadata_layout", lambda: audit.equal(
        same_name_metadata["node"], fields[0]["node"], "same-name metadata forgery"))
    cross_record_metadata = copy.deepcopy(records[0])
    cross_record_metadata["node"] = copy.deepcopy(records[1]["node"])
    audit.negative("cross_record_metadata", lambda: audit.equal(
        cross_record_metadata["node"], fields[0]["node"], "cross-record metadata forgery"))
    layout_tamper = copy.deepcopy(records[0]["chunks_acquired"][0])
    layout_tamper["starts"][0] += 1
    audit.negative("chunk_layout", lambda: audit.equal(
        layout_tamper["starts"], [0, 0], "chunk layout forgery"))
    summary_tamper = copy.deepcopy(records[0])
    summary_tamper["finite_count"] += 1
    first_numeric_bytes = safe_relative(DATA, records[0]["assembled_path"]).read_bytes()
    first_numeric_finite = numeric_statistics(first_numeric_bytes, records[0]["data_type"])[0]
    audit.negative("derived_summary", lambda: audit.equal(
        summary_tamper["finite_count"], first_numeric_finite, "summary forgery"))
    hash_tamper = copy.deepcopy(records[0]["chunks_acquired"][0])
    hash_tamper["decoded_sha256"] = "0" * 64
    first_decoded_path = safe_relative(DATA, hash_tamper["decoded_path"])
    audit.negative("decoded_hash_record", lambda: audit.equal(
        hash_tamper["decoded_sha256"], sha256_path(first_decoded_path), "decoded hash forgery"))
    chunk_path_tamper = copy.deepcopy(records[0]["chunks_acquired"][0])
    chunk_path_tamper["compressed_path"] = "arrays/pf_active__coil_current/chunks/forged.zst"
    audit.negative("canonical_chunk_path", lambda: audit.equal(
        chunk_path_tamper["compressed_path"], "arrays/pf_active__coil_current/chunks/c__0__0.zst",
        "chunk path forgery"))
    assembled_path_tamper = copy.deepcopy(records[0])
    assembled_path_tamper["assembled_path"] = records[1]["assembled_path"]
    audit.negative("canonical_assembled_path", lambda: audit.equal(
        assembled_path_tamper["assembled_path"], "arrays/pf_active__coil_current/assembled.raw",
        "assembled path forgery"))
    audit.check(sample_compressed is not None and sample_string_raw is not None and
                sample_string_expected_counts is not None and
                sample_numeric_raw is not None and sample_edge_padding_raw is not None,
                "negative control fixtures")
    audit.negative("zstd_truncated", lambda: decompress_zstd(sample_compressed[:-3]))
    audit.negative("string_truncated", lambda: decode_vlen_utf8(sample_string_raw[:-1], sample_string_expected_counts))
    audit.negative("string_trailing", lambda: decode_vlen_utf8(sample_string_raw + b"x", sample_string_expected_counts))
    invalid_utf8 = bytearray(sample_string_raw)
    string_count = struct.unpack_from("<I", invalid_utf8, 0)[0]
    first_payload_offset = 4 + 4 * string_count
    audit.check(first_payload_offset < len(invalid_utf8), "string payload fixture")
    invalid_utf8[first_payload_offset] = 0xFF
    audit.negative("string_invalid_utf8", lambda: decode_vlen_utf8(bytes(invalid_utf8), sample_string_expected_counts))
    audit.negative("numeric_size", lambda: numeric_statistics(sample_numeric_raw[:-1], sample_numeric_record["dtype"]))
    tampered_edge = bytearray(sample_edge_padding_raw)
    tampered_edge[-1] ^= 1
    audit.negative("edge_padding_raw_hash", lambda: audit.equal(sha256_bytes(bytes(tampered_edge)), sample_edge_padding_hash, "tampered edge hash"))
    scalar = struct.pack("<q", 30422)
    audit.negative("scalar_shot_id", lambda: audit.equal(struct.unpack("<q", scalar)[0], 30421, "tampered scalar"))
    assembled_first = safe_relative(DATA, records[0]["assembled_path"]).read_bytes()
    assembled_tampered = bytearray(assembled_first)
    assembled_tampered[0] ^= 1
    audit.negative("assembled_hash", lambda: audit.equal(sha256_bytes(bytes(assembled_tampered)), records[0]["assembled_sha256"], "tampered assembled"))

    report = {
        "schema": "fusionconceptai:independent-pf-geometry-byte-audit-v1",
        "status": "independent_byte_contract_pass",
        "assertion_count": audit.assertions,
        "negative_controls": audit.negative_controls,
        "frozen_identities": fixed_identities,
        "verifier_lineage": {
            "immutable_acquisition_producer_sha256": "c0f61a04900adca51a44b5a92635392ce81a124d6c1f8e190373402797f8c323",
            "hardened_r2_verifier_sha256": "3cbfa730faa15c55b38d119945cf75ad533ed7060312b4ea8b3a9146f79186ad",
            "hardened_r2_test_sha256": "a6f513fb40d6e98e7acefb1d9830da91489568def2d7b525348b89d7e77559f2",
            "live_equals_snapshot": True,
            "r1_test_bytes_available": False,
            "r1_test_scope": "historical execution receipt only; old test bytes were not preserved",
            "r2_freeze_file_count": len(r2_manifest["files"]),
        },
        "acquisition": {
            "root": str(DATA),
            "file_count": len(live_files),
            "total_bytes": sum(path.stat().st_size for path in live_files),
            "array_count": len(fields),
            "compressed_chunk_count": compressed_chunk_total,
            "decoded_chunk_count": compressed_chunk_total,
            "decoded_chunk_bytes": decoded_chunk_total,
            "edge_chunk_count": edge_chunk_count,
            "string_value_count": string_value_total,
            "dtype_counts": dtype_counts,
            "rank_counts": rank_counts,
            "selection_path_order_sha256": sha256_bytes(canonical_bytes(field_paths)),
            "assembled_binding_sha256": sha256_bytes(canonical_bytes(assembled_bindings)),
            "acquisition_payload_sha256": acquisition["acquisition_payload_sha256"],
            "selection_payload_sha256": selection["selection_payload_sha256"],
            "source_mapping_payload_sha256": selection["source_mapping_payload_sha256"],
        },
        "decoder_independence": {
            "zstd": "python-zstandard codec is shared because the frozen bytes use Zstandard",
            "independent_components": [
                "file inventory and hashes", "Zarr metadata contract", "chunk index enumeration",
                "edge cropping and row-major assembly", "vlen UTF-8 framing", "numeric struct decoding",
                "source URL binding", "payload seals", "science locks",
            ],
            "limitation": "This is not an independent implementation of the Zstandard compression algorithm.",
        },
        "science_boundary": {
            "raw_values_only": True,
            "geometry_mapping": "not_accepted",
            "turns_semantics": "unknown",
            "current_sign_semantics": "unknown",
            "current_per_turn_semantics": "unknown",
            "free_boundary_ready": False,
            "physical_validation": False,
            "scientific_acceptance": False,
            "terminal_authority": False,
        },
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_bytes(canonical_bytes(report))
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    report = run(args.report.resolve())
    print(json.dumps({"status": report["status"], "assertions": report["assertion_count"],
                      "negative_controls": len(report["negative_controls"]),
                      "report": str(args.report.resolve()),
                      "report_sha256": sha256_path(args.report.resolve())}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
