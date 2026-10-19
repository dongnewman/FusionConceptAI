"""Run the V3 source-witness gates serially with frozen inputs and tree RSS."""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time

import psutil


ROOT = Path(__file__).resolve().parents[4]
TEST_DIR = Path(__file__).resolve().parent
if str(TEST_DIR) not in sys.path:
    sys.path.insert(0, str(TEST_DIR))

from shard_coverage_tools import (  # noqa: E402
    SCENARIOS,
    expected_input_pin_hash,
    load_ledger,
    parse_shard_result,
    validate_aggregate_results,
    validate_shard_result,
    validate_static_coverage,
)


EVIDENCE_ROOT = (
    ROOT
    / "docs/implementation/UP1-04A-VNEXT-T2-SOURCE-WITNESS-PREC/agent_r1_20260922"
).resolve()
HEAVY_NAMES = {
    "julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh",
    "mpiexec.exe", "mpiexec",
}
DEFAULT_TIMEOUT_SECONDS = 300.0
DEFAULT_PROCESS_TREE_RSS_BYTES = 2_147_483_648
EXPECTED_RUNTIME_JULIA_FILES = 84
HARNESS_JULIA_FILES = (
    "src/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/fixture_helpers.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
    "vnext_t2_concrete_source_witness_v3_tests.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
    "shard_test_helpers.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
    "vnext_t2_concrete_source_witness_v3_shard_tests.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/replay_child.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
    "fresh_process_replay_driver.jl",
    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl",
)
HARNESS_INCLUDE_CONTRACTS = {
    "vnext_t2_concrete_source_witness_v3_tests.jl": {"fixture_helpers.jl"},
    "shard_test_helpers.jl": {"fixture_helpers.jl"},
    "vnext_t2_concrete_source_witness_v3_shard_tests.jl": {
        "shard_test_helpers.jl"
    },
    "replay_child.jl": {"fixture_helpers.jl"},
    "fresh_process_replay_driver.jl": {"fixture_helpers.jl"},
    "parse_gate.jl": set(),
}
SHARD_LEDGER = TEST_DIR / "shard_coverage_ledger.json"
GENOME_V5_DYNAMIC_COMPONENTS = (
    "src/GenomeV5/G1/GrammarProfileV2.jl",
    "src/GenomeV5/G1/EquationPlanV2.jl",
    "src/GenomeV5/G1/MechanismGenomePayloadV2.jl",
    "src/GenomeV5/G1/MechanismGenomeV5.jl",
    "src/GenomeV5/G2/SpatialGrammarProfileV2.jl",
    "src/GenomeV5/G2/RegionInterfaceContractV2.jl",
    "src/GenomeV5/G2/FieldSpacePlanV2.jl",
    "src/GenomeV5/G2/FieldGeometryGenomeV5.jl",
    "src/GenomeV5/G3/RealizationGenomeV5.jl",
    "src/GenomeV5/G3/ControlGenomeV5.jl",
    "src/GenomeV5/G3/CoupledRealizationControlBindingV2.jl",
    "src/GenomeV5/G3/RealizationControlGenomeV5.jl",
)
T0_DEFINITION_DEPENDENCIES = (
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "src/GenomeV5/G1/DiffusionDeclarationV1.jl",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceFeedbackLawV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
)
V3_EXPLICIT_SOURCE_DEPENDENCIES = (
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV1.jl",
    "src/GenomeV5/Integration/VNextParentBaselineBindingLocalV1.jl",
    "src/GenomeV5/G3/G3RealizationChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3ControlChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV1.jl",
    "src/GenomeV5/G3/G3BindingChildEditabilityV2.jl",
    "src/GenomeV5/Integration/VNextG3BindingAuthorityBridgeLocalV1.jl",
)


def utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def receipt(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def write_new(path: Path, value: object) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, indent=2, sort_keys=True)


def heavy_processes() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for process in psutil.process_iter(["name", "cmdline", "create_time"]):
        name = (process.info.get("name") or "").lower()
        if name in HEAVY_NAMES:
            rows.append({
                "pid": process.pid,
                "name": process.info.get("name"),
                "cmdline": process.info.get("cmdline"),
                "create_time": process.info.get("create_time"),
            })
    return rows


