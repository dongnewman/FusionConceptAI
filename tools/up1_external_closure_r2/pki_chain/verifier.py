"""Fail-closed X.509/receipt verifier for the UP1 external closure boundary.

This is intentionally a small, dependency-light verifier.  It validates the
certificate path and the signed receipt locally; it never consults a system
trust store, network endpoint, or OS trust decision.  A production profile
without an externally supplied trust anchor/time/revocation input is reported
as typed absence and cannot publish.
"""

from __future__ import annotations

import base64
import binascii
import hashlib
import ipaddress
import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec, ed25519, ed448, padding, rsa, dsa
    from cryptography.x509.oid import ExtensionOID, ExtendedKeyUsageOID, NameOID, ObjectIdentifier
    _CRYPTOGRAPHY_AVAILABLE = True
    _CRYPTOGRAPHY_ERROR = None
except Exception as exc:  # pragma: no cover - exercised on installations without cryptography
    _CRYPTOGRAPHY_AVAILABLE = False
    _CRYPTOGRAPHY_ERROR = f"{type(exc).__name__}: {exc}"


SCHEMA = "UP1-EXTERNAL-CLOSURE-R2.pki-chain-result.v1"
TEST_EKU = "1.3.6.1.4.1.55555.1.1"
TEST_POLICY = "1.3.6.1.4.1.55555.1.2"
KNOWN_CRITICAL_EXTENSIONS = {
    ExtensionOID.BASIC_CONSTRAINTS,
    ExtensionOID.KEY_USAGE,
    ExtensionOID.SUBJECT_KEY_IDENTIFIER,
    ExtensionOID.AUTHORITY_KEY_IDENTIFIER,
    ExtensionOID.SUBJECT_ALTERNATIVE_NAME,
    ExtensionOID.ISSUER_ALTERNATIVE_NAME,
    ExtensionOID.NAME_CONSTRAINTS,
    ExtensionOID.CERTIFICATE_POLICIES,
    ExtensionOID.EXTENDED_KEY_USAGE,
    ExtensionOID.CRL_DISTRIBUTION_POINTS,
    ExtensionOID.AUTHORITY_INFORMATION_ACCESS,
    ExtensionOID.SUBJECT_INFORMATION_ACCESS,
}

RECEIPT_FIELDS = frozenset({"scope", "source_version", "verification_id", "nonce", "challenge", "sequence", "issued_at", "expires_at", "idempotency_key", "signer_key_id", "receipt_digest_sha256", "signature", "algorithm", "signature_algorithm"})
PROFILE_FIELDS = frozenset({"id", "profile_id", "state", "test_only", "digest", "algorithm", "signature_algorithm", "public_key_bits", "signature_encoding", "eku_oid", "extended_key_usage_oid", "policy_oid", "trust_anchor", "authorized_scope", "scope", "production_profile"})
TRUST_ANCHOR_FIELDS = frozenset({"fingerprint_sha256", "sha256", "source_channel", "authorized_scope", "effective_at", "not_after", "rotation_policy", "revocation_policy"})
REVOCATION_FIELDS = frozenset({"status", "verified", "issuer", "serial", "this_update", "next_update", "produced_at", "responder", "response_sha256"})
TRUSTED_TIME_FIELDS = frozenset({"verified", "message_imprint_sha256", "gen_time", "policy", "nonce", "tsa_chain", "revocation"})
LEDGER_FIELDS = frozenset({"consumed_nonces", "last_sequence", "idempotency"})
ALLOWED_ALGORITHMS = frozenset({"RSA", "ECDSA", "Ed25519", "Ed448"})


class VerificationError(Exception):
    def __init__(self, code: str, message: str, stage: str, *, typed_absence: bool = False):
        super().__init__(message)
        self.code = code
        self.message = message
        self.stage = stage
        self.typed_absence = typed_absence


def canonical_json_bytes(value: Any) -> bytes:
    """Return the contract's deterministic UTF-8 JSON representation."""
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise VerificationError("canonical_bytes_mismatch", f"duplicate JSON key: {key}", "canonical_schema_profile")
        result[key] = value
    return result


def _check_allowed(value: Mapping[str, Any], allowed: frozenset[str], label: str) -> None:
    unknown = sorted(set(value) - allowed)
    if unknown:
        raise VerificationError("canonical_bytes_mismatch", f"unknown {label} field(s): {','.join(unknown)}", "canonical_schema_profile")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _evaluation_time(request: Mapping[str, Any], test_only: bool) -> datetime:
    value = request.get("evaluation_time")
    if value is None:
        return _now()
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            raise ValueError("evaluation_time must include timezone")
        return parsed.astimezone(timezone.utc)
    except Exception as exc:
        raise VerificationError("trusted_time_absent", f"invalid evaluation time: {exc}", "trusted_time", typed_absence=not test_only) from exc


def _parse_utc(value: Any, field: str) -> datetime:
    if not isinstance(value, str) or not value:
        raise VerificationError("timestamp_invalid", f"{field} must be RFC3339 UTC text", "trusted_time")
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise VerificationError("timestamp_invalid", f"{field} is not RFC3339: {exc}", "trusted_time") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timedelta(0):
        raise VerificationError("timestamp_invalid", f"{field} must carry UTC offset", "trusted_time")
    return parsed.astimezone(timezone.utc)


