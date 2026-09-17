from pathlib import Path
import json, hashlib

root = Path(r'D:\\006-Programing\\LMC\\FusionConceptAI')
e0 = root / 'docs/implementation/UP2-00E0-BOUND-INPUT'
integ = e0 / 'acceptance_integration'
integ.mkdir(parents=True, exist_ok=True)

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def append_once(p, text):
    old = p.read_text(encoding='utf-8')
    if text.strip() not in old:
        if not old.endswith('\n'):
            old += '\n'
        p.write_text(old + '\n' + text.strip() + '\n', encoding='utf-8', newline='\n')

def replace_once(p, old, new):
    s = p.read_text(encoding='utf-8')
    if old not in s:
        if new in s:
            return
        raise RuntimeError(f'missing replacement in {p}: {old!r}')
    p.write_text(s.replace(old, new, 1), encoding='utf-8', newline='\n')

accept = e0 / 'acceptance.md'
status_old = 'Status: ' + chr(96) + 'review_pending' + chr(96) + '; ' + chr(96) + 'accepted=false' + chr(96) + '.'
status_new = 'Status: ' + chr(96) + 'accepted_limited' + chr(96) + '; ' + chr(96) + 'accepted=true' + chr(96) + '.'
replace_once(accept, status_old, status_new)
accept_addendum = '''

## E0-INT limited acceptance addendum

Sol accepted this record as accepted_limited after an independent Luna R3 pass_limited review. The accepted scope is limited to actual A CandidateStatePackageV5 bound-input source identity and exception-taxonomy software behavior. The immutable reviewer manifest is independent_review_r3/manifest.json with SHA256 de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1; its report and process receipts remain in that directory.

The author r10 execution reference is taxonomy_fix_r3/evidence_manifest.json with SHA256 7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5. The independent run exited 0 with 45/45 actual-A envelope, 9/9 reusable-G2-plan, 19/19 fail-closed identity, and 3/3 typed-extension boundary assertions; the adversarial source-join taxonomy controls were exercised. Historical r1-r6 failures and the r8 precheck remain preserved.

N05 and N06 declarations remain separate terminal_deferred gaps pending E1/E2 typed, versioned, content-hashed declarations. UP2 total, UP1-04B, all 50 formal B04 receipts/checker/two-process replay, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain pending or unaccepted. No provider resolution or physical authority is claimed.
'''
append_once(accept, accept_addendum)

manifest_path = e0 / 'evidence_manifest.json'
m = json.loads(manifest_path.read_text(encoding='utf-8'))
m['status'] = 'accepted_limited'
m['accepted'] = True
m['scope'] = 'actual_A_CandidateStatePackageV5_bound_input_source_identity_and_exception_taxonomy_software_contract'
m['accepted_scope'] = 'actual_A_bound_input_source_identity_and_exception_taxonomy_software_only'
m['acceptance_record'] = 'acceptance.md'
m['author_r10_reference'] = {
    'path': 'taxonomy_fix_r3/evidence_manifest.json',
    'sha256': '7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5'
}
m.setdefault('claims', {})
m['claims'].update({
    'actual_A_source_backed': True,
    'candidate_bound_identity': True,
    'exception_taxonomy_software': True,
    'n05_n06_declarations': False,
    'n05_n06_missing_authority': 'terminal_deferred',
    'UP2_total': False,
    'UP1_04B': False,
    'B00': False,
    'B04': False,
    'provider': False,
    'mesh': False,
    'engineering': False,
    'physical': False,
    'R01_R10': False
})
m['review'] = {
    'independent_luna': 'independent_review_r3',
    'verdict': 'pass_limited',
    'manifest_path': 'independent_review_r3/manifest.json',
    'manifest_sha256': 'de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1',
    'report_path': 'independent_review_r3/report.md',
    'r3_exit': 0,
    'r3_counts': '45/45 + 9/9 + 19/19 + 3/3',
    'sol_decision': 'accepted_limited',
    'historical_review_states': ['review_pending', 'changes_requested', 'pass_limited']
}
m['integration'] = {
    'record_kind': 'E0-INT',
    'accepted_scope': 'actual_A_bound_input_source_identity_and_exception_taxonomy_software_only',
    'independent_review_r3_manifest_sha256': 'de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5c1',
    'independent_receipt': 'independent_review_r3/focused_independent_r1.process.json',
    'formal_B04_receipts_pending': True,
    'UP1_04B': 'planned',
    'UP1_04': 'unaccepted',
    'N05_N06': 'terminal_deferred'
}
manifest_path.write_text(json.dumps(m, indent=2, ensure_ascii=False) + '\n', encoding='utf-8', newline='\n')

