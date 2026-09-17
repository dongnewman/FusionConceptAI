from __future__ import annotations
import json, os, subprocess, sys
from pathlib import Path
from tools.up1_external_closure_r2.integration.runner import run_pipeline, receipt_digest, state_digest
from tools.up1_external_closure_r2.integration.runner import _aggregate_document, _stage_record
from tools.up1_external_closure_r2.aggregate_gate.aggregate_gate import aggregate_document

def package(role="PRODUCTION"):
    return {"schema":"UP1-R2.integration-input.v1", "version":"v1", "candidate_id":"candidate://integration", "source_ref":"repo://integration", "source_version":"v1", "fixture_role":role}

def anchors():
    return {"candidate_fingerprint":"2"*64, "source_fingerprint":"3"*64, "expected_context_sha256":"0"*64, "trust_anchor":{}, "trust_anchor_sha256":"1"*64}

def test_missing_production_inputs_are_typed_absent_and_no_publish():
    r=run_pipeline(package())
    assert r["status"] == "terminal_deferred" and r["no_publish"] and not r["new_ad"]
    assert all(v["status"] in {"verified","typed_absence","terminal_deferred"} for v in r["stages"].values())

def test_strict_root_rejects_unknown_and_wrong_version():
    p=package(); p["_adapter_result"]=True
    assert run_pipeline(p)["status"] == "fail_closed"
    a=anchors(); a["candidate_fingerprint"]="x"*64; a["source_fingerprint"]="y"*64
    assert run_pipeline(package(), expected_context={}, anchors=a, ledger_path="missing-ledger.json", key_path="missing-key", intake_spool=".")["status"] == "fail_closed"
    p=package(); p["version"]="forged"
    assert run_pipeline(p)["status"] == "fail_closed"

def test_test_only_never_promotes_without_independent_anchors():
    r=run_pipeline(package("TEST_ONLY"))
    assert r["status"] == "terminal_deferred" and r["TEST_ONLY"] and r["non_evidence"]

def test_real_component_path_has_no_precomputed_stage_bypass(tmp_path):
    p=package(); p["witness"]={"status":"verified","authority_verified":True}
    r=run_pipeline(p, expected_context={}, anchors=anchors(), ledger_path=tmp_path/"ledger.json", key_path=tmp_path/"key", intake_spool=tmp_path)
    assert r["status"] == "fail_closed"

def test_changed_input_requires_authenticated_ledger(tmp_path):
    key=tmp_path/"key"; key.write_bytes(b"test-key")
    first=run_pipeline(package(), expected_context={}, anchors=anchors(), ledger_path=tmp_path/"ledger.json", key_path=key, intake_spool=tmp_path)
    altered=package(); altered["source_version"]="v2"
    second=run_pipeline(altered, expected_context={}, anchors=anchors(), ledger_path=tmp_path/"ledger.json", key_path=key, intake_spool=tmp_path, prior_state=first)
    assert second["status"] == "terminal_deferred" and second["event"] == "intake_changed" and not second["new_ad"]

def test_receipt_and_state_hashes_recompute_from_returned_object(tmp_path):
    r=run_pipeline(package())
    assert r["receipt_sha256"] == receipt_digest(r)
    assert r["receipt_hash"] == r["receipt_sha256"]
    assert r["state_hash"] == state_digest(r)

def test_tampered_authenticated_ledger_is_fail_closed(tmp_path):
    key=tmp_path/"key"; key.write_bytes(b"integration-test-key")
    ledger=tmp_path/"ledger.json"
    first=run_pipeline(package(), expected_context={}, anchors=anchors(), ledger_path=ledger, key_path=key, intake_spool=tmp_path)
    raw=json.loads(ledger.read_text(encoding="utf-8")); raw["latest"]["new_ad"]=True; ledger.write_text(json.dumps(raw), encoding="utf-8")
    result=run_pipeline(package(), expected_context={}, anchors=anchors(), ledger_path=ledger, key_path=key, intake_spool=tmp_path)
    assert result["status"] == "fail_closed"