def _load_json(value: Any) -> Any:
    if isinstance(value, Mapping):
        return value
    if isinstance(value, (str, Path)):
        path = Path(value)
        if not path.exists():
            raise VerificationError("verifier_absent", f"JSON input does not exist: {path}", "canonical_schema_profile", typed_absence=True)
        try:
            return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=_reject_duplicate_pairs)
        except VerificationError:
            raise
        except json.JSONDecodeError as exc:
            raise VerificationError("canonical_bytes_mismatch", f"invalid JSON: {exc}", "canonical_schema_profile") from exc
    raise TypeError("expected a mapping or JSON path")


def _read_bytes(value: Any) -> bytes:
    if isinstance(value, bytes):
        return value
    if isinstance(value, Path):
        return value.read_bytes()
    if isinstance(value, str):
        if "-----BEGIN" in value:
            return value.encode("utf-8")
        p = Path(value)
        try:
            return p.read_bytes() if p.exists() else value.encode("utf-8")
        except OSError:
            return value.encode("utf-8")
    raise TypeError("expected bytes, text or path")


def _read_pem_certs(value: Any) -> list[Any]:
    raw = _read_bytes(value)
    blocks = re.findall(br"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", raw, flags=re.S)
    if not blocks:
        try:
            return [x509.load_der_x509_certificate(raw)]
        except Exception as exc:
            raise VerificationError("certificate_chain_absent", f"certificate parse failed: {exc}", "trust_anchor_load") from exc
    result = []
    for block in blocks:
        try:
            result.append(x509.load_pem_x509_certificate(block))
        except Exception as exc:
            raise VerificationError("certificate_chain_absent", f"certificate parse failed: {exc}", "trust_anchor_load") from exc
    return result


def _material_present(value: Any) -> bool:
    return not isinstance(value, (str, Path)) or (isinstance(value, str) and "-----BEGIN" in value) or Path(value).exists()


def _b64(value: Any, field: str) -> bytes:
    if isinstance(value, bytes):
        return value
    if not isinstance(value, str):
        raise VerificationError("signature_profile_unknown", f"{field} must be base64 text", "receipt_signature")
    try:
        return base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as exc:
        raise VerificationError("signature_profile_unknown", f"{field} is not valid base64", "receipt_signature") from exc


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _name_text(name: Any) -> str:
    return ",".join(f"{a.oid.dotted_string}={a.value}" for a in name)


def _extension(cert: Any, oid: Any, required: bool = False) -> Any:
    try:
        return cert.extensions.get_extension_for_oid(oid).value
    except x509.ExtensionNotFound:
        if required:
            raise VerificationError("critical_extension_unknown", f"missing extension {oid.dotted_string}", "path_build_and_certificate_constraints")
        return None


def _verify_signature(cert: Any, issuer: Any, label: str) -> None:
    try:
        key = issuer.public_key()
        sig = cert.signature
        data = cert.tbs_certificate_bytes
        algorithm = cert.signature_hash_algorithm
        if isinstance(key, rsa.RSAPublicKey):
            key.verify(sig, data, padding.PKCS1v15(), algorithm)
        elif isinstance(key, ec.EllipticCurvePublicKey):
            key.verify(sig, data, ec.ECDSA(algorithm))
        elif isinstance(key, (ed25519.Ed25519PublicKey, ed448.Ed448PublicKey)):
            key.verify(sig, data)
        elif isinstance(key, dsa.DSAPublicKey):
            key.verify(sig, data, algorithm)
        else:
            raise ValueError(f"unsupported issuer key {type(key).__name__}")
    except Exception as exc:
        raise VerificationError("certificate_signature_invalid", f"{label} certificate signature invalid: {exc}", "path_build_and_certificate_constraints") from exc


def _public_key_info(cert: Any) -> tuple[str, int | None]:
    key = cert.public_key()
    if isinstance(key, ed25519.Ed25519PublicKey):
        return "Ed25519", 256
    if isinstance(key, ed448.Ed448PublicKey):
        return "Ed448", 456
    if isinstance(key, rsa.RSAPublicKey):
        return "RSA", key.key_size
    if isinstance(key, ec.EllipticCurvePublicKey):
        return f"ECDSA-{key.curve.name}", key.key_size
    if isinstance(key, dsa.DSAPublicKey):
        return "DSA", key.key_size
    return type(key).__name__, None


