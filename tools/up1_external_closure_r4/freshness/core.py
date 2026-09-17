"""Offline, fail-closed freshness/revocation/replay prototype.

This module is intentionally transport agnostic.  OCSP, CRL and trusted-time
objects are *receipts supplied by an authority*; this code never contacts an
authority and never uses the host wall clock to establish validity.  Missing
authority material is therefore a typed absence (``terminal_deferred``), while
malformed or contradictory material is a hard ``fail_closed`` result.
"""

from __future__ import annotations

import copy
import hashlib
import hmac
import json
import math
import os
import re
import stat
import tempfile
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

SCHEMA = "UP1-R4.freshness.v1"
PROFILE = "OFFLINE-FAIL-CLOSED-R4"
REPLAY_SCHEMA = "UP1-R4.replay-state.v1"
CLAIM_CEILING = "offline freshness prototype; no authority or physical evidence"

RECEIPT_FIELDS = {
    "verification_id", "nonce", "challenge", "scope", "source", "source_version",
    "sequence", "issued_at", "expires_at", "idempotency_key", "payload",
}
TOP_FIELDS = {
    "schema", "profile", "test_only", "receipt", "receipt_signature_valid",
    "attestor_signature", "clock_skew_seconds", "replay_window",
    "trusted_time_receipt", "trusted_time", "revocation_receipt", "revocation",
    "expected_scope", "expected_source_version", "ledger_namespace",
}
SCOPE_FIELDS = {"candidate", "source"}
VERSION_FIELDS = {"version", "hash"}
WINDOW_FIELDS = {"duration_seconds", "trusted_time_basis", "ledger_retention_seconds", "clock_skew_seconds"}
ATTESTOR_FIELDS = {"signature_valid"}

_RFC3339 = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$")
_HEX64 = re.compile(r"^[0-9a-f]{64}$")


