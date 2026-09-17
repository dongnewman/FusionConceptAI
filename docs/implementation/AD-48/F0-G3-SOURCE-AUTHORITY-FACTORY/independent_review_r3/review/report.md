# AD48-F0 G3 source-authority factory independent review R3

## Verdict

`pass_limited` for the frozen F0 software contract. R3 independently confirms that the repaired factory accepts the exact AD45 common handle and exact envelope, constructs an independent typed `G3SourceContractBindingV1` plus candidate-bound G3 source content/declaration/ref/hash for all four scopes using the S1 frozen source inputs, and rejects the required negative controls. R1 and R2 blockers are closed.

This is a repository-local software contract review only. It creates no trusted attestation, final candidate identity, package/T0 identity, provider, mesh, solver, engineering, physical, search, R01-R10, or L4 credit.

## Frozen inputs and boundary

The reviewed product files were sampled twice with identical bytes and SHA-256:

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | 31581 | `1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4` |
| `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl` | 14904 | `02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f` |

The exact AD45 handle used at the factory call is `fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`, version `v5`. The factory rereads and verifies the exact relative envelope path `docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json`, 9612 bytes, SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc` before constructing a result. The four source locators were loaded from the frozen AD48-S1 JSON products and matched current bytes, path, observed HEAD, and status.

R3 observed HEAD was `4b69f55f7f80240147a65a22809dc1207824dde2`. The existing dirty `src/FusionConceptAI.jl` and untracked G3 source files were present at the review boundary; no command in this review edited them. The review writes only this `independent_review_r3/` directory.

## Contract findings

1. `g3_source_authority_factory_v1` and its four explicit scope wrappers validate typed locator, exact AD45 handle ID/version, exact envelope path and digest, live source bytes/length/SHA, live Git HEAD/path/blob/status, exact G3 contract ref, exact `G3VersionAxesV2`, and scoped declaration ref before construction. A stale HEAD, path/status, source path, bytes, or hash fails closed; a missing required input is typed absence with `terminal_deferred`.
2. The output has an independent typed `G3SourceContractBindingV1` directly carrying the exact common handle, scope's G3 contract ref, all four axes, `binding_role=:temporary_common_candidate_binding_handle_only`, `candidate_identity_created=false`, and a recomputable binding digest. It is not `G3ContractBindingV2` and does not adapt or publish one.
3. `G3CandidateBoundSourceContentV1` and `G3CandidateBoundSourceDeclarationV1` carry the source locator/path/bytes/hash, locator digest, source role/schema, exact AD45 envelope path/hash, contract/axes/binding, declaration ref, and recomputable content/declaration hashes. The local declaration hash is explicitly separate from final candidate/package declaration or T0 identity; all final and candidate identity flags remain false.
4. Present construction receipts include the typed constructor/function/schema, exact source inputs, output declaration, semantic and construction digests, `registry_not_used=true`, `trusted_attestation_created=false`, and false final identity flags. Receipt replay is deterministic and has no global publication path.
5. The focused test and independent probe cover synthetic candidate, foreign handle, wrong version, wrong AD45 allocation, alias, missing inputs, wrong scope/contract/axes/declaration, source/path/status/HEAD/hash mutation, registry preservation, declaration replay, and all four wrappers. Results are fail-closed or typed absence as applicable.

## Independent execution

Julia was checked absent before each process and runs were serialized. Raw PID/UTC/exit/stdout/stderr receipts are under `raw/`.

| check | result | exit |
|---|---:|---:|
| F0 focused suite | 320/320 | 0 |
| exact AD45 + S1 frozen real-input probe | 99/99 | 0 |
| G3 realization child regression | 65/65 | 0 |
| G3 control child regression | 167/167 | 0 |
| G3 binding child regression | 70/70 | 0 |
| Python plan validator | 31 markdown, 526 links, 39 tasks, DAG acyclic | 0 |
| scoped `git diff --check` | clean | 0 |

The real-input probe independently recomputed canonical hashes for binding, content, and declaration for each Present scope. It also confirmed the exact AD45 namespace compatibility that blocked R2. The focused suite's registry hash was unchanged before/after construction and a failed call.

## Historical blockers

R1's missing candidate-bound source declaration/content identity and missing factory-owned live invalidation checks are closed by the typed source binding/content/declaration and Git probe. R2's `foreign_common_handle` failure is closed by exact acceptance of the frozen AD45 `candidate-binding` ID and `v5` version, with an exact envelope re-read. The prior launcher and same-process module-replacement failures remain append-only in `archive/` and are not reused as positive evidence.

## Claim ceiling

`pass_limited` applies only to the two F0 implementation files and this software contract boundary. It does not create or imply trusted source identity, CandidateIdentityV1, package/T0/T1/T2, provider/mesh/solver execution, engineering feasibility, physical validation, search credit, R01-R10 completion, or an L4 credible candidate.
