# UP2-00G-I1B-SOURCE-ENVELOPE independent acceptance R1

Verdict: `changes_requested`; `accepted=false`; `review_pending=true`.

The bounded software scope itself is supported: `acceptance.md` and the
current evidence manifest preserve `accepted_limited` for actual-A
source-envelope software behavior only. Focused R5 records PID `14796`, exit
`0`, and `2653/2653`; independent postrun R5 is `pass_limited`; R9 is recorded
as the semantic test-only repair. The old focused-R4 failure remains present
and is described as `2051/2052`, exit `1`, one line-407 lexical failure; it was
not overwritten.

The four protected inputs are byte/hash consistent with the manifest:

| input | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/GI1BSourceMutationEnvelopeV1.jl` | 43037 | `58e5f3aa24da64e4ca9c843fc35bba79d8089206a6b49fd56966784051a31e12` |
| `test/GenomeV5/UP2/gi1b_source_envelope_tests.jl` | 25685 | `2de750b05cfea77ad7fc2dac0d0c8f8862c60028bba38e95b887e23a4bcc0299` |
| `test/GenomeV5/UP2/gi1b_source_envelope_fixtures.json` | 23906 | `23794ed2e7958ccd21b26418428e06279150d380e4710c77050bf8b4fe3da1c6` |
| `test/GenomeV5/UP2/run_gi1b_source_envelope.jl` | 408 | `54132f1415faba369807857c1175c317757339b1f3451af902a5f525b0f067b5` |

## Blocking evidence correction

The raw focused-R5 stderr is empty. Direct hashing gives the canonical empty
SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.
However, the current focused-R5 output hash, focused-R5 manifest, postrun-R5
report/manifest, owner acceptance, and evidence manifest repeatedly record
`e3b0c44298fc1c149af4c8996fb92427ae41e4649b934ca495991b7852b855`, which is a
different string with `bf` omitted. The byte count `0` is correct, but the
recorded stderr hash is not the hash of the preserved raw file. The focused-R5
stdout hash and bytes are consistent (`2806`,
`22f5b6723c74b3b502100cba753a9b567c09896722f3373ae28d45b579976121`).

Because the requested final acceptance requires accurate raw stdout/stderr
SHA and bytes, the root should not finalize this acceptance record until the
owner repairs the recorded empty-stderr SHA in a new additive correction
record. This review does not modify the old receipts or source files.

## Scope and index audit

`python docs/v4_multitopology_generation/validate_plan.py --delivery-protection`
exited `0` with planning checks pass and relative links checked. JSON parsing
and protected-input/hash/byte checks passed. The implementation index and core
planning README describe GI1B as actual-A source-envelope software behavior,
retain `accepted_limited`, `pass_limited`, `terminal_deferred`, and explicitly
exclude N06 actual authority, UP2 total, formal B00/B04, compiler, provider,
mesh, solver, engineering, physical and R01–R10 credit. No index entry presents
GI1B as a formal task completion. The local fixture remains oracle-only and no
mesh declaration is promoted to mesh execution.

No Julia/DESC command was run for this review. The result is therefore
`changes_requested`, and the root cannot finally accept the GI1B record until
the stderr hash discrepancy is corrected and independently rechecked.
