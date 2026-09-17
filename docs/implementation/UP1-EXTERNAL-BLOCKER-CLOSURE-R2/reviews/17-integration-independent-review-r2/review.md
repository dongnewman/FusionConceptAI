# UP1 R2 integration slice independent review R2

## Decision

`rework_pending_dependency` (P1 integration findings remain; environment R5 is
`pass_limited`, while revocation R3 remains `rework` and the later R4 directory
contains raw evidence but no pass verdict). The R1 unauthenticated adapter
bypass is closed: current code routes stage values through the real validators.
However, receipt self-recomputation, authenticated prior-state semantics,
fingerprint provenance, aggregate completion, and ledger CAS are not closed.

## Scope and fresh verification

Read-only review of the current R2 integration implementation, tests, 17 slice
contract/evidence, all current public component call sites, and the latest
component review evidence. Only this R2 review directory was written. No
installation, download, network, Julia, DESC, solver, mesh, provider, S3 or
heavy-lane operation was used.

Fresh checks:

* `python -B -m pytest -q test/up1_external_closure_r2/integration/test_integration.py` twice: `6 passed` each run.
* `python -B -m py_compile` for integration `__init__.py`, `runner.py` and `cli.py`: exit `0`.
* The focused two-child-process test is semantically deterministic.
* A separate temporary-directory threaded race and HMAC mutation test was run; raw output is retained below.
* The prior 17 implementation manifest is intact (`8/8` listed bytes/SHA); no pycache/pyc was claimed or removed.

## R1 controls rechecked

The following now fail closed or defer as required:

* `_adapter_result` stage observations are not trusted; the real witness,
  PKI, revocation, source-axis, G2, environment and intake APIs are reached.
* Bare intake `{status: verified}` is passed to `AuthorityIntakeAdapter` and
  does not promote.
* Unknown root fields and duplicate stage aliases are rejected by
  `_strict_root`.
* Foreign candidate/source data, foreign schema and forged component receipt
  fields fail through actual validation.
* Missing expected context, anchors, key, ledger or intake spool yields
  terminal deferred/no publish.
* TEST_ONLY with absent material remains terminal deferred with
  `TEST_ONLY=true`, `non_evidence=true`; no eligible state was observed.
* HMAC-authenticated ledger tamper and replay-key replacement fail closed.

These results close the R1 promotion shortcut but do not establish that a
valid production chain can complete or that its receipts are authentic.

## Findings

### F1 — P1: top-level receipt hashes cannot be recomputed

`_finish` at `runner.py:207-213` computes `receipt_sha256` over `_semantic(out)`
while `out` does not yet contain either receipt field, then adds both
`receipt_sha256` and `receipt_hash` to the object. Recomputing the canonical
digest over the returned object therefore hashes additional fields and yields a
different value. The deterministic-noop branch at `runner.py:195-197` changes
`event`, `input_unchanged`, and other fields without recalculating the receipt.

Observed in a fresh temporary ledger: `first_recomputes=false` and
`second_recomputes=false`, with the second event `deterministic_noop`. A stored
receipt that cannot be recomputed from the returned state cannot serve as the
integration receipt chain or authenticate prior/no-op behavior.

Required repair: define a canonical receipt payload that explicitly excludes
both hash aliases, hash that payload, and verify/recompute after every state
transition including no-op. Keep the stored ledger receipt and returned result
semantically identical.

### F2 — P1: ledger locking is not compare-and-swap

`_IntegrationLedger.load` releases `_lock` before component evaluation, and
`commit` at `runner.py:147-155` unconditionally replaces the ledger. There is
no expected prior receipt/state hash or sequence precondition in `commit`.

A fresh race with delayed component evaluation let two concurrent callers both
complete `event=intake` and commit successfully against an initially empty
ledger (`both_commit_success=True`). The O_EXCL lock serializes individual
reads/writes, but it does not prevent a stale reader from overwriting a newer
state. Atomic replace is not CAS.

Required repair: carry the loaded prior receipt/state hash into commit, recheck
it while holding the lock, and return a typed replay/conflict failure for a
stale writer. Add real two-process contention evidence, not only sequential
semantic equality.

### F3 — P1: candidate/source fingerprint roots remain caller-self-supplied

`_package_fingerprint` at `runner.py:78-83` accepts any syntactically valid
64-character `candidate_fingerprint` and `source_fingerprint`; it does not
derive or compare them to the canonical candidate/source objects. Component
results are checked against these values at `runner.py:97-109`, so a future
component receipt bound to the same attacker-chosen values could satisfy the
integrator. The integrator therefore cannot establish candidate/source/input
identity from an independent anchor or canonical source declaration.

Required repair: derive candidate/source identities from authenticated canonical
inputs or require independent expected-context/anchor digests for them, then
bind every component receipt and the ledger state to those values. Merely
checking lowercase-hex shape is insufficient.

### F4 — P1: aggregate stage is never executed and eligible state is unreachable

After the ordered component loop, `runner.py:203-205` always creates a skipped
aggregate record with `upstream_not_authority_verified`; it never calls the
public `aggregate_gate.aggregate_document` API and never has a successful path
to `eligible_for_authority_recheck`. This is fail-safe for current missing
inputs, but it does not implement the documented contract that all independently
verified production stages may reach the preparation-only eligibility boundary.

Required repair: invoke the aggregate gate only after all stage receipts pass
strict binding and authority checks, preserve its result/hash, and keep
TEST_ONLY and any absence/invalid/replay state deferred or fail-closed.

### F5 — P2: authenticated prior state is only receipt-id checked and noop output is stale

At `runner.py:194`, a caller-supplied `prior_state` is accepted when only its
`receipt_sha256` equals the latest ledger receipt; other fields are not compared
to the authenticated ledger record. The current returned no-op is based on
`latest`, so the mutation did not promote in this run, but a mismatched prior
object is silently accepted and no field-level identity is proved. Combined
with F1, the no-op receipt is stale after its event update.

Required repair: require prior state to be an exact canonical/authenticated
match (or ignore it entirely and use only ledger state), reject mismatches, and
recompute the no-op receipt with `new_ad=false` and `no_publish=true`.

### F6 — P2: integration ledger path/reparse and Windows ACL provenance are not closed

The key is checked for regular-file/symlink status at `runner.py:115-119`, but
the ledger path and parent are not checked for symlink/reparse substitution,
owner or write permissions. The HMAC mutation/key-replacement negatives pass,
but that only proves integrity when the caller can trust the key/path. A
platform-capable reparse/ACL negative is still required for this ledger seam.

## Dependency and claim boundary

Environment provenance R5 is marked `pass_limited`. Revocation/time/replay R3
is `rework`; the newer R4 directory has raw runs but no independent pass
receipt. Therefore this review cannot exceed `rework_pending_dependency` and
grants no UP1, external authority, T0, B00/B04, engineering, physical or
R01-R10 credit.

## Re-review requirements

1. Make top-level and stage receipts recomputable from a declared hash payload.
2. Implement ledger compare-and-swap with stale-writer/replay evidence.
3. Anchor candidate/source fingerprints independently and verify every receipt
   schema/version/hash/claim ceiling and all three fingerprint domains.
4. Execute aggregate gate on a valid bound chain while retaining deferred and
   TEST_ONLY ceilings.
5. Reject non-exact prior states and close ledger reparse/ACL platform checks.
6. Re-run the full attack matrix after revocation obtains an independent pass.

Claim ceiling: review-only software-preparation analysis; no parent-goal credit.