def tree_rss(process: psutil.Process) -> tuple[int, list[int]]:
    members = [process]
    try:
        members.extend(process.children(recursive=True))
    except psutil.Error:
        pass
    total = 0
    pids: list[int] = []
    for member in members:
        try:
            total += member.memory_info().rss
            pids.append(member.pid)
        except psutil.Error:
            pass
    return total, pids


def kill_tree(process: psutil.Process) -> None:
    try:
        children = process.children(recursive=True)
    except psutil.Error:
        children = []
    for child in reversed(children):
        try:
            child.kill()
        except psutil.Error:
            pass
    try:
        process.kill()
    except psutil.Error:
        pass


def fusion_package_source_paths() -> list[Path]:
    """Return the exact static source closure loaded by `using FusionConceptAI`."""
    entry = ROOT / "src/FusionConceptAI.jl"
    text = entry.read_text(encoding="utf-8")
    relative_includes = re.findall(
        r'^\s*include\("([^"\r\n]+\.jl)"\)\s*$', text, flags=re.MULTILINE
    )
    include_call_count = len(re.findall(r"\binclude\(", text))
    if len(relative_includes) != include_call_count:
        raise RuntimeError(
            "unresolved FusionConceptAI include form: "
            f"resolved={len(relative_includes)} calls={include_call_count}"
        )
    return [entry, *(ROOT / "src" / item for item in relative_includes)]


def assert_explicit_runtime_inventory() -> None:
    """Fail if any definition-only loader gains an untracked Julia include."""
    loader = ROOT / "src/GenomeV5/Integration/GenomeV5Integration.jl"
    loader_names = set(re.findall(
        r'"([^"\r\n]+\.jl)"', loader.read_text(encoding="utf-8")
    ))
    expected_loader_names = {Path(item).name for item in GENOME_V5_DYNAMIC_COMPONENTS}
    if loader_names != expected_loader_names:
        raise RuntimeError(
            "GenomeV5 dynamic component inventory mismatch: "
            f"observed={sorted(loader_names)} expected={sorted(expected_loader_names)}"
        )

    t0_helper = ROOT / T0_DEFINITION_DEPENDENCIES[0]
    t0_preamble = t0_helper.read_text(encoding="utf-8").split(
        "# Current factory APIs", 1
    )[0]
    t0_names = set(re.findall(r'"([^"\r\n]+\.jl)"', t0_preamble))
    expected_t0_names = {Path(item).name for item in T0_DEFINITION_DEPENDENCIES[1:]}
    if t0_names != expected_t0_names:
        raise RuntimeError(
            "T0 definition include inventory mismatch: "
            f"observed={sorted(t0_names)} expected={sorted(expected_t0_names)}"
        )
    if "load_genome_v5_components!()" not in t0_preamble:
        raise RuntimeError("T0 helper no longer invokes the GenomeV5 component loader")

    fixture = TEST_DIR / "fixture_helpers.jl"
    fixture_preamble = fixture.read_text(encoding="utf-8").split(
        "const V3_CANDIDATE", 1
    )[0]
    fixture_names = set(re.findall(r'"([^"\r\n]+\.jl)"', fixture_preamble))
    expected_fixture_names = {
        Path(T0_DEFINITION_DEPENDENCIES[0]).name,
        Path(HARNESS_JULIA_FILES[0]).name,
        *(Path(item).name for item in V3_EXPLICIT_SOURCE_DEPENDENCIES),
    }
    if fixture_names != expected_fixture_names:
        raise RuntimeError(
            "V3 fixture include inventory mismatch: "
            f"observed={sorted(fixture_names)} expected={sorted(expected_fixture_names)}"
        )

    harness_by_name = {
        Path(relative).name: relative for relative in HARNESS_JULIA_FILES[2:]
    }
    if set(harness_by_name) != set(HARNESS_INCLUDE_CONTRACTS):
        raise RuntimeError(
            "V3 harness include contract inventory mismatch: "
            f"observed={sorted(harness_by_name)} "
            f"expected={sorted(HARNESS_INCLUDE_CONTRACTS)}"
        )
    for name, expected_includes in HARNESS_INCLUDE_CONTRACTS.items():
        relative = harness_by_name[name]
        harness = ROOT / relative
        included = set(re.findall(
            r'include\(joinpath\(@__DIR__,\s*"([^"\r\n]+\.jl)"\)\)',
            harness.read_text(encoding="utf-8"), flags=re.MULTILINE,
        ))
        if included != expected_includes:
            raise RuntimeError(
                f"untracked harness include in {relative}: "
                f"observed={sorted(included)} expected={sorted(expected_includes)}"
            )


