"""Verified MAST Level-1 source fields -> generic axisymmetric snapshots.

The adapter is deliberately device-specific only at the raw-data boundary.  Its
output has a device-neutral axisymmetric schema and retains the complete
raw-to-canonical lineage.  It does not interpret EFIT as an independent
measurement, infer uncertainty, or make a likelihood available.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import importlib.machinery
import importlib.util
import json
import math
import os
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from types import MappingProxyType
from typing import Any, Mapping, Sequence

import numpy as np


HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
DEFAULT_PROTOCOL = HERE / "native_axisymmetric_protocol_v2.json"
EXPECTED_PROTOCOL_SHA256 = "9c68cd4f171983dc13df48dbcfe64e84373de1bbe20fd5135286a604ce36d4df"
ADAPTER_VERSION = "native_axisymmetric_source_adapter_v2"
BLOSC_RUNTIME_LOADER_VERSION = "native_blosc_runtime_loader_v1"
EXPECTED_BLOSC_RUNTIME_RELATIVE_PATH = "Library/bin/blosc.dll"
EXPECTED_BLOSC_RUNTIME_SHA256 = (
    "a21580c0c6eb967a9442f4e0559203c99781a530679bd8c7c6c408c4f27c7b11"
)
SNAPSHOT_SCHEMA = "fusionconceptai:generic-axisymmetric-source-snapshot-v1"
SERIES_SCHEMA = "fusionconceptai:native-axisymmetric-source-series-v1"
CLAIM_CEILING = (
    "versioned MAST shot 30421 native source-field preparation for same-source "
    "conditional fixed-boundary solver execution only; independent validation, "
    "calibrated diagnostic response, likelihood, EOS/transport closure, verified "
    "coil geometry, free-boundary prediction, formal inverse acceptance, B03, B07B, "
    "ITER measurement status, and parent UP4-03 completion remain deferred"
)
COCOS_CONSUMED_SUBSET = {
    "source_interpretation": (
        "MAST efm is COCOS 3 in the official OMFIT MAST reader; this is an "
        "upstream software interpretation, not a shot-30421 metadata attestation"
    ),
    "consumed_subset": "psi,pprime,ffprime,Grad-Shafranov operator,and Br/Bz definitions only",
    "source_e_bp": 0,
    "source_sigma_bp": -1,
    "source_sigma_r_phi_z": 1,
    "source_psi_units": "Wb / rad",
    "source_pprime_units": "Pa-rad/Wb",
    "source_ffprime_units": "T-rad",
    "freegs_br_definition": "-dpsi_dz_over_r",
    "freegs_bz_definition": "dpsi_dr_over_r",
    "freegs_jtor_definition": "r_pprime_plus_ffprime_over_mu0_r",
    "freegs_rhs_definition": "minus_mu0_r_jtor",
    "mapping": "identity_no_sign_or_2pi_transform",
    "q_theta_status": "not_consumed_not_verified",
}
PF_CURRENT_PATHS = (
    "amc/p2u_current", "amc/p2l_current", "amc/p3u_current", "amc/p3l_current",
    "amc/p4u_current", "amc/p4l_current", "amc/p5u_current", "amc/p5l_current",
    "amc/p6u_current", "amc/p6l_current",
)
PROFILE_PATHS = (
    "efm/ppsi_c", "efm/fpsi_c", "efm/pprime", "efm/ffprime",
)


class SourceAdapterError(RuntimeError):
    """Typed fail-closed adapter error."""

    def __init__(self, code: str, message: str):
        super().__init__(f"{code}: {message}")
        self.code = code


def _require(condition: bool, code: str, message: str) -> None:
    if not condition:
        raise SourceAdapterError(code, message)


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")


def _canonical_sha256(value: Any) -> str:
    return _sha256_bytes(_canonical_bytes(value))


def _safe_child(root: Path, relative: str, code: str) -> Path:
    _require(isinstance(relative, str) and relative and "\\" not in relative,
             code, f"unsafe relative path {relative!r}")
    pure = PurePosixPath(relative)
    _require(not pure.is_absolute() and ".." not in pure.parts,
             code, f"unsafe relative path {relative!r}")
    root_resolved = root.resolve()
    path = (root_resolved / Path(*pure.parts)).resolve()
    _require(path == root_resolved or root_resolved in path.parents,
             code, f"path escapes source root: {relative!r}")
    return path


def _read_json(path: Path, code: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:  # pragma: no cover - exact parser text is not an API
        raise SourceAdapterError(code, f"cannot parse {path}: {exc}") from exc
    _require(isinstance(value, dict), code, f"{path} must contain a JSON object")
    return value


def _load_protocol(path: Path | str = DEFAULT_PROTOCOL) -> dict[str, Any]:
    protocol_path = Path(path).resolve()
    _require(protocol_path.is_file(), "native_protocol_missing", str(protocol_path))
    actual_hash = _sha256_path(protocol_path)
    _require(actual_hash == EXPECTED_PROTOCOL_SHA256,
             "native_protocol_hash_error",
             f"expected {EXPECTED_PROTOCOL_SHA256}, got {actual_hash}")
    protocol = _read_json(protocol_path, "native_protocol_parse_error")
    canonical = protocol.get("canonical_contract", {})
    forward = protocol.get("forward_contract", {})
    semantics = protocol.get("semantics", {})
    runtime_library = protocol.get("verified_decoder", {}).get("runtime_library", {})
    _require(
        protocol.get("schema") == "fusionconceptai:native-axisymmetric-source-protocol-v2"
        and protocol.get("adapter_version") == ADAPTER_VERSION
        and protocol.get("shot_id") == 30421
        and canonical.get("raw_psirz_dimensions") == ["time", "profile_z", "profile_r"]
        and canonical.get("raw_psirz_shape") == [120, 65, 129]
        and canonical.get("canonical_dimensions") == ["r", "z"]
        and canonical.get("resampling_in_adapter") == "none"
        and canonical.get("imputation") == "none"
        and canonical.get("gridr_status") == "report_only_distinct_array_no_tolerance_substitution"
        and forward.get("generic_device_routing") is True
        and forward.get("device_name_routing") is False
        and forward.get("free_boundary_mode") == "typed_absent_unmapped_coil_geometry"
        and forward.get("cocos_consumed_subset") == COCOS_CONSUMED_SUBSET
        and semantics.get("likelihood_ready") is False
        and semantics.get("formal_acceptance") is False
        and semantics.get("physical_validation") is False
        and semantics.get("engineering_validation") is False
        and semantics.get("claim_ceiling") == CLAIM_CEILING
        and runtime_library == {
            "loader_version": BLOSC_RUNTIME_LOADER_VERSION,
            "path_basis": "sys.base_prefix",
            "relative_path": EXPECTED_BLOSC_RUNTIME_RELATIVE_PATH,
            "sha256": EXPECTED_BLOSC_RUNTIME_SHA256,
            "ctypes_abi": (
                "blosc_init;blosc_cbuffer_validate(void*,size_t,size_t*)->int;"
                "blosc_decompress_ctx(void*,void*,size_t,int)->int;"
                "blosc_compress(int,int,size_t,size_t,void*,void*,size_t)->int"
            ),
        },
        "native_protocol_contract_error",
        "protocol canonical, routing, readiness, or claim contract differs",
    )
    return protocol


def _load_decoder(protocol: Mapping[str, Any]):
    declaration = protocol.get("verified_decoder", {})
    path = _safe_child(REPO_ROOT, declaration.get("relative_path", ""),
                       "native_decoder_path_error")
    _require(path.is_file(), "native_decoder_missing", str(path))
    actual_hash = _sha256_path(path)
    _require(actual_hash == declaration.get("sha256"),
             "native_decoder_hash_error",
             f"expected {declaration.get('sha256')}, got {actual_hash}")
    loader = importlib.machinery.SourceFileLoader(
        "_verified_mast_source_decoder", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    _require(spec is not None and spec.loader is not None,
             "native_decoder_import_error", str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@dataclass(frozen=True)
class DecoderRuntimeIdentity:
    loader_version: str
    python_executable: str
    sys_prefix: str
    sys_base_prefix: str
    base_prefix_differs_from_prefix: bool
    path_basis: str
    library_path: str
    library_sha256: str
    ctypes_abi: str


def _decoder_runtime_identity(identity: DecoderRuntimeIdentity) -> dict[str, Any]:
    return {
        "loader_version": identity.loader_version,
        "python_executable": identity.python_executable,
        "sys_prefix": identity.sys_prefix,
        "sys_base_prefix": identity.sys_base_prefix,
        "base_prefix_differs_from_prefix": identity.base_prefix_differs_from_prefix,
        "path_basis": identity.path_basis,
        "library_path": identity.library_path,
        "library_sha256": identity.library_sha256,
        "ctypes_abi": identity.ctypes_abi,
    }


def _resolve_verified_blosc_runtime(
    protocol: Mapping[str, Any],
    *,
    executable: Path | str | None = None,
    prefix: Path | str | None = None,
    base_prefix: Path | str | None = None,
) -> DecoderRuntimeIdentity:
    """Resolve the pinned Blosc DLL from the interpreter's base runtime."""
    declaration = protocol.get("verified_decoder", {}).get("runtime_library", {})
    _require(
        declaration.get("loader_version") == BLOSC_RUNTIME_LOADER_VERSION
        and declaration.get("path_basis") == "sys.base_prefix"
        and declaration.get("relative_path") == EXPECTED_BLOSC_RUNTIME_RELATIVE_PATH
        and declaration.get("sha256") == EXPECTED_BLOSC_RUNTIME_SHA256,
        "native_blosc_runtime_contract_error",
        "runtime library resolution contract differs",
    )
    executable_path = Path(sys.executable if executable is None else executable).resolve()
    prefix_path = Path(sys.prefix if prefix is None else prefix).resolve()
    base_path = Path(sys.base_prefix if base_prefix is None else base_prefix).resolve()
    _require(executable_path.is_file(), "native_blosc_runtime_executable_missing",
             str(executable_path))
    _require(base_path.is_dir(), "native_blosc_runtime_base_prefix_missing",
             str(base_path))
    library_path = _safe_child(
        base_path, declaration["relative_path"], "native_blosc_runtime_path_error")
    _require(library_path.is_file(), "native_blosc_runtime_missing", str(library_path))
    library_hash = _sha256_path(library_path)
    _require(library_hash == declaration["sha256"],
             "native_blosc_runtime_hash_error",
             f"expected {declaration['sha256']}, got {library_hash}")
    return DecoderRuntimeIdentity(
        loader_version=BLOSC_RUNTIME_LOADER_VERSION,
        python_executable=str(executable_path),
        sys_prefix=str(prefix_path),
        sys_base_prefix=str(base_path),
        base_prefix_differs_from_prefix=base_path != prefix_path,
        path_basis="sys.base_prefix",
        library_path=str(library_path),
        library_sha256=library_hash,
        ctypes_abi=declaration["ctypes_abi"],
    )


