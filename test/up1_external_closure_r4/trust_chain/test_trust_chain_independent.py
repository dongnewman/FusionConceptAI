"""Independent, offline adversarial tests for the R4 trust-chain verifier.

This file owns all certificate construction and expected decisions.  It does
not use implementation helpers to create fixtures, and it never mutates the
component under test.  A valid local chain is deliberately expected to remain
``unverified``/``no_publish``: this suite is software evidence only.
"""

from __future__ import annotations

import ast
import base64
import copy
import hashlib
import json
import os
import socket
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.x509.oid import NameOID, ObjectIdentifier


ROOT = Path(__file__).resolve().parents[3]
COMPONENT = ROOT / "tools" / "up1_external_closure_r4" / "trust_chain"
sys.path.insert(0, str(ROOT))
from tools.up1_external_closure_r4.trust_chain import verifier  # noqa: E402


EVAL = "2026-06-01T00:00:00Z"
UTC = timezone.utc


def _name(common_name: str) -> x509.Name:
    return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, common_name)])


def _key(bits: int = 2048) -> rsa.RSAPrivateKey:
    return rsa.generate_private_key(public_exponent=65537, key_size=bits)


def _cert(
    subject: x509.Name,
    issuer: x509.Name,
    public_key: rsa.RSAPublicKey,
    signer: rsa.RSAPrivateKey,
    *,
    ca: bool,
    path_length: int | None,
    key_cert_sign: bool,
    digital_signature: bool,
    not_before: datetime | None = None,
    not_after: datetime | None = None,
    authority_key_id: bytes | None = None,
    critical_unknown: bool = False,
    signature_hash: hashes.HashAlgorithm = hashes.SHA256(),
) -> x509.Certificate:
    before = not_before or (datetime(2025, 1, 1, tzinfo=UTC))
    after = not_after or (datetime(2028, 1, 1, tzinfo=UTC))
    builder = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(public_key)
        .serial_number(x509.random_serial_number())
        .not_valid_before(before)
        .not_valid_after(after)
        .add_extension(x509.BasicConstraints(ca=ca, path_length=path_length), critical=True)
        .add_extension(
            x509.KeyUsage(
                digital_signature=digital_signature,
                content_commitment=False,
                key_encipherment=False,
                data_encipherment=False,
                key_agreement=False,
                key_cert_sign=key_cert_sign,
                crl_sign=key_cert_sign,
                encipher_only=False,
                decipher_only=False,
            ),
            critical=True,
        )
        .add_extension(x509.SubjectKeyIdentifier.from_public_key(public_key), critical=False)
    )
    if authority_key_id is not None:
        builder = builder.add_extension(
            x509.AuthorityKeyIdentifier(key_identifier=authority_key_id, authority_cert_issuer=None, authority_cert_serial_number=None),
            critical=False,
        )
    if critical_unknown:
        builder = builder.add_extension(x509.UnrecognizedExtension(ObjectIdentifier("1.2.3.4.5.6"), b"fixture"), critical=True)
    return builder.sign(private_key=signer, algorithm=signature_hash)


def _material(cert: x509.Certificate, kind: str) -> bytes:
    return cert.public_bytes(serialization.Encoding.PEM if kind == "pem" else serialization.Encoding.DER)


