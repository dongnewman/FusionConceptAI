"""Python-only static verifier for the ungranted v16 FreeGS candidate."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any


EXPECTED_SCHEMA = (
    "fusionconceptai:native-axisymmetric-forward-fixed-dirichlet-dof-elimination-v16"
)
EXPECTED_INPUT_SHA256 = "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"
EXPECTED_SOURCE_SHA256 = "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac"
EXPECTED_V15_SOLVER_OUTPUT_SHA256 = (
    "489ba5db2816658a5d742fd36740930cab5432404069a99af44cc03e30e36d0d"
)
EXPECTED_V15_ADAPTER_RECEIPT_SHA256 = (
    "13e1b0261902d9735a935fcc7f3899c8403ba2c12c8480c6d37f69aa7ebd1bbd"
)
EXPECTED_V15_OBSERVATION_SHA256 = (
    "79ac90db34bc717d652f33a28ff3a5531b8c618a06af3474a6f0712545227cf4"
)
EXPECTED_MATH_REVIEW_SHA256 = (
    "5a0d41b9379a4327d14587e7552dbe7a12bc383e27fd10d247e9a48e6018919a"
)
EXPECTED_PROJECTION_CAP = 1.0e-12

EXPECTED_NO_GO = {
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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def same_path(left: str | Path, right: str | Path) -> bool:
    return str(Path(left).resolve()).casefold() == str(Path(right).resolve()).casefold()


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


def _calls_method(tree: ast.AST, method: str) -> bool:
    return any(
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and node.func.attr == method
        for node in ast.walk(tree)
    )


def _module_constant(tree: ast.AST, name: str) -> Any:
    for node in getattr(tree, "body", []):
        if isinstance(node, ast.Assign) and any(
            isinstance(target, ast.Name) and target.id == name
            for target in node.targets
        ):
            try:
                return ast.literal_eval(node.value)
            except (ValueError, TypeError):
                return None
    return None


def _has_terminal_outer_error_receipt(tree: ast.AST) -> bool:
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


def validate_mandatory_sidecars(sidecars: dict[str, Any], output_path: Path) -> dict[str, Path]:
    expected_leaf = output_path.parent.resolve()
    expected = {
        "adapter_receipt": expected_leaf / "freegs_adapter_receipt_v16.json",
        "execution": expected_leaf / "execution.json",
        "solver_output": expected_leaf / "solver_output.json",
        "stdout": expected_leaf / "stdout.raw",
        "stderr": expected_leaf / "stderr.raw",
    }
    require(set(sidecars) == set(expected) | {"storage_rule"}, "mandatory sidecar schema changed")
    for key, path in expected.items():
        require(same_path(sidecars[key], path), f"mandatory sidecar is not bound to v16 leaf: {key}")
        require("/archive/" in str(path).replace("\\", "/").casefold(), f"sidecar outside archive: {key}")
        require(not path.exists(), f"mandatory sidecar already exists: {key}")
    require(sidecars.get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"), "archive storage rule changed")
    return expected


def parse_supervisor_pins(argv: list[str], separator: int) -> dict[str, str]:
    pins: dict[str, str] = {}
    i = 0
    while i < separator:
        if argv[i] == "--require-file-sha256":
            require(i + 1 < separator, "truncated file-pin argument")
            path_text, digest = argv[i + 1].rsplit("=", 1)
            require(path_text not in pins, "duplicate supervisor file pin")
            pins[path_text] = digest.lower()
            i += 2
        else:
            i += 1
    return pins


def validate_no_go_ancestry(protocol: dict[str, Any], root: Path) -> dict[str, str]:
    ancestry = protocol.get("prior_candidate_no_go_ancestry", {})
    require(ancestry.get("status") == "frozen_prior_no_go_only", "v13/v14 prior NO-GO status changed")
    actual: dict[str, str] = {}
    for key, reports in (
        ("v13", [ancestry.get("v13_dispatch_review", {})]),
        ("v14", [ancestry.get("v14_math_code_review", {})]),
    ):
        for item in reports:
            p = root / item["report_path"]
            m = root / item["manifest_path"]
            exp_report, exp_manifest = EXPECTED_NO_GO[key]
            require(sha256(p) == exp_report == item.get("report_sha256"), f"{key} NO-GO report hash mismatch")
            require(sha256(m) == exp_manifest == item.get("manifest_sha256"), f"{key} NO-GO manifest hash mismatch")
            actual[key] = exp_report
    reviews = protocol.get("review_ancestry", {})
    require(reviews.get("status") == "sealed_independent_v12_no_go", "v12 NO-GO ancestry status changed")
    for key, member in (
        ("v12_search_chain", "search_chain_tester"),
        ("v12_native_g1g2", "native_g1g2_reviewer"),
    ):
        item = reviews.get(member, {})
        rp, mp = EXPECTED_NO_GO[key]
        require(sha256(root / item["report_path"]) == rp == item.get("report_sha256"), f"{key} report hash mismatch")
        require(sha256(root / item["manifest_path"]) == mp == item.get("manifest_sha256"), f"{key} manifest hash mismatch")
        actual[key] = rp
    math_review = protocol.get("dirichlet_elimination", {}).get("prior_math_proposal_review", {})
    require(math_review.get("verdict") == "GO_math_proposal_only", "v16 math proposal verdict changed")
    require(math_review.get("report_sha256") == EXPECTED_MATH_REVIEW_SHA256, "v16 math review hash declaration mismatch")
    require(sha256(root / math_review["report_path"]) == EXPECTED_MATH_REVIEW_SHA256, "v16 math review bytes changed")
    return actual


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    require(protocol.get("schema") == EXPECTED_SCHEMA, "v16 protocol schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "candidate state must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "v16 must not claim runtime authorization")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "root heavy slot must remain ungranted")
    require(protocol.get("dependency_file_pin_count") == len(protocol.get("dependency_file_pins", [])), "dependency pin count mismatch")
    step_list = protocol.get("steps")
    require(isinstance(step_list, list) and len(step_list) == 1, "v16 requires one bounded FreeGS step")
    step = step_list[0]
    argv = step.get("launcher_argv_template")
    require(isinstance(argv, list) and "--" in argv, "launcher argv is missing the child separator")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)), "launcher command length receipt mismatch")
    require(step["command_length_chars"] < 32767, "Windows command line exceeds the platform limit")
    separator = argv.index("--")
    pins = parse_supervisor_pins(argv, separator)
    declared = {
        str(item["path"]): str(item["sha256"]).lower()
        for item in protocol["dependency_file_pins"]
    }
    require(len(declared) == len(protocol["dependency_file_pins"]), "duplicate declared dependency pin")
    require(pins == declared, "supervisor pins do not exactly match declared dependency pins")
    for path_text, digest in pins.items():
        path = Path(path_text)
        require(path.is_file(), f"pinned input is missing: {path}")
        require(sha256(path) == digest, f"pinned input hash mismatch: {path}")

    require(argv[0].casefold().endswith("\\anaconda3\\python.exe") and argv[1] == "-B", "supervisor interpreter must remain pinned Python -B")
    require(pins.get(argv[0]) == sha256(Path(argv[0])), "supervisor interpreter is not hash-pinned")
    require(Path(argv[2]).name.casefold() == "run_recorded_process.py", "launcher must use the pinned recorded-process supervisor")
    require(pins.get(str(Path(argv[2]))) == sha256(Path(argv[2])), "recorded-process supervisor is not hash-pinned")
    require(argv[argv.index("--name") + 1] == "native-axisymmetric-v7-fixed-dirichlet-elimination-r16", "supervisor task name changed")
    require(same_path(argv[argv.index("--cwd") + 1], protocol["repository_root"]), "supervisor cwd changed")
    require(int(argv[argv.index("--wall-seconds") + 1]) == protocol["resource_contract"]["wall_seconds_per_step"], "wall-time resource gate changed")
    require(int(argv[argv.index("--rss-bytes") + 1]) == protocol["resource_contract"]["process_tree_rss_bytes_per_step"], "RSS resource gate changed")
    env_values = [argv[i + 1] for i, item in enumerate(argv[:separator]) if item == "--env"]
    env_map = dict(value.split("=", 1) for value in env_values)
    require(env_map == {"PYTHONHASHSEED": "0"}, "explicit supervisor environment changed")
    supervisor_text = Path(argv[2]).read_text(encoding="utf-8")
    require("environment.update(thread_environment)" in supervisor_text, "pinned supervisor no longer applies the thread environment")
    for key, value in protocol["resource_contract"]["thread_environment"].items():
        require(f'"{key}": "{value}"' in supervisor_text, f"pinned supervisor thread limit changed: {key}")

    root = Path(protocol["repository_root"]).resolve()
    child = argv[separator + 1 :]
    runner_rel = protocol["v7_runner"]["runner"]
    runner = root / runner_rel
    require(Path(child[2]).resolve() == runner.resolve(), "child runner path is not v7")
    require(pins.get(str(runner)) == sha256(runner), "v7 runner is not supervisor-pinned")
    expected_python = Path(protocol["python_dependency_resolution"]["freegs_site_packages"]).parents[1] / "Scripts" / "python.exe"
    require(len(child) >= 8, "child argv is truncated")
    require(same_path(child[0], expected_python), "child interpreter differs from the pinned FreeGS venv")
    require(child[1] == "-B", "child bytecode writing must remain disabled")
    child_options = child[3:]
    values: dict[str, str] = {}
    i = 0
    while i < len(child_options):
        option = child_options[i]
        require(option.startswith("--") and i + 1 < len(child_options), "invalid child argv option")
        values[option] = child_options[i + 1]
        i += 2
    require(set(values) == {"--input", "--source", "--output"}, "child argv options changed")
    input_path, source_path, output_path = Path(values["--input"]), Path(values["--source"]), Path(values["--output"])
    source_inputs = protocol["source_inputs"]
    require(sha256(input_path) == EXPECTED_INPUT_SHA256, "frozen v10 solver input hash changed")
    require(sha256(source_path) == EXPECTED_SOURCE_SHA256, "frozen v2 source snapshot hash changed")
    require(protocol["v7_runner"]["numerical_controls"]["rtol"] == 1.0e-5, "rtol changed")
    require(protocol["v7_runner"]["numerical_controls"]["atol"] == 1.0e-10, "atol changed")
    require(protocol["v7_runner"]["numerical_controls"]["maxits"] == 100, "maxits changed")
    require(protocol["v7_runner"]["numerical_controls"]["blend"] == 0.0, "Picard blend changed")
    require(protocol["v7_runner"]["numerical_controls"]["mode"] == "source_and_observed_dirichlet_fixed_boundary", "solver mode changed")
    require(source_inputs["same_source_profile_derivative_diagnostic"]["scope"].startswith("finite-difference same-source diagnostic"), "source-state interpretation changed")

    expected_leaf = output_path.parent
    require(not expected_leaf.exists(), "new v16 output leaf already exists")
    require(same_path(step["result_path"], output_path), "step result path differs from child output")
    require(step["name"] == "direct_actual_freegs_fixed_observed_box_dof_elimination_v7_r16", "step name does not bind v16")
    require(step["required_absent_paths"] == [str(expected_leaf)], "absent-path guard differs from v16 output leaf")
    require(argv[argv.index("--require-absent-path") + 1] == str(expected_leaf), "launcher absent-path guard differs")
    for option, filename in (
        ("--stdout", "stdout.raw"),
        ("--stderr", "stderr.raw"),
        ("--receipt", "execution.json"),
    ):
        pos = argv.index(option)
        require(pos + 1 < separator, f"launcher missing {option}")
        require(same_path(argv[pos + 1], expected_leaf / filename), f"{option} is outside the new v16 leaf")

    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    expected_sidecars = validate_mandatory_sidecars(sidecars, output_path)
    endpoint = protocol.get("runtime_endpoint_join", {})
    require(same_path(endpoint.get("output_leaf", ""), expected_leaf), "runtime endpoint output leaf mismatch")
    require(same_path(endpoint.get("solver_output", ""), expected_sidecars["solver_output"]), "runtime endpoint solver output mismatch")
    require(same_path(endpoint.get("adapter_receipt", ""), expected_sidecars["adapter_receipt"]), "runtime endpoint adapter receipt mismatch")
    require(endpoint.get("output_leaf_absent_at_candidate_freeze") is True, "fresh leaf absence was not declared")

    elimination = protocol.get("dirichlet_elimination", {})
    require(elimination.get("equation") == "A_BI=0 and A_BB=I imply psi_B=b_B=g_B; solve A_II psi_I=b_I-A_IB g_B", "block-equivalence statement changed")
    require(elimination.get("flatten_order") == "C order with row=x*ny+y", "C-order row convention changed")
    require(elimination.get("boundary_partition") == "unique union of the four edges; shared corners occur once; disjoint exhaustive interior/boundary index sets", "boundary-index contract changed")
    require(elimination.get("same_operator") == "rebuild the exact pinned FreeGS 0.8.2 GSsparse4thOrder matrix with the constructor's frozen bounds and shape; verify the initial MGDirect object identity", "operator identity contract changed")
    require(elimination.get("setSolverVcycle_policy") == "reject if solver object identity differs from the constructor-captured MGDirect; unchecked setSolverVcycle is forbidden because it rebuilds the second-order GSsparse operator", "setSolverVcycle control changed")
    require(elimination.get("no_full_grid_fallback") is True, "full-grid fallback must remain forbidden")
    require(elimination.get("projection_cap_wb_per_rad") == EXPECTED_PROJECTION_CAP, "historical 1e-12 guard changed")
    require(elimination.get("projection_method") == "no post-solve projection; boundary unknowns are eliminated before solving; no threshold waiver", "projection behavior changed")
    require(elimination.get("residual_acceptance_threshold") == "not_defined_diagnostic_only", "residual threshold was invented")
    require(elimination.get("picard_controls_changed") is False, "Picard controls changed")
    require(elimination.get("psi_bndry_proxy_write") is False, "psi_bndry proxy write is forbidden")
    require(elimination.get("physical_or_physics_credit") is False, "v16 candidate cannot claim physics credit")

    tests = (root / protocol["v7_runner"]["test"]).read_text(encoding="utf-8")
    for marker in (
        "test_wrong_sign_negative_control_fails_full_interior_residual",
        "test_a_ib_contains_expected_nonzero_couplings_with_correct_c_order_sign",
        "test_factorization_is_per_outer_solve_and_reused_only_within_that_scope",
        "test_set_solver_vcycle_identity_change_is_rejected_before_dispatch",
        "test_grid_coordinate_change_is_rejected_before_dispatch",
        "test_adapter_does_not_write_psi_bndry_or_call_set_solver_vcycle",
        "test_v16_precontext_runner_failure_is_terminal_without_restore_claim",
        "test_v13_precontext_negative_control_remains_started",
        "test_each_mandatory_sidecar_rejects_retargeting",
        "test_solver_requires_callback_before_each_solve_and_restores_after_failure",
        "test_solver_exception_has_no_full_grid_fallback",
    ):
        require(marker in tests, f"required v16 static test missing: {marker}")
    source_hash_fields = {
        protocol["v7_runner"]["runner"]: "runner_sha256",
        protocol["v7_runner"]["adapter"]: "adapter_sha256",
        protocol["v7_runner"]["elimination_core"]: "elimination_core_sha256",
        protocol["v7_runner"]["test"]: "test_sha256",
        protocol["v7_runner"]["static_verifier"]: "static_verifier_sha256",
    }
    runner_tree = ast.parse(runner.read_text(encoding="utf-8"))
    for rel in (
        protocol["v7_runner"]["runner"],
        protocol["v7_runner"]["adapter"],
        protocol["v7_runner"]["elimination_core"],
        protocol["v7_runner"]["test"],
        protocol["v7_runner"]["static_verifier"],
    ):
        path = root / rel
        require(path.is_file(), f"v16 candidate file missing: {rel}")
        ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        digest = sha256(path)
        require(protocol["v7_runner"][source_hash_fields[rel]] == digest, f"v16 source hash mismatch: {rel}")
        require(pins.get(str(path)) == digest, f"v16 source is not supervisor-pinned: {rel}")
    require(_module_constant(runner_tree, "VERSIONED_REVISION") == protocol["v7_runner"]["revision"], "v7 runner revision identity mismatch")
    adapter_tree = ast.parse((root / protocol["v7_runner"]["adapter"]).read_text(encoding="utf-8"))
    require(not _writes_attribute(adapter_tree, "psi_bndry"), "adapter must never assign psi_bndry")
    require(not _writes_attribute(runner_tree, "psi_bndry"), "runner must never assign psi_bndry")
    require(not _calls_method(adapter_tree, "setSolverVcycle"), "adapter must reject rather than call setSolverVcycle")
    require(_has_terminal_outer_error_receipt(runner_tree), "outer runner exception must always set terminal runner_raised")
    require("1.0e-12" in (root / protocol["v7_runner"]["elimination_core"]).read_text(encoding="utf-8"), "historical projection guard literal missing")

    history = protocol.get("prior_actual_v15_projection_failure", {})
    require(history.get("solver_output_sha256") == EXPECTED_V15_SOLVER_OUTPUT_SHA256, "v15 raw solver-output hash binding changed")
    require(history.get("adapter_receipt_sha256") == EXPECTED_V15_ADAPTER_RECEIPT_SHA256, "v15 adapter receipt hash binding changed")
    require(history.get("root_observation_sha256") == EXPECTED_V15_OBSERVATION_SHA256, "v15 root observation hash binding changed")
    for key in ("solver_output_path", "adapter_receipt_path", "root_observation_path"):
        require(sha256(root / history[key]) == history[key.replace("_path", "_sha256")], f"historical v15 failure evidence changed: {key}")
    require(history.get("event_index") == 35, "v15 failed event index changed")
    require(history.get("r_max_max_abs_delta_wb_per_rad") == 1.0143656747896301e-12, "v15 measured edge drift changed")
    require(history.get("status") == "program_exception_exit5_pre_update", "v15 failure classification changed")
    no_go = validate_no_go_ancestry(protocol, root)
    return {
        "status": "static_protocol_check_pass_ungranted",
        "schema": protocol["schema"],
        "protocol_sha256": sha256(protocol_path),
        "launcher_pin_count": len(pins),
        "dependency_pin_count": len(declared),
        "all_supervisor_pins_rehashed": True,
        "child_argv_binding_valid": True,
        "same_frozen_solver_input_sha256": sha256(input_path),
        "same_frozen_source_snapshot_sha256": sha256(source_path),
        "root_resource_slot_granted": False,
        "solver_output_leaf_exists": expected_leaf.exists(),
        "mandatory_sidecars_bound_to_same_new_archive_leaf": True,
        "v15_failure_preserved_and_hash_bound": True,
        "prior_no_go_ancestry": no_go,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    args = parser.parse_args()
    result = validate_candidate(args.protocol.resolve())
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"status": "static_protocol_check_fail", "error": str(exc)}, sort_keys=True))
        raise SystemExit(1)
