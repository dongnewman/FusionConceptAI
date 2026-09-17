# UP2-00 contract-only precompiler scaffold

Status: `review_pending`  
Accepted: `false`  
Scope: `schema_validation_only`

This archive records the first auditable typed slice. `up2_projection_from_a` derives N01 and N02 values from the actual `CandidateStatePackageV5` fields (G1 equation/state, G2 embedding/field space, and G3 resource/ledger entries). `up2_input_from_a` re-derives the projection and rejects a forged projection with the same package hash. N01 rank, dimension, shape, and N02 unit mutations are changed typed values; the validator derives the failure from source relationships and does not read `expected_error`. The invalid path leaves compile, provider, and solver invocation counters at zero.

N05 is registered as five typed paired-interface mutations, but remains `terminal_deferred`: the current A package supplies a G2 interface reference, regions, normal, and transfer kind, while it does not supply authoritative flux port and unit provenance. Region identifiers are not treated as flux ports; the projection uses explicit pending port values and `port_source=:unverified`. N03, N04, and N06–N10 remain pending semantic gaps (35 mutations), so 40 of the 50 rows are pending in this slice. The fixture still contains all 50 frozen mutation rows; registration is not evidence that pending rows passed.

The r18 focused runner completed with process exit `0`. It exercises the actual A package path and checks all ten N01/N02 mutations for derived error code, exact path, changed input hash, and zero compile/provider/solver calls; N05 and the other 35 rows remain pending. r17 is preserved as the preceding exit-0 attempt. The earlier r2–r4 attempts have real exit `1`; r5 and r7 were real exit `0` but came from the pre-refactor self-certifying implementation and are historical only. The original r6 attempt was overwritten before this archive and is marked unrecoverable/unknown; its current file is not used as evidence of the original run. r8–r16 are preserved with their original failures and intermediate states.

Only `up2_input_from_a(package, mission_bounds, source_manifest_hash)` is source-backed. The public low-level `UP2PrecompilerInputV1` constructor remains a synthetic test seam and is explicitly unverified; it is not admissible for B04. The source manifest hash passed to the A factory is the digest of the frozen UP1-04A fixture file used by the focused test. It is a test provenance anchor, not an external provider receipt. No solver, mesh, provider, engineering, physical, B00, B04, or R01–R10 credit is claimed. `claim_ceiling=none`, `resolution=terminal_deferred`, and `evidence_reused=false` remain required.

Command:

```text
julia --startup-file=no --project=. test/GenomeV5/UP2/run_up2_00_contract.jl
```

Environment: Julia 1.10.5, Python 3.13.5, Julia threads 24, BLAS threads 12, HEAD `4b69f55f7f80240147a65a22809dc1207824dde2`. Existing dirty work was preserved; only the three UP2 source files, three UP2 test files, fixture, and this implementation archive are in scope.

Independent review is still required before any limited software acceptance is recorded.

## Integration record

Independent review r18 is `accepted_limited` for the actual-A N01/N02 schema/value projection slice only. Review artifacts: [independent acceptance](independent_review_r18/acceptance.md), SHA256 `c8ca42620ea85b0d168c128763923fed426e51a8ee63db7d2e1ce145484436f7`; [independent evidence](independent_review_r18/evidence_manifest.json), SHA256 `4bfbf378be1de8b30de6b6077a4b30037df527b50a3ce814bf58a59d4e74d127`.

This limited review does not accept UP2-00 overall: the author status remains `review_pending`, `accepted=false`, 40 of 50 mutations remain pending, and UP1-04B remains `planned`. B00, B04, provider, mesh, engineering, physical, and R01-R10 credit remain false.
