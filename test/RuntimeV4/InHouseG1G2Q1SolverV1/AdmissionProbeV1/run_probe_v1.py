"""Run the clone-only Q1 admission timing probe under the frozen Job limits."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import sys
import time
from pathlib import Path
from types import ModuleType


SUPERVISOR_SHA256 = (
    "17C3701BC565FDC54EC0BD324E2BB65D7EE77E91C8D78FD4B6A0231B22CA12F2"
)
INTEGRATION_SHA256 = (
    "37FC25612CCCF94044F736984F7F4A730C7F6F078898C80849981ADD27F3BC86"
)
PACKAGE_SHA256 = (
    "EFFAC2E603D2A1AF30605B70310A634E3659AC487634E164AB049851795C4F89"
)
FIXTURE_SHA256 = (
    "C40322D190E3BB72AFC0882E755687C67D5AD0EC4EC580BC09DFF9AA8ACBDC9A"
)
PROBE_SCHEMA = "inhouse-q1-admission-probe-run-v1"
# Updated to the frozen probe source SHA after independent static review.
PROBE_SOURCE_SHA256 = (
    "8CF92684C608A095D07C7CBA499CB4947C8C3ACFD059C2173D98F746E92D5E33"
)
EVENT_SCHEMA = "inhouse-q1-admission-probe-events-v1"
SUMMARY_SCHEMA = "inhouse-q1-admission-probe-summary-v1"
EXPECTED_OUTCOME = "diagnostic_clone_stopped_before_follow_on_fixture_work"


def sha256(path: Path) -> str | None:
    if not path.is_file():
        return None
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def validate_diagnostic_completion(events_path: Path,
                                   summary_path: Path) -> dict:
    """Fail closed unless the clone reached its exact zero-credit stop."""
    if not events_path.is_file() or not summary_path.is_file():
        raise RuntimeError("diagnostic event stream or summary is missing")

    raw_lines = events_path.read_bytes().splitlines()
    if not raw_lines:
        raise RuntimeError("diagnostic event stream is empty")
    events: list[dict] = []
    for number, raw_line in enumerate(raw_lines, start=1):
        try:
            event = json.loads(raw_line.decode("utf-8", errors="strict"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise RuntimeError(
                f"malformed diagnostic event line {number}") from error
        if not isinstance(event, dict):
            raise RuntimeError(f"diagnostic event line {number} is not an object")
        if event.get("schema") != EVENT_SCHEMA or \
                event.get("diagnostic_only") is not True or \
                event.get("acceptance_credit") is not False or \
                event.get("compiler_or_solver_input") is not False:
            raise RuntimeError(f"diagnostic event line {number} has invalid scope")
        events.append(event)

    event_names = [event.get("event") for event in events]
    if event_names[0] != "probe_started" or \
            event_names.count("probe_started") != 1:
        raise RuntimeError("diagnostic start event is missing or duplicated")
    if event_names.count("fresh_admission_input_bound") != 1 or \
            event_names.count("clone_call_begin") != 1 or \
            event_names.count("clone_result_discarded") != 1 or \
            event_names.count("diagnostic_stop") != 1:
        raise RuntimeError("required diagnostic input/call/stop event is missing or duplicated")
    if "probe_exception" in event_names:
        raise RuntimeError("diagnostic clone or event flush raised an exception")
    allowed_events = {
        "probe_started", "fresh_admission_input_bound", "clone_call_begin",
        "phase_begin", "phase_end", "clone_result_discarded",
        "diagnostic_stop",
    }
    if any(name not in allowed_events for name in event_names):
        raise RuntimeError("diagnostic stream contains an unknown event")

    fresh_index = event_names.index("fresh_admission_input_bound")
    call_index = event_names.index("clone_call_begin")
    result_index = event_names.index("clone_result_discarded")
    stop_index = event_names.index("diagnostic_stop")
    if not (0 < fresh_index < call_index < result_index < stop_index ==
            len(events) - 1):
        raise RuntimeError("diagnostic events are out of expected order")
    result_event = events[result_index]
    terminal = events[stop_index]
    if result_event.get("result_discarded") is not True:
        raise RuntimeError("diagnostic clone result was not explicitly discarded")
    if not isinstance(result_event.get("status"), str) or \
            not isinstance(result_event.get("resolution"), str):
        raise RuntimeError("diagnostic clone result fields are incomplete")
    if terminal.get("outcome") != EXPECTED_OUTCOME or \
            terminal.get("clone_only") is not True or \
            terminal.get("official_admission_called") is not False or \
            terminal.get("compiler_called") is not False or \
            terminal.get("solver_called") is not False or \
            terminal.get("acceptance_credit") is not False:
        raise RuntimeError("terminal event is not the expected diagnostic stop")

    identity_keys = (
        "candidate_id", "candidate_version", "transport_bundle_hash",
        "recheck_bundle_hash", "recheck_wire_sha256", "parent_commitments",
        "g3_expected_commitment",
    )
    input_event = events[fresh_index]
    input_identity = {key: input_event.get(key) for key in identity_keys}
    if any(value is None for value in input_identity.values()):
        raise RuntimeError("fresh admission input identity is incomplete")
    for event in events[fresh_index:]:
        if any(event.get(key) != value
               for key, value in input_identity.items()):
            raise RuntimeError("diagnostic input identity changed within the run")
    if not input_event.get("input_type", "").endswith(
            "VNextT1AdmissionInputV2"):
        raise RuntimeError("diagnostic input is not VNextT1AdmissionInputV2")

    begins: dict[int, dict] = {}
    ends: dict[int, dict] = {}
    active_phase: int | None = None
    for event in events:
        name = event.get("event")
        if name == "phase_begin":
            index = event.get("phase_index")
            if type(index) is not int or index < 1 or index in begins:
                raise RuntimeError("diagnostic phase begin index is invalid")
            if active_phase is not None:
                raise RuntimeError("diagnostic phase begins overlap")
            if index != len(begins) + 1:
                raise RuntimeError("diagnostic phase begin order is not contiguous")
            if not isinstance(event.get("phase"), str) or \
                    type(event.get("source_line")) is not int or \
                    type(event.get("final_return_expression")) is not bool:
                raise RuntimeError("diagnostic phase begin fields are invalid")
            begins[index] = event
            active_phase = index
        elif name == "phase_end":
            index = event.get("phase_index")
            if type(index) is not int or index not in begins or index in ends:
                raise RuntimeError("diagnostic phase end is missing a unique begin")
            if active_phase != index:
                raise RuntimeError("diagnostic phase end order is invalid")
            begin = begins[index]
            if event.get("phase") != begin.get("phase") or \
                    event.get("source_line") != begin.get("source_line") or \
                    begin.get("final_return_expression") is not False:
                raise RuntimeError("diagnostic phase end identity is invalid")
            ends[index] = event
            active_phase = None
        elif name == "clone_result_discarded":
            if active_phase is None or \
                    begins[active_phase].get("final_return_expression") is not True:
                raise RuntimeError("clone returned before the final source expression")
        elif name == "diagnostic_stop" and active_phase is None:
            raise RuntimeError("final implicit-return marker is missing")

    if not begins:
        raise RuntimeError("diagnostic clone recorded no admission phases")
    if active_phase != max(begins):
        raise RuntimeError("diagnostic clone did not stop in the final source phase")
    final_candidates = [index for index, event in begins.items()
                        if event.get("final_return_expression") is True]
    if final_candidates != [max(begins)]:
        raise RuntimeError("diagnostic final-return phase is not unique and last")
    final_index = final_candidates[0]
    if set(ends) != set(begins) - {final_index}:
        raise RuntimeError("non-final phases are incomplete or final phase was closed")
    unmatched = sorted(set(begins) - set(ends))
    interrupted = [index for index in unmatched if index != final_index]
    if unmatched != [final_index] or interrupted:
        raise RuntimeError("diagnostic has missing or interrupted phase records")

    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise RuntimeError("diagnostic summary is malformed") from error
    if not isinstance(summary, dict):
        raise RuntimeError("diagnostic summary is not an object")
    expected_summary = {
        "schema": SUMMARY_SCHEMA,
        "diagnostic_only": True,
        "acceptance_credit": False,
        "official_admission_called": False,
        "compiler_called": False,
        "solver_called": False,
        "scipy_called": False,
        "clone_result_discarded": True,
        "outcome": EXPECTED_OUTCOME,
        "unmatched_phase_indices": [final_index],
        "intentional_final_return_phase": final_index,
        "interrupted_phase_indices": [],
        "phase_count": len(begins),
        "error": "",
    }
    mismatches = {key: {"expected": value, "actual": summary.get(key)}
                  for key, value in expected_summary.items()
                  if summary.get(key) != value}
    if mismatches:
        raise RuntimeError(f"diagnostic summary mismatch: {mismatches}")
    if not isinstance(summary.get("result_status"), str) or \
            not isinstance(summary.get("result_resolution"), str):
        raise RuntimeError("diagnostic summary result fields are incomplete")
    return {
        "event_line_count": len(events),
        "malformed_event_line_count": 0,
        "diagnostic_summary_valid": True,
        "clone_result_discarded": True,
        "terminal_diagnostic_outcome": EXPECTED_OUTCOME,
        "unmatched_phase_indices": unmatched,
        "intentional_final_return_phase": final_index,
        "interrupted_phase_indices": interrupted,
        "phase_count": len(begins),
        "candidate_id": input_identity["candidate_id"],
        "candidate_version": input_identity["candidate_version"],
        "diagnostic_clone_called": True,
        "result_status": summary["result_status"],
        "result_resolution": summary["result_resolution"],
        "transport_bundle_hash": input_identity["transport_bundle_hash"],
        "recheck_bundle_hash": input_identity["recheck_bundle_hash"],
        "g3_expected_commitment": input_identity["g3_expected_commitment"],
        "summary_sha256": sha256(summary_path),
        "last_event": terminal,
    }


def observed_clone_call(events_path: Path) -> bool:
    """Report an observed clone entry even when timeout truncates its run."""
    if not events_path.is_file():
        return False
    for raw_line in events_path.read_bytes().splitlines():
        try:
            event = json.loads(raw_line.decode("utf-8", errors="strict"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if isinstance(event, dict) and event.get("event") == "clone_call_begin":
            return True
    return False


def record_postflight_pins(supervisor: ModuleType, repo_root: Path,
                           test_dir: Path, probe_dir: Path,
                           runner_path: Path, input_hashes: dict[str, str],
                           receipt: dict,
                           total_deadline: float | None) -> None:
    receipt["postflight_started"] = True
    post_hashes = verify_pins(
        supervisor, repo_root, test_dir, probe_dir, runner_path,
        enforce_fixed=False)
    changed = sorted(name for name in set(input_hashes) | set(post_hashes)
                     if input_hashes.get(name) != post_hashes.get(name))
    receipt["postflight_input_hashes_match"] = not changed
    receipt["postflight_changed_inputs"] = changed
    receipt["postflight_input_sha256"] = post_hashes
    receipt["postflight_missing_inputs"] = sorted(
        name for name, digest in post_hashes.items() if digest is None)
    receipt["runner_sha256_post"] = post_hashes.get(
        "admission_probe_v1/runner")
    receipt["probe_sha256_post"] = post_hashes.get(
        "admission_probe_v1/probe_source")
    if changed:
        receipt["stop_reason"] = "input_pin_changed_during_probe"
    if total_deadline is not None and time.monotonic() >= total_deadline:
        receipt["postflight_deadline_expired"] = True
        receipt["stop_reason"] = "total_wall_timeout_postflight"


def load_supervisor(path: Path) -> ModuleType:
    spec = importlib.util.spec_from_file_location(
        "inhouse_q1_serial_supervisor_v1", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load the pinned Q1 serial supervisor")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def input_paths(repo_root: Path, test_dir: Path, probe_dir: Path,
                runner_path: Path) -> dict[str, Path]:
    return {
        "runner": runner_path,
        "probe_source": probe_dir / "probe_admission_v1.jl",
        "focused_fixture": test_dir / "focused_fixture.jl",
        "integration_source": repo_root / "src" / "GenomeV5" / "Integration"
        / "VNextGenomeV5IntegrationV2.jl",
        "package_source": repo_root / "src" / "Contracts"
        / "CandidateStatePackageV5NextV2.jl",
        "serial_supervisor": test_dir / "run_serial_acceptance.py",
        "project": repo_root / "Project.toml",
        "manifest": repo_root / "Manifest.toml",
        "v3_fixture_helpers": repo_root / "test" / "GenomeV5" / "Integration"
        / "VNextT2ConcreteSourceWitnessV3" / "fixture_helpers.jl",
    }


def verify_pins(supervisor: ModuleType, repo_root: Path, test_dir: Path,
                probe_dir: Path, runner_path: Path, *,
                enforce_fixed: bool = True) -> dict[str, str | None]:
    # Reuse the same full source/test/AD-45 inventory as the formal Q1 runner,
    # then add the isolated probe implementation files.
    actual = supervisor._input_pins(test_dir, repo_root)
    extra = input_paths(repo_root, test_dir, probe_dir, runner_path)
    actual.update({
        f"admission_probe_v1/{name}": (
            digest.lower() if digest is not None else None)
        for name, path in extra.items()
        for digest in (sha256(path),)
    })
    expected = {
        "focused_fixture.jl": FIXTURE_SHA256.lower(),
        "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl":
            INTEGRATION_SHA256.lower(),
        "src/Contracts/CandidateStatePackageV5NextV2.jl":
            PACKAGE_SHA256.lower(),
        "run_serial_acceptance.py": SUPERVISOR_SHA256.lower(),
        "admission_probe_v1/probe_source": PROBE_SOURCE_SHA256.lower(),
        "admission_probe_v1/focused_fixture": FIXTURE_SHA256.lower(),
        "admission_probe_v1/integration_source": INTEGRATION_SHA256.lower(),
        "admission_probe_v1/package_source": PACKAGE_SHA256.lower(),
        "admission_probe_v1/serial_supervisor": SUPERVISOR_SHA256.lower(),
    }
    changed = {
        name: {"expected": digest, "actual": actual.get(name)}
        for name, digest in expected.items() if actual.get(name) != digest
    }
    missing = [name for name, digest in actual.items() if digest is None]
    if enforce_fixed and (changed or missing):
        raise RuntimeError(
            f"input pin mismatch changed={changed} missing={missing}")
    return {name: digest.lower() if digest is not None else None
            for name, digest in actual.items()}


def build_julia_argv(supervisor: ModuleType, repo_root: Path,
                     probe_source: Path, events_path: Path,
                     summary_path: Path) -> tuple[list[str], Path]:
    configured = os.environ.get("JULIA_EXE")
    found = Path(configured).expanduser() if configured else Path(
        shutil.which("julia") or "")
    julia_exe = found.resolve() if found.is_file() else None
    if julia_exe is None:
        raise RuntimeError("Julia executable unavailable; set JULIA_EXE")
    argv = [
        str(julia_exe), "--startup-file=no", "--threads=1",
        f"--compile={supervisor.JULIA_COMPILE_MODE}",
        f"--heap-size-hint={supervisor.JULIA_HEAP_HINT}",
        f"--project={repo_root}", str(probe_source),
        "--events-jsonl", str(events_path),
        "--summary-json", str(summary_path),
    ]
    return argv, julia_exe


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    if os.name != "nt":
        raise SystemExit("NO_GO: Windows Job Object enforcement is unavailable")

    runner_path = Path(__file__).resolve()
    probe_dir = runner_path.parent
    test_dir = probe_dir.parent
    repo_root = test_dir.parents[2]
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=False)
    events_path = output_dir / "admission-events.jsonl"
    summary_path = output_dir / "diagnostic-summary.json"
    stdout_path = output_dir / "julia.stdout.log"
    stderr_path = output_dir / "julia.stderr.log"
    audit_path = output_dir / "process-tree-audit.jsonl"
    receipt_path = output_dir / "run-receipt.json"

    receipt: dict = {
        "schema": PROBE_SCHEMA,
        "diagnostic_only": True,
        "acceptance_credit": False,
        "official_admission_called": False,
        "official_public_admission_entry_called": False,
        "diagnostic_clone_called": False,
        "compiler_called": False,
        "solver_called": False,
        "scipy_called": False,
        "started_at_unix_seconds": time.time(),
        "output_directory": str(output_dir),
        "stop_reason": None,
        "julia_exit_code": None,
        "peak_sampled_tree_rss_bytes": 0,
        "peak_job_commit_bytes": 0,
        "rss_accounting_incomplete": False,
        "job_snapshot_attempts": 0,
        "job_snapshot_retries": 0,
    }
    job = None
    supervisor = None
    input_hashes = None
    total_started = None
    total_deadline = None
    try:
        supervisor_path = test_dir / "run_serial_acceptance.py"
        supervisor = load_supervisor(supervisor_path)
        input_hashes = verify_pins(
            supervisor, repo_root, test_dir, probe_dir, runner_path)
        receipt["input_sha256"] = input_hashes

        expected_settings = {
            "RSS_LIMIT_BYTES": 2 * 1024 * 1024 * 1024,
            "TOTAL_WALL_TIMEOUT_SECONDS": 240,
            "JULIA_TIMEOUT_SECONDS": 240,
            "POLL_SECONDS": 0.25,
            "JULIA_HEAP_HINT": "1G",
            "JULIA_COMPILE_MODE": "min",
        }
        actual_settings = {name: getattr(supervisor, name, None)
                           for name in expected_settings}
        receipt["resource_settings"] = actual_settings
        if actual_settings != expected_settings:
            raise RuntimeError(
                f"frozen supervisor settings changed: {actual_settings}")

        argv, julia_exe = build_julia_argv(
            supervisor, repo_root, probe_dir / "probe_admission_v1.jl",
            events_path, summary_path)
        receipt["julia_argv"] = argv
        receipt["julia_executable"] = str(julia_exe)
        receipt["julia_compile_mode"] = supervisor.JULIA_COMPILE_MODE
        receipt["julia_threads"] = 1
        receipt["julia_heap_size_hint"] = supervisor.JULIA_HEAP_HINT
        receipt["aggregate_job_commit_limit_bytes"] = supervisor.RSS_LIMIT_BYTES
        receipt["process_tree_rss_limit_bytes"] = supervisor.RSS_LIMIT_BYTES
        receipt["process_tree_sample_seconds"] = supervisor.POLL_SECONDS
        receipt["total_wall_timeout_seconds"] = (
            supervisor.TOTAL_WALL_TIMEOUT_SECONDS)

        total_started = time.monotonic()
        total_deadline = (total_started +
                          supervisor.TOTAL_WALL_TIMEOUT_SECONDS)
        job = supervisor.WindowsJob(supervisor.RSS_LIMIT_BYTES)
        exit_code = supervisor._run_in_job(
            argv, repo_root, stdout_path, stderr_path, audit_path, job,
            receipt, "admission_probe_v1",
            supervisor.JULIA_TIMEOUT_SECONDS, total_deadline)
        supervisor._require_no_pending_process_sample_handles(
            receipt, "post_admission_probe")
        receipt["julia_exit_code"] = exit_code
        receipt["diagnostic_clone_called"] = observed_clone_call(events_path)
        completion_valid = False
        try:
            completion = validate_diagnostic_completion(
                events_path, summary_path)
            receipt.update(completion)
            completion_valid = True
        except BaseException as error:
            receipt["diagnostic_validation_error"] = str(error)
            if receipt["stop_reason"] is None:
                receipt["stop_reason"] = "diagnostic_output_integrity_failure"
        if exit_code != 0 and receipt["stop_reason"] is None:
            receipt["stop_reason"] = "diagnostic_clone_nonzero_exit"

        record_postflight_pins(
            supervisor, repo_root, test_dir, probe_dir, runner_path,
            input_hashes, receipt, total_deadline)
        if receipt["stop_reason"] is None and exit_code == 0 and \
                completion_valid:
            receipt["stop_reason"] = "diagnostic_complete_zero_credit"
        elif receipt["stop_reason"] is None:
            receipt["stop_reason"] = "diagnostic_clone_nonzero_exit"
        return 0 if receipt["stop_reason"] == \
            "diagnostic_complete_zero_credit" else 2
    except BaseException as error:
        if receipt["stop_reason"] is None:
            receipt["stop_reason"] = f"supervisor_exception:{type(error).__name__}"
        receipt["supervisor_error"] = str(error)
        if receipt.get("postflight_started") and \
                "postflight_input_sha256" not in receipt:
            receipt["postflight_error"] = str(error)
        if supervisor is not None and input_hashes is not None and \
                not receipt.get("postflight_started", False):
            try:
                record_postflight_pins(
                    supervisor, repo_root, test_dir, probe_dir, runner_path,
                    input_hashes, receipt, total_deadline)
            except BaseException as postflight_error:
                receipt["postflight_error"] = str(postflight_error)
                if receipt["stop_reason"] is None:
                    receipt["stop_reason"] = "postflight_verification_failed"
        return_code = 2
        return return_code
    finally:
        if job is not None:
            try:
                if job.handle and job.active_processes() > 0:
                    job.terminate(94)
                if job.handle:
                    receipt["peak_job_commit_bytes"] = max(
                        receipt.get("peak_job_commit_bytes", 0),
                        job.peak_job_commit_bytes())
            except OSError as error:
                receipt["job_cleanup_error"] = str(error)
            job.close()
        if total_started is not None:
            receipt["total_wall_elapsed_seconds"] = max(
                0.0, time.monotonic() - total_started)
        receipt["completed_at_unix_seconds"] = time.time()
        receipt["events_sha256"] = sha256(events_path)
        receipt["diagnostic_summary_sha256"] = sha256(summary_path)
        write_json(receipt_path, receipt)
        print("ADMISSION_DIAGNOSTIC=" + str(receipt["stop_reason"]))


if __name__ == "__main__":
    raise SystemExit(main())
