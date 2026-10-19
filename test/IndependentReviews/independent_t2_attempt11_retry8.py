from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/r2_protocol_freeze_20260924_t2_protocol_attempt11_preflight_600s_retry8"
PROTOCOL_PATH = BASE / "protocol.json"
MAP_PATH = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/coverage_map_r11.json"
CONTROLLER_PATH = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r13.py"
STATIC_QA_PATH = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r13.py"
OUT = ROOT / "docs/implementation/UP1-04A-VNEXT-T2/archive/independent_t2_attempt11_retry8_static_tester_20260924_v3"

EXPECTED_PROTOCOL = "e5ddc50030d82c1532dd18538f06adabcc7b10d3500241075c4062a813c5b965"
EXPECTED_MAP = "b20a3081025442899f4b7e880dfd1d864413d65afdd678f135a1cb3af2e099f7"
EXPECTED_QA = "ed0e3ad8a800cd6647bcb3acca1405025c6b65631f662c26c509bfba178ed92a"
EXPECTED_CONTROLLER = "876b324e8dae38f3b5b3477d2e0f75f66abc32125aa06d050bedb4b0120eb863"
EXPECTED_DRIVER = "5a71c6417cadd04c3f36f8461134de46f455debdf7c6e9f804181c589c3b590e"
EXPECTED_VALIDATOR = "3210149a408a93d812ae8b1e4fcf45f4877b318e079364ae0774c90c75aab424"
EXPECTED_BUILDER = "aae483a51178f9ca19d67d80983b37f58b7da4e0ae741c08b59b7cb3e1ae7a2c"
EXPECTED_FREEZER = "709034f8075f9b7a0ee064174a333442aa2101fa847478eec5a04d15d87b7fcb"
EXPECTED_QA_SOURCE = "ae32f430fc338a91d8bbd3b8722d5810826dfa7d418e7bc2dc4e2eccd5f0f1c2"
EXPECTED_SNAPSHOT = "8da9bce3f77842417ac9fb8fcd51fe461fb312bcadac056c5171f56b93aa9701"
EXPECTED_DISPATCH = "83e83b7293c339bfe9d12d528ae3c1b4baa781096455b2373d6306b7fb6b326f"
EXPECTED_COMMAND = "a18d3cc0b4f9ceb158ae53cb59c9d47b75ce1f71ade13456eaa1ff775c608768"


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def canonical_json(value: Any) -> bytes:
    def safe(item: Any) -> Any:
        if isinstance(item, float) and not math.isfinite(item):
            return {"nonfinite_float": repr(item)}
        if isinstance(item, dict):
            return {str(key): safe(child) for key, child in item.items()}
        if isinstance(item, (list, tuple)):
            return [safe(child) for child in item]
        return item
    return (json.dumps(safe(value), ensure_ascii=False, sort_keys=True,
                       indent=2, allow_nan=False) + "\n").encode("utf-8")


