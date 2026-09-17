from pathlib import Path
import hashlib,json,subprocess,datetime
root=Path(r'D:\\006-Programing\\LMC\\FusionConceptAI'); out=root/'docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_precheck_r2'
paths=['src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl','test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json','test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl','test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl','docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/evidence_manifest.json']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
obj={'record_kind':'E2-N06-independent-precheck-r2-input-freeze','captured_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'head':subprocess.run(['git','rev-parse','HEAD'],cwd=root,capture_output=True,text=True).stdout.strip(),'files':{p:{'sha256':sha(root/p),'bytes':(root/p).stat().st_size,'mtime_ns':(root/p).stat().st_mtime_ns} for p in paths},'author_supplied_four_hashes':{'source':'e624a7b8e06954e7d37e3b0be8d973bdb08a1a89eb556b7c9ff777126158fa85','fixture':'766760a1b847ff292d00bacb05ef78d634c1242bf965aafa992419ddd47c2b4e','test':'899360ff3f0b1c77bd12ecc25069503aaca2cb5a777aa1921c8ed2c7f8471864','runner':'9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af'},'execution':{'julia':'not_run','desc':'not_run'}}
(out/'input_hashes.json').write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
print(hashlib.sha256((out/'input_hashes.json').read_bytes()).hexdigest())