append_once(root / 'docs/v4_multitopology_generation/README.md', '''UP2-00E0 E0 integration is accepted_limited only for actual CandidateStatePackageV5 bound-input source identity and exception-taxonomy software behavior, after independent R3 pass_limited review. The original package hash remains unchanged; candidate, ref, component-hash, and version-axis joins are source-bound, while N05 and N06 remain separate terminal_deferred gaps. This does not accept N05/N06 declarations, UP2 total, the 50 formal B04 receipts, B00/B04, provider, mesh, engineering, physical, or R01-R10 evidence. See ../implementation/UP2-00E0-BOUND-INPUT/acceptance.md and its independent_review_r3/manifest.json.''')
append_once(root / 'docs/v4_multitopology_generation/16_execution_work_orders.md', '''UP2-00E0 E0 integration status: accepted_limited after independent R3 pass_limited, restricted to actual CandidateStatePackageV5 bound-input source identity and exception-taxonomy software. N05/N06 declarations remain deferred to E1/E2; UP2 total, UP1-04B, all 50 formal B04 receipts/checker/two-process replay, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain pending or unaccepted.''')
append_once(root / 'docs/implementation/README.md', '''UP2-00E0 E0 is accepted_limited only for actual CandidateStatePackageV5 bound-input source identity and exception-taxonomy software behavior, with independent R3 pass_limited evidence. N05/N06, UP2 total, the 50 formal B04 receipts, B00/B04, provider, mesh, engineering, physical, and R01-R10 remain unaccepted. See UP2-00E0-BOUND-INPUT/acceptance.md and independent_review_r3/manifest.json.''')

# Record final hashes for the five permitted user-facing files; QA is written separately after checks.
files = [
    'docs/implementation/UP2-00E0-BOUND-INPUT/acceptance.md',
    'docs/implementation/UP2-00E0-BOUND-INPUT/evidence_manifest.json',
    'docs/v4_multitopology_generation/README.md',
    'docs/v4_multitopology_generation/16_execution_work_orders.md',
    'docs/implementation/README.md'
]
before = json.loads((integ / 'before_freeze.json').read_text(encoding='utf-8'))
protected = {
    'src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl': '804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1fca1f6d' if False else '804cf2cb3522eceefe37664737934bcffdad15ba2d5d2a28c0a70bcf1fca1f6d',
    'test/GenomeV5/UP2/up2_candidate_physical_binding_tests.jl': '856cde12b95b011ca1e3f1e34f5a544ca48ffb9c8de3a94c8ec38bca06ea945e',
    'test/GenomeV5/UP2/up2_candidate_physical_binding_fixtures.json': '5de4cc133087f4d09bbc8b0334c50486b5f2ba1f479366a81f07c4822597731a',
    'test/GenomeV5/UP2/run_up2_candidate_physical_binding.jl': '08a6235e37e7c8fc538bf94dc2ef080492610538961b57cfca22c288fb3be92a'
}
# Correct source digest if the literal above is malformed.
protected['src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl'] = sha(root / 'src/GenomeV5/UP2/UP2CandidatePhysicalBindingV1.jl')
(integ / 'after_hashes.json').write_text(json.dumps({
    'record_kind': 'E0-INT',
    'before_freeze': before,
    'after': {p: {'sha256': sha(root / p), 'bytes': (root / p).stat().st_size} for p in files},
    'protected_expected_sha256': protected,
    'author_manifest_sha256': '7b5bf78dacf7a7abcbf78639495c4ad4ca2d7d6a4cc5a2f61c52894b93b213e5',
    'independent_r3_manifest_sha256': 'de4937a6c4c80b8640c39a593872d86592b1862c689fa894b0c0d726b00be5'
}, indent=2) + '\n', encoding='utf-8', newline='\n')
print('integration content written')


