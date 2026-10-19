"""Shared exact Windows process-table and lifecycle consumer bridge.

The R23 T2 and Native R30 postimages load this source only through their
protocol-pinned source closures. Any runtime result remains bounded by those
consumers' exact SPI, retained-handle, resource, exit, cleanup, and outer
process receipts. Generation identity is the native pair (PID, raw 100 ns
FILETIME ticks) from the build-pinned SPI table and a Windows process handle;
psutil is a resource reader only.
"""

from __future__ import annotations

import importlib.util
import hashlib
import json
import math
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[3]
TEST_DIR = Path(__file__).resolve().parent
TABLE_HELPER_PATH = TEST_DIR / "native_process_table_r23_v1.py"
TABLE_HELPER_REL = "test/RuntimeV4/NativeG1G2DiffusionV1/native_process_table_r23_v1.py"
native_table = sys.modules.get("native_process_table_r23_v1")
if native_table is None:
    TABLE_SPEC = importlib.util.spec_from_file_location("native_process_table_r23_v1", TABLE_HELPER_PATH)
    if TABLE_SPEC is None or TABLE_SPEC.loader is None:
        raise RuntimeError("R23 native process-table helper cannot be loaded")
    native_table = importlib.util.module_from_spec(TABLE_SPEC)
    sys.modules[TABLE_SPEC.name] = native_table
    TABLE_SPEC.loader.exec_module(native_table)

SCHEMA = "native-g1g2-r16-root-audit-r23-v1"
SAMPLE_SCHEMA = "native-g1g2-r23-process-tree-sample-v1"
RESOURCE_MEASUREMENT_SCHEMA = "fca-managed-resource-measurement-v1"
RESOURCE_SOURCE_TAGS = [
    "GetProcessMemoryInfo", "GetProcessTimes",
    "NtQueryInformationProcess.ProcessCommandLineInformation",
]
MANAGED_ACK_SCHEMA = "fca-managed-process-ack-v1"
MANAGED_ACK_PUBLICATION_SCHEMA = "fca-managed-ack-publication-v1"
RSS_THRESHOLD_BYTES = 2_147_483_648
SAMPLE_INTERVAL_SECONDS = 0.2
STAGE_WALL_SECONDS = 480.0
JULIA_HEAP_SIZE_HINT = "1G"
JULIA_COMPILER_MODE = "--compile=min"
STAGES = ("parse_all", "primary", "fresh_replay")
HEAVY_NAMES = frozenset({"julia.exe", "julia", "desc.exe", "desc", "mesh.exe", "mesh"})
NO_NUMERICAL_CREDIT = {
    "numerical_status": "not_established",
    "numerical_credit": False,
    "physical_status": "unknown",
    "solver_success_claimed": False,
}


class MonitorIncomplete(RuntimeError):
    """An authoritative inventory, exact identity, or resource read failed."""


def _identity(value: Any) -> tuple[int, int]:
    return native_table.validate_identity(value)


def _finite_nonnegative(value: Any, field: str) -> float:
    if type(value) not in (int, float) or isinstance(value, bool):
        raise MonitorIncomplete(f"{field} must be a native finite nonnegative number")
    converted = float(value)
    if not math.isfinite(converted) or converted < 0:
        raise MonitorIncomplete(f"{field} must be a native finite nonnegative number")
    return converted


def _rss_bytes(value: Any) -> int:
    if type(value) is not int or value < 0:
        raise MonitorIncomplete("RSS must be a native nonnegative integer byte count")
    return value


def _table_row_identity(row: Any) -> tuple[int, int]:
    if not isinstance(row, native_table.ProcessRow):
        raise MonitorIncomplete("process table row is untyped")
    return _identity((row.identity.pid, row.identity.create_time_100ns))


