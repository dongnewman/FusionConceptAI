# G-I1B source envelope independent acceptance R3

Verdict: `pass_limited`; `accepted=false`; `review_pending=true`.

This is an independent evidence review of the additive R7 erratum. It does not
modify the G-I1B source, tests, fixture, runner, focused receipts, previous
reviews, or core planning files, and it does not run Julia, DESC, a provider,
mesh, solver, or any heavy computation.

## Recomputed focused-R5 evidence

The preserved raw bytes were read directly from
`focused_r5/stdout.txt` and `focused_r5/stderr.txt`:

| file | bytes | independently recomputed SHA-256 |
|---|---:|---|
| `stdout.txt` | 2806 | `22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121` |
| `stderr.txt` | 0 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |

Both values match `focused_r5/output_hashes.json`,
`focused_r5/command_receipts.json`, `focused_r5/report.json`, the owner
manifest, and R7's direct-raw section. All three focused structured receipts
contain a 64-character stderr SHA. The command receipt independently records
PID `14796`, exit `0`, and the report records `2653/2653`; the raw stdout
contains two repeated UP1 groups (`299/299` each), then
`2024/2024 + 8/8 + 14/14 + 6/6 + 3/3`, which sums to
`2*299 + 2024 + 8 + 14 + 6 + 3 = 2653`.

The four current protected files were independently hashed and match R7's
manifest:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl` | 43037 | `58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12` |
| `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl` | 25685 | `2de750b05cfea77ad7fc2dac0d0c8f8862c60028bba38e95b887e23a4bcc0299` |
| `test/GenomeV5/UP2/gi1b_source_envelope_fixtures.json` | 23906 | `23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6` |
| `test/GenomeV5/UP2/run_gi1b_source_envelope.jl` | 408 | `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5` |

## R7 and historical evidence integrity

R7 `report.md`, `command_receipts.json`, `evidence_manifest.json`, and its
generator are valid UTF-8 byte files with no control bytes. The human-readable
report contains no `$stdoutHash`, `$stderrHash`, `$(`, `<actual>`, `<pending>`,
or `${...}` placeholder. R7 is a clean additive record and explicitly states
that no Julia/DESC command was run.

R7 correctly preserves the earlier error rather than replacing it: R6's
historical fields retain the 62-character empty-stderr value, while R6's
structured replacement carries the independently computed 64-character
value. The focused-R4 raw output, stderr, QA, and receipt hashes independently
match their preserved receipt; R4 remains exit `1`, `2051/2052`, with one
line-407 lexical production-boundary failure. The focused-R5 rerun and R9
test-only repair are therefore traceable, not silently rewritten.

## Acceptance decision and ceiling

I find sufficient independent evidence for a bounded software-only
`actual-A source-envelope` slice: the actual-A factory paths, typed source
access, mutation-row schema, taxonomy, frozen matrix, production boundary,
typed N06 authority-gap handling, and oracle-only fixture boundary represented
by the focused R5 run. The correct owner state remains `accepted=false` until
the architect records the decision; this review is `pass_limited`, not an
acceptance mutation.

The claim ceiling is strictly:

- actual-A source-envelope software behavior only;
- N06 actual dimensioned source authority remains `terminal_deferred`, with
  typed `authority_gap` / `typed_absent` handling;
- no UP2-total, compiler, provider, mesh, solver, engineering, physical,
  current-A, formal B00, formal B04, or R01-R10 credit;
- the fixture remains oracle-only and the old focused-R4 failure remains part
  of the evidence history.

The remaining gaps are material: fresh candidate-bound three-layer identity
rebuild, authoritative N06 cross-layer law, formal B00/B04 receipts/checker
and two-process replay, provider/mesh/physical execution, and the unchanged
parent R01-R10 goal. None is closed by this review.
