import hashlib, json, os, pathlib, subprocess, sys
from datetime import datetime, timezone

ROOT = pathlib.Path(__file__).resolve().parents[6]
FRESH = ROOT / 'docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2'
SCOPES = ('realization', 'control', 'binding', 'bundle')
MANIFEST = json.loads((FRESH/'manifest.json').read_text(encoding='utf-8'))
PROBE = json.loads((FRESH/'independent_review_r1/raw/real_input_factory_probe.stdout.txt').read_text(encoding='utf-8').splitlines()[0])
CHECKS = []
ISSUES = []

def check(name, value, detail=None):
    value = bool(value)
    CHECKS.append({'name': name, 'pass': value, **({'detail': detail} if detail else {})})
    if not value:
        ISSUES.append({'name': name, 'detail': detail})

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def canon(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(',', ':'))

def run_git(*args):
    p = subprocess.run(['git', '-C', str(ROOT), *args], text=True, capture_output=True)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

check('manifest_status_review_pending', MANIFEST.get('status') == 'review_pending' and MANIFEST.get('accepted') is False)
check('manifest_observed_head', MANIFEST.get('observed_head') == '4b69f55f7f80240147a65a22809dc1207824dde2')
check('manifest_fresh_s2_unlocked', MANIFEST.get('root_acceptance_input', {}).get('fresh_s2_unlocked') is True)
check('manifest_claim_ceiling', MANIFEST.get('claims', {}).get('trusted_attestation') is False and MANIFEST.get('claims', {}).get('candidate_identity') is False and MANIFEST.get('claims', {}).get('t0') is False and MANIFEST.get('claims', {}).get('provider') is False and MANIFEST.get('claims', {}).get('physical') is False and MANIFEST.get('claims', {}).get('search') is False and MANIFEST.get('claims', {}).get('r01_r10') is False and MANIFEST.get('claims', {}).get('l4_credible_count') == 0)
check('manifest_four_scopes', set(MANIFEST.get('products', {})) == set(SCOPES))

expected_controls = {'source_hash_mutation':'fail_closed','source_bytes_mutation':'fail_closed','HEAD_mutation':'fail_closed','path_status_mutation':'fail_closed','wrong_locator_scope':'fail_closed','AD45_handle_or_version_mutation':'fail_closed','AD45_envelope_hash_mutation':'fail_closed','contract_ref_mismatch':'fail_closed','version_axes_mismatch':'fail_closed','replay_conflict':'fail_closed','missing_typed_input':'typed_absent_terminal_deferred'}
check('manifest_negative_controls_closed', MANIFEST.get('negative_controls') == expected_controls)

