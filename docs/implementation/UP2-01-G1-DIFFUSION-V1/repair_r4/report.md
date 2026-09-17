# UP2-01-G1-DIFFUSION-V1 repair R4

Status: `changes_ready_for_independent_r4_review`; `review_pending=true`; `accepted=false`.
Runtime status: `not_run`; Julia and DESC were intentionally not invoked.

This repair addresses the two findings in the independent R3 static review.

The declaration admission catch path is now exercised through the internal
controlled seam `_g1d_admit_v1_fault_probe`. The seam calls the same internal
admission implementation used by the public entry point and deliberately
raises an internal fault; the catch path returns a typed result with
`status=:program_exception`, `error_code=:unexpected_exception`,
`declaration=nothing`, and a non-null exception type. The public
`g1_diffusion_admit_v1` signature remains fixed to the production
`g1_diffusion_validate` function and exposes no checker injection parameter.
No result is directly constructed by the test.

Malformed user `probe_point` input is now classified as the expected typed
contradiction `:fail_closed` with `error_code=:K_probe_point_malformed` and
path `/K/probe_point`; it is no longer misclassified as a program exception.
The source/hash admission path catches only failures from the internal
canonical hash operation and maps those to the separate program-exception
branch. No exception-message substring is inspected anywhere.

The R3 archive was left unchanged as historical evidence. Its
`review_pending=false` state was an archive error before independent review;
this R4 report is the additive erratum with the corrected current state
`review_pending=true`, `accepted=false`.

## Hash ledger

R3 after hashes are the R4 before hashes for the four versioned files:

| file | R3 before SHA-256 | R4 after SHA-256 |
|---|---|---|
| `src/GenomeV5/G1/DiffusionDeclarationV1.jl` | `2d668cdc5ad40b55ca628af766273b4824e973ca5f77bb2172e7bc52fa5dd9a9` | `14d26ee556029bd1fcf2477f3dbe9599622d37a3f5704d1c0bb1dd9ea31dbf1a` |
| `test/GenomeV5/G1/diffusion_v1_contract_tests.jl` | `29bd3225a9a0fe6498fe5cdcc01ed44ef405bc2b11835f2d457e9982e590a48c` | `34bfaf76f30d5fe2684035d810b36a5c3bc045a0d8d278e3f0af5dc5b888c4a6` |
| `test/GenomeV5/G1/diffusion_v1_fixture.json` | `1dba965964c8d9b4792ebb8f5dae68bb6fdb85b6f8d315d83a73a2bc5ae9a152` | `7b580bf9ad875ed70ffc3aa0ee2e27cbe124c413ec7dad0a8fcd3410c6864641` |
| `test/GenomeV5/G1/static_qa_diffusion_v1.py` | `eb9f9587bfa745bbf31d9b135881cd9fbd4fef0efb442dd8ef3b8d5164002d33` | `87f511f5402224df06928a9e78c0d3213d2330da5b91021b628acd51d7536066` |

The historical R3 state files remain untouched:

| archive | SHA-256 |
|---|---|
| `repair_r3/report.md` | `0956b606e576ad8979fec115fd679f0f6465659f5be51f84e9c07786fbc9d44c` |
| `repair_r3/evidence_manifest.json` | `0faed4835e7b52a9de28a5964bc30e695fdb99d642fc3710972d56d149ec44c2` |

## Static QA

Command:

```text
D:\Users\Newman\anaconda3\python.exe test/GenomeV5/G1/static_qa_diffusion_v1.py
```

Exit: `0`; output included `static_qa=pass` and
`julia_or_desc_executed=false`. JSON parsing and Python AST parsing also
passed. The interpreter was
`D:\Users\Newman\anaconda3\python.exe`. No Julia/DESC command was run.

The static checks cover local typed-field ordering, the fixed production
validator binding, no exception-text classification, malformed K probe
fail-closed semantics, and the program-exception test seam. No compiler,
provider, mesh, solver, physical, current-A, B00, B04, or R01-R10 credit is
claimed.

## Independent review entry

An independent Luna R4 static review should begin with the four R4 hashes and
this erratum, confirm that R3 archives are unchanged, inspect the internal
fault seam versus the fixed public validator, and rerun only the Python static
QA. The single serial focused Julia lane remains outside this repair.
