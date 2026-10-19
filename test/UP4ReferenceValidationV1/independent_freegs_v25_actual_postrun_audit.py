from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import sys
from typing import Any

import psutil


sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
BASE = Path("docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC")
PROTOCOL = BASE / "agent_reference_gs_20260924/native_axisymmetric_forward_v16/actual_run_protocol_v25_process_tree_candidate_v1.json"
V24_PROTOCOL = BASE / "agent_reference_gs_20260924/native_axisymmetric_forward_v15/actual_run_protocol_v24_process_tree_candidate_v1.json"
SUPERVISOR = Path("tools/up4_reference_validation/freegs_process_supervisor_v25.py")
V24_SUPERVISOR = Path("tools/up4_reference_validation/freegs_process_supervisor_v24.py")
RUN_LEAF = BASE / "archive/root_freegs_v25_grant_20260924"
ACTUAL = RUN_LEAF / "actual_run_r25/freegs_solve"
OUT = ROOT / BASE / "archive/independent_freegs_v25_postrun_tester_20260924_r3"

EXPECTED = {
    "protocol": "ce2a06249c79f9a134adf41bc0731ead1da7189b4fb6fd14ea2d6850e604d8ae",
    "supervisor": "7092ac49e8a6af758b97433b002dbf605ff4cbf12669aa5c5de42ec07c90c53b",
    "pin_manifest": "a71da61f6946d40ca1e52e3e20e82953fa67afdda54f793da4b827f6d0fc7a04",
    "v24_protocol": "2735bfb319695240ba9abc868e76e3b6756146067e635abf83ff0e0c88c37a4d",
    "v24_supervisor": "ebf0e022e3d42622aac2eeff2858b9f70bd4b3cfba7bfbdce4ee28ae191861c7",
    "solver_output": "e1c23b86456927da63f9db5fa0d92deb4964d4b0fa784f64b87b70ffa0c804b6",
    "adapter_receipt": "7cee871eea12f7526071a91b769d4fc4b9b1eae84c46ee1895eb6aaa229c21af",
    "execution_receipt": "c59260de901ecf165b305a2fdfedcb28b7e517b518503cb4ae4fd81490eedfb4",
    "stdout": "5410a2ca4d1907be0c9b13ab2c1f1a03ff23b8086e22a87d6369268133cf40c2",
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def norm(path: str | Path) -> str:
    return os.path.normcase(str(Path(path).resolve(strict=False)))


def finite_number(value: Any) -> bool:
    return type(value) in (int, float) and math.isfinite(float(value))


def main() -> int:
    if not OUT.is_dir():
        raise RuntimeError(f"output evidence leaf must be created first: {OUT}")
    if any(OUT.iterdir()):
        raise RuntimeError(f"refusing to overwrite evidence leaf: {OUT}")

    errors: list[str] = []
    checks: dict[str, bool] = {}
    file_hashes: dict[str, dict[str, Any]] = {}
    for relative, expected in {
        PROTOCOL: EXPECTED["protocol"],
        SUPERVISOR: EXPECTED["supervisor"],
        V24_PROTOCOL: EXPECTED["v24_protocol"],
        V24_SUPERVISOR: EXPECTED["v24_supervisor"],
        Path("tools/up4_reference_validation/freegs_v25_pin_manifest.json"): EXPECTED["pin_manifest"],
    }.items():
        actual = ROOT / relative
        got = sha256_file(actual) if actual.is_file() else None
        file_hashes[str(relative)] = {
            "bytes": actual.stat().st_size if actual.is_file() else None,
            "sha256": got,
            "expected_sha256": expected,
            "match": got == expected,
        }
        if got != expected:
            errors.append(f"frozen hash mismatch: {relative}")

    protocol = load_json(ROOT / PROTOCOL)
    v24_protocol = load_json(ROOT / V24_PROTOCOL)
    execution_path = ROOT / ACTUAL / "execution.json"
    adapter_path = ROOT / ACTUAL / "freegs_adapter_receipt_v18.json"
    output_path = ROOT / ACTUAL / "solver_output.json"
    stdout_path = ROOT / ACTUAL / "stdout.raw"
    stderr_path = ROOT / ACTUAL / "stderr.raw"
    execution = load_json(execution_path)
    adapter = load_json(adapter_path)
    output = load_json(output_path)
    invocation = load_json(ROOT / RUN_LEAF / "invocation.json")
    start = load_json(ROOT / RUN_LEAF / "start.json")
    outer_stdout_path = ROOT / RUN_LEAF / "invocation.stdout.raw"
    outer_stderr_path = ROOT / RUN_LEAF / "invocation.stderr.raw"
    outer_exit_path = ROOT / RUN_LEAF / "invocation.exit.txt"

    pins = protocol["dependency_file_pins"]
    pin_by_norm: dict[str, dict[str, Any]] = {}
    pin_results: list[dict[str, Any]] = []
    for pin in pins:
        key = norm(pin["path"])
        if key in pin_by_norm:
            errors.append(f"duplicate protocol pin path: {pin['path']}")
        pin_by_norm[key] = pin
        path = Path(pin["path"])
        actual_bytes = path.stat().st_size if path.is_file() else None
        actual_hash = sha256_file(path) if path.is_file() else None
        matched = actual_bytes == pin["bytes"] and actual_hash == pin["sha256"].lower()
        pin_results.append({
            "path": pin["path"], "expected_bytes": pin["bytes"],
            "actual_bytes": actual_bytes, "expected_sha256": pin["sha256"].lower(),
            "actual_sha256": actual_hash, "match": matched,
        })
        if not matched:
            errors.append(f"current pin mismatch/missing: {pin['path']}")

    def verify_run_pin_rows(label: str, rows: list[dict[str, Any]]) -> bool:
        row_map = {norm(row["path"]): row for row in rows}
        valid = len(rows) == len(pin_by_norm) and len(row_map) == len(rows)
        valid = valid and set(row_map) == set(pin_by_norm)
        for key, pin in pin_by_norm.items():
            row = row_map.get(key)
            valid = valid and row is not None
            if row is not None:
                valid = valid and row.get("status") == "match"
                valid = valid and row.get("actual_sha256", "").lower() == pin["sha256"].lower()
                valid = valid and row.get("expected_sha256", "").lower() == pin["sha256"].lower()
                try:
                    current_size = Path(pin["path"]).stat().st_size
                except OSError:
                    current_size = None
                valid = valid and pin["bytes"] == current_size
        if not valid:
            errors.append(f"{label} does not exactly match current protocol pin set")
        return bool(valid)

    before_pins_ok = verify_run_pin_rows("execution.required_files", execution["required_files"])
    after_pins_ok = verify_run_pin_rows("execution.required_files_after", execution["required_files_after"])

    v24_map = {norm(row["path"]): (row["bytes"], row["sha256"].lower()) for row in v24_protocol["dependency_file_pins"]}
    v25_map = {norm(row["path"]): (row["bytes"], row["sha256"].lower()) for row in pins}
    inherited = sorted(k for k, v in v24_map.items() if v25_map.get(k) == v)
    changed = sorted(k for k, v in v24_map.items() if k in v25_map and v25_map[k] != v)
    missing_v24 = sorted(set(v24_map) - set(v25_map))
    added_v25 = sorted(set(v25_map) - set(v24_map))

    # Runtime sample arithmetic and identity completeness.
    samples = execution["samples"]
    root_identity = execution["root_identity"]
    root_key = (root_identity["pid"], root_identity["create_time_epoch_s"])
    process_ids = {(row["pid"], row["create_time_epoch_s"]) for row in execution["observed_processes"]}
    sample_sums: list[int] = []
    samples_valid = len(samples) == execution["sample_count"] == 41
    for index, sample in enumerate(samples):
        rows = sample.get("processes", [])
        ids = [(row.get("pid"), row.get("create_time_epoch_s")) for row in rows]
        rss_sum = sum(row.get("rss_bytes", -1) for row in rows)
        sample_sums.append(rss_sum)
        samples_valid = samples_valid and sample.get("complete") is True and sample.get("error") is None
        samples_valid = samples_valid and len(rows) > 0 and len(set(ids)) == len(ids)
        samples_valid = samples_valid and root_key in ids
        samples_valid = samples_valid and all(identity in process_ids for identity in ids)
        samples_valid = samples_valid and all(type(row.get("rss_bytes")) is int and row["rss_bytes"] >= 0 for row in rows)
        samples_valid = samples_valid and sample.get("process_tree_rss_bytes") == rss_sum
        if index and sample.get("elapsed_seconds", -1) < samples[index - 1].get("elapsed_seconds", -1):
            samples_valid = False
    sample_peak = max(sample_sums) if sample_sums else None
    sample_timestamps = [sample.get("elapsed_seconds") for sample in samples]
    samples_valid = samples_valid and all(finite_number(v) for v in sample_timestamps)
    samples_valid = samples_valid and execution["complete_sample_count"] == len(samples)
    samples_valid = samples_valid and execution["all_samples_complete"] is True
    samples_valid = samples_valid and execution["peak_complete_process_tree_rss_bytes"] == sample_peak

    # Non-signalling current-process check for exact sampled identities.
    live_exact: list[dict[str, Any]] = []
    identity_probe: list[dict[str, Any]] = []
    for pid, expected_ct in sorted(process_ids):
        try:
            proc = psutil.Process(pid)
            current_ct = proc.create_time()
            same = abs(current_ct - expected_ct) < 1e-5
            alive = proc.is_running()
            if same and alive:
                live_exact.append({"pid": pid, "create_time_epoch_s": current_ct})
            identity_probe.append({
                "pid": pid, "expected_create_time_epoch_s": expected_ct,
                "current_create_time_epoch_s": current_ct, "same_identity": same,
                "is_running": alive,
            })
        except psutil.NoSuchProcess:
            identity_probe.append({"pid": pid, "expected_create_time_epoch_s": expected_ct,
                                   "state": "no_such_process"})
        except psutil.AccessDenied as exc:
            identity_probe.append({"pid": pid, "expected_create_time_epoch_s": expected_ct,
                                   "state": "access_denied", "error": str(exc)})
            errors.append(f"cannot verify recorded PID identity {pid}: AccessDenied")

    output_copy = dict(output)
    result_sha = output_copy.pop("result_sha256", None)
    canonical_output_sha = sha256_bytes(json.dumps(
        output_copy, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False,
    ).encode("utf-8"))

    # Callback, boundary, linear-solve and actual Equilibrium.solve evidence.
    callbacks = adapter["boundary_callback_events"]
    scalar_events = adapter["boundary_scalar_events"]
    linear_events = adapter["linear_solver_events"]
    edge_names = ("r_min", "r_max", "z_min", "z_max")
    callbacks_valid = len(callbacks) == 24
    for event in callbacks:
        callbacks_valid = callbacks_valid and event.get("callback_identity_exact") is True
        callbacks_valid = callbacks_valid and event.get("target_equilibrium_identity_exact") is True
        callbacks_valid = callbacks_valid and event.get("interior_unchanged") is True
        callbacks_valid = callbacks_valid and event.get("return_was_none") is True
        edge_map = event.get("edge_after_callback", {})
        callbacks_valid = callbacks_valid and all(
            edge_map.get(edge, {}).get("exact") is True
            and edge_map.get(edge, {}).get("max_abs_delta_wb_per_rad") == 0.0
            for edge in edge_names
        )
    scalar_valid = len(scalar_events) == 48 and all(
        event.get("target_equilibrium_identity_exact") is True
        and event.get("solver_psi_bndry_mutated") is False
        and event.get("solver_psi_bndry_write_attempted") is False
        for event in scalar_events
    )
    linear_valid = len(linear_events) == 24 and all(
        event.get("callback_preceded_solver_exactly_once") is True
        and event.get("output_edges_exact") is True
        and event.get("rhs_boundary_equals_frozen_source_exactly") is True
        for event in linear_events
    )
    solve_observation = output["actual_equilibrium_solve_observation"]
    calls = solve_observation["calls"]
    eq_calls_valid = len(calls) == solve_observation["actual_eq_solve_call_count"] == 24
    eq_calls_valid = eq_calls_valid and all(c.get("call_completed") is True and not c.get("observation_errors") for c in calls)
    eq_calls_valid = eq_calls_valid and solve_observation.get("original_callables_restored") is True

    xpoint_update_counts = []
    for call in calls:
        for critical in call.get("critical_calls", []):
            if critical.get("scope") == "equilibrium_boundary_update":
                xpoint_update_counts.append(len(critical.get("x_points", [])))
    terminal_topology_observed = bool(xpoint_update_counts) and xpoint_update_counts[-1] == 0 and all(
        value == 0 for value in xpoint_update_counts[-4:]
    )

    convergence = output["convergence"]
    residual = output["solved_state"]["independent_gs_residual"]
    source_residual_full = output["test_only_frozen_source_jtor_linear_diagnostic"]
    source_residual = {
        "diagnostic_sha256": source_residual_full.get("diagnostic_sha256"),
        "independent_gs_residual": source_residual_full.get("independent_gs_residual"),
        "pde_acceptance": source_residual_full.get("pde_acceptance"),
        "residual_acceptance_threshold": source_residual_full.get("residual_acceptance_threshold"),
        "changes_to_formal_equilibrium": source_residual_full.get("changes_to_formal_equilibrium"),
        "formal_solve_replacement": source_residual_full.get("formal_solve_replacement"),
    }
    expected_output_status = "test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"
    result_bytes = output_path.stat().st_size
    output_digest = sha256_file(output_path)
    stdout = stdout_path.read_bytes()
    stdout_fields = stdout.decode("utf-8").strip().split("\t")
    stdout_consistent = (
        len(stdout_fields) >= 11 and stdout_fields[0] == "FUSION_FREEGS_PROFILE_V2"
        and stdout_fields[1] == output["status"] and stdout_fields[2] == result_sha
        and stdout_fields[6] == str(convergence["iterations"])
        and stdout_fields[7] == str(convergence["final_relative_change"])
        and output_digest in stdout_fields
    )

    # Explicit metadata mismatch: source path/hash is v25, but its receipt label is v24.
    expected_supervisor_version = protocol["process_tree_supervisor_v25"]["version"]
    reported_supervisor_version = execution.get("supervisor_version")
    supervisor_source_text = (ROOT / SUPERVISOR).read_text(encoding="utf-8")
    version_line = next((line.strip() for line in supervisor_source_text.splitlines()
                         if '"supervisor_version"' in line), None)
    command_paths = [str(item).casefold() for item in start["argv"]]
    actual_command_targets_v25 = any("freegs_process_supervisor_v25.py" in item for item in command_paths)
    expected_tree_contract = protocol["process_tree_supervisor_v25"]["tree_observation_contract"]
    reported_tree_contract = execution.get("tree_observation_contract")
    tree_contract_line = next((line.strip() for line in supervisor_source_text.splitlines()
                               if '"tree_observation_contract"' in line), None)

    # Hash every actual-run file, not just selected records.
    run_files = []
    for path in sorted((ROOT / RUN_LEAF).rglob("*")):
        if path.is_file():
            run_files.append({
                "path": str(path.relative_to(ROOT)).replace("\\", "/"),
                "bytes": path.stat().st_size, "sha256": sha256_file(path),
            })

    checks.update({
        "protocol_and_v25_sources_pinned": all(row["match"] for row in file_hashes.values()),
        "all_190_protocol_pins_rehashed": len(pins) == 190 and len(pin_results) == 190 and all(row["match"] for row in pin_results),
        "pre_run_required_files_exactly_match_190_pins": before_pins_ok,
        "post_run_required_files_exactly_match_190_pins": after_pins_ok,
        "v24_lineage_exactly_inherited": len(v24_map) == 179 and len(inherited) == 179 and not changed and not missing_v24 and len(added_v25) == 11,
        "root_and_descendant_sample_series_complete": bool(samples_valid),
        "process_tree_peak_below_2gib": sample_peak is not None and sample_peak < 2_147_483_648,
        "natural_exit_exact_root_and_tree_proven": execution.get("stop_reason") == "root_natural_exit" and execution.get("tree_exit_proven") is True and execution.get("natural_root_exit_identity_check", {}).get("status") == "verified_exact_root_exit",
        "no_exact_sampled_process_identity_remains_live": not live_exact,
        "callback_receipts_preserve_all_four_edges": bool(callbacks_valid),
        "scalar_receipts_record_no_boundary_write": bool(scalar_valid),
        "linear_solve_receipts_bind_rhs_and_edges": bool(linear_valid),
        "24_actual_equilibrium_calls_complete_and_restored": bool(eq_calls_valid),
        "terminal_topology_observed_after_4_to_2_to_0_transition": terminal_topology_observed,
        "solver_output_file_hash_matches_handoff": output_digest == EXPECTED["solver_output"],
        "adapter_and_execution_file_hashes_match_handoff": sha256_file(adapter_path) == EXPECTED["adapter_receipt"] and sha256_file(execution_path) == EXPECTED["execution_receipt"],
        "output_internal_result_digest_matches": result_sha == canonical_output_sha,
        "stdout_row_matches_output_and_measured_iteration": bool(stdout_consistent),
        "outer_invocation_raws_match_receipt": sha256_file(outer_stdout_path) == invocation.get("stdout_sha256") and sha256_file(outer_stderr_path) == invocation.get("stderr_sha256") and sha256_file(outer_exit_path) == invocation.get("exit_sha256") and outer_exit_path.read_text(encoding="utf-8").strip() == "0",
        "bounded_solver_convergence_matches_relative_tolerance": output.get("status") == expected_output_status and convergence["iterations"] == 24 and convergence["final_relative_change"] < convergence["requested_rtol"] and convergence["max_iterations"] == 100,
        "physical_inverse_and_formal_credit_explicitly_false": output["claim_boundary"].get("physical_validation") is False and output["claim_boundary"].get("reference_inversion_G1_G2_G3") is False and output["claim_boundary"].get("formal_acceptance") is False and output["claim_boundary"].get("engineering_validation") is False and invocation.get("physics_credit") is False and invocation.get("formal_reference_inverse_credit") is False,
        "supervisor_version_receipt_matches_protocol": reported_supervisor_version == expected_supervisor_version,
        "tree_observation_contract_receipt_matches_protocol": reported_tree_contract == expected_tree_contract,
        "actual_command_targets_pinned_v25_path": actual_command_targets_v25,
    })
    for name, passed in checks.items():
        if not passed:
            errors.append(f"check failed: {name}")

    # Distinguish the single labeling defect from process/output evidence.
    receipt_contract_checks = {
        "supervisor_version_receipt_matches_protocol",
        "tree_observation_contract_receipt_matches_protocol",
    }
    process_output_checks = [k for k, v in checks.items() if k not in receipt_contract_checks and not v]
    if process_output_checks:
        verdict = "NO_GO_PROCESS_OR_OUTPUT_EVIDENCE_INCOMPLETE"
    elif any(not checks[key] for key in receipt_contract_checks):
        verdict = "NO_GO_FOR_CLEAN_V25_RECEIPT_CERTIFICATION; DIAGNOSTIC_RUN_DATA_PASS"
    else:
        verdict = "GO_BOUNDED_POSTRUN_EVIDENCE_ONLY"

    receipt = {
        "schema": "independent-freegs-v25-postrun-audit-v1",
        "reviewer_role": "independent_read_only_postrun_tester",
        "supersedes_audit_attempt": {
            "path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v25_postrun_tester_20260924/postrun_review_receipt.json",
            "sha256": "26870fc5339015bd86c7f3cf76b557bc3571713353ae982b0b27df3a5377f441",
            "reason": "initial checker tested the v25 supervisor path in child command_argv; this retry correctly tests outer supervisor argv from start.json and also checks both protocol receipt identity fields",
        },
        "supersedes_compactness_retry": {
            "path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v25_postrun_tester_20260924_r2/postrun_review_receipt.json",
            "sha256": "6dd3cf2a47b4a95bdc29d217fc2ba934aee77c903e8b68c03cfad6f37af6a947",
            "reason": "r2 included complete duplicated base64 diagnostic arrays in addition to their source-file hash; r3 keeps only measured residual summaries and exact hashes",
        },
        "frozen_protocol_path": str(PROTOCOL).replace("\\", "/"),
        "frozen_protocol_sha256": sha256_file(ROOT / PROTOCOL),
        "root_actual_leaf": str(RUN_LEAF).replace("\\", "/"),
        "verdict": verdict,
        "checks": checks,
        "errors_and_contract_differences": errors,
        "frozen_and_lineage_hashes": file_hashes,
        "dependency_pin_audit": {
            "protocol_count": protocol["dependency_file_pin_count"],
            "actual_count": len(pins), "matched_count": sum(row["match"] for row in pin_results),
            "mismatches": [row for row in pin_results if not row["match"]],
        },
        "v24_lineage_diff": {
            "v24_count": len(v24_map), "v25_count": len(v25_map),
            "exactly_inherited_count": len(inherited), "changed_paths": changed,
            "missing_v24_paths": missing_v24,
            "v25_additions": [pin_by_norm[k]["path"] for k in added_v25],
        },
        "actual_run": {
            "outer_invocation": invocation,
            "start_receipt": start,
            "child_exit_code": execution["child_exit_code"],
            "harness_exit_code": execution["harness_exit_code"],
            "stop_reason": execution["stop_reason"],
            "elapsed_seconds": execution["elapsed_seconds"],
            "wall_limit_seconds": execution["wall_limit_seconds"],
            "rss_limit_bytes": execution["process_tree_rss_limit_bytes"],
            "peak_tree_rss_bytes": sample_peak,
            "sample_count": len(samples), "complete_sample_count": execution["complete_sample_count"],
            "sampled_peak_elapsed_seconds": samples[sample_sums.index(sample_peak)]["elapsed_seconds"] if sample_sums else None,
            "sampled_identity_probe": identity_probe,
            "still_live_exact_recorded_identities": live_exact,
            "sample_series": {
                "first": samples[0] if samples else None,
                "last": samples[-1] if samples else None,
                "identity_set": [{"pid": pid, "create_time_epoch_s": created} for pid, created in sorted(process_ids)],
            },
            "stdout_sha256": sha256_file(stdout_path),
            "stderr_sha256": sha256_file(stderr_path),
            "invocation_exit_text": (ROOT / RUN_LEAF / "invocation.exit.txt").read_text(encoding="utf-8").strip(),
        },
        "version_label_discrepancy": {
            "protocol_expected": expected_supervisor_version,
            "execution_receipt_reports": reported_supervisor_version,
            "pinned_source_line": version_line,
            "protocol_tree_contract_expected": expected_tree_contract,
            "execution_tree_contract_reports": reported_tree_contract,
            "pinned_source_tree_contract_line": tree_contract_line,
            "execution_command_targets_v25_source_path": actual_command_targets_v25,
            "pinned_v25_source_sha256": EXPECTED["supervisor"],
            "classification": "two receipt/protocol identity-field mismatches; start argv and dependency pin bind the v25 source path/hash, so these stale fields alone do not show that v24 code executed; they prevent clean receipt-contract certification.",
        },
        "solver_output": {
            "file_bytes": result_bytes, "file_sha256": output_digest,
            "status": output["status"], "revision": output["revision"],
            "result_sha256": result_sha, "independently_recomputed_result_sha256": canonical_output_sha,
            "convergence": convergence,
            "independent_gs_residual": residual,
            "frozen_source_jtor_diagnostic": source_residual,
            "residual_acceptance_threshold": output["numerical_assessment"]["independent_gs_residual_acceptance_threshold"],
            "comparison": output["comparison"],
            "claim_boundary": output["claim_boundary"],
            "numerical_assessment": output["numerical_assessment"],
            "topology": {
                "xpoint_counts_at_equilibrium_boundary_update": xpoint_update_counts,
                "status": output.get("free_boundary_status"),
                "claim": "terminal topology observation only; no physical acceptance",
            },
            "warnings": output["warnings"],
        },
        "adapter_audit": {
            "receipt_status": adapter["status"], "runner_return_code": adapter["runner_return_code"],
            "restoration": adapter["restoration"],
            "runner_global_bindings": adapter["runner_global_bindings"],
            "boundary_callback_event_count": len(callbacks),
            "boundary_scalar_event_count": len(scalar_events),
            "linear_solver_event_count": len(linear_events),
            "all_callbacks_exact_edges_and_unchanged_interiors": bool(callbacks_valid),
            "all_scalar_observations_no_write": bool(scalar_valid),
            "all_linear_events_exact_rhs_edges": bool(linear_valid),
            "max_linear_residual_abs": max(event["linear_residual"]["max_abs_all"] for event in linear_events),
            "actual_equilibrium_solve_count": len(calls),
            "all_actual_solve_calls_completed": bool(eq_calls_valid),
        },
        "root_actual_leaf_files": run_files,
        "scope_boundary": "This postrun audit establishes file/receipt/process-tree and bounded numerical-output facts only. It grants no independent inverse, G2 reference, engineering, or physical credit.",
    }
    text = json.dumps(receipt, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False) + "\n"
    receipt_path = OUT / "postrun_review_receipt.json"
    receipt_path.write_text(text, encoding="utf-8", newline="\n")
    receipt_sha = sha256_file(receipt_path)
    summary_text = json.dumps({
        "schema": "independent-freegs-v25-postrun-audit-summary-v1",
        "verdict": verdict,
        "failed_checks": [name for name, passed in checks.items() if not passed],
        "receipt_path": str(receipt_path.relative_to(ROOT)).replace("\\", "/"),
        "receipt_sha256": receipt_sha,
    }, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"
    (OUT / "audit.stdout.raw").write_bytes(summary_text.encode("utf-8"))
    (OUT / "audit.stderr.raw").write_bytes(b"")
    (OUT / "audit.exit.txt").write_bytes(b"0\n")
    command = {
        "argv": [sys.executable, "-B", sys.argv[0]],
        "cwd": str(ROOT), "exit_code": 0, "python_no_bytecode": sys.flags.dont_write_bytecode,
        "scope": "read-only postrun hash/receipt/process/numerical audit; no FreeGS/Julia invocation",
    }
    (OUT / "command_argv.json").write_text(
        json.dumps(command, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n",
        encoding="utf-8", newline="\n",
    )
    evidence_files = []
    for path in sorted(OUT.iterdir()):
        if path.is_file():
            evidence_files.append({"path": path.name, "bytes": path.stat().st_size,
                                   "sha256": sha256_file(path)})
    source_path = Path(__file__).resolve()
    manifest = {
        "schema": "independent-freegs-v25-postrun-evidence-manifest-v1",
        "evidence_leaf": str(OUT.relative_to(ROOT)).replace("\\", "/"),
        "source_path": str(source_path.relative_to(ROOT)).replace("\\", "/"),
        "source_bytes": source_path.stat().st_size,
        "source_sha256": sha256_file(source_path),
        "evidence_files_excluding_manifest": evidence_files,
    }
    (OUT / "evidence_manifest.json").write_text(
        json.dumps(manifest, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n",
        encoding="utf-8", newline="\n",
    )
    sys.stdout.write(summary_text)
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
