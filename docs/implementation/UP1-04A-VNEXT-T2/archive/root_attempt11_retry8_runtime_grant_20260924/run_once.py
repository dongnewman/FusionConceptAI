"""One root-granted invocation of the frozen T2 retry8 controller."""

from __future__ import annotations

import csv
from datetime import datetime, timezone
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import sys

import psutil


REPO = Path(r"D:\006-Programing\LMC\FusionConceptAI")
FREEZE = REPO / "docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry8"
GRANT = REPO / "docs/implementation/UP1-04A-VNEXT-T2/archive/root_attempt11_retry8_runtime_grant_20260924"
PROTOCOL = FREEZE / "protocol.json"
PROTOCOL_SHA256 = "e5ddc50030d82c1532dd18538f06adabcc7b10d3500241075c4062a813c5b965"
COMMAND = FREEZE / "command_argv.json"
COMMAND_SHA256 = "a18d3cc0b4f9ceb158ae53cb59c9d47b75ce1f71ade13456eaa1ff775c608768"
SNAPSHOT = FREEZE / "freeze_snapshot.json"
SNAPSHOT_SHA256 = "8da9bce3f77842417ac9fb8fcd51fe461fb312bcadac056c5171f56b93aa9701"
STATIC_QA = FREEZE / "static_qa.json"
STATIC_QA_SHA256 = "ed0e3ad8a800cd6647bcb3acca1405025c6b65631f662c26c509bfba178ed92a"
HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
BASELINE = REPO / "docs/implementation/GOAL-EXECUTION-20260923/archive/root_baseline_r1/dirty_tracked_hashes.json"
OUTPUT = REPO / "docs/implementation/UP1-04A-VNEXT-T2/formal_t2_actual_negative_r6_attempt11_retry8"


def digest(path: Path) -> str:
    h = sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def check_pin(path: Path, expected_bytes: int, expected_sha256: str) -> None:
    if not path.is_file() or path.stat().st_size != expected_bytes or digest(path) != expected_sha256:
        raise RuntimeError(f"frozen pin drift: {path}")