class ExactHandleRegistry:
    """Own registered birth handles and retain original root handles by raw identity.

    The permissive PID-open adapter is retained only for the historical
    non-managed path. A lifecycle-backed consumer must set
    ``strict_registered_births=True``: a missed DEBUG_CREATE registration is a
    hard incomplete result, never a snapshot-PID OpenProcess recovery.
    """

    def __init__(
        self,
        *,
        opener: Callable[[native_table.ProcessRow], Any] = native_table.open_exact_process_handle,
        identity_reader: Callable[[Any], tuple[int, int]] = native_table.read_process_handle_identity,
        closer: Callable[[Any], None] = native_table.close_process_handle,
        strict_registered_births: bool = False,
        phase_root: Path | None = None,
    ) -> None:
        self._opener = opener
        self._identity_reader = identity_reader
        self._closer = closer
        self._strict_registered_births = strict_registered_births
        self._phase_root = Path(phase_root).resolve() if phase_root is not None else None
        self._managed_session_id: str | None = None
        self._managed_scope_sha256: str | None = None
        self._managed_monitor_identity: tuple[int, int] | None = None
        self._handles: dict[tuple[int, int], Any] = {}
        self._owned: set[tuple[int, int]] = set()
        self._birth_records: dict[tuple[int, int], Any] = {}
        self._birth_event_receipts: dict[tuple[int, int], dict[str, Any]] = {}
        self._registration_sequences: dict[tuple[int, int], int] = {}
        self._ack_publications: dict[tuple[int, int], Any] = {}

    @property
    def identities(self) -> tuple[tuple[int, int], ...]:
        return tuple(sorted(self._handles))

    @property
    def phase_root(self) -> Path:
        if self._phase_root is None:
            raise MonitorIncomplete("managed registry lacks its owned phase root")
        return self._phase_root

    def bind_managed_context(self, managed: Any) -> None:
        """Bind registry authority to the core-validated one-phase environment."""
        if self._birth_records or self._registration_sequences:
            raise MonitorIncomplete("managed context cannot change after a birth was registered")
        try:
            session_id = managed.session_id
            scope_sha256 = managed.scope_sha256
            monitor = _identity((managed.monitor_identity.pid,
                                 managed.monitor_identity.creation_time_100ns))
            phase_root = Path(managed.ack_directory)
        except Exception as exc:
            raise MonitorIncomplete("core managed context is malformed") from exc
        if type(session_id) is not str or len(session_id) != 64 or \
                any(ch not in "0123456789abcdef" for ch in session_id) or \
                type(scope_sha256) is not str or len(scope_sha256) != 64 or \
                any(ch not in "0123456789abcdef" for ch in scope_sha256):
            raise MonitorIncomplete("core managed session/scope is malformed")
        if not phase_root.is_absolute():
            raise MonitorIncomplete("managed ACK phase root must be absolute")
        try:
            phase_root = phase_root.resolve(strict=True)
            if not phase_root.is_dir():
                raise MonitorIncomplete("managed ACK phase root is not a directory")
        except MonitorIncomplete:
            raise
        except Exception as exc:
            raise MonitorIncomplete("managed ACK phase root cannot be resolved") from exc
        if self._phase_root is not None and self._phase_root != phase_root:
            raise MonitorIncomplete("registry phase root differs from core ACK directory")
        self._phase_root = phase_root
        self._managed_session_id = session_id
        self._managed_scope_sha256 = scope_sha256
        self._managed_monitor_identity = monitor

    def bind_popen(self, popen: Any, snapshot: Any) -> tuple[int, int]:
        identity = bind_popen_generation(
            popen, snapshot, handle_identity_reader=self._identity_reader,
        )
        existing = self._handles.get(identity)
        if existing is not None and existing is not getattr(popen, "_handle", None):
            raise MonitorIncomplete("duplicate handle binding for one raw process identity")
        self._handles[identity] = getattr(popen, "_handle")
        return identity

    def handle_for(self, identity: Any) -> Any:
        """Return only a cached exact-generation handle; never open by PID."""
        if hasattr(identity, "pid") and hasattr(identity, "creation_time_100ns"):
            pair = _identity((identity.pid, identity.creation_time_100ns))
        else:
            pair = _identity(identity)
        handle = self._handles.get(pair)
        if handle is None:
            raise MonitorIncomplete("managed generation has no acknowledged retained handle")
        native_table.require_same_identity(self._identity_reader(handle), pair,
                                           phase="registry exact retained handle")
        return handle

    def birth_event_receipt(self, identity: Any) -> dict[str, Any]:
        """Return the sealed create-event context used by exact-handle sampling."""
        if hasattr(identity, "pid") and hasattr(identity, "creation_time_100ns"):
            pair = _identity((identity.pid, identity.creation_time_100ns))
        else:
            pair = _identity(identity)
        receipt = self._birth_event_receipts.get(pair)
        if receipt is None:
            raise MonitorIncomplete("resource sample has no registered birth-event receipt")
        return dict(receipt)

    def register_birth(self, record: Any, *, ack_type: Any,
                       ack_publisher: Callable[[Mapping[str, Any]], Any]) -> Any:
        """Validate a pending debug birth, publish the exact 16-key ACK, then adopt.

        Core retains ownership until this returns. Publication/validation errors
        therefore leave the pending debug event held and let core close its
        duplicate exactly once.
        """
        try:
            identity_obj = record.identity
            parent_obj = record.parent_identity
            monitor_obj = record.monitor_identity
            identity = _identity((identity_obj.pid, identity_obj.creation_time_100ns))
            parent = _identity((parent_obj.pid, parent_obj.creation_time_100ns))
            monitor = _identity((monitor_obj.pid, monitor_obj.creation_time_100ns))
            event_pid = record.event_pid
            handle = record.retained_handle
            sequence = record.registration_sequence
            session_id = record.session_id
            scope_sha256 = record.scope_sha256
            source_row = record.source_row
            source_snapshot = native_table.validate_snapshot(record.source_snapshot)
            source_receipt = record.source_snapshot_receipt
            measurement = record.creation_measurement
        except Exception as exc:
            raise MonitorIncomplete("managed birth record is malformed") from exc

        if type(handle) is not int or handle <= 0:
            raise MonitorIncomplete("managed birth handle must be an exact positive raw integer")
        if type(event_pid) is not int or event_pid != identity[0]:
            raise MonitorIncomplete("debug CREATE PID differs from the retained-handle generation")
        if identity in self._handles or identity in self._birth_records:
            raise MonitorIncomplete("duplicate managed birth identity")
        if type(sequence) is not int or sequence <= 0 or \
                sequence != len(self._registration_sequences) + 1:
            raise MonitorIncomplete("managed registration sequence is not unique and contiguous")
        if type(session_id) is not str or len(session_id) != 64 or \
                any(ch not in "0123456789abcdef" for ch in session_id):
            raise MonitorIncomplete("managed session id is malformed")
        if type(scope_sha256) is not str or len(scope_sha256) != 64 or \
                any(ch not in "0123456789abcdef" for ch in scope_sha256):
            raise MonitorIncomplete("managed scope digest is malformed")
        if self._managed_session_id is None or self._managed_scope_sha256 is None or \
                self._managed_monitor_identity is None or self._phase_root is None:
            raise MonitorIncomplete("registry has not been bound to the core managed context")
        if session_id != self._managed_session_id or scope_sha256 != self._managed_scope_sha256 or \
                monitor != self._managed_monitor_identity:
            raise MonitorIncomplete("birth session/scope/monitor differs from core managed context")
        if record.job_bound is not True:
            raise MonitorIncomplete("managed birth is not proven inside the configured Job")
        row_identity = _table_row_identity(source_row)
        if row_identity != identity or source_row.ppid != parent[0]:
            raise MonitorIncomplete("managed birth row does not bind exact identity and parent PID")
        source_table_row = source_snapshot.by_pid.get(identity[0])
        if source_table_row is None or _table_row_identity(source_table_row) != identity or \
                source_table_row.ppid != parent[0] or source_table_row.name != source_row.name:
            raise MonitorIncomplete("phase source snapshot does not bind the exact CREATE row")
        if not isinstance(source_receipt, Mapping) or source_receipt.get("complete") is not True or \
                source_receipt.get("phase") != "managed_create" or \
                type(source_receipt.get("sequence")) is not int or source_receipt["sequence"] < 0 or \
                source_receipt.get("row_identity") != {
                    "pid": identity[0], "create_time_100ns": identity[1]} or \
                source_receipt.get("row_ppid") != source_row.ppid or \
                source_receipt.get("row_name") != source_row.name:
            raise MonitorIncomplete("managed birth lacks its exact phase-history source witness")
        native_table.require_same_identity(self._identity_reader(handle), identity,
                                           phase="registry CREATE adoption")
        _validate_managed_measurement(measurement, identity, phase="create")
        expected_event_sequence = measurement.get("event_sequence")
        if source_receipt.get("event_sequence") != expected_event_sequence:
            raise MonitorIncomplete("CREATE source witness and creation measurement sequence differ")
        if parent != monitor and parent not in self._handles:
            raise MonitorIncomplete("managed birth parent generation is not registered")
        if parent != monitor:
            self.handle_for(parent)

        payload = {
            "schema": MANAGED_ACK_SCHEMA,
            "session_id": session_id,
            "scope_sha256": scope_sha256,
            "child_pid": identity[0],
            "child_creation_time_100ns": identity[1],
            "parent_pid": parent[0],
            "parent_creation_time_100ns": parent[1],
            "monitor_pid": monitor[0],
            "monitor_creation_time_100ns": monitor[1],
            "registration_sequence": sequence,
            "handle_duplicated": True,
            "identity_registered": True,
            "job_bound": True,
            "creation_sample_measured": True,
            "resume_permitted": True,
            "full_run_resource_complete": False,
        }
        try:
            from_mapping = getattr(ack_type, "from_mapping", None)
            if not callable(from_mapping):
                raise MonitorIncomplete("core ACK type lacks the frozen from_mapping validator")
            ack = from_mapping(payload)
            if type(ack) is not ack_type or ack.wire() != payload:
                raise MonitorIncomplete("core ACK type does not round-trip the exact 16-key contract")
            publication = ack_publisher(payload)
            _validate_ack_publication(publication, identity, payload, self._phase_root)
        except Exception as exc:
            if isinstance(exc, MonitorIncomplete):
                raise
            raise MonitorIncomplete("managed birth ACK publication failed") from exc

        # Transfer ownership only after the exact ACK is durable and verified.
        self._handles[identity] = handle
        self._owned.add(identity)
        self._birth_records[identity] = record
        self._registration_sequences[identity] = sequence
        self._ack_publications[identity] = publication
        self._birth_event_receipts[identity] = {
            "schema": "fca-managed-birth-resource-context-v1",
            "complete": True,
            "identity": {"pid": identity[0], "create_time_100ns": identity[1]},
            "parent_identity": {"pid": parent[0], "create_time_100ns": parent[1]},
            "session_id": session_id,
            "scope_sha256": scope_sha256,
            "registration_sequence": sequence,
            "event_sequence": expected_event_sequence,
            "source_snapshot_sequence": source_receipt["sequence"],
            "creation_measurement": dict(measurement),
            "ack": payload,
            "ack_publication": _publication_mapping(publication),
        }
        return ack

    def unregister_and_close_birth(self, identity: Any, *, sequence: int) -> Mapping[str, Any]:
        if hasattr(identity, "pid") and hasattr(identity, "creation_time_100ns"):
            pair = _identity((identity.pid, identity.creation_time_100ns))
        else:
            pair = _identity(identity)
        if type(sequence) is not int or self._registration_sequences.get(pair) != sequence:
            raise MonitorIncomplete("managed close sequence does not match the registered generation")
        handle = self._handles.get(pair)
        if handle is None or pair not in self._owned:
            raise MonitorIncomplete("managed close has no registry-owned exact handle")
        native_table.require_same_identity(self._identity_reader(handle), pair,
                                           phase="registry close exact identity")
        if not native_table.wait_for_process_exit(handle, 0):
            raise MonitorIncomplete("managed retained process handle is not signaled at close")
        self._closer(handle)
        self._owned.remove(pair)
        self._handles.pop(pair, None)
        return {"schema": "fca-managed-registry-close-r1", "complete": True,
                "identity": {"pid": pair[0], "create_time_100ns": pair[1]},
                "registration_sequence": sequence, "handle_closed": True}

    def for_row(self, row: native_table.ProcessRow, snapshot: Any) -> Any:
        identity = _table_row_identity(row)
        table = native_table.validate_snapshot(snapshot)
        observed_row = table.by_pid.get(identity[0])
        if observed_row is None:
            raise MonitorIncomplete("cannot open a process absent from current SPI snapshot")
        native_table.require_same_identity(_table_row_identity(observed_row), identity,
                                           phase="handle-registry row")
        handle = self._handles.get(identity)
        if handle is None:
            if self._strict_registered_births:
                raise MonitorIncomplete("managed SPI row lacks a registered DEBUG_CREATE generation")
            handle = self._opener(row)
            try:
                native_table.require_same_identity(self._identity_reader(handle), identity,
                                                   phase="handle-registry open")
            except Exception:
                self._closer(handle)
                raise
            self._handles[identity] = handle
            self._owned.add(identity)
        else:
            native_table.require_same_identity(self._identity_reader(handle), identity,
                                               phase="handle-registry cached handle")
        return handle

    def close_owned(self) -> dict[str, Any]:
        failures = []
        closed = []
        for identity in sorted(self._owned):
            handle = self._handles.get(identity)
            try:
                self._closer(handle)
                closed.append({"pid": identity[0], "create_time_100ns": identity[1]})
                self._owned.remove(identity)
                self._handles.pop(identity, None)
            except Exception as exc:
                failures.append({"pid": identity[0], "create_time_100ns": identity[1],
                                 "type": type(exc).__name__, "message": str(exc),
                                 "repr": repr(exc)})
        return {"schema": "native-g1g2-r23-handle-close-receipt-v1",
                "complete": not failures, "closed_owned_handles": closed,
                "errors": failures,
                "popen_handles_not_owned_by_registry": len(self._handles) - len(self._owned)}


