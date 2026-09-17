from pathlib import Path
import hashlib,json,subprocess,datetime
root=Path(r'D:\\006-Programing\\LMC\\FusionConceptAI')
out=root/'docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_precheck_r1'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs=[
 'src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl',
 'test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json',
 'test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl',
 'test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl',
 'docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/evidence_manifest.json',
 'docs/v4_multitopology_generation/00_normative_contracts_and_state_model.md',
 'docs/v4_multitopology_generation/18_sources_and_architecture_decisions.md',
 'docs/v4_multitopology_generation/README.md'
]
proc=subprocess.run(['powershell','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)' } | Select-Object Name,ProcessId,ParentProcessId | ConvertTo-Json -Compress"],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
obj={
 'record_kind':'E2-N06-independent-precheck-r1',
 'captured_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
 'head':subprocess.run(['git','rev-parse','HEAD'],cwd=root,capture_output=True,text=True).stdout.strip(),
 'dirty_status_command':'git status --short',
 'input_files':{p:{'bytes':(root/p).stat().st_size,'sha256':sha(root/p),'mtime_ns':(root/p).stat().st_mtime_ns} for p in inputs},
 'author_latest_frozen_hashes':{
  'source':'443cb60dae73101ad3523517f5d85eb9a616b5f60d8b605830cd2a789583f1a7',
  'fixture':'58b2e4fe7f496d65ab88e109cd99f972dbba044da426ff573668a7849e9ce744',
  'test':'73045b4170b82c20944909350fcb06fb847115f6e9d79cd292f1fa49a57e00',
  'runner':'9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af'
 },
 'historical_receipts':{
  'focused_r1':{'exit':1,'classification':'program_exception_unsupported_first_generator_default','path':'../focused_r1/'},
  'focused_r2':{'exit':1,'classification':'program_exception_invalid_authored_owner_scope_and_conversion_offset','path':'../focused_r2/'},
  'focused_r3':{'exit':1,'classification':'program_exception_missing_semantic_view_N06InvocationCounterV1','path':'../focused_r3/'}
 },
 'process_sweep':{'command':'powershell Get-CimInstance Win32_Process julia/desc','exit':proc.returncode,'stdout':proc.stdout,'stderr':proc.stderr,'empty':not proc.stdout.strip()},
 'execution':{'julia':'not_run','desc':'not_run','reason':'independent static precheck only'}
}
(out/'input_hashes.json').write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'input_hashes':{p:v['sha256'] for p,v in obj['input_files'].items()},'process_empty':obj['process_sweep']['empty']},ensure_ascii=False))
