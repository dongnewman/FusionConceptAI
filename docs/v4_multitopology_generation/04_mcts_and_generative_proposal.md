# v4 MCTS 多步探索与生成式候选提议

## 1. 职责边界

本模块用于探索“单步看起来无利、完成多步组合后才形成新机制”的候选。MCTS、代理模型、GFlowNet 或 LLM 都只有生成 `ProposalEnvelopeV4` 的权限；它们不能产生 evidence、跳过编译、修改 hard gate 或授予晋升。

## 2. 部分 Genome 搜索树

```text
state s       = CompiledCandidatePrefixV4
action a      = 一个合法 typed edit 或 production
child s'      = 重新编译后的候选前缀
terminal leaf = 在当前 completion policy 下可物化的 Genome bundle
observation   = 编译、低/中/高保真 evidence 的不可变摘要
```

树节点使用 canonical prefix hash。不同 action 序列到达同一 canonical prefix 时合并为 DAG 节点，同时保留多条 lineage，避免重复展开。

## 3. Progressive widening

高分支 Genome 不预先列举所有 action。节点可展开动作数满足：

\[
|A(s)| \le kN(s)^\alpha, \qquad 0<\alpha<1.
\]

新增 action 来源按冻结配额混合：

- grammar 中未访问 production；
- novelty emitter 建议；
- failure repair rule；
- generative model 提议；
- 随机合法 production。

任何来源都必须通过同一个 typed compiler，不允许模型专用语法捷径。

## 4. 树策略

v4 不使用单一物理总分。每个 target behavior cell 和 stage 分别维护价值统计。一个可用的调度形式是：

\[
U(s,a)=Q_{scope}(s,a)
+c\sqrt{\frac{\log N(s)}{1+N(s,a)}}
+\beta U_{model}(s,a)
+\gamma D_{cell}(s,a)
-\eta \widehat C(s,a).
\]

其中：

- `Q_scope` 只来自相同 evidence scope 的后代结果；
- `U_model` 是认识不确定性，只用于探索；
- `D_cell` 是新生态位或低访问区域增量；
- `C` 是预计计算成本。

这些量用于选 action，不是 candidate physical score。硬门仍不可补偿。

## 5. 回传语义

回传分别记录：

- 是否到达新的 compiled semantic cell；
- 是否产生新的 solver input；
- 最深 evidence stage；
- 各 stage 的 scoped pass/fail/unknown；
- 是否发现新 proof certificate；
- 实际成本与预测成本；
- 后代谱系贡献。

不得把一个后代的高保真通过反向写成祖先的物理通过。祖先只增加“曾产生有价值后代”的搜索统计。

## 6. 代理模型

代理模型按任务拆分，不训练万能模型：

- 编译成功概率模型；
- stage-specific survival 模型；
- cost/runtime 模型；
- solver nonconvergence 模型；
- behavior descriptor/novelty 模型；
- false-negative calibration 模型。

训练数据必须包含失败、unknown、deferred 和随机审计样本。数据按 lineage、semantic cell 和时间做泄漏隔离，不能把同一 solver input 的副本分到训练与验证两侧。

预测必须返回不确定性和适用域。超出训练域时不允许自信外推，转入探索或随机审计队列。

## 7. GFlowNet 条件生成

GFlowNet 适合按多种高潜力模式生成组合对象，但 v4 不定义一个跨作用域总 reward。采用条件任务：

```text
P(genome completion |
  target_behavior_cell,
  requested_stage,
  failure_repair_class,
  mission,
  grammar_version)
```

训练 reward 只能使用调度性质，例如新 cell 插入、相同 scope 的 archive improvement、信息增益或成功编译；不得把未执行的物理预测写成通过证据。

启用条件：

- 已有足够多、分布可审计的真实编译和求解记录；
- holdout calibration 合格；
- 生成结果在标签擦除后不变；
- random/revival 通道仍保留；
- 每批生成结果仍全部经过编译与独立求解。

数据不足时，v4 先使用 grammar-guided mutation、MCTS 和 QD，不为了“使用 AI”提前训练高偏差模型。

## 8. LLM 的可选角色

LLM 可以：

- 提议一组 typed edit 意图；
- 解释失败谱系并生成 repair hypothesis；
- 从已有 motif 产生新的组合草案；
- 生成待编译的 grammar production 候选。

LLM 不可以：

- 直接写入正式 Genome 而不编译；
- 为缺失字段猜测物理默认值；
- 评价可行性或新颖性；
- 修改 sealed evidence；
- 读取 family 标签后选择求解路线。

所有 LLM 提议保存 model、prompt-template、decoding config 和输出哈希。

## 9. 生成式偏差与保护

每批记录：

- proposal 来源分布；
- semantic/solver-input duplicate rate；
- cell coverage；
- lineage concentration；
- 与随机合法生成的对照；
- 各模型假阴性和过度自信率。

若生成模型集中到少数模式，降低其预算而不是删除其他 emitter。若模型输出与 grammar 冲突频繁，退回规则/MCTS，并修复训练表示。

## 10. 验收测试

1. 多步完成任务可跨越至少一个低价值中间节点。
2. DAG 合并不丢失 lineage。
3. progressive widening 不依赖 action 枚举顺序。
4. 删除模型预测字段后，物理判定完全不变。
5. 代理训练集无 solver-input 泄漏。
6. 模型域外候选不会被高置信永久剪枝。
7. GFlowNet/LLM 停用后，规则、QD 和随机通道仍能完整运行。

## 11. 研究依据

- MAP-Elites: <https://arxiv.org/abs/1504.04909>
- CMA-ME: <https://arxiv.org/abs/1912.02400>
- GFlowNet Foundations: <https://jmlr.org/papers/volume24/22-0364/22-0364.pdf>
- Continuous-action MCTS: <https://doi.org/10.1609/aaai.v34i04.5885>
- Enhanced POET（只借鉴开放式踏脚石思想）: <https://arxiv.org/abs/2003.08536>