def _load_verified_blosc(
    protocol: Mapping[str, Any],
) -> tuple[Any, Any, DecoderRuntimeIdentity]:
    """Load only the protocol-pinned runtime library and configure its exact ABI."""
    identity = _resolve_verified_blosc_runtime(protocol)
    library_path = Path(identity.library_path)
    dll_handle = None
    try:
        if hasattr(os, "add_dll_directory"):
            dll_handle = os.add_dll_directory(str(library_path.parent))
        library = ctypes.CDLL(str(library_path))
        library.blosc_init.argtypes = []
        library.blosc_init.restype = None
        library.blosc_init()
        library.blosc_cbuffer_validate.argtypes = [
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.POINTER(ctypes.c_size_t),
        ]
        library.blosc_cbuffer_validate.restype = ctypes.c_int
        library.blosc_decompress_ctx.argtypes = [
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_int,
        ]
        library.blosc_decompress_ctx.restype = ctypes.c_int
        library.blosc_compress.argtypes = [
            ctypes.c_int,
            ctypes.c_int,
            ctypes.c_size_t,
            ctypes.c_size_t,
            ctypes.c_void_p,
            ctypes.c_void_p,
            ctypes.c_size_t,
        ]
        library.blosc_compress.restype = ctypes.c_int
    except Exception as exc:
        if dll_handle is not None:
            dll_handle.close()
        raise SourceAdapterError(
            "native_blosc_runtime_load_error",
            f"cannot load configured runtime {library_path}: {exc}",
        ) from exc
    return library, dll_handle, identity


