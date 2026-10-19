"""Run parent and replay Julia processes sequentially without memory overlap."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys
import time


HERE = Path(__file__).resolve().parent


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def run_phase(command: list[str], stdout_path: Path, stderr_path: Path) -> dict[str, object]:
    started = time.monotonic()
    started_utc = utc()
    with stdout_path.open("wb") as stdout, stderr_path.open("wb") as stderr:
        completed = subprocess.run(
            command,
            cwd=HERE.parents[3],
            env=os.environ.copy(),
            stdout=stdout,
            stderr=stderr,
            check=False,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
    return {
        "command": command,
        "started_utc": started_utc,
        "ended_utc": utc(),
        "seconds": time.monotonic() - started,
        "exit_code": completed.returncode,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--julia", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--evidence-dir", required=True)
    args = parser.parse_args()

    evidence_dir = Path(args.evidence_dir).resolve()
    evidence_dir.mkdir(parents=True, exist_ok=True)
    expected_path = evidence_dir / "replay_expected.json"
    base = [args.julia, "--startup-file=no", f"--project={args.project}"]

    parent_command = base + [str(HERE / "replay_parent.jl"), str(expected_path)]
    parent = run_phase(parent_command, evidence_dir / "parent.stdout.raw",
                       evidence_dir / "parent.stderr.raw")
    if parent["exit_code"] != 0:
        (evidence_dir / "sequential_replay.json").write_text(
            json.dumps({"parent": parent, "child": None}, indent=2),
            encoding="utf-8",
        )
        return int(parent["exit_code"])

    expected = json.loads(expected_path.read_text(encoding="utf-8"))
    if expected.get("formal_gate_evidence_kind") != "synthetic_local":
        raise RuntimeError("replay parent evidence scope mismatch")
    if expected.get("formal_gate_verified") is not False:
        raise RuntimeError("synthetic replay cannot claim a verified formal gate")

    child_command = base + [
        str(HERE / "replay_child.jl"),
        expected["package_hash"],
        expected["input_hash"],
        expected["ledger_hash"],
        expected["formal_t1_software_acceptance_receipt_hash"],
        expected["candidate_t1_admission_receipt_hash"],
    ]
    child = run_phase(child_command, evidence_dir / "child.stdout.raw",
                      evidence_dir / "child.stderr.raw")
    metadata = {
        "schema": "vnext-t2-sequential-fresh-process-replay-r2",
        "process_overlap": False,
        "parent_natural_exit_before_child_start": True,
        "parent": parent,
        "child": child,
        "formal_gate_evidence_kind": "synthetic_local",
        "formal_gate_verified": False,
        "formal_t2_accepted": False,
    }
    (evidence_dir / "sequential_replay.json").write_text(
        json.dumps(metadata, indent=2), encoding="utf-8")
    sys.stdout.write((evidence_dir / "parent.stdout.raw").read_text(
        encoding="utf-8"))
    sys.stdout.write((evidence_dir / "child.stdout.raw").read_text(
        encoding="utf-8"))
    if child["exit_code"] != 0:
        return int(child["exit_code"])
    print("VNEXT_T2_IDENTITY_RECEIPT_V2_SEQUENTIAL_REPLAY=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
