#!/usr/bin/env python3
"""Versioned path-binding wrapper for the frozen V21 replay controller."""
from __future__ import annotations

import ast
import copy
import hashlib
import json
import pathlib
import re
import stat
import sys
import types
import zipfile
from collections.abc import Callable, Mapping
from pathlib import PurePosixPath
from typing import Any


BASE = pathlib.Path(__file__).resolve().parent
ROOT = pathlib.Path(__file__).resolve().parents[3]
R4_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"
R4_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r4.jl"
R4_ABSENCE_HELPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/historical_absent_output_slots_v21_r4.py"
ORIGINAL_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
R4_PROTOCOL_PATH = BASE / "replay_protocol_v21_r4.json"
R5_PROTOCOL_PATH = BASE / "replay_protocol_v21_r5.json"
R6_PROTOCOL_PATH = BASE / "replay_protocol_v21_r6.json"
R7_PROTOCOL_PATH = BASE / "replay_protocol_v21_r7.json"
ORIGINAL_CONTROLLER = BASE / "run_replay_staged_v21.py"
OVERLAY_SPEC_PATH = BASE / "controller_overlay_spec_v21_r4.json"
ORIGINAL_CONTROLLER_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
OVERLAY_SPEC_SHA256 = "e057248e6acff70594d71d023d362b3c79a92535d2b85f923377ee429b0a5e18"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
R4_PROTOCOL_SHA256 = "d4b221074907f5e79d063012f48d97c41a73acaee8e6c9260dd7cb4dd5846a0f"
R4_PROTOCOL_BYTES = 1028450
R5_PROTOCOL_SHA256 = "7ed9c0bd849f0540b1ccb31a805f9055ea31f3bb6d20803cca0ec7216c808274"
R5_PROTOCOL_BYTES = 1029337
R5_WRAPPER_SHA256 = "172ccb476f19a912aa0b8632ac48e81b384d5a86fcdb874d60a3e7c7ced77b02"
R5_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r5.json"
R5_SPEC_PATH = BASE / "controller_overlay_spec_v21_r5.json"
R6_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r6.json"
R6_SPEC_PATH = BASE / "controller_overlay_spec_v21_r6.json"
R5_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r5"
R5_STAGING_ROOT = R5_OUTPUT_ROOT / "archive_mirror"
R5_OUTPUT_LEAF = R5_OUTPUT_ROOT / "runtime_replay_r21_r5"
R6_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r6"
R6_STAGING_ROOT = R6_OUTPUT_ROOT / "archive_mirror"
R6_OUTPUT_LEAF = R6_OUTPUT_ROOT / "runtime_replay_r21_r6"
R4_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r4_scopefix_addendum_r1"
R4_STAGING_ROOT = R4_OUTPUT_ROOT / "archive_mirror"
R4_OUTPUT_LEAF = R4_OUTPUT_ROOT / "runtime_replay_r21_r4_v10inputs_20260927_01"
R3_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json"
R3_PROTOCOL_SHA256 = "1688c51f96cf87ebaec3df75409954f21ac11ca22ecc589ae72634f69c402119"
R4_V9_STATIC_RAW_SIDECAR_KEY = "r4_v9_static_raw_output_sidecar"
R4_V9_STATIC_RAW_SIDECAR_SCHEMA = "mms-v21-r4-v9-static-raw-output-sidecar-v1"
R4_V9_STATIC_RAW_ROUTE_KEY = "r4_checked_path_v9_raw_sidecar_route"
R4_V9_STATIC_RAW_ROUTE_SCHEMA = "mms-v21-r4-v9-static-raw-sidecar-route-v1"
R4_ABSOLUTE_ARCHIVE_ROUTE_KEY = "r4_checked_path_absolute_archive_file_route"
R4_ABSOLUTE_ARCHIVE_ROUTE_SCHEMA = "mms-v21-r4-exact-absolute-archive-file-route-v1"
R4_V6_SCOPEFIX_ADDENDUM_KEY = "r4_v6_postrun_scopefix_closure_addendum"
R4_V6_SCOPEFIX_ADDENDUM_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-transitive-closure-addendum-v1"
R4_V6_SCOPEFIX_ROUTE_KEY = "r4_checked_path_v6_scopefix_addendum_route"
R4_V6_SCOPEFIX_ROUTE_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-route-v1"
R4_V6_SCOPEFIX_MATERIALIZATION_KEY = "r4_v6_postrun_scopefix_addendum_materialization"
R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-materialization-v1"
R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY = "r4_v10_root_observation_input_addendum"
R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA = "mms-v21-r4-v10-root-observation-input-addendum-v1"
R4_V10_ROOT_OBSERVATION_ROUTE_KEY = "r4_checked_path_v10_root_observation_input_route"
R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA = "mms-v21-r4-v10-root-observation-input-route-v1"
R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY = "r4_v10_root_observation_input_materialization"
R4_V10_ROOT_OBSERVATION_MATERIALIZATION_SCHEMA = "mms-v21-r4-v10-root-observation-input-materialization-v1"
V10_REVIEW_MANIFEST_REL = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "independent_replay_v10_postrun_review_20260924/review_manifest.json"
)
V10_REVIEW_MANIFEST_BYTES = 4013
V10_REVIEW_MANIFEST_SHA256 = "7093aa4b07bf545c4b85a9436564b46bbc4bc50d15881eaf93e44ac29263cce5"
V10_ROOT_OBSERVATION_PATH = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "root_replay_v10_grant_20260924/observation.json"
)
V10_ROOT_OBSERVATION_BYTES = 8230
V10_ROOT_OBSERVATION_SHA256 = "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9"
R4_V10_ROOT_OBSERVATION_TARGETS = {
    V10_ROOT_OBSERVATION_PATH: (8230, "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/grant.json":
        (3065, "ac07074745769abee598904e2c87f1ac62fbb649ff1b54787cee898f7aa3a5b6"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.exit.txt":
        (2, "8722616204217eddb39e7df969e0698aed8e599ba62ed2de1ce49b03ade0fede"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.stderr.raw":
        (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/root_replay_v10_grant_20260924/controller.stdout.raw":
        (320, "4029ec84fb491bdcd440d88c1e7e6894fdbc2e1ae6adca30b130d404c568cadc"),
}
R4_V10_ROOT_OBSERVATION_PATHS = tuple(R4_V10_ROOT_OBSERVATION_TARGETS)
R4_V10_PATH_BINDING_KEY = "r4_v10_recorded_path_binding_addendum"
R4_V10_PATH_BINDING_SCHEMA = "mms-v21-r4-v10-recorded-path-binding-addendum-v1"
R4_V10_PATH_BINDING_REPLACEMENTS = [{'old_line': '                str(path.resolve()), path.stat().st_size, digest(path)):',
  'new_line': '                str(_r4_v10_original_path_binding(root, runtime[f"{key}_path"], '
              'path, "file")), path.stat().st_size, digest(path)):'},
 {'old_line': '        str((runtime_root / "producer_process/numerical").resolve()),',
  'new_line': '        str(_r4_v10_original_path_binding(root, runtime["root"], runtime_root, '
              '"directory") / "producer_process" / "numerical"),'}]
V6_PROTOCOL_REL = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r6/replay_protocol_v6.json"
)
V6_PROTOCOL_SHA256 = "9d28384297942eb3cec2fd788e88ac17fb1868e25b55fc7dbe85d3c97d79fca9"
V6_SCOPEFIX_MANIFEST_REL = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_review_scopefix_20260923/SHA256SUMS.txt"
)
V6_SCOPEFIX_MANIFEST_BYTES = 6618
V6_SCOPEFIX_MANIFEST_SHA256 = "d4c677725763cb374bf663ca736e59262781b37d9289136af974d15c27ce9873"
V6_SCOPEFIX_TARGETS = {
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_independent_review_20260923/postrun_review.md":
        (7495, "34a967955a1c06be8527a3c929f3bb4a41452ec92c44e4ed44ab798f31809839"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_independent_review_20260923/commands_and_exits.txt":
        (1337, "c13070f88f652037521edfbe4ee223585e9ef88c3dd7543d480615c6d7c33303"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_independent_review_20260923/scope_violation.md":
        (915, "b0da5b1ee21d82d97059dcf6a90e61dd2c5cbac100f089d08c1a1ee85f0c7cbc"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_v6_postrun_independent_review_20260923/SHA256SUMS.txt":
        (4986, "03cc15ab00f543e4a74c7fe5d8fcc79a9e0625b9a60558a914aaeb4039a4674b"),
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
    "replay_only_continuation_r6/static_contract_check_v6_r1/receipt.json":
        (819, "3d48bad224ad2fab000b68bfcd388b558a95b4e9eff7158b71dcd72d84a998f9"),
}
R4_V6_SCOPEFIX_PATHS = frozenset(V6_SCOPEFIX_TARGETS)
R4_V9_STATIC_RAW_PATHS = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/exit_code.txt",
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/stderr.raw",
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/stdout.raw",
)
R4_V9_STATIC_RAW_EXPECTED = {
    R4_V9_STATIC_RAW_PATHS[0]: (2, "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa"),
    R4_V9_STATIC_RAW_PATHS[1]: (1955, "d23970e5b2b2dbf3774419757dd46382090fd1dcf3f4c808566202a210c62acd"),
    R4_V9_STATIC_RAW_PATHS[2]: (0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
}


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


def _read_unique_zip_member(archive: zipfile.ZipFile, member: str) -> bytes:
    matches = [info for info in archive.infolist() if info.filename == member]
    if not matches:
        raise FileNotFoundError(f"R4 V6 scopefix addendum ZIP member is missing: {member}")
    if len(matches) != 1 or matches[0].is_dir():
        raise ValueError(f"R4 V6 scopefix addendum ZIP member is non-unique or not a file: {member}")
    chunks: list[bytes] = []
    with archive.open(matches[0], "r") as stream:
        while True:
            chunk = stream.read(1024 * 1024)
            if not chunk:
                break
            chunks.append(chunk)
    return b"".join(chunks)


def _parse_v6_scopefix_manifest(manifest_bytes: bytes) -> list[dict[str, Any]]:
    if len(manifest_bytes) != V6_SCOPEFIX_MANIFEST_BYTES or \
            _sha256(manifest_bytes) != V6_SCOPEFIX_MANIFEST_SHA256:
        raise ValueError("R4 V6 scopefix addendum manifest differs from its exact size/SHA pin")
    raw_lines = manifest_bytes.splitlines(keepends=True)
    if len(raw_lines) != 34:
        raise ValueError("R4 V6 scopefix addendum manifest must contain exactly 34 rows")
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for ordinal, raw_line in enumerate(raw_lines, start=1):
        if raw_line.endswith(b"\r\n"):
            line_bytes = raw_line[:-2]
        elif raw_line.endswith(b"\n"):
            line_bytes = raw_line[:-1]
        elif raw_line.endswith(b"\r"):
            raise ValueError("R4 V6 scopefix addendum manifest uses an unsupported bare-CR line ending")
        else:
            line_bytes = raw_line
        try:
            line = line_bytes.decode("utf-8")
        except UnicodeDecodeError as exc:
            raise ValueError("R4 V6 scopefix addendum manifest row is not UTF-8") from exc
        parts = line.split("  ", 2)
        if len(parts) != 3 or not re.fullmatch(r"[0-9a-f]{64}", parts[0]) or \
                not parts[2].startswith("bytes="):
            raise ValueError("R4 V6 scopefix addendum manifest row format changed")
        logical = parts[1]
        path = _confined_relative(logical, "R4 V6 scopefix manifest path")
        if len(path.parts) < 2 or path.parts[0] not in ("docs", "test") or logical in seen:
            raise ValueError("R4 V6 scopefix addendum manifest path is malformed or duplicated")
        try:
            byte_count = int(parts[2].removeprefix("bytes="))
        except ValueError as exc:
            raise ValueError("R4 V6 scopefix addendum manifest byte count is invalid") from exc
        if byte_count < 0:
            raise ValueError("R4 V6 scopefix addendum manifest byte count is negative")
        seen.add(logical)
        rows.append({
            "manifest_ordinal": ordinal,
            "logical_path": logical,
            "archive_member": logical,
            "bytes": byte_count,
            "sha256": parts[0],
            "manifest_row_sha256": _sha256(line_bytes),
        })
    return rows


def _logical_paths_in(value: object) -> list[str]:
    paths: list[str] = []
    if isinstance(value, Mapping):
        logical = value.get("logical_path")
        if isinstance(logical, str):
            paths.append(logical)
        for child in value.values():
            paths.extend(_logical_paths_in(child))
    elif isinstance(value, (list, tuple)):
        for child in value:
            paths.extend(_logical_paths_in(child))
    return paths


def _validate_v6_scopefix_closure_addendum(protocol: Mapping[str, Any], root: pathlib.Path = ROOT,
                                            *, archive: zipfile.ZipFile | None = None) -> dict[str, Any]:
    """Verify the fixed five-path V6 addendum against its pinned manifest, ZIP, and unchanged base map."""
    proof = protocol.get(R4_V6_SCOPEFIX_ADDENDUM_KEY)
    contract = protocol.get("archived_input_source")
    if not isinstance(proof, dict) or not isinstance(contract, dict) or \
            proof.get("schema") != R4_V6_SCOPEFIX_ADDENDUM_SCHEMA or \
            proof.get("classification") != "test_only_continuation" or \
            proof.get("runtime_grant") is not False or proof.get("numerical_credit") is not False or \
            proof.get("physical_credit") is not False:
        raise ValueError("R4 V6 scopefix addendum proof schema or no-credit boundary changed")
    entries = contract.get("entries")
    references = contract.get("referenced_paths")
    prefixes = contract.get("directory_prefixes")
    absent = contract.get("expected_absent", [])
    restored = contract.get("restored_entries", [])
    restored_directories = contract.get("restored_directories", [])
    if not all(isinstance(value, list) for value in
               (entries, references, prefixes, absent, restored, restored_directories)) or \
            (len(entries), len(references), len(prefixes)) != (613, 645, 31):
        raise ValueError("R4 V6 scopefix addendum requires the unchanged 613/645/31 base closure")
    base_map = {
        "entries_count": len(entries),
        "entries_sha256": _sha256(_canonical_bytes(entries)),
        "referenced_paths_count": len(references),
        "referenced_paths_sha256": _sha256(_canonical_bytes(references)),
        "directory_prefixes_count": len(prefixes),
        "directory_prefixes_sha256": _sha256(_canonical_bytes(prefixes)),
    }
    if proof.get("base_map") != base_map:
        raise ValueError("R4 V6 scopefix addendum base-map binding differs from the unchanged R3 closure")

    expected_archive = (pathlib.Path(root).resolve().parent / "FusionConceptAI_cleanup_20260926" /
                        "precleanup_docs_runs_tmp.zip").resolve()
    archive_path = pathlib.Path(str(contract.get("archive_path", ""))).resolve()
    archive_pin = {"path": str(expected_archive), "sha256": ARCHIVE_SHA256}
    if archive_path != expected_archive or contract.get("archive_sha256") != ARCHIVE_SHA256 or \
            proof.get("archive") != archive_pin or not archive_path.is_file():
        raise ValueError("R4 V6 scopefix addendum archive path or SHA binding changed")
    parent_r3 = protocol.get("parent_r3_protocol")
    expected_parent_r3 = {"path": R3_PROTOCOL_REL, "sha256": R3_PROTOCOL_SHA256}
    if not isinstance(parent_r3, Mapping) or \
            {"path": parent_r3.get("path"), "sha256": parent_r3.get("sha256")} != expected_parent_r3 or \
            proof.get("parent_r3_protocol") != expected_parent_r3:
        raise ValueError("R4 V6 scopefix addendum parent-R3 binding changed")
    r3_path = pathlib.Path(root).resolve() / pathlib.Path(*PurePosixPath(R3_PROTOCOL_REL).parts)
    if not r3_path.is_relative_to(pathlib.Path(root).resolve()):
        raise ValueError("R4 V6 scopefix addendum parent-R3 path escapes the repository")
    r3_body = json.loads(_read_pinned(r3_path, R3_PROTOCOL_SHA256, "R4 pinned R3 protocol"))
    parent_v6 = protocol.get("parent_v6_protocol")
    expected_parent_v6 = {"path": V6_PROTOCOL_REL, "sha256": V6_PROTOCOL_SHA256}
    if not isinstance(parent_v6, Mapping) or \
            {"path": parent_v6.get("path"), "sha256": parent_v6.get("sha256")} != expected_parent_v6 or \
            proof.get("parent_v6_protocol") != expected_parent_v6 or \
            r3_body.get("parent_v6_protocol") != expected_parent_v6:
        raise ValueError("R4 V6 scopefix addendum parent-V6 binding changed")
    review = protocol.get("parent_v6_postrun_scopefix_review")
    if not isinstance(review, Mapping) or review.get("manifest_path") != V6_SCOPEFIX_MANIFEST_REL or \
            review.get("manifest_sha256") != V6_SCOPEFIX_MANIFEST_SHA256 or \
            proof.get("manifest") != {"logical_path": V6_SCOPEFIX_MANIFEST_REL,
                                       "bytes": V6_SCOPEFIX_MANIFEST_BYTES,
                                       "sha256": V6_SCOPEFIX_MANIFEST_SHA256}:
        raise ValueError("R4 V6 scopefix addendum manifest is not bound to the parent review")

    base_paths = {str(path) for table in (entries, references, prefixes, absent, restored, restored_directories)
                  for path in _logical_paths_in(table)}
    base_paths.update(_logical_paths_in(protocol.get("r4_historical_absent_output_slots")))
    base_paths.update(_logical_paths_in(protocol.get(R4_V9_STATIC_RAW_SIDECAR_KEY)))
    base_casefold = {path.casefold() for path in base_paths}
    target_casefold: set[str] = set()
    for logical in R4_V6_SCOPEFIX_PATHS:
        path = _confined_relative(logical, "R4 V6 scopefix addendum target")
        if path.parts[:1] != ("docs",):
            raise ValueError(f"R4 V6 scopefix addendum target is not a docs path: {logical}")
        folded = logical.casefold()
        overlaps_base = any(folded == base or folded.startswith(base + "/") or base.startswith(folded + "/")
                            for base in base_casefold)
        if folded in target_casefold or overlaps_base:
            raise ValueError(f"R4 V6 scopefix addendum path overlaps or case-aliases an existing route: {logical}")
        target_casefold.add(folded)
        if any(folded == str(row.get("logical_path", "")).rstrip("/").casefold() or
               folded.startswith(str(row.get("logical_path", "")).rstrip("/").casefold() + "/") or
               str(row.get("logical_path", "")).rstrip("/").casefold().startswith(folded + "/")
               for row in prefixes if isinstance(row, Mapping)):
            raise ValueError(f"R4 V6 scopefix addendum path overlaps a directory prefix: {logical}")
        workspace_root = pathlib.Path(root).resolve()
        workspace_raw = workspace_root / pathlib.Path(*path.parts)
        cursor = workspace_root
        if _is_reparse_point(cursor):
            raise ValueError(f"R4 V6 scopefix addendum workspace root is a reparse point: {logical}")
        for part in path.parts:
            cursor = cursor / part
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V6 scopefix addendum workspace path contains a reparse point: {logical}")
        workspace_path = workspace_raw.resolve()
        if not workspace_path.is_relative_to(workspace_root) or workspace_raw.exists():
            raise ValueError(f"R4 V6 scopefix addendum workspace path is not absent: {logical}")

    if archive is None:
        if _sha256_file(archive_path) != ARCHIVE_SHA256:
            raise ValueError("R4 V6 scopefix addendum archive whole-file SHA changed")
        archive_context: Any = zipfile.ZipFile(archive_path, "r")
        close_archive = True
    else:
        if pathlib.Path(str(archive.filename)).resolve() != archive_path:
            raise ValueError("R4 V6 scopefix addendum ZIP handle is not the pinned archive")
        archive_context = archive
        close_archive = False
    try:
        manifest_bytes = _read_unique_zip_member(archive_context, V6_SCOPEFIX_MANIFEST_REL)
        manifest_rows = _parse_v6_scopefix_manifest(manifest_bytes)
        selected = [row for row in manifest_rows if row["logical_path"] in R4_V6_SCOPEFIX_PATHS]
        if len(selected) != 5 or {row["logical_path"] for row in selected} != R4_V6_SCOPEFIX_PATHS or \
                proof.get("row_count") != 5 or proof.get("rows") != selected:
            raise ValueError("R4 V6 scopefix addendum proof does not equal the exact five manifest rows")
        payloads: dict[str, bytes] = {}
        for row in selected:
            expected_bytes, expected_sha = V6_SCOPEFIX_TARGETS[row["logical_path"]]
            if (row["bytes"], row["sha256"], row["archive_member"]) != \
                    (expected_bytes, expected_sha, row["logical_path"]):
                raise ValueError(f"R4 V6 scopefix addendum manifest row differs from its fixed pin: {row['logical_path']}")
            payload = _read_unique_zip_member(archive_context, row["archive_member"])
            if len(payload) != row["bytes"] or _sha256(payload) != row["sha256"]:
                raise ValueError(f"R4 V6 scopefix addendum ZIP bytes differ from the manifest row: {row['logical_path']}")
            payloads[row["logical_path"]] = payload
    finally:
        if close_archive:
            archive_context.close()

    stage_root_text = contract.get("staging_root")
    route = protocol.get(R4_V6_SCOPEFIX_ROUTE_KEY)
    expected_route = {
        "schema": R4_V6_SCOPEFIX_ROUTE_SCHEMA,
        "proof_key": R4_V6_SCOPEFIX_ADDENDUM_KEY,
        "proof_schema": R4_V6_SCOPEFIX_ADDENDUM_SCHEMA,
        "logical_paths": [row["logical_path"] for row in selected],
        "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                       "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
                       "exact_five_v10_root_observation_addendum", "original_checked_path"],
        "nonmatching_paths": "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path",
        "exact_relative_paths_only": True,
        "absolute_addendum_aliases": False,
        "materialization_root": stage_root_text,
        "materializes_only_addendum_rows": True,
        "materializes_inside_repository_docs": False,
        "changes_613_file_map": False,
        "changes_645_reference_set": False,
        "changes_31_directory_prefixes": False,
        "changes_four_absence_proofs": False,
        "changes_v15_or_v16_evidence": False,
        "changes_original_eight_source_overlays": False,
        "numerical_credit": False,
        "physical_credit": False,
        "runtime_grant": False,
    }
    if route != expected_route or not isinstance(stage_root_text, str) or \
            pathlib.Path(stage_root_text).resolve().is_relative_to((pathlib.Path(root).resolve() / "docs").resolve()):
        raise ValueError("R4 V6 scopefix addendum checked_path route or external stage binding changed")
    return {"proof": dict(proof), "rows": [dict(row) for row in selected], "payloads": payloads}


def _is_reparse_point(path: pathlib.Path) -> bool:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    return path.is_symlink() or bool(getattr(info, "st_file_attributes", 0) &
                                     getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0x400))


def _materialize_v6_scopefix_closure_addendum(root: pathlib.Path, protocol: Mapping[str, Any],
                                               stage_root: pathlib.Path,
                                               validated_addendum: Mapping[str, Any]) -> dict[str, Any]:
    """Write only the already verified five payloads under the new external mirror and rehash them."""
    proof = protocol.get(R4_V6_SCOPEFIX_ADDENDUM_KEY)
    contract = protocol.get("archived_input_source")
    ownership = protocol.get("r4_output_ownership")
    if not isinstance(proof, Mapping) or not isinstance(contract, Mapping) or not isinstance(ownership, Mapping) or \
            validated_addendum.get("proof") != proof:
        raise ValueError("R4 V6 scopefix addendum materializer lacks the validated protocol proof")
    workspace = pathlib.Path(root).resolve()
    stage_argument = pathlib.Path(stage_root)
    stage = stage_argument.resolve()
    expected_stage = pathlib.Path(str(contract.get("staging_root", ""))).resolve()
    ownership_stage = pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve()
    external_root = pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve()
    output_leaf = pathlib.Path(str(ownership.get("runtime_output_leaf", ""))).resolve()
    if stage != expected_stage or stage != ownership_stage or not stage.is_relative_to(external_root) or \
            stage.is_relative_to((workspace / "docs").resolve()) or \
            ownership.get("outside_repository_docs") is not True or stage_argument != stage or \
            not stage.is_dir() or output_leaf.exists():
        raise ValueError("R4 V6 scopefix addendum materializer stage/output scope is not the fresh external R4 root")
    route = protocol.get(R4_V6_SCOPEFIX_ROUTE_KEY)
    if not isinstance(route, Mapping) or route.get("materialization_root") != str(stage):
        raise ValueError("R4 V6 scopefix addendum materializer route/stage binding changed")
    rows = validated_addendum.get("rows")
    payloads = validated_addendum.get("payloads")
    if not isinstance(rows, list) or len(rows) != 5 or not isinstance(payloads, Mapping) or \
            set(payloads) != R4_V6_SCOPEFIX_PATHS or rows != proof.get("rows") or \
            [row.get("logical_path") for row in rows if isinstance(row, Mapping)] != route.get("logical_paths"):
        raise ValueError("R4 V6 scopefix addendum materializer rows or payload set is incomplete")

    # Validate every target and parent before writing the first addendum file.
    targets: list[tuple[dict[str, Any], bytes, pathlib.Path]] = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise ValueError("R4 V6 scopefix addendum materializer row is malformed")
        logical = row.get("logical_path")
        if not isinstance(logical, str) or logical not in R4_V6_SCOPEFIX_PATHS or \
                row.get("archive_member") != logical:
            raise ValueError("R4 V6 scopefix addendum materializer path is outside the exact five-row set")
        relative = _confined_relative(logical, "R4 V6 scopefix materialization path")
        target = stage / pathlib.Path(*relative.parts)
        if not target.resolve().is_relative_to(stage):
            raise ValueError(f"R4 V6 scopefix addendum staging target escapes the mirror: {logical}")
        payload = payloads.get(logical)
        expected_bytes, expected_sha = V6_SCOPEFIX_TARGETS[logical]
        if not isinstance(payload, bytes) or len(payload) != expected_bytes or _sha256(payload) != expected_sha or \
                row.get("bytes") != expected_bytes or row.get("sha256") != expected_sha or \
                isinstance(row.get("manifest_ordinal"), bool) or not isinstance(row.get("manifest_ordinal"), int) or \
                row.get("manifest_ordinal", 0) < 1 or \
                not isinstance(row.get("manifest_row_sha256"), str) or \
                not re.fullmatch(r"[0-9a-f]{64}", row["manifest_row_sha256"]):
            raise ValueError(f"R4 V6 scopefix addendum validated payload differs from its fixed row: {logical}")
        for path in (stage, *stage.parents):
            if _is_reparse_point(path):
                raise ValueError(f"R4 V6 scopefix addendum stage contains a reparse point: {path}")
        cursor = stage
        for part in relative.parts:
            cursor = cursor / part
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V6 scopefix addendum path contains a reparse point: {cursor}")
        if target.exists() or target.is_symlink():
            raise FileExistsError(f"R4 V6 scopefix addendum staging target already exists: {logical}")
        for parent in target.parents:
            if parent == stage:
                break
            if parent.exists() and not parent.is_dir():
                raise ValueError(f"R4 V6 scopefix addendum staging parent is not a directory: {parent}")
        targets.append((dict(row), payload, target))

    materialized: list[dict[str, Any]] = []
    for row, payload, target in targets:
        parent = target.parent
        missing_parents: list[pathlib.Path] = []
        while parent != stage and not parent.exists():
            missing_parents.append(parent)
            parent = parent.parent
        for directory in reversed(missing_parents):
            directory.mkdir()
            if _is_reparse_point(directory):
                raise ValueError(f"R4 V6 scopefix addendum created a reparse point: {directory}")
        with target.open("xb") as stream:
            stream.write(payload)
        expected_bytes, expected_sha = V6_SCOPEFIX_TARGETS[row["logical_path"]]
        if _is_reparse_point(target) or not target.is_file() or target.stat().st_size != expected_bytes or \
                _sha256_file(target) != expected_sha:
            raise ValueError(f"R4 V6 scopefix addendum materialized bytes differ from frozen row: {row['logical_path']}")
        materialized.append({
            "manifest_ordinal": row["manifest_ordinal"],
            "logical_path": row["logical_path"],
            "archive_member": row["archive_member"],
            "bytes": row["bytes"],
            "sha256": row["sha256"],
            "manifest_row_sha256": row["manifest_row_sha256"],
            "staged_path": str(target),
        })
    return {
        "schema": R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA,
        "proof_sha256": _sha256(_canonical_bytes(proof)),
        "materialized_count": len(materialized),
        "rows": materialized,
    }


def _confined_relative(value: object, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value:
        raise ValueError(f"{label} is not a canonical POSIX relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or path.as_posix() != value or any(part in ("", ".", "..") for part in path.parts):
        raise ValueError(f"{label} escapes or is not canonical: {value!r}")
    return path


def _r4_v10_original_path_binding(controller: types.ModuleType, root: pathlib.Path | str,
                                   logical_path: object, physical_path: pathlib.Path,
                                   kind: str) -> pathlib.Path:
    """Bind a historical absolute argv/receipt path to one exact input path."""
    root_path = pathlib.Path(root).resolve()
    if root_path != ROOT.resolve():
        raise ValueError("R4 V10 logical path binding requires the exact repository root")
    if not isinstance(logical_path, str) or "\\" in logical_path:
        raise ValueError("R4 V10 logical path binding requires a canonical POSIX path")
    logical = PurePosixPath(logical_path)
    if logical.is_absolute() or logical.as_posix() != logical_path or logical.parts[:1] != ("docs",) or \
            any(part in ("", ".", "..") for part in logical.parts):
        raise ValueError("R4 V10 logical path binding rejects noncanonical repository paths")
    resolver = getattr(controller, "ARCHIVE_INPUTS", None)
    if resolver is None or resolver.root != root_path or resolver.archive_sha256 != ARCHIVE_SHA256:
        raise ValueError("R4 V10 logical path binding lacks the exact initialized archive resolver")
    stage_root = pathlib.Path(resolver.stage_root)
    docs_root = (root_path / "docs").resolve()
    if not stage_root.is_absolute() or stage_root.resolve() != stage_root or \
            stage_root.is_relative_to(docs_root) or _is_reparse_point(stage_root):
        raise ValueError("R4 V10 archive stage root is not the exact external mirror")
    workspace_target = root_path.joinpath(*logical.parts)
    staged_target = stage_root.joinpath(*logical.parts)
    actual = pathlib.Path(physical_path)
    if actual == workspace_target:
        route_root = root_path
        expected_physical = workspace_target
        logical_identity = workspace_target
    elif actual == staged_target:
        route_root = stage_root
        expected_physical = staged_target
        logical_identity = workspace_target
    else:
        raise ValueError(f"R4 V10 physical path is not the exact workspace or staged target: {logical_path}")
    cursor = route_root
    for part in logical.parts:
        cursor = cursor / part
        if _is_reparse_point(cursor):
            raise ValueError(f"R4 V10 input path contains a reparse point: {logical_path}")
    if resolver.logical_path(actual) != logical_path:
        raise ValueError(f"R4 V10 physical path does not map back to its exact logical path: {logical_path}")
    resolved = actual.resolve()
    if resolved != expected_physical or not resolved.is_relative_to(route_root):
        raise ValueError(f"R4 V10 physical path escapes its exact input target: {logical_path}")
    if kind == "file":
        row = resolver.entries.get(logical_path)
        if not isinstance(row, dict) or row.get("logical_path") != logical_path or \
                row.get("archive_member") != logical_path or row.get("archive_sha256") != ARCHIVE_SHA256 or \
                resolver.staged.get(logical_path) != staged_target:
            raise ValueError(f"R4 V10 file path is not the frozen 613-row archive mapping: {logical_path}")
        size, expected_sha = row.get("bytes"), row.get("sha256")
        if isinstance(size, bool) or not isinstance(size, int) or size < 0 or \
                not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha) or \
                not actual.is_file() or actual.stat().st_size != size or _sha256_file(actual) != expected_sha:
            raise ValueError(f"R4 V10 input file differs from its frozen archive row: {logical_path}")
    elif kind == "directory":
        row = resolver.directories.get(logical_path)
        if not isinstance(row, dict) or row.get("logical_path") != logical_path or \
                row.get("archive_member_prefix") != logical_path or row.get("archive_sha256") != ARCHIVE_SHA256 or \
                row.get("mirror_scope") != "explicitly_mapped_descendants_only" or not actual.is_dir():
            raise ValueError(f"R4 V10 directory path is not the frozen 31-prefix archive mapping: {logical_path}")
    else:
        raise ValueError("R4 V10 path binding kind is unsupported")
    # A staged source gets ROOT/logical without resolving an absent docs target.
    # An exact restored source retains the original resolved-path identity.
    return logical_identity

def _apply_r4_v10_path_binding_addendum(source_bytes: bytes, proof: object) -> bytes:
    if not isinstance(proof, dict) or proof.get("schema") != R4_V10_PATH_BINDING_SCHEMA or \
            proof.get("base_transformed_source_sha256") != _sha256(source_bytes) or \
            proof.get("replacement_count") != 2 or proof.get("replacements") != R4_V10_PATH_BINDING_REPLACEMENTS:
        raise ValueError("R4 V10 recorded-path addendum differs from its exact base proof")
    replacements = {row["old_line"]: row["new_line"] for row in R4_V10_PATH_BINDING_REPLACEMENTS}
    lines = source_bytes.decode("utf-8").splitlines(keepends=True)
    counts = {old: 0 for old in replacements}
    transformed: list[str] = []
    for line in lines:
        body = line[:-1] if line.endswith("\n") else line
        if body.endswith("\r"):
            body = body[:-1]
        if body in replacements:
            counts[body] += 1
            transformed.append(replacements[body] + line[len(body):])
        else:
            transformed.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R4 V10 recorded-path addendum line cardinality changed: {counts}")
    result = "".join(transformed).encode("utf-8")
    if proof.get("transformed_source_sha256") != _sha256(result):
        raise ValueError("R4 V10 recorded-path addendum transformed bytes differ from their frozen SHA")
    return result


def _read_pinned(path: pathlib.Path, expected_sha256: str, label: str) -> bytes:
    data = path.read_bytes()
    actual = _sha256(data)
    if actual != expected_sha256:
        raise ValueError(f"{label} differs from its frozen SHA-256: {actual}")
    return data


def _load_spec(protocol: Mapping[str, Any], protocol_path: pathlib.Path) -> dict[str, Any]:
    if pathlib.Path(protocol_path).resolve() not in (R6_PROTOCOL_PATH.resolve(), R7_PROTOCOL_PATH.resolve()):
        raise ValueError("current wrapper accepts only the explicit R6 or R7 successor protocol")
    source_pins = protocol.get("owned_source_files_by_path")
    if not isinstance(source_pins, Mapping):
        raise ValueError("R6 protocol has no owned-source pin map for its overlay spec")
    expected_sha = source_pins.get(R6_SPEC_REL)
    if not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        raise ValueError("R6 protocol lacks one exact overlay-spec source pin")
    raw = _read_pinned(R6_SPEC_PATH, expected_sha, "R6 controller overlay spec")
    spec = json.loads(raw)
    canonical_sha = source_pins.get(ORIGINAL_CONTROLLER_REL)

    r5_protocol_wire = _read_pinned(R5_PROTOCOL_PATH, R5_PROTOCOL_SHA256, "historical R5 protocol")
    if len(r5_protocol_wire) != R5_PROTOCOL_BYTES:
        raise ValueError("historical R5 protocol byte count differs from its preserved identity")
    r5_protocol = json.loads(r5_protocol_wire)
    r5_pins = r5_protocol.get("owned_source_files_by_path")
    if not isinstance(r5_pins, Mapping):
        raise ValueError("historical R5 protocol lacks its frozen source map")
    r5_spec = json.loads(_read_pinned(R5_SPEC_PATH, str(r5_pins.get(R5_SPEC_REL, "")),
                                      "historical R5 controller overlay spec"))
    if r5_spec.get("schema") != "mms-v21-r5-controller-overlay-spec-v1":
        raise ValueError("historical R5 overlay spec schema differs")
    expected_replacements = copy.deepcopy(r5_spec["replacements"])
    expected_replacements[1]["new_line"] = expected_replacements[1]["new_line"].replace(
        "replay_protocol_v21_r5.json", "replay_protocol_v21_r6.json")
    expected_replacements[2]["new_line"] = expected_replacements[2]["new_line"].replace(
        "up2_replay_v21_r5", "up2_replay_v21_r6")
    expected_replacements[3]["new_line"] = expected_replacements[3]["new_line"].replace(
        "up2_replay_v21_r5", "up2_replay_v21_r6")
    expected_replacements[3]["new_line"] = expected_replacements[3]["new_line"].replace(
        "V21 R5 output_leaf", "V21 R6 output_leaf")
    if spec.get("schema") != "mms-v21-r6-controller-overlay-spec-v1" or \
            spec.get("original_controller_path") != ORIGINAL_CONTROLLER_REL or \
            spec.get("original_controller_sha256") != canonical_sha or \
            spec.get("replacement_count") != 8 or spec.get("replacements") != expected_replacements:
        raise ValueError("R6 overlay spec is not the exact R5 eight-replacement successor on the pinned controller")
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

    v20_functions = [node for node in ast.parse(source).body
                     if isinstance(node, ast.FunctionDef) and node.name == "verify_v20_actual_failure"]
    if len(v20_functions) != 1 or v20_functions[0].end_lineno is None:
        raise ValueError("R4 overlay requires the unique top-level V20 failure validator")
    v20_function = v20_functions[0]
    order_line = "    if file_inventory(runtime_root) != runtime_entries:"
    counts = {old: 0 for old in replacements}
    transformed: list[str] = []
    for line_number, line in enumerate(lines, 1):
        body = line.rstrip("\r\n")
        if body == order_line and not v20_function.lineno <= line_number <= v20_function.end_lineno:
            transformed.append(line)
            continue
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


def _read_selected_protocol(protocol_path: pathlib.Path, supplied_sha256: str | None) -> dict[str, Any]:
    actual_path = pathlib.Path(protocol_path).resolve()
    if actual_path == R4_PROTOCOL_PATH.resolve():
        wire = _read_pinned(R4_PROTOCOL_PATH, R4_PROTOCOL_SHA256, "historical R4 protocol")
        if len(wire) != R4_PROTOCOL_BYTES:
            raise ValueError("historical R4 protocol byte count differs from its preserved identity")
        historical = json.loads(wire)
        pins = historical.get("owned_source_files_by_path")
        actual_wrapper = _sha256(pathlib.Path(__file__).resolve().read_bytes())
        if not isinstance(pins, dict) or pins.get(R4_CONTROLLER_REL) == actual_wrapper:
            raise ValueError("historical R4 protocol unexpectedly identifies the current successor wrapper")
        raise ValueError("historical R4 protocol is preserved but cannot execute against the changed wrapper source")
    if actual_path == R5_PROTOCOL_PATH.resolve():
        wire = _read_pinned(R5_PROTOCOL_PATH, R5_PROTOCOL_SHA256, "historical R5 protocol")
        if len(wire) != R5_PROTOCOL_BYTES:
            raise ValueError("historical R5 protocol byte count differs from its preserved identity")
        historical = json.loads(wire)
        pins = historical.get("owned_source_files_by_path")
        actual_wrapper = _sha256(pathlib.Path(__file__).resolve().read_bytes())
        if not isinstance(pins, dict) or pins.get(R4_CONTROLLER_REL) != R5_WRAPPER_SHA256:
            raise ValueError("historical R5 protocol wrapper pin differs from its exact preserved source identity")
        if pins.get(R4_CONTROLLER_REL) == actual_wrapper:
            raise ValueError("historical R5 protocol unexpectedly identifies the current R6-capable wrapper")
        raise ValueError("historical R5 protocol is preserved but cannot execute against the changed wrapper source")
    if actual_path not in (R6_PROTOCOL_PATH.resolve(), R7_PROTOCOL_PATH.resolve()):
        raise ValueError("UP2 accepts only the unique R6 or R7 successor protocol path")
    if supplied_sha256 is None or not re.fullmatch(r"[0-9a-f]{64}", supplied_sha256):
        raise ValueError("R6 execution requires the exact lowercase CLI protocol SHA-256")
    selected_path = R7_PROTOCOL_PATH if actual_path == R7_PROTOCOL_PATH.resolve() else R6_PROTOCOL_PATH
    wire = selected_path.read_bytes()
    if _sha256(wire) != supplied_sha256:
        raise ValueError("UP2 CLI --protocol-sha256 differs from the selected protocol bytes")
    protocol = json.loads(wire)
    if selected_path == R7_PROTOCOL_PATH:
        parent = protocol.get("parent_r6_protocol")
        expected = {"path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r6.json",
                    "bytes": R6_PROTOCOL_PATH.stat().st_size,
                    "sha256": _sha256(R6_PROTOCOL_PATH.read_bytes())}
        if parent != expected:
            raise ValueError("R7 protocol does not name the exact preserved R6 parent")
        current_rows = protocol.get("r7_current_source_files")
        current_pins = protocol.get("r7_current_source_files_by_path")
        if not isinstance(current_rows, list) or not isinstance(current_pins, dict) or \
                current_pins != {row.get("path"): row.get("sha256") for row in current_rows
                                 if isinstance(row, dict)}:
            raise ValueError("R7 current-source rows and map differ")
        for row in current_rows:
            source = (ROOT / pathlib.Path(*_confined_relative(row.get("path"),
                                                               "R7 current-source path").parts)).resolve()
            if not source.is_relative_to(ROOT.resolve()) or not source.is_file() or \
                    source.stat().st_size != row.get("bytes") or _sha256_file(source) != row.get("sha256"):
                raise ValueError(f"R7 current source differs from its exact protocol pin: {row.get('path')}")
        if current_pins.get(R4_CONTROLLER_REL) != _sha256(pathlib.Path(__file__).resolve().read_bytes()):
            raise ValueError("R7 current wrapper differs from its exact protocol pin")
    return protocol


def _verify_r6_route_identity(protocol: dict[str, Any]) -> None:
    parent = protocol.get("parent_r5_protocol")
    if parent != {"path": "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r5.json",
                  "bytes": R5_PROTOCOL_BYTES, "sha256": R5_PROTOCOL_SHA256}:
        raise ValueError("R6 protocol does not name the unique exact frozen R5 parent")
    parent_wire = _read_pinned(R5_PROTOCOL_PATH, R5_PROTOCOL_SHA256, "R6 parent R5 protocol")
    if len(parent_wire) != R5_PROTOCOL_BYTES:
        raise ValueError("R6 parent R5 protocol byte count differs")
    parent_protocol = json.loads(parent_wire)
    parent_pins = parent_protocol.get("owned_source_files_by_path")
    if not isinstance(parent_pins, dict) or parent_pins.get(R4_CONTROLLER_REL) != R5_WRAPPER_SHA256:
        raise ValueError("R6 parent R5 wrapper pin differs from the exact preserved pre-R6 source")
    ownership = protocol.get("r4_output_ownership")
    contract = protocol.get("archived_input_source")
    if not isinstance(ownership, dict) or not isinstance(contract, dict) or \
            pathlib.Path(str(protocol.get("output_leaf", ""))).resolve() != R6_OUTPUT_LEAF.resolve() or \
            pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve() != R6_OUTPUT_ROOT.resolve() or \
            pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve() != R6_STAGING_ROOT.resolve() or \
            pathlib.Path(str(ownership.get("runtime_output_leaf", ""))).resolve() != R6_OUTPUT_LEAF.resolve() or \
            pathlib.Path(str(contract.get("staging_root", ""))).resolve() != R6_STAGING_ROOT.resolve() or \
            ownership.get("outside_repository_docs") is not True:
        raise ValueError("R6 protocol output ownership differs from its fixed external route")
    if R6_OUTPUT_ROOT.exists() or R6_STAGING_ROOT.exists() or R6_OUTPUT_LEAF.exists():
        raise FileExistsError("preserve any existing R6 output or mirror state")
    rows = protocol.get("owned_source_files")
    pins = protocol.get("owned_source_files_by_path")
    if not isinstance(rows, list) or not isinstance(pins, dict) or len(rows) != len(pins) or \
            len({row.get("path") for row in rows if isinstance(row, dict)}) != len(rows) or \
            pins != {row.get("path"): row.get("sha256") for row in rows if isinstance(row, dict)}:
        raise ValueError("R6 protocol owned-source rows and source pin map differ")
    for key in (R4_CONTROLLER_REL, ORIGINAL_CONTROLLER_REL, R6_SPEC_REL):
        if not isinstance(pins.get(key), str) or not re.fullmatch(r"[0-9a-f]{64}", pins[key]):
            raise ValueError(f"R6 protocol lacks one exact required owned-source pin: {key}")


def _verify_protocol_self_pins(protocol: dict[str, Any], spec: dict[str, Any]) -> dict[str, Any]:
    source_rows = protocol.get("owned_source_files")
    source_pins = protocol.get("owned_source_files_by_path")
    if not isinstance(source_rows, list) or not isinstance(source_pins, dict) or \
            len(source_rows) != len(source_pins) or \
            len({row.get("path") for row in source_rows if isinstance(row, dict)}) != len(source_rows) or \
            source_pins != {row.get("path"): row.get("sha256") for row in source_rows if isinstance(row, dict)}:
        raise ValueError("R6 protocol owned-source rows and source pin map differ")
    if protocol.get("schema") != "mms-replay-only-continuation-protocol-v21" or \
            protocol.get("version") != 21 or protocol.get("classification") != "test_only_continuation" or \
            protocol.get("runtime_grant") is not False:
        raise ValueError("R6 protocol changes the frozen no-credit continuation status")
    if protocol.get("controller") != R4_CONTROLLER_REL or protocol.get("entrypoint") != R4_ENTRYPOINT_REL:
        raise ValueError("R6 protocol must use the existing R4 consumer and entrypoint")
    ownership = protocol.get("r4_output_ownership")
    contract = protocol.get("archived_input_source")
    if not isinstance(ownership, dict) or not isinstance(contract, dict) or \
            pathlib.Path(str(protocol.get("output_leaf", ""))).resolve() != R6_OUTPUT_LEAF.resolve() or \
            pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve() != R6_OUTPUT_ROOT.resolve() or \
            pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve() != R6_STAGING_ROOT.resolve() or \
            pathlib.Path(str(ownership.get("runtime_output_leaf", ""))).resolve() != R6_OUTPUT_LEAF.resolve() or \
            pathlib.Path(str(contract.get("staging_root", ""))).resolve() != R6_STAGING_ROOT.resolve() or \
            ownership.get("outside_repository_docs") is not True:
        raise ValueError("R6 protocol output ownership differs from its fixed external route")

    workspace = ROOT.resolve()
    r7_preimages = protocol.get("r7_parent_preimages", {})
    for row in source_rows:
        if not isinstance(row, dict) or not isinstance(row.get("path"), str):
            raise ValueError("R6 owned-source row is malformed")
        rel = _confined_relative(row["path"], "R6 owned-source path")
        preimage = r7_preimages.get(row["path"]) if isinstance(r7_preimages, dict) else None
        source = (ROOT / pathlib.Path(*_confined_relative(preimage.get("path"),
                                                           "R7 parent preimage path").parts)).resolve() \
            if isinstance(preimage, dict) else (workspace / pathlib.Path(*rel.parts)).resolve()
        if not source.is_relative_to(workspace) or not source.is_file() or \
                source.stat().st_size != row.get("bytes") or _sha256_file(source) != row.get("sha256"):
            raise ValueError(f"R6 owned source differs from its exact protocol pin: {row['path']}")
    if not protocol.get("parent_r6_protocol") and source_pins.get(R4_CONTROLLER_REL) != _sha256(pathlib.Path(__file__).resolve().read_bytes()) or \
            source_pins.get(ORIGINAL_CONTROLLER_REL) != _sha256(ORIGINAL_CONTROLLER.read_bytes()) or \
            source_pins.get(R6_SPEC_REL) != _sha256(R6_SPEC_PATH.read_bytes()):
        raise ValueError("R6 wrapper, canonical controller, or overlay spec differs from its owned-source pin")
    if spec.get("original_controller_sha256") != source_pins.get(ORIGINAL_CONTROLLER_REL):
        raise ValueError("R6 overlay spec does not name the canonical controller postimage pin")
    overlay = protocol.get("r4_controller_overlay")
    spec_sha = source_pins.get(R6_SPEC_REL)
    original_sha = source_pins.get(ORIGINAL_CONTROLLER_REL)
    if not isinstance(overlay, dict) or overlay.get("original_controller_sha256_before") != original_sha or \
            overlay.get("original_controller_sha256_after") != original_sha or \
            overlay.get("overlay_spec_path") != R6_SPEC_REL or overlay.get("overlay_spec_sha256") != spec_sha or \
            overlay.get("replacement_count") != 8 or overlay.get("replacements") != spec["replacements"] or \
            overlay.get("path_binding_replacement_count") != 6 or \
            overlay.get("guard_consumption_binding_correction") != {
                "original_call": spec["replacements"][6]["old_line"],
                "corrected_call": spec["replacements"][6]["new_line"],
                "source_variable": "R4_TRANSFORMED_CONTROLLER_SOURCE",
                "source_value": "exact UTF-8 decoded transformed controller bytes compiled and executed by the R4 wrapper",
            } or not isinstance(overlay.get("unified_diff"), str) or \
            overlay.get("unified_diff_sha256") != _sha256(overlay["unified_diff"].encode("utf-8")):
        raise ValueError("R6 overlay evidence differs from the frozen source/spec pins")
    binding = protocol.get(R4_V10_PATH_BINDING_KEY)
    if not isinstance(binding, dict) or binding.get("schema") != R4_V10_PATH_BINDING_SCHEMA or \
            binding.get("base_transformed_source_sha256") != overlay.get("transformed_source_sha256") or \
            binding.get("replacement_count") != 2 or binding.get("replacements") != R4_V10_PATH_BINDING_REPLACEMENTS or \
            not isinstance(binding.get("transformed_source_sha256"), str) or \
            not re.fullmatch(r"[0-9a-f]{64}", binding["transformed_source_sha256"]):
        raise ValueError("R6 V10 recorded-path addendum is not bound to its exact eight-overlay base")
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


def audit_v10_input_closure_before_mirror(
        protocol: Mapping[str, Any], root: pathlib.Path = ROOT,
        non_doc_v10_resolver: Callable[[pathlib.Path, zipfile.ZipFile, dict[str, object]], dict[str, object]] | None = None
) -> dict[str, Any]:
    """Read-only audit of the full V10+613-row closure; safe to call on tamper fixtures."""
    root = pathlib.Path(root).resolve()
    contract = protocol.get("archived_input_source")
    v10_ref = protocol.get("v10_protocol")
    output_ownership = protocol.get("r4_output_ownership")
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
    ownership = protocol.get("r4_output_ownership")
    if not isinstance(ownership, Mapping):
        raise ValueError("R4 pre-mirror gate lacks its versioned external-root ownership")
    expected_output_root = pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve()
    expected_staging_root = (expected_output_root / "archive_mirror").resolve()
    expected_output_leaf = R6_OUTPUT_LEAF.resolve()
    protocol_output_leaf = pathlib.Path(str(protocol.get("output_leaf", ""))).resolve()
    ownership_stage = pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve()
    ownership_leaf = pathlib.Path(str(ownership.get("runtime_output_leaf", ""))).resolve()
    fixed_output_root = R6_OUTPUT_ROOT.resolve()
    if pathlib.Path(str(output_ownership.get("raw_external_root", ""))).resolve() != expected_output_root or \
            pathlib.Path(str(contract.get("staging_root", ""))).resolve() != expected_staging_root or \
            ownership_stage != expected_staging_root or ownership_leaf != expected_output_leaf or \
            protocol_output_leaf != expected_output_leaf or \
            expected_output_root != fixed_output_root or ownership.get("outside_repository_docs") is not True or \
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
        r7_preimages = protocol.get("r7_parent_preimages", {})
        parent_preimage = r7_preimages.get(source_path.as_posix()) if isinstance(r7_preimages, dict) else None
        selected_source = source_path
        if isinstance(parent_preimage, dict):
            selected_source = _confined_relative(parent_preimage.get("path"),
                                                 "R7 parent source preimage path")
        live = (root / pathlib.Path(*selected_source.parts)).resolve()
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
                if non_doc_v10_resolver is None:
                    raise ValueError("R4 pre-mirror audit requires the canonical non-doc V10 source resolver")
                resolved = non_doc_v10_resolver(root, archive, item)
                if not isinstance(resolved, dict):
                    raise ValueError(f"R4 canonical resolver returned a malformed V10 non-doc result: {logical}")
                content = resolved.get("content")
                if resolved.get("logical_path") != logical or resolved.get("bytes") != size or \
                        resolved.get("sha256") != sha or not isinstance(content, bytes) or \
                        len(content) != size or _sha256(content) != sha or \
                        resolved.get("resolved_from") not in (
                            "verified_workspace_bytes", "verified_unique_zip_files_source"):
                    raise ValueError(f"R4 canonical resolver did not verify the exact V10 non-doc row: {logical}")
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


def _read_unique_v10_zip_member(archive: zipfile.ZipFile, member: str) -> bytes:
    infos = archive.infolist()
    exact = [info for info in infos if info.filename == member]
    aliases = [info for info in infos if info.filename.casefold() == member.casefold()]
    if len(exact) != 1 or len(aliases) != 1 or exact[0].is_dir():
        raise ValueError(f"R4 V10 input ZIP member is missing, aliased, duplicated, or not a file: {member}")
    with archive.open(exact[0], "r") as stream:
        return stream.read()


def _v10_root_observation_rows(review_manifest: Mapping[str, Any],
                               observation: Mapping[str, Any]) -> list[dict[str, Any]]:
    root_observation = review_manifest.get("root_observation")
    grant = observation.get("grant")
    sidecars = observation.get("controller_sidecars")
    if not isinstance(root_observation, Mapping) or not isinstance(grant, Mapping) or \
            not isinstance(sidecars, Mapping):
        raise ValueError("R4 V10 source documents lack the pinned declarations")
    sidecar_names = ("controller.exit.txt", "controller.stderr.raw", "controller.stdout.raw")
    if set(root_observation) != {"path", "sha256"} or \
            set(grant) != {"relative_path", "bytes", "sha256"} or \
            set(sidecars) != set(sidecar_names) or any(
                not isinstance(sidecars[name], Mapping) or
                set(sidecars[name]) != {"relative_path", "bytes", "sha256"}
                for name in sidecar_names
            ):
        raise ValueError("R4 V10 source declarations have an unexpected field shape")
    obs_sha = V10_ROOT_OBSERVATION_SHA256
    sources = [
        (V10_ROOT_OBSERVATION_PATH, 8230, obs_sha, V10_REVIEW_MANIFEST_REL, 4013,
         V10_REVIEW_MANIFEST_SHA256, "/root_observation",
         root_observation.get("path"), None, root_observation.get("sha256")),
        (R4_V10_ROOT_OBSERVATION_PATHS[1], 3065,
         "ac07074745769abee598904e2c87f1ac62fbb649ff1b54787cee898f7aa3a5b6",
         V10_ROOT_OBSERVATION_PATH, 8230, obs_sha, "/grant",
         grant.get("relative_path"), grant.get("bytes"), grant.get("sha256")),
        (R4_V10_ROOT_OBSERVATION_PATHS[2], 2,
         "8722616204217eddb39e7df969e0698aed8e599ba62ed2de1ce49b03ade0fede",
         V10_ROOT_OBSERVATION_PATH, 8230, obs_sha, "/controller_sidecars/controller.exit.txt",
         (sidecars.get("controller.exit.txt") or {}).get("relative_path"),
         (sidecars.get("controller.exit.txt") or {}).get("bytes"),
         (sidecars.get("controller.exit.txt") or {}).get("sha256")),
        (R4_V10_ROOT_OBSERVATION_PATHS[3], 0,
         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
         V10_ROOT_OBSERVATION_PATH, 8230, obs_sha, "/controller_sidecars/controller.stderr.raw",
         (sidecars.get("controller.stderr.raw") or {}).get("relative_path"),
         (sidecars.get("controller.stderr.raw") or {}).get("bytes"),
         (sidecars.get("controller.stderr.raw") or {}).get("sha256")),
        (R4_V10_ROOT_OBSERVATION_PATHS[4], 320,
         "4029ec84fb491bdcd440d88c1e7e6894fdbc2e1ae6adca30b130d404c568cadc",
         V10_ROOT_OBSERVATION_PATH, 8230, obs_sha, "/controller_sidecars/controller.stdout.raw",
         (sidecars.get("controller.stdout.raw") or {}).get("relative_path"),
         (sidecars.get("controller.stdout.raw") or {}).get("bytes"),
         (sidecars.get("controller.stdout.raw") or {}).get("sha256")),
    ]
    rows: list[dict[str, Any]] = []
    for logical, size, digest, source_path, source_size, source_digest, pointer, actual_path, actual_size, actual_sha in sources:
        size_matches = actual_size is None if pointer == "/root_observation" else (
            type(actual_size) is int and actual_size == size
        )
        if actual_path != logical or not size_matches or actual_sha != digest:
            raise ValueError(f"R4 V10 source declaration differs from its exact fixed pin: {logical}")
        rows.append({
            "logical_path": logical, "archive_member": logical, "bytes": size, "sha256": digest,
            "source_document_path": source_path, "source_document_bytes": source_size,
            "source_document_sha256": source_digest, "source_json_pointer": pointer,
        })
    return rows


def _validate_v10_root_observation_input_addendum(protocol: Mapping[str, Any], root: pathlib.Path = ROOT,
                                                   *, archive: zipfile.ZipFile | None = None) -> dict[str, Any]:
    proof = protocol.get(R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY)
    contract = protocol.get("archived_input_source")
    parent = protocol.get("parent_v10_independent_postrun_review")
    if not isinstance(proof, dict) or not isinstance(contract, dict) or not isinstance(parent, Mapping) or \
            proof.get("schema") != R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA or \
            proof.get("classification") != "test_only_continuation" or proof.get("runtime_grant") is not False or \
            proof.get("numerical_credit") is not False or proof.get("physical_credit") is not False:
        raise ValueError("R4 V10 root observation addendum schema or no-credit boundary changed")
    entries, refs, prefixes = (contract.get("entries"), contract.get("referenced_paths"),
                               contract.get("directory_prefixes"))
    absent, restored, restored_dirs = (contract.get("expected_absent", []),
                                       contract.get("restored_entries", []),
                                       contract.get("restored_directories", []))
    if not all(isinstance(value, list) for value in (entries, refs, prefixes, absent, restored, restored_dirs)) or \
            (len(entries), len(refs), len(prefixes)) != (613, 645, 31):
        raise ValueError("R4 V10 root observation addendum requires unchanged 613/645/31 base closure")
    base_map = {
        "entries_count": len(entries), "entries_sha256": _sha256(_canonical_bytes(entries)),
        "referenced_paths_count": len(refs), "referenced_paths_sha256": _sha256(_canonical_bytes(refs)),
        "directory_prefixes_count": len(prefixes), "directory_prefixes_sha256": _sha256(_canonical_bytes(prefixes)),
    }
    if proof.get("base_map") != base_map:
        raise ValueError("R4 V10 root observation base-map binding differs from unchanged R3 closure")
    expected_archive = (pathlib.Path(root).resolve().parent / "FusionConceptAI_cleanup_20260926" /
                        "precleanup_docs_runs_tmp.zip").resolve()
    archive_path = pathlib.Path(str(contract.get("archive_path", ""))).resolve()
    if archive_path != expected_archive or contract.get("archive_sha256") != ARCHIVE_SHA256 or \
            proof.get("archive") != {"path": str(expected_archive), "sha256": ARCHIVE_SHA256} or \
            not archive_path.is_file():
        raise ValueError("R4 V10 root observation archive path or SHA binding changed")
    parent_manifest = {"logical_path": V10_REVIEW_MANIFEST_REL, "bytes": 4013,
                       "sha256": V10_REVIEW_MANIFEST_SHA256}
    if parent.get("manifest_path") != V10_REVIEW_MANIFEST_REL or \
            parent.get("manifest_sha256") != V10_REVIEW_MANIFEST_SHA256 or \
            proof.get("parent_review_manifest") != parent_manifest:
        raise ValueError("R4 V10 root observation is not bound to the pinned parent review manifest")
    manifest_rows = [row for row in entries if isinstance(row, Mapping) and
                     row.get("logical_path") == V10_REVIEW_MANIFEST_REL]
    if len(manifest_rows) != 1 or (manifest_rows[0].get("bytes"), manifest_rows[0].get("sha256")) != \
            (V10_REVIEW_MANIFEST_BYTES, V10_REVIEW_MANIFEST_SHA256):
        raise ValueError("R4 V10 parent review manifest differs from its exact base-map row")
    base_paths = {str(path) for table in (entries, refs, prefixes, absent, restored, restored_dirs)
                  for path in _logical_paths_in(table)}
    for key in ("r4_historical_absent_output_slots", R4_V9_STATIC_RAW_SIDECAR_KEY,
                R4_V6_SCOPEFIX_ADDENDUM_KEY):
        base_paths.update(_logical_paths_in(protocol.get(key)))
    folded_base = {path.casefold() for path in base_paths}
    if len(R4_V10_ROOT_OBSERVATION_PATHS) != 5 or len(set(R4_V10_ROOT_OBSERVATION_PATHS)) != 5:
        raise ValueError("R4 V10 root observation target set is not exactly five paths")
    workspace = pathlib.Path(root).resolve()
    for logical in R4_V10_ROOT_OBSERVATION_PATHS:
        rel = _confined_relative(logical, "R4 V10 root observation target")
        folded = logical.casefold()
        if rel.parts[:1] != ("docs",) or any(
                folded == item or folded.startswith(item + "/") or item.startswith(folded + "/")
                for item in folded_base):
            raise ValueError(f"R4 V10 root observation target overlaps an existing path: {logical}")
        if any(folded == str(row.get("logical_path", "")).rstrip("/").casefold() or
               folded.startswith(str(row.get("logical_path", "")).rstrip("/").casefold() + "/") or
               str(row.get("logical_path", "")).rstrip("/").casefold().startswith(folded + "/")
               for row in prefixes if isinstance(row, Mapping)):
            raise ValueError(f"R4 V10 root observation target overlaps a base directory prefix: {logical}")
        cursor = workspace
        for part in rel.parts:
            cursor = cursor / part
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V10 workspace target contains a reparse point: {logical}")
        if cursor.exists():
            raise ValueError(f"R4 V10 root observation target must remain absent in workspace: {logical}")
    expected_route = {
        "schema": R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA, "proof_key": R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY,
        "proof_schema": R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA,
        "logical_paths": list(R4_V10_ROOT_OBSERVATION_PATHS),
        "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                       "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
                       "exact_five_v10_root_observation_addendum", "original_checked_path"],
        "nonmatching_paths": "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path",
        "exact_relative_paths_only": True, "absolute_addendum_aliases": False,
        "materialization_root": contract.get("staging_root"), "materializes_only_addendum_rows": True,
        "materializes_inside_repository_docs": False, "changes_613_file_map": False,
        "changes_645_reference_set": False, "changes_31_directory_prefixes": False,
        "changes_four_absence_proofs": False, "changes_v15_or_v16_evidence": False,
        "changes_original_eight_source_overlays": False, "numerical_credit": False,
        "physical_credit": False, "runtime_grant": False,
    }
    if protocol.get(R4_V10_ROOT_OBSERVATION_ROUTE_KEY) != expected_route:
        raise ValueError("R4 V10 root observation route or stage binding changed")
    if archive is None:
        if _sha256_file(archive_path) != ARCHIVE_SHA256:
            raise ValueError("R4 V10 root observation ZIP whole-file SHA changed")
        archive_context = zipfile.ZipFile(archive_path, "r")
        close_archive = True
    else:
        if pathlib.Path(str(archive.filename)).resolve() != archive_path:
            raise ValueError("R4 V10 root observation ZIP handle is not the pinned archive")
        archive_context, close_archive = archive, False
    try:
        manifest_bytes = _read_unique_v10_zip_member(archive_context, V10_REVIEW_MANIFEST_REL)
        if len(manifest_bytes) != 4013 or _sha256(manifest_bytes) != V10_REVIEW_MANIFEST_SHA256:
            raise ValueError("R4 V10 review manifest ZIP bytes differ from exact pin")
        manifest = json.loads(manifest_bytes)
        observation_bytes = _read_unique_v10_zip_member(archive_context, V10_ROOT_OBSERVATION_PATH)
        if len(observation_bytes) != 8230 or _sha256(observation_bytes) != V10_ROOT_OBSERVATION_SHA256:
            raise ValueError("R4 V10 observation ZIP bytes differ from exact pin")
        observation = json.loads(observation_bytes)
        if observation.get("schema") != "root_mms_v10_actual_observation_v1" or proof.get("root_observation") != {
                "logical_path": V10_ROOT_OBSERVATION_PATH, "bytes": 8230, "sha256": V10_ROOT_OBSERVATION_SHA256}:
            raise ValueError("R4 V10 observation source document differs from exact pin")
        selected = _v10_root_observation_rows(manifest, observation)
        proof_rows = proof.get("rows")
        if not isinstance(proof_rows, list) or len(proof_rows) != 5 or any(
                not isinstance(row, Mapping) or type(row.get("bytes")) is not int
                for row in proof_rows
        ):
            raise ValueError("R4 V10 proof row byte sizes must be exact integers")
        if proof.get("row_count") != 5 or proof_rows != selected:
            raise ValueError("R4 V10 proof differs from the exact five source-bound rows")
        payloads: dict[str, bytes] = {}
        for row in selected:
            logical = row["logical_path"]
            if row["archive_member"] != logical or (row["bytes"], row["sha256"]) != \
                    R4_V10_ROOT_OBSERVATION_TARGETS[logical]:
                raise ValueError(f"R4 V10 row differs from fixed pin: {logical}")
            payload = _read_unique_v10_zip_member(archive_context, logical)
            if len(payload) != row["bytes"] or _sha256(payload) != row["sha256"]:
                raise ValueError(f"R4 V10 archive member differs from bound row: {logical}")
            payloads[logical] = payload
    finally:
        if close_archive:
            archive_context.close()
    return {"proof": dict(proof), "rows": [dict(row) for row in selected], "payloads": payloads}


def _materialize_v10_root_observation_input_addendum(root: pathlib.Path, protocol: Mapping[str, Any],
                                                       stage_root: pathlib.Path,
                                                       validated: Mapping[str, Any]) -> dict[str, Any]:
    proof = protocol.get(R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY)
    contract = protocol.get("archived_input_source")
    ownership = protocol.get("r4_output_ownership")
    if not isinstance(proof, Mapping) or not isinstance(contract, Mapping) or not isinstance(ownership, Mapping) or \
            validated.get("proof") != proof:
        raise ValueError("R4 V10 materializer lacks the validated protocol proof")
    workspace, stage_arg = pathlib.Path(root).resolve(), pathlib.Path(stage_root)
    stage = stage_arg.resolve()
    external_root = pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve()
    output_leaf = pathlib.Path(str(ownership.get("runtime_output_leaf", ""))).resolve()
    if stage != pathlib.Path(str(contract.get("staging_root", ""))).resolve() or \
            stage != pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve() or \
            not stage.is_relative_to(external_root) or stage.is_relative_to((workspace / "docs").resolve()) or \
            ownership.get("outside_repository_docs") is not True or stage_arg != stage or \
            not stage.is_dir() or output_leaf.exists():
        raise ValueError("R4 V10 materializer stage/output is not the fresh external R4 root")
    route, rows, payloads = protocol.get(R4_V10_ROOT_OBSERVATION_ROUTE_KEY), validated.get("rows"), validated.get("payloads")
    if not isinstance(route, Mapping) or route.get("materialization_root") != str(stage) or \
            not isinstance(rows, list) or len(rows) != 5 or not isinstance(payloads, Mapping) or \
            set(payloads) != set(R4_V10_ROOT_OBSERVATION_PATHS) or rows != proof.get("rows") or \
            [row.get("logical_path") for row in rows if isinstance(row, Mapping)] != route.get("logical_paths"):
        raise ValueError("R4 V10 materializer rows or payloads are incomplete")
    targets: list[tuple[dict[str, Any], bytes, pathlib.Path]] = []
    for row in rows:
        logical = row.get("logical_path") if isinstance(row, Mapping) else None
        if not isinstance(logical, str) or logical not in R4_V10_ROOT_OBSERVATION_TARGETS or \
                row.get("archive_member") != logical:
            raise ValueError("R4 V10 materializer path is outside the exact five rows")
        rel = _confined_relative(logical, "R4 V10 materialization target")
        target, payload = stage.joinpath(*rel.parts), payloads.get(logical)
        expected_size, expected_sha = R4_V10_ROOT_OBSERVATION_TARGETS[logical]
        if not target.resolve().is_relative_to(stage) or not isinstance(payload, bytes) or \
                len(payload) != expected_size or _sha256(payload) != expected_sha or \
                row.get("bytes") != expected_size or row.get("sha256") != expected_sha:
            raise ValueError(f"R4 V10 materializer bytes or path differ from fixed row: {logical}")
        for path in (stage, *stage.parents):
            if _is_reparse_point(path):
                raise ValueError(f"R4 V10 stage contains a reparse point: {path}")
        cursor = stage
        for part in rel.parts:
            cursor = cursor / part
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V10 target contains a reparse point: {cursor}")
        if target.exists() or target.is_symlink():
            raise FileExistsError(f"R4 V10 target already exists: {logical}")
        for parent_path in target.parents:
            if parent_path == stage:
                break
            if parent_path.exists() and not parent_path.is_dir():
                raise ValueError(f"R4 V10 target parent is not a directory: {parent_path}")
        targets.append((dict(row), payload, target))
    written: list[dict[str, Any]] = []
    for row, payload, target in targets:
        missing: list[pathlib.Path] = []
        parent = target.parent
        while parent != stage and not parent.exists():
            missing.append(parent)
            parent = parent.parent
        for directory in reversed(missing):
            directory.mkdir()
            if _is_reparse_point(directory):
                raise ValueError(f"R4 V10 created a reparse point: {directory}")
        with target.open("xb") as stream:
            stream.write(payload)
        size, digest = R4_V10_ROOT_OBSERVATION_TARGETS[row["logical_path"]]
        if _is_reparse_point(target) or not target.is_file() or target.stat().st_size != size or \
                _sha256_file(target) != digest:
            raise ValueError(f"R4 V10 materialized bytes differ from fixed row: {row['logical_path']}")
        written.append({**row, "staged_path": str(target.resolve())})
    return {"schema": R4_V10_ROOT_OBSERVATION_MATERIALIZATION_SCHEMA,
            "proof_sha256": _sha256(_canonical_bytes(proof)), "materialized_count": len(written), "rows": written}


class _R4PreMirrorAudit(dict[str, Any]):
    """Keep the legacy JSON-safe audit keys while carrying verified ZIP payloads in-process."""

    def __init__(self, audit: Mapping[str, Any], validated_addendum: dict[str, Any],
                 validated_v10_addendum: dict[str, Any]) -> None:
        super().__init__(audit)
        self._validated_addendum = validated_addendum
        self._validated_v10_addendum = validated_v10_addendum

    def get(self, key: str, default: Any = None) -> Any:
        if key == R4_V6_SCOPEFIX_ADDENDUM_KEY:
            return self._validated_addendum
        return super().get(key, default)


def verify_v10_closure_before_mirror(protocol_path: pathlib.Path | str, supplied_sha256: str,
                                     protocol: Mapping[str, Any], root: pathlib.Path = ROOT,
                                     non_doc_v10_resolver: Callable[
                                         [pathlib.Path, zipfile.ZipFile, dict[str, object]], dict[str, object]
                                     ] | None = None) -> dict[str, Any]:
    """Check the exact CLI protocol pin and all V10 inputs before original mirror materialization."""
    actual_path = pathlib.Path(protocol_path).resolve()
    if actual_path not in (R6_PROTOCOL_PATH.resolve(), R7_PROTOCOL_PATH.resolve()):
        raise ValueError("pre-mirror gate accepts only replay_protocol_v21_r6.json or replay_protocol_v21_r7.json")
    if not isinstance(supplied_sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", supplied_sha256):
        raise ValueError("R2 pre-mirror gate requires the exact lowercase CLI protocol SHA-256")
    wire = actual_path.read_bytes()
    if _sha256(wire) != supplied_sha256:
        raise ValueError("R2 CLI --protocol-sha256 differs from actual protocol bytes")
    parsed = json.loads(wire)
    if parsed != dict(protocol):
        raise ValueError("R2 protocol object passed to the original resolver differs from CLI bytes")
    audit = audit_v10_input_closure_before_mirror(parsed, root, non_doc_v10_resolver)
    archive_path = pathlib.Path(str(parsed["archived_input_source"]["archive_path"])).resolve()
    with zipfile.ZipFile(archive_path, "r") as archive:
        validated_addendum = _validate_v6_scopefix_closure_addendum(parsed, root, archive=archive)
        validated_v10_addendum = _validate_v10_root_observation_input_addendum(parsed, root, archive=archive)
    return _R4PreMirrorAudit(audit, validated_addendum, validated_v10_addendum)


def _invocation_bindings() -> tuple[pathlib.Path, str | None]:
    protocol_path = R7_PROTOCOL_PATH
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


def _load_historical_absence_helper(protocol: dict[str, Any]) -> types.ModuleType:
    pins = protocol.get("owned_source_files_by_path", {})
    rows = protocol.get("owned_source_files", [])
    helper_sha = pins.get(R4_ABSENCE_HELPER_REL)
    matching = [row for row in rows if row.get("path") == R4_ABSENCE_HELPER_REL]
    if not isinstance(helper_sha, str) or len(helper_sha) != 64 or len(matching) != 1:
        raise ValueError("R4 historical absence helper lacks one exact owned source pin")
    path = BASE / "historical_absent_output_slots_v21_r4.py"
    wire = _read_pinned(path, helper_sha, "R4 historical absence helper")
    if matching[0].get("bytes") != len(wire) or matching[0].get("sha256") != helper_sha:
        raise ValueError("R4 historical absence helper row differs from its actual source bytes")
    route = protocol.get("r4_checked_path_absence_route", {})
    if route.get("schema") != "mms-v21-r4-historical-absent-output-route-v1" or \
            route.get("helper_path") != R4_ABSENCE_HELPER_REL or \
            route.get("helper_sha256") != helper_sha or route.get("fixed_slot_count") != 4 or \
            route.get("all_other_paths_use_original_checked_path") is not True or \
            any(route.get(key) is not False for key in (
                "materializes_archive_or_output_paths", "overrides_path_exists_or_is_file",
                "changes_v16_expected_absent_semantics", "changes_original_eight_source_overlays",
                "runtime_grant")):
        raise ValueError("R4 historical absence route differs from its narrow no-credit contract")
    sidecar_route = protocol.get(R4_V9_STATIC_RAW_ROUTE_KEY, {})
    sidecar_proof = protocol.get(R4_V9_STATIC_RAW_SIDECAR_KEY, {})
    if sidecar_route.get("schema") != R4_V9_STATIC_RAW_ROUTE_SCHEMA or \
            sidecar_route.get("helper_path") != R4_ABSENCE_HELPER_REL or \
            sidecar_route.get("helper_sha256") != helper_sha or \
            sidecar_route.get("proof_key") != R4_V9_STATIC_RAW_SIDECAR_KEY or \
            sidecar_route.get("proof_schema") != R4_V9_STATIC_RAW_SIDECAR_SCHEMA or \
            sidecar_route.get("logical_paths") != list(R4_V9_STATIC_RAW_PATHS) or \
            sidecar_route.get("precedence") != [
                "exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                "original_checked_path"] or \
            sidecar_route.get("nonmatching_paths") != \
                "existing_four_absence_route_then_original_checked_path" or \
            any(sidecar_route.get(key) is not False for key in (
                "changes_613_file_map", "changes_645_reference_set", "changes_31_directory_prefixes",
                "changes_four_absence_proofs", "changes_original_eight_source_overlays",
                "changes_runtime_grant")) or sidecar_route.get("runtime_grant") is not False:
        raise ValueError("R4 V9 raw sidecar route differs from its exact-three no-credit contract")
    if not isinstance(sidecar_proof, dict) or sidecar_proof.get("schema") != R4_V9_STATIC_RAW_SIDECAR_SCHEMA:
        raise ValueError("R4 V9 raw sidecar proof is missing or malformed")
    module = types.ModuleType("_up2_r4_historical_absence_runtime")
    module.__file__ = str(path)
    module.__package__ = None
    sys.modules[module.__name__] = module
    exec(compile(wire, str(path), "exec", dont_inherit=True), module.__dict__)
    return module


def _absolute_archive_file_aliases(root: pathlib.Path,
                                   protocol: dict[str, Any]) -> dict[str, str]:
    """Bind lexical absolute file aliases to the unchanged, source-pinned map."""
    if str(root) != str(ROOT) or root.resolve() != ROOT.resolve():
        raise ValueError("R4 absolute archive aliases require the exact repository root")
    rows = protocol.get("archived_input_source", {}).get("entries")
    if not isinstance(rows, list) or len(rows) != 613:
        raise ValueError("R4 absolute archive aliases require the unchanged 613 file map")
    expected_route = {
        "schema": R4_ABSOLUTE_ARCHIVE_ROUTE_SCHEMA,
        "repository_root": str(ROOT),
        "mapped_file_count": 613,
        "mapped_rows_sha256": _sha256(_canonical_bytes(rows)),
        "mapping_rule": "exact root plus canonical logical file path; separator normalization only",
        "consumer": "original checked_path and original ArchivedInputResolver size/SHA checks",
        "changes_613_file_map": False,
        "changes_v15_evidence": False,
        "changes_four_absence_or_three_sidecar_routes": False,
        "runtime_grant": False,
    }
    if protocol.get(R4_ABSOLUTE_ARCHIVE_ROUTE_KEY) != expected_route:
        raise ValueError("R4 absolute archive route differs from its source-bound file map")
    aliases: dict[str, str] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("R4 absolute archive map row is malformed")
        logical = row.get("logical_path")
        parts = _confined_relative(logical, "R4 absolute archive logical file path")
        absolute = root.joinpath(*parts.parts)
        if not absolute.resolve().is_relative_to(root.resolve()):
            raise ValueError("R4 absolute archive file alias escapes its bound repository")
        alias = str(absolute).replace("\\", "/")
        if alias in aliases:
            raise ValueError("R4 absolute archive file alias is ambiguous")
        aliases[alias] = logical
    return aliases


def _install_historical_absent_output_slots(controller: types.ModuleType,
                                           protocol: dict[str, Any]) -> None:
    helper = _load_historical_absence_helper(protocol)
    absolute_aliases = _absolute_archive_file_aliases(ROOT, protocol)
    controller._r4_v9_static_raw_sidecar_helper = helper
    controller._r4_v9_static_raw_sidecar_materialization = None
    controller._r4_v6_scopefix_staged_paths = {}
    controller._r4_v6_scopefix_addendum_materialization = None
    controller._r4_v10_root_observation_staged_paths = {}
    controller._r4_v10_root_observation_materialization = None
    original = getattr(controller, "_r4_original_checked_path", controller.checked_path)
    controller._r4_original_checked_path = original

    def checked_path_with_fixed_absent_output_slots(root: pathlib.Path, relative: str) -> pathlib.Path:
        resolver = controller.ARCHIVE_INPUTS
        if isinstance(relative, str) and relative in R4_V6_SCOPEFIX_PATHS and \
                (str(root) != str(ROOT) or pathlib.Path(root).resolve() != ROOT.resolve() or
                 resolver is None or resolver.root != ROOT.resolve()):
            raise ValueError("R4 V6 scopefix addendum route requires the exact repository root and resolver")
        if relative in R4_V9_STATIC_RAW_PATHS:
            if resolver is None:
                raise ValueError("R4 V9 raw sidecar requires the initialized original archive resolver")
            sidecar = helper.resolve_v9_static_raw_output_sidecar_v21_r4(
                root, protocol, resolver.stage_root, relative,
                protocol.get(R4_V9_STATIC_RAW_SIDECAR_KEY))
            if sidecar is None:
                raise ValueError(f"R4 exact V9 static raw path did not resolve through its sidecar: {relative}")
            return sidecar
        if resolver is None:
            # Only exact declared slots can require the initialized original resolver.
            stage_root = None
        else:
            stage_root = resolver.stage_root
        absent = helper.resolve_historical_absent_output_slot_v21_r4(
            root, protocol, stage_root, relative,
            protocol.get("r4_historical_absent_output_slots"))
        if absent is not None:
            return absent
        logical = absolute_aliases.get(relative.replace("\\", "/")) if isinstance(relative, str) else None
        if logical is not None:
            # The original resolver still verifies the workspace or staged bytes.
            # No directories, absent outputs, sidecar files or other aliases enter this route.
            mapped = next(row for row in protocol["archived_input_source"]["entries"]
                          if row["logical_path"] == logical)
            if resolver is None or str(root) != str(ROOT) or resolver.root != ROOT.resolve() or \
                    resolver.entries.get(logical) != mapped:
                raise ValueError("R4 absolute archive alias lacks the exact initialized resolver binding")
            return original(root, logical)
        if isinstance(relative, str) and relative in R4_V6_SCOPEFIX_PATHS:
            staged_paths = controller._r4_v6_scopefix_staged_paths
            if resolver is None or not isinstance(staged_paths, dict) or relative not in staged_paths:
                raise FileNotFoundError(f"R4 V6 scopefix addendum path was not materialized: {relative}")
            raw_target = pathlib.Path(staged_paths[relative])
            expected = resolver.stage_root / pathlib.Path(*PurePosixPath(relative).parts)
            if raw_target != expected:
                raise ValueError(f"R4 V6 scopefix addendum staged path differs from its exact mirror binding: {relative}")
            cursor = resolver.stage_root
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V6 scopefix addendum mirror contains a reparse point: {relative}")
            for part in PurePosixPath(relative).parts:
                cursor = cursor / part
                if _is_reparse_point(cursor):
                    raise ValueError(f"R4 V6 scopefix addendum path contains a reparse point: {relative}")
            target = raw_target.resolve()
            if target != expected or not target.is_relative_to(resolver.stage_root) or not target.is_file():
                raise ValueError(f"R4 V6 scopefix addendum staged path differs from its exact mirror binding: {relative}")
            return target
        if isinstance(relative, str) and relative in R4_V10_ROOT_OBSERVATION_PATHS:
            route = protocol.get(R4_V10_ROOT_OBSERVATION_ROUTE_KEY)
            contract = protocol.get("archived_input_source")
            ownership = protocol.get("r4_output_ownership")
            expected_stage = pathlib.Path(str(route.get("materialization_root", ""))).resolve() \
                if isinstance(route, Mapping) else pathlib.Path()
            external_root = pathlib.Path(str(ownership.get("raw_external_root", ""))).resolve() \
                if isinstance(ownership, Mapping) else pathlib.Path()
            if str(root) != str(ROOT) or pathlib.Path(root).resolve() != ROOT.resolve() or \
                    resolver is None or resolver.root != ROOT.resolve() or \
                    not isinstance(route, Mapping) or not isinstance(contract, Mapping) or \
                    not isinstance(ownership, Mapping) or resolver.stage_root != expected_stage or \
                    expected_stage != pathlib.Path(str(contract.get("staging_root", ""))).resolve() or \
                    expected_stage != pathlib.Path(str(ownership.get("archive_mirror_root", ""))).resolve() or \
                    not expected_stage.is_relative_to(external_root) or \
                    expected_stage.is_relative_to((ROOT / "docs").resolve()):
                raise ValueError("R4 V10 root observation route requires the exact repository root and resolver stage")
            staged_paths = controller._r4_v10_root_observation_staged_paths
            if not isinstance(staged_paths, dict) or relative not in staged_paths:
                raise FileNotFoundError(f"R4 V10 root observation path was not materialized: {relative}")
            proof = protocol.get(R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY)
            rows = proof.get("rows") if isinstance(proof, Mapping) else None
            matches = [row for row in rows if isinstance(row, Mapping) and row.get("logical_path") == relative] \
                if isinstance(rows, list) else []
            if len(matches) != 1:
                raise ValueError(f"R4 V10 root observation route lacks one exact row: {relative}")
            row = matches[0]
            if type(row.get("bytes")) is not int:
                raise ValueError(f"R4 V10 root observation row byte size is not an exact integer: {relative}")
            raw_target = pathlib.Path(staged_paths[relative])
            expected = resolver.stage_root / pathlib.Path(*PurePosixPath(relative).parts)
            if raw_target != expected:
                raise ValueError(f"R4 V10 root observation staged path differs from its exact mirror binding: {relative}")
            cursor = resolver.stage_root
            if _is_reparse_point(cursor):
                raise ValueError(f"R4 V10 root observation mirror contains a reparse point: {relative}")
            for part in PurePosixPath(relative).parts:
                cursor = cursor / part
                if _is_reparse_point(cursor):
                    raise ValueError(f"R4 V10 root observation path contains a reparse point: {relative}")
            target = raw_target.resolve()
            if target != expected or not target.is_relative_to(resolver.stage_root) or not target.is_file() or \
                    target.stat().st_size != row.get("bytes") or _sha256_file(target) != row.get("sha256"):
                raise ValueError(f"R4 V10 root observation staged bytes differ from its exact row: {relative}")
            return target
        return original(root, relative)

    controller.checked_path = checked_path_with_fixed_absent_output_slots


def _stage_archive_before_v10_binding(source: bytes) -> bytes:
    text = source.decode("utf-8")
    start_marker = '        v10_ref = protocol.get("v10_protocol")\n'
    end_marker = '            raise ValueError("V21 V10 input categories changed; expected 18 docs and 71 workspace inputs")\n\n'
    insert_marker = '        if set(self.expected_absent) & set(self.entries) or \\\n'
    if text.count(start_marker) != 1 or text.count(end_marker) != 1 or text.count(insert_marker) != 1:
        raise ValueError("V10 binding relocation requires exact frozen controller anchors")
    start = text.index(start_marker)
    end = text.index(end_marker, start) + len(end_marker)
    block = text[start:end]
    remaining = text[:start] + text[end:]
    insert = remaining.index(insert_marker)
    if insert <= start:
        raise ValueError("V10 binding relocation would precede archive staging")
    return (remaining[:insert] + block + remaining[insert:]).encode("utf-8")


def _bind_active_source_rows(source: bytes) -> bytes:
    text = source.decode("utf-8")
    old = '    source_files = protocol["owned_source_files"]\n'
    if text.count(old) != 1:
        raise ValueError("active source binding requires one exact frozen controller anchor")
    return text.replace(old, '    source_files = _r7_active_source_rows(protocol)\n', 1).encode("utf-8")


def _bind_staged_v10_review_leaf(source: bytes) -> bytes:
    text = source.decode("utf-8")
    old = '        rel = path.relative_to(root.resolve()).as_posix()\n'
    new = ('        rel = (PurePosixPath(review["manifest_path"]).parent / name).as_posix()\n'
           '        if checked_path(root, rel).resolve() != path:\n'
           '            raise ValueError("V10 review staged leaf differs from its logical path")\n')
    if text.count(old) != 1:
        raise ValueError("V10 review leaf binding requires one exact frozen controller anchor")
    return text.replace(old, new, 1).encode("utf-8")


def _bind_v11_recorded_argv_to_original_root(source: bytes) -> bytes:
    text = source.decode("utf-8")
    old = '    expected_command[5] = str((runtime_root / "producer_process/numerical").resolve())\n'
    new = ('    expected_command[5] = str((root / pathlib.Path(*PurePosixPath(runtime["root"]).parts) '
           '/ "producer_process/numerical").resolve())\n')
    if text.count(old) != 1:
        raise ValueError("V11 recorded argv binding requires one exact frozen controller anchor")
    return text.replace(old, new, 1).encode("utf-8")


def _load_frozen_controller(protocol_path: pathlib.Path,
                            supplied_sha256: str | None) -> tuple[types.ModuleType, dict[str, Any]]:
    protocol = _read_selected_protocol(protocol_path, supplied_sha256)
    _verify_r6_route_identity(protocol)
    spec = _load_spec(protocol, protocol_path)
    protocol = _verify_protocol_self_pins(protocol, spec)
    source_pins = protocol["owned_source_files_by_path"]
    original = _read_pinned(ORIGINAL_CONTROLLER, source_pins[ORIGINAL_CONTROLLER_REL], "R6 canonical controller")
    base_transformed = _apply_exact_line_overlay(original, spec)
    overlay = protocol["r4_controller_overlay"]
    if overlay.get("transformed_source_sha256") != _sha256(base_transformed):
        raise ValueError("transformed V21 controller source differs from its preserved eight-overlay proof")
    transformed = _apply_r4_v10_path_binding_addendum(
        base_transformed, protocol.get(R4_V10_PATH_BINDING_KEY))
    transformed = _stage_archive_before_v10_binding(transformed)
    transformed = _bind_active_source_rows(transformed)
    transformed = _bind_staged_v10_review_leaf(transformed)
    transformed = _bind_v11_recorded_argv_to_original_root(transformed)
    module = types.ModuleType("_frozen_v21_controller_r6_path_overlay")
    module.__file__ = str(pathlib.Path(__file__).resolve())
    module.__package__ = None
    def active_source_rows(runtime_protocol: dict[str, Any]) -> list[dict[str, Any]]:
        parent_rows = runtime_protocol.get("owned_source_files")
        if not isinstance(parent_rows, list):
            raise ValueError("active source binding lacks the complete parent source rows")
        if pathlib.Path(protocol_path).resolve() != R7_PROTOCOL_PATH.resolve():
            return parent_rows
        if runtime_protocol != protocol:
            raise ValueError("active source binding differs from the selected R7 protocol")
        current_rows = runtime_protocol.get("r7_current_source_files")
        current_pins = runtime_protocol.get("r7_current_source_files_by_path")
        preimages = runtime_protocol.get("r7_parent_preimages")
        if not isinstance(current_rows, list) or not isinstance(current_pins, dict) or \
                not isinstance(preimages, dict) or len(current_rows) != 2 or \
                set(current_pins) != set(preimages) or \
                current_pins != {row.get("path"): row.get("sha256") for row in current_rows}:
            raise ValueError("R7 active and parent source bindings differ")
        by_path = {row["path"]: row for row in current_rows}
        if len(by_path) != 2 or not set(by_path).issubset({row.get("path") for row in parent_rows}):
            raise ValueError("R7 active source rows do not replace exactly two parent paths")
        return [dict(by_path[row["path"]]) if row["path"] in by_path else dict(row)
                for row in parent_rows]
    module.__dict__["_r7_active_source_rows"] = active_source_rows
    module.__dict__["_r4_v10_original_path_binding"] = (
        lambda root, logical, physical, kind: _r4_v10_original_path_binding(
            module, root, logical, physical, kind))
    transformed_source = transformed.decode("utf-8")
    module.__dict__["R4_TRANSFORMED_CONTROLLER_SOURCE"] = transformed_source
    code = compile(transformed_source, str(ORIGINAL_CONTROLLER), "exec", dont_inherit=True)
    exec(code, module.__dict__)
    canonical_default = R6_PROTOCOL_PATH.resolve()
    if module.DEFAULT_PROTOCOL.resolve() != canonical_default:
        raise ValueError("frozen V21 controller default protocol path changed")
    module.DEFAULT_PROTOCOL = pathlib.Path(protocol_path).resolve()
    _install_historical_absent_output_slots(module, protocol)
    return module, protocol


def main() -> int:
    protocol_path, supplied_sha = _invocation_bindings()
    controller, _protocol = _load_frozen_controller(protocol_path, supplied_sha)
    original_resolver = controller.ArchivedInputResolver

    def resolver_with_read_only_preflight(root: pathlib.Path, protocol: dict[str, Any]) -> Any:
        if supplied_sha is None:
            raise ValueError("R2 pre-mirror gate did not receive the actual CLI --protocol-sha256")
        preflight = verify_v10_closure_before_mirror(
            protocol_path, supplied_sha, protocol, root,
            non_doc_v10_resolver=controller.resolve_non_doc_v10_input)
        resolver = original_resolver(root, protocol)
        if type(resolver) is not original_resolver:
            raise TypeError("R2 pre-mirror gate did not return the original V21 archive resolver instance")
        validated_addendum = preflight.get("r4_v6_scopefix_closure_addendum")
        if not isinstance(validated_addendum, dict):
            raise ValueError("R4 V6 scopefix addendum did not pass the pre-mirror source gate")
        addendum_receipt = _materialize_v6_scopefix_closure_addendum(
            root, protocol, resolver.stage_root, validated_addendum)
        addendum_rows = addendum_receipt.get("rows")
        if not isinstance(addendum_rows, list) or len(addendum_rows) != 5 or \
                {row.get("logical_path") for row in addendum_rows if isinstance(row, dict)} != R4_V6_SCOPEFIX_PATHS:
            raise ValueError("R4 V6 scopefix addendum materializer returned an incomplete receipt")
        controller._r4_v6_scopefix_staged_paths = {
            row["logical_path"]: pathlib.Path(row["staged_path"]) for row in addendum_rows
        }
        controller._r4_v6_scopefix_addendum_materialization = addendum_receipt

        helper = controller._r4_v9_static_raw_sidecar_helper
        proof = protocol.get(R4_V9_STATIC_RAW_SIDECAR_KEY)
        materialized = helper.materialize_v9_static_raw_output_sidecar_v21_r4(
            root, protocol, resolver.stage_root, proof)
        if not isinstance(materialized, tuple) or len(materialized) != len(R4_V9_STATIC_RAW_PATHS) or \
                any(not isinstance(row, dict) for row in materialized):
            raise ValueError("R4 V9 sidecar materializer returned an incomplete receipt")
        materialized_by_path = {row.get("logical_path"): row for row in materialized}
        if len(materialized_by_path) != len(R4_V9_STATIC_RAW_PATHS) or \
                set(materialized_by_path) != set(R4_V9_STATIC_RAW_PATHS):
            raise ValueError("R4 V9 sidecar materializer returned duplicate or unexpected logical paths")
        for logical_path, (expected_bytes, expected_sha) in R4_V9_STATIC_RAW_EXPECTED.items():
            row = materialized_by_path[logical_path]
            target = (resolver.stage_root / pathlib.Path(*PurePosixPath(logical_path).parts)).resolve()
            if row.get("bytes") != expected_bytes or row.get("sha256") != expected_sha or \
                    row.get("staged_path") != str(target) or not target.is_relative_to(resolver.stage_root) or \
                    not target.is_file() or target.stat().st_size != expected_bytes or \
                    _sha256_file(target) != expected_sha or row.get("archive_member") != logical_path:
                raise ValueError(f"R4 V9 sidecar materialization differs from its frozen raw receipt: {logical_path}")
        sidecar_receipt = {
            "schema": R4_V9_STATIC_RAW_SIDECAR_SCHEMA,
            "proof_sha256": _sha256(_canonical_bytes(proof)),
            "materialized_count": len(materialized),
            "rows": [dict(materialized_by_path[path]) for path in R4_V9_STATIC_RAW_PATHS],
        }
        controller._r4_v9_static_raw_sidecar_materialization = sidecar_receipt
        validated_v10_addendum = preflight._validated_v10_addendum
        v10_receipt = _materialize_v10_root_observation_input_addendum(
            root, protocol, resolver.stage_root, validated_v10_addendum)
        v10_rows = v10_receipt.get("rows")
        if not isinstance(v10_rows, list) or len(v10_rows) != 5 or \
                {row.get("logical_path") for row in v10_rows if isinstance(row, dict)} != \
                set(R4_V10_ROOT_OBSERVATION_PATHS):
            raise ValueError("R4 V10 root observation materializer returned an incomplete receipt")
        controller._r4_v10_root_observation_staged_paths = {
            row["logical_path"]: pathlib.Path(row["staged_path"]) for row in v10_rows
        }
        controller._r4_v10_root_observation_materialization = v10_receipt
        original_resolution_receipt = resolver.resolution_receipt
        if not callable(original_resolution_receipt):
            raise TypeError("R4 original resolver has no resolution receipt method")

        def resolution_receipt_with_r4_addenda() -> dict[str, Any]:
            receipt = original_resolution_receipt()
            if not isinstance(receipt, dict) or R4_V9_STATIC_RAW_SIDECAR_KEY in receipt or \
                    R4_V6_SCOPEFIX_MATERIALIZATION_KEY in receipt or \
                    R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY in receipt:
                raise ValueError("R4 original archive resolution receipt is malformed or already supplemented")
            receipt[R4_V9_STATIC_RAW_SIDECAR_KEY] = dict(sidecar_receipt)
            receipt[R4_V6_SCOPEFIX_MATERIALIZATION_KEY] = dict(addendum_receipt)
            receipt[R4_V10_ROOT_OBSERVATION_MATERIALIZATION_KEY] = dict(v10_receipt)
            return receipt

        resolver.resolution_receipt = resolution_receipt_with_r4_addenda
        return resolver

    # The original resolver owns the unchanged 613-file map; V9, V6, and V10 addenda
    # stay separately receipted, then the original checked_path fallback remains.
    controller.ArchivedInputResolver = resolver_with_read_only_preflight
    return int(controller.main())


if __name__ == "__main__":
    raise SystemExit(main())
