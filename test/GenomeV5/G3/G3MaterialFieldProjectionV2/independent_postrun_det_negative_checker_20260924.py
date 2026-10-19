#!/usr/bin/env python3
"""Independent read-only verification of the recorded G3 determinant-negative run."""
from __future__ import annotations

import copy
import hashlib
import json
from datetime import datetime
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[4]
BASE = Path("docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive")
RUN_REL = BASE / "root_g3_det_negative_grant_20260924/actual_run_v1"
GRANT_REL = BASE / "root_g3_det_negative_grant_20260924/grant.json"
OBS_REL = BASE / "root_g3_det_negative_grant_20260924/observation.json"
PROTOCOL_REL = BASE / "native_g3_mfp_v2_det_negative_review_r1_20260924/frozen_protocol_v1/protocol.json"
OUT_REL = BASE / "independent_g3_det_negative_postrun_tester_20260924"

PIN_SHA = {
    "src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl": "d08dff9064808e36762a226b94b2295a4cc38f81981f8008ce1425a80531771a",
    "test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl": "a4752286960efe44566bd9c745c94efedbceb43e1c8e6754b3c1ea91b1a88064",
    "test/GenomeV5/G3/G3MaterialFieldProjectionV2/determinant_negative_v1_tests.jl": "5e90d014a938d8d1043a0313fedf325f03f39bdb26428bc2db70f49440b4117a",
    "test/GenomeV5/G3/G3MaterialFieldProjectionV2/determinant_negative_v1_fixture.json": "e47512fe0839902b9452859625f04297e3a0df40c12cd7e394d57db5efb1d5c3",
}
PROTOCOL_SHA = "5de564af1d0c68ac2cfdeccbfbf90394838ef24df3a50bc213e917f8e4777f60"
RUN_FILE_NAMES = ("final.json", "samples.jsonl", "stderr.raw", "stdout.raw")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_entry(path: Path, relative: str) -> dict:
    blob = path.read_bytes()
    return {"path": relative, "bytes": len(blob), "sha256": sha256_bytes(blob)}


def reject_if_bad(grant, observation, protocol, final, samples, raw_meta, pin_actual, protocol_meta):
    errors = []
    expected_pins = set(PIN_SHA)
    recorded_pins = {row.get("relative_path"): row.get("sha256") for row in grant.get("pinned_inputs", [])}
    if set(recorded_pins) != expected_pins:
        errors.append("grant_pin_set_mismatch")
    for rel, expected in PIN_SHA.items():
        if recorded_pins.get(rel) != expected or pin_actual.get(rel, {}).get("sha256") != expected:
            errors.append("pinned_input_drift:" + rel)
    if protocol_meta.get("sha256") != PROTOCOL_SHA:
        errors.append("protocol_sha_mismatch")
    if protocol.get("claim_ceiling") != "constructor_gate_regression_only" or protocol.get("physical_status") != "unknown":
        errors.append("protocol_claim_boundary_mismatch")
    if protocol.get("formal_credit") is not False or protocol.get("solver_credit") is not False:
        errors.append("protocol_credit_boundary_mismatch")
    if observation.get("launcher", {}).get("sha256") != grant.get("launcher", {}).get("sha256"):
        errors.append("launcher_binding_mismatch")
    if observation.get("input_pins_stable") is not True or final.get("input_pins_stable") is not True:
        errors.append("input_stability_not_proven")
    final_pins = final.get("input_pins_after", {})
    for rel, expected in PIN_SHA.items():
        if final_pins.get(rel) != expected:
            errors.append("final_input_pin_mismatch:" + rel)
    raw_claims = {name: raw_meta[name] for name in RUN_FILE_NAMES}
    if observation.get("actual_files", {}) != raw_claims:
        errors.append("observation_raw_metadata_mismatch")
    for name in RUN_FILE_NAMES:
        actual = raw_meta.get(name, {})
        if name == "final.json":
            if actual.get("sha256") != protocol_meta.get("final_sha256"):
                errors.append("final_raw_sha_mismatch")
        elif name == "samples.jsonl":
            if final.get("samples_sha256") != actual.get("sha256"):
                errors.append("samples_raw_sha_mismatch")
        elif name == "stdout.raw":
            if final.get("stdout_sha256") != actual.get("sha256"):
                errors.append("stdout_raw_sha_mismatch")
        elif name == "stderr.raw":
            if final.get("stderr_sha256") != actual.get("sha256"):
                errors.append("stderr_raw_sha_mismatch")
    argv = grant.get("command_argv", [])
    if final.get("command_argv") != argv or argv[-4:] != ["--project=.", "--startup-file=no", "--history-file=no", "test/GenomeV5/G3/G3MaterialFieldProjectionV2/determinant_negative_v1_tests.jl"]:
        errors.append("argv_binding_mismatch")
    if final.get("child_exit_code") != 0 or observation.get("child_exit_code") != 0 or final.get("stop_reason") != "natural_exit":
        errors.append("natural_exit_mismatch")
    if observation.get("julia_test_result") != "9/9 pass":
        errors.append("test_result_mismatch")
    if any(observation.get(k) is not False for k in ("physical_credit", "engineering_credit", "solver_credit", "formal_candidate_credit")):
        errors.append("observation_credit_boundary_mismatch")
    if final.get("physical_credit") is not False or final.get("claim_ceiling") != "constructor_gate_regression_only":
        errors.append("final_credit_boundary_mismatch")
    limit = grant.get("sampled_rss_stop_bytes")
    wall = grant.get("wall_limit_seconds")
    if not isinstance(limit, int) or not isinstance(wall, (int, float)):
        errors.append("resource_limits_missing")
    else:
        if not samples or any(not isinstance(s.get("rss_bytes"), int) or s["rss_bytes"] > limit for s in samples):
            errors.append("rss_limit_exceeded_or_unmeasured")
        peak = max((s.get("rss_bytes", -1) for s in samples), default=-1)
        if peak != final.get("peak_sampled_process_tree_rss_bytes") or peak != observation.get("peak_sampled_process_tree_rss_bytes"):
            errors.append("rss_peak_mismatch")
        if len(samples) != final.get("sample_count") or len(samples) != observation.get("sample_count"):
            errors.append("sample_count_mismatch")
        if final.get("elapsed_seconds", wall + 1) > wall or observation.get("elapsed_seconds", wall + 1) > wall:
            errors.append("wall_limit_exceeded")
    if not re.search(r"G3 MFP V2 symmetric determinant-negative tensor is rejected\s*\|\s*9\s+9\s+", raw_meta.get("stdout_text", "")):
        errors.append("stdout_test_summary_missing")
    if raw_meta.get("stderr_text") != "":
        errors.append("stderr_not_empty")
    return errors


