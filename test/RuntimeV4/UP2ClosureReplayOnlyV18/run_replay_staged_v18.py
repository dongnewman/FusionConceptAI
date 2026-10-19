#!/usr/bin/env python3
"""Two-process, test-only replay continuation with explicit resource gates (v18)."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import pathlib
import re
import subprocess
import sys
import time
import traceback

try:
    import psutil
except Exception as exc:  # fail before launching Julia when the monitor is absent
    raise SystemExit(f"psutil is required for the replay resource gate: {exc}")

ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = pathlib.Path(__file__).resolve().with_name("replay_staged_v18.jl")
DEFAULT_PROTOCOL = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r18/replay_protocol_v18.json"
V10_TIMEOUT_RECEIPT_KEYS = (
    "controller_final", "producer_process_final", "producer_process_record", "producer_stdout",
    "producer_stderr", "controller_inputs_before", "controller_inputs_after", "protocol_receipt",
)
PROCESS_POLL_INTERVAL_SECONDS = 0.25
AGGREGATE_OVERHEAD_RESERVE_SECONDS = PROCESS_POLL_INTERVAL_SECONDS


class AggregateChildWallBudgetExhausted(RuntimeError):
    """Raised before a child launch when no aggregate budget remains."""


class ControllerOverheadBudgetExhausted(RuntimeError):
    """Raised before a child launch when the separate controller budget is spent."""


class ProcessTreeObservationError(RuntimeError):
    """A process-tree RSS sample is incomplete and must not be treated as a limit check."""

    def __init__(self, scope: str, root_pid: int, process_pid: int | None,
                 partial_rss_bytes: int, observed_process_identities: list[dict[str, object]],
                 cause: BaseException):
        self.evidence = {
            "scope": scope,
            "root_pid": int(root_pid),
            "process_pid": None if process_pid is None else int(process_pid),
            "partial_rss_bytes_not_used_for_gate": int(partial_rss_bytes),
            "observed_process_identities": list(observed_process_identities),
            "error_type": type(cause).__name__,
            "error": str(cause),
        }
        super().__init__(
            f"incomplete process-tree RSS observation at {scope} "
            f"(root_pid={root_pid}, process_pid={process_pid}, "
            f"error={type(cause).__name__}: {cause})")


def controller_overhead_seconds(started_at: float, now: float, child_wall_spent_seconds: float) -> float:
    values = (started_at, now, child_wall_spent_seconds)
    if any(isinstance(value, bool) or not isinstance(value, (int, float)) or
           not math.isfinite(float(value)) for value in values):
        raise ValueError("controller overhead accounting inputs must be finite numbers")
    elapsed = float(now) - float(started_at)
    child = float(child_wall_spent_seconds)
    if elapsed < 0 or child < 0 or child > elapsed:
        raise ValueError("controller overhead accounting inputs are outside their valid range")
    return elapsed - child


def enforce_controller_overhead_budget(started_at: float, child_wall_spent_seconds: float,
                                       limit_seconds: float, now: float | None = None) -> float:
    if isinstance(limit_seconds, bool) or not isinstance(limit_seconds, (int, float)) or \
            not math.isfinite(float(limit_seconds)) or float(limit_seconds) <= 0:
        raise ValueError("controller overhead limit must be a positive finite number")
    current = time.monotonic() if now is None else now
    elapsed = controller_overhead_seconds(started_at, current, child_wall_spent_seconds)
    if elapsed >= float(limit_seconds):
        raise ControllerOverheadBudgetExhausted(
            f"controller overhead budget exhausted before child launch: "
            f"elapsed={elapsed:.9f}s, limit={float(limit_seconds):.9f}s")
    return elapsed


def validate_controller_overhead_contract(protocol: dict[str, object]) -> dict[str, object]:
    limit = protocol.get("controller_overhead_seconds_limit")
    definition = protocol.get("controller_overhead_definition")
    receipt = protocol.get("receipt_contract")
    if isinstance(limit, bool) or not isinstance(limit, (int, float)) or \
            not math.isfinite(float(limit)) or float(limit) != 120.0:
        raise ValueError("controller overhead limit must remain the frozen 120-second cap")
    if not isinstance(definition, str) or "before the read-only preflight" not in definition or \
            "subtracting child intervals" not in definition:
        raise ValueError("controller overhead accounting definition is incomplete")
    if not isinstance(receipt, dict) or receipt.get("controller_overhead_budget") != \
            "final spent, overrun, and limit status" or receipt.get("preflight_timeout_output_leaf_created") is not False:
        raise ValueError("controller overhead timeout receipt contract is incomplete")
    return {"limit_seconds": float(limit), "definition": definition, "receipt": receipt}


def validate_aggregate_child_wall_contract(protocol: dict[str, object]) -> dict[str, float]:
    """Validate the frozen two-stage aggregate wall budget before output creation."""
    stage_limits = protocol.get("stage_limits")
    if not isinstance(stage_limits, dict):
        raise ValueError("aggregate child wall contract has no stage_limits object")
    total = protocol.get("total_child_wall_limit_seconds")
    stage_limit = stage_limits.get("seconds")
    cleanup_grace = protocol.get("termination_cleanup_grace_seconds")
    if any(isinstance(value, bool) or not isinstance(value, (int, float)) or
           not math.isfinite(float(value)) for value in (total, stage_limit, cleanup_grace)):
        raise ValueError("aggregate child wall limits must be finite numbers")
    total = float(total)
    stage_limit = float(stage_limit)
    cleanup_grace = float(cleanup_grace)
    if total <= 0 or stage_limit <= 0 or cleanup_grace <= 0:
        raise ValueError("aggregate child wall limits must be positive")
    minimum = 2.0 * stage_limit
    if total < minimum:
        raise ValueError("aggregate child wall limit is below combined producer/consumer stage caps")
    definition = protocol.get("aggregate_child_wall_definition")
    if not isinstance(definition, str) or "bounded cleanup" not in definition:
        raise ValueError("aggregate child wall accounting definition is missing")
    return {"total_limit_seconds": total, "stage_limit_seconds": stage_limit,
            "cleanup_grace_seconds": cleanup_grace,
            "poll_reserve_seconds": AGGREGATE_OVERHEAD_RESERVE_SECONDS}


def stage_child_wall_budget(total_limit_seconds: float, child_wall_spent_seconds: float,
                            stage_limit_seconds: float, cleanup_grace_seconds: float,
                            poll_reserve_seconds: float = AGGREGATE_OVERHEAD_RESERVE_SECONDS
                            ) -> dict[str, float]:
    """Return the bounded live window while reserving time for kill/cleanup."""
    values = (total_limit_seconds, child_wall_spent_seconds, stage_limit_seconds,
              cleanup_grace_seconds, poll_reserve_seconds)
    if any(isinstance(value, bool) or not isinstance(value, (int, float)) or
           not math.isfinite(float(value)) for value in values):
        raise ValueError("aggregate child wall budget inputs must be finite numbers")
    total = float(total_limit_seconds)
    spent = float(child_wall_spent_seconds)
    stage_cap = float(stage_limit_seconds)
    cleanup = float(cleanup_grace_seconds)
    poll = float(poll_reserve_seconds)
    if total <= 0 or spent < 0 or stage_cap <= 0 or cleanup <= 0 or poll < 0:
        raise ValueError("aggregate child wall budget inputs are outside their valid range")
    remaining = total - spent
    if remaining <= cleanup + poll:
        raise AggregateChildWallBudgetExhausted(
            f"aggregate child wall budget exhausted before launch: remaining={remaining:.9f}s, "
            f"cleanup_reserve={cleanup:.9f}s, poll_reserve={poll:.9f}s")
    live_limit = min(stage_cap, remaining - cleanup - poll)
    if live_limit <= 0:
        raise AggregateChildWallBudgetExhausted("aggregate child wall budget has no safe live window")
    return {"total_limit_seconds": total, "spent_before_seconds": spent,
            "remaining_before_seconds": remaining, "stage_cap_seconds": stage_cap,
            "live_limit_seconds": live_limit, "cleanup_grace_seconds": cleanup,
            "poll_reserve_seconds": poll}


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
        "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r18")
    if not expected.is_relative_to(archive_root):
        raise ValueError("protocol output_leaf escapes the V18 replay-only archive")
    if not output.is_relative_to(archive_root):
        raise ValueError("output must remain under the V18 replay-only archive leaf")
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


def validate_original_v10_process_receipts(process_final: object, process_record: object) -> None:
    """Check the historical v10 process receipt schema, independent of this continuation version."""
    if not isinstance(process_final, dict) or not isinstance(process_record, dict):
        raise ValueError("original v10 producer process receipt is not a JSON object")
    if (process_final.get("schema"), process_final.get("stop_reason"), process_final.get("exit_code"),
            process_final.get("stage"), process_final.get("controller_exit_code")) != (
            "mms-recorded-process-v3", "wall_timeout", 15, "producer", 124):
        raise ValueError("original v10 producer process receipt changed")
    if (process_record.get("schema"), process_record.get("stop_reason"), process_record.get("exit_code"),
            process_record.get("stage"), process_record.get("controller_exit_code")) != (
            "mms-recorded-process-v3", "wall_timeout", 15, None, 124):
        raise ValueError("original v10 producer raw process record changed")


def verify_child_command_contract(protocol: dict[str, object]) -> None:
    runtime = protocol["runtime"]
    protocol_sha = "<protocol-sha256>"
    coverage = protocol.get("coverage_contract")
    coverage_child = coverage.get("child_argv") if isinstance(coverage, dict) else None
    if not isinstance(coverage_child, dict) or coverage_child.get("entrypoint") != protocol.get("entrypoint") or \
            "V18 tests follow" not in str(coverage_child.get("negative_control", "")):
        raise ValueError("protocol child_argv coverage description is stale or incomplete")
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
    validate_original_v10_process_receipts(process_final, process_record)

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


def verify_v10_replay_failure(root: pathlib.Path, contract: object,
                              review: object) -> dict[str, object]:
    """Bind the actual V10 replay failure, its immutable sources, diagnosis, and independent NO-GO."""
    if not isinstance(contract, dict) or not isinstance(review, dict):
        raise ValueError("V10 replay failure ancestry is incomplete")
    parent_protocol = contract.get("protocol")
    if not isinstance(parent_protocol, dict):
        raise ValueError("V10 actual replay protocol metadata is missing")
    protocol_path = verify_bound_sha256(root, parent_protocol.get("path"),
                                        parent_protocol.get("sha256"), "V10 actual replay protocol")
    v10_protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    v10_source_entries = v10_protocol.get("owned_source_files", [])
    for item in v10_source_entries:
        path = verify_bound_sha256(root, item.get("path"), item.get("sha256"), "V10 owned source")
        if path.stat().st_size != item.get("bytes"):
            raise ValueError(f"V10 owned source byte count drift: {path}")
    source_by_path = v10_protocol.get("owned_source_files_by_path")
    if not isinstance(source_by_path, dict) or len(source_by_path) != 3:
        raise ValueError("V10 owned source map is incomplete")
    if source_by_path != {item["path"]: item["sha256"] for item in v10_source_entries}:
        raise ValueError("V10 owned source file list and path map differ")

    runtime = contract.get("runtime")
    if not isinstance(runtime, dict) or not isinstance(runtime.get("entries"), list):
        raise ValueError("V10 actual runtime inventory is missing")
    runtime_root = checked_path(root, runtime.get("root"))
    entries = runtime["entries"]
    verify_inventory(entries)
    if file_inventory(runtime_root) != entries or len(entries) != runtime.get("file_count"):
        raise ValueError("V10 replay output leaf differs from its complete frozen inventory")
    if sum(int(item["bytes"]) for item in entries) != runtime.get("bytes"):
        raise ValueError("V10 replay output leaf byte total changed")

    final_path = checked_path(root, runtime.get("final_path"))
    process_path = checked_path(root, runtime.get("producer_process_path"))
    failure_path = checked_path(root, runtime.get("producer_failure_path"))
    stdout_path = checked_path(root, runtime.get("stdout_path"))
    stderr_path = checked_path(root, runtime.get("stderr_path"))
    before_path = checked_path(root, runtime.get("inputs_before_path"))
    after_path = checked_path(root, runtime.get("inputs_after_path"))
    producer_after_path = checked_path(root, runtime.get("producer_inputs_after_path"))
    final = json.loads(final_path.read_text(encoding="utf-8"))
    process = json.loads(process_path.read_text(encoding="utf-8"))
    failure = json.loads(failure_path.read_text(encoding="utf-8"))
    before_wire = before_path.read_bytes()
    after_wire = after_path.read_bytes()
    producer_after_wire = producer_after_path.read_bytes()
    before = json.loads(before_wire)
    if before_wire != after_wire or before_wire != producer_after_wire or len(before) != 351:
        raise ValueError("V10 replay input snapshots are not the same frozen 351-entry bytes")
    verify_inventory(before)

    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"),
            final.get("solver_exit_code"), final.get("stopping_reason"),
            final.get("authority"), final.get("inputs_unchanged"),
            final.get("producer_tree_unchanged"), final.get("nonlinear_solves")) != (
            "mms-replay-only-controller-final-v2", "replay_hydration_unsupported", 72, False,
            "fail", 2, "stationary_nonzero_residual", "no_publish", True, False, 0):
        raise ValueError("V10 replay controller failure or saved solver semantics changed")
    if (process.get("schema"), process.get("stage"), process.get("stop_reason"),
            process.get("exit_code"), process.get("memory_limit_bytes")) != (
            "mms-replay-recorded-process-v2", None, "exited", 72, 2147483648):
        raise ValueError("V10 replay producer process receipt changed")
    stages = final.get("stages")
    if not isinstance(stages, list) or len(stages) != 1 or not isinstance(stages[0], dict):
        raise ValueError("V10 replay controller stage differs from its process receipt")
    stage_record = dict(stages[0])
    if stage_record.pop("stage", None) != "producer" or stage_record != process:
        raise ValueError("V10 replay controller stage differs from its process receipt")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "canonical_result_hash_check",
            "ArgumentError: spatial result hash mismatch", 2, "fail", "no_publish"):
        raise ValueError("V10 typed hydration failure signature changed")
    if process.get("child_wall_seconds", 1e9) > 480 or \
            process.get("peak_sampled_process_tree_working_set_bytes", 1e99) > 2147483648:
        raise ValueError("V10 replay process exceeded its recorded per-stage limits")
    for key, path in (("stdout", stdout_path), ("stderr", stderr_path)):
        raw = process.get(key)
        if not isinstance(raw, dict) or (raw.get("path"), raw.get("bytes"), raw.get("sha256")) != (
                str(path.resolve()), path.stat().st_size, digest(path)):
            raise ValueError(f"V10 actual producer {key} receipt differs from its raw bytes")
    if process.get("command") != final.get("stages", [{}])[0].get("command"):
        raise ValueError("V10 actual producer argv differs between controller and process receipts")
    expected_command = [v10_protocol["runtime"]["julia_executable"], "--startup-file=no", "--project=.",
        v10_protocol["entrypoint"], "producer",
        str((runtime_root / "producer_process/numerical").resolve()),
        v10_protocol["saved_producer_tree"]["root"], parent_protocol["sha256"],
        "not_applicable", "not_applicable"]
    if process.get("command") != expected_command:
        raise ValueError("V10 recorded producer argv differs from the frozen protocol and actual output leaf")
    if str(pathlib.Path(process.get("cwd", "")).resolve()) != str(root.resolve()):
        raise ValueError("V10 producer working directory changed")

    phases_root = runtime_root / "producer_process/numerical/hydration_phases"
    phase_names = ("canonical_body_parse", "semantic_hash_recompute", "result_digest_injection",
                   "typed_wire_encoding", "json3_typed_parse", "concrete_type_check")
    phases = []
    for name in phase_names:
        phase_path = phases_root / f"{name}.json"
        if not phase_path.is_file():
            raise FileNotFoundError(f"V10 hydration checkpoint missing: {phase_path}")
        value = json.loads(phase_path.read_text(encoding="utf-8"))
        if value.get("phase") != name or value.get("completed") is not True:
            raise ValueError(f"V10 hydration checkpoint changed: {name}")
        phases.append(value)
    if (phases[1].get("result_hash"), phases[2].get("result_hash"), phases[3].get("result_hash"),
            phases[4].get("result_hash"), phases[5].get("result_hash")) != ("10eeefa961fe7dc6e4a822af1b5a159054a4d97fa916304f7f27893d78087b1f",) * 5:
        raise ValueError("V10 recomputed saved result identity changed")
    if (runtime_root / "producer_process/numerical/hydration_phases/canonical_result_hash_check.json").exists():
        raise ValueError("V10 unexpectedly completed the failing canonical result hash check")
    if (runtime_root / "producer_process/numerical/producer_complete.json").exists() or \
            (runtime_root / "consumer_process").exists() or \
            (runtime_root / "producer_tree_before_consumer.json").exists() or \
            (runtime_root / "producer_tree_after_consumer.json").exists():
        raise ValueError("V10 failed replay unexpectedly reached completion or consumer tree comparison")
    stdout = stdout_path.read_text(encoding="utf-8")
    stderr = stderr_path.read_text(encoding="utf-8")
    if "MMS_REPLAY_ONLY mode=producer julia=1.10.5" not in stdout or \
            "MMS_REPLAY_ONLY_FAIL classification=replay_hydration_unsupported error=ArgumentError: spatial result hash mismatch" not in stderr:
        raise ValueError("V10 original replay stdout/stderr failure signature changed")

    diagnosis = contract.get("diagnosis")
    if not isinstance(diagnosis, dict) or not isinstance(diagnosis.get("entries"), list):
        raise ValueError("V10 read-only diagnosis evidence is missing")
    verify_inventory(diagnosis["entries"])
    diagnosis_root = checked_path(root, diagnosis.get("root"))
    if file_inventory(diagnosis_root) != diagnosis["entries"] or len(diagnosis["entries"]) != 4:
        raise ValueError("V10 diagnosis leaf inventory changed or contains implementation code")

    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V10 independent postrun review report")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V10 independent postrun review manifest")
    commands_path = verify_bound_sha256(root, review.get("commands_path"), review.get("commands_sha256"),
                                        "V10 independent postrun review commands")
    report = report_path.read_text(encoding="utf-8")
    commands = commands_path.read_text(encoding="utf-8")
    review_manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    audit = review_manifest.get("reviewer_audit")
    if (review_manifest.get("schema"), review_manifest.get("classification"),
            review_manifest.get("reviewer_task"),
            review_manifest.get("julia_started_by_reviewer"),
            review_manifest.get("solver_started_by_reviewer"),
            review_manifest.get("archive_contains_executable_files"),
            isinstance(audit, dict) and audit.get("exit_code")) != (
            "independent_mms_v10_postrun_review_manifest_v1",
            "NO_GO_replay_hydration_unsupported", "/root/mms_closure/oracle_review",
            False, False, False, 0):
        raise ValueError("V10 independent postrun review manifest scope/classification changed")
    if review_manifest.get("protocol") != parent_protocol:
        raise ValueError("V10 independent review is not bound to the frozen actual replay protocol")
    if review_manifest.get("owned_sources") != v10_protocol.get("owned_source_files_by_path"):
        raise ValueError("V10 independent review source inventory differs from the frozen protocol")
    manifest_report = review_manifest.get("review_report")
    if not isinstance(manifest_report, dict) or (manifest_report.get("path"),
            manifest_report.get("sha256")) != ("review.md", review.get("report_sha256")):
        raise ValueError("V10 independent review report pin differs from its manifest")
    root_observation = review_manifest.get("root_observation")
    if not isinstance(root_observation, dict):
        raise ValueError("V10 root actual-run observation is missing from the independent review")
    root_observation_path = verify_bound_sha256(root, root_observation.get("path"),
        root_observation.get("sha256"), "V10 root actual-run observation")
    observation = json.loads(root_observation_path.read_text(encoding="utf-8"))
    observation_files = observation.get("actual_files")
    runtime_rel = pathlib.PurePosixPath(runtime["root"])
    expected_observation_files = {pathlib.PurePosixPath(item["path"]).relative_to(runtime_rel).as_posix(): {
        "relative_path": item["path"], "bytes": item["bytes"], "sha256": item["sha256"]} for item in entries}
    if observation.get("schema") != "root_mms_v10_actual_observation_v1" or \
            observation.get("classification") != "replay_hydration_unsupported" or \
            observation_files != expected_observation_files:
        raise ValueError("V10 root observation does not match the complete frozen runtime inventory")
    outcome = observation.get("outcome")
    if not isinstance(outcome, dict) or (
            outcome.get("controller_exit_code"), outcome.get("producer_exit_code"),
            outcome.get("error"), outcome.get("hydration_stage"), outcome.get("inputs_unchanged"),
            outcome.get("producer_tree_unchanged"), outcome.get("solver_exit_code_saved"),
            outcome.get("saved_numerical_status"), outcome.get("consumer_started"),
            outcome.get("nonlinear_solves"), outcome.get("authority")) != (
            72, 72, "ArgumentError: spatial result hash mismatch", "canonical_result_hash_check",
            True, False, 2, "fail", False, 0, "no_publish"):
        raise ValueError("V10 root actual-run outcome or saved solver lineage changed")
    observation_support_paths = [root_observation_path]
    grant_record = observation.get("grant")
    if not isinstance(grant_record, dict):
        raise ValueError("V10 root execution grant receipt is missing")
    observation_support_paths.append(verify_bound_sha256(root, grant_record.get("relative_path"),
        grant_record.get("sha256"), "V10 root execution grant"))
    sidecars = observation.get("controller_sidecars")
    if not isinstance(sidecars, dict) or set(sidecars) != {
            "controller.exit.txt", "controller.stdout.raw", "controller.stderr.raw"}:
        raise ValueError("V10 root controller sidecar inventory is incomplete")
    controller_exit_path = checked_path(root, sidecars["controller.exit.txt"]["relative_path"])
    if controller_exit_path.read_text(encoding="utf-8").strip() != "72":
        raise ValueError("V10 root controller raw exit receipt changed")
    for item in sidecars.values():
        if not isinstance(item, dict):
            raise ValueError("V10 root controller sidecar entry is invalid")
        path = verify_bound_sha256(root, item.get("relative_path"), item.get("sha256"),
                                   "V10 root controller sidecar")
        if path.stat().st_size != item.get("bytes"):
            raise ValueError("V10 root controller sidecar byte count changed")
        observation_support_paths.append(path)
    if not isinstance(audit, dict):
        raise ValueError("V10 independent postrun review audit receipt is missing")
    review_entries = review.get("entries")
    if not isinstance(review_entries, list) or len(review_entries) != 6:
        raise ValueError("V10 independent review artifact inventory is missing")
    verify_inventory(review_entries)
    review_leaf = manifest_path.parent
    if file_inventory(review_leaf) != review_entries:
        raise ValueError("V10 independent review artifact inventory changed")

    def verify_manifest_leaf_file(key: str, hash_key: str, label: str) -> pathlib.Path:
        name = audit.get(key)
        if not isinstance(name, str) or pathlib.PurePosixPath(name).name != name:
            raise ValueError(f"V10 independent review {label} path is invalid")
        path = (review_leaf / name).resolve()
        if not path.is_relative_to(review_leaf.resolve()):
            raise ValueError(f"V10 independent review {label} escapes its evidence leaf")
        rel = path.relative_to(root.resolve()).as_posix()
        return verify_bound_sha256(root, rel, audit.get(hash_key), f"V10 independent review {label}")

    audit_exit_path = verify_manifest_leaf_file("exit_code_file", "exit_code_file_sha256", "audit exit receipt")
    audit_stdout_path = verify_manifest_leaf_file("stdout", "stdout_sha256", "audit stdout")
    audit_stderr_path = verify_manifest_leaf_file("stderr", "stderr_sha256", "audit stderr")
    command_name = audit.get("command_record")
    if command_name != commands_path.name or pathlib.Path(commands_path).resolve().parent != review_leaf.resolve() or \
            audit.get("command_record_sha256") != digest(commands_path):
        raise ValueError("V10 independent review command record differs from its manifest")
    if audit_exit_path.read_text(encoding="utf-8").strip() != "0":
        raise ValueError("V10 independent review audit did not exit zero")
    if audit_stderr_path.stat().st_size != 0 or audit_stdout_path.stat().st_size == 0:
        raise ValueError("V10 independent review raw command outputs changed")
    runtime_evidence = review_manifest.get("runtime_evidence")
    if not isinstance(runtime_evidence, dict) or (
            runtime_evidence.get("controller_exit"), runtime_evidence.get("producer_exit"),
            runtime_evidence.get("hydration_stage"), runtime_evidence.get("nonlinear_solves"),
            runtime_evidence.get("consumer_started"), runtime_evidence.get("authority"),
            runtime_evidence.get("formal_candidate_credit")) != (
            72, 72, "canonical_result_hash_check", 0, False, "no_publish", False):
        raise ValueError("V10 independent review runtime evidence changed")
    integrity = review_manifest.get("integrity_checks")
    if not isinstance(integrity, dict) or (
            integrity.get("repo_snapshot_entries"), integrity.get("input_snapshot_bytes_equal"),
            integrity.get("repo_snapshot_current_mismatches"),
            integrity.get("saved_numerical_tree_file_count"),
            integrity.get("saved_numerical_tree_current_mismatches"),
            integrity.get("runtime_leaf_file_count"), integrity.get("runtime_leaf_hash_mismatches"),
            integrity.get("preserved_solver_exit")) != (351, True, 0, 119, 0, 17, 0, 2):
        raise ValueError("V10 independent review integrity summary changed")
    if integrity.get("inputs_before_sha256") != integrity.get("inputs_after_sha256") or \
            integrity.get("saved_numerical_tree_protocol_sha256") != \
            v10_protocol["saved_producer_tree"]["sha256"] or \
            integrity.get("original_numerical_result_sha256") != \
            v10_protocol["replay_inputs"]["numerical_result"]["sha256"]:
        raise ValueError("V10 independent review input/tree/result identity changed")
    if "NO-GO" not in report or "canonical_result_hash_check" not in report or \
            "producer_tree_unchanged=false" not in report:
        raise ValueError("V10 independent postrun review conclusion or evidence boundary changed")
    if "Exact validation invocation:" not in commands or "did not launch or call Julia" not in report:
        raise ValueError("V10 independent postrun review command/exit evidence changed")

    return {"protocol_path": protocol_path, "protocol_entry": {
                "path": parent_protocol["path"], "bytes": protocol_path.stat().st_size,
                "sha256": parent_protocol["sha256"]}, "source_entries": v10_source_entries,
            "runtime_root": runtime_root, "runtime_entries": entries,
            "final": final, "process": process, "failure": failure, "phases": phases,
            "tree_comparison_status": "not_reached", "diagnosis_root": diagnosis_root,
            "review_report_path": report_path, "review_manifest_path": manifest_path,
            "review_commands_path": commands_path, "review_audit_exit_path": audit_exit_path,
            "review_audit_stdout_path": audit_stdout_path,
            "review_audit_stderr_path": audit_stderr_path, "review_entries": review_entries,
            "review_manifest": review_manifest, "root_observation_path": root_observation_path,
            "observation_support_paths": observation_support_paths}


def verify_v11_actual_failure(root: pathlib.Path, evidence: object,
                              diagnosis_evidence: object) -> dict[str, object]:
    """Bind the immutable V11 runtime failure and its observe-first diagnosis."""
    if not isinstance(evidence, dict) or not isinstance(diagnosis_evidence, dict):
        raise ValueError("V11 failure and diagnosis ancestry are incomplete")
    parent_protocol = evidence.get("protocol")
    if not isinstance(parent_protocol, dict):
        raise ValueError("V11 frozen protocol reference is missing")
    protocol_path = verify_bound_sha256(root, parent_protocol.get("path"),
                                        parent_protocol.get("sha256"), "V11 frozen protocol")
    v11 = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (v11.get("schema"), v11.get("version"), v11.get("classification"), v11.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v11", 11, "test_only_continuation", False):
        raise ValueError("V11 protocol identity or no-credit boundary changed")
    if v11.get("preserved_numerical_status") != {
            "authority": "no_publish", "physical_validation": "unsupported", "solver_exit_code": 2,
            "status": "fail", "stopping_reason": "stationary_nonzero_residual"}:
        raise ValueError("V11 preserved numerical failure semantics changed")
    if len(v11.get("v10_protocol", {}).get("path", "")) == 0 or \
            v11.get("v10_protocol", {}).get("pinned_input_count") != 89 or \
            len(v11.get("saved_producer_tree", {}).get("entries", [])) != 119:
        raise ValueError("V11 did not retain the original 89/119 pinned inputs")

    source_entries = v11.get("owned_source_files")
    if not isinstance(source_entries, list) or len(source_entries) != 3:
        raise ValueError("V11 owned source inventory is incomplete")
    verify_inventory(source_entries)
    for item in source_entries:
        path = verify_bound_sha256(root, item.get("path"), item.get("sha256"), "V11 immutable source")
        if path.stat().st_size != item.get("bytes"):
            raise ValueError(f"V11 immutable source byte-count drift: {path}")

    runtime = evidence.get("runtime")
    static = evidence.get("static_evidence")
    if not isinstance(runtime, dict) or not isinstance(static, dict):
        raise ValueError("V11 runtime/static evidence inventory is missing")
    runtime_root = checked_path(root, runtime.get("root"))
    runtime_entries = runtime.get("entries")
    if not isinstance(runtime_entries, list):
        raise ValueError("V11 runtime inventory is not a list")
    verify_inventory(runtime_entries)
    if file_inventory(runtime_root) != runtime_entries or len(runtime_entries) != runtime.get("file_count"):
        raise ValueError("V11 runtime output leaf differs from its complete frozen inventory")
    if sum(int(item["bytes"]) for item in runtime_entries) != runtime.get("bytes"):
        raise ValueError("V11 runtime output leaf byte total changed")
    final_path = checked_path(root, runtime.get("final_path"))
    process_path = checked_path(root, runtime.get("producer_process_path"))
    failure_path = checked_path(root, runtime.get("failure_path"))
    stdout_path = checked_path(root, runtime.get("stdout_path"))
    stderr_path = checked_path(root, runtime.get("stderr_path"))
    before_path = checked_path(root, runtime.get("inputs_before_path"))
    after_path = checked_path(root, runtime.get("inputs_after_path"))
    final = json.loads(final_path.read_text(encoding="utf-8"))
    process = json.loads(process_path.read_text(encoding="utf-8"))
    failure = json.loads(failure_path.read_text(encoding="utf-8"))
    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("solver_exit_code"), final.get("numerical_status"), final.get("authority"),
            final.get("software_complete"), final.get("producer_tree_comparison_status"),
            final.get("producer_tree_unchanged"), final.get("inputs_unchanged"),
            final.get("nonlinear_solves"), final.get("test_only_continuation"),
            final.get("stopping_reason")) != (
            "mms-replay-only-controller-final-v3", "replay_hydration_unsupported", 72, 2, "fail",
            "no_publish", False, "not_reached", None, True, 0, True, "stationary_nonzero_residual"):
        raise ValueError("V11 final classification, solver failure, or not-reached semantics changed")
    verify_v11_process_receipt(process)
    stages = final.get("stages")
    if not isinstance(stages, list) or len(stages) != 1 or not isinstance(stages[0], dict):
        raise ValueError("V11 failed run must contain exactly its producer stage")
    expected_command = list(v11["child_command_contract"]["producer"])
    expected_command[3] = v11["entrypoint"]
    expected_command[4] = "producer"
    expected_command[5] = str((runtime_root / "producer_process/numerical").resolve())
    expected_command[7] = parent_protocol["sha256"]
    if stages[0].get("command") != expected_command:
        raise ValueError("V11 recorded producer argv differs from frozen protocol and actual output leaf")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("solver_exit_code"), failure.get("numerical_status"), failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "observe_typed_body_before_assertions",
            2, "fail", "no_publish"):
        raise ValueError("V11 first actual hydration failure receipt changed")
    if (hashlib.sha256(before_path.read_bytes()).hexdigest() != hashlib.sha256(after_path.read_bytes()).hexdigest()):
        raise ValueError("V11 pinned-input snapshot changed during its failed replay")
    if runtime_root.joinpath("consumer_process").exists() or runtime_root.joinpath(
            "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V11 failure unexpectedly published producer completion or consumer stage")
    for stage_raw_name, path in (("stdout", stdout_path), ("stderr", stderr_path)):
        actual = {"bytes": path.stat().st_size, "sha256": digest(path)}
        process_raw = process.get(stage_raw_name)
        if not isinstance(process_raw, dict) or {"bytes": process_raw.get("bytes"),
                "sha256": process_raw.get("sha256")} != actual or process_raw.get("path") != str(path.resolve()):
            raise ValueError(f"V11 raw producer {stage_raw_name} receipt changed")
        stages = final.get("stages")
        stage_raw = stages[0].get(stage_raw_name) if isinstance(stages, list) and len(stages) == 1 else None
        if not isinstance(stage_raw, dict) or {"bytes": stage_raw.get("bytes"),
                "sha256": stage_raw.get("sha256")} != actual or stage_raw.get("path") != str(path.resolve()):
            raise ValueError(f"V11 final {stage_raw_name} transcript receipt changed")

    static_root = checked_path(root, static.get("root"))
    static_entries = static.get("entries")
    if not isinstance(static_entries, list):
        raise ValueError("V11 static evidence inventory is not a list")
    verify_inventory(static_entries)
    if file_inventory(static_root) != static_entries:
        raise ValueError("V11 static evidence leaf differs from its complete inventory")
    static_receipt_path = checked_path(root, static.get("receipt_path"))
    if digest(static_receipt_path) != static.get("receipt_sha256"):
        raise ValueError("V11 static test receipt hash changed")
    static_receipt = json.loads(static_receipt_path.read_text(encoding="utf-8"))
    if (static_receipt.get("classification"), static_receipt.get("exit_code"),
            static_receipt.get("test_count"), static_receipt.get("julia_started"),
            static_receipt.get("output_leaf_absent")) != ("static_contract_pass_test_only", 0, 16, False, True):
        raise ValueError("V11 static test receipt or its historical scope changed")
    if static_receipt.get("protocol", {}).get("sha256") != parent_protocol["sha256"]:
        raise ValueError("V11 static test receipt does not bind its frozen protocol")
    if static_receipt.get("owned_source_files") != source_entries:
        raise ValueError("V11 static test receipt does not bind its immutable owned sources")

    diagnosis_root = checked_path(root, diagnosis_evidence.get("root"))
    diagnosis_entries = diagnosis_evidence.get("entries")
    if not isinstance(diagnosis_entries, list):
        raise ValueError("V11 diagnosis inventory is not a list")
    verify_inventory(diagnosis_entries)
    if file_inventory(diagnosis_root) != diagnosis_entries:
        raise ValueError("V11 diagnosis evidence leaf differs from its complete inventory")
    diagnosis_path = checked_path(root, diagnosis_evidence.get("diagnosis_path"))
    diagnosis = json.loads(diagnosis_path.read_text(encoding="utf-8"))
    if (diagnosis.get("schema"), diagnosis.get("classification"), diagnosis.get("controller_exit_code"),
            diagnosis.get("producer_exit_code"), diagnosis.get("failure_classification"),
            diagnosis.get("hydration_stage")) != (
            "mms-replay-only-v11-hydration-diagnosis-r1", "read_only_test_only_continuation_diagnosis", 72, 72,
            "replay_hydration_unsupported", "observe_typed_body_before_assertions"):
        raise ValueError("V11 observe-first diagnosis identity changed")
    obs = diagnosis.get("observation", {})
    if (obs.get("paired_leaf_count_total"), obs.get("exact_integral_float_to_int_count_total"),
            obs.get("all_reported_scalar_differences_are_exact_integral_float_to_int"),
            obs.get("first_exact_token_difference", {}).get("source_float_token"),
            obs.get("first_exact_token_difference", {}).get("typed_integer_token")) != (2415, 153, True, "0.0", "0"):
        raise ValueError("V11 exact-token diagnosis evidence changed")
    for key, path in (("final_sha256", final_path), ("producer_process_sha256", process_path),
                      ("producer_failure_sha256", failure_path), ("stdout_sha256", stdout_path),
                      ("stderr_sha256", stderr_path),
                      ("observation_sha256", checked_path(root, evidence["observation_path"])),
                      ("differences_sha256", checked_path(root, evidence["differences_path"])),
                      ("saved_numerical_result_sha256", checked_path(root, evidence["saved_result_path"]))):
        if diagnosis.get("evidence_hashes", {}).get(key) != digest(path):
            raise ValueError(f"V11 diagnosis does not bind actual receipt ({key})")

    all_entries: dict[str, dict[str, object]] = {}
    all_entries[parent_protocol["path"]] = {"path": parent_protocol["path"],
        "bytes": protocol_path.stat().st_size, "sha256": parent_protocol["sha256"]}
    for item in source_entries + runtime_entries + static_entries + diagnosis_entries:
        all_entries[item["path"]] = dict(item)
    return {"protocol_path": protocol_path, "protocol": v11, "final": final, "process": process,
            "failure": failure, "runtime_root": runtime_root, "runtime_entries": runtime_entries,
            "source_entries": source_entries, "static_entries": static_entries,
            "static_receipt_path": static_receipt_path, "diagnosis_entries": diagnosis_entries,
            "diagnosis_path": diagnosis_path, "input_entries": [all_entries[k] for k in sorted(all_entries)]}


def verify_v12_static_no_go(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind immutable V12 sources, its passing-but-insufficient static receipt, and independent NO-GO probe."""
    if not isinstance(evidence, dict):
        raise ValueError("V12 independent NO-GO evidence is missing")
    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V12 protocol ancestry is missing")
    protocol_path = verify_bound_sha256(root, protocol_ref.get("path"), protocol_ref.get("sha256"),
                                        "V12 frozen protocol")
    v12 = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (v12.get("schema"), v12.get("version"), v12.get("classification"), v12.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v12", 12, "test_only_continuation", False):
        raise ValueError("V12 protocol identity or no-credit boundary changed")
    if v12.get("state") != "frozen_static_unreviewed_no_julia":
        raise ValueError("V12 frozen static candidate state changed")

    source_entries = v12.get("owned_source_files")
    if not isinstance(source_entries, list) or len(source_entries) != 4:
        raise ValueError("V12 owned source inventory is incomplete")
    verify_inventory(source_entries)
    if v12.get("owned_source_files_by_path") != {item["path"]: item["sha256"] for item in source_entries}:
        raise ValueError("V12 source inventory and path map differ")

    static_contract = v12.get("static_contract_run")
    if not isinstance(static_contract, dict):
        raise ValueError("V12 static contract receipt reference is missing")
    static_evidence = evidence.get("static_evidence")
    if not isinstance(static_evidence, dict) or static_evidence.get("root") != static_contract.get("evidence_leaf"):
        raise ValueError("V12 static evidence reference changed")
    static_root = checked_path(root, static_evidence.get("root"))
    static_entries = static_evidence.get("entries")
    if not isinstance(static_entries, list) or len(static_entries) != 8:
        raise ValueError("V12 static evidence leaf inventory changed")
    verify_inventory(static_entries)
    if file_inventory(static_root) != static_entries:
        raise ValueError("V12 static evidence leaf inventory drift")
    receipt_path = static_root / "receipt.json"
    if (receipt_path.relative_to(root).as_posix(), digest(receipt_path)) != (
            static_evidence.get("receipt_path"), static_evidence.get("receipt_sha256")):
        raise ValueError("V12 static receipt does not match its frozen evidence reference")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("schema"), receipt.get("classification"), receipt.get("julia_started"),
            receipt.get("solver_started"), receipt.get("pre_output_contract_verified"),
            receipt.get("output_leaf_absent"), receipt.get("command", {}).get("exit_code"),
            receipt.get("command", {}).get("test_count")) != (
            "mms-replay-only-v12-static-receipt-v1", "static_contract_pass_test_only", False,
            False, True, True, 0, 19):
        raise ValueError("V12 historical static receipt or scope changed")
    if receipt.get("protocol") != {"path": protocol_ref["path"], "bytes": protocol_path.stat().st_size,
                                    "sha256": protocol_ref["sha256"]} or \
            receipt.get("owned_source_files") != source_entries:
        raise ValueError("V12 static receipt does not bind its frozen protocol and source hashes")
    if receipt.get("output_leaf") != v12.get("output_leaf") or static_contract.get("output_leaf_must_remain_absent") is not True:
        raise ValueError("V12 static receipt output absence target changed")
    if checked_path(root, v12["output_leaf"]).exists():
        raise ValueError("V12 runtime output leaf unexpectedly exists")

    review = evidence.get("independent_review")
    if not isinstance(review, dict):
        raise ValueError("V12 independent review receipt is missing")
    review_root = checked_path(root, review.get("root"))
    review_entries = review.get("entries")
    if not isinstance(review_entries, list) or len(review_entries) != 17:
        raise ValueError("V12 independent review evidence inventory is incomplete")
    verify_inventory(review_entries)
    if file_inventory(review_root) != review_entries:
        raise ValueError("V12 independent review evidence inventory changed")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V12 independent review manifest")
    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V12 independent review report")
    commands_path = verify_bound_sha256(root, review.get("commands_path"), review.get("commands_sha256"),
                                        "V12 independent review command receipt")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if (manifest.get("schema"), manifest.get("reviewer_task"), manifest.get("classification"),
            manifest.get("protocol")) != (
            "independent-evidence-review-manifest-v1", "/root/mms_closure/oracle_review", "NO-GO",
            {"path": protocol_ref["path"], "bytes": protocol_path.stat().st_size,
             "sha256": protocol_ref["sha256"]}):
        raise ValueError("V12 independent review identity or protocol binding changed")
    scope_check = manifest.get("scope_check")
    if not isinstance(scope_check, dict) or scope_check.get("evidence_only") is not True or \
            scope_check.get("executable_count") != 0 or scope_check.get("executable_files") != []:
        raise ValueError("V12 independent review leaf scope changed")
    manifest_leaf_entries = [{"path": pathlib.PurePosixPath(item["path"]).name,
                              "bytes": item["bytes"], "sha256": item["sha256"]}
                             for item in review_entries if item["path"] !=
                             (review_root / "manifest.json").relative_to(root).as_posix()]
    if manifest.get("review_leaf_files") != manifest_leaf_entries or \
            manifest.get("review_leaf_file_count_excluding_manifest") != 16:
        raise ValueError("V12 independent review manifest does not bind its evidence leaf")
    report = report_path.read_text(encoding="utf-8")
    if "**NO-GO for a V12 replay runtime grant.**" not in report or \
            "Checker false-negative reproduction" not in report:
        raise ValueError("V12 independent NO-GO report classification changed")

    commands = json.loads(commands_path.read_text(encoding="utf-8"))
    if (commands.get("reviewer_task"), commands.get("runtime", {}).get("julia_started"),
            commands.get("runtime", {}).get("replay_started"), commands.get("runtime", {}).get("solver_started"),
            commands.get("runtime", {}).get("runtime_output_leaf_absent")) != (
            "/root/mms_closure/oracle_review", False, False, False, True):
        raise ValueError("V12 independent review runtime boundary changed")
    mutation_commands = [item for item in commands.get("commands", [])
                         if item.get("purpose") == "In-memory negative-control probe of the frozen text checker; exact Python stdin preserved"]
    if len(mutation_commands) != 1:
        raise ValueError("V12 independent mutation probe record is missing")
    mutation = mutation_commands[0]
    if mutation.get("exit_code") != 0 or mutation.get("observed") != [
            "removing the unequal-real semantic rejection: ACCEPTED_BY_CHECKER",
            "removing the object key-set mismatch rejection: ACCEPTED_BY_CHECKER",
            "removing the sequence shape mismatch rejection: ACCEPTED_BY_CHECKER"]:
        raise ValueError("V12 independent mutation probe outcome changed")

    evidence_entries = [*static_entries, *review_entries]
    all_entries: dict[str, dict[str, object]] = {
        protocol_ref["path"]: {"path": protocol_ref["path"], "bytes": protocol_path.stat().st_size,
                               "sha256": protocol_ref["sha256"]}}
    for item in source_entries + evidence_entries:
        all_entries[item["path"]] = dict(item)
    return {"protocol": v12, "protocol_path": protocol_path, "source_entries": source_entries,
            "static_entries": static_entries, "static_receipt": receipt,
            "review_entries": review_entries, "review_manifest": manifest,
            "review_report_path": report_path, "review_manifest_path": manifest_path,
            "review_commands_path": commands_path,
            "input_entries": [all_entries[key] for key in sorted(all_entries)]}