def bind_popen_generation(
    popen: Any,
    snapshot: Any,
    *,
    handle_identity_reader: Callable[[Any], tuple[int, int]] = native_table.read_process_handle_identity,
) -> tuple[int, int]:
    """Bind the original Popen handle to the same exact row in an SPI snapshot."""
    try:
        table = native_table.validate_snapshot(snapshot)
        pid = getattr(popen, "pid", None)
        if type(pid) is not int or pid <= 0:
            raise MonitorIncomplete("Popen PID must be a positive native integer")
        handle = getattr(popen, "_handle", None)
        if handle is None:
            raise MonitorIncomplete("Popen original process handle is unavailable")
        actual = handle_identity_reader(handle)
        identity = _identity(actual)
        if identity[0] != pid:
            raise MonitorIncomplete("Popen PID does not match original process handle")
        row = table.by_pid.get(pid)
        if row is None:
            raise MonitorIncomplete("Popen process is absent from authoritative SPI snapshot")
        native_table.require_same_identity(_table_row_identity(row), identity,
                                           phase="Popen/table exact generation")
        return identity
    except MonitorIncomplete:
        raise
    except Exception as exc:
        raise MonitorIncomplete("Popen original handle generation read failed") from exc


def _validate_resource_row(raw: Any, row: native_table.ProcessRow) -> dict[str, Any]:
    if not isinstance(raw, Mapping):
        raise MonitorIncomplete("resource reader returned a non-mapping value")
    rss = _rss_bytes(raw.get("rss_bytes"))
    cpu_user = _finite_nonnegative(raw.get("cpu_user_seconds"), "CPU user seconds")
    cpu_system = _finite_nonnegative(raw.get("cpu_system_seconds"), "CPU system seconds")
    command = raw.get("cmdline")
    if type(command) not in (list, tuple) or any(type(part) is not str for part in command):
        raise MonitorIncomplete("process command line is absent or malformed")
    return {
        "pid": row.identity.pid,
        "create_time_100ns": row.identity.create_time_100ns,
        "create_time_seconds_display": native_table.display_seconds(row.identity.create_time_100ns),
        "ppid": row.ppid,
        "name": row.name,
        "cmdline": list(command),
        "rss_bytes": rss,
        "cpu_user_seconds": cpu_user,
        "cpu_system_seconds": cpu_system,
    }


