#!/usr/bin/env python3
"""Build the R4 protocol as a narrow, no-credit successor to the frozen R3 run."""
from __future__ import annotations

import argparse
import ast
import copy
import datetime as dt
import difflib
import hashlib
import json
import pathlib
import re
import sys
import types
import zipfile
from typing import Any


ROOT = pathlib.Path(__file__).resolve().parents[3]
BASE = pathlib.Path(__file__).resolve().parent
ARCHIVE_PATH = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "precleanup_docs_runs_tmp.zip"
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"

R2_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r2.json"
R2_PROTOCOL_SHA256 = "e6a6917bc720b7f61a48707aea60d5377b67c3c61c30c817eeacfb1dfa9b0659"
R2_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r2"
R3_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json"
R3_PROTOCOL_SHA256 = "1688c51f96cf87ebaec3df75409954f21ac11ca22ecc589ae72634f69c402119"
R3_PROTOCOL_PATH = ROOT / pathlib.Path(*pathlib.PurePosixPath(R3_PROTOCOL_REL).parts)
R3_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r3"
R3_STAGING_ROOT = R3_OUTPUT_ROOT / "archive_mirror"
R3_OUTPUT_LEAF = R3_OUTPUT_ROOT / "runtime_replay_r21_r3"
R3_FAILURE_LEAF = ROOT / "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1"
R3_RECEIPT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/external_exit_receipt.json"
R3_RECEIPT_SHA256 = "ccacd39c6e060f145879b8bfd147f4cfa9569b6c4f19477f7dab8cc1de8dfcdb"
R3_RECEIPT_BYTES = 1958
R3_FAILURE_STDERR_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/stderr.raw"
R3_FAILURE_STDERR_SHA256 = "ecf6ce659d814cdf9dda764f00142a40f67c0cda072a4577355664d841bb80ed"
R3_FAILURE_STDERR_BYTES = 1228
R3_RAW_MANIFEST_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/manifest.json"
R3_RAW_MANIFEST_SHA256 = "dd6ed92fc004ee358166c06c435a1bc2f3ff1359b70870b040c20e954c11888b"
R3_SOURCE_SNAPSHOT_REL = (
    "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_20260926_r1/"
    "independent_source_snapshot_pre_v20check_r1"
)
R3_SOURCE_SNAPSHOT_MANIFEST_SHA256 = "3238055aa7608a5ca0619ec82c3cc78e8208e490db3600e875373c56b5e3f30e"
R3_TEST_SNAPSHOT_REL = R3_SOURCE_SNAPSHOT_REL + "/test_independent_static_v21.actual_run.py"
R3_TEST_SNAPSHOT_SHA256 = "ec8e611fa730d90961a8a565b9433842ae81a6dc120d311881f8b0684b67b883"
R3_TEST_SNAPSHOT_BYTES = 38506
R3_STATIC_RECEIPT_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_static_qa_20260926_r3/external_exit_receipt.json"
R3_STATIC_RECEIPT_SHA256 = "788ad2d467190d3d866e9ab4be30b74382cd7f69c653cb63c74b8c865f93d97c"
R3_STATIC_RECEIPT_BYTES = 863
R3_STATIC_STDERR_REL = "runs/UP2ClosureReplayOnlyV21/runtime_launcher_r21_r3_static_qa_20260926_r3/stderr.raw"
R3_STATIC_STDERR_SHA256 = "a536c48133978dca3572b33186956fac6a4e3fcd87a0d1d1cc5a6931cda0c7ad"
R3_STATIC_STDERR_BYTES = 1795
R3_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r3.py"
R3_BUILDER_SHA256 = "f00fc8b32176dfd8af6b086a15a31e02cbe734696986d918d38931c1dab20905"
R3_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r3.py"
R3_CONTROLLER_SHA256 = "eab064af3761ebce10e7d44d096f98640fbb1b28d4b3ddf8f3f2d06b1fbf39ee"
R3_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r3.jl"
R3_ENTRYPOINT_SHA256 = "01024630a438ac9502e0a2b0b6a20ecdf3e1da0263f58b7d996fd6baf77d5dcc"
R3_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r3.json"
R3_SPEC_SHA256 = "58b951ad8a7bb660e6ce297fafc31090fd72bc2bc6e644c826326de308b833d5"

ORIGINAL_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21.py"
ORIGINAL_BUILDER_SHA256 = "d844efd26530bc4e240b2902baf53689b591aa7c862261816f1b751b018ca8e9"
ORIGINAL_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21.py"
ORIGINAL_CONTROLLER_SHA256 = "8fdbf6b38e53ac3ab4ea65310587587707a643f16e76d2623b23601239f05579"
ORIGINAL_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21.jl"
ORIGINAL_ENTRYPOINT_SHA256 = "ca2f0c6b6d4db4b1a3b2d9051f344af84cf0f9de3ff2f7bc479a644c8ae3dfa7"
ORIGINAL_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21.json"
ORIGINAL_PROTOCOL_SHA256 = "113fa02eb54d5b2aa870f2b9c07024def18427fa353c485f30568e50125c4b2e"
R2_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r2.py"
R2_BUILDER_SHA256 = "ba42c715ec566982fa62e3841c46fdfaea31ea559735473cc1314c0df8cf5271"
R2_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r2.py"
R2_CONTROLLER_SHA256 = "666c255aa2904eb55e90083b1ab59c32aed4fe4b5d005ef45afcc118905a3457"
R2_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r2.jl"
R2_ENTRYPOINT_SHA256 = "cb70e7e508510a251379509b8cd07a5d7afd580226409c06f4cab22618ab398e"
R2_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r2.json"
R2_SPEC_SHA256 = "369202ad82fa5669a5a1749117214f36bee9f01f953109ec53d6d9da39d3a345"

R4_BUILDER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/build_protocol_v21_r4.py"
R4_CONTROLLER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/run_replay_staged_v21_r4.py"
R4_ENTRYPOINT_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_staged_v21_r4.jl"
R4_SPEC_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/controller_overlay_spec_v21_r4.json"
R4_TEST_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/test_independent_static_v21.py"
R4_TEST_SHA256 = "77d4788e4471f8d13f38c0c36bb7a510db3145d5f4ccab4146a1aa94ff31783b"
R4_ABSENCE_HELPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/historical_absent_output_slots_v21_r4.py"
R4_ABSENCE_HELPER_SHA256 = "557df466f0b78364c2c9b75dd590ef3e9c64f0b2d5d384431f249f0ad0daff1e"
R4_V9_STATIC_RAW_SIDECAR_KEY = "r4_v9_static_raw_output_sidecar"
R4_V9_STATIC_RAW_SIDECAR_SCHEMA = "mms-v21-r4-v9-static-raw-output-sidecar-v1"
R4_V9_STATIC_RAW_ROUTE_KEY = "r4_checked_path_v9_raw_sidecar_route"
R4_V9_STATIC_RAW_ROUTE_SCHEMA = "mms-v21-r4-v9-static-raw-sidecar-route-v1"
R4_V9_STATIC_RAW_PATHS = (
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/exit_code.txt",
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/stderr.raw",
    "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/replay_only_continuation_r9/"
    "static_contract_check_v9_r1/stdout.raw",
)
R4_PROTOCOL_PATH = BASE / "replay_protocol_v21_r4.json"
R4_OUTPUT_ROOT = ROOT.parent / "FusionConceptAI_cleanup_20260926" / "up2_replay_v21_r4_scopefix_addendum_r1"
R4_STAGING_ROOT = R4_OUTPUT_ROOT / "archive_mirror"
R4_OUTPUT_LEAF = R4_OUTPUT_ROOT / "runtime_replay_r21_r4_v10inputs_20260927_01"
R4_SPEC_SHA256 = "e057248e6acff70594d71d023d362b3c79a92535d2b85f923377ee429b0a5e18"
R4_V6_SCOPEFIX_ADDENDUM_KEY = "r4_v6_postrun_scopefix_closure_addendum"
R4_V6_SCOPEFIX_ADDENDUM_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-transitive-closure-addendum-v1"
R4_V10_PATH_BINDING_KEY = "r4_v10_recorded_path_binding_addendum"
R4_V10_PATH_BINDING_SCHEMA = "mms-v21-r4-v10-recorded-path-binding-addendum-v1"
R4_V10_PATH_BINDING_REPLACEMENTS = [{'old_line': '                str(path.resolve()), path.stat().st_size, digest(path)):',
  'new_line': '                str(_r4_v10_original_path_binding(root, runtime[f"{key}_path"], '
              'path, "file")), path.stat().st_size, digest(path)):'},
 {'old_line': '        str((runtime_root / "producer_process/numerical").resolve()),',
  'new_line': '        str(_r4_v10_original_path_binding(root, runtime["root"], runtime_root, '
              '"directory") / "producer_process" / "numerical"),'}]