def write_new(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def load_controller() -> Any:
    spec = importlib.util.spec_from_file_location("retry8_controller_r13", CONTROLLER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load frozen controller r13 source")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class FakeProcess:
    def __init__(self, pid: Any, ppid: Any, created: Any, *, rss: Any = 0,
                 cpu_user: Any = 0.0, cpu_system: Any = 0.0,
                 children: list["FakeProcess"] | None = None,
                 name: str = "worker.exe", live_created: Any = None) -> None:
        self.pid = pid
        self.parent_pid = ppid
        self.created = created
        self.live_created = created if live_created is None else live_created
        self.rss = rss
        self.cpu_user = cpu_user
        self.cpu_system = cpu_system
        self.child_processes = children or []
        self.process_name = name
        self.kill_calls = 0
        self._running = True

    def create_time(self) -> Any:
        return self.live_created

    def is_running(self) -> bool:
        return self._running

    def children(self, recursive: bool = False) -> list["FakeProcess"]:
        return list(self.child_processes)

    def memory_info(self) -> SimpleNamespace:
        return SimpleNamespace(rss=self.rss)

    def cpu_times(self) -> SimpleNamespace:
        return SimpleNamespace(user=self.cpu_user, system=self.cpu_system)

    def kill(self) -> None:
        self.kill_calls += 1
        self._running = False

    def name(self) -> str:
        return self.process_name

    def cmdline(self) -> list[str]:
        return [self.process_name]


class FakeLaunch:
    def __init__(self, pid: Any, created: Any) -> None:
        self.pid = pid
        self.created = created

    def create_time(self) -> Any:
        return self.created


class FakePsutil:
    class NoSuchProcess(Exception):
        pass

    class ZombieProcess(Exception):
        pass

    def __init__(self, rows: list[dict[str, Any]],
                 live: dict[int, FakeProcess] | None = None) -> None:
        self.rows = [dict(row) for row in rows]
        self.live = live or {}

    def pids(self) -> list[Any]:
        return [row.get("pid") for row in self.rows]

    def process_iter(self, attrs: Any = None, ad_value: Any = None) -> list[Any]:
        return [SimpleNamespace(info=dict(row)) for row in self.rows]

    def Process(self, pid: int) -> FakeProcess:
        if pid in self.live:
            return self.live[pid]
        for row in self.rows:
            if row.get("pid") == pid:
                return FakeProcess(pid, row.get("ppid"), row.get("create_time"),
                                   name=row.get("name", "worker.exe"))
        raise self.NoSuchProcess(pid)

    def wait_procs(self, processes: list[Any], timeout: float = 0) -> tuple[list[Any], list[Any]]:
        return list(processes), []


def collect_pin_records(value: Any, prefix: str = "") -> list[dict[str, Any]]:
    found: list[dict[str, Any]] = []
    if isinstance(value, dict):
        if isinstance(value.get("path"), str) and isinstance(value.get("sha256"), str):
            found.append({"path": value["path"], "sha256": value["sha256"],
                          "bytes": value.get("bytes"), "key": prefix})
        else:
            for key, child in value.items():
                found.extend(collect_pin_records(child, f"{prefix}.{key}" if prefix else key))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(collect_pin_records(child, f"{prefix}[{index}]"))
    return found


def main() -> int:
    if OUT.exists():
        raise FileExistsError(f"evidence leaf already exists: {OUT}")
    OUT.mkdir(parents=True, exist_ok=False)
    observations: list[dict[str, Any]] = []

    def record(name: str, passed: bool, detail: str, **extra: Any) -> None:
        observations.append({"name": name, "passed": bool(passed), "detail": detail, **extra})

    protocol_bytes = PROTOCOL_PATH.read_bytes()
    protocol = json.loads(protocol_bytes)
    coverage = json.loads(MAP_PATH.read_text(encoding="utf-8"))
    qa_frozen = json.loads((BASE / "static_qa.json").read_text(encoding="utf-8"))
    frozen_files = {
        str(PROTOCOL_PATH.relative_to(ROOT)): EXPECTED_PROTOCOL,
        str(MAP_PATH.relative_to(ROOT)): EXPECTED_MAP,
        str((BASE / "static_qa.json").relative_to(ROOT)): EXPECTED_QA,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r13.py": EXPECTED_CONTROLLER,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/actual_formal_negative_driver_r6.jl": EXPECTED_DRIVER,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/validate_projection24_reuse_r6.py": EXPECTED_VALIDATOR,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/build_coverage_map_r7.py": EXPECTED_BUILDER,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/freeze_independent_negative_protocol_r13.py": EXPECTED_FREEZER,
        "test/GenomeV5/Integration/VNextT2FormalIndependentR1/static_qa_independent_negative_r13.py": EXPECTED_QA_SOURCE,
        str((BASE / "freeze_snapshot.json").relative_to(ROOT)): EXPECTED_SNAPSHOT,
        str((BASE / "dispatch.json").relative_to(ROOT)): EXPECTED_DISPATCH,
        str((BASE / "command_argv.json").relative_to(ROOT)): EXPECTED_COMMAND,
    }
    anchor_results = []
    for relative, expected in frozen_files.items():
        path = ROOT / relative
        observed = sha256_file(path) if path.is_file() else None
        anchor_results.append({"path": relative, "expected_sha256": expected,
                               "observed_sha256": observed,
                               "bytes": path.stat().st_size if path.is_file() else None,
                               "match": observed == expected})
    record("frozen_anchor_hashes", all(item["match"] for item in anchor_results),
           "protocol, map, static QA, sources, dispatch, command, and snapshot match the final retry8 handoff",
           anchors=anchor_results)

    inputs = protocol.get("inputs", {})
    input_results = []
    if isinstance(inputs, dict):
        for relative, pin in inputs.items():
            path = ROOT / relative
            observed_sha = sha256_file(path) if path.is_file() else None
            observed_bytes = path.stat().st_size if path.is_file() else None
            input_results.append({"path": relative, "expected_sha256": pin.get("sha256"),
                                  "observed_sha256": observed_sha,
                                  "expected_bytes": pin.get("bytes"),
                                  "observed_bytes": observed_bytes,
                                  "match": observed_sha == pin.get("sha256") and
                                           observed_bytes == pin.get("bytes")})
    record("current_input_closure", len(input_results) == 459 and
           all(item["match"] for item in input_results),
           "rehash each current protocol input pin by path, byte length, and SHA-256",
           declared_input_count=protocol.get("input_count"),
           verified_input_count=len(input_results),
           mismatches=[item for item in input_results if not item["match"]],
           input_hash_receipt_path="current_input_hashes.json")
    write_new(OUT / "current_input_hashes.json", canonical_json(input_results))

    lineage = protocol.get("attempt11_retry5_retry6_static_failure_lineage", {})
    lineage_results: dict[str, Any] = {}
    for retry in ("retry5", "retry6"):
        section = lineage.get(retry, {})
        pins = collect_pin_records(section.get("files", {}), retry)
        checked = []
        for pin in pins:
            path = ROOT / pin["path"]
            observed_sha = sha256_file(path) if path.is_file() else None
            observed_bytes = path.stat().st_size if path.is_file() else None
            checked.append({**pin, "expected_sha256": pin["sha256"],
                            "observed_sha256": observed_sha,
                            "observed_bytes": observed_bytes,
                            "match": observed_sha == pin["sha256"] and
                                     observed_bytes == pin["bytes"]})
        lineage_results[retry] = {
            "declared_pin_count": len(pins), "checked_pin_count": len(checked),
            "failure_type": section.get("failure", {}).get("type"),
            "failure_message": section.get("failure", {}).get("message"),
            "formal_t2_accepted": section.get("formal_t2_accepted"),
            "julia_executed": section.get("julia_executed"),
            "pins": checked,
        }
    record("retry5_retry6_failure_lineage", all(
               lineage_results[key]["checked_pin_count"] == 10 and
               all(pin["match"] for pin in lineage_results[key]["pins"])
               for key in ("retry5", "retry6")) and
           lineage.get("status") == "both_immutable_partial_failures_pinned_no_acceptance",
           "independently rehash all ten preserved evidence files from retry5 and retry6",
           schema=lineage.get("schema"), status=lineage.get("status"), retries=lineage_results)

    runtime_plan = coverage.get("runtime_execution_plan", {})
    formal_phase_cases = runtime_plan.get("actual_formal_phase_case_ids", {})
    formal_case_count = sum(len(value) for value in formal_phase_cases.values())
    case_count = len(coverage.get("successor_cases", []))
    coverage_ok = (
        protocol.get("expected_phase_count") == 30 and
        formal_case_count == 45 and case_count == 60 and
        runtime_plan.get("expected_runtime_case_hit_count") == 68 and
        coverage.get("successor_assertion_site_count") == 214 and
        coverage.get("successor_expected_runtime_hit_count") == 622 and
        protocol.get("coverage_assertion_hit_plan", {}).get("assertion_site_count") == 214 and
        protocol.get("coverage_assertion_hit_plan", {}).get("expected_runtime_hit_count") == 622
    )
    record("coverage_and_phase_contract", coverage_ok,
           "preserve the frozen formal cases, all unique successor cases, planned case hits and assertion-site hits",
           expected_phase_count=protocol.get("expected_phase_count"),
           formal_case_count=formal_case_count, unique_case_count=case_count,
           case_hits=runtime_plan.get("expected_runtime_case_hit_count"),
           assertion_site_count=coverage.get("successor_assertion_site_count"),
           assertion_site_hits=coverage.get("successor_expected_runtime_hit_count"),
           assertion_hit_plan_status=protocol.get("coverage_assertion_hit_plan", {}).get("status"),
           actual_hits=protocol.get("actual_source_site_hits"))

    budgets = protocol.get("resource_gates", {})
    budget_ok = (
        budgets.get("phase_wall_seconds") == 480 and
        budgets.get("phase_wall_timeout_overrides", {}).get("actual_formal_preflight") == 600 and
        budgets.get("authority_phase_wall_seconds") == 2400 and
        budgets.get("authority_case_wall_seconds") == 2400 and
        budgets.get("process_tree_working_set_bytes") == 2147483648 and
        budgets.get("julia_threads") == 1 and budgets.get("openblas_threads") == 1
    )
    record("resource_budget_contract", budget_ok,
           "only the formal preflight phase is 600s; ordinary phases 480s, authority 2400s, 2GiB and one Julia/BLAS thread",
           budgets=budgets)
    planned_dir = protocol.get("planned_evidence_directory")
    planned_absent = protocol.get("planned_evidence_directory_absent") is True and \
        isinstance(planned_dir, str) and not (ROOT / planned_dir).exists()
    record("planned_runtime_output_absent", planned_absent,
           "the planned T2 actual-output directory remains absent",
           planned_evidence_directory=planned_dir,
           exists=(ROOT / planned_dir).exists() if isinstance(planned_dir, str) else None)
    record("no_acceptance_or_julia_claim", protocol.get("formal_t2_accepted") is False and
           protocol.get("scientific_acceptance") is False and
           protocol.get("actual_source_site_hits") == "pending_julia_execution",
           "static coverage plan is not represented as actual source-site hits or acceptance",
           formal_t2_accepted=protocol.get("formal_t2_accepted"),
           scientific_acceptance=protocol.get("scientific_acceptance"),
           actual_source_site_hits=protocol.get("actual_source_site_hits"))

    controller = load_controller()
    old_psutil = controller.psutil
    fake_results: list[dict[str, Any]] = []

    def fake_record(name: str, passed: bool, detail: str, **extra: Any) -> None:
        fake_results.append({"name": name, "passed": bool(passed), "detail": detail, **extra})

    root = FakeProcess(41001, 1, 1.0, rss=0, cpu_user=0.0, cpu_system=0.0,
                       name="python.exe")
    child = FakeProcess(41002, 41001, 2.0, rss=0, cpu_user=0.0,
                        cpu_system=0.0, name="worker.exe")
    root.child_processes = [child]
    zero_sample = controller.process_tree_sample(root, 1.0)
    fake_record("valid_zero_rss_cpu", zero_sample.get("sample_complete") is True and
                zero_sample.get("process_tree_working_set_bytes") == 0 and
                zero_sample.get("process_tree_user_cpu_seconds") == 0.0 and
                zero_sample.get("process_tree_system_cpu_seconds") == 0.0,
                "zero RSS and zero CPU values are valid measurements",
                sample=zero_sample)

    invalid_sample_results = []
    invalid_values = [True, float("nan"), float("inf"), -1]
    for field in ("rss", "cpu_user", "cpu_system"):
        for value in invalid_values:
            child_case = FakeProcess(41002, 41001, 2.0, rss=value if field == "rss" else 0,
                                     cpu_user=value if field == "cpu_user" else 0.0,
                                     cpu_system=value if field == "cpu_system" else 0.0)
            root_case = FakeProcess(41001, 1, 1.0, children=[child_case])
            sample = controller.process_tree_sample(root_case, 1.0)
            invalid_sample_results.append({"field": field, "value": repr(value),
                                           "rejected": sample.get("sample_complete") is False,
                                           "errors": sample.get("errors", [])})
    fake_record("invalid_rss_cpu", all(item["rejected"] for item in invalid_sample_results),
                "bool, NaN, infinity, and negative RSS/CPU inputs all make tree samples incomplete",
                cases=invalid_sample_results)

    identity_results = []
    for field, bads in (("pid", [True, float("nan"), float("inf"), 0, -1]),
                        ("create_time", [True, float("nan"), float("inf"), -1.0, 0.0])):
        for value in bads:
            pid = value if field == "pid" else 41002
            created = value if field == "create_time" else 2.0
            child_case = FakeProcess(pid, 41001, created)
            root_case = FakeProcess(41001, 1, 1.0, children=[child_case])
            sample = controller.process_tree_sample(root_case, 1.0)
            identity_results.append({"field": field, "value": repr(value),
                                     "rejected": sample.get("sample_complete") is False,
                                     "errors": sample.get("errors", [])})
    fake_record("invalid_pid_create_time", all(item["rejected"] for item in identity_results),
                "malformed PID and create_time values are rejected in tree sampling",
                cases=identity_results)

    table_results = []
    for field, values in (("pid", [True, float("nan"), float("inf"), -1, 0]),
                          ("ppid", [True, -1, float("nan"), float("inf")]),
                          ("create_time", [True, float("nan"), float("inf"), -1.0, 0.0])):
        for value in values:
            row = {"pid": 42001, "ppid": 1, "create_time": 3.0, "name": "worker.exe"}
            row[field] = value
            fake = FakePsutil([row], {42001: FakeProcess(42001, 1, 3.0)})
            controller.psutil = fake
            snapshot = controller._process_table_snapshot()
            table_results.append({"field": field, "value": repr(value),
                                  "incomplete": snapshot.get("complete") is False,
                                  "errors": snapshot.get("errors", [])})
    fake_record("process_table_invalid_pid_ppid_ct", all(item["incomplete"] for item in table_results),
                "process table rejects bool/invalid PID, PPID, and creation-time values",
                cases=table_results)

    controller.psutil = FakePsutil(
        [{"pid": 43001, "ppid": 1, "create_time": 4.0, "name": "worker.exe"}],
        {43001: FakeProcess(43001, 1, 4.0, live_created=4.5)},
    )
    table_reuse = controller._process_table_snapshot()
    fake_record("process_table_generation_reuse", table_reuse.get("complete") is False and
                any("reused" in error.get("message", "").lower()
                    for error in table_reuse.get("errors", [])),
                "same PID with a changed create_time during table generation recheck fails closed",
                snapshot=table_reuse)

    launch_match = controller._bind_launch_root_identity(
        FakeLaunch(44001, 5.0), FakeProcess(44001, 1, 5.0))
    launch_reuse_rejected = False
    launch_error = None
    try:
        controller._bind_launch_root_identity(
            FakeLaunch(44001, 5.0), FakeProcess(44001, 1, 6.0))
    except Exception as error:
        launch_reuse_rejected = True
        launch_error = f"{type(error).__name__}: {error}"
    fake_record("launch_root_identity_reuse", launch_match.get("complete") is True and
                launch_reuse_rejected,
                "matching launch/lookup identity binds; same PID with another generation is rejected",
                matching=launch_match, reused_generation_error=launch_error)

    kill_identity_results = []
    for source_name in ("tracked", "discovered"):
        for identity in ([{"pid": True, "create_time": 2.0}],
                         [{"pid": 41002, "create_time": True}],
                         [{"pid": 41002, "create_time": float("nan")}],
                         [{"pid": 41002, "create_time": float("inf")}],
                         [{"pid": 41002, "create_time": -1.0}]):
            root_for_kill = FakeProcess(41001, 1, 1.0)
            controller.psutil = FakePsutil([], {})
            kwargs = {"tracked_processes": identity} if source_name == "tracked" else {"tracked_processes": [], "discovered_processes": identity}
            result = controller.kill_tree(root_for_kill, 1.0, **kwargs)
            kill_identity_results.append({"source": source_name,
                                          "identity": [{k: repr(v) for k, v in x.items()} for x in identity],
                                          "no_signal": result.get("signal_attempts") == [] and
                                                      root_for_kill.kill_calls == 0,
                                          "result": result})
    for bad_root in ((True, 1.0), (41001, True), (41001, float("nan")),
                     (41001, float("inf")), (41001, -1.0)):
        root_for_kill = FakeProcess(bad_root[0], 1, bad_root[1])
        controller.psutil = FakePsutil([], {})
        result = controller.kill_tree(root_for_kill, bad_root[1], [])
        kill_identity_results.append({"source": "root", "identity": [repr(x) for x in bad_root],
                                      "no_signal": result.get("signal_attempts") == [] and
                                                  root_for_kill.kill_calls == 0,
                                      "result": result})
    fake_record("kill_zero_signal_malformed_identity", all(item["no_signal"] for item in kill_identity_results),
                "kill_tree returns before signal attempts for malformed tracked, discovered, or root identities",
                cases=kill_identity_results)

    controller.psutil = FakePsutil([], {})
    final_absent = controller._final_process_tree_audit(
        45001, 7.0, [], root_exit_confirmed=True)
    controller.psutil = FakePsutil(
        [{"pid": 45001, "ppid": 1, "create_time": 8.0, "name": "julia.exe"}],
        {45001: FakeProcess(45001, 1, 8.0, name="julia.exe")},
    )
    final_reuse = controller._final_process_tree_audit(
        45001, 7.0, [], root_exit_confirmed=True)
    controller.psutil = FakePsutil(
        [{"pid": 45002, "ppid": 1, "create_time": 9.0, "name": "worker.exe"}],
        {45002: FakeProcess(45002, 1, 9.0, name="worker.exe")},
    )
    final_residual_child = controller._final_process_tree_audit(
        45001, 7.0, [{"pid": 45002, "create_time": 9.0}],
        root_exit_confirmed=True)
    fake_record("natural_and_final_tree_audit", final_absent.get("complete") is True and
                final_absent.get("root_identity_absent") is True and
                final_reuse.get("complete") is False and
                not final_reuse.get("root_identity_absent") and
                final_residual_child.get("complete") is True and
                len(final_residual_child.get("residual_descendant_processes", [])) == 1 and
                final_residual_child["residual_descendant_processes"][0].get("pid") == 45002,
                "final audit accepts an absent exited root, rejects root PID reuse, and reports a tracked child that remains",
                root_absent_audit=final_absent,
                reused_root_audit=final_reuse,
                residual_child_audit=final_residual_child)
    controller.psutil = old_psutil
    record("independent_fake_process_controls", all(item["passed"] for item in fake_results),
           "independent Python fake-process exercises over frozen controller r13",
           case_count=len(fake_results), cases=fake_results)

    # Run the frozen static QA as a direct Python script with bytecode disabled.
    report_path = OUT / "static_qa_rerun.json"
    argv = [sys.executable, "-B", str(STATIC_QA_PATH.resolve()),
            "--protocol", str(PROTOCOL_PATH.resolve()),
            "--protocol-sha256", EXPECTED_PROTOCOL,
            "--dispatch", str((BASE / "dispatch.json").resolve()),
            "--command", str((BASE / "command_argv.json").resolve()),
            "--report", str(report_path.resolve())]
    completed = subprocess.run(argv, cwd=ROOT, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, shell=False, check=False)
    write_new(OUT / "static_qa.command.json", canonical_json({
        "argv": argv, "cwd": str(ROOT), "shell": False,
        "exit_code": completed.returncode,
        "stdout_sha256": sha256_bytes(completed.stdout),
        "stderr_sha256": sha256_bytes(completed.stderr),
        "stdout_bytes": len(completed.stdout), "stderr_bytes": len(completed.stderr),
    }))
    write_new(OUT / "static_qa.stdout.raw", completed.stdout)
    write_new(OUT / "static_qa.stderr.raw", completed.stderr)
    write_new(OUT / "static_qa.exit.txt", f"{completed.returncode}\n".encode("ascii"))
    qa_report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    qa_ok = completed.returncode == 0 and qa_report.get("status") == "pass" and \
        qa_report.get("negative_control_count") == 166 and \
        qa_report.get("successor_assertion_sites_static_plan") == 214 and \
        qa_report.get("successor_runtime_hits_static_plan") == 622 and \
        qa_report.get("formal_t2_accepted") is False and \
        qa_report.get("julia_executed") is False and \
        qa_report.get("julia_parse_executed") is False
    record("frozen_static_qa_rerun", qa_ok,
           "rerun exact pinned QA source directly under python -B; QA must pass with 166 controls and static-only coverage claims",
           command=argv, exit_code=completed.returncode,
           stdout_sha256=sha256_bytes(completed.stdout),
           stderr_sha256=sha256_bytes(completed.stderr),
           report_sha256=sha256_file(report_path) if report_path.exists() else None,
           report_summary={key: qa_report.get(key) for key in
                           ("schema", "status", "negative_control_count",
                            "successor_assertion_sites_static_plan",
                            "successor_runtime_hits_static_plan",
                            "formal_t2_accepted", "julia_executed",
                            "julia_parse_executed")})

    report = {
        "schema": "independent-t2-attempt11-retry8-static-tester-v1",
        "status": "bounded_one_run_go" if all(x["passed"] for x in observations) else "no_go",
        "bounded_verdict": "GO for one separately granted bounded run only" if all(x["passed"] for x in observations) else "NO-GO",
        "protocol_sha256": sha256_bytes(protocol_bytes),
        "coverage_map_sha256": sha256_file(MAP_PATH),
        "static_qa_frozen_sha256": sha256_file(BASE / "static_qa.json"),
        "static_qa_rerun_sha256": sha256_file(report_path) if report_path.exists() else None,
        "controller_sha256": sha256_file(CONTROLLER_PATH),
        "tester_source_path": Path(__file__).relative_to(ROOT).as_posix(),
        "tester_source_sha256": sha256_file(Path(__file__).resolve()),
        "protocol_input_count": protocol.get("input_count"),
        "verified_input_count": len(input_results),
        "input_hashes_match": all(item["match"] for item in input_results),
        "runtime_executed": False,
        "julia_started": False,
        "formal_t2_accepted": False,
        "scientific_acceptance": False,
        "actual_source_site_hits": "pending_julia_execution",
        "observations": observations,
    }
    report_bytes = canonical_json(report)
    write_new(OUT / "independent_review_receipt.json", report_bytes)
    files = []
    for path in sorted(OUT.iterdir()):
        if path.is_file() and path.name != "manifest.json":
            files.append({"path": path.name, "bytes": path.stat().st_size,
                          "sha256": sha256_file(path)})
    manifest_bytes = canonical_json({
        "schema": "independent-t2-attempt11-retry8-static-evidence-manifest-v1",
        "evidence_only": True, "contains_executable_payload": False,
        "entries": files,
    })
    write_new(OUT / "manifest.json", manifest_bytes)
    print(json.dumps({"status": report["status"],
                      "checks": len(observations),
                      "passed": sum(1 for x in observations if x["passed"]),
                      "input_pins": len(input_results),
                      "receipt_sha256": sha256_bytes(report_bytes),
                      "manifest_sha256": sha256_bytes(manifest_bytes),
                      "path": str(OUT)}, separators=(",", ":"), sort_keys=True))
    return 0 if report["status"] == "bounded_one_run_go" else 1


if __name__ == "__main__":
    raise SystemExit(main())
