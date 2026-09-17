"""Serial evidence runner for the bounded R4 integration tests.

The runner invokes only this focused pytest file twice, in separate Python
processes.  It records raw stdout/stderr, PID, UTC, exit status, and SHA-256
receipts.  No Julia, DESC, network, T0, or S3 command is reachable here.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TEST = ROOT / "test" / "up1_external_closure_r4" / "integration" / "test_integration.py"
OUT = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R4" / "13-integration-independent-test"
RAW = OUT / "raw"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run_one(index: int) -> dict:
    started = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    proc = subprocess.Popen(
        [sys.executable, "-m", "pytest", str(TEST), "-q"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = proc.communicate()
    finished = datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
    prefix = f"serial_run_{index}"
    (RAW / f"{prefix}.stdout.raw.txt").write_bytes(stdout)
    (RAW / f"{prefix}.stderr.raw.txt").write_bytes(stderr)
    (RAW / f"{prefix}.pid.txt").write_text(str(proc.pid), encoding="utf-8")
    (RAW / f"{prefix}.utc.txt").write_text(f"started={started}\nfinished={finished}\n", encoding="utf-8")
    (RAW / f"{prefix}.exit.txt").write_text(str(proc.returncode), encoding="utf-8")
    return {
        "run": index,
        "pid": proc.pid,
        "started_utc": started,
        "finished_utc": finished,
        "exit": proc.returncode,
        "stdout_sha256": sha256(stdout),
        "stderr_sha256": sha256(stderr),
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
    }


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    rows = [run_one(1), run_one(2)]
    manifest = {
        "schema": "UP1.external-closure-r4.integration-independent-evidence.v1",
        "cwd": str(ROOT),
        "test": str(TEST.relative_to(ROOT)),
        "command": [sys.executable, "-m", "pytest", str(TEST.relative_to(ROOT)), "-q"],
        "network": False,
        "heavy_lane": False,
        "t0_executed": False,
        "s3_executed": False,
        "runs": rows,
    }
    (OUT / "run_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True, separators=(",", ":")))
    return 0 if all(row["exit"] == 0 for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
