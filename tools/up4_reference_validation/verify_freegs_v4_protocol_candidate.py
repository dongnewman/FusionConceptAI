#!/usr/bin/env python3
"""Python-only preflight for the ungranted FreeGS v12 protocol candidate.

This verifier does not import FreeGS, launch Julia, or start a solver. It
rehashes every supervisor pin and proves the full child argv/input/output
binding before a later root-controlled resource grant.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


EXPECTED_SCHEMA = (
    "fusionconceptai:native-axisymmetric-forward-observed-box-edge-"
    "reprojection-review-candidate-v12"
)
EXPECTED_STEP = (
    "direct_actual_freegs_fixed_observed_box_boundary_edge_reprojection_v4_r12"
)
EXPECTED_INPUT_SHA256 = "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"
EXPECTED_SOURCE_SHA256 = "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac"
EXPECTED_BASELINE_SHA256 = "3fbc8262ea9e6ab58e06892349bc3640e36d88f2985d950cc386b511e6e3b4ec"
EXPECTED_REVISION = "runtime-v4-freegs-axisymmetric-profile-execution-v4-observed-box-boundary-edge-reprojection"
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
REQUIRED_POSTCONDITIONS = (
    "projection occurs only before original FreeGS _updatePlasmaPsi for the exact marked target callback and same source-derived grid; original method is called afterward to update spline/critical metadata",
    "all four frozen source edges are corner-compatible and are restored exactly only when every preprojection per-sample delta is <= 1e-12 Wb/rad; any larger delta aborts before projection",
    "the 1e-12 Wb/rad cap is a test-only roundoff guard based solely on v11 same-grid FreeGS 0.8.2 measurements, not a solver, residual, or physics acceptance threshold",
    "interior psi hash and bitwise samples remain unchanged across projection; source edge arrays, source psi_boundary, rtol, atol, max_iterations, blend, and source/Jtor inputs remain unchanged",
    "final exact array_equal checks remain in the unchanged v2 postprocess; residual is recomputed from final projected psi and actual returned Jtor",
    "posthoc v11 raw/projected residual values are diagnostic discriminators only and are not acceptance targets; source-state and terminal residual gates remain unknown until measured",
    "actual Picard iteration count remains unknown unless directly reported; Equilibrium.solve invocation count is not a Picard iteration count",
    "solver convergence, source-state/terminal residual, and independent physical validation remain separate gates",
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


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
    expected_runner = Path(repo_root) / "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v4.py"
    _require(Path(child[2]).resolve() == expected_runner.resolve(), "child runner path is not v4")
    _require(pins.get(str(expected_runner)) == sha256(expected_runner), "v4 runner is not supervisor-pinned")
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
    _require(not output_path.parent.exists(), "new v12 solver output leaf already exists")
    _require("--require-absent-path" in argv[:separator], "supervisor absent-path guard is missing")
    absent = argv.index("--require-absent-path")
    _require(absent + 1 < separator and Path(argv[absent + 1]).resolve() == output_path.parent.resolve(), "absent-path guard does not match v12 output leaf")

    adapter_receipt = protocol.get("mandatory_evidence_sidecars", {}).get("adapter_receipt")
    expected_receipt = output_path.parent / "freegs_adapter_receipt_v12.json"
    _require(adapter_receipt == str(expected_receipt), "adapter receipt sidecar is not bound to the solver output leaf")
    _require(not expected_receipt.exists(), "v12 adapter receipt path already exists")

    adapter = protocol.get("v4_adapter", {})
    for key, relative in (
        ("adapter", "tools/up4_reference_validation/freegs_observed_dirichlet_boundary_v2.py"),
        ("runner", "tools/up4_reference_validation/runtime_v4_freegs_axisymmetric_profile_runner_v4.py"),
        ("test", "test/UP4ReferenceValidationV1/test_freegs_observed_dirichlet_boundary_v2.py"),
        ("static_verifier", "tools/up4_reference_validation/verify_freegs_v4_protocol_candidate.py"),
    ):
        file_path = Path(repo_root) / relative
        _require(adapter.get(key) == relative, f"protocol {key} path mismatch")
        _require(adapter.get(key + "_sha256") == sha256(file_path), f"protocol {key} SHA mismatch")
        _require(pins.get(str(file_path)) == sha256(file_path), f"{key} is not in supervisor pins")

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
        _require(required in postconditions, f"required v12 postcondition missing: {required}")
    scope = protocol.get("scope", {})
    _require("observed-box" in scope.get("boundary_convergence_semantics", "") and "not separatrix/physical plasma boundary flux" in scope.get("boundary_convergence_semantics", ""), "proxy label exceeds its metadata-only meaning")
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
        "adapter_receipt_path": str(expected_receipt),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    args = parser.parse_args()
    print(json.dumps(verify_candidate(args.protocol), sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
