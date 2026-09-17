from __future__ import annotations

import base64
import hashlib
import json
import os
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, padding, rsa
from cryptography.x509.oid import ExtensionOID, NameOID, ObjectIdentifier

from tools.up1_external_closure_r2.pki_chain.verifier import canonical_json_bytes, verify_request

TEST_EKU = "1.3.6.1.4.1.55555.1.1"
TEST_POLICY = "1.3.6.1.4.1.55555.1.2"


def name(label: str, marker: str = "TEST_ONLY") -> x509.Name:
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, label), x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, marker)])


def cert(subject, issuer, public_key, signer, serial, *, ca, path_length=None, eku=None, san=None, policy=TEST_POLICY, key_cert_sign=None, unknown_critical=False, email_san=None, name_constraints=None, algorithm=None):
    now = datetime.now(timezone.utc)
    b = x509.CertificateBuilder().subject_name(subject).issuer_name(issuer).public_key(public_key).serial_number(serial).not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=3))
    b = b.add_extension(x509.BasicConstraints(ca=ca, path_length=path_length), critical=True)
    b = b.add_extension(x509.SubjectKeyIdentifier.from_public_key(public_key), critical=False)
    b = b.add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(signer.public_key()), critical=False)
    b = b.add_extension(x509.KeyUsage(digital_signature=not ca, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=ca if key_cert_sign is None else key_cert_sign, crl_sign=ca, encipher_only=False, decipher_only=False), critical=True)
    if eku is not None:
        b = b.add_extension(x509.ExtendedKeyUsage([ObjectIdentifier(v) for v in eku]), critical=True)
    sans = []
    sans.extend(x509.DNSName(v) for v in (san or []))
    sans.extend(x509.RFC822Name(v) for v in (email_san or []))
    if sans:
        b = b.add_extension(x509.SubjectAlternativeName(sans), critical=False)
    if name_constraints is not None:
        b = b.add_extension(name_constraints, critical=True)
    b = b.add_extension(x509.CertificatePolicies([x509.PolicyInformation(ObjectIdentifier(policy), None)]), critical=False)
    if unknown_critical:
        b = b.add_extension(x509.UnrecognizedExtension(ObjectIdentifier("1.2.3.4.5.6.7"), b"\x05\x00"), critical=True)
    return b.sign(signer, algorithm=algorithm)


def fixture():
    rk, ik, lk = (ed25519.Ed25519PrivateKey.generate() for _ in range(3))
    root = cert(name("UP1 TEST_ONLY Root"), name("UP1 TEST_ONLY Root"), rk.public_key(), rk, 100, ca=True, path_length=1)
    inter = cert(name("UP1 TEST_ONLY Intermediate"), root.subject, ik.public_key(), rk, 101, ca=True, path_length=0, name_constraints=x509.NameConstraints(permitted_subtrees=[x509.DNSName(".test")], excluded_subtrees=None))
    leaf = cert(name("UP1 TEST_ONLY Attestor"), inter.subject, lk.public_key(), ik, 102, ca=False, eku=[TEST_EKU], san=["attestor.test"])
    payload = {"scope": "fixture-scope", "source_version": "TEST_ONLY-source-v1", "verification_id": "verification-1", "nonce": "nonce-1", "challenge": "challenge-1", "sequence": 1, "issued_at": "2026-09-16T00:00:00Z", "expires_at": "2026-09-18T00:00:00Z", "idempotency_key": "idempotency-1", "signer_key_id": x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()}
    sig = lk.sign(canonical_json_bytes(payload))
    receipt = dict(payload, receipt_digest_sha256=hashlib.sha256(canonical_json_bytes(payload)).hexdigest(), signature=base64.b64encode(sig).decode())
    profile = {"id": "TEST_ONLY-W2-R1", "digest": "SHA-256", "signature_algorithm": "Ed25519", "public_key_bits": 256, "signature_encoding": "raw_64_bytes", "eku_oid": TEST_EKU, "policy_oid": TEST_POLICY}
    req = {"test_only": True, "profile": profile, "root": root.public_bytes(serialization.Encoding.PEM), "intermediates": [inter.public_bytes(serialization.Encoding.PEM)], "leaf": leaf.public_bytes(serialization.Encoding.PEM), "receipt": receipt}
    return locals()