def _profile(request: Mapping[str, Any]) -> tuple[dict[str, Any], bool]:
    raw = request.get("profile")
    if raw is None:
        raise VerificationError("signature_profile_unknown", "versioned profile is required", "canonical_schema_profile", typed_absence=True)
    profile = dict(_load_json(raw) if not isinstance(raw, Mapping) else raw)
    _check_allowed(profile, PROFILE_FIELDS, "profile")
    # Accept the contract's nested production profile while retaining all
    # trust-anchor metadata at the outer profile object.
    nested = profile.get("production_profile")
    if isinstance(nested, Mapping):
        _check_allowed(nested, PROFILE_FIELDS, "production_profile")
        profile = {**dict(nested), **profile}
    ident = profile.get("id") or profile.get("profile_id")
    profile_test_only = bool(profile.get("test_only") or (isinstance(ident, str) and ident.startswith("TEST_ONLY-")))
    if "test_only" in request and bool(request["test_only"]) != profile_test_only:
        raise VerificationError("signature_profile_unknown", "caller mode and profile TEST_ONLY mode disagree", "canonical_schema_profile")
    test_only = profile_test_only
    if test_only:
        if ident != "TEST_ONLY-W2-R1":
            raise VerificationError("signature_profile_unknown", "unknown TEST_ONLY profile", "canonical_schema_profile")
        expected = {"digest": "SHA-256", "signature_algorithm": "Ed25519", "public_key_bits": 256, "signature_encoding": "raw_64_bytes", "eku_oid": TEST_EKU, "policy_oid": TEST_POLICY}
        for key, val in expected.items():
            if profile.get(key) != val:
                raise VerificationError("signature_profile_unknown", f"TEST_ONLY profile {key} mismatch", "canonical_schema_profile")
        return profile, True
    # Production profile values are external inputs.  A null/placeholder value
    # must never silently fall back to the fixture profile.
    required = ("algorithm", "public_key_bits", "signature_encoding", "eku_oid", "policy_oid", "trust_anchor")
    if profile.get("state") == "typed_absent" or any(profile.get(k) in (None, "", "project_attestation_signing_oid") for k in required):
        raise VerificationError("trust_anchor_absent", "production trust profile or root is absent", "trust_anchor_load", typed_absence=True)
    if not isinstance(profile.get("trust_anchor"), Mapping):
        raise VerificationError("trust_anchor_absent", "production trust_anchor is absent", "trust_anchor_load", typed_absence=True)
    _check_allowed(profile["trust_anchor"], TRUST_ANCHOR_FIELDS, "trust_anchor")
    algorithm = profile.get("algorithm")
    declared_signature_algorithm = profile.get("signature_algorithm")
    if not isinstance(algorithm, str) or algorithm not in ALLOWED_ALGORITHMS:
        raise VerificationError("signature_profile_unknown", f"production algorithm is not a closed-enum value: {algorithm!r}", "canonical_schema_profile")
    if declared_signature_algorithm is not None and declared_signature_algorithm != algorithm:
        raise VerificationError("signature_profile_unknown", "profile algorithm and signature_algorithm disagree", "canonical_schema_profile")
    if "digest" in profile and profile["digest"] != "SHA-256":
        raise VerificationError("signature_profile_unknown", "production digest must be exact SHA-256", "canonical_schema_profile")
    return profile, False


def _check_critical_extensions(cert: Any, label: str) -> None:
    for ext in cert.extensions:
        if ext.critical and ext.oid not in KNOWN_CRITICAL_EXTENSIONS:
            raise VerificationError("critical_extension_unknown", f"{label} has unknown critical extension {ext.oid.dotted_string}", "path_build_and_certificate_constraints")


def _check_validity(cert: Any, when: datetime, label: str) -> None:
    # *_utc is available in modern cryptography; fall back for compatibility.
    not_before = cert.not_valid_before_utc if hasattr(cert, "not_valid_before_utc") else cert.not_valid_before.replace(tzinfo=timezone.utc)
    not_after = cert.not_valid_after_utc if hasattr(cert, "not_valid_after_utc") else cert.not_valid_after.replace(tzinfo=timezone.utc)
    if not_before > when or not_after < when:
        raise VerificationError("certificate_expired", f"{label} outside validity interval", "path_build_and_certificate_constraints")


def _check_key_usage(cert: Any, label: str, required: Iterable[str]) -> None:
    ku = _extension(cert, ExtensionOID.KEY_USAGE, required=True)
    for item in required:
        if not getattr(ku, item, False):
            raise VerificationError("key_usage_invalid", f"{label} lacks keyUsage {item}", "path_build_and_certificate_constraints")


def _check_leaf_key_usage(cert: Any) -> None:
    ku = _extension(cert, ExtensionOID.KEY_USAGE, required=True)
    if not ku.digital_signature:
        raise VerificationError("key_usage_invalid", "leaf lacks keyUsage digitalSignature", "path_build_and_certificate_constraints")
    if ku.key_cert_sign or ku.crl_sign:
        raise VerificationError("key_usage_invalid", "leaf carries CA-only keyUsage", "path_build_and_certificate_constraints")


def _check_ski_aki(child: Any, issuer: Any, label: str) -> None:
    aki = _extension(child, ExtensionOID.AUTHORITY_KEY_IDENTIFIER)
    ski = _extension(issuer, ExtensionOID.SUBJECT_KEY_IDENTIFIER)
    if aki is None or aki.key_identifier is None or ski is None or aki.key_identifier != ski.digest:
        raise VerificationError("certificate_chain_absent", f"{label} AKI/SKI linkage mismatch", "path_build_and_certificate_constraints")


def _dns_matches(pattern: str, value: str) -> bool:
    pattern, value = pattern.lower().rstrip("."), value.lower().rstrip(".")
    if pattern.startswith("."):
        return value.endswith(pattern) or value == pattern[1:]
    return value == pattern


def _mailbox_matches(constraint: str, mailbox: str) -> bool:
    """RFC822Name constraint with mailbox/domain label boundaries."""
    constraint = constraint.strip().lower().rstrip(".")
    mailbox = mailbox.strip().lower()
    if "@" in constraint:
        return mailbox == constraint
    domain = mailbox.rsplit("@", 1)[-1].rstrip(".")
    base = constraint.lstrip(".")
    return domain == base or domain.endswith("." + base)


def _leaf_names(cert: Any) -> tuple[list[str], list[str], list[ipaddress._BaseAddress]]:
    dns: list[str] = []
    emails: list[str] = []
    ips: list[ipaddress._BaseAddress] = []
    san = _extension(cert, ExtensionOID.SUBJECT_ALTERNATIVE_NAME)
    if san:
        dns = list(san.get_values_for_type(x509.DNSName))
        emails = list(san.get_values_for_type(x509.RFC822Name))
        ips = list(san.get_values_for_type(x509.IPAddress))
    return dns, emails, ips


