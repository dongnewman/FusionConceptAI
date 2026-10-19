"""Run one authorized R26 child with exact-input hashing and bounded RSS."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys
import time

import psutil


ROOT = Path(__file__).resolve().parents[4]
EVIDENCE_ROOT = (ROOT / "docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922").resolve()
HEAVY_NAMES = {"julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh", "mpiexec.exe", "mpiexec"}


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def digest(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest().upper()}


def resolve_relative(value: str, *, must_exist: bool = True) -> Path:
    rel = Path(value)
    if rel.is_absolute() or ".." in rel.parts:
        raise ValueError(f"path must be repository-relative without traversal: {value}")
    path = (ROOT / rel).resolve()
    path.relative_to(ROOT.resolve())
    if must_exist and not path.is_file():
        raise ValueError(f"input is not an existing file: {value}")
    return path


def heavy_processes() -> list[dict[str, object]]:
    rows = []
    for process in psutil.process_iter(["name", "cmdline", "create_time"]):
        name = (process.info.get("name") or "").lower()
        if name in HEAVY_NAMES:
            rows.append({"pid": process.pid, "name": process.info.get("name"),
                "cmdline": process.info.get("cmdline"),
                "create_time": process.info.get("create_time")})
    return rows


def tree_rss(process: psutil.Process) -> tuple[int, list[int]]:
    members = [process]
    try:
        members.extend(process.children(recursive=True))
    except psutil.Error:
        pass
    total, pids = 0, []
    for member in members:
        try:
            total += member.memory_info().rss
            pids.append(member.pid)
        except psutil.Error:
            pass
    return total, pids


def kill_tree(process: psutil.Process) -> None:
    try:
        children = process.children(recursive=True)
    except psutil.Error:
        children = []
    for child in reversed(children):
        try:
            child.kill()
        except psutil.Error:
            pass
    try:
        process.kill()
    except psutil.Error:
        pass


def write_new(path: Path, value: object) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--max-rss-bytes", type=int, default=2**31)
    parser.add_argument("--input", action="append", required=True)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a child command is required after --")
    if args.timeout <= 0 or args.max_rss_bytes <= 0:
        parser.error("timeout and RSS ceiling must be positive")

    out_rel = Path(args.out)
    if out_rel.is_absolute() or ".." in out_rel.parts:
        raise ValueError("output must be repository-relative without traversal")
    out = (ROOT / out_rel).resolve()
    out.relative_to(EVIDENCE_ROOT)
    if out == EVIDENCE_ROOT:
        raise ValueError("broad evidence root is not a run directory")

    input_paths = [resolve_relative(value) for value in args.input]
    input_keys = [path.relative_to(ROOT).as_posix() for path in input_paths]
    if len(input_keys) != len(set(input_keys)):
        raise ValueError("duplicate input path")
    runner_key = Path(__file__).resolve().relative_to(ROOT).as_posix()
    if runner_key not in input_keys:
        raise ValueError("runner must be frozen as an explicit input")

    baseline_heavy = heavy_processes()
    if baseline_heavy:
        raise RuntimeError("serialized resource lane is occupied: " + json.dumps(baseline_heavy))

    out.mkdir(parents=True, exist_ok=False)
    before = {key: digest(path) for key, path in zip(input_keys, input_paths)}
    environment = os.environ.copy()
    environment["JULIA_NUM_THREADS"] = "1"
    explicit_env = {"JULIA_NUM_THREADS": "1"}
    for item in args.env:
        key, value = item.split("=", 1)
        environment[key] = value
        explicit_env[key] = value

    started_utc = utc()
    started = time.monotonic()
    samples: list[dict[str, object]] = []
    reason = "natural_exit"
    process = None
    with (out / "stdout.raw").open("xb") as stdout, (out / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(command, cwd=ROOT, env=environment,
            stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        observed = psutil.Process(process.pid)
        create_time = observed.create_time()
        write_new(out / "start.json", {"schema": "r26_exact_input_run_v1",
            "owner": args.owner, "command": command, "cwd": str(ROOT),
            "pid": process.pid, "process_create_time": create_time,
            "started_utc": started_utc, "environment": explicit_env,
            "timeout_seconds": args.timeout,
            "working_set_limit_bytes": args.max_rss_bytes,
            "inputs_before": before, "baseline_heavy_processes": baseline_heavy})
        with (out / "samples.jsonl").open("x", encoding="utf-8", newline="\n", buffering=1) as stream:
            while process.poll() is None:
                try:
                    if observed.create_time() != create_time:
                        reason = "pid_ownership_invalid"
                        break
                    rss, pids = tree_rss(observed)
                    sample = {"utc": utc(), "root_pid": process.pid,
                        "process_tree_pids": pids, "process_tree_rss_bytes": rss,
                        "elapsed_seconds": time.monotonic() - started}
                    samples.append(sample)
                    stream.write(json.dumps(sample) + "\n")
                    if rss >= args.max_rss_bytes:
                        reason = "working_set_hard_ceiling"
                        break
                    if time.monotonic() - started >= args.timeout:
                        reason = "wall_timeout"
                        break
                except psutil.NoSuchProcess:
                    break
                time.sleep(0.2)
            if process.poll() is None and reason != "natural_exit":
                kill_tree(observed)
            exit_code = process.wait()

    after = {key: digest(path) for key, path in zip(input_keys, input_paths)}
    input_changes = sorted(key for key in before if before[key] != after[key])
    final_heavy = heavy_processes()
    stdout_hash = digest(out / "stdout.raw")
    stderr_hash = digest(out / "stderr.raw")
    final = {"schema": "r26_exact_input_run_v1", "owner": args.owner,
        "pid": process.pid, "command": command, "cwd": str(ROOT),
        "started_utc": started_utc, "ended_utc": utc(),
        "elapsed_seconds": time.monotonic() - started,
        "exit_code": exit_code, "stop_reason": reason,
        "peak_process_tree_rss_bytes": max((row["process_tree_rss_bytes"] for row in samples), default=0),
        "stdout": stdout_hash, "stderr": stderr_hash,
        "inputs_before": before, "inputs_after": after,
        "input_changes": input_changes,
        "new_or_residual_heavy_processes": final_heavy,
        "actual_model_attestation": "unavailable"}
    write_new(out / "final.json", final)
    print(json.dumps(final), flush=True)
    return 0 if (exit_code == 0 and reason == "natural_exit" and
        not input_changes and not final_heavy) else 1


if __name__ == "__main__":
    raise SystemExit(main())
