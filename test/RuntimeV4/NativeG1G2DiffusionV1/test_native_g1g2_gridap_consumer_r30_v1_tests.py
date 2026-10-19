"""Focused tests for the R30 read-only pinned ZIP input provider.

These fixtures exercise the production provider against temporary inputs. They
do not restore repository files or launch the Gridap consumer.
"""

from __future__ import annotations

import contextlib
import copy
import hashlib
import io
import importlib.util
import json
import stat
import sys
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any
from unittest.mock import patch

from pinned_zip_input_provider_r30_v1 import PinnedInputError, PinnedZipInputProvider
import run_native_g1g2_gridap_consumer_r30_v1 as r30
import verify_native_g1g2_gridap_consumer_r30_v1 as r30_verifier
import test_native_g1g2_gridap_consumer_r28_v1 as r28_fixture_support
import test_native_g1g2_gridap_consumer_r29_v1 as r29_pid_reuse_support

# Load an isolated, unmodified copy for the 13 historical R28 protocol tests.
# The separate fixture module below is rebound to R30 for the 17 process-tree
# fixtures; that rebinding must not redirect historical R28 contract tests.
_r28_contract_spec = importlib.util.spec_from_file_location(
    "native_g1g2_r28_protocol_contracts_legacy_r30",
    r28_fixture_support.__file__,
)
if _r28_contract_spec is None or _r28_contract_spec.loader is None:
    raise ImportError("could not load the isolated legacy R28 protocol-contract tests")
r28_contract_support = importlib.util.module_from_spec(_r28_contract_spec)
sys.modules[_r28_contract_spec.name] = r28_contract_support
_r28_contract_spec.loader.exec_module(r28_contract_support)

# Reuse the historical fake process-table fixtures while directing their calls
# at the real R30 supervisor implementation.
r28_fixture_support.r28 = r30
r29_pid_reuse_support.r29 = r30
r29_pid_reuse_support.fixture_support.r28 = r30


def _adapt_legacy_r28_snapshot_to_r23(table: Any, snapshot: Any) -> Any:
    """Keep the historical fake rows but supply R30's real typed SPI envelope."""
    if isinstance(snapshot, table.ProcessTableSnapshot):
        return table.validate_snapshot(snapshot)
    sentinel_ticks = 134345421481717430
    source_pids = {row.identity.pid for row in snapshot.rows}
    rows = []
    if 0 not in source_pids:
        rows.append(table.ProcessRow(table.ProcessIdentity(0, sentinel_ticks), 0, ""))
    if 4 not in source_pids:
        rows.append(table.ProcessRow(table.ProcessIdentity(4, sentinel_ticks), 0, "System"))
    for row in snapshot.rows:
        rows.append(table.ProcessRow(
            table.ProcessIdentity(row.identity.pid, row.identity.create_time_100ns),
            row.ppid, row.name))
    return table.ProcessTableSnapshot(
        rows=tuple(rows), host_identity=table.WINDOWS_BUILD_PIN,
        buffer_bytes=table.SPI_FIXED_HEADER_BYTES, query_attempts=1, ntstatus_u32=0)


def _install_r30_typed_spi_adapter_for_r28_fixtures() -> None:
    """Adapt only R30's imported legacy fixtures; leave the R28 source untouched."""
    protocol = r30.load_protocol(r30.repo_path(r30.REL_PROTOCOL))
    r30.validate_protocol_shape(protocol)
    table, _supervisor = r30._load_r23(protocol)
    for fixture_type in (
        r28_fixture_support._R28RaceTable,
        r28_fixture_support._R28OrphanChainTable,
        r29_pid_reuse_support._ReusedParentDisappearsTable,
    ):
        original_query = fixture_type.query_native_process_table

        def query_native_process_table(self: Any, _query: Any = original_query) -> Any:
            return _adapt_legacy_r28_snapshot_to_r23(table, _query(self))

        fixture_type.query_native_process_table = query_native_process_table
        fixture_type.validate_snapshot = staticmethod(table.validate_snapshot)
        fixture_type.native_snapshot_digest = staticmethod(table.native_snapshot_digest)
        fixture_type.ProcessTableError = table.ProcessTableError


_install_r30_typed_spi_adapter_for_r28_fixtures()


