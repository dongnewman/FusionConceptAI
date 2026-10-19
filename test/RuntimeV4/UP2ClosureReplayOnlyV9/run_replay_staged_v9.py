#!/usr/bin/env python3
"""Two-process, test-only replay continuation with explicit resource gates (v9)."""
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
SCRIPT = pathlib.Path(__file__).resolve().with_name("replay_staged_v9.jl")
DEFAULT_PROTOCOL = ROOT / "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/replay_protocol_v9.json"
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
        "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9")
    if not expected.is_relative_to(archive_root):
        raise ValueError("protocol output_leaf escapes the V9 replay-only archive")
    if not output.is_relative_to(archive_root):
        raise ValueError("output must remain under the V9 replay-only archive leaf")
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


def verify_v3_runtime_failure(root: pathlib.Path, evidence: object) -> dict[str, object]:
    """Bind the complete immutable V3 failed-run leaf before any V9 output or child."""
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
    """Require the V9 replay call to resolve through the helper's actual DefinitionRuntime module."""
    if not all(isinstance(value, str) for value in (entrypoint_text, helper_text, candidate_source_text)):
        raise ValueError("context builder binding source text is unavailable")
    if "include(HELPER)" not in entrypoint_text or \
            not re.search(r"const\s+M\s*=\s*ManufacturedCandidateV1Tests", entrypoint_text) or \
            not re.search(r"const\s+S\s*=\s*M\.S", entrypoint_text):
        raise ValueError("replay context builder is not resolved through the frozen helper module alias")
    exact_call = "S.build_spatial_candidate_v4(parent.context, parent.physical_input; physical_declaration=d)"
    if entrypoint_text.count(exact_call) != 1 or "build_spatial_candidate_v5" in entrypoint_text:
        raise ValueError("replay must call the defined V4 spatial candidate builder exactly once")
    if "module ManufacturedCandidateV1Tests" not in helper_text or \
            "module DefinitionRuntime" not in helper_text or \
            not re.search(r"const\s+S\s*=\s*DefinitionRuntime\b", helper_text) or \
            '"SpatialCandidateV4.jl"' not in helper_text:
        raise ValueError("helper does not bind S to DefinitionRuntime with SpatialCandidateV4 included")
    if not re.search(r"function\s+build_spatial_candidate_v4\s*\(", candidate_source_text) or \
            re.search(r"function\s+build_spatial_candidate_v5\s*\(", candidate_source_text):
        raise ValueError("pinned candidate source does not define the required V4 builder only")


def verify_context_builder_contract(root: pathlib.Path, protocol: dict[str, object]) -> dict[str, object]:
    contract = protocol.get("context_builder_contract")
    if not isinstance(contract, dict):
        raise ValueError("context builder contract is missing")
    if (contract.get("module_alias"), contract.get("module_name"), contract.get("builder_symbol")) != (
            "S=M.S", "DefinitionRuntime", "build_spatial_candidate_v4"):
        raise ValueError("context builder contract names an unsupported module or symbol")
    entrypoint_rel = protocol.get("entrypoint")
    if entrypoint_rel != contract.get("entrypoint_path"):
        raise ValueError("context builder entrypoint differs from the frozen protocol")
    entrypoint_path = verify_bound_sha256(root, entrypoint_rel, contract.get("entrypoint_sha256"),
                                          "V9 replay entrypoint")
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


