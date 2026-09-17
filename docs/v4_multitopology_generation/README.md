# v4 多拓扑生成：核心规划与执行入口

版本：`v4-upgrade-plan-20260914.1`。本目录保存当前架构、执行路线、工作单和未完成事项；`docs/implementation/` 保存实现记录与历史快照。本文是规划，不能作为代码实现或物理验收证据。

## 1. 本次调整与目标

按 2026-09-14 用户指令，先扩大三层 Genome 的可执行表达能力，再完成物理编译、空间离散与耦合，验证合法模块组合，完成逆向 realization 与工程反馈，最后接入条件 e-graph 和更广的演化搜索。三层 Genome 允许版本化补齐；旧版合同、候选身份和历史 evidence 不得被原地重解释。本次指令替代旧版“本目录不修改 Genome”及搜索优先的实施顺序。

保留完整父目标：用同一条可复现链路完成真实参考对象表示、可识别的隐参数逆恢复与留出预测，再通过 G1/G2/G3 的机制、场、几何、拓扑、实现和控制搜索，产生至少一个经过独立物理、工程、整装净输出及原创性审查的 L4 候选。R01–R10 不能被局部里程碑代替。建成装置并测得正净输出是额外的 L5 证据要求。

这里的“通用”是**在声明的模型、空间和数值适用域内，依据合同自动组合并可扩展**。有限软件不承诺任意抽象拓扑都可物化、任意等离子体模型都可闭合、任意目标场都有可制造源。

## 2. 阅读路径

所有执行者先读 [00 共同合同](00_normative_contracts_and_state_model.md)，再读本页和 [16 工作单](16_execution_work_orders.md)。任务状态与依赖以 [task_manifest.json](task_manifest.json) 为准；文本工作单拥有技术步骤，机器清单拥有调度关系，二者冲突必须先修正。

| 阅读者或任务 | 必读文件 |
|---|---|
| Sol（high）总调度 | [主线提示词，500 字以内](15_sol_system_prompt.md)、[14 协作与决策](14_agent_orchestration.md)、16、13 |
| Luna（high）执行者 | [17 执行提示词](17_luna_worker_prompt.md)、被分配工作单、00、对应技术章 |
| Genome 补齐 | [G1](<G1 机制基因组.md>)、[G2](<G2 场—几何基因组.md>)、[G3](<G3 实现—控制Genome.md>)、[10 升级实施](10_genome_upgrade_execution.md) |
| 编译、离散与耦合 | [01 抽象编译](01_candidate_integration_and_abstract_compilation.md)、[11 执行编译](11_physics_compilation_and_discretization.md) |
| 模块组合、源与硬件逆实现 | [05 realization 合同](05_realization_and_independent_physics_execution.md)、[12 组合与逆实现](12_composition_and_inverse_realization.md) |
| 验证和最终证据 | [13 验收协议](13_acceptance_benchmarks_and_evidence.md)、[06 物理 frontier](06_multifidelity_hard_physics_frontier.md)、[08 整装 VVUQ](08_high_fidelity_whole_device_vvuq.md)、[09 authority](09_evidence_authority_campaign_and_v4_roadmap.md) |
| 更广搜索与等价改写 | [AST / hypergraph / e-graph](<typed AST、operator hypergraph 或 e-graph.md>)、[02 证明剪枝](02_proof_pruning_and_failure_semantics.md)、[03 演化 QD](03_open_ended_evolution_and_quality_diversity.md)、[04 MCTS](04_mcts_and_generative_proposal.md)、[07 Pareto](07_survivor_sparsification_and_pareto.md) |
| 技术选择与来源 | [18 架构决策及来源](18_sources_and_architecture_decisions.md) |
| 已有实现和旧计划 | [implementation 档案索引](../implementation/README.md)；历史材料不能反向覆盖本规划 |

## 3. 强制实施顺序

`UP0–UP6` 是本次工程升级阶段，与现有运行器的 `S0–S10`、历史 `V4-P0–P6` 不同。

