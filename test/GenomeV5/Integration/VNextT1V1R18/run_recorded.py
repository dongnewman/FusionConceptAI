"""One serial command with authoritative exit, raw streams and external memory samples."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import subprocess
import time
import psutil

ROOT = Path(__file__).resolve().parents[4]
def utc():
    return datetime.now(timezone.utc).isoformat()
def sha(path):
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
def heavy():
    return [{"pid": p.pid, "name": p.info["name"], "cmdline": p.info["cmdline"]}
            for p in psutil.process_iter(["name", "cmdline"])
            if (p.info["name"] or "").lower() in ("julia.exe", "desc.exe", "mesh.exe", "mpiexec.exe")]
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--timeout", type=float, default=1800)
    parser.add_argument("--env", action="append", default=[])
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    out = (ROOT / args.out).resolve()
    out.relative_to(ROOT / "docs/implementation/UP1-04A-VNEXT-T1")
    out.mkdir(exist_ok=False)
    if heavy():
        raise RuntimeError("serial lane occupied: " + json.dumps(heavy()))
    lockpath = ROOT / "tmp/runtime.lock"
    lockpath.parent.mkdir(exist_ok=True)
    lock = lockpath.open("x", encoding="utf-8")
    lock.write(json.dumps({"owner": "t1_astra_xhigh_closeout", "controller_pid": os.getpid(), "utc": utc()}))
    lock.close()
    source_paths = sorted(p for folder in ("src", "test") for p in (ROOT / folder).rglob("*")
                          if p.is_file() and "__pycache__" not in p.parts)
    before = {p.relative_to(ROOT).as_posix(): sha(p) for p in source_paths}
    env = os.environ.copy()
    env["JULIA_NUM_THREADS"] = "1"
    for item in args.env:
        key, value = item.split("=", 1)
        env[key] = value
    p = None
    samples = []
    reason = "natural_exit"
    started = utc()
    start = time.monotonic()
    try:
        with (out / "stdout.raw").open("wb") as stdout, (out / "stderr.raw").open("wb") as stderr:
            p = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stdout, stderr=stderr,
                                 creationflags=subprocess.CREATE_NO_WINDOW)
            proc = psutil.Process(p.pid)
            created = proc.create_time()
            receipt = {"command": command, "cwd": str(ROOT), "pid": p.pid,
                       "started_utc": started, "environment": {"JULIA_NUM_THREADS": "1", **dict(x.split("=", 1) for x in args.env)},
                       "executable": proc.exe(), "create_time": created,
                       "timeout_seconds": args.timeout, "working_set_limit": 2147483648,
                       "inputs_before": before}
            (out / "start.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
            with (out / "samples.jsonl").open("w", encoding="utf-8", buffering=1) as stream:
                while p.poll() is None:
                    try:
                        if proc.create_time() != created:
                            reason = "pid_ownership_invalid"
                            break
                        mem = proc.memory_info()
                        sample = {"utc": utc(), "pid": p.pid, "working_set_bytes": mem.rss,
                                  "private_bytes": mem.private, "cpu_seconds": sum(proc.cpu_times()[:2])}
                        samples.append(sample)
                        stream.write(json.dumps(sample) + "\n")
                        if mem.rss >= 2147483648:
                            reason = "working_set_hard_ceiling"
                            break
                        if time.monotonic() - start >= args.timeout:
                            reason = "wall_timeout"
                            break
                    except psutil.NoSuchProcess:
                        break
                    time.sleep(0.25)
                if p.poll() is None and reason != "natural_exit":
                    for child in proc.children(recursive=True):
                        child.kill()
                    p.kill()
                exit_code = p.wait()
        after = {p.relative_to(ROOT).as_posix(): sha(p) for p in source_paths}
        changes = [rel for rel in before if before[rel] != after[rel]]
        final = {"pid": p.pid, "command": command, "cwd": str(ROOT), "started_utc": started,
                 "ended_utc": utc(), "seconds": time.monotonic() - start,
                 "exit_code": exit_code, "stop_reason": reason,
                 "peak_working_set_bytes": max((s["working_set_bytes"] for s in samples), default=0),
                 "peak_private_bytes": max((s["private_bytes"] for s in samples), default=0),
                 "stdout": sha(out / "stdout.raw"), "stderr": sha(out / "stderr.raw"),
                 "source_changes": changes, "residual_heavy_processes": heavy(),
                 "actual_model_attestation": "unavailable"}
        (out / "final.json").write_text(json.dumps(final, indent=2), encoding="utf-8")
        print(json.dumps(final))
        return 0 if exit_code == 0 and reason == "natural_exit" and not changes and not heavy() else 1
    finally:
        if p is not None and p.poll() is None:
            p.kill()
            p.wait()
        lockpath.unlink()
if __name__ == "__main__":
    raise SystemExit(main())
