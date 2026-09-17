"""Independent serial evidence runner for the second cross-binding repair."""

from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test" / "up1_external_closure_r4" / "integration"
OUT = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R4" / "18-cross-binding-repair2-independent-retest"
RAW = OUT / "raw"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def file_receipt(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": sha256_bytes(data)}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def run_one(index: int) -> dict[str, object]:
    command = [sys.executable, "-B", "-m", "pytest", str(TEST_ROOT.relative_to(ROOT)), "-q"]
    started = utc_now()
    proc = subprocess.Popen(
        command,
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = proc.communicate()
    finished = utc_now()
    prefix = f"integration_run_{index}"
    (RAW / f"{prefix}.stdout.raw.txt").write_bytes(stdout)
    (RAW / f"{prefix}.stderr.raw.txt").write_bytes(stderr)
    combined = stdout + stderr
    (RAW / f"{prefix}.combined.raw.txt").write_bytes(combined)
    (RAW / f"{prefix}.pid.txt").write_text(str(proc.pid) + "\n", encoding="utf-8")
    (RAW / f"{prefix}.utc.txt").write_text(f"started={started}\nfinished={finished}\n", encoding="utf-8")
    (RAW / f"{prefix}.exit.txt").write_text(str(proc.returncode) + "\n", encoding="utf-8")
    return {
        "run": index,
        "pid": proc.pid,
        "started_utc": started,
        "finished_utc": finished,
        "exit": proc.returncode,
        "stdout_sha256": sha256_bytes(stdout),
        "stderr_sha256": sha256_bytes(stderr),
        "combined_sha256": sha256_bytes(combined),
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
        "command": command,
    }


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    source_files = [
        ROOT / "tools" / "up1_external_closure_r4" / "integration" / "orchestrator.py",
        TEST_ROOT / "test_cross_binding_repair_retest.py",
        TEST_ROOT / "test_integration.py",
    ]
    before = {str(path.relative_to(ROOT)): file_receipt(path) for path in source_files}
    rows = [run_one(1), run_one(2)]
    after = {str(path.relative_to(ROOT)): file_receipt(path) for path in source_files}
    manifest = {
        "schema": "UP1.external-closure-r4.cross-binding-repair2-independent-retest.v1",
        "cwd": str(ROOT),
        "test_root": str(TEST_ROOT.relative_to(ROOT)),
        "command": [sys.executable, "-B", "-m", "pytest", str(TEST_ROOT.relative_to(ROOT)), "-q"],
        "scope": "offline local integration only; no network, Julia, DESC, T0, S3, or runtime execution",
        "network": False,
        "heavy_lane": False,
        "t0_executed": False,
        "s3_executed": False,
        "source_hashes_before": before,
        "source_hashes_after": after,
        "source_hashes_unchanged": before == after,
        "runs": rows,
    }
    (OUT / "run_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True, separators=(",", ":")))
    return 0 if manifest["source_hashes_unchanged"] and all(row["exit"] == 0 for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
