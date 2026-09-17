# R5 failure receipt

Upstream diagnostic: [repair_r4/diagnostic_julia_r2](../repair_r4/diagnostic_julia_r2/)

- Diagnostic status: parse failure before the Test summary.
- Reported error: `":owner_token" is not a valid function argument name`.
- Location: `test/RuntimeV4/M4Isolated/m5_core_perf_r3_tests.jl:137`.
- Minimal repair: replace `(getfield(cached_trace, :owner_token) = Ref{Nothing}())`
  with `setfield!(cached_trace, :owner_token, Ref{Nothing}())` inside the same
  `@test_throws Exception` assertion.
- Product source changes: none.
- Test intent: unchanged; the immutable trace-owner mutation must still throw.
- Julia rerun: deferred to the parent review lane.
- Claim ceiling: `screen_only`; no performance, formal credit, or factorial
  closure claim.
