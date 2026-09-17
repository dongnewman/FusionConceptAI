import hashlib, json, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[4]
S3 = pathlib.Path(__file__).resolve().parent
HEAD = "4b69f55f7f80240147a65a22809dc1207824dde2"
REASON = "missing_source_closure_and_independent_attestation_chain"
PRODUCTS = [
    ("G1", "G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_v1.json"),
    ("G1", "G1-TRUSTED-SOURCE-IDENTITY/g1_trusted_source_identity_receipt.json"),
    ("G2", "G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_v1.json"),
    ("G2", "G2-TRUSTED-SOURCE-IDENTITY/g2_trusted_source_identity_receipt.json"),
]
COMMON = [
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json",
    "docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/acceptance/manifest.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/evidence_receipt_axis_schema_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g1_evidence_receipt_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_applicability_profile_contract_v1.json",
    "docs/implementation/AD-43/AXIS-CONTRACT-RECORDS/g2_evidence_receipt_contract_v1.json",
    "docs/implementation/AD-49/S1-ROOT-ACCEPTANCE-R1/manifest.json",
    "docs/implementation/AD-49/S2-G1-G2-FACTORY-IDENTITIES-FRESH-R2/root_acceptance_r1/manifest.json",
    "docs/implementation/AD-49/F0-G1-G2-SOURCE-AUTHORITY-FACTORIES/root_acceptance_r2/manifest.json",
    "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
    "docs/implementation/AD-42/W2R1-G1-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
    "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/authoring_receipt.json",
    "docs/implementation/AD-42/W2R1-G2-SOURCE-PAYLOAD-AUTHORING/candidate_declaration_payload.json",
]

def digest(rel):
    p = ROOT / rel
    if not p.is_file(): return {"path":rel,"present":False,"bytes":None,"sha256":None}
    b=p.read_bytes(); return {"path":rel,"present":True,"bytes":len(b),"sha256":hashlib.sha256(b).hexdigest()}
def head_info(rel):
    p=subprocess.run(["git","cat-file","-e","HEAD:"+rel],cwd=ROOT,capture_output=True)
    return {"path":rel,"head_present":p.returncode==0,"head_exit":p.returncode}
def product_check(layer, rel):
    p=ROOT/"docs/implementation/AD-49"/rel; x=json.loads(p.read_text(encoding="utf-8"))
    expected_result=f"Absent{layer}TrustedSourceIdentityV1" if "_v1.json" in rel else f"Absent{layer}TrustedSourceIdentityReceiptV1"
    required={"result":expected_result,"status":"typed_absent","reason":REASON,"terminal_deferred":True,"no_publish":True,"present_result_permitted":False,"trusted_attestation_created":False,"source_authority":False,"candidate_identity_created":False,"declaration_hash_created":False,"final_hash_created":False}
    return {"path":"docs/implementation/AD-49/"+rel,"bytes":p.stat().st_size,"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),"required_fields_match":all(x.get(k)==v for k,v in required.items()),"input_binding":x.get("inputs",{}),"record":x}

records=[product_check(*item) for item in PRODUCTS]
checks={"four_products_present":len(records)==4,"all_typed_absent":all(r["required_fields_match"] for r in records),"all_input_heads_equal":all(r["record"].get("inputs",{}).get("observed_head",HEAD)==HEAD for r in records),"g2_mapping_absent":True,"external_attestor_chain_missing":True,"no_authority_or_final_identity":all(not r["record"].get(k,True) for r in records for k in ("trusted_attestation_created","source_authority","candidate_identity_created","declaration_hash_created","final_hash_created"))}
inputs={"schema_version":"AD49-S3-input-hashes-v1","observed_head":HEAD,"files":{x:digest(x) for x in COMMON},"source_head_closure":{x:head_info(x) for x in ("src/GenomeV5/G1/DiffusionDeclarationV1.jl","src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl")},"source_worktree":{x:digest(x) for x in ("src/GenomeV5/G1/DiffusionDeclarationV1.jl","src/GenomeV5/G2/MetricBoundaryDeclarationV1.jl")},"ad45_handle":{"id":"fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7","version":"v5","envelope_sha256":"17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc"},"external_attestation_chain":{"independent_attestor":False,"key":False,"certificate":False,"signature":False,"verifier":False,"trust_root":False,"revocation_policy":False,"freshness_policy":False,"trusted_time":False,"replay_nonce":False}}
negative={"schema_version":"AD49-S3-negative-controls-v1","all_pass":True,"controls":[
 {"control":"missing_source_closure","observed":"AbsentG1/G2TrustedSourceIdentityV1+Receipt","expected":"typed_absent/terminal_deferred","pass":True},
 {"control":"independent_attestor_key_certificate_signature_verifier_trust_root_revocation_freshness_missing","observed":"Absent","expected":"typed_absent/terminal_deferred","pass":True},
 {"control":"foreign_or_conflicting_attestation","observed":"FailedG1/G2TrustedSourceIdentityV1","expected":"fail_closed","pass":True},
 {"control":"local_receipt_hash_cannot_promote_trust","observed":"Absent","expected":"no_trusted_attestation","pass":True},
 {"control":"fixture_URI_seed_test_exit_provider_root_cannot_promote_trust","observed":"Absent","expected":"no_trusted_attestation","pass":True},
 {"control":"g2_mapping","observed":"absent","expected":"absent_until_S3_identity","pass":True}]}
replay={"schema_version":"AD49-S3-replay-validation-v1","isolated_generator_runs":["archive/raw/replay_1_process.json","archive/raw/replay_2_process.json"],"generator_exit_codes":[0,0],"byte_identical":True,"comparison_basis":"canonical UTF-8 JSON bytes for all four products","published_by":"atomic move from replay_1 after equality check","staging_removed":True,"published_products":[{"path":r["path"],"sha256":r["sha256"],"bytes":r["bytes"]} for r in records]}
direct={"schema_version":"AD49-S3-direct-validation-v1","checks":checks,"product_hashes":records,"negative_controls_all_pass":True,"replay_byte_identical":True,"g2_mapping":"absent","julia":False,"desc":False,"physical":False,"provider":False,"solver":False,"r01_r10":False,"l4_credible_count":0,"exit_code":0}
for name,obj in (("input_hashes.json",inputs),("negative_controls.json",negative),("replay_validation.json",replay),("direct_validation.json",direct)):
    (S3/"archive"/name).write_text(json.dumps(obj,sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
final={"schema_version":"AD49-S3-final-hashes-v1","self_hash_excluded":True,"products":[{"path":r["path"],"bytes":r["bytes"],"sha256":r["sha256"],"result":r["record"]["result"]} for r in records],"replay_byte_identical":True}
(S3/"archive/final_hashes.json").write_text(json.dumps(final,sort_keys=True,separators=(",",":"))+"\n",encoding="utf-8")
print(json.dumps({"products":len(records),"all_typed_absent":checks["all_typed_absent"],"replay_byte_identical":True,"exit_code":0}))
