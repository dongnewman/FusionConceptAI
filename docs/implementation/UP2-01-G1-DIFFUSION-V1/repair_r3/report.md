# UP2-01-G1-DIFFUSION-V1 repair R3

Status: `changes_ready_for_independent_r3_review`; `review_pending=false`; `accepted=false`.
Runtime status: `not_run`; Julia and DESC were intentionally not invoked.

This repair addresses both blockers recorded by the R2 independent static
precheck. The source-payload struct and its semantic/hash methods now occur
before every local typed field that names it, including
`G1DiffusionDeclarationV1`. The static QA also scans local struct fields for
forward references and checks that the source-payload definition occurs once.

The public preparation adapters now return `G1DiffusionAdmissionResultV1`.
They expose `status`, `error_code`, `error_path`, `declaration`, and
`exception_type`. Forged source hashes, K-bound mismatches, out-of-domain K
probes, positive residual-sign expectations, and unit conflicts return
`status=:fail_closed` with no declaration and a field-specific path. A valid
candidate declaration and a source payload with a matching content hash return
`status=:terminal_deferred` because no external authoritative source is
available. Unexpected caught exceptions use the separate
`status=:program_exception` / `error_code=:unexpected_exception` branch; no
exception-message substring is used for classification. Constructors remain
strict and continue to throw on malformed inputs.

The typed residual remains the candidate-owned chain
`-DIV(K(x)*GRAD(u(x)))=f(x)` with `residual_sign=-1`. The tests cover the
typed admission outcomes, identity edits, K bounds/domain, sign and units,
and missing authority. The fixture records the new negative-control names.
These are schema and contract declarations only: they do not establish a
physical solution, provider execution, mesh, compiler result, or current-A
authority.

## Hash ledger

The R2 precheck supplied the following before hashes for the four versioned
working files. The R3 after hashes are from the current worktree:

| file | R2 before SHA-256 | R3 after SHA-256 |
|---|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `a37ff22489086aa55ad2fe7d75f8b5c2e6eb5a633bd60eed8c4947d230e45b1a` | `2d668cdc5ad40b55ca628af766273b4824e973ca5f77bb2172e7bc52fa5dd9a9` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | `719c238f0af997ab0cec954f0c05c06e3b27d3b5d43cb95fb6da108f696e2f80` | `29bd3225a9a0fe6498fe5cdcc01ed44ef405bc2b11835f2d457e9982e590a48c` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | `debfe9ffb3cc1b85fe084369f5dda554d9e64397799755930ff38b16b6dedfed` | `1dba965964c8d9b4792ebb8f5dae68bb6fdb85b6f8d315d83a73a2bc5ae9a152` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | `fcb948cc86249962b12952bc9765b6f6bba1e621023305a2dabfcaf8bdfa06a8` | `eb9f9587bfa745bbf31d9b135881cd9fbd4fef0efb442dd8ef3b8d5164002d33` |

## Static QA

Command:

```text
D:\Users\Newman\anaconda3\python.exe test/GenomeV5/G1/static_qa_diffusion_v1.py
```

Exit: `0`.

Observed output included `static_qa=pass` and
`julia_or_desc_executed=false`. The interpreter path was
`D:\Users\Newman\anaconda3\python.exe`; no Julia/DESC command was run.
JSON parsing and Python AST parsing were also completed without executing the
Julia test file. No compiler/provider/mesh/physical or R01-R10 credit is
claimed.

## Independent review entry

An independent Luna R3 static review should start from the current four file
hashes above, inspect `repair_r3/evidence_manifest.json`, rerun only the
Python static QA, and verify the admission result fields and local typed-field
ordering. The single serial focused Julia lane remains outside this repair.
