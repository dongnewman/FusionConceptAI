# UP1 external-blocker closure R2 — G2 independent review R2

## Scope and identity

- Group: `R2-G2`; reviewer task: `/root/up1r2_g2_review`.
- Reviewer model/effort: `gpt-5.6-luna` / `high`.
- Frozen source revision: `b2c04d8339774635aaecd73651efcdb101e01b5d`.
- Inputs:返工后的 `production_g2_mapping.py`, `test_only_positive.json`,
  `typed_absent.json`, `expected_binding.json`.
- All review outputs are `TEST_ONLY=true`, `non_evidence=true`.

## Fresh commands

The independent matrix driver was run twice as separate `python -B` OS
processes (A PID `84336`, B PID `112216`, common parent PID `77792`, exit 0).
Each emitted 47 cases and all 47 rows passed; semantic JSON was byte-identical
after excluding process metadata. The matrix contains the original R1 34 case
IDs plus expected-binding and canonical/integrity attacks.

Two additional fresh wrapper processes ran the CLI with `--expected` for the
TEST_ONLY and typed-absence fixtures. Their child PID/parent PID/UTC/exit and
raw stream hashes are retained in `raw/cli_*.receipt.raw`.

The independent verification command was:

```text
python -B docs/implementation/UP1-EXTERNAL-BLOCKER-CLOSURE-R2/reviews/05-g2-independent-review-r2/verification.py
```

It independently checked component input hashes, source/fixture hashes, R2
rework receipt raw files and hashes, two-process replay, CLI metadata, labels,
and the no-heavy-lane rule. It found four receipt hash mismatches described in
`findings.md`; the implementation matrix itself had no failing row.

## Attack coverage

Covered duplicate JSON keys, unknown fields, repeated/missing axes,
bidirectional edge asymmetry, foreign candidate/source inconsistent and
self-consistent edits, expected-binding replacement/missing/axis mutation/
self-reference, canonical declaration hash forged/missing/reordered, source
identity/integrity hash forged, signature payload forged/missing, receipt
forged/missing, issuer/key/policy/name/EKU/keyUsage/revocation/freshness/
nonce/sequence/idempotency/replay, TEST_ONLY isolation, and PRODUCTION with no
externally verified signature authority.

The legal array permutation passed only after rebuilding the declaration,
signature-payload, and receipt hashes. A stale permutation was rejected.

## Claim ceiling and cleanup

The result is `rework`, dominated by the supplied receipt integrity defect;
no P1/P2-free `pass_limited` conclusion is possible. No Julia, DESC, solver,
provider, mesh, external operation, or heavy lane ran. No source, test,
factory, registry, or historical artifact was modified. Cleanup details are in
`cleanup_inventory.json`; only this review directory is owned by this task.
