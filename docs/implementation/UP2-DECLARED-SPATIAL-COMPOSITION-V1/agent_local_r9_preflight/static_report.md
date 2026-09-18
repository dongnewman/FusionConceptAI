# UP2-DECLARED-SPATIAL-COMPOSITION-V1 — R9 preflight wrapper

## Scope and boundary

This is a read-only AST/static preflight package. `runner.ps1` was not invoked
while preparing or checking this package; Julia and DESC were not started. The
required runtime command is the declared spatial composition focused test, but
this receipt does not claim its execution or a Julia result.

The wrapper is one-shot: it acquires an atomic durable lock, refuses any
pre-existing receipt directory, starts at most one Julia process, uses
`JULIA_NUM_THREADS=1`, waits at most 300 seconds by default, and on timeout
kills only that process and descendants discovered from parent IDs. Redirected
streams are drained after timeout and no retry path exists.

## Frozen six-file set

| File | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredSpatialCompositionExecutionV1.jl` | `819500922d52408d4a16f75a441b157d6ac953a19510fc6648b3594bd9312216` |
| `test/RuntimeV4/DeclaredSpatialComposition/declared_spatial_composition_execution_v1_tests.jl` | `44ed2fcb4b11e9a742a0acbf5c51495957c320736d1e3fdf0152237ebc22d547` |
| `test/RuntimeV4/DeclaredSpatialComposition/fixture.json` | `ba506e35d0058d5c469dbf494c5ab1a00240206bf5e6826b86590b6dea064a0a` |
| `test/RuntimeV4/DeclaredSpatialComposition/independent_oracle.py` | `946cf37ac8692c276ac9bb2ee32b32f1059fd7ce99ca5a0d9bc6bc4a3cb1c232` |
| `test/RuntimeV4/DeclaredSpatialComposition/static_qa.py` | `9120b20e2384f57af5697befc430bb9fa0ffcaf86d4279aeda5071fef67ca389` |
| `docs/implementation/UP2-DECLARED-SPATIAL-COMPOSITION-V1/report.md` | `8b7b85bdc5d6a94212e641ae0c0fa12b69d1ad19fd7b04a42500557145cbc572` |

Any missing file, changed hash, non-six hash map, or non-six protected-file set
fails the receipt. Postflight requires two consecutive zero Julia/DESC process
observations separated by 250 ms.

## Static checks performed

| Check | Result |
|---|---|
| PowerShell parser AST for `runner.ps1` | PASS; 0 parser errors |
| six manifest hashes match current files | PASS; 0 mismatches |
| default timeout 300 seconds and `WaitForExit($timeoutMs)` | PASS |
| atomic CreateNew lock, new run directory, refusal/no overwrite | PASS |
| own-tree kill, strict hashes, double-zero postflight | PASS |
| one process `Start()` site and no retry | PASS; 1 `Start()` site |
| repository `static_qa.py` / independent oracle | PASS; 8 negative vectors, MMS order 2.0020872428184697 |
| Julia/DESC execution during this static pass | NOT PERFORMED |

Claim ceiling remains `screen_only`; no UP/R/L4 credit, provider receipt,
physical validation, engineering qualification, candidate authority, or whole-
device closure is implied.
