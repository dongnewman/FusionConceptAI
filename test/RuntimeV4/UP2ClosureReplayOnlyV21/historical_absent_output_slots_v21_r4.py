"""Pinned evidence for four historical output paths that were never created.

This module authorizes only the V6, V9, V12, and V13 output leaves below. It is
not an extension of V21's V16 ``expected_absent`` map, and it never creates or
pretends that a path exists. The runtime resolver returns the real workspace
path only after rechecking the frozen source evidence and both physical roots.
"""
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import stat
import zipfile
import zlib
from collections import defaultdict
from collections.abc import Mapping
from dataclasses import dataclass
from typing import Any


RECEIPT_KEY = "r4_historical_absent_output_slots"
RECEIPT_SCHEMA = "mms-v21-r4-historical-absent-output-slots-v1"
V9_RAW_SIDECAR_KEY = "r4_v9_static_raw_output_sidecar"
V9_RAW_SIDECAR_SCHEMA = "mms-v21-r4-v9-static-raw-output-sidecar-v1"
R3_PROTOCOL_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/replay_protocol_v21_r3.json"
R3_PROTOCOL_BYTES = 989_227
R3_PROTOCOL_SHA256 = "1688c51f96cf87ebaec3df75409954f21ac11ca22ecc589ae72634f69c402119"
HELPER_REL = "test/RuntimeV4/UP2ClosureReplayOnlyV21/historical_absent_output_slots_v21_r4.py"
ARCHIVE_PATH = (
    r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926"
    r"\precleanup_docs_runs_tmp.zip"
)
ARCHIVE_BYTES = 472_888_641
ARCHIVE_SHA256 = "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7"
R3_MIRROR_ROOT = (
    r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926"
    r"\up2_replay_v21_r3\archive_mirror"
)
R2_MIRROR_ROOT = (
    r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926"
    r"\up2_replay_v21_r2\archive_mirror"
)

_MAP_COUNTS = {
    "entries": 613,
    "referenced_paths": 645,
    "directory_prefixes": 31,
    "expected_absent": 1,
    "restored_entries": 0,
    "restored_directories": 0,
}
_ZIP_ENTRY_COUNT = 23_151
_ZIP_DIRECTORY_ENTRY_COUNT = 0
_WINDOWS_NAME_COLLISION_GROUPS = 0
_MAP_TABLES = tuple(_MAP_COUNTS)


@dataclass(frozen=True, slots=True)
class _EvidenceRef:
    role: str
    path: str
    byte_count: int
    sha256: str

    def as_receipt(self) -> dict[str, object]:
        return {"role": self.role, "path": self.path, "bytes": self.byte_count,
                "sha256": self.sha256}


@dataclass(frozen=True, slots=True)
class _SlotSpec:
    slot_id: str
    logical_path: str
    parent_version: int
    evidence: tuple[_EvidenceRef, ...]