def _fixture(*, kind: str = "pem", leaf_ca: bool = False, leaf_unknown_critical: bool = False,
             root_path_length: int | None = 1, intermediate_key_cert_sign: bool = True,
             bad_aki: bool = False, leaf_validity: tuple[datetime, datetime] | None = None,
             root_hash_algorithm: hashes.HashAlgorithm = hashes.SHA256(), root_bits: int = 2048,
             wrong_leaf_signature: bool = False) -> tuple[dict, dict[str, bytes], dict[str, rsa.RSAPrivateKey]]:
    root_key = _key(root_bits)
    inter_key = _key()
    leaf_key = _key()
    root_name, inter_name, leaf_name = _name("R4 Root"), _name("R4 Intermediate"), _name("R4 Leaf")
    root = _cert(root_name, root_name, root_key.public_key(), root_key, ca=True, path_length=root_path_length,
                 key_cert_sign=True, digital_signature=False, signature_hash=root_hash_algorithm)
    root_ski = root.extensions.get_extension_for_class(x509.SubjectKeyIdentifier).value.digest
    inter = _cert(inter_name, root_name, inter_key.public_key(), root_key, ca=True, path_length=0,
                  key_cert_sign=intermediate_key_cert_sign, digital_signature=False,
                  authority_key_id=(b"\x99" * len(root_ski) if bad_aki else root_ski))
    inter_ski = inter.extensions.get_extension_for_class(x509.SubjectKeyIdentifier).value.digest
    before, after = leaf_validity or (datetime(2025, 1, 1, tzinfo=UTC), datetime(2028, 1, 1, tzinfo=UTC))
    leaf_signer = root_key if wrong_leaf_signature else inter_key
    leaf = _cert(leaf_name, inter_name, leaf_key.public_key(), leaf_signer, ca=leaf_ca, path_length=None,
                 key_cert_sign=False, digital_signature=True, not_before=before, not_after=after,
                 authority_key_id=inter_ski, critical_unknown=leaf_unknown_critical)
    raws = {"root": _material(root, kind), "intermediate": _material(inter, kind), "leaf": _material(leaf, kind)}
    profile = {
        "id": "PRODUCTION-FIXTURE",
        "root_sha256": hashlib.sha256(raws["root"]).hexdigest(),
        "allowed_algorithms": ["RSA-SHA256"],
        "digest": "SHA-256",
    }
    request = {
        "root": {"raw_bytes": raws["root"]},
        "intermediates": [{"raw_bytes": raws["intermediate"]}],
        "leaf": {"raw_bytes": raws["leaf"]},
        "profile": profile,
        "evaluation_time": EVAL,
    }
    return request, raws, {"root": root_key, "intermediate": inter_key, "leaf": leaf_key}


