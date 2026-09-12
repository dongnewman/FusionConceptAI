"""Independent byte-level audit of the unified revised run, using Python stdlib."""
import hashlib
import json
import sys
from pathlib import Path


def main():
    run_dir = Path(sys.argv[1]).resolve()
    manifest = json.loads((run_dir / "execution_manifest.json").read_text(encoding="utf-8"))
    records = [manifest[k] for k in ("julia_executable", "project", "manifest")]
    records += manifest["sources"] + manifest["artifacts"]
    if manifest.get("resume_origin"):
        origin = json.loads(Path(manifest["resume_origin"]["path"]).read_text(encoding="utf-8-sig"))
        assert origin["candidate_hash"] == manifest["candidate_hash"]["value"]
        records.append({"path": str(Path(origin["upstream_run"]) / "execution_manifest.json"),
                        "sha256": {"value": origin["upstream_manifest_sha256"]}})
        for item in origin["copied_files"]:
            records.extend({"path": item[key], "sha256": {"value": item["sha256"]}}
                           for key in ("source", "destination"))
    mismatches = []
    for record in records:
        path = Path(record["path"])
        expected = record["sha256"]["value"]
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
        if actual != expected:
            mismatches.append({"path": str(path), "expected": expected, "actual": actual})
    result = json.loads((run_dir / "result.json").read_text(encoding="utf-8"))
    assert result["candidate_hash"] == manifest["candidate_hash"]
    assert result["context_hash"] == manifest["context_hash"]
    assert result["status"] == "deferred"
    assert result["declared_reduced_execution_minimum_reached"]
    assert not result["full_function_space_mhd_solved"]
    assert not result["p5_ready"] and result["credible_device_count"] == 0
    stages = {stage["stage"]: stage for stage in result["stages"]}
    assert all(stages[name]["executed"] for name in (
        "multiregion_physics", "engineering_control_fault", "numerical_verification", "uncertainty_propagation"))
    assert not stages["physical_validation"]["executed"]
    report = {"records_checked": len(records), "mismatch_count": len(mismatches),
              "mismatches": mismatches, "stage_semantics_checked": True,
              "scope": "independent file bytes and stage consistency; no physical validation",
              "exit_code": 0 if not mismatches else 1}
    destination = run_dir / "independent_manifest_audit.json"
    destination.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report))
    return report["exit_code"]


if __name__ == "__main__":
    raise SystemExit(main())
