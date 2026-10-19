#!/usr/bin/env python3
"""Build a V21 R2 protocol with the complete, pinned V10 docs-input closure."""
from __future__ import annotations

import argparse
import copy
import datetime as dt
import difflib
import hashlib
import json
import pathlib
import re
import zipfile
from pathlib import PurePosixPath
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
ARCHIVE_PATH = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "precleanup_docs_runs_tmp.zip"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
BASE_PROTOCOL_PATH = BASE / "replay_protocol_v21.json"
BASE_PROTOCOL_SHA256 = "113fa02eb54d5b2aa870f2b9c07024def18427fa353c485f30568e50125c4b2e"
BASE_BUILDER_PATH = BASE / "build_protocol_v21.py"
BASE_BUILDER_SHA256 = "d844efd26530bc4e240b2902baf53689b591aa7c862261816f1b751b018ca8e9"
BASE_CONTROLLER_PATH = BASE / "run_replay_staged_v21.py"
BASE_CONTROLLER_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
BASE_ENTRYPOINT_PATH = BASE / "replay_staged_v21.jl"
BASE_ENTRYPOINT_SHA256 = "ca2f0c6b6d4db4b1a3b2d9051f344af84cf0f9de3ff2f7bc479a644c8ae3dfa7"
OVERLAY_SPEC_PATH = BASE / "controller_overlay_spec_v21_r2.json"
OVERLAY_SPEC_SHA256 = "369202ad82fa5669a5a1749117214f36bee9f01f953109ec53d6d9da39d3a345"
R2_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r2.jl"
R2_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r2.py"
R2_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r2.py"
R2_STATIC_TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
OVERLAY_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r2.json"
R2_PROTOCOL_PATH = BASE / "replay_protocol_v21_r2.json"
R2_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r2"
R2_STAGING_ROOT = R2_OUTPUT_ROOT / "archive_mirror"
R2_OUTPUT_LEAF = R2_OUTPUT_ROOT / "runtime_replay_r21_r2"
V10_PATH = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/agent_r2_n1_20260922/"
    "manufactured_candidate_v1/protocol_staged_v10.json"
)
V10_SHA256 = "ff53030155703ee3fcfe3b25ae48fdcc03d411b0da1020cff0cd909388c6aad3"
EXPECTED_BASE_SUMMARY = {
    "archive_directory_prefixes": 31,
    "archive_mapped_bytes": 31317525,
    "archive_mapped_files": 595,
    "archive_mapped_workspace_missing_files": 562,
    "archive_mapped_workspace_present_files": 33,
    "complete_unique_docs_paths": 627,
    "restored_workspace_directories_without_archive": 0,
    "restored_workspace_files_without_archive": 0,
    "v20_path_value_occurrences": 763,
    "v20_unique_docs_path_values": 597,
    "v21_parent_v20_extra_file_references": 30,
    "witnessed_expected_absences": 1,
}
EXPECTED_R2_MAP = {
    "archive_directory_prefixes": 31,
    "archive_mapped_bytes": 31564478,
    "archive_mapped_files": 613,
    "archive_mapped_workspace_missing_files": 580,
    "archive_mapped_workspace_present_files": 33,
    "complete_unique_docs_paths": 645,
    "restored_workspace_directories_without_archive": 0,
    "restored_workspace_files_without_archive": 0,
    "v20_path_value_occurrences": 763,
    "v20_unique_docs_path_values": 597,
    "v21_parent_v20_extra_file_references": 30,
    "witnessed_expected_absences": 1,
    "v10_pinned_input_count": 89,
    "v10_pinned_docs_input_count": 18,
    "v10_pinned_workspace_input_count": 71,
    "v10_docs_inputs_added_to_archive_map": 18,
    "v10_docs_input_bytes_added": 246953,
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def confined_relative(value: object, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError(f"{label} is not a canonical POSIX relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or path.as_posix() != value or any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"{label} escapes or is not canonical: {value!r}")
    return path


def _load_overlay_spec() -> dict[str, Any]:
    data = OVERLAY_SPEC_PATH.read_bytes()
    if sha256_bytes(data) != OVERLAY_SPEC_SHA256:
        raise ValueError("R2 overlay spec differs from its frozen SHA-256")
    spec = json.loads(data)
    if spec.get("schema") != "mms-v21-r2-controller-overlay-spec-v2" or \
            spec.get("original_controller_path") != BASE_CONTROLLER_PATH.relative_to(ROOT).as_posix() or \
            spec.get("original_controller_sha256") != BASE_CONTROLLER_SHA256 or \
            spec.get("replacement_count") != 7 or len(spec.get("replacements", [])) != 7:
        raise ValueError("R2 overlay specification does not match its frozen contract")
    return spec


def _apply_complete_line_overlay(source_bytes: bytes, spec: dict[str, Any]) -> bytes:
    lines = source_bytes.decode("utf-8").splitlines(keepends=True)
    replacement_rows = spec["replacements"]
    replacements = {row["old_line"]: row["new_line"] for row in replacement_rows}
    if len(replacements) != 7:
        raise ValueError("R2 controller overlay has duplicate old-line patterns")
    counts = {old: 0 for old in replacements}
    output: list[str] = []
    for line in lines:
        body = line.rstrip("\r\n")
        new = replacements.get(body)
        if new is None:
            output.append(line)
        else:
            counts[body] += 1
            output.append(new + line[len(body):])
    if any(value != 1 for value in counts.values()):
        raise ValueError(f"R2 controller overlay source-line count changed: {counts}")
    return "".join(output).encode("utf-8")


def _render_overlay_evidence(spec: dict[str, Any], original: bytes, transformed: bytes) -> dict[str, Any]:
    original_lines = original.decode("utf-8").splitlines(keepends=True)
    transformed_lines = transformed.decode("utf-8").splitlines(keepends=True)
    diff = "".join(difflib.unified_diff(
        original_lines, transformed_lines,
        fromfile="run_replay_staged_v21.py (frozen source)",
        tofile="run_replay_staged_v21_r2.py (in-memory path overlay)",
    ))
    return {
        "schema": "mms-v21-r2-controller-overlay-evidence-v1",
        "original_controller_path": spec["original_controller_path"],
        "original_controller_sha256_before": sha256_bytes(original),
        "original_controller_sha256_after": sha256_file(BASE_CONTROLLER_PATH),
        "transformed_source_sha256": sha256_bytes(transformed),
        "overlay_spec_path": OVERLAY_SPEC_REL,
        "overlay_spec_sha256": OVERLAY_SPEC_SHA256,
        "replacement_count": len(spec["replacements"]),
        "path_binding_replacement_count": 6,
        "guard_consumption_binding_correction": {
            "original_call": spec["replacements"][6]["old_line"],
            "corrected_call": spec["replacements"][6]["new_line"],
            "source_variable": "R2_TRANSFORMED_CONTROLLER_SOURCE",
            "source_value": "exact UTF-8 decoded transformed controller bytes compiled and executed by the R2 wrapper",
        },
        "replacements": copy.deepcopy(spec["replacements"]),
        "unified_diff": diff,
        "unified_diff_sha256": sha256_bytes(diff.encode("utf-8")),
        "scope": "Six exact complete-line path bindings plus one exact guard-input consumption correction; all official V21 validation/control-flow statements remain ordered and intact.",
    }


def _source_row(rel: str) -> dict[str, Any]:
    path = ROOT / pathlib.Path(*PurePosixPath(rel).parts)
    if not path.is_file():
        raise FileNotFoundError(f"R2 pinned source is missing: {rel}")
    return {"path": rel, "bytes": path.stat().st_size, "sha256": sha256_file(path)}


def _verify_preserved_base(base: dict[str, Any]) -> None:
    if base.get("schema") != "mms-replay-only-continuation-protocol-v21" or base.get("version") != 21 or \
            base.get("runtime_grant") is not False or base.get("classification") != "test_only_continuation":
        raise ValueError("preserved V21 base protocol identity/status changed")
    source = base.get("archived_input_source")
    if not isinstance(source, dict) or source.get("archive_sha256") != ARCHIVE_SHA256:
        raise ValueError("preserved V21 base archive identity changed")
    summary = source.get("closure_summary")
    if summary != EXPECTED_BASE_SUMMARY:
        raise ValueError("preserved V21 base 595/31/1 closure does not match the frozen summary")
    if (len(source.get("entries", [])), len(source.get("directory_prefixes", [])),
            len(source.get("expected_absent", [])), len(source.get("referenced_paths", []))) != (595, 31, 1, 627):
        raise ValueError("preserved V21 base closure arrays differ from the frozen 595/31/1 mapping")
    if (len(base.get("saved_producer_tree", {}).get("entries", [])),
            base.get("saved_producer_tree", {}).get("file_count"),
            base.get("saved_producer_tree", {}).get("bytes")) != (119, 119, 6590185):
        raise ValueError("preserved V21 119-file producer tree changed")
    if (base.get("stage_limits", {}).get("seconds"), base.get("stage_limits", {}).get("working_set_bytes"),
            base.get("total_child_wall_limit_seconds"), base.get("controller_overhead_seconds_limit"),
            base.get("preserved_numerical_status")) != (
            480, 2147483648, 960, 120,
            {"authority": "no_publish", "physical_validation": "unsupported", "solver_exit_code": 2,
             "status": "fail", "stopping_reason": "stationary_nonzero_residual"}):
        raise ValueError("preserved V21 numerical/resource gates changed")


def _verify_base_archive_rows(source: dict[str, Any], archive: zipfile.ZipFile) -> None:
    rows = source["entries"]
    seen: set[str] = set()
    for row in rows:
        logical = row.get("logical_path")
        confined_relative(logical, "base archive map logical_path")
        if logical in seen or row.get("archive_member") != logical or row.get("archive_sha256") != ARCHIVE_SHA256:
            raise ValueError(f"preserved V21 base archive row is malformed or duplicated: {logical}")
        seen.add(logical)
        info = archive.getinfo(logical)
        content = archive.read(info)
        if info.is_dir() or len(content) != row.get("bytes") or sha256_bytes(content) != row.get("sha256"):
            raise ValueError(f"preserved V21 base archive row does not match its ZIP bytes: {logical}")
        workspace = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
        if workspace.is_file() and (workspace.stat().st_size != row.get("bytes") or
                                    sha256_file(workspace) != row.get("sha256")):
            raise ValueError(f"workspace copy differs from preserved archive input: {logical}")


def _verify_v10_input_rows(base: dict[str, Any], archive: zipfile.ZipFile,
                           entry_map: dict[str, dict[str, Any]]) -> tuple[dict[str, Any], list[tuple[int, dict[str, Any]]]]:
    ref = base.get("v10_protocol")
    if not isinstance(ref, dict) or (ref.get("path"), ref.get("sha256"), ref.get("pinned_input_count")) != \
            (V10_PATH, V10_SHA256, 89):
        raise ValueError("pinned V10 protocol reference/count changed")
    v10_bytes = archive.read(V10_PATH)
    if sha256_bytes(v10_bytes) != V10_SHA256:
        raise ValueError("pinned V10 protocol ZIP bytes differ from the frozen SHA")
    v10 = json.loads(v10_bytes)
    inputs = v10.get("inputs")
    if not isinstance(inputs, list) or len(inputs) != 89:
        raise ValueError("pinned V10 input list is not exactly 89 rows")
    if len({item.get("path") for item in inputs if isinstance(item, dict)}) != 89:
        raise ValueError("pinned V10 input paths are duplicated or malformed")

    missing_docs: list[tuple[int, dict[str, Any]]] = []
    docs_count = 0
    for index, item in enumerate(inputs):
        if not isinstance(item, dict):
            raise ValueError(f"V10 input row {index} is not an object")
        logical = item.get("path")
        path = confined_relative(logical, f"V10 input[{index}].path")
        size = item.get("bytes")
        sha = item.get("sha256")
        if isinstance(size, bool) or not isinstance(size, int) or size < 0 or \
                not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
            raise ValueError(f"V10 input identity is malformed at index {index}")
        if path.parts[0] == "docs":
            docs_count += 1
            info = archive.getinfo(logical)
            content = archive.read(info)
            if info.is_dir() or len(content) != size or sha256_bytes(content) != sha:
                raise ValueError(f"V10 docs input does not match its exact ZIP member: {logical}")
            mapped = entry_map.get(logical)
            if mapped is None:
                missing_docs.append((index, item))
            elif (mapped.get("archive_member"), mapped.get("bytes"), mapped.get("sha256"),
                  mapped.get("archive_sha256")) != (logical, size, sha, ARCHIVE_SHA256):
                raise ValueError(f"V10 docs input map binding differs from the V10 pin: {logical}")
            workspace = ROOT / pathlib.Path(*path.parts)
            if workspace.is_file() and (workspace.stat().st_size != size or sha256_file(workspace) != sha):
                raise ValueError(f"V10 docs workspace copy differs from its pinned ZIP member: {logical}")
        else:
            workspace = ROOT / pathlib.Path(*path.parts)
            if not workspace.is_file() or workspace.stat().st_size != size or sha256_file(workspace) != sha:
                raise ValueError(f"V10 non-doc pinned input is missing or changed: {logical}")
    if docs_count != 18 or len(inputs) - docs_count != 71:
        raise ValueError(f"V10 89-input split changed: docs={docs_count}, workspace={len(inputs)-docs_count}")
    if len(missing_docs) != 18 or sum(int(row["bytes"]) for _, row in missing_docs) != 246953:
        raise ValueError("V10 missing-doc closure differs from the reviewed 18 paths / 246,953 bytes")
    return v10, missing_docs


def _make_added_row(index: int, item: dict[str, Any], archive_sha: str) -> dict[str, Any]:
    logical = item["path"]
    workspace = ROOT / pathlib.Path(*PurePosixPath(logical).parts)
    if workspace.exists():
        raise ValueError(f"R2 must not restore or overwrite any of the 18 missing docs files: {logical}")
    return {
        "logical_path": logical,
        "archive_member": logical,
        "bytes": item["bytes"],
        "sha256": item["sha256"],
        "archive_sha256": archive_sha,
        "workspace_state_at_build": "missing",
        "workspace_bytes_at_build": None,
        "workspace_sha256_at_build": None,
        "source_fields": [f"$.v10_protocol.inputs[{index}].path"],
    }


def _verify_entrypoint_overlay() -> None:
    original = BASE_ENTRYPOINT_PATH.read_bytes()
    old = b'const PROTOCOL = joinpath(@__DIR__, "replay_protocol_v21.json")'
    new = b'const PROTOCOL = joinpath(@__DIR__, "replay_protocol_v21_r2.json")'
    if sha256_bytes(original) != BASE_ENTRYPOINT_SHA256 or original.count(old) != 1:
        raise ValueError("V21 Julia entrypoint differs from its frozen source or path binding")
    expected = original.replace(old, new, 1)
    if sha256_file(BASE_ENTRYPOINT_PATH) != BASE_ENTRYPOINT_SHA256:
        raise ValueError("original V21 Julia entrypoint changed while preparing R2")
    r2_path = BASE / "replay_staged_v21_r2.jl"
    if not r2_path.is_file() or r2_path.read_bytes() != expected:
        raise ValueError("R2 Julia entrypoint is not the exact single-literal versioned successor")


def build_protocol() -> tuple[dict[str, Any], dict[str, Any]]:
    if not ARCHIVE_PATH.is_file() or sha256_file(ARCHIVE_PATH) != ARCHIVE_SHA256:
        raise ValueError("pinned cleanup archive is missing or differs from its fixed SHA-256")
    if sha256_file(BASE_PROTOCOL_PATH) != BASE_PROTOCOL_SHA256:
        raise ValueError("preserved V21 protocol changed from its frozen SHA-256")
    if sha256_file(BASE_BUILDER_PATH) != BASE_BUILDER_SHA256 or \
            sha256_file(BASE_CONTROLLER_PATH) != BASE_CONTROLLER_SHA256 or \
            sha256_file(BASE_ENTRYPOINT_PATH) != BASE_ENTRYPOINT_SHA256:
        raise ValueError("one or more original V21 sources changed from their frozen SHA-256")
    if sha256_file(OVERLAY_SPEC_PATH) != OVERLAY_SPEC_SHA256:
        raise ValueError("R2 controller overlay spec changed from its frozen SHA-256")
    if R2_OUTPUT_ROOT.exists() or R2_STAGING_ROOT.exists() or R2_OUTPUT_LEAF.exists():
        raise FileExistsError("preserve R2 output and archive-mirror roots; protocol build requires them absent")

    _verify_entrypoint_overlay()
    base = json.loads(BASE_PROTOCOL_PATH.read_bytes())
    _verify_preserved_base(base)
    with zipfile.ZipFile(ARCHIVE_PATH, "r") as archive:
        _verify_base_archive_rows(base["archived_input_source"], archive)
        old_map = {row["logical_path"]: row for row in base["archived_input_source"]["entries"]}
        v10, missing_docs = _verify_v10_input_rows(base, archive, old_map)
        archive_members = {info.filename for info in archive.infolist() if not info.is_dir()}
        for _, row in missing_docs:
            if row["path"] not in archive_members:
                raise ValueError(f"V10 input is missing from the pinned ZIP; no mirror may be created: {row['path']}")

    spec = _load_overlay_spec()
    original_controller = BASE_CONTROLLER_PATH.read_bytes()
    if sha256_bytes(original_controller) != BASE_CONTROLLER_SHA256:
        raise ValueError("frozen V21 runner changed while preparing its R2 overlay")
    transformed_controller = _apply_complete_line_overlay(original_controller, spec)
    overlay_evidence = _render_overlay_evidence(spec, original_controller, transformed_controller)

    entries = copy.deepcopy(base["archived_input_source"]["entries"])
    refs = copy.deepcopy(base["archived_input_source"]["referenced_paths"])
    entry_by_path = {row["logical_path"]: row for row in entries}
    ref_by_path = {row["logical_path"]: row for row in refs}
    for index, row in missing_docs:
        logical = row["path"]
        if logical in entry_by_path or logical in ref_by_path:
            raise ValueError(f"V10 missing closure path already has a conflicting R2 map/reference: {logical}")
        new_entry = _make_added_row(index, row, ARCHIVE_SHA256)
        entries.append(new_entry)
        refs.append({
            "logical_path": logical,
            "classification": "archive_file",
            "occurrence_count": 1,
            "source_fields": new_entry["source_fields"],
            "workspace_state_at_build": "absent",
            "workspace_sha256_at_build": None,
            "archive_source_sha256": ARCHIVE_SHA256,
        })
    entries.sort(key=lambda row: row["logical_path"])
    refs.sort(key=lambda row: row["logical_path"])

    docs_paths = {row["path"] for row in v10["inputs"] if row["path"].startswith("docs/")}
    if not docs_paths <= {row["logical_path"] for row in entries} or \
            not docs_paths <= {row["logical_path"] for row in refs}:
        raise ValueError("R2 map/reference closure does not cover all V10 pinned docs inputs")
    if len(entries) != 613 or len(refs) != 645:
        raise ValueError(f"R2 closure dimensions changed: entries={len(entries)}, refs={len(refs)}")
    # None of the 18 new file paths is below a preserved directory-prefix binding.
    for directory in base["archived_input_source"]["directory_prefixes"]:
        prefix = directory["logical_path"].rstrip("/") + "/"
        if any(row["path"].startswith(prefix) for _, row in missing_docs):
            raise ValueError(f"R2 additions would require changing a preserved directory prefix: {prefix}")

    r2 = copy.deepcopy(base)
    r2["protocol_revision"] = "v21-r2"
    r2["protocol_revision_parent"] = {
        "path": BASE_PROTOCOL_PATH.relative_to(ROOT).as_posix(),
        "sha256": BASE_PROTOCOL_SHA256,
        "change_scope": "Complete the 18 missing V10 docs-input map rows and provide versioned R2 path bindings only.",
    }
    r2["r2_created_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    r2["protocol_generation"] = (
        "Test-only V21 R2 closure repair from the frozen V21 source/protocol. Adds only the 18 exact V10-pinned "
        "docs inputs missing from the prior map. The original V21 protocol, controller, Julia source, 595-file map, "
        "31 directory prefixes, 119-file saved producer tree, numerical failure, no-credit status, and all "
        "480-second stage / 2-GiB sampled RSS / 960-second aggregate child wall / 120-second controller budgets "
        "remain pinned and unchanged. Runtime grant remains false."
    )
    r2["controller"] = R2_CONTROLLER_REL
    r2["entrypoint"] = R2_ENTRYPOINT_REL
    r2["output_leaf"] = str(R2_OUTPUT_LEAF.resolve())
    source_rels = [
        R2_BUILDER_REL, R2_CONTROLLER_REL, R2_ENTRYPOINT_REL, R2_STATIC_TEST_REL, OVERLAY_SPEC_REL,
        BASE_BUILDER_PATH.relative_to(ROOT).as_posix(), BASE_CONTROLLER_PATH.relative_to(ROOT).as_posix(),
        BASE_ENTRYPOINT_PATH.relative_to(ROOT).as_posix(), BASE_PROTOCOL_PATH.relative_to(ROOT).as_posix(),
    ]
    owned_sources = [_source_row(rel) for rel in sorted(source_rels)]
    source_by_path = {row["path"]: row["sha256"] for row in owned_sources}
    r2["owned_source_files"] = owned_sources
    r2["owned_source_files_by_path"] = source_by_path
    r2["r2_controller_overlay"] = overlay_evidence
    r2["r2_unmodified_v21_pins"] = [
        {"path": row, "sha256": pin}
        for row, pin in ((BASE_PROTOCOL_PATH.relative_to(ROOT).as_posix(), BASE_PROTOCOL_SHA256),
                         (BASE_CONTROLLER_PATH.relative_to(ROOT).as_posix(), BASE_CONTROLLER_SHA256),
                         (BASE_ENTRYPOINT_PATH.relative_to(ROOT).as_posix(), BASE_ENTRYPOINT_SHA256),
                         (BASE_BUILDER_PATH.relative_to(ROOT).as_posix(), BASE_BUILDER_SHA256))
    ]
    r2["r2_pre_output_closure_contract"] = {
        "schema": "mms-v21-r2-v10-pre-mirror-closure-v1",
        "function": "verify_v10_closure_before_mirror",
        "position": "R2 controller resolver-factory gate, after official controller timer and protocol SHA validation but before original ArchivedInputResolver materializes any file",
        "required_v10_inputs": 89,
        "required_archive_map_entries": 613,
        "requires_exact_archive_file_sha256": ARCHIVE_SHA256,
        "missing_or_changed_input_action": "raise before archive mirror/output creation; do not execute a producer or consumer",
        "original_v21_validation_retained": True,
        "no_mirror_write_during_gate": True,
    }

    archive_source = r2["archived_input_source"]
    archive_source["staging_root"] = str(R2_STAGING_ROOT.resolve())
    archive_source["closure_scope"] = (
        "The exact V20 path/reference/failure closure, plus the pinned V10 protocol and every one of its 18 docs inputs; "
        "the R2 delta adds the 18 previously unmapped V10 docs inputs. All 71 non-doc V10 inputs are verified from "
        "their current workspace bytes before protocol generation."
    )
    archive_source["closure_revision"] = "v21-r2-v10-input-closure"
    archive_source["entries"] = entries
    archive_source["referenced_paths"] = refs
    closure = archive_source["closure_summary"]
    closure.update({
        "archive_mapped_files": len(entries),
        "archive_mapped_bytes": sum(row["bytes"] for row in entries),
        "archive_mapped_workspace_present_files": sum(
            row["workspace_state_at_build"] == "present_same_sha256" for row in entries),
        "archive_mapped_workspace_missing_files": sum(
            row["workspace_state_at_build"] == "missing" for row in entries),
        "archive_directory_prefixes": len(archive_source["directory_prefixes"]),
        "complete_unique_docs_paths": len(refs),
        "v10_pinned_input_count": len(v10["inputs"]),
        "v10_pinned_docs_input_count": sum(row["path"].startswith("docs/") for row in v10["inputs"]),
        "v10_pinned_workspace_input_count": sum(not row["path"].startswith("docs/") for row in v10["inputs"]),
        "v10_docs_inputs_added_to_archive_map": len(missing_docs),
        "v10_docs_input_bytes_added": sum(int(row["bytes"]) for _, row in missing_docs),
    })
    if closure != EXPECTED_R2_MAP:
        raise ValueError(f"R2 closure summary differs from the reviewed expected values: {closure}")

    r2["controller_command_template"] = (
        f"{r2['runtime']['python_executable']} -B {R2_CONTROLLER_REL} --protocol "
        f"test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r2.json "
        f"--protocol-sha256 <protocol-sha256> --output {R2_OUTPUT_LEAF.resolve()} --root-serial-slot-granted"
    )
    r2["context_builder_contract"]["entrypoint_path"] = R2_ENTRYPOINT_REL
    r2["context_builder_contract"]["entrypoint_sha256"] = source_by_path[R2_ENTRYPOINT_REL]
    r2["context_builder_contract"]["semantic_change"] = (
        "R2 changes the protocol/source path binding and completes the V10 input map only. It preserves V21's V4 "
        "context reconstruction and independent final-state plus case-bound identity checks."
    )
    r2["child_command_contract"] = {
        "producer": [r2["runtime"]["julia_executable"], "--startup-file=no", "--project=.", R2_ENTRYPOINT_REL,
                     "producer", "<new-producer-numerical-dir>",
                     str((R2_STAGING_ROOT / pathlib.Path(*PurePosixPath(r2["saved_producer_tree"]["root"]).parts)).resolve()),
                     "<protocol-sha256>", "not_applicable", "not_applicable"],
        "consumer": [r2["runtime"]["julia_executable"], "--startup-file=no", "--project=.", R2_ENTRYPOINT_REL,
                     "consumer", "<new-consumer-numerical-dir>", "<new-producer-numerical-dir>",
                     "<protocol-sha256>", "<controller-sealed-carrier-sha256>",
                     "<controller-sealed-binding-sha256>"],
    }
    r2["coverage_contract"]["output_leaf"] = str(R2_OUTPUT_LEAF.resolve())
    r2["coverage_contract"]["child_argv"]["entrypoint"] = R2_ENTRYPOINT_REL
    r2["coverage_contract"]["child_argv"]["negative_control"] = (
        "R2 static checks and the pre-mirror V10 closure gate start no producer or consumer; only a separate root slot grant may do so."
    )
    r2["coverage_contract"]["pre_mirror_v10_input_closure"] = True
    r2["r2_output_ownership"] = {
        "schema": "mms-v21-r2-external-raw-root-ownership-v1",
        "owner": "UP2ClosureReplayOnlyV21 R2 test-only replay",
        "raw_external_root": str(R2_OUTPUT_ROOT.resolve()),
        "archive_mirror_root": str(R2_STAGING_ROOT.resolve()),
        "runtime_output_leaf": str(R2_OUTPUT_LEAF.resolve()),
        "outside_repository_docs": True,
        "mirror_contents": "Only the explicitly mapped 613 ZIP members; no broad archive extraction and no docs restoration.",
        "builder_creates_mirror_or_output": False,
        "pre_mirror_gate_requires_both_absent": True,
    }
    r2["independent_static_review"] = {
        "scope": "R2 input-closure builder, protocol, and versioned path/pre-mirror gate review pending",
        "julia_started": False,
        "solver_started": False,
        "runtime_grant": False,
    }
    if r2.get("runtime_grant") is not False:
        raise ValueError("R2 must preserve runtime_grant=false")
    return r2, {
        "protocol_path": str(R2_PROTOCOL_PATH),
        "base_protocol_sha256": BASE_PROTOCOL_SHA256,
        "archive_sha256": ARCHIVE_SHA256,
        "v10_protocol_sha256": V10_SHA256,
        "v10_pinned_inputs": len(v10["inputs"]),
        "v10_docs_input_count": sum(row["path"].startswith("docs/") for row in v10["inputs"]),
        "v10_non_docs_workspace_input_count": sum(not row["path"].startswith("docs/") for row in v10["inputs"]),
        "added_archive_rows": len(missing_docs),
        "added_archive_bytes": sum(int(row["bytes"]) for _, row in missing_docs),
        "archive_mapped_files": len(entries),
        "archive_mapped_bytes": sum(row["bytes"] for row in entries),
        "archive_mapped_missing": closure["archive_mapped_workspace_missing_files"],
        "archive_mapped_present": closure["archive_mapped_workspace_present_files"],
        "directory_prefixes": len(archive_source["directory_prefixes"]),
        "expected_absences": len(archive_source["expected_absent"]),
        "complete_unique_docs_paths": len(refs),
        "saved_producer_tree_files": len(r2["saved_producer_tree"]["entries"]),
        "runtime_grant": r2["runtime_grant"],
        "numerical_status": r2["preserved_numerical_status"],
        "resource_limits": {
            "per_stage_seconds": r2["stage_limits"]["seconds"],
            "sampled_rss_bytes": r2["stage_limits"]["working_set_bytes"],
            "aggregate_child_wall_seconds": r2["total_child_wall_limit_seconds"],
            "controller_overhead_seconds": r2["controller_overhead_seconds_limit"],
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write only replay_protocol_v21_r2.json")
    args = parser.parse_args()
    protocol, summary = build_protocol()
    wire = canonical_bytes(protocol)
    summary["protocol_sha256"] = sha256_bytes(wire)
    summary["protocol_bytes"] = len(wire)
    if args.write:
        if R2_PROTOCOL_PATH.exists():
            raise FileExistsError("preserve existing R2 protocol; this builder never replaces it")
        R2_PROTOCOL_PATH.write_bytes(wire)
        summary["written"] = True
    else:
        summary["written"] = False
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