def terminate_tree(pid: int, cleanup_grace_seconds: float) -> dict[str, object]:
    """Terminate a process tree and bound all waits by one cleanup deadline."""
    started = time.monotonic()
    deadline = started + max(0.0, float(cleanup_grace_seconds))
    try:
        root_proc = psutil.Process(pid)
        children = root_proc.children(recursive=True)
    except (psutil.NoSuchProcess, psutil.AccessDenied):
        root_proc = None
        children = []
    targets = list(reversed(children)) + ([root_proc] if root_proc is not None else [])
    identities: list[dict[str, object]] = []
    terminate_requested: list[int] = []
    for proc in reversed(children):
        try:
            identities.append({"pid": proc.pid, "create_time": proc.create_time()})
            terminate_requested.append(proc.pid)
            proc.terminate()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    if root_proc is not None:
        try:
            identities.append({"pid": root_proc.pid, "create_time": root_proc.create_time()})
            terminate_requested.append(root_proc.pid)
            root_proc.terminate()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    alive = targets
    if targets:
        try:
            grace = min(1.0, max(0.0, deadline - time.monotonic()))
            _, alive = psutil.wait_procs(targets, timeout=grace)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            alive = []
    kill_requested: list[int] = []
    for proc in alive:
        try:
            kill_requested.append(proc.pid)
            proc.kill()
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            pass
    remaining = max(0.0, deadline - time.monotonic())
    if alive and remaining > 0:
        try:
            _, alive = psutil.wait_procs(alive, timeout=remaining)
        except (psutil.NoSuchProcess, psutil.AccessDenied):
            alive = []
    return {
        "cleanup_grace_seconds": float(cleanup_grace_seconds),
        "elapsed_seconds": time.monotonic() - started,
        "terminate_requested_pids": sorted(set(terminate_requested)),
        "kill_requested_pids": sorted(set(kill_requested)),
        "owned_process_identities": identities,
        "remaining_process_pids": sorted({proc.pid for proc in alive}),
        "termination_confirmed": not alive,
        "bounded_wait_deadline_monotonic": deadline,
    }


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
        while proc.poll() is None:
            rss, observed = live_tree_bytes(proc.pid)
            peak = max(peak, rss)
            identities.extend(observed)
            elapsed = time.monotonic() - process_started
            if rss > memory_limit:
                stop_reason = "working_set_limit"
                cleanup = terminate_tree(proc.pid, cleanup_grace)
                break
            if elapsed >= effective_live_limit:
                stop_reason = ("aggregate_wall_timeout" if effective_live_limit < limit_s
                               else "wall_timeout")
                cleanup = terminate_tree(proc.pid, cleanup_grace)
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
                cleanup["termination_confirmed"] = not bool(cleanup.get("remaining_process_pids"))
        process_ended = time.monotonic()
        exit_code = proc.poll()
    child_wall_seconds = process_ended - process_started
    aggregate_overrun = max(0.0, child_wall_seconds - aggregate_remaining)
    cleanup_elapsed = 0.0 if cleanup is None else float(cleanup["elapsed_seconds"])
    cleanup_overrun = max(0.0, cleanup_elapsed - cleanup_grace)
    cleanup_unconfirmed = cleanup is not None and cleanup.get("termination_confirmed") is not True
    if stop_reason == "exited" and child_wall_seconds > effective_live_limit:
        stop_reason = ("aggregate_wall_timeout" if effective_live_limit < limit_s else "wall_timeout")
    if aggregate_overrun > 0 or cleanup_overrun > 0 or cleanup_unconfirmed:
        stop_reason = "aggregate_cleanup_overrun"
    elapsed_stage = time.monotonic() - stage_started
    stdout_bytes = stdout_path.read_bytes()
    stderr_bytes = stderr_path.read_bytes()
    unique = {(int(x["pid"]), float(x["create_time"])): x for x in identities}
    return {
        "schema": "mms-replay-recorded-process-v2", "command": command, "cwd": str(cwd),
        "pid": proc.pid, "started_utc": started_utc,
        "elapsed_seconds": elapsed_stage, "child_wall_seconds": child_wall_seconds,
        "exit_code": exit_code, "stop_reason": stop_reason,
        "aggregate_child_wall_remaining_before_seconds": aggregate_remaining,
        "aggregate_child_wall_overrun_seconds": aggregate_overrun,
        "per_stage_live_limit_seconds": effective_live_limit,
        "cleanup_grace_seconds": cleanup_grace, "cleanup": cleanup,
        "peak_sampled_process_tree_working_set_bytes": peak,
        "memory_limit_bytes": memory_limit, "wall_limit_seconds": limit_s,
        "observed_process_identities": list(unique.values()),
        "terminated_owned_processes": [] if cleanup is None else cleanup["owned_process_identities"],
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


def verify_pre_output_contract(protocol_path: pathlib.Path | str, expected_protocol_sha: str,
                               output_arg: pathlib.Path | str) -> dict[str, object]:
    """Run main's complete read-only pre-output validation chain and return its frozen inputs."""
    protocol_path = pathlib.Path(protocol_path).resolve()
    if protocol_path != DEFAULT_PROTOCOL.resolve():
        raise ValueError("only the frozen replay_protocol_v9.json is accepted")
    protocol_wire = protocol_path.read_bytes()
    actual_protocol_sha = hashlib.sha256(protocol_wire).hexdigest()
    if actual_protocol_sha.lower() != expected_protocol_sha.lower():
        raise ValueError("replay protocol SHA does not match --protocol-sha256")
    protocol = json.loads(protocol_wire)
    if protocol.get("schema") != "mms-replay-only-continuation-protocol-v9" or protocol.get("classification") != "test_only_continuation":
        raise ValueError("unsupported replay protocol schema or classification")
    if protocol.get("runtime_grant") is not False:
        raise ValueError("protocol runtime_grant must remain false; root serial-slot grant is a command argument")
    controller_overhead_contract = validate_controller_overhead_contract(protocol)
    aggregate_wall_contract = validate_aggregate_child_wall_contract(protocol)
    output = resolve_output_target(ROOT, output_arg, protocol.get("output_leaf"))
    if output.exists():
        raise FileExistsError(f"preserve existing replay-only output: {output}")
    verify_child_command_contract(protocol)
    context_builder_contract = verify_context_builder_contract(ROOT, protocol)
    v8_failure = verify_v8_context_rebuild_failure(ROOT, protocol)

    v7_ancestry = verify_v7_no_go_ancestry(
        ROOT, protocol.get("parent_v7_protocol"), protocol.get("parent_v7_independent_review"))

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
    julia_script = ROOT / "test/RuntimeV4/UP2ClosureReplayOnlyV9/replay_staged_v9.jl"
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
        "v10_timeout": verified_timeout, "v6_failure": v6_failure, "v3_failure": verified_v3_failure,
        "context_builder_contract": context_builder_contract, "v8_failure": v8_failure,
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
    producer_tree_unchanged = False
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
            if producer["stop_reason"] in ("wall_timeout", "aggregate_wall_timeout", "aggregate_cleanup_overrun",
                                            "working_set_limit"):
                classification = "resource_interruption"
                controller_exit = 123 if producer["stop_reason"] == "working_set_limit" else 124
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
            if consumer["stop_reason"] in ("wall_timeout", "aggregate_wall_timeout", "aggregate_cleanup_overrun",
                                            "working_set_limit"):
                classification = "resource_interruption"
                controller_exit = 123 if consumer["stop_reason"] == "working_set_limit" else 124
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
            "schema": "mms-replay-only-controller-final-v2", "classification": classification,
            "controller_exit_code": controller_exit, "test_only_continuation": True,
            "software_complete": controller_exit == 0, "numerical_status": "fail", "solver_exit_code": 2,
            "stopping_reason": "stationary_nonzero_residual", "formal_candidate_credit": False,
            "physical_validation": "unsupported", "authority": "no_publish", "nonlinear_solves": 0,
            "inputs_unchanged": before == after, "producer_tree_unchanged": producer_tree_unchanged,
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
