#!/usr/bin/env python3
"""Independent Python-only review of the frozen R14 v7 RSS reporter candidate."""
from __future__ import annotations

import hashlib
import importlib
import json
import subprocess
import sys
import tempfile
from pathlib import Path


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
LEAF = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v7"
OUT = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/independent_r14_static_v7_review_20260924"
PROTOCOL_REL = "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v7/protocol.json"
PROTOCOL_SHA = "35c4132bc8c3e53b2c0f237b03ed82e1e8739eb6f48f708d0687e02baba7ea01"
MANIFEST_SHA = "d969e5c8f670070e264fb96eac25c31c0277c539222ee2f4b2707fbc99a07931"
SUMMARY_SHA = "a2d9fa3ef71a33fffdfe107bb68b675c26cf1f3da79464045d0735edf63511ae"
HANDOFF_SHA = "db1e82a0eeda649babc99c44ac91a5bdc36475f72b4564b04a00e7b12aed4169"
EXPECTED_EXTERNAL = {
    "test/RuntimeV4/NativeG1G2DiffusionV1/report_r14_resource_outcome_v7.py": "69e964339bf6a65184775d1b503b7f81b49dc50b58c2a4658a777e9f19046432",
    "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v7_resource_report.py": "e41b6507218ba4a85059982be85bc63d611f362de3962e7f77eaf9c1d7a5f5ed",
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14.py": "b2c5682f454d990e212538c24361e5b873731dbff96a1fc5f622bcf779ec1930",
    "test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight.py": "1891f65a28b00c8cfa76ab72f3ef5988ed77897753e9335be0795eca7be9c812",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v6/protocol.json": "62daac70a79d6caae2e9755116e40749d47d2c44da370b4b18930a92b60ea8ce",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r14_v1/r14_static_v6/archive_manifest.json": "bd7637964241343590c9e8d7a8a47cbdeabf786a4747608c8c21ac6b9d8aab58",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/summary.json": "e0ebc5cfd90ac36f4249af1022a2f05277c3e9850816244ca63bbb40ce1a5044",
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r13_v1/r13_actual_v1/02_primary/samples.jsonl": "8f018ea7d4ae7e9f86b78229420f68d06d34b87f7b51d84207394b92810918af",
}
EXPECTED_ARCHIVE = {
    "protocol.json": PROTOCOL_SHA,
    "review_handoff.json": HANDOFF_SHA,
    "summary.json": SUMMARY_SHA,
    "static_qa.command.json": "d8bc6472c509645c825d0906c4906b47ee5591bb6e9f9f6a1adbabf9b191ed45",
    "static_qa.exit.txt": "4355a46b19d348dc2f57c046f8ef63d4538ebb936000f3c9ee954a27460dd865",
    "static_qa.stderr.raw": "7ef798d6bc11698355871e0050d61a38de893278b14adfd83f4baa2dc652f172",
    "static_qa.stdout.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "static_qa_retry1.command.json": "1908a8d6f28fed95beb6f45e8fe32937fd10e9eac60d013ee698505b9864afcd",
    "static_qa_retry1.exit.txt": "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa",
    "static_qa_retry1.stderr.raw": "3f75ed8a316512bcee211a9d569d420dbbc6f696dfaac7be640391c479780bd3",
    "static_qa_retry1.stdout.raw": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
}

sys.path.insert(0, str(HERE))
reporter = importlib.import_module("report_r14_resource_outcome_v7")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path, rel: str) -> dict:
    data = path.read_bytes()
    return {"path": rel.replace("\\", "/"), "bytes": len(data), "sha256": sha256_bytes(data)}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def make_run(root: Path, values: list[object], stop_reason: str, exit_code: int,
             *, declared_peak: int | None = None, stage_list: list[str] | None = None) -> Path:
    names = stage_list or ["parse_all", "primary"]
    stages = []
    for ordinal, name in enumerate(names, start=1):
        stage_dir = root / f"{ordinal:02d}_{name}"
        stage_dir.mkdir(parents=True)
        row_values = values if name == "primary" else [100_000_000]
        row_reason = stop_reason if name == "primary" else "natural_exit"
        row_exit = exit_code if name == "primary" else 0
        raw_samples = b"".join(
            (json.dumps({"process_tree_rss_bytes": v, "elapsed_seconds": ix / 5}, sort_keys=True) + "\n").encode("utf-8")
            for ix, v in enumerate(row_values)
        )
        (stage_dir / "samples.jsonl").write_bytes(raw_samples)
        peak = max(row_values, default=0) if declared_peak is None or name != "primary" else declared_peak
        final = {
            "schema": "native-g1g2-recorded-stage-v1", "index": ordinal, "stage": name,
            "exit_code": row_exit, "stop_reason": row_reason, "sample_count": len(row_values),
            "peak_process_tree_rss_bytes": peak,
            "stdout": {"bytes": 0, "sha256": sha256_bytes(b"")},
            "stderr": {"bytes": 0, "sha256": sha256_bytes(b"")},
        }
        (stage_dir / "final.json").write_text(json.dumps(final, sort_keys=True) + "\n", encoding="utf-8")
        stages.append(final)
    summary = {
        "schema": "native-g1g2-run-summary-v1", "runtime_executed": True,
        "status": "fail" if exit_code else "pass", "stages": stages,
        "scientific_status": "not_accepted", "physical_status": "unknown",
    }
    (root / "summary.json").write_text(json.dumps(summary, sort_keys=True) + "\n", encoding="utf-8")
    return root


