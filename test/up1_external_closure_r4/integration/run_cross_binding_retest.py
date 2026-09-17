"""Serial evidence runner for the independent cross-binding R4 retest.

The command is intentionally limited to the offline integration test package.
Each process gets its own PID and UTC envelope; stored stdout/stderr and the
test source are hashed so a later reviewer can distinguish raw evidence from
the prose ruling.
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
TEST_ROOT = ROOT / "test" / "up1_external_closure_r4" / "integration"
OUT = ROOT / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R4" / "17-cross-binding-repair-independent-retest"
RAW = OUT / "raw"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


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
    (RAW / f"{prefix}.pid.txt").write_text(str(proc.pid), encoding="utf-8")
    (RAW / f"{prefix}.utc.txt").write_text(f"started={started}\nfinished={finished}\n", encoding="utf-8")
    (RAW / f"{prefix}.exit.txt").write_text(str(proc.returncode), encoding="utf-8")
    combined = stdout + stderr
    (RAW / f"{prefix}.combined.raw.txt").write_bytes(combined)
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
        TEST_ROOT / "test_cross_binding_repair_retest.py",
        TEST_ROOT / "test_integration.py",
        ROOT / "tools" / "up1_external_closure_r4" / "integration" / "orchestrator.py",
    ]
    before_hashes = {
        str(path.relative_to(ROOT)): {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        for path in source_files
    }
    rows = [run_one(1), run_one(2)]
    after_hashes = {
        str(path.relative_to(ROOT)): {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        for path in source_files
    }
    manifest = {
        "schema": "UP1.external-closure-r4.cross-binding-repair-independent-retest.v1",
        "cwd": str(ROOT),
        "test_root": str(TEST_ROOT.relative_to(ROOT)),
        "command": [sys.executable, "-B", "-m", "pytest", str(TEST_ROOT.relative_to(ROOT)), "-q"],
        "scope": "offline local integration only; no network, Julia, DESC, T0, S3, or runtime execution",
        "network": False,
        "heavy_lane": False,
        "t0_executed": False,
        "s3_executed": False,
        "source_hashes_before": before_hashes,
        "source_hashes_after": after_hashes,
        "source_hashes_unchanged": before_hashes == after_hashes,
        "runs": rows,
    }
    (OUT / "run_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, sort_keys=True, separators=(",", ":")))
    return 0 if manifest["source_hashes_unchanged"] and all(row["exit"] == 0 for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
