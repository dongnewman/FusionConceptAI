# UP1 R2 revocation/time/replay independent review R3

- review revision: `03-revocation-independent-review-r3`
- group: `W2-R2-03-revocation-time-replay`
- reviewer: independent Luna worker (`gpt-5.6-luna`, high)
- verdict: `rework`
- claim ceiling: `TEST_ONLY non_evidence` / contract-software preparation only
- write boundary: only this R3 review directory was written; implementation, tests and prior 03 evidence were read-only

## Fresh runs

Fresh command:

```text
python -B -m pytest -q -rs test/up1_external_closure_r2/revocation_time_replay/test_revocation_time_replay.py
```

Observed `8 passed, 1 skipped`; the skip is line 159's `symlink creation unavailable in this fixture environment`. The independent harness was a separate `python -B` process and spawned separate CLI processes for key/replay/concurrency cases. Raw output and hashes are in `raw/` and `run_receipt.json`. No network, OS wall-clock trust decision, Git time, mtime, Julia, DESC, solver, mesh, provider or external operation was used.

## Findings

### R3-01 — Windows owner/permissions control is not enforced (P1)

`PersistentReplayLedger._key()` checks owner only when `os.getuid` exists and checks mode bits only when `os.name != "nt"` (`core.py:293-310`). On the current Windows host, a key changed to mode `0644` was accepted and the receipt returned valid (`owner_permissions_0644` in `raw/attack_harness.stdout.raw`). Thus the required owner/perms attack is not dynamically closed on this platform. If the key directory is writable by another actor, key replacement plus ledger replacement can forge authenticated state.

Required fix: use a Windows ACL/DACL owner and write-access check (or fail closed when it cannot be proven), verify the key path and parent ACLs, and add a Windows-capable fixture/receipt proving rejection of broad permissions and foreign owner. Do not treat POSIX mode checks as portable proof.

### R3-02 — Symlink/reparse dynamic coverage is skipped, not passed (P2)

Both the focused suite and the independent harness could not create a symlink and recorded a skip (`trusted_key_symlink`, `OSError`). The static `_reject_reparse()` logic is present, but no runtime evidence proves it rejects a key symlink/reparse path on this host. Reparse-point handling remains unverified for the requested acceptance boundary.

Required fix: run the same negative on a fixture-capable Windows ACL/symlink environment or use a controlled reparse-point test fixture; retain the raw process/exit evidence. A skip may remain explicitly marked unavailable, but cannot be counted as closed for `pass_limited` without a separate platform proof.

### R3-03 — 03 evidence manifest is stale and does not close `repair_r2` (P2)

The current `03-revocation-time-replay/evidence_manifest.json` declares `repair_revision` `repair-r1-after-...`, points `run_receipt` and `repair_receipts` at `repair_r1`, and lists only repair-r1 raw artifacts. The implementation/test hashes now match the R2 source, and the listed repair-r1 raw hashes independently match, but `repair_r2/run_receipt.json` and its raw streams are not included in the manifest closure. The 03 record therefore cannot establish which receipt belongs to the current source revision. The repair-r2 receipt reports the correct `8 passed, 1 skipped` run, but an unreferenced receipt is not admissible evidence.

Required fix: create a new evidence manifest revision that points to `repair_r2/run_receipt.json`, lists and hashes every repair-r2 raw artifact, binds current source/test hashes and the explicit skip, and records manifest self-hash exclusion. Do not amend old receipts in place.

## Verified controls

- HMAC-valid duplicate idempotency entries, duplicate nonce entries and bidirectional index mismatch all return `ledger_corrupt`/exit `2`.
- Missing explicit key and omitted automatic key generation return `replay_ledger_absent`/`typed_absent`; no adjacent key is auto-created.
- Replacing the explicit key after a commit returns `ledger_corrupt`/exit `2`.
- Same-key/same-digest replay is `replayed`/fail-closed per the repaired component contract; sequence rollback/gap is rejected.
- Duplicate JSON and non-finite JSON inputs return typed parser errors with fail-closed result and exit `2`; source type and `revocation.available` string attacks are rejected.
- OCSP valid chain is accepted and bad chain is fail-closed; two concurrent processes produce exactly one valid commit and one replay rejection.
- Current implementation source hashes and every raw hash referenced by the existing repair manifest independently recompute successfully. This is integrity only and does not repair the stale manifest closure.
- No trust decision uses OS wall-clock time; `time.monotonic()` is confined to lock timeout handling. All outputs retain `TEST_ONLY`/`non_evidence` claim boundaries where emitted.

## Rework acceptance

Before a new review, add Windows ACL/owner/perms enforcement or a fail-closed proof, obtain a non-skipped symlink/reparse negative (or explicitly document a separate platform gate), and publish a new manifest/receipt closure for `repair_r2`. Then rerun the complete attack set in a new review revision. Until these P1/P2 findings are closed, this component is not `pass_limited`; it grants no external authority, UP1, B00/B04, engineering, physical or R01-R10 credit.
