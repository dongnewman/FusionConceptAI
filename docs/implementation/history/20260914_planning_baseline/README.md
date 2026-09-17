# 多拓扑生成到可信物理装置 v4：设计总纲

状态：下一阶段设计大纲，不代表已经实现或产生可信装置  
日期：2026-09-02  
适用项目：FusionConceptAI

## 1. 一句话目标

v4 把已经完成定义的机制 Genome、场—几何 Genome、实现—控制 Genome 接入一条统一的、可恢复的搜索与证据链，在不枚举完整笛卡尔积、不按装置家族路由、不把代理预测当物理证据的前提下，从开放式多拓扑生成推进到证据边界内的最简可信候选。

三种 Genome 的既有文档是 v4 的规范性上游，本目录不复制、改写或另立其语义。v4 只定义它们如何被引用、组合、编译、搜索、求解和审计。

## 2. 总体组成与职责

| 部分 | 核心职责 | 主要产物 | 详细文档 |
|---|---|---|---|
| 共同合同与状态模型 | 固定术语、哈希、状态、authority 和不可补偿规则 | `CandidateStatePackageV4` | [00 共同合同](00_normative_contracts_and_state_model.md) |
| 候选集成与抽象编译 | 组合三种 Genome；编译区域、接口、边界、端口、因果和义务 | `CompiledCandidatePrefixV4` | [01 候选集成](01_candidate_integration_and_abstract_compilation.md) |
| 严格证明式剪枝 | 只凭可验证证书永久删除不可能前缀；区分失败、休眠和未知 | `PruneCertificateV4` | [02 证明式剪枝](02_proof_pruning_and_failure_semantics.md) |
| 开放式演化与 QD | 保留踏脚石、失败前沿和多样化谱系，不收敛到单一家族 | `DeepQDArchiveV4` | [03 演化与 QD](03_open_ended_evolution_and_quality_diversity.md) |
| MCTS 与生成式提议 | 对多步机制组合做渐进展开；以 AI 提议候选而非判定物理 | `ProposalEnvelopeV4` | [04 MCTS 与生成提议](04_mcts_and_generative_proposal.md) |
| realization 与独立物理解算 | 把 Genome 编译为有限、有单位、可执行的候选绑定输入；按 capability 路由 | `ExecutablePhysicalSubjectV4` | [05 realization 与求解](05_realization_and_independent_physics_execution.md) |
| 多保真硬物理 frontier | 按适用义务依次执行场、轨道/损失、平衡、稳定性和输运 | `StageFrontierV4` | [06 硬物理 frontier](06_multifidelity_hard_physics_frontier.md) |
| 成活者稀疏化与 Pareto | 在硬门之后、同一比较作用域内做结构和工程最简化 | `ScopedParetoArchiveV4` | [07 稀疏化与 Pareto](07_survivor_sparsification_and_pareto.md) |
| 高保真整装与 VVUQ | 完整耦合整装、数值 VVUQ、双代码、工程与验证证据 | `WholeDeviceEvidencePackageV4` | [08 高保真与 VVUQ](08_high_fidelity_whole_device_vvuq.md) |
| 最终证据 authority 与实施 | 终局分类、可信声明、campaign、验收和 v4 实施顺序 | `CredibleCandidateEnvelopeV4` | [09 authority 与路线图](09_evidence_authority_campaign_and_v4_roadmap.md) |

## 3. 统一流程

```text
三种既有 Genome 合同
        │
        ▼
候选前缀组合与抽象编译 ── 严格证书成立 ──> proof_pruned
        │
        ├── 开放式演化 / Deep-QD / 失败前沿 / 休眠复活
        ├── progressive-widening MCTS
        └── GFlowNet/代理/规则生成的候选提议
        │                 以上都只有提议权
        ▼
有限 realization 与 exact solver-input 编译
        ▼
独立 capability-routed 物理解算
        ▼
不可变多保真 frontier
场/解析界 → 轨道或损失 → 平衡 → 稳定性 → 输运
        ▼
同作用域稀疏化与 Pareto
        ▼
有限压力 + 动理学 + 工程 + 故障场景 + numerical VVUQ + 双代码
        ▼
validation VVUQ / 外部证据
        ▼
最终整装 authority
        ▼
证据边界内的最简可信候选，或有作用域的 fail/unknown/unsupported
```

搜索循环可以从任何非终局档案成员产生后代；证据链只能前向晋升。搜索器不得更改历史证据，较高保真结果不得反向给较低保真候选补信用。

## 4. v4 的核心变化

相对 v3，v4 增加以下强制能力：

1. 不预先物化完整联合 Genome；仅对被选中的部分 Genome 惰性展开。
2. 永久剪枝仅允许基于机器可验证的无解证书；低保真不利结果进入休眠或失败前沿。
3. 每个行为生态位保留多条不同谱系，而不是每格只有一个赢家。
4. 类型化遗传编程、QD、MCTS、连续优化、生成式模型和随机复活以多 emitter 方式并行，且每类有预算下限。
5. AI 模型只有提议和预算排序权，没有物理判定、晋升或终局分类权。
6. realization 是既有 Genome 的候选绑定物化，不得暗中发明未编码组件、状态或边界。
7. 中间 provider 缺口采用 `terminal_deferred`；只有最终整装 authority 可以给出终局 `unsupported`。
8. 最简性只在已声明 grammar、bounds、mission、evidence level 和 comparison scope 内成立。

## 5. 跨文档不可变原则

- 不使用 device family、历史名称、parent、benchmark 身份或候选序号进行生成、路由、门控或晋升。
- 三种 Genome 的语义由其既有文档拥有；v4 只保存其版本化引用和规范哈希。
- `unknown`、`unsupported`、`physical_fail`、`numerical_fail`、`not_applicable` 和 `terminal_deferred` 不得合并。
- 代理分数、新颖性、信息增益、成本和复杂度不得补偿硬物理门。
- 所有物理结论必须绑定 exact candidate、scenario、solver input、backend、数值配置和证据哈希。
- 不适用必须有 applicability proof；没有执行不能默认通过。
- 最终可信结果不等于实验验证、工程可建造或商业可行，声明必须受 evidence ceiling 限制。

## 6. 文档优先级与冲突解决

本目录内优先级为：

1. [00 共同合同](00_normative_contracts_and_state_model.md)；
2. 本总纲；
3. 01–09 各详细设计。

三种既有 Genome 文档对 Genome 内部语义具有更高优先级；v4 不得覆盖它们。若详细文档与共同合同冲突，以共同合同为准并修正文档，不允许实现自行选择解释。

v4 继承以下现有基线的证据边界：

- [统一多拓扑装置生成架构 v3](../universal_multitopology_device_generation_architecture_v3_20260827.md)；
- [v141 unbiased generic chain](../v141_unbiased_generic_chain_design.md)；
- [v142 terminal-deferred whole-device](../v142_terminal_deferred_whole_device_design.md)。

本目录是下一阶段设计，不改变历史运行结果、密封 artifact 或既有 acceptance 声明。
