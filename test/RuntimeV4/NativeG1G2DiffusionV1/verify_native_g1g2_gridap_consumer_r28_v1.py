"""Static-only verifier for the frozen R28 consumer protocol; never runs Julia."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import run_native_g1g2_gridap_consumer_r28_v1 as r28


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    args = parser.parse_args()
    protocol_path = Path(args.protocol).resolve()
    protocol = r28.load_protocol(protocol_path)
    r28.validate_protocol_shape(protocol)
    observed = list(getattr(sys, "orig_argv", []))
    if not observed:
        observed = [sys.executable, *sys.argv]
    r28.validate_invocation("static_verifier", observed, protocol)
    pins = r28.verify_input_pins(protocol)
    julia = protocol["execution_plan"]["julia_executable"]
    julia_path = Path(julia["path"])
    if not julia_path.is_file():
        raise r28.PreflightError("pinned Julia executable is unavailable")
    julia_receipt = r28.file_receipt(julia_path)
    if julia_receipt["bytes"] != julia["bytes"] or julia_receipt["sha256"] != julia["sha256"]:
        raise r28.PreflightError("pinned Julia executable hash mismatch")
    interpreter = protocol["invocation_contract"]["python_interpreter"]
    python_receipt = r28.file_receipt(Path(interpreter["path"]))
    if python_receipt["bytes"] != interpreter["bytes"] or python_receipt["sha256"] != interpreter["sha256"]:
        raise r28.PreflightError("pinned Python interpreter hash mismatch")
    output = r28.repo_path(protocol["planned_output_leaf"])
    if output.exists():
        raise r28.PreflightError("planned runtime output leaf is not fresh")
    commands = r28.planned_stage_commands(protocol, output)
    if [x["stage"] for x in commands] != protocol["execution_plan"]["stage_order"]:
        raise r28.PreflightError("planned command stage order mismatch")
    for stage, command in zip(commands, protocol["execution_plan"]["stage_commands"]):
        if stage != command:
            raise r28.PreflightError(f"planned command drift in stage {stage['stage']}")
    print(json.dumps({
        "status": "static_protocol_check_pass",
        "runtime_executed": False,
        "julia_started": False,
        "input_pin_count": pins["checked_count"],
        "stage_order": protocol["execution_plan"]["stage_order"],
        "planned_argv_verified": True,
        "runtime_output_leaf_absent": True,
        "resource_contract": protocol["limits"],
        "numerical_credit": False,
        "physical_credit": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except r28.PreflightError as exc:
        print(json.dumps({"status": "static_protocol_check_fail", "runtime_executed": False,
                          "error": str(exc), **r28.NO_CREDIT}, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)
