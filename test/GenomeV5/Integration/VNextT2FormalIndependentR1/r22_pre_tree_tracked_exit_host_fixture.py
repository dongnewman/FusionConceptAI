from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


def write_json(path: Path, value: Any) -> None:
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, sort_keys=True) + "\n",
                         encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def wait_for_file(path: Path, seconds: float) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if path.is_file():
            return True
        time.sleep(0.01)
    return path.is_file()


def root_role(phase_dir: Path) -> int:
    start_child = phase_dir / "start_child.json"
    target_ready = phase_dir / "target_ready.json"
    target_release = phase_dir / "target_release.json"
    target_exit = phase_dir / "target_parent_wait.json"
    root_release = phase_dir / "root_release.json"
    write_json(phase_dir / "root_ready.json", {
        "schema": "vnext-t2-r22-host-fixture-root-ready-r1",
        "pid": os.getpid(),
    })
    if not wait_for_file(start_child, 10.0):
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "root_wait_start_child", "pid": os.getpid()})
        return 91

    creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    child = subprocess.Popen(
        [sys.executable, "-B", str(Path(__file__).resolve()),
         "--role", "tracked-child", "--phase-dir", str(phase_dir)],
        cwd=str(phase_dir.parent), stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=creationflags,
    )
    if not wait_for_file(target_ready, 8.0):
        if child.poll() is None:
            child.terminate()
        code = child.wait(timeout=5.0)
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "root_wait_target_ready", "target_pid": child.pid,
            "cleanup_exit_code": code})
        return 92
    try:
        code = child.wait(timeout=12.0)
    except subprocess.TimeoutExpired:
        if child.poll() is None:
            child.terminate()
        code = child.wait(timeout=5.0)
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "root_wait_target_natural_exit", "target_pid": child.pid,
            "cleanup_exit_code": code})
        return 93
    write_json(target_exit, {
        "schema": "vnext-t2-r22-host-fixture-target-parent-wait-r1",
        "target_pid": child.pid,
        "wait_exit_code": code,
        "target_natural_exit_receipt": "target_natural_exit.json",
        "parent_reaped_target": True,
    })
    if code != 0:
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "root_target_exit_code", "target_pid": child.pid,
            "wait_exit_code": code})
        return 94
    if not wait_for_file(root_release, 12.0):
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "root_wait_release", "pid": os.getpid()})
        return 95
    write_json(phase_dir / "root_natural_exit.json", {
        "schema": "vnext-t2-r22-host-fixture-root-natural-exit-r1",
        "pid": os.getpid(), "target_pid": child.pid,
        "target_wait_exit_code": code,
        "root_release_marker_seen": True,
        "natural_exit": True,
    })
    return 0


def tracked_child_role(phase_dir: Path) -> int:
    release = phase_dir / "target_release.json"
    pid = os.getpid()
    write_json(phase_dir / "target_ready.json", {
        "schema": "vnext-t2-r22-host-fixture-target-ready-r1", "pid": pid})
    if not wait_for_file(release, 12.0):
        write_json(phase_dir / "fixture_failure.json", {
            "stage": "target_wait_release", "pid": pid})
        return 96
    write_json(phase_dir / "target_natural_exit.json", {
        "schema": "vnext-t2-r22-host-fixture-target-natural-exit-r1",
        "pid": pid,
        "release_marker_seen": True,
        "exit_path": "normal_return",
        "natural_exit": True,
    })
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--role", choices=("root", "tracked-child"), required=True)
    parser.add_argument("--phase-dir", type=Path, required=True)
    args = parser.parse_args()
    args.phase_dir = args.phase_dir.resolve()
    args.phase_dir.mkdir(parents=True, exist_ok=True)
    if args.role == "root":
        return root_role(args.phase_dir)
    return tracked_child_role(args.phase_dir)


if __name__ == "__main__":
    raise SystemExit(main())
