#!/usr/bin/env python3
"""Python-only preflight for the ungranted FreeGS v15 protocol candidate.

This verifier does not import FreeGS, launch Julia, or start a solver. It
rehashes every supervisor pin and proves the full child argv/input/output
binding before a later root-controlled resource grant.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
from typing import Any


EXPECTED_SCHEMA = (
    "fusionconceptai:native-axisymmetric-forward-observed-box-"
    "corner-diagnostic-precontext-terminal-review-candidate-v15"
)
EXPECTED_STEP = (
    "direct_actual_freegs_fixed_observed_box_corner_diagnostic_v6_r15"
)
EXPECTED_INPUT_SHA256 = "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"
EXPECTED_SOURCE_SHA256 = "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac"
EXPECTED_BASELINE_SHA256 = "3fbc8262ea9e6ab58e06892349bc3640e36d88f2985d950cc386b511e6e3b4ec"
EXPECTED_REVISION_V6 = "runtime-v4-freegs-axisymmetric-profile-execution-v6-precontext-terminal-receipt"
EXPECTED_BASELINE_REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v2"
EXPECTED_CONTROLS = {
    "atol": 1e-10,
    "blend": 0.0,
    "boundary": "observed_dirichlet_box_edges",
    "cocos_mapping": "identity_no_sign_or_2pi_transform",
    "cocos_scope": "gs_bp_subset_only_q_theta_not_consumed",
    "coordinate_transform": "linear_interp_source_r_to_uniform_solver_r",
    "machine": "explicit_empty_machine",
    "max_iterations": 100,
    "mode": "source_and_observed_dirichlet_fixed_boundary",
    "rtol": 1e-5,
}
MAX_PREPROJECT_DELTA = 1.0e-12
EXPECTED_STORAGE_RULE = (
    "raw run/exit/hash/review evidence only under docs/implementation/"
    "UP4-03-REFERENCE-VALIDATION-PREC/archive/**; tools and tests stay in "
    "their owned source/test paths"
)
EXPECTED_REVIEW_ANCESTRY = {
    "search_chain_tester": {
        "report_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_v12_static_review_r1_20260923/review.md",
        "report_sha256": "269156b24a6a6d4efc636fa7430e75c5c5b9a15292e950db5bf85117475c53d6",
        "manifest_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_v12_static_review_r1_20260923/review_manifest.json",
        "manifest_sha256": "58e397b77e1b09290276766a9f5c01b6f84caa942ea6ff7fcbcc0f94ab02467f",
    },
    "native_g1g2_reviewer": {
        "report_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v12_static_review_r1_20260923/review.md",
        "report_sha256": "a801ac0554527df6e08f5c33f96217678360a9a5251de3a3a405915758de6428",
        "manifest_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v12_static_review_r1_20260923/archive_manifest.json",
        "manifest_sha256": "b4b842b216ca626d45e7cb374896189585fb5fb3cb5193bb88889dabc8c9eaf7",
    },
}
EXPECTED_PRIOR_CANDIDATE_NO_GO = {
    "v13_dispatch_review": {
        "report_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v13_dispatch_review_r1_20260923/review.md",
        "report_sha256": "6ccf1ef035f48fb79023c8190424b177a79775f6e65bf56e94f229971520afc7",
        "manifest_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v13_dispatch_review_r1_20260923/archive_manifest.json",
        "manifest_sha256": "6f756f360431038393846d1318e7d45178b550a226c34d49fb60e309fcb042ce",
    },
    "v14_math_code_review": {
        "report_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v14_math_code_review_20260923/review.md",
        "report_sha256": "b214cc5d8281d15d5044dab74401f37ca4951198ab026b52a384435d5b40f5c5",
        "manifest_path": "docs/implementation/UP4-03-REFERENCE-VALIDATION-PREC/archive/independent_freegs_v14_math_code_review_20260923/review_manifest.json",
        "manifest_sha256": "9837a71774b5713c14fe3d9075fcbe16faa3602f88c2b1e1f709a1ab38859ba2",
    },
}
EXPECTED_V13_RUNNER_SHA256 = "9c060e4bf9fdb15298b1fef647ab2d9d2e0e5a7d9bd1e5d8daf1203ee76a2f6b"


def validate_prior_candidate_no_go_ancestry(
    protocol: dict[str, Any], repository_root: Path
) -> dict[str, dict[str, str]]:
    ancestry = protocol.get("prior_candidate_no_go_ancestry")
    _require(isinstance(ancestry, dict), "prior v13/v14 NO-GO ancestry is missing")
    _require(ancestry.get("status") == "frozen_prior_no_go_only", "prior candidate ancestry status mismatch")
    result: dict[str, dict[str, str]] = {}
    for role, expected in EXPECTED_PRIOR_CANDIDATE_NO_GO.items():
        record = ancestry.get(role)
        _require(isinstance(record, dict), f"prior candidate review is missing: {role}")
        _require(record.get("verdict") == "NO-GO", f"prior candidate verdict changed: {role}")
        result[role] = {}
        for kind in ("report", "manifest"):
            path_key, hash_key = kind + "_path", kind + "_sha256"
            relative, digest = expected[path_key], expected[hash_key]
            _require(record.get(path_key) == relative, f"prior candidate review path changed: {role}/{kind}")
            _require(record.get(hash_key) == digest, f"prior candidate review hash declaration changed: {role}/{kind}")
            evidence_path = repository_root / relative
            _require(evidence_path.is_file(), f"prior candidate review is missing: {relative}")
            _require(sha256(evidence_path) == digest, f"prior candidate review hash mismatch: {relative}")
            result[role][kind + "_sha256"] = digest
    return result


REQUIRED_POSTCONDITIONS = (
    "projection occurs only before original FreeGS _updatePlasmaPsi for the exact marked target callback and same source-derived grid; original method is called afterward to update spline/critical metadata",
    "all four frozen source edges are corner-compatible and are restored exactly only when every preprojection per-sample delta is <= 1e-12 Wb/rad; any larger delta aborts before projection",
    "the 1e-12 Wb/rad cap is a test-only roundoff guard based solely on v11 same-grid FreeGS 0.8.2 measurements, not a solver, residual, or physics acceptance threshold",
    "interior psi hash and bitwise samples remain unchanged across projection; source edge arrays, source psi_boundary, rtol, atol, max_iterations, blend, and source/Jtor inputs remain unchanged",
    "final exact array_equal checks remain in the unchanged v2 postprocess; residual is recomputed from final projected psi and actual returned Jtor",
    "posthoc v11 raw/projected residual values are diagnostic discriminators only and are not acceptance targets; source-state and terminal residual gates remain unknown until measured",
    "actual Picard iteration count remains unknown unless directly reported; Equilibrium.solve invocation count is not a Picard iteration count",
    "solver convergence, source-state/terminal residual, and independent physical validation remain separate gates",
    "the observed-box corner is recorded only as a read-only diagnostic; the adapter never assigns it to eq.psi_bndry, which pinned FreeGS 0.8.2 picard.solve reads in bndry_relchange, so native Picard stopping behavior is preserved",
    "context entry and global restoration receipts are true only when the delegated main.__globals__ context was actually entered and exact original revision/validator objects were restored",
    "every mandatory execution/stdout/stderr/solver-output/adapter sidecar is bound to the exact same fresh archive output leaf and launcher result/endpoint paths",
    "any BaseException after receipt construction, including a failure before entering the delegated globals context, sets receipt status to runner_raised while all pre-context flags remain false",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def _same_path(left: str | Path, right: str | Path) -> bool:
    raw = str(left)
    components = raw.replace("/", "\\").split("\\")
    if not Path(raw).is_absolute() or any(part in {".", ".."} for part in components):
        return False
    return os.path.normcase(str(Path(raw).resolve())) == os.path.normcase(
        str(Path(right).resolve())
    )


def validate_mandatory_sidecar_binding(
    protocol: dict[str, Any], output_path: Path
) -> dict[str, str]:
    """Fail closed unless all declared result/evidence paths bind one leaf."""
    output_path = output_path.resolve()
    leaf = output_path.parent
    expected = {
        "solver_output": output_path,
        "execution": leaf / "execution.json",
        "stdout": leaf / "stdout.raw",
        "stderr": leaf / "stderr.raw",
        "adapter_receipt": leaf / "freegs_adapter_receipt_v15.json",
    }
    sidecars = protocol.get("mandatory_evidence_sidecars")
    _require(isinstance(sidecars, dict), "mandatory evidence sidecars are missing")
    _require(set(sidecars) == set(expected) | {"storage_rule"}, "mandatory evidence sidecars are incomplete or contain unbound paths")
    _require(sidecars.get("storage_rule") == EXPECTED_STORAGE_RULE, "mandatory evidence storage rule changed")

    step_list = protocol.get("steps")
    _require(isinstance(step_list, list) and len(step_list) == 1, "candidate must contain one result step")
    _require(_same_path(step_list[0].get("result_path", ""), output_path), "step result_path does not bind the solver output")
    endpoint = protocol.get("runtime_endpoint_join")
    _require(isinstance(endpoint, dict), "runtime endpoint join is missing")
    _require(_same_path(endpoint.get("solver_output", ""), output_path), "runtime endpoint solver_output does not bind the result")
    _require(_same_path(endpoint.get("output_leaf", ""), leaf), "runtime endpoint output_leaf does not bind the result parent")

    bound: dict[str, str] = {}
    for key, expected_path in expected.items():
        value = sidecars.get(key)
        _require(isinstance(value, str), f"mandatory sidecar path is missing: {key}")
        _require(_same_path(value, expected_path), f"mandatory sidecar path is not bound to the v15 output leaf: {key}")
        normalized = str(Path(value).resolve()).replace("\\", "/").lower()
        _require("/archive/" in normalized, f"mandatory sidecar must be under archive: {key}")
        _require(not Path(value).exists(), f"mandatory sidecar already exists: {key}")
        bound[key] = str(expected_path)
    endpoint_receipt = endpoint.get("adapter_receipt")
    _require(_same_path(endpoint_receipt or "", expected["adapter_receipt"]), "runtime endpoint adapter receipt path is not bound")
    _require(not leaf.exists(), "new v15 solver output leaf already exists")
    return bound


def validate_sealed_v12_review_ancestry(
    protocol: dict[str, Any], repository_root: Path
) -> dict[str, dict[str, str]]:
    ancestry = protocol.get("review_ancestry")
    _require(isinstance(ancestry, dict), "sealed v12 NO-GO review ancestry is missing")
    _require(ancestry.get("status") == "sealed_independent_v12_no_go", "sealed v12 NO-GO review ancestry status mismatch")
    resolved: dict[str, dict[str, str]] = {}
    for role, expected in EXPECTED_REVIEW_ANCESTRY.items():
        record = ancestry.get(role)
        _require(isinstance(record, dict), f"v12 review ancestry record is missing: {role}")
        _require(record.get("verdict") == "NO-GO", f"v12 ancestry verdict changed: {role}")
        resolved[role] = {}
        for kind in ("report", "manifest"):
            path_key = kind + "_path"
            hash_key = kind + "_sha256"
            relative = expected[path_key]
            _require(record.get(path_key) == relative, f"v12 review ancestry path changed: {role}/{kind}")
            expected_hash = expected[hash_key]
            _require(record.get(hash_key) == expected_hash, f"v12 review ancestry hash declaration changed: {role}/{kind}")
            evidence_path = Path(repository_root) / relative
            _require(evidence_path.is_file(), f"sealed v12 review evidence is missing: {relative}")
            actual_hash = sha256(evidence_path)
            _require(actual_hash == expected_hash, f"sealed v12 review evidence hash mismatch: {relative}")
            resolved[role][kind + "_sha256"] = actual_hash
    return resolved


def _pin_map(argv: list[str], separator: int) -> dict[str, str]:
    pins: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] != "--require-file-sha256":
            index += 1
            continue
        _require(index + 1 < separator, "truncated supervisor file pin")
        value = argv[index + 1]
        _require("=" in value, "malformed supervisor file pin")
        path_text, digest = value.rsplit("=", 1)
        _require(len(digest) == 64, "malformed supervisor SHA-256 digest")
        _require(path_text not in pins, f"duplicate supervisor file pin: {path_text}")
        pins[path_text] = digest.lower()
        index += 2
    return pins


def verify_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    _require(protocol.get("schema") == EXPECTED_SCHEMA, "candidate schema mismatch")
    _require(protocol.get("state") == "review_candidate_ungranted_not_dispatched", "candidate must be ungranted and undispatched")
    slot = protocol.get("root_resource_slot", {})
    _require(slot.get("required") is True and slot.get("granted") is False, "root resource slot must remain required and ungranted")
    _require(protocol.get("dependency_file_pin_count") == len(protocol.get("dependency_file_pins", [])), "dependency pin count mismatch")
    steps = protocol.get("steps")
    _require(isinstance(steps, list) and len(steps) == 1, "candidate must contain one bounded direct FreeGS step")
    step = steps[0]
    _require(step.get("name") == EXPECTED_STEP and step.get("order") == 1, "step identity/order mismatch")
    argv = step.get("launcher_argv_template")
    _require(isinstance(argv, list) and all(isinstance(item, str) for item in argv), "launcher argv must be a string array")
    _require(step.get("command_length_chars") == len(" ".join(argv)), "recorded launcher command length is stale")
    _require(argv.count("--") == 1, "launcher must have exactly one child separator")
    separator = argv.index("--")
    _require(argv[:separator].count("--name") == 1, "supervisor must provide exactly one run name")
    run_name_index = argv[:separator].index("--name")
    _require(
        run_name_index + 1 < separator
        and argv[run_name_index + 1] == "native-axisymmetric-v6-precontext-terminal-receipt-r15",
        "supervisor run name does not bind to the v15 candidate",
    )
    _require("--require-file-sha256" not in argv[separator + 1 :], "supervisor pin appears after child separator")
    pins = _pin_map(argv, separator)
    declared = {str(item["path"]): str(item["sha256"]).lower() for item in protocol["dependency_file_pins"]}
    _require(len(declared) == len(protocol["dependency_file_pins"]), "duplicate dependency file pins")
    _require(pins == declared, "launcher supervisor pins do not exactly match the declared dependency pin set")
    for path_text, digest in pins.items():
        pin_path = Path(path_text)
        _require(pin_path.is_file(), f"pinned supervisor dependency is missing: {path_text}")
        _require(sha256(pin_path) == digest, f"pinned supervisor dependency hash mismatch: {path_text}")

    child = argv[separator + 1 :]
    _require(len(child) >= 7, "child argv is incomplete")
    _require(Path(child[0]).is_file(), "FreeGS Python executable is missing")
    _require(child[1] == "-B", "child must disable Python bytecode writes")
    repo_root = protocol.get("repository_root")
    expected_runner = Path(repo_root) / "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v6.py"
    _require(Path(child[2]).resolve() == expected_runner.resolve(), "child runner path is not v6")
    _require(pins.get(str(expected_runner)) == sha256(expected_runner), "v6 runner is not supervisor-pinned")
    for option in ("--input", "--source", "--output"):
        _require(child.count(option) == 1, f"child argv requires exactly one {option}")
    values: dict[str, str] = {}
    index = 3
    while index < len(child):
        if child[index].startswith("--"):
            _require(index + 1 < len(child), f"child argv option has no value: {child[index]}")
            values[child[index]] = child[index + 1]
            index += 2
        else:
            index += 1
    input_path = Path(values["--input"])
    source_path = Path(values["--source"])
    output_path = Path(values["--output"])
    _require(sha256(input_path) == EXPECTED_INPUT_SHA256, "frozen v10 solver input hash mismatch")
    _require(sha256(source_path) == EXPECTED_SOURCE_SHA256, "frozen source snapshot hash mismatch")
    input_doc = json.loads(input_path.read_text(encoding="utf-8"))
    _require(input_doc.get("revision") == EXPECTED_BASELINE_REVISION, "input revision is not frozen v2")
    _require(input_doc.get("controls") == EXPECTED_CONTROLS, "v10 solver controls changed")
    _require("/archive/" in str(output_path).replace("\\", "/").lower(), "solver output must be in archive")
    _require(not output_path.parent.exists(), "new v15 solver output leaf already exists")
    _require("--require-absent-path" in argv[:separator], "supervisor absent-path guard is missing")
    absent = argv.index("--require-absent-path")
    _require(absent + 1 < separator and Path(argv[absent + 1]).resolve() == output_path.parent.resolve(), "absent-path guard does not match v15 output leaf")

    mandatory_sidecars = validate_mandatory_sidecar_binding(protocol, output_path)
    supervisor_values: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] in {"--receipt", "--stdout", "--stderr"}:
            _require(index + 1 < separator, f"supervisor output option has no value: {argv[index]}")
            supervisor_values[argv[index]] = argv[index + 1]
            index += 2
        else:
            index += 1
    _require(_same_path(supervisor_values.get("--receipt", ""), mandatory_sidecars["execution"]), "launcher execution receipt is not bound to mandatory sidecar")
    _require(_same_path(supervisor_values.get("--stdout", ""), mandatory_sidecars["stdout"]), "launcher stdout is not bound to mandatory sidecar")
    _require(_same_path(supervisor_values.get("--stderr", ""), mandatory_sidecars["stderr"]), "launcher stderr is not bound to mandatory sidecar")

    adapter = protocol.get("v6_runner", {})
    _require(adapter.get("runner_revision") == EXPECTED_REVISION_V6, "v6 runner revision mismatch")
    _require(adapter.get("candidate_scope") == "pre-context terminal receipt status only; no solver, numerical, physical-boundary, or residual-control change", "v15 candidate scope changed")
    _require(adapter.get("revision_binding") == "delegated main.__globals__; not the distinct runpy namespace", "runner identity binding description changed")
    _require(
        adapter.get("numerical_effect")
        == "test-only exact four-edge reprojection plus read-only observed-box corner diagnostic before original pinned FreeGS updates; never writes eq.psi_bndry; no interior/source/control/postprocess exact-gate change",
        "v5 adapter numerical effect is misstated",
    )
    for key, relative in (
        ("adapter", "tools/up4_reference_validation/freegs_observed_dirichlet_boundary_v3.py"),
        ("runner", "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v6.py"),
        ("test", "test/UP4ReferenceValidationV1/test_freegs_observed_dirichlet_boundary_v4.py"),
        ("static_verifier", "tools/up4_reference_validation/verify_freegs_v6_protocol_candidate.py"),
    ):
        file_path = Path(repo_root) / relative
        _require(adapter.get(key) == relative, f"protocol {key} path mismatch")
        _require(adapter.get(key + "_sha256") == sha256(file_path), f"protocol {key} SHA mismatch")
        _require(pins.get(str(file_path)) == sha256(file_path), f"{key} is not in supervisor pins")

    runner_text = expected_runner.read_text(encoding="utf-8")
    _require('"runtime-v4-freegs-axisymmetric-profile-execution-v6-"' in runner_text and '"precontext-terminal-receipt"' in runner_text, "v6 runner source revision identity mismatch")
    _require('receipt["status"] = "runner_raised"' in runner_text, "v6 runner lacks unconditional terminal receipt status")
    _require('receipt.setdefault("status", "runner_raised")' not in runner_text, "v6 runner retains the pre-context setdefault defect")
    test_path = Path(repo_root) / "test/UP4ReferenceValidationV1/test_freegs_observed_dirichlet_boundary_v4.py"
    test_text = test_path.read_text(encoding="utf-8")
    _require("test_v15_precontext_failure_is_terminal_and_does_not_claim_restore" in test_text, "v15 terminal failure-path test is missing")
    _require("test_v13_precontext_negative_control_retains_started_status" in test_text, "frozen v13 negative control is missing")
    runner_record = adapter.get("v13_negative_control", {})
    legacy_runner = Path(repo_root) / "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v5.py"
    _require(runner_record.get("runner") == "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v5.py", "v13 negative-control path changed")
    _require(runner_record.get("runner_sha256") == EXPECTED_V13_RUNNER_SHA256, "v13 negative-control source hash declaration changed")
    _require(sha256(legacy_runner) == EXPECTED_V13_RUNNER_SHA256, "frozen v13 negative-control source changed")
    _require(pins.get(str(legacy_runner)) == EXPECTED_V13_RUNNER_SHA256, "frozen v13 runner is not supervisor-pinned as a negative control")
    _require(runner_record.get("expected_precontext_status") == "started", "v13 negative-control expected failure state changed")
    _require(runner_record.get("precontext_flags") == {
        "globals_context_entered": False,
        "globals_context_restore_attempted": False,
        "globals_restored_after_context": False,
        "globals_restore_exact": False,
    }, "v13 negative-control context flags changed")

    projection = protocol.get("edge_projection_guard", {})
    _require(projection.get("max_preprojection_delta_wb_per_rad") == MAX_PREPROJECT_DELTA, "roundoff cap differs")
    _require(projection.get("classification") == "test_only_adapter_roundoff_guard_not_scientific_acceptance_threshold", "roundoff cap is mislabeled")
    _require(projection.get("v11_measured_max_per_edge_wb_per_rad") == {
        "r_min": 7.26486579227803e-13,
        "r_max": 8.417589542064619e-13,
        "z_min": 4.521296531612151e-13,
        "z_max": 2.381705943577117e-13,
    }, "v11 evidence basis for the cap changed")
    residual = protocol.get("residual_discriminator", {})
    _require(residual.get("acceptance_threshold") == "not_defined", "a residual acceptance threshold was introduced")
    _require(residual.get("must_recompute_from_final_projected_psi") is True, "final projected psi residual recomputation is not required")
    _require(residual.get("posthoc_v11_raw_l2_relative") == 0.002502303376492294, "v11 raw residual discriminator changed")
    _require(residual.get("posthoc_v11_projected_l2_relative") == 0.0025023033765812527, "v11 projected residual discriminator changed")
    postconditions = step.get("postconditions", [])
    for required in REQUIRED_POSTCONDITIONS:
        _require(required in postconditions, f"required v15 postcondition missing: {required}")
    scope = protocol.get("scope", {})
    semantics = scope.get("boundary_convergence_semantics", "")
    _require(
        "observed-box" in semantics
        and "read-only diagnostic" in semantics
        and "never written to eq.psi_bndry" in semantics
        and "native Picard stopping behavior is preserved" in semantics
        and "not separatrix/physical plasma boundary flux" in semantics
        and "no physics credit" in semantics,
        "corner diagnostic semantics do not truthfully describe native Picard stopping behavior",
    )
    review_ancestry = validate_sealed_v12_review_ancestry(protocol, Path(repo_root))
    prior_candidate_ancestry = validate_prior_candidate_no_go_ancestry(protocol, Path(repo_root))
    _require(protocol.get("runtime_execution_authorized") is False, "static candidate must not claim runtime authorization")

    return {
        "status": "static_protocol_check_pass",
        "schema": protocol["schema"],
        "state": protocol["state"],
        "protocol_sha256": sha256(protocol_path),
        "launcher_pin_count": len(pins),
        "dependency_pin_count": len(declared),
        "all_supervisor_pins_rehashed": True,
        "child_argv_binding_valid": True,
        "solver_input_sha256": sha256(input_path),
        "source_snapshot_sha256": sha256(source_path),
        "root_resource_slot_granted": slot["granted"],
        "solver_output_leaf_exists": output_path.parent.exists(),
        "mandatory_sidecars_bound": mandatory_sidecars,
        "sealed_v12_review_ancestry": review_ancestry,
        "prior_v13_v14_no_go_ancestry": prior_candidate_ancestry,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify_candidate(args.protocol), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
