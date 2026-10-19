#!/usr/bin/env python3
"""Read-only independent verification of the recorded G3 MFP V2 failed run."""
from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[4]
ARCHIVE = Path("docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive")
BASE = ARCHIVE / "root_g3_focused_v2_grant_20260924"
RUN = BASE / "actual_run_v1"
OUT = ARCHIVE / "independent_g3_mfp_v2_focused_postrun_20260924"
EXPECTED_PINS = {
    "src/GenomeV5/G3/G3MaterialFieldProjectionV2.jl": "d08dff9064808e36762a226b94b2295a4cc38f81981f8008ce1425a80531771a",
    "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl": "616bda1a3f8f32a60e8175f9d8cbb44261e803fd9e392bf75c7a5593d26ed8e7",
    "test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl": "a4752286960efe44566bd9c745c94efedbceb43e1c8e6754b3c1ea91b1a88064",
    "test/GenomeV5/G3/up2_g3_source_feedback_v1_fixture.json": "7a09ec15949e148c87c2772319e6c018d767d23bacf131147c34b3e6ce63fc40",
}
EXPECTED_LAUNCHER = "41bf5cb8cc3586fa7e83e4693e642fa4245611fb6115089eb3dc72f0596dcd45"
EXPECTED_REVIEW = "cfcf6ffa20f3b3f6b8d307eb28e9ba1cfdeb9d938f0af100e50e334b35b93763"
EXPECTED_TESTER_REVIEW = "72761b1bbf01410fb64610f840238b739cb910fdab392be0af90f17cf0d6d917"
TEST_REL = "test/GenomeV5/G3/G3MaterialFieldProjectionV2/focused_tests.jl"
RAW_NAMES = ("final.json", "samples.jsonl", "stderr.raw", "stdout.raw")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path, rel: str) -> dict:
    data = path.read_bytes()
    return {"path": rel.replace("\\", "/"), "bytes": len(data), "sha256": sha(data)}


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    base = ROOT / BASE
    run = ROOT / RUN
    grant_path = base / "grant.json"
    observation_path = base / "observation.json"
    grant, observation = read_json(grant_path), read_json(observation_path)
    final = read_json(run / "final.json")
    samples = [json.loads(line) for line in (run / "samples.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    stdout = (run / "stdout.raw").read_text(encoding="utf-8", errors="replace")
    stderr = (run / "stderr.raw").read_text(encoding="utf-8", errors="replace")

    raw_entries = {name: file_receipt(run / name, str(RUN / name)) for name in RAW_NAMES}
    raw_observation = {
        name: {"relative_path": row["path"], "bytes": row["bytes"], "sha256": row["sha256"]}
        for name, row in raw_entries.items()
    }
    current_pins = {rel: file_receipt(ROOT / rel, rel) for rel in EXPECTED_PINS}
    launcher_rel = grant["launcher"]["relative_path"]
    launcher = file_receipt(ROOT / launcher_rel, launcher_rel)
    review_rel = grant["independent_reviewer"]["relative_path"]
    reviewer = file_receipt(ROOT / review_rel, review_rel)
    tester_rel = grant["independent_tester"]["relative_path"]
    tester_review = file_receipt(ROOT / tester_rel, tester_rel)
    grant_receipt = file_receipt(grant_path, str(BASE / "grant.json"))
    observation_receipt = file_receipt(observation_path, str(BASE / "observation.json"))

    summary_lines = re.findall(r"(?m)^(.+?)\s*\|\s*(\d+)\s+(\d+)\s+(\d+)\s+([\d.]+s)\s*$", stdout)
    failure_lines = [int(m.group(1)) for m in re.finditer(r"Test Failed at [^\r\n]+:(\d+)", stdout)]
    testset_count = len(re.findall(r"(?m)^Test Summary:", stdout))
    parsed_test_summary = None
    if summary_lines:
        name, passed, failed, total, testset_seconds = summary_lines[-1]
        parsed_test_summary = {
            "name": name.strip(), "passed": int(passed), "failed": int(failed),
            "total": int(total), "testset_seconds": testset_seconds,
        }

    checks = []
    def check(name: str, ok: bool, detail=None):
        checks.append({"name": name, "pass": bool(ok), **({"detail": detail} if detail is not None else {})})

    pin_declarations = {row.get("relative_path"): row.get("sha256") for row in grant.get("pinned_inputs", [])}
    check(
        "grant input pin set and current bytes",
        set(pin_declarations) == set(EXPECTED_PINS)
        and all(pin_declarations.get(p) == digest and current_pins[p]["sha256"] == digest for p, digest in EXPECTED_PINS.items()),
    )
    check(
        "launcher and independent review pins",
        launcher["sha256"] == EXPECTED_LAUNCHER
        and grant.get("launcher", {}).get("sha256") == EXPECTED_LAUNCHER
        and reviewer["sha256"] == EXPECTED_REVIEW
        and tester_review["sha256"] == EXPECTED_TESTER_REVIEW,
    )
    check(
        "grant-observation binding",
        observation.get("grant", {}).get("relative_path") == str(BASE / "grant.json").replace("\\", "/")
        and observation.get("grant", {}).get("bytes") == grant_receipt["bytes"]
        and observation.get("grant", {}).get("sha256") == grant_receipt["sha256"],
    )
    check(
        "raw file hashes join observation and final",
        observation.get("actual_files") == raw_observation
        and final.get("stdout_sha256") == raw_entries["stdout.raw"]["sha256"]
        and final.get("stderr_sha256") == raw_entries["stderr.raw"]["sha256"]
        and final.get("samples_sha256") == raw_entries["samples.jsonl"]["sha256"],
    )

    expected_argv = grant.get("command_argv", [])
    check(
        "child command matches grant and focused test",
        final.get("command_argv") == expected_argv
        and expected_argv[-1:] == [TEST_REL]
        and final.get("cwd") == grant.get("repo"),
    )
    check(
        "natural Julia child exit 1 and test failure classification",
        final.get("child_exit_code") == observation.get("child_exit_code") == 1
        and final.get("stop_reason") == observation.get("stop_reason") == "natural_exit"
        and observation.get("classification") == "test_assertion_failures_with_fail_closed_receipt"
        and "Some tests did not pass: 8 passed, 18 failed" in stderr,
    )
    expected_summary = {
        "name": "G3MaterialFieldProjectionV2 source, heat endpoint, and power distinction",
        "passed": 8, "failed": 18, "total": 26,
        "testset_seconds": parsed_test_summary.get("testset_seconds") if parsed_test_summary else None,
    }
    expected_failure_lines = [119, 120, 122, *range(127, 142)]
    check(
        "first test set exact 8 passed / 18 failed / 26",
        testset_count == 1 and parsed_test_summary == expected_summary
        and failure_lines == expected_failure_lines,
        {"summary": parsed_test_summary, "failure_lines": failure_lines},
    )
    check(
        "later focused sets did not run after first failing set",
        testset_count == 1 and "G3MaterialFieldProjectionV2 missing provenance defers" not in stdout,
    )
    check(
        "screen path's zero solver-call assertion passed; credits remain false",
        150 not in failure_lines
        and final.get("physical_credit") is False
        and "no successful g3 v2 focused runtime" in observation.get("scientific_boundary", "").lower()
        and "no material geometry provider, solver, engineering or physical credit" in grant.get("scientific_boundary", ""),
    )
    rss_values = [int(row["rss_bytes"]) for row in samples]
    check(
        "recorded run stayed under its sampled resource and wall limits",
        len(samples) == final.get("sample_count") == observation.get("sample_count") == 49
        and max(rss_values) == final.get("peak_sampled_process_tree_rss_bytes") == observation.get("peak_sampled_process_tree_rss_bytes") == 544092160
        and max(rss_values) < grant.get("sampled_rss_stop_bytes", 0)
        and final.get("elapsed_seconds", 1e9) < grant.get("wall_limit_seconds", 0),
    )
    check(
        "final current input pins match after-run receipt",
        final.get("input_pins_stable") is True
        and all(final.get("input_pins_after", {}).get(path) == digest for path, digest in EXPECTED_PINS.items()),
    )

    # Explicitly expose a stale cross-run label without changing the raw result classification.
    metadata_mismatch = {
        "final_schema": final.get("schema"),
        "final_claim_ceiling": final.get("claim_ceiling"),
        "actual_command_test": expected_argv[-1] if expected_argv else None,
        "classification": "stale_det_negative_metadata_in_focused_v2_final_record",
    }
    outcome_verified = all(item["pass"] for item in checks)
    verification = {
        "schema": "independent_g3_mfp_v2_focused_postrun_verification_v1",
        "verdict": "VERIFIED_NO_GO_FOCUSED_TEST_FAILURE" if outcome_verified else "INDEPENDENT_REVIEW_NO_GO",
        "scope": "Read-only hash and outcome verification of the already-recorded G3 MFP V2 focused Julia run. This checker did not execute Julia.",
        "grant": grant_receipt,
        "observation": observation_receipt,
        "launcher": launcher,
        "independent_reviewer_receipt": reviewer,
        "independent_static_tester_receipt": tester_review,
        "raw_run_artifacts": raw_entries,
        "current_input_pins": current_pins,
        "recorded_outcome": {
            "child_exit_code": final.get("child_exit_code"),
            "stop_reason": final.get("stop_reason"),
            "elapsed_seconds": final.get("elapsed_seconds"),
            "sample_count": len(samples),
            "peak_sampled_process_tree_rss_bytes": max(rss_values),
            "rss_cap_bytes": grant.get("sampled_rss_stop_bytes"),
            "wall_cap_seconds": grant.get("wall_limit_seconds"),
            "first_testset": parsed_test_summary,
            "failure_line_numbers": failure_lines,
            "testset_count": testset_count,
            "stderr": stderr.strip(),
        },
        "metadata_mismatch": metadata_mismatch,
        "checks": checks,
        "claim_boundary": {
            "solver_credit": False,
            "physical_credit": False,
            "engineering_credit": False,
            "candidate_or_authority_credit": False,
            "note": "The first testset's line-150 assertion requires compiler/provider/mesh/solver call counts all to be zero; that assertion is not among the 18 failed predicates. The grant and observation also explicitly withhold solver/physical credit.",
        },
        "limits": [
            "This confirms a failed focused test, not successful runtime or physics evidence.",
            "final.json retains a determinant-negative schema/claim label from another run; use the bound command, grant and observation for this focused-run classification.",
        ],
    }
    output_dir = ROOT / OUT
    output_dir.mkdir(parents=True, exist_ok=True)
    verification_path = output_dir / "verification.json"
    verification_path.write_text(json.dumps(verification, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    checker = file_receipt(Path(__file__).resolve(), str(Path(__file__).resolve().relative_to(ROOT)))
    manifest = {
        "schema": "independent_g3_mfp_v2_focused_postrun_manifest_v1",
        "verification": file_receipt(verification_path, str(verification_path.relative_to(ROOT))),
        "checker_source": checker,
        "input_receipts": [grant_receipt, observation_receipt, launcher, reviewer, tester_review, *raw_entries.values(), *current_pins.values()],
        "command": [sys.executable, "-B", str(Path(__file__).resolve())],
        "checker_exit_code": 0 if outcome_verified else 1,
        "raw_run_child_exit_code": final.get("child_exit_code"),
    }
    manifest_path = output_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "verdict": verification["verdict"],
        "checks_passed": sum(row["pass"] for row in checks),
        "checks_total": len(checks),
        "raw_child_exit": final.get("child_exit_code"),
        "first_testset": parsed_test_summary,
        "verification_sha256": sha(verification_path.read_bytes()),
        "manifest_sha256": sha(manifest_path.read_bytes()),
    }, sort_keys=True))
    return 0 if outcome_verified else 1


if __name__ == "__main__":
    raise SystemExit(main())
