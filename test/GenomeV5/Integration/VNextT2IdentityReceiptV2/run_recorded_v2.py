"""Run one frozen T2 command with whole-process-tree resource accounting."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import time

import psutil


ROOT = Path(__file__).resolve().parents[4]
EVIDENCE_ROOT = ROOT / "docs/implementation/UP1-04A-VNEXT-T2"
HEAVY_NAMES = {"julia.exe", "desc.exe", "mesh.exe", "mpiexec.exe"}


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def receipt(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def heavy_processes() -> list[dict[str, object]]:
    rows = []
    for process in psutil.process_iter(["name", "cmdline", "create_time"]):
        if (process.info["name"] or "").lower() in HEAVY_NAMES:
            rows.append({"pid": process.pid, "name": process.info["name"],
                         "cmdline": process.info["cmdline"],
                         "create_time": process.info["create_time"]})
    return rows


def pinned_receipts(paths: list[str]) -> dict[str, dict[str, object]]:
    rows = {}
    for relative in sorted(set(paths)):
        path = (ROOT / relative).resolve()
        path.relative_to(ROOT)
        if not path.is_file():
            raise FileNotFoundError(relative)
        rows[path.relative_to(ROOT).as_posix()] = receipt(path)
    return rows


def process_tree_sample(root: psutil.Process) -> dict[str, object]:
    processes = [root]
    try:
        processes.extend(root.children(recursive=True))
    except psutil.Error:
        pass
    rows = []
    for process in processes:
        try:
            memory = process.memory_info()
            cpu = process.cpu_times()
            rows.append({
                "pid": process.pid,
                "create_time": process.create_time(),
                "name": process.name(),
                "working_set_bytes": int(memory.rss),
                "private_bytes": int(getattr(memory, "private", memory.rss)),
                "cpu_seconds": float(cpu.user + cpu.system),
            })
        except psutil.Error:
            continue
    return {
        "utc": utc(),
        "process_count": len(rows),
        "working_set_bytes": sum(row["working_set_bytes"] for row in rows),
        "private_bytes": sum(row["private_bytes"] for row in rows),
        "cpu_seconds": sum(row["cpu_seconds"] for row in rows),
        "processes": rows,
    }


def kill_tree(root: psutil.Process) -> None:
    try:
        children = root.children(recursive=True)
    except psutil.Error:
        children = []
    for process in reversed(children):
        try:
            process.kill()
        except psutil.Error:
            pass
    try:
        root.kill()
    except psutil.Error:
        pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--working-set-limit", type=int,
                        default=2_147_483_648)
    parser.add_argument("--pin", action="append", required=True)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("--formal-gate-evidence-kind",
                        choices=("synthetic_local", "formal_t1_actual"),
                        default="synthetic_local")
    parser.add_argument("--formal-gate-verified", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        raise ValueError("command is required after --")
    if (args.formal_gate_evidence_kind == "synthetic_local" and
            args.formal_gate_verified):
        raise ValueError("synthetic local evidence cannot be marked verified")
    if (args.formal_gate_evidence_kind == "formal_t1_actual" and
            not args.formal_gate_verified):
        raise ValueError("actual formal T1 evidence must be runner-verified")

    output = (ROOT / args.out).resolve()
    output.relative_to(EVIDENCE_ROOT)
    output.mkdir(parents=True, exist_ok=False)
    occupied = heavy_processes()
    if occupied:
        raise RuntimeError("serialized lane occupied: " + json.dumps(occupied))

    runner_relative = Path(__file__).resolve().relative_to(ROOT).as_posix()
    pins = sorted(set(args.pin + [runner_relative]))
    before = pinned_receipts(pins)
    environment = os.environ.copy()
    environment["JULIA_NUM_THREADS"] = "1"
    for assignment in args.env:
        key, value = assignment.split("=", 1)
        environment[key] = value

    lock_path = ROOT / "tmp/runtime.lock"
    lock_path.parent.mkdir(exist_ok=True)
    process: subprocess.Popen[bytes] | None = None
    root_process: psutil.Process | None = None
    samples: list[dict[str, object]] = []
    stop_reason = "natural_exit"
    started_utc = utc()
    started = time.monotonic()
    with lock_path.open("x", encoding="utf-8") as lock:
        json.dump({"owner": "vnext_t2_identity_receipt_v2",
                   "controller_pid": os.getpid(), "utc": started_utc,
                   "pinned_inputs": list(before)}, lock)
    try:
        with (output / "stdout.raw").open("wb") as stdout, \
                (output / "stderr.raw").open("wb") as stderr:
            process = subprocess.Popen(
                command, cwd=ROOT, env=environment, stdout=stdout,
                stderr=stderr, creationflags=subprocess.CREATE_NO_WINDOW)
            root_process = psutil.Process(process.pid)
            root_create_time = root_process.create_time()
            start = {
                "command": command, "cwd": str(ROOT), "pid": process.pid,
                "root_create_time": root_create_time,
                "started_utc": started_utc,
                "environment": {"JULIA_NUM_THREADS": "1", **dict(
                    item.split("=", 1) for item in args.env)},
                "timeout_seconds": args.timeout,
                "working_set_limit_process_tree_bytes":
                    args.working_set_limit,
                "formal_gate_evidence_kind":
                    args.formal_gate_evidence_kind,
                "formal_gate_verified": args.formal_gate_verified,
                "system_available_bytes": psutil.virtual_memory().available,
                "inputs_before": before,
            }
            (output / "start.json").write_text(
                json.dumps(start, indent=2), encoding="utf-8")
            with (output / "samples.jsonl").open(
                    "w", encoding="utf-8", buffering=1) as stream:
                while process.poll() is None:
                    try:
                        if root_process.create_time() != root_create_time:
                            stop_reason = "pid_ownership_invalid"
                            break
                        sample = process_tree_sample(root_process)
                        samples.append(sample)
                        stream.write(json.dumps(sample) + "\n")
                        if sample["working_set_bytes"] >= args.working_set_limit:
                            stop_reason = "process_tree_working_set_hard_ceiling"
                            break
                        if time.monotonic() - started >= args.timeout:
                            stop_reason = "wall_timeout"
                            break
                    except psutil.NoSuchProcess:
                        break
                    time.sleep(0.25)
                if process.poll() is None and stop_reason != "natural_exit":
                    kill_tree(root_process)
                exit_code = process.wait()

        after = pinned_receipts(pins)
        changes = [path for path in before if before[path] != after[path]]
        residual = heavy_processes()
        final = {
            "pid": process.pid, "command": command, "cwd": str(ROOT),
            "started_utc": started_utc, "ended_utc": utc(),
            "seconds": time.monotonic() - started, "exit_code": exit_code,
            "stop_reason": stop_reason,
            "resource_scope": "root_and_recursive_child_process_tree",
            "peak_process_tree_working_set_bytes": max(
                (int(row["working_set_bytes"]) for row in samples),
                default=0),
            "peak_process_tree_private_bytes": max(
                (int(row["private_bytes"]) for row in samples), default=0),
            "peak_process_count": max(
                (int(row["process_count"]) for row in samples), default=0),
            "stdout": receipt(output / "stdout.raw"),
            "stderr": receipt(output / "stderr.raw"),
            "inputs_after": after, "pinned_input_changes": changes,
            "residual_heavy_processes": residual,
            "actual_model_attestation": "unavailable",
            "formal_gate_evidence_kind":
                args.formal_gate_evidence_kind,
            "formal_gate_verified": args.formal_gate_verified,
            "formal_t2_accepted": False,
        }
        (output / "final.json").write_text(
            json.dumps(final, indent=2), encoding="utf-8")
        print(json.dumps(final))
        return 0 if (exit_code == 0 and stop_reason == "natural_exit"
                     and not changes and not residual) else 1
    finally:
        if process is not None and process.poll() is None:
            assert root_process is not None
            kill_tree(root_process)
            process.wait()
        lock_path.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