@dataclass(frozen=True)
class VerifiedSourceArray:
    requested_path: str
    resolved_path: str
    package: str
    shape: tuple[int, ...]
    chunks: tuple[int, ...]
    dtype: str
    dimensions: tuple[str, ...]
    units: str | None
    assembled_raw_sha256: str
    compressed_sha256: tuple[str, ...]
    decoded_sha256: tuple[str, ...]


@dataclass(frozen=True)
class NativeAxisymmetricSeries:
    shot_id: int
    protocol_sha256: str
    source_package_sha256: tuple[tuple[str, str], ...]
    arrays: Mapping[str, np.ndarray]
    source_records: tuple[VerifiedSourceArray, ...]
    decoder_runtime: DecoderRuntimeIdentity
    source_binding_sha256: str
    series_payload_sha256: str
    coil_geometry_status: str
    uncertainty_status: str
    likelihood_ready: bool
    claim_ceiling: str


@dataclass(frozen=True)
class NativeAxisymmetricSnapshot:
    shot_id: int
    efm_time_index: int
    efm_time_s: float
    amc_time_index: int
    amc_time_s: float
    amc_signed_delta_s: float
    amc_max_delta_s: float
    r_m: np.ndarray
    z_m: np.ndarray
    psi_wb_per_rad: np.ndarray
    psi_norm: np.ndarray
    pressure_pa: np.ndarray
    f_tm: np.ndarray
    pprime_pa_rad_per_wb: np.ndarray
    ffprime_t_rad: np.ndarray
    psi_axis_wb_per_rad: float
    psi_boundary_wb_per_rad: float
    magnetic_axis_m: tuple[float, float]
    lcfs_r_m: np.ndarray
    lcfs_z_m: np.ndarray
    xpoints_m: tuple[tuple[str, float, float], ...]
    vacuum_f_tm: float
    plasma_current_a: float
    internal_pf_currents_a_turn: tuple[tuple[str, float], ...]
    fitted_input_currents_a: np.ndarray
    source_binding_sha256: str
    source_series_payload_sha256: str
    snapshot_payload_sha256: str
    coil_geometry_status: str
    uncertainty_status: str
    likelihood_ready: bool
    formal_acceptance: bool
    claim_ceiling: str


def _record_identity(record: VerifiedSourceArray) -> dict[str, Any]:
    return {
        "requested_path": record.requested_path,
        "resolved_path": record.resolved_path,
        "package": record.package,
        "shape": list(record.shape),
        "chunks": list(record.chunks),
        "dtype": record.dtype,
        "dimensions": list(record.dimensions),
        "units": record.units,
        "assembled_raw_sha256": record.assembled_raw_sha256,
        "compressed_sha256": list(record.compressed_sha256),
        "decoded_sha256": list(record.decoded_sha256),
    }


