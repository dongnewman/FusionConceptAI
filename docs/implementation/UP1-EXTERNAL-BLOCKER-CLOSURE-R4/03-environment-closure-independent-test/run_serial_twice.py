"""Run the independent environment-closure checks twice, serially.

The runner is intentionally a small stdlib-only process harness.  Each child
run is isolated, and stdout/stderr plus PID, UTC bounds, exit code, and SHA-256
are written as raw evidence.  The resulting conclusion is ``pass_limited`` or
``fail_limited`` and has no external-authority or formal-gate meaning.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone


ROOT = Path(__file__).resolve().parents[4]
TEST_RUNNER = ROOT / "test" / "up1_external_closure_r4" / "environment_closure" / "test_environment_closure_independent.py"
EVIDENCE = Path(__file__).resolve().parent / "raw"


def utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def implementation_freeze() -> list[dict[str, str]]:
    """Record hashes of the frozen collector inputs without editing them."""
    files: list[dict[str, str]] = []
    for path in sorted((ROOT / "tools" / "up1_external_closure_r4" / "environment_closure").glob("*.py")):
        files.append({"path": path.relative_to(ROOT).as_posix(), "sha256": sha256(path.read_bytes())})
    return files


def run_one(index: int) -> dict[str, object]:
    started = utc()
    command = [sys.executable, str(TEST_RUNNER)]
    process = subprocess.Popen(command, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=False)
    pid = process.pid
    stdout, stderr = process.communicate()
    ended = utc()
    stem = f"run_{index}"
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / f"{stem}.stdout.raw").write_bytes(stdout)
    (EVIDENCE / f"{stem}.stderr.raw").write_bytes(stderr)
    (EVIDENCE / f"{stem}.pid.txt").write_text(f"{pid}\n", encoding="ascii")
    (EVIDENCE / f"{stem}.utc.txt").write_text(f"started_utc={started}\nended_utc={ended}\n", encoding="ascii")
    (EVIDENCE / f"{stem}.exit.txt").write_text(f"{process.returncode}\n", encoding="ascii")
    combined = stdout + b"\n" + stderr
    (EVIDENCE / f"{stem}.sha256.txt").write_text(f"{sha256(combined)}\n", encoding="ascii")
    try:
        payload = json.loads(stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        payload = {"status": "fail_limited", "parse_error": True}
    return {"index": index, "pid": pid, "started_utc": started, "ended_utc": ended, "exit_code": process.returncode, "stdout_sha256": sha256(stdout), "stderr_sha256": sha256(stderr), "combined_sha256": sha256(combined), "payload": payload}


def main() -> int:
    parser = argparse.ArgumentParser(description="serially run the independent UP1 R4 environment closure test twice")
    parser.add_argument("--run", type=int, choices=(1, 2), help="run only one serial leg; default runs both")
    args = parser.parse_args()
    indices = (args.run,) if args.run else (1, 2)
    runs = [run_one(index) for index in indices]
    statuses = [str(run.get("payload", {}).get("status")) for run in runs]
    exits = [run.get("exit_code") for run in runs]
    status = "pass_limited" if runs and all(value == "pass_limited" for value in statuses) and all(code == 0 for code in exits) else "fail_limited"
    report = {
        "record_kind": "up1_external_environment_closure_r4_serial_independent_test",
        "schema": "UP1.external-environment-closure-r4-serial-test.v1",
        "status": status,
        "authority": {"authoritative": False, "status": "local_test_only"},
        "claim_ceiling": "serial local behavior test only; version/hash observations do not establish reproducible closure; no formal UP1 gate",
        "serial": len(runs) == 2,
        "frozen_implementation": implementation_freeze(),
        "runs": runs,
    }
    (EVIDENCE.parent / "serial_report.json").write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if status == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
