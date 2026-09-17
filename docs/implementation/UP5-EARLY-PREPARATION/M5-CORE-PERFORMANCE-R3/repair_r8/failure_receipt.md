# R8 failure receipt

Upstream diagnostic: [repair_r7/diagnostic_julia_r5](../repair_r7/diagnostic_julia_r5/)

- Diagnostic result: `50 passed, 0 failed, 1 errored, 51 total`.
- Failure: `invoke: argument type error` in
  `_ceg_query_result_top_bytes` at
  `src/Canonical/ConditionalEGraphCanonical.jl:223`.
- Root cause: the final `_ceg_wrap` invocation supplied the body as the first
  argument and omitted the required domain/kind tag.
- Minimal repair: pass
  `"conditional_equality_query_result"` before the body.
- Focused test additions: JSON3 structural `kind`/`domain` validation,
  repeat-call byte determinism, and existing query hash relation.
- Static scan: zero remaining matching malformed wrap call shapes under
  `src/Canonical`.
- Julia/DESC rerun: deferred to parent review.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
