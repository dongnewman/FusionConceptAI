from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path
import tempfile
from types import ModuleType


ROOT = Path(__file__).resolve().parents[3]
PROTOCOL_PATH = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r17_pid_identity_static_20260924/protocol.json"
EXPECTED_PROTOCOL_SHA256 = "1a640ea5b0dfb26f001ad2953137b159364a6aa0c32c83ca99dd5f7e06c8d076"
EXPECTED_MANIFEST_SHA256 = "15ed2012e0393c18b11914e2e65bcfe5d912d2c6168b1d4988e52cc2b882fd99"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_source_module(name: str, path: Path) -> ModuleType:
    module = ModuleType(name)
    module.__file__ = str(path)
    exec(compile(path.read_bytes(), str(path), "exec"), module.__dict__)
    return module


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, sort_keys=True) + "\n", encoding="utf-8")


def synthetic_report(leaf: Path, reporter: ModuleType, child_receipt_ct: float,
                     root_audit_ct: object = 1.0,
                     omit_root_sample_identity: bool = False) -> dict:
    stage = leaf / "01_parse_all"
    stage.mkdir(parents=True)
    root_row = {
        "pid": 301, "name": "julia", "cmdline": ["julia"],
        "create_time": 1.0, "rss_bytes": 80_000_000,
        "cpu_user_seconds": 1.0, "cpu_system_seconds": 0.5,
    }
    child_row = {
        "pid": 302, "name": "julia-worker", "cmdline": ["julia-worker"],
        "create_time": 7.0, "rss_bytes": 40_000_000,
        "cpu_user_seconds": 0.25, "cpu_system_seconds": 0.125,
    }
    process_rows = [child_row] if omit_root_sample_identity else [root_row, child_row]
    sample_pids = [row["pid"] for row in process_rows]
    sample_rss = sum(row["rss_bytes"] for row in process_rows)
    sample = {
        "utc": "2026-09-24T00:00:00Z",
        "elapsed_seconds": 0.0,
        "root_pid": 301,
        "process_tree_sample_complete": True,
        "process_tree_sample_errors": [],
        "process_tree_expected_member_count": len(process_rows),
        "process_tree_measured_member_count": len(process_rows),
        "process_tree_pids": sample_pids,
        "process_tree_discovered_pids": sample_pids,
        "process_tree_measured_pids": sample_pids,
        "process_tree_processes": process_rows,
        "process_tree_rss_bytes": sample_rss,
        "partial_process_tree_rss_bytes": sample_rss,
    }
    (stage / "samples.jsonl").write_text(
        json.dumps(sample, sort_keys=True) + "\n", encoding="utf-8"
    )
    final = {
        "schema": "native-g1g2-recorded-stage-v1", "index": 1,
        "stage": "parse_all", "exit_code": 0, "stop_reason": "natural_exit",
        "sample_count": 1, "root_pid": 301, "root_process_create_time": 1.0,
        "peak_process_tree_rss_bytes": sample_rss,
        "peak_process_tree_rss_sample_index": 1,
        "peak_process_tree_rss_sample_utc": sample["utc"],
        "peak_process_tree_rss_sample_elapsed_seconds": 0.0,
        "peak_process_tree_rss_sample_bytes": sample_rss,
        "resource_monitor_complete": True,
        "resource_monitor_status": "complete",
        "resource_monitor_failure": None,
    }
    write_json(stage / "final.json", final)
    write_json(leaf / "summary.json", {
        "schema": "native-g1g2-run-summary-v1", "mode": "actual",
        "runtime_executed": True, "status": "pass",
        "resource_monitor_complete": True, "stages": [final],
        "numerical_status": "not_established", "physical_status": "unknown",
    })
    descendant = {"pid": 302, "create_time": child_receipt_ct,
                  "exit_confirmed": True}
    audit = {
        "schema": "native-g1g2-root-outer-supervisor-residual-audit-v1",
        "audit_owner": "root_dispatch_controller", "audit_status": "pass",
        "run_mode": "actual", "runtime_executed": True,
        "run_root_pid_create_time": {"pid": 900, "create_time": 1.0},
        "pre_run_inventory_complete": True, "post_run_inventory_complete": True,
        "post_run_heavy_process_inventory": [],
        "supervised_runner": {"pid": 900, "create_time": 1.0,
                              "exit_confirmed": True},
        "residual_scan_before_and_after_each_stage": True,
        "residual_scan_completeness": {
            "pre_run_inventory_complete": True,
            "post_run_inventory_complete": True,
            "stages": [{"index": 1, "stage": "parse_all",
                        "pre_stage_inventory_complete": True,
                        "post_stage_inventory_complete": True}],
        },
        "stage_root_exit_receipts": [{
            "index": 1, "stage": "parse_all", "pid": 301,
            "create_time": 1.0, "exit_confirmed": True,
        }],
        "tracked_descendant_exit_receipts": [
            {"index": 1, "stage": "parse_all", **descendant},
        ],
        "stages": [{
            "index": 1, "stage": "parse_all", "root_pid": 301,
            "root_process_create_time": root_audit_ct,
            "root_exit_confirmed": True,
            "pre_stage_inventory_complete": True,
            "post_stage_inventory_complete": True,
            "pre_stage_residual_heavy_processes": [],
            "post_stage_residual_heavy_processes": [],
            "tracked_descendant_exit_receipts": [descendant],
        }],
    }
    write_json(leaf / reporter.OUTER_AUDIT_FILENAME, audit)
    return reporter.build_report(leaf)


