"""Capture two serial unit+adversarial retests without touching code or tests."""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
RAW = HERE / "raw"
SOURCE_FILES = [
    Path("tools/up1_external_closure_r4/g2_mapping/validator.py"),
    Path("tools/up1_external_closure_r4/g2_mapping/validate_g2_mapping.py"),
    Path("tools/up1_external_closure_r4/g2_mapping/g2_mapping.py"),
    Path("test/up1_external_closure_r4/g2_mapping/test_independent_g2_mapping.py"),
    Path("test/up1_external_closure_r4/g2_mapping/adversarial_probe.py"),
    Path("test/up1_external_closure_r4/g2_mapping/serial_run.py"),
]
EVIDENCE_07_FILES = [
    Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/07-g2-independent-test/report.md"),
    Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/07-g2-independent-test/raw/serial_run_1.raw.txt"),
    Path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R4/07-g2-independent-test/raw/serial_run_2.raw.txt"),
]


def utc() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_sha(path: Path) -> str:
    return sha((ROOT / path).read_bytes())


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="")


def run_one(index: int) -> dict[str, object]:
    started = utc()
    proc = subprocess.Popen(
        [sys.executable, "-B", "test/up1_external_closure_r4/g2_mapping/serial_run.py"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = proc.communicate()
    ended = utc()
    combined = stdout + (b"\n[runner.stderr]\n" + stderr if stderr else b"")
    prefix = RAW / f"run_{index}"
    write_text(prefix.with_suffix(".stdout.raw.txt"), stdout.decode("utf-8"))
    write_text(prefix.with_suffix(".stderr.raw.txt"), stderr.decode("utf-8"))
    write_text(prefix.with_suffix(".raw.txt"), combined.decode("utf-8"))
    write_text(prefix.with_suffix(".pid.txt"), f"{proc.pid}\n")
    write_text(prefix.with_suffix(".utc.txt"), f"started_at_utc={started}\nended_at_utc={ended}\n")
    write_text(prefix.with_suffix(".exit.txt"), f"{proc.returncode}\n")
    write_text(
        prefix.with_suffix(".sha256.txt"),
        f"stdout_sha256={sha(stdout)}\nstderr_sha256={sha(stderr)}\nraw_sha256={sha(combined)}\n",
    )
    decoded = stdout.decode("utf-8")
    adversarial_section = decoded.split("[adversarial.stdout]", 1)[1]
    adversarial_json = adversarial_section[adversarial_section.find("{") : adversarial_section.rfind("}") + 1]
    return {
        "run": index,
        "runner_pid": proc.pid,
        "child_pids": {
            "unit": int(re.search(r"\[unit\] pid=(\d+)", decoded).group(1)),
            "adversarial": int(re.search(r"\[adversarial\] pid=(\d+)", decoded).group(1)),
        },
        "started_at_utc": started,
        "ended_at_utc": ended,
        "exit": proc.returncode,
        "stdout_sha256": sha(stdout),
        "stderr_sha256": sha(stderr),
        "raw_sha256": sha(combined),
        "stdout_path": str(prefix.with_suffix(".stdout.raw.txt").relative_to(HERE)),
        "stderr_path": str(prefix.with_suffix(".stderr.raw.txt").relative_to(HERE)),
        "raw_path": str(prefix.with_suffix(".raw.txt").relative_to(HERE)),
        "unit_15_tests_ok": "Ran 15 tests" in decoded and "OK" in decoded,
        "adversarial": json.loads(adversarial_json),
    }


def main() -> int:
    RAW.mkdir(parents=True, exist_ok=True)
    started = utc()
    records = [run_one(1), run_one(2)]
    ended = utc()
    source_hashes = {str(path): file_sha(path) for path in SOURCE_FILES}
    evidence_07_hashes = {str(path): file_sha(path) for path in EVIDENCE_07_FILES}
    semantic_pass = all(
        item["exit"] == 0
        and item["unit_15_tests_ok"]
        and item["adversarial"]["finding_count"] == 0
        and item["adversarial"]["conservative_decision"] == "no_gap_observed"
        and all(
            case["decision"] == "fail_closed"
            and case["resolution"] == "fail_closed"
            and case["no_publish"] is True
            and case["formal_credit"] == "none"
            for case in item["adversarial"]["cases"]
        )
        for item in records
    )
    result = {
        "schema": "UP1.g2-repair-independent-retest.v1",
        "capture_pid": os.getpid(),
        "started_at_utc": started,
        "ended_at_utc": ended,
        "runs": records,
        "all_exit_zero": all(item["exit"] == 0 for item in records),
        "raw_sha256_equal": records[0]["raw_sha256"] == records[1]["raw_sha256"],
        "stdout_sha256_equal": records[0]["stdout_sha256"] == records[1]["stdout_sha256"],
        "semantic_pass": semantic_pass,
        "frozen_source_hashes": source_hashes,
        "frozen_07_evidence_hashes": evidence_07_hashes,
    }
    (HERE / "capture_manifest.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    (HERE / "freeze_manifest.json").write_text(
        json.dumps(
            {
                "schema": "UP1.g2-repair-independent-retest.freeze.v1",
                "source_files": source_hashes,
                "prior_07_evidence_files": evidence_07_hashes,
                "implementation_and_tests_untouched_by_capture": True,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    return 0 if result["all_exit_zero"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
