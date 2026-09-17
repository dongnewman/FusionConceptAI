# AD48-F0 G3 source-authority factory independent review R1

## Verdict

`changes_requested`. The final two implementation files are stable at the requested freeze, and the software checks pass, but the implementation is only a typed adapter around `G3ContractBindingV2`. It does not construct or return a candidate-bound G3 source declaration or its declaration/content identity. That is a required capability in the AD48 S2/F0 contract, so this review cannot accept F0 and cannot treat the current result as sufficient input for a completed fresh S2 gate.

## Frozen inputs

The final double sample was stable before the final focused run:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | 16832 | `b00bc91b07336463d5ee2c9b51058ff052e4cb08acd1423322a5e60c0a857d2f` |
| `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl` | 6827 | `ad62cf6bf15fa14b8f0093f609828898660e31fd25c1d13bd103850cc01d32c6` |

The source was changed during the earlier part of this independent review from a 13652-byte candidate to the final 16832-byte candidate. The earlier candidate is recorded in `review/raw/concurrency_replacement.json`; its initial focused run is not used as evidence for the final file. The final source and test were then double-sampled with unchanged bytes, SHA and mtime.

## Contract and API findings

The final source declares typed identity and construction-receipt unions for `present`, `typed_absent`, and `fail_closed`, plus `semantic_view` methods for the locator, all union members and the result. The entry point consumes `G3IndependentSourceLocatorV1`, a `QualifiedRefV1` v5 common candidate handle, `GenomeContractRef`, and `G3VersionAxesV2`. It validates the four scope-specific contract refs and axes, calls the real `G3ContractBindingV2` constructor, records the constructed binding digest, and leaves registry state untouched. Missing typed inputs become `Absent...` with `terminal_deferred`; type, scope, path, contract, axis, foreign-handle, stale-byte and constructor errors become `Failed...` with `fail_closed`.

The receipt has a replayable function name, constructor type and symbolic argument schema, and includes the typed input values and exact source path/bytes/SHA. It explicitly records `registry_not_used=true`, `candidate_identity_created=false`, `declaration_hash_created=false`, and `trusted_attestation_created=false`. The source contains no registry mutation and no provider, mesh, solver, engineering, physical or search execution. These parts satisfy the limited software adapter boundary and are not physical or source-authority evidence.

The blocking defect is semantic. `_g3s_binding` calls only:

`G3ContractBindingV2(contract_ref, common_binding_handle, version_axes)`

The output is a contract-binding handle/hash. There is no candidate-bound G3 source declaration type, source declaration reference, declaration body, declaration hash, source content payload, or declaration-to-locator binding. The `common_binding_handle` is merely a candidate-shaped `QualifiedRefV1`; setting its URI prefix and version does not create the required source declaration. The code itself documents that the constructed object is “not a CandidateIdentityV1 and not a declaration,” while every present result keeps `declaration_hash_created=false`. Therefore fresh S2 cannot identify a present source-authority factory from this implementation, and S3/fresh W1/W2 remain blocked.

There is also a contract-quality gap in the locator check: it verifies current file bytes and SHA, expected relative path, and the `:missing` status, but it does not compare `observed_head` or the locator's HEAD/working-tree path-status fields with a current repository probe. This leaves HEAD/status staleness to the upstream locator owner instead of making the factory's source invalidation boundary self-checking. It should be closed in the repair or explicitly documented as an upstream-only invariant.

The implementation exposes one scope-parameterized entry point and dynamically names the result function by scope. If the F0 work order's “four scope-specific constructors” is interpreted literally, the repair should add typed scope wrappers or an equally explicit per-scope API; the current generic entry point is testable but does not itself provide four distinct constructor entry points.

## Execution evidence

The final implementation was independently run serially with Julia 1.10.5 at `C:\Users\Newman\AppData\Local\Programs\Julia-1.10.5\bin\julia.exe`, PID `33416`, UTC `2026-09-15T14:10:03.187`, and exited `0`: `157/157` focused checks passed. The three G3 child regressions were run as separate serial Julia processes on the final source: realization `65/65`, PID `86668`; control `167/167`, PID `63584`; binding `70/70`, PID `77836`; all exited `0`, total `302/302`. Raw output and the two failed wrapper-launch attempts are retained under `review/raw/`.

The active planning validator used Python 3.13.5 at `D:\Users\Newman\anaconda3\python.exe`, exited `0`, and reported 31 markdown files, 526 relative links, 39 tasks and an acyclic DAG. Scoped `git diff --check` exited `0`. These are software and planning hygiene checks only; they do not establish source authority, trusted attestation, provider availability, mesh, solver convergence, engineering feasibility, physical output, or R01–R10 completion.

## Required repair and gate decision

Repair must remain limited to the two owned implementation files and must add a typed candidate-bound G3 source declaration/content contract whose exact semantic body is bound to the independent locator, source bytes/SHA, scope, G3 contract ref, candidate handle and four axes. The construction receipt must record the declaration constructor signature and argument schema sufficiently for an independent fresh replay. It must continue to keep the construction receipt separate from trusted attestation, keep candidate/final identity claims false, preserve absent/fail-closed behavior, and leave the registry unchanged. After that repair receives a different Luna independent review, rerun the fresh S2 eight-product set; do not reuse the current S2 absence products or this F0 run.

`fresh_s2_permitted`: `false_pending_f0_repair_and_review`.

The parent R01–R10 objective, physical and engineering evidence, provider/mesh/solver execution, search credit and L4 count remain unchanged: false or zero.
