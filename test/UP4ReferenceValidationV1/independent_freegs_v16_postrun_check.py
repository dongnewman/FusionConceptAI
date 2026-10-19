#!/usr/bin/env python3
"""Read-only, independent structural check of the archived FreeGS v16 run."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import pathlib
import sys
from collections import Counter
from datetime import datetime, timezone


REPO = pathlib.Path(__file__).resolve().parents[2]
PREC = pathlib.Path("docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC")
PROTOCOL_REL = pathlib.Path(
    "agent_r1_20260923/native_axisymmetric_forward_v7/actual_run_protocol_v16_candidate_v1.json"
)
RUN_REL = pathlib.Path(
    "archive/agent_r1_20260923/native_axisymmetric_forward_v7/actual_run_r16/freegs_solve"
)
EXPECTED_PROTOCOL_SHA256 = "32bb7c9f7d4f7aabaf563cc57842408d132ae8c374af869084ccd32979fe8cfc"
EXPECTED_SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-dirichlet-dof-elimination-v16"
EXPECTED_OUTPUT_SCHEMA = "fusionconceptai:runtime-v4-freegs-axisymmetric-profile-output-v2"
EXPECTED_ADAPTER_SCHEMA = "fusionconceptai:freegs-observed-dirichlet-adapter-receipt-v4"
EXPECTED_EDGE_NAMES = {"r_min", "r_max", "z_min", "z_max"}
EXPECTED_NONCONVERGENCE = "Picard iteration failed to converge (too many iterations)"
EXPECTED_RESIDUAL_CLASS = "diagnostic_only_no_physical_acceptance_threshold"


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: pathlib.Path) -> object:
    with path.open("r", encoding="utf-8") as stream:
        return json.load(stream)


def normalized(path: str | pathlib.Path) -> str:
    return os.path.normcase(os.path.abspath(os.fspath(path)))


def require(condition: bool, label: str, failures: list[str]) -> None:
    if not condition:
        failures.append(label)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--evidence-dir", required=True)
    args = parser.parse_args()

    evidence_dir = pathlib.Path(args.evidence_dir).resolve()
    evidence_dir.mkdir(parents=True, exist_ok=False)
    protocol_path = REPO / PREC / PROTOCOL_REL
    run_dir = REPO / PREC / RUN_REL
    run_files = {
        "execution": run_dir / "execution.json",
        "adapter_receipt": run_dir / "freegs_adapter_receipt_v16.json",
        "solver_output": run_dir / "solver_output.json",
        "stderr": run_dir / "stderr.raw",
        "stdout": run_dir / "stdout.raw",
    }
    checker_path = pathlib.Path(__file__).resolve()
    failures: list[str] = []

    protocol_sha = sha256_file(protocol_path)
    protocol = load_json(protocol_path)
    require(protocol.get("schema") == EXPECTED_SCHEMA, "protocol_schema", failures)
    require(protocol_sha == EXPECTED_PROTOCOL_SHA256, "protocol_sha256", failures)
    pins = protocol.get("dependency_file_pins", [])
    require(len(pins) == 158, "protocol_pin_count_158", failures)
    require(protocol.get("dependency_file_pin_count") == len(pins), "protocol_pin_count_field", failures)

    pin_rows: list[dict[str, object]] = []
    pin_by_norm: dict[str, dict[str, object]] = {}
    for pin in pins:
        path_text = pin.get("path")
        pin_path = pathlib.Path(path_text) if isinstance(path_text, str) else pathlib.Path("<invalid>")
        exists = pin_path.is_file()
        size = pin_path.stat().st_size if exists else None
        actual_sha = sha256_file(pin_path) if exists else None
        expected_size = pin.get("bytes")
        expected_sha = pin.get("sha256")
        status = "match" if exists and size == expected_size and actual_sha == expected_sha else "mismatch"
        pin_rows.append(
            {
                "path": path_text,
                "expected_bytes": expected_size,
                "actual_bytes": size,
                "expected_sha256": expected_sha,
                "actual_sha256": actual_sha,
                "status": status,
            }
        )
        require(status == "match", f"pinned_input:{path_text}", failures)
        key = normalized(path_text) if isinstance(path_text, str) else "<invalid>"
        require(key not in pin_by_norm, f"duplicate_protocol_pin:{path_text}", failures)
        pin_by_norm[key] = pin

    execution = load_json(run_files["execution"])
    adapter = load_json(run_files["adapter_receipt"])
    solver_output = load_json(run_files["solver_output"])
    run_hashes = {name: sha256_file(path) for name, path in run_files.items()}
    run_sizes = {name: path.stat().st_size for name, path in run_files.items()}

    # The supervisor's before/after receipts must identify exactly the frozen pin set.
    for field in ("required_files", "required_files_after"):
        rows = execution.get(field, [])
        by_path: dict[str, dict[str, object]] = {}
        for row in rows:
            path_text = row.get("path")
            key = normalized(path_text) if isinstance(path_text, str) else "<invalid>"
            require(key not in by_path, f"{field}_duplicate:{path_text}", failures)
            by_path[key] = row
        require(len(rows) == 158, f"{field}_count_158", failures)
        require(set(by_path) == set(pin_by_norm), f"{field}_path_set_matches_protocol", failures)
        for key, pin in pin_by_norm.items():
            row = by_path.get(key)
            if row is None:
                continue
            expected = pin.get("sha256")
            require(row.get("expected_sha256") == expected, f"{field}_expected_sha:{pin.get('path')}", failures)
            require(row.get("actual_sha256") == expected, f"{field}_actual_sha:{pin.get('path')}", failures)
            require(row.get("status") == "match", f"{field}_status:{pin.get('path')}", failures)
    require(execution.get("pins_stable_during_run") is True, "run_pins_stable", failures)
    require(execution.get("evidence_status") == "recorded_pins_stable", "run_evidence_status", failures)
    require(execution.get("required_file_changes") == [], "run_no_input_file_changes", failures)
    require(execution.get("preflight_errors") == [], "run_preflight_clean", failures)

    # Rehash and bind every protocol-declared run sidecar without copying raw payloads.
    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    for name, file_path in run_files.items():
        declared = sidecars.get(name)
        require(isinstance(declared, str) and normalized(declared) == normalized(file_path), f"sidecar_path:{name}", failures)
    require(normalized(execution.get("stdout_path", "")) == normalized(run_files["stdout"]), "execution_stdout_path", failures)
    require(normalized(execution.get("stderr_path", "")) == normalized(run_files["stderr"]), "execution_stderr_path", failures)
    require(execution.get("stdout_sha256") == run_hashes["stdout"], "execution_stdout_sha", failures)
    require(execution.get("stderr_sha256") == run_hashes["stderr"], "execution_stderr_sha", failures)
    require(normalized(adapter.get("receipt_path", "")) == normalized(run_files["adapter_receipt"]), "adapter_receipt_path", failures)
    require(normalized(adapter.get("output_path", "")) == normalized(run_files["solver_output"]), "adapter_output_path", failures)

    # Verify natural numerical nonconvergence, not a harness assertion/setup failure.
    require(execution.get("child_exit_code") == 4, "child_exit_4", failures)
    require(execution.get("harness_exit_code") == 4, "harness_exit_4", failures)
    require(execution.get("stop_reason") == "natural_exit", "natural_exit", failures)
    require(adapter.get("schema") == EXPECTED_ADAPTER_SCHEMA, "adapter_schema", failures)
    require(adapter.get("status") == "runner_returned", "adapter_runner_returned", failures)
    require(adapter.get("runner_return_code") == 4, "adapter_exit_4", failures)
    require(solver_output.get("schema") == EXPECTED_OUTPUT_SCHEMA, "output_schema", failures)
    require(solver_output.get("status") == "numerical_fail_nonconvergence", "output_nonconvergence_status", failures)
    require(solver_output.get("phase") == "numerical_solve", "output_numerical_phase", failures)
    require(solver_output.get("runner_exit_code") == 4, "output_exit_4", failures)
    require(solver_output.get("exception_type") == "RuntimeError", "output_runtime_error", failures)
    require(solver_output.get("message") == EXPECTED_NONCONVERGENCE, "output_nonconvergence_message", failures)
    target = adapter.get("target", {})
    require(target.get("formal_freegs_solve_returned") is False, "formal_solve_did_not_return", failures)
    require(target.get("target_exception") == {"message": EXPECTED_NONCONVERGENCE, "type": "RuntimeError"}, "adapter_failure_branch", failures)

    # Check all 101 callback events and all 202 scalar observation events.
    callback_events = adapter.get("boundary_callback_events", [])
    scalar_events = adapter.get("boundary_scalar_events", [])
    linear_events = adapter.get("linear_solver_events", [])
    require(len(callback_events) == 101, "callback_event_count_101", failures)
    require(len(scalar_events) == 202, "scalar_event_count_202", failures)
    require(len(linear_events) == 101, "linear_event_count_101", failures)
    frozen_edges = target.get("frozen_edge_hashes", {})
    require(set(frozen_edges) == EXPECTED_EDGE_NAMES, "four_frozen_edges", failures)
    for expected_index, event in enumerate(callback_events, 1):
        require(event.get("event_index") == expected_index, f"callback_index:{expected_index}", failures)
        require(event.get("callback_identity_exact") is True, f"callback_identity:{expected_index}", failures)
        require(event.get("target_equilibrium_identity_exact") is True, f"callback_target_identity:{expected_index}", failures)
        require(event.get("return_was_none") is True, f"callback_return_none:{expected_index}", failures)
        require(event.get("interior_unchanged") is True, f"callback_interior_unchanged:{expected_index}", failures)
        require(event.get("interior_sha256_before") == event.get("interior_sha256_after"), f"callback_interior_hash:{expected_index}", failures)
        edge_receipt = event.get("edge_after_callback", {})
        require(set(edge_receipt) == EXPECTED_EDGE_NAMES, f"callback_edge_set:{expected_index}", failures)
        for edge in EXPECTED_EDGE_NAMES:
            item = edge_receipt.get(edge, {})
            expected_hash = frozen_edges.get(edge)
            require(item.get("exact") is True, f"callback_edge_exact:{expected_index}:{edge}", failures)
            require(item.get("max_abs_delta_wb_per_rad") == 0.0, f"callback_edge_delta_zero:{expected_index}:{edge}", failures)
            require(item.get("expected_sha256") == expected_hash, f"callback_edge_expected_hash:{expected_index}:{edge}", failures)
            require(item.get("values_sha256") == expected_hash, f"callback_edge_values_hash:{expected_index}:{edge}", failures)
    for expected_index, event in enumerate(scalar_events, 1):
        require(event.get("event_index") == expected_index, f"scalar_index:{expected_index}", failures)
        require(event.get("target_equilibrium_identity_exact") is True, f"scalar_target_identity:{expected_index}", failures)
        require(event.get("solver_psi_bndry_mutated") is False, f"scalar_no_mutation:{expected_index}", failures)
        require(event.get("solver_psi_bndry_write_attempted") is False, f"scalar_no_write:{expected_index}", failures)
        require(event.get("picard_stop_effect") == "native_eq_psi_bndry_value_preserved", f"scalar_stop_effect:{expected_index}", failures)

    # The adapter's per-call residual diagnostics must be finite and bound to output call snapshots.
    residual_keys = ("l2_all", "l2_interior", "max_abs_all", "max_abs_boundary", "max_abs_interior")
    residual_values: dict[str, list[float]] = {key: [] for key in residual_keys}
    for expected_index, event in enumerate(linear_events, 1):
        require(event.get("event_index") == expected_index, f"linear_index:{expected_index}", failures)
        require(event.get("callback_preceded_solver_exactly_once") is True, f"linear_preceded_by_callback:{expected_index}", failures)
        require(event.get("rhs_boundary_equals_frozen_source_exactly") is True, f"linear_rhs_boundary:{expected_index}", failures)
        require(event.get("output_edges_exact") is True, f"linear_output_edges:{expected_index}", failures)
        residual = event.get("linear_residual", {})
        require(residual.get("classification") == EXPECTED_RESIDUAL_CLASS, f"residual_class:{expected_index}", failures)
        for key in residual_keys:
            value = residual.get(key)
            finite_nonnegative = isinstance(value, (int, float)) and math.isfinite(value) and value >= 0.0
            require(finite_nonnegative, f"residual_finite_nonnegative:{expected_index}:{key}", failures)
            if finite_nonnegative:
                residual_values[key].append(float(value))

    observation = solver_output.get("execution_state", {}).get("partial_numerics", {}).get("actual_equilibrium_solve_observation", {})
    calls = observation.get("calls", [])
    require(observation.get("actual_eq_solve_call_count") == 101, "output_actual_solve_call_count_101", failures)
    require(observation.get("formal_freegs_solve_returned") is False, "output_formal_solve_not_returned", failures)
    require(len(calls) == 101, "output_observation_calls_101", failures)
    for i, (call, linear_event) in enumerate(zip(calls, linear_events), 1):
        require(call.get("eq_solve_call_index") == i, f"output_call_index:{i}", failures)
        require(call.get("call_completed") is True, f"output_call_completed:{i}", failures)
        require(call.get("observation_errors") == [], f"output_observation_errors:{i}", failures)
        require(linear_event.get("initial_psi_sha256") == call.get("input_psi", {}).get("values_sha256"), f"output_input_psi_join:{i}", failures)
        require(linear_event.get("output_psi_sha256") == call.get("output_psi", {}).get("values_sha256"), f"output_output_psi_join:{i}", failures)

    reduced = adapter.get("reduced_linear_system", {})
    require(reduced.get("status") == "ready", "linear_system_ready", failures)
    require(reduced.get("shape_r_z") == [65, 65], "linear_system_grid_65x65", failures)
    require(reduced.get("interior_count_unique") == 3969 and reduced.get("boundary_count_unique") == 256, "linear_system_partition_counts", failures)
    require(reduced.get("partition_disjoint_exhaustive") is True, "linear_system_partition", failures)
    require(reduced.get("a_bi_exact_zero") is True and reduced.get("a_bb_exact_identity") is True, "linear_system_boundary_blocks", failures)
    require(reduced.get("full_grid_fallback_permitted") is False and reduced.get("projection_used") is False, "linear_system_no_fallback_or_projection", failures)
    require(reduced.get("residual_threshold") == "not_defined_diagnostic_only", "linear_system_residual_diagnostic_only", failures)

    # Resource and pin evidence: bounded natural run, all processes reaped, no input drift.
    elapsed = execution.get("elapsed_seconds")
    wall_limit = execution.get("wall_limit_seconds")
    peak_rss = execution.get("peak_process_tree_rss_bytes")
    rss_limit = execution.get("process_tree_rss_limit_bytes")
    samples = execution.get("samples", [])
    require(isinstance(elapsed, (int, float)) and elapsed <= wall_limit, "run_within_wall_limit", failures)
    require(isinstance(peak_rss, int) and peak_rss <= rss_limit, "run_within_rss_limit", failures)
    require(execution.get("sample_count") == len(samples), "resource_sample_count", failures)
    require(bool(samples) and samples[-1].get("pids") == [] and samples[-1].get("process_tree_rss_bytes") == 0, "resource_child_reaped", failures)
    require(max((s.get("process_tree_rss_bytes", -1) for s in samples), default=-1) == peak_rss, "resource_peak_matches_samples", failures)

    # Explicitly retain the claim boundary; this is not physical or formal acceptance.
    claims = solver_output.get("claim_boundary", {})
    require(adapter.get("target", {}).get("physics_credit") is False, "adapter_no_physics_credit", failures)
    require(adapter.get("target", {}).get("physical_boundary_flux_claim") is False, "adapter_no_boundary_flux_claim", failures)
    for key in ("formal_acceptance", "independent_validation", "likelihood_ready", "reference_inversion_G1_G2_G3", "terminal_authority"):
        require(claims.get(key) is False, f"claim_false:{key}", failures)
    require(claims.get("solve_attempted") is True and claims.get("solve_completed") is False, "claim_solve_incomplete", failures)

    stdout_fields = run_files["stdout"].read_text(encoding="utf-8").strip().split("\t")
    require(len(stdout_fields) >= 11, "stdout_marker_field_count", failures)
    if len(stdout_fields) >= 11:
        require(stdout_fields[0] == "FUSION_FREEGS_PROFILE_V2", "stdout_marker", failures)
        require(stdout_fields[1] == "numerical_fail_nonconvergence", "stdout_status", failures)
        require(stdout_fields[2] == solver_output.get("result_sha256"), "stdout_result_hash_join", failures)
        require(stdout_fields[5] == solver_output.get("source_snapshot_payload_sha256"), "stdout_source_payload_hash_join", failures)
        require(stdout_fields[10] == run_hashes["solver_output"], "stdout_solver_output_file_hash_join", failures)
    require(run_files["stderr"].stat().st_size == 0, "stderr_empty", failures)

    residual_summary = {
        key: {"min": min(values), "max": max(values)} if values else None
        for key, values in residual_values.items()
    }
    verification = {
        "schema": "independent-freegs-v16-postrun-verification-v1",
        "review_scope": "read-only artifact and event validation; no FreeGS or Julia process launched by this checker",
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": "PASS_RECORDED_NUMERICAL_NONCONVERGENCE_ONLY" if not failures else "NO_GO",
        "failures": failures,
        "protocol": {
            "path": str(protocol_path.resolve()),
            "bytes": protocol_path.stat().st_size,
            "sha256": protocol_sha,
            "expected_sha256": EXPECTED_PROTOCOL_SHA256,
            "schema": protocol.get("schema"),
            "dependency_pin_count": len(pins),
            "all_158_current_pin_hashes_and_sizes_match": all(row["status"] == "match" for row in pin_rows),
            "pin_rows": pin_rows,
        },
        "run_files": {
            name: {"path": str(path.resolve()), "bytes": run_sizes[name], "sha256": run_hashes[name]}
            for name, path in run_files.items()
        },
        "run_outcome": {
            "child_exit_code": execution.get("child_exit_code"),
            "harness_exit_code": execution.get("harness_exit_code"),
            "stop_reason": execution.get("stop_reason"),
            "output_status": solver_output.get("status"),
            "phase": solver_output.get("phase"),
            "exception_type": solver_output.get("exception_type"),
            "message": solver_output.get("message"),
            "elapsed_seconds": elapsed,
            "wall_limit_seconds": wall_limit,
            "peak_process_tree_rss_bytes": peak_rss,
            "process_tree_rss_limit_bytes": rss_limit,
            "resource_sample_count": len(samples),
            "child_reaped": bool(samples) and samples[-1].get("pids") == [] and samples[-1].get("process_tree_rss_bytes") == 0,
            "pins_stable_during_run": execution.get("pins_stable_during_run"),
        },
        "event_validation": {
            "callback_event_count": len(callback_events),
            "scalar_event_count": len(scalar_events),
            "linear_solver_event_count": len(linear_events),
            "output_solve_call_count": len(calls),
            "all_101_callbacks_preserve_all_4_frozen_edges_exactly": not any(x.startswith("callback_edge_") for x in failures),
            "all_101_callbacks_preserve_interior_and_identity": not any(x.startswith("callback_") for x in failures),
            "all_202_scalar_events_are_read_only": not any(x.startswith("scalar_") for x in failures),
            "all_101_linear_events_have_exact_rhs_boundary_and_output_edges": not any(x.startswith("linear_") for x in failures),
            "residual_values_checked_as_receipt_diagnostics_not_rederived_from_operator": residual_summary,
            "residual_boundary_max_abs": residual_summary.get("max_abs_boundary", {}).get("max") if residual_summary.get("max_abs_boundary") else None,
            "linear_system_summary": {
                "status": reduced.get("status"),
                "grid_shape": reduced.get("shape_r_z"),
                "interior_count": reduced.get("interior_count_unique"),
                "boundary_count": reduced.get("boundary_count_unique"),
                "a_bi_zero": reduced.get("a_bi_exact_zero"),
                "a_bb_identity": reduced.get("a_bb_exact_identity"),
                "no_projection": reduced.get("projection_used") is False,
                "no_full_grid_fallback": reduced.get("full_grid_fallback_permitted") is False,
                "residual_threshold": reduced.get("residual_threshold"),
            },
        },
        "claim_boundary": {
            "physics_credit": target.get("physics_credit"),
            "physical_boundary_flux_claim": target.get("physical_boundary_flux_claim"),
            "formal_acceptance": claims.get("formal_acceptance"),
            "independent_validation": claims.get("independent_validation"),
            "solve_attempted": claims.get("solve_attempted"),
            "solve_completed": claims.get("solve_completed"),
            "terminal_authority": claims.get("terminal_authority"),
            "interpretation": "The run recorded 101 fixed-boundary linear solve calls, then failed Picard nonconvergence; it is not a completed FreeGS solve or physical validation.",
        },
        "checker": {"path": str(checker_path), "sha256": sha256_file(checker_path)},
    }

    verification_path = evidence_dir / "verification.json"
    verification_path.write_text(json.dumps(verification, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    command_data = {
        "kind": "non_executable_command_data",
        "argv": list(getattr(sys, "orig_argv", [])),
        "python_executable": sys.executable,
        "checker_script": str(checker_path),
        "evidence_dir": str(evidence_dir),
        "checker_scope": "Python read-only validation only; no FreeGS/Julia subprocess or run command invoked",
    }
    command_path = evidence_dir / "command_argv.json"
    command_path.write_text(json.dumps(command_data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    manifest_files = []
    for path in (verification_path, command_path, checker_path, protocol_path, *run_files.values()):
        manifest_files.append(
            {
                "path": str(path.resolve()),
                "bytes": path.stat().st_size,
                "sha256": sha256_file(path),
                "role": "tester_evidence" if path.parent == evidence_dir else ("tester_source" if path == checker_path else "reviewed_frozen_or_run_input"),
            }
        )
    manifest = {
        "schema": "independent-freegs-v16-postrun-manifest-v1",
        "verdict": verification["verdict"],
        "files": manifest_files,
        "raw_solver_output_copied": False,
        "manifest_self_hash": "not_applicable",
    }
    manifest_path = evidence_dir / "archive_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verification["verdict"], "failures": failures, "verification": str(verification_path), "manifest": str(manifest_path)}, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
