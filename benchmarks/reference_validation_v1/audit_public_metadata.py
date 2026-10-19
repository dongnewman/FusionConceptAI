"""Read-only FAIR-MAST metadata audit; never treats catalog rows as array identity.

This reports public metadata drift against the frozen UP4 reference inputs. It
does not download signal chunks, revise the split, or authorize a likelihood.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import sys

import requests


ROOT = Path(__file__).resolve().parents[2]
FIELDS = (
    "ayc/ne",
    "ayc/te",
    "ayc/ne_error",
    "ayc/te_error",
    "ayc/covariance_ne_te",
    "efm/fcoil_c",
    "efm/fcoil_x",
)
MAX_BYTES = 2_000_000


def fetch(session: requests.Session, url: str) -> tuple[bytes, dict[str, object]]:
    with session.get(url, timeout=(10, 30), stream=True) as response:
        response.raise_for_status()
        chunks = []
        size = 0
        for chunk in response.iter_content(65536):
            size += len(chunk)
            if size > MAX_BYTES:
                raise ValueError(f"metadata response exceeds {MAX_BYTES} bytes: {url}")
            chunks.append(chunk)
        raw = b"".join(chunks)
        return raw, {
            "url": url,
            "http_status": response.status_code,
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
        }


def run() -> list[dict[str, object]]:
    catalog = json.loads(
        (ROOT / "benchmarks/reference_validation_v1/source_evidence.json").read_text(
            encoding="utf-8"
        )
    )
    results = []
    with requests.Session() as session:
        for shot in (30421, 30420):
            local_level1 = json.loads(
                (ROOT / f"benchmarks/reference_data_level1_v1/shot{shot}_r1/zmetadata.json")
                .read_text(encoding="utf-8")
            )["metadata"]
            for field in FIELDS:
                result: dict[str, object] = {"shot": shot, "source": "level1", "field": field}
                for suffix in (".zarray", ".zattrs"):
                    raw, identity = fetch(
                        session,
                        f"https://s3.echo.stfc.ac.uk/mast/level1/shots/{shot}.zarr/{field}/{suffix}",
                    )
                    value = json.loads(raw)
                    identity["same_as_frozen_metadata"] = (
                        value == local_level1[f"{field}/{suffix}"]
                    )
                    result[suffix] = identity
                    if suffix == ".zarray":
                        result["shape"] = value.get("shape")
                    else:
                        result["dimensions"] = value.get("_ARRAY_DIMENSIONS")
                        result["units"] = value.get("units")
                        result["uuid"] = value.get("uuid")
                results.append(result)

            zarr_url = f"https://s3.echo.stfc.ac.uk/mast/level2/shots/{shot}.zarr/zarr.json"
            raw, identity = fetch(session, zarr_url)
            live = json.loads(raw)["consolidated_metadata"]["metadata"]
            local_path = ROOT / f"benchmarks/reference_data_v2/raw/shot{shot}/level2/shots/{shot}.zarr/zarr.json"
            frozen_raw = local_path.read_bytes()
            frozen = json.loads(frozen_raw)["consolidated_metadata"]["metadata"]
            identity["same_bytes_as_frozen"] = raw == frozen_raw
            for name in ("n_e", "t_e"):
                key = f"thomson_scattering/{name}"
                catalog_rows = [
                    row for row in catalog["catalog_snapshots"][str(shot)]["rows"]
                    if row["name"] == name
                ]
                if len(catalog_rows) != 1:
                    raise ValueError(f"expected one frozen catalog row for {shot}/{name}")
                row = catalog_rows[0]
                results.append({
                    "shot": shot,
                    "source": "level2",
                    "field": key,
                    "live_metadata": identity,
                    "live_shape": live[key].get("shape"),
                    "frozen_shape": frozen[key].get("shape"),
                    "catalog_shape": row["shape"],
                    "live_dimensions": live[key].get("dimension_names"),
                    "frozen_dimensions": frozen[key].get("dimension_names"),
                    "catalog_dimensions": row["dimensions"],
                    "live_units": live[key].get("attributes", {}).get("units"),
                    "catalog_units": row["units"],
                    "catalog_uuid": row["uuid"],
                    "array_uuid": live[key].get("attributes", {}).get("uuid"),
                })

            catalog_url = f"https://mastapp.site/parquet/level2/signals?shot_id={shot}"
            catalog_raw, catalog_identity = fetch(session, catalog_url)
            frozen_catalog = (
                ROOT / f"benchmarks/reference_data_v2/raw/shot{shot}/api/signals_shot_{shot}.parquet"
            ).read_bytes()
            catalog_identity["same_bytes_as_frozen"] = catalog_raw == frozen_catalog
            results.append({"shot": shot, "source": "catalog_parquet", "identity": catalog_identity})
    return results


if __name__ == "__main__":
    try:
        for item in run():
            print(json.dumps(item, ensure_ascii=False, sort_keys=True))
    except Exception as exc:
        print(json.dumps({"audit_error": type(exc).__name__, "detail": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
