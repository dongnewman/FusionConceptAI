"""Static-only verifier for the isolated FreeGS v25 supervisor candidate."""
from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
from typing import Any


SCHEMA = "fusionconceptai:native-axisymmetric-forward-fixed-observed-box-picard-v25-process-tree-supervisor"
V24_PROTOCOL_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v15/actual_run_protocol_v24_process_tree_candidate_v1.json"
V24_PROTOCOL_SHA256 = "2735bfb319695240ba9abc868e76e3b6756146067e635abf83ff0e0c88c37a4d"
V24_VERIFIER_SHA256 = "8d564ba6b84f8c0e813c93dd1c22da1e866a4da080021eb51c0ed866560f5d28"
V24_OWNER_MANIFEST_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v24_identity_binding_static_r1/evidence_manifest.json"
V24_OWNER_MANIFEST_SHA256 = "52a222ee54f1c9d1b39098d3f95fd5c79eaf772fe4e91a0b42b25a81e6fadd16"
V24_TESTER_ROOT = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v24_process_tree_review_20260924"
V24_TESTER_RECEIPT_SHA256 = "fd3c18d19c0d75bdbceb55706a63a26ced082bf10e422a70c4a3b735f4df3a3a"
V24_TESTER_MANIFEST_SHA256 = "cddbe0177410a49672f5df140b63953b701aeeb5c032e40e123739fc85fbbd98"
V24_REVIEWER_ROOT = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v24_process_tree_review_r2_20260924"
V24_REVIEWER_REVIEW_SHA256 = "2ce5145b17ee503e06aec7748257c1b777301ef155bc9b1372775d24608a3492"
V24_REVIEWER_MANIFEST_SHA256 = "1927021bb91ef2d1934e7cbe15aaa8ee8aedc68e1a8e9f632a913e21b3c41772"
V24_ROOT_DECISION_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/root_freegs_v24_runtime_no_go_20260924/decision.md"
V24_ROOT_DECISION_SHA256 = "6bbce7a770c2d6aa899dc86683ac5386809d7be03a37fda4a70da2cc92ed34e8"
V22_PROTOCOL_SHA256 = "45b99a9b6c14005275de07895b1c248164a2385dc33d060c2cf03d0ef0b9d3b8"
V22_DECISION_SHA256 = "070f86e2a11956b986c0b6a6f1dc01d9a6534aa0ecfcc2651fb5b10281bbfb6d"
V22_REVIEW_SHA256 = "d0d245b4ce b39f656e32de7ff1ad1d1574788208ad5bf6eea91b3db4781753ae".replace(" ", "")
V22_REVIEW_MANIFEST_SHA256 = "29d1ac33b532de33016c99f5d07626df2aa5846a89e2579c4cde710b886982ea"
V22_VERIFIER_SHA256 = "788cc415f8435ae30f01cabb647c1367b13953eb9e84cf7b6160c0b1e546c5dd"
V22_TEST_SHA256 = "75c8a7365245a89dd1991187dfb61a95a68be23ebc3fc989a8c760ec10ee4ff3"
V22_SCOPE_SHA256 = "4943e77a25c96e2cab948ce6379f13cab07a289661eecf8a5b9004f9595334c1"
V23_PROTOCOL_SHA256 = "c05adbfb7c0abf87d6d28b96e2c0249e64cb4ad29032ea60c8b3cefdddac86a4"
V23_VERIFIER_SHA256 = "a87af3d1e5a022c89b99bb8be1ec4b246528f0baaaf1729f83694c02f0d8763f"
V23_REVIEW_RECEIPT_SHA256 = "2714d497f2bb41631ff05f25b28117231d6c56eff65d60a1ac128b38018f178c"
V23_REVIEW_MANIFEST_SHA256 = "90c661f018a55ebf51f932eb5f7e12aee0bddd8de2b79574188340dc734a4be5"
V23_REVIEW_RESULT_SHA256 = "27531af2e262c4d5ae7f6ebed7f893a10a4e19505ab9d173d3ad8b241b6994f3"
V23_SECOND_REVIEW_SHA256 = "01461231cac272ba281f2857bdd0599bf178b20a0e212cbfd15cde7495863a12"
V23_OWNER_MANIFEST_SHA256 = "5703322bf96329b55a2abb7acc469ff8591d891a713c4e32126c3efd1166f4a6"
V23_STATIC_VERIFIER_REVIEW_ROOT = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v23_process_tree_review_20260924"
V23_SECOND_REVIEW_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v23_process_tree_review_reference_inverse_r1_20260924/review.md"
V23_OWNER_MANIFEST_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/agent_reference_gs_20260924/freegs_v23_process_tree_static_r2/evidence_manifest.json"
V23_PROTOCOL_PATH = "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/agent_reference_gs_20260924/native_axisymmetric_forward_v14/actual_run_protocol_v23_process_tree_candidate_v1.json"
EXPECTED_EXIT_CODES = {
    "preflight": 96,
    "wall_limit": 97,
    "rss_limit": 98,
    "incomplete_or_unproven_tree": 99,
}
PIN_MANIFEST_SCHEMA = "fusionconceptai:process-tree-required-files-manifest-v1"
EXPECTED_SUPERVISOR_CONTRACT = {
    "version": "freegs-process-supervisor-v25",
    "receipt_schema": "fusionconceptai:recorded-process-execution-v2",
    "tree_observation_contract": "complete_sampled_recursive_tree_rss_and_tracked_descendant_exit_v2_popen_identity_bound_strictly_typed",
    "sample_race_policy": "NoSuchProcess or AccessDenied during recursive enumeration, process identity, or RSS read invalidates the entire sample; raw PID must be a builtin positive int and raw create_time a builtin finite positive int/float excluding bool before any numeric coercion; the Popen and Process(pid) root identities must also match before sampling; never compare a partial sum to the cap.",
    "cleanup_policy": "Record terminate/kill/wait attempts; return a resource exit only when enumeration is complete and every tracked process is verified gone. Any denied, failed, or unknown operation returns supervisor exit 99. If root identity is unbound or may refer to a reused PID, cleanup may use only the Popen-owned child handle and never the unbound lookup handle.",
    "natural_exit_policy": "Preserve the child exit only after all samples were complete, Popen and Process(pid) still identify the exact initially bound root after wait, the exact root lookup reports gone, and every sampled descendant is verified gone; malformed, coercible, nonfinite, or nonpositive identity fields, identity mismatch, unreadable identity, live or unreadable descendants yield supervisor exit 99.",
    "proof_scope": "Sampled process tree and identities discovered by complete recursive snapshots; not OS job-object containment and not a guarantee about a process existing only between samples.",
    "resource_exit_codes": EXPECTED_EXIT_CODES,
    "negative_controls": [
        "complete samples contain the exact root pid/create-time identity once",
        "Popen launch handle and Process(pid) lookup have exact matching pid/create-time before first sample",
        "reject bool True create_time even when a lookup returns float 1.0 before any identity coercion",
        "reject bool or coercible non-integer PID before converting it to int",
        "reject bool, strings, nonfinite, zero, or negative create_time before converting it to float",
        "Popen create-time unreadable before sampling fails closed with zero complete samples",
        "Process(pid) create-time unreadable before sampling fails closed with zero complete samples",
        "PID reuse between Popen and Process(pid) lookup returns exit 99 without signaling the reused lookup PID",
        "natural exit rechecks exact Popen and Process(pid) identities and requires the exact root lookup gone",
        "natural exit identity drift after wait fails exit 99 and never signals the reused lookup PID",
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
    require(protocol.get("schema") == SCHEMA, "V25 schema mismatch")
    require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "V25 must remain ungranted")
    require(protocol.get("runtime_execution_authorized") is False, "V25 cannot authorize execution")
    slot = protocol.get("root_resource_slot", {})
    require(slot.get("required") is True and slot.get("granted") is False, "root resource slot must remain ungranted")
    require(slot.get("v24_runtime_no_go_preserved") is True, "V24 runtime NO-GO must remain explicit in V25")

    v24_path = root / V24_PROTOCOL_PATH
    require(v24_path.is_file() and sha256(v24_path) == V24_PROTOCOL_SHA256,
            "frozen V24 protocol ancestry changed")
    v24 = load_json(v24_path)
    v24_verifier_path = root / "tools/up4_reference_validation/verify_freegs_v24_process_tree_candidate.py"
    require(v24_verifier_path.is_file() and sha256(v24_verifier_path) == V24_VERIFIER_SHA256,
            "frozen V24 static verifier changed")
    v24_verifier = import_module(v24_verifier_path, "freegs_v24_ancestry_verifier")
    v24_result = v24_verifier.validate_candidate(v24_path)
    require(v24_result.get("dependency_pin_count") == 179 and v24_result.get("root_resource_slot_granted") is False,
            "V24 frozen 179-pin static candidate no longer validates")

    prior_v24 = protocol.get("prior_v24_runtime_no_go", {})
    expected_v24_ancestry = {
        "protocol_path": V24_PROTOCOL_PATH,
        "protocol_sha256": V24_PROTOCOL_SHA256,
        "owner_static_evidence_manifest_path": V24_OWNER_MANIFEST_PATH,
        "owner_static_evidence_manifest_sha256": V24_OWNER_MANIFEST_SHA256,
        "independent_tester_receipt_path": V24_TESTER_ROOT + "/independent_review_receipt.json",
        "independent_tester_receipt_sha256": V24_TESTER_RECEIPT_SHA256,
        "independent_tester_manifest_path": V24_TESTER_ROOT + "/evidence_manifest.json",
        "independent_tester_manifest_sha256": V24_TESTER_MANIFEST_SHA256,
        "independent_reviewer_review_path": V24_REVIEWER_ROOT + "/review.md",
        "independent_reviewer_review_sha256": V24_REVIEWER_REVIEW_SHA256,
        "independent_reviewer_manifest_path": V24_REVIEWER_ROOT + "/evidence_manifest.json",
        "independent_reviewer_manifest_sha256": V24_REVIEWER_MANIFEST_SHA256,
        "root_decision_path": V24_ROOT_DECISION_PATH,
        "root_decision_sha256": V24_ROOT_DECISION_SHA256,
        "finding": "V24 is retained as runtime NO-GO: its coercive int(pid)/float(create_time) accepts malformed bool True and float 1.0 as the same identity, allowing complete sampled-tree evidence; V25 rejects malformed raw identity types before conversion.",
    }
    require(prior_v24 == expected_v24_ancestry, "V24 malformed-identity NO-GO ancestry binding mismatch")
    for path_key, hash_key in [
        ("protocol_path", "protocol_sha256"),
        ("owner_static_evidence_manifest_path", "owner_static_evidence_manifest_sha256"),
        ("independent_tester_receipt_path", "independent_tester_receipt_sha256"),
        ("independent_tester_manifest_path", "independent_tester_manifest_sha256"),
        ("independent_reviewer_review_path", "independent_reviewer_review_sha256"),
        ("independent_reviewer_manifest_path", "independent_reviewer_manifest_sha256"),
        ("root_decision_path", "root_decision_sha256"),
    ]:
        ancestry_file = root / prior_v24[path_key]
        require(ancestry_file.is_file() and sha256(ancestry_file) == prior_v24[hash_key],
                f"V24 NO-GO ancestry evidence changed: {prior_v24[path_key]}")

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

    v23_path = root / V23_PROTOCOL_PATH
    require(v23_path.is_file() and sha256(v23_path) == V23_PROTOCOL_SHA256,
            "frozen V23 protocol ancestry changed")
    v23 = load_json(v23_path)
    v23_verifier_path = root / "tools/up4_reference_validation/verify_freegs_v23_process_tree_candidate.py"
    require(v23_verifier_path.is_file() and sha256(v23_verifier_path) == V23_VERIFIER_SHA256,
            "frozen V23 static verifier changed")
    v23_verifier = import_module(v23_verifier_path, "freegs_v23_ancestry_verifier")
    v23_result = v23_verifier.validate_candidate(v23_path)
    require(v23_result.get("dependency_pin_count") == 169 and v23_result.get("root_resource_slot_granted") is False,
            "V23 frozen 169-pin static candidate no longer validates")

    prior_v23 = protocol.get("prior_v23_runtime_no_go", {})
    expected_v23_ancestry = {
        "protocol_path": V23_PROTOCOL_PATH,
        "protocol_sha256": V23_PROTOCOL_SHA256,
        "independent_review_receipt_path": V23_STATIC_VERIFIER_REVIEW_ROOT + "/independent_review_receipt.json",
        "independent_review_receipt_sha256": V23_REVIEW_RECEIPT_SHA256,
        "independent_review_manifest_path": V23_STATIC_VERIFIER_REVIEW_ROOT + "/evidence_manifest.json",
        "independent_review_manifest_sha256": V23_REVIEW_MANIFEST_SHA256,
        "independent_check_result_path": V23_STATIC_VERIFIER_REVIEW_ROOT + "/independent_check_result.json",
        "independent_check_result_sha256": V23_REVIEW_RESULT_SHA256,
        "second_independent_review_path": V23_SECOND_REVIEW_PATH,
        "second_independent_review_sha256": V23_SECOND_REVIEW_SHA256,
        "owner_static_evidence_manifest_path": V23_OWNER_MANIFEST_PATH,
        "owner_static_evidence_manifest_sha256": V23_OWNER_MANIFEST_SHA256,
        "finding": "V23 is static-only GO and runtime NO-GO: independent fake Popen generation A versus Process(pid) generation B can falsely report a complete natural exit; preserve all V23 bytes and bind exact launch identity in V24.",
    }
    require(prior_v23 == expected_v23_ancestry, "V23 independent NO-GO ancestry binding mismatch")
    for path_key, hash_key in [
        ("protocol_path", "protocol_sha256"),
        ("independent_review_receipt_path", "independent_review_receipt_sha256"),
        ("independent_review_manifest_path", "independent_review_manifest_sha256"),
        ("independent_check_result_path", "independent_check_result_sha256"),
        ("second_independent_review_path", "second_independent_review_sha256"),
        ("owner_static_evidence_manifest_path", "owner_static_evidence_manifest_sha256"),
    ]:
        ancestry_file = root / prior_v23[path_key]
        require(ancestry_file.is_file() and sha256(ancestry_file) == prior_v23[hash_key],
                f"V23 NO-GO ancestry evidence changed: {prior_v23[path_key]}")

    contract = protocol.get("process_tree_supervisor_v25", {})
    contract_pin_fields = {
        "source_path", "source_sha256", "static_verifier_path", "static_verifier_sha256",
        "static_test_path", "static_test_sha256", "pin_manifest_path", "pin_manifest_sha256",
    }
    require(set(contract) == set(EXPECTED_SUPERVISOR_CONTRACT) | contract_pin_fields,
            "V25 process-tree supervisor contract field inventory mismatch")
    for key, expected in EXPECTED_SUPERVISOR_CONTRACT.items():
        require(contract.get(key) == expected, f"V25 process-tree supervisor contract mismatch: {key}")
    scope = protocol.get("scope")
    require(scope == v24.get("scope") == v23.get("scope") == v22.get("scope") and isinstance(scope, dict) and len(scope) == 17,
            "V25 must preserve the exact V24/V23/V22 17-key scope")
    v22_scope_contract = protocol.get("protocol_scope_contract_v22", {})
    require(v22_scope_contract.get("restored_scope_sha256") == V22_SCOPE_SHA256, "17-key scope hash changed")
    require(v22_scope_contract.get("current_scope") == scope, "scope receipt differs from top-level scope")
    require(v22_scope_contract.get("scope_key_count") == 17 and v22_scope_contract.get("scope_key_names") == sorted(scope),
            "scope key inventory changed")

    steps = protocol.get("steps")
    require(isinstance(steps, list) and len(steps) == 1, "V25 requires one bounded FreeGS step")
    step = steps[0]
    expected_step = "direct_actual_freegs_fixed_observed_box_picard_policy_v25_process_tree_strict_identity"
    expected_task = "native-axisymmetric-v10-fixed-box-picard-v25-strict-identity-process-tree"
    require(step.get("name") == expected_step and step.get("order") == 1, "V25 step identity mismatch")
    require(step.get("result_exit_schema_contract") == v24["steps"][0]["result_exit_schema_contract"],
            "runner natural-exit status contract changed")
    require(step.get("natural_exit_statuses_by_code") == v24["steps"][0]["natural_exit_statuses_by_code"],
            "runner source-derived natural status sets changed")
    require(step.get("natural_exit_map") == v24["steps"][0]["natural_exit_map"],
            "runner natural-exit category summary changed")
    require(step.get("dynamic_binding") == v24["steps"][0]["dynamic_binding"],
            "FreeGS numerical solver policy/control binding changed")
    require(step.get("required_absent_paths") == [protocol["runtime_endpoint_join"]["output_leaf"]],
            "V25 output-leaf absent guard mismatch")

    v24_dependencies = dependency_map(v24)
    new_dependencies = dependency_map(protocol)
    require(protocol.get("dependency_file_pin_count") == len(new_dependencies) == 190,
            "V25 dependency pin count changed")
    contract_id = protocol["process_tree_supervisor_v25"]
    new_supervisor = str(root / contract_id["source_path"])
    new_verifier = str(root / contract_id["static_verifier_path"])
    new_test = str(root / contract_id["static_test_path"])
    manifest_rel = contract_id.get("pin_manifest_path")
    new_manifest = str(root / str(manifest_rel))
    ancestry_paths = {
        str((root / path).resolve()): prior_v24[hash_key]
        for path, hash_key in [
            (V24_PROTOCOL_PATH, "protocol_sha256"),
            (V24_OWNER_MANIFEST_PATH, "owner_static_evidence_manifest_sha256"),
            (V24_TESTER_ROOT + "/independent_review_receipt.json", "independent_tester_receipt_sha256"),
            (V24_TESTER_ROOT + "/evidence_manifest.json", "independent_tester_manifest_sha256"),
            (V24_REVIEWER_ROOT + "/review.md", "independent_reviewer_review_sha256"),
            (V24_REVIEWER_ROOT + "/evidence_manifest.json", "independent_reviewer_manifest_sha256"),
            (V24_ROOT_DECISION_PATH, "root_decision_sha256"),
        ]
    }
    expected_paths = set(v24_dependencies) | {new_supervisor, new_verifier, new_test, new_manifest} | set(ancestry_paths)
    require(set(new_dependencies) == expected_paths,
            "V25 pins must preserve all 179 V24 pins and add four V25 code/manifest pins plus seven frozen V24 ancestry evidence pins")
    for path_text, pin in v24_dependencies.items():
        require(new_dependencies[path_text] == pin, f"one of the 179 V24 pins changed: {path_text}")
    for path_text, expected in ancestry_paths.items():
        require(new_dependencies[path_text]["sha256"].lower() == expected,
                f"V23 ancestry pin hash mismatch: {path_text}")
    for path_text, pin in new_dependencies.items():
        path = Path(path_text)
        require(path.is_file() and path.stat().st_size == pin["bytes"] and sha256(path) == pin["sha256"].lower(),
                f"V25 dependency pin mismatch: {path_text}")
    require(new_dependencies[new_supervisor]["roles"] == ["runtime_dependency"], "V25 supervisor role mismatch")
    require(new_dependencies[new_verifier]["roles"] == ["v25_process_tree_static_verifier"], "V25 verifier role mismatch")
    require(new_dependencies[new_test]["roles"] == ["v25_process_tree_test"], "V25 test role mismatch")
    require(new_dependencies[new_manifest]["roles"] == ["v25_process_tree_pin_manifest"], "V25 pin-manifest role mismatch")
    manifest_payload = load_json(Path(new_manifest))
    require(manifest_payload.get("schema") == PIN_MANIFEST_SCHEMA, "V25 pin manifest schema mismatch")
    manifest_map = {str(item["path"]): str(item["sha256"]).lower() for item in manifest_payload.get("pins", [])}
    require(manifest_payload.get("pin_count") == 189 and len(manifest_map) == 189,
            "V25 runtime manifest must contain all 179 V24 pins, seven frozen ancestry pins, and three V25 code pins")
    require(manifest_map == {path: str(item["sha256"]).lower() for path, item in new_dependencies.items() if path != new_manifest},
            "V25 runtime pin manifest does not bind every non-manifest dependency pin")

    frozen_v24 = v24.get("frozen_files", {})
    frozen_v25 = protocol.get("frozen_files", {})
    new_frozen = {contract_id["source_path"], contract_id["static_verifier_path"],
                  contract_id["static_test_path"], contract_id["pin_manifest_path"]}
    require(set(frozen_v25) == set(frozen_v24) | new_frozen,
            "V25 frozen-file inventory must preserve all V24 files and add its four owned files")
    for rel, digest in frozen_v24.items():
        require(frozen_v25.get(rel) == digest, f"one of the V24 frozen-file pins changed: {rel}")
    require(frozen_v25[contract_id["source_path"]] == sha256(root / contract_id["source_path"]),
            "V25 supervisor frozen pin mismatch")
    require(frozen_v25[contract_id["static_verifier_path"]] == sha256(root / contract_id["static_verifier_path"]),
            "V25 verifier frozen pin mismatch")
    require(frozen_v25[contract_id["static_test_path"]] == sha256(root / contract_id["static_test_path"]),
            "V25 test frozen pin mismatch")
    require(frozen_v25[contract_id["pin_manifest_path"]] == sha256(root / contract_id["pin_manifest_path"]),
            "V25 pin-manifest frozen pin mismatch")
    require(protocol.get("protocol_scope_contract_v22") == v24.get("protocol_scope_contract_v22"),
            "V22 scope provenance contract must remain byte-equivalent through V24")
    require(contract_id.get("static_verifier_path") == "tools/up4_reference_validation/verify_freegs_v25_process_tree_candidate.py",
            "V25 verifier path mismatch")
    require(contract_id.get("static_test_path") == "test/UP4ReferenceValidationV1/test_freegs_process_supervisor_v25.py",
            "V25 test path mismatch")
    require(contract_id.get("pin_manifest_path") == "tools/up4_reference_validation/freegs_v25_pin_manifest.json",
            "V25 pin manifest path mismatch")
    require(contract_id.get("source_path") == "tools/up4_reference_validation/freegs_process_supervisor_v25.py",
            "V25 supervisor path mismatch")
    require(contract_id.get("source_sha256") == new_dependencies[new_supervisor]["sha256"], "source pin in V25 contract mismatch")
    require(contract_id.get("static_verifier_sha256") == new_dependencies[new_verifier]["sha256"], "verifier pin in V25 contract mismatch")
    require(contract_id.get("static_test_sha256") == new_dependencies[new_test]["sha256"], "test pin in V25 contract mismatch")
    require(contract_id.get("pin_manifest_sha256") == new_dependencies[new_manifest]["sha256"], "pin-manifest hash in V25 contract mismatch")

    v24_resource = v24.get("resource_contract", {})
    resource = protocol.get("resource_contract", {})
    for key, value in v24_resource.items():
        require(resource.get(key) == value, f"frozen resource contract changed: {key}")
    for key, expected in {
        "supervisor_receipt_schema": "fusionconceptai:recorded-process-execution-v2",
        "incomplete_process_tree_harness_exit": 99,
        "natural_exit_requires_complete_samples_and_descendant_audit": True,
        "partial_rss_never_compared_to_limit": True,
        "tree_exit_proof_scope": EXPECTED_SUPERVISOR_CONTRACT["proof_scope"],
        "root_identity_binding_required": True,
        "root_identity_lookup_mismatch_harness_exit": 99,
        "natural_exit_requires_exact_bound_root_identity": True,
        "identity_failure_never_signals_unbound_lookup_pid": True,
        "identity_fields_strictly_typed_before_numeric_conversion": True,
        "pid_requires_builtin_positive_int": True,
        "create_time_requires_builtin_finite_positive_int_or_float_excluding_bool": True,
        "malformed_identity_harness_exit": 99,
    }.items():
        require(resource.get(key) == expected, f"V25 resource-supervision policy mismatch: {key}")
    require(protocol.get("source_inputs") == v24.get("source_inputs"), "V25 solver input/source bytes changed")
    require(protocol["source_inputs"]["solver_input_sha256"] == "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447",
            "V10 frozen solver input hash changed")
    require(protocol["source_inputs"]["snapshot_sha256"] == "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac",
            "shot-30421 source snapshot hash changed")

    step_v23 = v24["steps"][0]
    argv = step.get("launcher_argv_template")
    v23_argv = copy.deepcopy(step_v23["launcher_argv_template"])
    old_leaf = Path(v24["runtime_endpoint_join"]["output_leaf"]).resolve()
    new_leaf = Path(protocol["runtime_endpoint_join"]["output_leaf"]).resolve()
    require(old_leaf != new_leaf and not new_leaf.exists(), "V25 output leaf must be new and absent")
    v23_argv[2] = new_supervisor
    for option, value in [
        ("--name", expected_task),
        ("--stdout", str(new_leaf / "stdout.raw")),
        ("--stderr", str(new_leaf / "stderr.raw")),
        ("--receipt", str(new_leaf / "execution.json")),
        ("--require-absent-path", str(new_leaf)),
    ]:
        v23_argv[v23_argv.index(option) + 1] = value
    separator = v23_argv.index("--")
    child_argv = v23_argv[separator + 1:]
    require("--output" in child_argv, "pinned child command lacks output option")
    child_argv[child_argv.index("--output") + 1] = str(new_leaf / "solver_output.json")
    prefix: list[str] = []
    index = 0
    while index < separator:
        token = v23_argv[index]
        if token in {"--require-file-sha256", "--require-file-sha256-manifest"}:
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
    require(argv == expected_argv, "V25 launcher argv differs beyond supervisor/task/output pins")
    require(step.get("command_length_chars") == len(subprocess.list2cmdline(argv)) < 32767,
            "V25 Windows launcher command length invalid")
    require(parse_launcher_pins(argv) == {new_manifest: str(new_dependencies[new_manifest]["sha256"]).lower()},
            "launcher must directly pin only the verified pin manifest")
    manifest_argv = [argv[i + 1] for i, token in enumerate(argv[:argv.index("--")])
                     if token == "--require-file-sha256-manifest"]
    require(manifest_argv == [new_manifest], "launcher must pass exactly the pinned V25 file manifest")
    require(step.get("result_path") == str(new_leaf / "solver_output.json"), "V25 result path mismatch")
    endpoint = protocol.get("runtime_endpoint_join", {})
    sidecars = protocol.get("mandatory_evidence_sidecars", {})
    require(endpoint.get("output_leaf") == str(new_leaf) and endpoint.get("output_leaf_absent_at_candidate_freeze") is True,
            "V25 endpoint output-leaf binding mismatch")
    require(endpoint.get("solver_output") == step.get("result_path"), "V25 endpoint solver output mismatch")
    require(sidecars.get("storage_rule", "").startswith("raw run/exit/hash/review evidence only under"),
            "V25 evidence-only archive rule changed")
    for key in ("adapter_receipt", "execution", "solver_output", "stdout", "stderr"):
        sidecar = Path(sidecars[key])
        require(sidecar.parent == new_leaf and not sidecar.exists(), f"V25 {key} sidecar path is not fresh in the output leaf")

    source = root / contract_id["source_path"]
    source_text = source.read_text(encoding="utf-8")
    for fragment in [
        "def observe_process_tree(",
        "root_identity_membership",
        "popen_root_identity",
        "lookup_root_identity",
        "root_identity_binding_mismatch",
        "root_identity_binding_failed",
        "pid_value = process.pid",
        "created_value = process.create_time()",
        "type(pid_value) is not int",
        "type(created_value) not in (int, float)",
        "created <= 0",
        "def _verify_natural_root_identity(",
        "natural_exit_root_identity_mismatch",
        "sample_root_identity_mismatch",
        "stop_child_without_process_identity(child, api)",
        "except Exception as exc:",
        "raise ProcessTreeEvidenceError(\"rss_read\"",
        "def stop_and_verify(",
        "TREE_EVIDENCE_EXIT = 99",
        "natural_root_exit_with_live_descendants",
        "sampled evidence only, not OS job containment",
    ]:
        require(fragment in source_text, f"V25 source contract anchor missing: {fragment}")

    return {
        "status": "static_process_tree_strict_typed_identity_candidate_pass_ungranted",
        "protocol_sha256": sha256(protocol_path),
        "dependency_pin_count": len(new_dependencies),
        "v24_dependency_pins_preserved": 179,
        "v23_dependency_pins_preserved": 169,
        "v24_runtime_no_go_bound": True,
        "strict_raw_identity_type_checks_bound": True,
        "popen_process_identity_binding_bound": True,
        "natural_exit_exact_root_identity_check_bound": True,
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
        print(f"FreeGS v25 process-tree verifier failed: {type(exc).__name__}: {exc}")
        raise SystemExit(1)
