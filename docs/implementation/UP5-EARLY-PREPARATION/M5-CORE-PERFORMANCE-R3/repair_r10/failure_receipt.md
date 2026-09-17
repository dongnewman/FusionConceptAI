# R10 failure receipt

Upstream diagnostic: [repair_r9/diagnostic_julia_r7](../repair_r9/diagnostic_julia_r7/)

- Diagnostic result: `58 passed, 1 failed, 0 errored, 59 total`.
- Failure: the test required an equal-field external immutable rule to satisfy
  `!== artifact_rule`; Julia treated the values as identical.
- Corrective action: remove that invalid equal/non-identical identity test and
  its forced construction.
- Retained coverage: artifact-owned forged rule hint leaves authoritative
  receipt bytes equal to the clean receipt; a foreign rule-ref forged hint is
  likewise ignored by the rule-set writer; direct `_ceg_cached_rule_bytes`
  forged-read negatives continue to throw.
- Product source changes: none.
- Julia/DESC rerun: deferred to parent review.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
