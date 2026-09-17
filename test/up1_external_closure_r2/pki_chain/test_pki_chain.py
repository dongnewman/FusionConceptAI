from __future__ import annotations

import base64
import copy
import json
import os
import subprocess
import sys
from types import SimpleNamespace
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed25519, padding, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID, ObjectIdentifier

from tools.up1_external_closure_r2.pki_chain.verifier import _check_certificate_algorithm, canonical_json_bytes, verify_request, VerificationError


TEST_EKU = "1.3.6.1.4.1.55555.1.1"
TEST_POLICY = "1.3.6.1.4.1.55555.1.2"


def _name(label: str) -> x509.Name:
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, label), x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, "TEST_ONLY")])


def _cert(subject, issuer, public_key, signer, serial, *, ca, path_length=None, eku=None, san=None, email_san=None, permitted=None, name_constraints=None, policy=TEST_POLICY, key_cert_sign=None, cert_hash=None):
    now = datetime.now(timezone.utc)
    builder = x509.CertificateBuilder().subject_name(subject).issuer_name(issuer).public_key(public_key).serial_number(serial).not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=3))
    builder = builder.add_extension(x509.BasicConstraints(ca=ca, path_length=path_length), critical=True)
    builder = builder.add_extension(x509.SubjectKeyIdentifier.from_public_key(public_key), critical=False)
    builder = builder.add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(signer.public_key()), critical=False)
    builder = builder.add_extension(x509.KeyUsage(digital_signature=not ca, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=ca if key_cert_sign is None else key_cert_sign, crl_sign=ca, encipher_only=False, decipher_only=False), critical=True)
    if eku:
        builder = builder.add_extension(x509.ExtendedKeyUsage([ObjectIdentifier(item) for item in eku]), critical=True)
    if san or email_san:
        names = [x509.DNSName(item) for item in (san or [])] + [x509.RFC822Name(item) for item in (email_san or [])]
        builder = builder.add_extension(x509.SubjectAlternativeName(names), critical=False)
    if name_constraints is not None:
        builder = builder.add_extension(name_constraints, critical=True)
    elif permitted:
        builder = builder.add_extension(x509.NameConstraints(permitted_subtrees=[x509.DNSName(item) for item in permitted], excluded_subtrees=None), critical=True)
    builder = builder.add_extension(x509.CertificatePolicies([x509.PolicyInformation(ObjectIdentifier(policy), None)]), critical=False)
    sign_algorithm = None if isinstance(signer, ed25519.Ed25519PrivateKey) else (cert_hash or hashes.SHA256())
    return builder.sign(signer, algorithm=sign_algorithm)


def _fixture() -> dict:
    root_key = ed25519.Ed25519PrivateKey.generate()
    intermediate_key = ed25519.Ed25519PrivateKey.generate()
    leaf_key = ed25519.Ed25519PrivateKey.generate()
    root = _cert(_name("UP1 TEST_ONLY Root"), _name("UP1 TEST_ONLY Root"), root_key.public_key(), root_key, 100, ca=True, path_length=1)
    intermediate = _cert(_name("UP1 TEST_ONLY Intermediate"), root.subject, intermediate_key.public_key(), root_key, 101, ca=True, path_length=0, permitted=[".test"])
    leaf = _cert(_name("UP1 TEST_ONLY Attestor"), intermediate.subject, leaf_key.public_key(), intermediate_key, 102, ca=False, eku=[TEST_EKU], san=["attestor.test"])
    leaf_ski = x509.SubjectKeyIdentifier.from_public_key(leaf_key.public_key()).digest.hex()
    payload = {"scope": "fixture-scope", "source_version": "TEST_ONLY-source-v1", "verification_id": "verification-1", "nonce": "nonce-1", "challenge": "challenge-1", "sequence": 1, "issued_at": "2026-09-16T00:00:00Z", "expires_at": "2026-09-18T00:00:00Z", "idempotency_key": "idempotency-1", "signer_key_id": leaf_ski}
    signature = leaf_key.sign(canonical_json_bytes(payload))
    receipt = dict(payload, receipt_digest_sha256=__import__("hashlib").sha256(canonical_json_bytes(payload)).hexdigest(), signature=base64.b64encode(signature).decode("ascii"))
    profile = {"id": "TEST_ONLY-W2-R1", "digest": "SHA-256", "signature_algorithm": "Ed25519", "public_key_bits": 256, "signature_encoding": "raw_64_bytes", "eku_oid": TEST_EKU, "policy_oid": TEST_POLICY}
    return {"test_only": True, "profile": profile, "root": root, "intermediate": intermediate, "leaf": leaf, "receipt": receipt, "root_key": root_key, "intermediate_key": intermediate_key, "leaf_key": leaf_key}