def _verify_package(
    package_name: str,
    declaration: Mapping[str, Any],
    protocol: Mapping[str, Any],
    decoder: Any,
    override_root: Path | None,
) -> tuple[dict[str, np.ndarray], tuple[VerifiedSourceArray, ...], str]:
    root = override_root.resolve() if override_root is not None else _safe_child(
        REPO_ROOT, declaration.get("relative_directory", ""),
        "native_source_root_error")
    _require(root.is_dir(), "native_source_root_missing", str(root))
    named_files = {
        "acquisition.json": declaration.get("acquisition_sha256"),
        "selection.json": declaration.get("selection_sha256"),
        "zmetadata.json": declaration.get("zmetadata_sha256"),
        "fetch_mast_source_fields_v1.py.copy": declaration.get("producer_snapshot_sha256"),
    }
    for name, expected in named_files.items():
        path = root / name
        _require(path.is_file(), "native_source_file_missing", str(path))
        actual = _sha256_path(path)
        _require(actual == expected, "native_source_file_hash_error",
                 f"{package_name}/{name}: expected {expected}, got {actual}")

    acquisition = _read_json(root / "acquisition.json", "native_acquisition_parse_error")
    selection = _read_json(root / "selection.json", "native_selection_parse_error")
    zmetadata = _read_json(root / "zmetadata.json", "native_zmetadata_parse_error")
    _require(
        acquisition.get("schema") == "mast-source-fields-acquisition-receipt-v1"
        and acquisition.get("shot") == 30421
        and acquisition.get("status") == "success"
        and acquisition.get("exit_code") == 0
        and acquisition.get("failures") == []
        and acquisition.get("raw_values_only") is True
        and acquisition.get("likelihood_ready") is False
        and acquisition.get("scientific_acceptance") is False
        and acquisition.get("metadata_sha256") == declaration.get("zmetadata_sha256")
        and acquisition.get("selection_sha256") == declaration.get("selection_sha256")
        and acquisition.get("script_sha256") == declaration.get("producer_snapshot_sha256")
        and selection.get("schema") == "mast-source-fields-selection-v1"
        and selection.get("shot") == 30421
        and selection.get("metadata_sha256") == declaration.get("zmetadata_sha256")
        and selection.get("raw_values_only") is True
        and selection.get("scientific_acceptance") is False,
        "native_acquisition_contract_error",
        f"{package_name}: acquisition/selection contract differs",
    )
    metadata = zmetadata.get("metadata")
    _require(isinstance(metadata, dict), "native_zmetadata_contract_error",
             f"{package_name}: consolidated metadata missing")

    expected_paths = declaration.get("array_paths")
    records = acquisition.get("arrays")
    _require(
        isinstance(records, list)
        and [item.get("requested_path") for item in records] == expected_paths,
        "native_array_set_error", f"{package_name}: acquired array set/order differs",
    )
    selection_records = selection.get("requested_fields")
    _require(
        isinstance(selection_records, list)
        and [item.get("requested_path") for item in selection_records] == expected_paths,
        "native_selection_array_set_error",
        f"{package_name}: selected array set/order differs",
    )

    library, dll_handle, _ = _load_verified_blosc(protocol)
    values: dict[str, np.ndarray] = {}
    identities: list[VerifiedSourceArray] = []
    try:
        for record, selected in zip(records, selection_records):
            requested = record.get("requested_path")
            contract = protocol.get("array_contracts", {}).get(requested)
            _require(isinstance(contract, dict) and contract.get("package") == package_name,
                     "native_array_contract_missing", str(requested))
            resolved = record.get("resolved_path")
            _require(
                selected == {key: record[key] for key in selected}
                and selected.get("resolved_path") == resolved
                and contract.get("resolved_path") == resolved
                and record.get("status") == "acquired_raw_values_no_uncertainty_interpretation"
                and record.get("failures") == []
                and record.get("zarray") == metadata.get(f"{resolved}/.zarray")
                and record.get("attributes") == metadata.get(f"{resolved}/.zattrs")
                and record.get("shape") == contract.get("shape")
                and record.get("chunks") == contract.get("chunks")
                and record.get("dtype") == contract.get("dtype")
                and record.get("dimensions") == contract.get("dimensions")
                and record.get("zarray", {}).get("order") == contract.get("order") == "C"
                and record.get("attributes", {}).get("units") == contract.get("units")
                and record.get("assembled_raw_bytes") == contract.get("assembled_raw_bytes")
                and record.get("assembled_raw_sha256") == contract.get("assembled_raw_sha256"),
                "native_array_metadata_error",
                f"{requested}: selection/acquisition/zmetadata/protocol mismatch",
            )
            shape = tuple(int(x) for x in record["shape"])
            chunks = tuple(int(x) for x in record["chunks"])
            dtype = np.dtype(record["dtype"])
            _require(dtype.str in ("<f4", "<f8") and len(shape) == len(chunks),
                     "native_array_dtype_shape_error", str(requested))
            field_dir = _safe_child(root, f"fields/{resolved.replace('/', '__')}",
                                    "native_array_path_error")
            metadata_path = field_dir / "field_metadata.json"
            _require(metadata_path.is_file()
                     and _read_json(metadata_path, "native_field_metadata_parse_error") == record,
                     "native_field_metadata_error", str(requested))
            assembled_relative = record.get("assembled_raw_path")
            expected_relative = f"fields/{resolved.replace('/', '__')}/assembled.raw"
            _require(str(assembled_relative).replace("\\", "/") == expected_relative,
                     "native_array_path_error", str(requested))
            assembled_path = _safe_child(root, expected_relative, "native_array_path_error")
            assembled_bytes = assembled_path.read_bytes()
            _require(
                len(assembled_bytes) == int(np.prod(shape, dtype=np.int64)) * dtype.itemsize
                and _sha256_bytes(assembled_bytes) == contract["assembled_raw_sha256"],
                "native_assembled_raw_error", str(requested),
            )
            reconstructed = np.empty(shape, dtype=dtype, order="C")
            compressed_hashes: list[str] = []
            decoded_hashes: list[str] = []
            chunk_records = record.get("chunks_acquired")
            _require(isinstance(chunk_records, list) and chunk_records,
                     "native_chunk_set_error", str(requested))
            covered = np.zeros(shape, dtype=np.bool_)
            for chunk in chunk_records:
                starts = tuple(int(x) for x in chunk.get("chunk_start", []))
                edge_shape = tuple(int(x) for x in chunk.get("edge_shape", []))
                full_shape = tuple(int(x) for x in chunk.get("full_chunk_shape", []))
                _require(
                    len(starts) == len(shape) and len(edge_shape) == len(shape)
                    and full_shape == chunks and chunk.get("status") == "decoded",
                    "native_chunk_metadata_error", str(requested),
                )
                compressed_path = _safe_child(
                    field_dir, str(chunk.get("compressed_path", "")).replace("\\", "/"),
                    "native_chunk_path_error")
                decoded_path = _safe_child(
                    field_dir, str(chunk.get("decoded_chunk_path", "")).replace("\\", "/"),
                    "native_chunk_path_error")
                compressed = compressed_path.read_bytes()
                decoded_on_disk = decoded_path.read_bytes()
                _require(
                    len(compressed) == chunk.get("compressed_bytes")
                    and _sha256_bytes(compressed) == chunk.get("compressed_sha256"),
                    "native_compressed_chunk_error", f"{requested}/{chunk.get('chunk_index')}",
                )
                raw, decoded_array, decoded_shape, full_bytes, edge_bytes = decoder.decode_chunk(
                    library, compressed, dtype, full_shape, edge_shape)
                _require(
                    raw == decoded_on_disk
                    and _sha256_bytes(raw) == chunk.get("decoded_sha256")
                    and len(raw) == chunk.get("decoded_bytes")
                    and tuple(decoded_shape) == tuple(chunk.get("decoded_shape", []))
                    and full_bytes == chunk.get("expected_full_bytes")
                    and edge_bytes == chunk.get("expected_edge_bytes"),
                    "native_decoded_chunk_error", f"{requested}/{chunk.get('chunk_index')}",
                )
                write_array = decoded_array
                if tuple(decoded_shape) == full_shape and full_shape != edge_shape:
                    write_array = decoded_array[tuple(slice(0, n) for n in edge_shape)]
                _require(tuple(write_array.shape) == tuple(chunk.get("written_shape", [])),
                         "native_chunk_written_shape_error", str(requested))
                slices = tuple(slice(starts[i], starts[i] + edge_shape[i])
                               for i in range(len(shape)))
                _require(not bool(np.any(covered[slices])),
                         "native_chunk_overlap_error", str(requested))
                reconstructed[slices] = write_array
                covered[slices] = True
                compressed_hashes.append(chunk["compressed_sha256"])
                decoded_hashes.append(chunk["decoded_sha256"])
            _require(bool(np.all(covered)) and reconstructed.tobytes(order="C") == assembled_bytes,
                     "native_chunk_assembly_error", str(requested))
            array = np.frombuffer(assembled_bytes, dtype=dtype).reshape(shape, order="C")
            _require(array.flags.c_contiguous and not array.flags.writeable,
                     "native_array_memory_contract_error", str(requested))
            values[requested] = array
            identities.append(VerifiedSourceArray(
                requested_path=requested, resolved_path=resolved, package=package_name,
                shape=shape, chunks=chunks, dtype=dtype.str,
                dimensions=tuple(record["dimensions"]), units=contract.get("units"),
                assembled_raw_sha256=contract["assembled_raw_sha256"],
                compressed_sha256=tuple(compressed_hashes),
                decoded_sha256=tuple(decoded_hashes),
            ))
    finally:
        if dll_handle is not None:
            dll_handle.close()
    return values, tuple(identities), declaration["acquisition_sha256"]


