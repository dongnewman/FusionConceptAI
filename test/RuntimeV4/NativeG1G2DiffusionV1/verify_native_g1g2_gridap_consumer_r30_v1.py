"""Independent static verifier for the pinned R30 native Gridap consumer."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import sys
import types
from pathlib import Path
from typing import Any, Mapping

import run_native_g1g2_gridap_consumer_r28_v1 as r28
import run_native_g1g2_gridap_consumer_r29_v1 as r29
import verify_native_g1g2_gridap_consumer_r29_v1 as r29_verifier


ROOT = Path(__file__).resolve().parents[3]
REL_R30_PROTOCOL = "runs/NativeG1G2DiffusionV1/managed_lifecycle_refreeze_root_20260928_r1/protocol.json"
REL_R30_RUNNER = "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r30_v1.py"
REL_R30_BUILDER = "test/RuntimeV4/NativeG1G2DiffusionV1/build_protocol_r30_v1.py"
r30: Any | None = None
r30_builder: Any | None = None


ARCHIVE_IDENTITY = {
    "path": r"D:\006-Programing\LMC\FusionConceptAI_cleanup_20260926\precleanup_docs_runs_tmp.zip",
    "bytes": 472888641,
    "sha256": "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7",
}
READINESS_PIN = {
    "path": "runs/NativeG1G2DiffusionV1/r30_manifest_readiness_20260926_r1/archive_window_receipt_r1.json",
    "bytes": 104099,
    "sha256": "fb7fc3abb9873933448afb2fe1087e4922d04fd9d6f2e91ad5467ca822108c19",
}
PARSE_MANIFEST_CONTRACT = {
    "path": "docs/implementation/UP2-01-NATIVE-G1G2-DIFFUSION-PREC/archive/"
            "native_g1g2_prelaunch_r13_v1/r13_actual_v1/parse_manifest.tsv",
    "bytes": 11504,
    "sha256": "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa",
    "entries": 108,
}

CURRENT_SOURCE_LINEAGE_SCHEMA = "native-g1g2-r30-current-input-source-lineage-v1"
CURRENT_SOURCE_LINEAGE_PATHS = (
    "Project.toml",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl",
    "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
CURRENT_SOURCE_LINEAGE_ROW_KEYS = (
    "path", "r29_original_pin", "foundation_before_pin", "foundation_after_pin",
    "r25_before_sha256", "r25_after_pin", "native_stage_before_sha256",
    "native_stage_after_pin", "r9_before_sha256", "r9_after_pin",
    "current_pin",
)
CURRENT_SOURCE_LINEAGE_RECEIPT_PINS = {
    "r25_integration_receipt": {
        "path": "runs/e/lifecycle_systemic_repair_20260927_r1/live_frozen_native_shared_source_r25_integration/receipt.json",
        "bytes": 2632,
        "sha256": "823724040c90bff8d5079b4e4134cad76d75e2af2f28d3a43aea407dc421d096",
    },
    "r25_source_review": {
        "path": "runs/e/t2_independent_review_20260928_r1/frozen_native_shared_source_go_r25.json",
        "bytes": 3199,
        "sha256": "cd08a826077ff0ea8032938b04b4fed9c4cfbd24eca011142a8dbf0fcebd9e94",
    },
    "native_stage_r7_integration_receipt": {
        "path": "runs/e/lifecycle_systemic_repair_20260927_r1/live_native_git_stage_and_fixture_producer_r7_integration/receipt.json",
        "bytes": 1387,
        "sha256": "e22243bd11945c5a5d704045021f28302632a10786840fcfd0f1278ff77fa005",
    },
    "native_stage_r32_source_review": {
        "path": "runs/e/t2_independent_review_20260928_r1/native_git_stage_only_source_review_go_r32.json",
        "bytes": 1773,
        "sha256": "2e65316141d4711a0e642b254734386649fdf4cb64cb82ba478c50113822ba5b",
    },
    "prefreeze_r9_integration_receipt": {
        "path": "runs/e/lifecycle_systemic_repair_20260927_r1/live_prefreeze_fixture_inputs_r9_integration/receipt.json",
        "bytes": 5314,
        "sha256": "1094e3afbf6c7d25c3e5e9d23c94f324ac395daeda474c553ff558f2f6d74392",
    },
    "current_nine_pin_source_review": {
        "path": "runs/e/t2_independent_review_20260928_r1/fixture_launcher_6aa7_full_nine_pin_source_go_r1.json",
        "bytes": 2902,
        "sha256": "b4f03364c8e76c2d6f97a9d86e4bafc8e7015c97b68c2a4df8d1d67ab791a0d2",
    },
    "prefreeze_r9_source_coverage_review": {
        "path": "runs/e/t2_independent_review_20260928_r1/source_coverage_fixture_contract_go_r1.json",
        "bytes": 8153,
        "sha256": "b1af6a82e8e4979189a848a95a8f61fa7089d19b704c93c2bc27dec8cb8061fb",
    },
}
R25_SOURCE_CANDIDATE_ROOT = "runs/e/t2_frozen_source_authority_candidate_20260928_r1/postimage"
R32_NATIVE_GIT_PRESERVED_PREIMAGE = {
    "path": "runs/e/t2_frozen_native_git_stage_repair_20260928_r1/preimage/NativeGitReadCompatibilityV1.01B5CC2A75647EBB3474EC17D66A5E9729D65EDC3B215D00EEE5337A6B3790BC.jl",
    "bytes": 86552,
    "sha256": "01b5cc2a75647ebb3474ec17d66a5e9729d65edc3b215d00eee5337a6b3790bc",
}
R32_NATIVE_GIT_CANDIDATE = (
    "runs/e/t2_frozen_native_git_stage_repair_20260928_r1/postimage/"
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl"
)
R9_SOURCE_REVIEW_PATHS = (
    "test/GenomeV5/Integration/VNextT2FormalIndependentR1/independent_negative_controller_r23.py",
    "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py",
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py",
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
    "scripts/prepare_t2_source_fixtures.jl",
    "tools/execution/t2_source_inputs.py",
    "tools/workspace_sources.py",
)


def _require(condition: bool, message: str) -> None:
    if not condition:
        raise r30.PreflightError(message)


def _read_pinned_json(path: Path, expected: Mapping[str, Any], label: str) -> dict[str, Any]:
    _require(not path.is_symlink() and path.is_file(), f"{label} is absent or not a regular file")
    raw = path.read_bytes()
    actual = {"path": expected.get("path"), "bytes": len(raw),
              "sha256": hashlib.sha256(raw).hexdigest()}
    _require(r30._exact_json_equal(actual, dict(expected)), f"{label} bytes differ from its exact pin")
    try:
        value = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise r30.PreflightError(f"{label} is not valid UTF-8 JSON: {type(exc).__name__}: {exc}") from exc
    _require(isinstance(value, dict), f"{label} JSON root is not an object")
    return value


def _unique_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _load_r30_source_exact(protocol: Mapping[str, Any], relative_path: str,
                           module_name: str) -> tuple[types.ModuleType, dict[str, Any]]:
    rows = protocol.get("r30_source_pins")
    if type(rows) is not list:
        raise ValueError("R30 owned source rows are unavailable for pinned import")
    matches = [row for row in rows if isinstance(row, Mapping) and row.get("path") == relative_path]
    if len(matches) != 1:
        raise ValueError(f"R30 source pin is missing or duplicated: {relative_path}")
    pin = matches[0]
    if set(pin) != {"path", "bytes", "sha256"} or type(pin.get("bytes")) is not int or \
            pin["bytes"] < 0 or type(pin.get("sha256")) is not str or \
            re.fullmatch(r"[0-9a-f]{64}", pin["sha256"]) is None:
        raise ValueError(f"R30 source pin is malformed: {relative_path}")
    path = (ROOT / Path(relative_path)).absolute()
    try:
        path.resolve(strict=True).relative_to(ROOT.resolve(strict=True))
    except Exception as exc:
        raise ValueError(f"R30 pinned source escapes the repository: {relative_path}") from exc
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"R30 pinned source is not a regular file: {relative_path}")
    raw = path.read_bytes()
    if len(raw) != pin["bytes"] or hashlib.sha256(raw).hexdigest() != pin["sha256"]:
        raise ValueError(f"R30 pinned source bytes differ before import: {relative_path}")
    module = types.ModuleType(module_name)
    module.__file__ = str(path.resolve(strict=True))
    module.__package__ = ""
    module.__r30_source_pin__ = dict(pin)
    previous = sys.modules.get(module_name)
    if previous is not None:
        raise ValueError(f"R30 source module name was already imported: {module_name}")
    sys.modules[module_name] = module
    try:
        exec(compile(raw, module.__file__, "exec", dont_inherit=True, optimize=0), module.__dict__)
        after = path.read_bytes()
        if len(after) != pin["bytes"] or hashlib.sha256(after).hexdigest() != pin["sha256"]:
            raise ValueError(f"R30 pinned source bytes drifted during import: {relative_path}")
    except BaseException:
        if sys.modules.get(module_name) is module:
            del sys.modules[module_name]
        raise
    return module, {"path": relative_path, "bytes": len(raw), "sha256": pin["sha256"]}


def _check_archive_contract(protocol: Mapping[str, Any]) -> dict[str, Any]:
    contract = protocol.get("archive_input_provider")
    _require(isinstance(contract, Mapping), "R30 archive provider contract is missing")
    for key, value in ARCHIVE_IDENTITY.items():
        _require(type(contract.get(key)) is type(value) and contract.get(key) == value,
                 f"R30 frozen archive {key} differs from the approved ZIP identity")
    _require(r30.R30_ARCHIVE_PATH == ARCHIVE_IDENTITY["path"] and
             type(r30.R30_ARCHIVE_BYTES) is int and r30.R30_ARCHIVE_BYTES == ARCHIVE_IDENTITY["bytes"] and
             r30.R30_ARCHIVE_SHA256 == ARCHIVE_IDENTITY["sha256"],
             "R30 runner archive constants differ from the frozen ZIP identity")
    _require(r30_builder.ARCHIVE_PATH == ARCHIVE_IDENTITY["path"] and
             type(r30_builder.ARCHIVE_BYTES) is int and r30_builder.ARCHIVE_BYTES == ARCHIVE_IDENTITY["bytes"] and
             r30_builder.ARCHIVE_SHA256 == ARCHIVE_IDENTITY["sha256"],
             "R30 builder archive constants differ from the frozen ZIP identity")
    _require(contract.get("schema") == "native-g1g2-r30-archive-input-provider-v1" and
             type(contract.get("zip_member_paths")) is list and
             len(contract["zip_member_paths"]) == 47 and
             contract["zip_member_paths"] == sorted(set(contract["zip_member_paths"])),
             "R30 explicit ZIP member source map is malformed")
    _require(r30._exact_json_equal(contract.get("source_readiness_receipt"), READINESS_PIN) and
             r30._exact_json_equal(r30_builder.READINESS_PIN, READINESS_PIN) and
             contract.get("source_map_origin") == "verified_original_r29_214_pin_join",
             "R30 readiness receipt/source-map lineage pin changed")

    readiness = _read_pinned_json(r30._physical_repo_path(READINESS_PIN["path"]),
                                  READINESS_PIN, "R30 archive-window readiness receipt")
    _require(readiness.get("classification") ==
             "read_only_input_readiness_no_runtime_or_science_credit" and
             readiness.get("files_materialized") is False and
             readiness.get("python_julia_or_host_runtime_started") is False and
             readiness.get("numerical_credit") is False and readiness.get("physical_credit") is False,
             "readiness receipt overstates materialization, runtime, or scientific credit")
    expected_parent = {**r30.R29_PROTOCOL_PIN, "input_pin_count": 214}
    _require(r30._exact_json_equal(readiness.get("protocol"), expected_parent),
             "readiness receipt does not bind the exact R29 protocol identity")
    archive = readiness.get("archive")
    expected_archive_fields = {
        "path": ARCHIVE_IDENTITY["path"],
        "bytes_before": ARCHIVE_IDENTITY["bytes"],
        "sha256_before": ARCHIVE_IDENTITY["sha256"],
        "bytes_after": ARCHIVE_IDENTITY["bytes"],
        "sha256_after": ARCHIVE_IDENTITY["sha256"],
        "unchanged": True,
        "expected_bytes": ARCHIVE_IDENTITY["bytes"],
        "expected_sha256": ARCHIVE_IDENTITY["sha256"],
    }
    _require(isinstance(archive, Mapping) and all(
        type(archive.get(key)) is type(value) and archive.get(key) == value
        for key, value in expected_archive_fields.items()),
        "readiness receipt archive before/after identity differs from the frozen ZIP")
    return readiness


def _verify_r29_restore_lineage_via_provider(manifest: Mapping[str, Any],
                                             r29_protocol: Mapping[str, Any],
                                             r30_protocol: Mapping[str, Any],
                                             provider: Any) -> int:
    """Recheck R29's exact-restore NO-GO inventory only through the R30 provider."""
    preflight = manifest.get("runtime_preflight")
    _require(isinstance(preflight, Mapping) and
             preflight.get("status") == "NO-GO_until_exact_restore" and
             preflight.get("exact_restore_required") is True and
             preflight.get("restored") is False and
             preflight.get("input_pin_waiver") is False,
             "R29 runtime preflight must remain NO-GO with exact restore required and no waiver")
    inventory = preflight.get("inventory")
    _require(type(inventory) is list and len(inventory) ==
             preflight.get("missing_count") == 47,
             "R29 exact-restore inventory must preserve all 47 absent paths")
    archive = preflight.get("archive") or preflight.get("archive_source")
    _require(isinstance(archive, Mapping) and archive.get("local_only") is True and
             archive.get("portable") is False,
             "R29 exact-restore ZIP source is missing or its local-only limitation is unclear")
    archive_contract = r30_protocol.get("archive_input_provider")
    _require(isinstance(archive_contract, Mapping),
             "R30 archive provider contract is missing from R29 lineage check")
    archive_identity = {key: archive.get(key) for key in ("path", "bytes", "sha256")}
    provider_identity = {
        "path": str(provider.archive_path),
        "bytes": provider.archive_bytes,
        "sha256": provider.archive_sha256,
    }
    frozen_identity = {key: archive_contract.get(key) for key in ("path", "bytes", "sha256")}
    _require(r30._exact_json_equal(archive_identity, frozen_identity) and
             r30._exact_json_equal(provider_identity, frozen_identity),
             "R29 archived-input identity differs from the bound R30 ZIP provider")

    r29_pin_rows = r29_protocol.get("input_pins")
    r30_pin_rows = r30_protocol.get("input_pins")
    _require(type(r29_pin_rows) is list and type(r30_pin_rows) is list and
             len(r29_pin_rows) == len(r30_pin_rows) == 214 and
             r30._exact_json_equal(r29_pin_rows, r30_pin_rows),
             "R29/R30 input pin rows are missing during archived lineage validation")
    r29_pins = {row.get("path"): row for row in r29_pin_rows if isinstance(row, Mapping)}
    r30_pins = {row.get("path"): row for row in r30_pin_rows if isinstance(row, Mapping)}
    _require(len(r29_pins) == len(r30_pins) == 214,
             "R29/R30 archived lineage input pins are malformed or duplicated")
    expected_paths: set[str] = set()
    expected_members: set[str] = set()
    zip_paths = archive_contract.get("zip_member_paths")
    _require(type(zip_paths) is list and len(zip_paths) == 47 and
             zip_paths == sorted(set(zip_paths)),
             "R30 ZIP source map is not the exact unique 47-member list")
    for item in inventory:
        _require(isinstance(item, Mapping), "R29 exact-restore inventory row is malformed")
        logical = item.get("path")
        member = item.get("zip_member")
        _require(type(logical) is str and type(member) is str and logical == member and
                 logical in zip_paths and logical not in expected_paths and
                 member not in expected_members,
                 f"R29 restore ZIP member is missing or duplicated: {member}")
        expected_paths.add(logical)
        expected_members.add(member)
        try:
            physical = provider.physical_path(logical)
            _require(not physical.is_symlink() and not physical.exists(),
                     f"R29 NO-GO input was unexpectedly materialized: {logical}")
            data = provider.read_bytes(logical)
            receipt = provider.receipt(logical)
        except r30.PreflightError:
            raise
        except Exception as exc:
            raise r30.PreflightError(
                f"R30 provider rejected R29 archived member {logical}: "
                f"{type(exc).__name__}: {exc}") from exc
        byte_count = len(data)
        sha = hashlib.sha256(data).hexdigest()
        _require(receipt.get("source") == "zip_member" and
                 receipt.get("path") == logical and
                 type(receipt.get("bytes")) is int and receipt.get("bytes") == byte_count and
                 receipt.get("sha256") == sha,
                 f"R30 provider receipt differs from its exact archived bytes: {logical}")
        _require(item.get("archive_match") is True and
                 type(item.get("expected_bytes")) is int and
                 type(item.get("observed_bytes")) is int and
                 byte_count == item.get("expected_bytes") == item.get("observed_bytes") and
                 type(item.get("expected_sha256")) is str and
                 type(item.get("observed_sha256")) is str and
                 sha == item.get("expected_sha256") == item.get("observed_sha256"),
                 f"R29 archived restore member bytes/hash mismatch: {logical}")
        for pin_rows, label in ((r29_pins, "R29"), (r30_pins, "R30")):
            pin = pin_rows.get(logical)
            _require(isinstance(pin, Mapping) and
                     type(pin.get("bytes")) is int and pin.get("bytes") == byte_count and
                     pin.get("sha256") == sha,
                     f"R29 restore member differs from the {label} frozen input pin: {logical}")
    _require(expected_paths == set(zip_paths) and expected_members == set(zip_paths),
             "R29 restore inventory does not cover the exact R30 provider member set")
    return len(inventory)


