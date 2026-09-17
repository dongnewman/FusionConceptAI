# AD49-F0 G1/G2 source-authority factories — root acceptance R2

日期：2026-09-16  
决策：`accepted_limited`  
accepted scope：`factory_software_capability_only`  
唯一后续许可：fresh `AD49-S2` probe

## Decision

依据不同 `gpt-5.6-luna/high` 的 R2 独立复核 `pass_limited`，root 接受四个 F0 产品在有限软件范围内的 factory capability。R1 的 `changes_requested` 记录保留为 append-only 历史；R2 已关闭其两个具体缺口：隔离 Git fixture 被误标为 `repository_head`，以及 `assume-unchanged`/`skip-worktree` 工作树变更未与真实 HEAD blob 做独立闭合。

R2 确认每个 factory 从自身模块 `@__DIR__` 推导并校验 repository anchor；`repository_head` 需要同一仓库根，anchor 不可用、foreign/relabelled fixture、HEAD blob digest 不符、工作树字节/长度/SHA 不符或 Git 状态不闭合时均 fail-closed。`isolated_test_fixture` 仅可产生 `synthetic_test_only=true` 的 Present 软件结果。G2 保留 `GenomeContractRef`，没有加入到 `QualifiedRefV1` 的 mapping API。

四个产品仍是当前工作树新增文件。G1/G2 declaration source 均未被 `HEAD=4b69f55f7f80240147a65a22809dc1207824dde2` 跟踪；因此本接受不把 factory 软件 capability 误写成 repository source authority。

## Frozen F0 products

| product | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G1/G1SourceAuthorityFactoryV1.jl` | 28642 | `23684a9e6bb267d6fdfe06df5acc8f7c8cf299ac8c8bf8433ae601c9fdb4331b` |
| `test/GenomeV5/G1/g1_source_authority_factory_v1_tests.jl` | 9857 | `6f6c8bfad9d7a3682e38e9d2960efdee93c63447339e46be84b36420846ec677` |
| `src/GenomeV5/G2/G2SourceAuthorityFactoryV1.jl` | 24807 | `5b5d013a0ad5ee6eb07f714480e36911be9aa96636a3d3f368f38163240409c8` |
| `test/GenomeV5/G2/g2_source_authority_factory_v1_tests.jl` | 9456 | `0dd880d54e05b0101860eb84ebb0a1a5dd6c6f86077efbf1919ff205b1061b70` |

R2 focused adversarial runs passed G1 `31/31` and G2 `31/31`, each exit `0`; existing G1 regressions passed `47/47 + 21/21`, and G2 regressions passed `57/57 + 59/59 + 8/8`, all exit `0`. Julia was serialized, with no Julia process before or after the review; DESC was not started. These are software and process records only.

## Review evidence

R1 remains `changes_requested` and its required repair list is retained at:

- `independent_review_r1/report.md`, SHA-256 `a3222d1f08bf81cff03d86802e4faf36fb617158c048ea7694e93b36ac039616`
- `independent_review_r1/manifest.json`, SHA-256 `321359f6bd519f72e771079a15c1a1ec60eed4fd8b2e18fca085006197c16732`

R2 is the accepting independent review:

- `independent_review_r2/report.md`, SHA-256 `b87f2494ddc193ce5925b1dbf35d02148853d60a7218b63ed565b0ab7d24e621`
- `independent_review_r2/manifest.json`, SHA-256 `f076358e4dd5e93675751798e60f9058b3b7b3dc802231bb7e9ee083a2b3a189`
- `independent_review_r2/direct_validation.json`, SHA-256 `20142cf9a713ef50e60f4517c2c24150975b1a0e022396c33461fdbade9865d6`
- `independent_review_r2/final_hashes.json`, SHA-256 `421caf1ed4f2cc2bfb53bf71d971542d6ceccbc6a99782bc8b73e8e1eb1994d8`

The compact R2 manifest and final hashes declare `self_hash_excluded=true`. The review directory is excluded from its own baseline/final scope; the retained compact baseline has `review_outputs_excluded=true`. Any earlier oversized self-inclusion attempt remains review history and is not used as acceptance evidence. R2 direct validation reports exit `0`, no failures, plan validator exit `0`, and scoped `git diff --check` exit `0`.

## Source and binding boundary

Both factories bind the exact temporary AD45 common handle
`fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`, version `v5`, and envelope
`docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json` (9612 bytes, SHA-256 `17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`). The source-stage binding remains temporary, with `trusted=false`, `candidate_identity_created=false`, and `final_hash_created=false`.

The current G1 and G2 declaration source files are `??` working-tree files and `git cat-file -e HEAD:path` is absent for both. The current factory result therefore cannot confer source authority or trusted source identity. No registry, entrypoint, old declaration schema, candidate package, or final hash was changed by this acceptance.

## Gate effect and claim ceiling

This acceptance permits only a fresh S2 factory probe using the frozen F0 products and current source/locator state. It does not accept or create:

`source_authority=false`, `trusted_source_identity=false`, `candidate_identity=false`, `final_hash=false`, `T0=false`, `T1=false`, `T2=false`, `provider=false`, `mesh=false`, `solver=false`, `engineering=false`, `physics=false`, `search=false`, `R01–R10=false`, `L4_credible_count=0`.

The acceptance does not unlock G2 mapping, W3-B, trusted identity, CandidateIdentity, UP2, or any physical or engineering execution. UP3–UP6 preparation may remain pending under their stated contracts. The parent R01–R10 goal remains open.

## Acceptance checks

The root read-only recheck confirmed HEAD, all four product bytes/SHA-256, protected registry/entrypoint/declaration hashes, upstream AD45/payload/locator hashes, R1/R2 review references, typed absence of both declaration sources, no Julia process, and no write outside this `root_acceptance_r2/**` directory. The plan validator and scoped diff check were already recorded with exit `0` by the independent R2 review.

