# R9 failure receipt

Upstream diagnostic: [repair_r8/diagnostic_julia_r6](../repair_r8/diagnostic_julia_r6/)

- Diagnostic result: `55 passed, 1 failed, 0 errored, 56 total`.
- Failure: the test expected forged `receipt_cache.rule_bytes` to throw, but
  `_ceg_attempt_bytes(artifact, receipt_cache)` completed successfully.
- Correct root cause: `_ceg_rule_set_bytes(s, cache)` re-canonicalizes each
  current artifact rule through `_ceg_rule_bytes(r, cache)` and intentionally
  does not consult the mutable `cache.rule_bytes` hint map.  The forged hint
  is therefore non-authoritative and unused, so no exception is expected.
- Minimal test repair: use the artifact-owned rule object and assert receipt
  bytes equal the clean receipt under the forged unused hint; add an equal but
  non-identical external rule key to make `IdDict` identity isolation explicit.
- Existing direct `_ceg_cached_rule_bytes` forged-entry tests remain throwing
  negatives for the path that does read and validate a hint.
- Product source changes: none.
- Julia/DESC rerun: deferred to parent review.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