def _verify_historical_pins_via_provider(protocol: Mapping[str, Any],
                                        r30_protocol: Mapping[str, Any],
                                        missing_inventory: list[Mapping[str, Any]],
                                        provider: Any, label: str) -> dict[str, int]:
    """Read each historical input pin through the already-bound R30 provider."""
    rows = protocol.get("input_pins")
    current_rows = r30_protocol.get("input_pins")
    _require(type(rows) is list and type(current_rows) is list,
             f"{label} historical input pins are malformed")
    current = {row.get("path"): row for row in current_rows if isinstance(row, Mapping)}
    _require(len(current) == len(current_rows), "R30 input pin list has duplicate or malformed paths")
    current_rebindings = r30_protocol.get("current_input_rebindings")
    _require(isinstance(current_rebindings, Mapping),
             "R30 explicit current-input rebinding map is missing from historical verification")
    rebound_workspace_paths = set(r30.CURRENT_INPUT_REBINDING_PATHS)
    _require(protocol.get("input_pin_count") == len(rows),
             f"{label} historical input pin count differs from its row list")
    expected_missing: dict[str, Mapping[str, Any]] = {}
    for item in missing_inventory:
        path = item.get("path")
        _require(type(path) is str and path not in expected_missing,
                 f"{label} historical absent-input inventory is malformed or duplicated")
        expected_missing[path] = item
    seen_missing: set[str] = set()
    seen_pins: set[str] = set()
    workspace_count = 0
    for pin in rows:
        _require(isinstance(pin, Mapping) and type(pin.get("path")) is str,
                 f"{label} historical input pin row is malformed")
        logical = pin["path"]
        _require(logical not in seen_pins, f"{label} historical input pins contain a duplicate: {logical}")
        seen_pins.add(logical)
        current_pin = current.get(logical)
        _require(isinstance(current_pin, Mapping) and r30._exact_json_equal(dict(pin), dict(current_pin)),
                 f"{label} historical input pin differs from the R30-bound row: {logical}")
        if logical in rebound_workspace_paths:
            binding = current_rebindings.get(logical)
            _require(isinstance(binding, Mapping) and
                     r30._exact_json_equal(dict(pin), binding.get("original_pin")) and
                     isinstance(binding.get("current_pin"), Mapping) and
                     isinstance(binding.get("preserved_original_pin"), Mapping),
                     f"{label} historical rebound input lacks exact original/current pins: {logical}")
            current_physical = provider.physical_path(logical)
            _require(not current_physical.is_symlink() and current_physical.is_file(),
                     f"{label} rebound current workspace source is absent: {logical}")
            current_data = provider.read_bytes(logical)
            current_receipt = provider.receipt(logical)
            current_hash = hashlib.sha256(current_data).hexdigest()
            active_pin = binding["current_pin"]
            _require(len(current_data) == active_pin.get("bytes") and
                     current_hash == active_pin.get("sha256") and
                     current_receipt.get("source") == "workspace" and
                     current_receipt.get("bytes") == len(current_data) and
                     current_receipt.get("sha256") == current_hash,
                     f"{label} active provider does not use the exact rebound current bytes: {logical}")
            preserved_pin = binding["preserved_original_pin"]
            preserved_path = r30._physical_repo_path(preserved_pin["path"])
            _require(not preserved_path.is_symlink() and preserved_path.is_file(),
                     f"{label} rebound historical source preimage is unavailable: {logical}")
            historical_data = preserved_path.read_bytes()
            historical_hash = hashlib.sha256(historical_data).hexdigest()
            _require(len(historical_data) == pin.get("bytes") == preserved_pin.get("bytes") and
                     historical_hash == pin.get("sha256") == preserved_pin.get("sha256"),
                     f"{label} preserved historical source differs from its original 214 pin: {logical}")
            workspace_count += 1
            continue
        try:
            physical = provider.physical_path(logical)
            data = provider.read_bytes(logical)
            receipt = provider.receipt(logical)
        except r30.PreflightError:
            raise
        except Exception as exc:
            raise r30.PreflightError(
                f"R30 provider rejected {label} historical input {logical}: "
                f"{type(exc).__name__}: {exc}") from exc
        byte_count = len(data)
        digest = hashlib.sha256(data).hexdigest()
        _require(receipt.get("path") == logical and type(receipt.get("bytes")) is int and
                 receipt.get("bytes") == byte_count and
                 receipt.get("sha256") == digest,
                 f"{label} historical provider receipt differs from input bytes: {logical}")
        item = expected_missing.get(logical)
        if item is not None:
            _require(receipt.get("source") == "zip_member" and
                     not physical.is_symlink() and not physical.exists() and
                     item.get("archive_match") is True and
                     type(item.get("expected_bytes")) is int and
                     type(item.get("observed_bytes")) is int and
                     byte_count == item.get("expected_bytes") == item.get("observed_bytes") and
                     item.get("expected_sha256") == item.get("observed_sha256") == digest,
                     f"{label} archived absent-input evidence changed: {logical}")
            seen_missing.add(logical)
        else:
            _require(receipt.get("source") == "workspace" and not physical.is_symlink() and
                     physical.is_file(),
                     f"{label} workspace input is absent or misclassified: {logical}")
            workspace_count += 1
    _require(seen_missing == set(expected_missing),
             f"{label} provider-backed missing inputs differ from the exact NO-GO inventory")
    return {"checked_count": workspace_count, "missing_count": len(seen_missing)}


