# AD49-F0 G1/G2 source-authority factories — independent review R1

Date: 2026-09-15 UTC  
Decision: `changes_requested`  
Scope: independent software review of the four F0 products and their task-owned focused/regression evidence. No reviewed product, source declaration, registry, `FusionConceptAI.jl`, or task manifest was modified. Only this `independent_review_r1/` directory was written.

## Decision

The factory software shape is substantially present and the ordinary focused tests pass, but this review cannot accept F0 as `pass_limited` because two required source-closure controls are unsound.

1. An isolated tracked Git fixture can be relabeled `provenance=:repository_head`; both factories then return `:present` with `synthetic_test_only=false`. The implementation derives the synthetic flag from the caller label but never checks that an isolated fixture must carry `:isolated_test_fixture`. This violates the required fixture ceiling and can mislabel synthetic bytes as repository provenance.
2. A tracked fixture file can be changed after commit and marked Git `assume-unchanged`. The working-tree status is empty, yet both factories return `:present` when the locator reports the mutated bytes. `_validate_locator` checks a HEAD path and a 40-character object id, but never hashes the bytes returned by `git cat-file blob HEAD:<path>` and compares them with the locator/source bytes. This does not establish the required exact committed Git closure.

Both defects are reproducible in fresh Julia processes and are recorded under `raw/`. The required repairs are narrow: enforce provenance/fixture consistency with a fail-closed result, and independently recompute the committed blob bytes from HEAD before allowing `:repository_head` Present. Add focused negative controls for both cases. Do not change old schemas, registries, `default_operator_registry()`, or promote any authority/identity claim.

## Positive evidence and boundaries

The current checkout is `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2`. The G1/G2 declaration sources and F0 tests are all present only as `??` working-tree files; `git cat-file -e HEAD:<path>` exits `128`. Therefore the current repository call is correctly typed absent in the focused tests. No Julia process remained after validation.

The exact AD45 common handle and envelope used by both products remain the accepted temporary values: `QualifiedRefV1/v5`, id `fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`, envelope 9612 bytes, SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`. The ordinary Present fixture path records `:isolated_test_fixture`, `synthetic_test_only=true`, the public `GenomeContractRef`, four axes, temporary binding role, `candidate_identity_created=false`, and binding/source/declaration/receipt hash inputs. G2 retains `GenomeContractRef` and does not perform mapping. The receipt flags remain `trusted=false`, `candidate_identity_created=false`, and `final_hash_created=false`.

## Fresh execution receipts

All Julia runs were started after a `NO_JULIA_PROCESS` check and serialized in one PowerShell runner. Focused and regression results were:

| check | result | PID | UTC | exit |
|---|---:|---:|---|---:|
| G1 F0 focused | 26/26 | 90020 | 16:40:25–16:40:35 | 0 |
| G2 F0 focused | 26/26 | 80612 | 16:40:35–16:40:46 | 0 |
| G1 diffusion regression | 32/32 + 34/34 + 5/5 | 85128 | 16:40:46–16:40:51 | 0 |
| G1 UP1 regression | 47/47 + 21/21 | 89680 | 16:40:51–16:41:03 | 0 |
| G2 metric regression | 20/20 + 10/10 + 5/5 + 14/14 + 15/15 | 84792 | 16:41:03–16:41:10 | 0 |
| G2 UP1 regression | 57/57 + 59/59 + 8/8 | 79892 | 16:41:10–16:41:22 | 0 |
| G1 wrong provenance probe | reproduced `present`, synthetic `false` | 24240 | 16:41:22–16:41:33 | 0 |
| G2 wrong provenance probe | reproduced `present`, synthetic `false` | 15792 | 16:41:33–16:41:47 | 0 |
| G1 assume-unchanged closure probe | reproduced `present`, status empty | 83916 | 16:44:37–16:44:50 | 0 |
| G2 assume-unchanged closure probe | reproduced `present`, status empty | 84936 | 16:44:50–16:45:01 | 0 |

Raw stdout/stderr and per-process PID/UTC/exit records are in `raw/`. The two failing-behavior probes intentionally use temporary Git repositories and do not touch the checkout.

## Python and plan checks

Python static/protected-hash validation ran with `D:\Users\Newman\anaconda3\python.exe`, PID `93496`, UTC `16:49:55.3750572Z–16:49:56.2285171Z`, exit `0`. It confirmed all four product hashes, protected hashes, current HEAD absence for both declaration sources, required additive tokens, and scoped `git diff --check` exit `0`; raw JSON is `raw/python_static_hash_validation_stdout.json`.

The plan validator ran serially with PID `90452`, UTC `16:49:56.2442500Z–16:49:56.9344667Z`, exit `0`: 31 markdown files, 526 relative links, 39 tasks, acyclic DAG. Raw streams are `raw/python_plan_validator_stdout.txt` and `raw/python_plan_validator_stderr.txt`.

## Product hashes and protected bytes

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl` | 27176 | `cf52fa4b0240dc25b793940a199153edc019190a7d2da106524a150514139a92` |
| `test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl` | 7741 | `3e257e8b0b8a75cee36cac29f5aa3dc6a67e1f59aed28f31b07623a2c6154726` |
| `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl` | 23187 | `1e64993eced7f7741eef46e840062a6bf1868593770314db33949de2918e919c` |
| `test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl` | 7340 | `907d797f39fb4be8fbdc59d2dd8aeaa1d238e4f0544a95e525bd8e6c2931c5fd` |
| `src/Contracts/GenomeContractRegistry.jl` | 2389 | `ee57228623e314897a3e34f3bfd387e8cce4d89c2b0dfaaf29d227076a08495c` |
| `src/IR/OperatorRegistry.jl` | 64932 | `4c2f4383140527613782288749283d268497846ec915df158164875125677f45` |
| `src/FusionConceptAI.jl` | 10144 | `e3fa8638ed9c5c5f468ae9a8f797416f2bec19b432cc10a9c1aea81ec3460783` |

## Credit ceiling

This review grants no source authority, trusted/final hash, candidate identity, T0, physical result, R01–R10, or L4 credit. It only records that the additive factory code passes its ordinary software tests while the two source-closure controls require repair. After repair, rerun fresh G1/G2 focused tests and both negative controls, then obtain another independent review.
