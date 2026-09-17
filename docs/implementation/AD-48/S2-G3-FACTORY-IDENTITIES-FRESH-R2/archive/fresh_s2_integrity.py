import hashlib, json, pathlib, subprocess, sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[5]
OUT = ROOT / 'docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2'
scopes = ('realization','control','binding','bundle')
expected_old = {
 'realization': ('19ea4b7ec669da116c09293afa8e861de47650c83a756670d906f048a67cb1fd','e8ed40a06adf41ffc7f54ad83ad400ef7fc2c43d4047b8abb9e4819513fe87ee'),
 'control': ('2f6f3cbf4c31aaf893f070df9909b21be859062cbfa697fc76886b6906980021','cf01d5a328cee5d9d60a8c88d08a433be3b4567d2990cf63a34a23b6fcccc8a0'),
 'binding': ('05ae8d811483cde640c2c8b5dcf1ec167a4d0dc9f39c7616d01e99fd9085e624','3195387030f73cf6d3717902bc3242e24b68afef81e166002c6347115cad1bbf'),
 'bundle': ('9c33dee9ff48ef8c34afe9f08f5a23e4f08d849a39bd11bb366aceedabf28807','8faff2c23c017ab6801d4c4bb8a6a5eaeb6531a23d6b5d210b25386be236ca36'),
}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def sha_text(s): return hashlib.sha256(s.encode()).hexdigest()
def canonical(x): return json.dumps(x, ensure_ascii=False, sort_keys=True, separators=(',',':'))
checks=[]
def ok(name, value=True): checks.append({'name':name,'pass':bool(value)}); assert value, name
for scope in scopes:
    ip=OUT/scope/'factory_identity_v1.json'; rp=OUT/scope/'construction_receipt.json'
    for p in (ip,rp):
        ok(f'exists:{p.name}:{scope}',p.is_file()); raw=p.read_bytes(); ok(f'no_lf:{p.name}:{scope}',not raw.endswith(b'\n')); j=json.loads(raw); ok(f'sha_length:{p.name}:{scope}',len(sha(p))==64)
    i=json.loads(ip.read_text()); r=json.loads(rp.read_text())
    ok(f'identity_result:{scope}',i['result']=='PresentG3FactoryIdentityV1'); ok(f'receipt_result:{scope}',r['result']=='PresentG3FactoryConstructionReceiptV1')
    ok(f'identity_semantic_hash:{scope}',i['semantic_hash']==sha_text(canonical(i['semantic_body'])))
    ok(f'receipt_semantic_hash:{scope}',r['semantic_hash']==sha_text(canonical(r['semantic_body'])))
    ok(f'identity_no_candidate:{scope}',i['candidate_identity_created'] is False and i['final_candidate_or_package_declaration_hash_created'] is False)
    ok(f'receipt_no_trust:{scope}',r['trusted_attestation_created'] is False and r['candidate_identity_created'] is False)
    ok(f'identity_decl_ref:{scope}',i['source_declaration_ref'].endswith('/ad48-s2-fresh-r2'))
    ok(f'identity_decl_hash:{scope}',i['g3_source_declaration_hash']==i['semantic_body']['source_declaration_hash']['value'])
    ok(f'receipt_decl_hash:{scope}',r['g3_source_declaration_hash']==r['semantic_body']['source_declaration_hash']['value'])
    ok(f'identity_receipt_decl_equal:{scope}',i['g3_source_declaration_hash']==r['g3_source_declaration_hash'])
    ok(f'binding_digest_present:{scope}',len(i['g3_source_contract_binding_digest'])==64)
    ok(f'content_digest_present:{scope}',len(i['source_content_digest'])==64 and i['source_content_digest']==r['source_content_digest'])
    loc=i['semantic_body']['locator']; src=ROOT / pathlib.PurePosixPath(loc['source_path'])
    ok(f'source_bytes:{scope}',src.stat().st_size==loc['source_bytes']); ok(f'source_sha:{scope}',sha(src)==loc['source_sha256']['value'])
    ok(f'git_freshness:{scope}',i['git_freshness']['observed_head']=='4b69f55f7f80240147a65a22809dc1207824dde2' and i['git_freshness']['working_tree_status']=='untracked')
    ok(f'root_acceptance_input:{scope}',sha(ROOT/'docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/root_acceptance_r3/manifest.json')==i['inputs']['f0']['root_acceptance_manifest']['sha256'])
for p, expected in ((ROOT/'src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl','1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4'),(ROOT/'test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl','02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f')): ok('F0_hash:'+p.name,sha(p)==expected)
env=ROOT/'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json'; ok('AD45_envelope_hash',sha(env)=='17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc' and env.stat().st_size==9612)
for scope, (ih,rh) in expected_old.items():
    ok('old_S2_identity_unchanged:'+scope,sha(ROOT/f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_identity_v1.json')==ih)
    ok('old_S2_receipt_unchanged:'+scope,sha(ROOT/f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_construction_receipt.json')==rh)
print(json.dumps({'status':'pass','checks':len(checks),'passed':sum(c['pass'] for c in checks),'pid':__import__('os').getpid(),'utc':datetime.now(timezone.utc).isoformat(),'old_s2_unchanged':True,'products':8},separators=(',',':')))