def _check_r29_lineage(protocol: Mapping[str, Any], provider: Any
                       ) -> tuple[dict[str, Any], dict[str, Any], int, int]:
    r29_path = r29.repo_path(r29.REL_PROTOCOL)
    r29_protocol = r29.load_protocol(r29_path)
    r29_manifest = r29_verifier._check_freeze_manifest(r29_path, r29_protocol)
    r29_runtime = r29_manifest.get("runtime_preflight")
    _require(isinstance(r29_runtime, Mapping), "R29 exact-restore NO-GO record is missing")
    inventory = r29_runtime.get("inventory")
    _require(type(inventory) is list and len(inventory) == 47,
             "R29 exact-restore inventory no longer contains all 47 absent inputs")
    verified_members = _verify_r29_restore_lineage_via_provider(
        r29_manifest, r29_protocol, protocol, provider)
    _require(verified_members == 47, "R29 pinned ZIP did not verify all 47 archived inputs")
    _require(type(r29_protocol.get("input_pins")) is list and
             len(r29_protocol["input_pins"]) == 214 and
             r29_protocol.get("input_pin_count") == 214 and
             r30._exact_json_equal(protocol.get("input_pins"), r29_protocol["input_pins"]),
             "R29 exact ordered 214-row input pins differ from R30")
    r29_pin_counts = _verify_historical_pins_via_provider(
        r29_protocol, protocol, inventory, provider, "R29")
    r28_protocol = r28.load_protocol(r28.repo_path(r28.REL_PROTOCOL))
    r28_pin_counts = _verify_historical_pins_via_provider(
        r28_protocol, protocol, inventory, provider, "R28")
    preserved_r28 = r29_verifier._check_r28_pins_preserved(r29_protocol, r28_protocol)
    r29_verifier._check_protocol_contracts(r29_protocol, r28_protocol)
    r28_no_go = r29_verifier._check_r28_no_go_lineage(r29_protocol)
    r28_receipts = r29_verifier._check_r28_static_receipts(r29_protocol, r28_protocol, r28_no_go)
    r29_verifier._check_r26_failure_unchanged(r29_protocol, r28_protocol)
    r29_verifier._check_static_qa_target(r29_protocol)
    r29_verifier._check_r29_pid_reuse_receipt(r29_protocol)

    _require(r30._exact_json_equal(protocol.get("input_pins"), r29_protocol.get("input_pins")) and
             protocol.get("input_pin_count") == 214,
             "R30 did not preserve the exact ordered R29 214-row input-pin list")
    lineage = protocol.get("parent_lineage")
    old_lineage = r29_protocol.get("parent_lineage")
    _require(isinstance(lineage, Mapping) and isinstance(old_lineage, Mapping),
             "R30/R29 failure lineage maps are missing")
    for key, old_record in old_lineage.items():
        _require(r30._exact_json_equal(lineage.get(key), old_record),
                 f"R30 changed an inherited R29 failure/no-credit record: {key}")
    parent_receipt = r30.verify_r29_parent_protocol(protocol, "r30_static_verifier")
    _require(r29_pin_counts == {"checked_count": 167, "missing_count": 47} and
             r28_pin_counts == {"checked_count": 144, "missing_count": 47},
             "historical R28/R29 pins did not retain their exact live/archived row counts")
    return r29_protocol, r29_manifest, verified_members, r28_receipts