_A = "docs/implementation/UP2-04-CLOSURE-REPAIR-PREC/archive/"
V9_PROTOCOL_REF = _EvidenceRef(
    "v9_parent_protocol",
    _A + "replay_only_continuation_r9/replay_protocol_v9.json",
    102_476,
    "37ecd51c875dbd71461c3ef71900c66cd30ae6a14a04e3a3e795e4bef8cb56dd",
)
V9_STATIC_RECEIPT_REF = _EvidenceRef(
    "v9_static_receipt",
    _A + "replay_only_continuation_r9/static_contract_check_v9_r1/receipt.json",
    2_135,
    "36de483509879e3f0ce164783895b64fbaefa4def319d7b7be507c4a222e5cf2",
)
V9_STATIC_OUTPUT_PARENT = _A + "replay_only_continuation_r9/static_contract_check_v9_r1"
_V9_RAW_OUTPUT_SPECS = (
    ("exit_code.txt", 2, "9a271f2a916b0b6ee6cecb2426f0b3206ef074578be55d9bc94f6f3fe3ab86aa"),
    ("stderr.raw", 1_955, "d23970e5b2b2dbf3774419757dd46382090fd1dcf3f4c808566202a210c62acd"),
    ("stdout.raw", 0, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
)
_SLOTS = (
    _SlotSpec(
        "v6-r6-runtime-replay",
        _A + "replay_only_continuation_r6/runtime_replay_r6",
        6,
        (
            _EvidenceRef("parent_protocol", _A + "replay_only_continuation_r6/replay_protocol_v6.json", 73040,
                         "9d28384297942eb3cec2fd788e88ac17fb1868e25b55fc7dbe85d3c97d79fca9"),
            _EvidenceRef("root_grant", _A + "root_replay_only_v6_grant_20260923/grant.json", 935,
                         "b621f9a7d0bfc46ce1923e174d327ac66010ae8c912f37d93b923f107828e517"),
            _EvidenceRef("pre_output_observation", _A + "root_replay_only_v6_grant_20260923/observation.json", 1443,
                         "d2ccf4d26d9fbfaaac7335c2e02f79b8b9b047690c0bc814eb1bd528e936e699"),
        ),
    ),
    _SlotSpec(
        "v9-r9-runtime-replay",
        _A + "replay_only_continuation_r9/runtime_replay_r9",
        9,
        (
            _EvidenceRef("parent_protocol", _A + "replay_only_continuation_r9/replay_protocol_v9.json", 102476,
                         "37ecd51c875dbd71461c3ef71900c66cd30ae6a14a04e3a3e795e4bef8cb56dd"),
            _EvidenceRef("static_receipt", _A + "replay_only_continuation_r9/static_contract_check_v9_r1/receipt.json", 2135,
                         "36de483509879e3f0ce164783895b64fbaefa4def319d7b7be507c4a222e5cf2"),
            _EvidenceRef("independent_reviewer_receipt", _A + "independent_replay_v9_static_review_20260923/review_receipt.json", 1976,
                         "d001a753de30063b0d51441ea19380a57712d2334304645a0034a4530e5b81ba"),
            _EvidenceRef("root_no_go_decision", _A + "root_replay_v9_no_go_20260923/decision.json", 1603,
                         "22c1b77fac4ea1173b182bc1a32b3e866864f81f7f3ee0f23a642c0b8882b2fc"),
        ),
    ),
    _SlotSpec(
        "v12-r12-runtime-replay",
        _A + "replay_only_continuation_r12/runtime_replay_r12",
        12,
        (
            _EvidenceRef("parent_protocol", _A + "replay_only_continuation_r12/replay_protocol_v12.json", 139531,
                         "89859da6beb8dc17d290adce51a76b0093f5a0da42598ea007c957d89ac504c1"),
            _EvidenceRef("static_receipt", _A + "replay_only_continuation_r12/static_contract_check_v12_r1/receipt.json", 2478,
                         "39b49dffd65c73befc09a3f70f91c708e0ed2e8f43ee4192ffb8480b84830211"),
            _EvidenceRef("independent_no_go_manifest", _A + "independent_replay_v12_static_review_r1_20260924/manifest.json", 3794,
                         "d54388d39239d86513dfe2623c7ade2aa8c06fcb6528e536d0faafde29682ac2"),
        ),
    ),
    _SlotSpec(
        "v13-r13-runtime-replay",
        _A + "replay_only_continuation_r13/runtime_replay_r13",
        13,
        (
            _EvidenceRef("parent_protocol", _A + "replay_only_continuation_r13/replay_protocol_v13.json", 154378,
                         "49af413f03d106d94fd830a98d489adf876d9d039f590e9115b4f0b9ec41b2ee"),
            _EvidenceRef("static_receipt", _A + "replay_only_continuation_r13/static_contract_check_v13_r1/receipt.json", 2759,
                         "0abe14b104fb862c520258443b17f8b7ba54c89212165af91c98dac32b78f19c"),
            _EvidenceRef("root_no_go_decision", _A + "root_mms_v13_runtime_no_go_20260924/decision.md", 2316,
                         "70a748dc3081c48842039dfd2d4483c2eaedd34cd1660172e50fcac2003b7b3e"),
        ),
    ),
)
_SLOT_BY_PATH = {slot.logical_path: slot for slot in _SLOTS}


@dataclass(frozen=True, slots=True)
class HistoricalAbsentOutputSlotsV21R4:
    """Immutable JSON receipt wrapper; runtime consumers still validate the mapping."""

    _canonical_json: str

    def as_receipt(self) -> dict[str, object]:
        value = json.loads(self._canonical_json)
        if not isinstance(value, dict):
            raise ValueError("historical absence receipt is not a JSON object")
        return value


@dataclass(frozen=True, slots=True)
class V9StaticRawOutputSidecarV21R4:
    """Immutable receipt wrapper for three ZIP-bound V9 static raw outputs."""

    _canonical_json: str

    def as_receipt(self) -> dict[str, object]:
        value = json.loads(self._canonical_json)
        if not isinstance(value, dict):
            raise ValueError("V9 static raw sidecar receipt is not a JSON object")
        return value


def _canonical_json_bytes(value: object) -> bytes:
    try:
        return json.dumps(value, sort_keys=True, separators=(",", ":"),
                          ensure_ascii=False, allow_nan=False).encode("utf-8")
    except (TypeError, ValueError) as exc:
        raise ValueError("historical absence evidence is not canonical JSON data") from exc


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _same_windows_path(left: os.PathLike[str] | str, right: os.PathLike[str] | str) -> bool:
    return os.path.normcase(os.path.normpath(os.path.abspath(os.fspath(left)))) == \
        os.path.normcase(os.path.normpath(os.path.abspath(os.fspath(right))))


def _assert_no_reparse_components(path: pathlib.Path) -> None:
    """Inspect with lstat before any resolution can hide a symlink/junction."""
    absolute = pathlib.Path(os.path.abspath(os.fspath(path)))
    current = pathlib.Path(absolute.anchor)
    parts = absolute.parts[1:] if absolute.anchor else absolute.parts
    for index, part in enumerate(parts):
        current = current / part
        try:
            metadata = os.lstat(current)
        except FileNotFoundError:
            return
        if stat.S_ISLNK(metadata.st_mode) or (getattr(metadata, "st_file_attributes", 0) & 0x400):
            raise ValueError(f"historical absence path contains a symlink/reparse point: {current}")
        if index < len(parts) - 1 and not stat.S_ISDIR(metadata.st_mode):
            raise ValueError(f"historical absence path has a non-directory ancestor: {current}")


def _assert_directory_if_present(path: pathlib.Path) -> bool:
    _assert_no_reparse_components(path)
    try:
        metadata = os.lstat(path)
    except FileNotFoundError:
        return False
    if not stat.S_ISDIR(metadata.st_mode):
        raise ValueError(f"historical mirror root is not a directory: {path}")
    return True


def _safe_target(root: pathlib.Path, logical_path: str) -> pathlib.Path:
    parts = logical_path.split("/")
    if not parts or parts[0] != "docs" or any(part in ("", ".", "..") for part in parts):
        raise ValueError("historical absence target is not a strict docs-relative path")
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    target = root_abs.joinpath(*parts)
    try:
        common = os.path.commonpath((os.path.normcase(str(root_abs)), os.path.normcase(str(target))))
    except ValueError as exc:
        raise ValueError("historical absence target is on a different volume") from exc
    if os.path.normcase(common) != os.path.normcase(str(root_abs)):
        raise ValueError("historical absence target escapes the workspace root")
    return target


def _require_absent(root: pathlib.Path, logical_path: str, label: str) -> None:
    target = _safe_target(root, logical_path)
    _assert_no_reparse_components(target)
    try:
        os.lstat(target)
    except FileNotFoundError:
        return
    raise ValueError(f"historical output target is present in {label}: {target}")


def _strict_docs_key(value: object) -> str:
    if type(value) is not str or not value or "\\" in value:
        raise ValueError("historical input map contains a noncanonical docs path")
    parts = value.split("/")
    if parts[0] != "docs" or any(part in ("", ".", "..") for part in parts):
        raise ValueError("historical input map contains an unsafe docs path")
    return "/".join(part.rstrip(" .").casefold() for part in parts)


def _member_key(value: str) -> str | None:
    """Normalize separators, dot segments, Windows trailing aliases and case."""
    parts: list[str] = []
    for part in value.replace("\\", "/").split("/"):
        if part in ("", "."):
            continue
        if part == "..":
            if not parts:
                return None
            parts.pop()
            continue
        component = part.rstrip(" .")
        if not component:
            return None
        parts.append(component)
    if not parts:
        return None
    return "/".join(parts)


def _member_matches_slot(member_name: str, logical_path: str) -> tuple[bool, bool, bool]:
    normalized = _member_key(member_name)
    if normalized is None:
        return False, False, False
    folded = normalized.casefold()
    target = logical_path.casefold()
    exact = folded == target
    descendant = folded.startswith(target + "/")
    if not (exact or descendant):
        return False, False, False
    expected_spelling = logical_path if exact else logical_path + normalized[len(logical_path):]
    raw_spelling = member_name.replace("\\", "/").rstrip("/")
    alias = normalized != expected_spelling or raw_spelling != normalized
    return exact, descendant, alias


def _archive_inventory(path: pathlib.Path) -> tuple[list[zipfile.ZipInfo], int, int]:
    with zipfile.ZipFile(path, "r") as archive:
        infos = archive.infolist()
    groups: dict[str, list[str]] = defaultdict(list)
    for info in infos:
        normalized = _member_key(info.filename)
        if normalized is not None:
            groups[normalized.casefold()].append(info.filename)
    collisions = sum(1 for names in groups.values() if len(names) > 1)
    directories = sum(1 for info in infos if info.is_dir())
    if len(infos) != _ZIP_ENTRY_COUNT or directories != _ZIP_DIRECTORY_ENTRY_COUNT or \
            collisions != _WINDOWS_NAME_COLLISION_GROUPS:
        raise ValueError("frozen ZIP central-directory inventory changed")
    return infos, directories, collisions


def _prefix_counts(infos: list[zipfile.ZipInfo], logical_path: str) -> dict[str, int]:
    exact = descendants = aliases = 0
    for info in infos:
        is_exact, is_descendant, is_alias = _member_matches_slot(info.filename, logical_path)
        exact += int(is_exact)
        descendants += int(is_descendant)
        aliases += int(is_alias)
    total = exact + descendants
    if total or aliases:
        raise ValueError(f"frozen ZIP contains the supposedly absent output prefix: {logical_path}")
    return {"exact_member_count_including_directories": exact,
            "descendant_member_count_including_directories": descendants,
            "windows_alias_member_count": aliases,
            "total_prefix_member_count": total}


def _map_rows(contract: Mapping[str, Any], table: str) -> list[object]:
    raw = contract.get(table)
    if not isinstance(raw, list):
        raise ValueError(f"archived-input map table {table!r} is missing or malformed")
    return raw


def _map_summary(contract: Mapping[str, Any]) -> dict[str, int]:
    summary: dict[str, int] = {}
    for table, expected in _MAP_COUNTS.items():
        rows = _map_rows(contract, table)
        if len(rows) != expected:
            raise ValueError(f"frozen archived-input map count changed for {table}")
        summary[table] = len(rows)
    return summary


def _all_mapped_paths(contract: Mapping[str, Any]) -> list[str]:
    paths: list[str] = []
    for table in _MAP_TABLES:
        for row in _map_rows(contract, table):
            if not isinstance(row, Mapping) or type(row.get("logical_path")) is not str:
                raise ValueError(f"archived-input map row in {table} lacks a logical_path")
            _strict_docs_key(row["logical_path"])
            paths.append(row["logical_path"])
    return paths


def _check_no_map_overlap(contract: Mapping[str, Any], slot: _SlotSpec) -> int:
    target = _strict_docs_key(slot.logical_path)
    count = 0
    for logical in _all_mapped_paths(contract):
        key = _strict_docs_key(logical)
        if key == target or key.startswith(target + "/") or target.startswith(key + "/"):
            count += 1
    if count:
        raise ValueError(f"historical output slot overlaps an archived-input map: {slot.slot_id}")
    return count


def _protocol_archive_source(protocol: Mapping[str, Any], expected_stage: str | None = None) -> Mapping[str, Any]:
    if protocol.get("schema") != "mms-replay-only-continuation-protocol-v21" or \
            protocol.get("version") != 21:
        raise ValueError("historical absence source is not a V21 continuation protocol")
    contract = protocol.get("archived_input_source")
    if not isinstance(contract, Mapping) or contract.get("schema") != "mms-v21-archived-input-map-v1":
        raise ValueError("V21 archived-input source is missing or unsupported")
    archive_path = contract.get("archive_path")
    if type(archive_path) is not str or not _same_windows_path(archive_path, ARCHIVE_PATH) or \
            contract.get("archive_sha256") != ARCHIVE_SHA256:
        raise ValueError("V21 protocol archive identity differs from the frozen source")
    stage = contract.get("staging_root")
    if type(stage) is not str or not os.path.isabs(stage):
        raise ValueError("V21 protocol staging root is malformed")
    if expected_stage is not None and not _same_windows_path(stage, expected_stage):
        raise ValueError("V21 protocol staging root differs from the actual resolver root")
    _map_summary(contract)
    return contract


def _iter_mappings(value: object):
    if isinstance(value, Mapping):
        yield value
        for child in value.values():
            yield from _iter_mappings(child)
    elif isinstance(value, list):
        for child in value:
            yield from _iter_mappings(child)


_REFERENCE_FIELD_PAIRS = (
    ("path", "sha256"), ("path", "sha"), ("receipt_path", "receipt_sha256"),
    ("report_path", "report_sha256"), ("manifest_path", "manifest_sha256"),
    ("commands_path", "commands_sha256"), ("observation_path", "observation_sha256"),
    ("grant_path", "grant_sha256"), ("protocol_path", "protocol_sha256"),
    ("decision_path", "decision_sha256"), ("checksums_path", "checksums_sha256"),
    ("input_inventory_path", "input_inventory_sha256"),
)


def _check_protocol_binds_evidence(protocol: Mapping[str, Any]) -> None:
    mappings = tuple(_iter_mappings(protocol))
    for slot in _SLOTS:
        for ref in slot.evidence:
            bound = any(node.get(path_key) == ref.path and node.get(hash_key) == ref.sha256
                        for node in mappings for path_key, hash_key in _REFERENCE_FIELD_PAIRS)
            if not bound:
                raise ValueError(f"protocol does not bind frozen evidence {ref.role}: {ref.path}")


def _load_json(raw: bytes, role: str) -> Mapping[str, Any]:
    try:
        value = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"historical evidence is not valid UTF-8 JSON: {role}") from exc
    if not isinstance(value, Mapping):
        raise ValueError(f"historical evidence JSON root is not an object: {role}")
    return value


