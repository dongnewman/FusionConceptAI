from __future__ import annotations

import hashlib
import json
import platform
import sys
import time
from pathlib import Path


TEST_ROOT = Path(__file__).resolve().parent
CONTROLLER = TEST_ROOT / "independent_negative_controller_r16.py"
EXPECTED_CONTROLLER_SHA256 = "326285c0b3e9f3f2ee8afb10b0b259defc2b3306805c833573193c51a1092be1"


def load_pinned_controller() -> dict[str, object]:
    source = CONTROLLER.read_bytes()
    digest = hashlib.sha256(source).hexdigest()
    if digest != EXPECTED_CONTROLLER_SHA256:
        raise RuntimeError(f"controller source drift: {digest}")
    namespace: dict[str, object] = {
        "__name__": "_vnext_t2_controller_r16_probe",
        "__file__": str(CONTROLLER),
        "__package__": None,
    }
    exec(compile(source, str(CONTROLLER), "exec"), namespace)
    namespace["_source_sha256"] = digest
    return namespace


def main() -> int:
    started = time.perf_counter()
    controller = load_pinned_controller()
    native = controller["_windows_native_process_table"]()
    snapshot_started = time.perf_counter()
    snapshot = controller["_process_table_snapshot"]()
    snapshot_seconds = time.perf_counter() - snapshot_started
    residual_started = time.perf_counter()
    residual = controller["heavy_processes"](snapshot)
    residual_seconds = time.perf_counter() - residual_started
    rows = native.get("rows", []) if isinstance(native, dict) else []
    selected = {
        str(pid): next((row for row in rows if row.get("pid") == pid), None)
        for pid in (0, 4, 332)
    }
    result = {
        "schema": "vnext-t2-native-process-table-host-probe-r1",
        "controller_path": str(CONTROLLER),
        "controller_sha256": controller["_source_sha256"],
        "host": {
            "windows_version": list(sys.getwindowsversion()[:3]),
            "platform_machine": platform.machine(),
            "native_host_identity": native.get("host_identity"),
        },
        "native_query": {
            "system_information_class": 5,
            "ntstatus_u32": native.get("ntstatus_u32"),
            "query_attempts": native.get("query_attempts"),
            "buffer_bytes": native.get("buffer_bytes"),
            "row_count": native.get("row_count"),
            "complete": native.get("complete"),
            "abi_contract": native.get("abi_contract"),
            "selected_rows": selected,
        },
        "process_snapshot": {
            "complete": snapshot.get("complete"),
            "attempts": snapshot.get("attempts"),
            "ordinary_rows": len(snapshot.get("rows", [])),
            "native_snapshots": snapshot.get("native_snapshots"),
            "membership_churn": snapshot.get("membership_churn"),
            "pid0_sentinel_counts": snapshot.get("pid0_sentinel_counts"),
            "pid4_sentinel_counts": snapshot.get("pid4_sentinel_counts"),
            "errors": snapshot.get("errors"),
        },
        "residual_audit": {
            "complete": residual.get("complete"),
            "processes": residual.get("processes"),
            "errors": residual.get("errors"),
        },
        "timing_seconds": {
            "native_query_included_in_total": True,
            "snapshot_including_inventory_crosschecks": snapshot_seconds,
            "residual_audit": residual_seconds,
            "total": time.perf_counter() - started,
            "per_30_terminal_audits_conservative_seconds":
                30 * snapshot_seconds,
        },
    }
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
    return 0 if native.get("complete") is True and \
        snapshot.get("complete") is True and \
        residual.get("complete") is True and \
        residual.get("processes") == [] else 1


if __name__ == "__main__":
    raise SystemExit(main())
