import hashlib, json, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[5]
FRESH = ROOT / 'docs/implementation/AD-48/S2-G3-FACTORY-IDENTITIES-FRESH-R2'
MANIFEST_PATH = FRESH / 'manifest.json'
SCOPES = ('realization', 'control', 'binding', 'bundle')

def digest(path):
    raw = path.read_bytes()
    return {'path': path.relative_to(ROOT).as_posix(), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}

manifest = json.loads(MANIFEST_PATH.read_text(encoding='utf-8'))
products = {}
for scope in SCOPES:
    products[scope] = {
        'identity': digest(FRESH / scope / 'factory_identity_v1.json'),
        'receipt': digest(FRESH / scope / 'construction_receipt.json'),
        'result': manifest['products'][scope]['result'],
    }
old = {}
for scope in SCOPES:
    old[scope] = {
        'identity': digest(ROOT / f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_identity_v1.json'),
        'receipt': digest(ROOT / f'docs/implementation/AD-48/S2-FACTORY-IDENTITIES/{scope}/factory_construction_receipt.json'),
    }
s1 = {}
for scope in SCOPES:
    p = ROOT / f'docs/implementation/AD-48/S1-SOURCE-LOCATORS/{scope}/source_locator_v1.json'
    s1[scope] = digest(p)
body = {
    'record_kind': 'AD48-S2-fresh-r2-repair-final-snapshot',
    'schema_version': 'AD48-S2-fresh-r2-repair-snapshot-v1',
    'task_id': manifest['task_id'],
    'repository_root': manifest['repository_root'],
    'observed_head': manifest['observed_head'],
    'manifest_frozen_fields': {k: manifest[k] for k in ('task_id','schema_version','status','accepted','accepted_scope','observed_head','claims')},
    'products': products,
    'old_s2_hashes': old,
    'inputs': {
        'f0': {
            'factory_source': {'path':'src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl','bytes':31581,'sha256':'1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4'},
            'factory_test': {'path':'test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl','bytes':14904,'sha256':'02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f'},
            'root_acceptance': digest(ROOT/'docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/root_acceptance_r3/manifest.json'),
        },
        's1_locators': s1,
        'ad45': {'handle_id': manifest['inputs']['ad45_handle_id'], 'handle_version': manifest['inputs']['ad45_handle_version'], 'envelope': digest(ROOT/'docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json')},
    },
    'self_hash_excluded': True,
}
raw = json.dumps(body, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode('utf-8')
(FRESH/'archive/repair_r2_final_snapshot.json').write_bytes(raw)
print(json.dumps({'status':'snapshot_written','path':'archive/repair_r2_final_snapshot.json','bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'products':8},separators=(',',':')))
