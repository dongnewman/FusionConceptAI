# AD-47 G3 source-binding readiness audit — independent review R1

日期：2026-09-15  
复核者：different `gpt-5.6-luna/high`  
结论：`changes_requested`  
范围：只复核 AD-47 三件 readiness 产品及其三项拟议工作单；未实现、未运行 Julia/DESC/mesh/solver/physics/search，未修改被审产品、源码、测试、fixture、核心清单或 task manifest。

## 定点与运行证据

复核根目录为 `D:\\006-Programing\\LMC\\FusionConceptAI`，观察 HEAD 为
`4b69f55f7f80240147a65a22809dc1207824dde2`。AD-47 根目录当前仍只有三个产品，三项未来产品目录均不存在；三项数量与工作单 ID 为 `8/16/6`，39 个任务的 manifest hash 仍为
`7d1700038f78dd1ea872cbc3fd6da29c5071596dae40d0c43b598b501195bae8`。

直接复核使用 `D:\\Users\\Newman\\anaconda3\\python.exe`、Python `3.13.5`，PID `64376`，UTC `2026-09-15T11:59:47.936463+00:00`，exit `1`。exit 1 是有意保留的合同发现：所有路径、数量、禁止边界、现状上限和可编辑性检查通过，但 `manifest.json` 的 work-order 条目没有结构化的 `inputs`、`outputs`、`depends_on`、`blocked_on`、`forbidden_scope`、`exit_gates`、`cleanup` 字段。原始 stdout 见 `review/direct_validation_stdout.json`；它不能替代物理或工程证据。

规划 validator 独立通过：31 个 markdown、497 个相对链接、39 个任务、DAG acyclic，exit `0`。AD-47 作用域 `git diff --check` exit `0`。两者只说明文档和工作树卫生。

## 现状边界核对

AD-47 对 G3 的事实边界基本正确：realization/control/binding precursors 仍是 local software contract/typed absence；没有 source-backed G3 declaration、source authority、actual binding、四轴 candidate attestation、feedback authority 或 physical realization。源码中的 bundle `candidate_hash` 不能提升为三层 `CandidateIdentityV1`；fixture、handle、测试通过和局部 hash 也不能提升 authority。fail-atomic CAS、编辑后旧 receipt 失效、失败保持 prior bytes/state/history 的要求被保留。R01–R10、T0/T1/T2、provider、mesh、solver、engineering、physical、search 和 L4 仍为 false/zero。

AD-45 的当前工作树状态已经变化：`independent_review_r2/manifest.json` 存在且为 `pass_limited`、`accepted=true`，其 A 单是 `dispatchable_after_parent_review=true`；但父任务尚未记录对 A 的正式接受。因此 AD-47 报告第 18 行仍写“R2 产品不存在”，manifest 的 `blocked_pending_AD45_repair_and_fresh_handle_review` 也已过时。正确边界应是：R2 独立复核已经存在，但在父审查接受、W3-A R2 输入冻结之前继续 blocked。该陈述必须修复后才能作为当前 readiness 记录。

AD-46 的 identity materialization 目录仍不存在，W2/W3 所需的 fresh G3 source identity、三层 identity 输入和 join 仍未闭合。AD-44 W3-A 的范围仍仅为 repository-source provenance。

## 三项工作单审查

数量本身有合理分解，暂未发现重复：8 件可覆盖 realization/control/binding/bundle 四个 scope 各一份 source-authority record 加一份 receipt；16 件是四个 scope 各四轴；6 件是 realization/control/binding 三个 child 各一份 join receipt 加一份 feedback-authority receipt。未来目录为空，故没有提前生成候选产品或 hash。

但是三项工作单目前不能作为可直接派发的完整机器合同：

1. `manifest.json` 只记录 `id/product_count/status/result_union/reviewer`，没有逐单 exact product path、每一类产品的 schema、输入输出字段、依赖、blocked 条件、禁止边、退出门和 cleanup。报告正文有相当多的中文说明，但不能替代可机械读取的派单合同，也没有明确 receipt 自身的 result/schema。应把这些字段补入 manifest，并保留报告为解释性文档。
2. AD47 说“复用 AD43 read-only contracts”，但 AD43 通用 `evidence_receipt_axis_schema_v1.json` 的 `common_fields.layer` 是 `enum(G1|G2)`。AD47 的 W2 却直接提出 realization/control/binding/bundle 四个 G3 scope 各四轴，没有定义合法的 G3 adapter、扩展版本或 scope-to-layer typed mapping。不能把 G3 scope 填进 G1/G2 枚举，也不能悄悄重造一个同名 schema。W2 派发前必须完成一个 additive 架构裁决：明确复用 AD43 哪些字段/哈希/负控，定义 G3 scope 的类型位置与新 contract ref/version，并证明不改写 AD43 冻结产品。
3. W1 的输入正文列出四个主要 G3 源文件，并概括提到三个 editable precursor，但没有逐项列出三个 child-editability source/test/receipt 的 locator、bytes/SHA 和 factory/source identity 输入。W1 的 8 件输出也没有把四个 authority record 的 schema 与四个 authority receipt 的 schema 分开定义。W3 同样只给出一个 join union，却未定义六个 receipt 各自的 result union、authority payload 和 absence/failure 字段。W1/W3 派发前应补足这些 exact closure，避免把 bundle record 重复当作 child authority 或把 feedback receipt 当作物理回代。

## 最早可派发边界

AD47 本身不能被接受为完成；结论为 `changes_requested`。修复 AD47 的时点陈述和结构化 manifest 后，若父任务正式接受 AD-45 A 且冻结 AD-44 W3-A R2 输入，最早可以只派发 W1 `AD47-G3-SOURCE-AUTHORITY-RECORDS`。W1 仍只能产生 `Present|Absent|Failed` software source-authority records；缺输入必须 typed absent/`terminal_deferred`，冲突必须 failed/`fail_closed`，不得生成 final identity 或 physical credit。

W2 必须等待 W1 的独立复核、AD-46/独立 G3 source identity inputs、显式 G2 `GenomeContractRef` 到 common `QualifiedRefV1` mapping，并先解决 AD43→G3 axis typed mapping。W3 必须继续等待 W1、W2、三层 identity/join 输入和 feedback target authority；其结果仍只能是 software join/feedback authority，不能关闭 inverse-realization 或父目标。

本复核没有授予任何 present、T0/T1/T2、provider、mesh、solver、engineering、physical、search、R01–R10 或 L4 信用。失败和当前 raw 收据保留在本复核目录；没有创建 task-owned scratch 或后台重计算。