def process_name(process: psutil.Process) -> str:
    name = process.info.get("name")
    if isinstance(name, str) and name:
        return name
    result = subprocess.run(
        ["tasklist", "/FI", f"PID eq {process.pid}", "/FO", "CSV", "/NH"],
        capture_output=True, text=True, check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(f"process-name fallback failed for PID {process.pid}")
    rows = list(csv.reader(result.stdout.splitlines()))
    if len(rows) != 1 or len(rows[0]) != 5 or rows[0][1] != str(process.pid) or not rows[0][0]:
        raise RuntimeError(f"process-name fallback incomplete for PID {process.pid}")
    return rows[0][0]


def heavy_inventory() -> list[dict[str, object]]:
    active: list[dict[str, object]] = []
    for process in psutil.process_iter(["name", "cmdline"]):
        try:
            name = process_name(process)
            command = process.info.get("cmdline")
        except psutil.NoSuchProcess:
            continue
        if name.lower() == "julia.exe":
            active.append({"pid": process.pid, "name": name, "cmdline": command})
        elif name.lower() in {"python.exe", "pythonw.exe"}:
            if not isinstance(command, list):
                raise RuntimeError(f"Python command line unreadable for PID {process.pid}")
            joined = " ".join(command).lower()
            if any(token in joined for token in (
                "independent_negative_controller", "freegs_process_supervisor",
                "runtime_v4_freegs_axisymmetric_profile_runner", "run_replay_staged_v14",
                "supervise_r16_root_audit", "run_native_g1g2_diffusion",
            )):
                active.append({"pid": process.pid, "name": name, "cmdline": command})
    return active


def main() -> int:
    if len(sys.argv) != 1:
        raise SystemExit("no arguments accepted")
    for path, expected in (
        (PROTOCOL, PROTOCOL_SHA256), (COMMAND, COMMAND_SHA256),
        (SNAPSHOT, SNAPSHOT_SHA256), (STATIC_QA, STATIC_QA_SHA256),
    ):
        if digest(path) != expected:
            raise RuntimeError(f"frozen artifact drift: {path}")
    protocol = json.loads(PROTOCOL.read_text(encoding="utf-8"))
    command = json.loads(COMMAND.read_text(encoding="utf-8"))
    if protocol["repository_head"] != HEAD or subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=REPO, text=True,
    ).strip() != HEAD:
        raise RuntimeError("HEAD drift")
    inputs = protocol["inputs"]
    if not isinstance(inputs, dict) or len(inputs) != 459 or protocol["input_count"] != 459:
        raise RuntimeError("T2 input cardinality drift")
    for rel, pin in inputs.items():
        if rel != pin["path"]:
            raise RuntimeError(f"T2 input path mismatch: {rel}")
        check_pin(REPO / rel, pin["bytes"], pin["sha256"])
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    if len(baseline) != 40:
        raise RuntimeError("protected dirty baseline cardinality drift")
    for pin in baseline:
        check_pin(REPO / pin["path"], pin["length"], pin["sha256"])
    if protocol["planned_evidence_directory"] != str(OUTPUT.relative_to(REPO)).replace("\\", "/"):
        raise RuntimeError("T2 evidence directory drift")
    if OUTPUT.exists():
        raise RuntimeError("fresh exact T2 output leaf required")
    if protocol["status"] != "frozen_static_ready_not_executed" or protocol["formal_t2_accepted"] is not False:
        raise RuntimeError("T2 frozen status drift")
    argv = command["argv"]
    if not isinstance(argv, list) or len(argv) != 27:
        raise RuntimeError("T2 argv shape drift")
    if Path(argv[0]).resolve(strict=True) != Path(sys.executable).resolve(strict=True):
        raise RuntimeError("T2 controller interpreter drift")
    if Path(argv[2]).resolve(strict=True) != (REPO / protocol["controller_path"]).resolve(strict=True):
        raise RuntimeError("T2 controller path drift")
    if argv[argv.index("--protocol") + 1] != str(PROTOCOL):
        raise RuntimeError("T2 protocol argv drift")
    if argv[argv.index("--protocol-sha256") + 1] != PROTOCOL_SHA256:
        raise RuntimeError("T2 protocol SHA argv drift")
    if argv[argv.index("--evidence-dir") + 1] != str(OUTPUT):
        raise RuntimeError("T2 evidence argv drift")
    if command["environment"] != {
        "JULIA_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "PYTHONDONTWRITEBYTECODE": "1",
    } or command["working_directory"] != str(REPO):
        raise RuntimeError("T2 environment/cwd drift")
    active = heavy_inventory()
    if active:
        raise RuntimeError(f"heavy lane occupied: {active}")

    start_path = GRANT / "start.json"
    with start_path.open("x", encoding="utf-8") as stream:
        json.dump({
            "schema": "root-t2-attempt11-retry8-grant-start-v1", "utc": utc(),
            "head": HEAD, "protocol_sha256": PROTOCOL_SHA256,
            "command_sha256": COMMAND_SHA256, "snapshot_sha256": SNAPSHOT_SHA256,
            "static_qa_sha256": STATIC_QA_SHA256,
            "checked_input_count": len(inputs), "protected_dirty_pin_count": len(baseline),
            "active_heavy_processes_before": active, "argv": argv,
            "environment_overrides": command["environment"], "cwd": str(REPO),
            "output_leaf_preexisting": False, "formal_t2_accepted": False,
        }, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    env = os.environ.copy()
    env.update(command["environment"])
    stdout_path = GRANT / "invocation.stdout.raw"
    stderr_path = GRANT / "invocation.stderr.raw"
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        child = subprocess.Popen(argv, cwd=REPO, env=env, stdout=stdout,
                                 stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
        child_pid = child.pid
        child_exit = child.wait()
    exit_path = GRANT / "invocation.exit.txt"
    exit_path.write_text(f"{child_exit}\n", encoding="ascii")
    with (GRANT / "invocation.json").open("x", encoding="utf-8") as stream:
        json.dump({
            "schema": "root-t2-attempt11-retry8-invocation-v1",
            "start_sha256": digest(start_path), "finished_utc": utc(),
            "controller_pid": child_pid, "controller_exit_code": child_exit,
            "stdout_sha256": digest(stdout_path), "stderr_sha256": digest(stderr_path),
            "exit_sha256": digest(exit_path), "output_leaf_present": OUTPUT.exists(),
            "formal_t2_accepted_by_root": False,
        }, stream, ensure_ascii=False, indent=2)
        stream.write("\n")
    return child_exit


if __name__ == "__main__":
    raise SystemExit(main())
