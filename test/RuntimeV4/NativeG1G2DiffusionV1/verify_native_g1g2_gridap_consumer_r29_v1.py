"""Independent static verifier for the frozen R29 Gridap protocol."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path
from typing import Any, Mapping

import run_native_g1g2_gridap_consumer_r28_v1 as r28
import run_native_g1g2_gridap_consumer_r29_v1 as r29


R28_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r28_v1/protocol.json"
)
R28_MANIFEST = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r28_v1/freeze_manifest.json"
)
R28_HANDOFF = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r28_v1/handoff.md"
)
R28_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r28_v1.py"
R28_TEST = "test/RuntimeV4/NativeG1G2DiffusionV1/test_native_g1g2_gridap_consumer_r28_v1.py"
R28_VERIFIER = "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r28_v1.py"
R29_QA_LEAF = "runs/goal_execution_20260926/r29_pid_reuse_static_qa_r1"


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise r29.PreflightError(message)


def _pin_map(protocol: Mapping[str, Any]) -> dict[str, Mapping[str, Any]]:
    return {pin["path"]: pin for pin in protocol["input_pins"]}


def _file_receipt(relative_or_absolute: str) -> dict[str, Any]:
    path = Path(relative_or_absolute)
    if not path.is_absolute():
        path = r29.repo_path(relative_or_absolute)
    _require(path.is_file(), f"pinned evidence file is absent or not a file: {relative_or_absolute}")
    keep_data = path.stat().st_size <= 8 * 1024 * 1024
    chunks: list[bytes] = []
    digest = hashlib.sha256()
    byte_count = 0
    with path.open("rb") as stream:
        while chunk := stream.read(1024 * 1024):
            digest.update(chunk)
            byte_count += len(chunk)
            if keep_data:
                chunks.append(chunk)
    return {"bytes": byte_count, "sha256": digest.hexdigest(),
            "data": b"".join(chunks) if keep_data else None}


def _check_current_pin(protocol: Mapping[str, Any], relative_path: str,
                       receipt: Mapping[str, Any]) -> None:
    pin = _pin_map(protocol).get(relative_path)
    _require(isinstance(pin, Mapping) and pin.get("bytes") == receipt.get("bytes") and
             pin.get("sha256") == receipt.get("sha256"),
             f"R29 does not preserve the exact evidence pin: {relative_path}")


def _check_historical_file(protocol: Mapping[str, Any], record: Mapping[str, Any],
                           path_key: str, sha_key: str, expected_path: str) -> None:
    _require(record.get(path_key) == expected_path,
             f"historical lineage path drifted: {path_key}")
    receipt = _file_receipt(expected_path)
    _require(record.get(sha_key) == receipt["sha256"],
             f"historical lineage hash drifted: {expected_path}")
    _check_current_pin(protocol, expected_path, receipt)


def _check_r28_no_go_lineage(protocol: Mapping[str, Any]) -> Mapping[str, Any]:
    lineage = protocol.get("parent_lineage")
    _require(isinstance(lineage, Mapping), "R29 parent lineage is missing")
    record = lineage.get("r28_pid_reuse_no_go")
    _require(isinstance(record, Mapping), "R28 NO-GO lineage record is malformed")
    _require(record.get("verdict") == "NO-GO_RUNTIME" and
             record.get("runtime_dispatch_verdict") == "NO-GO",
             "R28 runtime NO-GO lineage was upgraded or omitted")
    _require(record.get("failure_shape") ==
             "R28 natural-exit PID reuse fail-closed branch lacked targeted injection coverage; "
             "Gridap runtime was never dispatched",
             "R28 natural-exit PID reuse failure shape drifted")
    _require(record.get("review_scope") ==
             "source/static-coverage analysis only; no standalone R28 PID-reuse review artifact exists",
             "R28 lineage misrepresents the absence of a standalone review artifact")
    _require("review_path" not in record and "review_sha256" not in record,
             "R28 lineage invents a PID-reuse review artifact")
    for path_key, sha_key, expected_path in (
        ("protocol_path", "protocol_sha256", R28_PROTOCOL),
        ("freeze_manifest_path", "freeze_manifest_sha256", R28_MANIFEST),
        ("handoff_path", "handoff_sha256", R28_HANDOFF),
        ("runner_path", "runner_sha256", R28_RUNNER),
        ("test_path", "test_sha256", R28_TEST),
        ("verifier_path", "verifier_sha256", R28_VERIFIER),
    ):
        _check_historical_file(protocol, record, path_key, sha_key, expected_path)
    old_protocol = _file_receipt(R28_PROTOCOL)
    old_manifest = json.loads(_file_receipt(R28_MANIFEST)["data"])
    _require(old_manifest.get("schema") == "native-g1g2-gridap-consumer-r28-freeze-manifest-v1" and
             old_manifest.get("protocol_path") == R28_PROTOCOL and
             old_manifest.get("protocol_sha256") == old_protocol["sha256"] and
             old_manifest.get("runtime_output_leaf_absent") is True and
             old_manifest.get("julia_started") is False and
             old_manifest.get("numerical_credit") is False and
             old_manifest.get("physical_credit") is False,
             "R28 freeze manifest no longer confirms its static-only, no-runtime boundary")
    for path_key, sha_key, expected_path in (
        ("runner_path", "runner_sha256", R28_RUNNER),
        ("test_path", "test_sha256", R28_TEST),
        ("verifier_path", "verifier_sha256", R28_VERIFIER),
    ):
        _require(old_manifest.get(path_key) == expected_path and
                 old_manifest.get(sha_key) == _file_receipt(expected_path)["sha256"],
                 f"R28 freeze manifest source pin drifted: {expected_path}")
    return record


def _check_r28_static_receipts(protocol: Mapping[str, Any],
                               r28_protocol: Mapping[str, Any],
                               no_go_record: Mapping[str, Any]) -> int:
    old_qa = r28_protocol.get("static_qa")
    expected_receipts = old_qa.get("qa_receipts") if isinstance(old_qa, Mapping) else None
    records = no_go_record.get("static_qa_receipts")
    _require(isinstance(expected_receipts, Mapping) and isinstance(records, list),
             "R28 static QA receipt lineage is missing")
    command_keys = {
        "python_full_suite": "python_tests_command",
        "orphan_chain_fault_injection": "orphan_chain_fault_injection_command",
        "static_verifier": "verifier_command",
    }
    _require({x.get("qa_name") for x in records if isinstance(x, Mapping)} == set(command_keys) and
             len(records) == len(command_keys),
             "R28 historical static QA receipt set is incomplete or duplicated")
    checked = 0
    record_map = {x["qa_name"]: x for x in records}
    for qa_name, command_key in command_keys.items():
        old = expected_receipts.get(qa_name)
        record = record_map[qa_name]
        _require(isinstance(old, Mapping), f"R28 protocol omitted receipt contract: {qa_name}")
        old_argv_path = old.get("command_argv")
        _require(type(old_argv_path) is str and old_argv_path.endswith(".command_argv.json"),
                 f"R28 command receipt path malformed: {qa_name}")
        expected_paths = {
            "command_argv_path": old_argv_path,
            "exit_code_path": old_argv_path[:-len(".command_argv.json")] + ".exit_code.json",
            "stdout_raw_path": old.get("stdout_raw"),
            "stderr_raw_path": old.get("stderr_raw"),
        }
        for path_key, expected_path in expected_paths.items():
            _require(type(expected_path) is str and record.get(path_key) == expected_path,
                     f"R28 receipt path drifted: {qa_name}.{path_key}")
        for path_key, sha_key in (
            ("command_argv_path", "command_argv_sha256"),
            ("exit_code_path", "exit_code_sha256"),
            ("stdout_raw_path", "stdout_raw_sha256"),
            ("stderr_raw_path", "stderr_raw_sha256"),
        ):
            path = record[path_key]
            receipt = _file_receipt(path)
            _require(record.get(sha_key) == receipt["sha256"],
                     f"R28 receipt SHA drifted: {qa_name}.{path_key}")
            _check_current_pin(protocol, path, receipt)
            checked += 1

        command = old_qa.get(command_key)
        argv_receipt = json.loads(_file_receipt(record["command_argv_path"])["data"])
        _require(isinstance(command, str) and argv_receipt.get("argv") == command.split(" "),
                 f"R28 archived argv differs from its frozen command: {qa_name}")
        exit_receipt = json.loads(_file_receipt(record["exit_code_path"])["data"])
        expected_exit = old.get("expected_exit_code")
        _require(exit_receipt.get("exit_code") == expected_exit == 0,
                 f"R28 archived exit does not match its historical contract: {qa_name}")
        stderr = _file_receipt(record["stderr_raw_path"])["data"].decode("utf-8", errors="replace")
        if qa_name == "python_full_suite":
            count = old.get("expected_tests_run")
            _require(count == old.get("expected_passed") == 30 and
                     re.search(r"Ran 30 tests in [^\r\n]+\r?\n\r?\nOK", stderr) is not None,
                     "R28 archived full suite is not the recorded 30/30 pass")
        elif qa_name == "orphan_chain_fault_injection":
            count = old.get("expected_tests_run")
            _require(count == old.get("expected_passed") == 6 and
                     re.search(r"Ran 6 tests in [^\r\n]+\r?\n\r?\nOK", stderr) is not None,
                     "R28 archived orphan-chain suite is not the recorded 6/6 pass")
        else:
            stdout = json.loads(_file_receipt(record["stdout_raw_path"])["data"])
            _require(old.get("expected_input_pin_count") == 191 and
                     stdout.get("status") == "static_protocol_check_pass" and
                     stdout.get("julia_started") is False and
                     stdout.get("input_pin_count") == 191 and
                     stdout.get("planned_argv_verified") is True and
                     stdout.get("runtime_output_leaf_absent") is True and
                     stdout.get("stage_order") == ["parse_all", "primary", "fresh_replay"] and
                     stdout.get("runtime_executed") is False and
                     stdout.get("numerical_credit") is False and
                     stdout.get("physical_credit") is False and not stderr,
                     "R28 archived verifier receipt no longer records a static-only 191-pin pass")
    return checked


def _check_r26_failure_unchanged(protocol: Mapping[str, Any],
                                 r28_protocol: Mapping[str, Any]) -> None:
    old_lineage = r28_protocol.get("parent_lineage")
    new_lineage = protocol.get("parent_lineage")
    _require(isinstance(old_lineage, Mapping) and isinstance(new_lineage, Mapping),
             "R28/R29 parent lineage map is missing")
    for key, old_record in old_lineage.items():
        _require(new_lineage.get(key) == old_record,
                 f"R29 changed or omitted frozen R28 parent lineage: {key}")
    old_failure = old_lineage.get("r26_actual_failure") if isinstance(old_lineage, Mapping) else None
    new_failure = new_lineage.get("r26_actual_failure") if isinstance(new_lineage, Mapping) else None
    _require(isinstance(old_failure, Mapping) and isinstance(new_failure, Mapping) and
             dict(new_failure) == dict(old_failure),
             "R29 changed or omitted the frozen R26 actual-failure lineage")

    old_pins = _pin_map(r28_protocol)
    new_pins = _pin_map(protocol)
    r26_old_pins = {path: pin for path, pin in old_pins.items()
                    if "r26" in path.casefold()}
    _require(bool(r26_old_pins), "R28 carries no R26 failure evidence pins")
    for path, old_pin in r26_old_pins.items():
        _require(new_pins.get(path) == old_pin,
                 f"R29 does not preserve the exact R26 failure pin: {path}")


def _check_static_qa_target(protocol: Mapping[str, Any]) -> None:
    invocation = protocol.get("invocation_contract")
    _require(isinstance(invocation, Mapping), "R29 invocation contract is missing")
    python = invocation.get("python_interpreter")
    _require(isinstance(python, Mapping) and type(python.get("path")) is str,
             "R29 pinned Python interpreter is malformed")
    static_qa = protocol.get("static_qa")
    _require(isinstance(static_qa, Mapping), "R29 static QA map is missing")
    legacy_test = str(r29.repo_path(r29.REL_LEGACY_TEST))
    expected_commands = {
        "python_tests_command": python["path"] + " -B " + legacy_test + " -v",
        "bind_failure_fault_injection_command": python["path"] + " -B " + legacy_test +
            " R28LaunchBindingFailureTests -v",
        "tree_cleanup_fault_injection_command": python["path"] + " -B " + legacy_test +
            " R28TrackedTreeCleanupFallbackTests -v",
        "sample_race_fault_injection_command": python["path"] + " -B " + legacy_test +
            " R28SampleRaceRecoveryTests -v",
        "orphan_chain_fault_injection_command": python["path"] + " -B " + legacy_test +
            " R28OrphanChainRecoveryTests -v",
        "verifier_command": python["path"] + " -B " + str(r29.repo_path(r29.REL_VERIFIER)) +
            " --protocol " + str(r29.repo_path(r29.REL_PROTOCOL)),
    }
    for key, expected in expected_commands.items():
        _require(static_qa.get(key) == expected, f"R29 static QA command drifted: {key}")
    target_command = (python["path"] + " -B " + str(r29.repo_path(r29.REL_TEST)) +
                      " R29NaturalExitPidReuseTests -v")
    _require(static_qa.get("pid_reuse_fault_injection_command") == target_command,
             "R29 targeted pid-reuse QA command is missing or drifted")
    _require(static_qa.get("receipts_persisted") is True and
             static_qa.get("julia_started") is False and
             static_qa.get("runtime_executed") is False and
             static_qa.get("numerical_credit") is False and
             static_qa.get("physical_credit") is False,
             "R29 static QA boundary claims runtime or science credit")


def _check_r29_pid_reuse_receipt(protocol: Mapping[str, Any]) -> None:
    static_qa = protocol["static_qa"]
    record = static_qa.get("qa_receipts", {}).get("pid_reuse_fault_injection")
    _require(isinstance(record, Mapping), "R29 PID-reuse QA receipt is missing")
    expected_paths = {
        "command_argv": f"{R29_QA_LEAF}/command_argv.json",
        "exit_code": f"{R29_QA_LEAF}/exit_code.json",
        "stdout_raw": f"{R29_QA_LEAF}/stdout.raw",
        "stderr_raw": f"{R29_QA_LEAF}/stderr.raw",
    }
    for key, expected_path in expected_paths.items():
        _require(record.get(key) == expected_path, f"R29 PID-reuse receipt path drifted: {key}")
        _check_current_pin(protocol, expected_path, _file_receipt(expected_path))
    argv_receipt = json.loads(_file_receipt(record["command_argv"])["data"])
    expected_argv = (static_qa["pid_reuse_fault_injection_command"].split(" "))
    _require(argv_receipt.get("argv") == expected_argv and
             argv_receipt.get("cwd") == str(r29.ROOT),
             "R29 archived PID-reuse command argv/cwd differs from the frozen selector")
    runner_pin = _pin_map(protocol).get(r29.REL_RUNNER)
    test_pin = _pin_map(protocol).get(r29.REL_TEST)
    _require(isinstance(runner_pin, Mapping) and isinstance(test_pin, Mapping),
             "R29 runner/test pins missing")
    _require(record.get("runner_before_sha256") == record.get("runner_after_sha256") ==
             runner_pin["sha256"] == argv_receipt.get("runner_sha256_before") ==
             argv_receipt.get("pinned_runner_sha256"),
             "R29 runner identity changed across the injected tests")
    _require(record.get("test_before_sha256") == record.get("test_after_sha256") ==
             test_pin["sha256"] == argv_receipt.get("test_sha256_before") ==
             argv_receipt.get("pinned_test_sha256"),
             "R29 test identity changed across the injected tests")
    exit_receipt = json.loads(_file_receipt(record["exit_code"])["data"])
    stdout = _file_receipt(record["stdout_raw"])
    stderr_receipt = _file_receipt(record["stderr_raw"])
    stderr = stderr_receipt["data"].decode("utf-8", errors="replace")
    _require(record.get("expected_exit_code") == exit_receipt.get("expected_exit_code") ==
             exit_receipt.get("exit_code") == 0 and
             record.get("expected_passed") == exit_receipt.get("tests_passed") == 2 and
             record.get("expected_tests_run") == exit_receipt.get("tests_run") == 2,
             "R29 PID-reuse QA receipt is not the archived 2/2 exit-0 run")
    _require(exit_receipt.get("julia_started") is False and
             exit_receipt.get("runtime_executed") is False and
             exit_receipt.get("numerical_credit") is False and
             exit_receipt.get("physical_credit") is False and
             record.get("julia_started") is False and
             record.get("numerical_credit") is False and
             record.get("physical_credit") is False,
             "R29 PID-reuse receipt claims runtime or science credit")
    _require(exit_receipt.get("runner_sha256_after") == record.get("runner_after_sha256") and
             exit_receipt.get("test_sha256_after") == record.get("test_after_sha256") and
             exit_receipt.get("stdout_bytes") == stdout["bytes"] and
             exit_receipt.get("stdout_sha256") == stdout["sha256"] and
             exit_receipt.get("stderr_bytes") == stderr_receipt["bytes"] and
             exit_receipt.get("stderr_sha256") == stderr_receipt["sha256"] and
             stdout["bytes"] == 0 and "Ran 2 tests" in stderr and "OK" in stderr and
             "test_parent_pid_reuse_then_disappearance_fails_closed_without_retry" in stderr and
             "test_genuine_parent_exit_without_pid_reuse_keeps_one_retry" in stderr,
             "R29 PID-reuse output receipt does not match its raw output evidence")


def _verify_input_pins_allowing_exact_runtime_no_go(protocol: Mapping[str, Any],
                                                    missing_inventory: list[Mapping[str, Any]]) -> dict[str, int]:
    pins = protocol.get("input_pins")
    _require(isinstance(pins, list) and pins and
             protocol.get("input_pin_count") == len(pins),
             "protocol input-pin count/list is malformed")
    seen_paths: set[str] = set()
    for pin in pins:
        _require(isinstance(pin, Mapping) and type(pin.get("path")) is str and
                 pin["path"] not in seen_paths and type(pin.get("bytes")) is int and
                 pin["bytes"] >= 0 and type(pin.get("sha256")) is str and
                 re.fullmatch(r"[0-9a-f]{64}", pin["sha256"]) is not None,
                 "protocol input pin is malformed or duplicated")
        seen_paths.add(pin["path"])
    expected_missing = {item["path"]: item for item in missing_inventory}
    _require(len(expected_missing) == len(missing_inventory),
             "runtime preflight missing inventory contains duplicate paths")
    seen_missing: dict[str, Mapping[str, Any]] = {}
    checked = 0
    for pin in pins:
        path = r29.repo_path(pin["path"])
        if not path.is_file():
            seen_missing[pin["path"]] = pin
            continue
        receipt = _file_receipt(pin["path"])
        _require(receipt["bytes"] == pin["bytes"] and receipt["sha256"] == pin["sha256"],
                 f"R29 input pin changed: {pin['path']}")
        checked += 1
    _require(set(seen_missing) == set(expected_missing),
             "missing R29 pins differ from the exact frozen runtime-preflight inventory")
    for path, pin in seen_missing.items():
        item = expected_missing[path]
        _require(pin.get("bytes") == item.get("expected_bytes") and
                 pin.get("sha256") == item.get("expected_sha256"),
                 f"missing pin identity differs from restore inventory: {path}")
    return {"checked_count": checked, "missing_count": len(seen_missing)}


def _verify_restore_archive(manifest: Mapping[str, Any], protocol: Mapping[str, Any]) -> int:
    preflight = manifest.get("runtime_preflight")
    _require(isinstance(preflight, Mapping) and
             preflight.get("status") == "NO-GO_until_exact_restore" and
             preflight.get("exact_restore_required") is True and
             preflight.get("restored") is False and
             preflight.get("input_pin_waiver") is False,
             "R29 runtime preflight must remain NO-GO with exact restore required and no waiver")
    inventory = preflight.get("inventory")
    _require(isinstance(inventory, list) and len(inventory) ==
             preflight.get("missing_count") == 47,
             "R29 exact-restore inventory must preserve all 47 absent paths")
    archive = preflight.get("archive") or preflight.get("archive_source")
    _require(isinstance(archive, Mapping) and archive.get("local_only") is True and
             archive.get("portable") is False,
             "R29 exact-restore ZIP source is missing or its local-only limitation is unclear")
    archive_path = archive.get("path")
    _require(type(archive_path) is str, "R29 exact-restore ZIP path is malformed")
    archive_receipt = _file_receipt(archive_path)
    _require(archive_receipt["bytes"] == archive.get("bytes") and
             archive_receipt["sha256"] == archive.get("sha256"),
             "R29 exact-restore ZIP identity differs from the frozen source receipt")

    expected_missing = {item["path"]: item for item in inventory}
    _require(len(expected_missing) == len(inventory),
             "R29 restore inventory contains duplicate paths")
    pin_map = _pin_map(protocol)
    with zipfile.ZipFile(archive_path, "r") as bundle:
        members = set(bundle.namelist())
        zip_members: set[str] = set()
        for item in inventory:
            path = item.get("path")
            member = item.get("zip_member")
            _require(type(path) is str and type(member) is str and member in members and
                     member not in zip_members,
                     f"R29 restore ZIP member is missing or duplicated: {member}")
            zip_members.add(member)
            _require(not r29.repo_path(path).exists(),
                     f"R29 NO-GO input was unexpectedly restored: {path}")
            _require(item.get("archive_match") is True,
                     f"R29 restore inventory does not assert a verified archive match: {path}")
            with bundle.open(member, "r") as stream:
                digest = hashlib.sha256()
                byte_count = 0
                while chunk := stream.read(1024 * 1024):
                    digest.update(chunk)
                    byte_count += len(chunk)
            sha = digest.hexdigest()
            _require(byte_count == item.get("expected_bytes") == item.get("observed_bytes") and
                     sha == item.get("expected_sha256") == item.get("observed_sha256"),
                     f"R29 archived restore member bytes/hash mismatch: {path}")
            pin = pin_map.get(path)
            _require(isinstance(pin, Mapping) and pin.get("bytes") == byte_count and
                     pin.get("sha256") == sha,
                     f"R29 restore member does not match the missing input pin: {path}")
    return len(inventory)


def _check_protocol_contracts(protocol: Mapping[str, Any],
                              r28_protocol: Mapping[str, Any]) -> None:
    expected_stages = ["parse_all", "primary", "fresh_replay"]
    expected_limits = {
        "sample_interval_seconds": 0.2,
        "wall_seconds_per_stage": 480.0,
        "sampled_rss_stop_threshold_bytes": 2 * 1024 * 1024 * 1024,
        "julia_heap_size_hint": "1G",
        "compiler_mode": "--compile=min",
        "julia_threads": 1,
        "blas_threads": 1,
    }
    _require(protocol.get("schema") == "native-g1g2-gridap-consumer-r29-protocol-v1",
             "R29 protocol schema drifted")
    _require(r28_protocol.get("schema") == "native-g1g2-gridap-consumer-r28-protocol-v1",
             "frozen R28 predecessor schema drifted")
    _require(r28_protocol.get("limits") == expected_limits and
             protocol.get("limits") == expected_limits,
             "R29 changed the frozen R28 stage/resource limits")
    _require(r28_protocol.get("fixture_and_solver_thresholds_unchanged") is True and
             protocol.get("fixture_and_solver_thresholds_unchanged") is True,
             "R29 did not preserve R28 fixture and numerical thresholds")
    old_plan = r28_protocol.get("execution_plan")
    plan = protocol.get("execution_plan")
    _require(isinstance(old_plan, Mapping) and isinstance(plan, Mapping) and
             old_plan.get("stage_order") == expected_stages and
             plan.get("stage_order") == expected_stages and
            old_plan.get("consumer_script") == r28.REL_FOCUSED and
            plan.get("consumer_script") == old_plan.get("consumer_script") and
            old_plan.get("primary_replay_same_consumer_script") is True and
            plan.get("primary_replay_same_consumer_script") is True and
            old_plan.get("compile_min_is_only_non_path_argv_delta_from_R13") is True and
            plan.get("compile_min_is_only_non_path_argv_delta_from_R13") is True,
             "R29 stage order/consumer identity/compile-mode contract changed")
    _require(protocol.get("planned_output_leaf") == r29.REL_OUTPUT and
             r28_protocol.get("planned_output_leaf") == r28.REL_OUTPUT,
             "R29 or R28 planned output leaf is not the unique frozen path")
    r28_output = r28.repo_path(r28_protocol["planned_output_leaf"])
    r29_output = r29.repo_path(protocol["planned_output_leaf"])
    _require(not r28_output.exists() and not r29_output.exists(),
             "historical or planned runtime output leaf is not absent")
    old_commands = r28.planned_stage_commands(r28_protocol, r28_output)
    new_commands = r29.planned_stage_commands(protocol, r29_output)
    _require(old_commands == old_plan.get("stage_commands") and
             new_commands == plan.get("stage_commands") and
             [x["stage"] for x in new_commands] == expected_stages,
             "R28/R29 frozen planned stage argv differs from its consumer contract")
    _require(len(old_commands) == len(new_commands), "R29 changed the stage command count")
    for old, new in zip(old_commands, new_commands):
        expected_argv = [arg.replace(str(r28_output), str(r29_output)) for arg in old["argv"]]
        _require(new == {"stage": old["stage"], "argv": expected_argv},
                 f"R29 changed the R28 consumer argv beyond the output-leaf path: {old['stage']}")
    _require(r28_protocol.get("archive_is_evidence_only") is True and
             protocol.get("archive_is_evidence_only") is True and
             protocol.get("acceptance_boundary", {}).get("runtime_executed") is False and
             protocol.get("acceptance_boundary", {}).get("numerical_credit") is False and
             protocol.get("acceptance_boundary", {}).get("physical_credit") is False,
             "R29 protocol grants runtime or science credit")
    _require(r28_protocol.get("failed_launch_cleanup_contract") ==
             protocol.get("failed_launch_cleanup_contract") == r29.FAILED_LAUNCH_CLEANUP_CONTRACT and
             r28_protocol.get("sampled_tracked_race_recovery_contract") ==
             protocol.get("sampled_tracked_race_recovery_contract") ==
             r29.SAMPLED_TRACKED_RACE_RECOVERY_CONTRACT,
             "R29 changed the frozen R28 launch-cleanup or sampled-race recovery contract")
    expected_load_path = f"@;{r29.ROOT};@stdlib"
    expected_environment = {
        "JULIA_LOAD_PATH": expected_load_path,
        "JULIA_NUM_THREADS": "1",
        "JULIA_PKG_OFFLINE": "true",
        "JULIA_PKG_PRECOMPILE_AUTO": "0",
        "OPENBLAS_NUM_THREADS": "1",
        "OMP_NUM_THREADS": "1",
        "MKL_NUM_THREADS": "1",
    }
    _require(plan.get("julia_load_path") == expected_load_path and
             protocol.get("environment_contract") == expected_environment,
             "R29 changed the frozen single-thread offline Julia environment")
    invocation = protocol.get("invocation_contract")
    _require(isinstance(invocation, Mapping), "R29 invocation roles are missing")
    python = invocation.get("python_interpreter")
    _require(isinstance(python, Mapping) and type(python.get("path")) is str,
             "R29 pinned Python interpreter contract is malformed")
    protocol_abs = str(r29.repo_path(r29.REL_PROTOCOL))
    expected_static = [python["path"], "-B", str(r29.repo_path(r29.REL_VERIFIER)),
                       "--protocol", protocol_abs]
    expected_actual = [python["path"], "-B", str(r29.repo_path(r29.REL_RUNNER)),
                       "--dispatch-actual", "--protocol", protocol_abs,
                       "--output", str(r29.repo_path(r29.REL_OUTPUT))]
    _require(invocation.get("static_verifier_argv") == expected_static and
             invocation.get("actual_supervisor_argv") == expected_actual and
             expected_static != expected_actual,
             "R29 static and actual invocation roles are not separately pinned")
    _require(protocol.get("process_table_contract", {}).get("host_build_pin") ==
             [10, 0, 26200, "AMD64"] and
             protocol.get("process_table_contract", {}).get("helper_schema") ==
             "native-g1g2-windows-process-table-r23-v1",
             "R29 native process table contract drifted")


def _check_r28_pins_preserved(protocol: Mapping[str, Any],
                              r28_protocol: Mapping[str, Any]) -> int:
    old = _pin_map(r28_protocol)
    new = _pin_map(protocol)
    _require(len(old) == 191, "frozen R28 input pin count changed")
    for path, pin in old.items():
        _require(new.get(path) == pin, f"R29 changed or omitted an R28 input pin: {path}")
    return len(old)


def _check_freeze_manifest(protocol_path: Path,
                           protocol: Mapping[str, Any]) -> Mapping[str, Any]:
    manifest_path = protocol_path.with_name("freeze_manifest.json")
    manifest_receipt = _file_receipt(str(manifest_path))
    manifest = json.loads(manifest_receipt["data"])
    relative_manifest = manifest_path.relative_to(r29.ROOT).as_posix()
    protocol_receipt = _file_receipt(str(protocol_path))
    _require(manifest.get("schema") == "native-g1g2-gridap-consumer-r29-freeze-manifest-v1" and
             manifest.get("protocol_path") == r29.REL_PROTOCOL and
             manifest.get("protocol_sha256") == protocol_receipt["sha256"],
             "R29 freeze manifest does not pin the live protocol bytes")
    _require(manifest.get("protocol_input_pin_count") == protocol.get("input_pin_count"),
             "R29 manifest/protocol input-pin counts differ")
    pins = _pin_map(protocol)
    for path_key, sha_key, expected_path, protocol_path_key in (
        ("runner_path", "runner_sha256", r29.REL_RUNNER, r29.REL_RUNNER),
        ("test_path", "test_sha256", r29.REL_TEST, r29.REL_TEST),
        ("verifier_path", "verifier_sha256", r29.REL_VERIFIER, r29.REL_VERIFIER),
    ):
        receipt = _file_receipt(expected_path)
        pin = pins.get(protocol_path_key)
        _require(manifest.get(path_key) == expected_path and
                 manifest.get(sha_key) == receipt["sha256"] and
                 isinstance(pin, Mapping) and pin.get("bytes") == receipt["bytes"] and
                 pin.get("sha256") == receipt["sha256"],
                 f"R29 freeze manifest source pin differs: {expected_path}")
    _require(manifest.get("runtime_output_leaf_absent") is True and
             not r29.repo_path(protocol["planned_output_leaf"]).exists() and
             manifest.get("julia_started") is False and
             manifest.get("numerical_credit") is False and
             manifest.get("physical_credit") is False,
             "R29 freeze manifest claims a runtime output or science credit")
    _require(relative_manifest == r29.REL_PROTOCOL.rsplit("/", 1)[0] + "/freeze_manifest.json",
             "R29 freeze manifest is not the unique sibling manifest")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    args = parser.parse_args()
    protocol_path = Path(args.protocol).resolve()
    _require(protocol_path == r29.repo_path(r29.REL_PROTOCOL).resolve(),
             "static verifier must inspect the unique frozen R29 protocol")
    protocol = r29.load_protocol(protocol_path)
    manifest = _check_freeze_manifest(protocol_path, protocol)
    runtime_preflight = manifest.get("runtime_preflight")
    _require(isinstance(runtime_preflight, Mapping), "R29 runtime preflight record is missing")
    inventory = runtime_preflight.get("inventory")
    _require(isinstance(inventory, list), "R29 exact-restore inventory is malformed")
    restored_count = _verify_restore_archive(manifest, protocol)
    pins = _verify_input_pins_allowing_exact_runtime_no_go(protocol, inventory)
    r28_protocol = r28.load_protocol(r28.repo_path(R28_PROTOCOL))
    r28_pins = _verify_input_pins_allowing_exact_runtime_no_go(r28_protocol, inventory)
    r28_preserved_pin_count = _check_r28_pins_preserved(protocol, r28_protocol)
    _check_protocol_contracts(protocol, r28_protocol)
    observed = list(getattr(sys, "orig_argv", []))
    if not observed:
        observed = [sys.executable, *sys.argv]
    r29.validate_invocation("static_verifier", observed, protocol)

    # Recheck the historical R28 run receipt and its exact no-runtime boundary.
    r28_output = r28.repo_path(r28_protocol["planned_output_leaf"])
    _require(not r28_output.exists(), "historical R28 output leaf is unexpectedly present")

    for relative in (r29.REL_RUNNER, r29.REL_TEST, r29.REL_VERIFIER):
        _require(relative in _pin_map(protocol), f"R29 source is not pinned: {relative}")
    r28_no_go = _check_r28_no_go_lineage(protocol)
    r28_receipts_checked = _check_r28_static_receipts(protocol, r28_protocol, r28_no_go)
    _check_r26_failure_unchanged(protocol, r28_protocol)
    _check_static_qa_target(protocol)
    _check_r29_pid_reuse_receipt(protocol)

    plan = protocol["execution_plan"]

    julia = protocol["execution_plan"]["julia_executable"]
    julia_path = Path(julia["path"])
    _require(julia_path.is_file(), "pinned Julia executable is unavailable")
    julia_receipt = _file_receipt(str(julia_path))
    _require(julia_receipt["bytes"] == julia["bytes"] and
             julia_receipt["sha256"] == julia["sha256"],
             "pinned Julia executable hash mismatch")
    python = protocol["invocation_contract"]["python_interpreter"]
    python_receipt = _file_receipt(python["path"])
    _require(python_receipt["bytes"] == python["bytes"] and
             python_receipt["sha256"] == python["sha256"],
             "pinned Python interpreter hash mismatch")

    output = r29.repo_path(protocol["planned_output_leaf"])
    _require(not output.exists(), "planned R29 runtime output leaf is not fresh")
    commands = r29.planned_stage_commands(protocol, output)
    _require([item["stage"] for item in commands] == plan["stage_order"],
             "planned command stage order mismatch")
    _require(commands == plan["stage_commands"], "planned stage argv differs from frozen protocol")
    _require(protocol.get("acceptance_boundary", {}).get("runtime_executed") is False and
             protocol.get("acceptance_boundary", {}).get("numerical_credit") is False and
             protocol.get("acceptance_boundary", {}).get("physical_credit") is False,
             "R29 frozen static verifier grants runtime or scientific credit")

    print(json.dumps({
        "status": "static_protocol_check_pass_runtime_no_go",
        "protocol_schema": protocol.get("schema"),
        "runtime_executed": False,
        "julia_started": False,
        "r29_input_pin_count": protocol["input_pin_count"],
        "r29_present_input_pins_checked": pins["checked_count"],
        "r29_runtime_missing_input_pin_count": pins["missing_count"],
        "runtime_preflight": runtime_preflight["status"],
        "runtime_restore_archive_members_verified": restored_count,
        "r28_input_pin_count": r28_protocol["input_pin_count"],
        "r28_present_input_pins_checked": r28_pins["checked_count"],
        "r28_runtime_missing_input_pin_count": r28_pins["missing_count"],
        "r28_pins_preserved_exactly": r28_preserved_pin_count,
        "r28_historical_static_receipt_files_checked": r28_receipts_checked,
        "r28_no_go_lineage_preserved": True,
        "r26_failure_lineage_and_hashes_preserved": True,
        "stage_order": plan["stage_order"],
        "planned_argv_verified": True,
        "r28_output_leaf_absent": True,
        "r29_output_leaf_absent": True,
        "runner_full_runtime_preflight": "NO-GO_until_exact_restore",
        "resource_contract": protocol["limits"],
        "runtime_dispatch_authorized": False,
        "numerical_credit": False,
        "physical_credit": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except r29.PreflightError as exc:
        print(json.dumps({"status": "static_protocol_check_fail", "runtime_executed": False,
                          "error": str(exc), **r29.NO_CREDIT}, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print(json.dumps({"status": "static_protocol_check_fail", "runtime_executed": False,
                          "error": f"independent evidence verification failed: {exc}",
                          **r29.NO_CREDIT}, sort_keys=True), file=sys.stderr)
        raise SystemExit(1)
