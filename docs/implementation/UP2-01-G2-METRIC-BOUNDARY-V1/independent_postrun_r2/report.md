# UP2-01-G2-METRIC-BOUNDARY-V1 independent postrun R2

Verdict: `changes_requested`; `accepted=false`; `review_pending=true`.
The focused runtime receipt itself is valid and passed, but it needs one
additive evidence clarification before it is safe to use as a postrun record.

The raw files independently hash as follows:

| file | bytes | SHA-256 |
|---|---:|---|
| `focused_r2/stdout.txt` | 980 | `2fe76c7c6a7264f5449b06174f2d3a18e5f123eab581f5784c5d442e7da84a44` |
| `focused_r2/stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

`run.json` matches PID `50816`, exit `0`, and UTC
`2026-09-14T20:53:04.6034925Z` through
`2026-09-14T20:53:12.0300209Z`. It records zero matching Julia/DESC
processes before and after, dirty rows 300 before and after, and the four
input hashes. The input hash file and current target bytes independently match
the recorded source, test, fixture, and static-QA hashes. All five runtime
testsets passed: chart metric/determinant 20/20, candidate mesh/face identity
10/10, source-edit identity 5/5, contradictions/deferred 14/14, and unit
exponent algebra 15/15, totaling 64/64. R4's two explicit `occursin` direction
fixes are therefore exercised by a passing focused run; the source, fixture,
and static-QA hashes remain unchanged.

The narrow evidence problem is the stdout line
`G2_METRIC_BOUNDARY_V1_JULIA_OR_DESC_EXECUTED=false`. It is printed
unconditionally by the Julia test and is also a fixture/static-QA field; it is
a static fixture claim, not a launcher observation. The actual run did execute
Julia, as proven by `run.json` PID/UTC/exit and the five test summaries. The
current receipt reports the line but does not label its scope, so a reader
could incorrectly treat it as proof that this run did not execute Julia.

The narrow correction is additive and requires no rerun: append an erratum to
the focused receipt stating that the line means
`fixture_static_julia_or_desc_executed=false`, while launcher execution is
`julia_executed=true` from `run.json`; future tests should rename the line to a
fixture/static marker or emit a separate launcher-owned execution field. Do
not weaken or remove the negative controls, and do not edit the old receipt in
this independent review.

The work order remains proposal-level with `accepted=false`. This receipt
grants software-test evidence only and no compiler, provider, mesh execution,
solver, physical, engineering, current-A, B00, B04, or R credit.

## Frozen evidence

- HEAD/branch: `4b69f55f7f80240147a65a22809dc1207824dde2` / `main`.
- Independent review dirty snapshot: 3,796 entries; UTF-8/LF status SHA-256
  `0760c775ebc84e46d7f0a809fe70d75895178026a4e759a2807192d42c4f77b7`.
- No matching Julia/DESC process was present during this review.