def runtime_julia_paths() -> list[Path]:
    """Return the recorded pipeline closure plus the frozen monolith."""
    assert_explicit_runtime_inventory()
    paths = set(fusion_package_source_paths())
    paths.update(ROOT / item for item in GENOME_V5_DYNAMIC_COMPONENTS)
    paths.update(ROOT / item for item in T0_DEFINITION_DEPENDENCIES)
    paths.update(ROOT / item for item in V3_EXPLICIT_SOURCE_DEPENDENCIES)
    paths.update(ROOT / item for item in HARNESS_JULIA_FILES)
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError("runtime Julia dependency missing: " + json.dumps(missing))
    ordered = sorted(paths)
    if len(ordered) != EXPECTED_RUNTIME_JULIA_FILES:
        raise RuntimeError(
            "runtime Julia dependency count mismatch: "
            f"observed={len(ordered)} expected={EXPECTED_RUNTIME_JULIA_FILES}"
        )
    return ordered


def dependency_paths() -> list[Path]:
    # Freeze only the exact Julia load closure plus its Python controllers and
    # project resolution inputs.  Recompute the same closure after execution
    # so an include-list addition/removal or byte change fails the pipeline.
    paths = set(runtime_julia_paths())
    paths.update(TEST_DIR.glob("*.py"))
    paths.add(SHARD_LEDGER)
    for relative in ("Project.toml", "Manifest.toml"):
        path = ROOT / relative
        if path.is_file():
            paths.add(path)
    missing = [str(path) for path in paths if not path.is_file()]
    if missing:
        raise FileNotFoundError("dependency missing: " + json.dumps(missing))
    return sorted(paths)


def dependency_receipts() -> dict[str, dict[str, object]]:
    return {
        path.resolve().relative_to(ROOT.resolve()).as_posix(): receipt(path)
        for path in dependency_paths()
    }


def write_parse_manifest(
    path: Path,
    runtime_paths: list[Path],
    dependency_snapshot: dict[str, dict[str, object]],
) -> dict[str, object]:
    rows: list[str] = []
    for source_path in runtime_paths:
        relative = source_path.resolve().relative_to(ROOT.resolve()).as_posix()
        expected = dependency_snapshot[relative]["sha256"]
        rows.append(f"{expected}\t{relative}\n")
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        stream.writelines(rows)
    return {"entries": len(rows), **receipt(path)}