def _validate_managed_measurement(value: Any, identity: tuple[int, int], *, phase: str,
                                  expected_event_sequence: int | None = None) -> dict[str, Any]:
    """Validate the core's exact-handle resource receipt without PID reopening."""
    required = {
        "schema", "phase", "identity", "handle_identity_before", "handle_identity_after",
        "event_sequence", "complete", "rss_bytes", "cpu_user_seconds", "cpu_system_seconds",
        "cmdline", "source_tags",
    }
    if not isinstance(value, Mapping) or set(value) != required:
        raise MonitorIncomplete("managed resource measurement keys differ from the frozen core schema")
    expected_identity = {"pid": identity[0], "creation_time_100ns": identity[1]}
    if value.get("schema") != RESOURCE_MEASUREMENT_SCHEMA or value.get("phase") != phase or \
            value.get("identity") != expected_identity or \
            value.get("handle_identity_before") != expected_identity or \
            value.get("handle_identity_after") != expected_identity:
        raise MonitorIncomplete("managed measurement does not bind its exact phase/handle generation")
    sequence = value.get("event_sequence")
    if type(sequence) is not int or sequence <= 0 or \
            (expected_event_sequence is not None and sequence != expected_event_sequence):
        raise MonitorIncomplete("managed measurement event sequence is absent or mismatched")
    if value.get("complete") is not True:
        raise MonitorIncomplete("managed exact-handle measurement is incomplete")
    _rss_bytes(value.get("rss_bytes"))
    _finite_nonnegative(value.get("cpu_user_seconds"), "CPU user seconds")
    _finite_nonnegative(value.get("cpu_system_seconds"), "CPU system seconds")
    command = value.get("cmdline")
    if type(command) is not list or any(type(part) is not str for part in command):
        raise MonitorIncomplete("managed exact-handle command line is malformed")
    if value.get("source_tags") != RESOURCE_SOURCE_TAGS:
        raise MonitorIncomplete("managed measurement source tags differ from exact-handle APIs")
    return dict(value)


def _publication_mapping(publication: Any) -> dict[str, Any]:
    if isinstance(publication, Mapping):
        return dict(publication)
    names = ("schema", "path", "filename", "bytes", "sha256", "exclusive", "flushed")
    try:
        return {name: getattr(publication, name) for name in names}
    except Exception as exc:
        raise MonitorIncomplete("ACK publication receipt is not typed or mapping-shaped") from exc


def _unique_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _validate_ack_publication(publication: Any, identity: tuple[int, int],
                              payload: Mapping[str, Any], phase_root: Path | None) -> dict[str, Any]:
    receipt = _publication_mapping(publication)
    expected_name = f"{identity[0]}_{identity[1]}.ack.json"
    expected_keys = {"schema", "path", "filename", "bytes", "sha256", "exclusive", "flushed"}
    if set(receipt) != expected_keys or receipt.get("schema") != MANAGED_ACK_PUBLICATION_SCHEMA or \
            receipt.get("filename") != expected_name or type(receipt.get("path")) is not str or \
            type(receipt.get("bytes")) is not int or receipt["bytes"] <= 0 or \
            type(receipt.get("sha256")) is not str or len(receipt["sha256"]) != 64 or \
            any(ch not in "0123456789abcdef" for ch in receipt["sha256"]) or \
            receipt.get("exclusive") is not True or receipt.get("flushed") is not True:
        raise MonitorIncomplete("ACK publication receipt differs from the exclusive 16-key contract")
    path = Path(receipt["path"])
    if not path.is_absolute() or path.name != expected_name:
        raise MonitorIncomplete("ACK publication path is not the expected absolute identity filename")
    try:
        resolved_parent = path.parent.resolve(strict=True)
        if phase_root is None or resolved_parent != phase_root or path.resolve(strict=True).parent != phase_root:
            raise MonitorIncomplete("ACK publication escaped its exclusive managed phase directory")
        raw = path.read_bytes()
    except MonitorIncomplete:
        raise
    except Exception as exc:
        raise MonitorIncomplete("ACK publication cannot be independently read back") from exc
    digest = hashlib.sha256(raw).hexdigest()
    if len(raw) != receipt["bytes"] or digest != receipt["sha256"]:
        raise MonitorIncomplete("ACK publication readback bytes/hash differ from its durable receipt")
    try:
        decoded = json.loads(raw.decode("utf-8"), object_pairs_hook=_unique_json_object)
    except Exception as exc:
        raise MonitorIncomplete("ACK publication is not unique-key UTF-8 JSON") from exc
    if decoded != dict(payload):
        raise MonitorIncomplete("ACK publication readback differs from the exact registry payload")
    return receipt