def test_prior_state_requires_complete_canonical_equality(tmp_path):
    key=tmp_path/"key"; key.write_bytes(b"integration-test-key"); ledger=tmp_path/"ledger.json"
    first=run_pipeline(package(), expected_context={}, anchors=anchors(), ledger_path=ledger, key_path=key, intake_spool=tmp_path)
    forged=dict(first); forged["status"]="eligible_for_authority_recheck"
    result=run_pipeline(package(), expected_context={}, anchors=anchors(), ledger_path=ledger, key_path=key, intake_spool=tmp_path, prior_state=forged)
    assert result["status"] == "fail_closed"

def test_aggregate_public_api_reaches_verified_structure_without_credit():
    fp={"candidate":"2"*64,"source":"3"*64,"input":"4"*64}
    records={s:_stage_record(s,{"status":"verified","schema":"component.test.v1","authority_verified":True,"candidate_fingerprint":fp["candidate"],"source_fingerprint":fp["source"],"input_fingerprint":fp["input"],"claim_ceiling":"preparation_only"}) for s in ("witness","g2","environment","intake")}
    result=aggregate_document(_aggregate_document(fp,records))
    assert result["status"] == "verified"
    assert result["resolution"] == "eligible_for_authority_recheck"
    assert result["claims"]["T0"] is False and result["ad_created"] is False

def test_two_process_cas_allows_one_commit_and_other_conflict_or_noop(tmp_path):
    path=tmp_path/"package.json"; path.write_text(json.dumps(package(), sort_keys=True), encoding="utf-8")
    key=tmp_path/"key"; key.write_bytes(b"integration-test-key")
    code="import json; from pathlib import Path; from tools.up1_external_closure_r2.integration.runner import run_pipeline; r=run_pipeline(json.loads(Path(r'''%s''').read_text()), expected_context={}, anchors={'candidate_fingerprint':'%s','source_fingerprint':'%s','expected_context_sha256':'%s','trust_anchor':{},'trust_anchor_sha256':'%s'}, ledger_path=r'''%s''', key_path=r'''%s''', intake_spool=r'''%s'''); print(json.dumps({'event':r.get('event'),'status':r.get('status'),'error_code':r.get('error_code'),'new_ad':r.get('new_ad')},sort_keys=True,separators=(',',':')))" % (path,"2"*64,"3"*64,"0"*64,"1"*64,tmp_path/"cas.json",key,tmp_path)
    env=dict(os.environ, PYTHONPATH=str(Path.cwd()))
    procs=[subprocess.Popen([sys.executable,"-B","-c",code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env) for _ in range(2)]
    rows=[json.loads(p.communicate(timeout=10)[0]) for p in procs]
    assert sum(row["event"] == "intake" for row in rows) == 1
    assert all(row["new_ad"] is False for row in rows)
    assert any(row["event"] in {"rejected","deterministic_noop"} for row in rows)

def test_two_process_same_frozen_missing_input_is_semantically_stable(tmp_path):
    path=tmp_path/"package.json"; path.write_text(json.dumps(package("TEST_ONLY"), sort_keys=True), encoding="utf-8")
    key=tmp_path/"key"; key.write_bytes(b"integration-test-key")
    code="import json; from pathlib import Path; from tools.up1_external_closure_r2.integration.runner import run_pipeline; r=run_pipeline(json.loads(Path(r'''%s''').read_text()), expected_context={}, anchors={'expected_context_sha256':'%s','trust_anchor':{},'trust_anchor_sha256':'%s'}, ledger_path=r'''%s''', key_path=r'''%s''', intake_spool=r'''%s'''); print(json.dumps({'status':r['status'],'input_fingerprint':r['input_fingerprint'],'stages':{k:v['receipt_sha256'] for k,v in r['stages'].items()}},sort_keys=True,separators=(',',':')))" % (path, "0"*64, "1"*64, tmp_path/"ledger.json", key, tmp_path)
    env=dict(os.environ, PYTHONPATH=str(Path.cwd()))
    a=subprocess.check_output([sys.executable,"-B","-c",code], text=True, env=env).strip()
    b=subprocess.check_output([sys.executable,"-B","-c",code], text=True, env=env).strip()
    assert a==b
