"""Python-only verifier for the ungranted FreeGS v21 status-set candidate."""

from __future__ import annotations

import ast
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
from typing import Any


SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v21-status-contract"
SUCCESS_STATUS = "test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"
V20_PROTOCOL_SHA256 = "ede17bf2edb8cf70127c29022da89aafb463e733d22e240b9a874939b7a45862"
V20_STATUS_VERIFIER_SHA256 = "8faa2051b98e0dc5d204d885f9eefe99cdf5ded98e28013b35f7e3ac6b53b832"
V20_STATUS_TEST_SHA256 = "167337b55fa42d7d431befeab9f4c63c3f6e995ef8b6dae1555e12393f8bf6db"
EXPECTED_STATUS_SETS = {
    "0": [SUCCESS_STATUS],
    "2": ["input_validation_failed"],
    "3": ["backend_unavailable"],
    "4": [
        "numerical_fail_boundary_invariant",
        "numerical_fail_invalid_state",
        "numerical_fail_nonconvergence",
    ],
    "5": ["program_exception"],
    "6": ["unsupported_fixed_box_terminal_topology"],
}
CATEGORY_SUMMARY = {
    "0": "success",
    "2": "input_validation_failure",
    "3": "backend_unavailable",
    "4": "numerical_failure",
    "5": "program_exception",
    "6": "unsupported_terminal_topology",
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def status_accepts(exit_code: int | str, status: str, allowed: dict[str, list[str]]) -> bool:
    return status in allowed.get(str(exit_code), [])


def validate_status_set_contract(
    step: dict[str, Any], contract: dict[str, Any], source_derived: dict[str, list[str]]
) -> None:
    exact_map = step.get("natural_exit_statuses_by_code")
    required_status = step.get("result_exit_schema_contract", {}).get("success", {}).get("required_status")
    require(required_status == SUCCESS_STATUS == source_derived["0"][0], "v21 success status differs from pinned runner")
    require(exact_map == source_derived == EXPECTED_STATUS_SETS, "v21 exact natural status sets differ from runner source")
    require(contract.get("runner_emitted_statuses_by_exit_code") == source_derived, "v21 recorded source-derived status sets differ")
    require(step.get("natural_exit_map") == CATEGORY_SUMMARY, "v21 natural_exit_map must remain category-only")
    require(step.get("natural_exit_map_scope") == "category_summary_only_not_an_exact_status_map", "v21 category map scope is ambiguous")
    failures = step.get("result_exit_schema_contract", {}).get("typed_failures", {})
    require(failures.get("natural_exit_codes") == [2, 3, 4, 5, 6], "v21 typed failure exit code list changed")
    require(failures.get("required_fields") == ["status", "runner_exit_code"], "v21 typed failure fields changed")
    require(failures.get("rule") == "runner_exit_code must be an exact natural exit key and status must be a member of natural_exit_statuses_by_code[runner_exit_code]; the category-only natural_exit_map is not a status allow-list", "v21 typed failure contract rule changed")


def _function(tree: ast.AST, name: str) -> ast.FunctionDef:
    matches = [node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef) and node.name == name]
    require(len(matches) == 1, f"expected one function named {name}")
    return matches[0]


def runner_success_status(runner_tree: ast.AST) -> str:
    matches: list[str] = []
    function = _function(runner_tree, "write_v18_result")
    for node in ast.walk(function):
        if not isinstance(node, ast.Assign):
            continue
        if any(
            isinstance(target, ast.Subscript)
            and isinstance(target.value, ast.Name)
            and target.value.id == "result"
            and isinstance(target.slice, ast.Constant)
            and target.slice.value == "status"
            for target in node.targets
        ) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
            matches.append(node.value.value)
    require(matches == [SUCCESS_STATUS], "pinned runner successful result status changed")
    return matches[0]


