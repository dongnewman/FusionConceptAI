# UP2-N06-H0A-DIMENSIONED-LAW focused R4 execution receipt

Disposition: `focused_test_failed`; `accepted=false`; `review_pending=true`.
The command was executed exactly once with safe pre-start stdout/stderr
redirection, a task-specific child PID variable, `WaitForExit()`, and exit
capture. No automatic rerun was performed.

Command:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

Execution used PID `13520`, UTC
`2026-09-14T21:16:41.8552609Z` through
`2026-09-14T21:16:46.4933824Z`, and exit code `1`. The raw streams were
captured before the process started and independently hashed. stdout is 2,553
bytes, SHA-256
`aff9a3413dab8137ea8a8df161496809d930f6cea29e551563f032505af201b3`.
stderr is 310 bytes, SHA-256
`a64e6d35d8d86249f2a54bdce3dc19890943cbc320899aa1ce2a73dcb15f1225`.

The first observed test error is a `StackOverflowError` in
`FusionConceptAI.N06H0AUnitEquationV1` at source line 170, repeating through
the keyword constructor at line 177, reached from `_h0a_equation` at test line
43. The first testset summary is `5 passed, 1 errored, 6 total`; the runner
then exits with `Some tests did not pass`. This is a runtime failure receipt,
not a source or test repair.

Preflight and postflight process counts were both zero for Julia/DESC. Dirty
rows were 301 before and 302 after. The one-row delta is an unrelated
concurrent `?? independent_postrun_r5/` workspace addition; the focused-r4
receipt files were created inside an already-counted untracked directory.
The four protected inputs have identical pre/post hashes. No source, test,
fixture, or runner file was modified by this execution.

The task message's runner SHA string had 63 characters. The actual current
runner SHA-256 is the 64-character value recorded below and in
`input_manifest.json`; the file itself was not changed.

No physical, provider, mesh, engineering, B04, or R01-R10 credit is granted.
The failure is preserved for third-party postrun review; no rerun or automatic
fix was attempted.

## Frozen input hashes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/UP2/N06DimensionedLedgerLawV1.jl` | 56221 | `02a53521aaa85f7880448da60c924b0afd548f55d87d0490fcf17bb727f0f18e` |
| `test/GenomeV5/UP2/n06_dimensioned_law_tests.jl` | 37457 | `51d5a34b7da01b5f2e8c757939c1ba391306b08b9aaa1b62eb0fcc4b6dea302a` |
| `test/GenomeV5/UP2/n06_dimensioned_law_fixtures.json` | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| `test/GenomeV5/UP2/run_n06_dimensioned_law.jl` | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |

