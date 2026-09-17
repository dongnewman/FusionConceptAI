"""One deterministic audit lane: run the unit suite then the black-box probe.

The parent process is intentionally serial and emits child PID/UTC/exit/raw
SHA-256 metadata so two invocations can be compared without trusting a test
runner's summary alone.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def run(label: str, argv: list[str]) -> dict[str, object]:
    started = utc()
    proc = subprocess.Popen(argv, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    stdout_text, stderr_text = proc.communicate()
    stdout = stdout_text.encode("utf-8")
    stderr = stderr_text.encode("utf-8")
    return {
        "label": label,
        "started_at_utc": started,
        "ended_at_utc": utc(),
        "pid": proc.pid,
        "exit": proc.returncode,
        "stdout_sha256": hashlib.sha256(stdout).hexdigest(),
        "stderr_sha256": hashlib.sha256(stderr).hexdigest(),
        "stdout": stdout_text,
        "stderr": stderr_text,
    }


def main() -> int:
    started = utc()
    unit = run("unit", [sys.executable, "-B", "-m", "unittest", "discover", "-s", "test/up1_external_closure_r4/g2_mapping", "-p", "test_*.py"])
    probe = run("adversarial", [sys.executable, "-B", "test/up1_external_closure_r4/g2_mapping/adversarial_probe.py"])
    print(f"RUNNER_PID={os.getpid()}")
    print(f"RUN_STARTED_UTC={started}")
    for record in (unit, probe):
        print(f"[{record['label']}] pid={record['pid']} started_at_utc={record['started_at_utc']} ended_at_utc={record['ended_at_utc']} exit={record['exit']} stdout_sha256={record['stdout_sha256']} stderr_sha256={record['stderr_sha256']}")
        print(f"[{record['label']}.stdout]")
        print(record["stdout"], end="")
        if record["stderr"]:
            print(f"[{record['label']}.stderr]")
            print(record["stderr"], end="")
    print(f"RUN_ENDED_UTC={utc()}")
    return 0 if unit["exit"] == 0 and probe["exit"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
