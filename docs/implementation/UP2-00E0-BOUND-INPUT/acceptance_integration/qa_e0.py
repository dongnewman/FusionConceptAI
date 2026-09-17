from pathlib import Path
import hashlib, json, subprocess, datetime
root = Path(r'D:\\006-Programing\\LMC\\FusionConceptAI')
integ = root / 'docs/implementation/UP2-00E0-BOUND-INPUT/acceptance_integration'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def run(cmd):
    p = subprocess.run(cmd, cwd=root, capture_output=True, text=True, encoding='utf-8', errors='replace')
    return {'command': ' '.join(cmd), 'exit': p.returncode, 'stdout': p.stdout, 'stderr': p.stderr}

edited = [
    'docs/implementation/UP2-00E0-BOUND-INPUT/acceptance.md',
    'docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json',
    'docs/v4_multitopology_generation/README.md',
    'docs/v4_multitopology_generation/16_execution_work_orders.md',
    'docs/implementation/README.md'
]
json_files = [p for p in integ.rglob('*.json')] + [root / 'docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json']
json_parse = []
for p in sorted(set(json_files)):
    try:
        json.loads(p.read_text(encoding='utf-8'))
        json_parse.append({'path': str(p.relative_to(root)), 'ok': True})
    except Exception as e:
        json_parse.append({'path': str(p.relative_to(root)), 'ok': False, 'error': repr(e)})
control = []
for rel in edited + [str(p.relative_to(root)) for p in integ.rglob('*') if p.is_file()]:
    p = root / rel
    if not p.exists(): continue
    bad = [(i, ord(ch)) for i,ch in enumerate(p.read_text(encoding='utf-8', errors='strict')) if ord(ch) < 32 and ch not in '\r\n\t']
    control.append({'path': rel, 'bad_control_count': len(bad), 'first_bad': bad[:5]})
validate = run(['python', 'docs/v4_multitopology_generation/validate_plan.py'])
diff = run(['git', 'diff', '--check'])
protected_expected = {
    'src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl': '804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d',
    'test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl': '856cde12b95b011ca1e3f1e34f5a544ca48ffb9c8de3a94c8ec38bca06ea945e',
    'test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json': '5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a',
    'test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl': '08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a',
    'docs/implementation/UP2-00E0-BOUND-INPUT/taxonomy_fix_r3/evidence_manifest.json': '7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5',
    'docs/implementation/UP2-00E0-BOUND-INPUT/independent_review_r3/manifest.json': 'de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1'
}
protected = {p: {'expected': h, 'actual': sha(root / p), 'match': h == sha(root / p)} for p,h in protected_expected.items()}
proc = subprocess.run(['powershell','-NoProfile','-Command', "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(julia|desc)' } | Select-Object Name,ProcessId,ParentProcessId | ConvertTo-Json -Compress"], cwd=root, capture_output=True, text=True, encoding='utf-8', errors='replace')
process_state = {'command': 'powershell Get-CimInstance Win32_Process julia/desc', 'exit': proc.returncode, 'stdout': proc.stdout, 'stderr': proc.stderr, 'empty': not proc.stdout.strip()}
result = {
    'record_kind': 'E0-INT-final-QA',
    'captured_at_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'json_parse': json_parse,
    'control_scan': control,
    'validate_plan': validate,
    'git_diff_check': diff,
    'protected_files': protected,
    'process_state_after_docs': process_state,
    'claims': {'accepted_scope_only': True, 'B00': False, 'B04': False, 'provider': False, 'mesh': False, 'engineering': False, 'physical': False, 'R01_R10': False}
}
(integ / 'qa.json').write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')
print(json.dumps({'validate_exit': validate['exit'], 'diff_exit': diff['exit'], 'json_ok': all(x['ok'] for x in json_parse), 'controls_ok': all(x['bad_control_count']==0 for x in control), 'protected_ok': all(x['match'] for x in protected.values()), 'process_empty': process_state['empty']}, ensure_ascii=False))
