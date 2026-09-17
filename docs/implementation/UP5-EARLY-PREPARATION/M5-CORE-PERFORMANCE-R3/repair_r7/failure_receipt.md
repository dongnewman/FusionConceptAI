# R7 failure receipt

Upstream diagnostic: [repair_r6/diagnostic_julia_r4](../repair_r6/diagnostic_julia_r4/)

- Diagnostic result: `40 passed, 1 failed, 0 errored, 41 total`.
- Failure: `artifact !== nothing` evaluated as `nothing !== nothing` at
  focused test line 209.
- Root causes repaired: cache-aware receipt writers omitted the
  `conditional_equivalence` / `conditional_saturation_attempt` domain tags;
  provenance validation incorrectly compared artifact trace owners with the
  unrelated fresh receipt cache owner.
- Minimal repair: preserve owner consistency within the trace itself
  (legacy all-`nothing` or sealed all-same owner; mixed/different rejected)
  and restore both domain tags.
- Focused tests: legacy provenance acceptance, mixed-owner rejection,
  cross-owner rejection, cache/legacy equivalence and attempt byte identity,
  derived artifact non-`nothing`, query, and replay path.
- Product semantics: unchanged outside the required receipt validation.
- Julia/DESC rerun: deferred to parent review.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
