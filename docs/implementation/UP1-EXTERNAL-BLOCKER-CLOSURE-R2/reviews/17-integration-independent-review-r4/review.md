# UP1 R2 integration slice independent review R4

## Decision

`pass_limited_with_test_scope_deferred`. No implementation P1/P2 finding
remains in the reviewed integration slice. The only retained limitation is the
dynamic Windows symlink/reparse fixture: creating a real symlink returned
WinError 1314 because this review environment lacks the privilege. Injected
symlink, reparse-attribute and ACL-provider failures were exercised and fail
closed or become typed storage-unavailable; the dynamic fixture limitation is
explicitly not claimed as passed.

This result is limited to offline software preparation and inherits the
revocation dependency verdict `pass_limited_with_test_scope_deferred`. It does
not provide production external authority, UP1, T0, B00/B04, engineering,
physical or R01-R10 credit.

## Scope and fresh verification

Read-only review of current integration implementation/tests/docs, all current
public component interfaces, current 17 evidence, and environment/revocation
review verdicts. Only this R4 review directory was written. No installation,
download, network, Julia, DESC, solver, mesh, provider, S3 or heavy-lane
operation was used.

Fresh command results:

* `python -B -m pytest -q test/up1_external_closure_r2/integration/test_integration.py` twice: `11 passed` each run.
* `python -B -m py_compile` for integration `__init__.py`, `runner.py` and
  `cli.py`: exit `0`.
* Independent top-level receipt/state recomputation passed for fresh output
  and deterministic noop (`sequence=2`, `new_ad=false`).
* HMAC ledger tamper/rollback and replay-key replacement failed closed.
* Independent two-process CAS produced exactly one commit and one stale-writer
  conflict; semantic two-process output remained deterministic.
* Valid candidate/source anchor contexts recomputed the supplied digests;
  context mutation and non-hex 64-character anchors failed closed.
* Public aggregate API returned `verified`/
  `eligible_for_authority_recheck` with `T0=false`, `ad_created=false`.
  A bound deterministic component probe reached the same status through
  `run_pipeline`.
* Injected storage failures returned the expected reparse/ACL errors. Real
  symlink fixture creation was unavailable (WinError 1314), retained as an
  explicit test-scope limitation.

## Full attack replay

R1–R3 attacks remain closed: `_adapter_result` and bare intake status are sent
to real component APIs; unknown root fields, duplicate aliases, foreign
candidate/source/schema/receipt data, malformed statuses, missing external
context/anchors/key/ledger/spool, replay/tamper/rollback and changed prior
state all fail closed or defer. TEST_ONLY remains `non_evidence` and cannot
reach eligibility. The exact observed rows are retained in
`raw/attack_matrix.txt`.

## Controls confirmed

The strict root schema requires the versioned package shape and rejects unknown
fields. External candidate/source fingerprints require lowercase 64-hex values;
optional `candidate_context` and `source_identity` are canonically recomputed
against those anchors. Component results require schema, authority flag, all
three fingerprint domains, matching receipt hash aliases and a bounded claim
ceiling before they can be verified.

The ledger checks storage-path reparse/ACL capability, authenticates its latest
state, verifies receipt and state digests, and uses an O_EXCL lock plus
compare-and-swap expected receipt/sequence. Prior state requires complete
canonical equality with the authenticated latest record. No-op transitions
recompute both digests. The aggregate gate is called only after all ordered
component stages are verified; the production positive probe reached
`eligible_for_authority_recheck` while retaining `T0=false` and no AD.

## Test-scope limitation

On this Windows host, `icacls` is available and injected `replay_key` symlink,
reparse attribute and ACL-provider denial paths were observed as
`replay_key_reparse_or_symlink`, `replay_key_reparse_point` and
`replay_key_owner_acl_unavailable`. A real symlink could not be created due to
WinError 1314. This is recorded as `test_scope_deferred`, not as an
implementation failure or a dynamic pass.

## Dependency and claim ceiling

Environment provenance R5 is `pass_limited`. Revocation/time/replay R5 is
`pass_limited_with_test_scope_deferred`; its owner mutation is explicitly
`not_executed/test_scope_deferred`. The integration verdict therefore uses the
same limited-with-deferred scope. No production trust, external authority,
UP1, parent-goal or downstream credit is granted.

## Re-review trigger

Resolve the privileged Windows symlink/owner dynamic fixture if a fully dynamic
platform claim is required. Any change to the integration code, component
interfaces, receipt schema, ledger protocol or dependency verdict requires a
new independent review revision.

Claim ceiling: `pass_limited_with_test_scope_deferred`, software preparation
only, TEST_ONLY/non-evidence.
