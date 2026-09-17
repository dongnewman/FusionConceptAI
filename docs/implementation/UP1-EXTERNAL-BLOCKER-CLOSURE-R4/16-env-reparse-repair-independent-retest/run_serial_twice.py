"""Serial evidence runner for the frozen R4 environment repair retest."""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
TEST = ROOT / "test" / "up1_external_closure_r4" / "environment_closure" / "test_environment_closure_repair_independent.py"
RAW = HERE / "raw"


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def run_one(index: int) -> dict[str, object]:
    started = utc_now()
    process = subprocess.Popen(
        [sys.executable, str(TEST)],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = process.communicate()
    ended = utc_now()
    prefix = f"run_{index}"
    combined = stdout + b"\n" + stderr
    (RAW / f"{prefix}.stdout.raw").write_bytes(stdout)
    (RAW / f"{prefix}.stderr.raw").write_bytes(stderr)
    (RAW / f"{prefix}.pid.txt").write_text(str(process.pid) + "\n", encoding="utf-8")
    (RAW / f"{prefix}.utc.txt").write_text(f"started_utc={started}\nended_utc={ended}\n", encoding="utf-8")
    (RAW / f"{prefix}.exit.txt").write_text(str(process.returncode) + "\n", encoding="utf-8")
    (RAW / f"{prefix}.sha256.txt").write_text(
        f"stdout_sha256={sha256(stdout)}\nstderr_sha256={sha256(stderr)}\ncombined_sha256={sha256(combined)}\n",
        encoding="utf-8",
    )
    try:
        payload = json.loads(stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        payload = {"status": "fail_limited", "parse_error": f"{type(exc).__name__}:{exc}"}
    return {
        "index": index,
        "pid": process.pid,
        "started_utc": started,
        "ended_utc": ended,
        "exit_code": process.returncode,
        "stdout_sha256": sha256(stdout),
        "stderr_sha256": sha256(stderr),
        "combined_sha256": sha256(combined),
        "payload": payload,
    }


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    runs = [run_one(1), run_one(2)]
    collector = ROOT / "tools" / "up1_external_closure_r4" / "environment_closure" / "collector.py"
    test_hash = hashlib.sha256(TEST.read_bytes()).hexdigest()
    report = {
        "record_kind": "up1_external_environment_closure_r4_repair_serial_independent_retest",
        "schema": "UP1.external-environment-closure-r4-repair-serial-independent-retest.v1",
        "serial": True,
        "cwd": str(ROOT),
        "command": [sys.executable, str(TEST.relative_to(ROOT))],
        "network": False,
        "implementation_frozen": {
            "collector": {"path": str(collector.relative_to(ROOT)), "sha256": hashlib.sha256(collector.read_bytes()).hexdigest()},
            "test": {"path": str(TEST.relative_to(ROOT)), "sha256": test_hash},
        },
        "runs": runs,
        "status": "pass_limited" if all(run["exit_code"] == 0 and run["payload"].get("status") == "pass_limited" for run in runs) else "fail_limited",
        "authority": {"authoritative": False, "status": "local_test_only"},
        "claim_ceiling": "serial local behavior evidence only; no external authority, no reproducible closure, and no formal UP1 gate",
    }
    (HERE / "serial_report.json").write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if report["status"] == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
