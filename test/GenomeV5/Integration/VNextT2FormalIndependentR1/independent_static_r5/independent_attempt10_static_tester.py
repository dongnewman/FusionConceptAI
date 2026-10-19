#!/usr/bin/env python3
"""Independent Python-only verification of the frozen T2 attempt10 bundle."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any


ROOT = Path(__file__).resolve().parents[5]
ARCHIVE_REL = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress")
ARCHIVE = ROOT / ARCHIVE_REL
PROTOCOL_REL = ARCHIVE_REL / "protocol.json"
MAP_REL = ARCHIVE_REL / "coverage_map_r7.json"
QA_REL = ARCHIVE_REL / "static_qa.json"
SNAPSHOT_REL = ARCHIVE_REL / "freeze_snapshot.json"
COMMAND_REL = ARCHIVE_REL / "command_argv.json"
DISPATCH_REL = ARCHIVE_REL / "dispatch.json"
OLD_MAP_REL = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json")
EVIDENCE_REL = Path(
    "docs/implementation/UP1-04A-VNEXT-T2/archive/"
    "independent_static_r5_attempt10_tester_retry2_20260924")
EVIDENCE = ROOT / EVIDENCE_REL
TEST_REL = Path(__file__).resolve().relative_to(ROOT).as_posix()

EXPECTED = {
    PROTOCOL_REL.as_posix(): "30c7e2141d0028607040d3395fecb3327738bb8c5cfda54ad6aa50a5ba96f58d",
    MAP_REL.as_posix(): "060b6d887901b462e63ae0ac68539abc35c2f89bdf35a360672435aef5df0d68",
    QA_REL.as_posix(): "8ea4d4395da37167ea8bb595783477227cb4038579a3bb38cc29acff1772a383",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r9.py":
        "514181506b6d41f05773d2388d79262e46ba26f1bfa42f301e72c1389d1ff8ad",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r6.jl":
        "5a71c6417cadd04c3f36f8461134de46f455debdf7c6e9f804181c589c3b590e",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/build_coverage_map_r7.py":
        "aae483a51178f9ca19d67d80983b37f58b7da4e0ae741c08b59b7cb3e1ae7a2c",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r8.py":
        "7fb4e60f5f04c3392dcf3581fb29810d20a57c529c25554fa6e28d9dea28b0af",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/freeze_independent_negative_protocol_r8.py":
        "db647193adf039b485230e4a66ccf55abb223915609563aa7ae9db69ce6948f4",
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/validate_projection24_reuse_r4.py":
        "bb0f40d1dbe5b7507657e4e60442ec6b6b027cca223d4eaed7ddcd56fb99b297",
}
EXPECTED_CACHE = [
    {
        "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/__pycache__/freeze_independent_negative_protocol_r3.cpython-313.pyc",
        "bytes": 48089,
        "sha256": "ebc3c1cfc31b7acf306d5f9addfaff5e45ca4a6772877585148a7df57d897608",
    },
    {
        "path": "test/GenomeV5/Integration/VNextT2FormalIndependentR1/__pycache__/static_qa_independent_negative_r3.cpython-313.pyc",
        "bytes": 72660,
        "sha256": "30cf8b444ec15c98e018a8cfb261e650acc61cf431e83ef65d59535cc5e51e4b",
    },
]
REQUIRED_NEGATIVE_CONTROL_NAMES = [
    "attempt8 14-argument interruption pin drift",
    "attempt9 projection natural-exit failure pin drift",
    "attempt9b QA failure receipt mutation rejected",
    "authority invocation cap drift rejected",
    "authority coverage threshold change rejected",
    "authority child cap no longer bounded by remaining invocation rejected",
    "authority runtime Test.record counter removal rejected",
    "authority flushed per-record event removal rejected",
    "authority per-record source line drift rejected",
    "authority progress wrong-case hit rejected",
    "authority partial progress receipt rejected",
    "authority partial child phase rejected",
    "partial event wrong source line rejected",
    "partial event wrong site ID rejected",
    "partial event ordinal gap rejected",
    "partial event wrong source file rejected",
    "partial event result class rejected",
    "partial map SHA drift rejected",
    "partial source SHA drift rejected",
    "partial case identity drift rejected",
    "partial child receipt is not reusable",
    "resume input closure drift rejected",
    "formal shard rejects coverage map argv reordering",
]


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def receipt(path: Path, relative: str | None = None) -> dict[str, Any]:
    data = path.read_bytes()
    return {
        "path": relative or path.resolve().relative_to(ROOT).as_posix(),
        "bytes": len(data),
        "sha256": sha(data),
    }


def json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"expected JSON object: {path}")
    return value


def check(checks: list[dict[str, Any]], name: str, ok: bool,
          detail: Any = None) -> None:
    row = {"name": name, "pass": bool(ok)}
    if detail is not None:
        row["detail"] = detail
    checks.append(row)


def site_by_id(rows: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    result = {row["id"]: row for row in rows}
    if len(result) != len(rows):
        raise ValueError("duplicate assertion site id")
    return result


def source_assertion_text(lines: list[str], line_number: int) -> str:
    """Reconstruct the indented Julia macro expression starting at one line."""
    if not 1 <= line_number <= len(lines):
        raise ValueError("assertion line is outside source")
    source_line = lines[line_number - 1]
    stripped = source_line.lstrip()
    indent = len(source_line) - len(stripped)
    pieces = [stripped]
    cursor = line_number
    while cursor < len(lines):
        candidate = lines[cursor]
        candidate_stripped = candidate.lstrip()
        candidate_indent = len(candidate) - len(candidate_stripped)
        if not candidate_stripped or candidate_stripped.startswith("#") or \
                candidate_indent <= indent:
            break
        pieces.append(candidate_stripped)
        cursor += 1
    return " ".join(piece.strip() for piece in pieces)


def cache_inventory() -> list[dict[str, Any]]:
    cache_root = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/__pycache__"
    return [receipt(path) for path in sorted(cache_root.glob("*.pyc"))]


def case_plan_digest(value: Any) -> str:
    raw = json.dumps(value, ensure_ascii=False, sort_keys=True,
                     separators=(",", ":")).encode("utf-8")
    return sha(raw)


def run_static_qa(protocol: dict[str, Any], protocol_sha: str) -> dict[str, Any]:
    dispatch_path = ROOT / DISPATCH_REL
    qa_script = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r8.py"
    report_path = EVIDENCE / "producer_static_qa_replay.json"
    stdout_path = EVIDENCE / "producer_static_qa_replay.stdout.raw"
    stderr_path = EVIDENCE / "producer_static_qa_replay.stderr.raw"
    command = [
        sys.executable, "-B", str(qa_script),
        "--protocol", str(ROOT / PROTOCOL_REL),
        "--protocol-sha256", protocol_sha,
        "--dispatch", str(dispatch_path),
        "--command", str(ROOT / COMMAND_REL),
        "--report", str(report_path),
    ]
    env = dict(os.environ)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    started = time.monotonic()
    completed = subprocess.run(command, cwd=ROOT, env=env, capture_output=True,
                               timeout=300, check=False)
    elapsed = time.monotonic() - started
    stdout_path.write_bytes(completed.stdout)
    stderr_path.write_bytes(completed.stderr)
    (EVIDENCE / "producer_static_qa_replay.command.json").write_text(
        json.dumps({
            "schema": "independent-static-qa-command-data-v1",
            "argv": command,
            "cwd": str(ROOT),
            "environment": {"PYTHONDONTWRITEBYTECODE": "1"},
            "exit_code": completed.returncode,
            "elapsed_seconds": elapsed,
            "julia_started": False,
        }, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8", newline="\n")
    return {
        "command": command,
        "exit_code": completed.returncode,
        "elapsed_seconds": elapsed,
        "report_path": report_path,
        "stdout_path": stdout_path,
        "stderr_path": stderr_path,
        "report": json_object(report_path) if report_path.is_file() else None,
    }


def main() -> int:
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    checks: list[dict[str, Any]] = []
    protocol = json_object(ROOT / PROTOCOL_REL)
    coverage = json_object(ROOT / MAP_REL)
    static_qa_frozen = json_object(ROOT / QA_REL)
    snapshot = json_object(ROOT / SNAPSHOT_REL)
    command_data = json_object(ROOT / COMMAND_REL)
    dispatch = json_object(ROOT / DISPATCH_REL)
    old_coverage = json_object(ROOT / OLD_MAP_REL)

    actual_bundle = {relative: receipt(ROOT / relative, relative)
                     for relative in EXPECTED}
    bundle_hashes_ok = all(
        actual_bundle[path]["sha256"] == expected
        for path, expected in EXPECTED.items())
    check(checks, "frozen bundle/source anchor SHA-256 pins",
          bundle_hashes_ok, actual_bundle)
    check(checks, "coverage map and protocol receipt join",
          protocol.get("coverage_map") == receipt(ROOT / MAP_REL, MAP_REL.as_posix())
          and protocol.get("input_count") == 319
          and protocol.get("expected_phase_count") == 30)

    pins = protocol.get("inputs", {})
    input_receipts: list[dict[str, Any]] = []
    mismatches = []
    for relative, expected in sorted(pins.items()):
        path = ROOT / relative
        try:
            actual = receipt(path, relative)
        except OSError as error:
            mismatches.append({"path": relative, "error": repr(error)})
            continue
        input_receipts.append(actual)
        if actual != {"path": relative, "bytes": expected.get("bytes"),
                      "sha256": expected.get("sha256")}:
            mismatches.append({"path": relative, "expected": expected,
                               "actual": actual})
    check(checks, "current protocol input closure rehashed 319 of 319",
          len(input_receipts) == len(pins) == protocol.get("input_count") == 319
          and not mismatches,
          {"rehashed": len(input_receipts), "pinned": len(pins),
           "mismatch_count": len(mismatches), "mismatches": mismatches[:8]})

    positive_pins = protocol.get("positive_reuse_input_pins", {})
    positive_pin_mismatches = []
    for relative, expected in positive_pins.items():
        actual = pins.get(relative)
        if not isinstance(actual, dict) or actual.get("bytes") != expected.get("bytes") or \
                actual.get("sha256") != expected.get("sha256"):
            positive_pin_mismatches.append(relative)
    check(checks, "104 positive R3 pins are an exact path/bytes/SHA subset of current closure",
          len(positive_pins) == 104 and not positive_pin_mismatches,
          {"positive_pin_count": len(positive_pins),
           "mismatch_count": len(positive_pin_mismatches),
           "mismatches": positive_pin_mismatches[:8]})

    plan = coverage["successor_assertion_runtime_hit_plan"]
    old_plan = old_coverage["successor_assertion_runtime_hit_plan"]
    current_sites = site_by_id(coverage["successor_assertion_sites"])
    old_sites = site_by_id(old_coverage["successor_assertion_sites"])
    ledger = protocol["attempt7_coverage_comparison"]["path_line_relocation_ledger"]
    ledger_by_id = {row["id"]: row for row in ledger.get("entries", [])}
    current_line_checks = 0
    relocation_errors = []
    reloc_path_changes = 0
    reloc_line_changes = 0
    stable_sites = 0
    delta_counts: dict[int, int] = {}
    source_cache: dict[str, list[str]] = {}
    for site_id in sorted(set(current_sites) | set(old_sites)):
        new = current_sites.get(site_id)
        old = old_sites.get(site_id)
        row = ledger_by_id.get(site_id)
        if new is None or old is None or row is None:
            relocation_errors.append({"id": site_id, "reason": "missing site or ledger row"})
            continue
        old_norm = {key: value for key, value in old.items()
                    if key not in {"path", "line"}}
        new_norm = {key: value for key, value in new.items()
                    if key not in {"path", "line"}}
        if old_norm != new_norm:
            relocation_errors.append({"id": site_id, "reason": "site semantics changed"})
        old_path, new_path = old["path"], new["path"]
        old_line, new_line = old["line"], new["line"]
        path_changed = old_path != new_path
        delta = new_line - old_line
        reloc_path_changes += int(path_changed)
        reloc_line_changes += int(delta != 0)
        delta_counts[delta] = delta_counts.get(delta, 0) + 1
        stable_sites += int(not path_changed and delta == 0)
        if row.get("attempt7") != {"path": old_path, "line": old_line} or \
                row.get("attempt8") != {"path": new_path, "line": new_line} or \
                row.get("path_changed") is not path_changed or \
                row.get("line_delta") != delta or \
                row.get("current_source_line_verified") is not True or \
                row.get("source_text_matches_attempt7") is not True or \
                row.get("source_text") != new.get("source_text") or \
                row.get("source_text_sha256") != new.get("source_text_sha256"):
            relocation_errors.append({"id": site_id, "reason": "ledger row disagrees with maps"})
        if old_path.endswith("actual_formal_negative_driver_r2.jl"):
            if new_path != "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r6.jl" or delta == 0:
                relocation_errors.append({"id": site_id, "reason": "unexpected driver relocation"})
        elif path_changed or delta != 0:
            relocation_errors.append({"id": site_id, "reason": "non-driver site relocated"})
        if new_path not in source_cache:
            try:
                source_cache[new_path] = (ROOT / new_path).read_text(encoding="utf-8").splitlines()
            except OSError as error:
                relocation_errors.append({"id": site_id, "reason": f"current source unavailable: {error}"})
                continue
        lines = source_cache[new_path]
        if not isinstance(new_line, int) or new_line < 1 or new_line > len(lines) or \
                source_assertion_text(lines, new_line) != new.get("source_text") or \
                sha(new.get("source_text", "").encode("utf-8")) != new.get("source_text_sha256"):
            relocation_errors.append({"id": site_id, "reason": "source line/text/hash mismatch"})
        else:
            current_line_checks += 1

    comparison = protocol["attempt7_coverage_comparison"]
    formal_ids = coverage["runtime_execution_plan"]["actual_formal_summary_case_ids"]
    all_case_ids = coverage["runtime_execution_plan"]["expected_unique_case_ids"]
    case_counts = coverage["runtime_execution_plan"]["expected_runtime_case_hit_counts"]
    site_hit_sum = sum(int(site.get("runtime_multiplicity", -1))
                       for site in coverage["successor_assertion_sites"])
    site_phase_sum = sum(sum(int(value) for value in site["expected_phase_hits"].values())
                         for site in coverage["successor_assertion_sites"])
    site_semantics_equal = (
        len(current_sites) == len(old_sites) == 214
        and current_sites.keys() == old_sites.keys()
        and current_sites.keys() == ledger_by_id.keys()
        and coverage["successor_case_assertion_ids"] ==
            old_coverage["successor_case_assertion_ids"]
        and coverage["successor_cases"] == old_coverage["successor_cases"]
        and coverage["runtime_execution_plan"] == old_coverage["runtime_execution_plan"]
        and plan["phase_site_hit_counts"] == old_plan["phase_site_hit_counts"]
        and plan["site_expected_phase_hits"] == old_plan["site_expected_phase_hits"]
        and all(current_sites[key]["expected_phase_hits"] == old_sites[key]["expected_phase_hits"]
                for key in current_sites)
        and all(current_sites[key]["runtime_multiplicity"] == old_sites[key]["runtime_multiplicity"]
                for key in current_sites)
        and coverage.get("old_assertion_site_count") == old_coverage.get("old_assertion_site_count") == 154
        and coverage.get("old_expected_runtime_hit_count") == old_coverage.get("old_expected_runtime_hit_count") == 174
    )
    check(checks, "45 formal cases / 60 unique / 68 runtime case hits preserved",
          len(formal_ids) == comparison.get("formal_case_count") == 45
          and len(all_case_ids) == comparison.get("case_count") == 60
          and len(set(all_case_ids)) == 60
          and sum(int(value) for value in case_counts.values()) ==
              comparison.get("runtime_case_hit_count") == 68
          and formal_ids == old_coverage["runtime_execution_plan"]["actual_formal_summary_case_ids"]
          and all_case_ids == old_coverage["runtime_execution_plan"]["expected_unique_case_ids"]
          and case_counts == old_coverage["runtime_execution_plan"]["expected_runtime_case_hit_counts"],
          {"formal_case_count": len(formal_ids), "unique_case_count": len(all_case_ids),
           "runtime_case_hits": sum(int(value) for value in case_counts.values())})
    check(checks, "214 assertion sites / 622 planned hits and old obligation map preserved",
          site_semantics_equal
          and plan.get("assertion_site_count") == 214
          and plan.get("expected_runtime_hit_count") == 622
          and coverage.get("successor_assertion_site_count") == 214
          and coverage.get("successor_expected_runtime_hit_count") == 622
          and site_hit_sum == site_phase_sum == 622,
          {"site_count": len(current_sites), "planned_hits": site_hit_sum,
           "phase_hit_sum": site_phase_sum, "old_obligations": 154,
           "old_planned_hits": 174})
    check(checks, "all 214 relocation ledger entries resolve to exact current source text",
          len(ledger_by_id) == 214 and current_line_checks == 214
          and reloc_path_changes == 175 and reloc_line_changes == 175 and stable_sites == 39
          and comparison.get("path_line_relocation_ledger", {}).get("current_source_line_verified_count") == 214
          and not relocation_errors,
          {"path_changed": reloc_path_changes, "line_changed": reloc_line_changes,
           "stable_sites": stable_sites, "line_delta_counts": delta_counts,
           "current_source_text_verified": current_line_checks,
           "errors": relocation_errors[:8]})

    phases = protocol.get("phase_order", [])
    dispatch_phases = dispatch.get("phase_order", [])
    check(checks, "30 phase order remains bound to dispatch",
          len(phases) == protocol.get("expected_phase_count") == 30
          and phases == dispatch_phases)
    check(checks, "2400s authority cap preserves 480s phase, 2GiB and 1-thread gates",
          protocol.get("resource_gates") == {
              "phase_wall_seconds": 480,
              "authority_phase_wall_seconds": 2400,
              "authority_case_wall_seconds": 2400,
              "process_tree_working_set_bytes": 2147483648,
              "julia_threads": 1,
              "openblas_threads": 1,
          }
          and protocol.get("authority_case_budget_change", {}).get("prior_case_timeout_seconds") == 1200
          and protocol.get("authority_case_budget_change", {}).get("new_case_timeout_seconds") == 2400
          and protocol.get("authority_case_budget_change", {}).get("authority_invocation_timeout_seconds") == 2400
          and protocol.get("authority_case_budget_change", {}).get("coverage_thresholds_changed") is False
          and protocol.get("authority_case_budget_change", {}).get("effective_child_timeout_policy") ==
              "min(per_case_cap, remaining_invocation_budget)")

    argv = command_data.get("argv", [])
    argv_values = {key: argv[argv.index(key) + 1] for key in (
        "--phase-timeout", "--authority-phase-timeout",
        "--authority-case-timeout", "--working-set-limit")
        if key in argv and argv.index(key) + 1 < len(argv)}
    env = command_data.get("environment", {})
    budget_cmd_ok = argv_values == {
        "--phase-timeout": "480",
        "--authority-phase-timeout": "2400",
        "--authority-case-timeout": "2400",
        "--working-set-limit": "2147483648",
    }
    shard_contract = protocol["actual_formal_shard_argv_contract"]
    check(checks, "command data pins 480/2400s and all 12 fixed shard modes",
          budget_cmd_ok and env.get("JULIA_NUM_THREADS") == "1"
          and env.get("OPENBLAS_NUM_THREADS") == "1"
          and shard_contract.get("shard_modes") == [
              "preflight", "fault_n10", "t1_handoff",
              *[f"authority-case:{case_id}" for case_id in
                protocol["authority_case_execution_contract"]["case_order"]]]
          and shard_contract.get("expected_driver_argument_count") == 16
          and shard_contract.get("coverage_map_path_driver_argv_index_1_based") == 15
          and shard_contract.get("coverage_map_sha256_driver_argv_index_1_based") == 16,
          {"command_timeout_values": argv_values,
           "shard_modes": shard_contract.get("shard_modes"),
           "environment": env})

    hit_plan = coverage["successor_assertion_runtime_hit_plan"].get("authority_case_hit_plan", {})
    authority_cases = protocol["authority_case_execution_contract"]
    expected_case_counts = authority_cases.get("expected_case_hit_counts_static_plan", {})
    case_site_counts = hit_plan.get("case_site_hit_counts", {})
    authority_site_ids = {row["id"] for row in coverage["successor_assertion_sites"]
                          if row.get("path") == hit_plan.get("source_path")}
    per_case_zero_fill = (len(case_site_counts) == 9 and
        all(set(counts) == authority_site_ids and len(counts) == 175
            for counts in case_site_counts.values()))
    expected_per_case_sums = {case_id: sum(int(n) for n in counts.values())
                              for case_id, counts in case_site_counts.items()}
    aggregate_authority_hits = {
        site_id: sum(int(case_site_counts[case_id][site_id])
                     for case_id in hit_plan.get("case_order", []))
        for site_id in authority_site_ids
    }
    per_case_plan_ok = (per_case_zero_fill
        and expected_per_case_sums == expected_case_counts
        and sum(expected_per_case_sums.values()) == 118
        and aggregate_authority_hits == hit_plan.get("expected_phase_site_hits")
        and sum(value > 0 for value in aggregate_authority_hits.values()) == 75
        and sum(aggregate_authority_hits.values()) == 118
        and hit_plan.get("case_order") == authority_cases.get("case_order"))
    check(checks, "authority per-case plan zero-fills 175 IDs and preserves 9 cases / 118 hits",
          per_case_plan_ok,
          {"case_count": len(case_site_counts), "source_site_count": len(authority_site_ids),
           "case_hit_sums": expected_per_case_sums,
           "planned_total_hits": sum(expected_per_case_sums.values())})
    check(checks, "partial receipts remain observational and cannot be reused; resume is ancestry-pinned",
          authority_cases.get("partial_record_event_prefix_is_observational_only") is True
          and authority_cases.get("partial_case_receipts_joinable") is False
          and authority_cases.get("partial_or_unterminated_case_receipts_joinable") is False
          and authority_cases.get("resume_requires_exact_parent_pipeline_phase_and_child_receipt_ancestry") is True
          and authority_cases.get("resume_skips_only_natural_exit_zero_complete_child_receipts") is True
          and authority_cases.get("resume_policy") ==
              "reuse_only_natural_exit_zero_ancestry_and_actual_hit_receipts_with_exact_current_protocol_inputs_and_case_ids")

    old7 = protocol["attempt7_interruption_basis"]
    old8 = protocol["attempt8_preflight_failure_basis"]
    old9 = protocol["attempt9_projection_preflight_failure_basis"]
    old9b = protocol["attempt9b_static_qa_failure_basis"]
    old9c = protocol["attempt9c_authority_interruption_basis"]
    check(checks, "attempt7-9c failure/interruption ancestry preserved without acceptance",
          old7.get("status") == "phase_wall_timeout_incomplete_not_accepted"
          and old7.get("baseline_phase", {}).get("stop_reason") == "phase_wall_timeout"
          and old7.get("baseline_phase", {}).get("exit_code") == 15
          and old7.get("pre_assertion_observation_count") == 1
          and old8.get("status") == "preserved_natural_exit_failure_not_acceptance"
          and old8.get("observed_preflight_argument_count") == 14
          and old8.get("driver_expected_argument_count") == 16
          and old8.get("observed_preflight_exit_code") == 1
          and old9.get("status") == "preserved_natural_exit_failure_not_acceptance"
          and old9.get("observed_exit_code") == 1
          and "schema mismatch" in old9.get("observed_stderr_final_line", "")
          and old9b.get("status") == "preserved_static_qa_failure_not_acceptance"
          and old9b.get("observed_failure") == {"type": "KeyError", "message": "'manifest_path'"}
          and old9c.get("status") == "resource_interruption_incomplete_not_scientific_fail_not_accepted"
          and old9c.get("authority_phase", {}).get("stop_reason") == "phase_wall_timeout"
          and old9c.get("authority_phase", {}).get("exit_code") == 15
          and all(row.get("formal_t2_accepted") is False
                  for row in (old7, old8, old9, old9b, old9c)))

    driver_path = ROOT / protocol["driver_path"]
    driver_text = driver_path.read_text(encoding="utf-8")
    record_start = driver_text.index(
        "function Test.record(testset::T2NegAssertionSiteTestSet,\n                     result::Test.Result)")
    record_end = driver_text.index(
        "function Test.record(testset::T2NegAssertionSiteTestSet,\n                     child::Test.AbstractTestSet)", record_start)
    record_body = driver_text[record_start:record_end]
    note_at = record_body.find("_t2_neg_authority_progress_note_result!(result, source, site_id)")
    delegate_at = record_body.find("recorded = Test.record(testset.inner, result)")
    progress_append = "function _t2_neg_authority_progress_append!(row::Dict{String,Any})"
    progress_note = "function _t2_neg_authority_progress_note_result!(result::Test.Result,"
    check(checks, "per-case hit count is sourced from actual Test.record events and flushed progress rows",
          "testset.hits[site_id] += 1" in record_body
          and delegate_at >= 0 and note_at > delegate_at
          and progress_append in driver_text and "flush(io)" in
              driver_text[driver_text.index(progress_append):driver_text.index(progress_note)]
          and "record_completed\" => true" in driver_text
          and "site_hit_count_for_case_observed\" => site_count" in driver_text
          and protocol["authority_case_execution_contract"].get(
              "case_site_hits_are_observed_from_test_record") is True
          and protocol.get("actual_source_site_hits") == "pending_julia_execution")

    cache_declared = protocol.get("python_cache_exclusion", {}).get("excluded_files", [])
    cache_now = cache_inventory()
    check(checks, "exact two excluded historical pycs rehashed, no third cache, none in current pins",
          protocol.get("python_cache_exclusion", {}).get("excluded_file_count") == 2
          and protocol.get("python_cache_exclusion", {}).get("cleaned") is False
          and cache_declared == EXPECTED_CACHE
          and cache_now == EXPECTED_CACHE
          and all(row["path"] not in pins for row in cache_now)
          and protocol.get("python_cache_exclusion", {}).get("cache_module_import_targets") == [],
          {"declared": cache_declared, "current": cache_now,
           "all_excluded_from_inputs": all(row["path"] not in pins for row in cache_now)})

    check(checks, "frozen bundle is static-only and execution evidence leaf is absent",
          protocol.get("formal_t2_accepted") is False
          and protocol.get("actual_source_site_hits") == "pending_julia_execution"
          and protocol.get("status") == "frozen_static_ready_not_executed"
          and snapshot.get("julia_started") is False
          and snapshot.get("formal_t2_accepted") is False
          and protocol.get("planned_evidence_directory_absent") is True
          and not (ROOT / protocol["planned_evidence_directory"]).exists()
          and command_data.get("kind") == "non_executable_command_data"
          and command_data.get("julia_started") is False)
    archived = [path for path in ARCHIVE.rglob("*") if path.is_file()]
    banned = {".py", ".pyc", ".jl", ".ps1", ".bat", ".cmd", ".exe", ".dll"}
    check(checks, "attempt10 freeze archive contains data only",
          all(path.suffix.lower() not in banned for path in archived),
          {"file_count": len(archived), "banned_suffixes": sorted(
              {path.suffix.lower() for path in archived if path.suffix.lower() in banned})})

    protocol_sha = receipt(ROOT / PROTOCOL_REL)["sha256"]
    static_run = run_static_qa(protocol, protocol_sha)
    report = static_run["report"] or {}
    controls = report.get("negative_controls", [])
    control_by_name = {row.get("name"): row for row in controls}
    required_control_rows = [control_by_name.get(name) for name in REQUIRED_NEGATIVE_CONTROL_NAMES]
    required_control_missing = [name for name, row in zip(REQUIRED_NEGATIVE_CONTROL_NAMES,
                                                         required_control_rows) if row is None]
    required_control_failed = [row for row in required_control_rows
                               if row is not None and row.get("status") != "pass"]
    check(checks, "frozen Python static QA rerun exit 0 with 102/102 controls",
          static_run["exit_code"] == 0 and report.get("status") == "pass"
          and report.get("negative_control_count") == len(controls) == 102
          and all(row.get("status") == "pass" for row in controls)
          and report.get("julia_executed") is False
          and report.get("julia_parse_executed") is False,
          {"exit_code": static_run["exit_code"], "status": report.get("status"),
           "negative_control_count": len(controls),
           "all_negative_controls_passed": all(row.get("status") == "pass" for row in controls),
           "julia_executed": report.get("julia_executed"),
           "julia_parse_executed": report.get("julia_parse_executed")})
    check(checks, "record/progress/partial/resume/shard argv targeted negatives passed",
          not required_control_missing and not required_control_failed,
          {"required": REQUIRED_NEGATIVE_CONTROL_NAMES,
           "missing": required_control_missing,
           "failed": required_control_failed})
    qa_shards = report.get("actual_formal_shard_argv_contract", {})
    qa_shard_modes = {row.get("mode") for row in qa_shards.get("commands", [])}
    check(checks, "static QA constructed and checked every actual shard argv map pin",
          qa_shards.get("status") == "pass"
          and qa_shards.get("runtime_uses_tested_builder") is True
          and qa_shards.get("expected_driver_argument_count") == 16
          and qa_shards.get("coverage_map_path_index_1_based") == 15
          and qa_shards.get("coverage_map_sha256_index_1_based") == 16
          and qa_shards.get("outer_actual_shard_count") == 4
          and qa_shards.get("authority_case_child_count") == 9
          and qa_shards.get("shard_count") == 12
          and qa_shards.get("negative_controls") == 5
          and qa_shard_modes == set(shard_contract.get("shard_modes", []))
          and all(row.get("coverage_map_path") == str(ROOT / MAP_REL)
                  and row.get("coverage_map_sha256") == EXPECTED[MAP_REL.as_posix()]
                  and row.get("driver_argument_count") == 16
                  for row in qa_shards.get("commands", [])),
          {"status": qa_shards.get("status"), "shard_count": qa_shards.get("shard_count"),
           "outer_shards": qa_shards.get("outer_actual_shard_count"),
           "authority_cases": qa_shards.get("authority_case_child_count"),
           "negative_controls": qa_shards.get("negative_controls"),
           "modes": sorted(qa_shard_modes)})
    # Re-enumerate cache paths after the direct-source QA process: `-B` and the
    # QA loader must not add bytecode or mutate the two excluded historical files.
    cache_after_qa = cache_inventory()
    check(checks, "Python QA rerun did not consume or alter excluded pycs",
          cache_after_qa == EXPECTED_CACHE,
          {"before": cache_now, "after": cache_after_qa,
           "qa_mode": "direct-script -B; frozen QA sets sys.dont_write_bytecode"})

    results = {
        "schema": "independent-t2-attempt10-static-review-v1",
        "verdict": "GO_STATIC_BOUNDED_REVIEW" if all(row["pass"] for row in checks)
            else "NO_GO_STATIC_REVIEW",
        "scope": "Read-only static and Python-only negative-control verification of attempt10; Julia was not started by this independent tester.",
        "frozen_bundle": actual_bundle,
        "static_qa_replay": {
            "command": static_run["command"],
            "exit_code": static_run["exit_code"],
            "elapsed_seconds": static_run["elapsed_seconds"],
            "report": receipt(static_run["report_path"],
                              static_run["report_path"].resolve().relative_to(ROOT).as_posix())
                if static_run["report_path"].is_file() else None,
            "stdout": receipt(static_run["stdout_path"],
                              static_run["stdout_path"].resolve().relative_to(ROOT).as_posix()),
            "stderr": receipt(static_run["stderr_path"],
                              static_run["stderr_path"].resolve().relative_to(ROOT).as_posix()),
            "negative_control_count": len(controls),
            "required_negative_controls": [row for row in required_control_rows if row is not None],
        },
        "input_closure": {
            "pinned_count": len(pins),
            "rehashed_count": len(input_receipts),
            "mismatch_count": len(mismatches),
            "receipts": input_receipts,
        },
        "coverage_preservation": {
            "formal_case_count": len(formal_ids),
            "unique_case_count": len(all_case_ids),
            "runtime_case_hit_count": sum(int(value) for value in case_counts.values()),
            "site_count": len(current_sites),
            "planned_site_hits": site_hit_sum,
            "phase_hit_sum": site_phase_sum,
            "relocated_path_count": reloc_path_changes,
            "relocated_line_count": reloc_line_changes,
            "stable_site_count": stable_sites,
            "line_delta_counts": delta_counts,
            "verified_current_source_lines": current_line_checks,
            "old_site_count": coverage.get("old_assertion_site_count"),
            "old_expected_hits": coverage.get("old_expected_runtime_hit_count"),
        },
        "authority_case_plan": {
            "order": hit_plan.get("case_order"),
            "zero_filled_source_sites_per_case": len(authority_site_ids),
            "per_case_static_hit_sums": expected_per_case_sums,
            "aggregate_static_hits": sum(expected_per_case_sums.values()),
            "actual_site_hits": protocol.get("actual_source_site_hits"),
            "partial_prefix_status": report.get("authority_partial_prefix_contract"),
            "resume_status": report.get("authority_resume_ancestry_contract"),
        },
        "resources": {
            "phase_seconds": protocol.get("resource_gates", {}).get("phase_wall_seconds"),
            "authority_case_seconds": protocol.get("resource_gates", {}).get("authority_case_wall_seconds"),
            "authority_invocation_seconds": protocol.get("resource_gates", {}).get("authority_phase_wall_seconds"),
            "working_set_bytes": protocol.get("resource_gates", {}).get("process_tree_working_set_bytes"),
            "julia_threads": protocol.get("resource_gates", {}).get("julia_threads"),
            "openblas_threads": protocol.get("resource_gates", {}).get("openblas_threads"),
            "coverage_thresholds_changed": protocol.get("authority_case_budget_change", {}).get("coverage_thresholds_changed"),
        },
        "excluded_bytecode_files": cache_after_qa,
        "checks": checks,
        "limits": [
            "622 is the frozen planned hit count; no Julia Test.record hits were observed by this static review.",
            "A static GO is not formal T2 acceptance, numerical evidence or physics evidence.",
        ],
    }
    verification_path = EVIDENCE / "verification.json"
    verification_path.write_text(json.dumps(results, ensure_ascii=False,
        sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    test_receipt = receipt(Path(__file__).resolve(), TEST_REL)
    manifest = {
        "schema": "independent-t2-attempt10-static-review-manifest-v1",
        "verification": receipt(verification_path,
            verification_path.resolve().relative_to(ROOT).as_posix()),
        "tester_source": test_receipt,
        "protocol": actual_bundle[PROTOCOL_REL.as_posix()],
        "coverage_map": actual_bundle[MAP_REL.as_posix()],
        "static_qa_frozen": actual_bundle[QA_REL.as_posix()],
        "input_count_rehashed": len(input_receipts),
        "negative_controls_replayed": len(controls),
        "static_qa_replay_exit_code": static_run["exit_code"],
        "julia_started": False,
        "archive_payload_kind": "evidence_only_data",
    }
    manifest_path = EVIDENCE / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False,
        sort_keys=True, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({
        "verdict": results["verdict"],
        "checks_passed": sum(row["pass"] for row in checks),
        "checks_total": len(checks),
        "input_count_rehashed": len(input_receipts),
        "static_qa_exit": static_run["exit_code"],
        "negative_controls": len(controls),
        "relocated_sites": reloc_path_changes,
        "line_delta_counts": delta_counts,
        "verification_sha256": sha(verification_path.read_bytes()),
        "manifest_sha256": sha(manifest_path.read_bytes()),
    }, sort_keys=True))
    return 0 if all(row["pass"] for row in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
