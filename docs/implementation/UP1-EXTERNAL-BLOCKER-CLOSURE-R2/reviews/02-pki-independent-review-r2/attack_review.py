from __future__ import annotations

import base64
import hashlib
import json
import os
import runpy
import sys
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, ed25519, padding, rsa
from cryptography.x509.oid import ExtensionOID, ObjectIdentifier

R1 = runpy.run_path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/02-pki-independent-review-r1/attack_review.py", run_name="attack_module")
cert, name, fixture, pems = (R1[k] for k in ("cert", "name", "fixture", "pems"))
canonical_json_bytes, verify_request = R1["canonical_json_bytes"], R1["verify_request"]
TEST_EKU, TEST_POLICY = R1["TEST_EKU"], R1["TEST_POLICY"]


def result(case, req, expected):
    r = verify_request(req)
    return {"case": case, "expected": expected, "status": r.get("status"), "error_code": r.get("error_code"), "resolution": r.get("resolution"), "evidence_class": r.get("evidence_class"), "no_publish": r.get("no_publish")}


def reissue_with_ku(original, signer, signer_key, *, key_cert_sign=False, crl_sign=False):
    b = x509.CertificateBuilder().subject_name(original.subject).issuer_name(original.issuer).public_key(original.public_key()).serial_number(original.serial_number).not_valid_before(original.not_valid_before_utc).not_valid_after(original.not_valid_after_utc)
    for ext in original.extensions:
        if ext.oid != ExtensionOID.KEY_USAGE:
            b = b.add_extension(ext.value, ext.critical)
    b = b.add_extension(x509.KeyUsage(digital_signature=True, content_commitment=False, key_encipherment=False, data_encipherment=False, key_agreement=False, key_cert_sign=key_cert_sign, crl_sign=crl_sign, encipher_only=False, decipher_only=False), critical=True)
    return b.sign(signer_key, algorithm=None)


def ec_production(curve):
    rk, ik, lk = (ec.generate_private_key(curve) for _ in range(3))
    marker = "PRODUCTION"
    root = cert(name("EC Production Root", marker), name("EC Production Root", marker), rk.public_key(), rk, 2100, ca=True, path_length=1, policy="1.2.4", algorithm=hashes.SHA256())
    inter = cert(name("EC Production Intermediate", marker), root.subject, ik.public_key(), rk, 2101, ca=True, path_length=0, policy="1.2.4", algorithm=hashes.SHA256())
    leaf = cert(name("EC Production Attestor", marker), inter.subject, lk.public_key(), ik, 2102, ca=False, eku=["1.2.3"], san=["attestor.example"], policy="1.2.4", algorithm=hashes.SHA256())
    payload = {"scope":"ec-scope","source_version":"ec-v1","verification_id":"ec-verification","nonce":"ec-nonce","challenge":"ec-challenge","sequence":1,"issued_at":datetime.now(timezone.utc).isoformat(),"expires_at":(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),"idempotency_key":"ec-idempotency","signer_key_id":x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()}
    can = canonical_json_bytes(payload)
    payload.update(receipt_digest_sha256=hashlib.sha256(can).hexdigest(), signature=base64.b64encode(lk.sign(can, ec.ECDSA(hashes.SHA256()))).decode())
    profile = {"id":"PRODUCTION-EC-R1","algorithm":"ECDSA","public_key_bits":curve.key_size,"signature_encoding":"der","eku_oid":"1.2.3","policy_oid":"1.2.4","trust_anchor":{"fingerprint_sha256":hashlib.sha256(root.public_bytes(serialization.Encoding.DER)).hexdigest()}}
    return {"profile":profile,"evaluation_time":datetime.now(timezone.utc).isoformat(),"root":root.public_bytes(serialization.Encoding.PEM),"intermediates":[inter.public_bytes(serialization.Encoding.PEM)],"leaf":leaf.public_bytes(serialization.Encoding.PEM),"receipt":payload,"revocation":{"status":"good","verified":True},"trusted_time":{"verified":True,"message_imprint_sha256":payload["receipt_digest_sha256"],"gen_time":datetime.now(timezone.utc).isoformat(),"policy":"1.2.3"},"replay_ledger":{"consumed_nonces":[],"last_sequence":0,"idempotency":{}}}


def weak_hash_profile():
    req = R1["production_rsa_fixture"](2048)
    # The verifier accepts an RSA-SHA1 policy token and still verifies receipt
    # with SHA-256; a weak hash identifier must be rejected by profile policy.
    req["profile"] = dict(req["profile"], id="PRODUCTION-RSA-SHA1-R1", algorithm="RSA-SHA1")
    return req