def _verify_slot_documents(slot: _SlotSpec, raw_by_role: Mapping[str, bytes]) -> None:
    docs: dict[str, Mapping[str, Any]] = {}
    for ref in slot.evidence:
        if ref.path.endswith(".json"):
            docs[ref.role] = _load_json(raw_by_role[ref.role], ref.role)
    parent = docs.get("parent_protocol")
    expected_schema = f"mms-replay-only-continuation-protocol-v{slot.parent_version}"
    if parent is None or parent.get("schema") != expected_schema or \
            parent.get("version") != slot.parent_version or \
            parent.get("classification") != "test_only_continuation" or \
            parent.get("runtime_grant") is not False or parent.get("output_leaf") != slot.logical_path:
        raise ValueError(f"parent protocol does not bind the exact absent output slot: {slot.slot_id}")
    if slot.parent_version == 6:
        grant = docs["root_grant"]
        obs = docs["pre_output_observation"]
        if grant.get("schema") != "root-serial-slot-grant-v1" or \
                grant.get("classification") != "test_only_continuation" or \
                grant.get("protocol_path") != next(r.path for r in slot.evidence if r.role == "parent_protocol") or \
                grant.get("protocol_sha256") != next(r.sha256 for r in slot.evidence if r.role == "parent_protocol") or \
                grant.get("output_leaf") != slot.logical_path:
            raise ValueError("V6 grant is not bound to its exact protocol/output")
        if obs.get("schema") != "root-mms-v6-preflight-failure-observation-v1" or \
                obs.get("output_leaf_exists") is not False or obs.get("julia_started") is not False or \
                obs.get("shell_exit_code") != 1 or slot.logical_path not in str(obs.get("exact_argv", "")):
            raise ValueError("V6 pre-output observation does not prove the output stayed absent")
        if "--protocol-sha256 " + grant["protocol_sha256"] not in str(obs.get("exact_argv", "")):
            raise ValueError("V6 observation argv does not bind the frozen protocol hash")
    elif slot.parent_version == 9:
        receipt = docs["static_receipt"]
        decision = docs["root_no_go_decision"]
        protocol_ref = next(r for r in slot.evidence if r.role == "parent_protocol")
        receipt_ref = next(r for r in slot.evidence if r.role == "static_receipt")
        if receipt.get("schema") != "mms-replay-v9-static-contract-receipt-v1" or \
                receipt.get("classification") != "static_contract_pass_test_only" or \
                receipt.get("julia_started") is not False or \
                receipt.get("runtime_output_leaf_created") is not False or \
                receipt.get("protocol") != {"bytes": protocol_ref.byte_count, "path": protocol_ref.path,
                                             "sha256": protocol_ref.sha256} or \
                receipt.get("exit_code") != 0 or receipt.get("test_count") != 11:
            raise ValueError("V9 static receipt does not bind a no-runtime output absence")
        if decision.get("schema") != "root-mms-replay-v9-no-go-v1" or \
                decision.get("decision") != "NO_GO_for_Julia_replay" or \
                decision.get("candidate_protocol_sha256") != protocol_ref.sha256 or \
                decision.get("producer_static_receipt_sha256") != receipt_ref.sha256 or \
                decision.get("actual_v9_runtime_outcome") != "not_executed":
            raise ValueError("V9 root decision does not bind the pinned absent-output lineage")
        reviewer = docs["independent_reviewer_receipt"]
        if reviewer.get("classification") != "NO-GO" or \
                reviewer.get("runtime_output_leaf_exists") is not False or \
                reviewer.get("runtime_launch_authorized") is not False or \
                reviewer.get("frozen_hashes", {}).get("protocol") != protocol_ref.sha256:
            raise ValueError("V9 independent review does not confirm the output leaf remained absent")
    elif slot.parent_version == 12:
        receipt = docs["static_receipt"]
        protocol_ref = next(r for r in slot.evidence if r.role == "parent_protocol")
        if receipt.get("schema") != "mms-replay-only-v12-static-receipt-v1" or \
                receipt.get("classification") != "static_contract_pass_test_only" or \
                receipt.get("julia_started") is not False or receipt.get("solver_started") is not False or \
                receipt.get("pre_output_contract_verified") is not True or \
                receipt.get("output_leaf_absent") is not True or receipt.get("output_leaf") != slot.logical_path or \
                receipt.get("protocol") != {"path": protocol_ref.path, "bytes": protocol_ref.byte_count,
                                             "sha256": protocol_ref.sha256}:
            raise ValueError("V12 static receipt does not prove the exact output leaf stayed absent")
        manifest = docs.get("independent_no_go_manifest")
        protocol_ref = next(r for r in slot.evidence if r.role == "parent_protocol")
        scope_check = manifest.get("scope_check") if manifest is not None else None
        if manifest is None or manifest.get("schema") != "independent-evidence-review-manifest-v1" or \
                manifest.get("classification") != "NO-GO" or not isinstance(scope_check, Mapping) or \
                scope_check.get("evidence_only") is not True or scope_check.get("executable_count") != 0 or \
                scope_check.get("executable_files") != [] or \
                manifest.get("protocol") != {"path": protocol_ref.path, "bytes": protocol_ref.byte_count,
                                              "sha256": protocol_ref.sha256}:
            raise ValueError("V12 independent evidence manifest is not a bounded no-go review")
    elif slot.parent_version == 13:
        receipt = docs["static_receipt"]
        protocol_ref = next(r for r in slot.evidence if r.role == "parent_protocol")
        if receipt.get("schema") != "up2-v13-static-evidence-receipt-v1" or \
                receipt.get("classification") != "STATIC_TESTS_PASS_RUNTIME_NOT_GRANTED" or \
                receipt.get("protocol") != {"path": protocol_ref.path, "bytes": protocol_ref.byte_count,
                                             "sha256": protocol_ref.sha256, "version": 13,
                                             "runtime_grant": False} or \
                receipt.get("runtime_boundary", {}).get("julia_started") is not False or \
                receipt.get("runtime_boundary", {}).get("producer_started") is not False or \
                receipt.get("runtime_boundary", {}).get("consumer_started") is not False or \
                receipt.get("runtime_boundary", {}).get("v13_output_leaf_absent") is not True:
            raise ValueError("V13 static receipt does not prove runtime was not granted and output stayed absent")
        decision = raw_by_role["root_no_go_decision"].decode("utf-8")
        if "NO-GO for the two-process Julia replay" not in decision or \
                "V13 output leaf is absent." not in decision or protocol_ref.sha256 not in decision:
            raise ValueError("V13 root decision does not bind the exact absent output/protocol")


