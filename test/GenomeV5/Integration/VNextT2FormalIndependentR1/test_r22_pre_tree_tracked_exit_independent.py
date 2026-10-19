from __future__ import annotations

import argparse
import ast
import hashlib
import json
import sys
import time
import traceback
import types
from pathlib import Path
from typing import Any
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[4]
TEST_ROOT = ROOT / "test/GenomeV5/Integration/VNextT2FormalIndependentR1"
CONTROLLER_R20 = TEST_ROOT / "independent_negative_controller_r20.py"
CONTROLLER_R21 = TEST_ROOT / "independent_negative_controller_r21.py"
CONTROLLER_R22 = TEST_ROOT / "independent_negative_controller_r22.py"
PROJECTION_VALIDATOR_R12 = TEST_ROOT / "validate_projection24_reuse_r12.py"
R23_TABLE = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
R23_SUPERVISOR = ROOT / "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
RUNS_ROOT = (ROOT / "runs/UP1-04A-VNEXT-T2").resolve()


class CheckFailure(AssertionError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_controller(path: Path) -> tuple[Any, str]:
    source = path.read_bytes()
    digest = sha256(source)
    module = types.ModuleType("independent_r22_pre_tree_controller")
    module.__file__ = str(path.resolve())
    module.__package__ = ""
    exec(compile(source, str(path.resolve()), "exec"), module.__dict__)
    return module, digest


def verify_projection_validator_pin(controller: Any) -> dict[str, Any]:
    expected = PROJECTION_VALIDATOR_R12.resolve()
    actual = Path(controller.PROJECTION_REUSE_VALIDATOR).resolve()
    require(actual == expected,
            "R22 controller does not pin the R12 projection-reuse validator")
    tree = ast.parse(expected.read_text(encoding="utf-8"), filename=str(expected))
    constants = {node.value for node in ast.walk(tree)
                 if isinstance(node, ast.Constant) and type(node.value) is str}
    require("vnext-t2-independent-negative-protocol-r10" in constants and
            "vnext-t2-projection24-cross-run-validation-r10" in constants,
            "pinned R12 validator does not accept protocol r10 and emit validation r10")
    return {"path": expected.relative_to(ROOT).as_posix(),
            "sha256": sha256(expected.read_bytes()),
            "accepted_protocol_schema": "vnext-t2-independent-negative-protocol-r10",
            "validation_receipt_schema": "vnext-t2-projection24-cross-run-validation-r10"}


def make_table(
        controller: Any, rows: list[tuple[int, int, int, str]], *,
        buffer_bytes: int | None = None) -> Any:
    native = controller._R23_TABLE
    typed = tuple(native.ProcessRow(native.ProcessIdentity(pid, ticks), ppid, name)
                  for pid, ticks, ppid, name in rows)
    return native.ProcessTableSnapshot(
        rows=typed, host_identity=tuple(native.WINDOWS_BUILD_PIN),
        buffer_bytes=(native.SPI_FIXED_HEADER_BYTES if buffer_bytes is None
                      else buffer_bytes), query_attempts=1, ntstatus_u32=0)


def malformed_table_for_query(controller: Any, valid_table: Any, *,
                               buffer_bytes: int) -> Any:
    """Build a typed but invalid table so validation fails at the query boundary."""
    native = controller._R23_TABLE
    malformed = object.__new__(type(valid_table))
    for field in ("rows", "host_identity", "buffer_bytes", "query_attempts",
                  "ntstatus_u32", "schema", "complete"):
        object.__setattr__(malformed, field, getattr(valid_table, field))
    object.__setattr__(malformed, "buffer_bytes", buffer_bytes)
    require(isinstance(malformed, native.ProcessTableSnapshot),
            "truncated control did not reach the controller as a typed snapshot")
    return malformed


def ids_for(controller: Any, *, with_sibling: bool = False) -> dict[str, tuple[int, int]]:
    # These are the exact root/conhost generations from the failed formal
    # parse_gate sample; the optional sibling is only for the prior-tracked
    # drift negative control.
    root = (40568, 134348478353788185)
    target = (93784, 134348478354020370)
    base = controller._R23_TABLE.WINDOWS_EPOCH_100NS + 1
    result = {"root": root, "target": target}
    if with_sibling:
        result["sibling"] = (95120, target[1] + 100)
    result["system"] = (0, base)
    result["system4"] = (4, base)
    return result


def rows_for(ids: dict[str, tuple[int, int]], *, include_target: bool,
             include_sibling: bool = False, root_identity: tuple[int, int] | None = None,
             target_identity: tuple[int, int] | None = None,
             sibling_identity: tuple[int, int] | None = None,
             extra_rows: list[tuple[int, int, int, str]] | None = None) -> list[tuple[int, int, int, str]]:
    root = root_identity or ids["root"]
    target = target_identity or ids["target"]
    sibling = sibling_identity or ids.get("sibling")
    rows = [
        (ids["system"][0], ids["system"][1], 0, ""),
        (ids["system4"][0], ids["system4"][1], 0, "System"),
        (root[0], root[1], 4, "julia.exe"),
    ]
    if include_sibling and sibling is not None:
        rows.append((sibling[0], sibling[1], root[0], "tracked-sibling.exe"))
    if include_target:
        rows.append((target[0], target[1], root[0], "conhost.exe"))
    if extra_rows:
        rows.extend(extra_rows)
    return rows


class FakeProcess:
    def __init__(self, identity: tuple[int, int]):
        self.pid = identity[0]
        self._handle = identity


class FakeRegistry:
    def __init__(self, ids: dict[str, tuple[int, int]], *, omit: set[str] | None = None):
        self._handles = {value: value for key, value in ids.items()
                         if key not in {"system", "system4"} and
                         key not in (omit or set())}
        self.opened: list[tuple[int, int]] = []

    def for_row(self, row: Any, snapshot: Any) -> tuple[int, int]:
        pid = row.identity.pid
        identity = (pid, row.identity.create_time_100ns)
        table = CONTROLLER_MODULE._R23_TABLE.validate_snapshot(snapshot)
        observed = table.by_pid.get(pid)
        if observed is None or (observed.identity.pid,
                                observed.identity.create_time_100ns) != identity:
            raise PermissionError("row is not bound to the exact source SPI generation")
        handle = self._handles.get(identity)
        if handle is None:
            handle = identity
            self._handles[identity] = handle
        self.opened.append(identity)
        return handle


CONTROLLER_MODULE: Any = None


def create_fixture(controller: Any, mode: str = "positive") -> tuple[dict[str, Any], FakeRegistry, dict[str, Any]]:
    with_sibling = mode == "other_tracked_drift"
    ids = ids_for(controller, with_sibling=with_sibling)
    native = controller._R23_TABLE
    previous = [ids["root"]]
    if with_sibling:
        previous.append(ids["sibling"])
    previous.append(ids["target"])

    prior_rows = rows_for(ids, include_target=True, include_sibling=with_sibling)
    outer_rows = rows_for(ids, include_target=True, include_sibling=with_sibling)
    failed_rows = rows_for(ids, include_target=False, include_sibling=with_sibling)
    accepted = make_table(controller, prior_rows)
    outer = make_table(controller, outer_rows)  # independent complete SPI receipt
    failed = make_table(controller, failed_rows)  # inner first/before table
    clean_rows = rows_for(ids, include_target=False, include_sibling=with_sibling)
    clean = make_table(controller, clean_rows)
    confirmations = [make_table(controller, clean_rows) for _ in range(3)]
    retry_before = make_table(controller, clean_rows)
    retry_after = make_table(controller, clean_rows)
    prior_source: Any = accepted
    outer_source: Any = outer
    registry_omit: set[str] = set()
    malformed_confirmation: Any = None

    if mode == "missing_prior_source":
        prior_source = None
    elif mode == "missing_outer_source":
        outer_source = None
    elif mode == "missing_handle":
        registry_omit.add("target")
    elif mode == "pid_reuse":
        reused_rows = rows_for(
            ids, include_target=True, include_sibling=with_sibling,
            target_identity=(ids["target"][0], ids["target"][1] + 1))
        confirmations[1] = make_table(controller, reused_rows)
    elif mode == "root_drift":
        drifted_root = (ids["root"][0], ids["root"][1] + 1)
        confirmations[0] = make_table(controller, rows_for(
            ids, include_target=False, include_sibling=with_sibling,
            root_identity=drifted_root))
    elif mode == "other_tracked_drift":
        confirmations[0] = make_table(controller, rows_for(
            ids, include_target=False, include_sibling=True,
            sibling_identity=(ids["sibling"][0], ids["sibling"][1] + 1)))
    elif mode == "orphan":
        orphan = (98000, ids["target"][1] + 1000, ids["target"][0], "orphan.exe")
        confirmations[0] = make_table(controller, rows_for(
            ids, include_target=False, include_sibling=with_sibling,
            extra_rows=[orphan]))
    elif mode == "truncated_snapshot":
        malformed_confirmation = malformed_table_for_query(
            controller, confirmations[1],
            buffer_bytes=native.SPI_FIXED_HEADER_BYTES - 1)
        confirmations[1] = malformed_confirmation
    elif mode == "incomplete_retry":
        retry_after = None
    elif mode not in ("positive",):
        raise CheckFailure(f"unknown R22 fixture mode: {mode}")

    # Query order is deliberately the R21 sample-4 order: the inner first
    # snapshot is queried after both complete source witnesses; three further
    # absence tables prove exit, then the whole-sample retry gets its own pair.
    queries = [failed, *confirmations, retry_before, retry_after]
    query_log: list[Any] = []
    registry = FakeRegistry(ids, omit=registry_omit)
    process = FakeProcess(ids["root"])
    wait_calls: list[tuple[tuple[int, int], float]] = []
    resource_reads: list[int] = []

    def query() -> Any:
        if not queries:
            raise CheckFailure(f"unexpected SPI query in {mode}")
        value = queries.pop(0)
        query_log.append(value)
        return value

    def wait(handle: Any, timeout: float) -> bool:
        identity = tuple(handle)
        wait_calls.append((identity, timeout))
        return identity == ids["target"]

    def exit_code(handle: Any) -> int:
        return 17

    metrics = {
        ids["root"][0]: (2048, 0.125, 0.25),
        ids["target"][0]: (4096, 0.5, 0.75),
    }
    if with_sibling:
        metrics[ids["sibling"][0]] = (1024, 0.0625, 0.125)

    def resource_reader(pid: int) -> dict[str, Any]:
        resource_reads.append(pid)
        rss, user, system = metrics[pid]
        return {"rss_bytes": rss, "cpu_user_seconds": user,
                "cpu_system_seconds": system, "cmdline": [f"pid-{pid}"]}

    return {
        "ids": ids, "previous": previous, "accepted": prior_source,
        "outer": outer_source, "failed": failed, "process": process,
        "registry": registry, "query": query, "query_log": query_log,
        "wait_calls": wait_calls, "resource_reads": resource_reads,
        "wait": wait, "exit_code": exit_code,
        "resource_reader": resource_reader, "mode": mode,
        "malformed_confirmation": malformed_confirmation,
        "retry_after": retry_after,
        "final_snapshot": make_table(controller, clean_rows),
        "previous_sample_index": 3, "sample_index": 4,
    }, registry, {"queries_remaining": lambda: len(queries)}


def run_sample(controller: Any, mode: str = "positive") -> tuple[dict[str, Any], dict[str, Any]]:
    fixture, registry, extra = create_fixture(controller, mode)
    native = controller._R23_TABLE
    completed_sources: list[Any] = []
    with patch.object(native, "query_native_process_table", side_effect=fixture["query"]), \
            patch.object(native, "read_process_handle_identity",
                         side_effect=lambda handle: tuple(handle)), \
            patch.object(native, "wait_for_process_exit",
                         side_effect=fixture["wait"]), \
            patch.object(native, "process_exit_code",
                         side_effect=fixture["exit_code"]), \
            patch.object(controller, "_r23_resource_reader",
                         side_effect=fixture["resource_reader"]):
        sample = controller._r20_native_sample(
            fixture["process"], registry, fixture["ids"]["root"],
            list(fixture["previous"]), sample_index=fixture["sample_index"],
            elapsed=0.6, deadline_monotonic=time.monotonic() + 60.0,
            previous_accepted_source_snapshot=fixture["accepted"],
            outer_reconcile_snapshot=fixture["outer"],
            previous_accepted_sample_index=fixture["previous_sample_index"],
            completed_source_snapshot_out=completed_sources)
    sample["_test_fixture"] = fixture
    sample["_test_registry"] = registry
    sample["_test_completed_sources"] = completed_sources
    sample["_test_queries_remaining"] = extra["queries_remaining"]()
    return sample, fixture


def pre_tree_record(sample: dict[str, Any]) -> dict[str, Any] | None:
    records = sample.get("pre_tree_tracked_exit_races", [])
    return records[0] if type(records) is list and records else None


def assert_no_credit(sample: dict[str, Any], record: dict[str, Any] | None) -> None:
    require(sample.get("sample_complete") is False,
            "failed R22 attempt or retry was reported as a complete sample")
    require(sample.get("process_tree_working_set_bytes") == 0 and
            sample.get("process_tree_user_cpu_seconds") == 0.0 and
            sample.get("process_tree_system_cpu_seconds") == 0.0,
            "incomplete R22 sample exposed resource credit")
    if record is not None:
        require(record.get("rss_credit_bytes") == 0 and
                record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
                record.get("exit_code_credit_issued") is False,
                "failed R22 receipt exposed RSS/CPU/exit credit")
        discarded = record.get("discarded_attempt", {})
        if discarded:
            require(discarded.get("credited_rss_bytes") == 0 and
                    discarded.get("credited_cpu_seconds") == {
                        "user": 0.0, "system": 0.0} and
                    discarded.get("exit_code_credit_issued") is False,
                    "discarded R22 attempt exposed a metric or exit credit")


def test_positive(controller: Any) -> dict[str, Any]:
    sample, fixture = run_sample(controller)
    ids = fixture["ids"]
    require(sample.get("sample_complete") is True and
            sample.get("sample_attempt_count") == 2,
            "valid pre-tree exit did not complete exactly one fresh whole-sample retry")
    records = sample.get("pre_tree_tracked_exit_races", [])
    require(type(records) is list and len(records) == 1,
            "positive pre-tree recovery did not retain exactly one typed receipt")
    record = records[0]
    expected_target = {"pid": ids["target"][0],
                       "create_time_100ns": ids["target"][1]}
    require(record.get("schema") == "vnext-t2-r22-pre-tree-tracked-exit-r1" and
            record.get("complete") is True and
            record.get("retry_started") is True and
            record.get("full_sample_completed_after_retry") is True and
            record.get("previous_accepted_sample_index") == 3 and
            record.get("logical_sample_index") == 4 and
            record.get("target_identity") == expected_target,
            "R22 positive receipt did not bind the sample-3 to sample-4 transition")
    require(record.get("previous_accepted_source", {}).get("snapshot", {}).get(
                "complete") is True and
            record.get("outer_reconcile_source", {}).get("snapshot", {}).get(
                "complete") is True and
            record.get("failed_attempt_source", {}).get("snapshot", {}).get(
                "complete") is True and
            record["previous_accepted_source"].get("snapshot", {}).get("raw_identity_digest_sha256") !=
                record["failed_attempt_source"].get("snapshot", {}).get("raw_identity_digest_sha256") and
            record["outer_reconcile_source"].get("snapshot", {}).get("raw_identity_digest_sha256") !=
                record["failed_attempt_source"].get("snapshot", {}).get("raw_identity_digest_sha256"),
            "positive R22 proof collapsed historical/outer/failed SPI boundaries")
    retired = {(item.get("pid"), item.get("create_time_100ns"))
               for item in record.get("retired_tracked_identities", [])}
    require(retired == {ids["target"]},
            "positive R22 receipt did not retire exactly the missing conhost generation")
    nested = record.get("r21_exact_exit_proof", {})
    exit_receipts = nested.get("exact_exit_receipts", [])
    require(len(exit_receipts) == 1 and
            exit_receipts[0].get("identity") == expected_target and
            exit_receipts[0].get("handle_identity_before_wait") == expected_target and
            exit_receipts[0].get("handle_identity_after_wait") == expected_target and
            exit_receipts[0].get("wait_confirmed") is True and
            type(exit_receipts[0].get("exit_code")) is int and
            exit_receipts[0].get("exit_code") != 259 and
            exit_receipts[0].get("exit_code_credit_issued") is False,
            "positive R22 receipt lacks the exact cached-handle natural-exit proof")
    absences = nested.get("absence_snapshots", [])
    require(nested.get("complete") is True and
            nested.get("absence_snapshot_count") == 3 and len(absences) == 3 and
            all(item.get("complete") is True for item in absences),
            "positive R22 receipt lacks three complete post-exit absence snapshots")
    require(record.get("partial_rss_bytes_not_credited") == 0 and
            record.get("rss_credit_bytes") == 0 and
            record.get("cpu_credit_seconds") == {"user": 0.0, "system": 0.0} and
            record.get("exit_code_credit_issued") is False and
            record.get("discarded_attempt", {}).get("credited_rss_bytes") == 0 and
            record.get("discarded_attempt", {}).get("credited_cpu_seconds") == {
                "user": 0.0, "system": 0.0} and
            record.get("discarded_attempt", {}).get("exit_code_credit_issued") is False,
            "pre-provider failed attempt received resource or exit credit")
    require(sample.get("process_tree_working_set_bytes") == 2048 and
            sample.get("process_tree_user_cpu_seconds") == 0.125 and
            sample.get("process_tree_system_cpu_seconds") == 0.25 and
            {item.get("pid") for item in sample.get("processes", [])} == {ids["root"][0]},
            "retry did not credit only the fresh root-only sample")
    require(fixture["resource_reads"] == [ids["root"][0]],
            "failed pre-tree attempt read resources before the fresh root-only retry")
    require(sample["_test_registry"].opened == [ids["root"]],
            "failed pre-tree attempt reopened the retired target generation for sampling")
    target_waits = [call for call in fixture["wait_calls"]
                    if call[0] == ids["target"]]
    require(target_waits == [(ids["target"], 0.001)],
            "pre-tree recovery did not wait on exactly the cached target handle")
    # The controller's dedicated final audit validates the receipt independently
    # of the sample-level success flags.
    audit = controller._r22_audit_pre_tree_tracked_exit_races(
        fixture["final_snapshot"],
        records, ids["root"], fixture["previous"])
    require(audit.get("complete") is True and audit.get("residual_retired_generations") == [],
            "R22 final audit did not close the positive exact-generation receipt: " +
            json.dumps(audit, sort_keys=True))
    return {"name": "sample-4 pre-tree conhost natural exit, three absences, full retry",
            "status": "pass", "sample_attempt_count": sample["sample_attempt_count"],
            "absence_snapshot_count": len(absences),
            "retired_generation_count": len(retired),
            "retry_rss_bytes": sample["process_tree_working_set_bytes"],
            "failed_attempt_resource_reads": 0,
            "target_opened_for_sampling": False,
            "final_audit_complete": audit.get("complete") is True}


def test_negative_controls(controller: Any) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for mode in ("missing_prior_source", "missing_outer_source", "missing_handle",
                 "pid_reuse", "root_drift", "other_tracked_drift", "orphan",
                 "truncated_snapshot", "incomplete_retry"):
        sample, fixture = run_sample(controller, mode)
        record = pre_tree_record(sample)
        require(record is not None,
                f"negative control {mode} omitted the typed pre-tree failure record")
        if mode == "incomplete_retry":
            # Natural exit/absence proof may be complete, but no active-set
            # retirement is accepted until the subsequent whole sample is full.
            require(record.get("r21_exact_exit_proof", {}).get("complete") is True and
                    record.get("retry_started") is True and
                    record.get("full_sample_completed_after_retry") is False and
                    sample.get("sample_attempt_count") == 2,
                    "incomplete whole-sample retry was not preserved as a fail-closed R22 result")
        else:
            require(record.get("complete") is False and
                    record.get("retry_started") is not True and
                    sample.get("sample_attempt_count") == 1 and
                    record.get("full_sample_completed_after_retry") is False,
                    f"unsafe pre-tree case {mode} started a whole-sample retry")
        if mode == "truncated_snapshot":
            proof_errors = record.get("r21_exact_exit_proof", {}).get("errors", [])
            require(len(fixture["query_log"]) == 3 and
                    fixture["query_log"][2] is fixture["malformed_confirmation"] and
                    any("process-table buffer size is invalid" in str(error.get("message", ""))
                        for error in proof_errors if isinstance(error, dict)),
                    "truncated snapshot did not fail at the controller query/validation boundary")
        assert_no_credit(sample, record)
        audit = controller._r22_audit_pre_tree_tracked_exit_races(
            fixture["final_snapshot"], [record], fixture["ids"]["root"],
            fixture["previous"])
        require(audit.get("complete") is False,
                f"final audit accepted unsafe pre-tree case {mode}")
        cases.append({"name": mode, "status": "pass",
                      "attempt_count": sample.get("sample_attempt_count"),
                      "record_complete": record.get("complete"),
                      "error_count": len(record.get("errors", []))})
    return cases


def run_suite(output: Path, controller_path: Path) -> tuple[int, dict[str, Any], str, str]:
    global CONTROLLER_MODULE
    require(sys.dont_write_bytecode, "run this independent test with Python -B")
    output = output.resolve()
    require(output.parent == RUNS_ROOT,
            "R22 evidence must be a direct child of the owned T2 runs directory")
    require(not output.exists(), f"refusing to overwrite existing evidence leaf: {output}")
    output.mkdir(parents=True, exist_ok=False)

    test_path = Path(__file__).resolve()
    controller_path = controller_path.resolve()
    before = {
        controller_path.relative_to(ROOT).as_posix(): sha256(controller_path.read_bytes()),
        CONTROLLER_R20.relative_to(ROOT).as_posix(): sha256(CONTROLLER_R20.read_bytes()),
        CONTROLLER_R21.relative_to(ROOT).as_posix(): sha256(CONTROLLER_R21.read_bytes()),
        PROJECTION_VALIDATOR_R12.relative_to(ROOT).as_posix(): sha256(
            PROJECTION_VALIDATOR_R12.read_bytes()),
        R23_TABLE.relative_to(ROOT).as_posix(): sha256(R23_TABLE.read_bytes()),
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): sha256(R23_SUPERVISOR.read_bytes()),
        test_path.relative_to(ROOT).as_posix(): sha256(test_path.read_bytes()),
    }
    controller, loaded_hash = load_controller(controller_path)
    require(loaded_hash == before[controller_path.relative_to(ROOT).as_posix()],
            "R22 controller bytes changed between pin and in-memory compile")
    projection_validator = verify_projection_validator_pin(controller)
    CONTROLLER_MODULE = controller
    receipt: dict[str, Any] = {
        "schema": "independent-vnext-t2-r22-pre-tree-tracked-exit-tests-r1",
        "status": "fail", "python_executed": True,
        "julia_executed": False, "formal_t2_accepted": False,
        "controller_path": controller_path.relative_to(ROOT).as_posix(),
        "projection_validator": projection_validator,
        "source_pins_before": before,
        "exact_launcher_argv": [sys.executable, "-B", str(test_path), *sys.argv[1:]],
        "positive_control": None, "negative_controls": [],
    }
    stdout_text = ""
    stderr_text = ""
    exit_code = 1
    try:
        receipt["positive_control"] = test_positive(controller)
        receipt["negative_controls"] = test_negative_controls(controller)
        receipt["positive_control_count"] = 1
        receipt["negative_control_count"] = len(receipt["negative_controls"])
        receipt["status"] = "pass"
        exit_code = 0
        stdout_text = ("R22_PRE_TREE_TRACKED_EXIT_TESTS=PASS\n"
                       "positive_controls=1\n"
                       f"negative_controls={len(receipt['negative_controls'])}\n")
    except Exception:
        stderr_text = traceback.format_exc()
        receipt["failure"] = stderr_text
        stdout_text = "R22_PRE_TREE_TRACKED_EXIT_TESTS=FAIL\n"
    after = {
        controller_path.relative_to(ROOT).as_posix(): sha256(controller_path.read_bytes()),
        CONTROLLER_R20.relative_to(ROOT).as_posix(): sha256(CONTROLLER_R20.read_bytes()),
        CONTROLLER_R21.relative_to(ROOT).as_posix(): sha256(CONTROLLER_R21.read_bytes()),
        PROJECTION_VALIDATOR_R12.relative_to(ROOT).as_posix(): sha256(
            PROJECTION_VALIDATOR_R12.read_bytes()),
        R23_TABLE.relative_to(ROOT).as_posix(): sha256(R23_TABLE.read_bytes()),
        R23_SUPERVISOR.relative_to(ROOT).as_posix(): sha256(R23_SUPERVISOR.read_bytes()),
        test_path.relative_to(ROOT).as_posix(): sha256(test_path.read_bytes()),
    }
    receipt["source_pins_after"] = after
    receipt["source_pins_unchanged"] = after == before
    receipt["test_exit_code"] = exit_code
    if not receipt["source_pins_unchanged"]:
        receipt["status"] = "fail"
        receipt["test_exit_code"] = 1
        exit_code = 1
        stderr_text += "A pinned input changed while R22 tests were running.\n"
        stdout_text = "R22_PRE_TREE_TRACKED_EXIT_TESTS=FAIL\n"
    (output / "stdout.raw").write_text(stdout_text, encoding="utf-8", newline="\n")
    (output / "stderr.raw").write_text(stderr_text, encoding="utf-8", newline="\n")
    (output / "exit_code.txt").write_text(f"{exit_code}\n", encoding="ascii")
    (output / "command_argv.json").write_text(
        json.dumps(receipt["exact_launcher_argv"], indent=2) + "\n",
        encoding="utf-8", newline="\n")
    (output / "evidence.json").write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n")
    print(stdout_text, end="", flush=True)
    if stderr_text:
        print(stderr_text, end="", file=sys.stderr, flush=True)
    return exit_code, receipt, stdout_text, stderr_text


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--controller", default=str(CONTROLLER_R22))
    args = parser.parse_args()
    exit_code, _, _, _ = run_suite(Path(args.output), Path(args.controller))
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