class ReceiptInputError(ValueError):
    """A malformed or unauthenticated local replay-state input."""

    def __init__(self, message: str, code: str = "input_invalid") -> None:
        super().__init__(message)
        self.code = code


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def canonical_digest(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def parse_json_strict(raw: str | bytes) -> Any:
    """Parse JSON while rejecting duplicate keys and non-finite constants."""

    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise ReceiptInputError(f"duplicate JSON key: {key}", "duplicate_field")
            result[key] = value
        return result

    def constant(value: str) -> Any:
        raise ReceiptInputError(f"non-finite JSON number: {value}", "nonfinite_number")

    try:
        return json.loads(raw, object_pairs_hook=pairs, parse_constant=constant)
    except ReceiptInputError:
        raise
    except (TypeError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReceiptInputError(f"invalid JSON: {exc}", "invalid_json") from exc


def _dt(value: Any) -> datetime | None:
    if not isinstance(value, str) or not _RFC3339.fullmatch(value):
        return None
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00" if value.endswith("Z") else value)
    except (TypeError, ValueError, OverflowError):
        return None
    return parsed.astimezone(timezone.utc) if parsed.tzinfo is not None else None


def _finite(value: Any) -> bool:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return False
    try:
        return math.isfinite(float(value))
    except (TypeError, ValueError, OverflowError):
        return False


def _error(code: str, detail: str, *, digest: str | None = None, absent: bool = False, extra: Mapping[str, Any] | None = None) -> dict[str, Any]:
    result = "typed_absent" if absent else "fail_closed"
    out: dict[str, Any] = {
        "schema": SCHEMA,
        "result": result,
        "status": result,
        "resolution": "terminal_deferred" if absent else "fail_closed",
        "error_code": code,
        "detail": detail,
        "claim_ceiling": CLAIM_CEILING,
        "formal_credit": "none",
        "no_publish": True,
        "network_access": False,
        "trusted_clock_basis": "signed_receipt_only",
    }
    if digest is not None:
        out["canonical_receipt_digest"] = digest
    if extra:
        out.update(copy.deepcopy(dict(extra)))
    return out


def _check_fields(value: Any, allowed: set[str], path: str) -> tuple[str | None, str]:
    if not isinstance(value, Mapping):
        return "receipt_type_invalid", f"{path} must be an object"
    unknown = sorted(set(value) - allowed)
    return ("unknown_field", f"unknown field at {path}: {unknown[0]}") if unknown else (None, "ok")


def _alias(obj: Mapping[str, Any], canonical: str, alternate: str) -> tuple[str | None, Any]:
    if canonical in obj and alternate in obj:
        return "unknown_field", f"conflicting aliases: {canonical}/{alternate}"
    return None, obj.get(canonical, obj.get(alternate))


def _scope_key(scope: Mapping[str, str]) -> str:
    return canonical_bytes(scope).decode("utf-8")


def _validate_structure(receipt: Any) -> tuple[str | None, str]:
    code, detail = _check_fields(receipt, RECEIPT_FIELDS, "$.receipt")
    if code:
        return code, detail
    for field in ("verification_id", "nonce", "challenge", "source", "idempotency_key", "issued_at", "expires_at"):
        if field not in receipt or receipt[field] in (None, ""):
            return ("nonce_absent" if field == "nonce" else "receipt_field_absent"), f"missing receipt field: {field}"
    for field in ("verification_id", "nonce", "challenge", "source", "idempotency_key"):
        if not isinstance(receipt[field], str) or not receipt[field]:
            return "receipt_type_invalid", f"{field} must be a non-empty string"
    scope = receipt.get("scope")
    if not isinstance(scope, Mapping) or set(scope) != SCOPE_FIELDS or any(not isinstance(scope[k], str) or not scope[k] for k in SCOPE_FIELDS):
        return "scope_binding_mismatch", "scope must be {candidate,source} non-empty strings"
    if receipt["source"] != scope["source"]:
        return "scope_binding_mismatch", "receipt source must equal scope.source"
    version = receipt.get("source_version")
    if not isinstance(version, Mapping) or set(version) != VERSION_FIELDS or any(not isinstance(version[k], str) or not version[k] for k in VERSION_FIELDS):
        return "source_version_binding_mismatch", "source_version must be {version,hash} strings"
    if not isinstance(receipt.get("sequence"), int) or isinstance(receipt["sequence"], bool) or receipt["sequence"] < 0:
        return "sequence_invalid", "sequence must be a non-negative integer"
    if _dt(receipt["issued_at"]) is None or _dt(receipt["expires_at"]) is None:
        return "timestamp_invalid", "issued_at and expires_at must be RFC3339 timestamps"
    if "payload" in receipt and not isinstance(receipt["payload"], Mapping):
        return "receipt_type_invalid", "payload must be an object"
    return None, "ok"


def _validate_trusted_time(value: Any, digest: str, receipt: Mapping[str, Any], skew: float) -> tuple[str | None, str, datetime | None]:
    if not isinstance(value, Mapping):
        return "trusted_time_absent", "trusted-time authority receipt is absent; OS wall clock is not used", None
    allowed = {"available", "profile", "gen_time", "genTime", "receipt_digest", "receiptDigest", "message_imprint", "messageImprint", "nonce", "challenge", "policy", "valid_from", "validFrom", "valid_to", "validTo", "signature_valid", "signatureValid", "chain_valid", "chainValid", "revocation_valid", "revocationValid", "authority_id"}
    code, detail = _check_fields(value, allowed, "$.trusted_time_receipt")
    if code:
        return code, detail, None
    ts = dict(value)
    if ts.get("available") is not True:
        return "trusted_time_absent", "trusted-time authority receipt is unavailable; OS wall clock is not used", None
    for canonical, alternate in (("gen_time", "genTime"), ("receipt_digest", "receiptDigest"), ("message_imprint", "messageImprint"), ("valid_from", "validFrom"), ("valid_to", "validTo"), ("signature_valid", "signatureValid"), ("chain_valid", "chainValid"), ("revocation_valid", "revocationValid")):
        conflict, val = _alias(ts, canonical, alternate)
        if conflict:
            return conflict, val, None
        if canonical not in ts and alternate in ts:
            ts[canonical] = ts[alternate]
    if ts.get("profile") not in {"rfc3161", "equivalent_signed_time"}:
        return "timestamp_invalid", "unsupported trusted-time profile", None
    gen = _dt(ts.get("gen_time"))
    if gen is None:
        return "timestamp_invalid", "trusted-time gen_time is invalid", None
    if ts.get("signature_valid") is not True or ts.get("chain_valid") is not True or ts.get("revocation_valid") is not True:
        return "timestamp_invalid", "trusted-time signature, chain, or revocation is not valid", None
    if ts.get("receipt_digest") != digest or ts.get("message_imprint") != digest:
        return "receipt_digest_mismatch", "trusted-time receipt does not bind canonical receipt digest", None
    if ts.get("nonce") not in (None, receipt.get("nonce")) or ts.get("challenge") not in (None, receipt.get("challenge")):
        return "timestamp_invalid", "trusted-time nonce/challenge does not bind receipt", None
    if not isinstance(ts.get("policy"), str) or not ts["policy"]:
        return "timestamp_invalid", "trusted-time policy is absent", None
    for field in ("valid_from", "valid_to"):
        if field in ts and _dt(ts[field]) is None:
            return "timestamp_invalid", f"trusted-time {field} is invalid", None
    tolerance = timedelta(seconds=skew)
    valid_from, valid_to = _dt(ts.get("valid_from")), _dt(ts.get("valid_to"))
    if valid_from is not None and gen < valid_from - tolerance or valid_to is not None and gen > valid_to + tolerance:
        return "timestamp_expired", "trusted-time receipt is outside its validity interval", None
    return None, "trusted", gen


def _validate_revocation(value: Any, as_of: datetime, skew: float, receipt_nonce: str) -> tuple[str | None, str]:
    if not isinstance(value, Mapping):
        return "revocation_status_unavailable", "revocation authority receipt is absent; no network lookup performed"
    allowed = {"available", "kind", "status", "issuer", "serial", "this_update", "thisUpdate", "next_update", "nextUpdate", "produced_at", "producedAt", "signature_valid", "signatureValid", "issuer_binding_valid", "issuerBindingValid", "responder_signature_valid", "chain_valid", "nonce_required", "nonce", "crl_number", "certificate_serial", "authority_id"}
    code, detail = _check_fields(value, allowed, "$.revocation_receipt")
    if code:
        return code, detail
    rev = dict(value)
    if rev.get("available") is not True:
        return "revocation_status_unavailable", "revocation authority receipt is unavailable; no network lookup performed"
    for canonical, alternate in (("this_update", "thisUpdate"), ("next_update", "nextUpdate"), ("produced_at", "producedAt"), ("signature_valid", "signatureValid"), ("issuer_binding_valid", "issuerBindingValid")):
        conflict, val = _alias(rev, canonical, alternate)
        if conflict:
            return conflict, val
        if canonical not in rev and alternate in rev:
            rev[canonical] = rev[alternate]
    kind = rev.get("kind")
    if kind not in {"ocsp", "crl", "revocation_receipt"}:
        return "revocation_status_invalid", "kind must be ocsp, crl, or revocation_receipt"
    required = ("issuer", "serial", "this_update", "next_update", "signature_valid", "issuer_binding_valid")
    if kind == "ocsp":
        required += ("produced_at", "responder_signature_valid", "chain_valid")
    elif kind == "crl":
        required += ("crl_number", "certificate_serial")
    for field in required:
        if field not in rev or rev[field] in (None, ""):
            return "revocation_status_unavailable", f"revocation authority field absent: {field}"
    if not isinstance(rev["issuer"], str) or not isinstance(rev["serial"], str):
        return "revocation_status_invalid", "issuer and serial must be strings"
    if rev.get("signature_valid") is not True or rev.get("issuer_binding_valid") is not True:
        return "certificate_signature_invalid", "revocation receipt signature or issuer binding is invalid"
    if kind == "ocsp" and (rev.get("responder_signature_valid") is not True or rev.get("chain_valid") is not True):
        return "certificate_signature_invalid", "OCSP responder signature chain is invalid"
    this_update, next_update = _dt(rev["this_update"]), _dt(rev["next_update"])
    produced = _dt(rev.get("produced_at")) if kind == "ocsp" else this_update
    if this_update is None or next_update is None or produced is None:
        return "timestamp_invalid", "revocation authority timestamps are invalid"
    tolerance = timedelta(seconds=skew)
    if this_update > next_update or produced > as_of + tolerance or as_of < this_update - tolerance or as_of > next_update + tolerance:
        return "revocation_response_stale", "revocation authority receipt is stale or outside freshness bounds"
    if kind == "ocsp" and rev.get("nonce_required") is True:
        if not isinstance(rev.get("nonce"), str) or not rev["nonce"]:
            return "nonce_absent", "OCSP nonce is required but absent"
    if kind == "ocsp" and rev.get("nonce") is not None and rev.get("nonce") != receipt_nonce:
        return "nonce_replayed", "OCSP nonce does not bind receipt nonce"
    if rev.get("status") not in {"good", "not_revoked", "revoked", "unknown"}:
        return "revocation_status_unavailable", "revocation status is absent"
    if rev["status"] == "revoked":
        return "certificate_revoked", "revocation authority receipt says revoked"
    if rev["status"] == "unknown":
        return "revocation_status_unknown", "revocation authority receipt says unknown"
    return None, "good"


def validate_revocation_receipt(value: Any, *, trusted_as_of: datetime, receipt_nonce: str, clock_skew_seconds: float = 0.0) -> dict[str, Any]:
    """Validate an injected OCSP/CRL/revocation receipt without I/O.

    The returned tuple-like information is kept as a normal result mapping so
    callers can preserve typed absence and hard-failure semantics at a
    boundary that does not yet have a complete envelope.
    """

    if not isinstance(trusted_as_of, datetime) or trusted_as_of.tzinfo is None or not _finite(clock_skew_seconds) or float(clock_skew_seconds) < 0:
        return _error("timestamp_invalid", "trusted_as_of must be timezone-aware and skew must be finite")
    code, detail = _validate_revocation(value, trusted_as_of.astimezone(timezone.utc), float(clock_skew_seconds), receipt_nonce)
    if code:
        return _error(code, detail, absent=code == "revocation_status_unavailable")
    return {"schema": SCHEMA, "result": "valid_for_declared_scope", "status": "good", "resolution": "valid_for_declared_scope", "error_code": None, "formal_credit": "none", "no_publish": True, "network_access": False}


def _empty_state() -> dict[str, Any]:
    return {"nonces": {}, "sequences": {}, "idempotency": {}, "entries": []}


def _state_hash(state: Mapping[str, Any]) -> str:
    return canonical_digest(state)


class PersistentReplayState:
    """HMAC-authenticated replay state with lock, CAS and atomic replacement."""

    def __init__(self, path: str | os.PathLike[str], *, key_path: str | os.PathLike[str] | None = None, key: bytes | None = None, namespace: str = "UP1-R4", lock_timeout: float = 10.0) -> None:
        self.path = Path(os.path.abspath(os.fspath(path)))
        self.key_path = Path(os.path.abspath(os.fspath(key_path))) if key_path is not None else None
        self._key_value = bytes(key) if key is not None else None
        self.namespace = namespace
        self.lock_path = self.path.with_name(self.path.name + ".lock")
        self.lock_timeout = float(lock_timeout)

    @staticmethod
    def _reject_reparse(path: Path, label: str, *, regular: bool = False) -> None:
        probe = path
        while True:
            try:
                st = os.lstat(probe)
            except FileNotFoundError:
                if probe == probe.parent:
                    break
                probe = probe.parent
                continue
            if stat.S_ISLNK(st.st_mode) or getattr(st, "st_file_attributes", 0) & 0x400:
                raise ReceiptInputError(f"{label} is a symlink/reparse point", "ledger_corrupt")
            if probe == path and regular and not stat.S_ISREG(st.st_mode):
                raise ReceiptInputError(f"{label} must be a regular file", "ledger_corrupt")
            if probe == probe.parent:
                break
            probe = probe.parent

    def _key(self) -> bytes:
        if self._key_value is not None:
            key = self._key_value
        elif self.key_path is not None:
            self._reject_reparse(self.key_path, "trusted replay key", regular=True)
            try:
                key = self.key_path.read_bytes()
            except OSError as exc:
                raise ReceiptInputError(f"trusted replay key unavailable: {exc}", "replay_ledger_absent") from exc
        else:
            raise ReceiptInputError("explicit trusted replay key is absent", "replay_ledger_absent")
        if len(key) < 16:
            raise ReceiptInputError("replay authentication key is too short", "ledger_corrupt")
        return key

    def _lock(self) -> int:
        self._reject_reparse(self.path, "replay state")
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self._reject_reparse(self.lock_path, "replay state lock")
        deadline = time.monotonic() + max(0.0, self.lock_timeout)
        while True:
            try:
                return os.open(self.lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            except FileExistsError:
                if time.monotonic() >= deadline:
                    raise TimeoutError("replay state lock timeout")
                time.sleep(0.005)

    def _unlock(self, fd: int) -> None:
        try:
            os.close(fd)
        finally:
            try:
                self.lock_path.unlink()
            except FileNotFoundError:
                pass

    def _envelope(self, state: Mapping[str, Any], key: bytes, version: int = 0) -> dict[str, Any]:
        base = {"schema": REPLAY_SCHEMA, "version": version, "namespace": self.namespace, "state": state, "state_hash": _state_hash(state)}
        base["auth_tag"] = hmac.new(key, canonical_bytes(base), hashlib.sha256).hexdigest()
        return base

    @staticmethod
    def _check_state(state: Any) -> None:
        if not isinstance(state, Mapping) or set(state) != {"nonces", "sequences", "idempotency", "entries"}:
            raise ReceiptInputError("replay state shape invalid", "ledger_corrupt")
        if not isinstance(state["nonces"], dict) or not isinstance(state["sequences"], dict) or not isinstance(state["idempotency"], dict) or not isinstance(state["entries"], list):
            raise ReceiptInputError("replay state field types invalid", "ledger_corrupt")
        indexes: tuple[dict[str, list[str]], dict[str, int], dict[str, dict[str, str]]] = ({}, {}, {})
        seen_nonce: set[str] = set(); seen_idem: set[str] = set(); seen_seq: set[tuple[str, int]] = set()
        for row in state["entries"]:
            fields = {"scope", "source", "nonce", "sequence", "idempotency_key", "canonical_digest", "result_digest"}
            if not isinstance(row, Mapping) or set(row) != fields or not all(isinstance(row[k], str) for k in ("scope", "source", "nonce", "idempotency_key", "canonical_digest", "result_digest")) or not isinstance(row["sequence"], int) or isinstance(row["sequence"], bool) or row["sequence"] < 0:
                raise ReceiptInputError("replay state entry invalid", "ledger_corrupt")
            try:
                scope_obj = json.loads(row["scope"])
            except (TypeError, ValueError, json.JSONDecodeError) as exc:
                raise ReceiptInputError("replay scope is not canonical JSON", "ledger_corrupt") from exc
            if not isinstance(scope_obj, Mapping) or set(scope_obj) != SCOPE_FIELDS or scope_obj.get("source") != row["source"] or _scope_key(scope_obj) != row["scope"]:
                raise ReceiptInputError("replay scope/source binding invalid", "ledger_corrupt")
            if row["nonce"] in seen_nonce or row["idempotency_key"] in seen_idem or (row["source"], row["sequence"]) in seen_seq:
                raise ReceiptInputError("replay state duplicate nonce, idempotency key, or source sequence", "ledger_corrupt")
            if not _HEX64.fullmatch(row["canonical_digest"]) or not _HEX64.fullmatch(row["result_digest"]):
                raise ReceiptInputError("replay digest invalid", "ledger_corrupt")
            seen_nonce.add(row["nonce"]); seen_idem.add(row["idempotency_key"]); seen_seq.add((row["source"], row["sequence"]))
            indexes[0].setdefault(row["scope"], []).append(row["nonce"])
            indexes[1][row["scope"]] = row["sequence"]
            indexes[2][row["idempotency_key"]] = {"canonical_digest": row["canonical_digest"], "result_digest": row["result_digest"]}
        if state["nonces"] != indexes[0] or state["sequences"] != indexes[1] or state["idempotency"] != indexes[2]:
            raise ReceiptInputError("replay indexes disagree with entries", "ledger_corrupt")

    def _read_unlocked(self, key: bytes) -> dict[str, Any]:
        self._reject_reparse(self.path, "replay state", regular=self.path.exists())
        if not self.path.exists():
            return self._envelope(_empty_state(), key, 0)
        try:
            envelope = parse_json_strict(self.path.read_text(encoding="utf-8"))
        except Exception as exc:
            if isinstance(exc, ReceiptInputError):
                raise ReceiptInputError(str(exc), "ledger_corrupt") from exc
            raise ReceiptInputError(f"replay state unreadable: {exc}", "ledger_corrupt") from exc
        fields = {"schema", "version", "namespace", "state", "state_hash", "auth_tag"}
        if not isinstance(envelope, Mapping) or set(envelope) != fields or envelope.get("schema") != REPLAY_SCHEMA or envelope.get("namespace") != self.namespace or not isinstance(envelope.get("version"), int) or envelope["version"] < 0:
            raise ReceiptInputError("replay state envelope invalid", "ledger_corrupt")
        base = {k: envelope[k] for k in ("schema", "version", "namespace", "state", "state_hash")}
        expected = hmac.new(key, canonical_bytes(base), hashlib.sha256).hexdigest()
        if not isinstance(envelope.get("auth_tag"), str) or not hmac.compare_digest(envelope["auth_tag"], expected) or envelope.get("state_hash") != _state_hash(envelope.get("state")):
            raise ReceiptInputError("replay state authentication or hash failed", "ledger_corrupt")
        self._check_state(envelope["state"])
        return dict(envelope)

    def _atomic_write(self, envelope: Mapping[str, Any]) -> None:
        fd, temp_name = tempfile.mkstemp(prefix=self.path.name + ".", suffix=".tmp", dir=str(self.path.parent), text=True)
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
                json.dump(envelope, stream, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
                stream.flush(); os.fsync(stream.fileno())
            self._reject_reparse(Path(temp_name), "replay state temporary file", regular=True)
            os.replace(temp_name, self.path)
            try:
                dir_fd = os.open(self.path.parent, os.O_RDONLY)
                try:
                    os.fsync(dir_fd)
                finally:
                    os.close(dir_fd)
            except OSError:
                pass
        finally:
            try:
                os.unlink(temp_name)
            except FileNotFoundError:
                pass

    def check_and_commit(self, *, scope: str, source: str, nonce: str, sequence: int, key: str, digest: str, result_digest: str, expected_state_hash: str | None = None, expected_version: int | None = None) -> tuple[str, dict[str, Any]]:
        lock_fd = self._lock()
        try:
            auth_key = self._key()
            envelope = self._read_unlocked(auth_key)
            if expected_state_hash is not None and expected_state_hash != envelope["state_hash"] or expected_version is not None and expected_version != envelope["version"]:
                return "cas_conflict", envelope
            state = copy.deepcopy(envelope["state"])
            prior = state["idempotency"].get(key)
            if prior is not None:
                return ("idempotent_replay" if prior.get("canonical_digest") == digest else "idempotency_conflict"), envelope
            for other_scope, values in state["nonces"].items():
                if nonce in values:
                    return ("nonce_replayed" if other_scope == scope else "scope_binding_mismatch"), envelope
            if any(row["source"] == source and row["sequence"] == sequence for row in state["entries"]):
                return "sequence_invalid", envelope
            prior_sequence = state["sequences"].get(scope)
            if prior_sequence is not None:
                if sequence <= prior_sequence:
                    return "sequence_invalid", envelope
                if sequence != prior_sequence + 1:
                    return "sequence_gap", envelope
            state["nonces"].setdefault(scope, []).append(nonce)
            state["sequences"][scope] = sequence
            state["idempotency"][key] = {"canonical_digest": digest, "result_digest": result_digest}
            state["entries"].append({"scope": scope, "source": source, "nonce": nonce, "sequence": sequence, "idempotency_key": key, "canonical_digest": digest, "result_digest": result_digest})
            self._check_state(state)
            new_envelope = self._envelope(state, auth_key, int(envelope["version"]) + 1)
            self._atomic_write(new_envelope)
            return "committed", new_envelope
        finally:
            self._unlock(lock_fd)


# Name used by the earlier prototype and convenient for callers migrating to R4.
PersistentReplayLedger = PersistentReplayState


def validate(payload: Mapping[str, Any], *, ledger: PersistentReplayState | None = None) -> dict[str, Any]:
    if not isinstance(payload, Mapping):
        return _error("receipt_type_invalid", "input must be an object")
    unknown = sorted(set(payload) - TOP_FIELDS)
    if unknown:
        return _error("unknown_field", f"unknown field at $: {unknown[0]}")
    if payload.get("schema") != SCHEMA or payload.get("profile") != PROFILE:
        return _error("signature_profile_unknown", "schema/profile do not match the offline R4 profile")
    receipt = payload.get("receipt")
    digest: str | None = None
    try:
        digest = canonical_digest(receipt)
    except (TypeError, ValueError):
        pass
    code, detail = _validate_structure(receipt)
    if code:
        # A malformed envelope is not an authority absence.  Only explicitly
        # missing external authority material is typed_absent below.
        return _error(code, detail, digest=digest)
    assert isinstance(receipt, Mapping)
    if payload.get("expected_scope") is not None:
        expected = payload["expected_scope"]
        if not isinstance(expected, Mapping) or set(expected) != SCOPE_FIELDS or any(not isinstance(expected[k], str) or not expected[k] for k in SCOPE_FIELDS):
            return _error("scope_binding_mismatch", "expected_scope must be {candidate,source} strings", digest=digest)
        if dict(expected) != dict(receipt["scope"]):
            return _error("scope_binding_mismatch", "receipt scope differs from expected verifier scope", digest=digest)
    if payload.get("expected_source_version") is not None:
        expected_version = payload["expected_source_version"]
        if not isinstance(expected_version, Mapping) or set(expected_version) != VERSION_FIELDS or any(not isinstance(expected_version[k], str) or not expected_version[k] for k in VERSION_FIELDS):
            return _error("source_version_binding_mismatch", "expected_source_version must be {version,hash} strings", digest=digest)
        if dict(expected_version) != dict(receipt["source_version"]):
            return _error("source_version_binding_mismatch", "receipt source version differs from expected binding", digest=digest)
    attestor = payload.get("attestor_signature")
    if attestor is not None:
        code, detail = _check_fields(attestor, ATTESTOR_FIELDS, "$.attestor_signature")
        if code:
            return _error(code, detail, digest=digest)
    if payload.get("receipt_signature_valid") is not True and not (isinstance(attestor, Mapping) and attestor.get("signature_valid") is True):
        return _error("certificate_signature_invalid", "canonical receipt has no valid authority signature", digest=digest)
    skew = payload.get("clock_skew_seconds", 0)
    if not _finite(skew) or float(skew) < 0:
        return _error("timestamp_invalid", "clock skew must be finite and non-negative", digest=digest)
    window = payload.get("replay_window")
    if not isinstance(window, Mapping):
        return _error("replay_window_absent", "replay freshness window authority input is absent", digest=digest, absent=True)
    code, detail = _check_fields(window, WINDOW_FIELDS, "$.replay_window")
    if code:
        return _error(code, detail, digest=digest)
    if "duration_seconds" not in window or "trusted_time_basis" not in window:
        return _error("replay_window_absent", "replay window lacks signed-time basis or duration", digest=digest, absent=True)
    if not _finite(window["duration_seconds"]) or float(window["duration_seconds"]) <= 0 or window["trusted_time_basis"] not in {"signed_receipt", "trusted_time_receipt"}:
        return _error("replay_window_invalid", "replay window duration/basis invalid", digest=digest)
    for name in ("ledger_retention_seconds", "clock_skew_seconds"):
        if name in window and (not _finite(window[name]) or float(window[name]) < 0):
            return _error("replay_window_invalid", f"replay window {name} must be finite and non-negative", digest=digest)
    time_input = payload.get("trusted_time_receipt", payload.get("trusted_time"))
    code, detail, as_of = _validate_trusted_time(time_input, digest or "", receipt, float(skew))
    if code:
        return _error(code, detail, digest=digest, absent=code == "trusted_time_absent")
    assert as_of is not None
    issued, expires = _dt(receipt["issued_at"]), _dt(receipt["expires_at"])
    assert issued is not None and expires is not None
    tolerance = timedelta(seconds=float(skew))
    if expires < issued:
        return _error("timestamp_invalid", "receipt expires before issued", digest=digest)
    if issued > as_of + tolerance:
        return _error("timestamp_invalid", "receipt is from the future relative to trusted time", digest=digest)
    if expires < as_of - tolerance:
        return _error("timestamp_expired", "receipt expired relative to trusted time", digest=digest)
    if (as_of - issued).total_seconds() > float(window["duration_seconds"]) + float(skew):
        return _error("replay_window_expired", "receipt is outside replay freshness window", digest=digest)
    revocation_input = payload.get("revocation_receipt", payload.get("revocation"))
    code, detail = _validate_revocation(revocation_input, as_of, float(skew), receipt["nonce"])
    if code:
        return _error(code, detail, digest=digest, absent=code == "revocation_status_unavailable")
    if ledger is None:
        return _error("replay_ledger_absent", "durable authenticated replay state is required", digest=digest, absent=True)
    namespace = payload.get("ledger_namespace", "UP1-R4")
    if not isinstance(namespace, str) or not namespace or ledger.namespace != namespace:
        return _error("scope_binding_mismatch", "ledger namespace does not match verifier namespace", digest=digest)
    scope = _scope_key(receipt["scope"])
    result_digest = canonical_digest({"ok": True, "digest": digest})
    try:
        disposition, envelope = ledger.check_and_commit(scope=scope, source=receipt["source"], nonce=receipt["nonce"], sequence=receipt["sequence"], key=receipt["idempotency_key"], digest=digest or "", result_digest=result_digest)
    except (OSError, ReceiptInputError, TimeoutError) as exc:
        return _error(getattr(exc, "code", "replay_ledger_invalid"), str(exc), digest=digest, absent=getattr(exc, "code", "") == "replay_ledger_absent")
    if disposition != "committed":
        return _error(disposition, f"durable replay state rejected receipt: {disposition}", digest=digest, extra={"replay_state": envelope})
    return {
        "schema": SCHEMA,
        "result": "valid_for_declared_scope",
        "status": "valid_for_declared_scope",
        "resolution": "valid_for_declared_scope",
        "error_code": None,
        "canonical_receipt_digest": digest,
        "trusted_as_of": as_of.isoformat().replace("+00:00", "Z"),
        "revocation": "good",
        "claim_ceiling": CLAIM_CEILING,
        "formal_credit": "none",
        "no_publish": True,
        "network_access": False,
        "trusted_clock_basis": "signed_receipt_only",
        "replay_state": envelope,
    }


validate_freshness = validate
_validate_time = _validate_trusted_time