def _current_lineage_file_pin(relative_path: str) -> dict[str, Any]:
    path = r30._physical_repo_path(relative_path)
    _require(not path.is_symlink() and path.is_file(),
             f"current-input source-lineage path is absent/not regular: {relative_path}")
    raw = path.read_bytes()
    return {"path": relative_path, "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest()}


def _current_lineage_receipt(pin: Mapping[str, Any], label: str) -> dict[str, Any]:
    _require(type(pin) is dict and set(pin) == {"path", "bytes", "sha256"} and
             type(pin.get("path")) is str and type(pin.get("bytes")) is int and
             pin["bytes"] > 0 and type(pin.get("sha256")) is str and
             re.fullmatch(r"[0-9a-f]{64}", pin["sha256"]) is not None,
             f"{label} pin is malformed")
    return _read_pinned_json(r30._physical_repo_path(pin["path"]), pin, label)


def _current_lineage_pin(path: str, row: Mapping[str, Any]) -> dict[str, Any]:
    _require(isinstance(row, Mapping) and type(row.get("bytes")) is int and
             row["bytes"] > 0 and type(row.get("sha256")) is str and
             re.fullmatch(r"[0-9a-fA-F]{64}", row["sha256"]) is not None,
             f"source-lineage receipt pin is malformed: {path}")
    return {"path": path, "bytes": row["bytes"], "sha256": row["sha256"].lower()}


def _check_current_input_source_lineage(
        protocol: Mapping[str, Any], r29_protocol: Mapping[str, Any]) -> dict[str, Any]:
    """Verify each current source pin against the actual R29/foundation/R25/R32/R9 chain."""
    lineage = protocol.get("current_input_source_lineage_v1")
    _require(type(lineage) is dict and list(lineage) == ["schema", "receipt_pins", "rows"] and
             lineage.get("schema") == CURRENT_SOURCE_LINEAGE_SCHEMA,
             "R30 current-input source lineage is absent or has the wrong schema")
    receipt_pins = lineage.get("receipt_pins")
    _require(type(receipt_pins) is dict and
             list(receipt_pins) == list(CURRENT_SOURCE_LINEAGE_RECEIPT_PINS) and
             r30._exact_json_equal(receipt_pins, CURRENT_SOURCE_LINEAGE_RECEIPT_PINS),
             "R30 current-input source lineage receipt pins differ from the approved six-file set")
    receipts = {
        key: _current_lineage_receipt(pin, f"R30 source-lineage {key}")
        for key, pin in CURRENT_SOURCE_LINEAGE_RECEIPT_PINS.items()
    }
    r25 = receipts["r25_integration_receipt"]
    r25_review = receipts["r25_source_review"]
    stage = receipts["native_stage_r7_integration_receipt"]
    stage_review = receipts["native_stage_r32_source_review"]
    prefreeze = receipts["prefreeze_r9_integration_receipt"]
    final_review = receipts["current_nine_pin_source_review"]
    coverage_review = receipts["prefreeze_r9_source_coverage_review"]

    foundation_pin = getattr(r30, "FOUNDATION_REBINDING_RECEIPT", None)
    _require(isinstance(foundation_pin, Mapping),
             "R30 foundation integration receipt pin is unavailable")
    foundation = _current_lineage_receipt(dict(foundation_pin),
                                           "R30 source-lineage foundation integration")
    _require(foundation.get("schema") == "root-exact-source-integration-receipt-v1" and
             foundation.get("owner") == "/root" and foundation.get("integrated_count") == 11 and
             foundation.get("runtime_credit") is False and foundation.get("formal_credit") is False and
             foundation.get("consumer_entrypoints_not_integrated") is True and
             foundation.get("deleted_files") == 0 and type(foundation.get("rows")) is list and
             len(foundation["rows"]) == 11,
             "foundation source-lineage receipt is malformed or overstates its scope")
    foundation_rows: dict[str, Mapping[str, Any]] = {}
    for row in foundation["rows"]:
        _require(isinstance(row, Mapping) and type(row.get("relative_path")) is str and
                 row["relative_path"] not in foundation_rows,
                 "foundation source-lineage receipt contains malformed/duplicate rows")
        foundation_rows[row["relative_path"]] = row

    r29_rows = r29_protocol.get("input_pins")
    _require(type(r29_rows) is list and len(r29_rows) == 214,
             "R29 source-lineage parent pins are not the exact ordered 214 rows")
    r29_by_path = {row.get("path"): row for row in r29_rows if isinstance(row, Mapping)}
    _require(len(r29_by_path) == 214,
             "R29 source-lineage parent pins contain duplicate/malformed paths")

    expected_r25_paths = {
        "Project.toml",
        "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
        "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
        "src/GenomeV5/Integration/VNextT2ModuleEntryV2.jl",
        "src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl",
    }
    _require(r25.get("schema") == "root-reviewed-in-place-integration-v1" and
             r25.get("owner") == "/root" and r25.get("file_count") == 7 and
             r25.get("formal_acceptance") is False and
             r25.get("fixture_producer_integrated") is False and
             r25.get("staging_performed") is False and
             r25.get("protected_current_baseline_unchanged") is True and
             type(r25.get("files")) is list and len(r25["files"]) == 7,
             "R25 source-lineage receipt is malformed or overstates its scope")
    _require(r25.get("review_path") == CURRENT_SOURCE_LINEAGE_RECEIPT_PINS[
                 "r25_source_review"]["path"] and
             str(r25.get("review_sha256", "")).lower() ==
                 CURRENT_SOURCE_LINEAGE_RECEIPT_PINS["r25_source_review"]["sha256"],
             "R25 integration receipt does not bind its pinned independent review")
    r25_rows: dict[str, Mapping[str, Any]] = {}
    for row in r25["files"]:
        _require(isinstance(row, Mapping) and type(row.get("path")) is str and
                 row["path"] not in r25_rows and set(row) ==
                 {"path", "before_sha256", "after_sha256", "bytes"} and
                 type(row.get("bytes")) is int and row["bytes"] > 0 and
                 type(row.get("before_sha256")) is str and
                 re.fullmatch(r"[0-9a-fA-F]{64}", row["before_sha256"]) is not None and
                 type(row.get("after_sha256")) is str and
                 re.fullmatch(r"[0-9a-fA-F]{64}", row["after_sha256"]) is not None,
                 "R25 integration source rows are malformed/duplicated")
        r25_rows[row["path"]] = row
    _require(set(r25_rows) == expected_r25_paths,
             "R25 integration receipt changed its exact seven-file source set")
    _require(r25_review.get("schema") == "independent-source-review-v1" and
             r25_review.get("disposition") == "GO_SOURCE_ONLY" and
             "no import" in r25_review.get("scope", "") and
             "formal T2" in r25_review.get("scope_limit", ""),
             "R25 source review is not the source-only GO")
    reviewed_r25 = r25_review.get("sources")
    _require(type(reviewed_r25) is list and len(reviewed_r25) == 7,
             "R25 source review does not cover all seven integrated files")
    reviewed_r25_by_path: dict[str, Mapping[str, Any]] = {}
    prefix = R25_SOURCE_CANDIDATE_ROOT + "/"
    for row in reviewed_r25:
        _require(isinstance(row, Mapping) and type(row.get("path")) is str and
                 row["path"].startswith(prefix),
                 "R25 review has a malformed or out-of-tree candidate path")
        logical = row["path"][len(prefix):]
        _require(logical not in reviewed_r25_by_path,
                 "R25 source review contains duplicate candidate paths")
        reviewed_r25_by_path[logical] = row
    _require(set(reviewed_r25_by_path) == expected_r25_paths,
             "R25 review source set differs from the seven-file integration set")
    for logical, receipt_row in r25_rows.items():
        reviewed = reviewed_r25_by_path[logical]
        after_pin = _current_lineage_pin(
            logical, {"bytes": receipt_row["bytes"], "sha256": receipt_row["after_sha256"]})
        _require(str(reviewed.get("sha256", "")).lower() == after_pin["sha256"] and
                 _current_lineage_file_pin(reviewed["path"]) == {
                     **after_pin, "path": reviewed["path"]},
                 f"R25 independent review source bytes differ from integration row: {logical}")

    native_path = CURRENT_SOURCE_LINEAGE_PATHS[-1]
    _require(stage.get("schema") == "root-reviewed-in-place-integration-v1" and
             stage.get("owner") == "/root" and stage.get("file_count") == 2 and
             stage.get("formal_acceptance") is False and stage.get("runtime_executed") is False and
             type(stage.get("files")) is list and len(stage["files"]) == 2,
             "NativeGit R7 stage receipt is malformed or overstates its scope")
    stage_rows = [row for row in stage["files"] if isinstance(row, Mapping) and
                  row.get("path") == native_path]
    _require(len(stage_rows) == 1, "NativeGit R7 receipt lacks its unique source row")
    stage_row = stage_rows[0]
    r25_native = r25_rows[native_path]
    stage_pin = _current_lineage_pin(
        native_path, {"bytes": stage_row.get("bytes"), "sha256": stage_row.get("after_sha256")})
    r25_after = _current_lineage_pin(
        native_path, {"bytes": r25_native["bytes"], "sha256": r25_native["after_sha256"]})
    stage_review_pin = CURRENT_SOURCE_LINEAGE_RECEIPT_PINS["native_stage_r32_source_review"]
    _require(stage_row.get("before_kind") == "regular_file" and
             str(stage_row.get("before_sha256", "")).lower() == r25_after["sha256"] and
             str(stage_row.get("after_sha256", "")).lower() == stage_pin["sha256"] and
             stage_row.get("review") == stage_review_pin["path"] and
             str(stage_row.get("review_sha256", "")).lower() == stage_review_pin["sha256"],
             "R7 NativeGit stage row is not the exact R25-to-R32 transition")
    _require(stage_review.get("schema") == "t2-independent-source-review-v1" and
             stage_review.get("disposition") == "GO_SOURCE_ONLY" and
             stage_review.get("target") == R32_NATIVE_GIT_CANDIDATE and
             str(stage_review.get("sha256", "")).lower() == stage_pin["sha256"] and
             stage_review.get("bytes") == stage_pin["bytes"] and
             str(stage_review.get("preimage_sha256", "")).lower() == r25_after["sha256"] and
             stage_review.get("preimage") ==
                 "runs/e/t2_frozen_native_git_stage_repair_20260928_r1/preimage/"
                 "NativeGitReadCompatibilityV1.F0DC1FBD8B5D186FF300A015E263F573B7587C9771E9B9B71EB1E77CC0BB56E1.jl",
             "R32 review does not bind the exact staged source and R25 preimage")
    preserved_stage_pin = _current_lineage_file_pin(R32_NATIVE_GIT_PRESERVED_PREIMAGE["path"])
    _require(r30._exact_json_equal(preserved_stage_pin, R32_NATIVE_GIT_PRESERVED_PREIMAGE) and
             stage_pin["bytes"] == preserved_stage_pin["bytes"] and
             stage_pin["sha256"] == preserved_stage_pin["sha256"],
             "R32 reviewed 01B5 source is absent from its immutable preserved copy")

    _require(prefreeze.get("schema") == "root-reviewed-in-place-integration-v1" and
             prefreeze.get("owner") == "/root" and prefreeze.get("file_count") == 7 and
             prefreeze.get("formal_acceptance") is False and
             prefreeze.get("runtime_executed") is False and
             prefreeze.get("staging_performed") is False and
             type(prefreeze.get("files")) is list and len(prefreeze["files"]) == 7 and
             type(prefreeze.get("before")) is list and len(prefreeze["before"]) == 7,
             "R9 prefreeze source receipt is malformed or overstates its scope")
    expected_r9_reviews = [
        {"path": CURRENT_SOURCE_LINEAGE_RECEIPT_PINS[
            "prefreeze_r9_source_coverage_review"]["path"],
         "sha256": CURRENT_SOURCE_LINEAGE_RECEIPT_PINS[
            "prefreeze_r9_source_coverage_review"]["sha256"]},
        {"path": "runs/e/t2_independent_review_20260928_r1/"
                 "r23_c025_phase_scope_repair_309b_launcher_4801_source_go_r2.json",
         "sha256": "5342f7fbb3371c9c8d1df90e853479a5d1cc6ad39525415c8e54a1c2966d1212b"},
    ]
    r9_reviews = prefreeze.get("reviews")
    _require(type(r9_reviews) is list and len(r9_reviews) == 2 and
             r30._exact_json_equal(r9_reviews, expected_r9_reviews),
             "R9 integration receipt does not bind its exact two source reviews")
    _require(coverage_review.get("schema") == "t2-independent-source-review-v1" and
             coverage_review.get("review_id") == "source-coverage-fixture-contract-go-r1" and
             coverage_review.get("disposition") == "GO_SOURCE_ONLY_WITH_LAUNCHER_HOLD" and
             coverage_review.get("fixture_boundary", {}).get("formal_t2_credit") == 0 and
             coverage_review.get("fixture_boundary", {}).get("physical_credit") == 0,
             "R9 T0 source-coverage review is not the pinned no-credit source-only review")
    coverage_sources = coverage_review.get("sources")
    t0_logical = CURRENT_SOURCE_LINEAGE_PATHS[4]
    t0_review_rows = [row for row in coverage_sources if isinstance(row, Mapping) and
                      row.get("role") == "T0_fixture_tests"] if type(coverage_sources) is list else []
    current_expected_t0_pin = {
        "path": t0_logical, "bytes": 80556,
        "sha256": "2703e526e00fbf71536f78c7cbc252081e253eee746060ea8513e08f67f39e92",
    }
    _require(len(t0_review_rows) == 1 and
             t0_review_rows[0].get("path") ==
                 "runs/e/t2_frozen_source_fixtures_20260928_r1/postimage/" + t0_logical and
             t0_review_rows[0].get("bytes") == 80556 and
             str(t0_review_rows[0].get("sha256", "")).lower() ==
                 "2703e526e00fbf71536f78c7cbc252081e253eee746060ea8513e08f67f39e92" and
             _current_lineage_file_pin(t0_review_rows[0]["path"]) == {
                 "path": t0_review_rows[0]["path"], "bytes": 80556,
                 "sha256": "2703e526e00fbf71536f78c7cbc252081e253eee746060ea8513e08f67f39e92"},
             "R9 source-coverage review does not bind the exact T0 fixture test source")
    r9_rows = [row for row in prefreeze["files"] if isinstance(row, Mapping) and
               row.get("path") in (native_path, t0_logical)]
    r9_before_rows = [row for row in prefreeze["before"] if isinstance(row, Mapping) and
                      row.get("path") in (native_path, t0_logical)]
    _require(len(r9_rows) == len(r9_before_rows) == 2 and
             {row["path"] for row in r9_rows} == {native_path, t0_logical} and
             {row["path"] for row in r9_before_rows} == {native_path, t0_logical},
             "R9 source receipt does not uniquely bind NativeGit and T0 before/after rows")
    r9_by_path = {row["path"]: row for row in r9_rows}
    r9_before_by_path = {row["path"]: row for row in r9_before_rows}
    r9_row, r9_before_row = r9_by_path[native_path], r9_before_by_path[native_path]
    t0_r9_row, t0_r9_before_row = r9_by_path[t0_logical], r9_before_by_path[t0_logical]
    _require(str(r9_row.get("before", "")).lower() == stage_pin["sha256"] and
             r9_row.get("source") == R32_NATIVE_GIT_CANDIDATE and
             str(r9_row.get("after", "")).lower() ==
                 str(r9_before_row.get("sha256", "")).lower(),
             "R9 source row does not continue the R32 reviewed NativeGit bytes")
    t0_foundation = foundation_rows.get(t0_logical)
    _require(isinstance(t0_foundation, Mapping) and
             isinstance(t0_foundation.get("after"), Mapping) and
             str(t0_r9_row.get("before", "")).lower() ==
                 str(t0_foundation["after"].get("sha256", "")).lower() and
             type(t0_r9_before_row.get("bytes")) is int and
             t0_r9_before_row.get("bytes") == t0_foundation["after"].get("bytes") and
             str(t0_r9_before_row.get("sha256", "")).lower() ==
                 str(t0_foundation["after"].get("sha256", "")).lower() and
             str(t0_r9_row.get("after", "")).lower() ==
                 str(t0_review_rows[0]["sha256"]).lower() and
             _current_lineage_file_pin(t0_r9_row["source"]) == {
                 "path": t0_r9_row["source"], "bytes": 80556,
                 "sha256": str(t0_review_rows[0]["sha256"]).lower()},
             "R9 T0 source row does not continue the foundation pin to the reviewed current source")

    _require(final_review.get("schema") == "t2-independent-source-review-v1" and
             final_review.get("status") == "GO_SOURCE_ONLY",
             "6AA current nine-pin source review is not a source-only GO")
    source_map = final_review.get("source_map_validation")
    final_sources = source_map.get("sources") if isinstance(source_map, Mapping) else None
    _require(isinstance(source_map, Mapping) and source_map.get("INPUTS_count") == 8 and
             source_map.get("SUPPORT_SOURCES_count") == 1 and
             source_map.get("KNOWN_SHA256_count") == 9 and
             source_map.get("KNOWN_BYTES_count") == 9 and
             source_map.get("all_sha_literals_exactly_64_hex") is True and
             source_map.get("all_current_source_bytes_and_hashes_match") is True and
             type(final_sources) is list and len(final_sources) == 9,
             "6AA source review does not attest the full nine-source closure")
    final_by_path: dict[str, Mapping[str, Any]] = {}
    for row in final_sources:
        _require(isinstance(row, Mapping) and type(row.get("path")) is str and
                 row["path"] not in final_by_path and type(row.get("bytes")) is int and
                 row["bytes"] > 0 and type(row.get("sha256")) is str and
                 re.fullmatch(r"[0-9a-f]{64}", row["sha256"]) is not None,
                 "6AA nine-source review contains malformed/duplicate rows")
        final_by_path[row["path"]] = row
    _require(set(final_by_path) == set(R9_SOURCE_REVIEW_PATHS),
             "6AA source review changed its exact eight-input/one-support closure")
    for logical, row in final_by_path.items():
        _require(_current_lineage_file_pin(logical) == {
            "path": logical, "bytes": row["bytes"], "sha256": row["sha256"]},
            f"6AA reviewed current-source bytes changed: {logical}")
    final_native = final_by_path[native_path]
    final_native_pin = {"path": native_path, "bytes": final_native["bytes"],
                        "sha256": final_native["sha256"]}
    _require(str(r9_row.get("after", "")).lower() == final_native_pin["sha256"] and
             _current_lineage_file_pin(r9_row["source"]) == {
                 "path": r9_row["source"], "bytes": final_native_pin["bytes"],
                 "sha256": final_native_pin["sha256"]},
             "R9 NativeGit source and 6AA nine-pin review do not bind the same current bytes")

    rows = lineage.get("rows")
    _require(type(rows) is list and len(rows) == len(CURRENT_SOURCE_LINEAGE_PATHS),
             "R30 current-input source lineage must contain exactly eight ordered rows")
    _require(tuple(row.get("path") for row in rows if isinstance(row, Mapping)) ==
             CURRENT_SOURCE_LINEAGE_PATHS,
             "R30 current-input source-lineage row order/path set changed")
    observed: list[dict[str, Any]] = []
    for logical, row in zip(CURRENT_SOURCE_LINEAGE_PATHS, rows):
        _require(type(row) is dict and tuple(row) == CURRENT_SOURCE_LINEAGE_ROW_KEYS and
                 row.get("path") == logical,
                 f"R30 source-lineage row schema/order changed: {logical}")
        original = r29_by_path.get(logical)
        if original is not None:
            original = _current_lineage_pin(logical, original)
        foundation_row = foundation_rows.get(logical)
        foundation_before = foundation_after = None
        if foundation_row is not None and logical != native_path:
            _require(isinstance(foundation_row.get("before"), Mapping) and
                     isinstance(foundation_row.get("after"), Mapping),
                     f"foundation source row is missing before/after pins: {logical}")
            foundation_before = _current_lineage_pin(logical, foundation_row["before"])
            foundation_after = _current_lineage_pin(logical, foundation_row["after"])
            _require(original is not None and foundation_before == original,
                     f"foundation source before pin differs from R29: {logical}")
        r25_row = r25_rows.get(logical)
        r25_before = None
        r25_after = None
        if r25_row is not None:
            r25_before = str(r25_row["before_sha256"]).lower()
            r25_after = _current_lineage_pin(
                logical, {"bytes": r25_row["bytes"], "sha256": r25_row["after_sha256"]})
            expected_parent = foundation_after if foundation_after is not None else original
            _require(expected_parent is not None and r25_before == expected_parent["sha256"],
                     f"R25 source before pin does not continue its exact parent: {logical}")
            reviewed_candidate = reviewed_r25[logical]["path"]
            _require(_current_lineage_file_pin(reviewed_candidate) == {
                **r25_after, "path": reviewed_candidate},
                f"R25 source candidate does not bind its reviewed after pin: {logical}")
        stage_before = stage_after = r9_before = r9_after = None
        if logical == native_path:
            stage_before = str(stage_row["before_sha256"]).lower()
            stage_after = stage_pin
            r9_before = str(r9_row["before"]).lower()
            r9_after = final_native_pin
            _require(stage_before == r25_after["sha256"] and
                     r9_before == stage_after["sha256"],
                     "NativeGit stage/prefreeze before pins break the R25→R32→R9 chain")
        elif logical == t0_logical:
            r9_before = str(t0_r9_row["before"]).lower()
            r9_after = current_expected_t0_pin
            _require(foundation_after is not None and r9_before == foundation_after["sha256"] and
                     r9_after == current_expected_t0_pin,
                     "T0 R9 before/after pins do not continue the foundation source")
        current = _current_lineage_file_pin(logical)
        if logical == native_path:
            _require(current == final_native_pin and current == r9_after,
                     "NativeGit canonical source differs from the final R9-reviewed pin")
        elif logical == t0_logical:
            _require(current == r9_after,
                     "T0 current source differs from the final R9-reviewed pin")
        elif r25_after is not None:
            _require(current == r25_after,
                     f"current source differs from the R25 reviewed endpoint: {logical}")
        elif foundation_after is not None:
            _require(current == foundation_after,
                     f"current source differs from the foundation-only endpoint: {logical}")
        expected_row = {
            "path": logical,
            "r29_original_pin": original,
            "foundation_before_pin": foundation_before,
            "foundation_after_pin": foundation_after,
            "r25_before_sha256": r25_before,
            "r25_after_pin": r25_after,
            "native_stage_before_sha256": stage_before,
            "native_stage_after_pin": stage_after,
            "r9_before_sha256": r9_before,
            "r9_after_pin": r9_after,
            "current_pin": current,
        }
        _require(r30._exact_json_equal(row, expected_row),
                 f"R30 source-lineage row differs from receipt-derived pins: {logical}")
        observed.append(expected_row)
    return {"complete": True, "schema": CURRENT_SOURCE_LINEAGE_SCHEMA,
            "receipt_pins": CURRENT_SOURCE_LINEAGE_RECEIPT_PINS,
            "count": len(observed), "rows": observed,
            "r29_foundation_r25_r32_r9_edges_verified": True,
            "r32_reviewed_source_checked_at_immutable_preimage": True,
            "current_nine_pin_review_checked_against_all_nine_files": True}


def _check_r29_archive_provider_source_contract() -> dict[str, bool]:
    source_path = Path(__file__)
    source = source_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(source_path))
    restore = _function_source(source, "_verify_r29_restore_lineage_via_provider", str(source_path))
    pins = _function_source(source, "_verify_historical_pins_via_provider", str(source_path))
    lineage = _function_source(source, "_check_r29_lineage", str(source_path))
    source_lineage = _function_source(source, "_check_current_input_source_lineage", str(source_path))
    main = _function_source(source, "main", str(source_path))
    runner_path = r30._physical_repo_path(r30.REL_RUNNER)
    runner_source = runner_path.read_text(encoding="utf-8")
    provider_bind = _function_source(runner_source, "bind_input_provider", str(runner_path))
    rebind_verify = _function_source(runner_source, "verify_current_input_rebindings", str(runner_path))
    runner_pin_check = _function_source(runner_source, "verify_input_pins", str(runner_path))
    _require("provider.read_bytes(logical)" in restore and
             "provider.receipt(logical)" in restore and
             "provider.physical_path(logical)" in restore,
             "R29 exact-restore evidence must be read and physically checked through R30 provider")
    _require("provider.read_bytes(logical)" in pins and
             "provider.receipt(logical)" in pins and
             "provider.physical_path(logical)" in pins,
             "historical R28/R29 input rows must use the R30 provider without virtualizing presence")
    _require("copy.deepcopy(dict(protocol))" in provider_bind and
             "for relative in CURRENT_INPUT_REBINDING_PATHS:" in provider_bind and
             "_exact_json_equal(historical_rows[index], row[\"original_pin\"])" in provider_bind and
             "historical_rows[index] = dict(row[\"current_pin\"])" in provider_bind and
             "PinnedZipInputProvider.from_protocol(provider_protocol, ROOT)" in provider_bind,
              "R30 provider overlay must preserve protocol history and substitute all six verified active workspace pins")
    _require("rebound_workspace_paths" in pins and
             "preserved_original_pin" in pins and
             "provider.read_bytes(logical)" in pins,
             "R30 historical verifier must separate preserved originals from current provider-backed bytes")
    _require("_read_exact_pinned_json(FOUNDATION_REBINDING_RECEIPT, phase)" in rebind_verify and
             "_read_exact_pinned_json(SUPERVISOR_PREIMAGE_RECEIPT, phase)" in rebind_verify and
             "for relative in CURRENT_INPUT_REBINDING_PATHS:" in rebind_verify and
             '"count": len(observed_rows)' in rebind_verify,
             "R30 must verify all six current/preimage rows against both exact root preservation receipts")
    _require("_INPUT_PROVIDER.verify_all(phase)" in runner_pin_check and
             "frozen R30 inputs are not complete" in runner_pin_check and
             "verify_owned_source_pins(protocol, phase)" in runner_pin_check and
             "verify_r29_parent_protocol(protocol, phase)" in runner_pin_check,
             "current R30 verify_input_pins must route provider failure and exact R29 parent checks")
    def calls(node: ast.AST) -> set[tuple[str, ...]]:
        def name_of(value: ast.AST) -> tuple[str, ...]:
            if isinstance(value, ast.Name):
                return (value.id,)
            if isinstance(value, ast.Attribute):
                base = name_of(value.value)
                return (*base, value.attr)
            return ()
        return {name_of(child.func) for child in ast.walk(node) if isinstance(child, ast.Call)}

    lineage_calls = calls(ast.parse(lineage))
    all_calls = calls(tree)
    imports = {alias.name for node in ast.walk(tree) if isinstance(node, ast.Import)
               for alias in node.names}
    old_restore_call = ("r29_verifier", "_verify" + "_restore" + "_archive")
    old_pin_call = ("r29_verifier", "_verify" + "_input_pins_allowing_exact_runtime_no_go")
    zip_reader_call = ("zip" + "file", "Zip" + "File")
    _require(old_pin_call not in lineage_calls and old_restore_call not in all_calls and
             ("zip" + "file") not in imports and zip_reader_call not in all_calls,
             "R30 historical verifier still contains a direct ZIP/member-reader path")
    bind = main.find("provider = r30.bind_input_provider(protocol)")
    shape = main.find("r30.validate_protocol_shape(protocol)")
    lineage_call = main.find("_check_r29_lineage(protocol, provider)")
    source_lineage_call = main.find("_check_current_input_source_lineage(protocol, r29_protocol)")
    full_provider_check = main.find('r30.verify_input_pins(protocol, "r30_static_verifier")')
    _require(0 <= bind < shape < lineage_call < source_lineage_call < full_provider_check,
             "R30 provider must bind before receipt-derived source lineage and full input checks")
    _require("CURRENT_SOURCE_LINEAGE_RECEIPT_PINS" in source_lineage and
             "prefreeze_r9_source_coverage_review" in source_lineage and
             "T0_fixture_tests" in source_lineage and
             "R32_NATIVE_GIT_PRESERVED_PREIMAGE" in source_lineage and
             "native_stage_before_sha256" in source_lineage and
             "r9_before_sha256" in source_lineage and
             "current_pin" in source_lineage,
             "R30 must validate the pinned R9 T0/NativeGit source-lineage edges and immutable R32 source")
    return {
        "r29_47_member_no_go_inventory_uses_r30_provider": True,
        "historical_unmodified_rows_use_r30_provider": True,
        "six_historical_rebound_rows_use_exact_preserved_preimages": True,
        "six_active_rebound_rows_use_r30_provider": True,
        "six_current_rebinding_rows_and_both_preimage_receipts_verified": True,
        "supervisor_current_runtime_source_rebinding_is_separately_verified": True,
        "archive_member_physical_absence_stays_real": True,
        "no_direct_zip_member_reader_in_r30_verifier": True,
        "provider_bound_before_historical_lineage": True,
        "seven_receipt_source_lineage_bound_before_full_provider_check": True,
        "r9_t0_and_native_git_edges_verified": True,
        "r32_reviewed_native_git_checked_at_immutable_preimage": True,
        "full_214_provider_check_follows_lineage_reads": True,
        "current_r30_pin_checker_uses_typed_provider_and_parent_guard": True,
        "current_r30_pin_checker_fails_closed_on_provider_errors": True,
    }


