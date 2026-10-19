from __future__ import annotations

import csv
import hashlib
import json
import runpy
import sys
from datetime import datetime, timezone
from pathlib import Path
from types import SimpleNamespace


ROOT = Path(__file__).resolve().parents[5]
LEAF = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry3"
ATTEMPT10 = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt10_case_progress"
ATTEMPT7_MAP = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260923_t2_protocol/coverage_map_r2.json"
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
CONTROLLER = TEST_ROOT / "independent_negative_controller_r10.py"
RUN_ONCE = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/root_attempt11_grant_20260924/run_once.py"
EXPECTED = {
    "protocol.json": "5731a35854292096feafb1838cfd1ff2811d62f1eccc6a150246b160928bd1e0",
    "coverage_map_r8.json": "9fb16233ae8c0c4373781450c3f1bffedd3373f4e5a6e44f34f804132f93df41",
    "static_qa.json": "c0770174cb2e363ee1a901e6f1c87e4aa3688a1a5a551a2a979b00492d13061c",
    "freeze_snapshot.json": "be30ee559e74281671d041770264fd806aae7c10da34fee7347bdb8349b0f73f",
    "dispatch.json": "018507844889043f4b3064cbfba13b72ee0eeca4257383e2febcab72dac58fb9",
    "command_argv.json": "dc2fedc31fec43602ef4400f3a60545351aa3b416be760d27bdb53161e5337b0",
    "independent_negative_controller_r10.py": "a80b3e1b92b040ab645569abbabd63fc4597b9d7419e1c20d91db4c0c5566152",
    "actual_formal_negative_driver_r6.jl": "5a71c6417cadd04c3f36f8461134de46f455debdf7c6e9f804181c589c3b590e",
    "build_coverage_map_r8.py": "5f991a6fba45eacfe5e82c306d8dfef8897ef12de7eeb2efaaecaebca8843327",
    "static_qa_independent_negative_r9.py": "1f2aebfd08a6afc3a541c3223171f51a15e80e9af18213f23647fbe1fb2a9773",
    "freeze_independent_negative_protocol_r9.py": "c509a878e71e45481b00b865e89b92b1c293bbdeff966d592b1f2ca03331e4e3",
    "validate_projection24_reuse_r4.py": "bb0f40d1dbe5b7507657e4e60442ec6b6b027cca223d4eaed7ddcd56fb99b297",
    "run_once.py": "5d6cf4c135bdc2ece734fbfe8ab0fd10e3e6025021a10eda457eec1634c6cccf",
}


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def file_receipt(path: Path) -> dict:
    raw = path.read_bytes()
    return {"path": path.relative_to(ROOT).as_posix(), "bytes": len(raw), "sha256": sha(raw)}


def assert_check(condition: bool, label: str, results: list[dict]) -> None:
    results.append({"check": label, "status": "pass" if condition else "fail"})
    if not condition:
        raise AssertionError(label)


def assertion_expression(lines: list[str], line_number: int) -> str:
    index = line_number - 1
    if index < 0 or index >= len(lines):
        raise AssertionError(f"source line missing: {line_number}")
    first = lines[index]
    stripped = first.lstrip()
    if not (stripped.startswith("@test ") or stripped.startswith("@test\n") or stripped.startswith("@test_throws ")):
        raise AssertionError(f"assertion macro absent at line {line_number}")
    indent = len(first) - len(stripped)
    body = [stripped]
    cursor = index + 1
    while cursor < len(lines):
        candidate = lines[cursor]
        candidate_stripped = candidate.lstrip()
        candidate_indent = len(candidate) - len(candidate_stripped)
        if not candidate_stripped or candidate_stripped.startswith("#") or candidate_indent <= indent:
            break
        body.append(candidate_stripped)
        cursor += 1
    return " ".join(part.strip() for part in body)