def _read_archive_evidence(archive_path: pathlib.Path, infos: list[zipfile.ZipInfo]) -> dict[str, dict[str, bytes]]:
    exact: dict[str, zipfile.ZipInfo] = {}
    for info in infos:
        exact.setdefault(info.filename, info)
    evidence: dict[str, dict[str, bytes]] = {}
    with zipfile.ZipFile(archive_path, "r") as archive:
        for slot in _SLOTS:
            role_bytes: dict[str, bytes] = {}
            for ref in slot.evidence:
                info = exact.get(ref.path)
                if info is None or info.is_dir() or info.file_size != ref.byte_count:
                    raise ValueError(f"pinned archive evidence is missing or has wrong size: {ref.path}")
                raw = archive.read(info)
                if _sha256_bytes(raw) != ref.sha256:
                    raise ValueError(f"pinned archive evidence hash changed: {ref.path}")
                role_bytes[ref.role] = raw
            evidence[slot.slot_id] = role_bytes
    return evidence


def _verify_evidence_map(contract: Mapping[str, Any], refs: tuple[_EvidenceRef, ...]) -> None:
    entries = _map_rows(contract, "entries")
    by_path: dict[str, Mapping[str, Any]] = {}
    for row in entries:
        if not isinstance(row, Mapping) or type(row.get("logical_path")) is not str:
            raise ValueError("archived-input file map row is malformed")
        key = _strict_docs_key(row["logical_path"])
        if key in by_path:
            raise ValueError("archived-input map has a Windows case alias")
        by_path[key] = row
    for ref in refs:
        row = by_path.get(_strict_docs_key(ref.path))
        if row is None or row.get("logical_path") != ref.path or row.get("archive_member") != ref.path or \
                row.get("bytes") != ref.byte_count or row.get("sha256") != ref.sha256 or \
                row.get("archive_sha256") != ARCHIVE_SHA256:
            raise ValueError(f"R3/R4 archive map does not bind pinned historical evidence: {ref.path}")
    referenced = _map_rows(contract, "referenced_paths")
    classifications: dict[str, set[str]] = defaultdict(set)
    for row in referenced:
        if not isinstance(row, Mapping):
            raise ValueError("referenced path row is malformed")
        logical = row.get("logical_path")
        classifications[_strict_docs_key(logical)].add(str(row.get("classification")))
    for ref in refs:
        kinds = classifications.get(_strict_docs_key(ref.path), set())
        if kinds != {"archive_file"}:
            raise ValueError(f"referenced-path table does not uniquely classify evidence: {ref.path}")


def _load_source_protocol(root: pathlib.Path, requested_path: pathlib.Path) -> tuple[Mapping[str, Any], bytes]:
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    expected_path = root_abs.joinpath(*R3_PROTOCOL_REL.split("/"))
    if not _same_windows_path(requested_path, expected_path):
        raise ValueError("historical absence builder accepts only the frozen R3 protocol path")
    _assert_no_reparse_components(expected_path)
    metadata = os.lstat(expected_path)
    if not stat.S_ISREG(metadata.st_mode):
        raise ValueError("frozen R3 protocol is not a regular file")
    raw = expected_path.read_bytes()
    if len(raw) != R3_PROTOCOL_BYTES or _sha256_bytes(raw) != R3_PROTOCOL_SHA256:
        raise ValueError("frozen R3 source protocol bytes changed")
    protocol = _load_json(raw, "R3 source protocol")
    return protocol, raw


def _check_archive_identity(protocol: Mapping[str, Any]) -> tuple[Mapping[str, Any], pathlib.Path]:
    contract = _protocol_archive_source(protocol)
    archive_text = contract.get("archive_path")
    if type(archive_text) is not str or not _same_windows_path(archive_text, ARCHIVE_PATH):
        raise ValueError("historical evidence archive path differs from the frozen archive")
    archive_path = pathlib.Path(ARCHIVE_PATH)
    _assert_no_reparse_components(archive_path)
    metadata = os.lstat(archive_path)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != ARCHIVE_BYTES or \
            _sha256_file(archive_path) != ARCHIVE_SHA256:
        raise ValueError("historical evidence archive bytes differ from the frozen ZIP")
    return contract, archive_path


def _build_receipt(root: pathlib.Path, source_protocol_path: pathlib.Path,
                   source_mirror_root: pathlib.Path) -> dict[str, object]:
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    _assert_no_reparse_components(root_abs)
    if not root_abs.is_dir():
        raise ValueError("historical absence workspace root is not a directory")
    source_protocol, _ = _load_source_protocol(root_abs, source_protocol_path)
    contract, archive_path = _check_archive_identity(source_protocol)
    stage_text = contract.get("staging_root")
    if type(stage_text) is not str or not _same_windows_path(source_mirror_root, R3_MIRROR_ROOT) or \
            not _same_windows_path(stage_text, R3_MIRROR_ROOT):
        raise ValueError("builder must use the source protocol's exact R3 mirror")
    source_mirror = pathlib.Path(R3_MIRROR_ROOT)
    _assert_no_reparse_components(source_mirror)
    if source_mirror.exists() and not source_mirror.is_dir():
        raise ValueError("frozen R3 mirror root exists but is not a directory")
    if _map_summary(contract) != _MAP_COUNTS:
        raise ValueError("frozen R3 map summary changed")
    _check_protocol_binds_evidence(source_protocol)

    refs = tuple(ref for slot in _SLOTS for ref in slot.evidence)
    _verify_evidence_map(contract, refs)
    infos, directory_count, collision_groups = _archive_inventory(archive_path)
    evidence = _read_archive_evidence(archive_path, infos)
    slots_receipt: list[dict[str, object]] = []
    for slot in _SLOTS:
        raw_by_role = evidence[slot.slot_id]
        _verify_slot_documents(slot, raw_by_role)
        _require_absent(root_abs, slot.logical_path, "workspace")
        _require_absent(source_mirror, slot.logical_path, "R3 archive mirror")
        prefix = _prefix_counts(infos, slot.logical_path)
        overlap_count = _check_no_map_overlap(contract, slot)
        slots_receipt.append({
            "slot_id": slot.slot_id,
            "logical_path": slot.logical_path,
            "parent_version": slot.parent_version,
            "evidence": [ref.as_receipt() for ref in slot.evidence],
            "archive_prefix_inventory": prefix,
            "r3_map_overlap_count": overlap_count,
            "workspace_target_absent_at_build": True,
            "r3_mirror_target_absent_at_build": True,
        })
    return {
        "schema": RECEIPT_SCHEMA,
        "classification": "source_bound_historical_absence_test_only",
        "credit": "none",
        "source_protocol": {"path": R3_PROTOCOL_REL, "bytes": R3_PROTOCOL_BYTES,
                            "sha256": R3_PROTOCOL_SHA256},
        "archive": {"path": ARCHIVE_PATH, "bytes": ARCHIVE_BYTES, "sha256": ARCHIVE_SHA256,
                    "member_count_including_directories": len(infos),
                    "directory_member_count": directory_count,
                    "windows_name_collision_groups": collision_groups},
        "source_mirror_root": R3_MIRROR_ROOT,
        "source_map_summary": _map_summary(contract),
        "slots": slots_receipt,
    }


