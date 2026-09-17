# AD-30 T0 LocalV1 R21 runtime receipt

日期：2026-09-18（Asia/Shanghai）
范围：仅归档既有 `runs/agent_local_up1_04a_vnext_t0_20260918_r21_wrapper/` 的
`run.json`、`stdout.txt`、`stderr.txt`，并记录其当前输入绑定；未修改源码、测试、
fixture、static QA 或索引，未提交，未再次运行 Julia/DESC。

## R20 fail lineage and R21 repair

R20 wrapper/inner exit 为 `1/1`。唯一 T0 R20c 错误是测试构造错误：旧 helper
用 `id == "g1-residual" ? :G1 : :G2` 推断层级，导致正例 `g1-source` 被标为
`:G2`，产品正确 fail-closed 为 `feedback_target_ref_unknown`；同时 R20c 复用
旧 refs，未检验不同 fresh identity 的 source/declaration 映射。

R21 仅修复测试构造：helper 支持显式 `target_layer` 并校验 `:G1/:G2` 与 id
前缀一致；正例分别使用 G1 source ref、G2 declaration ref，并以 rekey 后的
fresh declarations 验证 fresh-ref 映射。产品 runtime mapping 未改动。

## R21 runtime result

- wrapper exit `0`；inner Julia exit `0`。
- 七个分组合计 `202/202`：`32/32`、`29/29`、`34/34`、`37/37`、`22/22`、
  `15/15`、`33/33`。
- frozen post-check：`17/17`。
- stdout 明确记录 `VNEXT_T0_LOCAL_STATIC_TEST_DEFINED=true` 与
  `VNEXT_T0_LOCAL_JULIA_OR_DESC_EXECUTED=false`。

## Raw receipt hashes

| artifact | bytes | SHA-256 |
|---|---:|---|
| `run.json` | 4974 | `eafaec0b1d88145b3fee65ed196eecebb03090ad9ab2671ed4ad2c8d4c0335da` |
| `stdout.txt` | 1328 | `a893a5fac7ff728f7658fdbfaea963cd8826610f1359c746175872121fc1b0c4` |
| `stderr.txt` | 246 | `3673c8cd9f5ffe4f18ed3800cf65817526b16a41fea323f14e63da166d77d00b` |

stderr 仅包含两条边界信息，均非测试失败：`fatal: path
'tmp/t0_local_r3_source_edit/G1_DiffusionDeclarationV1.edited.jl' exists on disk,
but not in 'HEAD'`，以及 `warning: ... LF will be replaced by CRLF the next time
Git touches it`。

## Claim boundary

`accepted=false`，`claim_ceiling=contract_only`，`screen_only=true`。本 receipt
不产生 T1/T2、provider、mesh、solver、physical 或 R01-R10 credit；亦不证明
scientific/engineering acceptance。`julia_executed=false`、`desc_executed=false`
按 wrapper receipt 的声明保留。
