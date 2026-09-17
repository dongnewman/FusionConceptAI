# H0-A focused test helper repair R9

Status: `review_pending` / `accepted=false`.

The independent postrun R2 review identified a test-only construction error:
`_h0a_digest(ch) = G.Digest256(repeat(ch, 64))` rejects non-hex labels such as
`z`, `foreign-schema`, `stale`, and `stale-g3`. The repair changes only that
helper to `G.digest256_text(String(ch))`, which produces deterministic valid
SHA-256 digests while preserving the production `Digest256` validation.

No source, fixture, runner, core document, old evidence, or G1 file was
modified. The focused Julia/DESC lane was not rerun by this repair worker;
the next action is a different Luna static review followed by the single
serial focused R3 run.

## Frozen pre-repair evidence

- HEAD: `4b69f55f7f80240147a65a22809dc1207824dde2`
- focused R2 exit: `1`
- R2 stdout SHA-256: `d5a7aa93f0dc73a3374cdd7f86e0eda6568d6fe4c06cfae3d9744a1028a01748`
- R2 stderr SHA-256: `a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`
- R2 first error: invalid lowercase hexadecimal `Digest256` literal in the
  test helper at line 9.

## Before/after hashes

| path | before SHA-256 | after SHA-256 | ownership check |
|---|---|---|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | `03aa28636626efa4a5fdcb2f806e23bfc3e166f0d6fcabe72ebb0e7c6001e8dc` | same | unchanged |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | `70662390ac46a781ebf0c2e01e910ed640943b3e98c08c5d224a3e12705672dc` | `1c2066a0fad0a324db263619d822e0e2d0422f73b23f6b702d74686a46383fdb` | authorized helper-only edit |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` | same | unchanged |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` | same | unchanged |

## Static QA

Interpreter: `D:\Users\Newman\anaconda3\python.exe`, Python `3.13.5`.

Command:

```text
python docs/implementation/UP2-N06-H0A-DIMENSIONED-LAW/repair_r9/static_qa_repair_r9.py
```

Expected/observed disposition: `static_qa=pass`, exit `0`,
`julia_or_desc_executed=false`.
Static QA artifact SHA-256: `96f8c89deabe8b9de5aa1b014f4b33e717ed658e8b13ceb97c6157a3fa114414`.

The static scan confirms all non-hex labels route through the canonical text
digest helper, no raw `Digest256(...)` or repeated literal construction
remains in the test, and the protected H0-A source and fixture exist.

Claim boundary: no H0-A acceptance, B00/B04, provider, mesh, engineering,
physical, or R01–R10 credit. Independent review remains pending.