def _request(fx: dict) -> dict:
    return {"test_only": True, "profile": fx["profile"], "root": fx["root"].public_bytes(serialization.Encoding.PEM), "intermediates": [fx["intermediate"].public_bytes(serialization.Encoding.PEM)], "leaf": fx["leaf"].public_bytes(serialization.Encoding.PEM), "receipt": fx["receipt"]}


def _production_fixture(bits: int = 2048, *, expired: bool = False) -> dict:
    root_key, intermediate_key, leaf_key = (rsa.generate_private_key(public_exponent=65537, key_size=bits) for _ in range(3))
    # Replace the TEST_ONLY OU from _name with a production marker.
    def prod_name(label):
        return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, label), x509.NameAttribute(NameOID.ORGANIZATIONAL_UNIT_NAME, "PRODUCTION")])
    root = _cert(prod_name("UP1 Production Root"), prod_name("UP1 Production Root"), root_key.public_key(), root_key, 200, ca=True, path_length=1, policy="1.2.4")
    intermediate = _cert(prod_name("UP1 Production Intermediate"), root.subject, intermediate_key.public_key(), root_key, 201, ca=True, path_length=0, policy="1.2.4")
    leaf = _cert(prod_name("UP1 Production Attestor"), intermediate.subject, leaf_key.public_key(), intermediate_key, 202, ca=False, eku=["1.2.3"], san=["attestor.example"], policy="1.2.4")
    now = datetime.now(timezone.utc)
    issued = "2000-01-01T00:00:00Z" if expired else (now - timedelta(minutes=1)).isoformat().replace("+00:00", "Z")
    expires = "2000-01-02T00:00:00Z" if expired else (now + timedelta(days=1)).isoformat().replace("+00:00", "Z")
    payload = {"scope": "production-scope", "source_version": "production-source-v1", "verification_id": "production-verification", "nonce": "production-nonce", "challenge": "production-challenge", "sequence": 1, "issued_at": issued, "expires_at": expires, "idempotency_key": "production-idempotency", "signer_key_id": x509.SubjectKeyIdentifier.from_public_key(leaf_key.public_key()).digest.hex()}
    canonical = canonical_json_bytes(payload)
    receipt = dict(payload, receipt_digest_sha256=__import__("hashlib").sha256(canonical).hexdigest(), signature=base64.b64encode(leaf_key.sign(canonical, padding.PKCS1v15(), hashes.SHA256())).decode("ascii"))
    profile = {"id": "PRODUCTION-EXTERNAL-R1", "algorithm": "RSA", "public_key_bits": bits, "signature_encoding": "pkcs1v15-sha256", "eku_oid": "1.2.3", "policy_oid": "1.2.4", "trust_anchor": {"fingerprint_sha256": __import__("hashlib").sha256(root.public_bytes(serialization.Encoding.DER)).hexdigest()}}
    request = {"profile": profile, "evaluation_time": now.isoformat().replace("+00:00", "Z"), "root": root.public_bytes(serialization.Encoding.PEM), "intermediates": [intermediate.public_bytes(serialization.Encoding.PEM)], "leaf": leaf.public_bytes(serialization.Encoding.PEM), "receipt": receipt, "revocation": {"status": "good", "verified": True}, "trusted_time": {"verified": True, "message_imprint_sha256": receipt["receipt_digest_sha256"], "gen_time": now.isoformat().replace("+00:00", "Z"), "policy": "1.2.3"}, "replay_ledger": {"consumed_nonces": [], "last_sequence": 0, "idempotency": {}}}
    return {"request": request, "root": root, "intermediate": intermediate, "leaf": leaf, "leaf_key": leaf_key}


