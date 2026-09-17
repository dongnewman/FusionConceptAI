# H0-A dimensioned law independent postrun R4

Verdict: `changes_requested`; `accepted=false`; `review_pending=true`.

The focused-R4 failure is reproduced by the preserved receipt and is a
production constructor dispatch defect, not a test-only expectation issue.
The raw stdout is 2,553 bytes with SHA-256
`aff9a3413dab8137ea8a8df161496809d930f6cea29e551563f032505af201b3`;
stderr is 310 bytes with SHA-256
`a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`.
`run.json` records PID `13520`, exit `1`, UTC
`2026-09-14T21:16:41.8552609Z` through `2026-09-14T21:16:46.4933824Z`,
dirty rows `301 -> 302`, and Julia/DESC processes `0 -> 0`.

The first testset reached 5 passes, 1 error, 6 total. The stack repeats
`N06H0AUnitEquationV1` at source lines 170 and 177 37,280 times and ends in
`StackOverflowError`. Static reading explains the recursion: the public outer
keyword constructor at lines 170-187 and the inner constructor at lines
145-167 share the same twelve positional arguments. The outer body calls
`N06H0AUnitEquationV1(..., owner_account_ids)` at line 177, and dispatch selects
the outer method again instead of entering the inner `new(...)` body. The
inner constructor is therefore never reached. Its line-166 `new(...)` is not
the observed failure site.

The outer line-183 call also attempts a 21-field positional reconstruction
without a named full-state construction seam. After the twelve-argument
recursion is bypassed, this path must be made explicit as part of the same
repair; a custom inner constructor does not safely provide an assumed default
full-field constructor. The narrow implementation repair is to introduce
private, unambiguous base/full construction paths, for example marker-tagged
inner constructors `Val(:base)` and `Val(:full)`: the public keyword method
calls the base marker after validation, then calls the full marker to attach
provenance/payload/role fields. Keep the public keyword API, typed fields,
validation and hashes unchanged. A private builder with the same two explicit
construction stages is equivalent. Do not solve this by weakening tests or by
removing typed validation.

The regression gate must run the same runner once after repair and exit `0`:
the first six-case schema set must be `6/6` with no error or
`StackOverflowError`; all later H0-A testsets must be reached and pass; no
line-170/177 recursion may remain; and pre/post protected hashes must be
freshly recorded. Actual-A remains deferred and no physical, provider, mesh,
engineering, B00/B04, or parent-goal credit is available.

The focused-R3 failure receipt remains untouched. Its original stdout/stderr
hashes are preserved, and R4 did not overwrite it. The scheduling message that
preceded R4 contained a 63-character runner SHA typo. The actual frozen runner
hash in R4's input manifest and on disk is the complete 64-character
`da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc`.
This is a dispatch-instruction defect, not an input-identity defect; add a
task-record erratum if desired, but do not treat the truncated string as valid
preflight evidence and do not rerun R4 for it.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Independent review dirty snapshot: 3,871 entries; UTF-8/LF status SHA-256
  `1d04cab381fa8d556215f79e4f01b04c311c1c9453176b17252ca9cb877843d8`.
- No matching Julia/DESC process was present during this review.