def pems(*xs):
    return [x.public_bytes(serialization.Encoding.PEM) for x in xs]


def run_case(case, request, expected="fail_closed"):
    result = verify_request(request)
    return {"case": case, "expected": expected, "status": result.get("status"), "error_code": result.get("error_code"), "resolution": result.get("resolution"), "evidence_class": result.get("evidence_class"), "no_publish": result.get("no_publish"), "message": result.get("message", "")}


def production_rsa_fixture(bits=512, *, expired_receipt=False):
    rk, ik, lk = (rsa.generate_private_key(public_exponent=65537, key_size=bits) for _ in range(3))
    marker = "PRODUCTION"
    root = cert(name("UP1 Production Root", marker), name("UP1 Production Root", marker), rk.public_key(), rk, 1100, ca=True, path_length=1, policy="1.2.4", algorithm=hashes.SHA256())
    inter = cert(name("UP1 Production Intermediate", marker), root.subject, ik.public_key(), rk, 1101, ca=True, path_length=0, policy="1.2.4", algorithm=hashes.SHA256())
    leaf = cert(name("UP1 Production Attestor", marker), inter.subject, lk.public_key(), ik, 1102, ca=False, eku=["1.2.3"], san=["attestor.example"], policy="1.2.4", algorithm=hashes.SHA256())
    payload = {"scope": "production-scope", "source_version": "prod-source-v1", "verification_id": "verification-prod", "nonce": "nonce-prod", "challenge": "challenge-prod", "sequence": 1, "issued_at": "2000-01-01T00:00:00Z" if expired_receipt else datetime.now(timezone.utc).isoformat(), "expires_at": "2000-01-02T00:00:00Z" if expired_receipt else (datetime.now(timezone.utc) + timedelta(days=1)).isoformat(), "idempotency_key": "idempotency-prod", "signer_key_id": x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()}
    canonical = canonical_json_bytes(payload)
    sig = lk.sign(canonical, padding.PKCS1v15(), hashes.SHA256())
    receipt = dict(payload, receipt_digest_sha256=hashlib.sha256(canonical).hexdigest(), signature=base64.b64encode(sig).decode())
    profile = {"id": "PRODUCTION-EXTERNAL-R1", "algorithm": "RSA", "public_key_bits": bits, "signature_encoding": "pkcs1v15-sha256", "eku_oid": "1.2.3", "policy_oid": "1.2.4", "trust_anchor": {"fingerprint_sha256": hashlib.sha256(root.public_bytes(serialization.Encoding.DER)).hexdigest()}}
    request = {"profile": profile, "evaluation_time": datetime.now(timezone.utc).isoformat(), "root": root.public_bytes(serialization.Encoding.PEM), "intermediates": [inter.public_bytes(serialization.Encoding.PEM)], "leaf": leaf.public_bytes(serialization.Encoding.PEM), "receipt": receipt, "revocation": {"status": "good", "verified": True}, "trusted_time": {"verified": True, "message_imprint_sha256": receipt["receipt_digest_sha256"], "gen_time": datetime.now(timezone.utc).isoformat(), "policy": "1.2.3"}, "replay_ledger": {"consumed_nonces": [], "last_sequence": 0, "idempotency": {}}}
    return request