def _check_archive_source_partition(protocol: Mapping[str, Any],
                                    r29_manifest: Mapping[str, Any],
                                    readiness: Mapping[str, Any]) -> None:
    contract = protocol["archive_input_provider"]
    inventory = r29_manifest["runtime_preflight"]["inventory"]
    expected_paths = sorted(item["path"] for item in inventory)
    _require(all(item.get("zip_member") == item.get("path") for item in inventory),
             "R29 archived members no longer bind their exact logical input paths")
    _require(r30._exact_json_equal(contract["zip_member_paths"], expected_paths),
             "R30 ZIP member paths do not match the exact R29 47-item inventory")
    summary = readiness.get("input_pins")
    _require(isinstance(summary, Mapping) and summary.get("total") == 214 and
             summary.get("workspace_count") == 167 and summary.get("zip_member_count") == 47,
             "readiness input partition is not the frozen 214/167/47 split")
    zip_rows = summary.get("zip_member_rows")
    _require(type(zip_rows) is list and len(zip_rows) == 47,
             "readiness archive-backed input rows are incomplete")
    pins = {row["path"]: row for row in protocol["input_pins"]}
    normalized_rows = [{key: row.get(key) for key in ("path", "bytes", "sha256")}
                       for row in sorted(zip_rows, key=lambda row: row["path"])]
    expected_rows = [pins[path] for path in expected_paths]
    _require(r30._exact_json_equal(normalized_rows, expected_rows),
             "readiness 47-row map differs from R29 input pins")


