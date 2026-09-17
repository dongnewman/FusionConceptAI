# Independent review R1 — M5-SEARCH-R2 machine-checker scope contract R1

## Decision

`NO-GO_FOR_FUTURE_CHECKER_IMPLEMENTATION / NO-GO_FOR_EXECUTION`.

This was a read-only JSON/schema/hash/owner-scope audit. No checker, fixture,
authority receipt, test, registry, search, Julia, solver, provider, mesh,
physical, performance, or source path was created or run. The only permitted
write root for this review is:

`docs/implementation/UP5-EARLY-PREPARATION/M5-SEARCH-R2/reviews/04-machine-checker-scope-independent-review-r1/**`

The package must remain `review_pending` / `not_implemented` /
`not_executed` / `terminal_deferred`, with `screen_only`, `no_publish=true`,
and `formal_credit=none`.

## Read-only evidence

| check | result |
|---|---|
| 04-package JSON parse | 6 files parsed; pass |
| 04 `hash_manifest.json` | 9 entries, 0 missing/mismatched; pass |
| 04 manifest input closure | 18 entries, 0 missing/mismatched; pass |
| future checker owner `tools/m5_search_contract_r2/check_contract.py` | absent |
| future test owner `test/m5_search_contract_r2/test_check_contract.py` | absent |
| append-only evidence directory | absent |
| negative vector count/IDs | 15; NV-01..NV-15; pass |
| Julia/search/checker execution | all false |

The frozen raw validation record is internally stale: it claims

`MANIFEST_SHA256=5c1dc1c3f62d2a653991e65cd0154cd44f9c7f2d49dd60f7e285374aabf1f7ec`
and
`HASH_MANIFEST_SHA256=4fe5e45b7fb61dd79241f0f452cf36f45c9d99ca1d74a664c71a55c57e8c2f24`,
while the current bytes hash to

`manifest.json = fd5498df2c2d30a0072d6979357f82ab58cc5a018ff6fb4a30eadf67ae1cf812`

and

`hash_manifest.json = 2e99f1fd2daf883d70bdb15ed7b271f7cb06da75b0e025d5abdb5b5fbb516831`.

The audit process therefore exited `1` with failed check
`RAW_STALE_SELF_HASH_CLAIMS`; raw stdout/stderr, PID and UTC are preserved in
`raw/static_review.stdout.raw` and `raw/static_review.stderr.raw`. This is a
review-evidence/provenance defect, not permission to repair the 04 package in
this review.

## P1/P2 machine-relation coverage

The 15 vectors are useful controls, but they do not strictly cover every
P1/P2 machine relation or every required sub-relation.

| finding/relation | vectors | coverage judgment |
|---|---|---|
| P1-01 authority metadata / typed absence | NV-01, NV-02 | direct, but no explicit stale-version/foreign-owner mutation |
| P1-02 content/operational/replay separation | NV-03, NV-04, NV-12, NV-13, NV-14 | direct core coverage; no explicit two-attempt changed-trace/config join vector |
| P1-03 accepted M5-C gate identity | NV-05 | direct core coverage; no separate null-raw/stale-history branch |
| P1-04 budget arithmetic/fold | NV-06, NV-07 | direct arithmetic/fold only; no explicit stage/scope/seed/cap/sequence mutation |
| P1-05 descriptor identity | NV-08 | direct cell/hash mismatch only; no explicit axis/label-erasure/tie-break/full-chain mutation |
| P2-01 failure precedence | NV-09 | direct caller-rank control only; no competing terminal observations |
| P2-02 prohibited scan | NV-10 | direct empty-input control only; no token-order/algorithm/unscanned-claim control |
| P2-03 upstream provenance/hash | NV-02 is only analogous | **not direct**: no mutation names a bound review/repair upstream path or its manifest entry |

Thus every principal P1 finding has at least one related vector, and P2-01/
P2-02 have one narrow vector, but the strict answer to “all P1/P2 machine
relations covered?” is **NO** because P2-03 is not directly exercised and the
sub-relations above remain uncovered.

The contract also specifies MC-14 CLI/process receipt and MC-16 claim ceiling,
but no negative vector tests missing required CLI/raw/PID/UTC/exit binding or a
checker-pass claim being presented as fixture, authority, M5-C, search,
execution, or formal credit. MC-01 only has a changed-byte mutation, not
missing/duplicate/unexpected path mutations. These omissions matter for the
future implementation test owner.

## Schema and receipt observations

All six JSON files parse and the three schemas declare `additionalProperties:
false` at their relevant object roots. This is shape validation only; no
sealed input bundle or output receipt exists to validate.

The output schema does not require `implementation_credit` or `formal_credit`
even though it declares those properties, and it does not schema-bind
`status` to `exit_code` or `precedence_rank` to the derived failure class. The
input schema permits a nullable caller field for `input_bundle_sha256`. The
future checker must enforce these relations by recomputation and must reject
caller-supplied identity/rank values; schema acceptance cannot be treated as
machine closure.

## Checker-pass boundary

Even a future `contract_machine_closure` (exit `0`) is only a recomputed
contract relation result. It must never authorize or imply fixture validity,
authority validity, an accepted M5-C gate, search completion, execution
success, or formal credit. The implementation must force
`claim_ceiling=screen_only`, `implementation_credit=none`,
`formal_credit=none`, and `no_publish=true` in the output and must retain the
current typed-absent closure as `not_executed` (exit `11`), not as a positive
authority result.

## Authorization and exact future file scope

`future checker implementation authorized: NO`.

Before any implementation authorization, the stale raw self-hashes and the
coverage gaps above require a reviewed correction and another independent
review. If a later reviewed decision authorizes implementation, the exact
allowed paths are only:

* `tools/m5_search_contract_r2/check_contract.py`
* `test/m5_search_contract_r2/test_check_contract.py`
* `tools/m5_search_contract_r2/evidence/**` (append-only evidence records)

No source, registry, existing test, review, repair package, search, Julia,
solver, provider, mesh, physical, or performance path may be modified or
created by that implementation. The current review writes only under its
declared review root.

## Process record

* role: static JSON/schema/hash/owner audit (read-only)
* PID: `62392`
* UTC start: `2026-09-17T04:44:37.9906482Z`
* UTC end: `2026-09-17T04:44:38.1336650Z`
* exit: `1` (expected finding: `RAW_STALE_SELF_HASH_CLAIMS`)
* Julia started: `False`
* search started: `False`
* checker implemented: `False`
* raw stdout: `raw/static_review.stdout.raw`
* raw stderr: `raw/static_review.stderr.raw`
