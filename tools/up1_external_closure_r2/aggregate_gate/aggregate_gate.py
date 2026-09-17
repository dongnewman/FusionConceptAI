"""UP1 external-closure R2 aggregate state machine.

The gate is deliberately a small, dependency-free boundary.  It consumes
versioned JSON only; it never imports Genome code and never publishes an AD or
any downstream authority.  A package is accepted only when all of its
component receipts agree on candidate/source/input fingerprints.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from contextlib import contextmanager
from collections import Counter
from pathlib import Path
from typing import Any, Mapping, Sequence

SCHEMA_VERSION = "UP1-EXTERNAL-CLOSURE-R2-AGGREGATE-V1"
LEDGER_SCHEMA_VERSION = "UP1-EXTERNAL-CLOSURE-R2-STATE-LEDGER-V1"
CODE_VERSION = "aggregate-gate-r2.2"
ORDERED_PHASES = ("intake", "aggregated", "terminal_deferred", "eligible_for_authority_recheck")
ORDERED_EVENTS = ("intake", "validated", "aggregate")
RESPONSIBILITY_SET = frozenset(("g1", "g2", "g3", "source_authority"))
_FINGERPRINT_RE = re.compile(r"^[0-9a-f]{64}$")
_ROOT_FIELDS = frozenset(("schema_version", "event", "sequence", "candidate_fingerprint", "source_fingerprint", "input_fingerprint", "fingerprints", "fingerprint_domains", "responsibility_packages", "authority_verified"))
_PACKAGE_FIELDS = frozenset(("responsibility", "package_id", "id", "name", "status", "candidate_fingerprint", "source_fingerprint", "input_fingerprint", "fingerprints", "fingerprint_domains", "receipts", "component_receipts", "components", "receipt", "authority_verified", "typed_absence", "absent", "invalid", "unsupported", "stale", "replayed", "replay", "conflict"))
_RECEIPT_FIELDS = frozenset(("receipt_id", "id", "component", "name", "status", "candidate_fingerprint", "source_fingerprint", "input_fingerprint", "fingerprints", "fingerprint_domains", "authority_verified", "typed_absence", "absent", "invalid", "unsupported", "stale", "replayed", "replay", "conflict"))
_FINGERPRINT_FIELDS = frozenset(("candidate", "source", "input", "candidate_fingerprint", "source_fingerprint", "input_fingerprint"))
ALLOWED_STATUSES = frozenset(
    {"verified", "typed_absence", "invalid", "unsupported", "stale", "replayed", "conflict"}
)
_TERMINAL_STATUSES = ALLOWED_STATUSES - {"verified"}
_CLAIM_CEILING = {
    "T0": False,
    "T1": False,
    "T2": False,
    "B00": False,
    "B04": False,
    "L4": 0,
    "parent": False,
}


class AggregateInputError(ValueError):
    """Raised for malformed versioned JSON input."""


def canonical_json(value: Any) -> str:
    """Return the canonical compact JSON representation (UTF-8, no LF)."""

    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _is_mapping(value: Any) -> bool:
    return isinstance(value, Mapping)


def _nonempty_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _valid_fingerprint(value: Any) -> bool:
    return isinstance(value, str) and _FINGERPRINT_RE.fullmatch(value) is not None


def _reject_unknown(obj: Mapping[str, Any], allowed: frozenset[str], path: str) -> None:
    unknown = sorted(set(obj) - allowed)
    if unknown:
        raise AggregateInputError(f"unknown field(s) at {path}: {','.join(unknown)}")


def _validate_fingerprint_object(value: Any, path: str) -> None:
    if not isinstance(value, Mapping):
        raise AggregateInputError(f"fingerprints must be an object at {path}")
    _reject_unknown(value, _FINGERPRINT_FIELDS, path)


def _validate_domains(obj: Mapping[str, Any], path: str) -> None:
    domains = obj.get("fingerprint_domains")
    if domains is None:
        return
    if not isinstance(domains, Mapping):
        raise AggregateInputError(f"fingerprint_domains must be an object at {path}")
    expected = {"candidate": "candidate", "source": "source", "input": "input"}
    if domains != expected:
        raise AggregateInputError(f"fingerprint domain labels mismatch at {path}")


def _first(obj: Mapping[str, Any], *keys: str) -> Any:
    for key in keys:
        if key in obj:
            return obj[key]
    return None


def _fingerprints(obj: Mapping[str, Any]) -> dict[str, Any]:
    nested = obj.get("fingerprints")
    nested = nested if _is_mapping(nested) else {}
    return {
        "candidate": _first(obj, "candidate_fingerprint", "candidateFingerprint")
        if _first(obj, "candidate_fingerprint", "candidateFingerprint") is not None
        else _first(nested, "candidate", "candidate_fingerprint"),
        "source": _first(obj, "source_fingerprint", "sourceFingerprint")
        if _first(obj, "source_fingerprint", "sourceFingerprint") is not None
        else _first(nested, "source", "source_fingerprint"),
        "input": _first(obj, "input_fingerprint", "inputFingerprint")
        if _first(obj, "input_fingerprint", "inputFingerprint") is not None
        else _first(nested, "input", "input_fingerprint"),
    }


def _status(obj: Mapping[str, Any]) -> str | None:
    raw = obj.get("status")
    if not isinstance(raw, str):
        return None
    return raw.strip().lower()


def _marker_status(obj: Mapping[str, Any]) -> str | None:
    explicit = _status(obj)
    if explicit is not None:
        return explicit
    if obj.get("conflict") is True:
        return "conflict"
    if obj.get("replayed") is True or obj.get("replay") is True:
        return "replayed"
    if obj.get("stale") is True or obj.get("fresh") is False or obj.get("freshness") == "stale":
        return "stale"
    if obj.get("unsupported") is True:
        return "unsupported"
    if obj.get("typed_absence") is True or obj.get("absent") is True:
        return "typed_absence"
    return None


def _package_items(document: Mapping[str, Any]) -> list[tuple[str, Mapping[str, Any]]]:
    _reject_unknown(document, _ROOT_FIELDS, "")
    _validate_domains(document, "")
    if "fingerprints" in document:
        _validate_fingerprint_object(document["fingerprints"], "/fingerprints")
    raw = _first(document, "responsibility_packages", "packages", "responsibilities")
    if _is_mapping(raw):
        items = []
        for name, package in raw.items():
            if not isinstance(name, str) or not isinstance(package, Mapping):
                raise AggregateInputError("responsibility_packages must map names to objects")
            _reject_unknown(package, _PACKAGE_FIELDS, f"/responsibility_packages/{name}")
            _validate_domains(package, f"/responsibility_packages/{name}")
            if "fingerprints" in package:
                _validate_fingerprint_object(package["fingerprints"], f"/responsibility_packages/{name}/fingerprints")
            items.append((name, package))
        return sorted(items, key=lambda item: item[0])
    if isinstance(raw, list):
        items = []
        for package in raw:
            if not isinstance(package, Mapping):
                raise AggregateInputError("each responsibility package must be an object")
            name = _first(package, "responsibility", "package_id", "id", "name")
            if not _nonempty_text(name):
                raise AggregateInputError("each responsibility package needs a non-empty id")
            _reject_unknown(package, _PACKAGE_FIELDS, f"/responsibility_packages/{name}")
            _validate_domains(package, f"/responsibility_packages/{name}")
            if "fingerprints" in package:
                _validate_fingerprint_object(package["fingerprints"], f"/responsibility_packages/{name}/fingerprints")
            items.append((name, package))
        return sorted(items, key=lambda item: item[0])
    raise AggregateInputError("missing responsibility_packages")


def _receipt_items(package: Mapping[str, Any]) -> list[tuple[str, Mapping[str, Any]]]:
    raw = _first(package, "receipts", "component_receipts", "components")
    if raw is None and "receipt" in package:
        raw = package["receipt"]
    if _is_mapping(raw):
        # A single receipt object has status/fingerprint fields; a mapping of
        # component ids has object values and no receipt status of its own.
        if _status(raw) is not None or any(k in raw for k in ("candidate_fingerprint", "fingerprints", "receipt_id")):
            rid = _first(raw, "receipt_id", "id", "component", "name") or "receipt"
            _reject_unknown(raw, _RECEIPT_FIELDS, f"/receipts/{rid}")
            _validate_domains(raw, f"/receipts/{rid}")
            if "fingerprints" in raw:
                _validate_fingerprint_object(raw["fingerprints"], f"/receipts/{rid}/fingerprints")
            return [(str(rid), raw)]
        items = []
        for rid, receipt in raw.items():
            if not isinstance(receipt, Mapping):
                raise AggregateInputError("component receipt must be an object")
            _reject_unknown(receipt, _RECEIPT_FIELDS, f"/receipts/{rid}")
            _validate_domains(receipt, f"/receipts/{rid}")
            if "fingerprints" in receipt:
                _validate_fingerprint_object(receipt["fingerprints"], f"/receipts/{rid}/fingerprints")
            items.append((str(rid), receipt))
        return sorted(items, key=lambda item: item[0])
    if isinstance(raw, list):
        items = []
        for index, receipt in enumerate(raw):
            if not isinstance(receipt, Mapping):
                raise AggregateInputError("component receipt must be an object")
            rid = _first(receipt, "receipt_id", "id", "component", "name") or f"receipt-{index + 1}"
            _reject_unknown(receipt, _RECEIPT_FIELDS, f"/receipts/{rid}")
            _validate_domains(receipt, f"/receipts/{rid}")
            if "fingerprints" in receipt:
                _validate_fingerprint_object(receipt["fingerprints"], f"/receipts/{rid}/fingerprints")
            items.append((str(rid), receipt))
        return sorted(items, key=lambda item: item[0])
    raise AggregateInputError("each responsibility package needs receipts")


def _input_fingerprints(document: Mapping[str, Any], package: Mapping[str, Any], receipt: Mapping[str, Any]) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    return _fingerprints(document), _fingerprints(package), _fingerprints(receipt)


def _compare_fingerprints(document: Mapping[str, Any], package: Mapping[str, Any], receipt: Mapping[str, Any], path: str, reasons: list[dict[str, Any]]) -> None:
    root, pkg, rec = _input_fingerprints(document, package, receipt)
    for kind in ("candidate", "source", "input"):
        expected = root[kind]
        if not _nonempty_text(expected):
            reasons.append({"code": "missing_fingerprint", "path": f"/{kind}_fingerprint"})
            continue
        if not _valid_fingerprint(expected):
            reasons.append({"code": "invalid_fingerprint", "path": f"/{kind}_fingerprint"})
            continue
        for label, values in (("package", pkg), ("receipt", rec)):
            value = values[kind]
            if not _nonempty_text(value):
                reasons.append({"code": "missing_fingerprint", "path": f"{path}/{label}/{kind}_fingerprint"})
            elif not _valid_fingerprint(value):
                reasons.append({"code": "invalid_fingerprint", "path": f"{path}/{label}/{kind}_fingerprint"})
            elif value != expected:
                reasons.append({"code": "fingerprint_mismatch", "path": f"{path}/{label}/{kind}_fingerprint", "expected": expected, "actual": value})


def _derive_package(document: Mapping[str, Any], name: str, package: Mapping[str, Any], seen_receipts: set[str]) -> dict[str, Any]:
    reasons: list[dict[str, Any]] = []
    package_path = f"/responsibility_packages/{name}"
    declared = _marker_status(package)
    if declared not in (None, *ALLOWED_STATUSES):
        reasons.append({"code": "unknown_status", "path": f"{package_path}/status", "actual": declared})
        declared = "invalid"
    try:
        receipts = _receipt_items(package)
    except AggregateInputError as exc:
        missing = "needs receipts" in str(exc)
        return {"responsibility": name, "status": "typed_absence" if missing else "invalid", "receipt_count": 0, "receipts": [], "reasons": [{"code": "missing_receipts" if missing else "malformed_receipts", "detail": str(exc)}]}
    if not receipts:
        reasons.append({"code": "missing_receipts", "path": package_path})
    normalized_receipts: list[dict[str, Any]] = []
    statuses: list[str] = []
    for rid, receipt in receipts:
        receipt_path = f"{package_path}/receipts/{rid}"
        status = _marker_status(receipt)
        if "authority_verified" in receipt and not isinstance(receipt["authority_verified"], bool):
            reasons.append({"code": "invalid_authority_verified", "path": f"{receipt_path}/authority_verified"})
            status = "invalid"
        elif receipt.get("authority_verified") is False:
            reasons.append({"code": "authority_not_verified", "path": f"{receipt_path}/authority_verified"})
            status = "typed_absence"
        if status not in (None, *ALLOWED_STATUSES):
            reasons.append({"code": "unknown_status", "path": f"{receipt_path}/status", "actual": status})
            status = "invalid"
        if status is None:
            status = "typed_absence"
            reasons.append({"code": "missing_status", "path": f"{receipt_path}/status"})
        receipt_key = f"{name}:{rid}"
        if receipt_key in seen_receipts:
            reasons.append({"code": "duplicate_receipt", "path": receipt_path, "receipt_id": rid})
        seen_receipts.add(receipt_key)
        _compare_fingerprints(document, package, receipt, receipt_path, reasons)
        statuses.append(status)
        normalized_receipts.append({"receipt_id": rid, "status": status})
    if len(set(statuses)) > 1:
        reasons.append({"code": "receipt_status_conflict", "statuses": sorted(set(statuses))})
    derived = "verified" if statuses and all(item == "verified" for item in statuses) else (Counter(statuses).most_common(1)[0][0] if statuses else "invalid")
    if declared is not None and declared != derived:
        reasons.append({"code": "package_status_conflict", "declared": declared, "derived": derived})
    if "authority_verified" in package and not isinstance(package["authority_verified"], bool):
        reasons.append({"code": "invalid_authority_verified", "path": f"{package_path}/authority_verified"})
        derived = "invalid"
    elif package.get("authority_verified") is False:
        reasons.append({"code": "authority_not_verified", "path": f"{package_path}/authority_verified"})
        derived = "typed_absence"
    if reasons and any(item["code"] in {"fingerprint_mismatch", "duplicate_receipt", "receipt_status_conflict", "package_status_conflict"} for item in reasons):
        derived = "conflict"
    elif reasons and any(item["code"] == "missing_fingerprint" for item in reasons):
        derived = "typed_absence"
    elif reasons and any(item["code"] == "invalid_fingerprint" for item in reasons):
        derived = "invalid"
    elif reasons and derived == "verified":
        derived = "invalid"
    return {"responsibility": name, "status": derived, "receipt_count": len(normalized_receipts), "receipts": normalized_receipts, "reasons": reasons}


def _validate_root(document: Any) -> tuple[Mapping[str, Any], str | None]:
    if not isinstance(document, Mapping):
        raise AggregateInputError("input must be a JSON object")
    version = document.get("schema_version")
    if version != SCHEMA_VERSION:
        raise AggregateInputError(f"schema_version must be {SCHEMA_VERSION}")
    _reject_unknown(document, _ROOT_FIELDS, "")
    if "fingerprints" in document:
        _validate_fingerprint_object(document["fingerprints"], "/fingerprints")
    event = document.get("event", "intake")
    if event not in ORDERED_EVENTS:
        raise AggregateInputError("event must be intake, validated or aggregate")
    sequence = document.get("sequence")
    if sequence is not None and (isinstance(sequence, bool) or not isinstance(sequence, int) or sequence < 1):
        raise AggregateInputError("sequence must be a positive integer")
    return document, event


def _base_result(document: Mapping[str, Any]) -> dict[str, Any]:
    fp = _fingerprints(document)
    return {
        "schema_version": SCHEMA_VERSION,
        "record_kind": "UP1ExternalClosureAggregateResultV1",
        "candidate_fingerprint": fp["candidate"],
        "source_fingerprint": fp["source"],
        "input_fingerprint": fp["input"],
        "claims": dict(_CLAIM_CEILING),
        "ad_created": False,
        "ad_action": "none",
    }


def aggregate_document(document: Mapping[str, Any]) -> dict[str, Any]:
    """Aggregate exactly four responsibility packages without publishing authority."""

    document, _ = _validate_root(document)
    result = _base_result(document)
    fp = _fingerprints(document)
    if not all(_nonempty_text(fp[key]) for key in ("candidate", "source", "input")):
        result.update({"status": "typed_absence", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "reason": "missing_root_fingerprint", "packages": []})
        return result
    try:
        package_items = _package_items(document)
    except AggregateInputError as exc:
        result.update({"status": "invalid", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "reason": str(exc), "packages": []})
        return result
    seen_names: set[str] = set()
    seen_receipts: set[str] = set()
    packages: list[dict[str, Any]] = []
    root_reasons: list[dict[str, Any]] = []
    for name, package in package_items:
        if name in seen_names:
            root_reasons.append({"code": "duplicate_responsibility", "responsibility": name})
        seen_names.add(name)
        packages.append(_derive_package(document, name, package, seen_receipts))
    if len(package_items) != 4:
        root_reasons.append({"code": "responsibility_count", "expected": 4, "actual": len(package_items)})
    names = [name for name, _ in package_items]
    if set(names) != RESPONSIBILITY_SET:
        root_reasons.append({"code": "responsibility_set_mismatch", "expected": sorted(RESPONSIBILITY_SET), "actual": sorted(set(names))})
    statuses = [item["status"] for item in packages]
    if document.get("authority_verified") is False:
        root_reasons.append({"code": "authority_not_verified", "path": "/authority_verified"})
    elif "authority_verified" in document and not isinstance(document["authority_verified"], bool):
        root_reasons.append({"code": "invalid_authority_verified", "path": "/authority_verified"})
    if len(set(statuses)) > 1 and not set(statuses).issubset({"verified", "typed_absence"}):
        root_reasons.append({"code": "responsibility_status_conflict", "statuses": sorted(set(statuses))})
    status = "verified" if len(package_items) == 4 and not root_reasons and statuses and all(value == "verified" for value in statuses) else "typed_absence"
    if any(value in {"invalid", "conflict"} for value in statuses) or any(item["code"] in {"duplicate_responsibility", "responsibility_count", "responsibility_set_mismatch", "responsibility_status_conflict"} for item in root_reasons):
        status = "conflict" if any(value == "conflict" for value in statuses) or any(item["code"] in {"duplicate_responsibility", "responsibility_count", "responsibility_set_mismatch", "responsibility_status_conflict"} for item in root_reasons) else "invalid"
    elif any(value in {"stale", "replayed", "unsupported"} for value in statuses):
        status = next(value for value in ("stale", "replayed", "unsupported") if value in statuses)
    elif any(value == "typed_absence" for value in statuses) or root_reasons:
        status = "typed_absence"
    result.update({
        "status": status,
        "resolution": "eligible_for_authority_recheck" if status == "verified" else "terminal_deferred",
        "terminal_deferred": status != "verified",
        "no_publish": status != "verified",
        "packages": packages,
        "reasons": root_reasons,
        "state": {"phase": "eligible_for_authority_recheck" if status == "verified" else "terminal_deferred", "sequence": 1},
    })
    return result


def _strict_loads(text: str) -> Any:
    def reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise AggregateInputError(f"duplicate JSON key: {key}")
            result[key] = value
        return result

    return json.loads(text, object_pairs_hook=reject_duplicate_pairs)


@contextmanager
def _ledger_lock(ledger_path: Path):
    lock_path = Path(str(ledger_path) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as handle:
        if os.name == "nt":
            import msvcrt

            handle.seek(0)
            handle.write(b"0")
            handle.flush()
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl

            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def _state_hash(state: Mapping[str, Any]) -> str:
    return sha256_text(canonical_json(state))


def _read_ledger(ledger_path: Path) -> list[dict[str, Any]]:
    if not ledger_path.exists():
        return []
    loaded = _strict_loads(ledger_path.read_text(encoding="utf-8"))
    if not isinstance(loaded, Mapping) or loaded.get("schema_version") != LEDGER_SCHEMA_VERSION:
        raise AggregateInputError("invalid state ledger schema")
    if set(loaded) != {"schema_version", "records"} or not isinstance(loaded.get("records"), list):
        raise AggregateInputError("invalid state ledger shape")
    records = loaded["records"]
    previous_hash = None
    for index, record in enumerate(records, 1):
        if not isinstance(record, Mapping) or set(record) != {"canonical_state_hash", "code_version", "input_fingerprint", "prev_hash", "record_hash", "sequence", "state"}:
            raise AggregateInputError(f"invalid state ledger record {index}")
        if record["code_version"] != CODE_VERSION or record["sequence"] != index or not isinstance(record["state"], Mapping):
            raise AggregateInputError(f"invalid state ledger ordering {index}")
        if not _valid_fingerprint(record["canonical_state_hash"]) or not _valid_fingerprint(record["record_hash"]):
            raise AggregateInputError(f"invalid state ledger hash {index}")
        if record["prev_hash"] is not None and not _valid_fingerprint(record["prev_hash"]):
            raise AggregateInputError(f"invalid state ledger previous hash {index}")
        if record["input_fingerprint"] is not None and not _valid_fingerprint(record["input_fingerprint"]):
            raise AggregateInputError(f"invalid state ledger fingerprint {index}")
        state_hash = _state_hash(record["state"])
        if record["canonical_state_hash"] != state_hash or record["input_fingerprint"] != record["state"].get("input_fingerprint"):
            raise AggregateInputError(f"state ledger hash/fingerprint mismatch {index}")
        if record["prev_hash"] != previous_hash:
            raise AggregateInputError(f"state ledger prev_hash mismatch {index}")
        unsigned = {key: record[key] for key in record if key != "record_hash"}
        if record["record_hash"] != sha256_text(canonical_json(unsigned)):
            raise AggregateInputError(f"state ledger record hash mismatch {index}")
        previous_hash = record["record_hash"]
    return [dict(record) for record in records]


def _write_ledger(ledger_path: Path, records: list[dict[str, Any]]) -> None:
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    payload = canonical_json({"schema_version": LEDGER_SCHEMA_VERSION, "records": records})
    descriptor, temporary = tempfile.mkstemp(prefix=ledger_path.name + ".", suffix=".tmp", dir=str(ledger_path.parent))
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, ledger_path)
    except BaseException:
        try:
            os.unlink(temporary)
        except OSError:
            pass
        raise


def _append_ledger_record(ledger_path: Path, records: list[dict[str, Any]], state: Mapping[str, Any]) -> dict[str, Any]:
    previous = records[-1]["record_hash"] if records else None
    sequence = len(records) + 1
    record: dict[str, Any] = {
        "canonical_state_hash": _state_hash(state),
        "code_version": CODE_VERSION,
        "input_fingerprint": state.get("input_fingerprint"),
        "prev_hash": previous,
        "sequence": sequence,
        "state": dict(state),
    }
    record["record_hash"] = sha256_text(canonical_json(record))
    records.append(record)
    _write_ledger(ledger_path, records)
    return record


def _public_receipt(record: Mapping[str, Any]) -> dict[str, Any]:
    """Return the non-authoritative receipt metadata for a returned state."""

    return {key: record[key] for key in ("canonical_state_hash", "prev_hash", "sequence", "input_fingerprint", "code_version")}


def _prior_matches_latest(prior_state: Mapping[str, Any], latest: Mapping[str, Any], record: Mapping[str, Any]) -> bool:
    if canonical_json(prior_state) == canonical_json(latest) and _state_hash(prior_state) == record["canonical_state_hash"]:
        return True
    # A deterministic-no-op is an envelope around the complete verified state.
    # Its receipt lets a later call prove that envelope came from this ledger;
    # caller-controlled status/packages still cannot replace the stored state.
    receipt = prior_state.get("ledger_receipt")
    if not isinstance(receipt, Mapping) or dict(receipt) != _public_receipt(record):
        return False
    envelope = json.loads(canonical_json(prior_state))
    envelope.pop("ledger_receipt", None)
    envelope.pop("input_unchanged", None)
    envelope.pop("ledger_sequence", None)
    if envelope.get("event") == "deterministic_noop":
        envelope["event"] = latest.get("event")
    return canonical_json(envelope) == canonical_json(latest)


def _ledger_failure(document: Mapping[str, Any], status: str, reason: str, event: str = "ledger_failure") -> dict[str, Any]:
    result = _base_result(document)
    result.update({"event": event, "status": status, "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "ad_created": False, "ad_action": "none", "packages": [], "reasons": [{"code": reason}]})
    return result


def _ordered_failure(document: Mapping[str, Any], reason: str, expected: Any = None, actual: Any = None, sequence: int = 0) -> dict[str, Any]:
    details: dict[str, Any] = [{"code": reason}]
    if expected is not None:
        details[0]["expected"] = expected
    if actual is not None:
        details[0]["actual"] = actual
    result = _base_result(document)
    result.update({"event": "invalid_order", "status": "invalid", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "state": {"phase": "terminal_deferred", "sequence": sequence, "input_fingerprint": _fingerprints(document)["input"]}, "packages": [], "reasons": details, "input_changed": False})
    return result


def _materialize(document: Mapping[str, Any], event: str, sequence: int, phase: str) -> dict[str, Any]:
    result = aggregate_document(document)
    result["event"] = event
    result["state"] = {"phase": phase, "sequence": sequence, "input_fingerprint": _fingerprints(document)["input"]}
    return result


def transition(document: Mapping[str, Any], prior_state: Mapping[str, Any] | None = None, ledger_path: str | Path | None = None) -> dict[str, Any]:
    """Apply an ordered transition backed by a local software-bookkeeping ledger.

    The ledger, rather than a caller-provided ``prior_state``, is authoritative.
    A supplied predecessor must be byte-for-byte canonical-equivalent to the
    latest verified ledger state.  Missing or forged predecessors fail closed.
    """

    document, event = _validate_root(document)
    root_fingerprints = _fingerprints(document)
    if any(value is not None and not _valid_fingerprint(value) for value in root_fingerprints.values()):
        return _ledger_failure(document, "invalid", "invalid_root_fingerprint", event="invalid_fingerprint")
    if any(value is None for value in root_fingerprints.values()):
        return _ledger_failure(document, "typed_absence", "missing_root_fingerprint", event="missing_fingerprint")
    if ledger_path is None:
        return _ledger_failure(document, "typed_absence", "state_ledger_required", event="ledger_required")
    path = Path(ledger_path)
    try:
        with _ledger_lock(path):
            records = _read_ledger(path)
            latest = records[-1]["state"] if records else None
            if latest is None:
                if prior_state is not None:
                    return _ledger_failure(document, "conflict", "prior_state_not_in_ledger")
                incoming = document.get("sequence")
                if event != "intake":
                    return _ordered_failure(document, "aggregate_requires_prior_intake", actual=event)
                if incoming is not None and incoming != 1:
                    return _ordered_failure(document, "sequence_expected", expected=1, actual=incoming)
                result = _materialize(document, "aggregated", incoming or 1, "aggregated")
                record = _append_ledger_record(path, records, result)
                result["ledger_receipt"] = _public_receipt(record)
                return result

            if not isinstance(prior_state, Mapping):
                return _ledger_failure(document, "conflict", "prior_state_required")
            # The caller cannot self-attest a predecessor: compare canonical
            # bytes and the ledger's independently verified state hash.
            if not _prior_matches_latest(prior_state, latest, records[-1]):
                return _ledger_failure(document, "conflict", "prior_state_not_in_ledger")

            old_fp = latest.get("input_fingerprint")
            new_fp = _fingerprints(document)["input"]
            prior_seq = latest["state"]["sequence"] if isinstance(latest.get("state"), Mapping) else 0
            prior_phase = latest["state"].get("phase") if isinstance(latest.get("state"), Mapping) else None
            incoming = document.get("sequence")
            expected = prior_seq if event == "intake" and old_fp == new_fp else prior_seq + 1
            if incoming is not None and incoming != expected:
                return _ordered_failure(document, "sequence_expected", expected=expected, actual=incoming, sequence=prior_seq)

            if old_fp != new_fp:
                changed = _base_result(document)
                changed.update({"event": "intake_changed", "status": "typed_absence", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "state": {"phase": "intake_changed", "sequence": prior_seq + 1, "input_fingerprint": new_fp}, "packages": [], "reasons": [{"code": "input_fingerprint_changed", "prior": old_fp, "current": new_fp}], "input_changed": True})
                record = _append_ledger_record(path, records, changed)
                changed["ledger_receipt"] = _public_receipt(record)
                return changed

            if event == "intake":
                # Preserve the complete verified state; input status/packages
                # from the request are never allowed to overwrite it.
                noop = json.loads(canonical_json(latest))
                noop["event"] = "deterministic_noop"
                noop["input_unchanged"] = True
                noop["ledger_sequence"] = records[-1]["sequence"]
                noop["ledger_receipt"] = _public_receipt(records[-1])
                return noop
            if event == "validated" and prior_phase in {"intake_changed", "intake"}:
                validated = _materialize(document, "validated", prior_seq + 1, "validated")
                record = _append_ledger_record(path, records, validated)
                validated["ledger_receipt"] = _public_receipt(record)
                return validated
            if event == "aggregate" and prior_phase == "validated":
                aggregated = _materialize(document, "aggregated", prior_seq + 1, "aggregated")
                record = _append_ledger_record(path, records, aggregated)
                aggregated["ledger_receipt"] = _public_receipt(record)
                return aggregated
            if event == "aggregate" and prior_phase in {"aggregated", "eligible_for_authority_recheck", "terminal_deferred"}:
                noop = json.loads(canonical_json(latest))
                noop["event"] = "deterministic_noop"
                noop["input_unchanged"] = True
                noop["ledger_sequence"] = records[-1]["sequence"]
                noop["ledger_receipt"] = _public_receipt(records[-1])
                return noop
            return _ordered_failure(document, "aggregate_requires_validated_predecessor", actual=prior_phase, sequence=prior_seq)
    except (AggregateInputError, OSError, json.JSONDecodeError, TypeError, ValueError):
        return _ledger_failure(document, "invalid", "state_ledger_tampered")


def _read_json(path: str | None) -> Any:
    if path:
        text = Path(path).read_text(encoding="utf-8")
    else:
        text = sys.stdin.read()

    return _strict_loads(text)


def _write_json(value: Mapping[str, Any], path: str | None) -> None:
    payload = canonical_json(value)
    if path:
        Path(path).write_text(payload, encoding="utf-8", newline="")
    else:
        sys.stdout.write(payload + "\n")


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", "-i", dest="input_path", help="versioned JSON input; default stdin")
    parser.add_argument("--prior-state", "--state", dest="state_path", help="prior result JSON for ordered transition")
    parser.add_argument("--ledger", "--ledger-path", dest="ledger_path", help="local state ledger (software bookkeeping)")
    parser.add_argument("--output", "-o", dest="output_path", help="write compact canonical JSON")
    args = parser.parse_args(argv)
    try:
        document = _read_json(args.input_path)
        prior = _read_json(args.state_path) if args.state_path else None
        result = transition(document, prior, ledger_path=args.ledger_path)
        _write_json(result, args.output_path)
        return 0
    except (AggregateInputError, json.JSONDecodeError, OSError, TypeError, ValueError) as exc:
        error = {"schema_version": SCHEMA_VERSION, "record_kind": "UP1ExternalClosureAggregateErrorV1", "status": "invalid", "resolution": "terminal_deferred", "terminal_deferred": True, "no_publish": True, "ad_created": False, "ad_action": "none", "error": str(exc), "claims": dict(_CLAIM_CEILING)}
        _write_json(error, args.output_path)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