def _function_source(source: str, function_name: str, label: str) -> str:
    try:
        tree = ast.parse(source, filename=label)
    except SyntaxError as exc:
        raise r30.PreflightError(f"{label} is not valid Python: {exc}") from exc
    matches = [node for node in tree.body if isinstance(node, ast.FunctionDef) and
               node.name == function_name]
    _require(len(matches) == 1, f"{label} must define exactly one top-level {function_name}")
    node = matches[0]
    return "\n".join(source.splitlines()[node.lineno - 1:node.end_lineno])


def _check_protocol_file_integrity_source_contract() -> dict[str, bool]:
    runner_path = r30._physical_repo_path(r30.REL_RUNNER)
    source = runner_path.read_text(encoding="utf-8")
    loader = _function_source(source, "load_protocol_with_receipt", str(runner_path))
    verifier = _function_source(source, "verify_loaded_protocol_file", str(runner_path))
    dispatcher = _function_source(source, "dispatch_actual", str(runner_path))
    sequence = _function_source(source, "_run_stage_sequence", str(runner_path))
    stage_pass = _function_source(source, "_stage_pass", str(runner_path))
    shape = _function_source(source, "validate_protocol_shape", str(runner_path))

    _require("raw = path.read_bytes()" in loader and
             "json.loads(raw.decode(\"utf-8\"))" in loader and
             '"sha256": sha256_bytes(raw)' in loader,
             "R30 protocol receipt must bind the exact raw bytes parsed once")
    for fragment in ("path.resolve(strict=True)", "protocol_path.read_bytes()",
                     "sha256_bytes(raw)", "_exact_json_equal(observed, dict(expected_receipt))"):
        _require(fragment in verifier,
                 f"R30 loaded protocol integrity check lacks {fragment}")
    _require("protocol, loaded_protocol_receipt = load_protocol_with_receipt(protocol_path)" in dispatcher and
             '_ACTIVE_PROTOCOL_SHA256 = loaded_protocol_receipt["sha256"]' in dispatcher and
             '"protocol_sha256": loaded_protocol_receipt["sha256"]' in dispatcher and
             '"protocol_file_at_load": loaded_protocol_receipt' in dispatcher and
             "protocol_path, loaded_protocol_receipt)" in dispatcher,
             "R30 dispatch must use the exact raw-loaded protocol receipt through prelaunch/stages")
    before = sequence.find("protocol_before = verify_loaded_protocol_file(")
    launch = sequence.find("stage = dict(_run_stage(")
    after = sequence.find("protocol_after = verify_loaded_protocol_file(")
    _require(0 <= before < launch < after,
             "R30 stage must verify protocol bytes before and after its consumer launch")
    for fragment in ('stage["protocol_file_before"] = protocol_before',
                     'stage["protocol_file_after"] = protocol_after',
                     'stage["stop_reason"] = "protocol_file_drift"',
                     "if not passed:\n            return stages, failure"):
        _require(fragment in sequence,
                 f"R30 stage sequence no longer stops serial dispatch on protocol drift: {fragment}")
    _require(stage_pass.find('stage.get("protocol_file_integrity_complete") is not True') >= 0 and
             stage_pass.find('stage.get("protocol_file_integrity_complete") is not True') <
             stage_pass.find('raw = (output /'),
             "R30 consumer result marker is checked before protocol identity gate")
    _require("_exact_json_equal(dict(limits), expected_limits)" in shape and
             "_exact_json_equal(dict(parse_manifest), expected_parse_manifest)" in shape,
             "R30 numeric resource/manifest contracts must use strict JSON type comparison")
    _require("PARSE_REBINDING_MARKER not in raw" in stage_pass,
             "R30 parse stage pass gate must require the four-source rebinding marker")
    return {
        "raw_protocol_bytes_bound_to_parsed_object": True,
        "dispatch_uses_loaded_protocol_sha256": True,
        "each_stage_has_protocol_pre_and_post_checks": True,
        "protocol_drift_blocks_next_stage": True,
        "limits_and_parse_manifest_use_type_strict_json_equality": True,
        "protocol_scope_sha_is_the_raw_loaded_byte_sha": True,
        "parse_current_source_rebinding_marker_required": True,
    }


def _check_managed_stage_source_contract(protocol: Mapping[str, Any]) -> dict[str, Any]:
    runner_path = r30._physical_repo_path(r30.REL_RUNNER)
    runner_source = runner_path.read_text(encoding="utf-8")
    exact_loader = _function_source(runner_source, "_exec_exact_pinned_source", str(runner_path))
    stage = _function_source(runner_source, "_run_stage", str(runner_path))
    sequence = _function_source(runner_source, "_run_stage_sequence", str(runner_path))
    _require("compile(source_bytes" in exact_loader and "exec(code, module.__dict__)" in exact_loader and
             "spec.loader.exec_module" not in exact_loader,
             "R30 module imports must compile and execute the exact source bytes, never use pyc loader")
    startup_sample = stage.find("startup_sample = audit.sample_process_tree(")
    startup_acceptance = stage.find('"suspended_startup_sample"')
    root_resume = stage.find("session.resume_root_after_ack()")
    stdin_writer = stage.find("stdin_writer.start()")
    resume_gate = stage.rfind('if stop_reason == "natural_exit":', startup_acceptance, root_resume)
    _require(0 <= startup_sample < startup_acceptance < resume_gate < root_resume < stdin_writer and
             stage[startup_sample:root_resume].count("startup_sample = audit.sample_process_tree(") == 1 and
             "for attempt in" not in stage[startup_sample:root_resume] and
             "startup_found == startup_active" in stage[startup_sample:root_resume] and
             "if found != active_now:" in stage and
             'outcome="complete_suspended_root_boundary"' in stage and
             '"included_as_complete_resource_observation": True' in stage and
             '"incomplete_suspended_startup_boundary"' in stage,
             "R30 must persist one complete whole-tree startup sample before root resume, with no startup retry")
    for fragment in ("WindowsDebugLifecycle.spawn_suspended(", "session.resume_root_after_ack()",
                     "audit.sample_process_tree(", "resource_reader=session.resource_reader",
                     "snapshot_provider=recording_snapshot_provider(startup_sample_snapshots)",
                     "startup_seal = _seal_native_snapshot(startup_sample_snapshots[-1], table)",
                     "snapshot_provider=recording_snapshot_provider(sample_snapshots)",
                     "seal = _seal_native_snapshot(sample_snapshots[-1], table)",
                     "lifecycle_session=session", "session.exit_proof_complete",
                     "session.close()", "FCA_MANAGED_SCOPE_SHA256"):
        _require(fragment in stage, f"R30 actual stage is missing its managed lifecycle gate: {fragment}")
    _require("_seal_native_snapshot(snapshot_provider(), table)" not in stage and
             "startup_sample.get(\"native_snapshot_after_digest\", ())" in stage and
             "accepted.get(\"native_snapshot_after_digest\", ())" in stage,
             "sample acceptance seals must reuse the sampler's event-bracketed post-query snapshots")
    _require("subprocess.Popen(" not in stage and "subprocess.run(" not in stage and
             "_native_resource_reader(" not in stage,
             "R30 actual stage retains a Popen/PID-resource fallback")
    for fragment in ("verify_current_input_rebindings(",
                     "verify_managed_lifecycle_source_pins(",
                     "current_input_rebindings_before", "managed_process_lifecycle_source_pins_before",
                     "current_input_rebindings_after", "managed_process_lifecycle_source_pins_after"):
        _require(fragment in sequence,
                 f"R30 stage source/pin pre-post checks are missing: {fragment}")
    supervisor_path = r30._physical_repo_path(r30.REL_R23_SUPERVISOR)
    supervisor_source = supervisor_path.read_text(encoding="utf-8")
    sample = _function_source(supervisor_source, "sample_process_tree", str(supervisor_path))
    _require("sample_boundary_checkpoint(attempt_id)" in sample and
             "resource_reader(\n                    handle, lifecycle_identity_factory(identity), row" in sample and
             "lifecycle_session.release_boundary_events" not in sample,
             "R30 managed sampling does not hold event boundaries around exact-handle reads")
    lifecycle_pin = protocol.get("managed_process_lifecycle_source_pins", {}).get(
        r30.REL_LIFECYCLE_CORE)
    _require(isinstance(lifecycle_pin, Mapping) and
             _exact_lifecycle_pin(protocol, r30.REL_LIFECYCLE_CORE, lifecycle_pin),
             "R30 managed lifecycle core pin is absent or malformed")
    return {
        "exact_pinned_python_source_loader": True,
        "suspended_debug_lifecycle_stage": True,
        "no_popen_or_pid_resource_fallback_in_stage": True,
        "handle_first_resource_reader": True,
        "sample_debug_boundary_checkpoints": True,
        "suspended_startup_full_sample_before_root_resume": True,
        "failed_suspended_startup_sample_blocks_root_resume": True,
        "sample_acceptance_uses_event_bracketed_post_sample_snapshot": True,
        "source_pins_rechecked_before_and_after_each_stage": True,
        "lifecycle_source_pin": dict(lifecycle_pin),
    }


def _exact_lifecycle_pin(protocol: Mapping[str, Any], relative_path: str,
                         pin: Mapping[str, Any]) -> bool:
    expected = r30.EXPECTED_LIFECYCLE_SOURCE_PINS.get(relative_path)
    return expected is not None and r30._exact_json_equal(dict(pin), expected) and \
        r30._exact_json_equal(protocol.get("managed_process_lifecycle_source_pins", {}).get(relative_path),
                              expected)