ARCHIVE_SCHEMA = "native-g1g2-r30-archive-input-provider-v1"
MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS = (
    "tools/execution/windows_process_lifecycle.py",
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
MANAGED_PROCESS_LIFECYCLE_JULIA_SOURCE_PATHS = (
    "src/GenomeV5/Integration/ManagedExternalProcessV1.jl",
    "src/GenomeV5/Integration/NativeGitReadCompatibilityV1.jl",
)
R30_CURRENT_INPUT_REBINDING_PATHS = (
    "Project.toml",
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
    "test/RuntimeV4/NativeG1G2DiffusionV1/supervise_r16_root_audit_r23_v1.py",
)
R30_PARSE_SOURCE_REBINDING_PATHS = (
    "src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl",
    "src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl",
    "test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl",
)
R30_REFROZEN_PROTOCOL = (
    "runs/NativeG1G2DiffusionV1/managed_lifecycle_refreeze_root_20260928_r1/protocol.json"
)
R30_HISTORICAL_E2CD_PROTOCOL = (
    "runs/NativeG1G2DiffusionV1/managed_lifecycle_refreeze_root_20260927_r1/protocol.json"
)
R30_HISTORICAL_E2CD_PROTOCOL_BYTES = 97_050
R30_HISTORICAL_E2CD_PROTOCOL_SHA256 = (
    "e2cde62a071977d598a2bd7189412d26615848b2efcd1ba9d4a6398a9e524d28"
)
R30_REFROZEN_OUTPUT = (
    "runs/NativeG1G2DiffusionV1/managed_lifecycle_formal_root_20260927_r1"
)
R30_PREIMAGE_RECEIPT_CONTRACT = {
    "schema": "native-g1g2-r30-current-input-rebinding-preimage-receipts-v1",
    "foundation_integration_receipt": {
        "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
                "live_foundation_integration/integration_receipt.json",
        "bytes": 6850,
        "sha256": "1740d82f1899582c466ca993095528461108b2ffc7963417af17556c930a87b8",
    },
    "supervisor_preimage_receipt": {
        "path": "runs/e/lifecycle_systemic_repair_20260927_r1/"
                "live_consumer_integration/preimage_receipt.json",
        "bytes": 5570,
        "sha256": "11f4574b48ed25256bfc450cffb0fcab6381a24d64c22ea3973921a1cd4f3370",
    },
}
R30_FROZEN_SOURCE_PINS = {
    "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r30_v1.py": {
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/run_native_g1g2_gridap_consumer_r30_v1.py",
        "bytes": 190_165,
        "sha256": "49bb68b698b6501ed05f34e16e4122d3424dd41c8cd3e6a88be7ea87fbcf0fca",
    },
    "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r30_v1.py": {
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/verify_native_g1g2_gridap_consumer_r30_v1.py",
        "bytes": 67_700,
        "sha256": "a47f7383acb0af1299d6ea2b4dd8c6dc17589a03a3610a8b450c494c23d2f8af",
    },
    "test/RuntimeV4/NativeG1G2DiffusionV1/build_protocol_r30_v1.py": {
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/build_protocol_r30_v1.py",
        "bytes": 34_622,
        "sha256": "ed8d0680f816218256f2e6d97a90b8c92bcace056e64fbce405251c9e70b7c9b",
    },
    "test/RuntimeV4/NativeG1G2DiffusionV1/parse_manifest_r30_stdin_v1.jl": {
        "path": "test/RuntimeV4/NativeG1G2DiffusionV1/parse_manifest_r30_stdin_v1.jl",
        "bytes": 9_515,
        "sha256": "b7cb98cce8dba0107c7551ff809a4978a1926ab3fbf4644c394447ef765defe1",
    },
}


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _ensure_r30_input_provider() -> Any:
    """Bind the real R30 archive provider for direct shape/legacy reads."""
    protocol = r30.load_protocol(r30.repo_path(r30.REL_PROTOCOL))
    if r30._INPUT_PROVIDER is None:
        return r30.bind_input_provider(protocol)
    return r30._INPUT_PROVIDER


def _fixture(
    base: Path,
    *,
    archive_entries: list[tuple[str | zipfile.ZipInfo, bytes]],
    zip_pins: dict[str, bytes],
    workspace_files: dict[str, bytes] | None = None,
    zip_member_paths: list[str] | None = None,
) -> tuple[dict[str, Any], Path, Path]:
    repo = base / "repo"
    repo.mkdir()
    local = workspace_files or {}
    for logical, data in local.items():
        target = repo.joinpath(*PurePosixPath(logical).parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    archive = base / "inputs.zip"
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            for member, data in archive_entries:
                bundle.writestr(member, data)

    pins = [
        {"path": logical, "bytes": len(data), "sha256": _sha256(data)}
        for logical, data in {**zip_pins, **local}.items()
    ]
    protocol = {
        "input_pins": sorted(pins, key=lambda row: row["path"]),
        "archive_input_provider": {
            "schema": ARCHIVE_SCHEMA,
            "path": str(archive),
            "bytes": archive.stat().st_size,
            "sha256": _sha256(archive.read_bytes()),
            "zip_member_paths": (sorted(zip_pins) if zip_member_paths is None
                                 else zip_member_paths),
        },
    }
    return protocol, repo, archive


class R30PinnedZipInputProviderTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="native_g1g2_r30_provider_")
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)

    def test_r29_parent_requires_exact_ordered_214_rows_and_every_field(self) -> None:
        parent_path = r30.repo_path(r30.REL_R29_PROTOCOL)
        raw = parent_path.read_bytes()
        parent = json.loads(raw.decode("utf-8"))
        parent_rows = parent["input_pins"]
        self.assertEqual(len(parent_rows), 214)

        def candidate(rows: list[dict[str, Any]]) -> dict[str, Any]:
            return {
                "parent_lineage": {"r29_protocol": dict(r30.R29_PROTOCOL_PIN)},
                "input_pins": rows,
            }

        positive = r30.verify_r29_parent_protocol(
            candidate([dict(row) for row in parent_rows]), "unit_positive")
        self.assertTrue(positive["complete"])
        self.assertTrue(positive["input_pins_exactly_match"])
        self.assertEqual(positive["input_pin_count"], 214)

        reordered = [dict(row) for row in parent_rows]
        reordered[0], reordered[1] = reordered[1], reordered[0]

        extra_field = [dict(row) for row in parent_rows]
        extra_field[0]["unbound_extra_field"] = "must be rejected"

        altered_value = [dict(row) for row in parent_rows]
        old_sha = altered_value[0]["sha256"]
        altered_value[0]["sha256"] = ("0" if old_sha[0] != "0" else "1") + old_sha[1:]

        altered_json_type = [dict(row) for row in parent_rows]
        altered_json_type[0]["bytes"] = float(altered_json_type[0]["bytes"])

        for label, rows in (
            ("reordered_rows", reordered),
            ("extra_row_field", extra_field),
            ("altered_row_value", altered_value),
            ("int_to_float_same_value", altered_json_type),
        ):
            with self.subTest(case=label):
                self.assertEqual(len(rows), 214)
                with self.assertRaisesRegex(
                    r30.PreflightError,
                    "R30 input_pins must equal the complete ordered R29 214-row list",
                ):
                    r30.verify_r29_parent_protocol(candidate(rows), f"unit_{label}")

    def test_current_runner_pin_check_rejects_parent_row_drift_and_provider_failure(self) -> None:
        self.assertEqual(r30.REL_PROTOCOL, R30_REFROZEN_PROTOCOL)
        self.assertEqual(r30_verifier.REL_R30_PROTOCOL, R30_REFROZEN_PROTOCOL)
        self.assertEqual(r30.REL_OUTPUT, R30_REFROZEN_OUTPUT)
        historical_path = r30.repo_path(R30_HISTORICAL_E2CD_PROTOCOL)
        self.assertNotEqual(R30_HISTORICAL_E2CD_PROTOCOL, R30_REFROZEN_PROTOCOL)
        self.assertTrue(historical_path.is_file())
        self.assertFalse(historical_path.is_symlink())
        historical_raw = historical_path.read_bytes()
        self.assertEqual(len(historical_raw), R30_HISTORICAL_E2CD_PROTOCOL_BYTES)
        self.assertEqual(_sha256(historical_raw), R30_HISTORICAL_E2CD_PROTOCOL_SHA256)
        historical_stderr = io.StringIO()
        with patch.object(sys, "argv", [
                str(r30.repo_path(r30.REL_VERIFIER)), "--protocol", str(historical_path)]), \
                contextlib.redirect_stderr(historical_stderr):
            historical_exit = r30_verifier.main()
        self.assertEqual(historical_exit, 1)
        rejection = json.loads(historical_stderr.getvalue())
        self.assertEqual(rejection["status"], "r30_static_preflight_failed")
        self.assertIn("static verifier must inspect the unique frozen R30 protocol",
                      rejection["error"])
        self.assertIs(rejection["julia_started"], False)
        self.assertIs(rejection["runtime_executed"], False)
        protocol = r30.load_protocol(r30.repo_path(r30.REL_PROTOCOL))
        source_rows = protocol.get("r30_source_pins")
        self.assertIsInstance(source_rows, list)
        expected_source_paths = {
            r30.REL_RUNNER, r30.REL_TEST, r30.REL_VERIFIER,
            r30.REL_INPUT_PROVIDER, r30.REL_PARSE_CONSUMER,
            r30.REL_PROTOCOL_BUILDER,
        }
        self.assertEqual({row.get("path") for row in source_rows},
                         expected_source_paths)
        source_by_path = {row["path"]: row for row in source_rows}
        for logical, expected in R30_FROZEN_SOURCE_PINS.items():
            with self.subTest(frozen_r30_source=logical):
                path = r30.repo_path(logical)
                self.assertTrue(path.is_file())
                self.assertFalse(path.is_symlink())
                raw = path.read_bytes()
                observed = {"path": logical, "bytes": len(raw),
                            "sha256": _sha256(raw)}
                self.assertEqual(observed, expected)
                self.assertEqual(source_by_path.get(logical), expected)
        for logical, row in source_by_path.items():
            with self.subTest(r30_source_closure=logical):
                self.assertEqual(set(row), {"path", "bytes", "sha256"})
                self.assertIs(type(row["bytes"]), int)
                self.assertGreater(row["bytes"], 0)
                self.assertRegex(row["sha256"], r"^[0-9a-f]{64}$")
                path = r30.repo_path(logical)
                self.assertTrue(path.is_file())
                self.assertFalse(path.is_symlink())
                raw = path.read_bytes()
                self.assertEqual(row, {"path": logical, "bytes": len(raw),
                                       "sha256": _sha256(raw)})
        pins = protocol["input_pins"]
        self.assertEqual(protocol.get("input_pin_count"), 214)
        r29_protocol = r30.load_protocol(r30.repo_path(r30.REL_R29_PROTOCOL))
        self.assertEqual(pins, r29_protocol["input_pins"])
        input_rows = {row["path"]: row for row in pins}
        preimage_receipts = protocol.get(
            "current_input_rebinding_preimage_receipts")
        self.assertEqual(preimage_receipts, R30_PREIMAGE_RECEIPT_CONTRACT)
        for key, schema, count, false_fields in (
            ("foundation_integration_receipt",
             "root-exact-source-integration-receipt-v1", 11,
             {"runtime_credit": False, "formal_credit": False,
              "consumer_entrypoints_not_integrated": True, "deleted_files": 0}),
            ("supervisor_preimage_receipt",
             "root-consumer-live-preimage-preservation-v1", 9,
             {"live_modified": False, "runtime_executed": False}),
        ):
            with self.subTest(preimage_receipt=key):
                receipt_pin = preimage_receipts[key]
                receipt_path = r30.repo_path(receipt_pin["path"])
                self.assertTrue(receipt_path.is_file())
                self.assertFalse(receipt_path.is_symlink())
                receipt_bytes = receipt_path.read_bytes()
                self.assertEqual(len(receipt_bytes), receipt_pin["bytes"])
                self.assertEqual(_sha256(receipt_bytes), receipt_pin["sha256"])
                receipt_body = json.loads(receipt_bytes.decode("utf-8"))
                self.assertEqual(receipt_body.get("schema"), schema)
                self.assertEqual(receipt_body.get("owner"), "/root")
                self.assertEqual(receipt_body.get("integrated_count",
                                                  receipt_body.get("count")), count)
                for field, value in false_fields.items():
                    observed = receipt_body.get(field)
                    if type(value) is bool:
                        self.assertIs(observed, value)
                    else:
                        self.assertIs(type(observed), int)
                        self.assertEqual(observed, value)
                self.assertEqual(len(receipt_body.get("rows", [])), count)
        current_rebindings = protocol.get("current_input_rebindings")
        self.assertIsInstance(current_rebindings, dict)
        self.assertEqual(set(current_rebindings),
                         set(R30_CURRENT_INPUT_REBINDING_PATHS))
        for logical in R30_CURRENT_INPUT_REBINDING_PATHS:
            with self.subTest(current_input_rebinding=logical):
                self.assertIn(logical, input_rows)
                row = current_rebindings[logical]
                self.assertEqual(set(row), {
                    "original_pin", "current_pin", "preserved_original_pin"})
                original = row["original_pin"]
                current = row["current_pin"]
                preserved = row["preserved_original_pin"]
                for pin in (original, current, preserved):
                    self.assertIsInstance(pin, dict)
                    self.assertEqual(set(pin), {"path", "bytes", "sha256"})
                    self.assertIs(type(pin["bytes"]), int)
                    self.assertGreater(pin["bytes"], 0)
                    self.assertRegex(pin["sha256"], r"^[0-9a-f]{64}$")
                self.assertEqual(original, input_rows[logical])
                self.assertEqual(current["path"], logical)
                self.assertEqual((preserved["bytes"], preserved["sha256"]),
                                 (original["bytes"], original["sha256"]))
                current_path = r30.repo_path(logical)
                self.assertTrue(current_path.is_file(),
                                f"current rebind source is absent: {logical}")
                current_bytes = current_path.read_bytes()
                self.assertEqual(current, {
                    "path": logical, "bytes": len(current_bytes),
                    "sha256": _sha256(current_bytes)})
        execution = protocol.get("execution_plan")
        self.assertIsInstance(execution, dict)
        parse_rebindings = execution.get("parse_source_rebindings")
        self.assertIsInstance(parse_rebindings, list)
        self.assertEqual([row.get("path") for row in parse_rebindings],
                         list(R30_PARSE_SOURCE_REBINDING_PATHS))
        for row in parse_rebindings:
            with self.subTest(parse_source_rebinding=row.get("path")):
                self.assertEqual(set(row), {"path", "original_pin", "current_pin"})
                self.assertEqual(row["original_pin"], input_rows[row["path"]])
                self.assertEqual(
                    row["current_pin"],
                    current_rebindings[row["path"]]["current_pin"])
        lifecycle_pins = protocol.get("managed_process_lifecycle_source_pins")
        self.assertIsInstance(lifecycle_pins, dict)
        self.assertEqual(set(lifecycle_pins),
                         set(MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS))
        for logical in MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS:
            with self.subTest(lifecycle_source=logical):
                path = r30.repo_path(logical)
                self.assertTrue(path.is_file(), f"canonical source is absent: {logical}")
                raw = path.read_bytes()
                row = lifecycle_pins[logical]
                self.assertEqual(set(row), {"path", "bytes", "sha256"})
                self.assertEqual(row, {"path": logical, "bytes": len(raw),
                                       "sha256": _sha256(raw)})
        additional = protocol.get("execution_plan", {}).get(
            "additional_julia_parse_sources")
        self.assertEqual(additional, [
            lifecycle_pins[logical]
            for logical in MANAGED_PROCESS_LIFECYCLE_JULIA_SOURCE_PATHS
        ])
        r30.validate_protocol_shape(protocol)
        for label, mutate in (
            ("missing_lifecycle_source", lambda candidate: candidate[
                "managed_process_lifecycle_source_pins"].pop(
                    MANAGED_PROCESS_LIFECYCLE_SOURCE_PATHS[0])),
            ("extra_lifecycle_source", lambda candidate: candidate[
                "managed_process_lifecycle_source_pins"].update({
                    "src/Unexpected.jl": {"path": "src/Unexpected.jl",
                                           "bytes": 1, "sha256": "f" * 64}})),
            ("wrong_lifecycle_source_sha", lambda candidate: candidate[
                "managed_process_lifecycle_source_pins"][
                    MANAGED_PROCESS_LIFECYCLE_JULIA_SOURCE_PATHS[0]].update(
                        {"sha256": "0" * 64})),
            ("missing_current_input_rebinding", lambda candidate: candidate[
                "current_input_rebindings"].pop(
                    R30_CURRENT_INPUT_REBINDING_PATHS[0])),
            ("extra_current_input_rebinding", lambda candidate: candidate[
                "current_input_rebindings"].update({"src/Unexpected.jl": {}})),
            ("wrong_current_input_rebinding_original", lambda candidate: candidate[
                "current_input_rebindings"][R30_CURRENT_INPUT_REBINDING_PATHS[1]][
                    "original_pin"].update({"sha256": "0" * 64})),
            ("wrong_current_input_rebinding_current", lambda candidate: candidate[
                "current_input_rebindings"][R30_CURRENT_INPUT_REBINDING_PATHS[1]][
                    "current_pin"].update({"bytes": 1})),
            ("wrong_current_input_rebinding_preserved", lambda candidate: candidate[
                "current_input_rebindings"][R30_CURRENT_INPUT_REBINDING_PATHS[1]][
                    "preserved_original_pin"].update({"sha256": "0" * 64})),
            ("missing_current_input_rebinding_preimage_receipts",
             lambda candidate: candidate.pop(
                 "current_input_rebinding_preimage_receipts")),
            ("wrong_preimage_receipt_schema",
             lambda candidate: candidate[
                 "current_input_rebinding_preimage_receipts"].update(
                     {"schema": "unbound-preimage-receipts-v1"})),
            ("wrong_foundation_preimage_receipt_pin",
             lambda candidate: candidate[
                 "current_input_rebinding_preimage_receipts"][
                     "foundation_integration_receipt"].update(
                         {"sha256": "0" * 64})),
            ("wrong_supervisor_preimage_receipt_size",
             lambda candidate: candidate[
                 "current_input_rebinding_preimage_receipts"][
                     "supervisor_preimage_receipt"].update({"bytes": 1})),
            ("extra_preimage_receipt_row",
             lambda candidate: candidate[
                 "current_input_rebinding_preimage_receipts"].update(
                     {"unexpected": {}})),
            ("missing_parse_source_rebinding", lambda candidate: candidate[
                "execution_plan"].update({"parse_source_rebindings": parse_rebindings[:-1]})),
            ("reordered_parse_source_rebindings", lambda candidate: candidate[
                "execution_plan"].update({"parse_source_rebindings": list(
                    reversed(parse_rebindings))})),
            ("wrong_parse_source_rebinding_current", lambda candidate: candidate[
                "execution_plan"]["parse_source_rebindings"][0][
                    "current_pin"].update({"sha256": "0" * 64})),
            ("missing_additional_parse_source", lambda candidate: candidate[
                "execution_plan"].update({"additional_julia_parse_sources": additional[:1]})),
            ("reordered_additional_parse_sources", lambda candidate: candidate[
                "execution_plan"].update({"additional_julia_parse_sources": list(
                    reversed(additional))})),
        ):
            candidate = copy.deepcopy(protocol)
            mutate(candidate)
            with self.subTest(lifecycle_contract=label):
                with self.assertRaises(r30.PreflightError):
                    r30.validate_protocol_shape(candidate)
        zip_paths = set(protocol["archive_input_provider"]["zip_member_paths"])
        self.assertEqual(len(pins), 214)
        rows = [
            {"path": row["path"], "bytes": row["bytes"], "sha256": row["sha256"],
             "source": "zip_member" if row["path"] in zip_paths else "workspace"}
            for row in pins
        ]
        self.assertEqual(sum(row["source"] == "workspace" for row in rows), 167)
        self.assertEqual(sum(row["source"] == "zip_member" for row in rows), 47)

        class Typed214Provider:
            def __init__(self, *, fail: bool = False) -> None:
                self.fail = fail
                self.phases: list[str] = []

            def verify_all(self, phase: str) -> dict[str, Any]:
                self.phases.append(phase)
                if self.fail:
                    raise PinnedInputError("injected read-only provider failure")
                return {
                    "complete": True,
                    "input_count": 214,
                    "workspace_count": 167,
                    "zip_member_count": 47,
                    "rows": copy.deepcopy(rows),
                    "archive_before": {"bytes": r30.R30_ARCHIVE_BYTES,
                                       "sha256": r30.R30_ARCHIVE_SHA256},
                    "archive_after": {"bytes": r30.R30_ARCHIVE_BYTES,
                                      "sha256": r30.R30_ARCHIVE_SHA256},
                    "phase": phase,
                }

        altered = copy.deepcopy(protocol)
        altered["input_pins"][0]["bytes"] += 1
        exact_provider = Typed214Provider()
        with patch.object(r30, "_INPUT_PROVIDER", exact_provider):
            with self.assertRaisesRegex(
                r30.PreflightError,
                "R30 input_pins must equal the complete ordered R29 214-row list",
            ):
                r30.verify_input_pins(altered, "r30_mutated_parent_pin")
        self.assertEqual(exact_provider.phases, ["r30_mutated_parent_pin"])

        failing_provider = Typed214Provider(fail=True)
        with patch.object(r30, "_INPUT_PROVIDER", failing_provider):
            with self.assertRaisesRegex(r30.PreflightError, "frozen R30 inputs are not complete"):
                r30.verify_input_pins(protocol, "r30_provider_failure")
        self.assertEqual(failing_provider.phases, ["r30_provider_failure"])

    def test_r29_archived_restore_no_go_inventory_is_verified_by_r30_provider(self) -> None:
        archived = {
            f"docs/archive_{index:02d}.bin": f"archived-input-{index:02d}\n".encode("ascii")
            for index in range(47)
        }
        workspace = {
            f"src/workspace_{index:03d}.jl": f"workspace-input-{index:03d}\n".encode("ascii")
            for index in range(167)
        }
        protocol, repo, archive = _fixture(
            self.base,
            archive_entries=list(archived.items()),
            zip_pins=archived,
            workspace_files=workspace,
        )
        protocol["archive_input_provider"].update(local_only=True, portable=False)
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        r29_protocol = {"input_pin_count": 214,
                        "input_pins": copy.deepcopy(protocol["input_pins"])}
        inventory = []
        for logical, data in sorted(archived.items()):
            digest = _sha256(data)
            inventory.append({
                "path": logical,
                "zip_member": logical,
                "archive_match": True,
                "expected_bytes": len(data),
                "observed_bytes": len(data),
                "expected_sha256": digest,
                "observed_sha256": digest,
            })
        manifest = {"runtime_preflight": {
            "status": "NO-GO_until_exact_restore",
            "exact_restore_required": True,
            "restored": False,
            "input_pin_waiver": False,
            "missing_count": 47,
            "archive": {
                "path": str(archive),
                "bytes": archive.stat().st_size,
                "sha256": _sha256(archive.read_bytes()),
                "local_only": True,
                "portable": False,
            },
            "inventory": inventory,
        }}

        self.assertEqual(r30_verifier._verify_r29_restore_lineage_via_provider(
            manifest, r29_protocol, protocol, provider), 47)
        for logical in archived:
            self.assertFalse(provider.physical_path(logical).exists())
            self.assertEqual(provider.receipt(logical)["source"], "zip_member")

        invalid_manifests: list[tuple[str, dict[str, Any]]] = []
        bad_waiver = copy.deepcopy(manifest)
        bad_waiver["runtime_preflight"]["input_pin_waiver"] = True
        invalid_manifests.append(("waiver", bad_waiver))
        bad_sha = copy.deepcopy(manifest)
        bad_sha["runtime_preflight"]["inventory"][0]["expected_sha256"] = "0" * 64
        invalid_manifests.append(("changed_expected_sha", bad_sha))
        duplicate = copy.deepcopy(manifest)
        duplicate["runtime_preflight"]["inventory"][1] = copy.deepcopy(
            duplicate["runtime_preflight"]["inventory"][0])
        invalid_manifests.append(("duplicate_inventory_member", duplicate))
        bad_archive = copy.deepcopy(manifest)
        bad_archive["runtime_preflight"]["archive"]["sha256"] = "1" * 64
        invalid_manifests.append(("archive_identity", bad_archive))
        for label, candidate in invalid_manifests:
            with self.subTest(case=label):
                with self.assertRaises(r30.PreflightError):
                    r30_verifier._verify_r29_restore_lineage_via_provider(
                        candidate, r29_protocol, protocol, provider)

        materialized_logical = next(iter(archived))
        materialized_path = provider.physical_path(materialized_logical)
        materialized_path.parent.mkdir(parents=True, exist_ok=True)
        materialized_path.write_bytes(archived[materialized_logical])
        try:
            with self.assertRaisesRegex(r30.PreflightError, "unexpectedly materialized"):
                r30_verifier._verify_r29_restore_lineage_via_provider(
                    manifest, r29_protocol, protocol, provider)
        finally:
            materialized_path.unlink()

    def test_loaded_protocol_receipt_is_exact_and_rejects_missing_drift_path_and_type_aliases(self) -> None:
        protocol_path = self.base / "protocol.json"
        raw = json.dumps({"schema": r30.SCHEMA, "unit": "receipt"},
                         sort_keys=True, separators=(",", ":")).encode("utf-8")
        protocol_path.write_bytes(raw)

        protocol, receipt = r30.load_protocol_with_receipt(protocol_path)
        self.assertEqual(protocol, {"schema": r30.SCHEMA, "unit": "receipt"})
        self.assertEqual(receipt, {
            "path": str(protocol_path.resolve()),
            "bytes": len(raw),
            "sha256": _sha256(raw),
        })
        self.assertEqual(r30.verify_loaded_protocol_file(
            protocol_path, receipt, "unit_exact_read"),
            {"phase": "unit_exact_read", "complete": True, **receipt})

        wrong_path = {**receipt, "path": str((self.base / "other.json").resolve())}
        for label, bad_receipt in (
            ("bool_bytes_alias", {**receipt, "bytes": True}),
            ("float_bytes_alias", {**receipt, "bytes": float(receipt["bytes"])}),
            ("path_mismatch", wrong_path),
            ("extra_receipt_field", {**receipt, "parsed_sha256": receipt["sha256"]}),
        ):
            with self.subTest(case=label):
                with self.assertRaisesRegex(r30.PreflightError, "receipt is malformed|differs from the exact bytes"):
                    r30.verify_loaded_protocol_file(protocol_path, bad_receipt, f"unit_{label}")

        with self.subTest(case="missing_protocol_file"):
            with self.assertRaisesRegex(r30.PreflightError, "absent|regular non-symlink"):
                r30.verify_loaded_protocol_file(self.base / "missing.json", receipt,
                                                "unit_missing")

        protocol_path.write_bytes(raw + b"\n")
        with self.subTest(case="changed_protocol_bytes"):
            with self.assertRaisesRegex(r30.PreflightError, "differs from the exact bytes"):
                r30.verify_loaded_protocol_file(protocol_path, receipt, "unit_changed")

    def test_protocol_file_integrity_brackets_stage_and_drift_blocks_later_stages(self) -> None:
        protocol_path = self.base / "sequence_protocol.json"
        raw = json.dumps({"schema": r30.SCHEMA, "unit": "sequence"},
                         sort_keys=True, separators=(",", ":")).encode("utf-8")
        protocol_path.write_bytes(raw)
        protocol, receipt = r30.load_protocol_with_receipt(protocol_path)
        extra_julia_sources = [
            {"path": logical, "bytes": 1, "sha256": ("a" if index == 0 else "b") * 64}
            for index, logical in enumerate(MANAGED_PROCESS_LIFECYCLE_JULIA_SOURCE_PATHS)
        ]
        parse_source_rebindings = [
            {"path": logical,
             "original_pin": {"path": logical, "bytes": 10 + index,
                              "sha256": ("c" if index % 2 == 0 else "d") * 64},
             "current_pin": {"path": logical, "bytes": 20 + index,
                             "sha256": ("e" if index % 2 == 0 else "f") * 64}}
            for index, logical in enumerate(R30_PARSE_SOURCE_REBINDING_PATHS)
        ]
        protocol["execution_plan"] = {
            "parse_manifest": {"entries": 108},
            "additional_julia_parse_sources": extra_julia_sources,
            "parse_source_rebindings": parse_source_rebindings,
        }
        plans = [{"stage": name, "argv": ["unused", name]}
                 for name in ("parse_all", "primary", "fresh_replay")]

        def source_check(_protocol: object, phase: str) -> dict[str, Any]:
            return {"phase": phase, "complete": True,
                    "rows": [{"path": "unit-source", "bytes": 1, "sha256": "a" * 64}]}

        def parent_check(_protocol: object, phase: str) -> dict[str, Any]:
            return {"phase": phase, "complete": True, "path": "unit-parent",
                    "bytes": 1, "sha256": "b" * 64,
                    "input_pin_count": 214, "input_pins_exactly_match": True}

        def launch_stub(output: Path, index: int, name: str, argv: list[str],
                        *_args: object) -> dict[str, Any]:
            stage_dir = output / f"{index:02d}_{name}"
            stage_dir.mkdir(parents=True, exist_ok=True)
            if name == "parse_all":
                manifest_files = protocol["execution_plan"]["parse_manifest"]["entries"]
                additional_files = len(protocol["execution_plan"][
                    "additional_julia_parse_sources"])
                rebind_count = len(protocol["execution_plan"][
                    "parse_source_rebindings"])
                total_files = manifest_files + additional_files
                marker = (f"NG12_PARSE status=pass files={manifest_files}\n"
                          f"NG12_PARSE_ADDITIONAL status=pass "
                          f"manifest_files={manifest_files} "
                          f"additional_files={additional_files} "
                          f"total_files={total_files}\n"
                          f"NG12_PARSE_REBINDING status=pass "
                          f"manifest_entries={manifest_files} "
                          f"original_bytes_verified={rebind_count} "
                          "original_sources_parsed=0 "
                          f"current_sources_parsed={rebind_count} "
                          f"total_files={total_files}")
            else:
                marker = f"NG12_RESULT mode={'primary' if name == 'primary' else 'replay'} status=pass"
            (stage_dir / "stdout.raw").write_text(marker, encoding="utf-8")
            return {"stage": name, "stop_reason": "natural_exit", "root_exit_code": 0,
                    "resource_monitor_complete": True, "source_integrity_complete": True,
                    "stdin_transfer": {"complete": True}}

        with patch.object(r30, "verify_owned_source_pins", side_effect=source_check), \
                patch.object(r30, "verify_r29_parent_protocol", side_effect=parent_check), \
                patch.object(r30, "_run_stage", side_effect=launch_stub):
            stages, failure = r30._run_stage_sequence(
                self.base / "positive_output", plans, protocol, {}, object(), object(),
                protocol_path, receipt)
        self.assertIsNone(failure)
        self.assertEqual([stage["stage"] for stage in stages],
                         ["parse_all", "primary", "fresh_replay"])
        for stage in stages:
            self.assertTrue(stage["protocol_file_integrity_complete"])
            self.assertTrue(stage["protocol_file_before"]["complete"])
            self.assertTrue(stage["protocol_file_after"]["complete"])
            self.assertEqual(stage["protocol_file_before"]["sha256"], _sha256(raw))
            self.assertEqual(stage["protocol_file_after"]["sha256"], _sha256(raw))

        additional_ok = (
            "NG12_PARSE_ADDITIONAL status=pass manifest_files=108 "
            "additional_files=2 total_files=110")
        rebind_ok = (
            "NG12_PARSE_REBINDING status=pass manifest_entries=108 "
            "original_bytes_verified=4 original_sources_parsed=0 "
            "current_sources_parsed=4 total_files=110")
        for label, additional_line, rebind_line in (
            ("missing_additional_parse_marker", None, rebind_ok),
            ("wrong_additional_parse_total",
             "NG12_PARSE_ADDITIONAL status=pass manifest_files=108 "
             "additional_files=2 total_files=111", rebind_ok),
            ("missing_source_rebinding_marker", additional_ok, None),
            ("wrong_source_rebinding_counts", additional_ok,
             "NG12_PARSE_REBINDING status=pass manifest_entries=108 "
             "original_bytes_verified=3 original_sources_parsed=1 "
             "current_sources_parsed=4 total_files=110"),
        ):
            bad_output = self.base / f"bad_parse_{label}"
            launches: list[str] = []

            def bad_launch_stub(_output: Path, index: int, name: str,
                                *_args: object) -> dict[str, Any]:
                launches.append(name)
                stage_dir = bad_output / f"{index:02d}_{name}"
                stage_dir.mkdir(parents=True, exist_ok=True)
                marker = "NG12_PARSE status=pass files=108"
                if name == "parse_all" and additional_line is not None:
                    marker += "\n" + additional_line
                if name == "parse_all" and rebind_line is not None:
                    marker += "\n" + rebind_line
                elif name != "parse_all":
                    marker = f"NG12_RESULT mode={'primary' if name == 'primary' else 'replay'} status=pass"
                (stage_dir / "stdout.raw").write_text(marker, encoding="utf-8")
                return {"stage": name, "stop_reason": "natural_exit", "root_exit_code": 0,
                        "resource_monitor_complete": True, "source_integrity_complete": True,
                        "stdin_transfer": {"complete": True}}

            with self.subTest(parse_gate=label), \
                    patch.object(r30, "verify_owned_source_pins", side_effect=source_check), \
                    patch.object(r30, "verify_r29_parent_protocol", side_effect=parent_check), \
                    patch.object(r30, "_run_stage", side_effect=bad_launch_stub):
                bad_stages, bad_failure = r30._run_stage_sequence(
                    bad_output, plans, protocol, {}, object(), object(),
                    protocol_path, receipt)
            self.assertEqual([stage["stage"] for stage in bad_stages], ["parse_all"])
            self.assertEqual(launches, ["parse_all"])
            self.assertIsNotNone(bad_failure)
            self.assertIn("required consumer marker missing", bad_failure or "")

        preflight_path = self.base / "preflight_drift_protocol.json"
        preflight_path.write_bytes(raw)
        _parsed, preflight_receipt = r30.load_protocol_with_receipt(preflight_path)
        preflight_path.write_bytes(raw + b" ")
        preflight_calls: list[str] = []

        def should_not_launch(_output: Path, _index: int, name: str,
                              *_args: object) -> dict[str, Any]:
            preflight_calls.append(name)
            raise AssertionError("stage launch must not run after protocol preflight drift")

        with patch.object(r30, "_run_stage", side_effect=should_not_launch):
            preflight_stages, preflight_failure = r30._run_stage_sequence(
                self.base / "preflight_output", plans, protocol, {}, object(), object(),
                preflight_path, preflight_receipt)
        self.assertEqual(preflight_stages, [])
        self.assertEqual(preflight_calls, [])
        self.assertIn("protocol/source preflight failed", preflight_failure or "")

        drift_path = self.base / "post_stage_drift_protocol.json"
        drift_path.write_bytes(raw)
        _parsed, drift_receipt = r30.load_protocol_with_receipt(drift_path)
        drift_calls: list[str] = []

        def drift_after_launch(output: Path, index: int, name: str, argv: list[str],
                               *_args: object) -> dict[str, Any]:
            result = launch_stub(output, index, name, argv)
            drift_calls.append(name)
            if len(drift_calls) == 1:
                drift_path.write_bytes(raw + b"\n")
            return result

        with patch.object(r30, "verify_owned_source_pins", side_effect=source_check), \
                patch.object(r30, "verify_r29_parent_protocol", side_effect=parent_check), \
                patch.object(r30, "_run_stage", side_effect=drift_after_launch):
            drift_stages, drift_failure = r30._run_stage_sequence(
                self.base / "post_stage_output", plans, protocol, {}, object(), object(),
                drift_path, drift_receipt)
        self.assertEqual(drift_calls, ["parse_all"])
        self.assertEqual(len(drift_stages), 1)
        self.assertFalse(drift_stages[0]["protocol_file_integrity_complete"])
        self.assertEqual(drift_stages[0]["stop_reason"], "protocol_file_drift")
        self.assertIn("stop_reason=protocol_file_drift", drift_failure or "")

    def test_shape_validator_rejects_numeric_type_aliases_in_limits_and_manifest(self) -> None:
        frozen_path = r30.repo_path(r30.REL_PROTOCOL)
        frozen = r30.load_protocol(frozen_path)
        _ensure_r30_input_provider()
        r30.validate_protocol_shape(frozen)

        bool_limit = copy.deepcopy(frozen)
        bool_limit["limits"]["julia_threads"] = True
        with self.subTest(contract="limits_bool_equals_int"):
            self.assertEqual(bool_limit["limits"]["julia_threads"],
                             frozen["limits"]["julia_threads"])
            with self.assertRaisesRegex(r30.PreflightError,
                                        "frozen R30 resource/compiler contract mismatch"):
                r30.validate_protocol_shape(bool_limit)

        float_manifest = copy.deepcopy(frozen)
        float_manifest["execution_plan"]["parse_manifest"]["bytes"] = float(
            frozen["execution_plan"]["parse_manifest"]["bytes"])
        with self.subTest(contract="manifest_float_equals_int"):
            self.assertEqual(float_manifest["execution_plan"]["parse_manifest"]["bytes"],
                             frozen["execution_plan"]["parse_manifest"]["bytes"])
            with self.assertRaisesRegex(r30.PreflightError,
                                        "R30 parse manifest input identity differs"):
                r30.validate_protocol_shape(float_manifest)


    def _positive_fixture(self) -> tuple[dict[str, Any], Path, Path, bytes, bytes]:
        local = b"local pinned source\n"
        archived = b'{"source":"frozen zip"}\n'
        protocol, repo, archive = _fixture(
            self.base,
            archive_entries=[
                ("docs/reference.json", archived),
                ("unrelated/archive-note.txt", b"unselected archive member\n"),
            ],
            zip_pins={"docs/reference.json": archived},
            workspace_files={"src/local-input.txt": local},
        )
        return protocol, repo, archive, local, archived

    def test_reads_both_sources_without_materializing_archive_paths(self) -> None:
        protocol, repo, _, local, archived = self._positive_fixture()
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)

        self.assertEqual(provider.read_bytes("src/local-input.txt"), local)
        self.assertEqual(provider.read_bytes("docs/reference.json"), archived)
        self.assertEqual(provider.read_json("docs/reference.json"), {"source": "frozen zip"})
        self.assertEqual(provider.receipt("docs/reference.json"), {
            "path": "docs/reference.json",
            "bytes": len(archived),
            "sha256": _sha256(archived),
            "source": "zip_member",
        })

        status = provider.verify_all("test-preflight")
        self.assertTrue(status["complete"])
        self.assertEqual((status["input_count"], status["workspace_count"],
                          status["zip_member_count"]), (2, 1, 1))
        self.assertEqual([row["path"] for row in status["rows"]],
                         ["docs/reference.json", "src/local-input.txt"])
        self.assertEqual([row["source"] for row in status["rows"]],
                         ["zip_member", "workspace"])

        physical = provider.physical_path("docs/reference.json")
        self.assertFalse(physical.exists())
        self.assertFalse(physical.is_file())
        adapter = provider.repo_path_adapter(
            lambda relative: repo.joinpath(*PurePosixPath(relative).parts))
        read_through = adapter("docs/reference.json")
        self.assertFalse(read_through.exists())
        self.assertFalse(read_through.is_file())
        self.assertEqual(read_through.read_bytes(), archived)
        self.assertEqual(read_through.read_text(encoding="utf-8"), archived.decode("utf-8"))
        with read_through.open("rb") as stream:
            self.assertEqual(stream.read(), archived)
        self.assertFalse(physical.exists())
        self.assertFalse(physical.is_file())

    def test_rejects_missing_duplicate_misbound_and_unsafe_archive_rows(self) -> None:
        valid = b"original!"
        cases: list[tuple[str, list[tuple[str | zipfile.ZipInfo, bytes]],
                          dict[str, bytes], list[str] | None]] = [
            ("missing member", [], {"docs/item.bin": valid}, None),
            ("same-size content drift", [("docs/item.bin", b"tampered!")],
             {"docs/item.bin": valid}, None),
            ("duplicate central-directory name",
             [("docs/item.bin", valid), ("docs/item.bin", valid)],
             {"docs/item.bin": valid}, None),
            ("duplicate source-map row", [("docs/item.bin", valid)],
             {"docs/item.bin": valid}, ["docs/item.bin", "docs/item.bin"]),
            ("un-pinned mapped path", [("docs/item.bin", valid)],
             {"docs/item.bin": valid}, ["docs/item.bin", "docs/other.bin"]),
            ("parent traversal", [("../outside.bin", valid)],
             {"../outside.bin": valid}, None),
            ("noncanonical logical path", [("docs//item.bin", valid)],
             {"docs/item.bin": valid}, None),
        ]
        for index, (label, entries, zip_pins, mapped_paths) in enumerate(cases):
            with self.subTest(case=label):
                base = self.base / str(index)
                base.mkdir()
                protocol, repo, _ = _fixture(
                    base, archive_entries=entries, zip_pins=zip_pins,
                    zip_member_paths=mapped_paths)
                with self.assertRaises(PinnedInputError):
                    PinnedZipInputProvider.from_protocol(protocol, repo)

        with self.subTest(case="archive symlink member"):
            base = self.base / "symlink_member"
            base.mkdir()
            link = zipfile.ZipInfo("docs/link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            protocol, repo, _ = _fixture(
                base, archive_entries=[(link, b"target")],
                zip_pins={"docs/link": b"target"})
            with self.assertRaises(PinnedInputError):
                PinnedZipInputProvider.from_protocol(protocol, repo)

    def test_workspace_drift_or_absence_never_falls_back_to_zip(self) -> None:
        local = b"workspace original"
        virtual = b"mapped archive source"
        protocol, repo, _ = _fixture(
            self.base,
            archive_entries=[
                ("docs/virtual.txt", virtual),
                ("src/local.txt", b"unselected duplicate bytes"),
            ],
            zip_pins={"docs/virtual.txt": virtual},
            workspace_files={"src/local.txt": local},
        )
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        (repo / "src/local.txt").write_bytes(b"workspace changed")
        with self.assertRaises(PinnedInputError):
            provider.read_bytes("src/local.txt")
        with self.assertRaises(PinnedInputError):
            provider.verify_all("post-drift")

        missing_base = self.base / "missing_workspace"
        missing_base.mkdir()
        missing_protocol, missing_repo, _ = _fixture(
            missing_base,
            archive_entries=[
                ("docs/virtual.txt", virtual),
                ("src/missing.txt", b"archive copy is not a source binding"),
            ],
            zip_pins={"docs/virtual.txt": virtual},
            workspace_files={"src/missing.txt": b"expected live bytes"},
        )
        (missing_repo / "src/missing.txt").unlink()
        with self.assertRaises(PinnedInputError):
            PinnedZipInputProvider.from_protocol(missing_protocol, missing_repo)

    def test_archive_backed_path_appearing_or_archive_identity_drifting_fails(self) -> None:
        protocol, repo, archive, _, archived = self._positive_fixture()
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        physical = provider.physical_path("docs/reference.json")
        physical.parent.mkdir(parents=True)
        physical.write_bytes(archived)
        with self.assertRaises(PinnedInputError):
            provider.read_bytes("docs/reference.json")
        physical.unlink()

        archive.write_bytes(archive.read_bytes() + b"\x00")
        with self.assertRaises(PinnedInputError):
            provider.verify_all("changed-archive")

    def test_archive_read_through_handle_rejects_mutating_path_apis(self) -> None:
        protocol, repo, _, _, _ = self._positive_fixture()
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        physical = provider.physical_path("docs/reference.json")
        adapter = provider.repo_path_adapter(
            lambda relative: repo.joinpath(*PurePosixPath(relative).parts))
        read_through = adapter("docs/reference.json")

        attempts = {
            "open-write": lambda: read_through.open("w"),
            "open-binary-write": lambda: read_through.open("wb"),
            "open-append": lambda: read_through.open("a"),
            "write-text": lambda: read_through.write_text("forbidden"),
            "write-bytes": lambda: read_through.write_bytes(b"forbidden"),
            "touch": lambda: read_through.touch(),
            "mkdir": lambda: read_through.mkdir(),
            "unlink": lambda: read_through.unlink(),
        }
        for label, operation in attempts.items():
            with self.subTest(operation=label):
                with self.assertRaises(PinnedInputError):
                    operation()
                self.assertFalse(physical.exists())
                self.assertFalse(physical.is_file())
        self.assertFalse(physical.parent.exists())

    def test_unpinned_reads_and_bad_archive_path_bindings_fail_closed(self) -> None:
        protocol, repo, _, _, _ = self._positive_fixture()
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        for operation in (
            lambda: provider.read_bytes("docs/not-pinned.txt"),
            lambda: provider.read_text("docs/not-pinned.txt"),
            lambda: provider.read_json("docs/not-pinned.txt"),
            lambda: provider.receipt("docs/not-pinned.txt"),
            lambda: provider.physical_path("docs/not-pinned.txt"),
        ):
            with self.subTest(operation=operation):
                with self.assertRaises(PinnedInputError):
                    operation()

    def test_parse_manifest_helper_streams_exact_provider_bytes_and_receipt(self) -> None:
        manifest = b"deadbeef\tsrc/example.jl\n"
        logical = r30.REL_PARSE_MANIFEST
        protocol, repo, _ = _fixture(
            self.base,
            archive_entries=[(logical, manifest)],
            zip_pins={logical: manifest},
        )
        provider = PinnedZipInputProvider.from_protocol(protocol, repo)
        contract = {"path": logical, "bytes": len(manifest),
                    "sha256": _sha256(manifest), "entries": 1}

        raw, receipt = r30.prepare_parse_manifest_stdin(provider, contract)
        self.assertEqual(raw, manifest)
        self.assertEqual(receipt, {"path": logical, "bytes": len(manifest),
                                   "sha256": _sha256(manifest), "source": "zip_member"})
        self.assertFalse(provider.physical_path(logical).exists())

        bad_contracts = [
            {**contract, "path": "docs/other.tsv"},
            {**contract, "bytes": len(manifest) + 1},
            {**contract, "sha256": "0" * 64},
            {**contract, "entries": True},
        ]
        for bad in bad_contracts:
            with self.subTest(contract=bad):
                with self.assertRaises(r30.PreflightError):
                    r30.prepare_parse_manifest_stdin(provider, bad)

        workspace_base = self.base / "workspace_manifest"
        workspace_base.mkdir()
        workspace_protocol, workspace_repo, _ = _fixture(
            workspace_base,
            archive_entries=[("docs/unrelated.txt", b"unrelated")],
            zip_pins={"docs/unrelated.txt": b"unrelated"},
            workspace_files={logical: manifest},
        )
        workspace_provider = PinnedZipInputProvider.from_protocol(workspace_protocol, workspace_repo)
        with self.assertRaises(r30.PreflightError):
            r30.prepare_parse_manifest_stdin(workspace_provider, contract)

    def test_parse_all_plan_binds_contract_separately_from_stdin_payload(self) -> None:
        manifest = {"path": r30.REL_PARSE_MANIFEST, "bytes": 11504,
                    "sha256": "a9f8625483929b02b3e1d00b272199a9be1f385ce212eb4459c9887d5b783ffa",
                    "entries": 108}
        extra_julia_sources = [
            {"path": logical, "bytes": index + 1,
             "sha256": ("a" if index == 0 else "b") * 64}
            for index, logical in enumerate(MANAGED_PROCESS_LIFECYCLE_JULIA_SOURCE_PATHS)
        ]
        parse_source_rebindings = [
            {"path": logical,
             "original_pin": {"path": logical, "bytes": 100 + index,
                              "sha256": ("c" if index % 2 == 0 else "d") * 64},
             "current_pin": {"path": logical, "bytes": 200 + index,
                             "sha256": ("e" if index % 2 == 0 else "f") * 64}}
            for index, logical in enumerate(R30_PARSE_SOURCE_REBINDING_PATHS)
        ]
        lifecycle_source_pins = {
            "tools/execution/windows_process_lifecycle.py": {
                "path": "tools/execution/windows_process_lifecycle.py",
                "bytes": 3, "sha256": "c" * 64},
            **{row["path"]: row for row in extra_julia_sources},
        }
        protocol = {"execution_plan": {
            "julia_executable": {"path": "julia"},
            "gridap_project": str(self.base / "GridapNativeG1G2V1"),
            "parse_manifest": manifest,
            "additional_julia_parse_sources": extra_julia_sources,
            "parse_source_rebindings": parse_source_rebindings,
        }, "managed_process_lifecycle_source_pins": lifecycle_source_pins,
        }
        commands = r30.planned_stage_commands(protocol, self.base / "new-output")
        parse_plan = commands[0]
        self.assertEqual(parse_plan["stage"], "parse_all")
        self.assertEqual(parse_plan["stdin_provider_path"], r30.REL_PARSE_MANIFEST)
        self.assertEqual(parse_plan.get("stdin_manifest_contract"), manifest)
        self.assertNotIn(r30.REL_PARSE_MANIFEST, parse_plan["argv"])
        extra_argv = [arg for row in extra_julia_sources
                      for arg in ("--extra-source", row["path"],
                                  str(row["bytes"]), row["sha256"])]
        rebind_argv = [arg for row in parse_source_rebindings
                       for arg in ("--source-rebinding", row["path"],
                                   str(row["original_pin"]["bytes"]),
                                   row["original_pin"]["sha256"],
                                   str(row["current_pin"]["bytes"]),
                                   row["current_pin"]["sha256"])]
        base_tail = ["11504", manifest["sha256"], str(manifest["entries"]),
                     str(r30.ROOT)]
        self.assertEqual(parse_plan["argv"][-(len(base_tail) + len(extra_argv) +
                                              len(rebind_argv)):],
                         base_tail + extra_argv + rebind_argv)
        self.assertEqual(manifest["entries"] + len(extra_julia_sources),
                         110)
        self.assertEqual(len(parse_source_rebindings), 4)
        self.assertEqual(parse_plan["stdin_manifest_contract"], manifest)
        self.assertEqual([row["stage"] for row in commands],
                         ["parse_all", "primary", "fresh_replay"])

    def test_parse_consumer_keeps_all_manifest_and_source_hash_checks(self) -> None:
        source = r30.repo_path(r30.REL_PARSE_CONSUMER).read_text(encoding="utf-8")
        for required in (
            "manifest_bytes = read(stdin)",
            "length(manifest_bytes) == expected_bytes",
            "bytes2hex(SHA.sha256(manifest_bytes)) == expected_sha256",
            'for line in eachline(manifest)',
            'split(line, "\\t"; limit=2)',
            "bytes = read(path)",
            "bytes2hex(SHA.sha256(bytes)) == expected",
            "Meta.parseall(String(bytes))",
            "count == expected_entries",
            "expected_entries == 108 || error",
            "length(additional_sources) == 2 || error",
            "bytes2hex(SHA.sha256(source_bytes)) == expected_source_sha256",
            "Meta.parseall(String(source_bytes))",
            "NG12_R30_SOURCE_REBINDING_PATHS",
            "source_rebindings::Vector{Tuple{String,Int,String,Int,String}}",
            "length(rebound_current_parsed) == 4",
            "preserved original source byte count mismatch",
            "current rebound source byte count mismatch",
            "Meta.parseall(String(current_source_bytes))",
            "length(ARGS) == 36",
            '"--source-rebinding"',
            "total_count == expected_entries + length(additional_sources)",
            "NG12_PARSE_ADDITIONAL status=pass",
            "NG12_PARSE_REBINDING status=pass",
        ):
            with self.subTest(fragment=required):
                self.assertIn(required, source)
        self.assertNotIn("read(ARGS", source)
        self.assertEqual(r30.STAGES, ("parse_all", "primary", "fresh_replay"))
        self.assertEqual(r30.WALL_SECONDS_PER_STAGE, 480.0)
        self.assertEqual(r30.SAMPLE_INTERVAL_SECONDS, 0.2)
        self.assertEqual(r30.RSS_LIMIT_BYTES, 2 * 1024**3)
        self.assertEqual(r30.JULIA_HEAP_HINT, "1G")
        self.assertEqual(r30.COMPILER_MODE, "--compile=min")
        runner_source = Path(r30.__file__).read_text(encoding="utf-8")
        for required in (
            'protocol.get("managed_process_lifecycle_source_pins")',
            'protocol.get("additional_julia_parse_sources")',
            'protocol.get("current_input_rebindings")',
            'protocol.get("current_input_rebinding_preimage_receipts")',
            'execution.get("parse_source_rebindings")',
            '"--extra-source"',
            '"--source-rebinding"',
            'expected_entries + len(additional_sources)',
            '"NG12_PARSE_ADDITIONAL status=pass',
            '"NG12_PARSE_REBINDING status=pass',
        ):
            with self.subTest(runner_contract=required):
                self.assertIn(required, runner_source)

    def test_manifest_writer_is_bounded_and_runs_inside_the_existing_stage_monitor(self) -> None:
        source = Path(r30.__file__).read_text(encoding="utf-8")
        start = source.index("def _run_stage(")
        end = source.index("\ndef _stage_pass(", start)
        stage = source[start:end]
        for required in (
            "stdin=subprocess.PIPE",
            "threading.Thread(",
            "stdin_writer.start()",
            "input_pipe.write(view[written:end])",
            "input_pipe.close()",
            "stdin_writer.join(timeout=0.25)",
            "written_sha256",
            "stdin_state[\"complete\"]",
            'while stop_reason == "natural_exit":',
            "time.sleep(SAMPLE_INTERVAL_SECONDS)",
        ):
            with self.subTest(fragment=required):
                self.assertIn(required, stage)
        self.assertNotIn("communicate(", stage)

    def test_actual_stage_sequence_uses_the_bound_manifest_helper_result(self) -> None:
        source = Path(r30.__file__).read_text(encoding="utf-8")
        start = source.index("def _run_stage_sequence(")
        end = source.index("\ndef _set_environment(", start)
        sequence = source[start:end]
        self.assertIn("prepare_parse_manifest_stdin(", sequence)
        self.assertIn("plan.get(\"stdin_manifest_contract\")", sequence)
        self.assertIn("stdin_bytes, stdin_receipt", sequence)
        self.assertIn("environment, table, audit, stdin_bytes, stdin_receipt", sequence)