def run_semantic_controls() -> list[dict]:
    cases = []
    threshold = reporter.RSS_THRESHOLD_BYTES

    def record(name: str, passed: bool, observed: str):
        cases.append({"name": name, "pass": bool(passed), "observed": observed})

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "exact", [threshold], "process_tree_rss_limit", 15)
        result = reporter.build_report(leaf)
        row = result["stage_reports"][1]
        record("exact threshold classified resource_failure", result["run_disposition"] == "resource_failure" and row["resource_failure"] and row["rss_threshold"]["overshoot_bytes"] == 0, result["run_disposition"])

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "overshoot", [threshold + 51], "natural_exit", 0)
        result = reporter.build_report(leaf)
        row = result["stage_reports"][1]
        record("overshoot overrides inconsistent stop but preserves raw exit", result["run_disposition"] == "resource_failure" and row["low_level_stage_outcome"]["stop_reason"] == "natural_exit" and row["low_level_stage_outcome"]["exit_code"] == 0 and row["low_level_stage_outcome"]["threshold_stop_consistency"] == "sampled_threshold_hit_but_low_level_stop_reason_differs", row["disposition"])

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "below", [threshold - 1], "natural_exit", 0)
        result = reporter.build_report(leaf)
        record("below threshold carries no solver-success claim", result["run_disposition"] == "no_sampled_rss_threshold_crossing" and result["claim_boundary"]["solver_success_claimed"] is False and result["claim_boundary"]["numerical_status"] == "not_established", result["run_disposition"])

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "missing-hit", [threshold - 1], "process_tree_rss_limit", 15)
        try:
            reporter.build_report(leaf)
            record("RSS stop without sample hit rejected", False, "accepted")
        except ValueError as exc:
            record("RSS stop without sample hit rejected", "no sampled threshold hit" in str(exc), str(exc))

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "peak-mismatch", [threshold + 10], "process_tree_rss_limit", 15, declared_peak=threshold)
        try:
            reporter.build_report(leaf)
            record("stale declared peak rejected", False, "accepted")
        except ValueError as exc:
            record("stale declared peak rejected", "peak RSS disagrees" in str(exc) or "summary disagrees" in str(exc), str(exc))

    with tempfile.TemporaryDirectory() as temp:
        leaf = make_run(Path(temp) / "bool-sample", [True], "natural_exit", 0)
        try:
            reporter.build_report(leaf)
            record("boolean RSS sample rejected", False, "accepted")
        except ValueError as exc:
            record("boolean RSS sample rejected", "nonnegative integer" in str(exc), str(exc))

    with tempfile.TemporaryDirectory() as temp:
        leaf = Path(temp) / "static-only"
        leaf.mkdir()
        (leaf / "summary.json").write_text(json.dumps({
            "schema": "native-g1g2-run-summary-v1", "runtime_executed": False,
            "mode": "static_only", "status": "static_ready", "stages": [],
        }), encoding="utf-8")
        try:
            result = reporter.build_report(leaf)
            record("static-only empty leaf rejected", False, "accepted as " + result["run_disposition"])
        except ValueError as exc:
            record("static-only empty leaf rejected", True, str(exc))
    return cases


