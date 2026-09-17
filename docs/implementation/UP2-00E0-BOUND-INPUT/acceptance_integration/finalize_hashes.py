from pathlib import Path
import hashlib,json,datetime
root=Path(r'D:\\006-Programing\\LMC\\FusionConceptAI'); integ=root/'docs/implementation/UP2-00E0-BOUND-INPUT/acceptance_integration'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
files=['docs/implementation/UP2-00E0-BOUND-INPUT/acceptance.md','docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json','docs/v4_multitopology_generation/README.md','docs/v4_multitopology_generation/16_execution_work_orders.md','docs/implementation/README.md']
protected=['src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl','test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl','test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json','test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl','docs/implementation/UP2-00E0-BOUND-INPUT/taxonomy_fix_r3/evidence_manifest.json','docs/implementation/UP2-00E0-BOUND-INPUT/independent_review_r3/manifest.json']
obj={'record_kind':'E0-INT-final-hashes','captured_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'files':{p:{'sha256':sha(root/p),'bytes':(root/p).stat().st_size} for p in files},'protected_files':{p:sha(root/p) for p in protected},'qa_sha256':sha(integ/'qa.json'),'author_r10_manifest_sha256':'7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5','independent_r3_manifest_sha256':'de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1'}
(integ/'final_hashes.json').write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(obj,ensure_ascii=False,indent=2))
