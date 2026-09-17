# AD-34 status sync R1

Date: 2026-09-15  
Decision: `accepted_limited` architecture/work-order boundary  
Source decision: Sol/root acceptance of AD-34 repair R4 and independent review R5

## Synchronized machine nodes

### `UP1-04A-VNEXT-G3-BINDING-EDIT-PREC`

Status is `planned`, `scope_status=proposal`, `accepted=false`,
`resolution=review_pending`; `claim_ceiling=contract_only`. It depends only
on `UP2-01-G3-SOURCE-FEEDBACK-V1`. Its exact six-file scope is:

* `src/GenomeV5/G3/G3BindingChildEditabilityV1.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_tests.jl`
* `test/GenomeV5/G3/g3_binding_child_editability_v1_fixture.json`
* `test/GenomeV5/G3/static_qa_g3_binding_child_editability_v1.py`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/README.md`
* `docs/implementation/UP1-04A-VNEXT-G3-BINDING-EDIT-PREC/manifest.json`

Current implementation ceiling is `AbsentChildBindingV1` typed-absent
scaffold only. There is no feedback child. Link CAS is disabled until the
authority recheck is checked-present and same-candidate realization/control
source children are available. The immutable source payload owns
`initial_links`; editable body initialization is exact canonical-byte copy;
source/content/child/initial-state/history/state hashes and fail-atomic CAS
rules remain those frozen in repair R4.

### `UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC`

Status is `planned`, `scope_status=proposal`, `accepted=false`,
`resolution=review_pending`; `claim_ceiling=contract_only`. It depends on
`UP1-04A-VNEXT-T0`, has no launcher, and owns exactly:

* `src/GenomeV5/Integration/VNextDeclarationAuthorityRecheckV1.jl`
* `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_tests.jl`
* `test/GenomeV5/Integration/vnext_declaration_authority_recheck_v1_fixture.json`
* `test/GenomeV5/Integration/static_qa_vnext_declaration_authority_recheck_v1.py`
* `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/README.md`
* `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/manifest.json`
* `docs/implementation/UP1-04A-VNEXT-T0-AUTHORITY-RECHECK-PREC/acceptance.md`

It consumes the T0 bundle plus a fresh T0-owned declaration authority record
or typed absence and emits checked-present, typed-absent, or fail-closed. It
must never synthesize declaration identity/canonical bytes/receipt fields from
legacy `G3SFAuthorityV1`. Future T1 depends on both T0 and this recheck; T0 is
unchanged. Current output remains typed absent and no machine node was added
for the recheck beyond this planned entry.

## Pairing and authority boundary

For required layers G1 and G2, upstream authority has exactly one record per
layer. Duplicate, missing, unknown, candidate, target-layer, target-authority,
and duplicate/ambiguous target conditions fail closed with the fixed errors in
the R4 proposal. Multiple distinct target keys may share one layer. Legacy
authority six-field equality is an integrity comparison only and never grants
authority. Legacy `:actual` is always typed absent/terminal deferred until the
independent recheck supplies declaration ref/hash, canonical bytes and source
receipt.

## Cleanup inventory and protection

This status synchronization created no scratch, cache, launcher, source, test,
or unrelated-code path. Therefore no cleanup deletion was performed. The
pre-existing dirty and untracked inventory was inspected and remains
protected, including historical receipts, failed runs, `__pycache__` folders,
logs, and unrelated implementation records. No broad glob, global cleanup,
revert, or receipt rewrite was used. Any ambiguous ownership remains
preserved for the owner to review.

## Claim ceiling

All actual binding, feedback, control, T0 authority, T1, T2, provider, mesh,
engineering, physical, search, B00, B04, and R01-R10 credits remain false.
This synchronization records only accepted_limited architecture/work-order
boundaries; it does not authorize implementation or execution.
