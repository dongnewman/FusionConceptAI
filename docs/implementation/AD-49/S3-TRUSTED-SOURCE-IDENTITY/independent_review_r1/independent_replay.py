from __future__ import annotations
import hashlib, json, os, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[5]
OUT=Path(__file__).resolve().parent
HEAD='4b69f55f7f80240147a65a22809dc1207824dde2'
HANDLE='fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7'
ENVELOPE_SHA='17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc'
COMMON=[
'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json',
'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/acceptance/manifest.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json',
'docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json',
'docs/implementation/AD-49/S1-ROOT-ACCEPTANCE-R1/manifest.json',
'docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/root_acceptance_r1/manifest.json',
'docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/root_acceptance_r2/manifest.json',
'docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json',
'docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json',
'docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json',
'docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json']
FORBIDDEN=['local_receipt_hash','reviewer_identity','fixture','URI','seed','test_exit','provider_trust_root','own_hash','candidate_hash']
MISSING={k:False for k in ['independent_attestor','attestor_key','certificate','signature','verifier','trust_root','revocation_policy','freshness_policy','trusted_time','replay_nonce']}
def digest(rel):
 p=ROOT/rel; b=p.read_bytes(); return {'bytes':len(b),'path':rel,'present':True,'sha256':hashlib.sha256(b).hexdigest()}
def head_info(rel):
 q=subprocess.run(['git','cat-file','-e','HEAD:'+rel],cwd=ROOT,capture_output=True)
 return {'head_exit':q.returncode,'head_present':q.returncode==0,'path':rel}
def build(layer,kind):
 source='src/GenomeV5/'+layer+'/'+('DiffusionDeclarationV1.jl' if layer=='G1' else 'MetricBoundaryDeclarationV1.jl')
 low=layer.lower(); s2='docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/'+low+'_factory_'+('identity_probe.json' if kind=='identity' else 'construction_probe_receipt.json')
 result='Absent'+layer+'TrustedSourceIdentityV1' if kind=='identity' else 'Absent'+layer+'TrustedSourceIdentityReceiptV1'
 return {'candidate_identity_created':False,'declaration_hash_created':False,'final_hash_created':False,'forbidden_derivations':FORBIDDEN,'inputs':{'ad45_handle':{'envelope_sha256':ENVELOPE_SHA,'id':HANDLE,'version':'v5'},'external_attestation_chain':MISSING,'observed_head':HEAD,'repository_root':str(ROOT).replace('\\','/'),'source_declaration':digest(source),'source_head_closure':[head_info(source)],'upstream_artifacts':[digest(x) for x in COMMON+[source,s2]]},'no_publish':True,'present_result_permitted':False,'reason':'missing_source_closure_and_independent_attestation_chain','record_kind':layer+'TrustedSourceIdentityV1' if kind=='identity' else layer+'TrustedSourceIdentityReceiptV1','result':result,'schema_version':'AD49-'+layer+'-trusted-source-identity-'+('v1' if kind=='identity' else 'receipt-v1'),'scope':layer,'source_authority':False,'status':'typed_absent','terminal_deferred':True,'trusted_attestation_created':False}
def write_set(target):
 target=Path(target); target.mkdir(parents=True,exist_ok=True)
 for layer,kind,name in [('G1','identity','g1_trusted_source_identity_v1.json'),('G1','receipt','g1_trusted_source_identity_receipt.json'),('G2','identity','g2_trusted_source_identity_v1.json'),('G2','receipt','g2_trusted_source_identity_receipt.json')]:
  rel=Path(layer)/name; p=target/rel; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes((json.dumps(build(layer,kind),ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode())
 return sorted(target.rglob('*.json'))
if __name__=='__main__':
 if len(sys.argv)!=2: raise SystemExit('usage: independent_replay.py TARGET')
 files=write_set(sys.argv[1]); print(json.dumps({'pid':os.getpid(),'files':len(files),'target':str(Path(sys.argv[1]).as_posix())},sort_keys=True)); raise SystemExit(0)
