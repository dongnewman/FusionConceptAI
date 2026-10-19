"""Freeze and replay the bounded UP2-00 contract consumer from copied bytes.

This is a limited software-contract handoff. It does not accept UP1/T1, T2,
solver, mesh, provider, physical, engineering, or scientific results.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Callable


sys.dont_write_bytecode = True

HANDOFF_SCHEMA = "up1-04a-vnext-limited-up2-00-frozen-handoff-v1"
CLOSURE_AUDIT_SCHEMA = "up1-consumer-closure-readonly-audit-v1"
CONSUMER_RUNNER = "test/GenomeV5/UP2/run_up2_00_contract.jl"
FIXTURE_RELATIVE = "test/GenomeV5/UP2/fixtures.json"
FIXTURE_ID = "UP2-00-N01-N10-001"
EXPECTED_CANDIDATE_REF = "fusionconceptai://candidate/candidate-1@v5"
EXPECTED_MUTATION_COUNT = 50
EXPECTED_N01_N02_COUNT = 10
WALL_LIMIT_SECONDS = 240
MEMORY_LIMIT_BYTES = 2_147_483_648
SAMPLE_SECONDS = 0.25
RUNNER_RELATIVE = "scripts/run_bounded_check.py"
SUPERVISOR_RELATIVE = "test/RuntimeV4/InHouseG1G2Q1SolverV1/run_serial_acceptance.py"
SNAPSHOT_HELPER_RELATIVE = "tools/execution/t2_source_inputs.py"
WORKSPACE_READER_RELATIVE = "tools/workspace_sources.py"
IDENTITY_MARKER = "UP1_04A_VNEXT_UP2_IDENTITY="


@dataclass(frozen=True)
class FrozenHandoff:
    root: Path
    snapshot_root: Path
    manifest_sha256: str
    snapshot_id: str
    candidate_ref: str
    fixture_id: str
    mutation_ids: tuple[str, ...]
    closure_paths: tuple[str, ...]
    support_sources: tuple[dict[str, Any], ...]
    snapshot: Any


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _file_pin(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {"path": str(path), "bytes": len(raw), "sha256": _sha256(raw)}


def _write_new_json(path: Path, value: dict[str, Any]) -> None:
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())


def _strict_json(raw: bytes, label: str) -> dict[str, Any]:
    def unique_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate JSON key in {label}: {key}")
            result[key] = value
        return result

    value = json.loads(raw.decode("utf-8", errors="strict"),
                       object_pairs_hook=unique_pairs)
    if type(value) is not dict:
        raise ValueError(f"{label} root must be an object")
    return value


def _load_snapshot_api(repository_root: Path, audited_rows: dict[str, dict[str, Any]]):
    root = repository_root.resolve(strict=True)
    helper = root / SNAPSHOT_HELPER_RELATIVE
    workspace_reader = root / WORKSPACE_READER_RELATIVE
    support_paths = ((SNAPSHOT_HELPER_RELATIVE, helper),
                     (WORKSPACE_READER_RELATIVE, workspace_reader))
    before = []
    for logical, path in support_paths:
        if not path.is_file() or path.is_symlink():
            raise RuntimeError(f"frozen snapshot support source is missing or not regular: {path}")
        pin = _file_pin(path)
        audited = audited_rows.get(logical)
        if audited is None or pin["bytes"] != audited["bytes"] or pin["sha256"] != audited["sha256"]:
            raise RuntimeError(f"snapshot support source differs from independent audit: {logical}")
        before.append({"logical_path": logical, **pin})
    sys.path.insert(0, str(root))
    module = importlib.import_module("tools.execution.t2_source_inputs")
    if Path(module.__file__).resolve(strict=True) != helper.resolve(strict=True):
        raise RuntimeError("snapshot helper was imported from an unexpected path")
    reader_module = sys.modules.get("tools.workspace_sources")
    reader_file = getattr(reader_module, "__file__", None)
    if reader_file is None or Path(reader_file).resolve(strict=True) != workspace_reader.resolve(strict=True):
        raise RuntimeError("snapshot workspace reader was imported from an unexpected path")
    after = [{"logical_path": logical, **_file_pin(path)}
             for logical, path in support_paths]
    if before != after:
        raise RuntimeError("snapshot support sources changed while the helper was imported")
    return module.FrozenInputSnapshot, tuple(after)


def _require_no_formal_t2_environment() -> None:
    present = sorted(name for name in os.environ if name.startswith("FUSION_T2_"))
    if present:
        raise RuntimeError(f"limited UP2-00 handoff rejects inherited formal T2 markers: {present}")


def _closure_paths(repository_root: Path, closure_audit_path: Path,
                   expected_audit_sha256: str, *,
                   validate_sources: bool = True) -> tuple[tuple[str, ...], dict[str, dict[str, Any]]]:
    raw = closure_audit_path.read_bytes()
    if _sha256(raw) != expected_audit_sha256.lower():
        raise RuntimeError("consumer closure audit raw SHA-256 mismatch")
    audit = _strict_json(raw, "consumer closure audit")
    if audit.get("schema") != CLOSURE_AUDIT_SCHEMA or \
            audit.get("consumer") != "UP2-00 typed contract smoke only" or \
            audit.get("execution_performed") is not False or \
            audit.get("formal_up1_acceptance") is not False or \
            audit.get("t2_fixture_inventory_present") is not False:
        raise RuntimeError("closure audit is not the reviewed limited UP2-00 audit")
    required = audit.get("required_result_contract")
    if type(required) is not dict or required.get("fixture_id") != FIXTURE_ID or \
            required.get("mutation_count") != EXPECTED_MUTATION_COUNT or \
            required.get("N01_N02") != "fail_closed" or \
            required.get("remaining_mutations") != 39 or \
            required.get("active_mutations") != 11 or \
            required.get("pending_mutations") != 39 or \
            required.get("provider_compile_solver_calls") != 0:
        raise RuntimeError("closure audit has a stale UP2-00 result contract")
    rows = audit.get("closure")
    runtime_tools = audit.get("runtime_tools")
    runtime_support = audit.get("runtime_support")
    if type(rows) is not list or not rows or audit.get("closure_count") != len(rows) or \
            type(runtime_tools) is not list or audit.get("runtime_tools_count") != len(runtime_tools) or \
            type(runtime_support) is not list or audit.get("runtime_support_count") != len(runtime_support) or \
            audit.get("total_unique_file_rows") != len(rows) + len(runtime_tools) + len(runtime_support):
        raise RuntimeError("closure audit row count is missing or inconsistent")
    expected_tools = {RUNNER_RELATIVE, SUPERVISOR_RELATIVE}
    expected_support = {SNAPSHOT_HELPER_RELATIVE, WORKSPACE_READER_RELATIVE}
    if {row.get("path") for row in runtime_tools if type(row) is dict} != expected_tools or \
            {row.get("path") for row in runtime_support if type(row) is dict} != expected_support:
        raise RuntimeError("closure audit runtime tool/support categories changed")
    audited_paths: list[str] = []
    audited_rows: dict[str, dict[str, Any]] = {}
    aliases: set[str] = set()
    for row in (*rows, *runtime_tools, *runtime_support):
        if type(row) is not dict or not {"path", "bytes", "sha256"}.issubset(row) or \
                (row in rows and set(row) != {"path", "bytes", "sha256"}):
            raise RuntimeError("closure/runtime audit row has an unexpected shape")
        relative = row["path"]
        if type(relative) is not str or not relative or "\\" in relative or \
                relative.startswith("/") or ":" in relative or \
                any(part in ("", ".", "..") for part in relative.split("/")):
            raise RuntimeError("closure audit contains a noncanonical relative path")
        if type(row["bytes"]) is not int or row["bytes"] < 0 or \
                type(row["sha256"]) is not str or \
                re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is None:
            raise RuntimeError("closure audit row has an invalid byte/hash pin")
        alias = relative.casefold()
        if alias in aliases:
            raise RuntimeError("closure audit contains duplicate/case-alias paths")
        aliases.add(alias)
        if validate_sources:
            source = repository_root.joinpath(*relative.split("/"))
            absolute_source = Path(os.path.abspath(os.fspath(source)))
            for component in reversed((absolute_source, *absolute_source.parents)):
                try:
                    info = component.lstat()
                except FileNotFoundError as error:
                    raise RuntimeError(f"consumer source path component is missing: {component}") from error
                if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x0400:
                    raise RuntimeError(f"consumer source path contains a symlink/reparse point: {component}")
            if not source.is_file() or source.is_symlink():
                raise RuntimeError(f"declared consumer input is missing or not regular: {relative}")
            raw = source.read_bytes()
            if len(raw) != row["bytes"] or _sha256(raw) != row["sha256"]:
                raise RuntimeError(f"consumer source differs from independent closure pin: {relative}")
        if relative in audited_rows:
            raise RuntimeError("closure audit repeats a path across categories")
        audited_rows[relative] = {"path": relative, "bytes": row["bytes"], "sha256": row["sha256"]}
        if row in rows:
            audited_paths.append(relative)
    if len(set(audited_paths)) != len(audited_paths):
        raise RuntimeError("closure audit contains duplicate paths")

    if not validate_sources:
        return tuple(sorted(audited_rows)), audited_rows

    # Re-enumerate from the current package include graph, its explicit
    # G1/G2/G3 loader, and the reviewed consumer roots. Hashes are always
    # regenerated from current bytes below; the audit contributes only the
    # reviewed roots and expected path set.
    direct = audit.get("direct_runtime_dependencies")
    if type(direct) is not list or any(type(path) is not str for path in direct):
        raise RuntimeError("closure audit direct runtime dependency list is malformed")
    expected_roots = {
        "Project.toml", "Manifest.toml", CONSUMER_RUNNER,
        "test/GenomeV5/UP2/up2_00_contract_tests.jl", FIXTURE_RELATIVE,
        "test/GenomeV5/UP1-04/fixtures.json",
        "test/GenomeV5/UP1-04/layer_fixture_child.jl",
    }
    if not expected_roots.issubset(set(direct)):
        raise RuntimeError("closure audit direct roots omit required UP2-00 inputs")
    computed = set(direct)
    include_literal = re.compile(r'\binclude\s*\(\s*"([^"]+)"\s*\)')
    include_dir = re.compile(r'\binclude\s*\(\s*joinpath\s*\(\s*@__DIR__\s*,([^)]*)\)')
    pending = ["src/FusionConceptAI.jl"]
    visited: set[str] = set()
    while pending:
        parent = pending.pop()
        if parent in visited:
            continue
        visited.add(parent)
        source_path = repository_root.joinpath(*parent.split("/"))
        if not source_path.is_file() or source_path.is_symlink():
            raise RuntimeError(f"current package include is missing or not regular: {parent}")
        computed.add(parent)
        text = source_path.read_text(encoding="utf-8")
        for literal in include_literal.findall(text):
            child = (Path(parent).parent / Path(literal)).as_posix()
            child = child.removeprefix("./")
            if child not in visited:
                pending.append(child)
        for argument in include_dir.findall(text):
            components = re.findall(r'"([^"]+)"', argument)
            if not components:
                continue
            child = Path(parent).parent.joinpath(*components).as_posix()
            child = child.replace("\\", "/")
            normalized = Path(child)
            if normalized.is_absolute() or ".." in normalized.parts:
                normalized = Path(os.path.normpath(child))
            child = normalized.as_posix()
            if child not in visited:
                pending.append(child)

    # Check the two reviewed top-level Base.include edges that close the
    # compatibility module loaded by this consumer.
    base_include_edges = {
        "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl": "NativeGitReadCompatibilityV1.jl",
        "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl": "ManagedExternalProcessV1.jl",
    }
    for parent, expected_name in base_include_edges.items():
        if parent not in computed:
            raise RuntimeError(f"closure omits Base.include owner: {parent}")
        source_path = repository_root.joinpath(*parent.split("/"))
        text = source_path.read_text(encoding="utf-8")
        edge_pattern = re.compile(
            rf'\bBase\.include\s*\(\s*@__MODULE__\s*,\s*joinpath\s*\(\s*@__DIR__\s*,\s*"{re.escape(expected_name)}"\s*\)\s*\)')
        if len(edge_pattern.findall(text)) != 1:
            raise RuntimeError(f"reviewed Base.include edge changed: {parent} -> {expected_name}")
        computed.add((Path(parent).parent / expected_name).as_posix())

    loader = repository_root / "src/GenomeV5/Integration/GenomeV5Integration.jl"
    loader_text = loader.read_text(encoding="utf-8")
    layer_groups = re.findall(
        r'\(\s*:\w+\s*,\s*\((.*?)\)\s*,\s*"(G[123])"\s*\)',
        loader_text, re.DOTALL)
    dynamic_components: set[str] = set()
    for file_group, layer in layer_groups:
        for filename in re.findall(r'"([^"/\\]+\.jl)"', file_group):
            dynamic_components.add(f"src/GenomeV5/{layer}/{filename}")
    if not dynamic_components:
        raise RuntimeError("current G1/G2/G3 dynamic loader closure is not recognizable")
    computed.update(dynamic_components)
    computed.update({
        "test/GenomeV5/G1/up1_g1_contract_tests.jl", "test/GenomeV5/G1/fixtures.json",
        "test/GenomeV5/G2/up1_g2_contract_tests.jl", "test/GenomeV5/G2/fixtures.json",
        "test/GenomeV5/G3/up1_g3_contract_tests.jl", "test/GenomeV5/G3/fixtures.json",
    })
    missing_dynamic = dynamic_components - set(audited_paths)
    if missing_dynamic:
        raise RuntimeError(f"closure audit omits current dynamic layer inputs: {sorted(missing_dynamic)}")
    if computed != set(audited_paths):
        raise RuntimeError("reviewed closure path set differs from the current include/dependency graph")
    return tuple(sorted(audited_rows)), audited_rows


def _candidate_ref_from_source(source: bytes) -> str:
    text = source.decode("utf-8", errors="strict")
    literal = 'G.QualifiedRefV1("fusionconceptai://candidate/candidate-1", "v5")'
    if literal not in text:
        raise RuntimeError("UP2-00 candidate source differs from the expected candidate")
    return EXPECTED_CANDIDATE_REF


def _scenario_from_snapshot(snapshot: Any, project_name: str) -> tuple[str, tuple[str, ...], dict[str, Any]]:
    fixture_key = f"{project_name}/{FIXTURE_RELATIVE}"
    fixture_row = snapshot.entries.get(fixture_key)
    if fixture_row is None:
        raise RuntimeError("frozen snapshot omits the UP2-00 scenario fixture")
    fixture_raw = snapshot.read_bytes(fixture_key, fixture_row["bytes"],
                                      fixture_row["sha256"])
    fixture = _strict_json(fixture_raw, "UP2-00 scenario fixture")
    if fixture.get("fixture_id") != FIXTURE_ID or \
            fixture.get("schema_id") != "GenomeV5/UP2/TypedPrecompilerContractV1" or \
            str(fixture.get("schema_version")) != "v2" or \
            fixture.get("schema_validation_only") is not True or \
            fixture.get("mutation_count") != EXPECTED_MUTATION_COUNT:
        raise RuntimeError("UP2-00 fixture identity/count differs from the bounded contract")
    mutations = fixture.get("mutations")
    if type(mutations) is not list or len(mutations) != EXPECTED_MUTATION_COUNT:
        raise RuntimeError("UP2-00 fixture mutation table is not the declared 50 rows")
    ids: list[str] = []
    class_counts: dict[str, int] = {}
    pending_count = 0
    n04_02_rows: list[dict[str, Any]] = []
    for mutation in mutations:
        if type(mutation) is not dict or type(mutation.get("id")) is not str:
            raise RuntimeError("UP2-00 mutation row is malformed")
        mutation_id = mutation["id"]
        if not mutation_id or mutation_id in ids:
            raise RuntimeError("UP2-00 mutation ids are empty or duplicated")
        ids.append(mutation_id)
        class_id = mutation.get("class_id")
        if type(class_id) is not str:
            raise RuntimeError("UP2-00 mutation class id is malformed")
        class_counts[class_id] = class_counts.get(class_id, 0) + 1
        mutation_kind = mutation.get("mutation_kind")
        if type(mutation_kind) is not str or not mutation_kind:
            raise RuntimeError("UP2-00 mutation kind is malformed")
        pending_count += class_id not in ("N01", "N02") and mutation_id != "N04-02"
        if mutation_id == "N04-02":
            n04_02_rows.append(mutation)
    n01_n02 = class_counts.get("N01", 0) + class_counts.get("N02", 0)
    if n01_n02 != EXPECTED_N01_N02_COUNT:
        raise RuntimeError("UP2-00 N01/N02 rows differ from the ten-row contract")
    active_count = len(ids) - pending_count
    if pending_count != 39 or active_count != 11 or len(n04_02_rows) != 1 or \
            n04_02_rows[0].get("mutation_kind") != "duplicate_account_ids" or \
            n04_02_rows[0].get("expected_error") != "invalid_closure":
        raise RuntimeError("UP2-00 pending/active N04-02 status differs from the 39+11 contract")
    return FIXTURE_ID, tuple(ids), {
        "fixture_id": FIXTURE_ID,
        "fixture_sha256": _sha256(fixture_raw),
        "mutation_count": len(ids),
        "mutation_ids": ids,
        "class_counts": class_counts,
        "n01_n02_count": n01_n02,
        "pending_count": pending_count,
        "active_count": active_count,
        "n04_02_status": n04_02_rows[0]["mutation_kind"],
    }


def freeze_inputs(repository_root: Path, snapshot_root: Path,
                  closure_audit_path: Path, expected_closure_audit_sha256: str,
                  *, _after_capture_for_test: Callable[[], None] | None = None) -> FrozenHandoff:
    """Copy current bytes for the reviewed logical closure into a fresh snapshot.

    The private hook exists only for deterministic negative controls: it runs
    after source bytes are pinned in memory and before the freezer copies them.
    """
    _require_no_formal_t2_environment()
    root = repository_root.resolve(strict=True)
    snapshot_target = Path(os.path.abspath(os.fspath(snapshot_root)))
    try:
        snapshot_target.relative_to(root / "runs")
    except ValueError as error:
        raise RuntimeError("frozen snapshot must be under repository runs for bounded pinning") from error
    audit_path = closure_audit_path.resolve(strict=True)
    try:
        audit_path.relative_to(root / "runs")
    except ValueError as error:
        raise RuntimeError("closure audit must be retained under repository runs") from error
    paths, audited_rows = _closure_paths(root, audit_path, expected_closure_audit_sha256)
    snapshot_api, support_sources = _load_snapshot_api(root, audited_rows)
    rows: list[dict[str, Any]] = []
    for relative in paths:
        raw = root.joinpath(*relative.split("/")).read_bytes()
        audited = audited_rows[relative]
        if len(raw) != audited["bytes"] or _sha256(raw) != audited["sha256"]:
            raise RuntimeError(f"captured consumer bytes differ from the independent audit: {relative}")
        suffix = Path(relative).suffix.lower()
        role = ("project_configuration" if relative in ("Project.toml", "Manifest.toml")
                else "runtime_tool" if relative in (RUNNER_RELATIVE, SUPERVISOR_RELATIVE)
                else "snapshot_support" if relative in (SNAPSHOT_HELPER_RELATIVE, WORKSPACE_READER_RELATIVE)
                else "fixture_data" if suffix in (".json", ".toml", ".csv")
                else "consumer_executable_source")
        rows.append({"logical_path": f"{root.name}/{relative}", "role": role,
                     "bytes": len(raw), "sha256": _sha256(raw)})
    confirm_paths, confirm_rows = _closure_paths(root, audit_path, expected_closure_audit_sha256)
    if confirm_paths != paths or confirm_rows != audited_rows:
        raise RuntimeError("consumer closure changed while source bytes were captured")
    if _after_capture_for_test is not None:
        _after_capture_for_test()
    snapshot = snapshot_api.freeze(root.parent, snapshot_root, rows)
    snapshot.verify_all()
    project_root = snapshot.root / root.name
    consumer_source = snapshot.read_bytes(
        f"{root.name}/test/GenomeV5/UP2/up2_00_contract_tests.jl",
        snapshot.entries[f"{root.name}/test/GenomeV5/UP2/up2_00_contract_tests.jl"]["bytes"],
        snapshot.entries[f"{root.name}/test/GenomeV5/UP2/up2_00_contract_tests.jl"]["sha256"])
    candidate_ref = _candidate_ref_from_source(consumer_source)
    fixture_id, mutation_ids, _ = _scenario_from_snapshot(snapshot, root.name)
    support_rows = tuple({"logical_path": key, **_file_pin(root / key)}
                         for key in (SNAPSHOT_HELPER_RELATIVE, WORKSPACE_READER_RELATIVE))
    for pin in support_rows:
        audited = audited_rows[pin["logical_path"]]
        if pin["bytes"] != audited["bytes"] or pin["sha256"] != audited["sha256"]:
            raise RuntimeError("snapshot support source differs from its independent audit row")
    return FrozenHandoff(project_root, snapshot.root, snapshot.manifest_sha256,
                         snapshot.snapshot_id, candidate_ref, fixture_id,
                         mutation_ids, tuple(f"{root.name}/{path}" for path in paths),
                         support_rows, snapshot)


def verify_inputs(repository_root: Path, snapshot_root: Path, *, expected_manifest_sha256: str,
                  expected_snapshot_id: str,
                  closure_audit_path: Path,
                  expected_closure_audit_sha256: str,
                  expected_support_sources: tuple[dict[str, Any], ...] | None = None) -> FrozenHandoff:
    """Admit only a complete, pinned snapshot and the fixed UP2-00 candidate."""
    _require_no_formal_t2_environment()
    repository = repository_root.resolve(strict=True)
    audit_path = closure_audit_path.resolve(strict=True)
    try:
        audit_path.relative_to(repository / "runs")
    except ValueError as error:
        raise RuntimeError("consumer closure audit must be under repository runs") from error
    closure_paths, audited_rows = _closure_paths(
        repository, audit_path, expected_closure_audit_sha256, validate_sources=False)
    snapshot_api, support_sources = _load_snapshot_api(repository, audited_rows)
    root = snapshot_root.resolve(strict=True)
    if expected_support_sources is not None and support_sources != expected_support_sources:
        raise RuntimeError("frozen snapshot support sources changed since capture")
    snapshot = snapshot_api.open(root, expected_manifest_sha256)
    snapshot.verify_all()
    if snapshot.snapshot_id != expected_snapshot_id.lower():
        raise RuntimeError("frozen input inventory identity differs from the caller pin")
    project_root = root / repository.name
    snapshot_paths, snapshot_audit_rows = _closure_paths(
        project_root, audit_path, expected_closure_audit_sha256)
    if snapshot_paths != closure_paths or snapshot_audit_rows != audited_rows:
        raise RuntimeError("frozen snapshot no longer matches the audited closure graph")
    expected_paths = tuple(f"{repository.name}/{relative}" for relative in closure_paths)
    if tuple(snapshot.entries.keys()) != expected_paths:
        raise RuntimeError("frozen snapshot membership differs from the independently audited closure")
    for relative in closure_paths:
        expected = audited_rows[relative]
        row = snapshot.entries[f"{repository.name}/{relative}"]
        if row["bytes"] != expected["bytes"] or row["sha256"] != expected["sha256"]:
            raise RuntimeError(f"frozen snapshot entry differs from independent audit: {relative}")
    source_key = f"{repository.name}/test/GenomeV5/UP2/up2_00_contract_tests.jl"
    source_row = snapshot.entries.get(source_key)
    if source_row is None:
        raise RuntimeError("frozen snapshot omits the UP2-00 consumer test")
    candidate_ref = _candidate_ref_from_source(snapshot.read_bytes(
        source_key, source_row["bytes"], source_row["sha256"]))
    fixture_id, mutation_ids, _ = _scenario_from_snapshot(snapshot, repository.name)
    return FrozenHandoff(project_root, root, snapshot.manifest_sha256,
                         snapshot.snapshot_id, candidate_ref, fixture_id,
                         mutation_ids, tuple(snapshot.entries.keys()), support_sources, snapshot)


_JULIA_RESULT_PROGRAM = r'''using FusionConceptAI
root = abspath(ARGS[1])
snapshot_id = String(ARGS[2])
module_source = realpath(pathof(FusionConceptAI))
expected_module_source = realpath(joinpath(root, "src", "FusionConceptAI.jl"))
module_source == expected_module_source || error("FusionConceptAI loaded outside frozen snapshot")
runner_source = realpath(joinpath(root, "test", "GenomeV5", "UP2", "run_up2_00_contract.jl"))
include(runner_source)
expected_up2_source_root = realpath(joinpath(root, "src", "GenomeV5", "UP2"))
realpath(Main._UP2_ROOT) == expected_up2_source_root || error("UP2 source loader escaped frozen snapshot")
test_source = realpath(joinpath(dirname(runner_source), "up2_00_contract_tests.jl"))
package = Main._up2_actual_package()
projection = FusionConceptAI.up2_projection_from_a(package)
mission = FusionConceptAI.UP2MissionBoundsV1("actual_a_package", "scalar_field", "1", "m",
    (0 // 1, 0 // 1, 0 // 1), (1 // 1, 1 // 1, 1 // 1), :static)
source_manifest_hash = FusionConceptAI.digest256_text(read(
    joinpath(root, "test", "GenomeV5", "UP1-04", "fixtures.json"), String))
input = FusionConceptAI.up2_input_from_a(package, mission, source_manifest_hash)
FusionConceptAI.up2_validate_input(input) || error("UP2-00 frozen input failed validation")
fixture = Main._UP2_FIXTURE
specs = Main._up2_fixture_specs()
pending_count = count(spec -> !(spec.class_id in (:N01, :N02)) && spec.id != "N04-02", specs)
active_count = length(specs) - pending_count
n04_02 = only(filter(spec -> spec.id == "N04-02", specs))
pending_count == 39 && active_count == 11 || error("UP2-00 pending/active counts changed")
n04_02.mutation_kind === :duplicate_account_ids || error("UP2-00 N04-02 status changed")
git_audit = FusionConceptAI.NativeGitReadCompatibilityV1.runtime_git_query_audit()
actual_cli_launches = Int(git_audit["actual_cli_launches"])
actual_native_repository_reads = Int(git_audit["actual_native_repository_reads"])
actual_cli_launches == 0 && actual_native_repository_reads == 0 ||
    error("UP2-00 limited consumer performed a Git CLI or repository read")
payload = (schema="up1-04a-vnext-limited-up2-00-result-v1",
    snapshot_id=snapshot_id, candidate_ref=package.candidate_ref.id,
    candidate_version=package.candidate_ref.version,
    candidate_hash=package.candidate_hash.value,
    projection_hash=projection.projection_hash.value,
    input_hash=input.input_hash.value,
    fixture_id=String(fixture.fixture_id),
    mutation_count=length(specs),
    pending_count=pending_count,
    active_count=active_count,
    n04_02_status=String(n04_02.mutation_kind),
    actual_cli_launches=actual_cli_launches,
    actual_native_repository_reads=actual_native_repository_reads,
    module_source_path=module_source,
    runner_source_path=runner_source,
    test_source_path=test_source,
    up2_source_root=expected_up2_source_root)
println("UP1_04A_VNEXT_UP2_IDENTITY=" * FusionConceptAI.canonical_json(payload))
'''


def _test_summaries(stdout: bytes) -> list[dict[str, Any]]:
    text = stdout.decode("utf-8", errors="strict")
    row_pattern = re.compile(r"^(.+?)\s*\|\s*(\d+)\s+(\d+)(?:\s+.*)?$")
    lines = text.splitlines()
    summaries: list[dict[str, Any]] = []
    summary_headers = 0
    for index, line in enumerate(lines):
        if not line.startswith("Test Summary:"):
            continue
        summary_headers += 1
        if index + 1 >= len(lines):
            raise RuntimeError("UP2-00 Test summary is truncated")
        match = row_pattern.match(lines[index + 1])
        if match is None:
            raise RuntimeError("UP2-00 Test summary totals are malformed")
        name = match.group(1).strip()
        passed = int(match.group(2))
        total = int(match.group(3))
        if not name:
            raise RuntimeError("UP2-00 test summary name is empty")
        if passed != total:
            raise RuntimeError(f"UP2-00 test summary contains failures: {name}")
        summaries.append({"suite": name, "passed": passed, "total": total})
    if not summaries or len(summaries) != summary_headers:
        raise RuntimeError("UP2-00 consumer emitted no parseable Test summaries")
    return summaries


def _result_marker(stdout: bytes, expected_snapshot_root: Path,
                   expected_snapshot_id: str) -> dict[str, Any]:
    pattern = re.compile(rb"^" + IDENTITY_MARKER.encode("ascii") + rb"([^\r\n]+)$",
                         re.MULTILINE)
    matches = pattern.findall(stdout)
    if len(matches) != 1:
        raise RuntimeError("UP2-00 consumer did not emit exactly one post-test identity marker")
    value = _strict_json(matches[0], "UP2-00 result marker")
    if value.get("schema") != "up1-04a-vnext-limited-up2-00-result-v1" or \
            value.get("fixture_id") != FIXTURE_ID or \
            value.get("mutation_count") != EXPECTED_MUTATION_COUNT or \
            value.get("pending_count") != 39 or value.get("active_count") != 11 or \
            value.get("n04_02_status") != "duplicate_account_ids" or \
            value.get("actual_cli_launches") != 0 or \
            value.get("actual_native_repository_reads") != 0 or \
            value.get("snapshot_id") != expected_snapshot_id.lower() or \
            value.get("candidate_ref") != EXPECTED_CANDIDATE_REF.removesuffix("@v5") or \
            value.get("candidate_version") != "v5":
        raise RuntimeError("UP2-00 result marker differs from the candidate/scenario contract")
    expected_module = os.path.normcase(str((expected_snapshot_root / "src/FusionConceptAI.jl").resolve(strict=True)))
    expected_runner = os.path.normcase(str((expected_snapshot_root / CONSUMER_RUNNER).resolve(strict=True)))
    expected_test = os.path.normcase(str((expected_snapshot_root / "test/GenomeV5/UP2/up2_00_contract_tests.jl").resolve(strict=True)))
    expected_up2_root = os.path.normcase(str((expected_snapshot_root / "src/GenomeV5/UP2").resolve(strict=True)))
    if os.path.normcase(str(value.get("module_source_path", ""))) != expected_module or \
            os.path.normcase(str(value.get("runner_source_path", ""))) != expected_runner or \
            os.path.normcase(str(value.get("test_source_path", ""))) != expected_test or \
            os.path.normcase(str(value.get("up2_source_root", ""))) != expected_up2_root:
        raise RuntimeError("Julia loaded the package or UP2 runner outside the frozen snapshot")
    return value


def _run_bounded_phase(repository_root: Path, handoff: FrozenHandoff,
                       output_dir: Path, julia_executable: Path,
                       closure_audit_path: Path,
                       runtime_tool_pins: tuple[dict[str, Any], ...]) -> dict[str, Any]:
    root = repository_root.resolve(strict=True)
    runner = root / RUNNER_RELATIVE
    supervisor = root / SUPERVISOR_RELATIVE
    for pin in runtime_tool_pins:
        current = _file_pin(Path(pin["path"]))
        if any(current[key] != pin[key] for key in ("path", "bytes", "sha256")):
            raise RuntimeError(f"runtime tool changed after source capture: {pin['path']}")
    handoff.snapshot.verify_all()
    command = [str(julia_executable.resolve(strict=True)),
               "--startup-file=no", "--history-file=no", "--threads=1",
               f"--project={handoff.root}", "-e", _JULIA_RESULT_PROGRAM,
               str(handoff.root), handoff.snapshot_id]
    runner_argv = [sys.executable, str(runner), "--output-dir", str(output_dir),
                   "--seconds", str(WALL_LIMIT_SECONDS)]
    pins = [handoff.snapshot.manifest_path, closure_audit_path]
    pins.extend(Path(pin["path"]) for pin in runtime_tool_pins)
    pins.extend(handoff.snapshot_root.joinpath(*row["frozen_path"].split("/"))
                for row in handoff.snapshot.entries.values())
    for path in pins:
        runner_argv.extend(("--pin", str(path)))
    runner_argv.extend(("--", *command))
    runner_stdout = output_dir.parent / (output_dir.name + ".runner.stdout.raw")
    runner_stderr = output_dir.parent / (output_dir.name + ".runner.stderr.raw")
    with runner_stdout.open("xb") as stdout_stream, runner_stderr.open("xb") as stderr_stream:
        completed = subprocess.run(runner_argv, cwd=root, stdout=stdout_stream,
                                   stderr=stderr_stream, check=False)
    receipt_path = output_dir / "receipt.json"
    if not receipt_path.is_file():
        raise RuntimeError("bounded runner returned without its raw receipt")
    receipt_raw = receipt_path.read_bytes()
    receipt = _strict_json(receipt_raw, "bounded runner receipt")
    stdout_path = output_dir / "stdout.raw"
    stderr_path = output_dir / "stderr.raw"
    if not stdout_path.is_file() or not stderr_path.is_file():
        raise RuntimeError("bounded runner omitted a raw child output stream")
    child_stdout = stdout_path.read_bytes()
    child_stderr = stderr_path.read_bytes()
    marker = _result_marker(child_stdout, handoff.root, handoff.snapshot_id)
    summaries = _test_summaries(child_stdout)
    executable_pin = _file_pin(julia_executable.resolve(strict=True))
    if completed.returncode != 0 or receipt.get("schema") != "bounded-workspace-check-v1" or \
            receipt.get("actual_child_os_exit_code") != 0 or \
            receipt.get("executable_pin_unchanged") is not True or \
            receipt.get("executable") != executable_pin or \
            receipt.get("stop_reason") is not None or \
            receipt.get("rss_accounting_incomplete") is not False or \
            receipt.get("job_active_processes_after_run") != 0 or \
            receipt.get("passed_software_check") is not True or \
            receipt.get("wall_limit_seconds") != WALL_LIMIT_SECONDS or \
            receipt.get("job_memory_limit_bytes") != MEMORY_LIMIT_BYTES or \
            receipt.get("process_tree_rss_limit_bytes") != MEMORY_LIMIT_BYTES or \
            receipt.get("sample_seconds") != SAMPLE_SECONDS:
        raise RuntimeError("bounded UP2-00 consumer phase did not satisfy its existing resource gate")
    if child_stderr:
        raise RuntimeError("bounded UP2-00 consumer wrote to stderr")
    for pin in runtime_tool_pins:
        current = _file_pin(Path(pin["path"]))
        if any(current[key] != pin[key] for key in ("path", "bytes", "sha256")):
            raise RuntimeError(f"runtime tool changed during bounded phase: {pin['path']}")
    process_id = receipt.get("check_process_id")
    if type(process_id) is not int or process_id <= 0:
        raise RuntimeError("bounded runner omitted the Julia child process identity")
    creation_time_utc = receipt.get("check_process_creation_time_utc")
    if type(creation_time_utc) not in (int, float) or not math.isfinite(creation_time_utc) or \
            creation_time_utc <= 0:
        raise RuntimeError("bounded runner omitted the Julia process creation time")
    handoff.snapshot.verify_all()
    return {
        "runner_return_code": completed.returncode,
        "runner_stdout": _file_pin(runner_stdout),
        "runner_stderr": _file_pin(runner_stderr),
        "runner_receipt": _file_pin(receipt_path),
        "child_stdout": _file_pin(stdout_path),
        "child_stderr": _file_pin(stderr_path),
        "identity": marker,
        "test_summaries": summaries,
        "process_id": process_id,
        "process_creation_time_utc": creation_time_utc,
        "executable": executable_pin,
        "resource_gate": {
            "wall_limit_seconds": receipt["wall_limit_seconds"],
            "job_memory_limit_bytes": receipt["job_memory_limit_bytes"],
            "process_tree_rss_limit_bytes": receipt["process_tree_rss_limit_bytes"],
            "sample_seconds": receipt["sample_seconds"],
            "peak_sampled_tree_rss_bytes": receipt.get("peak_sampled_tree_rss_bytes"),
            "peak_job_commit_bytes": receipt.get("peak_job_commit_bytes"),
            "rss_accounting_incomplete": receipt["rss_accounting_incomplete"],
            "stop_reason": receipt["stop_reason"],
        },
        "passed_software_check": True,
    }


def run_two_process_replay(repository_root: Path, snapshot_root: Path,
                           evidence_root: Path, *,
                           expected_manifest_sha256: str,
                           expected_snapshot_id: str,
                           julia_executable: Path | None = None,
                           closure_audit_path: Path,
                           expected_closure_audit_sha256: str,
                           expected_support_sources: tuple[dict[str, Any], ...] | None = None) -> dict[str, Any]:
    """Run primary and fresh replay with the same closed snapshot and compare identities."""
    root = repository_root.resolve(strict=True)
    output_root = Path(os.path.abspath(os.fspath(evidence_root)))
    if output_root.exists():
        raise FileExistsError(f"retain existing frozen handoff evidence: {output_root}")
    try:
        output_root.relative_to((root / "runs").resolve(strict=True))
    except ValueError as error:
        raise RuntimeError("frozen handoff evidence must be below repository runs") from error
    handoff = verify_inputs(root, snapshot_root,
                            expected_manifest_sha256=expected_manifest_sha256,
                            expected_snapshot_id=expected_snapshot_id,
                            closure_audit_path=closure_audit_path,
                            expected_closure_audit_sha256=expected_closure_audit_sha256,
                            expected_support_sources=expected_support_sources)
    try:
        output_root.relative_to(handoff.snapshot_root)
    except ValueError:
        pass
    else:
        raise RuntimeError("handoff evidence must remain outside the frozen snapshot tree")
    closure_path = closure_audit_path.resolve(strict=True)
    try:
        closure_path.relative_to((root / "runs").resolve(strict=True))
    except ValueError as error:
        raise RuntimeError("consumer closure audit must be under repository runs") from error
    closure_paths, audited_rows = _closure_paths(
        handoff.root, closure_path, expected_closure_audit_sha256)
    expected_closure_paths = tuple(f"{root.name}/{path}" for path in closure_paths)
    if tuple(handoff.snapshot.entries.keys()) != expected_closure_paths or \
            handoff.closure_paths != expected_closure_paths:
        raise RuntimeError("frozen manifest membership differs from the captured closure")
    fixture_id, mutation_ids, scenario = _scenario_from_snapshot(handoff.snapshot, root.name)
    if fixture_id != FIXTURE_ID or len(mutation_ids) != EXPECTED_MUTATION_COUNT:
        raise RuntimeError("frozen candidate/scenario manifest is invalid")
    julia = julia_executable
    if julia is None:
        found = shutil.which("julia")
        if found is None:
            raise RuntimeError("Julia executable is not available on PATH")
        julia = Path(found)
    if not julia.is_absolute():
        raise RuntimeError("Julia executable path must be absolute")
    executable_pin = _file_pin(julia.resolve(strict=True))
    runtime_paths = (RUNNER_RELATIVE, SUPERVISOR_RELATIVE,
                     SNAPSHOT_HELPER_RELATIVE, WORKSPACE_READER_RELATIVE)
    runtime_pins = []
    for relative in runtime_paths:
        live_pin = _file_pin(root / relative)
        audited = audited_rows.get(relative)
        snapshot_row = handoff.snapshot.entries.get(f"{root.name}/{relative}")
        if audited is None or snapshot_row is None or \
                live_pin["bytes"] != audited["bytes"] or live_pin["sha256"] != audited["sha256"] or \
                snapshot_row["bytes"] != audited["bytes"] or snapshot_row["sha256"] != audited["sha256"]:
            raise RuntimeError(f"runtime tool/support bytes differ from the independent audit or snapshot: {relative}")
        runtime_pins.append({"role": relative, **live_pin})
    runtime_pins.append({"role": "handoff_controller", **_file_pin(Path(__file__).resolve(strict=True))})
    runtime_tool_pins = tuple(runtime_pins)
    output_root.mkdir(parents=True, exist_ok=False)
    receipt: dict[str, Any] = {
        "schema": HANDOFF_SCHEMA,
        "scope": "UP2-00 local synthetic CandidateStatePackage contract smoke only",
        "formal_up1_acceptance": False,
        "formal_up1_status": "HOLD",
        "formal_t2_acceptance": False,
        "candidate_ref": handoff.candidate_ref,
        "scenario_manifest": scenario,
        "consumer_closure_count": len(handoff.closure_paths) - 4,
        "runtime_tools_count": 2,
        "runtime_support_count": 2,
        "total_unique_file_rows": len(handoff.closure_paths),
        "closure_audit": _file_pin(closure_path),
        "snapshot": {
            "root": str(handoff.snapshot_root),
            "project_root": str(handoff.root),
            "manifest_path": "manifest.toml",
            "manifest_sha256": handoff.manifest_sha256,
            "snapshot_id": handoff.snapshot_id,
            "entry_count": len(handoff.snapshot.entries),
        },
        "support_sources": list(handoff.support_sources),
        "runtime_tool_pins": list(runtime_tool_pins),
        "julia_executable": executable_pin,
        "runtime_git_audit": None,
        "parent_julia_git_counters": None,
        "whole_tree_runtime_git_zero": "unproven",
        "primary": None,
        "fresh_replay": None,
        "same_snapshot": False,
        "same_result": False,
        "replay_process_is_new": False,
        "passed_limited_handoff": False,
    }
    try:
        handoff.snapshot.verify_all()
        receipt["primary"] = _run_bounded_phase(
            root, handoff, output_root / "primary", julia, closure_path, runtime_tool_pins)
        handoff.snapshot.verify_all()
        receipt["fresh_replay"] = _run_bounded_phase(
            root, handoff, output_root / "fresh_replay", julia, closure_path, runtime_tool_pins)
        primary = receipt["primary"]
        replay = receipt["fresh_replay"]
        receipt["runtime_git_audit"] = {
            "primary": {
                "actual_cli_launches": primary["identity"]["actual_cli_launches"],
                "actual_native_repository_reads": primary["identity"]["actual_native_repository_reads"],
            },
            "fresh_replay": {
                "actual_cli_launches": replay["identity"]["actual_cli_launches"],
                "actual_native_repository_reads": replay["identity"]["actual_native_repository_reads"],
            },
        }
        receipt["parent_julia_git_counters"] = receipt["runtime_git_audit"]
        receipt["same_snapshot"] = (
            handoff.snapshot.snapshot_id == expected_snapshot_id.lower() and
            handoff.snapshot.manifest_sha256 == expected_manifest_sha256.lower())
        receipt["same_result"] = (
            primary["identity"] == replay["identity"] and
            primary["test_summaries"] == replay["test_summaries"] and
            primary["child_stderr"]["bytes"] == replay["child_stderr"]["bytes"] == 0)
        receipt["replay_process_is_new"] = (
            primary["process_id"] != replay["process_id"] and
            primary["process_creation_time_utc"] != replay["process_creation_time_utc"])
        receipt["passed_limited_handoff"] = bool(
            receipt["same_snapshot"] and receipt["same_result"] and
            receipt["replay_process_is_new"] and
            primary["passed_software_check"] and replay["passed_software_check"])
        if not receipt["passed_limited_handoff"]:
            raise RuntimeError("fresh replay differs from the primary UP2-00 result")
    except BaseException as error:
        receipt["failure"] = repr(error)
        raise
    finally:
        final_verification_error: BaseException | None = None
        try:
            handoff.snapshot.verify_all()
        except BaseException as error:
            final_verification_error = error
            receipt["final_snapshot_verified"] = False
            receipt["passed_limited_handoff"] = False
            receipt.setdefault("failure", repr(error))
        else:
            receipt["final_snapshot_verified"] = True
        _write_new_json(output_root / "handoff_receipt.json", receipt)
        if final_verification_error is not None and sys.exc_info()[0] is None:
            raise final_verification_error
    return receipt


def _main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repository-root", required=True, type=Path)
    parser.add_argument("--closure-audit", required=True, type=Path)
    parser.add_argument("--closure-audit-sha256", required=True)
    parser.add_argument("--snapshot-root", required=True, type=Path)
    parser.add_argument("--evidence-root", required=True, type=Path)
    parser.add_argument("--julia-executable", type=Path)
    args = parser.parse_args()
    root = args.repository_root.resolve(strict=True)
    evidence_root = Path(os.path.abspath(os.fspath(args.evidence_root)))
    if evidence_root.exists():
        raise FileExistsError(f"retain existing frozen handoff evidence: {evidence_root}")
    evidence_root.mkdir(parents=True, exist_ok=False)
    try:
        handoff = freeze_inputs(root, args.snapshot_root, args.closure_audit,
                                args.closure_audit_sha256)
        _write_new_json(evidence_root / "freeze_receipt.json", {
            "schema": "up1-04a-vnext-limited-up2-00-freeze-v1",
            "scope": "UP2-00 local synthetic CandidateStatePackage contract smoke only",
            "formal_up1_acceptance": False,
            "formal_up1_status": "HOLD",
            "candidate_ref": handoff.candidate_ref,
            "fixture_id": handoff.fixture_id,
            "mutation_count": len(handoff.mutation_ids),
            "pending_count": 39,
            "active_count": 11,
            "mutation_ids": list(handoff.mutation_ids),
            "consumer_closure_count": len(handoff.closure_paths) - 4,
            "runtime_tools_count": 2,
            "runtime_support_count": 2,
            "total_unique_file_rows": len(handoff.closure_paths),
            "support_sources": list(handoff.support_sources),
            "snapshot_root": str(handoff.snapshot_root),
            "project_root": str(handoff.root),
            "manifest_sha256": handoff.manifest_sha256,
            "snapshot_id": handoff.snapshot_id,
        })
        receipt = run_two_process_replay(
            root, handoff.snapshot_root, evidence_root / "execution",
            expected_manifest_sha256=handoff.manifest_sha256,
            expected_snapshot_id=handoff.snapshot_id,
            julia_executable=args.julia_executable,
            closure_audit_path=args.closure_audit,
            expected_closure_audit_sha256=args.closure_audit_sha256,
            expected_support_sources=handoff.support_sources)
        print(json.dumps({"passed_limited_handoff": receipt["passed_limited_handoff"],
                          "snapshot_id": handoff.snapshot_id,
                          "same_result": receipt["same_result"]}, sort_keys=True),
              flush=True)
        return 0
    except BaseException as error:
        _write_new_json(evidence_root / "failure.json", {
            "schema": HANDOFF_SCHEMA,
            "formal_up1_acceptance": False,
            "failure": repr(error),
        })
        raise


if __name__ == "__main__":
    raise SystemExit(_main())