def _test_suite_inventory() -> dict[str, Any]:
    test_path = r30._physical_repo_path(r30.REL_TEST)
    r28_test_path = r28.repo_path(r28.REL_TEST)
    r29_test_path = r29.repo_path(r29.REL_TEST)

    def classes(path: Path) -> dict[str, ast.ClassDef]:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        return {node.name: node for node in tree.body if isinstance(node, ast.ClassDef)}

    def direct_tests(node: ast.ClassDef) -> list[str]:
        return sorted(child.name for child in node.body
                      if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and
                      child.name.startswith("test_"))

    def base_name(node: ast.ClassDef) -> str:
        if not node.bases or not isinstance(node.bases[0], ast.Attribute):
            return ""
        return node.bases[0].attr

    def qualified_base_name(node: ast.ClassDef) -> str:
        if not node.bases or not isinstance(node.bases[0], ast.Attribute):
            return ""
        base = node.bases[0]
        if not isinstance(base.value, ast.Name):
            return ""
        return f"{base.value.id}.{base.attr}"

    current = classes(test_path)
    old28 = classes(r28_test_path)
    old29 = classes(r29_test_path)
    required_bases = {
        "R30InheritedSampleRaceRecoveryTests": "R28SampleRaceRecoveryTests",
        "R30InheritedOrphanChainRecoveryTests": "R28OrphanChainRecoveryTests",
        "R30InheritedLaunchBindingFailureTests": "R28LaunchBindingFailureTests",
        "R30InheritedTreeCleanupFallbackTests": "R28TrackedTreeCleanupFallbackTests",
        "R30InheritedPidReuseRecoveryTests": "R29NaturalExitPidReuseTests",
        "R30InheritedR28ProtocolContractTests": "R28ProtocolContractTests",
    }
    for name, expected_base in required_bases.items():
        _require(name in current and base_name(current[name]) == expected_base,
                 f"R30 suite no longer inherits the intended original fault fixture: {name}")
    expected_old_counts = {
        "R28SampleRaceRecoveryTests": 6,
        "R28OrphanChainRecoveryTests": 6,
        "R28LaunchBindingFailureTests": 2,
        "R28TrackedTreeCleanupFallbackTests": 3,
    }
    for name, count in expected_old_counts.items():
        _require(name in old28 and len(direct_tests(old28[name])) == count,
                 f"R28 inherited fixture shape changed: {name}")
    expected_r28_protocol_names = {
        "test_frozen_r13_resource_and_consumer_gates",
        "test_static_and_actual_argv_roles_do_not_alias",
        "test_stage_commands_use_one_frozen_consumer_and_only_compile_min_delta",
        "test_stage_contract_mutation_is_rejected",
        "test_failed_launch_cleanup_contract_mutation_is_rejected",
        "test_protocol_rejects_duplicate_or_missing_source_pins",
        "test_pin_checker_detects_modified_input_without_dispatch",
        "test_runtime_entry_requires_explicit_dispatch_mode",
        "test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit",
        "test_r23_exact_generation_apis_are_the_only_runtime_identity_path",
        "test_root_bind_failure_routes_to_original_handle_cleanup",
        "test_tree_failure_has_same_handle_fallback_and_serial_stage_stop",
        "test_sample_race_contract_records_exact_transition_and_forbids_unresolved_clear",
    }
    _require("R28ProtocolContractTests" in old28 and
             set(direct_tests(old28["R28ProtocolContractTests"])) == expected_r28_protocol_names and
             len(expected_r28_protocol_names) == 13,
             "R28 protocol-contract test set is incomplete or changed")
    inherited_protocol = current.get("R30InheritedR28ProtocolContractTests")
    test_source = test_path.read_text(encoding="utf-8")
    r13_wrapper_name = "test_frozen_r13_resource_and_consumer_gates"
    r13_wrapper = next((child for child in inherited_protocol.body
                        if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and
                        child.name == r13_wrapper_name), None) if inherited_protocol else None
    r13_wrapper_source = ast.get_source_segment(test_source, r13_wrapper) if r13_wrapper else None
    _require(inherited_protocol is not None and
             direct_tests(inherited_protocol) == [r13_wrapper_name] and
             qualified_base_name(inherited_protocol) ==
             "r28_contract_support.R28ProtocolContractTests" and
             r13_wrapper_source is not None and
             "provider = _ensure_r30_input_provider()" in r13_wrapper_source and
             "legacy_runner = r28_contract_support.r28" in r13_wrapper_source and
             "provider.repo_path_adapter(legacy_runner.repo_path)" in r13_wrapper_source and
             'patch.object(legacy_runner, "repo_path", new=adapted_repo_path)' in
             r13_wrapper_source and
             f"super().{r13_wrapper_name}()" in r13_wrapper_source and
             "spec_from_file_location(" in test_source and
             "r28_fixture_support.r28 = r30" in test_source and
             "r28_fixture_support.PROTOCOL = r30.repo_path" not in test_source,
             "R30 must isolate the 13 unchanged R28 contract tests, allowing only the exact R13 provider adapter")
    _require("R29NaturalExitPidReuseTests" in old29 and
             len(direct_tests(old29["R29NaturalExitPidReuseTests"])) == 2,
             "R29 two-case PID-reuse fixture changed")
    expected_direct_counts = {
        "R30PinnedZipInputProviderTests": 17,
        "R30InheritedOrphanChainRecoveryTests": 2,
        "R30InheritedTreeCleanupFallbackTests": 1,
        "R30InheritedSourceContractTests": 8,
    }
    for name, count in expected_direct_counts.items():
        _require(name in current and len(direct_tests(current[name])) == count,
                 f"R30 current test coverage changed unexpectedly: {name}")
    expected_orphan_overrides = {
        "test_orphan_descendant_missing_or_reused_before_bind_is_unaccounted",
        "test_unaccounted_orphan_chain_stops_serial_sequence_before_replay",
    }
    orphan_class = current["R30InheritedOrphanChainRecoveryTests"]
    orphan_method = next((child for child in orphan_class.body
                          if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and
                          child.name ==
                          "test_orphan_descendant_missing_or_reused_before_bind_is_unaccounted"),
                         None)
    orphan_source = ast.get_source_segment(test_source, orphan_method) if orphan_method else None
    cases_assignment = next((child for child in ast.walk(orphan_method)
                             if isinstance(child, ast.Assign) and
                             any(isinstance(target, ast.Name) and target.id == "cases"
                                 for target in child.targets)), None) if orphan_method else None
    case_rows = cases_assignment.value.elts if (
        cases_assignment is not None and isinstance(cases_assignment.value, ast.List)) else []
    try:
        orphan_scenarios = [ast.literal_eval(row.elts[0]) for row in case_rows
                            if isinstance(row, ast.Tuple) and len(row.elts) == 3]
        parent_reuse_reason = ast.literal_eval(case_rows[2].elts[2]) if len(case_rows) == 3 else None
    except (IndexError, TypeError, ValueError):
        orphan_scenarios = []
        parent_reuse_reason = None
    _require(set(direct_tests(orphan_class)) == expected_orphan_overrides and
             orphan_scenarios == [
                 {"fresh_descendants": False},
                 {"child_generation_reuse": True},
                 {"parent_generation_reuse": True},
             ] and parent_reuse_reason ==
             "missing_tracked_generation_pid_reused_after_natural_exit" and
             orphan_source is not None and
             'self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")' in orphan_source and
             'self.assertFalse(stage["resource_monitor_complete"])' in orphan_source and
             'self.assertFalse(stage["final_residual_audit"]["residual_clear"])' in orphan_source and
             'self.assertEqual(stage["sample_recovery_count"], 0)' in orphan_source and
             'self.assertIs(recovery.get("retry_authorized"), False)' in orphan_source and
             'self.assertEqual(recovery.get("retry_count"), 0)' in orphan_source and
             'self.assertIs(recovery.get("residual_clear"), False)' in orphan_source and
             'self.assertFalse(stage["numerical_credit"])' in orphan_source and
             'self.assertFalse(stage["physical_credit"])' in orphan_source,
             "R30 orphan overrides must retain the exact three fail-closed scenarios and zero-credit/retry checks")
    required_provider_tests = {
        "test_loaded_protocol_receipt_is_exact_and_rejects_missing_drift_path_and_type_aliases",
        "test_protocol_file_integrity_brackets_stage_and_drift_blocks_later_stages",
        "test_shape_validator_rejects_numeric_type_aliases_in_limits_and_manifest",
        "test_r29_archived_restore_no_go_inventory_is_verified_by_r30_provider",
        "test_r29_parent_requires_exact_ordered_214_rows_and_every_field",
        "test_workspace_drift_or_absence_never_falls_back_to_zip",
        "test_archive_backed_path_appearing_or_archive_identity_drifting_fails",
        "test_current_runner_pin_check_rejects_parent_row_drift_and_provider_failure",
    }
    required_source_tests = {
        "test_dispatch_binds_raw_protocol_receipt_through_prelaunch_and_every_stage",
        "test_r29_archive_lineage_and_214_pins_use_only_the_r30_provider",
    }
    _require(required_provider_tests.issubset(set(direct_tests(current["R30PinnedZipInputProviderTests"]))) and
             required_source_tests.issubset(set(direct_tests(current["R30InheritedSourceContractTests"]))),
             "R30 receipt/stage/type-strict test controls are missing")
    _require(
        'r30.verify_input_pins(altered, "r30_mutated_parent_pin")' in test_source and
        'r30.verify_input_pins(protocol, "r30_provider_failure")' in test_source,
        "R30 suite lacks direct mutated-row and provider-failure calls through verify_input_pins")
    current_r30_tree_test = "test_tree_failure_has_same_handle_fallback_and_serial_stage_stop"
    _require(current_r30_tree_test in direct_tests(current["R30InheritedSourceContractTests"]) and
             "r28_fixture_support.r28 = r30" in test_source,
             "R30 tree cleanup contract must test the live R30 runner and rebound process fixtures")
    # The R30 suite carries all 17 original R28 process fixtures, all 13
    # isolated historical protocol-contract tests (with only the exact R13
    # provider adapter), two R29 PID-reuse tests, and 25 current R30
    # provider/source-contract cases. R30 fixture methods replace inherited
    # methods with the same names, so they do not increase discovery count.
    total = expected_direct_counts["R30PinnedZipInputProviderTests"] + \
        expected_direct_counts["R30InheritedSourceContractTests"] + \
        sum(expected_old_counts.values()) + len(expected_r28_protocol_names) + 2
    _require(total == 57 and total == 30 + 2 + 25,
             "R30 declared inherited/provider test total changed")
    return {
        "r30_declared_test_cases": total,
        "r30_specific_cases": 25,
        "inherited_r28_total_cases": 30,
        "provider_and_stdin_cases": expected_direct_counts["R30PinnedZipInputProviderTests"],
        "source_contract_cases": expected_direct_counts["R30InheritedSourceContractTests"],
        "inherited_r28_sample_race_cases": expected_old_counts["R28SampleRaceRecoveryTests"],
        "inherited_r28_orphan_chain_cases": expected_old_counts["R28OrphanChainRecoveryTests"],
        "inherited_r28_launch_binding_cases": expected_old_counts["R28LaunchBindingFailureTests"],
        "inherited_r28_tree_cleanup_cases": expected_old_counts["R28TrackedTreeCleanupFallbackTests"],
        "inherited_r28_protocol_contract_cases": len(expected_r28_protocol_names),
        "inherited_r28_protocol_contract_test_names": sorted(expected_r28_protocol_names),
        "r28_protocol_contract_module_isolated_from_r30_fixture_rebinding": True,
        "inherited_r29_pid_reuse_cases": 2,
        "protocol_receipt_and_stage_integrity_controls": sorted(required_provider_tests),
        "dispatch_receipt_binding_controls": sorted(required_source_tests),
        "provider_and_stdin_test_names": direct_tests(current["R30PinnedZipInputProviderTests"]),
        "r28_inherited_test_names": {
            name: direct_tests(old28[name]) for name in expected_old_counts
        },
        "r30_orphan_override_test_names": direct_tests(orphan_class),
        "r28_protocol_contract_test_names": direct_tests(old28["R28ProtocolContractTests"]),
        "r30_r13_adapter_test_names": direct_tests(inherited_protocol),
        "r30_current_input_pin_behavior_test_names": sorted({
            "test_r29_parent_requires_exact_ordered_214_rows_and_every_field",
            "test_workspace_drift_or_absence_never_falls_back_to_zip",
            "test_archive_backed_path_appearing_or_archive_identity_drifting_fails",
            "test_current_runner_pin_check_rejects_parent_row_drift_and_provider_failure",
        }),
        "r30_current_tree_behavior_test_names": {
            "inherited_r28_process_fixtures_run_on_r30": direct_tests(
                old28["R28TrackedTreeCleanupFallbackTests"]),
            "r30_tree_contract": current_r30_tree_test,
        },
        "r29_pid_reuse_test_names": direct_tests(old29["R29NaturalExitPidReuseTests"]),
    }


