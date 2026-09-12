"""Build compact delivery evidence from completed real-run and regression files."""
import hashlib
import json
import re
import sys
from pathlib import Path


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def record(path):
    path = Path(path).resolve()
    return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def main(run, checks, output):
    run, checks = Path(run).resolve(), Path(checks).resolve()
    manifest = read(run / "execution_manifest.json")
    final = read(run / "result.json")
    physics = read(run / "physics.json")
    engineering = read(run / "engineering.json")
    verification = read(run / "verification.json")
    audit = read(run / "independent_manifest_audit.json")
    decimal = read(run / "verification/decimal_audit.json")
    assert int((run / "runner.exit").read_text()) == 0
    assert audit["exit_code"] == 0 and audit["mismatch_count"] == 0
    assert int((run / "verification/decimal_audit.exitcode").read_text()) == 0
    assert all(x["candidate_hash"] == manifest["candidate_hash"] and
               x["context_hash"] == manifest["context_hash"]
               for x in (final, physics, engineering, verification))
    assert physics["executed"] and engineering["executed"] and verification["executed"]
    assert tuple(s["fault"] for s in engineering["scenarios"]) == ("none", "load_short")
    regressions = {}
    for name in ("physics", "engineering", "verification", "graphs", "core", "spine", "package"):
        exit_path, log = checks / (name + ".exit"), checks / (name + ".log")
        assert int(exit_path.read_text()) == 0
        groups = re.findall(r"\|\s+(\d+)\s+(\d+)\s+[\d.]+(?:s|m)", log.read_text(encoding="utf-8-sig"))
        regressions[name] = {"exit_code": 0, "reported_groups": len(groups),
                             "passes": sum(int(a) for a, _ in groups),
                             "tests": sum(int(b) for _, b in groups), "log": record(log),
                             "exit": record(exit_path)}
    assert int((checks / "queue.exit").read_text()) == 0
    integration_log = checks.parent / "unified_r3.log"
    assert "REVISED_INTEGRATION_TESTS_EXIT_CODE=0" in integration_log.read_text(encoding="utf-8-sig")
    numeric_engineering = {k: v for k, v in verification["numerical"]["engineering"].items()
                           if k != "fine_response"}
    result = {
        "scope": "completed declared reduced execution, not full-field MHD or physical validation",
        "candidate_hash": manifest["candidate_hash"], "context_hash": manifest["context_hash"],
        "starting_head": manifest["starting_head"], "manifest": record(run / "execution_manifest.json"),
        "runner_exit_code": 0, "integration_log": record(integration_log), "regressions": regressions,
        "independent_manifest_audit": audit, "decimal_audit": record(run / "verification/decimal_audit.json"),
        "stage_status": [{k: v for k, v in s.items() if k not in ("metrics",)} for s in final["stages"]],
        "physics": {k: physics[k] for k in ("status", "solver_exit_code", "initial_state", "final_state",
                                           "iterations", "stopping_reason", "execution", "diagnostics")},
        "engineering": {"status": engineering["status"], "solver_exit_code": engineering["solver_exit_code"],
                        "upstream_valid": engineering["upstream_valid"],
                        "applicability_status": engineering["applicability_status"],
                        "B_projected_T": engineering["B_projected_T"],
                        "scenarios": [{"fault": s["fault"], "metrics": s["metrics"]}
                                      for s in engineering["scenarios"]]},
        "numerical": {"status": verification["status"], "solver_exit_code": verification["solver_exit_code"],
                      "physics": verification["numerical"]["physics"], "engineering": numeric_engineering},
        "sensitivity": {"method": verification["propagation"]["method"],
                        "case_count": verification["propagation"]["case_count"],
                        "ranges": verification["propagation"]["ranges"],
                        "coupled_pressure": verification["propagation"]["coupled_pressure_sensitivity"],
                        "distribution": verification["propagation"]["distribution"]},
        "constrained_solver_diagnostic": decimal["constrained_solver_audit"],
        "whole_status": final["status"], "full_function_space_mhd_solved": False,
        "physical_validation": "unsupported", "p5_ready": False, "credible_device_count": 0,
    }
    Path(output).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": record(output), "exit_code": 0, "regressions": regressions}))


if __name__ == "__main__":
    main(*sys.argv[1:])