def _series_body(series: NativeAxisymmetricSeries) -> dict[str, Any]:
    return {
        "schema": SERIES_SCHEMA,
        "adapter_version": ADAPTER_VERSION,
        "shot_id": series.shot_id,
        "protocol_sha256": series.protocol_sha256,
        "source_package_sha256": [list(x) for x in series.source_package_sha256],
        "source_records": [_record_identity(x) for x in series.source_records],
        "decoder_runtime": _decoder_runtime_identity(series.decoder_runtime),
        "source_binding_sha256": series.source_binding_sha256,
        "coil_geometry_status": series.coil_geometry_status,
        "uncertainty_status": series.uncertainty_status,
        "likelihood_ready": series.likelihood_ready,
        "claim_ceiling": series.claim_ceiling,
    }


def _array_bytes_sha256(array: np.ndarray) -> str:
    return _sha256_bytes(array.tobytes(order="C"))


def _expected_source_record_identities(
    protocol: Mapping[str, Any],
) -> dict[str, dict[str, Any]]:
    expected: dict[str, dict[str, Any]] = {}
    for package_name in ("primary", "supplement"):
        declaration = protocol["source_packages"][package_name]
        root = _safe_child(REPO_ROOT, declaration["relative_directory"],
                           "native_source_root_error")
        acquisition_path = root / "acquisition.json"
        _require(_sha256_path(acquisition_path) == declaration["acquisition_sha256"],
                 "native_source_file_hash_error",
                 f"{package_name}/acquisition.json changed")
        acquisition = _read_json(acquisition_path, "native_acquisition_parse_error")
        for item in acquisition.get("arrays", []):
            name = item.get("requested_path")
            contract = protocol["array_contracts"].get(name)
            _require(isinstance(contract, dict) and contract.get("package") == package_name,
                     "native_array_contract_missing", str(name))
            record = VerifiedSourceArray(
                requested_path=name, resolved_path=item["resolved_path"],
                package=package_name, shape=tuple(item["shape"]),
                chunks=tuple(item["chunks"]), dtype=item["dtype"],
                dimensions=tuple(item["dimensions"]),
                units=item.get("attributes", {}).get("units"),
                assembled_raw_sha256=item["assembled_raw_sha256"],
                compressed_sha256=tuple(
                    chunk["compressed_sha256"] for chunk in item["chunks_acquired"]),
                decoded_sha256=tuple(
                    chunk["decoded_sha256"] for chunk in item["chunks_acquired"]),
            )
            expected[name] = _record_identity(record)
    return expected


def validate_native_axisymmetric_series(series: NativeAxisymmetricSeries) -> dict[str, Any]:
    protocol = _load_protocol()
    decoder_runtime = _resolve_verified_blosc_runtime(protocol)
    expected_contracts = protocol["array_contracts"]
    expected_records = _expected_source_record_identities(protocol)
    _require(
        series.shot_id == 30421
        and series.protocol_sha256 == EXPECTED_PROTOCOL_SHA256
        and series.decoder_runtime == decoder_runtime
        and series.coil_geometry_status == "typed_absent_from_bound_source_protocol"
        and series.uncertainty_status == "typed_absent_for_source_field_likelihood"
        and series.likelihood_ready is False
        and series.claim_ceiling == CLAIM_CEILING,
        "native_series_metadata_error", "series readiness or claim metadata differs",
    )
    _require(isinstance(series.arrays, Mapping), "native_series_array_map_error",
             "arrays must be a mapping")
    _require(set(series.arrays) == set(expected_contracts)
             and len(series.source_records) == len(expected_contracts),
             "native_series_array_set_error", "series array set differs")
    _require(series.source_package_sha256 == tuple(
        (name, protocol["source_packages"][name]["acquisition_sha256"])
        for name in ("primary", "supplement")),
        "native_series_source_package_error", "source package identities differ")
    by_name = {record.requested_path: record for record in series.source_records}
    _require(set(by_name) == set(expected_contracts),
             "native_series_source_record_error", "source records differ")
    for name, contract in expected_contracts.items():
        record = by_name[name]
        array = series.arrays[name]
        _require(
            isinstance(array, np.ndarray)
            and tuple(array.shape) == tuple(contract["shape"])
            and array.dtype.str == contract["dtype"]
            and array.flags.c_contiguous and not array.flags.writeable
            and _array_bytes_sha256(array) == contract["assembled_raw_sha256"]
            and _record_identity(record) == expected_records[name],
            "native_series_live_source_binding_error", name,
        )
    expected_binding = _canonical_sha256({
        "protocol_sha256": EXPECTED_PROTOCOL_SHA256,
        "source_package_sha256": [list(x) for x in series.source_package_sha256],
        "source_records": [_record_identity(x) for x in series.source_records],
    })
    _require(series.source_binding_sha256 == expected_binding,
             "native_series_source_binding_hash_error", "source binding hash differs")
    expected_payload = _canonical_sha256(_series_body(series))
    _require(series.series_payload_sha256 == expected_payload,
             "native_series_payload_hash_error", "series payload hash differs")

    arrays = series.arrays
    support = np.asarray(protocol["canonical_contract"]["radial_support_indices"], dtype=np.int64)
    mask = np.isfinite(arrays["efm/psirz"])
    reference = np.zeros(129, dtype=np.bool_)
    reference[support] = True
    _require(mask.shape == (120, 65, 129)
             and bool(np.all(mask[:, :, support]))
             and not bool(np.any(mask[:, :, ~reference])),
             "native_psirz_support_error", "psirz finite support differs")
    _require(np.array_equal(arrays["efm/r"], arrays["efm/profile_r"][support]),
             "native_r_coordinate_identity_error", "efm/r is not the exact psirz support")
    _require(np.array_equal(arrays["efm/z"], arrays["efm/profile_z"]),
             "native_z_coordinate_identity_error", "efm/z and profile_z differ")
    _require(np.array_equal(arrays["efm/gridz"], arrays["efm/z"]),
             "native_gridz_identity_error", "gridz and z differ")
    gridr_delta = float(np.max(np.abs(
        arrays["efm/gridr"].astype(np.float64) - arrays["efm/r"].astype(np.float64))))
    expected_delta = protocol["canonical_contract"]["observed_gridr_max_abs_delta_from_r_m"]
    _require(gridr_delta == expected_delta,
             "native_gridr_observed_delta_error",
             f"expected observed delta {expected_delta}, got {gridr_delta}")
    return {
        "status": "verified_native_axisymmetric_series",
        "array_count": len(arrays),
        "psirz_finite_count": int(mask.sum()),
        "radial_support_count": int(support.size),
        "gridr_max_abs_delta_from_r_m": gridr_delta,
        "source_binding_sha256": expected_binding,
        "series_payload_sha256": expected_payload,
        "decoder_runtime": _decoder_runtime_identity(decoder_runtime),
        "likelihood_ready": False,
        "claim_ceiling": CLAIM_CEILING,
    }