def _sample_boundary_mapping(boundary: Any) -> dict[str, Any] | None:
    if boundary is None:
        return None
    if isinstance(boundary, Mapping):
        return dict(boundary)
    try:
        attempt_id = boundary.attempt_id
        complete = boundary.complete
        membership_changed = boundary.membership_changed
        pending = boundary.pending_event_codes
        reason = boundary.reason
    except Exception as exc:
        return {"complete": False, "receipt_error": type(exc).__name__}
    if type(attempt_id) is not int or attempt_id <= 0 or type(complete) is not bool or \
            type(membership_changed) is not bool or type(pending) is not tuple or \
            any(type(code) is not int for code in pending) or \
            (reason is not None and type(reason) is not str):
        return {"complete": False, "receipt_error": "malformed_boundary_fields"}
    return {"attempt_id": attempt_id, "complete": complete,
            "membership_changed": membership_changed,
            "pending_event_codes": list(pending), "reason": reason}


def _released_event_summary(events: Any) -> dict[str, Any]:
    if type(events) not in (tuple, list):
        raise MonitorIncomplete("released debug-event collection is malformed")
    rows = []
    for event in events:
        try:
            code = event.code
            pid = event.process_id
            thread_id = event.thread_id
            exit_code = event.exit_code
        except Exception as exc:
            raise MonitorIncomplete("released debug-event receipt is untyped") from exc
        if type(code) is not int or code <= 0 or type(pid) is not int or pid <= 0 or \
                type(thread_id) is not int or thread_id <= 0 or \
                (exit_code is not None and type(exit_code) is not int):
            raise MonitorIncomplete("released debug-event receipt fields are malformed")
        rows.append({"event_code": code, "pid": pid, "thread_id": thread_id,
                     "exit_code": exit_code})
    return {"complete": True, "count": len(rows), "events": rows}


def _finish_lifecycle_sample_attempt(session: Any, attempt_id: int) -> dict[str, Any]:
    """End once, retain typed race evidence, then release only after discard."""
    try:
        boundary = session.end_sample_attempt(attempt_id)
        mapped = _sample_boundary_mapping(boundary)
    except Exception as exc:
        # The core contract returns a typed incomplete boundary rather than
        # raising when an event is held. An exception here is an unclassified
        # lifecycle failure; retain it and do not guess whether it is safe to
        # continue any debug event.
        return {"attempt_id": attempt_id, "complete": False,
                "membership_changed": True, "pending_event_codes": [],
                "reason": "end_sample_attempt_exception",
                "end_error": {"type": type(exc).__name__, "message": str(exc),
                              "repr": repr(exc)}}
    if mapped is None or mapped.get("attempt_id") != attempt_id:
        return {"attempt_id": attempt_id, "complete": False,
                "membership_changed": True, "pending_event_codes": [],
                "reason": "malformed_or_wrong_sample_boundary",
                "boundary_error": mapped}
    if mapped.get("complete") is not True or mapped.get("membership_changed") is not False or \
            mapped.get("pending_event_codes") != [] or mapped.get("reason") is not None:
        # The attempt has ended and its resource result is discarded before any
        # event is continued. Event release never creates another sample.
        try:
            released = session.release_boundary_events()
            mapped["released_boundary_events"] = _released_event_summary(released)
        except Exception as exc:
            mapped["release_error"] = {"type": type(exc).__name__, "message": str(exc),
                                       "repr": repr(exc)}
        return mapped
    return mapped