| 阶段 | 交付内容 | 退出门，均需实现证据和独立评审 |
|---|---|---|
| UP0 | 当前源码、脏文件、运行中断、旧证据和版本合同基线 | 可复查基线，保护清单，合同边界与派单依赖无冲突 |
| UP1 | G1 算子与闭合；G2 空间与场合同；G3 资源、源、材料和控制合同；最小组件核 | 合法/非法构造、版本迁移、标签擦除、组件数值验证；不是只添字段 |
| UP2 | 自研物理编译、离散组装和耦合；复用成熟数值算法 | 声明驱动执行，支持变系数和组合结构；不靠候选身份或整棵 AST 特判；空间兼容性取代固定模型身份判断 |
| UP3 | 成熟模块按端口、方程和作用域自动组合 | 未预写专用驱动的合法组合实际求解；守恒、耦合一致性、留出组合和非法组合全部核验 |
| UP4 | 源/硬件逆实现；供能、热、材料、结构、控制约束回代；真实参考逆恢复 | 实现误差重新进入主物理，闭环共同收敛，参考逆恢复有可识别性和留出证据 |
| UP5 | 条件 e-graph、丰富 typed edits、物理反馈和扩大搜索 | 等价改写可重放；G1/G2/G3 均有实际编辑与重新执行；小规模有效后按证据扩容 |
| UP6 | 全部适用物理与工程义务、整装净输出、VVUQ、独立原创性与复放 | 原父目标 R01–R10 全部独立验收，至少一个新候选通过全部必需终局门 |

阶段门按所声明的能力配置逐项验收，不把早期有限配置的通过写成全部物理覆盖。每阶段内部采用“小合同→小实现→真实运行→独立评审”的纵向切片。UP1 的 G3 定义逆设计对象、约束和元件核；UP4 才集成完整逆设计和物理闭环，因此不形成依赖循环。保留现行小规模迭代作回归；UP5 之前不得把广搜索当作补齐执行能力的替代。

```mermaid
flowchart LR
  A[UP1 三层 Genome 与组件] --> B[UP2 编译 离散 耦合]
  B --> C[UP3 合法模块组合]
  C --> D[UP4 源硬件逆实现和反馈]
  D --> E[UP5 等价改写和结构搜索]
  E --> F[UP6 整装及独立验收]
  D -->|实现误差 供能 热 形变| B
  E -->|新的机制 空间 实现| A
```

## 4. 当前事实与下一步（2026-09-16 中期审计）

当前 HEAD 为 `b2c04d8339774635aaecd73651efcdb101e01b5d`，工作树仍有既有源码、测试和文档改动。旧 `4b69f55` 是历史基线，不是当前 checkout。接手时必须刷新实际输入，不能只写 HEAD。

**先读 [20 中期审计](20_midterm_audit_20260916.md) 和 [21 下一轮执行批次](21_next_execution_batches.md)。** 当前39节点：UP0两项accepted；UP1四项按有限范围accepted、十一项planned；UP2九项、UP3三项、UP4四项、UP5三项、UP6三项均planned。UP1整体尚未验收，UP2通用执行尚未交付，R01–R10未关闭，L4=0。子切片的 accepted_limited 不改变父节点状态。

AD54接受本地21文件源码发布；AD56接受Git过滤/CRLF locator软件修复；AD55 fresh F0/S2的六scope source-stage输出及独立复核通过，用户转述的Sol有限裁决已[归档](../implementation/MIDTERM-AUDIT-20260916/AD55_decision_archive.md)。三份factory仍含AD56未提交修复；HEAD来源对象与工作树执行器须分别冻结。source-stage present不是trusted source/candidate/final identity，也不是provider/mesh/solver/工程/物理/搜索信用。

下一步：完整冻结实际执行闭包，fresh S3如实判定；缺外部trust root则typed absence并列清输入/责任方/唤醒条件，不重复无变化的S3。满足来源门后按既有T0/recheck/T1/T2及B00/B04进入通用执行；正式门不满足时只做已授权准备，测试专用数值执行须先经范围决策，不越过现有DAG。细节见21。

## 5. 状态、历史和档案

- [task_manifest.json](task_manifest.json) 与 [16](16_execution_work_orders.md) 仍是唯一正式任务和依赖；本轮保留其原始字节及39节点。
- [implementation 当前索引](../implementation/README.md) 按UP阶段和任务查档；[机器目录](../implementation/MIDTERM-AUDIT-20260916/archive_catalog.json) 是检索快照，不是验收或调度器。
- 本页旧逐轮AD叙述已完整存入[入口原文快照](../implementation/MIDTERM-AUDIT-20260916/entry_snapshots/core_README.before.txt)，保持原始字节。历史的pending或旧HEAD只代表当时状态；最新限定范围由20、具体验收书和实际证据联合判断。
- 18中的历史架构决策、所有原验收书和失败记录保留。遇到历史“当前”与本页冲突，先核对时间、输入hash及scope，禁止批量把旧结果改写成present/accepted。

本目录用于完整路线指导，implementation用于实现、审计和历史档案。一次文档整理、软件测试或来源工厂复放都不会关闭父目标。