def _literal_pair(node: ast.AST) -> tuple[str, int] | None:
    if not isinstance(node, ast.Return) or not isinstance(node.value, ast.Tuple) or len(node.value.elts) != 2:
        return None
    status, code = node.value.elts
    if (isinstance(status, ast.Constant) and isinstance(status.value, str)
            and isinstance(code, ast.Constant) and isinstance(code.value, int)):
        return status.value, code.value
    return None


def policy_failure_pairs(runner_tree: ast.AST) -> set[tuple[str, int]]:
    function = _function(runner_tree, "_classify_policy_failure")
    pairs = {_literal_pair(node) for node in ast.walk(function)}
    pairs.discard(None)
    require(pairs == {
        ("numerical_fail_nonconvergence", 4),
        ("numerical_fail_boundary_invariant", 4),
        ("numerical_fail_invalid_state", 4),
        ("unsupported_fixed_box_terminal_topology", 6),
        ("program_exception", 5),
    }, "pinned v9 policy failure classifier status/exit pairs changed")
    return pairs  # type: ignore[return-value]


def baseline_failure_pairs(baseline_tree: ast.AST) -> set[tuple[str, int]]:
    code_maps: list[dict[str, int]] = []
    for node in baseline_tree.body:
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == "FAILURE_EXIT_CODES" for target in node.targets):
            continue
        if isinstance(node.value, ast.Dict):
            code_maps.append({
                key.value: value.value
                for key, value in zip(node.value.keys, node.value.values)
                if isinstance(key, ast.Constant) and isinstance(key.value, str)
                and isinstance(value, ast.Constant) and isinstance(value.value, int)
            })
    require(len(code_maps) == 1, "pinned baseline failure exit table is not unique")
    exit_codes = code_maps[0]
    require(exit_codes == {
        "input_validation_failed": 2,
        "backend_unavailable": 3,
        "numerical_fail_nonconvergence": 4,
        "program_exception": 5,
    }, "pinned baseline failure exit table changed")
    function = _function(baseline_tree, "classify_failure")
    assigned: set[str] = set()
    for node in ast.walk(function):
        if not isinstance(node, ast.Assign) or not any(isinstance(t, ast.Name) and t.id == "status" for t in node.targets):
            continue
        if isinstance(node.value, ast.Constant) and isinstance(node.value.value, str):
            assigned.add(node.value.value)
    require(assigned == set(exit_codes), "pinned baseline failure classifier status set changed")
    pairs = {(status, exit_codes[status]) for status in assigned}
    require(any(
        isinstance(node, ast.Return) and isinstance(node.value, ast.Tuple)
        and len(node.value.elts) == 2
        and isinstance(node.value.elts[0], ast.Name) and node.value.elts[0].id == "status"
        and isinstance(node.value.elts[1], ast.Subscript)
        and isinstance(node.value.elts[1].value, ast.Name)
        and node.value.elts[1].value.id == "FAILURE_EXIT_CODES"
        for node in ast.walk(function)
    ), "pinned baseline classifier no longer emits its status/code table directly")
    return pairs


def runner_statuses_by_exit_code(runner_path: Path, baseline_path: Path) -> dict[str, list[str]]:
    runner_tree = ast.parse(runner_path.read_text(encoding="utf-8"), filename=str(runner_path))
    baseline_tree = ast.parse(baseline_path.read_text(encoding="utf-8"), filename=str(baseline_path))
    policy_pairs = policy_failure_pairs(runner_tree)
    fallback_pairs = baseline_failure_pairs(baseline_tree)

    classify = _function(runner_tree, "classify_v18")
    direct_fallback = any(
        isinstance(node, ast.Return) and isinstance(node.value, ast.Call)
        and isinstance(node.value.func, ast.Name) and node.value.func.id == "_classify_policy_failure"
        and len(node.value.args) == 3
        and isinstance(node.value.args[1], ast.Subscript)
        and isinstance(node.value.args[1].value, ast.Name)
        and node.value.args[1].value.id == "originals"
        for node in ast.walk(classify)
    )
    require(direct_fallback, "v9 classifier no longer passes fallback status/code through without normalization")

    all_pairs = fallback_pairs | policy_pairs | {(runner_success_status(runner_tree), 0)}
    derived: dict[str, list[str]] = {}
    for status, code in all_pairs:
        derived.setdefault(str(code), []).append(status)
    for statuses in derived.values():
        statuses.sort()
    require(derived == EXPECTED_STATUS_SETS, "runner/source-derived natural exit status sets changed")
    return derived


