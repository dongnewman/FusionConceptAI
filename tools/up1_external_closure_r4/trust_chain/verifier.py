"""Small fail-closed certificate-chain verifier for UP1 external closure R4.

The implementation is intentionally offline and dependency-light.  It does
not load an operating-system trust store, discover roots, fetch revocation
data, or manufacture a project root.  ``cryptography`` is optional: when it
is absent the result is a typed absence, never a permissive pass.

The public result states are deliberately narrow:

* ``typed_absence`` -- required material or verifier capability is absent;
* ``invalid`` -- supplied bytes, chain, policy, or signature are invalid;
* ``unverified`` -- local cryptographic checks passed, but no authority was
  established.  This state is always ``no_publish``.

``TEST_ONLY`` input is accepted only as a software fixture mode.  It remains
``unverified`` and ``evidence_class=non_evidence`` even when all checks pass.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

try:  # optional by design; no fallback verifier is allowed
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import dsa, ec, ed25519, ed448, padding, rsa
    from cryptography.x509.oid import ExtensionOID

    _CRYPTOGRAPHY_AVAILABLE = True
    _CRYPTOGRAPHY_ERROR: str | None = None
except Exception as exc:  # pragma: no cover - exercised on dependency-free hosts
    _CRYPTOGRAPHY_AVAILABLE = False
    _CRYPTOGRAPHY_ERROR = f"{type(exc).__name__}: {exc}"


SCHEMA = "UP1.external-closure-r4.trust-chain.v1"
ALLOWED_ALGORITHMS = frozenset({"RSA-SHA256", "ECDSA-SHA256", "Ed25519", "Ed448"})
WEAK_HASHES = frozenset({"md2", "md4", "md5", "sha1"})
CRYPTOGRAPHY_AVAILABLE = _CRYPTOGRAPHY_AVAILABLE


class VerificationError(Exception):
    """Internal typed verifier error."""

    def __init__(self, code: str, message: str, *, typed_absence: bool = False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.typed_absence = typed_absence


def canonical_json_bytes(value: Any) -> bytes:
    """Return deterministic UTF-8 bytes for signature/preimage callers."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def hash_raw_bytes(raw: bytes | bytearray | memoryview) -> str:
    """SHA-256 of exactly the supplied bytes (not a parsed/canonical form)."""
    if not isinstance(raw, (bytes, bytearray, memoryview)):
        raise TypeError("raw material must be bytes-like")
    return hashlib.sha256(bytes(raw)).hexdigest()


def certificate_raw_sha256(value: Any) -> str:
    """Hash certificate input bytes before parsing; paths are read verbatim."""
    return hash_raw_bytes(_read_raw(value, label="certificate"))


hash_certificate_raw_bytes = certificate_raw_sha256


def _result(status: str, *, test_only: bool, error_code: str | None = None, message: str | None = None, checks: Mapping[str, Any] | None = None, certificates: Sequence[Mapping[str, Any]] | None = None) -> dict[str, Any]:
    non_evidence = bool(test_only)
    return {
        "schema": SCHEMA,
        "status": status,
        "verification_state": status,
        "error_code": error_code,
        "message": message,
        "resolution": "terminal_deferred" if status == "typed_absence" else "no_publish",
        "no_publish": True,
        "authoritative": False,
        "verified_authority": False,
        "test_only": bool(test_only),
        "non_evidence": non_evidence,
        "evidence_class": "non_evidence" if non_evidence else "none",
        "availability": "unavailable" if error_code == "CRYPTOGRAPHY_UNAVAILABLE" else "available",
        "checks": dict(checks or {}),
        "certificates": list(certificates or []),
    }


