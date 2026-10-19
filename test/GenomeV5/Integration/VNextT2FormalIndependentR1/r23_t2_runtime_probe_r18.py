from __future__ import annotations

import json
import os
import sys
import types
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
CONTROLLER = Path(__file__).resolve().with_name("independent_negative_controller_r18.py")


def main() -> int:
    root_output = Path(sys.argv[1]).resolve()
    source = CONTROLLER.read_bytes()
    module = types.ModuleType("t2_controller_r18_runtime_probe")
    module.__file__ = str(CONTROLLER)
    exec(compile(source, str(CONTROLLER), "exec"), module.__dict__)
    natural_output = root_output / "natural_python_child"
    natural_child = [sys.executable, "-B", "-c", "import time; time.sleep(0.8)"]
    original_native_sample = module._r23_native_sample
    terminal_race_fixture = {
        "schema": "vnext-t2-r18-terminal-race-scheduling-fixture-r1",
        "second_sample_hook_entered": False,
        "child_wait_natural_exit_code": None,
        "original_native_sampler_called_after_wait": False,
        "sampler_replaced_only_for_natural_phase": True,
    }

    def wait_inside_first_natural_sample(process, registry, root_identity,
                                         previous, *, sample_index, elapsed):
        if sample_index == 2:
            terminal_race_fixture["second_sample_hook_entered"] = True
            exit_code = process.wait(timeout=3.0)
            terminal_race_fixture["child_wait_natural_exit_code"] = exit_code
            terminal_race_fixture["original_native_sampler_called_after_wait"] = True
        return original_native_sample(
            process, registry, root_identity, previous,
            sample_index=sample_index, elapsed=elapsed)

    module._r23_native_sample = wait_inside_first_natural_sample
    natural = module.run_phase(
        "r23_exact_python_child_probe", natural_child, natural_output,
        timeout_seconds=10.0,
        working_set_limit_bytes=2_147_483_648,
        environment=os.environ.copy())
    module._r23_native_sample = original_native_sample
    timeout_output = root_output / "timed_python_child"
    timeout_child = [sys.executable, "-B", "-c", "import time; time.sleep(10)"]
    timed = module.run_phase(
        "r23_exact_python_timeout_probe", timeout_child, timeout_output,
        timeout_seconds=1.0,
        working_set_limit_bytes=2_147_483_648,
        environment=os.environ.copy())
    payload = {
        "schema": "vnext-t2-r23-runtime-probe-r1",
        "controller": module.file_receipt(CONTROLLER),
        "terminal_race_fixture": terminal_race_fixture,
        "natural_phase": natural,
        "timeout_phase": timed,
        "formal_t2_accepted": False,
        "julia_started": False,
    }
    print(json.dumps(payload, sort_keys=True), flush=True)
    try:
        module.require_natural(natural, exit_zero=True)
        if timed.get("stop_reason") != "phase_wall_timeout" or \
                timed.get("termination_receipt", {}).get("verified") is not True or \
                timed.get("final_process_tree_audit", {}).get("complete") is not True or \
                timed.get("final_process_tree_audit", {}).get(
                    "residual_descendant_processes"):
            raise RuntimeError("timeout child exact termination/audit did not remain partial and complete")
    except Exception as error:
        print(json.dumps({"probe_assertion": "fail",
                          "type": type(error).__name__, "message": str(error)},
                         sort_keys=True), flush=True)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
