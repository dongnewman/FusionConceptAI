from __future__ import annotations
import base64, hashlib, json, os, runpy, sys
from datetime import datetime, timedelta, timezone
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ed448, ed25519, rsa, ec, padding

R1 = runpy.run_path("docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/02-pki-independent-review-r1/attack_review.py", run_name="attack_module")
cert, name, canonical, verify = R1["cert"], R1["name"], R1["canonical_json_bytes"], R1["verify_request"]

def out(case, req, expected):
    r = verify(req); return {"case":case,"expected":expected,"status":r.get("status"),"error_code":r.get("error_code"),"resolution":r.get("resolution"),"evidence_class":r.get("evidence_class"),"no_publish":r.get("no_publish")}

def ed448_prod():
    rk, ik, lk = (ed448.Ed448PrivateKey.generate() for _ in range(3)); m="PRODUCTION"
    root=cert(name("Ed448 Production Root",m),name("Ed448 Production Root",m),rk.public_key(),rk,3100,ca=True,path_length=1,policy="1.2.4")
    inter=cert(name("Ed448 Production Intermediate",m),root.subject,ik.public_key(),rk,3101,ca=True,path_length=0,policy="1.2.4")
    leaf=cert(name("Ed448 Production Attestor",m),inter.subject,lk.public_key(),ik,3102,ca=False,eku=["1.2.3"],san=["attestor.example"],policy="1.2.4")
    p={"scope":"ed448-scope","source_version":"ed448-v1","verification_id":"ed448-verification","nonce":"ed448-nonce","challenge":"ed448-challenge","sequence":1,"issued_at":datetime.now(timezone.utc).isoformat(),"expires_at":(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),"idempotency_key":"ed448-idempotency","signer_key_id":x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()}; can=canonical(p); p.update(receipt_digest_sha256=hashlib.sha256(can).hexdigest(),signature=base64.b64encode(lk.sign(can)).decode())
    prof={"id":"PRODUCTION-ED448-R1","algorithm":"Ed448","public_key_bits":456,"signature_encoding":"raw_114_bytes","eku_oid":"1.2.3","policy_oid":"1.2.4","trust_anchor":{"fingerprint_sha256":hashlib.sha256(root.public_bytes(serialization.Encoding.DER)).hexdigest()}}
    return {"profile":prof,"evaluation_time":datetime.now(timezone.utc).isoformat(),"root":root.public_bytes(serialization.Encoding.PEM),"intermediates":[inter.public_bytes(serialization.Encoding.PEM)],"leaf":leaf.public_bytes(serialization.Encoding.PEM),"receipt":p,"revocation":{"status":"good","verified":True},"trusted_time":{"verified":True,"message_imprint_sha256":p["receipt_digest_sha256"],"gen_time":datetime.now(timezone.utc).isoformat(),"policy":"1.2.3"},"replay_ledger":{"consumed_nonces":[],"last_sequence":0,"idempotency":{}}}

def rsa_hash_variant(hash_algorithm):
    rk,ik,lk=(rsa.generate_private_key(public_exponent=65537,key_size=2048) for _ in range(3)); m="PRODUCTION"
    root=cert(name("Hash Production Root",m),name("Hash Production Root",m),rk.public_key(),rk,3200,ca=True,path_length=1,policy="1.2.4",algorithm=hash_algorithm); inter=cert(name("Hash Production Intermediate",m),root.subject,ik.public_key(),rk,3201,ca=True,path_length=0,policy="1.2.4",algorithm=hash_algorithm); leaf=cert(name("Hash Production Attestor",m),inter.subject,lk.public_key(),ik,3202,ca=False,eku=["1.2.3"],san=["attestor.example"],policy="1.2.4",algorithm=hash_algorithm)
    p={"scope":"hash-scope","source_version":"hash-v1","verification_id":"hash-verification","nonce":"hash-nonce","challenge":"hash-challenge","sequence":1,"issued_at":datetime.now(timezone.utc).isoformat(),"expires_at":(datetime.now(timezone.utc)+timedelta(days=1)).isoformat(),"idempotency_key":"hash-idempotency","signer_key_id":x509.SubjectKeyIdentifier.from_public_key(lk.public_key()).digest.hex()}; can=canonical(p); p.update(receipt_digest_sha256=hashlib.sha256(can).hexdigest(),signature=base64.b64encode(lk.sign(can,padding.PKCS1v15(),hashes.SHA256())).decode())
    prof={"id":"PRODUCTION-RSA-HASH-R1","algorithm":"RSA","public_key_bits":2048,"signature_encoding":"pkcs1v15-sha256","eku_oid":"1.2.3","policy_oid":"1.2.4","trust_anchor":{"fingerprint_sha256":hashlib.sha256(root.public_bytes(serialization.Encoding.DER)).hexdigest()}}
    return {"profile":prof,"evaluation_time":datetime.now(timezone.utc).isoformat(),"root":root.public_bytes(serialization.Encoding.PEM),"intermediates":[inter.public_bytes(serialization.Encoding.PEM)],"leaf":leaf.public_bytes(serialization.Encoding.PEM),"receipt":p,"revocation":{"status":"good","verified":True},"trusted_time":{"verified":True,"message_imprint_sha256":p["receipt_digest_sha256"],"gen_time":datetime.now(timezone.utc).isoformat(),"policy":"1.2.3"},"replay_ledger":{"consumed_nonces":[],"last_sequence":0,"idempotency":{}}}

def main():
    outv=[]; prod=R1["production_rsa_fixture"](2048)
    outv.append(out("ed448_production_allowed",ed448_prod(),"valid_for_declared_scope"))
    outv.append(out("rsa_sha384_certificate_hash",rsa_hash_variant(hashes.SHA384()),"fail_closed"))
    for value in ("rsa","RSA-SHA256","RSA-PKCS1v15-SHA256","Ed25519","ed448","ECDSA-SHA256","RSA-SHA1","RSA-MD5","RSA-MD2","UNKNOWN"):
        req=R1["production_rsa_fixture"](2048); req["profile"]=dict(req["profile"],algorithm=value,id="PRODUCTION-ALG-VARIANT-R1"); outv.append(out("profile_algorithm_variant_"+value.replace("/","_"),req,"fail_closed"))
    for field in ("algorithm","signature_algorithm"):
        req=R1["production_rsa_fixture"](2048); rec=dict(req["receipt"]); rec[field]="ECDSA"; req["receipt"]=rec; outv.append(out("receipt_"+field+"_mismatch",req,"fail_closed"))
    req=R1["production_rsa_fixture"](2048); req["profile"]=dict(req["profile"],signature_algorithm="ECDSA"); outv.append(out("profile_signature_algorithm_mismatch",req,"fail_closed"))
    print(json.dumps({"pid":os.getpid(),"python":sys.version.split()[0],"started_utc":datetime.now(timezone.utc).isoformat(),"cases":outv},ensure_ascii=False,sort_keys=True,separators=(",",":")))
if __name__=="__main__": main()