def verify_launcher_fake_controls(results: list[dict]) -> dict:
    import ast

    import_ns = runpy.run_path(str(RUN_ONCE), run_name="independent_static_probe")
    source = RUN_ONCE.read_text(encoding="utf-8")
    ast.parse(source, filename=str(RUN_ONCE))
    subprocess_module = import_ns["subprocess"]
    saved_run = subprocess_module.run
    calls: list[tuple[list[str], dict]] = []

    class FakeProcess:
        def __init__(self, pid=4321, name=None):
            self.pid = pid
            self.info = {"name": name}

    try:
        direct = import_ns["process_name"](FakeProcess(name="python.exe"))
        assert_check(direct == "python.exe", "launcher direct name path", results)

        def valid_tasklist(argv, **kwargs):
            calls.append((argv, kwargs))
            return SimpleNamespace(returncode=0, stdout='"julia.exe","4321","Console","1","12 K"\r\n')

        subprocess_module.run = valid_tasklist
        fallback = import_ns["process_name"](FakeProcess(name=None))
        assert_check(fallback == "julia.exe", "launcher missing-name tasklist fallback", results)
        assert_check(
            calls[0][0] == ["tasklist", "/FI", "PID eq 4321", "/FO", "CSV", "/NH"]
            and calls[0][1] == {"capture_output": True, "text": True, "check": False},
            "launcher fallback argv and captured CSV contract",
            results,
        )

        bad_rows = [
            (1, '"julia.exe","4321","Console","1","12 K"\n'),
            (0, ""),
            (0, "INFO: No tasks are running...\n"),
            (0, '"julia.exe","9999","Console","1","12 K"\n'),
            (0, '","4321","Console","1","12 K"\n'),
            (0, '"julia.exe","4321","Console","1"\n'),
            (0, '"julia.exe","4321","Console","1","12 K"\n"x.exe","4321","Console","1","1 K"\n'),
        ]
        for index, (returncode, stdout) in enumerate(bad_rows, start=1):
            subprocess_module.run = lambda argv, _rc=returncode, _out=stdout, **kwargs: SimpleNamespace(returncode=_rc, stdout=_out)
            try:
                import_ns["process_name"](FakeProcess(name=None))
            except RuntimeError:
                continue
            raise AssertionError(f"launcher accepted malformed fallback case {index}")
        assert_check(True, "launcher seven malformed/failing tasklist results reject", results)
    finally:
        subprocess_module.run = saved_run

    assert_check('name.lower() == "julia.exe"' in source and "process_name(process)" in source, "launcher Julia process filter is present", results)
    return {"source": file_receipt(RUN_ONCE), "fake_controls": 10, "windows_tasklist_end_to_end": "not_run", "main_called": False}