def load_native_axisymmetric_series(
    protocol_path: Path | str = DEFAULT_PROTOCOL,
    *,
    primary_root: Path | str | None = None,
    supplement_root: Path | str | None = None,
) -> NativeAxisymmetricSeries:
    protocol = _load_protocol(protocol_path)
    decoder = _load_decoder(protocol)
    decoder_runtime = _resolve_verified_blosc_runtime(protocol)
    overrides = {
        "primary": None if primary_root is None else Path(primary_root),
        "supplement": None if supplement_root is None else Path(supplement_root),
    }
    arrays: dict[str, np.ndarray] = {}
    records: list[VerifiedSourceArray] = []
    package_hashes: list[tuple[str, str]] = []
    for package_name in ("primary", "supplement"):
        package_arrays, package_records, package_hash = _verify_package(
            package_name, protocol["source_packages"][package_name], protocol,
            decoder, overrides[package_name])
        overlap = set(arrays).intersection(package_arrays)
        _require(not overlap, "native_source_package_overlap_error", str(sorted(overlap)))
        arrays.update(package_arrays)
        records.extend(package_records)
        package_hashes.append((package_name, package_hash))
    records_tuple = tuple(records)
    package_tuple = tuple(package_hashes)
    binding = _canonical_sha256({
        "protocol_sha256": EXPECTED_PROTOCOL_SHA256,
        "source_package_sha256": [list(x) for x in package_tuple],
        "source_records": [_record_identity(x) for x in records_tuple],
    })
    provisional = NativeAxisymmetricSeries(
        shot_id=30421, protocol_sha256=EXPECTED_PROTOCOL_SHA256,
        source_package_sha256=package_tuple,
        arrays=MappingProxyType(arrays), source_records=records_tuple,
        decoder_runtime=decoder_runtime,
        source_binding_sha256=binding, series_payload_sha256="",
        coil_geometry_status="typed_absent_from_bound_source_protocol",
        uncertainty_status="typed_absent_for_source_field_likelihood",
        likelihood_ready=False, claim_ceiling=CLAIM_CEILING,
    )
    payload = _canonical_sha256(_series_body(provisional))
    series = NativeAxisymmetricSeries(**{
        **provisional.__dict__, "series_payload_sha256": payload,
    })
    validate_native_axisymmetric_series(series)
    return series


def _readonly_copy(value: np.ndarray, dtype: np.dtype | type = np.float64) -> np.ndarray:
    result = np.ascontiguousarray(value, dtype=dtype)
    result.setflags(write=False)
    return result


def _finite_scalar(value: Any, code: str, label: str) -> float:
    _require(not isinstance(value, (bool, np.bool_)), code, f"{label} cannot be boolean")
    result = float(value)
    _require(math.isfinite(result), code, f"{label} must be finite")
    return result


def _nearest_index(values: np.ndarray, target: float) -> int:
    _require(values.ndim == 1 and values.size > 0 and bool(np.isfinite(values).all()),
             "native_alignment_timebase_error", "alignment timebase must be finite 1D")
    return int(np.argmin(np.abs(values.astype(np.float64) - target)))