class R30InheritedSampleRaceRecoveryTests(r28_fixture_support.R28SampleRaceRecoveryTests):
    """Run the existing sampled-race fixture matrix against the R30 supervisor."""


class R30InheritedOrphanChainRecoveryTests(r28_fixture_support.R28OrphanChainRecoveryTests):
    """Keep all orphan ancestry fixtures on the R30 process-monitor path."""

    def test_orphan_descendant_missing_or_reused_before_bind_is_unaccounted(self) -> None:
        # R30 keeps the frozen R28 cases and fail-closed assertions. Its R29
        # parent-reuse diagnostic is more specific than the historical reason:
        # it records both the replacement parent generation and the descendant
        # whose stale PPID makes ancestry ambiguous.
        cases = [
            ({"fresh_descendants": False}, {
                "digest_observed_descendant_missing_before_handle_bind"}, None),
            ({"child_generation_reuse": True}, {
                "digest_observed_descendant_generation_or_parent_changed"}, None),
            ({"parent_generation_reuse": True}, {
                "replacement_generation_observed_after_missing_parent_exit",
                "descendant_ancestry_ambiguous_after_parent_pid_reuse"},
             "missing_tracked_generation_pid_reused_after_natural_exit"),
        ]
        for options, expected_reasons, diagnostic_reason in cases:
            with self.subTest(options=options):
                stage, _table, _audit, attempts = self._run_orphan_stage(**options)
                self.assertEqual(stage["stop_reason"], "resource_monitor_incomplete")
                self.assertFalse(stage["resource_monitor_complete"])
                self.assertFalse(stage["final_residual_audit"]["residual_clear"])
                self.assertEqual(stage["sample_recovery_count"], 0)
                recovery = attempts[0]["recovery"]
                reasons = {item.get("reason") for item in recovery[
                    "unaccounted_observed_generations"]}
                self.assertTrue(expected_reasons.issubset(reasons))
                if diagnostic_reason is not None:
                    self.assertEqual(recovery.get("reason"), diagnostic_reason)
                    self.assertIs(recovery.get("retry_authorized"), False)
                    self.assertEqual(recovery.get("retry_count"), 0)
                    self.assertIs(recovery.get("residual_clear"), False)
                self.assertFalse(stage["numerical_credit"])
                self.assertFalse(stage["physical_credit"])

    def test_unaccounted_orphan_chain_stops_serial_sequence_before_replay(self) -> None:
        failed, _table, _audit, _attempts = self._run_orphan_stage(fresh_descendants=False)
        self.assertEqual(failed["stop_reason"], "resource_monitor_incomplete")
        protocol_path = r30.repo_path(r30.REL_PROTOCOL)
        protocol, loaded_receipt = r30.load_protocol_with_receipt(protocol_path)
        calls: list[str] = []
        plans = [{"stage": name, "argv": ["fake", name]}
                 for name in ("parse_all", "primary", "fresh_replay")]

        def injected_stage(output: Path, index: int, name: str, argv: list[str],
                           environment: object, table: object, audit: object,
                           *stdin_args: object) -> dict:
            calls.append(name)
            (output / f"{index:02d}_{name}").mkdir(parents=True, exist_ok=True)
            if name == "primary":
                return {**failed, "stage": name}
            return {"stage": name, "stop_reason": "natural_exit", "root_exit_code": 0,
                    "resource_monitor_complete": True, "source_integrity_complete": True,
                    "stdin_transfer": {"complete": True},
                    "numerical_credit": False, "physical_credit": False}

        def injected_pass(output: Path, stage: dict, index: int) -> tuple[bool, str | None]:
            if stage["stage"] == "primary":
                return False, (
                    f"{stage['stage']}: stop_reason={stage['stop_reason']}; "
                    "injected primary residual uncertainty")
            return True, None

        with tempfile.TemporaryDirectory(prefix="native_g1g2_r30_orphan_sequence_") as temp:
            with patch.object(r30, "_run_stage", side_effect=injected_stage), \
                    patch.object(r30, "_stage_pass", side_effect=injected_pass):
                stages, failure = r30._run_stage_sequence(
                    Path(temp), plans, protocol, {}, object(), object(),
                    protocol_path, loaded_receipt)
        self.assertEqual(calls, ["parse_all", "primary"])
        self.assertEqual(len(stages), 2)
        self.assertIn("stop_reason=resource_monitor_incomplete", failure or "")


