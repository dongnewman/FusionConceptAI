# v4 开放式演化、Deep-QD 与踏脚石保存

## 1. 目标

本模块解决贪心漏斗无法跨越低分中间态的问题。它不寻找单一“最高总分”候选，而是在行为空间内持续维护多条机制谱系、当前成活者、失败前沿和潜在踏脚石。

## 2. Genotype 与 phenotype

- genotype：三个 Genome 的版本化、类型化程序/图表示；
- phenotype：经 candidate-bound 求解得到的行为描述和证据状态；
- lineage：从父代到后代的 typed edit trace；
- behavior descriptor：不含装置 family 的物理/因果行为向量。

建议的 descriptor 轴包括：

- 状态和算子数量；
- 守恒账户秩与能量转换路径；
- 区域邻接、因果环秩和接口结构；
- field-topology invariants；
- 对称结构与破缺方式；
- actuator/sensor/control 的可控与可观测结构；
- 主要失败阶段和失败机理；
- evidence depth。

descriptor 的每一轴必须可解释、可重算，并声明来自编译结果还是求解 evidence。不可用值为 `null/unknown`，不得填零。

## 3. DeepQDArchiveV4

每个生态位不只保留一个 incumbent，而保留最多 `K` 个不同角色；v4 初始建议 `K=8`：

- 2 个同 scope 内质量较优；
- 2 个 genotype/lineage 距离较大；
- 2 个失败机理或 evidence 路径不同；
- 1 个不确定性较高；
- 1 个 reservoir-sampled 长期保存。

候选只在相同 mission、hard-gate depth、evidence level 和 comparison scope 内比较质量。不同 cell 之间不做统一总分淘汰。

生态位实现优先使用稀疏哈希或 CVT；不得为高维 descriptor 建立完整规则网格。

## 4. 可行/不可行双种群

维护两个互相迁移的种群：

- `FeasiblePopulationV4`：在当前声明 stage 通过全部 required gate；
- `InfeasibleFrontierV4`：没有无解证书、具有修复或新颖价值的失败候选。

从不可行到可行的迁移必须经过重新编译和独立求解。从可行候选产生的失败后代不抹除父代 evidence。

## 5. 类型保持的演化算子

### 5.1 小尺度变异

- 替换类型相容算子；
- 增删一个基项或调节一个系数；
- 调整接口、边界或控制参数；
- 重连类型相容的因果边；
- 改变有限运行点或故障场景参数。

### 5.2 结构变异

- 区域分裂或合并；
- 添加/移除闭合因果回路；
- 添加新的 source–conversion–sink 路径；
- 改变场源、边界或接口表达；
- 增删传感器—估计器—执行器闭环。

### 5.3 开放式变异

- 模块复制后分化；
- 类型化子图 crossover；
- 中性漂移；
- 改变完整机制 motif 的 macro-mutation；
- 从长期休眠谱系复活后重新组合。

每个算子必须声明影响的 Genome、前置条件、失效条件和需重跑的 evidence stages。

## 6. Multi-emitter 调度

v4 初始 campaign 采用多个 emitter，共享档案但有独立最低预算：

| Emitter | 目标 | 初始预算建议 |
|---|---|---:|
| novelty emitter | 覆盖新行为生态位 | 25% |
| failure-frontier emitter | 修复接近硬门的候选 | 20% |
| MCTS emitter | 完成多步程序结构 | 20% |
| local CMA/BO emitter | 优化已知 basin 的连续参数 | 15% |
| generative emitter | 学习组合式候选分布 | 10% |
| random/revival emitter | 抗共同偏差和复活 | 10% |

比例是预注册起点，不是物理常数。后续可由 bandit 调度，但任何 emitter 不得低于 manifest 规定的预算下限，避免搜索模式永久灭绝。

## 7. 父代选择

禁止只从当前最高质量候选中选父代。父代队列按 emitter 分开：

- novelty emitter 按行为距离和低访问 cell；
- failure emitter 按可修复 margin 和失败多样性；
- local emitter 按同 cell 的 Pareto improvement；
- random/revival emitter 使用可复放 reservoir sampling；
- MCTS/generative emitter 使用各自策略，但仍受 typed compiler 约束。

所有选择必须记录 selection probability 或确定性排序依据，以支持偏差审计。

## 8. 原创性边界

档案可以声明：

- internal structural novelty；
- bounded physical-behavior novelty。

不得仅凭档案距离声明外部文献新颖性、专利性、不侵权或 FTO。外部检索只能作用于少量硬门成活候选，并生成独立证据。

## 9. 停止与重启

若连续两个冻结批次出现以下情况，应停止扩规模并重启或修复：

- 新增行为 cell 为零；
- 新增 capability-cell hard-gate coverage 为零；
- 大多数 proposal 是 semantic/solver-input cache duplicate；
- emitter 退化为同一谱系；
- 假阴性审计超阈值；
- provider gap 主导结果，搜索新增结构无法产生新 evidence。

重启保留 grammar、proof certificates、evidence 和全局档案，但可更换初始前缀、descriptor tessellation、mutation mix 或随机流。

## 10. 验收测试

1. 每个 cell 可同时保存不同谱系的多个候选。
2. 低分中间态可在多步变异后产生更深成活者。
3. 任一 emitter 都不会因短期表现被分配为零。
4. 搜索不读取 family/name 作为 descriptor 或父代选择特征。
5. 搜索分数不会写入 EvidenceEnvelope。
6. 随机流、谱系、算子和档案替换可确定性 replay。
7. 休眠和失败候选可以被复活，`proof_pruned` 候选不能被绕过证书直接复活。

