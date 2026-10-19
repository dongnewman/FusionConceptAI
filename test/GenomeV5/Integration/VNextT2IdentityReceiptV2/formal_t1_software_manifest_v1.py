"""Strict verifier for the root-issued T1 software acceptance manifest.

The manifest qualifies the seven-file T1 software/protocol surface.  It is
never candidate-specific.  A separate runtime receipt binds one later T2
candidate after this verifier succeeds.
"""

from __future__ import annotations

import argparse
from contextvars import ContextVar
import hashlib
import json
import os
from pathlib import Path
from pathlib import PurePosixPath
import re
from typing import Any


ROOT = Path(__file__).resolve().parents[4]
SCHEMA = "vnext-t1-software-acceptance-manifest-r1"
EXPECTED_HEAD = "63792ca22958ffca8c3fa8e642256eb9f7240724"
EXPECTED_PROTOCOL_PATH = \
    "test/GenomeV5/Integration/VNextT1FormalR26/protocol_r26_v9.json"
EXPECTED_PROTOCOL_SCHEMA = "vnext_t1_independent_formal_r26_protocol_v9"
EXPECTED_SINGLE_MERGE_SCHEMA = \
    "vnext_t1_independent_formal_r26_single_merge_v8"
EXPECTED_ROUND = "r8"
EXPECTED_RUNS = ("primary_r8", "replay_r8")
EXPECTED_V1_CARRIER_BYTES = 8_269_571
EXPECTED_V1_CARRIER_SHA256 = \
    "1abdd43b057c6f6ba7dc020cf3c4a9239823cc2081f00583a405f7d0d91645f8"
EXPECTED_V2_CARRIER_BYTES = 8_267_526
EXPECTED_V2_CARRIER_SHA256 = \
    "aed5b8f16b9a27c76fe5b098e1e52015d7b4090de1563915a02dcff413885e1a"
EXPECTED_V2_FORMAL_HARNESS_PATH = \
    "test/GenomeV5/Integration/VNextT1FormalR26/v2_formal_r26.jl"
EXPECTED_V2_FORMAL_HARNESS_BYTES = 27_776
EXPECTED_V2_FORMAL_HARNESS_SHA256 = \
    "9a640613875d79b973fb2a42b96a1d2135281ddd9c439228eec550a8567d4cb1"
EXPECTED_STAGE_SCRIPTS = {
    "v1_carrier":
        "test/GenomeV5/Integration/VNextT1FormalR26/v1_shard_r26.jl",
    "v1_contract":
        "test/GenomeV5/Integration/VNextT1FormalR26/v1_shard_r26.jl",
    "v2_formal": EXPECTED_V2_FORMAL_HARNESS_PATH,
    "binding_formal":
        "test/GenomeV5/Integration/VNextT1FormalR26/"
        "binding_missing_wire_formal_r26.jl",
}
EXPECTED_T1_SOURCES = {
    "src/Contracts/CandidateStatePackageV5Next.jl":
        "7ca5b0bfed97193053f157c2b9650624b54ba206784fad348f77fd791652c3b0",
    "src/Contracts/CandidateStatePackageV5NextV2.jl":
        "effac2e603d2a1af30605b70310a634e3659ac487634e164ab049851795c4f89",
    "src/Contracts/VNextT1PackageBindingAdapterV2.jl":
        "a7c6ac7065d84a18e541aa5743dc908f8d5304ec5875726d22d615b2c171e943",
    "src/Contracts/VNextT1CandidateBindingV2.jl":
        "b507f8e4f31baea7fd2c4e5be5b5c7026382d69a92b6235f863bd67433c243b2",
    "src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckLocalV2.jl":
        "d68c61c20d359fd70a364ad70545845e540435b8b052fecf1a9ac1ab64e2008e",
    "src/GenomeV5/Integration/VNextGenomeV5IntegrationV2.jl":
        "37fc25612cccf94044f736984f7f4a730c7f6f078898c80849981add27f3bc86",
    "src/GenomeV5/Integration/VNextGenomeV5Integration.jl":
        "d9824756a1287f6ed7a7df0c5d06a1523b109b52f12a91d36b9aab5ec05ba501",
}
EXPECTED_WORKSPACE_SOURCES_PATH = "tools/workspace_sources.py"
EXPECTED_WORKSPACE_SOURCES_SHA256 = \
    "7c99b3ba9b8bf36923cca729ecaaeb5748a2b9369922dd9ae6bbcb51f64a8920"
EXPECTED_T1_HISTORICAL_INDEX_PATH = \
    "test/fixtures/historical_sources/t1_manifest_index.json"
EXPECTED_T1_HISTORICAL_INDEX_SHA256 = \
    "57a3ddad571af1f4915c421af60231506474571d3bf355c2a51247113b95e07c"
EXPECTED_T1_HISTORICAL_ARCHIVE_PATH = \
    "D:/006-Programing/LMC/FusionConceptAI_cleanup_20260926/" \
    "precleanup_docs_runs_tmp.zip"
EXPECTED_T1_HISTORICAL_ARCHIVE_SNAPSHOT = \
    "t1-r26-precleanup-20260926"
EXPECTED_T1_HISTORICAL_PATHS = frozenset("""
docs/implementation/UP1-04A-VNEXT-T1/astra_semantic_review_20260922_r1/r18/final_cross_process_review_v2.json
docs/implementation/UP1-04A-VNEXT-T1/formal_software_acceptance_r26_v9_r1/assemble_manifest.py
docs/implementation/UP1-04A-VNEXT-T1/formal_software_acceptance_r26_v9_r1/primary_r8.stderr_bundle.json
docs/implementation/UP1-04A-VNEXT-T1/formal_software_acceptance_r26_v9_r1/primary_r8.stdout_bundle.json
docs/implementation/UP1-04A-VNEXT-T1/formal_software_acceptance_r26_v9_r1/replay_r8.stderr_bundle.json
docs/implementation/UP1-04A-VNEXT-T1/formal_software_acceptance_r26_v9_r1/replay_r8.stdout_bundle.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/binding_formal/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/binding_formal/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/binding_formal/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/binding_formal/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/binding_formal/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/single_merge.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_carrier/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_carrier/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_carrier/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_carrier/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_carrier/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_contract/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_contract/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_contract/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_contract/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v1_contract/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v2_formal/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v2_formal/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v2_formal/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v2_formal/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/primary_r8/v2_formal/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/binding_formal/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/binding_formal/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/binding_formal/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/binding_formal/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/binding_formal/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/cross_merge.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/single_merge.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_carrier/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_carrier/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_carrier/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_carrier/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_carrier/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_contract/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_contract/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_contract/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_contract/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v1_contract/stdout.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v2_formal/final.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v2_formal/ledger.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v2_formal/start.json
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v2_formal/stderr.raw
docs/implementation/UP1-04A-VNEXT-T1/independent_formal_r26_20260922/replay_r8/v2_formal/stdout.raw
""".split())
_ACTIVE_T1_HISTORICAL_SESSION: ContextVar[Any] = ContextVar(
    "active_t1_historical_session", default=None)
HEX64 = re.compile(r"^[0-9a-f]{64}$")
EXPECTED_V1_TARGET_IDS = tuple(
    [f"r18v2-{index:03d}" for index in range(1, 64)]
    + [f"r26-extra-{index:03d}" for index in range(1, 8)]
)
EXPECTED_V2_LEGACY_TESTSETS = (
    "V2 same-chain producer to reload adapter",
    "R11b wire-bound package guards and identity witness boundary",
    "V2 fail-closed gates",
    "V2 R7 carrier byte/hash negative matrix",
    "V2 R7 transport duplicate and stale authority negatives",
    "V2 R9 G3 authority shape guards",
    "V2 R7 package wire and semantic tamper fail atomic",
)
EXPECTED_V2_EXTRA_TESTSETS = (
    "R26 V2 honest absence, mismatch, and envelope separation",
    "R26 V2 malformed absence cannot be laundered",
    "R26 V2 detached content joins and constructor closure",
    "R26 V2 reload adapter binding and resource gates",
)
EXPECTED_BINDING_CASE_IDS = (
    "absent_zero", "absent_duplicate_matching", "absent_duplicate_differing",
    "absent_foreign_candidate", "absent_candidate_digest",
    "absent_package_hash", "absent_matching_present",
    "absent_matching_absent", "present_zero", "present_duplicate",
    "present_foreign_candidate", "present_candidate_digest",
    "present_package_hash", "present_observed_absent", "present_matching",
    "present_wrong_wire",
)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def resolve_workspace_file(relative: str) -> Path:
    session = _ACTIVE_T1_HISTORICAL_SESSION.get()
    if session is not None and session.frozen:
        return session.resolve_entry(relative)
    path = (ROOT / relative).resolve()
    path.relative_to(ROOT)
    if not path.is_file():
        raise ValueError(f"referenced artifact is absent: {relative}")
    return path


