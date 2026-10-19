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
from typing import Any, Callable


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1"
R20_PROTOCOL = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r20_strict_identity_static_20260924/protocol.json"
R20_OWNER_LEAF = R20_PROTOCOL.parent
R20_SUPERVISOR = TEST_DIR / "supervise_r16_root_audit_r20_v1.py"
R20_TESTS = TEST_DIR / "test_r16_root_audit_r20_v1.py"
R19_SUPERVISOR = TEST_DIR / "supervise_r16_root_audit_r19_v1.py"
R19_TESTS = TEST_DIR / "test_r16_root_audit_r19_v1.py"
R19_PROTOCOL = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r19_root_supervisor_static_20260924/protocol.json"
OUT = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/independent_native_g1g2_r20_strict_identity_review_v2_20260924"
ACTUAL_OUTPUT = ROOT / "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_prelaunch_r16_v1/r16_root_supervised_actual_r20_v1"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def write_new(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(payload)
        stream.flush()
        os.fsync(stream.fileno())


def canonical_json(value: Any) -> bytes:
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False,
                       allow_nan=False) + "\n").encode("utf-8")


def load_module(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load frozen source: {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


class FakeProcess:
    def __init__(self, pid: Any, created: Any, *, rss: Any = 1024,
                 cpu_user: Any = 0.25, cpu_system: Any = 0.5,
                 ppid: Any = 1, descendants: list["FakeProcess"] | None = None,
                 times: list[Any] | None = None) -> None:
        self.pid = pid
        self.created = created
        self.times = list(times or [])
        self.rss = rss
        self.cpu_user = cpu_user
        self.cpu_system = cpu_system
        self.parent_pid = ppid
        self.descendants = descendants or []
        self.killed = False
        self.wait_calls = 0
        self.kill_create_time_at_signal: Any = None

    def create_time(self) -> Any:
        if self.times:
            if len(self.times) > 1:
                return self.times.pop(0)
            return self.times[0]
        return self.created

    def children(self, recursive: bool = False) -> list["FakeProcess"]:
        return list(self.descendants)

    def memory_info(self) -> SimpleNamespace:
        return SimpleNamespace(rss=self.rss)

    def cpu_times(self) -> SimpleNamespace:
        return SimpleNamespace(user=self.cpu_user, system=self.cpu_system)

    def ppid(self) -> Any:
        return self.parent_pid

    def name(self) -> str:
        return "python.exe" if self.pid in (101, 501) else "julia.exe"

    def cmdline(self) -> list[str]:
        return [self.name()]

    def kill(self) -> None:
        self.killed = True
        self.kill_create_time_at_signal = self.times[0] if self.times else self.created

    def wait(self, timeout: float | None = None) -> int:
        self.wait_calls += 1
        return 0


class FakePopen:
    def __init__(self, pid: Any) -> None:
        self.pid = pid
        self._handle = 777
        self.kill_calls = 0
        self.wait_calls = 0

    def kill(self) -> None:
        self.kill_calls += 1

    def wait(self, timeout: float | None = None) -> int:
        self.wait_calls += 1
        return 0


def run() -> dict[str, Any]:
    if OUT.exists():
        raise FileExistsError(f"evidence leaf already exists: {OUT}")
    OUT.mkdir(parents=True, exist_ok=False)
    observations: list[dict[str, Any]] = []

    def record(name: str, passed: bool, detail: str, **extra: Any) -> None:
        observations.append({"name": name, "passed": bool(passed), "detail": detail,
                             **extra})

    protocol_bytes = R20_PROTOCOL.read_bytes()
    protocol = json.loads(protocol_bytes)
    protocol_hash = sha256_bytes(protocol_bytes)
    frozen = [
        {"path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r20_strict_identity_static_20260924/protocol.json",
         "expected": "3dc4800818a262d64e59cde75ed71c4bee81272e3c25ab501c1eab9d1a78db9a"},
        {"path": "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r20_v1.py",
         "expected": "60326248aaf6f88b8b414ab9bdb6ce9a8b6cdc436183aefcb08216ea252613a1"},
        {"path": "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r20_v1.py",
         "expected": "f0ea8e631a59c579c4870ec255c74b025e4bf2320d8244da20bc7a19292b1cb1"},
        {"path": "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r19_v1.py",
         "expected": "c4f6c4bcbf7fc5067c1a0e33ad9ba881aac95b32d6181cc9e90c07d947119952"},
        {"path": "test/RuntimeV4/NativeG1G2DiffusionV1/test_r16_root_audit_r19_v1.py",
         "expected": "25f6fab55730639b8f56261d9bd420003fab24c24de427e01486218eea541e09"},
        {"path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/native_g1g2_r19_root_supervisor_static_20260924/protocol.json",
         "expected": "5ed5f6ccbb825eb159f4347298605f46b4214de018b2a97f52dcb4994c63d573"},
    ]
    parent_hashes: list[dict[str, Any]] = []
    for pin in protocol.get("frozen_parent_pins", []):
        parent_hashes.append({"path": pin["path"], "role": pin["role"],
                              "expected": pin["sha256"]})
    for pin in frozen:
        parent_hashes.append(pin)
    parent_results: list[dict[str, Any]] = []
    for pin in parent_hashes:
        path = ROOT / Path(pin["path"])
        observed = sha256_file(path) if path.is_file() else None
        expected = pin["expected"]
        parent_results.append({"path": pin["path"], "role": pin.get("role"),
                               "expected_sha256": expected,
                               "observed_sha256": observed,
                               "match": observed == expected,
                               "bytes": path.stat().st_size if path.is_file() else None})
    record("protocol_and_lineage_pins", all(row["match"] for row in parent_results),
           "rehash R20 protocol/source/tests, R19 NO-GO source/protocol/tests, and every frozen R16/R18 dependency pin",
           pin_count=len(parent_results), pins=parent_results,
           protocol_sha256=protocol_hash)

    contract = protocol.get("r16_limits", {})
    expected_contract = {
        "stage_order": ["parse_all", "primary", "fresh_replay"],
        "wall_seconds_per_stage": 480.0,
        "sampled_rss_stop_threshold_bytes": 2147483648,
        "sample_interval_seconds": 0.2,
        "compiler_mode": "--compile=min",
        "julia_heap_size_hint": "1G",
        "julia_threads": 1,
        "blas_threads": 1,
    }
    record("resource_contract", all(contract.get(k) == v for k, v in expected_contract.items()),
           "R16 stage order and resource settings remain frozen in R20",
           expected=expected_contract, observed={k: contract.get(k) for k in expected_contract})
    record("runtime_absent_before", not ACTUAL_OUTPUT.exists(),
           "planned actual-output leaf was absent before static checks",
           path=str(ACTUAL_OUTPUT))

    r19 = load_module("r19_frozen", R19_SUPERVISOR)
    r20 = load_module("r20_frozen", R20_SUPERVISOR)

    # Reproduce the old post-resource raw equality bug: 1.0 == True.
    sample_rows: dict[str, Any] = {}
    for label, module, second in (("r19", r19, True), ("r20", r20, True)):
        child = FakeProcess(202, 1.0, ppid=101, times=[1.0, second])
        root = FakeProcess(101, 10.0, descendants=[child])
        row = module.sample_process_tree(root, sample_index=1,
                                        sampled_utc="2026-09-24T00:00:00Z")
        sample_rows[label] = {"complete": row.get("complete"),
                              "rss_bytes": row.get("rss_bytes"),
                              "errors": row.get("errors", [])}
    record("r19_sample_bool_alias", sample_rows["r19"]["complete"] is True and
           sample_rows["r20"]["complete"] is False,
           "R19 accepts the post-read raw True == 1.0 recheck; R20 revalidates its native type",
           results=sample_rows)

    wait_rows: dict[str, Any] = {}
    for label, module, times in (
        ("r19", r19, [1.0, True]),
        ("r20", r20, [1.0, 1.0, True]),
    ):
        process = FakeProcess(202, 1.0, times=times)
        receipts, errors = module.process_exit_receipts({(202, 1.0): process}, [(202, 1.0)])
        wait_rows[label] = {"exit_confirmed": bool(receipts and receipts[0].get("exit_confirmed")),
                            "receipts": receipts, "errors": errors,
                            "wait_calls": process.wait_calls}
    record("r19_wait_bool_alias", wait_rows["r19"]["exit_confirmed"] is True and
           wait_rows["r20"]["exit_confirmed"] is False,
           "R19 post-wait raw equality confirms a bool alias; R20 fails the post-wait identity validation",
           results=wait_rows)

    kill_rows: dict[str, Any] = {}
    for label, module, times in (
        ("r19", r19, [1.0, 1.0, True]),
        ("r20", r20, [1.0, 1.0, 1.0, 1.0, True]),
    ):
        process = FakeProcess(202, 1.0, times=times)
        result = module.terminate_and_wait({(202, 1.0): process}, [(202, 1.0)])
        kill_rows[label] = {"complete": result.get("complete"),
                            "killed": process.killed,
                            "exit_receipts": result.get("exit_receipts"),
                            "errors": result.get("errors"),
                            "wait_calls": process.wait_calls}
    record("r19_kill_exit_receipt_bool_alias", kill_rows["r19"]["complete"] is True and
           kill_rows["r20"]["complete"] is False and kill_rows["r20"]["killed"] is True,
           "R19 termination can accept a bool at the post-wait check; R20 reports incomplete, with its attempted kill occurring before the post-wait change",
           results=kill_rows,
           interpretation="This post-wait alias cannot establish the identity of the post-wait object. R20 blocks completion; the separate immediate pre-signal case below checks generation before signaling.")

    # Immediate pre-signal replay. R19 checks once; R20 checks both the first
    # observation and the boundary observation before the signal.
    pre_signal_rows: dict[str, Any] = {}
    for label, module, times in (("r19", r19, [1.0, True, True]),
                                 ("r20", r20, [1.0, True])):
        process = FakeProcess(202, 1.0, times=times)
        result = module.terminate_and_wait({(202, 1.0): process}, [(202, 1.0)])
        pre_signal_rows[label] = {"killed": process.killed,
                                  "signal_create_time": process.kill_create_time_at_signal,
                                  "complete": result.get("complete"),
                                  "errors": result.get("errors")}
    record("pre_signal_recheck", pre_signal_rows["r19"]["killed"] is True and
           pre_signal_rows["r20"]["killed"] is False,
           "R19 signals after one psutil identity read; R20 detects the bool alias on its immediate second pre-signal read",
           results=pre_signal_rows)

    # Strict malformed identity and process-resource cases.
    malformed = [
        ("bool_pid", True, 1.0), ("nan_time", 501, float("nan")),
        ("positive_infinity_time", 501, float("inf")),
        ("bool_time", 501, True), ("integer_time", 501, 1),
    ]
    malformed_results: list[dict[str, Any]] = []
    for name, pid, created in malformed:
        try:
            r20._identity(pid, created)
            passed = False
            error = None
        except Exception as exc:
            passed = True
            error = f"{type(exc).__name__}: {exc}"
        malformed_results.append({"name": name, "rejected": passed, "error": error})
    rss_cases = [True, float("nan"), float("inf")]
    cpu_cases = [True, float("nan"), float("inf")]
    resource_results: list[dict[str, Any]] = []
    for field, cases in (("rss", rss_cases), ("cpu_user", cpu_cases)):
        for value in cases:
            child = FakeProcess(202, 20.0, ppid=101, **{field: value})
            root = FakeProcess(101, 10.0, descendants=[child])
            row = r20.sample_process_tree(root, sample_index=1)
            resource_results.append({"field": field, "value_repr": repr(value),
                                     "rejected": row.get("complete") is False,
                                     "rss_bytes": row.get("rss_bytes"),
                                     "errors": row.get("errors", [])})
    record("malformed_identity_resource", all(item["rejected"] for item in malformed_results) and
           all(item["rejected"] for item in resource_results),
           "R20 rejects bool/nonfinite/non-native identity and RSS/CPU samples without coercion",
           identities=malformed_results, resources=resource_results)

    # Raw FILETIME root guard around a process-tree sample.
    ticks = r20._unix_seconds_filetime_roundtrip(1_700_000_000.0)
    root_created = r20._filetime_unix_seconds(ticks)
    root = FakeProcess(501, root_created)
    guard_rows = iter([(501, ticks), (501, ticks + 1)])
    guarded_sample = r20.sample_process_tree(
        root, sample_index=2, expected_root_creation_filetime_ticks=ticks,
        pid_handle_identity_reader=lambda pid: next(guard_rows),
    )
    record("sample_raw_filetime_after_guard", guarded_sample["complete"] is False and
           guarded_sample["root_generation_guard_complete"] is False,
           "R20 detects raw FILETIME generation drift at the sample post-read guard",
           errors=guarded_sample["errors"],
           guard_before=guarded_sample["root_generation_guard_before"],
           guard_after=guarded_sample["root_generation_guard_after"])

    # Root Popen generation: only identical exact raw FILETIME on the original
    # and fresh handles permits a signal.
    expected = (501, root_created)
    binding = {"complete": True, "popen_handle_creation_filetime_ticks": ticks}
    positive_popen = FakePopen(501)
    positive = r20.kill_popen_if_bound(
        positive_popen, expected, binding,
        handle_identity_reader=lambda _: (501, ticks),
        pid_handle_identity_reader=lambda pid: (501, ticks),
    )
    changed_popen = FakePopen(501)
    changed = r20.kill_popen_if_bound(
        changed_popen, expected, binding,
        handle_identity_reader=lambda _: (501, ticks),
        pid_handle_identity_reader=lambda pid: (501, ticks + 1),
    )
    malformed_popen = FakePopen(501)
    malformed = r20.kill_popen_if_bound(
        malformed_popen, expected, binding,
        handle_identity_reader=lambda _: (501, ticks),
        pid_handle_identity_reader=lambda pid: (True, ticks),
    )
    record("popen_pre_signal_filetime", positive["signal_sent"] is True and
           positive_popen.kill_calls == 1 and changed["signal_sent"] is False and
           changed_popen.kill_calls == 0 and malformed["signal_sent"] is False and
           malformed_popen.kill_calls == 0,
           "R20 signals only when original and fresh PID handles report the exact bound raw FILETIME ticks",
           positive=positive, positive_kill_calls=positive_popen.kill_calls,
           changed_generation=changed, changed_kill_calls=changed_popen.kill_calls,
           malformed_fresh_handle=malformed,
           malformed_kill_calls=malformed_popen.kill_calls)

    # A Popen generation change detected after wait invalidates the receipt.
    waiting_popen = FakePopen(501)
    after_reads = iter([(501, ticks), (501, ticks + 1)])
    wait_code, wait_errors = r20.wait_popen_if_bound(
        waiting_popen, expected, binding, timeout_seconds=1.0,
        handle_identity_reader=lambda _: next(after_reads),
    )
    record("popen_post_wait_filetime", wait_code is None and bool(wait_errors) and
           waiting_popen.wait_calls == 1,
           "R20 invalidates a wait result if the Popen raw FILETIME generation check changes after wait",
           wait_code=wait_code, errors=wait_errors, wait_calls=waiting_popen.wait_calls)

    # Re-run official frozen checks as independent subprocesses and persist the
    # exact argv/output/exit evidence.
    commands = [
        ("python_tests", [sys.executable, "-B",
                          str(R20_TESTS.relative_to(ROOT)), "-v"]),
        ("static_preflight", [sys.executable, "-B",
                               str(R20_SUPERVISOR.relative_to(ROOT)),
                               "--static-only", "--output", "r16_root_supervised_actual_r20_v1"]),
    ]
    command_receipts: list[dict[str, Any]] = []
    for name, argv in commands:
        completed = subprocess.run(argv, cwd=ROOT, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, check=False, shell=False)
        write_new(OUT / f"{name}.stdout.raw", completed.stdout)
        write_new(OUT / f"{name}.stderr.raw", completed.stderr)
        write_new(OUT / f"{name}.exit.txt", f"{completed.returncode}\n".encode("ascii"))
        command_receipt = {
            "argv": argv, "cwd": str(ROOT), "shell": False,
            "exit_code": completed.returncode,
            "stdout_sha256": sha256_bytes(completed.stdout),
            "stderr_sha256": sha256_bytes(completed.stderr),
            "stdout_bytes": len(completed.stdout), "stderr_bytes": len(completed.stderr),
        }
        write_new(OUT / f"{name}.command.json", canonical_json(command_receipt))
        command_receipts.append({"name": name, **command_receipt})
        record(name, completed.returncode == 0,
               "independent rerun of the frozen R20 Python suite/static-only preflight",
               exit_code=completed.returncode,
               stdout_sha256=command_receipt["stdout_sha256"],
               stderr_sha256=command_receipt["stderr_sha256"],
               stdout=completed.stdout.decode("utf-8", errors="replace")[:12000],
               stderr=completed.stderr.decode("utf-8", errors="replace")[:12000])

    output_after = not ACTUAL_OUTPUT.exists()
    record("runtime_absent_after", output_after,
           "no actual-output leaf was created by static checks",
           path=str(ACTUAL_OUTPUT), exists=ACTUAL_OUTPUT.exists())
    record("runtime_never_started", protocol.get("static_preparation", {}).get("julia_started") is False and
           protocol.get("static_preparation", {}).get("runtime_executed") is False and
           protocol.get("claim_ceiling", {}).get("numerical_credit_before_outer_audit") is False,
           "frozen R20 is a static candidate; this test starts no Julia/mesh/solver")

    all_passed = all(item["passed"] for item in observations)
    report = {
        "schema": "independent-native-g1g2-r20-strict-identity-review-v2",
        "status": "bounded_static_go" if all_passed else "no_go",
        "bounded_verdict": "GO for one separately reviewed test-only dispatch decision" if all_passed else "NO-GO",
        "protocol_sha256": protocol_hash,
        "supervisor_sha256": sha256_file(R20_SUPERVISOR),
        "python_test_sha256": sha256_file(R20_TESTS),
        "reviewer_script_path": str(Path(__file__).relative_to(ROOT).as_posix()),
        "reviewer_script_sha256": sha256_file(Path(__file__).resolve()),
        "runtime_executed": False,
        "julia_started": False,
        "numerical_status": "not_established",
        "physical_status": "unknown",
        "observations": observations,
        "command_receipts": command_receipts,
        "frozen_parent_pin_match_count": sum(1 for row in parent_results if row["match"]),
        "frozen_parent_pin_count": len(parent_results),
    }
    report_bytes = canonical_json(report)
    write_new(OUT / "review_receipt.json", report_bytes)
    manifest_entries = []
    for path in sorted(OUT.iterdir()):
        if path.is_file() and path.name != "manifest.json":
            manifest_entries.append({"path": path.name, "bytes": path.stat().st_size,
                                     "sha256": sha256_file(path)})
    manifest = {
        "schema": "independent-native-g1g2-r20-evidence-manifest-v2",
        "evidence_only": True,
        "contains_executable_payload": False,
        "entries": manifest_entries,
    }
    manifest_bytes = canonical_json(manifest)
    write_new(OUT / "manifest.json", manifest_bytes)
    return {"status": report["status"], "review_receipt_sha256": sha256_bytes(report_bytes),
            "manifest_sha256": sha256_bytes(manifest_bytes), "checks": len(observations),
            "passed": sum(1 for item in observations if item["passed"]),
            "path": str(OUT)}


if __name__ == "__main__":
    result = run()
    print(json.dumps(result, sort_keys=True, separators=(",", ":")))
