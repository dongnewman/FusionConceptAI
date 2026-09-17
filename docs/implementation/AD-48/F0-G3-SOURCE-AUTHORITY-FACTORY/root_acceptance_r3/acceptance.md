# AD48-F0 G3 source-authority factory — root acceptance R3

日期：2026-09-15  
decision：`accepted_limited`  
accepted_scope：`g3_source_stage_factory_software_contract_only`

本 root acceptance 依据：

- R1 独立复核：`changes_requested`；缺少 candidate-bound G3 source content/declaration identity，且 factory 未闭合 live source invalidation。
- R2 独立复核：`changes_requested`；factory 只接受 `fusionconceptai://candidate/...`，拒绝 AD45 冻结的 `fusionconceptai://candidate-binding/...`，四个真实调用均 `foreign_common_handle`。
- R3 独立复核：`pass_limited`；exact AD45 handle、version、envelope path/SHA 和 S1 四个真实 frozen source inputs 均通过，R1/R2 blockers closed。

## Frozen product hashes

| product | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/G3/G3SourceAuthorityFactoryV1.jl` | 31581 | `1002676652c44aed81caaf9599ebf9ca62b0a4aab2fa32afe1e3d8c8edf8c0f4` |
| `test/GenomeV5/G3/g3_source_authority_factory_v1_tests.jl` | 14904 | `02540e91aded97267161af1f02a48b721aaacbb0b187751249f61603d8cd0e9f` |

当前只读 hash 核验与 R3 acceptance/manifest JSON 解析均通过；R3 产品双采样保持一致。核验结果由 R3 `raw/hash_replay.json`、`raw/protected_paths_status.json` 和 `raw/plan_validator_final.json` 支持。

## Acceptance evidence

R3 focused Julia passed `320/320` (exit `0`)。独立 exact-input probe 使用 AD45 冻结句柄
`fusionconceptai://candidate-binding/AD45-FRESH-CANDIDATE-BINDING-ENVELOPE/3da169fa-2376-4b36-b794-ac5a32161aa7`、version `v5`，并在 factory 调用时验证 envelope
`docs/implementation/AD-45/FRESH-CANDIDATE-BINDING-ENVELOPE/fresh_candidate_binding_envelope_v1.json`，9612 bytes，SHA-256
`17901aa6e1be326b95e56fbbbd5148bd02b7c3ea43bd0c451336cd297e2950dc`；四 scope 真实 frozen inputs passed `99/99` (exit `0`)。相关 G3 realization/control/binding 回归为 `65/65 + 167/167 + 70/70 = 302/302`，全部 exit `0`。

该有限范围确认 typed `G3SourceContractBindingV1` 直接绑定 exact common handle、scope G3 contract 和四 axes；`binding_role` 仅为 temporary，`candidate_identity_created=false`。source content/declaration/ref/hash 可重算，local declaration hash 明确不等 final candidate/package/T0 declaration hash；receipt replayable 且 `trusted_attestation_created=false`。synthetic/foreign/wrong-version/allocation/alias 与 source/HEAD/hash/path/status mutations fail-closed，缺少 typed input 为 typed absence/`terminal_deferred`。registry、`FusionConceptAI`、`RealizationGenomeV5` 与 `G3ContractBindingV2` 未被本验收修改或冒充。

## Gate effect and claim ceiling

本验收只解锁 **fresh AD48-S2 factory receipt** 的重新取证。旧 S2 `AbsentG3FactoryIdentityV1` 历史不能被本验收覆盖、改写或当作 fresh present receipt；旧产品继续 append-only 保留。

AD48-S3 trusted source identity、fresh W1、W2、AD46 identity input freeze/join/materialization 仍锁定。`trusted_identity=false`、`final_candidate=false`、`package=false`、`T0=false`、`T1=false`、`T2=false`、`provider=false`、`physics=false`、`search=false`、`R01–R10=false`、`L4 credible count=0`。本次归档未运行 Julia/DESC，也未修改产品或其他目录。

## References

- `docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/independent_review_r1/report.md` — R1 `changes_requested`
- `docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/independent_review_r2/review.md` — R2 `changes_requested`
- `docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/independent_review_r3/review/report.md` — R3 `pass_limited`
- `docs/implementation/AD-48/F0-G3-SOURCE-AUTHORITY-FACTORY/independent_review_r3/acceptance/acceptance.json` — R3 machine acceptance
