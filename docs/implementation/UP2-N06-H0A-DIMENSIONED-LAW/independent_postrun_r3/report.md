# H0-A independent postrun review R3

Verdict: `changes_requested`.

This is a read-only third-party review of the preserved `focused_r3` serial
run. The run exited `1` at `2026-09-14T19:44:44.4838455Z` after starting at
`2026-09-14T19:44:41.1206494Z`, with root PID `8900`. The first testset
reported five passes, one error, and six total cases; no later testset was
reached. The captured first error is the test helper `_h0a_equation` using
`NamedTuple{(),Tuple{}}()` as a zero-argument constructor (the two defaults at
`n06_dimensioned_law_tests.jl:40-41`; the stack reports the helper at line 34).
`NamedTuple{(),Tuple{}}()` has no callable empty constructor in the observed
Julia runtime.

The same latent expression is present twice in the production H0-A source:
`N06DimensionedLedgerLawV1.jl:166` uses it for the two stored role maps, and
`:175` uses it for the two keyword defaults. The test has the corresponding
two defaults at `n06_dimensioned_law_tests.jl:40-41`. This is therefore a
four-occurrence blocker, not a single first-testset typo. The narrow repair is
to replace all four zero-argument forms with `NamedTuple()` (or the explicit
empty tuple argument form `NamedTuple{(),Tuple{}}(())`) while preserving the
declared `NamedTuple` field types. No source or test file was changed by this
review.

The broader static scan found no reserved-key assignment form. The role key
`:return` occurs only as a quoted `Symbol` in `NamedTuple` type parameters and
role tuples, which is valid Julia syntax; there is no `return=...`, `end=...`,
or analogous keyword assignment. The test digest helper is already
`G.digest256_text(String(ch))`, and the source uses `digest256_text` or
`canonical_hash`; no raw fixed-character `Digest256(...)` construction or
invalid fixed hex literal remains in these H0-A files. The typed defaults
`nothing` are routed to `Any`/union fields or checked before reconstruction;
the only default-type failure found is the empty `NamedTuple` constructor.

The focused_r3 stdout/stderr, command, PID/UTC, input manifest, postflight
process result, and protected before/after hashes remain unchanged. Julia and
DESC were not run during this review. The run's partial five passes are not a
suite pass, and no H0-A dimensioned-law, B00, B04, provider, mesh,
engineering, physical, or R01-R10 credit is available.
