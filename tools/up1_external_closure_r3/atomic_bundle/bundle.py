"""Bounded offline atomic response-bundle prototype (R3).

The implementation is intentionally non-authoritative.  It can validate and
replay TEST_ONLY fixtures and exercise the complete local receipt/transaction
chain, but it cannot mint external authority or publish a result.
"""
from __future__ import annotations

import base64
import copy
import datetime as dt
import hashlib
import json
import os
import pathlib
import stat
import tempfile
import uuid
from collections import Counter
from typing import Any

from .canonical import CanonicalError, canonical_bytes, canonical_profile, parse_json_strict

ORDER = ["EHP-01", "EHP-02", "EHP-03", "EHP-04"]
EXCLUSIONS = ["signature", "signature_sha256", "owner_preimage_sha256", "set_signature", "set_preimage_sha256", "review_signature", "review_preimage_sha256", "bundle_canonical_sha256"]
DOMAIN = "UP1.external-handoff.atomic-response-bundle.v1/"
ROLES = ["ehp01_witness", "ehp02_pki_verifier", "ehp03_source_authority", "ehp04_environment_provider"]
_HASH_KEYS = {"signature_sha256", "owner_preimage_sha256", "set_preimage_sha256", "review_preimage_sha256", "receiver_preimage_sha256", "bundle_canonical_sha256"}
ERROR_CODES = frozenset({
    "RAW_INVALID_UTF8", "RAW_DUPLICATE_KEY", "RAW_NONFINITE_NUMBER", "RAW_INVALID_JSON",
    "CANONICAL_NUMBER_UNSUPPORTED", "CANONICAL_VALUE_UNSUPPORTED", "SCHEMA_INVALID",
    "SCHEMA_VALIDATOR_UNAVAILABLE", "CANONICAL_EXCLUSION_NAME_INVALID", "PACKET_ORDER_MISMATCH",
    "PACKET_PAYLOAD_DIGEST_MISMATCH", "PACKET_DIGEST_MISMATCH", "PACKET_SHARED_BINDING_MISMATCH",
    "OWNER_ID_DUPLICATE", "OWNER_ROLE_SCOPE_MISMATCH", "OWNER_PREIMAGE_DIGEST_MISMATCH",
    "SIGNATURE_ALGORITHM_UNSUPPORTED", "SIGNATURE_DIGEST_MISMATCH", "SIGNATURE_VERIFICATION_FAILED",
    "SECURITY_OUTCOME_UNAVAILABLE", "TYPED_VALIDATION_FAILURE", "TEST_ONLY_NON_EVIDENCE",
    "EHP03_CANDIDATE_BINDING_MISMATCH", "EHP03_SOURCE_BINDING_MISMATCH", "EHP03_AXIS_SET_MISMATCH",
    "EHP03_GRAPH_BIJECTION_FAILURE", "EHP03_GRAPH_DIGEST_MISMATCH", "EHP03_GRAPH_REF_MISMATCH",
    "EHP03_G2_MAPPING_MISMATCH", "EHP03_G2_MAPPING_DIGEST_MISMATCH", "EHP03_G2_ROW_DIGEST_MISMATCH",
    "EHP03_G2_REF_MISMATCH", "EHP04_CONTEXT_BINDING_MISMATCH", "EHP04_RUNTIME_SET_MISMATCH",
    "EHP04_RUNTIME_DIGEST_MISMATCH", "EHP04_IDENTITY_MAP_DUPLICATE", "EHP04_SBOM_COMPONENT_DUPLICATE",
    "EHP04_SBOM_EDGE_ENDPOINT_MISSING", "EHP04_SBOM_DIGEST_MISMATCH", "EHP04_SBOM_EDGE_DIGEST_MISMATCH",
    "EHP04_BINARY_BINDING_MISMATCH", "EHP04_BINARY_SBOM_REF_MISMATCH", "EHP04_DOWNLOAD_REF_MISMATCH",
    "EHP04_FIXTURE_CLOSURE_FAILURE", "EHP04_FIXTURE_DECISION_MISMATCH", "SET_BUNDLE_ID_MISMATCH",
    "SET_REQUEST_ID_MISMATCH", "SET_PACKET_DIGESTS_MISMATCH", "SET_SHARED_BINDING_MISMATCH",
    "SET_PREIMAGE_DIGEST_MISMATCH", "BUNDLE_DIGEST_MISMATCH", "REVIEWER_SEPARATION_FAILURE",
    "REVIEW_PREIMAGE_DIGEST_MISMATCH", "REVIEW_PACKET_DIGEST_MISMATCH", "REVIEW_BUNDLE_DIGEST_MISMATCH",
    "REVIEW_SET_RECEIPT_DIGEST_MISMATCH", "DECISION_DISAGREEMENT", "QUARANTINE_RECEIPT_INCOMPLETE",
    "QUARANTINE_RAW_DIGEST_MISMATCH", "QUARANTINE_RAW_SIZE_MISMATCH", "QUARANTINE_LOCATOR_INVALID",
    "QUARANTINE_LOCATOR_MISMATCH", "QUARANTINE_TRANSACTION_MISMATCH", "QUARANTINE_NOT_BEFORE_VERIFY",
    "QUARANTINE_RECEIVER_SIGNATURE_MISSING", "QUARANTINE_RECEIVER_SIGNATURE_INVALID",
    "QUARANTINE_RECEIPT_DIGEST_MISMATCH", "QUARANTINE_RECEIPT_NOT_BOUND", "CAS_ROOT_INVALID",
    "CAS_REPARSE_POINT_REJECTED", "CAS_COLLISION_FAIL_CLOSED", "CAS_HARDLINK_REJECTED", "CAS_INSTALL_UNAVAILABLE",
    "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE", "EHP04_BINARY_ARTIFACT_UNAVAILABLE", "EHP04_FIXTURE_RECEIPT_UNBOUND",
    "EHP04_ARTIFACT_ROOT_REQUIRED", "EHP04_SBOM_ARTIFACT_UNAVAILABLE", "EHP04_SBOM_ARTIFACT_DIGEST_MISMATCH",
    "EHP04_DOWNLOAD_RECEIPT_UNAVAILABLE", "EHP04_DOWNLOAD_RECEIPT_DIGEST_MISMATCH",
    "DECISION_NOT_BOUND_TO_QUARANTINE",
})


def error_registry() -> dict[str, Any]:
    """Return the implementation-owned error registry.

    Consumers must derive documentation/checklists from this function rather
    than maintaining a second hand-written list.  ``ERROR_CODES`` remains a
    frozen compatibility view for existing callers.
    """
    return {
        "schema": "UP1.atomic-bundle.error-registry.r3.v1",
        "source": "tools/up1_external_closure_r3/atomic_bundle/bundle.py:ERROR_CODES",
        "codes": sorted(ERROR_CODES),
        "unknown_code_policy": "preserve_original_and_fail_closed",
        "decisions": ["accepted_all", "rejected_all", "terminal_deferred"],
    }


def validate_error_registry(registry: Any) -> bool:
    """Validate a serialized registry against this implementation's source."""
    return isinstance(registry, dict) and set(registry.get("codes", [])) == set(ERROR_CODES) and registry.get("unknown_code_policy") == "preserve_original_and_fail_closed"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _digest(value: Any) -> str:
    return sha256(canonical_bytes(value))


def _try_digest(value: Any) -> str | None:
    try:
        return _digest(value)
    except (CanonicalError, TypeError, ValueError):
        return None


def _utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def _parse_time(value: Any) -> dt.datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo else None


def _err(errors: list[dict[str, str]], code: str, path: str = "/") -> None:
    # Preserve an unexpected internal code for diagnosis.  Silently replacing
    # it with a generic value made registry drift invisible and could turn a
    # newly introduced predicate into an apparently unrelated failure.  The
    # presence of any error still forces the caller's decision closed.
    errors.append({"code": str(code), "path": path})


def _run_predicate(
    errors: list[dict[str, str]] | None,
    predicate: Any,
    path: str,
) -> list[dict[str, str]]:
    """Run one production predicate with a typed, fail-closed boundary.

    The vector harness and the bundle validator both use the same predicates.
    Predicates append typed errors to a caller-owned list when one is supplied,
    while direct callers receive a fresh list.  A malformed input or an
    unexpected implementation exception is never allowed to escape as an
    apparent success.
    """
    target = errors if isinstance(errors, list) else []
    try:
        predicate(target)
    except (CanonicalError, TypeError, ValueError, AttributeError, KeyError, IndexError):
        _err(target, "TYPED_VALIDATION_FAILURE", path)
    return target