R4_V6_SCOPEFIX_ROUTE_KEY = "r4_checked_path_v6_scopefix_addendum_route"
R4_V6_SCOPEFIX_ROUTE_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-route-v1"
R4_V6_SCOPEFIX_MATERIALIZATION_KEY = "r4_v6_postrun_scopefix_addendum_materialization"
R4_V6_SCOPEFIX_MATERIALIZATION_SCHEMA = "mms-v21-r4-v6-postrun-scopefix-addendum-materialization-v1"
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
R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY = "r4_v10_root_observation_input_addendum"
R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA = "mms-v21-r4-v10-root-observation-input-addendum-v1"
R4_V10_ROOT_OBSERVATION_ROUTE_KEY = "r4_checked_path_v10_root_observation_input_route"
R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA = "mms-v21-r4-v10-root-observation-input-route-v1"
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
V10_ROOT_OBSERVATION_TARGETS = {
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
PINNED_ANCESTOR_SOURCES = {
    R3_PROTOCOL_REL: R3_PROTOCOL_SHA256,
    R3_BUILDER_REL: R3_BUILDER_SHA256,
    R3_CONTROLLER_REL: R3_CONTROLLER_SHA256,
    R3_ENTRYPOINT_REL: R3_ENTRYPOINT_SHA256,
    R3_SPEC_REL: R3_SPEC_SHA256,
    R2_PROTOCOL_REL: R2_PROTOCOL_SHA256,
    R2_BUILDER_REL: R2_BUILDER_SHA256,
    R2_CONTROLLER_REL: R2_CONTROLLER_SHA256,
    R2_ENTRYPOINT_REL: R2_ENTRYPOINT_SHA256,
    R2_SPEC_REL: R2_SPEC_SHA256,
    ORIGINAL_BUILDER_REL: ORIGINAL_BUILDER_SHA256,
    ORIGINAL_CONTROLLER_REL: ORIGINAL_CONTROLLER_SHA256,
    ORIGINAL_ENTRYPOINT_REL: ORIGINAL_ENTRYPOINT_SHA256,
    ORIGINAL_PROTOCOL_REL: ORIGINAL_PROTOCOL_SHA256,
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_historical_absence_helper() -> types.ModuleType:
    helper_path = verify_file(R4_ABSENCE_HELPER_REL, R4_ABSENCE_HELPER_SHA256)
    helper_bytes = helper_path.read_bytes()
    if sha256_bytes(helper_bytes) != R4_ABSENCE_HELPER_SHA256:
        raise ValueError("R4 historical absence helper changed during its pinned read")
    module = types.ModuleType("_up2_r4_historical_absence_builder")
    module.__file__ = str(helper_path)
    module.__package__ = None
    sys.modules[module.__name__] = module
    exec(compile(helper_bytes, str(helper_path), "exec", dont_inherit=True), module.__dict__)
    return module


def canonical_bytes(value: Any) -> bytes:
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
            sha256_bytes(manifest_bytes) != V6_SCOPEFIX_MANIFEST_SHA256:
        raise ValueError("R4 V6 scopefix addendum manifest differs from its exact size/SHA pin")
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    raw_lines = manifest_bytes.splitlines(keepends=True)
    if len(raw_lines) != 34:
        raise ValueError("R4 V6 scopefix addendum manifest must contain exactly 34 rows")
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
        rel = pathlib.PurePosixPath(logical)
        if "\\" in logical or rel.is_absolute() or rel.as_posix() != logical or \
                len(rel.parts) < 2 or rel.parts[0] not in ("docs", "test") or \
                any(part in ("", ".", "..") for part in rel.parts) or logical in seen:
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
            "manifest_row_sha256": sha256_bytes(line_bytes),
        })
    return rows


def build_v6_scopefix_closure_addendum(r3: dict[str, Any]) -> dict[str, Any]:
    """Build the five-file addendum from the exact V6 manifest and immutable ZIP."""
    review = r3.get("parent_v6_postrun_scopefix_review")
    parent_v6 = r3.get("parent_v6_protocol")
    contract = r3.get("archived_input_source")
    if not isinstance(review, dict) or not isinstance(parent_v6, dict) or not isinstance(contract, dict) or \
            review.get("manifest_path") != V6_SCOPEFIX_MANIFEST_REL or \
            review.get("manifest_sha256") != V6_SCOPEFIX_MANIFEST_SHA256 or \
            parent_v6.get("path") != V6_PROTOCOL_REL or parent_v6.get("sha256") != V6_PROTOCOL_SHA256 or \
            contract.get("archive_sha256") != ARCHIVE_SHA256 or \
            pathlib.Path(str(contract.get("archive_path", ""))).resolve() != ARCHIVE_PATH.resolve():
        raise ValueError("R4 V6 scopefix addendum is not bound to the pinned R3/V6/ZIP sources")

    rows = contract.get("entries")
    references = contract.get("referenced_paths")
    prefixes = contract.get("directory_prefixes")
    absent = contract.get("expected_absent", [])
    restored = contract.get("restored_entries", [])
    restored_directories = contract.get("restored_directories", [])
    if not all(isinstance(value, list) for value in
               (rows, references, prefixes, absent, restored, restored_directories)) or \
            (len(rows), len(references), len(prefixes)) != (613, 645, 31):
        raise ValueError("R4 V6 scopefix addendum requires the unchanged 613/645/31 base closure")
    base_tables = {
        "entries": [row.get("logical_path") for row in rows if isinstance(row, dict)],
        "referenced_paths": [row.get("logical_path") for row in references if isinstance(row, dict)],
        "directory_prefixes": [row.get("logical_path") for row in prefixes if isinstance(row, dict)],
        "expected_absent": [row.get("logical_path") for row in absent if isinstance(row, dict)],
        "restored_entries": [row.get("logical_path") for row in restored if isinstance(row, dict)],
        "restored_directories": [row.get("logical_path") for row in restored_directories if isinstance(row, dict)],
    }
    if any(len(base_tables[key]) != len(source) for key, source in (
            ("entries", rows), ("referenced_paths", references), ("directory_prefixes", prefixes),
            ("expected_absent", absent), ("restored_entries", restored),
            ("restored_directories", restored_directories))):
        raise ValueError("R4 V6 scopefix addendum base closure contains malformed path rows")
    exact_base = {str(path) for paths in base_tables.values() for path in paths}
    casefold_base = {path.casefold() for path in exact_base}
    prefix_paths = set(base_tables["directory_prefixes"])
    target_casefolds: set[str] = set()
    for logical in V6_SCOPEFIX_TARGETS:
        rel = pathlib.PurePosixPath(logical)
        if "\\" in logical or rel.is_absolute() or rel.as_posix() != logical or rel.parts[:1] != ("docs",) or \
                any(part in ("", ".", "..") for part in rel.parts):
            raise ValueError(f"R4 V6 scopefix addendum target is not canonical: {logical}")
        folded = logical.casefold()
        overlaps_base = any(folded == base or folded.startswith(base + "/") or base.startswith(folded + "/")
                            for base in casefold_base)
        if folded in target_casefolds or overlaps_base:
            raise ValueError(f"R4 V6 scopefix addendum target overlaps an existing path: {logical}")
        target_casefolds.add(folded)
        if any(folded == str(prefix).rstrip("/").casefold() or
               folded.startswith(str(prefix).rstrip("/").casefold() + "/") or
               str(prefix).rstrip("/").casefold().startswith(folded + "/") for prefix in prefix_paths):
            raise ValueError(f"R4 V6 scopefix addendum target overlaps a directory prefix: {logical}")
        workspace_target = path_for(logical)
        cursor = ROOT
        if cursor.is_symlink():
            raise ValueError(f"R4 V6 scopefix addendum workspace root is a symlink: {logical}")
        for part in rel.parts:
            cursor = cursor / part
            if cursor.is_symlink():
                raise ValueError(f"R4 V6 scopefix addendum workspace path contains a symlink: {logical}")
        if workspace_target.exists():
            raise ValueError(f"R4 V6 scopefix addendum must not restore a workspace docs file: {logical}")

    with zipfile.ZipFile(ARCHIVE_PATH, "r") as archive:
        manifest_bytes = _read_unique_zip_member(archive, V6_SCOPEFIX_MANIFEST_REL)
        parsed = _parse_v6_scopefix_manifest(manifest_bytes)
        selected = [row for row in parsed if row["logical_path"] in V6_SCOPEFIX_TARGETS]
        if len(selected) != 5 or {row["logical_path"] for row in selected} != set(V6_SCOPEFIX_TARGETS):
            raise ValueError("R4 V6 scopefix addendum manifest does not contain the exact five target paths")
        for row in selected:
            expected_bytes, expected_sha = V6_SCOPEFIX_TARGETS[row["logical_path"]]
            if (row["bytes"], row["sha256"], row["archive_member"]) != \
                    (expected_bytes, expected_sha, row["logical_path"]):
                raise ValueError(f"R4 V6 scopefix addendum manifest row differs from its fixed pin: {row['logical_path']}")
            content = _read_unique_zip_member(archive, row["archive_member"])
            if len(content) != row["bytes"] or sha256_bytes(content) != row["sha256"]:
                raise ValueError(f"R4 V6 scopefix addendum ZIP bytes differ from manifest: {row['logical_path']}")

    return {
        "schema": R4_V6_SCOPEFIX_ADDENDUM_SCHEMA,
        "classification": "test_only_continuation",
        "runtime_grant": False,
        "numerical_credit": False,
        "physical_credit": False,
        "manifest": {
            "logical_path": V6_SCOPEFIX_MANIFEST_REL,
            "bytes": V6_SCOPEFIX_MANIFEST_BYTES,
            "sha256": V6_SCOPEFIX_MANIFEST_SHA256,
        },
        "archive": {"path": str(ARCHIVE_PATH.resolve()), "sha256": ARCHIVE_SHA256},
        "parent_r3_protocol": {"path": R3_PROTOCOL_REL, "sha256": R3_PROTOCOL_SHA256},
        "parent_v6_protocol": {"path": V6_PROTOCOL_REL, "sha256": V6_PROTOCOL_SHA256},
        "base_map": {
            "entries_count": len(rows),
            "entries_sha256": sha256_bytes(canonical_bytes(rows)),
            "referenced_paths_count": len(references),
            "referenced_paths_sha256": sha256_bytes(canonical_bytes(references)),
            "directory_prefixes_count": len(prefixes),
            "directory_prefixes_sha256": sha256_bytes(canonical_bytes(prefixes)),
        },
        "row_count": len(selected),
        "rows": selected,
    }