class PkiChainTests(unittest.TestCase):
    def test_valid_test_only_chain_is_non_evidence(self):
        result = verify_request(_request(_fixture()))
        self.assertEqual(result["status"], "valid_for_declared_scope")
        self.assertTrue(result["no_publish"])
        self.assertEqual(result["evidence_class"], "non_evidence")

    def test_missing_production_root_is_typed_absence(self):
        fx = _fixture()
        request = _request(fx)
        request.pop("root")
        request["test_only"] = False
        request["profile"] = {"state": "typed_absent", "trust_anchor": None}
        result = verify_request(request)
        self.assertEqual(result["status"], "typed_absence")
        self.assertEqual(result["error_code"], "trust_anchor_absent")
        self.assertEqual(result["resolution"], "terminal_deferred")
        self.assertTrue(result["no_publish"])

    def test_bad_receipt_signature_fail_closed(self):
        request = _request(_fixture())
        request["receipt"]["signature"] = base64.b64encode(b"x" * 64).decode("ascii")
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "certificate_signature_invalid")

    def test_policy_eku_and_name_constraints_fail_closed(self):
        fx = _fixture()
        request = _request(fx)
        request["profile"] = dict(fx["profile"], policy_oid="1.3.6.1.4.1.55555.9.9")
        result = verify_request(request)
        self.assertEqual(result["error_code"], "signature_profile_unknown")

    def test_path_length_fail_closed(self):
        fx = _fixture()
        # The fixture root permits one subordinate CA; add a second CA, which
        # also exercises the root/intermediate issuer and AKI/SKI checks.
        request = _request(fx)
        request["intermediates"] = [request["intermediates"][0], request["intermediates"][0]]
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertIn(result["error_code"], {"certificate_chain_absent", "key_usage_invalid"})

    def test_json_cli_emits_machine_result(self):
        fx = _fixture()
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            for name, cert in (("ROOT_TEST_ONLY.pem", fx["root"]), ("intermediate_TEST_ONLY.pem", fx["intermediate"]), ("leaf_TEST_ONLY.pem", fx["leaf"])):
                (base / name).write_bytes(cert.public_bytes(serialization.Encoding.PEM))
            request = {"test_only": True, "profile": fx["profile"], "root": str(base / "ROOT_TEST_ONLY.pem"), "intermediates": [str(base / "intermediate_TEST_ONLY.pem")], "leaf": str(base / "leaf_TEST_ONLY.pem"), "receipt": fx["receipt"]}
            req = base / "request.json"
            req.write_text(json.dumps(request), encoding="utf-8")
            env = dict(os.environ)
            env["PYTHONDONTWRITEBYTECODE"] = "1"
            proc = subprocess.run([sys.executable, "-B", "-m", "tools.up1_external_closure_r2.pki_chain", "--request", str(req)], capture_output=True, text=True, env=env)
            self.assertEqual(proc.returncode, 0, proc.stderr)
            output = json.loads(proc.stdout)
            self.assertEqual(output["status"], "valid_for_declared_scope")
            self.assertEqual(output["evidence_class"], "non_evidence")

    def test_production_rsa_1024_is_rejected_by_independent_policy(self):
        result = verify_request(_production_fixture(1024)["request"])
        self.assertEqual(result["status"], "fail_closed")
        self.assertTrue(result["no_publish"])
        self.assertEqual(result["error_code"], "signature_profile_unknown")

    def test_production_algorithm_is_closed_enum_and_rejects_weak_spellings(self):
        for value in ("RSA-SHA1", "RSA-MD5", "rsa", "RSA-SHA256", "UNKNOWN"):
            request = _production_fixture(2048)["request"]
            request["profile"] = dict(request["profile"], algorithm=value)
            result = verify_request(request)
            self.assertEqual(result["status"], "fail_closed", value)
            self.assertEqual(result["error_code"], "signature_profile_unknown", value)

    def test_receipt_declared_algorithm_must_match_profile(self):
        request = _production_fixture(2048)["request"]
        request["receipt"] = dict(request["receipt"], signature_algorithm="RSA-SHA1")
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "signature_profile_unknown")

    def test_profile_and_receipt_algorithm_aliases_must_be_consistent(self):
        request = _production_fixture(2048)["request"]
        request["profile"] = dict(request["profile"], signature_algorithm="ECDSA")
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "signature_profile_unknown")
        request = _production_fixture(2048)["request"]
        request["receipt"] = dict(request["receipt"], algorithm="RSA", signature_algorithm="ECDSA")
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "signature_profile_unknown")

    def test_each_production_certificate_signature_hash_is_policy_bound(self):
        fx = _production_fixture(2048)
        # A SHA-1-signed certificate is cryptographically meaningful but
        # outside the profile's exact RSA/SHA-256 certificate policy. The
        # installed cryptography build refuses creating SHA-1 certificates,
        # so this regression probes the same production policy with the
        # parsed-certificate interface rather than manufacturing evidence.
        fake_sha1_cert = SimpleNamespace(signature_hash_algorithm=hashes.SHA1(), signature_algorithm_oid=ObjectIdentifier("1.2.840.113549.1.1.5"))
        with self.assertRaises(VerificationError):
            _check_certificate_algorithm(fake_sha1_cert, fx["request"]["profile"], "root")
        fake_md5_cert = SimpleNamespace(signature_hash_algorithm=hashes.MD5(), signature_algorithm_oid=ObjectIdentifier("1.2.840.113549.1.1.4"))
        with self.assertRaises(VerificationError):
            _check_certificate_algorithm(fake_md5_cert, fx["request"]["profile"], "root")
        fake_unknown_cert = SimpleNamespace(signature_hash_algorithm=hashes.SHA256(), signature_algorithm_oid=ObjectIdentifier("1.2.3.4.5"))
        with self.assertRaises(VerificationError):
            _check_certificate_algorithm(fake_unknown_cert, fx["request"]["profile"], "root")

    def test_expired_receipt_and_trusted_time_window_are_rejected(self):
        expired = verify_request(_production_fixture(2048, expired=True)["request"])
        self.assertEqual(expired["status"], "fail_closed")
        self.assertEqual(expired["error_code"], "timestamp_expired")
        fresh = _production_fixture(2048)["request"]
        fresh["trusted_time"] = dict(fresh["trusted_time"], gen_time="2000-01-01T00:00:00Z")
        result = verify_request(fresh)
        self.assertEqual(result["status"], "fail_closed")
        self.assertIn(result["error_code"], {"timestamp_expired", "certificate_expired"})

    def test_rfc822_constraint_respects_domain_label_boundary(self):
        fx = _fixture()
        email_nc = x509.NameConstraints(permitted_subtrees=[x509.RFC822Name("example.com")], excluded_subtrees=None)
        email_intermediate = _cert(fx["intermediate"].subject, fx["root"].subject, fx["intermediate"].public_key(), fx["root_key"], 301, ca=True, path_length=0, name_constraints=email_nc)
        email_leaf = _cert(fx["leaf"].subject, email_intermediate.subject, fx["leaf"].public_key(), fx["intermediate_key"], 302, ca=False, eku=[TEST_EKU], email_san=["attacker@notexample.com"])
        request = _request(fx)
        request["intermediates"] = [email_intermediate.public_bytes(serialization.Encoding.PEM)]
        request["leaf"] = email_leaf.public_bytes(serialization.Encoding.PEM)
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "name_constraints_violation")

    def test_leaf_cannot_have_ca_key_usage(self):
        fx = _fixture()
        bad_leaf = _cert(fx["leaf"].subject, fx["intermediate"].subject, fx["leaf"].public_key(), fx["intermediate_key"], 303, ca=False, eku=[TEST_EKU], san=["attestor.test"], key_cert_sign=True)
        request = _request(fx)
        request["leaf"] = bad_leaf.public_bytes(serialization.Encoding.PEM)
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "key_usage_invalid")

    def test_receipt_unknown_and_duplicate_json_are_rejected(self):
        fx = _fixture()
        unknown = _request(fx)
        unknown["receipt"] = dict(unknown["receipt"], unknown_field="reject-me")
        result = verify_request(unknown)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "canonical_bytes_mismatch")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate.json"
            path.write_text('{"scope":"fixture-scope","scope":"evil","source_version":"x"}', encoding="utf-8")
            duplicate = _request(fx)
            duplicate["receipt"] = str(path)
            result = verify_request(duplicate)
            self.assertEqual(result["status"], "fail_closed")
            self.assertEqual(result["error_code"], "canonical_bytes_mismatch")
            cli = subprocess.run([sys.executable, "-B", "-m", "tools.up1_external_closure_r2.pki_chain", "--request", str(path)], capture_output=True, text=True, env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
            self.assertEqual(cli.returncode, 3)
            self.assertEqual(json.loads(cli.stdout)["error_code"], "canonical_bytes_mismatch")

    def test_caller_profile_and_certificate_test_only_modes_must_agree(self):
        fx = _fixture()
        request = _request(fx)
        request["test_only"] = False
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "signature_profile_unknown")
        production_profile = {"id": "PRODUCTION-EXTERNAL-R1", "algorithm": "Ed25519", "public_key_bits": 256, "signature_encoding": "raw_64_bytes", "eku_oid": TEST_EKU, "policy_oid": TEST_POLICY, "trust_anchor": {"fingerprint_sha256": __import__("hashlib").sha256(fx["root"].public_bytes(serialization.Encoding.DER)).hexdigest()}}
        request = _request(fx)
        request["test_only"] = False
        request["profile"] = production_profile
        result = verify_request(request)
        self.assertEqual(result["status"], "fail_closed")
        self.assertEqual(result["error_code"], "signature_profile_unknown")


if __name__ == "__main__":
    unittest.main()