def main() -> int:
    grant_path, obs_path, protocol_path = (ROOT / p for p in (GRANT_REL, OBS_REL, PROTOCOL_REL))
    run_path = ROOT / RUN_REL
    grant, observation, protocol = map(read_json, (grant_path, obs_path, protocol_path))
    final = read_json(run_path / "final.json")
    samples = [json.loads(line) for line in (run_path / "samples.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    stdout_text = (run_path / "stdout.raw").read_text(encoding="utf-8")
    stderr_text = (run_path / "stderr.raw").read_text(encoding="utf-8")

    grant_entry = file_entry(grant_path, str(GRANT_REL).replace("\\", "/"))
    obs_entry = file_entry(obs_path, str(OBS_REL).replace("\\", "/"))
    protocol_entry = file_entry(protocol_path, str(PROTOCOL_REL).replace("\\", "/"))
    launcher_path = ROOT / grant["launcher"]["relative_path"]
    launcher_entry = file_entry(launcher_path, grant["launcher"]["relative_path"])
    run_entries = {name: file_entry(run_path / name, str(RUN_REL / name).replace("\\", "/")) for name in RUN_FILE_NAMES}
    raw_meta = {
        name: {"relative_path": entry["path"], "bytes": entry["bytes"], "sha256": entry["sha256"]}
        for name, entry in run_entries.items()
    }
    raw_meta["stdout_text"] = stdout_text
    raw_meta["stderr_text"] = stderr_text
    pin_actual = {}
    for rel in PIN_SHA:
        p = ROOT / rel
        pin_actual[rel] = file_entry(p, rel)
    protocol_entry["final_sha256"] = run_entries["final.json"]["sha256"]

    checks = []
    def check(name, condition, detail=None):
        checks.append({"name": name, "pass": bool(condition), **({"detail": detail} if detail is not None else {})})

    check("protocol exact hash", protocol_entry["sha256"] == PROTOCOL_SHA, protocol_entry)
    check("grant protocol binding", grant.get("protocol", {}).get("sha256") == PROTOCOL_SHA)
    check("observation grant binding", observation.get("grant", {}).get("sha256") == grant_entry["sha256"] and observation.get("grant", {}).get("bytes") == grant_entry["bytes"])
    check("four frozen input pins", all(pin_actual[r]["sha256"] == PIN_SHA[r] for r in PIN_SHA), pin_actual)
    raw_claims = {name: raw_meta[name] for name in RUN_FILE_NAMES}
    check("raw artifact hashes join final and observation", observation.get("actual_files") == raw_claims and final.get("stdout_sha256") == run_entries["stdout.raw"]["sha256"] and final.get("stderr_sha256") == run_entries["stderr.raw"]["sha256"] and final.get("samples_sha256") == run_entries["samples.jsonl"]["sha256"])
    check("command joins grant and final", final.get("command_argv") == grant.get("command_argv") and final.get("command_argv", [])[-1:] == [protocol.get("julia_test_protocol", {}).get("argv", [])[-1]])
    check("natural exit 0 and 9/9 summary", final.get("child_exit_code") == 0 and observation.get("child_exit_code") == 0 and final.get("stop_reason") == "natural_exit" and bool(re.search(r"G3 MFP V2 symmetric determinant-negative tensor is rejected\s*\|\s*9\s+9\s+", stdout_text)))
    check("13 RSS samples below stop cap", len(samples) == 13 and max(s["rss_bytes"] for s in samples) == 357916672 and max(s["rss_bytes"] for s in samples) < grant["sampled_rss_stop_bytes"])
    check("wall and scope ceiling", final.get("elapsed_seconds", grant["wall_limit_seconds"] + 1) < grant["wall_limit_seconds"] and final.get("claim_ceiling") == "constructor_gate_regression_only" and final.get("physical_credit") is False and observation.get("physical_credit") is False and observation.get("solver_credit") is False and observation.get("formal_candidate_credit") is False)

    base_errors = reject_if_bad(grant, observation, protocol, final, samples, raw_meta, pin_actual, protocol_entry)
    check("independent contract predicates", not base_errors, base_errors)

    negative_results = []
    def negative(name, g=grant, o=observation, f=final, ss=samples, rm=raw_meta, pa=pin_actual, pm=protocol_entry):
        errors = reject_if_bad(g, o, protocol, f, ss, rm, pa, pm)
        negative_results.append({"name": name, "rejected": bool(errors), "errors": errors[:4]})
    bad_obs = copy.deepcopy(observation)
    bad_obs["actual_files"]["stdout.raw"]["sha256"] = "0" * 64
    negative("stale stdout hash", o=bad_obs)
    bad_grant = copy.deepcopy(grant)
    bad_grant["pinned_inputs"].pop()
    negative("missing frozen input pin", g=bad_grant)
    bad_samples = copy.deepcopy(samples)
    bad_samples[0]["rss_bytes"] = grant["sampled_rss_stop_bytes"] + 1
    negative("RSS above stop cap", ss=bad_samples)
    bad_final = copy.deepcopy(final)
    bad_final["child_exit_code"] = 1
    negative("altered child exit", f=bad_final)
    check("four in-memory negative controls rejected", all(x["rejected"] for x in negative_results), negative_results)

    all_pass = all(row["pass"] for row in checks)
    verification = {
        "schema": "independent_g3_det_negative_postrun_verification_v1",
        "verdict": "PASS_RECORDED_CONSTRUCTOR_REGRESSION_ONLY" if all_pass else "NO_GO",
        "scope": "Read-only independent verification of frozen input pins and recorded determinant-negative Julia test run; no source execution was performed by this checker.",
        "physical_or_solver_credit": False,
        "protocol": protocol_entry,
        "grant": grant_entry,
        "observation": obs_entry,
        "launcher": launcher_entry,
        "run_artifacts": run_entries,
        "input_pins": pin_actual,
        "recorded_run": {
            "child_exit_code": final.get("child_exit_code"),
            "stop_reason": final.get("stop_reason"),
            "elapsed_seconds": final.get("elapsed_seconds"),
            "sample_count": len(samples),
            "peak_sampled_process_tree_rss_bytes": max(s["rss_bytes"] for s in samples),
            "rss_stop_bytes": grant.get("sampled_rss_stop_bytes"),
            "wall_limit_seconds": grant.get("wall_limit_seconds"),
            "stdout_summary": stdout_text.strip(),
            "stderr_empty": stderr_text == "",
        },
        "checks": checks,
        "negative_controls": negative_results,
        "limitations": ["This is a constructor-gate regression only.", "No material spatial solve, solver, physical, engineering, candidate, or authority claim is established."],
    }
    out = ROOT / OUT_REL
    out.mkdir(parents=True, exist_ok=True)
    verification_path = out / "verification.json"
    verification_path.write_text(json.dumps(verification, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    checker_entry = file_entry(Path(__file__).resolve(), str(Path(__file__).resolve().relative_to(ROOT)).replace("\\", "/"))
    manifest = {
        "schema": "independent_g3_det_negative_postrun_manifest_v1",
        "verification": file_entry(verification_path, str(OUT_REL / "verification.json").replace("\\", "/")),
        "checker_source": checker_entry,
        "inputs": [grant_entry, obs_entry, protocol_entry, launcher_entry, *run_entries.values(), *pin_actual.values()],
        "checker_command": [sys.executable, "-B", str(Path(__file__).resolve())],
        "checker_exit_code": 0 if all_pass else 1,
    }
    manifest_path = out / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verification["verdict"], "checks_passed": sum(c["pass"] for c in checks), "checks_total": len(checks), "negative_controls_rejected": sum(n["rejected"] for n in negative_results), "verification_sha256": file_entry(verification_path, "verification.json")["sha256"], "manifest_sha256": file_entry(manifest_path, "manifest.json")["sha256"]}, sort_keys=True))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
