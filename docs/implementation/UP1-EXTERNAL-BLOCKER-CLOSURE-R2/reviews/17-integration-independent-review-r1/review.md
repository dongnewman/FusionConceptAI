# UP1 R2 integration slice independent review R1

## Decision

`rework_pending_dependencies` (P1 integration findings; environment and
revocation dependencies are independently still `rework`). The focused suite
and deterministic two-process check pass, but the runner can promote caller
supplied observations and caller supplied prior state without authenticating
them. Therefore this slice cannot be treated as a reliable integration gate,
even at the preparation-only boundary.

## Scope and method

Read-only review of the current integration implementation, focused tests and
17 evidence package, plus the public interfaces of witness, PKI, revocation,
source-axis, G2, environment, intake and aggregate components. Only this
review directory was written. No installation, download, network, Julia,
DESC, solver, mesh, provider, S3 or heavy-lane operation was used.

Fresh checks:

* `python -B -m pytest -q test/up1_external_closure_r2/integration/test_integration.py` twice: `6 passed` each run.
* `python -B -m py_compile` for integration `__init__.py`, `runner.py` and `cli.py`: exit `0`.
* Two independent child OS processes with the same TEST_ONLY package produced identical input and nine stage receipt hashes.
* The current 17 implementation evidence is marked `TEST_ONLY`, `non_evidence`, and `review_pending`; its receipt reports `pass_limited`, but that is superseded by this adversarial review.

## Findings

### F1 — P1: `_adapter_result` is an unauthenticated promotion path

At `tools/up1_external_closure_r2/integration/runner.py:141-145`, any mapping
with `_adapter_result == true` is passed directly to `_stage_record`. No
component validator is called, and `_stage_record` maps `status=verified` to
the internal `verified` state. The aggregate then accepts these stage states
and `run_pipeline` returns `eligible_for_authority_recheck`.

An independently constructed PRODUCTION package with all seven stage values
set to `{_adapter_result:true,status:verified,authority_verified:true}` reached
`eligible_for_authority_recheck`. The same values carried a foreign schema,
forged pipeline version, candidate/source/input fingerprints and forged
receipt hashes; all were ignored. This directly violates the requirement that
the runner call each component and reject foreign/tampered/unknown/duplicate
stage input. `authority_verified=true` is merely caller-controlled data here.

The intake branch at `runner.py:174-178` has a second variant: any mapping that
contains a `status` field is accepted without the adapter marker, spool, path,
or `AuthorityIntakeAdapter` call. A bare `{status:verified,
authority_verified:true}` intake record therefore participates in promotion.

Required repair: remove this bypass from production execution, or make it an
explicit non-promoting observation type that is always `typed_absence` or
`non_evidence`. Every stage must invoke its version-pinned public validator and
validate returned schema/status/error/claim ceiling plus candidate, source and
input bindings before an aggregate receipt is constructed.

### F2 — P1: package schema, aliases and cross-stage identity are not closed

There is no root package schema/unknown-field validation before fingerprinting
(`runner.py:215-221`). Adding an unknown root field, adding both `witness` and
`witness_authority` with conflicting values (`runner.py:128-135` silently
chooses the first), or putting foreign candidate/source values in a stage
observation still reached `eligible_for_authority_recheck` through F1.

The runner's `_fingerprints` function (`runner.py:109-118`) derives or trusts
top-level values, but `_aggregate_document` (`runner.py:190-206`) stamps those
values onto every synthetic receipt. It never compares them with the
component payload/result identity or a component-authenticated receipt. A
stage result's incoming `receipt_sha256`/`receipt_hash`, schema or version is
not checked; the runner computes a new hash over the wrapper instead. Thus
candidate/source/input fingerprint chain consistency is asserted by the
integrator itself rather than established from each component's receipt.

Required repair: define one strict integration-input schema (duplicate keys,
unknown fields, aliases and non-finite values rejected), forbid ambiguous
stage aliases, require exactly one stage representation, and require every
component receipt to expose and match the pipeline schema/version and all three
fingerprints. Do not synthesize a receipt that replaces an unverified
component receipt.

### F3 — P1: caller-controlled prior state can forge deterministic no-op

At `runner.py:222-225`, a matching `prior_state.input_fingerprint` causes the
runner to deep-copy arbitrary caller data and only overwrite `schema`,
`event`, `input_unchanged` and `no_publish`. It does not validate the prior
schema, receipt hash, stage set, stage receipt hashes, status, claim ceiling,
fingerprints, or `new_ad`.

With a matching digest and an otherwise forged prior object, the observed
result was `event=deterministic_noop`, `status=eligible_for_authority_recheck`,
`receipt_sha256=forged`, and `new_ad=true`. This violates no-new-AD and prior
state integrity boundaries and can preserve a caller-supplied promotion.

Required repair: authenticate or recompute the prior receipt from a strict
canonical state, verify exact stage/fingerprint/schema/version and require
`new_ad=false`, `no_publish=true`, and a non-promoting prior status before
returning a no-op. Invalid or unverifiable prior state must be
`fail_closed`/`terminal_deferred`, never copied.

## Verified controls and limits

The current six tests confirm production missing inputs are deferred, TEST_ONLY
is terminal/non-evidence, explicit invalid adapter status fails closed,
changed input is blocked as `intake_changed`, and two child processes are
semantically deterministic. Direct `replayed`, `foreign` and unknown adapter
status strings also reduced to fail closed. These are useful negative/status
mapping checks but do not close the F1 bypass.

External `expected_context`, anchors, replay key and ledger are accepted as
separate parameters, and the environment adapter forwards some of them. The
integration layer does not require them globally before production stage
promotion, and the adapter path can bypass all checks. This is therefore not
evidence that independent context/anchor/replay inputs are enforced.

The latest available component reviews independently report revocation/time/
replay R3 `rework` (Windows ACL/symlink/manifest gaps) and environment R4
`rework` (unsigned provenance metadata remains mutable). The integration
verdict is consequently capped at `rework_pending_dependencies`, with no
UP1, external-authority, T0, B00/B04, engineering, physical or R01-R10 credit.

## Re-review requirements

1. Remove or permanently non-promote `_adapter_result` and bare intake status
   shortcuts; prove each stage calls its real public validator.
2. Add strict root/stage schema and duplicate/unknown/foreign/alias rejection.
3. Bind authenticated component receipts to the exact candidate, source and
   input fingerprints and validate receipt hash/version/claim ceiling before
   aggregate construction.
4. Validate prior state cryptographically/semantically and force no-op to have
   no AD or promotion.
5. Re-run the full attack matrix in a new review revision after environment and
   revocation dependencies obtain independent pass status.

Claim ceiling: review-only, contract software preparation; no external
authority, UP1, parent-goal or downstream credit.