def build_historical_absent_output_slots_v21_r4(
    root: pathlib.Path,
    source_protocol_path: pathlib.Path,
    source_mirror_root: pathlib.Path,
) -> HistoricalAbsentOutputSlotsV21R4:
    """Build a fixed four-slot proof from the byte-pinned original R3 inputs."""
    receipt = _build_receipt(pathlib.Path(root), pathlib.Path(source_protocol_path),
                             pathlib.Path(source_mirror_root))
    return HistoricalAbsentOutputSlotsV21R4(_canonical_json_bytes(receipt).decode("utf-8"))


def resolve_historical_absent_output_slot_v21_r4(
    root: pathlib.Path,
    current_protocol: Mapping[str, Any],
    actual_stage_root: pathlib.Path | None,
    logical_path: object,
    proof: Mapping[str, Any] | None = None,
) -> pathlib.Path | None:
    """Resolve an exact authorized absent slot to its real workspace path.

    All non-slot paths return ``None`` untouched so the frozen controller's
    original ``checked_path`` handles them. No path normalization occurs before
    this exact membership check.
    """
    if type(logical_path) is not str or logical_path not in _SLOT_BY_PATH:
        return None
    slot = _SLOT_BY_PATH[logical_path]
    if actual_stage_root is None:
        raise ValueError("an exact historical output slot requires the initialized original resolver")
    if not isinstance(current_protocol, Mapping):
        raise ValueError("current protocol is not a mapping")
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    _assert_no_reparse_components(root_abs)
    if not root_abs.is_dir():
        raise ValueError("current workspace root is not a directory")
    current_contract = _protocol_archive_source(current_protocol, os.fspath(actual_stage_root))
    actual_stage = pathlib.Path(os.path.abspath(os.fspath(actual_stage_root)))
    _assert_no_reparse_components(actual_stage)
    if not actual_stage.is_dir():
        raise ValueError("actual archive resolver stage root is not a directory")
    docs_root = root_abs / "docs"
    if _paths_overlap(actual_stage, docs_root):
        raise ValueError("actual archive resolver stage root overlaps workspace docs")

    source_protocol_path = root_abs.joinpath(*R3_PROTOCOL_REL.split("/"))
    source_protocol, _ = _load_source_protocol(root_abs, source_protocol_path)
    source_contract = _protocol_archive_source(source_protocol)
    if any(_canonical_json_bytes(_map_rows(current_contract, table)) !=
           _canonical_json_bytes(_map_rows(source_contract, table)) for table in _MAP_TABLES):
        raise ValueError("current R4 archive-input maps differ from the frozen R3 source map")
    _check_protocol_binds_evidence(current_protocol)

    protocol_receipt = current_protocol.get(RECEIPT_KEY)
    if proof is None:
        proof = protocol_receipt if isinstance(protocol_receipt, Mapping) else None
    if not isinstance(proof, Mapping) or not isinstance(protocol_receipt, Mapping):
        raise ValueError("current protocol lacks its versioned source-bound absence receipt")
    if _canonical_json_bytes(proof) != _canonical_json_bytes(protocol_receipt):
        raise ValueError("supplied absence proof differs from the pinned protocol receipt")
    expected_receipt = _build_receipt(root_abs, source_protocol_path, pathlib.Path(R3_MIRROR_ROOT))
    if _canonical_json_bytes(proof) != _canonical_json_bytes(expected_receipt):
        raise ValueError("absence receipt differs from the exact source-bound four-slot proof")

    # The current R4 mirror is obtained only from the original resolver and must
    # equal the protocol's own staging_root. The R3 proof above is independent.
    _require_absent(root_abs, slot.logical_path, "workspace")
    _require_absent(actual_stage, slot.logical_path, "actual R4 resolver mirror")
    target = _safe_target(root_abs, slot.logical_path)
    _assert_no_reparse_components(target)
    return target


_VERIFIED_V9_SIDECAR_STAGES: set[tuple[str, str, str]] = set()


def _v9_raw_logical_path(name: str) -> str:
    return V9_STATIC_OUTPUT_PARENT + "/" + name


def _verify_v9_raw_receipt_documents(parent_raw: bytes, receipt_raw: bytes) -> None:
    parent = _load_json(parent_raw, "V9 parent protocol")
    receipt = _load_json(receipt_raw, "V9 static receipt")
    runtime_output_leaf = _SLOT_BY_PATH[_A + "replay_only_continuation_r9/runtime_replay_r9"].logical_path
    if parent.get("schema") != "mms-replay-only-continuation-protocol-v9" or \
            parent.get("version") != 9 or parent.get("classification") != "test_only_continuation" or \
            parent.get("runtime_grant") is not False or parent.get("output_leaf") != runtime_output_leaf:
        raise ValueError("V9 parent protocol is not the frozen test-only no-runtime input")
    if receipt.get("schema") != "mms-replay-v9-static-contract-receipt-v1" or \
            receipt.get("classification") != "static_contract_pass_test_only" or \
            receipt.get("julia_started") is not False or \
            receipt.get("runtime_output_leaf_created") is not False or \
            type(receipt.get("exit_code")) is not int or receipt.get("exit_code") != 0 or \
            type(receipt.get("test_count")) is not int or receipt.get("test_count") != 11 or \
            receipt.get("protocol") != {
                "bytes": V9_PROTOCOL_REF.byte_count,
                "path": V9_PROTOCOL_REF.path,
                "sha256": V9_PROTOCOL_REF.sha256,
            }:
        raise ValueError("V9 static receipt does not bind the pinned no-runtime parent protocol")
    raw_outputs = receipt.get("raw_outputs")
    expected_names = {name for name, _, _ in _V9_RAW_OUTPUT_SPECS}
    if not isinstance(raw_outputs, Mapping) or set(raw_outputs) != expected_names:
        raise ValueError("V9 static receipt raw-output rows differ from the fixed three-file sidecar")
    for name, byte_count, sha256 in _V9_RAW_OUTPUT_SPECS:
        row = raw_outputs.get(name)
        if not isinstance(row, Mapping) or type(row.get("bytes")) is not int or \
                row.get("bytes") != byte_count or row.get("sha256") != sha256:
            raise ValueError(f"V9 static receipt does not bind the exact raw output: {name}")


def _check_unmapped_v9_raw_path(contract: Mapping[str, Any], logical_path: str) -> int:
    target = _strict_docs_key(logical_path)
    overlaps = 0
    for mapped in _all_mapped_paths(contract):
        key = _strict_docs_key(mapped)
        # The mapped receipt's parent directory is intentionally shared. The
        # exact raw file and anything below a file-shaped target are forbidden.
        if key == target or key.startswith(target + "/"):
            overlaps += 1
    if overlaps:
        raise ValueError(f"V9 raw sidecar path overlaps the frozen 613/645/31 map: {logical_path}")
    return overlaps