def _snapshot_body(snapshot: NativeAxisymmetricSnapshot) -> dict[str, Any]:
    def array_entry(value: np.ndarray, units: str, dimensions: Sequence[str]) -> dict[str, Any]:
        return {
            "dimensions": list(dimensions), "units": units,
            "shape": list(value.shape), "dtype": value.dtype.str,
            "values_sha256": _array_bytes_sha256(value),
            "values": value.tolist(),
        }
    return {
        "schema": SNAPSHOT_SCHEMA,
        "adapter_version": ADAPTER_VERSION,
        "shot_id": snapshot.shot_id,
        "efm_time_index": snapshot.efm_time_index,
        "efm_time_s": snapshot.efm_time_s,
        "amc_alignment": {
            "policy": "nearest_explicit_bound", "index": snapshot.amc_time_index,
            "time_s": snapshot.amc_time_s, "signed_delta_s": snapshot.amc_signed_delta_s,
            "caller_max_delta_s": snapshot.amc_max_delta_s,
        },
        "canonical_dimensions": ["r", "z"],
        "raw_to_canonical": {
            "raw_dimensions": ["time", "profile_z", "profile_r"],
            "operation": "select explicit time/support then transpose z,r to r,z",
        },
        "cocos_consumed_subset": COCOS_CONSUMED_SUBSET,
        "arrays": {
            "r_m": array_entry(snapshot.r_m, "m", ["r"]),
            "z_m": array_entry(snapshot.z_m, "m", ["z"]),
            "psi_wb_per_rad": array_entry(snapshot.psi_wb_per_rad, "Wb / rad", ["r", "z"]),
            "psi_norm": array_entry(snapshot.psi_norm, "1", ["psi_norm"]),
            "pressure_pa": array_entry(snapshot.pressure_pa, "Pa", ["psi_norm"]),
            "f_tm": array_entry(snapshot.f_tm, "T-m", ["psi_norm"]),
            "pprime_pa_rad_per_wb": array_entry(snapshot.pprime_pa_rad_per_wb, "Pa-rad/Wb", ["psi_norm"]),
            "ffprime_t_rad": array_entry(snapshot.ffprime_t_rad, "T-rad", ["psi_norm"]),
            "lcfs_r_m": array_entry(snapshot.lcfs_r_m, "m", ["lcfs_point"]),
            "lcfs_z_m": array_entry(snapshot.lcfs_z_m, "m", ["lcfs_point"]),
            "fitted_input_currents_a": array_entry(snapshot.fitted_input_currents_a, "A", ["fcoil_n"]),
        },
        "scalars": {
            "psi_axis_wb_per_rad": snapshot.psi_axis_wb_per_rad,
            "psi_boundary_wb_per_rad": snapshot.psi_boundary_wb_per_rad,
            "magnetic_axis_m": list(snapshot.magnetic_axis_m),
            "xpoints_m": [list(x) for x in snapshot.xpoints_m],
            "vacuum_f_tm": snapshot.vacuum_f_tm,
            "plasma_current_a": snapshot.plasma_current_a,
            "internal_pf_currents_a_turn": [list(x) for x in snapshot.internal_pf_currents_a_turn],
        },
        "source_binding_sha256": snapshot.source_binding_sha256,
        "source_series_payload_sha256": snapshot.source_series_payload_sha256,
        "coil_geometry_status": snapshot.coil_geometry_status,
        "uncertainty_status": snapshot.uncertainty_status,
        "likelihood_ready": snapshot.likelihood_ready,
        "formal_acceptance": snapshot.formal_acceptance,
        "claim_ceiling": snapshot.claim_ceiling,
    }


def _build_native_axisymmetric_snapshot(
    series: NativeAxisymmetricSeries,
    efm_time_index: int,
    *,
    amc_max_delta_s: float,
) -> NativeAxisymmetricSnapshot:
    validate_native_axisymmetric_series(series)
    protocol = _load_protocol()
    _require(isinstance(efm_time_index, int) and not isinstance(efm_time_index, bool),
             "native_snapshot_time_index_error", "efm_time_index must be an integer")
    allowed = protocol["canonical_contract"]["loadable_profile_time_indices"]
    _require(efm_time_index in allowed, "native_snapshot_time_index_error",
             f"index {efm_time_index} is outside finite profile rows")
    maximum = _finite_scalar(amc_max_delta_s, "native_amc_alignment_bound_error",
                             "amc_max_delta_s")
    _require(maximum > 0, "native_amc_alignment_bound_error",
             "amc_max_delta_s must be positive")
    arrays = series.arrays
    target_time = float(arrays["efm/time"][efm_time_index])
    amc_index = _nearest_index(arrays["amc/time"], target_time)
    amc_time = float(arrays["amc/time"][amc_index])
    signed_delta = amc_time - target_time
    _require(abs(signed_delta) <= maximum, "native_amc_alignment_error",
             f"nearest AMC delta {signed_delta} exceeds {maximum}")
    support = np.asarray(protocol["canonical_contract"]["radial_support_indices"], dtype=np.int64)
    raw_psi_zr = arrays["efm/psirz"][efm_time_index, :, support]
    psi_rz = _readonly_copy(np.transpose(raw_psi_zr, (1, 0)))
    r_m = _readonly_copy(arrays["efm/r"])
    z_m = _readonly_copy(arrays["efm/z"])
    profiles = [_readonly_copy(arrays[path][efm_time_index, :]) for path in PROFILE_PATHS]
    _require(all(bool(np.isfinite(x).all()) for x in (psi_rz, *profiles)),
             "native_snapshot_nonfinite_core_error", "psi/profile core contains nonfinite values")
    lcfs_mask = (np.isfinite(arrays["efm/lcfs_r"][efm_time_index])
                 & np.isfinite(arrays["efm/lcfs_z"][efm_time_index]))
    _require(bool(np.any(lcfs_mask)), "native_snapshot_lcfs_absent", "no finite LCFS pairs")
    lcfs_r = _readonly_copy(arrays["efm/lcfs_r"][efm_time_index, lcfs_mask])
    lcfs_z = _readonly_copy(arrays["efm/lcfs_z"][efm_time_index, lcfs_mask])
    xpoints: list[tuple[str, float, float]] = []
    for label in ("xpoint1", "xpoint2"):
        r_value = float(arrays[f"efm/{label}_rc"][efm_time_index])
        z_value = float(arrays[f"efm/{label}_zc"][efm_time_index])
        if math.isfinite(r_value) and math.isfinite(z_value):
            xpoints.append((label, r_value, z_value))
        else:
            _require(not math.isfinite(r_value) and not math.isfinite(z_value),
                     "native_snapshot_xpoint_pair_error", f"{label} is half-present")
    pf_currents = tuple((path.removeprefix("amc/").removesuffix("_current"),
                         float(arrays[path][amc_index]) * 1000.0)
                        for path in PF_CURRENT_PATHS)
    fitted = _readonly_copy(arrays["efm/fcoil_x"][efm_time_index, :])
    provisional = NativeAxisymmetricSnapshot(
        shot_id=series.shot_id, efm_time_index=efm_time_index,
        efm_time_s=target_time, amc_time_index=amc_index, amc_time_s=amc_time,
        amc_signed_delta_s=signed_delta, amc_max_delta_s=maximum,
        r_m=r_m, z_m=z_m, psi_wb_per_rad=psi_rz,
        psi_norm=_readonly_copy(arrays["efm/psi_norm"]),
        pressure_pa=profiles[0], f_tm=profiles[1],
        pprime_pa_rad_per_wb=profiles[2], ffprime_t_rad=profiles[3],
        psi_axis_wb_per_rad=float(arrays["efm/psi_axis"][efm_time_index]),
        psi_boundary_wb_per_rad=float(arrays["efm/psi_boundary"][efm_time_index]),
        magnetic_axis_m=(float(arrays["efm/magnetic_axis_r"][efm_time_index]),
                         float(arrays["efm/magnetic_axis_z"][efm_time_index])),
        lcfs_r_m=lcfs_r, lcfs_z_m=lcfs_z, xpoints_m=tuple(xpoints),
        vacuum_f_tm=float(arrays["efm/bvac_r"][efm_time_index]
                          * arrays["efm/bvac_val"][efm_time_index]),
        plasma_current_a=float(arrays["efm/plasma_current_x"][efm_time_index]),
        internal_pf_currents_a_turn=pf_currents,
        fitted_input_currents_a=fitted,
        source_binding_sha256=series.source_binding_sha256,
        source_series_payload_sha256=series.series_payload_sha256,
        snapshot_payload_sha256="",
        coil_geometry_status="typed_absent_from_bound_source_protocol",
        uncertainty_status="typed_absent_for_source_field_likelihood",
        likelihood_ready=False, formal_acceptance=False, claim_ceiling=CLAIM_CEILING,
    )
    payload = _canonical_sha256(_snapshot_body(provisional))
    snapshot = NativeAxisymmetricSnapshot(**{
        **provisional.__dict__, "snapshot_payload_sha256": payload,
    })
    return snapshot