class R30InheritedLaunchBindingFailureTests(r28_fixture_support.R28LaunchBindingFailureTests):
    """Retain original Popen-handle cleanup fault injections on R30."""


class R30InheritedTreeCleanupFallbackTests(r28_fixture_support.R28TrackedTreeCleanupFallbackTests):
    """Retain cleanup and serial-stop fault injections on R30."""

    def test_failed_stage_sequence_never_launches_later_stages(self) -> None:
        protocol_path = r30.repo_path(r30.REL_PROTOCOL)
        protocol, loaded_receipt = r30.load_protocol_with_receipt(protocol_path)
        calls: list[str] = []
        plans = [{"stage": name, "argv": ["fake", name]}
                 for name in ("parse_all", "primary", "fresh_replay")]

        def injected_stage(output: Path, index: int, name: str, argv: list[str],
                           environment: object, table: object, audit: object,
                           *stdin_args: object) -> dict:
            calls.append(name)
            (output / f"{index:02d}_{name}").mkdir(parents=True, exist_ok=True)
            return {"stage": name, "stop_reason": "resource_monitor_incomplete",
                    "root_exit_code": None, "resource_monitor_complete": False,
                    "source_integrity_complete": True}

        with tempfile.TemporaryDirectory(prefix="native_g1g2_r30_tree_sequence_") as temp:
            with patch.object(r30, "_run_stage", side_effect=injected_stage):
                stages, failure = r30._run_stage_sequence(
                    Path(temp), plans, protocol, {}, object(), object(),
                    protocol_path, loaded_receipt)
        self.assertEqual(calls, ["parse_all"])
        self.assertEqual(len(stages), 1)
        self.assertIn("stop_reason=resource_monitor_incomplete", failure or "")