def _load_profile(request: Mapping[str, Any]) -> tuple[dict[str, Any], bool]:
    raw = request.get("profile") or {}
    if isinstance(raw, (str, Path)):
        path = Path(raw)
        if not path.exists():
            raise VerificationError("PROFILE_ABSENT", "signature profile is absent", typed_absence=True)
        try:
            raw = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            raise VerificationError("PROFILE_INVALID", f"signature profile cannot be loaded: {exc}") from exc
    if raw is None:
        raw = {}
    if not isinstance(raw, Mapping):
        raise VerificationError("PROFILE_INVALID", "signature profile must be an object")
    profile = dict(raw)
    ident = profile.get("id") or profile.get("profile_id") or profile.get("name")
    test_only = bool(request.get("test_only") or request.get("mode") == "TEST_ONLY" or profile.get("test_only") or (isinstance(ident, str) and ident.startswith("TEST_ONLY")))
    if request.get("test_only") is not None and bool(request["test_only"]) != test_only:
        raise VerificationError("PROFILE_MODE_MISMATCH", "request and profile TEST_ONLY modes disagree")
    if request.get("mode") is not None and request.get("mode") not in {"TEST_ONLY", "PRODUCTION", "UNVERIFIED"}:
        raise VerificationError("PROFILE_INVALID", "mode must be TEST_ONLY, PRODUCTION, or UNVERIFIED")
    allowed = profile.get("allowed_algorithms", profile.get("algorithms"))
    if allowed is None:
        allowed_set = set(ALLOWED_ALGORITHMS)
    elif isinstance(allowed, str):
        allowed_set = {allowed}
    else:
        try:
            allowed_set = set(allowed)
        except TypeError as exc:
            raise VerificationError("ALGORITHM_POLICY_INVALID", "allowed_algorithms must be a string or list") from exc
    if not allowed_set or not allowed_set.issubset(ALLOWED_ALGORITHMS):
        raise VerificationError("ALGORITHM_POLICY_INVALID", "algorithm policy contains unsupported values")
    profile["allowed_algorithms"] = sorted(allowed_set)
    digest = profile.get("digest", "SHA-256")
    if str(digest).upper() != "SHA-256":
        raise VerificationError("ALGORITHM_POLICY_INVALID", "only SHA-256 digest policy is supported")
    profile["digest"] = "SHA-256"
    return profile, test_only


def _read_raw(value: Any, *, label: str) -> bytes:
    if isinstance(value, bytes):
        return value
    if isinstance(value, bytearray):
        return bytes(value)
    if isinstance(value, memoryview):
        return value.tobytes()
    if isinstance(value, Path):
        try:
            return value.read_bytes()
        except OSError as exc:
            raise VerificationError(f"{label.upper()}_ABSENT", f"{label} path cannot be read: {exc}", typed_absence=True) from exc
    if isinstance(value, Mapping):
        declared = value.get("raw_sha256")
        if "raw_b64" in value:
            raw = _decode_b64(value["raw_b64"], f"{label}.raw_b64")
        elif "bytes_b64" in value:
            raw = _decode_b64(value["bytes_b64"], f"{label}.bytes_b64")
        elif "raw_bytes" in value:
            raw = _read_raw(value["raw_bytes"], label=label)
        elif "bytes" in value:
            raw = _read_raw(value["bytes"], label=label)
        elif "pem" in value:
            raw = _read_raw(value["pem"], label=label)
        elif "der" in value:
            raw = _read_raw(value["der"], label=label)
        elif "path" in value or "file" in value:
            raw = _read_raw(value.get("path", value.get("file")), label=label)
        else:
            raise VerificationError(f"{label.upper()}_ABSENT", f"{label} raw bytes are absent", typed_absence=True)
        if declared is not None and str(declared).lower() != hash_raw_bytes(raw):
            raise VerificationError("RAW_HASH_MISMATCH", f"{label} raw byte SHA-256 does not match declaration")
        return raw
    if isinstance(value, str):
        if "-----BEGIN" in value:
            return value.encode("utf-8")
        path = Path(value)
        if path.exists():
            return _read_raw(path, label=label)
        # Certificate text is not silently interpreted as a path or key.
        raise VerificationError(f"{label.upper()}_ABSENT", f"{label} path does not exist", typed_absence=True)
    raise VerificationError(f"{label.upper()}_INVALID", f"unsupported {label} material type")


