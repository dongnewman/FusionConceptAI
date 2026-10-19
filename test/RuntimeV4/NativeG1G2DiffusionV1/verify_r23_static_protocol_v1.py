"""Verify frozen R23 source pins and static-only execution contract."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
DEFAULT_PROTOCOL = (
    ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_r23_spi_static_20260925_r1/protocol.json"
)


class StaticProtocolError(RuntimeError):
    pass


def _sha256(path: Path) -> tuple[int, str]:
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            size += len(chunk)
            digest.update(chunk)
    return size, digest.hexdigest()


def verify(protocol_path: Path) -> dict[str, Any]:
    try:
        protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise StaticProtocolError(f"protocol unreadable: {type(exc).__name__}: {exc}") from exc
    if protocol.get("schema") != "native-g1g2-r23-exact-spi-static-protocol-v1":
        raise StaticProtocolError("candidate schema mismatch")
    dispatch = protocol.get("runtime_dispatch_status")
    if dispatch != {
        "eligible": False,
        "julia_started": False,
        "runtime_executed": False,
        "status": "disabled_pending_independent_review_and_root_grant",
    }:
        raise StaticProtocolError("runtime dispatch must remain disabled before external review/root grant")
    limits = protocol.get("limits")
    expected_limits = {
        "wall_seconds_per_stage": 480.0,
        "rss_sampled_stop_threshold_bytes": 2_147_483_648,
        "sample_interval_seconds": 0.2,
        "julia_heap_size_hint": "1G",
        "julia_threads": 1,
        "blas_threads": 1,
        "compiler_mode": "--compile=min",
        "fixtures_and_numerical_thresholds_unchanged": True,
    }
    if limits != expected_limits:
        raise StaticProtocolError("resource/numerical execution contract changed")
    files = protocol.get("source_and_tool_pins")
    if not isinstance(files, list) or not files:
        raise StaticProtocolError("source/tool pins missing")
    checked = []
    for item in files:
        if not isinstance(item, dict) or set(item) != {"path", "role", "bytes", "sha256"}:
            raise StaticProtocolError("malformed source/tool pin")
        path = ROOT / item["path"]
        try:
            size, digest = _sha256(path)
        except Exception as exc:
            raise StaticProtocolError(f"pinned file unreadable: {item['path']}: {exc}") from exc
        if type(item["bytes"]) is not int or size != item["bytes"] or digest != item["sha256"]:
            raise StaticProtocolError(f"source/tool pin mismatch: {item['path']}")
        if path.suffix == ".py":
            try:
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            except Exception as exc:
                raise StaticProtocolError(f"Python syntax parse failed: {item['path']}: {exc}") from exc
        checked.append(item["path"])
    baseline = protocol.get("baseline_input_pin_set")
    if not isinstance(baseline, dict) or baseline.get("count") != 115:
        raise StaticProtocolError("the exact 115-input baseline pin set is required")
    baseline_path = ROOT / baseline["static_preflight_path"]
    size, digest = _sha256(baseline_path)
    if size != baseline["static_preflight_bytes"] or digest != baseline["static_preflight_sha256"]:
        raise StaticProtocolError("baseline static preflight pin mismatch")
    baseline_json = json.loads(baseline_path.read_text(encoding="utf-8"))
    dependencies = baseline_json.get("dependencies")
    if not isinstance(dependencies, dict) or len(dependencies) != 115:
        raise StaticProtocolError("baseline dependency count mismatch")
    pinned = baseline.get("dependencies")
    if not isinstance(pinned, list) or len(pinned) != 115:
        raise StaticProtocolError("protocol must carry all 115 baseline input hashes")
    normalized = {item["path"]: {"bytes": item["bytes"], "sha256": item["sha256"]}
                  for item in pinned}
    if normalized != dependencies:
        raise StaticProtocolError("the 115 baseline hashes differ from frozen r10 static preflight")
    for item in pinned:
        path = ROOT / item["path"]
        try:
            input_size, input_digest = _sha256(path)
        except Exception as exc:
            raise StaticProtocolError(f"baseline input unreadable: {item['path']}: {exc}") from exc
        if input_size != item["bytes"] or input_digest != item["sha256"]:
            raise StaticProtocolError(f"baseline input hash changed: {item['path']}")
    return {
        "schema": "native-g1g2-r23-static-verification-v1",
        "status": "static_protocol_check_pass",
        "checked_source_and_tool_files": len(checked),
        "checked_baseline_inputs": len(pinned),
        "runtime_executed": False,
        "julia_started": False,
        "numerical_credit": False,
        "physical_status": "unknown",
        "protocol_sha256": _sha256(protocol_path)[1],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", type=Path, default=DEFAULT_PROTOCOL)
    args = parser.parse_args(argv)
    try:
        result = verify(args.protocol)
    except Exception as exc:
        result = {
            "schema": "native-g1g2-r23-static-verification-v1",
            "status": "static_protocol_check_fail",
            "error_type": type(exc).__name__,
            "error": str(exc),
            "runtime_executed": False,
            "julia_started": False,
            "numerical_credit": False,
            "physical_status": "unknown",
        }
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 1
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
