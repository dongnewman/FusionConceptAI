# Task-owned failure history

This append-only sidecar records failed task-local attempts before the final
receipt was frozen. The failures were not treated as passes and did not alter
the six product scope.

1. Python static QA was first run directly and passed. The first Julia command
   exited nonzero because the test referenced `G3SourceFeedbackLawV1.jl` from
   the test directory instead of the source directory (`SystemError`, missing
   file). The test path was repaired.
2. The next focused Julia run reached the test body and exposed two test-local
   issues: an invalid expectation that the state hash equals the full semantic
   view including its own hash, and use of `state.key` although the state owns
   the key through `source_payload.key`. Both were repaired.
3. The following focused Julia run exposed a pairing fail-closed path that
   called `first` after recording a missing upstream layer. The missing-layer
   branch was repaired to return the deterministic error instead of raising.

The final direct Python and Julia receipt is `archive/r1/receipt.json`; its raw
stdout/stderr files are retained beside it. No failure was classified as
physical, engineering, provider, mesh, T0/T1/T2, B00/B04, or R01-R10 evidence.
