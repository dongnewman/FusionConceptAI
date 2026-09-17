# UP1 R2 revocation/time/replay independent review R4

- verdict: `rework`
- scope: `tools/up1_external_closure_r2/revocation_time_replay/**`, its focused tests, and the 03 evidence closure only
- claim ceiling: `TEST_ONLY non_evidence`; no external authority, UP1, B00/B04, engineering, physical, provider or R01-R10 credit
- reviewer: delegated `gpt-5.6-luna` / high; fresh Python `-B`; Windows 11 host; no network

## 1. Independent execution

The fresh focused run is `11 passed, 1 skipped` (raw output in `raw/pytest.stdout.raw`). The single skip is the existing symlink fixture at test line 160: Windows policy in this environment does not permit creating that symlink. The fresh independent harness is a separate `python -B` process and launches separate `python -B` CLI children, including a two-process race. Compilation of all module Python files returned `compile_ok`/exit 0. No OS wall clock, mtime, Git time, network, CRL/OCSP/TSA service, solver, provider, or production artifact was used.

## 2. R1-R3 attack replay

The raw harness records the following observed outcomes:

| attack | observed outcome |
|---|---|
| first commit, same nonce replay, contiguous next sequence, sequence gap | valid/exit 0; `nonce_replayed` or `sequence_gap`/exit 2 |
| HMAC-valid duplicate nonce, duplicate idempotency, and index mismatch | `ledger_corrupt`, fail-closed/exit 2 |
| missing explicit key and omitted key (automatic generation probe) | `replay_ledger_absent`, `typed_absent`, no key created |
| key replacement after a committed ledger | `ledger_corrupt`/exit 2 |
| duplicate JSON, nonfinite JSON, wrong source type, string `revocation.available` | typed protocol errors/fail-closed/exit 2 |
| revoked, stale `next_update`, unknown, invalid signature | `certificate_revoked`, `revocation_response_stale`, `revocation_status_unknown`, or `certificate_signature_invalid`/exit 2 |
| two processes, same nonce/sequence/idempotency | exactly one valid commit and one `nonce_replayed`/exit 2 |

This rechecks the former caller-resettable snapshot, authenticated ledger state tamper, HMAC-valid semantic corruption, key replacement, parser/canonical-digest boundaries, strict TEST_ONLY/profile/type checks, stale/unknown/revoked CRL/OCSP paths, and atomic two-process replay. The source binds the key only through the explicit non-payload `--key`/`key_path` input; it does not derive or generate a key from the receipt payload or ledger path. All result/error paths carry the `TEST_ONLY non_evidence` claim ceiling and signed-receipt-only clock/network labels.

## 3. Windows ACL and reparse review

Live disposable-file checks passed:

- a restricted key was accepted;
- adding an Everyone read ACE, Users read ACE, or Authenticated Users read ACE was rejected as `trusted_key_acl_invalid`/fail-closed;
- making the key/ledger path parent a Windows Junction was rejected as `ledger_corrupt`; both the key-parent and ledger/lock-parent paths were exercised;
- monkeypatching the ACL verifier lookup to unavailable returned `trusted_key_acl_unsupported`/`typed_absent`, never valid.

The implementation's Windows verifier (current `core.py:298-341`) obtains owner/DACL/SDDL from PowerShell, permits only current user/SYSTEM/Administrators owners, rejects broad allow identities and inherited broad ACEs, and treats unavailable/unparseable verification as typed absence. `_reject_reparse` (`core.py:274-295`) checks each existing path component, final regular-file status for the key, and realpath equality. The focused symlink case remains the one explicitly recorded environment skip; the Junction/realpath escape was dynamically proven above.

The harness attempted a foreign-owner mutation with `icacls /setowner *S-1-5-20`; Windows returned error 1307 (the unprivileged test token cannot assign that SID as owner), so no false positive is claimed for that mutation. The source owner allowlist and the repair receipt's restricted-owner proof remain recorded, but the requested foreign-owner rejection is not dynamically proven here.

## 4. Evidence closure

The main 03 manifest currently points to `repair_r2/run_receipt.json`, lists all eight `repair_r2/raw/**` streams, and its listed source/raw SHA-256 values independently recompute successfully. Its current source hashes are:

`__init__.py` `A657EE0C...546AD`; `core.py` `1F134AB4...7F83`; `cli.py` `FEC3DAAA...CBD21`; focused test `821D830C...07A5F`; two-process driver `75205CC5...5F9E2`.

The R4 receipt/manifest below binds the fresh source hashes, harness hash, focused raw streams, exact commands, PIDs/parent PID where observed, semantic rows, and cleanup inventory. Manifest self-hash is excluded. All retained raw outputs are under this R4 review directory; the implementation, tests, and prior evidence receipts were not modified.

## 5. P2 and decision

### R4-P2-01 — foreign-owner rejection lacks a live receipt

The acceptance request explicitly requires an owner-mismatch negative. The current medium-integrity token cannot assign a foreign owner (`icacls` 1307), so the harness row is an environmental skip rather than a pass. Required fix: run the same disposable-key mutation under a controlled Windows fixture with `SeRestorePrivilege` (or equivalent privileged owner fixture), prove the owner SID is outside current user/SYSTEM/Administrators, and retain the raw `trusted_key_acl_invalid`/exit-2 output. Until that receipt is attached, this review remains `rework`; no P1/P2-free `pass_limited` verdict is granted. The explicit symlink skip is also retained as an environment note. This package does not establish production trust roots, real CRL/OCSP/TSA authority, external attestor identity, or any parent UP1/B00/B04/engineering/physical gate.