def _check_name_constraints(intermediate: Any, leaf: Any) -> None:
    nc = _extension(intermediate, ExtensionOID.NAME_CONSTRAINTS)
    if nc is None:
        return
    dns, emails, ips = _leaf_names(leaf)
    permitted = nc.permitted_subtrees or []
    excluded = nc.excluded_subtrees or []
    for subtree in excluded:
        value = subtree
        if isinstance(value, x509.DNSName) and any(_dns_matches(value.value, item) for item in dns):
            raise VerificationError("name_constraints_violation", "leaf DNS SAN is excluded", "path_build_and_certificate_constraints")
        if isinstance(value, x509.RFC822Name) and any(_mailbox_matches(value.value, item) for item in emails):
            raise VerificationError("name_constraints_violation", "leaf email SAN is excluded", "path_build_and_certificate_constraints")
        if isinstance(value, x509.IPAddress) and any(item in value.value for item in ips):
            raise VerificationError("name_constraints_violation", "leaf IP SAN is excluded", "path_build_and_certificate_constraints")
    for subtree in permitted:
        value = subtree
        if isinstance(value, x509.DNSName) and dns and not any(_dns_matches(value.value, item) for item in dns):
            raise VerificationError("name_constraints_violation", "leaf DNS SAN is outside permitted subtree", "path_build_and_certificate_constraints")
        if isinstance(value, x509.RFC822Name) and emails and not any(_mailbox_matches(value.value, item) for item in emails):
            raise VerificationError("name_constraints_violation", "leaf email SAN is outside permitted subtree", "path_build_and_certificate_constraints")
        if isinstance(value, x509.IPAddress) and ips and not any(item in value.value for item in ips):
            raise VerificationError("name_constraints_violation", "leaf IP SAN is outside permitted subtree", "path_build_and_certificate_constraints")


def _check_path_lengths(root: Any, intermediates: list[Any]) -> None:
    """Apply each CA's pathLenConstraint to the number of subordinate CAs."""
    cas = [root, *intermediates]
    for index, issuer in enumerate(cas):
        bc = _extension(issuer, ExtensionOID.BASIC_CONSTRAINTS, required=True)
        if bc.path_length is None:
            continue
        subordinate_ca_count = len(cas) - index - 1
        if subordinate_ca_count > bc.path_length:
            raise VerificationError("key_usage_invalid", f"CA path length exceeded at index {index}", "path_build_and_certificate_constraints")


def _policy_oids(cert: Any) -> set[str]:
    policies = _extension(cert, ExtensionOID.CERTIFICATE_POLICIES)
    return {item.policy_identifier.dotted_string for item in policies} if policies else set()


def _check_policy(cert: Any, expected: str, label: str) -> None:
    if expected not in _policy_oids(cert):
        raise VerificationError("policy_oid_mismatch", f"{label} policy OID mismatch", "path_build_and_certificate_constraints")


def _check_algorithm(cert: Any, profile: Mapping[str, Any], label: str) -> None:
    alg = _profile_algorithm(profile)
    key_alg, bits = _public_key_info(cert)
    expected_bits = profile.get("public_key_bits")
    if alg == "Ed25519" and key_alg != "Ed25519":
        raise VerificationError("signature_profile_unknown", f"{label} key algorithm {key_alg} does not match Ed25519", "path_build_and_certificate_constraints")
    if alg == "Ed448" and key_alg != "Ed448":
        raise VerificationError("signature_profile_unknown", f"{label} key algorithm {key_alg} does not match Ed448", "path_build_and_certificate_constraints")
    if alg == "RSA" and key_alg != "RSA":
        raise VerificationError("signature_profile_unknown", f"{label} key algorithm {key_alg} does not match RSA", "path_build_and_certificate_constraints")
    if alg == "ECDSA" and not key_alg.startswith("ECDSA-"):
        raise VerificationError("signature_profile_unknown", f"{label} key algorithm {key_alg} does not match ECDSA", "path_build_and_certificate_constraints")
    if alg not in ALLOWED_ALGORITHMS:
        raise VerificationError("signature_profile_unknown", f"unsupported receipt algorithm policy {alg or '<absent>'}", "path_build_and_certificate_constraints")
    if expected_bits is not None and bits is not None and int(expected_bits) != bits:
        raise VerificationError("signature_profile_unknown", f"{label} key size mismatch", "path_build_and_certificate_constraints")


def _check_production_key_strength(cert: Any, label: str) -> None:
    key_alg, bits = _public_key_info(cert)
    if key_alg == "RSA" and (bits is None or bits < 2048):
        raise VerificationError("signature_profile_unknown", f"{label} RSA key is below 2048 bits", "path_build_and_certificate_constraints")
    if key_alg.startswith("ECDSA-") and key_alg.split("-", 1)[1] not in {"secp256r1", "secp384r1", "secp521r1"}:
        raise VerificationError("signature_profile_unknown", f"{label} uses an unapproved EC curve", "path_build_and_certificate_constraints")
    if key_alg == "DSA" or key_alg not in {"RSA", "Ed25519", "Ed448"} and not key_alg.startswith("ECDSA-"):
        raise VerificationError("signature_profile_unknown", f"{label} uses an unapproved key algorithm {key_alg}", "path_build_and_certificate_constraints")
    hash_algorithm = cert.signature_hash_algorithm
    if hash_algorithm is not None and hash_algorithm.name.lower() in {"sha1", "md5", "md2"}:
        raise VerificationError("signature_profile_unknown", f"{label} certificate uses weak hash {hash_algorithm.name}", "path_build_and_certificate_constraints")


