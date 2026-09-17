"""Run the R4 source-axis binding independent test twice, serially.

This runner records raw child streams and process metadata.  It is local
behavior evidence only: no external source, authority, formal credit, or
publish permission can be obtained from it.
"""
from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test" / "up1_external_closure_r4" / "source_axis_binding"
EVIDENCE = Path(__file__).resolve().parent / "raw"


def utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def stable_output(data: bytes) -> bytes:
    """Remove unittest's wall-clock duration while retaining raw evidence."""
    return re.sub(rb"Ran (\d+) tests in [0-9.]+s", rb"Ran \1 tests in <duration>s", data)


def run_one(index: int) -> dict[str, object]:
    started = utc()
    command = [sys.executable, "-B", "-m", "unittest", "discover", "-s", str(TEST_ROOT), "-p", "test_*.py", "-v"]
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
    (EVIDENCE / f"{stem}.sha256.txt").write_text(f"stdout_sha256={digest(stdout)}\nstderr_sha256={digest(stderr)}\ncombined_sha256={digest(combined)}\n", encoding="ascii")
    return {
        "index": index,
        "pid": pid,
        "started_utc": started,
        "ended_utc": ended,
        "exit_code": process.returncode,
        "stdout_sha256": digest(stdout),
        "stderr_sha256": digest(stderr),
        "normalized_stderr_sha256": digest(stable_output(stderr)),
        "combined_sha256": digest(combined),
        "stdout_bytes": len(stdout),
        "stderr_bytes": len(stderr),
    }


def main() -> int:
    runs = [run_one(1), run_one(2)]
    serial_byte_identical = runs[0]["stdout_sha256"] == runs[1]["stdout_sha256"] and runs[0]["stderr_sha256"] == runs[1]["stderr_sha256"]
    normalized_output_identical = runs[0]["stdout_sha256"] == runs[1]["stdout_sha256"] and runs[0]["normalized_stderr_sha256"] == runs[1]["normalized_stderr_sha256"]
    status = "pass_limited" if all(run["exit_code"] == 0 for run in runs) and normalized_output_identical else "fail_limited"
    report = {
        "record_kind": "up1_external_source_axis_binding_r4_serial_independent_test",
        "schema": "UP1.external-source-axis-binding-r4-serial-test.v1",
        "status": status,
        "authority": {"authoritative": False, "status": "local_test_only"},
        "formal_credit": "none",
        "no_publish": True,
        "claim_ceiling": "two serial local test runs; raw/git/hash observations do not establish external authority or close a formal UP1 gate",
        "scope": [
            "raw bytes/hash/locator and source identity",
            "HEAD/tree/dirty/patch/untracked/submodule evidence",
            "unique four-axis coverage and domain-separated digests",
            "candidate/run/authority references and reverse-edge joins",
            "duplicate key, float, canonical preimage, hash/ref/axis drift adversaries",
            "TEST_ONLY non_evidence, typed absence, formal_credit none, no_publish true",
        ],
        "serial": True,
        "byte_identical": serial_byte_identical,
        "normalized_output_identical": normalized_output_identical,
        "runs": runs,
    }
    (EVIDENCE.parent / "serial_report.json").write_text(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2))
    return 0 if status == "pass_limited" else 1


if __name__ == "__main__":
    raise SystemExit(main())
