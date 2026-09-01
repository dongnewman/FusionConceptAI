# v4 成活者稀疏化、最简性与 Pareto

## 1. 职责

本模块只处理已经通过声明硬门的候选。它回答“在相同 grammar、bounds、mission、evidence level 和 comparison scope 内，哪些实现非支配、哪些部件或数学基可以删除”，不回答全局最简单装置是什么。

## 2. 准入条件

候选进入本模块必须同时满足：

- required stage hard gates 已有 candidate-bound `pass`；
- 没有用 `unknown` 或 `terminal_deferred` 代替 pass；
- physical subject、scenario 和 evidence hashes 完整；
- comparison scope 相同或存在正式可比性证明；
- 复杂度指标可从确切 realization 重算。

未通过硬门的候选可以进入 failure-repair 稀疏化实验，但不得与 survivor Pareto 混在一起，也不能获得最简可信声明。

## 3. 两类“基”同时稀疏化

### 3.1 Genome 结构基

- 区域、接口和因果边；
- 场源、组件和资源网络；
- 传感器、估计器、执行器和控制回路；
- 冗余 source/sink、支撑和保护路径。

### 3.2 数学表达基

- Fourier/B-spline/current-potential 系数；
- 边界、剖面、体电流和场源基；
- 控制模态、时序和故障策略基；
- 数值离散中属于设计自由度而非求解精度的基。

不得只删除物理部件而保留无消费系数，也不得只压缩系数而不审计结构复杂度。

## 4. 依赖闭合的消融

一次消融是 typed edit，不是输出文件后处理：

1. 选择待删除 gene/subgraph/basis term；
2. 计算依赖闭包；
3. 删除或重新绑定所有消费者；
4. 重新编译三种 Genome 组合；
5. 生成新 `physical_subject_hash`；
6. 重跑所有受影响 hard gates；
7. 只有新候选独立通过后，才承认复杂度下降。

如果删除后通过依赖于旧候选 evidence，结果无效。

## 5. 复杂度坐标

至少分别记录：

- active region/interface/operator 数；
- 物理组件和独立电源数；
- 导体总长度、最大/积分曲率和最小间距；
- 材料、支撑、屏蔽、热沉和低温质量；
- source/actuator 峰值和总容量；
- 传感器、估计器、控制器状态和 hybrid mode 数；
- 维护、装配和故障恢复复杂度；
- active basis 数、阶数和条件数；
- 不确定性裕度与证据成本。

这些坐标保持独立，不预设万能加权和。

## 6. ScopedParetoArchiveV4

档案键：

```text
mission_hash
grammar_hash
bounds_hash
capability_cell
comparison_scope
hard_gate_depth
evidence_level
scenario_scope
```

档案值保存非支配候选及证据引用。一个候选只有在所有 required 维度不差且至少一维更优时才支配另一个候选。`unknown` 维度不允许被当作优于已知不利值。

不同 scope 的候选可以并列展示，但不得宣称相互支配。

## 7. 鲁棒性优先于名义最小

若删除部件或基项导致：

- scenario failure 增加；
- UQ 下 margin 跨零；
- 控制可观测/可控性下降；
- 数值条件数恶化；
- provider independence 或 validation obligation 无法满足，

则该消融不能被称为更简单的可信候选。最简性比较应使用满足声明鲁棒性门后的 realization，而不是名义 operating point。

## 8. 与搜索的反馈

Pareto 结果可以向搜索器提供：

- 可删除 motif；
- 复杂度高但无收益的基项；
- 不同 cell 的稀疏 survivor seeds；
- robustness-sensitive components；
- 后续局部优化方向。

反馈只影响新 proposal。不得用后来的简化结果改写原候选 evidence 或 lineage。

## 9. 最简性声明模板

允许：

> 在 grammar G、参数界 B、任务 M、scenario scope S、证据等级 E 和 comparison scope C 内，该候选属于当前通过全部 required hard gates 的非支配最简实现集合。

禁止：

> 这是全局最简单、最优或最可建造的聚变装置。

## 10. 验收测试

1. Pareto 输入全部通过同 scope 硬门。
2. 删除任一 active gene 后均重新编译和重算受影响 evidence。
3. 结构基和数学基同时计入复杂度。
4. 不同 evidence level 不相互支配。
5. `unknown` 不被转换为有利数值。
6. 顺序变化不改变非支配集合。
7. 输出声明包含 G/B/M/S/E/C 六项边界。

