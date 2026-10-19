"""Acquire an exact bounded set of source data for the MAST Thomson response.

The frozen decoder is reused without mutation. Every failure retains the raw
command, available response bytes, metadata, and progress; units/statistical
meaning are never inferred from field labels.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import sys
import traceback

import numpy as np
import psutil
import requests

ROOT = Path(__file__).resolve().parents[1]
METADATA = ROOT / "benchmarks/reference_data_level1_v1/shot30421_r1/zmetadata.json"
METADATA_SHA = "362932d6cfeb62f01109a56b825b235b7daaedc928c17340be59c7a1398e7db1"
HELPER = ROOT / "tools/fetch_mast_source_fields_v1.py"
HELPER_SHA = "b5b2fb24dcbb189b9425b811aca2390c7027dac177486bf9b795c9fb0a6a259c"
DLL = Path(r"D:\Users\Newman\anaconda3\Library\bin\blosc.dll")
DLL_SHA = "a21580c0c6eb967a9442f4e0559203c99781a530679bd8c7c6c408c4f27c7b11"
FIELDS = tuple("ayc/" + name for name in (
    "angle", "instrument_dr", "instrument_time", "scat_length", "arb",
    "spectra", "aspectra", "spectra_error", "spectra_stray_light",
    "poisson_error", "plasmalight_error", "chi2", "laser_energy", "laser_track",
    "time", "radial_index", "spectral_index", "pe", "pe_error", "interferometer_corr"))
MAX_CHUNK = 8_000_000
MAX_RSS = 536_870_912


def sha(raw):
    return sha256(raw).hexdigest()


def utc():
    return datetime.now(timezone.utc).isoformat()


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def identity(path):
    raw = path.read_bytes()
    return {"path": str(path), "bytes": len(raw), "sha256": sha(raw)}


def rss():
    size = psutil.Process().memory_info().rss
    if size > MAX_RSS:
        raise MemoryError(f"process RSS {size} exceeds frozen limit {MAX_RSS}")
    return size


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    # Creation, never replacement: the output directory is the transaction boundary.
    out.mkdir(parents=True, exist_ok=False)
    record = {"schema": "mast-thomson-response-acquisition-v1", "shot": 30421,
        "started_utc": utc(), "command": sys.argv, "pid": os.getpid(),
        "python": sys.version, "executable": sys.executable,
        "status": "started", "raw_values_only": True, "arrays": [],
        "error_semantics": "unknown_not_assumed_sigma", "likelihood_ready": False,
        "scientific_acceptance": False,
        "limits": {"compressed_chunk_bytes": MAX_CHUNK, "array_bytes": 8_000_000,
            "total_decoded_bytes": 24_000_000, "process_rss_bytes": MAX_RSS,
            "connect_seconds": 10, "read_seconds": 30}}
    write_json(out / "acquisition.json", record)
    session = None
    dll_handle = None
    code = 1
    try:
        pins = {"metadata": identity(METADATA), "decoder": identity(HELPER),
            "blosc": identity(DLL), "entry": identity(Path(__file__).resolve())}
        record["input_pins"] = pins
        write_json(out / "acquisition.json", record)
        for name, expected in (("metadata", METADATA_SHA), ("decoder", HELPER_SHA), ("blosc", DLL_SHA)):
            if pins[name]["sha256"] != expected:
                raise ValueError(f"{name} input pin mismatch")
        spec = importlib.util.spec_from_file_location("mast_thomson_frozen_decoder", HELPER)
        decoder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(decoder)
        metadata_bytes = METADATA.read_bytes()
        metadata = json.loads(metadata_bytes)["metadata"]
        selected, total = decoder.resolve_fields(metadata, 30421, list(FIELDS))
        selection = {"schema": "mast-thomson-response-selection-v1", "frozen_utc": utc(),
            "shot": 30421, "metadata_sha256": METADATA_SHA,
            "ownership": "docs/implementation/GOAL-EXECUTION-20260922/ownership_delta15_thomson_response_source.json",
            "fields": selected, "total_decoded_bytes": total,
            "selection": "exact metadata paths; no aliases, resampling, unit conversion or imputation",
            "interpretation": "all reported error/covariance and instrument labels remain unverified scientific semantics"}
        write_json(out / "selection.json", selection)
        (out / "zmetadata.json").write_bytes(metadata_bytes)
        (out / "fetch_mast_thomson_response_v1.py.copy").write_bytes(Path(__file__).read_bytes())
        (out / "fetch_mast_source_fields_v1.py.copy").write_bytes(HELPER.read_bytes())
        record.update(selection_sha256=sha((out / "selection.json").read_bytes()),
            total_decoded_bytes=total, peak_observed_rss_bytes=rss(), status="acquiring")
        write_json(out / "acquisition.json", record)
        library, dll_handle, actual_dll = decoder.load_blosc()
        if Path(actual_dll).resolve() != DLL.resolve():
            raise ValueError("loaded DLL path differs from frozen explicit path")
        session = requests.Session()
        for field in selected:
            field_path = field["resolved_path"]
            target = out / "fields" / field_path.replace("/", "__")
            chunks_dir = target / "chunks"
            chunks_dir.mkdir(parents=True, exist_ok=False)
            item = dict(field)
            item.update(status="acquiring", chunks_acquired=[], started_utc=utc())
            record["arrays"].append(item)
            write_json(out / "acquisition.json", record)
            shape, chunks = tuple(field["shape"]), tuple(field["chunks"])
            dtype = np.dtype(field["dtype"])
            assembled = np.empty(shape, dtype=dtype, order="C")
            covered = np.zeros(shape, dtype=np.bool_)
            for index in decoder.chunk_indices(shape, chunks):
                starts = tuple(index[a] * chunks[a] for a in range(len(shape)))
                edge = tuple(min(chunks[a], shape[a] - starts[a]) for a in range(len(shape)))
                key = ".".join(str(v) for v in index)
                url = f"https://s3.echo.stfc.ac.uk/mast/level1/shots/30421.zarr/{field_path}/{key}"
                chunk = {"chunk_index": list(index), "chunk_start": list(starts),
                    "edge_shape": list(edge), "url": url, "requested_utc": utc()}
                item["chunks_acquired"].append(chunk)
                write_json(out / "acquisition.json", record)
                compressed_path = chunks_dir / (key + ".blosc")
                chunk["compressed_path"] = compressed_path.relative_to(out).as_posix()
                with session.get(url, timeout=(10, 30), stream=True) as response:
                    chunk["http_status"] = response.status_code
                    chunk["headers"] = {k: v for k, v in response.headers.items()
                        if k.lower() in ("content-length", "content-type", "etag", "last-modified")}
                    response.raise_for_status()
                    chunk["status"] = "downloading"
                    write_json(out / "acquisition.json", record)
                    received = 0
                    with compressed_path.open("xb") as handle:
                        for part in response.iter_content(65536):
                            if received + len(part) > MAX_CHUNK:
                                raise ValueError("compressed response exceeds frozen maximum")
                            handle.write(part)
                            received += len(part)
                compressed = compressed_path.read_bytes()
                chunk.update(compressed_path=compressed_path.relative_to(out).as_posix(),
                    compressed_bytes=len(compressed), compressed_sha256=sha(compressed))
                write_json(out / "acquisition.json", record)
                raw, values, decoded_shape, full_bytes, edge_bytes = decoder.decode_chunk(
                    library, compressed, dtype, chunks, edge)
                raw_path = chunks_dir / (key + ".raw")
                raw_path.write_bytes(raw)
                values = values[tuple(slice(0, s) for s in edge)]
                slices = tuple(slice(starts[a], starts[a] + edge[a]) for a in range(len(shape)))
                if covered[slices].any() or values.shape != edge:
                    raise ValueError("overlapping or incorrectly shaped decoded chunk")
                assembled[slices] = values
                covered[slices] = True
                chunk.update(decoded_path=raw_path.relative_to(out).as_posix(),
                    decoded_bytes=len(raw), decoded_sha256=sha(raw), decoded_shape=list(decoded_shape),
                    full_bytes=full_bytes, edge_bytes=edge_bytes, completed_utc=utc(), status="decoded")
                record["peak_observed_rss_bytes"] = max(record["peak_observed_rss_bytes"], rss())
                write_json(out / "acquisition.json", record)
            if not covered.all():
                raise ValueError("not every source cell was decoded exactly once")
            assembled_path = target / "assembled.raw"
            assembled_raw = assembled.tobytes(order="C")
            assembled_path.write_bytes(assembled_raw)
            finite = assembled[np.isfinite(assembled)]
            item.update(status="acquired_raw_values_semantics_unverified", completed_utc=utc(),
                assembled_path=assembled_path.relative_to(out).as_posix(),
                assembled_bytes=len(assembled_raw), assembled_sha256=sha(assembled_raw),
                finite_count=int(finite.size), total_count=int(assembled.size),
                minimum=float(finite.min()) if finite.size else None,
                maximum=float(finite.max()) if finite.size else None)
            write_json(target / "field_metadata.json", item)
            write_json(out / "acquisition.json", record)
            print(json.dumps({"field": field_path, "bytes": len(assembled_raw),
                "finite": int(finite.size), "sha256": item["assembled_sha256"]}), flush=True)
        after = {k: identity(Path(v["path"])) for k, v in pins.items()}
        record["input_pins_after"] = after
        record["inputs_unchanged"] = after == pins
        if after != pins:
            raise ValueError("input changed during acquisition")
        record["status"] = "acquired_requires_independent_decode_review"
        code = 0
    except Exception as exc:
        record.update(status="failed", exception_type=type(exc).__name__, error=str(exc))
        (out / "exception.txt").write_text(traceback.format_exc(), encoding="utf-8")
        print(json.dumps({"status": "failed", "exception_type": type(exc).__name__, "error": str(exc)}), flush=True)
    finally:
        if session is not None:
            session.close()
        if dll_handle is not None:
            dll_handle.close()
        record.update(ended_utc=utc(), exit_code=code)
        write_json(out / "acquisition.json", record)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
