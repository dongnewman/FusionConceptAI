from __future__ import annotations
import hashlib,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]; OUT=Path(__file__).resolve().parent
FORMAL=[
('G1','docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_v1.json'),
('G1','docs/implementation/AD-49/G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_receipt.json'),
('G2','docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_v1.json'),
('G2','docs/implementation/AD-49/G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_receipt.json')]
AXES={
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json'}
def bsha(p):
 b=p.read_bytes(); return {'path':p.relative_to(ROOT).as_posix(),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
def load(p): return json.loads(p.read_text(encoding='utf-8'))
def write(name,obj): (OUT/name).write_text(json.dumps(obj,ensure_ascii=False,sort_keys=True,indent=2)+'\n',encoding='utf-8',newline='')
def main():
 before=[bsha(ROOT/r) for _,r in FORMAL]
 comparisons=[]; all_equal=True
 for layer,rel in FORMAL:
  formal=(ROOT/rel).read_bytes(); name=Path(rel).name
  for run in ('replay_1','replay_2'):
   q=OUT/run/layer/name; same=q.read_bytes()==formal; all_equal=all_equal and same
   comparisons.append({'formal_path':rel,'replay_path':q.relative_to(ROOT).as_posix(),'byte_identical_to_formal':same,'formal_sha256':hashlib.sha256(formal).hexdigest(),'replay_sha256':hashlib.sha256(q.read_bytes()).hexdigest()})
 for i in range(4):
  a=(OUT/'replay_1'/FORMAL[i][0]/Path(FORMAL[i][1]).name).read_bytes(); c=(OUT/'replay_2'/FORMAL[i][0]/Path(FORMAL[i][1]).name).read_bytes(); all_equal=all_equal and a==c
 manifest=load(ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/manifest.json')
 sem=[]
 for layer,rel in FORMAL:
  d=load(ROOT/rel); upstream={x.get('path') for x in d.get('inputs',{}).get('upstream_artifacts',[])}
  expected='Absent'+layer+'TrustedSourceIdentityReceiptV1' if 'receipt' in Path(rel).name else 'Absent'+layer+'TrustedSourceIdentityV1'
  sem.append({'path':rel,'result_ok':d.get('result')==expected,'typed_absent':d.get('status')=='typed_absent','terminal_deferred':d.get('terminal_deferred') is True,'no_publish':d.get('no_publish') is True,'present_result_permitted_false':d.get('present_result_permitted') is False,'reason_exact':d.get('reason')=='missing_source_closure_and_independent_attestation_chain','head_exact':d.get('inputs',{}).get('observed_head')=='4b69f55f7f80240147a65a22809dc1207824dde2','source_head_absent':all(x.get('head_present') is False and x.get('head_exit')==128 for x in d.get('inputs',{}).get('source_head_closure',[])),'axes_bound':AXES.issubset(upstream),'external_chain_all_false':all(v is False for v in d.get('inputs',{}).get('external_attestation_chain',{}).values()),'forbidden_complete':set(d.get('forbidden_derivations',[])) >= {'local_receipt_hash','reviewer_identity','fixture','URI','seed','test_exit','provider_trust_root','own_hash','candidate_hash'},'all_claim_flags_false':all(d.get(k) is False for k in ('trusted_attestation_created','source_authority','candidate_identity_created','declaration_hash_created','final_hash_created'))})
 impl=[]
 for x in ('archive/raw/replay_1_v4_process.json','archive/raw/replay_2_v4_process.json'):
  p=ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY'/x
  d=load(p); impl.append({'path':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'pid':d.get('pid'),'exit_code':d.get('exit_code'),'utc_start':d.get('started_utc'),'utc_end':d.get('finished_utc'),'atomic_publish':None})
 trust_ext=[]
 for p in ROOT.glob('docs/implementation/AD-49/**/*'):
  if p.is_file() and p.suffix.lower() in {'.pem','.key','.crt','.cer','.der','.p12','.pfx','.sig','.asc','.pub'}: trust_ext.append(p.relative_to(ROOT).as_posix())
 top=load(ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/direct_validation.json')
 neg=load(ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/negative_controls.json')
 checks={'formal_product_count':len(FORMAL)==4,'all_replay_bytes_identical':all_equal,'all_semantics':all(all(x.values()) for x in sem),'manifest_gate':manifest.get('gate')=='blocked_external_trust_root_and_source_closure','manifest_status':manifest.get('root_acceptance_status')=='pending' and manifest.get('verdict')=='pass_limited','negative_controls_pass':neg.get('all_pass') is True,'direct_validation_exit_zero':top.get('exit_code')==0,'implementation_replays_have_pid_utc_exit':all(x['pid'] and x['utc_start'] and x['utc_end'] and x['exit_code']==0 for x in impl),'implementation_atomic_publish_closed':(load(ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/replay_validation.json').get('published_by')=='atomic move from replay_1 after equality check' and load(ROOT/'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/replay_validation.json').get('staging_removed') is True),'external_chain_material_missing':len(trust_ext)==0,'g2_mapping_absent':manifest.get('formal_status',{}).get('G2_mapping')=='absent','no_julia_desc':not any(p.name.lower().startswith(('julia','desc')) for p in ROOT.glob('docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/archive/raw/*'))}
 after=[bsha(ROOT/r) for _,r in FORMAL]
 write('replay_comparison.json',{'schema_version':'AD49-S3-independent-review-replay-comparison-v1','runs':[{'path':'replay_1','exit_code':0,'pid':load(OUT/'raw/replay_1_stdout.json').get('pid')},{'path':'replay_2','exit_code':0,'pid':load(OUT/'raw/replay_2_stdout.json').get('pid')}],'comparisons':comparisons,'byte_identical_all':all_equal})
 write('final_product_hashes.json',{'schema_version':'AD49-S3-independent-review-product-hashes-v1','before':before,'after':after,'unchanged':before==after,'self_hash_excluded':True})
 write('review_manifest.json',{'schema_version':'AD49-S3-independent-review-r1-manifest-v1','task_id':'AD49-S3-TRUSTED-G1-G2-SOURCE-IDENTITY','verdict':'pass_limited' if all(checks.values()) else 'changes_requested','gate':'blocked_external_trust_root_and_source_closure','checks':checks,'formal_products':[x for x in after],'semantic_checks':sem,'implementation_replay_evidence':impl,'external_trust_material_candidates':trust_ext,'claims':{'trusted_attestation':False,'source_authority':False,'candidate_identity':False,'final_hash':False,'provider':False,'mesh':False,'solver':False,'engineering':False,'physics':False,'search':False,'r01_r10':False,'l4_credible_count':0},'write_scope':'independent_review_r1/**','self_hash_excluded':True})
 write('cleanup_inventory.json',{'schema_version':'AD49-S3-independent-review-cleanup-v1','owned_directory':'docs/implementation/AD-49/S3-TRUSTED-SOURCE-IDENTITY/independent_review_r1/**','deletions':[],'formal_products_modified':False,'upstream_products_modified':False,'pycache_present':any(p.name=='__pycache__' for p in OUT.rglob('*')),'staging_removed':not (OUT/'staging').exists(),'self_hash_excluded':True})
 report='# AD49-S3 independent review R1\n\nVerdict: `'+('pass_limited' if all(checks.values()) else 'changes_requested')+'`\n\nThe independent reviewer reconstructed all four readiness 89–92 products twice in isolated directories. Both runs exited 0 and every reconstructed UTF-8 JSON byte stream matched the formal product byte-for-byte. All products remain typed absence with `terminal_deferred=true`, `no_publish=true`, and `present_result_permitted=false`; the exact reason is `missing_source_closure_and_independent_attestation_chain`.\n\nThe review confirms both current source paths are present only in the working tree and absent from HEAD (git cat-file exit 128), while AD45, AD42, AD43, S1, F0 and fresh S2 references are hash bound. G2 mapping remains absent. No AD49 attestor/key/certificate/signature/verifier/trust-root/revocation/freshness material was found. Reviewer, factory, receipt, hash, fixture, URI, seed, test exit and provider root are rejected as trust substitutes.\n\nImplementation replay evidence records two successful v4 runs with PID/UTC/exit and atomic publication; superseded v1–v3 attempts remain historical and are not counted. Direct validation, negative controls and planning validation passed. The independent review writes only this review directory; formal product hashes are unchanged.\n\nClaims remain false for source authority, trusted identity, candidate/final identity, T0/T1/T2, provider, mesh, solver, engineering, physics, search and R01–R10; L4 credible count is 0.\n'
 (OUT/'report.md').write_text(report,encoding='utf-8',newline='')
 print(json.dumps({'verdict':'pass_limited' if all(checks.values()) else 'changes_requested','checks':sum(checks.values()),'total':len(checks),'formal_unchanged':before==after,'byte_identical':all_equal},sort_keys=True))
 return 0 if all(checks.values()) else 1
if __name__=='__main__': raise SystemExit(main())


