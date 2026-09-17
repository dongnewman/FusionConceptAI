# UP4 inverse-realization contract matrix R5 runtime archive

状态：`contract_only / accepted=false / runtime_success_archived`。

本目录归档既有 focused Julia run 的原始结果；本次只新增文档证据，未重跑 Julia/DESC，未修改产品源码、测试、fixture、manifest 状态或原始 run 文件。

## Runtime 结果

- 原始 run：`runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r5/`
- command：`julia --startup-file=no --history-file=no --project=. test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl`
- HEAD：`70cded1ca1b64496bbee44ac0025659f446364ea`
- started：`2026-09-17T17:01:29.7393536Z`
- finished：`2026-09-17T17:01:34.2971852Z`
- exit code：`0`
- test totals：`58 pass / 58 total`
- reported Julia time：`3.9s`
- stderr：空（`0` bytes）
- `run.json`：`hashes_unchanged=true`

stdout 原文为：

```text
Test Summary:                                    | Pass  Total  Time
UP4 inverse realization request contract-only v1 |   58     58  3.9s
```

## 输入完整性

R5 原始 run 的 pre/post input hash 完全一致；归档使用这些原始记录，不以当前工作树重算值替代：

| path | pre/post SHA-256 |
|---|---|
| `src/RuntimeV4/InverseRealizationRequestContractV1.jl` | `5c25e92b625eff79b3e4714e3bbfb33e3b57354bddf2a24339296c890537b6e4` |
| `test/RuntimeV4/inverse_realization_request_contract_v1_tests.jl` | `898bf30229a7254f3aaa5388253c959a51247d13bb66dc4afca999168aa2a2b5` |
| `test/RuntimeV4/fixtures/inverse_realization_request_contract_v1.json` | `51c025279dc514fc035366696ffa29387ffac5b68f9edfab9ceab43daab39fcd` |

原始 artifact SHA-256：`run.json=9fd4cbb0c5aebf4852a65cfb1e66633f57370e55a42cdadf475121d40f2373ce`、`stdout.raw=9eec3aa1181af9550be66c8d2fcc6839ef9db1d66675081560e9fd9486b6c17c`、`stderr.raw=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`、`head.txt=6b114fb77c18b3d2d7106bc3e864cc15d2beb24624553f4e2727bf3a80bbadbf`。

## R4 失败保留

R4 原始证据仍保留且未覆盖：
`runs/agent_local_up4_inverse_realization_contract_matrix_20260918_r4/`。

- exit code：`1`
- test totals：`0 pass / 0 fail / 1 error`
- failure：`inverse external input [malformed_input]: duplicate provider domains`
- `hashes_unchanged=true`
- 原始 `run.json`、`stdout.raw`、`stderr.raw` 未改写。

R5 的成功只证明当前 inverse-realization request contract 的 Julia focused contract tests 通过；不证明真实 provider、hardware、mesh、solver、工程或物理实现，不授予 formal authority、UP4 完成或 R01–R10 信用。

## 归档边界

- `provider_calls=0`、`solver_calls=0`
- `real_provider=false`、`real_hardware=false`
- `desc_executed=false`
- `formal_credit=none`
- `no_r01_r10_credit=true`
- `no_commit=true`