def path_for(relative: str) -> pathlib.Path:
    path = ROOT / pathlib.Path(*pathlib.PurePosixPath(relative).parts)
    if not path.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError(f"R4 source path escapes repository: {relative}")
    return path


def source_row(relative: str, expected_sha256: str | None = None) -> dict[str, Any]:
    path = path_for(relative)
    if not path.is_file():
        raise FileNotFoundError(f"R4 owned source is missing: {relative}")
    actual_sha = sha256_file(path)
    if expected_sha256 is not None and actual_sha != expected_sha256:
        raise ValueError(f"R4 owned source differs from its frozen pin: {relative}")
    return {"path": relative, "bytes": path.stat().st_size, "sha256": actual_sha}


def verify_file(relative: str, expected_sha256: str, expected_bytes: int | None = None) -> pathlib.Path:
    path = path_for(relative)
    if not path.is_file() or sha256_file(path) != expected_sha256 or \
            (expected_bytes is not None and path.stat().st_size != expected_bytes):
        raise ValueError(f"R4 frozen source/evidence differs: {relative}")
    return path


def verify_r3_execution_ancestry(r3: dict[str, Any]) -> dict[str, Any]:
    receipt_path = verify_file(R3_RECEIPT_REL, R3_RECEIPT_SHA256, R3_RECEIPT_BYTES)
    receipt = json.loads(receipt_path.read_bytes())
    verify_file(R3_FAILURE_STDERR_REL, R3_FAILURE_STDERR_SHA256, R3_FAILURE_STDERR_BYTES)
    static_receipt_path = verify_file(R3_STATIC_RECEIPT_REL, R3_STATIC_RECEIPT_SHA256, R3_STATIC_RECEIPT_BYTES)
    static_receipt = json.loads(static_receipt_path.read_bytes())
    static_stderr_path = verify_file(R3_STATIC_STDERR_REL, R3_STATIC_STDERR_SHA256, R3_STATIC_STDERR_BYTES)
    raw_manifest_path = verify_file(R3_RAW_MANIFEST_REL, R3_RAW_MANIFEST_SHA256, 2992)
    snapshot_dir = ROOT / pathlib.Path(*pathlib.PurePosixPath(R3_SOURCE_SNAPSHOT_REL).parts)
    snapshot_manifest_path = snapshot_dir / "source_snapshot_manifest.json"
    verify_file(
        R3_SOURCE_SNAPSHOT_REL + "/source_snapshot_manifest.json",
        R3_SOURCE_SNAPSHOT_MANIFEST_SHA256,
        2914,
    )
    snapshot_manifest = json.loads(snapshot_manifest_path.read_bytes())
    if snapshot_manifest.get("failure_leaf") != str(R3_FAILURE_LEAF.relative_to(ROOT)).replace("\\", "/") or \
            snapshot_manifest.get("schema") != "up2-r3-actual-wrapper-run-source-snapshot-v1" or \
            snapshot_manifest.get("original_external_exit_receipt_sha256") != R3_RECEIPT_SHA256 or \
            snapshot_manifest.get("original_raw_manifest_sha256") != R3_RAW_MANIFEST_SHA256 or \
            snapshot_manifest.get("raw_failure_outputs_untouched") is not True:
        raise ValueError("R3 actual-run source snapshot no longer binds the untouched failure evidence")
    expected_snapshot = {
        R3_PROTOCOL_REL: (R3_PROTOCOL_SHA256, 989227),
        R3_CONTROLLER_REL: (R3_CONTROLLER_SHA256, 27094),
        R3_BUILDER_REL: (R3_BUILDER_SHA256, 26187),
        R4_TEST_REL: (R3_TEST_SNAPSHOT_SHA256, R3_TEST_SNAPSHOT_BYTES),
    }
    snapshot_rows = snapshot_manifest.get("sources")
    if not isinstance(snapshot_rows, list) or len(snapshot_rows) != 4:
        raise ValueError("R3 actual-run snapshot no longer contains its exact four executed sources")
    source_paths: set[str] = set()
    for row in snapshot_rows:
        source_rel = row.get("source_path")
        snapshot_rel = row.get("snapshot_path")
        if source_rel not in expected_snapshot or source_rel in source_paths:
            raise ValueError("R3 actual-run source snapshot contains an unexpected/duplicate source")
        expected_sha, expected_bytes = expected_snapshot[source_rel]
        snapshot_path = verify_file(str(snapshot_rel), expected_sha, expected_bytes)
        if row.get("sha256") != expected_sha or row.get("bytes") != expected_bytes or \
                row.get("source_sha256_before") != expected_sha or row.get("source_sha256_after") != expected_sha:
            raise ValueError("R3 actual-run source snapshot row differs from its frozen bytes")
        if source_rel == R4_TEST_REL and snapshot_path.resolve() != (ROOT / pathlib.Path(*pathlib.PurePosixPath(R3_TEST_SNAPSHOT_REL).parts)).resolve():
            raise ValueError("R3 old test snapshot path differs from its frozen ancestry path")
        source_paths.add(source_rel)
    if source_paths != set(expected_snapshot):
        raise ValueError("R3 actual-run snapshot omits an executed source")
    if (receipt.get("schema"), receipt.get("protocol_sha256"), receipt.get("actual_child_os_exit_code"),
            receipt.get("source_pins_unchanged"), receipt.get("julia_exit_not_inferred"),
            receipt.get("physical_acceptance_credit")) != (
            "root-up2-v21-r3-actual-external-exit-r1", R3_PROTOCOL_SHA256, 1, True, True, False):
        raise ValueError("R3 failed-run receipt changed its observed no-credit outcome")
    if (static_receipt.get("schema"), static_receipt.get("actual_direct_python_os_exit_code"),
            static_receipt.get("protocol_sha256"), static_receipt.get("julia_started"),
            static_receipt.get("replay_runner_started"), static_receipt.get("numerical_credit")) != (
            "root-up2-r3-independent-suite-actual-exit-r3", 0, R3_PROTOCOL_SHA256, False, False, False):
        raise ValueError("R3 10-test static-suite receipt changed its no-credit outcome")
    static_stderr = static_stderr_path.read_text(encoding="utf-8")
    if receipt.get("stderr", {}).get("sha256") != R3_FAILURE_STDERR_SHA256 or \
            static_receipt.get("stderr_sha256") != R3_STATIC_STDERR_SHA256 or \
            "Ran 10 tests" not in static_stderr or "OK" not in static_stderr:
        raise ValueError("R3 wrapper/static raw stderr evidence differs from its receipts")
    if raw_manifest_path.stat().st_size != 2992 or R3_OUTPUT_LEAF.exists():
        raise ValueError("R3 failure raw manifest or preserved absent runtime leaf changed")
    for row in r3.get("owned_source_files", []):
        relative = row.get("path")
        if relative == R4_TEST_REL:
            # The R3 test is checked through its immutable execution snapshot above.
            if row.get("sha256") != R3_TEST_SNAPSHOT_SHA256 or row.get("bytes") != R3_TEST_SNAPSHOT_BYTES:
                raise ValueError("R3 protocol test pin differs from its exact executed source snapshot")
            continue
        verify_file(str(relative), str(row.get("sha256")), int(row.get("bytes")))
    return {
        "protocol_path": R3_PROTOCOL_REL,
        "protocol_bytes": R3_PROTOCOL_PATH.stat().st_size,
        "protocol_sha256": R3_PROTOCOL_SHA256,
        "actual_failure_receipt_path": R3_RECEIPT_REL,
        "actual_failure_receipt_bytes": R3_RECEIPT_BYTES,
        "actual_failure_receipt_sha256": R3_RECEIPT_SHA256,
        "actual_failure_stderr_path": R3_FAILURE_STDERR_REL,
        "actual_failure_stderr_bytes": R3_FAILURE_STDERR_BYTES,
        "actual_failure_stderr_sha256": R3_FAILURE_STDERR_SHA256,
        "static_suite_receipt_path": R3_STATIC_RECEIPT_REL,
        "static_suite_receipt_bytes": R3_STATIC_RECEIPT_BYTES,
        "static_suite_receipt_sha256": R3_STATIC_RECEIPT_SHA256,
        "static_suite_stderr_path": R3_STATIC_STDERR_REL,
        "static_suite_stderr_bytes": R3_STATIC_STDERR_BYTES,
        "static_suite_stderr_sha256": R3_STATIC_STDERR_SHA256,
        "static_suite_tests_passed": 10,
        "raw_manifest_path": R3_RAW_MANIFEST_REL,
        "raw_manifest_sha256": R3_RAW_MANIFEST_SHA256,
        "source_snapshot_manifest_path": R3_SOURCE_SNAPSHOT_REL + "/source_snapshot_manifest.json",
        "source_snapshot_manifest_sha256": R3_SOURCE_SNAPSHOT_MANIFEST_SHA256,
        "executed_test_snapshot_path": R3_TEST_SNAPSHOT_REL,
        "executed_test_snapshot_bytes": R3_TEST_SNAPSHOT_BYTES,
        "executed_test_snapshot_sha256": R3_TEST_SNAPSHOT_SHA256,
        "actual_child_os_exit_code": 1,
        "julia_started": False,
        "raw_failure_outputs_untouched": True,
    }


