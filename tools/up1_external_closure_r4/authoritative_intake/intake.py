"""Local, fail-closed intake and isolation for UP1 external handoffs.

The object intentionally has a narrow claim ceiling:

* only an explicitly configured channel identity and policy can pass the local
  admission checks;
* every input is copied as the exact original bytes into a content-addressed
  quarantine object and receives a local transport receipt;
* packet sets are committed as one decision (``accepted_all`` or
  ``rejected_all``), never partially;
* no local receipt is a channel acknowledgement, signature, or authority
  proof.  Missing real channel configuration is ``typed_absent`` and a
  configured-but-unverified packet is ``typed_unverified``.

No network or message API is present in this module by design.
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import secrets
import stat
import tempfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Iterable, Mapping

SCHEMA_VERSION = "UP1.authoritative-intake-r4.v1"
RECEIPT_SCHEMA_VERSION = "UP1.authoritative-intake-transport-receipt-r4.v1"
ACK_SCHEMA_VERSION = "UP1.authoritative-intake-packet-set-ack-r4.v1"
MAX_BYTES_DEFAULT = 16 * 1024 * 1024
_HEX = frozenset("0123456789abcdef")
_IDENTIFIER = frozenset("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")


class IntakeError(ValueError):
    """Stable, fail-closed local intake error."""

    def __init__(self, code: str, message: str, **details: Any) -> None:
        super().__init__(message)
        self.code = str(code)
        self.message = str(message)
        self.details = details


def _utc_now() -> str:
    return _dt.datetime.now(_dt.timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _canonical(value: Any) -> bytes:
    try:
        return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")
    except (TypeError, ValueError, UnicodeEncodeError) as exc:
        raise IntakeError("noncanonical_value", "value cannot be represented as canonical UTF-8 JSON") from exc


def _json_loads_unique(raw: bytes) -> Any:
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise IntakeError("invalid_utf8", "packet is not UTF-8 JSON") from exc

    def pairs(items: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in items:
            if key in result:
                raise IntakeError("duplicate_json_key", f"duplicate JSON key: {key}")
            result[key] = value
        return result

    try:
        return json.loads(text, object_pairs_hook=pairs, parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))
    except IntakeError:
        raise
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        raise IntakeError("invalid_json", "packet is not valid JSON") from exc


def _id(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value or len(value) > 256 or any(char not in _IDENTIFIER for char in value):
        raise IntakeError("invalid_identifier", f"{name} must be a bounded explicit identifier")
    return value


def _bool(value: Any, name: str) -> bool:
    if not isinstance(value, bool):
        raise IntakeError("invalid_policy", f"{name} must be boolean")
    return value


@dataclass(frozen=True)
class ChannelIdentity:
    """Explicit local description of one channel identity.

    ``real_channel`` is intentionally opt-in.  Its default is false, so a
    configuration object alone cannot manufacture a real external channel.
    ``endpoint`` is descriptive only and is never contacted.
    """

    channel_id: str
    owner_id: str
    transport: str
    endpoint: str = ""
    real_channel: bool = False
    identity_ref: str = ""

    def __post_init__(self) -> None:
        _id(self.channel_id, "channel_id")
        _id(self.owner_id, "owner_id")
        _id(self.transport, "transport")
        if self.endpoint and not isinstance(self.endpoint, str):
            raise IntakeError("invalid_channel_identity", "endpoint must be a string")
        _bool(self.real_channel, "real_channel")
        if self.identity_ref:
            _id(self.identity_ref, "identity_ref")

    @classmethod
    def from_value(cls, value: "ChannelIdentity | Mapping[str, Any]") -> "ChannelIdentity":
        if isinstance(value, cls):
            return value
        if not isinstance(value, Mapping):
            raise IntakeError("channel_identity_required", "explicit channel identity is required")
        return cls(
            channel_id=value.get("channel_id", value.get("authority_channel_id", "")),
            owner_id=value.get("owner_id", value.get("channel_owner_id", "")),
            transport=value.get("transport", ""),
            endpoint=value.get("endpoint", ""),
            real_channel=value.get("real_channel", value.get("configured_real_channel", False)),
            identity_ref=value.get("identity_ref", ""),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "channel_id": self.channel_id,
            "owner_id": self.owner_id,
            "transport": self.transport,
            "endpoint": self.endpoint,
            "identity_ref": self.identity_ref,
            "real_channel": self.real_channel,
        }


@dataclass(frozen=True)
class ChannelPolicy:
    """Explicit admission policy for one channel.

    ``required_packet_ids`` may be empty for a generic packet set.  When it is
    non-empty, the incoming set must contain exactly those IDs once each.
    """

    channel_id: str
    required_packet_ids: tuple[str, ...] = ()
    allowed_packet_ids: tuple[str, ...] = ()
    max_packet_count: int = 64
    max_packet_bytes: int = MAX_BYTES_DEFAULT
    # A local transport can admit bytes without proving external authority.
    # Callers that need signature-gated local admission must opt in explicitly.
    require_signature: bool = False
    policy_ref: str = ""

    def __post_init__(self) -> None:
        _id(self.channel_id, "policy.channel_id")
        if len(set(self.required_packet_ids)) != len(self.required_packet_ids):
            raise IntakeError("invalid_policy", "required_packet_ids must be unique")
        for value in (*self.required_packet_ids, *self.allowed_packet_ids):
            _id(value, "packet_id")
        if not isinstance(self.max_packet_count, int) or isinstance(self.max_packet_count, bool) or self.max_packet_count < 1:
            raise IntakeError("invalid_policy", "max_packet_count must be positive")
        if not isinstance(self.max_packet_bytes, int) or isinstance(self.max_packet_bytes, bool) or self.max_packet_bytes < 1:
            raise IntakeError("invalid_policy", "max_packet_bytes must be positive")
        _bool(self.require_signature, "require_signature")
        if self.policy_ref:
            _id(self.policy_ref, "policy_ref")

    @classmethod
    def from_value(cls, value: "ChannelPolicy | Mapping[str, Any]") -> "ChannelPolicy":
        if isinstance(value, cls):
            return value
        if not isinstance(value, Mapping):
            raise IntakeError("channel_policy_required", "explicit channel policy is required")
        required = value.get("required_packet_ids", value.get("packet_ids", ()))
        allowed = value.get("allowed_packet_ids", ())
        if isinstance(required, str) or isinstance(allowed, str):
            raise IntakeError("invalid_policy", "packet ID collections must be sequences")
        return cls(
            channel_id=value.get("channel_id", value.get("authority_channel_id", "")),
            required_packet_ids=tuple(required or ()),
            allowed_packet_ids=tuple(allowed or ()),
            max_packet_count=value.get("max_packet_count", 64),
            max_packet_bytes=value.get("max_packet_bytes", MAX_BYTES_DEFAULT),
            require_signature=value.get("require_signature", False),
            policy_ref=value.get("policy_ref", ""),
        )

    def as_dict(self) -> dict[str, Any]:
        return {
            "channel_id": self.channel_id,
            "required_packet_ids": list(self.required_packet_ids),
            "allowed_packet_ids": list(self.allowed_packet_ids),
            "max_packet_count": self.max_packet_count,
            "max_packet_bytes": self.max_packet_bytes,
            "require_signature": self.require_signature,
            "policy_ref": self.policy_ref,
        }


def _ensure_regular_parent(path: Path, root: Path) -> None:
    """Reject links and paths outside ``root`` before creating anything.

    ``Path.absolute()`` deliberately preserves ``..`` components.  Comparing
    that result with ``relative_to`` therefore lets ``root / '..' / escape``
    through the lexical check.  Check the normalized absolute boundary first,
    then inspect the original lexical components so a link hidden before a
    ``..`` component (for example ``root / 'link' / '..'``) cannot be skipped.
    Missing directories are created only after both checks have completed.
    """
    root = Path(os.path.abspath(os.fspath(root)))
    current = Path(path).absolute()
    normalized = Path(os.path.abspath(os.fspath(current)))
    try:
        normalized.relative_to(root)
    except ValueError as exc:
        raise IntakeError("path_escape", "adapter-owned path escaped root") from exc

    def reject_existing(component: Path) -> None:
        try:
            info = component.lstat()
        except FileNotFoundError:
            return
        except OSError as exc:
            raise IntakeError("path_check_failed", "could not inspect adapter-owned path component") from exc
        if stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & 0x400):
            raise IntakeError("reparse_path", "adapter-owned path contains a link or reparse point")
        if not stat.S_ISDIR(info.st_mode):
            raise IntakeError("path_not_directory", "adapter-owned path component is not a directory")

    # Inspect the supplied lexical path before normalization.  This catches a
    # symlink/reparse component which could otherwise be hidden by ``..``.
    lexical = Path(current.anchor) if current.anchor else Path.cwd()
    for part in current.parts[1:] if current.is_absolute() else current.parts:
        if part in ("", "."):
            continue
        if part == "..":
            lexical = lexical.parent
            continue
        lexical = lexical / part
        reject_existing(lexical)

    # Walk the normalized in-root path and create only missing components.
    components: list[Path] = []
    component = normalized
    while True:
        components.append(component)
        if component == root:
            break
        parent = component.parent
        if parent == component:
            raise IntakeError("path_escape", "adapter-owned path escaped root")
        component = parent
    for component in reversed(components):
        try:
            info = component.lstat()
        except FileNotFoundError:
            try:
                component.mkdir()
            except FileExistsError:
                # Re-check a race instead of treating an unexpected object as
                # a usable directory.
                reject_existing(component)
                continue
            info = component.lstat()
        except OSError as exc:
            raise IntakeError("path_check_failed", "could not inspect adapter-owned path component") from exc
        if stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & 0x400):
            raise IntakeError("reparse_path", "adapter-owned path contains a link or reparse point")
        if not stat.S_ISDIR(info.st_mode):
            raise IntakeError("path_not_directory", "adapter-owned path component is not a directory")


def _accept_existing_immutable(path: Path, data: bytes) -> None:
    """Accept only a unique regular inode containing exactly ``data``."""
    try:
        info = path.lstat()
    except FileNotFoundError as exc:
        raise IntakeError("immutable_collision", "immutable destination disappeared during install") from exc
    if stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & 0x400):
        raise IntakeError("immutable_collision", "immutable destination is a link or reparse point")
    if not stat.S_ISREG(info.st_mode):
        raise IntakeError("immutable_collision", "immutable destination is not a regular file")
    if getattr(info, "st_nlink", 1) != 1:
        raise IntakeError("immutable_alias", "immutable destination is a hard-link alias")
    try:
        same_bytes = path.read_bytes() == data
    except OSError as exc:
        raise IntakeError("immutable_collision", "immutable destination could not be read") from exc
    if not same_bytes:
        raise IntakeError("immutable_collision", "immutable destination contains different bytes")


def _atomic_create(path: Path, data: bytes, root: Path) -> None:
    """Create immutable bytes atomically, accepting only identical retries."""
    _ensure_regular_parent(path.parent, root)
    if path.exists():
        _accept_existing_immutable(path, data)
        return
    temporary = path.with_name(f".{path.name}.{secrets.token_hex(12)}.tmp")
    try:
        flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0)
        fd = os.open(str(temporary), flags, 0o600)
        try:
            with os.fdopen(fd, "wb", closefd=True) as stream:
                stream.write(data)
                stream.flush()
                os.fsync(stream.fileno())
        except BaseException:
            raise
        try:
            os.link(str(temporary), str(path))
        except FileExistsError:
            _accept_existing_immutable(path, data)
        except OSError as exc:
            # A hard-link publication is used so an existing digest object is
            # never overwritten.  This is the fail-closed fallback on FSes
            # that do not support hard links.
            raise IntakeError("atomic_install_unavailable", "atomic immutable install is unavailable") from exc
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def atomic_quarantine(raw: bytes, root: str | os.PathLike[str], *, kind: str = "packet") -> dict[str, Any]:
    """Atomically preserve exact ``raw`` bytes and return its local locator."""
    if not isinstance(raw, (bytes, bytearray, memoryview)):
        raise IntakeError("raw_bytes_required", "quarantine input must be bytes")
    raw_bytes = bytes(raw)
    base = Path(root).absolute()
    _ensure_regular_parent(base, base)
    quarantine = base / "quarantine"
    _ensure_regular_parent(quarantine, base)
    digest = _sha256(raw_bytes)
    name = f"{digest}.bin"
    target = quarantine / name
    _atomic_create(target, raw_bytes, base)
    return {
        "raw_sha256": digest,
        "raw_size_bytes": len(raw_bytes),
        "quarantine_locator": str(target.relative_to(base).as_posix()),
        "quarantine_transaction_id": f"quarantine-{digest[:24]}",
        "kind": kind,
    }


@dataclass
class AuthorityIntake:
    """Offline local intake adapter with a non-authoritative claim ceiling."""

    spool_root: str | os.PathLike[str]
    channel_identity: ChannelIdentity | Mapping[str, Any] | None = None
    channel_policy: ChannelPolicy | Mapping[str, Any] | None = None
    signature_verifier: Callable[[bytes, Any], bool] | None = None
    max_bytes: int = MAX_BYTES_DEFAULT
    root: Path = field(init=False)
    identity: ChannelIdentity | None = field(init=False, default=None)
    policy: ChannelPolicy | None = field(init=False, default=None)

    def __post_init__(self) -> None:
        if not isinstance(self.max_bytes, int) or isinstance(self.max_bytes, bool) or self.max_bytes < 1:
            raise ValueError("max_bytes must be positive")
        self.root = Path(self.spool_root).absolute()
        _ensure_regular_parent(self.root, self.root)
        (self.root / "quarantine").mkdir(exist_ok=True)
        (self.root / "receipts").mkdir(exist_ok=True)
        self.identity = ChannelIdentity.from_value(self.channel_identity) if self.channel_identity is not None else None
        self.policy = ChannelPolicy.from_value(self.channel_policy) if self.channel_policy is not None else None
        if self.identity is not None and self.policy is not None and self.identity.channel_id != self.policy.channel_id:
            raise IntakeError("channel_identity_policy_mismatch", "identity and policy channel IDs must match")

    def _status(self, *, signature_present: bool, signature_verified: bool = False) -> str:
        if self.identity is None or self.policy is None or not self.identity.real_channel:
            return "typed_absent"
        if not signature_present or not signature_verified:
            return "typed_unverified"
        # A local verifier can inform diagnostics but does not create external
        # authority.  Keep the public status typed_unverified by design.
        return "typed_unverified"

    def _persist_receipt(self, receipt: dict[str, Any]) -> str:
        raw = _canonical({key: value for key, value in receipt.items() if key != "receipt_sha256"})
        receipt["receipt_sha256"] = _sha256(raw)
        path = self.root / "receipts" / f"{receipt['receipt_sha256']}.json"
        _atomic_create(path, _canonical(receipt), self.root)
        return str(path.relative_to(self.root).as_posix())

    def _base_receipt(self, *, raw_meta: dict[str, Any], decision: str, outcome: str,
                      status: str, packet_count: int, packet_set_sha256: str | None,
                      transport_receipt: Any, errors: list[dict[str, Any]]) -> dict[str, Any]:
        if transport_receipt is None:
            # This is a local observation of the spool handoff, not an
            # external transport acknowledgement.  Keeping it explicit avoids
            # the dangerous implication that a missing field means a verified
            # channel.
            transport_receipt = {
                "kind": "local_spool_observation",
                "received_utc": _utc_now(),
                "pid": os.getpid(),
                "network_access": False,
                "external_ack": False,
            }
        return {
            "schema": RECEIPT_SCHEMA_VERSION,
            "receipt_id": f"local-{secrets.token_hex(16)}",
            "received_utc": _utc_now(),
            "pid": os.getpid(),
            "raw_size_bytes": raw_meta["raw_size_bytes"],
            "raw_sha256": raw_meta["raw_sha256"],
            "quarantine_locator": raw_meta["quarantine_locator"],
            "quarantine_transaction_id": raw_meta["quarantine_transaction_id"],
            "packet_count": packet_count,
            "packet_set_sha256": packet_set_sha256,
            "transport_receipt": transport_receipt,
            "channel_identity": self.identity.as_dict() if self.identity else None,
            "channel_policy": self.policy.as_dict() if self.policy else None,
            "decision": decision,
            "outcome": outcome,
            "authority_status": status,
            "external_signature_state": "not_verified",
            "external_channel_ack": None,
            "authority_claim": False,
            "local_bookkeeping_only": True,
            "no_network_or_message_sent": True,
            "errors": errors,
        }

    def _input_bytes(self, raw_or_path: bytes | bytearray | memoryview | str | os.PathLike[str]) -> bytes:
        if isinstance(raw_or_path, (bytes, bytearray, memoryview)):
            raw = bytes(raw_or_path)
        else:
            source = Path(raw_or_path)
            if not source.is_file() or source.is_symlink():
                raise IntakeError("input_not_regular", "input path must be a regular non-link file")
            raw = source.read_bytes()
        return raw

    def receive(self, raw_or_path: bytes | bytearray | memoryview | str | os.PathLike[str], *,
                channel_id: str | None = None, transport_receipt: Any = None,
                packet_id: str | None = None, signature: Any = None) -> dict[str, Any]:
        """Receive one raw packet, preserving bytes before local validation."""
        try:
            raw = self._input_bytes(raw_or_path)
        except IntakeError as error:
            return {"ok": False, "decision": "rejected_all", "authority_status": self._status(signature_present=False),
                    "error": {"code": error.code, "message": error.message, "details": error.details}}
        meta = atomic_quarantine(raw, self.root, kind="packet")
        if len(raw) > self.max_bytes:
            error = IntakeError("oversize", "input exceeds configured maximum bytes", max_bytes=self.max_bytes)
            status = self._status(signature_present=False)
            receipt = self._base_receipt(raw_meta=meta, decision="rejected_all", outcome="quarantined",
                                         status=status, packet_count=1, packet_set_sha256=None,
                                         transport_receipt=transport_receipt,
                                         errors=[{"code": error.code, "message": error.message, "details": error.details}])
            ref = self._persist_receipt(receipt)
            return {"ok": False, "decision": "rejected_all", "authority_status": status,
                    "quarantine": meta, "transport_receipt": ref, "receipt": receipt}
        try:
            packet = _json_loads_unique(raw)
            if not isinstance(packet, Mapping):
                raise IntakeError("packet_object_required", "packet must be a JSON object")
            actual_id = packet_id or packet.get("packet_id") or packet.get("id")
            if actual_id is None:
                raise IntakeError("packet_id_missing", "packet_id is required")
            actual_id = _id(actual_id, "packet_id")
            signature_value = signature if signature is not None else packet.get("signature")
            result = self.receive_packet_set([(actual_id, raw, signature_value)], channel_id=channel_id,
                                             transport_receipt=transport_receipt, _prequarantined=[meta])
            return result
        except IntakeError as error:
            status = self._status(signature_present=False)
            receipt = self._base_receipt(raw_meta=meta, decision="rejected_all", outcome="quarantined",
                                         status=status, packet_count=1, packet_set_sha256=None,
                                         transport_receipt=transport_receipt,
                                         errors=[{"code": error.code, "message": error.message, "details": error.details}])
            ref = self._persist_receipt(receipt)
            return {"ok": False, "decision": "rejected_all", "authority_status": status,
                    "quarantine": meta, "transport_receipt": ref, "receipt": receipt}

    def receive_packet_set(self, packets: Iterable[Any], *, channel_id: str | None = None,
                           transport_receipt: Any = None, request_id: str | None = None,
                           _prequarantined: list[dict[str, Any]] | None = None) -> dict[str, Any]:
        """Atomically decide a packet set: one ``accepted_all`` or rejection.

        Each item may be ``(packet_id, raw_bytes, signature)`` or a mapping
        with ``packet_id``/``raw`` (``bytes`` is also accepted) and optional
        ``signature``.  All raw bytes are quarantined before policy evaluation;
        no accepted/authority object is ever written.
        """
        try:
            items = list(packets)
        except TypeError as exc:
            raise IntakeError("packet_set_required", "packets must be iterable") from exc
        metas: list[dict[str, Any]] = list(_prequarantined or [])
        normalized: list[tuple[str, bytes, Any, dict[str, Any]]] = []
        errors: list[dict[str, Any]] = []
        for index, item in enumerate(items):
            try:
                if isinstance(item, Mapping):
                    packet_id = item.get("packet_id", item.get("id"))
                    raw = item.get("raw", item.get("bytes", item.get("payload")))
                    signature = item.get("signature")
                elif isinstance(item, (tuple, list)) and len(item) in (2, 3):
                    packet_id, raw = item[0], item[1]
                    signature = item[2] if len(item) == 3 else None
                else:
                    raise IntakeError("packet_item_invalid", "packet item must be a mapping or tuple")
                packet_id = _id(packet_id, f"packets[{index}].packet_id")
                if not isinstance(raw, (bytes, bytearray, memoryview)):
                    raise IntakeError("raw_bytes_required", f"packets[{index}] raw bytes are required")
                raw_bytes = bytes(raw)
                meta = next((m for m in metas if m["raw_sha256"] == _sha256(raw_bytes)), None)
                if meta is None:
                    meta = atomic_quarantine(raw_bytes, self.root, kind="packet")
                    metas.append(meta)
                if len(raw_bytes) > self.max_bytes:
                    raise IntakeError("oversize", f"packets[{index}] exceeds configured maximum bytes")
                normalized.append((packet_id, raw_bytes, signature, meta))
            except IntakeError as error:
                errors.append({"index": index, "code": error.code, "message": error.message, "details": error.details})
        raw_set = _canonical([{"packet_id": pid, "raw_sha256": meta["raw_sha256"], "raw_size_bytes": meta["raw_size_bytes"]}
                             for pid, _raw, _sig, meta in normalized])
        set_hash = _sha256(raw_set)
        signature_present = bool(normalized) and all(signature not in (None, "", {}, []) for _pid, _raw, signature, _meta in normalized)
        signature_verified = False
        if self.signature_verifier is not None and signature_present and not errors:
            try:
                signature_verified = all(bool(self.signature_verifier(raw, signature)) for _pid, raw, signature, _meta in normalized)
            except Exception:
                signature_verified = False
        status = self._status(signature_present=signature_present, signature_verified=signature_verified)
        if self.identity is None or self.policy is None:
            errors.append({"code": "channel_configuration_absent", "message": "explicit channel identity and policy are required"})
        elif channel_id is not None and channel_id != self.identity.channel_id:
            errors.append({"code": "channel_identity_mismatch", "message": "request channel does not match configured identity"})
        elif self.identity.channel_id != self.policy.channel_id:
            errors.append({"code": "channel_identity_policy_mismatch", "message": "configured identity and policy do not match"})
        if not normalized:
            errors.append({"code": "packet_set_empty", "message": "packet set must contain at least one packet"})
        if self.policy is not None:
            if len(normalized) > self.policy.max_packet_count:
                errors.append({"code": "packet_count_exceeded", "message": "packet set exceeds policy max_packet_count"})
            ids = [pid for pid, _raw, _sig, _meta in normalized]
            if len(ids) != len(set(ids)):
                errors.append({"code": "packet_id_duplicate", "message": "packet IDs must be unique"})
            if self.policy.required_packet_ids and set(ids) != set(self.policy.required_packet_ids):
                errors.append({"code": "packet_set_membership_mismatch", "message": "packet set does not match required IDs"})
            if self.policy.allowed_packet_ids and any(pid not in self.policy.allowed_packet_ids for pid in ids):
                errors.append({"code": "packet_id_not_allowed", "message": "packet ID is not allowed by policy"})
            if self.policy.require_signature and not signature_present:
                errors.append({"code": "signature_missing", "message": "policy requires a signature for every packet"})
            if self.policy.require_signature and not signature_verified:
                errors.append({"code": "signature_unverified", "message": "signature verifier did not establish verification"})
        decision = "accepted_all" if not errors else "rejected_all"
        outcome = "accepted_local" if decision == "accepted_all" else "quarantined"
        if errors and status == "typed_absent" and not any(e["code"] == "channel_configuration_absent" for e in errors):
            errors.append({"code": "authority_channel_typed_absent", "message": "real external channel is unavailable"})
        receipt_meta = metas[0] if metas else {"raw_sha256": "", "raw_size_bytes": 0, "quarantine_locator": "", "quarantine_transaction_id": ""}
        receipt = self._base_receipt(raw_meta=receipt_meta, decision=decision, outcome=outcome, status=status,
                                     packet_count=len(normalized), packet_set_sha256=set_hash,
                                     transport_receipt=transport_receipt, errors=errors)
        receipt["request_id"] = request_id
        receipt["packet_quarantine"] = metas
        receipt_ref = self._persist_receipt(receipt)
        ack = {
            "schema": ACK_SCHEMA_VERSION,
            "request_id": request_id,
            "decision": decision,
            "packet_count": len(normalized),
            "packet_set_sha256": set_hash,
            "transport_receipt_ref": receipt_ref,
            "authority_status": status,
            "authority_claim": False,
            "local_bookkeeping_only": True,
            "external_ack_sent": False,
            "errors": errors,
        }
        return {"ok": decision == "accepted_all", "decision": decision, "authority_status": status,
                "ack": ack, "receipt": receipt, "receipt_ref": receipt_ref,
                "quarantine": metas, "packet_set_sha256": set_hash}

    # Explicit aliases make the all-or-reject boundary discoverable to callers.
    ack_packet_set = receive_packet_set
    intake_packet_set = receive_packet_set


AuthoritativeIntake = AuthorityIntake


__all__ = [
    "AuthorityIntake", "AuthoritativeIntake", "ChannelIdentity", "ChannelPolicy",
    "IntakeError", "SCHEMA_VERSION", "RECEIPT_SCHEMA_VERSION", "ACK_SCHEMA_VERSION",
    "atomic_quarantine",
]
