#!/usr/bin/env python3
"""Two-process, test-only replay continuation with explicit resource gates (v6)."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import time
import traceback

try:
    import psutil
except Exception as exc:  # fail before launching Julia when the monitor is absent
    raise SystemExit(f"psutil is required for the replay resource gate: {exc}")

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = pathlib.Path(__file__).resolve().with_name("replay_staged_v6.jl")
DEFAULT_PROTOCOL = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6/replay_protocol_v6.json"
V10_TIMEOUT_RECEIPT_KEYS = (
    "controller_final", "producer_process_final", "producer_process_record", "producer_stdout",
    "producer_stderr", "controller_inputs_before", "controller_inputs_after", "protocol_receipt",
)


def digest(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def write_new(path: pathlib.Path, value: object) -> None:
    if path.exists():
        raise FileExistsError(f"preserve existing replay evidence: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical_bytes(value))


def checked_path(root: pathlib.Path, rel: str) -> pathlib.Path:
    if not isinstance(rel, str) or not rel:
        raise ValueError("protocol path must be a nonempty repository-relative string")
    path = (root / rel).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"protocol path escapes repository: {rel}")
    return path


def resolve_output_target(root: pathlib.Path, output_arg: pathlib.Path | str,
                          protocol_output_leaf: object) -> pathlib.Path:
    """Require --output to resolve exactly to the frozen protocol output leaf."""
    if not isinstance(protocol_output_leaf, str) or not protocol_output_leaf:
        raise ValueError("protocol output_leaf must be a nonempty repository-relative path")
    output_path = pathlib.Path(output_arg)
    output = (root / output_path).resolve() if not output_path.is_absolute() else output_path.resolve()
    expected = checked_path(root, protocol_output_leaf)
    archive_root = checked_path(root,
        "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6")
    if not expected.is_relative_to(archive_root):
        raise ValueError("protocol output_leaf escapes the V6 replay-only archive")
    if not output.is_relative_to(archive_root):
        raise ValueError("output must remain under the V6 replay-only archive leaf")
    if output != expected:
        raise ValueError("--output must resolve exactly to protocol output_leaf")
    return output


def build_child_command(julia_executable: str | pathlib.Path, entrypoint: str, mode: str,
                        output: str | pathlib.Path, source: str | pathlib.Path, protocol_sha: str,
                        carrier_sha: str = "not_applicable", binding_sha: str = "not_applicable") -> list[str]:
    common = [str(julia_executable), "--startup-file=no", "--project=.", entrypoint]
    if mode == "producer":
        if carrier_sha != "not_applicable" or binding_sha != "not_applicable":
            raise ValueError("producer command cannot accept consumer seals")
        return common + ["producer", str(output), str(source), protocol_sha,
                         "not_applicable", "not_applicable"]
    if mode == "consumer":
        return common + ["consumer", str(output), str(source), protocol_sha, carrier_sha, binding_sha]
    raise ValueError("unknown replay child mode")


def build_producer_launch_command(protocol: dict[str, object], julia_executable: str | pathlib.Path,
                                  output: str | pathlib.Path, protocol_sha: str) -> list[str]:
    """Build the exact producer argv used by main, retaining the frozen relative source spelling."""
    source_root = protocol["saved_producer_tree"]["root"]
    return build_child_command(julia_executable, str(protocol["entrypoint"]), "producer",
                               output, str(source_root), protocol_sha)


def build_consumer_launch_command(protocol: dict[str, object], julia_executable: str | pathlib.Path,
                                  output: str | pathlib.Path, producer_root: str | pathlib.Path,
                                  protocol_sha: str, carrier_sha: str, binding_sha: str) -> list[str]:
    """Build the exact consumer argv used by main from its runtime transport seals."""
    return build_child_command(julia_executable, str(protocol["entrypoint"]), "consumer",
                               output, producer_root, protocol_sha, carrier_sha, binding_sha)


def verify_child_command_contract(protocol: dict[str, object]) -> None:
    runtime = protocol["runtime"]
    protocol_sha = "<protocol-sha256>"
    contract = protocol.get("child_command_contract")
    expected = {
        "producer": build_producer_launch_command(protocol, runtime["julia_executable"],
            "<new-producer-numerical-dir>", protocol_sha),
        "consumer": build_consumer_launch_command(protocol, runtime["julia_executable"],
            "<new-consumer-numerical-dir>", "<new-producer-numerical-dir>", protocol_sha,
            "<controller-sealed-carrier-sha256>", "<controller-sealed-binding-sha256>"),
    }
    if contract != expected:
        raise ValueError("protocol child_command_contract differs from controller-generated argv")


def verify_v10_timeout_receipts(root: pathlib.Path, receipts: object) -> dict[str, object]:
    """Validate every original v10 timeout receipt before any output or Julia process."""
    if not isinstance(receipts, dict) or set(receipts) != set(V10_TIMEOUT_RECEIPT_KEYS):
        raise ValueError("v10 timeout receipt set does not match the frozen protocol contract")

    paths: dict[str, pathlib.Path] = {}
    for key in V10_TIMEOUT_RECEIPT_KEYS:
        item = receipts[key]
        if not isinstance(item, dict):
            raise ValueError(f"v10 timeout receipt is not an object ({key})")
        rel = item.get("path")
        size = item.get("bytes")
        expected_sha = item.get("sha256")
        if not isinstance(rel, str) or not rel:
            raise ValueError(f"v10 timeout receipt path is not a nonempty string ({key})")
        if isinstance(size, bool) or not isinstance(size, int) or size < 0:
            raise ValueError(f"v10 timeout receipt byte count is invalid ({key})")
        if not isinstance(expected_sha, str) or len(expected_sha) != 64:
            raise ValueError(f"v10 timeout receipt SHA-256 is invalid ({key})")
        try:
            int(expected_sha, 16)
        except ValueError as exc:
            raise ValueError(f"v10 timeout receipt SHA-256 is invalid ({key})") from exc
        path = checked_path(root, rel)
        if not path.is_file():
            raise FileNotFoundError(f"original v10 timeout receipt missing ({key}): {path}")
        if path.stat().st_size != size or digest(path) != expected_sha:
            raise ValueError(f"original v10 timeout receipt drift ({key}): {path}")
        paths[key] = path

    try:
        controller_final = json.loads(paths["controller_final"].read_text(encoding="utf-8"))
        process_final = json.loads(paths["producer_process_final"].read_text(encoding="utf-8"))
        process_record = json.loads(paths["producer_process_record"].read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("original v10 final/process receipt is not valid UTF-8 JSON") from exc

    if (controller_final.get("schema"), controller_final.get("controller_exit_code"),
            controller_final.get("execution_classification"), controller_final.get("software_batch_complete")) != (
            "mms-staged-controller-result-v10", 124, "resource_interruption", False):
        raise ValueError("original v10 controller timeout/failure semantics changed")
    stages = controller_final.get("stages")
    if not isinstance(stages, list) or not stages or not isinstance(stages[0], dict):
        raise ValueError("original v10 controller producer stage receipt is missing")
    original_stage = stages[0]
    if (original_stage.get("stage"), original_stage.get("stop_reason"), original_stage.get("exit_code")) != (
            "producer", "wall_timeout", 15):
        raise ValueError("original v10 producer timeout/exit semantics changed")
    if (process_final.get("schema"), process_final.get("stop_reason"), process_final.get("exit_code"),
            process_final.get("stage"), process_final.get("controller_exit_code")) != (
            "mms-recorded-process-v6", "wall_timeout", 15, "producer", 124):
        raise ValueError("original v10 producer process receipt changed")
    if (process_record.get("schema"), process_record.get("stop_reason"), process_record.get("exit_code")) != (
            "mms-recorded-process-v6", "wall_timeout", 15):
        raise ValueError("original v10 producer raw process record changed")

    for key in ("producer_stdout", "producer_stderr"):
        item = receipts[key]
        raw_key = key.removeprefix("producer_")
        recorded = process_record.get(raw_key)
        stage_raw = original_stage.get(raw_key)
        expected = (item["bytes"], item["sha256"])
        if not isinstance(recorded, dict) or (recorded.get("bytes"), recorded.get("sha256")) != expected:
            raise ValueError(f"original v10 raw process output receipt mismatch ({key})")
        if not isinstance(stage_raw, dict) or (stage_raw.get("bytes"), stage_raw.get("sha256")) != expected:
            raise ValueError(f"original v10 controller raw output receipt mismatch ({key})")

    before_path = paths["controller_inputs_before"]
    after_path = paths["controller_inputs_after"]
    if digest(before_path) != digest(after_path):
        raise ValueError("original v10 91-key recorder snapshots are not byte-identical")

    return {
        "paths": paths,
        "controller_final": controller_final,
        "original_stage": original_stage,
        "process_final": process_final,
        "process_record": process_record,
    }


def verify_v3_runtime_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the complete immutable V3 failed-run leaf before any V6 output or child."""
    if not isinstance(evidence, dict):
        raise ValueError("V3 hydration-failure evidence is not an object")
    root_rel = evidence.get("root")
    if not isinstance(root_rel, str) or not root_rel:
        raise ValueError("V3 hydration-failure root is invalid")
    runtime_root = checked_path(root, root_rel)
    if not runtime_root.is_dir():
        raise FileNotFoundError(f"V3 runtime failure leaf missing: {runtime_root}")
    entries = evidence.get("entries")
    if not isinstance(entries, list) or len(entries) != evidence.get("file_count"):
        raise ValueError("V3 runtime failure inventory count mismatch")
    actual = file_inventory(runtime_root)
    if actual != entries:
        raise ValueError("V3 runtime failure inventory drift")

    roles = evidence.get("roles")
    expected_roles = {"final", "producer_record", "producer_failure", "stdout", "stderr",
                      "inputs_before", "inputs_after"}
    if not isinstance(roles, dict) or set(roles) != expected_roles:
        raise ValueError("V3 runtime failure role set mismatch")
    paths: dict[str, pathlib.Path] = {}
    for role, rel in roles.items():
        path = checked_path(root, rel)
        if not path.is_relative_to(runtime_root.resolve()):
            raise ValueError(f"V3 runtime failure role escapes its leaf ({role})")
        paths[role] = path
    try:
        final = json.loads(paths["final"].read_text(encoding="utf-8"))
        producer = json.loads(paths["producer_record"].read_text(encoding="utf-8"))
        failure = json.loads(paths["producer_failure"].read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("V3 runtime failure receipts are not valid UTF-8 JSON") from exc

    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"), final.get("solver_exit_code"),
            final.get("inputs_unchanged"), final.get("formal_candidate_credit")) != (
            "mms-replay-only-controller-final-v1", "replay_hydration_unsupported", 72, False,
            "fail", 2, True, False):
        raise ValueError("V3 controller failure classification or solver semantics changed")
    stages = final.get("stages")
    if not isinstance(stages, list) or len(stages) != 1 or not isinstance(stages[0], dict):
        raise ValueError("V3 runtime failure must contain only its producer stage")
    stage = stages[0]
    if (stage.get("stage"), stage.get("stop_reason"), stage.get("exit_code"), stage.get("wall_limit_seconds"),
            stage.get("memory_limit_bytes")) != ("producer", "exited", 72, 480.0, 2**31):
        raise ValueError("V3 producer hydration failure process record changed")
    if (producer.get("schema"), producer.get("stop_reason"), producer.get("exit_code"),
            producer.get("wall_limit_seconds"), producer.get("memory_limit_bytes")) != (
            "mms-replay-recorded-process-v1", "exited", 72, 480.0, 2**31):
        raise ValueError("V3 producer raw process record changed")
    if (failure.get("schema"), failure.get("classification"), failure.get("phase"), failure.get("solver_exit_code"),
            failure.get("numerical_status"), failure.get("authority")) != (
            "mms-replay-only-failure-v1", "replay_hydration_unsupported", "typed_result_hydration", 2, "fail", "no_publish"):
        raise ValueError("V3 typed hydration failure receipt changed")
    error = failure.get("error")
    if not isinstance(error, str) or "merge(::@NamedTuple" not in error or "result_hash" not in error:
        raise ValueError("V3 hydration error signature changed")
    for name in ("stdout", "stderr"):
        recorded = producer.get(name)
        path = paths[name]
        if not isinstance(recorded, dict) or (recorded.get("bytes"), recorded.get("sha256")) != (
                path.stat().st_size, digest(path)):
            raise ValueError(f"V3 raw {name} binding mismatch")
    if digest(paths["inputs_before"]) != digest(paths["inputs_after"]):
        raise ValueError("V3 before/after inputs are not byte-identical")
    if (runtime_root / "consumer_process").exists() or (runtime_root / "consumer_process.json").exists():
        raise ValueError("V3 consumer unexpectedly ran")
    if (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V3 producer completion unexpectedly exists")
    return {"root": runtime_root, "paths": paths, "final": final, "producer": producer, "failure": failure}


def verify_bound_sha256(root: pathlib.Path, rel: object, expected_sha: object, label: str) -> pathlib.Path:
    if not isinstance(expected_sha, str) or len(expected_sha) != 64:
        raise ValueError(f"bound artifact SHA-256 is invalid ({label})")
    try:
        int(expected_sha, 16)
    except ValueError as exc:
        raise ValueError(f"bound artifact SHA-256 is invalid ({label})") from exc
    if not isinstance(rel, str) or not rel:
        raise ValueError(f"bound artifact path is invalid ({label})")
    path = checked_path(root, rel)
    if not path.is_file() or digest(path) != expected_sha:
        raise ValueError(f"bound artifact drift ({label}): {path}")
    return path


def file_inventory(root: pathlib.Path) -> list[dict[str, object]]:
    entries = []
    for path in sorted(p for p in root.rglob("*") if p.is_file()):
        entries.append({"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path)})
    return entries


def verify_inventory(entries: list[dict[str, object]]) -> None:
    for entry in entries:
        path = checked_path(ROOT, str(entry["path"]))
        if not path.is_file():
            raise FileNotFoundError(f"frozen replay input missing: {path}")
        if path.stat().st_size != entry["bytes"] or digest(path) != entry["sha256"]:
            raise ValueError(f"frozen replay input drift: {path}")


def snapshot(entries: list[dict[str, object]]) -> list[dict[str, object]]:
    records = []
    for entry in entries:
        path = checked_path(ROOT, str(entry["path"]))
        records.append({"path": entry["path"], "bytes": path.stat().st_size, "sha256": digest(path)})
    return records


def tree_digest(root: pathlib.Path) -> dict[str, object]:
    items = file_inventory(root)
    body = canonical_bytes(items)
    return {"root": str(root.resolve()), "files": len(items), "bytes": sum(int(x["bytes"]) for x in items),
            "sha256": hashlib.sha256(body).hexdigest(), "entries": items}


def live_tree_bytes(root_pid: int) -> tuple[int, list[dict[str, object]]]:
    try:
        root_proc = psutil.Process(root_pid)
        processes = [root_proc] + root_proc.children(recursive=True)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        processes = []
    total = 0
    identities = []
    seen = set()
    for proc in processes:
        if proc.pid in seen:
            continue
        seen.add(proc.pid)
        try:
            total += proc.memory_info().rss
            identities.append({"pid": proc.pid, "create_time": proc.create_time()})
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            continue
    return total, identities


def terminate_tree(pid: int) -> list[dict[str, object]]:
    try:
        root_proc = psutil.Process(pid)
        children = root_proc.children(recursive=True)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        root_proc = None
        children = []
    residual = []
    for proc in reversed(children):
        try:
            residual.append({"pid": proc.pid, "create_time": proc.create_time()})
            proc.terminate()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if root_proc is not None:
        try:
            root_proc.terminate()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if root_proc is not None:
        try:
            _, alive = psutil.wait_procs(children + [root_proc], timeout=2.0)
            for proc in alive:
                try:
                    proc.kill()
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
            psutil.wait_procs(alive, timeout=2.0)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    return residual


def run_stage(command: list[str], cwd: pathlib.Path, stage_dir: pathlib.Path, limit_s: float,
              memory_limit: int, env: dict[str, str]) -> dict[str, object]:
    stage_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = stage_dir / "stdout.raw"
    stderr_path = stage_dir / "stderr.raw"
    started = time.monotonic()
    started_utc = dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")
    peak = 0
    identities: list[dict[str, object]] = []
    stop_reason = "exited"
    cleanup: list[dict[str, object]] = []
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        proc = subprocess.Popen(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                                creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
        while proc.poll() is None:
            rss, observed = live_tree_bytes(proc.pid)
            peak = max(peak, rss)
            identities.extend(observed)
            elapsed = time.monotonic() - started
            if rss > memory_limit:
                stop_reason = "working_set_limit"
                cleanup = terminate_tree(proc.pid)
                break
            if elapsed >= limit_s:
                stop_reason = "wall_timeout"
                cleanup = terminate_tree(proc.pid)
                break
            time.sleep(0.25)
        try:
            proc.wait(timeout=5.0)
        except subprocess.TimeoutExpired:
            cleanup = cleanup or terminate_tree(proc.pid)
            proc.wait(timeout=5.0)
    ended = time.monotonic()
    stdout_bytes = stdout_path.read_bytes()
    stderr_bytes = stderr_path.read_bytes()
    unique = {(int(x["pid"]), float(x["create_time"])): x for x in identities}
    return {
        "schema": "mms-replay-recorded-process-v1", "command": command, "cwd": str(cwd),
        "pid": proc.pid, "started_utc": started_utc,
        "elapsed_seconds": ended - started, "exit_code": proc.returncode,
        "stop_reason": stop_reason, "peak_sampled_process_tree_working_set_bytes": peak,
        "memory_limit_bytes": memory_limit, "wall_limit_seconds": limit_s,
        "observed_process_identities": list(unique.values()), "terminated_owned_processes": cleanup,
        "stdout": {"path": str(stdout_path), "bytes": len(stdout_bytes), "sha256": hashlib.sha256(stdout_bytes).hexdigest()},
        "stderr": {"path": str(stderr_path), "bytes": len(stderr_bytes), "sha256": hashlib.sha256(stderr_bytes).hexdigest()},
        "memory_scope": "sampled process-tree RSS; sampling is not a continuous operating-system hard limit",
    }


def valid_completion(path: pathlib.Path, stage: str) -> dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    required = {
        "producer": ("mms-replay-only-producer-complete-v1", "test_only_continuation", 2, "fail"),
        "consumer": ("mms-replay-only-consumer-complete-v1", "test_only_continuation", 2, "fail"),
    }[stage]
    if (value.get("schema"), value.get("classification"), value.get("solver_exit_code"), value.get("numerical_status")) != required:
        raise ValueError(f"{stage} completion changed frozen numerical status semantics")
    if value.get("nonlinear_solves") != 0 or value.get("authority") != "no_publish" or value.get("physical_validation") != "unsupported":
        raise ValueError(f"{stage} completion exceeds test-only replay scope")
    if value.get("formal_candidate_credit") is not False:
        raise ValueError(f"{stage} completion promoted a test-only result")
    marker_name = "producer_validator_completed.json" if stage == "producer" else "consumer_suite_completed.json"
    marker = json.loads((path.parent / marker_name).read_text(encoding="utf-8"))
    expected_name = "validate_spatial_manufactured_result_v1" if stage == "producer" else "ManufacturedCandidateV1Tests.result_tests"
    field_name = "validator" if stage == "producer" else "suite"
    if marker.get("runtime_hit") is not True or marker.get(field_name) != expected_name or marker.get("exit_code") != 0:
        raise ValueError(f"{stage} did not record its required runtime hit and exit")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--protocol", type=pathlib.Path, default=DEFAULT_PROTOCOL)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--protocol-sha256", required=True)
    parser.add_argument("--root-serial-slot-granted", action="store_true",
                        help="required explicit acknowledgement that the root allocated its sole Julia slot")
    args = parser.parse_args()
    if not args.root_serial_slot_granted:
        parser.error("refusing Julia execution without --root-serial-slot-granted")

    protocol_path = args.protocol.resolve()
    if protocol_path != DEFAULT_PROTOCOL.resolve():
        raise ValueError("only the frozen replay_protocol_v6.json is accepted")
    protocol_wire = protocol_path.read_bytes()
    actual_protocol_sha = hashlib.sha256(protocol_wire).hexdigest()
    if actual_protocol_sha.lower() != args.protocol_sha256.lower():
        raise ValueError("replay protocol SHA does not match --protocol-sha256")
    protocol = json.loads(protocol_wire)
    if protocol.get("schema") != "mms-replay-only-continuation-protocol-v6" or protocol.get("classification") != "test_only_continuation":
        raise ValueError("unsupported replay protocol schema or classification")
    if protocol.get("runtime_grant") is not False:
        raise ValueError("protocol runtime_grant must remain false; root serial-slot grant is a command argument")
    output = resolve_output_target(ROOT, args.output, protocol.get("output_leaf"))
    if output.exists():
        raise FileExistsError(f"preserve existing replay-only output: {output}")
    verify_child_command_contract(protocol)

    runtime = protocol["runtime"]
    if str(pathlib.Path(sys.executable).resolve()) != str(pathlib.Path(runtime["python_executable"]).resolve()):
        raise ValueError("Python executable differs from the frozen runtime")
    if sys.version.split()[0] != runtime["python_version"] or psutil.__version__ != runtime["psutil_version"]:
        raise ValueError("Python or psutil version differs from the frozen runtime")

    source_files = protocol["owned_source_files"]
    verify_inventory(source_files)
    evidence_docs = protocol["owned_evidence_docs"]
    verify_inventory(evidence_docs)
    parent_v5 = protocol["parent_v5_protocol"]
    verify_bound_sha256(ROOT, parent_v5.get("path"), parent_v5.get("sha256"), "parent v5 protocol")
    v5_no_go = protocol["parent_v5_no_go_review"]
    if v5_no_go.get("classification") != "NO-GO" or v5_no_go.get("julia_started") is not False:
        raise ValueError("V5 reviewer NO-GO ancestry or no-Julia boundary changed")
    verify_bound_sha256(ROOT, v5_no_go.get("report_path"), v5_no_go.get("report_sha256"),
                        "V5 independent NO-GO report")
    verify_bound_sha256(ROOT, v5_no_go.get("manifest_path"), v5_no_go.get("manifest_sha256"),
                        "V5 independent NO-GO manifest")
    parent_v3 = protocol["parent_v3_protocol"]
    parent_v3_path = verify_bound_sha256(ROOT, parent_v3.get("path"), parent_v3.get("sha256"), "parent v3 protocol")
    verified_v3_failure = verify_v3_runtime_failure(ROOT, protocol["v3_runtime_failure"])
    parent_v2 = protocol["parent_v2_protocol"]
    verify_bound_sha256(ROOT, parent_v2.get("path"), parent_v2.get("sha256"), "parent v2 protocol")
    parent_v1 = protocol["parent_v1_protocol"]
    parent_v1_path = verify_bound_sha256(ROOT, parent_v1.get("path"), parent_v1.get("sha256"), "parent v1 protocol")
    v1_failure = protocol["v1_preflight_failure"]
    failure_receipt_path = verify_bound_sha256(
        ROOT, v1_failure.get("receipt_path"), v1_failure.get("receipt_sha256"), "v1 preflight failure receipt")
    verify_bound_sha256(ROOT, v1_failure.get("stderr_path"), v1_failure.get("stderr_sha256"), "v1 preflight stderr")
    verify_bound_sha256(ROOT, v1_failure.get("stdout_path"), v1_failure.get("stdout_sha256"), "v1 preflight stdout")
    failure_receipt = json.loads(failure_receipt_path.read_text(encoding="utf-8"))
    if (failure_receipt.get("source_sha256"), failure_receipt.get("protocol_sha256"),
            failure_receipt.get("natural_exit_code"), failure_receipt.get("julia_started"),
            failure_receipt.get("output_directory_created")) != (
            "baec84c3e9f7549ad800475753141717eb000fb3e001ff4579eaf0873b589eb8",
            digest(parent_v1_path), 1, False, False):
        raise ValueError("preserved V1 preflight failure receipt changed")
    v10_protocol = protocol["v10_protocol"]
    v10_path = checked_path(ROOT, v10_protocol["path"])
    if digest(v10_path) != v10_protocol["sha256"]:
        raise ValueError("preserved v10 protocol drift")
    old_protocol = json.loads(v10_path.read_text(encoding="utf-8"))
    if len(old_protocol["inputs"]) != 89:
        raise ValueError("v10 frozen input count drift")
    pinned_files = old_protocol["inputs"]
    if len(pinned_files) != protocol["v10_protocol"]["pinned_input_count"]:
        raise ValueError("protocol-declared v10 frozen input count drift")
    for item in pinned_files:
        path = checked_path(ROOT, item["path"])
        if path.stat().st_size != item["bytes"] or digest(path) != item["sha256"]:
            raise ValueError(f"v10 pinned input drift: {path}")
    frozen_tree = protocol["saved_producer_tree"]
    tree_root = checked_path(ROOT, frozen_tree["root"])
    actual_tree = file_inventory(tree_root)
    if actual_tree != frozen_tree["entries"]:
        raise ValueError("preserved v10 producer tree drift")
    if len(actual_tree) != frozen_tree["file_count"]:
        raise ValueError("preserved v10 producer tree file count drift")

    v10_timeout = protocol["v10_timeout_receipts"]
    verified_timeout = verify_v10_timeout_receipts(ROOT, v10_timeout)
    timeout_paths = verified_timeout["paths"]
    controller_final = verified_timeout["controller_final"]
    original_stage = verified_timeout["original_stage"]
    process_record = verified_timeout["process_record"]
    numerical_wire = json.loads(checked_path(ROOT, protocol["replay_inputs"]["numerical_result"]["path"]).read_text(encoding="utf-8"))
    numerical_case = numerical_wire["cases"][0]
    if (numerical_wire.get("status"), numerical_wire.get("solver_exit_code"), numerical_case.get("status"),
            numerical_case.get("stopping_reason"), numerical_case.get("solver_exit_code")) != (
            "fail", 2, "fail", "stationary_nonzero_residual", 2):
        raise ValueError("saved numerical failure/solver exit 2 semantics changed")

    all_inputs = {x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in pinned_files}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in frozen_tree["entries"]})
    all_inputs[parent_v3["path"]] = {"path": parent_v3["path"],
        "bytes": parent_v3_path.stat().st_size, "sha256": parent_v3["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in protocol["v3_runtime_failure"]["entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in source_files})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in evidence_docs})
    for key in V10_TIMEOUT_RECEIPT_KEYS:
        item = v10_timeout[key]
        path = timeout_paths[key]
        all_inputs[item["path"]] = {"path": item["path"], "bytes": item["bytes"], "sha256": item["sha256"]}
    for label, item in protocol["replay_inputs"].items():
        path = checked_path(ROOT, item["path"])
        if not path.is_file() or path.stat().st_size != item["bytes"] or digest(path) != item["sha256"]:
            raise ValueError(f"replay input drift ({label}): {path}")
        all_inputs[item["path"]] = {"path": item["path"], "bytes": item["bytes"], "sha256": item["sha256"]}
    input_entries = [all_inputs[k] for k in sorted(all_inputs)]
    julia = pathlib.Path(protocol["runtime"]["julia_executable"])
    if not julia.is_file() or digest(julia) != protocol["runtime"]["julia_sha256"]:
        raise ValueError("pinned Julia executable missing or changed")
    if str(julia.resolve()) != protocol["runtime"]["julia_executable"]:
        raise ValueError("Julia executable path resolution changed")
    if digest(SCRIPT) != protocol["owned_source_files_by_path"][SCRIPT.relative_to(ROOT).as_posix()]:
        raise ValueError("replay controller source hash differs from frozen protocol")
    julia_script = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV6/replay_staged_v6.jl"
    if digest(julia_script) != protocol["owned_source_files_by_path"][julia_script.relative_to(ROOT).as_posix()]:
        raise ValueError("replay Julia entrypoint hash differs from frozen protocol")
    entrypoint = str(julia_script.relative_to(ROOT).as_posix())
    if protocol.get("entrypoint") != entrypoint:
        raise ValueError("protocol entrypoint differs from the exact controller launch path")
    before = snapshot(input_entries)
    stage_limit = float(protocol["stage_limits"]["seconds"])
    memory_limit = int(protocol["stage_limits"]["working_set_bytes"])
    output.mkdir(parents=True)
    write_new(output / "inputs_before.json", before)
    env = os.environ.copy()
    env.update({str(k): str(v) for k, v in protocol.get("environment", {}).items()})
    results: list[dict[str, object]] = []
    completions: list[dict[str, object]] = []
    classification = "program_exception"
    controller_exit = 126
    producer_tree_unchanged = False
    producer_root = output / "producer_process/numerical"
    consumer_root = output / "consumer_process/numerical"
    start = time.monotonic()
    try:
        producer_dir = output / "producer_process"
        producer_cmd = build_producer_launch_command(protocol, julia, producer_root, actual_protocol_sha)
        producer = run_stage(producer_cmd, ROOT, producer_dir, stage_limit, memory_limit, env)
        results.append(dict(producer, stage="producer"))
        write_new(output / "producer_process.json", producer)
        after_producer = snapshot(input_entries)
        write_new(producer_dir / "inputs_after.json", after_producer)
        if before != after_producer:
            classification = "input_drift"
            controller_exit = 125
            raise ValueError("pinned inputs or saved producer tree changed in producer stage")
        complete_path = producer_root / "producer_complete.json"
        if producer["stop_reason"] != "exited" or producer["exit_code"] != 0:
            failure_path = producer_root / "producer_failure.json"
            failure = json.loads(failure_path.read_text(encoding="utf-8")) if failure_path.is_file() else None
            if producer["stop_reason"] in ("wall_timeout", "working_set_limit"):
                classification = "resource_interruption"
                controller_exit = 124 if producer["stop_reason"] == "wall_timeout" else 123
            elif failure and failure.get("classification") == "replay_hydration_unsupported":
                classification = "replay_hydration_unsupported"
                controller_exit = 72
            else:
                classification = "program_exception"
                controller_exit = int(producer["exit_code"] or 1)
            raise RuntimeError(f"producer stage incomplete: {classification}")
        producer_complete = valid_completion(complete_path, "producer")
        binding_path = producer_root / "replay_carrier_binding.json"
        carrier_path = producer_root / "replay_carrier.bin"
        seal = {"carrier_sha256": digest(carrier_path), "binding_sha256": digest(binding_path),
                "carrier_bytes": carrier_path.stat().st_size, "binding_bytes": binding_path.stat().st_size,
                "source_result_sha256": protocol["replay_inputs"]["numerical_result"]["sha256"]}
        if seal["carrier_sha256"] != producer_complete["carrier_sha256"] or seal["binding_sha256"] != producer_complete["carrier_binding_sha256"]:
            raise ValueError("producer completion differs from independent transport seal")
        write_new(output / "producer_transport_seal.json", seal)
        producer_before_consumer = tree_digest(producer_dir)
        write_new(output / "producer_tree_before_consumer.json", producer_before_consumer)
        producer_overhead = time.monotonic() - start - float(producer["elapsed_seconds"])
        if producer_overhead > float(protocol["controller_overhead_seconds_limit"]):
            classification = "resource_interruption"
            controller_exit = 124
            raise TimeoutError("replay controller overhead exceeded before consumer")

        consumer_dir = output / "consumer_process"
        consumer_cmd = build_consumer_launch_command(protocol, julia, consumer_root, producer_root,
            actual_protocol_sha, str(seal["carrier_sha256"]), str(seal["binding_sha256"]))
        consumer = run_stage(consumer_cmd, ROOT, consumer_dir, stage_limit, memory_limit, env)
        results.append(dict(consumer, stage="consumer"))
        write_new(output / "consumer_process.json", consumer)
        after_consumer = snapshot(input_entries)
        write_new(consumer_dir / "inputs_after.json", after_consumer)
        if before != after_consumer:
            classification = "input_drift"
            controller_exit = 125
            raise ValueError("pinned inputs or saved producer tree changed in consumer stage")
        if consumer["stop_reason"] != "exited" or consumer["exit_code"] != 0:
            if consumer["stop_reason"] in ("wall_timeout", "working_set_limit"):
                classification = "resource_interruption"
                controller_exit = 124 if consumer["stop_reason"] == "wall_timeout" else 123
            else:
                classification = "program_exception"
                controller_exit = int(consumer["exit_code"] or 1)
            raise RuntimeError(f"consumer stage incomplete: {classification}")
        consumer_complete = valid_completion(consumer_root / "consumer_complete.json", "consumer")
        producer_after_consumer = tree_digest(producer_dir)
        write_new(output / "producer_tree_after_consumer.json", producer_after_consumer)
        if producer_before_consumer != producer_after_consumer:
            raise ValueError("consumer altered the sealed producer tree")
        producer_tree_unchanged = True
        after = snapshot(input_entries)
        write_new(output / "inputs_after.json", after)
        if before != after:
            classification = "input_drift"
            controller_exit = 125
            raise ValueError("original 89 pins or saved producer tree changed during replay")
        elapsed_children = sum(float(x["elapsed_seconds"]) for x in results)
        overhead = time.monotonic() - start - elapsed_children
        if overhead > float(protocol["controller_overhead_seconds_limit"]):
            classification = "resource_interruption"
            controller_exit = 124
            raise TimeoutError("replay controller overhead limit exceeded")
        if producer_complete["result_hash"] != consumer_complete["result_hash"]:
            raise ValueError("producer/consumer result identity mismatch")
        classification = "test_only_continuation_complete"
        controller_exit = 0
    except Exception:
        if controller_exit == 126:
            classification = "program_exception"
        exception = traceback.format_exc()
    else:
        exception = None
    finally:
        after = snapshot(input_entries)
        if not (output / "inputs_after.json").exists():
            write_new(output / "inputs_after.json", after)
        if before != after and controller_exit == 0:
            classification = "input_drift"
            controller_exit = 125
        final = {
            "schema": "mms-replay-only-controller-final-v1", "classification": classification,
            "controller_exit_code": controller_exit, "test_only_continuation": True,
            "software_complete": controller_exit == 0, "numerical_status": "fail", "solver_exit_code": 2,
            "stopping_reason": "stationary_nonzero_residual", "formal_candidate_credit": False,
            "physical_validation": "unsupported", "authority": "no_publish", "nonlinear_solves": 0,
            "inputs_unchanged": before == after, "producer_tree_unchanged": producer_tree_unchanged,
            "stages": results, "elapsed_seconds": time.monotonic() - start,
            "stage_limits": protocol["stage_limits"],
        }
        if "exception" in locals() and exception:
            final["controller_exception"] = exception
        write_new(output / "final.json", final)
    print(json.dumps({"classification": classification, "controller_exit_code": controller_exit,
                      "output": str(output), "final_sha256": digest(output / "final.json")}, separators=(",", ":")))
    return controller_exit


if __name__ == "__main__":
    raise SystemExit(main())
