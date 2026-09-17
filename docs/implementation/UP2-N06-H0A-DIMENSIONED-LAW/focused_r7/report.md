# H0-A focused R7 execution receipt

Status: `executed_exit_nonzero`; `exit_code=1`; `accepted=false`; `review_pending=true`.

The single serialized command was executed once after the R19b `pass_limited`
precheck and T0 completion:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n06_dimensioned_law.jl
```

The launcher used `System.Diagnostics.Process`, redirected both streams before
start, waited for process exit, and hashed the completed raw byte files. PID was
`41736`; UTC interval was `2026-09-14T23:43:38.2366289Z` to
`2026-09-14T23:48:36.0156943Z`. No Julia or DESC process remained afterward. The prior
R6 exit-1 evidence is retained and was not overwritten.

## First real failure

The first failing assertion is in `H0-A trusted semantic and G2 provenance
controls`, at
`test/GenomeV5/UP2/n06_dimensioned_law_tests.jl:551`:

```text
Expression: isempty((G._n06_h0a_validate_law(good, endpoints; law_id = law_id)).errors)
Evaluated: isempty(("role_sign_mismatch:source", "role_sign_mismatch:load", "role_sign_mismatch:return"))
Summary: 38 passed, 1 failed, 39 total
```

The runner then stopped with stderr reporting `38 passed, 1 failed, 0 errored,
0 broken`. This is preserved verbatim in `stdout.raw` and `stderr.raw`. No code
was changed and no rerun or repair was attempted in this task.

The actual-A group itself printed `7 passed, 7 total` for
`H0-A actual-A source binding remains deferred`. The runner does not print a
structured actual-A result status, declaration type, or compile/provider/solver
counter fields; those receipt fields are explicitly `not_printed_by_runner`.
It is therefore not valid to infer them from the passing group summary.
The raw runner output contains 65 `Test Summary` blocks, preserved in
`group_summaries.txt`; no expected group count was substituted for the observed
output.

## Input and output hashes

| artifact | bytes | SHA-256 |
|---|---:|---|
| source | 59570 | `9bdf3919666611f7bf7c679ed2fb6d2630d692ccca46de183dccbb5bef98ee4c` |
| test | 48902 | `58e1293fe7f7504cbb1f63a5fa9cd11734704e5ad742ce30607a00825d6b15f8` |
| fixture | 1451 | `779e29bac0a71c5072896301e24e74c9686c293609b89e250d0b0aff5bf0cc99` |
| runner | 299 | `da4c41517badd8c99f5f10e55c9219e2450afb223798eb7f7b4db2048ce293dc` |
| stdout.raw | 9857 | `c114cc2c4fced2acadbb5c822227daf1fff954e4e784150e0c213dafec5320bc` |
| stderr.raw | 311 | `73824bf33e176701c1e568a6af07c77665bad3bc89f6d60125ffc493efa8de45` |

The four input hashes were identical before and after execution. Pre/post dirty
snapshots are retained in `pre_dirty.txt` and `post_dirty.txt`; pre/post Julia
and DESC snapshots are explicit empty arrays. The run remains software-contract
evidence only. H0-A remains `accepted=false`; no external-authority, UP2-total,
B00, B04, provider, mesh, physical, engineering, or R credit is claimed.
