# v4 多保真硬物理 frontier

## 1. 目标

本模块把一次性流水线改为逐层冻结、合并后晋升的 `StageFrontierV4`。每层只消费上一层明确 admitted 的候选和本层 evidence request；并行 shard 不能因先完成而抢走晋升预算。

## 2. 通用 stage ladder

```text
S0 compiled/materialized
→ S1 analytic or certified bounds
→ S2 field/source realization
→ S3 topology-dependent orbit, Poincare, end-loss or equivalent
→ S4 finite-pressure/equilibrium closure
→ S5 applicable stability obligations
→ S6 transport/reaction/power closure
→ S7 engineering/control scenario closure
→ S8 integrated high-fidelity and VVUQ
```

这是义务层级，不是装置 family 路线。某阶段 `not_applicable` 必须有 applicability proof；required 但缺 provider 时 `terminal_deferred`。

闭合场可以使用 P32→P64→P128 的证据升级；开放或混合边界候选使用其声明的轨道、端损失和边界通量义务。二者只有在 comparison scope 相同且证据义务可比时才进入同一 Pareto。

## 3. StageFrontierV4

每层产生不可变 frontier：

```text
campaign_id / batch_id / stage_id
input_manifest_hash
frozen_selection_policy_hash
candidate_evidence_refs[]
stage_outcomes[]
admitted_refs[]
dormant_refs[]
failure_frontier_refs[]
terminal_deferred_refs[]
not_applicable_proofs[]
budget_used / retry_used
merge_hash
```

所有 shard 完成或明确失败后统一 merge，再执行 selection。禁止先完成者先晋升。

## 4. 硬门规则

- 每个 gate 有作用域、单位、阈值来源、适用域、数值容差和证据等级；
- required gate 不能被其他指标补偿；
- unavailable metric 序列化为 `null`，不使用 `Inf` 或虚构零值；
- incomplete trace 不允许计算需要完整轨迹的二次指标；
- 物理变化后重跑全部受影响 gate；
- 后处理指标不能替代 governing residual closure；
- 一次低保真通过只允许晋升到下一 evidence request，不授予高层物理信用。

## 5. 晋升不是永久淘汰

本层 outcome 决定这个确切 physical subject 是否进入下一层，不决定其父前缀是否永久删除：

- `pass`：可竞争本层晋升额度；
- `physical_fail`：进入失败前沿，可产生修复后代；
- `numerical_fail`：进入数值诊断/重试额度；
- `unknown`：保持证据缺口，不当作 pass/fail；
- `terminal_deferred`：进入 capability gap queue；
- `not_applicable`：凭 proof 跳过该义务，但不增加信用。

## 6. 多保真与 rank reversal

低保真仅用于预算分配。为防止低保真排序错过高保真优解：

1. 每层保留 behavior-cell quotas，而非只取全局最高分；
2. 预留不确定性和随机审计额度；
3. 从低保真 soft rejects 中抽样进入下一层；
4. 测量低/高保真 rank correlation 和 false-negative interval；
5. correlation 不足时减少代理淘汰，扩大随机/多样性晋升；
6. 不允许高保真结果回写修改历史低保真 outcome。

## 7. 基阶升级

基阶升级必须由失败机理驱动：

- 表达残差或场形不足：允许增加场/边界/电流势基；
- 热排、结构、电源容量不足：优先修改 realization/control，不增加无关场基；
- provider 不支持：保持 deferred，不产生升阶信用；
- 升阶后残差、条件数和 heldout behavior 无改善：停止该升阶路线；
- 每次升阶创建新 physical subject 和 solver input hash。

## 8. 预算分层

预算按 `budget stratum → exact capability cell → behavior cell` 三层轮转：

1. budget stratum 确保不同计算成本/义务组都有资源；
2. exact capability cell 保持执行路由严格；
3. behavior cell 防止少数高密度构型垄断。

每层 manifest 固定：探索、晋升、异常/重试、基阶升级、随机审计和 provider-gap 预算。不同预算不能在运行中私自借用。

## 9. 建议的首轮规模

这是设计预算，不是成活率或可信度承诺：

| 层 | 目标上限 |
|---|---:|
| compiled mechanism/combined prefixes | 4,096 |
| Deep-QD active archive members | 约 2,048（256 cells × K=8） |
| materialized field/realization inputs | 2,048 |
| first candidate-bound physics | 512 |
| middle fidelity | 128 |
| long-horizon/finite-pressure | 32 |
| integrated high fidelity | 8–16 |

若前层没有成活者，不得为了填满下层名额放宽 gate。

## 10. 停止规则

连续两个冻结批次若没有增加新的 required-gate survivor capability/behavior cells，或新增结果主要为 solver-input cache hits，则停止扩规模并诊断：

- grammar 是否产生不可物化义务；
- provider portfolio 是否缺口主导；
- realization 分布是否过窄；
- 低保真 gate 是否假阴性过高；
- 搜索是否谱系塌缩。

## 11. 验收测试

1. shard 顺序不改变 merge 和 promotion。
2. 每层输入来自冻结上一层 frontier。
3. 不适用均有 proof；未执行不默认 pass。
4. 不同 topology 使用声明义务而非 family 路由。
5. random audit 能检测低/高保真 rank reversal。
6. 基阶升级能追溯失败机理。
7. 中间 stage 永远不发出终局可信声明。