def _read_v9_raw_archive_outputs(
    archive_path: pathlib.Path,
    infos: list[zipfile.ZipInfo],
    contract: Mapping[str, Any],
) -> tuple[dict[str, bytes], list[dict[str, object]]]:
    exact_by_name: dict[str, list[zipfile.ZipInfo]] = defaultdict(list)
    for info in infos:
        exact_by_name[info.filename].append(info)
    rows: list[dict[str, object]] = []
    raw_by_path: dict[str, bytes] = {}
    with zipfile.ZipFile(archive_path, "r") as archive:
        for name, expected_bytes, expected_sha256 in _V9_RAW_OUTPUT_SPECS:
            logical_path = _v9_raw_logical_path(name)
            target_key = _strict_docs_key(logical_path)
            exact = exact_by_name.get(logical_path, [])
            normalized_matches: list[zipfile.ZipInfo] = []
            for info in infos:
                normalized = _member_key(info.filename)
                if normalized is not None and normalized.casefold() == target_key:
                    normalized_matches.append(info)
            if len(exact) != 1 or len(normalized_matches) != 1 or exact[0] is not normalized_matches[0]:
                raise ValueError(f"V9 raw archive member is missing, duplicated, or aliased: {logical_path}")
            info = exact[0]
            if info.is_dir() or info.file_size != expected_bytes:
                raise ValueError(f"V9 raw archive member has the wrong type or size: {logical_path}")
            if _check_unmapped_v9_raw_path(contract, logical_path) != 0:
                raise ValueError(f"V9 raw output unexpectedly entered the original map: {logical_path}")
            digest = hashlib.sha256()
            crc = 0
            byte_count = 0
            chunks: list[bytes] = []
            # Reading to EOF makes zipfile verify the member CRC; the explicit
            # CRC and digest checks below also bind the exact decompressed bytes.
            with archive.open(info, "r") as stream:
                while True:
                    chunk = stream.read(64 * 1024)
                    if not chunk:
                        break
                    byte_count += len(chunk)
                    if byte_count > expected_bytes:
                        raise ValueError(f"V9 raw archive member exceeds its pinned size: {logical_path}")
                    digest.update(chunk)
                    crc = zlib.crc32(chunk, crc)
                    chunks.append(chunk)
            actual_crc = crc & 0xFFFFFFFF
            raw = b"".join(chunks)
            actual_sha256 = digest.hexdigest()
            if byte_count != expected_bytes or len(raw) != expected_bytes or \
                    actual_sha256 != expected_sha256 or actual_crc != info.CRC:
                raise ValueError(f"V9 raw archive member bytes, SHA-256, or CRC changed: {logical_path}")
            raw_by_path[logical_path] = raw
            rows.append({
                "logical_path": logical_path,
                "archive_member": info.filename,
                "bytes": expected_bytes,
                "sha256": expected_sha256,
                "zip_crc32": f"{actual_crc:08x}",
                "zip_exact_file_member_count": 1,
                "zip_windows_alias_member_count": 0,
                "r3_map_overlap_count": 0,
                "workspace_target_absent_at_build": True,
                "r3_mirror_target_absent_at_build": True,
            })
    return raw_by_path, rows


def _read_pinned_mirror_file(root: pathlib.Path, ref: _EvidenceRef, label: str) -> bytes:
    path = root.joinpath(*ref.path.split("/"))
    _assert_no_reparse_components(path)
    try:
        metadata = os.lstat(path)
    except FileNotFoundError as exc:
        raise ValueError(f"pinned {label} is missing from its original mirror: {ref.path}") from exc
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != ref.byte_count:
        raise ValueError(f"pinned {label} has the wrong type or size in its original mirror: {ref.path}")
    raw = path.read_bytes()
    if len(raw) != ref.byte_count or _sha256_bytes(raw) != ref.sha256:
        raise ValueError(f"pinned {label} bytes changed in its original mirror: {ref.path}")
    return raw


def _assert_archive_unchanged(path: pathlib.Path) -> None:
    _assert_no_reparse_components(path)
    metadata = os.lstat(path)
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != ARCHIVE_BYTES or \
            _sha256_file(path) != ARCHIVE_SHA256:
        raise ValueError("frozen source ZIP changed during the V9 raw-sidecar check")


def _build_v9_static_raw_sidecar_context(
    root: pathlib.Path,
    source_protocol_path: pathlib.Path,
    source_mirror_root: pathlib.Path,
) -> tuple[dict[str, object], dict[str, bytes]]:
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    _assert_no_reparse_components(root_abs)
    if not root_abs.is_dir():
        raise ValueError("V9 raw-sidecar workspace root is not a directory")
    source_protocol, source_protocol_raw = _load_source_protocol(root_abs, source_protocol_path)
    contract, archive_path = _check_archive_identity(source_protocol)
    stage_text = contract.get("staging_root")
    if type(stage_text) is not str or not _same_windows_path(source_mirror_root, R3_MIRROR_ROOT) or \
            not _same_windows_path(stage_text, R3_MIRROR_ROOT):
        raise ValueError("V9 raw-sidecar builder must use the exact frozen R3 source mirror")
    source_mirror = pathlib.Path(R3_MIRROR_ROOT)
    if not _assert_directory_if_present(source_mirror):
        raise ValueError("frozen R3 source mirror is missing")
    if _map_summary(contract) != _MAP_COUNTS:
        raise ValueError("frozen R3 map summary changed before the V9 raw-sidecar build")
    _check_protocol_binds_evidence(source_protocol)
    refs = tuple(ref for slot in _SLOTS for ref in slot.evidence)
    _verify_evidence_map(contract, refs)

    infos, directory_count, collision_groups = _archive_inventory(archive_path)
    evidence = _read_archive_evidence(archive_path, infos)
    for slot in _SLOTS:
        _verify_slot_documents(slot, evidence[slot.slot_id])
    v9_evidence = evidence["v9-r9-runtime-replay"]
    parent_raw = v9_evidence["parent_protocol"]
    receipt_raw = v9_evidence["static_receipt"]
    _verify_v9_raw_receipt_documents(parent_raw, receipt_raw)

    mirror_receipt = _read_pinned_mirror_file(source_mirror, V9_STATIC_RECEIPT_REF, "V9 static receipt")
    if mirror_receipt != receipt_raw:
        raise ValueError("R3 mirror V9 receipt differs from the receipt inside the pinned ZIP")
    raw_by_path, rows = _read_v9_raw_archive_outputs(archive_path, infos, contract)
    for row in rows:
        logical_path = row["logical_path"]
        if type(logical_path) is not str:
            raise ValueError("internal V9 raw-sidecar path is malformed")
        _require_v9_raw_target_absent(root_abs, logical_path, "workspace")
        _require_v9_raw_target_absent(source_mirror, logical_path, "R3 source mirror")

    receipt: dict[str, object] = {
        "schema": V9_RAW_SIDECAR_SCHEMA,
        "classification": "source_bound_v9_static_raw_sidecar_test_only",
        "credit": "none",
        "source_protocol": {
            "path": R3_PROTOCOL_REL,
            "bytes": R3_PROTOCOL_BYTES,
            "sha256": R3_PROTOCOL_SHA256,
        },
        "archive": {
            "path": ARCHIVE_PATH,
            "bytes": ARCHIVE_BYTES,
            "sha256": ARCHIVE_SHA256,
            "member_count_including_directories": len(infos),
            "directory_member_count": directory_count,
            "windows_name_collision_groups": collision_groups,
        },
        "v9_parent_protocol": V9_PROTOCOL_REF.as_receipt(),
        "v9_static_receipt": V9_STATIC_RECEIPT_REF.as_receipt(),
        "source_mirror_root": R3_MIRROR_ROOT,
        "source_map_summary": _map_summary(contract),
        "files": rows,
    }

    # Close the read window with fresh pins and absence checks. These files are
    # staged only later into a distinct R4 mirror by materialize().
    _, source_protocol_post = _load_source_protocol(root_abs, source_protocol_path)
    if source_protocol_post != source_protocol_raw:
        raise ValueError("frozen R3 source protocol changed during V9 raw-sidecar validation")
    mirror_receipt_post = _read_pinned_mirror_file(source_mirror, V9_STATIC_RECEIPT_REF, "V9 static receipt")
    if mirror_receipt_post != mirror_receipt:
        raise ValueError("R3 mirror V9 receipt changed during V9 raw-sidecar validation")
    for row in rows:
        logical_path = row["logical_path"]
        if type(logical_path) is not str:
            raise ValueError("internal V9 raw-sidecar path is malformed")
        _require_v9_raw_target_absent(root_abs, logical_path, "workspace")
        _require_v9_raw_target_absent(source_mirror, logical_path, "R3 source mirror")
    _assert_archive_unchanged(archive_path)
    return receipt, raw_by_path


def build_v9_static_raw_output_sidecar_v21_r4(
    root: pathlib.Path,
    source_protocol_path: pathlib.Path,
    source_mirror_root: pathlib.Path,
) -> V9StaticRawOutputSidecarV21R4:
    """Build the exact three-file R9 static raw sidecar from frozen ZIP bytes."""
    receipt, _ = _build_v9_static_raw_sidecar_context(
        pathlib.Path(root), pathlib.Path(source_protocol_path), pathlib.Path(source_mirror_root))
    return V9StaticRawOutputSidecarV21R4(_canonical_json_bytes(receipt).decode("utf-8"))