def parse_supervisor_pins(argv: list[str], separator: int) -> dict[str, str]:
    pins: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] == "--require-file-sha256":
            require(index + 1 < separator, "truncated supervisor file pin")
            path_text, digest = argv[index + 1].rsplit("=", 1)
            require(path_text not in pins, "duplicate supervisor pin")
            pins[path_text] = digest.lower()
            index += 2
        else:
            index += 1
    return pins


def _load_v20_verifier(path: Path):
    spec = importlib.util.spec_from_file_location("freegs_v20_status_verifier_frozen", path)
    require(spec is not None and spec.loader is not None, "cannot load frozen v20 verifier")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    root = Path(protocol["repository_root"]).resolve()
    require(protocol.get("schema") == SCHEMA, "v21 schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "v21 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "v21 cannot authorize execution")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "root heavy slot is not granted")

    contract = protocol.get("protocol_status_contract_v21", {})
    require(contract.get("schema") == "fusionconceptai:freegs-runner-exit-status-set-contract-v1", "v21 status-set contract missing")
    step_list = protocol.get("steps")
    require(isinstance(step_list, list) and len(step_list) == 1, "v21 requires one bounded FreeGS step")
    step = step_list[0]
    expected_step = "direct_actual_freegs_fixed_observed_box_picard_policy_v21_status_contract"
    expected_task = "native-axisymmetric-v9-fixed-box-picard-v21-status-contract"
    require(step.get("name") == expected_step == contract.get("step_name"), "v21 step identity mismatch")

    prior = contract.get("prior_v20_candidate", {})
    v20_path = root / prior.get("protocol_path", "")
    require(prior.get("protocol_sha256") == V20_PROTOCOL_SHA256, "v20 prior protocol hash declaration changed")
    require(v20_path.is_file() and sha256(v20_path) == V20_PROTOCOL_SHA256, "v20 prior protocol bytes changed")
    v20 = json.loads(v20_path.read_text(encoding="utf-8"))
    v20_contract = v20.get("protocol_status_contract_v20", {})
    v20_step = v20.get("steps", [{}])[0]
    require(v20_step.get("natural_exit_map", {}).get("4") == "numerical_fail_nonconvergence_or_boundary_invariant", "v20 scalar exit-4 defect ancestry changed")
    require("natural_exit_statuses_by_code" not in v20_step, "v20 must remain preserved without the v21 exact status-set repair")
    require("mapped natural child exit" in v20_step.get("result_exit_schema_contract", {}).get("typed_failures", {}).get("rule", ""), "v20 failure rule ancestry changed")
    require(prior.get("prior_exit4_scalar_status") == v20_step.get("natural_exit_map", {}).get("4"), "v20 scalar exit-4 status declaration changed")
    require(prior.get("v20_exit4_status_set") == EXPECTED_STATUS_SETS["4"], "v20 observed exit-4 status set declaration changed")
    prior_v20_verifier = root / v20_contract.get("static_verifier", "")
    prior_v20_test = root / v20_contract.get("static_test", "")
    require(sha256(prior_v20_verifier) == V20_STATUS_VERIFIER_SHA256 == v20_contract.get("static_verifier_sha256"), "v20 verifier ancestry pin changed")
    require(sha256(prior_v20_test) == V20_STATUS_TEST_SHA256 == v20_contract.get("static_test_sha256"), "v20 test ancestry pin changed")
    # Preserve the prior full static result as ancestry. It is not a v20 semantic GO:
    # the exit-4 scalar status-set omission is separately and explicitly rejected above.
    prior_verifier = _load_v20_verifier(prior_v20_verifier)
    prior_result = prior_verifier.validate_candidate(v20_path)
    require(prior_result.get("status") == "static_protocol_check_pass_ungranted", "v20 frozen ancestry verifier no longer passes its own pins")

    expected_v20_step = "direct_actual_freegs_fixed_observed_box_picard_policy_v20_status_contract"
    require(v20_step.get("name") == expected_v20_step, "v20 prior step label changed")
    prior_leaf = v20.get("runtime_endpoint_join", {}).get("output_leaf")
    require(isinstance(prior_leaf, str) and not Path(prior_leaf).exists(), "v20 output leaf must remain absent")

    dependencies = protocol.get("dependency_file_pins", [])
    require(protocol.get("dependency_file_pin_count") == len(dependencies) == 165, "v21 dependency pin count mismatch")
    prior_dependencies = {str(x["path"]): str(x["sha256"]).lower() for x in v20.get("dependency_file_pins", [])}
    new_dependencies = {str(x["path"]): str(x["sha256"]).lower() for x in dependencies}
    require(len(new_dependencies) == len(dependencies), "duplicate v21 dependency pin")
    v20_test_path = str(root / v20_contract["static_test"])
    v20_verifier_path = str(root / v20_contract["static_verifier"])
    new_test_path = str(root / contract.get("static_test", ""))
    new_verifier_path = str(root / contract.get("static_verifier", ""))
    expected_dependency_paths = (set(prior_dependencies) - {v20_test_path, v20_verifier_path}) | {new_test_path, new_verifier_path}
    require(set(new_dependencies) == expected_dependency_paths, "v21 dependency pin set is not the exact V20 replacement set")
    for path_text, digest in prior_dependencies.items():
        if path_text not in {v20_test_path, v20_verifier_path}:
            require(new_dependencies[path_text] == digest, f"inherited dependency pin changed: {path_text}")
    for path_text, digest in new_dependencies.items():
        path = Path(path_text)
        require(path.is_file() and sha256(path) == digest, f"v21 dependency pin mismatch: {path}")

    frozen_files = protocol.get("frozen_files", {})
    v20_frozen = v20.get("frozen_files", {})
    for path_text, digest in v20_frozen.items():
        require(frozen_files.get(path_text) == digest, f"inherited frozen source pin changed: {path_text}")
    require(frozen_files.get(contract.get("static_verifier")) == sha256(root / contract.get("static_verifier", "")), "v21 verifier missing from frozen file pins")
    require(frozen_files.get(contract.get("static_test")) == sha256(root / contract.get("static_test", "")), "v21 test missing from frozen file pins")

    argv = step.get("launcher_argv_template")
    require(isinstance(argv, list) and "--" in argv, "v21 launcher argv missing child separator")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)), "v21 Windows command length receipt mismatch")
    require(step["command_length_chars"] < 32767, "v21 Windows command line limit exceeded")
    prior_argv = v20_step.get("launcher_argv_template")
    require(isinstance(prior_argv, list), "v20 prior launcher argv missing")
    expected_argv = list(prior_argv)

    def replace_option(option: str, value: str) -> None:
        index = expected_argv.index(option)
        expected_argv[index + 1] = value

    new_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"]).resolve()
    replace_option("--name", expected_task)
    replace_option("--stdout", str(new_leaf / "stdout.raw"))
    replace_option("--stderr", str(new_leaf / "stderr.raw"))
    replace_option("--receipt", str(new_leaf / "execution.json"))
    replace_option("--require-absent-path", str(new_leaf))
    prior_separator = expected_argv.index("--")
    child_options = expected_argv[prior_separator + 1 :]
    require("--output" in child_options, "v20 prior child argv has no output option")
    child_options[child_options.index("--output") + 1] = str(new_leaf / "solver_output.json")
    expected_argv[prior_separator + 1 :] = child_options
    for index, value in enumerate(expected_argv[:prior_separator]):
        if value.casefold().startswith(v20_test_path.casefold() + "="):
            expected_argv[index] = new_test_path + "=" + new_dependencies[new_test_path]
        elif value.casefold().startswith(v20_verifier_path.casefold() + "="):
            expected_argv[index] = new_verifier_path + "=" + new_dependencies[new_verifier_path]
    require(argv == expected_argv, "v21 launcher argv has an unauthorized change beyond status pins/task/output leaf")
    separator = argv.index("--")
    launcher_pins = parse_supervisor_pins(argv, separator)
    require(launcher_pins == new_dependencies, "v21 supervisor pins differ from exact protocol pin set")
    require(argv[argv.index("--name") + 1] == expected_task == contract.get("supervisor_task_name"), "v21 supervisor task name mismatch")

    runner = root / contract.get("runner_source_path", "")
    baseline = root / contract.get("baseline_runner_source_path", "")
    require(sha256(runner) == contract.get("runner_source_sha256"), "pinned v9 runner source hash mismatch")
    require(sha256(baseline) == contract.get("baseline_runner_source_sha256"), "pinned baseline v2 runner source hash mismatch")
    source_derived = runner_statuses_by_exit_code(runner, baseline)
    validate_status_set_contract(step, contract, source_derived)
    require(contract.get("negative_controls") == [
        "exhaustive cross product: every natural exit code/status pair accepts if and only if source-derived map contains that status",
        "reject the v20 scalar exit-4 summary string as a solver status",
        "reject exit-4 numerical statuses when paired with exit 5 or 6",
        "reject program_exception on exit 4 and unsupported topology on exit 5",
        "reject removal of any source-derived status and reject any cross-code status insertion",
        "source-derived map includes baseline v2 fallback and all v9 policy-specific failure branches",
    ], "v21 failure-map negative-control contract changed")

    source_input = protocol.get("source_inputs", {})
    require(sha256(Path(source_input["solver_input_path"])) == source_input["solver_input_sha256"] == "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447", "frozen v10 generated solver input changed")
    require(sha256(Path(source_input["snapshot_path"])) == source_input["snapshot_sha256"] == "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac", "frozen shot-30421 snapshot changed")
    out_path = Path(step["result_path"])
    require(out_path.resolve() == new_leaf / "solver_output.json", "v21 result path does not match fresh output leaf")
    require(step.get("required_absent_paths") == [str(new_leaf)], "v21 absent-path guard is not bound to the new output leaf")
    require(not out_path.parent.exists(), "v21 fresh output leaf already exists")
    require(Path(protocol["mandatory_evidence_sidecars"]["solver_output"]) == out_path, "v21 output sidecar binding mismatch")
    require(Path(protocol["runtime_endpoint_join"]["solver_output"]) == out_path, "v21 runtime endpoint mismatch")
    for key in ("adapter_receipt", "execution", "stderr", "stdout"):
        sidecar = Path(protocol["mandatory_evidence_sidecars"][key])
        require(sidecar.parent == out_path.parent and not sidecar.exists(), f"v21 {key} sidecar is not a fresh same-leaf receipt")
    require(protocol["mandatory_evidence_sidecars"].get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"), "v21 archive storage rule changed")
    require(protocol["runtime_endpoint_join"].get("output_leaf_absent_at_candidate_freeze") is True, "v21 fresh output absence not recorded")

    return {
        "status": "static_protocol_check_pass_ungranted",
        "protocol_sha256": sha256(protocol_path),
        "dependency_pin_count": len(dependencies),
        "all_supervisor_pins_rehashed": True,
        "v20_no_go_exit4_scalar_mismatch_bound": True,
        "runner_source_derived_statuses_by_exit_code": source_derived,
        "category_summary_separate_from_exact_status_allow_list": True,
        "all_exit_code_status_pairs_exhaustively_testable": True,
        "same_frozen_solver_input_sha256": source_input["solver_input_sha256"],
        "same_frozen_source_snapshot_sha256": source_input["snapshot_sha256"],
        "root_resource_slot_granted": False,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
    }


def main() -> int:
    import argparse

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
