"""Independent Python-only tests for the frozen T2 R18 heavy-audit gate.

This source is tester-owned and deliberately outside the frozen T2 input set.
It exercises the production predicate at the baseline entry and through the
final-audit caller without starting Julia or querying live processes.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
from typing import Any, Callable


EXPECTED_PROTOCOL_SHA = "90262706d77127112e6c097664b18c67062ed265641719f666e546baf55a9cc7"
EXPECTED_CONTROLLER_SHA = "0c82606e5d76815238db567c2be55095ba6523cf838b16f3ee50beb55119b660"
EXPECTED_MAP_SHA = "7cb1c9ed0d32c5ef09c135b185d42865fa22ed7381907a325ed63561fe19db56"
EXPECTED_FINAL_AUDIT_SCHEMA = "vnext-t2-r23-final-process-tree-audit-r1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_module(path: Path):
    spec = importlib.util.spec_from_file_location("t2_controller_r18_under_test", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot create controller import spec")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def valid_receipt() -> dict[str, Any]:
    return {
        "schema": "vnext-t2-r23-global-heavy-audit-r1",
        "complete": True,
        "processes": [],
        "controller_processes": [],
        "native_heavy_identities": [],
        "errors": [],
        "snapshot": {
            "schema": "vnext-t2-r23-native-snapshot-receipt-r1",
            "complete": True,
            "host_identity": [10, 0, 26200, "AMD64"],
            "system_information_class": 5,
            "buffer_bytes": 256,
            "query_attempts": 1,
            "raw_identity_digest_sha256": "a" * 64,
            "identity_authority": "NtQuerySystemInformation_class5_raw_FILETIME_100ns",
            "row_count": 2,
        },
    }


def make_cases() -> list[tuple[str, dict[str, Any] | list[Any] | None, bool]]:
    cases: list[tuple[str, dict[str, Any] | list[Any] | None, bool]] = []
    cases.append(("complete_empty_positive", valid_receipt(), True))

    for field in ("processes", "controller_processes", "native_heavy_identities", "errors"):
        receipt = valid_receipt()
        receipt[field] = [{"synthetic": "nonempty"}]
        cases.append((f"nonempty_{field}", receipt, False))

    cases.extend([
        ("missing_receipt", None, False),
        ("receipt_wrong_top_type", [], False),
        ("missing_schema", {k: v for k, v in valid_receipt().items() if k != "schema"}, False),
        ("wrong_schema", {**valid_receipt(), "schema": "unknown"}, False),
        ("missing_complete", {k: v for k, v in valid_receipt().items() if k != "complete"}, False),
        ("incomplete_false", {**valid_receipt(), "complete": False}, False),
        ("complete_int_one", {**valid_receipt(), "complete": 1}, False),
    ])

    for field in ("processes", "controller_processes", "native_heavy_identities", "errors"):
        receipt = valid_receipt()
        del receipt[field]
        cases.append((f"missing_{field}", receipt, False))
        receipt = valid_receipt()
        receipt[field] = None
        cases.append((f"malformed_{field}_null", receipt, False))
        receipt = valid_receipt()
        receipt[field] = {}
        cases.append((f"malformed_{field}_object", receipt, False))

    snapshot_mutations: list[tuple[str, Callable[[dict[str, Any]], None]]] = [
        ("missing_snapshot", lambda r: r.pop("snapshot")),
        ("snapshot_null", lambda r: r.__setitem__("snapshot", None)),
        ("snapshot_wrong_type", lambda r: r.__setitem__("snapshot", [])),
        ("snapshot_missing_schema", lambda r: r["snapshot"].pop("schema")),
        ("snapshot_wrong_schema", lambda r: r["snapshot"].__setitem__("schema", "unknown")),
        ("snapshot_incomplete", lambda r: r["snapshot"].__setitem__("complete", False)),
        ("snapshot_complete_int_one", lambda r: r["snapshot"].__setitem__("complete", 1)),
        ("snapshot_missing_authority", lambda r: r["snapshot"].pop("identity_authority")),
        ("snapshot_wrong_authority", lambda r: r["snapshot"].__setitem__("identity_authority", "display-name-only")),
        ("snapshot_missing_host_identity", lambda r: r["snapshot"].pop("host_identity")),
        ("snapshot_wrong_host_identity", lambda r: r["snapshot"].__setitem__("host_identity", [])),
        ("snapshot_missing_system_information_class", lambda r: r["snapshot"].pop("system_information_class")),
        ("snapshot_wrong_system_information_class", lambda r: r["snapshot"].__setitem__("system_information_class", 4)),
        ("snapshot_missing_buffer_bytes", lambda r: r["snapshot"].pop("buffer_bytes")),
        ("snapshot_wrong_buffer_bytes", lambda r: r["snapshot"].__setitem__("buffer_bytes", False)),
        ("snapshot_missing_query_attempts", lambda r: r["snapshot"].pop("query_attempts")),
        ("snapshot_wrong_query_attempts", lambda r: r["snapshot"].__setitem__("query_attempts", True)),
        ("snapshot_missing_raw_identity_digest", lambda r: r["snapshot"].pop("raw_identity_digest_sha256")),
        ("snapshot_malformed_raw_identity_digest", lambda r: r["snapshot"].__setitem__("raw_identity_digest_sha256", "not-a-sha256")),
        ("snapshot_missing_row_count", lambda r: r["snapshot"].pop("row_count")),
        ("snapshot_row_count_zero", lambda r: r["snapshot"].__setitem__("row_count", 0)),
        ("snapshot_row_count_bool", lambda r: r["snapshot"].__setitem__("row_count", True)),
        ("snapshot_row_count_string", lambda r: r["snapshot"].__setitem__("row_count", "2")),
    ]
    for name, mutate in snapshot_mutations:
        receipt = valid_receipt()
        mutate(receipt)
        cases.append((name, receipt, False))
    return cases


def synthetic_snapshot(controller: Any, extra_rows: tuple[Any, ...] = ()) -> Any:
    table_module = controller._R23_TABLE
    ticks = 1_350_000_000_000_000_000
    idle = table_module.ProcessRow(
        table_module.ProcessIdentity(0, ticks), 0, "")
    system = table_module.ProcessRow(
        table_module.ProcessIdentity(4, ticks), 0, "System")
    return table_module.ProcessTableSnapshot(
        rows=(idle, system, *extra_rows),
        host_identity=(10, 0, 26200, "AMD64"),
        buffer_bytes=table_module.SPI_FIXED_HEADER_BYTES,
        query_attempts=1,
    )


def final_audit_with_receipt(controller: Any, receipt: Any) -> dict[str, Any]:
    snapshot = synthetic_snapshot(controller)
    ticks = 1_350_000_000_000_000_000
    original = controller._r23_exact_heavy_audit
    controller._r23_exact_heavy_audit = lambda _snapshot: copy.deepcopy(receipt)
    try:
        return controller._r23_final_audit(
            (999, ticks + 1), [], snapshot, root_exit_confirmed=True)
    finally:
        controller._r23_exact_heavy_audit = original


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True)
    parser.add_argument("--controller", required=True)
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--coverage-map", required=True)
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    controller_path = Path(args.controller).resolve()
    protocol_path = Path(args.protocol).resolve()
    map_path = Path(args.coverage_map).resolve()

    if sha256(protocol_path) != EXPECTED_PROTOCOL_SHA:
        raise RuntimeError("frozen protocol SHA mismatch")
    if sha256(controller_path) != EXPECTED_CONTROLLER_SHA:
        raise RuntimeError("frozen controller SHA mismatch")
    if sha256(map_path) != EXPECTED_MAP_SHA:
        raise RuntimeError("frozen coverage map SHA mismatch")

    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    coverage = json.loads(map_path.read_text(encoding="utf-8"))
    if protocol.get("formal_t2_accepted") is not False or protocol.get("status") != "frozen_static_ready_not_executed":
        raise RuntimeError("protocol claim ceiling/status changed")
    if protocol.get("coverage_map", {}).get("sha256") != EXPECTED_MAP_SHA:
        raise RuntimeError("protocol does not pin the expected coverage map")
    if protocol.get("controller_r17_r18_preflight_delta", {}).get("baseline_and_final_audit_share_helper") is not True:
        raise RuntimeError("protocol does not assert shared baseline/final audit helper")

    controller = load_module(controller_path)
    cases = make_cases()
    results = []
    failures = []
    for name, receipt, should_pass in cases:
        try:
            controller.verify_baseline_heavy_processes_clear(copy.deepcopy(receipt))
            baseline_passed = True
            baseline_error = None
        except Exception as error:
            baseline_passed = False
            baseline_error = f"{type(error).__name__}: {error}"

        final = final_audit_with_receipt(controller, receipt)
        final_passed = final.get("complete") is True and not final.get("errors")
        baseline_ok = baseline_passed is should_pass
        final_ok = final_passed is should_pass
        if not baseline_ok or not final_ok:
            failures.append(name)
        results.append({
            "case": name,
            "expected_go": should_pass,
            "baseline_go": baseline_passed,
            "baseline_error": baseline_error,
            "final_go": final_passed,
            "final_complete": final.get("complete"),
            "final_error_count": len(final.get("errors", [])),
            "pass": baseline_ok and final_ok,
        })

    table_module = controller._R23_TABLE
    ticks = 1_350_000_000_000_000_000
    julia_row = table_module.ProcessRow(
        table_module.ProcessIdentity(4242, ticks + 100), 4, "julia.exe")
    for name, extra_rows, expected_go in (
        ("actual_table_empty_baseline_and_final_positive", (), True),
        ("actual_table_julia_process_baseline_and_final_negative", (julia_row,), False),
    ):
        snapshot = synthetic_snapshot(controller, extra_rows)
        receipt = controller.heavy_processes(snapshot)
        try:
            controller.verify_baseline_heavy_processes_clear(receipt)
            baseline_passed = True
            baseline_error = None
        except Exception as error:
            baseline_passed = False
            baseline_error = f"{type(error).__name__}: {error}"
        final = controller._r23_final_audit(
            (999, ticks + 1), [], snapshot, root_exit_confirmed=True)
        final_passed = final.get("complete") is True and not final.get("errors")
        case_passed = baseline_passed is expected_go and final_passed is expected_go
        if not case_passed:
            failures.append(name)
        results.append({
            "case": name,
            "expected_go": expected_go,
            "baseline_go": baseline_passed,
            "baseline_error": baseline_error,
            "baseline_process_count": len(receipt.get("processes", [])),
            "final_go": final_passed,
            "final_complete": final.get("complete"),
            "final_error_count": len(final.get("errors", [])),
            "final_process_count": len(final.get("global_heavy_process_audit", {}).get("processes", [])),
            "pass": case_passed,
        })

    runtime = coverage.get("runtime_execution_plan", {})
    formal_case_ids = runtime.get("actual_formal_summary_case_ids", [])
    coverage_summary = {
        "phase_count": protocol.get("expected_phase_count"),
        "formal_case_count": len(formal_case_ids),
        "runtime_unique_cases": runtime.get("expected_unique_case_count"),
        "runtime_case_hits": runtime.get("expected_runtime_case_hit_count"),
        "source_sites": coverage.get("successor_assertion_site_count"),
        "planned_source_site_hits": coverage.get("successor_expected_runtime_hit_count"),
        "authority_source_sites": 175,
        "authority_nonzero_sites": 75,
        "authority_planned_hits": 118,
        "transport_site_ids": coverage.get("context_transport_assertion_site_count"),
        "transport_planned_hits": coverage.get("context_transport_expected_runtime_hit_count"),
        "relocated_site_count": coverage.get("attempt9c_relocation_summary", {}).get("entry_count"),
        "case_site_set_equal": coverage.get("attempt9c_relocation_summary", {}).get("all_source_text_and_phase_hit_contracts_equal"),
    }
    expected_coverage = {
        "phase_count": 30, "formal_case_count": 45, "runtime_unique_cases": 60,
        "runtime_case_hits": 68, "source_sites": 214,
        "planned_source_site_hits": 622, "authority_source_sites": 175,
        "authority_nonzero_sites": 75, "authority_planned_hits": 118,
        "transport_site_ids": 23, "transport_planned_hits": 92,
        "relocated_site_count": 175, "case_site_set_equal": True,
    }
    if coverage_summary != expected_coverage:
        failures.append("coverage_regression")

    report = {
        "schema": "independent-t2-r18-audit-predicate-probe-r1",
        "status": "pass" if not failures else "fail",
        "controller_sha256": sha256(controller_path),
        "protocol_sha256": sha256(protocol_path),
        "coverage_map_sha256": sha256(map_path),
        "test_count": len(results),
        "boundary_count": 2,
        "positive_case_count": sum(1 for row in results if row["expected_go"]),
        "negative_case_count": sum(1 for row in results if not row["expected_go"]),
        "passed_case_count": sum(1 for row in results if row["pass"]),
        "failures": failures,
        "coverage": coverage_summary,
        "results": results,
        "julia_started": False,
        "formal_t2_accepted": False,
    }
    print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