def sample_process_tree(
    root_identity: Any,
    *,
    snapshot_provider: Callable[[], native_table.ProcessTableSnapshot],
    handle_provider: Callable[[native_table.ProcessRow], Any],
    resource_reader: Callable[..., Mapping[str, Any]],
    handle_identity_reader: Callable[[Any], tuple[int, int]],
    previously_tracked: Iterable[Any] = (),
    sample_index: int = 1,
    elapsed_seconds: float | None = None,
    lifecycle_session: Any | None = None,
    lifecycle_identity_factory: Callable[[tuple[int, int]], Any] | None = None,
    lifecycle_attempt_callback: Callable[[int], None] | None = None,
) -> dict[str, Any]:
    """Sample a stable exact SPI tree; any read/churn gap makes the sample incomplete."""
    errors: list[dict[str, Any]] = []
    partial_rss = 0
    rows: list[dict[str, Any]] = []
    resource_measurement_receipts: list[dict[str, Any]] = []
    before_digest: tuple[tuple[int, int, int, str], ...] | None = None
    after_digest: tuple[tuple[int, int, int, str], ...] | None = None
    root: tuple[int, int] | None = None
    attempt_id: int | None = None
    attempt_boundary: Any | None = None
    boundary_open = False

    def query_snapshot() -> Any:
        if lifecycle_session is not None:
            checkpoint = lifecycle_session.sample_boundary_checkpoint(attempt_id)
            if getattr(checkpoint, "observed", None) is not False or \
                    getattr(checkpoint, "pending_event_codes", None) != ():
                raise MonitorIncomplete(
                    "debug event crossed the pre-query whole-sample boundary")
        snapshot = snapshot_provider()
        if lifecycle_session is not None:
            checkpoint = lifecycle_session.sample_boundary_checkpoint(attempt_id)
            if getattr(checkpoint, "observed", None) is not False or \
                    getattr(checkpoint, "pending_event_codes", None) != ():
                raise MonitorIncomplete(
                    "debug event crossed the post-query whole-sample boundary")
        return snapshot

    try:
        root = _identity(root_identity)
        if type(sample_index) is not int or sample_index < 1:
            raise MonitorIncomplete("sample index must be a positive native integer")
        if elapsed_seconds is not None:
            _finite_nonnegative(elapsed_seconds, "elapsed seconds")
        if lifecycle_session is not None:
            if lifecycle_identity_factory is None:
                raise MonitorIncomplete("lifecycle sample requires a typed core identity factory")
            attempt_id = lifecycle_session.begin_sample_attempt()
            if type(attempt_id) is not int or attempt_id <= 0:
                raise MonitorIncomplete("lifecycle returned a malformed whole-sample attempt id")
            if lifecycle_attempt_callback is not None:
                lifecycle_attempt_callback(attempt_id)
            boundary_open = True
        before = native_table.validate_snapshot(query_snapshot())
        before_digest = native_table.native_snapshot_digest(before)
        identities = native_table.descendant_identities(
            before, root, previously_tracked=previously_tracked,
        )
        before_rows = before.by_pid
        for identity_obj in identities:
            identity = (identity_obj.pid, identity_obj.create_time_100ns)
            row = before_rows[identity[0]]
            handle = handle_provider(row)
            native_table.require_handle_matches_table(
                handle, identity, before, handle_identity_reader=handle_identity_reader,
            )
            if lifecycle_session is None:
                raw_metrics = resource_reader(identity[0])
            else:
                event_receipt = {
                    "schema": "fca-managed-whole-sample-resource-context-v1",
                    "identity": {"pid": identity[0], "creation_time_100ns": identity[1]},
                    "sample_index": sample_index,
                    "attempt_id": attempt_id,
                    "event_sequence": attempt_id,
                }
                raw_managed = resource_reader(
                    handle, lifecycle_identity_factory(identity), row,
                    phase="whole_sample", event_receipt=event_receipt,
                )
                managed_keys = {"rss_bytes", "cpu_user_seconds", "cpu_system_seconds",
                                "cmdline", "measurement_receipt"}
                if not isinstance(raw_managed, Mapping) or set(raw_managed) != managed_keys:
                    raise MonitorIncomplete("lifecycle resource reader lacks separate metrics and receipt")
                measurement_receipt = _validate_managed_measurement(
                    raw_managed["measurement_receipt"], identity, phase="whole_sample",
                    expected_event_sequence=attempt_id,
                )
                if raw_managed["rss_bytes"] != measurement_receipt["rss_bytes"] or \
                        raw_managed["cpu_user_seconds"] != measurement_receipt["cpu_user_seconds"] or \
                        raw_managed["cpu_system_seconds"] != measurement_receipt["cpu_system_seconds"] or \
                        raw_managed["cmdline"] != measurement_receipt["cmdline"]:
                    raise MonitorIncomplete("legacy metric projection differs from exact resource receipt")
                resource_measurement_receipts.append(measurement_receipt)
                raw_metrics = raw_managed
            native_table.require_same_identity(
                handle_identity_reader(handle), identity, phase="sample-after-resource-read",
            )
            measured = _validate_resource_row(raw_metrics, row)
            rows.append(measured)
            partial_rss += measured["rss_bytes"]

        after = native_table.validate_snapshot(query_snapshot())
        after_digest = native_table.native_snapshot_digest(after)
        after_identities = native_table.descendant_identities(after, root,
            previously_tracked=identities)
        before_exact = {(item.pid, item.create_time_100ns) for item in identities}
        after_exact = {(item.pid, item.create_time_100ns) for item in after_identities}
        if before_exact != after_exact:
            raise MonitorIncomplete("process tree membership/generation changed during sample")
        after_rows = after.by_pid
        for measured in rows:
            pid = measured["pid"]
            original = before_rows[pid]
            current = after_rows.get(pid)
            if current is None or _table_row_identity(current) != _table_row_identity(original) or \
                    current.ppid != original.ppid or current.name != original.name:
                raise MonitorIncomplete("process row identity/name/parent changed during sample")
        if lifecycle_session is not None:
            attempt_boundary = _finish_lifecycle_sample_attempt(lifecycle_session, attempt_id)
            boundary_open = False
            if attempt_boundary.get("complete") is not True or \
                    attempt_boundary.get("membership_changed") is not False or \
                    attempt_boundary.get("pending_event_codes") != [] or \
                    attempt_boundary.get("reason") is not None:
                raise MonitorIncomplete("debug event crossed the whole-sample lifecycle boundary")
        if lifecycle_session is not None and len(resource_measurement_receipts) != len(rows):
            raise MonitorIncomplete("complete lifecycle sample lacks one exact resource receipt per process")
        return {
            "schema": SAMPLE_SCHEMA,
            "sample_index": sample_index,
            "elapsed_seconds": elapsed_seconds,
            "root_identity": {"pid": root[0], "create_time_100ns": root[1]},
            "complete": True,
            "processes": rows,
            "discovered_identities": [
                {"pid": item.pid, "create_time_100ns": item.create_time_100ns}
                for item in identities
            ],
            "measured_identities": [
                {"pid": row["pid"], "create_time_100ns": row["create_time_100ns"]}
                for row in rows
            ],
            "partial_rss_bytes": partial_rss,
            "credited_rss_bytes": partial_rss,
            "rss_bytes": partial_rss,
            "resource_measurement_receipts": resource_measurement_receipts,
            "sample_attempt_boundary": _sample_boundary_mapping(attempt_boundary),
            "native_snapshot_before_rows": len(before.rows),
            "native_snapshot_after_rows": len(after.rows),
            "native_snapshot_before_digest": before_digest,
            "native_snapshot_after_digest": after_digest,
            "identity_source": "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
            "errors": errors,
        }
    except Exception as exc:
        if lifecycle_session is not None and boundary_open:
            try:
                attempt_boundary = _finish_lifecycle_sample_attempt(lifecycle_session, attempt_id)
                boundary_open = False
            except Exception as boundary_exc:
                boundary_open = False
                errors.append({"phase": "sample_attempt_boundary", "type": type(boundary_exc).__name__,
                               "message": str(boundary_exc), "repr": repr(boundary_exc)})
        errors.append({"phase": "sample_process_tree", "type": type(exc).__name__,
                       "message": str(exc), "repr": repr(exc)})
        return {
            "schema": SAMPLE_SCHEMA,
            "sample_index": sample_index if type(sample_index) is int else None,
            "elapsed_seconds": elapsed_seconds,
            "root_identity": ({"pid": root[0], "create_time_100ns": root[1]}
                              if root is not None else None),
            "complete": False,
            "processes": rows,
            "discovered_identities": [],
            "measured_identities": [
                {"pid": row["pid"], "create_time_100ns": row["create_time_100ns"]}
                for row in rows
            ],
            "partial_rss_bytes": partial_rss,
            "credited_rss_bytes": 0,
            "rss_bytes": None,
            "resource_measurement_receipts": resource_measurement_receipts,
            "sample_attempt_boundary": _sample_boundary_mapping(attempt_boundary),
            "native_snapshot_before_rows": None,
            "native_snapshot_after_rows": None,
            "native_snapshot_before_digest": before_digest,
            "native_snapshot_after_digest": after_digest,
            "identity_source": "build_pinned_spi_raw_create_time_100ns_plus_exact_process_handle",
            "errors": errors,
            **NO_NUMERICAL_CREDIT,
        }


