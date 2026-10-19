"""Acquire exact public Level-1 AYC arrays; do not interpret errors as sigma.

Source discovery: https://mastapp.site/level1-data.html and shot JSON endpoint.
Blosc API: https://github.com/Blosc/c-blosc/blob/main/blosc/blosc.h
This bounded acquisition does not join different data levels or grant VVUQ credit.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
from pathlib import Path
import sys
from datetime import datetime, timezone

import numpy as np
import requests


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--shot", type=int, required=True)
    parser.add_argument("--metadata", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    schema_bytes = args.metadata.read_bytes()
    schema = json.loads(schema_bytes)
    metadata = schema["metadata"]
    (output / "zmetadata.json").write_bytes(schema_bytes)
    dll_dir = Path(sys.executable).parent / "Library" / "bin"
    dll_path = dll_dir / "blosc.dll"
    dll_handle = os.add_dll_directory(str(dll_dir))
    lib = ctypes.CDLL(str(dll_path))
    lib.blosc_cbuffer_validate.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.POINTER(ctypes.c_size_t)]
    lib.blosc_cbuffer_validate.restype = ctypes.c_int
    lib.blosc_decompress_ctx.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_int]
    lib.blosc_decompress_ctx.restype = ctypes.c_int
    names = ("ne", "te", "ne_error", "te_error", "covariance_ne_te", "time",
             "radial_index", "radius", "instrument_dr", "instrument_time")
    receipt = {"schema": "mast-level1-raw-acquisition-v1", "shot": args.shot,
        "utc_started": datetime.now(timezone.utc).isoformat(), "command": sys.argv,
        "pid": os.getpid(), "python": sys.version, "executable": sys.executable,
        "metadata_sha256": digest(schema_bytes), "script_sha256": digest(Path(__file__).read_bytes()),
        "blosc_dll": str(dll_path), "blosc_dll_sha256": digest(dll_path.read_bytes()),
        "error_semantics": "unverified_not_assumed_standard_deviation",
        "likelihood_ready": False, "scientific_acceptance": False, "arrays": [], "failures": []}
    session = requests.Session()
    try:
        for name in names:
            entry = {"name": name}
            try:
                spec = metadata[f"ayc/{name}/.zarray"]
                attrs = metadata[f"ayc/{name}/.zattrs"]
                if spec["shape"] != spec["chunks"] or spec["order"] != "C" or spec["filters"]:
                    raise ValueError("bounded reader requires one complete C-order unfiltered chunk")
                if spec["compressor"]["id"] != "blosc":
                    raise ValueError("unexpected compressor")
                if "shot_id" in attrs and attrs["shot_id"] != args.shot:
                    raise ValueError("metadata shot mismatch")
                suffix = ".".join("0" for _ in spec["shape"])
                url = f"https://s3.echo.stfc.ac.uk/mast/level1/shots/{args.shot}.zarr/ayc/{name}/{suffix}"
                response = session.get(url, timeout=(10, 30))
                response.raise_for_status()
                compressed = response.content
                if len(compressed) > 4_000_000:
                    raise ValueError("chunk exceeds bounded acquisition size")
                (output / f"{name}.blosc").write_bytes(compressed)
                src = ctypes.create_string_buffer(compressed)
                size = ctypes.c_size_t()
                if lib.blosc_cbuffer_validate(src, len(compressed), ctypes.byref(size)) != 0:
                    raise ValueError("invalid Blosc buffer")
                expected = int(np.prod(spec["shape"])) * np.dtype(spec["dtype"]).itemsize
                if size.value != expected or expected > 4_000_000:
                    raise ValueError("decoded size differs from actual Zarr shape")
                dest = ctypes.create_string_buffer(expected)
                if lib.blosc_decompress_ctx(src, dest, expected, 1) != expected:
                    raise ValueError("Blosc decompression failed")
                raw = dest.raw
                (output / f"{name}.raw").write_bytes(raw)
                array = np.frombuffer(raw, dtype=spec["dtype"]).reshape(spec["shape"])
                finite = array[np.isfinite(array)]
                entry.update(url=url, http_status=response.status_code, metadata=spec, attributes=attrs,
                    compressed_sha256=digest(compressed), raw_sha256=digest(raw), raw_bytes=len(raw),
                    finite_count=int(finite.size), total_count=int(array.size),
                    minimum=float(finite.min()) if finite.size else None,
                    maximum=float(finite.max()) if finite.size else None,
                    negative_finite_count=int(np.count_nonzero(finite < 0)),
                    status="decoded_raw_values_no_uncertainty_interpretation")
                receipt["arrays"].append(entry)
                print(json.dumps({k:entry[k] for k in ("name", "finite_count", "total_count", "minimum", "maximum")}), flush=True)
            except Exception as exc:
                entry.update(exception_type=type(exc).__name__, message=str(exc), status="acquisition_failed")
                receipt["failures"].append(entry)
                print(json.dumps(entry), flush=True)
            (output / "acquisition.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    finally:
        receipt["utc_finished"] = datetime.now(timezone.utc).isoformat()
        receipt["exit_code"] = int(bool(receipt["failures"]))
        (output / "acquisition.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
        session.close()
        dll_handle.close()
    return receipt["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