class R30InheritedPidReuseRecoveryTests(r29_pid_reuse_support.R29NaturalExitPidReuseTests):
    """Run both frozen R29 PID-reuse cases against the real R30 supervisor."""


class R30InheritedR28ProtocolContractTests(r28_contract_support.R28ProtocolContractTests):
    """Execute every unchanged historical R28 protocol-contract test in isolation."""

    def test_frozen_r13_resource_and_consumer_gates(self) -> None:
        # Keep the original R28 assertions and code intact while resolving its
        # archived R13 summary through the already pinned, read-only R30 ZIP
        # provider. Physical existence/stat continue to describe the checkout.
        provider = _ensure_r30_input_provider()
        legacy_runner = r28_contract_support.r28
        adapted_repo_path = provider.repo_path_adapter(legacy_runner.repo_path)
        with patch.object(legacy_runner, "repo_path", new=adapted_repo_path):
            super().test_frozen_r13_resource_and_consumer_gates()


class R30InheritedSourceContractTests(unittest.TestCase):
    def test_r29_archive_lineage_and_214_pins_use_only_the_r30_provider(self) -> None:
        contract = r30_verifier._check_r29_archive_provider_source_contract()
        self.assertTrue(all(contract.values()))

    def test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit(self) -> None:
        r28_fixture_support.R28ProtocolContractTests.test_sampled_rss_gate_is_fail_closed_and_keeps_no_credit(self)

    def test_r23_exact_generation_apis_are_the_only_runtime_identity_path(self) -> None:
        r28_fixture_support.R28ProtocolContractTests.test_r23_exact_generation_apis_are_the_only_runtime_identity_path(self)

    def test_root_bind_failure_routes_to_original_handle_cleanup(self) -> None:
        r28_fixture_support.R28ProtocolContractTests.test_root_bind_failure_routes_to_original_handle_cleanup(self)

    def test_tree_failure_has_same_handle_fallback_and_serial_stage_stop(self) -> None:
        source = Path(r30.repo_path(r30.REL_RUNNER)).read_text(encoding="utf-8")
        self.assertIn('failure_phase="tracked_tree_cleanup_incomplete"', source)
        self.assertIn('"schema": "native-g1g2-r30-tree-cleanup-fallback-v1"', source)
        self.assertIn('"next_stage_after_tree_cleanup_incomplete": False', source)

    def _boundary_snapshot(self, table: Any, mode: str) -> Any:
        idle_ticks = 134345421427017430
        root_identity = (740, 134345421481717430)
        missing_identity = (741, root_identity[1] + 1)
        rows = [
            table.ProcessRow(table.ProcessIdentity(0, idle_ticks), 0, ""),
            table.ProcessRow(table.ProcessIdentity(4, idle_ticks), 0, "System"),
        ]
        include_root = mode not in {"child_only", "sentinels_only", "root_reused"}
        if include_root:
            rows.append(table.ProcessRow(
                table.ProcessIdentity(*root_identity), 4, "julia.exe"))
        if mode == "child_only":
            rows.append(table.ProcessRow(
                table.ProcessIdentity(*missing_identity), root_identity[0], "worker.exe"))
        elif mode == "root_reused":
            rows.append(table.ProcessRow(
                table.ProcessIdentity(root_identity[0], root_identity[1] + 10),
                4, "julia-replacement.exe"))
        elif mode == "child_reused":
            rows.append(table.ProcessRow(
                table.ProcessIdentity(missing_identity[0], missing_identity[1] + 10),
                root_identity[0], "worker-replacement.exe"))
        elif mode == "root_and_orphan":
            rows.append(table.ProcessRow(
                table.ProcessIdentity(742, missing_identity[1] + 1),
                missing_identity[0], "orphan-worker.exe"))
        snapshot = table.ProcessTableSnapshot(
            rows=tuple(rows), host_identity=table.WINDOWS_BUILD_PIN,
            buffer_bytes=table.SPI_FIXED_HEADER_BYTES, query_attempts=1, ntstatus_u32=0)
        if mode == "invalid":
            # Model a truncated/incomplete source snapshot after its typed object
            # was returned; the production validator must refuse to seal it.
            object.__setattr__(snapshot, "buffer_bytes", 0)
        return snapshot

    def _exercise_boundary_case(
        self, boundary: str, *, failure_mode: str = "root_only",
        observed_modes: tuple[str, ...] = (), wait_for_child: bool = True,
        exit_code: int = 0, recovery_allowed: bool = True,
        trigger: str = "exact", direct_reconcile: bool = False,
    ) -> dict[str, Any]:
        table, _supervisor = r30._load_r23()
        root_identity = (740, 134345421481717430)
        missing_identity = (741, root_identity[1] + 1)
        root_handle = object()
        missing_handle = object()
        handles = {root_identity: root_handle, missing_identity: missing_handle}
        handle_identities = {
            id(root_handle): root_identity,
            id(missing_handle): missing_identity,
        }
        tracked = {root_identity, missing_identity}
        failure_snapshot = self._boundary_snapshot(table, failure_mode)
        observed = [self._boundary_snapshot(table, mode) for mode in observed_modes]
        snapshot_calls: list[str] = []

        def snapshot_provider() -> Any:
            snapshot_calls.append("snapshot")
            if not observed:
                raise AssertionError("unexpected native snapshot request")
            return observed.pop(0)

        def read_handle(handle: Any) -> tuple[int, int]:
            return handle_identities[id(handle)]

        def wait_handle(handle: Any, _timeout: float) -> bool:
            return handle is missing_handle and wait_for_child

        def read_exit_code(handle: Any) -> int:
            self.assertIs(handle, missing_handle)
            return exit_code

        error: BaseException = table.ProcessTableError(r30.SAMPLED_TRACKED_RACE_ERROR)
        if trigger == "wrong_type":
            error = RuntimeError(r30.SAMPLED_TRACKED_RACE_ERROR)
        elif trigger == "wrong_message":
            error = table.ProcessTableError("different native process-table failure")
        elif trigger == "subclass":
            class DerivedProcessTableError(table.ProcessTableError):
                pass
            error = DerivedProcessTableError(r30.SAMPLED_TRACKED_RACE_ERROR)
        elif trigger != "exact":
            raise AssertionError(f"unknown boundary trigger fixture: {trigger}")

        exit_receipts: list[dict[str, Any]] = []
        boundary_records: list[dict[str, Any]] = []
        bind_calls = 0
        result: tuple[Any, ...] | None = None
        rejected: dict[str, Any] | None = None
        with tempfile.TemporaryDirectory(prefix="native_g1g2_r30_boundary_") as temp:
            records_path = Path(temp) / "boundary_reconciliations.jsonl"
            with patch.object(table, "read_process_handle_identity", side_effect=read_handle), \
                    patch.object(table, "wait_for_process_exit", side_effect=wait_handle), \
                    patch.object(table, "process_exit_code", side_effect=read_exit_code), \
                    patch.object(r30, "_bind_tree", wraps=r30._bind_tree) as bind_spy:
                if direct_reconcile:
                    record, reconciled, bound = r30._reconcile_boundary_natural_exit(
                        failure_snapshot, error, boundary, 7, root_identity, tracked,
                        handles, table, snapshot_provider, exit_receipts,
                        recovery_allowed=recovery_allowed)
                    result = (bound, record, reconciled)
                else:
                    try:
                        result = r30._bind_tree_at_boundary(
                            failure_snapshot, root_identity, tracked, handles, table,
                            snapshot_provider, exit_receipts, boundary_records,
                            records_path, boundary=boundary, sampling_event_index=7,
                            recovery_allowed=recovery_allowed)
                    except r30.BoundaryReconciliationRejected as exc:
                        rejected = exc.receipt
                bind_calls = bind_spy.call_count
            receipt_lines = (records_path.read_text(encoding="utf-8").splitlines()
                             if records_path.exists() else [])
        record = rejected if rejected is not None else (result[1] if result is not None else None)
        if isinstance(record, dict):
            for credit_key in ("numerical_credit", "physical_credit",
                               "solver_success_claimed"):
                self.assertIs(record[credit_key], False)
        return {
            "record": record,
            "result": result,
            "rejected": rejected,
            "boundary_records": boundary_records,
            "receipt_lines": receipt_lines,
            "exit_receipts": exit_receipts,
            "snapshot_call_count": len(snapshot_calls),
            "bind_call_count": bind_calls,
            "tracked": tracked,
            "root_identity": root_identity,
            "missing_identity": missing_identity,
        }

    def _assert_native_snapshot_seal(self, seal: dict[str, Any]) -> None:
        payload = {key: seal[key] for key in (
            "schema", "host_identity", "buffer_bytes", "query_attempts",
            "ntstatus_u32", "process_rows")}
        raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
        self.assertEqual(seal["row_count"], len(seal["process_rows"]))
        self.assertEqual(seal["sha256"], _sha256(raw))

    def test_sample_race_contract_uses_the_r30_frozen_protocol(self) -> None:
        protocol = r30.load_protocol(r30.repo_path(r30.REL_PROTOCOL))
        table, _supervisor = r30._load_r23()
        contract = protocol["sampled_tracked_race_recovery_contract"]
        self.assertEqual(contract["max_retry_count_per_sampling_tick"], 1)
        self.assertTrue(contract["every_missing_tracked_generation_requires_exact_natural_exit_receipt"])
        self.assertTrue(contract["every_newly_observed_descendant_requires_exact_retained_handle_or_explicit_unaccounted"])
        self.assertEqual(contract["unaccounted_observed_generation"],
                         "resource_monitor_incomplete_residual_clear_false_no_next_stage")
        self.assertFalse(contract["numerical_credit_on_recovery"])
        self.assertFalse(contract["physical_credit_on_recovery"])
        source = Path(r30.repo_path(r30.REL_RUNNER)).read_text(encoding="utf-8")
        for anchor in ("tracked_before_sample", "sample_attempts.jsonl",
                       "_recover_missing_tracked_sample_race(",
                       "digest_observed_descendant_missing_before_handle_bind",
                       'residual["residual_clear"] = False'):
            with self.subTest(anchor=anchor):
                self.assertIn(anchor, source)

        # Exercise the actual boundary helper against R23 typed SPI objects.
        # The same natural-exit route is valid at either edge of one sample,
        # but unresolved identity or incomplete evidence never earns credit.
        for boundary in ("before_sample", "after_sample"):
            with self.subTest(boundary=boundary):
                positive = self._exercise_boundary_case(
                    boundary, observed_modes=("root_only", "root_only", "root_only"))
                record = positive["record"]
                self.assertIsNotNone(record)
                self.assertIs(record["complete"], True)
                self.assertEqual(record["boundary"], boundary)
                self.assertEqual(record["trigger"]["type"], "ProcessTableError")
                self.assertEqual(record["trigger"]["message"],
                                 r30.SAMPLED_TRACKED_RACE_ERROR)
                self.assertEqual(record["tracked_before"], [
                    {"pid": positive["root_identity"][0],
                     "create_time_100ns": positive["root_identity"][1]},
                    {"pid": positive["missing_identity"][0],
                     "create_time_100ns": positive["missing_identity"][1]},
                ])
                self.assertEqual(record["missing_tracked_identities"], [
                    {"pid": positive["missing_identity"][0],
                     "create_time_100ns": positive["missing_identity"][1]}])
                self.assertIs(record["root_live_before"], True)
                self.assertIs(record["root_live_after"], True)
                self.assertEqual(record["whole_bind_retry_limit"], 1)
                self.assertEqual(record["whole_bind_retry_count"], 1)
                self.assertEqual(positive["bind_call_count"], 2)
                self.assertEqual(positive["snapshot_call_count"], 3)
                self.assertEqual(positive["tracked"], {positive["root_identity"]})
                self.assertEqual(positive["result"][0], (positive["root_identity"],))
                natural = record["natural_exit_receipt"]
                self.assertIs(natural["complete"], True)
                self.assertIs(natural["wait_confirmed"], True)
                self.assertEqual(natural["exit_code"], 0)
                self.assertIs(natural["pid_reused_after_exit"], False)
                for seal_name in ("failure_before_snapshot", "fresh_after_exit_snapshot",
                                  "after_retry_snapshot"):
                    seal = record[seal_name]
                    self._assert_native_snapshot_seal(seal)
                    self.assertEqual(seal["host_identity"], list(table.WINDOWS_BUILD_PIN))
                    self.assertIn([positive["root_identity"][0], 4,
                                   positive["root_identity"][1], "julia.exe"],
                                  seal["process_rows"])
                self.assertEqual(record["failure_before_snapshot"]["process_rows"][-1][0],
                                 positive["root_identity"][0])
                root_check = record["failure_before_closure"]["live_generation_checks"][0]
                self.assertEqual(root_check["identity"], {
                    "pid": positive["root_identity"][0],
                    "create_time_100ns": positive["root_identity"][1]})
                self.assertIs(root_check["wait_signaled"], False)
                self.assertEqual(root_check["handle_identity_before_wait"],
                                 root_check["handle_identity_after_wait"])
                for credit_key in ("numerical_credit", "physical_credit",
                                   "solver_success_claimed"):
                    self.assertIs(record[credit_key], False)
                self.assertEqual(len(positive["boundary_records"]), 1)
                self.assertEqual(json.loads(positive["receipt_lines"][0]), record)

        # The PID may disappear naturally, but a fresh same-PID generation
        # immediately after the exact-handle exit receipt is a hard rejection.
        reused = self._exercise_boundary_case(
            "before_sample", observed_modes=("child_reused",))
        reuse_record = reused["record"]
        self.assertIs(reuse_record["complete"], False)
        self.assertEqual(reuse_record["reason"],
                         "exact_natural_exit_receipt_incomplete_or_reused")
        self.assertIs(reuse_record["natural_exit_receipt"]["complete"], True)
        self.assertIs(reuse_record["natural_exit_receipt"]["pid_reused_after_exit"], True)
        self.assertEqual(reuse_record["natural_exit_receipt"]["replacement_create_time_100ns"],
                         reused["missing_identity"][1] + 10)
        self.assertEqual(reuse_record["whole_bind_retry_count"], 0)
        self.assertEqual(reused["bind_call_count"], 1)

        # A stale PPID to the exited parent is orphan evidence, not a clear
        # residual; do not consume further SPI samples or retry the bind.
        orphan = self._exercise_boundary_case(
            "after_sample", failure_mode="root_and_orphan")
        orphan_record = orphan["record"]
        self.assertIs(orphan_record["complete"], False)
        self.assertEqual(orphan_record["reason"],
                         "boundary_reconciliation_evidence_incomplete")
        self.assertIn("visible process is orphaned from the missing parent PID",
                      orphan_record["reconciliation_error"]["message"])
        self.assertEqual(orphan_record["whole_bind_retry_count"], 0)
        self.assertEqual(orphan["snapshot_call_count"], 0)

        # Exact-one/non-root is mandatory; root loss and multiple losses cannot
        # be reinterpreted as the authorized single natural-exit case.
        root_missing = self._exercise_boundary_case(
            "before_sample", failure_mode="child_only", direct_reconcile=True)
        self.assertEqual(root_missing["record"]["reason"],
                         "root_missing_or_missing_identity_is_root")
        self.assertEqual(root_missing["record"]["whole_bind_retry_count"], 0)
        multiple_missing = self._exercise_boundary_case(
            "before_sample", failure_mode="sentinels_only", direct_reconcile=True)
        self.assertEqual(multiple_missing["record"]["reason"],
                         "missing_tracked_generation_count_is_not_exactly_one")
        self.assertEqual(multiple_missing["record"]["whole_bind_retry_count"], 0)

        # The trigger is type- and message-exact, including rejection of a
        # subclass that happens to inherit ProcessTableError.
        for trigger in ("wrong_type", "wrong_message", "subclass"):
            with self.subTest(trigger=trigger):
                wrong_trigger = self._exercise_boundary_case(
                    "before_sample", trigger=trigger, direct_reconcile=True)
                self.assertEqual(wrong_trigger["record"]["reason"],
                    "trigger_is_not_the_exact_tracked_missing_process_table_error")
                self.assertEqual(wrong_trigger["record"]["whole_bind_retry_count"], 0)
                self.assertEqual(wrong_trigger["snapshot_call_count"], 0)

        live_handle = self._exercise_boundary_case(
            "before_sample", wait_for_child=False)
        self.assertIs(live_handle["record"]["complete"], False)
        self.assertEqual(live_handle["record"]["natural_exit_receipt"]["reason"],
                         "exact_handle_not_signaled")
        self.assertEqual(live_handle["record"]["whole_bind_retry_count"], 0)
        self.assertEqual(live_handle["snapshot_call_count"], 0)
        still_active = self._exercise_boundary_case(
            "before_sample", observed_modes=("root_only",), exit_code=259)
        self.assertIs(still_active["record"]["natural_exit_receipt"]["complete"], True)
        self.assertEqual(still_active["record"]["natural_exit_receipt"]["exit_code"], 259)
        self.assertIs(still_active["record"]["complete"], False)
        self.assertEqual(still_active["record"]["whole_bind_retry_count"], 0)

        mixed = self._exercise_boundary_case(
            "before_sample", recovery_allowed=False)
        self.assertEqual(mixed["record"]["reason"],
                         "boundary_recovery_cannot_mix_with_sampling_recovery")
        self.assertEqual(mixed["record"]["whole_bind_retry_count"], 0)
        self.assertEqual(mixed["snapshot_call_count"], 0)

        # Fresh-source generation drift and an incomplete post-retry SPI seal
        # both retain the observed evidence and stay fail-closed.
        fresh_changed = self._exercise_boundary_case(
            "before_sample", observed_modes=("root_only", "root_reused"))
        self.assertIs(fresh_changed["record"]["complete"], False)
        self.assertIsNotNone(fresh_changed["record"]["fresh_after_exit_snapshot"])
        self._assert_native_snapshot_seal(
            fresh_changed["record"]["fresh_after_exit_snapshot"])
        self.assertEqual(fresh_changed["record"]["whole_bind_retry_count"], 0)
        self.assertEqual(
            fresh_changed["record"]["fresh_after_exit_snapshot"]["process_rows"][-1][2],
            fresh_changed["root_identity"][1] + 10)

        changed_failure_source = self._exercise_boundary_case(
            "before_sample", failure_mode="root_reused", direct_reconcile=True)
        self.assertEqual(changed_failure_source["record"]["reason"],
                         "tracked_pid_generation_mismatch")
        self._assert_native_snapshot_seal(
            changed_failure_source["record"]["failure_before_snapshot"])
        self.assertEqual(
            changed_failure_source["record"]["failure_before_snapshot"]["process_rows"][-1][2],
            changed_failure_source["root_identity"][1] + 10)
        self.assertEqual(changed_failure_source["record"]["whole_bind_retry_count"], 0)

        invalid_source = self._exercise_boundary_case(
            "before_sample", failure_mode="invalid", direct_reconcile=True)
        self.assertEqual(invalid_source["record"]["reason"],
                         "boundary_reconciliation_evidence_incomplete")
        self.assertIsNone(invalid_source["record"]["failure_before_snapshot"])
        self.assertEqual(invalid_source["record"]["whole_bind_retry_count"], 0)

        invalid_after_retry = self._exercise_boundary_case(
            "after_sample", observed_modes=("root_only", "root_only", "invalid"))
        self.assertIs(invalid_after_retry["record"]["complete"], False)
        self.assertEqual(invalid_after_retry["record"]["reason"],
                         "boundary_reconciliation_evidence_incomplete")
        self.assertEqual(invalid_after_retry["record"]["whole_bind_retry_count"], 1)
        self.assertIsNone(invalid_after_retry["record"]["after_retry_snapshot"])

        changed_after_retry = self._exercise_boundary_case(
            "after_sample", observed_modes=("root_only", "root_only", "root_reused"))
        self.assertIs(changed_after_retry["record"]["complete"], False)
        self.assertEqual(changed_after_retry["record"]["reason"],
                         "boundary_reconciliation_evidence_incomplete")
        self.assertEqual(changed_after_retry["record"]["whole_bind_retry_count"], 1)
        self._assert_native_snapshot_seal(
            changed_after_retry["record"]["after_retry_snapshot"])
        self.assertEqual(
            changed_after_retry["record"]["after_retry_snapshot"]["process_rows"][-1][2],
            changed_after_retry["root_identity"][1] + 10)

        stage_start = source.index("def _run_stage(")
        stage_end = source.index("\ndef _stage_pass(", stage_start)
        stage = source[stage_start:stage_end]
        after_boundary = stage.index('boundary="after_sample"')
        acceptance = stage.index('acceptance = {', after_boundary)
        accepted_record = stage.index("sample_boundary_acceptances.append(acceptance)",
                                      acceptance)
        sample_commit = stage.index("samples.append(sample)", accepted_record)
        disposition = stage.index("audit.sampled_resource_disposition(samples)", sample_commit)
        self.assertLess(after_boundary, acceptance)
        self.assertLess(acceptance, accepted_record)
        self.assertLess(accepted_record, sample_commit)
        self.assertLess(sample_commit, disposition)
        self.assertIn("if isinstance(exc, BoundaryReconciliationRejected):", stage)
        self.assertIn('monitor_error["boundary_reconciliation"] = exc.receipt', stage)
        self.assertIn('stop_reason = "resource_monitor_incomplete"', stage)

        # Exercise the real stage and serial dispatcher with an exact typed
        # boundary failure. The legacy fixture's missing-row RuntimeError is
        # translated only for this injected R23 snapshot, preserving the old
        # fixture source while forcing the real boundary reconciler to reject
        # a missing root generation.
        protocol_path = Path(r30.repo_path(r30.REL_PROTOCOL))
        loaded_protocol, loaded_receipt = r30.load_protocol_with_receipt(protocol_path)
        provider = _ensure_r30_input_provider()
        fixture_table = r28_fixture_support._R28RaceTable(tracked_child_exits=False)
        fixture_audit = r28_fixture_support._R28RaceAudit(fixture_table)
        fake_process = r28_fixture_support._R28Process(
            fixture_table, fixture_table.root_handle)
        native_table, _native_supervisor = r30._load_r23()
        query_index = [0]
        rejection_snapshot: list[Any] = []
        idle_ticks = 134345421481717430

        def make_native_snapshot(process_rows: list[tuple[tuple[int, int], int, str]]) -> Any:
            rows = [
                native_table.ProcessRow(
                    native_table.ProcessIdentity(0, idle_ticks), 0, ""),
                native_table.ProcessRow(
                    native_table.ProcessIdentity(4, idle_ticks), 0, "System"),
            ]
            rows.extend(native_table.ProcessRow(
                native_table.ProcessIdentity(identity[0], identity[1]), ppid, name)
                for identity, ppid, name in process_rows)
            return native_table.ProcessTableSnapshot(
                rows=tuple(rows), host_identity=native_table.WINDOWS_BUILD_PIN,
                buffer_bytes=native_table.SPI_FIXED_HEADER_BYTES,
                query_attempts=1, ntstatus_u32=0)

        def query_native_process_table() -> Any:
            query_index[0] += 1
            if query_index[0] == 1:
                process_rows: list[tuple[tuple[int, int], int, str]] = []
            elif query_index[0] in (2, 3):
                process_rows = [(fixture_table.root_identity, 1, "julia.exe")]
            elif query_index[0] == 4:
                # The root is absent while a visible child still names its PID.
                process_rows = [(fixture_table.tracked_child,
                                 fixture_table.root_identity[0], "tracked-helper.exe")]
            else:
                process_rows = ([] if fixture_table.root_identity in fixture_table.exited else
                                [(fixture_table.root_identity, 1, "julia.exe")])
            snapshot = make_native_snapshot(process_rows)
            if query_index[0] == 4:
                rejection_snapshot.append(snapshot)
            return snapshot

        legacy_descendants = fixture_table.descendant_identities

        def typed_missing_generation(snapshot: Any, root_identity: tuple[int, int],
                                     *, previously_tracked: Any = ()) -> Any:
            try:
                return legacy_descendants(
                    snapshot, root_identity, previously_tracked=previously_tracked)
            except RuntimeError as exc:
                if rejection_snapshot and snapshot is rejection_snapshot[0] and \
                        str(exc) == r30.SAMPLED_TRACKED_RACE_ERROR:
                    raise native_table.ProcessTableError(str(exc)) from exc
                raise

        fixture_table.query_native_process_table = query_native_process_table
        fixture_table.descendant_identities = typed_missing_generation
        temporary_output = tempfile.TemporaryDirectory(
            prefix="native_g1g2_r30_boundary_stage_")
        output = Path(temporary_output.name)
        launches: list[str] = []
        real_run_stage = r30._run_stage

        def observed_run_stage(stage_output: Path, index: int, stage_name: str,
                               command: list[str], environment: Any, table_arg: Any,
                               audit_arg: Any, *stage_args: Any) -> dict[str, Any]:
            launches.append(stage_name)
            return real_run_stage(stage_output, index, stage_name, command,
                                  environment, table_arg, audit_arg, *stage_args)

        plans = [
            {"stage": "primary", "argv": ["fake-julia", "primary"]},
            {"stage": "fresh_replay", "argv": ["fake-julia", "fresh_replay"]},
        ]
        try:
            with patch.object(r30.subprocess, "Popen", return_value=fake_process), \
                    patch.object(r30, "_run_stage", side_effect=observed_run_stage), \
                    patch.object(r30, "_INPUT_PROVIDER", provider):
                stages, sequence_failure = r30._run_stage_sequence(
                    output, plans, loaded_protocol, {}, fixture_table, fixture_audit,
                    protocol_path, loaded_receipt)
            stage_dir = output / "01_primary"
            retained_boundary_rows = (stage_dir / "boundary_reconciliations.jsonl").read_text(
                encoding="utf-8").splitlines()
            sample_attempt_bytes = (stage_dir / "sample_attempts.jsonl").read_bytes()
            later_stage_created = (output / "02_fresh_replay").exists()
        finally:
            temporary_output.cleanup()

        self.assertEqual(launches, ["primary"])
        self.assertEqual(len(stages), 1)
        self.assertIn("stop_reason=resource_monitor_incomplete", sequence_failure or "")
        stage_result = stages[0]
        self.assertEqual(stage_result["stop_reason"], "resource_monitor_incomplete")
        self.assertIs(stage_result["resource_monitor_complete"], False)
        self.assertEqual(stage_result["monitor_error"]["type"],
                         "BoundaryReconciliationRejected")
        rejected_receipt = stage_result["monitor_error"]["boundary_reconciliation"]
        self.assertEqual(rejected_receipt["reason"],
                         "root_missing_or_missing_identity_is_root")
        self.assertEqual(stage_result["boundary_reconciliations"], [rejected_receipt])
        self.assertEqual(len(retained_boundary_rows), 1)
        self.assertEqual(json.loads(retained_boundary_rows[0]), rejected_receipt)
        self.assertEqual(sample_attempt_bytes, b"")
        self.assertEqual(stage_result["sample_attempt_count"], 0)
        self.assertEqual(stage_result["samples"], [])
        self.assertEqual(stage_result["sample_boundary_acceptances"], [])
        self.assertFalse(later_stage_created)
        for credit_key in ("numerical_credit", "physical_credit",
                           "solver_success_claimed"):
            self.assertIs(stage_result[credit_key], False)

    def test_static_and_actual_r30_argv_roles_do_not_alias(self) -> None:
        protocol = r30.load_protocol(r30.repo_path(r30.REL_PROTOCOL))
        contract = protocol["invocation_contract"]
        r30.validate_invocation("static_verifier", contract["static_verifier_argv"], protocol)
        r30.validate_invocation("actual_supervisor", contract["actual_supervisor_argv"], protocol)
        with self.assertRaisesRegex(r30.PreflightError, "selected role"):
            r30.validate_invocation("actual_supervisor", contract["static_verifier_argv"], protocol)
        with self.assertRaisesRegex(r30.PreflightError, "selected role"):
            r30.validate_invocation("static_verifier", contract["actual_supervisor_argv"], protocol)

    def test_dispatch_binds_raw_protocol_receipt_through_prelaunch_and_every_stage(self) -> None:
        source = Path(r30.__file__).read_text(encoding="utf-8")
        dispatch_start = source.index("def dispatch_actual(")
        dispatch_end = source.index("\ndef main(", dispatch_start)
        dispatch = source[dispatch_start:dispatch_end]
        self.assertIn("protocol, loaded_protocol_receipt = load_protocol_with_receipt(protocol_path)",
                      dispatch)
        self.assertNotIn("load_protocol(protocol_path)", dispatch)
        self.assertIn('"protocol_sha256": loaded_protocol_receipt["sha256"]', dispatch)
        self.assertIn("protocol_path, loaded_protocol_receipt)", dispatch)
        self.assertIn('"protocol_file_at_load": loaded_protocol_receipt', dispatch)

        sequence_start = source.index("def _run_stage_sequence(")
        sequence_end = source.index("\ndef _set_environment(", sequence_start)
        sequence = source[sequence_start:sequence_end]
        before = sequence.index("protocol_before = verify_loaded_protocol_file(")
        launch = sequence.index("stage = dict(_run_stage(")
        after = sequence.index("protocol_after = verify_loaded_protocol_file(")
        self.assertLess(before, launch)
        self.assertLess(launch, after)
        for required in (
            'stage["protocol_file_before"] = protocol_before',
            'stage["protocol_file_after"] = protocol_after',
            'stage["protocol_file_integrity_complete"]',
            'stage["stop_reason"] = "protocol_file_drift"',
            "if not passed:\n            return stages, failure",
        ):
            with self.subTest(fragment=required):
                self.assertIn(required, sequence)

        stage_pass_start = source.index("def _stage_pass(")
        stage_pass_end = source.index("\ndef _run_stage_sequence(", stage_pass_start)
        stage_pass = source[stage_pass_start:stage_pass_end]
        self.assertLess(stage_pass.index('if stage.get("protocol_file_integrity_complete") is not True:'),
                        stage_pass.index('raw = (output /'))


if __name__ == "__main__":
    unittest.main(verbosity=2)
