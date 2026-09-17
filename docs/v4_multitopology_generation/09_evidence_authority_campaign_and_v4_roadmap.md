# v4 最终证据 authority、campaign 与实施路线图

> 2026-09-14 路线更新：UP6 最终关账，authority 约束贯穿全部阶段。新的实施顺序为 UP0–UP6，历史 V4-P0–P6 顺序已被本次授权替代。 共同规范以 [00](00_normative_contracts_and_state_model.md)、[总纲](README.md) 和 [16 工作单](16_execution_work_orders.md) 为准。本文是设计合同，非实现状态报告。

## 1. 最终 authority 的职责

`FinalWholeDeviceAuthorityV4` 是唯一可以发出终局 candidate disposition 的模块。它不重新运行搜索或修改物理结果，只审计全部义务是否闭合、证据是否在适用域内、状态是否一致，并生成受限声明。

## 2. CredibleCandidateEnvelopeV4

```text
candidate_ref
physical_subject_hash
mission / grammar / bounds / scenario scope
genome_contract_refs_and_hashes
terminal_disposition
claim_ceiling
passed_obligations[]
failed_obligations[]
unknown_obligations[]
unsupported_obligations[]
not_applicable_proofs[]
numerical_vvuq_status
validation_vvuq_status
engineering_status
pareto_scope_and_rank
novelty_claim_scope
all_evidence_refs[]
authority_version_and_hash
```

## 3. 终局分类规则

### 3.1 credible_within_scope

仅当：

- scope 内所有 required obligations 都有适用、收敛、候选绑定 evidence；
- hard gates 全部通过；
- required scenarios 全部满足；
- numerical VVUQ 满足声明；
- validation/engineering 状态达到该 claim 所需等级；
- 没有 unresolved terminal-deferred；
- Pareto/最简性声明包含完整边界。

### 3.2 physical_fail

至少一个 required quantity 在 provider 适用域内成功计算并违反硬门。必须说明精确作用域，不把一个 realization 的失败扩展为整个 grammar 无解。

### 3.3 numerical_fail

required 数值协议未满足，例如不收敛、网格不一致或双代码差异超阈。不得伪装为物理失败。

### 3.4 unknown

适用计算或 validation 缺少充分 evidence，或证据冲突未解决。

### 3.5 unsupported

只有在完整 terminal closure 审计后，required obligation 仍无合法 provider/物化路径、歧义或超域，才由本 authority 发出。中间 `terminal_deferred` 不等于终局 unsupported。

## 4. 可信声明层级

建议使用显式 claim ladder：

| 等级 | 允许声明 |
|---|---|
| L0 | grammar 内结构合法、可编译 |
| L1 | 指定低保真物理门通过 |
| L2 | candidate-bound 平衡/稳定/输运义务达到声明深度 |
| L3 | integrated numerical whole-device closure + numerical VVUQ |
| L4 | 工程场景、独立验证证据达到声明协议 |
| L5 | 与具体声明匹配的实验/工程 qualification；声称建成且实测正净输出必须有相应装置测量证据，不由搜索自动产生 |

“最简可信候选”必须同时写明 L 等级和 scope，不能只写 `pass`。

只有 L4 及以上才允许称为“证据边界内的可信物理装置候选”；L3 及以下必须称为结构候选、低/中保真物理候选或整装数值候选。若没有 L4 结果，可信物理装置候选数量必须报告为 0。L5 才能支持更强的实验或工程 qualification 声明。

## 5. 新颖性 authority

分开记录：

- internal structural novelty；
- bounded physical-behavior novelty；
- external literature similarity audit；
- patentability/FTO 专业评估。

前两项可以由系统在声明 archive 和 descriptor 下计算；后两项是独立工作流。任何内部哈希唯一都不能自动提升外部新颖性声明。

## 6. Campaign manifest

每次正式 campaign 在运行前冻结：

