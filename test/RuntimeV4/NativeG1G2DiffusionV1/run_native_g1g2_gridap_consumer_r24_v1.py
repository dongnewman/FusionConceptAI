"""Root-dispatched native G1/G2 compiler -> Gridap consumer supervisor (R24).

This is the single formal consumer runner for this version. It wraps the
unchanged Julia focused test and delegates process-generation identity,
process-tree sampling, and exact-handle termination to the frozen R23 helper.
Importing this module never launches Julia. Runtime dispatch requires the
explicit --dispatch-actual mode and exact protocol-pinned invocation argv.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
REL_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r24_v1.py"
REL_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r24_v1.py"
REL_VERIFIER = "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r24_v1.py"
REL_R23_TABLE = "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
REL_R23_SUPERVISOR = "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
REL_FOCUSED = "test/RuntimeV4/NativeG1G2DiffusionV1/focused_tests_r14_compile_min.jl"
REL_PARSE_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/parse_manifest.tsv"
)
REL_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r24_v1/protocol.json"
)
REL_OUTPUT = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r24_v1/actual_run_root_grant_01"
)
REL_R13_SUMMARY = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/summary.json"
)
REL_R13_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/protocol.json"
)
REL_R23_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_r23_spi_static_20260925_r1/protocol.json"
)

SCHEMA = "native-g1g2-gridap-consumer-r24-protocol-v1"
SUMMARY_SCHEMA = "native-g1g2-gridap-consumer-r24-summary-v1"
RSS_LIMIT_BYTES = 2_147_483_648
SAMPLE_INTERVAL_SECONDS = 0.2
WALL_SECONDS_PER_STAGE = 480.0
JULIA_HEAP_HINT = "1G"
COMPILER_MODE = "--compile=min"
STAGES = ("parse_all", "primary", "fresh_replay")
NO_CREDIT = {
    "numerical_credit": False,
    "numerical_status": "not_established",
    "physical_credit": False,
    "physical_status": "unknown",
    "solver_success_claimed": False,
}


class PreflightError(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def file_receipt(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    return {"path": str(path), "bytes": len(data), "sha256": sha256_bytes(data)}


def repo_path(relative: str) -> Path:
    candidate = (ROOT / Path(relative)).resolve()
    try:
        candidate.relative_to(ROOT.resolve())
    except ValueError as exc:
        raise PreflightError(f"repository pin path escapes root: {relative}") from exc
    return candidate


def load_protocol(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise PreflightError(f"protocol read/JSON failure: {type(exc).__name__}: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise PreflightError("protocol schema mismatch")
    return value


def validate_protocol_shape(protocol: Mapping[str, Any]) -> None:
    limits = protocol.get("limits")
    if not isinstance(limits, Mapping):
        raise PreflightError("limits object missing")
    expected_limits = {
        "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
        "wall_seconds_per_stage": WALL_SECONDS_PER_STAGE,
        "sampled_rss_stop_threshold_bytes": RSS_LIMIT_BYTES,
        "julia_heap_size_hint": JULIA_HEAP_HINT,
        "compiler_mode": COMPILER_MODE,
        "julia_threads": 1,
        "blas_threads": 1,
    }
    if dict(limits) != expected_limits:
        raise PreflightError("frozen R24 resource/compiler contract mismatch")
    execution = protocol.get("execution_plan")
    if not isinstance(execution, Mapping) or list(execution.get("stage_order", ())) != list(STAGES):
        raise PreflightError("stage order must remain parse_all/primary/fresh_replay")
    if execution.get("consumer_script") != REL_FOCUSED:
        raise PreflightError("formal consumer script is not the frozen R14 consumer")
    if execution.get("primary_replay_same_consumer_script") is not True:
        raise PreflightError("primary/replay consumer identity is not explicit")
    if execution.get("compile_min_is_only_non_path_argv_delta_from_R13") is not True:
        raise PreflightError("non-path execution argv delta is not limited to --compile=min")
    expected_load_path = f"@;{ROOT};@stdlib"
    if execution.get("julia_load_path") != expected_load_path:
        raise PreflightError("frozen Julia load path differs from R13 environment")
    environment = protocol.get("environment_contract")
    expected_environment = {
        "JULIA_LOAD_PATH": expected_load_path,
        "JULIA_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
    }
    if environment != expected_environment:
        raise PreflightError("runtime environment contract differs from the frozen single-thread R13 setup")
    if protocol.get("fixture_and_solver_thresholds_unchanged") is not True:
        raise PreflightError("fixture/numerical threshold preservation is not declared")
    if protocol.get("archive_is_evidence_only") is not True:
        raise PreflightError("archive scope must be evidence-only")
    pins = protocol.get("input_pins")
    if not isinstance(pins, list) or not pins:
        raise PreflightError("input pin list is missing")
    paths: set[str] = set()
    for pin in pins:
        if not isinstance(pin, Mapping):
            raise PreflightError("input pin entry must be an object")
        rel = pin.get("path")
        digest = pin.get("sha256")
        byte_count = pin.get("bytes")
        if type(rel) is not str or rel in paths:
            raise PreflightError("input pin path is malformed or duplicated")
        if type(digest) is not str or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise PreflightError(f"input pin SHA-256 is malformed: {rel}")
        if type(byte_count) is not int or byte_count < 0:
            raise PreflightError(f"input pin byte count is malformed: {rel}")
        paths.add(rel)
    if protocol.get("input_pin_count") != len(pins):
        raise PreflightError("input pin count does not match the frozen pin list")
    required = {
        REL_RUNNER, REL_TEST, REL_VERIFIER, REL_R23_TABLE, REL_R23_SUPERVISOR,
        REL_FOCUSED, REL_PARSE_MANIFEST, REL_R13_SUMMARY, REL_R23_PROTOCOL,
        REL_R13_PROTOCOL,
        "src/RuntimeV4/NativeG1G2DiffusionCompilerV1.jl",
        "src/RuntimeV4/GridapNativeG1G2DiffusionAdapterV1.jl",
        "test/RuntimeV4/NativeG1G2DiffusionV1/fixture_and_oracle.jl",
        "Project.toml", "Manifest.toml",
    }
    absent = sorted(required - paths)
    if absent:
        raise PreflightError("required consumer/helper/environment pins missing: " + ", ".join(absent))
    r13_summary = json.loads(repo_path(REL_R13_SUMMARY).read_text(encoding="utf-8"))
    for rel, expected_pin in r13_summary["dependencies_before"].items():
        pinned = next((item for item in pins if item["path"] == rel), None)
        if pinned is None or pinned["bytes"] != expected_pin["bytes"] or \
                pinned["sha256"] != expected_pin["sha256"]:
            raise PreflightError(f"R13 frozen input pin missing/drifted in R24: {rel}")
    process_contract = protocol.get("process_table_contract")
    if not isinstance(process_contract, Mapping) or \
            process_contract.get("host_build_pin") != [10, 0, 26200, "AMD64"] or \
            process_contract.get("helper_schema") != "native-g1g2-windows-process-table-r23-v1":
        raise PreflightError("R23 build-pinned native process table contract mismatch")
    if protocol.get("acceptance_boundary", {}).get("numerical_credit") is not False or \
            protocol.get("acceptance_boundary", {}).get("physical_credit") is not False:
        raise PreflightError("R24 static/runtime preparation cannot pregrant numerical or physical credit")
    invocation = protocol.get("invocation_contract")
    if not isinstance(invocation, Mapping):
        raise PreflightError("invocation contract missing")
    static_argv = invocation.get("static_verifier_argv")
    actual_argv = invocation.get("actual_supervisor_argv")
    if type(static_argv) is not list or type(actual_argv) is not list or static_argv == actual_argv:
        raise PreflightError("static and runtime invocation roles must be separately pinned")
    python_pin = invocation.get("python_interpreter")
    if not isinstance(python_pin, Mapping) or type(python_pin.get("path")) is not str:
        raise PreflightError("Python interpreter identity pin is malformed")
    protocol_abs = str(repo_path(REL_PROTOCOL))
    expected_static = [python_pin["path"], "-B", str(repo_path(REL_VERIFIER)),
                       "--protocol", protocol_abs]
    expected_actual = [python_pin["path"], "-B", str(repo_path(REL_RUNNER)),
                       "--dispatch-actual", "--protocol", protocol_abs,
                       "--output", str(repo_path(REL_OUTPUT))]
    if static_argv != expected_static or actual_argv != expected_actual:
        raise PreflightError("frozen static/runtime argv does not address the unique R24 verifier/consumer")
    planned_output = protocol.get("planned_output_leaf")
    if planned_output != REL_OUTPUT:
        raise PreflightError("runtime output leaf differs from frozen unique leaf")
    # The R13 actual protocol is the command parent. Apart from the explicit
    # compile-min mode flag and versioned consumer/artifact paths, every token
    # and stage role must remain exactly equal.
    parent = json.loads(repo_path(REL_R13_PROTOCOL).read_text(encoding="utf-8"))
    parent_commands = parent["execution_plan"]["stage_commands"]
    planned = execution["stage_commands"]
    old_output = parent["execution_plan"]["planned_actual_output"]
    if len(parent_commands) != 3 or len(planned) != 3:
        raise PreflightError("R13/R24 stage command count changed")
    for old, new in zip(parent_commands, planned):
        old_argv = list(old["argv"])
        if old_argv.count(COMPILER_MODE) != 0 or old_argv.count("--threads=1") != 1:
            raise PreflightError("R13 compiler/thread argv parent is unexpected")
        old_argv.insert(old_argv.index("--threads=1") + 1, COMPILER_MODE)
        if old["stage"] != "parse_all":
            old_argv = [arg.replace(old_output, str(repo_path(REL_OUTPUT))) for arg in old_argv]
        old_argv = [arg.replace("focused_tests_r12_markers.jl", Path(REL_FOCUSED).name)
                    for arg in old_argv]
        if new != {"stage": old["stage"], "argv": old_argv}:
            raise PreflightError(f"R24 command is not the pinned R13 command plus approved path/mode delta: {old['stage']}")


def verify_input_pins(protocol: Mapping[str, Any]) -> dict[str, Any]:
    checked: list[dict[str, Any]] = []
    missing: list[dict[str, str]] = []
    changed: list[dict[str, Any]] = []
    for pin in protocol["input_pins"]:
        path = repo_path(pin["path"])
        if not path.is_file():
            missing.append({"path": pin["path"], "reason": "missing_or_not_file"})
            continue
        current = file_receipt(path)
        checked.append({"path": pin["path"], "bytes": current["bytes"], "sha256": current["sha256"]})
        if current["bytes"] != pin["bytes"] or current["sha256"] != pin["sha256"]:
            changed.append({"path": pin["path"], "expected_bytes": pin["bytes"],
                            "actual_bytes": current["bytes"], "expected_sha256": pin["sha256"],
                            "actual_sha256": current["sha256"]})
    result = {"complete": not missing and not changed, "checked_count": len(checked),
              "missing": missing, "changed": changed, "checked": checked}
    if not result["complete"]:
        raise PreflightError("frozen input pins are not complete: " + json.dumps(result, sort_keys=True))
    return result


def validate_invocation(mode: str, observed_argv: list[str], protocol: Mapping[str, Any]) -> None:
    if mode not in ("static_verifier", "actual_supervisor"):
        raise PreflightError("invocation role must be explicitly static_verifier or actual_supervisor")
    expected = protocol["invocation_contract"][f"{mode}_argv"]
    if observed_argv != expected:
        raise PreflightError(
            "observed invocation argv does not match the selected role: " +
            json.dumps({"role": mode, "expected": expected, "observed": observed_argv}, sort_keys=True)
        )


def _load_r23() -> tuple[Any, Any]:
    table_name = "native_process_table_r23_v1"
    table = sys.modules.get(table_name)
    if table is None:
        path = repo_path(REL_R23_TABLE)
        spec = importlib.util.spec_from_file_location(table_name, path)
        if spec is None or spec.loader is None:
            raise PreflightError("frozen R23 process-table helper cannot load")
        table = importlib.util.module_from_spec(spec)
        sys.modules[table_name] = table
        spec.loader.exec_module(table)
    supervisor_name = "supervise_r16_root_audit_r23_v1"
    supervisor = sys.modules.get(supervisor_name)
    if supervisor is None:
        path = repo_path(REL_R23_SUPERVISOR)
        spec = importlib.util.spec_from_file_location(supervisor_name, path)
        if spec is None or spec.loader is None:
            raise PreflightError("frozen R23 exact supervisor helpers cannot load")
        supervisor = importlib.util.module_from_spec(spec)
        sys.modules[supervisor_name] = supervisor
        spec.loader.exec_module(supervisor)
    return table, supervisor


def parse_script_text() -> str:
    return (
        'using SHA; '
        'function ng12_parse_issue(x); '
        'x isa Expr || return nothing; '
        'x.head in (:error,:incomplete) && return x.head; '
        'for child in x.args; issue=ng12_parse_issue(child); '
        'issue===nothing || return issue; end; nothing; end; '
        'function main(args); manifest=args[1]; root=args[2]; count=0; '
        'for line in eachline(manifest); expected,relative=split(line,"\\t";limit=2); '
        'path=joinpath(root,split(relative,\'/\')...); '
        'bytes=read(path); bytes2hex(SHA.sha256(bytes))==expected || '
        'error("parse pin mismatch: "*relative); '
        'parsed=Meta.parseall(String(bytes)); issue=ng12_parse_issue(parsed); '
        'issue===nothing || error("parse tree "*String(issue)*": "*relative); '
        'count+=1; end; println("NG12_PARSE status=pass files=",count); end; '
        'main(ARGS)'
    )


def julia_prefix(julia_exe: str, gridap_project: str) -> list[str]:
    return [julia_exe, f"--project={gridap_project}", "--startup-file=no",
            "--history-file=no", "--threads=1", COMPILER_MODE,
            f"--heap-size-hint={JULIA_HEAP_HINT}"]


def planned_stage_commands(protocol: Mapping[str, Any], output: Path) -> list[dict[str, Any]]:
    execution = protocol["execution_plan"]
    julia = execution["julia_executable"]["path"]
    prefix = julia_prefix(julia, execution["gridap_project"])
    artifact = output / "artifacts" / "primary.bin"
    parse_manifest = repo_path(REL_PARSE_MANIFEST)
    return [
        {"stage": "parse_all", "argv": [*prefix, "-e", parse_script_text(),
            str(parse_manifest), str(ROOT)]},
        {"stage": "primary", "argv": [*prefix, str(repo_path(REL_FOCUSED)),
            "primary", str(artifact)]},
        {"stage": "fresh_replay", "argv": [*prefix, str(repo_path(REL_FOCUSED)),
            "replay", str(artifact)]},
    ]


def _native_resource_reader(pid: int) -> Mapping[str, Any]:
    import psutil
    process = psutil.Process(pid)
    memory = process.memory_info()
    cpu = process.cpu_times()
    command = process.cmdline()
    return {"rss_bytes": memory.rss, "cpu_user_seconds": cpu.user,
            "cpu_system_seconds": cpu.system, "cmdline": command}


def _id_dict(identity: tuple[int, int]) -> dict[str, int]:
    return {"pid": identity[0], "create_time_100ns": identity[1]}


def _identity_map(value: Any) -> tuple[int, int]:
    table, _ = _load_r23()
    return table.validate_identity(value)


def _natural_exit_receipt(identity: tuple[int, int], handle: Any,
                          snapshot_provider: Any, table: Any,
                          wait_for_exit: Any, exit_code_reader: Any) -> dict[str, Any]:
    """Receipt an exit by the already bound exact handle, then reconcile SPI."""
    try:
        table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                    phase="natural-exit-prewait-handle")
        if not wait_for_exit(handle, 0.001):
            return {"identity": _id_dict(identity), "complete": False,
                    "reason": "exact_handle_not_signaled"}
        table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                    phase="natural-exit-postwait-handle")
        code = exit_code_reader(handle)
        after = table.validate_snapshot(snapshot_provider())
        row = after.by_pid.get(identity[0])
        if row is not None and (row.identity.pid, row.identity.create_time_100ns) == identity:
            raise RuntimeError("same exact generation remains after signaled handle")
        return {"schema": "native-g1g2-r24-natural-exit-receipt-v1",
                "identity": _id_dict(identity), "complete": True,
                "signal_sent": False, "wait_confirmed": True,
                "exit_code": code,
                "pid_reused_after_exit": row is not None,
                "replacement_create_time_100ns": (
                    row.identity.create_time_100ns if row is not None else None)}
    except Exception as exc:
        return {"schema": "native-g1g2-r24-natural-exit-receipt-v1",
                "identity": _id_dict(identity), "complete": False,
                "signal_sent": False, "wait_confirmed": False,
                "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)},
                **NO_CREDIT}


def _resource_tree_depth(identity: tuple[int, int], root_identity: tuple[int, int],
                         snapshot: Any, table: Any) -> int:
    by_pid = {row.identity.pid: row for row in snapshot.rows}
    depth = 0
    current = by_pid.get(identity[0])
    seen: set[int] = set()
    while current is not None and current.identity.pid != root_identity[0]:
        if current.identity.pid in seen:
            raise RuntimeError("cycle in process parent chain")
        seen.add(current.identity.pid)
        parent_pid = current.ppid
        if parent_pid == 0:
            raise RuntimeError("tracked descendant no longer traces to root")
        depth += 1
        current = by_pid.get(parent_pid)
    if current is None:
        raise RuntimeError("tracked descendant parent row missing")
    if (current.identity.pid, current.identity.create_time_100ns) != root_identity:
        raise RuntimeError("root PID generation changed while ordering termination")
    return depth


def _bind_tree(snapshot: Any, root_identity: tuple[int, int], tracked: set[tuple[int, int]],
               handles: dict[tuple[int, int], Any], table: Any) -> tuple[tuple[int, int], ...]:
    identities = table.descendant_identities(snapshot, root_identity,
        previously_tracked=tuple(sorted(tracked)))
    for item in identities:
        identity = (item.pid, item.create_time_100ns)
        if identity not in handles:
            row = snapshot.by_pid.get(identity[0])
            if row is None:
                raise RuntimeError("new descendant disappeared before exact handle binding")
            handles[identity] = table.open_exact_process_handle(row)
        table.require_handle_matches_table(handles[identity], identity, snapshot,
            handle_identity_reader=table.read_process_handle_identity)
        tracked.add(identity)
    return tuple(sorted((item.pid, item.create_time_100ns) for item in identities))


def _terminate_tracked(root_identity: tuple[int, int], handles: dict[tuple[int, int], Any],
                       tracked: set[tuple[int, int]], table: Any, audit: Any) -> dict[str, Any]:
    signalled: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []
    snapshot_provider = table.query_native_process_table
    # Discover and terminate exact current descendants for bounded passes.
    for pass_index in range(1, 9):
        try:
            snapshot = table.validate_snapshot(snapshot_provider())
            root_row = snapshot.by_pid.get(root_identity[0])
            if root_row is not None and \
                    (root_row.identity.pid, root_row.identity.create_time_100ns) != root_identity:
                raise RuntimeError("root PID was reused during termination")
            present: list[tuple[int, int]] = []
            if root_row is not None:
                live_tracked: set[tuple[int, int]] = set()
                for identity in tuple(sorted(tracked)):
                    handle = handles.get(identity)
                    if handle is None:
                        raise RuntimeError("tracked identity has no exact retained handle")
                    table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                                phase="termination-preflight-handle")
                    row = snapshot.by_pid.get(identity[0])
                    row_is_exact = row is not None and \
                        (row.identity.pid, row.identity.create_time_100ns) == identity
                    if table.wait_for_process_exit(handle, 0.001):
                        receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                            table, table.wait_for_process_exit, table.process_exit_code)
                        signalled.append(receipt)
                        if receipt.get("complete") is not True:
                            errors.append({"pass": pass_index, "natural_exit": receipt})
                    elif row_is_exact:
                        live_tracked.add(identity)
                    else:
                        raise RuntimeError("tracked generation vanished without exact wait receipt")
                ids = table.descendant_identities(snapshot, root_identity,
                    previously_tracked=tuple(sorted(live_tracked)))
                for item in ids:
                    identity = (item.pid, item.create_time_100ns)
                    if identity not in handles:
                        row = snapshot.by_pid[item.pid]
                        handles[identity] = table.open_exact_process_handle(row)
                    tracked.add(identity)
                    present.append(identity)
                order = sorted(present, key=lambda item: _resource_tree_depth(
                    item, root_identity, snapshot, table), reverse=True)
            else:
                # Root exited: any row recursively parented by a tracked PID is
                # conservatively treated as a remaining descendant.
                rows = snapshot.by_pid
                pid_depth: dict[int, tuple[int, int]] = {root_identity[0]: root_identity}
                changed = True
                while changed:
                    changed = False
                    for row in snapshot.rows:
                        parent = pid_depth.get(row.ppid)
                        if parent is None or row.identity.pid in pid_depth:
                            continue
                        if row.identity.create_time_100ns < parent[1]:
                            raise RuntimeError("orphan child chronology is ambiguous")
                        identity = (row.identity.pid, row.identity.create_time_100ns)
                        pid_depth[row.identity.pid] = identity
                        tracked.add(identity)
                        if identity not in handles:
                            handles[identity] = table.open_exact_process_handle(row)
                        changed = True
                present = [identity for pid, identity in pid_depth.items()
                           if pid != root_identity[0] and rows.get(pid) is not None and
                           (rows[pid].identity.pid, rows[pid].identity.create_time_100ns) == identity]
                order = sorted(present, key=lambda item: item[1], reverse=True)
            for identity in order:
                handle = handles.get(identity)
                if handle is None:
                    errors.append({"pass": pass_index, "identity": _id_dict(identity),
                                   "reason": "missing_exact_handle_before_signal"})
                    continue
                if table.wait_for_process_exit(handle, 0.001):
                    receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                        table, table.wait_for_process_exit, table.process_exit_code)
                    signalled.append(receipt)
                    if receipt.get("complete") is not True:
                        errors.append({"pass": pass_index, "natural_exit": receipt})
                    continue
                result = audit.signal_exact_process(
                    handle, identity,
                    snapshot_provider=snapshot_provider,
                    handle_identity_reader=table.read_process_handle_identity,
                    signal_sender=table.terminate_process_handle,
                    wait_for_exit=table.wait_for_process_exit,
                    exit_code_reader=table.process_exit_code,
                    timeout_seconds=10.0,
                )
                signalled.append(result)
                if result.get("complete") is not True:
                    errors.append({"pass": pass_index, "identity": _id_dict(identity),
                                   "result": result})
            final = table.validate_snapshot(snapshot_provider())
            residual = audit.audit_residual_identities(tracked, final)
            if residual.get("complete") is not True or residual.get("residual_clear") is not True:
                errors.append({"pass": pass_index, "residual_audit": residual})
                continue
            heavy = audit.global_heavy_processes(final)
            if heavy:
                errors.append({"pass": pass_index, "unowned_heavy_identities": [list(x) for x in heavy]})
                continue
            if not errors:
                return {"schema": "native-g1g2-r24-exact-termination-v1",
                        "complete": True, "passes": pass_index,
                        "signals": signalled, "residual_audit": residual,
                        "unowned_heavy_identities": []}
        except Exception as exc:
            errors.append({"pass": pass_index, "type": type(exc).__name__,
                           "message": str(exc), "repr": repr(exc)})
    return {"schema": "native-g1g2-r24-exact-termination-v1", "complete": False,
            "passes": 8, "signals": signalled, "errors": errors,
            **NO_CREDIT}


def _run_stage(output: Path, index: int, stage_name: str, command: list[str],
               environment: Mapping[str, str], table: Any, audit: Any) -> dict[str, Any]:
    stage_dir = output / f"{index:02d}_{stage_name}"
    stage_dir.mkdir()
    started: float | None = None
    started_utc: str | None = None
    samples: list[dict[str, Any]] = []
    tracked: set[tuple[int, int]] = set()
    exit_receipts: list[dict[str, Any]] = []
    termination_receipt: dict[str, Any] | None = None
    monitor_error: dict[str, Any] | None = None
    stop_reason = "natural_exit"
    root_identity: tuple[int, int] | None = None
    root_exit_code: int | None = None
    stage_wall = WALL_SECONDS_PER_STAGE
    root_handle = None
    handles: dict[tuple[int, int], Any] = {}
    cache: dict[str, Any] = {"snapshot": None}

    def snapshot_provider() -> Any:
        value = table.query_native_process_table()
        cache["snapshot"] = table.validate_snapshot(value)
        return cache["snapshot"]

    def handle_provider(row: Any) -> Any:
        snapshot = cache.get("snapshot")
        if snapshot is None:
            raise RuntimeError("R23 sample requested a handle without a pinned snapshot")
        identity = (row.identity.pid, row.identity.create_time_100ns)
        if identity not in handles:
            handles[identity] = table.open_exact_process_handle(row)
        table.require_handle_matches_table(handles[identity], identity, snapshot,
            handle_identity_reader=table.read_process_handle_identity)
        tracked.add(identity)
        return handles[identity]

    # Check and record the global inventory before each child launch.
    prelaunch_snapshot = snapshot_provider()
    heavy_before = audit.global_heavy_processes(prelaunch_snapshot)
    if heavy_before:
        raise RuntimeError("pre-run heavy process inventory is not empty: " + repr(heavy_before))
    with (stage_dir / "stdout.raw").open("xb") as stdout, \
            (stage_dir / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(
            command, cwd=str(ROOT), env=dict(environment), stdout=stdout, stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        started = time.monotonic()
        started_utc = utc_now()
        root_handle = getattr(process, "_handle", None)
        try:
            initial_snapshot = snapshot_provider()
            root_identity = audit.bind_popen_generation(process, initial_snapshot,
                handle_identity_reader=table.read_process_handle_identity)
            tracked.add(root_identity)
            handles[root_identity] = root_handle
        except Exception as exc:
            monitor_error = {"phase": "root_launch_binding", "type": type(exc).__name__,
                             "message": str(exc), "repr": repr(exc)}
            stop_reason = "resource_monitor_incomplete"
        start_receipt = {
            "schema": "native-g1g2-r24-stage-start-v1", "stage": stage_name,
            "started_utc": started_utc, "argv": command, "cwd": str(ROOT),
            "root_pid": process.pid,
            "root_identity": _id_dict(root_identity) if root_identity else None,
            "identity_source": "Popen_original_handle_plus_build_pinned_SPI_raw_FILETIME",
            "global_heavy_before": [list(x) for x in heavy_before],
            "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
            "wall_seconds_per_stage": stage_wall,
            "sampled_rss_stop_threshold_bytes": RSS_LIMIT_BYTES,
            "sampled_stop_semantics": True,
            "environment": {k: environment.get(k) for k in (
                "JULIA_LOAD_PATH", "JULIA_NUM_THREADS", "JULIA_PKG_OFFLINE",
                "JULIA_PKG_PRECOMPILE_AUTO", "OPENBLAS_NUM_THREADS",
                "OMP_NUM_THREADS", "MKL_NUM_THREADS")},
        }
        (stage_dir / "start.json").write_text(json.dumps(start_receipt, indent=2, sort_keys=True),
                                               encoding="utf-8")

        while stop_reason == "natural_exit":
            now_elapsed = time.monotonic() - started
            if now_elapsed >= stage_wall:
                stop_reason = "resource_failure"
                monitor_error = {"phase": "wall_deadline", "elapsed_seconds": now_elapsed,
                                 "limit_seconds": stage_wall,
                                 "reason": "stage_wall_deadline"}
                break
            try:
                current = snapshot_provider()
                # Receipt exits only through the already generation-bound handle.
                for identity in tuple(sorted(tracked)):
                    handle = handles.get(identity)
                    if handle is None:
                        raise RuntimeError("tracked exact identity has no retained handle")
                    table.require_same_identity(table.read_process_handle_identity(handle), identity,
                                                phase="tracked-stage-loop-handle")
                    waited = table.wait_for_process_exit(handle, 0.001)
                    row = current.by_pid.get(identity[0])
                    same_row = row is not None and \
                        (row.identity.pid, row.identity.create_time_100ns) == identity
                    if waited:
                        receipt = _natural_exit_receipt(identity, handle, snapshot_provider,
                            table, table.wait_for_process_exit, table.process_exit_code)
                        exit_receipts.append(receipt)
                        if receipt.get("complete") is not True:
                            raise RuntimeError("exact natural-exit receipt incomplete")
                        tracked.remove(identity)
                        if identity == root_identity:
                            root_exit_code = receipt["exit_code"]
                    elif not same_row:
                        raise RuntimeError("tracked identity absent/reused but original handle is active")

                if root_identity not in tracked:
                    if tracked:
                        raise RuntimeError("consumer root exited while descendants remain; stopping fail-closed")
                    break

                current = snapshot_provider()
                _bind_tree(current, root_identity, tracked, handles, table)
                heavy_unowned = set(audit.global_heavy_processes(current)) - tracked
                if heavy_unowned:
                    raise RuntimeError("unowned heavy process appeared during stage: " +
                                       repr(sorted(heavy_unowned)))

                elapsed = time.monotonic() - started
                sample = audit.sample_process_tree(
                    root_identity, snapshot_provider=snapshot_provider,
                    handle_provider=handle_provider,
                    resource_reader=_native_resource_reader,
                    handle_identity_reader=table.read_process_handle_identity,
                    previously_tracked=tuple(sorted(tracked)),
                    sample_index=len(samples) + 1, elapsed_seconds=elapsed)
                samples.append(sample)
                with (stage_dir / "samples.jsonl").open("a", encoding="utf-8", newline="\n") as stream:
                    stream.write(json.dumps(sample, sort_keys=True) + "\n")
                if sample.get("complete") is not True:
                    stop_reason = "resource_monitor_incomplete"
                    monitor_error = {"phase": "sample_process_tree", "sample": sample}
                    break
                tracked.update({
                    (item["pid"], item["create_time_100ns"])
                    for item in sample["discovered_identities"]
                })
                after_sample = snapshot_provider()
                _bind_tree(after_sample, root_identity, tracked, handles, table)
                heavy_unowned = set(audit.global_heavy_processes(after_sample)) - tracked
                if heavy_unowned:
                    raise RuntimeError("unowned heavy process appeared across sample: " +
                                       repr(sorted(heavy_unowned)))
                disposition = audit.sampled_resource_disposition(samples)
                if disposition.get("disposition") == "resource_failure":
                    stop_reason = "resource_failure"
                    monitor_error = {"phase": "sampled_resource_gate", "disposition": disposition}
                    break
                # Sampled interval is an observation cadence, not a hard RSS cap.
                time.sleep(SAMPLE_INTERVAL_SECONDS)
            except Exception as exc:
                monitor_error = {"phase": "stage_monitor", "type": type(exc).__name__,
                                 "message": str(exc), "repr": repr(exc)}
                stop_reason = "resource_monitor_incomplete"
                break

        if stop_reason != "natural_exit" and root_identity is not None:
            termination_receipt = _terminate_tracked(root_identity, handles, tracked, table, audit)
            if termination_receipt.get("complete") is not True:
                stop_reason = "resource_monitor_incomplete"

        # A final inventory and exact residual audit are mandatory on all exits.
        try:
            final_snapshot = snapshot_provider()
            residual = audit.audit_residual_identities(set(handles), final_snapshot)
            heavy_after = audit.global_heavy_processes(final_snapshot)
            residual_complete = residual.get("complete") is True and \
                residual.get("residual_clear") is True and not heavy_after
        except Exception as exc:
            residual = {"complete": False, "failure": {
                "type": type(exc).__name__, "message": str(exc), "repr": repr(exc)}}
            heavy_after = ()
            residual_complete = False
        if not residual_complete:
            stop_reason = "resource_monitor_incomplete"
            monitor_error = monitor_error or {"phase": "final_residual_audit",
                                              "residual": residual,
                                              "heavy_after": [list(x) for x in heavy_after]}

        close_receipt = {"complete": True, "closed_owned_handles": []}
        for identity, handle in list(handles.items()):
            if identity == root_identity:
                continue  # Popen owns and closes its original handle.
            try:
                table.close_process_handle(handle)
                close_receipt["closed_owned_handles"].append(_id_dict(identity))
                handles.pop(identity)
            except Exception as exc:
                close_receipt["complete"] = False
                close_receipt.setdefault("errors", []).append({
                    "identity": _id_dict(identity), "type": type(exc).__name__,
                    "message": str(exc), "repr": repr(exc)})
        if close_receipt.get("complete") is not True:
            stop_reason = "resource_monitor_incomplete"

        finished = time.monotonic()
        all_exit_receipts_complete = bool(exit_receipts) and all(
            item.get("complete") is True for item in exit_receipts)
        root_receipts = [item for item in exit_receipts
                         if item.get("identity") == _id_dict(root_identity)
                         ] if root_identity is not None else []
        if len(root_receipts) != 1 or root_receipts[0].get("complete") is not True:
            stop_reason = "resource_monitor_incomplete"
        if stop_reason == "natural_exit" and root_exit_code is None and root_receipts:
            root_exit_code = root_receipts[0].get("exit_code")
        disposition = audit.sampled_resource_disposition(samples) if samples else {
            "disposition": "resource_monitor_incomplete", "complete": False,
            "reason": "no_samples", **NO_CREDIT}
        if stop_reason == "resource_failure" and disposition.get("disposition") != "resource_failure":
            reason = (monitor_error or {}).get("disposition", {}).get("reason")
            disposition = {"disposition": "resource_failure", "complete": True,
                           "reason": reason or "stage_wall_deadline", **NO_CREDIT}
        elif stop_reason == "resource_monitor_incomplete":
            disposition = {"disposition": "resource_monitor_incomplete", "complete": False,
                           "reason": "monitor_or_residual_audit_incomplete", **NO_CREDIT}
        final = {
            "schema": "native-g1g2-r24-stage-final-v1", "stage": stage_name,
            "started_utc": started_utc, "finished_utc": utc_now(),
            "elapsed_seconds": finished - started, "argv": command,
            "root_identity": _id_dict(root_identity) if root_identity else None,
            "root_exit_code": root_exit_code,
            "root_exit_receipt": root_receipts[0] if root_receipts else None,
            "stage_exit_receipts": exit_receipts,
            "all_stage_exit_receipts_complete": all_exit_receipts_complete,
            "samples": samples,
            "resource_disposition": disposition,
            "stop_reason": stop_reason,
            "termination_receipt": termination_receipt,
            "final_residual_audit": residual,
            "global_heavy_after": [list(x) for x in heavy_after],
            "handle_close_receipt": close_receipt,
            "resource_monitor_complete": stop_reason == "natural_exit" and residual_complete and
                all_exit_receipts_complete and disposition.get("complete") is True,
            "monitor_error": monitor_error,
            **NO_CREDIT,
        }
        (stage_dir / "final.json").write_text(json.dumps(final, indent=2, sort_keys=True),
                                               encoding="utf-8")
        return final


def _stage_pass(output: Path, stage: Mapping[str, Any], stage_index: int) -> tuple[bool, str | None]:
    if stage.get("stop_reason") != "natural_exit":
        return False, f"{stage.get('stage')}: stop_reason={stage.get('stop_reason')}"
    if stage.get("root_exit_code") != 0:
        return False, f"{stage.get('stage')}: natural root exit code is not zero"
    if stage.get("resource_monitor_complete") is not True:
        return False, f"{stage.get('stage')}: monitor or residual audit incomplete"
    raw = (output / f"{stage_index:02d}_{stage['stage']}" / "stdout.raw").read_text(
        encoding="utf-8", errors="replace")
    marker = "NG12_PARSE status=pass files=108" if stage["stage"] == "parse_all" else (
        f"NG12_RESULT mode={'primary' if stage['stage'] == 'primary' else 'replay'} status=pass")
    if marker not in raw:
        return False, f"{stage.get('stage')}: required consumer marker missing"
    return True, None


def _set_environment(protocol: Mapping[str, Any]) -> dict[str, str]:
    env = dict(os.environ)
    env.update({
        "JULIA_LOAD_PATH": protocol["execution_plan"]["julia_load_path"],
        "JULIA_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
    })
    return env


def dispatch_actual(protocol_path: Path, output: Path, observed_argv: list[str]) -> int:
    protocol = load_protocol(protocol_path)
    validate_protocol_shape(protocol)
    validate_invocation("actual_supervisor", observed_argv, protocol)
    if os.name != "nt":
        raise PreflightError("R23 exact process-table runtime is Windows-only")
    if output.resolve() != repo_path(REL_OUTPUT).resolve():
        raise PreflightError("runtime output must equal the single frozen actual leaf")
    if output.exists():
        raise PreflightError("runtime output leaf already exists; choose a new version, never overwrite")
    pins = verify_input_pins(protocol)
    table, audit = _load_r23()
    if tuple(table.WINDOWS_BUILD_PIN) != tuple(protocol["process_table_contract"]["host_build_pin"]):
        raise PreflightError("runtime Windows build pin differs from R23")
    julia = protocol["execution_plan"]["julia_executable"]
    julia_path = Path(julia["path"])
    if not julia_path.is_file() or file_receipt(julia_path)["sha256"] != julia["sha256"]:
        raise PreflightError("pinned Julia executable is missing or changed")
    python_pin = protocol["invocation_contract"]["python_interpreter"]
    python_path = Path(python_pin["path"])
    if not python_path.is_file():
        raise PreflightError("pinned Python supervisor interpreter is unavailable")
    python_receipt = file_receipt(python_path)
    if python_receipt["bytes"] != python_pin["bytes"] or \
            python_receipt["sha256"] != python_pin["sha256"]:
        raise PreflightError("pinned Python supervisor interpreter changed")
    before_snapshot = table.query_native_process_table()
    heavy_before = audit.global_heavy_processes(before_snapshot)
    if heavy_before:
        raise PreflightError("pre-run heavy process inventory is not empty and complete")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.mkdir()
    (output / "artifacts").mkdir()
    (output / "prelaunch.json").write_text(json.dumps({
        "schema": "native-g1g2-r24-prelaunch-receipt-v1",
        "created_utc": utc_now(), "protocol_sha256": file_receipt(protocol_path)["sha256"],
        "actual_supervisor_argv": observed_argv, "input_pin_count": pins["checked_count"],
        "input_pins_before": pins, "process_table_before": table.smoke_summary(before_snapshot),
        "global_heavy_before": [list(x) for x in heavy_before],
        "runtime_executed": True, "numerical_credit": False, "physical_credit": False,
    }, indent=2, sort_keys=True), encoding="utf-8")
    environment = _set_environment(protocol)
    commands = planned_stage_commands(protocol, output)
    stages: list[dict[str, Any]] = []
    failure: str | None = None
    for index, plan in enumerate(commands, 1):
        stage = dict(_run_stage(output, index, plan["stage"], plan["argv"],
                                environment, table, audit))
        stages.append(stage)
        ok, stage_failure = _stage_pass(output, stage, index)
        if not ok:
            failure = stage_failure
            break
    if failure is None and len(stages) == len(STAGES):
        artifact = output / "artifacts" / "primary.bin"
        required_artifacts = [artifact, Path(str(artifact) + ".preassert.bin"),
            Path(str(artifact) + ".wrong-sign-preassert.bin"),
            Path(str(artifact) + ".replay-preassert.bin")]
        missing = [str(p) for p in required_artifacts if not p.is_file()]
        if missing:
            failure = "consumer artifact/checkpoint missing: " + ", ".join(missing)
    after_pins = verify_input_pins(protocol)
    after_snapshot = table.query_native_process_table()
    residual_heavy = audit.global_heavy_processes(after_snapshot)
    if residual_heavy:
        failure = failure or "post-run global heavy process inventory is nonempty"
    complete = failure is None and len(stages) == len(STAGES) and \
        all(stage.get("resource_monitor_complete") is True for stage in stages)
    summary = {
        "schema": SUMMARY_SCHEMA, "created_utc": utc_now(),
        "runtime_executed": True,
        "formal_consumer": "NativeG1G2DiffusionCompilerV1 -> GridapNativeG1G2DiffusionAdapterV1",
        "unique_consumer_script": REL_FOCUSED,
        "status": "focused_consumer_pass" if complete else "not_established",
        "failure": failure, "stage_order": [stage["stage"] for stage in stages],
        "stages": stages, "input_pins_before": pins,
        "input_pins_after": after_pins,
        "input_pins_unchanged": pins["checked"] == after_pins["checked"],
        "global_heavy_after": [list(x) for x in residual_heavy],
        "resource_contract": dict(protocol["limits"]),
        "software_status": "pass" if complete else "not_established",
        "focused_assertion_status": "passed" if complete else "not_established",
        "numerical_credit": False,
        "numerical_status": "focused_test_assertions_only" if complete else "not_established",
        "physical_credit": False, "physical_status": "unknown",
        "scientific_status": "not_accepted", "resolution": "terminal_deferred",
        "model_provenance": protocol["model_provenance"],
    }
    (output / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True),
                                          encoding="utf-8")
    print(json.dumps({"status": summary["status"], "output": str(output),
        "runtime_executed": True, "completed_stages": summary["stage_order"],
        "failure": failure, "numerical_credit": False, "physical_credit": False}, sort_keys=True))
    return 0 if complete else 1


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--dispatch-actual", action="store_true")
    parser.add_argument("--protocol", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    if not args.dispatch_actual:
        raise PreflightError("runtime dispatch requires explicit --dispatch-actual root-grant invocation")
    protocol_path = Path(args.protocol).resolve()
    output = Path(args.output).resolve()
    observed = list(getattr(sys, "orig_argv", []))
    if not observed:
        observed = [sys.executable, *sys.argv]
    return dispatch_actual(protocol_path, output, observed)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PreflightError as exc:
        print(json.dumps({"status": "preflight_failed", "runtime_executed": False,
                          "error": str(exc), **NO_CREDIT}, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)
