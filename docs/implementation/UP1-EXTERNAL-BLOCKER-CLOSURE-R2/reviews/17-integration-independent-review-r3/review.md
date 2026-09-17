# UP1 R2 integration slice independent review R3

## Decision

`rework_pending_dependency`. The R1/R2 bypasses, receipt/state recomputation,
noop transition, HMAC tamper handling and real two-process CAS now pass the
focused probes. The positive production path remains broken by an undefined
`role` variable, and external fingerprint anchors accept non-hex values. These
are integration P1 findings. Environment R5 is `pass_limited`; revocation R5
is still under review with no verdict receipt in the current directory, so the
dependency gate cannot pass.

## Scope and verification

Read-only review of current integration code/tests/docs, public component APIs,
current 17 evidence, and available environment/revocation review records.
Only this R3 review directory was written. No install, download, network,
Julia, DESC, solver, mesh, provider, S3 or heavy-lane operation was used.

Fresh checks:

* `python -B -m pytest -q test/up1_external_closure_r2/integration/test_integration.py` twice: `9 passed` each run.
* `python -B -m py_compile` for integration files: exit `0`.
* Independent direct probes recomputed top-level `receipt_digest` and
  `state_digest` on fresh and deterministic-noop outputs.
* Independent HMAC tamper/key-replacement probes failed closed.
* Fresh two-child Python `-B` race produced exactly one intake commit and one
  `integration_ledger_compare_and_swap_conflict` rejection.
* Windows `icacls` capability is present; symlink fixture creation returned
  WinError 1314, so a dynamic reparse negative remains unavailable.

## R1/R2 attack replay

`_adapter_result` is no longer a bypass: the real component functions are
invoked. Bare intake status is sent to `AuthorityIntakeAdapter` and does not
promote. Strict root schema rejects unknown fields and duplicate aliases;
foreign stage candidate/source/schema/receipt values fail closed. Missing
context, anchors, key, ledger or spool is terminal deferred/no publish.
TEST_ONLY material remains terminal deferred/non-evidence. These controls are
confirmed in `raw/attack_matrix.txt`.

## Findings

### F1 — P1: positive aggregate path raises `NameError`

At `runner.py:288`, status reduction tests `role == "PRODUCTION"`, but
`role` is never defined in `run_pipeline`. The aggregate branch at
`runner.py:283-286` is reached when all stage records are verified; an
independent probe supplied deterministic component results satisfying the
binding preconditions and observed `NameError: name 'role' is not defined`.

Consequently a valid bound production chain cannot return
`eligible_for_authority_recheck`; the documented aggregate completion path is
not executable. This is more than a conservative deferred result: it is an
uncaught program exception in the claimed positive path.

Required repair: derive `role` from the strict root once, invoke the real
aggregate gate only after all component receipts pass, then reduce its result
with an explicit production/TEST_ONLY ceiling. Add a positive integration test
that reaches aggregate and verifies its receipt/hash and final status.

### F2 — P1: independent fingerprint anchors are not strictly typed

`_package_fingerprint` at `runner.py:78-83` accepts `candidate_fingerprint` and
`source_fingerprint` anchor values if they are strings of length 64; unlike
`_strict_root`, it does not require lowercase hexadecimal. An independent probe
with `candidate_fingerprint='x'*64` and `source_fingerprint='y'*64` was accepted
and persisted into the output fingerprint map.

This allows a malformed/foreign anchor to become the root identity for every
component receipt and ledger state. The value is not promoted to authority in
the current deferred case, but the boundary is not closed for a future valid
chain.

Required repair: apply the same exact lowercase-hex digest schema to external
anchors, validate anchor schema/version and bind candidate/source digests to
the independently supplied canonical context rather than merely copying
strings.

### F3 — P2: caller prior state is not compared exactly

`runner.py:194` checks only `prior_state.receipt_sha256` against the latest
authenticated ledger receipt. Other caller fields are not compared with the
ledger state. The current output remains deferred and `new_ad=false`, so no
promotion was observed, but a mismatched prior object is silently accepted.

Required repair: ignore caller state except as an exact canonical snapshot, or
compare schema/version/sequence/event/status/fingerprints/state hash and all
stage receipts before accepting it; mismatch must fail closed.

### F4 — P2: Windows reparse/owner/DACL dynamic proof remains unavailable

`_check_storage_path` now attempts reparse detection and invokes `icacls`, and
regular temporary-path checking passed. However, creating the required symlink
fixture failed with WinError 1314 because this environment lacks the privilege.
No owner/DACL semantic negative was independently demonstrated. This is an
explicit capability gap, not a pass.

## Verified state and dependency boundary

Top-level receipt and state hashes recompute correctly after the R2 repair;
deterministic noop increments sequence and recomputes both hashes. HMAC ledger
tamper and key replacement fail closed. The real two-process CAS negative has
one commit and one stale-writer conflict. Deterministic two-process output is
also stable. These checks do not repair F1/F2.

Environment provenance R5 is recorded as `pass_limited`. Revocation R3 remains
`rework`; the current revocation R5 directory has only `acl_review_harness.py`
and no pass verdict/review receipt. Therefore this review remains capped at
`rework_pending_dependency`, with no UP1, external-authority, T0, B00/B04,
engineering, physical or R01-R10 credit.

## Re-review requirements

1. Define `role` and prove a real all-verified aggregate/eligible path.
2. Reject non-hex or otherwise untyped external fingerprint anchors and bind
   them to an independent candidate/source context.
3. Enforce exact prior-state equality or reject caller prior snapshots.
4. Obtain a platform-capable Windows reparse/owner/DACL negative, or retain an
   explicit unavailable capability status in the contract.
5. Re-run all attacks after revocation R5 receives an independent verdict.

Claim ceiling: review-only software preparation; no parent-goal credit.
