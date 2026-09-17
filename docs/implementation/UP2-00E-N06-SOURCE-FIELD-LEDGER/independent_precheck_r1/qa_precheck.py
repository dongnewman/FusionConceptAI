from pathlib import Path
import hashlib,json,subprocess,datetime
root=Path(r'D:\\006-Programing\\LMC\\FusionConceptAI'); out=root/'docs/implementation/UP2-00E-N06-SOURCE-FIELD-LEDGER/independent_precheck_r1'
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(cmd):
 p=subprocess.run(cmd,cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 return {'command':' '.join(cmd),'exit':p.returncode,'stdout':p.stdout,'stderr':p.stderr}
expected={
 'src/GenomeV5/UP2/N06SourceFieldLedgerMappingV1.jl':'443cb60dae73101ad3523517f5d85eb9a616b5f60d8b605830cd2a789583f1a7',
 'test/GenomeV5/UP2/n06_source_field_ledger_mapping_fixtures.json':'58b2e4fe7f496d65ab88e109cd99f972dbba044da426ff573668a7849e9ce744',
 'test/GenomeV5/UP2/n06_source_field_ledger_mapping_tests.jl':'73045b4170b82c20944909350fcb06fb847115f6e9d4e79cd292f1fa49a57e00',
 'test/GenomeV5/UP2/run_n06_source_field_ledger_mapping.jl':'9410e2edbb7afc70599e183f30a2ef9836b7e84a1834296e27d96b881b1f86af'
}
json_files=list(out.rglob('*.json'))
parses=[]
for p in json_files:
 try: json.loads(p.read_text(encoding='utf-8')); parses.append({'path':str(p.relative_to(root)),'ok':True})
 except Exception as e: parses.append({'path':str(p.relative_to(root)),'ok':False,'error':repr(e)})
controls=[]
for p in [x for x in out.rglob('*') if x.is_file()]:
 try: s=p.read_text(encoding='utf-8')
 except: continue
 bad=[(i,ord(c)) for i,c in enumerate(s) if ord(c)<32 and c not in '\r\n\t']
 controls.append({'path':str(p.relative_to(root)),'bad_count':len(bad),'first_bad':bad[:3]})
hashes={p:{'expected':h,'actual':sha(root/p),'match':h==sha(root/p)} for p,h in expected.items()}
proc=run(['powershell','-NoProfile','-Command',"Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)' } | Select-Object Name,ProcessId,ParentProcessId | ConvertTo-Json -Compress"])
qa={'record_kind':'E2-N06-independent-precheck-r1-QA','captured_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'json_parse':parses,'control_scan':controls,'source_hash_check':hashes,'git_diff_check':run(['git','diff','--check']),'process_sweep':proc,'execution':{'julia':'not_run','desc':'not_run'},'verdict':'changes_requested','claim_ceiling':'contract_only'}
(out/'qa.json').write_text(json.dumps(qa,indent=2,ensure_ascii=False)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'json_ok':all(x['ok'] for x in parses),'controls_ok':all(x['bad_count']==0 for x in controls),'source_hashes_ok':all(x['match'] for x in hashes.values()),'diff_exit':qa['git_diff_check']['exit'],'process_empty':not proc['stdout'].strip()},ensure_ascii=False))