def main() -> int:
    global r30, r30_builder
    parser = argparse.ArgumentParser()
    parser.add_argument("--protocol", required=True)
    args = parser.parse_args()
    requested = Path(args.protocol)
    try:
        if requested.is_symlink() or not requested.is_file():
            raise ValueError("R30 verifier protocol must be the regular frozen workspace file")
        protocol_path = requested.resolve(strict=True)
        expected_protocol_path = (ROOT / REL_R30_PROTOCOL).resolve(strict=True)
        if protocol_path != expected_protocol_path:
            raise ValueError("static verifier must inspect the unique frozen R30 protocol")
        bootstrap_raw = protocol_path.read_bytes()
        bootstrap_protocol = json.loads(bootstrap_raw.decode("utf-8"),
                                         object_pairs_hook=_unique_json_object)
        if type(bootstrap_protocol) is not dict or \
                bootstrap_protocol.get("schema") != "native-g1g2-gridap-consumer-r30-protocol-v1":
            raise ValueError("R30 protocol bootstrap schema mismatch")
        r30, runner_source_load = _load_r30_source_exact(
            bootstrap_protocol, REL_R30_RUNNER, "run_native_g1g2_gridap_consumer_r30_v1")
        r30_builder, builder_source_load = _load_r30_source_exact(
            bootstrap_protocol, REL_R30_BUILDER, "build_protocol_r30_v1")
        if protocol_path.resolve(strict=True) != r30.repo_path(r30.REL_PROTOCOL).resolve(strict=True):
            raise ValueError("loaded R30 source resolves a different protocol path")
        protocol, loaded_receipt = r30.load_protocol_with_receipt(protocol_path)
        bootstrap_receipt = {"path": str(protocol_path), "bytes": len(bootstrap_raw),
                             "sha256": hashlib.sha256(bootstrap_raw).hexdigest()}
        if not r30._exact_json_equal(loaded_receipt, bootstrap_receipt):
            raise ValueError("R30 protocol bytes changed between bootstrap and exact runner load")
    except Exception as exc:
        print(json.dumps({"status": "r30_static_preflight_failed",
                          "error": f"exact source/protocol bootstrap failed: {type(exc).__name__}: {exc}",
                          "julia_started": False, "runtime_executed": False,
                          "numerical_credit": False, "physical_credit": False}, sort_keys=True),
              file=sys.stderr)
        return 1
    _require(loaded_receipt.get("path") == str(protocol_path) and
             type(loaded_receipt.get("bytes")) is int and
             re.fullmatch(r"[0-9a-f]{64}", str(loaded_receipt.get("sha256"))) is not None,
             "R30 protocol raw-byte load receipt is malformed")
    provider = r30.bind_input_provider(protocol)
    r30.validate_protocol_shape(protocol)
    readiness = _check_archive_contract(protocol)
    r29_protocol, r29_manifest, restore_member_count, r28_receipt_count = \
        _check_r29_lineage(protocol, provider)
    current_source_lineage_receipt = _check_current_input_source_lineage(protocol, r29_protocol)
    _check_archive_source_partition(protocol, r29_manifest, readiness)

    # The provider performs full read-only checks over all 214 inputs and verifies
    # that the ZIP archive identity is unchanged around all historical member reads.
    pin_receipt = r30.verify_input_pins(protocol, "r30_static_verifier")
    _require(pin_receipt["complete"] is True and pin_receipt["checked_count"] == 214 and
             pin_receipt["source_counts"] == {"workspace": 167, "zip_member": 47} and
             pin_receipt["missing"] == [] and pin_receipt["changed"] == [],
             "R30 provider failed to verify all exact 214 source rows")
    _require(pin_receipt["archive_before"] == pin_receipt["archive_after"] == ARCHIVE_IDENTITY,
             "R30 input archive changed during static input verification")
    current_rebind_receipt = pin_receipt.get("current_input_rebindings")
    lifecycle_pin_receipt = pin_receipt.get("managed_process_lifecycle_source_pins")
    _require(isinstance(current_rebind_receipt, Mapping) and
             current_rebind_receipt.get("complete") is True and
             current_rebind_receipt.get("count") == 6 and
             len(current_rebind_receipt.get("rows", [])) == 6 and
             isinstance(lifecycle_pin_receipt, Mapping) and
             lifecycle_pin_receipt.get("complete") is True and
             lifecycle_pin_receipt.get("count") == 3 and
             len(lifecycle_pin_receipt.get("rows", [])) == 3,
             "R30 current-source rebindings/lifecycle pins are not fully checked")
    owned_source_receipt = r30.verify_owned_source_pins(
        protocol, "r30_static_verifier_report")
    _require(owned_source_receipt.get("complete") is True and
             owned_source_receipt.get("count") == 6 and
             len(owned_source_receipt.get("rows", [])) == 6,
             "R30 owned runner/test/verifier/provider/parser/builder source set is incomplete")
    absent_zip_count = 0
    for logical in protocol["archive_input_provider"]["zip_member_paths"]:
        physical = provider.physical_path(logical)
        _require(not physical.exists() and not physical.is_file(),
                 f"R30 ZIP-backed path was materialized in the checkout: {logical}")
        absent_zip_count += 1
    _require(absent_zip_count == 47, "R30 strict ZIP source map no longer has 47 absent physical files")

    execution = protocol["execution_plan"]
    manifest_contract = execution.get("parse_manifest")
    _require(r30._exact_json_equal(manifest_contract, PARSE_MANIFEST_CONTRACT),
             "R30 parse manifest identity/type differs from the original pinned 108-row manifest")
    manifest_bytes, manifest_receipt = r30.prepare_parse_manifest_stdin(provider, manifest_contract)
    _require(len(manifest_bytes) == PARSE_MANIFEST_CONTRACT["bytes"] and
             manifest_receipt == {"path": PARSE_MANIFEST_CONTRACT["path"],
                                  "bytes": PARSE_MANIFEST_CONTRACT["bytes"],
                                  "sha256": PARSE_MANIFEST_CONTRACT["sha256"],
                                  "source": "zip_member"},
             "R30 parse-all stdin bytes/receipt differ from the original manifest pin")
    _require(not provider.physical_path(PARSE_MANIFEST_CONTRACT["path"]).exists(),
             "R30 original parse manifest was materialized into the checkout")

    output = r30.repo_path(protocol["planned_output_leaf"])
    _require(protocol["planned_output_leaf"] == r30.REL_OUTPUT and not output.exists(),
             "R30 formal output leaf must remain absent during static verification")
    planned = r30.planned_stage_commands(protocol, output)
    _require(planned == execution.get("stage_commands") and
             [row["stage"] for row in planned] == ["parse_all", "primary", "fresh_replay"],
             "R30 formal-consumer stage argv differs from its frozen serial plan")
    invocation = protocol.get("invocation_contract")
    _require(isinstance(invocation, Mapping), "R30 invocation roles are absent")
    observed_argv = list(getattr(sys, "orig_argv", []))
    if not observed_argv:
        observed_argv = [sys.executable, *sys.argv]
    r30.validate_invocation("static_verifier", observed_argv, protocol)

    python = invocation["python_interpreter"]
    julia = execution["julia_executable"]
    for label, item in (("pinned Python", python), ("pinned Julia", julia)):
        path = Path(item["path"])
        _require(not path.is_symlink() and path.is_file(), f"{label} executable is unavailable")
        raw = path.read_bytes()
        _require(len(raw) == item["bytes"] and hashlib.sha256(raw).hexdigest() == item["sha256"],
                 f"{label} executable differs from its frozen bytes/hash")

    static_qa = protocol.get("static_qa")
    _require(isinstance(static_qa, Mapping) and
             static_qa.get("verifier_command") ==
             " ".join(invocation["static_verifier_argv"]) and
             static_qa.get("r30_input_provider_tests_command") ==
             f"{python['path']} -B {r30.repo_path(r30.REL_TEST)} -v" and
             static_qa.get("runtime_output_leaf_absent") is True and
             static_qa.get("julia_started") is False and
             static_qa.get("runtime_executed") is False,
             "R30 static QA commands or no-runtime boundary changed")
    for key in ("python_tests_command", "bind_failure_fault_injection_command",
                "tree_cleanup_fault_injection_command", "sample_race_fault_injection_command",
                "orphan_chain_fault_injection_command", "pid_reuse_fault_injection_command"):
        _require(static_qa.get(key) == r29_protocol["static_qa"].get(key),
                 f"R30 changed a frozen R28/R29 fault-suite command: {key}")
    suite_shape = _test_suite_inventory()
    protocol_integrity_contract = _check_protocol_file_integrity_source_contract()
    managed_stage_contract = _check_managed_stage_source_contract(protocol)
    historical_archive_contract = _check_r29_archive_provider_source_contract()

    before_inheritance = protocol.get("acceptance_boundary")
    _require(isinstance(before_inheritance, Mapping) and
             before_inheritance.get("numerical_credit") is False and
             before_inheritance.get("physical_credit") is False and
             before_inheritance.get("runtime_executed") is False and
             protocol.get("runtime_grant") is False and
             protocol.get("fixture_and_solver_thresholds_unchanged") is True,
             "R30 preparation protocol grants runtime or scientific credit")

    protocol_post_receipt = r30.verify_loaded_protocol_file(
        protocol_path, loaded_receipt, "r30_static_verifier_post")
    _require(r30._exact_json_equal(
        {key: value for key, value in protocol_post_receipt.items()
         if key not in ("phase", "complete")}, loaded_receipt),
        "R30 protocol bytes changed during static verification")
    _require(not output.exists(), "R30 output leaf appeared during static verification")
    print(json.dumps({
        "status": "r30_static_protocol_and_inputs_verified_no_runtime",
        "protocol_schema": protocol["schema"],
        "protocol_load_receipt": loaded_receipt,
        "r30_exact_source_load_receipts": [runner_source_load, builder_source_load],
        "protocol_post_receipt": protocol_post_receipt,
        "archive_identity": ARCHIVE_IDENTITY,
        "archive_input_provider_identity_checked_in_runner_builder_protocol_and_readiness": True,
        "r29_input_pin_count": 214,
        "r30_input_pin_count_verified": pin_receipt["checked_count"],
        "input_source_counts": pin_receipt["source_counts"],
        "r30_owned_source_pins_verified": owned_source_receipt["rows"],
        "zip_backed_physical_paths_absent": absent_zip_count,
        "archive_before_after_equal": pin_receipt["archive_before"] == pin_receipt["archive_after"],
        "r29_archived_restore_members_verified": restore_member_count,
        "r29_archived_restore_members_verified_through_r30_provider": restore_member_count,
        "r28_historical_receipt_files_checked": r28_receipt_count,
        "r28_historical_full_suite":
            "29/30 passed; 1 errored because R13 summary was absent; historical only",
        "r29_historical_pid_reuse_suite": "2/2 pinned Python fault-injection pass",
        "r30_declared_coverage": suite_shape,
        "r30_protocol_integrity_source_contract": protocol_integrity_contract,
        "r30_managed_stage_source_contract": managed_stage_contract,
        "r30_current_input_rebindings_verified": current_rebind_receipt["rows"],
        "r30_current_input_source_lineage_verified": current_source_lineage_receipt,
        "r30_current_input_rebinding_preimage_receipts_verified":
            current_rebind_receipt["preimage_receipts"],
        "r30_current_input_rebinding_scope": {
            "all_six_current_rows_verified": current_rebind_receipt["count"] == 6,
            "six_historical_preimages_verified": True,
            "six_current_workspace_rows_verified_through_provider": True,
            "sixth_supervisor_source_current_and_preimage_verified": True,
            "historical_214_input_pins_unchanged": True,
        },
        "r30_managed_process_lifecycle_sources_verified": lifecycle_pin_receipt["rows"],
        "historical_archive_provider_source_contract": historical_archive_contract,
        "parse_manifest_stdin_bytes": len(manifest_bytes),
        "parse_manifest_sha256": manifest_receipt["sha256"],
        "stage_order": execution["stage_order"],
        "planned_stage_argv_verified": True,
        "planned_output_leaf_absent": True,
        "julia_started": False,
        "runtime_executed": False,
        "numerical_credit": False,
        "physical_credit": False,
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except r30.PreflightError as exc:
        print(json.dumps({"status": "r30_static_preflight_failed", "error": str(exc),
                          "julia_started": False, "runtime_executed": False,
                          "numerical_credit": False, "physical_credit": False}, sort_keys=True),
              file=sys.stderr)
        raise SystemExit(1)
