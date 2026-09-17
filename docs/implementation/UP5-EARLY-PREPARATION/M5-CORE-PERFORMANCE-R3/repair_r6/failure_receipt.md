# R6 failure receipt

Upstream diagnostic: [repair_r5/diagnostic_julia_r3](../repair_r5/diagnostic_julia_r3/)

- Diagnostic result: `18 passed, 0 failed, 1 errored, 19 total`.
- Failure: `ArgumentError: invalid conditional proposal cache entry` at
  `src/IR/ConditionalEGraphSaturation.jl:246`, reached from focused test line
  93.
- Cause: `mutated_proposal.proposal_keys[forward]` was intentionally replaced
  with a forged key, then the same corrupted cache was reused to initialize
  the sort-key negative.
- Minimal repair: use `mutated_proposal_identity` for the identity mutation and
  a fresh `mutated_proposal_sort` for sort-key setup/mutation.
- Product source changes: none.
- Test intent: unchanged; each independent cache corruption must throw.
- Julia rerun: deferred to parent review.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
