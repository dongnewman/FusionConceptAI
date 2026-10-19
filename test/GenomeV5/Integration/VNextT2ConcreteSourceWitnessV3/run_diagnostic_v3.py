"""Record one bounded direct baseline validate/build diagnostic."""

from __future__ import annotations

from pathlib import Path
import argparse
import json
import os

import run_recorded_v3 as runtime


DIAGNOSTIC = Path(__file__).with_name("diagnose_baseline_build.jl")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--julia", default="julia")
    args = parser.parse_args()
    output = (runtime.ROOT / args.out).resolve()
    output.relative_to(runtime.EVIDENCE_ROOT)
    if runtime.heavy_processes():
        raise RuntimeError("serialized heavy lane occupied: " +
                           json.dumps(runtime.heavy_processes()))
    output.mkdir(parents=True, exist_ok=False)

    dependencies_before = runtime.dependency_receipts()
    diagnostic_relative = DIAGNOSTIC.resolve().relative_to(
        runtime.ROOT.resolve()).as_posix()
    dependencies_before[diagnostic_relative] = runtime.receipt(DIAGNOSTIC)
    environment = os.environ.copy()
    environment["JULIA_NUM_THREADS"] = "1"
    command = [args.julia, "--startup-file=no", "--project=.",
               diagnostic_relative]
    result = runtime.run_step(output, 1, "baseline_build_diagnostic",
        command, dependencies_before, runtime.DEFAULT_TIMEOUT_SECONDS,
        runtime.DEFAULT_PROCESS_TREE_RSS_BYTES, environment)

    dependencies_after = runtime.dependency_receipts()
    dependencies_after[diagnostic_relative] = runtime.receipt(DIAGNOSTIC)
    changes = sorted(
        set(dependencies_before) ^ set(dependencies_after) |
        {path for path in set(dependencies_before) & set(dependencies_after)
         if dependencies_before[path] != dependencies_after[path]}
    )
    residual = runtime.heavy_processes()
    stdout = (output / "01_baseline_build_diagnostic/stdout.raw").read_text(
        encoding="utf-8", errors="replace")
    captured = "diagnostic_exception_captured=true" in stdout
    status = ("passed" if result["exit_code"] == 0 and
              result["stop_reason"] == "natural_exit" and captured and
              not changes and not residual else "failed")
    final = {
        "schema": "vnext_t2_source_witness_v3_diagnostic_v1",
        "status": status,
        "stage": result,
        "dependencies_before": dependencies_before,
        "dependencies_after": dependencies_after,
        "input_changes": changes,
        "residual_heavy_processes": residual,
        "formal_consumer_count": 0,
    }
    runtime.write_new(output / "diagnostic_final.json", final)
    print(json.dumps(final, sort_keys=True), flush=True)
    return 0 if status == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