def snapshot_native_axisymmetric(
    series: NativeAxisymmetricSeries,
    efm_time_index: int,
    *,
    amc_max_delta_s: float,
) -> NativeAxisymmetricSnapshot:
    snapshot = _build_native_axisymmetric_snapshot(
        series, efm_time_index, amc_max_delta_s=amc_max_delta_s)
    validate_native_axisymmetric_snapshot(snapshot, series)
    return snapshot


def validate_native_axisymmetric_snapshot(
    snapshot: NativeAxisymmetricSnapshot,
    series: NativeAxisymmetricSeries,
) -> dict[str, Any]:
    validate_native_axisymmetric_series(series)
    _require(
        snapshot.shot_id == series.shot_id
        and snapshot.source_binding_sha256 == series.source_binding_sha256
        and snapshot.source_series_payload_sha256 == series.series_payload_sha256
        and snapshot.coil_geometry_status == "typed_absent_from_bound_source_protocol"
        and snapshot.uncertainty_status == "typed_absent_for_source_field_likelihood"
        and snapshot.likelihood_ready is False
        and snapshot.formal_acceptance is False
        and snapshot.claim_ceiling == CLAIM_CEILING,
        "native_snapshot_metadata_error", "snapshot readiness, source, or claim differs",
    )
    expected = _build_native_axisymmetric_snapshot(
        series, snapshot.efm_time_index, amc_max_delta_s=snapshot.amc_max_delta_s)
    expected_body = _snapshot_body(expected)
    actual_body = _snapshot_body(snapshot)
    _require(actual_body == expected_body,
             "native_snapshot_live_source_binding_error",
             "snapshot values or alignment differ from the verified series")
    expected_hash = _canonical_sha256(actual_body)
    _require(snapshot.snapshot_payload_sha256 == expected_hash,
             "native_snapshot_payload_hash_error", "snapshot payload hash differs")
    return {
        "status": "verified_native_axisymmetric_snapshot",
        "shot_id": snapshot.shot_id,
        "efm_time_index": snapshot.efm_time_index,
        "efm_time_s": snapshot.efm_time_s,
        "amc_time_index": snapshot.amc_time_index,
        "amc_signed_delta_s": snapshot.amc_signed_delta_s,
        "radial_count": int(snapshot.r_m.size),
        "vertical_count": int(snapshot.z_m.size),
        "lcfs_point_count": int(snapshot.lcfs_r_m.size),
        "xpoint_count": len(snapshot.xpoints_m),
        "snapshot_payload_sha256": expected_hash,
        "likelihood_ready": False,
        "formal_acceptance": False,
        "claim_ceiling": CLAIM_CEILING,
    }


def require_native_likelihood_ready(_snapshot: NativeAxisymmetricSnapshot) -> None:
    raise SourceAdapterError(
        "native_likelihood_not_ready",
        "source-field uncertainty, EOS/transport response, and likelihood semantics are absent",
    )


def write_native_axisymmetric_snapshot(
    snapshot: NativeAxisymmetricSnapshot,
    series: NativeAxisymmetricSeries,
    output: Path | str,
) -> dict[str, Any]:
    validation = validate_native_axisymmetric_snapshot(snapshot, series)
    body = _snapshot_body(snapshot)
    body["snapshot_payload_sha256"] = snapshot.snapshot_payload_sha256
    output_path = Path(output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(body, indent=2, sort_keys=True, allow_nan=False) + "\n"
    output_bytes = payload.encode("utf-8")
    output_path.write_bytes(output_bytes)
    return {
        **validation,
        "output": str(output_path.resolve()),
        "output_sha256": _sha256_bytes(output_bytes),
        "output_bytes": len(output_bytes),
    }


def _main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify")
    verify.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    materialize = sub.add_parser("materialize")
    materialize.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    materialize.add_argument("--efm-time-index", type=int, required=True)
    materialize.add_argument("--amc-max-delta-s", type=float, required=True)
    materialize.add_argument("--output", type=Path, required=True)
    args = parser.parse_args(argv)
    series = load_native_axisymmetric_series(args.protocol)
    if args.command == "verify":
        result = validate_native_axisymmetric_series(series)
    else:
        snapshot = snapshot_native_axisymmetric(
            series, args.efm_time_index, amc_max_delta_s=args.amc_max_delta_s)
        result = write_native_axisymmetric_snapshot(snapshot, series, args.output)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(_main())