- 三种 Genome contract refs/hashes；
- grammar、bounds、mission 和 scenario scope；
- compiler/proof/search/provider/authority 版本；
- behavior descriptors、cell 定义和 archive 深度；
- emitter 预算和最低份额；
- stage budgets、promotion policy 和 random audit；
- hard gates、容差和 applicability；
- retry、recovery、cache 和 stop rules；
- claim ceiling；
- 随机种子和 shard plan。

运行中变更任一规范字段必须创建新 campaign，不得修改已冻结 manifest。

## 7. 可恢复执行和严格合并

- shard 输入由 frozen manifest 内容寻址；
- 每个结果独立写入，不共享可变聚合状态；
- merge 验证 grid/budget/schema/provider hashes；
- 空 shard、损坏 JSONL、重复 solver input 和跨 grid 结果必须拒绝；
- stage frontier 只在全部 shard 终态后生成；
- 恢复执行复用已完成 evidence，不重复记账；
- 并行完成顺序不得影响选择结果。

## 8. 数量报告

每份报告分别列出：

- raw proposal actions；
- unique candidate prefixes；
- proof-pruned prefixes；
- compiled semantic structures；
- active/dormant/failure QD members；
- materialized physical subjects；
- unique solver inputs；
- 各 stage pass/fail/unknown/deferred；
- integrated executions；
- terminal dispositions；
- 各 evidence level 的 credible candidates。

这些数量不可相加后称为“装置数”。

## 9. 新实施路线与进入条件

唯一当前路线是 [README 的 UP0–UP6](README.md)，具体依赖见 [16 工作单](16_execution_work_orders.md) 和 [task_manifest.json](task_manifest.json)。旧版 V4-P0–P6 搜索优先顺序已归入 [历史快照](../implementation/history/20260914_planning_baseline/09_evidence_authority_campaign_and_v4_roadmap.md)，不得用于现行派单。

1. UP0 审计当前源码、脏文件、运行恢复和版本合同。
2. UP1 补齐三 Genome 的语义/适用性和最小组件核，采用显式版本迁移。
3. UP2 将声明编成方程、离散与耦合系统，复用成熟数值算法。
4. UP3 验证不同合法模块组合可自动执行，并有留出组合与负控制。
5. UP4 实际逆设计源/硬件，把实现误差、供能、热、结构和控制回代主物理；完成真实参考隐参逆恢复。
6. UP5 接入条件 e-graph、丰富结构编辑和物理反馈；比较有界 campaign 后再扩规模。
7. UP6 完成全部适用物理/工程、整装净输出、VVUQ、原创性和独立复放，按原 R01–R10 关账。

每个阶段的 accepted 只覆盖其协议声明的能力域。阶段完成不隐含装置可信；最终 authority 不能因排期已结束而填补 evidence 缺口。扩大搜索前要求组合执行、逆实现回代和真实反馈已通过；软件/模型问题占主导时先修复能力。

## 10. v4 正式验收

1. 三种 Genome 以明确版本引用；新增语义经过迁移与独立验收，历史候选、哈希和 evidence 未被原地重解释。
2. 无 family/name/ID 路由、门控和晋升。
3. 永久剪枝 100% 有独立可复放证书。
4. Deep-QD、失败前沿、休眠复活和 multi-emitter 可恢复。
5. AI/代理输出不能进入 evidence 或 terminal disposition。
6. 三种边界纵切片走相同合同和 authority。
7. stage frontier 合并与 shard 顺序无关。
8. 每个物理变化重跑全部受影响 hard gates。
9. Pareto 只发生在硬门后和相同 scope 内。
10. integrated solve、numerical VVUQ、validation VVUQ 和工程证据分离。
11. 只有最终 authority 发出终局 unsupported/credible。
12. 所有数量按 proposal、结构、physical subject、solver input、survivor 和 credible level 分层报告。

## 11. 当前证据边界

本目录是 v4 设计大纲。文档完成不代表代码已实现、provider 已覆盖、campaign 已运行，也不改变项目当前可信完整物理装置仍需 candidate-bound 整装证据的事实。