def global_heavy_processes(snapshot: Any) -> tuple[tuple[int, int], ...]:
    """Classify the global heavy-process inventory from authoritative SPI names."""
    table = native_table.validate_snapshot(snapshot)
    found = []
    for row in table.rows:
        if row.name.casefold() in HEAVY_NAMES:
            found.append(_table_row_identity(row))
    return tuple(sorted(found))


def signal_exact_process(
    handle: Any,
    expected_identity: Any,
    *,
    snapshot_provider: Callable[[], native_table.ProcessTableSnapshot],
    handle_identity_reader: Callable[[Any], tuple[int, int]],
    signal_sender: Callable[[Any], Any],
    wait_for_exit: Callable[[Any, float], Any],
    exit_code_reader: Callable[[Any], int],
    timeout_seconds: float = 10.0,
) -> dict[str, Any]:
    """Signal only after fresh SPI+handle equality; verify same handle after wait."""
    expected = _identity(expected_identity)
    if type(timeout_seconds) not in (int, float) or isinstance(timeout_seconds, bool) or \
            not math.isfinite(float(timeout_seconds)) or timeout_seconds <= 0:
        raise MonitorIncomplete("wait timeout must be a positive finite number")
    signalled = False
    try:
        before = native_table.validate_snapshot(snapshot_provider())
        row = before.by_pid.get(expected[0])
        if row is None:
            raise MonitorIncomplete("target row missing before signal")
        native_table.require_handle_matches_table(
            handle, expected, before, handle_identity_reader=handle_identity_reader,
        )
        # Repeat immediately before the signal; no float identities participate.
        immediate = native_table.validate_snapshot(snapshot_provider())
        immediate_row = immediate.by_pid.get(expected[0])
        if immediate_row is None:
            raise MonitorIncomplete("target row missing at signal boundary")
        native_table.require_same_identity(_table_row_identity(immediate_row), expected,
                                           phase="signal-boundary table")
        native_table.require_same_identity(handle_identity_reader(handle), expected,
                                           phase="signal-boundary handle")
        signal_sender(handle)
        signalled = True
        waited = wait_for_exit(handle, float(timeout_seconds))
        if waited is not True:
            raise MonitorIncomplete("native wait did not confirm process exit")
        native_table.require_same_identity(handle_identity_reader(handle), expected,
                                           phase="post-wait original handle")
        code = exit_code_reader(handle)
        if type(code) is not int or code == 259:  # STILL_ACTIVE
            raise MonitorIncomplete("native exit code is malformed or process remains active")
        after = native_table.validate_snapshot(snapshot_provider())
        residual = after.by_pid.get(expected[0])
        if residual is not None and _table_row_identity(residual) == expected:
            raise MonitorIncomplete("target exact generation remains in final table")
        return {
            "schema": "native-g1g2-r23-exit-receipt-v1",
            "identity": {"pid": expected[0], "create_time_100ns": expected[1]},
            "signal_sent": True,
            "wait_confirmed": True,
            "exit_code": code,
            "post_table_same_generation_present": False,
            "post_table_reused_pid_ticks": (
                residual.identity.create_time_100ns if residual is not None else None
            ),
            "complete": True,
        }
    except Exception as exc:
        return {
            "schema": "native-g1g2-r23-exit-receipt-v1",
            "identity": {"pid": expected[0], "create_time_100ns": expected[1]},
            "signal_sent": signalled,
            "wait_confirmed": False,
            "exit_code": None,
            "complete": False,
            "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)},
            **NO_NUMERICAL_CREDIT,
        }