class IndependentTrustChainTests(unittest.TestCase):
    def assert_status(self, request: dict, status: str = "unverified", code: str | None = None) -> dict:
        result = verifier.verify_request(request)
        self.assertEqual(result.get("status"), status, result)
        self.assertTrue(result.get("no_publish"), result)
        self.assertFalse(result.get("authoritative"), result)
        if code:
            self.assertEqual(result.get("error_code"), code, result)
        return result

    def test_der_and_pem_hash_raw_bytes_but_share_der_identity(self) -> None:
        pem_request, pem, _ = _fixture(kind="pem")
        der_request, der, _ = _fixture(kind="der")
        # Regenerate an equivalent chain with one fixture's certs in both encodings.
        _, _, keys = _fixture(kind="pem")
        del keys  # independent generation is intentional; raw-hash assertions below use direct material.
        pem_cert, _, _ = _fixture(kind="pem")
        # The API's explicit hash helper is the contract under test.
        from cryptography.hazmat.primitives import serialization as _serialization
        cert = x509.load_pem_x509_certificate(pem["root"])
        der_root = cert.public_bytes(_serialization.Encoding.DER)
        self.assertNotEqual(verifier.hash_raw_bytes(pem["root"]), verifier.hash_raw_bytes(der_root))
        self.assertEqual(verifier.hash_raw_bytes(der_root), verifier.hash_raw_bytes(cert.public_bytes(_serialization.Encoding.DER)))
        self.assertEqual(verifier.certificate_raw_sha256(pem["root"]), hashlib.sha256(pem["root"]).hexdigest())
        self.assertEqual(self.assert_status(pem_request)["root_raw_sha256"], hashlib.sha256(pem["root"]).hexdigest())
        # DER fixture is independently valid and its root pin is over DER bytes.
        self.assertEqual(self.assert_status(der_request)["root_raw_sha256"], hashlib.sha256(der["root"]).hexdigest())

    def test_root_pin_is_required_and_exact_raw_bytes(self) -> None:
        request, raws, _ = _fixture()
        bad = copy.deepcopy(request)
        bad["profile"]["root_sha256"] = "0" * 64
        self.assert_status(bad, "invalid", "ROOT_HASH_MISMATCH")
        no_pin = copy.deepcopy(request)
        no_pin["profile"].pop("root_sha256")
        self.assert_status(no_pin, "typed_absence", "ROOT_HASH_ABSENT")
        supplied = copy.deepcopy(request)
        supplied["root"]["raw_sha256"] = "f" * 64
        self.assert_status(supplied, "invalid", "RAW_HASH_MISMATCH")
        self.assertEqual(hashlib.sha256(raws["root"]).hexdigest(), request["profile"]["root_sha256"])

    def test_order_issuer_and_certificate_signature_are_checked(self) -> None:
        request, _, _ = _fixture()
        wrong_order = copy.deepcopy(request)
        wrong_order["chain"] = [wrong_order.pop("root"), wrong_order.pop("leaf"), wrong_order.pop("intermediates")[0]]
        self.assert_status(wrong_order, "invalid", "CHAIN_ORDER_INVALID")
        wrong_signature, _, _ = _fixture(wrong_leaf_signature=True)
        self.assert_status(wrong_signature, "invalid", "CERTIFICATE_SIGNATURE_INVALID")

    def test_ca_key_usage_and_path_length_are_fail_closed(self) -> None:
        leaf_ca, _, _ = _fixture(leaf_ca=True)
        self.assert_status(leaf_ca, "invalid", "CONSTRAINT_INVALID")
        no_sign, _, _ = _fixture(intermediate_key_cert_sign=False)
        self.assert_status(no_sign, "invalid", "CONSTRAINT_INVALID")
        path, _, _ = _fixture(root_path_length=0)
        self.assert_status(path, "invalid", "PATH_LENGTH_INVALID")

    def test_aki_ski_linkage_is_checked(self) -> None:
        request, _, _ = _fixture(bad_aki=True)
        self.assert_status(request, "invalid", "CHAIN_LINK_INVALID")

    def test_validity_uses_explicit_trusted_time_and_rejects_naive_time(self) -> None:
        expired, _, _ = _fixture(leaf_validity=(datetime(2020, 1, 1, tzinfo=UTC), datetime(2020, 1, 2, tzinfo=UTC)))
        self.assert_status(expired, "invalid", "CERTIFICATE_EXPIRED")
        missing = _fixture()[0]
        missing.pop("evaluation_time")
        # A verifier must never silently consult wall-clock time for authority-like validity.
        self.assert_status(missing, "typed_absence", "EVALUATION_TIME_ABSENT")
        naive = _fixture()[0]
        naive["evaluation_time"] = "2026-06-01T00:00:00"
        self.assert_status(naive, "invalid", "EVALUATION_TIME_INVALID")

    def test_unknown_critical_extension_is_rejected(self) -> None:
        request, _, _ = _fixture(leaf_unknown_critical=True)
        self.assert_status(request, "invalid", "CRITICAL_EXTENSION_UNKNOWN")

    def test_algorithm_downgrade_and_weak_key_are_rejected(self) -> None:
        # cryptography 44 intentionally refuses to mint SHA-1 certificates;
        # exercise the same downgrade boundary with a policy that excludes
        # the otherwise valid RSA-SHA256 chain.
        downgrade, _, _ = _fixture()
        downgrade["profile"]["allowed_algorithms"] = ["ECDSA-SHA256"]
        self.assert_status(downgrade, "invalid", "ALGORITHM_NOT_ALLOWED")
        weak, _, _ = _fixture(root_bits=1024)
        self.assert_status(weak, "invalid", "KEY_STRENGTH_INVALID")
        profile = _fixture()[0]
        profile["profile"]["allowed_algorithms"] = ["RSA-SHA1"]
        self.assert_status(profile, "invalid", "ALGORITHM_POLICY_INVALID")

    def test_detached_signature_is_checked_without_granting_authority(self) -> None:
        request, _, keys = _fixture()
        payload = b"UP1-R4 detached signed payload"
        signature = keys["leaf"].sign(payload, padding.PKCS1v15(), hashes.SHA256())
        request["payload"] = payload
        request["signature"] = {"algorithm": "RSA-SHA256", "signature_b64": base64.b64encode(signature).decode("ascii")}
        result = self.assert_status(request)
        self.assertTrue(result["signature"]["verified"])
        self.assertFalse(result["authoritative"])
        bad = copy.deepcopy(request)
        bad["signature"]["signature_b64"] = base64.b64encode(signature[:-1] + bytes([signature[-1] ^ 1])).decode("ascii")
        self.assert_status(bad, "invalid", "SIGNATURE_INVALID")
        absent = copy.deepcopy(request)
        absent["signature"] = {"algorithm": "RSA-SHA256"}
        self.assert_status(absent, "typed_absence", "SIGNATURE_ABSENT")

    def test_test_only_is_non_evidence_and_never_authoritative(self) -> None:
        request, _, _ = _fixture()
        request["mode"] = "TEST_ONLY"
        request["profile"].pop("root_sha256")
        result = self.assert_status(request)
        self.assertTrue(result["test_only"])
        self.assertTrue(result["non_evidence"])
        self.assertEqual(result["evidence_class"], "non_evidence")
        self.assertFalse(result["authoritative"])

    def test_missing_cryptography_is_typed_unavailable_and_offline(self) -> None:
        request = {"root": {"raw_b64": "AA=="}, "leaf": {"raw_b64": "AA=="}, "evaluation_time": EVAL}
        proc = subprocess.run(
            [sys.executable, "-S", "-m", "tools.up1_external_closure_r4.trust_chain"],
            input=json.dumps(request), text=True, capture_output=True, cwd=ROOT,
        )
        self.assertEqual(proc.returncode, 2, proc.stderr)
        result = json.loads(proc.stdout)
        self.assertEqual(result["status"], "typed_absence", result)
        self.assertEqual(result["error_code"], "CRYPTOGRAPHY_UNAVAILABLE", result)
        self.assertTrue(result["no_publish"])

    def test_no_system_store_or_network_surface(self) -> None:
        source = (COMPONENT / "verifier.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        imports = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imports.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imports.add(node.module.split(".")[0])
        self.assertFalse(imports & {"socket", "ssl", "urllib", "requests", "httpx", "certifi", "subprocess"})
        self.assertNotIn("load_default_certs", source)
        self.assertNotIn("create_default_context", source)
        self.assertNotIn("urlopen", source)
        old = socket.create_connection
        socket.create_connection = lambda *a, **k: (_ for _ in ()).throw(AssertionError("network used"))
        try:
            self.assert_status(_fixture()[0])
        finally:
            socket.create_connection = old

    def test_signature_helper_is_false_or_typed_for_all_bad_inputs(self) -> None:
        _, _, keys = _fixture()
        payload = b"detached"
        signature = keys["leaf"].sign(payload, padding.PKCS1v15(), hashes.SHA256())
        good = verifier.verify_signature_result(payload, signature, keys["leaf"].public_key(), "RSA-SHA256")
        self.assertTrue(good["verified"])
        self.assertFalse(good["authoritative"])
        self.assertFalse(verifier.verify_signature(payload, b"bad", keys["leaf"].public_key(), "RSA-SHA256"))
        absent = verifier.verify_signature_result(payload, None, keys["leaf"].public_key(), "RSA-SHA256")
        self.assertEqual(absent["status"], "typed_absence")


if __name__ == "__main__":
    unittest.main(verbosity=2)