def main():
    f = fixture(); base = f["req"]; out = []
    # Re-run every R1 attack using the returned current verifier.
    # The R1 harness itself is invoked by the command wrapper in the evidence run.
    out.append(result("rsa_2048_production_baseline", R1["production_rsa_fixture"](2048), "valid_for_declared_scope"))
    out.append(result("rsa_1024_production", R1["production_rsa_fixture"](1024), "fail_closed"))
    out.append(result("ec_p256_production_baseline", ec_production(ec.SECP256R1()), "valid_for_declared_scope"))
    out.append(result("ec_secp256k1_unapproved_curve", ec_production(ec.SECP256K1()), "fail_closed"))
    out.append(result("profile_sha1_weak_hash", weak_hash_profile(), "fail_closed"))
    for label, issued, expires in (("receipt_issued_after_expires", "2026-09-18T00:00:00Z", "2026-09-17T00:00:00Z"), ("receipt_issued_malformed", "not-a-time", "2026-09-18T00:00:00Z")):
        req = dict(base); rec = dict(f["receipt"]); rec["issued_at"], rec["expires_at"] = issued, expires; signed = dict(rec); signed.pop("receipt_digest_sha256"); signed.pop("signature"); can = canonical_json_bytes(signed); rec["receipt_digest_sha256"] = hashlib.sha256(can).hexdigest(); rec["signature"] = base64.b64encode(f["lk"].sign(can)).decode(); out.append(result(label, dict(req, evaluation_time="2026-09-17T12:00:00Z", receipt=rec), "fail_closed"))
    for label, gen in (("trusted_gen_time_before_issued", "1999-01-01T00:00:00Z"), ("trusted_gen_time_after_expires", "2099-01-01T00:00:00Z"), ("trusted_gen_time_malformed", "bad-time")):
        req = R1["production_rsa_fixture"](2048); req["trusted_time"] = dict(req["trusted_time"], gen_time=gen); out.append(result(label, req, "fail_closed"))
    # Exact mailbox, subdomain, and look-alike domain constraints.
    for label, constraint, mailbox, expected in (("rfc822_exact_mailbox", "user@example.com", "user@example.com", "valid_for_declared_scope"), ("rfc822_subdomain", "example.com", "user@sub.example.com", "valid_for_declared_scope"), ("rfc822_notexample", "example.com", "user@notexample.com", "fail_closed")):
        ek, lk = ed25519.Ed25519PrivateKey.generate(), ed25519.Ed25519PrivateKey.generate(); inter = cert(name("UP1 TEST_ONLY Email Intermediate"), f["root"].subject, ek.public_key(), f["rk"], 2301, ca=True, path_length=0, name_constraints=x509.NameConstraints(permitted_subtrees=[x509.RFC822Name(constraint)], excluded_subtrees=None)); leaf = cert(name("UP1 TEST_ONLY Email Attestor"), inter.subject, lk.public_key(), ek, 2302, ca=False, eku=[TEST_EKU], email_san=[mailbox]); rec = dict(f["receipt"], signer_key_id=x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()); rec.pop("receipt_digest_sha256"); rec.pop("signature"); can=canonical_json_bytes(rec); rec["receipt_digest_sha256"]=hashlib.sha256(can).hexdigest(); rec["signature"]=base64.b64encode(lk.sign(can)).decode(); out.append(result(label, dict(base, intermediates=[inter.public_bytes(serialization.Encoding.PEM)], leaf=leaf.public_bytes(serialization.Encoding.PEM), receipt=rec), expected))
    for bit in ("key_cert_sign", "crl_sign"):
        leaf = reissue_with_ku(f["leaf"], f["ik"], f["ik"], **{bit:True}); out.append(result("leaf_"+bit+"_only", dict(base, leaf=leaf.public_bytes(serialization.Encoding.PEM)), "fail_closed"))
    # Unknown critical extension at each certificate level.
    bad_root = cert(name("UP1 TEST_ONLY Bad Root"), name("UP1 TEST_ONLY Bad Root"), f["rk"].public_key(), f["rk"], 2401, ca=True, path_length=1, unknown_critical=True); out.append(result("unknown_critical_root", dict(base, root=bad_root.public_bytes(serialization.Encoding.PEM)), "fail_closed"))
    bad_inter = cert(name("UP1 TEST_ONLY Bad Intermediate"), f["root"].subject, f["ik"].public_key(), f["rk"], 2402, ca=True, path_length=0, unknown_critical=True); leaf = cert(name("UP1 TEST_ONLY Bad Leaf"), bad_inter.subject, f["lk"].public_key(), f["ik"], 2403, ca=False, eku=[TEST_EKU], san=["attestor.test"]); out.append(result("unknown_critical_intermediate", dict(base, intermediates=[bad_inter.public_bytes(serialization.Encoding.PEM)], leaf=leaf.public_bytes(serialization.Encoding.PEM)), "fail_closed"))
    # Unknown fields at every JSON envelope level.
    for field, key in (("profile_unknown", "profile"), ("receipt_unknown", "receipt"), ("trust_anchor_unknown", "profile"), ("revocation_unknown", "revocation"), ("trusted_time_unknown", "trusted_time"), ("ledger_unknown", "replay_ledger")):
        req = R1["production_rsa_fixture"](2048); req[key] = dict(req[key]); target = req[key]["trust_anchor"] if key == "profile" and field == "trust_anchor_unknown" else req[key]; target["unknown_field"] = "reject-me"; out.append(result(field, req, "fail_closed"))
    # Duplicate profile and receipt JSON files must be rejected by the parser.
    for label, key in (("duplicate_profile_json", "profile"), ("duplicate_receipt_json", "receipt")):
        req = R1["production_rsa_fixture"](2048)
        obj = req[key]
        text = json.dumps(obj, separators=(",", ":"), sort_keys=True)
        first = next(iter(obj))
        raw = text[:-1] + "," + json.dumps(first) + ":" + json.dumps(obj[first]) + "}"
        with tempfile.NamedTemporaryFile("w", suffix=".json", encoding="utf-8", delete=False) as h:
            h.write(raw)
            path = h.name
        try: req[key] = path; out.append(result(label, req, "fail_closed"))
        finally: Path(path).unlink(missing_ok=True)
    # Caller/profile mismatch in both directions.
    req = dict(base); req["test_only"] = False; out.append(result("test_only_profile_caller_production", req, "fail_closed"))
    req = R1["production_rsa_fixture"](2048); req["test_only"] = True; out.append(result("production_profile_caller_test_only", req, "fail_closed"))
    print(json.dumps({"pid":os.getpid(),"python":sys.version.split()[0],"started_utc":datetime.now(timezone.utc).isoformat(),"cases":out}, ensure_ascii=False, sort_keys=True, separators=(",", ":")))


if __name__ == "__main__": main()