def wait_exact_process(
    handle: Any,
    expected_identity: Any,
    *,
    snapshot_provider: Callable[[], native_table.ProcessTableSnapshot],
    handle_identity_reader: Callable[[Any], tuple[int, int]],
    wait_for_exit: Callable[[Any, float], Any],
    exit_code_reader: Callable[[Any], int],
    timeout_seconds: float = 10.0,
) -> dict[str, Any]:
    """Record a natural exit on the exact handle and reconcile its table row."""
    expected = _identity(expected_identity)
    if type(timeout_seconds) not in (int, float) or isinstance(timeout_seconds, bool) or \
            not math.isfinite(float(timeout_seconds)) or timeout_seconds <= 0:
        raise MonitorIncomplete("wait timeout must be a positive finite number")
    try:
        before = native_table.validate_snapshot(snapshot_provider())
        row = before.by_pid.get(expected[0])
        if row is None:
            raise MonitorIncomplete("target row missing before wait")
        native_table.require_handle_matches_table(
            handle, expected, before, handle_identity_reader=handle_identity_reader,
        )
        waited = wait_for_exit(handle, float(timeout_seconds))
        if waited is not True:
            raise MonitorIncomplete("native wait did not confirm process exit")
        native_table.require_same_identity(handle_identity_reader(handle), expected,
                                           phase="post-wait original handle")
        code = exit_code_reader(handle)
        if type(code) is not int or code == 259:
            raise MonitorIncomplete("native exit code is malformed or process remains active")
        after = native_table.validate_snapshot(snapshot_provider())
        residual = after.by_pid.get(expected[0])
        if residual is not None and _table_row_identity(residual) == expected:
            raise MonitorIncomplete("target exact generation remains in final table")
        return {
            "schema": "native-g1g2-r23-exit-receipt-v1",
            "identity": {"pid": expected[0], "create_time_100ns": expected[1]},
            "signal_sent": False,
            "wait_confirmed": True,
            "exit_code": code,
            "post_table_same_generation_present": False,
            "post_table_reused_pid_ticks": (
                residual.identity.create_time_100ns if residual is not None else None
            ),
            "complete": True,
        }
    except Exception as exc:
        return {
            "schema": "native-g1g2-r23-exit-receipt-v1",
            "identity": {"pid": expected[0], "create_time_100ns": expected[1]},
            "signal_sent": False,
            "wait_confirmed": False,
            "exit_code": None,
            "complete": False,
            "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)},
            **NO_NUMERICAL_CREDIT,
        }


def audit_residual_identities(
    tracked: Iterable[Any], snapshot: Any,
) -> dict[str, Any]:
    """Check exact tracked generations are absent after stage control/wait."""
    try:
        table = native_table.validate_snapshot(snapshot)
        expected = tuple(sorted({_identity(value) for value in tracked}))
        residual = []
        for pid, ticks in expected:
            row = table.by_pid.get(pid)
            if row is not None and _table_row_identity(row) == (pid, ticks):
                residual.append({"pid": pid, "create_time_100ns": ticks})
        return {
            "schema": "native-g1g2-r23-residual-audit-v1",
            "complete": True,
            "expected_identity_count": len(expected),
            "residual_exact_identities": residual,
            "residual_clear": not residual,
            "row_count": len(table.rows),
            "host_identity": list(table.host_identity),
        }
    except Exception as exc:
        return {
            "schema": "native-g1g2-r23-residual-audit-v1",
            "complete": False,
            "residual_clear": False,
            "failure": {"type": type(exc).__name__, "message": str(exc), "repr": repr(exc)},
            **NO_NUMERICAL_CREDIT,
        }


def sampled_resource_disposition(samples: Iterable[Mapping[str, Any]]) -> dict[str, Any]:
    """Apply the unchanged sampled 2 GiB and 480 s stop contract."""
    sequence = list(samples)
    if not sequence:
        return {"disposition": "resource_monitor_incomplete", "complete": False,
                "reason": "no_samples", **NO_NUMERICAL_CREDIT}
    peak = 0
    peak_index = None
    for index, sample in enumerate(sequence, 1):
        if not isinstance(sample, Mapping) or sample.get("complete") is not True:
            return {"disposition": "resource_monitor_incomplete", "complete": False,
                    "reason": "incomplete_sample", **NO_NUMERICAL_CREDIT}
        rss = _rss_bytes(sample.get("rss_bytes"))
        elapsed = _finite_nonnegative(sample.get("elapsed_seconds"), "elapsed seconds")
        if rss > peak:
            peak, peak_index = rss, index
        if rss >= RSS_THRESHOLD_BYTES:
            return {"disposition": "resource_failure", "complete": True,
                    "reason": "sampled_rss_threshold_hit_or_overshoot",
                    "sampled_peak_rss_bytes": peak, "peak_sample_index": peak_index,
                    **NO_NUMERICAL_CREDIT}
        if elapsed >= STAGE_WALL_SECONDS:
            return {"disposition": "resource_failure", "complete": True,
                    "reason": "stage_wall_deadline",
                    "sampled_peak_rss_bytes": peak, "peak_sample_index": peak_index,
                    **NO_NUMERICAL_CREDIT}
    return {"disposition": "no_sampled_rss_threshold_crossing", "complete": True,
            "sampled_peak_rss_bytes": peak, "peak_sample_index": peak_index,
            "rss_threshold_bytes": RSS_THRESHOLD_BYTES,
            "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
            "wall_seconds_per_stage": STAGE_WALL_SECONDS,
            **NO_NUMERICAL_CREDIT}


def runtime_dispatch(*_: Any, **__: Any) -> None:
    raise RuntimeError("R23 runtime dispatch is disabled pending independent review and root grant")


def static_contract() -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "runtime_dispatch": "disabled_pending_independent_review_and_root_grant",
        "identity": "(native positive PID, exact raw FILETIME ticks); no float equality",
        "process_source": "build-pinned NtQuerySystemInformation(SystemProcessInformation), class 5",
        "host_pin": list(native_table.WINDOWS_BUILD_PIN),
        "stage_order": list(STAGES),
        "wall_seconds_per_stage": STAGE_WALL_SECONDS,
        "sampled_rss_stop_threshold_bytes": RSS_THRESHOLD_BYTES,
        "sample_interval_seconds": SAMPLE_INTERVAL_SECONDS,
        "julia_heap_size_hint": JULIA_HEAP_SIZE_HINT,
        "julia_compiler_mode": JULIA_COMPILER_MODE,
        "fixtures_and_solver_thresholds_unchanged": True,
        "no_numerical_credit": NO_NUMERICAL_CREDIT,
    }