def verify_mirror(protocol: dict[str, Any], root: pathlib.Path, label: str) -> dict[str, Any]:
    contract = protocol.get("archived_input_source")
    if not isinstance(contract, dict) or contract.get("archive_sha256") != ARCHIVE_SHA256:
        raise ValueError(f"{label} protocol lacks the exact archived-input identity")
    staging = pathlib.Path(str(contract.get("staging_root", ""))).resolve()
    expected = root.resolve()
    rows = contract.get("entries")
    prefixes = contract.get("directory_prefixes")
    refs = contract.get("referenced_paths")
    if staging != expected or not staging.is_dir() or not isinstance(rows, list) or len(rows) != 613 or \
            not isinstance(prefixes, list) or len(prefixes) != 31 or not isinstance(refs, list) or len(refs) != 645:
        raise ValueError(f"{label} mirror identity/count/root differs")
    expected_rows: dict[str, tuple[int, str]] = {}
    for row in rows:
        logical = row.get("logical_path")
        if not isinstance(logical, str) or logical in expected_rows or row.get("archive_sha256") != ARCHIVE_SHA256:
            raise ValueError(f"{label} archive map has duplicate or malformed file identity")
        expected_rows[logical] = (int(row["bytes"]), str(row["sha256"]))
    actual: dict[str, tuple[int, str]] = {}
    for path in staging.rglob("*"):
        if path.is_symlink():
            raise ValueError(f"{label} mirror contains a symlink")
        if path.is_file():
            actual[path.relative_to(staging).as_posix()] = (path.stat().st_size, sha256_file(path))
    if actual != expected_rows or sum(size for size, _ in actual.values()) != 31564478:
        raise ValueError(f"{label} mirror differs from the exact 613-file closure")
    return {"root": str(staging), "file_count": len(actual), "bytes": sum(s for s, _ in actual.values()),
            "directory_prefix_count": len(prefixes), "referenced_path_count": len(refs)}


def apply_overlay(source: bytes, spec: dict[str, Any]) -> bytes:
    replacements: dict[str, str] = {}
    for row in spec.get("replacements", []):
        if not isinstance(row, dict) or not isinstance(row.get("old_line"), str) or \
                not isinstance(row.get("new_line"), str) or row["old_line"] in replacements:
            raise ValueError("R4 overlay contains a malformed or duplicate complete-line binding")
        replacements[row["old_line"]] = row["new_line"]
    if len(replacements) != 8 or spec.get("replacement_count") != 8:
        raise ValueError("R4 overlay must contain the eight exact R3 bindings plus inventory-order correction")
    source_text = source.decode("utf-8")
    v20_functions = [node for node in ast.parse(source_text).body
                     if isinstance(node, ast.FunctionDef) and node.name == "verify_v20_actual_failure"]
    if len(v20_functions) != 1 or v20_functions[0].end_lineno is None:
        raise ValueError("R4 overlay requires the unique top-level V20 failure validator")
    v20_function = v20_functions[0]
    order_line = "    if file_inventory(runtime_root) != runtime_entries:"
    counts = {line: 0 for line in replacements}
    transformed: list[str] = []
    for line_number, line in enumerate(source_text.splitlines(keepends=True), 1):
        body = line.rstrip("\r\n")
        if body == order_line and not v20_function.lineno <= line_number <= v20_function.end_lineno:
            transformed.append(line)
            continue
        if body in replacements:
            counts[body] += 1
            transformed.append(replacements[body] + line[len(body):])
        else:
            transformed.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R4 overlay exact-line cardinality changed: {counts}")
    return "".join(transformed).encode("utf-8")


