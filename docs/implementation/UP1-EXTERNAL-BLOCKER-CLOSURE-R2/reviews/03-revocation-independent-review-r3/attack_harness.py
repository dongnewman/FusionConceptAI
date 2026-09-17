"""Independent R3 checks; TEST_ONLY/non_evidence only."""
from __future__ import annotations
import json, os, subprocess, sys, tempfile
from pathlib import Path
ROOT = Path(__file__).resolve().parents[5]; MODULE = ROOT / "tools" / "up1_external_closure_r2" / "revocation_time_replay"; sys.path.insert(0, str(MODULE))
from core import PersistentReplayLedger, canonical_bytes, canonical_digest, validate  # noqa: E402
KEY = bytes(range(32)); ASOF = "2026-09-17T12:00:00Z"
def fixture(seq=1, nonce="nonce-001", idem="idem-001"):
    r={"verification_id":"v-001","nonce":nonce,"challenge":"challenge-001","scope":{"candidate":"c-001","source":"attestor-A"},"source":"attestor-A","source_version":{"version":"source-v1","hash":"abc123"},"sequence":seq,"issued_at":"2026-09-17T11:59:00Z","expires_at":"2026-09-17T12:10:00Z","idempotency_key":idem,"payload":{"value":3}}; d=canonical_digest(r)
    return {"schema":"UP1-R2.revocation-time-replay.v1","profile":"TEST_ONLY-W2-R1","test_only":True,"receipt":r,"receipt_signature_valid":True,"clock_skew_seconds":2,"replay_window":{"duration_seconds":3600,"trusted_time_basis":"signed_receipt"},"trusted_time_receipt":{"available":True,"profile":"rfc3161","gen_time":ASOF,"receipt_digest":d,"message_imprint":d,"nonce":nonce,"challenge":"challenge-001","policy":"TEST_ONLY-TSA","signature_valid":True,"chain_valid":True,"revocation_valid":True},"revocation_receipt":{"available":True,"kind":"crl","status":"good","issuer":"CA-TEST_ONLY","serial":"7","certificate_serial":"7","crl_number":"1","this_update":"2026-09-17T11:00:00Z","next_update":"2026-09-17T13:00:00Z","signature_valid":True,"issuer_binding_valid":True}}
def refresh(p):
    d=canonical_digest(p["receipt"]); p["trusted_time_receipt"]["receipt_digest"]=d; p["trusted_time_receipt"]["message_imprint"]=d; p["trusted_time_receipt"]["nonce"]=p["receipt"]["nonce"]; return p
def s(case,o,exit_code=None):
    x={"case":case,"result":o.get("result"),"status":o.get("status"),"error_code":o.get("error_code")};
    if exit_code is not None:x["exit"]=exit_code
    return x
def cli(path,payload,ledger,key):
    p=subprocess.run([sys.executable,"-B",str(path),"--ledger",str(ledger),"--key",str(key)],input=json.dumps(payload,separators=(",",":")),text=True,capture_output=True); return p.returncode,json.loads(p.stdout)
def signed(path,state,key):
    l=PersistentReplayLedger(path,key_path=key); path.write_text(json.dumps(l._envelope(state,KEY),separators=(",",":")),encoding="utf-8")
