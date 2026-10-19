"""Read-only independent audit of the already completed FreeGS r10 evidence.

This reads frozen receipts and solver JSON only. It does not import FreeGS,
start Julia, or modify any source evidence. It writes a derived receipt to the
explicit path supplied by the reviewer.
"""

from __future__ import annotations

import base64
import argparse
import hashlib
import json
import math
import pathlib
import struct

from scipy.constants import mu_0


REPO = pathlib.Path(__file__).resolve().parents[2]
NATIVE = REPO / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_r1_20260922/native_axisymmetric_forward_v2"
GRANT_ROOT = REPO / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/root_freegs_v10_grant_20260923"

EXPECTED_HASHES = {
    "protocol_v10": "366b24785d4ecc1589f215253ab82d4b2dee8703a4b76836d5563b1bea2371d9",
    "static_verification_v10": "355f0d75fccdcb1208fa906e6c3df409db6b7beaf4c24a353574ccbd3206b385",
    "root_grant": "75a5d468df82acf4d4d309379fff88b4ae124e23dada91fe90e141e9f86faeeb",
    "generated_input_binding": "e0f2397e0d5671d62f3be381b8e0c50869742f075cd843a0f11d641d1d433cbf",
    "dispatch_observation": "4944da7aa15eb864a4cef2a42ee673eca5d24ba863da10305c08c9a7959bcbc8",
    "r10_step1_execution": "802be380568dcdb73f40e97eb748ea66e6a8dbb1fc14941ca09448cf9093c08a",
    "r10_step1_stdout": "87e8952e8d902ee71f2acb3662d7106105bed7c22141371ff9eaaeabbb5eb5d7",
    "r10_step2_execution": "020c09f5e2bf71b103dd66073ccacda8f995a8ce4c88ba02bf4c96f086b003f1",
    "r10_step2_stdout": "247a5bf211bdb946b8d499a9ef66ddac098b4c61fe56b49b60494fffd99eacef",
    "r10_solver_output": "0ab33908927e1875cddd4cb56302aa800bfc77a03d9ccf8a709ebc028ef59869",
    "r8_solver_output": "5a90938510dc41266dddc7e4c25989d33311f33dea0473a7e0975e200c010f38",
    "freegs_picard_source": "731722b98c97dfd758428a411dce684806e36e8cb6e38e69f23552451646880f",
    "freegs_equilibrium_source": "1eece1ff87587a90aeba662b1ab15bb313d1e1493b140074db33e8b2ff93567e",
    "runner_source": "3fbc8262ea9e6ab58e06892349bc3640e36d88f2985d950cc386b511e6e3b4ec",
}


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def artifact_hashes() -> dict[str, str]:
    files = {
        "protocol_v10": NATIVE / "actual_run_protocol_v10.json",
        "static_verification_v10": NATIVE / "protocol_static_verification_v10.json",
        "root_grant": GRANT_ROOT / "grant.json",
        "generated_input_binding": GRANT_ROOT / "generated_input_binding.json",
        "dispatch_observation": GRANT_ROOT / "dispatch_observation.json",
        "r10_step1_execution": NATIVE / "actual_run_r10/julia_closure/execution.json",
        "r10_step1_stdout": NATIVE / "actual_run_r10/julia_closure/stdout.raw",
        "r10_step2_execution": NATIVE / "actual_run_r10/freegs_solve/execution.json",
        "r10_step2_stdout": NATIVE / "actual_run_r10/freegs_solve/stdout.raw",
        "r10_solver_output": NATIVE / "actual_run_r10/freegs_solve/solver_output.json",
        "r8_solver_output": NATIVE / "actual_run_r8/freegs_solve/solver_output.json",
        "freegs_picard_source": pathlib.Path(r"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Lib\site-packages\freegs\picard.py"),
        "freegs_equilibrium_source": pathlib.Path(r"D:\006-Programing\LMC\outputs\fusion_concept_ai\.venv-freegs\Lib\site-packages\freegs\equilibrium.py"),
        "runner_source": REPO / "scripts/runtime_v4_freegs_axisymmetric_profile_runner_v2.py",
    }
    actual = {name: sha256(path) for name, path in files.items()}
    assert actual == EXPECTED_HASHES, "one or more reviewed inputs no longer match their frozen hashes"
    return actual