def _profile_algorithm(profile: Mapping[str, Any]) -> str:
    value = profile.get("algorithm", profile.get("signature_algorithm"))
    if not isinstance(value, str) or value not in ALLOWED_ALGORITHMS:
        raise VerificationError("signature_profile_unknown", f"algorithm is not a closed-enum value: {value!r}", "canonical_schema_profile")
    declared_signature_algorithm = profile.get("signature_algorithm")
    if declared_signature_algorithm is not None and declared_signature_algorithm != value:
        raise VerificationError("signature_profile_unknown", "profile algorithm and signature_algorithm disagree", "canonical_schema_profile")
    return str(value)


def _check_certificate_algorithm(cert: Any, profile: Mapping[str, Any], label: str) -> None:
    """Bind each certificate's actual signature algorithm to the profile."""
    algorithm = _profile_algorithm(profile)
    try:
        hash_name = cert.signature_hash_algorithm.name.lower() if cert.signature_hash_algorithm is not None else None
        oid = cert.signature_algorithm_oid.dotted_string
    except Exception as exc:
        raise VerificationError("signature_profile_unknown", f"{label} signature algorithm is unsupported: {exc}", "path_build_and_certificate_constraints") from exc
    if algorithm in {"RSA", "ECDSA"}:
        if hash_name != "sha256":
            raise VerificationError("signature_profile_unknown", f"{label} certificate signature hash {hash_name!r} does not match SHA-256 policy", "path_build_and_certificate_constraints")
        expected_oids = {"RSA": "1.2.840.113549.1.1.11", "ECDSA": "1.2.840.10045.4.3.2"}
        if oid != expected_oids[algorithm]:
            raise VerificationError("signature_profile_unknown", f"{label} certificate signature OID {oid} does not match {algorithm}", "path_build_and_certificate_constraints")
    elif algorithm == "Ed25519" and oid != "1.3.101.112":
        raise VerificationError("signature_profile_unknown", f"{label} certificate signature OID does not match Ed25519", "path_build_and_certificate_constraints")
    elif algorithm == "Ed448" and oid != "1.3.101.113":
        raise VerificationError("signature_profile_unknown", f"{label} certificate signature OID does not match Ed448", "path_build_and_certificate_constraints")


