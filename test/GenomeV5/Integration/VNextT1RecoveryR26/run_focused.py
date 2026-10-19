"""Run one focused T1 command with exact pinned inputs and bounded resources."""

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
EVIDENCE_ROOT = ROOT / "docs/implementation/UP1-04A-VNEXT-T1/recovery_r26_20260922"
HEAVY_NAMES = {"julia.exe", "desc.exe", "mesh.exe", "mpiexec.exe"}


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def file_receipt(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def heavy_processes() -> list[dict[str, object]]:
    return [
        {"pid": process.pid, "name": process.info["name"],
         "cmdline": process.info["cmdline"]}
        for process in psutil.process_iter(["name", "cmdline"])
        if (process.info["name"] or "").lower() in HEAVY_NAMES
    ]


def pinned_receipts(relative_paths: list[str]) -> dict[str, dict[str, object]]:
    receipts: dict[str, dict[str, object]] = {}
    for relative in relative_paths:
        path = (ROOT / relative).resolve()
        path.relative_to(ROOT)
        if not path.is_file():
            raise FileNotFoundError(f"pinned input missing: {relative}")
        normalized = path.relative_to(ROOT).as_posix()
        receipts[normalized] = file_receipt(path)
    return dict(sorted(receipts.items()))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--working-set-limit", type=int, default=2_147_483_648)
    parser.add_argument("--pin", action="append", required=True)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        raise ValueError("command is required after --")

    output = (ROOT / args.out).resolve()
    output.relative_to(EVIDENCE_ROOT)
    output.mkdir(parents=True, exist_ok=False)
    occupied = heavy_processes()
    if occupied:
        raise RuntimeError("serialized lane occupied: " + json.dumps(occupied))

    lock_path = ROOT / "tmp/runtime.lock"
    lock_path.parent.mkdir(exist_ok=True)
    pinned = sorted(set(args.pin + [
        "test/GenomeV5/Integration/VNextT1RecoveryR26/run_focused.py"
    ]))
    before = pinned_receipts(pinned)
    environment = os.environ.copy()
    environment["JULIA_NUM_THREADS"] = "1"
    for assignment in args.env:
        key, value = assignment.split("=", 1)
        environment[key] = value

    process: subprocess.Popen[bytes] | None = None
    samples: list[dict[str, object]] = []
    stop_reason = "natural_exit"
    started_utc = utc()
    started = time.monotonic()
    with lock_path.open("x", encoding="utf-8") as lock:
        json.dump({"owner": "t1_recovery_r26", "controller_pid": os.getpid(),
                   "utc": started_utc, "pinned_inputs": list(before)}, lock)
    try:
        with (output / "stdout.raw").open("wb") as stdout, \
                (output / "stderr.raw").open("wb") as stderr:
            process = subprocess.Popen(
                command, cwd=ROOT, env=environment, stdout=stdout, stderr=stderr,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            observed = psutil.Process(process.pid)
            create_time = observed.create_time()
            start_receipt = {
                "command": command,
                "cwd": str(ROOT),
                "pid": process.pid,
                "started_utc": started_utc,
                "executable": observed.exe(),
                "create_time": create_time,
                "environment": {"JULIA_NUM_THREADS": "1", **dict(
                    item.split("=", 1) for item in args.env)},
                "timeout_seconds": args.timeout,
                "working_set_limit": args.working_set_limit,
                "system_available_bytes": psutil.virtual_memory().available,
                "inputs_before": before,
            }
            (output / "start.json").write_text(
                json.dumps(start_receipt, indent=2), encoding="utf-8")
            with (output / "samples.jsonl").open(
                    "w", encoding="utf-8", buffering=1) as sample_stream:
                while process.poll() is None:
                    try:
                        if observed.create_time() != create_time:
                            stop_reason = "pid_ownership_invalid"
                            break
                        memory = observed.memory_info()
                        sample = {
                            "utc": utc(), "pid": process.pid,
                            "working_set_bytes": memory.rss,
                            "private_bytes": memory.private,
                            "cpu_seconds": sum(observed.cpu_times()[:2]),
                        }
                        samples.append(sample)
                        sample_stream.write(json.dumps(sample) + "\n")
                        if memory.rss >= args.working_set_limit:
                            stop_reason = "working_set_hard_ceiling"
                            break
                        if time.monotonic() - started >= args.timeout:
                            stop_reason = "wall_timeout"
                            break
                    except psutil.NoSuchProcess:
                        break
                    time.sleep(0.25)
                if process.poll() is None and stop_reason != "natural_exit":
                    for child in observed.children(recursive=True):
                        child.kill()
                    process.kill()
                exit_code = process.wait()

        after = pinned_receipts(pinned)
        changes = [relative for relative in before if before[relative] != after[relative]]
        residual = heavy_processes()
        final = {
            "pid": process.pid,
            "command": command,
            "cwd": str(ROOT),
            "started_utc": started_utc,
            "ended_utc": utc(),
            "seconds": time.monotonic() - started,
            "exit_code": exit_code,
            "stop_reason": stop_reason,
            "peak_working_set_bytes": max(
                (int(sample["working_set_bytes"]) for sample in samples), default=0),
            "peak_private_bytes": max(
                (int(sample["private_bytes"]) for sample in samples), default=0),
            "stdout": file_receipt(output / "stdout.raw"),
            "stderr": file_receipt(output / "stderr.raw"),
            "inputs_after": after,
            "pinned_input_changes": changes,
            "residual_heavy_processes": residual,
            "actual_model_attestation": "unavailable",
        }
        (output / "final.json").write_text(
            json.dumps(final, indent=2), encoding="utf-8")
        print(json.dumps(final))
        return 0 if (exit_code == 0 and stop_reason == "natural_exit"
                     and not changes and not residual) else 1
    finally:
        if process is not None and process.poll() is None:
            process.kill()
            process.wait()
        lock_path.unlink(missing_ok=True)


if __name__ == "__main__":
    raise SystemExit(main())
