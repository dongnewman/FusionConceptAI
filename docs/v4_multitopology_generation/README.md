# v4 多拓扑生成：核心规划与执行入口

版本：`v4-upgrade-plan-20260917.agent-local.1`。本目录保存当前架构、执行路线、工作单和未完成事项；`docs/implementation/` 保存实现记录与历史快照。本文是规划，不能作为代码实现或物理验收证据。

## 1. 本次调整与目标

按 2026-09-14 用户指令，先扩大三层 Genome 的可执行表达能力，再完成物理编译、空间离散与耦合，验证合法模块组合，完成逆向 realization 与工程反馈，最后接入条件 e-graph 和更广的演化搜索。三层 Genome 允许版本化补齐；旧版合同、候选身份和历史 evidence 不得被原地重解释。本次指令替代旧版“本目录不修改 Genome”及搜索优先的实施顺序。

保留完整父目标：用同一条可复现链路完成真实参考对象表示、可识别的隐参数逆恢复与留出预测，再通过 G1/G2/G3 的机制、场、几何、拓扑、实现和控制搜索，产生至少一个经过独立物理、工程、整装净输出及原创性审查的 L4 候选。R01–R10 不能被局部里程碑代替。建成装置并测得正净输出是额外的 L5 证据要求。

这里的“通用”是**在声明的模型、空间和数值适用域内，依据合同自动组合并可扩展**。有限软件不承诺任意抽象拓扑都可物化、任意等离子体模型都可闭合、任意目标场都有可制造源。

## 2. 阅读路径

所有执行者先读 [22 智能体自主研发合同](22_agent_local_execution.md) 和 [00 共同合同](00_normative_contracts_and_state_model.md)，再读本页和 [16 工作单](16_execution_work_orders.md)。任务状态与依赖以 [task_manifest.json](task_manifest.json) 为准；文本工作单拥有技术步骤，机器清单拥有调度关系，二者冲突必须先修正。

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

## 4. 当前执行政策与下一步（2026-09-18）

**默认由智能体自主负责，取消外部认证对主线的阻塞。** Sol 决策与验收，Luna 实现并交叉复核；不再等待 CA、证明人、TSA、OCSP/CRL、签名 ACK、权威 G2 或发布方证明。科学与工程要求保持，项目内候选身份不等于物理正确。具体替换规则和实际命令见 [22](22_agent_local_execution.md)。

从 [21 当前执行批次](21_next_execution_batches.md) 和 [16 工作单](16_execution_work_orders.md) 推进本地完整声明、组合执行、数值验证及逆实现。不要继续补外部责任人表或无变化地重跑 S3/R4。实际缺失的模型、输入、离散能力和数值失败仍逐项修复。

当前索引同步基线为 T1 R1–R3 diagnostic receipts（工作树基于 `f418c6e`）；后续提交会再刷新本索引。下列记录是静态、合同或屏幕记录，不是完成百分比；不代表相应 UP 标签、R01–R10 或 parent goal 已关闭：

