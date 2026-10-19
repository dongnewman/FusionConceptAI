"""Bounded no-Julia Windows SPI + Popen handle smoke for R23."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
TABLE_PATH = HERE / "native_process_table_r23_v1.py"
SUPERVISOR_PATH = HERE / "supervise_r16_root_audit_r23_v1.py"


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


table = _load("native_process_table_r23_v1", TABLE_PATH)
supervisor = _load("supervise_r16_root_audit_r23_v1", SUPERVISOR_PATH)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if os.name != "nt":
        raise RuntimeError("R23 native process table host smoke requires Windows")
    import psutil

    before = table.query_native_process_table()
    heavy_before = supervisor.global_heavy_processes(before)
    if heavy_before:
        raise RuntimeError(f"pre-smoke heavy inventory is not empty: {heavy_before!r}")

    argv = [sys.executable, "-B", "-c", "import time; time.sleep(0.8)"]
    popen = subprocess.Popen(
        argv, cwd=str(HERE.parents[3]), stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL, shell=False,
        creationflags=subprocess.CREATE_NO_WINDOW,
    )
    identity: tuple[int, int] | None = None
    sample: dict[str, Any] | None = None
    exit_receipt: dict[str, Any] | None = None
    owned_sample_handles: list[int] = []
    try:
        launch_snapshot = table.query_native_process_table()
        identity = supervisor.bind_popen_generation(popen, launch_snapshot)
        time.sleep(0.12)

        def resource_reader(pid: int) -> dict[str, Any]:
            process = psutil.Process(pid)
            memory = process.memory_info()
            cpu = process.cpu_times()
            return {
                "rss_bytes": memory.rss,
                "cpu_user_seconds": cpu.user,
                "cpu_system_seconds": cpu.system,
                "cmdline": process.cmdline(),
            }

        def exact_sample_handle(row: Any) -> Any:
            if row.identity.pid == identity[0]:
                return popen._handle
            handle = table.open_exact_process_handle(row)
            owned_sample_handles.append(handle)
            return handle

        sample = supervisor.sample_process_tree(
            identity,
            snapshot_provider=table.query_native_process_table,
            handle_provider=exact_sample_handle,
            resource_reader=resource_reader,
            handle_identity_reader=table.read_process_handle_identity,
            sample_index=1,
            elapsed_seconds=0.12,
        )
        if sample.get("complete") is not True:
            raise RuntimeError("R23 sample failed: " + json.dumps(sample, sort_keys=True))
        for owned_handle in owned_sample_handles:
            table.close_process_handle(owned_handle)
        owned_sample_handles.clear()

        exit_receipt = supervisor.wait_exact_process(
            popen._handle,
            identity,
            snapshot_provider=table.query_native_process_table,
            handle_identity_reader=table.read_process_handle_identity,
            wait_for_exit=table.wait_for_process_exit,
            exit_code_reader=table.process_exit_code,
            timeout_seconds=5.0,
        )
        if exit_receipt.get("complete") is not True:
            raise RuntimeError("R23 exact wait failed: " + json.dumps(exit_receipt, sort_keys=True))
        python_exit_code = popen.wait(timeout=5.0)
        if type(python_exit_code) is not int or python_exit_code != exit_receipt.get("exit_code"):
            raise RuntimeError("Popen collection disagrees with exact handle exit receipt")

        final_snapshot = table.query_native_process_table()
        residual = supervisor.audit_residual_identities((identity,), final_snapshot)
        if residual.get("complete") is not True or residual.get("residual_clear") is not True:
            raise RuntimeError("R23 final residual audit failed: " + json.dumps(residual, sort_keys=True))
        heavy_after = supervisor.global_heavy_processes(final_snapshot)
        if heavy_after:
            raise RuntimeError(f"post-smoke heavy inventory is not empty: {heavy_after!r}")

        result = {
            "schema": "native-g1g2-r23-host-smoke-v1",
            "status": "bounded_host_smoke_pass",
            "runtime_dispatch": "disabled_pending_independent_review_and_root_grant",
            "julia_started": False,
            "solver_started": False,
            "numerical_status": "not_established",
            "physical_status": "unknown",
            "numerical_credit": False,
            "actual_model": "not_visible_to_worker",
            "requested_model": "gpt-6-luna",
            "requested_reasoning_effort": "max",
            "host_process_table": table.smoke_summary(final_snapshot),
            "popen_bound_identity": {"pid": identity[0], "create_time_100ns": identity[1]},
            "launch_argv": argv,
            "sample": sample,
            "natural_exit_receipt": exit_receipt,
            "python_return_code": python_exit_code,
            "residual_audit": residual,
            "heavy_inventory_before": list(heavy_before),
            "heavy_inventory_after": list(heavy_after),
            "source_sha256": {
                "process_table_helper": _sha(TABLE_PATH),
                "supervisor": _sha(SUPERVISOR_PATH),
                "host_smoke": _sha(Path(__file__).resolve()),
            },
        }
        print(json.dumps(result, sort_keys=True, separators=(",", ":")))
        return 0
    except Exception:
        if popen.poll() is None and identity is not None:
            cleanup = supervisor.signal_exact_process(
                popen._handle, identity,
                snapshot_provider=table.query_native_process_table,
                handle_identity_reader=table.read_process_handle_identity,
                signal_sender=table.terminate_process_handle,
                wait_for_exit=table.wait_for_process_exit,
                exit_code_reader=table.process_exit_code,
                timeout_seconds=5.0,
            )
            print(json.dumps({"cleanup_receipt": cleanup}, sort_keys=True))
        raise
    finally:
        for owned_handle in owned_sample_handles:
            try:
                table.close_process_handle(owned_handle)
            except Exception as close_exc:
                print(json.dumps({
                    "sample_handle_cleanup_failure": {
                        "type": type(close_exc).__name__,
                        "message": str(close_exc),
                    },
                    "numerical_credit": False,
                }, sort_keys=True))


if __name__ == "__main__":
    raise SystemExit(main())