def summarize_residual(psi: list[list[float]], jtor: list[list[float]], r: list[float], z: list[float]) -> dict:
    dr = float(r[1] - r[0])
    dz = float(z[1] - z[0])
    rhs_values: list[float] = []
    residual_values: list[float] = []
    for i in range(1, len(r) - 1):
        for j in range(1, len(z) - 1):
            center = psi[i][j]
            operator = (
                (psi[i + 1][j] - 2.0 * center + psi[i - 1][j]) / dr**2
                - (psi[i + 1][j] - psi[i - 1][j]) / (2.0 * dr * r[i])
                + (psi[i][j + 1] - 2.0 * center + psi[i][j - 1]) / dz**2
            )
            rhs = -mu_0 * r[i] * jtor[i][j]
            rhs_values.append(rhs)
            residual_values.append(operator - rhs)
    threshold = max(1.0e-30, 1.0e-12 * max(abs(value) for value in rhs_values))
    selected = [(rhs, residual) for rhs, residual in zip(rhs_values, residual_values) if abs(rhs) > threshold]
    return {
        "mu_0_from_scipy_constants": mu_0,
        "mask_threshold": threshold,
        "plasma_mask_count": len(selected),
        "plasma_l2_relative": math.sqrt(sum(residual**2 for _, residual in selected))
        / max(math.sqrt(sum(rhs**2 for rhs, _ in selected)), 1.0e-30),
        "plasma_linf_relative": max(abs(residual) for _, residual in selected)
        / max(max(abs(rhs) for rhs, _ in selected), 1.0e-30),
        "plasma_rms_absolute": math.sqrt(sum(residual**2 for _, residual in selected) / len(selected)),
        "status": "reviewer_derived_from_r10_terminal_partial_psi_and_observed_eq_jtor_not_stored_as_runner_output",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--receipt", required=True, type=pathlib.Path)
    args = parser.parse_args()
    out = args.receipt.resolve()
    hashes = artifact_hashes()
    protocol = read_json(NATIVE / "actual_run_protocol_v10.json")
    static = read_json(NATIVE / "protocol_static_verification_v10.json")
    grant = read_json(GRANT_ROOT / "grant.json")
    step1 = read_json(NATIVE / "actual_run_r10/julia_closure/execution.json")
    step2 = read_json(NATIVE / "actual_run_r10/freegs_solve/execution.json")
    input_path = NATIVE / "actual_run_r10/julia_closure/validate_artifacts/solver_input.canonical.json"
    solver_input = read_json(input_path)
    r8 = read_json(NATIVE / "actual_run_r8/freegs_solve/solver_output.json")
    r10 = read_json(NATIVE / "actual_run_r10/freegs_solve/solver_output.json")

    pins = {item["path"].replace("/", "\\").casefold(): item["sha256"] for item in protocol["dependency_file_pins"]}
    assert protocol["dependency_file_pin_count"] == 149 == len(pins)
    assert static["all_checks_pass"] is True and len(static["live_pin_checks"]) == 149
    assert grant["granted"] is True
    assert grant["protocol_sha256"] == hashes["protocol_v10"]
    assert grant["static_verification_sha256"] == hashes["static_verification_v10"]
    assert grant["head"] == protocol["git_head"] == "63792ca22958ffca8c3fa8e642256eb9f7240724"
    assert grant["concurrent_julia_or_freegs"] == []
    assert grant["resource_per_step"] == {"process_tree_rss_bytes": 2147483648, "wall_seconds": 180}

    pin_audit = {}
    generated_input_key = str(input_path).replace("/", "\\").casefold()
    for stage_name, receipt in (("step1_julia_closure", step1), ("step2_freegs_solve", step2)):
        before = {item["path"].replace("/", "\\").casefold(): item for item in receipt["required_files"]}
        after = {item["path"].replace("/", "\\").casefold(): item for item in receipt["required_files_after"]}
        bad = [item for item in [*before.values(), *after.values()] if item["status"] != "match" or item["actual_sha256"] != item["expected_sha256"]]
        assert not bad
        assert set(before) == set(after)
        assert all(before[key]["expected_sha256"] == after[key]["expected_sha256"] for key in before)
        extras = {key: item["expected_sha256"] for key, item in before.items() if key not in pins}
        assert all(key in before and before[key]["expected_sha256"] == digest for key, digest in pins.items())
        if stage_name == "step1_julia_closure":
            assert set(before) == set(pins)
        else:
            assert set(before) == set(pins) | {generated_input_key}
            assert extras == {generated_input_key: "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"}
        assert receipt["pins_stable_during_run"] is True
        assert receipt["required_file_changes"] == [] and receipt["preflight_errors"] == []
        pin_audit[stage_name] = {
            "required_files_before_and_after": len(before),
            "every_expected_and_actual_hash_matches": True,
            "exact_149_protocol_pin_set_present": stage_name == "step1_julia_closure",
            "additional_non_protocol_file": extras,
            "pins_stable_during_run": True,
            "required_file_changes": 0,
        }

    assert step1["stop_reason"] == "natural_exit" and step1["child_exit_code"] == step1["harness_exit_code"] == 0
    assert step2["stop_reason"] == "natural_exit" and step2["child_exit_code"] == step2["harness_exit_code"] == 4
    assert step1["elapsed_seconds"] < 180 and step2["elapsed_seconds"] < 180
    assert step1["peak_process_tree_rss_bytes"] < 2147483648 and step2["peak_process_tree_rss_bytes"] < 2147483648

    r8_pn = r8["execution_state"]["partial_numerics"]
    r10_pn = r10["execution_state"]["partial_numerics"]
    r8_input = read_json(NATIVE / "actual_run_r8/julia_closure/validate_artifacts/solver_input.canonical.json")
    assert solver_input["controls"] == r8_input["controls"]
    assert solver_input["source_snapshot_payload_sha256"] == "2175141f835b75c6c3dec0f656c6fb6d53cf387b4245d026df456fc2c8789b78"
    changed_identity_fields = sorted(key for key in solver_input if solver_input[key] != r8_input.get(key))
    assert changed_identity_fields == [
        "binding_hash", "candidate_hash", "compiled_prefix_hash", "context_hash",
        "declaration_hash", "field_geometry_genome_hash", "physical_subject_hash",
    ]
    assert r8_pn["source_state"]["jtor_a_per_m2"]["values_sha256"] == r10_pn["source_state"]["jtor_a_per_m2"]["values_sha256"]
    assert r8_pn["source_state"]["psi_wb_per_rad"]["values_sha256"] == r10_pn["source_state"]["psi_wb_per_rad"]["values_sha256"]
    assert r8_pn["source_state"]["independent_gs_residual"] == r10_pn["source_state"]["independent_gs_residual"]
    assert r8_pn["partial_solver_psi"]["values_sha256"] == r10_pn["partial_solver_psi"]["values_sha256"]
    assert r10["status"] == r8["status"] == "numerical_fail_nonconvergence"
    assert r10["message"] == r8["message"] == "Picard iteration failed to converge (too many iterations)"

    observer = r10_pn["actual_equilibrium_solve_observation"]
    calls = observer["calls"]
    assert observer["observer_scope"] == "actual_bound_equilibrium_solve_calls_inside_pinned_freegs_solve"
    assert observer["actual_eq_solve_call_count"] == len(calls) == 101
    assert observer["iteration_count_claimed"] is False and observer["formal_freegs_solve_returned"] is False
    assert [call["eq_solve_call_index"] for call in calls] == list(range(1, 102))
    assert all(call["call_completed"] is True and "exception" not in call for call in calls)
    assert calls[-1]["output_psi"]["values_sha256"] == r10_pn["partial_solver_psi"]["values_sha256"]
    assert calls[0]["eq_psi_boundary_after"]["status"] == "finite_observed"
    assert all(call["eq_psi_boundary_after"]["status"] == "typed_absent" for call in calls[1:])
    final_critical_updates = [call["critical_calls"][-1] for call in calls]
    assert all(item["scope"] == "equilibrium_boundary_update" for item in final_critical_updates)
    assert len(final_critical_updates[0]["x_points"]) == 2
    assert all(len(item["x_points"]) == 0 for item in final_critical_updates[1:])
    supplied_boundaries = [call["supplied_psi_boundary"]["value"] for call in calls]
    assert len(set(supplied_boundaries)) == 1

    controls = solver_input["controls"]
    rtol = float(controls["rtol"])
    atol = float(controls["atol"])
    first_boundary = float(calls[0]["eq_psi_boundary_after"]["value"])
    retained_boundary_change = -first_boundary  # FreeGS initializes bndry to zero and computes bndry_last - bndry.
    terminal_changes = {}
    for index in (99, 100):
        call = calls[index]
        delta = call["picard_change"]
        psi_gate = delta["max_abs_wb_per_rad"]["value"] < atol or delta["relative_to_output_span"]["value"] < rtol
        boundary_gate = (2.0 * rtol < rtol) or (abs(retained_boundary_change) < atol)
        assert psi_gate is True and boundary_gate is False
        terminal_changes[str(call["eq_solve_call_index"])] = {
            "max_abs_wb_per_rad": delta["max_abs_wb_per_rad"]["value"],
            "relative_to_output_span": delta["relative_to_output_span"]["value"],
            "psi_change_gate_passes": psi_gate,
            "psi_bndry_after": call["eq_psi_boundary_after"]["status"],
            "none_branch_bndry_relchange": 2.0 * rtol,
            "stale_abs_bndry_change": abs(retained_boundary_change),
            "boundary_gate_passes": boundary_gate,
        }

    last_jtor_entry = calls[-1]["eq_jtor_after"]
    packed = base64.b64decode(last_jtor_entry["values_base64"])
    values = [item[0] for item in struct.iter_unpack("<d", packed)]
    nr, nz = last_jtor_entry["shape"]
    assert len(values) == nr * nz
    jtor = [values[row * nz : (row + 1) * nz] for row in range(nr)]
    partial_psi = r10_pn["partial_solver_psi"]["values"]
    radial = r10_pn["source_state"]["r_m"]["values"]
    vertical = r10_pn["source_state"]["z_m"]["values"]
    terminal_residual = summarize_residual(partial_psi, jtor, radial, vertical)
    diag = r10_pn["test_only_frozen_source_jtor_linear_diagnostic"]

    result = {
        "schema": "fusionconceptai:native-freegs-r10-independent-review-v1",
        "review_mode": "read_only_no_freegs_or_julia_started",
        "requested_model_effort": "GPT-6 Luna/max",
        "actual_model_effort_visibility": "not exposed to this reviewer context",
        "head": protocol["git_head"],
        "evidence_hashes": hashes,
        "static_review": {
            "protocol_dependency_file_pin_count": len(pins),
            "static_verification_all_checks_pass": static["all_checks_pass"],
            "static_verification_live_pin_checks": len(static["live_pin_checks"]),
            "static_verification_process_exit_code": "not recorded in the verifier JSON",
            "external_root_grant": grant,
            "stage_pin_audit": pin_audit,
        },
        "actual_stages": {
            "step1": {
                "name": step1["name"], "command_argv": step1["command_argv"],
                "stop_reason": step1["stop_reason"], "child_exit_code": step1["child_exit_code"],
                "harness_exit_code": step1["harness_exit_code"], "elapsed_seconds": step1["elapsed_seconds"],
                "peak_process_tree_rss_bytes": step1["peak_process_tree_rss_bytes"],
                "pins_stable": step1["pins_stable_during_run"],
                "result_boundary": "Julia source-closure/input-validation only; FUSION_RUN_FREEGS_PROFILE_V2_SOLVE=0; generated receipt is validated_input_no_solve",
                "stderr_sha256": step1["stderr_sha256"], "stdout_sha256": step1["stdout_sha256"],
                "receipt_sha256": step1["receipt_sha256"],
            },
            "step2": {
                "name": step2["name"], "command_argv": step2["command_argv"],
                "stop_reason": step2["stop_reason"], "child_exit_code": step2["child_exit_code"],
                "harness_exit_code": step2["harness_exit_code"], "elapsed_seconds": step2["elapsed_seconds"],
                "peak_process_tree_rss_bytes": step2["peak_process_tree_rss_bytes"],
                "pins_stable": step2["pins_stable_during_run"], "status": r10["status"],
                "phase": r10["phase"], "exception_type": r10["exception_type"], "message": r10["message"],
                "stderr_sha256": step2["stderr_sha256"], "stdout_sha256": step2["stdout_sha256"],
                "receipt_sha256": step2["receipt_sha256"],
                "solver_input_sha256": sha256(input_path),
            },
        },
        "r8_delta": {
            "controls_identical": True,
            "source_snapshot_file_sha256": solver_input["source_snapshot_file_sha256"],
            "source_snapshot_payload_sha256": solver_input["source_snapshot_payload_sha256"],
            "source_psi_sha256_identical": r8_pn["source_state"]["psi_wb_per_rad"]["values_sha256"],
            "source_jtor_sha256_identical": r8_pn["source_state"]["jtor_a_per_m2"]["values_sha256"],
            "source_residual_identical": r8_pn["source_state"]["independent_gs_residual"],
            "terminal_partial_psi_sha256_identical": r8_pn["partial_solver_psi"]["values_sha256"],
            "terminal_partial_psi_shape": r10_pn["partial_solver_psi"]["shape"],
            "terminal_partial_psi_finite_count": r10_pn["partial_solver_psi"]["finite_count"],
            "identity_hash_fields_changed": changed_identity_fields,
            "r8_terminal_actual_jtor_trace": "not available; r8 stored no per-call Equilibrium.solve observation",
        },
        "numerical_evidence": {
            "controls": controls,
            "actual_eq_solve_call_count": len(calls),
            "call_index_semantics": observer["call_index_semantics"],
            "iteration_count_claimed": observer["iteration_count_claimed"],
            "all_eq_solve_calls_completed": all(call["call_completed"] for call in calls),
            "top_level_freegs_solve_returned": observer["formal_freegs_solve_returned"],
            "picard_iteration_count": "unknown; FreeGS returned no convergence arrays",
            "first_boundary_flux_after_call1": first_boundary,
            "profile_supplied_boundary_each_call": supplied_boundaries[0],
            "final_boundary_update_xpoint_count_call1": len(final_critical_updates[0]["x_points"]),
            "final_boundary_update_xpoint_count_calls2_to101": 0,
            "call101_max_observed_dirichlet_edge_drift_wb_per_rad": max(
                entry["max_abs_drift_wb_per_rad"]["value"]
                for entry in calls[-1]["observed_boundary_drift"].values()
            ),
            "boundary_flux_status_calls2_to101": "typed_absent",
            "terminal_call_gate_observation": terminal_changes,
            "source_state_residual": r10_pn["source_state"]["independent_gs_residual"],
            "test_only_frozen_source_jtor_linear_diagnostic": {
                "status": diag["status"], "formal_solve_replacement": diag["formal_solve_replacement"],
                "residual": diag["independent_gs_residual"],
            },
            "terminal_partial_state_residual": terminal_residual,
            "terminal_partial_state_residual_scope": "reviewer-derived from the saved partial psi and the actual final eq.Jtor observation; no acceptance threshold is defined",
        },
        "static_root_cause": {
            "finding": "FreeGS's generic Picard boundary convergence gate cannot pass after psi_bndry becomes None under this custom fixed-boundary callback; psi-change gate is already met at calls 100 and 101.",
            "source_evidence": {
                "equilibrium_source_sha256": EXPECTED_HASHES["freegs_equilibrium_source"],
                "equilibrium_source_location": "FreeGS 0.8.2 equilibrium.py: _updateBoundaryPsi fixedBoundary identity branch assigns psi[0,0]; the custom callback's no-X-point branch assigns psi_bndry=None (source lines 621-626).",
                "picard_source_sha256": EXPECTED_HASHES["freegs_picard_source"],
                "picard_source_location": "picard.py: None boundary branch sets bndry_relchange=2*rtol; convergence also requires boundary-change tolerance; maxits guard follows eq.solve and iteration increment (source lines 173-183, 216-232).",
            },
            "boundary_change_initial_value": 0.0,
            "retained_abs_boundary_change": abs(retained_boundary_change),
            "atol": atol,
            "rtol": rtol,
            "formal_acceptance": False,
        },
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"audit_receipt": str(out), "status": "pass", "receipt_sha256": sha256(out)}, sort_keys=True))


if __name__ == "__main__":
    main()