def validate_packet_order(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate the ordered EHP packet identifiers (R02)."""
    def check(out: list[dict[str, str]]) -> None:
        packets = bundle.get("packets") if isinstance(bundle, dict) else None
        if not isinstance(packets, list):
            _err(out, "SCHEMA_INVALID", "/packets")
            return
        ids = [packet.get("packet_id") if isinstance(packet, dict) else None for packet in packets]
        if ids != ORDER:
            _err(out, "PACKET_ORDER_MISMATCH", "/packets")
    return _run_predicate(errors, check, "/packets")


def validate_canonical_exclusions(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate the exact canonical-exclusion set (R03)."""
    def check(out: list[dict[str, str]]) -> None:
        if not isinstance(bundle, dict) or bundle.get("canonical_exclusions") != EXCLUSIONS:
            _err(out, "CANONICAL_EXCLUSION_NAME_INVALID", "/canonical_exclusions")
    return _run_predicate(errors, check, "/canonical_exclusions")


def validate_set_receipt_bundle_id(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate set-receipt binding to the bundle identifier (R04)."""
    def check(out: list[dict[str, str]]) -> None:
        receipt = bundle.get("set_receipt") if isinstance(bundle, dict) else None
        bundle_id = bundle.get("bundle_id") if isinstance(bundle, dict) else None
        if not isinstance(receipt, dict) or receipt.get("bundle_id") != bundle_id:
            _err(out, "SET_BUNDLE_ID_MISMATCH", "/set_receipt/bundle_id")
    return _run_predicate(errors, check, "/set_receipt/bundle_id")


def validate_set_receipt_request_id(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate set-receipt binding to the request identifier (R05)."""
    def check(out: list[dict[str, str]]) -> None:
        receipt = bundle.get("set_receipt") if isinstance(bundle, dict) else None
        request_id = bundle.get("request_id") if isinstance(bundle, dict) else None
        if not isinstance(receipt, dict) or receipt.get("request_id") != request_id:
            _err(out, "SET_REQUEST_ID_MISMATCH", "/set_receipt/request_id")
    return _run_predicate(errors, check, "/set_receipt/request_id")


def validate_set_receipt_packet_digests(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate the set-receipt packet-digest list (R06)."""
    def check(out: list[dict[str, str]]) -> None:
        receipt = bundle.get("set_receipt") if isinstance(bundle, dict) else None
        digests = bundle.get("packet_digests") if isinstance(bundle, dict) else None
        if not isinstance(receipt, dict) or receipt.get("packet_digests") != digests:
            _err(out, "SET_PACKET_DIGESTS_MISMATCH", "/set_receipt/packet_digests")
    return _run_predicate(errors, check, "/set_receipt/packet_digests")


def validate_shared_binding(bundle: Any, errors: list[dict[str, str]] | None = None) -> list[dict[str, str]]:
    """Validate every packet's copy of the top-level shared binding (R07)."""
    def check(out: list[dict[str, str]]) -> None:
        if not isinstance(bundle, dict):
            _err(out, "SCHEMA_INVALID", "/")
            return
        packets, shared = bundle.get("packets"), bundle.get("shared_binding")
        if not isinstance(packets, list) or not isinstance(shared, dict):
            _err(out, "SCHEMA_INVALID", "/shared_binding")
            return
        expected = _digest(shared)
        for i, packet in enumerate(packets):
            if not isinstance(packet, dict) or _digest(packet.get("shared_binding")) != expected:
                _err(out, "PACKET_SHARED_BINDING_MISMATCH", f"/packets/{i}/shared_binding")
    return _run_predicate(errors, check, "/shared_binding")


def validate_security_and_decision(
    bundle: Any,
    context: dict[str, Any] | None = None,
    *,
    fixture_status: str | None = None,
    security_ok: bool | None = None,
    errors: list[dict[str, str]] | None = None,
) -> dict[str, Any]:
    """Derive the bounded security/fixture decision (R24/R25).

    With an explicit context, security is read only from that context, as in
    :func:`validate_bundle`; the wire ``security`` object is never trusted.
    A context-less call is a semantic harness entry and may inspect the
    internal fixture flag, but it still grants no authority or publication
    credit.  Only a clean ``not_executed`` fixture can defer; all other missing
    security outcomes reject.
    """
    out: list[dict[str, str]] = errors if isinstance(errors, list) else []
    ctx_supplied = context is not None
    ctx = context if isinstance(context, dict) else {}
    try:
        if fixture_status is None and isinstance(bundle, dict):
            packets = bundle.get("packets")
            if isinstance(packets, list) and len(packets) == 4 and isinstance(packets[3], dict):
                payload = packets[3].get("payload")
                fixture = payload.get("foreign_owner_fixture") if isinstance(payload, dict) else None
                fixture_status = fixture.get("fixture_status") if isinstance(fixture, dict) else None
        if security_ok is None:
            if ctx_supplied:
                security_ok = ctx.get("security_ok") is True
            else:
                security = bundle.get("security") if isinstance(bundle, dict) else None
                security_ok = isinstance(security, dict) and security.get("security_ok") is True
        if ctx_supplied:
            if ctx.get("public_keys") is not None and ctx.get("trusted_public_keys") is None:
                _err(out, "SECURITY_OUTCOME_UNAVAILABLE", "/security/trusted_public_keys")
            trusted_keys = ctx.get("trusted_public_keys")
            if isinstance(trusted_keys, dict) and any(str(key).startswith("TEST_ONLY") for key in trusted_keys):
                _err(out, "TEST_ONLY_NON_EVIDENCE", "/security/trusted_public_keys")
            for trust_field in ("trust_anchor", "security_profile", "verifier_profile"):
                if str(ctx.get(trust_field, "")).startswith("TEST_ONLY"):
                    _err(out, "TEST_ONLY_NON_EVIDENCE", f"/security/{trust_field}")
        if out:
            decision = "rejected_all"
        elif fixture_status == "not_executed":
            decision = "terminal_deferred"
        elif security_ok is True:
            decision = "accepted_all"
        else:
            _err(out, "SECURITY_OUTCOME_UNAVAILABLE", "/security")
            decision = "rejected_all"
    except (CanonicalError, TypeError, ValueError, AttributeError, KeyError, IndexError):
        _err(out, "TYPED_VALIDATION_FAILURE", "/security")
        decision = "rejected_all"
    return {"errors": out, "fixture_status": fixture_status, "security_ok": bool(security_ok), "decision": decision}


def validate_decision_consistency(
    bundle: Any,
    derived_decision: str | None = None,
    errors: list[dict[str, str]] | None = None,
) -> list[dict[str, str]]:
    """Validate receipt/review decision claims against the derived decision (D01)."""
    def check(out: list[dict[str, str]]) -> None:
        # A missing derived decision is deliberately treated as rejection: an
        # acceptance-shaped claim must never pass without an explicit result.
        decision = derived_decision if derived_decision in {"accepted_all", "rejected_all", "terminal_deferred"} else "rejected_all"
        expected = decision if decision in {"accepted_all", "rejected_all"} else "rejected_all"
        receipt = bundle.get("set_receipt") if isinstance(bundle, dict) else None
        review = bundle.get("independent_review") if isinstance(bundle, dict) else None
        if isinstance(receipt, dict) and receipt.get("decision") not in (None, expected):
            _err(out, "DECISION_DISAGREEMENT", "/set_receipt/decision")
        if isinstance(review, dict) and review.get("derived_decision") not in (None, decision):
            _err(out, "DECISION_DISAGREEMENT", "/independent_review/derived_decision")
    return _run_predicate(errors, check, "/set_receipt/decision")


# Stable private aliases keep the owning predicate names discoverable to
# existing in-package callers while the public ``validate_*`` names are used
# by standalone vector harnesses.
_check_packet_order = validate_packet_order
_check_canonical_exclusions = validate_canonical_exclusions
_check_set_receipt_bundle_id = validate_set_receipt_bundle_id
_check_set_receipt_request_id = validate_set_receipt_request_id
_check_set_receipt_packet_digests = validate_set_receipt_packet_digests
_check_shared_binding = validate_shared_binding
_check_security_and_decision = validate_security_and_decision
_check_decision_consistency = validate_decision_consistency


def _without_top(obj: Any, names: set[str]) -> Any:
    return {k: v for k, v in obj.items() if k not in names} if isinstance(obj, dict) else obj


def bundle_preimage(bundle: dict[str, Any]) -> bytes:
    # Bundle canonical digest excludes all signature material, all preimage
    # digests, and its own digest; payload bytes remain part of the preimage.
    value = copy.deepcopy(bundle)
    value.pop("bundle_canonical_sha256", None)
    # Signature material is excluded only at its contract-defined locations;
    # payload dictionaries are opaque bytes and must never be recursively
    # edited (a payload may legitimately contain a field named signature).
    for packet in value.get("packets", []) if isinstance(value.get("packets"), list) else []:
        if isinstance(packet, dict):
            packet.pop("signature", None)
    if isinstance(value.get("set_receipt"), dict):
        value["set_receipt"].pop("set_signature", None)
    if isinstance(value.get("independent_review"), dict):
        value["independent_review"].pop("review_signature", None)
    return canonical_bytes(value)


def packet_owner_preimage(packet: dict[str, Any]) -> bytes:
    value = copy.deepcopy(packet)
    value.pop("payload_sha256", None)
    value.pop("signature", None)
    return (DOMAIN + "packet-owner\n").encode("ascii") + canonical_bytes(value)


def set_receipt_preimage(bundle: dict[str, Any]) -> bytes:
    receipt = copy.deepcopy(bundle["set_receipt"])
    receipt.pop("set_signature", None)
    # The derived bundle digest is deliberately inserted into the preimage;
    # it is not an extra wire key and therefore cannot weaken schema closure.
    receipt["bundle_canonical_sha256"] = bundle["bundle_canonical_sha256"]
    return (DOMAIN + "set-receipt\n").encode("ascii") + canonical_bytes(receipt)


def review_preimage(bundle: dict[str, Any]) -> bytes:
    review = copy.deepcopy(bundle["independent_review"])
    review.pop("review_signature", None)
    return (DOMAIN + "independent-review\n").encode("ascii") + canonical_bytes(review)


def packet_digest(packet: dict[str, Any]) -> dict[str, str]:
    if not isinstance(packet, dict) or "payload" not in packet:
        raise CanonicalError("SCHEMA_INVALID", "packet payload is required")
    payload_sha = _digest(packet["payload"])
    signature = packet.get("signature", {})
    if not isinstance(signature, dict):
        raise CanonicalError("SCHEMA_INVALID", "packet signature must be an object")
    try:
        signature_sha = _digest(base64.b64decode(signature.get("signature_b64", ""), validate=True)) if signature.get("signature_b64") else ""
    except (ValueError, CanonicalError):
        signature_sha = ""
    return {"packet_id": packet.get("packet_id", ""), "payload_sha256": payload_sha, "owner_signature_sha256": signature_sha}


def _sign(private_key: Any, data: bytes) -> tuple[str, str]:
    raw = private_key.sign(data)
    return base64.b64encode(raw).decode("ascii"), sha256(raw)


def _verify_signature(sig: dict[str, Any], data: bytes, context: dict[str, Any], errors: list[dict[str, str]], path: str) -> None:
    if sig.get("algorithm") != "Ed25519":
        _err(errors, "SIGNATURE_ALGORITHM_UNSUPPORTED", path)
        return
    try:
        raw = base64.b64decode(sig.get("signature_b64", ""), validate=True)
        if sha256(raw) != sig.get("signature_sha256"):
            _err(errors, "SIGNATURE_DIGEST_MISMATCH", path)
        # Public API callers may not select an ambient verifier.  The legacy
        # ``public_keys`` name remains accepted only for direct helper tests;
        # validate_bundle requires the pinned ``trusted_public_keys`` map.
        keys = context.get("trusted_public_keys")
        if keys is None:
            keys = context.get("public_keys", {})
        encoded = keys.get(sig.get("key_id")) if isinstance(keys, dict) else None
        if encoded is None:
            _err(errors, "SECURITY_OUTCOME_UNAVAILABLE", path)
            return
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
        key = Ed25519PublicKey.from_public_bytes(base64.b64decode(encoded, validate=True))
        key.verify(raw, data)
    except Exception:
        _err(errors, "SIGNATURE_VERIFICATION_FAILED", path)


def _receiver_preimage(receipt: dict[str, Any]) -> bytes:
    value = copy.deepcopy(receipt)
    value.pop("receiver_signature", None)
    value.pop("receipt_sha256", None)
    return (DOMAIN + "quarantine-receipt\n").encode("ascii") + canonical_bytes(value)


def _reparse(path: pathlib.Path) -> bool:
    try:
        st = path.lstat()
    except FileNotFoundError:
        return False
    return stat.S_ISLNK(st.st_mode) or bool(getattr(st, "st_file_attributes", 0) & 0x400)


def _windows_handle_link_count(path: pathlib.Path) -> int | None:
    """Return the kernel link count when Windows exposes it, else None.

    ``st_nlink`` is the first line of defence on every platform.  On Windows
    the handle query is retained as a second independent observation because
    some filesystem providers report incomplete POSIX stat information.
    """
    if os.name != "nt":
        return None
    try:
        import ctypes
        from ctypes import wintypes
        class _Info(ctypes.Structure):
            _fields_ = [
                ("file_attributes", wintypes.DWORD), ("creation", wintypes.FILETIME),
                ("access", wintypes.FILETIME), ("write", wintypes.FILETIME),
                ("volume", wintypes.DWORD), ("size_high", wintypes.DWORD),
                ("size_low", wintypes.DWORD), ("links", wintypes.DWORD),
                ("index_high", wintypes.DWORD), ("index_low", wintypes.DWORD),
            ]
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.CreateFileW.restype = wintypes.HANDLE
        handle = kernel.CreateFileW(str(path), 0x80, 0x07, None, 3, 0x02000000, None)
        if handle in (wintypes.HANDLE(-1).value, None):
            return None
        try:
            info = _Info()
            if not kernel.GetFileInformationByHandle(handle, ctypes.byref(info)):
                return None
            return int(info.links)
        finally:
            kernel.CloseHandle(handle)
    except Exception:
        return None


def _link_count(path: pathlib.Path) -> int | None:
    try:
        st = path.stat()
    except OSError:
        return None
    nlink = getattr(st, "st_nlink", None)
    if isinstance(nlink, int) and nlink > 0:
        return nlink
    return _windows_handle_link_count(path)


def _assert_single_link(path: pathlib.Path) -> None:
    """Reject external hardlinks; never treat an unavailable identity as safe."""
    nlink = _link_count(path)
    if nlink is None:
        raise OSError("CAS_INSTALL_UNAVAILABLE")
    if nlink != 1:
        raise OSError("CAS_HARDLINK_REJECTED")


def _safe_mkdir_tree(path: pathlib.Path) -> pathlib.Path:
    """Create a directory tree after checking every existing component.

    The check is deliberately component-wise and precedes each mkdir.  A
    final lstat/resolve pass closes the common 'created then replaced by a
    reparse point' race for this offline prototype.
    """
    path = pathlib.Path(path)
    current = pathlib.Path(path.anchor)
    parts = path.parts[1:] if path.anchor else path.parts
    for part in parts:
        current = current / part
        try:
            st = current.lstat()
        except FileNotFoundError:
            try:
                current.mkdir()
            except FileExistsError:
                pass
            try:
                st = current.lstat()
            except FileNotFoundError as exc:
                raise OSError("CAS_ROOT_INVALID") from exc
        if _reparse(current):
            raise OSError("CAS_REPARSE_POINT_REJECTED")
        if not stat.S_ISDIR(st.st_mode):
            raise OSError("CAS_ROOT_INVALID")
    try:
        resolved = path.resolve(strict=True)
    except OSError as exc:
        raise OSError("CAS_ROOT_INVALID") from exc
    if _reparse(path):
        raise OSError("CAS_REPARSE_POINT_REJECTED")
    return resolved


def _safe_root(root: pathlib.Path) -> pathlib.Path:
    root = pathlib.Path(root.absolute())
    # Do not call mkdir(parents=True): each existing parent must be inspected
    # before any creation and every newly-created component must be rechecked.
    return _safe_mkdir_tree(root)


def _write_durable(path: pathlib.Path, data: bytes, root: pathlib.Path | None = None) -> None:
    path = pathlib.Path(path)
    root_resolved = pathlib.Path(root).resolve(strict=True) if root is not None else None
    parent_resolved = _safe_mkdir_tree(path.parent)
    if root_resolved is not None:
        try:
            if not parent_resolved.is_relative_to(root_resolved):
                raise OSError("CAS_ROOT_INVALID")
        except AttributeError:
            if os.path.commonpath([str(parent_resolved), str(root_resolved)]) != str(root_resolved):
                raise OSError("CAS_ROOT_INVALID")
    if _reparse(path.parent):
        raise OSError("CAS_REPARSE_POINT_REJECTED")
    if _reparse(path):
        raise FileExistsError("CAS_REPARSE_POINT_REJECTED")
    if path.exists():
        _assert_single_link(path)
        if path.is_file() and path.read_bytes() == data:
            return
        raise FileExistsError("CAS_COLLISION_FAIL_CLOSED")
    tmp = path.with_name(f".{path.name}.{uuid.uuid4().hex}.tmp")
    fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_BINARY", 0), 0o600)
    try:
        with os.fdopen(fd, "wb", closefd=True) as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        try:
            os.link(str(tmp), str(path))
        except FileExistsError:
            _assert_single_link(path)
            if path.is_file() and path.read_bytes() == data:
                return
            raise
        except OSError as exc:
            # A failed publication is never silently treated as durable on any
            # platform.  Windows-specific tolerance applies only to directory
            # fsync below, not to the object install itself.
            raise OSError("CAS_INSTALL_UNAVAILABLE") from exc
        # The temporary name and the published CAS name briefly share an
        # inode. Remove the temporary name before accepting identity.
        try:
            tmp.unlink()
        except FileNotFoundError:
            pass
        _assert_single_link(path)
        try:
            dfd = os.open(str(path.parent), os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
            try:
                os.fsync(dfd)
            finally:
                os.close(dfd)
        except OSError as exc:
            # Windows has no portable directory-handle fsync.  The object
            # file itself was flushed before publication; retain the receipt
            # binding while avoiding a false platform failure.
            if os.name != "nt":
                raise OSError("CAS_INSTALL_UNAVAILABLE") from exc
    finally:
        if tmp.exists():
            tmp.unlink()


def quarantine_raw(raw: bytes, root: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    base = pathlib.Path(root) if root is not None else pathlib.Path(tempfile.mkdtemp(prefix="up1-r3-quarantine-"))
    base = _safe_root(base)
    digest = sha256(raw)
    cas = base / "cas" / digest
    _write_durable(cas, raw, base)
    committed = _utc_now()
    receipt = {"schema": "UP1.atomic-bundle.quarantine-receipt.v1", "raw_receipt_id": str(uuid.uuid4()), "raw_object_sha256": digest, "raw_blob_sha256": sha256(cas.read_bytes()), "raw_size_bytes": len(raw), "immutable_locator": str(cas), "cas_transaction_id": "cas-" + digest[:24], "durable_commit_utc": committed, "verification_started_utc": committed, "decision_utc": committed, "receiver_signature": {}, "state": "quarantine_raw"}
    # This is a local TEST_ONLY receiver receipt. It is useful for exercising
    # the signed-receipt path, but it is never an external trust anchor.
    try:
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
        receiver_key = Ed25519PrivateKey.from_private_bytes(bytes(range(1, 33)))
        receiver_preimage = _receiver_preimage(receipt)
        receiver_raw = receiver_key.sign(receiver_preimage)
        receipt["receiver_signature"] = {"key_id": "TEST_ONLY-receiver", "algorithm": "Ed25519", "profile_id": "TEST_ONLY-R3", "signature_b64": base64.b64encode(receiver_raw).decode("ascii"), "signature_sha256": sha256(receiver_raw), "receiver_preimage_sha256": sha256(receiver_preimage)}
    except ImportError:
        receipt["receiver_signature"] = {"key_id": "TEST_ONLY-receiver-unavailable", "algorithm": "Ed25519", "profile_id": "TEST_ONLY-R3", "signature_b64": "", "signature_sha256": "", "receiver_preimage_sha256": ""}
    receipt["receipt_sha256"] = _digest({k: v for k, v in receipt.items() if k != "receipt_sha256"})
    _write_durable(base / "receipts" / (receipt["raw_receipt_id"] + ".json"), canonical_bytes(receipt), base)
    return {"root": str(base.resolve()), "cas_path": str(cas.resolve()), "receipt": receipt, "receipt_sha256": receipt["receipt_sha256"]}


def _schema_errors(bundle: dict[str, Any]) -> list[dict[str, str]]:
    try:
        from jsonschema import Draft202012Validator, FormatChecker, RefResolver
        schema_path = pathlib.Path(__file__).resolve().parents[3] / "docs" / "implementation" / "UP1-EXTERNAL-BLOCKER-CLOSURE-R3" / "04-atomic-contract-repair-r1" / "bundle.schema.json"
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        resolver = RefResolver(schema_path.as_uri(), schema)
        return [{"code": "SCHEMA_INVALID", "path": "/" + "/".join(str(x) for x in e.absolute_path)} for e in Draft202012Validator(schema, resolver=resolver, format_checker=FormatChecker()).iter_errors(bundle)]
    except ImportError:
        return [{"code": "SCHEMA_VALIDATOR_UNAVAILABLE", "path": "/"}]
    except Exception:
        return [{"code": "SCHEMA_INVALID", "path": "/"}]


def _check_quarantine(bundle: dict[str, Any], q: dict[str, Any], errors: list[dict[str, str]], raw: bytes) -> None:
    set_receipt = bundle.get("set_receipt") if isinstance(bundle, dict) else None
    rec = set_receipt.get("quarantine_receipt", {}) if isinstance(set_receipt, dict) else {}
    required = ["raw_receipt_id", "raw_object_sha256", "raw_blob_sha256", "raw_size_bytes", "immutable_locator", "cas_transaction_id", "durable_commit_utc", "verification_started_utc", "decision_utc", "receiver_signature", "state", "receipt_sha256"]
    if not isinstance(rec, dict) or any(k not in rec for k in required):
        _err(errors, "QUARANTINE_RECEIPT_INCOMPLETE", "/set_receipt/quarantine_receipt"); return
    if not rec.get("cas_transaction_id") or not rec.get("receipt_sha256"):
        _err(errors, "DECISION_NOT_BOUND_TO_QUARANTINE", "/set_receipt/decision")
    raw_digest = sha256(raw)
    if rec.get("raw_object_sha256") != raw_digest or rec.get("raw_blob_sha256") != raw_digest:
        _err(errors, "QUARANTINE_RAW_DIGEST_MISMATCH", "/set_receipt/quarantine_receipt")
    if rec.get("raw_size_bytes") != len(raw):
        _err(errors, "QUARANTINE_RAW_SIZE_MISMATCH", "/set_receipt/quarantine_receipt/raw_size_bytes")
    locator = pathlib.Path(rec.get("immutable_locator", ""))
    if rec.get("state") != "quarantine_raw" or not locator.is_absolute():
        _err(errors, "QUARANTINE_LOCATOR_INVALID", "/set_receipt/quarantine_receipt")
    if q:
        expected = q.get("receipt", {})
        # The submitted receipt must be the exact receipt produced by this
        # quarantine transaction; independently repeating only a few claims is
        # insufficient because transaction IDs and receiver signatures are
        # security-bound fields.
        if rec != expected:
            _err(errors, "QUARANTINE_RECEIPT_NOT_BOUND", "/set_receipt/quarantine_receipt")
        if str(locator) != str(pathlib.Path(q.get("cas_path", ""))):
            _err(errors, "QUARANTINE_LOCATOR_MISMATCH", "/set_receipt/quarantine_receipt/immutable_locator")
    try:
        if _reparse(locator) or not locator.is_file() or locator.name != raw_digest:
            _err(errors, "QUARANTINE_LOCATOR_INVALID", "/set_receipt/quarantine_receipt/immutable_locator")
        else:
            try:
                _assert_single_link(locator)
            except OSError as exc:
                _err(errors, str(exc).split(":", 1)[0], "/set_receipt/quarantine_receipt/immutable_locator")
            stored = locator.read_bytes()
            if len(stored) != len(raw) or sha256(stored) != raw_digest:
                _err(errors, "QUARANTINE_RAW_DIGEST_MISMATCH", "/set_receipt/quarantine_receipt")
    except (OSError, ValueError):
        _err(errors, "QUARANTINE_LOCATOR_INVALID", "/set_receipt/quarantine_receipt/immutable_locator")
    if rec.get("cas_transaction_id") != "cas-" + raw_digest[:24]:
        _err(errors, "QUARANTINE_TRANSACTION_MISMATCH", "/set_receipt/quarantine_receipt/cas_transaction_id")
    for a, b in [("durable_commit_utc", "verification_started_utc"), ("verification_started_utc", "decision_utc")]:
        left, right = _parse_time(rec.get(a)), _parse_time(rec.get(b))
        if not left or not right or left > right:
            _err(errors, "QUARANTINE_NOT_BEFORE_VERIFY", "/set_receipt/quarantine_receipt")
    rsig = rec.get("receiver_signature")
    if not isinstance(rsig, dict) or not rsig.get("signature_b64"):
        _err(errors, "QUARANTINE_RECEIVER_SIGNATURE_MISSING", "/set_receipt/quarantine_receipt/receiver_signature")
    else:
        try:
            if rsig.get("key_id") != "TEST_ONLY-receiver" or rsig.get("algorithm") != "Ed25519":
                raise ValueError
            preimage = _receiver_preimage(rec)
            if rsig.get("receiver_preimage_sha256") != sha256(preimage):
                raise ValueError
            raw_sig = base64.b64decode(rsig["signature_b64"], validate=True)
            if rsig.get("signature_sha256") != sha256(raw_sig):
                raise ValueError
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
            receiver_private = bytes(range(1, 33))
            # Derive the pinned public key from the fixed TEST_ONLY private
            # seed; no ambient trust store or caller-supplied key is accepted.
            from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
            pinned = Ed25519PrivateKey.from_private_bytes(receiver_private).public_key()
            pinned.verify(raw_sig, preimage)
            # The pinned receiver is intentionally a local test fixture.  A
            # valid TEST_ONLY signature proves only local plumbing, never an
            # external receiver or authority claim.
            _err(errors, "TEST_ONLY_NON_EVIDENCE", "/set_receipt/quarantine_receipt/receiver_signature")
        except Exception:
            _err(errors, "QUARANTINE_RECEIVER_SIGNATURE_INVALID", "/set_receipt/quarantine_receipt/receiver_signature")
    if rec.get("receipt_sha256") != _digest({k: v for k, v in rec.items() if k != "receipt_sha256"}):
        _err(errors, "QUARANTINE_RECEIPT_DIGEST_MISMATCH", "/set_receipt/quarantine_receipt/receipt_sha256")


def _check_ehp03(payload: Any, shared: dict[str, Any], errors: list[dict[str, str]]) -> None:
    if not isinstance(payload, dict): return
    candidate, source_digest = shared.get("candidate_id"), shared.get("source_identity_sha256")
    source = payload.get("source_identity", {})
    if not isinstance(source, dict):
        _err(errors, "EHP03_SOURCE_BINDING_MISMATCH", "/packets/2/payload/source_identity"); return
    g2 = payload.get("g2_mapping") if isinstance(payload.get("g2_mapping"), dict) else {}
    authority = payload.get("authority_receipt") if isinstance(payload.get("authority_receipt"), dict) else {}
    if source.get("candidate_id") != candidate or g2.get("candidate_id") != candidate or authority.get("candidate_id") != candidate:
        _err(errors, "EHP03_CANDIDATE_BINDING_MISMATCH", "/packets/2/payload")
    if _try_digest(source) != source_digest or authority.get("source_identity_sha256") != source_digest:
        _err(errors, "EHP03_SOURCE_BINDING_MISMATCH", "/packets/2/payload/source_identity")
    for direction in ("forward_edges", "reverse_edges"):
        graph = payload.get("evidence_graph", {})
        edges = graph.get(direction, []) if isinstance(graph, dict) else []
        ids, identities = [], []
        for i, edge in enumerate(edges):
            if not isinstance(edge, dict):
                _err(errors, "EHP03_GRAPH_BIJECTION_FAILURE", f"/packets/2/payload/evidence_graph/{direction}/{i}"); continue
            ids.append(edge.get("edge_id")); identities.append(tuple(edge.get(k) for k in ("from_kind", "from_id", "to_kind", "to_id", "candidate_id", "source_identity_sha256", "namespace", "version", "issued_at")) + (_try_digest(edge.get("issuer_ref")), _try_digest(edge.get("signature_ref"))))
            if edge.get("candidate_id") != candidate or edge.get("source_identity_sha256") != source_digest:
                _err(errors, "EHP03_SOURCE_BINDING_MISMATCH", f"/packets/2/payload/evidence_graph/{direction}/{i}")
            edge_body = {k: v for k, v in edge.items() if k not in {"edge_sha256"}}
            if edge.get("edge_sha256") and _try_digest(edge_body) != edge.get("edge_sha256"):
                _err(errors, "EHP03_GRAPH_DIGEST_MISMATCH", f"/packets/2/payload/evidence_graph/{direction}/{i}/edge_sha256")
        if len(ids) != len(set(ids)) or len(identities) != len(set(identities)):
            _err(errors, "EHP03_GRAPH_BIJECTION_FAILURE", "/packets/2/payload/evidence_graph")
    graph = payload.get("evidence_graph", {})
    fwd = graph.get("forward_edges", []) if isinstance(graph, dict) and isinstance(graph.get("forward_edges", []), list) else []
    rev = graph.get("reverse_edges", []) if isinstance(graph, dict) and isinstance(graph.get("reverse_edges", []), list) else []
    def inv(e: dict[str, Any]) -> tuple[Any, ...]:
        # edge_id and edge_sha256 are directional identities.  Every other
        # field, especially issuer/signature/time authority, must survive the
        # inverse relation check.
        return tuple(e.get(k) for k in ("to_kind", "to_id", "from_kind", "from_id", "candidate_id", "source_identity_sha256", "namespace", "version", "issued_at")) + (_try_digest(e.get("issuer_ref")), _try_digest(e.get("signature_ref")))
    def ident(e: dict[str, Any]) -> tuple[Any, ...]:
        return tuple(e.get(k) for k in ("from_kind", "from_id", "to_kind", "to_id", "candidate_id", "source_identity_sha256", "namespace", "version", "issued_at")) + (_try_digest(e.get("issuer_ref")), _try_digest(e.get("signature_ref")))
    if Counter(ident(x) for x in fwd if isinstance(x, dict)) != Counter(inv(x) for x in rev if isinstance(x, dict)):
        _err(errors, "EHP03_GRAPH_BIJECTION_FAILURE", "/packets/2/payload/evidence_graph")
    if isinstance(graph, dict) and graph.get("graph_sha256"):
        graph_body = {k: v for k, v in graph.items() if k != "graph_sha256"}
        if _try_digest(graph_body) != graph.get("graph_sha256"):
            _err(errors, "EHP03_GRAPH_DIGEST_MISMATCH", "/packets/2/payload/evidence_graph/graph_sha256")
        if isinstance(authority, dict) and authority.get("graph_sha256") != graph.get("graph_sha256"):
            _err(errors, "EHP03_GRAPH_REF_MISMATCH", "/packets/2/payload/authority_receipt/graph_sha256")
    expected_axes = {x.get("axis_id") for x in shared.get("four_axis_refs", [])}
    axes = payload.get("axis_materials", [])
    if len(axes) != 4 or len({x.get("axis_id") for x in axes if isinstance(x, dict)}) != 4 or {x.get("axis_id") for x in axes if isinstance(x, dict)} != expected_axes:
        _err(errors, "EHP03_AXIS_SET_MISMATCH", "/packets/2/payload/axis_materials")
    mapping = g2
    if not isinstance(mapping, dict):
        _err(errors, "EHP03_G2_MAPPING_MISMATCH", "/packets/2/payload/g2_mapping"); return
    if mapping.get("ambiguity_decision") != "none" or not mapping.get("mapping_rows") or not mapping.get("reverse_rows") or mapping.get("candidate_id") != candidate:
        _err(errors, "EHP03_G2_MAPPING_MISMATCH", "/packets/2/payload/g2_mapping")
    rows = mapping.get("mapping_rows", []) if isinstance(mapping.get("mapping_rows", []), list) else []
    reverse = mapping.get("reverse_rows", []) if isinstance(mapping.get("reverse_rows", []), list) else []
    for collection in (rows, reverse):
        for i, row in enumerate(collection):
            if not isinstance(row, dict):
                _err(errors, "EHP03_G2_MAPPING_MISMATCH", "/packets/2/payload/g2_mapping"); continue
            if row.get("row_sha256"):
                row_body = {k: v for k, v in row.items() if k != "row_sha256"}
                if _try_digest(row_body) != row.get("row_sha256"):
                    _err(errors, "EHP03_G2_ROW_DIGEST_MISMATCH", f"/packets/2/payload/g2_mapping/{i}/row_sha256")
    # row_sha256 is intentionally omitted here: forward and reverse rows are
    # directional documents and therefore have different valid digests.  Each
    # digest was independently recomputed above; this comparison binds only
    # the inverse endpoints plus row identity and issuer/time authority.
    def row_identity(row: dict[str, Any], inverse: bool = False) -> tuple[Any, ...]:
        endpoints = (row.get("to_id"), row.get("from_id")) if inverse else (row.get("from_id"), row.get("to_id"))
        return endpoints + (row.get("row_id"), _try_digest(row.get("issuer_ref")), row.get("issued_at"))
    if Counter(row_identity(x) for x in rows if isinstance(x, dict)) != Counter(row_identity(x, True) for x in reverse if isinstance(x, dict)):
        _err(errors, "EHP03_G2_MAPPING_MISMATCH", "/packets/2/payload/g2_mapping")
    if mapping.get("mapping_sha256"):
        mapping_body = {k: v for k, v in mapping.items() if k != "mapping_sha256"}
        if _try_digest(mapping_body) != mapping.get("mapping_sha256"):
            _err(errors, "EHP03_G2_MAPPING_DIGEST_MISMATCH", "/packets/2/payload/g2_mapping/mapping_sha256")
    auth = payload.get("authority_receipt", {})
    if isinstance(auth, dict) and isinstance(mapping.get("issuer_ref"), dict) and mapping.get("issuer_ref") != auth.get("signature_ref"):
        _err(errors, "EHP03_G2_REF_MISMATCH", "/packets/2/payload/g2_mapping/issuer_ref")
    if isinstance(auth, dict):
        authority_signature = auth.get("signature_ref")
        if authority_signature is not None and isinstance(mapping, dict) and mapping.get("issuer_ref") != authority_signature:
            _err(errors, "EHP03_G2_REF_MISMATCH", "/packets/2/payload/g2_mapping/issuer_ref")
        # Graph edges and mapping rows are authority-bearing, not merely
        # topological.  Bind their issuer/signature references to the same
        # authority receipt so a relabeled inverse cannot pass.
        for direction, collection in (("forward_edges", fwd), ("reverse_edges", rev)):
            for i, edge in enumerate(collection):
                if not isinstance(edge, dict):
                    continue
                if authority_signature is not None and (edge.get("issuer_ref") != authority_signature or edge.get("signature_ref") != authority_signature):
                    _err(errors, "EHP03_GRAPH_REF_MISMATCH", f"/packets/2/payload/evidence_graph/{direction}/{i}")
        for direction, collection in (("mapping_rows", rows), ("reverse_rows", reverse)):
            for i, row in enumerate(collection):
                if isinstance(row, dict) and authority_signature is not None and row.get("issuer_ref") != authority_signature:
                    _err(errors, "EHP03_G2_REF_MISMATCH", f"/packets/2/payload/g2_mapping/{direction}/{i}/issuer_ref")


def _artifact_bytes(path_value: Any, artifact_root: pathlib.Path | None = None) -> bytes | None:
    """Read an artifact only when its real bytes are locally present/contained."""
    if not isinstance(path_value, str):
        return None
    # EHP-04 is an evidence boundary: an absolute path without a pinned root
    # is not an acceptable local-material claim.  Requiring the root here,
    # rather than only at the public call site, also protects direct helper
    # callers and keeps every artifact path on the same containment path.
    if artifact_root is None:
        return None
    path = pathlib.Path(path_value)
    if not path.is_absolute():
        return None
    try:
        # Check every existing component, including parents, for links/reparse
        # points before resolving and reading the artifact.
        current = pathlib.Path(path.anchor)
        for part in path.parts[1:]:
            current = current / part
            if _reparse(current):
                return None
        resolved = path.resolve(strict=True)
        root_resolved = artifact_root.resolve(strict=True)
        if not root_resolved.is_dir() or _reparse(root_resolved):
            return None
        if not resolved.is_relative_to(root_resolved):
            return None
        if not resolved.is_file() or _reparse(resolved):
            return None
        return resolved.read_bytes()
    except (OSError, ValueError, AttributeError):
        return None


def _local_material_bytes(material: Any, *, path_keys: tuple[str, ...], hash_keys: tuple[str, ...], artifact_root: pathlib.Path | None) -> tuple[bytes | None, str | None]:
    """Resolve a declared local artifact and return bytes plus its hash key.

    R3 accepts a small compatibility set of field names because the frozen
    contract predates the local-byte hardening.  All variants still require a
    path, a declared SHA-256, a pinned root, and an on-disk recomputation.
    """
    if not isinstance(material, dict):
        return None, None
    path_value = next((material.get(k) for k in path_keys if isinstance(material.get(k), str)), None)
    declared = next((material.get(k) for k in hash_keys if isinstance(material.get(k), str)), None)
    return _artifact_bytes(path_value, artifact_root), declared


def _require_local_material(material: Any, *, path_keys: tuple[str, ...], hash_keys: tuple[str, ...], artifact_root: pathlib.Path | None, errors: list[dict[str, str]], unavailable_code: str, digest_code: str, path: str) -> bytes | None:
    """Require a root-contained byte receipt and compare its declared hash."""
    content, declared = _local_material_bytes(material, path_keys=path_keys, hash_keys=hash_keys, artifact_root=artifact_root)
    if artifact_root is None:
        _err(errors, "EHP04_ARTIFACT_ROOT_REQUIRED", path)
    if content is None or not declared:
        _err(errors, unavailable_code, path)
        return None
    if sha256(content) != declared:
        _err(errors, digest_code, path)
    return content


def _check_ehp04(payload: Any, shared: dict[str, Any], errors: list[dict[str, str]], artifact_root: pathlib.Path | None = None) -> str | None:
    if not isinstance(payload, dict): return None
    # Presence of any EHP-04 material claim pins the whole check to one
    # validated artifact root.  This is intentionally decided before reading
    # a path so a caller cannot obtain a claim-only pass by omitting the root.
    ri_claim = payload.get("runtime_and_imports") if isinstance(payload.get("runtime_and_imports"), dict) else {}
    fixture_claim = payload.get("foreign_owner_fixture") if isinstance(payload.get("foreign_owner_fixture"), dict) else {}
    if artifact_root is None and (ri_claim.get("runtimes") or ri_claim.get("imports") or ri_claim.get("lockfiles") or payload.get("sbom_documents") or payload.get("binaries") or fixture_claim.get("fixture_status") == "executed"):
        _err(errors, "EHP04_ARTIFACT_ROOT_REQUIRED", "/security/artifact_root")
    if payload.get("expected_context_sha256") != shared.get("expected_context_sha256"):
        _err(errors, "EHP04_CONTEXT_BINDING_MISMATCH", "/packets/3/payload/expected_context_sha256")
    outer = payload.get("outer_authority", {})
    if not isinstance(outer, dict): outer = {}
    if (outer.get("candidate_id"), outer.get("source_identity_sha256"), outer.get("expected_context_sha256")) != (shared.get("candidate_id"), shared.get("source_identity_sha256"), shared.get("expected_context_sha256")):
        _err(errors, "EHP04_CONTEXT_BINDING_MISMATCH", "/packets/3/payload/outer_authority")
    ri = payload.get("runtime_and_imports", {})
    if not isinstance(ri, dict): ri = {}
    runtimes = ri.get("runtimes", []) if isinstance(ri.get("runtimes", []), list) else []
    if len(runtimes) != 2 or {x.get("name") for x in runtimes if isinstance(x, dict)} != {"Julia", "Python"}:
        _err(errors, "EHP04_RUNTIME_SET_MISMATCH", "/packets/3/payload/runtime_and_imports/runtimes")
    for i, runtime in enumerate(runtimes):
        if not isinstance(runtime, dict): continue
        content = _artifact_bytes(runtime.get("path"), artifact_root)
        if content is None:
            _err(errors, "EHP04_RUNTIME_ARTIFACT_UNAVAILABLE", f"/packets/3/payload/runtime_and_imports/runtimes/{i}/path")
        elif runtime.get("path_sha256") != sha256(content):
            _err(errors, "EHP04_RUNTIME_DIGEST_MISMATCH", f"/packets/3/payload/runtime_and_imports/runtimes/{i}/path_sha256")
    for field in ("imports", "lockfiles"):
        items = ri.get(field, []); keys = [(x.get("name"), x.get("version"), x.get("locator"), x.get("sha256")) for x in items if isinstance(x, dict)]
        if len(keys) != len(set(keys)): _err(errors, "EHP04_IDENTITY_MAP_DUPLICATE", f"/packets/3/payload/runtime_and_imports/{field}")
        # A locator is metadata unless it is an explicit local path.  When a
        # producer supplies path/local_path/bytes_path, bind the actual bytes
        # too; an absolute locator is treated as the same local-material
        # assertion for backwards-compatible envelopes.
        for i, item in enumerate(items if isinstance(items, list) else []):
            if not isinstance(item, dict):
                continue
            locator = item.get("path") or item.get("local_path") or item.get("bytes_path")
            if not locator and isinstance(item.get("locator"), str) and pathlib.Path(item["locator"]).is_absolute():
                locator = item["locator"]
            if locator:
                _require_local_material(item, path_keys=("path", "local_path", "bytes_path", "locator"), hash_keys=("local_sha256", "bytes_sha256", "sha256"), artifact_root=artifact_root, errors=errors, unavailable_code="EHP04_RUNTIME_ARTIFACT_UNAVAILABLE", digest_code="EHP04_RUNTIME_DIGEST_MISMATCH", path=f"/packets/3/payload/runtime_and_imports/{field}/{i}")
    all_components: set[str] = set()
    for i, sbom in enumerate(payload.get("sbom_documents", [])):
        comps = sbom.get("components", []) if isinstance(sbom, dict) else []
        ids = [x.get("component_id") for x in comps if isinstance(x, dict)]
        if len(ids) != len(set(ids)) or all_components.intersection(ids): _err(errors, "EHP04_SBOM_COMPONENT_DUPLICATE", f"/packets/3/payload/sbom_documents/{i}/components")
        all_components.update(ids)
        for j, edge in enumerate(sbom.get("dependency_edges", []) if isinstance(sbom, dict) else []):
            if not isinstance(edge, dict):
                _err(errors, "EHP04_SBOM_EDGE_ENDPOINT_MISSING", f"/packets/3/payload/sbom_documents/{i}/dependency_edges/{j}"); continue
            if edge.get("from_component_id") not in ids or edge.get("to_component_id") not in ids:
                _err(errors, "EHP04_SBOM_EDGE_ENDPOINT_MISSING", f"/packets/3/payload/sbom_documents/{i}/dependency_edges/{j}")
            if edge.get("edge_sha256"):
                body = {k: v for k, v in edge.items() if k != "edge_sha256"}
                if _try_digest(body) != edge.get("edge_sha256"):
                    _err(errors, "EHP04_SBOM_EDGE_DIGEST_MISMATCH", f"/packets/3/payload/sbom_documents/{i}/dependency_edges/{j}/edge_sha256")
        local_sbom_bytes = _require_local_material(sbom, path_keys=("path", "document_path", "local_path", "bytes_path"), hash_keys=("local_sha256", "bytes_sha256", "document_bytes_sha256", "document_sha256"), artifact_root=artifact_root, errors=errors, unavailable_code="EHP04_SBOM_ARTIFACT_UNAVAILABLE", digest_code="EHP04_SBOM_ARTIFACT_DIGEST_MISMATCH", path=f"/packets/3/payload/sbom_documents/{i}")
        if isinstance(sbom, dict) and sbom.get("document_sha256"):
            # Local transport metadata is not part of the SBOM document
            # preimage.  This keeps the historical canonical-object digest
            # valid while independently checking the local bytes above.
            body = {k: v for k, v in sbom.items() if k not in {"document_sha256", "path", "document_path", "local_path", "bytes_path", "local_sha256", "bytes_sha256", "document_bytes_sha256"}}
            # ``document_sha256`` historically represented the canonical
            # object digest.  R3 additionally permits it to be the declared
            # digest of the local document bytes; either form is checked
            # against bytes, never accepted as a claim-only value.
            semantic_ok = _try_digest(body) == sbom.get("document_sha256")
            byte_hash_ok = local_sbom_bytes is not None and sha256(local_sbom_bytes) == sbom.get("document_sha256")
            if not semantic_ok and not byte_hash_ok:
                _err(errors, "EHP04_SBOM_DIGEST_MISMATCH", f"/packets/3/payload/sbom_documents/{i}/document_sha256")
    for i, binary in enumerate(payload.get("binaries", [])):
        if not isinstance(binary, dict):
            _err(errors, "EHP04_BINARY_BINDING_MISMATCH", f"/packets/3/payload/binaries/{i}"); continue
        download = binary.get("download_receipt") if isinstance(binary.get("download_receipt"), dict) else {}
        if binary.get("candidate_id") != shared.get("candidate_id") or download.get("subject_sha256") != binary.get("sha256"):
            _err(errors, "EHP04_BINARY_BINDING_MISMATCH", f"/packets/3/payload/binaries/{i}")
        binary_bytes = _artifact_bytes(binary.get("path"), artifact_root)
        if binary_bytes is None:
            _err(errors, "EHP04_BINARY_ARTIFACT_UNAVAILABLE", f"/packets/3/payload/binaries/{i}/path")
        elif sha256(binary_bytes) != binary.get("sha256"):
            _err(errors, "EHP04_BINARY_BINDING_MISMATCH", f"/packets/3/payload/binaries/{i}/sha256")
        docs = {x.get("document_id"): x.get("document_sha256") for x in payload.get("sbom_documents", []) if isinstance(x, dict)}
        if not any(isinstance(ref, dict) and docs.get(ref.get("ref")) == ref.get("sha256") for ref in binary.get("sbom_refs", [])):
            _err(errors, "EHP04_BINARY_SBOM_REF_MISMATCH", f"/packets/3/payload/binaries/{i}/sbom_refs")
        receipt_ref = download.get("receipt_ref") if isinstance(download, dict) else {}
        download_material = dict(download) if isinstance(download, dict) else {}
        if isinstance(receipt_ref, dict):
            for key in ("path", "receipt_path", "local_path", "bytes_path", "local_sha256", "bytes_sha256", "receipt_sha256", "sha256"):
                if key in receipt_ref and key not in download_material:
                    download_material[key] = receipt_ref[key]
        receipt_bytes = _require_local_material(download_material, path_keys=("path", "receipt_path", "local_path", "bytes_path"), hash_keys=("local_sha256", "bytes_sha256", "receipt_sha256", "sha256"), artifact_root=artifact_root, errors=errors, unavailable_code="EHP04_DOWNLOAD_RECEIPT_UNAVAILABLE", digest_code="EHP04_DOWNLOAD_RECEIPT_DIGEST_MISMATCH", path=f"/packets/3/payload/binaries/{i}/download_receipt")
        if isinstance(receipt_ref, dict) and receipt_ref.get("sha256"):
            # A root-contained receipt has its own digest.  The legacy
            # claim-only form is rejected above; only its bytes may establish
            # the receipt reference.  If no nested path exists, retain the
            # historical subject binding check for targeted helper tests.
            if receipt_bytes is not None:
                if receipt_ref.get("sha256") != sha256(receipt_bytes):
                    _err(errors, "EHP04_DOWNLOAD_REF_MISMATCH", f"/packets/3/payload/binaries/{i}/download_receipt/receipt_ref")
            elif receipt_ref.get("sha256") != binary.get("sha256"):
                _err(errors, "EHP04_DOWNLOAD_REF_MISMATCH", f"/packets/3/payload/binaries/{i}/download_receipt/receipt_ref")
    fixture = payload.get("foreign_owner_fixture", {})
    status = fixture.get("fixture_status") if isinstance(fixture, dict) else None
    if status == "executed":
        required = ("owner_id", "acl_sha256", "command", "exit_code", "utc", "stdout_sha256", "stderr_sha256", "receipt_sha256")
        if any(k not in fixture for k in required) or fixture.get("exit_code") != 0 or fixture.get("receipt_sha256") != _digest({k: v for k, v in fixture.items() if k != "receipt_sha256"}):
            _err(errors, "EHP04_FIXTURE_CLOSURE_FAILURE", "/packets/3/payload/foreign_owner_fixture")
        stdout = _artifact_bytes(fixture.get("stdout_path"), artifact_root)
        stderr = _artifact_bytes(fixture.get("stderr_path"), artifact_root)
        receipt_bytes = _artifact_bytes(fixture.get("receipt_path"), artifact_root)
        if stdout is None or stderr is None or receipt_bytes is None:
            _err(errors, "EHP04_FIXTURE_RECEIPT_UNBOUND", "/packets/3/payload/foreign_owner_fixture")
        else:
            if sha256(stdout) != fixture.get("stdout_sha256") or sha256(stderr) != fixture.get("stderr_sha256"):
                _err(errors, "EHP04_FIXTURE_CLOSURE_FAILURE", "/packets/3/payload/foreign_owner_fixture")
            try:
                receipt_obj = parse_json_strict(receipt_bytes)
                if not isinstance(receipt_obj, dict) or receipt_obj.get("receipt_sha256") != fixture.get("receipt_sha256"):
                    _err(errors, "EHP04_FIXTURE_RECEIPT_UNBOUND", "/packets/3/payload/foreign_owner_fixture/receipt_path")
            except CanonicalError:
                _err(errors, "EHP04_FIXTURE_RECEIPT_UNBOUND", "/packets/3/payload/foreign_owner_fixture/receipt_path")
    elif status != "not_executed":
        _err(errors, "EHP04_FIXTURE_DECISION_MISMATCH", "/packets/3/payload/foreign_owner_fixture")
    return status


def validate_bundle(raw_utf8: bytes, context: dict[str, Any] | None = None, quarantine_root: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    context = dict(context or {})
    try:
        raw = bytes(raw_utf8)
    except (TypeError, ValueError):
        return _result("", None, {"cas_path": "", "receipt": {}}, [{"code": "RAW_INVALID_JSON", "path": "/"}], None, False)
    raw_digest = sha256(raw)
    errors: list[dict[str, str]] = []
    try:
        q = quarantine_raw(raw, quarantine_root)
    except OSError as exc:
        code = str(exc).split(":", 1)[0]
        if code not in ERROR_CODES:
            code = "CAS_INSTALL_UNAVAILABLE"
        _err(errors, code, "/quarantine")
        # Filesystem identity/durability unavailable is a typed local defer,
        # never an acceptance.  A detected collision/reparse remains a hard
        # rejection because the filesystem supplied contradictory evidence.
        decision = "terminal_deferred" if code == "CAS_INSTALL_UNAVAILABLE" else "rejected_all"
        return _result(raw_digest, None, {"cas_path": "", "receipt": {}}, errors, None, False, decision_override=decision)
    try:
        bundle = parse_json_strict(raw)
    except CanonicalError as exc:
        _err(errors, exc.code); return _result(raw_digest, None, q, errors, None, False)
    if not isinstance(bundle, dict):
        _err(errors, "SCHEMA_INVALID"); return _result(raw_digest, bundle, q, errors, None, False)
    schema_errors = _schema_errors(bundle); errors.extend(schema_errors)
    # Cross-field predicates consume typed mappings/lists only.  Once the
    # Draft-2020-12 shape fails, return a stable typed result and do not let a
    # malformed scalar reach .get(), indexing, or canonicalisation code.
    if schema_errors:
        return _result(raw_digest, bundle, q, errors, None, False)
    validate_canonical_exclusions(bundle, errors)
    packets, digests = bundle.get("packets"), bundle.get("packet_digests")
    validate_packet_order(bundle, errors)
    if not isinstance(digests, list) or [d.get("packet_id") for d in digests if isinstance(d, dict)] != ORDER:
        _err(errors, "PACKET_ORDER_MISMATCH", "/packets")
    else:
        seen_owners: set[str] = set()
        for i, (packet, expected) in enumerate(zip(packets, digests)):
            if not isinstance(packet, dict): continue
            try:
                actual = packet_digest(packet)
            except (CanonicalError, TypeError, ValueError):
                _err(errors, "SCHEMA_INVALID", f"/packets/{i}"); continue
            if packet.get("payload_sha256") != actual["payload_sha256"]: _err(errors, "PACKET_PAYLOAD_DIGEST_MISMATCH", f"/packets/{i}/payload_sha256")
            if expected != actual: _err(errors, "PACKET_DIGEST_MISMATCH", f"/packet_digests/{i}")
            owner = packet.get("owner", {}); sig = packet.get("signature", {})
            if owner.get("owner_id") in seen_owners: _err(errors, "OWNER_ID_DUPLICATE", f"/packets/{i}/owner/owner_id")
            seen_owners.add(owner.get("owner_id"))
            if owner.get("role") != ROLES[i] or sig.get("key_id") != owner.get("owner_id"): _err(errors, "OWNER_ROLE_SCOPE_MISMATCH", f"/packets/{i}")
            try:
                preimage = packet_owner_preimage(packet)
                if sig.get("owner_preimage_sha256") != sha256(preimage): _err(errors, "OWNER_PREIMAGE_DIGEST_MISMATCH", f"/packets/{i}/signature/owner_preimage_sha256")
                _verify_signature(sig, preimage, context, errors, f"/packets/{i}/signature")
            except (CanonicalError, TypeError, ValueError, AttributeError, KeyError):
                _err(errors, "TYPED_VALIDATION_FAILURE", f"/packets/{i}/signature")
            if str(owner.get("owner_id", "")).startswith("TEST_ONLY-") or str(sig.get("profile_id", "")).startswith("TEST_ONLY"):
                _err(errors, "TEST_ONLY_NON_EVIDENCE", f"/packets/{i}")
    shared = bundle.get("shared_binding")
    validate_shared_binding(bundle, errors)
    if isinstance(shared, dict) and isinstance(packets, list):
        if len(packets) == 4:
            _check_ehp03(packets[2].get("payload"), shared, errors)
            artifact_root = None
            if context.get("artifact_root") is not None:
                try:
                    artifact_root = pathlib.Path(context["artifact_root"]).resolve(strict=True)
                except (OSError, ValueError):
                    _err(errors, "EHP04_CONTEXT_BINDING_MISMATCH", "/security/artifact_root")
            fixture_status = _check_ehp04(packets[3].get("payload"), shared, errors, artifact_root)
        else: fixture_status = None
    else: fixture_status = None
    receipt = bundle.get("set_receipt", {})
    validate_set_receipt_bundle_id(bundle, errors)
    validate_set_receipt_request_id(bundle, errors)
    validate_set_receipt_packet_digests(bundle, errors)
    if isinstance(shared, dict) and _digest(receipt.get("shared_binding")) != _digest(shared): _err(errors, "SET_SHARED_BINDING_MISMATCH", "/set_receipt/shared_binding")
    _check_quarantine(bundle, q, errors, raw)
    expected_bundle = sha256(bundle_preimage(bundle))
    if bundle.get("bundle_canonical_sha256") != expected_bundle: _err(errors, "BUNDLE_DIGEST_MISMATCH", "/bundle_canonical_sha256")
    if isinstance(receipt, dict) and receipt.get("set_signature"):
        try:
            sp = set_receipt_preimage(bundle)
            if receipt["set_signature"].get("set_preimage_sha256") != sha256(sp): _err(errors, "SET_PREIMAGE_DIGEST_MISMATCH", "/set_receipt/set_signature/set_preimage_sha256")
            _verify_signature(receipt["set_signature"], sp, context, errors, "/set_receipt/set_signature")
        except (KeyError, CanonicalError):
            _err(errors, "SET_PREIMAGE_DIGEST_MISMATCH", "/set_receipt/set_signature")
    review = bundle.get("independent_review", {})
    owners = {p.get("owner", {}).get("owner_id") for p in packets if isinstance(p, dict)} if isinstance(packets, list) else set()
    forbidden = owners | {receipt.get("channel", {}).get("owner_id"), context.get("verifier_publisher_id")}
    if review.get("reviewer_id") in forbidden: _err(errors, "REVIEWER_SEPARATION_FAILURE", "/independent_review/reviewer_id")
    if isinstance(review, dict) and review.get("review_signature"):
        rp = review_preimage(bundle)
        if review["review_signature"].get("review_preimage_sha256") != sha256(rp): _err(errors, "REVIEW_PREIMAGE_DIGEST_MISMATCH", "/independent_review/review_signature/review_preimage_sha256")
        _verify_signature(review["review_signature"], rp, context, errors, "/independent_review/review_signature")
    computed_packet_digests = [packet_digest(p) for p in packets] if isinstance(packets, list) and len(packets) == 4 and all(isinstance(p, dict) for p in packets) else []
    if review.get("recomputed_packet_digests") != computed_packet_digests: _err(errors, "REVIEW_PACKET_DIGEST_MISMATCH", "/independent_review/recomputed_packet_digests")
    if review.get("recomputed_bundle_sha256") != expected_bundle: _err(errors, "REVIEW_BUNDLE_DIGEST_MISMATCH", "/independent_review/recomputed_bundle_sha256")
    set_digest = _digest({k: v for k, v in receipt.items() if k != "set_signature"}) if isinstance(receipt, dict) else ""
    if review.get("set_receipt_sha256") != set_digest: _err(errors, "REVIEW_SET_RECEIPT_DIGEST_MISMATCH", "/independent_review/set_receipt_sha256")
    security_state = validate_security_and_decision(bundle, context, fixture_status=fixture_status, errors=errors)
    fixture_status = security_state["fixture_status"]
    security_ok = security_state["security_ok"]
    decision = security_state["decision"]
    validate_decision_consistency(bundle, decision, errors)
    # Decision disagreements are themselves malformed/security-bound errors;
    # do not let a previously-derived deferred decision survive them.
    if errors:
        decision = "rejected_all"
    return _result(raw_digest, bundle, q, errors, fixture_status, not bool(schema_errors), decision_override=decision, expected_bundle=expected_bundle, packet_digests=computed_packet_digests)


def _result(raw_digest: str, bundle: Any, q: dict[str, Any], errors: list[dict[str, str]], fixture_status: str | None, schema_ok: bool, decision_override: str | None = None, expected_bundle: str | None = None, packet_digests: list[dict[str, str]] | None = None) -> dict[str, Any]:
    decision = decision_override or ("rejected_all" if errors else "terminal_deferred")
    if errors and decision == "accepted_all":
        decision = "rejected_all"
    return {"schema_ok": schema_ok, "raw_sha256": raw_digest, "bundle_canonical_sha256": expected_bundle or (bundle.get("bundle_canonical_sha256") if isinstance(bundle, dict) else None), "packet_digests": packet_digests or [], "completeness": not bool(errors), "fixture_status": fixture_status, "decision": decision, "failure_codes": sorted({x["code"] for x in errors}), "raw_receipt_refs": [{"ref": q["cas_path"], "sha256": raw_digest}], "quarantine_transaction": q["receipt"].get("cas_transaction_id"), "status": "prototype_pass_limited" if not errors else "fail_limited", "formal_credit": "none", "authority_credit": False, "no_publish": True, "claim_scope": "software_only", "canonical_profile": canonical_profile(), "implementation_status": "prototype_pass_limited"}