| 记录 | 提交 | 状态上限 |
|---|---|---|
| T0 LocalV1 | `87f0263` | committed |
| T0 authority recheck | `94e4598` / R21 | historical `interrupted_incomplete`；negative dispatch `0/25`；no retry；no authority |
| T0 authority recheck | `345bafb` / R22 | `runtime_complete`；Julia `310/310`；negative dispatch `25/25`；`accepted=false`；`contract_only`；no T1/T2 credit；100 snapshots仅静态推导 |
| T1 package/edit/round-trip | `62d9a61` / R5 | static `16`；`prepared_not_executed`；无 runtime receipt |
| T1 focused runtime | `d37ef44` / R1 | `program_exception`；2 pass / 1 error；no retry；no T1/T2/UP1 credit |
| T1 focused runtime | `f5c9328` / R2 | `fail_closed` projection；11 pass / 3 fail / 14 error；15/15 unchanged；no retry；no T1/T2/UP1 credit |
| T1 focused runtime | `f418c6e` / R3 | `fail_closed` projection；11 pass / 3 fail / 14 error；15/15 unchanged；no retry；bare catch did not expose underlying exception；no T1/T2/UP1 credit |
| Spatial composition | `e5e44bd` / R9 | `54/54`；`screen_only`；`accepted=false`；no formal credits |
| G1/G2/G3 execution | `7c82e95` / R22 | nested receipt authoritative `39/39 + 13/13`；package `preflight_only`；`screen_only`；no formal credits |
| UP2 spatial transfer | `ca5fef9` | 70/70 `contract_only` |
| UP3 composition solve plan | `a1ad8cc` | 161/161 `contract_only` |
| UP4 SHIR | `5d9d651` | 547/547 `prepared_not_measured` |
| UP4 engineering bridge | `5ea78c0` | 189/189 `contract_only` |
| UP5 conditional egraph | `cd52ee3` | `contract_only` conditional egraph；不关闭标签 |
| UP5 bounded structure | `f9612bd` | 94/94 `contract_only` |
| UP6 final ledger | `67a4e87` | 123/123 `contract_only`；no final authority |
| UP2 executable screen | `348b061` | 68/68 `manufactured_numerical_screen` |
| DCCE declared diffusion compile-execute | `09cf7d1` | Python static QA/oracle pass；`screen_only`；`accepted=false`；Julia未运行；无 UP2-01/R credit |
| EngineeringFeedback | R14 code / R15 runtime | R14 code；R15 runtime `77/77`；`screen_only`，`accepted=false`，`component_load=false`；no formal credits |

T0 authority recheck 最新 R22 为 `runtime_complete`：Julia focused test `310/310`，negative dispatch `25/25`，`accepted=false`，`contract_only`，无 T1/T2 credit；`100 snapshots` 仅由静态 25×4 推导，非运行时独立计数。R21 中断记录保留历史语义。T1 R5 的 static `16`、`prepared_not_executed` 保留为历史基线；其后 R1 为 `program_exception`（2 pass / 1 error），R2/R3 均为 `fail_closed` projection（11 pass / 3 fail / 14 error，15/15 unchanged，no retry），且 R3 裸 catch 未暴露底层异常。T1/T2/UP1 均无 credit。Spatial R9 `54/54` 仍为 `screen_only`。G1/G2/G3 R22 的 nested receipt authoritative，计数 `39/39 + 13/13`，但 package manifest 仍为 `preflight_only`，不授 formal credits。DCCE `09cf7d1` 仅完成 Python static QA/oracle，`screen_only`、`accepted=false`，Julia未运行，不授 UP2-01 或 R credit。EngineeringFeedback R14 code/R15 runtime `77/77` 仍是 `screen_only`、`accepted=false`、`component_load=false`，无 formal credits。上述记录不提供 provider/physics Julia/DESC runtime credit、物理、工程或 final authority 信用。`R01–R10` 仍 `pending`，`L4=0`，parent goal 仍 open，UP labels 未由这些 receipts 关闭。清理备注：本轮 Python 缓存和空缓存目录已清理；`runs`、`tmp`、evidence 和 protected dirty 状态保留。未跑切片、未跟踪实现和未完成的数值/物理/工程门不得提前写成完成。

## 5. 状态、历史和档案

- [task_manifest.json](task_manifest.json) 和 [16](16_execution_work_orders.md) 记录当前调度与工作单；[execution_policy.json](execution_policy.json) 给出可执行的默认政策。
- [implementation 当前索引](../implementation/README.md) 用于查找实现记录；[20 中期审计](20_midterm_audit_20260916.md) 是 9 月 16 日历史快照，不能重设外部门。
- [本次修改档案](../implementation/AGENT-LOCAL-EXECUTION-20260917/README.md) 保存修改前原文、保护清单与验证结果。旧 R4 的 typed_absent 继续表示缺外部认证，不再阻塞本地开发。
- 原验收书、失败记录和旧 candidate/hash 保留原含义；任何能力完成度仍由相应代码、运行结果及技术复核决定。
