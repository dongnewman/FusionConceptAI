#!/usr/bin/env python3
"""Read-only structural verifier for the ungranted FreeGS v3 candidate."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


EXPECTED_SCHEMA = (
    "fusionconceptai:native-axisymmetric-forward-observed-box-"
    "boundary-proxy-review-candidate-v11"
)
EXPECTED_STEP = "direct_actual_freegs_fixed_observed_box_boundary_proxy_solve_v3_r11"
EXPECTED_INPUT_SHA256 = "0ea833fd717c313a2f5d1c562ccbb78a3dc5efc1f4a4679bd454b1b1a918f447"
EXPECTED_SOURCE_SHA256 = "fe7e3cf247cd9d0f0c58a9d3926899ec0b34323ac839992b61003085ebd738ac"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_candidate(protocol_path: Path) -> dict[str, Any]:
    protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    if protocol.get("schema") != EXPECTED_SCHEMA:
        raise ValueError("candidate schema mismatch")
    if protocol.get("state") != "review_candidate_ungranted_not_dispatched":
        raise ValueError("candidate is not marked ungranted and undispatched")
    slot = protocol.get("root_resource_slot", {})
    if slot.get("granted") is not False or slot.get("required") is not True:
        raise ValueError("root resource slot must remain required and ungranted")

    steps = protocol.get("steps")
    if not isinstance(steps, list) or len(steps) != 1:
        raise ValueError("candidate must contain exactly one direct FreeGS step")
    step = steps[0]
    if step.get("name") != EXPECTED_STEP or step.get("order") != 1:
        raise ValueError("candidate step identity/order mismatch")
    argv = step.get("launcher_argv_template")
    if not isinstance(argv, list) or not all(isinstance(item, str) for item in argv):
        raise ValueError("launcher argv is not a string array")
    if step.get("command_length_chars") != len(" ".join(argv)):
        raise ValueError("recorded launcher command length is stale")
    if argv.count("--") != 1:
        raise ValueError("launcher must contain exactly one child separator")
    separator = argv.index("--")
    if "--require-file-sha256" in argv[separator + 1 :]:
        raise ValueError("a supervisor file pin appears after the child separator")

    supervisor_pins: dict[str, str] = {}
    index = 0
    while index < separator:
        if argv[index] == "--require-file-sha256":
            if index + 1 >= separator or "=" not in argv[index + 1]:
                raise ValueError("malformed supervisor SHA-256 pin")
            path_text, digest = argv[index + 1].rsplit("=", 1)
            if len(digest) != 64 or path_text in supervisor_pins:
                raise ValueError("invalid or duplicate supervisor SHA-256 pin")
            supervisor_pins[path_text] = digest.lower()
            index += 2
        else:
            index += 1

    declared_count = protocol.get("dependency_file_pin_count")
    dependency_pins = protocol.get("dependency_file_pins")
    if not isinstance(dependency_pins, list) or declared_count != len(dependency_pins):
        raise ValueError("dependency pin count does not match its list")
    for pin in dependency_pins:
        pin_path = Path(pin["path"])
        digest = str(pin["sha256"]).lower()
        if supervisor_pins.get(str(pin_path)) != digest:
            raise ValueError(f"dependency pin is absent from launcher: {pin_path}")
        if not pin_path.is_file() or sha256(pin_path) != digest:
            raise ValueError(f"dependency pin does not match current file bytes: {pin_path}")
    for path_text, digest in supervisor_pins.items():
        pin_path = Path(path_text)
        if not pin_path.is_file() or sha256(pin_path) != digest:
            raise ValueError(f"supervisor pin does not match current file bytes: {pin_path}")

    child_argv = argv[separator + 1 :]
    if len(child_argv) < 4 or Path(child_argv[2]).name != "runtime_v4_freegs_axisymmetric_profile_runner_v3.py":
        raise ValueError("child runner is not the versioned v3 runner")
    for option in ("--input", "--source", "--output"):
        if child_argv.count(option) != 1:
            raise ValueError(f"child argv must contain exactly one {option}")
    child_option = {child_argv[i]: child_argv[i + 1] for i in range(len(child_argv) - 1) if child_argv[i].startswith("--")}
    input_path = Path(child_option["--input"])
    source_path = Path(child_option["--source"])
    output_path = Path(child_option["--output"])
    if sha256(input_path) != EXPECTED_INPUT_SHA256:
        raise ValueError("reused v10 solver input hash mismatch")
    if sha256(source_path) != EXPECTED_SOURCE_SHA256:
        raise ValueError("reused v10 source snapshot hash mismatch")
    input_document = json.loads(input_path.read_text(encoding="utf-8"))
    if input_document.get("revision") != "runtime-v4-freegs-axisymmetric-profile-execution-v2":
        raise ValueError("frozen v2 input revision was changed")
    if input_document.get("controls") != {
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
    }:
        raise ValueError("frozen v10 numerical controls differ from requested values")
    if str(output_path).replace("\\", "/").lower().find("/archive/") < 0:
        raise ValueError("solver output is outside the evidence archive")
    if output_path.parent.exists():
        raise ValueError("new solver evidence leaf already exists")
    if "--require-absent-path" not in argv[:separator]:
        raise ValueError("supervisor absent-path guard is missing")
    absent_index = argv.index("--require-absent-path")
    if absent_index + 1 >= separator or argv[absent_index + 1] != str(output_path.parent):
        raise ValueError("supervisor absent-path guard does not match the new output leaf")

    adapter = protocol.get("v3_adapter", {})
    if adapter.get("status") != "review_candidate_ungranted_not_dispatched":
        raise ValueError("adapter metadata does not preserve ungranted state")
    semantics = " ".join(
        [str(protocol.get("scope", {}).get("boundary_convergence_semantics", ""))]
        + [str(item) for item in step.get("postconditions", [])]
    ).lower()
    if "observed-box" not in semantics or "physical plasma boundary" not in semantics:
        raise ValueError("proxy labeling/physical boundary distinction is missing")
    if EXPECTED_INPUT_SHA256 not in str(step.get("dynamic_binding", {})):
        raise ValueError("frozen solver input hash is not declared in dynamic binding")
    if EXPECTED_SOURCE_SHA256 not in str(step.get("dynamic_binding", {})):
        raise ValueError("frozen source snapshot hash is not declared in dynamic binding")
    if "actual completed iterations remain unknown" not in str(step.get("dynamic_binding", {})):
        raise ValueError("requested max iteration limit is being confused with observed count")

    return {
        "candidate_state": protocol["state"],
        "dependency_pin_count": declared_count,
        "launcher_pin_count": len(supervisor_pins),
        "step": step["name"],
        "solver_output_exists": output_path.parent.exists(),
        "root_resource_slot_granted": slot["granted"],
        "protocol_path": str(protocol_path),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("protocol", type=Path)
    arguments = parser.parse_args()
    result = verify_candidate(arguments.protocol)
    print(json.dumps({"status": "static_protocol_check_pass", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