def main() -> int:
    results = []
    def check(name: str, passed: bool, detail=None):
        results.append({"name": name, "pass": bool(passed), **({"detail": detail} if detail is not None else {})})

    protocol_path = ROOT / PROTOCOL_REL
    protocol = load_json(protocol_path)
    manifest_path = LEAF / "archive_manifest.json"
    archive_manifest = load_json(manifest_path)
    handoff = load_json(LEAF / "review_handoff.json")
    summary = load_json(LEAF / "summary.json")

    check("frozen leaf anchors", sha256_bytes(protocol_path.read_bytes()) == PROTOCOL_SHA and sha256_bytes(manifest_path.read_bytes()) == MANIFEST_SHA and sha256_bytes((LEAF / "summary.json").read_bytes()) == SUMMARY_SHA and sha256_bytes((LEAF / "review_handoff.json").read_bytes()) == HANDOFF_SHA)
    leaf_entries = {p.relative_to(LEAF).as_posix(): sha256_bytes(p.read_bytes()) for p in LEAF.rglob("*") if p.is_file() and p.name != "archive_manifest.json"}
    check("leaf inventory and all 11 frozen entry hashes", set(leaf_entries) == set(EXPECTED_ARCHIVE) and leaf_entries == EXPECTED_ARCHIVE and archive_manifest.get("entry_count_excluding_manifest") == 11 and {e["path"]: e["sha256"] for e in archive_manifest.get("entries", [])} == EXPECTED_ARCHIVE, leaf_entries)

    external_pins = {e["path"]: e["sha256"] for e in archive_manifest.get("external_pins", [])}
    actual_external = {rel: sha256_bytes((ROOT / rel).read_bytes()) for rel in EXPECTED_EXTERNAL}
    check("all 8 external source and ancestry pins", external_pins == EXPECTED_EXTERNAL and actual_external == EXPECTED_EXTERNAL, actual_external)

    inherited = protocol.get("inherited_runtime_contract", {})
    resource = protocol.get("rss_guard", {})
    check("unchanged 480s, 2GiB, 0.2s, 1G and single threads", inherited.get("wall_seconds_per_stage") == 480.0 and inherited.get("whole_process_tree_rss_threshold_bytes") == 2_147_483_648 and inherited.get("rss_sample_interval_seconds") == 0.2 and inherited.get("julia_heap_size_hint") == "1G" and inherited.get("julia_threads") == 1 and inherited.get("blas_threads") == 1 and resource.get("threshold_bytes") == 2_147_483_648 and resource.get("sample_interval_seconds") == 0.2)
    check("physics, fixtures and thresholds are unchanged; no Julia", inherited.get("fixture_cases_and_mesh_levels_changed") is False and inherited.get("numerical_thresholds_changed") is False and protocol.get("julia_started") is False and protocol.get("numerical_status") == "not_established" and protocol.get("physical_status") == "unknown" and protocol.get("formal_t2_consumer_receipts") == 0)
    check("R14 reporter logic is explicitly sampled resource failure", resource.get("stop_when_sampled_rss_greater_than_or_equal_to_threshold") is True and resource.get("threshold_reached_or_overshot_disposition") == "resource_failure" and protocol.get("reporter", {}).get("resource_failure_rule", "").find(">= 2147483648") >= 0 and protocol.get("reporter", {}).get("no_solver_success_inference") is True)
    check("reporter and runtime pins agree with current bytes", protocol.get("reporter", {}).get("sha256") == EXPECTED_EXTERNAL["test/RuntimeV4/NativeG1G2DiffusionV1/report_r14_resource_outcome_v7.py"] and protocol.get("static_qa", {}).get("test_sha256") == EXPECTED_EXTERNAL["test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v7_resource_report.py"] and protocol.get("runtime_integration", {}).get("runner_sha256") == EXPECTED_EXTERNAL["test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14.py"] and protocol.get("runtime_integration", {}).get("preflight_sha256") == EXPECTED_EXTERNAL["test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight.py"])
    check("v7 report remains additive and not dispatch authorization", protocol.get("reporter", {}).get("role") == "additive_read_only_post_run_classifier" and protocol.get("runtime_integration", {}).get("dispatch_ready") is False and protocol.get("bounded_decision", "").find("unauthorized") >= 0 and handoff.get("dispatch_authorized") is False)
    check("prior setup failure preserved and successful retry is 9/9", (LEAF / "static_qa.exit.txt").read_text(encoding="utf-8").strip() == "1" and (LEAF / "static_qa_retry1.exit.txt").read_text(encoding="utf-8").strip() == "0" and b"Ran 9 tests" in (LEAF / "static_qa_retry1.stderr.raw").read_bytes() and b"OK" in (LEAF / "static_qa_retry1.stderr.raw").read_bytes())

    test_cmd = [sys.executable, "-B", "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v7_resource_report.py", "-v"]
    test_run = subprocess.run(test_cmd, cwd=ROOT, capture_output=True, text=True, check=False)
    test_receipt = {
        "argv": test_cmd, "cwd": str(ROOT), "exit_code": test_run.returncode,
        "stdout": test_run.stdout, "stderr": test_run.stderr,
        "stdout_sha256": sha256_bytes(test_run.stdout.encode()), "stderr_sha256": sha256_bytes(test_run.stderr.encode()),
        "julia_started_by_test": False,
    }
    check("independent rerun of frozen static suite 9/9", test_run.returncode == 0 and "Ran 9 tests" in test_run.stderr and "OK" in test_run.stderr)

    semantic = run_semantic_controls()
    check("independent threshold/resource semantics positive and negative controls", all(row["pass"] for row in semantic), semantic)

    checker_entry = receipt(Path(__file__).resolve(), Path(__file__).resolve().relative_to(ROOT).as_posix())
    input_receipts = [
        receipt(protocol_path, PROTOCOL_REL),
        receipt(manifest_path, str(manifest_path.relative_to(ROOT))),
        receipt(LEAF / "summary.json", str((LEAF / "summary.json").relative_to(ROOT))),
        receipt(LEAF / "review_handoff.json", str((LEAF / "review_handoff.json").relative_to(ROOT))),
    ]
    input_receipts.extend(receipt(ROOT / rel, rel) for rel in EXPECTED_EXTERNAL)
    input_receipts.extend(receipt(ROOT / rel, rel) for rel in EXPECTED_EXTERNAL if "report_r14_resource" in rel or "test_r14_static" in rel)
    input_receipts.extend(receipt(LEAF / rel, str((LEAF / rel).relative_to(ROOT))) for rel in EXPECTED_ARCHIVE if rel.endswith(".raw") or rel.endswith(".exit.txt") or rel.endswith(".command.json"))

    all_pass = all(row["pass"] for row in results)
    verification = {
        "schema": "independent_native_g1g2_r14_v7_static_review_v1",
        "verdict": "PASS_STATIC_REPORTER_CANDIDATE_ONLY" if all_pass else "NO_GO",
        "scope": "Python-only review of frozen R14 v7 RSS reporter, static suite, runtime invariants, and dependency pins. Julia was not run.",
        "protocol": receipt(protocol_path, PROTOCOL_REL),
        "archive_manifest": receipt(manifest_path, str(manifest_path.relative_to(ROOT))),
        "reporter_source": receipt(ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/report_r14_resource_outcome_v7.py", "test/RuntimeV4/NativeG1G2DiffusionV1/report_r14_resource_outcome_v7.py"),
        "static_test_source": receipt(ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v7_resource_report.py", "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_static_v7_resource_report.py"),
        "static_rerun": test_receipt,
        "runtime_contract": {
            "wall_seconds_per_stage": inherited.get("wall_seconds_per_stage"),
            "rss_threshold_bytes": resource.get("threshold_bytes"),
            "rss_sample_interval_seconds": resource.get("sample_interval_seconds"),
            "heap_hint": inherited.get("julia_heap_size_hint"),
            "julia_threads": inherited.get("julia_threads"),
            "blas_threads": inherited.get("blas_threads"),
            "fixtures_changed": inherited.get("fixture_cases_and_mesh_levels_changed"),
            "numerical_thresholds_changed": inherited.get("numerical_thresholds_changed"),
        },
        "semantic_controls": semantic,
        "checks": results,
        "lineage": {"first_test_attempt_exit": 1, "failed_setup_preserved": True, "successful_retry_test_count": 9},
        "limits": ["Static reporter candidate only; dispatch remains unauthorized.", "No Julia, solver, mesh, replay, numerical, or physical result was established."],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    verification_path = OUT / "verification.json"
    verification_path.write_text(json.dumps(verification, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    manifest_out = {
        "schema": "independent_native_g1g2_r14_v7_static_review_manifest_v1",
        "verification": receipt(verification_path, str(verification_path.relative_to(ROOT))),
        "checker_source": checker_entry,
        "inputs": input_receipts,
        "checker_argv": [sys.executable, "-B", str(Path(__file__).resolve())],
        "static_suite_argv": test_cmd,
        "static_suite_exit": test_run.returncode,
        "review_exit": 0 if all_pass else 1,
    }
    manifest_out_path = OUT / "manifest.json"
    manifest_out_path.write_text(json.dumps(manifest_out, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "verdict": verification["verdict"], "checks_passed": sum(x["pass"] for x in results),
        "checks_total": len(results), "reporter_controls_passed": sum(x["pass"] for x in semantic),
        "reporter_controls_total": len(semantic),
        "verification_sha256": sha256_bytes(verification_path.read_bytes()),
        "manifest_sha256": sha256_bytes(manifest_out_path.read_bytes()),
    }, sort_keys=True))
    return 0 if all_pass else 1


if __name__ == "__main__":
    raise SystemExit(main())
