# UP2/UP3 declared spatial composition V1 — R9 runtime acceptance

## Result

The R9 runtime receipt is complete and passes the serialized focused Julia
lane: **54/54**, exit code `0`, one Julia start, `JULIA_NUM_THREADS=1`, and no
DESC process.  This is a local software/numerical runtime receipt only.  The
claim ceiling remains `screen_only`; `accepted=false`, with no UP, R, or L4
credit and no provider, physical, engineering, candidate, or whole-device
authority.

The complete receipt is the run directory
`docs/implementation/UP2-DECLARED-SPATIAL-COMPOSITION-V1/agent_local_r9_preflight/run_20260918_120936_343_8ad76d38f9294970aa4776cfc0dbf22d/`.
Its `run_metadata.json` has `status=runtime_complete`, `startedOnce=true`,
`startCount=1`, `exitCode=0`, `timeoutClassified=false`,
`postflightZeroJuliaDesc=true`, `streamsCaptured=true`, and
`ownedFilesUnchanged=true`.  The captured stdout is the 54/54 test summary;
stderr is empty.

## Numerical and negative coverage

The frozen focused test and its independent static/oracle evidence cover the
following numerical results:

- conservation residual: `0`
- interface-flux residual: `0`
- ledger residual: `0`
- MMS refinement order: `2.0020872428184697` (acceptance threshold `>=1.8`)
- one joint solver invocation with residual bound `1e-12`
- holdout solution: `(0.15601849765681325, 0.01194048906512854,
  -0.21296590148316002, -0.3486531796880121)`

All eight negative vectors are represented: `duplicate_producer`,
`unit_mismatch`, `missing_boundary`, `nonoverlap`, `nonfinite_K`,
`pure_neumann_singular`, `missing_return`, and `geometry_hash_change`.

## Frozen six-file integrity

The R9 receipt captured all six protected files before and after execution;
`owned_hash_changes.json` is `{}` and every before/after SHA-256 is identical:

| Protected file | SHA-256 |
|---|---|
| `src/RuntimeV4/DeclaredSpatialCompositionExecutionV1.jl` | `819500922d52408d4a16f75a441b157d6ac953a19510fc6648b3594bd9312216` |
| `test/RuntimeV4/DeclaredSpatialComposition/declared_spatial_composition_execution_v1_tests.jl` | `44ed2fcb4b11e9a742a0acbf5c51495957c320736d1e3fdf0152237ebc22d547` |
| `test/RuntimeV4/DeclaredSpatialComposition/fixture.json` | `ba506e35d0058d5c469dbf494c5ab1a00240206bf5e6826b86590b6dea064a0a` |
| `test/RuntimeV4/DeclaredSpatialComposition/independent_oracle.py` | `946cf37ac8692c276ac9bb2ee32b32f1059fd7ce99ca5a0d9bc6bc4a3cb1c232` |
| `test/RuntimeV4/DeclaredSpatialComposition/static_qa.py` | `9120b20e2384f57af5697befc430bb9fa0ffcaf86d4279aeda5071fef67ca389` |
| `docs/implementation/UP2-DECLARED-SPATIAL-COMPOSITION-V1/report.md` | `8b7b85bdc5d6a94212e641ae0c0fa12b69d1ad19fd7b04a42500557145cbc572` |

## Snapshot boundary

The parent `report.md` and `manifest.json` are two members of the frozen
six-file set and were not edited.  Their `julia_executed=false` and
`focused_julia_test_not_executed` language is the pre-runtime snapshot that
was true when those files were authored.  This additive R9 acceptance record
supersedes neither file and does not rewrite that historical snapshot; the
runtime fact is stated only here and in the new manifest.

No Julia or DESC command was run while creating this acceptance record, and no
commit was created.
