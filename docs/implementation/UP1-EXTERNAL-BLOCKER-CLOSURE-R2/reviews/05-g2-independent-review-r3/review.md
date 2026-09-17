# UP1 external-blocker closure R2 — G2 independent review R3

## Verdict

`pass_limited`. No P1/P2 finding was observed. This is bounded software and
receipt-integrity preparation only; it grants no external authority, UP1,
B00/B04, provider, mesh, solver, engineering, physical, or R01–R10 credit.

## Fresh verification

- `python -B tools/up1_external_closure_r2/g2_mapping/integrity_validator.py`
  was run independently; exit `0`, `all_true=true`, 15 unique raw streams,
  4 zero-byte streams in the R2 rework receipt, and 10 manifest input hashes.
- The R2 47-case driver was run twice in fresh processes: A PID `89636`, B PID
  `100668`, common parent PID `95312`, both exit `0`. All 47 rows passed and
  semantic JSON was byte-identical after excluding timestamps/PIDs.
- The independent R3 checker returned `48/48` checks passed, including exact
  manifest/input hashes, all receipt-referenced raw byte/hash pairs, every
  empty-stream digest, integrity-audit PID/UTC/exit, R2 logic replay, and
  TEST_ONLY/non_evidence labels.

## Scope and drift check

The 47-case logic was compared against the prior R2 review output and did not
drift. This includes expected-binding replacement/missing/axis mutation/
self-reference, foreign candidate/source, canonical/source/declaration/
signature-payload/receipt hash attacks, duplicate/unknown fields, security
field negatives, TEST_ONLY isolation, and PRODUCTION without externally
verified authority.

The corrected empty-file SHA-256 is
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
All 15 raw streams and the four R2 rework empty streams now match their
receipts exactly. No Julia/DESC/solver/provider/mesh/heavy lane ran, and no
source, test, factory, registry, or historical artifact was modified.
