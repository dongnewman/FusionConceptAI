"""Static-only verifier for the isolated FreeGS v23 supervisor candidate."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
from typing import Any


SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v23-process-tree-supervisor"
V22_PROTOCOL_SHA256 = "45b99a9b6c14005275de07895b1c248164a2385dc33d060c2cf03d0ef0b9d3b8"
V22_DECISION_SHA256 = "070f86e2a11956b986c0b6a6f1dc01d9a6534aa0ecfcc2651fb5b10281bbfb6d"
V22_REVIEW_SHA256 = "d0d245b4ce b39f656e32de7ff1ad1d1574788208ad5bf6eea91b3db4781753ae".replace(" ", "")
V22_REVIEW_MANIFEST_SHA256 = "29d1ac33b532de33016c99f5d07626df2aa5846a89e2579c4cde710b886982ea"
V22_VERIFIER_SHA256 = "788cc415f8435ae30f01cabb647c1367b13953eb9e84cf7b6160c0b1e546c5dd"
V22_TEST_SHA256 = "75c8a7365245a89dd1991187dfb61a95a68be23ebc3fc989a8c760ec10ee4ff3"
V22_SCOPE_SHA256 = "4943e77a25c96e2cab948ce6379f13cab07a289661eecf8a5b9004f9595334c1"
EXPECTED_EXIT_CODES = {
    "preflight": 96,
    "wall_limit": 97,
    "rss_limit": 98,
    "incomplete_or_unproven_tree": 99,
}
PIN_MANIFEST_SCHEMA = "fusionconceptai:process-tree-required-files-manifest-v1"
EXPECTED_SUPERVISOR_CONTRACT = {
    "version": "freegs-process-supervisor-v23",
    "receipt_schema": "fusionconceptai:recorded-process-execution-v2",
    "tree_observation_contract": "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v1",
    "sample_race_policy": "NoSuchProcess or AccessDenied during recursive enumeration, process identity, or RSS read invalidates the entire sample; never compare a partial sum to the cap.",
    "cleanup_policy": "Record terminate/kill/wait attempts; return a resource exit only when enumeration is complete and every tracked process is verified gone. Any denied, failed, or unknown operation returns supervisor exit 99.",
    "natural_exit_policy": "Preserve the child exit only after all samples were complete and every identity discovered by those samples is verified gone after root exit; live or unreadable descendants yield supervisor exit 99.",
    "proof_scope": "Sampled process tree and identities discovered by complete recursive snapshots; not OS job-object containment and not a guarantee about a process existing only between samples.",
    "resource_exit_codes": EXPECTED_EXIT_CODES,
    "negative_controls": [
        "complete samples contain the exact root pid/create-time identity once",
        "AccessDenied during recursive process enumeration",
        "NoSuchProcess during recursive process enumeration",
        "AccessDenied during per-process RSS read",
        "NoSuchProcess between enumeration and RSS read",
        "AccessDenied during terminate or kill",
        "wait returns a still-live process after terminate and after kill",
        "AccessDenied or unknown final process state",
        "leader exits while a tracked descendant remains alive",
        "natural exit with every observed descendant verified gone",
    ],
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def canonical_sha256(value: object) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


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


def parse_launcher_pins(argv: list[str]) -> dict[str, str]:
    separator = argv.index("--")
    result: dict[str, str] = {}
    i = 0
    while i < separator:
        if argv[i] == "--require-file-sha256":
            declaration = argv[i + 1]
            require("=" in declaration, "malformed required-file pin")
            path, digest = declaration.rsplit("=", 1)
            require(len(digest) == 64, "required-file pin hash length mismatch")
            require(path not in result, "duplicate launcher required-file pin")
            result[path] = digest.lower()
            i += 2
        else:
            i += 1
    return result


def import_module(path: Path, module_name: str):
    spec = importlib.util.spec_from_file_location(module_name, path)
    require(spec is not None and spec.loader is not None, f"cannot import verifier {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def validate_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol_path = protocol_path.resolve()
    protocol = load_json(protocol_path)
    root = Path(protocol["repository_root"]).resolve()
    require(protocol.get("schema") == SCHEMA, "V23 schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "V23 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "V23 cannot authorize execution")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "root resource slot must remain ungranted")

    v22_relative = Path("docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v13/actual_run_protocol_v22_scope_contract_candidate_v1.json")
    v22_path = root / v22_relative
    require(v22_path.is_file() and sha256(v22_path) == V22_PROTOCOL_SHA256, "frozen V22 protocol ancestry changed")
    v22 = load_json(v22_path)
    v22_verifier_path = root / "tools/up4_reference_validation/verify_freegs_v22_scope_contract_candidate.py"
    require(v22_verifier_path.is_file() and sha256(v22_verifier_path) == V22_VERIFIER_SHA256, "frozen V22 verifier changed")
    v22_verifier = import_module(v22_verifier_path, "freegs_v22_ancestry_verifier")
    v22_result = v22_verifier.validate_candidate(v22_path)
    require(v22_result.get("dependency_pin_count") == 165 and v22_result.get("root_resource_slot_granted") is False,
            "V22 frozen static status/scope audit no longer passes")

    prior = protocol.get("prior_v22_runtime_no_go", {})
    decision_rel = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/root_freegs_v22_runtime_no_go_20260924/decision.md"
    review_root = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v22_resource_supervisor_no_go_reference_inverse_r1_20260924"
    review_rel = review_root + "/review.md"
    review_manifest_rel = review_root + "/evidence_manifest.json"
    require(prior.get("protocol_sha256") == V22_PROTOCOL_SHA256, "V22 protocol NO-GO ancestry hash mismatch")
    require(prior.get("decision_path") == decision_rel and prior.get("decision_sha256") == V22_DECISION_SHA256,
            "root V22 runtime NO-GO decision binding mismatch")
    require(prior.get("independent_review_path") == review_rel and prior.get("independent_review_sha256") == V22_REVIEW_SHA256,
            "independent V22 supervisor review binding mismatch")
    require(prior.get("independent_manifest_path") == review_manifest_rel and prior.get("independent_manifest_sha256") == V22_REVIEW_MANIFEST_SHA256,
            "independent V22 supervisor review manifest binding mismatch")
    for rel, expected in [(decision_rel, V22_DECISION_SHA256), (review_rel, V22_REVIEW_SHA256),
                          (review_manifest_rel, V22_REVIEW_MANIFEST_SHA256)]:
        path = root / rel
        require(path.is_file() and sha256(path) == expected, f"V22 historical NO-GO evidence changed: {rel}")

    contract = protocol.get("process_tree_supervisor_v23", {})
    contract_pin_fields = {
        "source_path", "source_sha256", "static_verifier_path", "static_verifier_sha256",
        "static_test_path", "static_test_sha256", "pin_manifest_path", "pin_manifest_sha256",
    }
    require(set(contract) == set(EXPECTED_SUPERVISOR_CONTRACT) | contract_pin_fields,
            "V23 process-tree supervisor contract field inventory mismatch")
    for key, expected in EXPECTED_SUPERVISOR_CONTRACT.items():
        require(contract.get(key) == expected, f"V23 process-tree supervisor contract mismatch: {key}")
    scope = protocol.get("scope")
    require(scope == v22.get("scope") and isinstance(scope, dict) and len(scope) == 17,
            "V23 must preserve the exact V22 17-key scope")
    v22_scope_contract = protocol.get("protocol_scope_contract_v22", {})
    require(v22_scope_contract.get("restored_scope_sha256") == V22_SCOPE_SHA256, "17-key scope hash changed")
    require(v22_scope_contract.get("current_scope") == scope, "scope receipt differs from top-level scope")
    require(v22_scope_contract.get("scope_key_count") == 17 and v22_scope_contract.get("scope_key_names") == sorted(scope),
            "scope key inventory changed")

    steps = protocol.get("steps")
    require(isinstance(steps, list) and len(steps) == 1, "V23 requires one bounded FreeGS step")
    step = steps[0]
    expected_step = "direct_actual_freegs_fixed_observed_box_picard_policy_v23_process_tree"
    expected_task = "native-axisymmetric-v10-fixed-box-picard-v23-process-tree"
    require(step.get("name") == expected_step and step.get("order") == 1, "V23 step identity mismatch")
    require(step.get("result_exit_schema_contract") == v22["steps"][0]["result_exit_schema_contract"],
            "runner natural-exit status contract changed")
    require(step.get("natural_exit_statuses_by_code") == v22["steps"][0]["natural_exit_statuses_by_code"],
            "runner source-derived natural status sets changed")
    require(step.get("natural_exit_map") == v22["steps"][0]["natural_exit_map"],
            "runner natural-exit category summary changed")
    require(step.get("dynamic_binding") == v22["steps"][0]["dynamic_binding"],
            "FreeGS numerical solver policy/control binding changed")
    require(step.get("required_absent_paths") == [protocol["runtime_endpoint_join"]["output_leaf"]],
            "V23 output-leaf absent guard mismatch")

    v22_dependencies = dependency_map(v22)
    new_dependencies = dependency_map(protocol)
    require(protocol.get("dependency_file_pin_count") == len(new_dependencies) == 169,
            "V23 dependency pin count changed")
    contract_id = protocol["process_tree_supervisor_v23"]
    new_supervisor = str(root / contract_id["source_path"])
    new_verifier = str(root / contract_id["static_verifier_path"])
    new_test = str(root / contract_id["static_test_path"])
    manifest_rel = contract_id.get("pin_manifest_path")
    new_manifest = str(root / str(manifest_rel))
    expected_paths = set(v22_dependencies) | {new_supervisor, new_verifier, new_test, new_manifest}
    require(set(new_dependencies) == expected_paths, "V23 pin set must retain all V22 pins and add supervisor/verifier/test/manifest")
    for path_text, pin in v22_dependencies.items():
        require(new_dependencies[path_text] == pin, f"one of the 165 V22 pins changed: {path_text}")
    for path_text, pin in new_dependencies.items():
        path = Path(path_text)
        require(path.is_file() and path.stat().st_size == pin["bytes"] and sha256(path) == pin["sha256"].lower(),
                f"V23 dependency pin mismatch: {path_text}")
    require(new_dependencies[new_supervisor]["roles"] == ["runtime_dependency"], "V23 supervisor role mismatch")
    require(new_dependencies[new_verifier]["roles"] == ["v23_process_tree_static_verifier"], "V23 verifier role mismatch")
    require(new_dependencies[new_test]["roles"] == ["v23_process_tree_test"], "V23 test role mismatch")
    require(new_dependencies[new_manifest]["roles"] == ["v23_process_tree_pin_manifest"], "V23 pin-manifest role mismatch")
    manifest_payload = load_json(Path(new_manifest))
    require(manifest_payload.get("schema") == PIN_MANIFEST_SCHEMA, "V23 pin manifest schema mismatch")
    manifest_map = {str(item["path"]): str(item["sha256"]).lower() for item in manifest_payload.get("pins", [])}
    require(manifest_payload.get("pin_count") == 168 and len(manifest_map) == 168,
            "V23 runtime pin manifest must contain all 165 old pins plus three V23 code pins")
    require(manifest_map == {path: str(item["sha256"]).lower() for path, item in new_dependencies.items() if path != new_manifest},
            "V23 runtime pin manifest does not bind every non-manifest dependency pin")

    frozen_v22 = v22.get("frozen_files", {})
    frozen_v23 = protocol.get("frozen_files", {})
    v22_contract = v22["protocol_scope_contract_v22"]
    new_frozen = {contract_id["source_path"], contract_id["static_verifier_path"],
                  contract_id["static_test_path"], contract_id["pin_manifest_path"]}
    require(set(frozen_v23) == set(frozen_v22) | new_frozen,
            "V23 frozen-file inventory must preserve V22 files and add its four owned files")
    for rel, digest in frozen_v22.items():
        require(frozen_v23.get(rel) == digest, f"one of the V22 frozen-file pins changed: {rel}")
    require(frozen_v23[contract_id["source_path"]] == sha256(root / contract_id["source_path"]),
            "V23 supervisor frozen pin mismatch")
    require(frozen_v23[contract_id["static_verifier_path"]] == sha256(root / contract_id["static_verifier_path"]),
            "V23 verifier frozen pin mismatch")
    require(frozen_v23[contract_id["static_test_path"]] == sha256(root / contract_id["static_test_path"]),
            "V23 test frozen pin mismatch")
    require(frozen_v23[contract_id["pin_manifest_path"]] == sha256(root / contract_id["pin_manifest_path"]),
            "V23 pin-manifest frozen pin mismatch")
    require(v22_contract == v22["protocol_scope_contract_v22"], "V22 scope provenance contract must remain byte-equivalent")
    require(contract_id.get("static_verifier_path") == "tools/up4_reference_validation/verify_freegs_v23_process_tree_candidate.py",
            "V23 verifier path mismatch")
    require(contract_id.get("static_test_path") == "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v23.py",
            "V23 test path mismatch")
    require(contract_id.get("pin_manifest_path") == "tools/up4_reference_validation/freegs_v23_pin_manifest.json",
            "V23 pin manifest path mismatch")
    require(contract_id.get("source_path") == "tools/up4_reference_validation/freegs_process_supervisor_v23.py",
            "V23 supervisor path mismatch")
    require(contract_id.get("source_sha256") == new_dependencies[new_supervisor]["sha256"], "source pin in V23 contract mismatch")
    require(contract_id.get("static_verifier_sha256") == new_dependencies[new_verifier]["sha256"], "verifier pin in V23 contract mismatch")
    require(contract_id.get("static_test_sha256") == new_dependencies[new_test]["sha256"], "test pin in V23 contract mismatch")
    require(contract_id.get("pin_manifest_sha256") == new_dependencies[new_manifest]["sha256"], "pin-manifest hash in V23 contract mismatch")

    v22_resource = v22.get("resource_contract", {})
    resource = protocol.get("resource_contract", {})
    for key, value in v22_resource.items():
        require(resource.get(key) == value, f"frozen resource contract changed: {key}")
    for key, expected in {
        "supervisor_receipt_schema": "fusionconceptai:recorded-process-execution-v2",
        "incomplete_process_tree_harness_exit": 99,
        "natural_exit_requires_complete_samples_and_descendant_audit": True,
        "partial_rss_never_compared_to_limit": True,
        "tree_exit_proof_scope": EXPECTED_SUPERVISOR_CONTRACT["proof_scope"],
    }.items():
        require(resource.get(key) == expected, f"V23 resource-supervision policy mismatch: {key}")
    require(protocol.get("source_inputs") == v22.get("source_inputs"), "V23 solver input/source bytes changed")
    require(protocol["source_inputs"]["solver_input_sha256"] == "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447",
            "V10 frozen solver input hash changed")
    require(protocol["source_inputs"]["snapshot_sha256"] == "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac",
            "shot-30421 source snapshot hash changed")

    step_v22 = v22["steps"][0]
    argv = step.get("launcher_argv_template")
    v22_argv = copy.deepcopy(step_v22["launcher_argv_template"])
    old_leaf = Path(v22["runtime_endpoint_join"]["output_leaf"]).resolve()
    new_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"]).resolve()
    require(old_leaf != new_leaf and not new_leaf.exists(), "V23 output leaf must be new and absent")
    v22_argv[2] = new_supervisor
    for option, value in [
        ("--name", expected_task),
        ("--stdout", str(new_leaf / "stdout.raw")),
        ("--stderr", str(new_leaf / "stderr.raw")),
        ("--receipt", str(new_leaf / "execution.json")),
        ("--require-absent-path", str(new_leaf)),
    ]:
        v22_argv[v22_argv.index(option) + 1] = value
    separator = v22_argv.index("--")
    child_argv = v22_argv[separator + 1:]
    require("--output" in child_argv, "pinned child command lacks output option")
    child_argv[child_argv.index("--output") + 1] = str(new_leaf / "solver_output.json")
    prefix: list[str] = []
    index = 0
    while index < separator:
        token = v22_argv[index]
        if token == "--require-file-sha256":
            index += 2
            continue
        prefix.append(token)
        index += 1
    require("--require-absent-path" in prefix, "fresh output absence guard missing")
    insert_at = prefix.index("--require-absent-path") + 2
    manifest_sha = new_dependencies[new_manifest]["sha256"]
    prefix[insert_at:insert_at] = [
        "--require-file-sha256", new_manifest + "=" + manifest_sha,
        "--require-file-sha256-manifest", new_manifest,
    ]
    expected_argv = prefix + ["--"] + child_argv
    require(argv == expected_argv, "V23 launcher argv differs beyond supervisor/task/output pins")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)) < 32767,
            "V23 Windows launcher command length invalid")
    require(parse_launcher_pins(argv) == {new_manifest: str(new_dependencies[new_manifest]["sha256"]).lower()},
            "launcher must directly pin only the verified pin manifest")
    manifest_argv = [argv[i + 1] for i, token in enumerate(argv[:argv.index("--")])
                     if token == "--require-file-sha256-manifest"]
    require(manifest_argv == [new_manifest], "launcher must pass exactly the pinned V23 file manifest")
    require(step.get("result_path") == str(new_leaf / "solver_output.json"), "V23 result path mismatch")
    endpoint = protocol.get("runtime_endpoint_join", {})
    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    require(endpoint.get("output_leaf") == str(new_leaf) and endpoint.get("output_leaf_absent_at_candidate_freeze") is True,
            "V23 endpoint output-leaf binding mismatch")
    require(endpoint.get("solver_output") == step.get("result_path"), "V23 endpoint solver output mismatch")
    require(sidecars.get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"),
            "V23 evidence-only archive rule changed")
    for key in ("adapter_receipt", "execution", "solver_output", "stdout", "stderr"):
        sidecar = Path(sidecars[key])
        require(sidecar.parent == new_leaf and not sidecar.exists(), f"V23 {key} sidecar path is not fresh in the output leaf")

    source = root / contract_id["source_path"]
    source_text = source.read_text(encoding="utf-8")
    for fragment in [
        "def observe_process_tree(",
        "root_identity_membership",
        "except Exception as exc:",
        "raise ProcessTreeEvidenceError(\"rss_read\"",
        "def stop_and_verify(",
        "TREE_EVIDENCE_EXIT = 99",
        "natural_root_exit_with_live_descendants",
        "sampled evidence only, not OS job containment",
    ]:
        require(fragment in source_text, f"V23 source contract anchor missing: {fragment}")

    return {
        "status": "static_process_tree_candidate_pass_ungranted",
        "protocol_sha256": sha256(protocol_path),
        "dependency_pin_count": len(new_dependencies),
        "all_dependency_pins_rehashed": True,
        "v22_scope_static_go_ancestry_preserved": True,
        "v22_runtime_no_go_bound": True,
        "supervisor_contract_bound": True,
        "solver_inputs_and_numerical_controls_unchanged": True,
        "resource_limits": {"wall_seconds": 180, "rss_bytes": 2147483648, "threads": 1},
        "root_resource_slot_granted": False,
        "runtime_execution_authorized": False,
        "freegs_or_julia_started": False,
        "new_output_leaf_absent": True,
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
        print(f"FreeGS v23 process-tree verifier failed: {type(exc).__name__}: {exc}")
        raise SystemExit(1)
