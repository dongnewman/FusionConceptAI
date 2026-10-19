#!/usr/bin/env python3
"""Independent Python-only verification of the frozen Native G1/G2 r14 static candidate."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import subprocess
import sys
from datetime import datetime, timezone


REPO = pathlib.Path(__file__).resolve().parents[3]
ARCHIVE = REPO / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive"
R10_ROOT = REPO / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/independent_r10_source_marker_review_20260923/frozen_protocol"
R13_LEAF = ARCHIVE / "native_g1g2_prelaunch_r13_v1/r13_static_v1"
R14_LEAF = ARCHIVE / "native_g1g2_prelaunch_r14_v1/r14_static_v5"
R14_EVIDENCE_ROOT = ARCHIVE / "native_g1g2_prelaunch_r14_v1"
EVIDENCE_REL = pathlib.Path("native_g1g2_prelaunch_r14_v1/independent_static_review_20260924_r3")
EXPECTED_R14 = {
    "r14_static_handoff.json": "784d4a0fc4f7d4fac25b96ecc24ccd31c7db5b90869e4b98e878ff08ab7ffeb9",
    "protocol.json": "20f5dadbca24663dc5d25888e46cc4082ac816ae202edeb1ea4ef602739f0db4",
    "static_preflight.json": "c111e96a35c4651956972dff819dea1ed8d8f1510b099c612391c3abf8d8f8cd",
}
EXPECTED_RUNNER = "b2c5682f454d990e212538c24361e5b873731dbff96a1fc5f622bcf779ec1930"
EXPECTED_PREFLIGHT = "1891f65a28b00c8cfa76ab72f3ef5988ed77897753e9335be0795eca7be9c812"
EXPECTED_TEST = "074917166609945e0f46da88f92657e4ddf930fb4eadea8a463783869412302a"
EXPECTED_FOCUSED = "7365639c802b3ff2ac5106bf368ea7ceea307afbe9bbfc78822907b186a99f78"
EXPECTED_OUTPUT_MARKER_SCHEMA = "native-g1g2-r14-prelaunch-preflight-receipt-v1"


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def normalized(path: str | pathlib.Path) -> str:
    return os.path.normcase(os.path.abspath(os.fspath(path)))


def read_json(path: pathlib.Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, label: str, failures: list[str]) -> None:
    if not condition:
        failures.append(label)


def verify_pin_table(table: dict[str, dict], *, base: pathlib.Path, label: str, failures: list[str]) -> list[dict]:
    rows: list[dict] = []
    for relative, pin in sorted(table.items()):
        if isinstance(pin, str):
            expected_size = None
            expected_sha = pin
        else:
            expected_size = pin.get("bytes")
            expected_sha = pin.get("sha256")
        path = pathlib.Path(relative)
        path = path if path.is_absolute() else base / path
        exists = path.is_file()
        size = path.stat().st_size if exists else None
        digest = sha256_file(path) if exists else None
        status = "match" if exists and (expected_size is None or size == expected_size) and digest == expected_sha else "mismatch"
        rows.append({
            "path": str(path.resolve()),
            "expected_bytes": expected_size,
            "actual_bytes": size,
            "expected_sha256": expected_sha,
            "actual_sha256": digest,
            "status": status,
        })
        require(status == "match", f"{label}:{relative}", failures)
    return rows


def parse_manifest(path: pathlib.Path, *, repo: pathlib.Path, failures: list[str], label: str) -> list[dict]:
    rows = []
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw:
            continue
        parts = raw.split("\t", 1)
        require(len(parts) == 2, f"{label}_row_format:{line_no}", failures)
        if len(parts) != 2:
            continue
        expected_sha, relative = parts
        source = repo / pathlib.Path(relative.replace("/", os.sep))
        exists = source.is_file()
        size = source.stat().st_size if exists else None
        actual_sha = sha256_file(source) if exists else None
        status = "match" if exists and actual_sha == expected_sha else "mismatch"
        rows.append({
            "line": line_no,
            "relative_path": relative,
            "bytes": size,
            "expected_sha256": expected_sha,
            "actual_sha256": actual_sha,
            "status": status,
        })
        require(status == "match", f"{label}_source_pin:{relative}", failures)
    return rows


def canonicalize_r14_argv(argv: list[str]) -> tuple[list[str], int]:
    count = argv.count("--compile=min")
    if count != 1:
        return argv[:], count
    result = argv[:]
    result.remove("--compile=min")
    result = [
        token.replace(
            "native_g1g2_prelaunch_r14_v1\\r14_actual_v1",
            "native_g1g2_prelaunch_r13_v1\\r13_actual_v1",
        ).replace("focused_tests_r14_compile_min.jl", "focused_tests_r12_markers.jl")
        for token in result
    ]
    return result, count


def run_python(argv: list[str], *, cwd: pathlib.Path, stem: str, output_dir: pathlib.Path, failures: list[str]) -> dict:
    result = subprocess.run(argv, cwd=cwd, capture_output=True, timeout=120, check=False)
    (output_dir / f"{stem}.stdout.raw").write_bytes(result.stdout)
    (output_dir / f"{stem}.stderr.raw").write_bytes(result.stderr)
    (output_dir / f"{stem}.exit.txt").write_text(f"{result.returncode}\n", encoding="ascii")
    require(result.returncode == 0, f"{stem}_exit_0", failures)
    return {
        "argv": argv,
        "exit_code": result.returncode,
        "stdout_bytes": len(result.stdout),
        "stdout_sha256": hashlib.sha256(result.stdout).hexdigest(),
        "stderr_bytes": len(result.stderr),
        "stderr_sha256": hashlib.sha256(result.stderr).hexdigest(),
    }


def main() -> int:
    evidence_dir = REPO / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive" / EVIDENCE_REL
    evidence_dir.mkdir(parents=True, exist_ok=False)
    failures: list[str] = []
    r14_files = {
        "handoff": R14_LEAF / "r14_static_handoff.json",
        "protocol": R14_LEAF / "protocol.json",
        "static_preflight": R14_LEAF / "static_preflight.json",
        "parse_manifest": R14_LEAF / "parse_manifest.tsv",
        "summary": R14_LEAF / "summary.json",
    }
    handoff = read_json(r14_files["handoff"])
    protocol = read_json(r14_files["protocol"])
    static_preflight = read_json(r14_files["static_preflight"])
    frozen_summary = read_json(r14_files["summary"])
    r13_protocol = read_json(R13_LEAF / "protocol.json")
    r13_preflight = read_json(R13_LEAF / "static_preflight.json")

    # Exact frozen anchors and all 123 current static dependencies.
    frozen_anchor_hashes = {name: sha256_file(path) for name, path in r14_files.items() if name in EXPECTED_R14}
    # r14_files uses semantic labels; separately pin the named anchors.
    frozen_anchor_hashes = {
        name: sha256_file(R14_LEAF / name) for name in EXPECTED_R14
    }
    for name, expected in EXPECTED_R14.items():
        require(frozen_anchor_hashes[name] == expected, f"frozen_anchor:{name}", failures)
    require(protocol.get("schema") == "native-g1g2-gridap-recorded-protocol-r14-v1", "r14_protocol_schema", failures)
    require(protocol.get("run_revision") == "r14_compile_min_resource_diagnostic_test_only", "r14_revision", failures)
    deps14 = static_preflight.get("dependencies", {})
    require(len(deps14) == 123, "r14_current_dependency_count_123", failures)
    dependency_rows = verify_pin_table(deps14, base=REPO, label="r14_dependency", failures=failures)

    # R10 115-pin baseline and all frozen R13/R14 ancestry references.
    r10_static_path = pathlib.Path(protocol["r10_baseline"]["static_preflight_path"])
    r10_protocol_path = pathlib.Path(protocol["r10_baseline"]["protocol_path"])
    r10_parse_path = pathlib.Path(protocol["r10_baseline"]["parse_manifest_path"])
    r10_static = read_json(r10_static_path)
    require(sha256_file(r10_static_path) == protocol["r10_baseline"]["static_preflight_sha256"], "r10_static_baseline_sha", failures)
    require(sha256_file(r10_protocol_path) == protocol["r10_baseline"]["protocol_sha256"], "r10_protocol_baseline_sha", failures)
    require(sha256_file(r10_parse_path) == protocol["r10_baseline"]["parse_manifest_sha256"], "r10_parse_baseline_sha", failures)
    r10_deps = r10_static.get("dependencies", {})
    require(len(r10_deps) == 115 and protocol["r10_baseline"].get("pinned_input_count") == 115, "r10_baseline_count_115", failures)
    r10_rows = verify_pin_table(r10_deps, base=REPO, label="r10_dependency", failures=failures)
    missing_from_r14 = sorted(set(r10_deps) - set(deps14))
    changed_r10 = sorted(k for k in set(r10_deps) & set(deps14) if r10_deps[k] != deps14[k])
    require(not missing_from_r14 and not changed_r10, "all_r10_115_pins_preserved_exactly", failures)

    lineage_files = protocol.get("prior_run_lineage", {}).get("files", {})
    require(len(lineage_files) == 34, "prior_lineage_count_34", failures)
    lineage_rows = verify_pin_table(lineage_files, base=REPO, label="prior_lineage", failures=failures)
    r13_parent_pins = handoff.get("r13_parent", {}).get("pins", {})
    r13_parent_rows = verify_pin_table(
        {path: {"bytes": (REPO / path).stat().st_size if (REPO / path).is_file() else None, "sha256": digest}
         for path, digest in r13_parent_pins.items()},
        base=REPO,
        label="r13_parent_pin",
        failures=failures,
    )
    for path, digest in r13_parent_pins.items():
        require(lineage_files.get(path) == digest, f"r13_parent_is_in_pinned_lineage:{path}", failures)

    # Check every advertised file in the frozen r14 leaf and the 108-source parse manifest.
    leaf_rows = []
    for row in handoff.get("r14_leaf_files", []):
        path = REPO / pathlib.Path(row["path"])
        actual_bytes = path.stat().st_size if path.is_file() else None
        actual_sha = sha256_file(path) if path.is_file() else None
        status = "match" if actual_bytes == row.get("bytes") and actual_sha == row.get("sha256") else "mismatch"
        leaf_rows.append({**row, "actual_bytes": actual_bytes, "actual_sha256": actual_sha, "status": status})
        require(status == "match", f"r14_frozen_leaf_file:{row['path']}", failures)
    parse_rows14 = parse_manifest(r14_files["parse_manifest"], repo=REPO, failures=failures, label="r14_parse")
    parse_rows13 = parse_manifest(R13_LEAF / "parse_manifest.tsv", repo=REPO, failures=failures, label="r13_parse")
    require(len(parse_rows14) == 108 and len(parse_rows13) == 108, "r13_r14_parse_entry_count_108", failures)
    normalized_manifest14 = [
        (r["expected_sha256"], r["relative_path"].replace("focused_tests_r14_compile_min.jl", "focused_tests_r12_markers.jl"))
        for r in parse_rows14
    ]
    normalized_manifest13 = [(r["expected_sha256"], r["relative_path"]) for r in parse_rows13]
    require(normalized_manifest14 == normalized_manifest13, "r14_parse_manifest_same_pinned_sources_after_named_test_path_normalization", failures)

    # Compare exact stage argv, allowing only the compile option plus versioned leaf/source path rewrites.
    stages13 = r13_protocol["execution_plan"]["stage_commands"]
    stages14 = protocol["execution_plan"]["stage_commands"]
    require([x.get("stage") for x in stages13] == ["parse_all", "primary", "fresh_replay"], "r13_stage_order", failures)
    require([x.get("stage") for x in stages14] == ["parse_all", "primary", "fresh_replay"], "r14_stage_order", failures)
    argv_diff = []
    for old, new in zip(stages13, stages14):
        normalized_argv, compile_count = canonicalize_r14_argv(new["argv"])
        threads_i = new["argv"].index("--threads=1") if "--threads=1" in new["argv"] else -1
        compile_i = new["argv"].index("--compile=min") if "--compile=min" in new["argv"] else -1
        stage_ok = old.get("stage") == new.get("stage") and old["argv"] == normalized_argv and compile_count == 1 and compile_i == threads_i + 1
        require(stage_ok, f"stage_argv_only_compile_min_delta:{new.get('stage')}", failures)
        argv_diff.append({
            "stage": new.get("stage"),
            "r13_argv_length": len(old["argv"]),
            "r14_argv_length": len(new["argv"]),
            "compile_min_occurrences": compile_count,
            "compile_min_position_after_threads": compile_i == threads_i + 1,
            "remaining_argv_equal_after_explicit_versioned_path_normalization": old["argv"] == normalized_argv,
        })

    require(protocol.get("stage_order") == r13_protocol.get("stage_order"), "protocol_stage_order_unchanged", failures)
    require(protocol.get("limits_per_julia_stage") == r13_protocol.get("limits_per_julia_stage"), "per_stage_limits_equal_r13", failures)
    require(protocol.get("limits_per_julia_stage") == {
        "wall_seconds": 480.0,
        "whole_process_tree_rss_bytes": 2147483648,
        "julia_threads": 1,
        "blas_threads": 1,
    }, "budget_480s_2GiB_1thread", failures)
    require(protocol.get("memory_observability", {}).get("julia_heap_size_hint") == "1G", "heap_hint_1G", failures)
    require(protocol.get("numerical_protocol") == r13_protocol.get("numerical_protocol"), "numerical_protocol_exactly_equal_r13", failures)
    require(protocol.get("precompile_diagnostic", {}).get("markers") == r13_protocol.get("precompile_diagnostic", {}).get("markers"), "precompile_markers_equal_r13", failures)
    require(protocol.get("precompile_diagnostic") == r13_protocol.get("precompile_diagnostic"), "precompile_contract_equal_r13", failures)
    require(handoff.get("r14_strategy", {}).get("compile_min_is_measured_as_resource_reduction") is False, "compile_min_not_claimed_measured_reduction", failures)
    require(protocol.get("r14_budget_contract", {}).get("fixtures_and_numerical_thresholds_unchanged") is True, "r14_fixture_threshold_contract", failures)
    require(protocol.get("r14_budget_contract", {}).get("diagnostic_only_not_solver_or_numerical_success") is True, "r14_diagnostic_only_contract", failures)

    focused_old = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r12_markers.jl"
    focused_new = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl"
    require(sha256_file(focused_old) == EXPECTED_FOCUSED and sha256_file(focused_new) == EXPECTED_FOCUSED, "r14_focused_test_byte_identical_to_r13", failures)
    compiler_source = REPO / "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl"
    adapter_source = REPO / "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl"
    fixture_source = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl"
    for path in (compiler_source, adapter_source, fixture_source):
        require(path.relative_to(REPO).as_posix() in deps14, f"frozen_source_present_in_dependencies:{path.name}", failures)
        require(path.relative_to(REPO).as_posix() in r13_preflight.get("dependencies", {}), f"source_pinned_in_r13:{path.name}", failures)
        if path.relative_to(REPO).as_posix() in r13_preflight.get("dependencies", {}):
            require(deps14[path.relative_to(REPO).as_posix()] == r13_preflight["dependencies"][path.relative_to(REPO).as_posix()], f"source_identical_to_r13:{path.name}", failures)

    # Frozen candidate status and previous actual R13 failure classification.
    require(handoff.get("claim_scope") == "compiler_resource_diagnostic", "claim_scope_compiler_resource_diagnostic", failures)
    require(handoff.get("status") == "static_ready_independent_review_pending", "frozen_handoff_pending_review", failures)
    require(handoff.get("decision_boundary", "").find("No Julia stage") >= 0, "handoff_no_julia_claim", failures)
    require(handoff.get("r14_strategy", {}).get("numerical_status") == "not_established", "numerical_not_established", failures)
    require(handoff.get("r14_strategy", {}).get("physical_status") == "unknown", "physical_unknown", failures)
    require(handoff.get("r14_strategy", {}).get("solver_success_predeclared") is False, "no_solver_success_predeclared", failures)
    require(frozen_summary.get("runtime_executed") is False and frozen_summary.get("resolution") == "terminal_deferred", "frozen_summary_static_only_deferred", failures)
    require(frozen_summary.get("scientific_status") == "not_accepted" and frozen_summary.get("physical_status") == "unknown", "frozen_summary_no_scientific_or_physical_credit", failures)
    require(handoff.get("static_qa", {}).get("julia_started") is False, "producer_static_qa_julia_false", failures)
    require(handoff.get("static_qa", {}).get("unit_test_count") == 12, "producer_static_qa_12_tests", failures)
    require(handoff.get("static_qa", {}).get("prelaunch_status") == "pass" and handoff.get("static_qa", {}).get("unit_test_status") == "pass", "producer_static_qa_pass", failures)
    require(handoff.get("r13_parent", {}).get("numerical_status") == "not_established", "r13_parent_numerical_not_established", failures)
    require(handoff.get("r13_parent", {}).get("physical_status") == "unknown", "r13_parent_physical_unknown", failures)
    require(handoff.get("r13_parent", {}).get("primary_exit_code") != 0, "r13_parent_failure_preserved", failures)

    # The frozen source cache starts empty; Python -B checks must not create bytecode.
    cache_dir = pathlib.Path(__file__).resolve().parent / "__pycache__"
    cache_before = sorted(x.name for x in cache_dir.iterdir()) if cache_dir.exists() else []
    require(not cache_before, "source_test_cache_empty_before", failures)

    output_dir = evidence_dir / "runner_static_only"
    planned_dir = evidence_dir / "planned_actual_never_created"
    runner = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/run_recorded_r14.py"
    test_path = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/test_r14_prelaunch_preflight.py"
    julia = pathlib.Path(protocol["execution_plan"]["julia_executable"]["path"])
    py = pathlib.Path(sys.executable).resolve()
    require(str(py).casefold() == r"d:\users\newman\anaconda3\python.exe".casefold(), "tester_python_matches_frozen_interpreter", failures)
    require(sha256_file(runner) == EXPECTED_RUNNER, "r14_runner_source_sha", failures)
    preflight_source = REPO / "test/RuntimeV4/NativeG1G2DiffusionV1/r14_prelaunch_preflight.py"
    test_source_sha = sha256_file(test_path)
    require(sha256_file(preflight_source) == EXPECTED_PREFLIGHT, "r14_preflight_source_sha", failures)
    require(test_source_sha == EXPECTED_TEST, "r14_unit_test_source_sha", failures)

    runner_argv = [
        str(py), "-B", str(runner),
        "--output", str(output_dir),
        "--planned-output", str(planned_dir),
        "--julia", str(julia),
        "--static-only",
    ]
    runner_result = run_python(runner_argv, cwd=REPO, stem="independent_static_runner", output_dir=evidence_dir, failures=failures)
    fresh_static = read_json(output_dir / "static_preflight.json") if (output_dir / "static_preflight.json").is_file() else {}
    fresh_summary = read_json(output_dir / "summary.json") if (output_dir / "summary.json").is_file() else {}
    fresh_preflight = {}
    try:
        fresh_preflight = json.loads((output_dir / "prelaunch.stdout.raw").read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        failures.append("independent_static_runner_preflight_json")
    require(fresh_summary.get("runtime_executed") is False, "independent_static_runtime_false", failures)
    require(fresh_summary.get("mode") == "static_only" and fresh_summary.get("status") == "static_ready", "independent_static_summary", failures)
    require(fresh_summary.get("resolution") == "terminal_deferred", "independent_static_deferred", failures)
    require(fresh_preflight.get("schema") == EXPECTED_OUTPUT_MARKER_SCHEMA and fresh_preflight.get("status") == "pass", "independent_preflight_pass", failures)
    require(fresh_preflight.get("julia_started") is False, "independent_preflight_no_julia", failures)
    require(fresh_preflight.get("static_preflight_sha256") == sha256_file(output_dir / "static_preflight.json"), "independent_preflight_static_sha_join", failures)
    require(fresh_static.get("static", {}).get("check_count") == 37, "independent_static_check_count_37", failures)
    require(all(value is True for value in fresh_static.get("static", {}).get("checks", {}).values()), "independent_static_checks_all_true", failures)
    fresh_manifest_rows = parse_manifest(output_dir / "parse_manifest.tsv", repo=REPO, failures=failures, label="independent_parse")
    require(len(fresh_manifest_rows) == 108, "independent_parse_manifest_108", failures)
    require(not planned_dir.exists(), "independent_planned_actual_path_absent", failures)

    test_argv = [str(py), "-B", str(test_path), "-v"]
    test_result = run_python(test_argv, cwd=REPO, stem="independent_python_tests", output_dir=evidence_dir, failures=failures)
    test_stderr = (evidence_dir / "independent_python_tests.stderr.raw").read_text(encoding="utf-8")
    test_names = [line.strip().split(" ... ", 1)[0].split(" (", 1)[0] for line in test_stderr.splitlines() if line.startswith("test_") and " ... ok" in line]
    require(len(test_names) == 12 and "Ran 12 tests" in test_stderr and test_stderr.rstrip().endswith("OK"), "independent_unit_tests_12_pass", failures)
    required_negative_names = {
        "test_missing_compile_mode_fails_closed",
        "test_extra_actual_argv_fails_closed_with_diagnostic",
        "test_static_argv_is_not_accepted_for_actual_mode",
        "test_threshold_tampering_fails_closed",
    }
    require(required_negative_names.issubset(set(test_names)), "independent_fail_closed_negative_controls", failures)

    cache_after = sorted(x.name for x in cache_dir.iterdir()) if cache_dir.exists() else []
    require(cache_after == cache_before, "source_test_cache_unchanged", failures)
    # Make sure neither the frozen candidate leaf nor pinned implementation inputs drifted.
    leaf_recheck = []
    for row in handoff.get("r14_leaf_files", []):
        path = REPO / pathlib.Path(row["path"])
        sha = sha256_file(path) if path.is_file() else None
        size = path.stat().st_size if path.is_file() else None
        status = "match" if size == row.get("bytes") and sha == row.get("sha256") else "mismatch"
        leaf_recheck.append({"path": row["path"], "bytes": size, "sha256": sha, "status": status})
        require(status == "match", f"r14_frozen_leaf_stable_after_tests:{row['path']}", failures)
    dep_recheck = verify_pin_table(deps14, base=REPO, label="r14_dependency_after", failures=failures)

    verdict = "PASS_STATIC_CANDIDATE_ONLY" if not failures else "NO_GO"
    verification = {
        "schema": "independent-native-g1g2-r14-static-review-v1",
        "recorded_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "failures": failures,
        "review_scope": "read-only static verification and Python-only tests; no Julia stage launched; no numerical or physical credit",
        "frozen_anchors": {
            name: {"path": str((R14_LEAF / name).resolve()), "bytes": (R14_LEAF / name).stat().st_size, "sha256": frozen_anchor_hashes[name], "expected_sha256": expected}
            for name, expected in EXPECTED_R14.items()
        },
        "r14_protocol": {
            "schema": protocol.get("schema"),
            "revision": protocol.get("run_revision"),
            "current_dependency_count": len(deps14),
            "current_dependency_rehash": dependency_rows,
            "r10_baseline_count": len(r10_deps),
            "r10_baseline_preserved_exactly": not missing_from_r14 and not changed_r10,
            "r10_missing_paths_in_r14": missing_from_r14,
            "r10_changed_pins_in_r14": changed_r10,
            "r10_rehash": r10_rows,
            "r14_lineage_count": len(lineage_files),
            "r14_lineage_rehash": lineage_rows,
            "r13_parent_pin_rehash": r13_parent_rows,
            "frozen_r14_leaf_file_rehash": leaf_rows,
            "frozen_r14_leaf_file_rehash_after_tests": leaf_recheck,
            "parse_manifest_entries": len(parse_rows14),
            "parse_manifest_all_sources_match": all(row["status"] == "match" for row in parse_rows14),
            "r13_r14_parse_set_equal_after_versioned_test_path_normalization": normalized_manifest14 == normalized_manifest13,
            "stage_argv_delta_checks": argv_diff,
            "stage_order": protocol.get("stage_order"),
            "limits_per_julia_stage": protocol.get("limits_per_julia_stage"),
            "julia_heap_size_hint": protocol.get("memory_observability", {}).get("julia_heap_size_hint"),
            "numerical_protocol_equal_to_r13": protocol.get("numerical_protocol") == r13_protocol.get("numerical_protocol"),
            "precompile_diagnostic_equal_to_r13": protocol.get("precompile_diagnostic") == r13_protocol.get("precompile_diagnostic"),
            "precompile_markers": protocol.get("precompile_diagnostic", {}).get("markers"),
            "focused_test_sha_equal_to_r13": sha256_file(focused_new) == sha256_file(focused_old) == EXPECTED_FOCUSED,
        },
        "frozen_claim_boundary": {
            "claim_scope": handoff.get("claim_scope"),
            "numerical_status": handoff.get("r14_strategy", {}).get("numerical_status"),
            "physical_status": handoff.get("r14_strategy", {}).get("physical_status"),
            "solver_success_predeclared": handoff.get("r14_strategy", {}).get("solver_success_predeclared"),
            "compile_min_resource_reduction_measured": protocol.get("compiler_strategy", {}).get("compile_min_is_measured_as_resource_reduction"),
            "frozen_summary": {k: frozen_summary.get(k) for k in ("mode", "runtime_executed", "status", "scientific_status", "physical_status", "resolution")},
            "interpretation": "This is a static compiler-resource diagnostic candidate; numerical status remains not established and physical status unknown.",
        },
        "independent_python_runs": {
            "static_runner": runner_result,
            "fresh_static_summary": fresh_summary,
            "fresh_preflight": {k: fresh_preflight.get(k) for k in ("schema", "status", "protocol_sha256", "static_preflight_sha256", "julia_started", "current_dependency_count", "julia_source_count", "hard_wall_seconds", "hard_process_tree_rss_bytes", "compile_min_is_the_only_compiler_argv_delta_from_r13")},
            "fresh_static_checks": fresh_static.get("static", {}).get("checks", {}),
            "fresh_parse_manifest_entries": len(fresh_manifest_rows),
            "unit_tests": {**test_result, "test_count": len(test_names), "test_names": test_names, "negative_controls_present": sorted(required_negative_names)},
            "cache_inventory_before": cache_before,
            "cache_inventory_after": cache_after,
            "planned_actual_path_absent": not planned_dir.exists(),
        },
        "checker": {"path": str(pathlib.Path(__file__).resolve()), "sha256": sha256_file(pathlib.Path(__file__).resolve())},
    }
    verification_path = evidence_dir / "verification.json"
    verification_path.write_text(json.dumps(verification, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    commands = {
        "kind": "non_executable_command_data",
        "python_executable": str(py),
        "static_runner_argv": runner_argv,
        "static_runner_exit": runner_result["exit_code"],
        "unit_test_argv": test_argv,
        "unit_test_exit": test_result["exit_code"],
        "note": "Both subprocesses are Python-only. run_recorded_r14.py was invoked with --static-only; its own branch records Julia not started.",
    }
    commands_path = evidence_dir / "command_argv.json"
    commands_path.write_text(json.dumps(commands, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    evidence_files = []
    for path in sorted(p for p in evidence_dir.rglob("*") if p.is_file()):
        evidence_files.append({"path": str(path.resolve()), "bytes": path.stat().st_size, "sha256": sha256_file(path), "role": "reviewer_evidence"})
    manifest_files = evidence_files + [
        {"path": str(pathlib.Path(__file__).resolve()), "bytes": pathlib.Path(__file__).stat().st_size, "sha256": sha256_file(pathlib.Path(__file__).resolve()), "role": "reviewer_source"},
        {"path": str(R14_LEAF / "r14_static_handoff.json"), "bytes": (R14_LEAF / "r14_static_handoff.json").stat().st_size, "sha256": frozen_anchor_hashes["r14_static_handoff.json"], "role": "frozen_candidate_anchor"},
        {"path": str(R14_LEAF / "protocol.json"), "bytes": (R14_LEAF / "protocol.json").stat().st_size, "sha256": frozen_anchor_hashes["protocol.json"], "role": "frozen_candidate_anchor"},
        {"path": str(R14_LEAF / "static_preflight.json"), "bytes": (R14_LEAF / "static_preflight.json").stat().st_size, "sha256": frozen_anchor_hashes["static_preflight.json"], "role": "frozen_candidate_anchor"},
    ]
    manifest = {
        "schema": "independent-native-g1g2-r14-static-review-manifest-v1",
        "verdict": verdict,
        "files": manifest_files,
        "no_julia_or_freegs_launched": True,
        "manifest_self_hash": "not_applicable",
    }
    manifest_path = evidence_dir / "archive_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"verdict": verdict, "failures": failures, "verification": str(verification_path), "manifest": str(manifest_path)}, sort_keys=True))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