def _paths_overlap(left: pathlib.Path, right: pathlib.Path) -> bool:
    left_abs = os.path.normcase(os.path.normpath(os.path.abspath(os.fspath(left))))
    right_abs = os.path.normcase(os.path.normpath(os.path.abspath(os.fspath(right))))
    left_drive = os.path.splitdrive(left_abs)[0]
    right_drive = os.path.splitdrive(right_abs)[0]
    if left_drive and right_drive and left_drive != right_drive:
        return False
    try:
        common = os.path.normcase(os.path.commonpath((left_abs, right_abs)))
    except ValueError as exc:
        raise ValueError("cannot establish containment for paths on the same volume") from exc
    return common == left_abs or common == right_abs


def _stage_target(stage_root: pathlib.Path, logical_path: str) -> pathlib.Path:
    parts = logical_path.split("/")
    if not parts or parts[0] != "docs" or any(part in ("", ".", "..") for part in parts):
        raise ValueError("V9 raw-sidecar target is not a strict docs-relative path")
    stage_abs = pathlib.Path(os.path.abspath(os.fspath(stage_root)))
    target = stage_abs.joinpath(*parts)
    try:
        common = os.path.normcase(os.path.commonpath((str(stage_abs), str(target))))
    except ValueError as exc:
        raise ValueError("V9 raw-sidecar target is on a different volume") from exc
    if common != os.path.normcase(str(stage_abs)):
        raise ValueError("V9 raw-sidecar target escapes the current stage root")
    return target


def _verify_helper_owned_source(root: pathlib.Path, current_protocol: Mapping[str, Any]) -> tuple[int, str]:
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    helper_path = root_abs.joinpath(*HELPER_REL.split("/"))
    loaded_path = pathlib.Path(os.path.abspath(os.fspath(__file__)))
    if not _same_windows_path(loaded_path, helper_path):
        raise ValueError("V9 raw-sidecar helper was not loaded from the owned source path")
    _assert_no_reparse_components(helper_path)
    metadata = os.lstat(helper_path)
    if not stat.S_ISREG(metadata.st_mode):
        raise ValueError("V9 raw-sidecar helper source is not a regular file")
    raw = helper_path.read_bytes()
    byte_count = len(raw)
    sha256 = _sha256_bytes(raw)
    rows = current_protocol.get("owned_source_files")
    by_path = current_protocol.get("owned_source_files_by_path")
    if not isinstance(rows, list) or not isinstance(by_path, Mapping):
        raise ValueError("current R4 protocol lacks its owned-source file pins")
    matches = [row for row in rows if isinstance(row, Mapping) and row.get("path") == HELPER_REL]
    expected = {"path": HELPER_REL, "bytes": byte_count, "sha256": sha256}
    if len(matches) != 1 or dict(matches[0]) != expected or by_path.get(HELPER_REL) != sha256:
        raise ValueError("current R4 protocol does not pin the exact V9 raw-sidecar helper bytes")
    return byte_count, sha256


def _runtime_v9_sidecar_inputs(
    root: pathlib.Path,
    current_protocol: Mapping[str, Any],
    actual_stage_root: pathlib.Path,
    proof: Mapping[str, Any] | None,
    *,
    verify_frozen_source: bool,
) -> tuple[pathlib.Path, Mapping[str, Any], dict[str, object], tuple[str, str, str], dict[str, bytes]]:
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    stage_abs = pathlib.Path(os.path.abspath(os.fspath(actual_stage_root)))
    _assert_no_reparse_components(root_abs)
    _assert_no_reparse_components(stage_abs)
    if not root_abs.is_dir() or not stage_abs.is_dir():
        raise ValueError("workspace root and actual R4 stage root must both exist as directories")
    current_contract = _protocol_archive_source(current_protocol, os.fspath(stage_abs))
    if _paths_overlap(root_abs, stage_abs):
        raise ValueError("actual R4 stage root must remain outside the workspace")
    if _paths_overlap(stage_abs, pathlib.Path(R2_MIRROR_ROOT)) or \
            _paths_overlap(stage_abs, pathlib.Path(R3_MIRROR_ROOT)):
        raise ValueError("actual R4 stage root overlaps an R2/R3 source mirror")
    source_protocol_path = root_abs.joinpath(*R3_PROTOCOL_REL.split("/"))
    source_protocol, _ = _load_source_protocol(root_abs, source_protocol_path)
    source_contract = _protocol_archive_source(source_protocol)
    if any(_canonical_json_bytes(_map_rows(current_contract, table)) !=
           _canonical_json_bytes(_map_rows(source_contract, table)) for table in _MAP_TABLES):
        raise ValueError("current R4 archived-input map differs from the frozen R3 map")
    refs = tuple(ref for slot in _SLOTS for ref in slot.evidence)
    _check_protocol_binds_evidence(current_protocol)
    _verify_evidence_map(current_contract, refs)
    for name, _, _ in _V9_RAW_OUTPUT_SPECS:
        _check_unmapped_v9_raw_path(current_contract, _v9_raw_logical_path(name))
    _verify_helper_owned_source(root_abs, current_protocol)

    protocol_proof = current_protocol.get(V9_RAW_SIDECAR_KEY)
    if not isinstance(protocol_proof, Mapping):
        raise ValueError("current R4 protocol lacks the V9 raw-sidecar receipt")
    if proof is None:
        proof = protocol_proof
    if not isinstance(proof, Mapping) or _canonical_json_bytes(proof) != _canonical_json_bytes(protocol_proof):
        raise ValueError("supplied V9 raw-sidecar proof differs from the current R4 protocol")
    if verify_frozen_source:
        expected_receipt, raw_by_path = _build_v9_static_raw_sidecar_context(
            root_abs, source_protocol_path, pathlib.Path(R3_MIRROR_ROOT))
        if _canonical_json_bytes(proof) != _canonical_json_bytes(expected_receipt):
            raise ValueError("current R4 V9 raw-sidecar receipt differs from exact frozen source evidence")
    else:
        expected_receipt = dict(proof)
        raw_by_path = {}
        if expected_receipt.get("schema") != V9_RAW_SIDECAR_SCHEMA or \
                expected_receipt.get("classification") != "source_bound_v9_static_raw_sidecar_test_only" or \
                expected_receipt.get("credit") != "none":
            raise ValueError("cached V9 raw-sidecar proof has an unsupported schema or credit claim")
    proof_sha = _sha256_bytes(_canonical_json_bytes(proof))
    identity = (
        os.path.normcase(str(root_abs)),
        os.path.normcase(str(stage_abs)),
        proof_sha,
    )
    return stage_abs, current_contract, dict(expected_receipt), identity, raw_by_path


def _verify_regular_staged_file(path: pathlib.Path, byte_count: int, sha256: str, label: str) -> None:
    _assert_no_reparse_components(path)
    try:
        metadata = os.lstat(path)
    except FileNotFoundError as exc:
        raise ValueError(f"V9 raw-sidecar staged file is missing: {label}") from exc
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_size != byte_count:
        raise ValueError(f"V9 raw-sidecar staged file has the wrong type or size: {label}")
    if _sha256_file(path) != sha256:
        raise ValueError(f"V9 raw-sidecar staged file hash changed: {label}")


def _assert_exact_stage_spelling(stage_root: pathlib.Path, logical_path: str) -> None:
    current = stage_root
    parts = logical_path.split("/")
    for index, component in enumerate(parts):
        _assert_no_reparse_components(current)
        try:
            with os.scandir(current) as entries:
                names = [entry.name for entry in entries]
        except FileNotFoundError as exc:
            raise ValueError(f"V9 raw-sidecar stage path component is missing: {current}") from exc
        component_key = component.rstrip(" .").casefold()
        aliases = [name for name in names if name.rstrip(" .").casefold() == component_key]
        if aliases != [component]:
            raise ValueError(f"V9 raw-sidecar stage path has a missing or aliased component: {component}")
        current = current / component
        metadata = os.lstat(current)
        if index < len(parts) - 1 and not stat.S_ISDIR(metadata.st_mode):
            raise ValueError(f"V9 raw-sidecar stage ancestor is not a directory: {current}")


def _verify_staged_v9_receipt(stage_root: pathlib.Path) -> pathlib.Path:
    path = _stage_target(stage_root, V9_STATIC_RECEIPT_REF.path)
    _assert_exact_stage_spelling(stage_root, V9_STATIC_RECEIPT_REF.path)
    _verify_regular_staged_file(path, V9_STATIC_RECEIPT_REF.byte_count,
                                V9_STATIC_RECEIPT_REF.sha256, "V9 static receipt")
    return path


