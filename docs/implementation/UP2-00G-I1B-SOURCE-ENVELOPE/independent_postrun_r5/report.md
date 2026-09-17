# G-I1B source envelope independent postrun R5

Verdict: `pass_limited`; `accepted=false`; `review_pending=true`.

The focused-R5 receipt is internally consistent. The raw stdout is 2,806
bytes with SHA-256
`22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121`; raw
stderr is empty with SHA-256
`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. The
launcher metadata reports PID `14796`, exit `0`, and UTC
`2026-09-14T21:10:05.4292512Z` through `2026-09-14T21:12:22.1171014Z`.
Dirty rows stayed `301 -> 301`, matching Julia/DESC process counts stayed
`0 -> 0`, and the four input hashes match the current protected bytes.

All reported focused assertions passed: repeated UP1 groups `299/299`, the
actual-A E1-present and both-absent factory `2024/2024`, aggregate taxonomy
`8/8`, schema/frozen matrix `14/14`, production boundary `6/6`, and fixture
oracle-only `3/3`, totaling `2653/2653`.

R9 is a test-only repair. The source remains unchanged, and the sole test
change replaces an undeclared free-text requirement that
`authority_gap` contain the literal substring `authority` with a non-empty
semantic check. This did not weaken the typed authority-gap contract: the
test still requires every N06 runtime row to be `:terminal_deferred` with
`:authority_gap`, `binding.authority == :typed_absent`, and an `N06` runtime
gap. The source profile continues to declare missing authority as
`terminal_deferred`, and the focused production boundary now passes `6/6`.
R9 static QA also records those typed N06 assertions as retained.

Focused-R4's exit-1 evidence remains preserved and matches R9's recorded
hashes: it had `2051/2052` GI1B assertions, one line-407 lexical failure,
`2024/2024` actual-A factories, `8/8` taxonomy, `14/14` schema, and `5/6`
production boundary. R5 therefore demonstrates the narrow test repair's
software effect without overwriting the failure history.

The G-I1B work remains contract/software evidence only. `accepted=false` and
`review_pending=true`; no compiler, provider, mesh, solver, engineering,
physical, current-A, formal B00/B04, or parent-goal credit is granted.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Independent review dirty snapshot: 3,855 entries; UTF-8/LF status SHA-256
  `358bd1a0031b1011857333a7e0d82130aba4443593f98635e2c2318c6f056272`.
- No matching Julia/DESC process was present during this review.

