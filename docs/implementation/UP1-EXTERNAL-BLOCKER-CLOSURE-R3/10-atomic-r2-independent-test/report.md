# UP1 R3 — 09 repaired prototype / atomic-r2 independent test

结论：'fail_limited'。本轮仅为离线软件探针；'formal_credit=none'、
'authority_credit=false'、'no_publish=true'，不产生任何 formal/authority/publish
结论。未启动 AD/S3、Julia、DESC 或 solver；无网络/外发。

## Frozen scope and integrity

被测实现与既有测试在 'freeze_manifest.json' 中冻结，随后由
'hash_check.json' 重算，5 个文件全部 'unchanged=true'。本轮只新增本目录的
探针和证据文件，没有修改被测实现或 'test/up1_external_closure_r3/atomic_bundle'
测试。

Implementation hashes:

- 'tools/up1_external_closure_r3/atomic_bundle/__init__.py' —
  '259a1550c703f0d2d1a437668ce7a9b2ecec70aa88727e5d232f1442c2c75a81'
- 'tools/up1_external_closure_r3/atomic_bundle/bundle.py' —
  '087eb10f58c83581d4bc8b42e79b7aee929a273432c43fc62c8a4dc4277c6665'
- 'tools/up1_external_closure_r3/atomic_bundle/canonical.py' —
  '95402ce98bb3567301df24808f5941abe03d4dc32256d72393c5689ea1e5d51b'

## Focused test, serial twice

Command:

'python -B -m unittest discover -s test/up1_external_closure_r3/atomic_bundle -p test_*.py'

| run | PID | UTC start → end | exit | raw stdout SHA-256 | raw stderr/combined SHA-256 | result |
|---:|---:|---|---:|---|---|---|
| 1 | 97676 | 2026-09-17T00:11:23.6092791Z → 2026-09-17T00:11:25.2517987Z | 0 | 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' | 'e9821dc0d15bfb00809704aae4897bbc56d6af240ea89b4798dace0c769c61ee' | 'Ran 20; OK; skipped=1' |
| 2 | 93080 | 2026-09-17T00:11:25.2769682Z → 2026-09-17T00:11:26.9189178Z | 0 | 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' | '62479e5d5ef0c9db5622795e2a90b676980ce39a4a19ca09c25721e3605819ad' | 'Ran 20; OK; skipped=1' |

The existing one skip is the host symlink/reparse privilege limitation.

## Independent attacks

The probe was run at
2026-09-17T00:13:49.6444272Z–2026-09-17T00:13:50.8643158Z, PID '16456',
exit '0'; stdout SHA-256
'f8d4042f98762b628f46d5472d67704a2723353b784a64dd8fafb2100299fd31', stderr
SHA-256 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'。
Raw JSONL is in 'raw/independent_attack.stdout.raw'.

| probe | outcome |
|---|---|
| Existing CAS hardlink | PASS — 'CAS_HARDLINK_REJECTED' |
| Pre-root and pre-parent real reparse | typed 'SKIP' — Windows 'WinError 1314'; no fabricated pass |
| Post-root and post-parent injected reparse | PASS — both 'CAS_REPARSE_POINT_REJECTED', with call-count observations |
| G2 directional inverse | PASS — forward/reverse row digests independently recomputed and distinct |
| G2 authority tamper | PASS — mapping/ref/row digest errors observed |
| Decision precedence | PASS — real errors reject before 'not_executed' defer; clean fixture defers |
| TEST_ONLY owner/receiver/context | PASS — 'TEST_ONLY_NON_EVIDENCE' observed in all three paths |
| EHP04 local bytes | PASS — contained Julia/Python/binary bytes verified |
| EHP04 local receipt and tamper | PASS — executed local receipt closes; tampered receipt gives 'EHP04_FIXTURE_RECEIPT_UNBOUND' |

## 26-vector builder attack

The independent audit finds 'static_placeholder=true': the current test-local
builder comprehension writes every R01–R25 value to the same '"mutation"' path
and uses one expected 'SCHEMA_INVALID' assertion. D01 writes one
'independent_review' shape but also produces 'SCHEMA_INVALID'. Replaying all 26
inputs yielded only R01's expected code; R02–R25 and D01 failed their matrix
expected code/decision checks. Therefore the claimed “26 independent builders”
is not established, and this is the limiting failure behind 'fail_limited'.

## Boundary

This is a local software/prototype result only. It does not mint or verify
external authority, does not provide formal credit, and must not be promoted to
engineering, physical, scientific, R01–R10, or publication acceptance.
