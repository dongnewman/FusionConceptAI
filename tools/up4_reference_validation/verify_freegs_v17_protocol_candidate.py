"""Python-only static verifier for the ungranted FreeGS v17 candidate."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any


SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v17"
INPUT_SHA256 = "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"
SOURCE_SHA256 = "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac"
V15_SOLVER_SHA256 = "489ba5db2816658a5d742fd36740930cab5432404069a99af44cc03e30e36d0d"
V15_RECEIPT_SHA256 = "13e1b0261902d9735a935fcc7f3899c8403ba2c12c8480c6d37f69aa7ebd1bbd"
V15_OBSERVATION_SHA256 = "79ac90db34bc717d652f33a28ff3a5531b8c618a06af3474a6f0712545227cf4"
V16_SOLVER_SHA256 = "8f03ed8f45d5114e3f910bcc70fbe1f74b3807d932daa773aa405b2de414f368"
V16_RECEIPT_SHA256 = "3f2ee3aab365e41dc42603f6b602925077788c1fa5ef696e6ca404ae6b21ff6c"
V16_EXECUTION_SHA256 = "dfbfe3d0e3e8b88f162a33953ccfdd0cbce55bc6902434bca7b58de10d77bfba"
V16_DIAGNOSIS_SHA256 = "be1d8fde0bba5e3cfa0cccda5c07d8d6e33d7d7a956bcfb0487f35c4a9f399db"
V16_TRAJECTORY_SHA256 = "e05c9e210479e63e15c00a8f865287df6284337f439bc85747550bab67aa177c"
V16_MANIFEST_SHA256 = "20f5ab3aa34fa322906e09c493b5f3f977940ae8bb6077873b3b135ec07239af"
V16_MATH_REVIEW_SHA256 = "5a0d41b9379a4327d14587e7552dbe7a12bc383e27fd10d247e9a48e6018919a"
V12_V13_V14_REPORTS = {
    "v12_search_chain": (
        "269156b24a6a6d4efc636fa7430e75c5c5b9a15292e950db5bf85117475c53d6",
        "58e397b77e1b09290276766a9f5c01b6f84caa942ea6ff7fcbcc0f94ab02467f",
    ),
    "v12_native_g1g2": (
        "a801ac0554527df6e08f5c33f96217678360a9a5251de3a3a405915758de6428",
        "b4b842b216ca626d45e7cb374896189585fb5fb3cb5193bb88889dabc8c9eaf7",
    ),
    "v13": (
        "6ccf1ef035f48fb79023c8190424b177a79775f6e65bf56e94f229971520afc7",
        "6f756f360431038393846d1318e7d45178b550a226c34d49fb60e309fcb042ce",
    ),
    "v14": (
        "b214cc5d8281d15d5044dab74401f37ca4951198ab026b52a384435d5b40f5c5",
        "9837a71774b5713c14fe3d9075fcbe16faa3602f88c2b1e1f709a1ab38859ba2",
    ),
}
ARCHIVE_STORAGE_RULE_PREFIX = "raw run/exit/hash/review evidence only under"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def same_path(left: str | Path, right: str | Path) -> bool:
    return str(Path(left).resolve()).casefold() == str(Path(right).resolve()).casefold()


def validate_mandatory_sidecars(sidecars: dict[str, Any], output_path: Path) -> dict[str, Path]:
    leaf = output_path.parent.resolve()
    expected = {
        "adapter_receipt": leaf / "freegs_adapter_receipt_v17.json",
        "execution": leaf / "execution.json",
        "solver_output": leaf / "solver_output.json",
        "stdout": leaf / "stdout.raw",
        "stderr": leaf / "stderr.raw",
    }
    require(
        set(sidecars) == set(expected) | {"storage_rule"},
        "mandatory sidecar schema changed",
    )
    for key, path in expected.items():
        require(same_path(sidecars[key], path), f"mandatory sidecar is not bound to v17 leaf: {key}")
        normalized = str(path).replace("\\", "/").casefold()
        require("/archive/" in normalized, f"mandatory sidecar outside archive: {key}")
        require(not path.exists(), f"mandatory sidecar already exists: {key}")
    require(
        str(sidecars.get("storage_rule", "")).startswith(ARCHIVE_STORAGE_RULE_PREFIX),
        "archive evidence-only storage rule changed",
    )
    return expected


def _writes_attribute(tree: ast.AST, attribute: str) -> bool:
    for node in ast.walk(tree):
        if isinstance(node, (ast.Assign, ast.AnnAssign, ast.AugAssign, ast.NamedExpr)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            if any(
                isinstance(target, ast.Attribute) and target.attr == attribute
                for root in targets for target in ast.walk(root)
            ):
                return True
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            if node.func.id == "setattr" and len(node.args) >= 2:
                arg = node.args[1]
                if isinstance(arg, ast.Constant) and arg.value == attribute:
                    return True
    return False


def _has_outer_terminal_status(tree: ast.AST) -> bool:
    for node in ast.walk(tree):
        if not isinstance(node, ast.ExceptHandler):
            continue
        for child in node.body:
            if not isinstance(child, ast.Assign):
                continue
            if not any(
                isinstance(target, ast.Subscript)
                and isinstance(target.value, ast.Name)
                and target.value.id == "receipt"
                and isinstance(target.slice, ast.Constant)
                and target.slice.value == "status"
                for target in child.targets
            ):
                continue
            if isinstance(child.value, ast.Constant) and child.value.value == "runner_raised":
                return True
    return False


def parse_supervisor_pins(argv: list[str], separator: int) -> dict[str, str]:
    pins: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] == "--require-file-sha256":
            require(index + 1 < separator, "truncated supervisor file pin")
            path_text, digest = argv[index + 1].rsplit("=", 1)
            require(path_text not in pins, "duplicate supervisor file pin")
            pins[path_text] = digest.lower()
            index += 2
        else:
            index += 1
    return pins


def _check_prior_hash(root: Path, block: dict[str, Any], key: str, expected: str) -> None:
    path_key, hash_key = f"{key}_path", f"{key}_sha256"
    require(block.get(hash_key) == expected, f"{key} historical hash declaration changed")
    require(sha256(root / block[path_key]) == expected, f"{key} historical evidence bytes changed")


def _validate_prior_reviews(protocol: dict[str, Any], root: Path) -> dict[str, str]:
    actual: dict[str, str] = {}
    v12 = protocol.get("review_ancestry", {})
    require(v12.get("status") == "sealed_independent_v12_no_go", "v12 NO-GO ancestry status changed")
    for key, member in (("v12_search_chain", "search_chain_tester"), ("v12_native_g1g2", "native_g1g2_reviewer")):
        item = v12.get(member, {})
        expected_report, expected_manifest = V12_V13_V14_REPORTS[key]
        require(sha256(root / item["report_path"]) == expected_report == item.get("report_sha256"), f"{key} report hash changed")
        require(sha256(root / item["manifest_path"]) == expected_manifest == item.get("manifest_sha256"), f"{key} manifest hash changed")
        require(item.get("verdict") == "NO-GO", f"{key} verdict changed")
        actual[key] = expected_report
    prior = protocol.get("prior_candidate_no_go_ancestry", {})
    require(prior.get("status") == "frozen_prior_no_go_only", "v13/v14 prior NO-GO status changed")
    for key, member in (("v13", "v13_dispatch_review"), ("v14", "v14_math_code_review")):
        item = prior.get(member, {})
        expected_report, expected_manifest = V12_V13_V14_REPORTS[key]
        require(sha256(root / item["report_path"]) == expected_report == item.get("report_sha256"), f"{key} report hash changed")
        require(sha256(root / item["manifest_path"]) == expected_manifest == item.get("manifest_sha256"), f"{key} manifest hash changed")
        require(item.get("verdict") == "NO-GO", f"{key} verdict changed")
        actual[key] = expected_report
    math_review = protocol.get("dirichlet_elimination", {}).get("prior_math_proposal_review", {})
    require(math_review.get("verdict") == "GO_math_proposal_only", "v16 math review scope changed")
    require(sha256(root / math_review["report_path"]) == V16_MATH_REVIEW_SHA256, "v16 math review changed")
    actual["v16_math_proposal_only"] = V16_MATH_REVIEW_SHA256
    return actual


def _verify_v16_trajectory(root: Path, prior: dict[str, Any]) -> list[dict[str, Any]]:
    output_path = root / prior["solver_output_path"]
    require(sha256(output_path) == V16_SOLVER_SHA256, "v16 solver output hash changed")
    payload = json.loads(output_path.read_text(encoding="utf-8"))
    observation = (
        payload.get("execution_state", {}).get("partial_numerics", {})
        .get("actual_equilibrium_solve_observation", {})
    )
    require(payload.get("status") == "numerical_fail_nonconvergence", "v16 failure status changed")
    require(payload.get("runner_exit_code") == 4, "v16 natural solver exit changed")
    require(observation.get("iteration_count_claimed") is False, "v16 call count must not be labelled Picard iterations")
    calls = observation.get("calls", [])
    require(len(calls) == 101, "v16 observed Equilibrium.solve call count changed")
    transitions: list[dict[str, Any]] = []
    for index, call in enumerate(calls[:3], start=1):
        updates = [
            item for item in call.get("critical_calls", [])
            if isinstance(item, dict) and item.get("scope") == "equilibrium_boundary_update"
        ]
        require(len(updates) >= 2, f"v16 call {index} lacks boundary topology observations")
        before, after = updates[0].get("x_points"), updates[-1].get("x_points")
        require(isinstance(before, list) and isinstance(after, list), f"v16 call {index} topology not explicit")
        transitions.append({
            "observed_eq_solve_call_index": index,
            "xpoints_before_solve": len(before),
            "xpoints_after_solve": len(after),
        })
    require(
        transitions == [
            {"observed_eq_solve_call_index": 1, "xpoints_before_solve": 4, "xpoints_after_solve": 2},
            {"observed_eq_solve_call_index": 2, "xpoints_before_solve": 2, "xpoints_after_solve": 0},
            {"observed_eq_solve_call_index": 3, "xpoints_before_solve": 0, "xpoints_after_solve": 0},
        ],
        "v16 transient X-point trajectory changed",
    )
    return transitions


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    require(protocol.get("schema") == SCHEMA, "v17 schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "v17 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "v17 candidate cannot authorize runtime")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "root heavy slot is not granted")

    dependencies = protocol.get("dependency_file_pins", [])
    require(protocol.get("dependency_file_pin_count") == len(dependencies), "dependency pin count mismatch")
    step_list = protocol.get("steps")
    require(isinstance(step_list, list) and len(step_list) == 1, "v17 requires one bounded FreeGS step")
    step = step_list[0]
    argv = step.get("launcher_argv_template")
    require(isinstance(argv, list) and "--" in argv, "supervisor argv has no child separator")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)), "Windows argv length receipt mismatch")
    require(step["command_length_chars"] < 32767, "Windows command line limit exceeded")
    separator = argv.index("--")
    launcher_pins = parse_supervisor_pins(argv, separator)
    declared = {str(item["path"]): str(item["sha256"]).lower() for item in dependencies}
    require(len(declared) == len(dependencies), "duplicate declared pins")
    require(launcher_pins == declared, "supervisor pins differ from the protocol pin set")
    for path_text, digest in launcher_pins.items():
        path = Path(path_text)
        require(path.is_file(), f"pinned file missing: {path}")
        require(sha256(path) == digest, f"pinned file hash mismatch: {path}")

    require(argv[0].casefold().endswith("\\anaconda3\\python.exe") and argv[1] == "-B", "supervisor interpreter identity changed")
    require(launcher_pins.get(argv[0]) == sha256(Path(argv[0])), "supervisor interpreter not pinned")
    supervisor = Path(argv[2])
    require(supervisor.name.casefold() == "run_recorded_process.py", "recorded-process harness changed")
    require(launcher_pins.get(str(supervisor)) == sha256(supervisor), "supervisor harness is not pinned")
    require(argv[argv.index("--name") + 1] == "native-axisymmetric-v8-fixed-box-picard-v17", "task name changed")
    require(same_path(argv[argv.index("--cwd") + 1], protocol["repository_root"]), "supervisor cwd changed")
    resources = protocol["resource_contract"]
    require(int(argv[argv.index("--wall-seconds") + 1]) == resources["wall_seconds_per_step"] == 180, "wall limit changed")
    require(int(argv[argv.index("--rss-bytes") + 1]) == resources["process_tree_rss_bytes_per_step"] == 2147483648, "RSS limit changed")
    env = [argv[i + 1] for i, value in enumerate(argv[:separator]) if value == "--env"]
    require(dict(value.split("=", 1) for value in env) == {"PYTHONHASHSEED": "0"}, "explicit environment changed")

    candidate = protocol.get("v17_fixed_box_policy", {})
    require(candidate.get("revision") == "freegs-fixed-observed-box-dirichlet-picard-v1", "policy revision mismatch")
    require(candidate.get("controls") == {"rtol": 1e-5, "atol": 1e-10, "maxits": 100, "blend": 0.0}, "threshold/control drift")
    require(candidate.get("convergence_control_changed_from_native") is True, "v17 stopping-rule change is not disclosed")
    require(candidate.get("boundary_edge_invariant") == "bitwise exact on all four frozen observed edges at initial state, before/after every solve, and after blend", "exact edge gate changed")
    require(candidate.get("historical_v15_guard_cap_wb_per_rad") == 1e-12, "historical v15 guard value drifted")
    require(candidate.get("historical_v15_guard_used_as_acceptance_threshold") is False, "historical guard cannot become an acceptance threshold")
    require(candidate.get("psi_bndry_proxy_read_for_stopping") is False and candidate.get("psi_bndry_proxy_write") is False, "corner proxy is forbidden")
    require(candidate.get("physical_or_inverse_credit") is False, "v17 cannot claim physics/inverse credit")
    require(candidate.get("terminal_topology_gate") == "after psi convergence only: fail closed if terminal xpoint_count != 0 or is_limited", "terminal topology gate changed")
    require(candidate.get("transient_topology") == "observe/record every solve call; permit transient X-points to disappear", "transient topology semantics changed")
    require(candidate.get("native_picard_iteration_count") == "not_run_not_inferred", "native Picard iteration count may not be inferred")
    native_picard = Path(candidate.get("pinned_native_picard_source_path", ""))
    require(native_picard.is_file(), "pinned native Picard source is missing")
    require(sha256(native_picard) == candidate.get("pinned_native_picard_source_sha256") == "731722b98c97dfd758428a411dce684806e36e8cb6e38e69f23552451646880f", "pinned FreeGS 0.8.2 picard.py changed")
    native_picard_text = native_picard.read_text(encoding="utf-8")
    for native_marker in (
        "psi_relchange = psi_maxchange / (amax(psi) - amin(psi))",
        "bndry_relchange = 2.0 * rtol",
        "if maxits and iteration > maxits:",
    ):
        require(native_marker in native_picard_text, f"pinned native Picard control-flow marker changed: {native_marker}")

    child = argv[separator + 1 :]
    require(len(child) == 9 and child[1] == "-B", "direct FreeGS child argv malformed")
    runner = Path(child[2]).resolve()
    require(same_path(runner, protocol["repository_root"] + "\\" + candidate["runner"]), "child runner path is not v17")
    source_paths = {
        "policy": Path(protocol["repository_root"]) / candidate["policy"],
        "runner": runner,
        "test": Path(protocol["repository_root"]) / candidate["test"],
        "static_verifier": Path(protocol["repository_root"]) / candidate["static_verifier"],
    }
    for key, path in source_paths.items():
        digest = sha256(path)
        require(candidate[f"{key}_sha256"] == digest, f"v17 {key} SHA mismatch")
        require(launcher_pins.get(str(path)) == digest, f"v17 {key} not supervisor-pinned")
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))

    child_options = child[3:]
    require(Path(child[0]).resolve() == (Path(protocol["python_dependency_resolution"]["freegs_site_packages"]).parents[1] / "Scripts" / "python.exe").resolve(), "FreeGS child interpreter changed")
    options: dict[str, str] = {}
    require(len(child_options) % 2 == 0, "child options are not key/value pairs")
    for index in range(0, len(child_options), 2):
        require(child_options[index] not in options, "duplicate child option")
        options[child_options[index]] = child_options[index + 1]
    require(set(options) == {"--input", "--source", "--output"}, "child input/output options changed")
    input_path, source_path, output_path = (Path(options[key]) for key in ("--input", "--source", "--output"))
    require(sha256(input_path) == INPUT_SHA256, "v10-generated solver input changed")
    require(sha256(source_path) == SOURCE_SHA256, "shot-30421 source snapshot changed")
    require(same_path(input_path, protocol["source_inputs"]["solver_input_path"]), "solver input path drift")
    require(same_path(source_path, protocol["source_inputs"]["snapshot_path"]), "source snapshot path drift")
    leaf = output_path.parent.resolve()
    require(not leaf.exists(), "new v17 actual output leaf already exists")
    require(same_path(output_path, step["result_path"]), "result path mismatch")
    require(step["required_absent_paths"] == [str(leaf)], "absent-path contract mismatch")
    require(argv[argv.index("--require-absent-path") + 1] == str(leaf), "supervisor absent-path binding mismatch")
    sidecars = validate_mandatory_sidecars(protocol["mandatory_evidence_sidecars"], output_path)
    endpoint = protocol["runtime_endpoint_join"]
    require(same_path(endpoint["output_leaf"], leaf), "runtime output leaf binding mismatch")
    require(same_path(endpoint["solver_output"], sidecars["solver_output"]), "runtime solver-output sidecar mismatch")
    require(same_path(endpoint["adapter_receipt"], sidecars["adapter_receipt"]), "runtime adapter-receipt sidecar mismatch")
    require(endpoint.get("output_leaf_absent_at_candidate_freeze") is True, "fresh output absence not declared")
    for option, filename in (("--stdout", "stdout.raw"), ("--stderr", "stderr.raw"), ("--receipt", "execution.json")):
        require(same_path(argv[argv.index(option) + 1], leaf / filename), f"supervisor {option} leaves archive leaf")

    runner_tree = ast.parse(runner.read_text(encoding="utf-8"))
    policy_tree = ast.parse(source_paths["policy"].read_text(encoding="utf-8"))
    require(not _writes_attribute(policy_tree, "psi_bndry"), "policy must never write eq.psi_bndry")
    require(not any(isinstance(node, ast.Attribute) and node.attr == "psi_bndry" for node in ast.walk(policy_tree)), "policy must not read eq.psi_bndry")
    require(_has_outer_terminal_status(runner_tree), "outer runner exception must set runner_raised")
    runner_text = runner.read_text(encoding="utf-8")
    require("make_freegs_policy_proxy" in runner_text, "v17 must isolate policy solve from FreeGS module namespace")
    require("temporary_observed_dirichlet_linear_solve" in runner_text, "reviewed scoped v16 adapter missing")
    require("picard_stop_effect\"] = \"not_used_by_v17_versioned_policy\"" in runner_text, "old adapter scalar receipt is not corrected for v17 semantics")
    policy_text = source_paths["policy"].read_text(encoding="utf-8")
    for marker in (
        "observed_xpoint_count_sequence",
        "topology_transitions",
        "if limited_after or xpoints_after != 0",
        "all four frozen observed edges",
        "within configured maxits",
    ):
        require(marker in policy_text, f"required v17 policy marker missing: {marker}")

    test_text = source_paths["test"].read_text(encoding="utf-8")
    for marker in (
        "test_transient_xpoints_4_to_2_to_0_are_recorded_terminal_empty_passes",
        "test_terminal_xpoint_fails_closed_after_psi_gate",
        "test_terminal_limited_state_fails_closed",
        "test_signed_zero_edge_drift_fails_even_when_array_equal_is_true",
        "test_v17_policy_maxits_counter_semantics_are_measured_not_inferred",
        "test_runner_binding_context_restores_after_body_exception",
        "test_noninteger_maxits_is_rejected_before_solving",
    ):
        require(marker in test_text, f"required v17 static test missing: {marker}")

    prior = protocol.get("prior_actual_v16_numerical_run", {})
    require(prior.get("status") == "numerical_fail_nonconvergence" and prior.get("natural_solver_exit") == 4, "v16 numerical failure must remain typed and preserved")
    require(prior.get("equilibrium_solve_call_count") == 101 and prior.get("iteration_count_claimed") is False, "v16 actual call count semantics changed")
    require(prior.get("final_linear_residual_max_abs_interior") == 1.077804512306102e-12, "v16 residual observation changed")
    transitions = _verify_v16_trajectory(Path(protocol["repository_root"]), prior)
    require(prior.get("observed_xpoint_transitions") == transitions, "v16 topology trajectory binding changed")
    _check_prior_hash(Path(protocol["repository_root"]), protocol["prior_actual_v15_projection_failure"], "solver_output", V15_SOLVER_SHA256)
    _check_prior_hash(Path(protocol["repository_root"]), protocol["prior_actual_v15_projection_failure"], "adapter_receipt", V15_RECEIPT_SHA256)
    _check_prior_hash(Path(protocol["repository_root"]), protocol["prior_actual_v15_projection_failure"], "root_observation", V15_OBSERVATION_SHA256)
    require(prior.get("adapter_receipt_sha256") == V16_RECEIPT_SHA256, "v16 adapter receipt hash binding changed")
    require(prior.get("execution_sha256") == V16_EXECUTION_SHA256, "v16 execution receipt hash binding changed")
    require(sha256(Path(protocol["repository_root"]) / prior["adapter_receipt_path"]) == V16_RECEIPT_SHA256, "v16 adapter receipt bytes changed")
    require(sha256(Path(protocol["repository_root"]) / prior["execution_path"]) == V16_EXECUTION_SHA256, "v16 execution bytes changed")
    diagnosis = protocol.get("prior_v16_posthoc_diagnosis", {})
    require(diagnosis.get("diagnosis_sha256") == V16_DIAGNOSIS_SHA256, "v16 diagnosis hash declaration changed")
    require(sha256(Path(protocol["repository_root"]) / diagnosis["diagnosis_path"]) == V16_DIAGNOSIS_SHA256, "v16 diagnosis bytes changed")
    require(diagnosis.get("trajectory_sha256") == V16_TRAJECTORY_SHA256, "v16 trajectory hash declaration changed")
    require(sha256(Path(protocol["repository_root"]) / diagnosis["trajectory_path"]) == V16_TRAJECTORY_SHA256, "v16 trajectory bytes changed")
    require(diagnosis.get("manifest_sha256") == V16_MANIFEST_SHA256, "v16 posthoc manifest hash declaration changed")
    require(sha256(Path(protocol["repository_root"]) / diagnosis["manifest_path"]) == V16_MANIFEST_SHA256, "v16 posthoc manifest bytes changed")
    ancestry = _validate_prior_reviews(protocol, Path(protocol["repository_root"]))

    return {
        "status": "static_protocol_check_pass_ungranted",
        "schema": SCHEMA,
        "protocol_sha256": sha256(protocol_path),
        "launcher_pin_count": len(launcher_pins),
        "dependency_pin_count": len(dependencies),
        "all_supervisor_pins_rehashed": True,
        "same_frozen_solver_input_sha256": sha256(input_path),
        "same_frozen_source_snapshot_sha256": sha256(source_path),
        "v16_failure_and_exact_4_to_2_to_0_xpoint_trajectory_bound": transitions,
        "v15_projection_failure_bound": True,
        "v12_v13_v14_no_go_lineage": ancestry,
        "mandatory_sidecars_bound_to_same_fresh_archive_leaf": True,
        "historical_v15_1e12_cap_is_not_acceptance_threshold": True,
        "root_resource_slot_granted": False,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate_candidate(args.protocol.resolve()), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"status": "static_protocol_check_fail", "error": str(exc)}, sort_keys=True))
        raise SystemExit(1)