def verify_v13_static_candidate_and_no_go(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind V13 static candidate, both independent reviews, and root runtime NO-GO."""
    if not isinstance(evidence, dict):
        raise ValueError("V13 frozen candidate evidence is missing")
    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V13 frozen protocol reference is missing")
    protocol_path = verify_bound_sha256(root, protocol_ref.get("path"), protocol_ref.get("sha256"),
                                        "V13 frozen protocol")
    v13 = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (v13.get("schema"), v13.get("version"), v13.get("classification"), v13.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v13", 13, "test_only_continuation", False):
        raise ValueError("V13 protocol identity or no-credit boundary changed")
    source_entries = v13.get("owned_source_files")
    if not isinstance(source_entries, list) or len(source_entries) != 3:
        raise ValueError("V13 source inventory is incomplete")
    verify_inventory(source_entries)
    static = evidence.get("static_evidence")
    if not isinstance(static, dict) or static.get("root") != \
            "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r13/static_contract_check_v13_r1":
        raise ValueError("V13 static evidence leaf reference changed")
    static_root = checked_path(root, static.get("root"))
    static_entries = static.get("entries")
    if not isinstance(static_entries, list) or len(static_entries) != 9:
        raise ValueError("V13 static evidence inventory is incomplete")
    verify_inventory(static_entries)
    if file_inventory(static_root) != static_entries:
        raise ValueError("V13 static evidence leaf inventory drift")
    receipt_path = verify_bound_sha256(root, static.get("receipt_path"), static.get("receipt_sha256"),
                                       "V13 static receipt")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("schema"), receipt.get("classification"), receipt.get("protocol", {}).get("sha256"),
            receipt.get("command", {}).get("exit_code"), receipt.get("command", {}).get("tests_run"),
            receipt.get("command", {}).get("tests_passed"), receipt.get("runtime_boundary", {}).get("julia_started"),
            receipt.get("runtime_boundary", {}).get("producer_started"),
            receipt.get("runtime_boundary", {}).get("consumer_started"),
            receipt.get("runtime_boundary", {}).get("v13_output_leaf_absent")) != (
            "up2-v13-static-evidence-receipt-v1", "STATIC_TESTS_PASS_RUNTIME_NOT_GRANTED",
            protocol_ref.get("sha256"), 0, 21, 21, False, False, False, True):
        raise ValueError("V13 static receipt or no-runtime boundary changed")
    if checked_path(root, v13["output_leaf"]).exists():
        raise ValueError("V13 runtime output leaf unexpectedly exists")

    sums_path = static_root / "SHA256SUMS.txt"
    expected_sums: dict[str, str] = {}
    for line in sums_path.read_text(encoding="ascii").splitlines():
        sha, name = line.split("  ", 1)
        if name in expected_sums:
            raise ValueError("V13 static SHA256SUMS contains duplicate entries")
        expected_sums[name] = sha
    actual_names = {path.name for path in static_root.iterdir() if path.is_file() and path.name != "SHA256SUMS.txt"}
    if actual_names != set(expected_sums) or any(digest(static_root / name) != sha
                                                  for name, sha in expected_sums.items()):
        raise ValueError("V13 static SHA256SUMS does not cover the complete evidence leaf")

    decision = evidence.get("root_no_go_decision")
    if not isinstance(decision, dict):
        raise ValueError("V13 root runtime NO-GO decision is missing")
    decision_path = verify_bound_sha256(root, decision.get("path"), decision.get("sha256"),
                                        "V13 root runtime NO-GO decision")
    if decision_path.stat().st_size != decision.get("bytes"):
        raise ValueError("V13 root decision byte count changed")
    decision_text = decision_path.read_text(encoding="utf-8")
    if "Decision: **NO-GO for the two-process Julia replay**" not in decision_text or \
            protocol_ref.get("sha256") not in decision_text or "fail-open monitor paths" not in decision_text:
        raise ValueError("V13 root NO-GO decision no longer records the frozen monitor defects")

    review_refs = evidence.get("independent_reviews")
    if not isinstance(review_refs, list) or len(review_refs) != 2:
        raise ValueError("V13 independent review ancestry is incomplete")
    review_inputs: list[dict[str, object]] = []
    review_reports: list[dict[str, object]] = []
    for review in review_refs:
        if not isinstance(review, dict):
            raise ValueError("V13 independent review reference is malformed")
        review_root_rel = review.get("root")
        if not isinstance(review_root_rel, str) or not review_root_rel:
            raise ValueError("V13 independent review leaf path is invalid")
        review_root = checked_path(root, review_root_rel)
        manifest_path = verify_bound_sha256(root, review.get("manifest_path"),
                                            review.get("manifest_sha256"),
                                            "V13 independent review manifest")
        report_path = verify_bound_sha256(root, review.get("report_path"),
                                          review.get("report_sha256"),
                                          "V13 independent review report")
        if manifest_path.parent != review_root or report_path.parent != review_root:
            raise ValueError("V13 independent review manifest/report escaped its leaf")
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if review.get("kind") == "review":
            if (manifest.get("schema"), manifest.get("reviewer_task")) != (
                    "evidence-only-independent-review-manifest-v1", "/root/mms_closure/oracle_review"):
                raise ValueError("V13 independent reviewer identity/schema changed")
            listed = manifest.get("review_leaf_files")
            if not isinstance(listed, list) or len(listed) != 14 or \
                    "NO-GO runtime" not in str(manifest.get("verdict", "")):
                raise ValueError("V13 independent reviewer verdict or inventory changed")
        elif review.get("kind") == "tester":
            if (manifest.get("schema"), manifest.get("classification"),
                    manifest.get("evidence_only"), manifest.get("contains_executable"),
                    manifest.get("artifact_count")) != (
                    "independent-evidence-only-review-leaf-manifest-v1",
                    "STATIC_HYDRATION_AND_PRECONDITIONS_GO_RUNTIME_NO_GO", True, False, 24):
                raise ValueError("V13 independent tester identity/verdict changed")
            listed = manifest.get("artifacts")
            if not isinstance(listed, list) or len(listed) != 24:
                raise ValueError("V13 independent tester artifact inventory changed")
        else:
            raise ValueError("V13 independent review kind is unsupported")
        if report_path.name != "review.md":
            raise ValueError("V13 independent review report filename changed")
        expected_files = []
        for item in listed:
            if not isinstance(item, dict) or not isinstance(item.get("path"), str):
                raise ValueError("V13 independent review file inventory is malformed")
            local = pathlib.PurePosixPath(item["path"])
            if local.is_absolute() or ".." in local.parts:
                raise ValueError("V13 independent review inventory path escapes its leaf")
            rel_path = (pathlib.PurePosixPath(review_root_rel) / local).as_posix()
            expected_files.append({"path": rel_path, "bytes": item.get("bytes"),
                                   "sha256": item.get("sha256")})
            if local.suffix.lower() in {".py", ".ps1", ".bat", ".cmd", ".exe", ".dll"}:
                raise ValueError("V13 independent review archive contains executable/source material")
        actual_files = [item for item in file_inventory(review_root)
                        if item["path"] != manifest_path.relative_to(root).as_posix()]
        if len(expected_files) != len(actual_files) or \
                {item["path"]: item for item in expected_files} != \
                {item["path"]: item for item in actual_files}:
            raise ValueError("V13 independent review artifact inventory drift")
        review_inputs.extend(actual_files)
        review_inputs.append({"path": manifest_path.relative_to(root).as_posix(),
                              "bytes": manifest_path.stat().st_size,
                              "sha256": review["manifest_sha256"]})
        review_reports.append({"path": report_path, "sha256": review["report_sha256"],
                               "manifest": manifest})

    all_entries: dict[str, dict[str, object]] = {
        protocol_ref["path"]: {"path": protocol_ref["path"], "bytes": protocol_path.stat().st_size,
                               "sha256": protocol_ref["sha256"]},
        decision["path"]: {"path": decision["path"], "bytes": decision["bytes"], "sha256": decision["sha256"]},
    }
    for entry in source_entries + static_entries:
        all_entries[entry["path"]] = dict(entry)
    for entry in review_inputs:
        all_entries[entry["path"]] = dict(entry)
    return {"protocol": v13, "protocol_path": protocol_path, "source_entries": source_entries,
            "static_entries": static_entries, "static_receipt": receipt,
            "decision_path": decision_path, "independent_reviews": review_reports,
            "input_entries": [all_entries[k] for k in sorted(all_entries)]}


def verify_v14_actual_failure_ancestry(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the V14 static GO, root grant, and immutable two-cause runtime failure."""
    if not isinstance(evidence, dict):
        raise ValueError("V14 actual failure ancestry is missing")

    def exact_leaf(root_rel: object, entries: object, label: str) -> tuple[pathlib.Path, list[dict[str, object]]]:
        if not isinstance(root_rel, str) or not root_rel or not isinstance(entries, list):
            raise ValueError(f"V14 {label} inventory is malformed")
        leaf = checked_path(root, root_rel)
        verify_inventory(entries)
        if file_inventory(leaf) != entries:
            raise ValueError(f"V14 {label} inventory drift")
        return leaf, entries

    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V14 protocol reference is missing")
    v14_protocol_path = verify_bound_sha256(root, protocol_ref.get("path"),
                                            protocol_ref.get("sha256"), "V14 protocol")
    if v14_protocol_path.stat().st_size != protocol_ref.get("bytes"):
        raise ValueError("V14 protocol byte count changed")
    v14_protocol = json.loads(v14_protocol_path.read_text(encoding="utf-8"))
    if (v14_protocol.get("schema"), v14_protocol.get("version"),
            v14_protocol.get("classification"), v14_protocol.get("runtime_grant"),
            v14_protocol.get("v10_protocol", {}).get("pinned_input_count"),
            v14_protocol.get("saved_producer_tree", {}).get("file_count")) != (
            "mms-replay-only-continuation-protocol-v14", 14, "test_only_continuation", False, 89, 119):
        raise ValueError("V14 frozen identity, no-credit, or 89/119 lineage changed")
    sources = evidence.get("source_files")
    if not isinstance(sources, list) or len(sources) != 3 or sources != v14_protocol.get("owned_source_files"):
        raise ValueError("V14 source ancestry does not match its frozen protocol")
    verify_inventory(sources)

    static = evidence.get("static_evidence")
    if not isinstance(static, dict):
        raise ValueError("V14 static evidence reference is missing")
    static_root, static_entries = exact_leaf(static.get("root"), static.get("entries"), "static evidence")
    static_receipt_path = verify_bound_sha256(root, static.get("receipt_path"),
                                              static.get("receipt_sha256"), "V14 static receipt")
    if static_receipt_path.parent != static_root:
        raise ValueError("V14 static receipt escaped its evidence leaf")
    static_receipt = json.loads(static_receipt_path.read_text(encoding="utf-8"))
    if (static_receipt.get("schema"), static_receipt.get("classification"),
            static_receipt.get("protocol", {}).get("sha256"),
            static_receipt.get("command", {}).get("exit_code"),
            static_receipt.get("command", {}).get("tests_run"),
            static_receipt.get("command", {}).get("tests_passed"),
            static_receipt.get("runtime_boundary", {}).get("julia_started"),
            static_receipt.get("runtime_boundary", {}).get("output_leaf_absent")) != (
            "up2-v14-static-evidence-receipt-v1", "STATIC_TESTS_PASS_RUNTIME_NOT_GRANTED",
            protocol_ref.get("sha256"), 0, 30, 30, False, True):
        raise ValueError("V14 static receipt is not the frozen 30/30 no-runtime result")

    review = evidence.get("independent_review")
    if not isinstance(review, dict):
        raise ValueError("V14 independent static review reference is missing")
    review_root, review_entries = exact_leaf(review.get("root"), review.get("entries"), "independent review")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"),
                                        review.get("manifest_sha256"), "V14 independent review manifest")
    report_path = verify_bound_sha256(root, review.get("report_path"),
                                      review.get("report_sha256"), "V14 independent review report")
    commands_path = verify_bound_sha256(root, review.get("commands_path"),
                                        review.get("commands_sha256"), "V14 independent review commands")
    if any(path.parent != review_root for path in (manifest_path, report_path, commands_path)):
        raise ValueError("V14 independent review artifacts escaped their evidence leaf")
    review_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if (review_manifest.get("schema"), review_manifest.get("classification"),
            review_manifest.get("reviewer_task"), review_manifest.get("evidence_only"),
            review_manifest.get("contains_executable"), review_manifest.get("julia_started"),
            review_manifest.get("replay_started")) != (
            "evidence-only-independent-review-manifest-v1", "BOUNDED_STATIC_GO_RUNTIME_NOT_GRANTED",
            "/root/mms_closure/oracle_review", True, False, False, False):
        raise ValueError("V14 independent review verdict or no-runtime boundary changed")
    listed_review_files = review_manifest.get("review_leaf_files")
    if not isinstance(listed_review_files, list) or len(listed_review_files) != 14:
        raise ValueError("V14 independent review file inventory changed")
    manifest_frozen = review_manifest.get("frozen_inputs")
    if not isinstance(manifest_frozen, dict) or any(
            manifest_frozen.get(key, {}).get("sha256") != expected for key, expected in (
                ("protocol", protocol_ref["sha256"]),
                ("runner", sources[1]["sha256"]),
                ("julia_entrypoint_read_only_not_run", sources[0]["sha256"]),
                ("focused_test", sources[2]["sha256"]))):
        raise ValueError("V14 independent reviewer did not audit the exact frozen source set")
    if any(pathlib.PurePosixPath(item["path"]).suffix.lower() in
           {".py", ".ps1", ".bat", ".cmd", ".exe", ".dll"} for item in listed_review_files):
        raise ValueError("V14 reviewer leaf contains executable/source material")

    grant = evidence.get("root_grant")
    if not isinstance(grant, dict):
        raise ValueError("V14 root runtime grant evidence is missing")
    grant_root, grant_entries = exact_leaf(grant.get("root"), grant.get("entries"), "root grant")
    grant_start_path = verify_bound_sha256(root, grant.get("root") + "/start.json",
                                           next((item.get("sha256") for item in grant_entries
                                                 if item.get("path") == grant.get("root") + "/start.json"), None),
                                           "V14 root grant start")
    grant_start = json.loads(grant_start_path.read_text(encoding="utf-8"))
    grant_invocation_path = grant_root / "invocation.json"
    invocation = json.loads(grant_invocation_path.read_text(encoding="utf-8"))
    invocation_sha = digest(grant_invocation_path)
    if (grant_start.get("schema"), grant_start.get("protocol_sha256"),
            grant_start.get("runner_sha256"), grant_start.get("replay_sha256"),
            grant_start.get("output_leaf_preexisting"),
            invocation.get("controller_exit_code"), invocation.get("output_leaf_present"),
            invocation.get("numerical_credit_by_root")) != (
            "root-closure-v14-start-v1", protocol_ref.get("sha256"), sources[1]["sha256"],
            sources[0]["sha256"], False, 124, True, False):
        raise ValueError("V14 root grant or invocation identity/credit changed")
    if invocation.get("exit_sha256") != next((item.get("sha256") for item in grant_entries
                                               if item.get("path") == grant.get("root") + "/invocation.exit.txt"), None):
        raise ValueError("V14 root grant exit receipt changed")
    stdout_path = grant_root / "invocation.stdout.raw"
    if digest(stdout_path) != invocation.get("stdout_sha256"):
        raise ValueError("V14 root grant stdout receipt changed")
    try:
        stdout_summary = json.loads(stdout_path.read_text(encoding="utf-8").strip())
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("V14 root grant controller summary is invalid") from exc

    runtime = evidence.get("runtime_failure")
    if not isinstance(runtime, dict):
        raise ValueError("V14 runtime failure leaf reference is missing")
    runtime_root, runtime_entries = exact_leaf(runtime.get("root"), runtime.get("entries"), "runtime failure")
    final_path = verify_bound_sha256(root, runtime.get("final_path"), runtime.get("final_sha256"),
                                     "V14 controller final")
    process_path = verify_bound_sha256(root, runtime.get("process_path"), runtime.get("process_sha256"),
                                       "V14 producer process receipt")
    failure_path = verify_bound_sha256(root, runtime.get("failure_path"), runtime.get("failure_sha256"),
                                       "V14 producer hydration failure")
    final = json.loads(final_path.read_text(encoding="utf-8"))
    process = json.loads(process_path.read_text(encoding="utf-8"))
    failure = json.loads(failure_path.read_text(encoding="utf-8"))
    stage = final.get("stages", [None])[0]
    expected_error = ("unsupported rebuilt V4 declaration schema node at declaration.source.input: "
                      "Main.ManufacturedCandidateV1Tests.DefinitionRuntime.SpatialManufacturedNumericalInputV1")
    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"), final.get("solver_exit_code"),
            final.get("authority"), final.get("inputs_unchanged"),
            final.get("producer_tree_comparison_status"),
            stdout_summary.get("final_sha256")) != (
            "mms-replay-only-controller-final-v3", "resource_interruption", 124, False,
            "fail", 2, "no_publish", True, "not_reached", runtime.get("final_sha256")):
        raise ValueError("V14 final receipt changed the preserved resource/numerical failure state")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "schema_directed_reconstruction",
            expected_error, 2, "fail", "no_publish"):
        raise ValueError("V14 actual hydration failure signature changed")
    if (process.get("schema"), process.get("exit_code"), process.get("stop_reason"),
            process.get("rss_complete_sample_count"), process.get("rss_sampling_complete"),
            process.get("peak_sampled_process_tree_working_set_bytes"),
            process.get("root_process_identity")) != (
            "mms-replay-recorded-process-v2", 72, "aggregate_cleanup_overrun", 920, False,
            1153818624, {"pid": 50388, "create_time": 1790253602.8210025}):
        raise ValueError("V14 producer resource-race receipt changed")
    cleanup = process.get("cleanup")
    errors = cleanup.get("termination_verification_errors") if isinstance(cleanup, dict) else None
    if cleanup.get("termination_confirmed") is not False or not isinstance(errors, list) or not any(
            item.get("stage") == "root_process_lookup" and item.get("error_type") == "NoSuchProcess"
            for item in errors if isinstance(item, dict)):
        raise ValueError("V14 leader-exit/NoSuchProcess cleanup race is not bound")
    if (not isinstance(stage, dict) or stage.get("stage") != "producer" or
            stage.get("exit_code") != 72 or stage.get("stop_reason") != "aggregate_cleanup_overrun" or
            stage.get("peak_sampled_process_tree_working_set_bytes") >= 2147483648 or
            stage.get("child_wall_seconds") >= 480):
        raise ValueError("V14 producer resource limits or exit status changed")
    if (runtime_root / "consumer_process").exists() or \
            (runtime_root / "consumer_process.json").exists() or \
            (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V14 failure unexpectedly produced consumer or producer completion")

    all_entries: dict[str, dict[str, object]] = {protocol_ref["path"]: dict(protocol_ref)}
    for group in (sources, static_entries, review_entries, grant_entries, runtime_entries):
        for item in group:
            all_entries[item["path"]] = dict(item)
    return {"protocol": v14_protocol, "protocol_path": v14_protocol_path,
            "static_receipt": static_receipt, "review_manifest": review_manifest,
            "grant_start": grant_start, "invocation": invocation,
            "final": final, "process": process, "failure": failure,
            "input_entries": [all_entries[key] for key in sorted(all_entries)]}


def validate_process_tree_monitor_contract(protocol: dict[str, object]) -> dict[str, object]:
    monitor = protocol.get("process_tree_monitor_contract")
    expected = {
        "schema": "mms-process-tree-resource-monitor-contract-v1",
        "sample_policy": "Every enumerated process must yield an identity and RSS; any exception marks the sample incomplete, records the failure, and stops the stage.",
        "partial_rss_policy": "Partial RSS is retained only as diagnostic metadata and never contributes to peak RSS or the 2 GiB comparison.",
        "termination_policy": "A wait_procs exception retains the last candidate set as potentially alive; termination is confirmed only after a complete inventory and a successful bounded wait reports no live targets.",
        "consumer_policy": "Any incomplete tree sample is a resource_interruption with exit 124 and blocks the next stage; unconfirmed cleanup also blocks the next stage.",
        "cleanup_outcome_policy": "Unconfirmed cleanup without positive measured overrun is cleanup_unconfirmed/124; aggregate_cleanup_overrun is reserved for positive child-total or cleanup-grace overrun. Both block the consumer.",
        "root_identity_policy": "Every complete RSS sample contains exactly one (pid, create_time) identity equal to the root pinned from Popen; PID reuse, missing/duplicate root identity, or descendant state unknown after leader exit fails closed.",
        "leader_exit_policy": "After Popen confirms leader exit, do not take another root RSS sample; recheck every previously observed descendant by exact identity and require a complete PPID descendant snapshot. Active descendants interrupt; an unobserved descendant, root PID still present/reused, or incomplete/unknown audit fails closed.",
        "cleanup_identity_policy": "Never signal a PID-only or recycled process; cleanup targets must be pinned identities from this stage, and residual lookup/kill/wait uncertainty prevents termination confirmation.",
        "pid_zero_policy": "Ignore only the exact process-table sentinel (pid=0, ppid=0), which is never an owned identity or descendant; PID 0 with any other PPID, negative IDs, malformed IDs, and unknown snapshots fail closed.",
    }
    if monitor != expected:
        raise ValueError("process-tree monitor contract is missing or fail-open")
    negatives = protocol.get("coverage_contract", {}).get("process_tree_resource_monitor_negative_controls")
    expected_negatives = [
        "inject descendant enumeration AccessDenied and require an incomplete sample with no RSS total returned",
        "inject descendant memory_info AccessDenied after a root sample and require the partial bytes be diagnostic only",
        "inject incomplete monitor status in run_stage and require resource_interruption/124 with consumer blocked",
        "inject wait_procs exceptions during terminate and kill waits and require candidates retained and termination_confirmed false",
        "inject missing or duplicate root identities and require the complete RSS sample be rejected",
        "inject root/descendant PID reuse and require fail-closed without signaling the recycled process",
        "make the leader exit with a live descendant and require interruption/124 with consumer blocked",
        "inject descendant lookup AccessDenied and terminate/kill errors; unknown residuals must remain unconfirmed",
        "confirm Popen exit after a complete root sample and require no post-exit RSS lookup plus a complete identity and PPID descendant audit",
        "make Popen exit before any complete root sample and require process-tree observation failure/124",
        "inject an unobserved child in the final PPID snapshot and require interruption/124, identity pinning, and no consumer launch",
        "inject PPID snapshot failure or a root PID still present/reused after confirmed exit and require fail-closed status",
        "inject unconfirmed bounded cleanup with zero measured overrun and require cleanup_unconfirmed/124 rather than aggregate_cleanup_overrun",
        "accept and ignore only the exact Windows PID 0/PPID 0 sentinel; reject PID 0 with nonzero PPID and all other invalid process-table identities",
    ]
    if negatives != expected_negatives:
        raise ValueError("process-tree monitor negative-control coverage changed")
    return monitor


def verify_v16_actual_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the immutable V16 representation-only failure leaf as V18 ancestry."""
    if not isinstance(evidence, dict):
        raise ValueError("V16 actual failure reference is missing")
    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V16 protocol reference is malformed")
    protocol_path = verify_bound_sha256(root, protocol_ref.get("path"), protocol_ref.get("sha256"),
                                        "V16 replay protocol")
    if protocol_path.stat().st_size != protocol_ref.get("bytes"):
        raise ValueError("V16 replay protocol byte count changed")
    parent = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (parent.get("schema"), parent.get("version"), parent.get("classification"), parent.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v16", 16, "test_only_continuation", False):
        raise ValueError("V16 frozen protocol classification or runtime grant changed")
    if parent.get("output_leaf") != evidence.get("runtime_root"):
        raise ValueError("V16 failure root differs from its frozen output_leaf")
    sources = evidence.get("source_files")
    if not isinstance(sources, list) or len(sources) != 3:
        raise ValueError("V16 source inventory is malformed")
    verify_inventory(sources)
    parent_hashes = parent.get("owned_source_files_by_path", {})
    if not isinstance(parent_hashes, dict) or any(parent_hashes.get(item.get("path")) != item.get("sha256") for item in sources):
        raise ValueError("V16 source inventory differs from the immutable V16 protocol")
    runtime_root = checked_path(root, evidence.get("runtime_root"))
    entries = evidence.get("runtime_entries")
    if not isinstance(entries, list) or len(entries) != 19:
        raise ValueError("V16 complete runtime failure inventory is missing")
    verify_inventory(entries)
    if file_inventory(runtime_root) != entries:
        raise ValueError("V16 runtime failure inventory changed")
    def read_ref(name: str) -> tuple[pathlib.Path, dict[str, object]]:
        ref = evidence.get(name)
        if not isinstance(ref, dict):
            raise ValueError(f"V16 {name} receipt reference is malformed")
        path = verify_bound_sha256(root, ref.get("path"), ref.get("sha256"), f"V16 {name}")
        if path.stat().st_size != ref.get("bytes") or not any(x.get("path") == ref.get("path") for x in entries):
            raise ValueError(f"V16 {name} receipt is outside its pinned runtime inventory")
        return path, json.loads(path.read_text(encoding="utf-8"))
    expected = {
        "final": runtime_root.relative_to(root).as_posix() + "/final.json",
        "process": runtime_root.relative_to(root).as_posix() + "/producer_process.json",
        "failure": runtime_root.relative_to(root).as_posix() + "/producer_process/numerical/producer_failure.json",
    }
    for name, path in expected.items():
        if not isinstance(evidence.get(name), dict) or evidence[name].get("path") != path:
            raise ValueError(f"V16 {name} path differs from the exact frozen runtime location")
    _, final = read_ref("final")
    _, process = read_ref("process")
    _, failure = read_ref("failure")
    if (final.get("classification"), final.get("controller_exit_code"), final.get("software_complete"),
            final.get("numerical_status"), final.get("solver_exit_code"), final.get("authority"),
            final.get("physical_validation"), final.get("inputs_unchanged"),
            final.get("producer_tree_comparison_status"), final.get("producer_tree_unchanged")) != (
            "replay_hydration_unsupported", 72, False, "fail", 2, "no_publish", "unsupported", True,
            "not_reached", None):
        raise ValueError("V16 replay/program failure and original solver failure semantics changed")
    if (process.get("schema"), process.get("exit_code"), process.get("stop_reason"),
            process.get("rss_complete_sample_count"), process.get("rss_sampling_complete"),
            process.get("peak_sampled_process_tree_working_set_bytes")) != (
            "mms-replay-recorded-process-v2", 72, "exited", 863, True, 1259450368):
        raise ValueError("V16 producer runtime receipt changed")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "schema_directed_reconstruction",
            "schema-directed reconstruction did not eliminate every observed representation difference",
            2, "fail", "no_publish"):
        raise ValueError("V16 exact after-reconstruction failure signature changed")
    if (runtime_root / "producer_process/consumer").exists() or (runtime_root / "consumer_process").exists():
        raise ValueError("V16 failure unexpectedly contains a consumer")
    if (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V16 failure unexpectedly contains producer completion")
    if (runtime_root / "producer_process/numerical/hydration_observation_reconstruction.json").exists():
        raise ValueError("V16 historical failure unexpectedly contains an after-observation receipt")
    return {"protocol": parent, "runtime_root": runtime_root, "final": final,
            "process": process, "failure": failure, "runtime_entries": entries}


def verify_v15_actual_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the immutable V15 run and its complete failure leaf as V18 ancestry."""
    if not isinstance(evidence, dict):
        raise ValueError("V15 actual failure reference is missing")
    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V15 protocol reference is malformed")
    protocol_path = verify_bound_sha256(root, protocol_ref.get("path"), protocol_ref.get("sha256"),
                                        "V15 replay protocol")
    if protocol_path.stat().st_size != protocol_ref.get("bytes"):
        raise ValueError("V15 replay protocol byte count changed")
    v15_protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (v15_protocol.get("schema"), v15_protocol.get("version"), v15_protocol.get("classification"),
            v15_protocol.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v15", 15, "test_only_continuation", False):
        raise ValueError("V15 frozen protocol classification or grant changed")
    if v15_protocol.get("output_leaf") != evidence.get("runtime_root"):
        raise ValueError("V15 failure root no longer matches its protocol output_leaf")

    sources = evidence.get("source_files")
    if not isinstance(sources, list) or len(sources) != 3:
        raise ValueError("V15 source inventory is malformed")
    verify_inventory(sources)
    for item in sources:
        declared_sources = v15_protocol.get("owned_source_files_by_path", {})
        if not isinstance(declared_sources, dict) or declared_sources.get(item.get("path")) != item.get("sha256"):
            raise ValueError("V15 source inventory contains a path outside its frozen protocol")

    runtime_root = checked_path(root, evidence.get("runtime_root"))
    runtime_entries = evidence.get("runtime_entries")
    if not isinstance(runtime_entries, list) or not runtime_entries:
        raise ValueError("V15 runtime evidence inventory is missing")
    verify_inventory(runtime_entries)
    if file_inventory(runtime_root) != runtime_entries:
        raise ValueError("V15 runtime failure leaf inventory is incomplete or contains drift")
    def read_entry(key: str, label: str) -> tuple[pathlib.Path, dict[str, object]]:
        ref = evidence.get(key)
        if not isinstance(ref, dict):
            raise ValueError(f"V15 {label} reference is malformed")
        path = verify_bound_sha256(root, ref.get("path"), ref.get("sha256"), f"V15 {label}")
        if path.stat().st_size != ref.get("bytes"):
            raise ValueError(f"V15 {label} byte count changed")
        if not any(item.get("path") == ref.get("path") for item in runtime_entries):
            raise ValueError(f"V15 {label} is outside the runtime failure leaf")
        return path, json.loads(path.read_text(encoding="utf-8"))

    expected_paths = {
        "final": runtime_root.relative_to(root).as_posix() + "/final.json",
        "process": runtime_root.relative_to(root).as_posix() + "/producer_process.json",
        "failure": runtime_root.relative_to(root).as_posix() + "/producer_process/numerical/producer_failure.json",
    }
    for key, expected_path in expected_paths.items():
        if not isinstance(evidence.get(key), dict) or evidence[key].get("path") != expected_path:
            raise ValueError(f"V15 {key} path differs from its exact frozen runtime location")
    _, final = read_entry("final", "controller final")
    _, process = read_entry("process", "producer process receipt")
    _, failure = read_entry("failure", "producer failure")
    expected_error = "unsupported SpatialMultiRegionCaseV4 field at cases[1].case_id"
    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"), final.get("solver_exit_code"),
            final.get("authority"), final.get("physical_validation"), final.get("nonlinear_solves"),
            final.get("inputs_unchanged"), final.get("producer_tree_comparison_status")) != (
            "mms-replay-only-controller-final-v3", "resource_interruption", 124, False,
            "fail", 2, "no_publish", "unsupported", 0, True, "not_reached"):
        raise ValueError("V15 controller failure changed its resource/numerical semantics")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "schema_directed_reconstruction",
            expected_error, 2, "fail", "no_publish"):
        raise ValueError("V15 actual hydration failure signature changed")
    if (process.get("schema"), process.get("exit_code"), process.get("stop_reason"),
            process.get("rss_complete_sample_count"), process.get("rss_sampling_complete"),
            process.get("peak_sampled_process_tree_working_set_bytes")) != (
            "mms-replay-recorded-process-v2", 72, "cleanup_unconfirmed", 860, False, 1071091712):
        raise ValueError("V15 producer failure/resource receipt changed")
    leader_check = process.get("leader_exit_descendant_check")
    if not isinstance(leader_check, dict) or leader_check.get("process_table_snapshot_complete") is not False or not any(
            item.get("stage") == "process_table_identity_validation" and
            item.get("error") == "process-table PID or PPID is outside its valid range"
            for item in leader_check.get("unknown_descendants", []) if isinstance(item, dict)):
        raise ValueError("V15 PID/PPID process-table failure is not bound")
    if process.get("root_process_identity") != {"pid": 72744, "create_time": 1790326389.0025537}:
        raise ValueError("V15 root process identity changed")
    if "hydration_case_from_body" not in failure.get("backtrace", ""):
        raise ValueError("V15 failure stack is no longer tied to the frozen V15 entrypoint")
    stdout_ref = process.get("stdout")
    stderr_ref = process.get("stderr")
    if not isinstance(stdout_ref, dict) or not isinstance(stderr_ref, dict):
        raise ValueError("V15 raw process streams are not recorded")
    for label, ref in (("stdout", stdout_ref), ("stderr", stderr_ref)):
        raw_path = checked_path(root, ref.get("path"))
        if not raw_path.is_file() or raw_path.stat().st_size != ref.get("bytes") or digest(raw_path) != ref.get("sha256"):
            raise ValueError(f"V15 producer {label} bytes changed")
        if not any(item.get("path") == raw_path.relative_to(root).as_posix() for item in runtime_entries):
            raise ValueError(f"V15 producer {label} is outside its runtime inventory")
    if not isinstance(evidence.get("independent_review"), dict):
        raise ValueError("V15 independent review reference is missing")
    review_ref = evidence["independent_review"]
    review_path = verify_bound_sha256(root, review_ref.get("path"), review_ref.get("sha256"),
                                      "V15 independent review result")
    for key, label in (("report", "V15 independent review report"),
                       ("manifest", "V15 independent review manifest")):
        item = review_ref.get(key)
        if not isinstance(item, dict):
            raise ValueError(f"{label} reference is malformed")
        verify_bound_sha256(root, item.get("path"), item.get("sha256"), label)
    review = json.loads(review_path.read_text(encoding="utf-8"))
    if (review.get("decision"), review.get("runtime_grant"), review.get("julia_started")) != ("GO", False, False):
        raise ValueError("V15 independent review no longer records static-only GO")
    if review.get("primary_pins", [{}])[0].get("sha256") != protocol_ref.get("sha256"):
        raise ValueError("V15 independent review no longer pins the parent protocol")
    for relative in ("producer_process/consumer", "consumer_process", "consumer_process.json"):
        if (runtime_root / relative).exists():
            raise ValueError("V15 failure unexpectedly contains a consumer process")
    if (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V15 failure unexpectedly contains producer completion")
    inputs_before = runtime_root / "inputs_before.json"
    inputs_after = runtime_root / "inputs_after.json"
    if not inputs_before.is_file() or not inputs_after.is_file() or inputs_before.read_bytes() != inputs_after.read_bytes():
        raise ValueError("V15 input snapshots are missing or differ")
    return {"protocol": v15_protocol, "protocol_path": protocol_path, "final": final,
            "process": process, "failure": failure, "review": review, "runtime_root": runtime_root,
            "runtime_entries": runtime_entries}


def verify_v14_postrun_audit(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the immutable V14 postrun audit and its complete evidence-only leaf."""
    if not isinstance(evidence, dict):
        raise ValueError("V14 postrun audit reference is missing")
    leaf_rel = evidence.get("root")
    entries = evidence.get("entries")
    if not isinstance(leaf_rel, str) or not leaf_rel or not isinstance(entries, list):
        raise ValueError("V14 postrun audit leaf inventory is malformed")
    leaf = checked_path(root, leaf_rel)
    verify_inventory(entries)
    if file_inventory(leaf) != entries:
        raise ValueError("V14 postrun audit leaf inventory drift")

    def artifact_path(field: str, hash_field: str, label: str) -> pathlib.Path:
        path = verify_bound_sha256(root, evidence.get(field), evidence.get(hash_field), label)
        if path.parent != leaf:
            raise ValueError(f"{label} escaped the V14 postrun audit leaf")
        return path

    report_path = artifact_path("report_path", "report_sha256", "V14 postrun report")
    manifest_path = artifact_path("manifest_path", "manifest_sha256", "V14 postrun manifest")
    commands_path = artifact_path("commands_path", "commands_sha256", "V14 postrun commands")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    commands = json.loads(commands_path.read_text(encoding="utf-8"))
    if (manifest.get("schema"), manifest.get("evidence_only"),
            manifest.get("contains_executable_payload"), manifest.get("source_leaf_modified")) != (
            "independent-v14-postrun-audit-manifest-v1", True, False, False):
        raise ValueError("V14 postrun audit manifest is not the frozen evidence-only leaf")
    manifest_entries = manifest.get("entries")
    expected_manifest_entries = [
        {"path": pathlib.PurePosixPath(item["path"]).name,
         "bytes": item["bytes"], "sha256": item["sha256"]}
        for item in entries if pathlib.PurePosixPath(item["path"]).name in {
            "artifact_hash_inventory.json", "commands.json", "report.json", "report.md"}
    ]
    if manifest_entries != expected_manifest_entries:
        raise ValueError("V14 postrun manifest artifact inventory changed")
    checks = report.get("checks")
    if not isinstance(checks, dict) or checks != {
            "consumer_not_started": True,
            "frozen_start_hashes_match_current": True,
            "input_snapshots_equal_509_records": True,
            "now_no_residual_pid_or_julia": True,
            "producer_exit_72_and_hydration_failure": True,
            "producer_raw_stream_hashes_match": True,
            "root_controller_exit_124": True,
    }:
        raise ValueError("V14 postrun checks no longer establish the recorded failure boundary")
    final = report.get("final")
    failure = report.get("producer_failure")
    runtime = report.get("run_commands")
    if not isinstance(final, dict) or not isinstance(failure, dict) or not isinstance(runtime, dict):
        raise ValueError("V14 postrun report is missing final/failure/runtime records")
    if (report.get("schema"), report.get("status"), report.get("read_only_review"),
            report.get("reviewer_started_julia"), final.get("classification"),
            final.get("controller_exit_code"), final.get("software_complete"),
            final.get("numerical_status"), final.get("authority"),
            final.get("inputs_unchanged"), final.get("producer_tree_comparison_status"),
            final.get("producer_tree_unchanged"), final.get("nonlinear_solves"), failure.get("classification"),
            failure.get("phase"), failure.get("hydration_stage"), failure.get("consumer_started"),
            failure.get("consumer_files_absent"), runtime.get("root_exit"),
            runtime.get("producer_process_exit"), runtime.get("producer_inner_solver_exit")) != (
            "independent-v14-postrun-audit-v1", "postrun_failure_confirmed", True, False,
            "resource_interruption", 124, False, "fail", "no_publish", True, "not_reached", None, 0,
            "replay_hydration_unsupported", "typed_result_hydration", "schema_directed_reconstruction",
            False, True, 124, 72, 2):
        raise ValueError("V14 postrun report changed the original timeout/hydration/solver failure state")
    expected_error = ("unsupported rebuilt V4 declaration schema node at declaration.source.input: "
                      "Main.ManufacturedCandidateV1Tests.DefinitionRuntime.SpatialManufacturedNumericalInputV1")
    if failure.get("error") != expected_error:
        raise ValueError("V14 postrun typed-input failure signature changed")
    child_argv = commands.get("producer_child", {}).get("argv")
    if (commands.get("root_launcher", {}).get("exit_code"),
            commands.get("controller_child", {}).get("exit_code"),
            commands.get("producer_child", {}).get("exit_code"),
            commands.get("producer_child", {}).get("inner_solver_exit_code"),
            commands.get("producer_child", {}).get("consumer_started"),
            not isinstance(child_argv, list) or "replay_staged_v14.jl" not in " ".join(child_argv)) != (
            124, 124, 72, 2, None, False):
        raise ValueError("V14 postrun commands changed producer argv/exit ancestry")
    all_entries = [dict(item) for item in entries]
    return {"leaf": leaf, "report": report, "manifest": manifest, "commands": commands,
            "input_entries": all_entries}


def verify_v11_process_receipt(process: object) -> None:
    """Validate the original V11 process receipt schema and terminal status."""
    if not isinstance(process, dict) or (process.get("schema"), process.get("stop_reason"),
            process.get("exit_code")) != ("mms-replay-recorded-process-v2", "exited", 72):
        raise ValueError("V11 producer process receipt changed")


def verify_v3_runtime_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the complete immutable V3 failed-run leaf before any V10 output or child."""
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


def check_context_builder_binding_text(entrypoint_text: str, helper_text: str,
                                       candidate_source_text: str) -> None:
    """Require the V10 replay call to resolve through the helper's actual DefinitionRuntime module."""
    if not all(isinstance(value, str) for value in (entrypoint_text, helper_text, candidate_source_text)):
        raise ValueError("context builder binding source text is unavailable")
    if "include(HELPER)" not in entrypoint_text or \
            not re.search(r"const\s+M\s*=\s*ManufacturedCandidateV1Tests", entrypoint_text) or \
            not re.search(r"const\s+S\s*=\s*M\.S", entrypoint_text):
        raise ValueError("replay context builder is not resolved through the frozen helper module alias")
    exact_call = "S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)"
    exact_validate_call = "S.validate_spatial_candidate_v4(context)"
    if entrypoint_text.count(exact_call) != 1 or "build_spatial_candidate_v5" in entrypoint_text:
        raise ValueError("replay must call the defined V4 spatial candidate builder exactly once")
    if entrypoint_text.count(exact_validate_call) != 1 or "validate_spatial_candidate_v5" in entrypoint_text:
        raise ValueError("replay must call the defined V4 spatial candidate validator exactly once")
    if "module ManufacturedCandidateV1Tests" not in helper_text or \
            "module DefinitionRuntime" not in helper_text or \
            not re.search(r"const\s+S\s*=\s*DefinitionRuntime\b", helper_text) or \
            '"SpatialCandidateV4.jl"' not in helper_text:
        raise ValueError("helper does not bind S to DefinitionRuntime with SpatialCandidateV4 included")
    if (not re.search(r"function\s+build_spatial_candidate_v4\s*\(", candidate_source_text) or
            re.search(r"function\s+build_spatial_candidate_v5\s*\(", candidate_source_text)):
        raise ValueError("pinned candidate source does not define the required V4 builder only")
    if (not re.search(r"function\s+validate_spatial_candidate_v4\s*\(", candidate_source_text) or
            re.search(r"function\s+validate_spatial_candidate_v5\s*\(", candidate_source_text)):
        raise ValueError("pinned candidate source does not define the required V4 validator only")


def verify_context_builder_contract(root: pathlib.Path, protocol: dict[str, object]) -> dict[str, object]:
    contract = protocol.get("context_builder_contract")
    if not isinstance(contract, dict):
        raise ValueError("context builder contract is missing")
    if (contract.get("module_alias"), contract.get("module_name"), contract.get("builder_symbol"),
            contract.get("validator_symbol")) != (
            "S=M.S", "DefinitionRuntime", "build_spatial_candidate_v4", "validate_spatial_candidate_v4"):
        raise ValueError("context builder contract names an unsupported module or symbol")
    entrypoint_rel = protocol.get("entrypoint")
    if entrypoint_rel != contract.get("entrypoint_path"):
        raise ValueError("context builder entrypoint differs from the frozen protocol")
    entrypoint_path = verify_bound_sha256(root, entrypoint_rel, contract.get("entrypoint_sha256"),
                                          "V18 replay entrypoint")
    helper_path = verify_bound_sha256(root, contract.get("helper_path"), contract.get("helper_sha256"),
                                      "DefinitionRuntime helper")
    candidate_path = verify_bound_sha256(root, contract.get("candidate_source_path"),
                                         contract.get("candidate_source_sha256"),
                                         "V4 spatial candidate source")
    entrypoint_text = entrypoint_path.read_text(encoding="utf-8")
    helper_text = helper_path.read_text(encoding="utf-8")
    candidate_text = candidate_path.read_text(encoding="utf-8")
    check_context_builder_binding_text(entrypoint_text, helper_text, candidate_text)
    return {"entrypoint_path": entrypoint_path, "helper_path": helper_path,
            "candidate_source_path": candidate_path}


def verify_v8_failure_receipt_values(final: object, producer: object,
                                     failure: object) -> None:
    """Validate V8's real controller-stage and raw-process receipt schemas."""
    if not all(isinstance(value, dict) for value in (final, producer, failure)):
        raise ValueError("V8 replay failure receipts are not JSON objects")
    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"), final.get("solver_exit_code"),
            final.get("stopping_reason"), final.get("authority"), final.get("inputs_unchanged")) != (
            "mms-replay-only-controller-final-v2", "program_exception", 71, False, "fail", 2,
            "stationary_nonzero_residual", "no_publish", True):
        raise ValueError("V8 controller program_exception or preserved solver semantics changed")
    stages = final.get("stages")
    if not isinstance(stages, list) or len(stages) != 1 or not isinstance(stages[0], dict):
        raise ValueError("V8 controller must contain exactly its producer stage")
    stage = stages[0]
    if (stage.get("stage"), stage.get("stop_reason"), stage.get("exit_code"),
            stage.get("wall_limit_seconds"), stage.get("memory_limit_bytes"),
            stage.get("peak_sampled_process_tree_working_set_bytes")) != (
            "producer", "exited", 71, 480.0, 2**31, 714674176):
        raise ValueError("V8 controller producer stage receipt changed")
    if (producer.get("schema"), producer.get("stop_reason"), producer.get("exit_code"),
            producer.get("peak_sampled_process_tree_working_set_bytes")) != (
            "mms-replay-recorded-process-v2", "exited", 71, 714674176):
        raise ValueError("V8 producer process receipt changed")
    if "stage" in producer:
        raise ValueError("V8 raw producer process receipt has an unexpected stage field")
    for name in ("stdout", "stderr"):
        raw = producer.get(name)
        stage_raw = stage.get(name)
        if not isinstance(raw, dict) or not isinstance(stage_raw, dict) or \
                (raw.get("bytes"), raw.get("sha256")) != (stage_raw.get("bytes"), stage_raw.get("sha256")):
            raise ValueError(f"V8 producer raw {name} binding changed")
    if (failure.get("schema"), failure.get("classification"), failure.get("phase"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "mms-replay-only-failure-v1", "context_rebuild_failed", "context_rebuild",
            "UndefVarError: `build_spatial_candidate_v5` not defined", 2, "fail", "no_publish"):
        raise ValueError("V8 context rebuild failure or inherited numerical semantics changed")


def verify_v8_context_rebuild_failure(root: pathlib.Path, protocol: dict[str, object]) -> dict[str, object]:
    """Bind the immutable V8 context-rebuild program exception and independent postrun NO-GO."""
    parent = protocol.get("parent_v8_protocol")
    attempt = protocol.get("parent_v8_failed_attempt")
    grant_pin = protocol.get("parent_v8_grant")
    observation_pin = protocol.get("parent_v8_observation")
    review = protocol.get("parent_v8_independent_postrun_review")
    if not all(isinstance(value, dict) for value in (parent, attempt, grant_pin, observation_pin, review)):
        raise ValueError("V8 failure ancestry is incomplete")
    protocol_path = verify_bound_sha256(root, parent.get("path"), parent.get("sha256"), "V8 protocol")
    v8_protocol = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (v8_protocol.get("schema"), v8_protocol.get("version"), v8_protocol.get("classification"),
            v8_protocol.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v8", 8, "test_only_continuation", False):
        raise ValueError("V8 protocol identity or no-credit boundary changed")
    if (v8_protocol.get("output_leaf"), attempt.get("output_leaf")) != (
            "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r8/runtime_replay_r8",
            "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r8/runtime_replay_r8"):
        raise ValueError("V8 failed-attempt output identity changed")

    grant_path = verify_bound_sha256(root, grant_pin.get("path"), grant_pin.get("sha256"), "V8 root grant")
    observation_path = verify_bound_sha256(root, observation_pin.get("path"), observation_pin.get("sha256"),
                                           "V8 root observation")
    grant = json.loads(grant_path.read_text(encoding="utf-8"))
    observation = json.loads(observation_path.read_text(encoding="utf-8"))
    if grant.get("decision") != "GO_for_one_test_only_replay" or \
            grant.get("physical_acceptance") is not False or \
            grant.get("original_v10_retroactive_closure") is not False or \
            grant.get("frozen_protocol", {}).get("sha256") != parent.get("sha256") or \
            grant.get("output_leaf") != attempt.get("output_leaf"):
        raise ValueError("V8 root grant identity or authority boundary changed")
    if (observation.get("schema"), observation.get("controller_shell_exit_code"),
            observation.get("classification"), observation.get("test_only_replay_complete"),
            observation.get("consumer_started")) != (
            "root-mms-replay-v8-actual-observation-v1", 71, "program_exception", False, False):
        raise ValueError("V8 root observation no longer records the preserved pre-consumer failure")

    entries = attempt.get("entries")
    if not isinstance(entries, list) or not entries:
        raise ValueError("V8 failed-attempt receipt inventory is missing")
    verify_inventory(entries)
    by_path = {entry["path"]: entry for entry in entries}
    def read_json(rel: object, label: str) -> dict[str, object]:
        if not isinstance(rel, str) or rel not in by_path:
            raise ValueError(f"V8 failed-attempt inventory lacks {label}")
        return json.loads(checked_path(root, rel).read_text(encoding="utf-8"))

    final = read_json(attempt.get("final_path"), "controller final")
    producer = read_json(attempt.get("producer_process_path"), "producer process")
    failure = read_json(attempt.get("producer_failure_path"), "producer failure")
    before_path = checked_path(root, str(attempt.get("inputs_before_path")))
    after_path = checked_path(root, str(attempt.get("inputs_after_path")))
    producer_after_path = checked_path(root, str(attempt.get("producer_inputs_after_path")))
    before, after, producer_after = (json.loads(p.read_text(encoding="utf-8"))
                                     for p in (before_path, after_path, producer_after_path))
    if before != after or after != producer_after or len(before) != 288:
        raise ValueError("V8 replay input snapshots changed or have an unexpected entry count")
    snapshot_entries = before
    verify_inventory(snapshot_entries)
    verify_v8_failure_receipt_values(final, producer, failure)
    runtime_root = checked_path(root, attempt.get("output_leaf"))
    if (runtime_root / "consumer_process").exists() or (runtime_root / "consumer_process.json").exists() or \
            (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V8 attempt unexpectedly contains downstream completion artifacts")

    if review.get("classification") != "NO-GO for V8 replay completion" or \
            review.get("julia_started_by_reviewer") is not False:
        raise ValueError("V8 independent postrun review classification changed")
    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V8 independent postrun report")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V8 independent postrun manifest")
    commands_path = verify_bound_sha256(root, review.get("commands_path"), review.get("commands_sha256"),
                                        "V8 independent postrun commands")
    report = report_path.read_text(encoding="utf-8")
    if "context_rebuild_failed" not in report or "consumer did not start" not in report or \
            "not a new solver numerical result" not in report:
        raise ValueError("V8 independent review no-go evidence changed")
    return {"protocol_path": protocol_path, "grant_path": grant_path, "observation_path": observation_path,
            "runtime_root": runtime_root, "attempt_entries": entries, "snapshot_entries": snapshot_entries,
            "final": final, "producer": producer, "failure": failure,
            "review_report_path": report_path, "review_manifest_path": manifest_path,
            "review_commands_path": commands_path}


def verify_v9_static_no_go_ancestry(root: pathlib.Path, protocol: dict[str, object]) -> dict[str, object]:
    """Preserve the V9 static pass and independent NO-GO that found its undefined validator call."""
    parent = protocol.get("parent_v9_protocol")
    static_receipt = protocol.get("parent_v9_static_receipt")
    tester = protocol.get("parent_v9_independent_tester")
    review = protocol.get("parent_v9_independent_no_go_review")
    root_decision = protocol.get("parent_v9_root_decision")
    if not all(isinstance(value, dict) for value in (parent, static_receipt, tester, review, root_decision)):
        raise ValueError("V9 candidate failure ancestry is incomplete")
    parent_path = verify_bound_sha256(root, parent.get("path"), parent.get("sha256"), "V9 parent protocol")
    parent_body = json.loads(parent_path.read_text(encoding="utf-8"))
    if (parent_body.get("schema"), parent_body.get("version"), parent_body.get("classification"),
            parent_body.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v9", 9, "test_only_continuation", False):
        raise ValueError("V9 candidate protocol identity or no-credit boundary changed")
    parent_sources = parent_body.get("owned_source_files")
    if not isinstance(parent_sources, list) or len(parent_sources) != 3:
        raise ValueError("V9 candidate source inventory is missing")
    verify_inventory(parent_sources)
    old_output = checked_path(root, parent_body.get("output_leaf"))
    if old_output.exists():
        raise ValueError("V9 candidate unexpectedly has runtime output")

    receipt_path = verify_bound_sha256(root, static_receipt.get("receipt_path"),
                                       static_receipt.get("receipt_sha256"), "V9 static test receipt")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("schema"), receipt.get("classification"), receipt.get("exit_code"),
            receipt.get("test_count"), receipt.get("julia_started"),
            receipt.get("runtime_output_leaf_created")) != (
            "mms-replay-v9-static-contract-receipt-v1", "static_contract_pass_test_only", 0, 11, False, False):
        raise ValueError("V9 static pass receipt changed")
    if receipt.get("protocol", {}).get("sha256") != parent.get("sha256"):
        raise ValueError("V9 static receipt is bound to a different protocol")
    raw_outputs = receipt.get("raw_outputs")
    if not isinstance(raw_outputs, dict) or set(raw_outputs) != {"stdout.raw", "stderr.raw", "exit_code.txt"}:
        raise ValueError("V9 static raw output receipt set changed")
    static_raw_paths: list[pathlib.Path] = []
    for name, item in raw_outputs.items():
        if not isinstance(item, dict):
            raise ValueError(f"V9 static raw output receipt is invalid ({name})")
        verify_bound_sha256(root, receipt_path.parent.joinpath(name).relative_to(root).as_posix(),
                            item.get("sha256"), f"V9 static raw output {name}")
        raw_path = receipt_path.parent / name
        if raw_path.stat().st_size != item.get("bytes"):
            raise ValueError(f"V9 static raw output byte count changed ({name})")
        static_raw_paths.append(raw_path)
    if (receipt_path.parent / "exit_code.txt").read_text(encoding="utf-8").strip() != "0":
        raise ValueError("V9 static raw test exit is not zero")
    static_sums_path = verify_bound_sha256(root, static_receipt.get("checksums_path"),
                                           static_receipt.get("checksums_sha256"), "V9 static checksums")
    static_commands_path = verify_bound_sha256(root, static_receipt.get("commands_path"),
                                               static_receipt.get("commands_sha256"), "V9 static commands")
    static_sum_lines = static_sums_path.read_text(encoding="ascii").splitlines()
    expected_static_sum_lines = [
        f"{digest(path)}  {path.name}" for path in sorted(
            [static_commands_path, receipt_path, *static_raw_paths], key=lambda item: item.name)]
    if static_sum_lines != expected_static_sum_lines:
        raise ValueError("V9 static checksum file does not bind its exact evidence files")

    tester_receipt_path = verify_bound_sha256(root, tester.get("receipt_path"), tester.get("receipt_sha256"),
                                              "V9 independent tester receipt")
    tester_entries = tester.get("entries")
    if not isinstance(tester_entries, list) or not tester_entries:
        raise ValueError("V9 independent tester evidence inventory is missing")
    verify_inventory(tester_entries)
    tester_dir = tester_receipt_path.parent
    if {item["path"]: item for item in tester_entries} != \
            {item["path"]: item for item in file_inventory(tester_dir)}:
        raise ValueError("V9 independent tester inventory differs from its complete evidence leaf")
    tester_sums_path = tester_dir / "SHA256SUMS.txt"
    if not tester_sums_path.is_file():
        raise FileNotFoundError("V9 independent tester checksum inventory is missing")
    tester_sums_rel = tester_sums_path.relative_to(root).as_posix()
    tester_sums_expected = [
        f"{item['sha256']}  {item['path']}" for item in sorted(
            (entry for entry in tester_entries if entry["path"] != tester_sums_rel),
            key=lambda item: item["path"])]
    if tester_sums_path.read_text(encoding="ascii").splitlines() != tester_sums_expected:
        raise ValueError("V9 independent tester checksum inventory does not bind its exact evidence files")
    tester_receipt = json.loads(tester_receipt_path.read_text(encoding="utf-8"))
    if (tester_receipt.get("schema"), tester_receipt.get("protocol", {}).get("actual_sha256"),
            tester_receipt.get("static_test", {}).get("natural_exit_code"),
            tester_receipt.get("static_test", {}).get("tests_run"),
            tester_receipt.get("static_test", {}).get("julia_started"),
            tester_receipt.get("verdict", {}).get("runtime_continuation"),
            tester_receipt.get("verdict", {}).get("julia_authorized_or_started")) != (
            "mms-replay-only-v9-independent-static-review-v1", parent.get("sha256"), 0, 11, False,
            "NO-GO", False):
        raise ValueError("V9 independent tester receipt changed or does not record the NO-GO boundary")
    binding_audit = tester_receipt.get("binding_audit")
    if not isinstance(binding_audit, dict) or binding_audit.get("entrypoint_line_52") != \
            "S.validate_spatial_candidate_v5(context)" or binding_audit.get("undefined_v5_validator_found") is not False or \
            binding_audit.get("validator_negative_control_present") is not False:
        raise ValueError("V9 independent tester did not preserve the validator static-coverage gap")

    if (review.get("classification"), review.get("julia_started"), review.get("runtime_started")) != (
            "NO-GO", False, False):
        raise ValueError("V9 independent NO-GO classification or no-runtime boundary changed")
    review_entries = review.get("entries")
    if not isinstance(review_entries, list) or not review_entries:
        raise ValueError("V9 independent NO-GO review inventory is missing")
    verify_inventory(review_entries)
    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V9 independent NO-GO report")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V9 independent NO-GO manifest")
    commands_path = verify_bound_sha256(root, review.get("commands_path"), review.get("commands_sha256"),
                                        "V9 independent NO-GO commands")
    review_receipt_path = verify_bound_sha256(root, review.get("receipt_path"), review.get("receipt_sha256"),
                                              "V9 independent NO-GO receipt")
    input_inventory_path = verify_bound_sha256(root, review.get("input_inventory_path"),
                                               review.get("input_inventory_sha256"),
                                               "V9 independent input inventory")
    report = report_path.read_text(encoding="utf-8")
    commands = commands_path.read_text(encoding="utf-8")
    review_receipt = json.loads(review_receipt_path.read_text(encoding="utf-8"))
    review_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if (review_receipt.get("schema"), review_receipt.get("classification"),
            review_receipt.get("runtime_launch_authorized"), review_receipt.get("julia_started_by_reviewer"),
            review_receipt.get("replay_controller_started_by_reviewer"),
            review_receipt.get("solver_desc_mesh_started_by_reviewer"),
            review_receipt.get("numerical_or_physical_credit"), review_receipt.get("runtime_output_leaf_exists")) != (
            "independent-mms-replay-v9-static-review-receipt-v1", "NO-GO", False, False, False, False, False, False):
        raise ValueError("V9 independent review receipt classification or launch/credit boundary changed")
    if (review_manifest.get("schema"), review_manifest.get("classification"), review_manifest.get("evidence_only"),
            review_manifest.get("contains_executable"), review_manifest.get("manifest_lists_itself"),
            review_manifest.get("artifact_count")) != (
            "independent-evidence-only-review-leaf-manifest-v1", "NO-GO", True, False, False, 8):
        raise ValueError("V9 independent review manifest scope or classification changed")
    expected_review_entries = [
        {"path": f"{pathlib.PurePosixPath(review.get('report_path')).parent}/{item['path']}",
         "bytes": item["bytes"], "sha256": item["sha256"]}
        for item in review_manifest["artifacts"]]
    if sorted(expected_review_entries, key=lambda item: item["path"]) != \
            sorted(review_entries, key=lambda item: item["path"]):
        raise ValueError("V9 independent review artifact inventory differs from its manifest")
    missing_definition = not any(text in report for text in (
        "not defined", "undefined", "no definition", "missing validator"))
    if ("NO-GO" not in report or "validate_spatial_candidate_v5" not in report or
            "validate_spatial_candidate_v4" not in report or missing_definition):
        raise ValueError("V9 reviewer did not preserve the undefined validator blocker")
    if "Exit: 0" not in commands or "NOT RUN" not in commands:
        raise ValueError("V9 independent review command/exit boundary changed")
    root_decision_path = verify_bound_sha256(root, root_decision.get("path"), root_decision.get("sha256"),
                                             "root V9 NO-GO decision")
    decision = json.loads(root_decision_path.read_text(encoding="utf-8"))
    if (decision.get("schema"), decision.get("decision"), decision.get("candidate_protocol_sha256"),
            decision.get("producer_static_receipt_sha256"), decision.get("classification"),
            decision.get("actual_v9_runtime_outcome")) != (
            "root-mms-replay-v9-no-go-v1", "NO_GO_for_Julia_replay", parent.get("sha256"),
            static_receipt.get("receipt_sha256"),
            "static_test_coverage_gap_and_predicted_runtime_program_exception", "not_executed"):
        raise ValueError("root V9 NO-GO decision or preserved outcome taxonomy changed")
    if decision.get("independent_tester") != {"path": tester.get("receipt_path"),
                                               "sha256": tester.get("receipt_sha256")} or \
            decision.get("independent_reviewer") != {"path": review.get("report_path"),
                                                       "sha256": review.get("report_sha256")}:
        raise ValueError("root V9 NO-GO decision does not bind the two independent receipts")
    return {"protocol_path": parent_path, "static_receipt_path": receipt_path,
            "static_checksums_path": static_sums_path, "static_commands_path": static_commands_path,
            "static_raw_paths": static_raw_paths,
            "tester_receipt_path": tester_receipt_path, "tester_entries": tester_entries,
            "tester_sums_path": tester_sums_path,
            "root_decision_path": root_decision_path,
            "review_entries": review_entries, "review_report_path": report_path,
            "review_manifest_path": manifest_path, "review_commands_path": commands_path,
            "review_receipt_path": review_receipt_path, "input_inventory_path": input_inventory_path,
            "static_receipt": receipt, "old_output": old_output}


def verify_v7_no_go_ancestry(root: pathlib.Path, parent_protocol: object,
                             independent_review: object) -> dict[str, object]:
    """Bind the immutable V7 protocol and its independent aggregate-limit NO-GO."""
    if not isinstance(parent_protocol, dict) or not isinstance(independent_review, dict):
        raise ValueError("V7 protocol/review ancestry is missing")
    parent_path = verify_bound_sha256(root, parent_protocol.get("path"),
                                      parent_protocol.get("sha256"), "V7 parent protocol")
    if independent_review.get("classification") != "NO-GO for runtime grant":
        raise ValueError("V7 independent review classification changed")
    if independent_review.get("julia_started") is not False or independent_review.get("output_leaf_absent") is not True:
        raise ValueError("V7 independent review execution boundary changed")
    report_path = verify_bound_sha256(root, independent_review.get("report_path"),
                                      independent_review.get("report_sha256"), "V7 independent review report")
    manifest_path = verify_bound_sha256(root, independent_review.get("manifest_path"),
                                        independent_review.get("manifest_sha256"), "V7 independent review manifest")
    commands_path = verify_bound_sha256(root, independent_review.get("commands_path"),
                                        independent_review.get("commands_sha256"), "V7 independent review commands")
    report = report_path.read_text(encoding="utf-8")
    commands = commands_path.read_text(encoding="utf-8")
    if ("NO-GO for a V7 runtime grant" not in report or
            "total_child_wall_limit_seconds" not in report or "960" not in report or
            "controller never enforces" not in report):
        raise ValueError("V7 independent review no-go reason changed")
    if "Exit: 0" not in commands or "No V7 replay controller" not in commands:
        raise ValueError("V7 independent review command/exit evidence changed")
    return {"protocol_path": parent_path, "report_path": report_path,
            "manifest_path": manifest_path, "commands_path": commands_path}


def verify_v6_postrun_scopefix_review(root: pathlib.Path, review: object) -> dict[str, object]:
    """Bind the corrected V6 post-run review and enforce its evidence-only archive scope."""
    if not isinstance(review, dict):
        raise ValueError("V6 corrected post-run review metadata is missing")
    if (review.get("classification"), review.get("julia_started"), review.get("replay_started"),
            review.get("archive_executable_count"), review.get("helper_exit_code")) != (
            "NO-GO for retry", False, False, 0, 0):
        raise ValueError("V6 corrected post-run review classification or scope changed")
    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V6 corrected post-run review report")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V6 corrected post-run evidence manifest")
    commands_path = verify_bound_sha256(root, review.get("commands_path"), review.get("commands_sha256"),
                                        "V6 corrected post-run command record")
    helper_path = verify_bound_sha256(root, review.get("helper_path"), review.get("helper_sha256"),
                                      "V6 relocated test-owned receipt helper")
    inventory_stdout = verify_bound_sha256(root, review.get("archive_inventory_stdout_path"),
                                           review.get("archive_inventory_stdout_sha256"),
                                           "V6 archive executable inventory stdout")
    inventory_exit = verify_bound_sha256(root, review.get("archive_inventory_exit_path"),
                                         review.get("archive_inventory_exit_sha256"),
                                         "V6 archive executable inventory exit")
    report_text = report_path.read_text(encoding="utf-8")
    commands_text = commands_path.read_text(encoding="utf-8")
    if "V6 remains NO-GO for retry" not in report_text or "scope_violation.md" not in report_text:
        raise ValueError("V6 corrected review does not preserve the NO-GO and scope history")
    if ("recheck_v6_receipts.ps1'" not in commands_text or "Exit: 0" not in commands_text or
            "No Julia" not in commands_text):
        raise ValueError("V6 corrected review command/exit evidence changed")
    if not helper_path.is_relative_to(checked_path(root, "test")):
        raise ValueError("V6 receipt helper is outside the test-owned tree")
    if inventory_stdout.read_text(encoding="utf-8").strip() != "EXECUTABLE_COUNT=0":
        raise ValueError("V6 corrected archive inventory is not empty of executables")
    if inventory_exit.read_text(encoding="ascii").strip() != "0":
        raise ValueError("V6 corrected archive inventory did not exit cleanly")

    evidence_leaf = checked_path(root, review.get("evidence_leaf"))
    manifest_entries: dict[str, tuple[str, int]] = {}
    for line in manifest_path.read_text(encoding="utf-8").splitlines():
        parts = line.split("  ", 2)
        if len(parts) != 3 or not parts[2].startswith("bytes="):
            raise ValueError("V6 corrected post-run manifest format changed")
        sha_value, rel, byte_field = parts
        try:
            byte_count = int(byte_field.removeprefix("bytes="))
        except ValueError as exc:
            raise ValueError("V6 corrected post-run manifest byte count is invalid") from exc
        path = verify_bound_sha256(root, rel, sha_value, "V6 corrected post-run manifest entry")
        if path.stat().st_size != byte_count:
            raise ValueError(f"V6 corrected post-run manifest size drift: {path}")
        manifest_entries[rel] = (sha_value, byte_count)

    prefix = review["evidence_leaf"].rstrip("/") + "/"
    leaf_entries = {rel for rel in manifest_entries if rel.startswith(prefix)}
    manifest_rel = review["manifest_path"]
    actual_leaf_files = {path.relative_to(root).as_posix() for path in evidence_leaf.rglob("*") if path.is_file()}
    if actual_leaf_files != leaf_entries | {manifest_rel}:
        raise ValueError("V6 corrected evidence leaf inventory differs from its manifest")
    forbidden = {".ps1", ".py", ".jl", ".exe", ".bat", ".cmd", ".com", ".sh"}
    if any(pathlib.Path(rel).suffix.lower() in forbidden for rel in leaf_entries | {manifest_rel}):
        raise ValueError("V6 corrected evidence leaf contains an executable or source file")
    if len(manifest_entries) < 10:
        raise ValueError("V6 corrected evidence manifest is unexpectedly incomplete")
    return {"report_path": report_path, "manifest_path": manifest_path, "commands_path": commands_path,
            "helper_path": helper_path, "evidence_leaf": evidence_leaf,
            "manifest_entry_count": len(manifest_entries)}


def verify_v6_root_preflight_failure(root: pathlib.Path, parent_protocol: object,
                                    review: object, attempt: object,
                                    postrun_review: object) -> dict[str, object]:
    """Bind the V6 GO, its root-only grant, and the pre-output schema failure as ancestry only."""
    if (not isinstance(parent_protocol, dict) or not isinstance(review, dict) or
            not isinstance(attempt, dict) or not isinstance(postrun_review, dict)):
        raise ValueError("V6 replay ancestry is incomplete")
    protocol_path = verify_bound_sha256(root, parent_protocol.get("path"), parent_protocol.get("sha256"),
                                        "parent V6 protocol")
    if review.get("classification") != "GO" or review.get("julia_started") is not False:
        raise ValueError("V6 independent review is not a static GO")
    report_path = verify_bound_sha256(root, review.get("report_path"), review.get("report_sha256"),
                                      "V6 independent review report")
    manifest_path = verify_bound_sha256(root, review.get("manifest_path"), review.get("manifest_sha256"),
                                        "V6 independent review manifest")
    grant_path = verify_bound_sha256(root, attempt.get("grant_path"), attempt.get("grant_sha256"),
                                     "V6 root grant receipt")
    observation_path = verify_bound_sha256(root, attempt.get("observation_path"),
                                           attempt.get("observation_sha256"), "V6 root preflight observation")
    grant = json.loads(grant_path.read_text(encoding="utf-8"))
    observation = json.loads(observation_path.read_text(encoding="utf-8"))
    expected_output = "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r6/runtime_replay_r6"
    if (grant.get("schema"), grant.get("classification"), grant.get("protocol_path"),
            grant.get("protocol_sha256"), grant.get("independent_review_path"),
            grant.get("independent_review_sha256"), grant.get("output_leaf"), grant.get("heavy_lane")) != (
            "root-serial-slot-grant-v1", "test_only_continuation", parent_protocol["path"],
            parent_protocol["sha256"], review["report_path"], review["report_sha256"], expected_output, "exclusive"):
        raise ValueError("V6 grant receipt no longer binds the reviewed V6 attempt")
    if (observation.get("schema"), observation.get("shell_exit_code"), observation.get("error_type"),
            observation.get("error_message"), observation.get("actual_historical_schema"),
            observation.get("expected_hardcoded_schema"), observation.get("producer_final_sha256"),
            observation.get("producer_process_sha256"), observation.get("producer_final_exit_code"),
            observation.get("producer_process_exit_code"), observation.get("producer_stop_reason"),
            observation.get("output_leaf_exists"), observation.get("julia_started")) != (
            "root-mms-v6-preflight-failure-observation-v1", 1, "ValueError",
            "original v10 producer process receipt changed", "mms-recorded-process-v3",
            "mms-recorded-process-v6", "5a299f91dec04cd6ea866f7610bc8faf15d9b99cd98bfbbdd987dec8b2f5ebfc",
            "584b1fe4e11dfb1325121041807dba06cb02371866c87b00fc2b020b3df91d69", 15, 15,
            "wall_timeout", False, False):
        raise ValueError("V6 preflight failure observation changed")
    parent_protocol_body = json.loads(protocol_path.read_text(encoding="utf-8"))
    if observation.get("exact_argv") != parent_protocol_body.get("controller_command_template", "").replace(
            "<this-file-sha256>", parent_protocol.get("sha256", "")):
        raise ValueError("V6 exact attempted command no longer matches its granted protocol")
    if report_path.stat().st_size <= 0 or manifest_path.stat().st_size <= 0:
        raise ValueError("V6 review evidence is empty")
    if checked_path(root, expected_output).exists():
        raise ValueError("V6 failed attempt unexpectedly created its output leaf")
    corrected_review = verify_v6_postrun_scopefix_review(root, postrun_review)
    return {"grant": grant, "observation": observation, "grant_path": grant_path,
            "observation_path": observation_path, "protocol_path": protocol_path,
            "postrun_review": corrected_review}


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


def live_tree_bytes(root_pid: int,
                    expected_root_identity: tuple[int, float] | None = None) -> tuple[int, list[dict[str, object]]]:
    """Return RSS only when every process in the enumerated tree was observed."""
    total = 0
    identities = []
    try:
        root_proc = psutil.Process(root_pid)
    except Exception as exc:
        raise ProcessTreeObservationError(
            "root_process", root_pid, root_pid, total, identities, exc) from exc
    try:
        root_pid_observed = int(root_proc.pid)
        root_create_time = float(root_proc.create_time())
        if root_pid_observed != int(root_pid) or not math.isfinite(root_create_time):
            raise ValueError("root identity is malformed")
        if expected_root_identity is not None and \
                (root_pid_observed, root_create_time) != \
                (int(expected_root_identity[0]), float(expected_root_identity[1])):
            raise ValueError(
                f"root identity changed: expected={expected_root_identity!r}, "
                f"observed={(root_pid_observed, root_create_time)!r}")
    except Exception as exc:
        raise ProcessTreeObservationError(
            "root_identity", root_pid, int(getattr(root_proc, "pid", root_pid)), total, identities, exc) from exc
    try:
        descendants = root_proc.children(recursive=True)
    except Exception as exc:
        raise ProcessTreeObservationError(
            "descendant_enumeration", root_pid, root_pid, total, identities, exc) from exc
    processes = [root_proc] + list(descendants)
    identities_by_pid: dict[int, tuple[int, float]] = {}
    root_occurrences = 0
    for proc in processes:
        try:
            process_pid = int(proc.pid)
            create_time = float(proc.create_time())
            if not math.isfinite(create_time):
                raise ValueError(f"process create_time must be finite, got {create_time!r}")
            identity = (process_pid, create_time)
            if process_pid == root_pid_observed:
                root_occurrences += 1
                if identity != (root_pid_observed, root_create_time):
                    raise ValueError("root pid was observed with a different creation time")
            previous = identities_by_pid.get(process_pid)
            if previous is not None:
                if previous != identity:
                    raise ValueError(f"pid reuse/conflicting identity in process tree: {previous!r} vs {identity!r}")
                continue
            identities_by_pid[process_pid] = identity
            rss = proc.memory_info().rss
            if isinstance(rss, bool) or not isinstance(rss, int) or rss < 0:
                raise ValueError(f"RSS must be a nonnegative integer, got {rss!r}")
            identities.append({"pid": process_pid, "create_time": create_time})
            total += rss
        except Exception as exc:
            try:
                failed_pid = int(proc.pid)
            except Exception:
                failed_pid = None
            raise ProcessTreeObservationError(
                "process_identity_or_rss", root_pid, failed_pid, total, identities, exc) from exc
    if root_occurrences != 1 or (root_pid_observed, root_create_time) not in identities_by_pid.values():
        cause = ValueError(
            f"complete tree sample must contain exactly one pinned root identity; "
            f"root_occurrences={root_occurrences}, root={(root_pid_observed, root_create_time)!r}")
        raise ProcessTreeObservationError(
            "root_identity_not_unique", root_pid, root_pid_observed, total, identities, cause)
    return total, identities


def known_descendants_after_leader_exit(
        identities: list[dict[str, object]], root_identity: tuple[int, float]) -> dict[str, object]:
    """Recheck every previously observed descendant by PID and creation time after leader exit."""
    active: list[dict[str, object]] = []
    unknown: list[dict[str, object]] = []
    try:
        expected_root = (int(root_identity[0]), float(root_identity[1]))
        if expected_root[0] <= 0 or not math.isfinite(expected_root[1]):
            raise ValueError("root identity is malformed")
    except Exception as exc:
        return {"active_descendants": active,
                "unknown_descendants": [{"stage": "root_identity_validation",
                                          "error_type": type(exc).__name__, "error": str(exc)}],
                "all_previously_observed_descendants_checked": False,
                "pinned_root_identity_verified": False,
                "rechecked_descendant_identity_count": 0}

    identities_by_pid: dict[int, float] = {}
    for item in identities:
        try:
            if not isinstance(item, dict) or isinstance(item.get("pid"), bool) or \
                    isinstance(item.get("create_time"), bool):
                raise ValueError("observed process identity is malformed")
            pid = int(item["pid"])
            create_time = float(item["create_time"])
            if pid <= 0 or not math.isfinite(create_time):
                raise ValueError("observed process identity is outside its valid range")
            previous = identities_by_pid.get(pid)
            if previous is not None and previous != create_time:
                raise ValueError("observed PID was reused within the stage")
            identities_by_pid[pid] = create_time
        except Exception as exc:
            unknown.append({"stage": "observed_identity_validation",
                            "error_type": type(exc).__name__, "error": str(exc)})

    if identities_by_pid.get(expected_root[0]) != expected_root[1]:
        unknown.append({"pid": expected_root[0], "expected_create_time": expected_root[1],
                        "observed_create_time": identities_by_pid.get(expected_root[0]),
                        "stage": "pinned_root_identity_missing_or_changed",
                        "error_type": "RootIdentityMismatch"})
    if unknown:
        return {"active_descendants": active, "unknown_descendants": unknown,
                "all_previously_observed_descendants_checked": False,
                "pinned_root_identity_verified": False,
                "rechecked_descendant_identity_count": 0}

    for pid, expected_create_time in sorted(identities_by_pid.items()):
        if pid == expected_root[0]:
            continue
        try:
            proc = psutil.Process(pid)
        except psutil.NoSuchProcess:
            continue
        except Exception as exc:
            unknown.append({"pid": pid, "expected_create_time": expected_create_time,
                            "stage": "lookup", "error_type": type(exc).__name__, "error": str(exc)})
            continue
        try:
            observed_create_time = float(proc.create_time())
            if not math.isfinite(observed_create_time) or observed_create_time != expected_create_time:
                unknown.append({"pid": pid, "expected_create_time": expected_create_time,
                                "observed_create_time": observed_create_time,
                                "stage": "pid_identity_changed", "error_type": "IdentityMismatch"})
                continue
            if proc.is_running():
                active.append({"pid": pid, "create_time": expected_create_time})
        except psutil.NoSuchProcess:
            continue
        except Exception as exc:
            unknown.append({"pid": pid, "expected_create_time": expected_create_time,
                            "stage": "running_check", "error_type": type(exc).__name__, "error": str(exc)})
    return {"active_descendants": active, "unknown_descendants": unknown,
            "all_previously_observed_descendants_checked": not unknown,
            "pinned_root_identity_verified": True,
            "rechecked_descendant_identity_count": len(identities_by_pid) - 1}


def process_table_descendants_after_leader_exit(
        identities: list[dict[str, object]], root_identity: tuple[int, float]) -> dict[str, object]:
    """Use the pinned psutil PPID snapshot to catch descendants born after the last RSS sample."""
    unknown: list[dict[str, object]] = []
    active: list[dict[str, object]] = []
    observed_process_identities: list[dict[str, object]] = []
    expected_root = (int(root_identity[0]), float(root_identity[1]))
    known_by_pid: dict[int, float] = {}
    for item in identities:
        try:
            if not isinstance(item, dict) or isinstance(item.get("pid"), bool) or \
                    isinstance(item.get("create_time"), bool):
                raise ValueError("observed process identity is malformed")
            pid = int(item["pid"])
            create_time = float(item["create_time"])
            if pid <= 0 or not math.isfinite(create_time):
                raise ValueError("observed process identity is outside its valid range")
            previous = known_by_pid.get(pid)
            if previous is not None and previous != create_time:
                raise ValueError("observed PID was reused within the stage")
            known_by_pid[pid] = create_time
        except Exception as exc:
            unknown.append({"stage": "observed_identity_validation",
                            "error_type": type(exc).__name__, "error": str(exc)})
    if known_by_pid.get(expected_root[0]) != expected_root[1]:
        unknown.append({"pid": expected_root[0], "expected_create_time": expected_root[1],
                        "observed_create_time": known_by_pid.get(expected_root[0]),
                        "stage": "pinned_root_identity_missing_or_changed",
                        "error_type": "RootIdentityMismatch"})
    if unknown:
        return {"active_descendants": active, "unknown_descendants": unknown,
                "process_table_snapshot_complete": False,
                "unobserved_descendant_identity_count": 0,
                "observed_process_identities": observed_process_identities}

    try:
        ppid_map = psutil._ppid_map()
        if not isinstance(ppid_map, dict):
            raise TypeError("pinned psutil _ppid_map did not return a dictionary")
    except Exception as exc:
        return {"active_descendants": active,
                "unknown_descendants": [{"stage": "process_table_ppid_snapshot",
                                          "error_type": type(exc).__name__, "error": str(exc)}],
                "process_table_snapshot_complete": False,
                "unobserved_descendant_identity_count": 0,
                "observed_process_identities": observed_process_identities}

    reverse: dict[int, list[int]] = {}
    for raw_pid, raw_parent_pid in ppid_map.items():
        if (isinstance(raw_pid, bool) or isinstance(raw_parent_pid, bool) or
                not isinstance(raw_pid, int) or not isinstance(raw_parent_pid, int)):
            unknown.append({"stage": "process_table_identity_validation",
                            "error_type": "MalformedProcessId",
                            "error": "process-table PID and PPID must be exact integers"})
            continue
        try:
            pid, parent_pid = raw_pid, raw_parent_pid
            if pid == 0:
                if parent_pid == 0:
                    # Windows psutil includes PID 0 (Idle) as its own parent. It is
                    # a process-table sentinel, never an owned process identity.
                    continue
                raise ValueError("PID 0 is valid only as the (0, 0) process-table sentinel")
            if pid < 0 or parent_pid < 0:
                raise ValueError("process-table PID or PPID is outside its valid range")
            reverse.setdefault(parent_pid, []).append(pid)
        except Exception as exc:
            unknown.append({"stage": "process_table_identity_validation",
                            "error_type": type(exc).__name__, "error": str(exc)})
    if expected_root[0] in ppid_map:
        unknown.append({"pid": expected_root[0], "expected_create_time": expected_root[1],
                        "stage": "root_pid_present_after_confirmed_exit",
                        "error_type": "RootStillPresentOrPidReused"})

    queue = [expected_root[0]]
    visited = {expected_root[0]}
    unobserved_count = 0
    while queue:
        parent_pid = queue.pop(0)
        for child_pid in sorted(reverse.get(parent_pid, [])):
            if child_pid in visited:
                unknown.append({"pid": child_pid, "parent_pid": parent_pid,
                                "stage": "process_table_descendant_cycle",
                                "error_type": "ProcessTreeCycle"})
                continue
            visited.add(child_pid)
            queue.append(child_pid)
            expected_create_time = known_by_pid.get(child_pid)
            if expected_create_time is None:
                unobserved_count += 1
                item = {"pid": child_pid, "parent_pid": parent_pid,
                        "stage": "unobserved_post_sample_descendant",
                        "error_type": "UnobservedDescendant"}
                try:
                    proc = psutil.Process(child_pid)
                    observed_create_time = float(proc.create_time())
                    if child_pid <= 0 or not math.isfinite(observed_create_time):
                        raise ValueError("unobserved descendant identity is malformed")
                    observed = {"pid": child_pid, "create_time": observed_create_time}
                    observed_process_identities.append(observed)
                    item["observed_create_time"] = observed_create_time
                    if proc.is_running():
                        active.append(observed)
                except psutil.NoSuchProcess:
                    item["identity_recheck"] = "process_disappeared_after_ppid_snapshot"
                except Exception as exc:
                    item["identity_recheck_error_type"] = type(exc).__name__
                    item["identity_recheck_error"] = str(exc)
                unknown.append(item)
                continue
            try:
                proc = psutil.Process(child_pid)
                observed_create_time = float(proc.create_time())
                if not math.isfinite(observed_create_time) or observed_create_time != expected_create_time:
                    unknown.append({"pid": child_pid, "expected_create_time": expected_create_time,
                                    "observed_create_time": observed_create_time,
                                    "stage": "process_table_descendant_pid_reuse",
                                    "error_type": "IdentityMismatch"})
                    continue
                if proc.is_running():
                    observed = {"pid": child_pid, "create_time": expected_create_time}
                    active.append(observed)
                    observed_process_identities.append(observed)
            except psutil.NoSuchProcess:
                # The PPID snapshot can race with a process that exited after enumeration.
                continue
            except Exception as exc:
                unknown.append({"pid": child_pid, "expected_create_time": expected_create_time,
                                "stage": "process_table_descendant_recheck",
                                "error_type": type(exc).__name__, "error": str(exc)})

    active.sort(key=lambda item: (int(item["pid"]), float(item["create_time"])))
    return {"active_descendants": active, "unknown_descendants": unknown,
            "process_table_snapshot_complete": not unknown,
            "unobserved_descendant_identity_count": unobserved_count,
            "observed_process_identities": observed_process_identities}


def audit_descendants_after_leader_exit(
        identities: list[dict[str, object]], root_identity: tuple[int, float]) -> dict[str, object]:
    """Recheck known descendants, then reject any newer child visible in a PPID snapshot."""
    prior = known_descendants_after_leader_exit(identities, root_identity)
    if prior["active_descendants"] or prior["unknown_descendants"]:
        return {**prior, "process_table_snapshot_complete": False,
                "unobserved_descendant_identity_count": 0,
                "audit_status": "active_or_unknown_previously_observed_descendant"}
    current = process_table_descendants_after_leader_exit(identities, root_identity)
    active = list(current["active_descendants"])
    unknown = list(current["unknown_descendants"])
    return {
        "active_descendants": active,
        "unknown_descendants": unknown,
        "all_previously_observed_descendants_checked": prior["all_previously_observed_descendants_checked"],
        "pinned_root_identity_verified": prior["pinned_root_identity_verified"],
        "rechecked_descendant_identity_count": prior["rechecked_descendant_identity_count"],
        "process_table_snapshot_complete": current["process_table_snapshot_complete"],
        "unobserved_descendant_identity_count": current["unobserved_descendant_identity_count"],
        "observed_process_identities": current["observed_process_identities"],
        "audit_status": "complete_no_residual_descendants" if not active and not unknown
        else "active_or_unknown_process_table_descendant",
    }


def terminate_tree(pid: int, cleanup_grace_seconds: float,
                   known_process_identities: list[dict[str, object]] | None = None,
                   expected_root_identity: tuple[int, float] | None = None) -> dict[str, object]:
    """Terminate a process tree and bound all waits by one cleanup deadline."""
    started = time.monotonic()
    deadline = started + max(0.0, float(cleanup_grace_seconds))
    observation_errors: list[dict[str, object]] = []
    inventory_complete = True
    known_by_pid: dict[int, float] = {}
    for item in known_process_identities or []:
        try:
            known_pid = int(item["pid"])
            known_create_time = float(item["create_time"])
            if not math.isfinite(known_create_time):
                raise ValueError("known process create_time is not finite")
            if known_pid in known_by_pid and known_by_pid[known_pid] != known_create_time:
                raise ValueError("known process list contains a reused PID")
            known_by_pid[known_pid] = known_create_time
        except Exception as exc:
            inventory_complete = False
            observation_errors.append({
                "stage": "known_identity_validation", "error_type": type(exc).__name__, "error": str(exc),
            })
    if expected_root_identity is not None:
        try:
            expected_pid = int(expected_root_identity[0])
            expected_create_time = float(expected_root_identity[1])
            if expected_pid != int(pid) or not math.isfinite(expected_create_time):
                raise ValueError("expected root identity is malformed")
            if expected_pid in known_by_pid and known_by_pid[expected_pid] != expected_create_time:
                raise ValueError("expected root identity conflicts with known process identities")
            known_by_pid[expected_pid] = expected_create_time
        except Exception as exc:
            inventory_complete = False
            observation_errors.append({
                "stage": "expected_root_identity_validation", "error_type": type(exc).__name__,
                "error": str(exc),
            })
            expected_root_identity = None
    else:
        inventory_complete = False
        observation_errors.append({
            "stage": "root_identity_unpinned", "pid": int(pid),
            "error_type": "MissingRootIdentity", "error": "refusing PID-only process-tree termination",
        })
    try:
        root_proc = psutil.Process(pid)
    except Exception as exc:
        root_proc = None
        inventory_complete = False
        observation_errors.append({
            "stage": "root_process_lookup", "pid": int(pid),
            "error_type": type(exc).__name__, "error": str(exc),
        })
    if root_proc is not None:
        try:
            root_identity = (int(root_proc.pid), float(root_proc.create_time()))
            if not math.isfinite(root_identity[1]) or root_identity[0] != int(pid):
                raise ValueError("root identity is malformed")
            expected_root_time = known_by_pid.get(int(pid))
            if expected_root_time is None or root_identity[1] != expected_root_time:
                inventory_complete = False
                observation_errors.append({
                    "stage": "root_pid_reuse_or_unpinned", "pid": int(pid),
                    "expected_create_time": expected_root_time,
                    "observed_create_time": root_identity[1],
                })
                root_proc = None
                children = []
            else:
                children = root_proc.children(recursive=True)
        except Exception as exc:
            children = []
            inventory_complete = False
            observation_errors.append({
                "stage": "root_identity_or_descendant_enumeration", "pid": int(pid),
                "error_type": type(exc).__name__, "error": str(exc),
            })
    else:
        children = []
    candidates: dict[tuple[int, float], object] = {}
    for proc in list(reversed(children)) + ([root_proc] if root_proc is not None else []):
        try:
            identity = (int(proc.pid), float(proc.create_time()))
            if not math.isfinite(identity[1]):
                raise ValueError("candidate create_time is not finite")
            expected = known_by_pid.get(identity[0])
            if expected is not None and expected != identity[1]:
                inventory_complete = False
                observation_errors.append({
                    "stage": "candidate_pid_reuse", "pid": identity[0],
                    "expected_create_time": expected, "observed_create_time": identity[1],
                })
                continue
            candidates[identity] = proc
        except Exception as exc:
            inventory_complete = False
            observation_errors.append({
                "stage": "candidate_identity", "pid": int(getattr(proc, "pid", -1)),
                "error_type": type(exc).__name__, "error": str(exc),
            })
    for known_pid, known_create_time in known_by_pid.items():
        try:
            proc = psutil.Process(known_pid)
        except psutil.NoSuchProcess:
            # The previously observed process identity is confirmed absent.
            continue
        except Exception as exc:
            inventory_complete = False
            observation_errors.append({
                "stage": "known_process_lookup", "pid": known_pid,
                "error_type": type(exc).__name__, "error": str(exc),
            })
            continue
        try:
            current_create_time = float(proc.create_time())
            if current_create_time != known_create_time:
                inventory_complete = False
                observation_errors.append({
                    "stage": "known_pid_reuse", "pid": known_pid,
                    "expected_create_time": known_create_time,
                    "observed_create_time": current_create_time,
                })
                continue
            candidates[(known_pid, known_create_time)] = proc
        except psutil.NoSuchProcess:
            continue
        except Exception as exc:
            inventory_complete = False
            observation_errors.append({
                "stage": "known_process_identity", "pid": known_pid,
                "error_type": type(exc).__name__, "error": str(exc),
            })
    targets = list(candidates.values())
    identities: list[dict[str, object]] = []
    terminate_requested: list[int] = []
    for proc in targets:
        try:
            identities.append({"pid": int(proc.pid), "create_time": float(proc.create_time())})
            terminate_requested.append(proc.pid)
            proc.terminate()
        except Exception as exc:
            observation_errors.append({
                "stage": "terminate_request", "pid": int(proc.pid),
                "error_type": type(exc).__name__, "error": str(exc),
            })
    alive = targets
    last_wait_succeeded = False
    if targets:
        try:
            grace = min(1.0, max(0.0, deadline - time.monotonic()))
            _, alive = psutil.wait_procs(targets, timeout=grace)
            last_wait_succeeded = True
        except Exception as exc:
            observation_errors.append({
                "stage": "terminate_wait", "pids": sorted({int(proc.pid) for proc in targets}),
                "error_type": type(exc).__name__, "error": str(exc),
            })
            # Retain the candidates as potentially alive.  A monitor failure is
            # uncertainty, not proof that descendants exited.
            alive = targets
    kill_requested: list[int] = []
    for proc in alive:
        try:
            kill_requested.append(proc.pid)
            proc.kill()
        except Exception as exc:
            observation_errors.append({
                "stage": "kill_request", "pid": int(proc.pid),
                "error_type": type(exc).__name__, "error": str(exc),
            })
    remaining = max(0.0, deadline - time.monotonic())
    if alive and remaining > 0:
        try:
            _, alive = psutil.wait_procs(alive, timeout=remaining)
            last_wait_succeeded = True
        except Exception as exc:
            observation_errors.append({
                "stage": "kill_wait", "pids": sorted({int(proc.pid) for proc in alive}),
                "error_type": type(exc).__name__, "error": str(exc),
            })
            # Keep the previous alive set when the bounded recheck itself fails.
    return {
        "cleanup_grace_seconds": float(cleanup_grace_seconds),
        "elapsed_seconds": time.monotonic() - started,
        "terminate_requested_pids": sorted(set(terminate_requested)),
        "kill_requested_pids": sorted(set(kill_requested)),
        "owned_process_identities": identities,
        "remaining_process_pids": sorted({proc.pid for proc in alive}),
        "termination_verification_errors": observation_errors,
        "process_tree_inventory_complete": inventory_complete,
        "termination_wait_succeeded": last_wait_succeeded,
        "termination_confirmed": inventory_complete and last_wait_succeeded and not alive,
        "bounded_wait_deadline_monotonic": deadline,
    }


def resource_interruption_exit_code(stop_reason: str) -> int | None:
    """Map monitor/limit stops to non-success controller outcomes."""
    if stop_reason == "working_set_limit":
        return 123
    if stop_reason in (
            "wall_timeout", "aggregate_wall_timeout", "aggregate_cleanup_overrun",
            "cleanup_unconfirmed", "process_tree_observation_incomplete",
            "leader_exited_with_live_descendants"):
        return 124
    return None


def run_stage(command: list[str], cwd: pathlib.Path, stage_dir: pathlib.Path, limit_s: float,
              memory_limit: int, env: dict[str, str], wall_budget: dict[str, float]) -> dict[str, object]:
    if not isinstance(wall_budget, dict) or wall_budget.get("live_limit_seconds", 0.0) <= 0:
        raise AggregateChildWallBudgetExhausted("stage launch refused without positive aggregate wall budget")
    if float(wall_budget["stage_cap_seconds"]) != float(limit_s):
        raise ValueError("stage wall budget does not match the frozen per-stage cap")
    stage_dir.mkdir(parents=True, exist_ok=True)
    stdout_path = stage_dir / "stdout.raw"
    stderr_path = stage_dir / "stderr.raw"
    stage_started = time.monotonic()
    started_utc = dt.datetime.now(dt.timezone.utc).isoformat(timespec="milliseconds")
    peak = 0
    identities: list[dict[str, object]] = []
    rss_sampling_complete = True
    rss_complete_sample_count = 0
    rss_observation_errors: list[dict[str, object]] = []
    root_identity: tuple[int, float] | None = None
    leader_exit_check: dict[str, object] | None = None
    leader_exit_observation: dict[str, object] | None = None
    stop_reason = "exited"
    cleanup: dict[str, object] | None = None
    process_started = 0.0
    process_ended = 0.0
    effective_live_limit = float(wall_budget["live_limit_seconds"])
    cleanup_grace = float(wall_budget["cleanup_grace_seconds"])
    aggregate_remaining = float(wall_budget["remaining_before_seconds"])
    with stdout_path.open("xb") as stdout, stderr_path.open("xb") as stderr:
        process_started = time.monotonic()
        proc = subprocess.Popen(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                                creationflags=getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0))
        try:
            if proc.poll() is not None:
                raise ProcessTreeObservationError(
                    "root_exited_before_identity_capture", proc.pid, proc.pid, 0, [],
                    RuntimeError("direct child exited before its process identity could be pinned"))
            root_proc = psutil.Process(proc.pid)
            root_create_time = float(root_proc.create_time())
            if not math.isfinite(root_create_time) or int(root_proc.pid) != int(proc.pid):
                raise ValueError("Popen root identity is malformed")
            root_identity = (int(proc.pid), root_create_time)
            if proc.poll() is not None:
                raise ProcessTreeObservationError(
                    "root_exited_during_identity_capture", proc.pid, proc.pid, 0, [],
                    RuntimeError("direct child exited while its process identity was being pinned"))
        except Exception as exc:
            rss_sampling_complete = False
            if isinstance(exc, ProcessTreeObservationError):
                rss_observation_errors.append(dict(exc.evidence))
            else:
                rss_observation_errors.append({
                    "scope": "root_identity_capture", "root_pid": int(proc.pid),
                    "process_pid": int(proc.pid), "partial_rss_bytes_not_used_for_gate": 0,
                    "observed_process_identities": [], "error_type": type(exc).__name__, "error": str(exc),
                })
            stop_reason = "process_tree_observation_incomplete"
            cleanup = terminate_tree(proc.pid, cleanup_grace, expected_root_identity=root_identity)
        def record_confirmed_leader_exit(exit_code: int, trigger: str,
                                         root_lookup: dict[str, object] | None = None) -> None:
            nonlocal leader_exit_check, leader_exit_observation, rss_sampling_complete
            nonlocal stop_reason, cleanup
            if root_identity is None:
                exit_check = {
                    "active_descendants": [],
                    "unknown_descendants": [{"stage": "pinned_root_identity_missing",
                                              "error_type": "RootIdentityMissing"}],
                    "all_previously_observed_descendants_checked": False,
                    "pinned_root_identity_verified": False,
                    "process_table_snapshot_complete": False,
                    "unobserved_descendant_identity_count": 0,
                    "observed_process_identities": [],
                }
            else:
                exit_check = audit_descendants_after_leader_exit(identities, root_identity)
            leader_exit_check = exit_check
            leader_exit_observation = {
                "schema": "mms-leader-exit-observation-v1",
                "mode": trigger,
                "leader_exit_code": exit_code,
                "root_identity": None if root_identity is None else [root_identity[0], root_identity[1]],
                "completed_root_matched_samples_before_exit": rss_complete_sample_count,
                "root_lookup": root_lookup,
                "descendant_audit": exit_check,
            }
            identities.extend(exit_check.get("observed_process_identities", []))
            if exit_check["active_descendants"]:
                stop_reason = "leader_exited_with_live_descendants"
                rss_sampling_complete = False
                rss_observation_errors.append({
                    "scope": "leader_exit_with_live_descendants", "root_pid": int(proc.pid),
                    "root_identity": None if root_identity is None else list(root_identity),
                    "active_descendants": exit_check["active_descendants"],
                    "unknown_descendants": exit_check["unknown_descendants"],
                })
                cleanup = terminate_tree(proc.pid, cleanup_grace, identities, root_identity)
            elif rss_complete_sample_count == 0 or exit_check["unknown_descendants"] or \
                    exit_check["process_table_snapshot_complete"] is not True or \
                    exit_check["all_previously_observed_descendants_checked"] is not True or \
                    exit_check["pinned_root_identity_verified"] is not True:
                stop_reason = "process_tree_observation_incomplete"
                rss_sampling_complete = False
                rss_observation_errors.append({
                    "scope": "post_leader_descendant_audit", "root_pid": int(proc.pid),
                    "root_identity": None if root_identity is None else list(root_identity),
                    "complete_root_matched_samples_before_exit": rss_complete_sample_count,
                    "unknown_descendants": exit_check["unknown_descendants"],
                })
                cleanup = terminate_tree(proc.pid, cleanup_grace, identities, root_identity)
            else:
                leader_exit_observation["status"] = "complete_no_residual_descendants"

        while stop_reason == "exited":
            leader_exit_code = proc.poll()
            if leader_exit_code is not None:
                # Popen has already confirmed exit. A further root RSS lookup
                # can race with process teardown and cannot replace the final
                # identity/descendant audit below.
                record_confirmed_leader_exit(leader_exit_code, "popen_exit_before_rss_sample")
                break
            try:
                rss, observed = live_tree_bytes(proc.pid, root_identity)
            except Exception as exc:
                late_exit_code = proc.poll()
                root_missing_after_confirmed_exit = (
                    late_exit_code is not None and root_identity is not None and
                    rss_complete_sample_count > 0 and isinstance(exc, ProcessTreeObservationError) and
                    exc.evidence.get("scope") == "root_process" and
                    exc.evidence.get("root_pid") == int(proc.pid) and
                    exc.evidence.get("process_pid") == int(proc.pid) and
                    exc.evidence.get("error_type") == "NoSuchProcess")
                if root_missing_after_confirmed_exit:
                    record_confirmed_leader_exit(late_exit_code, "popen_exit_during_rss_race",
                                                 dict(exc.evidence))
                    break
                rss_sampling_complete = False
                if isinstance(exc, ProcessTreeObservationError):
                    rss_observation_errors.append(dict(exc.evidence))
                    identities.extend(exc.evidence.get("observed_process_identities", []))
                else:
                    rss_observation_errors.append({
                        "scope": "unexpected_monitor_exception", "root_pid": int(proc.pid),
                        "error_type": type(exc).__name__, "error": str(exc),
                    })
                stop_reason = "process_tree_observation_incomplete"
                cleanup = terminate_tree(proc.pid, cleanup_grace, identities, root_identity)
                break
            rss_complete_sample_count += 1
            peak = max(peak, rss)
            identities.extend(observed)
            elapsed = time.monotonic() - process_started
            leader_exit_code = proc.poll()
            if leader_exit_code is not None:
                record_confirmed_leader_exit(leader_exit_code, "popen_exit_after_complete_rss_sample")
                break
            if rss > memory_limit:
                stop_reason = "working_set_limit"
                cleanup = terminate_tree(proc.pid, cleanup_grace, identities, root_identity)
                break
            if elapsed >= effective_live_limit:
                stop_reason = ("aggregate_wall_timeout" if effective_live_limit < limit_s
                               else "wall_timeout")
                cleanup = terminate_tree(proc.pid, cleanup_grace, identities, root_identity)
                break
            time.sleep(min(PROCESS_POLL_INTERVAL_SECONDS,
                           max(0.0, effective_live_limit - elapsed)))
        if cleanup is not None and proc.poll() is None:
            # The cleanup helper has already sent terminate/kill and exhausted
            # its one shared bounded wait; never add a second unbounded wait.
            try:
                proc.kill()
            except OSError:
                pass
            if proc.poll() is None:
                cleanup["termination_confirmed"] = False
                remaining_pids = set(cleanup.get("remaining_process_pids", []))
                remaining_pids.add(proc.pid)
                cleanup["remaining_process_pids"] = sorted(remaining_pids)
            else:
                cleanup["direct_child_exit_observed_after_kill"] = True
                cleanup["termination_confirmed"] = (
                    cleanup.get("termination_confirmed") is True and
                    not bool(cleanup.get("remaining_process_pids")))
        process_ended = time.monotonic()
        exit_code = proc.poll()
    child_wall_seconds = process_ended - process_started
    aggregate_overrun = max(0.0, child_wall_seconds - aggregate_remaining)
    cleanup_elapsed = 0.0 if cleanup is None else float(cleanup["elapsed_seconds"])
    cleanup_overrun = max(0.0, cleanup_elapsed - cleanup_grace)
    cleanup_unconfirmed = cleanup is not None and cleanup.get("termination_confirmed") is not True
    if stop_reason == "exited" and child_wall_seconds > effective_live_limit:
        stop_reason = ("aggregate_wall_timeout" if effective_live_limit < limit_s else "wall_timeout")
    if aggregate_overrun > 0 or cleanup_overrun > 0:
        stop_reason = "aggregate_cleanup_overrun"
    elif cleanup_unconfirmed:
        stop_reason = "cleanup_unconfirmed"
    elapsed_stage = time.monotonic() - stage_started
    stdout_bytes = stdout_path.read_bytes()
    stderr_bytes = stderr_path.read_bytes()
    unique = {(int(x["pid"]), float(x["create_time"])): x for x in identities}
    return {
        "schema": "mms-replay-recorded-process-v2", "command": command, "cwd": str(cwd),
        "pid": proc.pid, "started_utc": started_utc,
        "root_process_identity": None if root_identity is None else {
            "pid": root_identity[0], "create_time": root_identity[1]},
        "leader_exit_descendant_check": leader_exit_check,
        "leader_exit_observation": leader_exit_observation,
        "elapsed_seconds": elapsed_stage, "child_wall_seconds": child_wall_seconds,
        "exit_code": exit_code, "stop_reason": stop_reason,
        "aggregate_child_wall_remaining_before_seconds": aggregate_remaining,
        "aggregate_child_wall_overrun_seconds": aggregate_overrun,
        "per_stage_live_limit_seconds": effective_live_limit,
        "cleanup_grace_seconds": cleanup_grace, "cleanup": cleanup,
        "peak_sampled_process_tree_working_set_bytes": peak,
        "rss_sampling_complete": rss_sampling_complete,
        "rss_complete_sample_count": rss_complete_sample_count,
        "rss_observation_errors": rss_observation_errors,
        "memory_limit_bytes": memory_limit, "wall_limit_seconds": limit_s,
        "observed_process_identities": list(unique.values()),
        "terminated_owned_processes": [] if cleanup is None else cleanup["owned_process_identities"],
        "stdout": {"path": str(stdout_path), "bytes": len(stdout_bytes), "sha256": hashlib.sha256(stdout_bytes).hexdigest()},
        "stderr": {"path": str(stderr_path), "bytes": len(stderr_bytes), "sha256": hashlib.sha256(stderr_bytes).hexdigest()},
        "memory_scope": "only complete enumerated-tree RSS samples are compared with the cap; sampling is not a continuous operating-system hard limit",
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


def _compact_julia_function(source: str, function_name: str) -> str:
    signature = f"function {function_name}"
    start = source.find(signature)
    if start < 0:
        raise ValueError(f"required Julia function is missing: {function_name}")
    next_function = source.find("\nfunction ", start + len(signature))
    body = source[start:] if next_function < 0 else source[start:next_function]
    uncommented = "\n".join(line.split("#", 1)[0] for line in body.splitlines())
    return re.sub(r"\s+", "", uncommented)


def check_hydration_contract_text(julia_source: str) -> None:
    """Fail closed unless the controller's real producer uses the V18 observe/rebuild path."""
    required = (
        "function hydration_diff!(numeric_type_differences, semantic_differences,",
        "representation_differences, parsed, exact, path)",
        "function hydration_rebuild_result(body, wire, expected_result_hash, context)",
        "function hydration_case_from_body(body_case, index, declaration)",
        "function hydration_restore_from_template(value, template, path)",
        "function hydration_declaration_from_body(body_declaration, expected_declaration)",
        "function hydration_current_input(value, path, declaration)",
        "function hydration_geometry_receipt(value, path, declaration)",
        "function hydration_execution_from_body(value, declaration)",
        "S.SpatialMultiRegionCaseV4(case_values..., case_hash)",
        "S.SpatialCurrentInputV4(",
        "S.SpatialManufacturedGeometryReceiptV1(",
        "S.SpatialManufacturedNumericalResultV1(",
        "S._smr_declaration(context)",
        "hydration_current_input(raw, field_path, declaration)",
        "hydration_restore_semantic_tree(value.current_closure, path * \".current_closure\", declaration)",
        "typeof(value) == typeof(template)",
        "no observed body/typed mismatch; exact-body reconstruction is not authorized",
        "observe-first mismatch root falls outside saved V4 result schema",
        "S._smr_bounded_identity_v1()",
        "S.spatial_manufactured_provider_identity_v1()",
        "S._smm_enclosure_v1(declaration.source.input)",
        "typed_value == item.body_value",
        "Set((item.typed_type, item.body_type)) == Set((\"Float64\", \"Int64\"))",
        "observe-first found an unproven typed/body value, key, or shape difference",
        "canonical_json(top) * \"\\n\" == wire",
        "S.validate_spatial_manufactured_result_v1(context, result)",
        "M.result_tests(context, result, out)",
    )
    missing = [needle for needle in required if needle not in julia_source]
    if missing:
        raise ValueError("V18 Julia hydration path is missing required schema/gate bindings: " + ", ".join(missing))
    if "hydration_restore_exact_numeric_tokens" in julia_source:
        raise ValueError("V18 must use exact body/schema reconstruction, not the V11 broad recursive numeric copier")
    observe = julia_source.index('new_json(joinpath(out, "hydration_observation_initial.json")')
    observed_type_check = julia_source.index("observed isa S.SpatialManufacturedNumericalResultV1 || error(\"observed result has wrong concrete type\")")
    rebuild = julia_source.index("result = hydration_rebuild_result(body, wire, expected_result_hash, context)")
    validator = julia_source.index("S.validate_spatial_manufactured_result_v1(context, result)")
    consumer = julia_source.index("M.result_tests(context, result, out)")
    if not observe < observed_type_check < rebuild < validator < consumer:
        raise ValueError("V18 observe/rebuild/full-validator/consumer call order changed")
    if "S.SpatialMultiRegionCaseV4" not in julia_source or "S.SpatialArtifactV4" not in julia_source:
        raise ValueError("V18 nested V4 schema constructors are missing")
    diff_body = _compact_julia_function(julia_source, "hydration_diff!(")
    fail_closed_guards = {
        "unequal numeric values": r"ifparsed==exacttypeof\(parsed\)==typeof\(exact\)\|\|push!\(numeric_type_differences,.*?typeof\(parsed\)==typeof\(exact\)&&!isequal\(parsed,exact\)&&push!\(semantic_differences,path\)elsepush!\(semantic_differences,path\)endreturn",
        "object key sets": r"ifparsed_keys!=exact_keyspush!\(semantic_differences,path\*\"\.<keys>\"\)returnend",
        "sequence lengths": r"length\(parsed\)==length\(exact\)\|\|\(push!\(semantic_differences,path\*\"\.<length>\"\);return\)",
        "sequence shapes": r"parsed_shape==exact_shape\|\|\(push!\(semantic_differences,path\*\"\.<shape>\"\);return\)",
    }
    for label, guard in fail_closed_guards.items():
        if re.search(guard, diff_body) is None:
            raise ValueError(f"V18 hydration diff function lost its fail-closed guard for {label}")

    case_restore = _compact_julia_function(julia_source, "hydration_case_from_body(")
    case_id_guard = (
        r"(?:if|elseif)key==:case_id"
        r"rawisaAbstractString\|\|error\(.*?\)"
        r"index<=length\(declaration\.cases\)\|\|error\(.*?\)"
        r"expected_case_id=declaration\.cases\[index\]\.case_id"
        r"raw==expected_case_id\|\|error\(.*?\)"
        r"returnString\(raw\)"
    )
    if re.search(case_id_guard, case_restore) is None:
        raise ValueError("V18 case_id hydration must preserve an exact declaration-matched AbstractString")
    generic_restore = _compact_julia_function(julia_source, "hydration_restore_from_template(")
    input_restore = _compact_julia_function(julia_source, "hydration_restore_manufactured_input(")
    dispatch = (r"iftemplateisaS\.SpatialManufacturedNumericalInputV1"
                r"returnhydration_restore_manufactured_input\(value,template,path\)"
                r"elseiftemplateisaDigest256")
    if re.search(dispatch, generic_restore) is None:
        raise ValueError("V18 template dispatcher does not route manufactured input through its exact V4 schema")
    input_guards = {
        "concrete input method": r"functionhydration_restore_manufactured_input\(value,template::S\.SpatialManufacturedNumericalInputV1,path\)",
        "named-tuple input body": r"valueisaNamedTuple\|\|error\(.*?\)",
        "field names from concrete schema": r"fields=fieldnames\(S\.SpatialManufacturedNumericalInputV1\)",
        "exact input field-set check": r"Set\(String\.\(keys\(value\)\)\)==Set\(String\.\(fields\)\)\|\|error\(.*?\)",
        "recursive reconstruction against typed template": r"values=Tuple\(hydration_restore_from_template\(getproperty\(value,field\),getfield\(template,field\),.*?\)forfieldinfields\)",
        "concrete V4 input constructor": r"restored=S\.SpatialManufacturedNumericalInputV1\(values\.\.\.\)",
        "strict V4 input validator": r"S\.validate_spatial_manufactured_input_v1\(restored\)===true\|\|error\(.*?\)",
        "exact semantic-body round trip": r"canonical_json\(S\.semantic_view\(restored\)\)==canonical_json\(value\)\|\|error\(.*?\)",
    }
    missing_input_guards = [label for label, pattern in input_guards.items()
                            if re.search(pattern, input_restore) is None]
    if missing_input_guards:
        raise ValueError("V18 exact manufactured-input hydration contract is missing: " +
                         ", ".join(missing_input_guards))
    ordered_guards = (
        "Set(String.(keys(value))) == Set(String.(fields))",
        "values = Tuple(hydration_restore_from_template(",
        "restored = S.SpatialManufacturedNumericalInputV1(values...)",
        "S.validate_spatial_manufactured_input_v1(restored) === true",
        "canonical_json(S.semantic_view(restored)) == canonical_json(value)",
    )
    guard_offsets = [input_restore.find(re.sub(r"\s+", "", item)) for item in ordered_guards]
    if any(offset < 0 for offset in guard_offsets) or guard_offsets != sorted(guard_offsets):
        raise ValueError("V18 manufactured-input hydration validation/reconstruction order changed")

    mapping_body = _compact_julia_function(julia_source, "hydration_declared_mapping!(")
    schema_body = _compact_julia_function(julia_source, "hydration_declared_representation_allowlist!(")
    rebuild_body = _compact_julia_function(julia_source, "result_from_saved_wire(")
    typed_rebuild_body = _compact_julia_function(julia_source, "hydration_rebuild_result(")
    schema_guards = {
        "exact typed NamedTuple field order": "typed_order==declared_order||error(",
        "exact saved-body key set": "Set(keys(exact_pairs))==Set(declared_order)||error(",
        "canonical body key order derivation": "canonical_body_order=sort!(collect(keys(exact_pairs)))",
    }
    missing_schema_guards = [label for label, needle in schema_guards.items() if needle not in mapping_body]
    if missing_schema_guards:
        raise ValueError("V18 declared mapping lost a fail-closed schema guard for " + ", ".join(missing_schema_guards))
    namedtuple_branch = mapping_body.split("elseifexact_valueisaNamedTuple", 1)
    if len(namedtuple_branch) != 2:
        raise ValueError("V18 declared mapping has no exact saved NamedTuple representation branch")
    namedtuple_branch = namedtuple_branch[1].split('elseerror("exactbodymappinghasanunsupportedrepresentationat$(path)")', 1)[0]
    namedtuple_guards = (
        "canonical_body_order=sort!(copy(declared_order))",
        "exact_order=String.(keys(exact_value))",
        'exact_order==canonical_body_order||error("exactsavedNamedTuplekeyorderdiffersfromcanonicalV4schemaorderat$(path)")',
        'iftyped_order!=exact_orderhydration_push_declared_representation!(rows,path,"object_key_order",declared_type,typed_order,exact_order)end',
    )
    missing_namedtuple_guards = [needle for needle in namedtuple_guards if needle not in namedtuple_branch]
    if missing_namedtuple_guards:
        raise ValueError("V18 NamedTuple parser-order mapping lost its exact canonical/schema guard or row: " +
                         ", ".join(missing_namedtuple_guards))
    if "String.(keys(exact_value))==typed_order" in namedtuple_branch:
        raise ValueError("V18 cannot require canonical parser order to equal typed declaration order")
    allow_guards = {
        "declared Tuple field path": "declared_type===Tuple||declared_type<:Tuple",
        "exact Tuple/body shape": "typed_shape==exact_shape||error(",
        "declared NamedTuple field path": "declared_type===NamedTuple||declared_type<:NamedTuple",
        "declared concrete V4 struct path": "declared_typeisaDataType&&isconcretetype(declared_type)&&isstructtype(declared_type)",
        "Tuple element types from concrete tuple declaration": "fieldtype(typeof(typed_value),index)",
        "struct child types from V4 declaration": "fieldtype(declared_type,index)",
    }
    missing_allow_guards = [label for label, needle in allow_guards.items() if needle not in schema_body]
    if missing_allow_guards:
        raise ValueError("V18 representation allowlist lost declaration-derived guard for " +
                         ", ".join(missing_allow_guards))
    after_contract = {
        "typed result declaration order": "Tuple(keys(result_body))==result_fields||error(",
        "saved exact result key set": "Set(keys(body_pairs_after))==Set(String.(result_fields))||error(",
        "after representation requires exact declared path membership":
            "all(item->(item.path,item.kind)inallowed_pairs,after_representation)||error(",
        "after semantic and numeric differences are rejected":
            "isempty(after_semantic)&&isempty(after_numeric)||error(",
    }
    missing_after_guards = [label for label, needle in after_contract.items() if needle not in rebuild_body]
    if missing_after_guards:
        raise ValueError("V18 after-reconstruction gate lost a strict condition for " + ", ".join(missing_after_guards))
    typed_rebuild_guards = {
        "exact canonical typed hash": "string(S.canonical_hash(top))==expected_result_hash||error(",
        "exact canonical wire": 'canonical_json(top)*"\\n"==wire||error(',
    }
    missing_typed_rebuild = [label for label, needle in typed_rebuild_guards.items()
                             if needle not in typed_rebuild_body]
    if missing_typed_rebuild:
        raise ValueError("V18 schema reconstruction lost a strict hash/wire condition for " +
                         ", ".join(missing_typed_rebuild))
    after_observation = rebuild_body.find('new_json(joinpath(out,"hydration_observation_reconstruction.json"),after_observation)')
    allowlist_call = rebuild_body.find("hydration_declared_representation_allowlist!(declared_allowlist,")
    allowlist_write = rebuild_body.find('new_json(joinpath(out,"hydration_declared_schema_allowlist.json"),')
    after_gate = rebuild_body.find("all(item->(item.path,item.kind)inallowed_pairs,after_representation)||error(")
    if min(after_observation, allowlist_call, allowlist_write, after_gate) < 0 or not (
            after_observation < allowlist_call < allowlist_write < after_gate):
        raise ValueError("V18 must persist the raw after observation before deriving and applying its V4 schema allowlist")
    if "Set((item.path,item.kind)foritemininitial_representation)" in rebuild_body:
        raise ValueError("V18 cannot authorize representation differences solely by the initial mismatch set")


def verify_hydration_contract_text(julia_source: str) -> None:
    check_hydration_contract_text(julia_source)


def verify_v17_actual_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the immutable V17 order-only hydration failure and its saved after observation."""
    if not isinstance(evidence, dict):
        raise ValueError("V17 actual failure reference is missing")
    protocol_ref = evidence.get("protocol")
    if not isinstance(protocol_ref, dict):
        raise ValueError("V17 protocol reference is malformed")
    protocol_path = verify_bound_sha256(root, protocol_ref.get("path"), protocol_ref.get("sha256"),
                                        "V17 replay protocol")
    if protocol_path.stat().st_size != protocol_ref.get("bytes"):
        raise ValueError("V17 replay protocol byte count changed")
    parent = json.loads(protocol_path.read_text(encoding="utf-8"))
    if (parent.get("schema"), parent.get("version"), parent.get("classification"),
            parent.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v17", 17, "test_only_continuation", False):
        raise ValueError("V17 frozen protocol classification or runtime grant changed")
    runtime_root_rel = evidence.get("runtime_root")
    if parent.get("output_leaf") != runtime_root_rel:
        raise ValueError("V17 runtime root differs from its frozen protocol output_leaf")
    sources = evidence.get("source_files")
    if not isinstance(sources, list) or len(sources) != 3:
        raise ValueError("V17 source inventory is malformed")
    verify_inventory(sources)
    if sources != parent.get("owned_source_files"):
        raise ValueError("V17 source inventory differs from its frozen protocol")
    runtime_root = checked_path(root, runtime_root_rel)
    entries = evidence.get("runtime_entries")
    if not isinstance(entries, list) or len(entries) != 20:
        raise ValueError("V17 complete runtime failure inventory is missing")
    verify_inventory(entries)
    if file_inventory(runtime_root) != entries:
        raise ValueError("V17 runtime failure leaf inventory changed")

    def read_runtime_ref(name: str) -> tuple[pathlib.Path, dict[str, object]]:
        ref = evidence.get(name)
        if not isinstance(ref, dict):
            raise ValueError(f"V17 {name} receipt reference is malformed")
        path = verify_bound_sha256(root, ref.get("path"), ref.get("sha256"), f"V17 {name}")
        if path.stat().st_size != ref.get("bytes") or not any(item.get("path") == ref.get("path") for item in entries):
            raise ValueError(f"V17 {name} is outside its frozen runtime inventory")
        return path, json.loads(path.read_text(encoding="utf-8"))

    expected_paths = {
        "final": runtime_root.relative_to(root).as_posix() + "/final.json",
        "process": runtime_root.relative_to(root).as_posix() + "/producer_process.json",
        "failure": runtime_root.relative_to(root).as_posix() + "/producer_process/numerical/producer_failure.json",
        "observation": runtime_root.relative_to(root).as_posix() + "/producer_process/numerical/hydration_observation_reconstruction.json",
    }
    for name, expected_path in expected_paths.items():
        ref = evidence.get(name)
        if not isinstance(ref, dict) or ref.get("path") != expected_path:
            raise ValueError(f"V17 {name} path differs from its exact frozen runtime location")
    _, final = read_runtime_ref("final")
    _, process = read_runtime_ref("process")
    _, failure = read_runtime_ref("failure")
    _, observation = read_runtime_ref("observation")
    if (final.get("schema"), final.get("classification"), final.get("controller_exit_code"),
            final.get("software_complete"), final.get("numerical_status"), final.get("solver_exit_code"),
            final.get("stopping_reason"), final.get("authority"), final.get("physical_validation"),
            final.get("nonlinear_solves"), final.get("inputs_unchanged"),
            final.get("producer_tree_comparison_status"), final.get("producer_tree_unchanged"),
            final.get("formal_candidate_credit")) != (
            "mms-replay-only-controller-final-v3", "replay_hydration_unsupported", 72, False,
            "fail", 2, "stationary_nonzero_residual", "no_publish", "unsupported", 0, True,
            "not_reached", None, False):
        raise ValueError("V17 replay/hydration failure changed original solver-fail/no-publish semantics")
    if (process.get("schema"), process.get("exit_code"), process.get("stop_reason"),
            process.get("rss_complete_sample_count"), process.get("rss_sampling_complete"),
            process.get("peak_sampled_process_tree_working_set_bytes")) != (
            "mms-replay-recorded-process-v2", 72, "exited", 844, True, 1112580096):
        raise ValueError("V17 producer runtime/complete-sample receipt changed")
    if process.get("memory_limit_bytes") != 2147483648 or process.get("per_stage_live_limit_seconds") != 480.0:
        raise ValueError("V17 stage resource limits changed")
    if process.get("rss_observation_errors") != []:
        raise ValueError("V17 producer RSS sampling includes an unknown observation")
    if (failure.get("classification"), failure.get("phase"), failure.get("hydration_stage"),
            failure.get("error"), failure.get("solver_exit_code"), failure.get("numerical_status"),
            failure.get("authority")) != (
            "replay_hydration_unsupported", "typed_result_hydration", "schema_directed_reconstruction",
            "noncanonical NamedTuple field order differs from the V4 schema at declaration",
            2, "fail", "no_publish"):
        raise ValueError("V17 actual NamedTuple-order hydration failure signature changed")
    if (observation.get("schema"), observation.get("phase"), len(observation.get("mismatch_roots", [])),
            len(observation.get("numeric_type_differences", [])), len(observation.get("semantic_differences", [])),
            len(observation.get("representation_differences", [])), len(observation.get("reconstruction_paths", []))) != (
            "mms-replay-only-hydration-observation-v2", "after_schema_directed_reconstruction_before_allowlist",
            0, 0, 0, 110, 153):
        raise ValueError("V17 persisted after-observation counts or phase changed")
    if any(item.get("kind") != "object_key_order" for item in observation["representation_differences"]):
        raise ValueError("V17 after-observation contains a non-order representation difference")
    declaration = next((item for item in observation.get("fields", []) if item.get("field") == "declaration"), None)
    if not isinstance(declaration, dict) or declaration.get("canonical_equal") is not True:
        raise ValueError("V17 declaration after-observation no longer proves canonical equality")
    typed = declaration.get("typed", {})
    body = declaration.get("body", {})
    if (typed.get("canonical_sha256"), typed.get("canonical_bytes")) != (
            body.get("canonical_sha256"), body.get("canonical_bytes")):
        raise ValueError("V17 declaration typed/body canonical fingerprints differ")
    if not body.get("concrete_type", "").startswith("@NamedTuple{applicability::"):
        raise ValueError("V17 declaration body no longer records canonical alphabetical NamedTuple order")
    leader_audit = process.get("leader_exit_observation", {}).get("descendant_audit", {})
    if leader_audit.get("process_table_snapshot_complete") is not True:
        raise ValueError("V17 leader-exit descendant audit is no longer complete")
    if (runtime_root / "consumer_process").exists() or (runtime_root / "producer_process/consumer").exists():
        raise ValueError("V17 actual failure unexpectedly started the consumer")
    if (runtime_root / "producer_process/numerical/producer_complete.json").exists():
        raise ValueError("V17 actual failure unexpectedly has producer completion")

    static = evidence.get("static_leaf")
    if not isinstance(static, dict):
        raise ValueError("V17 static evidence leaf reference is malformed")
    static_root = checked_path(root, static.get("path"))
    static_entries = static.get("entries")
    if not isinstance(static_entries, list) or len(static_entries) != 9:
        raise ValueError("V17 static evidence inventory is malformed")
    verify_inventory(static_entries)
    if file_inventory(static_root) != static_entries:
        raise ValueError("V17 static evidence leaf inventory changed")
    receipt_path = verify_bound_sha256(root, static.get("receipt_path"), static.get("receipt_sha256"),
                                       "V17 static receipt")
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if (receipt.get("schema"), receipt.get("classification"), receipt.get("julia_started"),
            receipt.get("producer_started"), receipt.get("consumer_started"), receipt.get("output_leaf_created"),
            receipt.get("static_test", {}).get("exit_code"), receipt.get("static_test", {}).get("test_count")) != (
            "mms-replay-only-continuation-v17-static-evidence-v1", "test_only_continuation_static_only",
            False, False, False, False, 0, 43):
        raise ValueError("V17 static test receipt or no-runtime boundary changed")
    if receipt.get("protocol", {}).get("sha256") != protocol_ref.get("sha256"):
        raise ValueError("V17 static receipt is not bound to the frozen V17 protocol")
    return {"protocol_path": protocol_path, "protocol": parent, "runtime_root": runtime_root,
            "runtime_entries": entries, "final": final, "process": process, "failure": failure,
            "observation": observation, "source_files": sources, "static_root": static_root,
            "static_entries": static_entries, "static_receipt": receipt}


def verify_pre_output_contract(protocol_path: pathlib.Path | str, expected_protocol_sha: str,
                               output_arg: pathlib.Path | str) -> dict[str, object]:
    """Run main's complete read-only pre-output validation chain and return its frozen inputs."""
    protocol_path = pathlib.Path(protocol_path).resolve()
    if protocol_path != DEFAULT_PROTOCOL.resolve():
        raise ValueError("only the frozen replay_protocol_v18.json is accepted")
    protocol_wire = protocol_path.read_bytes()
    actual_protocol_sha = hashlib.sha256(protocol_wire).hexdigest()
    if actual_protocol_sha.lower() != expected_protocol_sha.lower():
        raise ValueError("replay protocol SHA does not match --protocol-sha256")
    protocol = json.loads(protocol_wire)
    if protocol.get("schema") != "mms-replay-only-continuation-protocol-v18" or protocol.get("classification") != "test_only_continuation":
        raise ValueError("unsupported replay protocol schema or classification")
    if protocol.get("runtime_grant") is not False:
        raise ValueError("protocol runtime_grant must remain false; root serial-slot grant is a command argument")
    controller_overhead_contract = validate_controller_overhead_contract(protocol)
    aggregate_wall_contract = validate_aggregate_child_wall_contract(protocol)
    process_tree_monitor_contract = validate_process_tree_monitor_contract(protocol)
    output = resolve_output_target(ROOT, output_arg, protocol.get("output_leaf"))
    if output.exists():
        raise FileExistsError(f"preserve existing replay-only output: {output}")
    verify_child_command_contract(protocol)
    context_builder_contract = verify_context_builder_contract(ROOT, protocol)
    julia_source_path = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV18/replay_staged_v18.jl"
    verify_hydration_contract_text(julia_source_path.read_text(encoding="utf-8"))
    v8_failure = verify_v8_context_rebuild_failure(ROOT, protocol)
    v9_ancestry = verify_v9_static_no_go_ancestry(ROOT, protocol)

    v7_ancestry = verify_v7_no_go_ancestry(
        ROOT, protocol.get("parent_v7_protocol"), protocol.get("parent_v7_independent_review"))
    v14_actual_failure = verify_v14_actual_failure_ancestry(
        ROOT, protocol.get("parent_v14_actual_failure"))
    v14_postrun_audit = verify_v14_postrun_audit(
        ROOT, protocol.get("parent_v14_postrun_audit"))
    v15_actual_failure = verify_v15_actual_failure(
        ROOT, protocol.get("parent_v15_actual_failure"))
    v16_actual_failure = verify_v16_actual_failure(
        ROOT, protocol.get("parent_v16_actual_failure"))
    v17_actual_failure = verify_v17_actual_failure(
        ROOT, protocol.get("parent_v17_actual_failure"))

    runtime = protocol["runtime"]
    if str(pathlib.Path(sys.executable).resolve()) != str(pathlib.Path(runtime["python_executable"]).resolve()):
        raise ValueError("Python executable differs from the frozen runtime")
    if sys.version.split()[0] != runtime["python_version"] or psutil.__version__ != runtime["psutil_version"]:
        raise ValueError("Python or psutil version differs from the frozen runtime")

    source_files = protocol["owned_source_files"]
    verify_inventory(source_files)
    evidence_docs = protocol["owned_evidence_docs"]
    verify_inventory(evidence_docs)
    parent_v6 = protocol["parent_v6_protocol"]
    v6_review = protocol["parent_v6_independent_review"]
    v6_attempt = protocol["parent_v6_root_attempt"]
    v6_postrun_review = protocol["parent_v6_postrun_scopefix_review"]
    v6_failure = verify_v6_root_preflight_failure(ROOT, parent_v6, v6_review, v6_attempt, v6_postrun_review)

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
    v10_replay = verify_v10_replay_failure(
        ROOT, protocol.get("parent_v10_actual_replay_failure"),
        protocol.get("parent_v10_independent_postrun_review"))
    v11_failure = verify_v11_actual_failure(
        ROOT, protocol.get("parent_v11_actual_failure"), protocol.get("parent_v11_diagnosis"))
    v12_no_go = verify_v12_static_no_go(ROOT, protocol.get("parent_v12_independent_no_go_review"))
    v13_parent = verify_v13_static_candidate_and_no_go(ROOT, protocol.get("parent_v13_static_candidate_and_no_go"))
    timeout_paths = verified_timeout["paths"]
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
    parent_v7 = protocol["parent_v7_protocol"]
    v7_protocol_path = v7_ancestry["protocol_path"]
    all_inputs[parent_v7["path"]] = {"path": parent_v7["path"],
        "bytes": v7_protocol_path.stat().st_size, "sha256": parent_v7["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in protocol["v3_runtime_failure"]["entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v10_replay["runtime_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v11_failure["input_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v12_no_go["input_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v13_parent["input_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v14_actual_failure["input_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v14_postrun_audit["input_entries"]})
    v17_ref = protocol["parent_v17_actual_failure"]
    v17_protocol_ref = v17_ref["protocol"]
    v17_protocol_path = v17_actual_failure["protocol_path"]
    all_inputs[v17_protocol_ref["path"]] = {"path": v17_protocol_ref["path"],
        "bytes": v17_protocol_path.stat().st_size, "sha256": v17_protocol_ref["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v17_ref["source_files"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v17_ref["runtime_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v17_ref["static_leaf"]["entries"]})
    v15_ref = protocol["parent_v15_actual_failure"]
    v15_protocol_ref = v15_ref["protocol"]
    v15_protocol_path = v15_actual_failure["protocol_path"]
    all_inputs[v15_protocol_ref["path"]] = {"path": v15_protocol_ref["path"],
        "bytes": v15_protocol_path.stat().st_size, "sha256": v15_protocol_ref["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v15_ref["source_files"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v15_ref["runtime_entries"]})
    review_ref = v15_ref["independent_review"]
    all_inputs[review_ref["path"]] = {"path": review_ref["path"], "bytes": review_ref["bytes"],
        "sha256": review_ref["sha256"]}
    for item in (review_ref["report"], review_ref["manifest"]):
        all_inputs[item["path"]] = {"path": item["path"], "bytes": item["bytes"], "sha256": item["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in protocol["parent_v10_actual_replay_failure"]["diagnosis"]["entries"]})
    v10_protocol_entry = v10_replay["protocol_entry"]
    all_inputs[v10_protocol_entry["path"]] = v10_protocol_entry
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v10_replay["source_entries"]})
    for entry in v10_replay["review_entries"]:
        all_inputs[entry["path"]] = {"path": entry["path"], "bytes": entry["bytes"], "sha256": entry["sha256"]}
    for path in (v10_replay["review_report_path"], v10_replay["review_manifest_path"],
                 v10_replay["review_commands_path"], v10_replay["review_audit_exit_path"],
                 v10_replay["review_audit_stdout_path"], v10_replay["review_audit_stderr_path"],
                 *v10_replay["observation_support_paths"]):
        rel = path.relative_to(ROOT).as_posix()
        all_inputs[rel] = {"path": rel, "bytes": path.stat().st_size, "sha256": digest(path)}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in source_files})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]} for x in evidence_docs})
    for path in (context_builder_contract["helper_path"], context_builder_contract["candidate_source_path"]):
        all_inputs[path.relative_to(ROOT).as_posix()] = {
            "path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path)}
    parent_v8 = protocol["parent_v8_protocol"]
    v8_protocol_path = v8_failure["protocol_path"]
    all_inputs[parent_v8["path"]] = {"path": parent_v8["path"],
        "bytes": v8_protocol_path.stat().st_size, "sha256": parent_v8["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v8_failure["attempt_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v8_failure["snapshot_entries"]})
    parent_v9 = protocol["parent_v9_protocol"]
    v9_protocol_path = v9_ancestry["protocol_path"]
    all_inputs[parent_v9["path"]] = {"path": parent_v9["path"],
        "bytes": v9_protocol_path.stat().st_size, "sha256": parent_v9["sha256"]}
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in json.loads(v9_protocol_path.read_text(encoding="utf-8"))["owned_source_files"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v9_ancestry["tester_entries"]})
    all_inputs.update({x["path"]: {"path": x["path"], "bytes": x["bytes"], "sha256": x["sha256"]}
                       for x in v9_ancestry["review_entries"]})
    for path in (v9_ancestry["static_receipt_path"], v9_ancestry["static_checksums_path"],
                 v9_ancestry["static_commands_path"], *v9_ancestry["static_raw_paths"],
                 v9_ancestry["tester_receipt_path"], v9_ancestry["tester_sums_path"],
                 v9_ancestry["review_report_path"],
                 v9_ancestry["review_manifest_path"], v9_ancestry["review_commands_path"],
                 v9_ancestry["review_receipt_path"], v9_ancestry["input_inventory_path"],
                 v9_ancestry["root_decision_path"]):
        rel = path.relative_to(ROOT).as_posix()
        all_inputs[rel] = {"path": rel, "bytes": path.stat().st_size, "sha256": digest(path)}
    for key in V10_TIMEOUT_RECEIPT_KEYS:
        item = v10_timeout[key]
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
    julia_script = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV18/replay_staged_v18.jl"
    if digest(julia_script) != protocol["owned_source_files_by_path"][julia_script.relative_to(ROOT).as_posix()]:
        raise ValueError("replay Julia entrypoint hash differs from frozen protocol")
    entrypoint = str(julia_script.relative_to(ROOT).as_posix())
    if protocol.get("entrypoint") != entrypoint:
        raise ValueError("protocol entrypoint differs from the exact controller launch path")
    before = snapshot(input_entries)
    return {
        "protocol": protocol, "protocol_sha256": actual_protocol_sha, "output": output,
        "before": before, "input_entries": input_entries, "stage_limit": float(protocol["stage_limits"]["seconds"]),
        "memory_limit": int(protocol["stage_limits"]["working_set_bytes"]), "julia": julia,
        "aggregate_wall_contract": aggregate_wall_contract,
        "controller_overhead_contract": controller_overhead_contract, "v7_ancestry": v7_ancestry,
        "v10_timeout": verified_timeout, "v10_replay_failure": v10_replay, "v11_actual_failure": v11_failure,
        "v12_static_no_go": v12_no_go,
        "v13_static_candidate_and_no_go": v13_parent,
        "v14_actual_failure": v14_actual_failure,
        "v14_postrun_audit": v14_postrun_audit,
        "v15_actual_failure": v15_actual_failure,
        "v16_actual_failure": v16_actual_failure,
        "v17_actual_failure": v17_actual_failure,
        "process_tree_monitor_contract": process_tree_monitor_contract,
        "v6_failure": v6_failure, "v3_failure": verified_v3_failure,
        "context_builder_contract": context_builder_contract, "v8_failure": v8_failure,
        "v9_ancestry": v9_ancestry,
    }


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

    controller_started = time.monotonic()
    preflight = verify_pre_output_contract(args.protocol, args.protocol_sha256, args.output)
    protocol = preflight["protocol"]
    controller_overhead_limit = float(preflight["controller_overhead_contract"]["limit_seconds"])
    try:
        enforce_controller_overhead_budget(controller_started, 0.0, controller_overhead_limit)
    except ControllerOverheadBudgetExhausted as exc:
        elapsed_overhead = controller_overhead_seconds(
            controller_started, time.monotonic(), 0.0)
        print(json.dumps({
            "classification": "resource_interruption", "controller_exit_code": 124,
            "phase": "pre_output_preflight", "controller_overhead_seconds": elapsed_overhead,
            "controller_overhead_limit_seconds": controller_overhead_limit,
            "controller_overhead_overrun_seconds": max(0.0, elapsed_overhead - controller_overhead_limit),
            "output_leaf_created": False, "child_process_started": False, "reason": str(exc),
        }, separators=(",", ":")))
        return 124
    actual_protocol_sha = preflight["protocol_sha256"]
    output = preflight["output"]
    before = preflight["before"]
    input_entries = preflight["input_entries"]
    stage_limit = preflight["stage_limit"]
    memory_limit = preflight["memory_limit"]
    aggregate_wall_contract = preflight["aggregate_wall_contract"]
    aggregate_child_wall_limit = float(aggregate_wall_contract["total_limit_seconds"])
    cleanup_grace_seconds = float(aggregate_wall_contract["cleanup_grace_seconds"])
    julia = preflight["julia"]
    env = os.environ.copy()
    env.update({str(k): str(v) for k, v in protocol.get("environment", {}).items()})
    output.mkdir(parents=True)
    write_new(output / "inputs_before.json", before)
    env = os.environ.copy()
    env.update({str(k): str(v) for k, v in protocol.get("environment", {}).items()})
    results: list[dict[str, object]] = []
    completions: list[dict[str, object]] = []
    classification = "program_exception"
    controller_exit = 126
    producer_tree_comparison_status = "not_reached"
    producer_root = output / "producer_process/numerical"
    consumer_root = output / "consumer_process/numerical"
    start = controller_started
    child_wall_spent = 0.0
    try:
        enforce_controller_overhead_budget(
            start, child_wall_spent, controller_overhead_limit)
        producer_dir = output / "producer_process"
        producer_cmd = build_producer_launch_command(protocol, julia, producer_root, actual_protocol_sha)
        producer_budget = stage_child_wall_budget(
            aggregate_child_wall_limit, child_wall_spent, stage_limit, cleanup_grace_seconds)
        producer = run_stage(producer_cmd, ROOT, producer_dir, stage_limit, memory_limit, env,
                             producer_budget)
        results.append(dict(producer, stage="producer"))
        child_wall_spent += float(producer["child_wall_seconds"])
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
            resource_exit = resource_interruption_exit_code(str(producer["stop_reason"]))
            if resource_exit is not None:
                classification = "resource_interruption"
                controller_exit = resource_exit
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
        try:
            producer_overhead = enforce_controller_overhead_budget(
                start, child_wall_spent, controller_overhead_limit)
        except ControllerOverheadBudgetExhausted as exc:
            producer_overhead = controller_overhead_seconds(start, time.monotonic(), child_wall_spent)
            classification = "resource_interruption"
            controller_exit = 124
            write_new(output / "consumer_launch_blocked.json", {
                "schema": "mms-replay-controller-overhead-launch-blocked-v1",
                "classification": "resource_interruption", "stage": "consumer",
                "reason": str(exc), "controller_overhead_seconds": producer_overhead,
                "controller_overhead_limit_seconds": controller_overhead_limit,
                "child_wall_spent_seconds": child_wall_spent,
                "consumer_process_started": False,
            })
            raise TimeoutError("replay controller overhead exceeded before consumer") from exc

        consumer_dir = output / "consumer_process"
        consumer_cmd = build_consumer_launch_command(protocol, julia, consumer_root, producer_root,
            actual_protocol_sha, str(seal["carrier_sha256"]), str(seal["binding_sha256"]))
        try:
            consumer_budget = stage_child_wall_budget(
                aggregate_child_wall_limit, child_wall_spent, stage_limit, cleanup_grace_seconds)
        except AggregateChildWallBudgetExhausted as exc:
            write_new(output / "consumer_launch_blocked.json", {
                "schema": "mms-replay-aggregate-child-wall-launch-blocked-v1",
                "classification": "resource_interruption", "stage": "consumer",
                "reason": str(exc), "child_wall_spent_seconds": child_wall_spent,
                "total_child_wall_limit_seconds": aggregate_child_wall_limit,
                "cleanup_grace_seconds": cleanup_grace_seconds,
                "consumer_process_started": False,
            })
            raise
        consumer = run_stage(consumer_cmd, ROOT, consumer_dir, stage_limit, memory_limit, env,
                             consumer_budget)
        results.append(dict(consumer, stage="consumer"))
        child_wall_spent += float(consumer["child_wall_seconds"])
        write_new(output / "consumer_process.json", consumer)
        after_consumer = snapshot(input_entries)
        write_new(consumer_dir / "inputs_after.json", after_consumer)
        if before != after_consumer:
            classification = "input_drift"
            controller_exit = 125
            raise ValueError("pinned inputs or saved producer tree changed in consumer stage")
        if consumer["stop_reason"] != "exited" or consumer["exit_code"] != 0:
            resource_exit = resource_interruption_exit_code(str(consumer["stop_reason"]))
            if resource_exit is not None:
                classification = "resource_interruption"
                controller_exit = resource_exit
            else:
                classification = "program_exception"
                controller_exit = int(consumer["exit_code"] or 1)
            raise RuntimeError(f"consumer stage incomplete: {classification}")
        consumer_complete = valid_completion(consumer_root / "consumer_complete.json", "consumer")
        producer_after_consumer = tree_digest(producer_dir)
        write_new(output / "producer_tree_after_consumer.json", producer_after_consumer)
        if producer_before_consumer != producer_after_consumer:
            producer_tree_comparison_status = "changed"
            raise ValueError("consumer altered the sealed producer tree")
        producer_tree_comparison_status = "unchanged"
        after = snapshot(input_entries)
        write_new(output / "inputs_after.json", after)
        if before != after:
            classification = "input_drift"
            controller_exit = 125
            raise ValueError("original 89 pins or saved producer tree changed during replay")
        elapsed_children = sum(float(x["child_wall_seconds"]) for x in results)
        if elapsed_children > aggregate_child_wall_limit:
            classification = "resource_interruption"
            controller_exit = 124
            raise TimeoutError("aggregate child wall limit exceeded after bounded cleanup")
        overhead = time.monotonic() - start - elapsed_children
        if overhead > controller_overhead_limit:
            classification = "resource_interruption"
            controller_exit = 124
            raise TimeoutError("replay controller overhead limit exceeded")
        if producer_complete["result_hash"] != consumer_complete["result_hash"]:
            raise ValueError("producer/consumer result identity mismatch")
        classification = "test_only_continuation_complete"
        controller_exit = 0
    except AggregateChildWallBudgetExhausted:
        classification = "resource_interruption"
        controller_exit = 124
        exception = traceback.format_exc()
    except ControllerOverheadBudgetExhausted:
        classification = "resource_interruption"
        controller_exit = 124
        exception = traceback.format_exc()
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
        controller_finished = time.monotonic()
        elapsed_controller = controller_finished - start
        child_wall_total = sum(float(x.get("child_wall_seconds", 0.0)) for x in results)
        controller_overhead_spent = controller_overhead_seconds(start, controller_finished, child_wall_total)
        controller_overhead_overrun = max(0.0, controller_overhead_spent - controller_overhead_limit)
        if controller_overhead_overrun > 0 and controller_exit == 0:
            classification = "resource_interruption"
            controller_exit = 124
        final = {
            "schema": "mms-replay-only-controller-final-v3", "classification": classification,
            "controller_exit_code": controller_exit, "test_only_continuation": True,
            "software_complete": controller_exit == 0, "numerical_status": "fail", "solver_exit_code": 2,
            "stopping_reason": "stationary_nonzero_residual", "formal_candidate_credit": False,
            "physical_validation": "unsupported", "authority": "no_publish", "nonlinear_solves": 0,
            "inputs_unchanged": before == after,
            "producer_tree_comparison_status": producer_tree_comparison_status,
            "producer_tree_unchanged": (True if producer_tree_comparison_status == "unchanged" else
                                         False if producer_tree_comparison_status == "changed" else None),
            "stages": results, "elapsed_seconds": elapsed_controller,
            "stage_limits": protocol["stage_limits"],
            "controller_overhead_budget": {
                "limit_seconds": controller_overhead_limit,
                "spent_seconds": controller_overhead_spent,
                "overrun_seconds": controller_overhead_overrun,
                "limit_status": "overrun" if controller_overhead_overrun > 0 else "within_limit",
                "definition": protocol["controller_overhead_definition"],
            },
            "aggregate_child_wall_budget": {
                "limit_seconds": aggregate_child_wall_limit,
                "spent_seconds": sum(float(x.get("child_wall_seconds", 0.0)) for x in results),
                "remaining_seconds": aggregate_child_wall_limit - sum(
                    float(x.get("child_wall_seconds", 0.0)) for x in results),
                "overrun_seconds": max(0.0, sum(float(x.get("child_wall_seconds", 0.0))
                                                  for x in results) - aggregate_child_wall_limit),
                "unconfirmed_cleanup_stages": [x.get("stage") for x in results
                                                if isinstance(x.get("cleanup"), dict)
                                                and x["cleanup"].get("termination_confirmed") is not True],
                "limit_status": (
                    "aggregate_overrun" if sum(float(x.get("child_wall_seconds", 0.0))
                                                for x in results) > aggregate_child_wall_limit
                    else "cleanup_unconfirmed" if any(
                        isinstance(x.get("cleanup"), dict)
                        and x["cleanup"].get("termination_confirmed") is not True for x in results)
                    else "within_limit"),
                "termination_cleanup_grace_seconds": cleanup_grace_seconds,
                "definition": protocol["aggregate_child_wall_definition"],
                "controller_overhead_separate_limit_seconds": controller_overhead_limit,
            },
        }
        if "exception" in locals() and exception:
            final["controller_exception"] = exception
        write_new(output / "final.json", final)
    print(json.dumps({"classification": classification, "controller_exit_code": controller_exit,
                      "output": str(output), "final_sha256": digest(output / "final.json")}, separators=(",", ":")))
    return controller_exit


if __name__ == "__main__":
    raise SystemExit(main())
