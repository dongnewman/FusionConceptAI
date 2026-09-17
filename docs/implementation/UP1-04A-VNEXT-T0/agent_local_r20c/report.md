# AD-30 T0 LocalV1 R20c G3 feedback and source-edit boundary

日期：2026-09-18（Asia/Shanghai）
范围：仅 G3 feedback candidate projection、source-edit child policy、外层 feedback target-ref 映射；无 Julia/DESC/provider/mesh/solver 运行，无提交。

## 实现

- G3 feedback normalization 与 semantic rebind 先重建并严格校验原始候选：`upstream_authority`、`feedback_targets` 及其 authority candidate projection 必须逐项与原始声明一致。
- 只允许 `missing` / `historical_absent` 且完全无 materialized authority fields 的 authority 确定性换绑到 fresh candidate；`actual`、`stale`、`contradictory` 或带物化 authority 的记录 fail-closed。
- source-edit 对 present G3 children 不再盲换 candidate；缺少 fresh candidate-bound receipt 时返回 `present_g3_child_requires_fresh_receipt`。`terminal_deferred` / `typed_absent` child 只有在 candidate、kind、status、receipt hash、source path 自洽后才换绑。
- 外层 `VNextT0LocalFeedbackV1` 保留旧 target-ref kind：旧 `source_ref` 映射 fresh `source_ref`，旧 `declaration_ref` 映射 fresh `declaration_ref`；unknown/ambiguous refs fail-closed，body hash 在换绑后重算。

## 静态 QA

命令：

```text
python -B docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py
```

结果：exit `0`，`status=pass`，`accepted=false`，`claim_ceiling=contract_only`，`screen_only=true`，`r01_r10_credit=false`，`julia_executed=false`，`desc_executed=false`。

测试文件增加 R20c 正负例、确定性重放、source-vs-declaration mapping、foreign/stale/contradictory/materialized authority 和 present-child fail-closed 控制；按本任务要求未运行 Julia 测试。

## 当前文件哈希

| path | bytes | SHA-256 |
|---|---:|---|
| `src/GenomeV5/Integration/VNextDeclarationTransportLocalV1.jl` | 96310 | `3f3446ec7b641470d1bb45cefed814463aca1af424a858945e09cbb1330ffcaa` |
| `test/GenomeV5/Integration/vnext_declaration_transport_local_v1_tests.jl` | 71867 | `b43917ddb8fb74e1b7e5a40a0d67046160b35468ed8e144ef79e35fe028095ba` |
| `docs/implementation/UP1-04A-VNEXT-T0/static_qa_local_v1.py` | 24915 | `9442a6ac5c7c129a4528374e7dea386d2c1d6997a896d68a529b9ee924912796` |

## 剩余风险

- 本轮未做 Julia 语法/运行验证；root 需在不同 Luna 环境串行执行 focused test。
- 现有 `VNextT0LocalChildPresentV1` 没有 fresh receipt 字段，因此 present G3 child 当前只能保守 fail-closed，不能宣称其已完成 candidate-bound 重建。
- 该切片仍是 local contract-only / screen-only；不产生 R01-R10、物理、provider、mesh 或 solver credit。
