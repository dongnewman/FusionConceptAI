"""Independent byte and stage-semantics audit for a completed spatial run."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path


def digest_value(value):
    return value["value"] if isinstance(value, dict) else value


def file_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: verify_v4_spatial_manifest.py RUN_DIR REPORT_JSON")
    run_dir = Path(sys.argv[1]).resolve()
    report_path = Path(sys.argv[2]).resolve()
    manifest = json.loads((run_dir / "execution_manifest.json").read_text(encoding="utf-8"))
    whole = json.loads((run_dir / "result.json").read_text(encoding="utf-8"))
    physics = json.loads((run_dir / "physics.json").read_text(encoding="utf-8"))
    engineering = json.loads((run_dir / "engineering.json").read_text(encoding="utf-8"))
    verification = json.loads((run_dir / "verification.json").read_text(encoding="utf-8"))
    records = [manifest[key] for key in (
        "julia_executable", "project", "manifest", "environment", "execution_ledger")]
    records += manifest["sources"] + manifest["artifacts"]
    mismatches = []
    seen = {}
    for record in records:
        path = Path(record["path"]).resolve()
        expected = digest_value(record["sha256"])
        actual = file_digest(path) if path.is_file() else None
        if str(path) in seen and seen[str(path)] != expected:
            mismatches.append({"path": str(path), "reason": "conflicting expected hashes"})
        seen[str(path)] = expected
        if actual != expected:
            mismatches.append({"path": str(path), "expected": expected, "actual": actual})
    identity_ok = all(
        manifest[key] == value[key]
        for value in (whole, physics, engineering, verification)
        for key in ("candidate_hash", "context_hash")
    )
    result_hash_value = digest_value(manifest["result_hash"])
    result_hash_present = len(result_hash_value) == 64 and all(
        char in "0123456789abcdef" for char in result_hash_value)
    result_path = str((run_dir / "result.json").resolve())
    result_artifact_bound = result_path in seen and not any(
        mismatch.get("path") == result_path for mismatch in mismatches)
    process_ok = (
        (run_dir / "runner.exit").read_text(encoding="utf-8").strip() == "0"
        and manifest["process_exit_code"] == 0
        and manifest["physical_solver_exit_code"] == physics["solver_exit_code"]
        and manifest["engineering_solver_exit_code"] == engineering["solver_exit_code"]
        and manifest["verification_exit_code"] == verification["solver_exit_code"]
    )
    case_ids = [case["case_id"] for case in physics["cases"]]
    scenario_ok = case_ids == [
        "nominal_coarse", "nominal_fine", "flux_low_coarse", "flux_high_coarse"
    ] and [case["case_id"] for case in engineering["cases"]] == case_ids
    authority_ok = (
        whole["status"] == "deferred"
        and whole["physical_validation"] == "unsupported"
        and not whole["p5_ready"]
        and whole["credible_device_count"] == 0
        and not manifest["p5_ready"]
        and manifest["credible_device_count"] == 0
    )
    events = [json.loads(line) for line in (run_dir / "execution_ledger.jsonl").read_text(
        encoding="utf-8").splitlines() if line]
    latest = {}
    for event in events:
        latest[event["stage"]] = event
    ledger_ok = all(
        latest[name]["execution_state"] == "completed"
        for name in ("candidate", "upstream_DESC", "physics", "engineering",
                     "verification", "whole", "manifest")
    ) and any(
        event["stage"] == "whole" and event["classification"] == "program_exception"
        for event in events
    )
    initial_head_ok = manifest["starting_head"] == (
        run_dir / "initial_head.txt").read_text(encoding="utf-8").strip()
    ok = (not mismatches and identity_ok and result_hash_present and result_artifact_bound
          and process_ok and scenario_ok and authority_ok and ledger_ok and initial_head_ok)
    report = {
        "status": "pass" if ok else "fail",
        "records_checked": len(records),
        "unique_paths_checked": len(seen),
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
        "identity_ok": identity_ok,
        "manifest_result_hash_present": result_hash_present,
        "result_json_bytes_bound": result_artifact_bound,
        "process_exit_semantics_ok": process_ok,
        "four_scenarios_ok": scenario_ok,
        "authority_ceiling_ok": authority_ok,
        "ledger_recovery_history_ok": ledger_ok,
        "initial_head_ok": initial_head_ok,
        "program_exception_events": sum(e["classification"] == "program_exception" for e in events),
        "human_interruption_events": sum(e["classification"] == "human_interruption" for e in events),
        "scope": "independent file-byte and stage-semantics audit; not physical validation",
    }
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