def _verify_receipt(request: Mapping[str, Any], leaf: Any, profile: Mapping[str, Any], test_only: bool, evaluation_time: datetime, trusted_gen_time: datetime | None = None) -> dict[str, Any]:
    receipt_raw = request.get("receipt")
    if receipt_raw is None:
        raise VerificationError("canonical_bytes_mismatch", "signed receipt is absent", "canonical_digest_scope_source_binding", typed_absence=True)
    receipt = _load_json(receipt_raw) if not isinstance(receipt_raw, Mapping) else dict(receipt_raw)
    _check_allowed(receipt, RECEIPT_FIELDS, "receipt")
    alg = _profile_algorithm(profile)
    declared_algorithm = receipt.get("algorithm")
    declared_signature_algorithm = receipt.get("signature_algorithm")
    if declared_algorithm is not None and declared_algorithm != alg:
        raise VerificationError("signature_profile_unknown", f"receipt algorithm {declared_algorithm!r} does not match profile {alg!r}", "receipt_signature")
    if declared_signature_algorithm is not None and declared_signature_algorithm != alg:
        raise VerificationError("signature_profile_unknown", f"receipt signature_algorithm {declared_signature_algorithm!r} does not match profile {alg!r}", "receipt_signature")
    if declared_algorithm is not None and declared_signature_algorithm is not None and declared_algorithm != declared_signature_algorithm:
        raise VerificationError("signature_profile_unknown", "receipt algorithm and signature_algorithm disagree", "receipt_signature")
    provided_digest = receipt.get("receipt_digest_sha256") or request.get("receipt_digest_sha256")
    signed = dict(receipt)
    sig_value = request.get("signature")
    if sig_value is None:
        sig_value = signed.pop("signature", None)
    signed.pop("signature_bytes", None)
    signed.pop("receipt_digest_sha256", None)
    canonical = canonical_json_bytes(signed)
    digest = _sha256(canonical)
    if provided_digest and provided_digest.lower() != digest:
        raise VerificationError("receipt_digest_mismatch", "receipt digest does not match canonical bytes", "canonical_digest_scope_source_binding")
    if request.get("canonical_bytes") is not None and _read_bytes(request["canonical_bytes"]) != canonical:
        raise VerificationError("canonical_bytes_mismatch", "provided canonical bytes differ", "canonical_digest_scope_source_binding")
    if sig_value is None:
        raise VerificationError("certificate_chain_absent", "receipt signature is absent", "receipt_signature", typed_absence=True)
    signature = _b64(sig_value, "signature")
    expected_encoding = profile.get("signature_encoding")
    if expected_encoding == "raw_64_bytes" and len(signature) != 64:
        raise VerificationError("signature_profile_unknown", "Ed25519 raw signature must be 64 bytes", "receipt_signature")
    if expected_encoding == "raw_114_bytes" and len(signature) != 114:
        raise VerificationError("signature_profile_unknown", "Ed448 raw signature must be 114 bytes", "receipt_signature")
    try:
        key = leaf.public_key()
        if alg == "Ed25519":
            if not isinstance(key, ed25519.Ed25519PublicKey):
                raise ValueError("leaf key is not Ed25519")
            key.verify(signature, canonical)
        elif alg == "Ed448":
            if not isinstance(key, ed448.Ed448PublicKey):
                raise ValueError("leaf key is not Ed448")
            key.verify(signature, canonical)
        elif alg == "RSA" and isinstance(key, rsa.RSAPublicKey):
            key.verify(signature, canonical, padding.PKCS1v15(), hashes.SHA256())
        elif alg == "ECDSA" and isinstance(key, ec.EllipticCurvePublicKey):
            key.verify(signature, canonical, ec.ECDSA(hashes.SHA256()))
        else:
            raise ValueError(f"receipt algorithm/key mismatch: {alg}/{type(key).__name__}")
    except Exception as exc:
        raise VerificationError("certificate_signature_invalid", f"receipt signature invalid: {exc}", "receipt_signature") from exc
    key_id = receipt.get("signer_key_id") or request.get("signer_key_id")
    if key_id:
        ski = _extension(leaf, ExtensionOID.SUBJECT_KEY_IDENTIFIER)
        expected = ski.digest.hex() if ski else None
        if str(key_id).lower().removeprefix("sha256:") != str(expected).lower():
            raise VerificationError("scope_binding_mismatch", "receipt signer key id does not match leaf SKI", "receipt_signature")
    for field in ("scope", "source_version", "verification_id", "nonce", "challenge", "sequence", "issued_at", "expires_at", "idempotency_key"):
        if field not in receipt or receipt[field] in (None, ""):
            code = "nonce_absent" if field in {"nonce", "challenge"} else "scope_binding_mismatch"
            raise VerificationError(code, f"receipt field {field} is absent", "canonical_digest_scope_source_binding", typed_absence=True)
    if not isinstance(receipt["sequence"], int) or isinstance(receipt["sequence"], bool) or receipt["sequence"] < 0:
        raise VerificationError("sequence_invalid", "receipt sequence must be a non-negative integer", "canonical_digest_scope_source_binding")
    if not isinstance(receipt["scope"], str) or not isinstance(receipt["source_version"], str):
        raise VerificationError("scope_binding_mismatch", "scope/source_version must be strings", "canonical_digest_scope_source_binding")
    issued_at = _parse_utc(receipt["issued_at"], "issued_at")
    expires_at = _parse_utc(receipt["expires_at"], "expires_at")
    if issued_at > expires_at:
        raise VerificationError("timestamp_invalid", "issued_at is after expires_at", "trusted_time")
    effective_time = trusted_gen_time or evaluation_time
    if effective_time < issued_at or effective_time > expires_at:
        raise VerificationError("timestamp_expired", "receipt is outside its issued/expires validity window", "trusted_time")
    expected_scopes = profile.get("authorized_scope") or profile.get("scope")
    if expected_scopes is not None:
        allowed = {expected_scopes} if isinstance(expected_scopes, str) else set(expected_scopes)
        if receipt["scope"] not in allowed:
            raise VerificationError("scope_binding_mismatch", "receipt scope is outside profile authorization", "canonical_digest_scope_source_binding")
    dns, emails, ips = _leaf_names(leaf)
    if not dns and not emails and not ips:
        raise VerificationError("scope_binding_mismatch", "leaf has no identity SAN", "path_build_and_certificate_constraints")
    return {"canonical_sha256": digest, "signature_verified": True, "scope": receipt.get("scope"), "source_version": receipt.get("source_version"), "issued_at": issued_at.isoformat().replace("+00:00", "Z"), "expires_at": expires_at.isoformat().replace("+00:00", "Z")}


def _external_evidence_checks(request: Mapping[str, Any], canonical_digest: str) -> None:
    """Validate the small, signed-input envelope around production PKI."""
    revocation = request.get("revocation")
    if not isinstance(revocation, Mapping):
        raise VerificationError("revocation_status_unavailable", "revocation input is not an object", "revocation", typed_absence=True)
    _check_allowed(revocation, REVOCATION_FIELDS, "revocation")
    status = str(revocation.get("status", "")).lower()
    if status in {"revoked", "unknown", "invalid", "expired"}:
        raise VerificationError("certificate_revoked" if status == "revoked" else "revocation_status_unavailable", f"revocation status is {status}", "revocation", typed_absence=status in {"unknown", "expired"})
    if status != "good" or revocation.get("verified") is not True:
        raise VerificationError("revocation_status_unavailable", "revocation response is not independently verified", "revocation", typed_absence=True)
    trusted_time = request.get("trusted_time")
    if not isinstance(trusted_time, Mapping):
        raise VerificationError("trusted_time_absent", "trusted time input is not an object", "trusted_time", typed_absence=True)
    _check_allowed(trusted_time, TRUSTED_TIME_FIELDS, "trusted_time")
    if trusted_time.get("verified") is not True:
        raise VerificationError("timestamp_invalid", "trusted time token is not verified", "trusted_time")
    imprint = str(trusted_time.get("message_imprint_sha256", "")).lower()
    if imprint != canonical_digest.lower():
        raise VerificationError("timestamp_invalid", "trusted time imprint does not match receipt digest", "trusted_time")
    gen_time = _parse_utc(trusted_time.get("gen_time"), "trusted_time.gen_time")
    if not trusted_time.get("gen_time") or not trusted_time.get("policy"):
        raise VerificationError("timestamp_invalid", "trusted time token lacks genTime or policy", "trusted_time")
    receipt = _load_json(request["receipt"]) if not isinstance(request.get("receipt"), Mapping) else request["receipt"]
    issued_at = _parse_utc(receipt.get("issued_at"), "issued_at")
    expires_at = _parse_utc(receipt.get("expires_at"), "expires_at")
    if gen_time < issued_at or gen_time > expires_at:
        raise VerificationError("timestamp_expired", "trusted time is outside receipt validity window", "trusted_time")
    ledger = request.get("replay_ledger")
    if not isinstance(ledger, Mapping):
        raise VerificationError("nonce_absent", "replay ledger/policy is absent", "replay_ledger", typed_absence=True)
    _check_allowed(ledger, LEDGER_FIELDS, "replay_ledger")
    nonce = receipt.get("nonce")
    if nonce in set(ledger.get("consumed_nonces", [])):
        raise VerificationError("nonce_replayed", "receipt nonce already consumed", "replay_ledger")
    previous = ledger.get("last_sequence")
    if previous is not None and receipt.get("sequence", -1) <= previous:
        raise VerificationError("sequence_invalid", "receipt sequence is not monotone", "replay_ledger")
    idem = receipt.get("idempotency_key")
    conflict = ledger.get("idempotency", {}).get(idem) if isinstance(ledger.get("idempotency"), Mapping) else None
    if conflict is not None and str(conflict).lower() != canonical_digest.lower():
        raise VerificationError("idempotency_conflict", "idempotency key has different receipt bytes", "replay_ledger")


