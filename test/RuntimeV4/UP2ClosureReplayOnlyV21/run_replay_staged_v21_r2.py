#!/usr/bin/env python3
"""Versioned path-binding wrapper for the frozen V21 replay controller."""
from __future__ import annotations

import hashlib
import json
import pathlib
import re
import sys
import types
import zipfile
from collections.abc import Mapping
from pathlib import PurePosixPath
from typing import Any


BASE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(__file__).resolve().parents[3]
R2_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r2.py"
R2_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r2.jl"
R2_PROTOCOL_PATH = BASE / "replay_protocol_v21_r2.json"
ORIGINAL_CONTROLLER = BASE / "run_replay_staged_v21.py"
OVERLAY_SPEC_PATH = BASE / "controller_overlay_spec_v21_r2.json"
ORIGINAL_CONTROLLER_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
OVERLAY_SPEC_SHA256 = "369202ad82fa5669a5a1749117214f36bee9f01f953109ec53d6d9da39d3a345"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _canonical_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _confined_relative(value: object, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError(f"{label} is not a canonical POSIX relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or path.as_posix() != value or any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"{label} escapes or is not canonical: {value!r}")
    return path


def _read_pinned(path: pathlib.Path, expected_sha256: str, label: str) -> bytes:
    data = path.read_bytes()
    actual = _sha256(data)
    if actual != expected_sha256:
        raise ValueError(f"{label} differs from its frozen SHA-256: {actual}")
    return data


def _load_spec() -> dict[str, Any]:
    raw = _read_pinned(OVERLAY_SPEC_PATH, OVERLAY_SPEC_SHA256, "R2 controller overlay spec")
    spec = json.loads(raw)
    if spec.get("schema") != "mms-v21-r2-controller-overlay-spec-v2" or \
            spec.get("original_controller_path") != "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py" or \
            spec.get("original_controller_sha256") != ORIGINAL_CONTROLLER_SHA256 or \
            spec.get("replacement_count") != 7 or not isinstance(spec.get("replacements"), list) or \
            len(spec["replacements"]) != 7:
        raise ValueError("R2 controller overlay specification is incomplete or unexpected")
    return spec


def _apply_exact_line_overlay(source_bytes: bytes, spec: dict[str, Any]) -> bytes:
    source = source_bytes.decode("utf-8")
    lines = source.splitlines(keepends=True)
    replacements: dict[str, str] = {}
    for row in spec["replacements"]:
        if not isinstance(row, dict) or not isinstance(row.get("old_line"), str) or \
                not isinstance(row.get("new_line"), str) or row["old_line"] in replacements:
            raise ValueError("R2 overlay contains a malformed or duplicate complete-line binding")
        replacements[row["old_line"]] = row["new_line"]

    counts = {old: 0 for old in replacements}
    transformed: list[str] = []
    for line in lines:
        body = line.rstrip("\r\n")
        replacement = replacements.get(body)
        if replacement is None:
            transformed.append(line)
            continue
        counts[body] += 1
        ending = line[len(body):]
        transformed.append(replacement + ending)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R2 overlay line cardinality mismatch: {counts}")
    return "".join(transformed).encode("utf-8")


def _verify_protocol_self_pins(spec: dict[str, Any]) -> dict[str, Any]:
    protocol_bytes = R2_PROTOCOL_PATH.read_bytes()
    protocol = json.loads(protocol_bytes)
    source_pins = protocol.get("owned_source_files_by_path")
    if not isinstance(source_pins, dict):
        raise ValueError("R2 protocol has no source pin map")
    expected_spec_sha = source_pins.get("test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r2.json")
    expected_controller_sha = source_pins.get(R2_CONTROLLER_REL)
    expected_original_sha = source_pins.get(spec["original_controller_path"])
    actual_spec_sha = _sha256(OVERLAY_SPEC_PATH.read_bytes())
    actual_controller_sha = _sha256(pathlib.Path(__file__).resolve().read_bytes())
    if actual_spec_sha != OVERLAY_SPEC_SHA256 or expected_spec_sha != actual_spec_sha:
        raise ValueError("R2 overlay spec differs from its protocol source pin")
    if expected_controller_sha != actual_controller_sha:
        raise ValueError("R2 controller wrapper differs from its protocol source pin")
    if expected_original_sha != ORIGINAL_CONTROLLER_SHA256:
        raise ValueError("original V21 controller differs from its R2 protocol source pin")
    if protocol.get("controller") != R2_CONTROLLER_REL or protocol.get("entrypoint") != R2_ENTRYPOINT_REL:
        raise ValueError("R2 protocol does not name the versioned controller and entrypoint")
    overlay = protocol.get("r2_controller_overlay")
    if not isinstance(overlay, dict) or overlay.get("original_controller_sha256_before") != ORIGINAL_CONTROLLER_SHA256 or \
            overlay.get("overlay_spec_sha256") != OVERLAY_SPEC_SHA256 or \
            overlay.get("original_controller_sha256_after") != ORIGINAL_CONTROLLER_SHA256 or \
            overlay.get("replacement_count") != 7 or overlay.get("replacements") != spec["replacements"] or \
            overlay.get("path_binding_replacement_count") != 6 or \
            overlay.get("guard_consumption_binding_correction") != {
                "original_call": spec["replacements"][6]["old_line"],
                "corrected_call": spec["replacements"][6]["new_line"],
                "source_variable": "R2_TRANSFORMED_CONTROLLER_SOURCE",
                "source_value": "exact UTF-8 decoded transformed controller bytes compiled and executed by the R2 wrapper",
            } or \
            not isinstance(overlay.get("unified_diff"), str) or \
            overlay.get("unified_diff_sha256") != _sha256(overlay["unified_diff"].encode("utf-8")):
        raise ValueError("R2 overlay evidence differs from the frozen source/spec pins")
    return protocol


def _verify_mapped_directory_manifests(archive: zipfile.ZipFile, contract: dict[str, Any],
                                       entry_map: dict[str, dict[str, Any]]) -> None:
    directories = contract.get("directory_prefixes")
    if not isinstance(directories, list) or len(directories) != 31:
        raise ValueError("R2 protocol must retain all 31 frozen archive directory prefixes")
    seen: set[str] = set()
    all_infos = [info for info in archive.infolist() if not info.is_dir()]
    for row in directories:
        if not isinstance(row, dict):
            raise ValueError("R2 directory-prefix row is malformed")
        logical = row.get("logical_path")
        path = _confined_relative(logical, "R2 directory-prefix path")
        prefix = path.as_posix().rstrip("/") + "/"
        if logical in seen or row.get("archive_member_prefix") != logical or \
                row.get("archive_sha256") != ARCHIVE_SHA256 or logical in entry_map:
            raise ValueError(f"R2 directory-prefix identity is inconsistent: {logical!r}")
        seen.add(logical)
        infos = sorted((info for info in all_infos if info.filename.startswith(prefix)), key=lambda info: info.filename)
        archive_manifest = [{"member": info.filename, "bytes": info.file_size, "crc32": f"{info.CRC:08x}"}
                            for info in infos]
        if (len(infos), sum(info.file_size for info in infos), _sha256(_canonical_bytes(archive_manifest))) != (
                row.get("archive_member_count"), row.get("archive_member_bytes"),
                row.get("archive_member_manifest_sha256")):
            raise ValueError(f"R2 directory-prefix archive manifest differs: {logical}")
        mapped = sorted((item for key, item in entry_map.items() if key.startswith(prefix)),
                        key=lambda item: str(item["logical_path"]))
        mapped_manifest = [{"logical_path": item["logical_path"], "bytes": item["bytes"], "sha256": item["sha256"]}
                           for item in mapped]
        if (len(mapped), sum(int(item["bytes"]) for item in mapped), _sha256(_canonical_bytes(mapped_manifest))) != (
                row.get("mapped_descendant_count"), row.get("mapped_descendant_bytes"),
                row.get("mapped_descendant_manifest_sha256")):
            raise ValueError(f"R2 directory-prefix mapped descendants differ: {logical}")


def audit_v10_input_closure_before_mirror(protocol: Mapping[str, Any], root: pathlib.Path = ROOT) -> dict[str, Any]:
    """Read-only audit of the full V10+613-row closure; safe to call on tamper fixtures."""
    root = pathlib.Path(root).resolve()
    contract = protocol.get("archived_input_source")
    v10_ref = protocol.get("v10_protocol")
    output_ownership = protocol.get("r2_output_ownership")
    if not isinstance(contract, dict) or not isinstance(v10_ref, dict) or not isinstance(output_ownership, dict):
        raise ValueError("R2 pre-mirror closure identity is incomplete")
    if protocol.get("runtime_grant") is not False or protocol.get("schema") != "mms-replay-only-continuation-protocol-v21" or \
            protocol.get("version") != 21 or v10_ref.get("pinned_input_count") != 89:
        raise ValueError("R2 pre-mirror gate refuses changed protocol status or V10 pin count")

    expected_archive = (root.parent / "FusionConceptAI_cleanup_20260926" / "precleanup_docs_runs_tmp.zip").resolve()
    archive_path = pathlib.Path(str(contract.get("archive_path", ""))).resolve()
    if archive_path != expected_archive or contract.get("archive_sha256") != ARCHIVE_SHA256 or \
            not archive_path.is_file() or _sha256_file(archive_path) != ARCHIVE_SHA256:
        raise ValueError("R2 pinned archive path or whole-file SHA differs before mirror creation")
    expected_output_root = (root.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r2").resolve()
    expected_staging_root = (expected_output_root / "archive_mirror").resolve()
    expected_output_leaf = (expected_output_root / "runtime_replay_r21_r2").resolve()
    if pathlib.Path(str(output_ownership.get("raw_external_root", ""))).resolve() != expected_output_root or \
            pathlib.Path(str(contract.get("staging_root", ""))).resolve() != expected_staging_root or \
            pathlib.Path(str(protocol.get("output_leaf", ""))).resolve() != expected_output_leaf or \
            output_ownership.get("archive_mirror_root") != str(expected_staging_root) or \
            output_ownership.get("runtime_output_leaf") != str(expected_output_leaf) or \
            expected_output_root.exists() or expected_staging_root.exists() or expected_output_leaf.exists():
        raise FileExistsError("R2 output or archive-mirror root is not the exact absent external root")
    if expected_output_root.is_relative_to((root / "docs").resolve()):
        raise ValueError("R2 output roots must stay outside repository docs")

    rows = contract.get("entries")
    refs = contract.get("referenced_paths")
    if not isinstance(rows, list) or len(rows) != 613 or not isinstance(refs, list) or len(refs) != 645:
        raise ValueError("R2 pre-mirror closure must contain exactly 613 archive rows and 645 references")
    source_rows = protocol.get("owned_source_files")
    source_pins = protocol.get("owned_source_files_by_path")
    if not isinstance(source_rows, list) or not isinstance(source_pins, dict) or \
            source_pins != {row.get("path"): row.get("sha256") for row in source_rows if isinstance(row, dict)}:
        raise ValueError("R2 pre-mirror source inventory and map differ")
    for row in source_rows:
        if not isinstance(row, dict):
            raise ValueError("R2 owned source row is malformed")
        source_path = _confined_relative(row.get("path"), "R2 owned source path")
        live = (root / pathlib.Path(*source_path.parts)).resolve()
        if not live.is_relative_to(root) or not live.is_file() or live.stat().st_size != row.get("bytes") or \
                _sha256_file(live) != row.get("sha256"):
            raise ValueError(f"R2 owned source differs from its protocol pin before mirror creation: {source_path}")
    entry_map: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("R2 archive input row is malformed")
        logical = row.get("logical_path")
        path = _confined_relative(logical, "R2 archive map logical_path")
        expected_size = row.get("bytes")
        expected_sha = row.get("sha256")
        if path.parts[0] != "docs" or isinstance(expected_size, bool) or not isinstance(expected_size, int) or \
                expected_size < 0 or not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha) or \
                row.get("archive_member") != logical or row.get("archive_sha256") != ARCHIVE_SHA256 or logical in entry_map:
            raise ValueError(f"R2 archive map row identity is malformed or duplicated: {logical!r}")
        entry_map[logical] = dict(row)

    directory_count_before = len(contract["directory_prefixes"])
    with zipfile.ZipFile(archive_path, "r") as archive:
        archive_names = {info.filename for info in archive.infolist() if not info.is_dir()}
        for logical, row in entry_map.items():
            info = archive.getinfo(logical)
            content = archive.read(info)
            if info.is_dir() or len(content) != row["bytes"] or _sha256(content) != row["sha256"]:
                raise ValueError(f"R2 mapped archive row differs from its exact ZIP bytes: {logical}")
            workspace = (root / pathlib.Path(*PurePosixPath(logical).parts)).resolve()
            if not workspace.is_relative_to(root):
                raise ValueError(f"R2 archive map path escapes workspace: {logical}")
            if workspace.exists() and not workspace.is_file():
                raise ValueError(f"R2 archive-file path is occupied by a non-file: {logical}")
            if workspace.is_file() and (workspace.stat().st_size != row["bytes"] or
                                        _sha256_file(workspace) != row["sha256"]):
                raise ValueError(f"R2 workspace copy differs from its mapped archive input: {logical}")
            if any(str(field).startswith("$.v10_protocol.inputs[") for field in row.get("source_fields", [])) and \
                    workspace.exists():
                raise ValueError(f"R2 must not restore any of the 18 V10 docs inputs: {logical}")
        _verify_mapped_directory_manifests(archive, contract, entry_map)

        absent_rows = contract.get("expected_absent")
        if not isinstance(absent_rows, list) or len(absent_rows) != 1 or not isinstance(absent_rows[0], dict):
            raise ValueError("R2 pre-mirror closure must retain its sole expected-absence witness")
        absent = absent_rows[0]
        absent_path = _confined_relative(absent.get("logical_path"), "R2 expected-absence path")
        absent_workspace = (root / pathlib.Path(*absent_path.parts)).resolve()
        if absent.get("kind") != "expected_absent_historical_output" or \
                absent.get("archive_sha256") != ARCHIVE_SHA256 or absent.get("archive_member_present") is not False or \
                absent.get("workspace_state_at_build") != "absent" or absent.get("logical_path") in archive_names or \
                absent_workspace.exists():
            raise ValueError("R2 expected-absence witness changed before mirror creation")

        v10_path = _confined_relative(v10_ref.get("path"), "R2 V10 protocol path")
        if v10_ref.get("path") != "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/agent_r2_n1_20260922/manufactured_candidate_v1/protocol_staged_v10.json" or \
                v10_ref.get("sha256") != "ff53030155703ee3fcfe3b25ae48fdcc03d411b0da1020cff0cd909388c6aad3":
            raise ValueError("R2 V10 protocol source pin changed")
        v10_row = entry_map.get(v10_ref["path"])
        if v10_row is None:
            raise ValueError("R2 V10 protocol itself is absent from the 613-row archive map")
        v10_bytes = archive.read(v10_ref["path"])
        if len(v10_bytes) != v10_row["bytes"] or _sha256(v10_bytes) != v10_ref["sha256"]:
            raise ValueError("R2 V10 protocol ZIP bytes differ from its map and SHA pin")
        v10 = json.loads(v10_bytes)
        inputs = v10.get("inputs")
        if not isinstance(inputs, list) or len(inputs) != 89:
            raise ValueError("R2 V10 protocol does not contain all 89 pinned input rows")
        seen_inputs: set[str] = set()
        docs_inputs = 0
        workspace_inputs = 0
        for index, item in enumerate(inputs):
            if not isinstance(item, dict):
                raise ValueError(f"R2 V10 input row {index} is malformed")
            logical = item.get("path")
            path = _confined_relative(logical, f"R2 V10 input[{index}].path")
            if logical in seen_inputs:
                raise ValueError(f"R2 V10 input path is duplicated: {logical}")
            seen_inputs.add(logical)
            size = item.get("bytes")
            sha = item.get("sha256")
            if isinstance(size, bool) or not isinstance(size, int) or size < 0 or \
                    not isinstance(sha, str) or not re.fullmatch(r"[0-9a-f]{64}", sha):
                raise ValueError(f"R2 V10 input[{index}] size/hash is malformed")
            if path.parts[0] == "docs":
                docs_inputs += 1
                mapped = entry_map.get(logical)
                if mapped is None or (mapped["bytes"], mapped["sha256"]) != (size, sha):
                    raise ValueError(f"R2 V10 docs input lacks an exact map row before materialization: {logical}")
                info = archive.getinfo(logical)
                content = archive.read(info)
                if info.is_dir() or len(content) != size or _sha256(content) != sha:
                    raise ValueError(f"R2 V10 docs input differs from its ZIP bytes: {logical}")
                workspace = (root / pathlib.Path(*path.parts)).resolve()
                if not workspace.is_relative_to(root):
                    raise ValueError(f"R2 V10 docs workspace path escapes root: {logical}")
                if workspace.is_file() and (workspace.stat().st_size != size or _sha256_file(workspace) != sha):
                    raise ValueError(f"R2 V10 docs workspace copy differs from V10 pin: {logical}")
                source_field = f"$.v10_protocol.inputs[{index}].path"
                if source_field not in mapped.get("source_fields", []):
                    raise ValueError(f"R2 mapped row omits its V10 source field: {logical}")
            else:
                workspace_inputs += 1
                workspace = (root / pathlib.Path(*path.parts)).resolve()
                if not workspace.is_relative_to(root) or not workspace.is_file() or \
                        workspace.stat().st_size != size or _sha256_file(workspace) != sha:
                    raise ValueError(f"R2 V10 non-doc input is missing or differs from its live pin: {logical}")
        if (docs_inputs, workspace_inputs) != (18, 71):
            raise ValueError(f"R2 V10 input categories changed: docs={docs_inputs}, workspace={workspace_inputs}")

    closure = contract.get("closure_summary")
    expected = {
        "archive_mapped_files": 613,
        "archive_mapped_bytes": 31564478,
        "archive_mapped_workspace_missing_files": 580,
        "archive_mapped_workspace_present_files": 33,
        "archive_directory_prefixes": 31,
        "complete_unique_docs_paths": 645,
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
    if not isinstance(closure, dict) or any(closure.get(key) != value for key, value in expected.items()) or \
            len(entry_map) != 613 or directory_count_before != 31 or len(refs) != 645:
        raise ValueError("R2 pre-mirror closure summary does not match the full 613/89/31 frozen inventory")
    ref_map = {row.get("logical_path"): row for row in refs if isinstance(row, dict)}
    if len(ref_map) != len(refs) or not set(entry_map) <= set(ref_map):
        raise ValueError("R2 referenced-path table does not cover every mapped archive file")
    docs_paths = {item["path"] for item in inputs if item["path"].startswith("docs/")}
    if not docs_paths <= set(entry_map) or not docs_paths <= set(ref_map):
        raise ValueError("R2 referenced-path table does not cover every V10 docs input")
    additions = [row for row in rows if any(str(field).startswith("$.v10_protocol.inputs[")
                                             for field in row.get("source_fields", []))]
    if len(additions) != 18 or sum(int(row["bytes"]) for row in additions) != 246953:
        raise ValueError("R2 source-field records do not account for exactly the 18 V10 additions")
    for index, item in enumerate(inputs):
        if not item["path"].startswith("docs/"):
            continue
        reference = ref_map[item["path"]]
        source_field = f"$.v10_protocol.inputs[{index}].path"
        if reference.get("classification") != "archive_file" or \
                source_field not in reference.get("source_fields", []):
            raise ValueError(f"R2 referenced-path classification/source is incomplete: {item['path']}")
    if len(protocol.get("saved_producer_tree", {}).get("entries", [])) != 119 or \
            protocol.get("saved_producer_tree", {}).get("bytes") != 6590185:
        raise ValueError("R2 closure repair changed the frozen 119-file producer tree")
    if protocol.get("preserved_numerical_status") != {
            "authority": "no_publish", "physical_validation": "unsupported", "solver_exit_code": 2,
            "status": "fail", "stopping_reason": "stationary_nonzero_residual"}:
        raise ValueError("R2 closure repair changed the frozen numerical/no-credit outcome")
    return {"v10_inputs_verified": 89, "v10_docs_inputs": 18, "v10_workspace_inputs": 71,
            "archive_rows_verified": 613, "archive_bytes_verified": 31564478,
            "directory_prefixes_verified": 31, "materialization_started": False}


def verify_v10_closure_before_mirror(protocol_path: pathlib.Path | str, supplied_sha256: str,
                                     protocol: Mapping[str, Any], root: pathlib.Path = ROOT) -> dict[str, Any]:
    """Check the exact CLI protocol pin and all V10 inputs before original mirror materialization."""
    actual_path = pathlib.Path(protocol_path).resolve()
    if actual_path != R2_PROTOCOL_PATH.resolve():
        raise ValueError("R2 pre-mirror gate accepts only replay_protocol_v21_r2.json")
    if not isinstance(supplied_sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", supplied_sha256):
        raise ValueError("R2 pre-mirror gate requires the exact lowercase CLI protocol SHA-256")
    wire = actual_path.read_bytes()
    if _sha256(wire) != supplied_sha256:
        raise ValueError("R2 CLI --protocol-sha256 differs from actual protocol bytes")
    parsed = json.loads(wire)
    if parsed != dict(protocol):
        raise ValueError("R2 protocol object passed to the original resolver differs from CLI bytes")
    return audit_v10_input_closure_before_mirror(parsed, root)


def _invocation_bindings() -> tuple[pathlib.Path, str | None]:
    protocol_path = R2_PROTOCOL_PATH
    supplied_sha: str | None = None
    argv = sys.argv[1:]
    index = 0
    while index < len(argv):
        value = argv[index]
        if value == "--protocol" and index + 1 < len(argv):
            protocol_path = pathlib.Path(argv[index + 1])
            index += 2
            continue
        if value.startswith("--protocol="):
            protocol_path = pathlib.Path(value.split("=", 1)[1])
        elif value == "--protocol-sha256" and index + 1 < len(argv):
            supplied_sha = argv[index + 1]
            index += 2
            continue
        elif value.startswith("--protocol-sha256="):
            supplied_sha = value.split("=", 1)[1]
        index += 1
    return protocol_path, supplied_sha


def _load_frozen_controller() -> tuple[types.ModuleType, dict[str, Any]]:
    spec = _load_spec()
    protocol = _verify_protocol_self_pins(spec)
    original = _read_pinned(ORIGINAL_CONTROLLER, ORIGINAL_CONTROLLER_SHA256, "original V21 controller")
    transformed = _apply_exact_line_overlay(original, spec)
    overlay = protocol["r2_controller_overlay"]
    if overlay.get("transformed_source_sha256") != _sha256(transformed):
        raise ValueError("transformed V21 controller source differs from its R2 protocol evidence")
    module = types.ModuleType("_frozen_v21_controller_r2_path_overlay")
    module.__file__ = str(pathlib.Path(__file__).resolve())
    module.__package__ = None
    transformed_source = transformed.decode("utf-8")
    module.__dict__["R2_TRANSFORMED_CONTROLLER_SOURCE"] = transformed_source
    code = compile(transformed_source, str(ORIGINAL_CONTROLLER), "exec", dont_inherit=True)
    exec(code, module.__dict__)
    return module, protocol


def main() -> int:
    controller, _protocol = _load_frozen_controller()
    protocol_path, supplied_sha = _invocation_bindings()
    original_resolver = controller.ArchivedInputResolver

    def resolver_with_read_only_preflight(root: pathlib.Path, protocol: dict[str, Any]) -> Any:
        if supplied_sha is None:
            raise ValueError("R2 pre-mirror gate did not receive the actual CLI --protocol-sha256")
        verify_v10_closure_before_mirror(protocol_path, supplied_sha, protocol, root)
        resolver = original_resolver(root, protocol)
        if type(resolver) is not original_resolver:
            raise TypeError("R2 pre-mirror gate did not return the original V21 archive resolver instance")
        return resolver

    # This is the only runtime seam added to the frozen controller: a read-only gate
    # before the original resolver constructor can write any archive-mirror file.
    controller.ArchivedInputResolver = resolver_with_read_only_preflight
    return int(controller.main())


if __name__ == "__main__":
    raise SystemExit(main())