def main() -> int:
    checks: list[dict] = []
    protocol_path = LEAF / "protocol.json"
    map_path = LEAF / "coverage_map_r8.json"
    qa_path = LEAF / "static_qa.json"
    protocol = read_json(protocol_path)
    coverage = read_json(map_path)
    qa = read_json(qa_path)
    previous_protocol = read_json(ATTEMPT10 / "protocol.json")
    previous_map = read_json(ATTEMPT7_MAP)
    receipts = {
        "protocol": file_receipt(protocol_path),
        "coverage_map": file_receipt(map_path),
        "static_qa": file_receipt(qa_path),
        "freeze_snapshot": file_receipt(LEAF / "freeze_snapshot.json"),
        "dispatch": file_receipt(LEAF / "dispatch.json"),
        "command_argv": file_receipt(LEAF / "command_argv.json"),
        "static_qa_stdout": file_receipt(LEAF / "static_qa.stdout.raw"),
        "static_qa_stderr": file_receipt(LEAF / "static_qa.stderr.raw"),
        "projection_phase": file_receipt(LEAF / "projection24_reuse_preflight/phase.json"),
        "projection_receipt": file_receipt(LEAF / "projection24_reuse_preflight/reuse_receipt.json"),
        "projection_stdout": file_receipt(LEAF / "projection24_reuse_preflight/stdout.raw"),
        "projection_stderr": file_receipt(LEAF / "projection24_reuse_preflight/stderr.raw"),
        "controller": file_receipt(CONTROLLER),
        "driver": file_receipt(TEST_ROOT / "actual_formal_negative_driver_r6.jl"),
        "map_builder": file_receipt(TEST_ROOT / "build_coverage_map_r8.py"),
        "static_qa_source": file_receipt(TEST_ROOT / "static_qa_independent_negative_r9.py"),
        "freezer": file_receipt(TEST_ROOT / "freeze_independent_negative_protocol_r9.py"),
        "projection_validator": file_receipt(TEST_ROOT / "validate_projection24_reuse_r4.py"),
    }
    for name, expected in EXPECTED.items():
        if name == "run_once.py":
            actual = sha(RUN_ONCE.read_bytes())
        else:
            actual = receipts[{
            "protocol.json": "protocol", "coverage_map_r8.json": "coverage_map",
            "static_qa.json": "static_qa", "freeze_snapshot.json": "freeze_snapshot",
            "dispatch.json": "dispatch", "command_argv.json": "command_argv",
            "independent_negative_controller_r10.py": "controller",
            "actual_formal_negative_driver_r6.jl": "driver", "build_coverage_map_r8.py": "map_builder",
            "static_qa_independent_negative_r9.py": "static_qa_source",
            "freeze_independent_negative_protocol_r9.py": "freezer",
            "validate_projection24_reuse_r4.py": "projection_validator",
            }[name]].get("sha256")
        assert_check(actual == expected, f"frozen hash {name}", checks)

    input_pins = protocol["inputs"]
    mismatches = []
    for key, pin in input_pins.items():
        path = ROOT / pin["path"]
        if pin["path"] != key or not path.is_file():
            mismatches.append({"path": key, "reason": "path_or_missing"})
            continue
        raw = path.read_bytes()
        if len(raw) != pin["bytes"] or sha(raw) != pin["sha256"]:
            mismatches.append({"path": key, "reason": "bytes_or_sha"})
    assert_check(len(input_pins) == 368 and not mismatches, "368 current input pins rehashed", checks)

    previous_pins = previous_protocol["inputs"]
    added = sorted(set(input_pins) - set(previous_pins))
    missing = sorted(set(previous_pins) - set(input_pins))
    changed_shared = sorted(
        path for path in set(input_pins) & set(previous_pins)
        if input_pins[path]["bytes"] != previous_pins[path]["bytes"]
        or input_pins[path]["sha256"] != previous_pins[path]["sha256"]
    )
    assert_check(len(previous_pins) == 319 and len(added) == 49 and not missing and not changed_shared,
                 "attempt10 input closure preserved with 49 explained lineage/tool additions", checks)

    positive = protocol["positive_reuse_input_pins"]
    positive_bad = [path for path, pin in positive.items() if path not in input_pins or input_pins[path] != pin]
    assert_check(len(positive) == 104 and not positive_bad, "104 positive pins exact-join current input closure", checks)

    assert_check(protocol["expected_phase_count"] == 30 and len(protocol["phase_order"]) == 30,
                 "30 ordered phases", checks)
    current_cases = {item["id"]: item for item in coverage["successor_cases"]}
    old_cases = {item["id"]: item for item in previous_map["successor_cases"]}
    runtime = coverage["runtime_execution_plan"]
    hit_counts = runtime["expected_runtime_case_hit_counts"]
    formal_ids = runtime["actual_formal_summary_case_ids"]
    old_formal_ids = previous_map["runtime_execution_plan"]["actual_formal_summary_case_ids"]
    assert_check(
        len(current_cases) == 60 and set(current_cases) == set(old_cases)
        and len(formal_ids) == 45 and set(formal_ids) == set(old_formal_ids)
        and runtime["expected_unique_case_count"] == 60
        and runtime["expected_runtime_case_hit_count"] == 68
        and sum(hit_counts.values()) == 68,
        "45 formal IDs, 60 unique case IDs, 68 runtime case hits preserved",
        checks,
    )

    sites = {item["id"]: item for item in coverage["successor_assertion_sites"]}
    old_sites = {item["id"]: item for item in previous_map["successor_assertion_sites"]}
    semantic_fields = ("macro_name", "source_text", "source_text_sha256", "runtime_multiplicity", "expected_phase_hits")
    semantic_diff = [
        site_id for site_id in set(sites) & set(old_sites)
        if any(sites[site_id][field] != old_sites[site_id][field] for field in semantic_fields)
    ]
    current_source_diff = []
    source_lines: dict[str, list[str]] = {}
    for site_id, site in sites.items():
        source_path = site["path"]
        source_lines.setdefault(source_path, (ROOT / source_path).read_text(encoding="utf-8").splitlines())
        expression = assertion_expression(source_lines[source_path], site["line"])
        if expression != site["source_text"] or sha(expression.encode("utf-8")) != site["source_text_sha256"]:
            current_source_diff.append(site_id)
    ledger = protocol["attempt7_coverage_comparison"]["path_line_relocation_ledger"]
    ledger_entries = ledger["entries"]
    assert_check(
        len(sites) == 214 and set(sites) == set(old_sites)
        and coverage["successor_assertion_site_count"] == 214
        and coverage["successor_expected_runtime_hit_count"] == 622
        and len(semantic_diff) == 0 and len(current_source_diff) == 0
        and len(ledger_entries) == 214
        and all(row["current_source_line_verified"] and row["source_text_matches_attempt7"] for row in ledger_entries),
        "214 sites and 622 planned hits preserve text/hash/multiplicity/phase semantics and resolve to current source",
        checks,
    )

    controls = qa["negative_controls"]
    control_names = [row["name"] for row in controls]
    assert_check(qa["status"] == "pass" and len(controls) == 131
                 and len(set(control_names)) == 131 and all(row["status"] == "pass" for row in controls),
                 "owner static QA receipt has 131 unique passing negative controls", checks)

    gates = protocol["resource_gates"]
    preflight_delta = protocol["preflight_phase_budget_change"]
    authority_delta = protocol["authority_case_budget_change"]
    assert_check(
        gates["phase_wall_seconds"] == 480
        and gates["phase_wall_timeout_overrides"] == {"actual_formal_preflight": 600}
        and gates["authority_phase_wall_seconds"] == 2400
        and gates["authority_case_wall_seconds"] == 2400
        and gates["process_tree_working_set_bytes"] == 2147483648
        and gates["julia_threads"] == 1 and gates["openblas_threads"] == 1
        and preflight_delta["only_phase_override"] == "actual_formal_preflight"
        and preflight_delta["coverage_thresholds_changed"] is False
        and authority_delta["authority_invocation_timeout_seconds"] == 2400
        and authority_delta["effective_child_timeout_policy"] == "min(per_case_cap, remaining_invocation_budget)"
        and authority_delta["coverage_thresholds_changed"] is False,
        "480s ordinary / 600s preflight-only / 2400s authority / 2GiB / 1+1 thread gates",
        checks,
    )

    shard_contract = qa["actual_formal_shard_argv_contract"]
    expected_map_abs = str(map_path.resolve())
    bad_shards = [row for row in shard_contract["commands"]
                  if row["driver_argument_count"] != 16
                  or row["coverage_map_path"] != expected_map_abs
                  or row["coverage_map_sha256"] != receipts["coverage_map"]["sha256"]]
    assert_check(shard_contract["status"] == "pass" and shard_contract["shard_count"] == 12
                 and len(shard_contract["commands"]) == 12 and not bad_shards,
                 "12 actual shard commands retain 16 arguments and exact map path/hash", checks)

    projection = protocol["projection24_reuse"]
    dependency_subset = projection["dependency_subset"]
    dependency_bad = [path for path, pin in dependency_subset.items()
                      if path not in input_pins or input_pins[path] != pin]
    reuse_phase = read_json(LEAF / "projection24_reuse_preflight/phase.json")
    reuse_receipt = read_json(LEAF / "projection24_reuse_preflight/reuse_receipt.json")
    group_hits = sum(reuse_receipt["semantic_group_site_counts"].values())
    reuse_stdout = (LEAF / "projection24_reuse_preflight/stdout.raw").read_text(encoding="utf-8")
    assert_check(
        projection["source_input_count"] == 157
        and projection["r1_input_intersection_count"] == 151
        and projection["excluded_r1_input_count"] == 6
        and projection["dependency_count"] == 159
        and len(dependency_subset) == 159 and not dependency_bad
        and reuse_phase["exit_code"] == 0 and reuse_phase["stop_reason"] == "natural_exit"
        and reuse_phase["pass_marker_observed"] and "T2_PROJECTION24_REUSE=PASS sites=24 groups=4" in reuse_stdout
        and reuse_receipt["status"] == "pass" and group_hits == 24,
        "projection reuse preflight natural exit, exact 159-pin dependency join and 24/4 groups",
        checks,
    )

    cache_contract = protocol["python_cache_exclusion"]
    cache_dir = TEST_ROOT / "__pycache__"
    cache_files = sorted(cache_dir.glob("*.pyc"))
    cache_rows = [{"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}
                  for path in cache_files]
    expected_cache = sorted(cache_contract["excluded_files"], key=lambda row: row["path"])
    assert_check(len(cache_files) == 2 and cache_rows == expected_cache
                 and all(row["path"] not in input_pins for row in expected_cache)
                 and cache_contract["cleaned"] is False,
                 "exactly two pre-existing excluded pycs remain unchanged and out of input closure", checks)

    lineage = {
        "attempt10": protocol["attempt10_preflight_interruption_basis"]["status"],
        "initial": protocol["attempt11_initial_freeze_failure_basis"]["status"],
        "retry1": protocol["attempt11_retry1_static_qa_failure_basis"]["status"],
        "retry2": protocol["attempt11_retry2_static_qa_failure_basis"]["status"],
    }
    assert_check(lineage["attempt10"] == "preserved_resource_interruption_partial_not_scientific_failure"
                 and lineage["initial"] == "preserved_pre_execution_freezer_failure_only"
                 and lineage["retry1"] == "preserved_static_qa_failure_only_no_julia"
                 and lineage["retry2"] == "preserved_static_qa_failure_only_no_julia",
                 "attempt10 interruption and attempt11 failed ancestry remain typed and pinned", checks)

    leaf_files = [p for p in LEAF.rglob("*") if p.is_file()]
    executable = [p.relative_to(ROOT).as_posix() for p in leaf_files
                  if p.suffix.lower() in {".py", ".jl", ".ps1", ".psm1", ".bat", ".cmd", ".exe", ".com"}]
    command_data = read_json(LEAF / "command_argv.json")
    snapshot = read_json(LEAF / "freeze_snapshot.json")
    assert_check(not executable and command_data["kind"] == "non_executable_command_data"
                 and protocol["status"] == "frozen_static_ready_not_executed"
                 and protocol["formal_t2_accepted"] is False
                 and protocol["actual_source_site_hits"] == "pending_julia_execution"
                 and snapshot["julia_started"] is False
                 and not (ROOT / protocol["planned_evidence_directory"]).exists(),
                 "evidence-only archive, planned runtime output absent and no Julia execution", checks)

    controller_ns = runpy.run_path(str(CONTROLLER), run_name="independent_static_probe")
    psutil_module = controller_ns["psutil"]

    class FakeProcess:
        def __init__(self, pid, rss=None, child=None, deny_rss=False, deny_enum=False):
            self.pid, self._rss, self._child = pid, rss, child
            self._deny_rss, self._deny_enum = deny_rss, deny_enum

        def children(self, recursive=True):
            if self._deny_enum:
                raise psutil_module.AccessDenied(pid=self.pid)
            return [self._child] if self._child else []

        def memory_info(self):
            if self._deny_rss:
                raise psutil_module.AccessDenied(pid=self.pid)
            return SimpleNamespace(rss=self._rss)

        def cpu_times(self):
            return SimpleNamespace(user=0.0, system=0.0)

        def create_time(self):
            return float(self.pid)

    root_rss = 1288490188
    hidden_child_rss = 1288490188
    limit = gates["process_tree_working_set_bytes"]
    hidden_child = FakeProcess(4322, deny_rss=True)
    root_process = FakeProcess(4321, rss=root_rss, child=hidden_child)
    sample = controller_ns["process_tree_sample"](root_process)
    controller_source = CONTROLLER.read_text(encoding="utf-8")
    run_phase_source = controller_source[controller_source.index("def run_phase("):controller_source.index("\ndef require_natural(")]
    resource_fail_open = (
        root_rss + hidden_child_rss > limit
        and sample["process_tree_working_set_bytes"] == root_rss
        and sample["process_tree_working_set_bytes"] < limit
        and len(sample["processes"]) == 1
        and not any(key in sample for key in ("complete", "sample_complete", "errors", "enumeration_complete"))
        and 'if sample["process_tree_working_set_bytes"] >=' in run_phase_source
        and 'sample["complete"]' not in run_phase_source
    )
    assert_check(resource_fail_open, "controller incomplete child RSS is accepted as below hard cap (NO-GO defect reproduced)", checks)

    launcher_summary = verify_launcher_fake_controls(checks)
    verdict = "NO_GO_RESOURCE_SAMPLE_FAIL_OPEN"
    output = {
        "schema": "independent-vnext-t2-attempt11-retry3-review-r1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "verdict": verdict,
        "formal_t2_accepted": False,
        "julia_started": False,
        "actual_site_hits": "pending_julia_execution",
        "checks": checks,
        "check_count": len(checks),
        "failed_static_contract_checks": [row["check"] for row in checks if row["status"] != "pass"],
        "frozen_receipts": receipts,
        "input_pin_audit": {
            "count": len(input_pins), "mismatch_count": len(mismatches),
            "attempt10_count": len(previous_pins), "added": len(added),
            "missing": len(missing), "changed_shared": len(changed_shared),
            "positive_pin_count": len(positive),
        },
        "coverage_audit": {
            "phase_count": len(protocol["phase_order"]), "formal_case_count": len(formal_ids),
            "unique_case_count": len(current_cases), "runtime_case_hit_count": sum(hit_counts.values()),
            "site_count": len(sites), "planned_hit_count": coverage["successor_expected_runtime_hit_count"],
            "semantic_site_diffs": len(semantic_diff), "current_source_expression_mismatches": len(current_source_diff),
            "ledger_site_count": len(ledger_entries),
            "path_changed_count": sum(bool(row["path_changed"]) for row in ledger_entries),
            "line_changed_count": sum(row["line_delta"] != 0 for row in ledger_entries),
            "line_delta_values": sorted({row["line_delta"] for row in ledger_entries}),
        },
        "resource_policy": gates,
        "resource_fail_open_counterexample": {
            "observed_root_rss_bytes": root_rss,
            "unreadable_child_rss_bytes_in_fixture": hidden_child_rss,
            "fixture_tree_rss_lower_bound_bytes": root_rss + hidden_child_rss,
            "hard_limit_bytes": limit,
            "reported_sample_rss_bytes": sample["process_tree_working_set_bytes"],
            "reported_process_rows": sample["processes"],
            "sample_completeness_field_present": False,
            "run_phase_completeness_guard_present": False,
            "controller_source_lines": {"children_error_swallowed": "207-210", "per_process_error_skipped": "215-228", "unconditional_rss_limit_comparison": "279-285"},
        },
        "owner_static_qa": {"status": qa["status"], "negative_control_count": len(controls), "all_pass": all(row["status"] == "pass" for row in controls), "resource_fail_open_caught": False},
        "owner_run_receipts": {
            "freeze_exit_code": 0,
            "static_qa_exit_code": 0,
            "static_qa_stderr_empty": not (LEAF / "static_qa.stderr.raw").read_bytes(),
            "projection_preflight_exit_code": reuse_phase["exit_code"],
        },
        "lineage": lineage,
        "launcher_static_probe": launcher_summary,
        "commands": {
            "independent_python": [sys.executable, "-B", Path(__file__).resolve().relative_to(ROOT).as_posix(), *sys.argv[1:]],
            "exit_code": 0,
            "scope": "Python-only/static and fake-object probes; no controller main, Julia, or runtime shard was launched",
        },
    }
    if len(sys.argv) > 1 and sys.argv[1] == "--write-receipt":
        target = ROOT / sys.argv[2]
        target.parent.mkdir(parents=True, exist_ok=True)
        raw = (json.dumps(output, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        target.write_bytes(raw)
        output["written_receipt"] = file_receipt(target)
    print(json.dumps(output, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
