# AD-47 acceptance

日期：2026-09-15  
工作单：`AD-47-G3-SOURCE-BINDING-READINESS-AUDIT`  
decision：`accepted_limited`  
accepted_scope：`g3_source_binding_readiness_and_workorder_topology_only`

## 裁决

root 接受 AD47 R2 的有限架构审计范围。该接受只确认 G3 source-backed readiness 边界、可编辑 precursor 的证据上限和 W0–W3 工作单拓扑；不接受任何 source-backed G3 declaration、candidate binding、四轴 candidate attestation、feedback physical closure 或父目标结果。

R1 `changes_requested`、R2 `pass_limited` 和本 acceptance 均保持 append-only。三份冻结产品、所有 reviews、W0–W3 工作单输出、源码、测试、fixture、`task_manifest.json` 均未修改。

## 冻结产品

| 产品 | bytes | SHA-256 |
|---|---:|---|
| `report.md` | 14853 | `f416bc0945c6fa317c9425c82b56051a56d5ded55681c309d17b2883cbf18fe8` |
| `manifest.json` | 20011 | `f8e59a6e0479090aeaf4a654d8cbb2ad922773606fd7000b17d802146e6698a2` |
| `cleanup_inventory.md` | 840 | `d701d00525b4527db6671d50c9c409b533888a0b418d38dbccc0aeacd240fb17` |

AD47 R1 的 `changes_requested` 报告和 raw sidecars 保留在原目录。R2 修复已由不同 Luna 以 `pass_limited` 复核；其结构化工作单字段、AD45 A `59/59`、AD44 W3-A frozen provenance 和四个工作单的 exact product topology 已由本 acceptance 重新核验。

## 调度裁决

- `AD47-G3-AXIS-SCHEMA-VERSIONED-EXTENSION`（W0，4 件）批准最早派发。它只能产生 additive、G3-specific、versioned axis schema/adapter；必须保持 AD43 产品只读，显式 `layer=G3`，不得 alias `G1|G2`。
- `AD47-G3-SOURCE-AUTHORITY-RECORDS`（W1，8 件）批准与 W0 并行派发。它只覆盖当前 working-tree 的 software provenance；四个 G3 scope 允许输出 typed absence/`terminal_deferred`，不产生 checked-present authority。
- `AD47-G3-CANDIDATE-BOUND-AXIS-ATTESTATIONS`（W2，16 件）继续 `blocked`，依赖 W0、W1、独立 source/identity reviews、显式 G2 mapping 和外部 identity-owner 输入。
- `AD47-G3-CHILD-BINDING-FEEDBACK-JOIN`（W3，6 件）继续 `blocked`，依赖 W0–W2、child source/test/receipt closure、feedback target authority 和 resource/thermal/implementation-error ledger。

不同 Luna/high 实现与不同 Luna/high 独立复核仍是每个工作单的退出门；重计算、provider、mesh、solver 和物理执行不因本裁决启动。

## 信用边界

G3 realization/control/binding precursors 和 focused tests 仍是 local software contract/typed-absence evidence，不是 present source authority。AD45 common handle 仍是 `accepted_limited` 临时 join handle，不是最终 candidate identity。

candidate/declaration/final identity hash、T0/T1/T2、provider、mesh、solver、engineering、physics、search、R01–R10 和 L4 credible count 均保持 `false`/`0`。文档、测试、代理结论、规划校验和 runner exit code 均不替代物理或工程证据。

## 验证

直接 JSON/hash/path/control、39-task DAG、plan validator 和 scoped diff 的原始收据位于 `status_sync_r1/raw/**`。本 acceptance 未运行 Julia/DESC/mesh/solver/physics/search，也未清理既有 dirty worktree；只清理 task-owned temporary files（本单为 0）。