for scope in SCOPES:
    ident_path = FRESH/scope/'factory_identity_v1.json'
    receipt_path = FRESH/scope/'construction_receipt.json'
    ip = json.loads(ident_path.read_bytes())
    rp = json.loads(receipt_path.read_bytes())
    pm = MANIFEST['products'][scope]
    check(f'{scope}:identity_sha_manifest', sha(ident_path) == pm['identity']['sha256'] and ident_path.stat().st_size == pm['identity']['bytes'])
    check(f'{scope}:receipt_sha_manifest', sha(receipt_path) == pm['receipt']['sha256'] and receipt_path.stat().st_size == pm['receipt']['bytes'])
    for label, path in (('identity', ident_path), ('receipt', receipt_path)):
        raw = path.read_bytes()
        check(f'{scope}:{label}:canonical_no_lf', not raw.endswith(b'\n') and raw.decode('utf-8') == canon(json.loads(raw)))
    check(f'{scope}:present_unions', ip.get('result') == 'PresentG3FactoryIdentityV1' and rp.get('result') == 'PresentG3FactoryConstructionReceiptV1')
    check(f'{scope}:task_and_schema', ip.get('task_id') == 'AD48-S2-G3-FACTORY-IDENTITY-FRESH-R2' and rp.get('task_id') == ip.get('task_id') and ip.get('schema_version') == 'AD48-G3-factory-identity-v1' and rp.get('schema_version') == 'AD48-G3-factory-construction-receipt-v1')
    check(f'{scope}:semantic_hashes', ip.get('semantic_hash') == hashlib.sha256(canon(ip['semantic_body']).encode()).hexdigest() and rp.get('semantic_hash') == hashlib.sha256(canon(rp['semantic_body']).encode()).hexdigest())
    check(f'{scope}:negative_claims', ip.get('trusted_attestation_created') is False and rp.get('trusted_attestation_created') is False and ip.get('candidate_identity_created') is False and rp.get('candidate_identity_created') is False and ip.get('final_candidate_or_package_declaration_hash_created') is False and rp.get('semantic_body', {}).get('final_candidate_or_package_declaration_hash_created') is False and ip.get('no_publish') is True and rp.get('no_publish') is True)
    check(f'{scope}:local_hashes_present', all(isinstance(ip.get(k), str) and len(ip[k]) == 64 for k in ('factory_identity_digest','g3_source_contract_binding_digest','g3_source_declaration_hash','source_content_digest')) and isinstance(rp.get('construction_digest'), str) and len(rp['construction_digest']) == 64)
    check(f'{scope}:identity_receipt_closure', ip['g3_source_declaration_hash'] == rp['g3_source_declaration_hash'] and ip['g3_source_declaration_hash'] == ip['semantic_body']['source_declaration_hash']['value'] and rp['g3_source_declaration_hash'] == rp['semantic_body']['source_declaration_hash']['value'] and ip['source_content_digest'] == rp['source_content_digest'] and ip['g3_source_contract_binding_digest'] == rp['g3_source_contract_binding_digest'])
    im = ip['semantic_body']; rm = rp['semantic_body']; out = rm['output_source_declaration']; cm = out['content']
    check(f'{scope}:locator_receipt_closure', im['locator'] == cm['locator'] and im['locator'] == rp['semantic_body']['output_source_declaration']['content']['locator'])
    check(f'{scope}:axes_four_way_equal', im['version_axes'] == cm['version_axes'] == out['content']['version_axes'])
    expected_contract_version = 'v2' if scope == 'binding' else 'v5'
    check(f'{scope}:contract_ref_equal', im['contract_ref'] == cm['contract_ref'] == out['content']['binding']['contract_ref'] and im['contract_ref']['uri'] == f'fusionconceptai://GenomeV5/G3/{scope}' and im['contract_ref']['version'] == expected_contract_version)
    check(f'{scope}:ad45_exact', im['common_binding_handle']['id'] == MANIFEST['inputs']['ad45_handle_id'] and im['common_binding_handle']['version'] == MANIFEST['inputs']['ad45_handle_version'] and cm['common_binding_envelope_path'] == MANIFEST['inputs']['ad45_envelope_path'] and cm['common_binding_envelope_sha256']['value'] == MANIFEST['inputs']['ad45_envelope_sha256'])
    loc = im['locator']; src = ROOT / pathlib.PureWindowsPath(loc['source_path'])
    if not src.exists(): src = ROOT / pathlib.PurePosixPath(loc['source_path'])
    check(f'{scope}:source_bytes_sha', src.exists() and src.stat().st_size == loc['source_bytes'] and sha(src) == loc['source_sha256']['value'] and sha(src) == im['source_sha256']['value'])
    check(f'{scope}:git_freshness_recomputed', loc['observed_head'] == MANIFEST['observed_head'] and loc['head_path_status'] == 'absent_untracked' and loc['working_tree_path_status'] == 'absent_untracked' and loc['working_tree_status'] == 'untracked')
    if src.exists():
        rc, out_ls, _ = run_git('ls-tree', 'HEAD', '--', loc['source_path'])
        rc2, out_st, _ = run_git('status', '--porcelain=v1', '--untracked-files=all', '--', loc['source_path'])
        rc3, out_head, _ = run_git('rev-parse', 'HEAD')
        check(f'{scope}:git_head_actual', rc3 == 0 and out_head == MANIFEST['observed_head'])
        check(f'{scope}:git_path_absent_actual', rc == 0 and out_ls == '')
        check(f'{scope}:git_status_actual', rc2 == 0 and out_st.startswith('?? '))
    pr = PROBE['scopes'][scope]
    check(f'{scope}:runtime_probe_product', pr['status'] == 'present' and pr['binding_digest'] == ip['g3_source_contract_binding_digest'] and pr['source_content_digest'] == ip['source_content_digest'] and pr['source_declaration_hash'] == ip['g3_source_declaration_hash'] and pr['construction_digest'] == rp['construction_digest'] and pr['source_path'] == loc['source_path'] and pr['source_sha256'] == loc['source_sha256']['value'] and pr['contract_ref'] == im['contract_ref'] and pr['axes'] == im['version_axes'])
    check(f'{scope}:f0_inputs_exact', ip['inputs']['f0']['source_factory_sha256'] == MANIFEST['inputs']['f0_factory_source_sha256'] and ip['inputs']['f0']['test_sha256'] == MANIFEST['inputs']['f0_factory_test_sha256'])
    s1 = ROOT / pathlib.PurePosixPath(ip['inputs']['s1_locator']['path'])
    check(f'{scope}:s1_locator_hash', s1.exists() and sha(s1) == ip['inputs']['s1_locator']['sha256'])