def _decode_b64(value: Any, label: str) -> bytes:
    if not isinstance(value, str):
        raise VerificationError("ENCODING_INVALID", f"{label} must be base64 text")
    try:
        return base64.b64decode(value, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise VerificationError("ENCODING_INVALID", f"{label} is not valid base64") from exc


def _parse_cert(value: Any, *, label: str) -> tuple[Any, bytes]:
    if not _CRYPTOGRAPHY_AVAILABLE:
        raise VerificationError("CRYPTOGRAPHY_UNAVAILABLE", _CRYPTOGRAPHY_ERROR or "cryptography unavailable", typed_absence=True)
    raw = _read_raw(value, label=label)
    try:
        blocks = re.findall(br"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", raw, flags=re.S)
        if blocks:
            if len(blocks) != 1 or raw.strip() != blocks[0].strip():
                raise ValueError("exactly one certificate PEM block is required")
            cert = x509.load_pem_x509_certificate(blocks[0])
        else:
            cert = x509.load_der_x509_certificate(raw)
    except Exception as exc:
        raise VerificationError("CERTIFICATE_INVALID", f"{label} cannot be parsed: {exc}") from exc
    return cert, raw


def _utc(value: Any) -> datetime:
    if value is None:
        raise VerificationError(
            "EVALUATION_TIME_ABSENT",
            "explicit trusted evaluation time is absent",
            typed_absence=True,
        )
    if isinstance(value, datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise VerificationError("EVALUATION_TIME_INVALID", "evaluation time is not RFC3339") from exc
    else:
        raise VerificationError("EVALUATION_TIME_INVALID", "evaluation time must be RFC3339 text")
    if parsed.tzinfo is None:
        raise VerificationError("EVALUATION_TIME_INVALID", "evaluation time requires timezone")
    return parsed.astimezone(timezone.utc)


def _extension(cert: Any, oid: Any) -> Any | None:
    try:
        return cert.extensions.get_extension_for_oid(oid).value
    except x509.ExtensionNotFound:
        return None


def _cert_algorithm(cert: Any) -> str:
    # Certificate policy is about the algorithm that signed the certificate,
    # not merely the subject public-key type.  OID mapping keeps a RSA-signed
    # leaf with an Ed25519 subject key from being misclassified as Ed25519.
    oid = cert.signature_algorithm_oid.dotted_string
    oid_map = {
        "1.2.840.113549.1.1.11": "RSA-SHA256",
        "1.2.840.113549.1.1.5": "RSA-SHA1",
        "1.2.840.113549.1.1.4": "RSA-MD5",
        "1.2.840.10045.4.3.2": "ECDSA-SHA256",
        "1.2.840.10045.4.1": "ECDSA-SHA1",
        "1.3.101.112": "Ed25519",
        "1.3.101.113": "Ed448",
    }
    if oid in oid_map:
        return oid_map[oid]
    key = cert.public_key()
    if isinstance(key, rsa.RSAPublicKey):
        name = getattr(cert.signature_hash_algorithm, "name", "").lower() if cert.signature_hash_algorithm else ""
        return "RSA-SHA256" if name == "sha256" else f"RSA-{name.upper() or 'UNKNOWN'}"
    if isinstance(key, ec.EllipticCurvePublicKey):
        name = getattr(cert.signature_hash_algorithm, "name", "").lower() if cert.signature_hash_algorithm else ""
        return "ECDSA-SHA256" if name == "sha256" else f"ECDSA-{name.upper() or 'UNKNOWN'}"
    if isinstance(key, ed25519.Ed25519PublicKey):
        return "Ed25519"
    if isinstance(key, ed448.Ed448PublicKey):
        return "Ed448"
    if isinstance(key, dsa.DSAPublicKey):
        name = getattr(cert.signature_hash_algorithm, "name", "").lower() if cert.signature_hash_algorithm else ""
        return f"DSA-{name.upper() or 'UNKNOWN'}"
    return type(key).__name__


def _check_algorithm(cert: Any, profile: Mapping[str, Any], label: str) -> str:
    algorithm = _cert_algorithm(cert)
    if algorithm not in set(profile["allowed_algorithms"]):
        raise VerificationError("ALGORITHM_NOT_ALLOWED", f"{label} uses {algorithm}, outside policy")
    if "SHA1" in algorithm or "MD5" in algorithm or "UNKNOWN" in algorithm:
        raise VerificationError("ALGORITHM_NOT_ALLOWED", f"{label} uses weak or unknown algorithm {algorithm}")
    if isinstance(cert.public_key(), rsa.RSAPublicKey) and cert.public_key().key_size < 2048:
        raise VerificationError("KEY_STRENGTH_INVALID", f"{label} RSA key is below 2048 bits")
    return algorithm


def _validity(cert: Any, when: datetime, label: str) -> None:
    # Do not evaluate the deprecated fallback property on modern versions;
    # ``getattr`` evaluates its default eagerly.
    before = cert.not_valid_before_utc if hasattr(cert, "not_valid_before_utc") else cert.not_valid_before.replace(tzinfo=timezone.utc)
    after = cert.not_valid_after_utc if hasattr(cert, "not_valid_after_utc") else cert.not_valid_after.replace(tzinfo=timezone.utc)
    if when < before or when > after:
        raise VerificationError("CERTIFICATE_EXPIRED", f"{label} is outside validity interval")


def _verify_cert_signature(child: Any, issuer: Any, label: str) -> None:
    key = issuer.public_key()
    try:
        if isinstance(key, rsa.RSAPublicKey):
            key.verify(child.signature, child.tbs_certificate_bytes, padding.PKCS1v15(), child.signature_hash_algorithm)
        elif isinstance(key, ec.EllipticCurvePublicKey):
            key.verify(child.signature, child.tbs_certificate_bytes, ec.ECDSA(child.signature_hash_algorithm))
        elif isinstance(key, (ed25519.Ed25519PublicKey, ed448.Ed448PublicKey)):
            key.verify(child.signature, child.tbs_certificate_bytes)
        elif isinstance(key, dsa.DSAPublicKey):
            key.verify(child.signature, child.tbs_certificate_bytes, child.signature_hash_algorithm)
        else:
            raise TypeError(type(key).__name__)
    except Exception as exc:
        raise VerificationError("CERTIFICATE_SIGNATURE_INVALID", f"{label} certificate signature invalid") from exc


def _check_extensions(cert: Any, *, label: str, leaf: bool) -> None:
    known = {
        ExtensionOID.BASIC_CONSTRAINTS,
        ExtensionOID.KEY_USAGE,
        ExtensionOID.SUBJECT_KEY_IDENTIFIER,
        ExtensionOID.AUTHORITY_KEY_IDENTIFIER,
        ExtensionOID.SUBJECT_ALTERNATIVE_NAME,
        ExtensionOID.NAME_CONSTRAINTS,
        ExtensionOID.CERTIFICATE_POLICIES,
        ExtensionOID.EXTENDED_KEY_USAGE,
        ExtensionOID.CRL_DISTRIBUTION_POINTS,
        ExtensionOID.AUTHORITY_INFORMATION_ACCESS,
    }
    for ext in cert.extensions:
        if ext.critical and ext.oid not in known:
            raise VerificationError("CRITICAL_EXTENSION_UNKNOWN", f"{label} has unknown critical extension {ext.oid.dotted_string}")
    bc = _extension(cert, ExtensionOID.BASIC_CONSTRAINTS)
    if bc is None:
        raise VerificationError("CONSTRAINT_INVALID", f"{label} basicConstraints is absent")
    ku = _extension(cert, ExtensionOID.KEY_USAGE)
    if ku is None:
        raise VerificationError("CONSTRAINT_INVALID", f"{label} keyUsage is absent")
    if leaf:
        if bc.ca or not ku.digital_signature or ku.key_cert_sign:
            raise VerificationError("CONSTRAINT_INVALID", "leaf CA/keyUsage constraints are invalid")
    else:
        if not bc.ca or not ku.key_cert_sign:
            raise VerificationError("CONSTRAINT_INVALID", f"{label} is not authorized to sign certificates")


def _check_link(child: Any, issuer: Any, label: str) -> None:
    if child.issuer != issuer.subject:
        raise VerificationError("CHAIN_ORDER_INVALID", f"{label} issuer does not match previous subject")
    aki = _extension(child, ExtensionOID.AUTHORITY_KEY_IDENTIFIER)
    ski = _extension(issuer, ExtensionOID.SUBJECT_KEY_IDENTIFIER)
    if aki is not None and ski is not None and aki.key_identifier is not None and aki.key_identifier != ski.digest:
        raise VerificationError("CHAIN_LINK_INVALID", f"{label} AKI/SKI linkage mismatch")


def _check_path_lengths(root: Any, intermediates: Sequence[Any]) -> None:
    cas = [root, *intermediates]
    for index, issuer in enumerate(cas):
        bc = _extension(issuer, ExtensionOID.BASIC_CONSTRAINTS)
        if bc is not None and bc.path_length is not None and len(cas) - index - 1 > bc.path_length:
            raise VerificationError("PATH_LENGTH_INVALID", f"CA path length exceeded at {index}")


def _key_from(value: Any) -> Any:
    if hasattr(value, "verify"):
        return value
    raw = _read_raw(value, label="public_key")
    try:
        return serialization.load_pem_public_key(raw)
    except Exception:
        try:
            return serialization.load_der_public_key(raw)
        except Exception as exc:
            raise VerificationError("PUBLIC_KEY_INVALID", "public key cannot be parsed") from exc


def verify_signature_result(data: bytes, signature: bytes | str | None = None, public_key: Any = None, algorithm: str = "", *, signature_b64: str | None = None) -> dict[str, Any]:
    """Verify one detached signature without consulting any trust store.

    ``verified`` means only that the supplied key verified the supplied bytes;
    it does not establish key ownership or authority.  Invalid and missing
    crypto capability are returned as typed states for callers that need the
    reason.
    """
    try:
        if not _CRYPTOGRAPHY_AVAILABLE:
            raise VerificationError("CRYPTOGRAPHY_UNAVAILABLE", _CRYPTOGRAPHY_ERROR or "cryptography unavailable", typed_absence=True)
        if signature is None:
            signature = signature_b64
        if signature in (None, "", b""):
            raise VerificationError("SIGNATURE_ABSENT", "signature bytes are absent", typed_absence=True)
        if not isinstance(data, bytes):
            raise VerificationError("SIGNATURE_INPUT_INVALID", "signature data must be bytes")
        if algorithm not in ALLOWED_ALGORITHMS:
            raise VerificationError("ALGORITHM_NOT_ALLOWED", f"unsupported signature algorithm {algorithm}")
        sig = _decode_b64(signature, "signature") if isinstance(signature, str) else bytes(signature)
        key = _key_from(public_key)
        if algorithm == "RSA-SHA256" and isinstance(key, rsa.RSAPublicKey):
            key.verify(sig, data, padding.PKCS1v15(), hashes.SHA256())
        elif algorithm == "ECDSA-SHA256" and isinstance(key, ec.EllipticCurvePublicKey):
            key.verify(sig, data, ec.ECDSA(hashes.SHA256()))
        elif algorithm == "Ed25519" and isinstance(key, ed25519.Ed25519PublicKey):
            key.verify(sig, data)
        elif algorithm == "Ed448" and isinstance(key, ed448.Ed448PublicKey):
            key.verify(sig, data)
        else:
            raise VerificationError("SIGNATURE_KEY_ALGORITHM_MISMATCH", "public key type does not match algorithm")
        return {"status": "unverified", "verified": True, "authoritative": False, "error_code": None}
    except VerificationError as exc:
        return {"status": "typed_absence" if exc.typed_absence else "invalid", "verified": False, "authoritative": False, "availability": "unavailable" if exc.code == "CRYPTOGRAPHY_UNAVAILABLE" else "available", "error_code": exc.code, "message": exc.message}
    except Exception:
        return {"status": "invalid", "verified": False, "authoritative": False, "error_code": "SIGNATURE_INVALID", "message": "detached signature verification failed"}


def verify_signature(data: bytes, signature: bytes | str | None = None, public_key: Any = None, algorithm: str = "", *, signature_b64: str | None = None) -> bool:
    """Boolean convenience interface; false is fail-closed for every error."""
    return bool(verify_signature_result(data, signature, public_key, algorithm, signature_b64=signature_b64).get("verified"))


def _normalise_chain(request: Mapping[str, Any]) -> tuple[Any, list[Any], Any]:
    root = request.get("root", request.get("trust_root"))
    leaf = request.get("leaf")
    chain = request.get("chain", request.get("certificates"))
    if leaf is None:
        if chain is not None and not isinstance(chain, (str, bytes, Path, Mapping)):
            values = list(chain)
            if len(values) < 2:
                raise VerificationError("CHAIN_ABSENT", "certificate chain requires root and leaf", typed_absence=True)
            # A complete ordered chain is root -> intermediates -> leaf.
            # In this form the first item is the caller-supplied root.
            root = values[0] if root is None else root
            leaf = values[-1]
            return root, values[1:-1], leaf
        if root is None:
            raise VerificationError("ROOT_ABSENT", "caller-pinned trust root is absent", typed_absence=True)
        raise VerificationError("LEAF_ABSENT", "leaf certificate is absent", typed_absence=True)
    if root is None:
        raise VerificationError("ROOT_ABSENT", "caller-pinned trust root is absent", typed_absence=True)
    inters = request.get("intermediates", request.get("intermediate", []))
    if inters is None:
        inters = []
    if isinstance(inters, (str, bytes, Path, Mapping)):
        inters = [inters]
    if not isinstance(inters, Sequence):
        raise VerificationError("CHAIN_INVALID", "intermediates must be a sequence")
    return root, list(inters), leaf


def verify_request(request: Mapping[str, Any]) -> dict[str, Any]:
    """Verify a caller-supplied chain and return a JSON-serialisable result."""
    if not isinstance(request, Mapping):
        return _result("invalid", test_only=False, error_code="REQUEST_INVALID", message="request must be an object")
    test_only = bool(request.get("test_only") or request.get("mode") == "TEST_ONLY")
    try:
        profile, test_only = _load_profile(request)
        evaluation = _utc(request.get("evaluation_time"))
        root_value, intermediate_values, leaf_value = _normalise_chain(request)
        root, root_raw = _parse_cert(root_value, label="root")
        inters: list[Any] = []
        records: list[dict[str, Any]] = [{"role": "root", "raw_sha256": hash_raw_bytes(root_raw), "der_sha256": hash_raw_bytes(root.public_bytes(serialization.Encoding.DER)), "subject": root.subject.rfc4514_string()}]
        anchor = profile.get("trust_anchor")
        anchor_hash = anchor.get("raw_sha256", anchor.get("sha256")) if isinstance(anchor, Mapping) else None
        declared_root_hash = (profile.get("root_sha256", profile.get("trust_root_sha256"))
                              or request.get("root_sha256") or request.get("trust_root_sha256")
                              or anchor_hash)
        # A production-shaped request must pin the exact root bytes supplied
        # by its caller. TEST_ONLY is the only exception: it exercises local
        # parser/crypto behavior and cannot establish authority.
        if not test_only and declared_root_hash is None:
            raise VerificationError("ROOT_HASH_ABSENT", "caller-pinned root raw SHA-256 is absent", typed_absence=True)
        if declared_root_hash is not None and str(declared_root_hash).lower() != records[0]["raw_sha256"]:
            raise VerificationError("ROOT_HASH_MISMATCH", "root raw byte SHA-256 differs from caller pin")
        if root.issuer != root.subject:
            raise VerificationError("CHAIN_ORDER_INVALID", "trust root is not self-issued")
        _check_algorithm(root, profile, "root")
        _validity(root, evaluation, "root")
        _check_extensions(root, label="root", leaf=False)
        _verify_cert_signature(root, root, "root")
        previous = root
        for index, value in enumerate(intermediate_values):
            cert, raw = _parse_cert(value, label=f"intermediate[{index}]")
            _check_link(cert, previous, f"intermediate[{index}]")
            _check_algorithm(cert, profile, f"intermediate[{index}]")
            _validity(cert, evaluation, f"intermediate[{index}]")
            _check_extensions(cert, label=f"intermediate[{index}]", leaf=False)
            _verify_cert_signature(cert, previous, f"intermediate[{index}]")
            inters.append(cert)
            records.append({"role": "intermediate", "index": index, "raw_sha256": hash_raw_bytes(raw), "der_sha256": hash_raw_bytes(cert.public_bytes(serialization.Encoding.DER)), "subject": cert.subject.rfc4514_string()})
            previous = cert
        leaf, leaf_raw = _parse_cert(leaf_value, label="leaf")
        _check_link(leaf, previous, "leaf")
        _check_algorithm(leaf, profile, "leaf")
        _validity(leaf, evaluation, "leaf")
        _check_extensions(leaf, label="leaf", leaf=True)
        _verify_cert_signature(leaf, previous, "leaf")
        records.append({"role": "leaf", "raw_sha256": hash_raw_bytes(leaf_raw), "der_sha256": hash_raw_bytes(leaf.public_bytes(serialization.Encoding.DER)), "subject": leaf.subject.rfc4514_string()})
        _check_path_lengths(root, inters)
        sig_info: dict[str, Any] | None = None
        signature = request.get("signature")
        if signature is not None:
            if not isinstance(signature, Mapping):
                raise VerificationError("SIGNATURE_INVALID", "signature must be an object")
            algorithm = signature.get("algorithm")
            if algorithm not in profile["allowed_algorithms"]:
                raise VerificationError("ALGORITHM_NOT_ALLOWED", "detached signature algorithm is outside policy")
            sig_value = signature.get("signature_b64", signature.get("signature"))
            if sig_value in (None, ""):
                raise VerificationError("SIGNATURE_ABSENT", "detached signature bytes are absent", typed_absence=True)
            data = request.get("payload", request.get("signed_bytes", b""))
            if isinstance(data, str):
                data = data.encode("utf-8")
            if not isinstance(data, bytes):
                raise VerificationError("SIGNATURE_INPUT_INVALID", "signed payload must be bytes or UTF-8 text")
            detached = verify_signature_result(data=data, signature=sig_value, public_key=leaf.public_key(), algorithm=str(algorithm))
            if not detached.get("verified"):
                raise VerificationError(str(detached.get("error_code") or "SIGNATURE_INVALID"), str(detached.get("message") or "detached signature invalid"))
            sig_info = {"algorithm": algorithm, "verified": True, "payload_sha256": hash_raw_bytes(data)}
        checks = {"root_hash": True, "raw_bytes_hashed": True, "chain_order": True, "certificate_signatures": True, "constraints": True, "algorithm_policy": True, "detached_signature": sig_info is None or sig_info.get("verified", False)}
        if test_only:
            checks["test_only_non_evidence"] = True
        result = _result("unverified", test_only=test_only, checks=checks, certificates=records)
        result["cryptographic_valid"] = True
        result["root_raw_sha256"] = records[0]["raw_sha256"]
        result["certificate_raw_sha256"] = [item["raw_sha256"] for item in records]
        result["authority"] = {"status": "unverified", "authoritative": False, "reason": "no external authority input"}
        result["signature"] = sig_info
        result["reason"] = "local cryptographic chain checks passed; external authority is not established"
        return result
    except VerificationError as exc:
        return _result("typed_absence" if exc.typed_absence else "invalid", test_only=test_only, error_code=exc.code, message=exc.message)
    except Exception as exc:  # parser/runtime surprises remain fail-closed
        return _result("invalid", test_only=test_only, error_code="VERIFIER_ERROR", message=f"unexpected verifier error: {type(exc).__name__}")


def verify_chain(*, root: Any = None, leaf: Any = None, intermediates: Any = None, chain: Any = None, profile: Any = None, signature: Any = None, payload: Any = None, **kwargs: Any) -> dict[str, Any]:
    """Keyword convenience API for callers that already have chain material."""
    request: dict[str, Any] = {"root": root, "leaf": leaf, "profile": profile}
    if intermediates is not None:
        request["intermediates"] = intermediates
    if chain is not None:
        request["chain"] = chain
    if signature is not None:
        request["signature"] = signature
    if payload is not None:
        request["payload"] = payload
    request.update(kwargs)
    return verify_request(request)


verify_certificate_chain = verify_chain


def result_exit_code(result: Mapping[str, Any]) -> int:
    return {"unverified": 0, "typed_absence": 2, "invalid": 3}.get(str(result.get("status")), 5)
