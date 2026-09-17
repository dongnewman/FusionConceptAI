# AD48-F0 G3 source-authority factory independent review R2

## Verdict

`changes_requested`.

The repaired factory closes the R1 structural gaps when exercised with the synthetic handle used by its focused suite: every scope produces typed candidate-bound source content/declaration/ref/hash; the local declaration hash is explicitly marked as a G3-local hash while candidate identity, final candidate/package declaration hash, and trusted attestation remain false; the factory performs live Git and working-tree checks; four wrappers exist; receipts are deterministic/replayable; and the operation is fail-atomic with no registry mutation.

The R2 gate is blocked by a real frozen-input compatibility failure. AD45's accepted binding envelope supplies this common v5 handle:

`fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`

Calling the factory with that exact handle and the current real locator, contract ref, axes, and per-scope declaration ref returns `fail_closed / foreign_common_handle` for all four scopes. The factory line `482` requires `startswith(common_binding_handle.id, "fusionconceptai://candidate/")`, which excludes AD45's frozen `candidate-binding` namespace. Consequently the actual AD45 candidate-bound path cannot construct any G3 source declaration, so the R1 gap is not fully closed.

## Frozen inputs and historical evidence

The current product files match the F0 archive manifest exactly:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | 29094 | `2dc7014f5b4423cd1350f20c85b8c31836df363b7b41392ea44ec8d2eac95a88` |
| `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl` | 12616 | `40361f140293e5619bce942677ce8be6ac388386e8cf6c9679e2ff0dd634e131` |

Observed HEAD is `4b69f55f7f80240147a65a22809dc1207824dde2`. R1's report, manifest, raw failed wrapper launches, earlier candidate hashes, and repair failure history remain preserved. The AD45 envelope used for the compatibility probe is 9612 bytes with SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`; its independent R2 manifest is 7694 bytes with SHA-256 `d5f58ce33e9d87579569cc3b167c9cffc4e9edafda5196545db76fc05bcfb22e2`.

## Contract checks

1. Candidate-bound G3 source content/declaration/ref/hash exists for all four scopes under the synthetic focused-test handle. `g3_source_declaration_hash_created=true` is separate from `candidate_identity_created=false` and `final_candidate_or_package_declaration_hash_created=false`. No CandidateIdentity, package hash, or T0 hash is created by this factory. This structural check passes, but actual AD45 compatibility fails as described above.
2. `_g3s_validate_locator` rereads current bytes and length/SHA, then probes `git rev-parse HEAD`, `git ls-tree HEAD:path`, `git rev-parse HEAD:path`, and `git status --porcelain=v1 --untracked-files=all -- path`; observed HEAD, HEAD path status/blob, working-tree path/status, and bytes are compared and mismatches fail closed. Focused negative controls cover stale HEAD, HEAD path status, working-tree path status, working-tree status, source path, source bytes/hash, and foreign inputs.
3. The four explicit wrappers are present and focused tests invoke each one.
4. Present receipts include typed constructor/function/schema inputs and output declaration for deterministic replay. `trusted_attestation_created=false` remains explicit.
5. Missing inputs return typed absence; mismatches and stale observations return fail closed; construction has no global publication path. The focused suite checks registry hash before/after. The F0 files do not alter `default_operator_registry()`. `src/FusionConceptAI.jl` was already dirty at R2 start with eight unrelated insertions; it was not edited by this review or by the F0 product files.
6. R1's source-declaration/content and live-invalidation gaps are structurally repaired, but the frozen AD45 handle namespace gap remains an acceptance blocker.

## Execution evidence

Before each Julia run, no `julia`, `julia-debug`, or `juliaup` process was present. Julia runs were serialized.

| check | exact result | exit |
|---|---:|---:|
| F0 focused Julia suite | 268/268 | 0 |
| G3 realization child regression | 65/65 | 0 |
| G3 control child regression | 167/167 | 0 |
| G3 binding child regression | 70/70 | 0 |
| G3 regression aggregate | 302/302 | `[0,0,0]` |
| AD45 real-handle compatibility calls | 0/4 present; 4/4 fail-closed | 0 (probe completed; behavior is a failure) |
| Python plan validator | 31 markdown, 526 links, 39 tasks, DAG acyclic | 0 |
| scoped `git diff --check` | 1 command, clean | 0 |

Raw command receipts are under `raw/`. The probe's exit `0` only means the probe ran; its four `foreign_common_handle` results are the blocking product behavior.

## Required repair

Accept the actual AD45 common binding namespace as a valid v5 candidate-bound handle, or replace the prefix check with the frozen QualifiedRef contract used by AD45. Add a focused real-handle test using the exact AD45 envelope value, rerun the four-scope construction and all invalidation/receipt checks, refresh the two product SHA values and archive manifest, then obtain a new independent R2 review. Keep the local declaration hash and all negative claims separated from final CandidateIdentity/package/T0 identity, and preserve the current failure history.

This review grants no trusted attestation, final candidate/package identity, T0/T1/T2, provider, mesh, solver, engineering, physical, search, R01–R10, or L4 credit.