env = ROOT / pathlib.PurePosixPath(MANIFEST['inputs']['ad45_envelope_path'])
check('AD45_envelope_actual', env.exists() and env.stat().st_size == 9612 and sha(env) == MANIFEST['inputs']['ad45_envelope_sha256'])
factory = ROOT / 'src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl'; test = ROOT / 'test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl'
check('F0_exact_hash_actual', sha(factory) == MANIFEST['inputs']['f0_factory_source_sha256'] and sha(test) == MANIFEST['inputs']['f0_factory_test_sha256'])
root_manifest = ROOT/'docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/root_acceptance_r3/manifest.json'
check('root_acceptance_exact_hash', sha(root_manifest) == MANIFEST['root_acceptance_input']['sha256'])

old = {'realization': ('19ea4b7ec669da116c09293afa8e861de47650c83a756670d906f048a67cb1fd','e8ed40a06adf41ffc7f54ad83ad400ef7fc2c43d4047b8abb9e4819513fe87ee'),'control': ('2f6f3cbf4c31aaf893f070df9909b21be859062cbfa697fc76886b6906980021','cf01d5a328cee5d9d60a8c88d08a433be3b4567d2990cf63a34a23b6fcccc8a0'),'binding': ('05ae8d811483cde640c2c8b5dcf1ec167a4d0dc9f39c7616d01e99fd9085e624','3195387030f73cf6d3717902bc3242e24b68afef81e166002c6347115cad1bbf'),'bundle': ('9c33dee9ff48ef8c34afe9f08f5a23e4f08d849a39bd11bb366aceedabf28807','8faff2c23c017ab6801d4c4bb8a6a5eaeb6531a23d6b5d210b25386be236ca36')}
for scope, (ih, rh) in old.items():
    check(f'{scope}:old_s2_immutable', sha(ROOT/f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_identity_v1.json') == ih and sha(ROOT/f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_construction_receipt.json') == rh)

for path in ('archive/factory_probe.stdout.txt','archive/factory_probe.stderr.txt','archive/focused_probe.stdout.txt','archive/focused_probe.stderr.txt','archive/replay_process_1.stdout.txt','archive/replay_process_1.stderr.txt','archive/replay_process_2.stdout.txt','archive/replay_process_2.stderr.txt','archive/integrity.stdout.json','archive/integrity.stderr.txt','archive/plan_validator.stdout.txt','archive/plan_validator.stderr.txt','archive/scoped_diff.stdout.txt','archive/scoped_diff.stderr.txt','archive/fresh_s2_factory_probe.jl','archive/fresh_s2_replay_probe.jl','archive/focused_probe_runner.jl','archive/fresh_s2_integrity.py'):
    check(f'archive_present:{path}', (FRESH/path).is_file())
check('archive_factory_probe_pass', json.loads((FRESH/'archive/factory_probe.stdout.txt').read_text())['status'] == 'pass')
check('archive_focused_pass', 'focused_status=pass' in (FRESH/'archive/focused_probe.stdout.txt').read_text())
check('archive_replay_pass', all(json.loads((FRESH/f'archive/replay_process_{n}.stdout.txt').read_text())['status'] == 'replay_pass' for n in (1,2)))
check('archive_integrity_pass', json.loads((FRESH/'archive/integrity.stdout.json').read_text())['status'] == 'pass' and json.loads((FRESH/'archive/integrity.stdout.json').read_text())['passed'] == 99)
check('archive_repair_snapshot_referenced_exists', (FRESH/'archive/repair_r2_final_snapshot.json').is_file(), 'acceptance.md names archive/repair_r2_final_snapshot.json as frozen input, but this file is absent')

replay1 = json.loads((FRESH/'independent_review_r1/raw/replay_process_1.stdout.txt').read_text())
replay2 = json.loads((FRESH/'independent_review_r1/raw/replay_process_2.stdout.txt').read_text())
check('fresh_two_process_replay_equal', replay1.get('status') == 'replay_pass' and replay2.get('status') == 'replay_pass' and replay1.get('scopes') == replay2.get('scopes'))
check('fresh_two_process_exit_zero', json.loads((FRESH/'independent_review_r1/raw/replay_process_1.execution.json').read_text())['exit_code'] == 0 and json.loads((FRESH/'independent_review_r1/raw/replay_process_2.execution.json').read_text())['exit_code'] == 0)

result = {'status': 'pass' if not ISSUES else 'changes_requested', 'checks': len(CHECKS), 'passed': sum(c['pass'] for c in CHECKS), 'failed': len(ISSUES), 'issues': ISSUES, 'pid': os.getpid(), 'utc': datetime.now(timezone.utc).isoformat(), 'product_count': 8, 'scopes': list(SCOPES), 'archive_repair_snapshot_present': (FRESH/'archive/repair_r2_final_snapshot.json').is_file()}
print(json.dumps(result, ensure_ascii=False, separators=(',', ':')))
sys.exit(0 if not ISSUES else 2)
