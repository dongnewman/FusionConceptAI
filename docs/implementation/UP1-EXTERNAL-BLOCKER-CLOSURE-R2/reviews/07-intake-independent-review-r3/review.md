# UP1 R2 authority_intake independent attack review R3

Decision: **rework** (`P2_evidence_count_mismatch`). No new P1 was
reproduced after handle-pinning, but pass_limited is blocked by the P2 below.
The claim ceiling remains `software_bookkeeping_only`; no external authority,
endpoint, signature, trust root, or UP1/T0/T1/T2 credit is claimed.

## Validation and 13/13 artifact check

Fresh focused validation exited 0. It ran 19 test cases: 17 executed tests
passed and 2 were skipped (ordinary symlink creation and the non-Windows
metadata race). The Windows Junction/reparse substitute and both insertion
race tests executed and passed.

The author manifest's 13 owned-input entries all match current byte counts and
SHA-256 values. Both retained raw stream files match the raw record exactly,
and the raw exit code is 0. Full independent matrix output is in
`raw/attack_matrix.json`.

## P2-1 — author validation count is internally inconsistent

The stored raw stream ends with `Ran 19 tests ... OK (skipped=2)`, which means
17 executed tests passed. However, the author manifest
(`07-authority-intake/manifest.json`) reports `tests_run=19`,
`tests_passed=19`, and `tests_skipped=2`; the validation receipt also says
`checks_passed=19` of `checks_total=19`. This is not a hash mismatch—the
13/13 bytes and raw hashes are exact—but the declared pass count overstates
executed passes by two. Regenerate the receipt/manifest with an unambiguous
definition (for example, `tests_run=19`, `tests_passed=17`,
`tests_skipped=2`) before acceptance.

## Handle-pinned attack results

### Input Junction insertion

The actual Windows Junction hook inserted a Junction after lexical/path
validation and before handle open. The opened handle facts rejected it with
`reparse_input`; no outside envelope was accepted.

### CAS/output Junction insertion

The actual output hook inserted a Junction before handle open. The write
handle validation returned structured `cas_symlink`, quarantined the input,
and wrote zero files in the external target. Pre-existing Junctions in each
of `incoming`, `quarantine`, `receipts`, `state`, and `cas` were all
rejected at initialization.

### Other required regressions

Absolute and `..` paths, hardlink aliasing, CAS wrong-digest replacement,
missing-CAS duplicate, oversize receipt, immutable receipt collision,
cross-process sequence/idempotency/ledger retention, and unsupported
non-Windows mode all behaved as contracted. Supplied `external_signature`
data remained non-authoritative: `signature=null`,
`external_signature_state=not_verified`, `typed_absence=true`,
`external_authority_claim=false`, `local_bookkeeping_only=true`.

## Acceptance gate

No P1/P2 implementation defect was reproduced in the handle-pinned paths.
Nevertheless, status is `rework` because the author evidence has a P2 count
mismatch. After correcting the manifest/receipt count fields, rerun this
review and require the same exact 13/13 and raw checks before
`pass_limited`.