def _assert_no_staged_name_alias(parent: pathlib.Path, filename: str) -> None:
    target_key = filename.rstrip(" .").casefold()
    with os.scandir(parent) as entries:
        for entry in entries:
            existing_key = entry.name.rstrip(" .").casefold()
            if existing_key == target_key and entry.name != filename:
                raise ValueError(f"V9 raw-sidecar staged filename has a Windows case/trailing alias: {entry.name}")


def _require_v9_raw_target_absent(root: pathlib.Path, logical_path: str, label: str) -> None:
    _require_absent(root, logical_path, label)
    target = _safe_target(root, logical_path)
    parent = target.parent
    _assert_no_reparse_components(parent)
    try:
        metadata = os.lstat(parent)
    except FileNotFoundError:
        return
    if not stat.S_ISDIR(metadata.st_mode):
        raise ValueError(f"V9 raw-sidecar parent is not a directory in {label}: {parent}")
    target_key = target.name.rstrip(" .").casefold()
    with os.scandir(parent) as entries:
        for entry in entries:
            if entry.name.rstrip(" .").casefold() == target_key:
                raise ValueError(f"V9 raw-sidecar target has a case/trailing alias in {label}: {entry.name}")


def _write_or_verify_sidecar_file(path: pathlib.Path, raw: bytes, row: Mapping[str, Any]) -> None:
    parent = path.parent
    _assert_no_reparse_components(parent)
    parent_metadata = os.lstat(parent)
    if not stat.S_ISDIR(parent_metadata.st_mode):
        raise ValueError("mapped V9 static receipt parent is not a real directory")
    _assert_no_staged_name_alias(parent, path.name)
    try:
        with path.open("xb") as stream:
            stream.write(raw)
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError:
        # Idempotence is limited to the exact pinned bytes; never overwrite.
        pass
    byte_count = row.get("bytes")
    sha256 = row.get("sha256")
    if type(byte_count) is not int or type(sha256) is not str:
        raise ValueError("V9 raw-sidecar row has malformed byte/hash fields")
    _verify_regular_staged_file(path, byte_count, sha256, str(row.get("logical_path")))


def materialize_v9_static_raw_output_sidecar_v21_r4(
    root: pathlib.Path,
    current_protocol: Mapping[str, Any],
    actual_stage_root: pathlib.Path,
    proof: Mapping[str, Any] | None = None,
) -> tuple[dict[str, object], ...]:
    """Stage only the three pinned V9 static raw siblings into the real R4 mirror."""
    if not isinstance(current_protocol, Mapping):
        raise ValueError("current R4 protocol is not a mapping")
    stage_root, _, expected_receipt, identity, raw_by_path = _runtime_v9_sidecar_inputs(
        pathlib.Path(root), current_protocol, pathlib.Path(actual_stage_root), proof,
        verify_frozen_source=True)
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    receipt_path = _verify_staged_v9_receipt(stage_root)
    rows = expected_receipt.get("files")
    if not isinstance(rows, list) or len(rows) != len(_V9_RAW_OUTPUT_SPECS):
        raise ValueError("V9 raw-sidecar proof has the wrong number of files")
    result_rows: list[dict[str, object]] = []
    for spec, row in zip(_V9_RAW_OUTPUT_SPECS, rows, strict=True):
        name, expected_bytes, expected_sha256 = spec
        if not isinstance(row, Mapping):
            raise ValueError("V9 raw-sidecar proof contains a malformed file row")
        logical_path = _v9_raw_logical_path(name)
        if row.get("logical_path") != logical_path or row.get("archive_member") != logical_path or \
                row.get("bytes") != expected_bytes or row.get("sha256") != expected_sha256:
            raise ValueError("V9 raw-sidecar proof row differs from the fixed literal file contract")
        _require_v9_raw_target_absent(root_abs, logical_path, "workspace")
        _require_v9_raw_target_absent(pathlib.Path(R3_MIRROR_ROOT), logical_path, "R3 source mirror")
        staged_path = _stage_target(stage_root, logical_path)
        if staged_path.parent != receipt_path.parent:
            raise ValueError("V9 raw-sidecar file is not a sibling of the mapped V9 receipt")
        _write_or_verify_sidecar_file(staged_path, raw_by_path[logical_path], row)
        result = dict(row)
        result["staged_path"] = str(staged_path)
        result_rows.append(result)

    # Postflight is deliberately limited to these three exact sidecars and
    # source pins. It never writes into the workspace, R2, or R3 mirrors.
    _verify_staged_v9_receipt(stage_root)
    _verify_helper_owned_source(root_abs, current_protocol)
    for name, _, _ in _V9_RAW_OUTPUT_SPECS:
        _assert_exact_stage_spelling(stage_root, _v9_raw_logical_path(name))
    for row in rows:
        logical_path = row.get("logical_path") if isinstance(row, Mapping) else None
        if type(logical_path) is not str:
            raise ValueError("V9 raw-sidecar proof contains a malformed logical path")
        _assert_no_staged_name_alias(_stage_target(stage_root, logical_path).parent,
                                     _stage_target(stage_root, logical_path).name)
        _verify_regular_staged_file(_stage_target(stage_root, logical_path),
                                    row["bytes"], row["sha256"], logical_path)
        _require_v9_raw_target_absent(root_abs, logical_path, "workspace")
        _require_v9_raw_target_absent(pathlib.Path(R3_MIRROR_ROOT), logical_path, "R3 source mirror")
    _VERIFIED_V9_SIDECAR_STAGES.add(identity)
    return tuple(result_rows)


def resolve_v9_static_raw_output_sidecar_v21_r4(
    root: pathlib.Path,
    current_protocol: Mapping[str, Any],
    actual_stage_root: pathlib.Path | None,
    logical_path: object,
    proof: Mapping[str, Any] | None = None,
) -> pathlib.Path | None:
    """Return a real staged file only for one of the three exact V9 raw paths."""
    exact_paths = {_v9_raw_logical_path(name) for name, _, _ in _V9_RAW_OUTPUT_SPECS}
    if type(logical_path) is not str or logical_path not in exact_paths:
        return None
    if actual_stage_root is None or not isinstance(current_protocol, Mapping):
        raise ValueError("an exact V9 raw-sidecar path requires the initialized R4 resolver")
    stage_root, _, receipt, identity, _ = _runtime_v9_sidecar_inputs(
        pathlib.Path(root), current_protocol, pathlib.Path(actual_stage_root), proof,
        verify_frozen_source=False)
    if identity not in _VERIFIED_V9_SIDECAR_STAGES:
        raise ValueError("V9 raw-sidecar files must be materialized before exact-path resolution")
    row = next((item for item in receipt["files"]
                if isinstance(item, Mapping) and item.get("logical_path") == logical_path), None)
    if not isinstance(row, Mapping):
        raise ValueError("exact V9 raw-sidecar path is missing from its frozen receipt")
    root_abs = pathlib.Path(os.path.abspath(os.fspath(root)))
    _require_v9_raw_target_absent(root_abs, logical_path, "workspace")
    _require_v9_raw_target_absent(pathlib.Path(R3_MIRROR_ROOT), logical_path, "R3 source mirror")
    target = _stage_target(stage_root, logical_path)
    _verify_staged_v9_receipt(stage_root)
    _assert_exact_stage_spelling(stage_root, logical_path)
    _verify_regular_staged_file(target, row["bytes"], row["sha256"], logical_path)
    return target


__all__ = [
    "HistoricalAbsentOutputSlotsV21R4",
    "V9StaticRawOutputSidecarV21R4",
    "RECEIPT_KEY",
    "RECEIPT_SCHEMA",
    "V9_RAW_SIDECAR_KEY",
    "V9_RAW_SIDECAR_SCHEMA",
    "build_historical_absent_output_slots_v21_r4",
    "resolve_historical_absent_output_slot_v21_r4",
    "build_v9_static_raw_output_sidecar_v21_r4",
    "materialize_v9_static_raw_output_sidecar_v21_r4",
    "resolve_v9_static_raw_output_sidecar_v21_r4",
]