def main():
    cli_path=MODULE/"cli.py"; rows=[]
    with tempfile.TemporaryDirectory(prefix="up1-r3-review-") as td0:
        td=Path(td0); key=td/"trusted.key"; key.write_bytes(KEY); ledger=td/"ledger.json"; rc,o=cli(cli_path,fixture(),ledger,key); rows.append(s("baseline",o,rc)); rc,o=cli(cli_path,fixture(),ledger,key); rows.append(s("same_key_same_digest_replayed",o,rc)); rc,o=cli(cli_path,fixture(seq=2,nonce="nonce-002",idem="idem-002"),ledger,key); rows.append(s("next_sequence",o,rc)); rc,o=cli(cli_path,fixture(seq=100,nonce="nonce-003",idem="idem-003"),ledger,key); rows.append(s("sequence_gap",o,rc))
        scope='{"candidate":"c-001","source":"attestor-A"}'; e1={"scope":scope,"source":"attestor-A","nonce":"n1","sequence":1,"idempotency_key":"same","canonical_digest":"a"*64,"result_digest":"b"*64}; e2={"scope":scope,"source":"attestor-A","nonce":"n2","sequence":2,"idempotency_key":"same","canonical_digest":"c"*64,"result_digest":"d"*64}; st={"nonces":{scope:["n1","n2"]},"sequences":{scope:2},"idempotency":{"same":{"canonical_digest":"c"*64,"result_digest":"d"*64}},"entries":[e1,e2]}; p=td/"dup-idem.json";signed(p,st,key);rc,o=cli(cli_path,fixture(seq=3,nonce="n3",idem="n3"),p,key);rows.append(s("hmac_valid_duplicate_idempotency",o,rc))
        e4=dict(e1);e4.update(sequence=2,idempotency_key="other");st={"nonces":{scope:["n1","n1"]},"sequences":{scope:2},"idempotency":{"same":{"canonical_digest":"a"*64,"result_digest":"b"*64},"other":{"canonical_digest":"a"*64,"result_digest":"b"*64}},"entries":[e1,e4]};p=td/"dup-nonce.json";signed(p,st,key);rc,o=cli(cli_path,fixture(seq=3,nonce="n3",idem="n3"),p,key);rows.append(s("hmac_valid_duplicate_nonce",o,rc))
        p=td/"index-mismatch.json";signed(p,{"nonces":{},"sequences":{},"idempotency":{},"entries":[e1]},key);rc,o=cli(cli_path,fixture(seq=2,nonce="n2",idem="n2"),p,key);rows.append(s("hmac_valid_index_mismatch",o,rc))
        rc,o=cli(cli_path,fixture(),td/"missing.json",td/"missing-key");rows.append(s("key_missing",o,rc)); auto=PersistentReplayLedger(td/"auto.json"); ao=validate(fixture(),ledger=auto);rows.append({"case":"automatic_key_generation","result":ao.get("result"),"status":ao.get("status"),"error_code":ao.get("error_code"),"key_created":auto.key_path is not None and auto.key_path.exists()})
        p=td/"replace.json";rc,o=cli(cli_path,fixture(),p,key);key.write_bytes(bytes([255-x for x in range(32)]));rc2,o2=cli(cli_path,fixture(seq=2,nonce="r2",idem="r2"),p,key);rows.append({"case":"key_replacement","first_exit":rc,"second_exit":rc2,"second":s("replacement",o2)})
        os.chmod(key,0o644);rc,o=cli(cli_path,fixture(),td/"perms.json",key);rows.append(s("owner_permissions_0644",o,rc))
        link=td/"link.key";try_link={"case":"trusted_key_symlink","skipped":False}
        try:os.symlink(key,link)
        except (OSError,NotImplementedError) as exc:try_link.update(skipped=True,reason=type(exc).__name__)
        else:try_link.update(s("symlink",validate(fixture(),ledger=PersistentReplayLedger(td/"link.json",key_path=link))))
        rows.append(try_link);base=json.dumps(fixture(),separators=(",",":"));dup=base.replace('"sequence":1,"issued_at"','"sequence":1,"sequence":1,"issued_at"',1);q=subprocess.run([sys.executable,"-B",str(cli_path),"--ledger",str(td/"dup-cli.json"),"--key",str(key)],input=dup,text=True,capture_output=True);rows.append({"case":"duplicate_json_cli","exit":q.returncode,**s("duplicate",json.loads(q.stdout))});nan=base.replace('"duration_seconds":3600','"duration_seconds":NaN');q=subprocess.run([sys.executable,"-B",str(cli_path),"--ledger",str(td/"nan-cli.json"),"--key",str(key)],input=nan,text=True,capture_output=True);rows.append({"case":"nonfinite_json_cli","exit":q.returncode,**s("nan",json.loads(q.stdout))})
        wrong=fixture();wrong["receipt"]["source"]=123;refresh(wrong);rc,o=cli(cli_path,wrong,td/"wrong-source.json",key);rows.append(s("source_type_cli",o,rc));u=fixture();u["revocation_receipt"]["available"]="false";rc,o=cli(cli_path,u,td/"available-string.json",key);rows.append(s("revocation_available_string",o,rc));oc=fixture();oc["revocation_receipt"]={"available":True,"kind":"ocsp","status":"good","issuer":"CA-TEST_ONLY","serial":"7","this_update":"2026-09-17T11:00:00Z","next_update":"2026-09-17T13:00:00Z","produced_at":"2026-09-17T11:30:00Z","signature_valid":True,"issuer_binding_valid":True,"responder_signature_valid":True,"chain_valid":True};rc,o=cli(cli_path,oc,td/"ocsp.json",key);rows.append(s("ocsp_valid",o,rc));oc["revocation_receipt"]["chain_valid"]=False;rc,o=cli(cli_path,oc,td/"ocsp-bad.json",key);rows.append(s("ocsp_bad_chain",o,rc))
        con=td/"concurrent.json";raw=json.dumps(fixture(),separators=(",",":"));ps=[subprocess.Popen([sys.executable,"-B",str(cli_path),"--ledger",str(con),"--key",str(key)],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True) for _ in range(2)];obs=[]
        for proc in ps:so,se=proc.communicate(raw);obs.append({"exit":proc.returncode,**s("concurrent",json.loads(so))})
        rows.append({"case":"two_process_atomic_cas","observed":obs})
    print(json.dumps({"TEST_ONLY":True,"non_evidence":True,"pid":os.getpid(),"parent_pid":os.getppid(),"rows":rows},sort_keys=True,separators=(",",":")));return 0
if __name__=="__main__":raise SystemExit(main())