def _absence(error: VerificationError, *, test_only: bool = False) -> dict[str, Any]:
    return {"schema": SCHEMA, "status": "typed_absence", "error_code": error.code, "message": error.message, "stage": error.stage, "resolution": "terminal_deferred", "no_publish": True, "evidence_class": "non_evidence" if test_only else "none", "test_only": test_only}


def _failure(error: VerificationError, *, test_only: bool = False) -> dict[str, Any]:
    return {"schema": SCHEMA, "status": "fail_closed", "error_code": error.code, "message": error.message, "stage": error.stage, "resolution": "no_publish", "no_publish": True, "evidence_class": "non_evidence" if test_only else "none", "test_only": test_only}


def verify_request(request: Mapping[str, Any]) -> dict[str, Any]:
    """Verify one request and return a JSON-serialisable decision."""
    if not _CRYPTOGRAPHY_AVAILABLE:
        return {"schema": SCHEMA, "status": "unsupported", "error_code": "verifier_absent", "message": _CRYPTOGRAPHY_ERROR, "resolution": "terminal_deferred", "no_publish": True, "evidence_class": "none"}
    test_only = False
    try:
        profile, test_only = _profile(request)
        evaluation_time = _evaluation_time(request, test_only)
        trusted_gen_time = None
        if not test_only and isinstance(request.get("trusted_time"), Mapping) and request["trusted_time"].get("gen_time"):
            _check_allowed(request["trusted_time"], TRUSTED_TIME_FIELDS, "trusted_time")
            trusted_gen_time = _parse_utc(request["trusted_time"]["gen_time"], "trusted_time.gen_time")
        certificate_evaluation_time = trusted_gen_time or evaluation_time
        root_value = request.get("root") or request.get("trust_root")
        if root_value is None:
            raise VerificationError("trust_anchor_absent", "pinned trust root is absent", "trust_anchor_load", typed_absence=True)
        if isinstance(root_value, (str, Path)) and not (isinstance(root_value, str) and "-----BEGIN" in root_value) and not Path(root_value).exists():
            raise VerificationError("trust_anchor_absent", "pinned trust root file is absent", "trust_anchor_load", typed_absence=True)
        roots = _read_pem_certs(root_value)
        if len(roots) != 1:
            raise VerificationError("trust_anchor_mismatch", "exactly one root certificate is required", "trust_anchor_load")
        root = roots[0]
        if not test_only:
            anchor = profile["trust_anchor"]
            expected = anchor.get("fingerprint_sha256") or anchor.get("sha256")
            if not expected:
                raise VerificationError("trust_anchor_absent", "pinned root fingerprint is absent", "trust_anchor_load", typed_absence=True)
            if _sha256(root.public_bytes(serialization.Encoding.DER)) != str(expected).lower():
                raise VerificationError("trust_anchor_mismatch", "root fingerprint differs from pinned anchor", "trust_anchor_load")
        marker = _name_text(root.subject).upper()
        if ("TEST_ONLY" in marker) != test_only:
            raise VerificationError("signature_profile_unknown", "caller/profile mode disagrees with root TEST_ONLY marker", "trust_anchor_load")
        _check_critical_extensions(root, "root")
        if not test_only:
            _check_production_key_strength(root, "root")
        _check_certificate_algorithm(root, profile, "root")
        _check_validity(root, certificate_evaluation_time, "root")
        bc = _extension(root, ExtensionOID.BASIC_CONSTRAINTS, required=True)
        if not bc.ca:
            raise VerificationError("key_usage_invalid", "root is not a CA", "path_build_and_certificate_constraints")
        _check_key_usage(root, "root", ("key_cert_sign",))
        _verify_signature(root, root, "root")
        chain_values = request.get("intermediates") or request.get("chain") or request.get("intermediate")
        if chain_values is None:
            inters: list[Any] = []
        elif isinstance(chain_values, (str, bytes, Path)):
            if not _material_present(chain_values):
                raise VerificationError("certificate_chain_absent", "intermediate certificate file is absent", "path_build_and_certificate_constraints", typed_absence=True)
            inters = _read_pem_certs(chain_values)
        else:
            inters = []
            for item in chain_values:
                if not _material_present(item):
                    raise VerificationError("certificate_chain_absent", "intermediate certificate file is absent", "path_build_and_certificate_constraints", typed_absence=True)
                inters.extend(_read_pem_certs(item))
        leaf_value = request.get("leaf")
        if leaf_value is None:
            raise VerificationError("certificate_chain_absent", "leaf certificate is absent", "path_build_and_certificate_constraints", typed_absence=True)
        if not _material_present(leaf_value):
            raise VerificationError("certificate_chain_absent", "leaf certificate file is absent", "path_build_and_certificate_constraints", typed_absence=True)
        leaf_certs = _read_pem_certs(leaf_value)
        if len(leaf_certs) != 1:
            raise VerificationError("certificate_chain_absent", "exactly one leaf certificate is required", "path_build_and_certificate_constraints")
        leaf = leaf_certs[0]
        if ("TEST_ONLY" in _name_text(leaf.subject).upper()) != test_only:
            raise VerificationError("signature_profile_unknown", "caller/profile mode disagrees with leaf TEST_ONLY marker", "path_build_and_certificate_constraints")
        previous = root
        for index, intermediate in enumerate(inters):
            label = f"intermediate[{index}]"
            if ("TEST_ONLY" in _name_text(intermediate.subject).upper()) != test_only:
                raise VerificationError("signature_profile_unknown", f"caller/profile mode disagrees with {label} TEST_ONLY marker", "path_build_and_certificate_constraints")
            if intermediate.issuer != previous.subject:
                raise VerificationError("certificate_chain_absent", f"{label} issuer/subject mismatch", "path_build_and_certificate_constraints")
            _check_ski_aki(intermediate, previous, label)
            _check_critical_extensions(intermediate, label)
            if not test_only:
                _check_production_key_strength(intermediate, label)
            _check_certificate_algorithm(intermediate, profile, label)
            _check_validity(intermediate, certificate_evaluation_time, label)
            ibc = _extension(intermediate, ExtensionOID.BASIC_CONSTRAINTS, required=True)
            if not ibc.ca:
                raise VerificationError("key_usage_invalid", f"{label} is not a CA", "path_build_and_certificate_constraints")
            _check_key_usage(intermediate, label, ("key_cert_sign",))
            _verify_signature(intermediate, previous, label)
            previous = intermediate
        if leaf.issuer != previous.subject:
            raise VerificationError("certificate_chain_absent", "leaf issuer does not match issuing CA subject", "path_build_and_certificate_constraints")
        _check_ski_aki(leaf, previous, "leaf")
        _check_critical_extensions(leaf, "leaf")
        if not test_only:
            _check_production_key_strength(leaf, "leaf")
        _check_certificate_algorithm(leaf, profile, "leaf")
        _check_validity(leaf, certificate_evaluation_time, "leaf")
        lbc = _extension(leaf, ExtensionOID.BASIC_CONSTRAINTS, required=True)
        if lbc.ca:
            raise VerificationError("key_usage_invalid", "leaf is a CA", "path_build_and_certificate_constraints")
        _check_leaf_key_usage(leaf)
        eku = _extension(leaf, ExtensionOID.EXTENDED_KEY_USAGE, required=True)
        expected_eku = profile.get("eku_oid") or profile.get("extended_key_usage_oid")
        if expected_eku not in {oid.dotted_string for oid in eku}:
            raise VerificationError("eku_missing", "leaf EKU does not contain attestation signing OID", "path_build_and_certificate_constraints")
        expected_policy = profile.get("policy_oid")
        if expected_policy:
            _check_policy(root, expected_policy, "root")
            for intermediate in inters:
                _check_policy(intermediate, expected_policy, "intermediate")
            _check_policy(leaf, expected_policy, "leaf")
        _check_path_lengths(root, inters)
        _check_name_constraints(root, leaf)
        for intermediate in inters:
            _check_name_constraints(intermediate, leaf)
        _check_algorithm(leaf, profile, "leaf")
        receipt_info = _verify_receipt(request, leaf, profile, test_only, evaluation_time, trusted_gen_time)
        # External production revocation and signed time are intentionally not
        # guessed. TEST_ONLY fixtures may provide a deterministic local marker.
        if not test_only:
            _external_evidence_checks(request, receipt_info["canonical_sha256"])
        result = {"schema": SCHEMA, "status": "valid_for_declared_scope", "error_code": None, "stage": "authority_decision", "resolution": "non_evidence" if test_only else "accepted_for_declared_scope", "no_publish": True if test_only else False, "evidence_class": "non_evidence" if test_only else "production_candidate", "test_only": test_only, "checks": {"root": True, "chain": True, "constraints": True, "receipt": receipt_info}}
        return result
    except VerificationError as exc:
        return _absence(exc, test_only=test_only) if exc.typed_absence else _failure(exc, test_only=test_only)
    except Exception as exc:
        return _failure(VerificationError("verifier_absent", f"unexpected verifier error: {type(exc).__name__}: {exc}", "canonical_schema_profile"), test_only=test_only)


def verify_chain(*, root: Any, leaf: Any, profile: Any, receipt: Any, intermediates: Any = None, **kwargs: Any) -> dict[str, Any]:
    """Convenience API mirroring the CLI request fields."""
    request = {"root": root, "leaf": leaf, "profile": profile, "receipt": receipt}
    if intermediates is not None:
        request["intermediates"] = intermediates
    request.update(kwargs)
    return verify_request(request)


def result_exit_code(result: Mapping[str, Any]) -> int:
    return {"valid_for_declared_scope": 0, "typed_absence": 2, "fail_closed": 3, "unsupported": 4}.get(str(result.get("status")), 5)
