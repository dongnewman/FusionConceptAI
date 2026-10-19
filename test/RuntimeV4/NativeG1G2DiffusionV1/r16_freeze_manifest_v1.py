"""Build/verify consistent, evidence-only Native G1/G2 r16 freeze metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


SCHEMA = "native-g1g2-r16-freeze-manifest-v1"
EXPECTED_CLAIM_BOUNDARY = {
    "numerical_credit_on_monitor_incomplete": False,
    "root_outer_supervisor_residual_audit_required": True,
    "numerical_credit_before_outer_supervisor_audit": False,
}
EXPECTED_LIMITS = {
    "wall_seconds": 480.0,
    "sampled_process_tree_rss_stop_threshold_bytes": 2_147_483_648,
    "rss_sample_interval_seconds": 0.2,
    "julia_threads": 1,
    "blas_threads": 1,
}
EXPECTED_MEMORY_OBSERVABILITY = {
    "julia_heap_size_hint": "1G",
    "julia_heap_size_hint_bytes": 1_073_741_824,
    "sampled_process_tree_rss_stop_threshold_bytes": 2_147_483_648,
    "rss_sample_interval_seconds": 0.2,
    "rss_enforcement_semantics": "sampled_stop_trigger",
    "sampled_overshoot_possible": True,
    "sampled_threshold_hit_or_overshoot_disposition": "resource_failure",
    "forced_gc_at_markers": False,
}
EXPECTED_RESOURCE_POLICY = {
    "schema": "native-g1g2-process-tree-monitor-fail-closed-v2",
    "sample_completeness_required": True,
    "rss_value_contract": "type(value) is int and value >= 0; bool, float, string, and coercion rejected",
    "invalid_rss_value_disposition": "resource_monitor_incomplete",
    "enumeration_or_member_read_error_disposition": "resource_monitor_incomplete",
    "no_such_process_race_disposition": "resource_monitor_incomplete",
    "partial_rss_can_clear_threshold": False,
    "preserve_partial_rss_pids_and_raw_exception": True,
    "monitor_incomplete_is_resource_failure": True,
    "numerical_credit_on_monitor_incomplete": False,
    "internal_kill_receipts_required": True,
    "internal_kill_errors_fail_closed": True,
    "tracked_descendant_exit_receipts_required": True,
    "root_outer_supervisor_residual_audit_required": True,
    "runner_kill_tree_is_sufficient_containment": False,
}
EXPECTED_TERMINATION_CONTRACT = {
    "runner_internal_kill_receipt_schema": "native-g1g2-internal-termination-receipt-v1",
    "internal_kill_errors_fail_closed": True,
    "tracked_descendant_exit_receipts_required": True,
    "root_outer_supervisor_residual_audit_required": True,
    "root_outer_supervisor_audit_schema": "native-g1g2-root-outer-supervisor-residual-audit-v1",
    "required_outer_audit_fields": [
        "run_root_pid_create_time",
        "stage_root_exit_receipts",
        "tracked_descendant_exit_receipts",
        "residual_scan_before_and_after_each_stage",
        "residual_scan_completeness",
        "post_run_heavy_process_inventory",
    ],
    "outer_audit_missing_disposition": "resource_monitor_incomplete",
    "runner_kill_tree_is_sufficient_containment": False,
    "numerical_credit_before_outer_audit": False,
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_object(path: Path, field: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"cannot read {field}: {path}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{field} must be a JSON object")
    return value


def build_freeze_manifest(
    protocol: dict[str, Any], static_preflight: dict[str, Any], *,
    protocol_bytes: bytes, static_preflight_bytes: bytes,
) -> dict[str, Any]:
    """Derive the claim field once from the protocol; reject polarity drift."""
    policy = protocol.get("resource_monitor_policy")
    reporter = protocol.get("resource_outcome_reporter")
    termination = protocol.get("process_tree_termination_contract")
    if not isinstance(policy, dict) or not isinstance(reporter, dict) or \
            not isinstance(termination, dict):
        raise ValueError("protocol resource/termination contracts are missing")
    if protocol.get("limits_per_julia_stage") != EXPECTED_LIMITS:
        raise ValueError("protocol stage limits differ from the frozen 480s/2GiB contract")
    memory = protocol.get("memory_observability")
    if not isinstance(memory, dict) or any(
        memory.get(key) != value
        for key, value in EXPECTED_MEMORY_OBSERVABILITY.items()
    ):
        raise ValueError("protocol sampled RSS/heap-hint semantics differ from the frozen contract")
    compiler = protocol.get("compiler_strategy")
    if not isinstance(compiler, dict) or any(
        compiler.get(key) != value for key, value in {
            "claim_scope": "compiler_resource_diagnostic",
            "mode": "--compile=min",
            "numerical_fixtures_or_thresholds_changed": False,
            "sampled_rss_stop_threshold_bytes_unchanged": 2_147_483_648,
            "diagnostic_is_numerical_success": False,
            "numerical_status_predeclared": "not_established",
            "physical_status_predeclared": "unknown",
        }.items()
    ):
        raise ValueError("protocol compiler strategy exceeds its diagnostic-only claim")
    credit = policy.get("numerical_credit_on_monitor_incomplete")
    if type(credit) is not bool:
        raise ValueError("protocol monitor credit field must be a JSON boolean")
    if policy != EXPECTED_RESOURCE_POLICY:
        raise ValueError("protocol monitor policy differs from the frozen fail-closed contract")
    if reporter.get("numerical_credit_on_incomplete_sample") is not credit:
        raise ValueError("protocol and reporter monitor-credit fields disagree")
    if reporter.get("external_outer_supervisor_audit_required") is not True:
        raise ValueError("resource reporter must require the root outer-supervisor audit")
    if credit is not False:
        raise ValueError("incomplete process-tree monitoring must carry zero numerical credit")
    if any(termination.get(key) != value for key, value in EXPECTED_TERMINATION_CONTRACT.items()):
        raise ValueError("outer-supervisor residual audit/no-credit contract is inconsistent")

    dependencies = static_preflight.get("dependencies")
    owned = protocol.get("ownership")
    if not isinstance(dependencies, dict) or not isinstance(owned, (tuple, list)):
        raise ValueError("static input pins or owned file inventory are missing")
    owned_pins = []
    for relative in owned:
        if not isinstance(relative, str) or relative not in dependencies:
            raise ValueError(f"owned file is not pinned: {relative!r}")
        pin = dependencies[relative]
        if not isinstance(pin, dict) or type(pin.get("bytes")) is not int or \
                type(pin.get("sha256")) is not str:
            raise ValueError(f"owned file pin is malformed: {relative}")
        owned_pins.append({"path": relative, "bytes": pin["bytes"], "sha256": pin["sha256"]})

    prelaunch = protocol.get("prelaunch_guard")
    if not isinstance(prelaunch, dict) or protocol.get("schema") != \
            "native-g1g2-gridap-recorded-protocol-r16-v1":
        raise ValueError("freeze manifest requires the r16 protocol schema and prelaunch guard")
    if prelaunch.get("required_before_julia") is not True or \
            protocol.get("run_mode") != "static_only" or \
            protocol.get("execution_plan", {}).get("runtime_executed") is not False:
        raise ValueError("freeze manifest may only be built from a static-only r16 protocol")
    if protocol.get("execution_plan", {}).get("julia_started") is not False:
        raise ValueError("static-only freeze manifest cannot claim Julia started")
    if len(dependencies) < 115:
        raise ValueError("static preflight must retain all 115 frozen r10 pins")

    return {
        "schema": SCHEMA,
        "protocol_sha256": _sha256(protocol_bytes),
        "static_preflight_sha256": _sha256(static_preflight_bytes),
        "runtime_executed": False,
        "julia_started": False,
        "r10_frozen_input_count": 115,
        "owned_source_and_test_pins": owned_pins,
        "resource_contract": {
            "sampled_rss_stop_threshold_bytes": EXPECTED_LIMITS[
                "sampled_process_tree_rss_stop_threshold_bytes"],
            "sample_interval_seconds": EXPECTED_LIMITS["rss_sample_interval_seconds"],
            "stage_wall_seconds": EXPECTED_LIMITS["wall_seconds"],
            "julia_heap_size_hint": EXPECTED_MEMORY_OBSERVABILITY["julia_heap_size_hint"],
            "compiler_mode": compiler["mode"],
            "rss_enforcement_semantics": "sampled_stop_trigger",
            "overshoot_possible": True,
            "invalid_rss_disposition": "resource_monitor_incomplete",
        },
        "process_tree_termination_contract": {
            "tracked_descendant_exit_receipts_required": True,
            "root_outer_supervisor_residual_audit_required": True,
            "runner_kill_tree_is_sufficient_containment": False,
        },
        "claim_boundary": dict(EXPECTED_CLAIM_BOUNDARY),
        "archive_payload_policy": "evidence_only_no_source_test_or_launcher_payload",
    }


def verify_freeze_manifest(
    candidate: dict[str, Any], protocol: dict[str, Any], static_preflight: dict[str, Any], *,
    protocol_bytes: bytes, static_preflight_bytes: bytes,
) -> None:
    expected = build_freeze_manifest(
        protocol, static_preflight,
        protocol_bytes=protocol_bytes,
        static_preflight_bytes=static_preflight_bytes,
    )
    if candidate != expected:
        raise ValueError("freeze manifest differs from protocol-derived metadata")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True, type=Path)
    parser.add_argument("--static-preflight", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    protocol_bytes = args.protocol.read_bytes()
    static_bytes = args.static_preflight.read_bytes()
    protocol = _read_object(args.protocol, "r16 protocol")
    static = _read_object(args.static_preflight, "r16 static preflight")
    document = build_freeze_manifest(
        protocol, static,
        protocol_bytes=protocol_bytes,
        static_preflight_bytes=static_bytes,
    )
    if args.output.exists():
        raise FileExistsError(f"freeze manifest output already exists: {args.output}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(document, stream, indent=2, sort_keys=True)
        stream.write("\n")
    verify_freeze_manifest(
        _read_object(args.output, "generated freeze manifest"), protocol, static,
        protocol_bytes=protocol_bytes,
        static_preflight_bytes=static_bytes,
    )
    print(json.dumps({"status": "freeze_manifest_valid", "output": str(args.output),
                      "runtime_executed": False, "julia_started": False}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
