# R4 contract delta from R3

This additive, contract-only delta closes exactly the three blockers in
`reviews/05-scope-contract-independent-review-r1/report.md`.  It does not
authorize implementation or runtime work.

1. D12 now hashes the real `/canonical_bundle/canonical_bytes` field.  The
   field is base64 for the exact JCS UTF-8 LF bytes of `payload`; the checker
   decodes it, compares the decoded bytes to the canonical payload projection,
   and recomputes `canonical_bytes_sha256`.  `canonical_bytes_mismatch` and
   `canonical_bytes_sha256_mismatch` are explicit negative controls.
2. Candidate/source/owner/edge/parameter/axis/direction are one immutable
   tuple across feedback, deletion, and every history item.  History is
   non-empty, has exact `1..n` sequence and linked version arithmetic, and
   carries base64 state-before/state-after/operation bytes with recomputed
   digests.  A stale or foreign delete has a required fail-atomic receipt:
   state/history bytes and hashes are unchanged and append count is zero.
3. A fresh review-start snapshot is captured before this package is finalized;
   a fresh review-end snapshot is captured afterwards.  The checker requires
   UTC end time later than start and every artifact, unchanged baseline
   `(status,bytes,SHA-256)` records, and no end path outside the baseline or
   this package.  The 17 dependency entries, seven local URNs, 33 failure
   mappings, and review-05 report remain frozen inputs.

The package remains `review_pending`, `not_implemented`, `not_executed`,
`formal_credit=none`, with external authority `typed_absent`; no Julia,
DESC, provider, solver, hardware, network, or source/test execution occurred.