def main() -> None:
    manifest_path = PROTOCOL_PATH.with_name("evidence_manifest.json")
    assert sha256(PROTOCOL_PATH) == EXPECTED_PROTOCOL_SHA256
    assert sha256(manifest_path) == EXPECTED_MANIFEST_SHA256
    protocol = json.loads(PROTOCOL_PATH.read_text(encoding="utf-8"))
    pin_results = []
    for pin in protocol["frozen_files"]:
        path = ROOT / pin["path"]
        actual = {"path": pin["path"], "bytes": path.stat().st_size,
                  "sha256": sha256(path)}
        assert actual["bytes"] == pin["bytes"], actual
        assert actual["sha256"] == pin["sha256"], actual
        pin_results.append(actual)

    reporter_dir = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1"
    current = load_source_module(
        "independent_r17_reporter",
        reporter_dir / "report_r17_resource_outcome_v1.py",
    )
    legacy = load_source_module(
        "independent_r16_reporter",
        reporter_dir / "report_r16_resource_outcome_v1.py",
    )
    results: dict[str, object] = {}
    with tempfile.TemporaryDirectory(prefix="r17_independent_identity_") as temp:
        wrong = Path(temp) / "wrong_identity"
        wrong.mkdir()
        r17_wrong = synthetic_report(wrong, current, child_receipt_ct=8.0)
        r16_wrong = legacy.build_report(wrong)
        wrong_reasons = r17_wrong["outer_supervisor_audit"]["failure_reasons"]
        required_reasons = [
            "outer_supervisor_stage[1]_observed_descendant_identity_exit_receipt_missing",
            "outer_supervisor_stage[1]_aggregate_descendant_identity_receipt_missing",
        ]
        assert r16_wrong["run_disposition"] == "no_sampled_rss_threshold_crossing"
        assert r17_wrong["run_disposition"] == "resource_monitor_incomplete"
        assert all(reason in wrong_reasons for reason in required_reasons)
        assert r17_wrong["claim_boundary"]["numerical_credit_on_monitor_incomplete"] is False
        results["pid_reuse_wrong_create_time"] = {
            "sample_identity": {"pid": 302, "create_time": 7.0},
            "both_receipts": {"pid": 302, "create_time": 8.0},
            "r16": r16_wrong["run_disposition"],
            "r17": r17_wrong["run_disposition"],
            "r17_failure_reasons": wrong_reasons,
            "r17_numerical_credit_on_incomplete":
                r17_wrong["claim_boundary"]["numerical_credit_on_monitor_incomplete"],
        }

        exact = Path(temp) / "exact_identity"
        exact.mkdir()
        r17_exact = synthetic_report(exact, current, child_receipt_ct=7.0)
        assert r17_exact["run_disposition"] == "no_sampled_rss_threshold_crossing"
        assert r17_exact["resource_monitor_complete"] is True
        observed = r17_exact["stage_reports"][0]["observed_process_identities"]
        assert observed == [{"pid": 301, "create_time": 1.0},
                            {"pid": 302, "create_time": 7.0}]
        results["exact_identity_positive"] = {
            "run_disposition": r17_exact["run_disposition"],
            "resource_monitor_complete": r17_exact["resource_monitor_complete"],
            "observed_process_identities": observed,
        }

        bad_root = Path(temp) / "boolean_root_create_time"
        bad_root.mkdir()
        r17_bad_root = synthetic_report(
            bad_root, current, child_receipt_ct=7.0, root_audit_ct=True
        )
        bad_root_reasons = r17_bad_root["outer_supervisor_audit"]["failure_reasons"]
        assert r17_bad_root["run_disposition"] == "resource_monitor_incomplete"
        assert "outer_supervisor_stage[1]_root_identity_mismatch" in bad_root_reasons
        results["boolean_root_identity_negative"] = {
            "run_disposition": r17_bad_root["run_disposition"],
            "failure_reasons": bad_root_reasons,
        }

        missing_root = Path(temp) / "missing_root_sample_identity"
        missing_root.mkdir()
        r17_missing_root = synthetic_report(
            missing_root, current, child_receipt_ct=7.0,
            omit_root_sample_identity=True,
        )
        results["missing_root_sample_identity_negative"] = {
            "sample_root_pid": 301,
            "sample_rows": [302],
            "final_root_process_identity":
                r17_missing_root["stage_reports"][0]["root_process_identity"],
            "observed_process_identities":
                r17_missing_root["stage_reports"][0]["observed_process_identities"],
            "run_disposition": r17_missing_root["run_disposition"],
            "resource_monitor_complete": r17_missing_root["resource_monitor_complete"],
            "outer_audit_complete": r17_missing_root["outer_supervisor_audit"]["complete"],
            "failure_reasons":
                r17_missing_root["outer_supervisor_audit"]["failure_reasons"],
        }

    assert protocol["identity_contract"]["receipt_authenticity"].startswith(
        "not upgraded;"
    )
    results["frozen_pins_verified"] = len(pin_results)
    results["pins"] = pin_results
    results["resource_contract"] = protocol["r16_parent_contract_preserved"]
    results["execution_boundary"] = protocol["execution"]
    print(json.dumps(results, sort_keys=True, indent=2))


if __name__ == "__main__":
    main()
