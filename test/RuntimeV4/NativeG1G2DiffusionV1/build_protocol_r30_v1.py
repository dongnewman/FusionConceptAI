"""Build the private R30 protocol from frozen R29 rows and ZIP evidence.

This builder never extracts archive members. It validates the inherited 214
input rows, their 167/47 source classes, the original parse manifest join, and
the R30 source closure before creating the single R30 protocol file.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath
from types import ModuleType
from typing import Any


ROOT = Path(__file__).resolve().parents[3]
REL_DIR = "test/RuntimeV4/NativeG1G2DiffusionV1"
REL_PROTOCOL = "runs/NativeG1G2DiffusionV1/managed_lifecycle_refreeze_root_20260928_r1/protocol.json"
REL_RUNNER = f"{REL_DIR}/run_native_g1g2_gridap_consumer_r30_v1.py"
REL_TEST = f"{REL_DIR}/test_native_g1g2_gridap_consumer_r30_v1_tests.py"
REL_VERIFIER = f"{REL_DIR}/verify_native_g1g2_gridap_consumer_r30_v1.py"
REL_PROVIDER = f"{REL_DIR}/pinned_zip_input_provider_r30_v1.py"
REL_PARSE_JULIA = f"{REL_DIR}/parse_manifest_r30_stdin_v1.jl"
REL_BUILDER = f"{REL_DIR}/build_protocol_r30_v1.py"
MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS = (
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
ADDITIONAL_JULIA_PARSE_SOURCE_PATHS = (
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
CURRENT_INPUT_REBINDING_PATHS = (
    "Project.toml",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py",
)
PARSE_SOURCE_REBINDING_PATHS = (
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
)
SOURCE_LINEAGE_PATHS = (
    "Project.toml",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl",
    "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
FOUNDATION_PREIMAGE_ROOT = (
    "runs/e/lifecycle_systemic_repair_20260927_r1/"
    "live_foundation_integration/preimages"
)
FOUNDATION_INTEGRATION_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
            "live_foundation_integration/integration_receipt.json",
    "bytes": 6850,
    "sha256": "1740d82f1899582c466ca993095528461108b2ffc7963417af17556c930a87b8",
}
R25_INTEGRATION_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
            "live_frozen_native_shared_source_r25_integration/receipt.json",
    "bytes": 2632,
    "sha256": "823724040c90bff8d5079b4e4134cad76d75e2af2f28d3a43aea407dc421d096",
}
R25_SOURCE_REVIEW = {
    "path": "runs/e/t2_independent_review_20260928_r1/"
            "frozen_native_shared_source_go_r25.json",
    "bytes": 3199,
    "sha256": "cd08a826077ff0ea8032938b04b4fed9c4cfbd24eca011142a8dbf0fcebd9e94",
}
NATIVE_STAGE_R7_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
            "live_native_git_stage_and_fixture_producer_r7_integration/receipt.json",
    "bytes": 1387,
    "sha256": "e22243bd11945c5a5d704045021f28302632a10786840fcfd0f1278ff77fa005",
}
NATIVE_STAGE_R32_REVIEW = {
    "path": "runs/e/t2_independent_review_20260928_r1/"
            "native_git_stage_only_source_review_go_r32.json",
    "bytes": 1773,
    "sha256": "2e65316141d4711a0e642b254734386649fdf4cb64cb82ba478c50113822ba5b",
}
PREFREEZE_R9_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
            "live_prefreeze_fixture_inputs_r9_integration/receipt.json",
    "bytes": 5314,
    "sha256": "1094e3afbf6c7d25c3e5e9d23c94f324ac395daeda474c553ff558f2f6d74392",
}
PREFREEZE_R9_SOURCE_REVIEW = {
    "path": "runs/e/t2_independent_review_20260928_r1/"
            "source_coverage_fixture_contract_go_r1.json",
    "bytes": 8153,
    "sha256": "b1af6a82e8e4979189a848a95a8f61fa7089d19b704c93c2bc27dec8cb8061fb",
}
CURRENT_NINE_PIN_REVIEW = {
    "path": "runs/e/t2_independent_review_20260928_r1/"
            "fixture_launcher_6aa7_full_nine_pin_source_go_r1.json",
    "bytes": 2902,
    "sha256": "b4f03364c8e76c2d6f97a9d86e4bafc8e7015c97b68c2a4df8d1d67ab791a0d2",
}
R25_CANDIDATE_ROOT = "runs/e/t2_frozen_source_authority_candidate_20260928_r1/postimage"
NATIVE_STAGE_CANDIDATE = (
    "runs/e/t2_frozen_native_git_stage_repair_20260928_r1/postimage/"
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"
)
NATIVE_STAGE_PRESERVED_POSTIMAGE = (
    "runs/e/t2_frozen_native_git_stage_repair_20260928_r1/preimage/"
    "NativeGitReadCompatibilityV1.01B5CC2A75647EBB3474EC17D66A5E9729D65EDC3B215D00EEE5337A6B3790BC.jl"
)
R25_NATIVE_BEFORE_SHA256 = "c50ed841e0ffef2f141aac9845d51f21a326db20512462493c636fdc8aecf56b"
R25_NATIVE_AFTER_SHA256 = "f0dc1fbd8b5d186ff300a015e263f573b7587c9771e9b9b71eb1e77cc0bb56e1"
NATIVE_STAGE_AFTER_SHA256 = "01b5cc2a75647ebb3474ec17d66a5e9729d65edc3b215d00eee5337a6b3790bc"
NATIVE_CURRENT_SHA256 = "989184fb17a0da95f3ec593c8d62b3567886a730cf472e287f1feda70b16f223"
SUPERVISOR_ORIGINAL_PIN = {
    "path": "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py",
    "bytes": 25343,
    "sha256": "ed38b5e1d9d7c506bd8db4c311948601fbb12be47ac68e2d3e4ac2e710342192",
}
SUPERVISOR_PRESERVED_ORIGINAL_PATH = (
    "runs/e/lifecycle_systemic_repair_20260927_r1/"
    "live_consumer_integration/preimages/"
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py"
)
SUPERVISOR_PREIMAGE_RECEIPT = {
    "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
            "live_consumer_integration/preimage_receipt.json",
    "bytes": 5570,
    "sha256": "11f4574b48ed25256bfc450cffb0fcab6381a24d64c22ea3973921a1cd4f3370",
}
REL_R29_PROTOCOL = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_gridap_consumer_r29_v1/protocol.json"
)
R29_PROTOCOL_PIN = {
    "path": REL_R29_PROTOCOL,
    "bytes": 78155,
    "sha256": "abab03601790bf7e095d19fcbca53426b353c662b6c0d4693c519fd79541dc8a",
}
REL_READINESS = "runs/NativeG1G2DiffusionV1/r30_manifest_readiness_20260926_r1/archive_window_receipt_r1.json"
READINESS_PIN = {
    "path": REL_READINESS,
    "bytes": 104099,
    "sha256": "fb7fc3abb9873933448afb2fe1087e4922d04fd9d6f2e91ad5467ca822108c19",
}
REL_OUTPUT = "runs/NativeG1G2DiffusionV1/managed_lifecycle_formal_root_20260927_r1"
ARCHIVE_PATH = r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\precleanup_docs_runs_tmp.zip"
ARCHIVE_BYTES = 472888641
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
MANIFEST_PATH = (
    "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
    "native_g1g2_prelaunch_r13_v1/r13_actual_v1/parse_manifest.tsv"
)
MANIFEST_BYTES = 11504
MANIFEST_SHA256 = "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa"
MANIFEST_ENTRIES = 108
EXPECTED_SOURCE_PATHS = {
    REL_RUNNER, REL_TEST, REL_VERIFIER, REL_PROVIDER, REL_PARSE_JULIA, REL_BUILDER,
}


class BuildError(RuntimeError):
    pass


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read(path: Path) -> bytes:
    if path.is_symlink() or not path.is_file():
        raise BuildError(f"expected a regular file: {path}")
    return path.read_bytes()


def _file_row(relative: str) -> dict[str, Any]:
    path = ROOT / PurePosixPath(relative)
    raw = _read(path)
    return {"path": relative, "bytes": len(raw), "sha256": _sha256(raw)}


def _safe_workspace_path(relative: str) -> Path:
    logical = PurePosixPath(relative)
    if not relative or "\\" in relative or logical.is_absolute() or \
            logical.as_posix() != relative or any(part in ("", ".", "..") for part in logical.parts):
        raise BuildError(f"unsafe pinned logical path: {relative!r}")
    candidate = ROOT.joinpath(*logical.parts)
    current = ROOT
    for part in logical.parts:
        current = current / part
        if current.is_symlink():
            raise BuildError(f"symlink component in workspace input: {relative}")
    try:
        candidate.resolve(strict=False).relative_to(ROOT.resolve(strict=True))
    except (OSError, ValueError) as exc:
        raise BuildError(f"workspace path escapes repository: {relative}") from exc
    return candidate


def _check_workspace_pin(row: dict[str, Any]) -> None:
    path = _safe_workspace_path(row["path"])
    if not path.is_file():
        raise BuildError(f"workspace pin is not physically present: {row['path']}")
    raw = _read(path)
    if len(raw) != row["bytes"] or _sha256(raw) != row["sha256"]:
        raise BuildError(f"workspace pin changed: {row['path']}")


def _archive_identity(path: Path) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise BuildError("frozen input archive is absent or is not a regular non-symlink file")
    digest = hashlib.sha256()
    total = 0
    with path.open("rb") as stream:
        while True:
            block = stream.read(1024 * 1024)
            if not block:
                break
            digest.update(block)
            total += len(block)
    return {"path": str(path), "bytes": total, "sha256": digest.hexdigest()}


def _verify_archive_members(archive_path: Path,
                            rows: list[dict[str, Any]],
                            pins_by_path: dict[str, dict[str, Any]]) -> list[str]:
    members = [row["path"] for row in rows]
    if len(members) != 47 or members != sorted(set(members)):
        raise BuildError("readiness ZIP source map must contain 47 unique sorted rows")
    try:
        with zipfile.ZipFile(archive_path, "r") as bundle:
            infos = bundle.infolist()
            names: dict[str, list[zipfile.ZipInfo]] = {}
            for info in infos:
                names.setdefault(info.filename, []).append(info)
            for row in rows:
                logical = row["path"]
                if row.get("archive_member") != logical or row.get("central_directory_count") != 1:
                    raise BuildError(f"readiness ZIP row is not a unique exact member: {logical}")
                pin = pins_by_path.get(logical)
                if pin is None or pin != {key: row[key] for key in ("path", "bytes", "sha256")}:
                    raise BuildError(f"readiness ZIP row differs from inherited R29 pin: {logical}")
                physical = _safe_workspace_path(logical)
                if physical.exists() or physical.is_symlink():
                    raise BuildError(f"ZIP-backed path is no longer physically absent: {logical}")
                matches = names.get(logical, [])
                if len(matches) != 1:
                    raise BuildError(f"archive member must occur exactly once: {logical}")
                info = matches[0]
                if info.is_dir() or info.file_size != row["bytes"]:
                    raise BuildError(f"archive member metadata differs from pin: {logical}")
                mode = (info.external_attr >> 16) & 0xFFFF
                file_type = stat.S_IFMT(mode)
                if file_type not in (0, stat.S_IFREG):
                    raise BuildError(f"archive member is not a regular file: {logical}")
                digest = hashlib.sha256()
                total = 0
                with bundle.open(info, "r") as stream:
                    while True:
                        block = stream.read(1024 * 1024)
                        if not block:
                            break
                        digest.update(block)
                        total += len(block)
                if total != row["bytes"] or digest.hexdigest() != row["sha256"]:
                    raise BuildError(f"archive member contents differ from pin: {logical}")
    except (OSError, zipfile.BadZipFile, zipfile.LargeZipFile, EOFError) as exc:
        raise BuildError(f"archive member verification failed: {type(exc).__name__}: {exc}") from exc
    return members


def _load_checked_json(relative: str, expected: dict[str, Any]) -> tuple[dict[str, Any], bytes]:
    path = ROOT / PurePosixPath(relative)
    raw = _read(path)
    row = {"path": relative, "bytes": len(raw), "sha256": _sha256(raw)}
    if row != expected:
        raise BuildError(f"frozen evidence file differs from its pin: {relative}")
    try:
        value = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise BuildError(f"frozen evidence JSON is malformed: {relative}") from exc
    if not isinstance(value, dict):
        raise BuildError(f"frozen evidence JSON root is not an object: {relative}")
    return value, raw


def _pin_row(path: str, byte_count: int, digest: str) -> dict[str, Any]:
    return {"path": path, "bytes": byte_count, "sha256": digest.lower()}


def _receipt_pin_row(path: str, row: dict[str, Any]) -> dict[str, Any]:
    byte_count = row.get("bytes")
    digest = row.get("sha256")
    if type(byte_count) is not int or byte_count <= 0 or type(digest) is not str or \
            len(digest) != 64:
        raise BuildError(f"source lineage pin is malformed: {path}")
    return _pin_row(path, byte_count, digest)


def _build_current_input_source_lineage(
        pin_rows: dict[str, dict[str, Any]],
        foundation_rows: dict[str, dict[str, Any]]) -> dict[str, Any]:
    r25, _ = _load_checked_json(R25_INTEGRATION_RECEIPT["path"], R25_INTEGRATION_RECEIPT)
    r25_review, _ = _load_checked_json(R25_SOURCE_REVIEW["path"], R25_SOURCE_REVIEW)
    stage, _ = _load_checked_json(
        NATIVE_STAGE_R7_RECEIPT["path"], NATIVE_STAGE_R7_RECEIPT)
    stage_review, _ = _load_checked_json(
        NATIVE_STAGE_R32_REVIEW["path"], NATIVE_STAGE_R32_REVIEW)
    prefreeze, _ = _load_checked_json(
        PREFREEZE_R9_RECEIPT["path"], PREFREEZE_R9_RECEIPT)
    prefreeze_review, _ = _load_checked_json(
        PREFREEZE_R9_SOURCE_REVIEW["path"], PREFREEZE_R9_SOURCE_REVIEW)
    final_review, _ = _load_checked_json(
        CURRENT_NINE_PIN_REVIEW["path"], CURRENT_NINE_PIN_REVIEW)

    if r25.get("schema") != "root-reviewed-in-place-integration-v1" or \
            r25.get("owner") != "/root" or r25.get("file_count") != 7 or \
            r25.get("formal_acceptance") is not False or \
            r25.get("fixture_producer_integrated") is not False or \
            r25.get("staging_performed") is not False or \
            r25.get("protected_current_baseline_unchanged") is not True or \
            type(r25.get("files")) is not list or len(r25["files"]) != 7:
        raise BuildError("R25 integration receipt is malformed or claims execution credit")
    if r25.get("review_sha256", "").lower() != R25_SOURCE_REVIEW["sha256"] or \
            not isinstance(r25.get("review_path"), str) or \
            Path(r25["review_path"]).resolve() != \
            _safe_workspace_path(R25_SOURCE_REVIEW["path"]).resolve():
        raise BuildError("R25 receipt is not bound to its fixed independent source review")
    if r25_review.get("schema") != "independent-source-review-v1" or \
            r25_review.get("disposition") != "GO_SOURCE_ONLY" or \
            "no import" not in r25_review.get("scope", "") or \
            "formal T2" not in r25_review.get("scope_limit", ""):
        raise BuildError("R25 independent review does not retain its source-only ceiling")

    r25_rows: dict[str, dict[str, Any]] = {}
    for row in r25["files"]:
        if not isinstance(row, dict) or type(row.get("path")) is not str or \
                row["path"] in r25_rows or set(row) != {
                    "path", "before_sha256", "after_sha256", "bytes"}:
            raise BuildError("R25 integration receipt has malformed/duplicate source rows")
        if type(row.get("bytes")) is not int or row["bytes"] <= 0 or \
                type(row.get("after_sha256")) is not str or \
                len(row["after_sha256"]) != 64 or \
                type(row.get("before_sha256")) is not str or \
                len(row["before_sha256"]) != 64:
            raise BuildError(f"R25 receipt pin is malformed: {row['path']}")
        r25_rows[row["path"]] = row
    expected_r25_paths = {
        "Project.toml",
        "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
        "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl",
        "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
    }
    if set(r25_rows) != expected_r25_paths:
        raise BuildError("R25 source receipt no longer covers its exact seven-file allowlist")

    review_sources = r25_review.get("sources")
    if type(review_sources) is not list or len(review_sources) != 7:
        raise BuildError("R25 source review does not cover all seven integrated source rows")
    reviewed_sources: dict[str, dict[str, Any]] = {}
    for row in review_sources:
        if not isinstance(row, dict) or type(row.get("path")) is not str or \
                row["path"] in reviewed_sources:
            raise BuildError("R25 source review contains malformed or duplicate paths")
        prefix = R25_CANDIDATE_ROOT + "/"
        if not row["path"].startswith(prefix):
            raise BuildError("R25 source review points outside the preserved candidate tree")
        logical = row["path"][len(prefix):]
        reviewed_sources[logical] = row
    if set(reviewed_sources) != expected_r25_paths:
        raise BuildError("R25 review candidate rows differ from the exact seven-file source map")
    for logical, receipt_row in r25_rows.items():
        after = _pin_row(logical, receipt_row["bytes"], receipt_row["after_sha256"])
        reviewed = reviewed_sources[logical]
        if reviewed.get("sha256", "").lower() != after["sha256"] or \
                _file_row(reviewed["path"]) != _pin_row(reviewed["path"], after["bytes"],
                                                         after["sha256"]):
            raise BuildError(f"R25 independent review does not bind exact source bytes: {logical}")

    for logical in expected_r25_paths:
        row = r25_rows[logical]
        original = pin_rows.get(logical)
        if logical == "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl":
            if original is not None:
                raise BuildError("NativeGit shared source unexpectedly entered R29's 214 pins")
            continue
        if original is None:
            raise BuildError(f"R25 source lineage is absent from inherited R29 pins: {logical}")
        foundation = foundation_rows.get(logical)
        if foundation is not None:
            before = foundation.get("before")
            after = foundation.get("after")
            if not isinstance(before, dict) or not isinstance(after, dict) or \
                    _pin_row(logical, before.get("bytes"), before.get("sha256", "")) != original:
                raise BuildError(f"foundation source does not preserve original R29 row: {logical}")
            if row["before_sha256"].lower() != after.get("sha256", "").lower():
                raise BuildError(f"R25 source does not continue the foundation row: {logical}")
        elif row["before_sha256"].lower() != original["sha256"]:
            raise BuildError(f"R25 source does not continue the original R29 row: {logical}")
        current = _file_row(logical)
        if current != _pin_row(logical, row["bytes"], row["after_sha256"]):
            raise BuildError(f"current source differs from the R25 approved integration: {logical}")

    if stage.get("schema") != "root-reviewed-in-place-integration-v1" or \
            stage.get("owner") != "/root" or stage.get("file_count") != 2 or \
            stage.get("formal_acceptance") is not False or \
            stage.get("runtime_executed") is not False or type(stage.get("files")) is not list:
        raise BuildError("NativeGit stage integration receipt is malformed or claims execution credit")
    native_stage_rows = [row for row in stage["files"]
                         if isinstance(row, dict) and row.get("path") ==
                         "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"]
    if len(native_stage_rows) != 1:
        raise BuildError("NativeGit stage receipt does not uniquely identify its source row")
    native_stage = native_stage_rows[0]
    if native_stage.get("before_sha256", "").lower() != R25_NATIVE_AFTER_SHA256 or \
            native_stage.get("after_sha256", "").lower() != NATIVE_STAGE_AFTER_SHA256 or \
            native_stage.get("bytes") != 86552 or native_stage.get("before_kind") != "regular_file" or \
            native_stage.get("review") != NATIVE_STAGE_R32_REVIEW["path"] or \
            native_stage.get("review_sha256", "").lower() != NATIVE_STAGE_R32_REVIEW["sha256"]:
        raise BuildError("NativeGit stage receipt is not an exact R25-to-R32 transition")
    if stage_review.get("schema") != "t2-independent-source-review-v1" or \
            stage_review.get("disposition") != "GO_SOURCE_ONLY" or \
            stage_review.get("target") != NATIVE_STAGE_CANDIDATE or \
            stage_review.get("sha256", "").lower() != NATIVE_STAGE_AFTER_SHA256 or \
            stage_review.get("bytes") != 86552 or \
            stage_review.get("preimage_sha256", "").lower() != R25_NATIVE_AFTER_SHA256:
        raise BuildError("NativeGit stage review does not authenticate the exact chained source")
    if _file_row(NATIVE_STAGE_PRESERVED_POSTIMAGE) != _pin_row(
            NATIVE_STAGE_PRESERVED_POSTIMAGE, 86552, NATIVE_STAGE_AFTER_SHA256):
        raise BuildError("preserved NativeGit stage bytes differ from their GO review")

    if prefreeze.get("schema") != "root-reviewed-in-place-integration-v1" or \
            prefreeze.get("owner") != "/root" or prefreeze.get("file_count") != 7 or \
            prefreeze.get("formal_acceptance") is not False or \
            prefreeze.get("runtime_executed") is not False or \
            prefreeze.get("staging_performed") is not False or \
            type(prefreeze.get("files")) is not list:
        raise BuildError("prefreeze integration receipt is malformed or claims execution credit")
    native_prefreeze_rows = [row for row in prefreeze["files"]
                             if isinstance(row, dict) and row.get("path") ==
                             "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"]
    if len(native_prefreeze_rows) != 1:
        raise BuildError("prefreeze receipt does not uniquely bind the NativeGit source row")
    native_prefreeze = native_prefreeze_rows[0]
    if native_prefreeze.get("before", "").lower() != NATIVE_STAGE_AFTER_SHA256 or \
            native_prefreeze.get("after", "").lower() != NATIVE_CURRENT_SHA256 or \
            native_prefreeze.get("source") != NATIVE_STAGE_CANDIDATE:
        raise BuildError("prefreeze receipt does not continue the reviewed NativeGit stage source")
    candidate_current = _file_row(native_prefreeze["source"])
    if candidate_current != _pin_row(
            native_prefreeze["source"], 86535, NATIVE_CURRENT_SHA256):
        raise BuildError("prefreeze NativeGit source candidate differs from its exact after pin")
    r9_reviews = prefreeze.get("reviews")
    if type(r9_reviews) is not list or not any(
            isinstance(row, dict) and row.get("path") == PREFREEZE_R9_SOURCE_REVIEW["path"] and
            row.get("sha256", "").lower() == PREFREEZE_R9_SOURCE_REVIEW["sha256"]
            for row in r9_reviews):
        raise BuildError("R9 integration receipt does not bind its source-coverage review")
    if prefreeze_review.get("schema") != "t2-independent-source-review-v1" or \
            prefreeze_review.get("review_id") != "source-coverage-fixture-contract-go-r1" or \
            prefreeze_review.get("disposition") != "GO_SOURCE_ONLY_WITH_LAUNCHER_HOLD" or \
            prefreeze_review.get("scope") != \
            "Static source/hash/count inspection only. No Julia, Git, imports, or tests executed.":
        raise BuildError("R9 source-coverage review does not retain its static-only disposition")
    t0_prefreeze_rows = [row for row in prefreeze["files"]
                         if isinstance(row, dict) and row.get("path") ==
                         "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"]
    if len(t0_prefreeze_rows) != 1:
        raise BuildError("R9 receipt does not uniquely bind the current T0 fixture source")
    t0_prefreeze = t0_prefreeze_rows[0]
    t0_review_rows = [row for row in prefreeze_review.get("sources", [])
                      if isinstance(row, dict) and row.get("role") == "T0_fixture_tests" and
                      row.get("path") == t0_prefreeze.get("source")]
    if len(t0_review_rows) != 1:
        raise BuildError("R9 source-coverage review does not uniquely bind the T0 postimage")
    t0_review = t0_review_rows[0]
    t0_foundation = foundation_rows.get(
        "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl")
    if t0_foundation is None or not isinstance(t0_foundation.get("after"), dict) or \
            t0_prefreeze.get("before", "").lower() != \
            t0_foundation["after"].get("sha256", "").lower() or \
            t0_prefreeze.get("after", "").lower() != t0_review.get("sha256", "").lower() or \
            t0_review.get("bytes") != 80556:
        raise BuildError("R9 T0 source row does not continue foundation and review pins")
    if _file_row(t0_review["path"]) != _pin_row(
            t0_review["path"], 80556, t0_review["sha256"]):
        raise BuildError("R9 preserved T0 source candidate differs from its source review")
    t0_current = _file_row(
        "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl")
    if t0_current != _pin_row(
            "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
            80556, t0_review["sha256"]):
        raise BuildError("current T0 source differs from the exact R9 source-review endpoint")
    if final_review.get("schema") != "t2-independent-source-review-v1" or \
            final_review.get("status") != "GO_SOURCE_ONLY":
        raise BuildError("current nine-pin source review is not a source-only GO")
    final_sources = final_review.get("source_map_validation", {}).get("sources")
    native_final_rows = [row for row in final_sources if isinstance(row, dict) and
                         row.get("path") == "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"] \
        if type(final_sources) is list else []
    if len(native_final_rows) != 1 or native_final_rows[0].get("bytes") != 86535 or \
            native_final_rows[0].get("sha256", "").lower() != NATIVE_CURRENT_SHA256:
        raise BuildError("nine-pin GO review does not bind the current NativeGit source")
    current_native = _file_row("src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl")
    if current_native != _pin_row(
            "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
            86535, NATIVE_CURRENT_SHA256):
        raise BuildError("current NativeGit source differs from the exact r25/R32/R9 reviewed chain")

    receipt_pins = {
        "r25_integration_receipt": dict(R25_INTEGRATION_RECEIPT),
        "r25_source_review": dict(R25_SOURCE_REVIEW),
        "native_stage_r7_integration_receipt": dict(NATIVE_STAGE_R7_RECEIPT),
        "native_stage_r32_source_review": dict(NATIVE_STAGE_R32_REVIEW),
        "prefreeze_r9_integration_receipt": dict(PREFREEZE_R9_RECEIPT),
        "prefreeze_r9_source_coverage_review": dict(PREFREEZE_R9_SOURCE_REVIEW),
        "current_nine_pin_source_review": dict(CURRENT_NINE_PIN_REVIEW),
    }
    rows: list[dict[str, Any]] = []
    for logical in SOURCE_LINEAGE_PATHS:
        current = _file_row(logical)
        foundation = foundation_rows.get(logical)
        r25_row = r25_rows.get(logical)
        native = logical == "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"
        if logical == "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl":
            original = pin_rows.get(logical)
            if original is None or foundation is None or r25_row is not None:
                raise BuildError("T0 test lineage has malformed R29/foundation/R25 links")
            after = foundation.get("after")
            if not isinstance(after, dict) or t0_prefreeze.get("before", "").lower() != \
                    after.get("sha256", "").lower() or current != _pin_row(
                        logical, t0_review["bytes"], t0_review["sha256"]):
                raise BuildError("T0 source does not continue foundation through the R9 review")
        elif not native:
            if r25_row is None:
                raise BuildError(f"R25 lineage row is absent: {logical}")
            r25_pin = _pin_row(logical, r25_row["bytes"], r25_row["after_sha256"])
            if current != r25_pin:
                raise BuildError(f"source changed after its reviewed R25 endpoint: {logical}")
        rows.append({
            "path": logical,
            "r29_original_pin": copy.deepcopy(pin_rows.get(logical)),
            "foundation_before_pin": (
                _receipt_pin_row(logical, foundation["before"])
                if foundation is not None and isinstance(foundation.get("before"), dict) and not native
                else None),
            "foundation_after_pin": (
                _receipt_pin_row(logical, foundation["after"])
                if foundation is not None and isinstance(foundation.get("after"), dict) and not native
                else None),
            "r25_before_sha256": (
                r25_row["before_sha256"].lower() if r25_row is not None else None),
            "r25_after_pin": (
                _pin_row(logical, r25_row["bytes"], r25_row["after_sha256"])
                if r25_row is not None else None),
            "native_stage_before_sha256": (
                R25_NATIVE_AFTER_SHA256 if native else None),
            "native_stage_after_pin": (
                _pin_row(logical, 86552, NATIVE_STAGE_AFTER_SHA256) if native else None),
            "r9_before_sha256": (
                t0_prefreeze["before"].lower()
                if logical == "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"
                else NATIVE_STAGE_AFTER_SHA256 if native else None),
            "r9_after_pin": (
                _pin_row(logical, t0_review["bytes"], t0_review["sha256"])
                if logical == "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl"
                else _pin_row(logical, 86535, NATIVE_CURRENT_SHA256) if native else None),
            "current_pin": current,
        })
    return {
        "schema": "native-g1g2-r30-current-input-source-lineage-v1",
        "receipt_pins": receipt_pins,
        "rows": rows,
    }


def _build_current_input_rebindings(
        pin_rows: dict[str, dict[str, Any]]) -> tuple[
            dict[str, dict[str, Any]], dict[str, Any], dict[str, Any]]:
    foundation, _ = _load_checked_json(
        FOUNDATION_INTEGRATION_RECEIPT["path"], FOUNDATION_INTEGRATION_RECEIPT)
    consumer, _ = _load_checked_json(
        SUPERVISOR_PREIMAGE_RECEIPT["path"], SUPERVISOR_PREIMAGE_RECEIPT)
    if foundation.get("schema") != "root-exact-source-integration-receipt-v1" or \
            foundation.get("owner") != "/root" or foundation.get("integrated_count") != 11 or \
            foundation.get("runtime_credit") is not False or \
            foundation.get("formal_credit") is not False or \
            foundation.get("consumer_entrypoints_not_integrated") is not True or \
            foundation.get("deleted_files") != 0 or type(foundation.get("rows")) is not list:
        raise BuildError("foundation preimage receipt does not preserve the approved source integration")
    if consumer.get("schema") != "root-consumer-live-preimage-preservation-v1" or \
            consumer.get("owner") != "/root" or consumer.get("count") != 9 or \
            consumer.get("live_modified") is not False or \
            consumer.get("runtime_executed") is not False or \
            type(consumer.get("rows")) is not list or len(consumer["rows"]) != 9:
        raise BuildError("consumer preimage receipt does not preserve the exact source snapshot")

    foundation_rows: dict[str, dict[str, Any]] = {}
    for row in foundation["rows"]:
        if not isinstance(row, dict) or type(row.get("relative_path")) is not str or \
                row["relative_path"] in foundation_rows:
            raise BuildError("foundation receipt has malformed or duplicate source rows")
        foundation_rows[row["relative_path"]] = row

    source_lineage = _build_current_input_source_lineage(pin_rows, foundation_rows)

    consumer_rows: list[dict[str, Any]] = []
    for row in consumer["rows"]:
        if not isinstance(row, dict) or type(row.get("original_pin")) is not dict or \
                type(row.get("preserved_original_pin")) is not dict:
            raise BuildError("consumer receipt has malformed original-source rows")
        consumer_rows.append(row)

    rebindings: dict[str, dict[str, Any]] = {}
    for logical in CURRENT_INPUT_REBINDING_PATHS[:-1]:
        original = pin_rows.get(logical)
        if original is None:
            raise BuildError(f"approved rebound source is absent from original R29 pins: {logical}")
        row = foundation_rows.get(logical)
        if row is None:
            raise BuildError(f"foundation receipt has no exact old/current row: {logical}")
        before = row.get("before")
        after = row.get("after")
        if not isinstance(before, dict) or not isinstance(after, dict) or \
                _pin_row(logical, before.get("bytes"), before.get("sha256", "")) != original:
            raise BuildError(f"foundation receipt original pin differs from R29: {logical}")
        current = _file_row(logical)
        r25_link = next((entry for entry in source_lineage["rows"]
                         if entry["path"] == logical), None)
        expected_current = (r25_link["current_pin"] if r25_link is not None
                            and (r25_link.get("r25_after_pin") is not None or
                                 r25_link.get("r9_after_pin") is not None) else
                            _pin_row(logical, after.get("bytes"), after.get("sha256", "")))
        if expected_current != current:
            raise BuildError(f"foundation receipt current pin differs from canonical source: {logical}")
        preserved_path = f"{FOUNDATION_PREIMAGE_ROOT}/{logical}"
        preserved = _file_row(preserved_path)
        if preserved["bytes"] != original["bytes"] or \
                preserved["sha256"] != original["sha256"]:
            raise BuildError(f"saved foundation preimage differs from the original R29 pin: {logical}")
        if current["bytes"] == original["bytes"] and current["sha256"] == original["sha256"]:
            raise BuildError(f"approved rebound source is not currently changed: {logical}")
        rebindings[logical] = {
            "original_pin": copy.deepcopy(original),
            "current_pin": current,
            "preserved_original_pin": preserved,
        }

    supervisor_path = SUPERVISOR_ORIGINAL_PIN["path"]
    if pin_rows.get(supervisor_path) != SUPERVISOR_ORIGINAL_PIN:
        raise BuildError("R16 supervisor must match its exact original R29 input pin")
    supervisor_matches = [row for row in consumer_rows
                          if row.get("original_pin") == SUPERVISOR_ORIGINAL_PIN]
    if len(supervisor_matches) != 1:
        raise BuildError("consumer receipt does not uniquely bind the original R16 supervisor")
    supervisor_row = supervisor_matches[0]
    preserved_supervisor = supervisor_row.get("preserved_original_pin")
    if preserved_supervisor != {
            "path": SUPERVISOR_PRESERVED_ORIGINAL_PATH,
            "bytes": SUPERVISOR_ORIGINAL_PIN["bytes"],
            "sha256": SUPERVISOR_ORIGINAL_PIN["sha256"],
    }:
        raise BuildError("consumer receipt supervisor preimage identity changed")
    preserved = _file_row(SUPERVISOR_PRESERVED_ORIGINAL_PATH)
    if preserved != preserved_supervisor:
        raise BuildError("saved supervisor bytes differ from the consumer preservation receipt")
    current = _file_row(supervisor_path)
    if current["bytes"] == SUPERVISOR_ORIGINAL_PIN["bytes"] and \
            current["sha256"] == SUPERVISOR_ORIGINAL_PIN["sha256"]:
        raise BuildError("approved R16 supervisor rebound is not currently changed")
    rebindings[supervisor_path] = {
        "original_pin": copy.deepcopy(SUPERVISOR_ORIGINAL_PIN),
        "current_pin": current,
        "preserved_original_pin": preserved,
    }
    if tuple(rebindings) != CURRENT_INPUT_REBINDING_PATHS:
        raise BuildError("current input rebindings differ from the exact six-path allowlist")
    if any(set(value) != {"original_pin", "current_pin", "preserved_original_pin"}
           for value in rebindings.values()):
        raise BuildError("current input rebind row shape changed")

    receipt_pins = {
        "schema": "native-g1g2-r30-current-input-rebinding-preimage-receipts-v1",
        "foundation_integration_receipt": dict(FOUNDATION_INTEGRATION_RECEIPT),
        "supervisor_preimage_receipt": dict(SUPERVISOR_PREIMAGE_RECEIPT),
    }
    return rebindings, receipt_pins, source_lineage


def _load_inputs() -> tuple[dict[str, Any], dict[str, Any], list[str], dict[str, Any]]:
    r29, r29_raw = _load_checked_json(REL_R29_PROTOCOL, R29_PROTOCOL_PIN)
    if r29.get("schema") != "native-g1g2-gridap-consumer-r29-protocol-v1" or \
            r29.get("input_pin_count") != 214 or type(r29.get("input_pins")) is not list or \
            len(r29["input_pins"]) != 214:
        raise BuildError("frozen R29 protocol does not carry the original 214 input rows")
    if any(row.get("path") == REL_R29_PROTOCOL for row in r29["input_pins"]):
        raise BuildError("R29 protocol unexpectedly appears in its own 214 input rows")
    readiness, _ = _load_checked_json(REL_READINESS, READINESS_PIN)
    if readiness.get("classification") != "read_only_input_readiness_no_runtime_or_science_credit" or \
            readiness.get("files_materialized") is not False or \
            readiness.get("python_julia_or_host_runtime_started") is not False or \
            readiness.get("numerical_credit") is not False or \
            readiness.get("physical_credit") is not False:
        raise BuildError("readiness evidence does not prove a read-only/no-credit preparation")
    if readiness.get("protocol") != {**R29_PROTOCOL_PIN, "input_pin_count": 214}:
        raise BuildError("readiness evidence is not bound to the exact R29 protocol identity")
    pins = r29["input_pins"]
    pin_rows: dict[str, dict[str, Any]] = {}
    for row in pins:
        if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256"}:
            raise BuildError("inherited R29 input pin row shape changed")
        if type(row["path"]) is not str or type(row["bytes"]) is not int or \
                type(row["sha256"]) is not str or len(row["sha256"]) != 64:
            raise BuildError("inherited R29 input pin row values are malformed")
        if row["path"] in pin_rows:
            raise BuildError("inherited R29 input pin paths are not unique")
        pin_rows[row["path"]] = row
    if not set(CURRENT_INPUT_REBINDING_PATHS[:-1]).issubset(pin_rows):
        raise BuildError("the five approved R29 input rebindings are not all in the original 214")
    current_input_rebindings, preimage_receipt_pins, source_lineage = \
        _build_current_input_rebindings(pin_rows)

    input_summary = readiness.get("input_pins")
    if not isinstance(input_summary, dict) or input_summary.get("total") != 214 or \
            input_summary.get("workspace_count") != 167 or input_summary.get("zip_member_count") != 47:
        raise BuildError("readiness evidence has an unexpected 214/167/47 split")
    workspace_rows = input_summary.get("workspace_rows")
    zip_rows = input_summary.get("zip_member_rows")
    if not isinstance(workspace_rows, list) or not isinstance(zip_rows, list) or \
            len(workspace_rows) != 167 or len(zip_rows) != 47:
        raise BuildError("readiness source rows are incomplete")
    workspace_names = [row.get("path") for row in workspace_rows if isinstance(row, dict)]
    zip_names = [row.get("path") for row in zip_rows if isinstance(row, dict)]
    if len(workspace_names) != 167 or len(zip_names) != 47 or \
            set(workspace_names) & set(zip_names) or \
            set(workspace_names) | set(zip_names) != set(pin_rows):
        raise BuildError("readiness source rows do not partition the exact inherited pin set")
    for row in workspace_rows:
        pin = pin_rows[row["path"]]
        if {key: row.get(key) for key in ("path", "bytes", "sha256")} != pin:
            raise BuildError(f"readiness workspace row differs from inherited pin: {row['path']}")
        if pin["path"] not in CURRENT_INPUT_REBINDING_PATHS:
            _check_workspace_pin(pin)
    for row in zip_rows:
        pin = pin_rows[row["path"]]
        if {key: row.get(key) for key in ("path", "bytes", "sha256")} != pin:
            raise BuildError(f"readiness ZIP row differs from inherited pin: {row['path']}")

    manifest = readiness.get("parse_manifest")
    expected_manifest = {"path": MANIFEST_PATH, "bytes": MANIFEST_BYTES,
                         "sha256": MANIFEST_SHA256, "pin_bytes": MANIFEST_BYTES,
                         "pin_sha256": MANIFEST_SHA256, "rows": MANIFEST_ENTRIES,
                         "unique_sources": MANIFEST_ENTRIES,
                         "all_sources_workspace_and_sha_matched": True}
    if not isinstance(manifest, dict) or any(manifest.get(key) != value
                                               for key, value in expected_manifest.items()):
        raise BuildError("original 108-row parse manifest readiness identity changed")
    manifest_pin = pin_rows.get(MANIFEST_PATH)
    if manifest_pin is None or manifest_pin["bytes"] != MANIFEST_BYTES or \
            manifest_pin["sha256"] != MANIFEST_SHA256:
        raise BuildError("original parse manifest is absent from R29's 214 input rows")
    joined = manifest.get("joined_rows")
    if type(joined) is not list or len(joined) != MANIFEST_ENTRIES:
        raise BuildError("parse manifest source join is incomplete")
    joined_names: set[str] = set()
    for row in joined:
        if not isinstance(row, dict) or row.get("local_file") is not True or \
                row.get("path") in joined_names:
            raise BuildError("parse manifest join has a missing/duplicate local source")
        joined_names.add(row["path"])
        pin = pin_rows.get(row["path"])
        if pin is None or row.get("bytes") != pin["bytes"] or \
                row.get("manifest_sha256") != pin["sha256"] or \
                row.get("pin_sha256") != pin["sha256"] or \
                row.get("observed_sha256") != pin["sha256"]:
            raise BuildError(f"parse manifest local source differs from R29 pin: {row['path']}")
        if row["path"] not in PARSE_SOURCE_REBINDING_PATHS:
            _check_workspace_pin(pin)

    archive = readiness.get("archive")
    if not isinstance(archive, dict) or archive.get("path") != ARCHIVE_PATH or \
            archive.get("bytes_before") != ARCHIVE_BYTES or \
            archive.get("sha256_before") != ARCHIVE_SHA256 or \
            archive.get("bytes_after") != ARCHIVE_BYTES or \
            archive.get("sha256_after") != ARCHIVE_SHA256 or \
            archive.get("unchanged") is not True or \
            archive.get("expected_bytes") != ARCHIVE_BYTES or \
            archive.get("expected_sha256") != ARCHIVE_SHA256:
        raise BuildError("readiness evidence archive identity is not the frozen ZIP")
    archive_path = Path(archive.get("path", ""))
    if not archive_path.is_absolute() or archive_path.is_symlink():
        raise BuildError("readiness archive path is not an absolute non-symlink path")
    before = _archive_identity(archive_path)
    if before["bytes"] != ARCHIVE_BYTES or before["sha256"] != ARCHIVE_SHA256:
        raise BuildError("live archive identity differs from frozen readiness receipt")
    member_paths = _verify_archive_members(archive_path, sorted(zip_rows, key=lambda row: row["path"]), pin_rows)
    after = _archive_identity(archive_path)
    if after != before:
        raise BuildError("archive identity changed during R30 protocol construction")
    return r29, readiness, member_paths, {
        "r29_protocol": {**R29_PROTOCOL_PIN, "input_pin_count": 214},
        "readiness_receipt": READINESS_PIN,
        "archive_before": before,
        "archive_after": after,
        "workspace_count": len(workspace_rows),
        "zip_member_count": len(zip_rows),
        "parse_manifest_joined_rows": len(joined),
        "current_input_rebindings": current_input_rebindings,
        "current_input_rebinding_preimage_receipts": preimage_receipt_pins,
        "current_input_source_lineage_v1": source_lineage,
    }


def _source_pins() -> list[dict[str, Any]]:
    rows = [_file_row(path) for path in sorted(EXPECTED_SOURCE_PATHS)]
    if {row["path"] for row in rows} != EXPECTED_SOURCE_PATHS:
        raise BuildError("R30 six-file source closure differs from expected paths")
    return rows


def _managed_process_lifecycle_source_pins() -> dict[str, dict[str, Any]]:
    rows = []
    for relative in MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS:
        _safe_workspace_path(relative)
        rows.append(_file_row(relative))
    pins = {row["path"]: row for row in rows}
    if list(pins) != list(MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS) or \
            any(set(row) != {"path", "bytes", "sha256"} for row in pins.values()):
        raise BuildError("managed process lifecycle source closure is malformed")
    return pins


def _load_runner(expected_source_pin: dict[str, Any]):
    runner_path = ROOT / PurePosixPath(REL_RUNNER)
    raw = _read(runner_path)
    observed_source_pin = {
        "path": REL_RUNNER,
        "bytes": len(raw),
        "sha256": _sha256(raw),
    }
    if expected_source_pin != observed_source_pin:
        raise BuildError("R30 runner execution bytes differ from the pinned source receipt")
    name = "native_g1g2_gridap_consumer_r30_builder_runner"
    module = ModuleType(name)
    module.__file__ = str(runner_path)
    module.__package__ = ""
    sys.modules[name] = module
    try:
        code = compile(raw, str(runner_path), "exec")
        exec(code, module.__dict__)
    except BaseException:
        if sys.modules.get(name) is module:
            del sys.modules[name]
        raise
    return module


def build_protocol() -> dict[str, Any]:
    r29, readiness, zip_member_paths, evidence = _load_inputs()
    output_path = ROOT / PurePosixPath(REL_OUTPUT)
    if output_path.exists() or output_path.is_symlink():
        raise BuildError("R30 actual output root must remain absent before dispatch")
    protocol_path = ROOT / PurePosixPath(REL_PROTOCOL)
    if protocol_path.exists() or protocol_path.is_symlink():
        raise BuildError("R30 protocol already exists; never overwrite a frozen protocol")

    protocol = copy.deepcopy(r29)
    protocol["schema"] = "native-g1g2-gridap-consumer-r30-protocol-v1"
    protocol["version"] = "R30 pinned-archive-input provider v1"
    protocol["created_local_date"] = "2026-09-28"
    protocol["input_pin_count"] = 214
    # Preserve all 214 original row objects in their original order.
    protocol["input_pins"] = copy.deepcopy(r29["input_pins"])
    protocol["planned_output_leaf"] = REL_OUTPUT
    protocol["archive_is_evidence_only"] = True
    protocol["fixture_and_solver_thresholds_unchanged"] = True
    protocol["acceptance_boundary"] = {
        **protocol.get("acceptance_boundary", {}),
        "numerical_credit": False,
        "physical_credit": False,
        "runtime_scope": "existing_native_g1g2_gridap_consumer_only",
    }
    protocol["runtime_grant"] = False
    lineage = copy.deepcopy(protocol.get("parent_lineage", {}))
    lineage["r29_protocol"] = dict(R29_PROTOCOL_PIN)
    protocol["parent_lineage"] = lineage
    protocol["archive_input_provider"] = {
        "schema": "native-g1g2-r30-archive-input-provider-v1",
        "path": ARCHIVE_PATH,
        "bytes": ARCHIVE_BYTES,
        "sha256": ARCHIVE_SHA256,
        "zip_member_paths": zip_member_paths,
        "source_readiness_receipt": dict(READINESS_PIN),
        "source_map_origin": "verified_original_r29_214_pin_join",
    }
    protocol["current_input_rebindings"] = copy.deepcopy(
        evidence["current_input_rebindings"])
    protocol["current_input_rebinding_preimage_receipts"] = copy.deepcopy(
        evidence["current_input_rebinding_preimage_receipts"])
    protocol["current_input_source_lineage_v1"] = copy.deepcopy(
        evidence["current_input_source_lineage_v1"])
    r30_source_pins = _source_pins()
    protocol["r30_source_pins"] = r30_source_pins
    managed_process_lifecycle_source_pins = \
        _managed_process_lifecycle_source_pins()
    protocol["managed_process_lifecycle_source_pins"] = \
        managed_process_lifecycle_source_pins

    execution = protocol["execution_plan"]
    execution["version"] = "native-g1g2-gridap-consumer-r30-execution-plan-v1"
    execution["evidence_output_path_delta"] = "R29 actual -> R30 actual run root"
    execution["versioned_consumer_path_delta"] = (
        "R30 reads the unchanged 108-row parse manifest from its pinned ZIP member via monitored stdin; "
        "primary and fresh replay retain the R29 consumer, fixture, and numerical thresholds")
    execution["parse_manifest"] = {
        "path": MANIFEST_PATH, "bytes": MANIFEST_BYTES,
        "sha256": MANIFEST_SHA256, "entries": MANIFEST_ENTRIES,
    }
    execution["additional_julia_parse_sources"] = [
        managed_process_lifecycle_source_pins[path]
        for path in ADDITIONAL_JULIA_PARSE_SOURCE_PATHS
    ]
    execution["parse_source_rebindings"] = [
        {
            "path": path,
            "original_pin": copy.deepcopy(
                protocol["current_input_rebindings"][path]["original_pin"]),
            "current_pin": copy.deepcopy(
                protocol["current_input_rebindings"][path]["current_pin"]),
        }
        for path in PARSE_SOURCE_REBINDING_PATHS
    ]
    execution["parse_manifest_transport_delta_from_R13"] = \
        "pinned_manifest_bytes_on_stdin_with_length_sha_and_eof_checks"
    execution["stage_order"] = ["parse_all", "primary", "fresh_replay"]
    runner_source_pin = next(
        row for row in r30_source_pins if row["path"] == REL_RUNNER)
    runner = _load_runner(runner_source_pin)
    execution["stage_commands"] = runner.planned_stage_commands(
        protocol, runner.repo_path(REL_OUTPUT))

    python_path = protocol["invocation_contract"]["python_interpreter"]["path"]
    protocol_abs = str(runner.repo_path(REL_PROTOCOL))
    verifier_abs = str(runner.repo_path(REL_VERIFIER))
    runner_abs = str(runner.repo_path(REL_RUNNER))
    test_abs = str(runner.repo_path(REL_TEST))
    output_abs = str(runner.repo_path(REL_OUTPUT))
    protocol["invocation_contract"]["static_verifier_argv"] = [
        python_path, "-B", verifier_abs, "--protocol", protocol_abs]
    protocol["invocation_contract"]["actual_supervisor_argv"] = [
        python_path, "-B", runner_abs, "--dispatch-actual", "--protocol",
        protocol_abs, "--output", output_abs]
    protocol["static_qa"]["verifier_command"] = (
        python_path + " -B " + verifier_abs + " --protocol " + protocol_abs)
    protocol["static_qa"]["r30_input_provider_tests_command"] = (
        python_path + " -B " + test_abs + " -v")
    protocol["static_qa"]["runtime_output_leaf_absent"] = True
    protocol["static_qa"]["julia_started"] = False
    protocol["static_qa"]["runtime_executed"] = False

    # A final re-read binds the exact files that will be recorded and the
    # archive/source closures immediately before protocol serialization.
    if _source_pins() != protocol["r30_source_pins"]:
        raise BuildError("R30 source files changed while building the protocol")
    if _managed_process_lifecycle_source_pins() != \
            protocol["managed_process_lifecycle_source_pins"] or \
            execution["additional_julia_parse_sources"] != [
                protocol["managed_process_lifecycle_source_pins"][path]
                for path in ADDITIONAL_JULIA_PARSE_SOURCE_PATHS]:
        raise BuildError("managed process lifecycle source inputs changed during protocol construction")
    r29_after, _, _, evidence_after = _load_inputs()
    if r29_after["input_pins"] != protocol["input_pins"]:
        raise BuildError("R29 ordered 214 input rows changed during protocol construction")
    if evidence_after["current_input_rebindings"] != \
            protocol["current_input_rebindings"] or \
            evidence_after["current_input_rebinding_preimage_receipts"] != \
            protocol["current_input_rebinding_preimage_receipts"] or \
            evidence_after["current_input_source_lineage_v1"] != \
            protocol["current_input_source_lineage_v1"]:
        raise BuildError("current input rebinding sources changed during protocol construction")
    if execution["parse_source_rebindings"] != [
            {"path": path,
             "original_pin": protocol["current_input_rebindings"][path]["original_pin"],
             "current_pin": protocol["current_input_rebindings"][path]["current_pin"]}
            for path in PARSE_SOURCE_REBINDING_PATHS]:
        raise BuildError("parse source rebindings differ from the exact current input map")
    return protocol


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true",
                        help="write the single frozen R30 protocol if it does not exist")
    args = parser.parse_args(argv)
    if not args.write:
        raise BuildError("protocol creation requires the explicit --write switch")
    protocol = build_protocol()
    output = ROOT / PurePosixPath(REL_PROTOCOL)
    raw = (json.dumps(protocol, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode("utf-8")
    try:
        output.parent.mkdir(parents=True, exist_ok=False)
        with output.open("xb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError as exc:
        raise BuildError("R30 protocol appeared before exclusive create; refusing overwrite") from exc
    observed = _read(output)
    if observed != raw:
        raise BuildError("written R30 protocol bytes differ from the generated object")
    print(json.dumps({
        "schema": "native-g1g2-r30-protocol-builder-receipt-v1",
        "protocol_path": REL_PROTOCOL,
        "protocol_bytes": len(raw),
        "protocol_sha256": _sha256(raw),
        "r29_input_pin_count": 214,
        "input_class_counts": {"workspace": 167, "zip_member": 47},
        "source_pin_count": len(protocol["r30_source_pins"]),
        "managed_process_lifecycle_source_pin_count": len(
            protocol["managed_process_lifecycle_source_pins"]),
        "additional_julia_parse_source_count": len(
            protocol["execution_plan"]["additional_julia_parse_sources"]),
        "parse_manifest_entries": MANIFEST_ENTRIES,
        "expected_total_julia_parse_count": MANIFEST_ENTRIES + len(
            protocol["execution_plan"]["additional_julia_parse_sources"]),
        "archive_identity_before_after_equal": True,
        "materialized_archive_members": False,
        "runtime_started": False,
        "numerical_credit": False,
        "physical_credit": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except BuildError as exc:
        print(f"R30 protocol build refused: {exc}", file=sys.stderr)
        raise SystemExit(2)
