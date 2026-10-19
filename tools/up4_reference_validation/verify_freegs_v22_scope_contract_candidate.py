"""Static-only verifier for the FreeGS v22 restored-scope candidate."""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
from typing import Any


SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v22-scope-contract"
V20_PROTOCOL_SHA256 = "ede17bf2edb8cf70127c29022da89aafb463e733d22e240b9a874939b7a45862"
V21_PROTOCOL_SHA256 = "7cbeb53d780cd055737213ec12f78c3733c85f04a9e33d73c39d3bb8730caa43"
V21_VERIFIER_SHA256 = "48e8f2a927da75899e6751775191054cdc611d88624286797b47abf10231806f"
V21_TEST_SHA256 = "3cce29c4be4d7b044bc3819b0e869e6dbfb39de4e2c42a13d36bc52615e2363c"
V21_SCOPE_REVIEW_SHA256 = "db053fe78d80af66c1fda4b186c3b24e983e8c5fdf99c40d6076b61a474785b8"
V21_SCOPE_REVIEW_MANIFEST_SHA256 = "7ce1ab20b0f699c379e115e3a3662f8b7c379646a181d06eb7efad62b03d8bbe"
V21_REFERENCE_REVIEW_SHA256 = "382765c00801316f4e196d3c3920940c98d5927453e6022aee47508255240379"
V21_REFERENCE_REVIEW_MANIFEST_SHA256 = "8be3e1c69d4f44b3975a79e66f9cf1964a5eab6a9e310756d1d03e3c0f2a6024"
V21_OWNER_EVIDENCE_MANIFEST_SHA256 = "93a17c49e8b892d51294cfcfccdfcdcd59503021ad8505d707be29ea6138c351"
V21_STATUS_SETS = {
    "0": ["test_only_fixed_observed_box_dirichlet_policy_v2_converged_residual_measured"],
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
V21_CATEGORY_SUMMARY = {
    "0": "success",
    "2": "input_validation_failure",
    "3": "backend_unavailable",
    "4": "numerical_failure",
    "5": "program_exception",
    "6": "unsupported_terminal_topology",
}
EXPECTED_SCOPE = {
    "G1_G3": "runtime_v4_declared_fixture_placeholders",
    "boundary": "observed_dirichlet_box_edges_from_same_reconstruction",
    "boundary_convergence_semantics": (
        "Unchanged from the pinned v18 candidate: fixed observed edges, rtol/atol/maxits/blend, "
        "policy order, observer gate, residual reporting, and all numerical source bytes are unchanged."
    ),
    "cocos_consumed_subset": "identity_no_sign_or_2pi_transform_for_GS_and_Bp_subset_only",
    "coil_geometry_free_boundary": "typed_absent_unmapped_coil_geometry",
    "engineering_validation": False,
    "executable_source_scope": (
        "Pinned v18 fixed observed-box runner/policy with V21 protocol status sets bound to the "
        "source-derived status for every natural exit; no solver source/input/control change."
    ),
    "formal_acceptance": False,
    "independent_validation": False,
    "likelihood_ready": False,
    "machine": "explicit_empty_machine",
    "parent_UP4_03_complete": False,
    "physical_validation": False,
    "q_theta_status": "not_consumed_not_verified",
    "reference_inversion_G1_G2_G3": False,
    "runner_status_receipt_semantics": (
        "The versioned runner retains truthful main.__globals__ context/restoration flags and "
        "unconditionally records runner_raised for any BaseException after receipt construction. "
        "The v13 pre-context started-status defect is retained as a negative control only."
    ),
    "terminal_authority": False,
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha256(value: object) -> str:
    body = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def validate_scope_contract(scope: object, v20_scope: dict[str, Any] | None = None) -> None:
    require(isinstance(scope, dict), "v22 top-level scope must restore the structured V20 object")
    require(set(scope) == set(EXPECTED_SCOPE), "v22 scope key set differs from the required 17 keys")
    require(scope == EXPECTED_SCOPE, "v22 scope values differ from the frozen current-fact allow-list")
    for key, expected in EXPECTED_SCOPE.items():
        require(type(scope[key]) is type(expected), f"v22 scope value type mismatch: {key}")
    if v20_scope is not None:
        require(isinstance(v20_scope, dict), "pinned V20 scope must remain structured")
        require(set(scope) == set(v20_scope), "v22 scope key set differs from pinned V20 scope")
        for key in set(scope) - {"executable_source_scope"}:
            require(scope[key] == v20_scope[key], f"v22 scope changed inherited V20 fact: {key}")


def _load_module(path: Path, name: str):
    spec = importlib.util.spec_from_file_location(name, path)
    require(spec is not None and spec.loader is not None, f"cannot load pinned verifier: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _dependency_map(protocol: dict[str, Any]) -> dict[str, str]:
    pins = protocol.get("dependency_file_pins")
    require(isinstance(pins, list), "dependency_file_pins must be a list")
    result = {str(item["path"]): str(item["sha256"]).lower() for item in pins}
    require(len(result) == len(pins), "duplicate dependency pin")
    return result


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    root = Path(protocol["repository_root"]).resolve()
    require(protocol.get("schema") == SCHEMA, "v22 protocol schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "v22 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "v22 cannot authorize execution")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "v22 root heavy slot is not granted")

    contract = protocol.get("protocol_scope_contract_v22", {})
    require(contract.get("schema") == "fusionconceptai:freegs-protocol-scope-restoration-contract-v1",
            "v22 scope contract missing")
    step_list = protocol.get("steps")
    require(isinstance(step_list, list) and len(step_list) == 1, "v22 requires exactly one bounded FreeGS step")
    step = step_list[0]
    expected_step = "direct_actual_freegs_fixed_observed_box_picard_policy_v22_scope_contract"
    expected_task = "native-axisymmetric-v9-fixed-box-picard-v22-scope-contract"
    require(step.get("name") == contract.get("step_name") == expected_step, "v22 step identity mismatch")
    require(contract.get("supervisor_task_name") == expected_task, "v22 supervisor task name mismatch")

    v20_path = root / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v11/actual_run_protocol_v20_candidate_v1.json"
    v21_path = root / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v12/actual_run_protocol_v21_candidate_v1.json"
    require(v20_path.is_file() and sha256(v20_path) == V20_PROTOCOL_SHA256, "V20 frozen protocol ancestry changed")
    require(v21_path.is_file() and sha256(v21_path) == V21_PROTOCOL_SHA256, "V21 frozen protocol ancestry changed")
    v20 = json.loads(v20_path.read_text(encoding="utf-8"))
    v21 = json.loads(v21_path.read_text(encoding="utf-8"))
    validate_scope_contract(protocol.get("scope"), v20.get("scope"))
    require(isinstance(v21.get("scope"), str), "V21 scalar-scope regression ancestry changed")

    prior = contract.get("prior_v21_candidate", {})
    require(prior.get("protocol_path") == v21_path.relative_to(root).as_posix(), "v21 prior path declaration changed")
    require(prior.get("protocol_sha256") == V21_PROTOCOL_SHA256, "v21 prior protocol hash declaration changed")
    require(prior.get("prior_scope_type") == "string" and prior.get("prior_scope_value") == v21["scope"],
            "v21 scalar scope defect declaration changed")
    require(prior.get("status_contract_verdict") == "GO_static_status_mapping_only", "v21 status-map split verdict changed")
    require(prior.get("runtime_candidate_verdict") == "NO_GO_scope_contract", "v21 runtime NO-GO ancestry missing")
    scope_contract = prior.get("scope_review", {})
    require(scope_contract.get("report_path") == "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v21_status_review_r2_scope_correction_20260924/review.md",
            "v21 scope correction report path changed")
    require(scope_contract.get("report_sha256") == V21_SCOPE_REVIEW_SHA256, "v21 scope correction report hash changed")
    require(scope_contract.get("manifest_path") == "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v21_status_review_r2_scope_correction_20260924/evidence_manifest.json",
            "v21 scope review manifest path changed")
    require(scope_contract.get("manifest_sha256") == V21_SCOPE_REVIEW_MANIFEST_SHA256, "v21 scope review manifest hash changed")
    ref_review = prior.get("reference_inverse_status_review", {})
    require(ref_review.get("report_path") == "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v21_status_review_reference_inverse_r1_20260924/review.md",
            "v21 independent status review path changed")
    require(ref_review.get("report_sha256") == V21_REFERENCE_REVIEW_SHA256, "v21 independent status review hash changed")
    require(ref_review.get("manifest_path") == "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v21_status_review_reference_inverse_r1_20260924/evidence_manifest.json",
            "v21 independent status review manifest path changed")
    require(ref_review.get("manifest_sha256") == V21_REFERENCE_REVIEW_MANIFEST_SHA256,
            "v21 independent status review manifest hash changed")
    owner_manifest = root / "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v21_status_contract_static_r1/evidence_manifest.json"
    require(owner_manifest.is_file() and sha256(owner_manifest) == V21_OWNER_EVIDENCE_MANIFEST_SHA256,
            "V21 owner static evidence manifest changed")
    for path_text, expected in [
        (scope_contract["report_path"], V21_SCOPE_REVIEW_SHA256),
        (scope_contract["manifest_path"], V21_SCOPE_REVIEW_MANIFEST_SHA256),
        (ref_review["report_path"], V21_REFERENCE_REVIEW_SHA256),
        (ref_review["manifest_path"], V21_REFERENCE_REVIEW_MANIFEST_SHA256),
    ]:
        p = root / path_text
        require(p.is_file() and sha256(p) == expected, f"V21 reviewer evidence changed: {path_text}")

    v21_contract = v21.get("protocol_status_contract_v21", {})
    v21_verifier_path = root / v21_contract.get("static_verifier", "")
    v21_test_path = root / v21_contract.get("static_test", "")
    require(sha256(v21_verifier_path) == V21_VERIFIER_SHA256 == v21_contract.get("static_verifier_sha256"),
            "V21 verifier ancestry pin changed")
    require(sha256(v21_test_path) == V21_TEST_SHA256 == v21_contract.get("static_test_sha256"),
            "V21 test ancestry pin changed")
    v21_verifier = _load_module(v21_verifier_path, "freegs_v21_scope_ancestor_verifier")
    v21_result = v21_verifier.validate_candidate(v21_path)
    require(v21_result.get("status") == "static_protocol_check_pass_ungranted", "V21 status-map static result changed")
    require(v21_result.get("dependency_pin_count") == 165 and v21_result.get("root_resource_slot_granted") is False,
            "V21 status-map static boundary changed")

    require(contract.get("scope_key_count") == 17, "v22 scope key count declaration changed")
    require(contract.get("scope_key_names") == sorted(EXPECTED_SCOPE), "v22 scope key name inventory changed")
    require(contract.get("restored_scope_sha256") == canonical_sha256(EXPECTED_SCOPE), "v22 scope value hash mismatch")
    require(contract.get("current_scope") == protocol["scope"], "v22 current scope receipt differs from top-level scope")
    require(contract.get("negative_controls") == [
        "reject scalar V21 scope",
        "reject each of the 17 missing scope keys independently",
        "reject each of the 17 scope values when independently changed or inverted",
        "reject wrong type for boolean scope fields",
        "reject changed scope key inventory and unexpected extra keys",
    ], "v22 scope negative-control contract changed")

    step_contract = protocol.get("protocol_status_contract_v21", {})
    require(v21.get("protocol_status_contract_v21") == step_contract, "v21 status contract was modified in v22")
    require(step.get("natural_exit_statuses_by_code") == V21_STATUS_SETS, "v22 status sets differ from frozen V21")
    require(step.get("natural_exit_map") == V21_CATEGORY_SUMMARY, "v22 category summary differs from frozen V21")
    require(step.get("natural_exit_map_scope") == "category_summary_only_not_an_exact_status_map",
            "v22 category-only map declaration changed")
    require(step.get("result_exit_schema_contract") == v21["steps"][0]["result_exit_schema_contract"],
            "v22 success/failure result status contract changed")
    require(step.get("dynamic_binding") == v21["steps"][0]["dynamic_binding"],
            "v22 numerical and observer dynamic binding changed")
    require(protocol.get("resource_contract") == v21.get("resource_contract"), "v22 resource limits changed")
    require(protocol.get("source_inputs") == v21.get("source_inputs"), "v22 source input pins changed")
    source_inputs = protocol.get("source_inputs", {})
    require(source_inputs.get("solver_input_sha256") == "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447",
            "frozen generated solver input SHA changed")
    require(source_inputs.get("snapshot_sha256") == "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac",
            "frozen shot-30421 source snapshot SHA changed")

    dependencies = protocol.get("dependency_file_pins", [])
    v21_dependencies = _dependency_map(v21)
    new_dependencies = _dependency_map(protocol)
    require(protocol.get("dependency_file_pin_count") == len(dependencies) == 165, "v22 dependency pin count mismatch")
    old_verifier = str(root / v21_contract["static_verifier"])
    old_test = str(root / v21_contract["static_test"])
    new_verifier = str(root / contract["static_verifier"])
    new_test = str(root / contract["static_test"])
    require(set(new_dependencies) == (set(v21_dependencies) - {old_verifier, old_test}) | {new_verifier, new_test},
            "v22 dependency pin set is not the exact V21 verifier/test replacement")
    for path_text, digest in v21_dependencies.items():
        if path_text not in {old_verifier, old_test}:
            require(new_dependencies.get(path_text) == digest, f"inherited v21 dependency pin changed: {path_text}")
    for path_text, expected in new_dependencies.items():
        p = Path(path_text)
        require(p.is_file() and sha256(p).lower() == expected, f"v22 dependency pin mismatch: {path_text}")

    frozen_files = protocol.get("frozen_files", {})
    v21_frozen = v21.get("frozen_files", {})
    require(set(frozen_files) == (set(v21_frozen) - {v21_contract["static_verifier"], v21_contract["static_test"]}) |
            {contract["static_verifier"], contract["static_test"]}, "v22 frozen-file set differs beyond its verifier/test replacement")
    for path_text, digest in v21_frozen.items():
        if path_text not in {v21_contract["static_verifier"], v21_contract["static_test"]}:
            require(frozen_files.get(path_text) == digest, f"inherited frozen file changed: {path_text}")
    require(frozen_files.get(contract["static_verifier"]) == sha256(root / contract["static_verifier"]),
            "v22 verifier missing from frozen file pins")
    require(frozen_files.get(contract["static_test"]) == sha256(root / contract["static_test"]),
            "v22 test missing from frozen file pins")

    argv = step.get("launcher_argv_template")
    v21_step = v21["steps"][0]
    prior_argv = v21_step.get("launcher_argv_template")
    require(isinstance(argv, list) and isinstance(prior_argv, list) and "--" in argv,
            "v22 launcher argv is malformed")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)),
            "v22 Windows command length receipt mismatch")
    require(step["command_length_chars"] < 32767, "v22 Windows command line limit exceeded")
    expected_argv = list(prior_argv)
    new_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"]).resolve()
    old_leaf = Path(v21["runtime_endpoint_join"]["output_leaf"]).resolve()
    require(not new_leaf.exists(), "v22 output leaf must be absent at candidate freeze")
    require(old_leaf != new_leaf, "v22 must have its own fresh output leaf")
    for option, value in [
        ("--name", expected_task),
        ("--stdout", str(new_leaf / "stdout.raw")),
        ("--stderr", str(new_leaf / "stderr.raw")),
        ("--receipt", str(new_leaf / "execution.json")),
        ("--require-absent-path", str(new_leaf)),
    ]:
        expected_argv[expected_argv.index(option) + 1] = value
    separator = expected_argv.index("--")
    child_options = expected_argv[separator + 1:]
    require("--output" in child_options, "V21 child argv has no output option")
    child_options[child_options.index("--output") + 1] = str(new_leaf / "solver_output.json")
    expected_argv[separator + 1:] = child_options
    for index, value in enumerate(expected_argv[:separator]):
        if value.casefold().startswith(old_test.casefold() + "="):
            expected_argv[index] = new_test + "=" + new_dependencies[new_test]
        elif value.casefold().startswith(old_verifier.casefold() + "="):
            expected_argv[index] = new_verifier + "=" + new_dependencies[new_verifier]
    require(argv == expected_argv, "v22 launcher argv changed beyond task/output and verifier/test pins")
    launcher_pins = v21_verifier.parse_supervisor_pins(argv, separator)
    require(launcher_pins == new_dependencies, "v22 supervisor argv pins differ from protocol pins")

    require(step.get("result_path") == str(new_leaf / "solver_output.json"), "v22 result path mismatch")
    require(step.get("required_absent_paths") == [str(new_leaf)], "v22 fresh leaf absent guard mismatch")
    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    endpoint = protocol.get("runtime_endpoint_join", {})
    require(Path(sidecars.get("solver_output", "")) == Path(step["result_path"]), "v22 solver output sidecar mismatch")
    require(Path(endpoint.get("solver_output", "")) == Path(step["result_path"]), "v22 runtime endpoint mismatch")
    for key in ("adapter_receipt", "execution", "stderr", "stdout"):
        path = Path(sidecars[key])
        require(path.parent == new_leaf and not path.exists(), f"v22 {key} sidecar is not a fresh same-leaf path")
    require(Path(endpoint["adapter_receipt"]) == Path(sidecars["adapter_receipt"]),
            "v22 runtime endpoint adapter receipt mismatch")
    require(sidecars.get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"),
            "v22 archive evidence rule changed")
    require(endpoint.get("output_leaf_absent_at_candidate_freeze") is True, "v22 output absence receipt missing")

    return {
        "status": "static_protocol_scope_contract_pass_ungranted",
        "protocol_sha256": sha256(protocol_path),
        "scope_key_count": len(protocol["scope"]),
        "restored_scope_sha256": canonical_sha256(protocol["scope"]),
        "dependency_pin_count": len(dependencies),
        "all_supervisor_pins_rehashed": True,
        "v21_status_contract_preserved": True,
        "v21_scope_no_go_bound": True,
        "same_frozen_solver_input_sha256": source_inputs["solver_input_sha256"],
        "same_frozen_source_snapshot_sha256": source_inputs["snapshot_sha256"],
        "same_resource_contract_as_v21": True,
        "root_resource_slot_granted": False,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
        "new_actual_output_leaf_absent": True,
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
        print(f"FreeGS v22 scope verifier failed: {type(exc).__name__}: {exc}")
        raise SystemExit(1)