class _T1HistoricalArchiveSession:
    def __init__(self, reader_module: Any, index_path: Any,
                 index_sha256: Any, archive_path: Any, *,
                 frozen_snapshot: Any = None,
                 expected_snapshot_id: Any = None,
                 expected_manifest_sha256: Any = None,
                 historical_archive_logical_path: str =
                     "historical_archives/t1_precleanup.zip") -> None:
        self._reader_module = reader_module
        self._index_path = index_path
        self._index_sha256 = index_sha256
        self._archive_path = archive_path
        self._frozen_snapshot = frozen_snapshot
        self._expected_snapshot_id = expected_snapshot_id
        self._expected_manifest_sha256 = expected_manifest_sha256
        self._historical_archive_logical_path = historical_archive_logical_path
        self._reader: Any = None

    @property
    def frozen(self) -> bool:
        return any(value is not None for value in (
            self._frozen_snapshot, self._expected_snapshot_id,
            self._expected_manifest_sha256)) or \
            self._historical_archive_logical_path != \
            "historical_archives/t1_precleanup.zip"

    @property
    def configured(self) -> bool:
        if self.frozen:
            return self._frozen_snapshot is not None and all(
                value is not None for value in (
                    self._reader_module, self._index_path,
                    self._index_sha256, self._expected_snapshot_id,
                    self._expected_manifest_sha256))
        return all(value is not None for value in (
            self._reader_module, self._index_path,
            self._index_sha256, self._archive_path))

    @property
    def supplied(self) -> bool:
        return any(value is not None for value in (
            self._reader_module, self._index_path,
            self._index_sha256, self._archive_path,
            self._frozen_snapshot, self._expected_snapshot_id,
            self._expected_manifest_sha256))

    def _frozen_row(self, logical_path: str, *, archive: bool = False) -> Any:
        table = (self._frozen_snapshot.external_archives if archive else
                 self._frozen_snapshot.entries)
        row = table.get(logical_path)
        if row is None or row.get("logical_path") != logical_path:
            raise ValueError(f"T1 frozen input is not declared: {logical_path}")
        return row

    def resolve_entry(self, logical_path: str) -> Path:
        if not self.configured:
            raise ValueError("all frozen T1 snapshot inputs and pins are required")
        row = self._frozen_row(logical_path)
        return self._frozen_snapshot.resolve(
            logical_path, row["bytes"], row["sha256"])

    def read_entry(self, logical_path: str) -> bytes:
        if not self.configured:
            raise ValueError("all frozen T1 snapshot inputs and pins are required")
        row = self._frozen_row(logical_path)
        return self._frozen_snapshot.read_bytes(
            logical_path, row["bytes"], row["sha256"])

    def _open(self) -> None:
        if self._reader is not None:
            return
        if not self.configured:
            if self.frozen:
                raise ValueError("all frozen T1 snapshot inputs and pins are required")
            raise ValueError("explicit T1 historical archive inputs are required")
        if getattr(self._reader_module, "__name__", None) != \
                "tools.workspace_sources":
            raise ValueError("T1 historical reader module identity mismatch")
        module_source = getattr(self._reader_module, "__file__", None)
        if self.frozen:
            snapshot = self._frozen_snapshot
            if type(self._expected_snapshot_id) is not str or \
                    type(self._expected_manifest_sha256) is not str or \
                    type(self._historical_archive_logical_path) is not str:
                raise ValueError("T1 frozen snapshot pins or archive key are invalid")
            expected_snapshot_id = self._expected_snapshot_id.lower()
            expected_manifest_sha256 = self._expected_manifest_sha256.lower()
            if not HEX64.fullmatch(expected_snapshot_id) or \
                    not HEX64.fullmatch(expected_manifest_sha256) or \
                    snapshot.snapshot_id != expected_snapshot_id or \
                    snapshot.inventory_root_sha256 != expected_snapshot_id or \
                    snapshot.manifest_sha256 != expected_manifest_sha256 or \
                    Path(ROOT).resolve(strict=True) != snapshot.root:
                raise ValueError("T1 frozen snapshot identity or ROOT mismatch")
            snapshot.verify_all()
            reader_source = self.resolve_entry(EXPECTED_WORKSPACE_SOURCES_PATH)
            if not isinstance(module_source, str) or \
                    Path(module_source).resolve(strict=True) != reader_source:
                raise ValueError("T1 frozen historical reader module path mismatch")
            reader_bytes = self.read_entry(EXPECTED_WORKSPACE_SOURCES_PATH)
            reader_row = self._frozen_row(EXPECTED_WORKSPACE_SOURCES_PATH)
            if len(reader_bytes) != reader_row["bytes"] or \
                    sha256_bytes(reader_bytes) != reader_row["sha256"]:
                raise ValueError("T1 frozen historical reader source binding mismatch")
        else:
            reader_source = resolve_workspace_file(EXPECTED_WORKSPACE_SOURCES_PATH)
            if not isinstance(module_source, str) or \
                    Path(module_source).resolve(strict=True) != reader_source:
                raise ValueError("T1 historical reader module path mismatch")
            if sha256_bytes(reader_source.read_bytes()) != \
                    EXPECTED_WORKSPACE_SOURCES_SHA256:
                raise ValueError("T1 historical reader source SHA-256 mismatch")
        reader_type = getattr(self._reader_module,
                              "HistoricalSourceReader", None)
        if not isinstance(reader_type, type):
            raise ValueError("T1 historical reader type is unavailable")
        expected_index = ROOT / EXPECTED_T1_HISTORICAL_INDEX_PATH
        try:
            index_input = os.fspath(self._index_path)
            if not isinstance(index_input, str) or not index_input or \
                    "\x00" in index_input or any(
                        part in {".", ".."}
                        for part in re.split(r"[\\/]", index_input)):
                raise ValueError("T1 historical index path is noncanonical")
            supplied_index_arg = Path(index_input)
            supplied_index = supplied_index_arg if supplied_index_arg.is_absolute() \
                else ROOT / supplied_index_arg
            supplied_index = Path(os.path.abspath(supplied_index))
        except (OSError, TypeError, ValueError) as error:
            raise ValueError("T1 historical index path is invalid") from error
        if supplied_index != expected_index:
            raise ValueError("T1 historical index path mismatch")
        if not isinstance(self._index_sha256, str) or \
                self._index_sha256.lower() != \
                EXPECTED_T1_HISTORICAL_INDEX_SHA256:
            raise ValueError("T1 historical index SHA-256 pin mismatch")
        if self.frozen:
            index_logical = EXPECTED_T1_HISTORICAL_INDEX_PATH
            index_row = self._frozen_row(index_logical)
            if index_row["sha256"] != EXPECTED_T1_HISTORICAL_INDEX_SHA256 or \
                    supplied_index != expected_index:
                raise ValueError("T1 frozen historical index identity mismatch")
            archive_logical = self._historical_archive_logical_path
            archive_row = self._frozen_row(archive_logical, archive=True)
            supplied_archive = self._frozen_snapshot.resolve(
                archive_logical, archive_row["bytes"], archive_row["sha256"])
            if self._archive_path is not None:
                try:
                    supplied_archive_arg = Path(self._archive_path)
                    if not supplied_archive_arg.is_absolute() or \
                            Path(os.path.abspath(supplied_archive_arg)) != supplied_archive:
                        raise ValueError("T1 frozen archive path mismatch")
                except (OSError, TypeError, ValueError) as error:
                    raise ValueError("T1 frozen archive path is invalid") from error
            candidate = reader_type.from_frozen_snapshot(
                self._frozen_snapshot, index_logical,
                EXPECTED_T1_HISTORICAL_INDEX_SHA256, archive_logical,
                expected_snapshot_id=expected_snapshot_id,
                expected_manifest_sha256=expected_manifest_sha256,
                strict_subset=True)
        else:
            try:
                supplied_archive_arg = Path(self._archive_path)
                if not supplied_archive_arg.is_absolute():
                    raise ValueError("T1 historical archive path must be absolute")
                supplied_archive = Path(os.path.abspath(supplied_archive_arg))
            except (OSError, TypeError, ValueError) as error:
                raise ValueError("T1 historical archive path is invalid") from error
            if supplied_archive.as_posix() != \
                    EXPECTED_T1_HISTORICAL_ARCHIVE_PATH:
                raise ValueError("T1 historical archive path mismatch")
            candidate = reader_type(
                supplied_index, EXPECTED_T1_HISTORICAL_INDEX_SHA256,
                self._archive_path, strict_subset=True)
        expected_identities = frozenset(
            (logical_path, EXPECTED_T1_HISTORICAL_ARCHIVE_SNAPSHOT)
            for logical_path in EXPECTED_T1_HISTORICAL_PATHS)
        if candidate.indexed_identities != expected_identities:
            raise ValueError("T1 historical index path allowlist mismatch")
        candidate.__enter__()
        self._reader = candidate

    def has_indexed_path(self, relative: str) -> bool:
        self._open()
        return (relative, EXPECTED_T1_HISTORICAL_ARCHIVE_SNAPSHOT) in \
            self._reader.indexed_identities

    def read_bytes(self, relative: str) -> bytes:
        self._open()
        return self._reader.read_bytes(
            relative, EXPECTED_T1_HISTORICAL_ARCHIVE_SNAPSHOT)

    def __enter__(self) -> _T1HistoricalArchiveSession:
        return self

    def __exit__(self, exc_type: Any, exc: Any, traceback: Any) -> bool:
        reader = self._reader
        self._reader = None
        try:
            if reader is None:
                return False
            return reader.__exit__(exc_type, exc, traceback)
        finally:
            if self.frozen and self.configured:
                self._frozen_snapshot.verify_all()