def run_step(
    output: Path,
    index: int,
    name: str,
    command: list[str],
    dependency_snapshot: dict[str, dict[str, object]],
    timeout_seconds: float,
    max_rss_bytes: int,
    environment: dict[str, str],
    artifacts: dict[str, dict[str, object]] | None = None,
) -> dict[str, object]:
    stage = output / f"{index:02d}_{name}"
    stage.mkdir()
    checkpoint = {
        "schema": "vnext_t2_source_witness_v3_checkpoint_before_assert_v1",
        "stage": name,
        "command": command,
        "created_utc": utc(),
        "dependencies": dependency_snapshot,
        "artifacts": artifacts or {},
        "timeout_seconds": timeout_seconds,
        "process_tree_rss_limit_bytes": max_rss_bytes,
    }
    # This receipt exists before the child starts and therefore before any
    # Julia `@test` or producer assertion can execute.
    write_new(stage / "checkpoint_before_assert.json", checkpoint)

    started = time.monotonic()
    started_utc = utc()
    samples: list[dict[str, object]] = []
    stop_reason = "natural_exit"
    with (stage / "stdout.raw").open("xb") as stdout, \
            (stage / "stderr.raw").open("xb") as stderr:
        process = subprocess.Popen(
            command,
            cwd=ROOT,
            env=environment,
            stdout=stdout,
            stderr=stderr,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
        observed = psutil.Process(process.pid)
        create_time = observed.create_time()
        write_new(stage / "start.json", {
            "schema": "vnext_t2_source_witness_v3_recorded_stage_v1",
            "stage": name,
            "command": command,
            "cwd": str(ROOT),
            "pid": process.pid,
            "process_create_time": create_time,
            "started_utc": started_utc,
            "timeout_seconds": timeout_seconds,
            "process_tree_rss_limit_bytes": max_rss_bytes,
            "environment": {
                "JULIA_NUM_THREADS": environment["JULIA_NUM_THREADS"],
                "VNEXT_T2_SOURCE_WITNESS_TRACE":
                    environment["VNEXT_T2_SOURCE_WITNESS_TRACE"],
            },
        })
        with (stage / "samples.jsonl").open(
                "x", encoding="utf-8", newline="\n", buffering=1) as stream:
            while process.poll() is None:
                try:
                    if observed.create_time() != create_time:
                        stop_reason = "pid_ownership_invalid"
                        break
                    rss, pids = tree_rss(observed)
                    sample = {
                        "utc": utc(),
                        "root_pid": process.pid,
                        "process_tree_pids": pids,
                        "process_tree_rss_bytes": rss,
                        "elapsed_seconds": time.monotonic() - started,
                    }
                    samples.append(sample)
                    stream.write(json.dumps(sample, sort_keys=True) + "\n")
                    if rss >= max_rss_bytes:
                        stop_reason = "process_tree_rss_limit"
                        break
                    if time.monotonic() - started >= timeout_seconds:
                        stop_reason = "wall_timeout"
                        break
                except psutil.NoSuchProcess:
                    break
                time.sleep(0.2)
            if process.poll() is None and stop_reason != "natural_exit":
                kill_tree(observed)
            exit_code = process.wait()

    final = {
        "schema": "vnext_t2_source_witness_v3_recorded_stage_v1",
        "index": index,
        "stage": name,
        "command": command,
        "started_utc": started_utc,
        "ended_utc": utc(),
        "elapsed_seconds": time.monotonic() - started,
        "exit_code": exit_code,
        "stop_reason": stop_reason,
        "peak_process_tree_rss_bytes": max(
            (int(sample["process_tree_rss_bytes"]) for sample in samples),
            default=0,
        ),
        "stdout": receipt(stage / "stdout.raw"),
        "stderr": receipt(stage / "stderr.raw"),
    }
    write_new(stage / "final.json", final)
    return final


def stage_directory(output: Path, stage: dict[str, object]) -> Path:
    return output / f"{int(stage['index']):02d}_{stage['stage']}"


def validate_recorded_shard(
    output: Path,
    stage: dict[str, object],
    scenario: str,
    ledger: dict[str, object],
    input_pin_hash: str,
) -> dict[str, object]:
    stdout = (stage_directory(output, stage) / "stdout.raw").read_text(
        encoding="utf-8", errors="replace"
    )
    summary_tokens = (
        "Test Summary:",
        f"VNext T2 concrete native source witness V3 shard {scenario}",
    )
    missing = [token for token in summary_tokens if token not in stdout]
    if missing:
        raise AssertionError(
            "shard-natural-test-summary-missing:" + json.dumps(missing)
        )
    observed = parse_shard_result(stdout)
    validate_shard_result(observed, scenario, ledger, input_pin_hash)
    validation = {
        "schema": "vnext_t2_source_witness_v3_shard_stage_validation_v1",
        "status": "pass",
        "natural_test_summary": True,
        **observed,
    }
    write_new(
        stage_directory(output, stage) / "shard_receipt_validation.json",
        validation,
    )
    return observed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--julia", default="julia")
    parser.add_argument("--timeout-per-step", type=float,
                        default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--max-rss-bytes", type=int,
                        default=DEFAULT_PROCESS_TREE_RSS_BYTES)
    args = parser.parse_args()
    if args.timeout_per_step <= 0 or args.max_rss_bytes <= 0:
        parser.error("timeout and RSS limit must be positive")

    output = (ROOT / args.out).resolve()
    output.relative_to(EVIDENCE_ROOT)
    if output == EVIDENCE_ROOT:
        raise ValueError("output must be a new child of the evidence leaf")
    if heavy_processes():
        raise RuntimeError(
            "serialized heavy lane occupied: " + json.dumps(heavy_processes())
        )
    output.mkdir(parents=True, exist_ok=False)
    artifact_directory = output / "artifacts"
    artifact_directory.mkdir()

    lock_path = ROOT / "tmp/vnext_t2_source_witness_v3_runtime.lock"
    lock_path.parent.mkdir(exist_ok=True)
    runtime_paths = runtime_julia_paths()
    dependencies_before = dependency_receipts()
    shard_ledger = load_ledger(SHARD_LEDGER)
    static_shard_coverage = validate_static_coverage(
        ROOT, TEST_DIR, shard_ledger
    )
    shard_input_pin_hash = expected_input_pin_hash(dependencies_before)
    shard_ledger_receipt = receipt(SHARD_LEDGER)
    parse_manifest_path = output / "runtime_parse_manifest.tsv"
    parse_manifest_receipt = write_parse_manifest(
        parse_manifest_path, runtime_paths, dependencies_before
    )
    environment = os.environ.copy()
    environment["JULIA_NUM_THREADS"] = "1"
    environment["VNEXT_T2_SOURCE_WITNESS_TRACE"] = "1"
    commands: list[tuple[str, list[str], str | None]] = [
        ("static_qa", [
            sys.executable, "-B",
            "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
            "static_qa_vnext_t2_concrete_source_witness_v3.py",
        ], None),
        ("parse_gate", [
            args.julia, "--startup-file=no", "--project=.",
            "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/parse_gate.jl",
            str(parse_manifest_path),
        ], None),
    ]
    commands.extend(
        (
            f"shard_{scenario}",
            [
                args.julia, "--startup-file=no", "--project=.",
                "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
                "vnext_t2_concrete_source_witness_v3_shard_tests.jl",
                scenario,
            ],
            scenario,
        )
        for scenario in SCENARIOS
    )

    stages: list[dict[str, object]] = []
    pipeline_status = "running"
    write_new(output / "pipeline_start.json", {
        "schema": "vnext_t2_source_witness_v3_recorded_pipeline_v1",
        "created_utc": utc(),
        "harness_julia_files": HARNESS_JULIA_FILES,
        "runtime_julia_files": [
            path.resolve().relative_to(ROOT.resolve()).as_posix()
            for path in runtime_paths
        ],
        "runtime_parse_manifest": parse_manifest_receipt,
        "shard_coverage_ledger": shard_ledger_receipt,
        "static_shard_coverage": static_shard_coverage,
        "shard_scenarios": list(SCENARIOS),
        "shard_input_pin_sha256": shard_input_pin_hash,
        "timeout_per_step_seconds": args.timeout_per_step,
        "process_tree_rss_limit_bytes": args.max_rss_bytes,
        "dependencies_before": dependencies_before,
        "baseline_heavy_processes": [],
        "formal_consumer_count": 0,
    })
    with lock_path.open("x", encoding="utf-8", newline="\n") as lock:
        json.dump({"owner": "vnext_t2_source_witness_v3",
                   "controller_pid": os.getpid(), "created_utc": utc()}, lock)
    try:
        shard_receipts: dict[str, dict[str, object]] = {}
        for index, (name, command, scenario) in enumerate(commands, start=1):
            checkpoint_artifacts = None
            if name == "parse_gate":
                checkpoint_artifacts = {
                    "runtime_parse_manifest.tsv": parse_manifest_receipt,
                }
            elif scenario is not None:
                checkpoint_artifacts = {
                    "shard_coverage_ledger.json": shard_ledger_receipt,
                    "expected_input_pin": {"sha256": shard_input_pin_hash},
                }
            result = run_step(
                output, index, name, command, dependencies_before,
                args.timeout_per_step, args.max_rss_bytes, environment,
                artifacts=checkpoint_artifacts,
            )
            stages.append(result)
            if result["exit_code"] != 0 or result["stop_reason"] != "natural_exit":
                pipeline_status = "failed"
                break
            if scenario is not None:
                try:
                    shard_receipts[scenario] = validate_recorded_shard(
                        output, result, scenario, shard_ledger,
                        shard_input_pin_hash,
                    )
                except Exception as exc:
                    write_new(
                        stage_directory(output, result)
                        / "shard_receipt_validation.json",
                        {
                            "schema": (
                                "vnext_t2_source_witness_v3_"
                                "shard_stage_validation_v1"
                            ),
                            "status": "fail",
                            "scenario": scenario,
                            "error": f"{type(exc).__name__}:{exc}",
                        },
                    )
                    pipeline_status = "failed"
                    break

        shard_coverage: dict[str, object] = {}
        shard_coverage_receipt: dict[str, object] = {}
        if pipeline_status == "running":
            shard_coverage = validate_aggregate_results(
                shard_receipts, shard_ledger
            )
            shard_coverage.update({
                "static_coverage": static_shard_coverage,
                "input_pin_sha256": shard_input_pin_hash,
                "formal_consumer_count": 0,
            })
            shard_coverage_path = output / "shard_runtime_coverage.json"
            write_new(shard_coverage_path, shard_coverage)
            shard_coverage_receipt = receipt(shard_coverage_path)

        artifact_receipts: dict[str, dict[str, object]] = {}
        if pipeline_status == "running":
            producer_command = [
                args.julia, "--startup-file=no", "--project=.",
                "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
                "fresh_process_replay_driver.jl",
                str(artifact_directory),
            ]
            producer_result = run_step(
                output, len(stages) + 1, "artifact_producer",
                producer_command, dependencies_before,
                args.timeout_per_step, args.max_rss_bytes, environment,
                artifacts={
                    "shard_runtime_coverage.json": shard_coverage_receipt,
                },
            )
            stages.append(producer_result)
            if (producer_result["exit_code"] != 0 or
                    producer_result["stop_reason"] != "natural_exit"):
                pipeline_status = "failed"

        if pipeline_status == "running":
            missing_artifacts: list[str] = []
            for name in ("baseline-witness.jls", "foreign-witness.jls"):
                path = artifact_directory / name
                if not path.is_file():
                    missing_artifacts.append(name)
                    continue
                artifact_receipts[name] = receipt(path)
            if missing_artifacts:
                write_new(output / "artifact_validation.json", {
                    "schema": "vnext_t2_source_witness_v3_artifact_validation_v1",
                    "status": "fail",
                    "missing": missing_artifacts,
                })
                pipeline_status = "failed"

        if pipeline_status == "running":
            replay_commands = (
                ("fresh_baseline", "baseline-witness.jls", "source_ready"),
                ("fresh_foreign", "foreign-witness.jls", "fail_closed"),
            )
            for index, (name, artifact, expected) in enumerate(
                    replay_commands, start=len(stages) + 1):
                command = [
                    args.julia, "--startup-file=no", "--project=.",
                    "test/GenomeV5/Integration/VNextT2ConcreteSourceWitnessV3/"
                    "replay_child.jl",
                    str(artifact_directory / artifact), expected,
                ]
                result = run_step(
                    output, index, name, command, dependencies_before,
                    args.timeout_per_step, args.max_rss_bytes, environment,
                    artifacts={
                        **artifact_receipts,
                        "shard_runtime_coverage.json": shard_coverage_receipt,
                    },
                )
                stages.append(result)
                if result["exit_code"] != 0 or result["stop_reason"] != "natural_exit":
                    pipeline_status = "failed"
                    break
        pipeline_status = "passed" if pipeline_status == "running" else pipeline_status
    finally:
        lock_path.unlink(missing_ok=True)

    dependencies_after = dependency_receipts()
    input_changes = sorted(
        set(dependencies_before) ^ set(dependencies_after)
        | {
            path for path in set(dependencies_before) & set(dependencies_after)
            if dependencies_before[path] != dependencies_after[path]
        }
    )
    residual_heavy = heavy_processes()
    if input_changes or residual_heavy:
        pipeline_status = "failed"
    stdout_contracts = {
        "fresh_baseline": "status=source_ready",
        "fresh_foreign": "status=fail_closed",
    }
    for stage in stages:
        expected = stdout_contracts.get(str(stage["stage"]))
        if expected is None:
            continue
        stdout = (stage_directory(output, stage) / "stdout.raw").read_text(
            encoding="utf-8", errors="replace"
        )
        if expected not in stdout:
            pipeline_status = "failed"

    final = {
        "schema": "vnext_t2_source_witness_v3_recorded_pipeline_v1",
        "status": pipeline_status,
        "ended_utc": utc(),
        "stages": stages,
        "artifact_receipts": artifact_receipts if "artifact_receipts" in locals() else {},
        "shard_coverage": shard_coverage if "shard_coverage" in locals() else {},
        "shard_coverage_receipt": (
            shard_coverage_receipt
            if "shard_coverage_receipt" in locals() else {}
        ),
        "dependencies_before": dependencies_before,
        "dependencies_after": dependencies_after,
        "input_changes": input_changes,
        "residual_heavy_processes": residual_heavy,
        "formal_consumer_count": 0,
        "formal_t1_accepted": False,
    }
    write_new(output / "pipeline_final.json", final)
    print(json.dumps(final, sort_keys=True), flush=True)
    return 0 if pipeline_status == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
