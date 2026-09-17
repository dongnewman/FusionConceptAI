# Independent review r2: UP2-00C N09

Verdict: `pass_limited` for the actual-A, contract-only provider-gap projection slice. The author archive remains `review_pending` / `accepted=false`; this review grants no provider resolution, B04, mesh, engineering, physical, or R01-R10 credit.

## Runtime evidence

Before execution, the independent snapshot recorded no `julia.exe` or `desc.exe` process. Exactly one focused command was then run serially:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_n09_provider_gap.jl
```

The process record is `focused_test.process.json`: PID `63304`, start `2026-09-14T08:39:40.6487305+08:00`, end `2026-09-14T08:41:40.6732149+08:00`, Julia `1.10.5`, exit `0`. The independent exit artifact is `focused_test.exit.txt`, value `0`. `focused_test.stdout.log` is 3,850 bytes, SHA-256 `215ade810de1e20918d6283a5938155206a3a485b84e5d85e69e584d81d63d0f`; it reports the three layer setup plus `7/7`, `24/24`, `144/144`, and `2/2` N09 assertions. `focused_test.stderr.log` is zero bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`. Post-run process evidence is `post_processes.json` with an empty list. No Julia/DESC process was left by this run.

The author history remains distinct: r1 is `unknown/program_exception` because asynchronous Start-Process lost its exact exit, with the real baseline mismatch preserved; r2 has process PID `19840`, exact exit `0`, empty stderr, and the recorded 144/144, 24/24, and 2/2 summaries. The author r1/r2 artifacts were rehashed and are listed in `before_hashes.json`.

## Actual-A source and identity checks

`src/GenomeV5/UP2/N09ProviderGapProjectionV1.jl:116-194` consumes a concrete `CandidateStatePackageV5` and projects five declarations from the package's actual components. The source paths and values are:

- `N09-01`: `g1.payload.grammar_profile.operators[0].provider_match`, locator `G1OperatorSpecV2.provider_match::Symbol` (`:129-145`)
- `N09-02`: `g2.grammar_profile.provider_match`, locator `SpatialGrammarProfileV2.provider_match::Symbol` (`:147-157`)
- `N09-03`: `g2.plan.exterior.provider_match`, locator `G2ExteriorPlanV2.provider_match::Symbol` (`:159-169`)
- `N09-04`: `g3.realization.provider_match`, locator `RealizationGenomeV5.provider_match::Symbol` (`:171-180`)
- `N09-05`: `g3.control.provider_match`, locator `ControlGenomeV5.provider_match::Symbol` (`:182-190`)

Each emitted declaration carries the package candidate ref, component public `GenomeContractRef`, and component candidate hash (`:29-60`). The projection constructor enforces candidate-bound declarations and unique layers (`:63-84`). The test independently checks those refs and hashes against the actual package at `test/GenomeV5/UP2/n09_provider_gap_tests.jl:86-112`.

The actual package builder at `n09_provider_gap_tests.jl:59-65` constructs G1/G2/G3 V5 objects from the child fixture process, binds the same candidate, passes actual G1/G2 feedback refs into G3, and calls `FusionConceptAI.integrate_genome_v5`. The five baseline values are therefore source values: G1 operator and both G2 declarations are `unique_match`; G3 realization and control are `no_match`. The fixture has 11 rows, all changing a declaration: one `no_match`, five `out_of_domain`, and five `invalid_signature`. The test verifies the actual baseline before mutation at source/projection construction and checks that each mutation changes the projection hash (`:114-137`). An unchanged G3 `no_match` baseline is never counted as a mutation because each G3 row changes to a different registered value.

## Classification and invocation boundary

`_n09_mutated_projection` at `N09ProviderGapProjectionV1.jl:255-272` requires the exact field path, exact source locator, source baseline provider value, and an actual value change before rebuilding the typed declaration. `n09_validate_mutation` at `:274-297` requires a complete five-declaration projection, rejects nonzero invocation counters, verifies the mutated value is one of the deferred provider capability statuses, and returns `status=:terminal_deferred`, `resolution=:terminal_deferred`, `error_code=:provider_match`, the exact source field path, and detail `provider_capability_gap:<mutated_value>`. The test checks all of these and all compile/provider/solver counts are zero.

The zero counters mean the invalid contract path short-circuited before any compiler, provider, or solver call. They do not mean a provider was found or executed. The fixture and acceptance correctly state `provider_resolution_executed=false`, `evidence_reused=false`, and no provider, mesh, solver, engineering, physical, B04, or R01-R10 credit.

## Limits retained by this verdict

This is a narrow projection of already present provider declarations. It does not itself validate the full A package identity or admission state beyond the actual package construction path used by the focused test. A caller can invoke the low-level `N09ProviderGapProjectionV1` constructor with a `Digest256` and declarations; that seam is not a substitute for the actual-A factory path and must not be admitted as B04 input.

The result class and resolution are fixed to the N09 contract domain in the validator (`:provider_match` and `:terminal_deferred`). The implementation does not include a negative test that changes `expected_error` to another class and proves classification remains source-derived; the validator does not read `spec.expected_error` in `n09_validate_mutation`, but the constructor validates the expected class and the test compares the fixed expected class. A future formal N10/B04 checker should add that oracle-independence control. This limitation prevents broader classification credit but does not invalidate the ten source path/ref/hash checks and the eleven actual changing provider-gap mutations in this bounded slice.

The author source, fixture, test, runner, old r1/r2 evidence, and core files were not modified. Only this independent review directory was written. The final recommendation is to retain the author archive as review-pending and allow only this contract-only slice to proceed to its next integration gate.