def read_workspace_file_bytes(relative: str) -> bytes:
    if relative in EXPECTED_T1_HISTORICAL_PATHS:
        session = _ACTIVE_T1_HISTORICAL_SESSION.get()
        if session is None or not session.configured:
            if session is not None and session.supplied:
                raise ValueError(
                    "all explicit T1 historical archive inputs are required")
            # Preserve the historical first missing-path error without reading
            # a same-named workspace file as a substitute for archive data.
            resolve_workspace_file(relative)
            raise ValueError(
                f"explicit T1 historical archive input is required: {relative}")
        return session.read_bytes(relative)
    session = _ACTIVE_T1_HISTORICAL_SESSION.get()
    if session is not None and session.frozen:
        return session.read_entry(relative)
    return resolve_workspace_file(relative).read_bytes()


def workspace_file_is_available(relative: str) -> bool:
    if relative in EXPECTED_T1_HISTORICAL_PATHS:
        session = _ACTIVE_T1_HISTORICAL_SESSION.get()
        if session is None or not session.configured:
            if session is not None and session.supplied:
                raise ValueError(
                    "all explicit T1 historical archive inputs are required")
            resolve_workspace_file(relative)
            raise ValueError(
                f"explicit T1 historical archive input is required: {relative}")
        return session.has_indexed_path(relative)
    session = _ACTIVE_T1_HISTORICAL_SESSION.get()
    if session is not None and session.frozen:
        try:
            session.resolve_entry(relative)
        except ValueError as error:
            if str(error) == f"T1 frozen input is not declared: {relative}":
                return False
            raise
        return True
    try:
        resolve_workspace_file(relative)
    except ValueError as error:
        if str(error) == f"referenced artifact is absent: {relative}":
            return False
        raise
    return True


def _verified_file_receipt_data(
        receipt: Any, label: str) -> tuple[dict[str, Any], bytes]:
    if not isinstance(receipt, dict):
        raise ValueError(f"{label} must be an object")
    required = {"path", "bytes", "sha256"}
    if not required.issubset(receipt):
        raise ValueError(f"{label} lacks {sorted(required - set(receipt))}")
    relative = receipt["path"]
    expected_bytes = receipt["bytes"]
    expected_sha = str(receipt["sha256"]).lower()
    if not isinstance(relative, str) or not relative:
        raise ValueError(f"{label}.path is invalid")
    if not isinstance(expected_bytes, int) or expected_bytes < 0:
        raise ValueError(f"{label}.bytes is invalid")
    if not HEX64.fullmatch(expected_sha):
        raise ValueError(f"{label}.sha256 is invalid")
    data = read_workspace_file_bytes(relative)
    actual = {"path": relative, "bytes": len(data),
              "sha256": sha256_bytes(data)}
    if actual["bytes"] != expected_bytes or actual["sha256"] != expected_sha:
        raise ValueError(f"{label} receipt mismatch: {actual}")
    return actual, data


def verify_file_receipt(receipt: Any, label: str) -> dict[str, Any]:
    actual, _ = _verified_file_receipt_data(receipt, label)
    return actual


def actual_file_receipt(relative: str, data: bytes) -> dict[str, Any]:
    return {"path": relative, "bytes": len(data),
            "sha256": sha256_bytes(data)}


