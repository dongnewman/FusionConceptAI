# v4 严格证明式剪枝与失败语义

## 1. 目标

本模块的目标不是尽可能多地删除候选，而是只永久删除“在已声明 grammar、bounds、mission 和完成规则下不存在任何合法完成”的候选前缀。

核心区别是：

```text
当前候选不利
≠ 当前候选的所有后代不可能有利
≠ 当前部分 Genome 不存在合法完成
```

只有第三种情况可以 `proof_pruned`。

## 2. PruneCertificateV4

每次永久剪枝必须有机器可验证证书：

```text
certificate_id
candidate_prefix_hash
grammar_hash
bounds_hash
mission_hash
proof_kind
unsat_core_or_bound
assumptions[]
checker_id_and_version
checker_result
affected_subtree_signature
replay_artifact_ref
```

任何缺少 checker replay 的剪枝只能转为 `dormant`，不能永久删除。

## 3. 允许永久剪枝的证书

### 3.1 结构与类型无解

- refinement/type 约束不可满足；
- 端口方向、张量阶或 function space 不可能匹配；
- required nonterminal 在 grammar 中没有任何合法 production；
- 自由度、约束和边界计数存在可证明矛盾。

### 3.2 量纲与守恒无解

- 单位方程不可满足；
- 守恒账户的必要源/汇在所有完成路径中都缺失；
- 接口账户出现无法配对的通量；
- 在有限上下界内，守恒残差的区间不包含零。

### 3.3 有界数学不可行

- interval arithmetic 证明约束区间无交；
- SMT/MILP/符号约束求解给出可复放 unsat core；
- 解析必要条件在完整声明域内被违反；
- 同一规范对象或同一 solver input 已存在，且本分支不产生新谱系信息。

“某个数值求解器没有收敛”“短轨迹逃逸”“代理预测通过率低”不属于证明。

## 4. 不允许永久剪枝的情况

| 情况 | 状态 | 后续处理 |
|---|---|---|
| 低保真 hard gate 不利 | `physical_fail` at scope | 保留谱系，可产生修复后代 |
| 数值不收敛 | `numerical_fail` 或 `unknown` | 重试/换适用 provider/休眠 |
| provider 缺失 | `terminal_deferred` | capability gap queue |
| 代理预测差 | `dormant` | 保留随机复活概率 |
| 当前复杂度过高 | archive non-elite | 可做稀疏化后代 |
| 新增机制尚未形成闭环 | `prefix_incomplete` | 允许多步 MCTS/演化完成 |

## 5. 失败前沿与不可行种群

所有未被证明无解的失败候选进入 `InfeasibleFrontierV4`，记录：

- 最早失败阶段；
- 失败 gate 和 margin；
- 对应 evidence scope；
- 可修复的 Genome 层；
- 推荐 typed edits；
- 新颖性和谱系贡献；
- 是否曾产生成功或更深后代。

不可行种群不参与可信候选排名，但可以按“可修复距离、行为新颖性、谱系贡献、证据不确定性”获得繁殖预算。

## 6. 休眠与复活

`DormantArchiveV4` 保存当前不值得继续求解、但没有无解证书的候选。每个 campaign 必须预留复活预算，用于：

- 随机抽取旧候选；
- 抽取少访问生态位；
- 抽取代理模型意见分歧大的候选；
- 在 provider/grammar 升级后重编译 deferred 候选；
- 对低保真淘汰样本做高保真假阴性审计。

休眠不是删除，也不是物理失败声明。

## 7. No-good learning 的作用域

经证明的 unsat core 可以生成 no-good rule，但必须绑定：

- grammar 和 bounds 版本；
- mission；
- 前缀语义，不使用 candidate ID；
- 适用变量域；
- proof checker 版本。

grammar、bounds、mission 或完成规则改变后必须重新验证，不能沿用旧 rule 永久剪枝。

## 8. 假阴性审计

每一批次从软淘汰集合中按预注册比例抽样，执行更高一级真实求解。记录：

```text
soft_rejected_count
audited_count
unexpected_survivor_count
false_negative_interval
by_gate / by_cell / by_model
```

若假阴性上置信界超过 campaign 阈值：

1. 暂停扩大规模；
2. 降低软筛选强度；
3. 增加复活与随机审计预算；
4. 重新校准代理或低保真门；
5. 不删除已经记录的反例。

## 9. 与物理硬门的关系

物理 hard gate 对“这个确切 physical subject 在这个 evidence scope 下能否晋升”具有约束力；Proof Authority 对“整个完成子树是否无解”具有约束力。两者不可混用。

一个确切候选可以 `physical_fail`，但其父前缀仍可生成不同 realization、运行点或控制后代。只有证书覆盖整个允许域，父前缀才可 `proof_pruned`。

## 10. 验收测试

1. 每个 `proof_pruned` 都能独立 replay。
2. 删除代理分数不改变永久剪枝集合。
3. 数值不收敛不会生成无解证书。
4. provider 缺失不会生成物理失败或无解证书。
5. 修改 bounds/grammar 后旧 no-good 自动失效并重审。
6. 失败前沿和休眠档案可恢复、可产生后代。
7. 假阴性审计结果能实际调整下一批预算。