def main():
    f = fixture()
    base = f["req"]
    out = []
    out.append(run_case("wrong_root_signature", dict(base, root=pems(cert(name("UP1 TEST_ONLY Wrong Root"), name("UP1 TEST_ONLY Wrong Root"), ed25519.Ed25519PrivateKey.generate().public_key(), (wrong := ed25519.Ed25519PrivateKey.generate()), 901, ca=True, path_length=1))[0])))
    self_leaf = cert(f["inter"].subject, f["inter"].subject, f["lk"].public_key(), f["lk"], 902, ca=False, eku=[TEST_EKU], san=["attestor.test"])
    out.append(run_case("self_signed_leaf", dict(base, intermediates=[], leaf=self_leaf.public_bytes(serialization.Encoding.PEM))))
    i2k = ed25519.Ed25519PrivateKey.generate()
    i2 = cert(name("UP1 TEST_ONLY Intermediate-2"), f["inter"].subject, i2k.public_key(), f["ik"], 903, ca=True, path_length=0, san=[])
    leaf2 = cert(name("UP1 TEST_ONLY Attestor-2"), i2.subject, f["lk"].public_key(), i2k, 909, ca=False, eku=[TEST_EKU], san=["attestor.test"])
    out.append(run_case("path_length_exceeded", dict(base, intermediates=pems(f["inter"], i2), leaf=leaf2.public_bytes(serialization.Encoding.PEM))))
    bad_bc = cert(f["inter"].subject, f["inter"].subject, f["lk"].public_key(), f["ik"], 904, ca=True, path_length=0, eku=[TEST_EKU], san=["attestor.test"])
    out.append(run_case("leaf_basic_constraints_ca_true", dict(base, intermediates=pems(f["inter"]), leaf=bad_bc.public_bytes(serialization.Encoding.PEM))))
    bad_aki = cert(name("UP1 TEST_ONLY Attestor"), f["inter"].subject, f["lk"].public_key(), f["ik"], 905, ca=False, eku=[TEST_EKU], san=["attestor.test"])
    # Rebuild the leaf with an AKI pointing at root instead of its issuer.
    bb = x509.CertificateBuilder().subject_name(bad_aki.subject).issuer_name(bad_aki.issuer).public_key(f["lk"].public_key()).serial_number(905).not_valid_before(bad_aki.not_valid_before_utc - timedelta(minutes=1)).not_valid_after(bad_aki.not_valid_after_utc)
    for ext in bad_aki.extensions:
        if ext.oid != ExtensionOID.AUTHORITY_KEY_IDENTIFIER:
            bb = bb.add_extension(ext.value, ext.critical)
    bb = bb.add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(f["rk"].public_key()), critical=False)
    bad_aki = bb.sign(f["ik"], algorithm=None)
    out.append(run_case("aki_ski_mismatch", dict(base, leaf=bad_aki.public_bytes(serialization.Encoding.PEM))))
    unknown = cert(name("UP1 TEST_ONLY Attestor"), f["inter"].subject, f["lk"].public_key(), f["ik"], 906, ca=False, eku=[TEST_EKU], san=["attestor.test"], unknown_critical=True)
    out.append(run_case("unknown_critical_extension", dict(base, leaf=unknown.public_bytes(serialization.Encoding.PEM))))
    out.append(run_case("leaf_eku_mismatch", dict(base, leaf=cert(name("UP1 TEST_ONLY Attestor"), f["inter"].subject, f["lk"].public_key(), f["ik"], 907, ca=False, eku=["1.2.3.4"], san=["attestor.test"]).public_bytes(serialization.Encoding.PEM))))
    expired_receipt = dict(f["receipt"], issued_at="2000-01-01T00:00:00Z", expires_at="2000-01-02T00:00:00Z")
    signed = dict(expired_receipt); signed.pop("receipt_digest_sha256"); signed.pop("signature")
    expired_receipt["receipt_digest_sha256"] = hashlib.sha256(canonical_json_bytes(signed)).hexdigest(); expired_receipt["signature"] = base64.b64encode(f["lk"].sign(canonical_json_bytes(signed))).decode()
    out.append(run_case("expired_receipt_fields_accepted", dict(base, receipt=expired_receipt), expected="fail_closed"))
    ku_bad = cert(name("UP1 TEST_ONLY Attestor"), f["inter"].subject, f["lk"].public_key(), f["ik"], 908, ca=False, eku=[TEST_EKU], san=["attestor.test"], key_cert_sign=True)
    ku_req = dict(base, leaf=ku_bad.public_bytes(serialization.Encoding.PEM))
    # Sign receipt with the same leaf key; the key is unchanged.
    out.append(run_case("leaf_key_usage_extra_key_cert_sign_accepted", ku_req, expected="fail_closed"))
    extra = dict(f["receipt"], unknown_field="accepted-by-verifier")
    signed = dict(extra); signed.pop("receipt_digest_sha256"); signed.pop("signature")
    extra["receipt_digest_sha256"] = hashlib.sha256(canonical_json_bytes(signed)).hexdigest(); extra["signature"] = base64.b64encode(f["lk"].sign(canonical_json_bytes(signed))).decode()
    out.append(run_case("receipt_unknown_field_accepted", dict(base, receipt=extra), expected="fail_closed"))
    # Duplicate JSON keys are silently collapsed by json.loads; feed a raw file with a duplicate scope.
    signed_json = json.dumps({k: v for k, v in f["receipt"].items() if k not in {"signature", "receipt_digest_sha256"}}, separators=(",", ":"), sort_keys=True)
    raw_signed = signed_json[:-1] + ',"scope":"fixture-scope"}'
    parsed = json.loads(raw_signed); digest = hashlib.sha256(canonical_json_bytes(parsed)).hexdigest(); sig = base64.b64encode(f["lk"].sign(canonical_json_bytes(parsed))).decode()
    raw = raw_signed[:-1] + ',"receipt_digest_sha256":' + json.dumps(digest) + ',"signature":' + json.dumps(sig) + '}'
    with tempfile.NamedTemporaryFile("w", suffix=".json", encoding="utf-8", delete=False) as h:
        h.write(raw); dup_path = h.name
    try:
        out.append(run_case("duplicate_json_keys_accepted", dict(base, receipt=dup_path), expected="fail_closed"))
    finally:
        Path(dup_path).unlink(missing_ok=True)
    # TEST_ONLY profile id forces non-evidence even when caller says production.
    upgraded = dict(base); upgraded["test_only"] = False
    out.append(run_case("test_only_profile_forced_non_evidence", upgraded, expected="valid_for_declared_scope_non_evidence"))
    prod = {"id": "PRODUCTION-EXTERNAL-R1", "algorithm": "Ed25519", "public_key_bits": 256, "signature_encoding": "raw_64_bytes", "eku_oid": "1.2.3", "policy_oid": "1.2.4", "trust_anchor": {"fingerprint_sha256": "00" * 32}}
    out.append(run_case("production_root_typed_absence", {"profile": prod, "leaf": base["leaf"], "receipt": base["receipt"]}, expected="typed_absence"))
    out.append(run_case("production_rsa_1024_weak_key_accepted", production_rsa_fixture(1024), expected="fail_closed"))
    out.append(run_case("production_expired_receipt_fields_accepted", production_rsa_fixture(2048, expired_receipt=True), expected="fail_closed"))
    # RFC822 permitted subtree must be domain-boundary aware; verifier uses raw endswith.
    ek, lk2 = ed25519.Ed25519PrivateKey.generate(), ed25519.Ed25519PrivateKey.generate()
    inter_email = cert(name("UP1 TEST_ONLY Email Intermediate"), f["root"].subject, ek.public_key(), f["rk"], 1201, ca=True, path_length=0, name_constraints=x509.NameConstraints(permitted_subtrees=[x509.RFC822Name("example.com")], excluded_subtrees=None))
    leaf_email = cert(name("UP1 TEST_ONLY Email Attestor"), inter_email.subject, lk2.public_key(), ek, 1202, ca=False, eku=[TEST_EKU], email_san=["attacker@notexample.com"])
    email_payload = dict(f["receipt"]); email_payload["signer_key_id"] = x509.SubjectKeyIdentifier.from_public_key(lk2.public_key()).digest.hex(); email_payload.pop("receipt_digest_sha256"); email_payload.pop("signature"); email_payload["scope"] = "fixture-scope"; email_can = canonical_json_bytes(email_payload); email_payload["receipt_digest_sha256"] = hashlib.sha256(email_can).hexdigest(); email_payload["signature"] = base64.b64encode(lk2.sign(email_can)).decode()
    out.append(run_case("name_constraints_email_suffix_bypass", dict(base, intermediates=[inter_email.public_bytes(serialization.Encoding.PEM)], leaf=leaf_email.public_bytes(serialization.Encoding.PEM), receipt=email_payload), expected="fail_closed"))
    print(json.dumps({"pid": os.getpid(), "python": sys.version.split()[0], "started_utc": datetime.now(timezone.utc).isoformat(), "cases": out}, ensure_ascii=False, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__":
    main()