def verify_json_receipt(receipt: Any, label: str) -> tuple[dict[str, Any], Any]:
    actual, data = _verified_file_receipt_data(receipt, label)
    try:
        value = json.loads(data.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError(f"{label} is not valid JSON: {error}") from error
    return actual, value


def projection_sha256(value: Any) -> str:
    encoded = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    return sha256_bytes(encoded)


def receipt_hash_equal(left: Any, right: Any) -> bool:
    if not isinstance(left, dict) or not isinstance(right, dict):
        return False
    try:
        return (int(left["bytes"]) == int(right["bytes"]) and
                str(left["sha256"]).lower() == str(right["sha256"]).lower())
    except (KeyError, TypeError, ValueError):
        return False


def receipt_map_equal(actual: Any, expected: Any) -> bool:
    return isinstance(actual, dict) and isinstance(expected, dict) and \
        set(actual) == set(expected) and all(
            receipt_hash_equal(actual[path], expected[path]) for path in expected)


def verify_single_merge_summary(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} summary must be an object")
    schema = str(value.get("schema", ""))
    if schema != EXPECTED_SINGLE_MERGE_SCHEMA:
        raise ValueError(f"{label} summary schema mismatch")
    expected_scalars = {
        "verdict": "pass", "target_count": 70,
        "baseline_target_count": 63, "extra_target_count": 7,
        "v2_legacy_testset_count": 7, "binding_case_count": 16,
        "formal_T1": False, "scientific_acceptance": False,
        "actual_model_attestation": "unavailable",
    }
    for key, expected in expected_scalars.items():
        if value.get(key) != expected:
            raise ValueError(f"{label}.{key} must equal {expected!r}")
    if value.get("round") != EXPECTED_ROUND or \
            value.get("run") not in EXPECTED_RUNS:
        raise ValueError(f"{label} round/run identity mismatch")
    protocol = value.get("protocol")
    if not isinstance(protocol, dict) or \
            not isinstance(protocol.get("bytes"), int) or \
            protocol["bytes"] <= 0 or \
            not HEX64.fullmatch(str(protocol.get("sha256", "")).lower()):
        raise ValueError(f"{label}.protocol receipt is malformed")
    stages = value.get("stages")
    identities = value.get("child_identities")
    stable = value.get("stable_replay_projection")
    expected_stages = {"v1_carrier", "v1_contract", "v2_formal",
                       "binding_formal"}
    if not isinstance(stages, dict) or set(stages) != expected_stages:
        raise ValueError(f"{label}.stages inventory mismatch")
    if not isinstance(identities, dict) or set(identities) != set(stages):
        raise ValueError(f"{label}.child_identities stage set mismatch")
    if not isinstance(stable, dict):
        raise ValueError(f"{label}.stable_replay_projection is required")
    dependencies = stable.get("dependencies")
    if not isinstance(dependencies, list) or not dependencies:
        raise ValueError(f"{label}.stable_replay_projection.dependencies is required")
    dependency_map: dict[str, dict[str, Any]] = {}
    for index, row in enumerate(dependencies):
        if not isinstance(row, dict) or not isinstance(row.get("path"), str) or \
                row["path"] in dependency_map or \
                not isinstance(row.get("bytes"), int) or row["bytes"] < 0 or \
                not HEX64.fullmatch(str(row.get("sha256", "")).lower()):
            raise ValueError(f"{label} stable dependency {index} is malformed")
        dependency_map[row["path"]] = {
            "bytes": row["bytes"], "sha256": str(row["sha256"]).lower()}
    protocol_sha = str(protocol["sha256"]).lower()
    if str(stable.get("protocol_sha256", "")).lower() != protocol_sha:
        raise ValueError(f"{label} stable protocol hash mismatch")
    protocol_bytes = read_workspace_file_bytes(EXPECTED_PROTOCOL_PATH)
    if len(protocol_bytes) != protocol["bytes"] or \
            sha256_bytes(protocol_bytes) != protocol_sha:
        raise ValueError(f"{label} current protocol snapshot differs")
    protocol_document = json.loads(protocol_bytes.decode("utf-8-sig"))
    if not isinstance(protocol_document, dict) or \
            protocol_document.get("schema") != EXPECTED_PROTOCOL_SCHEMA or \
            protocol_document.get("base_head") != EXPECTED_HEAD:
        raise ValueError(f"{label} protocol document identity mismatch")
    if protocol_document.get("formal_T1") is not False or \
            protocol_document.get("scientific_acceptance") is not False or \
            protocol_document.get("actual_model_attestation") != "unavailable" or \
            protocol_document.get("path_guard_selftest", {}).get("passed") is not True:
        raise ValueError(f"{label} protocol evidence ceiling/path guard mismatch")
    parse_rows = protocol_document.get("harness_parse_gate")
    if not isinstance(parse_rows, list) or not parse_rows or \
            any(not isinstance(row, dict) or row.get("parsed") is not True
                for row in parse_rows):
        raise ValueError(f"{label} protocol parse gate is incomplete")
    parse_map = {row.get("path"): row for row in parse_rows}
    if len(parse_map) != len(parse_rows) or any(
            path not in dependency_map or
            not receipt_hash_equal(row, dependency_map[path])
            for path, row in parse_map.items()):
        raise ValueError(f"{label} protocol parse/dependency binding mismatch")
    expected_v2_harness = {
        "bytes": EXPECTED_V2_FORMAL_HARNESS_BYTES,
        "sha256": EXPECTED_V2_FORMAL_HARNESS_SHA256,
    }
    if EXPECTED_V2_FORMAL_HARNESS_PATH not in parse_map or \
            EXPECTED_V2_FORMAL_HARNESS_PATH not in dependency_map or \
            not receipt_hash_equal(
                parse_map[EXPECTED_V2_FORMAL_HARNESS_PATH],
                expected_v2_harness) or \
            not receipt_hash_equal(
                dependency_map[EXPECTED_V2_FORMAL_HARNESS_PATH],
                expected_v2_harness):
        raise ValueError(f"{label} exact V2 formal harness pin mismatch")
    resources = protocol_document.get("resources")
    expected_resources = {
        "carrier_seconds": 10.0,
        "carrier_expected_bytes": EXPECTED_V1_CARRIER_BYTES,
        "package_integrator_seconds": 30.0,
        "reload_adapter_seconds": 30.0,
        "fresh_process_wall_seconds": 240.0,
        "process_tree_rss_bytes": 2_147_483_648,
    }
    if resources != expected_resources:
        raise ValueError(f"{label} protocol resource contract mismatch")
    protocol_dependencies = protocol_document.get("dependencies")
    if not isinstance(protocol_dependencies, list) or \
            len(protocol_dependencies) != len(dependency_map) or any(
                not isinstance(row, dict) or row.get("path") not in dependency_map or
                not receipt_hash_equal(row, dependency_map[row["path"]])
                for row in protocol_dependencies):
        raise ValueError(f"{label} stable/protocol dependency projection mismatch")
    v1_carrier = protocol_document.get("v1", {}).get(
        "source_carrier_fixture")
    if not isinstance(v1_carrier, dict) or \
            v1_carrier.get("expected_bytes") != EXPECTED_V1_CARRIER_BYTES or \
            str(v1_carrier.get("raw_sha256", "")).lower() != \
            EXPECTED_V1_CARRIER_SHA256 or \
            v1_carrier.get("limit_seconds") != 10.0:
        raise ValueError(f"{label} V1 carrier protocol identity mismatch")
    v1_successor = protocol_document["v1"].get("successor")
    v1_reference = v1_carrier.get("reference_manifest")
    if not isinstance(v1_successor, dict) or \
            v1_carrier.get("fixture_source") != v1_successor.get("path") or \
            v1_carrier.get("fixture_source_sha256") != \
            v1_successor.get("sha256") or not isinstance(v1_reference, dict) or \
            v1_reference.get("path") not in dependency_map or \
            not receipt_hash_equal(
                v1_reference, dependency_map[v1_reference["path"]]):
        raise ValueError(f"{label} V1 carrier source/reference pin mismatch")
    v2_carrier = protocol_document.get("v2", {}).get("carrier_fixture")
    if not isinstance(v2_carrier, dict) or \
            v2_carrier.get("expected_bytes") != EXPECTED_V2_CARRIER_BYTES or \
            str(v2_carrier.get("wire_sha256", "")).lower() != \
            EXPECTED_V2_CARRIER_SHA256:
        raise ValueError(f"{label} V2 carrier protocol identity mismatch")
    v2_source = protocol_document["v2"].get("source")
    if not isinstance(v2_source, dict) or \
            v2_carrier.get("fixture_source") != v2_source.get("path") or \
            v2_carrier.get("fixture_source_sha256") != v2_source.get("sha256"):
        raise ValueError(f"{label} V2 carrier source pin mismatch")
    for key in ("reference_receipt", "reference_artifact"):
        reference = v2_carrier.get(key)
        if not isinstance(reference, dict) or \
                reference.get("path") not in dependency_map or \
                not receipt_hash_equal(
                    reference, dependency_map[reference["path"]]):
            raise ValueError(f"{label} V2 carrier {key} pin mismatch")
    return {"schema": schema, "round": value["round"], "run": value["run"],
            "stages": stages, "child_identities": identities,
            "stable_projection": stable,
            "dependency_map": dependency_map,
            "protocol_receipt": {"bytes": protocol["bytes"],
                                 "sha256": protocol_sha},
            "protocol_document": protocol_document,
            "stable_projection_sha256": projection_sha256(stable)}


def verify_stage_command(start: dict[str, Any], stage: str,
                         ledger_relative: str, label: str) -> None:
    command = start.get("command")
    if not isinstance(command, list) or any(
            not isinstance(argument, str) for argument in command):
        raise ValueError(f"{label} recorded command is malformed")
    if stage not in EXPECTED_STAGE_SCRIPTS or len(command) < 7 or \
            Path(command[0]).name.lower() not in {"julia", "julia.exe"} or \
            command[1:4] != [
                "--project=.", "--startup-file=no", "--history-file=no"]:
        raise ValueError(f"{label} recorded Julia command prefix mismatch")
    script_path = Path(command[4])
    if not script_path.is_absolute():
        script_path = ROOT / script_path
    if script_path.resolve() != resolve_workspace_file(
            EXPECTED_STAGE_SCRIPTS[stage]):
        raise ValueError(f"{label} recorded stage harness mismatch")
    expected_middle = ["--shard", stage.removeprefix("v1_")] \
        if stage.startswith("v1_") else []
    if command[5:-2] != expected_middle or command[-2] != "--ledger":
        raise ValueError(f"{label} recorded stage arguments mismatch")
    command_ledger = Path(command[-1])
    if not command_ledger.is_absolute():
        command_ledger = ROOT / command_ledger
    expected_ledger_path = ROOT.joinpath(*PurePosixPath(
        ledger_relative).parts)
    if command_ledger.resolve() != expected_ledger_path.resolve():
        raise ValueError(f"{label} recorded ledger output mismatch")
    cwd = start.get("cwd")
    if not isinstance(cwd, str) or Path(cwd).resolve() != ROOT.resolve() or \
            start.get("owner") != "independent_formal_r26":
        raise ValueError(f"{label} recorded owner/working directory mismatch")


def verify_recorded_stage(receipt: Any, summary: dict[str, Any],
                          label: str) -> dict[str, Any]:
    final_receipt, final = verify_json_receipt(receipt, f"{label}.final")
    final_relative = PurePosixPath(final_receipt["path"])
    if final_relative.name != "final.json":
        raise ValueError(f"{label} must reference a final.json receipt")
    stage = final_relative.parent.name
    summary_stages = summary["stages"]
    if stage not in summary_stages:
        raise ValueError(f"{label} stage {stage!r} is absent from summary")
    if not isinstance(final, dict) or final.get("schema") != \
            "r26_exact_input_run_v1":
        raise ValueError(f"{label} recorded-run schema mismatch")
    if final.get("exit_code") != 0 or final.get("stop_reason") != "natural_exit":
        raise ValueError(f"{label} recorded child did not exit naturally")
    if final.get("input_changes") != [] or \
            final.get("new_or_residual_heavy_processes") != []:
        raise ValueError(f"{label} recorded input/process state is not clean")
    if final.get("inputs_before") != final.get("inputs_after"):
        raise ValueError(f"{label} recorded inputs changed")
    actual_inputs = final.get("inputs_before")
    expected_inputs = dict(summary["dependency_map"])
    expected_inputs[EXPECTED_PROTOCOL_PATH] = summary["protocol_receipt"]
    if not receipt_map_equal(actual_inputs, expected_inputs):
        raise ValueError(f"{label} inputs are not protocol-exact")
    peak = final.get("peak_process_tree_rss_bytes")
    elapsed = final.get("elapsed_seconds")
    if not isinstance(peak, int) or peak < 0 or peak >= 2_147_483_648:
        raise ValueError(f"{label} recorded process-tree RSS gate failed")
    if not isinstance(elapsed, (int, float)) or elapsed < 0:
        raise ValueError(f"{label} recorded elapsed time is invalid")

    start_relative = (final_relative.parent / "start.json").as_posix()
    stdout_relative = (final_relative.parent / "stdout.raw").as_posix()
    stderr_relative = (final_relative.parent / "stderr.raw").as_posix()
    ledger_relative = (final_relative.parent / "ledger.json").as_posix()
    siblings = (start_relative, stdout_relative, stderr_relative)
    for sibling in siblings:
        if not workspace_file_is_available(sibling):
            raise ValueError(
                f"{label} sibling artifact is absent: "
                f"{PurePosixPath(sibling).name}")
    start_data = read_workspace_file_bytes(start_relative)
    stdout_data = read_workspace_file_bytes(stdout_relative)
    stderr_data = read_workspace_file_bytes(stderr_relative)
    start = json.loads(start_data.decode("utf-8-sig"))
    verify_stage_command(start, stage, ledger_relative, label)
    protocol_resources = summary["protocol_document"]["resources"]
    if start.get("timeout_seconds") != \
            protocol_resources["fresh_process_wall_seconds"] or \
            start.get("working_set_limit_bytes") != \
            protocol_resources["process_tree_rss_bytes"]:
        raise ValueError(f"{label} recorded start resource gate mismatch")
    if start.get("environment") != {"JULIA_NUM_THREADS": "1"}:
        raise ValueError(f"{label} recorded Julia environment mismatch")
    if start.get("inputs_before") != final.get("inputs_before"):
        raise ValueError(f"{label} start/final input snapshots differ")
    if elapsed > start["timeout_seconds"]:
        raise ValueError(f"{label} recorded wall-time gate failed")

    stdout = {
        "bytes": len(stdout_data),
        "sha256": sha256_bytes(stdout_data),
    }
    stderr = {
        "bytes": len(stderr_data),
        "sha256": sha256_bytes(stderr_data),
    }
    if not receipt_hash_equal(final.get("stdout"), stdout) or \
            not receipt_hash_equal(final.get("stderr"), stderr):
        raise ValueError(f"{label} raw stdout/stderr receipt mismatch")
    if stderr["bytes"] != 0 or \
            final.get("actual_model_attestation") != "unavailable":
        raise ValueError(f"{label} stderr/model evidence mismatch")
    expected = summary_stages[stage]
    if not isinstance(expected, dict) or \
            expected.get("elapsed_seconds") != elapsed or \
            expected.get("peak_process_tree_rss_bytes") != peak or \
            not receipt_hash_equal(expected.get("stdout"), stdout) or \
            not receipt_hash_equal(expected.get("stderr"), stderr):
        raise ValueError(f"{label} does not match single-merge stage projection")
    identity = {
        "pid": start.get("pid"),
        "process_create_time": start.get("process_create_time"),
        "started_utc": start.get("started_utc"),
    }
    if identity != summary["child_identities"].get(stage):
        raise ValueError(f"{label} child identity differs from single merge")
    return {
        "stage": stage,
        "final": final_receipt,
        "start": actual_file_receipt(start_relative, start_data),
        "stdout": stdout,
        "stderr": stderr,
        "identity": identity,
        "elapsed_seconds": elapsed,
        "peak_process_tree_rss_bytes": peak,
    }


def verify_execution(value: Any, label: str, fresh: bool = False) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object")
    if value.get("status") != "pass" or value.get("exit_code") != 0:
        raise ValueError(f"{label} did not pass naturally")
    if value.get("stop_reason") != "natural_exit":
        raise ValueError(f"{label}.stop_reason must be natural_exit")
    if value.get("pinned_input_changes") != []:
        raise ValueError(f"{label} has input drift")
    if value.get("residual_heavy_processes") != []:
        raise ValueError(f"{label} left residual heavy processes")
    gates = value.get("resource_gates")
    if not isinstance(gates, dict):
        raise ValueError(f"{label}.resource_gates is required")
    for key in ("timeout_seconds", "working_set_limit_bytes",
                "carrier_limit_seconds", "package_integrator_limit_seconds",
                "reload_adapter_limit_seconds", "within_timeout",
                "within_working_set_limit"):
        if key not in gates:
            raise ValueError(f"{label}.resource_gates.{key} is required")
    expected_limits = {
        "timeout_seconds": 240,
        "working_set_limit_bytes": 2_147_483_648,
        "carrier_limit_seconds": 10,
        "package_integrator_limit_seconds": 30,
        "reload_adapter_limit_seconds": 30,
    }
    for key, expected in expected_limits.items():
        if gates.get(key) != expected:
            raise ValueError(
                f"{label}.resource_gates.{key} must equal {expected!r}")
    if gates["within_timeout"] is not True or \
            gates["within_working_set_limit"] is not True:
        raise ValueError(f"{label} exceeded a resource gate")
    summary_receipt, summary_value = verify_json_receipt(
        value.get("summary_receipt"), f"{label}.summary_receipt")
    summary = verify_single_merge_summary(summary_value, label)
    stages = value.get("stage_receipts")
    if not isinstance(stages, list) or not stages:
        raise ValueError(f"{label}.stage_receipts must be nonempty")
    verified = [verify_recorded_stage(item, summary,
        f"{label}.stage_receipts[{i}]") for i, item in enumerate(stages)]
    stage_names = [row["stage"] for row in verified]
    if len(stage_names) != len(set(stage_names)) or \
            set(stage_names) != set(summary["stages"]):
        raise ValueError(f"{label}.stage_receipts stage inventory mismatch")
    stdout = verify_file_receipt(value.get("stdout"), f"{label}.stdout")
    stderr = verify_file_receipt(value.get("stderr"), f"{label}.stderr")
    stable_projection_sha256 = str(
        value.get("stable_projection_sha256", "")).lower()
    if stable_projection_sha256 != summary["stable_projection_sha256"]:
        raise ValueError(f"{label}.stable_projection_sha256 mismatch")
    identities = value.get("child_identities")
    if not isinstance(identities, dict) or not identities:
        raise ValueError(f"{label}.child_identities must be nonempty")
    checked_identities: dict[str, dict[str, Any]] = {}
    if identities != summary["child_identities"]:
        raise ValueError(f"{label}.child_identities differ from single merge")
    for stage, identity in identities.items():
        if not isinstance(stage, str) or not stage or not isinstance(identity, dict):
            raise ValueError(f"{label}.child_identities is malformed")
        if not isinstance(identity.get("pid"), int) or identity["pid"] <= 0:
            raise ValueError(f"{label}.child_identities.{stage}.pid is invalid")
        if not isinstance(identity.get("process_create_time"), (int, float)):
            raise ValueError(
                f"{label}.child_identities.{stage}.process_create_time is invalid")
        if not isinstance(identity.get("started_utc"), str) or \
                not identity["started_utc"]:
            raise ValueError(
                f"{label}.child_identities.{stage}.started_utc is invalid")
        checked_identities[stage] = {
            "pid": identity["pid"],
            "process_create_time": identity["process_create_time"],
            "started_utc": identity["started_utc"],
        }
    if fresh:
        if value.get("fresh_child_identity_distinct") is not True:
            raise ValueError("fresh replay child identity was not distinct")
        if value.get("stable_projection_equal") is not True:
            raise ValueError("fresh replay projection was not stable")
        if value.get("process_overlap") is not False:
            raise ValueError("fresh replay processes overlapped")
    return {"summary_receipt": summary_receipt,
            "summary_schema": summary["schema"],
            "round": summary["round"], "run": summary["run"],
            "stage_receipts": verified, "stdout": stdout, "stderr": stderr,
            "resource_gates": gates,
            "stable_projection_sha256": stable_projection_sha256,
            "stable_projection": summary["stable_projection"],
            "dependency_map": summary["dependency_map"],
            "protocol_document": summary["protocol_document"],
            "protocol_receipt": summary["protocol_receipt"],
            "child_identities": checked_identities}


def verify_v1_carrier_ledgers(execution: dict[str, Any],
                              label: str) -> dict[str, Any]:
    protocol = execution["protocol_document"]
    stable = execution["stable_projection"]
    protocol_sha = execution["protocol_receipt"]["sha256"]
    dependency_map = execution["dependency_map"]
    protocol_shards = {
        row["name"]: row for row in protocol["v1"]["shards"]}
    stable_shards = {
        row["shard"]: row for row in stable.get("v1", [])
        if isinstance(row, dict) and isinstance(row.get("shard"), str)}
    if set(protocol_shards) != {"carrier", "contract"} or \
            set(stable_shards) != {"carrier", "contract"}:
        raise ValueError(f"{label} V1 shard projection mismatch")
    stage_rows = {row["stage"]: row for row in execution["stage_receipts"]}
    ledger_receipts: list[dict[str, Any]] = []
    carrier_observation: dict[str, Any] | None = None
    for shard in ("carrier", "contract"):
        stage = f"v1_{shard}"
        final_relative = PurePosixPath(stage_rows[stage]["final"]["path"])
        ledger_relative = (final_relative.parent / "ledger.json").as_posix()
        if not workspace_file_is_available(ledger_relative):
            raise ValueError(f"{label}.{stage} ledger is absent")
        raw = read_workspace_file_bytes(ledger_relative)
        ledger_receipt = {
            "path": ledger_relative,
            "bytes": len(raw), "sha256": sha256_bytes(raw),
        }
        ledger = json.loads(raw.decode("utf-8-sig"))
        expected = protocol_shards[shard]
        stable_row = stable_shards[shard]
        if not isinstance(ledger, dict) or ledger.get("schema") != \
                "vnext_t1_v1_shard_r26_ledger_v2" or \
                ledger.get("shard") != shard or \
                str(ledger.get("protocol_sha256", "")).lower() != protocol_sha or \
                ledger.get("pid") != stage_rows[stage]["identity"]["pid"]:
            raise ValueError(f"{label}.{stage} ledger identity mismatch")
        if ledger.get("selected_target_ids") != expected["target_ids"] or \
                ledger.get("selected_target_ids") != \
                stable_row.get("selected_target_ids") or \
                ledger.get("runtime_multiplicity") != \
                stable_row.get("runtime_multiplicity") or \
                set(ledger.get("runtime_target_ids", [])) != \
                set(expected["target_ids"]) or \
                ledger.get("target_ownership_exact") is not True or \
                ledger.get("source_sha256") != \
                protocol["v1"]["successor"]["sha256"]:
            raise ValueError(f"{label}.{stage} target/runtime evidence mismatch")
        if ledger.get("include_wall_gate_pass") is not True or \
                ledger.get("include_wall_limit_seconds") != \
                expected["max_wall_seconds"] or \
                not isinstance(ledger.get("include_wall_elapsed_seconds"),
                               (int, float)) or \
                not 0 <= ledger["include_wall_elapsed_seconds"] <= \
                expected["max_wall_seconds"]:
            raise ValueError(f"{label}.{stage} wall gate mismatch")
        if ledger.get("dependencies_unchanged") is not True or \
                not receipt_map_equal(
                    ledger.get("dependencies_before"), dependency_map) or \
                not receipt_map_equal(
                    ledger.get("dependencies_after"), dependency_map) or \
                ledger.get("formal_T1") is not False or \
                ledger.get("scientific_acceptance") is not False or \
                ledger.get("actual_model_attestation") != "unavailable":
            raise ValueError(f"{label}.{stage} dependency/status evidence mismatch")
        observation = ledger.get("source_carrier_resource")
        if shard == "carrier":
            if observation is not None:
                raise ValueError(
                    f"{label}.{stage} unexpectedly executed source carrier")
        else:
            spec = protocol["v1"]["source_carrier_fixture"]
            if not isinstance(observation, dict) or observation.get("schema") != \
                    "vnext_t1_v1_source_carrier_resource_r26_v1" or \
                    observation.get("first_call_count") != 1 or \
                    observation.get("operation") != spec["operation"] or \
                    observation.get("fixture") != spec["fixture"]:
                raise ValueError(f"{label}.{stage} source carrier identity mismatch")
            exact_scalars = {
                "expected_bytes": EXPECTED_V1_CARRIER_BYTES,
                "actual_bytes": EXPECTED_V1_CARRIER_BYTES,
                "carrier_bytes": EXPECTED_V1_CARRIER_BYTES,
                "expected_raw_sha256": EXPECTED_V1_CARRIER_SHA256,
                "raw_sha256": EXPECTED_V1_CARRIER_SHA256,
                "carrier_sha256": EXPECTED_V1_CARRIER_SHA256,
                "limit_seconds": 10.0,
                "carrier_type": "FusionConceptAI.VNextT1CanonicalBytesV2",
                "exact_byte_join": True,
                "gate_pass": True,
            }
            if any(observation.get(key) != expected_value
                   for key, expected_value in exact_scalars.items()) or \
                    not isinstance(observation.get("cold_seconds"), (int, float)) or \
                    not 0 <= observation["cold_seconds"] <= 10.0 or \
                    not isinstance(observation.get("canonical_seconds"),
                                   (int, float)) or \
                    observation["canonical_seconds"] < 0:
                raise ValueError(f"{label}.{stage} source carrier gate failed")
            carrier_observation = observation
        ledger_receipts.append(ledger_receipt)
    if carrier_observation is None:
        raise ValueError(f"{label} source carrier observation is absent")
    expected_carrier_projection = {key: carrier_observation[key] for key in (
        "operation", "fixture", "actual_bytes", "raw_sha256",
        "carrier_bytes", "carrier_sha256", "carrier_type", "exact_byte_join")}
    if stable.get("v1_source_carrier") != expected_carrier_projection:
        raise ValueError(f"{label} source carrier stable projection mismatch")
    return {"ledger_receipts": ledger_receipts,
            "source_carrier": expected_carrier_projection}


def verify_coverage(value: Any) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ValueError("coverage must be an object")
    v1 = value.get("v1")
    v2 = value.get("v2")
    binding = value.get("binding")
    if not all(isinstance(item, dict) for item in (v1, v2, binding)):
        raise ValueError("coverage v1/v2/binding objects are required")
    v1_expected = {"status": "pass", "legacy_target_count": 63,
                   "added_target_count": 7, "exact_target_count": 70,
                   "unique_target_count": 70, "missing_targets": [],
                   "duplicate_targets": []}
    for key, expected in v1_expected.items():
        if v1.get(key) != expected:
            raise ValueError(f"coverage.v1.{key} must equal {expected!r}")
    target_ids = v1.get("target_ids")
    if target_ids != list(EXPECTED_V1_TARGET_IDS):
        raise ValueError("coverage.v1.target_ids is not the exact ordered 63+7 set")
    if v2.get("status") != "pass" or v2.get("legacy_testset_count") != 7:
        raise ValueError("coverage.v2 must pass all seven legacy testsets")
    legacy = v2.get("legacy_testsets")
    if not isinstance(legacy, list) or [row.get("title") for row in legacy
            if isinstance(row, dict)] != list(EXPECTED_V2_LEGACY_TESTSETS):
        raise ValueError("coverage.v2.legacy_testsets inventory mismatch")
    if len(legacy) != 7 or any(row.get("status") != "pass" for row in legacy):
        raise ValueError("coverage.v2 legacy testset status mismatch")
    extras = v2.get("required_extras")
    if extras != list(EXPECTED_V2_EXTRA_TESTSETS):
        raise ValueError("coverage.v2.required_extras inventory mismatch")
    if binding.get("status") != "pass" or binding.get("case_count") != 16:
        raise ValueError("coverage.binding must pass exactly 16 cases")
    if binding.get("case_ids") != list(EXPECTED_BINDING_CASE_IDS):
        raise ValueError("coverage.binding.case_ids inventory mismatch")
    v1_receipt, v1_summary_value = verify_json_receipt(
        v1.get("receipt"), "coverage.v1.receipt")
    v1_summary = verify_single_merge_summary(
        v1_summary_value, "coverage.v1.receipt")
    protocol_document = v1_summary["protocol_document"]
    dependency_map = v1_summary["dependency_map"]
    protocol_sha = v1_summary["protocol_receipt"]["sha256"]
    v1_rows = v1_summary["stable_projection"].get("v1")
    if not isinstance(v1_rows, list) or not v1_rows:
        raise ValueError("coverage.v1 actual shard projection is absent")
    actual_target_ids: list[str] = []
    for index, row in enumerate(v1_rows):
        if not isinstance(row, dict):
            raise ValueError(f"coverage.v1 shard {index} is malformed")
        selected = row.get("selected_target_ids")
        multiplicity = row.get("runtime_multiplicity")
        if not isinstance(selected, list) or not isinstance(multiplicity, dict):
            raise ValueError(f"coverage.v1 shard {index} lacks runtime evidence")
        if set(multiplicity) != set(selected) or any(
                not isinstance(count, int) or count <= 0
                for count in multiplicity.values()):
            raise ValueError(f"coverage.v1 shard {index} runtime multiplicity failed")
        actual_target_ids.extend(selected)
    if actual_target_ids != list(EXPECTED_V1_TARGET_IDS) or \
            len(set(actual_target_ids)) != 70:
        raise ValueError("coverage.v1 actual execution is not exact 63+7")

    v2_receipt_rows = v2.get("receipts")
    if not isinstance(v2_receipt_rows, list) or not v2_receipt_rows:
        raise ValueError("coverage.v2 requires immutable JSON receipts")
    v2_documents: list[tuple[dict[str, Any], Any]] = []
    seen_v2_paths: set[str] = set()
    for index, receipt in enumerate(v2_receipt_rows):
        actual, document = verify_json_receipt(
            receipt, f"coverage.v2.receipts[{index}]")
        if actual["path"] in seen_v2_paths:
            raise ValueError("coverage.v2 contains duplicate receipt paths")
        seen_v2_paths.add(actual["path"])
        v2_documents.append((actual, document))
    ledgers = [(actual, document) for actual, document in v2_documents
        if isinstance(document, dict) and document.get("schema") ==
        "vnext_t1_v2_formal_r26_ledger_v3"]
    if len(ledgers) != 1:
        raise ValueError("coverage.v2 requires exactly one V2 formal ledger")
    v2_ledger_receipt, v2_ledger = ledgers[0]
    legacy_actual = v2_ledger.get("legacy_testsets")
    protocol_legacy = protocol_document["v2"]["legacy_testsets"]
    if v2_ledger.get("legacy_testset_count") != 7 or \
            not isinstance(legacy_actual, list) or len(legacy_actual) != 7 or \
            [row.get("title") for row in legacy_actual
             if isinstance(row, dict)] != list(EXPECTED_V2_LEGACY_TESTSETS) or \
            [{key: row.get(key) for key in ("title", "ast_sha256")}
             for row in legacy_actual if isinstance(row, dict)] != \
            protocol_legacy or \
            any(not isinstance(row, dict) or row.get("status") != "pass"
                or row.get("default_source_ast_sha256") !=
                row.get("ast_sha256") or row.get("context_match") is not True
                or row.get("filename_context_ast_sha256") !=
                row.get("captured_ast_sha256")
                or row.get("filename_context_line_files") !=
                row.get("captured_line_files") for row in legacy_actual):
        raise ValueError("coverage.v2 actual legacy execution mismatch")
    measured_v2_resources = {
        "carrier_seconds": protocol_document["resources"]["carrier_seconds"],
        "package_integrator_seconds":
            protocol_document["resources"]["package_integrator_seconds"],
        "reload_adapter_seconds":
            protocol_document["resources"]["reload_adapter_seconds"],
    }
    if v2_ledger.get("historical_writer_suppressions") != 2 or \
            v2_ledger.get("pid") != \
            v1_summary["child_identities"]["v2_formal"]["pid"] or \
            v2_ledger.get("carrier_gate_pass") is not True or \
            v2_ledger.get("package_integrator_gate_pass") is not True or \
            v2_ledger.get("reload_adapter_gate_pass") is not True or \
            v2_ledger.get("carrier_limit_seconds") != 10 or \
            v2_ledger.get("package_integrator_limit_seconds") != 30 or \
            v2_ledger.get("reload_adapter_limit_seconds") != 30 or \
            v2_ledger.get("inputs_unchanged") is not True or \
            v2_ledger.get("dependencies_unchanged") is not True or \
            not receipt_map_equal(
                v2_ledger.get("dependencies_before"), dependency_map) or \
            not receipt_map_equal(
                v2_ledger.get("dependencies_after"), dependency_map) or \
            str(v2_ledger.get("protocol_sha256", "")).lower() != protocol_sha:
        raise ValueError("coverage.v2 actual resource/input evidence failed")
    for field, limit in measured_v2_resources.items():
        measured = v2_ledger.get(field)
        if isinstance(measured, bool) or \
                not isinstance(measured, (int, float)) or \
                not 0 <= measured <= limit:
            raise ValueError(f"coverage.v2 actual {field} gate failed")
    for key in ("wire_sha256", "bundle_hash", "semantic_identity", "package_hash"):
        if not HEX64.fullmatch(str(v2_ledger.get(key, "")).lower()):
            raise ValueError(f"coverage.v2 actual {key} is invalid")
    if v2_ledger.get("carrier_expected_bytes") != EXPECTED_V2_CARRIER_BYTES or \
            str(v2_ledger.get("carrier_expected_sha256", "")).lower() != \
            EXPECTED_V2_CARRIER_SHA256 or \
            v2_ledger.get("wire_bytes") != EXPECTED_V2_CARRIER_BYTES or \
            str(v2_ledger.get("wire_sha256", "")).lower() != \
            EXPECTED_V2_CARRIER_SHA256 or \
            not isinstance(v2_ledger.get("serialized_package_bytes"), int) or \
            v2_ledger["serialized_package_bytes"] <= 0:
        raise ValueError("coverage.v2 actual carrier/package bytes mismatch")
    source_relative = v2_ledger.get("source")
    source_sha = str(v2_ledger.get("source_sha256", "")).lower()
    protocol_v2_source = protocol_document["v2"]["source"]
    if not isinstance(source_relative, str) or not HEX64.fullmatch(source_sha) or \
            source_relative.replace("\\", "/") != protocol_v2_source["path"] or \
            source_sha != str(protocol_v2_source["sha256"]).lower() or \
            protocol_v2_source["path"] not in dependency_map or \
            not receipt_hash_equal(
                protocol_v2_source,
                dependency_map[protocol_v2_source["path"]]):
        raise ValueError("coverage.v2 source identity is malformed")
    source_bytes = read_workspace_file_bytes(source_relative)
    if sha256_bytes(source_bytes) != source_sha:
        raise ValueError("coverage.v2 source identity changed")
    harness_receipt = dependency_map.get(EXPECTED_V2_FORMAL_HARNESS_PATH)
    if not receipt_hash_equal(harness_receipt, {
            "bytes": EXPECTED_V2_FORMAL_HARNESS_BYTES,
            "sha256": EXPECTED_V2_FORMAL_HARNESS_SHA256}):
        raise ValueError("coverage.v2 formal harness dependency mismatch")
    harness_raw = read_workspace_file_bytes(EXPECTED_V2_FORMAL_HARNESS_PATH)
    if len(harness_raw) != EXPECTED_V2_FORMAL_HARNESS_BYTES or \
            sha256_bytes(harness_raw) != EXPECTED_V2_FORMAL_HARNESS_SHA256:
        raise ValueError("coverage.v2 formal harness identity changed")
    harness_text = harness_raw.decode("utf-8")
    for title in EXPECTED_V2_EXTRA_TESTSETS:
        if harness_text.count(f'@testset "{title}"') != 1:
            raise ValueError(f"coverage.v2 required extra missing: {title}")

    binding_receipt, binding_ledger = verify_json_receipt(
        binding.get("receipt"), "coverage.binding.receipt")
    if not isinstance(binding_ledger, dict) or binding_ledger.get("schema") != \
            "vnext_t1_binding_cross_product_r26_ledger_v1":
        raise ValueError("coverage.binding actual ledger schema mismatch")
    results = binding_ledger.get("results")
    if binding_ledger.get("case_count") != 16 or \
            not isinstance(results, list) or len(results) != 16 or \
            [row.get("name") for row in results if isinstance(row, dict)] != \
             list(EXPECTED_BINDING_CASE_IDS) or \
            any(not isinstance(row, dict) or
                row.get("receipt_hash_matches") is not True for row in results) or \
            binding_ledger.get("pid") != \
            v1_summary["child_identities"]["binding_formal"]["pid"] or \
            binding_ledger.get("dependencies_unchanged") is not True or \
            not receipt_map_equal(
                binding_ledger.get("dependencies_before"), dependency_map) or \
            not receipt_map_equal(
                binding_ledger.get("dependencies_after"), dependency_map) or \
            str(binding_ledger.get("protocol_sha256", "")).lower() != protocol_sha:
        raise ValueError("coverage.binding actual cross-product evidence failed")
    return {
        "v1": {"receipt": v1_receipt,
               "stable_projection_sha256":
                   v1_summary["stable_projection_sha256"],
               "actual_target_ids": actual_target_ids,
               "protocol_document": protocol_document},
        "v2": {"receipts": [row[0] for row in v2_documents],
               "ledger_receipt": v2_ledger_receipt,
               "legacy_testsets": [row["title"] for row in legacy_actual],
               "required_extras": list(EXPECTED_V2_EXTRA_TESTSETS),
               "protocol_sha256": str(
                   v2_ledger.get("protocol_sha256", "")).lower(),
               "stable_projection": {key: v2_ledger[key] for key in (
                   "source_sha256", "legacy_testsets", "wire_bytes",
                   "wire_sha256", "bundle_hash", "semantic_identity",
                   "package_hash", "serialized_package_bytes")}},
        "binding": {"receipt": binding_receipt,
                    "case_ids": [row["name"] for row in results],
                    "protocol_sha256": str(
                        binding_ledger.get("protocol_sha256", "")).lower(),
                    "stable_projection": {
                        "case_count": binding_ledger["case_count"],
                        "results": results,
                    }},
    }


def reject_candidate_fields(value: Any, path: str = "manifest") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            lowered = str(key).lower()
            if "candidate" in lowered and key != "candidate_specific":
                raise ValueError(f"candidate-specific field forbidden at {path}.{key}")
            reject_candidate_fields(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            reject_candidate_fields(child, f"{path}[{index}]")


def _verify_formal_frozen_protocol(snapshot: Any, protocol_path_value: str,
                                  expected_protocol_sha256: str,
                                  expected_snapshot_id: str,
                                  expected_manifest_sha256: str) -> None:
    protocol_input = Path(protocol_path_value)
    if not protocol_input.is_absolute():
        raise ValueError("formal T2 protocol path must be absolute")
    protocol_path = protocol_input.resolve(strict=True)
    root = Path(snapshot.root).resolve(strict=True)
    try:
        protocol_path.relative_to(root)
    except ValueError:
        pass
    else:
        raise ValueError("formal T2 protocol must be outside the frozen source tree")
    raw = protocol_path.read_bytes()
    if sha256_bytes(raw) != expected_protocol_sha256.lower():
        raise ValueError("formal T2 protocol raw SHA-256 mismatch")
    try:
        protocol = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ValueError("formal T2 protocol is not valid JSON") from error
    if not isinstance(protocol, dict):
        raise ValueError("formal T2 protocol root must be an object")
    if "protocol_path" in protocol and protocol.get("protocol_path") != str(protocol_path):
        raise ValueError("formal T2 protocol path identity mismatch")
    record = protocol.get("source_snapshot")
    consumer = protocol.get("consumer")
    consumer_protocol = consumer.get("protocol") if isinstance(consumer, dict) else None
    wrapped_record = consumer_protocol.get("source_snapshot") \
        if isinstance(consumer_protocol, dict) else None
    if record is None:
        record = wrapped_record
    elif wrapped_record is not None and wrapped_record != record:
        raise ValueError("formal T2 protocol source authorization wrappers differ")
    if not isinstance(record, dict) or \
            record.get("schema") != "fusion-t2-frozen-input-snapshot-v1":
        raise ValueError("formal T2 protocol lacks frozen source authorization")
    snapshot.verify_frozen_identity()
    manifest = snapshot.manifest_path.read_bytes()

    def expected_rows(rows: Any) -> dict[str, dict[str, Any]]:
        return {key: {"role": row["role"], "bytes": row["bytes"],
                      "sha256": row["sha256"]}
                for key, row in sorted(rows.items())}

    if record.get("source_root") != str(root) or \
            record.get("manifest_path") != "manifest.toml" or \
            record.get("manifest_bytes") != len(manifest) or \
            record.get("manifest_sha256") != expected_manifest_sha256.lower() or \
            sha256_bytes(manifest) != expected_manifest_sha256.lower() or \
            snapshot.manifest_sha256 != expected_manifest_sha256.lower() or \
            record.get("inventory_root_sha256") != expected_snapshot_id.lower() or \
            record.get("snapshot_id") != expected_snapshot_id.lower() or \
            snapshot.inventory_root_sha256 != expected_snapshot_id.lower() or \
            snapshot.snapshot_id != expected_snapshot_id.lower() or \
            record.get("expected_entries") != expected_rows(snapshot.entries) or \
            record.get("expected_external_archives") != expected_rows(
                snapshot.external_archives):
        raise ValueError("formal T2 protocol source authorization differs from frozen snapshot")


def _verify_manifest_active(path: Path,
                            expected_raw_sha256: str) -> dict[str, Any]:
    expected = expected_raw_sha256.lower()
    if not HEX64.fullmatch(expected):
        raise ValueError("expected software manifest SHA-256 must be 64 hex chars")
    raw = path.read_bytes()
    actual_sha = sha256_bytes(raw)
    if actual_sha != expected:
        raise ValueError("software manifest raw SHA-256 mismatch")
    manifest = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(manifest, dict):
        raise ValueError("software manifest root must be an object")
    reject_candidate_fields(manifest)
    if manifest.get("schema") != SCHEMA:
        raise ValueError("software manifest schema mismatch")
    if manifest.get("formal_t1_software_accepted") is not True:
        raise ValueError("formal T1 software acceptance is not true")
    if manifest.get("acceptance_scope") != "software_capability_multi_candidate":
        raise ValueError("software acceptance scope mismatch")
    if manifest.get("candidate_specific") is not False:
        raise ValueError("software manifest must not be candidate-specific")
    if manifest.get("repository_head") != EXPECTED_HEAD:
        raise ValueError("software manifest repository HEAD mismatch")
    if manifest.get("actual_model_attestation") != "unavailable":
        raise ValueError("actual_model_attestation must remain unavailable")
    accepted_by = manifest.get("accepted_by")
    if not isinstance(accepted_by, dict) or accepted_by.get("role") != "root":
        raise ValueError("software manifest must be accepted by role root")

    source_rows = manifest.get("source_receipts")
    if not isinstance(source_rows, list) or len(source_rows) != 7:
        raise ValueError("software manifest requires exactly seven source receipts")
    source_by_path = {row.get("path"): row for row in source_rows
                      if isinstance(row, dict)}
    if set(source_by_path) != set(EXPECTED_T1_SOURCES):
        raise ValueError("software manifest seven-source path set mismatch")
    verified_sources = []
    for relative, frozen_hash in EXPECTED_T1_SOURCES.items():
        row = source_by_path[relative]
        if str(row.get("sha256", "")).lower() != frozen_hash:
            raise ValueError(f"frozen T1 source hash mismatch for {relative}")
        verified_sources.append(verify_file_receipt(
            row, f"source_receipts[{relative}]"))

    protocol = manifest.get("protocol_scope")
    if not isinstance(protocol, dict):
        raise ValueError("protocol_scope is required")
    historical = protocol.get("historical_snapshot_receipts")
    current = protocol.get("current_integration_receipts")
    if not isinstance(historical, list) or not historical:
        raise ValueError("historical protocol snapshot receipts are required")
    if not isinstance(current, list) or not current:
        raise ValueError("current integration receipts are required")
    if protocol.get("shared_loader_covered") is not False:
        raise ValueError("historical T1 manifest cannot claim the new shared loader")
    verified_protocol = {
        "historical": [verify_file_receipt(item,
            f"protocol_scope.historical_snapshot_receipts[{i}]")
            for i, item in enumerate(historical)],
        "current": [verify_file_receipt(item,
            f"protocol_scope.current_integration_receipts[{i}]")
            for i, item in enumerate(current)],
    }

    coverage = verify_coverage(manifest.get("coverage"))
    primary = verify_execution(manifest.get("primary_execution"),
                               "primary_execution")
    replay = verify_execution(manifest.get("fresh_replay"), "fresh_replay",
                               fresh=True)
    if primary["run"] != "primary_r8" or replay["run"] != "replay_r8" or \
            primary["round"] != EXPECTED_ROUND or \
            replay["round"] != EXPECTED_ROUND:
        raise ValueError("primary/replay v9 round identities are invalid")
    primary_v1_carrier = verify_v1_carrier_ledgers(
        primary, "primary_execution")
    replay_v1_carrier = verify_v1_carrier_ledgers(
        replay, "fresh_replay")
    if primary_v1_carrier["source_carrier"] != \
            replay_v1_carrier["source_carrier"]:
        raise ValueError("primary/replay V1 source carrier identity differs")
    if set(primary["child_identities"]) != set(replay["child_identities"]):
        raise ValueError("primary/replay child stage identity sets differ")
    for stage in primary["child_identities"]:
        first = primary["child_identities"][stage]
        second = replay["child_identities"][stage]
        if (first["pid"], first["process_create_time"]) == \
                (second["pid"], second["process_create_time"]):
            raise ValueError(f"fresh replay child identity was reused: {stage}")
    if primary["stable_projection_sha256"] != \
            replay["stable_projection_sha256"]:
        raise ValueError("primary/replay stable projection hashes differ")
    if primary["stable_projection"] != replay["stable_projection"]:
        raise ValueError("primary/replay stable projection content differs")
    if not receipt_hash_equal(
            coverage["v1"]["receipt"], primary["summary_receipt"]):
        raise ValueError("coverage.v1 is not bound to the primary single merge")
    if coverage["v1"]["stable_projection_sha256"] != \
            primary["stable_projection_sha256"]:
        raise ValueError("coverage.v1 projection differs from primary execution")
    primary_stable = primary["stable_projection"]
    if primary_stable.get("v2") != coverage["v2"]["stable_projection"]:
        raise ValueError("coverage.v2 ledger differs from primary stable projection")
    if primary_stable.get("binding") != \
            coverage["binding"]["stable_projection"]:
        raise ValueError(
            "coverage.binding ledger differs from primary stable projection")
    stable_protocol_sha = str(primary_stable.get("protocol_sha256", "")).lower()
    if not HEX64.fullmatch(stable_protocol_sha) or \
            coverage["v2"]["protocol_sha256"] != stable_protocol_sha or \
            coverage["binding"]["protocol_sha256"] != stable_protocol_sha:
        raise ValueError("coverage ledger protocol hashes differ from primary")
    primary_root = PurePosixPath(
        primary["summary_receipt"]["path"]).parent
    v2_ledger_path = PurePosixPath(
        coverage["v2"]["ledger_receipt"]["path"])
    binding_ledger_path = PurePosixPath(
        coverage["binding"]["receipt"]["path"])
    if v2_ledger_path.parent != primary_root / "v2_formal" or \
            binding_ledger_path.parent != primary_root / "binding_formal":
        raise ValueError("coverage ledgers are not from the primary execution")
    reviews = manifest.get("independent_review_receipts")
    if not isinstance(reviews, list) or not reviews:
        raise ValueError("at least one independent review receipt is required")
    verified_reviews = [verify_file_receipt(item,
        f"independent_review_receipts[{i}]") for i, item in enumerate(reviews)]
    return {
        "schema": "vnext-t1-software-acceptance-verification-r1",
        "verified": True,
        "manifest_path": str(path.resolve()),
        "manifest_bytes": len(raw),
        "manifest_sha256": actual_sha,
        "repository_head": EXPECTED_HEAD,
        "sources": verified_sources,
        "protocol": verified_protocol,
        "coverage": coverage,
        "primary": primary,
        "fresh_replay": replay,
        "v1_source_carrier": {
            "primary": primary_v1_carrier,
            "fresh_replay": replay_v1_carrier,
        },
        "independent_reviews": verified_reviews,
        "actual_model_attestation": "unavailable",
        "candidate_specific": False,
    }


def verify_manifest(
        path: Path, expected_raw_sha256: str, *,
        historical_reader_module: Any = None,
        historical_index_path: Any = None,
        historical_index_sha256: Any = None,
        historical_archive_path: Any = None,
        frozen_snapshot: Any = None,
        expected_snapshot_id: Any = None,
        expected_manifest_sha256: Any = None,
        historical_archive_logical_path: str =
            "historical_archives/t1_precleanup.zip") -> dict[str, Any]:
    formal_env_names = (
        "FUSION_T2_FROZEN_SNAPSHOT_ID",
        "FUSION_T2_FROZEN_MANIFEST_SHA256",
        "FUSION_T2_FROZEN_PROTOCOL_SHA256",
        "FUSION_T2_FROZEN_PROTOCOL_PATH",
    )
    formal_env_present = [name in os.environ for name in formal_env_names]
    if any(formal_env_present):
        if not all(formal_env_present):
            raise ValueError("formal T2 frozen environment pins are incomplete")
        formal_env = [os.environ[name] for name in formal_env_names]
        if any(type(value) is not str or not value for value in formal_env) or \
                any(not HEX64.fullmatch(value.lower()) for value in formal_env[:3]):
            raise ValueError("formal T2 frozen environment pins are malformed")
        if frozen_snapshot is None or historical_reader_module is None or \
                historical_index_path is None or historical_index_sha256 is None or \
                type(expected_snapshot_id) is not str or \
                type(expected_manifest_sha256) is not str:
            raise ValueError("formal T2 verification requires complete frozen snapshot inputs")
        if expected_snapshot_id.lower() != formal_env[0].lower() or \
                expected_manifest_sha256.lower() != formal_env[1].lower():
            raise ValueError("formal T2 frozen environment identity mismatch")
        _verify_formal_frozen_protocol(
            frozen_snapshot, formal_env[3], formal_env[2],
            expected_snapshot_id.lower(), expected_manifest_sha256.lower())
    session = _T1HistoricalArchiveSession(
        historical_reader_module, historical_index_path,
        historical_index_sha256, historical_archive_path,
        frozen_snapshot=frozen_snapshot,
        expected_snapshot_id=expected_snapshot_id,
        expected_manifest_sha256=expected_manifest_sha256,
        historical_archive_logical_path=historical_archive_logical_path)
    token = _ACTIVE_T1_HISTORICAL_SESSION.set(session)
    try:
        with session:
            if session.frozen:
                session._open()
            return _verify_manifest_active(path, expected_raw_sha256)
    finally:
        _ACTIVE_T1_HISTORICAL_SESSION.reset(token)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()
    result = verify_manifest(Path(args.manifest).resolve(), args.expected_sha256)
    encoded = json.dumps(result, sort_keys=True, separators=(",", ":"))
    if args.output:
        output = Path(args.output).resolve()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(encoded + "\n", encoding="utf-8")
    print(encoded)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
