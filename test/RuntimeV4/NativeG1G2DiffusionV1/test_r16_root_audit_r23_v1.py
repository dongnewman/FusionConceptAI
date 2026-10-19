from __future__ import annotations

import ctypes
import importlib.util
import math
import os
import subprocess
import sys
import unittest
from pathlib import Path
from typing import Any


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def _load(name: str, path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot load {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


table = _load("native_process_table_r23_v1", HERE / "native_process_table_r23_v1.py")
supervisor = _load("supervise_r16_root_audit_r23_v1_tests", HERE / "supervise_r16_root_audit_r23_v1.py")
HOST = table.WINDOWS_BUILD_PIN


def _align8(value: int) -> int:
    return (value + 7) & ~7


def make_snapshot(rows: list[tuple[int, int, int, str, int]]) -> table.ProcessTableSnapshot:
    """Build a minimal, fully bounded fake SPI response.

    Each row is (pid, ppid, FILETIME ticks, image name, thread count).
    """
    spans = []
    for pid, _ppid, _ticks, name, threads in rows:
        name_bytes = name.encode("utf-16le")
        base = table.SPI_FIXED_HEADER_BYTES + threads * table.SYSTEM_THREAD_INFORMATION_BYTES
        spans.append(_align8(base + len(name_bytes)))
    total = sum(spans)
    buffer = ctypes.create_string_buffer(total)
    base_address = ctypes.addressof(buffer)
    offset = 0
    for index, ((pid, ppid, ticks, name, threads), span) in enumerate(zip(rows, spans)):
        record = table._SystemProcessInformationPrefix.from_address(base_address + offset)
        record.NextEntryOffset = span if index != len(rows) - 1 else 0
        record.NumberOfThreads = threads
        record.CreateTime = ticks
        record.UniqueProcessId = pid or None
        record.InheritedFromUniqueProcessId = ppid or None
        encoded = name.encode("utf-16le")
        record.ImageName.Length = len(encoded)
        record.ImageName.MaximumLength = len(encoded)
        if encoded:
            name_address = base_address + offset + table.SPI_FIXED_HEADER_BYTES + threads * table.SYSTEM_THREAD_INFORMATION_BYTES
            record.ImageName.Buffer = name_address
            ctypes.memmove(name_address, encoded, len(encoded))
        else:
            record.ImageName.Buffer = None
        offset += span
    return table.parse_spi_buffer(buffer, total, host_identity=HOST)


def rows_base() -> list[tuple[int, int, int, str, int]]:
    return [
        (0, 0, 1_343_454_214_817_174_30, "", 0),
        (4, 0, 1_343_454_214_817_174_30, "System", 3),
        (301, 4, 1_343_454_214_817_174_31, "python.exe", 4),
        (302, 301, 1_343_454_214_817_174_32, "julia.exe", 7),
        (303, 302, 1_343_454_214_817_174_33, "desc.exe", 2),
    ]


class FakePopen:
    def __init__(self, pid: int, handle: str):
        self.pid = pid
        self._handle = handle


class IntConvertibleHandle:
    def __int__(self) -> int:
        return 123


class NativeProcessTableR23Tests(unittest.TestCase):
    def setUp(self) -> None:
        self.snapshot = make_snapshot(rows_base())

    def test_exact_x64_layout_and_build_pin(self) -> None:
        table._validate_abi()
        self.assertEqual(table._SystemProcessInformationPrefix.CreateTime.offset, 32)
        self.assertEqual(table._SystemProcessInformationPrefix.ImageName.offset, 56)
        self.assertEqual(table._SystemProcessInformationPrefix.UniqueProcessId.offset, 80)
        self.assertEqual(table._SystemProcessInformationPrefix.InheritedFromUniqueProcessId.offset, 88)
        with self.assertRaises(table.ProcessTableError):
            table._validate_host_identity((10, 0, 26100, "AMD64"))
        with self.assertRaises(table.ProcessTableError):
            table._validate_host_identity((10, 0, 26200, "ARM64"))

    def test_handle_normalization_rejects_arbitrary_intable_and_aliases(self) -> None:
        for bad in (True, IntConvertibleHandle(), 0, -1, ctypes.c_void_p(None)):
            with self.subTest(value=repr(bad)):
                with self.assertRaises(table.ProcessTableError):
                    table._raw_handle_value(bad, phase="test")

    @unittest.skipUnless(os.name == "nt", "Windows subprocess.Handle integration")
    def test_real_windows_popen_handle_identity_and_wait(self) -> None:
        popen = subprocess.Popen(
            [sys.executable, "-B", "-c", "pass"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=False,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        try:
            self.assertIs(type(popen._handle), subprocess.Handle)
            identity = table.read_process_handle_identity(popen._handle)
            self.assertEqual(identity[0], popen.pid)
            self.assertTrue(table.wait_for_process_exit(popen._handle, 5.0))
            self.assertEqual(table.process_exit_code(popen._handle), 0)
            self.assertEqual(popen.wait(timeout=5.0), 0)
        finally:
            if popen.poll() is None:
                popen.kill()
                popen.wait(timeout=5.0)

    def test_full_thread_record_spans_and_exact_rows_parse(self) -> None:
        self.assertEqual(len(self.snapshot.rows), 5)
        self.assertEqual(self.snapshot.by_pid[302].identity.create_time_100ns,
                         1_343_454_214_817_174_32)
        self.assertEqual(self.snapshot.by_pid[302].name, "julia.exe")
        self.assertEqual(self.snapshot.by_pid[302].ppid, 301)

    def test_duplicate_pid_fails_closed(self) -> None:
        rows = rows_base() + [(302, 301, 200, "julia.exe", 1)]
        with self.assertRaises(table.ProcessTableError):
            make_snapshot(rows)

    def test_unknown_build_and_bad_record_lengths_fail_closed(self) -> None:
        self.assertRaises(table.ProcessTableError, table._validate_host_identity,
                          (10, 0, 26201, "AMD64"))
        with self.assertRaises(table.ProcessTableError):
            table.parse_spi_buffer(ctypes.create_string_buffer(100), 100,
                                   host_identity=HOST)

    def test_invalid_next_entry_offset_fails_closed(self) -> None:
        rows = rows_base()
        sizes = [_align8(table.SPI_FIXED_HEADER_BYTES + row[4] *
                         table.SYSTEM_THREAD_INFORMATION_BYTES + len(row[3].encode("utf-16le")))
                 for row in rows]
        total = sum(sizes)
        buffer = ctypes.create_string_buffer(total)
        address = ctypes.addressof(buffer)
        first = table._SystemProcessInformationPrefix.from_address(address)
        first.NextEntryOffset = 1
        with self.assertRaises(table.ProcessTableError):
            table.parse_spi_buffer(buffer, total, host_identity=HOST)

    def test_bad_utf16_and_image_pointer_escape_fail_closed(self) -> None:
        encoded_rows = rows_base()
        encoded_rows[2] = (301, 4, encoded_rows[2][2], "X", 0)
        spans = [_align8(table.SPI_FIXED_HEADER_BYTES + len(row[3].encode("utf-16le")))
                 for row in encoded_rows]
        total = sum(spans)
        buffer = ctypes.create_string_buffer(total)
        address = ctypes.addressof(buffer)
        offset = 0
        for index, (row, span) in enumerate(zip(encoded_rows, spans)):
            record = table._SystemProcessInformationPrefix.from_address(address + offset)
            record.NextEntryOffset = span if index < len(encoded_rows) - 1 else 0
            record.NumberOfThreads = 0
            record.CreateTime = row[2]
            record.UniqueProcessId = row[0] or None
            record.InheritedFromUniqueProcessId = row[1] or None
            text = row[3].encode("utf-16le")
            record.ImageName.Length = len(text)
            record.ImageName.MaximumLength = len(text)
            if text:
                record.ImageName.Buffer = address + offset + table.SPI_FIXED_HEADER_BYTES
                ctypes.memmove(record.ImageName.Buffer, text, len(text))
            offset += span
        broken = table._SystemProcessInformationPrefix.from_address(address + spans[0])
        broken.ImageName.Buffer = address + total + 8
        with self.assertRaises(table.ProcessTableError):
            table.parse_spi_buffer(buffer, total, host_identity=HOST)

    def test_invalid_utf16_image_bytes_fail_closed(self) -> None:
        rows = rows_base()
        spans = [_align8(table.SPI_FIXED_HEADER_BYTES + len(row[3].encode("utf-16le")))
                 for row in rows]
        total = sum(spans)
        buffer = ctypes.create_string_buffer(total)
        address = ctypes.addressof(buffer)
        offset = 0
        for index, (row, span) in enumerate(zip(rows, spans)):
            record = table._SystemProcessInformationPrefix.from_address(address + offset)
            record.NextEntryOffset = span if index < len(rows) - 1 else 0
            record.NumberOfThreads = 0
            record.CreateTime = row[2]
            record.UniqueProcessId = row[0] or None
            record.InheritedFromUniqueProcessId = row[1] or None
            text = row[3].encode("utf-16le")
            record.ImageName.Length = len(text)
            record.ImageName.MaximumLength = len(text)
            if text:
                record.ImageName.Buffer = address + offset + table.SPI_FIXED_HEADER_BYTES
                ctypes.memmove(record.ImageName.Buffer, text, len(text))
            offset += span
        # Replace PID 301's name with a lone UTF-16 high surrogate.
        record = table._SystemProcessInformationPrefix.from_address(address + spans[0] + spans[1])
        record.ImageName.Length = 2
        record.ImageName.MaximumLength = 2
        record.ImageName.Buffer = address + spans[0] + spans[1] + table.SPI_FIXED_HEADER_BYTES
        ctypes.memmove(record.ImageName.Buffer, b"\x00\xd8", 2)
        with self.assertRaises(table.ProcessTableError):
            table.parse_spi_buffer(buffer, total, host_identity=HOST)

    def test_strict_native_pid_and_tick_types_reject_bool_float_and_alias(self) -> None:
        for identity in ((True, 100), (301, True), (301, 1.0), (301, -1), (0, 100)):
            with self.subTest(identity=identity), self.assertRaises(table.ProcessTableError):
                table.validate_identity(identity)
        with self.assertRaises(table.ProcessTableError):
            table.validate_pid(True)

    def test_one_tick_alias_is_not_exact_identity(self) -> None:
        before = (301, 134_345_421_427_015_660)
        adjacent = (301, 134_345_421_427_015_661)
        self.assertNotEqual(before, adjacent)
        self.assertEqual(table.display_seconds(before[1]), table.display_seconds(adjacent[1]))
        with self.assertRaises(table.ProcessTableError):
            table.require_same_identity(adjacent, before, phase="one-tick-negative")

    def test_stale_snapshot_handle_generation_fails(self) -> None:
        old = (301, 1_343_454_214_817_174_31)
        new = (301, 1_343_454_214_817_174_32)
        with self.assertRaises(table.ProcessTableError):
            table.require_handle_matches_table(
                "old-handle", new, self.snapshot,
                handle_identity_reader=lambda _handle: old,
            )

    def test_handle_access_denial_fails_closed(self) -> None:
        identity = (301, 1_343_454_214_817_174_31)
        with self.assertRaises(table.ProcessTableError):
            table.require_handle_matches_table(
                "denied-handle", identity, self.snapshot,
                handle_identity_reader=lambda _handle: (_ for _ in ()).throw(PermissionError("denied")),
            )

    def test_popen_original_handle_must_match_table_generation(self) -> None:
        popen = FakePopen(301, "popen-handle")
        expected = (301, 1_343_454_214_817_174_31)
        self.assertEqual(supervisor.bind_popen_generation(
            popen, self.snapshot,
            handle_identity_reader=lambda _handle: expected,
        ), expected)
        with self.assertRaises(supervisor.MonitorIncomplete):
            supervisor.bind_popen_generation(
                popen, self.snapshot,
                handle_identity_reader=lambda _handle: (301, expected[1] + 1),
            )

    def test_exact_handle_registry_caches_and_closes_only_owned_handles(self) -> None:
        closed = []
        opened: dict[int, str] = {}
        def opener(row: table.ProcessRow) -> str:
            handle = f"open-{row.identity.pid}"
            opened[row.identity.pid] = handle
            return handle
        def reader(handle: str) -> tuple[int, int]:
            if handle == "popen":
                return (301, 1_343_454_214_817_174_31)
            pid = int(handle.split("-")[1])
            return (pid, self.snapshot.by_pid[pid].identity.create_time_100ns)
        registry = supervisor.ExactHandleRegistry(
            opener=opener, identity_reader=reader, closer=closed.append,
        )
        popen = FakePopen(301, "popen")
        root = registry.bind_popen(popen, self.snapshot)
        row = self.snapshot.by_pid[302]
        first = registry.for_row(row, self.snapshot)
        second = registry.for_row(row, self.snapshot)
        self.assertEqual(first, second)
        self.assertEqual(root, (301, 1_343_454_214_817_174_31))
        self.assertEqual(registry.identities, (
            (301, 1_343_454_214_817_174_31),
            (302, 1_343_454_214_817_174_32),
        ))
        close_receipt = registry.close_owned()
        self.assertTrue(close_receipt["complete"])
        self.assertEqual(closed, ["open-302"])
        self.assertEqual(close_receipt["popen_handles_not_owned_by_registry"], 1)

    def test_descendant_tree_preserves_exact_ids(self) -> None:
        observed = table.descendant_identities(self.snapshot,
            (301, 1_343_454_214_817_174_31))
        self.assertEqual([(item.pid, item.create_time_100ns) for item in observed], [
            (301, 1_343_454_214_817_174_31),
            (302, 1_343_454_214_817_174_32),
            (303, 1_343_454_214_817_174_33),
        ])

    def test_parent_pid_reuse_chronology_is_ambiguous_and_fails(self) -> None:
        rows = rows_base()
        rows[2] = (301, 4, 1_343_454_214_817_174_99, "python.exe", 1)
        with self.assertRaises(table.ProcessTableError):
            snapshot = make_snapshot(rows)
            table.descendant_identities(snapshot, (301, 1_343_454_214_817_174_99))

    def test_previous_identity_pid_reuse_fails_closed(self) -> None:
        with self.assertRaises(table.ProcessTableError):
            table.descendant_identities(
                self.snapshot, (301, 1_343_454_214_817_174_31),
                previously_tracked=((302, 1_343_454_214_817_174_99),),
            )

    def test_spi_host_smoke_is_read_only_and_build_pinned(self) -> None:
        if os.name != "nt":
            self.skipTest("Windows SPI host smoke is platform-specific")
        observed = table.query_native_process_table()
        self.assertEqual(observed.host_identity, HOST)
        self.assertGreater(len(observed.rows), 100)
        self.assertEqual(observed.by_pid[4].name, "System")


class R23SupervisorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.snapshot = make_snapshot(rows_base())
        self.root = (301, 1_343_454_214_817_174_31)
        self.handle_ids = {
            "301": self.root,
            "302": (302, 1_343_454_214_817_174_32),
            "303": (303, 1_343_454_214_817_174_33),
        }

    def test_sample_uses_exact_spi_and_raw_handle_identity(self) -> None:
        sample = supervisor.sample_process_tree(
            self.root,
            snapshot_provider=lambda: self.snapshot,
            handle_provider=lambda row: str(row.identity.pid),
            resource_reader=lambda pid: {
                "rss_bytes": pid * 100,
                "cpu_user_seconds": 1.25,
                "cpu_system_seconds": 0.5,
                "cmdline": ["pinned", str(pid)],
            },
            handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
        )
        self.assertTrue(sample["complete"], sample["errors"])
        self.assertEqual(sample["rss_bytes"], 30100 + 30200 + 30300)
        self.assertEqual(sample["discovered_identities"], sample["measured_identities"])
        self.assertTrue(all("create_time_100ns" in row for row in sample["processes"]))

    def test_psutil_float_alias_is_never_consulted(self) -> None:
        sample = supervisor.sample_process_tree(
            self.root, snapshot_provider=lambda: self.snapshot,
            handle_provider=lambda row: str(row.identity.pid),
            resource_reader=lambda pid: {
                "rss_bytes": 1, "cpu_user_seconds": 0, "cpu_system_seconds": 0,
                "cmdline": [],
            },
            handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
        )
        self.assertTrue(sample["complete"], sample["errors"])
        self.assertNotIn("psutil", sample["identity_source"])

    def test_resource_read_handle_generation_change_incomplete(self) -> None:
        calls: dict[str, int] = {}
        def changing_reader(handle: str) -> tuple[int, int]:
            calls[handle] = calls.get(handle, 0) + 1
            expected = self.handle_ids[handle]
            if handle == "302" and calls[handle] == 2:
                return (expected[0], expected[1] + 1)
            return expected
        sample = supervisor.sample_process_tree(
            self.root, snapshot_provider=lambda: self.snapshot,
            handle_provider=lambda row: str(row.identity.pid),
            resource_reader=lambda pid: {
                "rss_bytes": 1, "cpu_user_seconds": 0, "cpu_system_seconds": 0,
                "cmdline": [],
            },
            handle_identity_reader=changing_reader,
        )
        self.assertFalse(sample["complete"])
        self.assertEqual(sample["disposition"] if "disposition" in sample else None, None)
        self.assertFalse(sample["numerical_credit"])

    def test_table_churn_after_resource_reads_incomplete(self) -> None:
        changed = make_snapshot([
            rows_base()[0], rows_base()[1], rows_base()[2],
            (302, 301, 1_343_454_214_817_174_34, "julia.exe", 7),
            rows_base()[4],
        ])
        calls = 0
        def provider() -> table.ProcessTableSnapshot:
            nonlocal calls
            calls += 1
            return self.snapshot if calls == 1 else changed
        sample = supervisor.sample_process_tree(
            self.root, snapshot_provider=provider,
            handle_provider=lambda row: str(row.identity.pid),
            resource_reader=lambda pid: {
                "rss_bytes": 1, "cpu_user_seconds": 0, "cpu_system_seconds": 0,
                "cmdline": [],
            },
            handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
        )
        self.assertFalse(sample["complete"])
        self.assertIsNone(sample["rss_bytes"])

    def test_process_table_access_denial_incomplete(self) -> None:
        sample = supervisor.sample_process_tree(
            self.root, snapshot_provider=lambda: (_ for _ in ()).throw(PermissionError("NtQuery denied")),
            handle_provider=lambda row: str(row.identity.pid),
            resource_reader=lambda pid: {},
            handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
        )
        self.assertFalse(sample["complete"])
        self.assertFalse(sample["numerical_credit"])
        self.assertIn("NtQuery denied", sample["errors"][0]["message"])

    def test_malformed_rss_or_cpu_fails_closed(self) -> None:
        for rss in (-1, True, "1", 1.5):
            with self.subTest(rss=rss):
                sample = supervisor.sample_process_tree(
                    self.root, snapshot_provider=lambda: self.snapshot,
                    handle_provider=lambda row: str(row.identity.pid),
                    resource_reader=lambda pid, invalid=rss: {
                        "rss_bytes": invalid, "cpu_user_seconds": 0,
                        "cpu_system_seconds": 0, "cmdline": [],
                    },
                    handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
                )
                self.assertFalse(sample["complete"])
        for cpu in (True, -1, float("nan"), float("inf")):
            with self.subTest(cpu=cpu):
                sample = supervisor.sample_process_tree(
                    self.root, snapshot_provider=lambda: self.snapshot,
                    handle_provider=lambda row: str(row.identity.pid),
                    resource_reader=lambda pid, invalid=cpu: {
                        "rss_bytes": 1, "cpu_user_seconds": invalid,
                        "cpu_system_seconds": 0, "cmdline": [],
                    },
                    handle_identity_reader=lambda handle: self.handle_ids[str(handle)],
                )
                self.assertFalse(sample["complete"])

    def test_heavy_inventory_from_spi_names(self) -> None:
        self.assertEqual(supervisor.global_heavy_processes(self.snapshot), (
            (302, 1_343_454_214_817_174_32),
            (303, 1_343_454_214_817_174_33),
        ))

    def test_terminate_signal_error_never_waits_or_claims_success(self) -> None:
        calls = {"signal": 0, "wait": 0}
        receipt = supervisor.signal_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=lambda: self.snapshot,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            signal_sender=lambda handle: (_ for _ in ()).throw(PermissionError("TerminateProcess denied")),
            wait_for_exit=lambda handle, timeout: calls.__setitem__("wait", calls["wait"] + 1),
            exit_code_reader=lambda handle: 0,
        )
        self.assertFalse(receipt["complete"])
        self.assertEqual(calls, {"signal": 0, "wait": 0})

    def test_table_generation_changes_at_signal_boundary_never_signals(self) -> None:
        calls = {"snapshot": 0, "signal": 0, "wait": 0}
        changed_rows = rows_base()
        changed_rows[3] = (302, 301, 1_343_454_214_817_174_99, "julia.exe", 7)
        changed = make_snapshot(changed_rows)
        def provider() -> table.ProcessTableSnapshot:
            calls["snapshot"] += 1
            return self.snapshot if calls["snapshot"] == 1 else changed
        receipt = supervisor.signal_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=provider,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            signal_sender=lambda handle: calls.__setitem__("signal", calls["signal"] + 1),
            wait_for_exit=lambda handle, timeout: calls.__setitem__("wait", calls["wait"] + 1),
            exit_code_reader=lambda handle: 0,
        )
        self.assertFalse(receipt["complete"])
        self.assertFalse(receipt["signal_sent"])
        self.assertEqual(calls["signal"], 0)
        self.assertEqual(calls["wait"], 0)
        self.assertFalse(receipt["numerical_credit"])

    def test_signal_generation_mismatch_sends_no_signal(self) -> None:
        calls = {"signal": 0, "wait": 0}
        receipt = supervisor.signal_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=lambda: self.snapshot,
            handle_identity_reader=lambda handle: (302, 1_343_454_214_817_174_33),
            signal_sender=lambda handle: calls.__setitem__("signal", calls["signal"] + 1),
            wait_for_exit=lambda handle, timeout: calls.__setitem__("wait", calls["wait"] + 1),
            exit_code_reader=lambda handle: 0,
        )
        self.assertFalse(receipt["complete"])
        self.assertFalse(receipt["signal_sent"])
        self.assertEqual(calls, {"signal": 0, "wait": 0})

    def test_successful_exact_signal_requires_old_generation_absent(self) -> None:
        calls = {"snapshot": 0}
        def provider() -> table.ProcessTableSnapshot:
            calls["snapshot"] += 1
            if calls["snapshot"] <= 2:
                return self.snapshot
            rows = rows_base()
            rows[3] = (302, 301, 1_343_454_214_817_174_34, "julia.exe", 1)
            return make_snapshot(rows)
        receipt = supervisor.signal_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=provider,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            signal_sender=lambda handle: None,
            wait_for_exit=lambda handle, timeout: True,
            exit_code_reader=lambda handle: 15,
        )
        self.assertTrue(receipt["complete"])
        self.assertFalse(receipt["post_table_same_generation_present"])
        self.assertEqual(receipt["post_table_reused_pid_ticks"],
                         1_343_454_214_817_174_34)

    def test_natural_wait_requires_exact_post_exit_absence(self) -> None:
        calls = {"snapshot": 0}
        def provider() -> table.ProcessTableSnapshot:
            calls["snapshot"] += 1
            if calls["snapshot"] == 1:
                return self.snapshot
            rows = rows_base()
            rows.pop(3)
            return make_snapshot(rows)
        receipt = supervisor.wait_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=provider,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            wait_for_exit=lambda handle, timeout: True,
            exit_code_reader=lambda handle: 0,
        )
        self.assertTrue(receipt["complete"])
        self.assertFalse(receipt["signal_sent"])
        self.assertEqual(receipt["exit_code"], 0)

    def test_natural_wait_old_identity_still_present_fails(self) -> None:
        receipt = supervisor.wait_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=lambda: self.snapshot,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            wait_for_exit=lambda handle, timeout: True,
            exit_code_reader=lambda handle: 0,
        )
        self.assertFalse(receipt["complete"])

    def test_wait_bool_exit_code_fails_closed(self) -> None:
        calls = {"snapshot": 0}
        def provider() -> table.ProcessTableSnapshot:
            calls["snapshot"] += 1
            rows = rows_base()
            if calls["snapshot"] > 1:
                rows.pop(3)
            return make_snapshot(rows)
        receipt = supervisor.wait_exact_process(
            "302", (302, 1_343_454_214_817_174_32),
            snapshot_provider=provider,
            handle_identity_reader=lambda handle: self.handle_ids[handle],
            wait_for_exit=lambda handle, timeout: True,
            exit_code_reader=lambda handle: True,
        )
        self.assertFalse(receipt["complete"])

    def test_residual_audit_is_generation_exact(self) -> None:
        receipt = supervisor.audit_residual_identities(
            [(302, 1_343_454_214_817_174_32)], self.snapshot,
        )
        self.assertTrue(receipt["complete"])
        self.assertEqual(len(receipt["residual_exact_identities"]), 1)
        reused = make_snapshot([
            rows_base()[0], rows_base()[1], rows_base()[2],
            (302, 301, 1_343_454_214_817_174_34, "julia.exe", 1), rows_base()[4],
        ])
        cleared = supervisor.audit_residual_identities(
            [(302, 1_343_454_214_817_174_32)], reused,
        )
        self.assertTrue(cleared["complete"])
        self.assertTrue(cleared["residual_clear"])

    def test_sampled_limit_semantics_unchanged_and_no_numerical_credit(self) -> None:
        below = supervisor.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 1, "elapsed_seconds": 1.0},
        ])
        self.assertEqual(below["disposition"], "no_sampled_rss_threshold_crossing")
        self.assertEqual(below["rss_threshold_bytes"], 2_147_483_648)
        hit = supervisor.sampled_resource_disposition([
            {"complete": True, "rss_bytes": 2_147_483_649, "elapsed_seconds": 1.0},
        ])
        self.assertEqual(hit["disposition"], "resource_failure")
        self.assertFalse(hit["numerical_credit"])
        self.assertEqual(supervisor.static_contract()["wall_seconds_per_stage"], 480.0)

    def test_runtime_dispatch_is_disabled_without_root_grant(self) -> None:
        with self.assertRaisesRegex(RuntimeError, "independent review and root grant"):
            supervisor.runtime_dispatch()


if __name__ == "__main__":
    unittest.main(verbosity=2)
