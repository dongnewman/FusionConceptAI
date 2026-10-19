"""Focused trust-boundary tests for the historical source archive reader.

Run with ``python -B test/workspace_sources_tests.py``.  These controls use
temporary archives and do not establish formal T2 or production readiness.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import sys
import tempfile
import warnings
import zipfile
import zlib
from types import MappingProxyType, SimpleNamespace
from unittest.mock import patch

sys.dont_write_bytecode = True
REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

import unittest

from tools.workspace_sources import (
    HistoricalSourceError,
    HistoricalSourceReader,
    _cross_lane_file_identity,
    _stat_fingerprint,
)


INDEX_SCHEMA = "fusion-workspace-historical-source-index-v1"


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _entry(logical_path: str, snapshot_id: str, member: str, payload: bytes) -> dict:
    return {
        "logical_path": logical_path,
        "snapshot_id": snapshot_id,
        "archive_member": member,
        "bytes": len(payload),
        "sha256": _sha256(payload),
        "zip_crc32": zlib.crc32(payload) & 0xFFFFFFFF,
        "origin_receipt": {
            "path": logical_path,
            "bytes": len(payload),
            "sha256": _sha256(payload),
        },
    }


def _write_fixture(
    directory: Path,
    records: list[tuple[str, str, str, bytes]],
    *,
    zip_members: list[tuple[str, bytes]] | None = None,
    archive_comment: bytes = b"workspace-source-test",
) -> dict:
    """Write a small stored ZIP and its exact index; return mutable paths/data."""
    directory.mkdir(parents=True, exist_ok=True)
    archive_path = directory / "history.zip"
    index_path = directory / "index.json"
    members = zip_members if zip_members is not None else [
        (member, payload) for _, _, member, payload in records
    ]
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_STORED) as zf:
            for member, payload in members:
                zf.writestr(member, payload)
            zf.comment = archive_comment

    entries = [_entry(*record) for record in records]
    archive_bytes = archive_path.read_bytes()
    document = {
        "schema": INDEX_SCHEMA,
        "archive": {
            "path": archive_path.resolve().as_posix(),
            "bytes": len(archive_bytes),
            "sha256": _sha256(archive_bytes),
        },
        "entries": entries,
    }
    _write_index(index_path, document)
    return {
        "directory": directory,
        "archive_path": archive_path,
        "index_path": index_path,
        "document": document,
        "entries": entries,
    }


def _write_index(index_path: Path, document: dict, raw: bytes | None = None) -> None:
    if raw is None:
        raw = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    index_path.write_bytes(raw)


def _reader(fixture: dict, *, index_sha256: str | None = None,
            archive_path: Path | None = None,
            strict_subset: bool = False) -> HistoricalSourceReader:
    index_bytes = fixture["index_path"].read_bytes()
    subset_options = {"strict_subset": True} if strict_subset else {}
    return HistoricalSourceReader(
        fixture["index_path"],
        _sha256(index_bytes) if index_sha256 is None else index_sha256,
        fixture["archive_path"] if archive_path is None else archive_path,
        **subset_options,
    )


FROZEN_INPUT_CANDIDATE = (
    REPO_ROOT / "runs" / "e" / "t2_frozen_input_binding_20260928_r1" /
    "postimages" / "tools" / "execution" / "t2_source_inputs.py"
)
FROZEN_INPUT_CANDIDATE_SHA256 = "EAE1E83433F7501F9137476A9D3A66D33DD04801585C4E60F0F9639E7203DA43"
FROZEN_READER_CANDIDATE = (
    REPO_ROOT / "runs" / "e" / "t2_frozen_archive_reader_candidate_20260928_r1" /
    "postimage" / "tools" / "workspace_sources.py"
)
FROZEN_READER_CANDIDATE_SHA256 = "7C99B3BA9B8BF36923CCA729ECAAEB5748A2B9369922DD9AE6BBCB51F64A8920"


def _load_frozen_input_candidate():
    payload = FROZEN_INPUT_CANDIDATE.read_bytes()
    if _sha256(payload) != FROZEN_INPUT_CANDIDATE_SHA256.lower():
        raise AssertionError("T2SourceInputs candidate bytes differ from the reviewed frozen protocol pin")
    name = f"_frozen_input_candidate_test_{id(payload)}"
    spec = importlib.util.spec_from_file_location(name, FROZEN_INPUT_CANDIDATE)
    if spec is None or spec.loader is None:
        raise AssertionError("could not construct the exact FrozenInputSnapshot candidate loader")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    try:
        spec.loader.exec_module(module)
    except BaseException:
        sys.modules.pop(name, None)
        raise
    return module, name


def _frozen_entry(logical_path: str, role: str, payload: bytes) -> dict:
    return {"logical_path": logical_path, "role": role,
            "bytes": len(payload), "sha256": _sha256(payload)}


def _frozen_external_archive(logical_path: str, role: str,
                             origin_path: Path, payload: bytes) -> dict:
    return {"logical_path": logical_path, "role": role,
            "bytes": len(payload), "sha256": _sha256(payload),
            "origin_path": str(origin_path.resolve())}


def _fresh_snapshot_parent(root: Path) -> tuple[Path, Path]:
    repository = root / "repository"
    repository.mkdir(parents=True)
    snapshots = root / "snapshots"
    snapshots.mkdir()
    return repository, snapshots


class HistoricalSourceReaderTests(unittest.TestCase):
    def _load_t2_binding_copy(self, temporary_root: Path):
        source_files = {
            "tools/workspace_sources.py": REPO_ROOT / "tools/workspace_sources.py",
            "tools/execution/t2_source_inputs.py":
                REPO_ROOT / "tools/execution/t2_source_inputs.py",
            "test/fixtures/historical_sources/index.json":
                REPO_ROOT / "test/fixtures/historical_sources/index.json",
        }
        source_bytes = {}
        copied_paths = set()
        for relative, source_path in source_files.items():
            payload = source_path.read_bytes()
            target = temporary_root.joinpath(*relative.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(payload)
            source_bytes[relative] = payload
            copied_paths.add(relative)

        reader_module = sys.modules[HistoricalSourceReader.__module__]
        self.assertEqual(Path(reader_module.__file__).resolve(),
                         (REPO_ROOT / "tools/workspace_sources.py").resolve())
        self.assertIs(reader_module.HistoricalSourceReader, HistoricalSourceReader)

        binding_path = temporary_root / "tools" / "execution" / "t2_source_inputs.py"
        module_name = f"_t2_source_inputs_copy_test_{id(temporary_root)}"
        spec = importlib.util.spec_from_file_location(module_name, binding_path)
        self.assertIsNotNone(spec)
        self.assertIsNotNone(spec.loader)
        module = importlib.util.module_from_spec(spec)
        sys.modules[module_name] = module
        try:
            spec.loader.exec_module(module)
        except BaseException:
            sys.modules.pop(module_name, None)
            raise

        self.assertIs(module.HistoricalSourceReader, HistoricalSourceReader)
        self.assertEqual(module.READER_SHA256,
                         _sha256(source_bytes["tools/workspace_sources.py"]))
        self.assertEqual(module.INDEX_SHA256,
                         _sha256(source_bytes["test/fixtures/historical_sources/index.json"]))
        self.assertEqual(module._LOADED_BINDING_SHA256,
                         _sha256(source_bytes["tools/execution/t2_source_inputs.py"]))
        return module, module_name, copied_paths

    def test_same_lane_fingerprint_and_windows_cross_lane_identity_are_distinct(self) -> None:
        def stat_row(*, ctime: int, birthtime: int | None = 500) -> SimpleNamespace:
            return SimpleNamespace(
                st_dev=11,
                st_ino=22,
                st_size=33,
                st_mtime_ns=44,
                st_ctime_ns=ctime,
                st_mtime=0.000000044,
                st_ctime=ctime / 1_000_000_000,
                st_file_attributes=0,
                st_birthtime_ns=birthtime,
            )

        original = stat_row(ctime=100)
        cross_lane = stat_row(ctime=101)
        self.assertNotEqual(_stat_fingerprint(original), _stat_fingerprint(cross_lane))
        if os.name == "nt":
            self.assertEqual(
                _cross_lane_file_identity(original),
                _cross_lane_file_identity(cross_lane),
            )
            with self.assertRaises(HistoricalSourceError):
                _cross_lane_file_identity(stat_row(ctime=100, birthtime=None))
            self.assertNotEqual(
                _cross_lane_file_identity(original),
                _cross_lane_file_identity(stat_row(ctime=100, birthtime=501)),
            )
        else:
            self.assertEqual(_cross_lane_file_identity(original),
                             _stat_fingerprint(original))
            self.assertNotEqual(_cross_lane_file_identity(original),
                                _cross_lane_file_identity(cross_lane))

    def test_t2_explicit_history_binding_never_falls_back_to_local_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name, copied_paths = self._load_t2_binding_copy(root)
            try:
                self.assertEqual(copied_paths, {
                    "tools/workspace_sources.py",
                    "tools/execution/t2_source_inputs.py",
                    "test/fixtures/historical_sources/index.json",
                })
                sources = module.T2SourceInputs(root)
                layout = sources.describe()
                self.assertEqual(layout["schema"], "vnext-t2-explicit-source-layout-v1")
                self.assertEqual(layout["snapshot_id"], module.SNAPSHOT_ID)
                self.assertEqual(len(layout["historical_source_data"]), 82)

                relative = sorted(layout["historical_source_data"])[0]
                path = root.joinpath(*relative.split("/"))
                expected = layout["historical_source_data"][relative]
                self.assertFalse(path.exists(), "historical source was materialized locally")
                with self.assertRaises(FileNotFoundError):
                    sources.read_bytes(path)
                with self.assertRaises(FileNotFoundError):
                    sources.receipt(path)
                with self.assertRaises(RuntimeError):
                    sources.require_local_execution(path)

                archive_before = _sha256(module.ARCHIVE_PATH.read_bytes())
                archived = sources.read_historical_bytes(
                    path, module.SNAPSHOT_ID, expected)
                self.assertEqual(len(archived), expected["bytes"])
                self.assertEqual(_sha256(archived), expected["sha256"])
                self.assertEqual(sources.historical_receipt(
                    path, module.SNAPSHOT_ID, expected), expected)
                with self.assertRaises(RuntimeError):
                    sources.read_historical_bytes(path, "wrong-snapshot", expected)
                wrong_receipt = dict(expected, sha256="0" * 64)
                with self.assertRaises(RuntimeError):
                    sources.read_historical_bytes(path, module.SNAPSHOT_ID, wrong_receipt)

                protocol = {
                    "source_layout": layout,
                    "inputs": {
                        **layout["historical_source_data"],
                        **layout["binding_inputs"],
                    },
                }
                protocol_bytes = sources.read_protocol_input_bytes(protocol, path)
                self.assertEqual(protocol_bytes, archived)
                historical_receipt = sources.protocol_input_receipt(protocol, path)
                self.assertEqual(historical_receipt, {
                    "path": relative,
                    "bytes": len(protocol_bytes),
                    "sha256": _sha256(protocol_bytes),
                })

                wrong_snapshot_protocol = {
                    "source_layout": dict(layout, snapshot_id="wrong-snapshot"),
                    "inputs": dict(protocol["inputs"]),
                }
                with self.assertRaises(RuntimeError):
                    sources.read_protocol_input_bytes(wrong_snapshot_protocol, path)
                wrong_layout_protocol = {
                    "source_layout": dict(
                        layout, implicit_local_fallback_allowed=True),
                    "inputs": dict(protocol["inputs"]),
                }
                with self.assertRaises(RuntimeError):
                    sources.protocol_input_receipt(wrong_layout_protocol, path)

                local_bytes = b"current local sentinel, distinct from archive\n"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(local_bytes)
                self.assertEqual(sources.read_bytes(path), local_bytes)
                self.assertEqual(sources.receipt(path), {
                    "path": relative,
                    "bytes": len(local_bytes),
                    "sha256": _sha256(local_bytes),
                })
                self.assertEqual(sources.read_historical_bytes(
                    path, module.SNAPSHOT_ID, expected), archived)
                self.assertEqual(
                    sources.read_protocol_input_bytes(protocol, path), archived)
                self.assertEqual(sources.protocol_input_receipt(protocol, path), {
                    "path": relative,
                    "bytes": len(archived),
                    "sha256": _sha256(archived),
                })
                with self.assertRaises(RuntimeError):
                    sources.require_local_execution(path)

                unindexed = root / "current-only.txt"
                with self.assertRaises(FileNotFoundError):
                    sources.read_bytes(unindexed)
                with self.assertRaises(RuntimeError):
                    sources.protocol_input_receipt(protocol, unindexed)
                unindexed_bytes = b"local-only\n"
                unindexed.write_bytes(unindexed_bytes)
                self.assertEqual(sources.read_bytes(unindexed), unindexed_bytes)
                with self.assertRaises(RuntimeError):
                    sources.read_protocol_input_bytes(protocol, unindexed)
                local_pin = {
                    "path": "current-only.txt",
                    "bytes": len(unindexed_bytes),
                    "sha256": _sha256(unindexed_bytes),
                }
                local_protocol = {
                    "source_layout": layout,
                    "inputs": {**protocol["inputs"], "current-only.txt": local_pin},
                }
                current_bytes = sources.read_protocol_input_bytes(
                    local_protocol, unindexed)
                self.assertEqual(current_bytes, unindexed_bytes)
                self.assertEqual(sources.protocol_input_receipt(
                    local_protocol, unindexed), {
                        "path": "current-only.txt",
                        "bytes": len(current_bytes),
                        "sha256": _sha256(current_bytes),
                    })
                for wrong_pin in (
                        None,
                        dict(local_pin, bytes=len(unindexed_bytes) + 1),
                        dict(local_pin, sha256="0" * 64)):
                    wrong_pin_protocol = {
                        "source_layout": layout,
                        "inputs": dict(protocol["inputs"]),
                    }
                    if wrong_pin is not None:
                        wrong_pin_protocol["inputs"]["current-only.txt"] = wrong_pin
                    with self.assertRaises(RuntimeError):
                        sources.read_protocol_input_bytes(
                            wrong_pin_protocol, unindexed)
                sources.require_local_execution(unindexed)
                with self.assertRaises(RuntimeError):
                    sources.read_historical_bytes(
                        unindexed, module.SNAPSHOT_ID, expected)
                self.assertEqual(_sha256(module.ARCHIVE_PATH.read_bytes()), archive_before)
                for historical in layout["historical_source_data"]:
                    if historical != relative:
                        self.assertFalse(
                            root.joinpath(*historical.split("/")).exists(),
                            f"unrequested history was materialized: {historical}",
                        )
                self.assertFalse(any(path.suffix == ".pyc" for path in root.rglob("*")))
            finally:
                sys.modules.pop(module_name, None)

    def test_t1_strict_subset_reader_exposes_only_pinned_manifest_identities(self) -> None:
        index_path = REPO_ROOT / "test/fixtures/historical_sources/t1_manifest_index.json"
        index_bytes = index_path.read_bytes()
        self.assertEqual(len(index_bytes), 36_185)
        self.assertEqual(_sha256(index_bytes),
                         "57a3ddad571af1f4915c421af60231506474571d3bf355c2a51247113b95e07c")
        index = json.loads(index_bytes.decode("utf-8"))
        self.assertEqual(index["schema"], INDEX_SCHEMA)
        self.assertEqual(len(index["entries"]), 49)
        self.assertEqual({row["snapshot_id"] for row in index["entries"]},
                         {"t1-r26-precleanup-20260926"})
        archive_row = index["archive"]
        self.assertEqual(archive_row, {
            "path": "D:/006-Programing/LMC/FusionConceptAI_cleanup_20260926/precleanup_docs_runs_tmp.zip",
            "bytes": 472_888_641,
            "sha256": "c84743bc55dc749bbcc43e936c278027ad9bce9b437c09e176be587f75ff2bb7",
        })
        archive_path = Path(archive_row["path"])
        indexed_members = {row["archive_member"] for row in index["entries"]}
        indexed_logical_paths = {row["logical_path"] for row in index["entries"]}
        expected_identities = frozenset(
            (row["logical_path"], row["snapshot_id"]) for row in index["entries"])
        reader = HistoricalSourceReader(
            index_path, _sha256(index_bytes), archive_path, strict_subset=True)
        self.assertIs(type(reader.indexed_identities), frozenset)
        self.assertEqual(reader.indexed_identities, expected_identities)

        with zipfile.ZipFile(archive_path, "r") as archive:
            infos = archive.infolist()
        self.assertEqual(len(infos), 23_151)
        unindexed_logical_candidates = [
            info.filename for info in infos
            if not info.is_dir()
            and info.filename not in indexed_members
            and info.filename not in indexed_logical_paths
            and PurePosixPath(info.filename).as_posix() == info.filename
            and "\\" not in info.filename
            and all(part not in {"", ".", ".."} for part in info.filename.split("/"))
        ]
        self.assertTrue(unindexed_logical_candidates)
        with reader:
            observed_identities = set()
            for selected in index["entries"]:
                payload = reader.read_bytes(selected["logical_path"], selected["snapshot_id"])
                self.assertEqual(len(payload), selected["bytes"])
                self.assertEqual(_sha256(payload), selected["sha256"])
                self.assertEqual(zlib.crc32(payload) & 0xFFFFFFFF, selected["zip_crc32"])
                observed_identities.add((selected["logical_path"], selected["snapshot_id"]))
            self.assertEqual(frozenset(observed_identities), reader.indexed_identities)
            with self.assertRaises(HistoricalSourceError):
                reader.read_bytes(unindexed_logical_candidates[0], index["entries"][0]["snapshot_id"])

    def test_t2_protocol_layout_rejects_missing_or_changed_pins(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name, _ = self._load_t2_binding_copy(root)
            try:
                sources = module.T2SourceInputs(root)
                layout = sources.describe()
                required_pins = {
                    **layout["historical_source_data"],
                    **layout["binding_inputs"],
                }
                valid_protocol = {
                    "source_layout": layout,
                    "inputs": dict(required_pins),
                }
                sources.verify_protocol_layout(valid_protocol)

                missing_pin = {
                    "source_layout": layout,
                    "inputs": dict(required_pins),
                }
                missing_pin["inputs"].pop(sorted(layout["historical_source_data"])[0])
                with self.assertRaises(RuntimeError):
                    sources.verify_protocol_layout(missing_pin)

                missing_binding_pin = {
                    "source_layout": layout,
                    "inputs": dict(required_pins),
                }
                missing_binding_pin["inputs"].pop(sorted(layout["binding_inputs"])[0])
                with self.assertRaises(RuntimeError):
                    sources.verify_protocol_layout(missing_binding_pin)

                changed_layout = json.loads(json.dumps(valid_protocol))
                first_historical = sorted(layout["historical_source_data"])[0]
                changed_history = changed_layout["source_layout"]["historical_source_data"]
                changed_history[first_historical]["sha256"] = "0" * 64
                with self.assertRaises(RuntimeError):
                    sources.verify_protocol_layout(changed_layout)

                changed_pin = {
                    "source_layout": layout,
                    "inputs": dict(required_pins),
                }
                changed_pin["inputs"][first_historical] = dict(
                    changed_pin["inputs"][first_historical], sha256="f" * 64)
                with self.assertRaises(RuntimeError):
                    sources.verify_protocol_layout(changed_pin)

                index_path = root / module.INDEX_RELATIVE
                original_index_bytes = index_path.read_bytes()
                index_path.write_bytes(original_index_bytes + b"\n")
                with self.assertRaises(HistoricalSourceError):
                    sources.describe()
                index_path.write_bytes(original_index_bytes)

                # The post-init layout pass must reject helper-byte drift by its
                # fixed reader pin, rather than describing the changed bytes.
                reader_copy = root / module.READER_RELATIVE
                reader_copy.write_bytes(reader_copy.read_bytes() + b"\n")
                with self.assertRaisesRegex(
                        RuntimeError,
                        r"T2 current source binding helper drift: tools/workspace_sources\.py"):
                    sources.describe()
            finally:
                sys.modules.pop(module_name, None)

    def test_t2_local_read_rejects_external_symlink(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name, _ = self._load_t2_binding_copy(root)
            outside = root.parent / f"{root.name}-outside.txt"
            try:
                sources = module.T2SourceInputs(root)
                outside.write_bytes(b"must not be followed\n")
                link = root / "external-link.txt"
                try:
                    link.symlink_to(outside)
                except (OSError, NotImplementedError) as exc:
                    self.skipTest(f"filesystem does not permit symlink fixtures: {exc}")
                with self.assertRaises(RuntimeError):
                    sources.read_bytes(link)
                self.assertEqual(outside.read_bytes(), b"must not be followed\n")
            finally:
                sys.modules.pop(module_name, None)
                outside.unlink(missing_ok=True)

    def assert_rejected(self, fixture: dict, logical_path: str = "source.py",
                        snapshot_id: str = "s1", *, index_sha256: str | None = None,
                        archive_path: Path | None = None) -> None:
        with self.assertRaises(HistoricalSourceError):
            with _reader(fixture, index_sha256=index_sha256,
                         archive_path=archive_path) as reader:
                reader.read_bytes(logical_path, snapshot_id)

    def test_exact_logical_snapshot_identity_and_text_json_reads(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            old_source = b"value = 'historical A'\r\n"
            new_source = b"value = 'historical B'\r\n"
            json_source = b'{"version":2,"enabled":true}'
            fixture = _write_fixture(root, [
                ("src/model.py", "snapshot-a", "snapshots/a/model.py", old_source),
                ("src/model.py", "snapshot-b", "snapshots/b/model.py", new_source),
                ("metadata.json", "snapshot-b", "snapshots/b/metadata.json", json_source),
            ])

            with _reader(fixture) as reader:
                self.assertEqual(reader.read_bytes("src/model.py", "snapshot-a"), old_source)
                self.assertEqual(reader.read_text("src/model.py", "snapshot-b"), new_source.decode())
                self.assertEqual(reader.read_json("metadata.json", "snapshot-b"),
                                 {"version": 2, "enabled": True})
                with self.assertRaises(HistoricalSourceError):
                    reader.read_bytes("src/model.py", "not-an-indexed-snapshot")

    def test_local_drift_is_never_a_fallback_for_historical_bytes(self) -> None:
        for strict_subset in (False, True):
            with self.subTest(strict_subset=strict_subset), tempfile.TemporaryDirectory() as raw_dir:
                root = Path(raw_dir)
                archived = b"frozen source bytes\n"
                fixture = _write_fixture(
                    root,
                    [("src/current.py", "snapshot-17", "history/src/current.py", archived)],
                    zip_members=([("history/src/current.py", archived),
                                  ("unindexed.py", b"archived but not allowlisted\n")]
                                 if strict_subset else None),
                )
                local_dir = root / "local"
                local_dir.mkdir()
                (local_dir / "src").mkdir()
                (local_dir / "src" / "current.py").write_bytes(b"changed working tree bytes\n")
                (local_dir / "unindexed.py").write_bytes(b"must not be used\n")

                previous_cwd = Path.cwd()
                try:
                    os.chdir(local_dir)
                    with _reader(fixture, strict_subset=strict_subset) as reader:
                        self.assertEqual(reader.read_bytes("src/current.py", "snapshot-17"), archived)
                        with self.assertRaises(HistoricalSourceError):
                            reader.read_bytes("unindexed.py", "snapshot-17")
                finally:
                    os.chdir(previous_cwd)

    def test_snapshot_id_is_required_and_reader_is_context_scoped(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            fixture = _write_fixture(Path(raw_dir), [
                ("source.py", "s1", "source.py", b"x = 1\n"),
            ])
            reader = _reader(fixture)
            with self.assertRaises(HistoricalSourceError):
                reader.read_bytes("source.py", "s1")
            with reader as opened:
                with self.assertRaises(TypeError):
                    opened.read_bytes("source.py")
                self.assertEqual(opened.read_bytes("source.py", "s1"), b"x = 1\n")
            with self.assertRaises(HistoricalSourceError):
                reader.read_bytes("source.py", "s1")

    def test_reading_source_never_extracts_imports_or_writes_bytecode(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            marker = root / "imported.marker"
            payload = (
                "from pathlib import Path\n"
                f"Path({str(marker)!r}).write_text('imported')\n"
            ).encode("utf-8")
            fixture = _write_fixture(root, [
                ("archived_payload.py", "s1", "payload/archived_payload.py", payload),
            ])
            before = {p.relative_to(root) for p in root.rglob("*")}
            self.assertTrue(sys.dont_write_bytecode)
            with _reader(fixture) as reader:
                self.assertEqual(reader.read_text("archived_payload.py", "s1"), payload.decode())
            after = {p.relative_to(root) for p in root.rglob("*")}
            self.assertEqual(after, before)
            self.assertFalse(marker.exists())
            self.assertNotIn("archived_payload", sys.modules)
            self.assertFalse(any(p.suffix == ".pyc" for p in root.rglob("*")))

    def test_index_pin_and_archive_identity_metadata_are_enforced(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            fixture = _write_fixture(root / "case-index-pin", [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            self.assert_rejected(fixture, index_sha256="0" * 64)

            for case, field, wrong_value in (
                ("archive-hash", "sha256", "0" * 64),
                ("archive-size", "bytes", fixture["document"]["archive"]["bytes"] + 1),
            ):
                with self.subTest(case=case):
                    case_fixture = _write_fixture(root / case, [
                        ("source.py", "s1", "source.py", b"payload"),
                    ])
                    case_fixture["document"]["archive"][field] = wrong_value
                    _write_index(case_fixture["index_path"], case_fixture["document"])
                    self.assert_rejected(case_fixture)

            path_fixture = _write_fixture(root / "archive-path", [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            copied_archive = root / "different-path.zip"
            copied_archive.write_bytes(path_fixture["archive_path"].read_bytes())
            self.assert_rejected(path_fixture, archive_path=copied_archive)

            relative_archive_path = _write_fixture(root / "relative-archive-path", [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            relative_archive_path["document"]["archive"]["path"] = "history.zip"
            _write_index(relative_archive_path["index_path"],
                         relative_archive_path["document"])
            self.assert_rejected(relative_archive_path)

    def test_origin_receipt_must_bind_the_logical_source_and_payload(self) -> None:
        for field, value in (("path", "other.py"), ("bytes", 99), ("sha256", "f" * 64)):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(Path(raw_dir), [
                    ("source.py", "s1", "source.py", b"payload"),
                ])
                fixture["entries"][0]["origin_receipt"][field] = value
                _write_index(fixture["index_path"], fixture["document"])
                self.assert_rejected(fixture)

    def test_entry_size_hash_and_crc_metadata_are_checked(self) -> None:
        for field, value in (("bytes", 99), ("sha256", "0" * 64),
                             ("zip_crc32", 0xFFFFFFFF)):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(Path(raw_dir), [
                    ("source.py", "s1", "source.py", b"payload"),
                ])
                fixture["entries"][0][field] = value
                if field in {"bytes", "sha256"}:
                    fixture["entries"][0]["origin_receipt"][field] = value
                _write_index(fixture["index_path"], fixture["document"])
                self.assert_rejected(fixture)

    def test_member_bytes_are_verified_even_when_archive_pin_is_updated(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            payload = b"original payload"
            fixture = _write_fixture(root, [
                ("source.py", "s1", "source.py", payload),
            ])
            with zipfile.ZipFile(fixture["archive_path"], "r") as zf:
                info = zf.getinfo("source.py")
            local_header_end = info.header_offset + 30 + len(info.filename.encode("utf-8")) + len(info.extra)
            with fixture["archive_path"].open("r+b") as archive:
                archive.seek(local_header_end)
                first = archive.read(1)
                archive.seek(local_header_end)
                archive.write(bytes([first[0] ^ 0x01]))
                archive.flush()
                os.fsync(archive.fileno())
            archive_bytes = fixture["archive_path"].read_bytes()
            fixture["document"]["archive"] = {
                "path": fixture["archive_path"].resolve().as_posix(),
                "bytes": len(archive_bytes),
                "sha256": _sha256(archive_bytes),
            }
            _write_index(fixture["index_path"], fixture["document"])
            self.assert_rejected(fixture)

    def test_duplicate_index_entries_and_duplicate_zip_members_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            duplicate_pair = _write_fixture(root / "duplicate-pair", [
                ("source.py", "s1", "a.py", b"a"),
                ("source.py", "s1", "b.py", b"b"),
            ])
            self.assert_rejected(duplicate_pair, "source.py", "s1")

            duplicate_member = _write_fixture(root / "duplicate-member", [
                ("a.py", "s1", "shared.py", b"a"),
                ("b.py", "s1", "shared.py", b"a"),
            ], zip_members=[("shared.py", b"a")])
            self.assert_rejected(duplicate_member, "a.py", "s1")

            duplicate_zip = _write_fixture(
                root / "duplicate-zip",
                [("source.py", "s1", "source.py", b"first")],
                zip_members=[("source.py", b"first"), ("source.py", b"second")],
            )
            self.assert_rejected(duplicate_zip)

    def test_unindexed_zip_files_and_directory_entries_are_rejected(self) -> None:
        cases = (
            ("unindexed-file", [("source.py", b"source"), ("extra.bin", b"extra")]),
            ("directory-entry", [("source.py", b"source"), ("extra/", b"")]),
        )
        for case, zip_members in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(
                    Path(raw_dir),
                    [("source.py", "s1", "source.py", b"source")],
                    zip_members=zip_members,
                )
                self.assert_rejected(fixture)
                if case == "unindexed-file":
                    with _reader(fixture, strict_subset=True) as reader:
                        self.assertEqual(reader.read_bytes("source.py", "s1"), b"source")
                        with self.assertRaises(HistoricalSourceError):
                            reader.read_bytes("extra.bin", "s1")
                else:
                    with self.assertRaises(HistoricalSourceError):
                        with _reader(fixture, strict_subset=True):
                            pass

    def test_noncanonical_logical_and_member_paths_are_rejected(self) -> None:
        invalid_logical_paths = (
            "",
            "/absolute.py",
            "C:/drive.py",
            "a\\b.py",
            "a/./b.py",
            "a/../b.py",
            "a//b.py",
            "e\u0301.py",
        )
        for index, logical in enumerate(invalid_logical_paths):
            with self.subTest(kind="logical", value=logical), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(Path(raw_dir), [
                    (logical, "s1", f"member-{index}.py", b"payload"),
                ])
                self.assert_rejected(fixture, logical, "s1")

        invalid_members = (
            "",
            "/absolute.py",
            "C:/drive.py",
            "a\\b.py",
            "a/./b.py",
            "a/../b.py",
            "a//b.py",
            "e\u0301.py",
        )
        for index, member in enumerate(invalid_members):
            with self.subTest(kind="member", value=member), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(Path(raw_dir), [
                    ("source.py", "s1", "payload.bin", b"payload"),
                ])
                fixture["entries"][0]["archive_member"] = member
                _write_index(fixture["index_path"], fixture["document"])
                self.assert_rejected(fixture)

    def test_casefold_and_nfkc_casefold_aliases_are_rejected(self) -> None:
        alias_pairs = (("Foo.py", "foo.py"), ("ß.py", "ss.py"))
        for first, second in alias_pairs:
            with self.subTest(first=first, second=second), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(Path(raw_dir), [
                    (first, "s1", "a.py", b"a"),
                    (second, "s1", "b.py", b"b"),
                ])
                self.assert_rejected(fixture, first, "s1")

    def test_index_member_alias_and_unindexed_zip_alias_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            index_alias = _write_fixture(
                root / "index-member-alias",
                [("a.py", "s1", "a.py", b"a"),
                 ("b.py", "s1", "A.py", b"b")],
                zip_members=[("a.py", b"a"), ("b.py", b"b")],
            )
            self.assert_rejected(index_alias, "a.py", "s1")

            zip_alias = _write_fixture(
                root / "zip-member-alias",
                [("source.py", "s1", "source.py", b"source")],
                zip_members=[("source.py", b"source"), ("SOURCE.py", b"other")],
            )
            self.assert_rejected(zip_alias)
            with self.assertRaises(HistoricalSourceError):
                with _reader(zip_alias, strict_subset=True):
                    pass

    def test_duplicate_json_keys_are_rejected_in_index_and_source(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            index_fixture = _write_fixture(root / "duplicate-index-json", [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            valid_index = index_fixture["index_path"].read_bytes()
            duplicate_index = b'{"schema":"wrong",' + valid_index[1:]
            _write_index(index_fixture["index_path"], index_fixture["document"], duplicate_index)
            self.assert_rejected(index_fixture)

            source_fixture = _write_fixture(root / "duplicate-source-json", [
                ("data.json", "s1", "data.json", b'{"key":1,"key":2}'),
            ])
            with self.assertRaises(HistoricalSourceError):
                with _reader(source_fixture) as reader:
                    reader.read_json("data.json", "s1")

    def test_archive_mutation_during_reader_lifetime_fails_closed(self) -> None:
        for strict_subset in (False, True):
            with self.subTest(strict_subset=strict_subset), tempfile.TemporaryDirectory() as raw_dir:
                fixture = _write_fixture(
                    Path(raw_dir),
                    [("source.py", "s1", "source.py", b"stable payload")],
                    zip_members=([("source.py", b"stable payload"), ("extra.bin", b"unindexed")]
                                 if strict_subset else None),
                )
                with self.assertRaises(HistoricalSourceError):
                    with _reader(fixture, strict_subset=strict_subset) as reader:
                        self.assertEqual(reader.read_bytes("source.py", "s1"), b"stable payload")
                        try:
                            with fixture["archive_path"].open("r+b") as archive:
                                archive.seek(-1, os.SEEK_END)
                                old_byte = archive.read(1)
                                archive.seek(-1, os.SEEK_END)
                                archive.write(bytes([old_byte[0] ^ 0x01]))
                                archive.flush()
                                os.fsync(archive.fileno())
                        except OSError:
                            before = fixture["archive_path"].stat()
                            os.utime(
                                fixture["archive_path"],
                                ns=(before.st_atime_ns, before.st_mtime_ns + 1_000_000),
                            )

    def test_raw_symlink_components_are_rejected_before_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            fixture = _write_fixture(root, [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            index_link = root / "index-link.json"
            archive_link = root / "archive-link.zip"
            try:
                index_link.symlink_to(fixture["index_path"])
                archive_link.symlink_to(fixture["archive_path"])
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"filesystem does not permit symlink fixtures: {exc}")

            cases = (
                (index_link, fixture["archive_path"]),
                (fixture["index_path"], archive_link),
            )
            for index_path, archive_path in cases:
                with self.subTest(index_path=str(index_path), archive_path=str(archive_path)):
                    index_pin = _sha256(index_path.read_bytes())
                    with self.assertRaises(HistoricalSourceError):
                        HistoricalSourceReader(index_path, index_pin, archive_path)

    def test_symlinked_parent_components_are_rejected_before_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            fixture = _write_fixture(root, [
                ("source.py", "s1", "source.py", b"payload"),
            ])
            parent_link = root / "parent-link"
            try:
                parent_link.symlink_to(root, target_is_directory=True)
            except (OSError, NotImplementedError) as exc:
                self.skipTest(f"filesystem does not permit directory symlinks: {exc}")

            cases = (
                (parent_link / "index.json", fixture["archive_path"]),
                (fixture["index_path"], parent_link / "history.zip"),
            )
            for index_path, archive_path in cases:
                with self.subTest(index_path=str(index_path), archive_path=str(archive_path)):
                    index_pin = _sha256(index_path.read_bytes())
                    with self.assertRaises(HistoricalSourceError):
                        HistoricalSourceReader(index_path, index_pin, archive_path)

    def _freeze_test_snapshot(self, root: Path, *, entries: list[dict],
                              archives: list[dict] | None = None):
        module, module_name = _load_frozen_input_candidate()
        repository, snapshots = _fresh_snapshot_parent(root)
        for row in entries:
            source = repository.joinpath(*row["logical_path"].split("/"))
            source.parent.mkdir(parents=True, exist_ok=True)
            source.write_bytes(row.pop("_payload"))
        snapshot = module.FrozenInputSnapshot.freeze(
            repository, snapshots / "generation-1", entries,
            explicit_external_archives=[] if archives is None else archives)
        return module, module_name, repository, snapshots, snapshot

    def test_frozen_snapshot_entry_only_roundtrip_and_crossed_pins_reject(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            payload = b"entry source bytes"
            module, module_name, repository, snapshots, snapshot = self._freeze_test_snapshot(
                root, entries=[_frozen_entry("src/input.txt", "source", payload) |
                               {"_payload": payload}])
            try:
                self.assertEqual(snapshot.read_bytes("src/input.txt", len(payload),
                                                     _sha256(payload)), payload)
                self.assertEqual(snapshot.resolve("src/input.txt", len(payload),
                                                  _sha256(payload)).read_bytes(), payload)
                self.assertIsNone(snapshot.verify_all())
                other = repository / "src" / "other.txt"
                other.write_bytes(b"different generation")
                second = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "generation-2",
                    [_frozen_entry("src/input.txt", "source", payload),
                     _frozen_entry("src/other.txt", "source", b"different generation")])
                (second.root / "manifest.toml").write_bytes(
                    (snapshot.root / "manifest.toml").read_bytes())
                with self.assertRaises(RuntimeError):
                    snapshot.read_bytes("src/input.txt", len(payload), _sha256(b"wrong"))
                with self.assertRaises(RuntimeError):
                    module.FrozenInputSnapshot.open(second.root, snapshot.manifest_sha256)
            finally:
                sys.modules.pop(module_name, None)

    def test_frozen_snapshot_archive_only_is_raw_bytes_with_provenance_only(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            origin = root / "history.zip"
            origin.write_bytes(b"PK raw archive bytes\x00\xff")
            payload = origin.read_bytes()
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root)
            try:
                snapshot = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "archive-only", [],
                    explicit_external_archives=[_frozen_external_archive(
                        "historical_archives/code_history.zip", "historical-archive",
                        origin, payload)])
                receipt = snapshot.external_archives["historical_archives/code_history.zip"]
                self.assertEqual(receipt["origin_path"], str(origin.resolve()))
                self.assertEqual(receipt["frozen_path"], "_archives/history.zip")
                origin.write_bytes(b"changed outside snapshot")
                origin.unlink()
                self.assertEqual(snapshot.read_bytes("historical_archives/code_history.zip",
                                                     len(payload), _sha256(payload)), payload)
                self.assertEqual(snapshot.resolve("historical_archives/code_history.zip",
                                                  len(payload), _sha256(payload)).read_bytes(),
                                 payload)
            finally:
                sys.modules.pop(module_name, None)

    def test_frozen_snapshot_rejects_empty_closure_extra_files_and_directories(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root)
            try:
                with self.assertRaises(RuntimeError):
                    module.FrozenInputSnapshot.freeze(repository, snapshots / "empty", [])
                payload = b"declared"
                (repository / "one.txt").write_bytes(payload)
                snapshot = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "closed",
                    [_frozen_entry("one.txt", "source", payload)])
                (snapshot.root / "extra.bin").write_bytes(b"extra")
                with self.assertRaises(RuntimeError):
                    snapshot.verify_all()
                (snapshot.root / "extra.bin").unlink()
                (snapshot.root / "empty-extra-dir").mkdir()
                with self.assertRaises(RuntimeError):
                    module.FrozenInputSnapshot.open(snapshot.root, snapshot.manifest_sha256)

                empty = snapshots / "crafted-empty"
                empty.mkdir()
                manifest = (
                    '[snapshot]\nschema = "fusion-t2-frozen-input-snapshot-v1"\n'
                    'entry_count = 0\nexternal_archive_count = 0\n'
                    'inventory_root_sha256 = "' + _sha256(b"[]") + '"\n').encode()
                (empty / "manifest.toml").write_bytes(manifest)
                with self.assertRaises(RuntimeError):
                    module.FrozenInputSnapshot.open(empty, _sha256(manifest))
            finally:
                sys.modules.pop(module_name, None)

    def test_frozen_snapshot_rejects_missing_tampered_and_changed_manifest_bytes(self) -> None:
        for mutation in ("missing", "member-bytes", "manifest-bytes"):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as raw_dir:
                root = Path(raw_dir)
                payload = b"stable declared bytes"
                module, module_name, _, _, snapshot = self._freeze_test_snapshot(
                    root, entries=[_frozen_entry("input.bin", "source", payload) |
                                   {"_payload": payload}])
                try:
                    if mutation == "missing":
                        snapshot.resolve("input.bin", len(payload), _sha256(payload)).unlink()
                    elif mutation == "member-bytes":
                        member = snapshot.resolve("input.bin", len(payload), _sha256(payload))
                        member.write_bytes(b"changed declared bytes")
                    else:
                        manifest = snapshot.root / "manifest.toml"
                        manifest.write_bytes(manifest.read_bytes() + b"# changed\n")
                    with self.assertRaises(RuntimeError):
                        module.FrozenInputSnapshot.open(snapshot.root, snapshot.manifest_sha256)
                finally:
                    sys.modules.pop(module_name, None)

    def test_frozen_snapshot_rejects_absolute_parent_reserved_ads_and_unicode_paths(self) -> None:
        invalid = ("/absolute.txt", "../escape.txt", "CON.txt", "folder/NUL.log",
                   "file.txt:stream", "bad\\name.txt", "fullwidth/Ａ.txt")
        for logical in invalid:
            with self.subTest(logical=logical), tempfile.TemporaryDirectory() as raw_dir:
                root = Path(raw_dir)
                module, module_name = _load_frozen_input_candidate()
                repository, snapshots = _fresh_snapshot_parent(root)
                try:
                    with self.assertRaises(RuntimeError):
                        module.FrozenInputSnapshot.freeze(
                            repository, snapshots / "bad",
                            [_frozen_entry(logical, "source", b"x")])
                finally:
                    sys.modules.pop(module_name, None)

    def test_frozen_snapshot_rejects_casefold_and_nfkc_alias_collisions(self) -> None:
        pairs = (("Dir/Foo.txt", "dir/foo.txt"), ("a/ß.txt", "a/ss.txt"))
        for first, second in pairs:
            with self.subTest(first=first, second=second), tempfile.TemporaryDirectory() as raw_dir:
                root = Path(raw_dir)
                module, module_name = _load_frozen_input_candidate()
                repository, snapshots = _fresh_snapshot_parent(root)
                try:
                    for logical, payload in ((first, b"one"), (second, b"two")):
                        source = repository.joinpath(*logical.split("/"))
                        source.parent.mkdir(parents=True, exist_ok=True)
                        source.write_bytes(payload)
                    with self.assertRaises(RuntimeError):
                        module.FrozenInputSnapshot.freeze(
                            repository, snapshots / "collision",
                            [_frozen_entry(first, "source", b"one"),
                             _frozen_entry(second, "source", b"two")])
                finally:
                    sys.modules.pop(module_name, None)

    def test_frozen_snapshot_rejects_reparse_sources_and_hardlink_aliases(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root)
            try:
                target = repository / "target.bin"
                target.write_bytes(b"target")
                link = repository / "link.bin"
                symlink_available = True
                try:
                    link.symlink_to(target)
                except (OSError, NotImplementedError) as exc:
                    symlink_available = False
                    warnings.warn(
                        f"symlink reparse-source subcase unavailable; not counted as coverage: {exc}",
                        RuntimeWarning,
                    )
                if symlink_available:
                    with self.assertRaises(RuntimeError):
                        module.FrozenInputSnapshot.freeze(
                            repository, snapshots / "symlink",
                            [_frozen_entry("link.bin", "source", b"target")])
                    link.unlink()
                alias = repository / "hardlink.bin"
                try:
                    os.link(target, alias)
                except (OSError, NotImplementedError) as exc:
                    self.skipTest(f"filesystem does not permit hardlink fixture: {exc}")
                with self.assertRaises(RuntimeError):
                    module.FrozenInputSnapshot.freeze(
                        repository, snapshots / "hardlink",
                        [_frozen_entry("target.bin", "source", b"target"),
                         _frozen_entry("hardlink.bin", "source", b"target")])
            finally:
                sys.modules.pop(module_name, None)

    def test_frozen_snapshot_detects_source_identity_change_during_copy(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root)
            source = repository / "large.bin"
            payload = b"x" * (2 * 1024 * 1024)
            source.write_bytes(payload)
            original_open = Path.open
            touched = False

            class MutatingStream:
                def __init__(self, stream):
                    self.stream = stream

                def __enter__(self):
                    return self

                def __exit__(self, *args):
                    return self.stream.__exit__(*args)

                def fileno(self):
                    return self.stream.fileno()

                def read(self, size=-1):
                    nonlocal touched
                    result = self.stream.read(size)
                    if result and not touched:
                        touched = True
                        info = source.stat()
                        os.utime(source, ns=(info.st_atime_ns, info.st_mtime_ns + 2_000_000))
                    return result

            def intercepted_open(path, *args, **kwargs):
                stream = original_open(path, *args, **kwargs)
                if Path(path) == source and args and args[0] == "rb":
                    return MutatingStream(stream)
                return stream

            try:
                with patch.object(Path, "open", intercepted_open):
                    with self.assertRaises(RuntimeError):
                        module.FrozenInputSnapshot.freeze(
                            repository, snapshots / "changed-during-copy",
                            [_frozen_entry("large.bin", "source", payload)])
                self.assertTrue(touched)
            finally:
                sys.modules.pop(module_name, None)

    def test_historical_reader_binds_index_and_archive_to_frozen_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            fixture = _write_fixture(root / "original", [
                ("source.py", "s1", "source.py", b"historical source bytes"),
            ], zip_members=[("source.py", b"historical source bytes"),
                            ("unindexed.py", b"extra member")])
            index_bytes = fixture["index_path"].read_bytes()
            archive_bytes = fixture["archive_path"].read_bytes()
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root / "snapshot")
            try:
                index_source = repository / "historical_sources" / "index.json"
                index_source.parent.mkdir(parents=True)
                index_source.write_bytes(index_bytes)
                snapshot = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "generation-1",
                    [_frozen_entry("historical_sources/index.json", "historical-index",
                                   index_bytes)],
                    explicit_external_archives=[_frozen_external_archive(
                        "historical_archives/code_history.zip", "historical-archive",
                        fixture["archive_path"], archive_bytes)])
                reader = HistoricalSourceReader.from_frozen_snapshot(
                    snapshot, "historical_sources/index.json", _sha256(index_bytes),
                    "historical_archives/code_history.zip",
                    expected_snapshot_id=snapshot.snapshot_id,
                    expected_manifest_sha256=snapshot.manifest_sha256,
                    strict_subset=True)
                with reader:
                    self.assertEqual(reader.read_bytes("source.py", "s1"),
                                     b"historical source bytes")
                    with self.assertRaises(HistoricalSourceError):
                        reader.read_bytes("unindexed.py", "s1")
                exact_reader = HistoricalSourceReader.from_frozen_snapshot(
                    snapshot, "historical_sources/index.json", _sha256(index_bytes),
                    "historical_archives/code_history.zip",
                    expected_snapshot_id=snapshot.snapshot_id,
                    expected_manifest_sha256=snapshot.manifest_sha256,
                    strict_subset=False)
                with self.assertRaises(HistoricalSourceError):
                    with exact_reader:
                        pass
                fixture["archive_path"].unlink()
                with self.assertRaises(HistoricalSourceError):
                    HistoricalSourceReader.from_frozen_snapshot(
                        snapshot, "historical_sources/index.json", _sha256(index_bytes),
                        "historical_archives/code_history.zip",
                        expected_snapshot_id="0" * 64,
                        expected_manifest_sha256=snapshot.manifest_sha256)
            finally:
                sys.modules.pop(module_name, None)
        self._assert_t2_frozen_constructor_binds_ids_root_helpers_and_never_falls_back()

    def test_historical_reader_frozen_binding_rejects_origin_mismatch_and_foreign_archive(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            fixture = _write_fixture(root / "original", [
                ("source.py", "s1", "source.py", b"historical source bytes"),
            ])
            index_bytes = fixture["index_path"].read_bytes()
            archive_bytes = fixture["archive_path"].read_bytes()
            module, module_name = _load_frozen_input_candidate()
            repository, snapshots = _fresh_snapshot_parent(root / "snapshot")
            try:
                index_source = repository / "historical_sources" / "index.json"
                index_source.parent.mkdir(parents=True)
                # The immutable index keeps its original archive path and must match the
                # archive row's exact origin metadata; another file with equal bytes is not a binding.
                index_source.write_bytes(index_bytes)
                other_origin = root / "copied-history.zip"
                other_origin.write_bytes(archive_bytes)
                snapshot = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "generation-1",
                    [_frozen_entry("historical_sources/index.json", "historical-index",
                                   index_bytes)],
                    explicit_external_archives=[_frozen_external_archive(
                        "historical_archives/code_history.zip", "historical-archive",
                        other_origin, archive_bytes)])
                with self.assertRaises(HistoricalSourceError):
                    HistoricalSourceReader.from_frozen_snapshot(
                        snapshot, "historical_sources/index.json", _sha256(index_bytes),
                        "historical_archives/code_history.zip",
                        expected_snapshot_id=snapshot.snapshot_id,
                        expected_manifest_sha256=snapshot.manifest_sha256)

                generation_marker = repository / "generation-marker.txt"
                generation_marker.write_bytes(b"other generation")
                matching = module.FrozenInputSnapshot.freeze(
                    repository, snapshots / "generation-2",
                    [_frozen_entry("historical_sources/index.json", "historical-index",
                                   index_bytes),
                     _frozen_entry("generation-marker.txt", "marker", b"other generation")],
                    explicit_external_archives=[_frozen_external_archive(
                        "historical_archives/code_history.zip", "historical-archive",
                        fixture["archive_path"], archive_bytes)])
                with self.assertRaises(HistoricalSourceError):
                    HistoricalSourceReader.from_frozen_snapshot(
                        matching, "historical_sources/index.json", _sha256(index_bytes),
                        "historical_archives/code_history.zip",
                        expected_snapshot_id=snapshot.snapshot_id,
                        expected_manifest_sha256=snapshot.manifest_sha256)
            finally:
                sys.modules.pop(module_name, None)

    def _assert_t2_frozen_constructor_binds_ids_root_helpers_and_never_falls_back(self) -> None:
        with tempfile.TemporaryDirectory() as raw_dir:
            root = Path(raw_dir)
            freezer_module, freezer_name = _load_frozen_input_candidate()

            # Archive bytes may come from a copied preparation input while the
            # sealed row retains the original, possibly unavailable, provenance path.
            archive_case_repo, archive_case_snapshots = _fresh_snapshot_parent(
                root / "archive-source-binding")
            probe_file = archive_case_repo / "probe.txt"
            probe_file.write_bytes(b"archive source-path fixture")
            copied_archive_source = root / "copied_archive_source.zip"
            with zipfile.ZipFile(copied_archive_source, "w",
                                 compression=zipfile.ZIP_STORED) as probe_archive:
                probe_archive.writestr("probe.bin", b"explicit archive source bytes")
            probe_payload = copied_archive_source.read_bytes()
            absent_legacy_origin = root / "legacy_origin" / "historical.zip"
            self.assertFalse(absent_legacy_origin.exists())
            archive_binding = _frozen_external_archive(
                "historical_archives/probe.zip", "historical-archive",
                absent_legacy_origin, probe_payload)
            archive_binding["source_path"] = str(copied_archive_source.resolve())
            archive_snapshot = freezer_module.FrozenInputSnapshot.freeze(
                archive_case_repo, archive_case_snapshots / "archive-source-authorized",
                [_frozen_entry("probe.txt", "fixture", b"archive source-path fixture")],
                explicit_external_archives=[archive_binding])
            archive_row = archive_snapshot.external_archives[
                "historical_archives/probe.zip"]
            self.assertEqual(archive_row["origin_path"],
                             str(absent_legacy_origin.resolve()))
            self.assertNotIn("source_path", archive_row)
            frozen_probe_archive = archive_snapshot.root.joinpath(
                *archive_row["frozen_path"].split("/"))
            self.assertEqual(frozen_probe_archive.read_bytes(), probe_payload)
            self.assertEqual(archive_row["bytes"], len(probe_payload))
            self.assertEqual(archive_row["sha256"], _sha256(probe_payload))
            reopened_archive_snapshot = freezer_module.FrozenInputSnapshot.open(
                archive_snapshot.root, archive_snapshot.manifest_sha256)
            reopened_archive_row = reopened_archive_snapshot.external_archives[
                "historical_archives/probe.zip"]
            self.assertEqual(reopened_archive_row["origin_path"],
                             str(absent_legacy_origin.resolve()))
            self.assertNotIn("source_path", reopened_archive_row)

            repository, snapshots = _fresh_snapshot_parent(root)
            index_source = REPO_ROOT / "test" / "fixtures" / "historical_sources" / "index.json"
            index_bytes = index_source.read_bytes()
            archive_origin = Path(freezer_module.ARCHIVE_PATH)
            archive_bytes = archive_origin.read_bytes()
            reader_bytes = FROZEN_READER_CANDIDATE.read_bytes()
            binding_bytes = FROZEN_INPUT_CANDIDATE.read_bytes()
            self.assertEqual(_sha256(reader_bytes), FROZEN_READER_CANDIDATE_SHA256.lower())
            copies = {
                "tools/workspace_sources.py": reader_bytes,
                "tools/execution/t2_source_inputs.py": binding_bytes,
                "test/fixtures/historical_sources/index.json": index_bytes,
            }
            for logical, payload in copies.items():
                target = repository.joinpath(*logical.split("/"))
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(payload)
            entries = [_frozen_entry(logical, "t2-binding-input", payload)
                       for logical, payload in copies.items()]
            source_snapshot = freezer_module.FrozenInputSnapshot.freeze(
                repository, snapshots / "authorized-generation", entries,
                explicit_external_archives=[_frozen_external_archive(
                    "historical_archives/code_history.zip", "historical-archive",
                    archive_origin, archive_bytes)])

            formal_env_names = (
                "FUSION_T2_FROZEN_SNAPSHOT_ID",
                "FUSION_T2_FROZEN_MANIFEST_SHA256",
                "FUSION_T2_FROZEN_PROTOCOL_SHA256",
                "FUSION_T2_FROZEN_PROTOCOL_PATH",
            )
            protocol_source_snapshot = {
                "schema": "fusion-t2-frozen-input-snapshot-v1",
                "source_root": str(source_snapshot.root),
                "manifest_path": "manifest.toml",
                "manifest_bytes": (source_snapshot.root / "manifest.toml").stat().st_size,
                "manifest_sha256": source_snapshot.manifest_sha256,
                "inventory_root_sha256": source_snapshot.inventory_root_sha256,
                "snapshot_id": source_snapshot.inventory_root_sha256,
                "expected_entries": {
                    key: {field: row[field] for field in ("role", "bytes", "sha256")}
                    for key, row in source_snapshot.entries.items()},
                "expected_external_archives": {
                    key: {field: row[field] for field in ("role", "bytes", "sha256")}
                    for key, row in source_snapshot.external_archives.items()},
            }
            protocol_path = root / "external_t2_protocol.json"

            def write_protocol(source_snapshot_record: dict[str, object], *,
                               wrapped: bool = True) -> bytes:
                payload: dict[str, object]
                if wrapped:
                    payload = {"consumer": {"protocol": {
                        "source_snapshot": source_snapshot_record}}}
                else:
                    payload = {"source_snapshot": source_snapshot_record}
                raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
                protocol_path.write_bytes(raw)
                return raw

            protocol_bytes = write_protocol(protocol_source_snapshot)
            protocol_sha256 = _sha256(protocol_bytes)
            source_formal_env = {
                formal_env_names[0]: source_snapshot.inventory_root_sha256,
                formal_env_names[1]: source_snapshot.manifest_sha256,
                formal_env_names[2]: protocol_sha256,
                formal_env_names[3]: str(protocol_path.resolve()),
            }
            external_snapshot = freezer_module.FrozenInputSnapshot.open(
                source_snapshot.root, source_snapshot.manifest_sha256)
            with patch.dict(os.environ, source_formal_env, clear=True):
                with self.assertRaises(RuntimeError):
                    freezer_module.T2SourceInputs(
                        external_snapshot.root, frozen_snapshot=external_snapshot,
                        expected_snapshot_id=external_snapshot.snapshot_id,
                        expected_manifest_sha256=external_snapshot.manifest_sha256)

            old_reader_module = sys.modules.get("tools.workspace_sources")
            binding_name = "tools.execution._t2_source_inputs_frozen_test"
            old_binding_module = sys.modules.get(binding_name)
            try:
                reader_path = source_snapshot.root / "tools" / "workspace_sources.py"
                reader_spec = importlib.util.spec_from_file_location(
                    "tools.workspace_sources", reader_path)
                self.assertIsNotNone(reader_spec)
                self.assertIsNotNone(reader_spec.loader)
                reader_module = importlib.util.module_from_spec(reader_spec)
                sys.modules["tools.workspace_sources"] = reader_module
                reader_spec.loader.exec_module(reader_module)

                binding_path = source_snapshot.root / "tools" / "execution" / "t2_source_inputs.py"
                binding_spec = importlib.util.spec_from_file_location(binding_name, binding_path)
                self.assertIsNotNone(binding_spec)
                self.assertIsNotNone(binding_spec.loader)
                binding_module = importlib.util.module_from_spec(binding_spec)
                sys.modules[binding_name] = binding_module
                binding_spec.loader.exec_module(binding_module)
                snapshot = binding_module.FrozenInputSnapshot.open(
                    source_snapshot.root, source_snapshot.manifest_sha256)
                snapshot.entries = MappingProxyType({
                    key: MappingProxyType(dict(row))
                    for key, row in snapshot.entries.items()})
                snapshot.external_archives = MappingProxyType({
                    key: MappingProxyType(dict(row))
                    for key, row in snapshot.external_archives.items()})

                protocol_snapshot_authorization = {
                    "snapshot_id": snapshot.snapshot_id,
                    "inventory_root_sha256": snapshot.inventory_root_sha256,
                    "manifest_sha256": snapshot.manifest_sha256,
                    "protocol_sha256": protocol_sha256,
                    "protocol_path": str(protocol_path.resolve()),
                }
                formal_env = {
                    formal_env_names[0]: protocol_snapshot_authorization["inventory_root_sha256"],
                    formal_env_names[1]: protocol_snapshot_authorization["manifest_sha256"],
                    formal_env_names[2]: protocol_snapshot_authorization["protocol_sha256"],
                    formal_env_names[3]: protocol_snapshot_authorization["protocol_path"],
                }
                self.assertEqual(protocol_snapshot_authorization["snapshot_id"],
                                 protocol_snapshot_authorization["inventory_root_sha256"])
                self.assertNotEqual(protocol_snapshot_authorization["snapshot_id"],
                                    binding_module.SNAPSHOT_ID,
                                    "frozen inventory ID and historical member snapshot ID are distinct")

                for missing_name in formal_env_names:
                    partial_env = dict(formal_env)
                    partial_env.pop(missing_name)
                    with patch.dict(os.environ, partial_env, clear=True):
                        with self.assertRaises(RuntimeError):
                            binding_module.T2SourceInputs(root / "not-a-source-root")
                for malformed_name in formal_env_names:
                    malformed_env = dict(formal_env)
                    malformed_env[malformed_name] = "malformed-pin"
                    with patch.dict(os.environ, malformed_env, clear=True):
                        with self.assertRaises(RuntimeError):
                            binding_module.T2SourceInputs(root / "not-a-source-root")

                with patch.dict(os.environ, formal_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(root / "not-a-source-root")

                missing_protocol_path_env = dict(formal_env)
                missing_protocol_path_env[formal_env_names[3]] = str(
                    root / "missing_external_protocol.json")
                with patch.dict(os.environ, missing_protocol_path_env, clear=True):
                    with self.assertRaises((FileNotFoundError, RuntimeError)):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                original_protocol = protocol_path.read_bytes()
                protocol_path.write_bytes(original_protocol + b" ")
                with patch.dict(os.environ, formal_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)
                protocol_path.write_bytes(b"{}")
                rehashed_malformed_protocol_env = dict(formal_env)
                rehashed_malformed_protocol_env[formal_env_names[2]] = _sha256(
                    protocol_path.read_bytes())
                with patch.dict(os.environ, rehashed_malformed_protocol_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                protocol_path.write_bytes(original_protocol)
                foreign_record = dict(protocol_source_snapshot)
                foreign_record["source_root"] = str(root / "foreign-generation")
                foreign_raw = write_protocol(foreign_record)
                foreign_protocol_env = dict(formal_env)
                foreign_protocol_env[formal_env_names[2]] = _sha256(foreign_raw)
                with patch.dict(os.environ, foreign_protocol_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                foreign_record = dict(protocol_source_snapshot)
                foreign_entries = dict(protocol_source_snapshot["expected_entries"])
                foreign_entries["tools/workspace_sources.py"] = {
                    **foreign_entries["tools/workspace_sources.py"],
                    "sha256": "0" * 64,
                }
                foreign_record["expected_entries"] = foreign_entries
                foreign_raw = write_protocol(foreign_record)
                foreign_protocol_env[formal_env_names[2]] = _sha256(foreign_raw)
                with patch.dict(os.environ, foreign_protocol_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                protocol_path.write_bytes(original_protocol)
                wrong_protocol_sha_env = dict(formal_env)
                wrong_protocol_sha_env[formal_env_names[2]] = "0" * 64
                with patch.dict(os.environ, wrong_protocol_sha_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                protocol_path.write_bytes(original_protocol)
                with patch.dict(os.environ, formal_env, clear=True):
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id="0" * 64,
                            expected_manifest_sha256=snapshot.manifest_sha256)
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            snapshot.root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256="0" * 64)
                    with self.assertRaises(RuntimeError):
                        binding_module.T2SourceInputs(
                            root, frozen_snapshot=snapshot,
                            expected_snapshot_id=snapshot.snapshot_id,
                            expected_manifest_sha256=snapshot.manifest_sha256)

                    wrong_inventory_env = dict(formal_env)
                    wrong_inventory_env[formal_env_names[0]] = "0" * 64
                    with patch.dict(os.environ, wrong_inventory_env, clear=True):
                        with self.assertRaises(RuntimeError):
                            binding_module.T2SourceInputs(
                                snapshot.root, frozen_snapshot=snapshot,
                                expected_snapshot_id=snapshot.snapshot_id,
                                expected_manifest_sha256=snapshot.manifest_sha256)
                    wrong_manifest_env = dict(formal_env)
                    wrong_manifest_env[formal_env_names[1]] = "0" * 64
                    with patch.dict(os.environ, wrong_manifest_env, clear=True):
                        with self.assertRaises(RuntimeError):
                            binding_module.T2SourceInputs(
                                snapshot.root, frozen_snapshot=snapshot,
                                expected_snapshot_id=snapshot.snapshot_id,
                                expected_manifest_sha256=snapshot.manifest_sha256)

                    bound = binding_module.T2SourceInputs(
                        snapshot.root, frozen_snapshot=snapshot,
                        expected_snapshot_id=protocol_snapshot_authorization["inventory_root_sha256"],
                        expected_manifest_sha256=protocol_snapshot_authorization["manifest_sha256"])
                self.assertIs(bound.frozen_snapshot, snapshot)
                self.assertEqual(bound.root, snapshot.root)
                self.assertEqual(len(bound.history), 82)
                self.assertEqual(reader_module.__file__, str(reader_path))
                self.assertEqual(Path(binding_module.__file__), binding_path)
                self.assertEqual(_sha256(bound.read_bytes(bound.index)), _sha256(index_bytes))
                logical = next(iter(bound.history))
                expected = bound.history[logical]
                historical = bound.read_historical_bytes(
                    snapshot.root.joinpath(*logical.split("/")),
                    binding_module.SNAPSHOT_ID, expected)
                self.assertEqual(len(historical), expected["bytes"])
                self.assertEqual(_sha256(historical), expected["sha256"])

                direct_protocol = write_protocol(protocol_source_snapshot, wrapped=False)
                direct_protocol_env = dict(formal_env)
                direct_protocol_env[formal_env_names[2]] = _sha256(direct_protocol)
                with patch.dict(os.environ, direct_protocol_env, clear=True):
                    direct_bound = binding_module.T2SourceInputs(
                        snapshot.root, frozen_snapshot=snapshot,
                        expected_snapshot_id=snapshot.snapshot_id,
                        expected_manifest_sha256=snapshot.manifest_sha256)
                self.assertIs(direct_bound.frozen_snapshot, snapshot)
                self.assertEqual(len(direct_bound.history), 82)

                archive_row = snapshot.external_archives[
                    "historical_archives/code_history.zip"]
                frozen_archive = snapshot.root.joinpath(*archive_row["frozen_path"].split("/"))
                frozen_archive.write_bytes(b"tampered frozen archive")
                with self.assertRaises((HistoricalSourceError, RuntimeError)):
                    bound.read_historical_bytes(
                        snapshot.root.joinpath(*logical.split("/")),
                        binding_module.SNAPSHOT_ID, expected)
            finally:
                sys.modules.pop(binding_name, None)
                if old_binding_module is not None:
                    sys.modules[binding_name] = old_binding_module
                if old_reader_module is None:
                    sys.modules.pop("tools.workspace_sources", None)
                else:
                    sys.modules["tools.workspace_sources"] = old_reader_module
                sys.modules.pop(freezer_name, None)


if __name__ == "__main__":
    unittest.main(verbosity=2)
