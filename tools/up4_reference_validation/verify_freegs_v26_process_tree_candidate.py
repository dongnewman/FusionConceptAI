"""Static-only verifier for the isolated FreeGS v26 receipt-contract candidate."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any

SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v26-process-tree-receipt-contract"
V25_PROTOCOL_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v16/actual_run_protocol_v25_process_tree_candidate_v1.json"
V25_PROTOCOL_SHA256 = "ce2a06249c79f9a134adf41bc0731ead1da7189b4fb6fd14ea2d6850e604d8ae"
V25_SOURCE_PATH = "tools/up4_reference_validation/freegs_process_supervisor_v25.py"
V25_SOURCE_SHA256 = "7092ac49e8a6af758b97433b002dbf605ff4cbf12669aa5c5de42ec07c90c53b"
V25_MANIFEST_PATH = "tools/up4_reference_validation/freegs_v25_pin_manifest.json"
V25_MANIFEST_SHA256 = "a71da61f6946d40ca1e52e3e20e82953fa67afdda54f793da4b827f6d0fc7a04"
V25_ACTUAL_LEAF = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/root_freegs_v25_grant_20260924/actual_run_r25/freegs_solve"
V25_EXECUTION_PATH = V25_ACTUAL_LEAF + "/execution.json"
V25_EXECUTION_SHA256 = "c59260de901ecf165b305a2fdfedcb28b7e517b518503cb4ae4fd81490eedfb4"
V25_ADAPTER_RECEIPT_PATH = V25_ACTUAL_LEAF + "/freegs_adapter_receipt_v18.json"
V25_ADAPTER_RECEIPT_SHA256 = "7cee871eea12f7526071a91b769d4fc4b9b1eae84c46ee1895eb6aaa229c21af"
V25_SOLVER_OUTPUT_PATH = V25_ACTUAL_LEAF + "/solver_output.json"
V25_SOLVER_OUTPUT_SHA256 = "e1c23b86456927da63f9db5fa0d92deb4964d4b0fa784f64b87b70ffa0c804b6"
V25_STDOUT_PATH = V25_ACTUAL_LEAF + "/stdout.raw"
V25_STDOUT_SHA256 = "5410a2ca4d1907be0c9b13ab2c1f1a03ff23b8086e22a87d6369268133cf40c2"
V25_STDERR_PATH = V25_ACTUAL_LEAF + "/stderr.raw"
V25_STDERR_SHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
V25_EMITTED_VERSION = "freegs-process-supervisor-v24"
V25_EMITTED_TREE_CONTRACT = "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound"
V26_VERSION = "freegs-process-supervisor-v26"
V26_TREE_CONTRACT = "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound_strictly_typed"
PIN_MANIFEST_SCHEMA = "fusionconceptai:process-tree-required-files-manifest-v1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"expected JSON object: {path}")
    return value


def dependency_map(protocol: dict[str, Any]) -> dict[str, dict[str, Any]]:
    pins = protocol.get("dependency_file_pins")
    require(isinstance(pins, list), "dependency_file_pins must be a list")
    result = {str(item["path"]): item for item in pins}
    require(len(result) == len(pins), "duplicate dependency pin path")
    return result


def required_file(receipt: dict[str, Any], path: Path) -> dict[str, Any]:
    resolved = str(path.resolve())
    matches = [item for item in receipt.get("required_files", []) if item.get("path") == resolved]
    require(len(matches) == 1, f"V25 actual receipt must contain exactly one required-file entry for {resolved}")
    return matches[0]


def validate_v25_actual_receipt(root: Path, protocol: dict[str, Any]) -> dict[str, Any]:
    v25_path = root / V25_PROTOCOL_PATH
    require(v25_path.is_file() and sha256(v25_path) == V25_PROTOCOL_SHA256, "frozen V25 protocol changed")
    v25 = load_json(v25_path)
    require(v25.get("schema") == "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v25-process-tree-supervisor",
            "V25 protocol schema mismatch")
    require(v25.get("runtime_execution_authorized") is False, "V25 protocol must remain historical and ungranted")
    v25_contract = v25.get("process_tree_supervisor_v25", {})
    require(v25_contract.get("source_path") == V25_SOURCE_PATH and v25_contract.get("source_sha256") == V25_SOURCE_SHA256,
            "V25 source binding mismatch")
    require(v25_contract.get("pin_manifest_path") == V25_MANIFEST_PATH and v25_contract.get("pin_manifest_sha256") == V25_MANIFEST_SHA256,
            "V25 manifest binding mismatch")
    source_path = root / V25_SOURCE_PATH
    manifest_path = root / V25_MANIFEST_PATH
    require(source_path.is_file() and sha256(source_path) == V25_SOURCE_SHA256, "V25 source bytes changed")
    require(manifest_path.is_file() and sha256(manifest_path) == V25_MANIFEST_SHA256, "V25 pin manifest bytes changed")

    old_dependencies = dependency_map(v25)
    require(v25.get("dependency_file_pin_count") == len(old_dependencies) == 190, "V25 dependency pin inventory mismatch")
    old_manifest = load_json(manifest_path)
    old_manifest_map = {str(item["path"]): str(item["sha256"]).lower() for item in old_manifest.get("pins", [])}
    require(old_manifest.get("schema") == PIN_MANIFEST_SCHEMA and old_manifest.get("pin_count") == 189 and len(old_manifest_map) == 189,
            "V25 runtime pin manifest inventory mismatch")
    require(old_manifest_map == {path: str(item["sha256"]).lower() for path, item in old_dependencies.items() if path != str((root / V25_MANIFEST_PATH).resolve())},
            "V25 runtime pin manifest does not match its frozen protocol")
    for path_text, pin in old_dependencies.items():
        path = Path(path_text)
        require(path.is_file() and path.stat().st_size == pin["bytes"] and sha256(path) == str(pin["sha256"]).lower(),
                f"V25 inherited dependency drift: {path_text}")

    output = root / V25_ACTUAL_LEAF
    expected_sidecars = {
        V25_EXECUTION_PATH: V25_EXECUTION_SHA256,
        V25_ADAPTER_RECEIPT_PATH: V25_ADAPTER_RECEIPT_SHA256,
        V25_SOLVER_OUTPUT_PATH: V25_SOLVER_OUTPUT_SHA256,
        V25_STDOUT_PATH: V25_STDOUT_SHA256,
        V25_STDERR_PATH: V25_STDERR_SHA256,
    }
    for rel, digest in expected_sidecars.items():
        path = root / rel
        require(path.is_file() and path.parent == output and sha256(path) == digest,
                f"V25 original run sidecar changed: {rel}")
    execution = load_json(root / V25_EXECUTION_PATH)
    require(execution.get("schema") == "fusionconceptai:recorded-process-execution-v2", "V25 execution receipt schema mismatch")
    require(execution.get("supervisor_version") == V25_EMITTED_VERSION, "V25 historical emitted version mismatch")
    require(execution.get("tree_observation_contract") == V25_EMITTED_TREE_CONTRACT,
            "V25 historical emitted tree contract mismatch")
    source_required = required_file(execution, source_path)
    manifest_required = required_file(execution, manifest_path)
    require(source_required.get("expected_sha256") == V25_SOURCE_SHA256 == source_required.get("actual_sha256")
            and source_required.get("status") == "match", "V25 actual receipt did not match the V25 source pin")
    require(manifest_required.get("expected_sha256") == V25_MANIFEST_SHA256 == manifest_required.get("actual_sha256")
            and manifest_required.get("status") == "match", "V25 actual receipt did not match the V25 manifest pin")
    require(execution.get("child_exit_code") == 0 and execution.get("harness_exit_code") == 0
            and execution.get("tree_exit_proven") is True and execution.get("all_samples_complete") is True,
            "V25 actual process-tree receipt natural-exit fields changed")
    require(execution.get("pins_stable_during_run") is True, "V25 actual receipt pin-stability field changed")

    ancestry = protocol.get("prior_v25_receipt_contract_mismatch", {})
    expected = {
        "protocol_path": V25_PROTOCOL_PATH,
        "protocol_sha256": V25_PROTOCOL_SHA256,
        "source_path": V25_SOURCE_PATH,
        "source_sha256": V25_SOURCE_SHA256,
        "pin_manifest_path": V25_MANIFEST_PATH,
        "pin_manifest_sha256": V25_MANIFEST_SHA256,
        "actual_leaf": V25_ACTUAL_LEAF,
        "actual_execution_path": V25_EXECUTION_PATH,
        "actual_execution_sha256": V25_EXECUTION_SHA256,
        "actual_adapter_receipt_path": V25_ADAPTER_RECEIPT_PATH,
        "actual_adapter_receipt_sha256": V25_ADAPTER_RECEIPT_SHA256,
        "actual_solver_output_path": V25_SOLVER_OUTPUT_PATH,
        "actual_solver_output_sha256": V25_SOLVER_OUTPUT_SHA256,
        "actual_stdout_path": V25_STDOUT_PATH,
        "actual_stdout_sha256": V25_STDOUT_SHA256,
        "actual_stderr_path": V25_STDERR_PATH,
        "actual_stderr_sha256": V25_STDERR_SHA256,
        "observed_supervisor_version": V25_EMITTED_VERSION,
        "observed_tree_observation_contract": V25_EMITTED_TREE_CONTRACT,
        "protocol_expected_supervisor_version": "freegs-process-supervisor-v25",
        "protocol_expected_tree_observation_contract": V26_TREE_CONTRACT,
        "v25_source_and_manifest_pins_matched": True,
        "actual_output_preserved_unchanged": True,
        "runtime_or_physics_credit": False,
    }
    require(ancestry == expected, "V25 actual-receipt mismatch ancestry binding differs")
    return {"v25": v25, "execution": execution, "output": output, "dependencies": old_dependencies}


def parse_launcher_pins(argv: list[str]) -> dict[str, str]:
    separator = argv.index("--")
    result: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] == "--require-file-sha256":
            declaration = argv[index + 1]
            require("=" in declaration, "malformed direct required-file pin")
            path, digest = declaration.rsplit("=", 1)
            require(len(digest) == 64 and path not in result, "malformed or duplicate direct required-file pin")
            result[path] = digest.lower()
            index += 2
        else:
            index += 1
    return result


def expected_v26_argv(v25_step: dict[str, Any], supervisor: str, manifest: str, manifest_sha: str,
                      task_name: str, output_leaf: Path) -> list[str]:
    argv = copy.deepcopy(v25_step["launcher_argv_template"])
    argv[2] = supervisor
    for option, value in [
        ("--name", task_name),
        ("--stdout", str(output_leaf / "stdout.raw")),
        ("--stderr", str(output_leaf / "stderr.raw")),
        ("--receipt", str(output_leaf / "execution.json")),
        ("--require-absent-path", str(output_leaf)),
    ]:
        argv[argv.index(option) + 1] = value
    separator = argv.index("--")
    child_argv = argv[separator + 1:]
    require("--output" in child_argv, "pinned V25 child command lacks output option")
    child_argv[child_argv.index("--output") + 1] = str(output_leaf / "solver_output.json")
    prefix: list[str] = []
    index = 0
    while index < separator:
        token = argv[index]
        if token in {"--require-file-sha256", "--require-file-sha256-manifest"}:
            index += 2
            continue
        prefix.append(token)
        index += 1
    insert_at = prefix.index("--require-absent-path") + 2
    prefix[insert_at:insert_at] = ["--require-file-sha256", manifest + "=" + manifest_sha,
                                   "--require-file-sha256-manifest", manifest]
    return prefix + ["--"] + child_argv


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol_path = protocol_path.resolve()
    protocol = load_json(protocol_path)
    root = Path(protocol["repository_root"]).resolve()
    require(protocol.get("schema") == SCHEMA, "V26 schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "V26 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "V26 cannot authorize runtime execution")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "V26 root resource slot must remain ungranted")
    require(slot.get("v25_receipt_contract_mismatch_preserved") is True, "V25 actual receipt mismatch must remain explicit")
    require(protocol.get("runtime_execution_authorized") is False, "V26 is static only")

    previous = validate_v25_actual_receipt(root, protocol)
    v25 = previous["v25"]
    mutable_v25_fields = {
        "schema", "recorded_utc", "dependency_file_pins", "dependency_file_pin_count",
        "runtime_endpoint_join", "mandatory_evidence_sidecars", "root_resource_slot",
        "review_ancestry", "steps", "frozen_files",
    }
    for key, value in v25.items():
        if key not in mutable_v25_fields:
            require(protocol.get(key) == value, f"V26 changed inherited V25 contract field: {key}")
    expected_slot = copy.deepcopy(v25["root_resource_slot"])
    expected_slot.update({
        "granted": False,
        "precondition": protocol.get("root_resource_slot", {}).get("precondition"),
        "v25_receipt_contract_mismatch_preserved": True,
    })
    require(slot == expected_slot, "V26 changed prior slot/no-go declarations")
    expected_review_ancestry = copy.deepcopy(v25["review_ancestry"])
    expected_review_ancestry["credit_limit"] = protocol.get("review_ancestry", {}).get("credit_limit")
    expected_review_ancestry["v26_required_reviews"] = protocol.get("review_ancestry", {}).get("v26_required_reviews")
    require(protocol.get("review_ancestry") == expected_review_ancestry,
            "V26 review ancestry changed or runtime/physics credit was implied")
    contract = protocol.get("process_tree_supervisor_v26", {})
    expected_contract = copy.deepcopy(v25["process_tree_supervisor_v25"])
    expected_contract.update({
        "version": V26_VERSION,
        "tree_observation_contract": V26_TREE_CONTRACT,
        "source_path": "tools/up4_reference_validation/freegs_process_supervisor_v26.py",
        "static_verifier_path": "tools/up4_reference_validation/verify_freegs_v26_process_tree_candidate.py",
        "static_test_path": "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v26.py",
        "pin_manifest_path": "tools/up4_reference_validation/freegs_v26_pin_manifest.json",
        "negative_controls": list(v25["process_tree_supervisor_v25"]["negative_controls"]) + [
            "V26 execution receipt supervisor_version must equal the V26 protocol version exactly; V24/V25 labels are rejected",
            "V26 execution receipt tree_observation_contract must equal the V26 protocol contract including _strictly_typed",
        ],
    })
    v26_paths = {
        "source_path": "tools/up4_reference_validation/freegs_process_supervisor_v26.py",
        "static_verifier_path": "tools/up4_reference_validation/verify_freegs_v26_process_tree_candidate.py",
        "static_test_path": "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v26.py",
        "pin_manifest_path": "tools/up4_reference_validation/freegs_v26_pin_manifest.json",
    }
    for key, value in v26_paths.items():
        expected_contract[key] = value
    for path_key, hash_key in [
        ("source_path", "source_sha256"),
        ("static_verifier_path", "static_verifier_sha256"),
        ("static_test_path", "static_test_sha256"),
        ("pin_manifest_path", "pin_manifest_sha256"),
    ]:
        expected_contract[hash_key] = sha256(root / expected_contract[path_key])
    new_dependencies = dependency_map(protocol)
    require(contract == expected_contract, "V26 supervisor metadata or inherited process-tree contract mismatch")
    require(contract.get("version") == V26_VERSION and contract.get("tree_observation_contract") == V26_TREE_CONTRACT,
            "V26 protocol receipt metadata values are not exact")

    v26_paths_abs = {key: str((root / value).resolve()) for key, value in v26_paths.items()}
    for key, path_text in v26_paths_abs.items():
        require(Path(path_text).is_file(), f"V26 owned file missing: {path_text}")
    source_path = Path(v26_paths_abs["source_path"])
    verifier_path = Path(v26_paths_abs["static_verifier_path"])
    test_path = Path(v26_paths_abs["static_test_path"])
    manifest_path = Path(v26_paths_abs["pin_manifest_path"])
    source_text = source_path.read_text(encoding="utf-8")
    require(source_text.count('"supervisor_version": "' + V26_VERSION + '"') == 1,
            "V26 source must emit exact V26 supervisor_version once")
    require(source_text.count('"tree_observation_contract": "' + V26_TREE_CONTRACT + '"') == 1,
            "V26 source must emit the exact strictly-typed tree contract once")
    require('"supervisor_version": "freegs-process-supervisor-v24"' not in source_text,
            "V26 source still emits stale V24 supervisor metadata")
    require('"tree_observation_contract": "' + V25_EMITTED_TREE_CONTRACT + '"' not in source_text,
            "V26 source still emits the untyped V25 tree-contract label")

    v25_dependencies = previous["dependencies"]
    expected_new_paths = {str(path.resolve()) for path in (source_path, verifier_path, test_path, manifest_path)}
    require(protocol.get("dependency_file_pin_count") == len(new_dependencies) == 194,
            "V26 dependency pin count must be 190 inherited V25 pins plus four owned files")
    expected_paths = set(v25_dependencies) | expected_new_paths
    require(set(new_dependencies) == expected_paths, "V26 must preserve all 190 V25 pins and add its four owned files")
    for path_text, pin in v25_dependencies.items():
        require(new_dependencies[path_text] == pin, f"inherited V25 pin changed: {path_text}")
    for path_text, pin in new_dependencies.items():
        path = Path(path_text)
        require(path.is_file() and path.stat().st_size == pin["bytes"] and sha256(path) == str(pin["sha256"]).lower(),
                f"V26 dependency pin mismatch: {path_text}")
    for path, role in [(source_path, ["runtime_dependency"]),
                       (verifier_path, ["v26_process_tree_static_verifier"]),
                       (test_path, ["v26_process_tree_test"]),
                       (manifest_path, ["v26_process_tree_pin_manifest"])]:
        pin = new_dependencies[str(path.resolve())]
        require(pin["roles"] == role, f"V26 pin role mismatch: {path}")
    require(contract.get("source_sha256") == sha256(source_path) == new_dependencies[str(source_path.resolve())]["sha256"],
            "V26 supervisor source hash mismatch")
    require(contract.get("static_verifier_sha256") == sha256(verifier_path) == new_dependencies[str(verifier_path.resolve())]["sha256"],
            "V26 verifier hash mismatch")
    require(contract.get("static_test_sha256") == sha256(test_path) == new_dependencies[str(test_path.resolve())]["sha256"],
            "V26 fake-test hash mismatch")
    require(contract.get("pin_manifest_sha256") == sha256(manifest_path) == new_dependencies[str(manifest_path.resolve())]["sha256"],
            "V26 pin-manifest hash mismatch")

    manifest_payload = load_json(manifest_path)
    manifest_map = {str(item["path"]): str(item["sha256"]).lower() for item in manifest_payload.get("pins", [])}
    self_manifest = str(manifest_path.resolve())
    expected_manifest_map = {path: str(item["sha256"]).lower() for path, item in new_dependencies.items() if path != self_manifest}
    require(manifest_payload.get("schema") == PIN_MANIFEST_SCHEMA and manifest_payload.get("pin_count") == 193
            and len(manifest_map) == 193, "V26 runtime pin manifest must contain 193 non-self dependency pins")
    require(manifest_map == expected_manifest_map, "V26 runtime pin manifest does not bind all non-self dependency pins")

    v25_frozen = v25.get("frozen_files", {})
    frozen = protocol.get("frozen_files", {})
    new_frozen = {str((root / rel).resolve()) for rel in v26_paths.values()}
    old_frozen_abs = {str((root / rel).resolve()): digest for rel, digest in v25_frozen.items()}
    expected_frozen = dict(old_frozen_abs)
    expected_frozen.update({str((root / rel).resolve()): sha256(root / rel) for rel in v26_paths.values()})
    normalized_frozen = {str((root / rel).resolve()): digest for rel, digest in frozen.items()}
    require(normalized_frozen == expected_frozen, "V26 frozen-file inventory must preserve V25 and add exactly four owned files")
    require(len(frozen) == len(v25_frozen) + 4, "V26 frozen file count mismatch")

    require(protocol.get("process_tree_supervisor_v25") == v25.get("process_tree_supervisor_v25"),
            "historical V25 contract must remain unchanged")
    require(protocol.get("scope") == v25.get("scope") and isinstance(protocol.get("scope"), dict)
            and len(protocol["scope"]) == 17, "V26 must preserve the structured 17-key scope")
    require(protocol.get("source_inputs") == v25.get("source_inputs"), "V26 solver input/source bytes changed")
    for key in ("resource_contract", "dirichlet_elimination", "residual_discriminator", "protocol_scope_contract_v22"):
        require(protocol.get(key) == v25.get(key), f"V26 numerical/scope contract changed: {key}")

    step = protocol.get("steps", [None])[0]
    require(isinstance(step, dict) and len(protocol.get("steps", [])) == 1, "V26 requires one bounded step")
    step_v25 = v25["steps"][0]
    require(step.get("dynamic_binding") == step_v25.get("dynamic_binding"), "V26 numerical policy/dynamic binding changed")
    for key in ("natural_exit_statuses_by_code", "natural_exit_map", "natural_exit_map_scope", "result_exit_schema_contract"):
        require(step.get(key) == step_v25.get(key), f"V26 exit semantics changed: {key}")
    expected_name = "direct_actual_freegs_fixed_observed_box_picard_policy_v26_process_tree_receipt_contract"
    expected_task = "native-axisymmetric-v10-fixed-box-picard-v26-receipt-contract-aligned-process-tree"
    require(step.get("name") == expected_name and step.get("supervisor_task_name") == expected_task,
            "V26 step/task identity mismatch")
    require(step.get("order") == 1, "V26 step order mismatch")
    leaf = Path(protocol.get("runtime_endpoint_join", {}).get("output_leaf", "")).resolve()
    old_leaf = Path(v25["runtime_endpoint_join"]["output_leaf"]).resolve()
    require(leaf != old_leaf and not leaf.exists(), "V26 output leaf must be new and absent")
    require(protocol.get("runtime_endpoint_join", {}).get("output_leaf_absent_at_candidate_freeze") is True,
            "V26 output leaf must be declared absent")
    require(protocol.get("runtime_endpoint_join", {}).get("derivation", "").startswith("V26 changes only execution-receipt metadata labels"),
            "V26 endpoint derivation must state the bounded metadata-only change")

    argv = step.get("launcher_argv_template")
    expected_argv = expected_v26_argv(step_v25, str(source_path), str(manifest_path),
                                      new_dependencies[str(manifest_path.resolve())]["sha256"], expected_task, leaf)
    require(argv == expected_argv, "V26 launcher argv differs beyond supervisor, manifest, task and output-leaf bindings")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)) < 32767,
            "V26 Windows launcher command length invalid")
    require(parse_launcher_pins(argv) == {str(manifest_path): new_dependencies[str(manifest_path.resolve())]["sha256"].lower()},
            "V26 launcher must directly pin exactly the V26 pin manifest")
    require(step.get("result_path") == str(leaf / "solver_output.json"), "V26 result path mismatch")
    require(step.get("required_absent_paths") == [str(leaf)], "V26 launcher output absence guard mismatch")

    endpoint = protocol.get("runtime_endpoint_join", {})
    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    require(endpoint.get("solver_output") == step.get("result_path"), "V26 endpoint solver output mismatch")
    require(sidecars.get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"),
            "V26 evidence-only archive rule changed")
    for key, filename in {
        "adapter_receipt": "freegs_adapter_receipt_v18.json", "execution": "execution.json",
        "solver_output": "solver_output.json", "stdout": "stdout.raw", "stderr": "stderr.raw",
    }.items():
        path = Path(sidecars[key]).resolve()
        require(path.parent == leaf and path.name == filename and not path.exists(),
                f"V26 {key} sidecar is not fresh under its one output leaf")

    require(slot.get("granted") is False and protocol.get("runtime_execution_authorized") is False,
            "V26 static candidate cannot authorize a FreeGS/Julia run")
    require(protocol["scope"].get("physical_validation") is False
            and protocol["scope"].get("reference_inversion_G1_G2_G3") is False
            and protocol["scope"].get("formal_acceptance") is False,
            "V26 structured scope physical/reference-inverse credit ceiling changed")
    return {
        "status": "static_receipt_contract_alignment_candidate_pass_ungranted",
        "protocol_sha256": sha256(protocol_path),
        "dependency_pin_count": len(new_dependencies),
        "v25_dependency_pins_preserved": len(v25_dependencies),
        "v24_dependency_pins_preserved": 179,
        "v23_dependency_pins_preserved": 169,
        "v25_actual_receipt_contract_mismatch_bound": True,
        "v25_actual_output_bytes_rehashed_unchanged": True,
        "v25_source_and_manifest_were_pinned_match_in_receipt": True,
        "v26_receipt_metadata_source_protocol_exact_match": True,
        "v26_strictly_typed_process_tree_contract": True,
        "v25_strict_identity_negative_controls_preserved": True,
        "strict_raw_identity_type_checks_bound": True,
        "popen_process_identity_binding_bound": True,
        "natural_exit_exact_root_identity_check_bound": True,
        "all_dependency_pins_rehashed": True,
        "scope_key_count": len(protocol["scope"]),
        "solver_inputs_and_numerical_controls_unchanged": True,
        "resource_limits": {"wall_seconds": 180, "rss_bytes": 2147483648, "threads": 1},
        "root_resource_slot_granted": False,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
        "new_output_leaf_absent": True,
        "physics_or_reference_inverse_credit": False,
    }


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    args = parser.parse_args()
    print(json.dumps(validate_candidate(args.protocol), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"FreeGS v26 receipt-contract verifier failed: {type(exc).__name__}: {exc}")
        raise SystemExit(1)