def verify_sources(r3: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    spec_path = path_for(R4_SPEC_REL)
    spec = json.loads(spec_path.read_bytes())
    r3_spec = json.loads(verify_file(R3_SPEC_REL, R3_SPEC_SHA256, 1916).read_bytes())
    version_name_bindings = (
        ("replay_staged_v21_r3.jl", "replay_staged_v21_r4.jl"),
        ("replay_protocol_v21_r3.json", "replay_protocol_v21_r4.json"),
        ("up2_replay_v21_r3", "up2_replay_v21_r4_scopefix_addendum_r1"),
        ("V21 R3 output_leaf", "V21 R4 output_leaf"),
        ("R3_TRANSFORMED_CONTROLLER_SOURCE", "R4_TRANSFORMED_CONTROLLER_SOURCE"),
    )
    expected_successor_replacements = []
    for parent_row in r3_spec.get("replacements", []):
        successor_row = dict(parent_row)
        for parent_name, successor_name in version_name_bindings:
            successor_row["new_line"] = successor_row["new_line"].replace(parent_name, successor_name)
        expected_successor_replacements.append(successor_row)
    if spec.get("schema") != "mms-v21-r4-controller-overlay-spec-v1" or \
            spec.get("original_controller_path") != ORIGINAL_CONTROLLER_REL or \
            spec.get("original_controller_sha256") != ORIGINAL_CONTROLLER_SHA256 or \
            spec.get("replacement_count") != 8 or len(spec.get("replacements", [])) != 8 or \
            spec.get("replacements", [])[:7] != expected_successor_replacements:
        raise ValueError("R4 overlay is not the exact R3 overlay plus its one approved inventory comparison")
    order_repair = spec["replacements"][7]
    if order_repair != {
            "old_line": "    if file_inventory(runtime_root) != runtime_entries:",
            "new_line": '    if sorted(file_inventory(runtime_root), key=lambda item: item["path"]) != sorted(runtime_entries, key=lambda item: item["path"]):'}:
        raise ValueError("R4 overlay differs from the one approved logical-path ordering correction")
    original = verify_file(ORIGINAL_CONTROLLER_REL, ORIGINAL_CONTROLLER_SHA256).read_bytes()
    transformed = apply_overlay(original, spec)
    r3_entry = verify_file(R3_ENTRYPOINT_REL, R3_ENTRYPOINT_SHA256, 62447).read_bytes()
    old = b'replay_protocol_v21_r3.json'
    new = b'replay_protocol_v21_r4.json'
    if r3_entry.count(old) != 1 or path_for(R4_ENTRYPOINT_REL).read_bytes() != r3_entry.replace(old, new, 1):
        raise ValueError("R4 Julia entrypoint is not the exact one-literal R3 successor")
    if sha256_file(spec_path) != R4_SPEC_SHA256:
        raise ValueError("R4 overlay spec hash differs from its frozen wrapper pin")

    source_rels = [
        R4_BUILDER_REL, R4_CONTROLLER_REL, R4_ENTRYPOINT_REL, R4_SPEC_REL, R4_TEST_REL,
        R4_ABSENCE_HELPER_REL,
        R3_PROTOCOL_REL, R3_BUILDER_REL, R3_CONTROLLER_REL, R3_ENTRYPOINT_REL, R3_SPEC_REL,
        R2_PROTOCOL_REL, R2_BUILDER_REL, R2_CONTROLLER_REL, R2_ENTRYPOINT_REL, R2_SPEC_REL,
        ORIGINAL_BUILDER_REL, ORIGINAL_CONTROLLER_REL, ORIGINAL_ENTRYPOINT_REL, ORIGINAL_PROTOCOL_REL,
    ]
    if len(source_rels) != 20 or len(set(source_rels)) != 20:
        raise ValueError("R4 transitive source inventory must contain 20 unique rows")
    source_rows = [source_row(
        relative,
        R4_TEST_SHA256 if relative == R4_TEST_REL else (
            R4_ABSENCE_HELPER_SHA256 if relative == R4_ABSENCE_HELPER_REL
            else PINNED_ANCESTOR_SOURCES.get(relative)),
    ) for relative in sorted(source_rels)]
    source_pins = {row["path"]: row["sha256"] for row in source_rows}
    if source_pins[R4_TEST_REL] != R4_TEST_SHA256:
        raise ValueError("R4 independent test differs from its one-way builder pin")
    diff = "".join(difflib.unified_diff(
        original.decode("utf-8").splitlines(keepends=True), transformed.decode("utf-8").splitlines(keepends=True),
        fromfile="run_replay_staged_v21.py (frozen source)",
        tofile="run_replay_staged_v21_r4.py (eight exact overlays)",
    ))
    overlay = {
        "schema": "mms-v21-r4-controller-overlay-evidence-v1",
        "original_controller_path": ORIGINAL_CONTROLLER_REL,
        "original_controller_sha256_before": sha256_bytes(original),
        "original_controller_sha256_after": sha256_file(path_for(ORIGINAL_CONTROLLER_REL)),
        "transformed_source_sha256": sha256_bytes(transformed),
        "overlay_spec_path": R4_SPEC_REL,
        "overlay_spec_sha256": R4_SPEC_SHA256,
        "replacement_count": 8,
        "path_binding_replacement_count": 6,
        "guard_consumption_binding_correction": {
            "original_call": spec["replacements"][6]["old_line"],
            "corrected_call": spec["replacements"][6]["new_line"],
            "source_variable": "R4_TRANSFORMED_CONTROLLER_SOURCE",
            "source_value": "exact UTF-8 decoded transformed controller bytes compiled and executed by the R4 wrapper",
        },
        "inventory_order_repair": {
            "original_call": order_repair["old_line"],
            "corrected_call": order_repair["new_line"],
            "sort_key": "POSIX logical row path string",
            "comparison": "complete list equality after sorting both inventories; bytes, hashes, duplicates, missing, and extra rows remain checked",
        },
        "replacements": copy.deepcopy(spec["replacements"]),
        "unified_diff": diff,
        "unified_diff_sha256": sha256_bytes(diff.encode("utf-8")),
        "scope": "R3's seven exact bindings are inherited; one additional exact complete-line correction orders both V20 inventories by logical POSIX path before unchanged full-row equality.",
    }
    return source_rows, overlay


def _read_unique_v10_zip_member(archive: zipfile.ZipFile, member: str) -> bytes:
    folded = member.casefold()
    exact = [info for info in archive.infolist() if info.filename == member]
    aliases = [info for info in archive.infolist() if info.filename.casefold() == folded]
    if len(exact) != 1 or len(aliases) != 1 or exact[0].is_dir():
        raise ValueError(f"R4 V10 input ZIP member is missing, aliased, duplicated, or not a file: {member}")
    with archive.open(exact[0], "r") as stream:
        return stream.read()


def _v10_root_observation_rows(review_manifest: dict[str, Any],
                               observation: dict[str, Any]) -> list[dict[str, Any]]:
    root_observation = review_manifest.get("root_observation")
    grant = observation.get("grant")
    sidecars = observation.get("controller_sidecars")
    if not isinstance(root_observation, dict) or not isinstance(grant, dict) or not isinstance(sidecars, dict):
        raise ValueError("R4 V10 source documents lack the pinned declarations")
    sidecar_names = ("controller.exit.txt", "controller.stderr.raw", "controller.stdout.raw")
    if set(root_observation) != {"path", "sha256"} or \
            set(grant) != {"relative_path", "bytes", "sha256"} or \
            set(sidecars) != set(sidecar_names) or any(
                not isinstance(sidecars[name], dict) or
                set(sidecars[name]) != {"relative_path", "bytes", "sha256"}
                for name in sidecar_names
            ):
        raise ValueError("R4 V10 source declarations have an unexpected field shape")
    observation_sha = "864b2fc5eacfcb8a44114fa5023f3125c9ff2fb08dce3b44b970dfe85eb0d5f9"
    declarations = [
        (V10_ROOT_OBSERVATION_PATH, 8230, observation_sha, V10_REVIEW_MANIFEST_REL,
         V10_REVIEW_MANIFEST_BYTES, V10_REVIEW_MANIFEST_SHA256, "/root_observation",
         root_observation.get("path"), None, root_observation.get("sha256")),
        (list(V10_ROOT_OBSERVATION_TARGETS)[1], 3065,
         "ac07074745769abee598904e2c87f1ac62fbb649ff1b54787cee898f7aa3a5b6",
         V10_ROOT_OBSERVATION_PATH, 8230, observation_sha, "/grant",
         grant.get("relative_path"), grant.get("bytes"), grant.get("sha256")),
        (list(V10_ROOT_OBSERVATION_TARGETS)[2], 2,
         "8722616204217eddb39e7df969e0698aed8e599ba62ed2de1ce49b03ade0fede",
         V10_ROOT_OBSERVATION_PATH, 8230, observation_sha, "/controller_sidecars/controller.exit.txt",
         (sidecars.get("controller.exit.txt") or {}).get("relative_path"),
         (sidecars.get("controller.exit.txt") or {}).get("bytes"),
         (sidecars.get("controller.exit.txt") or {}).get("sha256")),
        (list(V10_ROOT_OBSERVATION_TARGETS)[3], 0,
         "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
         V10_ROOT_OBSERVATION_PATH, 8230, observation_sha, "/controller_sidecars/controller.stderr.raw",
         (sidecars.get("controller.stderr.raw") or {}).get("relative_path"),
         (sidecars.get("controller.stderr.raw") or {}).get("bytes"),
         (sidecars.get("controller.stderr.raw") or {}).get("sha256")),
        (list(V10_ROOT_OBSERVATION_TARGETS)[4], 320,
         "4029ec84fb491bdcd440d88c1e7e6894fdbc2e1ae6adca30b130d404c568cadc",
         V10_ROOT_OBSERVATION_PATH, 8230, observation_sha, "/controller_sidecars/controller.stdout.raw",
         (sidecars.get("controller.stdout.raw") or {}).get("relative_path"),
         (sidecars.get("controller.stdout.raw") or {}).get("bytes"),
         (sidecars.get("controller.stdout.raw") or {}).get("sha256")),
    ]
    rows: list[dict[str, Any]] = []
    for logical, size, digest, source_path, source_size, source_digest, pointer, declared_path, declared_size, declared_sha in declarations:
        expected_declared_size = None if pointer == "/root_observation" else size
        size_matches = declared_size is None if pointer == "/root_observation" else (
            type(declared_size) is int and declared_size == expected_declared_size
        )
        if declared_path != logical or not size_matches or declared_sha != digest:
            raise ValueError(f"R4 V10 source declaration differs from its exact fixed pin: {logical}")
        rows.append({
            "logical_path": logical,
            "archive_member": logical,
            "bytes": size,
            "sha256": digest,
            "source_document_path": source_path,
            "source_document_bytes": source_size,
            "source_document_sha256": source_digest,
            "source_json_pointer": pointer,
        })
    return rows


def _v10_logical_paths(value: Any) -> list[str]:
    paths: list[str] = []
    if isinstance(value, dict):
        if isinstance(value.get("logical_path"), str):
            paths.append(value["logical_path"])
        for child in value.values():
            paths.extend(_v10_logical_paths(child))
    elif isinstance(value, (list, tuple)):
        for child in value:
            paths.extend(_v10_logical_paths(child))
    return paths


def build_v10_root_observation_input_addendum(protocol: dict[str, Any]) -> dict[str, Any]:
    contract = protocol.get("archived_input_source")
    parent = protocol.get("parent_v10_independent_postrun_review")
    if not isinstance(contract, dict) or not isinstance(parent, dict) or \
            parent.get("manifest_path") != V10_REVIEW_MANIFEST_REL or \
            parent.get("manifest_sha256") != V10_REVIEW_MANIFEST_SHA256:
        raise ValueError("R4 V10 source addendum is not bound to the pinned parent review manifest")
    entries = contract.get("entries")
    references = contract.get("referenced_paths")
    prefixes = contract.get("directory_prefixes")
    absent = contract.get("expected_absent", [])
    restored = contract.get("restored_entries", [])
    restored_directories = contract.get("restored_directories", [])
    if not all(isinstance(value, list) for value in
               (entries, references, prefixes, absent, restored, restored_directories)) or \
            (len(entries), len(references), len(prefixes)) != (613, 645, 31):
        raise ValueError("R4 V10 source addendum requires unchanged 613/645/31 base closure")
    base_map = {
        "entries_count": len(entries),
        "entries_sha256": sha256_bytes(canonical_bytes(entries)),
        "referenced_paths_count": len(references),
        "referenced_paths_sha256": sha256_bytes(canonical_bytes(references)),
        "directory_prefixes_count": len(prefixes),
        "directory_prefixes_sha256": sha256_bytes(canonical_bytes(prefixes)),
    }
    manifest_rows = [row for row in entries if isinstance(row, dict) and
                     row.get("logical_path") == V10_REVIEW_MANIFEST_REL]
    if len(manifest_rows) != 1 or (manifest_rows[0].get("bytes"), manifest_rows[0].get("sha256")) != \
            (V10_REVIEW_MANIFEST_BYTES, V10_REVIEW_MANIFEST_SHA256):
        raise ValueError("R4 V10 parent review manifest differs from its exact base-map row")
    targets = list(V10_ROOT_OBSERVATION_TARGETS)
    base_paths = {str(path) for table in (entries, references, prefixes, absent, restored, restored_directories)
                  for path in _v10_logical_paths(table)}
    base_paths.update(_v10_logical_paths(protocol.get("r4_historical_absent_output_slots")))
    base_paths.update(_v10_logical_paths(protocol.get(R4_V9_STATIC_RAW_SIDECAR_KEY)))
    base_paths.update(_v10_logical_paths(protocol.get(R4_V6_SCOPEFIX_ADDENDUM_KEY)))
    base_casefold = {path.casefold() for path in base_paths}
    target_casefold: set[str] = set()
    for logical in targets:
        rel = pathlib.PurePosixPath(logical)
        if "\\" in logical or rel.is_absolute() or rel.as_posix() != logical or rel.parts[:1] != ("docs",) or \
                any(part in ("", ".", "..") for part in rel.parts):
            raise ValueError(f"R4 V10 target is not a canonical docs path: {logical}")
        folded = logical.casefold()
        if folded in target_casefold or any(
                folded == base or folded.startswith(base + "/") or base.startswith(folded + "/")
                for base in base_casefold):
            raise ValueError(f"R4 V10 target overlaps or aliases an existing source route: {logical}")
        target_casefold.add(folded)
        if any(folded == str(row.get("logical_path", "")).rstrip("/").casefold() or
               folded.startswith(str(row.get("logical_path", "")).rstrip("/").casefold() + "/") or
               str(row.get("logical_path", "")).rstrip("/").casefold().startswith(folded + "/")
               for row in prefixes if isinstance(row, dict)):
            raise ValueError(f"R4 V10 target overlaps an existing directory prefix: {logical}")
        cursor = ROOT
        for part in rel.parts:
            cursor = cursor / part
            if cursor.is_symlink():
                raise ValueError(f"R4 V10 target workspace path contains a symlink: {logical}")
        if (ROOT / pathlib.Path(*rel.parts)).exists():
            raise ValueError(f"R4 V10 target must remain absent in workspace: {logical}")
    archive_path = pathlib.Path(str(contract.get("archive_path", ""))).resolve()
    if archive_path != ARCHIVE_PATH.resolve() or contract.get("archive_sha256") != ARCHIVE_SHA256:
        raise ValueError("R4 V10 source addendum archive path/SHA differs from the frozen ZIP")
    with zipfile.ZipFile(archive_path, "r") as archive:
        manifest_bytes = _read_unique_v10_zip_member(archive, V10_REVIEW_MANIFEST_REL)
        if len(manifest_bytes) != V10_REVIEW_MANIFEST_BYTES or sha256_bytes(manifest_bytes) != V10_REVIEW_MANIFEST_SHA256:
            raise ValueError("R4 V10 parent review manifest ZIP bytes differ from the exact pin")
        review_manifest = json.loads(manifest_bytes)
        observation_bytes = _read_unique_v10_zip_member(archive, V10_ROOT_OBSERVATION_PATH)
        if len(observation_bytes) != V10_ROOT_OBSERVATION_BYTES or \
                sha256_bytes(observation_bytes) != V10_ROOT_OBSERVATION_SHA256:
            raise ValueError("R4 V10 root observation ZIP bytes differ from the exact pin")
        observation = json.loads(observation_bytes)
        if observation.get("schema") != "root_mms_v10_actual_observation_v1":
            raise ValueError("R4 V10 root observation source schema changed")
        selected = _v10_root_observation_rows(review_manifest, observation)
        for row in selected:
            payload = _read_unique_v10_zip_member(archive, row["archive_member"])
            if len(payload) != row["bytes"] or sha256_bytes(payload) != row["sha256"]:
                raise ValueError(f"R4 V10 archive bytes differ from the bound source row: {row['logical_path']}")
    return {
        "schema": R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA,
        "classification": "test_only_continuation",
        "runtime_grant": False,
        "numerical_credit": False,
        "physical_credit": False,
        "archive": {"path": str(ARCHIVE_PATH.resolve()), "sha256": ARCHIVE_SHA256},
        "parent_review_manifest": {
            "logical_path": V10_REVIEW_MANIFEST_REL,
            "bytes": V10_REVIEW_MANIFEST_BYTES,
            "sha256": V10_REVIEW_MANIFEST_SHA256,
        },
        "root_observation": {
            "logical_path": V10_ROOT_OBSERVATION_PATH,
            "bytes": V10_ROOT_OBSERVATION_BYTES,
            "sha256": V10_ROOT_OBSERVATION_SHA256,
        },
        "base_map": base_map,
        "row_count": 5,
        "rows": selected,
    }


def build_v10_recorded_path_binding_addendum(overlay: dict[str, Any]) -> dict[str, Any]:
    original = verify_file(ORIGINAL_CONTROLLER_REL, ORIGINAL_CONTROLLER_SHA256).read_bytes()
    spec = json.loads(path_for(R4_SPEC_REL).read_bytes())
    base = apply_overlay(original, spec)
    base_sha = sha256_bytes(base)
    if base_sha != overlay.get("transformed_source_sha256"):
        raise ValueError("R4 V10 path addendum base differs from the preserved eight-overlay source")
    replacements = {row["old_line"]: row["new_line"] for row in R4_V10_PATH_BINDING_REPLACEMENTS}
    transformed: list[str] = []
    counts = {old: 0 for old in replacements}
    for line in base.decode("utf-8").splitlines(keepends=True):
        body = line[:-1] if line.endswith("\n") else line
        if body.endswith("\r"):
            body = body[:-1]
        if body in replacements:
            counts[body] += 1
            transformed.append(replacements[body] + line[len(body):])
        else:
            transformed.append(line)
    if any(count != 1 for count in counts.values()):
        raise ValueError(f"R4 V10 path addendum exact-line cardinality changed: {counts}")
    output = "".join(transformed).encode("utf-8")
    return {
        "schema": R4_V10_PATH_BINDING_SCHEMA,
        "base_transformed_source_sha256": base_sha,
        "replacement_count": 2,
        "replacements": copy.deepcopy(R4_V10_PATH_BINDING_REPLACEMENTS),
        "transformed_source_sha256": sha256_bytes(output),
    }


def build_protocol() -> tuple[dict[str, Any], dict[str, Any]]:
    if not R3_PROTOCOL_PATH.is_file() or sha256_file(R3_PROTOCOL_PATH) != R3_PROTOCOL_SHA256:
        raise ValueError("R3 parent protocol differs from its exact executed-run SHA")
    r3_wire = R3_PROTOCOL_PATH.read_bytes()
    r3 = json.loads(r3_wire)
    if (r3.get("schema"), r3.get("version"), r3.get("classification"), r3.get("runtime_grant")) != (
            "mms-replay-only-continuation-protocol-v21", 21, "test_only_continuation", False):
        raise ValueError("R3 ancestry status or no-credit boundary changed")
    if not ARCHIVE_PATH.is_file() or sha256_file(ARCHIVE_PATH) != ARCHIVE_SHA256:
        raise ValueError("pinned cleanup archive is missing or differs")
    r3_snapshot = verify_r3_execution_ancestry(r3)
    r2_protocol = json.loads(verify_file(R2_PROTOCOL_REL, R2_PROTOCOL_SHA256, 973773).read_bytes())
    r2_mirror = verify_mirror(r2_protocol, R2_OUTPUT_ROOT / "archive_mirror", "R2")
    r3_mirror = verify_mirror(r3, R3_STAGING_ROOT, "R3")
    if R3_OUTPUT_LEAF.exists():
        raise FileExistsError("preserve the actual R3 failed-run leaf state")
    if R4_OUTPUT_ROOT.exists() or R4_STAGING_ROOT.exists() or R4_OUTPUT_LEAF.exists():
        raise FileExistsError("R4 requires a new external output, archive mirror, and runtime leaf all absent")
    source_rows, overlay = verify_sources(r3)
    v10_path_binding_addendum = build_v10_recorded_path_binding_addendum(overlay)

    r4 = copy.deepcopy(r3)
    coverage = r4.get("coverage_contract")
    if not isinstance(coverage, dict) or coverage.get("process_tree_resource_monitor_negative_controls") != \
            r3.get("coverage_contract", {}).get("process_tree_resource_monitor_negative_controls") or \
            len(coverage.get("process_tree_resource_monitor_negative_controls", [])) != 14:
        raise ValueError("R3 exact 14-item process-tree monitor negative list changed")
    coverage["child_argv"]["entrypoint"] = R4_ENTRYPOINT_REL
    coverage["output_leaf"] = str(R4_OUTPUT_LEAF.resolve())

    r4["controller"] = R4_CONTROLLER_REL
    r4["entrypoint"] = R4_ENTRYPOINT_REL
    r4["output_leaf"] = str(R4_OUTPUT_LEAF.resolve())
    r4[R4_V6_SCOPEFIX_ADDENDUM_KEY] = build_v6_scopefix_closure_addendum(r3)
    r4["archived_input_source"]["staging_root"] = str(R4_STAGING_ROOT.resolve())
    r4["archived_input_source"]["closure_scope"] = (
        "The exact R3 613-file V10-complete archive map is unchanged; exact-three V9 raw sidecars, exact-five V6 scopefix "
        "rows, and exact-five V10 root-observation inputs are separately source-bound addenda materialized only in the "
        "new R4 mirror and are not added to the 613 rows. "
        "The R2 and R3 mirrors and the R3 failed-run leaf are preserved byte-for-byte."
    )
    r4["context_builder_contract"]["entrypoint_path"] = R4_ENTRYPOINT_REL
    r4["context_builder_contract"]["entrypoint_sha256"] = next(
        row["sha256"] for row in source_rows if row["path"] == R4_ENTRYPOINT_REL)
    for mode in ("producer", "consumer"):
        command = r4["child_command_contract"][mode]
        hits = [index for index, value in enumerate(command) if value == R3_ENTRYPOINT_REL]
        if len(hits) != 1:
            raise ValueError(f"R3 {mode} command does not contain one exact entrypoint binding")
        command[hits[0]] = R4_ENTRYPOINT_REL
    producer_command = r4["child_command_contract"]["producer"]
    logical_source = pathlib.PurePosixPath(str(r4["saved_producer_tree"]["root"]))
    if logical_source.is_absolute() or logical_source.as_posix() != r4["saved_producer_tree"]["root"] or \
            logical_source.parts[:1] != ("docs",) or any(part in ("", ".", "..") for part in logical_source.parts) or \
            len(producer_command) != 10:
        raise ValueError("R3 producer command source-root binding is malformed")
    logical_source_path = pathlib.Path(*logical_source.parts)
    expected_r3_source = str((R3_STAGING_ROOT / logical_source_path).resolve())
    expected_r4_source = str((R4_STAGING_ROOT / logical_source_path).resolve())
    if producer_command[6] != expected_r3_source:
        raise ValueError("R3 producer source root differs from its exact saved logical root")
    producer_command[6] = expected_r4_source

    r4["controller_command_template"] = (
        f"{r4['runtime']['python_executable']} -B {R4_CONTROLLER_REL} --protocol "
        f"test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r4.json "
        f"--protocol-sha256 <protocol-sha256> --output {R4_OUTPUT_LEAF.resolve()} --root-serial-slot-granted"
    )
    r4["r4_controller_overlay"] = overlay
    r4[R4_V10_PATH_BINDING_KEY] = v10_path_binding_addendum
    r4["r4_inventory_order_repair"] = {
        "schema": "mms-v21-r4-v20-inventory-logical-order-repair-v1",
        "function": "verify_v20_actual_failure",
        "only_changed_condition": "file_inventory(runtime_root) != runtime_entries",
        "comparison": "sorted(actual, key=logical POSIX path) == sorted(frozen, key=logical POSIX path)",
        "preserved_checks": ["row paths", "bytes", "SHA-256", "entry count", "duplicate rejection", "missing rows", "extra rows"],
        "historical_v20_entries_changed": False,
        "file_inventory_global_order_changed": False,
        "r2_r3_r4_runtime_resource_or_numerical_limits_changed": False,
        "runtime_grant": False,
    }
    r4["parent_r3_protocol"] = {
        "path": R3_PROTOCOL_REL,
        "bytes": len(r3_wire),
        "sha256": R3_PROTOCOL_SHA256,
        "actual_run_ancestry": r3_snapshot,
        "mirror_preservation": r3_mirror,
        "prior_r2_mirror_preservation": r2_mirror,
        "R3_run_no_credit": True,
    }
    r4["r4_output_ownership"] = {
        "schema": "mms-v21-r4-external-raw-root-ownership-v1",
        "owner": "UP2ClosureReplayOnlyV21 R4 logical inventory ordering repair",
        "raw_external_root": str(R4_OUTPUT_ROOT.resolve()),
        "archive_mirror_root": str(R4_STAGING_ROOT.resolve()),
        "runtime_output_leaf": str(R4_OUTPUT_LEAF.resolve()),
        "outside_repository_docs": True,
        "mirror_contents": "The exact unchanged 613-row map plus separately proved exact-three V9 raw sidecars, exact-five V6 scopefix rows, and exact-five V10 root-observation inputs; no other paths are materialized. R2 and R3 mirrors remain preserved.",
        "builder_creates_mirror_or_output": False,
        "pre_mirror_gate_requires_all_r4_roots_absent": True,
        "r2_r3_roots_are_read_only_preserved": True,
    }
    r4["r4_pre_output_order_contract"] = {
        "schema": "mms-v21-r4-pre-output-logical-inventory-order-v1",
        "original_runtime_rows": 21,
        "original_runtime_bytes": 3365672,
        "same_path_byte_hash_differences": 0,
        "failure_cause": "Windows Path component ordering differed from the archived logical POSIX string order only.",
        "comparison_key": "row['path'] logical POSIX string",
        "full_row_equality_after_sort": True,
        "duplicate_missing_extra_and_content_drift_still_fail": True,
        "no_resource_or_numerical_threshold_change": True,
    }
    r4["owned_source_files"] = source_rows
    r4["owned_source_files_by_path"] = {row["path"]: row["sha256"] for row in source_rows}
    helper = load_historical_absence_helper()
    r4["r4_historical_absent_output_slots"] = (
        helper.build_historical_absent_output_slots_v21_r4(
            ROOT, R3_PROTOCOL_PATH, R3_STAGING_ROOT).as_receipt())
    r4[R4_V9_STATIC_RAW_SIDECAR_KEY] = helper.build_v9_static_raw_output_sidecar_v21_r4(
        ROOT, R3_PROTOCOL_PATH, R3_STAGING_ROOT).as_receipt()
    if r4[R4_V9_STATIC_RAW_SIDECAR_KEY].get("schema") != R4_V9_STATIC_RAW_SIDECAR_SCHEMA:
        raise ValueError("R4 V9 static raw sidecar proof has an unsupported schema")
    r4[R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY] = build_v10_root_observation_input_addendum(r4)
    r4["r4_checked_path_absence_route"] = {
        "schema": "mms-v21-r4-historical-absent-output-route-v1",
        "helper_path": R4_ABSENCE_HELPER_REL,
        "helper_sha256": R4_ABSENCE_HELPER_SHA256,
        "fixed_slot_count": 4,
        "consumer": "original checked_path followed by the original real Path.exists assertion",
        "all_other_paths_use_original_checked_path": True,
        "materializes_archive_or_output_paths": False,
        "overrides_path_exists_or_is_file": False,
        "changes_v16_expected_absent_semantics": False,
        "changes_original_eight_source_overlays": False,
        "runtime_grant": False,
    }
    r4[R4_V9_STATIC_RAW_ROUTE_KEY] = {
        "schema": R4_V9_STATIC_RAW_ROUTE_SCHEMA,
        "helper_path": R4_ABSENCE_HELPER_REL,
        "helper_sha256": R4_ABSENCE_HELPER_SHA256,
        "proof_key": R4_V9_STATIC_RAW_SIDECAR_KEY,
        "proof_schema": R4_V9_STATIC_RAW_SIDECAR_SCHEMA,
        "logical_paths": list(R4_V9_STATIC_RAW_PATHS),
        "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                       "original_checked_path"],
        "nonmatching_paths": "existing_four_absence_route_then_original_checked_path",
        "changes_613_file_map": False,
        "changes_645_reference_set": False,
        "changes_31_directory_prefixes": False,
        "changes_four_absence_proofs": False,
        "changes_original_eight_source_overlays": False,
        "changes_runtime_grant": False,
        "runtime_grant": False,
    }
    r4["r4_created_utc"] = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    r4["r4_checked_path_absolute_archive_file_route"] = {
        "schema": "mms-v21-r4-exact-absolute-archive-file-route-v1",
        "repository_root": str(ROOT),
        "mapped_file_count": 613,
        "mapped_rows_sha256": sha256_bytes(canonical_bytes(r4["archived_input_source"]["entries"])),
        "mapping_rule": "exact root plus canonical logical file path; separator normalization only",
        "consumer": "original checked_path and original ArchivedInputResolver size/SHA checks",
        "changes_613_file_map": False,
        "changes_v15_evidence": False,
        "changes_four_absence_or_three_sidecar_routes": False,
        "runtime_grant": False,
    }
    addendum_rows = r4[R4_V6_SCOPEFIX_ADDENDUM_KEY]["rows"]
    r4[R4_V6_SCOPEFIX_ROUTE_KEY] = {
        "schema": R4_V6_SCOPEFIX_ROUTE_SCHEMA,
        "proof_key": R4_V6_SCOPEFIX_ADDENDUM_KEY,
        "proof_schema": R4_V6_SCOPEFIX_ADDENDUM_SCHEMA,
        "logical_paths": [row["logical_path"] for row in addendum_rows],
        "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                       "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
                       "exact_five_v10_root_observation_addendum", "original_checked_path"],
        "nonmatching_paths": "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path",
        "exact_relative_paths_only": True,
        "absolute_addendum_aliases": False,
        "materialization_root": str(R4_STAGING_ROOT.resolve()),
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
    r4[R4_V10_ROOT_OBSERVATION_ROUTE_KEY] = {
        "schema": R4_V10_ROOT_OBSERVATION_ROUTE_SCHEMA,
        "proof_key": R4_V10_ROOT_OBSERVATION_ADDENDUM_KEY,
        "proof_schema": R4_V10_ROOT_OBSERVATION_ADDENDUM_SCHEMA,
        "logical_paths": list(V10_ROOT_OBSERVATION_TARGETS),
        "precedence": ["exact_three_v9_static_raw_sidecar", "four_historical_absent_output_slots",
                       "exact_613_absolute_archive_file_alias", "exact_five_v6_scopefix_addendum",
                       "exact_five_v10_root_observation_addendum", "original_checked_path"],
        "nonmatching_paths": "existing V9 sidecar, four absence, 613 exact aliases, V6 and V10 addenda, then original checked_path",
        "exact_relative_paths_only": True,
        "absolute_addendum_aliases": False,
        "materialization_root": str(R4_STAGING_ROOT.resolve()),
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
    r4["independent_static_review"] = {
        "scope": "R4 logical-path inventory ordering, four fixed source-bound absent output assertions, exact-three V9 raw sidecar, exact-five V6 scopefix and exact-five V10 root-observation source addenda, exact absolute aliases for the unchanged 613 archive files, exact R2/R3 ancestry preservation, and unchanged pre-output guards; pending independent result",
        "julia_started": False,
        "solver_started": False,
        "runtime_grant": False,
    }
    summary = {
        "protocol_path": str(R4_PROTOCOL_PATH),
        "parent_r3_protocol_sha256": R3_PROTOCOL_SHA256,
        "owned_source_count": len(source_rows),
        "r4_static_test_sha256": next(row["sha256"] for row in source_rows if row["path"] == R4_TEST_REL),
        "v6_scopefix_addendum_count": len(addendum_rows),
        "r3_mirror": r3_mirror,
        "r2_mirror": r2_mirror,
        "r3_actual_failure_receipt_sha256": R3_RECEIPT_SHA256,
        "r4_output_root_absent": not R4_OUTPUT_ROOT.exists(),
        "runtime_grant": r4["runtime_grant"],
    }
    return r4, summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="write only the fixed-name, versioned R4 protocol")
    args = parser.parse_args()
    protocol, summary = build_protocol()
    wire = canonical_bytes(protocol)
    summary["protocol_sha256"] = sha256_bytes(wire)
    summary["protocol_bytes"] = len(wire)
    if args.write:
        if R4_PROTOCOL_PATH.exists():
            raise FileExistsError("preserve any existing R4 protocol; this builder never replaces it")
        R4_PROTOCOL_PATH.write_bytes(wire)
        summary["written"] = True
    else:
        summary["written"] = False
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
